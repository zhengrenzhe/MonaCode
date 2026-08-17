// MonaCodeEditorFeatureTests.swift
//
// P05-T105 — Implement retained feature codeEditor.
//
// Verifies the codeEditor feature across its three implementation operations:
//   1. Feature-specific behavior: register the standalone code-editor
//      contribution set + lifecycle hooks.
//   2. The exact feature identity `codeEditor` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce). codeEditor is the host
//      feature that instantiates contributions; it declares no owned
//      actions / commands / contributions itself.
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     CODEEDITOR feature=live actions=0 commands=0 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaCodeEditorFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1\nlet y = 2") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/codeeditor-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: standalone contribution set + lifecycle

    func testStandaloneContributionSetIsVerbatimFromRegistry() {
        let feature = MonaCodeEditorFeature()
        let registry = MonaContributionRegistry()
        let standalone = feature.standaloneContributionIds
        let live = registry.liveIdentities.map { $0.id }
        XCTAssertEqual(standalone, live)
        XCTAssertFalse(standalone.isEmpty)
        // Every standalone contribution id is a live registered contribution.
        for id in standalone {
            XCTAssertTrue(registry.contains(id), "missing contribution \(id)")
        }
    }

    func testCreateEditorAttachesModelAndFiresCreatedLifecycle() {
        let feature = MonaCodeEditorFeature()
        var fired: [MonaCodeEditorLifecyclePhase] = []
        _ = feature.onChange { event in fired.append(event.phase) }

        XCTAssertFalse(feature.isCreated)
        let model = makeModel("hello")
        let attached = feature.createEditor(model: model)
        XCTAssertTrue(feature.isCreated)
        XCTAssertEqual(attached.getValue(), "hello")
        XCTAssertEqual(fired, [.created])
    }

    func testActivateFiresActivatedLifecycle() {
        let feature = MonaCodeEditorFeature()
        var fired: [MonaCodeEditorLifecyclePhase] = []
        _ = feature.onChange { event in fired.append(event.phase) }
        _ = feature.createEditor(model: makeModel("abc"))
        feature.activate()
        XCTAssertEqual(fired, [.created, .activated])
    }

    func testDisposeFiresDisposedLifecycleAndIsIdempotent() {
        let feature = MonaCodeEditorFeature()
        var fired: [MonaCodeEditorLifecyclePhase] = []
        _ = feature.onChange { event in fired.append(event.phase) }
        _ = feature.createEditor(model: makeModel("abc"))
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertEqual(fired, [.created, .disposed])
        // Idempotent.
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertEqual(fired, [.created, .disposed])
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaCodeEditorFeature.featureId, "codeEditor")
        XCTAssertTrue(features.contains("codeEditor"))

        // codeEditor is the host feature; it owns no actions / commands /
        // contributions / options / menus / keybindings directly.
        XCTAssertTrue(MonaCodeEditorFeature.declaredActionIds.isEmpty)
        XCTAssertTrue(MonaCodeEditorFeature.declaredCommandIds.isEmpty)
        XCTAssertTrue(MonaCodeEditorFeature.declaredContributionIds.isEmpty)
        XCTAssertTrue(MonaCodeEditorFeature.declaredKeybindingCommands.isEmpty)
        XCTAssertTrue(MonaCodeEditorFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaCodeEditorFeature.declaredMenuIds.isEmpty)

        // The slice verification is vacuously true: every declared id (none)
        // is in the corresponding registry.
        let slicePass = MonaCodeEditorFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaCodeEditorFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaCodeEditorFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaCodeEditorFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }
        XCTAssertTrue(slicePass)
    }

    // MARK: - 3. Routing through shared gateways

    func testModelMutationRoutesThroughTransactionGateway() {
        let feature = MonaCodeEditorFeature()
        let model = makeModel("hello")
        _ = feature.createEditor(model: model)
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitEdit(
            gateway: gateway,
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 4)
            ),
            text: "HEL"
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "HELlo")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaCodeEditorFeature()
        let ticket = gate.captureTicket()

        var received: MonaCodeEditorLifecyclePhase?
        let accepted = feature.publishLifecycle(
            .created,
            executor: executor,
            ticket: ticket
        ) { phase in
            received = phase
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received == nil)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, .created)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitter() {
        let feature = MonaCodeEditorFeature()
        var fired: [MonaCodeEditorLifecyclePhase] = []
        _ = feature.onChange { event in fired.append(event.phase) }
        _ = feature.createEditor(model: makeModel("abc"))
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertEqual(fired.last, .disposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaCodeEditorFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaCodeEditorFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaCodeEditorFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testContractBehavior() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let feature = MonaCodeEditorFeature()

        let featureLive = features.contains(MonaCodeEditorFeature.featureId)
        let actionCount = MonaCodeEditorFeature.declaredActionIds.count
        let commandCount = MonaCodeEditorFeature.declaredCommandIds.count
        let contribCount = MonaCodeEditorFeature.declaredContributionIds.count
        let kbCount = MonaCodeEditorFeature.declaredKeybindingCommands.count
        let optionCount = MonaCodeEditorFeature.declaredOptionIds.count
        let menuCount = MonaCodeEditorFeature.declaredMenuIds.count

        let slicePass = MonaCodeEditorFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaCodeEditorFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaCodeEditorFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaCodeEditorFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: commit a model edit through the editor's transaction gateway.
        let model = makeModel("hello")
        _ = feature.createEditor(model: model)
        let gateway = MonaTransactionGateway(model: model)
        let mutationOutcome = feature.commitEdit(
            gateway: gateway,
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 4)
            ),
            text: "HEL"
        )
        let mutation: Bool
        if case .applied = mutationOutcome, model.getValue() == "HELlo" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishLifecycle(.created, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("CODEEDITOR feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
