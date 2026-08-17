// MonaContextmenuFeatureTests.swift
//
// P05-T110 — Implement retained feature contextmenu.
//
// Verifies the contextmenu feature across its three implementation operations:
//   1. Feature-specific behavior: construct the ordered native editor context
//      menu from menu registries (MonaMenuRegistry / MonaBuiltinMenus + the
//      neutral MonaMenuModel → adapt to AppKit).
//   2. The exact feature identity `contextmenu` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     CONTEXTMENU feature=live actions=1 commands=1 contributions=1 keybindings=1 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaContextmenuFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "hello\nworld") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/contextmenu-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: construct the ordered native context menu

    func testBuildContextMenuReturnsNativeMenuFromEditorContextModel() {
        let menus = MonaMenuRegistry()
        let gateway = MonaContextMenuGateway()
        let feature = MonaContextmenuFeature(menuRegistry: menus, gateway: gateway)
        let context = MonaKeybindingContext()

        let nsMenu = feature.buildContextMenu(context: context)

        XCTAssertNotNil(nsMenu)
        XCTAssertGreaterThan(nsMenu!.numberOfItems, 0)
    }

    func testBuildContextMenuPreservesDeclarationOrderFromMenuRegistry() {
        let menus = MonaMenuRegistry()
        let gateway = MonaContextMenuGateway()
        let feature = MonaContextmenuFeature(menuRegistry: menus, gateway: gateway)
        let context = MonaKeybindingContext()

        let nsMenu = feature.buildContextMenu(context: context)!

        // The EditorContext menu's first visible item (group 9_cutcopypaste,
        // order 1) is "Cut".
        let firstNonSeparator = nsMenu.items.first { !$0.isSeparatorItem }
        XCTAssertNotNil(firstNonSeparator)
        XCTAssertEqual(firstNonSeparator?.title, "Cut")

        // "Copy" and "Paste" should be present in the menu.
        let titles = nsMenu.items.map { $0.title }
        XCTAssertTrue(titles.contains("Copy"))
        XCTAssertTrue(titles.contains("Paste"))
    }

    func testBuildContextMenuIncludesSeparatorsBetweenGroups() {
        let menus = MonaMenuRegistry()
        let gateway = MonaContextMenuGateway()
        let feature = MonaContextmenuFeature(menuRegistry: menus, gateway: gateway)
        let context = MonaKeybindingContext()

        let nsMenu = feature.buildContextMenu(context: context)!

        let separatorCount = nsMenu.items.filter { $0.isSeparatorItem }.count
        XCTAssertGreaterThan(separatorCount, 0)
    }

    func testBuildContextMenuAdaptsNeutralModelToAppMenuModel() {
        let menus = MonaMenuRegistry()
        let gateway = MonaContextMenuGateway()
        let feature = MonaContextmenuFeature(menuRegistry: menus, gateway: gateway)
        let context = MonaKeybindingContext()

        let appModel = feature.buildAppMenuModel(context: context)

        XCTAssertNotNil(appModel)
        XCTAssertGreaterThan(appModel!.items.count, 0)
    }

    func testBuildContextMenuReturnsNilForUnknownMenuId() {
        let menus = MonaMenuRegistry()
        let gateway = MonaContextMenuGateway()
        let feature = MonaContextmenuFeature(menuRegistry: menus, gateway: gateway)
        let context = MonaKeybindingContext()

        let nsMenu = feature.buildContextMenu(menuId: "NonexistentMenu", context: context)
        XCTAssertNil(nsMenu)
    }

    func testBuildContextMenuIsNoOpAfterDisposal() {
        let menus = MonaMenuRegistry()
        let gateway = MonaContextMenuGateway()
        let feature = MonaContextmenuFeature(menuRegistry: menus, gateway: gateway)
        feature.dispose()

        let nsMenu = feature.buildContextMenu(context: MonaKeybindingContext())
        XCTAssertNil(nsMenu)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaContextmenuFeature.featureId, "contextmenu")
        XCTAssertTrue(features.contains("contextmenu"))

        let actionIds = MonaContextmenuFeature.declaredActionIds
        XCTAssertEqual(actionIds, ["editor.action.showContextMenu"])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaContextmenuFeature.declaredCommandIds
        XCTAssertEqual(commandIds, ["editor.action.showContextMenu"])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaContextmenuFeature.declaredContributionIds, [
            "editor.contrib.contextmenu"
        ])
        for id in MonaContextmenuFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaContextmenuFeature.declaredKeybindingCommands, [
            "editor.action.showContextMenu"
        ])
        for id in MonaContextmenuFeature.declaredKeybindingCommands {
            let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaContextmenuFeature.declaredOptionIds, ["contextmenu"])
        for id in MonaContextmenuFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaContextmenuFeature.declaredMenuIds, [])
        for id in MonaContextmenuFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaContextmenuFeature()
        let ticket = gate.captureTicket()

        var received: [MonaContextmenuEvent] = []
        let accepted = feature.publishContextmenuEvent(
            MonaContextmenuEvent(menuId: "EditorContext", itemCount: 6),
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
        let feature = MonaContextmenuFeature()
        var fired: [MonaContextmenuEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaContextmenuFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaContextmenuFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Show Editor Context Menu")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaContextmenuFeature()
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
        let feature = MonaContextmenuFeature(menuRegistry: menus, gateway: MonaContextMenuGateway())

        let featureLive = features.contains(MonaContextmenuFeature.featureId)
        let actionCount = MonaContextmenuFeature.declaredActionIds.count
        let commandCount = MonaContextmenuFeature.declaredCommandIds.count
        let contribCount = MonaContextmenuFeature.declaredContributionIds.count
        let kbCount = MonaContextmenuFeature.declaredKeybindingCommands.count
        let optionCount = MonaContextmenuFeature.declaredOptionIds.count
        let menuCount = MonaContextmenuFeature.declaredMenuIds.count

        let slicePass = MonaContextmenuFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaContextmenuFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaContextmenuFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaContextmenuFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaContextmenuFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaContextmenuFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: build the native context menu from the menu registry.
        let nsMenu = feature.buildContextMenu(context: MonaKeybindingContext())
        let mutation = nsMenu != nil && nsMenu!.numberOfItems > 0

        // Async publication.
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishContextmenuEvent(
            MonaContextmenuEvent(menuId: "EditorContext", itemCount: 1),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("CONTEXTMENU feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
