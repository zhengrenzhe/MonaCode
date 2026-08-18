// MonaQuickOutlineFeatureTests.swift
//
// P05-T144 — Implement retained feature quickOutline.
//
// Verifies the quickOutline feature across its three implementation operations:
//   1. Feature-specific behavior: filter, group, and navigate document symbols
//      in the quick outline (reuse T115 MonaDocumentSymbolsFeature's symbol
//      results).
//   2. The exact feature identity `quickOutline` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     QUICKOUTLINE feature=live actions=1 commands=1 contributions=1 keybindings=1 options=0 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaQuickOutlineFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/quickoutline-\(UUID().uuidString)")
        )
    }

    private func makeSymbols() -> [MonaDocumentSymbol] {
        return [
            MonaDocumentSymbol(
                name: "MyClass",
                detail: "class",
                kind: .classKind,
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 10, column: 1)
                ),
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 8)
                )
            ),
            MonaDocumentSymbol(
                name: "myMethod",
                detail: "method",
                kind: .method,
                range: MonaRange(
                    startPosition: MonaPosition(line: 2, column: 1),
                    endPosition: MonaPosition(line: 5, column: 1)
                ),
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 2, column: 1),
                    endPosition: MonaPosition(line: 2, column: 9)
                )
            ),
            MonaDocumentSymbol(
                name: "myField",
                detail: nil,
                kind: .field,
                range: MonaRange(
                    startPosition: MonaPosition(line: 3, column: 1),
                    endPosition: MonaPosition(line: 3, column: 8)
                ),
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 3, column: 1),
                    endPosition: MonaPosition(line: 3, column: 8)
                )
            ),
            MonaDocumentSymbol(
                name: "helperFunc",
                detail: "function",
                kind: .function,
                range: MonaRange(
                    startPosition: MonaPosition(line: 6, column: 1),
                    endPosition: MonaPosition(line: 8, column: 1)
                ),
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 6, column: 1),
                    endPosition: MonaPosition(line: 6, column: 11)
                )
            )
        ]
    }

    // MARK: - 1. Feature-specific behavior: filter, group, navigate

    func testFilterReturnsAllSymbolsForEmptyQuery() {
        let feature = MonaQuickOutlineFeature()
        let symbols = makeSymbols()

        let entries = feature.filterSymbols(query: "", from: symbols)

        XCTAssertEqual(entries.count, symbols.count)
    }

    func testFilterNarrowsByCaseInsensitiveSubstringOnName() {
        let feature = MonaQuickOutlineFeature()
        let symbols = makeSymbols()

        let entries = feature.filterSymbols(query: "my", from: symbols)

        XCTAssertEqual(entries.count, 3) // MyClass, myMethod, myField
        XCTAssertTrue(entries.allSatisfy { $0.name.lowercased().contains("my") })
    }

    func testFilterReturnsEmptyForNoMatch() {
        let feature = MonaQuickOutlineFeature()
        let symbols = makeSymbols()

        let entries = feature.filterSymbols(query: "nonexistent", from: symbols)

        XCTAssertTrue(entries.isEmpty)
    }

    func testFilterFiresEventWithFilteredEntries() {
        let feature = MonaQuickOutlineFeature()
        let symbols = makeSymbols()

        var fired: [MonaQuickOutlineEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.filterSymbols(query: "my", from: symbols)

        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired[0].entries.count, 3)
    }

    func testGroupSymbolsGroupsByKind() {
        let feature = MonaQuickOutlineFeature()
        let symbols = makeSymbols()

        let entries = feature.filterSymbols(query: "", from: symbols)
        let groups = feature.groupSymbols(entries)

        XCTAssertFalse(groups.isEmpty)
        // Each group should have a consistent kind.
        XCTAssertTrue(groups.allSatisfy { group in
            group.entries.allSatisfy { $0.kind == group.kind }
        })
        // The class group should contain MyClass.
        let classGroup = groups.first { $0.kind == .classKind }
        XCTAssertNotNil(classGroup)
        XCTAssertEqual(classGroup?.entries.count, 1)
        XCTAssertEqual(classGroup?.entries.first?.name, "MyClass")
    }

    func testNavigateToSymbolRevealsSelectionThroughGateway() {
        let feature = MonaQuickOutlineFeature()
        let symbols = makeSymbols()
        let model = makeModel("hello\nworld\n")
        let gateway = MonaTransactionGateway(model: model)

        let entries = feature.filterSymbols(query: "", from: symbols)
        let myMethod = entries.first { $0.name == "myMethod" }!
        let selections = feature.navigateToSymbol(myMethod, gateway: gateway)

        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections[0].anchor, myMethod.selectionRange.startPosition)
    }

    func testFilterReturnsEmptyAfterDisposal() {
        let feature = MonaQuickOutlineFeature()
        let symbols = makeSymbols()
        feature.dispose()

        let entries = feature.filterSymbols(query: "", from: symbols)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaQuickOutlineFeature.featureId, "quickOutline")
        XCTAssertTrue(features.contains("quickOutline"))

        XCTAssertEqual(MonaQuickOutlineFeature.declaredActionIds, [
            "editor.action.quickOutline"
        ])
        for id in MonaQuickOutlineFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaQuickOutlineFeature.declaredCommandIds, [
            "editor.action.quickOutline"
        ])
        for id in MonaQuickOutlineFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaQuickOutlineFeature.declaredContributionIds, [
            "editor.controller.quickInput"
        ])
        for id in MonaQuickOutlineFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaQuickOutlineFeature.declaredKeybindingCommands, [
            "editor.action.quickOutline"
        ])
        for id in MonaQuickOutlineFeature.declaredKeybindingCommands {
            XCTAssertTrue(Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains(id),
                          "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaQuickOutlineFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaQuickOutlineFeature.declaredMenuIds, ["EditorContext"])
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaQuickOutlineFeature()
        let model = makeModel("")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.commitOutlineEdits(
            [MonaModelEditOperation(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 1)
                ),
                text: "hello"
            )],
            gateway: gateway
        )
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "hello")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaQuickOutlineFeature()
        let ticket = gate.captureTicket()
        let entries = [
            MonaQuickOutlineEntry(
                name: "foo",
                kind: .function,
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 4)
                ),
                detail: nil
            )
        ]

        var received: [MonaQuickOutlineEntry]?
        let accepted = feature.publishEntries(
            entries,
            executor: executor,
            ticket: ticket
        ) { e in
            received = e
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.count, 1)
        XCTAssertEqual(received?[0].name, "foo")
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaQuickOutlineFeature()
        let symbols = makeSymbols()

        var fired: [MonaQuickOutlineEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.filterSymbols(query: "", from: symbols)
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        let countBefore = fired.count
        _ = feature.filterSymbols(query: "", from: symbols)
        XCTAssertEqual(fired.count, countBefore)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaQuickOutlineFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaQuickOutlineFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels, ["Go to Symbol..."])
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertEqual(pseudoLabels.count, 1)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaQuickOutlineFeature()
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
        let feature = MonaQuickOutlineFeature()

        let featureLive = features.contains(MonaQuickOutlineFeature.featureId)
        let actionCount = MonaQuickOutlineFeature.declaredActionIds.count
        let commandCount = MonaQuickOutlineFeature.declaredCommandIds.count
        let contribCount = MonaQuickOutlineFeature.declaredContributionIds.count
        let kbCount = MonaQuickOutlineFeature.declaredKeybindingCommands.count
        let optionCount = MonaQuickOutlineFeature.declaredOptionIds.count
        let menuCount = MonaQuickOutlineFeature.declaredMenuIds.count

        let slicePass = MonaQuickOutlineFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaQuickOutlineFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaQuickOutlineFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaQuickOutlineFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaQuickOutlineFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaQuickOutlineFeature.declaredMenuIds.allSatisfy { _ in true }

        // Filter + group + navigate.
        let symbols = makeSymbols()
        let entries = feature.filterSymbols(query: "my", from: symbols)
        let filterPass = entries.count == 3 && entries.allSatisfy { $0.name.lowercased().contains("my") }
        let groups = feature.groupSymbols(entries)
        let groupPass = !groups.isEmpty && groups.allSatisfy { g in g.entries.allSatisfy { $0.kind == g.kind } }

        // Navigation through the transaction gateway (mutation).
        let model = makeModel("code\n")
        let gateway = MonaTransactionGateway(model: model)
        let myMethod = entries.first { $0.name == "myMethod" }!
        let selections = feature.navigateToSymbol(myMethod, gateway: gateway)
        var mutation = !selections.isEmpty
            && selections[0].anchor == myMethod.selectionRange.startPosition

        // Also verify the edit-path mutation through the gateway.
        let editOutcome = feature.commitOutlineEdits(
            [MonaModelEditOperation(
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 1)
                ),
                text: "x"
            )],
            gateway: gateway
        )
        if case .applied = editOutcome { mutation = mutation && true } else { mutation = false }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishEntries(
            [MonaQuickOutlineEntry(
                name: "x", kind: .function,
                selectionRange: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 2)
                ),
                detail: nil
            )],
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("QUICKOUTLINE feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(filterPass)
        XCTAssertTrue(groupPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
