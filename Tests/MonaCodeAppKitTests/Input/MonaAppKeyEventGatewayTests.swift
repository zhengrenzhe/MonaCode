// MonaAppKeyEventGatewayTests.swift
//
// P04-T002 — Translate AppKit key events through one native gateway.
//
// Verifies the single AppKit → Core keyboard-event gateway:
//
//   - `MonaMacKeyCodeMap`      — maps macOS virtual key codes (the integer
//                                `NSEvent.keyCode` values, e.g. kVK_Return=36,
//                                kVK_Tab=48, kVK_Space=49) to `MonaKeyCode`
//                                (P01-T004). Known macOS codes map to their
//                                Monaco equivalents; UNKNOWN codes map to
//                                `MonaKeyCode.custom(_:)` WITHOUT collapsing to
//                                a known case (e.g. `.unknown`).
//   - `MonaAppKeyEventGateway` — the ONE native gateway that translates an
//                                `NSEvent` (keyDown/keyUp) into a `MonaKeyEvent`
//                                (P04-T001). Translates EXACTLY ONCE (no
//                                re-translation). Preserves dead-key (no
//                                keyText), repeat (`isARepeat` from NSEvent),
//                                function-key, keypad, modifier-only (no text),
//                                and unrecognized (custom code) cases. Applies a
//                                `MonaKeyDispatchOutcome` at the native boundary
//                                (`preventDefault` → NSEvent default prevention,
//                                `stopPropagation` → responder-chain stop).
//
// macOS virtual key codes are the Carbon/HIToolbox constants (kVK_*). They are
// NOT Monaco's KeyCode values — the gateway bridges the two.

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaAppKeyEventGatewayTests: XCTestCase {

    // MARK: - NSEvent construction helpers

    /// Builds a synthetic keyDown/keyUp `NSEvent` for a given macOS key code.
    private func keyEvent(
        type: NSEvent.EventType = .keyDown,
        keyCode: UInt16,
        characters: String,
        charactersIgnoringModifiers: String? = nil,
        modifierFlags: NSEvent.ModifierFlags = [],
        isARepeat: Bool = false,
        timestamp: TimeInterval = 100.0
    ) -> NSEvent {
        return NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: timestamp,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers ?? characters,
            isARepeat: isARepeat,
            keyCode: keyCode
        )!
    }

    // MARK: - MonaMacKeyCodeMap: macOS key code → MonaKeyCode

    func testKeyCodeMapMapsReturnToEnter() {
        // kVK_Return = 0x24 = 36
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 36), .enter)
    }

    func testKeyCodeMapMapsTabToTab() {
        // kVK_Tab = 0x30 = 48
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 48), .tab)
    }

    func testKeyCodeMapMapsSpaceToSpace() {
        // kVK_Space = 0x31 = 49
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 49), .space)
    }

    func testKeyCodeMapMapsDeleteToBackspace() {
        // kVK_Delete = 0x33 = 51 (macOS "Delete" = backspace)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 51), .backspace)
    }

    func testKeyCodeMapMapsForwardDeleteToDelete() {
        // kVK_ForwardDelete = 0x75 = 117 (macOS forward-delete / Del)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 117), .delete)
    }

    func testKeyCodeMapMapsEscapeToEscape() {
        // kVK_Escape = 0x35 = 53
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 53), .escape)
    }

    func testKeyCodeMapMapsArrowKeys() {
        // kVK_LeftArrow=123, kVK_RightArrow=124, kVK_DownArrow=125, kVK_UpArrow=126
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 123), .leftArrow)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 124), .rightArrow)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 125), .downArrow)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 126), .upArrow)
    }

    func testKeyCodeMapMapsFunctionKeysF1ThroughF20() {
        // The macOS function-key virtual codes (not in numeric order):
        //   F1=122  F2=120  F3=99  F4=118  F5=96  F6=97  F7=98  F8=100  F9=101
        //   F10=109 F11=103 F12=111 F13=105 F14=107 F15=113 F16=106
        //   F17=64  F18=79  F19=80  F20=90
        let pairs: [(mac: Int, mona: MonaKeyCode)] = [
            (122, .f1), (120, .f2), (99, .f3), (118, .f4), (96, .f5),
            (97, .f6), (98, .f7), (100, .f8), (101, .f9), (109, .f10),
            (103, .f11), (111, .f12), (105, .f13), (107, .f14), (113, .f15),
            (106, .f16), (64, .f17), (79, .f18), (80, .f19), (90, .f20),
        ]
        for pair in pairs {
            XCTAssertEqual(
                MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: pair.mac),
                pair.mona,
                "mac code \(pair.mac) should map to \(pair.mona)"
            )
        }
    }

    func testKeyCodeMapMapsNavigationKeys() {
        // kVK_Home=115, kVK_PageUp=116, kVK_End=119, kVK_PageDown=121,
        // kVK_Help=114 (maps to Monaco insert)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 115), .home)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 116), .pageUp)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 119), .end)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 121), .pageDown)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 114), .insert)
    }

    func testKeyCodeMapMapsLetterKeys() {
        // A representative sample of ANSI letter positions.
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 0), .keyA)   // kVK_ANSI_A
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 14), .keyE)   // kVK_ANSI_E
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 46), .keyM)   // kVK_ANSI_M
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 12), .keyQ)   // kVK_ANSI_Q
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 17), .keyT)   // kVK_ANSI_T
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 16), .keyY)   // kVK_ANSI_Y
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 6), .keyZ)    // kVK_ANSI_Z
    }

    func testKeyCodeMapMapsDigitKeys() {
        // macOS digit key codes are positional, not value-ordered.
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 18), .digit1) // kVK_ANSI_1
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 19), .digit2)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 29), .digit0) // kVK_ANSI_0
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 25), .digit9) // kVK_ANSI_9
    }

    func testKeyCodeMapMapsPunctuationKeys() {
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 41), .semicolon)    // kVK_ANSI_Semicolon
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 24), .equal)         // kVK_ANSI_Equal
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 43), .comma)         // kVK_ANSI_Comma
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 27), .minus)         // kVK_ANSI_Minus
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 47), .period)        // kVK_ANSI_Period
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 44), .slash)         // kVK_ANSI_Slash
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 50), .backquote)     // kVK_ANSI_Grave
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 33), .bracketLeft)   // kVK_ANSI_LeftBracket
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 42), .backslash)     // kVK_ANSI_Backslash
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 30), .bracketRight)  // kVK_ANSI_RightBracket
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 39), .quote)          // kVK_ANSI_Quote
    }

    func testKeyCodeMapMapsKeypadKeys() {
        // kVK_ANSI_Keypad0=82 … Keypad9=92 (note 90 is unused).
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 82), .numpad0)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 83), .numpad1)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 87), .numpad5)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 92), .numpad9)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 67), .numpadMultiply) // kVK_ANSI_KeypadMultiply
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 69), .numpadAdd)      // kVK_ANSI_KeypadPlus
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 78), .numpadSubtract) // kVK_ANSI_KeypadMinus
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 75), .numpadDivide)   // kVK_ANSI_KeypadDivide
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 65), .numpadDecimal)  // kVK_ANSI_KeypadDecimal
    }

    func testKeyCodeMapMapsModifierKeys() {
        // kVK_Shift=56, kVK_RightShift=60, kVK_Control=59, kVK_RightControl=62,
        // kVK_Option=58, kVK_RightOption=61, kVK_Command=55, kVK_RightCommand=54,
        // kVK_CapsLock=57
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 56), .shift)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 60), .shift)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 59), .ctrl)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 62), .ctrl)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 58), .alt)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 61), .alt)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 55), .meta)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 54), .meta)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 57), .capsLock)
    }

    func testKeyCodeMapMapsVolumeKeys() {
        // kVK_VolumeUp=72, kVK_VolumeDown=73, kVK_Mute=74
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 72), .audioVolumeUp)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 73), .audioVolumeDown)
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 74), .audioVolumeMute)
    }

    func testKeyCodeMapMapsUnknownCodeToCustomWithoutCollapse() {
        // A macOS key code outside the known set must map to custom(_) and NOT
        // collapse to a known case (e.g. .unknown / .maxValue).
        let code = MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 200)
        XCTAssertEqual(code, .custom(200))
        XCTAssertEqual(code.rawValue, 200)
        XCTAssertNotEqual(code, .unknown)
        XCTAssertNotEqual(code, .maxValue)
    }

    func testKeyCodeMapMapsUnknownNegativeCodeToCustom() {
        let code = MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: -7)
        XCTAssertEqual(code, .custom(-7))
        XCTAssertEqual(code.rawValue, -7)
    }

    func testKeyCodeMapCustomCodeEqualInRawValueToKnownComparesEqual() {
        // Value-based equality: a custom code whose raw value matches a known
        // constant compares equal (per P01-T004).
        XCTAssertEqual(MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode: 9999), .custom(9999))
        // escape.rawValue == 9; a custom(9) is equal to .escape by raw value.
        XCTAssertEqual(MonaKeyCode.custom(9), .escape)
    }

    // MARK: - MonaAppKeyEventGateway: NSEvent → MonaKeyEvent

    func testGatewayTranslatesKeyDownPrintableLetter() {
        let gateway = MonaAppKeyEventGateway()
        // kVK_ANSI_A = 0, characters "a", no modifiers.
        let event = keyEvent(keyCode: 0, characters: "a")
        let translated = gateway.translateKeyDown(event, isComposing: false)

        XCTAssertEqual(translated.keyCode, .keyA)
        XCTAssertEqual(translated.keyText, "a")
        XCTAssertEqual(translated.modifiers, [])
        XCTAssertFalse(translated.isRepeat)
        XCTAssertFalse(translated.isComposing)
        XCTAssertEqual(translated.timestamp, 100.0, accuracy: 1e-9)
    }

    func testGatewayTranslatesKeyUpToSameNeutralEvent() {
        // MonaKeyEvent is phase-agnostic (no keyDown/keyUp field). A keyUp
        // produces the same neutral values as a keyDown for the same physical
        // event, so the responder can route both through one gateway.
        let gateway = MonaAppKeyEventGateway()
        let down = keyEvent(type: .keyDown, keyCode: 0, characters: "a")
        let up = keyEvent(type: .keyUp, keyCode: 0, characters: "a")

        let downTranslated = gateway.translateKeyDown(down, isComposing: false)
        let upTranslated = gateway.translateKeyUp(up, isComposing: false)

        XCTAssertEqual(downTranslated, upTranslated)
    }

    func testGatewayTranslatesCmdKToCtrlCmdModifier() {
        // On macOS, the Command key is the accelerator → MonaKeyMod.ctrlCmd.
        let gateway = MonaAppKeyEventGateway()
        // kVK_ANSI_K = 40
        let event = keyEvent(
            keyCode: 40,
            characters: "k",
            modifierFlags: .command
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)

        XCTAssertEqual(translated.keyCode, .keyK)
        XCTAssertEqual(translated.keyText, "k")
        XCTAssertEqual(translated.modifiers, .ctrlCmd)
    }

    func testGatewayTranslatesControlAsWinCtrl() {
        // On macOS, the Control key is the secondary modifier → winCtrl.
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(
            keyCode: 0,
            characters: "a",
            modifierFlags: .control
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.modifiers, .winCtrl)
    }

    func testGatewayTranslatesOptionAsAlt() {
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(
            keyCode: 0,
            characters: "a",
            modifierFlags: .option
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.modifiers, .alt)
    }

    func testGatewayTranslatesShiftModifier() {
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(
            keyCode: 0,
            characters: "A",
            modifierFlags: .shift
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.modifiers, .shift)
        XCTAssertEqual(translated.keyText, "A")
    }

    func testGatewayTranslatesModifierCombination() {
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(
            keyCode: 7, // kVK_ANSI_X
            characters: "x",
            modifierFlags: [.command, .shift]
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertTrue(translated.modifiers.contains(.ctrlCmd))
        XCTAssertTrue(translated.modifiers.contains(.shift))
        XCTAssertEqual(translated.keyCode, .keyX)
    }

    func testGatewayPreservesIsRepeatFromNSEvent() {
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(
            keyCode: 0,
            characters: "a",
            isARepeat: true
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertTrue(translated.isRepeat)
    }

    func testGatewayPreservesTimestampFromNSEvent() {
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(
            keyCode: 0,
            characters: "a",
            timestamp: 9876.54321
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.timestamp, 9876.54321, accuracy: 1e-9)
    }

    func testGatewayPreservesIsComposingParameter() {
        // The IME composition state is not carried by NSEvent; the composition
        // session (P04-T004) supplies it per-call. The gateway preserves it
        // verbatim into the neutral event.
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(keyCode: 0, characters: "a")
        let composing = gateway.translateKeyDown(event, isComposing: true)
        XCTAssertTrue(composing.isComposing)

        let notComposing = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertFalse(notComposing.isComposing)
    }

    // MARK: - Dead-key, function-key, keypad, modifier-only, unrecognized

    func testGatewayDeadKeyProducesNoKeyText() {
        // A dead-key press produces no committed text (empty `characters`).
        // The gateway must NOT synthesize text — keyText is nil.
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(
            keyCode: 0, // kVK_ANSI_A
            characters: ""
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.keyCode, .keyA)
        XCTAssertNil(translated.keyText)
    }

    func testGatewayFunctionKeyProducesNoKeyText() {
        // Function keys (F1-F20, arrows, nav) carry the .function modifier flag
        // and produce no text.
        let gateway = MonaAppKeyEventGateway()
        // F5 = 96
        let event = keyEvent(
            keyCode: 96,
            characters: "",
            modifierFlags: .function
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.keyCode, .f5)
        XCTAssertNil(translated.keyText)
    }

    func testGatewayArrowKeyProducesNoKeyText() {
        let gateway = MonaAppKeyEventGateway()
        // Left arrow = 123, .function flag set, no characters.
        let event = keyEvent(
            keyCode: 123,
            characters: "",
            modifierFlags: .function
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.keyCode, .leftArrow)
        XCTAssertNil(translated.keyText)
    }

    func testGatewayKeypadDigitPreservesProducedText() {
        // Keypad digits carry the .numericPad flag but DO produce text ("5").
        let gateway = MonaAppKeyEventGateway()
        // kVK_ANSI_Keypad5 = 87
        let event = keyEvent(
            keyCode: 87,
            characters: "5",
            modifierFlags: .numericPad
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.keyCode, .numpad5)
        XCTAssertEqual(translated.keyText, "5")
    }

    func testGatewayModifierOnlyKeyProducesNoKeyText() {
        // A modifier-only press (here Shift delivered as a keyDown with the
        // modifier's keyCode) carries the modifier keyCode and produces no
        // text. The keyCode is preserved as the modifier's MonaKeyCode.
        let gateway = MonaAppKeyEventGateway()
        // kVK_Shift = 56, no characters, .shift flag.
        let event = keyEvent(
            keyCode: 56,
            characters: "",
            modifierFlags: .shift
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.keyCode, .shift)
        XCTAssertNil(translated.keyText)
        XCTAssertEqual(translated.modifiers, .shift)
    }

    func testGatewayUnknownMacKeyCodeBecomesCustomCode() {
        // An unrecognized macOS key code is carried as custom(_) — NOT dropped
        // and NOT collapsed to a known case.
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(
            keyCode: 200,
            characters: ""
        )
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.keyCode, .custom(200))
        XCTAssertEqual(translated.keyCode.rawValue, 200)
        XCTAssertNotEqual(translated.keyCode, .unknown)
        XCTAssertNil(translated.keyText)
    }

    func testGatewayTranslationIsStableAcrossRepeatedCalls() {
        // Translating the same NSEvent more than once yields equal neutral
        // events — the gateway performs a pure, single-step translation with
        // no accumulating state and no re-translation path.
        let gateway = MonaAppKeyEventGateway()
        let event = keyEvent(keyCode: 40, characters: "k", modifierFlags: .command)
        let first = gateway.translateKeyDown(event, isComposing: false)
        let second = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(first, second)
    }

    // MARK: - MonaAppKeyEventGateway: native dispatch-boundary application

    func testApplyDefaultOutcomeIsPassThrough() {
        // The all-false default outcome leaves the platform to do its default
        // behavior: no prevention, no propagation stop.
        let gateway = MonaAppKeyEventGateway()
        let action = gateway.apply(MonaKeyDispatchOutcome.default)
        XCTAssertFalse(action.preventDefault)
        XCTAssertFalse(action.stopPropagation)
    }

    func testApplyPreventDefaultOutcomePreventsNSEventDefault() {
        // preventDefault → the platform suppresses the NSEvent's default
        // behavior (do not feed the input context, do not beep).
        let gateway = MonaAppKeyEventGateway()
        let outcome = MonaKeyDispatchOutcome(
            handled: false,
            preventDefault: true,
            stopPropagation: false
        )
        let action = gateway.apply(outcome)
        XCTAssertTrue(action.preventDefault)
        XCTAssertFalse(action.stopPropagation)
    }

    func testApplyStopPropagationOutcomeStopsResponderChain() {
        // stopPropagation → the event stops bubbling up the responder chain.
        let gateway = MonaAppKeyEventGateway()
        let outcome = MonaKeyDispatchOutcome(
            handled: false,
            preventDefault: false,
            stopPropagation: true
        )
        let action = gateway.apply(outcome)
        XCTAssertFalse(action.preventDefault)
        XCTAssertTrue(action.stopPropagation)
    }

    func testApplyHandledOutcomeDoesNotConflateHandledWithPreventDefault() {
        // `handled` records whether a Core handler consumed the event. It is
        // SEPARATE from `preventDefault` (per P04-T001's three-independent-
        // flags design). A handled-only outcome does NOT, by itself, instruct
        // the platform to prevent the default — the resolver sets
        // `preventDefault` explicitly when it wants default suppression.
        let gateway = MonaAppKeyEventGateway()
        let outcome = MonaKeyDispatchOutcome(
            handled: true,
            preventDefault: false,
            stopPropagation: false
        )
        let action = gateway.apply(outcome)
        XCTAssertFalse(action.preventDefault)
        XCTAssertFalse(action.stopPropagation)
    }

    func testApplyFullyResolvedOutcomeSetsBothNativeFlags() {
        let gateway = MonaAppKeyEventGateway()
        let outcome = MonaKeyDispatchOutcome(
            handled: true,
            preventDefault: true,
            stopPropagation: true
        )
        let action = gateway.apply(outcome)
        XCTAssertTrue(action.preventDefault)
        XCTAssertTrue(action.stopPropagation)
    }

    func testApplyOutcomeProducesValueTypeEquatableAction() {
        // The native action is an immutable value type; equal outcomes produce
        // equal actions.
        let gateway = MonaAppKeyEventGateway()
        let outcome = MonaKeyDispatchOutcome(
            handled: false,
            preventDefault: true,
            stopPropagation: true
        )
        XCTAssertEqual(gateway.apply(outcome), gateway.apply(outcome))
    }
}
