// MonaQueryGeometryBarrier.swift
//
// P03-T007 — Enforce the QueryGeometryBarrier for hit testing and native queries.
//
// `MonaQueryGeometryBarrier` is the gate that answers geometry queries ONLY from
// one complete generation. It owns the current complete projection generation
// (from `MonaViewGraph`, P03-T001), the published scroll truth (from
// `MonaScrollModel`, P03-T005), and the ready immutable layout records
// (`MonaLineLayoutRecord`, P03-T003) for the visible view lines. Every query —
// point, range, caret, selection, composition, accessibility geometry — is
// answered from this single frozen generation; partial state is never observed.
//
// When an immediate query needs a view line whose record is not yet built, the
// barrier synchronously finishes the bounded visible-line work for THAT line
// (shapes + assembles the record via `MonaLineLayoutBuilder`, P03-T003) and then
// answers. This bounded completion is limited to one line (or the few lines a
// query touches), never the whole document. If bounded completion fails (the
// shaper throws), the barrier returns a typed `MonaGeometryUnavailable` reason
// rather than publishing partial glyph data.
//
// The actual coordinate conversion is delegated to `MonaHitTester` (P03-T007),
// which consumes a `MonaGeometrySnapshot` built from the barrier's frozen
// generation. The barrier wraps the hit tester's optional results into typed
// `MonaGeometryResult` values, distinguishing:
//   - `.noCompleteGeneration`        — no generation has been published.
//   - `.outOfBounds`                 — the query is outside the document bounds
//                                       and cannot be resolved.
//   - `.boundedCompletionFailed(lineNumber:)` — synchronously building the
//                                       needed line's record failed.
//   - `.positionUnresolvable`        — the position cannot be mapped to a view
//                                       line in this generation.
//
// Supporting value types defined here:
//   - `MonaGeometryUnavailable`  — the typed unavailable reason.
//   - `MonaGeometryResult<Value>` — available(Value) | unavailable(reason).
//   - `MonaGeometrySnapshot`      — the complete, ready state of one generation
//                                   consumed by `MonaHitTester`.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreGraphics + CoreText + Foundation + MonaCode (for MonaPosition/MonaRange).

import Foundation
import CoreGraphics
import CoreText
import MonaCode

// MARK: - MonaGeometryUnavailable

/// A typed reason a geometry query could not be answered from one complete
/// generation.
public enum MonaGeometryUnavailable: Equatable, Sendable {

    /// No complete generation has been published yet. Every query returns this
    /// until `MonaQueryGeometryBarrier.publishGeneration` has run.
    case noCompleteGeneration

    /// The query's coordinates (point or position) are outside the document
    /// bounds and cannot be resolved to a position or rect.
    case outOfBounds

    /// The position cannot be mapped to a view line in the current generation
    /// (e.g. it lands on a hidden line or a piece with no record).
    case positionUnresolvable

    /// Synchronously finishing the bounded visible-line work for `lineNumber`
    /// failed (the shaper or line builder threw). No partial geometry is
    /// published for that line. `lineNumber` is the 1-based model line number.
    case boundedCompletionFailed(lineNumber: Int)
}

// MARK: - MonaGeometryResult

/// The result of a geometry query: either an available value or a typed
/// unavailable reason.
public enum MonaGeometryResult<Value: Equatable>: Equatable {

    /// The query succeeded; the associated value is the geometry answer.
    case available(Value)

    /// The query could not be answered from one complete generation; the
    /// associated reason is typed.
    case unavailable(MonaGeometryUnavailable)

    /// The available value, or `nil` when unavailable.
    public var availableValue: Value? {
        if case .available(let value) = self {
            return value
        }
        return nil
    }

    /// `true` when the query is unavailable.
    public var isUnavailable: Bool {
        if case .unavailable = self {
            return true
        }
        return false
    }
}

// MARK: - MonaGeometrySnapshot

/// The complete, ready state of one generation consumed by `MonaHitTester`.
///
/// Bundles the frozen projection (view lines + generation), the vertical index
/// (O(log n) prefix-height lookups), the ready immutable layout records keyed
/// by 1-based view-line number, the configured per-view-line pixel height, and
/// the published scroll offset. The hit tester reads everything it needs from
/// this snapshot; the barrier builds a fresh snapshot per query from its frozen
/// generation state plus the records grown by bounded completion.
public struct MonaGeometrySnapshot {

    /// The generation id of this snapshot's projection.
    public let generation: Int

    /// The frozen projection (view lines + generation) from `MonaViewGraph`.
    public let projection: MonaViewProjection

    /// The vertical index for the projection (O(log n) vertical lookups).
    public let verticalIndex: MonaVerticalIndex

    /// Ready immutable layout records keyed by 1-based view-line number. Lines
    /// absent from this dictionary have no record in this snapshot (the hit
    /// tester returns `nil` for them).
    public let records: [Int: MonaLineLayoutRecord]

    /// The configured per-view-line pixel height.
    public let lineHeight: Int

    /// The published horizontal scroll offset (Double logical points).
    public let scrollOffsetX: Double

    /// The published vertical scroll offset (Double logical points).
    public let scrollOffsetY: Double

    /// Creates a geometry snapshot.
    public init(
        generation: Int,
        projection: MonaViewProjection,
        verticalIndex: MonaVerticalIndex,
        records: [Int: MonaLineLayoutRecord],
        lineHeight: Int,
        scrollOffsetX: Double,
        scrollOffsetY: Double
    ) {
        self.generation = generation
        self.projection = projection
        self.verticalIndex = verticalIndex
        self.records = records
        self.lineHeight = lineHeight
        self.scrollOffsetX = scrollOffsetX
        self.scrollOffsetY = scrollOffsetY
    }
}

// MARK: - MonaQueryGeometryBarrier

/// The geometry query barrier: answers geometry ONLY from one complete
/// generation.
///
/// Owns the current complete projection generation, the published scroll truth,
/// and the ready immutable layout records for the visible view lines. Every
/// query is answered from this single frozen generation. When an immediate
/// query needs a view line whose record is not yet built, the barrier
/// synchronously finishes the bounded visible-line work for that line (shapes +
/// assembles the record) and then answers. If bounded completion fails, the
/// barrier returns a typed `MonaGeometryUnavailable` reason rather than
/// publishing partial glyph data.
///
/// Thread-safety: instances are not thread-safe; the editor pipeline that owns
/// one barrier is expected to drive it from a single coordinator.
public final class MonaQueryGeometryBarrier {

    // MARK: - Owned dependencies

    /// The view graph supplying complete projection generations.
    private let viewGraph: MonaViewGraph

    /// The scroll model supplying the published scroll truth.
    private let scrollModel: MonaScrollModel

    /// The line-layout builder used for bounded visible-line completion.
    private let builder: MonaLineLayoutBuilder

    /// The configured per-view-line pixel height.
    private let lineHeight: Int

    /// Supplies the full UTF-16 code units of a 1-based model line. The barrier
    /// slices these for the view-line piece it needs to shape.
    private let codeUnitsForModelLine: (Int) -> [UInt16]

    /// The hit tester that performs the actual coordinate conversion. The
    /// barrier sets its `snapshot` before delegating each query.
    private let hitTester: MonaHitTester

    // MARK: - Frozen generation state

    /// The current complete generation id, or `nil` before the first publish.
    private var generationValue: Int?

    /// The frozen projection for the current generation.
    private var projection: MonaViewProjection?

    /// The frozen vertical index for the current generation.
    private var verticalIndex: MonaVerticalIndex

    /// The published scroll offset captured at publish time.
    private var scrollOffsetX: Double = 0
    private var scrollOffsetY: Double = 0

    /// The ready records, keyed by 1-based view-line number. Grown by bounded
    /// completion; never holds partial records.
    private var records: [Int: MonaLineLayoutRecord] = [:]

    /// View-line numbers whose bounded completion failed. A failed line never
    /// publishes partial geometry; queries on it return
    /// `.boundedCompletionFailed`.
    private var failedLines: Set<Int> = []

    // MARK: - Init

    /// Creates a barrier over the given dependencies.
    ///
    /// - Parameters:
    ///   - viewGraph: The view graph supplying complete projection generations.
    ///   - scrollModel: The scroll model supplying the published scroll truth.
    ///   - builder: The line-layout builder used for bounded visible-line
    ///     completion.
    ///   - lineHeight: The configured per-view-line pixel height.
    ///   - codeUnitsForModelLine: A closure supplying the full UTF-16 code
    ///     units of a 1-based model line. The barrier slices these for the
    ///     view-line piece it needs to shape.
    public init(
        viewGraph: MonaViewGraph,
        scrollModel: MonaScrollModel,
        builder: MonaLineLayoutBuilder,
        lineHeight: Int,
        codeUnitsForModelLine: @escaping (Int) -> [UInt16]
    ) {
        precondition(lineHeight > 0, "MonaQueryGeometryBarrier lineHeight must be positive")
        self.viewGraph = viewGraph
        self.scrollModel = scrollModel
        self.builder = builder
        self.lineHeight = lineHeight
        self.codeUnitsForModelLine = codeUnitsForModelLine
        self.hitTester = MonaHitTester(lineHeight: lineHeight)
        self.verticalIndex = MonaVerticalIndex()
    }

    // MARK: - Public: generation state

    /// The current complete generation id, or `nil` before the first publish.
    public var currentGeneration: Int? {
        return generationValue
    }

    /// Publishes the current complete projection generation as the barrier's
    /// frozen generation, optionally pre-building the layout records for a
    /// bounded set of visible view lines.
    ///
    /// After this returns, queries are answered from this generation. Pre-
    /// building visible lines (the bounded visible-line work) is optional; any
    /// line not pre-built is built on demand by a later query (bounded
    /// completion).
    ///
    /// - Parameter visibleViewLines: The 1-based closed range of view lines to
    ///   pre-build, or `nil` to defer all record building to query time.
    /// - Returns: The published generation id, or `nil` if the projection is
    ///   empty.
    @discardableResult
    public func publishGeneration(visibleViewLines: ClosedRange<Int>?) -> Int? {
        // The view graph publishes a new generation only after every affected
        // index (vertical + view-zone) is complete. Reading the projection +
        // vertical index here captures that complete generation.
        let projection = viewGraph.getProjection()
        let verticalIndex = viewGraph.verticalIndex

        self.projection = projection
        self.verticalIndex = verticalIndex
        self.generationValue = projection.generation

        // Capture the published scroll truth. This is frozen into the
        // generation so queries answer from one consistent snapshot rather
        // than a mix of generation + fresh scroll.
        self.scrollOffsetX = scrollModel.publishedScrollX
        self.scrollOffsetY = scrollModel.publishedScrollY

        // Reset the per-generation record cache and failure set.
        self.records = [:]
        self.failedLines = []

        // Pre-build the bounded visible-line work, if requested.
        if let range = visibleViewLines {
            let lower = max(range.lowerBound, 1)
            let upper = min(range.upperBound, projection.viewLines.count)
            if lower <= upper {
                for viewLine in lower...upper {
                    _ = buildRecord(viewLine: viewLine, projection: projection)
                }
            }
        }

        return generationValue
    }

    // MARK: - Public: queries

    /// Hit-tests a viewport-space point against the current complete generation.
    ///
    /// - Returns: The model position, or a typed unavailable reason.
    public func hitTest(point: CGPoint) -> MonaGeometryResult<MonaPosition> {
        guard let projection = self.projection, generationValue != nil else {
            return .unavailable(.noCompleteGeneration)
        }
        let vi = verticalIndex

        // Viewport → content space.
        let contentY = Double(point.y) + scrollOffsetY

        // Above the first line → clamp to the start of the first view line.
        if contentY < 0 {
            guard !projection.viewLines.isEmpty else {
                return .unavailable(.outOfBounds)
            }
            let first = projection.viewLines.first!
            return .available(MonaPosition(line: first.modelLineNumber, column: first.startColumn))
        }

        // At or below the content end → clamp to the end of the last view line.
        if contentY >= Double(vi.totalHeight) {
            guard !projection.viewLines.isEmpty else {
                return .unavailable(.outOfBounds)
            }
            let lastIndex = projection.viewLines.count
            let last = projection.viewLines.last!
            guard let record = buildRecord(viewLine: lastIndex, projection: projection) else {
                return .unavailable(.boundedCompletionFailed(lineNumber: last.modelLineNumber))
            }
            return .available(MonaPosition(
                line: last.modelLineNumber,
                column: last.startColumn + record.sourceLength
            ))
        }

        // Resolve the 1-based view line containing this content y.
        let viewLine = vi.viewLineAtVerticalOffset(Int(contentY))
        if viewLine < 1 || viewLine > projection.viewLines.count {
            return .unavailable(.outOfBounds)
        }
        let vl = projection.viewLines[viewLine - 1]

        // Bounded visible-line completion: ensure this line's record is built.
        guard buildRecord(viewLine: viewLine, projection: projection) != nil else {
            return .unavailable(.boundedCompletionFailed(lineNumber: vl.modelLineNumber))
        }

        // Delegate the per-line conversion to the hit tester.
        hitTester.snapshot = buildSnapshot()
        if let position = hitTester.hitTest(point: point) {
            return .available(position)
        }
        return .unavailable(.positionUnresolvable)
    }

    /// Returns the caret rect (in viewport space) for a model position against
    /// the current complete generation.
    ///
    /// - Returns: The caret rect, or a typed unavailable reason.
    public func caretRect(for position: MonaPosition) -> MonaGeometryResult<CGRect> {
        guard let projection = self.projection, generationValue != nil else {
            return .unavailable(.noCompleteGeneration)
        }

        // Find the view-line pieces for this position's model line and ensure
        // their records (bounded completion).
        var indices: [Int] = []
        for i in 0..<projection.viewLines.count {
            if projection.viewLines[i].modelLineNumber == position.line {
                indices.append(i + 1)
            }
        }
        guard !indices.isEmpty else {
            return .unavailable(.outOfBounds)
        }
        for index in indices {
            guard buildRecord(viewLine: index, projection: projection) != nil else {
                return .unavailable(.boundedCompletionFailed(lineNumber: position.line))
            }
        }

        hitTester.snapshot = buildSnapshot()
        if let rect = hitTester.getCaretRect(position: position) {
            return .available(rect)
        }
        return .unavailable(.positionUnresolvable)
    }

    /// Returns the selection rects (in viewport space) for a model range
    /// against the current complete generation.
    ///
    /// - Returns: The rects, or a typed unavailable reason.
    public func rangeRects(for range: MonaRange) -> MonaGeometryResult<[CGRect]> {
        guard let projection = self.projection, generationValue != nil else {
            return .unavailable(.noCompleteGeneration)
        }

        // Collect the view-line indices whose model line falls within the
        // range's line span, and ensure their records (bounded completion).
        var indices: [Int] = []
        for i in 0..<projection.viewLines.count {
            let modelLine = projection.viewLines[i].modelLineNumber
            if modelLine >= range.startPosition.line && modelLine <= range.endPosition.line {
                indices.append(i + 1)
            }
        }
        guard !indices.isEmpty else {
            return .unavailable(.outOfBounds)
        }
        for index in indices {
            let modelLine = projection.viewLines[index - 1].modelLineNumber
            guard buildRecord(viewLine: index, projection: projection) != nil else {
                return .unavailable(.boundedCompletionFailed(lineNumber: modelLine))
            }
        }

        hitTester.snapshot = buildSnapshot()
        return .available(hitTester.getRangeRects(range: range))
    }

    // MARK: - Private: bounded visible-line completion

    /// Builds and caches the record for `viewLine` (1-based) if not already
    /// built. Returns the record, or `nil` if the view line is out of range or
    /// building failed (in which case the line is added to `failedLines`).
    ///
    /// This is the bounded visible-line completion path: it shapes + assembles
    /// exactly one line's record, never the whole document.
    private func buildRecord(
        viewLine: Int,
        projection: MonaViewProjection
    ) -> MonaLineLayoutRecord? {
        if let cached = records[viewLine] {
            return cached
        }
        if failedLines.contains(viewLine) {
            return nil
        }
        guard viewLine >= 1 && viewLine <= projection.viewLines.count else {
            return nil
        }

        let vl = projection.viewLines[viewLine - 1]
        let fullUnits = codeUnitsForModelLine(vl.modelLineNumber)

        // Compute this piece's UTF-16 length. A wrapped continuation piece's
        // length is the gap to the next wrapped piece's start column; the last
        // piece of a line runs to the model line's end.
        let pieceLength: Int
        if viewLine < projection.viewLines.count {
            let next = projection.viewLines[viewLine]
            if next.modelLineNumber == vl.modelLineNumber && next.isWrapped {
                pieceLength = next.startColumn - vl.startColumn
            } else {
                pieceLength = max(0, fullUnits.count - (vl.startColumn - 1))
            }
        } else {
            pieceLength = max(0, fullUnits.count - (vl.startColumn - 1))
        }

        // Slice the piece's code units from the full model line.
        let startIdx = vl.startColumn - 1
        let endIdx = startIdx + pieceLength
        let pieceUnits: [UInt16]
        if startIdx >= 0 && endIdx <= fullUnits.count && startIdx <= endIdx {
            pieceUnits = startIdx < endIdx ? Array(fullUnits[startIdx..<endIdx]) : []
        } else {
            // Bounds out of range — treat as an empty piece.
            pieceUnits = []
        }

        do {
            let stamp = builder.makeDependencyStamp()
            let record = try builder.build(codeUnits: pieceUnits, dependencyStamp: stamp)
            records[viewLine] = record
            return record
        } catch {
            // Bounded completion failed: no partial glyph data is published.
            failedLines.insert(viewLine)
            return nil
        }
    }

    /// Builds a fresh `MonaGeometrySnapshot` from the frozen generation state
    /// plus the records grown by bounded completion.
    private func buildSnapshot() -> MonaGeometrySnapshot? {
        guard let projection = self.projection, let generation = generationValue else {
            return nil
        }
        return MonaGeometrySnapshot(
            generation: generation,
            projection: projection,
            verticalIndex: verticalIndex,
            records: records,
            lineHeight: lineHeight,
            scrollOffsetX: scrollOffsetX,
            scrollOffsetY: scrollOffsetY
        )
    }
}
