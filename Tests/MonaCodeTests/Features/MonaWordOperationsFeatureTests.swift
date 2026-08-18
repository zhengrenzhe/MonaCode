// MonaWordOperationsFeatureTests.swift
//
// P05-T160 — Implement retained feature wordOperations.
//
// Verifies the wordOperations feature across its three implementation operations:
//   1. Feature-specific behavior: move, delete, and transform (transpose) by
//      the frozen word boundary profile (MonaWordClassifier three-way: word,
//      separator, whitespace). Deletes and transposes are committed
//      transactionally through MonaTransactionGateway for mutation.
//   2. The exact feature identity `wordOperations` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     WORDOPERATIONS feature=live actions=1 commands=20 contributions=0 keybindings=6 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaWordOperationsFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "foo bar baz") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/wordops-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: move / delete / transform

    // move word left
    func testMoveWordLeftFromEndLandsAtStartOfWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let p = feature.moveWordLeft(
            from: MonaPosition(line: 1, column: 8),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 5))
    }

    func testMoveWordLeftFromWordStartLandsAtPreviousWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let p = feature.moveWordLeft(
            from: MonaPosition(line: 1, column: 5),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 1))
    }

    func testMoveWordLeftAtStartOfLineMovesToPreviousLineEnd() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo\nbar")
        let p = feature.moveWordLeft(
            from: MonaPosition(line: 2, column: 1),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 4))
    }

    func testMoveWordLeftAtVeryStartIsNoOp() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo")
        let p = feature.moveWordLeft(
            from: MonaPosition(line: 1, column: 1),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 1))
    }

    // move word right
    func testMoveWordRightFromStartLandsAtStartOfNextWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let p = feature.moveWordRight(
            from: MonaPosition(line: 1, column: 1),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 5))
    }

    func testMoveWordRightAtEndIsNoOp() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo")
        let p = feature.moveWordRight(
            from: MonaPosition(line: 1, column: 4),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 1, column: 4))
    }

    func testMoveWordRightAtEndOfLineMovesToNextLineStart() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo\nbar")
        let p = feature.moveWordRight(
            from: MonaPosition(line: 1, column: 4),
            model: model
        )
        XCTAssertEqual(p, MonaPosition(line: 2, column: 1))
    }

    // move word select
    func testMoveWordLeftSelectExtendsRangeToStartOfWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let r = feature.moveWordLeftSelect(
            from: MonaPosition(line: 1, column: 8),
            model: model
        )
        XCTAssertEqual(r, MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 8)
        ))
    }

    func testMoveWordRightSelectExtendsRangeToStartOfNextWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let r = feature.moveWordRightSelect(
            from: MonaPosition(line: 1, column: 1),
            model: model
        )
        XCTAssertEqual(r, MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 5)
        ))
    }

    // delete word left
    func testDeleteWordLeftDeletesWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordLeft(
            from: MonaPosition(line: 1, column: 8),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "foo ")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDeleteWordLeftEatsTrailingWhitespaceAndPrecedingWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo ")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordLeft(
            from: MonaPosition(line: 1, column: 5),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDeleteWordLeftAtStartIsDropped() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordLeft(
            from: MonaPosition(line: 1, column: 1),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "foo")
        } else {
            XCTFail("expected dropped at start, got \(outcome)")
        }
    }

    // delete word right
    func testDeleteWordRightDeletesWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordRight(
            from: MonaPosition(line: 1, column: 1),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), " bar")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDeleteWordRightAtEndIsDropped() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordRight(
            from: MonaPosition(line: 1, column: 4),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "foo")
        } else {
            XCTFail("expected dropped at end, got \(outcome)")
        }
    }

    // delete inside word
    func testDeleteInsideWordDeletesContainingWord() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteInsideWord(
            at: MonaPosition(line: 1, column: 3),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), " bar")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    // transform: transpose word
    func testTransposeWordSwapsTwoWords() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.transposeWord(
            at: MonaPosition(line: 1, column: 8),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "bar foo")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testTransposeWordAtStartIsDropped() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.transposeWord(
            at: MonaPosition(line: 1, column: 1),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "foo")
        } else {
            XCTFail("expected dropped at start, got \(outcome)")
        }
    }

    // disposal
    func testCommandsAreNoOpsAfterDisposal() {
        let feature = MonaWordOperationsFeature()
        let model = makeModel("foo bar")
        let gateway = MonaTransactionGateway(model: model)
        feature.dispose()
        let outcome = feature.deleteWordLeft(
            from: MonaPosition(line: 1, column: 8),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "foo bar")
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

        XCTAssertEqual(MonaWordOperationsFeature.featureId, "wordOperations")
        XCTAssertTrue(features.contains("wordOperations"))

        let actionIds = MonaWordOperationsFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "deleteInsideWord"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        let commandIds = MonaWordOperationsFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "cursorWordEndLeft",
            "cursorWordEndLeftSelect",
            "cursorWordEndRight",
            "cursorWordEndRightSelect",
            "cursorWordLeft",
            "cursorWordLeftSelect",
            "cursorWordRight",
            "cursorWordRightSelect",
            "cursorWordStartLeft",
            "cursorWordStartLeftSelect",
            "cursorWordStartRight",
            "cursorWordStartRightSelect",
            "deleteInsideWord",
            "deleteWordEndLeft",
            "deleteWordEndRight",
            "deleteWordLeft",
            "deleteWordRight",
            "deleteWordStartLeft",
            "deleteWordStartRight",
            "lastCursorWordSelect"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertTrue(MonaWordOperationsFeature.declaredContributionIds.isEmpty)

        let kbCommands = MonaWordOperationsFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands, [
            "cursorWordEndRight",
            "cursorWordEndRightSelect",
            "cursorWordLeft",
            "cursorWordLeftSelect",
            "deleteWordLeft",
            "deleteWordRight"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertTrue(MonaWordOperationsFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaWordOperationsFeature.declaredMenuIds.isEmpty)
        _ = contributions
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaWordOperationsFeature()
        let ticket = gate.captureTicket()

        var received: [MonaWordOperationsEvent] = []
        let accepted = feature.publishWordOperationsEvent(
            MonaWordOperationsEvent(
                operation: .delete,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 4)
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
        let feature = MonaWordOperationsFeature()
        var fired: [MonaWordOperationsEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaWordOperationsFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaWordOperationsFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Delete Word")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaWordOperationsFeature()
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
        let feature = MonaWordOperationsFeature()

        let featureLive = features.contains(MonaWordOperationsFeature.featureId)
        let actionCount = MonaWordOperationsFeature.declaredActionIds.count
        let commandCount = MonaWordOperationsFeature.declaredCommandIds.count
        let contribCount = MonaWordOperationsFeature.declaredContributionIds.count
        let kbCount = MonaWordOperationsFeature.declaredKeybindingCommands.count
        let optionCount = MonaWordOperationsFeature.declaredOptionIds.count
        let menuCount = MonaWordOperationsFeature.declaredMenuIds.count

        let slicePass = MonaWordOperationsFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaWordOperationsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaWordOperationsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaWordOperationsFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaWordOperationsFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: delete the word "bar" through the transaction gateway.
        let model = makeModel("foo bar")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteWordLeft(
            from: MonaPosition(line: 1, column: 8),
            gateway: gateway
        )
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "foo " {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishWordOperationsEvent(
            MonaWordOperationsEvent(
                operation: .delete,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 5),
                    endPosition: MonaPosition(line: 1, column: 8)
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

        print("WORDOPERATIONS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
