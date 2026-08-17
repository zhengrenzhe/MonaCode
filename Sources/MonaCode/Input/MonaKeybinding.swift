// MonaKeybinding.swift
//
// P04-T003 — Port keybinding resolution and chord state to Core.
//
// `MonaKeybinding` is an immutable keybinding *definition*. It is the Core-side
// analogue of a Monaco `KeybindingRule` / resolved `Keybinding`: it pairs a
// physical key + modifier set with a command ID, a when-clause context
// expression, and a precedence weight. It is the unit the resolver
// (`MonaKeybindingResolver`) registers, orders, and matches against a
// `MonaKeyEvent` (P04-T001).
//
// Fields (all immutable):
//
//   - `key: MonaKeyCode`         — the logical key code (P01-T004) of the FIRST
//                                  part. Unknown numeric codes are carried via
//                                  `MonaKeyCode.custom(_:)` and preserved.
//   - `modifiers: MonaKeyMod`    — the modifier set (P01-T004) of the FIRST
//                                  part, an `OptionSet` over Monaco's bit
//                                  layout (`CtrlCmd`, `Shift`, `Alt`, `WinCtrl`).
//   - `command: String`          — the command ID dispatched when this
//                                  keybinding resolves. Never mutated by the
//                                  resolver; command removal operates on this
//                                  value.
//   - `when: String?`            — an optional when-clause context expression
//                                  (e.g. `"editorTextFocus && !editorReadonly"`).
//                                  `nil` means the keybinding is unconditional
//                                  (always matches, context-independent).
//   - `weight: Int`              — precedence. Higher weight wins. Monaco
//                                  assigns defaults `weight1 = 0` and dynamic
//                                  overrides `weight1 = 1000`; this field is
//                                  the abstract weight used by the resolver's
//                                  ordering comparator.
//   - `chordKey: MonaKeyCode?`   — `nil` for a single-part keybinding; non-nil
//                                  for a two-part chord (e.g. Cmd+K Cmd+C), in
//                                  which case this is the key code of the
//                                  SECOND part.
//   - `chordModifiers: MonaKeyMod` — the modifier set of the SECOND part. Empty
//                                  for single-part keybindings.
//
// A single-part keybinding dispatches its command as soon as its first part
// matches. A chord keybinding enters the chord state on the first part and
// dispatches only when the second part matches within the chord timeout
// (managed by `MonaChordState`).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An immutable keybinding definition: key + modifiers + command + when-clause +
/// weight, with an optional two-part chord.
///
/// Registered with `MonaKeybindingResolver`, which orders candidates by weight
/// (higher wins), then specificity (more modifiers wins), then registration
/// order (later wins), and matches them against a `MonaKeyEvent` under a
/// `MonaKeybindingContext`. The type carries no platform reference and
/// constructs no dispatch by itself.
public struct MonaKeybinding: Equatable, Hashable, Sendable {

    /// The logical key code of the first part (P01-T004).
    public let key: MonaKeyCode

    /// The modifier set of the first part (P01-T004).
    public let modifiers: MonaKeyMod

    /// The command ID dispatched when this keybinding resolves.
    public let command: String

    /// An optional when-clause context expression. `nil` means unconditional.
    public let when: String?

    /// Precedence weight. Higher wins. Defaults typically use a lower weight
    /// than dynamic overrides.
    public let weight: Int

    /// The key code of the second part, or `nil` for a single-part keybinding.
    public let chordKey: MonaKeyCode?

    /// The modifier set of the second part. Empty for single-part keybindings.
    public let chordModifiers: MonaKeyMod

    /// Creates a single-part keybinding (no chord second part).
    ///
    /// `chordKey` defaults to `nil` and `chordModifiers` defaults to empty,
    /// yielding a keybinding that dispatches its command as soon as its first
    /// part matches.
    public init(
        key: MonaKeyCode,
        modifiers: MonaKeyMod,
        command: String,
        when: String?,
        weight: Int
    ) {
        self.init(
            key: key,
            modifiers: modifiers,
            command: command,
            when: when,
            weight: weight,
            chordKey: nil,
            chordModifiers: []
        )
    }

    /// Creates a keybinding, optionally a two-part chord.
    ///
    /// Pass a non-nil `chordKey` (with `chordModifiers`) to define a chord:
    /// the resolver enters the chord state on the first part and dispatches the
    /// command only when the second part matches within the chord timeout.
    public init(
        key: MonaKeyCode,
        modifiers: MonaKeyMod,
        command: String,
        when: String?,
        weight: Int,
        chordKey: MonaKeyCode?,
        chordModifiers: MonaKeyMod
    ) {
        self.key = key
        self.modifiers = modifiers
        self.command = command
        self.when = when
        self.weight = weight
        self.chordKey = chordKey
        self.chordModifiers = chordModifiers
    }

    /// `true` when this keybinding is a two-part chord.
    public var isChord: Bool { chordKey != nil }
}
