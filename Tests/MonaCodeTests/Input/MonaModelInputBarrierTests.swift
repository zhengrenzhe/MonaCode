// MonaModelInputBarrierTests.swift
//
// P04-T005 — Replicate multi-cursor input through ModelInputBarrier.
//
// Verifies the two Core input types that carry a multi-cursor edit through the
// transactional mutation path:
//
//   - `MonaMultiCursorInputPlan` — the multi-cursor edit plan: a primary
//                                   cursor edit plus zero or more secondary
//                                   cursor edits, with replication rules for
//                                   overlap (merge or reject), merge (adjacent
//                                   edits combine), ordering (reverse
//                                   start-offset application), snippet
//                                   (tabstop placeholders replicated per
//                                   cursor), clipboard (paste replicated per
//                                   cursor), and composition (IME marked text
//                                   replicated per cursor).
//   - `MonaModelInputBarrier`    — prepares primary + secondary cursor edits
//                                   against ONE immutable model version
//                                   (captured at the start), applies the
//                                   replication rules before commit, and
//                                   publishes ALL cursor edits + selections in
//                                   ONE transaction through the P01-T009
//                                   transaction gateway — or publishes NONE
//                                   (atomic: any failure rolls back the entire
//                                   batch, leaving the model untouched).
//
// Test contract (P04-T005): capture-one-version; apply-replication-rules;
// all-or-none publication.

import XCTest
import MonaCode

final class MonaModelInputBarrierTests: XCTestCase {

    // MARK: - Helpers

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/m"))
    }

    private func pos(_ line: Int, _ column: Int) -> MonaPosition {
        return MonaPosition(line: line, column: column)
    }

    private func range(_ sl: Int, _ sc: Int, _ el: Int, _ ec: Int) -> MonaRange {
        return MonaRange(startLine: sl, startColumn: sc, endLine: el, endColumn: ec)
    }

    // MARK: - 1. MonaMultiCursorInputPlan: primary + secondary structure

    /// A plan holds a primary cursor edit and zero or more secondary cursor
    /// edits. `allEdits` exposes primary first, then secondary in order.
    func testPlanHoldsPrimaryAndSecondaryEdits() {
        let primary = MonaCursorInputEdit(
            range: range(1, 1, 1, 1),
            text: "X",
            kind: .text
        )
        let secondary = [
            MonaCursorInputEdit(range: range(2, 1, 2, 1), text: "X", kind: .text),
            MonaCursorInputEdit(range: range(3, 1, 3, 1), text: "X", kind: .text)
        ]
        let plan = MonaMultiCursorInputPlan(primary: primary, secondary: secondary)

        XCTAssertEqual(plan.primary, primary)
        XCTAssertEqual(plan.secondary, secondary)
        XCTAssertEqual(plan.allEdits.count, 3)
        XCTAssertEqual(plan.allEdits[0], primary)
        XCTAssertEqual(plan.allEdits[1], secondary[0])
        XCTAssertEqual(plan.allEdits[2], secondary[1])
    }

    // MARK: - 2. Replication: text across cursors

    /// Replicating a plain-text insertion across multiple cursor positions
    /// produces one edit per cursor, each a folded insertion at that cursor's
    /// position, all carrying the same text and `.text` kind.
    func testReplicateTextAcrossCursors() {
        let plan = MonaMultiCursorInputPlan.replicateText(
            cursorPositions: [pos(1, 1), pos(1, 4), pos(1, 7)],
            text: "Z"
        )

        XCTAssertEqual(plan.allEdits.count, 3)
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.kind == .text })
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.text == "Z" })
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.range.isFolded })
        XCTAssertEqual(plan.allEdits[0].range.startPosition, pos(1, 1))
        XCTAssertEqual(plan.allEdits[1].range.startPosition, pos(1, 4))
        XCTAssertEqual(plan.allEdits[2].range.startPosition, pos(1, 7))
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.tabstops.isEmpty })
    }

    // MARK: - 3. Replication: clipboard paste per cursor

    /// Replicating a clipboard paste across cursors produces one `.clipboard`
    /// edit per cursor, each carrying the same pasted text.
    func testReplicateClipboardPasteAcrossCursors() {
        let plan = MonaMultiCursorInputPlan.replicateClipboardPaste(
            cursorPositions: [pos(1, 1), pos(2, 1)],
            text: "pasted"
        )

        XCTAssertEqual(plan.allEdits.count, 2)
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.kind == .clipboard })
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.text == "pasted" })
    }

    // MARK: - 4. Replication: IME composition marked text per cursor

    /// Replicating IME composition marked text across cursors produces one
    /// `.composition` edit per cursor, each carrying the same marked text.
    func testReplicateCompositionMarkedTextAcrossCursors() {
        let plan = MonaMultiCursorInputPlan.replicateCompositionMarkedText(
            cursorPositions: [pos(1, 1), pos(1, 3)],
            markedText: "你好"
        )

        XCTAssertEqual(plan.allEdits.count, 2)
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.kind == .composition })
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.text == "你好" })
    }

    // MARK: - 5. Replication: snippet tabstops per cursor

    /// Replicating a snippet across cursors gives EACH cursor its own copy of
    /// the tabstop placeholders, expressed as offset pairs relative to that
    /// cursor's insertion start. Each cursor's edit carries the same template
    /// text and the same relative tabstops.
    func testReplicateSnippetReplicatesTabstopsPerCursor() {
        let template = MonaSnippetTemplate(
            text: "for (${1:i}) {}",
            tabstops: [
                MonaSnippetTabstop(index: 1, startOffset: 5, endOffset: 6)
            ]
        )
        let plan = MonaMultiCursorInputPlan.replicateSnippet(
            cursorPositions: [pos(1, 1), pos(2, 1)],
            template: template
        )

        XCTAssertEqual(plan.allEdits.count, 2)
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.kind == .snippet })
        XCTAssertTrue(plan.allEdits.allSatisfy { $0.text == "for (${1:i}) {}" })
        // Each cursor carries its own (identical, relative) tabstop.
        XCTAssertEqual(plan.allEdits[0].tabstops.count, 1)
        XCTAssertEqual(plan.allEdits[1].tabstops.count, 1)
        XCTAssertEqual(plan.allEdits[0].tabstops.first?.index, 1)
        XCTAssertEqual(plan.allEdits[0].tabstops.first?.startOffset, 5)
        XCTAssertEqual(plan.allEdits[0].tabstops.first?.endOffset, 6)
        XCTAssertEqual(plan.allEdits[0].tabstops, plan.allEdits[1].tabstops)
    }

    // MARK: - 6. Overlap rule: reject

    /// Two cursors editing OVERLAPPING ranges (strict intersection, not just
    /// touching) with different text cannot be merged; `resolvingConflicts`
    /// with the default `.reject` policy returns `nil`.
    func testOverlapRejectReturnsNil() {
        // "abcdef": edit [1,2..1,4) (replaces "bc") and [1,3..1,5) (replaces "cd")
        // — these ranges strictly overlap.
        let plan = MonaMultiCursorInputPlan(
            primary: MonaCursorInputEdit(range: range(1, 2, 1, 4), text: "BC"),
            secondary: [MonaCursorInputEdit(range: range(1, 3, 1, 5), text: "CD")]
        )

        XCTAssertNil(plan.resolvingConflicts(overlapPolicy: .reject),
            "strictly overlapping ranges with different text must reject")
    }

    // MARK: - 7. Overlap rule: merge identical overlapping

    /// Two cursors editing overlapping ranges with IDENTICAL text and kind
    /// merge into a single edit covering the union of the ranges, under the
    /// `.merge` policy.
    func testOverlapMergeCombinesIdenticalOverlapping() {
        // "abcdef": two cursors both inserting "X" over overlapping ranges
        // [1,2..1,4) and [1,3..1,5). With .merge and identical text/kind, the
        // union range is [1,2..1,5) and a single "X" is inserted.
        let plan = MonaMultiCursorInputPlan(
            primary: MonaCursorInputEdit(range: range(1, 2, 1, 4), text: "X", kind: .text),
            secondary: [MonaCursorInputEdit(range: range(1, 3, 1, 5), text: "X", kind: .text)]
        )

        let resolved = plan.resolvingConflicts(overlapPolicy: .merge)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.allEdits.count, 1, "identical overlapping edits merge into one")
        XCTAssertEqual(resolved?.allEdits.first?.range, range(1, 2, 1, 5))
        XCTAssertEqual(resolved?.allEdits.first?.text, "X")
    }

    // MARK: - 8. Merge rule: adjacent edits combine

    /// Two cursors editing ADJACENT ranges (one's end == the other's start)
    /// with the same kind combine into one edit whose range spans both and
    /// whose text is the concatenation.
    func testMergeCombinesAdjacentEdits() {
        // "abcdef": edit [1,1..1,2) inserts "A", edit [1,2..1,2) inserts "B".
        // Adjacent (touching) → merge into [1,1..1,2) inserting "AB".
        let plan = MonaMultiCursorInputPlan(
            primary: MonaCursorInputEdit(range: range(1, 1, 1, 2), text: "A", kind: .text),
            secondary: [MonaCursorInputEdit(range: range(1, 2, 1, 2), text: "B", kind: .text)]
        )

        let resolved = plan.resolvingConflicts(overlapPolicy: .reject)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.allEdits.count, 1, "adjacent same-kind edits merge into one")
        XCTAssertEqual(resolved?.allEdits.first?.range, range(1, 1, 1, 2))
        XCTAssertEqual(resolved?.allEdits.first?.text, "AB")
    }

    // MARK: - 9. Ordering rule: reverse start-offset

    /// `orderedOperations` returns the edit operations sorted in DESCENDING
    /// start-offset order so that applying them in this sequence preserves
    /// the offsets of edits not yet applied.
    func testOrderedOperationsReverseStartOffset() {
        let model = makeModel("abcdefghij")
        let plan = MonaMultiCursorInputPlan(
            primary: MonaCursorInputEdit(range: range(1, 1, 1, 1), text: "1"),
            secondary: [
                MonaCursorInputEdit(range: range(1, 5, 1, 5), text: "2"),
                MonaCursorInputEdit(range: range(1, 8, 1, 8), text: "3")
            ]
        )

        let ops = plan.orderedOperations(model: model)
        XCTAssertEqual(ops.count, 3)
        // Descending start offset: offset 7 (col 8), offset 4 (col 5), offset 0 (col 1).
        XCTAssertEqual(ops[0].range.startPosition, pos(1, 8))
        XCTAssertEqual(ops[1].range.startPosition, pos(1, 5))
        XCTAssertEqual(ops[2].range.startPosition, pos(1, 1))
        XCTAssertEqual(ops[0].text, "3")
        XCTAssertEqual(ops[1].text, "2")
        XCTAssertEqual(ops[2].text, "1")
    }

    // MARK: - 10. Resulting selections per cursor

    /// `resultingSelections` computes each cursor's post-edit selection as a
    /// collapsed caret at the end of its inserted text. For two non-overlapping
    /// insertions, each cursor lands just past its inserted text.
    func testResultingSelectionsPerCursor() {
        let model = makeModel("abcdef")
        // Insert "XY" at col 1 (offset 0) and "Z" at col 4 (offset 3).
        let plan = MonaMultiCursorInputPlan(
            primary: MonaCursorInputEdit(range: range(1, 1, 1, 1), text: "XY"),
            secondary: [MonaCursorInputEdit(range: range(1, 4, 1, 4), text: "Z")]
        )

        let selections = plan.resultingSelections(model: model)
        XCTAssertEqual(selections.count, 2)
        // Cursor 0: inserted "XY" (2 units) at offset 0 → offset 2 → col 3.
        // No smaller-offset edit shifts it (it IS the smallest).
        XCTAssertEqual(selections[0].anchor, pos(1, 3))
        XCTAssertEqual(selections[0].activePosition, pos(1, 3))
        // Cursor 1: inserted "Z" (1 unit) at offset 3, shifted by +2 from the
        // edit at offset 0 → final offset 6 → col 7.
        XCTAssertEqual(selections[1].anchor, pos(1, 7))
        XCTAssertEqual(selections[1].activePosition, pos(1, 7))
    }

    // MARK: - 11. Barrier: prepare captures model version

    /// `prepare` captures the model's current version id as the immutable
    /// version the edits are prepared against. The captured version is
    /// observable on the barrier and the prepared handle.
    func testPrepareCapturesModelVersion() {
        let model = makeModel("hello")
        let barrier = MonaModelInputBarrier(model: model)

        let v0 = model.getVersionId()
        let prepared = barrier.prepare(
            MonaMultiCursorInputPlan.replicateText(cursorPositions: [pos(1, 1)], text: "X")
        )

        XCTAssertEqual(barrier.capturedVersionId, v0)
        XCTAssertEqual(prepared.capturedVersionId, v0)
        XCTAssertEqual(prepared.capturedAlternativeVersionId, model.getAlternativeVersionId())
    }

    // MARK: - 12. Barrier: commit publishes all cursors in one transaction

    /// A clean multi-cursor commit applies EVERY cursor's edit through the
    /// transaction gateway as ONE transaction: one version bump, one
    /// content-change event, all selections recorded. The model text reflects
    /// every cursor's edit.
    func testCommitPublishesAllCursorsInOneTransaction() {
        let model = makeModel("abc def ghi")
        let barrier = MonaModelInputBarrier(model: model)

        var events: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { events.append($0) }
        defer { disposable.dispose() }

        let v0 = model.getVersionId()
        // Insert "X" at col 1 (offset 0), col 5 (offset 4), col 9 (offset 8).
        let plan = MonaMultiCursorInputPlan.replicateText(
            cursorPositions: [pos(1, 1), pos(1, 5), pos(1, 9)],
            text: "X"
        )

        let outcome = barrier.commit(plan)

        guard case .applied(let selections) = outcome else {
            return XCTFail("expected .applied, got \(outcome)")
        }
        XCTAssertEqual(model.getVersionId(), v0 + 1, "one transaction bumps the version exactly once")
        XCTAssertEqual(events.count, 1, "one transaction fires exactly one content-change event")
        XCTAssertEqual(events[0].changes.count, 3, "all three cursor edits are in the single batch")
        // Each cursor inserted "X"; resulting text has three X's inserted.
        XCTAssertEqual(model.getValue(), "Xabc Xdef Xghi")
        // Three selections, one per cursor.
        XCTAssertEqual(selections.count, 3)
    }

    // MARK: - 13. Barrier: atomic — overlap rejection publishes NONE

    /// When the plan contains overlapping edits that cannot be resolved
    /// (default `.reject` policy), the barrier publishes NOTHING: the model
    /// text, version, and events are all untouched. This is the all-or-none
    /// guarantee.
    func testCommitRollsBackAllOnOverlapRejection() {
        let model = makeModel("abcdef")
        let barrier = MonaModelInputBarrier(model: model)

        var events: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { events.append($0) }
        defer { disposable.dispose() }

        let v0 = model.getVersionId()
        // Overlapping ranges with different text → rejected.
        let plan = MonaMultiCursorInputPlan(
            primary: MonaCursorInputEdit(range: range(1, 2, 1, 4), text: "BC"),
            secondary: [MonaCursorInputEdit(range: range(1, 3, 1, 5), text: "CD")]
        )

        let outcome = barrier.commit(plan)

        if case .rolledBack = outcome {
            // ok
        } else {
            XCTFail("expected .rolledBack for overlap rejection, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "abcdef", "overlap rejection must not mutate the model text")
        XCTAssertEqual(model.getVersionId(), v0, "overlap rejection must not bump the version")
        XCTAssertTrue(events.isEmpty, "overlap rejection must fire no events")
    }

    // MARK: - 14. Barrier: atomic — validation failure publishes NONE

    /// When any prepared edit's range is invalid (the model would clamp it),
    /// the transaction gateway rolls back the WHOLE batch: the model is
    /// untouched even though some edits were valid. This is the all-or-none
    /// guarantee inherited from the transaction gateway.
    func testCommitRollsBackAllOnValidationFailure() {
        let model = makeModel("abc")
        let barrier = MonaModelInputBarrier(model: model)

        var events: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { events.append($0) }
        defer { disposable.dispose() }

        let v0 = model.getVersionId()
        // One valid edit and one edit whose range is out of bounds (line 99).
        let plan = MonaMultiCursorInputPlan(
            primary: MonaCursorInputEdit(range: range(1, 1, 1, 1), text: "X"),
            secondary: [MonaCursorInputEdit(range: range(99, 1, 99, 1), text: "Y")]
        )

        let outcome = barrier.commit(plan)

        if case .rolledBack = outcome {
            // ok
        } else {
            XCTFail("expected .rolledBack for validation failure, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "abc", "validation failure must not mutate the model text")
        XCTAssertEqual(model.getVersionId(), v0, "validation failure must not bump the version")
        XCTAssertTrue(events.isEmpty, "validation failure must fire no events")
    }

    // MARK: - 15. Barrier: stale version drops (publishes NONE)

    /// If the model was mutated directly between `prepare` and `commit`
    /// (bypassing the barrier), the captured version diverges and the barrier
    /// DROPS the input: no edits applied, no events fired, model untouched by
    /// the barrier (the direct mutation remains).
    func testCommitDropsOnStaleVersion() {
        let model = makeModel("abc")
        let barrier = MonaModelInputBarrier(model: model)

        let prepared = barrier.prepare(
            MonaMultiCursorInputPlan.replicateText(cursorPositions: [pos(1, 1)], text: "X")
        )

        // Direct mutation bypassing the barrier: bumps the version.
        model.setValue("abcdef")

        var events: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { events.append($0) }
        defer { disposable.dispose() }

        let vAfterMutation = model.getVersionId()
        let outcome = barrier.commit(prepared)

        if case .dropped = outcome {
            // ok
        } else {
            XCTFail("expected .dropped for stale version, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "abcdef", "stale drop must not mutate the model further")
        XCTAssertEqual(model.getVersionId(), vAfterMutation, "stale drop must not bump the version")
        XCTAssertTrue(events.isEmpty, "stale drop must fire no events")
    }

    // MARK: - 16. Barrier: commit records selections per cursor

    /// A successful commit records the per-cursor resulting selections on the
    /// transaction gateway's `lastCommittedSelections`, so the committed unit
    /// carries the post-edit cursor state forward.
    func testCommitRecordsSelectionsPerCursorOnGateway() {
        let model = makeModel("ab cd")
        let gateway = MonaTransactionGateway(model: model)
        let barrier = MonaModelInputBarrier(model: model, gateway: gateway)

        // Insert "X" at col 1 (offset 0) and col 4 (offset 3).
        let plan = MonaMultiCursorInputPlan.replicateText(
            cursorPositions: [pos(1, 1), pos(1, 4)],
            text: "X"
        )

        let outcome = barrier.commit(plan)

        guard case .applied(let selections) = outcome else {
            return XCTFail("expected .applied, got \(outcome)")
        }
        XCTAssertEqual(gateway.lastCommittedSelections.count, 2)
        XCTAssertEqual(gateway.lastCommittedSelections, selections)
        // Cursor 0: inserted "X" at offset 0 → offset 1 → col 2.
        XCTAssertEqual(selections[0].anchor, pos(1, 2))
        // Cursor 1: inserted "X" at offset 3, shifted +1 by cursor 0 → offset 5 → col 6.
        XCTAssertEqual(selections[1].anchor, pos(1, 6))
    }
}
