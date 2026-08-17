// MonaColorizeModelLine.swift
//
// P05-T011 — Implement editor.colorizeModelLine from immutable layout geometry.
//
// `MonaColorizeModelLine` is the native layout-geometry colorizer for a single
// model line. Monaco's original `editor.colorizeModelLine` emits an HTML string
// of `<span>` runs with inline CSS classes resolved against a theme. MonaCode is
// a native macOS/AppKit port: the colorize output is purely native — attributed
// runs (CTRun-style) plus `CGRect` geometry — no HTML serialization, no DOM, no
// CSS renderer.
//
// The three load-bearing behaviors (matching the spec's implementation ops):
//
//   1. Project tokens, injected text, bidi segments, and theme styling from one
//      immutable line-layout record. `colorize(model:lineNumber:layoutRecord:
//      layoutGeneration:)` takes a model line and its immutable
//      `MonaLineLayoutRecord` (P03-T003). From the layout record it projects:
//        - tokens — via the attached `MonaColorizeSource`'s tokenization
//          (P05-T009), scoped to the line's raw UTF-16 units;
//        - theme styling — token scope → theme foreground color
//          (P05-T006 `MonaThemeRegistry`), resolved through the colorize source;
//        - injected text — the `injectedTextSpans` recorded on the line, each
//          projected to a geometry rect;
//        - bidi segments — the per-run bidi embedding levels
//          (`layoutRecord.bidiLevels`), carried on each native run.
//      The geometry (run rects, injected-text rects, total width, line height)
//      is read directly from the frozen layout record — no reshaping.
//
//   2. Return native runs and geometry without HTML string construction. The
//      output is a `MonaColorizeLineResult` of native `MonaColorizeLineRun`
//      values (one `NSAttributedString` + `CGRect` per glyph run) plus a
//      `MonaColorizeLineGeometry` — never an HTML string, never a DOM/CSS
//      artifact.
//
//   3. Reject mixed model and layout generations. The model's current versionId
//      (`MonaCodeModel.getVersionId()`) and the layout generation (the geometry
//      barrier generation from P03-T007 that produced the layout) must MATCH.
//      If they differ — the model changed after the layout was computed, so the
//      layout is stale — colorize throws `MonaColorizeModelError.staleLayout`
//      and produces NO geometry. This is the same generation-truth invariant as
//      the dependency stamps (P03-T004) and the geometry barrier (P03-T007).
//
// Raw UTF-16 invariant (consistent with `MonaColorizeSource` / `MonaAXTextArea`):
// token boundaries and glyph-run source ranges are raw UTF-16 offsets into the
// line. The line's raw units are obtained from the model and projected through
// the layout record without surrogate repair.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, `import MonaCode`.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaColorizeLineRun

/// One native colorized run projected from an immutable line-layout record.
///
/// Carries the run's attributed text (native, never HTML), its UTF-16 source
/// range within the line, its line-relative geometry rect, and its bidi
/// embedding level (even = LTR, odd = RTL).
public struct MonaColorizeLineRun: Equatable {

    /// The native attributed text of this run, carrying resolved per-token
    /// foreground colors. Never an HTML string.
    public let attributedText: NSAttributedString

    /// The UTF-16 offset range this run covers in the source line.
    public let utf16Range: Range<Int>

    /// The run's geometry rect, relative to the line origin (device-space
    /// pixels). Derived from the frozen layout record's glyph positions, per-run
    /// advance, and baseline metrics.
    public let rect: CGRect

    /// The per-run bidi embedding level from `layoutRecord.bidiLevels`. Even
    /// levels are LTR; odd levels are RTL.
    public let bidiLevel: UInt8

    /// Creates a native colorized run.
    public init(
        attributedText: NSAttributedString,
        utf16Range: Range<Int>,
        rect: CGRect,
        bidiLevel: UInt8
    ) {
        self.attributedText = attributedText
        self.utf16Range = utf16Range
        self.rect = rect
        self.bidiLevel = bidiLevel
    }
}

// MARK: - MonaColorizeLineGeometry

/// The geometry projected from an immutable line-layout record: one rect per
/// injected-text span (line-relative), the total line pixel width, and the line
/// pixel height.
public struct MonaColorizeLineGeometry: Equatable {

    /// One line-relative rect per `MonaInjectedTextSpan` recorded on the line,
    /// in the order they appear on the record.
    public let injectedTextRects: [CGRect]

    /// The total pixel width of the line (sum of per-run advances from the
    /// layout record).
    public let totalWidth: CGFloat

    /// The pixel height of the line (ascent + descent + leading from the
    /// layout record).
    public let lineHeight: CGFloat

    /// Creates the geometry projection.
    public init(
        injectedTextRects: [CGRect],
        totalWidth: CGFloat,
        lineHeight: CGFloat
    ) {
        self.injectedTextRects = injectedTextRects
        self.totalWidth = totalWidth
        self.lineHeight = lineHeight
    }
}

// MARK: - MonaColorizeLineResult

/// The native result of colorizing one model line from its immutable layout
/// record: native runs (attributed text + geometry per glyph run) plus the
/// line geometry. Never an HTML string.
public struct MonaColorizeLineResult: Equatable {

    /// One native run per glyph run in the layout record, in visual order.
    public let runs: [MonaColorizeLineRun]

    /// The line geometry projected from the layout record.
    public let geometry: MonaColorizeLineGeometry

    /// Creates the colorize result.
    public init(runs: [MonaColorizeLineRun], geometry: MonaColorizeLineGeometry) {
        self.runs = runs
        self.geometry = geometry
    }
}

// MARK: - MonaColorizeModelError

/// A typed reason `MonaColorizeModelLine.colorize` refuses to produce geometry.
public enum MonaColorizeModelError: Error, Equatable {

    /// The model's current versionId does not match the layout generation. The
    /// model changed after the layout was computed, so the layout is stale; no
    /// geometry is produced from a stale layout.
    ///
    /// - Parameters:
    ///   - modelVersionId: The model's current versionId at the time of the
    ///     check.
    ///   - layoutGeneration: The generation the caller asserted produced the
    ///     layout record (the geometry barrier generation from P03-T007).
    case staleLayout(modelVersionId: Int, layoutGeneration: Int)
}

// MARK: - MonaColorizeModelLine

/// Colorizes a single model line from its immutable line-layout record.
///
/// Construct with `init(colorizeSource:)` (defaults to a fresh
/// `MonaColorizeSource`, P05-T009). Call `colorize(model:lineNumber:
/// layoutRecord:layoutGeneration:)` to project the line's tokens, injected text,
/// bidi segments, and theme styling from the frozen layout record into native
/// runs + geometry. A mixed-generation check rejects a stale layout before any
/// geometry is produced.
///
/// The output is always native (attributed runs + `CGRect` geometry) — never
/// HTML, never a DOM/CSS renderer artifact.
public final class MonaColorizeModelLine {

    /// The colorize source supplying tokenization + theme color resolution
    /// (P05-T009). The source's `directTokenProvider` (when attached) supplies
    /// the line's tokens; the source's `themeRegistry` (P05-T006) resolves token
    /// foreground colors.
    public let colorizeSource: MonaColorizeSource

    /// Creates a colorize-model-line projector.
    ///
    /// - Parameter colorizeSource: The colorize source (P05-T009) supplying
    ///   tokenization and theme colors. Defaults to a fresh source with the
    ///   active theme set to Monaco's standalone default (`vs-dark`).
    public init(colorizeSource: MonaColorizeSource = MonaColorizeSource()) {
        self.colorizeSource = colorizeSource
    }

    // MARK: - colorize

    /// Colorizes one model line from its immutable line-layout record.
    ///
    /// The model's current versionId must match `layoutGeneration` (the geometry
    /// barrier generation from P03-T007 that produced the layout). If they
    /// differ, the layout is stale and `.staleLayout` is thrown — no geometry is
    /// produced from a stale layout.
    ///
    /// From the layout record, this projects:
    ///   - tokens (via the colorize source's tokenization, scoped to the line);
    ///   - theme styling (token scope → theme foreground color, P05-T006);
    ///   - injected text (each `injectedTextSpan` → a geometry rect);
    ///   - bidi segments (per-run `bidiLevels`, carried on each native run).
    ///
    /// The result is native — one `MonaColorizeLineRun` per glyph run
    /// (attributed text + `CGRect`) plus line geometry — never an HTML string.
    ///
    /// - Parameters:
    ///   - model: The model owning the line.
    ///   - lineNumber: The 1-based model line number.
    ///   - layoutRecord: The line's immutable layout record (P03-T003).
    ///   - layoutGeneration: The generation that produced `layoutRecord` (the
    ///     model versionId captured at layout-build time / the geometry barrier
    ///     generation from P03-T007). Must equal `model.getVersionId()`.
    /// - Returns: The native runs + geometry projected from the layout record.
    /// - Throws: `MonaColorizeModelError.staleLayout` when the model's current
    ///   versionId does not match `layoutGeneration`.
    public func colorize(
        model: MonaCodeModel,
        lineNumber: Int,
        layoutRecord: MonaLineLayoutRecord,
        layoutGeneration: Int
    ) throws -> MonaColorizeLineResult {

        // Op 3 — Reject mixed model and layout generations. The model's current
        // versionId and the layout generation must match. If the model changed
        // after the layout was computed (versionId bumped), the layout is stale
        // and no geometry is produced. This is the same generation-truth
        // invariant as the dependency stamps (P03-T004) and the geometry barrier
        // (P03-T007).
        let modelVersion = model.getVersionId()
        guard modelVersion == layoutGeneration else {
            throw MonaColorizeModelError.staleLayout(
                modelVersionId: modelVersion,
                layoutGeneration: layoutGeneration
            )
        }

        // Fetch the line's raw UTF-16 units. The model stores raw units; the
        // public accessor returns a String, whose `.utf16` view recovers the
        // raw units (NSString preserves lone surrogates, so no repair occurs).
        let lineUnits = Array(model.getLineContent(lineNumber).utf16)

        // Op 1 — Project tokens + theme styling from the layout record. Build
        // the full-line attributed string via the colorize source (P05-T009):
        // it tokenizes the line's raw units and applies each token's resolved
        // theme foreground color to its raw UTF-16 range. Each glyph run below
        // slices this attributed string at its source range, so per-run
        // attributed text carries exactly the theme colors projected from the
        // layout record's geometry.
        let fullAttributed = colorizeSource.colorize(source: lineUnits)

        // Op 1 + Op 2 — Project native runs + geometry from the layout record's
        // glyph runs. One native run per glyph run; the rect is read from the
        // frozen record (positions + per-run advance + baseline metrics) — no
        // reshaping.
        var runs: [MonaColorizeLineRun] = []
        runs.reserveCapacity(layoutRecord.glyphRuns.count)
        for (index, glyphRun) in layoutRecord.glyphRuns.enumerated() {
            let runRange = glyphRun.sourceRange

            // Slice the full-line attributed string at the run's UTF-16 range,
            // clamped to the available attributed length so a piece-record
            // shorter than the line does not over-read.
            let clampedStart = max(0, min(runRange.lowerBound, fullAttributed.length))
            let clampedEnd = max(clampedStart, min(runRange.upperBound, fullAttributed.length))
            let sliceRange = NSRange(location: clampedStart,
                                     length: clampedEnd - clampedStart)
            let runAttributed = fullAttributed.attributedSubstring(from: sliceRange)

            // Geometry: x from the run's first glyph position; width from the
            // per-run total advance recorded on the layout record; y from the
            // run's baseline minus its ascent; height from the run's ascent +
            // descent.
            let runAdvance: CGFloat = index < layoutRecord.advances.count
                ? layoutRecord.advances[index]
                : 0
            let startX: CGFloat = glyphRun.positions.first?.x ?? 0
            let baseline: CGFloat = index < layoutRecord.baselines.count
                ? layoutRecord.baselines[index]
                : layoutRecord.baseline
            let rect = CGRect(
                x: startX,
                y: baseline - glyphRun.ascent,
                width: runAdvance,
                height: glyphRun.ascent + glyphRun.descent
            )

            // Bidi level from the layout record (even = LTR, odd = RTL).
            let bidiLevel: UInt8 = index < layoutRecord.bidiLevels.count
                ? layoutRecord.bidiLevels[index]
                : 0

            runs.append(MonaColorizeLineRun(
                attributedText: runAttributed,
                utf16Range: clampedStart..<clampedEnd,
                rect: rect,
                bidiLevel: bidiLevel
            ))
        }

        // Op 1 — Project injected text from the layout record. Each span becomes
        // a line-relative rect: x from the rawUnitBoundary at the span's UTF-16
        // start (the frozen geometry), width from the span's recorded pixel
        // width, height from the layout record's line height.
        let lineHeight = layoutRecord.lineHeight
        var injectedRects: [CGRect] = []
        injectedRects.reserveCapacity(layoutRecord.injectedTextSpans.count)
        for span in layoutRecord.injectedTextSpans {
            let startX = self.startX(
                forUTF16Offset: span.utf16Range.lowerBound,
                in: layoutRecord
            )
            injectedRects.append(CGRect(
                x: startX,
                y: 0,
                width: span.width,
                height: lineHeight
            ))
        }

        let geometry = MonaColorizeLineGeometry(
            injectedTextRects: injectedRects,
            totalWidth: layoutRecord.totalWidth,
            lineHeight: lineHeight
        )

        return MonaColorizeLineResult(runs: runs, geometry: geometry)
    }

    // MARK: - Private: raw-unit boundary lookup

    /// Returns the device-space x position (relative to the line origin) where
    /// the UTF-16 unit at `offset` begins, read from the frozen
    /// `rawUnitBoundaries`. Returns 0 when no boundary covers `offset`.
    ///
    /// This is a pure lookup on the frozen record — no reshaping.
    private func startX(
        forUTF16Offset offset: Int,
        in record: MonaLineLayoutRecord
    ) -> CGFloat {
        for boundary in record.rawUnitBoundaries {
            if boundary.utf16Range.contains(offset) {
                return boundary.startX
            }
        }
        return 0
    }
}
