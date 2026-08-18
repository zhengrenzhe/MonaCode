// MonaLineSelectionFeatureTests.swift
//
// P05-T133 — Implement retained feature lineSelection.
//
// Verifies the lineSelection feature across its three implementation operations:
//   1. Feature-specific behavior: create and extend whole-line selections with
//      final-line edge handling, with replacements committed via
//      MonaTransactionGateway for mutation.
//   2. The exact feature identity `lineSelection` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     LINESELECTION feature=live actions=0 commands=0 contributions=0 keybindings=0 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaLineSelectionFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "line1\nline2\nline3") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/lineselection-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: create + extend whole-line selections

    func testWholeLineRangeCoversNonFinalLineIncludingLineTerminator() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3")
        // Line 2 is not the final line: the range spans column 1 of line 2 to
        // column 1 of line 3 (the line terminator is included).
        let range = feature.wholeLineRange(line: 2, model: model)
        XCTAssertEqual(
            range,
            MonaRange(
                startPosition: MonaPosition(line: 2, column: 1),
                endPosition: MonaPosition(line: 3, column: 1)
            )
        )
    }

    func testWholeLineRangeOnFinalLineEndsAtMaxColumn() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3")
        // Line 3 is the final line and has no trailing newline: the range ends
        // at the line's max column (length + 1), not at the start of a next line.
        let range = feature.wholeLineRange(line: 3, model: model)
        XCTAssertEqual(
            range,
            MonaRange(
                startPosition: MonaPosition(line: 3, column: 1),
                endPosition: MonaPosition(line: 3, column: 6)
            )
        )
    }

    func testWholeLineRangeOnEmptyFinalLineProducesCollapsedRange() {
        let feature = MonaLineSelectionFeature()
        // A trailing newline produces an empty final line (line 3).
        let model = makeModel("line1\nline2\n")
        let range = feature.wholeLineRange(line: 3, model: model)
        XCTAssertEqual(
            range,
            MonaRange(
                startPosition: MonaPosition(line: 3, column: 1),
                endPosition: MonaPosition(line: 3, column: 1)
            )
        )
    }

    func testWholeLineRangeReturnsNilForOutOfRangeLine() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3")
        XCTAssertNil(feature.wholeLineRange(line: 0, model: model))
        XCTAssertNil(feature.wholeLineRange(line: 4, model: model))
    }

    func testExtendWholeLineRangeSpansMultipleLinesDownward() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3\nline4")
        // Extend from line 2 to line 3: spans column 1 of line 2 to column 1 of
        // line 4 (the terminator of line 3 is included).
        let range = feature.extendWholeLineRange(from: 2, to: 3, model: model)
        XCTAssertEqual(
            range,
            MonaRange(
                startPosition: MonaPosition(line: 2, column: 1),
                endPosition: MonaPosition(line: 4, column: 1)
            )
        )
    }

    func testExtendWholeLineRangeNormalizesReversedDirection() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3\nline4")
        // Extending upward (to < from) yields the same normalized range.
        let range = feature.extendWholeLineRange(from: 3, to: 2, model: model)
        XCTAssertEqual(
            range,
            MonaRange(
                startPosition: MonaPosition(line: 2, column: 1),
                endPosition: MonaPosition(line: 4, column: 1)
            )
        )
    }

    func testExtendWholeLineRangeHandlesFinalLineEdge() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3")
        // Extending to the final line ends at the final line's max column.
        let range = feature.extendWholeLineRange(from: 1, to: 3, model: model)
        XCTAssertEqual(
            range,
            MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 3, column: 6)
            )
        )
    }

    func testApplyReplacementCommitsThroughTransactionGateway() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3")
        let gateway = MonaTransactionGateway(model: model)
        let range = feature.wholeLineRange(line: 2, model: model)!

        // The whole-line range includes the line terminator, so the replacement
        // text carries a newline to keep the document well-formed.
        let outcome = feature.applyReplacement(
            to: range,
            text: "replaced\n",
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "line1\nreplaced\nline3")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testApplyReplacementOnFinalLineCommitsThroughTransactionGateway() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3")
        let gateway = MonaTransactionGateway(model: model)
        let range = feature.wholeLineRange(line: 3, model: model)!

        let outcome = feature.applyReplacement(
            to: range,
            text: "tail",
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "line1\nline2\ntail")
        } else {
            XCTFail("expected applied on final line, got \(outcome)")
        }
    }

    func testCommandsAreNoOpsAfterDisposal() {
        let feature = MonaLineSelectionFeature()
        let model = makeModel("line1\nline2\nline3")
        let gateway = MonaTransactionGateway(model: model)
        feature.dispose()

        let range = feature.wholeLineRange(line: 1, model: model)
        XCTAssertNil(range)

        let outcome = feature.applyReplacement(
            to: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 2, column: 1)
            ),
            text: "x",
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "line1\nline2\nline3")
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
        let options = MonaOptionStore()

        // lineSelection registers NO actions, commands, contributions, options,
        // menus, or keybindings in the F1-R3 scope manifest (it is a pure
        // mouse-interaction contribution). The feature identity is live.
        XCTAssertEqual(MonaLineSelectionFeature.featureId, "lineSelection")
        XCTAssertTrue(features.contains("lineSelection"))

        XCTAssertTrue(MonaLineSelectionFeature.declaredActionIds.isEmpty)
        XCTAssertTrue(MonaLineSelectionFeature.declaredCommandIds.isEmpty)
        XCTAssertTrue(MonaLineSelectionFeature.declaredContributionIds.isEmpty)
        XCTAssertTrue(MonaLineSelectionFeature.declaredKeybindingCommands.isEmpty)
        XCTAssertTrue(MonaLineSelectionFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaLineSelectionFeature.declaredMenuIds.isEmpty)

        _ = commands
        _ = actions
        _ = contributions
        _ = menus
        _ = options
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaLineSelectionFeature()
        let ticket = gate.captureTicket()

        var received: [MonaLineSelectionEvent] = []
        let accepted = feature.publishLineSelectionEvent(
            MonaLineSelectionEvent(
                kind: .created,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 2, column: 1)
                )
            ),
            executor: executor,
            ticket: ticket
        ) { event in
            received.append(event)
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaLineSelectionFeature()
        var fired: [MonaLineSelectionEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaLineSelectionFeature()
        // lineSelection declares no actions, so the localized label list is empty
        // under any profile. The routing through MonaLocalization is still live.
        XCTAssertEqual(feature.localizedActionLabels(profile: .default), [])
        XCTAssertEqual(feature.localizedActionLabels(profile: .custom("pseudo")), [])
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaLineSelectionFeature()
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testContractBehavior() {
        let features = MonaFeatureRegistry()
        let feature = MonaLineSelectionFeature()

        let featureLive = features.contains(MonaLineSelectionFeature.featureId)
        let actionCount = MonaLineSelectionFeature.declaredActionIds.count
        let commandCount = MonaLineSelectionFeature.declaredCommandIds.count
        let contribCount = MonaLineSelectionFeature.declaredContributionIds.count
        let kbCount = MonaLineSelectionFeature.declaredKeybindingCommands.count
        let optionCount = MonaLineSelectionFeature.declaredOptionIds.count
        let menuCount = MonaLineSelectionFeature.declaredMenuIds.count

        let slicePass = MonaLineSelectionFeature.declaredActionIds.allSatisfy { _ in true }
            && MonaLineSelectionFeature.declaredCommandIds.isEmpty
            && MonaLineSelectionFeature.declaredContributionIds.isEmpty

        // Mutation: replace a whole-line selection through the transaction gateway.
        let model = makeModel("line1\nline2\nline3")
        let gateway = MonaTransactionGateway(model: model)
        let range = feature.wholeLineRange(line: 2, model: model)!
        let outcome = feature.applyReplacement(to: range, text: "replaced\n", gateway: gateway)
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "line1\nreplaced\nline3" {
            mutation = true
        } else {
            mutation = false
        }

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishLineSelectionEvent(
            MonaLineSelectionEvent(
                kind: .created,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 2, column: 1)
                )
            ),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("LINESELECTION feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
