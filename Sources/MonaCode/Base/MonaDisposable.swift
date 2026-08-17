// MonaDisposable.swift
//
// P01-T005 — Implement deterministic events and idempotent disposal.
//
// `MonaDisposable` is the base-model disposal protocol: a single `dispose()`
// entry point that releases a resource (an event-listener subscription, an
// emitter, a cancellation registration, …). Disposal is idempotent — disposing
// an already-disposed resource is a no-op — mirroring Monaco's `IDisposable`
// (monaco-editor 0.56.0, vendored from vscode's `vs/base/common/lifecycle.ts`).
//
// The protocol is class-bound (`AnyObject`): disposal mutates shared state
// (the "already disposed" guard), so conforming types are reference types.
// This matches Monaco, where `IDisposable` is implemented by classes.
//
// `MonaDisposableImpl` is the concrete idempotent disposable: it wraps a single
// disposal action and runs it at most once. Disposing twice (or any further
// number of times) is a no-op. The wrapped action runs outside the internal
// lock so a reentrant disposal (an action that itself disposes another
// resource) cannot deadlock.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A disposable resource.
///
/// Conforming types are reference types (`AnyObject`): `dispose()` mutates
/// shared disposal state. `dispose()` is idempotent — calling it on an
/// already-disposed instance is a no-op and must never trap.
public protocol MonaDisposable: AnyObject {

    /// Releases the resource this disposable owns.
    ///
    /// Idempotent: disposing an already-disposed resource is a no-op. Safe to
    /// call any number of times.
    func dispose()
}

/// A concrete idempotent disposable wrapping a single disposal action.
///
/// The action passed to `init(_:)` runs at most once: the first `dispose()`
/// runs it and clears it; every subsequent `dispose()` is a no-op. This is the
/// Swift counterpart of Monaco's `Disposable` / `toDisposable()` helpers and is
/// the value returned by `MonaEmitter.event` for listener removal.
public final class MonaDisposableImpl: MonaDisposable {

    private let lock = NSLock()
    // `nil` after the first `dispose()`, which makes disposal idempotent.
    private var action: (() -> Void)?

    /// Creates a disposable that runs `action` the first time `dispose()` is
    /// called.
    public init(_ action: @escaping () -> Void) {
        self.action = action
    }

    public func dispose() {
        // Swap the action out under the lock, then run it outside the lock.
        // Running outside the lock means a reentrant disposal (an action that
        // disposes another resource) cannot deadlock, and a second `dispose()`
        // finds `action == nil` and becomes a no-op.
        lock.lock()
        let pending = action
        action = nil
        lock.unlock()
        pending?()
    }
}
