// MonaAXTextAreaTests.swift
//
// P04-T010 — Expose the raw UTF-16 native text accessibility surface.
//
// Verifies the native-text accessibility surface for the AppKit editor: the
// value / selection / visible-range / attributed-substring / range-for-position /
// bounds-for-range / position-for-range / line-mapping selectors that macOS
// accessibility clients (VoiceOver, the AXUIElement API) call.
//
//   - `MonaAXTextArea`           — the persistent AX text surface. Holds an
//                                  indirect model + geometry barrier reference,
//                                  exposes the frozen native-text selectors, and
//                                  routes geometry through the complete-
//                                  generation barrier (P03-T007).
//   - `MonaAXTextRangeMapper`    — converts between accessibility integer
//                                  ranges (NSRange, UTF-16 unit offsets as AX
//                                  clients see them) and raw model UTF-16
//                                  offsets / MonaRange. A pure integer
//                                  translation with NO surrogate repair: a lone
//                                  surrogate counts as exactly one UTF-16 unit on
//                                  both sides.
//
// Test contract (P04-T010): value (raw UTF-16, no repair), selection, visible
// range (gated on generation), attributed substring, range-for-position,
// bounds-for-range, position-for-range (through the barrier), and line mapping;
// the range mapper translates NSRange <-> MonaRange without repair.

import XCTest
import AppKit
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaAXTextAreaTests: XCTestCase {

    // MARK: - Shared helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// Creates a model from raw UTF-16 `[UInt16]` so lone surrogates survive.
    private func makeModel(_ units: [UInt16]) -> MonaCodeModel {
        return MonaCodeModel(units: units, uri: MonaURI(scheme: "inmemory", path: "/ax"))
    }

    /// Creates a model from a `String` (lone surrogates in the String literal are
    /// already repaired by Swift; use `makeModel(_:)` with raw units to test
    /// lone-surrogate preservation).
    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/ax"))
    }

    /// Builds a geometry barrier over a real model + view graph + scroll model
    /// + builder (mirrors `MonaDragDropServicesTests.makeBarrier`).
    @discardableResult
    private func makeBarrier(
        text: String = "abc\ndef",
        lineHeight: Int = 20
    ) -> (MonaQueryGeometryBarrier, MonaCodeModel, MonaScrollModel) {
        let model = MonaCodeModel(text: text, uri: MonaURI.parse("monacode:ax")!)
        let viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 400, contentHeight: Double(2 * lineHeight),
            viewportWidth: 400, viewportHeight: Double(lineHeight)
        )
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let provider: (Int) -> [UInt16] = { lineNum in
            Array(model.getLineContent(lineNum).utf16)
        }
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: provider
        )
        return (barrier, model, scrollModel)
    }

    // MARK: - MonaAXTextRangeMapper: NSRange <-> MonaRange (no repair)

    /// The mapper converts an NSRange over "abc\ndef" (length 7) to the
    /// equivalent MonaRange via raw model UTF-16 offsets. No surrogate repair.
    func testMapperConvertsNSRangeToMonaRange() {
        let model = makeModel("abc\ndef")
        let mapper = MonaAXTextRangeMapper(model: model)

        // NSRange(0, 3) -> positions (1,1)..(1,4) = "abc".
        let range = mapper.monaRange(for: NSRange(location: 0, length: 3))
        XCTAssertEqual(range.startPosition, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(range.endPosition, MonaPosition(line: 1, column: 4))
    }

    /// The mapper converts a MonaRange back to an NSRange via raw model offsets.
    func testMapperConvertsMonaRangeToNSRange() {
        let model = makeModel("abc\ndef")
        let mapper = MonaAXTextRangeMapper(model: model)

        // (1,1)..(2,2) covers "abc\nd" = offsets 0..<5 -> NSRange(0, 5).
        let range = MonaRange(startLine: 1, startColumn: 1, endLine: 2, endColumn: 2)
        XCTAssertEqual(mapper.axRange(for: range), NSRange(location: 0, length: 5))
    }

    /// The mapper is a pure integer translation: a lone surrogate (0xD800)
    /// counts as exactly one UTF-16 unit on both sides — no repair, no merge,
    /// no U+FFFD substitution.
    func testMapperPreservesLoneSurrogateAsOneUnit() {
        // Raw units: "a" + lone high surrogate (0xD800) + "\n" + "b".
        let model = makeModel([0x0061, 0xD800, 0x000A, 0x0062])
        let mapper = MonaAXTextRangeMapper(model: model)

        // Offset 1 is the lone surrogate; the range (1, 1) covers exactly it.
        let range = mapper.monaRange(for: NSRange(location: 1, length: 1))
        // Position at offset 1 = line 1, column 2 (the lone surrogate).
        XCTAssertEqual(range.startPosition, MonaPosition(line: 1, column: 2))
        // Position at offset 2 = line 1, column 3 (past the surrogate).
        XCTAssertEqual(range.endPosition, MonaPosition(line: 1, column: 3))

        // Round-trip: MonaRange back to NSRange(1, 1). The surrogate did not
        // expand, merge, or get replaced.
        XCTAssertEqual(mapper.axRange(for: range), NSRange(location: 1, length: 1))
    }

    /// The mapper's offset conversion is identity: an AX UTF-16 offset maps
    /// 1:1 to a raw model offset (both are UTF-16 unit indices over the same
    /// raw storage), with no normalization.
    func testMapperOffsetConversionIsIdentity() {
        let model = makeModel([0x0061, 0xD800, 0x0062])
        let mapper = MonaAXTextRangeMapper(model: model)
        XCTAssertEqual(mapper.modelOffset(forAxOffset: 1), 1)
        XCTAssertEqual(mapper.axOffset(forModelOffset: 1), 1)
    }

    // MARK: - MonaAXTextArea: value (full text, raw UTF-16, no repair)

    /// `value` exposes the full text as an NSString built from the raw model
    /// UTF-16 units. The length matches the model's raw unit count.
    func testValueReturnsFullTextAsRawUTF16NSString() {
        let model = makeModel("abc\ndef")
        let area = MonaAXTextArea(model: model)

        let value = area.value
        XCTAssertEqual(value.length, 7)
        XCTAssertEqual(value.character(at: 0), 0x0061) // 'a'
        XCTAssertEqual(value.character(at: 3), 0x000A) // '\n'
        XCTAssertEqual(value.character(at: 6), 0x0066) // 'f'
    }

    /// `value` preserves a lone surrogate (0xD800) verbatim — no U+FFFD repair.
    /// This is the raw UTF-16 native text contract.
    func testValuePreservesLoneSurrogateWithoutRepair() {
        let model = makeModel([0x0061, 0xD800, 0x0062])
        let area = MonaAXTextArea(model: model)

        let value = area.value
        XCTAssertEqual(value.length, 3, "lone surrogate counts as one UTF-16 unit")
        XCTAssertEqual(value.character(at: 1), 0xD800, "lone surrogate must not be repaired to U+FFFD")
    }

    /// `numberOfCharacters` reports the raw UTF-16 unit count.
    func testNumberOfCharactersIsRawUTF16Length() {
        let model = makeModel([0x0061, 0xD800, 0x0062])
        let area = MonaAXTextArea(model: model)
        XCTAssertEqual(area.numberOfCharacters, 3)
    }

    // MARK: - MonaAXTextArea: selection (settable NSRange)

    /// `selectionRange` is settable AX state: the editor / AX element graph
    /// syncs the selection in; AX clients read it back as an NSRange.
    func testSelectionRangeIsSettableAndRoundTrips() {
        let model = makeModel("abc\ndef")
        let area = MonaAXTextArea(model: model)

        // Defaults to a folded range at offset 0.
        XCTAssertEqual(area.selectionRange, NSRange(location: 0, length: 0))

        area.selectionRange = NSRange(location: 1, length: 2)
        XCTAssertEqual(area.selectionRange, NSRange(location: 1, length: 2))
    }

    // MARK: - MonaAXTextArea: attributed substring (raw UTF-16, no repair)

    /// `attributedSubstring(for:)` returns an NSAttributedString for the range,
    /// built from the raw model UTF-16 units — lone surrogates survive.
    func testAttributedSubstringReturnsRawUTF16Substring() {
        let model = makeModel([0x0061, 0xD800, 0x0062])
        let area = MonaAXTextArea(model: model)

        // Substring covering the lone surrogate at offset 1.
        let attr = area.attributedSubstring(for: NSRange(location: 1, length: 1))
        XCTAssertNotNil(attr)
        XCTAssertEqual(attr?.length, 1, "lone surrogate counts as one UTF-16 unit")
        // Read the raw code unit through the CFString interface — the Swift
        // `String` bridge repairs lone surrogates to U+FFFD, so `.string` cannot
        // be used to verify the raw unit was preserved. CFString reads the
        // underlying UTF-16 storage verbatim.
        let cfStr = CFAttributedStringGetString(attr! as CFAttributedString)
        XCTAssertEqual(CFStringGetLength(cfStr), 1)
        XCTAssertEqual(CFStringGetCharacterAtIndex(cfStr, 0), 0xD800,
                       "lone surrogate must survive in the attributed substring")
    }

    /// `attributedSubstring(for:)` returns nil for an out-of-bounds range.
    func testAttributedSubstringReturnsNilForOutOfBounds() {
        let model = makeModel("abc")
        let area = MonaAXTextArea(model: model)
        XCTAssertNil(area.attributedSubstring(for: NSRange(location: 10, length: 1)))
    }

    // MARK: - MonaAXTextArea: line mapping

    /// `line(forCharacterIndex:)` maps a UTF-16 offset to a 1-based line number.
    func testLineForCharacterIndexMapsOffsetToLineNumber() {
        let model = makeModel("abc\ndef")
        let area = MonaAXTextArea(model: model)

        XCTAssertEqual(area.line(forCharacterIndex: 0), 1) // 'a'
        XCTAssertEqual(area.line(forCharacterIndex: 2), 1) // 'c'
        XCTAssertEqual(area.line(forCharacterIndex: 4), 2) // 'd'
        XCTAssertEqual(area.line(forCharacterIndex: 6), 2) // 'f'
    }

    /// `range(forLine:)` maps a 1-based line number to the NSRange spanning that
    /// line's content (including a trailing newline for non-final lines).
    func testRangeForLineMapsLineNumberToNSRange() {
        let model = makeModel("abc\ndef")
        let area = MonaAXTextArea(model: model)

        // Line 1: "abc\n" = offsets 0..<4.
        XCTAssertEqual(area.range(forLine: 1), NSRange(location: 0, length: 4))
        // Line 2: "def" = offsets 4..<7 (no trailing newline).
        XCTAssertEqual(area.range(forLine: 2), NSRange(location: 4, length: 3))
    }

    // MARK: - MonaAXTextArea: visible range (gated on generation)

    /// Without a geometry barrier, `visibleRange` falls back to the full range
    /// (the safe default for AX clients when no layout generation is known).
    func testVisibleRangeWithoutBarrierFallsBackToFullRange() {
        let model = makeModel("abc\ndef")
        let area = MonaAXTextArea(model: model)
        XCTAssertEqual(area.visibleRange, NSRange(location: 0, length: 7))
    }

    /// With a barrier that has NOT yet published a generation, `visibleRange`
    /// falls back to the full range (no partial geometry is synthesized).
    func testVisibleRangeBeforeGenerationFallsBackToFullRange() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 20) }
        )
        // No publishGeneration yet -> no complete generation -> full range.
        XCTAssertEqual(area.visibleRange, NSRange(location: 0, length: 7))
    }

    /// With a published generation and a one-line viewport, `visibleRange` is
    /// the range of the visible characters (line 1 = offsets 0..<4).
    func testVisibleRangeWithGenerationClampsToVisibleCharacters() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 20) }
        )
        // Viewport height 20 = one line; visible = "abc\n" = offsets 0..<4.
        XCTAssertEqual(area.visibleRange, NSRange(location: 0, length: 4))
    }

    /// With a viewport that shows the whole document, `visibleRange` spans the
    /// full text.
    func testVisibleRangeWithFullViewportSpansWholeDocument() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 40) }
        )
        XCTAssertEqual(area.visibleRange, NSRange(location: 0, length: 7))
    }

    // MARK: - MonaAXTextArea: geometry queries (routed through the barrier)

    /// `range(forPosition:)` resolves a viewport-space point to the NSRange of
    /// the character at that position through the geometry barrier.
    func testRangeForPositionResolvesThroughBarrier() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 40) }
        )

        // x=0, y=10 -> line 1, column 1 -> offset 0 -> character 'a' = (0, 1).
        let range = area.range(forPosition: CGPoint(x: 0, y: 10))
        XCTAssertEqual(range, NSRange(location: 0, length: 1))
    }

    /// `range(forPosition:)` returns nil when the barrier has no complete
    /// generation (no partial geometry is synthesized).
    func testRangeForPositionReturnsNilWithoutGeneration() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        // No publishGeneration.
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 40) }
        )
        XCTAssertNil(area.range(forPosition: CGPoint(x: 0, y: 10)))
    }

    /// `range(forPosition:)` returns nil when no barrier is configured.
    func testRangeForPositionReturnsNilWithoutBarrier() {
        let model = makeModel("abc\ndef")
        let area = MonaAXTextArea(model: model)
        XCTAssertNil(area.range(forPosition: CGPoint(x: 0, y: 10)))
    }

    /// `bounds(forRange:)` resolves an NSRange to a CGRect through the barrier.
    func testBoundsForRangeResolvesThroughBarrier() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 40) }
        )

        // Range covering the first character of line 1: offset 0..<1.
        let rect = area.bounds(forRange: NSRange(location: 0, length: 1))
        XCTAssertNotNil(rect)
        XCTAssertEqual(rect?.origin.x, 0)
        XCTAssertEqual(rect?.origin.y, 0)
        XCTAssertEqual(rect?.height, 20)
        XCTAssertGreaterThan(rect?.width ?? 0, 0)
    }

    /// `bounds(forRange:)` returns nil without a complete generation.
    func testBoundsForRangeReturnsNilWithoutGeneration() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 40) }
        )
        XCTAssertNil(area.bounds(forRange: NSRange(location: 0, length: 1)))
    }

    /// `position(forRange:)` resolves an NSRange to a viewport-space point
    /// (the origin of the range's first character) through the barrier.
    func testPositionForRangeResolvesThroughBarrier() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 40) }
        )

        // Caret at (1,1) -> offset 0 -> origin (0, 0).
        let point = area.position(forRange: NSRange(location: 0, length: 0))
        XCTAssertEqual(point, CGPoint(x: 0, y: 0))
    }

    /// `position(forRange:)` returns nil without a complete generation.
    func testPositionForRangeReturnsNilWithoutGeneration() {
        let (barrier, model, _) = makeBarrier(text: "abc\ndef")
        let area = MonaAXTextArea(
            model: model,
            geometryBarrier: barrier,
            viewportSize: { CGSize(width: 400, height: 40) }
        )
        XCTAssertNil(area.position(forRange: NSRange(location: 0, length: 0)))
    }

    // MARK: - MonaAXTextArea: raw UTF-16 invariant end-to-end

    /// The full AX text surface is consistent with the raw model: the value
    /// length, the range mapper, and the geometry offsets all agree on raw
    /// UTF-16 unit counts — a lone surrogate is one unit everywhere.
    func testAXSurfaceIsConsistentWithRawUTF16Units() {
        // "a" + lone surrogate + "\n" + "b"
        let model = makeModel([0x0061, 0xD800, 0x000A, 0x0062])
        let area = MonaAXTextArea(model: model)
        let mapper = MonaAXTextRangeMapper(model: model)

        XCTAssertEqual(area.numberOfCharacters, 4)
        XCTAssertEqual(area.value.length, 4)

        // Line 1 = "a" + surrogate + "\n" = offsets 0..<3.
        XCTAssertEqual(area.range(forLine: 1), NSRange(location: 0, length: 3))
        // The lone surrogate is on line 1.
        XCTAssertEqual(area.line(forCharacterIndex: 1), 1)

        // The mapper agrees: NSRange(1, 1) is the lone surrogate, MonaRange
        // (1,2)..(1,3), round-trips exactly.
        let surrRange = mapper.monaRange(for: NSRange(location: 1, length: 1))
        XCTAssertEqual(surrRange, MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 3))
    }
}
