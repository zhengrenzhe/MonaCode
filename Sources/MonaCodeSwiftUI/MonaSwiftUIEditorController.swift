// MonaSwiftUIEditorController.swift
//
// P04-T015 — Deliver MonaCodeEditor and MonaSwiftUIEditorController lifecycle wrappers.
//
// `MonaSwiftUIEditorController` is the explicit controller that owns the model +
// the view attachment with STABLE IDENTITY across SwiftUI body re-evaluations.
// SwiftUI re-renders (which create new `MonaCodeEditor` struct instances) map
// INTO this controller; they must NEVER recreate the editor or reset the model.
//
// The controller is the single owner:
//   - It owns the model STRONGLY (the external owner P04-T014 refers to: "the
//     model is created/owned OUTSIDE the view"). The view borrows it weakly via
//     `MonaEditorAttachment` (P04-T014), so model lifetime is independent from
//     view attachment: detaching the view never disposes the model.
//   - It owns the `MonaCodeEditorView` it creates in `makeEditorView(frame:)`.
//     The view is created ONCE; subsequent calls reuse the SAME instance.
//
// `updateNSView` (in `MonaCodeEditor`) maps SwiftUI declared state into the
// controller via `applyDeclaredChanges(...)`, which applies ONLY declared
// option/model/focus changes — never re-running text semantics, rendering,
// input, or provider logic (those live in the AppKit view + Core).
//
// `@MainActor` isolation matches P04-T014's convention: the model is non-Sendable
// and the AppKit view is main-actor-isolated, so the controller is main-actor to
// keep both on the main thread (the AppKit contract).

import AppKit
import MonaCode
import MonaCodeAppKit

// MARK: - MonaSwiftUIEditorController

/// The explicit controller that owns the model + the `MonaCodeEditorView`
/// attachment with STABLE IDENTITY across SwiftUI body re-evaluations.
///
/// SwiftUI re-renders create new `MonaCodeEditor` struct instances, but those
/// structs hold a REFERENCE to this controller — so the controller (and the
/// view + model it owns) persists. SwiftUI maps into the controller; it never
/// recreates the editor or resets the model.
///
/// The controller is the single owner of the model (strong). The view borrows
/// the model weakly via `MonaEditorAttachment` (P04-T014), so model lifetime is
/// independent from view attachment — detaching the view never disposes the
/// model.
@MainActor
public final class MonaSwiftUIEditorController {

    // MARK: - Stable identity

    /// A token that is stable for the controller's entire lifetime. SwiftUI
    /// body re-evaluations never change it. Used by the lifecycle tests to
    /// assert that a re-render maps into the SAME controller (not a new one).
    public let identityToken: UUID = UUID()

    // MARK: - Single-owned state

    /// The model the controller owns (strong — single owner). The view borrows
    /// it weakly via `MonaEditorAttachment`, so detaching the view never
    /// disposes the model. Lifetime is independent from view attachment.
    public private(set) var model: MonaCodeModel

    /// The `MonaCodeEditorView` the controller created in `makeEditorView`.
    /// `nil` until `makeEditorView(frame:)` is first called. Created ONCE;
    /// subsequent calls reuse the SAME instance (stable identity).
    public private(set) var editorView: MonaCodeEditorView?

    /// The declared-options snapshot last applied via `applyDeclaredChanges`.
    /// Recorded only — the wrapper does NOT execute rendering/input/provider
    /// logic to apply options; the AppKit view reads declared state when it
    /// next renders. This keeps semantics/rendering OUTSIDE the wrapper.
    public private(set) var declaredOptions: MonaCodeEditorOptions = .defaults

    /// The declared focus request last applied via `applyDeclaredChanges`.
    /// Recorded only — focus application is delegated to the AppKit view's
    /// accessibility surface (P04-T012); the wrapper runs no focus logic.
    public private(set) var declaredFocusRequest: MonaCodeEditorFocusRequest = .none

    // MARK: - Init

    /// Creates a controller owning `model` (strong — the single owner). The
    /// view borrows the model weakly when attached.
    public init(model: MonaCodeModel) {
        self.model = model
    }

    // MARK: - makeNSView equivalent

    /// Creates the `MonaCodeEditorView` ONCE and attaches the owned model.
    ///
    /// Idempotent: a no-op returning the existing view when called again —
    /// SwiftUI body re-evaluations must NOT recreate the editor. The view
    /// borrows the model weakly via `MonaEditorAttachment` (P04-T014), so the
    /// model's lifetime is independent from the view.
    public func makeEditorView(frame: NSRect) -> MonaCodeEditorView {
        if let existing = editorView {
            // Stable identity: reuse the SAME view instance across re-renders.
            return existing
        }
        let view = MonaCodeEditorView(frame: frame)
        // Attach the owned model. The view borrows it weakly — the controller
        // (not the view) owns the model's lifetime.
        view.attach(model: model)
        editorView = view
        return view
    }

    // MARK: - updateNSView equivalent

    /// Applies declared option/model/focus changes to the existing view ONLY.
    ///
    /// This is the entire `updateNSView` mapping — it does NOT re-run text
    /// semantics, rendering, input, or provider logic:
    ///
    ///   - Declared MODEL change: if `declaredModel` differs from the owned
    ///     model, the controller adopts it (strong ref) and re-attaches to the
    ///     view IN PLACE (the view instance is reused, not recreated). The
    ///     prior model is never disposed — its lifetime is independent.
    ///   - Declared MODEL unchanged: a no-op for the attachment — re-attaching
    ///     would re-run `performAttach` (semantics), so the wrapper must NOT.
    ///   - Declared OPTIONS / FOCUS: recorded as a snapshot only; the wrapper
    ///     executes no rendering/input/provider logic to apply them.
    public func applyDeclaredChanges(
        model declaredModel: MonaCodeModel,
        options: MonaCodeEditorOptions,
        focusRequest: MonaCodeEditorFocusRequest
    ) {
        // Record the declared snapshot (no execution — delegates to the view).
        self.declaredOptions = options
        self.declaredFocusRequest = focusRequest

        // Model change path ONLY. When the declared model is the SAME instance
        // as the owned model, do NOT re-attach: re-attaching would re-run
        // `performAttach` (text semantics). The wrapper maps model CHANGES
        // only, never a no-op re-attach.
        guard declaredModel !== model else {
            return
        }

        // Adopt the new model (single owner — strong ref). The prior model is
        // released here (its lifetime was independent: the external owner or
        // this controller kept it alive; the view never owned it).
        self.model = declaredModel

        // Re-attach IN PLACE: the view instance is reused, not recreated.
        // `MonaCodeEditorView.attach(model:)` detaches the prior model first
        // (idempotent) and attaches the new one via `MonaEditorAttachment`.
        editorView?.attach(model: declaredModel)
    }
}
