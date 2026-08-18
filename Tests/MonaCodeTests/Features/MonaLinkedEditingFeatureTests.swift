// MonaLinkedEditingFeatureTests.swift
//
// P05-T135 — Implement retained feature linkedEditing.
//
// Verifies the linkedEditing feature across its three implementation operations:
//   1. Feature-specific behavior: mirror linked-editing ranges under provider
//      version and cancellation gates (reuse MonaProviderExecutor P05-T013 +
//      MonaCancellationToken), with mirrored edits committed via
//      MonaTransactionGateway for mutation.
//   2. The exact feature identity `linkedEditing` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     LINKEDEDITING feature=live actions=1 commands=1 contributions=1 keybindings=1 options=2 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaLinkedEditingFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = x") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/linkedediting-\(UUID().uuidString)")
        )
    }

    /// A test provider that returns a fixed set of linked ranges, optionally
    /// gated by a cancellation token.
    private final class TestLinkedEditingProvider: MonaLinkedEditingRangeProvider {
        let ranges: MonaLinkedEditingRanges?
        let token: MonaCancellationToken?
        init(ranges: MonaLinkedEditingRanges?, token: MonaCancellationToken? = nil) {
            self.ranges = ranges
            self.token = token
        }
        func provideLinkedEditingRanges(
            at position: MonaPosition,
            model: MonaCodeModel,
            token: MonaCancellationToken
        ) -> MonaProviderResult<MonaLinkedEditingRanges?> {
            if let gate = self.token {
                return .cancelable(gate, ranges)
            }
            return .synchronous(ranges)
        }
    }

    private func linkedRanges() -> MonaLinkedEditingRanges {
        // Two linked occurrences of "x" in "let x = x".
        return MonaLinkedEditingRanges(
            ranges: [
                MonaRange(startLine: 1, startColumn: 5, endLine: 1, endColumn: 6),
                MonaRange(startLine: 1, startColumn: 9, endLine: 1, endColumn: 10)
            ],
            wordRange: MonaRange(startLine: 1, startColumn: 5, endLine: 1, endColumn: 6)
        )
    }

    // MARK: - 1. Feature-specific behavior: mirror linked-editing ranges

    func testStartLinkedEditingRetainsRangesFromProvider() {
        let feature = MonaLinkedEditingFeature()
        let model = makeModel("let x = x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestLinkedEditingProvider(ranges: linkedRanges())
        let tokenSource = MonaCancellationTokenSource()

        var received: [MonaLinkedEditingRanges] = []
        let accepted = feature.startLinkedEditing(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { ranges in
            if let r = ranges { received.append(r) }
        }
        XCTAssertTrue(accepted)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0].ranges.count, 2)
        XCTAssertTrue(feature.hasActiveSession)
    }

    func testMirrorEditAppliesSameTextToAllLinkedRanges() {
        let feature = MonaLinkedEditingFeature()
        let model = makeModel("let x = x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestLinkedEditingProvider(ranges: linkedRanges())
        let tokenSource = MonaCancellationTokenSource()
        let gateway = MonaTransactionGateway(model: model)

        _ = feature.startLinkedEditing(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { _ in }
        executor.drain()

        let outcome = feature.mirrorEdit(text: "count", gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "let count = count")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testMirrorEditWithoutActiveSessionIsDropped() {
        let feature = MonaLinkedEditingFeature()
        let model = makeModel("let x = x")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.mirrorEdit(text: "count", gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "let x = x")
        } else {
            XCTFail("expected dropped with no session, got \(outcome)")
        }
    }

    func testStartLinkedEditingDropsWhenTokenAlreadyCancelled() {
        let feature = MonaLinkedEditingFeature()
        let model = makeModel("let x = x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        // Provider gates publication on an already-cancelled token.
        let provider = TestLinkedEditingProvider(
            ranges: linkedRanges(),
            token: MonaCancellationToken.cancelled
        )
        let tokenSource = MonaCancellationTokenSource()

        var received: [MonaLinkedEditingRanges] = []
        let accepted = feature.startLinkedEditing(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { ranges in
            if let r = ranges { received.append(r) }
        }
        // The cancelable shape with an already-cancelled token normalizes to
        // "no value to publish": not enqueued.
        XCTAssertFalse(accepted)
        executor.drain()
        XCTAssertTrue(received.isEmpty)
        XCTAssertFalse(feature.hasActiveSession)
    }

    func testStartLinkedEditingDropsWhenTicketIsStale() {
        let feature = MonaLinkedEditingFeature()
        let model = makeModel("let x = x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestLinkedEditingProvider(ranges: linkedRanges())
        let tokenSource = MonaCancellationTokenSource()
        let ticket = gate.captureTicket()
        // Invalidate the ticket before publication (cancellation bumped).
        gate.cancel()

        var received: [MonaLinkedEditingRanges] = []
        _ = feature.startLinkedEditing(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: ticket,
            token: tokenSource.token
        ) { ranges in
            if let r = ranges { received.append(r) }
        }
        executor.drain()
        // Stale ticket: receive never invoked, no session retained.
        XCTAssertTrue(received.isEmpty)
        XCTAssertFalse(feature.hasActiveSession)
    }

    func testStopLinkedEditingClearsActiveSession() {
        let feature = MonaLinkedEditingFeature()
        let model = makeModel("let x = x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let provider = TestLinkedEditingProvider(ranges: linkedRanges())
        let tokenSource = MonaCancellationTokenSource()

        _ = feature.startLinkedEditing(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { _ in }
        executor.drain()
        XCTAssertTrue(feature.hasActiveSession)

        feature.stopLinkedEditing()
        XCTAssertFalse(feature.hasActiveSession)
    }

    func testMirrorEditIsNoOpAfterDisposal() {
        let feature = MonaLinkedEditingFeature()
        let model = makeModel("let x = x")
        let gateway = MonaTransactionGateway(model: model)
        feature.dispose()

        let outcome = feature.mirrorEdit(text: "count", gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "let x = x")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaLinkedEditingFeature.featureId, "linkedEditing")
        XCTAssertTrue(features.contains("linkedEditing"))

        let actionIds = MonaLinkedEditingFeature.declaredActionIds
        XCTAssertEqual(actionIds, ["editor.action.linkedEditing"])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaLinkedEditingFeature.declaredCommandIds, ["editor.action.linkedEditing"])
        XCTAssertEqual(MonaLinkedEditingFeature.declaredContributionIds, ["editor.contrib.linkedEditing"])
        for id in MonaLinkedEditingFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaLinkedEditingFeature.declaredKeybindingCommands, ["editor.action.linkedEditing"])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaLinkedEditingFeature.declaredKeybindingCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(
            MonaLinkedEditingFeature.declaredOptionIds,
            ["linkedEditing", "renameOnType"]
        )
        for id in MonaLinkedEditingFeature.declaredOptionIds {
            XCTAssertNotNil(MonaBuiltinOptions.option(named: id), "missing option \(id)")
        }

        XCTAssertTrue(MonaLinkedEditingFeature.declaredMenuIds.isEmpty)
        _ = menus
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("let x = x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaLinkedEditingFeature()
        let provider = TestLinkedEditingProvider(ranges: linkedRanges())
        let tokenSource = MonaCancellationTokenSource()

        var received: [MonaLinkedEditingRanges] = []
        _ = feature.startLinkedEditing(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { ranges in
            if let r = ranges { received.append(r) }
        }
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaLinkedEditingFeature()
        var fired: [MonaLinkedEditingEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
        XCTAssertFalse(feature.hasActiveSession)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaLinkedEditingFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaLinkedEditingFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Start Linked Editing")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaLinkedEditingFeature()
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
        let feature = MonaLinkedEditingFeature()

        let featureLive = features.contains(MonaLinkedEditingFeature.featureId)
        let actionCount = MonaLinkedEditingFeature.declaredActionIds.count
        let commandCount = MonaLinkedEditingFeature.declaredCommandIds.count
        let contribCount = MonaLinkedEditingFeature.declaredContributionIds.count
        let kbCount = MonaLinkedEditingFeature.declaredKeybindingCommands.count
        let optionCount = MonaLinkedEditingFeature.declaredOptionIds.count
        let menuCount = MonaLinkedEditingFeature.declaredMenuIds.count

        let slicePass = MonaLinkedEditingFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaLinkedEditingFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaLinkedEditingFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaLinkedEditingFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaLinkedEditingFeature.declaredOptionIds.allSatisfy {
                MonaBuiltinOptions.option(named: $0) != nil
            }

        // Mutation: start linked editing and mirror an edit across the linked
        // ranges through the transaction gateway.
        let model = makeModel("let x = x")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let gateway = MonaTransactionGateway(model: model)
        let provider = TestLinkedEditingProvider(ranges: linkedRanges())
        let tokenSource = MonaCancellationTokenSource()
        _ = feature.startLinkedEditing(
            at: MonaPosition(line: 1, column: 5),
            provider: provider,
            model: model,
            executor: executor,
            ticket: gate.captureTicket(),
            token: tokenSource.token
        ) { _ in }
        executor.drain()
        let mirrorOutcome = feature.mirrorEdit(text: "count", gateway: gateway)
        let mutation: Bool
        if case .applied = mirrorOutcome, model.getValue() == "let count = count" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        var delivered = false
        let model2 = makeModel("let x = x")
        let gate2 = MonaPublicationGate(model: model2)
        let queue2 = MonaMicrotaskQueue()
        let executor2 = MonaProviderExecutor(gate: gate2, queue: queue2)
        let provider2 = TestLinkedEditingProvider(ranges: linkedRanges())
        let tokenSource2 = MonaCancellationTokenSource()
        let feature2 = MonaLinkedEditingFeature()
        _ = feature2.startLinkedEditing(
            at: MonaPosition(line: 1, column: 5),
            provider: provider2,
            model: model2,
            executor: executor2,
            ticket: gate2.captureTicket(),
            token: tokenSource2.token
        ) { _ in delivered = true }
        executor2.drain()
        let asyncPass = delivered && queue2.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed && !feature.hasActiveSession

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("LINKEDEDITING feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
