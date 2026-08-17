// MonaGotoErrorFeatureTests.swift
//
// P05-T122 — Implement retained feature gotoError.
//
// Verifies the gotoError feature across its three implementation operations:
//   1. Feature-specific behavior: navigate marker severities (error > warning >
//      info, then by position) in next/prev direction, and announce the selected
//      diagnostic through the shared `MonaAXAnnouncementBridge` (P04-T012);
//      markers/diagnostics come from the model.
//   2. The exact feature identity `gotoError` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, degraded plain-text behavior, and the AX announcement
//      through the shared gateways.
//
// On Green, `testGotoErrorContractLeaf` prints the contract line:
//     GOTOERROR feature=live actions=4 commands=5 contributions=3 keybindings=5 options=0 menus=2 mutation=pass async=pass disposal=pass localization=pass plaintext=pass announcement=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaGotoErrorFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: navigate severities + announce

    func testNavigateNextOrdersBySeverityThenPosition() {
        let feature = MonaGotoErrorFeature()
        let diags = [
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .info, message: "info at 3"),
                position: MonaPosition(line: 3, column: 1)),
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "error at 5"),
                position: MonaPosition(line: 5, column: 1)),
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .warning, message: "warn at 2"),
                position: MonaPosition(line: 2, column: 1)),
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "error at 1"),
                position: MonaPosition(line: 1, column: 1))
        ]
        feature.setDiagnostics(diags)
        // Severity desc (error first), then position asc: error@1, error@5, warn@2, info@3.
        let first = feature.navigate(.next)
        XCTAssertEqual(first?.marker.message, "error at 1")
        let second = feature.navigate(.next)
        XCTAssertEqual(second?.marker.message, "error at 5")
        let third = feature.navigate(.next)
        XCTAssertEqual(third?.marker.message, "warn at 2")
        let fourth = feature.navigate(.next)
        XCTAssertEqual(fourth?.marker.message, "info at 3")
    }

    func testNavigatePrevWrapsAround() {
        let feature = MonaGotoErrorFeature()
        let diags = [
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1)),
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .warning, message: "w1"),
                position: MonaPosition(line: 2, column: 1))
        ]
        feature.setDiagnostics(diags)
        // From no selection, prev wraps to the last (info-ordered) marker.
        let prev = feature.navigate(.prev)
        XCTAssertEqual(prev?.marker.message, "w1")
        let prev2 = feature.navigate(.prev)
        XCTAssertEqual(prev2?.marker.message, "e1")
    }

    func testNavigateNextWrapsAroundToFirst() {
        let feature = MonaGotoErrorFeature()
        let diags = [
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1)),
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .warning, message: "w1"),
                position: MonaPosition(line: 2, column: 1))
        ]
        feature.setDiagnostics(diags)
        _ = feature.navigate(.next) // e1
        _ = feature.navigate(.next) // w1
        let wrap = feature.navigate(.next) // wraps to e1
        XCTAssertEqual(wrap?.marker.message, "e1")
    }

    func testNavigateReturnsNilWhenNoDiagnostics() {
        let feature = MonaGotoErrorFeature()
        XCTAssertNil(feature.navigate(.next))
        XCTAssertNil(feature.navigate(.prev))
        XCTAssertNil(feature.selectedDiagnostic)
    }

    func testNavigateFiresEventWithSelectedDiagnostic() {
        let feature = MonaGotoErrorFeature()
        var events: [MonaGotoErrorEvent] = []
        _ = feature.onChange { events.append($0) }
        feature.setDiagnostics([
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1))
        ])
        _ = feature.navigate(.next)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].selectedDiagnostic?.marker.message, "e1")
        XCTAssertEqual(events[0].index, 0)
    }

    func testAnnounceSelectedDiagnosticRoutesThroughAnnouncementBridge() throws {
        let feature = MonaGotoErrorFeature()
        let bridge = MonaAXAnnouncementBridge(profile: .default)
        feature.setDiagnostics([
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1))
        ])
        _ = feature.navigate(.next)
        XCTAssertEqual(bridge.pendingCount, 0)
        let queued = try feature.announceSelectedDiagnostic(bridge: bridge)
        XCTAssertTrue(queued)
        XCTAssertEqual(bridge.pendingCount, 1)
        let text = bridge.nextAnnouncement()
        XCTAssertEqual(text, bridge.lastAnnounced)
        XCTAssertEqual(bridge.pendingCount, 0)
    }

    func testAnnounceDedupsRepeatSelection() throws {
        let feature = MonaGotoErrorFeature()
        let bridge = MonaAXAnnouncementBridge(profile: .default)
        feature.setDiagnostics([
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1))
        ])
        _ = feature.navigate(.next)
        _ = try feature.announceSelectedDiagnostic(bridge: bridge)
        XCTAssertEqual(bridge.pendingCount, 1)
        _ = bridge.nextAnnouncement()
        // Same selection → dedup drops the repeat.
        let queued = try feature.announceSelectedDiagnostic(bridge: bridge)
        XCTAssertFalse(queued)
        XCTAssertEqual(bridge.pendingCount, 0)
    }

    func testCommitRevealRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/gotoerr")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaGotoErrorFeature()
        feature.setDiagnostics([
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 2, column: 1))
        ])
        _ = feature.navigate(.next)
        let committed = feature.commitReveal(gateway: gateway)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testNavigateIsNoOpAfterDispose() {
        let feature = MonaGotoErrorFeature()
        feature.setDiagnostics([
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1))
        ])
        feature.dispose()
        XCTAssertNil(feature.navigate(.next))
        XCTAssertTrue(feature.isDisposed)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertTrue(features.contains(MonaGotoErrorFeature.featureId))
        XCTAssertEqual(MonaGotoErrorFeature.featureId, "gotoError")

        let actionIds = MonaGotoErrorFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.marker.next",
            "editor.action.marker.prev",
            "editor.action.marker.nextInFiles",
            "editor.action.marker.prevInFiles"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // Commands: the close command + the four marker navigation actions,
        // in manifest source order.
        XCTAssertEqual(MonaGotoErrorFeature.declaredCommandIds, [
            "closeMarkersNavigation",
            "editor.action.marker.next",
            "editor.action.marker.nextInFiles",
            "editor.action.marker.prev",
            "editor.action.marker.prevInFiles"
        ])
        for id in MonaGotoErrorFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaGotoErrorFeature.declaredContributionIds, [
            "editor.contrib.markerDecorations",
            "editor.contrib.markerController",
            "editor.contrib.markerSelectionStatus"
        ])
        for id in MonaGotoErrorFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        let kbCommands = MonaGotoErrorFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands, [
            "editor.action.marker.next",
            "editor.action.marker.nextInFiles",
            "editor.action.marker.prev",
            "editor.action.marker.prevInFiles",
            "closeMarkersNavigation"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }

        // gotoError owns no editor options.
        XCTAssertTrue(MonaGotoErrorFeature.declaredOptionIds.isEmpty)

        XCTAssertEqual(MonaGotoErrorFeature.declaredMenuIds, [
            "gotoErrorTitleMenu",
            "MenubarGoMenu"
        ])
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "a\nb",
            uri: MonaURI(scheme: "inmemory", path: "/gotoerr-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaGotoErrorFeature()
        feature.setDiagnostics([
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1))
        ])
        _ = feature.navigate(.next)
        let event = MonaGotoErrorEvent(
            selectedDiagnostic: feature.selectedDiagnostic, index: 0)
        let ticket = gate.captureTicket()

        var received: [MonaGotoErrorEvent] = []
        let accepted = feature.publishGotoErrorEvent(
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
        let feature = MonaGotoErrorFeature()
        var fired: [MonaGotoErrorEvent] = []
        _ = feature.onChange { fired.append($0) }
        feature.setDiagnostics([
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1))
        ])
        _ = feature.navigate(.next)
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        _ = feature.navigate(.next)
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaGotoErrorFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaGotoErrorFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Go to Next Problem (Error, Warning, Info)")
        XCTAssertEqual(enLabels[1], "Go to Previous Problem (Error, Warning, Info)")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaGotoErrorFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testGotoErrorContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let feature = MonaGotoErrorFeature()

        let featureLive = features.contains(MonaGotoErrorFeature.featureId)
        let actionCount = MonaGotoErrorFeature.declaredActionIds.count
        let commandCount = MonaGotoErrorFeature.declaredCommandIds.count
        let contribCount = MonaGotoErrorFeature.declaredContributionIds.count
        let kbCount = MonaGotoErrorFeature.declaredKeybindingCommands.count
        let optionCount = MonaGotoErrorFeature.declaredOptionIds.count
        let menuCount = MonaGotoErrorFeature.declaredMenuIds.count

        let slicePass = MonaGotoErrorFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaGotoErrorFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaGotoErrorFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
        let kbPass = MonaGotoErrorFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }

        // Diagnostics from the model: navigate by severity, announce selection.
        feature.setDiagnostics([
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .warning, message: "w1"),
                position: MonaPosition(line: 2, column: 1)),
            MonaGotoErrorDiagnostic(
                marker: MonaMarker(severity: .error, message: "e1"),
                position: MonaPosition(line: 1, column: 1))
        ])
        let selected = feature.navigate(.next)
        let navigationPass = selected?.marker.message == "e1"

        // Announcement: route the selected diagnostic through the AX bridge.
        let bridge = MonaAXAnnouncementBridge(profile: .default)
        var announcementPass = false
        do {
            let queued = try feature.announceSelectedDiagnostic(bridge: bridge)
            announcementPass = queued && bridge.pendingCount == 1
            _ = bridge.nextAnnouncement()
        } catch {
            announcementPass = false
        }

        // Mutation: reveal the selection through the transaction gateway.
        let model = MonaCodeModel(text: "x\ny", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitReveal(gateway: gateway).count == 1
            && gateway.lastCommittedSelections.count == 1

        // Async: publish a goto-error event through the provider executor.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let event = MonaGotoErrorEvent(selectedDiagnostic: selected, index: 0)
        _ = feature.publishGotoErrorEvent(event, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("GOTOERROR feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail") announcement=\(announcementPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(kbPass)
        XCTAssertTrue(navigationPass)
        XCTAssertTrue(announcementPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
