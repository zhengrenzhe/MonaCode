// MonaEditorAttachment.swift
//
// P04-T014 — Deliver MonaCodeEditorView as the AppKit editor boundary.
//
// `MonaEditorAttachment` is the attachment helper that attaches/detaches a
// `MonaCodeModel` to/from a `MonaCodeEditorView`. It is the single owner of the
// three P04-T014 lifetime invariants:
//
//   1. Model lifetime is independent from view attachment — the model is
//      created/owned OUTSIDE the view. The attachment holds a WEAK (borrow)
//      reference to the model: attaching does NOT create or retain-own the
//      model, and detaching does NOT destroy it (the attachment never calls
//      `model.dispose()`). A model survives view disposal.
//
//   2. All callbacks are detached before disposal — every observer/emitter
//      subscription the view registers on the model (`onDidChangeContent`,
//      `onWillDispose`, …) is stored as a `MonaDisposable` here and disposed in
//      `detach()`/`deinit` BEFORE the view tears down its collaborators. No
//      retained closures leak: every listener closure is a `@Sendable`
//      (non-isolated) closure that bridges back to the main actor via
//      `MainActor.assumeIsolated` (the model is always mutated on the main
//      thread in an AppKit editor, so the synchronous emitter callback runs on
//      the main thread), so no retain cycle forms and disposing the disposable
//      removes the listener from the model's emitter.
//
//   3. Only the contract-owned surface leaks — `MonaEditorAttachment` is one of
//      the two new public types; the view's internal gateway collaborators stay
//      `internal`.
//
// `@MainActor` isolation: the attachment is main-actor-isolated (matching the
// `NSView` it attaches to) so the non-Sendable `MonaCodeModel` never crosses an
// actor boundary — the model is created/owned outside the view but is always
// attached and mutated on the main thread (the AppKit contract). The emitter
// subscription closures are `@Sendable` so they match the non-isolated closure
// type `MonaEvent` expects; each hops to the main actor via
// `MainActor.assumeIsolated` before touching any main-actor state.
//
// The attachment delegates the creation/teardown of model-dependent subsystems
// (projection, geometry barrier, input barrier, AX graph, …) to the view's
// `performAttach(model:)` / `performDetach()` hooks, so the attachment owns the
// LIFETIME invariants and the view owns the COMPOSITION.
//
// `MonaEmitter` (the base-layer event emitter) has idempotent disposal —
// `dispose()` is a no-op when called again — so disposing a disposable twice
// (e.g. detach then deinit) is safe; this file reuses that guarantee rather than
// re-tracking disposal state.

import Foundation
import MonaCode

// MARK: - MonaEditorAttachment

/// The attachment helper that attaches/detaches a `MonaCodeModel` to/from a
/// `MonaCodeEditorView`, enforcing the P04-T014 lifetime invariants:
///
///   - the model is held weakly (borrow) — the view never owns its lifetime;
///   - every model-event subscription is disposed in `detach()`/`deinit` before
///     the view tears down;
///   - the model is never disposed by attach/detach — a model survives view
///     disposal.
///
/// The attachment delegates creation/teardown of model-dependent subsystems to
/// the view's `performAttach(model:)` / `performDetach()` hooks.
@MainActor
public final class MonaEditorAttachment {

    // MARK: - Backing references

    /// The view the attachment attaches models to. Held weakly: the view owns
    /// the attachment (`let attachment: MonaEditorAttachment`), so a strong ref
    /// here would form a retain cycle. During the view's `deinit` the weak ref
    /// may already read as `nil` — `detach()` tolerates that (disposing the
    /// disposables is the load-bearing step and needs no view ref).
    private weak var view: MonaCodeEditorView?

    /// The attached model. Held WEAKLY (borrow): the model is created/owned
    /// outside the view. Attaching does NOT create or retain-own the model;
    /// detaching does NOT destroy it. The attachment never calls
    /// `model.dispose()`.
    private weak var model: MonaCodeModel?

    // MARK: - Subscriptions

    /// Every observer/emitter subscription registered on the model while
    /// attached. Disposed in `detach()` BEFORE the view tears down its
    /// collaborators. `MonaDisposable.dispose()` is idempotent (the base-layer
    /// `MonaDisposableImpl` runs its action at most once), so disposing twice
    /// (detach then deinit) is safe.
    private var disposables: [MonaDisposable] = []

    /// `true` while a model is attached.
    private var attached: Bool = false

    // MARK: - Init

    /// Creates an attachment for `view`.
    public init(view: MonaCodeEditorView) {
        self.view = view
    }

    // MARK: - Contract surface

    /// The attached model (a weak/borrow read), or `nil` when detached. The
    /// view never owns this model's lifetime.
    public var attachedModel: MonaCodeModel? {
        return model
    }

    /// `true` while a model is attached to the view.
    public var isAttached: Bool {
        return attached
    }

    // MARK: - Attach

    /// Attaches `model` to the view.
    ///
    /// Detaches any prior model first (idempotent). The attachment holds a WEAK
    /// (borrow) reference to `model` — it never creates, owns, or retains-owns
    /// the model, and never disposes it. The view's model-dependent subsystems
    /// (projection, geometry barrier, input barrier, AX graph, …) are created
    /// via the view's `performAttach(model:)` hook, and every model-event
    /// subscription is stored here as a disposable so `detach()` can remove it.
    public func attach(model: MonaCodeModel) {
        // Detach any prior model first (idempotent — a no-op when not attached).
        detach()

        self.model = model
        self.attached = true

        // Create the model-dependent subsystems in the view.
        view?.performAttach(model: model)

        // Subscribe to model events. Each closure is `@Sendable` (non-isolated)
        // to match the non-isolated closure type `MonaEvent` expects, and hops
        // back to the main actor via `MainActor.assumeIsolated` before touching
        // any main-actor state. The model is always mutated on the main thread
        // (the AppKit contract), so the synchronous emitter callback runs on the
        // main thread and `assumeIsolated` is safe.
        //
        // `[weak self]` captures this attachment (a `@MainActor` type, hence
        // Sendable) weakly — no retain cycle: view → attachment → disposables →
        // closure → (weak) attachment. Disposing the disposable removes the
        // listener from the model's emitter.

        let contentHandler: @Sendable (MonaModelContentChangeEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleContentChange()
            }
        }
        disposables.append(model.onDidChangeContent(contentHandler))

        let disposeHandler: @Sendable (MonaCodeModel) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                // When the model is disposed externally, auto-detach so the view
                // never observes a disposed model. The attachment does NOT
                // dispose the model here — it is already being disposed by its
                // external owner.
                self?.detach()
            }
        }
        disposables.append(model.onWillDispose(disposeHandler))
    }

    // MARK: - Detach

    /// Detaches the model and removes EVERY subscription the view registered on
    /// it, BEFORE the view tears down its model-dependent collaborators.
    ///
    /// Idempotent: a no-op when not attached. The model is NEVER disposed by
    /// detach — its lifetime is owned outside the view.
    public func detach() {
        guard attached else { return }

        // Detach ALL callbacks BEFORE disposal of the view's collaborators.
        // `MonaDisposable.dispose()` is idempotent, so a second detach (e.g.
        // from the view's deinit) is a safe no-op.
        for disposable in disposables {
            disposable.dispose()
        }
        disposables.removeAll()

        // Tear down the model-dependent collaborators (does NOT dispose the
        // model). Best-effort via the weak view ref: during the view's deinit
        // the weak ref may read as `nil`, in which case the collaborators are
        // released by the deinit anyway — disposing the disposables above is
        // the load-bearing step and needs no view ref.
        view?.performDetach()

        self.model = nil
        self.attached = false
    }

    // MARK: - Content-change handling (main-actor)

    /// Invoked (on the main actor) when the attached model fires a content-change
    /// event. Delegates to the view, which invalidates its projection.
    private func handleContentChange() {
        view?.observeContentChange()
    }

    // MARK: - Deinit

    // The attachment has no deinit of its own: its `disposables` array is
    // main-actor-isolated (non-Sendable), so it cannot be touched from a
    // non-isolated deinit. The authoritative teardown is `MonaCodeEditorView.deinit`,
    // which calls `detach()` → `attachment.detach()`, disposing every disposable
    // and tearing down the view's collaborators BEFORE the attachment (a stored
    // property of the view) is released. `detach()` is idempotent, so the view's
    // deinit is a safe, single disposal point.
}
