// MonaDiffEditorView.swift
//
// P07-T009 — Deliver diff and multi-diff views, SwiftUI wrappers, and
// sample-host activation.
//
// `MonaDiffEditorView` is the native `NSView` that composes TWO
// `MonaCodeEditorView`s (original + modified) over shared models, driven by
// ONE `MonaDiffCoordinator` (P07-T002). It is the slot P05-T012 preserved
// (the empty declaration slot in `MonaEditorInstanceAdapters.swift` is
// superseded by this file — see the fix-forward note there).
//
// Composition (the first implementation operation):
//   - originalEditor — a `MonaCodeEditorView` (P04-T014) attached to the
//                      original (left) model (weak/borrow — lifetime
//                      independent from the diff view).
//   - modifiedEditor — a `MonaCodeEditorView` (P04-T014) attached to the
//                      modified (right) model (weak/borrow).
//   - coordinator     — ONE `MonaDiffCoordinator` (P07-T002) shared across
//                      both editors (the single diff-coordination surface).
//
// Lifetime invariants (carried forward from P04-T014/T015):
//   1. Model lifetime is independent from diff-view attachment — the diff
//      view borrows each model weakly via the sub-editor's
//      `MonaEditorAttachment`; attach/detach never disposes either model.
//   2. All callbacks are detached before disposal — `detach()` detaches both
//      sub-editors (idempotent), removing every subscription before teardown.
//
// MonaCodeAppKit imports AppKit + Foundation + MonaCode (for the coordinator +
// model types), matching P04-T014's import pattern.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaDiffEditorView

/// The native diff editor view: composes two `MonaCodeEditorView`s (original +
/// modified) over shared models, driven by ONE `MonaDiffCoordinator`
/// (P07-T002).
///
/// Attach the original + modified models via `attach(original:modified:)`; the
/// view attaches them to the two sub-editors (weak/borrow — lifetime
/// independent). Detach via `detach()` (idempotent; never disposes the models).
public final class MonaDiffEditorView: NSView {

    // MARK: - Composed sub-editors + coordinator

    /// The original (left) editor. A `MonaCodeEditorView` (P04-T014) that
    /// borrows the original model weakly via its `MonaEditorAttachment`.
    public let originalEditor: MonaCodeEditorView

    /// The modified (right) editor. A `MonaCodeEditorView` (P04-T014) that
    /// borrows the modified model weakly via its `MonaEditorAttachment`.
    public let modifiedEditor: MonaCodeEditorView

    /// The single shared diff coordinator (P07-T002) driving both editors.
    public let coordinator: MonaDiffCoordinator

    // MARK: - Init

    /// Creates the diff editor view with `frame`. Composes two fresh
    /// `MonaCodeEditorView` sub-editors (sized by auto-layout) and one
    /// `MonaDiffCoordinator` (with the default wall clock + diff engines).
    public override init(frame: NSRect) {
        originalEditor = MonaCodeEditorView(frame: .zero)
        modifiedEditor = MonaCodeEditorView(frame: .zero)
        coordinator = MonaDiffCoordinator(clock: MonaWallClock())
        super.init(frame: frame)
        commonInit()
    }

    /// Creates the diff editor view from a decoder. Composes two fresh
    /// `MonaCodeEditorView` sub-editors (programmatic, not decoded) and one
    /// `MonaDiffCoordinator`.
    public required init?(coder: NSCoder) {
        originalEditor = MonaCodeEditorView(frame: .zero)
        modifiedEditor = MonaCodeEditorView(frame: .zero)
        coordinator = MonaDiffCoordinator(clock: MonaWallClock())
        super.init(coder: coder)
        commonInit()
    }

    /// Shared setup: adds both sub-editors as subviews (original on the left,
    /// modified on the right) and lays them out side by side.
    private func commonInit() {
        originalEditor.translatesAutoresizingMaskIntoConstraints = false
        modifiedEditor.translatesAutoresizingMaskIntoConstraints = false
        addSubview(originalEditor)
        addSubview(modifiedEditor)
        // Side-by-side layout: original left half, modified right half.
        NSLayoutConstraint.activate([
            originalEditor.leadingAnchor.constraint(equalTo: leadingAnchor),
            originalEditor.topAnchor.constraint(equalTo: topAnchor),
            originalEditor.bottomAnchor.constraint(equalTo: bottomAnchor),
            originalEditor.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),

            modifiedEditor.leadingAnchor.constraint(equalTo: originalEditor.trailingAnchor),
            modifiedEditor.topAnchor.constraint(equalTo: topAnchor),
            modifiedEditor.bottomAnchor.constraint(equalTo: bottomAnchor),
            modifiedEditor.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: - Contract surface

    /// `true` while BOTH sub-editors have a model attached.
    public var isAttached: Bool {
        return originalEditor.isAttached && modifiedEditor.isAttached
    }

    /// Attaches `original` to the original editor and `modified` to the
    /// modified editor. Both models are borrowed weakly via each sub-editor's
    /// `MonaEditorAttachment` — the diff view never owns either model's
    /// lifetime. Detaches any prior models first (idempotent).
    public func attach(original: MonaCodeModel, modified: MonaCodeModel) {
        originalEditor.attach(model: original)
        modifiedEditor.attach(model: modified)
    }

    /// Detaches both sub-editors (idempotent). Every subscription is removed
    /// BEFORE teardown. Neither model is disposed — lifetime is independent.
    public func detach() {
        originalEditor.detach()
        modifiedEditor.detach()
    }

    // MARK: - Deinit (safety net)

    deinit {
        // Detach every subscription before teardown. `detach()` is idempotent
        // (a no-op when not attached). The models are NEVER disposed here.
        detach()
    }
}
