// MonaUndoRedoTests.swift
//
// P02-T001 — Implement undo and redo elements on transaction truth.
//
// Verifies that `MonaUndoRedoElement` is an immutable snapshot of one edit group
// (operations, before/after version, EOL changes, selection recovery, and
// alternative-version transitions) and that `MonaUndoRedoStack` manages the
// undo/redo LIFO lists, routes every replay mutation through the same
// `MonaTransactionGateway` as direct edits, and rolls back the stack position
// when a replay transaction fails (dropped or rolled back by the gateway).
//
// Test contract (P02-T001): element captures edit group + EOL + selections +
// alternative version; stack push/undo/redo; route through transaction gateway;
// rollback stack position on replay failure.

import XCTest
import MonaCode

final class MonaUndoRedoTests: XCTestCase {

    // MARK: - Helpers

    /// A convenience URI for the test models.
    private func testURI() -> MonaURI {
        return MonaURI(scheme: "inmemory", path: "/undo-test")
    }

    // MARK: - 1. MonaUndoRedoElement: edit grouping

    /// An element captures the forward operations (redo) and the reverse
    /// operations (undo) as an immutable snapshot, plus the before/after version
    /// ids that bracket the edit group.
    func testElementCapturesEditGroupAndVersionRange() {
        let forward = [
            MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "X"
            )
        ]
        let reverse = [
            MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )
        ]
        let element = MonaUndoRedoElement(
            label: "insert-X",
            operations: forward,
            reverseOperations: reverse,
            beforeVersionId: 1,
            afterVersionId: 2,
            beforeAlternativeVersionId: 1,
            afterAlternativeVersionId: 1
        )

        XCTAssertEqual(element.label, "insert-X")
        XCTAssertEqual(element.operations, forward, "the element captures the forward (redo) operations")
        XCTAssertEqual(element.reverseOperations, reverse, "the element captures the reverse (undo) operations")
        XCTAssertEqual(element.beforeVersionId, 1)
        XCTAssertEqual(element.afterVersionId, 2)
        XCTAssertNil(element.eolChange, "an element without an EOL change has a nil eolChange")
        XCTAssertEqual(element.beforeSelections, [], "selections default to empty when not provided")
        XCTAssertEqual(element.afterSelections, [])
    }

    /// An element captures the before/after alternative version ids — the
    /// alternative-version transition recorded for undo/redo tracking.
    func testElementCapturesAlternativeVersionTransition() {
        let element = MonaUndoRedoElement(
            operations: [],
            reverseOperations: [],
            beforeVersionId: 5,
            afterVersionId: 6,
            beforeAlternativeVersionId: 4,
            afterAlternativeVersionId: 5
        )
        XCTAssertEqual(element.beforeAlternativeVersionId, 4)
        XCTAssertEqual(element.afterAlternativeVersionId, 5)
    }

    /// An element captures an EOL change as a `MonaUndoRedoEOLChange` transition.
    func testElementCapturesEOLChange() {
        let eol = MonaUndoRedoEOLChange(before: .lf, after: .crlf)
        let element = MonaUndoRedoElement(
            operations: [],
            reverseOperations: [],
            beforeVersionId: 1,
            afterVersionId: 2,
            beforeAlternativeVersionId: 1,
            afterAlternativeVersionId: 1,
            eolChange: eol
        )
        XCTAssertEqual(element.eolChange, eol)
        XCTAssertEqual(element.eolChange?.before, .lf)
        XCTAssertEqual(element.eolChange?.after, .crlf)
    }

    /// An element captures the before/after cursor selections for selection
    /// recovery on undo/redo.
    func testElementCapturesSelectionRecovery() {
        let before = [
            MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))
        ]
        let after = [
            MonaSelection(anchor: MonaPosition(line: 1, column: 2), activePosition: MonaPosition(line: 1, column: 2))
        ]
        let element = MonaUndoRedoElement(
            operations: [],
            reverseOperations: [],
            beforeVersionId: 1,
            afterVersionId: 2,
            beforeAlternativeVersionId: 1,
            afterAlternativeVersionId: 1,
            beforeSelections: before,
            afterSelections: after
        )
        XCTAssertEqual(element.beforeSelections, before, "the element captures the pre-edit selections for undo recovery")
        XCTAssertEqual(element.afterSelections, after, "the element captures the post-edit selections for redo recovery")
    }

    /// The element is a value type with `let` properties — an immutable snapshot.
    /// Two elements with equal fields compare equal.
    func testElementIsImmutableValueSnapshot() {
        let e1 = MonaUndoRedoElement(
            label: "edit",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "A"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: 1,
            afterVersionId: 2,
            beforeAlternativeVersionId: 1,
            afterAlternativeVersionId: 1,
            eolChange: MonaUndoRedoEOLChange(before: .lf, after: .crlf),
            beforeSelections: [MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))],
            afterSelections: [MonaSelection(anchor: MonaPosition(line: 1, column: 2), activePosition: MonaPosition(line: 1, column: 2))]
        )
        // Construct an identical element.
        let e2 = MonaUndoRedoElement(
            label: "edit",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "A"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: 1,
            afterVersionId: 2,
            beforeAlternativeVersionId: 1,
            afterAlternativeVersionId: 1,
            eolChange: MonaUndoRedoEOLChange(before: .lf, after: .crlf),
            beforeSelections: [MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))],
            afterSelections: [MonaSelection(anchor: MonaPosition(line: 1, column: 2), activePosition: MonaPosition(line: 1, column: 2))]
        )
        XCTAssertEqual(e1, e2, "two elements with equal fields compare equal")
    }

    // MARK: - 2. MonaUndoRedoStack: push / undo / redo

    /// `push(_:)` populates the undo stack and `canUndo` reflects its state.
    /// A fresh stack has nothing to undo or redo.
    func testPushPopulatesUndoStack() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        XCTAssertFalse(stack.canUndo, "a fresh stack cannot undo")
        XCTAssertFalse(stack.canRedo, "a fresh stack cannot redo")
        XCTAssertEqual(stack.undoCount, 0)
        XCTAssertEqual(stack.redoCount, 0)

        stack.push(MonaUndoRedoElement(
            operations: [],
            reverseOperations: [],
            beforeVersionId: 1,
            afterVersionId: 1,
            beforeAlternativeVersionId: 1,
            afterAlternativeVersionId: 1
        ))
        XCTAssertTrue(stack.canUndo, "after a push the stack can undo")
        XCTAssertFalse(stack.canRedo, "after a push the stack cannot redo")
        XCTAssertEqual(stack.undoCount, 1)
    }

    /// `push(_:)` clears the redo stack — a standard undo behavior: once a new
    /// edit is pushed, the previously undone edits are no longer redoable.
    func testPushClearsRedoStack() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        // Push an element whose reverse ops are valid against "abc" (delete
        // nothing at (1,1)-(1,1) — a no-op reverse that survives validation).
        stack.push(MonaUndoRedoElement(
            label: "first",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "X"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: ""
            )],
            beforeVersionId: 1,
            afterVersionId: 2,
            beforeAlternativeVersionId: 1,
            afterAlternativeVersionId: 1
        ))

        // Undo → element moves to the redo stack.
        let undoOutcome = stack.undo()
        XCTAssertEqual(undoOutcome, .replayed)
        XCTAssertFalse(stack.canUndo)
        XCTAssertTrue(stack.canRedo, "after undo the redo stack is populated")
        XCTAssertEqual(stack.redoCount, 1)

        // Push a second element → redo stack is cleared.
        stack.push(MonaUndoRedoElement(
            label: "second",
            operations: [],
            reverseOperations: [],
            beforeVersionId: 2,
            afterVersionId: 3,
            beforeAlternativeVersionId: 2,
            afterAlternativeVersionId: 2
        ))
        XCTAssertTrue(stack.canUndo)
        XCTAssertFalse(stack.canRedo, "a new push clears the redo stack")
        XCTAssertEqual(stack.redoCount, 0)
    }

    // MARK: - 3. Route undo/redo through the transaction gateway

    /// `undo()` routes the reverse operations through the transaction gateway:
    /// the model text is reverted, the version is bumped (one commit = one
    /// version bump), and the element moves to the redo stack.
    func testUndoRoutesReverseOpsThroughGateway() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        // Apply the forward edit through the gateway so the model is in the
        // post-edit state the element's reverse operations target.
        let forwardOps = [MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        )]
        let tx = gateway.beginTransaction()
        tx.prepareEdits(forwardOps)
        _ = tx.commit()
        XCTAssertEqual(model.getValue(), "Xabc", "the forward edit is applied through the gateway")
        let afterVersion = model.getVersionId()

        // Push the element capturing the forward + reverse operations.
        stack.push(MonaUndoRedoElement(
            label: "insert-X",
            operations: forwardOps,
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: afterVersion - 1,
            afterVersionId: afterVersion,
            beforeAlternativeVersionId: afterVersion - 1,
            afterAlternativeVersionId: afterVersion - 1
        ))

        let outcome = stack.undo()
        XCTAssertEqual(outcome, .replayed, "a successful undo replays through the gateway")
        XCTAssertEqual(model.getValue(), "abc", "undo reverted the model text via the gateway")
        XCTAssertEqual(model.getVersionId(), afterVersion + 1, "undo bumps the version exactly once via the gateway commit")
        XCTAssertFalse(stack.canUndo, "after undo the undo stack is empty")
        XCTAssertTrue(stack.canRedo, "after undo the element moved to the redo stack")
    }

    /// `redo()` routes the forward operations through the transaction gateway:
    /// the model text is restored and the element moves back to the undo stack.
    func testRedoRoutesForwardOpsThroughGateway() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        let forwardOps = [MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        )]
        let tx = gateway.beginTransaction()
        tx.prepareEdits(forwardOps)
        _ = tx.commit()
        let afterVersion = model.getVersionId()

        stack.push(MonaUndoRedoElement(
            operations: forwardOps,
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: afterVersion - 1,
            afterVersionId: afterVersion,
            beforeAlternativeVersionId: afterVersion - 1,
            afterAlternativeVersionId: afterVersion - 1
        ))

        // Undo → model reverts to "abc".
        _ = stack.undo()
        XCTAssertEqual(model.getValue(), "abc")

        // Redo → model restored to "Xabc".
        let outcome = stack.redo()
        XCTAssertEqual(outcome, .replayed, "a successful redo replays through the gateway")
        XCTAssertEqual(model.getValue(), "Xabc", "redo restored the model text via the gateway")
        XCTAssertTrue(stack.canUndo, "after redo the element moved back to the undo stack")
        XCTAssertFalse(stack.canRedo, "after redo the redo stack is empty")
    }

    /// A full undo → redo round-trip restores the model to the post-edit state.
    func testUndoRedoRoundTripRestoresModel() {
        let model = MonaCodeModel(text: "hello", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        let forwardOps = [MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
            text: "H"
        )]
        // Apply forward: replace "h" with "H" → "Hello".
        let tx = gateway.beginTransaction()
        tx.prepareEdits(forwardOps)
        _ = tx.commit()
        XCTAssertEqual(model.getValue(), "Hello")
        let afterVersion = model.getVersionId()

        stack.push(MonaUndoRedoElement(
            label: "capitalize-H",
            operations: forwardOps,
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: "h"
            )],
            beforeVersionId: afterVersion - 1,
            afterVersionId: afterVersion,
            beforeAlternativeVersionId: afterVersion - 1,
            afterAlternativeVersionId: afterVersion - 1
        ))

        // Undo → "hello".
        XCTAssertEqual(stack.undo(), .replayed)
        XCTAssertEqual(model.getValue(), "hello")

        // Redo → "Hello".
        XCTAssertEqual(stack.redo(), .replayed)
        XCTAssertEqual(model.getValue(), "Hello")
        XCTAssertTrue(stack.canUndo)
        XCTAssertFalse(stack.canRedo)
    }

    // MARK: - 4. Undo/redo prepare the committed undo metadata + selections

    /// `undo()` commits undo metadata with `isUndoing == true` and recovers the
    /// before selections through the gateway.
    func testUndoCommitsIsUndoingMetadataAndBeforeSelections() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        let before = [MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))]
        let after = [MonaSelection(anchor: MonaPosition(line: 1, column: 2), activePosition: MonaPosition(line: 1, column: 2))]

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        _ = tx.commit()
        let afterVersion = model.getVersionId()

        stack.push(MonaUndoRedoElement(
            label: "insert-X",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "X"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: afterVersion - 1,
            afterVersionId: afterVersion,
            beforeAlternativeVersionId: afterVersion - 1,
            afterAlternativeVersionId: afterVersion - 1,
            beforeSelections: before,
            afterSelections: after
        ))

        _ = stack.undo()

        XCTAssertEqual(gateway.lastCommittedUndoMetadata.isUndoing, true, "undo commits isUndoing metadata through the gateway")
        XCTAssertEqual(gateway.lastCommittedUndoMetadata.isRedoing, false)
        XCTAssertEqual(gateway.lastCommittedUndoMetadata.label, "insert-X", "the element label is carried into the undo metadata")
        XCTAssertEqual(gateway.lastCommittedSelections, before, "undo recovers the before selections through the gateway")
    }

    /// `redo()` commits undo metadata with `isRedoing == true` and recovers the
    /// after selections through the gateway.
    func testRedoCommitsIsRedoingMetadataAndAfterSelections() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        let before = [MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))]
        let after = [MonaSelection(anchor: MonaPosition(line: 1, column: 2), activePosition: MonaPosition(line: 1, column: 2))]

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        _ = tx.commit()
        let afterVersion = model.getVersionId()

        stack.push(MonaUndoRedoElement(
            label: "insert-X",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "X"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: afterVersion - 1,
            afterVersionId: afterVersion,
            beforeAlternativeVersionId: afterVersion - 1,
            afterAlternativeVersionId: afterVersion - 1,
            beforeSelections: before,
            afterSelections: after
        ))

        _ = stack.undo()
        _ = stack.redo()

        XCTAssertEqual(gateway.lastCommittedUndoMetadata.isRedoing, true, "redo commits isRedoing metadata through the gateway")
        XCTAssertEqual(gateway.lastCommittedUndoMetadata.isUndoing, false)
        XCTAssertEqual(gateway.lastCommittedSelections, after, "redo recovers the after selections through the gateway")
    }

    // MARK: - 5. EOL changes on undo/redo

    /// `undo()` reverses the EOL change (applies the before EOL) through the
    /// gateway; `redo()` re-applies the after EOL.
    func testUndoRedoReversesEOLChangeThroughGateway() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        // Apply the EOL change through the gateway so the model is in the
        // post-change state (.crlf) the element targets.
        let tx = gateway.beginTransaction()
        tx.prepareEOL(.crlf)
        _ = tx.commit()
        XCTAssertEqual(model.getEndOfLineSequence(), .crlf)
        let afterVersion = model.getVersionId()

        stack.push(MonaUndoRedoElement(
            label: "eol-crlf",
            operations: [],
            reverseOperations: [],
            beforeVersionId: afterVersion - 1,
            afterVersionId: afterVersion,
            beforeAlternativeVersionId: afterVersion - 1,
            afterAlternativeVersionId: afterVersion - 1,
            eolChange: MonaUndoRedoEOLChange(before: .lf, after: .crlf)
        ))

        // Undo → EOL reverts to .lf.
        let undoOutcome = stack.undo()
        XCTAssertEqual(undoOutcome, .replayed)
        XCTAssertEqual(model.getEndOfLineSequence(), .lf, "undo reverses the EOL change through the gateway")

        // Redo → EOL restored to .crlf.
        let redoOutcome = stack.redo()
        XCTAssertEqual(redoOutcome, .replayed)
        XCTAssertEqual(model.getEndOfLineSequence(), .crlf, "redo re-applies the EOL change through the gateway")
    }

    // MARK: - 6. Rollback stack position on replay failure

    /// When `undo()` replays reverse operations whose range the model would
    /// clamp (invalid range), the gateway rolls back the transaction. The stack
    /// rolls back its position: the element is restored to the undo stack and
    /// `canUndo` remains true. The model is left untouched.
    func testUndoRollsBackStackPositionOnValidationFailure() {
        let model = MonaCodeModel(text: "ab", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        let v0 = model.getVersionId()

        // An element whose reverse operation has a range far past the line's max
        // column (3 for "ab"). The gateway's `isValidRange` check fails → the
        // transaction rolls back with "validation failure".
        stack.push(MonaUndoRedoElement(
            label: "bad-reverse",
            operations: [],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 50),
                text: ""
            )],
            beforeVersionId: v0,
            afterVersionId: v0,
            beforeAlternativeVersionId: v0,
            afterAlternativeVersionId: v0
        ))

        let outcome = stack.undo()
        guard case .replayFailed(let reason) = outcome else {
            XCTFail("expected .replayFailed but got \(outcome)")
            return
        }
        XCTAssertEqual(reason, "validation failure", "the replay fails with the gateway's validation-failure reason")

        // The stack position is rolled back: the element is restored to the undo stack.
        XCTAssertTrue(stack.canUndo, "the stack rolls back its position so canUndo stays true")
        XCTAssertFalse(stack.canRedo, "the redo stack is unchanged after a failed undo")
        XCTAssertEqual(stack.undoCount, 1, "the element was restored to the undo stack")
        XCTAssertEqual(model.getValue(), "ab", "the model is untouched after a failed replay")
        XCTAssertEqual(model.getVersionId(), v0, "the version is untouched after a failed replay")
    }

    /// When `redo()` replays forward operations that fail validation, the stack
    /// rolls back its position: the element is restored to the redo stack.
    func testRedoRollsBackStackPositionOnValidationFailure() {
        let model = MonaCodeModel(text: "ab", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        let v0 = model.getVersionId()

        // An element with valid reverse (no-op at (1,1)-(1,1)) but an invalid
        // forward range. Undo succeeds (reverse is valid); redo fails (forward
        // range exceeds the line) and the element is restored to the redo stack.
        stack.push(MonaUndoRedoElement(
            label: "bad-forward",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 50),
                text: ""
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: ""
            )],
            beforeVersionId: v0,
            afterVersionId: v0,
            beforeAlternativeVersionId: v0,
            afterAlternativeVersionId: v0
        ))

        // Undo succeeds (the reverse op is a valid no-op).
        XCTAssertEqual(stack.undo(), .replayed)
        XCTAssertTrue(stack.canRedo)

        // Redo fails: the forward op's range (1,1)-(1,50) exceeds the line's
        // max column → the gateway rolls back → the stack rolls back its position.
        let redoOutcome = stack.redo()
        guard case .replayFailed(let reason) = redoOutcome else {
            XCTFail("expected .replayFailed but got \(redoOutcome)")
            return
        }
        XCTAssertEqual(reason, "validation failure")
        XCTAssertFalse(stack.canUndo, "the undo stack is unchanged after a failed redo")
        XCTAssertTrue(stack.canRedo, "the stack rolls back its position so canRedo stays true")
        XCTAssertEqual(stack.redoCount, 1, "the element was restored to the redo stack")
    }

    // MARK: - 7. Empty-stack and clear behavior

    /// `undo()` and `redo()` on an empty stack return `.replayFailed` without
    /// touching the model.
    func testUndoRedoOnEmptyStackFails() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        let v0 = model.getVersionId()
        XCTAssertEqual(stack.undo(), .replayFailed(reason: "nothing to undo"), "undo on an empty stack fails with a descriptive reason")
        XCTAssertEqual(stack.redo(), .replayFailed(reason: "nothing to redo"), "redo on an empty stack fails with a descriptive reason")
        XCTAssertEqual(model.getVersionId(), v0, "an empty-stack replay does not touch the model")
    }

    /// `clear()` empties both the undo and redo stacks.
    func testClearEmptiesBothStacks() {
        let model = MonaCodeModel(text: "abc", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        // Push an element whose reverse op is a valid no-op against "abc".
        stack.push(MonaUndoRedoElement(
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "X"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: ""
            )],
            beforeVersionId: 1,
            afterVersionId: 2,
            beforeAlternativeVersionId: 1,
            afterAlternativeVersionId: 1
        ))
        _ = stack.undo()
        XCTAssertTrue(stack.canRedo)

        stack.clear()
        XCTAssertFalse(stack.canUndo, "clear empties the undo stack")
        XCTAssertFalse(stack.canRedo, "clear empties the redo stack")
        XCTAssertEqual(stack.undoCount, 0)
        XCTAssertEqual(stack.redoCount, 0)
    }

    // MARK: - 8. Multiple elements: LIFO ordering

    /// The undo stack is LIFO: the most recently pushed element is undone first.
    /// Undoing then redoing in sequence respects the LIFO order.
    func testStackIsLIFO() {
        let model = MonaCodeModel(text: "", uri: testURI())
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)

        // Push two elements. Each inserts a character at (1,1).
        // Element A: insert "A" → model "A"
        // Element B: insert "B" → model "BA"
        // To keep the reverse ops valid against the current model state, we
        // apply each forward edit through the gateway before pushing.
        let applyA = gateway.beginTransaction()
        applyA.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "A"
        ))
        _ = applyA.commit()
        XCTAssertEqual(model.getValue(), "A")
        stack.push(MonaUndoRedoElement(
            label: "insert-A",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "A"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: model.getVersionId() - 1,
            afterVersionId: model.getVersionId(),
            beforeAlternativeVersionId: model.getVersionId() - 1,
            afterAlternativeVersionId: model.getVersionId() - 1
        ))

        let applyB = gateway.beginTransaction()
        applyB.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "B"
        ))
        _ = applyB.commit()
        XCTAssertEqual(model.getValue(), "BA")
        stack.push(MonaUndoRedoElement(
            label: "insert-B",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "B"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: model.getVersionId() - 1,
            afterVersionId: model.getVersionId(),
            beforeAlternativeVersionId: model.getVersionId() - 1,
            afterAlternativeVersionId: model.getVersionId() - 1
        ))

        // Undo B first (LIFO): "BA" → "A".
        XCTAssertEqual(stack.undo(), .replayed)
        XCTAssertEqual(model.getValue(), "A", "LIFO: the most recently pushed element (B) is undone first")
        XCTAssertEqual(gateway.lastCommittedUndoMetadata.label, "insert-B")

        // Undo A: "A" → "".
        XCTAssertEqual(stack.undo(), .replayed)
        XCTAssertEqual(model.getValue(), "")
        XCTAssertEqual(gateway.lastCommittedUndoMetadata.label, "insert-A")

        XCTAssertFalse(stack.canUndo)
        XCTAssertTrue(stack.canRedo)

        // Redo A first (LIFO on the redo stack): "" → "A".
        XCTAssertEqual(stack.redo(), .replayed)
        XCTAssertEqual(model.getValue(), "A")
        XCTAssertEqual(gateway.lastCommittedUndoMetadata.label, "insert-A")

        // Redo B: "A" → "BA".
        XCTAssertEqual(stack.redo(), .replayed)
        XCTAssertEqual(model.getValue(), "BA")
        XCTAssertEqual(gateway.lastCommittedUndoMetadata.label, "insert-B")
    }
}
