// MonaLinesOperationsFeatureTests.swift
//
// P05-T134 — Implement retained feature linesOperations.
//
// Verifies the linesOperations feature across its three implementation operations:
//   1. Feature-specific behavior: move, copy, delete, join, sort, trim, transpose,
//      and duplicate lines transactionally (8 operations, all via
//      MonaTransactionGateway for mutation).
//   2. The exact feature identity `linesOperations` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     LINESOPERATIONS feature=live actions=12 commands=12 contributions=0 keybindings=8 options=0 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaLinesOperationsFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "a\nb\nc") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/linesops-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: 8 operations via MonaTransactionGateway

    // move
    func testMoveLinesUpSwapsLineWithPredecessor() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.moveLinesUp(line: 2, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "b\na\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testMoveLinesUpOnFirstLineIsDropped() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.moveLinesUp(line: 1, gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nc")
        } else {
            XCTFail("expected dropped on first line, got \(outcome)")
        }
    }

    func testMoveLinesDownSwapsLineWithSuccessor() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.moveLinesDown(line: 2, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nc\nb")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testMoveLinesDownOnLastLineIsDropped() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.moveLinesDown(line: 3, gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nc")
        } else {
            XCTFail("expected dropped on last line, got \(outcome)")
        }
    }

    // copy
    func testCopyLinesUpInsertsCopyAboveOriginal() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.copyLinesUp(line: 2, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nb\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testCopyLinesDownInsertsCopyBelowOriginal() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.copyLinesDown(line: 2, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nb\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    // delete
    func testDeleteLinesRemovesMiddleLineAndItsTerminator() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteLines(line: 2, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDeleteLinesOnFinalLineRemovesContent() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.deleteLines(line: 3, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb")
        } else {
            XCTFail("expected applied on final line, got \(outcome)")
        }
    }

    // join
    func testJoinLinesMergesLineWithNext() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.joinLines(line: 1, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a b\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testJoinLinesTrimsWhitespaceBetweenLines() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("hello   \n   world")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.joinLines(line: 1, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "hello world")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testJoinLinesOnFinalLineIsDropped() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.joinLines(line: 3, gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nc")
        } else {
            XCTFail("expected dropped on final line, got \(outcome)")
        }
    }

    // sort
    func testSortLinesAscendingOrdersLines() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("c\na\nb")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.sortLinesAscending(from: 1, to: 3, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testSortLinesDescendingOrdersLines() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("c\na\nb")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.sortLinesDescending(from: 1, to: 3, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "c\nb\na")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    // trim
    func testTrimTrailingWhitespaceStripsTrailingSpaces() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a  \nb \nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.trimTrailingWhitespace(from: 1, to: 3, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    // transpose
    func testTransposeCharactersSwapsTwoCharsBeforeCursor() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        // Cursor at column 4 (after 'c'): swap 'b' and 'c' -> "acb".
        let outcome = feature.transposeCharacters(
            at: MonaPosition(line: 1, column: 4),
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "acb")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testTransposeCharactersAtStartIsDropped() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.transposeCharacters(
            at: MonaPosition(line: 1, column: 1),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abc")
        } else {
            XCTFail("expected dropped at start, got \(outcome)")
        }
    }

    // duplicate
    func testDuplicateSelectionDuplicatesSelectedText() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        // Selection "ll" spans columns 3..5 (1-based).
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 5)
        )
        let outcome = feature.duplicateSelection(range: range, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "hellllo")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDuplicateSelectionCollapsedDuplicatesWholeLine() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        // Collapsed selection on line 2: duplicate the whole line.
        let range = MonaRange(
            startPosition: MonaPosition(line: 2, column: 1),
            endPosition: MonaPosition(line: 2, column: 1)
        )
        let outcome = feature.duplicateSelection(range: range, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nb\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testCommandsAreNoOpsAfterDisposal() {
        let feature = MonaLinesOperationsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        feature.dispose()
        let outcome = feature.moveLinesUp(line: 2, gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nc")
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

        XCTAssertEqual(MonaLinesOperationsFeature.featureId, "linesOperations")
        XCTAssertTrue(features.contains("linesOperations"))

        let actionIds = MonaLinesOperationsFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.transposeLetters",
            "editor.action.copyLinesUpAction",
            "editor.action.copyLinesDownAction",
            "editor.action.duplicateSelection",
            "editor.action.moveLinesUpAction",
            "editor.action.moveLinesDownAction",
            "editor.action.sortLinesAscending",
            "editor.action.sortLinesDescending",
            "editor.action.trimTrailingWhitespace",
            "editor.action.deleteLines",
            "editor.action.joinLines",
            "editor.action.transpose"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaLinesOperationsFeature.declaredCommandIds, actionIds)
        for id in MonaLinesOperationsFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // linesOperations registers no contribution descriptor in the F1-R3
        // scope manifest.
        XCTAssertTrue(MonaLinesOperationsFeature.declaredContributionIds.isEmpty)

        let kbCommands = MonaLinesOperationsFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands, [
            "editor.action.copyLinesDownAction",
            "editor.action.copyLinesUpAction",
            "editor.action.deleteLines",
            "editor.action.joinLines",
            "editor.action.moveLinesDownAction",
            "editor.action.moveLinesUpAction",
            "editor.action.transposeLetters",
            "editor.action.trimTrailingWhitespace"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaLinesOperationsFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaLinesOperationsFeature.declaredMenuIds, ["MenubarSelectionMenu"])
        for id in MonaLinesOperationsFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
        _ = contributions
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaLinesOperationsFeature()
        let ticket = gate.captureTicket()

        var received: [MonaLinesOperationsEvent] = []
        let accepted = feature.publishLinesOperationsEvent(
            MonaLinesOperationsEvent(
                operation: .delete,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 2, column: 1)
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
        let feature = MonaLinesOperationsFeature()
        var fired: [MonaLinesOperationsEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaLinesOperationsFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaLinesOperationsFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Transpose Letters")
        XCTAssertEqual(enLabels[1], "Copy Line Up")
        XCTAssertEqual(enLabels[4], "Move Line Up")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaLinesOperationsFeature()
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
        let feature = MonaLinesOperationsFeature()

        let featureLive = features.contains(MonaLinesOperationsFeature.featureId)
        let actionCount = MonaLinesOperationsFeature.declaredActionIds.count
        let commandCount = MonaLinesOperationsFeature.declaredCommandIds.count
        let contribCount = MonaLinesOperationsFeature.declaredContributionIds.count
        let kbCount = MonaLinesOperationsFeature.declaredKeybindingCommands.count
        let optionCount = MonaLinesOperationsFeature.declaredOptionIds.count
        let menuCount = MonaLinesOperationsFeature.declaredMenuIds.count

        let slicePass = MonaLinesOperationsFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaLinesOperationsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaLinesOperationsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaLinesOperationsFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaLinesOperationsFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: move line 2 up through the transaction gateway.
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.moveLinesUp(line: 2, gateway: gateway)
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "b\na\nc" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishLinesOperationsEvent(
            MonaLinesOperationsEvent(
                operation: .move,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 2, column: 1)
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

        print("LINESOPERATIONS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
