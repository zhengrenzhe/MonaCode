// MonaBracketMatchingFeatureTests.swift
//
// P05-T101 — Implement retained feature bracketMatching.
//
// Verifies the bracketMatching feature across its three implementation operations:
//   1. Feature-specific behavior: match, navigate, select, and highlight
//      bracket pairs from the active tokenization state.
//   2. The exact feature identity `bracketMatching` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testBracketMatchingContractLeaf` prints the contract line:
//     BRACKETMATCHING feature=live actions=3 commands=3 contributions=1 keybindings=2 options=3 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaBracketMatchingFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: match / navigate / select / highlight

    func testMatchBracketFindsMatchingPairForward() {
        let feature = MonaBracketMatchingFeature()
        let text = "abc (def) ghi"
        // '(' is at line 1, column 5.
        let pair = feature.matchBracket(text: text, position: MonaPosition(line: 1, column: 5))
        XCTAssertNotNil(pair)
        XCTAssertEqual(pair?.open, MonaPosition(line: 1, column: 5))
        XCTAssertEqual(pair?.close, MonaPosition(line: 1, column: 9))
        XCTAssertEqual(pair?.bracket, "(")
    }

    func testMatchBracketFindsMatchingPairBackwardFromClose() {
        let feature = MonaBracketMatchingFeature()
        let text = "abc (def) ghi"
        // ')' is at line 1, column 9 → match opens at column 5.
        let pair = feature.matchBracket(text: text, position: MonaPosition(line: 1, column: 9))
        XCTAssertNotNil(pair)
        XCTAssertEqual(pair?.open, MonaPosition(line: 1, column: 5))
        XCTAssertEqual(pair?.close, MonaPosition(line: 1, column: 9))
    }

    func testMatchBracketRespectsNesting() {
        let feature = MonaBracketMatchingFeature()
        let text = "(a(b)c)"
        // Outer '(' at column 1 → match is the final ')' at column 7.
        let outer = feature.matchBracket(text: text, position: MonaPosition(line: 1, column: 1))
        XCTAssertEqual(outer?.close, MonaPosition(line: 1, column: 7))
        // Inner '(' at column 3 → match is ')' at column 5.
        let inner = feature.matchBracket(text: text, position: MonaPosition(line: 1, column: 3))
        XCTAssertEqual(inner?.close, MonaPosition(line: 1, column: 5))
    }

    func testMatchBracketReturnsNilForNonBracketAndUnmatched() {
        let feature = MonaBracketMatchingFeature()
        let text = "abc (def ghi"
        // Non-bracket position.
        XCTAssertNil(feature.matchBracket(text: text, position: MonaPosition(line: 1, column: 1)))
        // Unmatched '(' (no closer).
        XCTAssertNil(feature.matchBracket(text: text, position: MonaPosition(line: 1, column: 5)))
    }

    func testJumpToBracketReturnsMatchingPosition() {
        let feature = MonaBracketMatchingFeature()
        let text = "x [y] z"
        // '[' at column 3 → jump to ']' at column 5.
        let jump = feature.jumpToBracket(text: text, position: MonaPosition(line: 1, column: 3))
        XCTAssertEqual(jump, MonaPosition(line: 1, column: 5))
        // ']' at column 5 → jump back to '[' at column 3.
        let back = feature.jumpToBracket(text: text, position: MonaPosition(line: 1, column: 5))
        XCTAssertEqual(back, MonaPosition(line: 1, column: 3))
    }

    func testSelectToBracketSelectsThePair() {
        let feature = MonaBracketMatchingFeature()
        let text = "x {ab} z"
        // '{' at column 3 → select to '}' at column 6.
        let selection = feature.selectToBracket(text: text, position: MonaPosition(line: 1, column: 3))
        XCTAssertNotNil(selection)
        XCTAssertEqual(selection?.anchor, MonaPosition(line: 1, column: 3))
        XCTAssertEqual(selection?.activePosition, MonaPosition(line: 1, column: 6))
        XCTAssertEqual(selection?.orientation, .forward)
    }

    func testHighlightBracketPairsReturnsAllCompletePairs() {
        let feature = MonaBracketMatchingFeature()
        let text = "(a(b)c)"
        let pairs = feature.highlightBracketPairs(text: text)
        // Two complete pairs: outer (1,1)-(1,7) and inner (1,3)-(1,5).
        XCTAssertEqual(pairs.count, 2)
        let openCols = pairs.map { $0.open.column }.sorted()
        XCTAssertEqual(openCols, [1, 3])
        let closeCols = pairs.map { $0.close.column }.sorted()
        XCTAssertEqual(closeCols, [5, 7])
    }

    func testHighlightBracketPairsAcrossLines() {
        let feature = MonaBracketMatchingFeature()
        let text = "(\nabc\n)"
        // '(' at (1,1), ')' at (3,1).
        let pairs = feature.highlightBracketPairs(text: text)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs[0].open, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(pairs[0].close, MonaPosition(line: 3, column: 1))
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertTrue(features.contains(MonaBracketMatchingFeature.featureId))
        XCTAssertEqual(MonaBracketMatchingFeature.featureId, "bracketMatching")

        let actionIds = MonaBracketMatchingFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.jumpToBracket",
            "editor.action.selectToBracket",
            "editor.action.removeBrackets"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaBracketMatchingFeature.declaredContributionIds,
                       ["editor.contrib.bracketMatchingController"])
        for id in MonaBracketMatchingFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        // Declared keybindings: jumpToBracket + removeBrackets (selectToBracket
        // carries no default keybinding).
        let kbCommands = MonaBracketMatchingFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands, ["editor.action.jumpToBracket", "editor.action.removeBrackets"])
        let keybindingCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(keybindingCommands.contains(id), "missing keybinding for \(id)")
        }

        // Declared options: matchBrackets, bracketPairColorization, bracketPairGuides.
        let optionIds = MonaBracketMatchingFeature.declaredOptionIds
        XCTAssertEqual(optionIds, ["matchBrackets", "bracketPairColorization", "bracketPairGuides"])
        for name in optionIds {
            XCTAssertNotNil(options.value(for: name), "missing option \(name)")
        }
        // bracketMatching declares no menus.
        XCTAssertTrue(MonaBracketMatchingFeature.declaredMenuIds.isEmpty)
    }

    // MARK: - 3. Routing through shared gateways

    func testModelMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "x {ab} z",
            uri: MonaURI(scheme: "inmemory", path: "/bracket")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaBracketMatchingFeature()
        let committed = feature.commitSelectToBracket(
            gateway: gateway,
            text: model.getValue(),
            position: MonaPosition(line: 1, column: 3)
        )
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 1, column: 3))
        XCTAssertEqual(committed[0].activePosition, MonaPosition(line: 1, column: 6))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "(a)",
            uri: MonaURI(scheme: "inmemory", path: "/bracket-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaBracketMatchingFeature()
        let pairs = feature.highlightBracketPairs(text: model.getValue())
        let ticket = gate.captureTicket()

        var received: [MonaBracketPair] = []
        let accepted = feature.publishBracketPairs(
            pairs,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaBracketMatchingFeature()
        var fired: [MonaBracketMatchingEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.matchBracket(text: "(a)", position: MonaPosition(line: 1, column: 1))
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        _ = feature.matchBracket(text: "(a)", position: MonaPosition(line: 1, column: 1))
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaBracketMatchingFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaBracketMatchingFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Go to Bracket")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaBracketMatchingFeature()
        // bracketMatching degrades to plain-text bracket scanning when no
        // tokenization / grammar is registered (the plain-text fallback).
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
        // Even in degraded mode, matching still works over plain text.
        let pair = feature.matchBracket(text: "(a)", position: MonaPosition(line: 1, column: 1))
        XCTAssertNotNil(pair)
    }

    // MARK: - Contract leaf

    func testBracketMatchingContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let feature = MonaBracketMatchingFeature()

        let featureLive = features.contains(MonaBracketMatchingFeature.featureId)
        let actionCount = MonaBracketMatchingFeature.declaredActionIds.count
        let commandCount = MonaBracketMatchingFeature.declaredCommandIds.count
        let contribCount = MonaBracketMatchingFeature.declaredContributionIds.count
        let kbCount = MonaBracketMatchingFeature.declaredKeybindingCommands.count
        let optionCount = MonaBracketMatchingFeature.declaredOptionIds.count
        let menuCount = MonaBracketMatchingFeature.declaredMenuIds.count

        let slicePass = MonaBracketMatchingFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaBracketMatchingFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaBracketMatchingFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaBracketMatchingFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }

        let model = MonaCodeModel(text: "(a)", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitSelectToBracket(
            gateway: gateway,
            text: model.getValue(),
            position: MonaPosition(line: 1, column: 1)
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let pairs = feature.highlightBracketPairs(text: model.getValue())
        _ = feature.publishBracketPairs(pairs, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("BRACKETMATCHING feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
