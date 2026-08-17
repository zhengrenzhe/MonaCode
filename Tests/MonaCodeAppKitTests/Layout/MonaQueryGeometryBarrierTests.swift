// MonaQueryGeometryBarrierTests.swift
//
// P03-T007 — Enforce the QueryGeometryBarrier for hit testing and native queries.
//
// Verifies the geometry query barrier and the hit tester:
//   - MonaQueryGeometryBarrier answers point/range/caret/selection geometry
//     ONLY from one complete generation (never partial state). It synchronously
//     finishes bounded visible-line work when an immediate query is needed, and
//     returns typed unavailable geometry (MonaGeometryUnavailable) when bounded
//     completion fails.
//   - MonaHitTester converts screen (viewport) coordinates to model positions
//     (hit testing) using MonaLineLayoutRecord.hitTest (P03-T003) + the
//     ViewGraph projection (P03-T001). hitTest(point:) -> MonaPosition?,
//     getCaretRect(position:), getRangeRects(range:).
//
// One contract case: the barrier answers only from a complete generation, the
// hit tester converts coordinates against the frozen record's hitTest, and
// bounded-completion failure yields typed unavailable geometry.

import XCTest
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaQueryGeometryBarrierTests: XCTestCase {

    // MARK: - Shared helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// One boundary covering one UTF-16 unit, `[startX, endX)`.
    private func unit(_ index: Int, _ startX: CGFloat, _ endX: CGFloat) -> MonaRawUnitBoundary {
        return MonaRawUnitBoundary(utf16Range: index..<(index + 1), startX: startX, endX: endX)
    }

    /// Builds an immutable layout record with the given raw-unit boundaries and
    /// source length. The other fields are filled with sensible defaults so the
    /// record is well-formed; the hit tester only reads `rawUnitBoundaries`,
    /// `sourceLength`, and `hitTest(offset:)`.
    private func makeRecord(
        boundaries: [MonaRawUnitBoundary],
        sourceLength: Int
    ) -> MonaLineLayoutRecord {
        let totalWidth = boundaries.isEmpty ? CGFloat(0) : boundaries.last!.endX
        let run = MonaGlyphRun(
            glyphs: [],
            positions: [],
            advances: [],
            stringIndices: [],
            sourceRange: 0..<sourceLength,
            fontDescriptor: menlo,
            ascent: 9,
            descent: 3,
            leading: 0
        )
        let stamp = MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        return MonaLineLayoutRecord(
            glyphRuns: [run],
            advances: [totalWidth],
            baseline: 9,
            baselines: [9],
            ascent: 9,
            descent: 3,
            leading: 0,
            rawUnitBoundaries: boundaries,
            bidiLevels: [0],
            injectedTextSpans: [],
            decorations: [],
            paintInputs: .plain,
            dependencyStamp: stamp,
            sourceLength: sourceLength
        )
    }

    /// A 3-line snapshot (model lines 1, 2, 3), lineHeight 20, no scroll.
    /// Line 1: 3 units x 10px (sourceLength 3). Line 2: 2 units x 10px (len 2).
    /// Line 3: 5 units x 8px (len 5).
    private func makeThreeLineSnapshot() -> MonaGeometrySnapshot {
        let viewLines = [
            MonaViewLine(modelLineNumber: 1),
            MonaViewLine(modelLineNumber: 2),
            MonaViewLine(modelLineNumber: 3),
        ]
        let projection = MonaViewProjection(generation: 1, viewLines: viewLines)
        let verticalIndex = MonaVerticalIndex(
            viewLines: viewLines, lineHeight: 20, zones: []
        )
        let line1 = makeRecord(
            boundaries: [unit(0, 0, 10), unit(1, 10, 20), unit(2, 20, 30)],
            sourceLength: 3
        )
        let line2 = makeRecord(
            boundaries: [unit(0, 0, 10), unit(1, 10, 20)],
            sourceLength: 2
        )
        let line3 = makeRecord(
            boundaries: [unit(0, 0, 8), unit(1, 8, 16), unit(2, 16, 24), unit(3, 24, 32), unit(4, 32, 40)],
            sourceLength: 5
        )
        return MonaGeometrySnapshot(
            generation: 1,
            projection: projection,
            verticalIndex: verticalIndex,
            records: [1: line1, 2: line2, 3: line3],
            lineHeight: 20,
            scrollOffsetX: 0,
            scrollOffsetY: 0
        )
    }

    /// A wrapped-line snapshot: model line 1 "ABCDEFGHIJ" wrapped at column 5 ->
    /// 2 view lines (startColumn 1 and 6). Each piece: 5 units x 10px.
    private func makeWrappedSnapshot() -> MonaGeometrySnapshot {
        let viewLines = [
            MonaViewLine(modelLineNumber: 1, startColumn: 1),
            MonaViewLine(modelLineNumber: 1, startColumn: 6, isWrapped: true),
        ]
        let projection = MonaViewProjection(generation: 1, viewLines: viewLines)
        let verticalIndex = MonaVerticalIndex(
            viewLines: viewLines, lineHeight: 20, zones: []
        )
        let pieceBoundaries: [MonaRawUnitBoundary] = [
            unit(0, 0, 10), unit(1, 10, 20), unit(2, 20, 30), unit(3, 30, 40), unit(4, 40, 50),
        ]
        let piece1 = makeRecord(boundaries: pieceBoundaries, sourceLength: 5)
        let piece2 = makeRecord(boundaries: pieceBoundaries, sourceLength: 5)
        return MonaGeometrySnapshot(
            generation: 1,
            projection: projection,
            verticalIndex: verticalIndex,
            records: [1: piece1, 2: piece2],
            lineHeight: 20,
            scrollOffsetX: 0,
            scrollOffsetY: 0
        )
    }

    // MARK: - Hit tester: hitTest(point:)

    func testHitTestNoSnapshotReturnsNil() {
        let tester = MonaHitTester(lineHeight: 20)
        XCTAssertNil(tester.hitTest(point: CGPoint(x: 5, y: 10)))
    }

    func testHitTestWithinFirstLineResolvesColumnByNearestEdge() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()

        // Left half of unit 0 (x in [0,5]) -> offset 0 -> column 1.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 5, y: 10)), MonaPosition(line: 1, column: 1))
        // Left half of unit 1 (x in [10,15]) -> offset 1 -> column 2.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 15, y: 10)), MonaPosition(line: 1, column: 2))
        // Left half of unit 2 (x in [20,25]) -> offset 2 -> column 3.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 25, y: 10)), MonaPosition(line: 1, column: 3))
        // Past the last unit -> sourceLength -> column 4 (end of line 1).
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 35, y: 10)), MonaPosition(line: 1, column: 4))
        // Before the first unit -> offset 0 -> column 1.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: -5, y: 10)), MonaPosition(line: 1, column: 1))
    }

    func testHitTestSecondLineUsesThatLineRecord() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()

        // View line 2 occupies y in [20, 40). Its record has 2 units x 10px.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 5, y: 25)), MonaPosition(line: 2, column: 1))
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 15, y: 25)), MonaPosition(line: 2, column: 2))
        // Past the last unit of line 2 -> sourceLength 2 -> column 3.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 25, y: 25)), MonaPosition(line: 2, column: 3))
    }

    func testHitTestThirdLineUsesThatLineRecord() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()

        // View line 3 occupies y in [40, 60). Its record has 5 units x 8px.
        // x=5 is in the right half of unit 0 ([0,8], midpoint 4) -> offset 1 -> col 2.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 5, y: 45)), MonaPosition(line: 3, column: 2))
    }

    func testHitTestAboveAndBelowContentReturnsNil() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()

        // Above content (contentY < 0).
        XCTAssertNil(tester.hitTest(point: CGPoint(x: 5, y: -5)))
        // At/below total height (60) -> out of bounds.
        XCTAssertNil(tester.hitTest(point: CGPoint(x: 5, y: 60)))
        XCTAssertNil(tester.hitTest(point: CGPoint(x: 5, y: 65)))
    }

    func testHitTestRespectsScrollOffset() {
        let snap = makeThreeLineSnapshot()
        // Shift the viewport down by 100: a viewport y of -80 -> contentY 20.
        let scrolled = MonaGeometrySnapshot(
            generation: snap.generation,
            projection: snap.projection,
            verticalIndex: snap.verticalIndex,
            records: snap.records,
            lineHeight: snap.lineHeight,
            scrollOffsetX: 0,
            scrollOffsetY: 100
        )
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = scrolled

        // contentY = -80 + 100 = 20 -> view line 2.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 5, y: -80)), MonaPosition(line: 2, column: 1))

        // Horizontal scroll: contentX = 5 + 50 = 55 -> past line 1's width (30) -> column 4.
        let hScroll = MonaGeometrySnapshot(
            generation: snap.generation,
            projection: snap.projection,
            verticalIndex: snap.verticalIndex,
            records: snap.records,
            lineHeight: snap.lineHeight,
            scrollOffsetX: 50,
            scrollOffsetY: 0
        )
        tester.snapshot = hScroll
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 5, y: 10)), MonaPosition(line: 1, column: 4))
    }

    func testHitTestWrappedLineMapsToCorrectPieceColumn() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeWrappedSnapshot()

        // Piece 1 (y in [0,20), startColumn 1).
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 25, y: 10)), MonaPosition(line: 1, column: 3))
        // Piece 2 (y in [20,40), startColumn 6).
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 5, y: 30)), MonaPosition(line: 1, column: 6))
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 25, y: 30)), MonaPosition(line: 1, column: 8))
        // Past piece 2's last unit -> sourceLength 5 -> column 6 + 5 = 11.
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 55, y: 30)), MonaPosition(line: 1, column: 11))
    }

    func testHitTestLineWithoutRecordReturnsNil() {
        // Records dictionary omits view line 2 -> hit tester returns nil for it.
        let snap = makeThreeLineSnapshot()
        var records = snap.records
        records.removeValue(forKey: 2)
        let partial = MonaGeometrySnapshot(
            generation: snap.generation, projection: snap.projection,
            verticalIndex: snap.verticalIndex, records: records,
            lineHeight: snap.lineHeight, scrollOffsetX: 0, scrollOffsetY: 0
        )
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = partial

        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 5, y: 10)), MonaPosition(line: 1, column: 1))
        XCTAssertNil(tester.hitTest(point: CGPoint(x: 5, y: 25)))
    }

    // MARK: - Hit tester: getCaretRect(position:)

    func testGetCaretRectAtLineStartMiddleEnd() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()

        // Column 1 (offset 0) -> x = first boundary startX (0), y = line top (0).
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 1, column: 1)), CGRect(x: 0, y: 0, width: 1, height: 20))
        // Column 2 (offset 1) -> x = boundary 1 startX (10).
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 1, column: 2)), CGRect(x: 10, y: 0, width: 1, height: 20))
        // Column 4 (offset 3 == sourceLength) -> x = last boundary endX (30).
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 1, column: 4)), CGRect(x: 30, y: 0, width: 1, height: 20))
        // Column past the end clamps to the end (offset 3).
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 1, column: 9)), CGRect(x: 30, y: 0, width: 1, height: 20))
        // Line 2 starts at y = 20.
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 2, column: 1)), CGRect(x: 0, y: 20, width: 1, height: 20))
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 2, column: 3)), CGRect(x: 20, y: 20, width: 1, height: 20))
        // Line 3 unit 2 -> x = 16, y = 40.
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 3, column: 3)), CGRect(x: 16, y: 40, width: 1, height: 20))
    }

    func testGetCaretRectNoSnapshotReturnsNil() {
        let tester = MonaHitTester(lineHeight: 20)
        XCTAssertNil(tester.getCaretRect(position: MonaPosition(line: 1, column: 1)))
    }

    func testGetCaretRectForUnknownLineReturnsNil() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()
        XCTAssertNil(tester.getCaretRect(position: MonaPosition(line: 5, column: 1)))
    }

    func testGetCaretRectWrappedLine() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeWrappedSnapshot()

        // Piece 1, column 3 (offset 2) -> x = 20, y = 0.
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 1, column: 3)), CGRect(x: 20, y: 0, width: 1, height: 20))
        // Piece 2, column 8 (offset 2) -> x = 20, y = 20.
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 1, column: 8)), CGRect(x: 20, y: 20, width: 1, height: 20))
        // Piece 2, end (column 11, offset 5 == sourceLength) -> x = 50, y = 20.
        XCTAssertEqual(tester.getCaretRect(position: MonaPosition(line: 1, column: 11)), CGRect(x: 50, y: 20, width: 1, height: 20))
    }

    // MARK: - Hit tester: getRangeRects(range:)

    func testGetRangeRectsSingleLine() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()

        // Full line "abc" (end column 4 == end-of-line position).
        let rects = tester.getRangeRects(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 4))
        XCTAssertEqual(rects, [CGRect(x: 0, y: 0, width: 30, height: 20)])
    }

    func testGetRangeRectsMultiLine() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()

        let rects = tester.getRangeRects(range: MonaRange(startLine: 1, startColumn: 2, endLine: 2, endColumn: 3))
        // Line 1: cols 2..4 -> offset 1..3 -> x 10..30 (width 20).
        // Line 2: cols 1..3 -> offset 0..2 -> x 0..20 (width 20).
        XCTAssertEqual(rects.count, 2)
        XCTAssertEqual(rects[0], CGRect(x: 10, y: 0, width: 20, height: 20))
        XCTAssertEqual(rects[1], CGRect(x: 0, y: 20, width: 20, height: 20))
    }

    func testGetRangeRectsSpansThreeLines() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()

        let rects = tester.getRangeRects(range: MonaRange(startLine: 1, startColumn: 1, endLine: 3, endColumn: 3))
        XCTAssertEqual(rects.count, 3)
        XCTAssertEqual(rects[0], CGRect(x: 0, y: 0, width: 30, height: 20))
        XCTAssertEqual(rects[1], CGRect(x: 0, y: 20, width: 20, height: 20))
        // Line 3 cols 1..3 -> offset 0..2 -> x 0..16 (width 16).
        XCTAssertEqual(rects[2], CGRect(x: 0, y: 40, width: 16, height: 20))
    }

    func testGetRangeRectsWrappedLineProducesOneRectPerPiece() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeWrappedSnapshot()

        let rects = tester.getRangeRects(range: MonaRange(startLine: 1, startColumn: 3, endLine: 1, endColumn: 8))
        // Piece 1 cols 3..6 -> offset 2..5 -> x 20..50 (width 30).
        // Piece 2 cols 6..8 -> offset 0..2 -> x 0..20 (width 20).
        XCTAssertEqual(rects.count, 2)
        XCTAssertEqual(rects[0], CGRect(x: 20, y: 0, width: 30, height: 20))
        XCTAssertEqual(rects[1], CGRect(x: 0, y: 20, width: 20, height: 20))
    }

    func testGetRangeRectsNoSnapshotReturnsEmpty() {
        let tester = MonaHitTester(lineHeight: 20)
        XCTAssertEqual(tester.getRangeRects(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 3)), [])
    }

    func testGetRangeRectsOutsideDocumentReturnsEmpty() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()
        XCTAssertEqual(tester.getRangeRects(range: MonaRange(startLine: 5, startColumn: 1, endLine: 5, endColumn: 3)), [])
    }

    func testGetRangeRectsCollapsedRangeReturnsEmpty() {
        let tester = MonaHitTester(lineHeight: 20)
        tester.snapshot = makeThreeLineSnapshot()
        // start == end -> zero-width -> no rects.
        XCTAssertEqual(tester.getRangeRects(range: MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 2)), [])
    }

    // MARK: - Barrier helpers

    /// Builds a barrier over a real model + view graph + scroll model + builder.
    private func makeBarrier(
        text: String = "abc\ndef",
        lineHeight: Int = 20,
        builder: MonaLineLayoutBuilder? = nil
    ) -> (MonaQueryGeometryBarrier, MonaCodeModel, MonaViewGraph, MonaScrollModel) {
        let model = MonaCodeModel(text: text, uri: MonaURI.parse("monacode:barrier")!)
        let viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)
        // Viewport shorter than the content so vertical scroll is not clamped
        // to zero in the scroll-offset test.
        let scrollModel = MonaScrollModel(
            contentWidth: 400, contentHeight: Double(2 * lineHeight),
            viewportWidth: 400, viewportHeight: Double(lineHeight)
        )
        let b: MonaLineLayoutBuilder
        if let builder = builder {
            b = builder
        } else {
            let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
            let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
            b = MonaLineLayoutBuilder(shaper: shaper)
        }
        let provider: (Int) -> [UInt16] = { lineNum in
            Array(model.getLineContent(lineNum).utf16)
        }
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: b,
            lineHeight: lineHeight,
            codeUnitsForModelLine: provider
        )
        return (barrier, model, viewGraph, scrollModel)
    }

    // MARK: - Barrier: no complete generation

    func testHitTestBeforePublishReturnsNoCompleteGeneration() {
        let (barrier, _, _, _) = makeBarrier()
        XCTAssertEqual(barrier.hitTest(point: CGPoint(x: 5, y: 10)), .unavailable(.noCompleteGeneration))
        XCTAssertNil(barrier.currentGeneration)
    }

    func testCaretRectBeforePublishReturnsNoCompleteGeneration() {
        let (barrier, _, _, _) = makeBarrier()
        XCTAssertEqual(
            barrier.caretRect(for: MonaPosition(line: 1, column: 1)),
            .unavailable(.noCompleteGeneration)
        )
    }

    func testRangeRectsBeforePublishReturnsNoCompleteGeneration() {
        let (barrier, _, _, _) = makeBarrier()
        XCTAssertEqual(
            barrier.rangeRects(for: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 3)),
            .unavailable(.noCompleteGeneration)
        )
    }

    // MARK: - Barrier: published generation — hit testing

    func testPublishGenerationAdvancesGenerationId() {
        let (barrier, _, _, _) = makeBarrier()
        let gen = barrier.publishGeneration(visibleViewLines: 1...2)
        XCTAssertNotNil(gen)
        XCTAssertEqual(barrier.currentGeneration, gen)
    }

    func testHitTestAfterPublishResolvesPosition() {
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        // x = 0 -> offset 0 -> column 1 of line 1.
        XCTAssertEqual(barrier.hitTest(point: CGPoint(x: 0, y: 10)), .available(MonaPosition(line: 1, column: 1)))
        // Very large x -> past the line width -> end of line 1 ("abc" len 3 -> column 4).
        XCTAssertEqual(barrier.hitTest(point: CGPoint(x: 10_000, y: 10)), .available(MonaPosition(line: 1, column: 4)))
        // Negative x -> clamp to column 1.
        XCTAssertEqual(barrier.hitTest(point: CGPoint(x: -100, y: 10)), .available(MonaPosition(line: 1, column: 1)))
        // View line 2 occupies y in [20, 40) -> line 2, column 1.
        XCTAssertEqual(barrier.hitTest(point: CGPoint(x: 0, y: 30)), .available(MonaPosition(line: 2, column: 1)))
    }

    func testHitTestAboveContentClampsToFirstPosition() {
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        // contentY < 0 -> clamp to the start of the first view line.
        XCTAssertEqual(barrier.hitTest(point: CGPoint(x: 5, y: -10)), .available(MonaPosition(line: 1, column: 1)))
    }

    func testHitTestBelowContentClampsToEndOfLastLine() {
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        // contentY far beyond total height -> clamp to end of last line ("def" len 3 -> column 4).
        XCTAssertEqual(barrier.hitTest(point: CGPoint(x: 0, y: 10_000)), .available(MonaPosition(line: 2, column: 4)))
    }

    func testHitTestUsesPublishedScrollOffset() {
        let (barrier, _, _, scroll) = makeBarrier()
        // Scroll down by one line (20px). converge so `published` reflects it.
        scroll.requestScroll(x: 0, y: 20)
        _ = scroll.converge()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        // Viewport y = 10 -> contentY = 10 + 20 = 30 -> view line 2, column 1.
        XCTAssertEqual(barrier.hitTest(point: CGPoint(x: 0, y: 10)), .available(MonaPosition(line: 2, column: 1)))
    }

    // MARK: - Barrier: caret + range geometry

    func testCaretRectAfterPublishAtLineStart() {
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        let result = barrier.caretRect(for: MonaPosition(line: 1, column: 1))
        guard case .available(let rect) = result else {
            XCTFail("expected available caret rect, got \(result)")
            return
        }
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 1, height: 20))
    }

    func testCaretRectAtEndOfLineUsesShapedWidth() {
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        let result = barrier.caretRect(for: MonaPosition(line: 1, column: 4))
        guard case .available(let rect) = result else {
            XCTFail("expected available caret rect, got \(result)")
            return
        }
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 1)
        XCTAssertEqual(rect.height, 20)
        // End of "abc" -> positive shaped width.
        XCTAssertGreaterThan(rect.origin.x, 0)
    }

    func testCaretRectForUnknownLineIsOutOfBounds() {
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        XCTAssertEqual(
            barrier.caretRect(for: MonaPosition(line: 5, column: 1)),
            .unavailable(.outOfBounds)
        )
    }

    func testRangeRectsAfterPublishProducesOneRectPerLine() {
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        let result = barrier.rangeRects(for: MonaRange(startLine: 1, startColumn: 1, endLine: 2, endColumn: 4))
        guard case .available(let rects) = result else {
            XCTFail("expected available range rects, got \(result)")
            return
        }
        XCTAssertEqual(rects.count, 2)
        XCTAssertEqual(rects[0].origin.y, 0)
        XCTAssertEqual(rects[1].origin.y, 20)
        XCTAssertEqual(rects[0].height, 20)
        XCTAssertEqual(rects[1].height, 20)
    }

    func testRangeRectsForOutsideDocumentIsOutOfBounds() {
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        XCTAssertEqual(
            barrier.rangeRects(for: MonaRange(startLine: 9, startColumn: 1, endLine: 9, endColumn: 3)),
            .unavailable(.outOfBounds)
        )
    }

    // MARK: - Barrier: bounded visible-line completion

    func testBoundedCompletionBuildsMissingLineOnDemand() {
        let (barrier, _, _, _) = makeBarrier()
        // Publish only view line 1 pre-built; line 2 is built on demand.
        _ = barrier.publishGeneration(visibleViewLines: 1...1)

        // Querying line 2 triggers synchronous bounded completion -> available.
        let result = barrier.hitTest(point: CGPoint(x: 0, y: 30))
        guard case .available(let pos) = result else {
            XCTFail("expected available after bounded completion, got \(result)")
            return
        }
        XCTAssertEqual(pos.line, 2)
        XCTAssertEqual(pos.column, 1)
    }

    func testBoundedCompletionFailureReturnsTypedUnavailable() {
        // A builder whose shaper has an invalid (empty) font family throws on
        // `build` -> every record build fails -> bounded completion fails.
        let invalidFont = MonaFontDescriptor(familyName: "", size: 12)
        let resolver = MonaFontFallbackResolver(primary: invalidFont, fallback: [])
        let shaper = MonaTextShaper(primaryFont: invalidFont, fallback: resolver, direction: .ltr, scale: 1)
        let failingBuilder = MonaLineLayoutBuilder(shaper: shaper)

        let (barrier, _, _, _) = makeBarrier(builder: failingBuilder)
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        // Hit testing line 1 -> bounded completion fails -> typed unavailable.
        let result = barrier.hitTest(point: CGPoint(x: 0, y: 10))
        guard case .unavailable(let reason) = result else {
            XCTFail("expected unavailable, got \(result)")
            return
        }
        if case .boundedCompletionFailed(let line) = reason {
            XCTAssertEqual(line, 1)
        } else {
            XCTFail("expected boundedCompletionFailed, got \(reason)")
        }
    }
}
