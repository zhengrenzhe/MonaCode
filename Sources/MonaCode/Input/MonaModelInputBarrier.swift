// MonaModelInputBarrier.swift
//
// P04-T005 — Replicate multi-cursor input through ModelInputBarrier.
//
// `MonaModelInputBarrier` is the chokepoint a multi-cursor input batch passes
// through before it may mutate the text model — the Swift counterpart of the
// multi-cursor edit application path Monaco routes through its command /
// cursor controller before pushing onto the text model (monaco-editor 0.56.0).
//
// The barrier prepares a primary cursor edit plus zero or more secondary cursor
// edits against ONE immutable model version (captured at the start), applies
// the six replication rules (overlap / merge / ordering / snippet / clipboard
// / composition) BEFORE commit, and publishes ALL cursor edits + selections in
// ONE transaction through the P01-T009 transaction gateway — or publishes NONE
// (atomic: any failure — overlap rejection, validation failure, stale version,
// or cancellation — rolls back the entire batch, leaving the model untouched).
//
// The barrier wraps a `MonaCodeModel` (P01-T008) and a `MonaTransactionGateway`
// (P01-T009). Text truth lives in the Piece Tree; the gateway owns the
// transactional mutation truth; the barrier owns the MULTI-CURSOR replication
// truth: the version captured at `prepare` is the authority the edits are
// prepared against, and any divergence (direct mutation between prepare and
// commit) drops the input before mutation.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A multi-cursor input plan captured against one immutable model version.
///
/// Produced by `MonaModelInputBarrier.prepare(_:)`. Carries the plan plus the
/// model version id and alternative version id captured at prepare time, which
/// the barrier validates against the live model at commit to detect direct
/// mutation that bypassed the barrier.
public struct MonaPreparedMultiCursorInput: Equatable {

    /// The captured multi-cursor plan.
    public let plan: MonaMultiCursorInputPlan

    /// The model's version id at prepare time. The barrier drops the input if
    /// this diverges from the live version at commit.
    public let capturedVersionId: Int

    /// The model's alternative version id at prepare time.
    public let capturedAlternativeVersionId: Int

    /// Creates a prepared input handle. (Barrier-only construction.)
    public init(
        plan: MonaMultiCursorInputPlan,
        capturedVersionId: Int,
        capturedAlternativeVersionId: Int
    ) {
        self.plan = plan
        self.capturedVersionId = capturedVersionId
        self.capturedAlternativeVersionId = capturedAlternativeVersionId
    }
}

/// The typed result of committing a multi-cursor input through the barrier.
///
/// Branch on the case to learn whether the batch committed (all cursor edits +
/// selections published in one transaction), was dropped before mutation
/// (stale version), or was rolled back (overlap rejection, validation failure,
/// or cancellation — the model is untouched).
public enum MonaModelInputBarrierOutcome: Equatable {

    /// Every cursor edit + selection committed cleanly as one transaction. The
    /// associated selections are the post-edit caret positions, one per
    /// surviving cursor.
    case applied(selections: [MonaSelection])

    /// The input was dropped before the model was mutated. The captured version
    /// had diverged from the live model (direct mutation between prepare and
    /// commit), or the transaction gateway dropped the transaction (cancellation,
    /// reentrant invalidation, or a closed transaction).
    case dropped(reason: String)

    /// The input was rolled back: every prepared component was reverted and the
    /// published model state is unchanged. Reasons include overlap rejection,
    /// validation failure (a prepared range was not valid as-given), and
    /// explicit rollback.
    case rolledBack(reason: String)
}

/// The chokepoint a multi-cursor input batch passes through before it may mutate
/// the text model.
///
/// Create with `init(model:)` (the barrier creates its own transaction gateway)
/// or `init(model:gateway:)` (to share an existing gateway). Prepare a
/// multi-cursor plan with `prepare(_:)` (captures the model version), then
/// commit with `commit(_:overlapPolicy:)` (applies the replication rules and
/// publishes all-or-none in one transaction). The convenience
/// `commit(_:overlapPolicy:)` taking a plan directly prepares then commits.
public final class MonaModelInputBarrier {

    // MARK: - Owned truth

    /// The model this barrier prepares multi-cursor edits against.
    public let model: MonaCodeModel

    /// The transaction gateway (P01-T009) the barrier publishes through. The
    /// barrier wraps an existing gateway when one is supplied; otherwise it
    /// creates and owns one.
    public let gateway: MonaTransactionGateway

    /// The model version id captured at the most recent `prepare`. Edits are
    /// prepared against this immutable version; commit drops the input if the
    /// live version has diverged.
    public private(set) var capturedVersionId: Int

    // MARK: - Initialization

    /// Creates a barrier that owns its own transaction gateway for `model`.
    public init(model: MonaCodeModel) {
        self.model = model
        self.gateway = MonaTransactionGateway(model: model)
        self.capturedVersionId = model.getVersionId()
    }

    /// Creates a barrier that publishes through the supplied `gateway`. The
    /// gateway must wrap `model`.
    public init(model: MonaCodeModel, gateway: MonaTransactionGateway) {
        self.model = model
        self.gateway = gateway
        self.capturedVersionId = model.getVersionId()
    }

    // MARK: - Prepare (capture one immutable model version)

    /// Prepares a multi-cursor plan against the model's CURRENT version,
    /// capturing that version as the immutable version the edits are prepared
    /// against. Returns a handle carrying the plan and the captured version.
    ///
    /// Preparation performs NO model mutation: the plan is a pure value, and
    /// the captured version is observed (not bumped).
    public func prepare(
        _ plan: MonaMultiCursorInputPlan
    ) -> MonaPreparedMultiCursorInput {
        capturedVersionId = model.getVersionId()
        return MonaPreparedMultiCursorInput(
            plan: plan,
            capturedVersionId: capturedVersionId,
            capturedAlternativeVersionId: model.getAlternativeVersionId()
        )
    }

    // MARK: - Commit (all-or-none in one transaction)

    /// Commits a prepared multi-cursor input as ONE transaction through the
    /// transaction gateway, applying the replication rules before commit.
    ///
    /// Flow:
    ///   1. Version truth — if the captured version diverged from the live
    ///      model (direct mutation between prepare and commit), drop the input.
    ///   2. Overlap + merge — resolve the plan; if overlap cannot be resolved
    ///      under `overlapPolicy`, roll back the whole batch.
    ///   3. Ordering + selections — order the operations in reverse
    ///      start-offset order and compute the per-cursor post-edit selections.
    ///   4. One transaction — prepare every operation + every selection on one
    ///      transaction and commit. The gateway validates every range; any
    ///      validation failure rolls back the whole batch (model untouched).
    ///
    /// Returns `.applied(selections:)` when the batch committed, `.dropped` when
    /// it was dropped before mutation (stale version), or `.rolledBack` when it
    /// was rolled back (overlap rejection or validation failure).
    @discardableResult
    public func commit(
        _ prepared: MonaPreparedMultiCursorInput,
        overlapPolicy: MonaOverlapPolicy = .reject
    ) -> MonaModelInputBarrierOutcome {
        // 1. Version truth: direct mutation bypassing the barrier invalidates
        //    the prepared edits' offsets — drop before any mutation.
        if prepared.capturedVersionId != model.getVersionId() {
            return .dropped(reason: MonaInputBarrierReason.staleVersion)
        }

        // 2. Overlap + merge replication rules.
        guard let resolved = prepared.plan.resolvingConflicts(overlapPolicy: overlapPolicy) else {
            return .rolledBack(reason: MonaInputBarrierReason.overlapRejected)
        }

        // 3. Ordering + selections (computed against the current, pre-commit
        //    model — the edits have not been applied yet).
        let operations = resolved.orderedOperations(model: model)
        let selections = resolved.resultingSelections(model: model)

        // 4. One transaction: prepare every operation + every selection, then
        //    commit. The gateway's commit validates every range and rolls back
        //    the whole batch on any validation failure (atomic all-or-none).
        let transaction = gateway.beginTransaction()
        if !operations.isEmpty {
            transaction.prepareEdits(operations)
        }
        transaction.prepareSelections(selections)

        let outcome = transaction.commit()
        switch outcome {
        case .applied, .reconciled:
            return .applied(selections: selections)
        case .dropped(let reason):
            return .dropped(reason: reason)
        case .rolledBack(let reason):
            return .rolledBack(reason: reason)
        }
    }

    /// Convenience: prepare a plan and commit it in one call.
    @discardableResult
    public func commit(
        _ plan: MonaMultiCursorInputPlan,
        overlapPolicy: MonaOverlapPolicy = .reject
    ) -> MonaModelInputBarrierOutcome {
        return commit(prepare(plan), overlapPolicy: overlapPolicy)
    }
}

// MARK: - Stable reason strings

/// Internal stable reason strings for `MonaModelInputBarrierOutcome`. The
/// strings are part of the observable contract (tests assert on them).
internal enum MonaInputBarrierReason {
    static let staleVersion = "stale version"
    static let overlapRejected = "overlap rejected"
}
