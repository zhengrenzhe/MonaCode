// MonaTransactionGatewayTests.swift
//
// P01-T009 — Make one edit transaction gateway own mutation and version truth.
//
// Verifies that `MonaTransactionGateway` is the single owner of mutation and
// version truth for a `MonaCodeModel`, and that `MonaEditTransaction` prepares
// edits WITHOUT mutating the published model state, commits text + version +
// alternative version + events + selections + undo metadata as one ordered
// unit, rolls back every prepared component on cancellation / validation
// failure / reentrant invalidation, and emits the four typed
// `MonaReconciliationOutcome` values (`.applied` / `.dropped(reason:)` /
// `.reconciled(changes:)` / `.rolledBack(reason:)`).
//
// The gateway wraps a `MonaCodeModel` (P01-T008). Text truth continues to live
// in the Piece Tree; the gateway owns the TRANSACTIONAL mutation truth: it
// captures the version at `beginTransaction()`, refuses to commit a transaction
// whose captured version has diverged from the model (direct mutation), and
// serializes transactions so that only one is active at a time. Beginning a
// second transaction invalidates the first (reentrant invalidation → `.dropped`
// on its `commit()`).
//
// Test contract (P01-T009): prepare-without-mutate; commit-as-one-unit;
// rollback-on-failure; typed outcomes.

import XCTest
import MonaCode

final class MonaTransactionGatewayTests: XCTestCase {

    // MARK: - 1. Prepare edits WITHOUT mutating the published model state

    /// Preparing edits on a transaction must not change the model's text,
    /// version id, or alternative version id. The prepared operations are
    /// observable on the transaction only.
    func testPrepareEditsWithoutMutatingModel() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        let v0 = model.getVersionId()
        let av0 = model.getAlternativeVersionId()

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        tx.prepareSelections([MonaSelection(anchor: MonaPosition(line: 1, column: 2), activePosition: MonaPosition(line: 1, column: 2))])
        tx.prepareUndoMetadata(MonaUndoMetadata(label: "insert-X"))

        // Model is untouched by preparation.
        XCTAssertEqual(model.getValue(), "abc", "prepare must not mutate the model text")
        XCTAssertEqual(model.getVersionId(), v0, "prepare must not bump the version id")
        XCTAssertEqual(model.getAlternativeVersionId(), av0, "prepare must not touch the alternative version id")
        XCTAssertTrue(gateway.hasOpenTransaction, "an uncommitted transaction keeps the gateway open")

        // The prepared components are observable on the transaction.
        XCTAssertEqual(tx.preparedOperations.count, 1)
        XCTAssertEqual(tx.preparedOperations[0].text, "X")
        XCTAssertEqual(tx.preparedSelections.count, 1)
        XCTAssertEqual(tx.preparedUndoMetadata.label, "insert-X")

        XCTAssertFalse(tx.isClosed, "a fresh transaction is open")
        XCTAssertFalse(tx.isApplied)
        XCTAssertFalse(tx.isRolledBack)
    }

    // MARK: - 2. Commit text + version + alternative version + events +
    //          selections + undo metadata as ONE ordered unit

    /// A successful commit applies the prepared text ops through the model in a
    /// single batch (one version bump, one `onDidChangeContent` event), records
    /// the pre-edit version as the alternative version, and records the prepared
    /// selections + undo metadata on the gateway as the committed unit.
    func testCommitAppliesTextVersionEventsSelectionsUndoAsOneUnit() {
        let model = MonaCodeModel(text: "Hello", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        var received: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { event in received.append(event) }
        defer { disposable.dispose() }

        let v0 = model.getVersionId()
        let selections = [MonaSelection(anchor: MonaPosition(line: 1, column: 3), activePosition: MonaPosition(line: 1, column: 3))]
        let undo = MonaUndoMetadata(label: "replace-H-with-hi")

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
            text: "hi"
        ))
        tx.prepareSelections(selections)
        tx.prepareUndoMetadata(undo)

        let outcome = tx.commit()

        XCTAssertEqual(outcome, .applied, "a clean commit must return .applied")
        XCTAssertTrue(tx.isApplied, "the transaction is marked applied")
        XCTAssertTrue(tx.isClosed, "a committed transaction is closed")
        XCTAssertFalse(gateway.hasOpenTransaction, "a committed transaction frees the gateway")

        // Text truth: applied through the Piece Tree. Replacing the single
        // character "H" (offset 0..1) with "hi" yields "hiello".
        XCTAssertEqual(model.getValue(), "hiello", "the prepared edit must be applied")
        // Version truth: bumped exactly once for the batch.
        XCTAssertEqual(model.getVersionId(), v0 + 1, "commit bumps the version exactly once")
        XCTAssertEqual(model.getAlternativeVersionId(), v0, "alternative version tracks the pre-edit version")

        // Events: exactly one content-change event for the batch.
        XCTAssertEqual(received.count, 1, "commit must fire exactly one content-change event for the batch")
        XCTAssertFalse(received[0].isFlush, "a transaction commit is not a flush")
        XCTAssertEqual(received[0].changes.count, 1)
        XCTAssertEqual(received[0].changes[0].text, "hi")

        // Selections + undo metadata are committed as part of the unit.
        XCTAssertEqual(gateway.lastCommittedSelections, selections, "committed selections must match the prepared ones")
        XCTAssertEqual(gateway.lastCommittedUndoMetadata, undo, "committed undo metadata must match the prepared one")
    }

    /// An empty transaction (no prepared ops) commits as `.applied` without
    /// bumping the version or firing an event — the unit is well-defined even
    /// when empty.
    func testEmptyCommitIsAppliedWithoutSideEffects() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        var received: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { event in received.append(event) }
        defer { disposable.dispose() }

        let v0 = model.getVersionId()
        let tx = gateway.beginTransaction()
        let outcome = tx.commit()

        XCTAssertEqual(outcome, .applied)
        XCTAssertEqual(model.getVersionId(), v0, "an empty commit must not bump the version")
        XCTAssertEqual(received.count, 0, "an empty commit must not fire a content-change event")
    }

    // MARK: - 3. Rollback on failure

    /// An explicit `rollback()` discards every prepared component and leaves the
    /// model untouched. The outcome is `.rolledBack`.
    func testExplicitRollbackLeavesModelUnchanged() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        var received: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { event in received.append(event) }
        defer { disposable.dispose() }

        let v0 = model.getVersionId()
        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        tx.prepareSelections([MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))])
        tx.prepareUndoMetadata(MonaUndoMetadata(label: "will-be-rolled-back"))

        let outcome = tx.rollback()

        XCTAssertEqual(outcome, .rolledBack(reason: "rolled back"), "explicit rollback returns .rolledBack")
        XCTAssertTrue(tx.isRolledBack)
        XCTAssertTrue(tx.isClosed)
        XCTAssertFalse(gateway.hasOpenTransaction, "rollback frees the gateway")
        XCTAssertEqual(model.getValue(), "abc", "rollback must not mutate the model")
        XCTAssertEqual(model.getVersionId(), v0, "rollback must not bump the version")
        XCTAssertEqual(received.count, 0, "rollback must not fire any event")
        XCTAssertEqual(gateway.lastCommittedSelections, [], "rollback does not record committed selections")
        XCTAssertEqual(gateway.lastCommittedUndoMetadata, .empty, "rollback does not record undo metadata")
    }

    /// A prepared operation whose range the model would clamp (invalid range)
    /// fails validation at commit; the transaction rolls back every prepared
    /// component and the model is left untouched.
    func testRollbackOnValidationFailure() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        var received: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { event in received.append(event) }
        defer { disposable.dispose() }

        let v0 = model.getVersionId()
        let tx = gateway.beginTransaction()
        // endColumn 9999 is far past the line's max column (4); validateRange
        // would clamp it, so the range is NOT valid as-given.
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 9999),
            text: "Z"
        ))
        tx.prepareUndoMetadata(MonaUndoMetadata(label: "invalid"))

        let outcome = tx.commit()

        XCTAssertEqual(outcome, .rolledBack(reason: "validation failure"), "an invalid range rolls back with the validation-failure reason")
        XCTAssertTrue(tx.isRolledBack)
        XCTAssertTrue(tx.isClosed)
        XCTAssertFalse(gateway.hasOpenTransaction)
        XCTAssertEqual(model.getValue(), "abc", "a rolled-back commit must not mutate the model")
        XCTAssertEqual(model.getVersionId(), v0, "a rolled-back commit must not bump the version")
        XCTAssertEqual(received.count, 0, "a rolled-back commit must not fire any event")
    }

    /// Cancellation requested before commit drops the transaction: the model is
    /// untouched and the outcome is `.dropped(reason: "cancelled")`.
    func testCancellationDropsTransaction() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        let source = MonaCancellationTokenSource()
        let tx = gateway.beginTransaction()
        tx.setCancellationToken(source.token)
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))

        let v0 = model.getVersionId()
        source.cancel()

        let outcome = tx.commit()
        XCTAssertEqual(outcome, .dropped(reason: "cancelled"), "a cancelled transaction drops with the cancelled reason")
        XCTAssertTrue(tx.isClosed)
        XCTAssertFalse(gateway.hasOpenTransaction)
        XCTAssertEqual(model.getValue(), "abc")
        XCTAssertEqual(model.getVersionId(), v0)
    }

    /// Beginning a second transaction invalidates the first (reentrant
    /// invalidation). Committing the invalidated first transaction drops it.
    func testReentrantInvalidationDropsFirstTransaction() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        let txA = gateway.beginTransaction()
        txA.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "A"
        ))

        XCTAssertTrue(gateway.hasOpenTransaction)
        // Beginning a second transaction invalidates the first.
        let txB = gateway.beginTransaction()
        txB.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "B"
        ))

        let v0 = model.getVersionId()
        let outcomeA = txA.commit()
        XCTAssertEqual(outcomeA, .dropped(reason: "reentrant invalidation"), "the invalidated transaction drops on commit")
        XCTAssertTrue(txA.isClosed)
        XCTAssertFalse(txA.isApplied)

        // The second transaction is still the active one and commits cleanly.
        let outcomeB = txB.commit()
        XCTAssertEqual(outcomeB, .applied)
        XCTAssertEqual(model.getValue(), "Babc")
        XCTAssertEqual(model.getVersionId(), v0 + 1)
        XCTAssertFalse(gateway.hasOpenTransaction)
    }

    /// A transaction whose captured version has diverged from the model (the
    /// model was mutated directly, bypassing the gateway) is dropped as stale
    /// when reconcile is not enabled.
    func testStaleVersionDropsTransactionWhenReconcileDisabled() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))

        let v0 = model.getVersionId()
        // Direct mutation bypassing the gateway bumps the model's version.
        _ = model.applyEdits([MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 4, endLine: 1, endColumn: 4),
            text: "Y"
        )])
        XCTAssertEqual(model.getVersionId(), v0 + 1, "the direct mutation must have bumped the version")
        XCTAssertEqual(model.getValue(), "abcY")

        let outcome = tx.commit()
        XCTAssertEqual(outcome, .dropped(reason: "stale version"), "a stale transaction drops when reconcile is disabled")
        XCTAssertTrue(tx.isClosed)
        XCTAssertFalse(gateway.hasOpenTransaction)
        // The stale transaction did not apply its prepared edit on top of the
        // direct mutation.
        XCTAssertEqual(model.getValue(), "abcY")
        XCTAssertEqual(model.getVersionId(), v0 + 1)
    }

    /// When reconcile IS enabled, a stale transaction re-validates its prepared
    /// operations against the CURRENT model, applies them, and returns
    /// `.reconciled(changes:)` describing the reconciliation.
    func testReconcileOnStaleVersionReturnsReconciled() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        tx.setReconcileEnabled(true)

        let v0 = model.getVersionId()
        // Direct mutation bumps the version and changes the text to "abcY".
        _ = model.applyEdits([MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 4, endLine: 1, endColumn: 4),
            text: "Y"
        )])
        let v1 = model.getVersionId()
        XCTAssertEqual(v1, v0 + 1)

        let outcome = tx.commit()

        guard case .reconciled(let changes) = outcome else {
            XCTFail("expected .reconciled but got \(outcome)")
            return
        }
        XCTAssertFalse(changes.isEmpty, "reconcile must describe the reconciliation")
        XCTAssertTrue(tx.isApplied)
        XCTAssertTrue(tx.isClosed)
        XCTAssertFalse(gateway.hasOpenTransaction)
        // The prepared insert-at-(1,1) was reapplied against the current text.
        XCTAssertEqual(model.getValue(), "XabcY", "reconcile reapplies the prepared edit against the current text")
        XCTAssertEqual(model.getVersionId(), v1 + 1, "reconcile bumps the version exactly once for the reapplied batch")
    }

    // MARK: - 4. Serialization: one transaction at a time

    /// `hasOpenTransaction` reflects whether a transaction is active on the
    /// gateway. Committing or rolling back the active transaction clears it.
    func testHasOpenTransactionReflectsActiveTransaction() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        XCTAssertFalse(gateway.hasOpenTransaction)
        let tx = gateway.beginTransaction()
        XCTAssertTrue(gateway.hasOpenTransaction)
        tx.rollback()
        XCTAssertFalse(gateway.hasOpenTransaction, "rollback clears the active transaction")

        // A second transaction after rollback begins cleanly.
        let tx2 = gateway.beginTransaction()
        XCTAssertTrue(gateway.hasOpenTransaction)
        _ = tx2.commit()
        XCTAssertFalse(gateway.hasOpenTransaction, "commit clears the active transaction")
    }

    /// The gateway exposes the model it owns transactional truth for.
    func testGatewayExposesOwningModel() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)
        XCTAssertTrue(gateway.model === model, "the gateway wraps the model it owns mutation truth for")
    }

    /// `gateway.commit(_:)` and `gateway.rollback(_:)` mirror the transaction's
    /// own methods and produce identical outcomes.
    func testGatewayCommitAndRollbackMirrorTransactionMethods() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gateway = MonaTransactionGateway(model: model)

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))

        let outcome = gateway.commit(tx)
        XCTAssertEqual(outcome, .applied)
        XCTAssertEqual(model.getValue(), "Xabc")

        // A rolled-back transaction via the gateway.
        let tx2 = gateway.beginTransaction()
        tx2.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "Y"
        ))
        let outcome2 = gateway.rollback(tx2)
        XCTAssertEqual(outcome2, .rolledBack(reason: "rolled back"))
        XCTAssertEqual(model.getValue(), "Xabc", "rollback via the gateway leaves the model unchanged")
    }
}
