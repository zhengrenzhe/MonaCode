// MonaLineStarts.swift
//
// P01-T007 — Port the Piece Tree over raw UInt16 storage.
//
// `MonaLineStarts` is the per-piece line-start metadata: the 0-based UTF-16
// offsets (relative to the start of the piece's own text) at which a line feed
// (`\n`, U+000A) occurs. With this list a piece can answer, in O(log) time
// within itself, which line a given piece-relative offset falls on and where
// each line begins.
//
// This is the port of Monaco's `createLineStarts` helper (monaco-editor 0.56.0,
// `pieceTreeBase.ts`), adapted to raw `[UInt16]` storage. The offsets are
// computed by scanning the raw code units for `0x000A`; no grapheme or Unicode
// normalization is applied, and isolated surrogates are passed through
// untouched (a lone surrogate is never `0x000A`, so it never affects line
// structure).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The line-feed offsets of a piece of text, as 0-based UTF-16 offsets relative
/// to the piece's own start.
///
/// The list is sorted ascending and contains one entry per `\n` (U+000A) in the
/// piece. It is the per-piece line-start metadata used by the Piece Tree to map
/// line numbers to offsets and offsets to (line, column) positions. Because the
/// list is relative to the piece start, splitting a piece into a left and right
/// part simply filters and re-bases this list — no full rescan is needed.
public struct MonaLineStarts: Equatable, Hashable {

    /// The 0-based UTF-16 offsets of each `\n` in the piece, relative to the
    /// piece's own start. Sorted ascending.
    public let lineFeedOffsets: [Int]

    /// Creates line-start metadata directly from a precomputed offset list.
    public init(lineFeedOffsets: [Int]) {
        self.lineFeedOffsets = lineFeedOffsets
    }

    /// Computes line-start metadata by scanning `units` for `0x000A`.
    ///
    /// Offsets are 0-based relative to the start of `units`. The input is raw
    /// UTF-16: a lone surrogate is never equal to `0x000A`, so isolated
    /// surrogates never produce a spurious line feed.
    public init(_ units: [UInt16]) {
        var offsets: [Int] = []
        offsets.reserveCapacity(units.count / 32)
        for i in 0..<units.count {
            if units[i] == 0x000A {
                offsets.append(i)
            }
        }
        self.lineFeedOffsets = offsets
    }

    /// Computes line-start metadata over a slice of `units`.
    ///
    /// Offsets are 0-based relative to the start of the slice (the slice's
    /// `startIndex` is treated as 0), not relative to the underlying array.
    public init(_ units: ArraySlice<UInt16>) {
        var offsets: [Int] = []
        var relative = 0
        for unit in units {
            if unit == 0x000A {
                offsets.append(relative)
            }
            relative += 1
        }
        self.lineFeedOffsets = offsets
    }

    /// The number of line feeds in the piece.
    public var lineFeedCount: Int {
        return lineFeedOffsets.count
    }
}
