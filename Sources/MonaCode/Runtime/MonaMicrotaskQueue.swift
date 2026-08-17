// MonaMicrotaskQueue.swift
//
// P05-T013 — Implement deterministic provider execution and microtask publication.
//
// `MonaMicrotaskQueue` is the deterministic microtask queue — the Swift
// counterpart of the single publication queue Monaco drains provider results
// through before they may write back into the model (monaco-editor 0.56.0).
// Provider publications are SERIALIZED on one queue: microtasks enqueue in
// insertion order and drain FIFO, so the order of publication is fully
// determined by the order of enqueue calls (no non-deterministic concurrency).
//
// Semantics (frozen by G6-R P05-T013):
//
//   - FIFO drain: `drain()` processes queued microtasks in the order they were
//     enqueued. A microtask enqueued DURING a drain is appended to the tail and
//     is processed in the same drain cycle, after the currently-queued batch.
//   - Reentrancy-safe: a nested `drain()` call made while a drain is already
//     running is a no-op — the in-flight loop owns the drain and picks up newly
//     enqueued microtasks itself.
//   - Deterministic: the sequence of `enqueue` / `drain` calls fully determines
//     the order in which microtasks run. `drain()` is synchronous and runs the
//     microtasks on the calling thread.
//   - `enqueue` never auto-drains: the caller controls when publication drains,
//     so tests and hosts can observe determinism (enqueue N, drain once, verify
//     order).
//
// The queue reuses the established lock + delivery-loop pattern from
// `MonaEmitter` (P01-T005): an `NSLock`-guarded pending array, an
// `_isDraining` reentrancy guard, and a loop that pulls the head until empty.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A deterministic microtask queue: one queue, FIFO, deterministic order.
///
/// Create with `init()`. Enqueue with `enqueue(_:)`; drain with `drain()`. See
/// the file header for the full semantics contract.
public final class MonaMicrotaskQueue {

    /// Creates an empty microtask queue.
    public init() {}

    private let _lock = NSLock()
    /// The pending microtasks, in enqueue (FIFO) order. Head is index 0.
    private var _pending: [() -> Void] = []
    /// Reentrancy guard: `true` while a drain loop is running.
    private var _isDraining = false

    /// The number of microtasks queued but not yet drained.
    public var pendingCount: Int {
        _lock.lock()
        defer { _lock.unlock() }
        return _pending.count
    }

    /// `true` while a `drain()` loop is running on this queue.
    public var isDraining: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _isDraining
    }

    /// Enqueues `microtask` at the tail of the queue.
    ///
    /// `enqueue` never auto-drains: the microtask runs only when `drain()` is
    /// next called. Enqueuing during an active drain appends to the tail; the
    /// in-flight loop processes it in the same drain cycle.
    public func enqueue(_ microtask: @escaping () -> Void) {
        _lock.lock()
        _pending.append(microtask)
        _lock.unlock()
    }

    /// Drains the queue: processes every queued microtask in FIFO order,
    /// including microtasks enqueued during this drain, until the queue is
    /// empty.
    ///
    /// Reentrancy-safe: a nested `drain()` call made while a drain is already
    /// running is a no-op (the in-flight loop owns the drain). Synchronous: runs
    /// all microtasks on the calling thread before returning.
    public func drain() {
        // Reentrancy guard: if a drain is already running on this queue, the
        // in-flight loop will pick up anything we enqueue; this call returns.
        _lock.lock()
        if _isDraining {
            _lock.unlock()
            return
        }
        _isDraining = true
        _lock.unlock()

        // Pull the head until empty. Microtasks enqueued during the loop are
        // appended to the tail and processed in the same cycle (FIFO).
        while true {
            _lock.lock()
            if _pending.isEmpty {
                _isDraining = false
                _lock.unlock()
                return
            }
            let microtask = _pending.removeFirst()
            _lock.unlock()
            microtask()
        }
    }
}
