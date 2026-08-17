// MonaDecorationTree.swift
//
// P02-T002 — Port decoration interval trees and stickiness semantics.
//
// `MonaDecorationTree` is an augmented interval tree over `MonaDecoration`
// ranges — the Swift counterpart of Monaco's `IntervalTree`
// (monaco-editor 0.56.0). The tree is keyed by each decoration's start
// position and augmented with the maximum end position in each subtree, so an
// interval query can prune subtrees that cannot intersect the query range.
//
// Operations:
//   - `insert(_:)`         — insert (or replace by id) a decoration.
//   - `delete(id:)`        — remove a decoration by id.
//   - `get(id:)`           — look up a decoration by id.
//   - `query(_:ownerId:)`  — return every decoration whose range intersects the
//                            query range (touching counts), owner-filtered.
//   - `allDecorations(ownerId:)` — return every decoration, owner-filtered.
//   - `acceptEdit(from:to:textLength:forceMoveMarkers:)` — range movement:
//                            reposition every decoration for an edit that
//                            replaces `[from, to)` with text of length
//                            `textLength`, resolving endpoints inside the
//                            replaced region by stickiness.
//
// Operation counters instrument insert, delete, interval query, and owner
// query, matching the G6-R P02-T002 instrumentation requirement.
//
// Range movement (the core stickiness port): for an edit replacing `[from, to)`
// with text of length `L`, each endpoint `p` of a decoration resolves to:
//   - `p`            when `p` is strictly before `from` (unchanged);
//   - a shifted     position when `p` is strictly after `to` — the endpoint
//                    keeps its offset relative to `to`, measured against the
//                    insertion end (`from + L`);
//   - `from`         (left affinity) or `from + L` (right affinity) when
//                    `from <= p <= to` — the boundary / inside case resolved by
//                    stickiness. `forceMoveMarkers == true` forces right affinity.
//
// The stickiness → endpoint-affinity table lives in `MonaDecorationStickiness`
// (see MonaDecoration.swift). After every endpoint is repositioned the tree is
// rebuilt so the BST ordering and `maxEnd` augmentation reflect the new
// positions; a query in post-edit coordinates therefore returns the moved
// decorations. (Monaco re-keys in place inside `IntervalTree.resolve`; this
// port rebuilds the balanced tree, which yields the same O(log n) height and
// the same observable query results.)
//
// `MonaDecorationTextLength` is the line/column span of an inserted text — the
// Swift counterpart of Monaco's text-length position delta. `add(to:)` returns
// the position of the inserted text's end relative to its start.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The line/column span of an inserted text, used by `MonaDecorationTree`
/// range movement.
///
/// `lineDelta` is the number of newlines in the text. `columnDelta` is the
/// number of UTF-16 code units on the final line. `add(to:)` resolves the end
/// position of the inserted text relative to its start:
///   - when `lineDelta == 0`, the end is on the same line, column advanced by
///     `columnDelta`;
///   - when `lineDelta > 0`, the end is on a new line, `lineDelta` lines below
///     the start, at column `columnDelta + 1` (1-based — a fresh line starts at
///     column 1, so `columnDelta` chars occupy columns 1..`columnDelta`).
public struct MonaDecorationTextLength: Equatable, Sendable {

    /// The number of newlines in the inserted text.
    public let lineDelta: Int

    /// The number of UTF-16 code units on the final line of the inserted text.
    public let columnDelta: Int

    /// Creates a text length from its line/column components.
    public init(lineDelta: Int, columnDelta: Int) {
        self.lineDelta = lineDelta
        self.columnDelta = columnDelta
    }

    /// Creates a text length from the inserted text, counting newlines and the
    /// trailing code units on the final line.
    public init(text: String) {
        var lines = 0
        var last = 0
        for unit in text.utf16 {
            if unit == 0x000A {
                lines += 1
                last = 0
            } else {
                last += 1
            }
        }
        self.lineDelta = lines
        self.columnDelta = last
    }

    /// Returns the end position of the inserted text relative to `position`
    /// (the insertion start).
    public func add(to position: MonaPosition) -> MonaPosition {
        if lineDelta == 0 {
            return MonaPosition(line: position.line, column: position.column + columnDelta)
        }
        return MonaPosition(line: position.line + lineDelta, column: columnDelta + 1)
    }
}

/// An augmented interval tree over `MonaDecoration` ranges.
///
/// Insert, delete, query, and accept-edit are instrumented with operation
/// counters. The tree is the source of truth for the live (post-edit) range of
/// each decoration; `get(id:)` returns the current range after any range
/// movement.
public final class MonaDecorationTree {

    /// A node in the augmented interval tree.
    private final class Node {
        var decoration: MonaDecoration
        var left: Node?
        var right: Node?
        /// The maximum end position in this node's subtree (the augmentation).
        var maxEnd: MonaPosition

        init(decoration: MonaDecoration) {
            self.decoration = decoration
            self.maxEnd = decoration.range.endPosition
        }
    }

    /// The source of truth for the live decorations, keyed by id.
    private var nodesById: [String: MonaDecoration] = [:]

    /// The BST root, ordered by `range.startPosition` and augmented with
    /// `maxEnd`. Rebuilt from `nodesById` on every structural change and on
    /// every range movement.
    private var root: Node?

    // MARK: - Operation counters

    /// The number of `insert(_:)` calls.
    public private(set) var insertCount: Int = 0

    /// The number of `delete(id:)` calls (including no-op deletes).
    public private(set) var deleteCount: Int = 0

    /// The number of `query(_:)` calls.
    public private(set) var intervalQueryCount: Int = 0

    /// The number of owner-filtered queries (`query(_:ownerId:)` with a non-zero
    /// owner, and `allDecorations(ownerId:)` with a non-zero owner).
    public private(set) var ownerQueryCount: Int = 0

    /// Creates an empty decoration tree.
    public init() {}

    // MARK: - Structural operations

    /// Inserts (or, when `id` already exists, replaces) a decoration.
    @discardableResult
    public func insert(_ decoration: MonaDecoration) -> MonaDecoration {
        nodesById[decoration.id] = decoration
        insertCount += 1
        rebuild()
        return decoration
    }

    /// Deletes the decoration with the given id, returning it, or `nil` when no
    /// such decoration exists.
    @discardableResult
    public func delete(id: String) -> MonaDecoration? {
        deleteCount += 1
        guard let removed = nodesById.removeValue(forKey: id) else {
            return nil
        }
        rebuild()
        return removed
    }

    /// Removes every decoration. Does not change the operation counters.
    public func removeAll() {
        nodesById.removeAll()
        root = nil
    }

    /// Returns the decoration with the given id, or `nil` when no such
    /// decoration exists.
    public func get(id: String) -> MonaDecoration? {
        return nodesById[id]
    }

    /// The number of decorations in the tree.
    public func count() -> Int {
        return nodesById.count
    }

    // MARK: - Queries

    /// Returns every decoration whose range intersects `range` (touching
    /// counts), optionally owner-filtered.
    ///
    /// `ownerId == 0` means "all owners". `filterOutValidation` is reserved
    /// for validation-owner filtering (no decoration is currently flagged as
    /// validation, so it filters nothing).
    public func query(
        _ range: MonaRange,
        ownerId: Int = 0,
        filterOutValidation: Bool = false
    ) -> [MonaDecoration] {
        intervalQueryCount += 1
        if ownerId != 0 {
            ownerQueryCount += 1
        }
        var result: [MonaDecoration] = []
        queryNode(root, range, ownerId, filterOutValidation, &result)
        return result
    }

    /// Returns every decoration in the tree, optionally owner-filtered, sorted
    /// by id.
    public func allDecorations(
        ownerId: Int = 0,
        filterOutValidation: Bool = false
    ) -> [MonaDecoration] {
        if ownerId != 0 {
            ownerQueryCount += 1
        }
        var all = Array(nodesById.values)
        if ownerId != 0 {
            all = all.filter { $0.ownerId == ownerId }
        }
        if filterOutValidation {
            all = all.filter { !isValidation($0) }
        }
        return all.sorted { $0.id < $1.id }
    }

    // MARK: - Range movement on edit

    /// Repositions every decoration for an edit that replaces the region
    /// `[from, to)` with text of length `textLength`.
    ///
    /// Endpoints strictly before `from` are unchanged; endpoints strictly after
    /// `to` keep their offset relative to `to`, measured against the insertion
    /// end; endpoints inside `[from, to]` (inclusive of both boundaries) are
    /// resolved by stickiness. `forceMoveMarkers == true` forces right affinity
    /// at the boundary.
    public func acceptEdit(
        from: MonaPosition,
        to: MonaPosition,
        textLength: MonaDecorationTextLength,
        forceMoveMarkers: Bool
    ) {
        guard !nodesById.isEmpty else { return }
        let insertionEnd = textLength.add(to: from)
        var updated: [String: MonaDecoration] = [:]
        updated.reserveCapacity(nodesById.count)
        for (id, var decoration) in nodesById {
            let startSticksLeft = forceMoveMarkers ? false : decoration.stickiness.startSticksLeft
            let endSticksLeft = forceMoveMarkers ? false : decoration.stickiness.endSticksLeft
            let newStart = resolve(
                decoration.range.startPosition,
                sticksLeft: startSticksLeft,
                from: from,
                to: to,
                insertionEnd: insertionEnd
            )
            let newEnd = resolve(
                decoration.range.endPosition,
                sticksLeft: endSticksLeft,
                from: from,
                to: to,
                insertionEnd: insertionEnd
            )
            decoration.range = MonaRange(startPosition: newStart, endPosition: newEnd)
            updated[id] = decoration
        }
        nodesById = updated
        rebuild()
    }

    /// Resolves a single endpoint position for an edit replacing `[from, to)`
    /// with text ending at `insertionEnd`.
    private func resolve(
        _ position: MonaPosition,
        sticksLeft: Bool,
        from: MonaPosition,
        to: MonaPosition,
        insertionEnd: MonaPosition
    ) -> MonaPosition {
        if position < from {
            // Strictly before the edit — unchanged.
            return position
        }
        if position > to {
            // Strictly after the edit — keep the offset relative to `to`,
            // measured against the insertion end.
            let relativeLine = position.line - to.line
            if relativeLine == 0 {
                return MonaPosition(
                    line: insertionEnd.line,
                    column: insertionEnd.column + (position.column - to.column)
                )
            }
            return MonaPosition(
                line: insertionEnd.line + relativeLine,
                column: position.column
            )
        }
        // `from <= position <= to` — the boundary / inside case. Resolve by
        // stickiness: left affinity sticks before the edit (resolves to `from`);
        // right affinity sticks after the edit (resolves to the insertion end).
        if sticksLeft {
            return from
        }
        return insertionEnd
    }

    /// `true` when `decoration` is a validation decoration to be filtered out by
    /// `filterOutValidation`. No decoration is currently flagged as validation;
    /// the hook is reserved for the validation-owner projection.
    private func isValidation(_ decoration: MonaDecoration) -> Bool {
        return false
    }

    // MARK: - Tree build / augmentation / query traversal

    /// Rebuilds the balanced BST and its `maxEnd` augmentation from `nodesById`.
    private func rebuild() {
        let sorted = nodesById.values.sorted { $0.range.startPosition < $1.range.startPosition }
        root = build(sorted, 0, sorted.count)
    }

    /// Builds a balanced subtree from the sorted decorations in `arr[lo..<hi]`.
    private func build(_ arr: [MonaDecoration], _ lo: Int, _ hi: Int) -> Node? {
        if lo >= hi {
            return nil
        }
        let mid = (lo + hi) / 2
        let node = Node(decoration: arr[mid])
        node.left = build(arr, lo, mid)
        node.right = build(arr, mid + 1, hi)
        recomputeMaxEnd(node)
        return node
    }

    /// Recomputes `maxEnd` for `node` from its own end and its children's
    /// `maxEnd`.
    private func recomputeMaxEnd(_ node: Node?) {
        guard let node = node else {
            return
        }
        var maximum = node.decoration.range.endPosition
        if let left = node.left, left.maxEnd > maximum {
            maximum = left.maxEnd
        }
        if let right = node.right, right.maxEnd > maximum {
            maximum = right.maxEnd
        }
        node.maxEnd = maximum
    }

    /// In-order interval traversal: appends every decoration in the subtree
    /// rooted at `node` whose range intersects `range` and passes the owner /
    /// validation filters.
    private func queryNode(
        _ node: Node?,
        _ range: MonaRange,
        _ ownerId: Int,
        _ filterOutValidation: Bool,
        _ result: inout [MonaDecoration]
    ) {
        guard let node = node else {
            return
        }
        // Prune: when this subtree's maximum end is strictly before the query
        // start, nothing in the subtree can intersect (touching is not strictly
        // before, so a touching subtree is kept).
        if node.maxEnd < range.startPosition {
            return
        }
        queryNode(node.left, range, ownerId, filterOutValidation, &result)

        let decoration = node.decoration
        if decoration.range.intersects(range) {
            let ownerMatches = (ownerId == 0 || decoration.ownerId == ownerId)
            let validationFiltered = filterOutValidation && isValidation(decoration)
            if ownerMatches && !validationFiltered {
                result.append(decoration)
            }
        }

        // Prune the right subtree: when this decoration's start is strictly
        // after the query end, the right subtree (whose starts sort at or after
        // this node's start) cannot intersect either.
        if !(decoration.range.startPosition > range.endPosition) {
            queryNode(node.right, range, ownerId, filterOutValidation, &result)
        }
    }
}
