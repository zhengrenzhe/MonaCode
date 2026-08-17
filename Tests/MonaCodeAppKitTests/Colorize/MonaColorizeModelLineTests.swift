// MonaColorizeModelLineTests.swift
//
// P05-T011 — Implement editor.colorizeModelLine from immutable layout geometry.
//
// Verifies `MonaColorizeModelLine` — colorizes a single model line from its
// immutable `MonaLineLayoutRecord` (P03-T003), projecting tokens, injected text,
// bidi segments, and theme styling into native runs + geometry. The output is
// purely native (attributed runs + `CGRect` geometry) — never HTML, never a
// DOM/CSS renderer artifact. A mixed-generation check rejects a stale layout
// (model changed after the layout was computed) before any geometry is produced.
//
// Test contract (P05-T011):
//   - tokens, injected text, bidi segments, and theme styling are projected
//     FROM the immutable line-layout record (P03-T003).
//   - the output is native runs + geometry (an `NSAttributedString` per run plus
//     `CGRect` rects) — never an HTML string.
//   - mixed model and layout generations are rejected: when the model's current
//     versionId differs from the layout generation, colorize throws
//     `.staleLayout` and produces NO geometry.

import XCTest
import AppKit
import Foundation
import CoreGraphics
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaColorizeModelLineTests: XCTestCase {

    // MARK: - Helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// A minimal in-process direct token provider for tests: produces tokens at
    /// caller-supplied raw UTF-16 offsets, each tagged with a scope id.
    private final class StubTokenProvider: MonaDirectTokenProvider {
        var tokens: [MonaColorToken]
        init(tokens: [MonaColorToken]) { self.tokens = tokens }
        func tokens(for source: [UInt16]) -> [MonaColorToken] { return tokens }
    }

    /// One boundary covering one UTF-16 unit, `[startX, endX)`.
    private func unit(_ index: Int, _ startX: CGFloat, _ endX: CGFloat) -> MonaRawUnitBoundary {
        return MonaRawUnitBoundary(utf16Range: index..<(index + 1), startX: startX, endX: endX)
    }

    /// Builds an immutable layout record for a 3-unit line ("abc") with two
    /// glyph runs (splitting at offset 1 to exercise bidi + per-run geometry),
    /// one injected-text span over unit 2, and a bidi level on the second run.
    private func makeRecord(
        sourceLength: Int,
        bidiLevels: [UInt8] = [0, 1],
        injectedSpans: [MonaInjectedTextSpan] = []
    ) -> MonaLineLayoutRecord {
        // Run 0 covers UTF-16 [0,1); run 1 covers [1,3). Positions in device px.
        let run0 = MonaGlyphRun(
            glyphs: [], positions: [CGPoint(x: 0, y: 9)], advances: [CGSize(width: 10, height: 0)],
            stringIndices: [0], sourceRange: 0..<1, fontDescriptor: menlo,
            ascent: 9, descent: 3, leading: 0, isRightToLeft: false
        )
        let run1 = MonaGlyphRun(
            glyphs: [], positions: [CGPoint(x: 10, y: 9), CGPoint(x: 20, y: 9)],
            advances: [CGSize(width: 10, height: 0), CGSize(width: 10, height: 0)],
            stringIndices: [1, 2], sourceRange: 1..<3, fontDescriptor: menlo,
            ascent: 9, descent: 3, leading: 0, isRightToLeft: true
        )
        let stamp = MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        return MonaLineLayoutRecord(
            glyphRuns: [run0, run1],
            advances: [10, 20],
            baseline: 9,
            baselines: [9, 9],
            ascent: 9,
            descent: 3,
            leading: 0,
            rawUnitBoundaries: [
                unit(0, 0, 10), unit(1, 10, 20), unit(2, 20, 30),
            ],
            bidiLevels: bidiLevels,
            injectedTextSpans: injectedSpans,
            decorations: [],
            paintInputs: .plain,
            dependencyStamp: stamp,
            sourceLength: sourceLength
        )
    }

    /// Builds a model with one line of text "abc" (3 UTF-16 units). The model
    /// boots at versionId 1.
    private func makeModel() -> MonaCodeModel {
        let factory = MonaModelFactory()
        return try! factory.createModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/colorize-model-line")
        )
    }

    /// Returns the lowercase 6-digit hex string for an `NSColor`, mirroring the
    /// theme rule foreground format so colors can be compared in tests.
    private func hexString(from color: NSColor?) -> String? {
        guard let color = color else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    // MARK: - Tokens + theme projected from the layout record

    /// Tokens are projected from the layout record: each run's attributed text
    /// carries the foreground color resolved from the active theme for the token
    /// scope covering that run's UTF-16 range.
    func testTokensAndThemeProjectedFromLayoutRecord() throws {
        let model = makeModel()
        // Three single-unit tokens: keyword (0..<1), string (1..<2), comment (2..<3).
        let tokens = [
            MonaColorToken(startUTF16: 0, endUTF16: 1, scope: "keyword"),
            MonaColorToken(startUTF16: 1, endUTF16: 2, scope: "string"),
            MonaColorToken(startUTF16: 2, endUTF16: 3, scope: "comment"),
        ]
        let provider = StubTokenProvider(tokens: tokens)
        let source = MonaColorizeSource(language: MonaPlainTextLanguage(),
                                        themeRegistry: MonaThemeRegistry())
        source.directTokenProvider = provider

        let layoutGen = model.getVersionId() // 1
        let record = makeRecord(sourceLength: 3)
        let colorizer = MonaColorizeModelLine(colorizeSource: source)

        let result = try colorizer.colorize(
            model: model, lineNumber: 1, layoutRecord: record, layoutGeneration: layoutGen
        )

        // Two glyph runs -> two native runs.
        XCTAssertEqual(result.runs.count, 2, "one native run per glyph run in the layout record")

        // Run 0 covers UTF-16 [0,1) — the "keyword" token.
        let run0 = result.runs[0]
        XCTAssertEqual(run0.utf16Range, 0..<1)
        let color0 = run0.attributedText.attribute(.foregroundColor, at: 0,
                                                    effectiveRange: nil) as? NSColor
        let theme = source.themeRegistry.currentTheme
        let expected0 = theme.rule(for: "keyword")?.foreground?.lowercased()
        XCTAssertEqual(hexString(from: color0), expected0,
                       "run 0 must carry the theme foreground for the keyword scope")

        // Run 1 covers UTF-16 [1,3) — "string" at offset 1, "comment" at offset 2.
        let run1 = result.runs[1]
        XCTAssertEqual(run1.utf16Range, 1..<3)
        let color1 = run1.attributedText.attribute(.foregroundColor, at: 0,
                                                    effectiveRange: nil) as? NSColor
        XCTAssertEqual(hexString(from: color1),
                       theme.rule(for: "string")?.foreground?.lowercased(),
                       "run 1 offset 0 must carry the string scope color")
        // Local offset 1 within run 1's substring is the "comment" token.
        let color1b = run1.attributedText.attribute(.foregroundColor, at: 1,
                                                     effectiveRange: nil) as? NSColor
        XCTAssertEqual(hexString(from: color1b),
                       theme.rule(for: "comment")?.foreground?.lowercased(),
                       "run 1 offset 1 must carry the comment scope color")
    }

    // MARK: - Bidi segments projected from the layout record

    /// Bidi segments are projected: each run carries the bidi embedding level
    /// from `layoutRecord.bidiLevels`.
    func testBidiSegmentsProjectedFromLayoutRecord() throws {
        let model = makeModel()
        let source = MonaColorizeSource(language: MonaPlainTextLanguage())
        let record = makeRecord(sourceLength: 3, bidiLevels: [0, 1])
        let colorizer = MonaColorizeModelLine(colorizeSource: source)

        let result = try colorizer.colorize(
            model: model, lineNumber: 1, layoutRecord: record,
            layoutGeneration: model.getVersionId()
        )

        XCTAssertEqual(result.runs.count, 2)
        XCTAssertEqual(result.runs[0].bidiLevel, 0, "run 0 is LTR (even level)")
        XCTAssertEqual(result.runs[1].bidiLevel, 1, "run 1 is RTL (odd level)")
    }

    // MARK: - Injected text projected from the layout record

    /// Injected-text spans are projected as geometry rects: one rect per span,
    /// positioned by the span's UTF-16 range in the layout record's
    /// `rawUnitBoundaries`, with the span's recorded pixel width.
    func testInjectedTextProjectedFromLayoutRecord() throws {
        let model = makeModel()
        let source = MonaColorizeSource(language: MonaPlainTextLanguage())
        // Injected text over UTF-16 [2,3) (unit 2, which spans x [20,30)).
        let span = MonaInjectedTextSpan(id: "inj-1", utf16Range: 2..<3, width: 30)
        let record = makeRecord(sourceLength: 3, injectedSpans: [span])
        let colorizer = MonaColorizeModelLine(colorizeSource: source)

        let result = try colorizer.colorize(
            model: model, lineNumber: 1, layoutRecord: record,
            layoutGeneration: model.getVersionId()
        )

        XCTAssertEqual(result.geometry.injectedTextRects.count, 1,
                       "one rect per injected-text span")
        let rect = result.geometry.injectedTextRects[0]
        // startX comes from the rawUnitBoundary at UTF-16 offset 2 (x=20).
        XCTAssertEqual(rect.origin.x, 20, accuracy: 0.0001,
                       "injected rect x comes from the layout record's rawUnitBoundaries")
        XCTAssertEqual(rect.width, 30, accuracy: 0.0001,
                       "injected rect width is the span's recorded pixel width")
        // Height is the layout record's line height (ascent + descent + leading = 12).
        XCTAssertEqual(rect.height, 12, accuracy: 0.0001,
                       "injected rect height is the layout record's line height")
    }

    // MARK: - Native runs + geometry (no HTML)

    /// The output is native: each run is an `NSAttributedString` + a `CGRect`.
    /// No run's attributed text contains HTML markup.
    func testOutputIsNativeRunsAndGeometryNoHTML() throws {
        let model = makeModel()
        let source = MonaColorizeSource(language: MonaPlainTextLanguage())
        let record = makeRecord(sourceLength: 3)
        let colorizer = MonaColorizeModelLine(colorizeSource: source)

        let result = try colorizer.colorize(
            model: model, lineNumber: 1, layoutRecord: record,
            layoutGeneration: model.getVersionId()
        )

        XCTAssertFalse(result.runs.isEmpty, "must produce native runs")
        for run in result.runs {
            XCTAssertTrue(run.attributedText is NSAttributedString,
                          "each run is a native NSAttributedString")
            XCTAssertFalse(run.attributedText.string.contains("<span"),
                           "runs must never contain HTML")
            XCTAssertFalse(run.attributedText.string.contains("<div"),
                           "runs must never contain HTML")
        }
        // Per-run geometry rects are non-negative size and finite.
        for run in result.runs {
            XCTAssertGreaterThanOrEqual(run.rect.width, 0)
            XCTAssertGreaterThanOrEqual(run.rect.height, 0)
            XCTAssertTrue(run.rect.origin.x.isFinite && run.rect.origin.y.isFinite
                         && run.rect.width.isFinite && run.rect.height.isFinite,
                         "run rects must be finite")
        }
        // Total geometry matches the layout record.
        XCTAssertEqual(result.geometry.totalWidth, 30, accuracy: 0.0001,
                       "total width is the layout record's total advance")
        XCTAssertEqual(result.geometry.lineHeight, 12, accuracy: 0.0001,
                       "line height is the layout record's line height")
    }

    // MARK: - Mixed-generation rejection (stale layout)

    /// When the model's current versionId does NOT match the layout generation,
    /// colorize rejects the stale layout — throws `.staleLayout` and produces no
    /// geometry.
    func testRejectsMixedModelAndLayoutGenerations() throws {
        let model = makeModel()
        XCTAssertEqual(model.getVersionId(), 1, "model boots at versionId 1")

        let source = MonaColorizeSource(language: MonaPlainTextLanguage())
        let record = makeRecord(sourceLength: 3)
        let colorizer = MonaColorizeModelLine(colorizeSource: source)

        // The layout was built against generation 1, but the caller claims a
        // stale generation 2 that does not match the model's current versionId.
        XCTAssertThrowsError(
            try colorizer.colorize(
                model: model, lineNumber: 1, layoutRecord: record,
                layoutGeneration: 2  // mismatched -> stale
            )
        ) { error in
            guard case MonaColorizeModelError.staleLayout(
                let modelVersion, let layoutGen
            ) = error else {
                XCTFail("expected .staleLayout, got \(error)")
                return
            }
            XCTAssertEqual(modelVersion, 1, "staleLayout carries the model's current versionId")
            XCTAssertEqual(layoutGen, 2, "staleLayout carries the mismatched layout generation")
        }
    }

    /// When the model changed after the layout was computed (versionId
    /// incremented via an edit), a previously-valid generation is now stale and
    /// must be rejected.
    func testRejectsStaleLayoutAfterModelEdit() throws {
        let model = makeModel()
        let layoutGen = model.getVersionId() // 1 — the layout was built here

        let source = MonaColorizeSource(language: MonaPlainTextLanguage())
        let record = makeRecord(sourceLength: 3)
        let colorizer = MonaColorizeModelLine(colorizeSource: source)

        // First call matches -> succeeds.
        _ = try colorizer.colorize(
            model: model, lineNumber: 1, layoutRecord: record, layoutGeneration: layoutGen
        )

        // Mutate the model: applyEdits increments the versionId.
        let edit = MonaModelEditOperation(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 1)
            ),
            text: "x"
        )
        _ = model.applyEdits([edit])
        XCTAssertGreaterThan(model.getVersionId(), layoutGen,
                             "the edit bumped the model versionId")

        // The old generation is now stale -> rejected, no geometry.
        XCTAssertThrowsError(
            try colorizer.colorize(
                model: model, lineNumber: 1, layoutRecord: record,
                layoutGeneration: layoutGen
            )
        ) { error in
            guard case MonaColorizeModelError.staleLayout = error else {
                XCTFail("expected .staleLayout after the model edit, got \(error)")
                return
            }
        }
    }
}
