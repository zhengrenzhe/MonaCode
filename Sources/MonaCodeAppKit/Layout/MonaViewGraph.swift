// MonaViewGraph.swift
//
// P03-T001 — Build ViewGraph projection and logarithmic vertical indexes.
//
// `MonaViewGraph` is the projection layer between the text model
// (`MonaCodeModel`) and the renderer. It projects model lines into view lines,
// applying:
//   - folding (collapsed ranges)         — a folded line collapses to one view
//                                           line marked `isCollapsed`.
//   - hidden ranges                       — hidden model lines are excluded.
//   - injected text                       — injections attach their id to the
//                                           view-line piece covering their
//                                           column.
//   - word wrapping                       — a model line longer than the wrap
//                                           column splits into multiple wrapped
//                                           view-line pieces.
//   - view zones                          — inserted visual blocks between
//                                           lines (do not create view lines;
//                                           they contribute height in the
//                                           vertical index).
//
// Generation contract: a new projection generation is published ONLY after
// every affected index (vertical + view-zone) is complete. Mutators mark the
// graph dirty but do not bump the generation; `getProjection()` rebuilds the
// view lines, rebuilds the vertical index, rebuilds the view-zone index, and
// ONLY THEN increments the generation. A non-dirty `getProjection()` returns
// the cached projection and does not bump the generation.
//
// `MonaViewInjection` is the value type for an injected-text span; it is
// defined here because it is a graph mutation input. `MonaViewZone` lives in
// `MonaViewZoneIndex.swift`.
//
// MonaCodeAppKit may import AppKit/CoreGraphics; this file keeps imports
// minimal (Foundation + MonaCode for the model).

import Foundation
import MonaCode

/// An injected-text span attached to a model line at a column.
public struct MonaViewInjection: Equatable, Hashable {

    /// A stable identifier for the injection (unique within one projection).
    public let id: String

    /// The 1-based model line number the injection attaches to.
    public let lineNumber: Int

    /// The 1-based UTF-16 column where the injection is positioned.
    public let column: Int

    /// The injected text.
    public let text: String

    /// Creates an injection.
    public init(id: String, lineNumber: Int, column: Int, text: String) {
        self.id = id
        self.lineNumber = lineNumber
        self.column = column
        self.text = text
    }
}

/// An immutable projection generation: the view-line list and its generation id.
public struct MonaViewProjection: Equatable {

    /// The generation id of this projection. Advances by one per rebuild.
    public let generation: Int

    /// The projected view lines in document order.
    public let viewLines: [MonaViewLine]

    /// Creates a projection value.
    public init(generation: Int, viewLines: [MonaViewLine]) {
        self.generation = generation
        self.viewLines = viewLines
    }
}

/// Projects a `MonaCodeModel` into view lines, applying folding, hidden ranges,
/// injected text, word wrapping, and view zones, and maintaining logarithmic
/// vertical + view-zone indexes.
public final class MonaViewGraph {

    // MARK: - Owned truth

    /// The text model being projected.
    private let model: MonaCodeModel

    /// The per-view-line pixel height.
    private var lineHeightValue: Int

    // MARK: - Mutation inputs

    /// Collapsed (folded) model-line ranges. A folded line collapses to one
    /// view line marked `isCollapsed`.
    private var foldedRanges: [MonaRange] = []

    /// Hidden model-line ranges. Hidden lines are excluded from the projection.
    private var hiddenRanges: [MonaRange] = []

    /// Injected-text spans.
    private var injections: [MonaViewInjection] = []

    /// The word-wrap column: `nil` disables wrapping; an integer `c` wraps a
    /// model line into view-line pieces of at most `c` UTF-16 characters.
    private var wordWrapColumn: Int? = nil

    /// View zones positioned after model lines.
    private var zones: [MonaViewZone] = []

    // MARK: - Cached projection state

    /// `true` when a mutator changed an input and the projection must rebuild.
    private var dirty: Bool = true

    /// The current generation id. Starts at 0; the first projection advances it
    /// to 1. Advances by one per rebuild (only after all indexes complete).
    private var generationValue: Int = 0

    /// The cached view lines (valid when `dirty == false`).
    private var cachedViewLines: [MonaViewLine] = []

    /// The vertical index for the current projection.
    private var verticalIndexValue: MonaVerticalIndex

    /// The view-zone index for the current projection.
    private var viewZoneIndexValue: MonaViewZoneIndex

    // MARK: - Initialization

    /// Creates a view graph projecting `model` with `lineHeight` per view line.
    public init(model: MonaCodeModel, lineHeight: Int) {
        self.model = model
        self.lineHeightValue = max(lineHeight, 1)
        // Placeholder indexes until the first projection builds real ones.
        self.verticalIndexValue = MonaVerticalIndex()
        self.viewZoneIndexValue = MonaViewZoneIndex(zones: [])
    }

    // MARK: - Mutators (mark dirty; do NOT advance generation)

    /// Sets the folded (collapsed) model-line ranges.
    public func setFoldedRanges(_ ranges: [MonaRange]) {
        foldedRanges = ranges
        dirty = true
    }

    /// Sets the hidden model-line ranges.
    public func setHiddenRanges(_ ranges: [MonaRange]) {
        hiddenRanges = ranges
        dirty = true
    }

    /// Sets the injected-text spans.
    public func setInjections(_ injections: [MonaViewInjection]) {
        self.injections = injections
        dirty = true
    }

    /// Sets the word-wrap column. `nil` disables wrapping; `c` wraps lines into
    /// pieces of at most `c` characters.
    public func setWordWrapColumn(_ column: Int?) {
        wordWrapColumn = column.map { max($0, 1) }
        dirty = true
    }

    /// Sets the view zones positioned after model lines.
    public func setViewZones(_ zones: [MonaViewZone]) {
        self.zones = zones
        dirty = true
    }

    /// Sets the per-view-line pixel height.
    public func setLineHeight(_ height: Int) {
        lineHeightValue = max(height, 1)
        dirty = true
    }

    // MARK: - Projection

    /// Returns the current projection, rebuilding it (and the vertical +
    /// view-zone indexes) if dirty. The generation advances by exactly one only
    /// after every affected index is complete.
    public func getProjection() -> MonaViewProjection {
        if dirty {
            rebuild()
        }
        return MonaViewProjection(generation: generationValue, viewLines: cachedViewLines)
    }

    /// The current generation id. Advances only inside `getProjection()` after
    /// a rebuild completes every index.
    public var generation: Int {
        return generationValue
    }

    /// The vertical index for the current projection.
    public var verticalIndex: MonaVerticalIndex {
        return verticalIndexValue
    }

    /// The view-zone index for the current projection.
    public var viewZoneIndex: MonaViewZoneIndex {
        return viewZoneIndexValue
    }

    // MARK: - Private: rebuild

    /// Rebuilds the view lines, the vertical index, and the view-zone index from
    /// the current inputs, then advances the generation. The generation advances
    /// ONLY after every index is complete.
    private func rebuild() {
        let lineCount = model.getLineCount()

        // ---- Resolve hidden model lines ----
        var hiddenLines = Set<Int>()
        for r in hiddenRanges {
            let lo = max(r.startPosition.line, 1)
            let hi = min(r.endPosition.line, lineCount)
            if lo <= hi {
                hiddenLines.formUnion(lo...hi)
            }
        }

        // ---- Resolve folded model lines (by start line) ----
        var foldedLines = Set<Int>()
        for r in foldedRanges {
            let lo = max(r.startPosition.line, 1)
            let hi = min(r.endPosition.line, lineCount)
            if lo <= hi {
                foldedLines.formUnion(lo...hi)
            }
        }

        // ---- Group injections by model line ----
        var injectionsByLine: [Int: [MonaViewInjection]] = [:]
        for inj in injections {
            injectionsByLine[inj.lineNumber, default: []].append(inj)
        }

        // ---- Visible zones (zones after visible model lines) ----
        let visibleZones = zones.filter { !hiddenLines.contains($0.afterLineNumber) }

        // ---- Build view lines ----
        var viewLines: [MonaViewLine] = []
        viewLines.reserveCapacity(lineCount)
        for modelLine in 1...max(lineCount, 1) {
            if modelLine > lineCount { break }
            if hiddenLines.contains(modelLine) { continue }

            let lineInjections = injectionsByLine[modelLine] ?? []
            let isCollapsed = foldedLines.contains(modelLine)

            if isCollapsed {
                // A folded line collapses to one view line. Injections attach by
                // id (column ignored for the collapsed form).
                viewLines.append(MonaViewLine(
                    modelLineNumber: modelLine,
                    startColumn: 1,
                    isWrapped: false,
                    injectionIds: lineInjections.map(\.id),
                    isCollapsed: true,
                    isVisible: true
                ))
                continue
            }

            let lineLen = model.getLineLength(modelLine)
            let wrap = wordWrapColumn

            if let w = wrap, w > 0, lineLen > w {
                // Wrap into pieces of at most `w` characters.
                var startCol = 1
                var pieceIndex = 0
                while startCol <= lineLen {
                    let endCol = min(startCol + w - 1, lineLen)
                    // The piece covers columns [startCol, endCol].
                    let pieceInjections = lineInjections
                        .filter { $0.column >= startCol && $0.column <= endCol }
                        .map(\.id)
                    viewLines.append(MonaViewLine(
                        modelLineNumber: modelLine,
                        startColumn: startCol,
                        isWrapped: pieceIndex > 0,
                        injectionIds: pieceInjections,
                        isCollapsed: false,
                        isVisible: true
                    ))
                    startCol = endCol + 1
                    pieceIndex += 1
                }
            } else {
                // Single (non-wrapped) view line covering [1, lineLen].
                let pieceInjections = lineInjections
                    .filter { $0.column >= 1 && $0.column <= lineLen + 1 }
                    .map(\.id)
                viewLines.append(MonaViewLine(
                    modelLineNumber: modelLine,
                    startColumn: 1,
                    isWrapped: false,
                    injectionIds: pieceInjections,
                    isCollapsed: false,
                    isVisible: true
                ))
            }
        }

        // ---- Rebuild the vertical index (complete BEFORE generation bump) ----
        let newVerticalIndex = MonaVerticalIndex(
            viewLines: viewLines,
            lineHeight: lineHeightValue,
            zones: visibleZones
        )

        // ---- Rebuild the view-zone index (complete BEFORE generation bump) ----
        let visibleLineSet = Set(viewLines.map(\.modelLineNumber))
        let newViewZoneIndex = MonaViewZoneIndex(zones: visibleZones, visibleLines: visibleLineSet)

        // ---- Publish: cache + advance generation only after all indexes done ----
        self.cachedViewLines = viewLines
        self.verticalIndexValue = newVerticalIndex
        self.viewZoneIndexValue = newViewZoneIndex
        self.generationValue += 1
        self.dirty = false
    }
}
