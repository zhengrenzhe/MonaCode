// MonaUndoRedoElement.swift
//
// P02-T001 — Implement undo and redo elements on transaction truth.
//
// `MonaUndoRedoElement` is the immutable snapshot of one edit group — the Swift
// counterpart of Monaco's `EditStackElement` (monaco-editor 0.56.0). Each
// element captures everything the undo/redo stack needs to replay the group
// forward (redo) or in reverse (undo) through the same transaction gateway as
// direct edits:
//
//   - `operations`            — the forward (redo) edit operations.
//   - `reverseOperations`     — the inverse (undo) edit operations. Monaco
//                               stores inverse edits (NOT old text roots — root
//                               retention would keep deleted large text alive).
//   - `beforeVersionId` /
//     `afterVersionId`        — the version ids bracketing the edit group.
//   - `beforeAlternativeVersionId` /
//     `afterAlternativeVersionId` — the alternative-version transition recorded
//                               for undo/redo tracking. EOL / setValue /
//                               undo / redo each have their own alternative-version
//                               restore rules; the element records the transition
//                               rather than collapsing it into one "transaction
//                               number".
//   - `eolChange`             — an optional EOL transition captured when the edit
//                               group includes a `pushEOL`. `nil` when the group
//                               did not change the EOL sequence.
//   - `beforeSelections` /
//     `afterSelections`        — the cursor state before and after the edit group,
//                               for selection recovery on undo/redo.
//   - `label`                 — the human-readable undo-stack label.
//
// The element is an immutable value type: every property is a `let`. It is the
// stack's record of one committed edit group, not a handle on live model state.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An EOL transition captured by a `MonaUndoRedoElement` when the edit group
/// includes a `pushEOL`.
///
/// `before` is the EOL sequence in effect before the group; `after` is the EOL
/// sequence the group pushed. Undo reverses the transition (applies `before`);
/// redo re-applies it (applies `after`).
public struct MonaUndoRedoEOLChange: Equatable {

    /// The EOL sequence before the edit group.
    public let before: MonaEndOfLineSequence

    /// The EOL sequence the edit group pushed.
    public let after: MonaEndOfLineSequence

    /// Creates an EOL transition.
    public init(before: MonaEndOfLineSequence, after: MonaEndOfLineSequence) {
        self.before = before
        self.after = after
    }
}

/// An immutable snapshot of one edit group for the undo/redo stack.
///
/// Create with the forward + reverse operations, the version ids bracketing the
/// group, the alternative-version transition, an optional EOL change, and the
/// before/after cursor selections. Push the element onto a `MonaUndoRedoStack`
/// to make it the undo target.
///
/// The element stores inverse edits (`reverseOperations`) rather than old text
/// roots: root retention would keep deleted large text alive beyond the undo
/// point. The inverse edits are sufficient to revert the model to its pre-edit
/// state when replayed through the transaction gateway.
public struct MonaUndoRedoElement: Equatable {

    /// The human-readable undo-stack label.
    public let label: String

    /// The forward (redo) edit operations. Replayed by `MonaUndoRedoStack.redo()`.
    public let operations: [MonaModelEditOperation]

    /// The inverse (undo) edit operations. Replayed by `MonaUndoRedoStack.undo()`.
    /// Inverse edits, not old text roots — root retention would keep deleted
    /// large text alive beyond the undo point.
    public let reverseOperations: [MonaModelEditOperation]

    /// The model's version id before the edit group.
    public let beforeVersionId: Int

    /// The model's version id after the edit group.
    public let afterVersionId: Int

    /// The model's alternative version id before the edit group. The alternative
    /// version is the pre-edit version tracked for undo/redo; EOL / setValue /
    /// undo / redo each have their own alternative-version restore rules, which
    /// the element records rather than collapsing into one "transaction number".
    public let beforeAlternativeVersionId: Int

    /// The model's alternative version id after the edit group.
    public let afterAlternativeVersionId: Int

    /// The EOL transition captured when the edit group includes a `pushEOL`,
    /// or `nil` when the group did not change the EOL sequence.
    public let eolChange: MonaUndoRedoEOLChange?

    /// The cursor selections before the edit group, for undo selection recovery.
    public let beforeSelections: [MonaSelection]

    /// The cursor selections after the edit group, for redo selection recovery.
    public let afterSelections: [MonaSelection]

    /// Creates an immutable undo/redo element capturing one edit group.
    ///
    /// `label` defaults to `""`, `eolChange` to `nil`, and the selections to
    /// empty arrays, so an element for a text-only group can omit them.
    public init(
        label: String = "",
        operations: [MonaModelEditOperation],
        reverseOperations: [MonaModelEditOperation],
        beforeVersionId: Int,
        afterVersionId: Int,
        beforeAlternativeVersionId: Int,
        afterAlternativeVersionId: Int,
        eolChange: MonaUndoRedoEOLChange? = nil,
        beforeSelections: [MonaSelection] = [],
        afterSelections: [MonaSelection] = []
    ) {
        self.label = label
        self.operations = operations
        self.reverseOperations = reverseOperations
        self.beforeVersionId = beforeVersionId
        self.afterVersionId = afterVersionId
        self.beforeAlternativeVersionId = beforeAlternativeVersionId
        self.afterAlternativeVersionId = afterAlternativeVersionId
        self.eolChange = eolChange
        self.beforeSelections = beforeSelections
        self.afterSelections = afterSelections
    }
}
