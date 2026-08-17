// MonaViewZoneIndex.swift
//
// P03-T001 — Build ViewGraph projection and logarithmic vertical indexes.
//
// A view zone is an inserted visual block positioned between two view lines
// (after a given model line). `MonaViewZone` is the value type describing one
// zone; `MonaViewZoneIndex` is the index that lets the projection answer
// "which zones sit between line A and line B?" and "what total height do the
// zones before a given line contribute?" without scanning the whole zone list.
//
// The index stores zones sorted by `afterLineNumber` and a prefix-height array
// keyed by model line number, so:
//   - `zones(afterLine:)` is O(log n + k) where k is the result size.
//   - `prefixHeight(afterLine:)` is O(log n).
//
// MonaCodeAppKit may import AppKit/CoreGraphics; this file keeps imports
// minimal (Foundation only — zone heights are plain `Int` pixels).

import Foundation

/// A view zone: an inserted visual block positioned after a model line.
///
/// Ported from Monaco's `IViewZone`. `afterLineNumber` is a 1-based model line
/// number; the zone is rendered in the whitespace between that line and the
/// next visible line. `height` is the zone's pixel height.
public struct MonaViewZone: Equatable, Hashable {

    /// A stable identifier for the zone (unique within one projection).
    public let id: String

    /// The 1-based model line number after which this zone is positioned.
    public let afterLineNumber: Int

    /// The zone's pixel height.
    public let height: Int

    /// Creates a view zone.
    public init(id: String, afterLineNumber: Int, height: Int) {
        self.id = id
        self.afterLineNumber = afterLineNumber
        self.height = max(height, 0)
    }
}

/// An index over the view zones of one projection generation.
///
/// Built by `MonaViewGraph` during a projection rebuild. Stores zones sorted by
/// `afterLineNumber` plus a prefix-height structure for O(log n) queries. The
/// index is immutable once built; a new projection produces a new index.
public final class MonaViewZoneIndex {

    /// All zones in the projection, sorted by `afterLineNumber` then `id`.
    public private(set) var zones: [MonaViewZone]

    /// Zones sorted by `afterLineNumber`.
    private let sortedByLine: [MonaViewZone]

    /// The `afterLineNumber` values of `sortedByLine` (for binary search).
    private let lineKeys: [Int]

    /// Prefix heights aligned with `sortedByLine`: `prefixHeights[i]` is the
    /// total height of zones `0..<i`.
    private let prefixHeights: [Int]

    /// Creates an index over `zones`, retaining only zones whose
    /// `afterLineNumber` is in `visibleLines` (zones after hidden lines are
    /// dropped, per Monaco's behavior). Pass an empty `visibleLines` to drop
    /// all zones.
    public init(zones: [MonaViewZone], visibleLines: Set<Int> = []) {
        let filtered = zones.filter { visibleLines.contains($0.afterLineNumber) }
        let sorted = filtered.sorted { a, b in
            if a.afterLineNumber != b.afterLineNumber {
                return a.afterLineNumber < b.afterLineNumber
            }
            return a.id < b.id
        }
        self.zones = sorted
        self.sortedByLine = sorted
        self.lineKeys = sorted.map(\.afterLineNumber)

        var prefixes = [Int](repeating: 0, count: sorted.count + 1)
        for i in 0..<sorted.count {
            prefixes[i + 1] = prefixes[i] + sorted[i].height
        }
        self.prefixHeights = prefixes
    }

    /// The zones positioned after `lineNumber` (1-based model line).
    public func zones(afterLine lineNumber: Int) -> [MonaViewZone] {
        // Binary search for the first zone with afterLineNumber == lineNumber.
        let lower = firstIndexWhere { $0 >= lineNumber } ?? sortedByLine.count
        var result: [MonaViewZone] = []
        var i = lower
        while i < sortedByLine.count && sortedByLine[i].afterLineNumber == lineNumber {
            result.append(sortedByLine[i])
            i += 1
        }
        return result
    }

    /// The total height of all zones positioned strictly before `lineNumber`
    /// (i.e. zones with `afterLineNumber < lineNumber`). O(log n).
    public func prefixHeight(beforeLineNumber lineNumber: Int) -> Int {
        // Find the first index whose afterLineNumber >= lineNumber.
        let idx = firstIndexWhere { $0 >= lineNumber } ?? sortedByLine.count
        return prefixHeights[idx]
    }

    /// The total height of all zones in the projection.
    public var totalHeight: Int {
        return prefixHeights[sortedByLine.count]
    }

    /// The number of zones in the index.
    public var count: Int {
        return sortedByLine.count
    }

    // MARK: - Private

    /// Returns the smallest index into `lineKeys` whose value satisfies the
    /// predicate, or `nil` if none. `lineKeys` is sorted ascending.
    private func firstIndexWhere(_ predicate: (Int) -> Bool) -> Int? {
        var lo = 0
        var hi = lineKeys.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if predicate(lineKeys[mid]) {
                hi = mid
            } else {
                lo = mid + 1
            }
        }
        return lo < lineKeys.count ? lo : nil
    }
}
