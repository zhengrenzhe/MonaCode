// MonaGlobalModelRegistryTest.swift
//
// Behavior test for MonaGlobalModelRegistry (MODEL-008 / P01-T012).
//
// Verifies the URI-keyed global model registry's create/register/get-by-uri/
// list/setLanguage/unregister storage and the `onDidChangeModels` change event.
// Also verifies the four retained public editor functions
// (`monaEditorCreateModel`, `monaEditorSetModelLanguage`, `monaEditorGetModel`,
// `monaEditorGetModels`) route through the shared singleton registry.

import XCTest
import MonaCode

final class MonaGlobalModelRegistryTest: XCTestCase {

    // MARK: - Registry direct: register / get by uri / list / unregister

    func testRegistryRegisterGetByUriListAndUnregister() async throws {
        let registry = MonaGlobalModelRegistry()
        let uriA = MonaURI(scheme: "inmemory", path: "/registry-a")
        let uriB = MonaURI(scheme: "inmemory", path: "/registry-b")
        let modelA = MonaCodeModel(text: "alpha", uri: uriA)
        let modelB = MonaCodeModel(text: "beta", uri: uriB)

        // Initially empty.
        XCTAssertEqual(registry.models().count, 0, "a fresh registry holds no models")
        XCTAssertNil(registry.model(for: uriA), "get by uri before register returns nil")

        // Register both.
        registry.register(modelA)
        registry.register(modelB)

        // get by uri returns the exact registered reference.
        XCTAssertTrue(registry.model(for: uriA) === modelA, "get by uri returns the registered model")
        XCTAssertTrue(registry.model(for: uriB) === modelB)
        XCTAssertNil(registry.model(for: MonaURI(scheme: "inmemory", path: "/absent")))

        // list returns every registered model.
        let listed = registry.models()
        XCTAssertEqual(listed.count, 2, "list returns every registered model")
        XCTAssertTrue(listed.contains(where: { $0 === modelA }))
        XCTAssertTrue(listed.contains(where: { $0 === modelB }))

        // unregister removes only the targeted model.
        registry.unregister(modelA)
        XCTAssertNil(registry.model(for: uriA), "unregister removes the model from the uri map")
        XCTAssertTrue(registry.model(for: uriB) === modelB, "unregister leaves other models intact")
        XCTAssertEqual(registry.models().count, 1)

        registry.unregister(modelB)
        XCTAssertEqual(registry.models().count, 0, "unregistering the last model empties the registry")
    }

    func testRegistryRegisterIsIdempotentPerUri() async throws {
        let registry = MonaGlobalModelRegistry()
        let uri = MonaURI(scheme: "inmemory", path: "/registry-idempotent")
        let model = MonaCodeModel(text: "x", uri: uri)

        registry.register(model)
        registry.register(model)  // same uri: replace, not append
        XCTAssertEqual(registry.models().count, 1, "re-registering the same uri must not duplicate")
        XCTAssertTrue(registry.model(for: uri) === model)
    }

    // MARK: - setLanguage

    func testRegistrySetLanguageOverridesLanguageId() async throws {
        let registry = MonaGlobalModelRegistry()
        let uri = MonaURI(scheme: "inmemory", path: "/registry-lang")
        let model = MonaCodeModel(text: "let x = 1", uri: uri)
        registry.register(model)

        // Before setLanguage, the registry reports the model's own language id.
        XCTAssertEqual(
            registry.languageId(for: model),
            model.getLanguageId(),
            "default language id mirrors the model's own")

        registry.setLanguage("swift", for: model)
        XCTAssertEqual(
            registry.languageId(for: model), "swift",
            "setLanguage overrides the registry-tracked language id")

        // setLanguage on an unregistered model is a no-op (the registry does
        // not track language for models it does not own).
        let foreign = MonaCodeModel(
            text: "y", uri: MonaURI(scheme: "inmemory", path: "/registry-lang-foreign"))
        registry.setLanguage("rust", for: foreign)
        XCTAssertEqual(
            registry.languageId(for: foreign), foreign.getLanguageId(),
            "setLanguage on an unregistered model is ignored")
    }

    // MARK: - Change event (MonaEmitter pattern)

    func testRegistryChangeEventFiresOnRegisterUnregisterAndSetLanguage() async throws {
        let registry = MonaGlobalModelRegistry()
        let uri = MonaURI(scheme: "inmemory", path: "/registry-event")
        let model = MonaCodeModel(text: "z", uri: uri)

        var received: [MonaModelRegistryChangeEvent] = []
        let disposable = registry.onDidChangeModels { event in
            received.append(event)
        }
        defer { disposable.dispose() }

        registry.register(model)
        XCTAssertEqual(received.count, 1, "register fires one change event")
        XCTAssertEqual(received[0].kind, .registered)
        XCTAssertEqual(received[0].modelId, model.id)

        registry.setLanguage("swift", for: model)
        XCTAssertEqual(received.count, 2, "setLanguage fires one change event")
        XCTAssertEqual(received[1].kind, .languageChanged)
        XCTAssertEqual(received[1].modelId, model.id)

        registry.unregister(model)
        XCTAssertEqual(received.count, 3, "unregister fires one change event")
        XCTAssertEqual(received[2].kind, .unregistered)
        XCTAssertEqual(received[2].modelId, model.id)
    }

    // MARK: - createModel (monaco editor.createModel counterpart)

    func testRegistryCreateModelRegistersAndReturns() async throws {
        let registry = MonaGlobalModelRegistry()
        let uri = MonaURI(scheme: "inmemory", path: "/registry-create")
        let model = registry.createModel(value: "hello", language: "swift", uri: uri)

        // createModel returns a live model registered under the given uri.
        XCTAssertTrue(registry.model(for: uri) === model, "createModel registers the new model")
        XCTAssertEqual(model.getValue(), "hello")
        XCTAssertEqual(registry.languageId(for: model), "swift", "createModel seeds the language override")

        // createModel without a uri generates one and still registers.
        let generated = registry.createModel(value: "world")
        XCTAssertEqual(registry.models().count, 2, "createModel without a uri registers under a generated uri")
        XCTAssertTrue(registry.models().contains(where: { $0 === generated }))
    }

    // MARK: - Public editor functions route through the shared registry

    func testPublicFunctionsRouteThroughSharedRegistry() async throws {
        let shared = MonaGlobalModelRegistry.shared
        let uri = MonaURI(scheme: "inmemory", path: "/registry-public-route")

        // Clean the shared singleton so this test is hermetic.
        defer {
            for model in shared.models() {
                shared.unregister(model)
            }
        }

        // createModel via the public function routes through .shared.
        let model = try await monaEditorCreateModel(
            value: "public", language: "swift", uri: uri)
        XCTAssertTrue(shared.model(for: uri) === model, "public createModel routes through the shared registry")

        // getModel by uri routes through .shared.
        let got = try await monaEditorGetModel(uri: uri)
        XCTAssertTrue(got === model, "public getModel routes through the shared registry")

        // getModels routes through .shared and includes the created model.
        let listed = try await monaEditorGetModels()
        XCTAssertTrue(listed.contains(where: { $0 === model }), "public getModels routes through the shared registry")

        // setModelLanguage routes through .shared.
        try await monaEditorSetModelLanguage(model: model, languageId: "rust")
        XCTAssertEqual(shared.languageId(for: model), "rust", "public setModelLanguage routes through the shared registry")
    }
}
