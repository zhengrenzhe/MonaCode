// MonaCoreGraphicsRenderer.swift
//
// P03-T006 — Complete the correct Core Graphics tiled renderer.
//
// `MonaCoreGraphicsRenderer` paints complete immutable `MonaLineLayoutRecord`s
// (P03-T003) into generation-keyed tiles using Core Graphics. It does NOT
// reshape text: every glyph it draws is read from the frozen glyph runs already
// stored on the layout record. Each tile is a `MonaRenderSurface` rasterized in
// linear premultiplied RGBA and cached under a `MonaRenderTileKey` that captures
// (generation, tile-x, tile-y, scale, subpixel-phase-x, subpixel-phase-y).
//
// The renderer composites every layer in the frozen z-order (bottom → top):
//   text → selections → cursors → decorations → widgets → gutters → minimap
//        → overlays
// Painting in this exact order is what makes a composited frame read
// correctly: a selection never occludes the text it highlights, a cursor never
// disappears under a decoration, and an overlay always composites on top.
//
// Cache contract: a tile is rasterized once per key and reused on subsequent
// requests for the same key. Scale and subpixel phase are part of the key, so a
// scale change or a subpixel scroll forces a re-rasterization. The tile cache
// (P03-T006 `MonaRenderTileCache`) bounds memory and evicts LRU without losing
// current-generation truth.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreGraphics + CoreText + Foundation.

import Foundation
import CoreGraphics
import CoreText

// MARK: - MonaRenderZLayer

/// The frozen compositing z-order (bottom → top) for the tiled renderer.
///
/// The renderer paints layers in `MonaRenderZLayer.allCases` order (ascending
/// `rawValue`). This order is frozen: a selection never occludes the text it
/// highlights (selections above text), a cursor never disappears under a
/// decoration (cursors above selections), and an overlay always composites on
/// top (overlays last).
public enum MonaRenderZLayer: Int, CaseIterable, Sendable {
    /// Glyph outlines + the per-line background fill (the text layer's base).
    case text = 0
    /// Selection range highlights.
    case selections = 1
    /// Caret/cursor lines.
    case cursors = 2
    /// Line decorations (underlines, background highlights, etc.).
    case decorations = 3
    /// View-zone widgets.
    case widgets = 4
    /// Gutter content (line numbers, glyph margin, etc.).
    case gutters = 5
    /// Minimap content.
    case minimap = 6
    /// Full-frame overlays (the topmost layer).
    case overlays = 7
}

// MARK: - MonaRenderOverlay

/// A full-frame overlay painted on the topmost z-layer.
public struct MonaRenderOverlay: Equatable, Sendable {

    /// The overlay rectangle, in tile-local device pixels (Core Graphics native
    /// space: origin at bottom-left, y up).
    public let rect: CGRect

    /// The overlay color.
    public let color: MonaPaintInputs.Color

    /// Creates an overlay.
    public init(rect: CGRect, color: MonaPaintInputs.Color) {
        self.rect = rect
        self.color = color
    }
}

// MARK: - MonaRenderLayerInputs

/// Optional per-tile layer inputs beyond the layout records.
///
/// Layers not supplied are skipped. The layout records carry the text,
/// selection, and decoration data; the cursors/widgets/gutters/minimap/overlays
/// layers are driven by these optional inputs so the renderer can paint a
/// complete frame as the editor pipeline supplies them.
public struct MonaRenderLayerInputs: Equatable, Sendable {

    /// The overlay rectangles painted on the topmost z-layer.
    public var overlays: [MonaRenderOverlay]

    /// Creates layer inputs.
    public init(overlays: [MonaRenderOverlay] = []) {
        self.overlays = overlays
    }
}

// MARK: - MonaCoreGraphicsRenderer

/// The Core Graphics tiled renderer.
///
/// Paints complete immutable `MonaLineLayoutRecord`s into generation-keyed
/// tiles, compositing in the frozen z-order (text → selections → cursors →
/// decorations → widgets → gutters → minimap → overlays) into a linear
/// premultiplied RGBA bitmap. Tiles are cached under `MonaRenderTileKey`
/// (generation + tile-x/y + scale + subpixel phase) so a scale or subpixel
/// change forces a re-rasterization while an unchanged key reuses the cached
/// pixels.
public final class MonaCoreGraphicsRenderer {

    /// The tile cache that bounds memory and evicts LRU without losing
    /// current-generation truth.
    public let tileCache: MonaRenderTileCache

    /// The device-pixel side length of a square tile (default 256).
    public let tileSide: Int

    /// The frozen z-order (bottom → top) this renderer composites in.
    public static let zOrder: [MonaRenderZLayer] = MonaRenderZLayer.allCases

    /// Creates a renderer that caches tiles in `tileCache` and rasterizes
    /// `tileSide`-pixel square tiles.
    public init(tileCache: MonaRenderTileCache, tileSide: Int = 256) {
        precondition(tileSide > 0, "MonaCoreGraphicsRenderer tileSide must be positive")
        self.tileCache = tileCache
        self.tileSide = tileSide
    }

    /// Returns the cached tile for `key` if present; otherwise rasterizes the
    /// visible `records` (positioned at `lineOrigins`, in tile-local device
    /// pixels, Core Graphics native space — origin at the tile's bottom-left,
    /// y up) plus the optional `layerInputs`, caches the result, and returns it.
    ///
    /// The renderer does NOT reshape text: every glyph is read from the frozen
    /// glyph runs on each `MonaLineLayoutRecord`. The scale factor for the
    /// rasterized surface is taken from `key.scale`.
    public func tile(
        for key: MonaRenderTileKey,
        records: [MonaLineLayoutRecord],
        lineOrigins: [CGPoint],
        layerInputs: MonaRenderLayerInputs = .init()
    ) -> MonaRenderTile {
        // Cache hit: reuse the cached tile (no re-rasterization).
        if let cached = tileCache.tile(for: key) {
            return cached
        }

        // Cache miss: rasterize a new tile surface and cache it.
        let surface = MonaRenderSurface(
            width: tileSide,
            height: tileSide,
            scaleFactor: key.scale
        )
        paint(into: surface.bitmapContext, height: tileSide, key: key, records: records,
              lineOrigins: lineOrigins, layerInputs: layerInputs)

        let tile = MonaRenderTile(key: key, surface: surface)
        tileCache.store(tile)
        return tile
    }

    // MARK: - Painting (frozen z-order)

    /// Paints every layer into `ctx` in the frozen z-order.
    private func paint(
        into ctx: CGContext,
        height: Int,
        key: MonaRenderTileKey,
        records: [MonaLineLayoutRecord],
        lineOrigins: [CGPoint],
        layerInputs: MonaRenderLayerInputs
    ) {
        // Apply the subpixel phase as a translation so the same (generation,
        // tile-x/y) rasterized at two phases yields two distinct bitmaps. The
        // phase is applied in device pixels; the CTM is saved/restored so it
        // does not leak across tiles.
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(key.subpixelPhaseX), y: CGFloat(-key.subpixelPhaseY))

        // Layer 0: text (per-line background fill + glyph outlines).
        paintTextLayer(into: ctx, records: records, lineOrigins: lineOrigins)

        // Layer 1: selections (per-line selection ranges).
        paintSelectionsLayer(into: ctx, records: records, lineOrigins: lineOrigins)

        // Layer 2: cursors (no per-record cursor data on the layout record;
        // driven by layer inputs in a future task — painted as a no-op here).
        paintCursorsLayer(into: ctx)

        // Layer 3: decorations (per-record decorations).
        paintDecorationsLayer(into: ctx, records: records, lineOrigins: lineOrigins)

        // Layer 4: widgets (no-op until view-zone widget inputs are wired).
        paintWidgetsLayer(into: ctx)

        // Layer 5: gutters (no-op until gutter inputs are wired).
        paintGuttersLayer(into: ctx)

        // Layer 6: minimap (no-op until minimap inputs are wired).
        paintMinimapLayer(into: ctx)

        // Layer 7: overlays (topmost).
        paintOverlaysLayer(into: ctx, overlays: layerInputs.overlays)

        ctx.restoreGState()
    }

    // MARK: Layer 0 — text

    /// Paints the per-line background fill and the glyph outlines.
    private func paintTextLayer(
        into ctx: CGContext,
        records: [MonaLineLayoutRecord],
        lineOrigins: [CGPoint]
    ) {
        let count = min(records.count, lineOrigins.count)
        for i in 0..<count {
            let record = records[i]
            let origin = lineOrigins[i]

            // Per-line background fill.
            let bgRect = CGRect(
                x: origin.x,
                y: origin.y,
                width: max(record.totalWidth, CGFloat(tileSide)),
                height: record.lineHeight
            )
            ctx.setFillColor(cgColor(from: record.paintInputs.background))
            ctx.fill(bgRect)

            // Glyph outlines.
            let foreground = cgColor(from: record.paintInputs.foreground)
            ctx.setFillColor(foreground)
            // The glyph positions on the record are relative to the line origin
            // with y = baseline (Core Text's native y-up convention). In
            // CG-native space (origin bottom-left, y up) the line origin's y is
            // the line bottom, so the absolute glyph origin is
            // (origin.x + pos.x, origin.y + pos.y).
            for run in record.glyphRuns {
                guard !run.glyphs.isEmpty else { continue }
                let font = run.font
                let positions = run.positions.map { pos -> CGPoint in
                    return CGPoint(x: origin.x + pos.x, y: origin.y + pos.y)
                }
                let glyphs = run.glyphs
                glyphs.withUnsafeBufferPointer { glyphBuf in
                    positions.withUnsafeBufferPointer { posBuf in
                        CTFontDrawGlyphs(
                            font,
                            glyphBuf.baseAddress!,
                            posBuf.baseAddress!,
                            glyphs.count,
                            ctx
                        )
                    }
                }
            }
        }
    }

    // MARK: Layer 1 — selections

    /// Paints the per-line selection range highlights above the text.
    private func paintSelectionsLayer(
        into ctx: CGContext,
        records: [MonaLineLayoutRecord],
        lineOrigins: [CGPoint]
    ) {
        let count = min(records.count, lineOrigins.count)
        // Selection color: a semi-transparent blue distinct from any default
        // foreground/background so the layer is visible in tests.
        let selectionColor = MonaPaintInputs.Color(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.4)
        ctx.setFillColor(cgColor(from: selectionColor))

        for i in 0..<count {
            let record = records[i]
            let origin = lineOrigins[i]
            for selectionRange in record.paintInputs.selectionRanges {
                // Resolve the selection's pixel x-extent from the raw-unit
                // boundaries (no reshaping — pure lookup on the frozen record).
                guard let startX = pixelX(for: selectionRange.lowerBound, in: record),
                      let endX = pixelX(for: selectionRange.upperBound, in: record) else {
                    continue
                }
                let rect = CGRect(
                    x: origin.x + startX,
                    y: origin.y,
                    width: endX - startX,
                    height: record.lineHeight
                )
                ctx.fill(rect)
            }
        }
    }

    // MARK: Layers 2–6 — cursors / decorations / widgets / gutters / minimap

    /// Layer 2 — cursors. The layout record does not carry caret geometry (the
    /// caret is paint-only state, V1-R3 hit 09, and is driven by layer inputs in
    /// a later task). Painted as a no-op so the z-order slot is reserved.
    private func paintCursorsLayer(into ctx: CGContext) { _ = ctx }

    /// Layer 3 — decorations. Paints each decoration's range as a thin underline
    /// rect at the bottom of the line's ascent band.
    private func paintDecorationsLayer(
        into ctx: CGContext,
        records: [MonaLineLayoutRecord],
        lineOrigins: [CGPoint]
    ) {
        let count = min(records.count, lineOrigins.count)
        let decorationColor = MonaPaintInputs.Color(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.8)
        ctx.setFillColor(cgColor(from: decorationColor))

        for i in 0..<count {
            let record = records[i]
            let origin = lineOrigins[i]
            for decoration in record.decorations {
                guard let startX = pixelX(for: decoration.utf16Range.lowerBound, in: record),
                      let endX = pixelX(for: decoration.utf16Range.upperBound, in: record) else {
                    continue
                }
                let underlineHeight: CGFloat = 1
                let rect = CGRect(
                    x: origin.x + startX,
                    y: origin.y,
                    width: endX - startX,
                    height: underlineHeight
                )
                ctx.fill(rect)
            }
        }
    }

    /// Layer 4 — widgets (view-zone widgets). No-op until widget inputs are
    /// wired.
    private func paintWidgetsLayer(into ctx: CGContext) { _ = ctx }

    /// Layer 5 — gutters. No-op until gutter inputs are wired.
    private func paintGuttersLayer(into ctx: CGContext) { _ = ctx }

    /// Layer 6 — minimap. No-op until minimap inputs are wired.
    private func paintMinimapLayer(into ctx: CGContext) { _ = ctx }

    // MARK: Layer 7 — overlays

    /// Paints the topmost overlay rectangles.
    private func paintOverlaysLayer(into ctx: CGContext, overlays: [MonaRenderOverlay]) {
        for overlay in overlays {
            ctx.setFillColor(cgColor(from: overlay.color))
            ctx.fill(overlay.rect)
        }
    }

    // MARK: - Helpers

    /// Resolves a `MonaPaintInputs.Color` to a `CGColor` in the linear RGB
    /// space the surface uses, so primary colors are stored bit-exact (no
    /// sRGB→display-profile color matching). Premultiplication is handled by the
    /// bitmap context (the fill color's RGB is multiplied by alpha at
    /// rasterization because the bitmap is `premultipliedLast`).
    private func cgColor(from color: MonaPaintInputs.Color) -> CGColor {
        let space = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
        let components: [CGFloat] = [color.red, color.green, color.blue, color.alpha]
        return CGColor(colorSpace: space, components: components)!
    }

    /// Returns the device-space x position (relative to the line origin) of a
    /// UTF-16 offset, by looking up the frozen raw-unit boundaries. Returns
    /// `nil` if the offset cannot be resolved (e.g. empty line).
    ///
    /// This is a pure lookup on the frozen record — no reshaping.
    private func pixelX(for offset: Int, in record: MonaLineLayoutRecord) -> CGFloat? {
        guard !record.rawUnitBoundaries.isEmpty else { return nil }
        if offset <= record.rawUnitBoundaries.first!.utf16Range.lowerBound {
            return record.rawUnitBoundaries.first!.startX
        }
        if offset >= record.rawUnitBoundaries.last!.utf16Range.upperBound {
            return record.rawUnitBoundaries.last!.endX
        }
        // Linear scan (boundaries are small per line and sorted by x).
        for boundary in record.rawUnitBoundaries {
            if boundary.utf16Range.lowerBound == offset {
                return boundary.startX
            }
            if boundary.utf16Range.upperBound == offset {
                return boundary.endX
            }
        }
        // Fallback: find the boundary whose range contains `offset`.
        for boundary in record.rawUnitBoundaries {
            if boundary.utf16Range.contains(offset) {
                return boundary.startX
            }
        }
        return nil
    }
}
