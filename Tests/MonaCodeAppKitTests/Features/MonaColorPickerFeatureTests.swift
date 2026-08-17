// MonaColorPickerFeatureTests.swift
//
// P05-T108 — Implement retained feature colorPicker.
//
// Verifies the colorPicker feature across its three implementation operations:
//   1. Feature-specific behavior: present, update, and commit document-color
//      provider results (via MonaTransactionGateway for commit).
//   2. The exact feature identity `colorPicker` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     COLORPICKER feature=live actions=2 commands=5 contributions=3 keybindings=2 options=4 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaColorPickerFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "color: #ff0000;") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/colorpicker-\(UUID().uuidString)")
        )
    }

    private func sampleColors() -> [MonaColorInformation] {
        return [
            MonaColorInformation(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 8),
                    endPosition: MonaPosition(line: 1, column: 15)
                ),
                color: "#ff0000",
                presentations: [
                    MonaColorPresentation(label: "RGB", text: "rgb(255, 0, 0)"),
                    MonaColorPresentation(label: "HEX", text: "#ff0000")
                ]
            )
        ]
    }

    // MARK: - 1. Feature-specific behavior: present / update / commit

    func testPresentColorsRetainsDocumentColorProviderResults() {
        let feature = MonaColorPickerFeature()
        let model = makeModel()

        let presented = feature.presentColors(sampleColors(), model: model)

        XCTAssertEqual(presented.count, 1)
        XCTAssertEqual(presented[0].color, "#ff0000")
        XCTAssertEqual(feature.presentedColorCount, 1)
        XCTAssertEqual(feature.presentedColors.map { $0.color }, ["#ff0000"])
    }

    func testPresentColorsWithEmptyProviderResultsPresentsNothing() {
        let feature = MonaColorPickerFeature()
        let model = makeModel()

        let presented = feature.presentColors([], model: model)

        XCTAssertTrue(presented.isEmpty)
        XCTAssertEqual(feature.presentedColorCount, 0)
    }

    func testUpdateColorsReplacesPresentedResults() {
        let feature = MonaColorPickerFeature()
        let model = makeModel()

        _ = feature.presentColors(sampleColors(), model: model)
        XCTAssertEqual(feature.presentedColorCount, 1)

        let updated = feature.updateColors([
            MonaColorInformation(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 8),
                    endPosition: MonaPosition(line: 1, column: 15)
                ),
                color: "#00ff00",
                presentations: [MonaColorPresentation(label: "HEX", text: "#00ff00")]
            )
        ])
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(feature.presentedColorCount, 1)
        XCTAssertEqual(feature.presentedColors[0].color, "#00ff00")
    }

    func testCommitColorAppliesPresentationTextTransactionallyThroughGateway() {
        let feature = MonaColorPickerFeature()
        let model = makeModel("color: #ff0000;")
        let gateway = MonaTransactionGateway(model: model)
        _ = feature.presentColors(sampleColors(), model: model)

        let color = feature.presentedColors[0]
        let presentation = color.presentations[0] // "rgb(255, 0, 0)"

        let outcome = feature.commitColor(color, presentation: presentation, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "color: rgb(255, 0, 0);")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testCommitColorWithHexPresentationCommitsHexText() {
        let feature = MonaColorPickerFeature()
        let model = makeModel("color: red;")
        let gateway = MonaTransactionGateway(model: model)
        let color = MonaColorInformation(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 8),
                endPosition: MonaPosition(line: 1, column: 11)
            ),
            color: "red",
            presentations: [MonaColorPresentation(label: "HEX", text: "#ff0000")]
        )
        let outcome = feature.commitColor(color, presentation: color.presentations[0], gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "color: #ff0000;")
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
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaColorPickerFeature.featureId, "colorPicker")
        XCTAssertTrue(features.contains("colorPicker"))

        let actionIds = MonaColorPickerFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.hideColorPicker",
            "editor.action.insertColorWithStandaloneColorPicker"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaColorPickerFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "_executeColorPresentationProvider",
            "_executeDocumentColorProvider",
            "editor.action.hideColorPicker",
            "editor.action.insertColorWithStandaloneColorPicker",
            "editor.action.showOrFocusStandaloneColorPicker"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaColorPickerFeature.declaredContributionIds, [
            "editor.contrib.colorContribution",
            "editor.contrib.standaloneColorPickerController",
            "editor.contrib.colorDetector"
        ])
        for id in MonaColorPickerFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        let kbCommands = MonaColorPickerFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands, [
            "editor.action.hideColorPicker",
            "editor.action.insertColorWithStandaloneColorPicker"
        ])
        let keybindingCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(keybindingCommands.contains(id), "missing keybinding for \(id)")
        }

        XCTAssertEqual(MonaColorPickerFeature.declaredOptionIds, [
            "colorDecorators",
            "colorDecoratorsLimit",
            "defaultColorDecorators",
            "colorDecoratorActivatedOn"
        ])

        XCTAssertEqual(MonaColorPickerFeature.declaredMenuIds, ["CommandPalette"])
        for id in MonaColorPickerFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaColorPickerFeature()
        let ticket = gate.captureTicket()

        var received: [MonaColorInformation] = []
        let accepted = feature.publishColorPresentations(
            sampleColors(),
            executor: executor,
            ticket: ticket
        ) { colors in
            received = colors
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaColorPickerFeature()
        var fired: [MonaColorPickerEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, present / update / commit are no-ops.
        let model = makeModel()
        let presented = feature.presentColors(sampleColors(), model: model)
        XCTAssertTrue(presented.isEmpty)
        XCTAssertEqual(feature.presentedColorCount, 0)
        let updated = feature.updateColors(sampleColors())
        XCTAssertTrue(updated.isEmpty)
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitColor(sampleColors()[0], presentation: sampleColors()[0].presentations[0], gateway: gateway)
        if case .dropped = outcome {
            // expected
        } else {
            XCTFail("expected dropped after dispose, got \(outcome)")
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaColorPickerFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaColorPickerFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Hide the Color Picker")
        XCTAssertEqual(enLabels[1], "Insert Color with Standalone Color Picker")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaColorPickerFeature()
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
        let feature = MonaColorPickerFeature()

        let featureLive = features.contains(MonaColorPickerFeature.featureId)
        let actionCount = MonaColorPickerFeature.declaredActionIds.count
        let commandCount = MonaColorPickerFeature.declaredCommandIds.count
        let contribCount = MonaColorPickerFeature.declaredContributionIds.count
        let kbCount = MonaColorPickerFeature.declaredKeybindingCommands.count
        let optionCount = MonaColorPickerFeature.declaredOptionIds.count
        let menuCount = MonaColorPickerFeature.declaredMenuIds.count

        let slicePass = MonaColorPickerFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaColorPickerFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaColorPickerFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaColorPickerFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaColorPickerFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: present then commit a document-color presentation through the
        // transaction gateway.
        let model = makeModel("color: #ff0000;")
        let gateway = MonaTransactionGateway(model: model)
        _ = feature.presentColors(sampleColors(), model: model)
        let commitColor = feature.presentedColors[0]
        let outcome = feature.commitColor(commitColor, presentation: commitColor.presentations[0], gateway: gateway)
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "color: rgb(255, 0, 0);" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishColorPresentations([], executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("COLORPICKER feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
