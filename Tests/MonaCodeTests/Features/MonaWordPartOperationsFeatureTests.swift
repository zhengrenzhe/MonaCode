// MonaWordPartOperationsFeatureTests.swift
//
// P05-T161 — Implement retained feature wordPartOperations.
//
// Verifies the wordPartOperations feature across its three implementation
// operations:
//   1. Feature-specific behavior: move and delete by camel, underscore, digit,
//      and punctuation word parts (camelCase / snake_case word-part
//      boundaries). Deletes are committed transactionally through
//      MonaTransactionGateway for mutation.
//   2. The exact feature identity `wordPartOperations` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     WORDPARTOPERATIONS feature=live actions=0 commands=8 contributions=0 keybindings=6 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaWordPartOperationsFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "caMeL") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/wordpart-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: move / delete by word part

    // move word part left (camelCase)
    func testMoveWordPartLeftCamelCaseFromEndLandsAtLastPartStart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let p = feature.moveWordPartLeft(
            from: MonaPosition(line: 1, column: 6),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 5))
    }

    func testMoveWordPartLeftCamelCaseChainsThroughParts() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        var p = feature.moveWordPartLeft(from: MonaPosition(line: 1, column: 6), model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 5))
        p = feature.moveWordPartLeft(from: p, model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 3))
        p = feature.moveWordPartLeft(from: p, model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 1))
    }

    func testMoveWordPartLeftAtStartIsNoOp() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let p = feature.moveWordPartLeft(
            from: MonaPosition(line: 1, column: 1),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 1))
    }

    // move word part right (camelCase)
    func testMoveWordPartRightCamelCaseFromStartLandsAtNextPartStart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let p = feature.moveWordPartRight(
            from: MonaPosition(line: 1, column: 1),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 3))
    }

    func testMoveWordPartRightCamelCaseChainsThroughParts() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        var p = feature.moveWordPartRight(from: MonaPosition(line: 1, column: 1), model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 3))
        p = feature.moveWordPartRight(from: p, model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 5))
        p = feature.moveWordPartRight(from: p, model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 6))
    }

    // move word part (snake_case / underscore)
    func testMoveWordPartLeftSnakeCaseFromEndLandsAtBarStart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("foo_bar")
        let p = feature.moveWordPartLeft(
            from: MonaPosition(line: 1, column: 8),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 5))
    }

    func testMoveWordPartRightSnakeCaseFromStartLandsAtUnderscore() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("foo_bar")
        let p = feature.moveWordPartRight(
            from: MonaPosition(line: 1, column: 1),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 4))
    }

    // move word part (digit boundaries)
    func testMoveWordPartLeftDigitBoundaryLandsAtDefStart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("abc123def")
        let p = feature.moveWordPartLeft(
            from: MonaPosition(line: 1, column: 10),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 7))
    }

    func testMoveWordPartLeftDigitBoundaryChainsToDigitThenAbc() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("abc123def")
        var p = feature.moveWordPartLeft(from: MonaPosition(line: 1, column: 10), model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 7))
        p = feature.moveWordPartLeft(from: p, model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 4))
        p = feature.moveWordPartLeft(from: p, model: model)
        XCTAssertEqual(p, MonaPosition(line: 1, column: 1))
    }

    // HTMLParser-style upper-run split
    func testMoveWordPartLeftHTMLParserSplitsBeforeParser() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("HTMLParser")
        // "HTMLParser|" (col 11) -> start of "Parser" (col 5)
        let p = feature.moveWordPartLeft(
            from: MonaPosition(line: 1, column: 11),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 5))
    }

    // move word part select
    func testMoveWordPartLeftSelectExtendsRangeToPartStart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let r = feature.moveWordPartLeftSelect(
            from: MonaPosition(line: 1, column: 6),
            model: model
        )
        XCTAssertEqual(r, MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 6)
        ))
    }

    func testMoveWordPartRightSelectExtendsRangeToNextPartStart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let r = feature.moveWordPartRightSelect(
            from: MonaPosition(line: 1, column: 1),
            model: model
        )
        XCTAssertEqual(r, MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 3)
        ))
    }

    // delete word part left
    func testDeleteWordPartLeftCamelDeletesLastPart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordPartLeft(
            from: MonaPosition(line: 1, column: 6),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "caMe")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDeleteWordPartLeftSnakeDeletesWordPart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("foo_bar")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordPartLeft(
            from: MonaPosition(line: 1, column: 8),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "foo_")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDeleteWordPartLeftAtStartIsDropped() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordPartLeft(
            from: MonaPosition(line: 1, column: 1),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "caMeL")
        } else {
            XCTFail("expected dropped at start, got \(outcome)")
        }
    }

    // delete word part right
    func testDeleteWordPartRightCamelDeletesFirstPart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordPartRight(
            from: MonaPosition(line: 1, column: 1),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "MeL")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDeleteWordPartRightSnakeDeletesFirstPart() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("foo_bar")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordPartRight(
            from: MonaPosition(line: 1, column: 1),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "_bar")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDeleteWordPartRightAtEndIsDropped() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordPartRight(
            from: MonaPosition(line: 1, column: 6),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "caMeL")
        } else {
            XCTFail("expected dropped at end, got \(outcome)")
        }
    }

    // disposal
    func testCommandsAreNoOpsAfterDisposal() {
        let feature = MonaWordPartOperationsFeature()
        let model = makeModel("caMeL")
        let gateway = MonaTransactionGateway(model: model)
        feature.dispose()
        let outcome = feature.deleteWordPartLeft(
            from: MonaPosition(line: 1, column: 6),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "caMeL")
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

        XCTAssertEqual(MonaWordPartOperationsFeature.featureId, "wordPartOperations")
        XCTAssertTrue(features.contains("wordPartOperations"))

        // wordPartOperations registers no editor actions in the F1-R3 scope
        // manifest — only editor commands.
        XCTAssertTrue(MonaWordPartOperationsFeature.declaredActionIds.isEmpty)

        let commandIds = MonaWordPartOperationsFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "cursorWordPartLeft",
            "cursorWordPartLeftSelect",
            "cursorWordPartRight",
            "cursorWordPartRightSelect",
            "cursorWordPartStartLeft",
            "cursorWordPartStartLeftSelect",
            "deleteWordPartLeft",
            "deleteWordPartRight"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertTrue(MonaWordPartOperationsFeature.declaredContributionIds.isEmpty)

        let kbCommands = MonaWordPartOperationsFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands, [
            "cursorWordPartLeft",
            "cursorWordPartLeftSelect",
            "cursorWordPartRight",
            "cursorWordPartRightSelect",
            "deleteWordPartLeft",
            "deleteWordPartRight"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertTrue(MonaWordPartOperationsFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaWordPartOperationsFeature.declaredMenuIds.isEmpty)
        _ = actions
        _ = contributions
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaWordPartOperationsFeature()
        let ticket = gate.captureTicket()

        var received: [MonaWordPartOperationsEvent] = []
        let accepted = feature.publishWordPartOperationsEvent(
            MonaWordPartOperationsEvent(
                operation: .delete,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 3)
                )
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
        let feature = MonaWordPartOperationsFeature()
        var fired: [MonaWordPartOperationsEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaWordPartOperationsFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaWordPartOperationsFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaWordPartOperationsFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    func testContractBehavior() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let feature = MonaWordPartOperationsFeature()

        let featureLive = features.contains(MonaWordPartOperationsFeature.featureId)
        let actionCount = MonaWordPartOperationsFeature.declaredActionIds.count
        let commandCount = MonaWordPartOperationsFeature.declaredCommandIds.count
        let contribCount = MonaWordPartOperationsFeature.declaredContributionIds.count
        let kbCount = MonaWordPartOperationsFeature.declaredKeybindingCommands.count
        let optionCount = MonaWordPartOperationsFeature.declaredOptionIds.count
        let menuCount = MonaWordPartOperationsFeature.declaredMenuIds.count

        let slicePass = MonaWordPartOperationsFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaWordPartOperationsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaWordPartOperationsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaWordPartOperationsFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaWordPartOperationsFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: delete the last word part "L" through the transaction gateway.
        let model = makeModel("caMeL")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordPartLeft(
            from: MonaPosition(line: 1, column: 6),
            gateway: gateway
        )
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "caMe" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishWordPartOperationsEvent(
            MonaWordPartOperationsEvent(
                operation: .delete,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 5),
                    endPosition: MonaPosition(line: 1, column: 6)
                )
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

        print("WORDPARTOPERATIONS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
