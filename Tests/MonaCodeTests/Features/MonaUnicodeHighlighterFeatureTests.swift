// MonaUnicodeHighlighterFeatureTests.swift
//
// P05-T157 — Implement retained feature unicodeHighlighter.
//
// Verifies the unicodeHighlighter feature across its three implementation
// operations:
//   1. Feature-specific behavior: detect configured invisible, ambiguous, and
//      non-basic Unicode spans (read unicode-highlighter options:
//      invisible/ambiguous/nonBasic ranges).
//   2. The exact feature identity `unicodeHighlighter` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation (read-only — none), asynchronous publication,
//      disposal, localization, and degraded plain-text behavior through the
//      shared gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     UNICODEHIGHLIGHTER feature=live actions=0 commands=4 contributions=1 keybindings=0 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaUnicodeHighlighterFeatureTests: XCTestCase {

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/unicode-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: detect configured Unicode spans

    func testDetectsInvisibleCharacterSpan() {
        let feature = MonaUnicodeHighlighterFeature()
        // U+200B ZERO WIDTH SPACE is an invisible character.
        let model = makeModel("a\u{200B}b")
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(invisibleCharacters: true)
        )
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].kind, .invisible)
        XCTAssertEqual(spans[0].codePoint, 0x200B)
        XCTAssertEqual(spans[0].range, MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 3))
    }

    func testDetectsAmbiguousCharacterSpan() {
        let feature = MonaUnicodeHighlighterFeature()
        // U+FF21 FULLWIDTH LATIN CAPITAL LETTER A is an ambiguous character
        // (confusable with ASCII 'A').
        let model = makeModel("a\u{FF21}b")
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(ambiguousCharacters: true)
        )
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].kind, .ambiguous)
        XCTAssertEqual(spans[0].codePoint, 0xFF21)
    }

    func testDetectsNonBasicAsciiSpan() {
        let feature = MonaUnicodeHighlighterFeature()
        // U+00E9 LATIN SMALL LETTER E WITH ACUTE is non-basic ASCII.
        let model = makeModel("café")
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(nonBasicASCII: true)
        )
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].kind, .nonBasicAscii)
        XCTAssertEqual(spans[0].codePoint, 0x00E9)
        XCTAssertEqual(spans[0].range, MonaRange(startLine: 1, startColumn: 4, endLine: 1, endColumn: 5))
    }

    func testDoesNotDetectBasicAscii() {
        let feature = MonaUnicodeHighlighterFeature()
        let model = makeModel("plain ASCII only 123")
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(
                ambiguousCharacters: true,
                invisibleCharacters: true,
                nonBasicASCII: true
            )
        )
        XCTAssertTrue(spans.isEmpty)
    }

    func testAllowedCharactersSuppressesDetection() {
        let feature = MonaUnicodeHighlighterFeature()
        let model = makeModel("a\u{200B}b")
        let options = MonaUnicodeHighlightOptions(
            invisibleCharacters: true,
            allowedCharacters: [0x200B]
        )
        let spans = feature.detectHighlights(in: model, options: options)
        XCTAssertTrue(spans.isEmpty)
    }

    func testDisabledKindsProduceNoSpans() {
        let feature = MonaUnicodeHighlighterFeature()
        // All kinds disabled → no spans even for problematic characters.
        let model = makeModel("a\u{200B}\u{FF21}é")
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(
                ambiguousCharacters: false,
                invisibleCharacters: false,
                nonBasicASCII: false
            )
        )
        XCTAssertTrue(spans.isEmpty)
    }

    func testDetectsSpansAcrossMultipleLines() {
        let feature = MonaUnicodeHighlighterFeature()
        // Line 1 has an invisible; line 2 has a non-basic char.
        let model = makeModel("a\u{200B}\né")
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(
                invisibleCharacters: true,
                nonBasicASCII: true
            )
        )
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].kind, .invisible)
        XCTAssertEqual(spans[0].range, MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 3))
        XCTAssertEqual(spans[1].kind, .nonBasicAscii)
        XCTAssertEqual(spans[1].range, MonaRange(startLine: 2, startColumn: 1, endLine: 2, endColumn: 2))
    }

    func testDetectionIsNoOpAfterDisposal() {
        let feature = MonaUnicodeHighlighterFeature()
        feature.dispose()
        let model = makeModel("a\u{200B}b")
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(invisibleCharacters: true)
        )
        XCTAssertTrue(spans.isEmpty)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaUnicodeHighlighterFeature.featureId, "unicodeHighlighter")
        XCTAssertTrue(features.contains("unicodeHighlighter"))

        // No labeled actions (the 4 unicode-highlight entries are commands
        // only — they carry no action label in the F1-R3 actions registry).
        XCTAssertTrue(MonaUnicodeHighlighterFeature.declaredActionIds.isEmpty)

        let commandIds = MonaUnicodeHighlighterFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "editor.action.unicodeHighlight.disableHighlightingOfAmbiguousCharacters",
            "editor.action.unicodeHighlight.disableHighlightingOfInvisibleCharacters",
            "editor.action.unicodeHighlight.disableHighlightingOfNonBasicAsciiCharacters",
            "editor.action.unicodeHighlight.showExcludeOptions"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(
            MonaUnicodeHighlighterFeature.declaredContributionIds,
            ["editor.contrib.unicodeHighlighter"]
        )
        for id in MonaUnicodeHighlighterFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertTrue(MonaUnicodeHighlighterFeature.declaredKeybindingCommands.isEmpty)

        XCTAssertEqual(
            MonaUnicodeHighlighterFeature.declaredOptionIds,
            ["unicodeHighlight"]
        )
        for id in MonaUnicodeHighlighterFeature.declaredOptionIds {
            XCTAssertNotNil(MonaBuiltinOptions.option(named: id), "missing option \(id)")
        }

        XCTAssertTrue(MonaUnicodeHighlighterFeature.declaredMenuIds.isEmpty)
        _ = menus
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("a\u{200B}b")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaUnicodeHighlighterFeature()
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(invisibleCharacters: true)
        )

        var received: [MonaUnicodeHighlightSpan] = []
        let accepted = feature.publishHighlights(
            spans,
            executor: executor,
            ticket: gate.captureTicket()
        ) { published in
            received = published
        }
        XCTAssertTrue(accepted)
        XCTAssertEqual(received.count, 0)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0].kind, .invisible)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testPublishHighlightsDropsWhenTicketIsStale() {
        let model = makeModel("a\u{200B}b")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaUnicodeHighlighterFeature()
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(invisibleCharacters: true)
        )
        let ticket = gate.captureTicket()
        gate.cancel()

        var received: [MonaUnicodeHighlightSpan] = []
        _ = feature.publishHighlights(spans, executor: executor, ticket: ticket) { published in
            received = published
        }
        executor.drain()
        XCTAssertTrue(received.isEmpty)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaUnicodeHighlighterFeature()
        var fired: [MonaUnicodeHighlighterEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaUnicodeHighlighterFeature()
        // unicodeHighlighter declares no labeled actions, so the localized list
        // is empty under every profile.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaUnicodeHighlighterFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    func testConfirmReadOnlyRoutesVacuousMutationThroughGateway() {
        let feature = MonaUnicodeHighlighterFeature()
        let model = makeModel("a\u{200B}b")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.confirmReadOnly(gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\u{200B}b")
        } else {
            XCTFail("expected applied read-only, got \(outcome)")
        }
    }

    // MARK: - Contract leaf

    func testContractBehavior() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let contributions = MonaContributionRegistry()
        let feature = MonaUnicodeHighlighterFeature()

        let featureLive = features.contains(MonaUnicodeHighlighterFeature.featureId)
        let actionCount = MonaUnicodeHighlighterFeature.declaredActionIds.count
        let commandCount = MonaUnicodeHighlighterFeature.declaredCommandIds.count
        let contribCount = MonaUnicodeHighlighterFeature.declaredContributionIds.count
        let kbCount = MonaUnicodeHighlighterFeature.declaredKeybindingCommands.count
        let optionCount = MonaUnicodeHighlighterFeature.declaredOptionIds.count
        let menuCount = MonaUnicodeHighlighterFeature.declaredMenuIds.count

        let slicePass = MonaUnicodeHighlighterFeature.declaredActionIds.allSatisfy { _ in true }
            && MonaUnicodeHighlighterFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaUnicodeHighlighterFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaUnicodeHighlighterFeature.declaredKeybindingCommands.allSatisfy { _ in true }
            && MonaUnicodeHighlighterFeature.declaredOptionIds.allSatisfy {
                MonaBuiltinOptions.option(named: $0) != nil
            }

        // Mutation: read-only — confirm the model is untouched via the gateway.
        let model = makeModel("a\u{200B}b")
        let gateway = MonaTransactionGateway(model: model)
        let readOutcome = feature.confirmReadOnly(gateway: gateway)
        let mutation: Bool
        if case .applied = readOutcome, model.getValue() == "a\u{200B}b" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let spans = feature.detectHighlights(
            in: model,
            options: MonaUnicodeHighlightOptions(invisibleCharacters: true)
        )
        var delivered = false
        _ = feature.publishHighlights(spans, executor: executor, ticket: gate.captureTicket()) { _ in
            delivered = true
        }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded
            && feature.degradedLanguage.id == MonaPlainTextLanguage.languageId

        print("UNICODEHIGHLIGHTER feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
