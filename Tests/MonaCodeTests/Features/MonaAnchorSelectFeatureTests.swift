// MonaAnchorSelectFeatureTests.swift
//
// P05-T100 — Implement retained feature anchorSelect.
//
// Verifies the anchorSelect feature across its three implementation operations:
//   1. Feature-specific behavior: extend selections from their anchors with
//      exact cursor ordering.
//   2. The exact feature identity `anchorSelect` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testAnchorSelectContractLeaf` prints the contract line:
//     ANCHORSELECT feature=live actions=4 commands=4 contributions=1 keybindings=3 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaAnchorSelectFeatureTests: XCTestCase {

    // MARK: - 1. Feature-specific behavior: extend selections from anchors

    func testExtendSelectionsFromAnchorsPreservesAnchorAndSetsCursor() {
        let feature = MonaAnchorSelectFeature()
        let anchors = [
            MonaPosition(line: 1, column: 5),
            MonaPosition(line: 3, column: 2)
        ]
        let cursors = [
            MonaPosition(line: 1, column: 10),
            MonaPosition(line: 2, column: 1)
        ]
        let selections = feature.extendSelections(fromAnchors: anchors, toCursors: cursors)
        XCTAssertEqual(selections.count, 2)
        // Anchor preserved verbatim; active position is the cursor.
        XCTAssertEqual(selections[0].anchor, MonaPosition(line: 1, column: 5))
        XCTAssertEqual(selections[0].activePosition, MonaPosition(line: 1, column: 10))
        XCTAssertEqual(selections[1].anchor, MonaPosition(line: 3, column: 2))
        XCTAssertEqual(selections[1].activePosition, MonaPosition(line: 2, column: 1))
    }

    func testExtendSelectionsDerivesExactCursorOrdering() {
        let feature = MonaAnchorSelectFeature()
        // Forward: cursor after anchor → forward (LTR).
        let forward = feature.selection(anchor: MonaPosition(line: 1, column: 1),
                                        cursor: MonaPosition(line: 1, column: 8))
        XCTAssertEqual(forward.orientation, .forward)
        XCTAssertEqual(forward.startPosition, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(forward.endPosition, MonaPosition(line: 1, column: 8))
        // Backward: cursor before anchor → backward (RTL).
        let backward = feature.selection(anchor: MonaPosition(line: 1, column: 8),
                                         cursor: MonaPosition(line: 1, column: 1))
        XCTAssertEqual(backward.orientation, .backward)
        // Backward keeps the anchor at the END (normalized) position.
        XCTAssertEqual(backward.anchor, backward.endPosition)
        XCTAssertEqual(backward.activePosition, backward.startPosition)
        // Collapsed: cursor == anchor → forward.
        let collapsed = feature.selection(anchor: MonaPosition(line: 2, column: 3),
                                           cursor: MonaPosition(line: 2, column: 3))
        XCTAssertEqual(collapsed.orientation, .forward)
        XCTAssertTrue(collapsed.anchor == collapsed.activePosition)
    }

    func testExtendSelectionsMismatchedCountsYieldsEmpty() {
        let feature = MonaAnchorSelectFeature()
        let selections = feature.extendSelections(
            fromAnchors: [MonaPosition(line: 1, column: 1)],
            toCursors: []
        )
        XCTAssertTrue(selections.isEmpty)
    }

    func testSelectionAnchorIsRecordedAtPosition() {
        let feature = MonaAnchorSelectFeature()
        let pos = MonaPosition(line: 4, column: 6)
        let anchor = feature.setSelectionAnchor(at: pos)
        XCTAssertEqual(anchor, pos)
        XCTAssertTrue(feature.hasSelectionAnchor)
        feature.cancelSelectionAnchor()
        XCTAssertFalse(feature.hasSelectionAnchor)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()

        // The feature identity is live.
        XCTAssertEqual(MonaAnchorSelectFeature.featureId, "anchorSelect")
        XCTAssertTrue(features.contains("anchorSelect"))

        // Declared actions (no rename / coalesce).
        let actionIds = MonaAnchorSelectFeature.declaredActionIds
        XCTAssertEqual(actionIds, [
            "editor.action.setSelectionAnchor",
            "editor.action.goToSelectionAnchor",
            "editor.action.selectFromAnchorToCursor",
            "editor.action.cancelSelectionAnchor"
        ])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // Declared contribution.
        let contributionIds = MonaAnchorSelectFeature.declaredContributionIds
        XCTAssertEqual(contributionIds, ["editor.contrib.selectionAnchorController"])
        for id in contributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        // Declared keybindings reference commands that have builtin keybindings.
        let kbCommands = MonaAnchorSelectFeature.declaredKeybindingCommands
        let keybindingCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(keybindingCommands.contains(id), "missing keybinding for \(id)")
        }
        // anchorSelect declares no options and no menus.
        XCTAssertTrue(MonaAnchorSelectFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaAnchorSelectFeature.declaredMenuIds.isEmpty)
    }

    // MARK: - 3. Routing through shared gateways

    func testModelMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "hello\nworld",
            uri: MonaURI(scheme: "inmemory", path: "/anchor")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaAnchorSelectFeature()
        let anchors = [MonaPosition(line: 1, column: 1)]
        let cursors = [MonaPosition(line: 1, column: 5)]
        let committed = feature.commitSelectionExtension(
            gateway: gateway,
            fromAnchors: anchors,
            toCursors: cursors
        )
        // The selection-extension transaction is committed as one unit through
        // the gateway; the gateway records the committed selections.
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(committed[0].activePosition, MonaPosition(line: 1, column: 5))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/anchor-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaAnchorSelectFeature()
        let ticket = gate.captureTicket()

        var received: [MonaSelection] = []
        let accepted = feature.publishSelections(
            [MonaSelection(anchor: MonaPosition(line: 1, column: 1),
                           activePosition: MonaPosition(line: 1, column: 3))],
            executor: executor,
            ticket: ticket
        ) { selections in
            received = selections
        }
        XCTAssertTrue(accepted)
        // Not delivered until the microtask queue is drained.
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaAnchorSelectFeature()
        var fired: [MonaAnchorSelectEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        feature.setSelectionAnchor(at: MonaPosition(line: 1, column: 1))
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        // After disposal, firing is a no-op (listeners dropped).
        feature.setSelectionAnchor(at: MonaPosition(line: 2, column: 2))
        XCTAssertEqual(fired.count, 1)
        // Idempotent disposal.
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaAnchorSelectFeature()
        // English profile: labels pass through the format rule unchanged.
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaAnchorSelectFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Set Selection Anchor")
        // Pseudo profile: the English fallback is wrapped in fullwidth brackets.
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaAnchorSelectFeature()
        // anchorSelect needs no tokenization; it degrades to plain text.
        XCTAssertTrue(feature.isPlainTextDegraded)
        let language = feature.degradedLanguage
        XCTAssertEqual(language.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(language.hasTokenization)
        XCTAssertFalse(language.hasGrammar)
    }

    // MARK: - Contract leaf

    func testAnchorSelectContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let feature = MonaAnchorSelectFeature()

        let featureLive = features.contains(MonaAnchorSelectFeature.featureId)
        let actionCount = MonaAnchorSelectFeature.declaredActionIds.count
        let commandCount = MonaAnchorSelectFeature.declaredCommandIds.count
        let contribCount = MonaAnchorSelectFeature.declaredContributionIds.count
        let kbCount = MonaAnchorSelectFeature.declaredKeybindingCommands.count
        let optionCount = MonaAnchorSelectFeature.declaredOptionIds.count
        let menuCount = MonaAnchorSelectFeature.declaredMenuIds.count

        let slicePass = MonaAnchorSelectFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaAnchorSelectFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaAnchorSelectFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }

        // Mutation + async + disposal + localization + plaintext routing.
        let model = MonaCodeModel(text: "x", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitSelectionExtension(
            gateway: gateway,
            fromAnchors: [MonaPosition(line: 1, column: 1)],
            toCursors: [MonaPosition(line: 1, column: 1)]
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishSelections([], executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        // Empty selections still publish (the synchronous value [] is enqueued).
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("ANCHORSELECT feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
