// MonaFindFeatureTests.swift
//
// P05-T117 — Implement retained feature find.
//
// Verifies the find feature across its three implementation operations:
//   1. Feature-specific behavior: run literal and RegExp find and replace with
//      exact match, scope, and history semantics. Literal find reuses
//      `MonaLiteralSearch` (P02-T003); RegExp find reuses `MonaRegExpParser` /
//      `MonaRegExpExecutor` (P02-T004); replacement reuses `MonaReplacePattern`
//      (P02-T003). Replace edits route through `MonaTransactionGateway`.
//   2. The exact feature identity `find` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     FIND feature=live actions=9 commands=17 contributions=1 keybindings=15 options=1 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaFindFeatureTests: XCTestCase {

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/find-\(UUID().uuidString)")
        )
    }

    private func range(_ sl: Int, _ sc: Int, _ el: Int, _ ec: Int) -> MonaRange {
        return MonaRange(
            startPosition: MonaPosition(line: sl, column: sc),
            endPosition: MonaPosition(line: el, column: ec)
        )
    }

    // MARK: - 1. Feature-specific behavior: literal / RegExp find + replace + history

    func testFindLiteralMatchesReturnsAllMatchesAsRanges() {
        let feature = MonaFindFeature()
        let model = makeModel("hello world hello")
        let query = MonaFindQuery(searchString: "hello")

        let result = feature.findMatches(in: model, query: query)

        XCTAssertEqual(result.matches, [
            range(1, 1, 1, 6),
            range(1, 13, 1, 18)
        ])
    }

    func testFindLiteralCaseInsensitiveMatchesWhenMatchCaseFalse() {
        let feature = MonaFindFeature()
        let model = makeModel("Hello hello HELLO")
        let query = MonaFindQuery(searchString: "hello", matchCase: false)

        let result = feature.findMatches(in: model, query: query)

        XCTAssertEqual(result.matches.count, 3)
    }

    func testFindLiteralExactMatchIsCaseSensitiveByDefault() {
        let feature = MonaFindFeature()
        let model = makeModel("Hello hello HELLO")
        let query = MonaFindQuery(searchString: "hello")  // matchCase defaults to true

        let result = feature.findMatches(in: model, query: query)

        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first, range(1, 7, 1, 12))
    }

    func testFindRegExpMatchesUsesRegExpExecutor() {
        let feature = MonaFindFeature()
        let model = makeModel("a1 b2 c3")
        let query = MonaFindQuery(searchString: "[a-z][0-9]", isRegex: true)

        let result = feature.findMatches(in: model, query: query)

        XCTAssertEqual(result.matches, [
            range(1, 1, 1, 3),
            range(1, 4, 1, 6),
            range(1, 7, 1, 9)
        ])
    }

    func testFindWholeWordFiltersNonWordBoundaryMatches() {
        let feature = MonaFindFeature()
        let model = makeModel("foo foobar foo")
        let query = MonaFindQuery(searchString: "foo", wholeWord: true)

        let result = feature.findMatches(in: model, query: query)

        XCTAssertEqual(result.matches, [
            range(1, 1, 1, 4),
            range(1, 12, 1, 15)
        ])
    }

    func testFindInSelectionScopesMatchesToSelectionRange() {
        let feature = MonaFindFeature()
        let model = makeModel("foo foo foo")
        let query = MonaFindQuery(searchString: "foo", findInSelection: true)
        // Scope to the middle "foo" only (columns 5..8).
        let scope = range(1, 5, 1, 8)

        let result = feature.findMatches(in: model, query: query, scope: scope)

        XCTAssertEqual(result.matches, [range(1, 5, 1, 8)])
    }

    func testReplaceAllRoutesEditsThroughTransactionGateway() {
        let feature = MonaFindFeature()
        let model = makeModel("hello world hello")
        let gateway = MonaTransactionGateway(model: model)
        let query = MonaFindQuery(searchString: "hello")

        let outcome = feature.replaceAll(
            in: model,
            query: query,
            replaceString: "HELLO",
            gateway: gateway
        )

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "HELLO world HELLO")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testReplaceNextReplacesFirstMatchThroughGateway() {
        let feature = MonaFindFeature()
        let model = makeModel("hello world hello")
        let gateway = MonaTransactionGateway(model: model)
        let query = MonaFindQuery(searchString: "hello")

        let outcome = feature.replaceNext(
            in: model,
            query: query,
            replaceString: "HELLO",
            gateway: gateway
        )

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "HELLO world hello")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testReplaceAllRegExpWithCaptureGroupSubstitution() {
        let feature = MonaFindFeature()
        let model = makeModel("a1 b2")
        let gateway = MonaTransactionGateway(model: model)
        let query = MonaFindQuery(searchString: "([a-z])([0-9])", isRegex: true)

        let outcome = feature.replaceAll(
            in: model,
            query: query,
            replaceString: "$2$1",
            gateway: gateway
        )

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "1a 2b")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testFindHistoryRecordsAndRetainsSearchHistory() {
        let feature = MonaFindFeature()
        feature.recordSearchHistory("foo")
        feature.recordSearchHistory("bar")
        feature.recordSearchHistory("foo")

        // The most recent entry is first; duplicates are de-duplicated.
        XCTAssertEqual(feature.searchHistory.first, "foo")
        XCTAssertEqual(feature.searchHistory.count, 2)
    }

    func testFindHistoryRecordsAndRetainsReplaceHistory() {
        let feature = MonaFindFeature()
        feature.recordReplaceHistory("XYZ")
        XCTAssertEqual(feature.replaceHistory, ["XYZ"])
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaFindFeature.featureId, "find")
        XCTAssertTrue(features.contains("find"))

        XCTAssertEqual(MonaFindFeature.declaredActionIds, [
            "actions.find",
            "editor.action.nextMatchFindAction",
            "editor.action.previousMatchFindAction",
            "editor.action.startFindReplaceAction",
            "editor.actions.findWithArgs",
            "actions.findWithSelection",
            "editor.action.goToMatchFindAction",
            "editor.action.nextSelectionMatchFindAction",
            "editor.action.previousSelectionMatchFindAction"
        ])
        for id in MonaFindFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaFindFeature.declaredCommandIds, [
            "actions.find",
            "actions.findWithSelection",
            "closeFindWidget",
            "editor.action.goToMatchFindAction",
            "editor.action.nextMatchFindAction",
            "editor.action.nextSelectionMatchFindAction",
            "editor.action.previousMatchFindAction",
            "editor.action.previousSelectionMatchFindAction",
            "editor.action.replaceAll",
            "editor.action.replaceOne",
            "editor.action.selectAllMatches",
            "editor.action.startFindReplaceAction",
            "editor.actions.findWithArgs",
            "toggleFindCaseSensitive",
            "toggleFindInSelection",
            "toggleFindRegex",
            "toggleFindWholeWord"
        ])
        for id in MonaFindFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaFindFeature.declaredContributionIds, [
            "editor.contrib.findController"
        ])
        for id in MonaFindFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaFindFeature.declaredKeybindingCommands, [
            "actions.find",
            "actions.findWithSelection",
            "closeFindWidget",
            "editor.action.nextMatchFindAction",
            "editor.action.nextSelectionMatchFindAction",
            "editor.action.previousMatchFindAction",
            "editor.action.previousSelectionMatchFindAction",
            "editor.action.replaceAll",
            "editor.action.replaceOne",
            "editor.action.selectAllMatches",
            "editor.action.startFindReplaceAction",
            "toggleFindCaseSensitive",
            "toggleFindInSelection",
            "toggleFindRegex",
            "toggleFindWholeWord"
        ])

        XCTAssertEqual(MonaFindFeature.declaredOptionIds, ["find"])
        XCTAssertNotNil(options.value(for: "find"))

        XCTAssertEqual(MonaFindFeature.declaredMenuIds, ["MenubarEditMenu"])
        for id in MonaFindFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaFindFeature()
        let ticket = gate.captureTicket()
        let result = MonaFindResult(matches: [range(1, 1, 1, 4)])

        var received: MonaFindResult?
        let accepted = feature.publishFindResult(
            result,
            executor: executor,
            ticket: ticket
        ) { event in received = event }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.matches.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaFindFeature()
        var fired: [MonaFindEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, find / replace are no-ops.
        let model = makeModel("hello")
        let result = feature.findMatches(in: model, query: MonaFindQuery(searchString: "hello"))
        XCTAssertTrue(result.matches.isEmpty)
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.replaceAll(
            in: model,
            query: MonaFindQuery(searchString: "hello"),
            replaceString: "X",
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "hello")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaFindFeature()
        let enActionLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enActionLabels.count, MonaFindFeature.declaredActionIds.count)
        XCTAssertEqual(enActionLabels.first, "Find")
        let pseudoActionLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoActionLabels.allSatisfy { $0.hasPrefix("\u{FF3B}") && $0.hasSuffix("\u{FF3D}") })
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaFindFeature()
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
        let options = MonaOptionStore()
        let feature = MonaFindFeature()

        let featureLive = features.contains(MonaFindFeature.featureId)
        let actionCount = MonaFindFeature.declaredActionIds.count
        let commandCount = MonaFindFeature.declaredCommandIds.count
        let contribCount = MonaFindFeature.declaredContributionIds.count
        let kbCount = MonaFindFeature.declaredKeybindingCommands.count
        let optionCount = MonaFindFeature.declaredOptionIds.count
        let menuCount = MonaFindFeature.declaredMenuIds.count

        let slicePass = MonaFindFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaFindFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaFindFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaFindFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaFindFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaFindFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Literal find + exact match + scope + history.
        let model = makeModel("hello world hello")
        let query = MonaFindQuery(searchString: "hello")
        let result = feature.findMatches(in: model, query: query)
        let findPass = result.matches.count == 2
            && result.matches.first == range(1, 1, 1, 6)
        feature.recordSearchHistory("hello")

        // RegExp find (reuses MonaRegExpParser / MonaRegExpExecutor).
        let regexResult = feature.findMatches(
            in: model,
            query: MonaFindQuery(searchString: "h.*?o", isRegex: true)
        )
        let regexPass = !regexResult.matches.isEmpty

        // Mutation: replace all routes edits through the gateway.
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.replaceAll(
            in: model,
            query: query,
            replaceString: "HELLO",
            gateway: gateway
        )
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "HELLO world HELLO" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishFindResult(
            MonaFindResult(matches: []),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let actionLabelCount = feature.localizedActionLabels(profile: .default).count
        let localizationPass = actionLabelCount == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("FIND feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(findPass)
        XCTAssertTrue(regexPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
