// MonaLineLayoutBuilder.swift
//
// P03-T003 — Freeze shared immutable LineLayoutRecord geometry.
//
// `MonaLineLayoutBuilder` builds `MonaLineLayoutRecord` values from shaped
// text (the output of `MonaTextShaper` from P03-T002). It is the single
// assembler that takes a `MonaShapingResult` and produces the frozen immutable
// record consumed by every downstream stage (hit tester, selection geometry,
// renderer).
//
// The builder offers two entry points:
//   - `build(codeUnits:...)`  — shapes the raw UTF-16 line via the owned
//                               `MonaTextShaper`, then assembles the record.
//   - `build(from:...)`       — assembles a record from an already-shaped
//                               `MonaShapingResult` (no reshaping). This is
//                               the path that lets hit testing and rendering
//                               consume the record without ever touching Core
//                               Text again.
//
// The builder also offers `makeDependencyStamp(wrappingColumn:)`, which derives
// the cache key from the shaper's configuration (font + scale + direction) plus
// the caller's wrapping column. Viewport position is never part of the stamp.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreText + CoreGraphics + Foundation.

import Foundation
import CoreText
import CoreGraphics

/// Builds immutable `MonaLineLayoutRecord` values from shaped text.
///
/// Create a builder once per shaper configuration and call `build` for each
/// line. The builder assembles glyph runs, advances, baselines, raw-unit
/// boundaries, bidi levels, decorations, injected-text spans, and paint inputs
/// into one frozen record.
public final class MonaLineLayoutBuilder {

    /// The shaper used by `build(codeUnits:...)`. The `build(from:...)` path
    /// does not invoke the shaper — it works purely from a pre-shaped
    /// `MonaShapingResult`.
    public let shaper: MonaTextShaper

    /// Creates a builder that shapes lines with `shaper`.
    public init(shaper: MonaTextShaper) {
        self.shaper = shaper
    }

    // MARK: - Dependency stamp

    /// Derives a dependency stamp from the shaper's configuration (font + scale
    /// + direction) plus the caller's wrapping column.
    ///
    /// The stamp deliberately excludes viewport position: a record is reusable
    /// across viewport positions as long as the shaping inputs are unchanged.
    public func makeDependencyStamp(wrappingColumn: Int? = nil) -> MonaLineLayoutDependencyStamp {
        return MonaLineLayoutDependencyStamp(
            fontDescriptor: shaper.primaryFontDescriptor,
            scale: shaper.scale,
            direction: shaper.direction,
            wrappingColumn: wrappingColumn
        )
    }

    // MARK: - Build (shapes the line, then assembles)

    /// Shapes `codeUnits` via the owned shaper and assembles an immutable
    /// `MonaLineLayoutRecord` from the result.
    ///
    /// - Parameters:
    ///   - codeUnits: The raw UTF-16 code units of the line.
    ///   - decorations: Decorations to freeze onto the record.
    ///   - injectedTextSpans: Injected-text spans to freeze onto the record.
    ///   - paintInputs: Frozen rendering inputs.
    ///   - dependencyStamp: The cache key for this record.
    /// - Returns: The frozen layout record.
    /// - Throws: `MonaTextShaperError` if shaping cannot produce a complete
    ///   result.
    public func build(
        codeUnits: [UInt16],
        decorations: [MonaLineDecoration] = [],
        injectedTextSpans: [MonaInjectedTextSpan] = [],
        paintInputs: MonaPaintInputs = .plain,
        dependencyStamp: MonaLineLayoutDependencyStamp
    ) throws -> MonaLineLayoutRecord {
        let shapingResult = try shaper.shape(codeUnits)
        return build(
            from: shapingResult,
            sourceLength: codeUnits.count,
            decorations: decorations,
            injectedTextSpans: injectedTextSpans,
            paintInputs: paintInputs,
            dependencyStamp: dependencyStamp
        )
    }

    // MARK: - Build (from a pre-shaped result — no reshaping)

    /// Assembles an immutable `MonaLineLayoutRecord` from an already-shaped
    /// `MonaShapingResult`.
    ///
    /// This path does NOT invoke the shaper. It works purely from the frozen
    /// shaping result, so hit testing and rendering can consume the assembled
    /// record without ever touching Core Text again.
    ///
    /// - Parameters:
    ///   - shapingResult: The shaped glyph runs + surrogate/unshaped offsets.
    ///   - sourceLength: The number of UTF-16 units in the source line.
    ///   - decorations: Decorations to freeze onto the record.
    ///   - injectedTextSpans: Injected-text spans to freeze onto the record.
    ///   - paintInputs: Frozen rendering inputs.
    ///   - dependencyStamp: The cache key for this record.
    /// - Returns: The frozen layout record.
    public func build(
        from shapingResult: MonaShapingResult,
        sourceLength: Int,
        decorations: [MonaLineDecoration] = [],
        injectedTextSpans: [MonaInjectedTextSpan] = [],
        paintInputs: MonaPaintInputs = .plain,
        dependencyStamp: MonaLineLayoutDependencyStamp
    ) -> MonaLineLayoutRecord {
        let runs = shapingResult.runs

        // Per-run advances: the total pixel width of each run.
        let advances: [CGFloat] = runs.map { run in
            run.advances.reduce(0) { $0 + $1.width }
        }

        // Line metrics: the maximum ascent / descent / leading across runs.
        let ascent = runs.map(\.ascent).max() ?? 0
        let descent = runs.map(\.descent).max() ?? 0
        let leading = runs.map(\.leading).max() ?? 0
        let baseline = ascent

        // Per-run baselines: all runs share the line baseline.
        let baselines = Array(repeating: baseline, count: runs.count)

        // Bidi levels: 0 for LTR runs, 1 for RTL runs.
        let bidiLevels: [UInt8] = runs.map { $0.isRightToLeft ? 1 : 0 }

        // Raw-unit boundaries: per-UTF-16-unit x-extents, sorted by x.
        let rawUnitBoundaries = buildRawUnitBoundaries(from: runs)

        return MonaLineLayoutRecord(
            glyphRuns: runs,
            advances: advances,
            baseline: baseline,
            baselines: baselines,
            ascent: ascent,
            descent: descent,
            leading: leading,
            rawUnitBoundaries: rawUnitBoundaries,
            bidiLevels: bidiLevels,
            injectedTextSpans: injectedTextSpans,
            decorations: decorations,
            paintInputs: paintInputs,
            dependencyStamp: dependencyStamp,
            sourceLength: sourceLength
        )
    }

    // MARK: - Private: raw-unit boundaries

    /// Builds the raw-unit boundary array from glyph runs.
    ///
    /// For each glyph in each run, the glyph covers a UTF-16 range
    /// `[stringIndex, nextStringIndex)` where `nextStringIndex` is the next
    /// glyph's string index (or the run's `sourceRange.upperBound` for the last
    /// glyph). The glyph's pixel extent `[position.x, position.x + advance.width)`
    /// is split evenly across the UTF-16 units it covers, producing one boundary
    /// per unit. The final array is sorted by ascending `startX` so that
    /// `hitTest(offset:)` can binary-search by x position.
    private func buildRawUnitBoundaries(from runs: [MonaGlyphRun]) -> [MonaRawUnitBoundary] {
        // Accumulate per-unit x-extents. A unit is typically covered by exactly
        // one glyph; if two glyphs somehow touch the same unit (overlapping
        // runs), the first-seen extent wins.
        var unitStartX: [Int: CGFloat] = [:]
        var unitEndX: [Int: CGFloat] = [:]

        for run in runs {
            let count = run.glyphs.count
            guard count > 0 else { continue }

            for i in 0..<count {
                let idx = run.stringIndices[i]
                let posX = run.positions[i].x
                let advWidth = run.advances[i].width

                // The UTF-16 range this glyph covers: [idx, nextIdx).
                let nextIdx: Int
                if i + 1 < count {
                    nextIdx = run.stringIndices[i + 1]
                } else {
                    nextIdx = run.sourceRange.upperBound
                }

                let unitCount = max(nextIdx - idx, 1)
                let perUnit = advWidth / CGFloat(unitCount)

                for u in 0..<unitCount {
                    let unitIdx = idx + u
                    let startX = posX + perUnit * CGFloat(u)
                    let endX = startX + perUnit
                    if unitStartX[unitIdx] == nil {
                        unitStartX[unitIdx] = startX
                        unitEndX[unitIdx] = endX
                    }
                }
            }
        }

        // Assemble and sort by ascending startX (for binary-search hit testing).
        var boundaries: [MonaRawUnitBoundary] = []
        boundaries.reserveCapacity(unitStartX.count)
        for offset in unitStartX.keys {
            guard let startX = unitStartX[offset], let endX = unitEndX[offset] else {
                continue
            }
            boundaries.append(MonaRawUnitBoundary(
                utf16Range: offset..<(offset + 1),
                startX: startX,
                endX: endX
            ))
        }
        boundaries.sort { lhs, rhs in
            if lhs.startX != rhs.startX {
                return lhs.startX < rhs.startX
            }
            return lhs.utf16Range.lowerBound < rhs.utf16Range.lowerBound
        }
        return boundaries
    }
}
