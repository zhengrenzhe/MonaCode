// MonaCodeEditorViewLifecycleTests.swift
//
// P04-T014 — Deliver MonaCodeEditorView as the AppKit editor boundary.
//
// Verifies the lifetime invariants of `MonaCodeEditorView` — the native
// `NSView` that composes model attachment, projection, the renderer branch,
// input, transfer, accessibility, widgets, and lifetime ownership into one
// editor boundary.
//
// The three load-bearing invariants (each with a test):
//
//   1. Composition — the view composes every Phase 03-04 subsystem into one
//      native view (model attachment, projection, renderer branch, input,
//      transfer, accessibility, widgets, lifetime ownership).
//
//   2. Model lifetime is independent from view attachment — the model is
//      created/owned OUTSIDE the view. Attaching a model does NOT create or
//      retain-own it; detaching does NOT destroy it. The view holds a weak
//      (borrow) reference. A model must survive view disposal.
//
//   3. All callbacks are detached before disposal — every observer/emitter
//      subscription the view registered on the model is detached in
//      `detach()`/`deinit` BEFORE the view is torn down. No retained closures
//      leak.
//
// Test contract (P04-T014): 1 case (lifecycle), 2 red-scaffold rows.

import XCTest
import AppKit
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

@MainActor
final class MonaCodeEditorViewLifecycleTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a model with a small multi-line document for the lifecycle tests.
    private func makeModel(_ text: String = "abc\ndef\nghi") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/editor-view-lifecycle")
        )
    }

    // MARK: - Invariant 2: Model lifetime independent from view attachment

    /// A model attached to a view survives the view's disposal. The view holds
    /// a weak (borrow) reference — it never creates, retains-owns, or disposes
    /// the model. Detaching and view deinit leave the model alive and usable.
    func testModelSurvivesViewDisposal() {
        let model = makeModel("hello\nworld")
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        // Attach: the view borrows the model (weak ref). The view does NOT
        // create, own, or retain-own the model.
        view.attach(model: model)
        XCTAssertTrue(view.isAttached, "view must report attached after attach")
        XCTAssertFalse(model.isDisposed(), "attaching must NOT dispose the model")

        // The view exposes the attached model as a weak (borrow) read.
        XCTAssertTrue(view.attachment.attachedModel === model,
                      "attachment must expose the attached model (weak/borrow)")

        // Detach: the model is NOT destroyed — the view never owns its lifetime.
        view.detach()
        XCTAssertFalse(view.isAttached, "view must report detached after detach")
        XCTAssertFalse(model.isDisposed(),
                       "detaching must NOT dispose the model — lifetime is independent")

        // The model is still fully usable after the view detached.
        XCTAssertEqual(model.getValue(), "hello\nworld",
                       "model must remain usable after detach")
    }

    /// A model survives the view being deinitialized. The view's `deinit` detaches
    /// all callbacks but never disposes the model — the external owner keeps the
    /// model alive.
    func testModelSurvivesViewDeinit() {
        let model = makeModel("survive\ndeinit")
        do {
            let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
            view.attach(model: model)
            XCTAssertTrue(view.isAttached)
            // `view` is released here → `deinit` runs → callbacks detach.
        }

        // The model is still alive: the external owner (this test) holds the only
        // strong reference, and the view never disposed it.
        XCTAssertFalse(model.isDisposed(),
                       "model must survive view disposal — view deinit never disposes it")
        XCTAssertEqual(model.getValue(), "survive\ndeinit",
                       "model must remain usable after the view is torn down")
    }

    // MARK: - Invariant 3: Detach all callbacks before disposal

    /// While attached, content-change events from the model reach the view.
    /// After `detach()`, the view's subscriptions are gone — further content
    /// changes never reach the view. `detach()` is idempotent and never throws.
    func testDetachRemovesAllCallbacksBeforeDisposal() {
        let model = makeModel("initial")
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        view.attach(model: model)

        let observationsBefore = view.contentChangeObservations

        // A content change reaches the view (the subscription is live).
        model.setValue("changed")
        XCTAssertEqual(view.contentChangeObservations, observationsBefore + 1,
                       "attached view must observe content-change events")

        // Detach removes EVERY subscription the view registered on the model.
        view.detach()

        // Further content changes never reach the view — no retained closures.
        let observationsAtDetach = view.contentChangeObservations
        model.setValue("again")
        model.setValue("and-again")
        XCTAssertEqual(view.contentChangeObservations, observationsAtDetach,
                       "after detach, no callbacks may fire — all subscriptions removed")

        // Detach is idempotent: calling it again is a no-op (no trap, no effect).
        view.detach()
        XCTAssertEqual(view.contentChangeObservations, observationsAtDetach,
                       "detach must be idempotent")

        // The model is still alive — detach never disposes it.
        XCTAssertFalse(model.isDisposed())
    }

    // MARK: - Invariant 1 + 4: Composition + contract-owned surface

    /// The view is a native `NSView` that composes every Phase 03-04 subsystem.
    /// The public surface is exactly the contract — no internal gateway types
    /// leak as public collaborators of the view.
    func testViewIsNativeNSViewComposingAllSubsystems() {
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 100, height: 50))

        // The view is a native NSView boundary.
        XCTAssertTrue(view is NSView, "MonaCodeEditorView must be a native NSView")

        // The contract surface: attach / detach / isAttached / attachment.
        XCTAssertFalse(view.isAttached, "a fresh view is not attached")
        XCTAssertNotNil(view.attachment, "the view must expose its attachment helper")

        // Every Phase 03-04 subsystem is composed (internal collaborators).
        // Projection.
        XCTAssertNil(view.viewGraph, "no view graph before attach")
        XCTAssertNil(view.geometryBarrier, "no geometry barrier before attach")
        // Renderer branch (model-independent — present before attach).
        XCTAssertNotNil(view.cgRenderer, "the Core Graphics renderer is composed")
        XCTAssertNotNil(view.metalRenderer, "the conditional Metal branch is composed")
        // Input (model-independent gateways present before attach).
        XCTAssertNotNil(view.pointerGateway)
        XCTAssertNotNil(view.scrollGateway)
        XCTAssertNotNil(view.contextMenuGateway)
        XCTAssertNotNil(view.keyEventGateway)
        // Transfer.
        XCTAssertNotNil(view.pasteEditPipeline)
        // Accessibility (model-independent coordinators present before attach).
        XCTAssertNotNil(view.focusCoordinator)
        XCTAssertNotNil(view.announcementBridge)

        // Attach wires the model-dependent subsystems.
        let model = makeModel()
        view.attach(model: model)
        XCTAssertNotNil(view.viewGraph, "attach composes the projection (view graph)")
        XCTAssertNotNil(view.geometryBarrier, "attach composes the geometry barrier")
        XCTAssertNotNil(view.inputBarrier, "attach composes the multi-cursor input barrier")
        XCTAssertNotNil(view.axElementGraph, "attach composes the AX element graph")
        XCTAssertNotNil(view.axMutationGateway, "attach composes the AX mutation gateway")
        XCTAssertNotNil(view.pasteboardGateway, "attach composes the clipboard gateway")
        XCTAssertNotNil(view.dragDropGateway, "attach composes the drag/drop gateway")
        XCTAssertNotNil(view.servicesGateway, "attach composes the Services gateway")
        XCTAssertNotNil(view.compositionArbiter, "attach composes the IME composition arbiter")

        view.detach()
        // Model-dependent collaborators are released on detach.
        XCTAssertNil(view.viewGraph, "detach releases the model-dependent projection")
        XCTAssertNil(view.axElementGraph, "detach releases the model-dependent AX graph")
    }
}
