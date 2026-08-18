// MonaMultiCursorInputPlan.swift
//
// P04-T005 — Replicate multi-cursor input through ModelInputBarrier.
//
// `MonaMultiCursorInputPlan` is the multi-cursor edit plan — the Swift
// counterpart of the cursor-replicated edit batch Monaco assembles before
// pushing it through the text model (monaco-editor 0.56.0). A plan carries a
// PRIMARY cursor edit plus zero or more SECONDARY cursor edits, and applies the
// six replication rules before the barrier commits the batch:
//
//   - overlap   — two cursors editing OVERLAPPING ranges either merge (when
//                 their text and kind are identical) or reject the plan.
//   - merge     — two cursors editing ADJACENT ranges (one's end == the
//                 other's start) with the same kind combine into one edit
//                 whose range spans both and whose text is the concatenation.
//   - ordering  — the edit operations are applied in DESCENDING start-offset
//                 order so that applying an edit at a larger offset does not
//                 shift the offsets of edits at smaller offsets.
//   - snippet   — a snippet's tabstop placeholders are replicated per cursor,
//                 each expressed as an offset pair relative to that cursor's
//                 own insertion start.
//   - clipboard — a clipboard paste is replicated per cursor, each edit
//                 carrying the same pasted text and `.clipboard` kind.
//   - composition — IME composition marked text is replicated per cursor, each
//                 edit carrying the same marked text and `.composition` kind.
//
// The plan is a pure value: it holds no reference to the model, performs no
// mutation, and never reads text. The offset-ordering and resulting-selection
// computations take the model as an argument and read offsets through it.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The kind of multi-cursor input, determining how the edit is replicated
/// across cursors and how merge conflicts are resolved.
public enum MonaMultiCursorInputKind: Equatable, Hashable {

    /// Plain text insertion or replacement.
    case text

    /// Snippet insertion with tabstop placeholders replicated per cursor.
    case snippet

    /// Clipboard paste replicated per cursor.
    case clipboard

    /// IME composition marked text replicated per cursor.
    case composition
}

/// A tabstop placeholder within a snippet, replicated per cursor.
///
/// `startOffset` and `endOffset` are 0-based UTF-16 code-unit offsets relative
/// to the START of the cursor's inserted text (end-exclusive). Each cursor
/// carries its own copy of the template's tabstops; because they are relative
/// offsets, the same placeholder values place each cursor's tabstop correctly
/// within its own inserted text.
public struct MonaSnippetTabstop: Equatable, Hashable {

    /// The tabstop index. 0 is the final tabstop (caret rest); 1+ are ordered
    /// tabstops visited in ascending order.
    public let index: Int

    /// The placeholder's start offset, relative to the cursor's inserted text.
    public let startOffset: Int

    /// The placeholder's end offset (exclusive), relative to the cursor's
    /// inserted text.
    public let endOffset: Int

    /// Creates a tabstop placeholder.
    public init(index: Int, startOffset: Int, endOffset: Int) {
        self.index = index
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

/// A snippet template: the text to insert plus the tabstop placeholders
/// expressed as relative offset pairs. Replicated verbatim to each cursor.
public struct MonaSnippetTemplate: Equatable {

    /// The snippet text (may include literal tabstop markers; the offsets in
    /// `tabstops` index into `text` as inserted).
    public let text: String

    /// The tabstop placeholders, as 0-based relative offset pairs into `text`.
    public let tabstops: [MonaSnippetTabstop]

    /// Creates a snippet template.
    public init(text: String, tabstops: [MonaSnippetTabstop] = []) {
        self.text = text
        self.tabstops = tabstops
    }
}

/// A single cursor's prepared edit within a multi-cursor plan.
///
/// Carries the range to replace (pre-edit coordinates), the text to insert, the
/// input kind (driving replication and merge), the marker-affinity flag, and —
/// for `.snippet` edits — the tabstop placeholders relative to this cursor's
/// insertion start.
public struct MonaCursorInputEdit: Equatable, Hashable {

    /// The range of text to replace (pre-edit coordinates).
    public let range: MonaRange

    /// The text to insert in place of the range.
    public let text: String

    /// The input kind, driving replication and merge behavior.
    public let kind: MonaMultiCursorInputKind

    /// `true` when markers at the range boundary should move with the edit.
    public let forceMoveMarkers: Bool

    /// Tabstop placeholders for `.snippet` edits, as offset pairs relative to
    /// the start of this cursor's inserted text. Empty for non-snippet edits.
    public let tabstops: [MonaSnippetTabstop]

    /// Creates a single cursor's prepared edit.
    public init(
        range: MonaRange,
        text: String,
        kind: MonaMultiCursorInputKind = .text,
        forceMoveMarkers: Bool = false,
        tabstops: [MonaSnippetTabstop] = []
    ) {
        self.range = range
        self.text = text
        self.kind = kind
        self.forceMoveMarkers = forceMoveMarkers
        self.tabstops = tabstops
    }
}

/// The policy for resolving two cursors editing OVERLAPPING ranges.
public enum MonaOverlapPolicy: Equatable {

    /// Reject the plan when two cursors edit overlapping ranges (the barrier
    /// rolls back the whole batch). This is the default.
    case reject

    /// Merge two overlapping edits into one edit covering the union of their
    /// ranges when their text and kind are identical; otherwise reject. The
    /// merged edit carries one copy of the text (the two cursors intended the
    /// same insertion in overlapping regions, so the merged result inserts it
    /// once over the union).
    case merge
}

/// A multi-cursor edit plan: a primary cursor edit plus zero or more secondary
/// cursor edits, with replication rules for overlap, merge, ordering, snippet,
/// clipboard, and composition.
///
/// Construct directly with `init(primary:secondary:)` or via the replication
/// factories (`replicateText`, `replicateClipboardPaste`,
/// `replicateCompositionMarkedText`, `replicateSnippet`). Resolve conflicts with
/// `resolvingConflicts(overlapPolicy:)`, order for application with
/// `orderedOperations(model:)`, and compute post-edit selections with
/// `resultingSelections(model:)`.
public struct MonaMultiCursorInputPlan: Equatable {

    /// The primary cursor's edit.
    public let primary: MonaCursorInputEdit

    /// The secondary cursors' edits, in cursor order.
    public let secondary: [MonaCursorInputEdit]

    /// Creates a plan from a primary edit and zero or more secondary edits.
    public init(primary: MonaCursorInputEdit, secondary: [MonaCursorInputEdit] = []) {
        self.primary = primary
        self.secondary = secondary
    }

    /// All cursor edits, primary first, then secondary in order.
    public var allEdits: [MonaCursorInputEdit] {
        return [primary] + secondary
    }

    // MARK: - Replication factories

    /// Replicates a plain-text insertion at each cursor position. Each cursor
    /// becomes a folded insertion (zero-length range) carrying the same text and
    /// `.text` kind. The first position is the primary; the rest are secondary.
    public static func replicateText(
        cursorPositions: [MonaPosition],
        text: String
    ) -> MonaMultiCursorInputPlan {
        return replicate(cursorPositions: cursorPositions, text: text, kind: .text, tabstops: [])
    }

    /// Replicates a clipboard paste at each cursor position. Each cursor
    /// becomes a folded insertion carrying the same pasted text and `.clipboard`
    /// kind.
    public static func replicateClipboardPaste(
        cursorPositions: [MonaPosition],
        text: String
    ) -> MonaMultiCursorInputPlan {
        return replicate(cursorPositions: cursorPositions, text: text, kind: .clipboard, tabstops: [])
    }

    /// Replicates IME composition marked text at each cursor position. Each
    /// cursor becomes a folded insertion carrying the same marked text and
    /// `.composition` kind.
    public static func replicateCompositionMarkedText(
        cursorPositions: [MonaPosition],
        markedText: String
    ) -> MonaMultiCursorInputPlan {
        return replicate(cursorPositions: cursorPositions, text: markedText, kind: .composition, tabstops: [])
    }

    /// Replicates a snippet at each cursor position. Each cursor becomes a
    /// folded insertion carrying the template text and `.snippet` kind, with
    /// the template's tabstop placeholders replicated verbatim (as relative
    /// offsets, so each cursor's tabstops land within its own inserted text).
    public static func replicateSnippet(
        cursorPositions: [MonaPosition],
        template: MonaSnippetTemplate
    ) -> MonaMultiCursorInputPlan {
        return replicate(
            cursorPositions: cursorPositions,
            text: template.text,
            kind: .snippet,
            tabstops: template.tabstops
        )
    }

    /// Shared replication core: builds one folded edit per cursor position.
    private static func replicate(
        cursorPositions: [MonaPosition],
        text: String,
        kind: MonaMultiCursorInputKind,
        tabstops: [MonaSnippetTabstop]
    ) -> MonaMultiCursorInputPlan {
        let edits = cursorPositions.map { position -> MonaCursorInputEdit in
            return MonaCursorInputEdit(
                range: MonaRange(startPosition: position, endPosition: position),
                text: text,
                kind: kind,
                forceMoveMarkers: false,
                tabstops: tabstops
            )
        }
        guard !edits.isEmpty else {
            // No cursors: a degenerate plan with a single empty edit at (1,1).
            return MonaMultiCursorInputPlan(
                primary: MonaCursorInputEdit(
                    range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                    text: "",
                    kind: kind
                )
            )
        }
        return MonaMultiCursorInputPlan(primary: edits[0], secondary: Array(edits.dropFirst()))
    }

    // MARK: - Conflict resolution (overlap + merge)

    /// Resolves overlap and merge conflicts, returning a new plan whose edits
    /// are non-overlapping, or `nil` if overlapping edits cannot be resolved.
    ///
    /// Overlap rule: two cursors editing strictly overlapping ranges (one's
    /// start is before the other's end) either merge (`.merge` policy with
    /// identical text and kind → one edit covering the union, one copy of the
    /// text) or reject (`.reject` policy, or non-identical under `.merge`).
    ///
    /// Merge rule: two cursors editing adjacent ranges (one's end == the
    /// other's start) with the same kind combine into one edit whose range
    /// spans both and whose text is the concatenation. This is always applied.
    ///
    /// The resolved plan's edits are in ascending start-position order; the
    /// first becomes `primary`, the rest `secondary`.
    public func resolvingConflicts(
        overlapPolicy: MonaOverlapPolicy = .reject
    ) -> MonaMultiCursorInputPlan? {
        // Sort ascending by start position (line-major, then column); tie-break
        // by end position then by original order for determinism.
        let sorted = allEdits.enumerated().sorted { a, b -> Bool in
            let aStart = a.element.range.startPosition
            let bStart = b.element.range.startPosition
            if aStart != bStart { return aStart < bStart }
            let aEnd = a.element.range.endPosition
            let bEnd = b.element.range.endPosition
            if aEnd != bEnd { return aEnd < bEnd }
            return a.offset < b.offset
        }.map { $0.element }

        var resolved: [MonaCursorInputEdit] = []
        for edit in sorted {
            guard let last = resolved.last else {
                resolved.append(edit)
                continue
            }
            let prevEnd = last.range.endPosition
            let curStart = edit.range.startPosition

            if curStart < prevEnd {
                // Strict overlap.
                switch overlapPolicy {
                case .reject:
                    return nil
                case .merge:
                    guard last.kind == edit.kind,
                          last.text == edit.text,
                          last.forceMoveMarkers == edit.forceMoveMarkers else {
                        return nil
                    }
                    // Merge: union range, one copy of the text, combine tabstops.
                    let mergedRange = MonaRange(
                        startPosition: last.range.startPosition,
                        endPosition: max(last.range.endPosition, edit.range.endPosition)
                    )
                    let merged = MonaCursorInputEdit(
                        range: mergedRange,
                        text: last.text,
                        kind: last.kind,
                        forceMoveMarkers: last.forceMoveMarkers,
                        tabstops: last.tabstops + edit.tabstops
                    )
                    resolved[resolved.count - 1] = merged
                    continue
                }
            } else if curStart == prevEnd && last.kind == edit.kind {
                // Adjacent (touching) and same kind → merge into one edit whose
                // range spans both and whose text is the concatenation.
                let combinedRange = MonaRange(
                    startPosition: last.range.startPosition,
                    endPosition: edit.range.endPosition
                )
                let combined = MonaCursorInputEdit(
                    range: combinedRange,
                    text: last.text + edit.text,
                    kind: last.kind,
                    forceMoveMarkers: last.forceMoveMarkers,
                    tabstops: last.tabstops + edit.tabstops
                )
                resolved[resolved.count - 1] = combined
                continue
            }
            resolved.append(edit)
        }

        // The resolved edits are non-overlapping and in ascending start order.
        // The first becomes the primary; the rest are secondary.
        return MonaMultiCursorInputPlan(
            primary: resolved[0],
            secondary: Array(resolved.dropFirst())
        )
    }

    // MARK: - Ordering rule (reverse start-offset)

    /// Returns the edit operations in DESCENDING start-offset order so that
    /// applying them in this sequence preserves the offsets of edits not yet
    /// applied. (The model also sorts internally; this is the plan's explicit
    /// ordering for validation and tests.)
    public func orderedOperations(model: MonaCodeModel) -> [MonaModelEditOperation] {
        return allEdits
            .map { (edit: $0, startOff: model.getOffsetAt($0.range.startPosition)) }
            .sorted { a, b in
                if a.startOff != b.startOff { return a.startOff > b.startOff }
                // Stable tie-break by original order (a/b carry no index; use
                // position then text for determinism).
                if a.edit.range.startPosition != b.edit.range.startPosition {
                    return a.edit.range.startPosition < b.edit.range.startPosition
                }
                return a.edit.text < b.edit.text
            }
            .map { entry in
                return MonaModelEditOperation(
                    range: entry.edit.range,
                    text: entry.edit.text,
                    forceMoveMarkers: entry.edit.forceMoveMarkers
                )
            }
    }

    // MARK: - Resulting selections per cursor

    /// Computes each cursor's post-edit selection as a collapsed caret at the
    /// end of its inserted text, accounting for the shift introduced by edits
    /// at smaller start offsets.
    ///
    /// Edits are applied in descending start-offset order; an edit at a smaller
    /// offset shifts every larger offset up by `(insertCount - deleteCount)`.
    /// Each cursor's final caret offset is therefore `startOff + insertCount +
    /// cumulativeShift`, where `cumulativeShift` is the net shift from edits at
    /// strictly smaller start offsets.
    ///
    /// The caret offset is computed in POST-commit coordinate space, so it is
    /// mapped to a `(line, column)` position through the POST-commit line
    /// structure (built by applying the non-overlapping edits to the model's
    /// text). Mapping through the pre-commit model would be wrong whenever the
    /// cumulative shift pushes a caret offset across a line boundary or beyond
    /// the pre-commit length — the pre-commit line structure does not reflect
    /// the shift, so it would clamp or mis-place the caret.
    ///
    /// The returned selections are in `allEdits` order (primary first).
    public func resultingSelections(model: MonaCodeModel) -> [MonaSelection] {
        struct Entry {
            let originalIndex: Int
            let startOff: Int
            let insertCount: Int
            let deleteCount: Int
            let insertText: String
        }

        var entries: [Entry] = []
        entries.reserveCapacity(allEdits.count)
        for (i, edit) in allEdits.enumerated() {
            let startOff = model.getOffsetAt(edit.range.startPosition)
            let endOff = model.getOffsetAt(edit.range.endPosition)
            let insertCount = Array(edit.text.utf16).count
            let deleteCount = max(endOff - startOff, 0)
            entries.append(Entry(
                originalIndex: i,
                startOff: startOff,
                insertCount: insertCount,
                deleteCount: deleteCount,
                insertText: edit.text
            ))
        }

        // Sort ascending by start offset for the cumulative-shift computation;
        // stable tie-break by original index.
        let ascending = entries.sorted { a, b in
            if a.startOff != b.startOff { return a.startOff < b.startOff }
            return a.originalIndex < b.originalIndex
        }

        // Build the post-commit text + its line-start offsets so caret offsets
        // (post-commit) map to correct (line, column) positions.
        let postCommitText = Self.applyEditsToText(
            model.getValue(),
            ascendingEdits: ascending.map {
                (startOff: $0.startOff, deleteCount: $0.deleteCount, insertText: $0.insertText)
            }
        )
        let lineStarts = Self.utf16LineStartOffsets(of: postCommitText)
        let postCommitUTF16Count = Array(postCommitText.utf16).count

        var selections = Array<MonaSelection?>(repeating: nil, count: entries.count)
        var cumulativeShift = 0
        for entry in ascending {
            let cursorOffset = entry.startOff + cumulativeShift + entry.insertCount
            let cursorPos = Self.position(
                atUTF16Offset: cursorOffset,
                lineStarts: lineStarts,
                textUTF16Count: postCommitUTF16Count
            )
            selections[entry.originalIndex] = MonaSelection(anchor: cursorPos, activePosition: cursorPos)
            cumulativeShift += entry.insertCount - entry.deleteCount
        }
        return selections.compactMap { $0 }
    }

    // MARK: - Post-commit position mapping (private helpers)

    /// Applies non-overlapping edits (in ascending start-offset order) to
    /// `text`, returning the post-commit text. Single pass: O(text size + total
    /// inserted text). Used to map post-commit caret offsets to positions.
    private static func applyEditsToText(
        _ text: String,
        ascendingEdits: [(startOff: Int, deleteCount: Int, insertText: String)]
    ) -> String {
        if ascendingEdits.isEmpty { return text }
        var result = ""
        let units = Array(text.utf16)
        var lastEnd = 0
        for edit in ascendingEdits {
            if edit.startOff > lastEnd {
                result += String(decoding: units[lastEnd..<edit.startOff], as: UTF16.self)
            }
            result += edit.insertText
            lastEnd = edit.startOff + edit.deleteCount
        }
        if lastEnd < units.count {
            result += String(decoding: units[lastEnd..<units.count], as: UTF16.self)
        }
        return result
    }

    /// Returns the UTF-16 offset of the first character of each line (1-based
    /// line indexing: line 1 starts at offset 0). `lineStarts[i]` is the offset
    /// of line `i + 1`'s first character.
    private static func utf16LineStartOffsets(of text: String) -> [Int] {
        var lineStarts: [Int] = [0]
        var offset = 0
        for unit in text.utf16 {
            if unit == 0x000A { // '\n' — next line starts after this unit.
                lineStarts.append(offset + 1)
            }
            offset += 1
        }
        return lineStarts
    }

    /// Maps a UTF-16 `offset` to a 1-based `(line, column)` position within the
    /// post-commit text. `lineStarts` is the output of `utf16LineStartOffsets`.
    /// The offset is clamped to `[0, textUTF16Count]` so a caret resting at the
    /// end of the text maps to the last line's max column.
    private static func position(
        atUTF16Offset offset: Int,
        lineStarts: [Int],
        textUTF16Count: Int
    ) -> MonaPosition {
        let clamped = min(max(offset, 0), textUTF16Count)
        // Binary search for the last line whose start <= clamped.
        var lo = 0
        var hi = lineStarts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if lineStarts[mid] <= clamped {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        let lineIndex = max(lo - 1, 0) // 0-based line index.
        let lineStart = lineStarts[lineIndex]
        let column = clamped - lineStart + 1 // 1-based column.
        return MonaPosition(line: lineIndex + 1, column: column)
    }
}
