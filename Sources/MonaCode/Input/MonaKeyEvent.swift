// MonaKeyEvent.swift
//
// P04-T001 — Define platform-neutral keyboard event semantics in Core.
//
// `MonaKeyEvent` is a platform-neutral keyboard event. It carries the values
// the Core input pipeline needs to resolve keybindings, drive IME
// composition, and decide dispatch — without referencing any platform type
// (no AppKit `NSEvent`, no UIKit, no SwiftUI). The platform layer (AppKit on
// macOS) constructs a `MonaKeyEvent` from a native event at exactly one
// gateway (P04-T002), and the rest of Core operates on this neutral form.
//
// Fields (all immutable):
//
//   - `keyCode: MonaKeyCode`  — the logical key code (P01-T004). The 134 known
//                               codes (`-1 … 132`) are static constants; any
//                               other integer is carried via
//                               `MonaKeyCode.custom(_:)` and preserved WITHOUT
//                               being collapsed to a known case.
//   - `keyText: String?`      — scan-independent produced text. This is the
//                               text the key produces (e.g. "a", "A", "1",
//                               "\n"), resolved independently of the physical
//                               scan code, so the same physical key can yield
//                               different `keyText` under different layouts
//                               (QWERTY vs Dvorak) or modifier states. `nil`
//                               for non-printing keys (arrows, function keys,
//                               modifier-only presses).
//   - `modifiers: MonaKeyMod` — the active modifier set (P01-T004), an
//                               `OptionSet` over Monaco's bit layout.
//   - `isRepeat: Bool`        — `true` when this event is a hardware key
//                               repeat (the key was held), not a fresh press.
//   - `isComposing: Bool`    — `true` while an IME composition is in progress.
//   - `timestamp: Double`    — the event timestamp, in the platform's native
//                               time base, carried verbatim for ordering.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A platform-neutral keyboard event.
///
/// Constructed once at the platform boundary (e.g. `MonaAppKeyEventGateway` on
/// macOS) and consumed by the Core keybinding resolver, composition arbiter, and
/// dispatch path. Carries no platform type; the platform layer reads the
/// resolved `MonaKeyDispatchOutcome` and applies it at the native boundary.
public struct MonaKeyEvent: Equatable, Hashable, Sendable {

    /// The logical key code (P01-T004). Unknown numeric values are accepted
    /// via `MonaKeyCode.custom(_:)` and preserved without collapse.
    public let keyCode: MonaKeyCode

    /// The scan-independent text the key produces, or `nil` for non-printing
    /// keys. Independent of the physical scan code, so layout and modifier
    /// variations surface here.
    public let keyText: String?

    /// The active modifier set (P01-T004), an `OptionSet` over Monaco's bit
    /// layout (`CtrlCmd`, `Shift`, `Alt`, `WinCtrl`).
    public let modifiers: MonaKeyMod

    /// `true` when this event is a hardware key repeat (key held), not a fresh
    /// press.
    public let isRepeat: Bool

    /// `true` while an IME composition is in progress.
    public let isComposing: Bool

    /// The event timestamp in the platform's native time base, carried verbatim
    /// for ordering.
    public let timestamp: Double

    /// Creates a platform-neutral keyboard event.
    ///
    /// All fields are set at construction; the instance is immutable.
    public init(
        keyCode: MonaKeyCode,
        keyText: String?,
        modifiers: MonaKeyMod,
        isRepeat: Bool,
        isComposing: Bool,
        timestamp: Double
    ) {
        self.keyCode = keyCode
        self.keyText = keyText
        self.modifiers = modifiers
        self.isRepeat = isRepeat
        self.isComposing = isComposing
        self.timestamp = timestamp
    }
}
