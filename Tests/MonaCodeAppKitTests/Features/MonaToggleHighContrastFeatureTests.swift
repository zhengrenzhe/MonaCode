// MonaToggleHighContrastFeatureTests.swift
//
// P05-T154 — Implement retained feature toggleHighContrast.
//
// Verifies the toggleHighContrast feature across its three implementation
// operations:
//   1. Feature-specific behavior: toggle the explicit high-contrast theme
//      profile and invalidate paint state (reuse T006 `MonaThemeRegistry`
//      setTheme to hc-black / hc-light + invalidate paint).
//   2. The exact feature identity `toggleHighContrast` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation (read-only — none performed), asynchronous
//      publication, disposal, localization, and degraded plain-text behavior
//      through the shared gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     TOGGLEHIGHCONTRAST feature=live actions=1 commands=1 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaToggleHighContrastFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 5") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/hc-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: toggle hc theme profile + invalidate paint

    func testToggleTurnsOnHighContrastFromNonHighContrastDefault() {
        let registry = MonaThemeRegistry()
        // Boots on `vs-dark` (Monaco's standalone default, non-high-contrast).
        XCTAssertEqual(registry.currentThemeId, "vs-dark")
        XCTAssertFalse(registry.isHighContrast)

        let feature = MonaToggleHighContrastFeature(themeRegistry: registry)
        let state = feature.toggleHighContrast()

        XCTAssertEqual(state?.themeId, "hc-black")
        XCTAssertEqual(state?.isHighContrast, true)
        XCTAssertEqual(registry.currentThemeId, "hc-black")
        XCTAssertTrue(registry.isHighContrast)
    }

    func testToggleTurnsOffHighContrastWhenAlreadyHighContrast() {
        let registry = MonaThemeRegistry()
        registry.setTheme("hc-black")
        XCTAssertTrue(registry.isHighContrast)

        let feature = MonaToggleHighContrastFeature(themeRegistry: registry)
        let state = feature.toggleHighContrast()

        XCTAssertEqual(state?.themeId, "vs-dark")
        XCTAssertEqual(state?.isHighContrast, false)
        XCTAssertFalse(registry.isHighContrast)
    }

    func testToggleOffFromHcLightReturnsToNonHighContrastDefault() {
        let registry = MonaThemeRegistry()
        registry.setTheme("hc-light")
        XCTAssertTrue(registry.isHighContrast)

        let feature = MonaToggleHighContrastFeature(themeRegistry: registry)
        let state = feature.toggleHighContrast()

        XCTAssertEqual(state?.themeId, "vs-dark")
        XCTAssertEqual(state?.isHighContrast, false)
    }

    func testToggleFiresToggleEventAndPaintInvalidation() {
        let registry = MonaThemeRegistry()
        let feature = MonaToggleHighContrastFeature(themeRegistry: registry)

        var toggles: [MonaHighContrastToggleEvent] = []
        var paints: [MonaPaintInvalidationEvent] = []
        _ = feature.onToggle { toggles.append($0) }
        _ = feature.onPaintInvalidation { paints.append($0) }

        _ = feature.toggleHighContrast()

        XCTAssertEqual(toggles.count, 1)
        XCTAssertEqual(toggles[0].previousThemeId, "vs-dark")
        XCTAssertEqual(toggles[0].state.themeId, "hc-black")
        XCTAssertEqual(paints.count, 1)
        XCTAssertEqual(paints[0].reason, "highContrastToggle")
    }

    func testInvalidatePaintStateFiresEventWithoutTogglingTheme() {
        let registry = MonaThemeRegistry()
        let feature = MonaToggleHighContrastFeature(themeRegistry: registry)

        var paints: [MonaPaintInvalidationEvent] = []
        _ = feature.onPaintInvalidation { paints.append($0) }

        feature.invalidatePaintState()
        XCTAssertEqual(paints.count, 1)
        // Theme unchanged.
        XCTAssertEqual(registry.currentThemeId, "vs-dark")
    }

    func testToggleIsNoOpAfterDisposal() {
        let registry = MonaThemeRegistry()
        let feature = MonaToggleHighContrastFeature(themeRegistry: registry)
        feature.dispose()

        let state = feature.toggleHighContrast()
        XCTAssertNil(state)
        XCTAssertEqual(registry.currentThemeId, "vs-dark")
        XCTAssertFalse(registry.isHighContrast)
    }

    func testCurrentHighContrastStateReflectsRegistry() {
        let registry = MonaThemeRegistry()
        let feature = MonaToggleHighContrastFeature(themeRegistry: registry)

        XCTAssertEqual(feature.currentHighContrastState.themeId, "vs-dark")
        XCTAssertFalse(feature.currentHighContrastState.isHighContrast)

        registry.setTheme("hc-light")
        XCTAssertEqual(feature.currentHighContrastState.themeId, "hc-light")
        XCTAssertTrue(feature.currentHighContrastState.isHighContrast)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaToggleHighContrastFeature.featureId, "toggleHighContrast")
        XCTAssertTrue(features.contains("toggleHighContrast"))

        XCTAssertEqual(MonaToggleHighContrastFeature.declaredActionIds, [
            "editor.action.toggleHighContrast"
        ])
        for id in MonaToggleHighContrastFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaToggleHighContrastFeature.declaredCommandIds, [
            "editor.action.toggleHighContrast"
        ])
        for id in MonaToggleHighContrastFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaToggleHighContrastFeature.declaredContributionIds, [])
        XCTAssertEqual(MonaToggleHighContrastFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaToggleHighContrastFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaToggleHighContrastFeature.declaredMenuIds, [])
        _ = contributions
        _ = menus
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGatewayWithoutTouchingModel() {
        let feature = MonaToggleHighContrastFeature()
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
        let feature = MonaToggleHighContrastFeature()
        let ticket = gate.captureTicket()

        let state = MonaHighContrastState(themeId: "hc-black", isHighContrast: true)
        var received: [MonaHighContrastState] = []
        let accepted = feature.publishToggle(
            state,
            executor: executor,
            ticket: ticket
        ) { event in received.append(event) }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0].themeId, "hc-black")
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaToggleHighContrastFeature()
        var toggles: [MonaHighContrastToggleEvent] = []
        var paints: [MonaPaintInvalidationEvent] = []
        _ = feature.onToggle { toggles.append($0) }
        _ = feature.onPaintInvalidation { paints.append($0) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(toggles.isEmpty)
        XCTAssertTrue(paints.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaToggleHighContrastFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaToggleHighContrastFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Toggle High Contrast Theme")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaToggleHighContrastFeature()
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
        let feature = MonaToggleHighContrastFeature()

        let featureLive = features.contains(MonaToggleHighContrastFeature.featureId)
        let actionCount = MonaToggleHighContrastFeature.declaredActionIds.count
        let commandCount = MonaToggleHighContrastFeature.declaredCommandIds.count
        let contribCount = MonaToggleHighContrastFeature.declaredContributionIds.count
        let kbCount = MonaToggleHighContrastFeature.declaredKeybindingCommands.count
        let optionCount = MonaToggleHighContrastFeature.declaredOptionIds.count
        let menuCount = MonaToggleHighContrastFeature.declaredMenuIds.count

        let slicePass = MonaToggleHighContrastFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaToggleHighContrastFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaToggleHighContrastFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaToggleHighContrastFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }

        // Feature behavior: toggle from vs-dark (non-hc) → hc-black (hc).
        let registry = MonaThemeRegistry()
        let themedFeature = MonaToggleHighContrastFeature(themeRegistry: registry)
        var paints = 0
        _ = themedFeature.onPaintInvalidation { _ in paints += 1 }
        let state = themedFeature.toggleHighContrast()
        let togglePass = state?.themeId == "hc-black"
            && state?.isHighContrast == true
            && registry.isHighContrast
            && paints == 1

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
        _ = feature.publishToggle(
            MonaHighContrastState(themeId: "hc-black", isHighContrast: true),
            executor: executor,
            ticket: pubGate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("TOGGLEHIGHCONTRAST feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(togglePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
