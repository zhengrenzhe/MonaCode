// MonaFontZoomFeatureTests.swift
//
// P05-T120 — Implement retained feature fontZoom.
//
// Verifies the fontZoom feature across its three implementation operations:
//   1. Feature-specific behavior: apply a bounded editor font zoom (clamped to
//      the frozen min/max) and invalidate the EXACT layout stamp domains the
//      `fontChanged` mutation dirties — no missing, no fanout — through the
//      P03-T004 `MonaDependencyStampEdgeMap`.
//   2. The exact feature identity `fontZoom` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testFontZoomContractLeaf` prints the contract line:
//     FONTZOOM feature=live actions=3 commands=3 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaFontZoomFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: bounded zoom + exact stamp invalidation

    func testZoomInIncreasesZoomByStep() {
        let feature = MonaFontZoomFeature()
        XCTAssertEqual(feature.currentZoom, 1.0, accuracy: 1e-9)
        let zoom = feature.zoomIn()
        XCTAssertEqual(zoom, 1.0 + MonaFontZoomFeature.zoomStep, accuracy: 1e-9)
        XCTAssertEqual(feature.currentZoom, zoom, accuracy: 1e-9)
    }

    func testZoomOutDecreasesZoomByStep() {
        let feature = MonaFontZoomFeature()
        let zoom = feature.zoomOut()
        XCTAssertEqual(zoom, 1.0 - MonaFontZoomFeature.zoomStep, accuracy: 1e-9)
        XCTAssertEqual(feature.currentZoom, zoom, accuracy: 1e-9)
    }

    func testZoomIsClampedToMax() {
        let feature = MonaFontZoomFeature()
        let zoom = feature.applyZoom(delta: 1000.0)
        XCTAssertEqual(zoom, MonaFontZoomFeature.maxZoom, accuracy: 1e-9)
        XCTAssertEqual(feature.currentZoom, MonaFontZoomFeature.maxZoom, accuracy: 1e-9)
    }

    func testZoomIsClampedToMin() {
        let feature = MonaFontZoomFeature()
        let zoom = feature.applyZoom(delta: -1000.0)
        XCTAssertEqual(zoom, MonaFontZoomFeature.minZoom, accuracy: 1e-9)
        XCTAssertEqual(feature.currentZoom, MonaFontZoomFeature.minZoom, accuracy: 1e-9)
    }

    func testResetZoomReturnsToOne() {
        let feature = MonaFontZoomFeature()
        _ = feature.applyZoom(delta: 3.0)
        let zoom = feature.resetZoom()
        XCTAssertEqual(zoom, 1.0, accuracy: 1e-9)
        XCTAssertEqual(feature.currentZoom, 1.0, accuracy: 1e-9)
    }

    func testApplyZoomFiresEventWithInvalidatedDomains() {
        let feature = MonaFontZoomFeature()
        var events: [MonaFontZoomEvent] = []
        _ = feature.onChange { events.append($0) }
        _ = feature.zoomIn()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].zoom, feature.currentZoom, accuracy: 1e-9)
        // The exact domains invalidated by a font change: geometry, scrollDimension, frame.
        XCTAssertEqual(Set(events[0].invalidatedDomains),
                       Set(arrayLiteral: .geometry, .scrollDimension, .frame))
    }

    func testInvalidatedDomainsForZoomChangeIsExactFrozenSet() {
        let feature = MonaFontZoomFeature()
        let domains = feature.invalidatedDomainsForZoomChange()
        // The `fontChanged` mutation invalidates exactly geometry + scrollDimension + frame.
        XCTAssertEqual(domains, Set(arrayLiteral: .geometry, .scrollDimension, .frame))
    }

    func testStampInvalidationAcceptsExactSetAndRejectsMissingAndFanout() {
        let feature = MonaFontZoomFeature()
        let exact: Set<MonaStampDomain> = [.geometry, .scrollDimension, .frame]
        XCTAssertTrue(feature.validateStampInvalidation(claimed: exact).isValid)

        // Missing scrollDimension → not valid.
        let missing: Set<MonaStampDomain> = [.geometry, .frame]
        XCTAssertFalse(feature.validateStampInvalidation(claimed: missing).isValid)

        // Fanout (paint is not invalidated by a font change) → not valid.
        let fanout: Set<MonaStampDomain> = [.geometry, .scrollDimension, .frame, .paint]
        XCTAssertFalse(feature.validateStampInvalidation(claimed: fanout).isValid)
    }

    func testApplyZoomIsNoOpAfterDispose() {
        let feature = MonaFontZoomFeature()
        feature.dispose()
        let zoom = feature.applyZoom(delta: 1.0)
        XCTAssertEqual(zoom, 1.0, accuracy: 1e-9)
        XCTAssertEqual(feature.currentZoom, 1.0, accuracy: 1e-9)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertTrue(features.contains(MonaFontZoomFeature.featureId))
        XCTAssertEqual(MonaFontZoomFeature.featureId, "fontZoom")

        let actionIds = MonaFontZoomFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.fontZoomIn",
            "editor.action.fontZoomOut",
            "editor.action.fontZoomReset"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }
        XCTAssertEqual(MonaFontZoomFeature.declaredCommandIds, actionIds)

        // fontZoom owns no contribution / keybinding / option / menu of its own.
        XCTAssertTrue(MonaFontZoomFeature.declaredContributionIds.isEmpty)
        XCTAssertTrue(MonaFontZoomFeature.declaredKeybindingCommands.isEmpty)
        XCTAssertTrue(MonaFontZoomFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaFontZoomFeature.declaredMenuIds.isEmpty)

        // Sanity: the declared slices reference only ids that exist.
        for id in MonaFontZoomFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }
        for name in MonaFontZoomFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: name), "missing option \(name)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testModelMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/fontzoom")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaFontZoomFeature()
        let position = MonaPosition(line: 1, column: 1)
        let committed = feature.commitZoomChange(gateway: gateway, position: position)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, position)
        XCTAssertEqual(committed[0].activePosition, position)
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/fontzoom-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaFontZoomFeature()
        let event = MonaFontZoomEvent(
            zoom: 1.5,
            invalidatedDomains: [.geometry, .scrollDimension, .frame])
        let ticket = gate.captureTicket()

        var received: [MonaFontZoomEvent] = []
        let accepted = feature.publishFontZoomEvent(
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
        let feature = MonaFontZoomFeature()
        var fired: [MonaFontZoomEvent] = []
        _ = feature.onChange { fired.append($0) }
        _ = feature.zoomIn()
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        _ = feature.zoomIn()
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaFontZoomFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaFontZoomFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Increase Editor Font Size")
        XCTAssertEqual(enLabels[1], "Decrease Editor Font Size")
        XCTAssertEqual(enLabels[2], "Reset Editor Font Size")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaFontZoomFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testFontZoomContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let feature = MonaFontZoomFeature()

        let featureLive = features.contains(MonaFontZoomFeature.featureId)
        let actionCount = MonaFontZoomFeature.declaredActionIds.count
        let commandCount = MonaFontZoomFeature.declaredCommandIds.count
        let contribCount = MonaFontZoomFeature.declaredContributionIds.count
        let kbCount = MonaFontZoomFeature.declaredKeybindingCommands.count
        let optionCount = MonaFontZoomFeature.declaredOptionIds.count
        let menuCount = MonaFontZoomFeature.declaredMenuIds.count

        let slicePass = MonaFontZoomFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaFontZoomFeature.declaredCommandIds.allSatisfy { commands.contains($0) }

        // Bounded zoom + exact stamp invalidation.
        let clampedMax = feature.applyZoom(delta: 1000.0) == MonaFontZoomFeature.maxZoom
        _ = feature.resetZoom()
        let clampedMin = feature.applyZoom(delta: -1000.0) == MonaFontZoomFeature.minZoom
        _ = feature.resetZoom()
        let exactDomains = feature.invalidatedDomainsForZoomChange()
            == Set(arrayLiteral: .geometry, .scrollDimension, .frame)
        let exactValidated = feature.validateStampInvalidation(
            claimed: [.geometry, .scrollDimension, .frame]).isValid

        // Mutation: route a zoom-change selection through the transaction gateway.
        let model = MonaCodeModel(text: "x", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitZoomChange(
            gateway: gateway,
            position: MonaPosition(line: 1, column: 1)
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        // Async: publish a font-zoom event through the provider executor.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let event = MonaFontZoomEvent(
            zoom: 1.2,
            invalidatedDomains: [.geometry, .scrollDimension, .frame])
        _ = feature.publishFontZoomEvent(event, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("FONTZOOM feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(clampedMax)
        XCTAssertTrue(clampedMin)
        XCTAssertTrue(exactDomains)
        XCTAssertTrue(exactValidated)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
