// MonaReadOnlyMessageFeatureTests.swift
//
// P05-T145 — Implement retained feature readOnlyMessage.
//
// Verifies the readOnlyMessage feature across its three implementation operations:
//   1. Feature-specific behavior: present explicit localized feedback for
//      rejected read-only mutations (reuse T007 `MonaLocalization` + the
//      read-only rejection from the model/editability check via the `readOnly`
//      editor option).
//   2. The exact feature identity `readOnlyMessage` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     READONLYMESSAGE feature=live actions=0 commands=0 contributions=1 keybindings=0 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaReadOnlyMessageFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/readonly-\(UUID().uuidString)")
        )
    }

    private func readOnlyStore() -> MonaOptionStore {
        let store = MonaOptionStore()
        _ = store.setValue(.bool(true), for: "readOnly")
        return store
    }

    // MARK: - 1. Feature-specific behavior: present localized read-only feedback

    func testEvaluateReadOnlyReadsReadOnlyOption() {
        let feature = MonaReadOnlyMessageFeature()

        let editable = MonaOptionStore()
        XCTAssertFalse(feature.evaluateReadOnly(using: editable))

        let readonly = readOnlyStore()
        XCTAssertTrue(feature.evaluateReadOnly(using: readonly))
    }

    func testMessageUsesCustomReadOnlyMessageWhenSet() {
        let feature = MonaReadOnlyMessageFeature()
        let store = MonaOptionStore()
        // readOnlyMessage is a MarkdownString object carrying a `value` string.
        _ = store.setValue(.object(["value": .string("Cannot edit this file")]), for: "readOnlyMessage")

        let message = feature.message(for: store, profile: .default)
        XCTAssertEqual(message, "Cannot edit this file")
    }

    func testMessageFallsBackToDefaultLocalizedReadOnlyMessage() {
        let feature = MonaReadOnlyMessageFeature()
        let store = MonaOptionStore()

        // No custom readOnlyMessage → the default localized message.
        let message = feature.message(for: store, profile: .default)
        XCTAssertEqual(message, "Cannot edit in read-only editor")
    }

    func testMessageAppliesPseudoTransformUnderPseudoProfile() {
        let feature = MonaReadOnlyMessageFeature()
        let store = MonaOptionStore()

        let pseudo = feature.message(for: store, profile: .custom("pseudo"))
        // Pseudo wraps in fullwidth brackets and doubles vowels.
        XCTAssertTrue(pseudo.hasPrefix("\u{FF3B}"))
    }

    func testPresentationVisibleOnlyWhenReadOnly() {
        let feature = MonaReadOnlyMessageFeature()

        let editable = MonaOptionStore()
        let editablePres = feature.presentation(for: editable, profile: .default)
        XCTAssertFalse(editablePres.visible)

        let readonly = readOnlyStore()
        let readonlyPres = feature.presentation(for: readonly, profile: .default)
        XCTAssertTrue(readonlyPres.visible)
        XCTAssertEqual(readonlyPres.message, "Cannot edit in read-only editor")
        XCTAssertFalse(readonlyPres.attributedString.string.isEmpty)
    }

    func testPresentRejectedMutationFiresEventWhenReadOnly() {
        let feature = MonaReadOnlyMessageFeature()
        let readonly = readOnlyStore()
        var fired: [MonaReadOnlyMessageEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let presented = feature.presentRejectedMutation(using: readonly, profile: .default)
        XCTAssertTrue(presented)
        XCTAssertEqual(fired.count, 1)
        XCTAssertTrue(fired[0].presentation.visible)
    }

    func testPresentRejectedMutationIsNoOpWhenEditable() {
        let feature = MonaReadOnlyMessageFeature()
        let editable = MonaOptionStore()
        var fired: [MonaReadOnlyMessageEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let presented = feature.presentRejectedMutation(using: editable, profile: .default)
        XCTAssertFalse(presented)
        XCTAssertEqual(fired.count, 0)
    }

    func testCommitInputRejectedWhenReadOnlyAndPresentsMessage() {
        let feature = MonaReadOnlyMessageFeature()
        let model = makeModel("let x = 1")
        let gateway = MonaTransactionGateway(model: model)
        let readonly = readOnlyStore()
        var fired: [MonaReadOnlyMessageEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let outcome = feature.commitInput(
            text: "let y = 2",
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 1)
            ),
            gateway: gateway,
            options: readonly,
            profile: .default
        )
        if case .dropped = outcome {
            // expected: read-only rejection drops the mutation.
        } else {
            XCTFail("expected dropped, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "let x = 1")
        XCTAssertEqual(fired.count, 1)
        XCTAssertTrue(fired[0].presentation.visible)
    }

    func testCommitInputAppliedWhenEditable() {
        let feature = MonaReadOnlyMessageFeature()
        let model = makeModel("ab")
        let gateway = MonaTransactionGateway(model: model)
        let editable = MonaOptionStore()

        let outcome = feature.commitInput(
            text: "c",
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 3),
                endPosition: MonaPosition(line: 1, column: 3)
            ),
            gateway: gateway,
            options: editable,
            profile: .default
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "abc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaReadOnlyMessageFeature.featureId, "readOnlyMessage")
        XCTAssertTrue(features.contains("readOnlyMessage"))

        XCTAssertEqual(MonaReadOnlyMessageFeature.declaredActionIds, [])
        for id in MonaReadOnlyMessageFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaReadOnlyMessageFeature.declaredCommandIds, [])
        for id in MonaReadOnlyMessageFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaReadOnlyMessageFeature.declaredContributionIds, [
            "editor.contrib.readOnlyMessageController"
        ])
        for id in MonaReadOnlyMessageFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaReadOnlyMessageFeature.declaredKeybindingCommands, [])
        let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaReadOnlyMessageFeature.declaredKeybindingCommands {
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaReadOnlyMessageFeature.declaredOptionIds, [
            "readOnlyMessage"
        ])
        for id in MonaReadOnlyMessageFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaReadOnlyMessageFeature.declaredMenuIds, [])
        for id in MonaReadOnlyMessageFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaReadOnlyMessageFeature()
        let readonly = readOnlyStore()
        let ticket = gate.captureTicket()

        var received: MonaReadOnlyMessagePresentation?
        let accepted = feature.publishReadOnlyMessage(
            feature.presentation(for: readonly, profile: .default),
            executor: executor,
            ticket: ticket
        ) { presentation in
            received = presentation
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertTrue(received?.visible ?? false)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaReadOnlyMessageFeature()
        var fired: [MonaReadOnlyMessageEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let readonly = readOnlyStore()
        _ = feature.presentRejectedMutation(using: readonly, profile: .default)
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, present is a no-op and fires no events.
        let countBefore = fired.count
        _ = feature.presentRejectedMutation(using: readonly, profile: .default)
        XCTAssertEqual(fired.count, countBefore)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaReadOnlyMessageFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaReadOnlyMessageFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)

        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaReadOnlyMessageFeature()
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
        let menus = MonaMenuRegistry()
        let feature = MonaReadOnlyMessageFeature()

        let featureLive = features.contains(MonaReadOnlyMessageFeature.featureId)
        let actionCount = MonaReadOnlyMessageFeature.declaredActionIds.count
        let commandCount = MonaReadOnlyMessageFeature.declaredCommandIds.count
        let contribCount = MonaReadOnlyMessageFeature.declaredContributionIds.count
        let kbCount = MonaReadOnlyMessageFeature.declaredKeybindingCommands.count
        let optionCount = MonaReadOnlyMessageFeature.declaredOptionIds.count
        let menuCount = MonaReadOnlyMessageFeature.declaredMenuIds.count

        let slicePass = MonaReadOnlyMessageFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaReadOnlyMessageFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaReadOnlyMessageFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaReadOnlyMessageFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaReadOnlyMessageFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaReadOnlyMessageFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Editability check + presentation.
        let readonly = readOnlyStore()
        let editable = MonaOptionStore()
        let evaluatePass = feature.evaluateReadOnly(using: readonly)
            && !feature.evaluateReadOnly(using: editable)
        let messagePass = feature.message(for: readonly, profile: .default) == "Cannot edit in read-only editor"

        // Mutation: read-only rejection drops the mutation and presents a message.
        var mutation = false
        let model = makeModel("let x = 1")
        let gateway = MonaTransactionGateway(model: model)
        var rejected = false
        _ = feature.onChange { _ in rejected = true }
        let outcome = feature.commitInput(
            text: "let y = 2",
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 1)
            ),
            gateway: gateway,
            options: readonly,
            profile: .default
        )
        if case .dropped = outcome, model.getValue() == "let x = 1", rejected {
            mutation = true
        }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishReadOnlyMessage(
            feature.presentation(for: readonly, profile: .default),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        let presented = feature.presentRejectedMutation(using: readonly, profile: .default)
        let presentPass = presented

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("READONLYMESSAGE feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(evaluatePass)
        XCTAssertTrue(messagePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(presentPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
