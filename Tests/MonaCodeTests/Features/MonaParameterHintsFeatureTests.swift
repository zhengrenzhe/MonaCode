// MonaParameterHintsFeatureTests.swift
//
// P05-T140 — Implement retained feature parameterHints.
//
// Verifies the parameterHints feature across its three implementation operations:
//   1. Feature-specific behavior: trigger, cycle, update, and dismiss
//      signature-help results (reuse `MonaProviderExecutor` P05-T013).
//   2. The exact feature identity `parameterHints` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     PARAMETERHINTS feature=live actions=1 commands=4 contributions=1 keybindings=4 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaParameterHintsFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "min(1, 2)") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/parameterhints-\(UUID().uuidString)")
        )
    }

    private func sampleResult() -> MonaParameterHintsResult {
        return MonaParameterHintsResult(
            signatures: [
                MonaParameterHintSignature(
                    label: "min(a: number, b: number): number",
                    parameters: [
                        MonaParameterHintParameter(label: "a: number", documentation: "the first value"),
                        MonaParameterHintParameter(label: "b: number", documentation: "the second value")
                    ],
                    documentation: "Return the lesser of two numbers.",
                    activeParameter: 0
                ),
                MonaParameterHintSignature(
                    label: "min(values: number[]): number",
                    parameters: [
                        MonaParameterHintParameter(label: "values: number[]", documentation: "the values to compare")
                    ],
                    documentation: "Return the least of many values.",
                    activeParameter: 0
                )
            ],
            activeSignature: 0,
            activeParameter: 0
        )
    }

    // MARK: - 1. Feature-specific behavior: trigger / cycle / update / dismiss

    func testTriggerShowsFirstSignatureAndFiresEvent() {
        let feature = MonaParameterHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        var fired: [MonaParameterHintsEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let result = feature.triggerParameterHints(sampleResult(), modelVersion: version)

        XCTAssertNotNil(result)
        XCTAssertTrue(feature.isVisible)
        XCTAssertEqual(feature.activeSignature, 0)
        XCTAssertEqual(feature.activeParameter, 0)
        XCTAssertEqual(feature.currentResult?.signatures.count, 2)
        XCTAssertEqual(fired.count, 1)
        XCTAssertTrue(fired[0].visible)
    }

    func testTriggerWithNoSignaturesIsDismissed() {
        let feature = MonaParameterHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()

        let empty = MonaParameterHintsResult(signatures: [], activeSignature: 0, activeParameter: 0)
        let result = feature.triggerParameterHints(empty, modelVersion: version)

        XCTAssertNil(result)
        XCTAssertFalse(feature.isVisible)
    }

    func testCycleNextAdvancesSignatureWithWrap() {
        let feature = MonaParameterHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.triggerParameterHints(sampleResult(), modelVersion: version)

        // 0 → 1
        let r1 = feature.cycleNextHint()
        XCTAssertEqual(feature.activeSignature, 1)
        XCTAssertEqual(r1?.activeSignature, 1)
        // 1 → 0 (wrap)
        _ = feature.cycleNextHint()
        XCTAssertEqual(feature.activeSignature, 0)
    }

    func testCyclePreviousDecrementsSignatureWithWrap() {
        let feature = MonaParameterHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.triggerParameterHints(sampleResult(), modelVersion: version)

        // 0 → 1 (wrap backward)
        _ = feature.cyclePreviousHint()
        XCTAssertEqual(feature.activeSignature, 1)
        // 1 → 0
        _ = feature.cyclePreviousHint()
        XCTAssertEqual(feature.activeSignature, 0)
    }

    func testUpdateSetsActiveSignatureAndParameter() {
        let feature = MonaParameterHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.triggerParameterHints(sampleResult(), modelVersion: version)

        let updated = feature.updateActiveHint(activeSignature: 1, activeParameter: 0)
        XCTAssertEqual(updated?.activeSignature, 1)
        XCTAssertEqual(updated?.activeParameter, 0)
        XCTAssertEqual(feature.activeSignature, 1)
        XCTAssertEqual(feature.activeParameter, 0)
    }

    func testUpdateClampsActiveSignatureToBounds() {
        let feature = MonaParameterHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.triggerParameterHints(sampleResult(), modelVersion: version)

        // Out-of-range signature clamps to the last valid index.
        let updated = feature.updateActiveHint(activeSignature: 99, activeParameter: 0)
        XCTAssertEqual(updated?.activeSignature, 1)
        XCTAssertEqual(feature.activeSignature, 1)
    }

    func testCycleWhenNotVisibleIsNoOp() {
        let feature = MonaParameterHintsFeature()
        XCTAssertFalse(feature.isVisible)
        let result = feature.cycleNextHint()
        XCTAssertNil(result)
        XCTAssertEqual(feature.activeSignature, 0)
    }

    func testDismissHidesAndClearsResult() {
        let feature = MonaParameterHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.triggerParameterHints(sampleResult(), modelVersion: version)
        XCTAssertTrue(feature.isVisible)

        var fired: [MonaParameterHintsEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let dismissed = feature.dismissParameterHints()
        XCTAssertTrue(dismissed)
        XCTAssertFalse(feature.isVisible)
        XCTAssertNil(feature.currentResult)
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(fired[0].visible)
    }

    func testDismissWhenNotVisibleIsNoOp() {
        let feature = MonaParameterHintsFeature()
        let dismissed = feature.dismissParameterHints()
        XCTAssertFalse(dismissed)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaParameterHintsFeature.featureId, "parameterHints")
        XCTAssertTrue(features.contains("parameterHints"))

        XCTAssertEqual(MonaParameterHintsFeature.declaredActionIds, [
            "editor.action.triggerParameterHints"
        ])
        for id in MonaParameterHintsFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaParameterHintsFeature.declaredCommandIds, [
            "closeParameterHints",
            "editor.action.triggerParameterHints",
            "showNextParameterHint",
            "showPrevParameterHint"
        ])
        for id in MonaParameterHintsFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaParameterHintsFeature.declaredContributionIds, [
            "editor.controller.parameterHints"
        ])
        for id in MonaParameterHintsFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaParameterHintsFeature.declaredKeybindingCommands, [
            "editor.action.triggerParameterHints",
            "closeParameterHints",
            "showNextParameterHint",
            "showPrevParameterHint"
        ])
        let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaParameterHintsFeature.declaredKeybindingCommands {
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaParameterHintsFeature.declaredOptionIds, [
            "parameterHints"
        ])
        for id in MonaParameterHintsFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaParameterHintsFeature.declaredMenuIds, [])
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaParameterHintsFeature()
        let model = makeModel("min()") // empty arg list; insert 'a' at col 5.
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        _ = feature.triggerParameterHints(sampleResult(), modelVersion: version)

        // Insert the active parameter's label at the caret (col 5, inside "()").
        let outcome = feature.commitParameterEdit(
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 5),
                endPosition: MonaPosition(line: 1, column: 5)
            ),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "min(a: number)")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaParameterHintsFeature()
        let ticket = gate.captureTicket()

        var received: MonaParameterHintsResult?
        let accepted = feature.publishParameterHints(
            sampleResult(),
            executor: executor,
            ticket: ticket
        ) { result in
            received = result
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.signatures.count, 2)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaParameterHintsFeature()
        var fired: [MonaParameterHintsEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let model = makeModel()
        _ = feature.triggerParameterHints(sampleResult(), modelVersion: model.getVersionId())
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, trigger / cycle / dismiss are no-ops and fire no events.
        let countBefore = fired.count
        _ = feature.triggerParameterHints(sampleResult(), modelVersion: model.getVersionId())
        XCTAssertFalse(feature.isVisible)
        _ = feature.cycleNextHint()
        _ = feature.dismissParameterHints()
        XCTAssertEqual(fired.count, countBefore)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaParameterHintsFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaParameterHintsFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels.first, "Trigger Parameter Hints")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertEqual(pseudoLabels.count, MonaParameterHintsFeature.declaredActionIds.count)
        XCTAssertEqual(pseudoLabels.first?.hasPrefix("\u{FF3B}"), true)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaParameterHintsFeature()
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
        let options = MonaOptionStore()
        let feature = MonaParameterHintsFeature()

        let featureLive = features.contains(MonaParameterHintsFeature.featureId)
        let actionCount = MonaParameterHintsFeature.declaredActionIds.count
        let commandCount = MonaParameterHintsFeature.declaredCommandIds.count
        let contribCount = MonaParameterHintsFeature.declaredContributionIds.count
        let kbCount = MonaParameterHintsFeature.declaredKeybindingCommands.count
        let optionCount = MonaParameterHintsFeature.declaredOptionIds.count
        let menuCount = MonaParameterHintsFeature.declaredMenuIds.count

        let slicePass = MonaParameterHintsFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaParameterHintsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaParameterHintsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaParameterHintsFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaParameterHintsFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaParameterHintsFeature.declaredMenuIds.allSatisfy { _ in true }

        // Trigger + cycle + update + dismiss.
        let model = makeModel("min()")
        let version = model.getVersionId()
        let triggered = feature.triggerParameterHints(sampleResult(), modelVersion: version)
        let triggerPass = triggered != nil && feature.isVisible && feature.activeSignature == 0

        _ = feature.cycleNextHint()
        let cycleNextPass = feature.activeSignature == 1
        _ = feature.cyclePreviousHint()
        let cyclePrevPass = feature.activeSignature == 0

        _ = feature.updateActiveHint(activeSignature: 1, activeParameter: 0)
        let updatePass = feature.activeSignature == 1

        // Mutation: commit the active parameter's label through the gateway.
        var mutation = false
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitParameterEdit(
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 5),
                endPosition: MonaPosition(line: 1, column: 5)
            ),
            gateway: gateway
        )
        if case .applied = outcome, model.getValue() == "min(values: number[])" {
            mutation = true
        }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishParameterHints(
            sampleResult(),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        let dismissed = feature.dismissParameterHints()
        let dismissPass = dismissed && !feature.isVisible

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("PARAMETERHINTS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(triggerPass)
        XCTAssertTrue(cycleNextPass)
        XCTAssertTrue(cyclePrevPass)
        XCTAssertTrue(updatePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(dismissPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
