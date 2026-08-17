// MonaDiffEditorFeatureTests.swift
//
// P05-T112 — Implement retained feature diffEditor.
//
// Verifies the diffEditor feature across its three implementation operations:
//   1. Feature-specific behavior: register diff-editor commands and
//      contributions over the Phase 07 diff interfaces (the diff-editor
//      command slice is registered against a diff-editor instance id; diff
//      construction itself stays behind the Phase 07 adapter — this feature
//      registers the slice, it does NOT implement diff logic). The
//      `diffEditor.revert` command routes its revert edit through
//      `MonaTransactionGateway`.
//   2. The exact feature identity `diffEditor` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     DIFFEDITOR feature=live actions=0 commands=12 contributions=0 keybindings=3 options=1 menus=2 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaDiffEditorFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "hello\nworld") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/diffeditor-\(UUID().uuidString)")
        )
    }

    private func makeInstance() -> MonaDiffEditorInstance {
        return MonaDiffEditorInstance(
            instanceId: "diff-\(UUID().uuidString)",
            originalModelUri: MonaURI(scheme: "inmemory", path: "/diff-original"),
            modifiedModelUri: MonaURI(scheme: "inmemory", path: "/diff-modified")
        )
    }

    // MARK: - 1. Feature-specific behavior: register commands over the Phase 07 slots

    func testRegisterDiffEditorCommandsRetainsDeclaredSliceByInstance() {
        let feature = MonaDiffEditorFeature()
        let instance = makeInstance()

        let registered = feature.registerDiffEditorCommands(for: instance)

        XCTAssertEqual(registered, MonaDiffEditorFeature.declaredCommandIds)
        XCTAssertEqual(feature.registeredCommandCount(for: instance), MonaDiffEditorFeature.declaredCommandIds.count)
    }

    func testRegisterDiffEditorCommandsForDistinctInstancesIsIndependent() {
        let feature = MonaDiffEditorFeature()
        let a = makeInstance()
        let b = makeInstance()

        _ = feature.registerDiffEditorCommands(for: a)
        XCTAssertEqual(feature.registeredCommandCount(for: a), MonaDiffEditorFeature.declaredCommandIds.count)
        XCTAssertEqual(feature.registeredCommandCount(for: b), 0)

        _ = feature.registerDiffEditorCommands(for: b)
        XCTAssertEqual(feature.registeredCommandCount(for: b), MonaDiffEditorFeature.declaredCommandIds.count)
    }

    func testRevertCommandRoutesEditThroughTransactionGateway() {
        let feature = MonaDiffEditorFeature()
        let instance = makeInstance()
        _ = feature.registerDiffEditorCommands(for: instance)
        let model = makeModel("hello world")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.executeDiffEditorCommand(
            "diffEditor.revert",
            for: instance,
            gateway: gateway,
            revertEdit: (
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 6)
                ),
                text: "HELLO"
            )
        )

        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "HELLO world")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testNonMutatingCommandsAreAcknowledgedWithoutMutation() {
        let feature = MonaDiffEditorFeature()
        let instance = makeInstance()
        _ = feature.registerDiffEditorCommands(for: instance)
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)

        // collapseAllUnchangedRegions / switchSide / toggle* carry no model
        // mutation; their diff logic is behind the Phase 07 diff engine. They
        // are acknowledged (.applied, no edit prepared) without mutating text.
        for commandId in [
            "diffEditor.collapseAllUnchangedRegions",
            "diffEditor.switchSide",
            "diffEditor.toggleCollapseUnchangedRegions",
            "editor.action.accessibleDiffViewer.next"
        ] {
            let outcome = feature.executeDiffEditorCommand(
                commandId,
                for: instance,
                gateway: gateway,
                revertEdit: nil
            )
            switch outcome {
            case .applied, .reconciled:
                XCTAssertEqual(model.getValue(), "hello")
            default:
                XCTFail("expected applied/reconciled for \(commandId), got \(outcome)")
            }
        }
    }

    func testExecuteUnknownCommandIsDropped() {
        let feature = MonaDiffEditorFeature()
        let instance = makeInstance()
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)

        let outcome = feature.executeDiffEditorCommand(
            "diffEditor.doesNotExist",
            for: instance,
            gateway: gateway,
            revertEdit: nil
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "hello")
        } else {
            XCTFail("expected dropped, got \(outcome)")
        }
    }

    func testReleaseDiffEditorCommandsDropsSliceForInstance() {
        let feature = MonaDiffEditorFeature()
        let instance = makeInstance()
        _ = feature.registerDiffEditorCommands(for: instance)
        XCTAssertEqual(feature.registeredCommandCount(for: instance), MonaDiffEditorFeature.declaredCommandIds.count)

        let released = feature.releaseDiffEditorCommands(for: instance)
        XCTAssertEqual(released, MonaDiffEditorFeature.declaredCommandIds.count)
        XCTAssertEqual(feature.registeredCommandCount(for: instance), 0)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let contributions = MonaContributionRegistry()

        XCTAssertEqual(MonaDiffEditorFeature.featureId, "diffEditor")
        XCTAssertTrue(features.contains("diffEditor"))

        // diffEditor declares no labeled actions.
        XCTAssertEqual(MonaDiffEditorFeature.declaredActionIds, [])

        let commandIds = MonaDiffEditorFeature.declaredCommandIds
        XCTAssertEqual(commandIds, [
            "diffEditor.collapseAllUnchangedRegions",
            "diffEditor.exitCompareMove",
            "diffEditor.revert",
            "diffEditor.showAllUnchangedRegions",
            "diffEditor.switchSide",
            "diffEditor.toggleCollapseUnchangedRegions",
            "diffEditor.toggleShowMovedCodeBlocks",
            "diffEditor.toggleUseInlineViewWhenSpaceIsLimited",
            "editor.action.accessibleDiffViewer.next",
            "editor.action.accessibleDiffViewer.prev",
            "editor.action.diffReview.next",
            "editor.action.diffReview.prev"
        ])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // diffContributions is 0 — diffEditor owns no contribution registrations.
        XCTAssertEqual(MonaDiffEditorFeature.declaredContributionIds, [])
        for id in MonaDiffEditorFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaDiffEditorFeature.declaredKeybindingCommands, [
            "editor.action.accessibleDiffViewer.next",
            "editor.action.accessibleDiffViewer.prev",
            "diffEditor.exitCompareMove"
        ])

        XCTAssertEqual(MonaDiffEditorFeature.declaredOptionIds, ["inDiffEditor"])

        XCTAssertEqual(MonaDiffEditorFeature.declaredMenuIds, [
            "DiffEditorHunkToolbar",
            "DiffEditorSelectionToolbar"
        ])
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaDiffEditorFeature()
        let instance = makeInstance()
        let ticket = gate.captureTicket()

        var received: MonaDiffEditorEvent?
        let accepted = feature.publishDiffEditorEvent(
            MonaDiffEditorEvent(instanceId: instance.instanceId, registeredCommands: MonaDiffEditorFeature.declaredCommandIds),
            executor: executor,
            ticket: ticket
        ) { event in received = event }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.instanceId, instance.instanceId)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaDiffEditorFeature()
        var fired: [MonaDiffEditorEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, register / release / execute are no-ops.
        let instance = makeInstance()
        let registered = feature.registerDiffEditorCommands(for: instance)
        XCTAssertTrue(registered.isEmpty)
        XCTAssertEqual(feature.registeredCommandCount(for: instance), 0)
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.executeDiffEditorCommand(
            "diffEditor.revert",
            for: instance,
            gateway: gateway,
            revertEdit: (
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 2)
                ),
                text: "X"
            )
        )
        if case .dropped = outcome {
            XCTAssertEqual(model.getValue(), "hello")
        } else {
            XCTFail("expected dropped after disposal, got \(outcome)")
        }
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaDiffEditorFeature()
        // diffEditor declares no actions; action labels are empty.
        XCTAssertEqual(feature.localizedActionLabels(profile: .default).count, 0)
        // Command labels route through MonaLocalization (id-as-label fallback).
        let enCommandLabels = feature.localizedCommandLabels(profile: .default)
        XCTAssertEqual(enCommandLabels.count, MonaDiffEditorFeature.declaredCommandIds.count)
        XCTAssertEqual(enCommandLabels.first, "diffEditor.collapseAllUnchangedRegions")
        let pseudoCommandLabels = feature.localizedCommandLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoCommandLabels.allSatisfy { $0.hasPrefix("\u{FF3B}") && $0.hasSuffix("\u{FF3D}") })
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaDiffEditorFeature()
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
        let feature = MonaDiffEditorFeature()

        let featureLive = features.contains(MonaDiffEditorFeature.featureId)
        let actionCount = MonaDiffEditorFeature.declaredActionIds.count
        let commandCount = MonaDiffEditorFeature.declaredCommandIds.count
        let contribCount = MonaDiffEditorFeature.declaredContributionIds.count
        let kbCount = MonaDiffEditorFeature.declaredKeybindingCommands.count
        let optionCount = MonaDiffEditorFeature.declaredOptionIds.count
        let menuCount = MonaDiffEditorFeature.declaredMenuIds.count

        let slicePass = MonaDiffEditorFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaDiffEditorFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaDiffEditorFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaDiffEditorFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaDiffEditorFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaDiffEditorFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: register the diff-editor command slice over the Phase 07
        // slot, then invoke `diffEditor.revert` through the transaction gateway.
        let instance = makeInstance()
        let registered = feature.registerDiffEditorCommands(for: instance)
        let sliceMatches = (registered == MonaDiffEditorFeature.declaredCommandIds)
        let countMatches = (feature.registeredCommandCount(for: instance) == commandCount)
        let registrationPass = sliceMatches && countMatches

        let model = makeModel("hello world")
        let gateway = MonaTransactionGateway(model: model)
        let outcome = feature.executeDiffEditorCommand(
            "diffEditor.revert",
            for: instance,
            gateway: gateway,
            revertEdit: (
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 6)
                ),
                text: "HELLO"
            )
        )
        let mutation: Bool
        if case .applied = outcome, model.getValue() == "HELLO world" {
            mutation = true
        } else {
            mutation = false
        }

        // Release the registered slice for the disposed diff-editor instance.
        let released = feature.releaseDiffEditorCommands(for: instance)
        let releasePass = released == commandCount && feature.registeredCommandCount(for: instance) == 0

        // Async publication.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishDiffEditorEvent(
            MonaDiffEditorEvent(instanceId: instance.instanceId, registeredCommands: []),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let actionLabelCount = feature.localizedActionLabels(profile: .default).count
        let commandLabelCount = feature.localizedCommandLabels(profile: .default).count
        let localizationPass = (actionLabelCount == actionCount) && (commandLabelCount == commandCount)
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("DIFFEDITOR feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(registrationPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(releasePass)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
