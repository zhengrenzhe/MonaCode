// MonaToggleTabFocusModeFeatureTests.swift
//
// P05-T155 — Implement retained feature toggleTabFocusMode.
//
// Verifies the toggleTabFocusMode feature across its three implementation
// operations:
//   1. Feature-specific behavior: switch Tab between editor command handling
//      and native focus traversal (reuse P04-T003 keybinding resolver's tab
//      handling).
//   2. The exact feature identity `toggleTabFocusMode` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation (read-only — none performed), asynchronous
//      publication, disposal, localization, and degraded plain-text behavior
//      through the shared gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     TOGGLETABFOCUSMODE feature=live actions=0 commands=1 contributions=0 keybindings=1 options=0 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaToggleTabFocusModeFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 5") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/tabfocus-\(UUID().uuidString)")
        )
    }

    /// A Tab key event (key code 2, no modifiers).
    private func tabEvent() -> MonaKeyEvent {
        return MonaKeyEvent(
            keyCode: .tab,
            keyText: "\t",
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 0
        )
    }

    /// A resolver pre-loaded with a single Tab keybinding (command
    /// `"tab.insert"`), so editor command handling is observable.
    private func tabResolver() -> MonaKeybindingResolver {
        return MonaKeybindingResolver(keybindings: [
            MonaKeybinding(
                key: .tab,
                modifiers: [],
                command: "tab.insert",
                when: nil,
                weight: 0
            )
        ])
    }

    // MARK: - 1. Feature-specific behavior: switch Tab between modes

    func testTabMovesFocusDefaultsToFalse() {
        let feature = MonaToggleTabFocusModeFeature()
        XCTAssertFalse(feature.tabMovesFocus)
        XCTAssertEqual(feature.currentTabFocusState.tabMovesFocus, false)
    }

    func testToggleTurnsTabMovesFocusOnThenOff() {
        let feature = MonaToggleTabFocusModeFeature()

        let on = feature.toggleTabFocusMode()
        XCTAssertEqual(on?.tabMovesFocus, true)
        XCTAssertTrue(feature.tabMovesFocus)

        let off = feature.toggleTabFocusMode()
        XCTAssertEqual(off?.tabMovesFocus, false)
        XCTAssertFalse(feature.tabMovesFocus)
    }

    func testToggleFiresEventWithNewState() {
        let feature = MonaToggleTabFocusModeFeature()
        var toggles: [MonaTabFocusToggleEvent] = []
        _ = feature.onToggle { toggles.append($0) }

        _ = feature.toggleTabFocusMode()
        _ = feature.toggleTabFocusMode()

        XCTAssertEqual(toggles.count, 2)
        XCTAssertEqual(toggles[0].state.tabMovesFocus, true)
        XCTAssertEqual(toggles[1].state.tabMovesFocus, false)
    }

    func testResolveTabDelegatesToResolverWhenTabMovesFocusIsFalse() {
        let feature = MonaToggleTabFocusModeFeature()
        let resolver = tabResolver()
        let chordState = MonaChordState(clock: { 0 })

        // tabMovesFocus is false → editor command handling: the resolver
        // dispatches the registered `tab.insert` command.
        let resolution = feature.resolveTab(
            event: tabEvent(),
            context: MonaKeybindingContext(),
            chordState: chordState,
            resolver: resolver
        )
        XCTAssertEqual(resolution.commandId, "tab.insert")
        XCTAssertTrue(resolution.outcome.handled)
        XCTAssertTrue(resolution.outcome.preventDefault)
        XCTAssertTrue(resolution.outcome.stopPropagation)
    }

    func testResolveTabPassesThroughToNativeFocusTraversalWhenTabMovesFocusIsTrue() {
        let feature = MonaToggleTabFocusModeFeature()
        _ = feature.toggleTabFocusMode() // tabMovesFocus → true
        let resolver = tabResolver()
        let chordState = MonaChordState(clock: { 0 })

        // tabMovesFocus is true → native focus traversal: the Tab event is
        // passed through regardless of the resolver's registered bindings.
        let resolution = feature.resolveTab(
            event: tabEvent(),
            context: MonaKeybindingContext(),
            chordState: chordState,
            resolver: resolver
        )
        XCTAssertNil(resolution.commandId)
        XCTAssertEqual(resolution.outcome, .default)
    }

    func testToggleIsNoOpAfterDisposal() {
        let feature = MonaToggleTabFocusModeFeature()
        feature.dispose()

        let state = feature.toggleTabFocusMode()
        XCTAssertNil(state)
        XCTAssertFalse(feature.tabMovesFocus)
    }

    func testResolveTabPassesThroughAfterDisposal() {
        let feature = MonaToggleTabFocusModeFeature()
        let resolver = tabResolver()
        let chordState = MonaChordState(clock: { 0 })
        feature.dispose()

        let resolution = feature.resolveTab(
            event: tabEvent(),
            context: MonaKeybindingContext(),
            chordState: chordState,
            resolver: resolver
        )
        XCTAssertNil(resolution.commandId)
        XCTAssertEqual(resolution.outcome, .default)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaToggleTabFocusModeFeature.featureId, "toggleTabFocusMode")
        XCTAssertTrue(features.contains("toggleTabFocusMode"))

        XCTAssertEqual(MonaToggleTabFocusModeFeature.declaredActionIds, [])

        XCTAssertEqual(MonaToggleTabFocusModeFeature.declaredCommandIds, [
            "editor.action.toggleTabFocusMode"
        ])
        for id in MonaToggleTabFocusModeFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaToggleTabFocusModeFeature.declaredContributionIds, [])

        XCTAssertEqual(MonaToggleTabFocusModeFeature.declaredKeybindingCommands, [
            "editor.action.toggleTabFocusMode"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaToggleTabFocusModeFeature.declaredKeybindingCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }

        XCTAssertEqual(MonaToggleTabFocusModeFeature.declaredOptionIds, [])

        XCTAssertEqual(MonaToggleTabFocusModeFeature.declaredMenuIds, [
            "CommandPalette"
        ])
        for id in MonaToggleTabFocusModeFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
        XCTAssertTrue(menus.contains(menuCommand: "editor.action.toggleTabFocusMode"))
        _ = actions
        _ = contributions
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGatewayWithoutTouchingModel() {
        let feature = MonaToggleTabFocusModeFeature()
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
        let feature = MonaToggleTabFocusModeFeature()
        let ticket = gate.captureTicket()

        let state = MonaTabFocusState(tabMovesFocus: true)
        var received: [MonaTabFocusState] = []
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
        XCTAssertEqual(received[0].tabMovesFocus, true)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaToggleTabFocusModeFeature()
        var toggles: [MonaTabFocusToggleEvent] = []
        _ = feature.onToggle { toggles.append($0) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(toggles.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaToggleTabFocusModeFeature()
        // toggleTabFocusMode declares no actions, so labels are empty under
        // every profile.
        XCTAssertEqual(feature.localizedActionLabels(profile: .default), [])
        XCTAssertEqual(feature.localizedActionLabels(profile: .custom("pseudo")), [])
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaToggleTabFocusModeFeature()
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
        let feature = MonaToggleTabFocusModeFeature()

        let featureLive = features.contains(MonaToggleTabFocusModeFeature.featureId)
        let actionCount = MonaToggleTabFocusModeFeature.declaredActionIds.count
        let commandCount = MonaToggleTabFocusModeFeature.declaredCommandIds.count
        let contribCount = MonaToggleTabFocusModeFeature.declaredContributionIds.count
        let kbCount = MonaToggleTabFocusModeFeature.declaredKeybindingCommands.count
        let optionCount = MonaToggleTabFocusModeFeature.declaredOptionIds.count
        let menuCount = MonaToggleTabFocusModeFeature.declaredMenuIds.count

        let slicePass = MonaToggleTabFocusModeFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaToggleTabFocusModeFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaToggleTabFocusModeFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaToggleTabFocusModeFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaToggleTabFocusModeFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Feature behavior: toggle flips tabMovesFocus; resolveTab switches
        // between editor command handling and native focus traversal.
        let resolver = tabResolver()
        let chordState = MonaChordState(clock: { 0 })

        // editor command handling (default).
        let editorResolution = feature.resolveTab(
            event: tabEvent(),
            context: MonaKeybindingContext(),
            chordState: chordState,
            resolver: resolver
        )
        let editorPass = editorResolution.commandId == "tab.insert"
            && editorResolution.outcome.handled

        // native focus traversal (after toggle).
        _ = feature.toggleTabFocusMode()
        let nativeResolution = feature.resolveTab(
            event: tabEvent(),
            context: MonaKeybindingContext(),
            chordState: chordState,
            resolver: resolver
        )
        let nativePass = nativeResolution.commandId == nil
            && nativeResolution.outcome == .default

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
            MonaTabFocusState(tabMovesFocus: true),
            executor: executor,
            ticket: pubGate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("TOGGLETABFOCUSMODE feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(editorPass)
        XCTAssertTrue(nativePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
