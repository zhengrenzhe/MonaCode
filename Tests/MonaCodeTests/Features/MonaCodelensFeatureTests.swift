// MonaCodelensFeatureTests.swift
//
// P05-T106 — Implement retained feature codelens.
//
// Verifies the codelens feature across its three implementation operations:
//   1. Feature-specific behavior: render, resolve, invoke, and release code-lens
//      results by model version (via MonaTransactionGateway for invocation).
//   2. The exact feature identity `codelens` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     CODELENS feature=live actions=1 commands=2 contributions=1 keybindings=0 options=3 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaCodelensFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1\nlet y = 2") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/codelens-\(UUID().uuidString)")
        )
    }

    private func sampleLenses() -> [MonaCodelens] {
        return [
            MonaCodelens(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 9)
                ),
                command: MonaCodelensCommand(
                    id: "codelens.showReferences",
                    title: "3 references",
                    edits: [
                        MonaCodelensEdit(
                            range: MonaRange(
                                startPosition: MonaPosition(line: 1, column: 5),
                                endPosition: MonaPosition(line: 1, column: 6)
                            ),
                            text: "z"
                        )
                    ]
                )
            ),
            MonaCodelens(
                range: MonaRange(
                    startPosition: MonaPosition(line: 2, column: 1),
                    endPosition: MonaPosition(line: 2, column: 9)
                ),
                command: MonaCodelensCommand(
                    id: "codelens.showReferences",
                    title: "1 reference",
                    edits: []
                )
            )
        ]
    }

    // MARK: - 1. Feature-specific behavior: render / resolve / invoke / release by model version

    func testRenderCodeLensesRetainsResultsByModelVersion() {
        let feature = MonaCodelensFeature()
        let model = makeModel()
        let version = model.getVersionId()

        let rendered = feature.renderCodeLenses(sampleLenses(), modelVersion: version)

        XCTAssertEqual(rendered.count, 2)
        XCTAssertEqual(rendered.map { $0.command.title }, ["3 references", "1 reference"])
        XCTAssertEqual(feature.renderedLensCount(for: version), 2)
    }

    func testRenderCodeLensesForNewModelVersionIsIndependent() {
        let feature = MonaCodelensFeature()
        let model = makeModel()

        let v1 = model.getVersionId()
        _ = feature.renderCodeLenses(sampleLenses(), modelVersion: v1)
        // The model advances (a direct mutation bypassing the feature).
        model.setValue("let x = 2\nlet y = 3")
        let v2 = model.getVersionId()

        XCTAssertNotEqual(v1, v2)
        XCTAssertEqual(feature.renderedLensCount(for: v1), 2)
        XCTAssertEqual(feature.renderedLensCount(for: v2), 0)

        _ = feature.renderCodeLenses(Array(sampleLenses().prefix(1)), modelVersion: v2)
        XCTAssertEqual(feature.renderedLensCount(for: v2), 1)
        XCTAssertEqual(feature.renderedLensCount(for: v1), 2)
    }

    func testResolveCodeLensReturnsLensWithCommandIntact() {
        let feature = MonaCodelensFeature()
        let original = sampleLenses()[0]
        let resolved = feature.resolveCodeLens(original)
        XCTAssertEqual(resolved.command.id, original.command.id)
        XCTAssertEqual(resolved.command.title, original.command.title)
        XCTAssertEqual(resolved.command.edits, original.command.edits)
        XCTAssertEqual(resolved.range, original.range)
    }

    func testInvokeCodeLensCommitsCommandEditsTransactionallyThroughGateway() {
        let feature = MonaCodelensFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let lens = MonaCodelens(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 9)
            ),
            command: MonaCodelensCommand(
                id: "codelens.showReferences",
                title: "replace",
                edits: [
                    MonaCodelensEdit(
                        range: MonaRange(
                            startPosition: MonaPosition(line: 1, column: 1),
                            endPosition: MonaPosition(line: 1, column: 4)
                        ),
                        text: "HEL"
                    )
                ]
            )
        )
        let outcome = feature.invokeCodeLens(lens, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "HELlo")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testInvokeCodeLensWithNoEditsCommitsEmptyTransaction() {
        let feature = MonaCodelensFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let lens = MonaCodelens(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 5)
            ),
            command: MonaCodelensCommand(id: "codelens.showReferences", title: "noop", edits: [])
        )
        let outcome = feature.invokeCodeLens(lens, gateway: gateway)
        switch outcome {
        case .applied, .reconciled:
            XCTAssertEqual(model.getValue(), "hello")
        default:
            XCTFail("expected applied/reconciled, got \(outcome)")
        }
    }

    func testReleaseCodeLensesDropsResultsForStaleModelVersion() {
        let feature = MonaCodelensFeature()
        let model = makeModel()

        let v1 = model.getVersionId()
        _ = feature.renderCodeLenses(sampleLenses(), modelVersion: v1)
        XCTAssertEqual(feature.renderedLensCount(for: v1), 2)

        let released = feature.releaseCodeLenses(modelVersion: v1)
        XCTAssertEqual(released, 2)
        XCTAssertEqual(feature.renderedLensCount(for: v1), 0)
    }

    func testReleaseCodeLensesForUnknownVersionReleasesNothing() {
        let feature = MonaCodelensFeature()
        let model = makeModel()
        let v1 = model.getVersionId()
        _ = feature.renderCodeLenses(sampleLenses(), modelVersion: v1)
        let released = feature.releaseCodeLenses(modelVersion: v1 + 999)
        XCTAssertEqual(released, 0)
        XCTAssertEqual(feature.renderedLensCount(for: v1), 2)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()

        XCTAssertEqual(MonaCodelensFeature.featureId, "codelens")
        XCTAssertTrue(features.contains("codelens"))

        let actionIds = MonaCodelensFeature.declaredActionIds
        XCTAssertEqual(actionIds, ["codelens.showLensesInCurrentLine"])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        let commandIds = MonaCodelensFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "_executeCodeLensProvider",
            "codelens.showLensesInCurrentLine"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaCodelensFeature.declaredContributionIds, ["css.editor.codeLens"])
        for id in MonaCodelensFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaCodelensFeature.declaredKeybindingCommands, [])

        XCTAssertEqual(MonaCodelensFeature.declaredOptionIds, [
            "codeLens",
            "codeLensFontFamily",
            "codeLensFontSize"
        ])

        XCTAssertEqual(MonaCodelensFeature.declaredMenuIds, [])
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaCodelensFeature()
        let ticket = gate.captureTicket()

        var received: [MonaCodelens] = []
        let accepted = feature.publishCodeLenses(
            sampleLenses(),
            executor: executor,
            ticket: ticket
        ) { lenses in
            received = lenses
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaCodelensFeature()
        var fired: [MonaCodelensEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, render / resolve / invoke / release are no-ops.
        let model = makeModel()
        let version = model.getVersionId()
        let rendered = feature.renderCodeLenses(sampleLenses(), modelVersion: version)
        XCTAssertTrue(rendered.isEmpty)
        XCTAssertEqual(feature.renderedLensCount(for: version), 0)
        let resolved = feature.resolveCodeLens(sampleLenses()[0])
        XCTAssertEqual(resolved.command.id, "codelens.showReferences")
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaCodelensFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaCodelensFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Show CodeLens Commands for Current Line")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaCodelensFeature()
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
        let feature = MonaCodelensFeature()

        let featureLive = features.contains(MonaCodelensFeature.featureId)
        let actionCount = MonaCodelensFeature.declaredActionIds.count
        let commandCount = MonaCodelensFeature.declaredCommandIds.count
        let contribCount = MonaCodelensFeature.declaredContributionIds.count
        let kbCount = MonaCodelensFeature.declaredKeybindingCommands.count
        let optionCount = MonaCodelensFeature.declaredOptionIds.count
        let menuCount = MonaCodelensFeature.declaredMenuIds.count

        let slicePass = MonaCodelensFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaCodelensFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaCodelensFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaCodelensFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaCodelensFeature.declaredMenuIds.allSatisfy { _ in true }

        // Mutation: invoke a code lens through the transaction gateway.
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let version = model.getVersionId()
        _ = feature.renderCodeLenses(sampleLenses(), modelVersion: version)
        let invokeLens = MonaCodelens(
            range: MonaRange(
                startPosition: MonaPosition(line: 1, column: 1),
                endPosition: MonaPosition(line: 1, column: 9)
            ),
            command: MonaCodelensCommand(
                id: "codelens.showReferences",
                title: "replace",
                edits: [
                    MonaCodelensEdit(
                        range: MonaRange(
                            startPosition: MonaPosition(line: 1, column: 1),
                            endPosition: MonaPosition(line: 1, column: 4)
                        ),
                        text: "HEL"
                    )
                ]
            )
        )
        let mutation: Bool
        let outcome = feature.invokeCodeLens(invokeLens, gateway: gateway)
        if case .applied = outcome, model.getValue() == "HELlo" {
            mutation = true
        } else {
            mutation = false
        }

        // Release the stale-model-version lenses.
        let released = feature.releaseCodeLenses(modelVersion: version)
        let releasePass = (released == 2 && feature.renderedLensCount(for: version) == 0)

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishCodeLenses([], executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("CODELENS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
