// MonaSmartSelectFeatureTests.swift
//
// P05-T150 — Implement retained feature smartSelect.
//
// Verifies the smartSelect feature across its three implementation operations:
//   1. Feature-specific behavior: expand and shrink provider selection ranges
//      while retaining orientation (a forward selection stays forward; a
//      backward selection stays backward across expand / shrink). Reuses
//      `MonaProviderExecutor` (P05-T013) for async publication.
//   2. The exact feature identity `smartSelect` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     SMARTSELECT feature=live actions=2 commands=3 contributions=1 keybindings=2 options=1 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaSmartSelectFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = value") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/smartselect-\(UUID().uuidString)")
        )
    }

    /// A three-level selection-range tree:
    ///   inner (word) → parent (line) → grandparent (statement).
    private func sampleTree() -> MonaSmartSelectSelectionRange {
        let inner = MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 6)
        )
        let parent = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 10)
        )
        let grandparent = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 20)
        )
        return MonaSmartSelectSelectionRange(
            range: inner,
            parent: MonaSmartSelectSelectionRange(
                range: parent,
                parent: MonaSmartSelectSelectionRange(range: grandparent, parent: nil)
            )
        )
    }

    // MARK: - 1. Feature-specific behavior: expand / shrink while retaining orientation

    func testBeginSessionRetainsCurrentRangeAndOrientation() {
        let feature = MonaSmartSelectFeature()
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)

        XCTAssertEqual(feature.currentRange, tree.range)
        XCTAssertEqual(feature.currentSelection?.anchor, tree.range.startPosition)
        XCTAssertEqual(feature.currentSelection?.activePosition, tree.range.endPosition)
    }

    func testBeginSessionBackwardOrientationRetained() {
        let feature = MonaSmartSelectFeature()
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .backward)

        // Backward: anchor at end, active at start.
        XCTAssertEqual(feature.currentSelection?.anchor, tree.range.endPosition)
        XCTAssertEqual(feature.currentSelection?.activePosition, tree.range.startPosition)
    }

    func testExpandMovesToParentRange() {
        let feature = MonaSmartSelectFeature()
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)

        let expanded = feature.expandedRange(using: tree)
        XCTAssertEqual(expanded, tree.parent?.range)
    }

    func testExpandSelectionCommitsExpandedRangeThroughGateway() {
        let feature = MonaSmartSelectFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)

        let outcome = feature.expandSelection(gateway: gateway)
        if case .applied = outcome {
            // expected: the expanded selection is committed.
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
        // The current range advanced to the parent.
        XCTAssertEqual(feature.currentRange, tree.parent?.range)
        // The committed selection is the expanded range.
        XCTAssertEqual(gateway.lastCommittedSelections.count, 1)
        XCTAssertEqual(gateway.lastCommittedSelections.first?.anchor, tree.parent?.range.startPosition)
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition, tree.parent?.range.endPosition)
    }

    func testExpandSelectionRetainsBackwardOrientation() {
        let feature = MonaSmartSelectFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .backward)

        _ = feature.expandSelection(gateway: gateway)
        // Backward: anchor at end, active at start of the expanded range.
        let expanded = tree.parent?.range
        XCTAssertEqual(feature.currentSelection?.anchor, expanded?.endPosition)
        XCTAssertEqual(feature.currentSelection?.activePosition, expanded?.startPosition)
    }

    func testExpandAtRootIsDropped() {
        let feature = MonaSmartSelectFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)

        // Expand twice to reach the root.
        _ = feature.expandSelection(gateway: gateway)
        _ = feature.expandSelection(gateway: gateway)
        XCTAssertEqual(feature.currentRange, tree.parent?.parent?.range)

        // A third expand is at the root → dropped.
        let outcome = feature.expandSelection(gateway: gateway)
        if case .dropped = outcome {
            // expected
        } else {
            XCTFail("expected dropped at root, got \(outcome)")
        }
    }

    func testShrinkSelectionCommitsInnerRangeThroughGateway() {
        let feature = MonaSmartSelectFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)
        _ = feature.expandSelection(gateway: gateway) // now at parent
        XCTAssertEqual(feature.currentRange, tree.parent?.range)

        let outcome = feature.shrinkSelection(gateway: gateway)
        if case .applied = outcome {
            // expected: the shrunk selection is committed.
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
        // Back to the inner range.
        XCTAssertEqual(feature.currentRange, tree.range)
    }

    func testShrinkRetainsBackwardOrientation() {
        let feature = MonaSmartSelectFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .backward)
        _ = feature.expandSelection(gateway: gateway) // now at parent (backward)
        _ = feature.shrinkSelection(gateway: gateway) // back to inner (backward)

        // Backward orientation retained across expand + shrink.
        XCTAssertEqual(feature.currentSelection?.anchor, tree.range.endPosition)
        XCTAssertEqual(feature.currentSelection?.activePosition, tree.range.startPosition)
    }

    func testShrinkAtInnermostIsDropped() {
        let feature = MonaSmartSelectFeature()
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)

        // No expansion yet — shrink at the innermost is dropped.
        let outcome = feature.shrinkSelection(gateway: gateway)
        if case .dropped = outcome {
            // expected
        } else {
            XCTFail("expected dropped at innermost, got \(outcome)")
        }
    }

    func testRetainOrientationBuildsForwardSelection() {
        let feature = MonaSmartSelectFeature()
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 10)
        )
        let selection = feature.retainOrientation(range, orientation: .forward)
        XCTAssertEqual(selection.anchor, range.startPosition)
        XCTAssertEqual(selection.activePosition, range.endPosition)
    }

    func testRetainOrientationBuildsBackwardSelection() {
        let feature = MonaSmartSelectFeature()
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 10)
        )
        let selection = feature.retainOrientation(range, orientation: .backward)
        XCTAssertEqual(selection.anchor, range.endPosition)
        XCTAssertEqual(selection.activePosition, range.startPosition)
    }

    func testBeginSessionIsNoOpAfterDispose() {
        let feature = MonaSmartSelectFeature()
        feature.dispose()
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)
        XCTAssertNil(feature.currentRange)
        XCTAssertNil(feature.currentSelection)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaSmartSelectFeature.featureId, "smartSelect")
        XCTAssertTrue(features.contains("smartSelect"))

        XCTAssertEqual(MonaSmartSelectFeature.declaredActionIds, [
            "editor.action.smartSelect.expand",
            "editor.action.smartSelect.shrink"
        ])
        for id in MonaSmartSelectFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSmartSelectFeature.declaredCommandIds, [
            "editor.action.smartSelect.expand",
            "editor.action.smartSelect.grow",
            "editor.action.smartSelect.shrink"
        ])
        for id in MonaSmartSelectFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaSmartSelectFeature.declaredContributionIds, [
            "editor.contrib.smartSelectController"
        ])
        for id in MonaSmartSelectFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaSmartSelectFeature.declaredKeybindingCommands, [
            "editor.action.smartSelect.expand",
            "editor.action.smartSelect.shrink"
        ])
        let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaSmartSelectFeature.declaredKeybindingCommands {
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaSmartSelectFeature.declaredOptionIds, [
            "smartSelect"
        ])
        for id in MonaSmartSelectFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaSmartSelectFeature.declaredMenuIds, [
            "MenubarSelectionMenu"
        ])
        for id in MonaSmartSelectFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaSmartSelectFeature()
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)
        let ticket = gate.captureTicket()

        var received: MonaSmartSelectSelectionRange?
        let accepted = feature.publishSmartSelect(
            tree,
            executor: executor,
            ticket: ticket
        ) { delivered in
            received = delivered
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.range, tree.range)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaSmartSelectFeature()
        var fired: [MonaSmartSelectEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .forward)
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, begin / expand / shrink are no-ops and fire no events.
        let countBefore = fired.count
        feature.beginSession(selectionRanges: tree, orientation: .forward)
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        _ = feature.expandSelection(gateway: gateway)
        _ = feature.shrinkSelection(gateway: gateway)
        XCTAssertEqual(fired.count, countBefore)
        XCTAssertNil(feature.currentRange)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaSmartSelectFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaSmartSelectFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels.first, "Expand Selection")
        XCTAssertEqual(enLabels.last, "Shrink Selection")

        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertEqual(pseudoLabels.count, MonaSmartSelectFeature.declaredActionIds.count)
        XCTAssertTrue(pseudoLabels.first?.hasPrefix("\u{FF3B}") ?? false)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaSmartSelectFeature()
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
        let feature = MonaSmartSelectFeature()
        let model = makeModel()

        let featureLive = features.contains(MonaSmartSelectFeature.featureId)
        let actionCount = MonaSmartSelectFeature.declaredActionIds.count
        let commandCount = MonaSmartSelectFeature.declaredCommandIds.count
        let contribCount = MonaSmartSelectFeature.declaredContributionIds.count
        let kbCount = MonaSmartSelectFeature.declaredKeybindingCommands.count
        let optionCount = MonaSmartSelectFeature.declaredOptionIds.count
        let menuCount = MonaSmartSelectFeature.declaredMenuIds.count

        let slicePass = MonaSmartSelectFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaSmartSelectFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaSmartSelectFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaSmartSelectFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaSmartSelectFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaSmartSelectFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        let tree = sampleTree()
        feature.beginSession(selectionRanges: tree, orientation: .backward)

        // Expand mutates the selection through the gateway, retaining backward orientation.
        var mutation = false
        let gateway = MonaTransactionGateway(model: model)
        var orientationRetained = false
        let outcome = feature.expandSelection(gateway: gateway)
        if case .applied = outcome,
           feature.currentRange == tree.parent?.range,
           feature.currentSelection?.anchor == tree.parent?.range.endPosition,
           feature.currentSelection?.activePosition == tree.parent?.range.startPosition {
            mutation = true
            orientationRetained = true
        }

        // Expand again to the root, then shrink back (orientation retained).
        _ = feature.expandSelection(gateway: gateway)
        let shrinkOutcome = feature.shrinkSelection(gateway: gateway)
        var shrinkPass = false
        if case .applied = shrinkOutcome,
           feature.currentRange == tree.parent?.range,
           feature.currentSelection?.anchor == tree.parent?.range.endPosition {
            shrinkPass = true
        }

        // Shrink at root-of-history after returning to inner is dropped.
        _ = feature.shrinkSelection(gateway: gateway) // back to inner
        let innerShrink = feature.shrinkSelection(gateway: gateway)
        var shrinkDroppedAtInnermost = false
        if case .dropped = innerShrink {
            shrinkDroppedAtInnermost = true
        }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishSmartSelect(
            tree,
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("SMARTSELECT feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(orientationRetained)
        XCTAssertTrue(shrinkPass)
        XCTAssertTrue(shrinkDroppedAtInnermost)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
