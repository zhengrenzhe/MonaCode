// MonaLifetimeRegistryTests.swift
//
// P01-T012 — Implement application-global and per-editor lifetime registries.
//
// Verifies the three H2-R lifetime registries:
//   - `MonaGlobalLifetime`: application-global lifetime. Owns global resources
//     (registries, services). Children disposed in reverse acquisition order.
//     Repeated teardown is inert (idempotent).
//   - `MonaEditorLifetime`: per-editor lifetime. Owns per-editor resources
//     (model, view, services). Disposes in reverse acquisition order. Inert on
//     repeated teardown.
//   - `MonaInitialModelRegistry`: tracks initial model state for the
//     first-model/initialization path. Weak accounting hooks for C09 (the
//     complexity gate) and the 1000-cycle lifecycle gate.
//
// Contract leaves exercised:
//   1. app-global / per-editor / initial-model registries with explicit owners.
//   2. dispose children in reverse acquisition order.
//   3. repeated teardown inert (idempotent).
//   4. weak accounting hooks (liveCount / totalRegistered / liveOwners) observe
//      release without retaining.
//
// On Green, `testGlobalLifetimeContractLeaf` prints the contract line:
//     LIFETIME registries=3 reverse=pass idempotent=pass weak=pass

import XCTest
import MonaCode

final class MonaLifetimeRegistryTests: XCTestCase {

    // MARK: - Test helpers

    /// A reference-typed recorder shared between a test and its disposables so
    /// the test can observe disposal order.
    private final class Recorder {
        var disposed: [String] = []
    }

    /// A disposable test resource that records `tag` on `Recorder` when
    /// disposed. Disposal is idempotent at the resource level so a repeated
    /// lifetime teardown cannot double-record.
    private final class TestResource: MonaDisposable {
        let tag: String
        private weak var recorder: Recorder?
        private var disposed = false

        init(tag: String, recorder: Recorder) {
            self.tag = tag
            self.recorder = recorder
        }

        var isDisposed: Bool { disposed }

        func dispose() {
            guard !disposed else { return }
            disposed = true
            recorder?.disposed.append(tag)
        }
    }

    // MARK: - 1. MonaGlobalLifetime — explicit owners + accounting

    func testGlobalLifetimeStartsEmptyAndNotDisposed() {
        let global = MonaGlobalLifetime()
        XCTAssertFalse(global.isDisposed)
        XCTAssertEqual(global.registeredCount, 0)
        XCTAssertEqual(global.registeredOwners, [])
    }

    func testGlobalLifetimeExposesEightProcessGlobalOwners() {
        // H2-R fixes exactly eight process-global owner categories.
        XCTAssertEqual(MonaGlobalResourceOwner.allCases.count, 8)
        // Spot-check the eight categories fixed by the H2-R runtimeScope.
        let owners = Set(MonaGlobalResourceOwner.allCases.map { $0.rawValue })
        for expected in [
            "environmentServices", "modelRegistry", "editorRegistry",
            "markerRegistry", "themeRegistry", "languageRegistry",
            "commandKeybindingMenuRegistry", "openerRegistry",
        ] {
            XCTAssertTrue(owners.contains(expected), "missing owner: \(expected)")
        }
    }

    func testGlobalLifetimeRegisterTracksExplicitOwnersAndCount() {
        let global = MonaGlobalLifetime()
        let recorder = Recorder()
        let r1 = TestResource(tag: "services", recorder: recorder)
        let r2 = TestResource(tag: "models", recorder: recorder)
        let r3 = TestResource(tag: "markers", recorder: recorder)

        global.register(.environmentServices, r1)
        global.register(.modelRegistry, r2)
        global.register(.markerRegistry, r3)

        XCTAssertEqual(global.registeredCount, 3)
        XCTAssertEqual(
            global.registeredOwners,
            [.environmentServices, .modelRegistry, .markerRegistry]
        )
        XCTAssertEqual(recorder.disposed, [])
    }

    // MARK: - 2. MonaGlobalLifetime — reverse acquisition order

    func testGlobalLifetimeDisposesChildrenInReverseAcquisitionOrder() {
        let global = MonaGlobalLifetime()
        let recorder = Recorder()
        global.register(.environmentServices, TestResource(tag: "A", recorder: recorder))
        global.register(.modelRegistry, TestResource(tag: "B", recorder: recorder))
        global.register(.editorRegistry, TestResource(tag: "C", recorder: recorder))
        global.register(.markerRegistry, TestResource(tag: "D", recorder: recorder))

        global.dispose()

        // Reverse of acquisition (A, B, C, D) is (D, C, B, A).
        XCTAssertEqual(recorder.disposed, ["D", "C", "B", "A"])
    }

    func testGlobalLifetimeDisposeIsIdempotentAndRepeatedTeardownIsInert() {
        let global = MonaGlobalLifetime()
        let recorder = Recorder()
        global.register(.environmentServices, TestResource(tag: "A", recorder: recorder))
        global.register(.modelRegistry, TestResource(tag: "B", recorder: recorder))

        global.dispose()
        // Repeated teardown: inert — no second disposal, no re-recording.
        global.dispose()
        global.dispose()

        XCTAssertEqual(recorder.disposed, ["B", "A"])
        XCTAssertTrue(global.isDisposed)
        XCTAssertEqual(global.registeredCount, 0)
        XCTAssertEqual(global.registeredOwners, [])
    }

    func testGlobalLifetimeRegistrationAfterDisposeImmediatelyDisposesResource() {
        // Post-dispose registration must not leak: the resource is disposed
        // immediately and not tracked, mirroring vscode's DisposableStore.
        let global = MonaGlobalLifetime()
        let recorder = Recorder()
        global.dispose()

        let late = TestResource(tag: "late", recorder: recorder)
        global.register(.openerRegistry, late)

        XCTAssertTrue(late.isDisposed)
        XCTAssertTrue(global.isDisposed)
        XCTAssertEqual(global.registeredCount, 0)
    }

    // MARK: - 3. MonaEditorLifetime — explicit owners + reverse order + idempotent

    func testEditorLifetimeExposesSevenPerEditorOwners() {
        // H2-R fixes exactly seven per-editor owner categories.
        XCTAssertEqual(MonaEditorResourceOwner.allCases.count, 7)
    }

    func testEditorLifetimeRegisterAndAccounting() {
        let editor = MonaEditorLifetime()
        let recorder = Recorder()
        editor.register(.modelAttachment, TestResource(tag: "model", recorder: recorder))
        editor.register(.selectionCursor, TestResource(tag: "sel", recorder: recorder))
        editor.register(.widgets, TestResource(tag: "wid", recorder: recorder))

        XCTAssertFalse(editor.isDisposed)
        XCTAssertEqual(editor.registeredCount, 3)
        XCTAssertEqual(
            editor.registeredOwners,
            [.modelAttachment, .selectionCursor, .widgets]
        )
    }

    func testEditorLifetimeDisposesInReverseAcquisitionOrder() {
        let editor = MonaEditorLifetime()
        let recorder = Recorder()
        editor.register(.modelAttachment, TestResource(tag: "1", recorder: recorder))
        editor.register(.selectionCursor, TestResource(tag: "2", recorder: recorder))
        editor.register(.scrollFocusContext, TestResource(tag: "3", recorder: recorder))
        editor.register(.imePointerEventDispatch, TestResource(tag: "4", recorder: recorder))

        editor.dispose()

        XCTAssertEqual(recorder.disposed, ["4", "3", "2", "1"])
        XCTAssertTrue(editor.isDisposed)
    }

    func testEditorLifetimeRepeatedTeardownIsInert() {
        let editor = MonaEditorLifetime()
        let recorder = Recorder()
        editor.register(.modelAttachment, TestResource(tag: "x", recorder: recorder))

        editor.dispose()
        editor.dispose()
        editor.dispose()

        XCTAssertEqual(recorder.disposed, ["x"])
        XCTAssertEqual(editor.registeredCount, 0)
    }

    func testEditorLifetimeRegistrationAfterDisposeImmediatelyDisposesResource() {
        let editor = MonaEditorLifetime()
        let recorder = Recorder()
        editor.dispose()

        let late = TestResource(tag: "late", recorder: recorder)
        editor.register(.widgets, late)

        XCTAssertTrue(late.isDisposed)
        XCTAssertEqual(editor.registeredCount, 0)
    }

    // MARK: - 4. MonaInitialModelRegistry — initial-model state tracking

    func testInitialModelDiscriminantHasThreeConstructionCases() {
        // H2-R fixes exactly three model construction cases.
        let cases: [MonaInitialModel] = [.implicitOwned, .externalBorrowed, .none]
        XCTAssertEqual(Set(cases).count, 3)
    }

    func testInitialModelRegistryStartsEmpty() {
        let registry = MonaInitialModelRegistry()
        XCTAssertFalse(registry.isDisposed)
        XCTAssertEqual(registry.totalRegistered, 0)
        XCTAssertEqual(registry.liveCount, 0)
        XCTAssertEqual(registry.liveOwners, [])
    }

    func testInitialModelRegistryTracksKindsAndCumulativeCount() {
        let registry = MonaInitialModelRegistry()

        // Two model-bearing constructions tracked weakly.
        let m1 = MonaCodeModel(text: "a", uri: MonaURI(scheme: "inmemory", path: "/1"))
        let m2 = MonaCodeModel(text: "b", uri: MonaURI(scheme: "inmemory", path: "/2"))
        registry.register(.implicitOwned, model: m1)
        registry.register(.externalBorrowed, model: m2)
        // The `.none` construction has no model to track.
        registry.register(.none, model: nil)

        XCTAssertEqual(registry.totalRegistered, 3)
        XCTAssertEqual(registry.liveCount, 2)
        XCTAssertEqual(registry.liveOwners, [.implicitOwned, .externalBorrowed])
    }

    // MARK: - 5. Weak accounting hooks (C09 + 1000-cycle lifecycle gate)

    func testInitialModelRegistryWeakAccountingReleasesOnDeallocWithoutDispose() {
        // The registry holds models WEAKLY: dropping the caller's strong
        // reference deallocates the model and the registry stops counting it,
        // even if the model was never explicitly disposed. This is the leak
        // signal the 1000-cycle gate observes.
        let registry = MonaInitialModelRegistry()

        do {
            let model = MonaCodeModel(
                text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m1")
            )
            registry.register(.implicitOwned, model: model)
            XCTAssertEqual(registry.totalRegistered, 1)
            XCTAssertEqual(registry.liveCount, 1)
            XCTAssertEqual(registry.liveOwners, [.implicitOwned])
        }

        // The do-scope held the only strong reference; the model is now
        // deallocated and the weak accounting hook reports zero live.
        XCTAssertEqual(registry.totalRegistered, 1, "cumulative count is sticky")
        XCTAssertEqual(registry.liveCount, 0)
        XCTAssertEqual(registry.liveOwners, [])
    }

    func testInitialModelRegistryWeakAccountingReleasesOnDisposeThenDealloc() {
        // Realistic lifecycle: the editor lifetime disposes the model, then the
        // caller releases its strong reference. The registry weakly observes
        // the release (dispose alone does not deallocate; the strong ref drop
        // does). The 1000-cycle gate asserts liveCount returns to zero.
        let registry = MonaInitialModelRegistry()
        var model: MonaCodeModel? = MonaCodeModel(
            text: "x", uri: MonaURI(scheme: "inmemory", path: "/m")
        )
        registry.register(.implicitOwned, model: model!)
        XCTAssertEqual(registry.liveCount, 1)

        model?.dispose()
        // Disposing clears emitters but does NOT deallocate — the registry
        // still sees the (disposed) model until the strong ref drops.
        XCTAssertEqual(registry.liveCount, 1)

        model = nil
        XCTAssertEqual(registry.liveCount, 0)
        XCTAssertEqual(registry.liveOwners, [])
    }

    func testInitialModelRegistryPartialLiveSetAfterPartialRelease() {
        let registry = MonaInitialModelRegistry()
        var m1: MonaCodeModel? = MonaCodeModel(text: "1", uri: MonaURI(scheme: "inmemory", path: "/1"))
        let m2 = MonaCodeModel(text: "2", uri: MonaURI(scheme: "inmemory", path: "/2"))
        registry.register(.implicitOwned, model: m1!)
        registry.register(.externalBorrowed, model: m2)

        XCTAssertEqual(registry.liveCount, 2)
        XCTAssertEqual(registry.liveOwners, [.implicitOwned, .externalBorrowed])

        m1 = nil  // release one; m2 still live
        XCTAssertEqual(registry.liveCount, 1)
        XCTAssertEqual(registry.liveOwners, [.externalBorrowed])
        XCTAssertEqual(registry.totalRegistered, 2)
    }

    func testInitialModelRegistryDisposeIsIdempotentAndClearsTracking() {
        let registry = MonaInitialModelRegistry()
        let m1 = MonaCodeModel(text: "1", uri: MonaURI(scheme: "inmemory", path: "/1"))
        registry.register(.implicitOwned, model: m1)

        registry.dispose()
        registry.dispose()  // inert

        XCTAssertTrue(registry.isDisposed)
        // Teardown clears the tracking table but the cumulative count records
        // that a registration occurred (C09 bound accounting).
        XCTAssertEqual(registry.liveCount, 0)
    }

    // MARK: - 6. Contract leaf

    func testGlobalLifetimeContractLeaf() {
        // Three registries, reverse-order dispose, idempotent teardown, weak
        // accounting — all present.
        let global = MonaGlobalLifetime()
        let editor = MonaEditorLifetime()
        let initial = MonaInitialModelRegistry()
        XCTAssertEqual(global.registeredCount, 0)
        XCTAssertEqual(editor.registeredCount, 0)
        XCTAssertEqual(initial.liveCount, 0)

        let recorder = Recorder()
        global.register(.environmentServices, TestResource(tag: "g1", recorder: recorder))
        global.register(.modelRegistry, TestResource(tag: "g2", recorder: recorder))
        global.dispose()
        let reversePass = (recorder.disposed == ["g2", "g1"])

        var idempotentPass = true
        global.dispose()  // inert
        idempotentPass = idempotentPass && (recorder.disposed == ["g2", "g1"])

        // Weak accounting: registry observes release without retaining.
        var weakPass = false
        do {
            let model = MonaCodeModel(text: "z", uri: MonaURI(scheme: "inmemory", path: "/z"))
            initial.register(.implicitOwned, model: model)
            weakPass = (initial.liveCount == 1)
        }
        weakPass = weakPass && (initial.liveCount == 0)

        print("LIFETIME registries=3 reverse=\(reversePass ? "pass" : "fail") idempotent=\(idempotentPass ? "pass" : "fail") weak=\(weakPass ? "pass" : "fail")")

        XCTAssertTrue(reversePass)
        XCTAssertTrue(idempotentPass)
        XCTAssertTrue(weakPass)
    }
}
