// MonaGotoSymbolFeatureTests.swift
//
// P05-T124 — Implement retained feature gotoSymbol.
//
// Verifies the gotoSymbol feature across its three implementation operations:
//   1. Feature-specific behavior: filter and navigate document symbols while
//      preserving provider order (reuse T115 `MonaDocumentSymbolsFeature`'s
//      symbol results).
//   2. The exact feature identity `gotoSymbol` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testGotoSymbolContractLeaf` prints the contract line:
//     GOTOSYMBOL feature=live actions=0 commands=2 contributions=0 keybindings=2 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaGotoSymbolFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: filter + navigate (provider order)

    private func makeSymbols() -> [MonaDocumentSymbol] {
        // Provider order is preserved by gotoSymbol: the symbols arrive already
        // ordered by `MonaDocumentSymbolsFeature` (range start, then name). We
        // construct them in that order so the filter preserves it.
        return [
            MonaDocumentSymbol(
                name: "alpha",
                kind: .function,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 10)
                ),
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 5),
                    endPosition: MonaPosition(line: 1, column: 10)
                )
            ),
            MonaDocumentSymbol(
                name: "betaAlpha",
                kind: .method,
                range: MonaRange(
                    startPosition: MonaPosition(line: 3, column: 1),
                    endPosition: MonaPosition(line: 3, column: 12)
                ),
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 3, column: 5),
                    endPosition: MonaPosition(line: 3, column: 12)
                )
            ),
            MonaDocumentSymbol(
                name: "gamma",
                kind: .variable,
                range: MonaRange(
                    startPosition: MonaPosition(line: 5, column: 1),
                    endPosition: MonaPosition(line: 5, column: 10)
                ),
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 5, column: 5),
                    endPosition: MonaPosition(line: 5, column: 10)
                )
            )
        ]
    }

    func testFilterPreservesProviderOrderAndMatchesCaseInsensitively() {
        let feature = MonaGotoSymbolFeature()
        let symbols = makeSymbols()
        // "alpha" matches both "alpha" and "betaAlpha" (case-insensitive).
        let filtered = feature.filterSymbols(symbols, query: "alpha")
        XCTAssertEqual(filtered.count, 2)
        // Provider order preserved: "alpha" before "betaAlpha".
        XCTAssertEqual(filtered[0].name, "alpha")
        XCTAssertEqual(filtered[1].name, "betaAlpha")
    }

    func testFilterEmptyQueryReturnsAllSymbolsInProviderOrder() {
        let feature = MonaGotoSymbolFeature()
        let symbols = makeSymbols()
        let filtered = feature.filterSymbols(symbols, query: "")
        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered.map { $0.name }, ["alpha", "betaAlpha", "gamma"])
    }

    func testFilterNoMatchReturnsEmpty() {
        let feature = MonaGotoSymbolFeature()
        let symbols = makeSymbols()
        let filtered = feature.filterSymbols(symbols, query: "zzz")
        XCTAssertTrue(filtered.isEmpty)
    }

    func testNavigateNextWalksFilteredOrderWithWrapAround() {
        let feature = MonaGotoSymbolFeature()
        let symbols = makeSymbols()
        feature.setSymbols(symbols)
        let first = feature.navigate(.next)
        XCTAssertEqual(first?.name, "alpha")
        let second = feature.navigate(.next)
        XCTAssertEqual(second?.name, "betaAlpha")
        let third = feature.navigate(.next)
        XCTAssertEqual(third?.name, "gamma")
        // Wrap-around to the first symbol.
        let fourth = feature.navigate(.next)
        XCTAssertEqual(fourth?.name, "alpha")
    }

    func testNavigatePrevWrapsToLastFromNoSelection() {
        let feature = MonaGotoSymbolFeature()
        let symbols = makeSymbols()
        feature.setSymbols(symbols)
        let prev = feature.navigate(.prev)
        XCTAssertEqual(prev?.name, "gamma")
        let prev2 = feature.navigate(.prev)
        XCTAssertEqual(prev2?.name, "betaAlpha")
    }

    func testNavigateAfterFilterUsesFilteredList() {
        let feature = MonaGotoSymbolFeature()
        let symbols = makeSymbols()
        let filtered = feature.filterSymbols(symbols, query: "alpha")
        feature.setSymbols(filtered)
        let first = feature.navigate(.next)
        XCTAssertEqual(first?.name, "alpha")
        let second = feature.navigate(.next)
        XCTAssertEqual(second?.name, "betaAlpha")
        // Wrap-around within the filtered list (2 symbols).
        let third = feature.navigate(.next)
        XCTAssertEqual(third?.name, "alpha")
    }

    func testNavigateFiresEventWithSelectedSymbolAndIndex() {
        let feature = MonaGotoSymbolFeature()
        var events: [MonaGotoSymbolEvent] = []
        _ = feature.onChange { events.append($0) }
        feature.setSymbols(makeSymbols())
        _ = feature.navigate(.next)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].selectedSymbol?.name, "alpha")
        XCTAssertEqual(events[0].index, 0)
    }

    func testNavigateReturnsNilWhenEmpty() {
        let feature = MonaGotoSymbolFeature()
        feature.setSymbols([])
        XCTAssertNil(feature.navigate(.next))
        XCTAssertNil(feature.navigate(.prev))
    }

    func testNavigateIsNoOpAfterDispose() {
        let feature = MonaGotoSymbolFeature()
        feature.setSymbols(makeSymbols())
        feature.dispose()
        XCTAssertNil(feature.navigate(.next))
        XCTAssertTrue(feature.isDisposed)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()

        XCTAssertTrue(features.contains(MonaGotoSymbolFeature.featureId))
        XCTAssertEqual(MonaGotoSymbolFeature.featureId, "gotoSymbol")

        // gotoSymbol owns no labeled actions (its slice is command-only).
        XCTAssertTrue(MonaGotoSymbolFeature.declaredActionIds.isEmpty)
        for id in MonaGotoSymbolFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // The declared command set: symbol-result navigation (next + cancel).
        XCTAssertEqual(
            MonaGotoSymbolFeature.declaredCommandIds,
            ["editor.gotoNextSymbolFromResult", "editor.gotoNextSymbolFromResult.cancel"]
        )
        for id in MonaGotoSymbolFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // gotoSymbol owns no contribution / option / menu of its own.
        XCTAssertTrue(MonaGotoSymbolFeature.declaredContributionIds.isEmpty)
        XCTAssertTrue(MonaGotoSymbolFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaGotoSymbolFeature.declaredMenuIds.isEmpty)

        let kbCommands = MonaGotoSymbolFeature.declaredKeybindingCommands
        XCTAssertEqual(
            kbCommands,
            ["editor.gotoNextSymbolFromResult", "editor.gotoNextSymbolFromResult.cancel"]
        )
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "alpha\nbeta\ngamma",
            uri: MonaURI(scheme: "inmemory", path: "/gotosymbol")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaGotoSymbolFeature()
        feature.setSymbols(makeSymbols())
        _ = feature.navigate(.next)
        let committed = feature.commitNavigate(gateway: gateway)
        XCTAssertEqual(committed.count, 1)
        // The reveal targets the selected symbol's selectionRange start (1,5).
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 1, column: 5))
        XCTAssertEqual(committed[0].activePosition, MonaPosition(line: 1, column: 5))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "a\nb",
            uri: MonaURI(scheme: "inmemory", path: "/gotosymbol-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaGotoSymbolFeature()
        feature.setSymbols(makeSymbols())
        _ = feature.navigate(.next)
        let event = MonaGotoSymbolEvent(
            selectedSymbol: feature.selectedSymbol,
            index: 0
        )
        let ticket = gate.captureTicket()

        var received: [MonaGotoSymbolEvent] = []
        let accepted = feature.publishGotoSymbolEvent(
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
        let feature = MonaGotoSymbolFeature()
        var fired: [MonaGotoSymbolEvent] = []
        _ = feature.onChange { fired.append($0) }
        feature.setSymbols(makeSymbols())
        _ = feature.navigate(.next)
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        _ = feature.navigate(.next)
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaGotoSymbolFeature()
        // gotoSymbol owns no labeled actions, so the localized set is empty
        // under every profile. The route still resolves through MonaLocalization.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaGotoSymbolFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaGotoSymbolFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testGotoSymbolContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let feature = MonaGotoSymbolFeature()

        let featureLive = features.contains(MonaGotoSymbolFeature.featureId)
        let actionCount = MonaGotoSymbolFeature.declaredActionIds.count
        let commandCount = MonaGotoSymbolFeature.declaredCommandIds.count
        let contribCount = MonaGotoSymbolFeature.declaredContributionIds.count
        let kbCount = MonaGotoSymbolFeature.declaredKeybindingCommands.count
        let optionCount = MonaGotoSymbolFeature.declaredOptionIds.count
        let menuCount = MonaGotoSymbolFeature.declaredMenuIds.count

        let slicePass = MonaGotoSymbolFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
        let kbPass = MonaGotoSymbolFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }

        // Filter + navigate: filter "alpha" → [alpha, betaAlpha], navigate next.
        let filtered = feature.filterSymbols(makeSymbols(), query: "alpha")
        let filterPass = filtered.count == 2 && filtered[0].name == "alpha"
            && filtered[1].name == "betaAlpha"
        feature.setSymbols(filtered)
        let nav = feature.navigate(.next)
        let navPass = nav?.name == "alpha"

        // Mutation: reveal the selected symbol through the transaction gateway.
        let model = MonaCodeModel(
            text: "alpha\nbeta\ngamma",
            uri: MonaURI(scheme: "inmemory", path: "/leaf")
        )
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitNavigate(gateway: gateway).count == 1
            && gateway.lastCommittedSelections.count == 1

        // Async: publish a goto-symbol event through the provider executor.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let event = MonaGotoSymbolEvent(selectedSymbol: feature.selectedSymbol, index: 0)
        _ = feature.publishGotoSymbolEvent(event, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("GOTOSYMBOL feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(kbPass)
        XCTAssertTrue(filterPass)
        XCTAssertTrue(navPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
