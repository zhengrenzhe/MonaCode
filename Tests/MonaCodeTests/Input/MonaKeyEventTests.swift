// MonaKeyEventTests.swift
//
// P04-T001 — Define platform-neutral keyboard event semantics in Core.
//
// Verifies the two platform-neutral Core input value types that carry a
// keyboard event through the editor pipeline:
//
//   - `MonaKeyEvent`           — platform-neutral keyboard event. Carries a
//                                 `MonaKeyCode` (P01-T004), scan-independent
//                                 `keyText`, `MonaKeyMod` modifiers, `isRepeat`,
//                                 `isComposing` (IME composition state), and a
//                                 `timestamp`. Immutable value type.
//   - `MonaKeyDispatchOutcome` — the dispatch *decision* (not the dispatch
//                                 itself). `handled`, `preventDefault`, and
//                                 `stopPropagation` are three independent
//                                 booleans, SEPARATE from platform dispatch:
//                                 the platform layer (AppKit) reads these and
//                                 applies them at the native boundary.
//
// Unknown key codes (`MonaKeyCode.custom(_:)`) are preserved through
// `MonaKeyEvent.keyCode` — they are NOT collapsed to a known case.

import XCTest
import MonaCode

final class MonaKeyEventTests: XCTestCase {

    // MARK: - MonaKeyEvent construction & field preservation

    func testKeyEventStoresKeyCodeKeyTextModifiersRepeatComposingTimestamp() {
        // A printable key with text: Cmd+K during composition.
        let event = MonaKeyEvent(
            keyCode: .keyK,
            keyText: "k",
            modifiers: [.ctrlCmd],
            isRepeat: true,
            isComposing: false,
            timestamp: 12345.678
        )

        XCTAssertEqual(event.keyCode, .keyK)
        XCTAssertEqual(event.keyText, "k")
        XCTAssertEqual(event.modifiers, .ctrlCmd)
        XCTAssertTrue(event.isRepeat)
        XCTAssertFalse(event.isComposing)
        XCTAssertEqual(event.timestamp, 12345.678, accuracy: 1e-9)
    }

    func testKeyEventKeyTextIsOptionalForNonPrintingKeys() {
        // Arrow keys, function keys, and modifier-only presses produce no
        // text. keyText is nil for those — it is the scan-independent text the
        // key produces, independent of keyboard-layout scan code.
        let arrow = MonaKeyEvent(
            keyCode: .leftArrow,
            keyText: nil,
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 1.0
        )
        XCTAssertNil(arrow.keyText)

        let fn = MonaKeyEvent(
            keyCode: .f5,
            keyText: nil,
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 2.0
        )
        XCTAssertNil(fn.keyText)

        // A shift-only press carries the modifier but no produced text.
        let shiftOnly = MonaKeyEvent(
            keyCode: .shift,
            keyText: nil,
            modifiers: [.shift],
            isRepeat: false,
            isComposing: false,
            timestamp: 3.0
        )
        XCTAssertNil(shiftOnly.keyText)
        XCTAssertEqual(shiftOnly.modifiers, .shift)
    }

    func testKeyEventKeyTextCarriesProducedTextIndependentOfScanCode() {
        // The same physical key can produce different text under different
        // layouts (e.g. Dvorak vs QWERTY) or with Shift held. keyText is the
        // resolved produced text, NOT a scan-code-derived value.
        let lowerA = MonaKeyEvent(
            keyCode: .keyA,
            keyText: "a",
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        let upperA = MonaKeyEvent(
            keyCode: .keyA,
            keyText: "A",
            modifiers: [.shift],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        // Same key code, different produced text — both preserved verbatim.
        XCTAssertEqual(lowerA.keyCode, upperA.keyCode)
        XCTAssertEqual(lowerA.keyText, "a")
        XCTAssertEqual(upperA.keyText, "A")
        XCTAssertNotEqual(lowerA.keyText, upperA.keyText)
    }

    func testKeyEventModifiersComposeAsOptionSet() {
        // Modifiers flow through MonaKeyMod (P01-T004) and compose with the
        // standard OptionSet operators.
        let event = MonaKeyEvent(
            keyCode: .keyC,
            keyText: "c",
            modifiers: [.ctrlCmd, .shift],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        XCTAssertTrue(event.modifiers.contains(.ctrlCmd))
        XCTAssertTrue(event.modifiers.contains(.shift))
        XCTAssertFalse(event.modifiers.contains(.alt))
    }

    func testKeyEventIsRepeatAndIsComposingAreIndependent() {
        // A key can be repeating AND mid-composition (e.g. holding a key while
        // the IME is committing). The two flags are independent booleans.
        let both = MonaKeyEvent(
            keyCode: .keyInComposition,
            keyText: nil,
            modifiers: [],
            isRepeat: true,
            isComposing: true,
            timestamp: 0.0
        )
        XCTAssertTrue(both.isRepeat)
        XCTAssertTrue(both.isComposing)

        let neither = MonaKeyEvent(
            keyCode: .enter,
            keyText: "\n",
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        XCTAssertFalse(neither.isRepeat)
        XCTAssertFalse(neither.isComposing)
    }

    func testKeyEventIsImmutableValueType() {
        // MonaKeyEvent is a struct with immutable stored properties. Two events
        // with equal fields are equal; mutation is not possible in Swift without
        // `var` + a mutating setter, which the type does not expose.
        let a = MonaKeyEvent(
            keyCode: .space,
            keyText: " ",
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 7.0
        )
        let b = MonaKeyEvent(
            keyCode: .space,
            keyText: " ",
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 7.0
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - Unknown key codes are preserved (not collapsed to a known case)

    func testKeyEventPreservesUnknownCustomKeyCode() {
        // P01-T004: MonaKeyCode.custom(_:) accepts any integer outside the
        // known -1 … 132 span. P04-T001 preserves that code through the event
        // WITHOUT collapsing it to a known case (e.g. .unknown / .maxValue).
        let exotic = MonaKeyCode.custom(9001)
        let event = MonaKeyEvent(
            keyCode: exotic,
            keyText: nil,
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        XCTAssertEqual(event.keyCode, exotic)
        XCTAssertEqual(event.keyCode.rawValue, 9001)
        XCTAssertNotEqual(event.keyCode, .unknown)
        XCTAssertNotEqual(event.keyCode, .maxValue)
        XCTAssertNotEqual(event.keyCode, .dependsOnKbLayout)
    }

    func testKeyEventPreservesNegativeCustomKeyCode() {
        // A custom code below -1 (the DependsOnKbLayout sentinel) must also
        // survive intact.
        let negative = MonaKeyCode.custom(-42)
        let event = MonaKeyEvent(
            keyCode: negative,
            keyText: nil,
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        XCTAssertEqual(event.keyCode, negative)
        XCTAssertEqual(event.keyCode.rawValue, -42)
        XCTAssertNotEqual(event.keyCode, .dependsOnKbLayout)
    }

    func testKeyEventEqualityIsValueBasedAcrossKnownAndCustomCodes() {
        // A custom code equal in raw value to a known constant compares equal
        // (value-based equality, per P01-T004). The event wrappers follow.
        let known = MonaKeyEvent(
            keyCode: .escape,
            keyText: nil,
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        let viaCustom = MonaKeyEvent(
            keyCode: .custom(9), // escape.rawValue == 9
            keyText: nil,
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        XCTAssertEqual(known, viaCustom)
    }

    // MARK: - MonaKeyDispatchOutcome: three independent dispatch decisions

    func testDispatchOutcomeStoresHandledPreventDefaultStopPropagation() {
        let outcome = MonaKeyDispatchOutcome(
            handled: true,
            preventDefault: true,
            stopPropagation: false
        )
        XCTAssertTrue(outcome.handled)
        XCTAssertTrue(outcome.preventDefault)
        XCTAssertFalse(outcome.stopPropagation)
    }

    func testDispatchOutcomePreventDefaultAndStopPropagationAreIndependent() {
        // The three flags are independent. A handler may:
        //   (a) handle + prevent default, but let the event bubble, or
        //   (b) not handle, yet still stop propagation, or
        //   (c) prevent default without claiming the event was handled.
        let handleButBubble = MonaKeyDispatchOutcome(
            handled: true,
            preventDefault: true,
            stopPropagation: false
        )
        XCTAssertTrue(handleButBubble.handled)
        XCTAssertTrue(handleButBubble.preventDefault)
        XCTAssertFalse(handleButBubble.stopPropagation)

        let stopOnly = MonaKeyDispatchOutcome(
            handled: false,
            preventDefault: false,
            stopPropagation: true
        )
        XCTAssertFalse(stopOnly.handled)
        XCTAssertFalse(stopOnly.preventDefault)
        XCTAssertTrue(stopOnly.stopPropagation)

        let preventOnly = MonaKeyDispatchOutcome(
            handled: false,
            preventDefault: true,
            stopPropagation: false
        )
        XCTAssertFalse(preventOnly.handled)
        XCTAssertTrue(preventOnly.preventDefault)
        XCTAssertFalse(preventOnly.stopPropagation)
    }

    func testDispatchOutcomeIsSeparatedFromPlatformDispatch() {
        // The outcome is a pure value record of the dispatch DECISION. It does
        // not itself perform any platform dispatch (no AppKit, no NSResponder,
        // no side effects). The platform layer reads these flags and applies
        // them at the native boundary.
        //
        // Concretely: the default "pass-through" outcome carries all-false and
        // signals "let the platform do its default behavior". Constructing it
        // must not require any platform type.
        let passthrough = MonaKeyDispatchOutcome(
            handled: false,
            preventDefault: false,
            stopPropagation: false
        )
        XCTAssertFalse(passthrough.handled)
        XCTAssertFalse(passthrough.preventDefault)
        XCTAssertFalse(passthrough.stopPropagation)
    }

    func testDispatchOutcomeDefaultUnhandedPassthrough() {
        // A convenience accessor for the all-false pass-through outcome.
        let def = MonaKeyDispatchOutcome.default
        XCTAssertFalse(def.handled)
        XCTAssertFalse(def.preventDefault)
        XCTAssertFalse(def.stopPropagation)
        XCTAssertEqual(
            def,
            MonaKeyDispatchOutcome(handled: false, preventDefault: false, stopPropagation: false)
        )
    }

    func testDispatchOutcomeIsImmutableValueType() {
        let a = MonaKeyDispatchOutcome(
            handled: true,
            preventDefault: true,
            stopPropagation: true
        )
        let b = MonaKeyDispatchOutcome(
            handled: true,
            preventDefault: true,
            stopPropagation: true
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - End-to-end: event carries unknown code, outcome decides dispatch

    func testUnknownKeyCodeEventCanStillProduceHandledOutcome() {
        // An event with an unknown key code is not pre-collapsed to "unhandled".
        // The resolver (P04-T003) decides; here we verify the value types carry
        // both the unknown code and a fully-formed outcome without loss.
        let event = MonaKeyEvent(
            keyCode: .custom(7777),
            keyText: nil,
            modifiers: [.ctrlCmd],
            isRepeat: false,
            isComposing: false,
            timestamp: 9.9
        )
        let outcome = MonaKeyDispatchOutcome(
            handled: true,
            preventDefault: true,
            stopPropagation: true
        )
        XCTAssertEqual(event.keyCode.rawValue, 7777)
        XCTAssertNotEqual(event.keyCode, .unknown)
        XCTAssertTrue(outcome.handled)
        XCTAssertTrue(outcome.preventDefault)
        XCTAssertTrue(outcome.stopPropagation)
    }
}
