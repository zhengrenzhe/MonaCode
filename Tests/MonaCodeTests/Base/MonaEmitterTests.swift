// MonaEmitterTests.swift
//
// P01-T005 — Implement deterministic events and idempotent disposal.
//
// Verifies:
//   - `MonaEmitter` listener insertion / removal / nested fire / disposal in
//     comparator (subscription) order.
//   - Idempotent disposal: disposing the emitter, a listener removal disposable,
//     and a `MonaDisposableImpl` twice are all no-ops.
//   - Additions during dispatch observe the NEXT dispatch only (a listener
//     registered while an event is being delivered does not receive the current
//     event; it receives the next `fire`).
//   - Listener failures are reported through the declared error boundary
//     (`onListenerError`) WITHOUT skipping later listeners.
//   - `MonaDisposable` protocol + `MonaDisposableImpl` idempotent action.
//   - `MonaEvent<T>` is the typed subscribe function.

import XCTest
import MonaCode

final class MonaEmitterTests: XCTestCase {

    /// A throw used to exercise the listener error boundary.
    private enum Boom: Error, Equatable { case boom }

    /// A mutable, reference-typed recorder captured by escaping closures so the
    /// test can observe delivery order, received events, and reported errors.
    private final class Recorder {
        var events: [String] = []
        var errors: [Error] = []
    }

    /// A mutable counter captured by escaping closures to gate reentrant
    /// listeners against unbounded recursion.
    private final class Counter {
        var n = 0
    }

    /// A reference-typed holder for a `MonaDisposable`, so a listener registered
    /// earlier can dispose a disposable assigned after registration.
    private final class DisposableHolder {
        var disposable: MonaDisposable?
    }

    // MARK: - MonaDisposable + MonaDisposableImpl

    func testDisposableImplRunsActionExactlyOnceAndIsIdempotent() {
        let counter = Counter()
        let disposable = MonaDisposableImpl { counter.n += 1 }

        disposable.dispose()
        disposable.dispose()
        disposable.dispose()

        // The action runs exactly once; subsequent disposals are no-ops.
        XCTAssertEqual(counter.n, 1)
    }

    func testDisposableImplWithNoActionIsSafeToDispose() {
        let disposable = MonaDisposableImpl({ })
        disposable.dispose()
        disposable.dispose()  // must not crash
    }

    // MARK: - Basic registration and fire

    func testEventRegistersListenerAndFireDeliversValue() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        _ = emitter.event({ (value: String) in recorder.events.append(value) })

        emitter.fire("hello")

        XCTAssertEqual(recorder.events, ["hello"])
    }

    func testListenersFireInSubscriptionOrder() {
        let emitter = MonaEmitter<Int>()
        let recorder = Recorder()
        _ = emitter.event({ (v: Int) in recorder.events.append("A:\(v)") })
        _ = emitter.event({ (v: Int) in recorder.events.append("B:\(v)") })
        _ = emitter.event({ (v: Int) in recorder.events.append("C:\(v)") })

        emitter.fire(7)

        XCTAssertEqual(recorder.events, ["A:7", "B:7", "C:7"])
    }

    // MARK: - Removal

    func testEventReturnsDisposableThatRemovesListener() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        let disposable = emitter.event({ (v: String) in recorder.events.append(v) })

        disposable.dispose()
        emitter.fire("ignored")

        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testRemovalDuringDispatchStopsNotYetDeliveredListener() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        let holder = DisposableHolder()

        _ = emitter.event({ (v: String) in
            recorder.events.append("A:\(v)")
            // Remove B before the dispatch reaches it.
            holder.disposable?.dispose()
        })
        holder.disposable = emitter.event({ (v: String) in
            recorder.events.append("B:\(v)")
        })

        emitter.fire("x")

        // A delivered; B was removed mid-dispatch and must not be delivered.
        XCTAssertEqual(recorder.events, ["A:x"])
    }

    // MARK: - Nested fire (reentrancy)

    func testTwoListenerNestedFireFinishesCurrentEventBeforeNestedSnapshot() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        let depth = Counter()

        _ = emitter.event({ (v: String) in
            recorder.events.append("A:\(v)")
            // A reentrantly fires once. The current event must finish (B gets
            // delivered) before the nested snapshot is processed.
            if depth.n == 0 {
                depth.n += 1
                emitter.fire("nested")
            }
        })
        _ = emitter.event({ (v: String) in
            recorder.events.append("B:\(v)")
        })

        emitter.fire("outer")

        // Current event fully drains (A:outer, B:outer), THEN the nested
        // snapshot drains (A:nested, B:nested).
        XCTAssertEqual(recorder.events, ["A:outer", "B:outer", "A:nested", "B:nested"])
    }

    func testSingleListenerNestedFireDeliversImmediately() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        let depth = Counter()

        _ = emitter.event({ (v: String) in
            recorder.events.append(v)
            // With a single listener, the nested fire is delivered immediately
            // after the outer invoke returns (the current snapshot is
            // exhausted, so the nested snapshot is processed next).
            if depth.n == 0 {
                depth.n += 1
                emitter.fire("nested")
            }
        })

        emitter.fire("first")

        XCTAssertEqual(recorder.events, ["first", "nested"])
    }

    // MARK: - Additions during dispatch

    func testAdditionsDuringDispatchObserveNextDispatchOnly() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        let added = Counter()

        _ = emitter.event({ (v: String) in
            recorder.events.append("A:\(v)")
            // Register B while the current event is being delivered. B must NOT
            // receive the current event; it must observe the NEXT fire only.
            if added.n == 0 {
                added.n += 1
                _ = emitter.event({ (v: String) in recorder.events.append("B:\(v)") })
            }
        })

        emitter.fire("first")
        // First dispatch: A only. B was added mid-dispatch and is excluded from
        // the current snapshot.
        XCTAssertEqual(recorder.events, ["A:first"])

        emitter.fire("second")
        // Second dispatch: both A and B.
        XCTAssertEqual(recorder.events, ["A:first", "A:second", "B:second"])
    }

    // MARK: - Idempotent disposal

    func testEmitterDisposeIsIdempotent() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        _ = emitter.event({ (v: String) in recorder.events.append(v) })

        emitter.dispose()
        emitter.dispose()  // second dispose is a no-op
        emitter.dispose()  // third dispose is a no-op

        emitter.fire("after")
        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testListenerDisposableIsIdempotent() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        let disposable = emitter.event({ (v: String) in recorder.events.append(v) })

        disposable.dispose()
        disposable.dispose()  // second dispose is a no-op

        emitter.fire("after")
        XCTAssertTrue(recorder.events.isEmpty)
    }

    // MARK: - Post-dispose behavior

    func testFireAfterDisposeIsNoOp() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()
        _ = emitter.event({ (v: String) in recorder.events.append(v) })

        emitter.dispose()
        emitter.fire("nope")

        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testSubscribeAfterDisposeReturnsInertDisposable() {
        let emitter = MonaEmitter<String>()
        emitter.dispose()

        // Subscribing after dispose returns an inert (empty) disposable; the
        // listener is never registered.
        let disposable = emitter.event({ (v: String) in
            XCTFail("listener registered after dispose must not be invoked")
        })

        // Disposing the inert disposable must be safe and idempotent.
        disposable.dispose()
        disposable.dispose()

        emitter.fire("still-nope")
    }

    func testDisposeDuringDispatchStopsRemainingListeners() {
        let emitter = MonaEmitter<String>()
        let recorder = Recorder()

        _ = emitter.event({ (v: String) in
            recorder.events.append("A:\(v)")
            // Dispose the emitter mid-dispatch. Remaining listeners in the
            // current snapshot must not be delivered, and pending nested
            // fires must be dropped.
            emitter.dispose()
        })
        _ = emitter.event({ (v: String) in
            recorder.events.append("B:\(v)")
        })

        emitter.fire("x")

        XCTAssertEqual(recorder.events, ["A:x"])

        // A subsequent fire is a no-op (emitter is disposed).
        emitter.fire("again")
        XCTAssertEqual(recorder.events, ["A:x"])
    }

    // MARK: - Listener error boundary

    func testListenerFailureReportedWithoutSkippingLaterListeners() {
        let recorder = Recorder()
        let emitter = MonaEmitter<String>(
            options: MonaEmitterOptions(onListenerError: { error in
                recorder.errors.append(error)
            })
        )

        _ = emitter.event({ (_: String) in throw Boom.boom })
        _ = emitter.event({ (v: String) in recorder.events.append(v) })

        emitter.fire("hi")

        // The throwing listener's error is reported through the boundary...
        XCTAssertEqual(recorder.errors.count, 1)
        XCTAssertEqual(recorder.errors.first as? Boom, .boom)
        // ...and the later listener is still delivered (not skipped).
        XCTAssertEqual(recorder.events, ["hi"])
    }

    func testListenerFailureWithoutBoundaryIsSwallowedAndDeliveryContinues() {
        let recorder = Recorder()
        let emitter = MonaEmitter<String>()  // no onListenerError boundary

        _ = emitter.event({ (_: String) in throw Boom.boom })
        _ = emitter.event({ (v: String) in recorder.events.append(v) })

        // fire must not throw and must not skip later listeners.
        emitter.fire("hi")

        XCTAssertEqual(recorder.events, ["hi"])
    }

    func testMultipleListenerFailuresAreEachReported() {
        let recorder = Recorder()
        let emitter = MonaEmitter<String>(
            options: MonaEmitterOptions(onListenerError: { error in
                recorder.errors.append(error)
            })
        )

        _ = emitter.event({ (_: String) in throw Boom.boom })
        _ = emitter.event({ (_: String) in throw Boom.boom })

        emitter.fire("hi")

        // Each failing listener reports its error independently.
        XCTAssertEqual(recorder.errors.count, 2)
    }

    // MARK: - Lifecycle hooks

    func testFirstListenerDidAddAndNoListenersHooksFire() {
        let added = Counter()
        let emptied = Counter()
        let emitter = MonaEmitter<String>(
            options: MonaEmitterOptions(
                onFirstListenerDidAdd: { added.n += 1 },
                onNoListeners: { emptied.n += 1 }
            )
        )

        let first = emitter.event({ (_: String) in })
        XCTAssertEqual(added.n, 1)  // first add fires once

        let second = emitter.event({ (_: String) in })
        XCTAssertEqual(added.n, 1)  // second add does not fire the hook

        second.dispose()
        XCTAssertEqual(emptied.n, 0)  // still one listener

        first.dispose()
        XCTAssertEqual(emptied.n, 1)  // last listener removed -> empty
    }

    // MARK: - MonaEvent<T> subscribe function type

    func testEventAccessorExposesTypedSubscribeFunction() {
        // `MonaEvent<T>` is the typed subscribe function: it accepts a listener
        // and returns a `MonaDisposable`. The `event` property of an emitter is
        // a value of this type.
        let emitter = MonaEmitter<Int>()
        let subscribe: MonaEvent<Int> = emitter.event
        let recorder = Recorder()

        let disposable = subscribe({ (v: Int) in recorder.events.append(String(v)) })
        defer { disposable.dispose() }

        emitter.fire(42)

        XCTAssertEqual(recorder.events, ["42"])
    }
}
