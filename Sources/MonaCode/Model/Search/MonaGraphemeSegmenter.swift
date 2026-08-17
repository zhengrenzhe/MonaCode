// MonaGraphemeSegmenter.swift
//
// P02-T003 — Implement word, grapheme, literal search, and replacement primitives.
//
// `MonaGraphemeSegmenter` segments raw UTF-16 into grapheme clusters — the
// user-perceived characters that Monaco's cursor and selection operations move
// over. It is the Swift counterpart of Monaco's grapheme iteration helpers
// (monaco-editor 0.56.0, `vs/base/common/strings.ts` `GraphemeIterator` /
// `nextCharLength` / `prevCharLength`), adapted to raw `[UInt16]` storage.
//
// Frozen profile (M1-R model, raw UTF-16):
//
//   - A surrogate pair (high `[0xD800...0xDBFF]` followed by low
//     `[0xDC00...0xDFFF]`) is one grapheme cluster spanning two code units.
//     An isolated (unpaired) surrogate is one grapheme cluster of one code
//     unit — it is never repaired or merged with an adjacent unit.
//   - A combining mark (general category Mn, the Unicode block
//     U+0300..U+036F plus other combining ranges listed below) clusters with
//     the preceding base: `base + combining` is one grapheme cluster.
//   - ASCII text has one grapheme cluster per code unit.
//   - Grapheme cluster boundaries are UTF-16 code-unit offsets; no code units
//     are repaired, normalized, or substituted.
//
// This implements the core of UAX #29 extended grapheme cluster segmentation
// sufficient for the Phase-02 primitives: surrogate-pair handling and
// combining-mark clustering. Full tailored grapheme segmentation (regional
// indicators, ZWJ sequences, etc.) is layered on later alongside the RegExp
// Unicode profiles; this frozen profile is the contract surface P02-T003
// verifies.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Grapheme-cluster segmentation over raw UTF-16 code units.
///
/// A stateless namespace of static methods; the entry point named by P02-T003
/// is `graphemeLength(_:)`. Boundary helpers `nextBoundary(after:in:)` and
/// `previousBoundary(before:in:)` enable forward and backward grapheme
/// iteration.
public enum MonaGraphemeSegmenter {

    /// Returns the number of grapheme clusters in `units`.
    public static func graphemeLength(_ units: [UInt16]) -> Int {
        var count = 0
        var i = 0
        let n = units.count
        while i < n {
            i = advanceBoundary(from: i, in: units)
            count += 1
        }
        return count
    }

    /// Returns the UTF-16 code-unit offset of the next grapheme-cluster boundary
    /// strictly after `from`.
    ///
    /// If `from` is at or past the end, returns `units.count` (clamps at end).
    public static func nextBoundary(after from: Int, in units: [UInt16]) -> Int {
        if from >= units.count {
            return units.count
        }
        if from < 0 {
            return 0
        }
        return advanceBoundary(from: from, in: units)
    }

    /// Returns the UTF-16 code-unit offset of the grapheme-cluster boundary
    /// strictly before `from` — i.e. the start of the cluster that contains or
    /// precedes position `from - 1`. Used for backward grapheme iteration.
    ///
    /// If `from` is at or before the start (or non-positive), returns `0`
    /// (clamps at start). If `from` is past the end, it is treated as the end.
    public static func previousBoundary(before from: Int, in units: [UInt16]) -> Int {
        if from <= 0 {
            return 0
        }
        let end = from > units.count ? units.count : from
        return previousBoundaryClamped(end, in: units)
    }

    // MARK: - Internals

    /// Advances from `i` to the start of the next grapheme cluster.
    ///
    /// A grapheme cluster is: one base code unit (which may be a surrogate
    /// pair, consuming two units) followed by any run of combining marks
    /// (each consuming one unit).
    private static func advanceBoundary(from i: Int, in units: [UInt16]) -> Int {
        let n = units.count
        guard i < n else { return n }

        var j = i
        // Consume one grapheme base: a surrogate pair or a single code unit.
        if isHighSurrogate(units[j]) && j + 1 < n && isLowSurrogate(units[j + 1]) {
            j += 2
        } else {
            j += 1
        }
        // Consume any run of combining marks that cluster with this base.
        while j < n && isCombiningMark(units[j]) {
            j += 1
        }
        return j
    }

    /// Walks forward from 0 to find the greatest cluster-start boundary `b`
    /// such that `b < from`. Returns `0` if `from <= 0` (caller guards).
    private static func previousBoundaryClamped(_ from: Int, in units: [UInt16]) -> Int {
        var b = 0
        var lastBefore = 0
        while b < from {
            lastBefore = b
            let next = advanceBoundary(from: b, in: units)
            if next >= from {
                return lastBefore
            }
            b = next
        }
        return lastBefore
    }

    /// Returns `true` if `u` is a high (leading) surrogate.
    private static func isHighSurrogate(_ u: UInt16) -> Bool {
        return u >= 0xD800 && u <= 0xDBFF
    }

    /// Returns `true` if `u` is a low (trailing) surrogate.
    private static func isLowSurrogate(_ u: UInt16) -> Bool {
        return u >= 0xDC00 && u <= 0xDFFF
    }

    /// Returns `true` if `u` is a combining mark that clusters with the
    /// preceding base.
    ///
    /// Covers the principal combining-mark ranges used by the frozen profile:
    ///   - U+0300..U+036F  (Combining Diacritical Marks)
    ///   - U+0483..U+0487  (Cyrillic combining marks)
    ///   - U+0591..U+05BD  (Hebrew points) + U+05BF + U+05C1..U+05C2 +
    ///     U+05C4..U+05C5 + U+05C7
    ///   - U+0610..U+061A  (Arabic combining)
    ///   - U+064B..U+065F  (Arabic marks)
    ///   - U+0670          (Arabic superscript alef)
    ///   - U+06D6..U+06DC, U+06DF..U+06E4, U+06E7..U+06E8, U+06EA..U+06ED
    ///   - U+0711          (Syriac)
    ///   - U+0730..U+074A  (Syriac combining)
    ///   - U+0900..U+0903, U+093A..U+094F, U+0951..U+0957 (Devanagari)
    ///   - U+20D0..U+20FF  (combining marks for symbols)
    ///   - U+FE00..U+FE0F  (variation selectors)
    ///   - U+FE20..U+FE2F  (combining half marks)
    ///
    /// Surrogates are never combining marks.
    private static func isCombiningMark(_ u: UInt16) -> Bool {
        switch u {
        case 0x0300...0x036F, 0x0483...0x0487,
             0x0591...0x05BD, 0x05BF, 0x05C1...0x05C2,
             0x05C4...0x05C5, 0x05C7,
             0x0610...0x061A, 0x064B...0x065F, 0x0670,
             0x06D6...0x06DC, 0x06DF...0x06E4,
             0x06E7...0x06E8, 0x06EA...0x06ED,
             0x0711, 0x0730...0x074A,
             0x0900...0x0903, 0x093A...0x094F, 0x0951...0x0957,
             0x20D0...0x20FF,
             0xFE00...0xFE0F, 0xFE20...0xFE2F:
            return true
        default:
            return false
        }
    }
}
