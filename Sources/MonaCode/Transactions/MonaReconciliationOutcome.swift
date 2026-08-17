// MonaReconciliationOutcome.swift
//
// P01-T009 — Make one edit transaction gateway own mutation and version truth.
//
// `MonaReconciliationOutcome` is the typed result of committing an edit
// transaction through the gateway — the Swift counterpart of the reconciled
// edit result Monaco produces when an edit batch is applied against a possibly
// moved model (monaco-editor 0.56.0). Every `MonaEditTransaction.commit()` and
// `MonaTransactionGateway.commit(_:)` returns one of four typed outcomes:
//
//   - `.applied`                 — the prepared unit committed cleanly.
//   - `.dropped(reason:)`         — the transaction was dropped before
//                                   mutation (cancellation, reentrant
//                                   invalidation, stale version, or a closed
//                                   transaction).
//   - `.reconciled(changes:)`     — the captured version had diverged but
//                                   reconcile was enabled; the prepared
//                                   operations were re-validated against the
//                                   current model and reapplied, and `changes`
//                                   describes the reconciliation.
//   - `.rolledBack(reason:)`      — a prepared component failed validation or
//                                   the caller explicitly rolled the transaction
//                                   back; every prepared component was reverted
//                                   and the model was left untouched.
//
// The outcome is the single source of truth for "what happened" in a
// transaction: callers branch on it rather than inspecting separate flags.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The typed result of committing an `MonaEditTransaction` through a
/// `MonaTransactionGateway`.
///
/// Branch on the case to learn whether the prepared unit committed, was dropped
/// before any mutation, was reconciled against a moved model, or was rolled
/// back with the model untouched. The associated `reason` / `changes` values
/// are stable, human-readable strings suitable for logging and tests.
public enum MonaReconciliationOutcome: Equatable {

    /// The prepared text + version + events + selections + undo metadata
    /// committed cleanly as one ordered unit.
    case applied

    /// The transaction was dropped before the model was mutated.
    ///
    /// Reasons (stable strings):
    ///   - `"reentrant invalidation"` — a second transaction was begun, so this
    ///     one is no longer the gateway's active transaction.
    ///   - `"cancelled"` — the attached cancellation token had cancellation
    ///     requested before commit.
    ///   - `"stale version"` — the captured version diverged from the model and
    ///     reconcile was not enabled.
    ///   - `"transaction closed"` — the transaction had already been committed
    ///     or rolled back.
    case dropped(reason: String)

    /// The captured version had diverged from the model, reconcile was enabled,
    /// and the prepared operations were re-validated against the current model
    /// and reapplied. `changes` describes the reconciliation (one entry per
    /// reconciled component).
    case reconciled(changes: [String])

    /// The transaction was rolled back: every prepared component was reverted
    /// and the published model state is unchanged.
    ///
    /// Reasons (stable strings):
    ///   - `"rolled back"` — the caller explicitly invoked `rollback()`.
    ///   - `"validation failure"` — a prepared operation's range was not valid
    ///     as-given (the model would clamp it), so the commit refused to apply.
    ///   - `"transaction closed"` — the transaction had already been closed.
    case rolledBack(reason: String)
}

// MARK: - Stable reason strings

/// Internal stable reason strings. Exposed as a private enum so the
/// implementation and any future tests share identical literals; the strings
/// themselves are part of the observable contract (tests assert on them).
internal enum MonaTransactionReason {
    static let reentrantInvalidation = "reentrant invalidation"
    static let cancelled = "cancelled"
    static let staleVersion = "stale version"
    static let transactionClosed = "transaction closed"

    static let rolledBack = "rolled back"
    static let validationFailure = "validation failure"
}
