// MonaAppKeyEventGateway.swift
//
// P04-T002 — Translate AppKit key events through one native gateway.
//
// `MonaAppKeyEventGateway` is the SINGLE native boundary that translates an
// AppKit `NSEvent` (keyDown / keyUp) into the platform-neutral `MonaKeyEvent`
// (P04-T001). The rest of Core (keybinding resolver, composition arbiter,
// dispatch) operates on `MonaKeyEvent` and never touches `NSEvent`. This is the
// one place where AppKit key-event fields become Core values.
//
// Responsibilities:
//
//   1. Translate EXACTLY ONCE. Each `NSEvent` is mapped to one `MonaKeyEvent`
//      in a single, pure step. There is no re-translation path and no mutating
//      gateway state that could double-apply a translation.
//   2. Preserve the cases the Core pipeline must distinguish:
//        - dead-key        — `characters` is empty → `keyText` is nil.
//        - repeat          — `NSEvent.isARepeat` → `MonaKeyEvent.isRepeat`.
//        - function-key    — `.function` flag set → `keyText` nil (F-keys,
//                            arrows, nav).
//        - keypad          — `.numericPad` flag set; the keyCode maps to a
//                            `numpad*` code and produced text is preserved.
//        - modifier-only   — the keyCode maps to a modifier (.shift / .ctrl /
//                            .alt / .meta); `keyText` is nil.
//        - unrecognized    — the macOS key code is absent from the map →
//                            `MonaKeyCode.custom(_:)`, preserved without collapse.
//   3. Apply a `MonaKeyDispatchOutcome` at the native boundary, producing a
//      `MonaAppKeyDispatchAction` the `NSResponder` consumes:
//        - `outcome.preventDefault`  → suppress the NSEvent's default behavior
//          (do not call `super.keyDown`, do not feed the input context).
//        - `outcome.stopPropagation` → stop the responder chain.
//      `handled` is intentionally NOT conflated with `preventDefault`: per
//      P04-T001 the three outcome flags are independent, and the resolver sets
//      `preventDefault` explicitly when it wants default suppression.
//
// The IME composition state (`isComposing`) is not carried by `NSEvent`; the
// composition session (P04-T004) supplies it per call.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

/// The single native gateway that translates AppKit `NSEvent` keyDown/keyUp
/// events into platform-neutral `MonaKeyEvent` values, and applies Core
/// dispatch outcomes at the native boundary.
///
/// Stateless: two calls with equal inputs produce equal outputs. Construct one
/// per editor host (or share a singleton); it holds no per-event state.
public final class MonaAppKeyEventGateway {

    /// Creates a gateway. The gateway is stateless; the initializer exists so
    /// callers hold an instance (matching the "one native gateway per editor"
    /// boundary) rather than reaching for statics.
    public init() {}

    // MARK: - NSEvent → MonaKeyEvent

    /// Translates an `NSEvent` of type `.keyDown` into a `MonaKeyEvent`.
    ///
    /// - Parameters:
    ///   - event: The `.keyDown` `NSEvent`.
    ///   - isComposing: Whether an IME composition is in progress at the moment
    ///     of this event. `NSEvent` does not carry this; the composition session
    ///     (P04-T004) supplies it.
    /// - Returns: The platform-neutral `MonaKeyEvent`. Translated exactly once.
    public func translateKeyDown(_ event: NSEvent, isComposing: Bool = false) -> MonaKeyEvent {
        return translate(event, isComposing: isComposing)
    }

    /// Translates an `NSEvent` of type `.keyUp` into a `MonaKeyEvent`.
    ///
    /// `MonaKeyEvent` is phase-agnostic (it carries no keyDown/keyUp field), so
    /// a keyUp produces the same neutral values as a keyDown for the same
    /// physical event. The responder routes both through one gateway.
    ///
    /// - Parameters:
    ///   - event: The `.keyUp` `NSEvent`.
    ///   - isComposing: Whether an IME composition is in progress.
    /// - Returns: The platform-neutral `MonaKeyEvent`. Translated exactly once.
    public func translateKeyUp(_ event: NSEvent, isComposing: Bool = false) -> MonaKeyEvent {
        return translate(event, isComposing: isComposing)
    }

    /// The single translation step shared by `translateKeyDown`/`translateKeyUp`.
    ///
    /// Performing the translation in one private method guarantees there is no
    /// second translation path: every public entry point funnels through here,
    /// so an `NSEvent` becomes a `MonaKeyEvent` exactly once.
    private func translate(_ event: NSEvent, isComposing: Bool) -> MonaKeyEvent {
        let keyCode = MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: Int(event.keyCode))
        let modifiers = Self.monaModifiers(for: event.modifierFlags)
        let keyText = resolvedKeyText(
            characters: event.characters,
            keyCode: keyCode,
            modifierFlags: event.modifierFlags
        )
        return MonaKeyEvent(
            keyCode: keyCode,
            keyText: keyText,
            modifiers: modifiers,
            isRepeat: event.isARepeat,
            isComposing: isComposing,
            timestamp: event.timestamp
        )
    }

    /// Resolves the scan-independent produced text for a key event.
    ///
    /// Returns `nil` (no produced text) when the event is a dead-key (empty
    /// `characters`), a function-key (`.function` flag — F-keys, arrows, nav),
    /// or modifier-only (keyCode is `.shift` / `.ctrl` / `.alt` / `.meta`).
    /// Otherwise returns `characters` verbatim — the text the key produces,
    /// independent of the physical scan code, so layout and modifier variations
    /// surface here (e.g. "a" vs "A" under Shift).
    private func resolvedKeyText(
        characters: String?,
        keyCode: MonaKeyCode,
        modifierFlags: NSEvent.ModifierFlags
    ) -> String? {
        if Self.isModifierOnlyKeyCode(keyCode) {
            return nil
        }
        if modifierFlags.contains(.function) {
            return nil
        }
        // `NSEvent.characters` is `String?`; a nil or empty payload means the key
        // produced no committed text (dead-key, or a synthetic event with no
        // characters). Either way, keyText is nil.
        guard let characters, !characters.isEmpty else {
            return nil
        }
        return characters
    }

    // MARK: - Modifier flags → MonaKeyMod

    /// Maps macOS modifier flags to `MonaKeyMod`, preserving Monaco's
    /// platform-abstract semantics: on macOS, Command is the accelerator
    /// (`CtrlCmd`) and Control is the secondary modifier (`WinCtrl`).
    static func monaModifiers(for flags: NSEvent.ModifierFlags) -> MonaKeyMod {
        var mods: MonaKeyMod = []
        if flags.contains(.command) { mods.insert(.ctrlCmd) }
        if flags.contains(.shift)   { mods.insert(.shift) }
        if flags.contains(.option)  { mods.insert(.alt) }
        if flags.contains(.control) { mods.insert(.winCtrl) }
        // `.function`, `.numericPad`, `.capsLock`, `.help`, and device flags are
        // not `MonaKeyMod` modifiers and are intentionally not mapped.
        return mods
    }

    /// Returns `true` when the keyCode identifies a modifier-only key — a press
    /// that produces no text and is tracked through the modifier bit set, not
    /// through a character. Both left and right variants map to the same
    /// `MonaKeyCode`, so a single comparison per modifier suffices.
    private static func isModifierOnlyKeyCode(_ keyCode: MonaKeyCode) -> Bool {
        return keyCode == .shift
            || keyCode == .ctrl
            || keyCode == .alt
            || keyCode == .meta
    }

    // MARK: - Native dispatch-boundary application

    /// Applies a `MonaKeyDispatchOutcome` at the native boundary, returning the
    /// action an `NSResponder` should perform.
    ///
    /// - `outcome.preventDefault` maps to `action.preventDefault` — the
    ///   responder should NOT call `super.keyDown(with:)` (suppressing the
    ///   input-context feed and the system beep).
    /// - `outcome.stopPropagation` maps to `action.stopPropagation` — the
    ///   responder should NOT pass the event to `nextResponder`.
    ///
    /// `outcome.handled` is NOT folded into `preventDefault`: per P04-T001 the
    /// three outcome flags are independent, and the resolver sets
    /// `preventDefault` explicitly when it wants default suppression. The
    /// gateway does not second-guess that decision.
    public func apply(_ outcome: MonaKeyDispatchOutcome) -> MonaAppKeyDispatchAction {
        return MonaAppKeyDispatchAction(
            preventDefault: outcome.preventDefault,
            stopPropagation: outcome.stopPropagation
        )
    }
}

/// The native AppKit action a `NSResponder` should perform for a resolved
/// `MonaKeyDispatchOutcome`, produced by `MonaAppKeyEventGateway.apply(_:)`.
///
/// This is the native-boundary projection of the platform-neutral outcome: it
/// tells the responder what to do with the `NSEvent`, without the gateway having
/// to own the responder or call `super` itself.
public struct MonaAppKeyDispatchAction: Equatable, Hashable, Sendable {

    /// `true` when the responder should suppress the NSEvent's default behavior
    /// (do not call `super.keyDown`, do not feed the input context).
    public let preventDefault: Bool

    /// `true` when the event should stop bubbling up the responder chain (do
    /// not pass to `nextResponder`).
    public let stopPropagation: Bool

    /// Creates a native dispatch action.
    public init(preventDefault: Bool, stopPropagation: Bool) {
        self.preventDefault = preventDefault
        self.stopPropagation = stopPropagation
    }

    /// The no-op action: perform the default behavior and continue propagation.
    public static let `default` = MonaAppKeyDispatchAction(
        preventDefault: false,
        stopPropagation: false
    )
}
