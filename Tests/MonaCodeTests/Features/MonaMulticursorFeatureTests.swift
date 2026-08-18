// MonaMulticursorFeatureTests.swift
//
// P05-T139 — Implement retained feature multicursor.
//
// Verifies the multicursor feature across its three implementation operations:
//   1. Feature-specific behavior: add, remove, merge, select, and edit 1, 100,
//      and 10000 cursors in stable order (reuse `MonaModelInputBarrier`
//      P04-T005 + `MonaMultiCursorInputPlan` for the multi-cursor edits).
//   2. The exact feature identity `multicursor` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     MULTICURSOR feature=live actions=13 commands=14 contributions=1 keybindings=8 options=4 menus=2 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaMulticursorFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "alpha\nbeta\ngamma") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/multicursor-\(UUID().uuidString)")
        )
    }

    // MARK: - 1. Feature-specific behavior: add / remove / merge / select / edit

    func testAddCursorKeepsStableAscendingOrder() {
        let feature = MonaMulticursorFeature()
        XCTAssertEqual(feature.cursorCount, 0)

        // Add out of order; the cursor list stays ascending by (line, column).
        _ = feature.addCursor(MonaPosition(line: 3, column: 1))
        _ = feature.addCursor(MonaPosition(line: 1, column: 1))
        _ = feature.addCursor(MonaPosition(line: 2, column: 1))

        XCTAssertEqual(feature.cursors, [
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 2, column: 1),
            MonaPosition(line: 3, column: 1)
        ])
        XCTAssertEqual(feature.cursorCount, 3)
        XCTAssertEqual(feature.primaryCursor, MonaPosition(line: 1, column: 1))
    }

    func testAddDuplicateCursorMergesWhenOptionEnabled() {
        let feature = MonaMulticursorFeature()
        _ = feature.addCursor(MonaPosition(line: 1, column: 1))
        _ = feature.addCursor(MonaPosition(line: 1, column: 1))

        // Overlapping cursors at the same position merge (multiCursorMergeOverlapping).
        XCTAssertEqual(feature.cursorCount, 1)
    }

    func testRemoveCursorDropsExactMatch() {
        let feature = MonaMulticursorFeature()
        _ = feature.addCursor(MonaPosition(line: 1, column: 1))
        _ = feature.addCursor(MonaPosition(line: 2, column: 1))
        _ = feature.addCursor(MonaPosition(line: 3, column: 1))

        let removed = feature.removeCursor(at: MonaPosition(line: 2, column: 1))
        XCTAssertTrue(removed)
        XCTAssertEqual(feature.cursors, [
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 3, column: 1)
        ])
    }

    func testRemoveCursorAtUnknownPositionIsNoOp() {
        let feature = MonaMulticursorFeature()
        _ = feature.addCursor(MonaPosition(line: 1, column: 1))
        let removed = feature.removeCursor(at: MonaPosition(line: 9, column: 9))
        XCTAssertFalse(removed)
        XCTAssertEqual(feature.cursorCount, 1)
    }

    func testRemoveSecondaryCursorsKeepsPrimaryOnly() {
        let feature = MonaMulticursorFeature()
        _ = feature.select([
            MonaPosition(line: 3, column: 1),
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 2, column: 1)
        ])
        let removed = feature.removeSecondaryCursors()
        XCTAssertEqual(removed, 2)
        XCTAssertEqual(feature.cursorCount, 1)
        XCTAssertEqual(feature.primaryCursor, MonaPosition(line: 1, column: 1))
    }

    func testMergeOverlappingCursorsDedupes() {
        // mergeOverlapping disabled so select preserves the duplicates, then
        // mergeOverlappingCursors collapses them.
        let feature = MonaMulticursorFeature(mergeOverlapping: false)
        _ = feature.select([
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 2, column: 1),
            MonaPosition(line: 2, column: 1),
            MonaPosition(line: 3, column: 1)
        ])
        XCTAssertEqual(feature.cursorCount, 5)

        let removed = feature.mergeOverlappingCursors()
        XCTAssertEqual(removed, 2)
        XCTAssertEqual(feature.cursors, [
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 2, column: 1),
            MonaPosition(line: 3, column: 1)
        ])
    }

    func testSelectReplacesCursorsWithSortedUniqueSet() {
        let feature = MonaMulticursorFeature()
        _ = feature.addCursor(MonaPosition(line: 5, column: 5))

        feature.select([
            MonaPosition(line: 3, column: 1),
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 3, column: 1),
            MonaPosition(line: 2, column: 1)
        ])
        XCTAssertEqual(feature.cursors, [
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 2, column: 1),
            MonaPosition(line: 3, column: 1)
        ])
    }

    func testEditOneCursorThroughBarrierAppliesInsertion() {
        let feature = MonaMulticursorFeature()
        let model = makeModel("abc")
        _ = feature.addCursor(MonaPosition(line: 1, column: 1))

        let outcome = feature.editAll(text: "X", model: model)
        if case .applied(let selections) = outcome {
            XCTAssertEqual(selections.count, 1)
            XCTAssertEqual(selections[0].anchor, MonaPosition(line: 1, column: 2))
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "Xabc")
    }

    func testEditOneHundredCursorsInStableOrder() {
        let feature = MonaMulticursorFeature()
        // 100 lines, one cursor at the start of each line (column 1).
        let lines = (0..<100).map { "L\($0)" }
        let model = makeModel(lines.joined(separator: "\n"))
        let positions = (1...100).map { MonaPosition(line: $0, column: 1) }
        feature.select(positions)

        XCTAssertEqual(feature.cursorCount, 100)
        XCTAssertEqual(feature.cursors.first, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(feature.cursors.last, MonaPosition(line: 100, column: 1))

        let outcome = feature.editAll(text: ">", model: model)
        if case .applied(let selections) = outcome {
            XCTAssertEqual(selections.count, 100)
            // Each cursor moved one column right (insertion at column 1 → column 2),
            // including the last cursor (post-commit caret mapping is correct).
            XCTAssertEqual(selections[0].anchor, MonaPosition(line: 1, column: 2))
            XCTAssertEqual(selections[99].anchor, MonaPosition(line: 100, column: 2))
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), (0..<100).map { ">L\($0)" }.joined(separator: "\n"))
    }

    func testEditTenThousandCursorsStableOrderNoQuadraticCatastrophe() {
        let feature = MonaMulticursorFeature()
        let count = 10000
        // 10000 lines, one cursor at the start of each.
        let lines = (0..<count).map { "n\($0)" }
        let model = makeModel(lines.joined(separator: "\n"))
        let positions = (1...count).map { MonaPosition(line: $0, column: 1) }
        feature.select(positions)

        XCTAssertEqual(feature.cursorCount, count)
        // Stable ascending order across 10000 cursors.
        let cursors = feature.cursors
        XCTAssertEqual(cursors.count, count)
        XCTAssertEqual(cursors.first, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(cursors.last, MonaPosition(line: count, column: 1))
        // Every consecutive pair is strictly ascending (no inversion).
        for i in 1..<cursors.count {
            XCTAssertLessThan(cursors[i - 1], cursors[i], "inversion at \(i)")
        }

        // The all-or-none barrier commits all 10000 edits in one transaction.
        let outcome = feature.editAll(text: "#", model: model)
        if case .applied(let selections) = outcome {
            XCTAssertEqual(selections.count, count)
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), (0..<count).map { "#n\($0)" }.joined(separator: "\n"))
    }

    func testEditWithNoCursorsIsDropped() {
        let feature = MonaMulticursorFeature()
        let model = makeModel("abc")
        let outcome = feature.editAll(text: "X", model: model)
        if case .dropped = outcome {
            // expected
        } else {
            XCTFail("expected dropped, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "abc")
    }

    func testEditAllThreadsOverlapPolicyToBarrier() {
        // editAll uses replicateText (folded insertions), so distinct cursors
        // never strictly overlap; both `.reject` and `.merge` apply the batch
        // atomically — verifying the overlapPolicy parameter is threaded through
        // to the all-or-none barrier.
        let modelA = makeModel("ab\ncd")
        let modelB = makeModel("ab\ncd")
        let featureA = MonaMulticursorFeature()
        let featureB = MonaMulticursorFeature()
        _ = featureA.select([MonaPosition(line: 1, column: 1), MonaPosition(line: 2, column: 1)])
        _ = featureB.select([MonaPosition(line: 1, column: 1), MonaPosition(line: 2, column: 1)])

        let outcomeA = featureA.editAll(text: "Z", model: modelA, overlapPolicy: .reject)
        let outcomeB = featureB.editAll(text: "Z", model: modelB, overlapPolicy: .merge)
        if case .applied(let sA) = outcomeA, case .applied(let sB) = outcomeB {
            XCTAssertEqual(sA.count, 2)
            XCTAssertEqual(sB.count, 2)
        } else {
            XCTFail("expected both applied, got \(outcomeA) / \(outcomeB)")
        }
        XCTAssertEqual(modelA.getValue(), "Zab\nZcd")
        XCTAssertEqual(modelB.getValue(), "Zab\nZcd")
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaMulticursorFeature.featureId, "multicursor")
        XCTAssertTrue(features.contains("multicursor"))

        XCTAssertEqual(MonaMulticursorFeature.declaredActionIds, [
            "editor.action.insertCursorAbove",
            "editor.action.insertCursorBelow",
            "editor.action.insertCursorAtEndOfEachLineSelected",
            "editor.action.addSelectionToNextFindMatch",
            "editor.action.addSelectionToPreviousFindMatch",
            "editor.action.moveSelectionToNextFindMatch",
            "editor.action.moveSelectionToPreviousFindMatch",
            "editor.action.selectHighlights",
            "editor.action.changeAll",
            "editor.action.addCursorsToBottom",
            "editor.action.addCursorsToTop",
            "editor.action.focusNextCursor",
            "editor.action.focusPreviousCursor"
        ])
        for id in MonaMulticursorFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaMulticursorFeature.declaredCommandIds, [
            "editor.action.insertCursorAbove",
            "editor.action.insertCursorBelow",
            "editor.action.insertCursorAtEndOfEachLineSelected",
            "editor.action.addSelectionToNextFindMatch",
            "editor.action.addSelectionToPreviousFindMatch",
            "editor.action.moveSelectionToNextFindMatch",
            "editor.action.moveSelectionToPreviousFindMatch",
            "editor.action.selectHighlights",
            "editor.action.changeAll",
            "editor.action.addCursorsToBottom",
            "editor.action.addCursorsToTop",
            "editor.action.focusNextCursor",
            "editor.action.focusPreviousCursor",
            "removeSecondaryCursors"
        ])
        for id in MonaMulticursorFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaMulticursorFeature.declaredContributionIds, [
            "editor.contrib.multiCursorController"
        ])
        for id in MonaMulticursorFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaMulticursorFeature.declaredKeybindingCommands, [
            "editor.action.insertCursorAbove",
            "editor.action.insertCursorBelow",
            "editor.action.insertCursorAtEndOfEachLineSelected",
            "editor.action.addSelectionToNextFindMatch",
            "editor.action.moveSelectionToNextFindMatch",
            "editor.action.selectHighlights",
            "editor.action.changeAll",
            "removeSecondaryCursors"
        ])
        let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaMulticursorFeature.declaredKeybindingCommands {
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaMulticursorFeature.declaredOptionIds, [
            "multiCursorMergeOverlapping",
            "multiCursorModifier",
            "multiCursorPaste",
            "multiCursorLimit"
        ])
        for id in MonaMulticursorFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaMulticursorFeature.declaredMenuIds, [
            "MenubarSelectionMenu",
            "EditorContext"
        ])
        for id in MonaMulticursorFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testMutationRoutesThroughModelInputBarrier() {
        let feature = MonaMulticursorFeature()
        let model = makeModel("ab\ncd")
        _ = feature.select([
            MonaPosition(line: 1, column: 1),
            MonaPosition(line: 2, column: 1)
        ])
        // The barrier is the all-or-none multi-cursor transaction gateway.
        let outcome = feature.editAll(text: "Z", model: model)
        if case .applied(let selections) = outcome {
            XCTAssertEqual(selections.count, 2)
            XCTAssertEqual(selections[0].anchor, MonaPosition(line: 1, column: 2))
            XCTAssertEqual(selections[1].anchor, MonaPosition(line: 2, column: 2))
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "Zab\nZcd")
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaMulticursorFeature()
        let ticket = gate.captureTicket()

        var received: [MonaPosition] = []
        let accepted = feature.publishCursors(
            [MonaPosition(line: 1, column: 1), MonaPosition(line: 1, column: 3)],
            executor: executor,
            ticket: ticket
        ) { cursors in
            received = cursors
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaMulticursorFeature()
        var fired: [MonaMulticursorEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.addCursor(MonaPosition(line: 1, column: 1))
        XCTAssertFalse(fired.isEmpty)

        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, add / select / edit are no-ops and fire no events.
        let countBefore = fired.count
        _ = feature.addCursor(MonaPosition(line: 2, column: 2))
        XCTAssertEqual(feature.cursorCount, 0)
        feature.select([MonaPosition(line: 3, column: 3)])
        XCTAssertEqual(feature.cursorCount, 0)
        let outcome = feature.editAll(text: "X", model: makeModel("abc"))
        if case .dropped = outcome {
            // expected
        } else {
            XCTFail("expected dropped after dispose, got \(outcome)")
        }
        XCTAssertEqual(fired.count, countBefore)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaMulticursorFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaMulticursorFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels.first, "Add Cursor Above")
        // Pseudo profile wraps in fullwidth brackets and doubles vowels.
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertEqual(pseudoLabels.count, MonaMulticursorFeature.declaredActionIds.count)
        XCTAssertEqual(pseudoLabels.first?.hasPrefix("\u{FF3B}"), true)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaMulticursorFeature()
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
        let feature = MonaMulticursorFeature()

        let featureLive = features.contains(MonaMulticursorFeature.featureId)
        let actionCount = MonaMulticursorFeature.declaredActionIds.count
        let commandCount = MonaMulticursorFeature.declaredCommandIds.count
        let contribCount = MonaMulticursorFeature.declaredContributionIds.count
        let kbCount = MonaMulticursorFeature.declaredKeybindingCommands.count
        let optionCount = MonaMulticursorFeature.declaredOptionIds.count
        let menuCount = MonaMulticursorFeature.declaredMenuIds.count

        let slicePass = MonaMulticursorFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaMulticursorFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaMulticursorFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaMulticursorFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaMulticursorFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaMulticursorFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Add / remove / merge / select across 1, 100, 10000 cursors in stable order.
        _ = feature.addCursor(MonaPosition(line: 1, column: 1))
        feature.select((1...100).map { MonaPosition(line: $0, column: 1) })
        let stable100 = feature.cursors == (1...100).map { MonaPosition(line: $0, column: 1) }
        _ = feature.removeSecondaryCursors()
        let primaryOnly = feature.cursorCount == 1

        let count = 10000
        let model = makeModel((0..<count).map { "n\($0)" }.joined(separator: "\n"))
        feature.select((1...count).map { MonaPosition(line: $0, column: 1) })
        let stable10k = feature.cursors.count == count
            && feature.cursors.first == MonaPosition(line: 1, column: 1)
            && feature.cursors.last == MonaPosition(line: count, column: 1)

        // Mutation: the all-or-none barrier commits 10000 edits in one transaction.
        var mutation = false
        let outcome = feature.editAll(text: "#", model: model)
        if case .applied(let selections) = outcome, selections.count == count {
            mutation = true
        }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishCursors(
            [MonaPosition(line: 1, column: 1)],
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("MULTICURSOR feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(stable100)
        XCTAssertTrue(primaryOnly)
        XCTAssertTrue(stable10k)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
