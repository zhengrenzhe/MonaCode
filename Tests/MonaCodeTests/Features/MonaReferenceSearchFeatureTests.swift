// MonaReferenceSearchFeatureTests.swift
//
// P05-T146 — Implement retained feature referenceSearch.
//
// Verifies the referenceSearch feature across its three implementation operations:
//   1. Feature-specific behavior: stream, group, navigate, and cancel
//      reference provider results (reuse `MonaProviderExecutor` P05-T013 +
//      `MonaCancellationToken`).
//   2. The exact feature identity `referenceSearch` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     REFERENCESEARCH feature=live actions=0 commands=9 contributions=1 keybindings=6 options=0 menus=2 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaReferenceSearchFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/referencesearch-\(UUID().uuidString)")
        )
    }

    private func sampleLocations() -> [MonaReferenceLocation] {
        return [
            MonaReferenceLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 5)
                )
            ),
            MonaReferenceLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 3, column: 5),
                    endPosition: MonaPosition(line: 3, column: 9)
                )
            ),
            MonaReferenceLocation(
                uri: "file:///b.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 2, column: 1),
                    endPosition: MonaPosition(line: 2, column: 5)
                )
            )
        ]
    }

    // MARK: - 1. Feature-specific behavior: stream / group / navigate / cancel

    func testGroupReferencesGroupsByUriPreservingOrder() {
        let feature = MonaReferenceSearchFeature()
        let groups = feature.groupReferences(sampleLocations())
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].uri, "file:///a.swift")
        XCTAssertEqual(groups[0].locations.count, 2)
        XCTAssertEqual(groups[1].uri, "file:///b.swift")
        XCTAssertEqual(groups[1].locations.count, 1)
    }

    func testGroupReferencesEmptyWhenNoLocations() {
        let feature = MonaReferenceSearchFeature()
        let groups = feature.groupReferences([])
        XCTAssertTrue(groups.isEmpty)
    }

    func testOpenReferencesRetainsResultAndFiresEvent() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel()
        let version = model.getVersionId()
        var fired: [MonaReferenceSearchEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let result = feature.openReferences(sampleLocations(), modelVersion: version)

        XCTAssertNotNil(result)
        XCTAssertTrue(feature.isVisible)
        XCTAssertEqual(feature.currentIndex, 0)
        XCTAssertEqual(result?.locations.count, 3)
        XCTAssertEqual(result?.groups.count, 2)
        XCTAssertEqual(fired.count, 1)
        XCTAssertTrue(fired[0].visible)
    }

    func testOpenReferencesWithNoLocationsIsDismissed() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel()
        let version = model.getVersionId()

        let result = feature.openReferences([], modelVersion: version)

        XCTAssertNil(result)
        XCTAssertFalse(feature.isVisible)
    }

    func testNavigateNextAdvancesWithWrap() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.openReferences(sampleLocations(), modelVersion: version)

        // 0 → 1
        _ = feature.navigateNext()
        XCTAssertEqual(feature.currentIndex, 1)
        // 1 → 2
        _ = feature.navigateNext()
        XCTAssertEqual(feature.currentIndex, 2)
        // 2 → 0 (wrap)
        _ = feature.navigateNext()
        XCTAssertEqual(feature.currentIndex, 0)
    }

    func testNavigatePreviousDecrementsWithWrap() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.openReferences(sampleLocations(), modelVersion: version)

        // 0 → 2 (wrap backward)
        _ = feature.navigatePrevious()
        XCTAssertEqual(feature.currentIndex, 2)
        // 2 → 1
        _ = feature.navigatePrevious()
        XCTAssertEqual(feature.currentIndex, 1)
    }

    func testRevealReferenceReturnsLocationAtIndex() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let locations = sampleLocations()
        _ = feature.openReferences(locations, modelVersion: version)

        let first = feature.revealReference(at: 0)
        XCTAssertEqual(first?.uri, "file:///a.swift")

        let outOfRange = feature.revealReference(at: 99)
        XCTAssertNil(outOfRange)
    }

    func testNavigateWhenNotVisibleIsNoOp() {
        let feature = MonaReferenceSearchFeature()
        XCTAssertFalse(feature.isVisible)
        let result = feature.navigateNext()
        XCTAssertNil(result)
        XCTAssertEqual(feature.currentIndex, 0)
    }

    func testCloseReferenceSearchHidesAndClears() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.openReferences(sampleLocations(), modelVersion: version)
        XCTAssertTrue(feature.isVisible)

        var fired: [MonaReferenceSearchEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let closed = feature.closeReferenceSearch()
        XCTAssertTrue(closed)
        XCTAssertFalse(feature.isVisible)
        XCTAssertNil(feature.currentResult)
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(fired[0].visible)
    }

    func testStreamReferencesPublishesGroupedResult() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let ticket = gate.captureTicket()
        let token = MonaCancellationToken.none

        var received: MonaReferenceSearchResult?
        let accepted = feature.streamReferences(
            sampleLocations(),
            executor: executor,
            ticket: ticket,
            token: token
        ) { result in
            received = result
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.groups.count, 2)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testCancelReferenceSearchSuppressesStreamAndCloses() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.openReferences(sampleLocations(), modelVersion: version)
        XCTAssertTrue(feature.isVisible)
        // Capture the in-flight token before cancelling.
        let token = feature.currentCancellationToken

        // Cancel: requests cancellation on the token source and closes the peek.
        let cancelled = feature.cancelReferenceSearch()
        XCTAssertTrue(cancelled)
        XCTAssertFalse(feature.isVisible)
        XCTAssertTrue(token.isCancellationRequested)

        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)

        // After cancellation, streaming with the cancelled token is suppressed:
        // publication is NOT enqueued.
        var received: MonaReferenceSearchResult?
        let accepted = feature.streamReferences(
            sampleLocations(),
            executor: executor,
            ticket: gate.captureTicket(),
            token: token
        ) { result in
            received = result
        }
        XCTAssertFalse(accepted)
        XCTAssertEqual(queue.pendingCount, 0)
        executor.drain()
        XCTAssertNil(received)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaReferenceSearchFeature.featureId, "referenceSearch")
        XCTAssertTrue(features.contains("referenceSearch"))

        XCTAssertEqual(MonaReferenceSearchFeature.declaredActionIds, [])
        for id in MonaReferenceSearchFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaReferenceSearchFeature.declaredCommandIds, [
            "editor.action.referenceSearch.trigger",
            "closeReferenceSearch",
            "closeReferenceSearchEditor",
            "goToNextReference",
            "goToPreviousReference",
            "openReference",
            "openReferenceToSide",
            "revealReference",
            "togglePeekWidgetFocus"
        ])
        for id in MonaReferenceSearchFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaReferenceSearchFeature.declaredContributionIds, [
            "editor.contrib.referencesController"
        ])
        for id in MonaReferenceSearchFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaReferenceSearchFeature.declaredKeybindingCommands, [
            "closeReferenceSearch",
            "goToNextReference",
            "goToPreviousReference",
            "openReferenceToSide",
            "revealReference",
            "togglePeekWidgetFocus"
        ])
        let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaReferenceSearchFeature.declaredKeybindingCommands {
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaReferenceSearchFeature.declaredOptionIds, [])
        for id in MonaReferenceSearchFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaReferenceSearchFeature.declaredMenuIds, [
            "CommandPalette",
            "EditorContextPeek"
        ])
        for id in MonaReferenceSearchFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaReferenceSearchFeature()
        let model = makeModel("ab")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        _ = feature.openReferences(sampleLocations(), modelVersion: version)

        // Apply a rename edit at the first reference's range through the gateway.
        let outcome = feature.commitReferenceEdit(
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 3)
            ),
            text: "value",
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "value")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaReferenceSearchFeature()
        let ticket = gate.captureTicket()

        var received: MonaReferenceSearchResult?
        let accepted = feature.publishReferences(
            MonaReferenceSearchResult(
                locations: sampleLocations(),
                groups: feature.groupReferences(sampleLocations()),
                currentIndex: 0
            ),
            executor: executor,
            ticket: ticket
        ) { result in
            received = result
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.locations.count, 3)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaReferenceSearchFeature()
        var fired: [MonaReferenceSearchEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let model = makeModel()
        _ = feature.openReferences(sampleLocations(), modelVersion: model.getVersionId())
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, open / navigate / close are no-ops and fire no events.
        let countBefore = fired.count
        _ = feature.openReferences(sampleLocations(), modelVersion: model.getVersionId())
        XCTAssertFalse(feature.isVisible)
        _ = feature.navigateNext()
        _ = feature.closeReferenceSearch()
        XCTAssertEqual(fired.count, countBefore)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaReferenceSearchFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaReferenceSearchFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)

        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaReferenceSearchFeature()
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
        let options = MonaOptionStore()
        let menus = MonaMenuRegistry()
        let feature = MonaReferenceSearchFeature()

        let featureLive = features.contains(MonaReferenceSearchFeature.featureId)
        let actionCount = MonaReferenceSearchFeature.declaredActionIds.count
        let commandCount = MonaReferenceSearchFeature.declaredCommandIds.count
        let contribCount = MonaReferenceSearchFeature.declaredContributionIds.count
        let kbCount = MonaReferenceSearchFeature.declaredKeybindingCommands.count
        let optionCount = MonaReferenceSearchFeature.declaredOptionIds.count
        let menuCount = MonaReferenceSearchFeature.declaredMenuIds.count

        let slicePass = MonaReferenceSearchFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaReferenceSearchFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaReferenceSearchFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaReferenceSearchFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaReferenceSearchFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaReferenceSearchFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Open + group + navigate.
        let model = makeModel("let x = 1")
        let version = model.getVersionId()
        let opened = feature.openReferences(sampleLocations(), modelVersion: version)
        let openPass = opened != nil && feature.isVisible && feature.currentIndex == 0
        let groupPass = opened?.groups.count == 2

        _ = feature.navigateNext()
        let nextPass = feature.currentIndex == 1
        _ = feature.navigateNext()
        _ = feature.navigateNext()
        let wrapPass = feature.currentIndex == 0

        // Mutation: rename edit at the first reference's range through the gateway.
        var mutation = false
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitReferenceEdit(
            at: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 5)
            ),
            text: "value",
            gateway: gateway
        )
        if case .applied = outcome {
            mutation = true
        }

        // Async streaming through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.streamReferences(
            sampleLocations(),
            executor: executor,
            ticket: gate.captureTicket(),
            token: MonaCancellationToken.none
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        // Cancel: requests cancellation on the token source and closes the peek.
        _ = feature.openReferences(sampleLocations(), modelVersion: model.getVersionId())
        let cancelToken = feature.currentCancellationToken
        let cancelled = feature.cancelReferenceSearch()
        // After cancellation, streaming with the cancelled token is suppressed.
        var suppressed = false
        _ = feature.streamReferences(
            sampleLocations(),
            executor: executor,
            ticket: gate.captureTicket(),
            token: cancelToken
        ) { _ in suppressed = true }
        executor.drain()
        let cancelPass = cancelled && !suppressed && !feature.isVisible

        let closed = feature.closeReferenceSearch()
        let closePass = !closed // already closed by cancel; closing again is a no-op

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("REFERENCESEARCH feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(openPass)
        XCTAssertTrue(groupPass)
        XCTAssertTrue(nextPass)
        XCTAssertTrue(wrapPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(cancelPass)
        XCTAssertTrue(closePass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
