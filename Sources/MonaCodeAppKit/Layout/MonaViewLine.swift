// MonaViewLine.swift
//
// P03-T001 — Build ViewGraph projection and logarithmic vertical indexes.
//
// `MonaViewLine` is the immutable view-line identity — the Swift counterpart of
// Monaco's `ViewLine` (monaco-editor 0.56.0). A view line is the projection of
// one model line (or a wrapped piece of one) into the visual coordinate space.
// It carries:
//   - `modelLineNumber`  — the 1-based model line this view line derives from.
//   - `startColumn`       — the 1-based UTF-16 column where this view line
//                           begins inside the model line (1 for a non-wrapped
//                           line or the first piece; advanced for continuations).
//   - `isWrapped`         — `true` when this is a wrapped continuation (not the
//                           first piece of its model line).
//   - `injectionIds`      — identifiers of injected-text spans attached to
//                           this view line (empty when none).
//   - `isCollapsed`       — `true` when this view line stands in for a folded
//                           (collapsed) model-line range.
//   - `isVisible`         — `false` when the underlying model line is hidden
//                           (hidden lines are excluded from the projection, so
//                           this is always `true` for lines present in the
//                           projection; kept for identity completeness).
//
// `MonaViewLine` is a value type: `Equatable` and `Hashable` with value
// semantics. Two view lines with equal fields are equal regardless of
// construction path.
//
// MonaCodeAppKit may import AppKit and CoreGraphics; this file keeps imports
// minimal (Foundation only — the identity carries no graphics types).

import Foundation

/// The immutable identity of a single projected view line.
///
/// A `MonaViewLine` is produced by `MonaViewGraph` when it projects model lines
/// into the view coordinate space. It does NOT carry shaped glyph data or pixel
/// geometry — only the identity needed to map between model and view
/// coordinates and to key layout records. Pixel heights live in
/// `MonaVerticalIndex`.
public struct MonaViewLine: Equatable, Hashable {

    /// The 1-based model line number this view line derives from.
    public let modelLineNumber: Int

    /// The 1-based UTF-16 column where this view line begins inside the model
    /// line. `1` for a non-wrapped line or the first piece of a wrapped line;
    /// advanced past the previous break for wrapped continuations.
    public let startColumn: Int

    /// `true` when this view line is a wrapped continuation (not the first
    /// piece of its model line).
    public let isWrapped: Bool

    /// Identifiers of injected-text spans attached to this view line. Empty
    /// when the view line carries no injections.
    public let injectionIds: [String]

    /// `true` when this view line stands in for a folded (collapsed)
    /// model-line range.
    public let isCollapsed: Bool

    /// `true` when the underlying model line is visible. Lines present in a
    /// projection are always visible (hidden lines are excluded); this field
    /// is kept for identity completeness and downstream consumers.
    public let isVisible: Bool

    /// Creates a view-line identity.
    public init(
        modelLineNumber: Int,
        startColumn: Int = 1,
        isWrapped: Bool = false,
        injectionIds: [String] = [],
        isCollapsed: Bool = false,
        isVisible: Bool = true
    ) {
        self.modelLineNumber = modelLineNumber
        self.startColumn = startColumn
        self.isWrapped = isWrapped
        self.injectionIds = injectionIds
        self.isCollapsed = isCollapsed
        self.isVisible = isVisible
    }
}
