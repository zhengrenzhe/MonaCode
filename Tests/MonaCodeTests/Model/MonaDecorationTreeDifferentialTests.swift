// MonaDecorationTreeDifferentialTests.swift
//
// P02-T002 — Port decoration interval trees and stickiness semantics.
//
// Verifies the differential contract for `MonaDecoration`,
// `MonaDecorationTree` (an augmented interval tree: insert / delete / query by
// range / owner filter / range movement on edit / stickiness updates / operation
// counters), and `MonaDecorationCollection`. The interval tree is the Swift
// counterpart of Monaco's `IntervalTree` (monaco-editor 0.56.0); stickiness is
// the Swift counterpart of Monaco's `TrackedRangeStickiness`.
//
// Test contract (P02-T002): decoration value type (range + options + stickiness +
// owner); interval tree insert/delete/query/owner-filter/range-movement/
// stickiness; decoration collection add/remove/query.

import XCTest
import MonaCode

final class MonaDecorationTreeDifferentialTests: XCTestCase {

    // MARK: - Helpers

    private func dec(
        _ id: String,
        _ startLine: Int,
        _ startColumn: Int,
        _ endLine: Int,
        _ endColumn: Int,
        ownerId: Int = 0,
        stickiness: MonaDecorationStickiness = .alwaysGrowsWhenTypingAtEdges
    ) -> MonaDecoration {
        return MonaDecoration(
            id: id,
            range: MonaRange(
                startLine: startLine,
                startColumn: startColumn,
                endLine: endLine,
                endColumn: endColumn
            ),
            ownerId: ownerId,
            stickiness: stickiness
        )
    }

    // MARK: - 1. MonaDecoration: value type (range + options + stickiness + owner)

    /// A decoration captures an id, a normalized range, owner id, stickiness, and
    /// options. Two decorations with equal fields compare equal.
    func testDecorationCapturesRangeOptionsStickinessOwner() {
        let d = MonaDecoration(
            id: "d1",
            range: MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 4),
            ownerId: 7,
            stickiness: .growsOnlyWhenTypingBefore,
            options: MonaDecorationOptions(isWholeLine: true, inlineClassName: "hl")
        )
        XCTAssertEqual(d.id, "d1")
        XCTAssertEqual(d.range, MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 4))
        XCTAssertEqual(d.ownerId, 7)
        XCTAssertEqual(d.stickiness, .growsOnlyWhenTypingBefore)
        XCTAssertEqual(d.options.isWholeLine, true)
        XCTAssertEqual(d.options.inlineClassName, "hl")

        let d2 = MonaDecoration(
            id: "d1",
            range: MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 4),
            ownerId: 7,
            stickiness: .growsOnlyWhenTypingBefore,
            options: MonaDecorationOptions(isWholeLine: true, inlineClassName: "hl")
        )
        XCTAssertEqual(d, d2, "two decorations with equal fields compare equal")
    }

    /// All four tracked-range stickiness values are distinct.
    func testStickinessHasFourDistinctCases() {
        let cases: [MonaDecorationStickiness] = [
            .alwaysGrowsWhenTypingAtEdges,
            .neverGrowsWhenTypingAtEdges,
            .growsOnlyWhenTypingBefore,
            .growsOnlyWhenTypingAfter
        ]
        XCTAssertEqual(Set(cases).count, 4, "there are four distinct stickiness values")
    }

    /// The default owner id is 0 and the default options are empty.
    func testDecorationDefaults() {
        let d = MonaDecoration(
            id: "x",
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1)
        )
        XCTAssertEqual(d.ownerId, 0, "default owner id is 0")
        XCTAssertEqual(d.stickiness, .alwaysGrowsWhenTypingAtEdges, "default stickiness")
        XCTAssertEqual(d.options, MonaDecorationOptions())
    }

    // MARK: - 2. MonaDecorationTree: insert / delete / query

    /// `insert(_:)` grows the tree and `count` reflects the size; `get(id:)`
    /// returns the stored decoration by id.
    func testInsertGrowsTreeAndGetById() {
        let tree = MonaDecorationTree()
        XCTAssertEqual(tree.count(), 0)

        tree.insert(dec("a", 1, 1, 1, 5))
        tree.insert(dec("b", 1, 3, 1, 8))
        tree.insert(dec("c", 2, 1, 3, 4))

        XCTAssertEqual(tree.count(), 3)
        XCTAssertEqual(tree.get(id: "a")?.range, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 5))
        XCTAssertEqual(tree.get(id: "b")?.range, MonaRange(startLine: 1, startColumn: 3, endLine: 1, endColumn: 8))
        XCTAssertEqual(tree.get(id: "c")?.range, MonaRange(startLine: 2, startColumn: 1, endLine: 3, endColumn: 4))
        XCTAssertNil(tree.get(id: "missing"), "get returns nil for an unknown id")
    }

    /// Inserting a decoration whose id already exists replaces the stored range.
    func testInsertWithExistingIdReplaces() {
        let tree = MonaDecorationTree()
        tree.insert(dec("a", 1, 1, 1, 5))
        tree.insert(dec("a", 2, 2, 4, 9))

        XCTAssertEqual(tree.count(), 1, "re-inserting an id replaces, not duplicates")
        XCTAssertEqual(tree.get(id: "a")?.range, MonaRange(startLine: 2, startColumn: 2, endLine: 4, endColumn: 9))
    }

    /// `delete(id:)` removes a decoration and returns it; deleting an unknown id
    /// returns nil and does not change the count.
    func testDeleteRemovesAndReturns() {
        let tree = MonaDecorationTree()
        tree.insert(dec("a", 1, 1, 1, 5))
        tree.insert(dec("b", 1, 3, 1, 8))

        let removed = tree.delete(id: "a")
        XCTAssertEqual(removed?.id, "a")
        XCTAssertEqual(tree.count(), 1)
        XCTAssertNil(tree.get(id: "a"))
        XCTAssertNotNil(tree.get(id: "b"))

        XCTAssertNil(tree.delete(id: "a"), "deleting an unknown id returns nil")
        XCTAssertEqual(tree.count(), 1, "deleting an unknown id does not change the count")
    }

    // MARK: - 3. Interval query + owner filter

    /// `query(_:)` returns every decoration whose range intersects the query
    /// range (touching counts as intersecting). Decorations entirely outside are
    /// excluded.
    func testQueryReturnsIntersectingDecorations() {
        let tree = MonaDecorationTree()
        tree.insert(dec("before", 1, 1, 1, 2))   // entirely before
        tree.insert(dec("touch", 1, 2, 1, 4))     // touches at (1,2)-(1,4)
        tree.insert(dec("overlap", 1, 3, 1, 7))   // overlaps
        tree.insert(dec("after", 1, 9, 1, 12))    // entirely after

        let hits = tree.query(MonaRange(startLine: 1, startColumn: 4, endLine: 1, endColumn: 6))
            .map { $0.id }.sorted()
        XCTAssertEqual(hits, ["overlap", "touch"], "touching and overlapping decorations are returned; before/after are excluded")
    }

    /// `query(_:ownerId:)` filters by owner: only decorations whose owner id
    /// matches (or ownerId == 0 meaning "all owners") are returned.
    func testQueryFiltersByOwner() {
        let tree = MonaDecorationTree()
        tree.insert(dec("o1a", 1, 1, 1, 5, ownerId: 1))
        tree.insert(dec("o2a", 1, 2, 1, 6, ownerId: 2))
        tree.insert(dec("o1b", 1, 3, 1, 7, ownerId: 1))
        tree.insert(dec("o2b", 1, 4, 1, 8, ownerId: 2))

        let owner1 = tree.query(
            MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 10),
            ownerId: 1
        ).map { $0.id }.sorted()
        XCTAssertEqual(owner1, ["o1a", "o1b"], "owner filter returns only owner 1 decorations")

        let owner2 = tree.query(
            MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 10),
            ownerId: 2
        ).map { $0.id }.sorted()
        XCTAssertEqual(owner2, ["o2a", "o2b"], "owner filter returns only owner 2 decorations")

        let all = tree.query(
            MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 10),
            ownerId: 0
        ).map { $0.id }.sorted()
        XCTAssertEqual(all, ["o1a", "o1b", "o2a", "o2b"], "ownerId 0 returns decorations from all owners")
    }

    /// `allDecorations(ownerId:)` returns every decoration in the tree, optional
    /// owner-filtered, in a stable id-sorted order.
    func testAllDecorations() {
        let tree = MonaDecorationTree()
        tree.insert(dec("c", 1, 1, 1, 2, ownerId: 1))
        tree.insert(dec("a", 1, 1, 1, 2, ownerId: 2))
        tree.insert(dec("b", 1, 1, 1, 2, ownerId: 1))

        XCTAssertEqual(tree.allDecorations().map { $0.id }.sorted(), ["a", "b", "c"])
        XCTAssertEqual(tree.allDecorations(ownerId: 1).map { $0.id }.sorted(), ["b", "c"])
    }

    // MARK: - 4. Operation-count instrumentation

    /// The tree counts insert, delete, interval-query, and owner-query
    /// operations.
    func testOperationCounters() {
        let tree = MonaDecorationTree()
        tree.insert(dec("a", 1, 1, 1, 5))
        tree.insert(dec("b", 1, 3, 1, 8))
        XCTAssertEqual(tree.insertCount, 2)

        _ = tree.delete(id: "a")
        XCTAssertEqual(tree.deleteCount, 1)

        _ = tree.query(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 10))
        XCTAssertEqual(tree.intervalQueryCount, 1)

        _ = tree.query(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 10), ownerId: 1)
        XCTAssertEqual(tree.ownerQueryCount, 1)

        _ = tree.allDecorations(ownerId: 1)
        XCTAssertEqual(tree.ownerQueryCount, 2, "an owner-filtered all query counts as an owner query")
    }

    // MARK: - 5. Range movement on edit (single-line insertion at the start edge)

    /// Inserting text exactly at a decoration's start edge resolves the start
    /// position by stickiness:
    ///   - alwaysGrowsWhenTypingAtEdges / growsOnlyWhenTypingBefore → start stays
    ///     (the range grows to include the inserted text).
    ///   - neverGrowsWhenTypingAtEdges / growsOnlyWhenTypingAfter → start moves
    ///     forward past the inserted text (the range does not grow).
    func testRangeMovementInsertAtStartEdgeByStickiness() {
        let stickinessBehaviors: [(MonaDecorationStickiness, MonaPosition)] = [
            (.alwaysGrowsWhenTypingAtEdges, MonaPosition(line: 1, column: 3)),
            (.neverGrowsWhenTypingAtEdges,  MonaPosition(line: 1, column: 5)),
            (.growsOnlyWhenTypingBefore,    MonaPosition(line: 1, column: 3)),
            (.growsOnlyWhenTypingAfter,     MonaPosition(line: 1, column: 5))
        ]
        for (stickiness, expectedStart) in stickinessBehaviors {
            let tree = MonaDecorationTree()
            // Decoration (1,3)-(1,5) over the text. Insert "XY" at (1,3).
            tree.insert(dec("d", 1, 3, 1, 5, stickiness: stickiness))
            tree.acceptEdit(
                from: MonaPosition(line: 1, column: 3),
                to: MonaPosition(line: 1, column: 3),
                textLength: MonaDecorationTextLength(text: "XY"),
                forceMoveMarkers: false
            )
            let resolved = tree.get(id: "d")?.range
            XCTAssertEqual(
                resolved?.startPosition,
                expectedStart,
                "stickiness \(stickiness) resolved start = \(expectedStart) after insert at start edge"
            )
            // The end is after the edit, so it shifts right by 2 in every case.
            XCTAssertEqual(
                resolved?.endPosition,
                MonaPosition(line: 1, column: 7),
                "stickiness \(stickiness): end shifts right by the inserted length"
            )
        }
    }

    /// Inserting text exactly at a decoration's end edge resolves the end
    /// position by stickiness:
    ///   - alwaysGrowsWhenTypingAtEdges / growsOnlyWhenTypingAfter → end moves
    ///     forward (the range grows).
    ///   - neverGrowsWhenTypingAtEdges / growsOnlyWhenTypingBefore → end stays
    ///     (the range does not grow).
    func testRangeMovementInsertAtEndEdgeByStickiness() {
        let stickinessBehaviors: [(MonaDecorationStickiness, MonaPosition)] = [
            (.alwaysGrowsWhenTypingAtEdges, MonaPosition(line: 1, column: 7)),
            (.neverGrowsWhenTypingAtEdges,  MonaPosition(line: 1, column: 5)),
            (.growsOnlyWhenTypingBefore,    MonaPosition(line: 1, column: 5)),
            (.growsOnlyWhenTypingAfter,     MonaPosition(line: 1, column: 7))
        ]
        for (stickiness, expectedEnd) in stickinessBehaviors {
            let tree = MonaDecorationTree()
            tree.insert(dec("d", 1, 3, 1, 5, stickiness: stickiness))
            tree.acceptEdit(
                from: MonaPosition(line: 1, column: 5),
                to: MonaPosition(line: 1, column: 5),
                textLength: MonaDecorationTextLength(text: "XY"),
                forceMoveMarkers: false
            )
            let resolved = tree.get(id: "d")?.range
            XCTAssertEqual(
                resolved?.startPosition,
                MonaPosition(line: 1, column: 3),
                "stickiness \(stickiness): start is before the edit and stays put"
            )
            XCTAssertEqual(
                resolved?.endPosition,
                expectedEnd,
                "stickiness \(stickiness) resolved end = \(expectedEnd) after insert at end edge"
            )
        }
    }

    /// Decorations entirely before an edit are unchanged; decorations entirely
    /// after an edit shift by the net (inserted - deleted) length.
    func testRangeMovementBeforeAndAfterEdit() {
        let tree = MonaDecorationTree()
        tree.insert(dec("before", 1, 1, 1, 2))   // entirely before
        tree.insert(dec("after",  1, 9, 1, 12))  // entirely after
        // Replace (1,3)-(1,5) (delete 2 chars) with "XYZW" (4 chars): net +2.
        tree.acceptEdit(
            from: MonaPosition(line: 1, column: 3),
            to: MonaPosition(line: 1, column: 5),
            textLength: MonaDecorationTextLength(text: "XYZW"),
            forceMoveMarkers: false
        )
        XCTAssertEqual(tree.get(id: "before")?.range, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2), "a decoration before the edit is unchanged")
        // from=(1,3), to=(1,5), inserted=4 → insertionEnd=(1,7). End (1,12): relLine 0,
        // newCol = 7 + (12 - 5) = 14. Start (1,9) → 7 + (9-5) = 11.
        XCTAssertEqual(tree.get(id: "after")?.range, MonaRange(startLine: 1, startColumn: 11, endLine: 1, endColumn: 14), "a decoration after the edit shifts by the net (inserted - deleted) length")
    }

    /// A multi-line insertion advances the line number and resets the column on
    /// the new line for decorations after the edit.
    func testRangeMovementMultilineInsert() {
        let tree = MonaDecorationTree()
        tree.insert(dec("after", 1, 9, 2, 4))
        // Insert "a\nbc" at (1,3): lineDelta=1, end column on new line = 2 + 1 = 3.
        // insertionEnd = (2, 3). The "after" decoration (1,9)-(2,4): start (1,9) is
        // on the same line as `to`=(1,3) → relLine 0, newCol = 3 + (9-3) = 9? No:
        // start.line (1) != to.line (1)? They are equal → relLine 0, newCol = 3 + (9-3) = 9,
        // line = insertionEnd.line = 2 → (2, 9). end (2,4): relLine = 2-1 = 1 →
        // (insertionEnd.line + 1, 4) = (3, 4).
        tree.acceptEdit(
            from: MonaPosition(line: 1, column: 3),
            to: MonaPosition(line: 1, column: 3),
            textLength: MonaDecorationTextLength(text: "a\nbc"),
            forceMoveMarkers: false
        )
        XCTAssertEqual(
            tree.get(id: "after")?.range,
            MonaRange(startLine: 2, startColumn: 9, endLine: 3, endColumn: 4),
            "a multi-line insert shifts a same-line start onto the new line and bumps later lines"
        )
    }

    /// `forceMoveMarkers == true` overrides stickiness so an endpoint exactly at
    /// the edit boundary moves with the inserted text.
    func testRangeMovementForceMoveMarkers() {
        let tree = MonaDecorationTree()
        // alwaysGrows would keep the start at (1,3); forceMoveMarkers moves it.
        tree.insert(dec("d", 1, 3, 1, 5, stickiness: .alwaysGrowsWhenTypingAtEdges))
        tree.acceptEdit(
            from: MonaPosition(line: 1, column: 3),
            to: MonaPosition(line: 1, column: 3),
            textLength: MonaDecorationTextLength(text: "XY"),
            forceMoveMarkers: true
        )
        XCTAssertEqual(
            tree.get(id: "d")?.range,
            MonaRange(startLine: 1, startColumn: 5, endLine: 1, endColumn: 7),
            "forceMoveMarkers overrides stickiness and moves the boundary endpoint forward"
        )
    }

    /// After range movement the tree is re-ordered, so a query in the new
    /// coordinates returns the moved decoration.
    func testQueryAfterRangeMovement() {
        let tree = MonaDecorationTree()
        tree.insert(dec("mover", 1, 3, 1, 5, stickiness: .alwaysGrowsWhenTypingAtEdges))
        tree.acceptEdit(
            from: MonaPosition(line: 1, column: 3),
            to: MonaPosition(line: 1, column: 3),
            textLength: MonaDecorationTextLength(text: "XY"),
            forceMoveMarkers: false
        )
        // The mover grew to (1,3)-(1,7). A query at (1,6)-(1,6) now hits it.
        let hits = tree.query(MonaRange(startLine: 1, startColumn: 6, endLine: 1, endColumn: 6))
            .map { $0.id }
        XCTAssertEqual(hits, ["mover"], "a query in post-edit coordinates reflects the moved range")
    }

    // MARK: - 6. MonaDecorationCollection

    /// A collection holds decorations for a model: add grows it, remove shrinks
    /// it, and range queries return the intersecting decorations.
    func testCollectionAddRemoveQuery() {
        var collection = MonaDecorationCollection()
        XCTAssertEqual(collection.count(), 0)

        collection.add(dec("a", 1, 1, 1, 5))
        collection.add(dec("b", 1, 8, 1, 12))
        collection.add(dec("c", 2, 1, 2, 9))
        XCTAssertEqual(collection.count(), 3)

        let hits = collection.decorations(in: MonaRange(startLine: 1, startColumn: 4, endLine: 1, endColumn: 10))
            .map { $0.id }.sorted()
        XCTAssertEqual(hits, ["a", "b"], "the collection returns intersecting decorations")

        collection.remove(id: "a")
        XCTAssertEqual(collection.count(), 2)
        XCTAssertNil(collection.decorations(in: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 5)).first { $0.id == "a" })

        let all = collection.allDecorations().map { $0.id }.sorted()
        XCTAssertEqual(all, ["b", "c"])
    }

    /// A collection can be filtered by owner.
    func testCollectionOwnerFilter() {
        var collection = MonaDecorationCollection()
        collection.add(dec("o1", 1, 1, 1, 5, ownerId: 1))
        collection.add(dec("o2", 1, 1, 1, 5, ownerId: 2))
        collection.add(dec("o1b", 1, 1, 1, 5, ownerId: 1))

        XCTAssertEqual(collection.allDecorations(ownerId: 1).map { $0.id }.sorted(), ["o1", "o1b"])
        XCTAssertEqual(collection.allDecorations(ownerId: 2).map { $0.id }, ["o2"])
        XCTAssertEqual(collection.allDecorations().map { $0.id }.sorted(), ["o1", "o1b", "o2"])
    }

    /// Clearing a collection empties it.
    func testCollectionClear() {
        var collection = MonaDecorationCollection()
        collection.add(dec("a", 1, 1, 1, 5))
        collection.add(dec("b", 1, 8, 1, 12))
        collection.clear()
        XCTAssertEqual(collection.count(), 0)
        XCTAssertTrue(collection.allDecorations().isEmpty)
    }
}
