// MonaValueEnumTests.swift
//
// P01-T004 — Implement key, modifier, token, and marker value types.
//
// Verifies the four base value types that mirror Monaco's standalone enums and
// the `Token` class, ported with the frozen raw-value layout (NOT reordered or
// compressed):
//
//   - `MonaKeyCode`     — extensible raw-value wrapper for `monaco.KeyCode`.
//                         All 134 known codes (DependsOnKbLayout = -1 …
//                         MAX_VALUE = 132) are exposed as static constants, and
//                         any unknown numeric value is accepted via
//                         `custom(_:)` / `init(rawValue:)`.
//   - `MonaKeyMod`      — `OptionSet` over Monaco's modifier bit layout
//                         (CtrlCmd = 2048, Shift = 1024, Alt = 512,
//                         WinCtrl = 256). Bit-composable and serializable: a
//                         keybinding number is `modifierBits | keyCode`, and a
//                         two-part chord is `first | (second << 16)`.
//   - `MonaToken`       — faithful port of `monaco.Token`: `offset` / `type` /
//                         `language` / `_tokenBrand` (Void) / `toString()`.
//                         Offsets are preserved verbatim. A companion
//                         `MonaTokenType` extensible raw-value wrapper carries
//                         the known `StandardTokenType` encodings (0…3) plus
//                         `custom(_:)` for unknown numeric encodings.
//   - `MonaMarker`      — carries a `MonaMarkerSeverity`; severity raw values
//                         keep Monaco's bit layout (Hint = 1, Info = 2,
//                         Warning = 4, Error = 8) and `Comparable` orders
//                         Error > Warning > Info > Hint. `MonaMarkerTag`
//                         keeps Unnecessary = 1, Deprecated = 2.

import XCTest
import MonaCode

final class MonaValueEnumTests: XCTestCase {

    // MARK: - MonaKeyCode (extensible raw-value wrapper)

    func testKeyCodeKnownCodesPreserveMonacoRawValues() {
        // The full -1 … 132 span is present with the exact Monaco values.
        XCTAssertEqual(MonaKeyCode.dependsOnKbLayout.rawValue, -1)
        XCTAssertEqual(MonaKeyCode.unknown.rawValue, 0)
        XCTAssertEqual(MonaKeyCode.backspace.rawValue, 1)
        XCTAssertEqual(MonaKeyCode.tab.rawValue, 2)
        XCTAssertEqual(MonaKeyCode.enter.rawValue, 3)
        XCTAssertEqual(MonaKeyCode.shift.rawValue, 4)
        XCTAssertEqual(MonaKeyCode.ctrl.rawValue, 5)
        XCTAssertEqual(MonaKeyCode.alt.rawValue, 6)
        XCTAssertEqual(MonaKeyCode.capsLock.rawValue, 8)
        XCTAssertEqual(MonaKeyCode.escape.rawValue, 9)
        XCTAssertEqual(MonaKeyCode.space.rawValue, 10)
        XCTAssertEqual(MonaKeyCode.pageUp.rawValue, 11)
        XCTAssertEqual(MonaKeyCode.pageDown.rawValue, 12)
        XCTAssertEqual(MonaKeyCode.end.rawValue, 13)
        XCTAssertEqual(MonaKeyCode.home.rawValue, 14)
        XCTAssertEqual(MonaKeyCode.leftArrow.rawValue, 15)
        XCTAssertEqual(MonaKeyCode.upArrow.rawValue, 16)
        XCTAssertEqual(MonaKeyCode.rightArrow.rawValue, 17)
        XCTAssertEqual(MonaKeyCode.downArrow.rawValue, 18)
        XCTAssertEqual(MonaKeyCode.insert.rawValue, 19)
        XCTAssertEqual(MonaKeyCode.delete.rawValue, 20)
        XCTAssertEqual(MonaKeyCode.digit0.rawValue, 21)
        XCTAssertEqual(MonaKeyCode.digit9.rawValue, 30)
        XCTAssertEqual(MonaKeyCode.keyA.rawValue, 31)
        XCTAssertEqual(MonaKeyCode.keyZ.rawValue, 56)
        XCTAssertEqual(MonaKeyCode.meta.rawValue, 57)
        XCTAssertEqual(MonaKeyCode.contextMenu.rawValue, 58)
        XCTAssertEqual(MonaKeyCode.f1.rawValue, 59)
        XCTAssertEqual(MonaKeyCode.f12.rawValue, 70)
        XCTAssertEqual(MonaKeyCode.f24.rawValue, 82)
        XCTAssertEqual(MonaKeyCode.numLock.rawValue, 83)
        XCTAssertEqual(MonaKeyCode.scrollLock.rawValue, 84)
        XCTAssertEqual(MonaKeyCode.semicolon.rawValue, 85)
        XCTAssertEqual(MonaKeyCode.quote.rawValue, 95)
        XCTAssertEqual(MonaKeyCode.oem8.rawValue, 96)
        XCTAssertEqual(MonaKeyCode.intlBackslash.rawValue, 97)
        XCTAssertEqual(MonaKeyCode.numpad0.rawValue, 98)
        XCTAssertEqual(MonaKeyCode.numpad9.rawValue, 107)
        XCTAssertEqual(MonaKeyCode.numpadMultiply.rawValue, 108)
        XCTAssertEqual(MonaKeyCode.numpadAdd.rawValue, 109)
        XCTAssertEqual(MonaKeyCode.numpadSeparator.rawValue, 110)
        XCTAssertEqual(MonaKeyCode.numpadSubtract.rawValue, 111)
        XCTAssertEqual(MonaKeyCode.numpadDecimal.rawValue, 112)
        XCTAssertEqual(MonaKeyCode.numpadDivide.rawValue, 113)
        XCTAssertEqual(MonaKeyCode.keyInComposition.rawValue, 114)
        XCTAssertEqual(MonaKeyCode.abntC1.rawValue, 115)
        XCTAssertEqual(MonaKeyCode.abntC2.rawValue, 116)
        XCTAssertEqual(MonaKeyCode.audioVolumeMute.rawValue, 117)
        XCTAssertEqual(MonaKeyCode.audioVolumeUp.rawValue, 118)
        XCTAssertEqual(MonaKeyCode.audioVolumeDown.rawValue, 119)
        XCTAssertEqual(MonaKeyCode.browserSearch.rawValue, 120)
        XCTAssertEqual(MonaKeyCode.browserHome.rawValue, 121)
        XCTAssertEqual(MonaKeyCode.browserBack.rawValue, 122)
        XCTAssertEqual(MonaKeyCode.browserForward.rawValue, 123)
        XCTAssertEqual(MonaKeyCode.mediaTrackNext.rawValue, 124)
        XCTAssertEqual(MonaKeyCode.mediaTrackPrevious.rawValue, 125)
        XCTAssertEqual(MonaKeyCode.mediaStop.rawValue, 126)
        XCTAssertEqual(MonaKeyCode.mediaPlayPause.rawValue, 127)
        XCTAssertEqual(MonaKeyCode.launchMediaPlayer.rawValue, 128)
        XCTAssertEqual(MonaKeyCode.launchMail.rawValue, 129)
        XCTAssertEqual(MonaKeyCode.launchApp2.rawValue, 130)
        XCTAssertEqual(MonaKeyCode.clear.rawValue, 131)
        XCTAssertEqual(MonaKeyCode.maxValue.rawValue, 132)
    }

    func testKeyCodeAcceptsUnknownNumericValuesViaCustom() {
        // Monaco accepts numeric key codes outside the known enum (e.g. platform
        // codes surfaced before the enum catches up). The wrapper must round-trip
        // any integer verbatim.
        let unknown1 = MonaKeyCode.custom(133)
        let unknown2 = MonaKeyCode.custom(999)
        let negative = MonaKeyCode.custom(-7)

        XCTAssertEqual(unknown1.rawValue, 133)
        XCTAssertEqual(unknown2.rawValue, 999)
        XCTAssertEqual(negative.rawValue, -7)
    }

    func testKeyCodeInitRawValueAcceptsAnyInteger() {
        // `init(rawValue:)` is the canonical construction path; both known and
        // unknown values flow through it.
        XCTAssertEqual(MonaKeyCode(rawValue: 9), MonaKeyCode.escape)
        XCTAssertEqual(MonaKeyCode(rawValue: 132), MonaKeyCode.maxValue)
        XCTAssertEqual(MonaKeyCode(rawValue: -1), MonaKeyCode.dependsOnKbLayout)
        XCTAssertEqual(MonaKeyCode(rawValue: 500).rawValue, 500)
    }

    func testKeyCodeEqualityIsByRawValueRegardlessOfConstructionPath() {
        // Two construction paths that yield the same raw value are equal and
        // hash-equal: comparator identity is value-based.
        let known = MonaKeyCode.escape
        let viaRaw = MonaKeyCode(rawValue: 9)
        let viaCustom = MonaKeyCode.custom(9)

        XCTAssertEqual(known, viaRaw)
        XCTAssertEqual(known, viaCustom)
        XCTAssertEqual(known.hashValue, viaRaw.hashValue)
        XCTAssertEqual(known.hashValue, viaCustom.hashValue)
    }

    func testKeyCodeDistinctRawValuesAreNotEqual() {
        XCTAssertNotEqual(MonaKeyCode.tab, MonaKeyCode.enter)
        XCTAssertNotEqual(MonaKeyCode.custom(133), MonaKeyCode.maxValue)
        XCTAssertNotEqual(MonaKeyCode(rawValue: 9), MonaKeyCode(rawValue: 10))
    }

    // MARK: - MonaKeyMod (OptionSet, bit-composable + serializable)

    func testKeyModKnownMasksPreserveMonacoBitLayout() {
        // Monaco's KeyMod bit values are load-bearing for keybinding
        // serialization; they must NOT be reordered.
        XCTAssertEqual(MonaKeyMod.ctrlCmd.rawValue, 1 << 11)   // 2048
        XCTAssertEqual(MonaKeyMod.shift.rawValue,    1 << 10)   // 1024
        XCTAssertEqual(MonaKeyMod.alt.rawValue,      1 << 9)    // 512
        XCTAssertEqual(MonaKeyMod.winCtrl.rawValue, 1 << 8)    // 256

        XCTAssertEqual(MonaKeyMod.ctrlCmd.rawValue, 2048)
        XCTAssertEqual(MonaKeyMod.shift.rawValue, 1024)
        XCTAssertEqual(MonaKeyMod.alt.rawValue, 512)
        XCTAssertEqual(MonaKeyMod.winCtrl.rawValue, 256)
    }

    func testKeyModBitCompositionViaOptionSetLiteral() {
        // Modifiers compose with `|` (OptionSet). The union of CtrlCmd + Shift +
        // Alt + WinCtrl is the bitwise OR of all four masks.
        let all: MonaKeyMod = [.ctrlCmd, .shift, .alt, .winCtrl]
        XCTAssertEqual(all.rawValue, 2048 | 1024 | 512 | 256)
        XCTAssertEqual(all.rawValue, 0b111100000000)  // bits 8..11 set

        let pair: MonaKeyMod = [.ctrlCmd, .shift]
        XCTAssertEqual(pair.rawValue, 2048 | 1024)
        XCTAssertEqual(pair.rawValue, 3072)

        XCTAssertTrue(pair.contains(.ctrlCmd))
        XCTAssertTrue(pair.contains(.shift))
        XCTAssertFalse(pair.contains(.alt))
        XCTAssertFalse(pair.contains(.winCtrl))
    }

    func testKeyModEmptyIsZero() {
        let empty = MonaKeyMod(rawValue: 0)
        XCTAssertEqual(empty.rawValue, 0)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertFalse(MonaKeyMod.shift.isEmpty)
    }

    func testKeyModSerializesToKeybindingNumberWithKeyCode() {
        // A keybinding number is `modifierBits | keyCode`, mirroring Monaco's
        // `KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyK`.
        let mods: MonaKeyMod = [.ctrlCmd, .shift]
        let keyK = MonaKeyCode.keyK

        let keybinding = mods.rawValue | keyK.rawValue

        XCTAssertEqual(keybinding, 2048 | 1024 | 41)
        XCTAssertEqual(keybinding, 3113)

        // Round-trip: the modifier bits and the key code are recoverable from
        // the low 16 bits of the serialized keybinding.
        let lowMask = keybinding & 0x0000_FFFF
        XCTAssertTrue(MonaKeyMod(rawValue: lowMask).contains(.ctrlCmd))
        XCTAssertTrue(MonaKeyMod(rawValue: lowMask).contains(.shift))
        XCTAssertEqual(MonaKeyCode(rawValue: lowMask & 0x00FF), keyK)
    }

    func testKeyModChordCombinesTwoPartsIntoOneNumber() {
        // `KeyMod.chord(first, second)` packs a two-part keybinding into one
        // number: firstPart | (secondPart << 16), matching Monaco.
        let first  = MonaKeyMod.ctrlCmd.rawValue | MonaKeyCode.keyK.rawValue   // Cmd+K
        let second = MonaKeyMod.ctrlCmd.rawValue | MonaKeyCode.keyC.rawValue   // Cmd+C

        let chord = MonaKeyMod.chord(firstPart: first, secondPart: second)

        XCTAssertEqual(chord, first | ((second & 0x0000_FFFF) << 16))
        XCTAssertEqual(chord & 0x0000_FFFF, first)
        XCTAssertEqual((chord & 0xFFFF_0000) >> 16, second & 0x0000_FFFF)
    }

    func testKeyModFirstAndSecondPartExtractChordHalves() {
        let first  = MonaKeyMod.shift.rawValue | MonaKeyCode.digit1.rawValue
        let second = MonaKeyMod.alt.rawValue   | MonaKeyCode.digit2.rawValue
        let chord  = MonaKeyMod.chord(firstPart: first, secondPart: second)

        XCTAssertEqual(MonaKeyMod.firstPart(of: chord), first)
        XCTAssertEqual(MonaKeyMod.secondPart(of: chord), second & 0x0000_FFFF)
    }

    // MARK: - MonaToken (offset/type/language/brand/toString) + MonaTokenType

    func testTokenPreservesOffsetTypeLanguageVerbatim() {
        let token = MonaToken(offset: 42, type: "keyword.ts", language: "typescript")

        XCTAssertEqual(token.offset, 42)
        XCTAssertEqual(token.type, "keyword.ts")
        XCTAssertEqual(token.language, "typescript")
    }

    func testTokenPreservesLargeAndZeroOffsets() {
        // Offsets are raw UTF-16 code-unit offsets; never clamped or converted.
        let zero = MonaToken(offset: 0, type: "", language: "")
        XCTAssertEqual(zero.offset, 0)

        let large = MonaToken(offset: 0x10FFFF, type: "string.json", language: "json")
        XCTAssertEqual(large.offset, 0x10FFFF)
    }

    func testTokenBrandIsAVoidField() {
        // Monaco's `Token` carries a `_tokenBrand: void` field. It participates
        // in the API surface but holds no data; two tokens with equal
        // offset/type/language are equal regardless of brand. `Void` has only
        // one value (`()`), so there is nothing to compare — the brand's
        // contract is that it type-checks as `Void` and is accessible.
        let a = MonaToken(offset: 1, type: "number", language: "plaintext")
        let b = MonaToken(offset: 1, type: "number", language: "plaintext")

        // `_tokenBrand` is `Void`-typed; binding it to `Void` would fail to
        // compile otherwise.
        let brandA: Void = a._tokenBrand
        let brandB: Void = b._tokenBrand
        _ = (brandA, brandB)  // silence unused-variable warnings

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testTokenToStringUsesMonacoFormat() {
        // Monaco's `Token.toString()` returns `[offset|type|language]`.
        let token = MonaToken(offset: 7, type: "keyword.ts", language: "typescript")
        XCTAssertEqual(token.toString(), "[7|keyword.ts|typescript]")

        let empty = MonaToken(offset: 0, type: "", language: "")
        XCTAssertEqual(empty.toString(), "[0||]")
    }

    func testTokenEqualityByOffsetTypeLanguageAndHashStability() {
        let a = MonaToken(offset: 10, type: "comment", language: "javascript")
        let b = MonaToken(offset: 10, type: "comment", language: "javascript")
        let c = MonaToken(offset: 10, type: "string",  language: "javascript")
        let d = MonaToken(offset: 11, type: "comment", language: "javascript")
        let e = MonaToken(offset: 10, type: "comment", language: "typescript")

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(a, e)
    }

    func testTokenTypeKnownEncodingsPreserveMonacoValues() {
        // StandardTokenType: Other = 0, Comment = 1, String = 2, RegEx = 3.
        XCTAssertEqual(MonaTokenType.other.rawValue, 0)
        XCTAssertEqual(MonaTokenType.comment.rawValue, 1)
        XCTAssertEqual(MonaTokenType.string.rawValue, 2)
        XCTAssertEqual(MonaTokenType.regEx.rawValue, 3)
    }

    func testTokenTypeAcceptsUnknownNumericEncodingsViaCustom() {
        let unknown = MonaTokenType.custom(4)
        XCTAssertEqual(unknown.rawValue, 4)

        XCTAssertEqual(MonaTokenType(rawValue: 3), MonaTokenType.regEx)
        XCTAssertEqual(MonaTokenType(rawValue: 9).rawValue, 9)
    }

    func testTokenTypeEqualityByRawValueRegardlessOfConstructionPath() {
        XCTAssertEqual(MonaTokenType.comment, MonaTokenType(rawValue: 1))
        XCTAssertEqual(MonaTokenType.comment, MonaTokenType.custom(1))
        XCTAssertEqual(MonaTokenType.comment.hashValue, MonaTokenType.custom(1).hashValue)
        XCTAssertNotEqual(MonaTokenType.other, MonaTokenType.comment)
    }

    // MARK: - MonaMarker (severity ordering + tag) + MonaMarkerSeverity + MonaMarkerTag

    func testMarkerSeverityKnownValuesPreserveMonacoBitLayout() {
        // MarkerSeverity keeps Monaco's bit-flag layout (NOT 1,2,3,4): the gap
        // between Info (2) and Warning (4) is intentional and load-bearing.
        XCTAssertEqual(MonaMarkerSeverity.hint.rawValue, 1)
        XCTAssertEqual(MonaMarkerSeverity.info.rawValue, 2)
        XCTAssertEqual(MonaMarkerSeverity.warning.rawValue, 4)
        XCTAssertEqual(MonaMarkerSeverity.error.rawValue, 8)
    }

    func testMarkerSeverityComparableOrdersErrorAboveWarningAboveInfoAboveHint() {
        // The required ordering: Error > Warning > Info > Hint.
        XCTAssertTrue(MonaMarkerSeverity.error > MonaMarkerSeverity.warning)
        XCTAssertTrue(MonaMarkerSeverity.warning > MonaMarkerSeverity.info)
        XCTAssertTrue(MonaMarkerSeverity.info > MonaMarkerSeverity.hint)
        XCTAssertTrue(MonaMarkerSeverity.error > MonaMarkerSeverity.hint)

        // Reverse direction for completeness.
        XCTAssertFalse(MonaMarkerSeverity.hint > MonaMarkerSeverity.info)
        XCTAssertFalse(MonaMarkerSeverity.info > MonaMarkerSeverity.warning)
        XCTAssertFalse(MonaMarkerSeverity.warning > MonaMarkerSeverity.error)

        // Equal severities are not strictly ordered against each other.
        XCTAssertFalse(MonaMarkerSeverity.error > MonaMarkerSeverity.error)
    }

    func testMarkerSeverityMinAndMax() {
        XCTAssertEqual(MonaMarkerSeverity.hint, MonaMarkerSeverity.min)
        XCTAssertEqual(MonaMarkerSeverity.error, MonaMarkerSeverity.max)
    }

    func testMarkerTagKnownValuesPreserveMonacoValues() {
        XCTAssertEqual(MonaMarkerTag.unnecessary.rawValue, 1)
        XCTAssertEqual(MonaMarkerTag.deprecated.rawValue, 2)
    }

    func testMarkerTagDistinctValuesNotEqual() {
        XCTAssertNotEqual(MonaMarkerTag.unnecessary, MonaMarkerTag.deprecated)
        XCTAssertNotEqual(MonaMarkerTag.unnecessary, MonaMarkerTag(rawValue: 2))
    }

    func testMarkerCarriesSeverityAndTag() {
        let marker = MonaMarker(
            severity: .warning,
            message: "Unused variable",
            tag: .unnecessary
        )

        XCTAssertEqual(marker.severity, .warning)
        XCTAssertEqual(marker.message, "Unused variable")
        XCTAssertEqual(marker.tag, .unnecessary)
    }

    func testMarkerEqualityBySeverityMessageAndTag() {
        let a = MonaMarker(severity: .error, message: "Syntax error", tag: .deprecated)
        let b = MonaMarker(severity: .error, message: "Syntax error", tag: .deprecated)
        let c = MonaMarker(severity: .warning, message: "Syntax error", tag: .deprecated)
        let d = MonaMarker(severity: .error, message: "Other", tag: .deprecated)
        let e = MonaMarker(severity: .error, message: "Syntax error", tag: .unnecessary)

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(a, e)
    }

    func testMarkerTagIsOptional() {
        // A marker need not carry a tag.
        let plain = MonaMarker(severity: .info, message: "Hint only", tag: nil)
        XCTAssertEqual(plain.severity, .info)
        XCTAssertNil(plain.tag)
    }
}
