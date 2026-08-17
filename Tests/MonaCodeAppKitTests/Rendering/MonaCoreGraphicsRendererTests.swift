// MonaCoreGraphicsRendererTests.swift
//
// P03-T006 — Complete the correct Core Graphics tiled renderer.
//
// Verifies the Core Graphics tiled renderer that paints complete immutable
// `MonaLineLayoutRecord`s (P03-T003) into generation-keyed tiles:
//   - MonaRenderSurface          — the render target (CGContext wrapper, bitmap
//                                  context, dimensions, scale factor) using
//                                  linear premultiplied RGBA.
//   - MonaRenderTileCache       — generation-keyed tile cache, bounded memory,
//                                  LRU eviction without losing current-
//                                  generation truth (current-generation tiles
//                                  are never evicted).
//   - MonaCoreGraphicsRenderer  — paints layout records into tiles, compositing
//                                  text → selections → cursors → decorations →
//                                  widgets → gutters → minimap → overlays in
//                                  frozen z-order. Scale + subpixel phase are
//                                  part of every cache key.
//
// The renderer does NOT reshape text: it reads the frozen glyph runs from the
// immutable layout record and paints them into a CGContext.
//
// One contract case: tiled CG renderer paints records into generation-keyed
// tiles in frozen z-order with premultiplied RGBA + scale/phase keys.

import XCTest
import CoreGraphics
import CoreText
@testable import MonaCodeAppKit

final class MonaCoreGraphicsRendererTests: XCTestCase {

    // MARK: - Helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    private func utf16(_ string: String) -> [UInt16] {
        return Array(string.utf16)
    }

    private func makeBuilder(scale: CGFloat = 1, direction: MonaTextDirection = .ltr) -> MonaLineLayoutBuilder {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: direction, scale: scale)
        return MonaLineLayoutBuilder(shaper: shaper)
    }

    private func makeRecord(
        text: String,
        foreground: MonaPaintInputs.Color = MonaPaintInputs.Color(red: 0, green: 0, blue: 0),
        background: MonaPaintInputs.Color = MonaPaintInputs.Color(red: 1, green: 1, blue: 1),
        selectionRanges: [Range<Int>] = [],
        scale: CGFloat = 1
    ) throws -> MonaLineLayoutRecord {
        let builder = makeBuilder(scale: scale)
        let stamp = builder.makeDependencyStamp()
        let paint = MonaPaintInputs(
            foreground: foreground,
            background: background,
            selectionRanges: selectionRanges
        )
        return try builder.build(codeUnits: utf16(text), paintInputs: paint, dependencyStamp: stamp)
    }

    // MARK: - MonaRenderSurface: premultiplied RGBA + dimensions

    func testMonaRenderSurface_UsesPremultipliedRGBAWithDimensionsAndScale() {
        let surface = MonaRenderSurface(width: 32, height: 24, scaleFactor: 2)

        XCTAssertEqual(surface.width, 32)
        XCTAssertEqual(surface.height, 24)
        XCTAssertEqual(surface.scaleFactor, 2)
        XCTAssertNotNil(surface.bitmapContext)
        // The backing bitmap uses premultiplied alpha (linear premultiplied
        // RGBA) for correct compositing.
        let alphaInfo = CGImageAlphaInfo(
            rawValue: surface.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        )
        XCTAssertEqual(alphaInfo, .premultipliedLast)
        // bytesPerRow is at least width * 4 (32-bit RGBA).
        XCTAssertGreaterThanOrEqual(surface.bytesPerRow, surface.width * 4)
    }

    // MARK: - MonaRenderTileCache: generation-keyed, bounded, LRU, current-gen protection

    func testMonaRenderTileCache_GenerationKeyedLRUWithCurrentGenerationProtection() {
        let cache = MonaRenderTileCache(maxTileCount: 3, maxBytes: Int.max)
        let side = 4

        // A helper that makes a distinct 4x4 surface-backed tile.
        func tile(_ key: MonaRenderTileKey) -> MonaRenderTile {
            let surface = MonaRenderSurface(width: side, height: side, scaleFactor: 1)
            return MonaRenderTile(key: key, surface: surface)
        }

        // --- Generation-keyed storage: same (tileX,tileY) at two generations
        // are distinct slots.
        cache.setCurrentGeneration(1)
        let keyA1 = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        let keyA2 = MonaRenderTileKey(generation: 2, tileX: 0, tileY: 0, scale: 1)
        cache.store(tile(keyA1))
        cache.store(tile(keyA2))
        XCTAssertNotNil(cache.tile(for: keyA1), "gen-1 tile must be retrievable")
        XCTAssertNotNil(cache.tile(for: keyA2), "gen-2 tile at same (x,y) is a distinct slot")
        XCTAssertEqual(cache.tileCount, 2)

        // --- No false hit: a key never stored returns nil.
        let keyMissing = MonaRenderTileKey(generation: 1, tileX: 9, tileY: 9, scale: 1)
        XCTAssertNil(cache.tile(for: keyMissing))

        // --- Explicit invalidation: invalidate(olderThanGeneration:) removes
        // stale-generation tiles ("when the generation changes, old tiles are
        // invalidated").
        let removed = cache.invalidate(olderThanGeneration: 2)
        XCTAssertEqual(removed, 1, "gen-1 tile invalidated; gen-2 retained")
        XCTAssertNil(cache.tile(for: keyA1))
        XCTAssertNotNil(cache.tile(for: keyA2))
        XCTAssertEqual(cache.tileCount, 1)

        // --- LRU eviction of non-current-generation tiles: fill the cache with
        // gen-2 tiles, advance the current generation to 3 (gen-2 tiles become
        // evictable), then store a gen-3 tile and observe LRU eviction.
        cache.setCurrentGeneration(2)
        let k0 = MonaRenderTileKey(generation: 2, tileX: 0, tileY: 0, scale: 1)
        let k1 = MonaRenderTileKey(generation: 2, tileX: 1, tileY: 0, scale: 1)
        let k2 = MonaRenderTileKey(generation: 2, tileX: 2, tileY: 0, scale: 1)
        cache.store(tile(k0))
        cache.store(tile(k1))
        cache.store(tile(k2))
        XCTAssertEqual(cache.tileCount, 3)
        // Touch k0 so k1 becomes the least-recently-used gen-2 tile.
        _ = cache.tile(for: k0)
        // Advance generation: gen-2 tiles are now non-current (evictable).
        cache.setCurrentGeneration(3)
        let k3 = MonaRenderTileKey(generation: 3, tileX: 3, tileY: 0, scale: 1)
        cache.store(tile(k3))
        // Capacity is 3; the LRU evictable (gen-2) tile (k1) must have been
        // evicted to make room for k3.
        XCTAssertNil(cache.tile(for: k1), "LRU non-current-gen tile evicted")
        XCTAssertNotNil(cache.tile(for: k0), "recently-used gen-2 tile retained")
        XCTAssertNotNil(cache.tile(for: k2), "gen-2 tile retained (not LRU)")
        XCTAssertNotNil(cache.tile(for: k3), "new current-gen tile stored")
        XCTAssertEqual(cache.tileCount, 3)

        // --- Current-generation tiles are NEVER evicted, even over capacity.
        // First drop the remaining gen-2 (evictable) tiles so the cache holds
        // only current-gen (gen-3) truth.
        cache.invalidate(olderThanGeneration: 3)
        // Only k3 (gen-3) remains now.
        // Fill with current-gen (gen-3) tiles beyond capacity — none are
        // evictable, so the cache must accept going over-budget rather than
        // lose current-generation truth.
        let k4 = MonaRenderTileKey(generation: 3, tileX: 4, tileY: 0, scale: 1)
        let k5 = MonaRenderTileKey(generation: 3, tileX: 5, tileY: 0, scale: 1)
        let k6 = MonaRenderTileKey(generation: 3, tileX: 6, tileY: 0, scale: 1)
        cache.store(tile(k4))
        cache.store(tile(k5))
        XCTAssertEqual(cache.tileCount, cache.maxTileCount)
        cache.store(tile(k6))
        // All four current-gen tiles must survive (no current-gen eviction).
        XCTAssertNotNil(cache.tile(for: k3))
        XCTAssertNotNil(cache.tile(for: k4))
        XCTAssertNotNil(cache.tile(for: k5))
        XCTAssertNotNil(cache.tile(for: k6))
        XCTAssertGreaterThan(cache.tileCount, cache.maxTileCount,
            "current-generation truth preserved even when over capacity")
    }

    // MARK: - MonaCoreGraphicsRenderer: paint + z-order + scale/phase keys

    func testMonaCoreGraphicsRenderer_PaintsRecordsIntoTilesInFrozenZOrderWithScaleAndPhaseKeys() throws {
        let cache = MonaRenderTileCache(maxTileCount: 64, maxBytes: Int.max)
        let renderer = MonaCoreGraphicsRenderer(tileCache: cache, tileSide: 64)

        // --- Frozen z-order (bottom -> top): text, selections, cursors,
        // decorations, widgets, gutters, minimap, overlays.
        XCTAssertEqual(
            MonaCoreGraphicsRenderer.zOrder,
            [.text, .selections, .cursors, .decorations, .widgets, .gutters, .minimap, .overlays]
        )

        // --- Background layer (part of the text layer base) is painted: a
        // record with a blue background fills the tile with blue.
        let blueRecord = try makeRecord(
            text: "MMMMMMMM",
            background: MonaPaintInputs.Color(red: 0, green: 0, blue: 1)
        )
        let baseKey = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        let baseTile = renderer.tile(
            for: baseKey,
            records: [blueRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        // The tile's surface is the premultiplied RGBA target.
        let baseAlpha = CGImageAlphaInfo(
            rawValue: baseTile.surface.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        )
        XCTAssertEqual(baseAlpha, .premultipliedLast)
        // At least one pixel must be the blue background (0,0,255,255). A small
        // tolerance covers sub-LSB rounding in the linear-RGB rasterization.
        XCTAssertTrue(
            containsPixel(in: baseTile.surface, r: 0, g: 0, b: 255, a: 255, tolerance: 2),
            "background layer must paint blue pixels"
        )

        // --- Text layer composites above background: a record with white
        // background + black text produces both white and black pixels.
        let textRecord = try makeRecord(
            text: "MMMMMMMMMMMMMMMM",
            foreground: MonaPaintInputs.Color(red: 0, green: 0, blue: 0),
            background: MonaPaintInputs.Color(red: 1, green: 1, blue: 1)
        )
        let textKey = MonaRenderTileKey(generation: 1, tileX: 1, tileY: 0, scale: 1)
        let textTile = renderer.tile(
            for: textKey,
            records: [textRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        XCTAssertTrue(
            containsPixel(in: textTile.surface, r: 255, g: 255, b: 255, a: 255, tolerance: 2),
            "white background must be present"
        )
        XCTAssertTrue(
            containsPixel(in: textTile.surface, r: 0, g: 0, b: 0, a: 255, tolerance: 2),
            "black text glyphs must composite above the background"
        )

        // --- Overlay layer composites LAST (on top of text): a full-tile red
        // overlay fully obscures the text underneath, proving the frozen z-order
        // (overlays above text).
        let overlay = MonaRenderOverlay(
            rect: CGRect(x: 0, y: 0, width: 64, height: 64),
            color: MonaPaintInputs.Color(red: 1, green: 0, blue: 0)
        )
        let overlayKey = MonaRenderTileKey(generation: 1, tileX: 2, tileY: 0, scale: 1)
        let overlayTile = renderer.tile(
            for: overlayKey,
            records: [textRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)],
            layerInputs: MonaRenderLayerInputs(overlays: [overlay])
        )
        // Every sampled pixel must be red (overlay on top).
        XCTAssertTrue(
            allPixelsAre(in: overlayTile.surface, r: 255, g: 0, b: 0, a: 255, tolerance: 2),
            "overlay (top z-layer) must composite above text"
        )

        // --- Cache hit: re-rendering the same key returns the cached tile
        // without growing the cache.
        let countBefore = cache.tileCount
        _ = renderer.tile(
            for: baseKey,
            records: [blueRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        XCTAssertEqual(cache.tileCount, countBefore, "cache hit must not grow the cache")

        // --- Scale is part of the cache key: a different scale is a miss.
        let scale2Key = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 2)
        _ = renderer.tile(
            for: scale2Key,
            records: [blueRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        XCTAssertEqual(cache.tileCount, countBefore + 1, "different scale => cache miss")

        // --- Subpixel phase is part of the cache key: a different phase is a
        // miss.
        let phaseKey = MonaRenderTileKey(
            generation: 1, tileX: 0, tileY: 0, scale: 1, subpixelPhaseX: 1, subpixelPhaseY: 0
        )
        _ = renderer.tile(
            for: phaseKey,
            records: [blueRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        XCTAssertEqual(cache.tileCount, countBefore + 2, "different subpixel phase => cache miss")

        // --- Generation-keyed: a tile stored under generation 1 is not
        // returned for generation 2.
        let gen2Key = MonaRenderTileKey(generation: 2, tileX: 0, tileY: 0, scale: 1)
        let gen2Tile = renderer.tile(
            for: gen2Key,
            records: [blueRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        XCTAssertFalse(gen2Tile === baseTile, "different generation => distinct tile (no false hit)")
    }

    // MARK: - Pixel sampling helpers

    /// Returns `true` if at least one pixel in `surface` equals the given
    /// premultiplied RGBA byte tuple (within `tolerance`).
    private func containsPixel(
        in surface: MonaRenderSurface,
        r: UInt8, g: UInt8, b: UInt8, a: UInt8,
        tolerance: UInt8 = 0
    ) -> Bool {
        for y in 0..<surface.height {
            for x in 0..<surface.width {
                let p = surface.pixelAt(x: x, y: y)
                guard let p = p else { continue }
                if matches(p, r, g, b, a, tolerance: tolerance) {
                    return true
                }
            }
        }
        return false
    }

    /// Returns `true` if every pixel in `surface` equals the given premultiplied
    /// RGBA byte tuple (within `tolerance`).
    private func allPixelsAre(
        in surface: MonaRenderSurface,
        r: UInt8, g: UInt8, b: UInt8, a: UInt8,
        tolerance: UInt8 = 0
    ) -> Bool {
        for y in 0..<surface.height {
            for x in 0..<surface.width {
                guard let p = surface.pixelAt(x: x, y: y) else { return false }
                if !matches(p, r, g, b, a, tolerance: tolerance) {
                    return false
                }
            }
        }
        return true
    }

    private func matches(
        _ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
        _ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8,
        tolerance: UInt8
    ) -> Bool {
        return abs(Int(p.r) - Int(r)) <= Int(tolerance)
            && abs(Int(p.g) - Int(g)) <= Int(tolerance)
            && abs(Int(p.b) - Int(b)) <= Int(tolerance)
            && abs(Int(p.a) - Int(a)) <= Int(tolerance)
    }
}
