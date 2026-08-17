// MonaProviderExecutor.swift
//
// P05-T013 — Implement deterministic provider execution and microtask publication.
//
// `MonaProviderExecutor` is the publication infrastructure that normalizes the
// seven provider result shapes onto ONE publication path serialized through a
// `MonaMicrotaskQueue` (monaco-editor 0.56.0). A provider may return its result
// in any of seven shapes — synchronous, asynchronous, optional, throwing,
// cancelable, resolvable, releasable — and the executor funnels them all
// through the same deterministic queue, validating a `MonaAsyncValidityTicket`
// immediately before publication and releasing every owned provider /
// resource list exactly once.
//
// The seven result shapes (`MonaProviderResult<Value>`):
//
//   - `.synchronous(value)`          — the value is available immediately.
//   - `.asynchronous(provider)`      — the executor creates a resolver and
//                                       hands it to `provider`, which resolves
//                                       later (deferred).
//   - `.optional(value?)`            — the value may be nil; a nil result has
//                                       no value to publish.
//   - `.throwing(body)`              — `body` may throw; a thrown result has
//                                       no value to publish.
//   - `.cancelable(token, value)`    — the result may be cancelled; a
//                                       cancelled token suppresses publication.
//   - `.resolvable(resolver)`        — an externally-created resolver that will
//                                       settle to a value later.
//   - `.releasable(value, list)`     — the result owns resources released on
//                                       publication (idempotent disposal).
//
// Normalization contract (frozen by G6-R P05-T013):
//
//   - ONE publication path: every shape funnels through the same
//     `MonaMicrotaskQueue`. Publication (the `receive` side effect) runs ONLY
//     inside a microtask on that queue, so the order of publication is fully
//     determined by the order of enqueue calls (FIFO, deterministic).
//   - Validate ticket immediately before publication: a `MonaAsyncValidityTicket`
//     (P01-T010) is validated right before `receive` runs. A stale / cancelled
//     ticket drops the publication SILENTLY — `receive` is never invoked, so
//     none of its side effects (events, cache writes, decorations, selection
//     mutations) occur. The owned list is still released exactly once.
//   - No-value normalization: a nil optional, a thrown body, or an
//     already-cancelled token has no value to publish — the publication is not
//     enqueued and the owned list is released exactly once (synchronously).
//   - Exactly-once release: every owned provider / resource list is released
//     exactly once, whether the publication succeeds or is dropped. Release
//     reuses `MonaDisposable`'s idempotent disposal (P01-T005): disposing twice
//     is a no-op, so the executor disposes each owned item once.
//
// The executor reuses `MonaPublicationGate` (P01-T010) for ticket validation,
// `MonaCancellationToken` / `MonaCancellationTokenSource` (P01-T006) for the
// cancelable shape, and `MonaDisposable` / `MonaDisposableImpl` (P01-T005) for
// idempotent release. No parallel mechanisms are introduced.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaProviderResolver

/// A deferred-value handle — the unified "resolve to a value later" path the
/// `.asynchronous` and `.resolvable` shapes normalize onto.
///
/// Create with `init()`. Settle with `resolve(_:)` (success) or
/// `reject(_:)` (failure); the first settle wins and subsequent calls are
/// no-ops (idempotent). Observe with `onSettled(_:)` — if the resolver is
/// already settled, the handler fires immediately and synchronously, otherwise
/// it fires when the resolver settles. Tear down with `dispose()` (idempotent):
/// after dispose, `resolve`/`reject` are no-ops, pending observers are dropped
/// without firing, and later `onSettled` handlers are never invoked — mirroring
/// `MonaEmitter`'s idempotent-disposal pattern.
public final class MonaProviderResolver<Value>: MonaDisposable {

    /// Creates an unsettled resolver.
    public init() {}

    private let _lock = NSLock()
    private var _settled = false
    private var _result: Result<Value, Error>? = nil
    private var _observers: [(Result<Value, Error>) -> Void] = []
    private var _disposed = false

    /// `true` once the resolver has settled (resolved or rejected) and not been
    /// disposed before settling.
    public var isSettled: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _settled
    }

    /// The settled result, or `nil` before the resolver settles (or if disposed
    /// before settling).
    public var result: Result<Value, Error>? {
        _lock.lock()
        defer { _lock.unlock() }
        return _result
    }

    /// Resolves the resolver with `value`. Idempotent: the first settle wins;
    /// every subsequent `resolve`/`reject` is a no-op. A no-op after `dispose()`.
    public func resolve(_ value: Value) {
        _settle(.success(value))
    }

    /// Rejects the resolver with `error`. Idempotent: the first settle wins;
    /// every subsequent `resolve`/`reject` is a no-op. A no-op after `dispose()`.
    public func reject(_ error: Error) {
        _settle(.failure(error))
    }

    /// Registers `handler` to fire when the resolver settles. If the resolver
    /// is already settled, `handler` fires immediately and synchronously. If
    /// the resolver has been disposed, `handler` is dropped (never fires).
    public func onSettled(_ handler: @escaping (Result<Value, Error>) -> Void) {
        _lock.lock()
        if _disposed {
            _lock.unlock()
            // Disposed: the handler can never fire. Drop it.
            return
        }
        if let result = _result {
            _lock.unlock()
            // Already settled: fire immediately and synchronously.
            handler(result)
            return
        }
        _observers.append(handler)
        _lock.unlock()
    }

    /// Tears down the resolver WITHOUT firing observers. Idempotent: a second
    /// call is a no-op. After dispose, `resolve`/`reject` are no-ops (the
    /// resolver never settles), pending observers are dropped, and later
    /// `onSettled` handlers are never invoked.
    public func dispose() {
        _lock.lock()
        if !_disposed {
            _disposed = true
            _observers.removeAll()
        }
        _lock.unlock()
    }

    /// Settles the resolver with `result` and fires pending observers outside
    /// the lock (so a reentrant `onSettled` cannot deadlock). Idempotent: the
    /// first settle wins; a no-op if already settled or disposed.
    private func _settle(_ result: Result<Value, Error>) {
        var toFire: [(Result<Value, Error>) -> Void] = []
        _lock.lock()
        if _disposed || _settled {
            _lock.unlock()
            return
        }
        _settled = true
        _result = result
        toFire = _observers
        _observers.removeAll()
        _lock.unlock()

        for observer in toFire {
            observer(result)
        }
    }
}

// MARK: - MonaProviderResult

/// A provider result in one of the seven normalized shapes. The executor
/// publishes every shape through the same `MonaMicrotaskQueue`.
public enum MonaProviderResult<Value> {

    /// A synchronous result: the value is available immediately.
    case synchronous(Value)

    /// An asynchronous result: the executor creates a resolver and hands it to
    /// `provider`, which must settle it (resolve or reject) later.
    case asynchronous((MonaProviderResolver<Value>) -> Void)

    /// An optional result: a nil value has no value to publish.
    case optional(Value?)

    /// A throwing result: `body` may throw; a thrown result has no value to
    /// publish.
    case throwing(() throws -> Value)

    /// A cancelable result: a token whose cancellation suppresses publication.
    case cancelable(MonaCancellationToken, Value)

    /// A resolvable result: an externally-created resolver that will settle to
    /// a value later.
    case resolvable(MonaProviderResolver<Value>)

    /// A releasable result: the value plus a list of owned resources released
    /// exactly once on publication (idempotent disposal).
    case releasable(Value, [MonaDisposable])
}

// MARK: - MonaProviderExecutor

/// Normalizes the seven provider result shapes onto one deterministic
/// publication path.
///
/// Create with `init(gate:queue:)`, passing the `MonaPublicationGate` used to
/// validate publication tickets. Publish with `publish(_:ticket:owned:receive:)`;
/// drain queued publications with `drain()`. See the file header for the full
/// semantics contract.
public final class MonaProviderExecutor {

    /// The gate used to validate `MonaAsyncValidityTicket`s immediately before
    /// publication. A stale / cancelled ticket drops the publication silently.
    public let gate: MonaPublicationGate

    /// The single deterministic microtask queue every provider publication is
    /// serialized on (one queue, FIFO, deterministic order).
    public let queue: MonaMicrotaskQueue

    /// Creates an executor that validates publication tickets against `gate`
    /// and serializes publication on `queue` (a fresh queue by default).
    public init(gate: MonaPublicationGate, queue: MonaMicrotaskQueue = MonaMicrotaskQueue()) {
        self.gate = gate
        self.queue = queue
    }

    /// Drains the publication queue: runs every queued publication in FIFO
    /// order until the queue is empty. Forwarded to `queue.drain()`.
    public func drain() {
        queue.drain()
    }

    /// Normalizes `result` onto the publication path, validating `ticket`
    /// immediately before publication and releasing every owned provider /
    /// resource list exactly once.
    ///
    /// - Returns: `true` when the result was accepted onto the publication path
    ///   (enqueued on the microtask queue, or — for the asynchronous /
    ///   resolvable shapes — armed to enqueue on settlement). `false` when the
    ///   shape normalized to "no value to publish" (a nil optional, a thrown
    ///   body, or an already-cancelled token); in that case the owned list is
    ///   released exactly once synchronously and nothing is enqueued.
    ///
    /// For an accepted result, `receive` runs ONLY inside a microtask on
    /// `queue`, after `drain()` is called. A stale / cancelled ticket drops the
    /// publication silently at publication time (`receive` is never invoked) but
    /// still releases the owned list exactly once.
    @discardableResult
    public func publish<Value>(
        _ result: MonaProviderResult<Value>,
        ticket: MonaAsyncValidityTicket,
        owned: [MonaDisposable] = [],
        receive: @escaping (Value) -> Void
    ) -> Bool {
        switch result {

        case .synchronous(let value):
            // Immediate value: enqueue on the publication path.
            return enqueuePublication(ticket, value: value, owned: owned, receive: receive)

        case .asynchronous(let provider):
            // Deferred: the executor creates the resolver, hands it to the
            // provider, and observes settlement.
            let resolver = MonaProviderResolver<Value>()
            provider(resolver)
            observeResolver(resolver, ticket: ticket, owned: owned, receive: receive)
            return true

        case .optional(let maybeValue):
            // Optional: nil has no value to publish. Release owned and drop.
            guard let value = maybeValue else {
                releaseOwned(owned)
                return false
            }
            return enqueuePublication(ticket, value: value, owned: owned, receive: receive)

        case .throwing(let body):
            // Throwing: a thrown body has no value to publish. Catch, release,
            // and drop.
            do {
                let value = try body()
                return enqueuePublication(ticket, value: value, owned: owned, receive: receive)
            } catch {
                releaseOwned(owned)
                return false
            }

        case .cancelable(let token, let value):
            // Cancelable: an already-cancelled token suppresses publication.
            if token.isCancellationRequested {
                releaseOwned(owned)
                return false
            }
            return enqueuePublication(ticket, value: value, owned: owned, receive: receive)

        case .resolvable(let resolver):
            // Resolvable: observe an externally-created resolver.
            observeResolver(resolver, ticket: ticket, owned: owned, receive: receive)
            return true

        case .releasable(let value, let releaseList):
            // Releasable: the value plus a release list — combine with the
            // caller-supplied owned list and release exactly once after
            // publication.
            let combined = owned + releaseList
            return enqueuePublication(ticket, value: value, owned: combined, receive: receive)
        }
    }

    // MARK: - Normalized publication path

    /// Enqueues a microtask that validates `ticket` immediately before
    /// publication: if the ticket is fresh, `receive(value)` runs (the
    /// publication side effect); if stale / cancelled, `receive` is never
    /// invoked (silent drop). In both cases the owned list is released exactly
    /// once. Always enqueues (returns `true`).
    @discardableResult
    internal func enqueuePublication<Value>(
        _ ticket: MonaAsyncValidityTicket,
        value: Value,
        owned: [MonaDisposable],
        receive: @escaping (Value) -> Void
    ) -> Bool {
        let gate = self.gate
        // Serialize publication on the one deterministic microtask queue.
        queue.enqueue {
            // Validate the ticket immediately before publication. A stale /
            // cancelled ticket drops the publication SILENTLY: `receive` is
            // never invoked, so none of its side effects occur.
            if gate.validate(ticket) {
                receive(value)
            }
            // Release every owned list exactly once — whether the publication
            // ran or was dropped. `MonaDisposable.dispose()` is idempotent, so
            // disposing each owned item once is exactly-once release.
            for disposable in owned {
                disposable.dispose()
            }
        }
        return true
    }

    /// Observes `resolver` and, on success, enqueues the publication on the one
    /// microtask queue (ticket validated at publication time). On rejection,
    /// releases the owned list exactly once (no publication).
    internal func observeResolver<Value>(
        _ resolver: MonaProviderResolver<Value>,
        ticket: MonaAsyncValidityTicket,
        owned: [MonaDisposable],
        receive: @escaping (Value) -> Void
    ) {
        resolver.onSettled { [weak self] result in
            guard let self else {
                // Executor gone: still release the owned list to avoid a leak.
                for disposable in owned {
                    disposable.dispose()
                }
                return
            }
            switch result {
            case .success(let value):
                _ = self.enqueuePublication(ticket, value: value, owned: owned, receive: receive)
            case .failure:
                // Rejected: no value to publish. Release owned exactly once.
                self.releaseOwned(owned)
            }
        }
    }

    /// Releases every owned provider / resource list exactly once. Each item is
    /// disposed once; `MonaDisposable.dispose()` is idempotent, so any external
    /// second dispose is a no-op.
    internal func releaseOwned(_ owned: [MonaDisposable]) {
        for disposable in owned {
            disposable.dispose()
        }
    }
}
