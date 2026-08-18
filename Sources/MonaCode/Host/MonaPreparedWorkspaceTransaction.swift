// MonaPreparedWorkspaceTransaction.swift
//
// P07-T006 — Implement the four-outcome WorkspaceEdit transaction.
//
// `MonaPreparedWorkspaceEditTransaction` is the component-side prepared
// transaction — the atomic apply-external-then-publish-model transaction built
// by `MonaWorkspaceEdit.apply(...)` (see MonaWorkspaceEdit.swift).
//
// It holds the two disjoint prepared slices of a workspace edit:
//
//   - `openModelMutations`     — the prepared open-model mutations. Each
//                                 captures the model + its start version id + the
//                                 edits to publish. The model is NOT mutated
//                                 during preparation — only its start version is
//                                 captured — so rollback is a discard.
//   - `externalPrep`           — the prepared external slice. For a transactional
//                                 host this is the host's
//                                 `MonaPreparedWorkspaceTransaction` (prepared
//                                 but not committed; its `commit()` is
//                                 nonthrowing-atomic). For a non-transactional
//                                 host this is a marker — ops are applied
//                                 one-by-one at commit time via
//                                 `applyExternalOperation` (throwing, with
//                                 undo-on-fail).
//
// The commit ordering is load-bearing:
//
//   external commit (nonthrowing atomic)  →  open-model publish
//
// The external commit MUST succeed before any open-model change is published.
// If external preparation OR commit fails, EVERY prepared open-model mutation is
// rolled back (discarded — the model was never touched). No partial state.
//
// NOTE ON NAMING: the host-side protocol `MonaPreparedWorkspaceTransaction`
// (defined in MonaHostContracts.swift, P07-T005) is DISTINCT from this
// component-side class `MonaPreparedWorkspaceEditTransaction`. The host protocol
// is the host's prepared atomic commit; this class is the component's
// orchestrator that wraps the host protocol plus the prepared open-model
// mutations. The two must not collide in the module's namespace, hence the
// distinct spelling. This file is named per the P07-T006 contract
// (`MonaPreparedWorkspaceTransaction.swift`); the type inside is the component
// orchestrator.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaPreparedOpenModelMutation (internal)

/// A prepared open-model mutation: the model, its captured start version id, and
/// the edits to publish on commit. The model is NOT mutated during preparation
/// — only its start version is captured — so rollback is a discard.
internal struct MonaPreparedOpenModelMutation {
    let model: MonaCodeModel
    let startVersionId: Int
    let edits: [MonaModelEditOperation]
}

// MARK: - MonaPreparedWorkspaceEditTransaction

/// The component-side prepared workspace transaction — the atomic
/// apply-external-then-publish-model transaction.
///
/// Created by `MonaWorkspaceEdit.apply(...)` after the open-model mutations are
/// captured and the external slice is prepared. `commit(cancellationToken:)`
/// runs the external commit FIRST (nonthrowing-atomic for a transactional host;
/// per-op with undo-on-fail for a non-transactional host) and only then
/// publishes the open-model changes. `rollback()` discards every prepared
/// open-model mutation and aborts the prepared external transaction.
public final class MonaPreparedWorkspaceEditTransaction {

    // The prepared open-model mutations. NEVER mutated during preparation.
    private let openModelMutations: [MonaPreparedOpenModelMutation]

    // The explicit host (authorizes external operations). Non-nil whenever
    // external operations are present.
    private let host: MonaWorkspaceEditHost

    // The external operations to commit (in order).
    private let externalOperations: [MonaExternalWorkspaceOperation]

    // The prepared external slice.
    private let externalPrep: MonaExternalPreparation

    // The stable transaction identity (assigned by the component, opaque to
    // the host).
    private let transactionID: MonaWorkspaceTransactionIdentity

    // Receipts collected during a non-transactional external commit, used to
    // undo already-applied ops on mid-batch failure.
    private var appliedReceipts: [(index: Int, receipt: MonaWorkspaceUndoReceipt)] = []

    /// Internal initializer — created by `MonaWorkspaceEdit.apply(...)`.
    internal init(
        openModelMutations: [MonaPreparedOpenModelMutation],
        host: MonaWorkspaceEditHost,
        externalOperations: [MonaExternalWorkspaceOperation],
        externalPrep: MonaExternalPreparation,
        transactionID: MonaWorkspaceTransactionIdentity
    ) {
        self.openModelMutations = openModelMutations
        self.host = host
        self.externalOperations = externalOperations
        self.externalPrep = externalPrep
        self.transactionID = transactionID
    }

    /// Commits the prepared transaction: external commit first, then open-model
    /// publish. Returns one of the four terminal outcomes.
    ///
    /// Ordering: the external commit (nonthrowing-atomic for a transactional
    /// host; per-op for a non-transactional host) MUST succeed BEFORE any
    /// open-model change is published. If external preparation or commit fails,
    /// every prepared open-model mutation is rolled back (the model was never
    /// touched during preparation).
    public func commit(
        cancellationToken: MonaCancellationToken = .none
    ) async -> MonaWorkspaceEditOutcome {

        // 1. Cancellation checkpoint before the external commit.
        if cancellationToken.isCancellationRequested {
            // External not yet committed; abort the prepared external
            // transaction (transactional path) and roll back open-model
            // (discard — never touched).
            await abortExternal()
            return .canceled(stage: .commitExternal)
        }

        // 2. External commit. ORDERING: this MUST succeed before open-model
        //    publish.
        let externalOutcome = await commitExternal(cancellationToken: cancellationToken)
        switch externalOutcome {
        case .succeeded:
            break  // fall through to open-model publish
        case .rejected(let index, let reason):
            // The host declined external authority during the non-transactional
            // commit. Roll back open-model (discard — never touched).
            return .rejected(operationIndex: index, reason: reason)
        case .failed(let details):
            // The non-transactional commit failed mid-batch. Undo the
            // already-applied ops and roll back open-model (discard).
            await undoAppliedOps()
            return .failed(details)
        case .canceled:
            // Cancellation mid-batch (non-transactional). Undo applied ops.
            await undoAppliedOps()
            return .canceled(stage: .commitExternal)
        }

        // 3. External commit succeeded. Cancellation checkpoint before
        //    open-model publish.
        if cancellationToken.isCancellationRequested {
            // The external commit is irreversible (transactional) or already
            // applied (non-transactional). Open-model changes are NOT
            // published.
            return .canceled(stage: .publishOpenModel)
        }

        // 4. Publish the open-model changes.
        return Self.publishOpenModel(openModelMutations, cancellationToken: cancellationToken)
    }

    /// Rolls back every prepared open-model mutation and aborts the prepared
    /// external transaction.
    ///
    /// Preparation never mutated the published model state — it only captured
    /// the start version — so the open-model rollback is a discard (the model
    /// is untouched). The prepared external transaction (transactional path)
    /// is aborted (idempotent). For the non-transactional path, any
    /// already-applied ops are undone via `undoExternalOperation`.
    public func rollback() async {
        await abortExternal()
        await undoAppliedOps()
        // Open-model mutations are discarded — the model was never touched.
    }

    // MARK: - External commit

    /// The outcome of the external commit phase.
    private enum ExternalCommitOutcome {
        case succeeded
        case rejected(index: Int, reason: String)
        case failed(MonaWorkspaceEditFailureDetails)
        case canceled
    }

    /// Runs the external commit. For a transactional host this is the host's
    /// prepared transaction's nonthrowing-atomic `commit()`. For a
    /// non-transactional host this applies each op one-by-one via
    /// `applyExternalOperation` (throwing), undoing already-applied ops on
    /// mid-batch failure.
    private func commitExternal(
        cancellationToken: MonaCancellationToken
    ) async -> ExternalCommitOutcome {

        switch externalPrep {
        case .transactional(let prepared):
            // Nonthrowing-atomic external commit. The host guarantees
            // allocation-free commit with no externally reportable failure.
            prepared.commit()
            return .succeeded

        case .nonTransactional:
            // Apply each op one-by-one. A mid-batch failure undoes the
            // already-applied ops (the caller of commitExternal undoes them
            // via undoAppliedOps on failure).
            for (index, op) in externalOperations.enumerated() {
                if cancellationToken.isCancellationRequested {
                    return .canceled
                }
                do {
                    let result = try await host.applyExternalOperation(
                        op, index: index, transactionID: transactionID
                    )
                    if result.applied, let receipt = result.undoReceipt {
                        appliedReceipts.append((index: index, receipt: receipt))
                    }
                } catch MonaHostContractError.workspaceAuthorityDeclined {
                    return .rejected(
                        index: index,
                        reason: "workspace authority declined at operation \(index)"
                    )
                } catch {
                    return .failed(MonaWorkspaceEditFailureDetails(
                        stage: .commitExternal,
                        operationIndex: index,
                        errorDescription: "\(error)"
                    ))
                }
            }
            return .succeeded
        }
    }

    // MARK: - Publish open-model

    /// Publishes the prepared open-model mutations. Each mutation's captured
    /// start version is validated against the live model — a divergence means the
    /// model was mutated directly, bypassing the transaction, and the publish
    /// fails (the external commit has already succeeded; this is a publish-stage
    /// failure, not an external failure).
    internal static func publishOpenModel(
        _ mutations: [MonaPreparedOpenModelMutation],
        cancellationToken: MonaCancellationToken
    ) -> MonaWorkspaceEditOutcome {
        for mutation in mutations {
            if cancellationToken.isCancellationRequested {
                return .canceled(stage: .publishOpenModel)
            }
            // Validate the model was not mutated directly during preparation.
            guard mutation.startVersionId == mutation.model.getVersionId() else {
                return .failed(MonaWorkspaceEditFailureDetails(
                    stage: .publishOpenModel,
                    operationIndex: nil,
                    errorDescription: "model version diverged: captured \(mutation.startVersionId), live \(mutation.model.getVersionId())"
                ))
            }
            // Publish: apply the edits as one unit (one version bump + one
            // content-change event).
            _ = mutation.model.applyEdits(mutation.edits)
        }
        return .applied
    }

    // MARK: - Abort / undo

    /// Aborts the prepared external transaction (transactional path). No-op for
    /// the non-transactional path. Idempotent — the host's `abort()` is
    /// idempotent.
    private func abortExternal() async {
        if case .transactional(let prepared) = externalPrep {
            await prepared.abort()
        }
    }

    /// Undoes every already-applied external op (non-transactional path). Each
    /// op is undone via `undoExternalOperation(receipt:)`. Order is not
    /// guaranteed by the host protocol; this best-effort undo is the
    /// non-transactional rollback.
    private func undoAppliedOps() async {
        for (_, receipt) in appliedReceipts {
            _ = await host.undoExternalOperation(receipt: receipt)
        }
        appliedReceipts.removeAll()
    }
}
