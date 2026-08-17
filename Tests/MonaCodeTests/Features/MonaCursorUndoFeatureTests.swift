// MonaCursorUndoFeatureTests.swift
//
// P05-T111 — Implement retained feature cursorUndo.
//
// Verifies the cursorUndo feature across its three implementation operations:
//   1. Feature-specific behavior: record and restore cursor-only navigation
//      states independently from model undo (separate from `MonaUndoRedoStack`
//      which is model-undo).
//   2. The exact feature identity `cursorUndo` + its declared commands, actions,
//      contributions, options, menus, and keybindings (referenced verbatim from
//      the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testContractBehavior` prints the contract line:
//     CURSORUNDO feature=live actions=1 commands=1 contributions=1 keybindings=1 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaCursorUndoFeatureTests: XCTestCase {

    private func makeModel(_ text: String = "hello\nworld") -> MonaCodeModel {
        return MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/cursorundo-\(UUID().uuidString)")
        )
    }

    private func state(_ line: Int, _ column: Int) -> MonaCursorState {
        return MonaCursorState(
            position: MonaPosition(line: line, column: column),
            selections: [MonaSelection(
                anchor: MonaPosition(line: line, column: column),
                activePosition: MonaPosition(line: line, column: column)
            )]
        )
    }

    // MARK: - 1. Feature-specific behavior: record and restore cursor-only states

    func testRecordCursorStateBuildsUndoStack() {
        let feature = MonaCursorUndoFeature()
        feature.recordCursorState(state(1, 1))
        feature.recordCursorState(state(1, 5))
        feature.recordCursorState(state(2, 3))

        XCTAssertTrue(feature.canUndo)
        XCTAssertEqual(feature.undoStackSize, 3)
    }

    func testCursorUndoRestoresPreviousStateAndClearsRedo() {
        let feature = MonaCursorUndoFeature()
        feature.recordCursorState(state(1, 1))
        feature.recordCursorState(state(2, 1))

        let restored = feature.cursorUndo()
        XCTAssertEqual(restored?.position, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(feature.undoStackSize, 1)
        XCTAssertTrue(feature.canRedo)
    }

    func testCursorRedoReappliesUndoneState() {
        let feature = MonaCursorUndoFeature()
        feature.recordCursorState(state(1, 1))
        feature.recordCursorState(state(2, 1))

        _ = feature.cursorUndo()
        let redone = feature.cursorRedo()
        XCTAssertEqual(redone?.position, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(feature.undoStackSize, 2)
        XCTAssertFalse(feature.canRedo)
    }

    func testRecordClearsRedoStack() {
        let feature = MonaCursorUndoFeature()
        feature.recordCursorState(state(1, 1))
        feature.recordCursorState(state(2, 1))
        _ = feature.cursorUndo()
        XCTAssertTrue(feature.canRedo)

        // A new navigation state clears the redo stack (matching Monaco's
        // standard undo behavior).
        feature.recordCursorState(state(3, 1))
        XCTAssertFalse(feature.canRedo)
    }

    func testCursorUndoOnEmptyStackReturnsNil() {
        let feature = MonaCursorUndoFeature()
        XCTAssertFalse(feature.canUndo)
        XCTAssertNil(feature.cursorUndo())
    }

    func testCursorRedoOnEmptyStackReturnsNil() {
        let feature = MonaCursorUndoFeature()
        XCTAssertFalse(feature.canRedo)
        XCTAssertNil(feature.cursorRedo())
    }

    func testCursorUndoIsIndependentFromModelUndoStack() {
        let model = makeModel("hello")
        let gateway = MonaTransactionGateway(model: model)
        let modelUndo = MonaUndoRedoStack(gateway: gateway)
        let cursorFeature = MonaCursorUndoFeature()

        // The cursor undo stack records cursor states independently.
        cursorFeature.recordCursorState(state(1, 3))
        cursorFeature.recordCursorState(state(1, 5))
        XCTAssertTrue(cursorFeature.canUndo)
        XCTAssertFalse(modelUndo.canUndo)

        // Cursor undo restores the cursor state without touching model undo.
        let restored = cursorFeature.cursorUndo()
        XCTAssertEqual(restored?.position, MonaPosition(line: 1, column: 3))
        XCTAssertFalse(modelUndo.canUndo)
    }

    func testCommandsAreNoOpsAfterDisposal() {
        let feature = MonaCursorUndoFeature()
        feature.recordCursorState(state(1, 1))
        feature.dispose()

        XCTAssertNil(feature.cursorUndo())
        XCTAssertNil(feature.cursorRedo())
        XCTAssertFalse(feature.canUndo)
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let actions = MonaActionRegistry()
        let contributions = MonaContributionRegistry()
        let menus = MonaMenuRegistry()
        let options = MonaOptionStore()

        XCTAssertEqual(MonaCursorUndoFeature.featureId, "cursorUndo")
        XCTAssertTrue(features.contains("cursorUndo"))

        let actionIds = MonaCursorUndoFeature.declaredActionIds
        XCTAssertEqual(actionIds, ["cursorUndo"])
        for id in actionIds {
            XCTAssertTrue(actions.contains(id), "missing action \(id)")
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
            XCTAssertTrue(actions.containsPureText(id), "missing pure-text action \(id)")
        }

        let commandIds = MonaCursorUndoFeature.declaredCommandIds
        XCTAssertEqual(commandIds, ["cursorUndo"])
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        XCTAssertEqual(MonaCursorUndoFeature.declaredContributionIds, [
            "editor.contrib.cursorUndoRedoController"
        ])
        for id in MonaCursorUndoFeature.declaredContributionIds {
            XCTAssertTrue(contributions.contains(id), "missing contribution \(id)")
        }

        XCTAssertEqual(MonaCursorUndoFeature.declaredKeybindingCommands, ["cursorUndo"])
        for id in MonaCursorUndoFeature.declaredKeybindingCommands {
            let kbCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
            XCTAssertTrue(kbCommands.contains(id), "missing keybinding \(id)")
        }

        XCTAssertEqual(MonaCursorUndoFeature.declaredOptionIds, [])
        XCTAssertEqual(MonaCursorUndoFeature.declaredMenuIds, [])
    }

    // MARK: - 3. Routing through shared gateways

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaCursorUndoFeature()
        let ticket = gate.captureTicket()

        var received: [MonaCursorUndoEvent] = []
        let accepted = feature.publishCursorUndoEvent(
            MonaCursorUndoEvent(kind: .undo, state: state(1, 1)),
            executor: executor,
            ticket: ticket
        ) { event in
            received.append(event)
        }
        XCTAssertTrue(accepted)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaCursorUndoFeature()
        var fired: [MonaCursorUndoEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        XCTAssertTrue(fired.isEmpty)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaCursorUndoFeature()
        let enLabels = feature.localizedActionLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaCursorUndoFeature.declaredActionIds.count)
        XCTAssertEqual(enLabels[0], "Cursor Undo")
        let pseudoLabels = feature.localizedActionLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels[0].hasPrefix("\u{FF3B}"))
        XCTAssertTrue(pseudoLabels[0].hasSuffix("\u{FF3D}"))
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaCursorUndoFeature()
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
        let feature = MonaCursorUndoFeature()

        let featureLive = features.contains(MonaCursorUndoFeature.featureId)
        let actionCount = MonaCursorUndoFeature.declaredActionIds.count
        let commandCount = MonaCursorUndoFeature.declaredCommandIds.count
        let contribCount = MonaCursorUndoFeature.declaredContributionIds.count
        let kbCount = MonaCursorUndoFeature.declaredKeybindingCommands.count
        let optionCount = MonaCursorUndoFeature.declaredOptionIds.count
        let menuCount = MonaCursorUndoFeature.declaredMenuIds.count

        let slicePass = MonaCursorUndoFeature.declaredActionIds.allSatisfy { actions.contains($0) }
            && MonaCursorUndoFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaCursorUndoFeature.declaredContributionIds.allSatisfy { contributions.contains($0) }
            && MonaCursorUndoFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }
            && MonaCursorUndoFeature.declaredOptionIds.allSatisfy { options.value(for: $0) != nil }
            && MonaCursorUndoFeature.declaredMenuIds.allSatisfy { menus.contains(menu: $0) }

        // Mutation: record and restore a cursor-only state.
        feature.recordCursorState(state(1, 1))
        feature.recordCursorState(state(1, 5))
        let restored = feature.cursorUndo()
        let mutation = restored?.position == MonaPosition(line: 1, column: 1)

        // Async publication.
        let model = makeModel("abc")
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        _ = feature.publishCursorUndoEvent(
            MonaCursorUndoEvent(kind: .undo, state: state(1, 1)),
            executor: executor,
            ticket: gate.captureTicket()
        ) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed

        let localizationPass = feature.localizedActionLabels(profile: .default).count == actionCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("CURSORUNDO feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
