// MonaWordHighlighterFeatureTests.swift
//
// P05-T159 — Implement retained feature wordHighlighter.
//
// Verifies the wordHighlighter feature across its three implementation
// operations:
//   1. Feature-specific behavior: combine textual and provider document
//      highlights with version gating (textual = literal search for the word
//      under cursor; provider = `MonaProviderExecutor` P05-T013; version-gated
//      like T115).
//   2. The exact feature identity `wordHighlighter` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation (read-only — none), asynchronous publication,
//      disposal, localization, and degraded plain-text behavior through the
//      shared gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     WORDHIGHLIGHTER feature=live actions=3 commands=3 contributions=1 keybindings=2 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaWordHighlighterFeatureTests: XCTestCase {

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/wordhighlight-\(UUID().uuidString)")
        )
    }

    /// A test provider that returns a fixed highlight set, optionally gated by
    /// a cancellation token.
    private final class TestDocumentHighlightProvider: MonaDocumentHighlightProvider {
        let highlights: [MonaDocumentHighlight]
        let token: MonaCancellationToken?
        init(highlights: [MonaDocumentHighlight], token: MonaCancellationToken? = nil) {
            self.highlights = highlights
            self.token = token
        }
        func provideDocumentHighlights(
            at position: MonaPosition,
            model: MonaCodeModel,
            token: MonaCancellationToken
        ) -> MonaProviderResult<[MonaDocumentHighlight]> {
            if let gate = self.token {
                return .cancelable(gate, highlights)
            }
            return .synchronous(highlights)
        }
    }

    private func highlight(_ line: Int, _ start: Int, _ end: Int, _ kind: MonaWordHighlightKind) -> MonaDocumentHighlight {
        return MonaDocumentHighlight(
            range: MonaRange(startLine: line, startColumn: start, endLine: line, endColumn: end),
            kind: kind
        )
    }

    // MARK: - 1. Feature-specific behavior: combine textual + provider highlights

    func testTextualHighlightsFindAllWordOccurrences() {
        let feature = MonaWordHighlighterFeature()
        // "x" appears as a whole word three times in "let x = x + x".
        let model = makeModel("let x = x + x")
        let highlights = feature.textualHighlights(for: MonaPosition(line: 1, column: 5), in: model)
        XCTAssertEqual(highlights.count, 3)
        for h in highlights {
            XCTAssertEqual(h.kind, .text)
        }
        // The occurrence at the cursor (col 5) is included.
        XCTAssertEqual(highlights[0].range, MonaRange(startLine: 1, startColumn: 5, endLine: 1, endColumn: 6))
    }

    func testTextualHighlightsReturnEmptyForWhitespacePosition() {
        let feature = MonaWordHighlighterFeature()
        let model = makeModel("let x = x")
        // Column 4 is a space — no active word.
        let highlights = feature.textualHighlights(for: MonaPosition(line: 1, column: 4), in: model)
        XCTAssertTrue(highlights.isEmpty)
    }

    func testCombineMergesTextualAndProviderDeduplicatingByRange() {
        let feature = MonaWordHighlighterFeature()
        let textual = [
            highlight(1, 5, 6, .text),
            highlight(1, 9, 10, .text)
        ]
        let provider = [
            highlight(1, 5, 6, .read),   // same range as textual[0] — dedupe
            highlight(1, 13, 14, .write)  // unique — kept
        ]
        let combined = feature.combine(textual, provider)
        // 3 unique ranges after dedupe.
        XCTAssertEqual(combined.count, 3)
        // The provider kind wins on the shared range (provider is authoritative).
        let first = combined.first { $0.range == MonaRange(startLine: 1, startColumn: 5, endLine: 1, endColumn: 6) }
        XCTAssertEqual(first?.kind, .read)
    }

    func testRequestCombinedHighlightsPublishesCombinedSetVersionGated() {
        let feature = MonaWordHighlighterFeature()
        let model = makeModel("let x = x + x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        // Provider returns one read highlight at col 9 (overlapping a textual).
        let provider = TestDocumentHighlightProvider(highlights: [
            highlight(1, 9, 10, .read)
        ])
        let tokenSource = MonaCancellationTokenSource()

        var received: [MonaDocumentHighlight] = []
        let accepted = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { combined in
            received = combined
        }
        XCTAssertTrue(accepted)
        XCTAssertEqual(received.count, 0)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        // Textual finds 3 (cols 5, 9, 13); provider adds 1 at col 9 (dedupes
        // with the textual at col 9). Combined = 3 unique ranges.
        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(queue.pendingCount, 0)
        XCTAssertTrue(feature.hasActiveHighlights)
    }

    func testRequestCombinedHighlightsDropsWhenTicketIsStale() {
        let feature = MonaWordHighlighterFeature()
        let model = makeModel("let x = x + x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestDocumentHighlightProvider(highlights: [])
        let tokenSource = MonaCancellationTokenSource()
        let ticket = gate.captureTicket()
        gate.cancel()

        var received: [MonaDocumentHighlight] = []
        _ = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: ticket,
            token: tokenSource.token
        ) { combined in
            received = combined
        }
        executor.drain()
        // Stale ticket: receive never invoked, no highlights retained.
        XCTAssertTrue(received.isEmpty)
        XCTAssertFalse(feature.hasActiveHighlights)
    }

    func testRequestCombinedHighlightsDropsWhenTokenAlreadyCancelled() {
        let feature = MonaWordHighlighterFeature()
        let model = makeModel("let x = x + x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        // Provider gates publication on an already-cancelled token.
        let provider = TestDocumentHighlightProvider(
            highlights: [highlight(1, 9, 10, .read)],
            token: MonaCancellationToken.cancelled
        )
        let tokenSource = MonaCancellationTokenSource()

        var received: [MonaDocumentHighlight] = []
        let accepted = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { combined in
            received = combined
        }
        // The cancelable shape with an already-cancelled token normalizes to
        // "no value to publish": not enqueued.
        XCTAssertFalse(accepted)
        executor.drain()
        XCTAssertTrue(received.isEmpty)
        XCTAssertFalse(feature.hasActiveHighlights)
    }

    func testNavigateNextAdvancesActiveHighlight() {
        let feature = MonaWordHighlighterFeature()
        let model = makeModel("let x = x + x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestDocumentHighlightProvider(highlights: [])
        let tokenSource = MonaCancellationTokenSource()
        _ = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { _ in }
        executor.drain()
        XCTAssertEqual(feature.currentIndex, 0)

        feature.navigateNext()
        XCTAssertEqual(feature.currentIndex, 1)
        feature.navigateNext()
        XCTAssertEqual(feature.currentIndex, 2)
        // Wrap around to 0.
        feature.navigateNext()
        XCTAssertEqual(feature.currentIndex, 0)
    }

    func testNavigatePreviousWrapsAround() {
        let feature = MonaWordHighlighterFeature()
        let model = makeModel("let x = x + x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestDocumentHighlightProvider(highlights: [])
        let tokenSource = MonaCancellationTokenSource()
        _ = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { _ in }
        executor.drain()
        XCTAssertEqual(feature.currentIndex, 0)

        feature.navigatePrevious()
        // Wraps around to the last highlight (index 2).
        XCTAssertEqual(feature.currentIndex, 2)
    }

    func testStopClearsActiveHighlights() {
        let feature = MonaWordHighlighterFeature()
        let model = makeModel("let x = x + x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestDocumentHighlightProvider(highlights: [])
        let tokenSource = MonaCancellationTokenSource()
        _ = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { _ in }
        executor.drain()
        XCTAssertTrue(feature.hasActiveHighlights)

        feature.stopHighlights()
        XCTAssertFalse(feature.hasActiveHighlights)
    }

    func testRequestIsNoOpAfterDisposal() {
        let feature = MonaWordHighlighterFeature()
        feature.dispose()
        let model = makeModel("let x = x + x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestDocumentHighlightProvider(highlights: [])

        var received: [MonaDocumentHighlight] = []
        let accepted = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: MonaCancellationToken.none
        ) { combined in
            received = combined
        }
        XCTAssertFalse(accepted)
        executor.drain()
        XCTAssertTrue(received.isEmpty)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaWordHighlighterFeature.featureId, "wordHighlighter")
        XCTAssertTrue(features.contains("wordHighlighter"))

        let actionIds = MonaWordHighlighterFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.wordHighlight.next",
            "editor.action.wordHighlight.prev",
            "editor.action.wordHighlight.trigger"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(
            MonaWordHighlighterFeature.declaredCommandIds,
            [
                "editor.action.wordHighlight.next",
                "editor.action.wordHighlight.prev",
                "editor.action.wordHighlight.trigger"
            ]
        )
        XCTAssertEqual(
            MonaWordHighlighterFeature.declaredContributionIds,
            ["editor.contrib.wordHighlighter"]
        )
        for id in MonaWordHighlighterFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(
            MonaWordHighlighterFeature.declaredKeybindingCommands,
            ["editor.action.wordHighlight.next", "editor.action.wordHighlight.prev"]
        )
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaWordHighlighterFeature.declaredKeybindingCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertTrue(MonaWordHighlighterFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaWordHighlighterFeature.declaredMenuIds.isEmpty)
        _ = menus
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("let x = x + x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaWordHighlighterFeature()
        let provider = TestDocumentHighlightProvider(highlights: [
            highlight(1, 9, 10, .read)
        ])
        let tokenSource = MonaCancellationTokenSource()

        var received: [MonaDocumentHighlight] = []
        _ = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { combined in
            received = combined
        }
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertFalse(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaWordHighlighterFeature()
        var fired: [MonaWordHighlighterEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
        XCTAssertFalse(feature.hasActiveHighlights)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaWordHighlighterFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaWordHighlighterFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Go to Next Symbol Highlight")
        XCTAssertEqual(enLabels[1], "Go to Previous Symbol Highlight")
        XCTAssertEqual(enLabels[2], "Trigger Symbol Highlight")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaWordHighlighterFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    func testConfirmReadOnlyRoutesVacuousMutationThroughGateway() {
        let feature = MonaWordHighlighterFeature()
        let model = makeModel("let x = x")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.confirmReadOnly(gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "let x = x")
        } else {
            XCTFail("expected applied read-only, got \(outcome)")
        }
    }

    // MARK: - Contract leaf

    func testContractBehavior() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let feature = MonaWordHighlighterFeature()

        let featureLive = features.contains(MonaWordHighlighterFeature.featureId)
        let actionCount = MonaWordHighlighterFeature.declaredActionIds.count
        let commandCount = MonaWordHighlighterFeature.declaredCommandIds.count
        let contribCount = MonaWordHighlighterFeature.declaredContributionIds.count
        let kbCount = MonaWordHighlighterFeature.declaredKeybindingCommands.count
        let optionCount = MonaWordHighlighterFeature.declaredOptionIds.count
        let menuCount = MonaWordHighlighterFeature.declaredMenuIds.count

        let slicePass = MonaWordHighlighterFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaWordHighlighterFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaWordHighlighterFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaWordHighlighterFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }

        // Mutation: read-only — confirm the model is untouched via the gateway.
        let model = makeModel("let x = x")
        let gateway = MonaTransactionGateway(model: model)
        let readOutcome = feature.confirmReadOnly(gateway: gateway)
        let mutation: Bool
        if case .applied = readOutcome, model.getValue() == "let x = x" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication: request combined highlights (textual + provider).
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestDocumentHighlightProvider(highlights: [
            highlight(1, 5, 6, .read)
        ])
        let tokenSource = MonaCancellationTokenSource()
        var delivered = false
        _ = feature.requestCombinedHighlights(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0 && feature.hasActiveHighlights

        feature.dispose()
        let disposalPass = feature.isDisposed && !feature.hasActiveHighlights

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded
            && feature.degradedLanguage.id == MonaPlainTextLanguage.languageId

        print("WORDHIGHLIGHTER feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
