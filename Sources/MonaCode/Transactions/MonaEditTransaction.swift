// MonaEditTransaction.swift
//
// P01-T009 — Make one edit transaction gateway own mutation and version truth.
//
// `MonaEditTransaction` is the prepared-but-not-applied edit unit — the Swift
// counterpart of Monaco's collected edit batch before it is pushed onto the
// text model (monaco-editor 0.56.0). A transaction is created by
// `MonaTransactionGateway.beginTransaction()` and accumulates prepared
// components WITHOUT mutating the published model state:
//
//   - text operations (`MonaModelEditOperation`)
//   - selections (cursor state for the future undo stack)
//   - undo metadata (label + isUndoing/isRedoing flags)
//   - an optional EOL change
//
// `commit()` applies every prepared component as one ordered unit through the
// gateway (text → version → events → selections → undo metadata). `rollback()`
// reverts every prepared component, leaving the model untouched. Both return a
// typed `MonaReconciliationOutcome`.
//
// The transaction captures the model's version id at begin time; the gateway
// uses it to detect divergence (direct mutation bypassing the gateway) and to
// drive the reconcile path. A transaction is single-use: once it has committed,
// been dropped, or been rolled back it is closed and further prepare calls are
// no-ops.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Undo metadata carried by a transaction for the future undo stack.
///
/// Phase 01 has no undo stack (the model's `pushStackElement` / `popStackElement`
/// are Phase 02 stubs); the transaction still collects this so the committed
/// unit carries undo information forward. `label` is the human-readable stack
/// label; `isUndoing` / `isRedoing` record whether the unit is part of an undo
/// or redo traversal (both `false` for a normal commit in Phase 01).
public struct MonaUndoMetadata: Equatable {

    /// The human-readable undo-stack label.
    public var label: String

    /// `true` when this unit is part of an undo traversal (Phase 02).
    public var isUndoing: Bool

    /// `true` when this unit is part of a redo traversal (Phase 02).
    public var isRedoing: Bool

    /// Creates undo metadata. Defaults model a non-undoing, non-redoing unit
    /// with an empty label.
    public init(label: String = "", isUndoing: Bool = false, isRedoing: Bool = false) {
        self.label = label
        self.isUndoing = isUndoing
        self.isRedoing = isRedoing
    }

    /// Empty undo metadata — the value carried by a transaction that prepared
    /// none, and the initial value of the gateway's `lastCommittedUndoMetadata`
    /// before any commit.
    ///
    /// A computed property (rather than a stored `static let`) so the type does
    /// not need to be `Sendable` for Swift 6's global-mutable-state check in
    /// Phase 01; concurrency isolation is established in Phase 02 (A+/R1),
    /// matching the pattern in `MonaModelOptions.defaults`.
    public static var empty: MonaUndoMetadata {
        return MonaUndoMetadata()
    }
}

/// A prepared-but-not-applied edit unit owned by a `MonaTransactionGateway`.
///
/// Create via `MonaTransactionGateway.beginTransaction()`. Prepare components
/// with the `prepare*` methods; none of them mutate the model. Resolve with
/// `commit()` (applies as one ordered unit) or `rollback()` (reverts every
/// prepared component). Both delegate to the owning gateway and return a typed
/// `MonaReconciliationOutcome`.
///
/// A transaction is single-use. Once closed (committed, dropped, or rolled
/// back) further `prepare*` calls are silently ignored and further
/// `commit()` / `rollback()` calls return the appropriate "transaction closed"
/// outcome.
public final class MonaEditTransaction {

    /// The transaction's phase in its single-use lifecycle.
    fileprivate enum Phase {
        /// Freshly begun; can prepare, commit, or roll back.
        case open
        /// A second transaction was begun on the gateway, invalidating this one.
        /// `commit()` drops it; `rollback()` rolls it back.
        case invalidated
        /// Committed cleanly or reconciled — terminal.
        case applied
        /// Dropped before mutation (cancellation, stale version, reentrant
        /// invalidation, or already closed) — terminal.
        case dropped
        /// Rolled back (explicit or validation failure) — terminal.
        case rolledBack
    }

    /// The owning gateway. Weak so a discarded transaction does not keep its
    /// gateway alive; the gateway is normally held by the caller for the
    /// transaction's lifetime.
    private weak var gateway: MonaTransactionGateway?

    // MARK: - Captured at begin time (version truth for divergence detection)

    /// The model's version id when this transaction began. The gateway compares
    /// it against the live `model.getVersionId()` at commit to detect direct
    /// mutation that bypassed the gateway.
    public let startVersionId: Int

    /// The model's alternative version id when this transaction began.
    public let startAlternativeVersionId: Int

    // MARK: - Prepared components (no model mutation)

    private(set) public var preparedOperations: [MonaModelEditOperation] = []
    private(set) public var preparedSelections: [MonaSelection] = []
    private(set) public var preparedUndoMetadata: MonaUndoMetadata = .empty
    /// An optional EOL change to push as part of the committed unit (`nil` =
    /// no EOL change prepared).
    private(set) public var preparedEOL: MonaEndOfLineSequence? = nil

    /// Whether reconcile is enabled for this transaction. When `true`, a
    /// version-divergent commit re-validates the prepared operations against
    /// the current model and reapplies them, returning `.reconciled`. When
    /// `false` (the default), version divergence drops the transaction.
    public var reconcileEnabled: Bool = false

    /// An optional cancellation token. If cancellation is requested before
    /// `commit()`, the gateway drops the transaction.
    public var cancellationToken: MonaCancellationToken = .none

    // MARK: - Phase

    fileprivate var phase: Phase = .open

    /// `true` once the transaction has reached a terminal phase (committed,
    /// dropped, or rolled back). An invalidated transaction is NOT closed —
    /// it can still be resolved by `commit()` or `rollback()`.
    public var isClosed: Bool {
        switch phase {
        case .open, .invalidated:
            return false
        case .applied, .dropped, .rolledBack:
            return true
        }
    }

    /// `true` if the transaction committed cleanly or was reconciled.
    public var isApplied: Bool { phase == .applied }

    /// `true` if the transaction was rolled back (explicitly or on validation
    /// failure).
    public var isRolledBack: Bool { phase == .rolledBack }

    /// `true` if the transaction was dropped before mutation.
    public var isDropped: Bool { phase == .dropped }

    // MARK: - Initialization (gateway-only)

    /// Creates a transaction capturing the model's version at begin time.
    /// `internal` so only `MonaTransactionGateway.beginTransaction()` can
    /// construct one.
    internal init(
        gateway: MonaTransactionGateway,
        startVersionId: Int,
        startAlternativeVersionId: Int
    ) {
        self.gateway = gateway
        self.startVersionId = startVersionId
        self.startAlternativeVersionId = startAlternativeVersionId
    }

    // MARK: - Prepare (NO model mutation)

    /// Queues a single edit operation. No-op once the transaction is closed or
    /// invalidated.
    public func prepareEdit(_ op: MonaModelEditOperation) {
        guard phase == .open else { return }
        preparedOperations.append(op)
    }

    /// Queues a batch of edit operations. No-op once closed or invalidated.
    public func prepareEdits(_ ops: [MonaModelEditOperation]) {
        guard phase == .open else { return }
        preparedOperations.append(contentsOf: ops)
    }

    /// Queues the cursor-state selections to commit as part of the unit. No-op
    /// once closed or invalidated.
    public func prepareSelections(_ selections: [MonaSelection]) {
        guard phase == .open else { return }
        preparedSelections = selections
    }

    /// Queues undo metadata to commit as part of the unit. No-op once closed or
    /// invalidated.
    public func prepareUndoMetadata(_ metadata: MonaUndoMetadata) {
        guard phase == .open else { return }
        preparedUndoMetadata = metadata
    }

    /// Queues an EOL change to push as part of the committed unit. No-op once
    /// closed or invalidated.
    public func prepareEOL(_ eol: MonaEndOfLineSequence) {
        guard phase == .open else { return }
        preparedEOL = eol
    }

    /// Enables or disables the reconcile path for version-divergent commits.
    /// Safe to set any time before `commit()`.
    public func setReconcileEnabled(_ enabled: Bool) {
        reconcileEnabled = enabled
    }

    /// Attaches a cancellation token. If `isCancellationRequested` is `true`
    /// at `commit()`, the gateway drops the transaction.
    public func setCancellationToken(_ token: MonaCancellationToken) {
        cancellationToken = token
    }

    // MARK: - Resolve (delegates to the owning gateway)

    /// Commits every prepared component as one ordered unit through the owning
    /// gateway. Returns the typed outcome.
    @discardableResult
    public func commit() -> MonaReconciliationOutcome {
        guard let gateway = gateway else {
            // The gateway was released. Treat as a closed transaction.
            return .dropped(reason: MonaTransactionReason.transactionClosed)
        }
        return gateway.commit(self)
    }

    /// Reverts every prepared component, leaving the model untouched. Returns
    /// `.rolledBack`. No-op (returns the prior terminal outcome's reason) if
    /// the transaction is already terminal.
    @discardableResult
    public func rollback() -> MonaReconciliationOutcome {
        guard let gateway = gateway else {
            return .rolledBack(reason: MonaTransactionReason.transactionClosed)
        }
        return gateway.rollback(self)
    }

    // MARK: - Phase transitions (gateway-only)

    /// Marks the transaction invalidated by a reentrant `beginTransaction()`.
    /// The transaction is no longer the gateway's active one; `commit()` will
    /// drop it and `rollback()` will roll it back. No-op if already terminal.
    internal func markInvalidated() {
        guard phase == .open else { return }
        phase = .invalidated
    }

    /// Marks the transaction cleanly committed (or reconciled). Gateway-only.
    internal func markApplied() {
        phase = .applied
    }

    /// Marks the transaction dropped before mutation. Gateway-only.
    internal func markDropped() {
        switch phase {
        case .open, .invalidated:
            phase = .dropped
        case .applied, .dropped, .rolledBack:
            // Already terminal; leave as-is.
            break
        }
    }

    /// Marks the transaction rolled back. Gateway-only.
    internal func markRolledBack() {
        switch phase {
        case .open, .invalidated:
            phase = .rolledBack
        case .applied, .dropped, .rolledBack:
            break
        }
    }
}
