// MonaLongLinesHelperFeatureTests.swift
//
// P05-T137 — Implement retained feature longLinesHelper.
//
// Verifies the longLinesHelper feature across its three implementation
// operations:
//   1. Feature-specific behavior: enforce the configured long-line rendering
//      cutoff and explicit unlimited mode (reading the
//      `longLinesHintThreshold` / `renderLongLineSelection` options via T005
//      `MonaOptionStore`).
//   2. The exact feature identity `longLinesHelper` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testLongLinesHelperContractLeaf` prints the contract line:
//     LONGLINESHELPER feature=live actions=0 commands=0 contributions=1 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import Foundation
@testable import MonaCode

final class MonaLongLinesHelperFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "short\n" + String(repeating: "x", count: 50) + "\nanother") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/longlines-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: enforce cutoff + explicit unlimited

    func testReadLongLinesOptionsDefaultsToUnlimitedWhenAbsent() {
        // longLinesHintThreshold / renderLongLineSelection are not registered
        // in the F1-R3 option store (they are runtime-read options that may
        // be absent in the Foundation-only Core). When absent, the store
        // returns nil, so the feature defaults to unlimited mode with
        // renderLongLineSelection = true.
        let feature = MonaLongLinesHelperFeature()
        let store = MonaOptionStore()
        let options = feature.readLongLinesOptions(from: store)
        XCTAssertNil(options.threshold)
        XCTAssertTrue(options.renderLongLineSelection)
    }

    func testEnforceLongLinesUnlimitedWhenNoThreshold() {
        let feature = MonaLongLinesHelperFeature()
        let model = makeModel()
        let options = MonaLongLinesOptions(threshold: nil, renderLongLineSelection: true)
        let enforcement = feature.enforceLongLines(
            model: model,
            options: options,
            explicitUnlimited: false
        )
        XCTAssertTrue(enforcement.unlimited)
        XCTAssertNil(enforcement.threshold)
        XCTAssertTrue(enforcement.longLineNumbers.isEmpty)
    }

    func testEnforceLongLinesFlagsLinesExceedingThreshold() {
        let feature = MonaLongLinesHelperFeature()
        // line 1 = 5 chars, line 2 = 50 chars, line 3 = 7 chars.
        let model = makeModel()
        let options = MonaLongLinesOptions(threshold: 20, renderLongLineSelection: true)
        let enforcement = feature.enforceLongLines(
            model: model,
            options: options,
            explicitUnlimited: false
        )
        XCTAssertFalse(enforcement.unlimited)
        XCTAssertEqual(enforcement.threshold, 20)
        XCTAssertEqual(enforcement.longLineNumbers, [2])
        XCTAssertTrue(enforcement.rendersLongLineSelection)
    }

    func testEnforceLongLinesFlagsMultipleLongLines() {
        let feature = MonaLongLinesHelperFeature()
        let model = makeModel(String(repeating: "x", count: 30) + "\n"
            + String(repeating: "x", count: 10) + "\n"
            + String(repeating: "x", count: 40))
        let options = MonaLongLinesOptions(threshold: 20, renderLongLineSelection: false)
        let enforcement = feature.enforceLongLines(
            model: model,
            options: options,
            explicitUnlimited: false
        )
        XCTAssertFalse(enforcement.unlimited)
        XCTAssertEqual(enforcement.longLineNumbers, [1, 3])
        XCTAssertFalse(enforcement.rendersLongLineSelection)
    }

    func testEnforceLongLinesExplicitUnlimitedOverridesConfiguredThreshold() {
        let feature = MonaLongLinesHelperFeature()
        let model = makeModel()
        // A configured cutoff exists...
        let options = MonaLongLinesOptions(threshold: 20, renderLongLineSelection: true)
        // ...but explicit unlimited mode overrides it.
        feature.setExplicitUnlimited(true)
        let enforcement = feature.enforceLongLines(
            model: model,
            options: options,
            explicitUnlimited: true
        )
        XCTAssertTrue(enforcement.unlimited)
        XCTAssertTrue(enforcement.longLineNumbers.isEmpty)
    }

    func testEnforceLongLinesZeroThresholdIsUnlimited() {
        let feature = MonaLongLinesHelperFeature()
        let model = makeModel()
        let options = MonaLongLinesOptions(threshold: 0, renderLongLineSelection: true)
        let enforcement = feature.enforceLongLines(
            model: model,
            options: options,
            explicitUnlimited: false
        )
        XCTAssertTrue(enforcement.unlimited)
    }

    func testEnforceLongLinesStagesEnforcementAndFiresEvent() {
        let feature = MonaLongLinesHelperFeature()
        var fired: [MonaLongLinesEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let model = makeModel()
        let options = MonaLongLinesOptions(threshold: 20, renderLongLineSelection: true)
        _ = feature.enforceLongLines(model: model, options: options, explicitUnlimited: false)
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.kind, .enforced)
        XCTAssertEqual(fired.first?.enforcement.longLineNumbers, [2])
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaLongLinesHelperFeature.featureId, "longLinesHelper")
        XCTAssertTrue(features.contains("longLinesHelper"))

        // longLinesHelper declares a single contribution and no commands,
        // actions, options, menus, or keybindings.
        XCTAssertEqual(MonaLongLinesHelperFeature.declaredActionIds, [])
        for id in MonaLongLinesHelperFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaLongLinesHelperFeature.declaredCommandIds, [])
        for id in MonaLongLinesHelperFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaLongLinesHelperFeature.declaredContributionIds, ["editor.contrib.longLinesHelper"])
        for id in MonaLongLinesHelperFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaLongLinesHelperFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaLongLinesHelperFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaLongLinesHelperFeature.declaredMenuIds, [])
        for id in MonaLongLinesHelperFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaLongLinesHelperFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let options = MonaLongLinesOptions(threshold: 20, renderLongLineSelection: true)
        let enforcement = feature.enforceLongLines(model: model, options: options, explicitUnlimited: false)

        let committed = feature.commitRevealFirstLongLine(gateway: gateway, enforcement: enforcement)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testMutationWithNoLongLinesCommitsNothing() {
        let feature = MonaLongLinesHelperFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let enforcement = MonaLongLinesEnforcement(
            unlimited: true, threshold: nil, longLineNumbers: [], rendersLongLineSelection: true
        )

        let committed = feature.commitRevealFirstLongLine(gateway: gateway, enforcement: enforcement)
        XCTAssertTrue(committed.isEmpty)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaLongLinesHelperFeature()
        let ticket = gate.captureTicket()
        let enforcement = MonaLongLinesEnforcement(
            unlimited: false, threshold: 20, longLineNumbers: [2], rendersLongLineSelection: true
        )

        var received: MonaLongLinesEnforcement?
        let accepted = feature.publishLongLinesEnforcement(
            enforcement,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, enforcement)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaLongLinesHelperFeature()
        var fired: [MonaLongLinesEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, enforce / commitReveal / publish are no-ops.
        let model = makeModel()
        let store = MonaOptionStore()
        _ = feature.readLongLinesOptions(from: store)
        let enforcement = feature.enforceLongLines(
            model: model,
            options: MonaLongLinesOptions(threshold: 20, renderLongLineSelection: true),
            explicitUnlimited: false
        )
        XCTAssertTrue(enforcement.longLineNumbers.isEmpty)
        let gateway = MonaTransactionGateway(model: model)
        XCTAssertTrue(feature.commitRevealFirstLongLine(gateway: gateway, enforcement: enforcement).isEmpty)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaLongLinesHelperFeature()
        // longLinesHelper declares no actions, so localized labels are empty
        // under every profile — but the path still routes through
        // MonaLocalization.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaLongLinesHelperFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaLongLinesHelperFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testLongLinesHelperContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let feature = MonaLongLinesHelperFeature()

        let featureLive = features.contains(MonaLongLinesHelperFeature.featureId)
        let actionCount = MonaLongLinesHelperFeature.declaredActionIds.count
        let commandCount = MonaLongLinesHelperFeature.declaredCommandIds.count
        let contribCount = MonaLongLinesHelperFeature.declaredContributionIds.count
        let kbCount = MonaLongLinesHelperFeature.declaredKeybindingCommands.count
        let optionCount = MonaLongLinesHelperFeature.declaredOptionIds.count
        let menuCount = MonaLongLinesHelperFeature.declaredMenuIds.count

        let slicePass = MonaLongLinesHelperFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaLongLinesHelperFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaLongLinesHelperFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaLongLinesHelperFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaLongLinesHelperFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Read options via the option store (returns nil → unlimited default).
        let store = MonaOptionStore()
        let readOptions = feature.readLongLinesOptions(from: store)
        let readPass = readOptions.threshold == nil && readOptions.renderLongLineSelection == true

        // Enforce a configured cutoff: line 2 (50 chars) exceeds threshold 20.
        let model = makeModel()
        let options = MonaLongLinesOptions(threshold: 20, renderLongLineSelection: true)
        let enforcement = feature.enforceLongLines(model: model, options: options, explicitUnlimited: false)
        let enforcePass = !enforcement.unlimited && enforcement.longLineNumbers == [2]

        // Explicit unlimited overrides the configured cutoff.
        feature.setExplicitUnlimited(true)
        let unlimitedEnforcement = feature.enforceLongLines(model: model, options: options, explicitUnlimited: true)
        let unlimitedPass = unlimitedEnforcement.unlimited && unlimitedEnforcement.longLineNumbers.isEmpty

        // Mutation: reveal the first long line through the gateway.
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitRevealFirstLongLine(gateway: gateway, enforcement: enforcement).count == 1
            && gateway.lastCommittedSelections.count == 1

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishLongLinesEnforcement(enforcement, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("LONGLINESHELPER feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(readPass)
        XCTAssertTrue(enforcePass)
        XCTAssertTrue(unlimitedPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
