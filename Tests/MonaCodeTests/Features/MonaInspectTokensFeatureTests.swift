// MonaInspectTokensFeatureTests.swift
//
// P05-T132 — Implement retained feature inspectTokens.
//
// Verifies the inspectTokens feature across its three implementation
// operations:
//   1. Feature-specific behavior: expose token, scope, foreground, background,
//      and source inspection data (reusing the token theme T006 for the
//      scope→color rule lookup; the plain-text language T008 as the degraded
//      tokenization source).
//   2. The exact feature identity `inspectTokens` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation (read-only — none performed), asynchronous
//      publication, disposal, localization, and degraded plain-text behavior
//      through the shared gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     INSPECTTOKENS feature=live actions=1 commands=1 contributions=1 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaInspectTokensFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 5") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/inspect-\(UUID().uuidString)")
        )
    }

    /// The builtin `vs` theme carries the default `""` scope rule
    /// (foreground `000000`, background `fffffe`).
    private func vsTheme() -> MonaTokenTheme {
        return MonaBuiltinThemes.theme(for: "vs")!
    }

    /// A custom theme whose default `""` scope rule carries a distinctive
    /// foreground (`ff0000`) and background (`00ff00`), so the inspection's
    /// theme lookup is observable.
    private func customTheme() -> MonaTokenTheme {
        return MonaTokenTheme(
            id: "test-custom",
            base: "vs",
            inherit: false,
            colors: [:],
            rules: [
                MonaTokenColorRule(token: "", foreground: "ff0000", background: "00ff00", fontStyle: "bold")
            ]
        )
    }

    // MARK: - 1. Feature-specific behavior: expose token + scope + colors + source

    func testInspectExposesTokenScopeForegroundBackgroundAndSource() {
        let feature = MonaInspectTokensFeature()
        let model = makeModel("let x = 5")

        let inspection = feature.inspect(
            at: MonaPosition(line: 1, column: 9),
            model: model,
            theme: vsTheme()
        )
        XCTAssertEqual(inspection?.token, "5")
        XCTAssertEqual(inspection?.scope, "")
        XCTAssertEqual(inspection?.foreground, "000000")
        XCTAssertEqual(inspection?.background, "fffffe")
        XCTAssertEqual(inspection?.fontStyle, nil)
        XCTAssertEqual(inspection?.source.languageId, "plaintext")
        XCTAssertEqual(inspection?.source.line, 1)
        XCTAssertEqual(inspection?.source.column, 9)
        XCTAssertEqual(inspection?.source.offset, 8)
    }

    func testInspectUsesThemeRuleForScope() {
        let feature = MonaInspectTokensFeature()
        let model = makeModel("let x = 5")

        let inspection = feature.inspect(
            at: MonaPosition(line: 1, column: 9),
            model: model,
            theme: customTheme()
        )
        XCTAssertEqual(inspection?.token, "5")
        XCTAssertEqual(inspection?.scope, "")
        XCTAssertEqual(inspection?.foreground, "ff0000")
        XCTAssertEqual(inspection?.background, "00ff00")
        XCTAssertEqual(inspection?.fontStyle, "bold")
    }

    func testInspectReturnsNilOnWhitespace() {
        let feature = MonaInspectTokensFeature()
        let model = makeModel("let x = 5")

        // Column 4 is the space between "let" and "x".
        let inspection = feature.inspect(
            at: MonaPosition(line: 1, column: 4),
            model: model,
            theme: vsTheme()
        )
        XCTAssertNil(inspection)
    }

    func testInspectReturnsNilAfterDisposal() {
        let feature = MonaInspectTokensFeature()
        let model = makeModel("let x = 5")
        feature.dispose()

        let inspection = feature.inspect(
            at: MonaPosition(line: 1, column: 9),
            model: model,
            theme: vsTheme()
        )
        XCTAssertNil(inspection)
    }

    func testInspectDoesNotMutateTheModel() {
        let feature = MonaInspectTokensFeature()
        let model = makeModel("let x = 5")

        _ = feature.inspect(
            at: MonaPosition(line: 1, column: 9),
            model: model,
            theme: vsTheme()
        )
        XCTAssertEqual(model.getValue(), "let x = 5")
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaInspectTokensFeature.featureId, "inspectTokens")
        XCTAssertTrue(features.contains("inspectTokens"))

        let actionIds = MonaInspectTokensFeature.declaredActionIds
        XCTAssertEqual(actionIds, ["editor.action.inspectTokens"])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaInspectTokensFeature.declaredCommandIds
        XCTAssertEqual(commandIds, ["editor.action.inspectTokens"])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaInspectTokensFeature.declaredContributionIds, [
            "editor.contrib.inspectTokens"
        ])
        for id in MonaInspectTokensFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaInspectTokensFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaInspectTokensFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaInspectTokensFeature.declaredMenuIds, [])
        _ = menus
        _ = options
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaInspectTokensFeature()
        let ticket = gate.captureTicket()

        let inspection = MonaTokenInspection(
            token: "abc",
            scope: "",
            foreground: "000000",
            background: "fffffe",
            fontStyle: nil,
            source: MonaTokenInspectionSource(languageId: "plaintext", line: 1, column: 1, offset: 0)
        )
        var received: [MonaTokenInspection] = []
        let accepted = feature.publishInspection(
            inspection,
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
        let feature = MonaInspectTokensFeature()
        var fired: [MonaInspectTokensEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaInspectTokensFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaInspectTokensFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Developer: Inspect Tokens")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaInspectTokensFeature()
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
        let feature = MonaInspectTokensFeature()

        let featureLive = features.contains(MonaInspectTokensFeature.featureId)
        let actionCount = MonaInspectTokensFeature.declaredActionIds.count
        let commandCount = MonaInspectTokensFeature.declaredCommandIds.count
        let contribCount = MonaInspectTokensFeature.declaredContributionIds.count
        let kbCount = MonaInspectTokensFeature.declaredKeybindingCommands.count
        let optionCount = MonaInspectTokensFeature.declaredOptionIds.count
        let menuCount = MonaInspectTokensFeature.declaredMenuIds.count

        let slicePass = MonaInspectTokensFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaInspectTokensFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaInspectTokensFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaInspectTokensFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }

        // Mutation: inspectTokens is a read-only inspection — it performs no
        // model mutation. Mutation routing is honored by performing no mutation
        // through any parallel mechanism; the model is unchanged and the
        // inspection returns a valid result.
        let model = makeModel("let x = 5")
        let inspection = feature.inspect(
            at: MonaPosition(line: 1, column: 9),
            model: model,
            theme: vsTheme()
        )
        let mutation = inspection != nil && model.getValue() == "let x = 5"

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishInspection(
            MonaTokenInspection(
                token: "5",
                scope: "",
                foreground: "000000",
                background: "fffffe",
                fontStyle: nil,
                source: MonaTokenInspectionSource(languageId: "plaintext", line: 1, column: 9, offset: 8)
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

        print("INSPECTTOKENS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
