// MonaSnippetFeatureTests.swift
//
// P05-T151 — Implement retained feature snippet.
//
// Verifies the snippet feature across its three implementation operations:
//   1. Feature-specific behavior: insert and navigate snippet sessions using
//      the Phase 06 snippet engine, routed through a Phase 06 snippet-engine
//      attachment point (a protocol the engine will implement). Edits via
//      `MonaTransactionGateway`; async via `MonaProviderExecutor` (P05-T013).
//   2. The exact feature identity `snippet` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     SNIPPET feature=live actions=0 commands=4 contributions=1 keybindings=3 options=2 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaSnippetFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "abc") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/snippet-\(UUID().uuidString)")
        )
    }

    /// A test snippet-engine attachment: records the parse/expand calls and
    /// produces two tabstops (a non-final at the insert start, a final at the
    /// insert end) — the shape the real Phase 06 engine will produce.
    private final class TestSnippetEngine: MonaSnippetEngineAttachment {
        var parsedText: String?
        var expandedText: String?
        func parseSnippet(_ text: String, insertRange: MonaRange) -> [MonaSnippetSessionTabstop] {
            parsedText = text
            return [
                MonaSnippetSessionTabstop(
                    index: 1,
                    range: insertRange,
                    placeholders: []
                ),
                MonaSnippetSessionTabstop(
                    index: 0,
                    range: MonaRange(
                        startPosition: insertRange.endPosition,
                        endPosition: insertRange.endPosition
                    ),
                    placeholders: []
                )
            ]
        }
        func expandSnippet(_ text: String) -> String {
            expandedText = text
            return text
        }
    }

    // MARK: - 1. Feature-specific behavior: insert / navigate / leave / release

    func testInsertSnippetWithEngineCreatesSessionAndMutatesModel() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let position = MonaPosition(line: 1, column: 4)

        let session = feature.insertSnippet(
            "X",
            at: position,
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )

        XCTAssertNotNil(session)
        XCTAssertEqual(model.getValue(), "abcX")
        XCTAssertEqual(engine.expandedText, "X")
        XCTAssertEqual(engine.parsedText, "X")
        XCTAssertEqual(session?.tabstops.count, 2)
        XCTAssertEqual(session?.currentIndex, 0)
        XCTAssertEqual(feature.activeSessionId, session?.id)
        XCTAssertEqual(feature.currentTabstop(for: session!.id)?.index, 1)
    }

    func testInsertSnippetWithoutEngineDegradesToSingleFinalTabstop() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()

        let session = feature.insertSnippet(
            "XY",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway
        )

        XCTAssertNotNil(session)
        XCTAssertEqual(model.getValue(), "abcXY")
        XCTAssertEqual(session?.tabstops.count, 1)
        // The fallback tabstop is the final tabstop (index 0).
        XCTAssertEqual(session?.tabstops.first?.index, 0)
    }

    func testMoveToNextTabstopAdvancesAndReturnsNewIndex() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )!
        XCTAssertEqual(session.currentIndex, 0)

        let next = feature.moveToNextTabstop(sessionId: session.id)
        XCTAssertEqual(next, 1)
        XCTAssertEqual(feature.currentTabstop(for: session.id)?.index, 0)
    }

    func testMoveToNextTabstopAtEndReturnsNil() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )!
        _ = feature.moveToNextTabstop(sessionId: session.id)

        let next = feature.moveToNextTabstop(sessionId: session.id)
        XCTAssertNil(next)
    }

    func testMoveToPreviousTabstopGoesBack() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )!
        _ = feature.moveToNextTabstop(sessionId: session.id)
        XCTAssertEqual(feature.currentTabstop(for: session.id)?.index, 0)

        let prev = feature.moveToPreviousTabstop(sessionId: session.id)
        XCTAssertEqual(prev, 0)
        XCTAssertEqual(feature.currentTabstop(for: session.id)?.index, 1)
    }

    func testMoveToPreviousTabstopAtStartReturnsNil() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )!

        let prev = feature.moveToPreviousTabstop(sessionId: session.id)
        XCTAssertNil(prev)
    }

    func testLeaveSnippetClearsActiveSession() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )!
        XCTAssertNotNil(feature.activeSessionId)

        let left = feature.leaveSnippet(sessionId: session.id)
        XCTAssertTrue(left)
        XCTAssertNil(feature.activeSessionId)
    }

    func testReleaseSessionDropsRetainedSession() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )!
        XCTAssertNotNil(feature.session(for: session.id))

        let released = feature.releaseSession(sessionId: session.id)
        XCTAssertEqual(released, 1)
        XCTAssertNil(feature.session(for: session.id))
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaSnippetFeature.featureId, "snippet")
        XCTAssertTrue(features.contains("snippet"))

        XCTAssertEqual(MonaSnippetFeature.declaredActionIds, [])
        for id in MonaSnippetFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaSnippetFeature.declaredCommandIds, [
            "acceptSnippet",
            "jumpToNextSnippetPlaceholder",
            "jumpToPrevSnippetPlaceholder",
            "leaveSnippet"
        ])
        for id in MonaSnippetFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSnippetFeature.declaredContributionIds, [
            "snippetController2"
        ])
        for id in MonaSnippetFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaSnippetFeature.declaredKeybindingCommands, [
            "jumpToNextSnippetPlaceholder",
            "jumpToPrevSnippetPlaceholder",
            "leaveSnippet"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaSnippetFeature.declaredKeybindingCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }

        XCTAssertEqual(MonaSnippetFeature.declaredOptionIds, [
            "snippetSuggestions",
            "stickyTabStops"
        ])

        XCTAssertEqual(MonaSnippetFeature.declaredMenuIds, [])
        for id in MonaSnippetFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaSnippetFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()

        let outcome = feature.insertSnippet(
            "XYZ",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )?.lastInsertOutcome

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "abcXYZ")
        } else {
            XCTFail("expected applied, got \(String(describing: outcome))")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaSnippetFeature()
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )!
        let ticket = gate.captureTicket()

        var received: MonaSnippetSession?
        let accepted = feature.publishSnippetSession(
            session,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, session)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaSnippetFeature()
        var fired: [MonaSnippetSessionEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, insert / navigate / leave / release are no-ops.
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )
        XCTAssertNil(session)
        XCTAssertEqual(model.getValue(), "abc")
        XCTAssertNil(feature.moveToNextTabstop(sessionId: "none"))
        XCTAssertNil(feature.moveToPreviousTabstop(sessionId: "none"))
        XCTAssertFalse(feature.leaveSnippet(sessionId: "none"))
        XCTAssertEqual(feature.releaseSession(sessionId: "none"), 0)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaSnippetFeature()
        // snippet declares no actions, so labels are empty under every profile.
        XCTAssertEqual(feature.localizedActionLabels(profile: .default), [])
        XCTAssertEqual(feature.localizedActionLabels(profile: .custom("pseudo")), [])
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaSnippetFeature()
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
        let feature = MonaSnippetFeature()

        let featureLive = features.contains(MonaSnippetFeature.featureId)
        let actionCount = MonaSnippetFeature.declaredActionIds.count
        let commandCount = MonaSnippetFeature.declaredCommandIds.count
        let contribCount = MonaSnippetFeature.declaredContributionIds.count
        let kbCount = MonaSnippetFeature.declaredKeybindingCommands.count
        let optionCount = MonaSnippetFeature.declaredOptionIds.count
        let menuCount = MonaSnippetFeature.declaredMenuIds.count

        let slicePass = MonaSnippetFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaSnippetFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaSnippetFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaSnippetFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaSnippetFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Insert a snippet session through the engine attachment + gateway.
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let engine = TestSnippetEngine()
        let session = feature.insertSnippet(
            "X",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: version,
            gateway: gateway,
            engine: engine
        )

        let mutation: Bool
        if let s = session, model.getValue() == "abcX", s.tabstops.count == 2 {
            mutation = true
        } else {
            mutation = false
        }

        // Navigate: next then previous.
        let navNext = feature.moveToNextTabstop(sessionId: session!.id) == 1
        let navPrev = feature.moveToPreviousTabstop(sessionId: session!.id) == 0
        let navigationPass = navNext && navPrev

        // Leave + release.
        let left = feature.leaveSnippet(sessionId: session!.id)
        let released = feature.releaseSession(sessionId: session!.id)
        let releasePass = left && released == 1

        // Async publication.
        let pubModel = makeModel("abc")
        let pubGateway = MonaTransactionGateway(model: pubModel)
        let pubVersion = pubModel.getVersionId()
        let pubEngine = TestSnippetEngine()
        let pubSession = feature.insertSnippet(
            "Y",
            at: MonaPosition(line: 1, column: 4),
            modelVersion: pubVersion,
            gateway: pubGateway,
            engine: pubEngine
        )!
        let pubGate = MonaPublicationGate(model: pubModel)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: pubGate, queue: queue)
        var delivered = false
        _ = feature.publishSnippetSession(pubSession, executor: executor, ticket: pubGate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("SNIPPET feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(navigationPass)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
