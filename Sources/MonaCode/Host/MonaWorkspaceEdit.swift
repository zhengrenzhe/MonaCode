// MonaWorkspaceEdit.swift
//
// P07-T006 — Implement the four-outcome WorkspaceEdit transaction.
//
// `MonaWorkspaceEdit` is the Swift counterpart of Monaco's workspace edit
// (monaco-editor 0.56.0): the atomic apply-external-then-publish-model
// transaction used by rename, code action, and other workspace-edit paths. It
// carries two disjoint slices:
//
//   - `openModelEdits`        — edits to OPEN models. These stay component-owned
//                                (component truth): they are prepared inside the
//                                component (the model's start version is captured
//                                WITHOUT mutating the published state) and
//                                published as one unit only after the external
//                                commit has succeeded.
//   - `externalOperations`     — file create / rename / delete operations. These
//                                are NEVER component-owned: they are prepared and
//                                committed through the explicit host
//                                (`MonaWorkspaceEditHost` from P07-T005), which
//                                must authorize each external op.
//
// The transaction exposes four terminal outcomes:
//
//   - `.applied`               — the external commit succeeded AND every prepared
//                                open-model change was published.
//   - `.rejected(index, reason)` — the host DECLINED external authority (it
//                                threw `workspaceAuthorityDeclined`). The rejecting
//                                operation index and an exact reason are carried.
//   - `.failed(details)`       — an operation FAILED with exact failure details
//                                (stage, operation index, error description).
//   - `.canceled(stage)`       — cancellation was requested via the token; the
//                                stage at which it was observed is carried.
//
// ORDERING (load-bearing): the external commit is nonthrowing-atomic and MUST
// succeed BEFORE any open-model change is published. If the external commit has
// not succeeded, open-model changes do not publish.
//
// ATOMICITY (load-bearing): if external preparation OR commit fails, EVERY
// prepared open-model mutation is rolled back. Preparation never mutates the
// published model state — it only captures the start version — so rollback is a
// discard (the model is untouched). No partial state survives.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaOpenModelEdit

/// An open-model edit: the model URI to edit plus the edit operations to apply.
/// Open-model edits are component-owned — they are NEVER delegated to the host.
///
/// Not `Equatable`: `MonaURI` is a cache-observable reference type (matching
/// `MonaExternalWorkspaceOperation`, which also omits `Equatable`).
public struct MonaOpenModelEdit {

    /// The URI of the open model to edit.
    public let modelURI: MonaURI

    /// The edit operations to apply to the model (in pre-edit coordinates).
    public let edits: [MonaModelEditOperation]

    /// Creates an open-model edit.
    public init(modelURI: MonaURI, edits: [MonaModelEditOperation]) {
        self.modelURI = modelURI
        self.edits = edits
    }
}

// MARK: - MonaWorkspaceEdit

/// A workspace edit: open-model edits (component truth) plus external resource
/// operations (delegated to the host).
///
/// Apply through `apply(host:modelResolver:transactionID:cancellationToken:)`,
/// which prepares both slices and commits them as one atomic
/// apply-external-then-publish-model transaction.
public struct MonaWorkspaceEdit {

    /// The open-model edits (component truth). Prepared inside the component
    /// and published only after the external commit has succeeded.
    public let openModelEdits: [MonaOpenModelEdit]

    /// The external resource operations (create / rename / delete). Prepared
    /// and committed through the explicit `MonaWorkspaceEditHost`.
    public let externalOperations: [MonaExternalWorkspaceOperation]

    /// Creates a workspace edit.
    public init(
        openModelEdits: [MonaOpenModelEdit] = [],
        externalOperations: [MonaExternalWorkspaceOperation] = []
    ) {
        self.openModelEdits = openModelEdits
        self.externalOperations = externalOperations
    }
}

// MARK: - MonaWorkspaceEditOutcome

/// The four terminal outcomes of a workspace-edit transaction.
public enum MonaWorkspaceEditOutcome: Equatable {

    /// The external commit succeeded AND every prepared open-model change was
    /// published.
    case applied

    /// The host DECLINED external authority (it threw
    /// `MonaHostContractError.workspaceAuthorityDeclined`). Carries the
    /// rejecting operation index and an exact reason. The open-model mutations
    /// were rolled back — the model is untouched.
    case rejected(operationIndex: Int, reason: String)

    /// An operation FAILED with exact failure details. Carries the stage, the
    /// failing operation index (nil for a publish-stage failure), and the error
    /// description. The open-model mutations were rolled back — the model is
    /// untouched (unless the failure was at publish time, after the external
    /// commit had already succeeded).
    case failed(MonaWorkspaceEditFailureDetails)

    /// Cancellation was requested via the token. Carries the stage at which
    /// cancellation was observed. The open-model mutations were rolled back
    /// (the model is untouched) unless cancellation was observed after the
    /// external commit had already succeeded.
    case canceled(stage: MonaWorkspaceEditCancelStage)
}

// MARK: - MonaWorkspaceEditFailureDetails

/// Exact failure details for the `.failed` outcome.
public struct MonaWorkspaceEditFailureDetails: Equatable, Sendable {

    /// The stage at which the failure occurred.
    public let stage: Stage

    /// The index of the failing external operation, or `nil` for a failure that
    /// is not tied to a single external op (e.g. a publish-stage divergence).
    public let operationIndex: Int?

    /// A human-readable description of the failure.
    public let errorDescription: String

    /// The stage at which a workspace-edit failure occurs.
    public enum Stage: String, Sendable, Equatable {
        /// A referenced open model could not be resolved.
        case resolveOpenModel
        /// External preparation failed (the host threw during
        /// `prepareAtomicExternalOperations` or `applyExternalOperation`).
        case prepareExternal
        /// The external (non-transactional) commit failed mid-batch — an
        /// `applyExternalOperation` threw after earlier ops had already been
        /// applied.
        case commitExternal
        /// Open-model publish failed (a model's version diverged from its
        /// captured start version).
        case publishOpenModel
    }

    /// Creates failure details.
    public init(stage: Stage, operationIndex: Int?, errorDescription: String) {
        self.stage = stage
        self.operationIndex = operationIndex
        self.errorDescription = errorDescription
    }
}

// MARK: - MonaWorkspaceEditCancelStage

/// The stage at which cancellation was observed during a workspace-edit
/// transaction.
public enum MonaWorkspaceEditCancelStage: String, Sendable, Equatable {

    /// Cancellation was observed before external preparation began (or during
    /// it, before any external op was applied). No external state was touched.
    case prepareExternal

    /// Cancellation was observed after external preparation succeeded but
    /// before the external commit ran. The prepared external transaction was
    /// aborted.
    case commitExternal

    /// Cancellation was observed after the external commit succeeded but
    /// before the open-model changes were published. The external commit is
    /// irreversible; the open-model changes were not published.
    case publishOpenModel
}

// MARK: - MonaWorkspaceEdit.apply

extension MonaWorkspaceEdit {

    /// Resolves a model for a URI. The host app supplies this — the component
    /// owns no model registry for external URIs.
    public typealias ModelResolver = (MonaURI) -> MonaCodeModel?

    /// Applies this workspace edit as one atomic
    /// apply-external-then-publish-model transaction.
    ///
    /// The flow:
    ///   1. Resolve + capture the open-model mutations inside component truth
    ///      (the model's start version is captured WITHOUT mutating the
    ///      published state).
    ///   2. If the cancellation token is already cancelled, return
    ///      `.canceled(.prepareExternal)` — nothing was touched.
    ///   3. If there are external operations, prepare them through the explicit
    ///      host. A host that declines external authority produces
    ///      `.rejected`; a host that throws another error produces `.failed`
    ///      (stage `.prepareExternal`). Either way the open-model mutations
    ///      are rolled back (discarded — the model was never touched).
    ///   4. Commit the prepared transaction: the external commit (nonthrowing
    ///      atomic for a transactional host; per-op with undo-on-fail for a
    ///      non-transactional host) runs FIRST, and only after it has
    ///      succeeded are the open-model changes published.
    public func apply(
        host: MonaWorkspaceEditHost?,
        modelResolver: ModelResolver,
        transactionID: MonaWorkspaceTransactionIdentity,
        cancellationToken: MonaCancellationToken = .none
    ) async -> MonaWorkspaceEditOutcome {

        // 1. Resolve + capture open-model mutations (NO model mutation).
        var mutations: [MonaPreparedOpenModelMutation] = []
        for (index, openEdit) in openModelEdits.enumerated() {
            guard let model = modelResolver(openEdit.modelURI) else {
                return .failed(MonaWorkspaceEditFailureDetails(
                    stage: .resolveOpenModel,
                    operationIndex: index,
                    errorDescription: "no open model resolved for uri"
                ))
            }
            mutations.append(MonaPreparedOpenModelMutation(
                model: model,
                startVersionId: model.getVersionId(),
                edits: openEdit.edits
            ))
        }

        // 2. Cancellation checkpoint before external preparation.
        if cancellationToken.isCancellationRequested {
            // Nothing was prepared; open-model mutations are discarded.
            return .canceled(stage: .prepareExternal)
        }

        // 3. Open-model-only path: no external ops, no host required.
        if externalOperations.isEmpty {
            return MonaPreparedWorkspaceEditTransaction.publishOpenModel(
                mutations, cancellationToken: cancellationToken
            )
        }

        // 4. External ops present — an explicit host is required to authorize
        //    them. No host ⇒ rejection of the first external op.
        guard let host = host else {
            // Open-model mutations are discarded (never applied).
            return .rejected(
                operationIndex: 0,
                reason: "no workspace-edit host attached to authorize external operations"
            )
        }

        // 5. Prepare external operations through the explicit host.
        let externalPrep: MonaExternalPreparation
        if host.capabilities.supportsTransactional {
            // Transactional path: prepare an atomic nonthrowing commit.
            let prepared: MonaPreparedWorkspaceTransaction
            do {
                prepared = try await host.prepareAtomicExternalOperations(
                    externalOperations, transactionID: transactionID
                )
            } catch MonaHostContractError.workspaceAuthorityDeclined {
                // The host declined external authority. Roll back open-model.
                return .rejected(
                    operationIndex: 0,
                    reason: "workspace authority declined by host"
                )
            } catch {
                // A non-authority failure during external preparation.
                return .failed(MonaWorkspaceEditFailureDetails(
                    stage: .prepareExternal,
                    operationIndex: 0,
                    errorDescription: "\(error)"
                ))
            }
            externalPrep = .transactional(prepared)
        } else {
            // Non-transactional path: ops are applied one-by-one at commit
            // time via applyExternalOperation. Nothing to prepare here.
            externalPrep = .nonTransactional
        }

        // 6. Build the prepared transaction and commit it.
        let transaction = MonaPreparedWorkspaceEditTransaction(
            openModelMutations: mutations,
            host: host,
            externalOperations: externalOperations,
            externalPrep: externalPrep,
            transactionID: transactionID
        )
        return await transaction.commit(cancellationToken: cancellationToken)
    }
}

// MARK: - MonaExternalPreparation (internal)

/// The result of preparing the external slice of a workspace edit.
internal enum MonaExternalPreparation {
    /// The host prepared an atomic nonthrowing commit (transactional path).
    case transactional(MonaPreparedWorkspaceTransaction)
    /// The host applies ops one-by-one at commit time (non-transactional path).
    case nonTransactional
}
