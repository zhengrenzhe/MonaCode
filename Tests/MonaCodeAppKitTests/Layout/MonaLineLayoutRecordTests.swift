// MonaLineLayoutRecordTests.swift
//
// P03-T003 — Freeze shared immutable LineLayoutRecord geometry.
//
// Verifies the immutable line-layout record that freezes the geometry of one
// shaped line:
//   - MonaLineLayoutRecord stores glyph runs, advances, baselines, raw-unit
//     boundaries (UTF-16 offsets), bidi levels, injected-text spans,
//     decorations, and paint inputs in one immutable value.
//   - MonaLineLayoutBuilder builds records from MonaTextShaper output
//     (MonaShapingResult), assembling glyph runs + advances + baselines +
//     boundaries + bidi + decorations into the immutable record.
//   - hitTest(offset:) maps an x position to a UTF-16 offset WITHOUT reshaping
//     (pure lookup on the frozen record).
//   - Records are keyed by a dependency stamp (font + scale + direction +
//     wrapping state — NOT viewport position alone).
//
// One contract case: immutable record geometry + builder + hit testing +
// dependency-stamp keying.

import XCTest
import CoreText
import CoreGraphics
@testable import MonaCodeAppKit

final class MonaLineLayoutRecordTests: XCTestCase {

    // MARK: - Helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    private func utf16(_ string: String) -> [UInt16] {
        return Array(string.utf16)
    }

    private func makeShaper(scale: CGFloat = 1, direction: MonaTextDirection = .ltr) -> MonaTextShaper {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        return MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: direction, scale: scale)
    }

    private func makeBuilder(scale: CGFloat = 1, direction: MonaTextDirection = .ltr) -> MonaLineLayoutBuilder {
        return MonaLineLayoutBuilder(shaper: makeShaper(scale: scale, direction: direction))
    }

    // MARK: - MonaLineLayoutRecord: immutability + value semantics

    func testRecordIsImmutableWithValueSemantics() {
        let run = MonaGlyphRun(
            glyphs: [1, 2],
            positions: [CGPoint(x: 0, y: 0), CGPoint(x: 7, y: 0)],
            advances: [CGSize(width: 7, height: 0), CGSize(width: 7, height: 0)],
            stringIndices: [0, 1],
            sourceRange: 0..<2,
            fontDescriptor: menlo,
            ascent: 9,
            descent: 3,
            leading: 0
        )
        let stamp = MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        let boundary = MonaRawUnitBoundary(utf16Range: 0..<1, startX: 0, endX: 7)
        let injection = MonaInjectedTextSpan(id: "inj1", utf16Range: 1..<2, width: 5)
        let decoration = MonaLineDecoration(id: "dec1", utf16Range: 0..<2, className: "highlight")
        let paint = MonaPaintInputs(
            foreground: MonaPaintInputs.Color(red: 0, green: 0, blue: 0),
            background: MonaPaintInputs.Color(red: 1, green: 1, blue: 1),
            selectionRanges: [0..<1]
        )

        let recordA = MonaLineLayoutRecord(
            glyphRuns: [run],
            advances: [14],
            baseline: 9,
            baselines: [9],
            ascent: 9,
            descent: 3,
            leading: 0,
            rawUnitBoundaries: [boundary],
            bidiLevels: [0],
            injectedTextSpans: [injection],
            decorations: [decoration],
            paintInputs: paint,
            dependencyStamp: stamp,
            sourceLength: 2
        )
        let recordB = MonaLineLayoutRecord(
            glyphRuns: [run],
            advances: [14],
            baseline: 9,
            baselines: [9],
            ascent: 9,
            descent: 3,
            leading: 0,
            rawUnitBoundaries: [boundary],
            bidiLevels: [0],
            injectedTextSpans: [injection],
            decorations: [decoration],
            paintInputs: paint,
            dependencyStamp: stamp,
            sourceLength: 2
        )

        // Value semantics: two records with equal fields are equal regardless
        // of construction path.
        XCTAssertEqual(recordA, recordB)
        // Every field is accessible and carries the supplied value.
        XCTAssertEqual(recordA.glyphRuns.count, 1)
        XCTAssertEqual(recordA.advances, [14])
        XCTAssertEqual(recordA.baseline, 9)
        XCTAssertEqual(recordA.baselines, [9])
        XCTAssertEqual(recordA.ascent, 9)
        XCTAssertEqual(recordA.descent, 3)
        XCTAssertEqual(recordA.leading, 0)
        XCTAssertEqual(recordA.rawUnitBoundaries, [boundary])
        XCTAssertEqual(recordA.bidiLevels, [0])
        XCTAssertEqual(recordA.injectedTextSpans, [injection])
        XCTAssertEqual(recordA.decorations, [decoration])
        XCTAssertEqual(recordA.paintInputs, paint)
        XCTAssertEqual(recordA.dependencyStamp, stamp)
        XCTAssertEqual(recordA.sourceLength, 2)
    }

    // MARK: - MonaLineLayoutBuilder: builds records from shaped text

    func testBuilderBuildsRecordFromShapedAscii() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(
            codeUnits: utf16("Hello"),
            dependencyStamp: stamp
        )

        // The record carries the shaped glyph runs.
        XCTAssertGreaterThanOrEqual(record.glyphRuns.count, 1)
        let totalGlyphs = record.glyphRuns.reduce(0) { $0 + $1.glyphs.count }
        XCTAssertEqual(totalGlyphs, 5, "'Hello' should produce 5 glyphs")

        // Advances: one per run, each = sum of glyph advances in that run.
        XCTAssertEqual(record.advances.count, record.glyphRuns.count)
        for (i, run) in record.glyphRuns.enumerated() {
            let runAdvance = run.advances.reduce(0) { $0 + $1.width }
            XCTAssertEqual(record.advances[i], runAdvance, accuracy: 0.001,
                           "advances[\(i)] must equal the run's total advance")
        }

        // Baseline + metrics: Menlo produces real metrics.
        XCTAssertGreaterThan(record.ascent, 0)
        XCTAssertGreaterThanOrEqual(record.descent, 0)
        XCTAssertEqual(record.baseline, record.ascent)
        // Per-run baselines: one per run, all equal to the line baseline.
        XCTAssertEqual(record.baselines.count, record.glyphRuns.count)
        for b in record.baselines {
            XCTAssertEqual(b, record.baseline)
        }

        // Bidi levels: all 0 for LTR ASCII.
        XCTAssertEqual(record.bidiLevels.count, record.glyphRuns.count)
        for level in record.bidiLevels {
            XCTAssertEqual(level, 0)
        }

        // Source length matches input.
        XCTAssertEqual(record.sourceLength, 5)
    }

    func testBuilderEmptyInputProducesEmptyRecord() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(codeUnits: [], dependencyStamp: stamp)

        XCTAssertEqual(record.glyphRuns.count, 0)
        XCTAssertEqual(record.advances, [])
        XCTAssertEqual(record.rawUnitBoundaries, [])
        XCTAssertEqual(record.bidiLevels, [])
        XCTAssertEqual(record.sourceLength, 0)
        XCTAssertEqual(record.ascent, 0)
        XCTAssertEqual(record.descent, 0)
    }

    // MARK: - Raw-unit boundaries

    func testRawUnitBoundariesCoverEveryShapedUnit() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(
            codeUnits: utf16("ABCDE"),
            dependencyStamp: stamp
        )

        // Every UTF-16 unit [0, 5) should have a boundary.
        let coveredOffsets = Set(record.rawUnitBoundaries.map { $0.utf16Range.lowerBound })
        XCTAssertEqual(coveredOffsets, Set(0..<5))

        // Boundaries are sorted by x position (ascending startX).
        for i in 1..<record.rawUnitBoundaries.count {
            XCTAssertGreaterThanOrEqual(
                record.rawUnitBoundaries[i].startX,
                record.rawUnitBoundaries[i - 1].startX,
                "boundaries must be x-ascending"
            )
        }

        // Each boundary has non-zero width.
        for b in record.rawUnitBoundaries {
            XCTAssertGreaterThan(b.endX, b.startX, "each unit must have non-zero width")
        }
    }

    // MARK: - Hit testing (no reshaping)

    func testHitTestAtUnitStartsReturnsOffset() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(
            codeUnits: utf16("Hello"),
            dependencyStamp: stamp
        )

        // Hit test at each boundary's startX -> returns that unit's offset.
        for b in record.rawUnitBoundaries {
            let result = record.hitTest(offset: b.startX)
            XCTAssertEqual(result, b.utf16Range.lowerBound,
                           "hitTest at startX of unit \(b.utf16Range.lowerBound) should return its offset")
        }
    }

    func testHitTestAtUnitEndsReturnsNextOffset() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(
            codeUnits: utf16("Hello"),
            dependencyStamp: stamp
        )

        // Hit test at each boundary's endX -> returns the next unit's offset
        // (or sourceLength for the last unit).
        for b in record.rawUnitBoundaries {
            let result = record.hitTest(offset: b.endX)
            XCTAssertEqual(result, b.utf16Range.upperBound,
                           "hitTest at endX of unit \(b.utf16Range.lowerBound) should return the next offset")
        }
    }

    func testHitTestAtUnitMidpointsReturnsUnitOffset() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(
            codeUnits: utf16("Hello"),
            dependencyStamp: stamp
        )

        // Hit test at the midpoint of each unit -> returns that unit's offset
        // (left half snaps to the start).
        for b in record.rawUnitBoundaries {
            let mid = (b.startX + b.endX) / 2
            let result = record.hitTest(offset: mid)
            XCTAssertEqual(result, b.utf16Range.lowerBound,
                           "hitTest at midpoint of unit \(b.utf16Range.lowerBound) should return its offset")
        }
    }

    func testHitTestClampsBeforeStart() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(
            codeUnits: utf16("Hello"),
            dependencyStamp: stamp
        )

        // Before the first unit: clamp to 0.
        XCTAssertEqual(record.hitTest(offset: -100), 0)
    }

    func testHitTestClampsAfterEnd() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(
            codeUnits: utf16("Hello"),
            dependencyStamp: stamp
        )

        // After the last unit: clamp to sourceLength.
        XCTAssertEqual(record.hitTest(offset: 100_000), 5)
    }

    func testHitTestEmptyRecordReturnsNil() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(codeUnits: [], dependencyStamp: stamp)

        XCTAssertNil(record.hitTest(offset: 0))
    }

    // MARK: - Hit testing without reshaping

    func testHitTestWorksFromPreShapedResultWithoutShaper() {
        // Build a shaping result manually (no Core Text call), then build a
        // record from it. The record's hit test must work using only the frozen
        // boundaries — no reference to the shaper is needed at query time.
        let run = MonaGlyphRun(
            glyphs: [1, 2, 3],
            positions: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 20, y: 0)],
            advances: [CGSize(width: 10, height: 0), CGSize(width: 10, height: 0), CGSize(width: 10, height: 0)],
            stringIndices: [0, 1, 2],
            sourceRange: 0..<3,
            fontDescriptor: menlo,
            ascent: 9,
            descent: 3,
            leading: 0
        )
        let shapingResult = MonaShapingResult(
            runs: [run],
            isolatedSurrogateOffsets: [],
            unshapedUnitOffsets: []
        )

        // Build the record from the pre-shaped result.
        let builder = MonaLineLayoutBuilder(shaper: makeShaper())
        let stamp = builder.makeDependencyStamp()
        let record = builder.build(
            from: shapingResult,
            sourceLength: 3,
            dependencyStamp: stamp
        )

        // The record is self-contained: hit testing reads only the frozen
        // rawUnitBoundaries, not the shaper.
        XCTAssertEqual(record.hitTest(offset: 0), 0)   // start of unit 0
        XCTAssertEqual(record.hitTest(offset: 5), 0)   // midpoint of unit 0
        XCTAssertEqual(record.hitTest(offset: 10), 1)  // boundary 0|1
        XCTAssertEqual(record.hitTest(offset: 15), 1)  // midpoint of unit 1
        XCTAssertEqual(record.hitTest(offset: 20), 2)  // boundary 1|2
        XCTAssertEqual(record.hitTest(offset: 25), 2)  // midpoint of unit 2
        XCTAssertEqual(record.hitTest(offset: 30), 3)  // end of last unit = sourceLength
    }

    // MARK: - Bidi levels

    func testBidiLevelsDerivedFromRunDirection() {
        let ltrRun = MonaGlyphRun(
            glyphs: [1],
            positions: [CGPoint(x: 0, y: 0)],
            advances: [CGSize(width: 10, height: 0)],
            stringIndices: [0],
            sourceRange: 0..<1,
            fontDescriptor: menlo,
            ascent: 9, descent: 3, leading: 0,
            isRightToLeft: false
        )
        let rtlRun = MonaGlyphRun(
            glyphs: [2],
            positions: [CGPoint(x: 10, y: 0)],
            advances: [CGSize(width: 10, height: 0)],
            stringIndices: [1],
            sourceRange: 1..<2,
            fontDescriptor: menlo,
            ascent: 9, descent: 3, leading: 0,
            isRightToLeft: true
        )
        let shapingResult = MonaShapingResult(
            runs: [ltrRun, rtlRun],
            isolatedSurrogateOffsets: [],
            unshapedUnitOffsets: []
        )

        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = builder.build(
            from: shapingResult,
            sourceLength: 2,
            dependencyStamp: stamp
        )

        // LTR run -> level 0; RTL run -> level 1.
        XCTAssertEqual(record.bidiLevels, [0, 1])
    }

    // MARK: - Dependency stamp

    func testDependencyStampEquality() {
        let stampA = MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        let stampB = MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        XCTAssertEqual(stampA, stampB)

        // Different font -> not equal.
        let otherFont = MonaFontDescriptor(familyName: "Menlo", size: 14)
        XCTAssertNotEqual(stampA, MonaLineLayoutDependencyStamp(
            fontDescriptor: otherFont, scale: 1, direction: .ltr, wrappingColumn: nil))

        // Different scale -> not equal.
        XCTAssertNotEqual(stampA, MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 2, direction: .ltr, wrappingColumn: nil))

        // Different direction -> not equal.
        XCTAssertNotEqual(stampA, MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .rtl, wrappingColumn: nil))

        // Different wrapping -> not equal.
        XCTAssertNotEqual(stampA, MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .ltr, wrappingColumn: 80))
    }

    func testDependencyStampExcludesViewportPosition() {
        // The dependency stamp has NO viewport-position field. Two records with
        // the same font/scale/direction/wrapping share the same stamp regardless
        // of where the viewport is scrolled — records are reusable across
        // viewport positions.
        let stamp = MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        // The stamp's fields are exactly font + scale + direction + wrapping.
        XCTAssertEqual(stamp.fontDescriptor, menlo)
        XCTAssertEqual(stamp.scale, 1)
        XCTAssertEqual(stamp.direction, .ltr)
        XCTAssertNil(stamp.wrappingColumn)
        // Two identically-constructed stamps are equal — "viewport position"
        // is not part of the identity.
        let stamp2 = MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        XCTAssertEqual(stamp, stamp2)
    }

    func testBuilderMakeDependencyStampFromShaper() {
        let builder = MonaLineLayoutBuilder(
            shaper: MonaTextShaper(
                primaryFont: menlo,
                fallback: MonaFontFallbackResolver(primary: menlo, fallback: []),
                direction: .rtl,
                scale: 2
            )
        )
        let stamp = builder.makeDependencyStamp(wrappingColumn: 80)
        XCTAssertEqual(stamp.fontDescriptor, menlo)
        XCTAssertEqual(stamp.scale, 2)
        XCTAssertEqual(stamp.direction, .rtl)
        XCTAssertEqual(stamp.wrappingColumn, 80)
    }

    // MARK: - Decorations, injected spans, paint inputs

    func testBuilderCarriesDecorationsInjectedSpansPaintInputs() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()

        let decoration = MonaLineDecoration(id: "dec1", utf16Range: 0..<3, className: "highlight")
        let injection = MonaInjectedTextSpan(id: "inj1", utf16Range: 3..<4, width: 20)
        let paint = MonaPaintInputs(
            foreground: MonaPaintInputs.Color(red: 0.1, green: 0.2, blue: 0.3),
            background: MonaPaintInputs.Color(red: 0.9, green: 0.8, blue: 0.7),
            selectionRanges: [1..<2]
        )

        let record = try builder.build(
            codeUnits: utf16("Hello"),
            decorations: [decoration],
            injectedTextSpans: [injection],
            paintInputs: paint,
            dependencyStamp: stamp
        )

        XCTAssertEqual(record.decorations, [decoration])
        XCTAssertEqual(record.injectedTextSpans, [injection])
        XCTAssertEqual(record.paintInputs, paint)
    }

    // MARK: - Computed properties

    func testRecordTotalWidthAndLineHeight() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(
            codeUnits: utf16("Hello"),
            dependencyStamp: stamp
        )

        // totalWidth = sum of per-run advances.
        let expectedWidth = record.advances.reduce(0, +)
        XCTAssertEqual(record.totalWidth, expectedWidth, accuracy: 0.001)

        // lineHeight = ascent + descent + leading.
        XCTAssertEqual(record.lineHeight, record.ascent + record.descent + record.leading, accuracy: 0.001)
        XCTAssertGreaterThan(record.totalWidth, 0)
    }

    // MARK: - Dependency stamp on the record

    func testRecordCarriesDependencyStamp() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp(wrappingColumn: 120)
        let record = try builder.build(
            codeUnits: utf16("Hi"),
            dependencyStamp: stamp
        )
        XCTAssertEqual(record.dependencyStamp, stamp)
    }
}
