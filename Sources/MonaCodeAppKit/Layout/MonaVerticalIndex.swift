// MonaVerticalIndex.swift
//
// P03-T001 — Build ViewGraph projection and logarithmic vertical indexes.
//
// `MonaVerticalIndex` is the logarithmic prefix-height index over the vertical
// layout of one projection generation. It answers two core queries in O(log n)
// WITHOUT a full-document scan:
//   - `verticalOffsetForViewLine(L)` — the top pixel offset of view line L.
//   - `viewLineAtVerticalOffset(offset)` — the view line containing the offset.
//
// The layout is modeled as a flat sequence of "segments". A segment is either:
//   - a view line (height = the configured line height), or
//   - a view zone (height = the zone's pixel height), positioned after its
//     owner view line.
// Each segment stores its pixel height and the 1-based view line it belongs to
// (a view line segment owns itself; a zone segment owns the line above it, so
// an offset that falls in a zone gap maps to the line above the gap).
//
// A segment tree (iterative, perfect-binary) over the segment heights provides
// O(log n) prefix-sum queries and O(log n) descent for offset->line lookup.
// `queryCount` and `scannedNodeCount` instrument the work so callers can prove
// the index is sub-linear (no full-document scans).
//
// MonaCodeAppKit may import AppKit/CoreGraphics; this file keeps imports
// minimal (Foundation only — offsets and heights are plain `Int` pixels).

import Foundation

/// A logarithmic prefix-height index over one projection's vertical layout.
///
/// Built by `MonaViewGraph` during a projection rebuild. Immutable once built;
/// a new projection produces a new index. All queries are O(log n) in the
/// number of layout segments and touch only a logarithmic number of tree nodes.
public final class MonaVerticalIndex {

    /// A single vertical-layout segment: a view line or a view zone gap.
    private struct Segment {
        /// Pixel height of the segment.
        let height: Int
        /// The 1-based view line this segment belongs to. For a view-line
        /// segment this is the line itself; for a zone segment this is the
        /// view line above the gap (the line the zone is positioned after).
        let ownerViewLine: Int
    }

    /// The segments in document order.
    private let segments: [Segment]

    /// Maps a 1-based view line number to its segment index in `segments`.
    private let segmentIndexForViewLine: [Int: Int]

    /// The perfect-binary segment tree size (next power of two >= segment count).
    private let size: Int

    /// The segment tree. Leaves live at `[size, size+n)`; internal node `i`
    /// stores the sum of its two children. `tree[0]` is unused.
    private let tree: [Int]

    /// The number of view lines in the projection.
    public let viewLineCount: Int

    /// The total document height (sum of all segment heights).
    public private(set) var totalHeight: Int = 0

    /// Cumulative query counter (incremented once per public query).
    public private(set) var queryCount: Int = 0

    /// Cumulative tree-node-access counter (the logarithmic-complexity witness).
    public private(set) var scannedNodeCount: Int = 0

    /// Creates an index from `viewLines` (in order), a per-view-line `lineHeight`,
    /// and the `zones` positioned after visible model lines.
    ///
    /// Zones whose `afterLineNumber` matches a view line's `modelLineNumber` are
    /// inserted as gap segments immediately after that view line. Zones after
    /// hidden model lines (no matching view line) are dropped.
    public init(viewLines: [MonaViewLine], lineHeight: Int, zones: [MonaViewZone]) {
        var segs: [Segment] = []
        var idxForLine: [Int: Int] = [:]
        segs.reserveCapacity(viewLines.count + zones.count)

        for (i, vl) in viewLines.enumerated() {
            let viewLine = i + 1
            idxForLine[viewLine] = segs.count
            segs.append(Segment(height: lineHeight, ownerViewLine: viewLine))
            // Emit zones positioned after this view line's model line.
            for z in zones where z.afterLineNumber == vl.modelLineNumber {
                segs.append(Segment(height: z.height, ownerViewLine: viewLine))
            }
        }

        self.segments = segs
        self.segmentIndexForViewLine = idxForLine
        self.viewLineCount = viewLines.count

        // Build the perfect-binary segment tree.
        let n = segs.count
        var s = 1
        while s < n { s <<= 1 }
        if s < 1 { s = 1 }
        self.size = s
        var t = [Int](repeating: 0, count: 2 * s)
        for i in 0..<n {
            t[s + i] = segs[i].height
        }
        var i = s - 1
        while i >= 1 {
            t[i] = t[2 * i] + t[2 * i + 1]
            i -= 1
        }
        self.tree = t
        self.totalHeight = t[1]
    }

    /// Creates an empty index.
    public convenience init() {
        self.init(viewLines: [], lineHeight: 0, zones: [])
    }

    /// Returns the top pixel offset of view line `viewLine` (1-based).
    /// O(log n). Returns 0 for out-of-range inputs.
    public func verticalOffsetForViewLine(_ viewLine: Int) -> Int {
        queryCount += 1
        guard let segIdx = segmentIndexForViewLine[viewLine] else { return 0 }
        return prefixSum(upTo: segIdx)
    }

    /// Returns the 1-based view line containing `offset`. An offset that falls
    /// in a zone gap maps to the view line ABOVE the gap. Offsets at or beyond
    /// the total height clamp to the last view line.
    /// O(log n).
    public func viewLineAtVerticalOffset(_ offset: Int) -> Int {
        queryCount += 1
        guard !segments.isEmpty else { return 0 }
        if offset >= totalHeight {
            // Clamp to the last view line's owner.
            return lastViewLineOwner()
        }
        let off = max(offset, 0)
        let leaf = findContainingSegment(off)
        return segments[leaf].ownerViewLine
    }

    // MARK: - Private: segment tree operations

    /// Prefix sum of segment heights for segments `[0, k)`. O(log n).
    private func prefixSum(upTo k: Int) -> Int {
        var result = 0
        var l = size
        var r = size + k
        while l < r {
            if l & 1 != 0 {
                result += tree[l]
                scannedNodeCount += 1
                l += 1
            }
            if r & 1 != 0 {
                r -= 1
                result += tree[r]
                scannedNodeCount += 1
            }
            l >>= 1
            r >>= 1
        }
        return result
    }

    /// Descends the tree to the leaf segment whose height range contains
    /// `offset` (the largest leaf whose prefix sum strictly exceeds `offset`).
    /// O(log n).
    private func findContainingSegment(_ offset: Int) -> Int {
        // Guard against zero-height layouts.
        guard totalHeight > 0 else { return max(segments.count - 1, 0) }
        var node = 1
        var remaining = offset
        while node < size {
            let left = 2 * node
            scannedNodeCount += 1
            if tree[left] > remaining {
                node = left
            } else {
                remaining -= tree[left]
                node = left + 1
            }
        }
        var leafIdx = node - size
        if leafIdx >= segments.count {
            leafIdx = segments.count - 1
        }
        if leafIdx < 0 { leafIdx = 0 }
        return leafIdx
    }

    /// Returns the owner view line of the last layout segment. The last segment
    /// is either a view-line segment (owns itself) or a zone segment after the
    /// last view line (still owns that last view line), so its owner is correct.
    private func lastViewLineOwner() -> Int {
        guard let last = segments.last else { return viewLineCount }
        return last.ownerViewLine
    }
}
