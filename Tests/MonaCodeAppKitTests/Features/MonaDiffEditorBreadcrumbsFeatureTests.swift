// MonaDiffEditorBreadcrumbsFeatureTests.swift
//
// P05-T113 — Implement retained feature diffEditorBreadcrumbs.
//
// Verifies the diffEditorBreadcrumbs feature across its three implementation
// operations:
//   1. Feature-specific behavior: present multi-diff navigation breadcrumbs from
//      host-owned item metadata — build the ordered breadcrumb items from the
//      host's multi-diff item metadata, mark the active item, and navigate by
//      index (firing a selection event routed through the async gateways).
//   2. The exact feature identity `diffEditorBreadcrumbs` + its declared
//      commands, actions, contributions, options, menus, and keybindings
//      (referenced verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     DIFFEDITORBREADCRUMBS feature=live actions=0 commands=0 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaDiffEditorBreadcrumbsFeatureTests: XCTestCase {

    private func sampleMetadata() -> [MonaDiffEditorBreadcrumbMetadata] {
        return [
            MonaDiffEditorBreadcrumbMetadata(itemId: "a", label: "Sources/Foo.swift", uri: MonaURI(scheme: "file", path: "/src/Foo.swift"), isActive: true),
            MonaDiffEditorBreadcrumbMetadata(itemId: "b", label: "Sources/Bar.swift", uri: MonaURI(scheme: "file", path: "/src/Bar.swift"), isActive: false),
            MonaDiffEditorBreadcrumbMetadata(itemId: "c", label: "Tests/Baz.swift", uri: MonaURI(scheme: "file", path: "/tst/Baz.swift"), isActive: false)
        ]
    }

    // MARK: - 1. Feature-specific behavior: present breadcrumbs from host metadata

    func testBuildBreadcrumbsPresentsOrderedItemsFromHostMetadata() {
        let feature = MonaDiffEditorBreadcrumbsFeature()
        let breadcrumbs = feature.buildBreadcrumbs(from: sampleMetadata())

        XCTAssertEqual(breadcrumbs.count, 3)
        XCTAssertEqual(breadcrumbs.map { $0.label }, ["Sources/Foo.swift", "Sources/Bar.swift", "Tests/Baz.swift"])
        XCTAssertEqual(breadcrumbs.map { $0.itemId }, ["a", "b", "c"])
        XCTAssertEqual(feature.breadcrumbCount, 3)
    }

    func testBuildBreadcrumbsMarksActiveItemFromMetadata() {
        let feature = MonaDiffEditorBreadcrumbsFeature()
        let breadcrumbs = feature.buildBreadcrumbs(from: sampleMetadata())

        let active = breadcrumbs.filter { $0.isActive }
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.itemId, "a")
        XCTAssertEqual(feature.activeBreadcrumbIndex, 0)
    }

    func testBuildBreadcrumbsWithEmptyMetadataYieldsNoBreadcrumbs() {
        let feature = MonaDiffEditorBreadcrumbsFeature()
        let breadcrumbs = feature.buildBreadcrumbs(from: [])
        XCTAssertTrue(breadcrumbs.isEmpty)
        XCTAssertEqual(feature.breadcrumbCount, 0)
        XCTAssertNil(feature.activeBreadcrumbIndex)
    }

    func testNavigateByIndexUpdatesActiveBreadcrumbAndFiresEvent() {
        let feature = MonaDiffEditorBreadcrumbsFeature()
        _ = feature.buildBreadcrumbs(from: sampleMetadata())
        var fired: [MonaDiffEditorBreadcrumbsEvent] = []
        _ = feature.onChange { fired.append($0) }

        let navigated = feature.navigate(toIndex: 2)

        XCTAssertTrue(navigated)
        XCTAssertEqual(feature.activeBreadcrumbIndex, 2)
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.selectedItemId, "c")
        XCTAssertEqual(fired.first?.selectedIndex, 2)
    }

    func testNavigateOutOfBoundsIsRejected() {
        let feature = MonaDiffEditorBreadcrumbsFeature()
        _ = feature.buildBreadcrumbs(from: sampleMetadata())

        XCTAssertFalse(feature.navigate(toIndex: -1))
        XCTAssertFalse(feature.navigate(toIndex: 3))
        // Active breadcrumb is unchanged.
        XCTAssertEqual(feature.activeBreadcrumbIndex, 0)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()

        XCTAssertEqual(MonaDiffEditorBreadcrumbsFeature.featureId, "diffEditorBreadcrumbs")
        XCTAssertTrue(features.contains("diffEditorBreadcrumbs"))

        // diffEditorBreadcrumbs declares no commands, actions, contributions,
        // options, menus, or keybindings — it is a host-metadata-driven
        // presentation feature with no own command registrations.
        XCTAssertEqual(MonaDiffEditorBreadcrumbsFeature.declaredActionIds, [])
        XCTAssertEqual(MonaDiffEditorBreadcrumbsFeature.declaredCommandIds, [])
        XCTAssertEqual(MonaDiffEditorBreadcrumbsFeature.declaredContributionIds, [])
        XCTAssertEqual(MonaDiffEditorBreadcrumbsFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaDiffEditorBreadcrumbsFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaDiffEditorBreadcrumbsFeature.declaredMenuIds, [])

        // The empty slice trivially satisfies the registry.
        XCTAssertTrue(MonaDiffEditorBreadcrumbsFeature.declaredActionIds.allSatisfy { actions.contains($0) })
        XCTAssertTrue(MonaDiffEditorBreadcrumbsFeature.declaredCommandIds.allSatisfy { commands.contains($0) })
        XCTAssertTrue(MonaDiffEditorBreadcrumbsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) })
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/bc-\(UUID().uuidString)")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaDiffEditorBreadcrumbsFeature()
        _ = feature.buildBreadcrumbs(from: sampleMetadata())
        let ticket = gate.captureTicket()

        var received: MonaDiffEditorBreadcrumbsEvent?
        let accepted = feature.publishBreadcrumbsEvent(
            MonaDiffEditorBreadcrumbsEvent(selectedItemId: "b", selectedIndex: 1),
            executor: executor,
            ticket: ticket
        ) { event in received = event }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.selectedItemId, "b")
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaDiffEditorBreadcrumbsFeature()
        var fired: [MonaDiffEditorBreadcrumbsEvent] = []
        _ = feature.onChange { fired.append($0) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, build / navigate are no-ops.
        let breadcrumbs = feature.buildBreadcrumbs(from: sampleMetadata())
        XCTAssertTrue(breadcrumbs.isEmpty)
        XCTAssertEqual(feature.breadcrumbCount, 0)
        XCTAssertFalse(feature.navigate(toIndex: 0))
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaDiffEditorBreadcrumbsFeature()
        // diffEditorBreadcrumbs declares no actions; labels are empty.
        XCTAssertEqual(feature.localizedActionLabels(profile: .default).count, 0)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaDiffEditorBreadcrumbsFeature()
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
        let feature = MonaDiffEditorBreadcrumbsFeature()

        let featureLive = features.contains(MonaDiffEditorBreadcrumbsFeature.featureId)
        let actionCount = MonaDiffEditorBreadcrumbsFeature.declaredActionIds.count
        let commandCount = MonaDiffEditorBreadcrumbsFeature.declaredCommandIds.count
        let contribCount = MonaDiffEditorBreadcrumbsFeature.declaredContributionIds.count
        let kbCount = MonaDiffEditorBreadcrumbsFeature.declaredKeybindingCommands.count
        let optionCount = MonaDiffEditorBreadcrumbsFeature.declaredOptionIds.count
        let menuCount = MonaDiffEditorBreadcrumbsFeature.declaredMenuIds.count

        let actionSlicePass = MonaDiffEditorBreadcrumbsFeature.declaredActionIds.allSatisfy { actions.contains($0) }
        let commandSlicePass = MonaDiffEditorBreadcrumbsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
        let contribSlicePass = MonaDiffEditorBreadcrumbsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
        let kbSlicePass = MonaDiffEditorBreadcrumbsFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }
        let optionSlicePass = MonaDiffEditorBreadcrumbsFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
        let menuSlicePass = MonaDiffEditorBreadcrumbsFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }
        let slicePass = actionSlicePass && commandSlicePass && contribSlicePass && kbSlicePass && optionSlicePass && menuSlicePass

        // Mutation: build the breadcrumbs from host-owned item metadata and
        // navigate to an item (the "mutation" is the active-breadcrumb update,
        // routed as a host-owned selection — no model text mutation occurs).
        let breadcrumbs = feature.buildBreadcrumbs(from: sampleMetadata())
        let buildPass = breadcrumbs.count == 3 && feature.breadcrumbCount == 3
        let navigated = feature.navigate(toIndex: 1)
        let mutation = buildPass && navigated && feature.activeBreadcrumbIndex == 1

        // Async publication.
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/bc-leaf-\(UUID().uuidString)")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishBreadcrumbsEvent(
            MonaDiffEditorBreadcrumbsEvent(selectedItemId: "b", selectedIndex: 1),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("DIFFEDITORBREADCRUMBS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
