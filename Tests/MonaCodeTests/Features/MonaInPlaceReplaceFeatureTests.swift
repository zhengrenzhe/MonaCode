// MonaInPlaceReplaceFeatureTests.swift
//
// P05-T130 — Implement retained feature inPlaceReplace.
//
// Verifies the inPlaceReplace feature across its three implementation operations:
//   1. Feature-specific behavior: replace the active word from exact previous
//      and next candidate calculations (cycle through candidates), via
//      MonaTransactionGateway for mutation.
//   2. The exact feature identity `inPlaceReplace` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     INPLACEREPLACE feature=live actions=2 commands=2 contributions=1 keybindings=2 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaInPlaceReplaceFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 5") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/inplace-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: replace the active word, cycling candidates

    func testReplaceNextReplacesActiveWordWithNextCandidate() {
        let feature = MonaInPlaceReplaceFeature()
        let model = makeModel("let x = 5")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.replaceNext(
            at: MonaPosition(line: 1, column: 9),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "let x = 6")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testReplaceNextCyclesThroughCandidatesOnRepeatAtSamePosition() {
        let feature = MonaInPlaceReplaceFeature()
        let model = makeModel("let x = 5")
        let gateway = MonaTransactionGateway(model: model)

        _ = feature.replaceNext(at: MonaPosition(line: 1, column: 9), gateway: gateway)
        XCTAssertEqual(model.getValue(), "let x = 6")
        _ = feature.replaceNext(at: MonaPosition(line: 1, column: 9), gateway: gateway)
        XCTAssertEqual(model.getValue(), "let x = 7")
        _ = feature.replaceNext(at: MonaPosition(line: 1, column: 9), gateway: gateway)
        XCTAssertEqual(model.getValue(), "let x = 8")
    }

    func testReplacePreviousReplacesActiveWordWithPreviousCandidate() {
        let feature = MonaInPlaceReplaceFeature()
        let model = makeModel("let x = 5")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.replacePrevious(
            at: MonaPosition(line: 1, column: 9),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "let x = 4")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDirectionSwitchCyclesBackThroughTheSequence() {
        let feature = MonaInPlaceReplaceFeature()
        let model = makeModel("let x = 5")
        let gateway = MonaTransactionGateway(model: model)

        _ = feature.replaceNext(at: MonaPosition(line: 1, column: 9), gateway: gateway)
        XCTAssertEqual(model.getValue(), "let x = 6")
        _ = feature.replaceNext(at: MonaPosition(line: 1, column: 9), gateway: gateway)
        XCTAssertEqual(model.getValue(), "let x = 7")
        _ = feature.replacePrevious(at: MonaPosition(line: 1, column: 9), gateway: gateway)
        XCTAssertEqual(model.getValue(), "let x = 6")
        _ = feature.replacePrevious(at: MonaPosition(line: 1, column: 9), gateway: gateway)
        XCTAssertEqual(model.getValue(), "let x = 5")
    }

    func testReplaceDropsWhenNoCandidateExists() {
        let feature = MonaInPlaceReplaceFeature()
        let model = makeModel("let name = hello")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.replaceNext(
            at: MonaPosition(line: 1, column: 13),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "let name = hello")
        } else {
            XCTFail("expected dropped for non-numeric word, got \(outcome)")
        }
    }

    func testCommandsAreNoOpsAfterDisposal() {
        let feature = MonaInPlaceReplaceFeature()
        let model = makeModel("let x = 5")
        let gateway = MonaTransactionGateway(model: model)
        feature.dispose()

        let outcome = feature.replaceNext(
            at: MonaPosition(line: 1, column: 9),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "let x = 5")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaInPlaceReplaceFeature.featureId, "inPlaceReplace")
        XCTAssertTrue(features.contains("inPlaceReplace"))

        let actionIds = MonaInPlaceReplaceFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.inPlaceReplace.up",
            "editor.action.inPlaceReplace.down"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaInPlaceReplaceFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "editor.action.inPlaceReplace.up",
            "editor.action.inPlaceReplace.down"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaInPlaceReplaceFeature.declaredContributionIds, [
            "editor.contrib.inPlaceReplaceController"
        ])
        for id in MonaInPlaceReplaceFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaInPlaceReplaceFeature.declaredKeybindingCommands, [
            "editor.action.inPlaceReplace.up",
            "editor.action.inPlaceReplace.down"
        ])
        for id in MonaInPlaceReplaceFeature.declaredKeybindingCommands {
            let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaInPlaceReplaceFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaInPlaceReplaceFeature.declaredMenuIds, [])
        _ = options
        _ = menus
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaInPlaceReplaceFeature()
        let ticket = gate.captureTicket()

        var received: [MonaInPlaceReplaceEvent] = []
        let accepted = feature.publishReplaceEvent(
            MonaInPlaceReplaceEvent(
                direction: .next,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 9),
                    endPosition: MonaPosition(line: 1, column: 10)
                ),
                oldText: "5",
                newText: "6"
            ),
            executor: executor,
            ticket: ticket
        ) { event in
            received.append(event)
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaInPlaceReplaceFeature()
        var fired: [MonaInPlaceReplaceEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaInPlaceReplaceFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaInPlaceReplaceFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Replace with Previous Value")
        XCTAssertEqual(enLabels[1], "Replace with Next Value")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaInPlaceReplaceFeature()
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
        let feature = MonaInPlaceReplaceFeature()

        let featureLive = features.contains(MonaInPlaceReplaceFeature.featureId)
        let actionCount = MonaInPlaceReplaceFeature.declaredActionIds.count
        let commandCount = MonaInPlaceReplaceFeature.declaredCommandIds.count
        let contribCount = MonaInPlaceReplaceFeature.declaredContributionIds.count
        let kbCount = MonaInPlaceReplaceFeature.declaredKeybindingCommands.count
        let optionCount = MonaInPlaceReplaceFeature.declaredOptionIds.count
        let menuCount = MonaInPlaceReplaceFeature.declaredMenuIds.count

        let slicePass = MonaInPlaceReplaceFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaInPlaceReplaceFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaInPlaceReplaceFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaInPlaceReplaceFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }

        // Mutation: replace the active word through the transaction gateway.
        let model = makeModel("let x = 5")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.replaceNext(
            at: MonaPosition(line: 1, column: 9),
            gateway: gateway
        )
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "let x = 6" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishReplaceEvent(
            MonaInPlaceReplaceEvent(
                direction: .next,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 9),
                    endPosition: MonaPosition(line: 1, column: 10)
                ),
                oldText: "5",
                newText: "6"
            ),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("INPLACEREPLACE feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
