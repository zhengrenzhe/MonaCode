// MonaHitTester.swift
//
// P03-T007 — Enforce the QueryGeometryBarrier for hit testing and native queries.
//
// `MonaHitTester` is the coordinate-conversion engine that turns screen
// (viewport) coordinates into model positions and model positions/ranges into
// viewport geometry. It is a pure consumer of one complete geometry snapshot:
// it never reshapes text, never mutates the projection, and never reaches into
// the model. Every per-line x→offset mapping goes through
// `MonaLineLayoutRecord.hitTest(offset:)` (P03-T003); every view-line→model-line
// mapping goes through the ViewGraph projection (P03-T001); every vertical
// lookup goes through `MonaVerticalIndex` (P03-T001).
//
// The hit tester answers THREE queries:
//   - `hitTest(point:)`          — viewport point → model position.
//   - `getCaretRect(position:)`  — model position → caret rect (viewport space).
//   - `getRangeRects(range:)`    — model range → selection rects (viewport space).
//
// Coordinate systems:
//   - Viewport space: origin at the top-left of the viewport, y down, x right.
//     A mouse coordinate from the host platform is in this space.
//   - Content space: origin at the top-left of the document content, y down.
//     `contentPoint = viewportPoint + scrollOffset`. A view line at vertical
//     index offset `v` (the top pixel of the line, from `MonaVerticalIndex`)
//     occupies content y in `[v, v + lineHeight)`.
//
// All returned rects (caret, range) are in VIEWPORT space (content rect minus
// the published scroll offset), so a caller can use them directly for overlay
// drawing. `hitTest` takes a viewport point and adds the scroll offset to reach
// content space before resolving.
//
// The hit tester returns `nil` (or `[]` for ranges) when a query cannot be
// resolved against the current snapshot — out of bounds, missing record, or no
// snapshot set. The `MonaQueryGeometryBarrier` (P03-T007) wraps these nils into
// typed `MonaGeometryUnavailable` reasons after performing bounded visible-line
// completion.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreGraphics + CoreText + Foundation + MonaCode (for MonaPosition/MonaRange).

import Foundation
import CoreGraphics
import CoreText
import MonaCode

/// The pure coordinate-conversion engine for one complete geometry snapshot.
///
/// Construct once with the configured `lineHeight` and set `snapshot` to the
/// current complete generation before querying. The hit tester holds no
/// mutable layout state of its own — it reads everything from the snapshot.
public final class MonaHitTester {

    /// The configured per-view-line pixel height. Used for caret height and for
    /// the vertical bounds of a view line.
    public let lineHeight: Int

    /// The current complete geometry snapshot the hit tester converts against.
    /// Set by the barrier (or a test) before querying. `nil` means no complete
    /// generation is available — every query returns `nil` / `[]`.
    public var snapshot: MonaGeometrySnapshot?

    /// Creates a hit tester with the given per-view-line pixel height.
    public init(lineHeight: Int) {
        precondition(lineHeight > 0, "MonaHitTester lineHeight must be positive")
        self.lineHeight = lineHeight
    }

    // MARK: - hitTest(point:): viewport point → model position

    /// Maps a viewport-space point to a model position against the current
    /// snapshot.
    ///
    /// The point is converted to content space by adding the snapshot's scroll
    /// offset, then resolved to a view line via `MonaVerticalIndex` and to a
    /// UTF-16 offset within that line via `MonaLineLayoutRecord.hitTest`.
    ///
    /// - Returns: The model position, or `nil` when no snapshot is set, the
    ///   point is outside the content bounds (above or below), the resolved
    ///   view line has no record in the snapshot, or the line is empty.
    public func hitTest(point: CGPoint) -> MonaPosition? {
        guard let snap = snapshot else { return nil }

        // Viewport → content space.
        let contentX = Double(point.x) + snap.scrollOffsetX
        let contentY = Double(point.y) + snap.scrollOffsetY

        // Out of vertical bounds: above the first line or at/below the content
        // end. (The barrier clamps these; the pure hit tester reports nil.)
        let totalHeight = snap.verticalIndex.totalHeight
        if contentY < 0 || contentY >= Double(totalHeight) {
            return nil
        }

        // Resolve the 1-based view line containing this content y.
        let viewLine = snap.verticalIndex.viewLineAtVerticalOffset(Int(contentY))
        if viewLine < 1 || viewLine > snap.projection.viewLines.count {
            return nil
        }

        let vl = snap.projection.viewLines[viewLine - 1]
        guard let record = snap.records[viewLine] else {
            // The line's record is not in this snapshot — cannot resolve.
            return nil
        }

        // Per-line x→offset lookup on the frozen record (no reshaping). An
        // empty line (no boundaries) yields offset 0 → the line's start column.
        let pieceOffset: Int
        if let resolved = record.hitTest(offset: CGFloat(contentX)) {
            pieceOffset = resolved
        } else {
            pieceOffset = 0
        }

        // The record is shaped for this view-line piece, so the resolved offset
        // is relative to the piece. The model column = piece start column +
        // piece offset.
        let column = vl.startColumn + pieceOffset
        return MonaPosition(line: vl.modelLineNumber, column: column)
    }

    // MARK: - getCaretRect(position:): model position → caret rect

    /// Returns the caret rect (in viewport space) for a model position against
    /// the current snapshot.
    ///
    /// The caret is a 1px-wide rect whose x is the pixel position of the
    /// UTF-16 boundary at `position.column` within the covering view-line
    /// piece, and whose y is the top of that piece's view line.
    ///
    /// - Returns: The caret rect, or `nil` when no snapshot is set, the
    ///   position's line has no view line in the projection, or the covering
    ///   piece has no record in the snapshot.
    public func getCaretRect(position: MonaPosition) -> CGRect? {
        guard let snap = snapshot else { return nil }

        // Collect the view-line pieces that derive from the position's model
        // line, in document order, with their records.
        var pieces: [(index: Int, viewLine: MonaViewLine, record: MonaLineLayoutRecord)] = []
        for i in 0..<snap.projection.viewLines.count {
            let vl = snap.projection.viewLines[i]
            if vl.modelLineNumber != position.line { continue }
            guard let record = snap.records[i + 1] else { continue }
            pieces.append((i + 1, vl, record))
        }
        if pieces.isEmpty { return nil }

        // Find the piece whose [startColumn, startColumn + sourceLength] contains
        // the position's column. If none contains it, clamp to the nearest end
        // of the line's first/last piece.
        var chosen = pieces.first!
        var offset: Int = 0
        var found = false
        for piece in pieces {
            let pieceStart = piece.viewLine.startColumn
            let pieceEnd = piece.viewLine.startColumn + piece.record.sourceLength
            if position.column >= pieceStart && position.column <= pieceEnd {
                chosen = piece
                offset = position.column - pieceStart
                found = true
                break
            }
        }
        if !found {
            // Past the end of the line → last piece, clamp to end. Before the
            // start → first piece, clamp to start.
            if position.column > pieces.last!.viewLine.startColumn + pieces.last!.record.sourceLength {
                chosen = pieces.last!
                offset = chosen.record.sourceLength
            } else {
                chosen = pieces.first!
                offset = 0
            }
        }

        // Clamp the offset into [0, sourceLength].
        offset = max(0, min(offset, chosen.record.sourceLength))

        guard let caretX = pixelX(for: offset, in: chosen.record) else { return nil }
        let lineTop = snap.verticalIndex.verticalOffsetForViewLine(chosen.index)
        return CGRect(
            x: caretX - CGFloat(snap.scrollOffsetX),
            y: CGFloat(lineTop) - CGFloat(snap.scrollOffsetY),
            width: 1,
            height: CGFloat(lineHeight)
        )
    }

    // MARK: - getRangeRects(range:): model range → selection rects

    /// Returns one selection rect per view-line piece the range intersects
    /// (in viewport space) against the current snapshot.
    ///
    /// For each view line whose model line number is within the range's line
    /// span, the column intersection is resolved to a pixel x-extent from the
    /// frozen record's raw-unit boundaries (no reshaping) and emitted as one
    /// rect spanning the full line height.
    ///
    /// - Returns: The rects (empty when no snapshot is set, the range is
    ///   outside the document, or the range collapses to zero width on every
    ///   piece).
    public func getRangeRects(range: MonaRange) -> [CGRect] {
        guard let snap = snapshot else { return [] }

        let startLine = range.startPosition.line
        let endLine = range.endPosition.line
        var rects: [CGRect] = []

        for i in 0..<snap.projection.viewLines.count {
            let vl = snap.projection.viewLines[i]
            if vl.modelLineNumber < startLine || vl.modelLineNumber > endLine {
                continue
            }
            guard let record = snap.records[i + 1] else { continue }

            let pieceStart = vl.startColumn
            let pieceEnd = vl.startColumn + record.sourceLength

            // Column intersection of the range with this piece.
            let colStart: Int
            if vl.modelLineNumber == startLine {
                colStart = max(pieceStart, range.startPosition.column)
            } else {
                colStart = pieceStart
            }
            let colEnd: Int
            if vl.modelLineNumber == endLine {
                colEnd = min(pieceEnd, range.endPosition.column)
            } else {
                colEnd = pieceEnd
            }

            // Zero-width on this piece → skip.
            if colStart >= colEnd { continue }

            let startOff = colStart - pieceStart
            let endOff = colEnd - pieceStart
            guard let startX = pixelX(for: startOff, in: record),
                  let endX = pixelX(for: endOff, in: record) else {
                continue
            }
            let lineTop = snap.verticalIndex.verticalOffsetForViewLine(i + 1)
            rects.append(CGRect(
                x: startX - CGFloat(snap.scrollOffsetX),
                y: CGFloat(lineTop) - CGFloat(snap.scrollOffsetY),
                width: endX - startX,
                height: CGFloat(lineHeight)
            ))
        }

        return rects
    }

    // MARK: - Private: pixel x lookup on a frozen record

    /// Resolves a UTF-16 offset (relative to the piece start) to its device-
    /// space x position within the line, by looking up the frozen raw-unit
    /// boundaries. Returns `nil` if the offset cannot be resolved (e.g. an
    /// empty line).
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
        for boundary in record.rawUnitBoundaries {
            if boundary.utf16Range.lowerBound == offset {
                return boundary.startX
            }
            if boundary.utf16Range.upperBound == offset {
                return boundary.endX
            }
        }
        for boundary in record.rawUnitBoundaries {
            if boundary.utf16Range.contains(offset) {
                return boundary.startX
            }
        }
        return nil
    }
}
