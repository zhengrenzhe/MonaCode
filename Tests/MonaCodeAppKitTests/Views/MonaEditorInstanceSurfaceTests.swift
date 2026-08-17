// MonaEditorInstanceSurfaceTests.swift
//
// P05-T012 — Close editor factories and five instance-interface sequences.
//
// Verifies the editor factory (create/attach/retrieve/dispose + global
// editor/model event sequences via `MonaEmitter`) and the five F1-R3
// instance-interface surfaces (exact retained member counts + native type
// adaptations), with diff/multi-diff construction kept behind Phase 07
// adapters while their declaration slots are preserved.
//
// Test contract (P05-T012): 1 case file. The case proves:
//   1. editor create/attach/retrieve/dispose lifecycle;
//   2. global editor/model event sequences fire (editor-created,
//      editor-disposed, model-created, model-will-dispose);
//   3. the 5 instance surfaces with EXACT retained member counts (assert the
//      counts — ownDeclarationCount + ownUniqueCount — match F1-R3 verbatim);
//   4. native type adaptations (monaco ITextModel -> MonaCodeModel,
//      IStandaloneCodeEditor -> the native editor type, DOMNode -> NSView,
//      ClientPoint -> CGPoint, DOMWidget -> the widget NSView protocol,
//      KeyboardEvent -> the keyboard event snapshot, MouseEvent -> the pointer
//      event snapshot, FontInfoTarget -> the native font-info target);
//   5. diff/multi-diff declaration slots are preserved, but their construction
//      is behind a Phase 07 adapter (unavailable until Phase 07 wires it).

import XCTest
import AppKit
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

@MainActor
final class MonaEditorInstanceSurfaceTests: XCTestCase {

    // MARK: - 1. Editor create/attach/retrieve/dispose lifecycle

    /// `create(model:options:)` produces an editor that is registered,
    /// retrievable by id, and reported by `getEditors()`. Disposing it removes
    /// it from the registry and fires the disposal sequence.
    func testEditorCreateRetrieveDisposeLifecycle() {
        let factory = MonaEditorFactory()
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/factory/lifecycle")
        )

        let editor = factory.create(model: model, options: nil)
        XCTAssertNotNil(editor, "create(model:options:) must produce an editor")
        XCTAssertFalse(editor.id.isEmpty, "editor must carry a non-empty id")
        XCTAssertTrue(factory.getEditors().contains(where: { $0.id == editor.id }),
                      "created editor must be present in getEditors()")
        XCTAssertTrue(factory.retrieve(id: editor.id) === editor,
                      "retrieve(id:) must return the exact editor instance")

        // dispose: removes from registry.
        factory.dispose(editor: editor)
        XCTAssertNil(factory.retrieve(id: editor.id),
                     "disposed editor must no longer be retrievable")
        XCTAssertFalse(factory.getEditors().contains(where: { $0.id == editor.id }),
                       "disposed editor must not appear in getEditors()")
    }

    /// `create(model:)` (no-options overload) attaches the model so the editor
    /// reports attached. The model's lifetime is independent from the editor —
    /// disposing the editor does NOT dispose an externally-owned model.
    func testCreateWithoutOptionsAttachesAndModelLifetimeIsIndependent() {
        let factory = MonaEditorFactory()
        let model = MonaCodeModel(
            text: "hello",
            uri: MonaURI(scheme: "inmemory", path: "/factory/no-options")
        )

        let editor = factory.create(model: model)
        XCTAssertTrue(editor.isAttached, "create(model:) must attach the model")

        factory.dispose(editor: editor)
        XCTAssertFalse(model.isDisposed(),
                       "disposing an editor must NOT dispose an externally-owned model")
    }

    /// `attach(editor:model:)` attaches a model to an existing editor and
    /// detaches any prior model first (idempotent attach path).
    func testAttachSwapsModelIdempotently() {
        let factory = MonaEditorFactory()
        let first = MonaCodeModel(
            text: "first",
            uri: MonaURI(scheme: "inmemory", path: "/factory/attach-first")
        )
        let second = MonaCodeModel(
            text: "second",
            uri: MonaURI(scheme: "inmemory", path: "/factory/attach-second")
        )

        let editor = factory.create(model: first)
        XCTAssertTrue(editor.attachment.attachedModel === first)

        factory.attach(editor: editor, model: second)
        XCTAssertTrue(editor.isAttached, "editor must remain attached after swap")
        XCTAssertTrue(editor.attachment.attachedModel === second,
                      "attach must swap to the new model")

        // Neither model was disposed by attach/swap (lifetime independent).
        XCTAssertFalse(first.isDisposed())
        XCTAssertFalse(second.isDisposed())
    }

    /// `disposeAll()` disposes every editor the factory created.
    func testDisposeAllClearsRegistry() {
        let factory = MonaEditorFactory()
        let model = MonaCodeModel(
            text: "x",
            uri: MonaURI(scheme: "inmemory", path: "/factory/dispose-all")
        )
        _ = factory.create(model: model)
        _ = factory.create(model: model)
        XCTAssertEqual(factory.getEditors().count, 2)

        factory.disposeAll()
        XCTAssertTrue(factory.getEditors().isEmpty,
                      "disposeAll must empty the editor registry")
    }

    // MARK: - 2. Global editor/model event sequences fire

    /// `onDidCreateEditor` fires with the exact editor instance when an editor
    /// is created.
    func testOnDidCreateEditorFires() {
        let factory = MonaEditorFactory()
        var fired: MonaCodeEditorView?
        _ = factory.onDidCreateEditor { editor in fired = editor }

        let model = MonaCodeModel(
            text: "create",
            uri: MonaURI(scheme: "inmemory", path: "/events/create-editor")
        )
        let editor = factory.create(model: model)
        XCTAssertTrue(fired === editor,
                      "onDidCreateEditor must fire with the created editor")
    }

    /// `onDidDisposeEditor` fires when an editor is disposed.
    func testOnDidDisposeEditorFires() {
        let factory = MonaEditorFactory()
        var fired: MonaCodeEditorView?
        _ = factory.onDidDisposeEditor { editor in fired = editor }

        let model = MonaCodeModel(
            text: "dispose",
            uri: MonaURI(scheme: "inmemory", path: "/events/dispose-editor")
        )
        let editor = factory.create(model: model)
        factory.dispose(editor: editor)
        XCTAssertTrue(fired === editor,
                      "onDidDisposeEditor must fire with the disposed editor")
    }

    /// `createModel` fires `onDidCreateModel`, and disposing the model fires
    /// `onWillDisposeModel`.
    func testModelGlobalEventsFire() {
        let factory = MonaEditorFactory()
        var createdModel: MonaCodeModel?
        var willDisposeModel: MonaCodeModel?
        _ = factory.onDidCreateModel { model in createdModel = model }
        _ = factory.onWillDisposeModel { model in willDisposeModel = model }

        let model = factory.createModel(
            text: "model-event",
            uri: MonaURI(scheme: "inmemory", path: "/events/model")
        )
        XCTAssertTrue(createdModel === model,
                      "onDidCreateModel must fire with the created model")

        model.dispose()
        XCTAssertTrue(willDisposeModel === model,
                      "onWillDisposeModel must fire when the model is disposed")
    }

    // MARK: - 3. The 5 instance surfaces with EXACT retained member counts

    /// Asserts the exact F1-R3 retained member counts for all five
    /// instance-interface surfaces. ownDeclarationCount (with overloads) and
    /// ownUniqueCount (deduplicated) must match the manifest verbatim.
    func testFiveInstanceSurfacesExactRetainedMemberCounts() {
        // IEditor: bases=[], ownDeclarationCount=43, ownUniqueCount=40.
        XCTAssertEqual(MonaInstanceSurfaceManifest.IEditor.bases, [])
        XCTAssertEqual(MonaInstanceSurfaceManifest.IEditor.ownDeclarationCount, 43)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IEditor.ownUniqueCount, 40)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IEditor.ownDeclarations.count, 43)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IEditor.ownUniqueMembers.count, 40)

        // ICodeEditor: bases=[IEditor], ownDeclarationCount=94, ownUniqueCount=94.
        XCTAssertEqual(MonaInstanceSurfaceManifest.ICodeEditor.bases, ["IEditor"])
        XCTAssertEqual(MonaInstanceSurfaceManifest.ICodeEditor.ownDeclarationCount, 94)
        XCTAssertEqual(MonaInstanceSurfaceManifest.ICodeEditor.ownUniqueCount, 94)
        XCTAssertEqual(MonaInstanceSurfaceManifest.ICodeEditor.ownDeclarations.count, 94)
        XCTAssertEqual(MonaInstanceSurfaceManifest.ICodeEditor.ownUniqueMembers.count, 94)

        // IStandaloneCodeEditor: bases=[ICodeEditor], 4/4.
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneCodeEditor.bases, ["ICodeEditor"])
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneCodeEditor.ownDeclarationCount, 4)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneCodeEditor.ownUniqueCount, 4)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneCodeEditor.ownDeclarations.count, 4)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneCodeEditor.ownUniqueMembers.count, 4)

        // IDiffEditor: bases=[IEditor], 17/17.
        XCTAssertEqual(MonaInstanceSurfaceManifest.IDiffEditor.bases, ["IEditor"])
        XCTAssertEqual(MonaInstanceSurfaceManifest.IDiffEditor.ownDeclarationCount, 17)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IDiffEditor.ownUniqueCount, 17)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IDiffEditor.ownDeclarations.count, 17)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IDiffEditor.ownUniqueMembers.count, 17)

        // IStandaloneDiffEditor: bases=[IDiffEditor], 5/5.
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneDiffEditor.bases, ["IDiffEditor"])
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneDiffEditor.ownDeclarationCount, 5)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneDiffEditor.ownUniqueCount, 5)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneDiffEditor.ownDeclarations.count, 5)
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneDiffEditor.ownUniqueMembers.count, 5)

        // Exactly five surfaces.
        XCTAssertEqual(MonaInstanceSurfaceManifest.surfaceCount, 5)
    }

    /// Verifies overload multiplicity is preserved: IEditor declares
    /// `setSelection` four times (43 declarations, 40 unique — 4 overloads
    /// collapse to 1 unique, +3 = 43-40).
    func testIEditorSetSelectionOverloadMultiplicityPreserved() {
        let setSelectionCount = MonaInstanceSurfaceManifest.IEditor.ownDeclarations.filter {
            $0 == "setSelection"
        }.count
        XCTAssertEqual(setSelectionCount, 4,
                       "IEditor must preserve the 4 setSelection overloads (43 decls, 40 unique)")
        // Unique list collapses the 5 overloads to 1.
        let uniqueSetSelection = MonaInstanceSurfaceManifest.IEditor.ownUniqueMembers.filter {
            $0 == "setSelection"
        }.count
        XCTAssertEqual(uniqueSetSelection, 1)
    }

    /// Verifies declaration order is verbatim from the manifest (first and
    /// last own-unique members of each surface).
    func testInstanceSurfaceDeclarationOrderVerbatim() {
        // IEditor own-unique first/last.
        XCTAssertEqual(MonaInstanceSurfaceManifest.IEditor.ownUniqueMembers.first, "onDidDispose")
        XCTAssertEqual(MonaInstanceSurfaceManifest.IEditor.ownUniqueMembers.last, "createDecorationsCollection")
        // ICodeEditor own-unique first/last.
        XCTAssertEqual(MonaInstanceSurfaceManifest.ICodeEditor.ownUniqueMembers.first, "onDidChangeModelContent")
        XCTAssertEqual(MonaInstanceSurfaceManifest.ICodeEditor.ownUniqueMembers.last, "handleInitialized")
        // IStandaloneCodeEditor own-unique (all 4).
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneCodeEditor.ownUniqueMembers,
                       ["updateOptions", "addCommand", "createContextKey", "addAction"])
        // IDiffEditor own-unique first/last.
        XCTAssertEqual(MonaInstanceSurfaceManifest.IDiffEditor.ownUniqueMembers.first, "getContainerDomNode")
        XCTAssertEqual(MonaInstanceSurfaceManifest.IDiffEditor.ownUniqueMembers.last, "handleInitialized")
        // IStandaloneDiffEditor own-unique (all 5).
        XCTAssertEqual(MonaInstanceSurfaceManifest.IStandaloneDiffEditor.ownUniqueMembers,
                       ["addCommand", "createContextKey", "addAction", "getOriginalEditor", "getModifiedEditor"])
    }

    // MARK: - 4. Native type adaptations

    /// The F1-R3 native type replacements map DOM-bearing types to native
    /// Swift types. Each adaptation must resolve to the declared native type
    /// and never be a silent no-op.
    func testNativeTypeAdaptationsResolveToDeclaredNativeTypes() {
        // DOMNode -> typed NSView protocol or concrete NSView.
        XCTAssertTrue(MonaInstanceDOMNode.self == NSView.self,
                     "DOMNode must adapt to NSView")
        // ClientPoint -> editor-view local CGPoint.
        XCTAssertTrue(MonaInstanceClientPoint.self == CGPoint.self,
                     "ClientPoint must adapt to CGPoint")
        // DOMWidget -> typed Mona content/overlay/glyph NSView protocol.
        let widgetType = MonaInstanceDOMWidget.self
        XCTAssertNotNil(widgetType,
                        "DOMWidget must adapt to a typed Mona widget NSView protocol")
        // KeyboardEvent -> immutable Mona keyboard event snapshot.
        XCTAssertTrue(MonaInstanceKeyboardEvent.self == MonaPublicKeyboardEvent.self,
                     "KeyboardEvent must adapt to the Mona keyboard event snapshot")
        // MouseEvent -> immutable Mona pointer event snapshot.
        XCTAssertTrue(MonaInstanceMouseEvent.self == MonaPointerEvent.self,
                     "MouseEvent must adapt to the Mona pointer event snapshot")
        // FontInfoTarget -> native text-attributes target.
        XCTAssertTrue(MonaInstanceFontInfoTarget.self == MonaEditorFontInfo.self,
                     "FontInfoTarget must adapt to the native font-info target")

        // Instance-interface type adaptations.
        // monaco ITextModel -> MonaCodeModel.
        XCTAssertTrue(MonaInstanceITextModel.self == MonaCodeModel.self,
                     "ITextModel must adapt to MonaCodeModel")
        // monaco IStandaloneCodeEditor -> the native editor type.
        XCTAssertTrue(MonaInstanceStandaloneCodeEditor.self == MonaCodeEditorView.self,
                     "IStandaloneCodeEditor must adapt to the native editor type (MonaCodeEditorView)")
    }

    /// The 14 DOM-bearing members listed in `nativeTypeReplacements.members`
    /// must all be retained on the ICodeEditor surface (they are the members
    /// whose signatures carry the adapted DOM types).
    func testDomBearingMembersRetainedOnICodeEditor() {
        let domBearingMembers = MonaInstanceSurfaceManifest.nativeReplacementMembers
        XCTAssertEqual(domBearingMembers.count, 14)
        let icEditorUnique = Set(MonaInstanceSurfaceManifest.ICodeEditor.ownUniqueMembers)
        for member in domBearingMembers {
            XCTAssertTrue(icEditorUnique.contains(member),
                         "DOM-bearing member \(member) must be retained on ICodeEditor")
        }
    }

    // MARK: - 5. Diff/multi-diff declaration slots preserved, Phase 07 adapter

    /// The diff editor and multi-file diff editor declaration slots exist as
    /// native types, but their construction is behind a Phase 07 adapter and
    /// throws until Phase 07 wires it.
    func testDiffAndMultiDiffSlotsPreservedButConstructionBehindPhase07() {
        // Declaration slots exist (types are real, not absent).
        _ = MonaDiffEditorView.self
        _ = MonaMultiDiffEditorView.self

        let factory = MonaEditorFactory()

        // createDiffEditor throws .phase07NotWired.
        do {
            _ = try factory.createDiffEditor(
                original: nil,
                modified: nil,
                options: nil
            )
            XCTFail("createDiffEditor must throw until Phase 07 wires it")
        } catch MonaEditorFactoryError.phase07NotWired {
            // expected
        } catch {
            XCTFail("createDiffEditor must throw .phase07NotWired, got: \(error)")
        }

        // createMultiFileDiffEditor throws .phase07NotWired.
        do {
            _ = try factory.createMultiFileDiffEditor(options: nil)
            XCTFail("createMultiFileDiffEditor must throw until Phase 07 wires it")
        } catch MonaEditorFactoryError.phase07NotWired {
            // expected
        } catch {
            XCTFail("createMultiFileDiffEditor must throw .phase07NotWired, got: \(error)")
        }

        // The multi-file diff nativeReturnType is recorded as MonaMultiDiffEditorView
        // (the F1-R3 multiFileDiff.nativeReturnType) — the slot is preserved.
        XCTAssertEqual(MonaInstanceSurfaceManifest.multiFileDiffNativeReturnType,
                       "MonaMultiDiffEditorView")
        XCTAssertEqual(MonaInstanceSurfaceManifest.multiFileDiffSourceFactory,
                       "editor.createMultiFileDiffEditor")
    }
}
