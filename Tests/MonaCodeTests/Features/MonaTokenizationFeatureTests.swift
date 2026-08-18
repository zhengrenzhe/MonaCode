// MonaTokenizationFeatureTests.swift
//
// P05-T156 — Implement retained feature tokenization.
//
// Verifies the tokenization feature across its three implementation operations:
//   1. Feature-specific behavior: consume direct token providers and retain
//      plain-text tokens when none is attached (reuse the token-provider
//      protocol pattern from T009 colorize, adapted for the Foundation-only
//      Core via Core's `MonaToken` value type).
//   2. The exact feature identity `tokenization` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation (read-only — none performed), asynchronous
//      publication, disposal, localization, and degraded plain-text behavior
//      through the shared gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     TOKENIZATION feature=live actions=0 commands=0 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

/// A test direct-token provider that returns a fixed token list per line,
/// mirroring the T009 `MonaDirectTokenProvider` pattern for the Foundation-only
/// Core (Core `MonaToken` value type instead of AppKit `MonaColorToken`).
private final class FixedTokenProvider: MonaTokenizationProvider {
    var tokensByLine: [String: [MonaToken]] = [:]

    func tokens(forLine line: String, languageId: String) -> [MonaToken] {
        return tokensByLine[line] ?? []
    }
}

final class MonaTokenizationFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 5") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/tokens-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: consume providers / retain plain-text

    func testTokenizeRetainsPlainTextTokenWhenNoProviderAttached() {
        let feature = MonaTokenizationFeature()

        let tokens = feature.tokenize(line: "let x = 5")

        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0], MonaToken(offset: 0, type: "", language: "plaintext"))
        XCTAssertEqual(tokens[0].toString(), "[0||plaintext]")
    }

    func testTokenizeConsumesDirectTokenProviderWhenAttached() {
        let feature = MonaTokenizationFeature()
        let provider = FixedTokenProvider()
        provider.tokensByLine = [
            "let x = 5": [
                MonaToken(offset: 0, type: "keyword.ts", language: "typescript"),
                MonaToken(offset: 4, type: "identifier.ts", language: "typescript"),
                MonaToken(offset: 6, type: "delimiter.ts", language: "typescript"),
                MonaToken(offset: 8, type: "number.ts", language: "typescript")
            ]
        ]
        feature.directTokenProvider = provider

        let tokens = feature.tokenize(line: "let x = 5", languageId: "typescript")

        XCTAssertEqual(tokens.count, 4)
        XCTAssertEqual(tokens[0].type, "keyword.ts")
        XCTAssertEqual(tokens[3].offset, 8)
    }

    func testTokenizeFallsBackToPlainTextWhenProviderReturnsEmpty() {
        let feature = MonaTokenizationFeature()
        let provider = FixedTokenProvider()
        feature.directTokenProvider = provider

        let tokens = feature.tokenize(line: "abc")

        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0], MonaToken(offset: 0, type: "", language: "plaintext"))
    }

    func testTokenizeTextReturnsPerLineTokens() {
        let feature = MonaTokenizationFeature()

        let lines = feature.tokenize(text: "hello\nworld")

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].count, 1)
        XCTAssertEqual(lines[0][0], MonaToken(offset: 0, type: "", language: "plaintext"))
        XCTAssertEqual(lines[1].count, 1)
        XCTAssertEqual(lines[1][0], MonaToken(offset: 0, type: "", language: "plaintext"))
    }

    func testTokenizeReturnsEmptyAfterDisposal() {
        let feature = MonaTokenizationFeature()
        feature.dispose()

        let tokens = feature.tokenize(line: "abc")
        XCTAssertTrue(tokens.isEmpty)

        let lines = feature.tokenize(text: "abc")
        XCTAssertTrue(lines.isEmpty)
    }

    func testPlainTextFallbackTokenUsesPlainTextLanguage() {
        let feature = MonaTokenizationFeature()
        let tokens = feature.tokenize(line: "abc")
        XCTAssertEqual(tokens[0].language, MonaPlainTextLanguage.languageId)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaTokenizationFeature.featureId, "tokenization")
        XCTAssertTrue(features.contains("tokenization"))

        XCTAssertEqual(MonaTokenizationFeature.declaredActionIds, [])
        XCTAssertEqual(MonaTokenizationFeature.declaredCommandIds, [])
        XCTAssertEqual(MonaTokenizationFeature.declaredContributionIds, [])
        XCTAssertEqual(MonaTokenizationFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaTokenizationFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaTokenizationFeature.declaredMenuIds, [])

        // The tokenization feature declares no command/action/contribution/menu
        // slice; every declared id set is empty. The slice-pass check therefore
        // reduces to "the feature identity is live in the registry".
        let slicePass = MonaTokenizationFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaTokenizationFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaTokenizationFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaTokenizationFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaTokenizationFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }
        XCTAssertTrue(slicePass)
        _ = menus
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGatewayWithoutTouchingModel() {
        let feature = MonaTokenizationFeature()
        let model = makeModel("let x = 5")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.confirmReadOnly(gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "let x = 5")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaTokenizationFeature()
        let ticket = gate.captureTicket()

        let tokens = [MonaToken(offset: 0, type: "", language: "plaintext")]
        var received: [[MonaToken]] = []
        let accepted = feature.publishTokenization(
            tokens,
            executor: executor,
            ticket: ticket
        ) { event in received.append(event) }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], tokens)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaTokenizationFeature()
        var events: [MonaTokenizationEvent] = []
        _ = feature.onChange { events.append($0) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(events.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaTokenizationFeature()
        // tokenization declares no actions, so labels are empty under every
        // profile.
        XCTAssertEqual(feature.localizedActionLabels(profile: .default), [])
        XCTAssertEqual(feature.localizedActionLabels(profile: .custom("pseudo")), [])
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaTokenizationFeature()
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
        let feature = MonaTokenizationFeature()

        let featureLive = features.contains(MonaTokenizationFeature.featureId)
        let actionCount = MonaTokenizationFeature.declaredActionIds.count
        let commandCount = MonaTokenizationFeature.declaredCommandIds.count
        let contribCount = MonaTokenizationFeature.declaredContributionIds.count
        let kbCount = MonaTokenizationFeature.declaredKeybindingCommands.count
        let optionCount = MonaTokenizationFeature.declaredOptionIds.count
        let menuCount = MonaTokenizationFeature.declaredMenuIds.count

        let slicePass = MonaTokenizationFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaTokenizationFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaTokenizationFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaTokenizationFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaTokenizationFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Feature behavior: plain-text fallback when no provider attached;
        // provider consumption when attached.
        let plainTokens = feature.tokenize(line: "abc")
        let plainPass = plainTokens.count == 1
            && plainTokens[0] == MonaToken(offset: 0, type: "", language: "plaintext")

        let provider = FixedTokenProvider()
        provider.tokensByLine = [
            "abc": [MonaToken(offset: 0, type: "identifier.ts", language: "typescript")]
        ]
        feature.directTokenProvider = provider
        let providedTokens = feature.tokenize(line: "abc", languageId: "typescript")
        let providerPass = providedTokens.count == 1
            && providedTokens[0].type == "identifier.ts"
        feature.directTokenProvider = nil

        // Mutation: read-only — the model is untouched.
        let model = makeModel("let x = 5")
        let gateway = MonaTransactionGateway(model: model)
        var mutation = false
        let outcome = feature.confirmReadOnly(gateway: gateway)
        if case .applied = outcome, model.getValue() == "let x = 5" {
            mutation = true
        }

        // Async publication.
        let pubGate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: pubGate, queue: queue)
        var delivered = false
        _ = feature.publishTokenization(
            [MonaToken(offset: 0, type: "", language: "plaintext")],
            executor: executor,
            ticket: pubGate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("TOKENIZATION feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(plainPass)
        XCTAssertTrue(providerPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
