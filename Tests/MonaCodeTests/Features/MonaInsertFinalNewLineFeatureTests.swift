// MonaInsertFinalNewLineFeatureTests.swift
//
// P05-T131 — Implement retained feature insertFinalNewLine.
//
// Verifies the insertFinalNewLine feature across its three implementation
// operations:
//   1. Feature-specific behavior: insert a final line terminator under explicit
//      command control (only if the document doesn't already end with one),
//      via MonaTransactionGateway for mutation.
//   2. The exact feature identity `insertFinalNewLine` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     INSERTFINALNEWLINE feature=live actions=1 commands=1 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaInsertFinalNewLineFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "abc") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/finalnewline-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: insert a final line terminator

    func testInsertsFinalNewLineWhenDocumentDoesNotEndWithOne() {
        let feature = MonaInsertFinalNewLineFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.insertFinalNewLine(gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "abc\n")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testIsNoOpWhenDocumentAlreadyEndsWithNewLine() {
        let feature = MonaInsertFinalNewLineFeature()
        let model = makeModel("abc\n")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.insertFinalNewLine(gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abc\n")
        } else {
            XCTFail("expected dropped when already ending with newline, got \(outcome)")
        }
    }

    func testInsertsFinalNewLineOnMultilineDocument() {
        let feature = MonaInsertFinalNewLineFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)

        _ = feature.insertFinalNewLine(gateway: gateway)
        XCTAssertEqual(model.getValue(), "a\nb\nc\n")
    }

    func testInsertsFinalNewLineOnEmptyDocument() {
        let feature = MonaInsertFinalNewLineFeature()
        let model = makeModel("")
        let gateway = MonaTransactionGateway(model: model)

        _ = feature.insertFinalNewLine(gateway: gateway)
        XCTAssertEqual(model.getValue(), "\n")
    }

    func testIsNoOpWhenDocumentEndsWithCarriageReturnNewline() {
        let feature = MonaInsertFinalNewLineFeature()
        let model = makeModel("abc\r\n")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.insertFinalNewLine(gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abc\r\n")
        } else {
            XCTFail("expected dropped for CR/LF-terminated document, got \(outcome)")
        }
    }

    func testCommandIsNoOpAfterDisposal() {
        let feature = MonaInsertFinalNewLineFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        feature.dispose()

        let outcome = feature.insertFinalNewLine(gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abc")
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

        XCTAssertEqual(MonaInsertFinalNewLineFeature.featureId, "insertFinalNewLine")
        XCTAssertTrue(features.contains("insertFinalNewLine"))

        let actionIds = MonaInsertFinalNewLineFeature.declaredActionIds
        XCTAssertEqual(actionIds, ["editor.action.insertFinalNewLine"])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaInsertFinalNewLineFeature.declaredCommandIds
        XCTAssertEqual(commandIds, ["editor.action.insertFinalNewLine"])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaInsertFinalNewLineFeature.declaredContributionIds, [])
        XCTAssertEqual(MonaInsertFinalNewLineFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaInsertFinalNewLineFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaInsertFinalNewLineFeature.declaredMenuIds, [])
        _ = contributions
        _ = menus
        _ = options
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaInsertFinalNewLineFeature()
        let ticket = gate.captureTicket()

        var received: [MonaInsertFinalNewLineEvent] = []
        let accepted = feature.publishInsertEvent(
            MonaInsertFinalNewLineEvent(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 4),
                    endPosition: MonaPosition(line: 1, column: 4)
                ),
                terminator: "\n"
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
        let feature = MonaInsertFinalNewLineFeature()
        var fired: [MonaInsertFinalNewLineEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaInsertFinalNewLineFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaInsertFinalNewLineFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Insert Final New Line")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaInsertFinalNewLineFeature()
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
        let feature = MonaInsertFinalNewLineFeature()

        let featureLive = features.contains(MonaInsertFinalNewLineFeature.featureId)
        let actionCount = MonaInsertFinalNewLineFeature.declaredActionIds.count
        let commandCount = MonaInsertFinalNewLineFeature.declaredCommandIds.count
        let contribCount = MonaInsertFinalNewLineFeature.declaredContributionIds.count
        let kbCount = MonaInsertFinalNewLineFeature.declaredKeybindingCommands.count
        let optionCount = MonaInsertFinalNewLineFeature.declaredOptionIds.count
        let menuCount = MonaInsertFinalNewLineFeature.declaredMenuIds.count

        let slicePass = MonaInsertFinalNewLineFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaInsertFinalNewLineFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaInsertFinalNewLineFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }

        // Mutation: insert a final newline through the transaction gateway.
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.insertFinalNewLine(gateway: gateway)
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "abc\n" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishInsertEvent(
            MonaInsertFinalNewLineEvent(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 4),
                    endPosition: MonaPosition(line: 1, column: 4)
                ),
                terminator: "\n"
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

        print("INSERTFINALNEWLINE feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
