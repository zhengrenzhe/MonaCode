// MonaEditorInstanceConformanceTests.swift
//
// P05-T012 / P07-T009 — Close editor instance-surface conformance.
//
// Behavior tests proving the concrete code-editor and diff-editor instance
// adapters conform to the F1-R3 instance-interface protocols
// (`MonaInstanceIStandaloneCodeEditor` / `MonaInstanceIDiffEditor`) and that
// protocol members are dispatchable through the existential. The
// identity/lifetime/surface members (getId, getEditorType, getDomNode,
// getModel, setModel, getValue, dispose) are wired to the native view's real
// contract; the remaining members are typed placeholders (inert events,
// empty/nil/zero returns) preserved so the surface compiles and existential
// dispatch works — they are NOT capability completion (real editor-driving
// behavior is Phase 06+).
//
// Test contract (P05-T012 / P07-T009): 1 case file. The cases prove:
//   1. a concrete code-editor instance conforms to
//      `MonaInstanceIStandaloneCodeEditor` and its wired members dispatch
//      through the `MonaInstanceICodeEditor` existential to the real view;
//   2. a concrete diff-editor instance conforms to `MonaInstanceIDiffEditor`
//      and its wired members dispatch through the existential to the diff view;
//   3. the inert event surface is callable (subscribing returns a disposable
//      that can be disposed — the surface is non-blocking before Phase 06+).

import XCTest
import AppKit
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

// Local empty-protocol stubs the tests pass to the no-op standalone members
// (updateOptions / addAction). Test-only conforming types for the empty marker
// protocols; the adapter implementations ignore the payloads.
private struct MonaConformanceTestActionDescriptor: MonaEditorIActionDescriptor {}
private struct MonaConformanceTestStandaloneOptions
    : MonaEditorIStandaloneEditorConstructionOptions {}

@MainActor
final class MonaEditorInstanceConformanceTests: XCTestCase {

    // MARK: - 1. Code-editor instance conformance

    /// A `MonaEditorStandaloneCodeEditorAdapter` wrapping a
    /// `MonaCodeEditorView` conforms to `MonaInstanceIStandaloneCodeEditor`
    /// (and thus `MonaInstanceICodeEditor` / `MonaInstanceIEditor`), and the
    /// wired identity/lifetime/surface members dispatch through the
    /// existential to the real view contract.
    func testCodeEditorInstanceConformsAndDispatchesWiredMembers() {
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/conformance/code")
        )
        view.attach(model: model)

        // Conformance: the adapter is the ICodeEditor existential (the
        // standalone adapter is-a IStandaloneCodeEditor : ICodeEditor).
        let instance: MonaInstanceICodeEditor =
            MonaEditorStandaloneCodeEditorAdapter(view: view)

        // Identity (real — wired to the view's id / editor-type string).
        XCTAssertEqual(instance.getId(), view.id,
                       "getId() must dispatch to the view's stable id")
        XCTAssertEqual(instance.getEditorType(), "builtin",
                       "getEditorType() must report the builtin editor type")

        // DOM surface (real — the view IS the NSView DOM node).
        XCTAssertTrue(instance.getDomNode() === view,
                      "getDomNode() must return the view itself (NSView DOM node)")
        XCTAssertTrue(instance.getContainerDomNode() === view,
                      "getContainerDomNode() must return the view itself")

        // Model surface (real — delegates to the attachment helper).
        XCTAssertTrue(instance.getModel() === model,
                      "getModel() must dispatch to the attached model")
        XCTAssertEqual(instance.getValue(), "abc\ndef",
                       "getValue() must read the attached model's text")

        // setModel(nil) detaches; setModel(model) attaches (idempotent).
        instance.setModel(nil)
        XCTAssertNil(instance.getModel(),
                     "setModel(nil) must detach the model through the existential")
        instance.setModel(model)
        XCTAssertTrue(instance.getModel() === model,
                     "setModel(model) must re-attach through the existential")

        // Lifetime (real — dispose detaches without disposing the model).
        XCTAssertFalse(model.isDisposed(),
                       "model must not be disposed before dispose()")
        instance.dispose()
        XCTAssertNil(instance.getModel(),
                     "dispose() must detach the model through the existential")
        XCTAssertFalse(model.isDisposed(),
                       "dispose() must NOT dispose the externally-owned model")

        // Geometry defaults are typed placeholders (Phase 06+ layout wiring).
        XCTAssertEqual(instance.getContentWidth(), 0)
        XCTAssertEqual(instance.getContentHeight(), 0)
        XCTAssertEqual(instance.getScrollTop(), 0)
    }

    /// The inert event surface is callable through the existential: subscribing
    /// returns a disposable that can be disposed without blocking. The events
    /// do not fire (Phase 06+ event plumbing); the surface exists so the
    /// protocol compiles and existential dispatch works.
    func testCodeEditorInstanceInertEventSurfaceIsCallable() {
        let view = MonaCodeEditorView(frame: .zero)
        let instance: MonaInstanceICodeEditor =
            MonaEditorStandaloneCodeEditorAdapter(view: view)

        // Several event members must be subscribable through the existential
        // without crashing and return disposables that are disposable.
        let dispose1 = instance.onDidDispose { _ in }
        let dispose2 = instance.onDidChangeModelContent { _ in }
        let dispose3 = instance.onKeyDown { _ in }
        dispose1.dispose()
        dispose2.dispose()
        dispose3.dispose()
        // Idempotent re-dispose is a no-op.
        dispose1.dispose()
    }

    /// The IStandaloneCodeEditor surface (4 own members) dispatches through the
    /// `MonaInstanceIStandaloneCodeEditor` existential: createContextKey
    /// returns a real `MonaContextKey`, and the no-op members (updateOptions,
    /// addCommand, addAction) do not block.
    func testStandaloneCodeEditorSurfaceMembersDispatch() {
        let view = MonaCodeEditorView(frame: .zero)
        let standalone: MonaInstanceIStandaloneCodeEditor =
            MonaEditorStandaloneCodeEditorAdapter(view: view)

        let key = standalone.createContextKey("editorTextFocus")
        XCTAssertEqual(key.name, "editorTextFocus",
                       "createContextKey must carry the requested name")

        // No-op members preserved so the surface compiles (Phase 06+ command/
        // context wiring). They must not crash and return nil defaults.
        XCTAssertNil(standalone.addCommand(0, { _ in }),
                     "addCommand must return nil before Phase 06+ command wiring")
        standalone.addAction(MonaConformanceTestActionDescriptor())
        standalone.updateOptions(MonaConformanceTestStandaloneOptions())
    }

    // MARK: - 2. Diff-editor instance conformance

    /// A `MonaEditorDiffEditorInstanceAdapter` wrapping a
    /// `MonaDiffEditorView` conforms to `MonaInstanceIDiffEditor` (and thus
    /// `MonaInstanceIEditor`), and the wired identity/lifetime/DOM members
    /// dispatch through the existential to the real diff view contract.
    func testDiffEditorInstanceConformsAndDispatchesWiredMembers() {
        let view = MonaDiffEditorView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let original = MonaCodeModel(
            text: "a",
            uri: MonaURI(scheme: "inmemory", path: "/conformance/diff/original")
        )
        let modified = MonaCodeModel(
            text: "b",
            uri: MonaURI(scheme: "inmemory", path: "/conformance/diff/modified")
        )
        view.attach(original: original, modified: modified)

        // Conformance: the adapter is the IDiffEditor existential.
        let instance: MonaInstanceIDiffEditor =
            MonaEditorDiffEditorInstanceAdapter(view: view)

        // Identity (real).
        XCTAssertFalse(instance.getId().isEmpty,
                       "getId() must return the diff view's non-empty id")
        XCTAssertEqual(instance.getEditorType(), "builtin",
                       "getEditorType() must report the builtin editor type")

        // DOM surface (real — the diff view IS the NSView DOM node).
        XCTAssertTrue(instance.getContainerDomNode() === view,
                      "getContainerDomNode() must return the diff view itself")

        // Sub-editors (real — the diff view composes two code editors; the
        // adapter exposes them as ICodeEditor existentials).
        let originalEditor = instance.getOriginalEditor()
        let modifiedEditor = instance.getModifiedEditor()
        XCTAssertEqual(originalEditor.getValue(), "a",
                       "getOriginalEditor().getValue() must read the original model")
        XCTAssertEqual(modifiedEditor.getValue(), "b",
                       "getModifiedEditor().getValue() must read the modified model")

        // Lifetime (real — dispose detaches both sub-editors without disposing
        // either model).
        instance.dispose()
        XCTAssertFalse(original.isDisposed(),
                       "original model must NOT be disposed by diff dispose()")
        XCTAssertFalse(modified.isDisposed(),
                       "modified model must NOT be disposed by diff dispose()")
    }

    /// The IDiffEditor surface's no-op members (goToDiff, revealFirstDiff,
    /// accessibleDiffViewerNext/Prev, updateOptions, handleInitialized,
    /// createViewModel, getLineChanges) dispatch through the existential
    /// without crashing — they are typed placeholders (Phase 06+ diff engine).
    func testDiffEditorInstancePlaceholderSurfaceMembersDispatch() {
        let view = MonaDiffEditorView(frame: .zero)
        let instance: MonaInstanceIDiffEditor =
            MonaEditorDiffEditorInstanceAdapter(view: view)

        // Navigation / a11y no-ops (Phase 07+ diff navigation wiring).
        instance.goToDiff(.next)
        instance.goToDiff(.previous)
        instance.revealFirstDiff(.next)
        instance.accessibleDiffViewerNext()
        instance.accessibleDiffViewerPrev()
        instance.handleInitialized()

        // Model surface placeholders.
        XCTAssertNil(instance.getModel(),
                     "getModel() must return nil before a diff model is attached")
        XCTAssertNil(instance.getLineChanges(),
                     "getLineChanges() must return nil before Phase 07+ diff computation")

        // createViewModel returns a real (stub) view model for the given models.
        let original = MonaCodeModel(
            text: "x",
            uri: MonaURI(scheme: "inmemory", path: "/conformance/diff/viewmodel/orig")
        )
        let modified = MonaCodeModel(
            text: "y",
            uri: MonaURI(scheme: "inmemory", path: "/conformance/diff/viewmodel/mod")
        )
        let viewModel = instance.createViewModel(original, modified)
        XCTAssertNotNil(viewModel,
                         "createViewModel must return a view-model instance")

        // Inert diff event surface is callable.
        let sub = instance.onDidUpdateDiff { _ in }
        sub.dispose()
    }

    // MARK: - 3. Multi-diff instance reachable through the diff surface

    /// `MonaMultiDiffEditorView` is a concrete NSView the factory constructs;
    /// it is reachable by metatype through the instance-surface file (the
    /// declaration graph records it as `multiFileDiffNativeReturnType`).
    func testMultiDiffViewReachableThroughInstanceSurface() {
        _ = MonaMultiDiffEditorView.self
        XCTAssertEqual(
            MonaInstanceSurfaceManifest.multiFileDiffNativeReturnType,
            "MonaMultiDiffEditorView"
        )
    }
}
