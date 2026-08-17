// MonaGlyphRun.swift
//
// P03-T002 — Shape mixed-script lines with Core Text and deterministic fallback.
//
// Foundational value types for the Core Text shaping layer:
//   - `MonaFontDescriptor` — the immutable identity of a font face (family name
//     + point size). This is the Q1-R4 font-provenance identity: every shaped
//     glyph run records the descriptor of the face that produced its glyphs, so
//     downstream code can attribute any rendered glyph to a concrete face
//     without re-resolving Core Text.
//   - `MonaTextDirection` — the base writing direction of a line (LTR or RTL).
//   - `MonaTabStop` — a device-space pixel x position a tab character snaps to.
//   - `MonaGlyphRun` — one shaped glyph run: glyph IDs, positions, advances,
//     per-glyph source UTF-16 indices, the source UTF-16 range, the font face
//     descriptor, typographic metrics, and an RTL flag. Immutable value type.
//
// `MonaGlyphRun` stores the font *descriptor* (the provenance identity) rather
// than a `CTFont` instance, so the struct has pure value semantics and auto-
// synthesized `Equatable`/`Hashable`. The resolved `CTFont` is re-derived from
// the descriptor on demand via the computed `font` property; this is sufficient
// because glyph IDs are already fixed at shaping time — the `CTFont` is only
// needed to look up outlines during rendering, and the immutable
// `MonaLineLayoutRecord` (P03-T003) caches the long-lived `CTFont` for the
// renderer.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreText + CoreGraphics + Foundation.

import Foundation
import CoreText
import CoreGraphics

/// The immutable identity of a font face: family name + point size.
///
/// Two descriptors with the same family name and size are equal. This is the
/// Q1-R4 font-provenance identity recorded for every shaped glyph run.
public struct MonaFontDescriptor: Equatable, Hashable, Sendable {

    /// The Core Text family name (e.g. `"Menlo"`, `"Apple Color Emoji"`).
    public let familyName: String

    /// The point size.
    public let size: CGFloat

    /// Creates a font descriptor.
    public init(familyName: String, size: CGFloat) {
        self.familyName = familyName
        self.size = size
    }
}

/// The base writing direction of a line.
public enum MonaTextDirection: Equatable, Hashable, Sendable {

    /// Left-to-right base direction.
    case ltr

    /// Right-to-left base direction.
    case rtl
}

/// A tab stop: a device-space pixel x position that a tab character snaps the
/// pen to.
public struct MonaTabStop: Equatable, Hashable, Sendable {

    /// The device-space pixel x position.
    public let position: CGFloat

    /// Creates a tab stop at `position`.
    public init(position: CGFloat) {
        self.position = position
    }
}

/// One shaped glyph run produced by `MonaTextShaper`.
///
/// A glyph run is a maximal sequence of glyphs sharing one font face and one
/// direction, shaped by Core Text as a single `CTRun`. All positions and
/// advances are in device-space pixels (already scaled by the shaper's `scale`
/// factor) and are relative to the line origin.
///
/// `MonaGlyphRun` is an immutable value type. Equality and hashing compare
/// every stored field; two runs with the same glyphs, positions, advances,
/// indices, range, descriptor, metrics, and direction are equal regardless of
/// construction path.
public struct MonaGlyphRun: Equatable, Hashable, Sendable {

    /// The glyph IDs, one per glyph, in visual order within the run.
    public let glyphs: [CGGlyph]

    /// The device-space position of each glyph's origin, relative to the line
    /// origin. `positions.count == glyphs.count`.
    public let positions: [CGPoint]

    /// The per-glyph advance (width + any side bearing) in device-space pixels.
    /// `advances.count == glyphs.count`.
    public let advances: [CGSize]

    /// The source UTF-16 offset (into the shaper's input `[UInt16]`) of each
    /// glyph. `stringIndices.count == glyphs.count`.
    public let stringIndices: [Int]

    /// The source UTF-16 unit range this run covers in the input line.
    public let sourceRange: Range<Int>

    /// The font face descriptor that produced these glyphs (Q1-R4 provenance).
    public let fontDescriptor: MonaFontDescriptor

    /// The font's typographic ascent (device-space pixels).
    public let ascent: CGFloat

    /// The font's typographic descent (device-space pixels, positive value).
    public let descent: CGFloat

    /// The font's leading (device-space pixels).
    public let leading: CGFloat

    /// `true` when Core Text reported this run as right-to-left
    /// (`kCTRunStatusRightToLeft`).
    public let isRightToLeft: Bool

    /// Creates a glyph run. All arrays must have equal counts.
    public init(
        glyphs: [CGGlyph],
        positions: [CGPoint],
        advances: [CGSize],
        stringIndices: [Int],
        sourceRange: Range<Int>,
        fontDescriptor: MonaFontDescriptor,
        ascent: CGFloat,
        descent: CGFloat,
        leading: CGFloat,
        isRightToLeft: Bool = false
    ) {
        self.glyphs = glyphs
        self.positions = positions
        self.advances = advances
        self.stringIndices = stringIndices
        self.sourceRange = sourceRange
        self.fontDescriptor = fontDescriptor
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.isRightToLeft = isRightToLeft
    }

    /// The resolved `CTFont` for this run's descriptor. Re-derived on each
    /// access from `fontDescriptor`; callers that need a long-lived instance
    /// (e.g. the renderer) should cache it.
    public var font: CTFont {
        return MonaGlyphRun.resolveCTFont(for: fontDescriptor)
    }

    // MARK: - Internal

    /// Resolves a `CTFont` from a descriptor (no substitution check). Used by
    /// the computed `font` property and shared with the fallback resolver.
    static func resolveCTFont(for descriptor: MonaFontDescriptor) -> CTFont {
        let attributes: [CFString: Any] = [
            kCTFontFamilyNameAttribute: descriptor.familyName,
            kCTFontSizeAttribute: descriptor.size,
        ]
        let ctDescriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(ctDescriptor, descriptor.size, nil)
    }
}
