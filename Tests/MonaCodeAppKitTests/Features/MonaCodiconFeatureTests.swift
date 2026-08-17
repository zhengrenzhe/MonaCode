// MonaCodiconFeatureTests.swift
//
// P05-T107 — Implement retained feature codicon.
//
// Verifies the codicon feature across its three implementation operations:
//   1. Feature-specific behavior: resolve Codicon identifiers and licensed glyph
//      assets through the theme registry (MonaThemeRegistry / MonaIconRegistry /
//      MonaCodiconMap). The codicon.ttf binary is NOT bundled at this layer
//      (fontBinaryBundled == false); this feature resolves glyph IDENTIFIERS and
//      the glyph map, not the font bytes.
//   2. The exact feature identity `codicon` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     CODICON feature=live actions=0 commands=0 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaCodiconFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "hello") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/codicon-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: resolve identifiers + licensed glyph assets

    func testResolveCodiconReturnsDefinitionForKnownId() {
        let feature = MonaCodiconFeature()
        let def = feature.resolveCodicon(id: "add")
        XCTAssertNotNil(def)
        XCTAssertEqual(def?.id, "add")
        XCTAssertEqual(def?.codepointHex, "ea60")
        XCTAssertFalse(def?.isAlias ?? true)
    }

    func testResolveCodiconReturnsNilForUnknownId() {
        let feature = MonaCodiconFeature()
        XCTAssertNil(feature.resolveCodicon(id: "no-such-icon"))
    }

    func testResolveCodepointFollowsAliasChains() {
        let feature = MonaCodiconFeature()
        // `diff-insert` is a deprecated alias of `add` -> codepoint ea60.
        XCTAssertEqual(feature.resolveCodepoint(id: "diff-insert"), "ea60")
        XCTAssertEqual(feature.resolveCodepoint(id: "add"), "ea60")
    }

    func testResolveCharacterReturnsUnicodeScalarAtCodepoint() {
        let feature = MonaCodiconFeature()
        let ch = feature.resolveCharacter(id: "add")
        XCTAssertNotNil(ch)
        // ea60 -> U+EA60
        XCTAssertEqual(ch?.unicodeScalars.first?.value, 0xEA60)
    }

    func testResolveGlyphReturnsCodiconMapEntry() {
        let feature = MonaCodiconFeature()
        let glyph = feature.resolveGlyph(id: "add")
        XCTAssertEqual(glyph?.id, "add")
        XCTAssertEqual(glyph?.codepointHex, "ea60")
    }

    func testResolveReturnsCombinedResolutionAndFiresEvent() {
        let feature = MonaCodiconFeature()
        var fired: [MonaCodiconEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let resolution = feature.resolve(id: "add")
        XCTAssertEqual(resolution.id, "add")
        XCTAssertEqual(resolution.codepointHex, "ea60")
        XCTAssertEqual(resolution.character?.unicodeScalars.first?.value, 0xEA60)
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired[0].resolution.id, "add")
    }

    func testResolveForUnknownIdReturnsNilCodepoint() {
        let feature = MonaCodiconFeature()
        let resolution = feature.resolve(id: "no-such-icon")
        XCTAssertEqual(resolution.id, "no-such-icon")
        XCTAssertNil(resolution.codepointHex)
        XCTAssertNil(resolution.character)
    }

    func testAvailableIconIdsCarriesAll776Glyphs() {
        let feature = MonaCodiconFeature()
        XCTAssertEqual(feature.availableIconIds.count, 776)
        XCTAssertEqual(feature.availableIconIds, MonaIconRegistry.ids)
    }

    func testAliasCountIs34() {
        let feature = MonaCodiconFeature()
        XCTAssertEqual(feature.aliasCount, MonaIconRegistry.aliases.count)
        XCTAssertEqual(feature.aliasCount, 34)
    }

    func testLicensedGlyphAssetsExposeFontProvenanceAndHash() {
        let feature = MonaCodiconFeature()
        XCTAssertEqual(feature.fontFilename, "codicon.ttf")
        XCTAssertEqual(feature.expectedFontSHA256, MonaCodiconMap.expectedFontSHA256)
        XCTAssertEqual(feature.expectedFontSizeBytes, MonaCodiconMap.expectedFontSizeBytes)
        // The codicon.ttf binary is NOT bundled at this layer.
        XCTAssertFalse(feature.fontBinaryBundled)
        XCTAssertFalse(MonaCodiconMap.fontBinaryBundled)

        let provenance = feature.licensedGlyphAssets
        XCTAssertEqual(provenance, MonaCodiconMap.provenance)
        XCTAssertTrue(provenance.artworkAndFontLicense.contains("CC BY"))
        XCTAssertTrue(provenance.monacoMitNotice.contains("MIT"))
    }

    func testResolutionGoesThroughThemeRegistryContext() {
        let themeRegistry = MonaThemeRegistry()
        let feature = MonaCodiconFeature(themeRegistry: themeRegistry)
        // The theme registry boots on Monaco's standalone default (`vs-dark`).
        XCTAssertEqual(feature.themeRegistry.currentThemeId, "vs-dark")
        XCTAssertEqual(feature.themeRegistry.currentThemeId, themeRegistry.currentThemeId)
        // Resolution is unaffected by the active theme (glyph identifiers are
        // theme-independent), but the feature holds the registry as its
        // resolution context.
        XCTAssertEqual(feature.resolveCodepoint(id: "add"), "ea60")
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        XCTAssertEqual(MonaCodiconFeature.featureId, "codicon")
        XCTAssertTrue(features.contains("codicon"))

        // codicon is the icon-font / glyph-map feature: it declares no commands,
        // actions, contributions, options, menus, or keybindings.
        XCTAssertTrue(MonaCodiconFeature.declaredActionIds.isEmpty)
        XCTAssertTrue(MonaCodiconFeature.declaredCommandIds.isEmpty)
        XCTAssertTrue(MonaCodiconFeature.declaredContributionIds.isEmpty)
        XCTAssertTrue(MonaCodiconFeature.declaredKeybindingCommands.isEmpty)
        XCTAssertTrue(MonaCodiconFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaCodiconFeature.declaredMenuIds.isEmpty)
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaCodiconFeature()
        let ticket = gate.captureTicket()

        var received: MonaCodiconResolution?
        let accepted = feature.publishResolution(
            MonaCodiconResolution(id: "add", codepointHex: "ea60", character: feature.resolveCharacter(id: "add")),
            executor: executor,
            ticket: ticket
        ) { resolution in
            received = resolution
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received?.id, "add")
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaCodiconFeature()
        var fired: [MonaCodiconEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, resolution still returns the value but fires no event.
        let resolution = feature.resolve(id: "add")
        XCTAssertEqual(resolution.id, "add")
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaCodiconFeature()
        // codicon declares no actions, so the localized label list is empty —
        // but the routing path through MonaLocalization is wired.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertTrue(enLabels.isEmpty)
        XCTAssertEqual(enLabels.count, MonaCodiconFeature.declaredActionIds.count)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaCodiconFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testContractBehavior() {
        let features = MonaFeatureRegistry()
        let feature = MonaCodiconFeature()

        let featureLive = features.contains(MonaCodiconFeature.featureId)
        let actionCount = MonaCodiconFeature.declaredActionIds.count
        let commandCount = MonaCodiconFeature.declaredCommandIds.count
        let contribCount = MonaCodiconFeature.declaredContributionIds.count
        let kbCount = MonaCodiconFeature.declaredKeybindingCommands.count
        let optionCount = MonaCodiconFeature.declaredOptionIds.count
        let menuCount = MonaCodiconFeature.declaredMenuIds.count

        let slicePass = MonaCodiconFeature.declaredActionIds.isEmpty
            && MonaCodiconFeature.declaredCommandIds.isEmpty
            && MonaCodiconFeature.declaredContributionIds.isEmpty
            && MonaCodiconFeature.declaredKeybindingCommands.isEmpty
            && MonaCodiconFeature.declaredOptionIds.isEmpty
            && MonaCodiconFeature.declaredMenuIds.isEmpty

        // Mutation: codicon resolves identifiers and performs NO text mutation.
        // The model is unchanged after a resolution; the transaction gateway is
        // the mutation boundary codicon would route through if it mutated.
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let beforeVersion = model.getVersionId()
        _ = feature.resolve(id: "add")
        let mutation = (model.getValue() == "hello" && model.getVersionId() == beforeVersion && gateway.model === model)

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let resolution = MonaCodiconResolution(id: "add", codepointHex: "ea60", character: feature.resolveCharacter(id: "add"))
        _ = feature.publishResolution(resolution, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("CODICON feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
