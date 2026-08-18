// MonaDiffViewLifecycleTests.swift
//
// P07-T009 — Deliver diff and multi-diff views, SwiftUI wrappers, and
// sample-host activation.
//
// Verifies the four load-bearing invariants of the diff + multi-diff view
// layer, the SwiftUI wrappers, and the sample-host activation:
//
//   1. Compose original and modified editors over shared models and ONE diff
//      coordinator — `MonaDiffEditorView` composes two `MonaCodeEditorView`s
//      (original + modified) sharing models, driven by one `MonaDiffCoordinator`
//      (P07-T002). The view is the slot P05-T012 preserved.
//
//   2. Consume ordered multi-diff snapshots with stable item identity and
//      synchronous change events — `MonaMultiDiffEditorView` consumes
//      snapshots from a `MonaMultiDiffDataSource` (P07-T005 host group):
//      each item carries a stable id; change events fire SYNCHRONOUSLY.
//
//   3. Wrap both native views with lifecycle-only SwiftUI types —
//      `MonaDiffEditor` + `MonaMultiDiffEditor` are `NSViewRepresentable`
//      bridges with stable identity, declared-only updates, and no logic
//      duplication (same invariants as P04-T015's `MonaCodeEditor`).
//
//   4. Activate all three products in the sample host without adding
//      production dependencies — `Sources/MonaCodeSample/main.swift` activates
//      MonaCode + MonaCodeAppKit + MonaCodeSwiftUI. The sample is a NON-PRODUCT
//      executable target, so activating products there adds NO production
//      dependencies.
//
// Test contract (P07-T009): 1 case (lifecycle), 4 red-scaffold rows.

import XCTest
import AppKit
import SwiftUI
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit
@testable import MonaCodeSwiftUI

@MainActor
final class MonaDiffViewLifecycleTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a model with a small multi-line document for the diff tests.
    private func makeModel(_ text: String, path: String) -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: path)
        )
    }

    // MARK: - Invariant 1: Compose original + modified editors over one coordinator

    /// `MonaDiffEditorView` composes two `MonaCodeEditorView`s (original +
    /// modified) sharing models, driven by ONE `MonaDiffCoordinator` (T002).
    /// Attaching the original + modified models attaches BOTH sub-editors; the
    /// coordinator is the single shared coordinator; detaching detaches both;
    /// neither model is disposed by attach/detach (lifetime independent).
    func testDiffEditorViewComposesTwoEditorsAndOneCoordinator() {
        let original = makeModel("abc\ndef", path: "/diff-original")
        let modified = makeModel("abc\nXYZ", path: "/diff-modified")

        let view = MonaDiffEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))

        // The view composes two distinct MonaCodeEditorView sub-editors.
        XCTAssertTrue(view.originalEditor is MonaCodeEditorView,
                      "original editor is a MonaCodeEditorView")
        XCTAssertTrue(view.modifiedEditor is MonaCodeEditorView,
                      "modified editor is a MonaCodeEditorView")
        XCTAssertFalse(view.originalEditor === view.modifiedEditor,
                       "original + modified are DISTINCT editor instances")
        XCTAssertFalse(view.originalEditor === view.modifiedEditor,
                       "original + modified are not the same instance")

        // The view composes ONE MonaDiffCoordinator (T002) shared across both.
        XCTAssertTrue(view.coordinator is MonaDiffCoordinator,
                      "the coordinator is a MonaDiffCoordinator (P07-T002)")

        // Initially not attached.
        XCTAssertFalse(view.isAttached, "fresh diff view is not attached")

        // Attach original + modified: both sub-editors attach their models.
        view.attach(original: original, modified: modified)
        XCTAssertTrue(view.isAttached, "diff view is attached after attach")
        XCTAssertTrue(view.originalEditor.isAttached, "original editor attached")
        XCTAssertTrue(view.modifiedEditor.isAttached, "modified editor attached")
        XCTAssertTrue(view.originalEditor.attachment.attachedModel === original,
                      "original model attached to the original editor (weak/borrow)")
        XCTAssertTrue(view.modifiedEditor.attachment.attachedModel === modified,
                      "modified model attached to the modified editor (weak/borrow)")

        // Detach: both sub-editors detach; neither model is disposed (lifetime
        // independent from view attachment — P04-T014 invariant carried forward).
        view.detach()
        XCTAssertFalse(view.isAttached, "diff view detached")
        XCTAssertFalse(view.originalEditor.isAttached, "original editor detached")
        XCTAssertFalse(view.modifiedEditor.isAttached, "modified editor detached")
        XCTAssertFalse(original.isDisposed(), "original model survives detach")
        XCTAssertFalse(modified.isDisposed(), "modified model survives detach")
    }

    // MARK: - Invariant 2: Consume multi-diff snapshots (stable identity, sync events)

    /// `MonaMultiDiffEditorView` consumes ordered snapshots from a
    /// `MonaMultiDiffDataSource` (T005). Each item carries a stable id; change
    /// events fire SYNCHRONOUSLY (the view's snapshot updates immediately when
    /// the source fires, not async).
    func testMultiDiffEditorViewConsumesSnapshotsWithStableIdentityAndSyncEvents() {
        let source = TestMultiDiffDataSource(items: [
            MonaMultiDiffItem(id: "a", originalModelURI: nil, modifiedModelURI: nil,
                              label: "A", description: nil),
            MonaMultiDiffItem(id: "b", originalModelURI: nil, modifiedModelURI: nil,
                              label: "B", description: nil),
        ])

        let view = MonaMultiDiffEditorView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        XCTAssertFalse(view.isAttached, "fresh multi-diff view is not attached")

        // Attach: the view consumes the initial snapshot synchronously.
        view.attach(dataSource: source)
        XCTAssertTrue(view.isAttached, "multi-diff view attached")
        XCTAssertEqual(view.currentSnapshot.count, 2, "initial snapshot consumed")
        XCTAssertEqual(view.currentSnapshot.map(\.id), ["a", "b"],
                       "snapshot preserves item order + stable ids")

        // Synchronous change event: update the source's snapshot. The view's
        // snapshot must reflect the new items IMMEDIATELY (sync, not async).
        source.update([
            MonaMultiDiffItem(id: "a", originalModelURI: nil, modifiedModelURI: nil,
                              label: "A*", description: nil),
            MonaMultiDiffItem(id: "c", originalModelURI: nil, modifiedModelURI: nil,
                              label: "C", description: nil),
        ])
        XCTAssertEqual(view.currentSnapshot.count, 2, "sync change updated the view snapshot")
        XCTAssertEqual(view.currentSnapshot.map(\.id), ["a", "c"],
                       "stable id 'a' retained; 'b' dropped; 'c' added — sync")
        XCTAssertEqual(view.currentSnapshot.first?.label, "A*",
                       "the retained 'a' item reflects its new content")

        // A duplicate-id snapshot is REJECTED by the source (the previous
        // snapshot is preserved). The view's snapshot is unchanged.
        source.update([
            MonaMultiDiffItem(id: "dup", originalModelURI: nil, modifiedModelURI: nil,
                              label: "D1", description: nil),
            MonaMultiDiffItem(id: "dup", originalModelURI: nil, modifiedModelURI: nil,
                              label: "D2", description: nil),
        ])
        XCTAssertEqual(view.currentSnapshot.map(\.id), ["a", "c"],
                       "rejected duplicate-id snapshot preserves the prior view state")

        // Detach: the view stops consuming; a later source change does NOT reach
        // the view's snapshot.
        let countBefore = view.currentSnapshot.count
        view.detach()
        XCTAssertFalse(view.isAttached, "multi-diff view detached")
        source.update([
            MonaMultiDiffItem(id: "z", originalModelURI: nil, modifiedModelURI: nil,
                              label: "Z", description: nil),
        ])
        XCTAssertEqual(view.currentSnapshot.count, countBefore,
                        "after detach, source changes do NOT reach the view snapshot")
    }

    // MARK: - Invariant 3: SwiftUI wrappers are lifecycle-only

    /// `MonaDiffEditor` + `MonaMultiDiffEditor` are lifecycle-only
    /// `NSViewRepresentable` bridges: stable identity (a re-render reuses the
    /// SAME native view), declared-only updates (no semantics re-run), and no
    /// logic duplication (the wrapper owns no renderer/input/provider/command
    /// collaborators — those live in the AppKit views + Core).
    func testSwiftUIWrappersAreLifecycleOnly() {
        // Both wrappers are NSViewRepresentable (SwiftUI→AppKit bridges).
        let original = makeModel("orig", path: "/swiftui-diff-orig")
        let modified = makeModel("mod", path: "/swiftui-diff-mod")
        let diffController = MonaDiffEditorController(original: original, modified: modified)
        let diffWrapper = MonaDiffEditor(controller: diffController)
        XCTAssertTrue(diffWrapper is any NSViewRepresentable,
                      "MonaDiffEditor must be an NSViewRepresentable")

        let multiController = MonaMultiDiffEditorController(
            dataSource: TestMultiDiffDataSource(items: [])
        )
        let multiWrapper = MonaMultiDiffEditor(controller: multiController)
        XCTAssertTrue(multiWrapper is any NSViewRepresentable,
                      "MonaMultiDiffEditor must be an NSViewRepresentable")

        // Stable identity: makeNSView equivalent creates the native view ONCE;
        // a re-render (applyDeclaredChanges with unchanged models) reuses the
        // SAME view instance + SAME identity token.
        let diffView = diffController.makeDiffView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        XCTAssertTrue(diffView is MonaDiffEditorView, "controller creates a MonaDiffEditorView")
        let tokenBefore = diffController.identityToken
        diffController.applyDeclaredChanges(original: original, modified: modified)
        XCTAssertTrue(diffController.diffView === diffView,
                      "a re-render must NOT recreate the diff view — stable identity")
        XCTAssertEqual(diffController.identityToken, tokenBefore,
                       "identity token is stable across re-renders")
        XCTAssertFalse(original.isDisposed(), "original model survives a no-op re-render")
        XCTAssertFalse(modified.isDisposed(), "modified model survives a no-op re-render")

        let multiView = multiController.makeMultiDiffView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        XCTAssertTrue(multiView is MonaMultiDiffEditorView, "controller creates a MonaMultiDiffEditorView")
        let multiTokenBefore = multiController.identityToken
        multiController.applyDeclaredChanges(dataSource: multiController.dataSource!)
        XCTAssertTrue(multiController.multiDiffView === multiView,
                      "a re-render must NOT recreate the multi-diff view — stable identity")
        XCTAssertEqual(multiController.identityToken, multiTokenBefore,
                       "multi-diff identity token is stable across re-renders")

        // Declared MODEL change on the diff controller re-attaches IN PLACE: the
        // view instance is reused, not recreated.
        let newModified = makeModel("mod2", path: "/swiftui-diff-mod2")
        diffController.applyDeclaredChanges(original: original, modified: newModified)
        XCTAssertTrue(diffController.diffView === diffView,
                      "a model change re-attaches in place — view NOT recreated")
        XCTAssertTrue(diffController.diffView?.modifiedEditor.attachment.attachedModel === newModified,
                      "the new modified model is attached to the in-place view")

        // Thin bridge: the wrappers own NO logic-bearing collaborators — only
        // declared-state properties (controller). No renderer / input barrier /
        // provider executor / command handler / text shaper.
        let diffSurface = Mirror(reflecting: diffWrapper).children.compactMap { $0.label }
        XCTAssertTrue(diffSurface.contains("controller"), "declared state: controller")
        XCTAssertFalse(diffSurface.contains("renderer"),
                       "wrapper owns no renderer — delegates to MonaDiffEditorView")
        XCTAssertFalse(diffSurface.contains("inputBarrier"),
                       "wrapper owns no input barrier — delegates to MonaDiffEditorView")
        XCTAssertFalse(diffSurface.contains("providerExecutor"),
                       "wrapper owns no provider executor")
        XCTAssertFalse(diffSurface.contains("commandHandler"),
                       "wrapper owns no command handler")

        let multiSurface = Mirror(reflecting: multiWrapper).children.compactMap { $0.label }
        XCTAssertTrue(multiSurface.contains("controller"), "declared state: controller")
        XCTAssertFalse(multiSurface.contains("renderer"),
                       "multi-diff wrapper owns no renderer")
        XCTAssertFalse(multiSurface.contains("inputBarrier"),
                       "multi-diff wrapper owns no input barrier")
    }

    // MARK: - Invariant 4: Sample host activates all three products

    /// `Sources/MonaCodeSample/main.swift` activates MonaCode + MonaCodeAppKit +
    /// MonaCodeSwiftUI (constructs editors / diff views / wrappers, attaches
    /// models). The sample is a NON-PRODUCT executable target, so this adds NO
    /// production dependencies (products=3 / nonProductTargets=3 preserved).
    func testSampleHostActivatesThreeProducts() {
        // The sample host's main.swift is a non-product executable target entry
        // point. Proving activation means proving it constructs representatives
        // from each of the three products — MonaCode (model/uri), MonaCodeAppKit
        // (native editor + diff views), MonaCodeSwiftUI (SwiftUI wrappers).
        let mainSwift = MonaDiffViewLifecycleTests.sampleMainSource()

        // MonaCode: the Core model + URI.
        XCTAssertTrue(mainSwift.contains("MonaCodeModel"),
                      "sample host activates MonaCode (MonaCodeModel)")
        XCTAssertTrue(mainSwift.contains("MonaURI"),
                      "sample host activates MonaCode (MonaURI)")

        // MonaCodeAppKit: the native editor + diff views.
        XCTAssertTrue(mainSwift.contains("MonaCodeEditorView"),
                      "sample host activates MonaCodeAppKit (MonaCodeEditorView)")
        XCTAssertTrue(mainSwift.contains("MonaDiffEditorView"),
                      "sample host activates MonaCodeAppKit (MonaDiffEditorView)")
        XCTAssertTrue(mainSwift.contains("MonaMultiDiffEditorView"),
                      "sample host activates MonaCodeAppKit (MonaMultiDiffEditorView)")

        // MonaCodeSwiftUI: the SwiftUI wrappers.
        XCTAssertTrue(mainSwift.contains("MonaCodeEditor"),
                      "sample host activates MonaCodeSwiftUI (MonaCodeEditor)")
        XCTAssertTrue(mainSwift.contains("MonaDiffEditor"),
                      "sample host activates MonaCodeSwiftUI (MonaDiffEditor)")
        XCTAssertTrue(mainSwift.contains("MonaMultiDiffEditor"),
                      "sample host activates MonaCodeSwiftUI (MonaMultiDiffEditor)")

        // The three products are imported explicitly (the sample target depends
        // on all three — a NON-PRODUCT target, so no production deps added).
        XCTAssertTrue(mainSwift.contains("import MonaCode"),
                      "sample host imports MonaCode")
        XCTAssertTrue(mainSwift.contains("import MonaCodeAppKit"),
                      "sample host imports MonaCodeAppKit")
        XCTAssertTrue(mainSwift.contains("import MonaCodeSwiftUI"),
                      "sample host imports MonaCodeSwiftUI")
    }

    // MARK: - Sample source accessor

    /// Reads `Sources/MonaCodeSample/main.swift` from the package root (SwiftPM
    /// runs tests with the package root as CWD). The sample is an executable
    /// target whose activation is a source-level property (it constructs the
    // three products' representatives); `swift build` proves it compiles.
    private static func sampleMainSource() -> String {
        let candidates = [
            "Sources/MonaCodeSample/main.swift",
            "./Sources/MonaCodeSample/main.swift",
        ]
        for path in candidates {
            if let data = FileManager.default.contents(atPath: path),
               let source = String(data: data, encoding: .utf8) {
                return source
            }
        }
        return ""
    }
}

// MARK: - Test multi-diff data source

/// A test-only `MonaMultiDiffDataSource` (P07-T005 host group) conformer: an
/// ordered snapshot + a synchronous change emitter. Duplicate-id updates are
/// rejected (the previous snapshot is preserved), matching the host contract.
private final class TestMultiDiffDataSource: MonaMultiDiffDataSource {

    private let emitter = MonaEmitter<MonaMultiDiffSnapshotChange>()
    private(set) var snapshot: [MonaMultiDiffItem]

    var onDidChangeSnapshot: MonaEvent<MonaMultiDiffSnapshotChange> { emitter.event }

    init(items: [MonaMultiDiffItem]) {
        self.snapshot = items
    }

    /// Synchronously fires a change event. A duplicate-id update is REJECTED:
    /// the previous snapshot is preserved and the event reports the rejection.
    func update(_ items: [MonaMultiDiffItem]) {
        let ids = items.map(\.id)
        let rejected = Set(ids).count != ids.count
        if rejected {
            emitter.fire(MonaMultiDiffSnapshotChange(
                items: snapshot, rejectedDuplicateIDs: true
            ))
            return
        }
        snapshot = items
        emitter.fire(MonaMultiDiffSnapshotChange(
            items: items, rejectedDuplicateIDs: false
        ))
    }
}
