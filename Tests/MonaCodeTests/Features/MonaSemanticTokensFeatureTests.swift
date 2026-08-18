// MonaSemanticTokensFeatureTests.swift
//
// P05-T149 — Implement retained feature semanticTokens.
//
// Verifies the semanticTokens feature across its three implementation operations:
//   1. Feature-specific behavior: apply full and delta semantic-token results
//      by version and result identifier (version-gated; delta application
//      requires the delta's previous resultId to match the retained resultId).
//      Reuses `MonaProviderExecutor` (P05-T013) for async publication.
//   2. The exact feature identity `semanticTokens` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     SEMANTICTOKENS feature=live actions=0 commands=4 contributions=1 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaSemanticTokensFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/semantictokens-\(UUID().uuidString)")
        )
    }

    private func sampleFull(resultId: String = "r1", data: [Int] = [0, 1, 4, 0, 2]) -> MonaSemanticTokensData {
        return MonaSemanticTokensData(data: data, resultId: resultId)
    }

    // MARK: - 1. Feature-specific behavior: apply full / delta by version + resultId

    func testApplyFullRetainsTokensAndResultId() {
        let feature = MonaSemanticTokensFeature()
        let full = sampleFull()

        let applied = feature.applyFull(full, version: 5)
        XCTAssertTrue(applied)
        XCTAssertEqual(feature.currentVersion, 5)
        XCTAssertEqual(feature.currentResultId, "r1")
        XCTAssertEqual(feature.currentTokens?.data, full.data)
    }

    func testApplyFullDropsStaleVersion() {
        let feature = MonaSemanticTokensFeature()
        _ = feature.applyFull(sampleFull(), version: 5)

        // A response for an older version is dropped.
        let older = MonaSemanticTokensData(data: [9, 9, 9], resultId: "r2")
        let applied = feature.applyFull(older, version: 4)
        XCTAssertFalse(applied)
        XCTAssertEqual(feature.currentVersion, 5)
        XCTAssertEqual(feature.currentResultId, "r1")
        XCTAssertEqual(feature.currentTokens?.data, sampleFull().data)
    }

    func testApplyFullAcceptsEqualOrNewerVersion() {
        let feature = MonaSemanticTokensFeature()
        _ = feature.applyFull(sampleFull(), version: 5)

        // Equal version (re-issue) is accepted.
        let same = MonaSemanticTokensData(data: [1, 2, 3], resultId: "r1b")
        XCTAssertTrue(feature.applyFull(same, version: 5))
        XCTAssertEqual(feature.currentResultId, "r1b")

        // Newer version is accepted.
        let newer = MonaSemanticTokensData(data: [4, 5, 6], resultId: "r2")
        XCTAssertTrue(feature.applyFull(newer, version: 6))
        XCTAssertEqual(feature.currentVersion, 6)
        XCTAssertEqual(feature.currentResultId, "r2")
    }

    func testApplyFullIsNoOpAfterDispose() {
        let feature = MonaSemanticTokensFeature()
        feature.dispose()
        let applied = feature.applyFull(sampleFull(), version: 1)
        XCTAssertFalse(applied)
        XCTAssertNil(feature.currentTokens)
        XCTAssertEqual(feature.currentVersion, 0)
    }

    func testApplyDeltaRequiresMatchingPreviousResultId() {
        let feature = MonaSemanticTokensFeature()
        _ = feature.applyFull(sampleFull(resultId: "r1"), version: 5)

        // A delta whose previousResultId matches is applied.
        let delta = MonaSemanticTokensDelta(
            resultId: "r2",
            previousResultId: "r1",
            edits: [MonaSemanticTokensEdit(start: 0, deleteCount: 0, data: [7, 8])]
        )
        let applied = feature.applyDelta(delta, version: 5)
        XCTAssertTrue(applied)
        XCTAssertEqual(feature.currentResultId, "r2")
        XCTAssertEqual(feature.currentVersion, 5)
        // The edit prepended [7,8] to the data.
        XCTAssertEqual(feature.currentTokens?.data, [7, 8, 0, 1, 4, 0, 2])
    }

    func testApplyDeltaDropsWhenPreviousResultIdMismatched() {
        let feature = MonaSemanticTokensFeature()
        _ = feature.applyFull(sampleFull(resultId: "r1"), version: 5)

        let delta = MonaSemanticTokensDelta(
            resultId: "r2",
            previousResultId: "wrong",
            edits: [MonaSemanticTokensEdit(start: 0, deleteCount: 0, data: [7, 8])]
        )
        let applied = feature.applyDelta(delta, version: 5)
        XCTAssertFalse(applied)
        XCTAssertEqual(feature.currentResultId, "r1")
        XCTAssertEqual(feature.currentTokens?.data, sampleFull().data)
    }

    func testApplyDeltaDropsWhenNoPriorFullResult() {
        let feature = MonaSemanticTokensFeature()
        // No applyFull first — there is no retained resultId to delta from.
        let delta = MonaSemanticTokensDelta(
            resultId: "r1",
            previousResultId: "r0",
            edits: [MonaSemanticTokensEdit(start: 0, deleteCount: 0, data: [1])]
        )
        let applied = feature.applyDelta(delta, version: 1)
        XCTAssertFalse(applied)
        XCTAssertNil(feature.currentTokens)
    }

    func testApplyDeltaDropsStaleVersion() {
        let feature = MonaSemanticTokensFeature()
        _ = feature.applyFull(sampleFull(resultId: "r1"), version: 5)

        let delta = MonaSemanticTokensDelta(
            resultId: "r2",
            previousResultId: "r1",
            edits: [MonaSemanticTokensEdit(start: 0, deleteCount: 5, data: [9])]
        )
        let applied = feature.applyDelta(delta, version: 4) // stale
        XCTAssertFalse(applied)
        XCTAssertEqual(feature.currentResultId, "r1")
        XCTAssertEqual(feature.currentVersion, 5)
    }

    func testApplyDeltaEditsDeleteAndInsert() {
        let feature = MonaSemanticTokensFeature()
        _ = feature.applyFull(sampleFull(resultId: "r1", data: [10, 20, 30]), version: 1)

        // Delete 1 element at start, insert [99].
        let delta = MonaSemanticTokensDelta(
            resultId: "r2",
            previousResultId: "r1",
            edits: [MonaSemanticTokensEdit(start: 0, deleteCount: 1, data: [99])]
        )
        XCTAssertTrue(feature.applyDelta(delta, version: 2))
        XCTAssertEqual(feature.currentTokens?.data, [99, 20, 30])
        XCTAssertEqual(feature.currentVersion, 2)
    }

    func testApplyFullFiresEvent() {
        let feature = MonaSemanticTokensFeature()
        var fired: [MonaSemanticTokensEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        _ = feature.applyFull(sampleFull(), version: 1)
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired[0].result?.resultId, "r1")
    }

    func testResetClearsRetainedState() {
        let feature = MonaSemanticTokensFeature()
        _ = feature.applyFull(sampleFull(), version: 3)
        XCTAssertNotNil(feature.currentTokens)

        feature.reset()
        XCTAssertNil(feature.currentTokens)
        XCTAssertNil(feature.currentResultId)
        XCTAssertEqual(feature.currentVersion, 0)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaSemanticTokensFeature.featureId, "semanticTokens")
        XCTAssertTrue(features.contains("semanticTokens"))

        XCTAssertEqual(MonaSemanticTokensFeature.declaredActionIds, [])
        for id in MonaSemanticTokensFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSemanticTokensFeature.declaredCommandIds, [
            "_provideDocumentSemanticTokens",
            "_provideDocumentSemanticTokensLegend",
            "_provideDocumentRangeSemanticTokens",
            "_provideDocumentRangeSemanticTokensLegend"
        ])
        for id in MonaSemanticTokensFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSemanticTokensFeature.declaredContributionIds, [
            "editor.contrib.viewportSemanticTokens"
        ])
        for id in MonaSemanticTokensFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaSemanticTokensFeature.declaredKeybindingCommands, [])
        let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaSemanticTokensFeature.declaredKeybindingCommands {
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaSemanticTokensFeature.declaredOptionIds, [])
        for id in MonaSemanticTokensFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaSemanticTokensFeature.declaredMenuIds, [])
        for id in MonaSemanticTokensFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesRetainedTokensThroughTransactionGateway() {
        let feature = MonaSemanticTokensFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        _ = feature.applyFull(sampleFull(), version: model.getVersionId())

        let outcome = feature.commitRetainedTokens(version: model.getVersionId(), gateway: gateway)
        if case .applied = outcome {
            // expected: the retained tokens are acknowledged through the gateway.
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testMutationDroppedForStaleVersion() {
        let feature = MonaSemanticTokensFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        _ = feature.applyFull(sampleFull(), version: 10)

        let outcome = feature.commitRetainedTokens(version: 1, gateway: gateway)
        if case .dropped = outcome {
            // expected: stale version is dropped.
        } else {
            XCTFail("expected dropped, got \(outcome)")
        }
    }

    func testMutationIsNoOpAfterDispose() {
        let feature = MonaSemanticTokensFeature()
        feature.dispose()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitRetainedTokens(version: 1, gateway: gateway)
        if case .dropped = outcome {
            // expected
        } else {
            XCTFail("expected dropped, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaSemanticTokensFeature()
        let ticket = gate.captureTicket()
        _ = feature.applyFull(sampleFull(), version: 1)

        var received: MonaSemanticTokensData?
        let accepted = feature.publishSemanticTokens(
            feature.currentTokens ?? sampleFull(),
            executor: executor,
            ticket: ticket
        ) { data in
            received = data
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.data, sampleFull().data)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaSemanticTokensFeature()
        var fired: [MonaSemanticTokensEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.applyFull(sampleFull(), version: 1)
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, apply is a no-op and fires no events.
        let countBefore = fired.count
        _ = feature.applyFull(sampleFull(), version: 2)
        XCTAssertEqual(fired.count, countBefore)
        XCTAssertNil(feature.currentTokens)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaSemanticTokensFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaSemanticTokensFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)

        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaSemanticTokensFeature()
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
        let feature = MonaSemanticTokensFeature()
        let model = makeModel()

        let featureLive = features.contains(MonaSemanticTokensFeature.featureId)
        let actionCount = MonaSemanticTokensFeature.declaredActionIds.count
        let commandCount = MonaSemanticTokensFeature.declaredCommandIds.count
        let contribCount = MonaSemanticTokensFeature.declaredContributionIds.count
        let kbCount = MonaSemanticTokensFeature.declaredKeybindingCommands.count
        let optionCount = MonaSemanticTokensFeature.declaredOptionIds.count
        let menuCount = MonaSemanticTokensFeature.declaredMenuIds.count

        let slicePass = MonaSemanticTokensFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaSemanticTokensFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaSemanticTokensFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaSemanticTokensFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaSemanticTokensFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaSemanticTokensFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Full application is version-gated.
        let full = sampleFull(resultId: "r1", data: [0, 1, 2, 3])
        let fullApplied = feature.applyFull(full, version: 1)
        let fullPass = fullApplied && feature.currentVersion == 1 && feature.currentResultId == "r1"

        // Stale version is dropped.
        let stale = MonaSemanticTokensData(data: [9], resultId: "r0")
        let staleDropped = !feature.applyFull(stale, version: 0)

        // Delta application requires matching previousResultId + version gate.
        let goodDelta = MonaSemanticTokensDelta(
            resultId: "r2",
            previousResultId: "r1",
            edits: [MonaSemanticTokensEdit(start: 0, deleteCount: 0, data: [7, 8])]
        )
        let deltaApplied = feature.applyDelta(goodDelta, version: 2)
        let deltaPass = deltaApplied && feature.currentResultId == "r2"
            && feature.currentTokens?.data == [7, 8, 0, 1, 2, 3]

        // Mismatched previousResultId is dropped.
        let badDelta = MonaSemanticTokensDelta(
            resultId: "r3",
            previousResultId: "wrong",
            edits: [MonaSemanticTokensEdit(start: 0, deleteCount: 1, data: [9])]
        )
        let badDeltaDropped = !feature.applyDelta(badDelta, version: 3)

        // Mutation: acknowledge retained tokens through the gateway (version-gated).
        var mutation = false
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.commitRetainedTokens(version: 2, gateway: gateway)
        if case .applied = outcome {
            mutation = true
        }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishSemanticTokens(
            feature.currentTokens ?? sampleFull(),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.reset()
        let resetPass = feature.currentTokens == nil && feature.currentVersion == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("SEMANTICTOKENS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(fullPass)
        XCTAssertTrue(staleDropped)
        XCTAssertTrue(deltaPass)
        XCTAssertTrue(badDeltaDropped)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(resetPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
