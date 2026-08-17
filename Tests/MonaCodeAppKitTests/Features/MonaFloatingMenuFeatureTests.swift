// MonaFloatingMenuFeatureTests.swift
//
// P05-T118 — Implement retained feature floatingMenu.
//
// Verifies the floatingMenu feature across its three implementation operations:
//   1. Feature-specific behavior: present the retained floating action menu as a
//      native AppKit floating menu (an `NSMenu`) without web layout dependencies
//      (no DOM / CSS). The menu is built from action items, presented at a
//      position, and dismissed; presentation fires a typed event.
//   2. The exact feature identity `floatingMenu` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testFloatingMenuContractLeaf` prints the contract line:
//     FLOATINGMENU feature=live actions=0 commands=0 contributions=1 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaFloatingMenuFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: native floating action menu

    func testBuildFloatingMenuProducesNativeNSMenuWithItems() {
        let feature = MonaFloatingMenuFeature()
        let items = [
            MonaFloatingMenuItem(actionId: "editor.action.clipboardCopyAction", label: "Copy", shortcut: "Cmd+C", isEnabled: true),
            MonaFloatingMenuItem(actionId: "editor.action.clipboardCutAction", label: "Cut", shortcut: "Cmd+X", isEnabled: true),
            MonaFloatingMenuItem(actionId: "editor.action.clipboardPasteAction", label: "Paste", shortcut: "Cmd+V", isEnabled: false)
        ]
        let menu = feature.buildFloatingMenu(items: items, context: MonaKeybindingContext())
        XCTAssertNotNil(menu)
        XCTAssertEqual(menu?.numberOfItems, 3)
        XCTAssertEqual(menu?.items[0].title, "Copy")
        XCTAssertEqual(menu?.items[1].title, "Cut")
        XCTAssertEqual(menu?.items[2].title, "Paste")
        // A disabled item is reflected on the native item.
        XCTAssertEqual(menu?.items[2].isEnabled, false)
    }

    func testBuildFloatingMenuReturnsNilWhenDisposed() {
        let feature = MonaFloatingMenuFeature()
        feature.dispose()
        let menu = feature.buildFloatingMenu(
            items: [MonaFloatingMenuItem(actionId: "x", label: "X", shortcut: nil, isEnabled: true)],
            context: MonaKeybindingContext())
        XCTAssertNil(menu)
    }

    func testBuildFloatingMenuReturnsNilForEmptyItems() {
        let feature = MonaFloatingMenuFeature()
        let menu = feature.buildFloatingMenu(items: [], context: MonaKeybindingContext())
        XCTAssertNil(menu)
    }

    func testPresentFloatingMenuFiresPresentedEvent() {
        let feature = MonaFloatingMenuFeature()
        var events: [MonaFloatingMenuEvent] = []
        _ = feature.onChange { events.append($0) }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "A", action: nil, keyEquivalent: ""))
        let presented = feature.presentFloatingMenu(
            menu,
            at: MonaPosition(line: 1, column: 1),
            in: nil)
        XCTAssertTrue(presented)
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0].presented)
        XCTAssertEqual(events[0].menuId, MonaFloatingMenuFeature.floatingMenuId)
        XCTAssertEqual(events[0].itemCount, 1)
    }

    func testDismissFloatingMenuFiresDismissedEventAndClearsCurrent() {
        let feature = MonaFloatingMenuFeature()
        var events: [MonaFloatingMenuEvent] = []
        _ = feature.onChange { events.append($0) }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "A", action: nil, keyEquivalent: ""))
        _ = feature.presentFloatingMenu(menu, at: MonaPosition(line: 1, column: 1), in: nil)
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0].presented)

        feature.dismissFloatingMenu()
        XCTAssertEqual(events.count, 2)
        XCTAssertFalse(events[1].presented)
        XCTAssertNil(feature.currentFloatingMenu)
    }

    func testPresentFloatingMenuIsNoOpAfterDispose() {
        let feature = MonaFloatingMenuFeature()
        feature.dispose()
        let presented = feature.presentFloatingMenu(
            NSMenu(),
            at: MonaPosition(line: 1, column: 1),
            in: nil)
        XCTAssertFalse(presented)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertTrue(features.contains(MonaFloatingMenuFeature.featureId))
        XCTAssertEqual(MonaFloatingMenuFeature.featureId, "floatingMenu")

        // floatingMenu owns no actions / commands / keybindings / options / menus
        // of its own — it presents other features' actions via the floating menu.
        XCTAssertTrue(MonaFloatingMenuFeature.declaredActionIds.isEmpty)
        XCTAssertTrue(MonaFloatingMenuFeature.declaredCommandIds.isEmpty)
        XCTAssertTrue(MonaFloatingMenuFeature.declaredKeybindingCommands.isEmpty)
        XCTAssertTrue(MonaFloatingMenuFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaFloatingMenuFeature.declaredMenuIds.isEmpty)

        // The single declared contribution is the floating-toolbar contribution
        // (the native floating action menu), referenced verbatim.
        XCTAssertEqual(MonaFloatingMenuFeature.declaredContributionIds,
                       ["editor.contrib.floatingToolbar"])
        for id in MonaFloatingMenuFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }
        // Sanity: the declared slices reference only ids that exist in the frozen
        // registries (no phantoms).
        for id in MonaFloatingMenuFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }
        for id in MonaFloatingMenuFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }
        for name in MonaFloatingMenuFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: name), "missing option \(name)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testModelMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/floating")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaFloatingMenuFeature()
        let position = MonaPosition(line: 1, column: 2)
        let committed = feature.commitActionTrigger(
            gateway: gateway,
            actionId: "editor.action.clipboardCopyAction",
            position: position
        )
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, position)
        XCTAssertEqual(committed[0].activePosition, position)
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/floating-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaFloatingMenuFeature()
        let event = MonaFloatingMenuEvent(menuId: MonaFloatingMenuFeature.floatingMenuId, itemCount: 2, presented: true)
        let ticket = gate.captureTicket()

        var received: [MonaFloatingMenuEvent] = []
        let accepted = feature.publishFloatingMenuEvent(
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
        let feature = MonaFloatingMenuFeature()
        var fired: [MonaFloatingMenuEvent] = []
        _ = feature.onChange { fired.append($0) }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "A", action: nil, keyEquivalent: ""))
        _ = feature.presentFloatingMenu(menu, at: MonaPosition(line: 1, column: 1), in: nil)
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)

        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        // After dispose, presentation / dismissal are no-ops and fire nothing.
        _ = feature.presentFloatingMenu(menu, at: MonaPosition(line: 1, column: 1), in: nil)
        feature.dismissFloatingMenu()
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaFloatingMenuFeature()
        let items = [
            MonaFloatingMenuItem(actionId: "a", label: "Copy", shortcut: nil, isEnabled: true),
            MonaFloatingMenuItem(actionId: "b", label: "Cut", shortcut: nil, isEnabled: true)
        ]
        let enLabels = feature.localizedMenuLabels(for: items, profile: .default)
        XCTAssertEqual(enLabels, ["Copy", "Cut"])
        let pseudoLabels = feature.localizedMenuLabels(for: items, profile: .custom("pseudo"))
        XCTAssertEqual(pseudoLabels.count, 2)
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaFloatingMenuFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testFloatingMenuContractLeaf() {
        let features = MonaFeatureRegistry()
        let contributions = MonaContributionRegistry()
        let feature = MonaFloatingMenuFeature()

        let featureLive = features.contains(MonaFloatingMenuFeature.featureId)
        let actionCount = MonaFloatingMenuFeature.declaredActionIds.count
        let commandCount = MonaFloatingMenuFeature.declaredCommandIds.count
        let contribCount = MonaFloatingMenuFeature.declaredContributionIds.count
        let kbCount = MonaFloatingMenuFeature.declaredKeybindingCommands.count
        let optionCount = MonaFloatingMenuFeature.declaredOptionIds.count
        let menuCount = MonaFloatingMenuFeature.declaredMenuIds.count

        let slicePass = MonaFloatingMenuFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }

        // Mutation: route a trigger selection through the transaction gateway.
        let model = MonaCodeModel(text: "x", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitActionTrigger(
            gateway: gateway,
            actionId: "editor.action.fontZoomIn",
            position: MonaPosition(line: 1, column: 1)
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        // Async: publish a floating-menu event through the provider executor.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let event = MonaFloatingMenuEvent(menuId: MonaFloatingMenuFeature.floatingMenuId, itemCount: 1, presented: true)
        _ = feature.publishFloatingMenuEvent(event, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        // Disposal.
        feature.dispose()
        let disposalPass = feature.isDisposed

        // Localization.
        let items = [MonaFloatingMenuItem(actionId: "a", label: "Copy", shortcut: nil, isEnabled: true)]
        let localizationPass = feature.localizedMenuLabels(for: items, profile: .default) == ["Copy"]

        // Plain-text degradation.
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("FLOATINGMENU feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
