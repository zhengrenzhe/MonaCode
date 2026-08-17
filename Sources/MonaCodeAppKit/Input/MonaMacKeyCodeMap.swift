// MonaMacKeyCodeMap.swift
//
// P04-T002 — Translate AppKit key events through one native gateway.
//
// `MonaMacKeyCodeMap` bridges macOS virtual key codes to Monaco's logical
// `MonaKeyCode` (P01-T004). The two key-code spaces are DIFFERENT:
//
//   - macOS virtual key codes are the Carbon/HIToolbox `kVK_*` constants —
//     positional scan codes for the physical Mac keyboard (kVK_Return=36,
//     kVK_Tab=48, kVK_Space=49, kVK_Delete=51, kVK_Escape=53, arrows 123-126,
//     function keys 122/120/99/118/96/97/98/100/101/109/103/111/105/107/113/
//     106/64/79/80/90, etc.). They are NOT Monaco's KeyCode values.
//   - `MonaKeyCode` is Monaco's logical key code (-1 … 132 for known codes,
//     plus `custom(_:)` for any other integer), ported verbatim from
//     `monaco-editor@0.56.0`.
//
// The map covers all standard macOS key codes. A macOS key code with no Monaco
// equivalent is returned as `MonaKeyCode.custom(macKeyCode)` — it is preserved
// verbatim and NOT collapsed to a known case (e.g. `.unknown`), matching the
// P01-T004 / P04-T001 "preserve unknown codes" contract.
//
// This is a stateless, namespace-only type. `MonaCodeAppKit` may `import AppKit`
// and `import Foundation`.

import AppKit
import Foundation
import MonaCode

/// A stateless bridge from macOS virtual key codes (`NSEvent.keyCode` integers)
/// to Monaco's logical `MonaKeyCode`.
///
/// Use `MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode:)` to resolve a macOS key
/// code. Known codes map to their Monaco equivalents; unknown codes map to
/// `MonaKeyCode.custom(_:)` without collapse.
public enum MonaMacKeyCodeMap {

    /// Resolves a macOS virtual key code to a `MonaKeyCode`.
    ///
    /// - Parameter macKeyCode: The macOS virtual key code (a `kVK_*` constant
    ///   as an integer, e.g. `36` for Return).
    /// - Returns: The corresponding `MonaKeyCode`. Known macOS codes map to
    ///   their Monaco equivalents; unknown codes are returned as
    ///   `MonaKeyCode.custom(macKeyCode)`, preserved without collapse.
    public static func monaKeyCode(forMacKeyCode macKeyCode: Int) -> MonaKeyCode {
        // A `switch` would be valid, but a dictionary lookup keeps the mapping
        // table declarative and lets the unknown-code fallback read as a single
        // `return custom(_)` at the end.
        if let known = Self.known[macKeyCode] {
            return known
        }
        return MonaKeyCode.custom(macKeyCode)
    }

    // MARK: - Known macOS key code → MonaKeyCode

    /// The complete table of standard macOS virtual key codes that have a Monaco
    /// equivalent. Key codes absent from this table (e.g. JIS-specific keys,
    /// the Fn key) flow through to `custom(_:)`.
    ///
    /// Values are the Carbon/HIToolbox `kVK_*` constants, NOT Monaco KeyCode
    /// values. Each pair is annotated with its `kVK_*` name for traceability.
    private static let known: [Int: MonaKeyCode] = {
        var table: [Int: MonaKeyCode] = [:]

        // --- Return / Tab / Space / Delete / Escape ---
        table[36] = .enter          // kVK_Return
        table[48] = .tab            // kVK_Tab
        table[49] = .space          // kVK_Space
        table[51] = .backspace      // kVK_Delete (macOS "Delete" = backspace)
        table[117] = .delete        // kVK_ForwardDelete
        table[53] = .escape         // kVK_Escape
        table[76] = .enter          // kVK_ANSI_KeypadEnter (Monaco has no separate keypad-enter)

        // --- Arrow keys ---
        table[123] = .leftArrow     // kVK_LeftArrow
        table[124] = .rightArrow    // kVK_RightArrow
        table[125] = .downArrow     // kVK_DownArrow
        table[126] = .upArrow       // kVK_UpArrow

        // --- Navigation keys ---
        table[114] = .insert        // kVK_Help (Mac Help ≈ Monaco insert)
        table[115] = .home          // kVK_Home
        table[116] = .pageUp        // kVK_PageUp
        table[119] = .end           // kVK_End
        table[121] = .pageDown      // kVK_PageDown

        // --- Function keys (F1–F20). macOS codes are positional, not value-ordered. ---
        table[122] = .f1   // kVK_F1
        table[120] = .f2   // kVK_F2
        table[99]  = .f3   // kVK_F3
        table[118] = .f4   // kVK_F4
        table[96]  = .f5   // kVK_F5
        table[97]  = .f6   // kVK_F6
        table[98]  = .f7   // kVK_F7
        table[100] = .f8   // kVK_F8
        table[101] = .f9   // kVK_F9
        table[109] = .f10  // kVK_F10
        table[103] = .f11  // kVK_F11
        table[111] = .f12  // kVK_F12
        table[105] = .f13  // kVK_F13
        table[107] = .f14  // kVK_F14
        table[113] = .f15  // kVK_F15
        table[106] = .f16  // kVK_F16
        table[64]  = .f17  // kVK_F17
        table[79]  = .f18  // kVK_F18
        table[80]  = .f19  // kVK_F19
        table[90]  = .f20  // kVK_F20

        // --- ANSI letters (macOS key code is the physical position, not the glyph). ---
        table[0]  = .keyA   // kVK_ANSI_A
        table[1]  = .keyS   // kVK_ANSI_S
        table[2]  = .keyD   // kVK_ANSI_D
        table[3]  = .keyF   // kVK_ANSI_F
        table[4]  = .keyH   // kVK_ANSI_H
        table[5]  = .keyG   // kVK_ANSI_G
        table[6]  = .keyZ   // kVK_ANSI_Z
        table[7]  = .keyX   // kVK_ANSI_X
        table[8]  = .keyC   // kVK_ANSI_C
        table[9]  = .keyV   // kVK_ANSI_V
        table[11] = .keyB   // kVK_ANSI_B
        table[12] = .keyQ   // kVK_ANSI_Q
        table[13] = .keyW   // kVK_ANSI_W
        table[14] = .keyE   // kVK_ANSI_E
        table[15] = .keyR   // kVK_ANSI_R
        table[16] = .keyY   // kVK_ANSI_Y
        table[17] = .keyT   // kVK_ANSI_T
        table[31] = .keyO   // kVK_ANSI_O
        table[32] = .keyU   // kVK_ANSI_U
        table[34] = .keyI   // kVK_ANSI_I
        table[35] = .keyP   // kVK_ANSI_P
        table[37] = .keyL   // kVK_ANSI_L
        table[38] = .keyJ   // kVK_ANSI_J
        table[40] = .keyK   // kVK_ANSI_K
        table[45] = .keyN   // kVK_ANSI_N
        table[46] = .keyM   // kVK_ANSI_M

        // --- ANSI digits (macOS codes are positional). ---
        table[18] = .digit1  // kVK_ANSI_1
        table[19] = .digit2  // kVK_ANSI_2
        table[20] = .digit3  // kVK_ANSI_3
        table[21] = .digit4  // kVK_ANSI_4
        table[22] = .digit6  // kVK_ANSI_6
        table[23] = .digit5  // kVK_ANSI_5
        table[25] = .digit9  // kVK_ANSI_9
        table[26] = .digit7  // kVK_ANSI_7
        table[28] = .digit8  // kVK_ANSI_8
        table[29] = .digit0  // kVK_ANSI_0

        // --- ANSI punctuation ---
        table[24] = .equal         // kVK_ANSI_Equal
        table[27] = .minus          // kVK_ANSI_Minus
        table[30] = .bracketRight   // kVK_ANSI_RightBracket
        table[33] = .bracketLeft    // kVK_ANSI_LeftBracket
        table[39] = .quote          // kVK_ANSI_Quote
        table[41] = .semicolon      // kVK_ANSI_Semicolon
        table[42] = .backslash       // kVK_ANSI_Backslash
        table[43] = .comma          // kVK_ANSI_Comma
        table[44] = .slash          // kVK_ANSI_Slash
        table[47] = .period         // kVK_ANSI_Period
        table[50] = .backquote      // kVK_ANSI_Grave
        table[10] = .intlBackslash  // kVK_ISO_Section (≈ Monaco intlBackslash)

        // --- Keypad ---
        table[65] = .numpadDecimal    // kVK_ANSI_KeypadDecimal
        table[67] = .numpadMultiply   // kVK_ANSI_KeypadMultiply
        table[69] = .numpadAdd        // kVK_ANSI_KeypadPlus
        table[75] = .numpadDivide     // kVK_ANSI_KeypadDivide
        table[78] = .numpadSubtract   // kVK_ANSI_KeypadMinus
        table[81] = .equal            // kVK_ANSI_KeypadEquals (Monaco has no numpad-equals)
        table[82] = .numpad0          // kVK_ANSI_Keypad0
        table[83] = .numpad1          // kVK_ANSI_Keypad1
        table[84] = .numpad2          // kVK_ANSI_Keypad2
        table[85] = .numpad3          // kVK_ANSI_Keypad3
        table[86] = .numpad4          // kVK_ANSI_Keypad4
        table[87] = .numpad5          // kVK_ANSI_Keypad5
        table[88] = .numpad6          // kVK_ANSI_Keypad6
        table[89] = .numpad7          // kVK_ANSI_Keypad7
        table[91] = .numpad8          // kVK_ANSI_Keypad8
        table[92] = .numpad9          // kVK_ANSI_Keypad9
        table[71] = .numLock          // kVK_ANSI_KeypadClear (Mac Clear ≈ Monaco numLock)

        // --- Modifiers ---
        // Both left and right variants of a modifier map to the same MonaKeyCode;
        // Monaco distinguishes modifiers by modifier bit, not by left/right key code.
        table[56] = .shift     // kVK_Shift
        table[60] = .shift     // kVK_RightShift
        table[59] = .ctrl      // kVK_Control
        table[62] = .ctrl      // kVK_RightControl
        table[58] = .alt        // kVK_Option
        table[61] = .alt        // kVK_RightOption
        table[55] = .meta       // kVK_Command
        table[54] = .meta       // kVK_RightCommand
        table[57] = .capsLock   // kVK_CapsLock

        // --- Volume / media ---
        table[72] = .audioVolumeUp    // kVK_VolumeUp
        table[73] = .audioVolumeDown  // kVK_VolumeDown
        table[74] = .audioVolumeMute  // kVK_Mute

        return table
    }()
}
