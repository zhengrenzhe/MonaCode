// MonaTransactionGateway.swift
//
// P01-T009 — Make one edit transaction gateway own mutation and version truth.
//
// `MonaTransactionGateway` is the single owner of mutation and version truth
// for a `MonaCodeModel`. It is the Swift counterpart of the edit-application
// chokepoint Monaco routes every batch through before it touches the text model
// (monaco-editor 0.56.0): a transaction is begun, edits are prepared against it
// WITHOUT mutating the published model state, and the whole unit (text +
// version + alternative version + events + selections + undo metadata) is
// committed as one ordered unit or rolled back wholesale.
//
// Responsibilities:
//
//   - `beginTransaction()` creates a `MonaEditTransaction` capturing the
//     model's current version id. Only one transaction is active at a time;
//     beginning a second invalidates the first (reentrant invalidation → its
//     `commit()` returns `.dropped(reason: "reentrant invalidation")`).
//   - `commit(_:)` validates the captured version against the live model,
//     validates every prepared operation's range, applies the text batch
//     through the model (one `applyEdits` call → one version bump + one
//     content-change event), pushes any prepared EOL change, and records the
//     prepared selections + undo metadata as the committed unit.
//   - `rollback(_:)` discards every prepared component; the model is untouched
//     because preparation never mutated it.
//   - On version divergence (the model was mutated directly, bypassing the
//     gateway), `commit` drops the transaction as stale — unless the
//     transaction enabled reconcile, in which case the prepared operations are
//     re-validated against the current model and reapplied, returning
//     `.reconciled(changes:)`.
//
// The gateway wraps an existing `MonaCodeModel`; text truth continues to live
// in the Piece Tree. The gateway owns the TRANSACTIONAL mutation truth: the
// version captured at `beginTransaction()` is the authority, and any divergence
// is reported as a stale or reconciled transaction.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The single owner of mutation and version truth for a `MonaCodeModel`.
///
/// Create with `init(model:)`. Begin a transaction with `beginTransaction()`,
/// prepare edits on the returned `MonaEditTransaction`, and resolve it with
/// `commit()` or `rollback()`. The gateway serializes transactions: only one
/// is active at a time.
public final class MonaTransactionGateway {

    // MARK: - Owned truth

    /// The model this gateway owns transactional mutation truth for. Text
    /// truth lives in the model's Piece Tree; the gateway owns the
    /// transactional mutation path.
    public let model: MonaCodeModel

    /// The transaction currently active on this gateway, or `nil` when no
    /// transaction is open. Only one transaction is active at a time; beginning
    /// a second invalidates the first.
    private var activeTransaction: MonaEditTransaction? = nil

    /// The selections committed by the most recent successful commit (applied
    /// or reconciled). Empty until a commit records selections.
    public private(set) var lastCommittedSelections: [MonaSelection] = []

    /// The undo metadata committed by the most recent successful commit.
    /// `.empty` until a commit records undo metadata.
    public private(set) var lastCommittedUndoMetadata: MonaUndoMetadata = .empty

    // MARK: - Initialization

    /// Creates a gateway that owns transactional mutation truth for `model`.
    public init(model: MonaCodeModel) {
        self.model = model
    }

    // MARK: - State

    /// `true` when a transaction is currently active (begun but not yet
    /// committed or rolled back).
    public var hasOpenTransaction: Bool {
        return activeTransaction != nil
    }

    // MARK: - Begin

    /// Begins a new edit transaction, capturing the model's current version id
    /// as the transaction's version truth.
    ///
    /// If a transaction is already active, it is invalidated (reentrant
    /// invalidation): its `commit()` will subsequently return
    /// `.dropped(reason: "reentrant invalidation")` and its `rollback()` will
    /// return `.rolledBack(reason: "rolled back")`.
    public func beginTransaction() -> MonaEditTransaction {
        // Invalidate any currently-active transaction. It is no longer the
        // gateway's active transaction; its prepared components are discarded
        // by its own rollback/commit when the caller resolves it.
        if let previous = activeTransaction {
            previous.markInvalidated()
        }
        let tx = MonaEditTransaction(
            gateway: self,
            startVersionId: model.getVersionId(),
            startAlternativeVersionId: model.getAlternativeVersionId()
        )
        activeTransaction = tx
        return tx
    }

    // MARK: - Commit

    /// Commits `transaction` as one ordered unit. Returns the typed outcome.
    ///
    /// If `transaction` is not the gateway's active one (it was invalidated by
    /// a reentrant `beginTransaction()`, or it was already closed), the call
    /// drops it.
    @discardableResult
    public func commit(_ transaction: MonaEditTransaction) -> MonaReconciliationOutcome {
        // Already terminal? Return a stable "closed" outcome.
        if transaction.isClosed {
            return .dropped(reason: MonaTransactionReason.transactionClosed)
        }

        // Not the active transaction (was invalidated reentrantly).
        guard transaction === activeTransaction else {
            // An invalidated transaction resolves as dropped.
            transaction.markDropped()
            return .dropped(reason: MonaTransactionReason.reentrantInvalidation)
        }

        // 1. Cancellation: if the attached token is cancelled, drop before any
        //    mutation.
        if transaction.cancellationToken.isCancellationRequested {
            transaction.markDropped()
            activeTransaction = nil
            return .dropped(reason: MonaTransactionReason.cancelled)
        }

        // 2. Version truth: detect direct mutation that bypassed the gateway.
        let liveVersion = model.getVersionId()
        if liveVersion != transaction.startVersionId {
            if transaction.reconcileEnabled {
                return reconcileAndCommit(transaction)
            }
            transaction.markDropped()
            activeTransaction = nil
            return .dropped(reason: MonaTransactionReason.staleVersion)
        }

        // 3. Validation: every prepared operation's range must be valid
        //    as-given (the model would not clamp it). A range that would clamp
        //    is a validation failure → roll back, model untouched.
        for op in transaction.preparedOperations {
            guard model.isValidRange(op.range) else {
                transaction.markRolledBack()
                activeTransaction = nil
                return .rolledBack(reason: MonaTransactionReason.validationFailure)
            }
        }

        // 4. Apply the text batch + EOL as one ordered unit. applyEdits applies
        //    the whole batch atomically (one version bump, one content-change
        //    event); pushEOL is a second version bump + event when prepared.
        return applyPrepared(transaction)
    }

    // MARK: - Rollback

    /// Reverts every prepared component on `transaction`, leaving the model
    /// untouched (preparation never mutated it). Returns `.rolledBack`.
    @discardableResult
    public func rollback(_ transaction: MonaEditTransaction) -> MonaReconciliationOutcome {
        if transaction.isClosed {
            return .rolledBack(reason: MonaTransactionReason.transactionClosed)
        }
        // Whether the transaction is the active one or was invalidated, rolling
        // it back discards its prepared components. The model is untouched
        // because prepare never mutated it.
        transaction.markRolledBack()
        if transaction === activeTransaction {
            activeTransaction = nil
        }
        return .rolledBack(reason: MonaTransactionReason.rolledBack)
    }

    // MARK: - Private: apply the prepared unit (clean or reconciled)

    /// Applies `transaction.preparedOperations` and `preparedEOL` through the
    /// model, records the committed selections + undo metadata, and returns
    /// `.applied`. The caller has already validated ranges against the live
    /// model.
    private func applyPrepared(_ transaction: MonaEditTransaction) -> MonaReconciliationOutcome {
        let ops = transaction.preparedOperations
        if !ops.isEmpty {
            _ = model.applyEdits(ops)
        }
        if let eol = transaction.preparedEOL {
            model.pushEOL(eol)
        }
        recordCommit(transaction)
        transaction.markApplied()
        activeTransaction = nil
        return .applied
    }

    /// Reconciles a version-divergent transaction: re-validates each prepared
    /// operation's range against the CURRENT model, clamping and recording any
    /// change, then reapplies the (possibly adjusted) batch and returns
    /// `.reconciled(changes:)`.
    private func reconcileAndCommit(_ transaction: MonaEditTransaction) -> MonaReconciliationOutcome {
        var changes: [String] = []
        changes.append("version \(transaction.startVersionId)->\(model.getVersionId())")

        // Re-validate each operation against the current model. A range that
        // would clamp is replaced with the validated range and the clamp is
        // recorded; a range that survives unchanged is applied as-is.
        var adjustedOps: [MonaModelEditOperation] = []
        adjustedOps.reserveCapacity(transaction.preparedOperations.count)
        for op in transaction.preparedOperations {
            let validated = model.validateRange(op.range)
            if validated != op.range {
                changes.append("operation range clamped to valid bounds")
            }
            adjustedOps.append(MonaModelEditOperation(
                range: validated,
                text: op.text,
                forceMoveMarkers: op.forceMoveMarkers
            ))
        }

        if !adjustedOps.isEmpty {
            _ = model.applyEdits(adjustedOps)
        }
        if let eol = transaction.preparedEOL {
            model.pushEOL(eol)
        }
        recordCommit(transaction)
        transaction.markApplied()
        activeTransaction = nil
        return .reconciled(changes: changes)
    }

    /// Records the committed selections + undo metadata from `transaction` as
    /// the gateway's last-committed unit.
    private func recordCommit(_ transaction: MonaEditTransaction) {
        lastCommittedSelections = transaction.preparedSelections
        lastCommittedUndoMetadata = transaction.preparedUndoMetadata
    }
}
