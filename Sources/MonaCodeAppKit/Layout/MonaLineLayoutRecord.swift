// MonaLineLayoutRecord.swift
//
// P03-T003 — Freeze shared immutable LineLayoutRecord geometry.
//
// `MonaLineLayoutRecord` is the immutable value that freezes the geometry of one
// shaped line. After `MonaTextShaper` (P03-T002) shapes a UTF-16 line into glyph
// runs, `MonaLineLayoutBuilder` assembles those runs together with advances,
// baselines, raw-unit boundaries, bidi levels, injected-text spans, decorations,
// and paint inputs into a single `MonaLineLayoutRecord`. Every downstream
// consumer — hit tester, selection geometry, renderer — reads the SAME frozen
// record without reshaping.
//
// The record is keyed by a `MonaLineLayoutDependencyStamp` carrying font + scale
// + direction + wrapping state. Viewport position is deliberately NOT part of
// the stamp: a record is reusable across viewport positions as long as the
// shaping inputs are unchanged.
//
// Supporting value types defined here:
//   - `MonaRawUnitBoundary`     — one UTF-16 unit's x-extent (for hit testing).
//   - `MonaInjectedTextSpan`    — an injected-text span recorded on the line.
//   - `MonaLineDecoration`      — a decoration recorded on the line.
//   - `MonaPaintInputs`          — frozen rendering inputs (colors + selections).
//   - `MonaLineLayoutDependencyStamp` — the cache key for a record.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreText + CoreGraphics + Foundation.

import Foundation
import CoreText
import CoreGraphics

// MARK: - MonaRawUnitBoundary

/// The x-extent of one source UTF-16 unit within a shaped line.
///
/// `MonaLineLayoutBuilder` produces one boundary per covered UTF-16 unit. The
/// boundary records the unit's UTF-16 range (typically `[i, i+1)`, or
/// `[i, i+2)` for a surrogate pair treated as one unit) and its pixel
/// `[startX, endX)` extent relative to the line origin. These boundaries are
/// the sole data source for `MonaLineLayoutRecord.hitTest(offset:)` — no
/// reshaping is needed at query time.
public struct MonaRawUnitBoundary: Equatable, Hashable, Sendable {

    /// The UTF-16 offset range this boundary covers in the source line.
    public let utf16Range: Range<Int>

    /// The device-space x position (relative to the line origin) where this
    /// unit begins.
    public let startX: CGFloat

    /// The device-space x position (relative to the line origin) where this
    /// unit ends.
    public let endX: CGFloat

    /// Creates a raw-unit boundary.
    public init(utf16Range: Range<Int>, startX: CGFloat, endX: CGFloat) {
        self.utf16Range = utf16Range
        self.startX = startX
        self.endX = endX
    }

    /// The pixel width of this unit (`endX - startX`).
    public var width: CGFloat { endX - startX }
}

// MARK: - MonaInjectedTextSpan

/// An injected-text span recorded on a line's layout record.
///
/// Injected text is shaped as part of the line (the shaper receives the full
/// line text including injections). This span records the injection's identity,
/// its UTF-16 offset range in the shaped line, and its pixel width, so the
/// renderer can attribute the geometry to the injection.
public struct MonaInjectedTextSpan: Equatable, Hashable, Sendable {

    /// A stable identifier for the injection (unique within one line).
    public let id: String

    /// The UTF-16 offset range the injection occupies in the shaped line.
    public let utf16Range: Range<Int>

    /// The device-space pixel width of the injected text.
    public let width: CGFloat

    /// Creates an injected-text span.
    public init(id: String, utf16Range: Range<Int>, width: CGFloat) {
        self.id = id
        self.utf16Range = utf16Range
        self.width = width
    }
}

// MARK: - MonaLineDecoration

/// A decoration recorded on a line's layout record.
///
/// Decorations carry an id, a UTF-16 range, and a className that the renderer
/// resolves to visual properties (background color, underline, etc.). The
/// immutable record freezes which decorations apply so the renderer does not
/// re-resolve them at paint time.
public struct MonaLineDecoration: Equatable, Hashable, Sendable {

    /// A stable identifier for the decoration.
    public let id: String

    /// The UTF-16 offset range the decoration covers in the shaped line.
    public let utf16Range: Range<Int>

    /// A CSS-like class name resolved by the renderer to visual properties.
    public let className: String

    /// Creates a line decoration.
    public init(id: String, utf16Range: Range<Int>, className: String) {
        self.id = id
        self.utf16Range = utf16Range
        self.className = className
    }
}

// MARK: - MonaPaintInputs

/// The frozen rendering inputs for a line: foreground/background colors and
/// selection ranges. The renderer reads these from the immutable record so it
/// does not re-query the theme or selection state at paint time.
public struct MonaPaintInputs: Equatable, Hashable, Sendable {

    /// An RGBA color value.
    public struct Color: Equatable, Hashable, Sendable {

        /// The red channel (0...1).
        public let red: CGFloat

        /// The green channel (0...1).
        public let green: CGFloat

        /// The blue channel (0...1).
        public let blue: CGFloat

        /// The alpha channel (0...1).
        public let alpha: CGFloat

        /// Creates a color. `alpha` defaults to 1 (fully opaque).
        public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

    /// The foreground text color.
    public let foreground: Color

    /// The background color.
    public let background: Color

    /// UTF-16 offset ranges that are part of the active selection.
    public let selectionRanges: [Range<Int>]

    /// Creates paint inputs.
    public init(
        foreground: Color,
        background: Color,
        selectionRanges: [Range<Int>] = []
    ) {
        self.foreground = foreground
        self.background = background
        self.selectionRanges = selectionRanges
    }

    /// Default plain paint inputs: black text on a white background, no
    /// selection.
    public static let plain = MonaPaintInputs(
        foreground: Color(red: 0, green: 0, blue: 0),
        background: Color(red: 1, green: 1, blue: 1)
    )
}

// MARK: - MonaLineLayoutDependencyStamp

/// The cache key for a `MonaLineLayoutRecord`.
///
/// The stamp captures every input that affects a line's shaped geometry: the
/// font descriptor, the device-space scale, the base writing direction, and the
/// wrapping column. Viewport position is deliberately NOT part of the stamp:
/// a record is reusable across viewport positions as long as these shaping
/// inputs are unchanged. This is the "key records by complete dependency stamps
/// rather than viewport position alone" invariant from P03-T003.
public struct MonaLineLayoutDependencyStamp: Equatable, Hashable, Sendable {

    /// The font descriptor that shaped the line.
    public let fontDescriptor: MonaFontDescriptor

    /// The device-space scale applied during shaping.
    public let scale: CGFloat

    /// The base writing direction.
    public let direction: MonaTextDirection

    /// The word-wrap column (`nil` = no wrapping).
    public let wrappingColumn: Int?

    /// Creates a dependency stamp.
    public init(
        fontDescriptor: MonaFontDescriptor,
        scale: CGFloat,
        direction: MonaTextDirection,
        wrappingColumn: Int?
    ) {
        self.fontDescriptor = fontDescriptor
        self.scale = scale
        self.direction = direction
        self.wrappingColumn = wrappingColumn
    }
}

// MARK: - MonaLineLayoutRecord

/// The immutable, frozen geometry of one shaped line.
///
/// `MonaLineLayoutRecord` stores every piece of data a renderer or hit tester
/// needs for one line, assembled by `MonaLineLayoutBuilder` from a
/// `MonaShapingResult`. Once built, the record is never mutated: hit testing
/// and rendering consume it without reshaping.
///
/// The record is keyed by a `MonaLineLayoutDependencyStamp` so consumers can
/// check whether a cached record matches the current shaping inputs (font,
/// scale, direction, wrapping) without re-shaping.
public struct MonaLineLayoutRecord: Equatable, Hashable, Sendable {

    /// The shaped glyph runs (from P03-T002), in visual order.
    public let glyphRuns: [MonaGlyphRun]

    /// The total advance (pixel width) of each run, parallel to `glyphRuns`.
    /// Each entry is the sum of that run's per-glyph advance widths.
    public let advances: [CGFloat]

    /// The line's baseline y-offset from the top (the maximum ascent across
    /// all runs). All runs share this baseline.
    public let baseline: CGFloat

    /// Per-run baseline y-offset from the line top, parallel to `glyphRuns`.
    /// For a single-baseline line every entry equals `baseline`; the array is
    /// kept per-run so multi-baseline scenarios are expressible without
    /// restructuring the record.
    public let baselines: [CGFloat]

    /// The line's ascent (the maximum run ascent).
    public let ascent: CGFloat

    /// The line's descent (the maximum run descent).
    public let descent: CGFloat

    /// The line's leading (the maximum run leading).
    public let leading: CGFloat

    /// The raw-unit boundaries: one per covered UTF-16 unit, sorted by
    /// ascending x position. These are the sole data source for
    /// `hitTest(offset:)`.
    public let rawUnitBoundaries: [MonaRawUnitBoundary]

    /// Per-run Unicode bidi embedding level, parallel to `glyphRuns`. Even
    /// levels are LTR; odd levels are RTL. Derived by the builder from each
    /// run's `isRightToLeft` flag (0 = LTR base, 1 = RTL base).
    public let bidiLevels: [UInt8]

    /// Injected-text spans recorded on this line.
    public let injectedTextSpans: [MonaInjectedTextSpan]

    /// Decorations recorded on this line.
    public let decorations: [MonaLineDecoration]

    /// The frozen rendering inputs for this line.
    public let paintInputs: MonaPaintInputs

    /// The dependency stamp keying this record.
    public let dependencyStamp: MonaLineLayoutDependencyStamp

    /// The total number of UTF-16 units in the source line.
    public let sourceLength: Int

    /// Creates an immutable line-layout record.
    public init(
        glyphRuns: [MonaGlyphRun],
        advances: [CGFloat],
        baseline: CGFloat,
        baselines: [CGFloat],
        ascent: CGFloat,
        descent: CGFloat,
        leading: CGFloat,
        rawUnitBoundaries: [MonaRawUnitBoundary],
        bidiLevels: [UInt8],
        injectedTextSpans: [MonaInjectedTextSpan],
        decorations: [MonaLineDecoration],
        paintInputs: MonaPaintInputs,
        dependencyStamp: MonaLineLayoutDependencyStamp,
        sourceLength: Int
    ) {
        self.glyphRuns = glyphRuns
        self.advances = advances
        self.baseline = baseline
        self.baselines = baselines
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.rawUnitBoundaries = rawUnitBoundaries
        self.bidiLevels = bidiLevels
        self.injectedTextSpans = injectedTextSpans
        self.decorations = decorations
        self.paintInputs = paintInputs
        self.dependencyStamp = dependencyStamp
        self.sourceLength = sourceLength
    }

    // MARK: - Computed geometry

    /// The total pixel width of the line (sum of per-run advances).
    public var totalWidth: CGFloat {
        return advances.reduce(0, +)
    }

    /// The pixel height of the line (ascent + descent + leading).
    public var lineHeight: CGFloat {
        return ascent + descent + leading
    }

    // MARK: - Hit testing

    /// Maps a device-space x offset (relative to the line origin) to a UTF-16
    /// offset within the source line.
    ///
    /// This is a pure lookup on the frozen `rawUnitBoundaries` — no reshaping
    /// occurs. The algorithm:
    ///   - Before the first unit: clamp to `0`.
    ///   - After the last unit: clamp to `sourceLength`.
    ///   - Within a unit: snap to the nearer edge (start or end) of that unit.
    ///   - In a gap between units: return the end offset of the last unit
    ///     before the gap.
    ///
    /// - Returns: The UTF-16 offset, or `nil` when the record has no
    ///   boundaries (empty line).
    public func hitTest(offset: CGFloat) -> Int? {
        guard !rawUnitBoundaries.isEmpty else { return nil }

        // Before the first unit: clamp to 0.
        let first = rawUnitBoundaries[0]
        if offset <= first.startX {
            return 0
        }

        // After the last unit: clamp to sourceLength.
        let last = rawUnitBoundaries[rawUnitBoundaries.count - 1]
        if offset >= last.endX {
            return sourceLength
        }

        // Binary search for the unit whose [startX, endX) contains `offset`.
        var lo = 0
        var hi = rawUnitBoundaries.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let b = rawUnitBoundaries[mid]
            if offset < b.startX {
                hi = mid - 1
            } else if offset >= b.endX {
                lo = mid + 1
            } else {
                // `offset` is within this unit's extent. Snap to the nearer
                // edge: left half (inclusive of the midpoint) -> start offset;
                // right half -> end offset.
                let midpoint = (b.startX + b.endX) / 2
                if offset <= midpoint {
                    return b.utf16Range.lowerBound
                } else {
                    return b.utf16Range.upperBound
                }
            }
        }

        // `offset` fell in a gap between two units. Return the end offset of
        // the last unit before the gap (hi points to it after the loop).
        if hi >= 0 {
            return rawUnitBoundaries[hi].utf16Range.upperBound
        }
        return 0
    }
}
