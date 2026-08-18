// MonaQuickHelpFeatureTests.swift
//
// P05-T143 — Implement retained feature quickHelp.
//
// Verifies the quickHelp feature across its three implementation operations:
//   1. Feature-specific behavior: present retained keyboard and accessibility
//      help from localized messages (reuse T007 MonaLocalization + T003
//      keybindings for the keyboard help).
//   2. The exact feature identity `quickHelp` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     QUICKHELP feature=live actions=0 commands=0 contributions=1 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaQuickHelpFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/quickhelp-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: keyboard + accessibility help

    func testKeyboardHelpReturnsEntriesFromBuiltinKeybindings() {
        let feature = MonaQuickHelpFeature()

        let entries = feature.keyboardHelp(profile: .default)

        XCTAssertEqual(entries.count, MonaBuiltinKeybindings.rows.count)
    }

    func testKeyboardHelpEntryCarriesCommandKeyLabelAndWhen() {
        let feature = MonaQuickHelpFeature()

        let entries = feature.keyboardHelp(profile: .default)

        // The F1 keybinding for editor.action.quickCommand should be present.
        let cmdEntry = entries.first { $0.command == "editor.action.quickCommand" }
        XCTAssertNotNil(cmdEntry)
        XCTAssertFalse(cmdEntry?.keyLabel.isEmpty ?? true)
    }

    func testKeyboardHelpFiresEventWithEntries() {
        let feature = MonaQuickHelpFeature()

        var fired: [MonaQuickHelpEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.keyboardHelp(profile: .default)

        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired[0].presentation.keyboardEntries.count, MonaBuiltinKeybindings.rows.count)
    }

    func testAccessibilityHelpReturnsLocalizedMessage() {
        let feature = MonaQuickHelpFeature()

        let enHelp = feature.accessibilityHelp(profile: .default)
        XCTAssertFalse(enHelp.isEmpty)

        // The pseudo profile transforms the message (fullwidth brackets).
        let pseudoHelp = feature.accessibilityHelp(profile: .custom("pseudo"))
        XCTAssertFalse(pseudoHelp.isEmpty)
        XCTAssertNotEqual(enHelp, pseudoHelp)
    }

    func testPresentHelpCombinesKeyboardAndAccessibility() {
        let feature = MonaQuickHelpFeature()

        let presentation = feature.presentHelp(profile: .default)

        XCTAssertEqual(presentation.keyboardEntries.count, MonaBuiltinKeybindings.rows.count)
        XCTAssertFalse(presentation.accessibilityMessage.isEmpty)
    }

    func testKeyboardHelpReturnsEmptyAfterDisposal() {
        let feature = MonaQuickHelpFeature()
        feature.dispose()

        let entries = feature.keyboardHelp(profile: .default)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaQuickHelpFeature.featureId, "quickHelp")
        XCTAssertTrue(features.contains("quickHelp"))

        XCTAssertEqual(MonaQuickHelpFeature.declaredActionIds, [])
        for id in MonaQuickHelpFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaQuickHelpFeature.declaredCommandIds, [])
        for id in MonaQuickHelpFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaQuickHelpFeature.declaredContributionIds, [
            "editor.controller.quickInput"
        ])
        for id in MonaQuickHelpFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaQuickHelpFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaQuickHelpFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaQuickHelpFeature.declaredMenuIds, [])
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaQuickHelpFeature()
        let model = makeModel("")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.commitHelpText(
            "help text",
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 1)
            ),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "help text")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaQuickHelpFeature()
        let ticket = gate.captureTicket()
        let presentation = feature.presentHelp(profile: .default)

        var received: MonaQuickHelpPresentation?
        let accepted = feature.publishHelp(
            presentation,
            executor: executor,
            ticket: ticket
        ) { p in
            received = p
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.keyboardEntries.count, presentation.keyboardEntries.count)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaQuickHelpFeature()

        var fired: [MonaQuickHelpEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.keyboardHelp(profile: .default)
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        let countBefore = fired.count
        _ = feature.keyboardHelp(profile: .default)
        XCTAssertEqual(fired.count, countBefore)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaQuickHelpFeature()
        // quickHelp declares no actions, so localized labels are empty under
        // every profile — but the path still routes through MonaLocalization.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaQuickHelpFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaQuickHelpFeature()
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
        let feature = MonaQuickHelpFeature()

        let featureLive = features.contains(MonaQuickHelpFeature.featureId)
        let actionCount = MonaQuickHelpFeature.declaredActionIds.count
        let commandCount = MonaQuickHelpFeature.declaredCommandIds.count
        let contribCount = MonaQuickHelpFeature.declaredContributionIds.count
        let kbCount = MonaQuickHelpFeature.declaredKeybindingCommands.count
        let optionCount = MonaQuickHelpFeature.declaredOptionIds.count
        let menuCount = MonaQuickHelpFeature.declaredMenuIds.count

        let slicePass = MonaQuickHelpFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaQuickHelpFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaQuickHelpFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaQuickHelpFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaQuickHelpFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaQuickHelpFeature.declaredMenuIds.allSatisfy { _ in true }

        // Keyboard + accessibility help from localized messages.
        let keyboardEntries = feature.keyboardHelp(profile: .default)
        let keyboardPass = keyboardEntries.count == MonaBuiltinKeybindings.rows.count
            && keyboardEntries.contains { $0.command == "editor.action.quickCommand" }
        let accessibilityHelp = feature.accessibilityHelp(profile: .default)
        let accessibilityPass = !accessibilityHelp.isEmpty

        // Mutation through the transaction gateway.
        let model = makeModel("")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitHelpText(
            "hi",
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 1)
            ),
            gateway: gateway
        )
        var mutation = false
        if case .applied = outcome, model.getValue() == "hi" {
            mutation = true
        }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishHelp(
            feature.presentHelp(profile: .default),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("QUICKHELP feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(keyboardPass)
        XCTAssertTrue(accessibilityPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
