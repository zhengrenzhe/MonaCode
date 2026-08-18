// MonaRenameFeatureTests.swift
//
// P05-T147 — Implement retained feature rename.
//
// Verifies the rename feature across its three implementation operations:
//   1. Feature-specific behavior: prepare rename, collect workspace edits,
//      preview failures, and apply atomically (workspace edits applied via
//      `MonaTransactionGateway` atomically — all-or-none).
//   2. The exact feature identity `rename` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     RENAME feature=live actions=1 commands=8 contributions=1 keybindings=6 options=1 menus=1 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaRenameFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "let x = 1") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/rename-\(UUID().uuidString)")
        )
    }

    private func sampleEdits() -> [MonaRenameLocation] {
        return [
            MonaRenameLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 5),
                    endPosition: MonaPosition(line: 1, column: 6)
                ),
                newText: "value"
            ),
            MonaRenameLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 9),
                    endPosition: MonaPosition(line: 1, column: 10)
                ),
                newText: "value"
            )
        ]
    }

    // MARK: - 1. Feature-specific behavior: prepare / collect / preview / apply

    func testPrepareRenameRetainsRangeAndPlaceholder() {
        let feature = MonaRenameFeature()
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 6)
        )
        let prepared = feature.prepareRename(at: range, placeholder: "x")

        XCTAssertNotNil(prepared)
        XCTAssertEqual(prepared?.range, range)
        XCTAssertEqual(prepared?.placeholder, "x")
        XCTAssertEqual(feature.currentPrepare?.placeholder, "x")
    }

    func testPrepareRenameIsNoOpAfterDispose() {
        let feature = MonaRenameFeature()
        feature.dispose()
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 2)
        )
        let prepared = feature.prepareRename(at: range, placeholder: "a")
        XCTAssertNil(prepared)
    }

    func testCollectWorkspaceEditGroupsEdits() {
        let feature = MonaRenameFeature()
        let edit = feature.collectWorkspaceEdit(sampleEdits())
        XCTAssertEqual(edit.edits.count, 2)
        XCTAssertEqual(edit.edits.first?.newText, "value")
    }

    func testCollectWorkspaceEditEmptyWhenNoEdits() {
        let feature = MonaRenameFeature()
        let edit = feature.collectWorkspaceEdit([])
        XCTAssertTrue(edit.edits.isEmpty)
    }

    func testPreviewRenameReportsNoFailuresForValidEdits() {
        let feature = MonaRenameFeature()
        let model = makeModel("let x = x")
        let edit = feature.collectWorkspaceEdit(sampleEdits())
        let preview = feature.previewRename(edit, model: model)

        XCTAssertTrue(preview.failures.isEmpty)
        XCTAssertTrue(preview.canApply)
    }

    func testPreviewRenameReportsFailureForEmptyEdits() {
        let feature = MonaRenameFeature()
        let model = makeModel()
        let edit = MonaRenameWorkspaceEdit(edits: [])
        let preview = feature.previewRename(edit, model: model)

        XCTAssertFalse(preview.failures.isEmpty)
        XCTAssertFalse(preview.canApply)
    }

    func testPreviewRenameReportsFailureForInvalidRange() {
        let feature = MonaRenameFeature()
        let model = makeModel("ab") // only 2 columns
        let edit = feature.collectWorkspaceEdit([
            MonaRenameLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 99) // out of range
                ),
                newText: "value"
            )
        ])
        let preview = feature.previewRename(edit, model: model)

        XCTAssertFalse(preview.failures.isEmpty)
        XCTAssertFalse(preview.canApply)
    }

    func testApplyRenameAppliesAllEditsAtomically() {
        let feature = MonaRenameFeature()
        let model = makeModel("let x = x") // col 5='x', col 9='x'
        let gateway = MonaTransactionGateway(model: model)
        let edit = feature.collectWorkspaceEdit(sampleEdits())

        let outcome = feature.applyRename(edit, gateway: gateway)
        if case .applied = outcome {
            XCTAssertEqual(model.getValue(), "let value = value")
        } else {
            XCTFail("expected applied, got \(outcome)")
        }
    }

    func testApplyRenameRollsBackAtomicallyWhenAnyRangeInvalid() {
        let feature = MonaRenameFeature()
        let model = makeModel("ab") // only 2 columns
        let gateway = MonaTransactionGateway(model: model)
        let edit = feature.collectWorkspaceEdit([
            MonaRenameLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 2) // valid
                ),
                newText: "z"
            ),
            MonaRenameLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 99) // INVALID
                ),
                newText: "q"
            )
        ])

        let outcome = feature.applyRename(edit, gateway: gateway)
        if case .rolledBack = outcome {
            // all-or-none: model untouched
            XCTAssertEqual(model.getValue(), "ab")
        } else {
            XCTFail("expected rolledBack, got \(outcome)")
        }
    }

    func testAcceptRenameInputAppliesAndFiresEvent() {
        let feature = MonaRenameFeature()
        let model = makeModel("let x = x")
        let gateway = MonaTransactionGateway(model: model)
        let edit = feature.collectWorkspaceEdit(sampleEdits())
        var fired: [MonaRenameEvent] = []
        _ = feature.onChange { event in fired.append(event) }

        let accepted = feature.acceptRenameInput(edit, gateway: gateway)
        XCTAssertTrue(accepted)
        XCTAssertEqual(model.getValue(), "let value = value")
        XCTAssertFalse(fired.isEmpty)
    }

    func testCancelRenameInputClearsPrepare() {
        let feature = MonaRenameFeature()
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 6)
        )
        _ = feature.prepareRename(at: range, placeholder: "x")
        XCTAssertNotNil(feature.currentPrepare)

        let cancelled = feature.cancelRenameInput()
        XCTAssertTrue(cancelled)
        XCTAssertNil(feature.currentPrepare)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let options = MonaOptionStore()
        let menus = MonaMenuRegistry()

        XCTAssertEqual(MonaRenameFeature.featureId, "rename")
        XCTAssertTrue(features.contains("rename"))

        XCTAssertEqual(MonaRenameFeature.declaredActionIds, [
            "editor.action.rename"
        ])
        for id in MonaRenameFeature.declaredActionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaRenameFeature.declaredCommandIds, [
            "editor.action.rename",
            "acceptRenameInput",
            "acceptRenameInputWithPreview",
            "cancelRenameInput",
            "focusNextRenameSuggestion",
            "focusPreviousRenameSuggestion",
            "_executeDocumentRenameProvider",
            "_executePrepareRename"
        ])
        for id in MonaRenameFeature.declaredCommandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaRenameFeature.declaredContributionIds, [
            "editor.contrib.renameController"
        ])
        for id in MonaRenameFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaRenameFeature.declaredKeybindingCommands, [
            "editor.action.rename",
            "acceptRenameInput",
            "acceptRenameInputWithPreview",
            "cancelRenameInput",
            "focusNextRenameSuggestion",
            "focusPreviousRenameSuggestion"
        ])
        let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in MonaRenameFeature.declaredKeybindingCommands {
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaRenameFeature.declaredOptionIds, [
            "renameOnType"
        ])
        for id in MonaRenameFeature.declaredOptionIds {
            XCTAssertNotNil(options.value(for: id), "missing option \(id)")
        }

        XCTAssertEqual(MonaRenameFeature.declaredMenuIds, [
            "EditorContext"
        ])
        for id in MonaRenameFeature.declaredMenuIds {
            XCTAssertTrue(menus.contains(menu: id), "missing menu \(id)")
        }
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel()
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaRenameFeature()
        let ticket = gate.captureTicket()

        var received: MonaRenameWorkspaceEdit?
        let accepted = feature.publishRename(
            MonaRenameWorkspaceEdit(edits: sampleEdits()),
            executor: executor,
            ticket: ticket
        ) { edit in
            received = edit
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.edits.count, 2)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaRenameFeature()
        var fired: [MonaRenameEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 6)
        )
        _ = feature.prepareRename(at: range, placeholder: "x")
        XCTAssertFalse(feature.isDisposed)

        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)

        // After disposal, prepare / accept / cancel are no-ops and fire no events.
        let countBefore = fired.count
        _ = feature.prepareRename(at: range, placeholder: "x")
        let model = makeModel()
        let gateway = MonaTransactionGateway(model: model)
        _ = feature.acceptRenameInput(feature.collectWorkspaceEdit(sampleEdits()), gateway: gateway)
        _ = feature.cancelRenameInput()
        XCTAssertEqual(fired.count, countBefore)
        XCTAssertNil(feature.currentPrepare)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaRenameFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaRenameFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels.first, "Rename Symbol")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertEqual(pseudoLabels.count, MonaRenameFeature.declaredActionIds.count)
        XCTAssertTrue(pseudoLabels.first?.hasPrefix("\u{FF3B}") ?? false)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaRenameFeature()
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
        let feature = MonaRenameFeature()

        let featureLive = features.contains(MonaRenameFeature.featureId)
        let actionCount = MonaRenameFeature.declaredActionIds.count
        let commandCount = MonaRenameFeature.declaredCommandIds.count
        let contribCount = MonaRenameFeature.declaredContributionIds.count
        let kbCount = MonaRenameFeature.declaredKeybindingCommands.count
        let optionCount = MonaRenameFeature.declaredOptionIds.count
        let menuCount = MonaRenameFeature.declaredMenuIds.count

        let slicePass = MonaRenameFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaRenameFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaRenameFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaRenameFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaRenameFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaRenameFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Prepare + collect + preview + apply atomically.
        let model = makeModel("let x = x")
        let gateway = MonaTransactionGateway(model: model)
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 6)
        )
        let prepared = feature.prepareRename(at: range, placeholder: "x")
        let preparePass = prepared != nil && feature.currentPrepare?.placeholder == "x"

        let edit = feature.collectWorkspaceEdit(sampleEdits())
        let collectPass = edit.edits.count == 2

        let preview = feature.previewRename(edit, model: model)
        let previewPass = preview.canApply && preview.failures.isEmpty

        var mutation = false
        let outcome = feature.applyRename(edit, gateway: gateway)
        if case .applied = outcome, model.getValue() == "let value = value" {
            mutation = true
        }

        // Atomic rollback when any range is invalid (all-or-none).
        let model2 = makeModel("ab")
        let gateway2 = MonaTransactionGateway(model: model2)
        let badEdit = feature.collectWorkspaceEdit([
            MonaRenameLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 2)
                ),
                newText: "z"
            ),
            MonaRenameLocation(
                uri: "file:///a.swift",
                range: MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: 99)
                ),
                newText: "q"
            )
        ])
        var atomicRollback = false
        let rolled = feature.applyRename(badEdit, gateway: gateway2)
        if case .rolledBack = rolled, model2.getValue() == "ab" {
            atomicRollback = true
        }

        // Async publication through the provider executor + microtask queue.
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishRename(
            MonaRenameWorkspaceEdit(edits: sampleEdits()),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        _ = feature.cancelRenameInput()
        let cancelPass = feature.currentPrepare == nil

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("RENAME feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(preparePass)
        XCTAssertTrue(collectPass)
        XCTAssertTrue(previewPass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(atomicRollback)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(cancelPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
