// MonaTextShaper.swift
//
// P03-T002 — Shape mixed-script lines with Core Text and deterministic fallback.
//
// `MonaTextShaper` shapes raw UTF-16 (`[UInt16]`) lines using Core Text
// (`CTLine`, `CTRun`). It is the sole typography authority for MonaCodeAppKit:
// it takes a primary font descriptor, a deterministic fallback resolver, a
// base writing direction (LTR/RTL), a device-space scale, and a set of tab
// stops, and produces a `MonaShapingResult` containing:
//   - `runs`: the shaped `MonaGlyphRun`s (glyph IDs, positions, advances,
//     source UTF-16 ranges, font descriptors, metrics, RTL flag).
//   - `isolatedSurrogateOffsets`: source UTF-16 offsets of isolated surrogates
//     that produced no glyph. These positions are RECORDED even though no glyph
//     is emitted, so downstream code knows an unshaped unit exists there.
//   - `unshapedUnitOffsets`: every source UTF-16 unit that produced no glyph
//     (a superset of `isolatedSurrogateOffsets`).
//
// Font provenance (Q1-R4): every distinct font face used during shaping is
// recorded in `recordedFaces`, and the run count is recorded in
// `recordedRunCount`.
//
// Bounded typed failure: if shaping cannot produce a complete result (e.g. the
// primary font is unavailable or the descriptor is malformed), `shape()`
// throws `MonaTextShaperError` and publishes NO partial runs.
//
// Implementation notes:
//   - Core Text's `CTLineCreateWithAttributedString` is the shaping entry point.
//   - The primary font's cascade list (`kCTFontCascadeListAttribute`) is set to
//     the resolver's fallback descriptors so missing glyphs fall back in the
//     caller-supplied deterministic order. When the explicit cascade is empty,
//     the attribute is left unset so Core Text uses its default cascade (this
//     lets the host cover scripts the caller did not enumerate; the explicit
//     order is still deterministic when supplied).
//   - Base direction is forced by prepending a strong directional mark
//     (U+200E LRM for LTR, U+200F RLM for RTL). The mark is default-ignorable
//     and produces no glyph; all glyph string indices are offset by +1 and
//     mapped back by subtracting 1.
//   - Scale multiplies positions, advances, and metrics (the font itself stays
//     at its nominal point size; the renderer applies the same scale via the
//     graphics context transform).
//   - Tab stops: when supplied, the advance of each tab glyph (U+0009) in an
//     LTR run is replaced with the distance to the next tab stop strictly
//     greater than the glyph's current x position, and subsequent positions
//     are recomputed.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreText + CoreGraphics + Foundation.

import Foundation
import CoreText
import CoreGraphics

/// The bounded typed failure returned by `MonaTextShaper.shape(_:)` when shaping
/// cannot produce a complete result. Partial glyph runs are never published.
public enum MonaTextShaperError: Error, Equatable, Sendable {

    /// The font descriptor is malformed (empty family name or non-positive size).
    case fontDescriptorInvalid(MonaFontDescriptor)

    /// The primary font could not be resolved to the requested family — Core
    /// Text silently substituted a different face. `resolvedFamilyName` is the
    /// family Core Text actually returned (or nil if it could not be read).
    case primaryFontUnavailable(MonaFontDescriptor, resolvedFamilyName: String?)

    /// Core Text failed to shape the line (e.g. `CTLineCreateWithAttributedString`
    /// returned nil). The associated value is a diagnostic string.
    case coreTextShapingFailed(String)
}

/// The result of shaping one UTF-16 line.
public struct MonaShapingResult: Equatable, Sendable {

    /// The shaped glyph runs in visual order.
    public let runs: [MonaGlyphRun]

    /// Source UTF-16 offsets of isolated surrogates (lone high or low
    /// surrogates). These offsets produced no glyph but are RECORDED so
    /// downstream code knows an unshaped unit exists at each position.
    public let isolatedSurrogateOffsets: [Int]

    /// Every source UTF-16 offset that produced no glyph (a superset of
    /// `isolatedSurrogateOffsets`). Includes isolated surrogates and any other
    /// unit Core Text did not cover.
    public let unshapedUnitOffsets: [Int]

    /// Creates a shaping result.
    public init(
        runs: [MonaGlyphRun],
        isolatedSurrogateOffsets: [Int],
        unshapedUnitOffsets: [Int]
    ) {
        self.runs = runs
        self.isolatedSurrogateOffsets = isolatedSurrogateOffsets
        self.unshapedUnitOffsets = unshapedUnitOffsets
    }
}

/// Shapes raw UTF-16 lines with Core Text and deterministic font fallback.
///
/// Create a shaper once per (font, direction, scale, tab-stops) configuration
/// and call `shape(_:)` for each line. The shaper records the font faces and
/// run count from the most recent `shape(_:)` call for Q1-R4 provenance.
public final class MonaTextShaper {

    /// The primary font descriptor.
    public let primaryFontDescriptor: MonaFontDescriptor

    /// The fallback resolver supplying the deterministic cascade order.
    public let fallbackResolver: MonaFontFallbackResolver

    /// The base writing direction.
    public let direction: MonaTextDirection

    /// The device-space scale applied to positions, advances, and metrics.
    public let scale: CGFloat

    /// The tab stops (sorted ascending by position).
    public let tabStops: [MonaTabStop]

    /// Every font face recorded during the last `shape(_:)` call (Q1-R4
    /// provenance). Resets at the start of each call; stays empty if the call
    /// threw.
    public private(set) var recordedFaces: [MonaFontDescriptor] = []

    /// The number of glyph runs recorded during the last `shape(_:)` call.
    /// Resets at the start of each call; stays 0 if the call threw.
    public private(set) var recordedRunCount: Int = 0

    /// Creates a shaper.
    public init(
        primaryFont: MonaFontDescriptor,
        fallback: MonaFontFallbackResolver,
        direction: MonaTextDirection = .ltr,
        scale: CGFloat = 1,
        tabStops: [MonaTabStop] = []
    ) {
        self.primaryFontDescriptor = primaryFont
        self.fallbackResolver = fallback
        self.direction = direction
        self.scale = scale > 0 ? scale : 1
        self.tabStops = tabStops.sorted { $0.position < $1.position }
    }

    // MARK: - Shaping

    /// Shapes `codeUnits` (raw UTF-16) into glyph runs.
    ///
    /// - Returns: A `MonaShapingResult` with the runs, isolated-surrogate
    ///   offsets, and unshaped-unit offsets.
    /// - Throws: `MonaTextShaperError` if shaping cannot produce a complete
    ///   result. No partial runs are published on failure.
    public func shape(_ codeUnits: [UInt16]) throws -> MonaShapingResult {
        // Reset provenance for this call. Stays empty if we throw below.
        recordedFaces = []
        recordedRunCount = 0

        // 1. Validate the primary descriptor.
        guard MonaTextShaper.isDescriptorValid(primaryFontDescriptor) else {
            throw MonaTextShaperError.fontDescriptorInvalid(primaryFontDescriptor)
        }

        // 2. Resolve the cascade (validates the primary font's availability and
        //    filters unavailable fallbacks).
        let (primaryCT, fallbackCTs) = try fallbackResolver.resolveCascade()

        // 3. Build the primary CTFont with the cascade list attached. We create
        //    the CTFont at the nominal descriptor size; the `scale` is applied
        //    as a post-multiply so the font identity stays nominal.
        let shapingFont = buildShapingFont(primary: primaryCT, fallbacks: fallbackCTs)

        // 4. Detect isolated surrogates in the input and build a cleaned copy
        //    where each isolated surrogate is replaced with U+FFFD. This
        //    prevents Core Text from emitting a .notdef cluster that consumes
        //    adjacent units (e.g. a lone high surrogate followed by 'B' would
        //    otherwise absorb 'B'). The original surrogate positions are
        //    recorded in `isolatedSurrogateOffsets` regardless of glyph emission.
        let isolatedSurrogates = detectIsolatedSurrogates(in: codeUnits)
        let isolatedSet = Set(isolatedSurrogates)
        let cleanedInput = codeUnits.enumerated().map { (i, u) -> UInt16 in
            isolatedSet.contains(i) ? 0xFFFD : u
        }

        // 5. Prepend a strong directional mark to force the base writing
        //    direction. The mark is default-ignorable and produces no glyph.
        let mark: UInt16 = (direction == .rtl) ? 0x200F : 0x200E  // RLM / LRM
        var shapedUnits = [UInt16]()
        shapedUnits.reserveCapacity(cleanedInput.count + 1)
        shapedUnits.append(mark)
        shapedUnits.append(contentsOf: cleanedInput)

        // 5. Build a CFAttributedString with the font attribute over the whole
        //    range. CFString preserves isolated surrogates (UTF-16 internal).
        guard let cfString = CFStringCreateWithCharacters(
            kCFAllocatorDefault,
            shapedUnits,
            shapedUnits.count
        ) else {
            throw MonaTextShaperError.coreTextShapingFailed("CFString creation failed")
        }
        let attrDict: [CFString: Any] = [kCTFontAttributeName: shapingFont]
        guard let attributed = CFAttributedStringCreate(
            kCFAllocatorDefault,
            cfString,
            attrDict as CFDictionary
        ) else {
            throw MonaTextShaperError.coreTextShapingFailed("CFAttributedString creation failed")
        }

        // 6. Shape with Core Text. `CTLineCreateWithAttributedString` returns
        //    a non-optional CTLine in Swift (it creates an empty line on
        //    failure rather than returning nil).
        let line = CTLineCreateWithAttributedString(attributed)

        // 7. Walk the runs.
        let cfRuns = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        var runs: [MonaGlyphRun] = []
        var coveredOffsets = Set<Int>()
        var facesTouched = [MonaFontDescriptor]()
        runs.reserveCapacity(cfRuns.count)
        for cfRun in cfRuns {
            guard let run = extractRun(
                cfRun,
                markOffset: 1,
                coveredOffsets: &coveredOffsets,
                facesTouched: &facesTouched
            ) else {
                continue
            }
            runs.append(run)
        }

        // 8. Apply scale (post-multiply) to positions, advances, and metrics.
        if scale != 1 {
            runs = runs.map { scaleRun($0, by: scale) }
        }

        // 9. Apply tab stops (LTR only).
        if !tabStops.isEmpty {
            runs = applyTabStops(to: runs, codeUnits: codeUnits)
        }

        // 10. Build unshaped-unit offsets: every input offset not covered by a
        //     glyph, PLUS every isolated-surrogate offset (the original surrogate
        //     code unit did not produce a glyph — it was replaced with U+FFFD
        //     before shaping, so the surrogate itself is unshaped even though
        //     the replacement glyph covers the position).
        var unshapedSet = Set<Int>()
        for i in 0..<codeUnits.count {
            if !coveredOffsets.contains(i) {
                unshapedSet.insert(i)
            }
        }
        unshapedSet.formUnion(isolatedSet)
        let unshaped = unshapedSet.sorted()

        // 11. Record provenance.
        // De-duplicate faces while preserving first-seen order.
        var seen = Set<MonaFontDescriptor>()
        var uniqueFaces: [MonaFontDescriptor] = []
        for face in facesTouched {
            if seen.insert(face).inserted {
                uniqueFaces.append(face)
            }
        }
        recordedFaces = uniqueFaces
        recordedRunCount = runs.count

        return MonaShapingResult(
            runs: runs,
            isolatedSurrogateOffsets: isolatedSurrogates,
            unshapedUnitOffsets: unshaped
        )
    }

    // MARK: - Private: run extraction

    /// Extracts a `MonaGlyphRun` from a `CTRun`, mapping string indices back to
    /// the original input offsets (subtracting `markOffset`) and recording
    /// covered source offsets and touched faces.
    private func extractRun(
        _ ctRun: CTRun,
        markOffset: Int,
        coveredOffsets: inout Set<Int>,
        facesTouched: inout [MonaFontDescriptor]
    ) -> MonaGlyphRun? {
        let count = CTRunGetGlyphCount(ctRun)
        guard count > 0 else { return nil }
        let wholeRange = CFRange(location: 0, length: 0)

        // Glyphs.
        var glyphs = [CGGlyph](repeating: 0, count: count)
        glyphs.withUnsafeMutableBufferPointer { buf in
            CTRunGetGlyphs(ctRun, wholeRange, buf.baseAddress!)
        }
        // Positions (relative to line origin).
        var positions = [CGPoint](repeating: .zero, count: count)
        positions.withUnsafeMutableBufferPointer { buf in
            CTRunGetPositions(ctRun, wholeRange, buf.baseAddress!)
        }
        // Advances.
        var advances = [CGSize](repeating: .zero, count: count)
        advances.withUnsafeMutableBufferPointer { buf in
            CTRunGetAdvances(ctRun, wholeRange, buf.baseAddress!)
        }
        // String indices (into the mark-prepended attributed string).
        var stringIndices = [CFIndex](repeating: 0, count: count)
        stringIndices.withUnsafeMutableBufferPointer { buf in
            CTRunGetStringIndices(ctRun, wholeRange, buf.baseAddress!)
        }
        // Typographic bounds. The range parameter is by-value (input); the
        // function clamps it internally and returns the run's width.
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let boundsRange = CFRange(location: 0, length: count)
        _ = CTRunGetTypographicBounds(ctRun, boundsRange, &ascent, &descent, &leading)
        // Run status (direction).
        let status = CTRunGetStatus(ctRun)
        let isRTL = (status.rawValue & CTRunStatus.rightToLeft.rawValue) != 0

        // Map string indices back to the original input offsets. Drop any glyph
        // whose mapped index is < 0 (the directional mark itself, if it ever
        // produced a glyph — it normally does not).
        var mappedGlyphs: [CGGlyph] = []
        var mappedPositions: [CGPoint] = []
        var mappedAdvances: [CGSize] = []
        var mappedIndices: [Int] = []
        mappedGlyphs.reserveCapacity(count)
        mappedPositions.reserveCapacity(count)
        mappedAdvances.reserveCapacity(count)
        mappedIndices.reserveCapacity(count)
        for i in 0..<count {
            let mapped = Int(stringIndices[i]) - markOffset
            if mapped < 0 { continue }  // the directional mark; skip.
            mappedGlyphs.append(glyphs[i])
            mappedPositions.append(positions[i])
            mappedAdvances.append(advances[i])
            mappedIndices.append(mapped)
            coveredOffsets.insert(mapped)
        }
        guard !mappedGlyphs.isEmpty else { return nil }

        // Source range = min..<(max+1) of the mapped indices.
        let minIdx = mappedIndices.min() ?? 0
        let maxIdx = mappedIndices.max() ?? 0
        let sourceRange = minIdx..<(maxIdx + 1)

        // Font face: extract the CTFont from the run attributes and map it to
        // a descriptor (preferring the caller-supplied nominal descriptor when
        // the family matches, so provenance reports nominal size not scaled).
        let runFont = MonaTextShaper.fontFromRun(ctRun)
        let descriptor = descriptorForFont(runFont)

        facesTouched.append(descriptor)

        return MonaGlyphRun(
            glyphs: mappedGlyphs,
            positions: mappedPositions,
            advances: mappedAdvances,
            stringIndices: mappedIndices,
            sourceRange: sourceRange,
            fontDescriptor: descriptor,
            ascent: ascent,
            descent: descent,
            leading: leading,
            isRightToLeft: isRTL
        )
    }

    // MARK: - Private: font helpers

    /// Builds the `CTFont` used for shaping, attaching the explicit cascade
    /// list when fallbacks are available. The font is created at the nominal
    /// descriptor size; scale is applied separately.
    private func buildShapingFont(primary: CTFont, fallbacks: [CTFont]) -> CTFont {
        if fallbacks.isEmpty {
            return primary
        }
        // Attach the cascade list to the primary font's descriptor.
        let cascadeDescs = fallbacks.map { CTFontCopyFontDescriptor($0) }
        let primaryDesc = CTFontCopyFontDescriptor(primary)
        let augmentedDesc = CTFontDescriptorCreateCopyWithAttributes(
            primaryDesc,
            [kCTFontCascadeListAttribute: cascadeDescs as CFArray] as CFDictionary
        )
        let size = primaryFontDescriptor.size
        return CTFontCreateWithFontDescriptor(augmentedDesc, size, nil)
    }

    /// Returns the `CTFont` attribute attached to `run`, or nil.
    private static func fontFromRun(_ run: CTRun) -> CTFont? {
        let attrs = CTRunGetAttributes(run)
        let key = Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()
        guard let ptr = CFDictionaryGetValue(attrs, key) else { return nil }
        return Unmanaged<CTFont>.fromOpaque(ptr).takeUnretainedValue()
    }

    /// Maps a `CTFont` to a `MonaFontDescriptor`, preferring the caller-supplied
    /// nominal descriptor (primary or fallback) when the family matches, so
    /// provenance reports the nominal identity rather than the scaled size.
    private func descriptorForFont(_ font: CTFont?) -> MonaFontDescriptor {
        guard let font = font else {
            return primaryFontDescriptor
        }
        let family = (CTFontCopyFamilyName(font) as String?) ?? ""
        if family.caseInsensitiveCompare(primaryFontDescriptor.familyName) == .orderedSame {
            return primaryFontDescriptor
        }
        for fb in fallbackResolver.fallbacks {
            if family.caseInsensitiveCompare(fb.familyName) == .orderedSame {
                return fb
            }
        }
        // Unknown face (e.g. Core Text's default automatic cascade picked a
        // system face not in the explicit list). Record a descriptor at the
        // CTFont's actual family and size for provenance fidelity.
        return MonaFontDescriptor(familyName: family, size: CTFontGetSize(font))
    }

    // MARK: - Private: scale + tab stops

    /// Returns a copy of `run` with positions, advances, and metrics multiplied
    /// by `factor`.
    private func scaleRun(_ run: MonaGlyphRun, by factor: CGFloat) -> MonaGlyphRun {
        let positions = run.positions.map {
            CGPoint(x: $0.x * factor, y: $0.y * factor)
        }
        let advances = run.advances.map {
            CGSize(width: $0.width * factor, height: $0.height * factor)
        }
        return MonaGlyphRun(
            glyphs: run.glyphs,
            positions: positions,
            advances: advances,
            stringIndices: run.stringIndices,
            sourceRange: run.sourceRange,
            fontDescriptor: run.fontDescriptor,
            ascent: run.ascent * factor,
            descent: run.descent * factor,
            leading: run.leading * factor,
            isRightToLeft: run.isRightToLeft
        )
    }

    /// Applies tab stops to LTR runs: each tab glyph's advance is replaced with
    /// the distance to the next tab stop strictly greater than the glyph's
    /// current x, and subsequent positions are recomputed.
    private func applyTabStops(to runs: [MonaGlyphRun], codeUnits: [UInt16]) -> [MonaGlyphRun] {
        return runs.map { run in
            // Only LTR runs get tab-stop processing.
            guard !run.isRightToLeft else { return run }
            guard !run.glyphs.isEmpty else { return run }

            var newPositions: [CGPoint] = []
            var newAdvances: [CGSize] = []
            newPositions.reserveCapacity(run.glyphs.count)
            newAdvances.reserveCapacity(run.glyphs.count)

            var cumX = run.positions[0].x
            for i in 0..<run.glyphs.count {
                newPositions.append(CGPoint(x: cumX, y: run.positions[i].y))
                var adv = run.advances[i]
                let sourceIdx = run.stringIndices[i]
                if sourceIdx < codeUnits.count && codeUnits[sourceIdx] == 0x0009 {
                    // Tab character: snap advance to the next tab stop > cumX.
                    if let nextStop = nextTabStop(after: cumX) {
                        adv = CGSize(width: nextStop - cumX, height: adv.height)
                    }
                }
                newAdvances.append(adv)
                cumX += adv.width
            }

            return MonaGlyphRun(
                glyphs: run.glyphs,
                positions: newPositions,
                advances: newAdvances,
                stringIndices: run.stringIndices,
                sourceRange: run.sourceRange,
                fontDescriptor: run.fontDescriptor,
                ascent: run.ascent,
                descent: run.descent,
                leading: run.leading,
                isRightToLeft: run.isRightToLeft
            )
        }
    }

    /// Returns the smallest tab stop position strictly greater than `x`, or nil.
    private func nextTabStop(after x: CGFloat) -> CGFloat? {
        for stop in tabStops where stop.position > x {
            return stop.position
        }
        return nil
    }

    // MARK: - Private: isolated surrogate detection

    /// Returns the source offsets of isolated surrogates in `codeUnits`.
    ///
    /// An isolated surrogate is a high surrogate (0xD800-0xDBFF) not followed
    /// by a low surrogate, or a low surrogate (0xDC00-0xDFFF) not preceded by a
    /// high surrogate.
    private func detectIsolatedSurrogates(in codeUnits: [UInt16]) -> [Int] {
        var offsets: [Int] = []
        var i = 0
        while i < codeUnits.count {
            let u = codeUnits[i]
            if MonaTextShaper.isHighSurrogate(u) {
                let next = (i + 1 < codeUnits.count) ? codeUnits[i + 1] : 0
                if MonaTextShaper.isLowSurrogate(next) {
                    // Valid surrogate pair; skip both.
                    i += 2
                    continue
                } else {
                    // Isolated high surrogate.
                    offsets.append(i)
                    i += 1
                    continue
                }
            } else if MonaTextShaper.isLowSurrogate(u) {
                // Isolated low surrogate (not preceded by a high surrogate).
                offsets.append(i)
                i += 1
                continue
            }
            i += 1
        }
        return offsets
    }

    // MARK: - Private: validation

    fileprivate static func isDescriptorValid(_ descriptor: MonaFontDescriptor) -> Bool {
        return !descriptor.familyName.isEmpty && descriptor.size > 0
    }

    fileprivate static func isHighSurrogate(_ u: UInt16) -> Bool {
        return u >= 0xD800 && u <= 0xDBFF
    }

    fileprivate static func isLowSurrogate(_ u: UInt16) -> Bool {
        return u >= 0xDC00 && u <= 0xDFFF
    }
}
