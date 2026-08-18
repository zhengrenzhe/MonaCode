// MonaDiffEditor.swift
//
// P07-T009 — Deliver diff and multi-diff views, SwiftUI wrappers, and
// sample-host activation.
//
// `MonaDiffEditor` is the SwiftUI→AppKit bridge: a `public struct
// MonaDiffEditor: NSViewRepresentable` that wraps `MonaDiffEditorView`
// (P07-T009). It is the public SwiftUI surface (`MonaCodeSwiftUI` product)
// that SwiftUI consumers use to embed the diff editor.
//
// It is a THIN, lifecycle-only bridge — all real logic stays in the AppKit
// view + Core (same invariants as P04-T015's `MonaCodeEditor`):
//   - `makeNSView(context:)` creates the `MonaDiffEditorView` ONCE via the
//     controller; SwiftUI re-renders never recreate the view.
//   - `updateNSView(_:context:)` propagates declared original/modified model
//     changes ONLY — it never re-runs diff semantics, rendering, input, or
//     provider logic. It delegates entirely to `MonaDiffEditorController` /
//     `MonaDiffEditorView` (P07-T009).
//
// Stable identity: the controller (`MonaDiffEditorController`) is the single
// owner of the models + view attachment. SwiftUI body re-evaluations create
// new `MonaDiffEditor` struct instances, but each holds a REFERENCE to the
// same controller — so the view + models persist. SwiftUI maps into the
// controller, not around it.
//
// Usage: the consumer holds the controller stably (e.g. via `@State`) and
// passes it to `MonaDiffEditor`:
//
//   @State private var controller = MonaDiffEditorController(
//       original: originalModel, modified: modifiedModel)
//   var body: some View {
//       MonaDiffEditor(controller: controller)
//   }
//
// `@MainActor` isolation matches P04-T015's convention (the AppKit view +
// models are main-actor-isolated). The controller owns the models strongly;
// the view borrows them weakly via the sub-editors' `MonaEditorAttachment`
// (P04-T014), so model lifetime is independent from view attachment.

import AppKit
import SwiftUI
import MonaCode
import MonaCodeAppKit

// MARK: - MonaDiffEditorController

/// The explicit controller that owns the original + modified models + the
/// `MonaDiffEditorView` attachment with STABLE IDENTITY across SwiftUI body
/// re-evaluations.
///
/// SwiftUI re-renders create new `MonaDiffEditor` struct instances, but those
/// structs hold a REFERENCE to this controller — so the controller (and the
/// view + models it owns) persists. SwiftUI maps into the controller; it never
/// recreates the diff view or resets the models.
///
/// The controller owns the models strongly (single owner). The diff view
/// borrows them weakly via the sub-editors' `MonaEditorAttachment` (P04-T014),
/// so model lifetime is independent from view attachment — detaching the view
/// never disposes the models.
@MainActor
public final class MonaDiffEditorController {

    // MARK: - Stable identity

    /// A token that is stable for the controller's entire lifetime. SwiftUI
    /// body re-evaluations never change it. Used by the lifecycle tests to
    /// assert that a re-render maps into the SAME controller (not a new one).
    public let identityToken: UUID = UUID()

    // MARK: - Single-owned state

    /// The original (left) model the controller owns (strong — single owner).
    /// The diff view borrows it weakly, so detaching the view never disposes
    /// the model. Lifetime is independent from view attachment.
    public private(set) var originalModel: MonaCodeModel

    /// The modified (right) model the controller owns (strong — single owner).
    public private(set) var modifiedModel: MonaCodeModel

    /// The `MonaDiffEditorView` the controller created in `makeDiffView`.
    /// `nil` until `makeDiffView(frame:)` is first called. Created ONCE;
    /// subsequent calls reuse the SAME instance (stable identity).
    public private(set) var diffView: MonaDiffEditorView?

    // MARK: - Init

    /// Creates a controller owning `original` + `modified` (strong — single
    /// owner). The diff view borrows them weakly when attached.
    public init(original: MonaCodeModel, modified: MonaCodeModel) {
        self.originalModel = original
        self.modifiedModel = modified
    }

    // MARK: - makeNSView equivalent

    /// Creates the `MonaDiffEditorView` ONCE and attaches the owned models.
    ///
    /// Idempotent: a no-op returning the existing view when called again —
    /// SwiftUI body re-evaluations must NOT recreate the diff view. The view
    /// borrows the models weakly (the controller owns their lifetime).
    public func makeDiffView(frame: NSRect) -> MonaDiffEditorView {
        if let existing = diffView {
            // Stable identity: reuse the SAME view instance across re-renders.
            return existing
        }
        let view = MonaDiffEditorView(frame: frame)
        // Attach the owned models. The view borrows them weakly — the
        // controller (not the view) owns the models' lifetime.
        view.attach(original: originalModel, modified: modifiedModel)
        diffView = view
        return view
    }

    // MARK: - updateNSView equivalent

    /// Applies declared original/modified model changes to the existing view
    /// ONLY. This is the entire `updateNSView` mapping — it does NOT re-run
    /// diff semantics, rendering, input, or provider logic.
    ///
    /// When the declared models are the SAME instances as the owned models, no
    /// re-attach occurs (re-attaching would re-run the sub-editors' semantics).
    /// A declared MODEL change re-attaches IN PLACE: the view instance is
    /// reused, not recreated. The prior models are never disposed — their
    /// lifetime is independent.
    public func applyDeclaredChanges(original: MonaCodeModel, modified: MonaCodeModel) {
        // No-op re-render (same models): do NOT re-attach — re-attaching would
        // re-run the sub-editors' `performAttach` (text semantics).
        guard original !== originalModel || modified !== modifiedModel else {
            return
        }

        // Adopt the new models (single owner — strong ref). The prior models
        // are released here (their lifetime was independent: the controller
        // kept them alive; the view never owned them).
        self.originalModel = original
        self.modifiedModel = modified

        // Re-attach IN PLACE: the view instance is reused, not recreated.
        // `MonaDiffEditorView.attach(original:modified:)` detaches the prior
        // models first (idempotent) and attaches the new ones.
        diffView?.attach(original: original, modified: modified)
    }
}

// MARK: - MonaDiffEditor (SwiftUI → AppKit bridge)

/// The SwiftUI→AppKit bridge wrapping `MonaDiffEditorView` (P07-T009).
///
/// `makeNSView(context:)` creates the AppKit view ONCE via the controller;
/// `updateNSView(_:context:)` propagates declared original/modified model
/// changes ONLY — never re-running diff semantics, rendering, input, or
/// provider logic.
///
/// The controller (`MonaDiffEditorController`) is the single owner of the
/// models + view attachment with stable identity across SwiftUI body
/// re-evaluations. SwiftUI maps into the controller, not around it.
public struct MonaDiffEditor: NSViewRepresentable {

    // MARK: - Declared state

    /// The controller that owns the models + view attachment (stable identity).
    public let controller: MonaDiffEditorController

    // MARK: - Init

    /// Creates the SwiftUI diff editor bridge.
    ///
    /// - Parameters:
    ///   - controller: The controller owning the models + view attachment. The
    ///     consumer must hold this stably (e.g. via `@State`) so SwiftUI body
    ///     re-evaluations map into the SAME controller — never recreate it.
    public init(controller: MonaDiffEditorController) {
        self.controller = controller
    }

    // MARK: - NSViewRepresentable

    /// Creates the `MonaDiffEditorView` ONCE via the controller. SwiftUI calls
    /// this once per view identity; subsequent body re-evaluations call only
    /// `updateNSView`, which reuses the SAME view instance.
    public func makeNSView(context: Context) -> MonaDiffEditorView {
        return controller.makeDiffView(frame: .zero)
    }

    /// Propagates declared original/modified model changes ONLY. Delegates
    /// entirely to the controller, which applies model changes (re-attach in
    /// place) — it never re-runs diff semantics, rendering, input, or
    /// provider logic.
    public func updateNSView(_ nsView: MonaDiffEditorView, context: Context) {
        controller.applyDeclaredChanges(
            original: controller.originalModel,
            modified: controller.modifiedModel
        )
    }
}
