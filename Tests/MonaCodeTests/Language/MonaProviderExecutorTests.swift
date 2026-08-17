// MonaProviderExecutorTests.swift
//
// P05-T013 — Implement deterministic provider execution and microtask publication.
//
// Verifies that `MonaProviderExecutor` normalizes the seven provider result
// shapes (synchronous, asynchronous, optional, throwing, cancelable,
// resolvable, releasable) onto one publication path serialized through a
// `MonaMicrotaskQueue` (one queue, FIFO, deterministic order), validates a
// `MonaAsyncValidityTicket` immediately before publication (a stale/cancelled
// ticket drops the result silently), and releases every owned provider /
// resource list exactly once (idempotent release).
//
// Test contract (P05-T013): 7-shape normalization; serialized FIFO
// publication; validate-ticket-before-publish; owned-list released exactly
// once.

import XCTest
import MonaCode

final class MonaProviderExecutorTests: XCTestCase {

    // MARK: - Helpers

    /// A counting disposable for verifying exactly-once release. Disposing
    /// twice must increment `disposeCount` only once (idempotent).
    private final class CountingDisposable: MonaDisposable {
        private let lock = NSLock()
        private var _disposed = false
        private(set) var disposeCount = 0
        func dispose() {
            lock.lock()
            if _disposed { lock.unlock(); return }
            _disposed = true
            lock.unlock()
            disposeCount += 1
        }
    }

    /// A model + gate + executor wired for a test.
    private func makeExecutor(text: String = "abc") -> (MonaCodeModel, MonaPublicationGate, MonaProviderExecutor) {
        let model = MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate = MonaPublicationGate(model: model)
        let executor = MonaProviderExecutor(gate: gate)
        return (model, gate, executor)
    }

    // MARK: - 1. MonaMicrotaskQueue drains in FIFO order (deterministic)

    /// Microtasks enqueued in order A, B, C drain in order A, B, C — the queue
    /// is FIFO and deterministic (no non-deterministic concurrency).
    func testMicrotaskQueueDrainsInFIFOOrder() {
        let queue = MonaMicrotaskQueue()
        var order: [Int] = []
        queue.enqueue { order.append(1) }
        queue.enqueue { order.append(2) }
        queue.enqueue { order.append(3) }

        XCTAssertEqual(queue.pendingCount, 3, "three microtasks are pending before drain")
        XCTAssertFalse(queue.isDraining, "queue must not be draining before drain()")

        queue.drain()

        XCTAssertEqual(order, [1, 2, 3], "microtasks must drain in FIFO enqueue order")
        XCTAssertEqual(queue.pendingCount, 0, "queue must be empty after drain")
    }

    /// Microtasks enqueued DURING a drain are processed in the same drain
    /// cycle, after the currently-queued batch (reentrancy-safe, deterministic).
    func testMicrotaskQueueDrainsNestedEnqueuesInOrder() {
        let queue = MonaMicrotaskQueue()
        var order: [Int] = []
        queue.enqueue {
            order.append(1)
            // A microtask enqueued mid-drain must run AFTER the current batch
            // (it is appended to the FIFO tail).
            queue.enqueue { order.append(3) }
        }
        queue.enqueue { order.append(2) }

        queue.drain()

        XCTAssertEqual(order, [1, 2, 3], "nested enqueues must drain FIFO after the current batch")
        XCTAssertEqual(queue.pendingCount, 0)
    }

    /// `drain()` is reentrancy-safe: a nested `drain()` call during an active
    /// drain is a no-op (the in-flight loop owns the drain).
    func testMicrotaskQueueDrainIsReentrancySafe() {
        let queue = MonaMicrotaskQueue()
        var drained: [Int] = []
        queue.enqueue {
            drained.append(1)
            // Nested drain during an active drain must NOT re-enter the loop.
            queue.drain()
            queue.enqueue { drained.append(2) }
        }
        queue.drain()
        XCTAssertEqual(drained, [1, 2])
        XCTAssertEqual(queue.pendingCount, 0)
    }

    // MARK: - 2. Shape 1: synchronous normalizes and publishes

    /// A synchronous result carries an immediate value; after drain, the
    /// receive closure is invoked with that value on the microtask queue.
    func testSynchronousResultNormalizesAndPublishes() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()

        var received: String? = nil
        let enqueued = executor.publish(
            .synchronous("hello"),
            ticket: ticket,
            receive: { received = $0 }
        )

        XCTAssertTrue(enqueued, "a synchronous result with a fresh ticket must be enqueued")
        XCTAssertNil(received, "publication must not run before drain")

        executor.drain()

        XCTAssertEqual(received, "hello", "a synchronous result must publish its value after drain")
    }

    // MARK: - 3. Shape 2: asynchronous normalizes via a resolver

    /// An asynchronous result receives a resolver the provider resolves later;
    /// the publication is enqueued when the resolver settles, then published
    /// on the microtask queue.
    func testAsynchronousResultNormalizesViaResolver() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()

        var received: String? = nil
        let enqueued = executor.publish(
            .asynchronous { resolver in
                // Defer resolution to simulate an async provider.
                resolver.resolve("deferred")
            },
            ticket: ticket,
            receive: { received = $0 }
        )

        XCTAssertTrue(enqueued, "an asynchronous result must be accepted for publication")
        // The provider resolved synchronously, so the publication is already
        // queued — but not yet published (must drain).
        XCTAssertNil(received, "publication must not run before drain")

        executor.drain()

        XCTAssertEqual(received, "deferred", "an asynchronous result must publish the resolved value")
    }

    // MARK: - 4. Shape 3: optional — nil drops, non-nil publishes

    /// An optional result that is nil has no value to publish: publication is
    /// not enqueued and the owned list is released exactly once.
    func testOptionalResultNilDropsAndReleases() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let owned = CountingDisposable()

        var received: String? = "_unset_"
        let enqueued = executor.publish(
            MonaProviderResult<String>.optional(nil),
            ticket: ticket,
            owned: [owned],
            receive: { received = $0 }
        )

        XCTAssertFalse(enqueued, "a nil optional must not enqueue a publication")
        XCTAssertEqual(received, "_unset_", "a nil optional must not invoke receive")
        XCTAssertEqual(owned.disposeCount, 1, "a nil optional must release the owned list exactly once")
    }

    /// An optional result that is non-nil publishes the value.
    func testOptionalResultNonNilPublishes() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()

        var received: String? = nil
        let enqueued = executor.publish(
            .optional("present"),
            ticket: ticket,
            receive: { received = $0 }
        )

        XCTAssertTrue(enqueued)
        executor.drain()
        XCTAssertEqual(received, "present")
    }

    // MARK: - 5. Shape 4: throwing — success publishes, failure drops

    /// A throwing result whose body returns successfully publishes the value.
    func testThrowingResultSuccessPublishes() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()

        var received: Int? = nil
        let enqueued = executor.publish(
            .throwing { 42 },
            ticket: ticket,
            receive: { received = $0 }
        )

        XCTAssertTrue(enqueued)
        executor.drain()
        XCTAssertEqual(received, 42)
    }

    /// A throwing result whose body throws has no value to publish:
    /// publication is not enqueued and the owned list is released exactly once.
    func testThrowingResultFailureDropsAndReleases() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let owned = CountingDisposable()

        struct ProviderError: Error {}

        var received: Int? = -1
        let enqueued = executor.publish(
            .throwing { throw ProviderError() },
            ticket: ticket,
            owned: [owned],
            receive: { received = $0 }
        )

        XCTAssertFalse(enqueued, "a throwing result that throws must not enqueue a publication")
        XCTAssertEqual(received, -1, "a throwing result that throws must not invoke receive")
        XCTAssertEqual(owned.disposeCount, 1, "a throwing failure must release the owned list exactly once")
    }

    // MARK: - 6. Shape 5: cancelable — not-cancelled publishes, cancelled drops

    /// A cancelable result whose token is not cancelled publishes the value.
    func testCancelableResultNotCancelledPublishes() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let source = MonaCancellationTokenSource()

        var received: String? = nil
        let enqueued = executor.publish(
            .cancelable(source.token, "payload"),
            ticket: ticket,
            receive: { received = $0 }
        )

        XCTAssertTrue(enqueued)
        XCTAssertFalse(source.token.isCancellationRequested)
        executor.drain()
        XCTAssertEqual(received, "payload")
    }

    /// A cancelable result whose token is already cancelled has its
    /// publication suppressed: not enqueued, owned list released exactly once.
    func testCancelableResultCancelledDropsAndReleases() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let source = MonaCancellationTokenSource()
        source.cancel()
        let owned = CountingDisposable()

        var received: String? = "_unset_"
        let enqueued = executor.publish(
            .cancelable(source.token, "payload"),
            ticket: ticket,
            owned: [owned],
            receive: { received = $0 }
        )

        XCTAssertTrue(source.token.isCancellationRequested)
        XCTAssertFalse(enqueued, "a cancelled token must not enqueue a publication")
        XCTAssertEqual(received, "_unset_", "a cancelled token must not invoke receive")
        XCTAssertEqual(owned.disposeCount, 1, "a cancelled result must release the owned list exactly once")
    }

    // MARK: - 7. Shape 6: resolvable — publishes on external resolution

    /// A resolvable result observes a pre-created resolver; when that resolver
    /// settles, the publication is enqueued and published on drain.
    func testResolvableResultPublishesOnResolution() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let resolver = MonaProviderResolver<String>()

        var received: String? = nil
        let enqueued = executor.publish(
            .resolvable(resolver),
            ticket: ticket,
            receive: { received = $0 }
        )

        XCTAssertTrue(enqueued, "a resolvable result must be accepted for publication")
        XCTAssertFalse(resolver.isSettled, "resolver must not be settled before resolve()")

        resolver.resolve("resolved-value")
        XCTAssertTrue(resolver.isSettled, "resolver must be settled after resolve()")

        XCTAssertNil(received, "publication must not run before drain")
        executor.drain()
        XCTAssertEqual(received, "resolved-value")
    }

    /// A resolvable result whose resolver rejects has no value to publish:
    /// the owned list is released exactly once, receive is not invoked.
    func testResolvableResultRejectDropsAndReleases() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let resolver = MonaProviderResolver<String>()
        let owned = CountingDisposable()

        struct RejectError: Error {}

        var received: String? = "_unset_"
        _ = executor.publish(
            .resolvable(resolver),
            ticket: ticket,
            owned: [owned],
            receive: { received = $0 }
        )

        resolver.reject(RejectError())
        XCTAssertEqual(received, "_unset_", "a rejected resolver must not invoke receive")
        XCTAssertEqual(owned.disposeCount, 1, "a rejected resolver must release the owned list exactly once")
    }

    // MARK: - 8. Shape 7: releasable — publishes and releases owned resources

    /// A releasable result carries a value plus a list of owned resources; the
    /// resources are released exactly once after the publication drains.
    func testReleasableResultPublishesAndReleasesOwned() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let resourceA = CountingDisposable()
        let resourceB = CountingDisposable()

        var received: String? = nil
        let enqueued = executor.publish(
            .releasable("value", [resourceA, resourceB]),
            ticket: ticket,
            receive: { received = $0 }
        )

        XCTAssertTrue(enqueued)
        // Before drain: not yet released (release happens at publication).
        XCTAssertEqual(resourceA.disposeCount, 0)
        XCTAssertEqual(resourceB.disposeCount, 0)

        executor.drain()

        XCTAssertEqual(received, "value")
        XCTAssertEqual(resourceA.disposeCount, 1, "releasable resources must be released exactly once after publish")
        XCTAssertEqual(resourceB.disposeCount, 1)
    }

    // MARK: - 9. Publication serialized on one FIFO queue (deterministic order)

    /// Multiple publications on one executor drain in enqueue order — the
    /// single microtask queue serializes publication deterministically.
    func testPublicationSerializedOnOneQueueFIFO() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()

        var order: [Int] = []
        _ = executor.publish(.synchronous(1), ticket: ticket) { order.append($0) }
        _ = executor.publish(.synchronous(2), ticket: ticket) { order.append($0) }
        _ = executor.publish(.synchronous(3), ticket: ticket) { order.append($0) }

        XCTAssertEqual(order, [], "no publication must run before drain")
        XCTAssertEqual(executor.queue.pendingCount, 3)

        executor.drain()

        XCTAssertEqual(order, [1, 2, 3], "publications must serialize in FIFO enqueue order on one queue")
    }

    /// Mixed shapes serialize on the same queue in enqueue order.
    func testMixedShapesSerializeOnOneQueueFIFO() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let resolver = MonaProviderResolver<Int>()

        var order: [String] = []
        _ = executor.publish(.synchronous(1), ticket: ticket) { order.append("sync-\($0)") }
        // The resolvable registers an observer but enqueues nothing yet.
        _ = executor.publish(.resolvable(resolver), ticket: ticket) { order.append("resolved-\($0)") }
        _ = executor.publish(.synchronous(3), ticket: ticket) { order.append("sync-\($0)") }
        // queue is now [M1, M3].

        // Resolve now — the observer fires synchronously and enqueues the
        // resolvable publication at the tail, behind M1 and M3.
        resolver.resolve(2)
        // queue is now [M1, M3, M2].

        executor.drain()

        XCTAssertEqual(order, ["sync-1", "sync-3", "resolved-2"],
                       "mixed shapes must serialize FIFO on the one queue")
    }

    // MARK: - 10. Ticket validation: stale ticket drops publication silently

    /// A ticket whose version has diverged since capture (model mutated) is
    /// stale: publication is dropped SILENTLY — receive is not invoked, and the
    /// owned list is released exactly once.
    func testStaleTicketDropsPublicationSilently() {
        let (model, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()

        // Mutate the model out of band → ticket is now stale (version changed).
        model.setValue("changed")
        XCTAssertFalse(gate.validate(ticket), "precondition: the ticket must be stale")

        let owned = CountingDisposable()
        var received: String? = "_unset_"
        let enqueued = executor.publish(
            .synchronous("value"),
            ticket: ticket,
            owned: [owned],
            receive: { received = $0 }
        )

        // Enqueued (the value exists), but the drop happens at publication.
        XCTAssertTrue(enqueued)
        executor.drain()

        XCTAssertEqual(received, "_unset_", "a stale ticket must drop the publication silently")
        XCTAssertEqual(owned.disposeCount, 1, "a stale-ticket drop must still release the owned list exactly once")
    }

    /// A ticket invalidated by `gate.cancel()` (cancellation generation bumped)
    /// is dropped silently.
    func testCancelledTicketDropsPublicationSilently() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()

        gate.cancel()
        XCTAssertFalse(gate.validate(ticket), "precondition: the ticket must be stale after cancel()")

        let owned = CountingDisposable()
        var received: String? = "_unset_"
        _ = executor.publish(
            .synchronous("value"),
            ticket: ticket,
            owned: [owned],
            receive: { received = $0 }
        )
        executor.drain()

        XCTAssertEqual(received, "_unset_", "a cancelled ticket must drop the publication silently")
        XCTAssertEqual(owned.disposeCount, 1)
    }

    /// A stale ticket for an asynchronous result drops at resolution time.
    func testStaleTicketDropsAsynchronousPublicationAtResolution() {
        let (model, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()

        var received: String? = nil
        let resolver = MonaProviderResolver<String>()
        _ = executor.publish(.resolvable(resolver), ticket: ticket) { received = $0 }

        // Stale the ticket, then resolve — the publication must drop.
        model.setValue("changed")
        XCTAssertFalse(gate.validate(ticket))
        resolver.resolve("late")

        XCTAssertNil(received, "receive must not run before drain")
        executor.drain()
        XCTAssertNil(received,
                     "a stale ticket must drop an async publication at resolution")
    }

    // MARK: - 11. Owned lists released exactly once (idempotent)

    /// A disposabled owned list is released exactly once: the release is
    /// idempotent (a second dispose is a no-op), and the executor releases it
    /// exactly once whether the publication succeeds or is dropped.
    func testOwnedListsReleasedExactlyOnce() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let owned = CountingDisposable()

        // Success path: owned released exactly once after publication.
        _ = executor.publish(.synchronous("v"), ticket: ticket, owned: [owned]) { _ in }
        executor.drain()
        XCTAssertEqual(owned.disposeCount, 1, "success path must release owned exactly once")

        // Idempotent: an external second dispose must be a no-op.
        owned.dispose()
        XCTAssertEqual(owned.disposeCount, 1, "a second dispose must be a no-op (idempotent)")
    }

    /// A releasable result's release list AND the owned list are both released
    /// exactly once (combined list, single release pass).
    func testReleasableAndOwnedBothReleasedExactlyOnce() {
        let (_, gate, executor) = makeExecutor()
        let ticket = gate.captureTicket()
        let releaseList = CountingDisposable()
        let owned = CountingDisposable()

        _ = executor.publish(
            .releasable("v", [releaseList]),
            ticket: ticket,
            owned: [owned]
        ) { _ in }
        executor.drain()

        XCTAssertEqual(releaseList.disposeCount, 1)
        XCTAssertEqual(owned.disposeCount, 1)
    }

    // MARK: - 12. Resolver settle is idempotent (first wins)

    /// `resolve` is idempotent: the first settle wins; a later `resolve` or
    /// `reject` is a no-op. Observers fire exactly once.
    func testResolverSettleIsIdempotent() {
        let resolver = MonaProviderResolver<Int>()
        var fires = 0
        var captured: Result<Int, Error>? = nil
        resolver.onSettled { captured = $0; fires += 1 }

        resolver.resolve(1)
        resolver.resolve(2)  // no-op
        struct E: Error {}
        resolver.reject(E())  // no-op

        XCTAssertTrue(resolver.isSettled)
        XCTAssertEqual(fires, 1, "observers must fire exactly once")
        switch captured {
        case .success(let v):
            XCTAssertEqual(v, 1, "the first settle wins")
        default:
            XCTFail("expected success(1)")
        }
    }

    /// An observer registered after the resolver has settled fires
    /// immediately and synchronously.
    func testResolverObserverFiresImmediatelyIfAlreadySettled() {
        let resolver = MonaProviderResolver<String>()
        resolver.resolve("done")

        var captured: String? = nil
        resolver.onSettled { result in
            if case .success(let v) = result { captured = v }
        }
        XCTAssertEqual(captured, "done", "a late observer must fire immediately on the settled value")
    }

    /// `dispose()` on a resolver is idempotent and prevents later observers
    /// from firing (reuses the established idempotent-disposal pattern).
    func testResolverDisposeIsIdempotentAndStopsLaterObservers() {
        let resolver = MonaProviderResolver<Int>()
        resolver.dispose()
        resolver.dispose()  // idempotent no-op

        var fired = false
        resolver.onSettled { _ in fired = true }
        resolver.resolve(1)

        XCTAssertFalse(fired, "a disposed resolver must not fire observers")
        XCTAssertFalse(resolver.isSettled, "a disposed resolver must not settle")
    }
}
