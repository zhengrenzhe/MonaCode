// MonaMiddleScrollFeatureTests.swift
//
// P05-T138 — Implement retained feature middleScroll.
//
// Verifies the middleScroll feature across its three implementation operations:
//   1. Feature-specific behavior: native middle-button scrolling with bounded
//      velocity and cancellation (reuse `MonaScrollModel` P03-T005 +
//      `MonaCancellationToken`).
//   2. The exact feature identity `middleScroll` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testMiddleScrollContractLeaf` prints the contract line:
//     MIDDLESCROLL feature=live actions=0 commands=0 contributions=1 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaMiddleScrollFeatureTests: XCTestCase {

    private func makeScrollModel(
        contentHeight: Double = 1000,
        viewportHeight: Double = 100
    ) -> MonaScrollModel {
        return MonaScrollModel(
            contentWidth: 800,
            contentHeight: contentHeight,
            viewportWidth: 800,
            viewportHeight: viewportHeight
        )
    }

    /// The anchor point for a middle-button drag.
    private let anchor = NSPoint(x: 50, y: 100)

    // MARK: - 1. Feature-specific behavior: bounded velocity + cancellation

    func testBeginMiddleButtonScrollActivatesDrag() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()

        let began = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)

        XCTAssertTrue(began)
        XCTAssertTrue(feature.isDragging)
    }

    func testBeginMiddleButtonScrollIsIdempotent() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()

        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)
        // A second begin without an end is a no-op (returns false).
        let second = feature.beginMiddleButtonScroll(at: NSPoint(x: 0, y: 0), in: scrollModel)
        XCTAssertFalse(second)
        XCTAssertTrue(feature.isDragging)
    }

    func testVelocityAtAnchorIsZero() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()
        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)

        let velocity = feature.currentVelocity(to: anchor)
        XCTAssertEqual(velocity, 0)
    }

    func testUpdateMiddleButtonScrollRequestsBoundedScroll() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()
        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)

        // Move the pointer 50 points above the anchor (deltaFromAnchor = +50)
        // → velocity = +50 → the scroll model advances publishedScrollY by 50.
        let event = feature.updateMiddleButtonScroll(
            to: NSPoint(x: 50, y: anchor.y - 50), in: scrollModel
        )
        XCTAssertNotNil(event)
        XCTAssertEqual(scrollModel.publishedScrollY, 50, accuracy: 0.0001)
    }

    func testVelocityIsBoundedToMaxVelocity() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()
        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)

        // Move the pointer far beyond the anchor — the velocity must be
        // bounded to `maxVelocity` (no unbounded acceleration).
        let velocity = feature.currentVelocity(to: NSPoint(x: 50, y: anchor.y - 100000))
        XCTAssertEqual(velocity, MonaMiddleScrollFeature.maxVelocity, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(velocity, MonaMiddleScrollFeature.maxVelocity)
    }

    func testVelocityIsBoundedBelowNegativeMaxVelocity() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()
        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)

        let velocity = feature.currentVelocity(to: NSPoint(x: 50, y: anchor.y + 100000))
        XCTAssertEqual(velocity, -MonaMiddleScrollFeature.maxVelocity, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(velocity, -MonaMiddleScrollFeature.maxVelocity)
    }

    func testUpdateWithoutBeginIsNoOp() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()

        let event = feature.updateMiddleButtonScroll(to: NSPoint(x: 0, y: 0), in: scrollModel)
        XCTAssertNil(event)
        XCTAssertEqual(scrollModel.publishedScrollY, 0)
        XCTAssertFalse(feature.isDragging)
    }

    func testEndMiddleButtonScrollStopsDrag() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()
        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)
        XCTAssertTrue(feature.isDragging)

        let ended = feature.endMiddleButtonScroll()
        XCTAssertTrue(ended)
        XCTAssertFalse(feature.isDragging)
    }

    func testEndWithoutBeginReturnsFalse() {
        let feature = MonaMiddleScrollFeature()
        let ended = feature.endMiddleButtonScroll()
        XCTAssertFalse(ended)
    }

    func testCancelViaCancellationTokenStopsDrag() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()
        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)
        XCTAssertTrue(feature.isDragging)

        let cancelled = feature.cancelMiddleButtonScroll(token: .cancelled)
        XCTAssertTrue(cancelled)
        XCTAssertFalse(feature.isDragging)
    }

    func testCancelWithNonCancelledTokenReturnsFalse() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()
        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)

        let cancelled = feature.cancelMiddleButtonScroll(token: .none)
        XCTAssertFalse(cancelled)
        XCTAssertTrue(feature.isDragging)
    }

    func testCancelFiresCancelledEvent() {
        let feature = MonaMiddleScrollFeature()
        let scrollModel = makeScrollModel()
        _ = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)
        var fired: [MonaMiddleScrollEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        _ = feature.cancelMiddleButtonScroll(token: .cancelled)
        XCTAssertTrue(fired.contains { $0.cancelled })
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaMiddleScrollFeature.featureId, "middleScroll")
        XCTAssertTrue(features.contains("middleScroll"))

        // middleScroll declares a single contribution and no commands, actions,
        // options, menus, or keybindings.
        XCTAssertEqual(MonaMiddleScrollFeature.declaredActionIds, [])
        for id in MonaMiddleScrollFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaMiddleScrollFeature.declaredCommandIds, [])
        for id in MonaMiddleScrollFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaMiddleScrollFeature.declaredContributionIds, ["editor.contrib.middleScroll"])
        for id in MonaMiddleScrollFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaMiddleScrollFeature.declaredKeybindingCommands, [])
        XCTAssertEqual(MonaMiddleScrollFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaMiddleScrollFeature.declaredMenuIds, [])
        for id in MonaMiddleScrollFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaMiddleScrollFeature()
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/middlescroll-\(UUID().uuidString)")
        )
        let gateway = MonaTransactionGateway(model: model)
        let position = MonaPosition(line: 1, column: 2)

        let committed = feature.commitScrollReveal(gateway: gateway, position: position)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, position)
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/middlescroll-\(UUID().uuidString)")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaMiddleScrollFeature()
        let ticket = gate.captureTicket()
        let event = MonaMiddleScrollEvent(
            velocityY: 25, requestedScrollX: 0, requestedScrollY: 25,
            cancelled: false, active: true
        )

        var received: MonaMiddleScrollEvent?
        let accepted = feature.publishMiddleScrollEvent(
            event,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, event)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaMiddleScrollFeature()
        var fired: [MonaMiddleScrollEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, begin / update / cancel are no-ops.
        let scrollModel = makeScrollModel()
        let began = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)
        XCTAssertFalse(began)
        XCTAssertFalse(feature.isDragging)
        XCTAssertNil(feature.updateMiddleButtonScroll(to: anchor, in: scrollModel))
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaMiddleScrollFeature()
        // middleScroll declares no actions, so localized labels are empty
        // under every profile — but the path still routes through
        // MonaLocalization.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaMiddleScrollFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaMiddleScrollFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testMiddleScrollContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let feature = MonaMiddleScrollFeature()

        let featureLive = features.contains(MonaMiddleScrollFeature.featureId)
        let actionCount = MonaMiddleScrollFeature.declaredActionIds.count
        let commandCount = MonaMiddleScrollFeature.declaredCommandIds.count
        let contribCount = MonaMiddleScrollFeature.declaredContributionIds.count
        let kbCount = MonaMiddleScrollFeature.declaredKeybindingCommands.count
        let optionCount = MonaMiddleScrollFeature.declaredOptionIds.count
        let menuCount = MonaMiddleScrollFeature.declaredMenuIds.count

        let slicePass = MonaMiddleScrollFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaMiddleScrollFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaMiddleScrollFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaMiddleScrollFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaMiddleScrollFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Begin + update + bound + cancel.
        let scrollModel = makeScrollModel()
        let began = feature.beginMiddleButtonScroll(at: anchor, in: scrollModel)
        let beginPass = began && feature.isDragging

        // Bounded velocity: a far pointer offset must be clamped to maxVelocity.
        let boundedVelocity = feature.currentVelocity(to: NSPoint(x: 50, y: anchor.y - 100000))
        let boundPass = abs(boundedVelocity) <= MonaMiddleScrollFeature.maxVelocity + 0.0001
            && boundedVelocity == MonaMiddleScrollFeature.maxVelocity

        // Update requests a bounded scroll on the scroll model.
        _ = feature.updateMiddleButtonScroll(to: NSPoint(x: 50, y: anchor.y - 30), in: scrollModel)
        let updatePass = scrollModel.publishedScrollY > 0

        // Cancellation via the cancellation token stops the drag.
        let cancelled = feature.cancelMiddleButtonScroll(token: .cancelled)
        let cancelPass = cancelled && !feature.isDragging

        // Mutation: reveal a position through the gateway.
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/middlescroll-\(UUID().uuidString)")
        )
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitScrollReveal(
            gateway: gateway, position: MonaPosition(line: 1, column: 1)
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishMiddleScrollEvent(
            MonaMiddleScrollEvent(velocityY: 10, requestedScrollX: 0, requestedScrollY: 10, cancelled: false, active: true),
            executor: executor, ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("MIDDLESCROLL feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(beginPass)
        XCTAssertTrue(boundPass)
        XCTAssertTrue(updatePass)
        XCTAssertTrue(cancelPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
