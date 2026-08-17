// MonaEventControl.swift
//
// P04-T007 — Implement public EventControl and native event adaptation.
//
// `MonaEventControl` is the mutable, imperative handle a PUBLIC event callback
// uses to signal the dispatch decision for an input event. It exposes EXPLICIT
// prevent-default and stop-propagation state transitions:
//
//   - `preventDefault()`   — records that the platform should suppress its
//                             default behavior for the event.
//   - `stopPropagation()`  — records that the event should stop bubbling up
//                             the responder chain / DOM-equivalent.
//   - `isDefaultPrevented`   — `true` once `preventDefault()` has been called.
//   - `isPropagationStopped` — `true` once `stopPropagation()` has been called.
//
// State transitions are EXPLICIT, not implicit: a freshly constructed control
// is always all-false (the constructor takes no prevent-default /
// stop-propagation argument), and a flag becomes true only when the
// corresponding method is called. The transitions are one-way (there is no
// public reset), mirroring the browser `Event.defaultPrevented` contract.
//
// The two flags are independent — a handler may prevent the platform default
// while letting the event bubble, or stop propagation without claiming the
// default should be suppressed. This mirrors `MonaKeyDispatchOutcome`
// (P04-T001), where `preventDefault` and `stopPropagation` are likewise
// independent booleans.
//
// `MonaEventControl` is deliberately a `final class` (reference type), not a
// struct. The dispatch code that owns the event and the public callback that
// receives it share ONE control instance: a mutation made inside the callback
// (`control.preventDefault()`) is immediately observable by the dispatch code
// that reads `control.isDefaultPrevented` after the callback returns. With a
// struct, the callback's mutation would not propagate back without `inout`
// plumbing through every callback signature. This is the same reason the
// browser `Event` is a reference type.
//
// The control is DECOUPLED from the immutable public event snapshot
// (`MonaPublicKeyboardEvent` etc.). The public event carries the native-adapted
// fields the callback READS; the control carries the dispatch decision the
// callback WRITES. The event never holds a control reference, so a callback
// cannot reach back through the event to mutate native state — and mutating the
// control never alters the event's fields.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A mutable handle exposing explicit prevent-default and stop-propagation
/// state transitions for a public event callback.
///
/// A `final class` (reference type) so that a mutation made inside a callback
/// is observable by the dispatch code sharing the same instance. State starts
/// clean (both flags `false`) and transitions only via `preventDefault()` /
/// `stopPropagation()`; the transitions are one-way.
///
/// Used alongside the immutable public event snapshot: the callback reads the
/// event fields and writes its dispatch decision through this control.
public final class MonaEventControl {

    /// `true` once `preventDefault()` has been called on this instance.
    ///
    /// Starts `false`; transitions to `true` only via `preventDefault()`. There
    /// is no public path back to `false`.
    private var _isDefaultPrevented: Bool = false

    /// `true` once `stopPropagation()` has been called on this instance.
    ///
    /// Starts `false`; transitions to `true` only via `stopPropagation()`. There
    /// is no public path back to `false`.
    private var _isPropagationStopped: Bool = false

    /// Creates a control with both flags `false`.
    ///
    /// The constructor takes no prevent-default / stop-propagation argument:
    /// state transitions are explicit, not implicit from construction.
    public init() {}

    /// `true` if `preventDefault()` has been called.
    public var isDefaultPrevented: Bool {
        return _isDefaultPrevented
    }

    /// `true` if `stopPropagation()` has been called.
    public var isPropagationStopped: Bool {
        return _isPropagationStopped
    }

    /// Records that the platform should suppress its default behavior for the
    /// event.
    ///
    /// One-way transition: sets `isDefaultPrevented` to `true`. Idempotent —
    /// calling it more than once has no additional effect. Independent of
    /// `stopPropagation()`.
    public func preventDefault() {
        _isDefaultPrevented = true
    }

    /// Records that the event should stop bubbling up the responder chain /
    /// DOM-equivalent.
    ///
    /// One-way transition: sets `isPropagationStopped` to `true`. Idempotent —
    /// calling it more than once has no additional effect. Independent of
    /// `preventDefault()`.
    public func stopPropagation() {
        _isPropagationStopped = true
    }
}
