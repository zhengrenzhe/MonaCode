// MonaWorkspaceEditTests.swift
//
// P07-T006 — Implement the four-outcome WorkspaceEdit transaction.
//
// Verifies the atomic apply-external-then-publish-model transaction:
//   1. Prepare open-model edits inside component truth + external resource
//      operations through the explicit host.
//   2. Expose applied / rejected / failed / canceled outcomes with exact failure
//      details.
//   3. Require a prepared nonthrowing atomic external commit BEFORE publishing
//      open-model changes.
//   4. Roll back EVERY prepared open-model mutation when external preparation or
//      commit fails (no partial model state).
//
// Test contract (P07-T006): 4 outcomes (applied/rejected/failed/canceled) with
// exact details; external-commit-before-publish ordering; rollback on external
// prep/commit failure.

import XCTest
import MonaCode

final class MonaWorkspaceEditTests: XCTestCase {

    // MARK: - 1. .applied — everything committed

    /// A transactional host that authorizes external ops: the external commit
    /// (host prepared transaction) succeeds, then the open-model changes
    /// publish. Outcome is `.applied`, the model version bumps, and the external
    /// prepared transaction was committed exactly once.
    func testAppliedOutcome() async {
        let model = Self.makeModel("/open-1", text: "hello")
        let startVersion = model.getVersionId()
        let host = StubTransactionalHost(model: model)
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(modelURI: model.uri, edits: [
                MonaModelEditOperation(range: Self.fullRange(), text: "HELLO")
            ])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .create, uri: Self.uri("/ext-create"))
            ]
        )

        let outcome = await edit.apply(
            host: host,
            modelResolver: { ObjectIdentifier($0) == ObjectIdentifier(model.uri) ? model : nil },
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-applied"),
            cancellationToken: .none
        )

        guard case .applied = outcome else {
            return XCTFail("expected .applied; got \(outcome)")
        }
        XCTAssertTrue(host.prepareCallCount == 1,
                      "external preparation called once")
        XCTAssertTrue(host.preparedTransaction?.commitCallCount == 1,
                      "external prepared transaction committed exactly once")
        XCTAssertTrue(host.preparedTransaction?.abortCallCount == 0,
                      "external prepared transaction was NOT aborted on success")
        XCTAssertNotEqual(model.getVersionId(), startVersion,
                           "open-model changes published (version bumped)")
    }

    // MARK: - 2. .rejected — the host declined external authority

    /// A host that declines external resource operations (throws
    /// `workspaceAuthorityDeclined`) produces `.rejected` with the rejecting
    /// operation index and an exact reason. The open-model mutations are rolled
    /// back — the model version is UNCHANGED (no partial state).
    func testRejectedOutcome() async {
        let model = Self.makeModel("/open-2", text: "abc")
        let startVersion = model.getVersionId()
        let host = StubTransactionalHost(model: model, prepareBehavior: .decline)
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(modelURI: model.uri, edits: [
                MonaModelEditOperation(range: Self.fullRange(), text: "ABC")
            ])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .delete, uri: Self.uri("/ext-del"))
            ]
        )

        let outcome = await edit.apply(
            host: host,
            modelResolver: { ObjectIdentifier($0) == ObjectIdentifier(model.uri) ? model : nil },
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-rejected"),
            cancellationToken: .none
        )

        guard case .rejected(let opIndex, let reason) = outcome else {
            return XCTFail("expected .rejected; got \(outcome)")
        }
        XCTAssertEqual(opIndex, 0, "the rejecting operation index is reported")
        XCTAssertFalse(reason.isEmpty, "the rejection carries an exact reason")
        XCTAssertEqual(model.getVersionId(), startVersion,
                       "rollback: model untouched when external prep was rejected")
        XCTAssertNil(host.preparedTransaction,
                     "no prepared external transaction survives a rejected preparation")
    }

    // MARK: - 3. .failed — an op failed with exact failure details

    /// A host that throws a non-authority error during external preparation
    /// produces `.failed` with exact failure details (stage, operation index,
    /// error description). The open-model mutations are rolled back — the model
    /// version is UNCHANGED.
    func testFailedOutcomeDuringExternalPreparation() async {
        let model = Self.makeModel("/open-3", text: "xyz")
        let startVersion = model.getVersionId()
        let host = StubTransactionalHost(
            model: model,
            prepareBehavior: .fail(MonaHostContractError.commandUnhandled("disk-full"))
        )
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(modelURI: model.uri, edits: [
                MonaModelEditOperation(range: Self.fullRange(), text: "XYZ")
            ])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .rename, uri: Self.uri("/ext-ren"))
            ]
        )

        let outcome = await edit.apply(
            host: host,
            modelResolver: { ObjectIdentifier($0) == ObjectIdentifier(model.uri) ? model : nil },
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-failed"),
            cancellationToken: .none
        )

        guard case .failed(let details) = outcome else {
            return XCTFail("expected .failed; got \(outcome)")
        }
        XCTAssertEqual(details.stage, .prepareExternal,
                       "exact failure stage: external preparation")
        XCTAssertEqual(details.operationIndex, 0,
                       "exact failing operation index")
        XCTAssertFalse(details.errorDescription.isEmpty,
                       "exact error description carried")
        XCTAssertEqual(model.getVersionId(), startVersion,
                       "rollback: model untouched when external prep failed")
    }

    // MARK: - 4. .canceled — cancelled via the cancellation token

    /// A cancellation token that is already cancelled produces `.canceled`
    /// with the stage at which cancellation was observed. The open-model
    /// mutations are rolled back — the model version is UNCHANGED.
    func testCanceledOutcome() async {
        let model = Self.makeModel("/open-4", text: "keep")
        let startVersion = model.getVersionId()
        let host = StubTransactionalHost(model: model)
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(modelURI: model.uri, edits: [
                MonaModelEditOperation(range: Self.fullRange(), text: "KEEP")
            ])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .create, uri: Self.uri("/ext-c"))
            ]
        )

        let outcome = await edit.apply(
            host: host,
            modelResolver: { ObjectIdentifier($0) == ObjectIdentifier(model.uri) ? model : nil },
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-canceled"),
            cancellationToken: .cancelled
        )

        guard case .canceled(let stage) = outcome else {
            return XCTFail("expected .canceled; got \(outcome)")
        }
        XCTAssertEqual(stage, .prepareExternal,
                       "cancellation observed at the external-preparation stage")
        XCTAssertEqual(model.getVersionId(), startVersion,
                       "rollback: model untouched when canceled")
        // Cancellation was observed before external preparation, so no prepared
        // external transaction was created.
        XCTAssertEqual(host.prepareCallCount, 0,
                       "external preparation skipped on early cancellation")
        XCTAssertNil(host.preparedTransaction,
                     "no prepared external transaction survives early cancel")
    }

    // MARK: - 5. Ordering — external commit BEFORE open-model publish

    /// The external commit (host prepared transaction's `commit()`) MUST run
    /// BEFORE any open-model change is published. We prove this by recording the
    /// model version id at the moment the host's prepared transaction commits —
    /// it must equal the start version (open-model not yet published). After the
    /// whole transaction returns `.applied`, the model version must have bumped,
    /// proving publish happened AFTER the external commit.
    func testExternalCommitBeforeOpenModelPublish() async {
        let model = Self.makeModel("/open-5", text: "order")
        let startVersion = model.getVersionId()
        let host = StubTransactionalHost(model: model)
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(modelURI: model.uri, edits: [
                MonaModelEditOperation(range: Self.fullRange(), text: "ORDER")
            ])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .create, uri: Self.uri("/ext-order"))
            ]
        )

        let outcome = await edit.apply(
            host: host,
            modelResolver: { ObjectIdentifier($0) == ObjectIdentifier(model.uri) ? model : nil },
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-order"),
            cancellationToken: .none
        )

        guard case .applied = outcome else {
            return XCTFail("expected .applied; got \(outcome)")
        }
        guard let versionAtExternalCommit = host.preparedTransaction?.modelVersionAtCommit else {
            return XCTFail("the host prepared transaction recorded no version-at-commit")
        }
        XCTAssertEqual(versionAtExternalCommit, startVersion,
                       "external commit ran BEFORE open-model publish (version still start)")
        XCTAssertNotEqual(model.getVersionId(), startVersion,
                           "open-model publish ran AFTER external commit (version bumped)")
    }

    // MARK: - 6. Rollback — non-transactional commit failure rolls back

    /// A non-transactional host that applies ops one-by-one and FAILS mid-batch
    /// (on op index 1, after op 0 was applied) produces `.failed`, undoes the
    /// already-applied op 0, and rolls back the open-model mutations — the model
    /// version is UNCHANGED. No partial external state survives: the applied op
    /// is undone via `undoExternalOperation`.
    func testRollbackOnNonTransactionalCommitFailure() async {
        let model = Self.makeModel("/open-6", text: "rb")
        let startVersion = model.getVersionId()
        let host = StubNonTransactionalHost(
            failOnOpIndex: 1,
            failure: MonaHostContractError.commandUnhandled("io-error")
        )
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(modelURI: model.uri, edits: [
                MonaModelEditOperation(range: Self.fullRange(), text: "RB")
            ])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .create, uri: Self.uri("/ext-0")),
                MonaExternalWorkspaceOperation(kind: .create, uri: Self.uri("/ext-1"))
            ]
        )

        let outcome = await edit.apply(
            host: host,
            modelResolver: { ObjectIdentifier($0) == ObjectIdentifier(model.uri) ? model : nil },
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-rb"),
            cancellationToken: .none
        )

        guard case .failed(let details) = outcome else {
            return XCTFail("expected .failed; got \(outcome)")
        }
        XCTAssertEqual(details.stage, .commitExternal,
                       "exact failure stage: external (non-transactional) commit")
        XCTAssertEqual(details.operationIndex, 1,
                       "exact failing operation index (the op that failed)")
        XCTAssertEqual(host.appliedOps.count, 1,
                       "op 0 was applied before op 1 failed")
        XCTAssertEqual(host.undoneReceipts.count, 1,
                       "the already-applied op 0 was undone (no partial external state)")
        XCTAssertEqual(model.getVersionId(), startVersion,
                       "rollback: model untouched when non-transactional commit failed")
    }

    // MARK: - 7. Open-model-only edit (no external ops) — still .applied

    /// A workspace edit with open-model edits but NO external operations still
    /// commits the open-model changes (the core open-model-only capability is
    /// retained). Outcome is `.applied`; no host is required.
    func testOpenModelOnlyEdit() async {
        let model = Self.makeModel("/open-7", text: "only")
        let startVersion = model.getVersionId()
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(modelURI: model.uri, edits: [
                MonaModelEditOperation(range: Self.fullRange(), text: "ONLY")
            ])],
            externalOperations: []
        )

        let outcome = await edit.apply(
            host: nil,
            modelResolver: { ObjectIdentifier($0) == ObjectIdentifier(model.uri) ? model : nil },
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-open-only"),
            cancellationToken: .none
        )

        guard case .applied = outcome else {
            return XCTFail("expected .applied; got \(outcome)")
        }
        XCTAssertNotEqual(model.getVersionId(), startVersion,
                           "open-model changes published (no external ops needed)")
    }

    // MARK: - 8. External ops with no host attached — .rejected

    /// A workspace edit that requests external operations but is applied with
    /// `host: nil` is rejected: there is no host to authorize the external ops.
    /// The open-model mutations are rolled back — model version UNCHANGED.
    func testExternalOpsWithoutHostIsRejected() async {
        let model = Self.makeModel("/open-8", text: "nohost")
        let startVersion = model.getVersionId()
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(modelURI: model.uri, edits: [
                MonaModelEditOperation(range: Self.fullRange(), text: "NOHOST")
            ])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .create, uri: Self.uri("/ext-nohost"))
            ]
        )

        let outcome = await edit.apply(
            host: nil,
            modelResolver: { ObjectIdentifier($0) == ObjectIdentifier(model.uri) ? model : nil },
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-nohost"),
            cancellationToken: .none
        )

        guard case .rejected(let opIndex, _) = outcome else {
            return XCTFail("expected .rejected; got \(outcome)")
        }
        XCTAssertEqual(opIndex, 0, "the first external op is the rejecting index")
        XCTAssertEqual(model.getVersionId(), startVersion,
                       "rollback: model untouched when no host authorized external ops")
    }

    // MARK: - Helpers

    private static func makeModel(_ path: String, text: String) -> MonaCodeModel {
        return MonaCodeModel(text: text, uri: uri(path))
    }

    private static func uri(_ path: String) -> MonaURI {
        return MonaURI(scheme: "inmemory", path: path)
    }

    /// A range covering the whole of a single-line model (line 1, cols 1..1+max).
    /// The exact end column is large enough to cover the test texts; the model
    /// clamps internally.
    private static func fullRange() -> MonaRange {
        return MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 10_000)
        )
    }
}

// MARK: - Stub transactional host (prepareAtomicExternalOperations path)

private final class StubTransactionalHost: MonaWorkspaceEditHost {
    enum PrepareBehavior {
        case succeed
        case decline
        case fail(Error)
    }

    let capabilities: MonaWorkspaceEditCapabilities
    private(set) var prepareCallCount = 0
    private(set) var preparedTransaction: StubHostPreparedTransaction?
    private let prepareBehavior: PrepareBehavior
    private weak var modelRef: MonaCodeModel?

    init(model: MonaCodeModel, prepareBehavior: PrepareBehavior = .succeed) {
        self.capabilities = MonaWorkspaceEditCapabilities(
            appliesResourceOperations: true,
            supportsTransactional: true,
            supportsUndoReceipts: true
        )
        self.prepareBehavior = prepareBehavior
        self.modelRef = model
    }

    func applyExternalOperation(
        _ operation: MonaExternalWorkspaceOperation,
        index: Int,
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaWorkspaceOperationResult {
        // Transactional host never uses per-op apply in these tests.
        return MonaWorkspaceOperationResult(applied: true, undoReceipt: nil)
    }

    func undoExternalOperation(receipt: MonaWorkspaceUndoReceipt) async -> Bool {
        return true
    }

    func prepareAtomicExternalOperations(
        _ operations: [MonaExternalWorkspaceOperation],
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaPreparedWorkspaceTransaction {
        prepareCallCount += 1
        switch prepareBehavior {
        case .succeed:
            let prepared = StubHostPreparedTransaction(identity: transactionID, model: modelRef)
            preparedTransaction = prepared
            return prepared
        case .decline:
            throw MonaHostContractError.workspaceAuthorityDeclined
        case .fail(let error):
            throw error
        }
    }
}

// MARK: - Stub host prepared transaction (the host-side nonthrowing commit)

private final class StubHostPreparedTransaction: MonaPreparedWorkspaceTransaction {
    let identity: MonaWorkspaceTransactionIdentity
    private(set) var commitCallCount = 0
    private(set) var abortCallCount = 0
    private var committed = false
    private var aborted = false
    /// The model version id at the moment `commit()` ran. Used by the ordering
    /// test to prove external commit precedes open-model publish.
    private(set) var modelVersionAtCommit: Int? = nil
    private weak var modelRef: MonaCodeModel?

    init(identity: MonaWorkspaceTransactionIdentity, model: MonaCodeModel?) {
        self.identity = identity
        self.modelRef = model
    }

    func commit() {
        guard !committed else { return }
        committed = true
        commitCallCount += 1
        modelVersionAtCommit = modelRef?.getVersionId()
    }

    func abort() async {
        guard !aborted else { return }
        aborted = true
        abortCallCount += 1
    }
}

// MARK: - Stub non-transactional host (applyExternalOperation path)

private final class StubNonTransactionalHost: MonaWorkspaceEditHost {
    let capabilities = MonaWorkspaceEditCapabilities(
        appliesResourceOperations: true,
        supportsTransactional: false,
        supportsUndoReceipts: true
    )

    private let failOnOpIndex: Int?
    private let failure: Error
    private(set) var appliedOps: [(op: MonaExternalWorkspaceOperation, index: Int, receipt: MonaWorkspaceUndoReceipt)] = []

    init(failOnOpIndex: Int?, failure: Error) {
        self.failOnOpIndex = failOnOpIndex
        self.failure = failure
    }

    func applyExternalOperation(
        _ operation: MonaExternalWorkspaceOperation,
        index: Int,
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaWorkspaceOperationResult {
        if index == failOnOpIndex {
            throw failure
        }
        let receipt = MonaWorkspaceUndoReceipt(token: "undo-\(index)")
        appliedOps.append((operation, index, receipt))
        return MonaWorkspaceOperationResult(applied: true, undoReceipt: receipt)
    }

    private(set) var undoneReceipts: [MonaWorkspaceUndoReceipt] = []
    func undoExternalOperation(receipt: MonaWorkspaceUndoReceipt) async -> Bool {
        undoneReceipts.append(receipt)
        return true
    }

    func prepareAtomicExternalOperations(
        _ operations: [MonaExternalWorkspaceOperation],
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaPreparedWorkspaceTransaction {
        // Non-transactional host never offers atomic prepare.
        throw MonaHostContractError.workspaceAuthorityDeclined
    }
}
