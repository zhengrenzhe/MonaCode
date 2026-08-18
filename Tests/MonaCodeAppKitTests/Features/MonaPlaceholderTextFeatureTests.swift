// MonaPlaceholderTextFeatureTests.swift
//
// P05-T141 — Implement retained feature placeholderText.
//
// Verifies the placeholderText feature across its three implementation operations:
//   1. Feature-specific behavior: render the placeholder presentation only
//      while the model is empty (native AppKit placeholder, disappears on first
//      input).
//   2. The exact feature identity `placeholderText` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     PLACEHOLDERTEXT feature=live actions=0 commands=0 contributions=1 keybindings=0 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaPlaceholderTextFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/placeholder-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: render only while model is empty

    func testPlaceholderVisibleWhenModelIsEmpty() {
        let feature = MonaPlaceholderTextFeature(placeholder: "Type something…")
        let model = makeModel("")

        let visible = feature.evaluate(using: model)
        XCTAssertTrue(visible)
        XCTAssertTrue(feature.presentation(for: model).visible)
    }

    func testPlaceholderHiddenWhenModelHasContent() {
        let feature = MonaPlaceholderTextFeature(placeholder: "Type something…")
        let model = makeModel("hello")

        let visible = feature.evaluate(using: model)
        XCTAssertFalse(visible)
        XCTAssertFalse(feature.presentation(for: model).visible)
    }

    func testAttachObservesModelAndShowsPlaceholderForEmptyModel() {
        let feature = MonaPlaceholderTextFeature(placeholder: "Placeholder text")
        let model = makeModel("")

        var fired: [MonaPlaceholderTextEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        feature.attach(to: model)

        XCTAssertTrue(feature.isVisible)
        XCTAssertEqual(fired.count, 1)
        XCTAssertTrue(fired[0].presentation.visible)
    }

    func testPlaceholderDisappearsOnFirstInput() {
        let feature = MonaPlaceholderTextFeature(placeholder: "Type here")
        let model = makeModel("")
        feature.attach(to: model)
        XCTAssertTrue(feature.isVisible)

        // First input: the model gains content; the placeholder disappears.
        model.setValue("h")

        XCTAssertFalse(feature.isVisible)
        XCTAssertEqual(feature.presentation(for: model).visible, false)
    }

    func testPlaceholderReappearsWhenModelBecomesEmptyAgain() {
        let feature = MonaPlaceholderTextFeature(placeholder: "Type here")
        let model = makeModel("x")
        feature.attach(to: model)
        XCTAssertFalse(feature.isVisible)

        // Clear the model: the placeholder reappears.
        model.setValue("")

        XCTAssertTrue(feature.isVisible)
    }

    func testUpdatePlaceholderRebuildsPresentation() {
        let feature = MonaPlaceholderTextFeature(placeholder: "old")
        let model = makeModel("")
        feature.attach(to: model)

        feature.updatePlaceholder("new placeholder")

        XCTAssertEqual(feature.placeholderText, "new placeholder")
        let p = feature.presentation(for: model)
        XCTAssertEqual(p.attributedString.string, "new placeholder")
        XCTAssertTrue(p.visible)
    }

    func testPresentationCarriesNativeAppKitPlaceholderAttributes() {
        let feature = MonaPlaceholderTextFeature(placeholder: "hint")
        let model = makeModel("")

        let p = feature.presentation(for: model)
        // The native AppKit placeholder is an attributed string carrying a
        // foreground color attribute (the dim placeholder color).
        let color = p.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil)
        XCTAssertNotNil(color)
        XCTAssertTrue(color is NSColor)
    }

    func testPresentationEmptyWhenModelHasContent() {
        let feature = MonaPlaceholderTextFeature(placeholder: "hint")
        let model = makeModel("content")

        let p = feature.presentation(for: model)
        XCTAssertFalse(p.visible)
        // When hidden, the rendered attributed string is empty (nothing to show).
        XCTAssertEqual(p.attributedString.string, "")
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaPlaceholderTextFeature.featureId, "placeholderText")
        XCTAssertTrue(features.contains("placeholderText"))

        XCTAssertEqual(MonaPlaceholderTextFeature.declaredActionIds, [])
        XCTAssertEqual(MonaPlaceholderTextFeature.declaredCommandIds, [])
        for id in MonaPlaceholderTextFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }
        for id in MonaPlaceholderTextFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaPlaceholderTextFeature.declaredContributionIds, [
            "editor.contrib.placeholderText"
        ])
        for id in MonaPlaceholderTextFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaPlaceholderTextFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaPlaceholderTextFeature.declaredOptionIds, [
            "placeholder"
        ])
        for id in MonaPlaceholderTextFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }
        XCTAssertEqual(MonaPlaceholderTextFeature.declaredMenuIds, [])
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGatewayAndHidesPlaceholder() {
        let feature = MonaPlaceholderTextFeature(placeholder: "Type here")
        let model = makeModel("")
        let gateway = MonaTransactionGateway(model: model)
        feature.attach(to: model)
        XCTAssertTrue(feature.isVisible)

        // First input is committed through the transaction gateway: the model
        // gains content and the placeholder disappears.
        let outcome = feature.commitInput(
            text: "h",
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 1)
            ),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "h")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
        XCTAssertFalse(feature.isVisible)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaPlaceholderTextFeature(placeholder: "hint")
        let ticket = gate.captureTicket()
        let presentation = feature.presentation(for: model)

        var received: MonaPlaceholderTextPresentation?
        let accepted = feature.publishPlaceholder(
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
        XCTAssertEqual(received?.visible, true)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaPlaceholderTextFeature(placeholder: "hint")
        let model = makeModel("")
        var fired: [MonaPlaceholderTextEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        feature.attach(to: model)
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, the observer is detached: mutating the model fires no
        // further events.
        let countBefore = fired.count
        model.setValue("text")
        XCTAssertEqual(fired.count, countBefore)
        // evaluate is still a pure query, but the feature is inert.
        XCTAssertFalse(feature.isVisible)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaPlaceholderTextFeature(placeholder: "hint")
        // placeholderText declares no actions, so localized labels are empty
        // under every profile — but the path still routes through MonaLocalization.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaPlaceholderTextFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaPlaceholderTextFeature(placeholder: "hint")
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
        let feature = MonaPlaceholderTextFeature(placeholder: "Type here")

        let featureLive = features.contains(MonaPlaceholderTextFeature.featureId)
        let actionCount = MonaPlaceholderTextFeature.declaredActionIds.count
        let commandCount = MonaPlaceholderTextFeature.declaredCommandIds.count
        let contribCount = MonaPlaceholderTextFeature.declaredContributionIds.count
        let kbCount = MonaPlaceholderTextFeature.declaredKeybindingCommands.count
        let optionCount = MonaPlaceholderTextFeature.declaredOptionIds.count
        let menuCount = MonaPlaceholderTextFeature.declaredMenuIds.count

        let slicePass = MonaPlaceholderTextFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaPlaceholderTextFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaPlaceholderTextFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaPlaceholderTextFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaPlaceholderTextFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaPlaceholderTextFeature.declaredMenuIds.allSatisfy { _ in true }

        // Empty model → placeholder visible; first input hides it.
        let model = makeModel("")
        feature.attach(to: model)
        let emptyVisible = feature.isVisible
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitInput(
            text: "hi",
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 1)
            ),
            gateway: gateway
        )
        var mutation = false
        if case .applied = outcome, model.getValue() == "hi", !feature.isVisible {
            mutation = true
        }

        // Clear the model → placeholder reappears.
        model.setValue("")
        let reappeared = feature.isVisible

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishPlaceholder(
            feature.presentation(for: model),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("PLACEHOLDERTEXT feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(emptyVisible)
        XCTAssertTrue(mutation)
        XCTAssertTrue(reappeared)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
