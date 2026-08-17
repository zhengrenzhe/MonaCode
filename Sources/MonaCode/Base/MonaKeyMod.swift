// MonaKeyMod.swift
//
// P01-T004 — Implement key, modifier, token, and marker value types.
//
// `MonaKeyMod` is an `OptionSet` mirroring `monaco.KeyMod`. Monaco exposes
// `KeyMod` as a class with four static numeric masks (`CtrlCmd`, `Shift`,
// `Alt`, `WinCtrl`) plus a `chord(first, second)` combinator. The bit values
// are load-bearing for keybinding serialization: a keybinding number is
// `modifierBits | keyCode`, and a two-part chord is packed as
// `firstPart | (secondPart << 16)`.
//
// `MonaKeyMod` preserves Monaco's exact bit layout (NOT reordered):
//
//     WinCtrl = 1 << 8   = 256    Win/Super on Windows·Linux, Ctrl on macOS
//     Alt     = 1 << 9   = 512    Alt / Option
//     Shift   = 1 << 10  = 1024   Shift
//     CtrlCmd = 1 << 11  = 2048   Ctrl on Windows·Linux, Cmd on macOS
//
// The platform-abstract names (`CtrlCmd`, `WinCtrl`) are preserved verbatim
// because they carry the platform-dependent semantics that are load-bearing
// for keybinding fidelity: `CtrlCmd` is the primary "accelerator" modifier
// (Cmd on macOS, Ctrl elsewhere), while `WinCtrl` covers the secondary one.
//
// `chord(firstPart:secondPart:)`, `firstPart(of:)`, and `secondPart(of:)` are
// ported branch-for-branch from Monaco's `KeyChord`.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An `OptionSet` over Monaco's `KeyMod` modifier bit layout.
///
/// Modifier masks compose with the standard `OptionSet` operators (`|`, `&`,
/// `-`, `.union`, `.intersection`, `.contains`). A keybinding number is built by
/// OR-ing the modifier bits with a `MonaKeyCode` raw value:
///
///     let kb = MonaKeyMod.ctrlCmd.rawValue | MonaKeyCode.keyK.rawValue
///
/// Two-part keybindings (chords) are packed with `chord(firstPart:secondPart:)`.
public struct MonaKeyMod: OptionSet, Equatable, Hashable, Sendable {

    public let rawValue: Int

    /// Creates a modifier set from a raw bit value.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The Ctrl / Cmd accelerator. Ctrl on Windows and Linux, Cmd on macOS.
    /// Bit `1 << 11` (= 2048).
    public static let ctrlCmd = MonaKeyMod(rawValue: 1 << 11)

    /// The Shift modifier. Bit `1 << 10` (= 1024).
    public static let shift = MonaKeyMod(rawValue: 1 << 10)

    /// The Alt / Option modifier. Bit `1 << 9` (= 512).
    public static let alt = MonaKeyMod(rawValue: 1 << 9)

    /// The Win / Super / Ctrl-secondary modifier. Win on Windows and Linux,
    /// Ctrl on macOS. Bit `1 << 8` (= 256).
    public static let winCtrl = MonaKeyMod(rawValue: 1 << 8)

    // MARK: - Keybinding serialization (ported from Monaco's KeyChord)

    /// Packs a two-part keybinding (a chord) into a single number, mirroring
    /// `monaco.KeyMod.chord` / `KeyChord.chord`.
    ///
    /// The result is `firstPart | ((secondPart & 0x0000_FFFF) << 16)`. Only the
    /// low 16 bits of `secondPart` are kept so the two halves occupy disjoint
    /// bit ranges and can be recovered with `firstPart(of:)` and
    /// `secondPart(of:)`.
    public static func chord(firstPart: Int, secondPart: Int) -> Int {
        return firstPart | ((secondPart & 0x0000_FFFF) << 16)
    }

    /// Returns the first (low 16-bit) half of a keybinding packed by `chord`.
    public static func firstPart(of keybinding: Int) -> Int {
        return keybinding & 0x0000_FFFF
    }

    /// Returns the second (high 16-bit) half of a keybinding packed by `chord`.
    public static func secondPart(of keybinding: Int) -> Int {
        return (keybinding & 0xFFFF_0000) >> 16
    }
}
