// MonaDocumentSymbolsFeatureTests.swift
//
// P05-T115 — Implement retained feature documentSymbols.
//
// Verifies the documentSymbols feature across its three implementation operations:
//   1. Feature-specific behavior: request, version-gate, sort, and expose
//      document-symbol provider results. Provider symbols are requested and
//      retained keyed by model version so a stale version's results can be
//      released when the model advances. Symbols are sorted by range start
//      position then name. A symbol command's edits route through the
//      `MonaTransactionGateway`.
//   2. The exact feature identity `documentSymbols` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     DOCUMENTSYMBOLS feature=live actions=1 commands=2 contributions=0 keybindings=1 options=0 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaDocumentSymbolsFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "func foo() {}\nfunc bar() {}") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/docsymbols-\(UUID().uuidString)")
        )
    }

    private func makeSymbol(
        name: String,
        line: Int,
        column: Int = 1,
        detail: String? = nil,
        kind: MonaDocumentSymbolKind = .function,
        command: MonaDocumentSymbolCommand? = nil
    ) -> MonaDocumentSymbol {
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: column),
            endPosition: MonaPosition(line: line, column: column + name.count + 2)
        )
        let selection = MonaRange(
            startPosition: MonaPosition(line: line, column: column),
            endPosition: MonaPosition(line: line, column: column + name.count)
        )
        return MonaDocumentSymbol(
            name: name,
            detail: detail,
            kind: kind,
            range: range,
            selectionRange: selection,
            children: [],
            command: command
        )
    }

    // MARK: - 1. Feature-specific behavior: request / version-gate / sort / expose

    func testRequestDocumentSymbolsRetainsResultsByModelVersion() {
        let feature = MonaDocumentSymbolsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        let symbols = [
            makeSymbol(name: "foo", line: 1),
            makeSymbol(name: "bar", line: 2)
        ]

        let retained = feature.requestDocumentSymbols(symbols, modelVersion: version)

        XCTAssertEqual(retained.count, 2)
        XCTAssertEqual(feature.retainedSymbolCount(for: version), 2)
    }

    func testRequestDocumentSymbolsForDistinctVersionsIsIndependent() {
        let feature = MonaDocumentSymbolsFeature()
        let v1 = 1
        let v2 = 2

        _ = feature.requestDocumentSymbols([makeSymbol(name: "foo", line: 1)], modelVersion: v1)
        XCTAssertEqual(feature.retainedSymbolCount(for: v1), 1)
        XCTAssertEqual(feature.retainedSymbolCount(for: v2), 0)

        _ = feature.requestDocumentSymbols([makeSymbol(name: "bar", line: 2)], modelVersion: v2)
        XCTAssertEqual(feature.retainedSymbolCount(for: v2), 1)
        XCTAssertEqual(feature.retainedSymbolCount(for: v1), 1)
    }

    func testRequestDocumentSymbolsSortsByRangeStartThenName() {
        let feature = MonaDocumentSymbolsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        // Provided out of order: a later-line symbol first, then an equal-line
        // symbol with a name that sorts after.
        let unsorted = [
            makeSymbol(name: "zeta", line: 3),
            makeSymbol(name: "alpha", line: 1),
            makeSymbol(name: "beta", line: 1)
        ]

        let sorted = feature.requestDocumentSymbols(unsorted, modelVersion: version)

        XCTAssertEqual(sorted.map { $0.name }, ["alpha", "beta", "zeta"])
    }

    func testReleaseDocumentSymbolsDropsResultsForStaleVersion() {
        let feature = MonaDocumentSymbolsFeature()
        let model = makeModel()
        let version = model.getVersionId()
        _ = feature.requestDocumentSymbols(
            [makeSymbol(name: "foo", line: 1)],
            modelVersion: version
        )
        XCTAssertEqual(feature.retainedSymbolCount(for: version), 1)

        let released = feature.releaseDocumentSymbols(modelVersion: version)
        XCTAssertEqual(released, 1)
        XCTAssertEqual(feature.retainedSymbolCount(for: version), 0)
    }

    func testInvokeDocumentSymbolRoutesCommandEditsThroughTransactionGateway() {
        let feature = MonaDocumentSymbolsFeature()
        let model = makeModel("hello world")
        let gateway = MonaTransactionGateway(model: model)
        let symbol = makeSymbol(
            name: "foo",
            line: 1,
            command: MonaDocumentSymbolCommand(
                id: "editor.action.quickOutline",
                title: "Go to Symbol...",
                edits: [
                    MonaDocumentSymbolEdit(
                        range: MonaRange(
                            startPosition: MonaPosition(line: 1, column: 1),
                            endPosition: MonaPosition(line: 1, column: 6)
                        ),
                        text: "HELLO"
                    )
                ]
            )
        )

        let outcome = feature.invokeDocumentSymbol(symbol, gateway: gateway)

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "HELLO world")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testInvokeDocumentSymbolWithoutCommandIsAcknowledged() {
        let feature = MonaDocumentSymbolsFeature()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let symbol = makeSymbol(name: "foo", line: 1, command: nil)

        let outcome = feature.invokeDocumentSymbol(symbol, gateway: gateway)

        switch outcome {
        case .applied, .reconciled:
            XCTAssertEqual(model.getValue(), "hello")
        default:
            XCTFail("expected applied/reconciled, got \(outcome)")
        }
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaDocumentSymbolsFeature.featureId, "documentSymbols")
        XCTAssertTrue(features.contains("documentSymbols"))

        XCTAssertEqual(MonaDocumentSymbolsFeature.declaredActionIds, [
            "editor.action.quickOutline"
        ])
        for id in MonaDocumentSymbolsFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaDocumentSymbolsFeature.declaredCommandIds, [
            "_executeDocumentSymbolProvider",
            "editor.action.quickOutline"
        ])
        for id in MonaDocumentSymbolsFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // documentSymbols declares no contributions — it is a provider registry.
        XCTAssertEqual(MonaDocumentSymbolsFeature.declaredContributionIds, [])
        for id in MonaDocumentSymbolsFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaDocumentSymbolsFeature.declaredKeybindingCommands, [
            "editor.action.quickOutline"
        ])

        XCTAssertEqual(MonaDocumentSymbolsFeature.declaredOptionIds, [])

        XCTAssertEqual(MonaDocumentSymbolsFeature.declaredMenuIds, [
            "EditorContext"
        ])
        for id in MonaDocumentSymbolsFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaDocumentSymbolsFeature()
        let version = model.getVersionId()
        let ticket = gate.captureTicket()
        let symbols = [makeSymbol(name: "foo", line: 1)]

        var received: [MonaDocumentSymbol]?
        let accepted = feature.publishDocumentSymbols(
            symbols,
            modelVersion: version,
            executor: executor,
            ticket: ticket
        ) { result in received = result }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaDocumentSymbolsFeature()
        var fired: [MonaDocumentSymbolsEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, request / release / invoke are no-ops.
        let version = 1
        let retained = feature.requestDocumentSymbols(
            [makeSymbol(name: "foo", line: 1)],
            modelVersion: version
        )
        XCTAssertTrue(retained.isEmpty)
        XCTAssertEqual(feature.retainedSymbolCount(for: version), 0)
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.invokeDocumentSymbol(
            makeSymbol(name: "foo", line: 1, command: nil),
            gateway: gateway
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "hello")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaDocumentSymbolsFeature()
        let enActionLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enActionLabels.count, MonaDocumentSymbolsFeature.declaredActionIds.count)
        XCTAssertEqual(enActionLabels.first, "Go to Symbol...")
        let pseudoActionLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoActionLabels.allSatisfy { $0.hasPrefix("\u{FF3B}") && $0.hasSuffix("\u{FF3D}") })
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaDocumentSymbolsFeature()
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
        let options = MonaOptionStore()
        let feature = MonaDocumentSymbolsFeature()

        let featureLive = features.contains(MonaDocumentSymbolsFeature.featureId)
        let actionCount = MonaDocumentSymbolsFeature.declaredActionIds.count
        let commandCount = MonaDocumentSymbolsFeature.declaredCommandIds.count
        let contribCount = MonaDocumentSymbolsFeature.declaredContributionIds.count
        let kbCount = MonaDocumentSymbolsFeature.declaredKeybindingCommands.count
        let optionCount = MonaDocumentSymbolsFeature.declaredOptionIds.count
        let menuCount = MonaDocumentSymbolsFeature.declaredMenuIds.count

        let slicePass = MonaDocumentSymbolsFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaDocumentSymbolsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaDocumentSymbolsFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaDocumentSymbolsFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaDocumentSymbolsFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaDocumentSymbolsFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Request (with sort) + version-gate + expose.
        let model = makeModel("hello world")
        let version = model.getVersionId()
        let unsorted = [
            makeSymbol(name: "zeta", line: 3),
            makeSymbol(name: "alpha", line: 1)
        ]
        let sorted = feature.requestDocumentSymbols(unsorted, modelVersion: version)
        let requestPass = sorted.map { $0.name } == ["alpha", "zeta"]
            && feature.retainedSymbolCount(for: version) == sorted.count

        // Mutation: a symbol command's edits route through the gateway.
        let symbol = makeSymbol(
            name: "foo",
            line: 1,
            command: MonaDocumentSymbolCommand(
                id: "editor.action.quickOutline",
                title: "Go to Symbol...",
                edits: [
                    MonaDocumentSymbolEdit(
                        range: MonaRange(
                            startPosition: MonaPosition(line: 1, column: 1),
                            endPosition: MonaPosition(line: 1, column: 6)
                        ),
                        text: "HELLO"
                    )
                ]
            )
        )
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.invokeDocumentSymbol(symbol, gateway: gateway)
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "HELLO world" {
            mutation = true
        } else {
            mutation = false
        }

        // Release the stale-version results.
        let released = feature.releaseDocumentSymbols(modelVersion: version)
        let releasePass = released == sorted.count && feature.retainedSymbolCount(for: version) == 0

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishDocumentSymbols(
            [makeSymbol(name: "foo", line: 1)],
            modelVersion: version,
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let actionLabelCount = feature.localizedActionLabels(profile: .default).count
        let localizationPass = actionLabelCount == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("DOCUMENTSYMBOLS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(requestPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
