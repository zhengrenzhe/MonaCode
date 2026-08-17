// MonaRenderTileCache.swift
//
// P03-T006 — Complete the correct Core Graphics tiled renderer.
//
// `MonaRenderTileCache` is the generation-keyed tile cache for the Core
// Graphics tiled renderer. Each tile is stored under a `MonaRenderTileKey`
// that captures (generation, tile-x, tile-y, scale, subpixel-phase-x,
// subpixel-phase-y). The cache is bounded by both a maximum tile count and a
// maximum byte budget; when a store would exceed either bound, the cache
// evicts the least-recently-used evictable tile.
//
// Eviction rule (the P03-T006 invariant):
//   - Tiles whose `key.generation == currentGeneration` are NEVER evicted. They
//     are the current-generation truth and must survive LRU pressure so a
//     composited frame never reads a torn (half-invalidated) tile.
//   - Tiles whose `key.generation != currentGeneration` are evictable and are
//     the LRU candidates. When the generation advances, the caller invokes
//     `invalidate(olderThanGeneration:)` (or `setCurrentGeneration(_:)` plus
//     invalidation) to drop stale tiles — "when the generation changes, old
//     tiles are invalidated."
//   - If the cache is over budget and only current-generation tiles remain,
//     the cache accepts the over-budget state rather than evicting truth.
//
// `MonaRenderTile` wraps a `MonaRenderSurface` (the painted pixels) plus its
// key and a byte count for budget accounting.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreGraphics + Foundation.

import Foundation
import CoreGraphics

// MARK: - MonaRenderTileKey

/// The cache key for a rendered tile.
///
/// Captures every input that defines a tile's rasterized identity: the
/// generation (projection/geometry/paint generation), the tile's device-space
/// column/row, the rasterization scale, and the subpixel phase. Two keys are
/// equal only when every field matches, so a change to the scale or subpixel
/// phase forces a cache miss (re-rasterization) even when the tile's
/// (generation, tile-x, tile-y) is unchanged.
public struct MonaRenderTileKey: Equatable, Hashable, Sendable {

    /// The generation this tile was rasterized for.
    public let generation: Int

    /// The tile's device-space column (tile `tileX` covers pixels
    /// `[tileX * tileSide, (tileX + 1) * tileSide)`).
    public let tileX: Int

    /// The tile's device-space row.
    public let tileY: Int

    /// The rasterization scale factor (e.g. 2.0 for Retina).
    public let scale: CGFloat

    /// The horizontal subpixel phase (0 ... `scale - 1` for a `scale`-factor
    /// surface). Tiles at the same (generation, tileX, tileY, scale) but
    /// different subpixel phase are distinct rasterizations.
    public let subpixelPhaseX: Int

    /// The vertical subpixel phase.
    public let subpixelPhaseY: Int

    /// Creates a tile key.
    public init(
        generation: Int,
        tileX: Int,
        tileY: Int,
        scale: CGFloat,
        subpixelPhaseX: Int = 0,
        subpixelPhaseY: Int = 0
    ) {
        self.generation = generation
        self.tileX = tileX
        self.tileY = tileY
        self.scale = scale
        self.subpixelPhaseX = subpixelPhaseX
        self.subpixelPhaseY = subpixelPhaseY
    }
}

// MARK: - MonaRenderTile

/// A cached rendered tile: the painted `MonaRenderSurface` plus its cache key.
///
/// The byte count (for budget accounting) is derived from the surface's
/// premultiplied RGBA bitmap (width × height × 4 bytes).
public final class MonaRenderTile {

    /// The cache key this tile was stored under.
    public let key: MonaRenderTileKey

    /// The painted render surface (owns the premultiplied RGBA pixels).
    public let surface: MonaRenderSurface

    /// The number of bytes the tile's bitmap occupies (`width × height × 4`).
    public var byteCount: Int {
        return surface.width * surface.height * 4
    }

    /// Creates a tile wrapping `surface` stored under `key`.
    public init(key: MonaRenderTileKey, surface: MonaRenderSurface) {
        self.key = key
        self.surface = surface
    }
}

// MARK: - MonaRenderTileCache

/// A generation-keyed, bounded-memory tile cache with LRU eviction that never
/// loses current-generation truth.
///
/// Tiles are stored under `MonaRenderTileKey` (generation + tile-x/y + scale +
/// subpixel phase). The cache is bounded by `maxTileCount` and `maxBytes`; when
/// a `store(_:)` would exceed either bound, the least-recently-used evictable
/// tile is evicted. A tile is evictable iff its `key.generation !=
/// currentGeneration` — current-generation tiles are never evicted, so a
/// composited frame never reads a torn tile. If the cache is over budget and
/// only current-generation tiles remain, the over-budget state is accepted.
///
/// Stale tiles (old generation) are removed explicitly via
/// `invalidate(olderThanGeneration:)`; this is the "when the generation changes,
/// old tiles are invalidated" path.
public final class MonaRenderTileCache {

    /// An entry in the cache: the tile plus its LRU recency stamp.
    private final class Entry {
        let tile: MonaRenderTile
        var recency: UInt64
        init(tile: MonaRenderTile, recency: UInt64) {
            self.tile = tile
            self.recency = recency
        }
    }

    /// The stored entries keyed by tile key.
    private var entries: [MonaRenderTileKey: Entry] = [:]

    /// The monotonic LRU recency counter (bumped on every access/store).
    private var recencyCounter: UInt64 = 0

    /// The current generation. Tiles whose `key.generation == currentGeneration`
    /// are protected from eviction.
    public private(set) var currentGeneration: Int = 0

    /// The maximum number of tiles the cache holds before evicting.
    public let maxTileCount: Int

    /// The maximum number of bytes the cache holds before evicting.
    public let maxBytes: Int

    /// Creates a cache bounded by `maxTileCount` and `maxBytes`.
    public init(maxTileCount: Int, maxBytes: Int) {
        precondition(maxTileCount > 0, "MonaRenderTileCache maxTileCount must be positive")
        precondition(maxBytes > 0, "MonaRenderTileCache maxBytes must be positive")
        self.maxTileCount = maxTileCount
        self.maxBytes = maxBytes
    }

    /// The number of tiles currently cached.
    public var tileCount: Int { entries.count }

    /// The total bytes currently cached.
    public var bytesUsed: Int {
        var total = 0
        for entry in entries.values {
            total += entry.tile.byteCount
        }
        return total
    }

    // MARK: - Generation management

    /// Sets the current generation. Does NOT immediately remove old-generation
    /// tiles — they become evictable (LRU candidates). To drop stale tiles
    /// explicitly, call `invalidate(olderThanGeneration:)`.
    public func setCurrentGeneration(_ generation: Int) {
        currentGeneration = generation
    }

    /// Removes every tile whose `key.generation` is strictly less than
    /// `generation` and returns the number removed. This is the "when the
    /// generation changes, old tiles are invalidated" path.
    @discardableResult
    public func invalidate(olderThanGeneration generation: Int) -> Int {
        var removed = 0
        for (key, _) in entries where key.generation < generation {
            entries.removeValue(forKey: key)
            removed += 1
        }
        return removed
    }

    /// Removes every tile whose `key.generation` equals `generation` and returns
    /// the number removed.
    @discardableResult
    public func invalidate(generation: Int) -> Int {
        var removed = 0
        for (key, _) in entries where key.generation == generation {
            entries.removeValue(forKey: key)
            removed += 1
        }
        return removed
    }

    /// Removes all cached tiles.
    public func invalidateAll() {
        entries.removeAll()
    }

    // MARK: - Access

    /// Returns the cached tile for `key`, bumping its LRU recency, or `nil` if
    /// no tile is cached for that key.
    public func tile(for key: MonaRenderTileKey) -> MonaRenderTile? {
        guard let entry = entries[key] else { return nil }
        recencyCounter &+= 1
        entry.recency = recencyCounter
        return entry.tile
    }

    /// Stores `tile` under its key, replacing any existing tile for that key.
    /// Then evicts LRU evictable (non-current-generation) tiles until the cache
    /// is within both bounds OR no evictable tiles remain. Current-generation
    /// tiles are never evicted, so the cache may end up over budget when only
    /// current-generation truth remains.
    public func store(_ tile: MonaRenderTile) {
        recencyCounter &+= 1
        let key = tile.key
        // Replace or insert.
        entries[key] = Entry(tile: tile, recency: recencyCounter)

        // Evict LRU evictable tiles until within both bounds or no evictable
        // tiles remain.
        while (entries.count > maxTileCount || bytesUsed > maxBytes) {
            guard let evictKey = leastRecentlyUsedEvictableKey() else {
                // Only current-generation tiles remain; preserve truth and
                // accept the over-budget state.
                return
            }
            entries.removeValue(forKey: evictKey)
        }
    }

    // MARK: - Private

    /// Returns the key of the least-recently-used tile whose generation differs
    /// from `currentGeneration`, or `nil` if no tile is evictable.
    private func leastRecentlyUsedEvictableKey() -> MonaRenderTileKey? {
        var lruKey: MonaRenderTileKey?
        var lruRecency: UInt64 = .max
        for (key, entry) in entries {
            if key.generation == currentGeneration { continue }
            if entry.recency < lruRecency {
                lruRecency = entry.recency
                lruKey = key
            }
        }
        return lruKey
    }
}
