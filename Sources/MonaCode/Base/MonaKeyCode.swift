// MonaKeyCode.swift
//
// P01-T004 — Implement key, modifier, token, and marker value types.
//
// `MonaKeyCode` is an extensible raw-value wrapper for `monaco.KeyCode`. Monaco
// exposes `KeyCode` as a fixed numeric enum spanning `-1` (`DependsOnKbLayout`)
// through `132` (`MAX_VALUE`), but it also accepts raw numeric key codes that
// fall outside that enum — for example platform-specific codes surfaced before
// the enum catches up. A plain Swift `enum` with a fixed raw value cannot model
// both at once, so `MonaKeyCode` is a `struct` wrapping an `Int` raw value:
//
//   - All 134 known codes are exposed as `static let` constants
//     (`MonaKeyCode.tab`, `.enter`, `.escape`, …, `.maxValue`), usable exactly
//     like enum cases.
//   - Any unknown numeric value is accepted via `MonaKeyCode.custom(_:)` or
//     `init(rawValue:)`.
//
// Equality, hashing, and `init(rawValue:)` are all value-based: two codes with
// the same raw value are equal and hash-equal regardless of whether they were
// constructed via a named constant, `init(rawValue:)`, or `custom(_:)`.
//
// The raw values are ported verbatim from `monaco-editor@0.56.0`
// (`standaloneEnums.ts` / `monaco.d.ts`): they are NOT reordered or compressed.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An extensible raw-value wrapper for `monaco.KeyCode`.
///
/// Wraps the integer key code that Monaco uses to identify physical and
/// logical keys. The 134 known codes (`DependsOnKbLayout = -1` through
/// `MAX_VALUE = 132`) are exposed as static constants; any other integer is
/// accepted via `custom(_:)` / `init(rawValue:)`. Equality is by raw value.
public struct MonaKeyCode: Equatable, Hashable, Sendable {

    /// The Monaco key code as a raw integer (range `-1 … 132` for known codes;
    /// any integer for unknown values).
    public let rawValue: Int

    /// Creates a key code from a raw integer value.
    ///
    /// Both known and unknown values flow through this initializer; it is the
    /// canonical construction path. Named constants (`MonaKeyCode.escape`,
    /// `.tab`, …) are pre-built instances of this initializer.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Creates a key code for an unknown numeric value not covered by the known
    /// constants. Functionally identical to `init(rawValue:)`; provided so the
    /// "known vs. unknown" intent reads at the call site.
    public static func custom(_ value: Int) -> MonaKeyCode {
        return MonaKeyCode(rawValue: value)
    }

    // MARK: - Known key codes (ported verbatim from monaco-editor@0.56.0)

    /// Placed first to cover the 0 value of the enum. `-1` signals that the
    /// ScanCode → KeyCode mapping depends on the keyboard layout.
    public static let dependsOnKbLayout = MonaKeyCode(rawValue: -1)

    /// The 0 value of the enum — an unknown / unmapped key.
    public static let unknown = MonaKeyCode(rawValue: 0)

    public static let backspace    = MonaKeyCode(rawValue: 1)
    public static let tab         = MonaKeyCode(rawValue: 2)
    public static let enter       = MonaKeyCode(rawValue: 3)
    public static let shift       = MonaKeyCode(rawValue: 4)
    public static let ctrl        = MonaKeyCode(rawValue: 5)
    public static let alt         = MonaKeyCode(rawValue: 6)
    public static let pauseBreak  = MonaKeyCode(rawValue: 7)
    public static let capsLock    = MonaKeyCode(rawValue: 8)
    public static let escape      = MonaKeyCode(rawValue: 9)
    public static let space       = MonaKeyCode(rawValue: 10)
    public static let pageUp      = MonaKeyCode(rawValue: 11)
    public static let pageDown    = MonaKeyCode(rawValue: 12)
    public static let end         = MonaKeyCode(rawValue: 13)
    public static let home       = MonaKeyCode(rawValue: 14)
    public static let leftArrow  = MonaKeyCode(rawValue: 15)
    public static let upArrow    = MonaKeyCode(rawValue: 16)
    public static let rightArrow = MonaKeyCode(rawValue: 17)
    public static let downArrow  = MonaKeyCode(rawValue: 18)
    public static let insert     = MonaKeyCode(rawValue: 19)
    public static let delete     = MonaKeyCode(rawValue: 20)

    public static let digit0 = MonaKeyCode(rawValue: 21)
    public static let digit1 = MonaKeyCode(rawValue: 22)
    public static let digit2 = MonaKeyCode(rawValue: 23)
    public static let digit3 = MonaKeyCode(rawValue: 24)
    public static let digit4 = MonaKeyCode(rawValue: 25)
    public static let digit5 = MonaKeyCode(rawValue: 26)
    public static let digit6 = MonaKeyCode(rawValue: 27)
    public static let digit7 = MonaKeyCode(rawValue: 28)
    public static let digit8 = MonaKeyCode(rawValue: 29)
    public static let digit9 = MonaKeyCode(rawValue: 30)

    public static let keyA = MonaKeyCode(rawValue: 31)
    public static let keyB = MonaKeyCode(rawValue: 32)
    public static let keyC = MonaKeyCode(rawValue: 33)
    public static let keyD = MonaKeyCode(rawValue: 34)
    public static let keyE = MonaKeyCode(rawValue: 35)
    public static let keyF = MonaKeyCode(rawValue: 36)
    public static let keyG = MonaKeyCode(rawValue: 37)
    public static let keyH = MonaKeyCode(rawValue: 38)
    public static let keyI = MonaKeyCode(rawValue: 39)
    public static let keyJ = MonaKeyCode(rawValue: 40)
    public static let keyK = MonaKeyCode(rawValue: 41)
    public static let keyL = MonaKeyCode(rawValue: 42)
    public static let keyM = MonaKeyCode(rawValue: 43)
    public static let keyN = MonaKeyCode(rawValue: 44)
    public static let keyO = MonaKeyCode(rawValue: 45)
    public static let keyP = MonaKeyCode(rawValue: 46)
    public static let keyQ = MonaKeyCode(rawValue: 47)
    public static let keyR = MonaKeyCode(rawValue: 48)
    public static let keyS = MonaKeyCode(rawValue: 49)
    public static let keyT = MonaKeyCode(rawValue: 50)
    public static let keyU = MonaKeyCode(rawValue: 51)
    public static let keyV = MonaKeyCode(rawValue: 52)
    public static let keyW = MonaKeyCode(rawValue: 53)
    public static let keyX = MonaKeyCode(rawValue: 54)
    public static let keyY = MonaKeyCode(rawValue: 55)
    public static let keyZ = MonaKeyCode(rawValue: 56)

    public static let meta          = MonaKeyCode(rawValue: 57)
    public static let contextMenu   = MonaKeyCode(rawValue: 58)

    public static let f1  = MonaKeyCode(rawValue: 59)
    public static let f2  = MonaKeyCode(rawValue: 60)
    public static let f3  = MonaKeyCode(rawValue: 61)
    public static let f4  = MonaKeyCode(rawValue: 62)
    public static let f5  = MonaKeyCode(rawValue: 63)
    public static let f6  = MonaKeyCode(rawValue: 64)
    public static let f7  = MonaKeyCode(rawValue: 65)
    public static let f8  = MonaKeyCode(rawValue: 66)
    public static let f9  = MonaKeyCode(rawValue: 67)
    public static let f10 = MonaKeyCode(rawValue: 68)
    public static let f11 = MonaKeyCode(rawValue: 69)
    public static let f12 = MonaKeyCode(rawValue: 70)
    public static let f13 = MonaKeyCode(rawValue: 71)
    public static let f14 = MonaKeyCode(rawValue: 72)
    public static let f15 = MonaKeyCode(rawValue: 73)
    public static let f16 = MonaKeyCode(rawValue: 74)
    public static let f17 = MonaKeyCode(rawValue: 75)
    public static let f18 = MonaKeyCode(rawValue: 76)
    public static let f19 = MonaKeyCode(rawValue: 77)
    public static let f20 = MonaKeyCode(rawValue: 78)
    public static let f21 = MonaKeyCode(rawValue: 79)
    public static let f22 = MonaKeyCode(rawValue: 80)
    public static let f23 = MonaKeyCode(rawValue: 81)
    public static let f24 = MonaKeyCode(rawValue: 82)

    public static let numLock     = MonaKeyCode(rawValue: 83)
    public static let scrollLock  = MonaKeyCode(rawValue: 84)
    public static let semicolon   = MonaKeyCode(rawValue: 85)
    public static let equal       = MonaKeyCode(rawValue: 86)
    public static let comma       = MonaKeyCode(rawValue: 87)
    public static let minus       = MonaKeyCode(rawValue: 88)
    public static let period      = MonaKeyCode(rawValue: 89)
    public static let slash       = MonaKeyCode(rawValue: 90)
    public static let backquote   = MonaKeyCode(rawValue: 91)
    public static let bracketLeft  = MonaKeyCode(rawValue: 92)
    public static let backslash    = MonaKeyCode(rawValue: 93)
    public static let bracketRight = MonaKeyCode(rawValue: 94)
    public static let quote       = MonaKeyCode(rawValue: 95)
    public static let oem8        = MonaKeyCode(rawValue: 96)
    public static let intlBackslash = MonaKeyCode(rawValue: 97)

    public static let numpad0 = MonaKeyCode(rawValue: 98)
    public static let numpad1 = MonaKeyCode(rawValue: 99)
    public static let numpad2 = MonaKeyCode(rawValue: 100)
    public static let numpad3 = MonaKeyCode(rawValue: 101)
    public static let numpad4 = MonaKeyCode(rawValue: 102)
    public static let numpad5 = MonaKeyCode(rawValue: 103)
    public static let numpad6 = MonaKeyCode(rawValue: 104)
    public static let numpad7 = MonaKeyCode(rawValue: 105)
    public static let numpad8 = MonaKeyCode(rawValue: 106)
    public static let numpad9 = MonaKeyCode(rawValue: 107)
    public static let numpadMultiply  = MonaKeyCode(rawValue: 108)
    public static let numpadAdd       = MonaKeyCode(rawValue: 109)
    public static let numpadSeparator = MonaKeyCode(rawValue: 110)
    public static let numpadSubtract  = MonaKeyCode(rawValue: 111)
    public static let numpadDecimal   = MonaKeyCode(rawValue: 112)
    public static let numpadDivide    = MonaKeyCode(rawValue: 113)

    public static let keyInComposition = MonaKeyCode(rawValue: 114)
    public static let abntC1           = MonaKeyCode(rawValue: 115)
    public static let abntC2           = MonaKeyCode(rawValue: 116)
    public static let audioVolumeMute  = MonaKeyCode(rawValue: 117)
    public static let audioVolumeUp    = MonaKeyCode(rawValue: 118)
    public static let audioVolumeDown  = MonaKeyCode(rawValue: 119)
    public static let browserSearch    = MonaKeyCode(rawValue: 120)
    public static let browserHome       = MonaKeyCode(rawValue: 121)
    public static let browserBack      = MonaKeyCode(rawValue: 122)
    public static let browserForward   = MonaKeyCode(rawValue: 123)
    public static let mediaTrackNext     = MonaKeyCode(rawValue: 124)
    public static let mediaTrackPrevious = MonaKeyCode(rawValue: 125)
    public static let mediaStop           = MonaKeyCode(rawValue: 126)
    public static let mediaPlayPause     = MonaKeyCode(rawValue: 127)
    public static let launchMediaPlayer  = MonaKeyCode(rawValue: 128)
    public static let launchMail         = MonaKeyCode(rawValue: 129)
    public static let launchApp2         = MonaKeyCode(rawValue: 130)
    public static let clear = MonaKeyCode(rawValue: 131)

    /// Placed last to cover the length of the enum. Do not depend on this
    /// value in downstream logic — it exists only to bound the known range.
    public static let maxValue = MonaKeyCode(rawValue: 132)
}
