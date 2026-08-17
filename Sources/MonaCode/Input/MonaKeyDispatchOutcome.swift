// MonaKeyDispatchOutcome.swift
//
// P04-T001 — Define platform-neutral keyboard event semantics in Core.
//
// `MonaKeyDispatchOutcome` is the dispatch *decision* a Core handler makes for
// a `MonaKeyEvent`. It is deliberately SEPARATE from platform dispatch: this
// value records what the platform layer (AppKit on macOS) should do, but it
// performs no dispatch itself and references no platform type. The platform
// layer reads these flags and applies them at the native boundary — calling
// `super.keyDown(with:)` (or not), stopping responder-chain propagation (or
// not), etc.
//
// The three flags are independent booleans:
//
//   - `handled: Bool`          — did a Core handler consume the event? When
//                                 `false`, the platform may treat the event as
//                                 unhandled (e.g. fall through to default
//                                 input or the next responder).
//   - `preventDefault: Bool`   — should the platform suppress its default
//                                 behavior for this event (e.g. suppress the
//                                 beep on an unmapped Cmd+key, or stop the
//                                 system from inserting text)?
//   - `stopPropagation: Bool`  — should the event stop bubbling up the
//                                 responder chain / DOM-equivalent?
//
// `preventDefault` and `stopPropagation` are independent: a handler may
// prevent the platform default while letting the event bubble, or stop
// propagation without claiming the event was handled. This mirrors the
// browser `KeyboardEvent` semantics Monaco's web layer relies on.
//
// The default pass-through outcome (`MonaKeyDispatchOutcome.default`) is
// all-false — "let the platform do its default behavior".
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The dispatch decision for a `MonaKeyEvent`, separate from platform dispatch.
///
/// Core handlers (keybinding resolver, composition arbiter) return this value;
/// the platform layer reads `handled`, `preventDefault`, and `stopPropagation`
/// and applies them at the native boundary. Constructing this value performs no
/// platform action and requires no platform type.
public struct MonaKeyDispatchOutcome: Equatable, Hashable, Sendable {

    /// Did a Core handler consume the event? When `false`, the platform may
    /// treat the event as unhandled.
    public let handled: Bool

    /// Should the platform suppress its default behavior for this event?
    /// Independent of `stopPropagation` and `handled`.
    public let preventDefault: Bool

    /// Should the event stop bubbling up the responder chain? Independent of
    /// `preventDefault` and `handled`.
    public let stopPropagation: Bool

    /// Creates a dispatch decision.
    ///
    /// All three flags are set at construction; the instance is immutable.
    public init(
        handled: Bool,
        preventDefault: Bool,
        stopPropagation: Bool
    ) {
        self.handled = handled
        self.preventDefault = preventDefault
        self.stopPropagation = stopPropagation
    }

    /// The pass-through outcome: the event was not handled, and the platform
    /// should perform its default behavior without suppression or propagation
    /// stop. Equivalent to `MonaKeyDispatchOutcome(handled: false,
    /// preventDefault: false, stopPropagation: false)`.
    public static let `default` = MonaKeyDispatchOutcome(
        handled: false,
        preventDefault: false,
        stopPropagation: false
    )
}
