// MonaEmitter.swift
//
// P01-T005 — Implement deterministic events and idempotent disposal.
//
// `MonaEmitter<T>` is the base-model event emitter — the Swift counterpart of
// Monaco's `Emitter<T>` (monaco-editor 0.56.0, vendored from vscode's
// `vs/base/common/event.ts`). It is a `final class` (reference type) so that
// its listener list and delivery queue are shared across all references to one
// instance, matching Monaco.
//
// Semantics ported from Monaco and frozen by B1-R:
//
//   - Subscription order: listeners are delivered in the order they were
//     registered (insertion order). Removal and disposal take effect before
//     the dispatch reaches a not-yet-delivered listener, so a listener removed
//     mid-dispatch does not receive the current event.
//   - Snapshot-end delivery queue: `fire(_:)` takes a snapshot of the live
//     listener list at the moment of the call and enqueues it. The current
//     snapshot drains to completion before any nested `fire` is processed
//     (nested fires are enqueued and delivered FIFO after the current event).
//   - Additions during dispatch observe the NEXT dispatch only: a listener
//     registered while an event is being delivered is appended to the live
//     list but is NOT part of the in-flight snapshot, so it does not receive
//     the current event — it receives the next `fire`.
//   - Listener failures: a listener callback may throw; the error is routed
//     through the declared `onListenerError` boundary and delivery continues to
//     later listeners (failures never truncate the dispatch). `fire` itself is
//     non-throwing.
//   - Idempotent disposal: `dispose()` is a no-op when called again. After
//     dispose, `fire` is a no-op and `event` (subscribe) returns an inert
//     `MonaDisposable` (the listener is never registered). Disposing mid-dispatch
//     stops not-yet-delivered listeners and drops pending nested fires.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Options configuring a `MonaEmitter`.
public struct MonaEmitterOptions {

    /// Invoked once, synchronously, when the first listener is added.
    public var onFirstListenerDidAdd: (() -> Void)?

    /// Invoked synchronously when the listener count drops to zero (the last
    /// listener is removed, or the emitter is disposed while it still had
    /// listeners).
    public var onNoListeners: (() -> Void)?

    /// The declared error boundary for listener failures. When a listener
    /// callback throws, the thrown error is reported here. Delivery continues
    /// to later listeners regardless. If `nil`, listener failures are swallowed
    /// (contained), matching Monaco's behavior when no error handler is wired.
    public var onListenerError: ((Error) -> Void)?

    public init(
        onFirstListenerDidAdd: (() -> Void)? = nil,
        onNoListeners: (() -> Void)? = nil,
        onListenerError: ((Error) -> Void)? = nil
    ) {
        self.onFirstListenerDidAdd = onFirstListenerDidAdd
        self.onNoListeners = onNoListeners
        self.onListenerError = onListenerError
    }
}

/// A deterministic, reentrancy-safe event emitter.
///
/// Create with `MonaEmitter<T>(options:)`. Subscribe via `event`; fire via
/// `fire(_:)`; tear down via `dispose()`. See the file header for the full
/// semantics contract.
public final class MonaEmitter<T>: MonaDisposable {

    /// Creates an emitter with the given options.
    public init(options: MonaEmitterOptions = MonaEmitterOptions()) {
        _options = options
    }

    /// The typed subscribe function for this emitter.
    ///
    /// Calling the returned value with a listener registers that listener and
    /// returns a `MonaDisposable` whose `dispose()` removes it. After the
    /// emitter is disposed, this returns an inert disposable (the listener is
    /// never registered).
    public var event: MonaEvent<T> {
        return { [weak self] listener in
            guard let self else {
                return MonaDisposableImpl({ })
            }
            return self.addListener(listener)
        }
    }

    /// Fires `event` to all registered listeners in subscription order.
    ///
    /// Synchronous and non-throwing: any listener failure is routed through
    /// the declared `onListenerError` boundary and delivery continues. After
    /// `dispose()`, `fire` is a no-op.
    public func fire(_ event: T) {
        var snapshot: [Listener] = []
        var shouldDeliver = false
        _lock.lock()
        if !_disposed {
            snapshot = _listeners
            _deliveryQueue.append(Entry(snapshot: snapshot, event: event))
            if !_isDelivering {
                _isDelivering = true
                shouldDeliver = true
            }
        }
        _lock.unlock()
        if shouldDeliver {
            runDeliveryLoop()
        }
    }

    /// Disposes the emitter and all of its listener subscriptions.
    ///
    /// Idempotent: calling it again is a no-op. Disposing mid-dispatch stops
    /// not-yet-delivered listeners (they are marked removed) and drops any
    /// pending nested fires. After dispose, `fire` is a no-op and `event`
    /// returns an inert disposable.
    public func dispose() {
        var captured: [Listener] = []
        var noListeners: (() -> Void)?
        _lock.lock()
        if !_disposed {
            _disposed = true
            captured = _listeners
            _listeners.removeAll()
            _deliveryQueue.removeAll()
            if !captured.isEmpty {
                noListeners = _options.onNoListeners
            }
        }
        _lock.unlock()
        for listener in captured {
            listener.removed = true
        }
        noListeners?()
    }

    // MARK: - Private

    /// A registered listener. A reference type so the `removed` flag is shared
    /// between the live listener list and any in-flight delivery snapshot: a
    /// removal during dispatch is observed by the snapshot and skips that
    /// listener.
    private final class Listener {
        let callback: (T) throws -> Void
        var removed: Bool
        init(callback: @escaping (T) throws -> Void) {
            self.callback = callback
            self.removed = false
        }
    }

    /// One queued delivery: a snapshot of the listeners at `fire` time and the
    /// event to deliver.
    private struct Entry {
        let snapshot: [Listener]
        let event: T
    }

    private let _options: MonaEmitterOptions
    private let _lock = NSLock()
    private var _listeners: [Listener] = []
    private var _deliveryQueue: [Entry] = []
    private var _isDelivering = false
    private var _disposed = false

    /// Registers `callback` and returns a removal disposable.
    private func addListener(_ callback: @escaping (T) throws -> Void) -> MonaDisposable {
        let listener = Listener(callback: callback)
        var firstAdd: (() -> Void)?
        _lock.lock()
        if _disposed {
            _lock.unlock()
            // Subscribe after dispose: return an inert disposable. The listener
            // is never registered, so `fire` will never invoke it.
            return MonaDisposableImpl({ })
        }
        let wasEmpty = _listeners.isEmpty
        _listeners.append(listener)
        if wasEmpty {
            firstAdd = _options.onFirstListenerDidAdd
        }
        _lock.unlock()
        firstAdd?()
        return MonaDisposableImpl { [weak self] in
            self?.removeListener(listener)
        }
    }

    /// Removes `listener` from the live list and marks it removed so any
    /// in-flight snapshot skips it.
    private func removeListener(_ listener: Listener) {
        var noListeners: (() -> Void)?
        _lock.lock()
        if let index = _listeners.firstIndex(where: { $0 === listener }) {
            _listeners.remove(at: index)
        }
        listener.removed = true
        if _listeners.isEmpty {
            noListeners = _options.onNoListeners
        }
        _lock.unlock()
        noListeners?()
    }

    /// Drains the delivery queue. The outermost `fire` starts this loop; nested
    /// `fire` calls only enqueue, because `_isDelivering` is already true. Each
    /// entry's snapshot drains fully before the next entry, so the current
    /// event finishes before any nested fire is processed.
    private func runDeliveryLoop() {
        while true {
            _lock.lock()
            if _deliveryQueue.isEmpty {
                _isDelivering = false
                _lock.unlock()
                return
            }
            let entry = _deliveryQueue.removeFirst()
            _lock.unlock()

            for listener in entry.snapshot {
                _lock.lock()
                let removed = listener.removed
                _lock.unlock()
                if removed { continue }
                do {
                    try listener.callback(entry.event)
                } catch {
                    _options.onListenerError?(error)
                }
            }
        }
    }
}
