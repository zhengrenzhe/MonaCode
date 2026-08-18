// MonaInlayHintsFeatureTests.swift
//
// P05-T127 — Implement retained feature inlayHints.
//
// Verifies the inlayHints feature across its three implementation operations:
//   1. Feature-specific behavior: request, resolve, lay out, and release
//      version-gated inlay hints (reuse `MonaProviderExecutor` P05-T013;
//      version-gated like T115/T106).
//   2. The exact feature identity `inlayHints` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     INLAYHINTS feature=live actions=0 commands=1 contributions=1 keybindings=0 options=1 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaInlayHintsFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1\nlet y = 2") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/inlayhints-\(UUID().uuidString)")
        )
    }

    private func sampleHints() -> [MonaInlayHint] {
        return [
            MonaInlayHint(
                position: MonaPosition(line: 1, column: 5),
                label: ": int",
                tooltip: "inferred type int",
                edits: [
                    MonaInlayHintEdit(
                        range: MonaRange(
                            startPosition: MonaPosition(line: 1, column: 5),
                            endPosition: MonaPosition(line: 1, column: 5)
                        ),
                        text: ": int"
                    )
                ]
            ),
            MonaInlayHint(
                position: MonaPosition(line: 2, column: 5),
                label: ": int",
                tooltip: nil,
                edits: []
            )
        ]
    }

    // MARK: - 1. Feature-specific behavior: request / resolve / lay out / release by model version

    func testRequestInlayHintsRetainsResultsByModelVersion() {
        let feature = MonaInlayHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()

        let requested = feature.requestInlayHints(sampleHints(), modelVersion: version)

        XCTAssertEqual(requested.count, 2)
        XCTAssertEqual(requested.map { $0.label }, [": int", ": int"])
        XCTAssertEqual(feature.retainedHintCount(for: version), 2)
    }

    func testRequestInlayHintsForNewModelVersionIsIndependent() {
        let feature = MonaInlayHintsFeature()
        let model = makeModel()

        let v1 = model.getVersionId()
        _ = feature.requestInlayHints(sampleHints(), modelVersion: v1)
        // The model advances (a direct mutation bypassing the feature).
        model.setValue("let x = 2\nlet y = 3")
        let v2 = model.getVersionId()

        XCTAssertNotEqual(v1, v2)
        XCTAssertEqual(feature.retainedHintCount(for: v1), 2)
        XCTAssertEqual(feature.retainedHintCount(for: v2), 0)

        _ = feature.requestInlayHints(Array(sampleHints().prefix(1)), modelVersion: v2)
        XCTAssertEqual(feature.retainedHintCount(for: v2), 1)
        XCTAssertEqual(feature.retainedHintCount(for: v1), 2)
    }

    func testResolveInlayHintReturnsHintWithPayloadIntact() {
        let feature = MonaInlayHintsFeature()
        let original = sampleHints()[0]
        let resolved = feature.resolveInlayHint(original)
        XCTAssertEqual(resolved.position, original.position)
        XCTAssertEqual(resolved.label, original.label)
        XCTAssertEqual(resolved.tooltip, original.tooltip)
        XCTAssertEqual(resolved.edits, original.edits)
    }

    func testLayoutInlayHintsProducesPositionLabelLayouts() {
        let feature = MonaInlayHintsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.requestInlayHints(sampleHints(), modelVersion: version)

        let layouts = feature.layoutInlayHints(modelVersion: version)
        XCTAssertEqual(layouts.count, 2)
        XCTAssertEqual(layouts[0].position, MonaPosition(line: 1, column: 5))
        XCTAssertEqual(layouts[0].label, ": int")
        XCTAssertEqual(layouts[1].position, MonaPosition(line: 2, column: 5))
        XCTAssertEqual(layouts[1].label, ": int")
    }

    func testLayoutInlayHintsForUnknownVersionIsEmpty() {
        let feature = MonaInlayHintsFeature()
        let model = makeModel()
        let v1 = model.getVersionId()
        _ = feature.requestInlayHints(sampleHints(), modelVersion: v1)

        let layouts = feature.layoutInlayHints(modelVersion: v1 + 999)
        XCTAssertTrue(layouts.isEmpty)
    }

    func testReleaseInlayHintsDropsResultsForStaleModelVersion() {
        let feature = MonaInlayHintsFeature()
        let model = makeModel()

        let v1 = model.getVersionId()
        _ = feature.requestInlayHints(sampleHints(), modelVersion: v1)
        XCTAssertEqual(feature.retainedHintCount(for: v1), 2)

        let released = feature.releaseInlayHints(modelVersion: v1)
        XCTAssertEqual(released, 2)
        XCTAssertEqual(feature.retainedHintCount(for: v1), 0)
    }

    func testReleaseInlayHintsForUnknownVersionReleasesNothing() {
        let feature = MonaInlayHintsFeature()
        let model = makeModel()
        let v1 = model.getVersionId()
        _ = feature.requestInlayHints(sampleHints(), modelVersion: v1)
        let released = feature.releaseInlayHints(modelVersion: v1 + 999)
        XCTAssertEqual(released, 0)
        XCTAssertEqual(feature.retainedHintCount(for: v1), 2)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()

        XCTAssertEqual(MonaInlayHintsFeature.featureId, "inlayHints")
        XCTAssertTrue(features.contains("inlayHints"))

        // inlayHints declares no labeled actions.
        XCTAssertEqual(MonaInlayHintsFeature.declaredActionIds, [])
        for id in MonaInlayHintsFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaInlayHintsFeature.declaredCommandIds, [
            "_executeInlayHintProvider"
        ])
        for id in MonaInlayHintsFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaInlayHintsFeature.declaredContributionIds, ["editor.contrib.InlayHints"])
        for id in MonaInlayHintsFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaInlayHintsFeature.declaredKeybindingCommands, [])

        XCTAssertEqual(MonaInlayHintsFeature.declaredOptionIds, [
            "inlayHints"
        ])

        XCTAssertEqual(MonaInlayHintsFeature.declaredMenuIds, [])
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaInlayHintsFeature()
        let model = makeModel("let x 1")
        let gateway = MonaTransactionGateway(model: model)
        // "let x 1" → "let x: int 1": insert ": int" after 'x' (column 6,
        // the gap before the space at column 6). The hint renders at column 6.
        let hint = MonaInlayHint(
            position: MonaPosition(line: 1, column: 6),
            label: ": int",
            tooltip: nil,
            edits: [
                MonaInlayHintEdit(
                    range: MonaRange(
                        startPosition: MonaPosition(line: 1, column: 6),
                        endPosition: MonaPosition(line: 1, column: 6)
                    ),
                    text: ": int"
                )
            ]
        )
        let outcome = feature.commitInlayHintEdits(hint, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "let x: int 1")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testMutationWithNoEditsCommitsEmptyTransaction() {
        let feature = MonaInlayHintsFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let hint = MonaInlayHint(
            position: MonaPosition(line: 1, column: 1),
            label: ": T",
            tooltip: nil,
            edits: []
        )
        let outcome = feature.commitInlayHintEdits(hint, gateway: gateway)
        switch outcome {
        case .applied, .reconciled:
            XCTAssertEqual(model.getValue(), "hello")
        default:
            XCTFail("expected applied/reconciled, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaInlayHintsFeature()
        let ticket = gate.captureTicket()

        var received: [MonaInlayHint] = []
        let accepted = feature.publishInlayHints(
            sampleHints(),
            executor: executor,
            ticket: ticket
        ) { hints in
            received = hints
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaInlayHintsFeature()
        var fired: [MonaInlayHintsEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, request / resolve / layout / release are no-ops.
        let model = makeModel()
        let version = model.getVersionId()
        let requested = feature.requestInlayHints(sampleHints(), modelVersion: version)
        XCTAssertTrue(requested.isEmpty)
        XCTAssertEqual(feature.retainedHintCount(for: version), 0)
        let layouts = feature.layoutInlayHints(modelVersion: version)
        XCTAssertTrue(layouts.isEmpty)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaInlayHintsFeature()
        // inlayHints declares no actions, so localized labels are empty under
        // every profile — but the path still routes through MonaLocalization.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaInlayHintsFeature.declaredActionIds.count)
        XCTAssertTrue(enLabels.isEmpty)
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.isEmpty)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaInlayHintsFeature()
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
        let feature = MonaInlayHintsFeature()

        let featureLive = features.contains(MonaInlayHintsFeature.featureId)
        let actionCount = MonaInlayHintsFeature.declaredActionIds.count
        let commandCount = MonaInlayHintsFeature.declaredCommandIds.count
        let contribCount = MonaInlayHintsFeature.declaredContributionIds.count
        let kbCount = MonaInlayHintsFeature.declaredKeybindingCommands.count
        let optionCount = MonaInlayHintsFeature.declaredOptionIds.count
        let menuCount = MonaInlayHintsFeature.declaredMenuIds.count

        let slicePass = MonaInlayHintsFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaInlayHintsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaInlayHintsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaInlayHintsFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaInlayHintsFeature.declaredMenuIds.allSatisfy { _ in true }

        // Request + layout: request hints for a version, then lay them out.
        let model = makeModel("let x 1")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        let requested = feature.requestInlayHints(sampleHints(), modelVersion: version)
        let layouts = feature.layoutInlayHints(modelVersion: version)
        let requestLayoutPass = requested.count == 2 && layouts.count == 2

        // Resolve: a hint resolves with its payload intact.
        let resolved = feature.resolveInlayHint(requested[0])
        let resolvePass = resolved.label == ": int" && resolved.edits.count == 1

        // Mutation: commit a hint's edits through the transaction gateway.
        // Insert ": int" after 'x' (column 6) → "let x: int 1".
        let mutationHint = MonaInlayHint(
            position: MonaPosition(line: 1, column: 6),
            label: ": int",
            tooltip: nil,
            edits: [
                MonaInlayHintEdit(
                    range: MonaRange(
                        startPosition: MonaPosition(line: 1, column: 6),
                        endPosition: MonaPosition(line: 1, column: 6)
                    ),
                    text: ": int"
                )
            ]
        )
        let mutation: Bool
        let outcome = feature.commitInlayHintEdits(mutationHint, gateway: gateway)
        if case .applied = outcome, model.getValue() == "let x: int 1" {
            mutation = true
        } else {
            mutation = false
        }

        // Release the stale-model-version hints.
        let released = feature.releaseInlayHints(modelVersion: version)
        let releasePass = (released == 2 && feature.retainedHintCount(for: version) == 0)

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishInlayHints([], executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("INLAYHINTS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(requestLayoutPass)
        XCTAssertTrue(resolvePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
