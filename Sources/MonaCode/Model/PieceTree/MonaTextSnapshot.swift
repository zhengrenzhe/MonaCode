// MonaTextSnapshot.swift
//
// P01-T007 — Port the Piece Tree over raw UInt16 storage.
//
// `MonaTextSnapshot` is an immutable capture of the Piece Tree's text at a
// point in time. It materializes the full `[UInt16]` text plus its line-feed
// offsets when created, so subsequent edits to the live tree never affect it.
// The snapshot answers the same text/line/offset/position queries as the live
// tree, but over the frozen flat copy.
//
// Raw UTF-16 storage is preserved: the materialized `[UInt16]` is never
// repaired, so isolated surrogates captured at snapshot time survive verbatim.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An immutable snapshot of a Piece Tree's text at a point in time.
///
/// Created by `MonaPieceTree.createSnapshot()`. The snapshot materializes the
/// document text as raw `[UInt16]` and precomputes line-feed offsets, so it can
/// answer `getText`, `getLineContent`, `getOffsetAt`, and `getPositionAt`
/// queries independently of the live tree. Edits to the live tree after the
/// snapshot was created never change the snapshot's text.
public struct MonaTextSnapshot: Equatable {

    /// The materialized raw UTF-16 text. Never repaired: isolated surrogates
    /// are preserved verbatim.
    public let units: [UInt16]

    /// Line-feed offsets within `units`, 0-based.
    public let lineStarts: MonaLineStarts

    /// The number of UTF-16 code units in the snapshot.
    public var length: Int {
        return units.count
    }

    /// The number of lines. An empty snapshot has 1 line; each `\n` adds one.
    public var lineCount: Int {
        return lineStarts.lineFeedCount + 1
    }

    /// Creates a snapshot materializing `units`.
    public init(units: [UInt16]) {
        self.units = units
        self.lineStarts = MonaLineStarts(units)
    }

    /// Returns the full text as raw `[UInt16]`.
    public func getText() -> [UInt16] {
        return units
    }

    /// Returns the content of `line` (1-based) excluding its trailing newline,
    /// as raw `[UInt16]`. Returns an empty array for a line beyond range.
    public func getLineContent(_ line: Int) -> [UInt16] {
        if line < 1 {
            return []
        }
        let startOffset: Int
        if line == 1 {
            startOffset = 0
        } else {
            let idx = line - 2 // 0-based index into lineFeedOffsets
            if idx < 0 || idx >= lineStarts.lineFeedOffsets.count {
                // The requested line's start would be past the last line feed;
                // it exists only if it is the final (possibly empty) line.
                if line == lineCount {
                    let prev = lineStarts.lineFeedOffsets.last ?? -1
                    startOffset = prev + 1
                } else {
                    return []
                }
            } else {
                startOffset = lineStarts.lineFeedOffsets[idx] + 1
            }
        }
        let endOffset: Int
        let endIdx = line - 1
        if endIdx < lineStarts.lineFeedOffsets.count {
            endOffset = lineStarts.lineFeedOffsets[endIdx]
        } else {
            endOffset = units.count
        }
        if startOffset >= endOffset {
            return []
        }
        return Array(units[startOffset..<endOffset])
    }

    /// Returns the 0-based UTF-16 offset for a 1-based `(line, column)` position.
    /// The result is clamped to `[0, length]`.
    public func getOffsetAt(_ position: MonaPosition) -> Int {
        let line = position.line
        let column = position.column
        let startOffset: Int
        if line <= 1 {
            startOffset = 0
        } else {
            let idx = line - 2
            if idx >= 0 && idx < lineStarts.lineFeedOffsets.count {
                startOffset = lineStarts.lineFeedOffsets[idx] + 1
            } else {
                startOffset = units.count
            }
        }
        let offset = startOffset + (column - 1)
        return min(max(offset, 0), units.count)
    }

    /// Returns the 1-based `(line, column)` position for a 0-based UTF-16
    /// offset. The offset is clamped to `[0, length]`.
    public func getPositionAt(_ offset: Int) -> MonaPosition {
        let clamped = min(max(offset, 0), units.count)
        if units.isEmpty {
            return MonaPosition(line: 1, column: 1)
        }
        if clamped == units.count {
            // End of text: position just past the last unit.
            let prev = getPositionAt(clamped - 1)
            if units[clamped - 1] == 0x000A {
                return MonaPosition(line: prev.line + 1, column: 1)
            } else {
                return MonaPosition(line: prev.line, column: prev.column + 1)
            }
        }
        // Number of line feeds strictly before `clamped`.
        let feedIdx = MonaTextSnapshot.lowerBoundIndex(in: lineStarts.lineFeedOffsets, of: clamped)
        let line = feedIdx + 1
        let lastLFBefore: Int
        if feedIdx > 0 {
            lastLFBefore = lineStarts.lineFeedOffsets[feedIdx - 1]
        } else {
            lastLFBefore = -1
        }
        let column = clamped - lastLFBefore
        return MonaPosition(line: line, column: column)
    }

    /// Returns the number of elements strictly less than `value` in a sorted
    /// ascending array — i.e. the insertion-point index (bisect-left).
    private static func lowerBoundIndex(in sorted: [Int], of value: Int) -> Int {
        var lo = 0
        var hi = sorted.count
        while lo < hi {
            let mid = (lo + hi) >> 1
            if sorted[mid] < value {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo
    }
}
