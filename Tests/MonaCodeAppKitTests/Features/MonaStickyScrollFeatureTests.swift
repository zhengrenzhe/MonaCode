// MonaStickyScrollFeatureTests.swift
//
// P05-T152 — Implement retained feature stickyScroll.
//
// Verifies the stickyScroll feature across its three implementation operations:
//   1. Feature-specific behavior: project nested symbol and folding context
//      into sticky viewport rows (reuse T115 document symbols + T119 folding
//      ranges). Mutation via `MonaTransactionGateway`; async via
//      `MonaProviderExecutor` (P05-T013).
//   2. The exact feature identity `stickyScroll` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     STICKYSCROLL feature=live actions=0 commands=5 contributions=1 keybindings=3 options=1 menus=3 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import AppKit
import Foundation
import MonaCode
@testable import MonaCodeAppKit

final class MonaStickyScrollFeatureTests: XCTestCase {

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/stickyscroll-\(UUID().uuidString)")
        )
    }

    /// A stickyScroll option carrying the default configuration.
    private func stickyStore(
        enabled: Bool = true,
        maxLineCount: Int = 5,
        defaultModel: String = "outlineModel"
    ) -> MonaOptionStore {
        let store = MonaOptionStore()
        _ = store.setValue(.object([
            "enabled": .bool(enabled),
            "maxLineCount": .int(maxLineCount),
            "defaultModel": .string(defaultModel)
        ]), for: "stickyScroll")
        return store
    }

    /// Builds a document symbol spanning `start...end` (1-based lines).
    private func symbol(
        _ name: String,
        _ kind: MonaDocumentSymbolKind,
        start: Int,
        end: Int,
        children: [MonaDocumentSymbol] = []
    ) -> MonaDocumentSymbol {
        return MonaDocumentSymbol(
            name: name,
            detail: nil,
            kind: kind,
            range: MonaRange(
                startPosition: MonaPosition(line: start, column: 1),
                endPosition: MonaPosition(line: end, column: 1)
            ),
            selectionRange: MonaRange(
                startPosition: MonaPosition(line: start, column: 1),
                endPosition: MonaPosition(line: start, column: 1)
            ),
            children: children
        )
    }

    /// A three-level nesting: A (class 1-20) > B (method 3-10) > C (method 5-8).
    private func nestedSymbols() -> [MonaDocumentSymbol] {
        return [
            symbol("A", .classKind, start: 1, end: 20, children: [
                symbol("B", .method, start: 3, end: 10, children: [
                    symbol("C", .method, start: 5, end: 8)
                ])
            ])
        ]
    }

    // MARK: - 1. Feature-specific behavior: project nested symbol + folding context

    func testProjectStickyRowsWalksNestingChainAtViewportTop() {
        let feature = MonaStickyScrollFeature()
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [],
            viewportTopLine: 6,
            options: stickyStore()
        )
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.map { $0.symbol.name }, ["A", "B", "C"])
        XCTAssertEqual(rows.map { $0.depth }, [0, 1, 2])
        XCTAssertEqual(rows.map { $0.isCollapsed }, [false, false, false])
        XCTAssertEqual(rows.map { $0.lineNumber }, [1, 3, 5])
    }

    func testProjectStickyRowsStopsAtCollapsedSymbol() {
        let feature = MonaStickyScrollFeature()
        // Fold B (range 3-10): the chain stops at B (collapsed), C is hidden.
        let bRange = MonaRange(
            startPosition: MonaPosition(line: 3, column: 1),
            endPosition: MonaPosition(line: 10, column: 1)
        )
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [bRange],
            viewportTopLine: 6,
            options: stickyStore()
        )
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map { $0.symbol.name }, ["A", "B"])
        XCTAssertEqual(rows.map { $0.depth }, [0, 1])
        XCTAssertEqual(rows[0].isCollapsed, false)
        XCTAssertEqual(rows[1].isCollapsed, true)
    }

    func testProjectStickyRowsEmptyWhenViewportAboveFirstSymbol() {
        let feature = MonaStickyScrollFeature()
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [],
            viewportTopLine: 1,
            options: stickyStore()
        )
        // Viewport top at line 1: A starts at line 1 (not strictly above), so no
        // sticky ancestors.
        XCTAssertTrue(rows.isEmpty)
    }

    func testProjectStickyRowsEmptyWhenStickyScrollDisabled() {
        let feature = MonaStickyScrollFeature()
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [],
            viewportTopLine: 6,
            options: stickyStore(enabled: false)
        )
        XCTAssertTrue(rows.isEmpty)
    }

    func testProjectStickyRowsRespectsMaxLineCount() {
        let feature = MonaStickyScrollFeature()
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [],
            viewportTopLine: 6,
            options: stickyStore(maxLineCount: 2)
        )
        // maxLineCount=2 caps the 3-row chain to the innermost 2 rows (B, C),
        // re-based to depths 0 and 1.
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map { $0.symbol.name }, ["B", "C"])
        XCTAssertEqual(rows.map { $0.depth }, [0, 1])
    }

    func testPresentationBuildsAttributedStringAndIsVisible() {
        let feature = MonaStickyScrollFeature()
        let presentation = feature.presentation(
            for: nestedSymbols(),
            foldedRanges: [],
            options: stickyStore(),
            profile: .default,
            viewportTopLine: 6
        )
        XCTAssertTrue(presentation.visible)
        XCTAssertEqual(presentation.rows.count, 3)
        XCTAssertEqual(presentation.attributedString.string, "A\nB\nC")
    }

    func testPresentationHiddenWhenNoStickyRows() {
        let feature = MonaStickyScrollFeature()
        let presentation = feature.presentation(
            for: nestedSymbols(),
            foldedRanges: [],
            options: stickyStore(enabled: false),
            profile: .default,
            viewportTopLine: 6
        )
        XCTAssertFalse(presentation.visible)
        XCTAssertTrue(presentation.rows.isEmpty)
        XCTAssertEqual(presentation.attributedString.string, "")
    }

    func testPresentFiresEventAndRetainsCurrentPresentation() {
        let feature = MonaStickyScrollFeature()
        var fired: [MonaStickyScrollEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let presented = feature.present(
            using: nestedSymbols(),
            foldedRanges: [],
            options: stickyStore(),
            profile: .default,
            viewportTopLine: 6
        )
        XCTAssertTrue(presented)
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(feature.currentPresentation.rows.count, 3)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaStickyScrollFeature.featureId, "stickyScroll")
        XCTAssertTrue(features.contains("stickyScroll"))

        XCTAssertEqual(MonaStickyScrollFeature.declaredActionIds, [])
        for id in MonaStickyScrollFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
        }

        XCTAssertEqual(MonaStickyScrollFeature.declaredCommandIds, [
            "editor.action.focusStickyScroll",
            "editor.action.goToFocusedStickyScrollLine",
            "editor.action.selectNextStickyScrollLine",
            "editor.action.selectPreviousStickyScrollLine",
            "editor.action.toggleStickyScroll"
        ])
        for id in MonaStickyScrollFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaStickyScrollFeature.declaredContributionIds, [
            "store.contrib.stickyScrollController"
        ])
        for id in MonaStickyScrollFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaStickyScrollFeature.declaredKeybindingCommands, [
            "editor.action.goToFocusedStickyScrollLine",
            "editor.action.selectNextStickyScrollLine",
            "editor.action.selectPreviousStickyScrollLine"
        ])
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaStickyScrollFeature.declaredKeybindingCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }

        XCTAssertEqual(MonaStickyScrollFeature.declaredOptionIds, [
            "stickyScroll"
        ])

        XCTAssertEqual(MonaStickyScrollFeature.declaredMenuIds, [
            "CommandPalette",
            "MenubarAppearanceMenu",
            "StickyScrollContext"
        ])
        for id in MonaStickyScrollFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughTransactionGateway() {
        let feature = MonaStickyScrollFeature()
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [],
            viewportTopLine: 6,
            options: stickyStore()
        )

        let outcome = feature.commitRevealStickyLine(rows[2], gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(gateway.lastCommittedSelections.first?.anchor.line, 5)
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaStickyScrollFeature()
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [],
            viewportTopLine: 6,
            options: stickyStore()
        )
        let ticket = gate.captureTicket()

        var received: [MonaStickyScrollRow]?
        let accepted = feature.publishStickyScroll(
            rows,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, rows)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaStickyScrollFeature()
        var fired: [MonaStickyScrollEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, project / present / commit are no-ops.
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [],
            viewportTopLine: 6,
            options: stickyStore()
        )
        XCTAssertTrue(rows.isEmpty)
        let presented = feature.present(
            using: nestedSymbols(),
            foldedRanges: [],
            options: stickyStore(),
            profile: .default,
            viewportTopLine: 6
        )
        XCTAssertFalse(presented)
        let model = makeModel("abc")
        let outcome = feature.commitRevealStickyLine(
            MonaStickyScrollRow(lineNumber: 1, symbol: nestedSymbols()[0], depth: 0, isCollapsed: false),
            gateway: MonaTransactionGateway(model: model)
        )
        if case .dropped = outcome {
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaStickyScrollFeature()
        XCTAssertEqual(feature.localizedActionLabels(profile: .default), [])
        XCTAssertEqual(feature.localizedActionLabels(profile: .custom("pseudo")), [])
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaStickyScrollFeature()
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
        let feature = MonaStickyScrollFeature()

        let featureLive = features.contains(MonaStickyScrollFeature.featureId)
        let actionCount = MonaStickyScrollFeature.declaredActionIds.count
        let commandCount = MonaStickyScrollFeature.declaredCommandIds.count
        let contribCount = MonaStickyScrollFeature.declaredContributionIds.count
        let kbCount = MonaStickyScrollFeature.declaredKeybindingCommands.count
        let optionCount = MonaStickyScrollFeature.declaredOptionIds.count
        let menuCount = MonaStickyScrollFeature.declaredMenuIds.count

        let slicePass = MonaStickyScrollFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaStickyScrollFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaStickyScrollFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaStickyScrollFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaStickyScrollFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Projection: nesting chain at viewport top 6 = A, B, C.
        let rows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [],
            viewportTopLine: 6,
            options: stickyStore()
        )
        let projectionPass = rows.count == 3 && rows.map { $0.symbol.name } == ["A", "B", "C"]

        // Folding: collapse B → chain stops at B.
        let bRange = MonaRange(
            startPosition: MonaPosition(line: 3, column: 1),
            endPosition: MonaPosition(line: 10, column: 1)
        )
        let foldedRows = feature.projectStickyRows(
            symbols: nestedSymbols(),
            foldedRanges: [bRange],
            viewportTopLine: 6,
            options: stickyStore()
        )
        let foldingPass = foldedRows.count == 2 && foldedRows[1].isCollapsed

        // Presentation + present.
        let presentation = feature.presentation(
            for: nestedSymbols(),
            foldedRanges: [],
            options: stickyStore(),
            profile: .default,
            viewportTopLine: 6
        )
        let presented = feature.present(
            using: nestedSymbols(),
            foldedRanges: [],
            options: stickyStore(),
            profile: .default,
            viewportTopLine: 6
        )
        let presentPass = presentation.visible && presented && feature.currentPresentation.rows.count == 3

        // Mutation: reveal the deepest sticky line through the gateway.
        let model = makeModel("abc")
        let gateway = MonaTransactionGateway(model: model)
        var mutation = false
        let outcome = feature.commitRevealStickyLine(rows[2], gateway: gateway)
        if case .applied = outcome, gateway.lastCommittedSelections.first?.anchor.line == 5 {
            mutation = true
        }

        // Async publication.
        let pubGate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: pubGate, queue: queue)
        var delivered = false
        _ = feature.publishStickyScroll(rows, executor: executor, ticket: pubGate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("STICKYSCROLL feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(projectionPass)
        XCTAssertTrue(foldingPass)
        XCTAssertTrue(presentPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
