// MonaCodeEditorSwiftUILifecycleTests.swift
//
// P04-T015 — Deliver MonaCodeEditor and MonaSwiftUIEditorController lifecycle wrappers.
//
// Verifies the lifecycle invariants of the SwiftUI surface over the AppKit editor
// boundary. `MonaCodeEditor` is the `NSViewRepresentable` (SwiftUI→AppKit bridge)
// and `MonaSwiftUIEditorController` is the explicit controller that owns the model
// + view attachment with STABLE IDENTITY across SwiftUI body re-evaluations.
//
// The three load-bearing invariants (each with a test):
//
//   1. Wrap the AppKit view with stable identity and explicit controller
//      ownership — a SwiftUI re-render (state change triggering `updateNSView`)
//      must reuse the SAME underlying `MonaCodeEditorView` instance and the SAME
//      model; identity is preserved.
//
//   2. Map SwiftUI updates to declared option, model, and focus changes only —
//      `updateNSView` applies only declared options (font/theme/snapshot of
//      declared state), model changes, and focus requests. It must NOT re-run
//      text semantics, rendering, input, or provider logic.
//
//   3. Keep text semantics, rendering, input, provider execution, and command
//      logic OUTSIDE the wrapper — the wrapper delegates entirely to
//      `MonaCodeEditorView` / `MonaEditorAttachment` (P04-T014). No logic
//      duplication.
//
// Test contract (P04-T015): 1 case (lifecycle), 2 red-scaffold rows.

import XCTest
import AppKit
import SwiftUI
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit
@testable import MonaCodeSwiftUI

@MainActor
final class MonaCodeEditorSwiftUILifecycleTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a model with a small multi-line document for the lifecycle tests.
    private func makeModel(_ text: String = "abc\ndef") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/swiftui-editor-lifecycle")
        )
    }

    // MARK: - Invariant 1: Stable identity + explicit controller ownership
    //
    // A SwiftUI re-render (state change triggering `updateNSView`) must reuse the
    // SAME underlying `MonaCodeEditorView` instance and the SAME model; the
    // controller is the single owner with stable identity.

    /// `makeNSView` creates the AppKit view ONCE via the controller. A subsequent
    /// re-render (`updateNSView` → `applyDeclaredChanges` with unchanged declared
    /// state) reuses the SAME view instance and the SAME attached model. The
    /// controller's identity token is stable across re-renders.
    func testControllerPreservesViewAndModelIdentityAcrossReRender() {
        let model = makeModel("hello\nworld")
        let controller = MonaSwiftUIEditorController(model: model)

        // makeNSView equivalent: create the view ONCE via the controller.
        let view = controller.makeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(view.isAttached, "makeEditorView attaches the declared model")
        XCTAssertTrue(view.attachment.attachedModel === model,
                      "the declared model is attached (weak/borrow — view never owns it)")

        // The controller is the single owner of the view it created.
        XCTAssertTrue(controller.editorView === view,
                      "controller owns the view it created (single owner)")
        let tokenBefore = controller.identityToken

        // Simulate a SwiftUI re-render: declared state changes trigger
        // `updateNSView`, which maps to `applyDeclaredChanges` with the SAME
        // model + SAME options + no focus request.
        controller.applyDeclaredChanges(
            model: model,
            options: .defaults,
            focusRequest: .none
        )

        // Identity preserved: SAME view instance, SAME model still attached,
        // SAME identity token. SwiftUI re-renders must NOT recreate the editor
        // or reset the model.
        XCTAssertTrue(controller.editorView === view,
                      "updateNSView must NOT recreate the view — stable identity")
        XCTAssertTrue(view.isAttached, "view remains attached after a re-render")
        XCTAssertTrue(view.attachment.attachedModel === model,
                      "same model remains attached after a re-render — identity preserved")
        XCTAssertEqual(controller.identityToken, tokenBefore,
                       "identity token is stable across SwiftUI re-renders")
    }

    // MARK: - Invariant 2: Map SwiftUI updates to declared option, model, focus ONLY
    //
    // `updateNSView` applies only declared options/model/focus. It must NOT
    // re-run text semantics, rendering, input, or provider logic.

    /// A re-render with an UNCHANGED model + UNCHANGED options + a focus request
    /// does NOT re-attach (no re-run of text semantics). A declared MODEL change
    /// re-attaches to the new model IN PLACE (the view instance is reused, not
    /// recreated). A declared OPTIONS change with an unchanged model also does
    /// NOT re-attach.
    func testUpdateMapsDeclaredChangesOnly_NoSemanticsReRun() {
        let modelA = makeModel("model-a")
        let controller = MonaSwiftUIEditorController(model: modelA)
        let view = controller.makeEditorView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))

        // While attached, a content change reaches the view (subscription live).
        modelA.setValue("model-a-edited")
        let observedAfterChange = view.contentChangeObservations
        XCTAssertGreaterThan(observedAfterChange, 0,
                            "attached view must observe content-change events")

        // Re-render with the SAME model + SAME options: updateNSView must NOT
        // re-attach. Re-attaching would re-run performAttach (which resets
        // contentChangeObservations to 0 = re-running semantics). The count
        // must be unchanged.
        controller.applyDeclaredChanges(
            model: modelA,
            options: .defaults,
            focusRequest: .focus
        )
        XCTAssertEqual(view.contentChangeObservations, observedAfterChange,
                       "updateNSView with unchanged model must NOT re-attach / re-run semantics")
        XCTAssertTrue(view.attachment.attachedModel === modelA,
                      "unchanged model stays attached (no spurious re-attach)")

        // A declared OPTIONS change with the SAME model: still no re-attach.
        let bigFont = MonaCodeEditorOptions(fontName: "Menlo", fontSize: 18, themeName: "dark")
        controller.applyDeclaredChanges(
            model: modelA,
            options: bigFont,
            focusRequest: .none
        )
        XCTAssertEqual(view.contentChangeObservations, observedAfterChange,
                       "an options-only change must NOT re-attach / re-run semantics")
        XCTAssertTrue(view.attachment.attachedModel === modelA,
                      "an options-only change must NOT detach the model")

        // A declared MODEL change: updateNSView re-attaches to the new model IN
        // PLACE — the view instance is reused, not recreated.
        let modelB = makeModel("model-b")
        controller.applyDeclaredChanges(
            model: modelB,
            options: .defaults,
            focusRequest: .none
        )
        XCTAssertTrue(view.attachment.attachedModel === modelB,
                       "a declared model change re-attaches to the new model")
        XCTAssertFalse(view.attachment.attachedModel === modelA,
                       "the prior model is no longer attached")
        XCTAssertTrue(controller.editorView === view,
                      "a model change re-attaches in place — the view is NOT recreated")

        // Neither model is disposed by re-attach: model lifetime is independent
        // from view attachment (the controller is the single owner; the view
        // borrows weakly).
        XCTAssertFalse(modelA.isDisposed(), "model A is never disposed by re-attach")
        XCTAssertFalse(modelB.isDisposed(), "model B is never disposed by attach")
    }

    // MARK: - Invariant 3: Wrapper delegates — no logic duplication
    //
    // The wrapper delegates entirely to MonaCodeEditorView / MonaEditorAttachment.
    // It owns NO text-semantics / rendering / input / provider / command logic.

    /// `MonaCodeEditor` is a thin `NSViewRepresentable`: its stored surface is
    /// ONLY the declared-state properties (controller / options / focusRequest).
    /// It owns no renderer, input barrier, provider executor, or command handler
    /// — those collaborators live in the AppKit view + Core, never in the
    /// SwiftUI bridge.
    func testWrapperIsThinBridge_NoRenderInputProviderLogic() {
        let model = makeModel()
        let editor = MonaCodeEditor(
            controller: MonaSwiftUIEditorController(model: model),
            options: .defaults,
            focusRequest: .none
        )

        // MonaCodeEditor is an NSViewRepresentable (SwiftUI→AppKit bridge).
        XCTAssertTrue(editor is any NSViewRepresentable,
                      "MonaCodeEditor must be an NSViewRepresentable")

        // The stored surface of MonaCodeEditor is ONLY the declared-state
        // properties — no logic-bearing collaborators.
        let surface = Mirror(reflecting: editor).children.compactMap { $0.label }
        XCTAssertTrue(surface.contains("controller"), "declared state: controller")
        XCTAssertTrue(surface.contains("options"), "declared state: options")
        XCTAssertTrue(surface.contains("focusRequest"), "declared state: focusRequest")

        // No text-semantics / rendering / input / provider / command logic in
        // the wrapper — those live in the AppKit view + Core.
        XCTAssertFalse(surface.contains("renderer"),
                       "wrapper owns no renderer — delegates to MonaCodeEditorView")
        XCTAssertFalse(surface.contains("inputBarrier"),
                       "wrapper owns no input barrier — delegates to MonaCodeEditorView")
        XCTAssertFalse(surface.contains("providerExecutor"),
                       "wrapper owns no provider executor — delegates to MonaCodeEditorView")
        XCTAssertFalse(surface.contains("commandHandler"),
                       "wrapper owns no command handler — delegates to MonaCodeEditorView")
        XCTAssertFalse(surface.contains("textShaper"),
                       "wrapper owns no text shaper — delegates to MonaCodeEditorView")
    }
}
