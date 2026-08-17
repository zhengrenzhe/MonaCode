// MonaUndoRedoStack.swift
//
// P02-T001 — Implement undo and redo elements on transaction truth.
//
// `MonaUndoRedoStack` manages the undo/redo LIFO lists and routes every replay
// mutation through the same `MonaTransactionGateway` as direct edits — the Swift
// counterpart of Monaco's `EditStack` (monaco-editor 0.56.0). Undo replays the
// element's `reverseOperations` (inverse edits, not old text roots); redo
// replays the element's forward `operations`. Both prepare the captured EOL
// change, selection recovery, and undo metadata on the transaction and commit
// through the gateway, so an undo/redo replay is observationally identical to a
// direct edit batch of the same shape (one version bump, one content-change
// event, recorded selections + undo metadata).
//
// When a replay transaction fails — the gateway drops it (cancellation, stale
// version, reentrant invalidation) or rolls it back (validation failure) — the
// stack rolls back its position: the element is restored to the stack it was
// popped from, so `canUndo` / `canRedo` reflect the pre-replay state. The model
// is left untouched (the gateway never mutated it).
//
// `push(_:)` populates the undo stack and clears the redo stack: once a new
// edit group is pushed, the previously undone groups are no longer redoable,
// matching Monaco's standard undo behavior.
//
// The stack does NOT own text or version truth — those live in the model (via
// the gateway). The stack owns the undo/redo LIFO truth: which elements are
// available to replay and in what order.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The typed result of an `undo()` / `redo()` replay through the transaction
/// gateway.
///
/// Branch on the case to learn whether the replay committed cleanly or was
/// rolled back / dropped by the gateway (in which case the stack restored the
/// element to its original position and the model is untouched).
public enum MonaUndoRedoReplayOutcome: Equatable {

    /// The replay committed cleanly (or was reconciled) through the gateway.
    /// The element moved from its source stack to the opposite stack.
    case replayed

    /// The replay transaction was dropped or rolled back by the gateway. The
    /// stack rolled back its position: the element was restored to the stack it
    /// was popped from. The model is untouched.
    ///
    /// `reason` is the gateway's reason string (e.g. `"validation failure"`,
    /// `"stale version"`, `"cancelled"`), or `"nothing to undo"` / `"nothing to
    /// redo"` when the source stack was empty.
    case replayFailed(reason: String)
}

/// Manages the undo/redo LIFO lists, routing every replay mutation through a
/// `MonaTransactionGateway`.
///
/// Create with `init(gateway:)`. Push committed edit groups with `push(_:)`;
/// replay them with `undo()` and `redo()`. The stack tracks `canUndo` /
/// `canRedo` and rolls back its position when a replay transaction fails.
public final class MonaUndoRedoStack {

    /// The gateway every undo/redo replay is routed through. The gateway owns
    /// the model's transactional mutation truth; the stack owns the undo/redo
    /// LIFO truth.
    public let gateway: MonaTransactionGateway

    /// The undo LIFO list. The top of the stack (last element) is the most
    /// recently pushed edit group and the next to be undone.
    private var undoStack: [MonaUndoRedoElement] = []

    /// The redo LIFO list. The top of the stack (last element) is the most
    /// recently undone edit group and the next to be redone.
    private var redoStack: [MonaUndoRedoElement] = []

    // MARK: - Initialization

    /// Creates a stack that routes every undo/redo replay through `gateway`.
    public init(gateway: MonaTransactionGateway) {
        self.gateway = gateway
    }

    // MARK: - State

    /// `true` when there is at least one element to undo.
    public var canUndo: Bool {
        return !undoStack.isEmpty
    }

    /// `true` when there is at least one element to redo.
    public var canRedo: Bool {
        return !redoStack.isEmpty
    }

    /// The number of elements on the undo stack.
    public var undoCount: Int {
        return undoStack.count
    }

    /// The number of elements on the redo stack.
    public var redoCount: Int {
        return redoStack.count
    }

    // MARK: - Push

    /// Pushes `element` onto the undo stack as the next undo target and clears
    /// the redo stack.
    ///
    /// A new edit group invalidates the previously undone groups: they are no
    /// longer redoable. This matches Monaco's standard undo behavior — `push*`
    /// on the edit stack always clears the future list.
    public func push(_ element: MonaUndoRedoElement) {
        undoStack.append(element)
        redoStack.removeAll()
    }

    /// Empties both the undo and redo stacks.
    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    // MARK: - Undo

    /// Replays the top of the undo stack in reverse through the transaction
    /// gateway. On a clean commit (or reconcile), the element moves to the redo
    /// stack. On a dropped or rolled-back transaction, the stack rolls back its
    /// position: the element is restored to the undo stack and the model is
    /// untouched.
    ///
    /// Returns `.replayFailed(reason: "nothing to undo")` when the undo stack
    /// is empty.
    @discardableResult
    public func undo() -> MonaUndoRedoReplayOutcome {
        guard let element = undoStack.popLast() else {
            return .replayFailed(reason: MonaUndoRedoReason.nothingToUndo)
        }

        let outcome = replay(element, direction: .undo)
        switch outcome {
        case .applied, .reconciled:
            // The replay committed cleanly: the element is now the next redo
            // target.
            redoStack.append(element)
            return .replayed
        case .dropped(let reason):
            // The gateway dropped the transaction before any mutation. Roll
            // back the stack position: restore the element to the undo stack.
            undoStack.append(element)
            return .replayFailed(reason: reason)
        case .rolledBack(let reason):
            // A prepared component failed validation, or the caller (via the
            // gateway) rolled the transaction back. Roll back the stack
            // position: restore the element to the undo stack.
            undoStack.append(element)
            return .replayFailed(reason: reason)
        }
    }

    // MARK: - Redo

    /// Replays the top of the redo stack forward through the transaction
    /// gateway. On a clean commit (or reconcile), the element moves to the undo
    /// stack. On a dropped or rolled-back transaction, the stack rolls back its
    /// position: the element is restored to the redo stack and the model is
    /// untouched.
    ///
    /// Returns `.replayFailed(reason: "nothing to redo")` when the redo stack
    /// is empty.
    @discardableResult
    public func redo() -> MonaUndoRedoReplayOutcome {
        guard let element = redoStack.popLast() else {
            return .replayFailed(reason: MonaUndoRedoReason.nothingToRedo)
        }

        let outcome = replay(element, direction: .redo)
        switch outcome {
        case .applied, .reconciled:
            // The replay committed cleanly: the element is now the next undo
            // target.
            undoStack.append(element)
            return .replayed
        case .dropped(let reason):
            redoStack.append(element)
            return .replayFailed(reason: reason)
        case .rolledBack(let reason):
            redoStack.append(element)
            return .replayFailed(reason: reason)
        }
    }

    // MARK: - Private: replay through the gateway

    /// The replay direction.
    private enum Direction {
        /// Undo: replay the reverse operations, reverse the EOL change, recover
        /// the before selections, commit with `isUndoing` metadata.
        case undo
        /// Redo: replay the forward operations, re-apply the EOL change, recover
        /// the after selections, commit with `isRedoing` metadata.
        case redo
    }

    /// Begins a transaction on the gateway, prepares the element's components in
    /// the given direction, and commits. Returns the gateway's typed outcome.
    ///
    /// The transaction is prepared WITHOUT mutating the model (per the gateway
    /// contract); the gateway applies the whole unit atomically on commit. The
    /// undo metadata records the replay direction so the committed unit is
    /// distinguishable from a direct edit.
    private func replay(
        _ element: MonaUndoRedoElement,
        direction: Direction
    ) -> MonaReconciliationOutcome {
        let tx = gateway.beginTransaction()

        switch direction {
        case .undo:
            // Replay the inverse edits. They were computed against the
            // post-edit model, so they are valid as-given when the model is in
            // the post-edit state.
            tx.prepareEdits(element.reverseOperations)
            // Reverse the EOL change: restore the before EOL.
            if let eol = element.eolChange {
                tx.prepareEOL(eol.before)
            }
            // Recover the pre-edit cursor state.
            tx.prepareSelections(element.beforeSelections)
            // Record the replay direction in the committed undo metadata.
            tx.prepareUndoMetadata(MonaUndoMetadata(
                label: element.label,
                isUndoing: true,
                isRedoing: false
            ))
        case .redo:
            // Replay the forward edits.
            tx.prepareEdits(element.operations)
            // Re-apply the EOL change: push the after EOL.
            if let eol = element.eolChange {
                tx.prepareEOL(eol.after)
            }
            // Recover the post-edit cursor state.
            tx.prepareSelections(element.afterSelections)
            // Record the replay direction in the committed undo metadata.
            tx.prepareUndoMetadata(MonaUndoMetadata(
                label: element.label,
                isUndoing: false,
                isRedoing: true
            ))
        }

        return tx.commit()
    }
}

// MARK: - Stable reason strings

/// Internal stable reason strings for empty-stack replay failures.
internal enum MonaUndoRedoReason {
    static let nothingToUndo = "nothing to undo"
    static let nothingToRedo = "nothing to redo"
}
