// MonaGotoLineFeatureTests.swift
//
// P05-T123 — Implement retained feature gotoLine.
//
// Verifies the gotoLine feature across its three implementation operations:
//   1. Feature-specific behavior: parse line and column input (line, line:column,
//      line,column), validate the parsed coordinate through the base-model
//      `MonaPosition` validation (P01-T001), and reveal the validated model
//      position through the shared `MonaTransactionGateway`.
//   2. The exact feature identity `gotoLine` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testGotoLineContractLeaf` prints the contract line:
//     GOTOLINE feature=live actions=1 commands=1 contributions=0 keybindings=1 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaGotoLineFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: parse + validate + reveal

    func testParseLineOnlyDefaultsColumnToOne() {
        let feature = MonaGotoLineFeature()
        let parsed = feature.parse("10")
        XCTAssertEqual(parsed?.line, 10)
        XCTAssertEqual(parsed?.column, 1)
    }

    func testParseLineColonColumn() {
        let feature = MonaGotoLineFeature()
        let parsed = feature.parse("10:5")
        XCTAssertEqual(parsed?.line, 10)
        XCTAssertEqual(parsed?.column, 5)
    }

    func testParseLineCommaColumn() {
        let feature = MonaGotoLineFeature()
        let parsed = feature.parse("10,5")
        XCTAssertEqual(parsed?.line, 10)
        XCTAssertEqual(parsed?.column, 5)
    }

    func testParseTrimsWhitespace() {
        let feature = MonaGotoLineFeature()
        let parsed = feature.parse("  10 : 5  ")
        XCTAssertEqual(parsed?.line, 10)
        XCTAssertEqual(parsed?.column, 5)
    }

    func testParseRejectsNonNumeric() {
        let feature = MonaGotoLineFeature()
        XCTAssertNil(feature.parse("abc"))
        XCTAssertNil(feature.parse(""))
        XCTAssertNil(feature.parse("10:xyz"))
    }

    func testValidateRejectsBelowMinimumInStrictMode() {
        let feature = MonaGotoLineFeature()
        XCTAssertNil(feature.validate(line: 0, column: 1, mode: .strict))
        XCTAssertNil(feature.validate(line: 1, column: 0, mode: .strict))
        XCTAssertNotNil(feature.validate(line: 1, column: 1, mode: .strict))
    }

    func testValidateClampsInRelaxedMode() {
        let feature = MonaGotoLineFeature()
        let pos = feature.validate(line: -3, column: -7, mode: .relaxed)
        XCTAssertEqual(pos?.line, 1)
        XCTAssertEqual(pos?.column, 1)
    }

    func testParseAndValidateCombinesParseAndStrictValidation() {
        let feature = MonaGotoLineFeature()
        let valid = feature.parseAndValidate("10:5", mode: .strict)
        XCTAssertEqual(valid?.line, 10)
        XCTAssertEqual(valid?.column, 5)
        // Invalid input → nil.
        XCTAssertNil(feature.parseAndValidate("abc", mode: .strict))
        XCTAssertNil(feature.parseAndValidate("0:1", mode: .strict))
    }

    func testRevealFiresEventWithValidatedPosition() {
        let feature = MonaGotoLineFeature()
        var events: [MonaGotoLineEvent] = []
        _ = feature.onChange { events.append($0) }
        _ = feature.parseAndValidate("3:2", mode: .strict)
        feature.reveal(position: MonaPosition(line: 3, column: 2))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].revealedPosition, MonaPosition(line: 3, column: 2))
    }

    func testCommitRevealRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "abc\ndef\nghi",
            uri: MonaURI(scheme: "inmemory", path: "/gotoline")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaGotoLineFeature()
        let position = MonaPosition(line: 2, column: 2)
        let committed = feature.commitReveal(gateway: gateway, position: position)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, position)
        XCTAssertEqual(committed[0].activePosition, position)
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testRevealIsNoOpAfterDispose() {
        let feature = MonaGotoLineFeature()
        feature.dispose()
        feature.reveal(position: MonaPosition(line: 1, column: 1))
        XCTAssertTrue(feature.isDisposed)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()

        XCTAssertTrue(features.contains(MonaGotoLineFeature.featureId))
        XCTAssertEqual(MonaGotoLineFeature.featureId, "gotoLine")

        XCTAssertEqual(MonaGotoLineFeature.declaredActionIds, ["editor.action.gotoLine"])
        for id in MonaGotoLineFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaGotoLineFeature.declaredCommandIds, ["editor.action.gotoLine"])

        // gotoLine owns no contribution / option / menu of its own.
        XCTAssertTrue(MonaGotoLineFeature.declaredContributionIds.isEmpty)
        XCTAssertTrue(MonaGotoLineFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaGotoLineFeature.declaredMenuIds.isEmpty)

        let kbCommands = MonaGotoLineFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands, ["editor.action.gotoLine"])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "a\nb",
            uri: MonaURI(scheme: "inmemory", path: "/gotoline-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaGotoLineFeature()
        let position = MonaPosition(line: 1, column: 1)
        feature.reveal(position: position)
        let event = MonaGotoLineEvent(revealedPosition: position)
        let ticket = gate.captureTicket()

        var received: [MonaGotoLineEvent] = []
        let accepted = feature.publishGotoLineEvent(
            event,
            executor: executor,
            ticket: ticket
        ) { delivered in received = [delivered] }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], event)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaGotoLineFeature()
        var fired: [MonaGotoLineEvent] = []
        _ = feature.onChange { fired.append($0) }
        feature.reveal(position: MonaPosition(line: 1, column: 1))
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.reveal(position: MonaPosition(line: 1, column: 1))
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaGotoLineFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaGotoLineFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Go to Line/Column...")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaGotoLineFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testGotoLineContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let feature = MonaGotoLineFeature()

        let featureLive = features.contains(MonaGotoLineFeature.featureId)
        let actionCount = MonaGotoLineFeature.declaredActionIds.count
        let commandCount = MonaGotoLineFeature.declaredCommandIds.count
        let contribCount = MonaGotoLineFeature.declaredContributionIds.count
        let kbCount = MonaGotoLineFeature.declaredKeybindingCommands.count
        let optionCount = MonaGotoLineFeature.declaredOptionIds.count
        let menuCount = MonaGotoLineFeature.declaredMenuIds.count

        let slicePass = MonaGotoLineFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaGotoLineFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
        let kbPass = MonaGotoLineFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }

        // Parse + validate: "3:2" → position (3,2), validated strict.
        let parsed = feature.parse("3:2")
        let validated = feature.validate(line: parsed?.line ?? 0, column: parsed?.column ?? 0, mode: .strict)
        let parseValidatePass = parsed?.line == 3 && parsed?.column == 2
            && validated == MonaPosition(line: 3, column: 2)
        feature.reveal(position: validated!)

        // Mutation: reveal the validated position through the transaction gateway.
        let model = MonaCodeModel(text: "a\nb\nc", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitReveal(
            gateway: gateway,
            position: MonaPosition(line: 2, column: 1)
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        // Async: publish a goto-line event through the provider executor.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let event = MonaGotoLineEvent(revealedPosition: MonaPosition(line: 2, column: 1))
        _ = feature.publishGotoLineEvent(event, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("GOTOLINE feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(kbPass)
        XCTAssertTrue(parseValidatePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
