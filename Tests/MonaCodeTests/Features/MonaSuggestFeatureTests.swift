// MonaSuggestFeatureTests.swift
//
// P05-T153 — Implement retained feature suggest.
//
// Verifies the suggest feature across its three implementation operations:
//   1. Feature-specific behavior: trigger, filter, rank, resolve, accept,
//      release, and remember completion items (7 operations; reuse
//      `MonaProviderExecutor` P05-T013 + the microtask queue).
//   2. The exact feature identity `suggest` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     SUGGEST feature=live actions=2 commands=20 contributions=1 keybindings=14 options=10 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaSuggestFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "abc") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/suggest-\(UUID().uuidString)")
        )
    }

    private func insertRange() -> MonaRange {
        return MonaRange(
            startPosition: MonaPosition(line: 1, column: 4),
            endPosition: MonaPosition(line: 1, column: 4)
        )
    }

    /// A test suggest provider: supplies three items (foo, bar, foobar) with
    /// distinct sortText / filterText, and resolves documentation on resolve.
    private final class TestSuggestProvider: MonaSuggestProvider {
        var lastContext: MonaCompletionContext?
        var resolvedLabels: [String] = []
        func provideCompletions(
            modelVersion: Int,
            context: MonaCompletionContext
        ) -> MonaCompletionList {
            lastContext = context
            let range = MonaRange(
                startPosition: MonaPosition(line: 1, column: 4),
                endPosition: MonaPosition(line: 1, column: 4)
            )
            return MonaCompletionList(items: [
                MonaCompletionItem(
                    label: "foo", kind: .function, insertText: "foo",
                    filterText: "foo", sortText: "b", range: range
                ),
                MonaCompletionItem(
                    label: "bar", kind: .method, insertText: "bar",
                    filterText: "bar", sortText: "a", range: range
                ),
                MonaCompletionItem(
                    label: "foobar", kind: .variable, insertText: "foobar",
                    filterText: "foobar", sortText: "c", range: range
                )
            ], isIncomplete: false)
        }
        func resolveCompletion(_ item: MonaCompletionItem) -> MonaCompletionItem {
            resolvedLabels.append(item.label)
            return MonaCompletionItem(
                label: item.label,
                kind: item.kind,
                detail: item.detail,
                insertText: item.insertText,
                filterText: item.filterText,
                sortText: item.sortText,
                range: item.range,
                documentation: "docs for \(item.label)"
            )
        }
    }

    // MARK: - 1. Feature-specific behavior: trigger / filter / rank / resolve / accept / release / remember

    func testTriggerStagesAndRetainsByVersion() {
        let feature = MonaSuggestFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let context = MonaCompletionContext(triggerKind: .manual, triggerCharacter: nil)

        let list = feature.trigger(provider: provider, modelVersion: version, context: context)

        XCTAssertEqual(list!.items.count, 3)
        XCTAssertEqual(provider.lastContext?.triggerKind, .manual)
        XCTAssertEqual(feature.stagedItems.count, 3)
        XCTAssertEqual(feature.retainedCount(for: version), 3)
    }

    func testFilterReturnsItemsMatchingQuery() {
        let feature = MonaSuggestFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        _ = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))

        let filtered = feature.filter("foo")
        // foo and foobar match; bar does not.
        XCTAssertEqual(filtered.map { $0.label }, ["foo", "foobar"])
    }

    func testRankOrdersBySortText() {
        let feature = MonaSuggestFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let list = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))

        let ranked = feature.rank(list!.items)
        XCTAssertEqual(ranked.map { $0.label }, ["bar", "foo", "foobar"])
    }

    func testResolveEnrichesDocumentationThroughProvider() {
        let feature = MonaSuggestFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let list = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))

        let resolved = feature.resolve(list!.items[0], provider: provider)
        XCTAssertEqual(resolved?.documentation, "docs for foo")
        XCTAssertEqual(provider.resolvedLabels, ["foo"])
    }

    func testAcceptAppliesInsertTextThroughGateway() {
        let feature = MonaSuggestFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let list = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))

        let outcome = feature.accept(list!.items[0], gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "abcfoo")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testReleaseDropsRetainedItemsForStaleVersion() {
        let feature = MonaSuggestFeature()
        let model = makeModel()
        let v1 = model.getVersionId()
        let provider = TestSuggestProvider()
        _ = feature.trigger(provider: provider, modelVersion: v1, context: .init(triggerKind: .manual, triggerCharacter: nil))
        XCTAssertEqual(feature.retainedCount(for: v1), 3)

        let released = feature.release(modelVersion: v1)
        XCTAssertEqual(released, 3)
        XCTAssertEqual(feature.retainedCount(for: v1), 0)
    }

    func testRememberRecordsSelectedItem() {
        let feature = MonaSuggestFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let list = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))

        let remembered = feature.remember(list!.items[1])
        XCTAssertTrue(remembered)
        XCTAssertEqual(feature.rememberedItem(for: "bar")?.label, "bar")
        // Remembering the same label again is a no-op (already remembered).
        let again = feature.remember(list!.items[1])
        XCTAssertFalse(again)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaSuggestFeature.featureId, "suggest")
        XCTAssertTrue(features.contains("suggest"))

        XCTAssertEqual(MonaSuggestFeature.declaredActionIds, [
            "editor.action.triggerSuggest",
            "editor.action.resetSuggestSize"
        ])
        for id in MonaSuggestFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSuggestFeature.declaredCommandIds, [
            "acceptAlternativeSelectedSuggestion",
            "acceptSelectedSuggestion",
            "acceptSelectedSuggestionOnEnter",
            "editor.action.resetSuggestSize",
            "editor.action.triggerSuggest",
            "focusAndAcceptSuggestion",
            "focusSuggestion",
            "hideSuggestWidget",
            "insertBestCompletion",
            "insertNextSuggestion",
            "insertPrevSuggestion",
            "selectFirstSuggestion",
            "selectLastSuggestion",
            "selectNextPageSuggestion",
            "selectNextSuggestion",
            "selectPrevPageSuggestion",
            "selectPrevSuggestion",
            "suggestWidgetCopy",
            "toggleSuggestionDetails",
            "toggleSuggestionFocus"
        ])
        for id in MonaSuggestFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSuggestFeature.declaredContributionIds, [
            "editor.contrib.suggestController"
        ])
        for id in MonaSuggestFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaSuggestFeature.declaredKeybindingCommands, [
            "acceptAlternativeSelectedSuggestion",
            "acceptSelectedSuggestion",
            "editor.action.triggerSuggest",
            "focusSuggestion",
            "hideSuggestWidget",
            "insertNextSuggestion",
            "insertPrevSuggestion",
            "selectNextPageSuggestion",
            "selectNextSuggestion",
            "selectPrevPageSuggestion",
            "selectPrevSuggestion",
            "suggestWidgetCopy",
            "toggleSuggestionDetails",
            "toggleSuggestionFocus"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaSuggestFeature.declaredKeybindingCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }

        XCTAssertEqual(MonaSuggestFeature.declaredOptionIds, [
            "acceptSuggestionOnCommitCharacter",
            "acceptSuggestionOnEnter",
            "quickSuggestions",
            "quickSuggestionsDelay",
            "suggest",
            "suggestFontSize",
            "suggestLineHeight",
            "suggestOnTriggerCharacters",
            "suggestSelection",
            "tabCompletion"
        ])

        XCTAssertEqual(MonaSuggestFeature.declaredMenuIds, [
            "suggestWidgetStatusBar"
        ])
        for id in MonaSuggestFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaSuggestFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let list = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))

        let outcome = feature.accept(list!.items[2], gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "abcfoobar")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaSuggestFeature()
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let list = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))
        let ticket = gate.captureTicket()

        var received: [MonaCompletionItem]?
        let accepted = feature.publishCompletions(
            list!.items,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, list!.items)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaSuggestFeature()
        var fired: [MonaSuggestEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, trigger / accept / release / remember are no-ops.
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let list = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))
        XCTAssertNil(list)
        XCTAssertTrue(feature.stagedItems.isEmpty)
        let outcome = feature.accept(
            MonaCompletionItem(label: "x", kind: .text, insertText: "x", range: insertRange()),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "abc")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
        XCTAssertEqual(feature.release(modelVersion: version), 0)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaSuggestFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaSuggestFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Trigger Suggest")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaSuggestFeature()
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
        let feature = MonaSuggestFeature()

        let featureLive = features.contains(MonaSuggestFeature.featureId)
        let actionCount = MonaSuggestFeature.declaredActionIds.count
        let commandCount = MonaSuggestFeature.declaredCommandIds.count
        let contribCount = MonaSuggestFeature.declaredContributionIds.count
        let kbCount = MonaSuggestFeature.declaredKeybindingCommands.count
        let optionCount = MonaSuggestFeature.declaredOptionIds.count
        let menuCount = MonaSuggestFeature.declaredMenuIds.count

        let slicePass = MonaSuggestFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaSuggestFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaSuggestFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaSuggestFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaSuggestFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Trigger: stage 3 items.
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let provider = TestSuggestProvider()
        let list = feature.trigger(provider: provider, modelVersion: version, context: .init(triggerKind: .manual, triggerCharacter: nil))
        let triggerPass = list!.items.count == 3 && feature.stagedItems.count == 3

        // Filter + rank.
        let filtered = feature.filter("foo")
        let ranked = feature.rank(list!.items)
        let filterRankPass = filtered.count == 2 && ranked.first?.label == "bar"

        // Resolve.
        let resolved = feature.resolve(list!.items[0], provider: provider)
        let resolvePass = resolved?.documentation == "docs for foo"

        // Accept: insert "foobar" (the third item) through the gateway.
        let mutation: Bool
        let outcome = feature.accept(list!.items[2], gateway: gateway)
        if case .applied = outcome, model.getValue() == "abcfoobar" {
            mutation = true
        } else {
            mutation = false
        }

        // Remember + release.
        let remembered = feature.remember(list!.items[1])
        let released = feature.release(modelVersion: version)
        let rememberReleasePass = remembered && released == 3

        // Async publication.
        let pubModel = makeModel("abc")
        let pubVersion = pubModel.getVersionId()
        let pubProvider = TestSuggestProvider()
        let pubList = feature.trigger(provider: pubProvider, modelVersion: pubVersion, context: .init(triggerKind: .manual, triggerCharacter: nil))
        let pubGate = MonaPublicationGate(model: pubModel)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: pubGate, queue: queue)
        var delivered = false
        _ = feature.publishCompletions(pubList!.items, executor: executor, ticket: pubGate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("SUGGEST feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(triggerPass)
        XCTAssertTrue(filterRankPass)
        XCTAssertTrue(resolvePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(rememberReleasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
