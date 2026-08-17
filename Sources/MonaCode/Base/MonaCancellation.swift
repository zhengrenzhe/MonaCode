// MonaCancellation.swift
//
// P01-T006 — Implement cancellation tokens and sources.
//
// `MonaCancellationToken` is the immutable cancellation token — the Swift
// counterpart of Monaco's `CancellationToken` (monaco-editor 0.56.0, vendored
// from vscode's `vs/base/common/cancellation.ts`). A token is an immutable view
// onto the cancellation state of a `MonaCancellationTokenSource`: it reports
// `isCancellationRequested` and accepts `onCancellationRequested` listeners.
//
// `MonaCancellationTokenSource` is the mutable owner of cancellation state —
// the Swift counterpart of Monaco's `CancellationTokenSource`. `cancel()`
// fires cancellation exactly once; `createChild()` links a child source whose
// cancellation is propagated from the parent but whose disposal does not
// propagate upward.
//
// Semantics ported from Monaco and frozen by B1-R:
//
//   - `none` (never cancels) and `cancelled` (already cancelled) singletons.
//   - `cancel()` fires cancellation exactly once; repeat calls are no-ops.
//   - Comparator-order delivery: listeners registered before `cancel()` fire
//     in registration order; a listener registered AFTER cancellation fires
//     immediately and synchronously at registration time.
//   - The disposable returned by `onCancellationRequested` removes the listener;
//     if the listener has already fired (source cancelled), disposal is a
//     no-op (idempotent).
//   - Child sources (via `createChild()`): disposing a child detaches it from
//     its parent WITHOUT canceling the parent (and without firing the child's
//     listeners). Parent `cancel()` cancels every still-attached child, and
//     the propagation continues transitively through grandchildren. A child
//     created after the parent has already been cancelled starts cancelled.
//   - `dispose()` of a source is distinct from `cancel()`: it tears down the
//     listener list and detaches from the parent/children without firing any
//     listener. After `dispose()`, `cancel()` is a no-op and
//     `onCancellationRequested` returns an inert disposable (unless the source
//     was already cancelled, in which case late listeners still fire).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An immutable cancellation token — a view onto the cancellation state owned
/// by a `MonaCancellationTokenSource`.
///
/// A token value can be passed around freely: it is a struct wrapping a
/// reference to the underlying state, so copies share the same observation
/// point. `isCancellationRequested` reflects the live state; it never changes
/// for `MonaCancellationToken.none` and is always `true` for
/// `MonaCancellationToken.cancelled`.
///
/// `@unchecked Sendable`: the token's underlying state is guarded by an
/// `NSLock` (for live sources) or is immutable (for the `none`/`cancelled`
/// singletons), so it is safe to share a token across concurrency-isolation
/// boundaries — which is the intended use of a cancellation token.
public struct MonaCancellationToken: @unchecked Sendable {

    /// The underlying state. `internal` so external code cannot construct a
    /// token directly; it obtains one via `none`, `cancelled`, or
    /// `MonaCancellationTokenSource.token`.
    internal let state: MonaCancellationState

    /// A token whose cancellation is never requested.
    ///
    /// `onCancellationRequested` listeners registered on this token never fire;
    /// the returned disposable is inert.
    public static let none: MonaCancellationToken = MonaCancellationToken(
        state: MonaCancellationNoneState()
    )

    /// A token that is already cancelled.
    ///
    /// `onCancellationRequested` listeners registered on this token fire
    /// immediately and synchronously at registration time; the returned
    /// disposable is inert.
    public static let cancelled: MonaCancellationToken = MonaCancellationToken(
        state: MonaCancellationCancelledState()
    )

    /// `true` when cancellation has been requested on the owning source.
    public var isCancellationRequested: Bool {
        return state.isCancellationRequested
    }

    /// Registers `listener` to be invoked when cancellation is requested.
    ///
    /// - If the source is already cancelled, `listener` fires immediately and
    ///   synchronously, and the returned disposable is inert.
    /// - If the source is not yet cancelled, `listener` is stored and fires
    ///   when `cancel()` runs. The returned disposable removes `listener`; if
    ///   called after `listener` has already fired, it is a no-op.
    /// - If the source has been disposed without cancellation, the returned
    ///   disposable is inert (the listener will never fire).
    @discardableResult
    public func onCancellationRequested(
        _ listener: @escaping () -> Void
    ) -> MonaDisposable {
        return state.register(listener)
    }
}

/// The internal cancellation-state abstraction shared by the `none`/
/// `cancelled` singletons and the live source state.
internal protocol MonaCancellationState: AnyObject {

    /// Whether cancellation has been requested.
    var isCancellationRequested: Bool { get }

    /// Registers a listener; returns a disposable that removes it (or an inert
    /// disposable if the listener will never fire).
    func register(_ listener: @escaping () -> Void) -> MonaDisposable
}

/// State for `MonaCancellationToken.none`: never cancels, listeners never fire.
internal final class MonaCancellationNoneState: MonaCancellationState {

    var isCancellationRequested: Bool { false }

    func register(_ listener: @escaping () -> Void) -> MonaDisposable {
        // The token never cancels, so the listener can never fire. Return an
        // inert disposable.
        return MonaDisposableImpl({ })
    }
}

/// State for `MonaCancellationToken.cancelled`: already cancelled, listeners
/// fire immediately and synchronously at registration time.
internal final class MonaCancellationCancelledState: MonaCancellationState {

    var isCancellationRequested: Bool { true }

    func register(_ listener: @escaping () -> Void) -> MonaDisposable {
        // Fire immediately, synchronously. The returned disposable is inert.
        listener()
        return MonaDisposableImpl({ })
    }
}

/// The live cancellation state owned by a `MonaCancellationTokenSource`.
///
/// Reference type so the parent/child link and the listener list are shared
/// across the source, its token, and any disposables handed out for listener
/// removal. All mutable state is guarded by `_lock`.
internal final class MonaCancellationLiveState: MonaCancellationState {

    /// A registered listener. A reference type so the `removed` flag is shared
    /// between the live listener list and any removal disposable, mirroring
    /// `MonaEmitter.Listener`.
    private final class Listener {
        let callback: () -> Void
        var removed: Bool
        init(callback: @escaping () -> Void) {
            self.callback = callback
            self.removed = false
        }
    }

    private let _lock = NSLock()
    private var _cancelled = false
    private var _disposed = false
    private var _listeners: [Listener] = []
    private var _children: [MonaCancellationLiveState] = []
    private weak var _parent: MonaCancellationLiveState?

    var isCancellationRequested: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _cancelled
    }

    func register(_ listener: @escaping () -> Void) -> MonaDisposable {
        _lock.lock()
        if _cancelled {
            _lock.unlock()
            // Already cancelled: fire immediately and synchronously, return an
            // inert disposable. This is the comparator-order "fire-immediately"
            // behavior for listeners registered after cancellation.
            listener()
            return MonaDisposableImpl({ })
        }
        if _disposed {
            _lock.unlock()
            // Disposed without cancellation: the listener will never fire.
            return MonaDisposableImpl({ })
        }
        let entry = Listener(callback: listener)
        _listeners.append(entry)
        _lock.unlock()
        return MonaDisposableImpl { [weak self] in
            self?.remove(entry)
        }
    }

    /// Requests cancellation. Idempotent: the first call fires the registered
    /// listeners in registration order and cancels every still-attached child;
    /// every subsequent call is a no-op. After `dispose()`, `cancel()` is a
    /// no-op.
    func cancel() {
        var toFire: [() -> Void] = []
        var childrenSnapshot: [MonaCancellationLiveState] = []
        _lock.lock()
        if _cancelled || _disposed {
            _lock.unlock()
            return
        }
        _cancelled = true
        for entry in _listeners where !entry.removed {
            toFire.append(entry.callback)
            entry.removed = true
        }
        _listeners.removeAll()
        childrenSnapshot = _children
        _lock.unlock()

        // Fire this source's own listeners first (comparator order: parent's
        // own listeners precede child listeners), then propagate to children.
        for callback in toFire {
            callback()
        }
        for child in childrenSnapshot {
            child.cancel()
        }
    }

    /// Creates a child state linked to this state. If this state is already
    /// cancelled, the child is cancelled immediately so that its token reports
    /// `isCancellationRequested == true` and late listeners fire.
    func createChild() -> MonaCancellationLiveState {
        let child = MonaCancellationLiveState()
        var alreadyCancelled = false
        _lock.lock()
        if !_disposed {
            _children.append(child)
            child._parent = self
            alreadyCancelled = _cancelled
        } else {
            alreadyCancelled = _cancelled
        }
        _lock.unlock()
        if alreadyCancelled {
            // Parent already cancelled (or disposed-but-cancelled): the child
            // must observe cancellation. If the parent was merely disposed
            // (not cancelled), `alreadyCancelled` is false and the child stays
            // live but detached.
            child.cancel()
        }
        return child
    }

    /// Tears down this state without firing listeners. Detaches from the
    /// parent (so the parent will not try to cancel this child again) and
    /// detaches from children (so they no longer hold a parent reference).
    /// Idempotent.
    func dispose() {
        var parentRef: MonaCancellationLiveState? = nil
        var childrenSnapshot: [MonaCancellationLiveState] = []
        _lock.lock()
        if _disposed {
            _lock.unlock()
            return
        }
        _disposed = true
        _listeners.removeAll()
        parentRef = _parent
        childrenSnapshot = _children
        _children.removeAll()
        _parent = nil
        _lock.unlock()

        // Detach from parent without canceling it.
        if let parent = parentRef {
            parent.removeChild(self)
        }
        // Children become orphans; we do NOT cancel or dispose them. They keep
        // their own (independent) cancellation state.
        for child in childrenSnapshot {
            child.detachParent()
        }
    }

    // MARK: - Private

    /// Removes `entry` from the listener list (if still present) and marks it
    /// removed so any in-flight snapshot skips it. Idempotent.
    private func remove(_ entry: Listener) {
        _lock.lock()
        if let index = _listeners.firstIndex(where: { $0 === entry }) {
            _listeners.remove(at: index)
        }
        entry.removed = true
        _lock.unlock()
    }

    /// Removes `child` from this state's child list. Called by a child during
    /// its own disposal.
    private func removeChild(_ child: MonaCancellationLiveState) {
        _lock.lock()
        if let index = _children.firstIndex(where: { $0 === child }) {
            _children.remove(at: index)
        }
        _lock.unlock()
    }

    /// Clears the parent back-reference. Called by the parent during its own
    /// disposal so children do not retain a dangling parent link.
    private func detachParent() {
        _lock.lock()
        _parent = nil
        _lock.unlock()
    }
}

/// The mutable owner of cancellation state — the Swift counterpart of Monaco's
/// `CancellationTokenSource`.
///
/// Create with `init()`. Observe via `token`. Fire cancellation with `cancel()`.
/// Link child sources with `createChild()`. Tear down with `dispose()` (which
/// is distinct from `cancel()` and does not fire listeners). Conforms to
/// `MonaDisposable` so a source can be registered with lifetime registries.
public final class MonaCancellationTokenSource: MonaDisposable {

    internal let state: MonaCancellationLiveState

    /// Creates a new, uncancelled token source.
    public init() {
        self.state = MonaCancellationLiveState()
    }

    /// Internal initializer used by `createChild()` to wrap an existing live
    /// state (linked to a parent).
    internal init(state: MonaCancellationLiveState) {
        self.state = state
    }

    /// The immutable token observing this source's cancellation state.
    public var token: MonaCancellationToken {
        return MonaCancellationToken(state: state)
    }

    /// Requests cancellation. Idempotent: the first call fires registered
    /// listeners in registration order and cancels every still-attached child
    /// (transitively); every subsequent call is a no-op. After `dispose()`,
    /// `cancel()` is a no-op.
    public func cancel() {
        state.cancel()
    }

    /// Creates a child token source linked to this source.
    ///
    /// - Disposing the child does NOT cancel this parent.
    /// - Calling `cancel()` on this parent cancels every still-attached child
    ///   (transitively through grandchildren).
    /// - If this parent is already cancelled when `createChild()` is called,
    ///   the child starts cancelled.
    public func createChild() -> MonaCancellationTokenSource {
        return MonaCancellationTokenSource(state: state.createChild())
    }

    /// Tears down this source: clears its listener list and detaches it from
    /// its parent and children. Does NOT fire listeners (distinct from
    /// `cancel()`). Idempotent.
    public func dispose() {
        state.dispose()
    }
}
