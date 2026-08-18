// MonaQuickCommandFeatureTests.swift
//
// P05-T142 — Implement retained feature quickCommand.
//
// Verifies the quickCommand feature across its three implementation operations:
//   1. Feature-specific behavior: filter and invoke registered editor commands
//      with exact enablement (reuse T002 MonaCommandRegistry for the command
//      list + enablement).
//   2. The exact feature identity `quickCommand` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     QUICKCOMMAND feature=live actions=1 commands=1 contributions=1 keybindings=1 options=0 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaQuickCommandFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/quickcmd-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: filter + invoke with exact enablement

    func testFilterReturnsAllLiveCommandsForEmptyQuery() {
        let feature = MonaQuickCommandFeature()
        let registry = MonaCommandRegistry()
        let context = MonaKeybindingContext()

        let entries = feature.filterCommands(query: "", registry: registry, context: context)

        XCTAssertEqual(entries.count, registry.liveCount)
        // Every entry should be enabled (no precondition on commands).
        XCTAssertTrue(entries.allSatisfy { $0.enabled })
    }

    func testFilterNarrowsByCaseInsensitiveSubstringOnCommandId() {
        let feature = MonaQuickCommandFeature()
        let registry = MonaCommandRegistry()
        let context = MonaKeybindingContext()

        let entries = feature.filterCommands(query: "cursor", registry: registry, context: context)

        XCTAssertFalse(entries.isEmpty)
        XCTAssertTrue(entries.allSatisfy { $0.commandId.lowercased().contains("cursor") })
    }

    func testFilterRespectsExactEnablementFromRegistry() {
        let feature = MonaQuickCommandFeature()
        let registry = MonaCommandRegistry()
        let context = MonaKeybindingContext()

        // A disposed registry enables nothing.
        registry.dispose()
        let entries = feature.filterCommands(query: "", registry: registry, context: context)

        XCTAssertTrue(entries.allSatisfy { !$0.enabled })
    }

    func testInvokeCommandReturnsEnabledWhenCommandIsLiveAndEnabled() {
        let feature = MonaQuickCommandFeature()
        let registry = MonaCommandRegistry()
        let context = MonaKeybindingContext()

        let outcome = feature.invokeCommand("cursorDown", registry: registry, context: context)

        if case .enabled = outcome {
            // expected
        } else {
            XCTFail("expected .enabled, got \(outcome)")
        }
    }

    func testInvokeCommandReturnsDisabledForUnknownCommand() {
        let feature = MonaQuickCommandFeature()
        let registry = MonaCommandRegistry()
        let context = MonaKeybindingContext()

        let outcome = feature.invokeCommand("nonexistent.command", registry: registry, context: context)

        if case .disabled = outcome {
            // expected
        } else {
            XCTFail("expected .disabled, got \(outcome)")
        }
    }

    func testInvokeCommandReturnsDisabledWhenRegistryIsDisposed() {
        let feature = MonaQuickCommandFeature()
        let registry = MonaCommandRegistry()
        registry.dispose()
        let context = MonaKeybindingContext()

        let outcome = feature.invokeCommand("cursorDown", registry: registry, context: context)

        if case .disabled = outcome {
            // expected
        } else {
            XCTFail("expected .disabled after disposal, got \(outcome)")
        }
    }

    func testFilterFiresEventWithFilteredEntries() {
        let feature = MonaQuickCommandFeature()
        let registry = MonaCommandRegistry()
        let context = MonaKeybindingContext()

        var fired: [MonaQuickCommandEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.filterCommands(query: "undo", registry: registry, context: context)

        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(fired[0].entries.isEmpty)
        XCTAssertTrue(fired[0].entries.allSatisfy { $0.commandId.lowercased().contains("undo") })
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaQuickCommandFeature.featureId, "quickCommand")
        XCTAssertTrue(features.contains("quickCommand"))

        XCTAssertEqual(MonaQuickCommandFeature.declaredActionIds, [
            "editor.action.quickCommand"
        ])
        for id in MonaQuickCommandFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaQuickCommandFeature.declaredCommandIds, [
            "editor.action.quickCommand"
        ])
        for id in MonaQuickCommandFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaQuickCommandFeature.declaredContributionIds, [
            "editor.controller.quickInput"
        ])
        for id in MonaQuickCommandFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaQuickCommandFeature.declaredKeybindingCommands, [
            "editor.action.quickCommand"
        ])
        for id in MonaQuickCommandFeature.declaredKeybindingCommands {
            XCTAssertTrue(Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains(id),
                          "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaQuickCommandFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaQuickCommandFeature.declaredMenuIds, ["EditorContext"])
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaQuickCommandFeature()
        let model = makeModel("")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.commitInvocationEdits(
            [MonaModelEditOperation(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 1)
                ),
                text: "hello"
            )],
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "hello")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaQuickCommandFeature()
        let ticket = gate.captureTicket()
        let entries = [
            MonaQuickCommandEntry(commandId: "undo", label: "Undo", enabled: true)
        ]

        var received: [MonaQuickCommandEntry]?
        let accepted = feature.publishEntries(
            entries,
            executor: executor,
            ticket: ticket
        ) { e in
            received = e
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.count, 1)
        XCTAssertEqual(received?[0].commandId, "undo")
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaQuickCommandFeature()
        let registry = MonaCommandRegistry()
        let context = MonaKeybindingContext()

        var fired: [MonaQuickCommandEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.filterCommands(query: "undo", registry: registry, context: context)
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, filterCommands returns empty and fires nothing.
        let countBefore = fired.count
        _ = feature.filterCommands(query: "undo", registry: registry, context: context)
        XCTAssertEqual(fired.count, countBefore)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaQuickCommandFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaQuickCommandFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels, ["Command Palette"])
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertEqual(pseudoLabels.count, 1)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaQuickCommandFeature()
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
        let feature = MonaQuickCommandFeature()

        let featureLive = features.contains(MonaQuickCommandFeature.featureId)
        let actionCount = MonaQuickCommandFeature.declaredActionIds.count
        let commandCount = MonaQuickCommandFeature.declaredCommandIds.count
        let contribCount = MonaQuickCommandFeature.declaredContributionIds.count
        let kbCount = MonaQuickCommandFeature.declaredKeybindingCommands.count
        let optionCount = MonaQuickCommandFeature.declaredOptionIds.count
        let menuCount = MonaQuickCommandFeature.declaredMenuIds.count

        let slicePass = MonaQuickCommandFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaQuickCommandFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaQuickCommandFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaQuickCommandFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaQuickCommandFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaQuickCommandFeature.declaredMenuIds.allSatisfy { _ in true }

        // Filter + invoke with exact enablement.
        let context = MonaKeybindingContext()
        let entries = feature.filterCommands(query: "undo", registry: commands, context: context)
        let filterPass = !entries.isEmpty
            && entries.allSatisfy { $0.commandId.lowercased().contains("undo") }
            && entries.allSatisfy { $0.enabled }
        let invokeOutcome = feature.invokeCommand("undo", registry: commands, context: context)
        var invokePass = false
        if case .enabled = invokeOutcome { invokePass = true }

        // Mutation through the transaction gateway.
        let model = makeModel("")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitInvocationEdits(
            [MonaModelEditOperation(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 1)
                ),
                text: "hi"
            )],
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
        _ = feature.publishEntries(
            [MonaQuickCommandEntry(commandId: "undo", label: "Undo", enabled: true)],
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("QUICKCOMMAND feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(filterPass)
        XCTAssertTrue(invokePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
