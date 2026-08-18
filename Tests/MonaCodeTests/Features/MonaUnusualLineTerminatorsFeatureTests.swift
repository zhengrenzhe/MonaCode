// MonaUnusualLineTerminatorsFeatureTests.swift
//
// P05-T158 — Implement retained feature unusualLineTerminators.
//
// Verifies the unusualLineTerminators feature across its three implementation
// operations:
//   1. Feature-specific behavior: detect and explicitly remove unusual line
//      terminators transactionally (LS / PS / NEL etc. → normalize to LF;
//      edits via `MonaTransactionGateway`).
//   2. The exact feature identity `unusualLineTerminators` + its declared
//      commands, actions, contributions, options, menus, and keybindings
//      (referenced verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     UNUSUALLINETERMINATORS feature=live actions=0 commands=0 contributions=1 keybindings=0 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaUnusualLineTerminatorsFeatureTests: XCTestCase {

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/unusual-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: detect + remove unusual terminators

    func testDetectsLineSeparator() {
        let feature = MonaUnusualLineTerminatorsFeature()
        // U+2028 LINE SEPARATOR.
        let model = makeModel("a\u{2028}b")
        let spans = feature.detectUnusualLineTerminators(in: model)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].codePoint, 0x2028)
        XCTAssertEqual(spans[0].range, MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 3))
    }

    func testDetectsParagraphSeparator() {
        let feature = MonaUnusualLineTerminatorsFeature()
        // U+2029 PARAGRAPH SEPARATOR.
        let model = makeModel("x\u{2029}y")
        let spans = feature.detectUnusualLineTerminators(in: model)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].codePoint, 0x2029)
    }

    func testDetectsNextLine() {
        let feature = MonaUnusualLineTerminatorsFeature()
        // U+0085 NEXT LINE.
        let model = makeModel("p\u{0085}q")
        let spans = feature.detectUnusualLineTerminators(in: model)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].codePoint, 0x0085)
    }

    func testDoesNotDetectNormalLineFeed() {
        let feature = MonaUnusualLineTerminatorsFeature()
        let model = makeModel("a\nb\nc")
        let spans = feature.detectUnusualLineTerminators(in: model)
        XCTAssertTrue(spans.isEmpty)
    }

    func testDetectsMultipleUnusualTerminators() {
        let feature = MonaUnusualLineTerminatorsFeature()
        let model = makeModel("a\u{2028}b\u{2029}c\u{0085}d")
        let spans = feature.detectUnusualLineTerminators(in: model)
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(spans[0].codePoint, 0x2028)
        XCTAssertEqual(spans[1].codePoint, 0x2029)
        XCTAssertEqual(spans[2].codePoint, 0x0085)
    }

    func testRemoveUnusualLineTerminatorsNormalizesToLF() {
        let feature = MonaUnusualLineTerminatorsFeature()
        let model = makeModel("a\u{2028}b\u{2029}c")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.removeUnusualLineTerminators(in: model, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nc")
            XCTAssertEqual(model.getLineCount(), 3)
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testRemoveWithNoUnusualTerminatorsIsAppliedNoOp() {
        let feature = MonaUnusualLineTerminatorsFeature()
        let model = makeModel("a\nb\nc")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.removeUnusualLineTerminators(in: model, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "a\nb\nc")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testDetectionIsNoOpAfterDisposal() {
        let feature = MonaUnusualLineTerminatorsFeature()
        feature.dispose()
        let model = makeModel("a\u{2028}b")
        let spans = feature.detectUnusualLineTerminators(in: model)
        XCTAssertTrue(spans.isEmpty)
    }

    func testRemovalIsNoOpAfterDisposal() {
        let feature = MonaUnusualLineTerminatorsFeature()
        feature.dispose()
        let model = makeModel("a\u{2028}b")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.removeUnusualLineTerminators(in: model, gateway: gateway)
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "a\u{2028}b")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
    }

    func testModeOffSuppressesDetection() {
        let feature = MonaUnusualLineTerminatorsFeature()
        let model = makeModel("a\u{2028}b")
        let spans = feature.detectUnusualLineTerminators(in: model, mode: .off)
        XCTAssertTrue(spans.isEmpty)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaUnusualLineTerminatorsFeature.featureId, "unusualLineTerminators")
        XCTAssertTrue(features.contains("unusualLineTerminators"))

        XCTAssertTrue(MonaUnusualLineTerminatorsFeature.declaredActionIds.isEmpty)
        XCTAssertTrue(MonaUnusualLineTerminatorsFeature.declaredCommandIds.isEmpty)

        XCTAssertEqual(
            MonaUnusualLineTerminatorsFeature.declaredContributionIds,
            ["editor.contrib.unusualLineTerminatorsDetector"]
        )
        for id in MonaUnusualLineTerminatorsFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertTrue(MonaUnusualLineTerminatorsFeature.declaredKeybindingCommands.isEmpty)

        XCTAssertEqual(
            MonaUnusualLineTerminatorsFeature.declaredOptionIds,
            ["unusualLineTerminators"]
        )
        for id in MonaUnusualLineTerminatorsFeature.declaredOptionIds {
            XCTAssertNotNil(MonaBuiltinOptions.option(named: id), "missing option \(id)")
        }

        XCTAssertTrue(MonaUnusualLineTerminatorsFeature.declaredMenuIds.isEmpty)
        _ = menus
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("a\u{2028}b")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaUnusualLineTerminatorsFeature()
        let spans = feature.detectUnusualLineTerminators(in: model)

        var received: [MonaUnusualLineTerminatorSpan] = []
        let accepted = feature.publishDetections(
            spans,
            executor: executor,
            ticket: gate.captureTicket()
        ) { published in
            received = published
        }
        XCTAssertTrue(accepted)
        XCTAssertEqual(received.count, 0)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0].codePoint, 0x2028)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testPublishDetectionsDropsWhenTicketIsStale() {
        let model = makeModel("a\u{2028}b")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaUnusualLineTerminatorsFeature()
        let spans = feature.detectUnusualLineTerminators(in: model)
        let ticket = gate.captureTicket()
        gate.cancel()

        var received: [MonaUnusualLineTerminatorSpan] = []
        _ = feature.publishDetections(spans, executor: executor, ticket: ticket) { published in
            received = published
        }
        executor.drain()
        XCTAssertTrue(received.isEmpty)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaUnusualLineTerminatorsFeature()
        var fired: [MonaUnusualLineTerminatorsEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaUnusualLineTerminatorsFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaUnusualLineTerminatorsFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testContractBehavior() {
        let features = MonaFeatureRegistry()
        let contributions = MonaContributionRegistry()
        let feature = MonaUnusualLineTerminatorsFeature()

        let featureLive = features.contains(MonaUnusualLineTerminatorsFeature.featureId)
        let actionCount = MonaUnusualLineTerminatorsFeature.declaredActionIds.count
        let commandCount = MonaUnusualLineTerminatorsFeature.declaredCommandIds.count
        let contribCount = MonaUnusualLineTerminatorsFeature.declaredContributionIds.count
        let kbCount = MonaUnusualLineTerminatorsFeature.declaredKeybindingCommands.count
        let optionCount = MonaUnusualLineTerminatorsFeature.declaredOptionIds.count
        let menuCount = MonaUnusualLineTerminatorsFeature.declaredMenuIds.count

        let slicePass = MonaUnusualLineTerminatorsFeature.declaredContributionIds.allSatisfy {
            contributions.contains($0)
        } && MonaUnusualLineTerminatorsFeature.declaredOptionIds.allSatisfy {
            MonaBuiltinOptions.option(named: $0) != nil
        }

        // Mutation: remove unusual line terminators transactionally through the
        // gateway.
        let model = makeModel("a\u{2028}b\u{2029}c")
        let gateway = MonaTransactionGateway(model: model)
        let removeOutcome = feature.removeUnusualLineTerminators(in: model, gateway: gateway)
        let mutation: Bool
        if case .applied = removeOutcome, model.getValue() == "a\nb\nc" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication (fresh model so the detection carries real spans).
        let asyncModel = makeModel("a\u{2028}b\u{2029}c")
        let gate = MonaPublicationGate(model: asyncModel)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let spans = feature.detectUnusualLineTerminators(in: asyncModel)
        var delivered = false
        _ = feature.publishDetections(spans, executor: executor, ticket: gate.captureTicket()) { _ in
            delivered = true
        }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded
            && feature.degradedLanguage.id == MonaPlainTextLanguage.languageId

        print("UNUSUALLINETERMINATORS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
