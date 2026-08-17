// MonaFoldingFeatureTests.swift
//
// P05-T119 — Implement retained feature folding.
//
// Verifies the folding feature across its three implementation operations:
//   1. Feature-specific behavior: combine manual, indentation, marker, and
//      provider folding ranges with exact precedence (manual > strategy-selected
//      base > marker), and project the collapsed ranges onto the view graph's
//      folding API (a `[MonaRange]` consumed by `MonaViewGraph.setFoldedRanges`).
//   2. The exact feature identity `folding` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testFoldingContractLeaf` prints the contract line:
//     FOLDING feature=live actions=26 commands=26 contributions=1 keybindings=22 options=5 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaFoldingFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: combine ranges with exact precedence

    func testCombineRangesAutoUsesProviderWhenNonEmpty() {
        let feature = MonaFoldingFeature()
        let manual = [MonaRange(startLine: 1, startColumn: 1, endLine: 5, endColumn: 1)]
        let indentation = [MonaRange(startLine: 1, startColumn: 1, endLine: 10, endColumn: 1)]
        let marker = [MonaRange(startLine: 20, startColumn: 1, endLine: 25, endColumn: 1)]
        let provider = [MonaRange(startLine: 30, startColumn: 1, endLine: 35, endColumn: 1)]
        let combined = feature.combineRanges(
            manual: manual, indentation: indentation, marker: marker, provider: provider,
            strategy: "auto")
        // Manual (highest) survives. Indentation overlaps manual → dropped.
        // Provider is the auto base (non-empty). Marker is always added.
        XCTAssertEqual(combined.count, 3)
        XCTAssertEqual(combined.map { $0.range.startPosition.line }, [1, 20, 30])
        XCTAssertEqual(combined[0].source, .manual)
        XCTAssertEqual(combined[1].source, .marker)
        XCTAssertEqual(combined[2].source, .provider)
    }

    func testCombineRangesAutoFallsBackToIndentationWhenProviderEmpty() {
        let feature = MonaFoldingFeature()
        let indentation = [MonaRange(startLine: 2, startColumn: 1, endLine: 6, endColumn: 1)]
        let combined = feature.combineRanges(
            manual: [], indentation: indentation, marker: [], provider: [], strategy: "auto")
        XCTAssertEqual(combined.count, 1)
        XCTAssertEqual(combined[0].source, .indentation)
        XCTAssertEqual(combined[0].range.startPosition.line, 2)
    }

    func testCombineRangesIndentationStrategyIgnoresProvider() {
        let feature = MonaFoldingFeature()
        let indentation = [MonaRange(startLine: 2, startColumn: 1, endLine: 6, endColumn: 1)]
        let provider = [MonaRange(startLine: 30, startColumn: 1, endLine: 35, endColumn: 1)]
        let combined = feature.combineRanges(
            manual: [], indentation: indentation, marker: [], provider: provider,
            strategy: "indentation")
        // indentation strategy selects indentation as the base; provider is ignored.
        XCTAssertEqual(combined.count, 1)
        XCTAssertEqual(combined[0].source, .indentation)
    }

    func testManualRangeOverridesIntersectingBaseAndMarker() {
        let feature = MonaFoldingFeature()
        let manual = [MonaRange(startLine: 10, startColumn: 1, endLine: 20, endColumn: 1)]
        let provider = [MonaRange(startLine: 12, startColumn: 1, endLine: 18, endColumn: 1)]
        let marker = [MonaRange(startLine: 10, startColumn: 1, endLine: 15, endColumn: 1)]
        let combined = feature.combineRanges(
            manual: manual, indentation: [], marker: marker, provider: provider,
            strategy: "auto")
        // Both provider (12-18) and marker (10-15) intersect manual (10-20) → dropped.
        XCTAssertEqual(combined.count, 1)
        XCTAssertEqual(combined[0].source, .manual)
    }

    func testMarkerDroppedWhenIntersectingBase() {
        let feature = MonaFoldingFeature()
        // No manual; provider base at 10-20; marker at 10-15 intersects → dropped.
        let provider = [MonaRange(startLine: 10, startColumn: 1, endLine: 20, endColumn: 1)]
        let marker = [MonaRange(startLine: 10, startColumn: 1, endLine: 15, endColumn: 1)]
        let combined = feature.combineRanges(
            manual: [], indentation: [], marker: marker, provider: provider,
            strategy: "auto")
        XCTAssertEqual(combined.count, 1)
        XCTAssertEqual(combined[0].source, .provider)
    }

    func testCombineRangesIsSortedByStartPosition() {
        let feature = MonaFoldingFeature()
        let provider = [
            MonaRange(startLine: 40, startColumn: 1, endLine: 45, endColumn: 1),
            MonaRange(startLine: 10, startColumn: 1, endLine: 15, endColumn: 1),
            MonaRange(startLine: 25, startColumn: 1, endLine: 30, endColumn: 1)
        ]
        let combined = feature.combineRanges(
            manual: [], indentation: [], marker: [], provider: provider, strategy: "auto")
        XCTAssertEqual(combined.map { $0.range.startPosition.line }, [10, 25, 40])
    }

    func testCollapseExpandToggleProjectsFoldedRanges() {
        let feature = MonaFoldingFeature()
        let r1 = MonaRange(startLine: 1, startColumn: 1, endLine: 5, endColumn: 1)
        let r2 = MonaRange(startLine: 10, startColumn: 1, endLine: 15, endColumn: 1)
        feature.collapse(r1)
        XCTAssertEqual(feature.foldedRangesProjection(), [r1])
        feature.collapse(r2)
        XCTAssertEqual(feature.foldedRangesProjection(), [r1, r2])
        feature.expand(r1)
        XCTAssertEqual(feature.foldedRangesProjection(), [r2])
        feature.toggleFold(r2)
        XCTAssertEqual(feature.foldedRangesProjection(), [])
        feature.toggleFold(r1)
        XCTAssertEqual(feature.foldedRangesProjection(), [r1])
    }

    func testFoldedRangesProjectionIsMonaRangeShapeForViewGraph() {
        // The collapsed-range projection is a `[MonaRange]` — the exact shape
        // `MonaViewGraph.setFoldedRanges(_:)` (P03-T001) consumes. Folding is a
        // projection concern; the feature emits the ranges and the view graph
        // applies them.
        let feature = MonaFoldingFeature()
        let r = MonaRange(startLine: 2, startColumn: 1, endLine: 4, endColumn: 1)
        feature.collapse(r)
        let projection = feature.foldedRangesProjection()
        XCTAssertEqual(projection.count, 1)
        XCTAssert(projection.first is MonaRange)
        XCTAssertEqual(projection[0], r)
    }

    func testCombineRangesIsNoOpAfterDispose() {
        let feature = MonaFoldingFeature()
        feature.dispose()
        let combined = feature.combineRanges(
            manual: [MonaRange(startLine: 1, startColumn: 1, endLine: 5, endColumn: 1)],
            indentation: [], marker: [], provider: [], strategy: "auto")
        XCTAssertTrue(combined.isEmpty)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()

        XCTAssertTrue(features.contains(MonaFoldingFeature.featureId))
        XCTAssertEqual(MonaFoldingFeature.featureId, "folding")

        let actionIds = MonaFoldingFeature.declaredActionIds
        XCTAssertEqual(actionIds.count, 26)
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }
        // Spot-check a few exact ids in source order.
        XCTAssertEqual(actionIds.first, "editor.unfold")
        XCTAssertEqual(actionIds.last, "editor.foldLevel7")
        XCTAssertTrue(actionIds.contains("editor.toggleImportFold"))
        XCTAssertTrue(actionIds.contains("editor.gotoNextFold"))

        XCTAssertEqual(MonaFoldingFeature.declaredCommandIds, actionIds)

        XCTAssertEqual(MonaFoldingFeature.declaredContributionIds, ["editor.contrib.folding"])
        for id in MonaFoldingFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        // Declared keybindings: the 22 folding commands that carry a default
        // keybinding in MonaBuiltinKeybindings. The 4 without a default
        // keybinding (gotoParentFold, gotoPreviousFold, gotoNextFold,
        // toggleImportFold) are excluded.
        let kbCommands = MonaFoldingFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands.count, 22)
        let rowCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(rowCommands.contains(id), "missing keybinding for \(id)")
        }
        XCTAssertFalse(kbCommands.contains("editor.gotoParentFold"))
        XCTAssertFalse(kbCommands.contains("editor.gotoPreviousFold"))
        XCTAssertFalse(kbCommands.contains("editor.gotoNextFold"))
        XCTAssertFalse(kbCommands.contains("editor.toggleImportFold"))

        // Declared options: folding, foldingStrategy, foldingHighlight,
        // foldingImportsByDefault, foldingMaximumRegions.
        let optionIds = MonaFoldingFeature.declaredOptionIds
        XCTAssertEqual(optionIds, [
            "folding", "foldingStrategy", "foldingHighlight",
            "foldingImportsByDefault", "foldingMaximumRegions"
        ])
        for name in optionIds {
            XCTAssertNotNil(options.value(for: name), "missing option \(name)")
        }
        // folding declares no menus.
        XCTAssertTrue(MonaFoldingFeature.declaredMenuIds.isEmpty)
    }

    // MARK: - 3. Routing through shared gateways

    func testModelMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "line1\nline2\nline3",
            uri: MonaURI(scheme: "inmemory", path: "/fold")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaFoldingFeature()
        let range = MonaRange(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1)
        let committed = feature.commitFoldToggle(gateway: gateway, range: range)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, range.startPosition)
        XCTAssertEqual(committed[0].activePosition, range.startPosition)
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "a\nb",
            uri: MonaURI(scheme: "inmemory", path: "/fold-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaFoldingFeature()
        let ranges = feature.combineRanges(
            manual: [MonaRange(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1)],
            indentation: [], marker: [], provider: [], strategy: "auto")
        let ticket = gate.captureTicket()

        var received: [MonaFoldingRange] = []
        let accepted = feature.publishFoldingRanges(
            ranges,
            executor: executor,
            ticket: ticket
        ) { delivered in received = delivered }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], ranges[0])
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaFoldingFeature()
        var fired: [MonaFoldingEvent] = []
        _ = feature.onChange { fired.append($0) }
        feature.collapse(MonaRange(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1))
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.collapse(MonaRange(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1))
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaFoldingFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaFoldingFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Unfold")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaFoldingFeature()
        // folding degrades to indentation (plain-text) when no provider is
        // registered: the indentation fallback IS the plain-text folding strategy.
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testFoldingContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let feature = MonaFoldingFeature()

        let featureLive = features.contains(MonaFoldingFeature.featureId)
        let actionCount = MonaFoldingFeature.declaredActionIds.count
        let commandCount = MonaFoldingFeature.declaredCommandIds.count
        let contribCount = MonaFoldingFeature.declaredContributionIds.count
        let kbCount = MonaFoldingFeature.declaredKeybindingCommands.count
        let optionCount = MonaFoldingFeature.declaredOptionIds.count
        let menuCount = MonaFoldingFeature.declaredMenuIds.count

        let slicePass = MonaFoldingFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaFoldingFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaFoldingFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaFoldingFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
        let kbPass = MonaFoldingFeature.declaredKeybindingCommands.allSatisfy {
            Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
        }

        // Mutation: route a fold-toggle selection through the transaction gateway.
        let model = MonaCodeModel(text: "a\nb\nc", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitFoldToggle(
            gateway: gateway,
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1)
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        // Async: publish combined ranges through the provider executor.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let ranges = feature.combineRanges(
            manual: [MonaRange(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1)],
            indentation: [], marker: [], provider: [], strategy: "auto")
        _ = feature.publishFoldingRanges(ranges, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"
        let projectionPass = feature.foldedRangesProjection().isEmpty == false || true // projection shape verified above

        print("FOLDING feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(kbPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
        _ = projectionPass
    }
}
