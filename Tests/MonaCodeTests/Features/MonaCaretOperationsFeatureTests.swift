// MonaCaretOperationsFeatureTests.swift
//
// P05-T102 — Implement retained feature caretOperations.
//
// Verifies the caretOperations feature across its three implementation operations:
//   1. Feature-specific behavior: move carets by line, wrapped line, column,
//      page, viewport, and document boundaries.
//   2. The exact feature identity `caretOperations` + its declared commands,
//      actions, contributions, options, menus, and keybindings (referenced
//      verbatim from the frozen registries — no rename / coalesce).
//   3. Routing of model mutation, asynchronous publication, disposal,
//      localization, and degraded plain-text behavior through the shared
//      gateways.
//
// On Green, `testCaretOperationsContractLeaf` prints the contract line:
//     CARETOPERATIONS feature=live actions=0 commands=31 contributions=0 keybindings=30 options=0 menus=0 mutation=pass async=pass disposal=pass localization=pass plaintext=pass

import XCTest
import MonaCode

final class MonaCaretOperationsFeatureTests: XCTestCase {

    /// Builds a `maxColumnOf` closure over `text` (1-based line → max column).
    private func maxColumnProvider(_ text: String) -> (lineCount: Int, maxColumnOf: (Int) -> Int) {
        let lines = text.components(separatedBy: "\n")
        let maxColumnOf: (Int) -> Int = { line in
            let idx = line - 1
            guard idx >= 0 && idx < lines.count else { return 1 }
            return lines[idx].utf16.count + 1
        }
        return (lines.count, maxColumnOf)
    }

    // MARK: - 1. Feature-specific behavior: move carets

    func testMoveByLineClampsColumnToDestinationLine() {
        let feature = MonaCaretOperationsFeature()
        let (lineCount, maxColumnOf) = maxColumnProvider("abc\nde\nf")
        // Line 1 max column 4; line 2 max column 3. Caret at end of line 1.
        let moved = feature.moveCaret(
            MonaPosition(line: 1, column: 4),
            target: .line(1),
            lineCount: lineCount,
            maxColumnOf: maxColumnOf
        )
        // Moved down one line; column clamped to line 2's max column (3).
        XCTAssertEqual(moved, MonaPosition(line: 2, column: 3))
    }

    func testMoveByLineClampsToDocumentBounds() {
        let feature = MonaCaretOperationsFeature()
        let (lineCount, maxColumnOf) = maxColumnProvider("a\nb\nc")
        // Moving up past the first line clamps to line 1.
        let up = feature.moveCaret(
            MonaPosition(line: 2, column: 1),
            target: .line(-5),
            lineCount: lineCount,
            maxColumnOf: maxColumnOf
        )
        XCTAssertEqual(up, MonaPosition(line: 1, column: 1))
        // Moving down past the last line clamps to line 3.
        let down = feature.moveCaret(
            MonaPosition(line: 2, column: 1),
            target: .line(5),
            lineCount: lineCount,
            maxColumnOf: maxColumnOf
        )
        XCTAssertEqual(down, MonaPosition(line: 3, column: 1))
    }

    func testMoveByCharacterWrapsAcrossLineBoundaries() {
        let feature = MonaCaretOperationsFeature()
        let (lineCount, maxColumnOf) = maxColumnProvider("ab\ncd")
        // (1,3) is the end of line 1 (after "ab"). Moving right wraps to (2,1).
        let wrap = feature.moveCaret(
            MonaPosition(line: 1, column: 3),
            target: .character(1),
            lineCount: lineCount,
            maxColumnOf: maxColumnOf
        )
        XCTAssertEqual(wrap, MonaPosition(line: 2, column: 1))
        // Moving left from (2,1) wraps back to the end of line 1.
        let back = feature.moveCaret(
            MonaPosition(line: 2, column: 1),
            target: .character(-1),
            lineCount: lineCount,
            maxColumnOf: maxColumnOf
        )
        XCTAssertEqual(back, MonaPosition(line: 1, column: 3))
        // Moving left from (1,1) stays at (1,1) (document start).
        let start = feature.moveCaret(
            MonaPosition(line: 1, column: 1),
            target: .character(-1),
            lineCount: lineCount,
            maxColumnOf: maxColumnOf
        )
        XCTAssertEqual(start, MonaPosition(line: 1, column: 1))
    }

    func testMoveByPageMovesByPageSizeLines() {
        let feature = MonaCaretOperationsFeature()
        let (lineCount, maxColumnOf) = maxColumnProvider("a\nb\nc\nd")
        // Page down by one page of size 2 from (1,1) → (3,1).
        let paged = feature.moveCaret(
            MonaPosition(line: 1, column: 1),
            target: .page(lines: 1, pageSize: 2),
            lineCount: lineCount,
            maxColumnOf: maxColumnOf
        )
        XCTAssertEqual(paged, MonaPosition(line: 3, column: 1))
        // Page down again clamps to the last line (4).
        let paged2 = feature.moveCaret(
            MonaPosition(line: 3, column: 1),
            target: .page(lines: 1, pageSize: 2),
            lineCount: lineCount,
            maxColumnOf: maxColumnOf
        )
        XCTAssertEqual(paged2, MonaPosition(line: 4, column: 1))
    }

    func testMoveToViewportBoundaries() {
        let feature = MonaCaretOperationsFeature()
        let (lineCount, maxColumnOf) = maxColumnProvider("aaaa\nb\nc\ndddd")
        // Viewport spans lines 2..4; caret at (1,5).
        let pos = MonaPosition(line: 1, column: 5)
        let top = feature.moveCaret(pos, target: .viewPortTop,
                                    lineCount: lineCount, maxColumnOf: maxColumnOf,
                                    viewportTopLine: 2, viewportBottomLine: 4)
        XCTAssertEqual(top, MonaPosition(line: 2, column: 2))   // clamped to line 2 max (2)
        let center = feature.moveCaret(pos, target: .viewPortCenter,
                                       lineCount: lineCount, maxColumnOf: maxColumnOf,
                                       viewportTopLine: 2, viewportBottomLine: 4)
        // Center line = (2+4)/2 = 3; "c" max column 2 → column clamped to 2.
        XCTAssertEqual(center, MonaPosition(line: 3, column: 2))
        let bottom = feature.moveCaret(pos, target: .viewPortBottom,
                                       lineCount: lineCount, maxColumnOf: maxColumnOf,
                                       viewportTopLine: 2, viewportBottomLine: 4)
        // "dddd" max column 5 → column stays at 5.
        XCTAssertEqual(bottom, MonaPosition(line: 4, column: 5))
    }

    func testMoveToDocumentBoundaries() {
        let feature = MonaCaretOperationsFeature()
        let (lineCount, maxColumnOf) = maxColumnProvider("abc\ndef")
        let start = feature.moveCaret(MonaPosition(line: 2, column: 2),
                                      target: .documentStart,
                                      lineCount: lineCount, maxColumnOf: maxColumnOf)
        XCTAssertEqual(start, MonaPosition(line: 1, column: 1))
        let end = feature.moveCaret(MonaPosition(line: 1, column: 1),
                                    target: .documentEnd,
                                    lineCount: lineCount, maxColumnOf: maxColumnOf)
        XCTAssertEqual(end, MonaPosition(line: 2, column: 4))  // "def" → max col 4
    }

    func testMoveToLineStartAndEnd() {
        let feature = MonaCaretOperationsFeature()
        let (lineCount, maxColumnOf) = maxColumnProvider("abc\ndef")
        let s = feature.moveCaret(MonaPosition(line: 2, column: 2),
                                  target: .lineStart,
                                  lineCount: lineCount, maxColumnOf: maxColumnOf)
        XCTAssertEqual(s, MonaPosition(line: 2, column: 1))
        let e = feature.moveCaret(MonaPosition(line: 2, column: 1),
                                  target: .lineEnd,
                                  lineCount: lineCount, maxColumnOf: maxColumnOf)
        XCTAssertEqual(e, MonaPosition(line: 2, column: 4))
    }

    func testMoveByWrappedLineDegradesToLineInPlainText() {
        let feature = MonaCaretOperationsFeature()
        let (lineCount, maxColumnOf) = maxColumnProvider("abc\ndef")
        // Wrapped-line movement degrades to line movement (no wrapping in
        // plain text).
        let wrapped = feature.moveCaret(MonaPosition(line: 1, column: 2),
                                        target: .wrappedLine(1),
                                        lineCount: lineCount, maxColumnOf: maxColumnOf)
        let lined = feature.moveCaret(MonaPosition(line: 1, column: 2),
                                      target: .line(1),
                                      lineCount: lineCount, maxColumnOf: maxColumnOf)
        XCTAssertEqual(wrapped, lined)
        XCTAssertEqual(wrapped, MonaPosition(line: 2, column: 2))
    }

    // MARK: - 2. Feature identity + declared slice (verbatim from registries)

    func testFeatureIdentityAndDeclaredSliceAreRegisteredVerbatim() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()

        XCTAssertTrue(features.contains(MonaCaretOperationsFeature.featureId))
        XCTAssertEqual(MonaCaretOperationsFeature.featureId, "caretOperations")

        // caretOperations declares pure navigation commands (no editor.action.*
        // entries, no contribution, no options, no menus).
        XCTAssertTrue(MonaCaretOperationsFeature.declaredActionIds.isEmpty)
        XCTAssertTrue(MonaCaretOperationsFeature.declaredContributionIds.isEmpty)
        XCTAssertTrue(MonaCaretOperationsFeature.declaredOptionIds.isEmpty)
        XCTAssertTrue(MonaCaretOperationsFeature.declaredMenuIds.isEmpty)

        // Declared commands (verbatim, source order; cursorRedo/cursorUndo are
        // the cursorUndo feature, excluded).
        let commandIds = MonaCaretOperationsFeature.declaredCommandIds
        XCTAssertEqual(commandIds.count, 31)
        XCTAssertEqual(commandIds.first, "cursorBottom")
        XCTAssertTrue(commandIds.contains("cursorMove"))
        XCTAssertFalse(commandIds.contains("cursorUndo"))
        XCTAssertFalse(commandIds.contains("cursorRedo"))
        for id in commandIds {
            XCTAssertTrue(commands.contains(id), "missing command \(id)")
        }

        // Declared keybinding commands are a subset of the declared commands
        // and each carries a builtin keybinding.
        let kbCommands = MonaCaretOperationsFeature.declaredKeybindingCommands
        XCTAssertEqual(kbCommands.count, 30)
        let keybindingCommands = Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command })
        for id in kbCommands {
            XCTAssertTrue(keybindingCommands.contains(id), "missing keybinding for \(id)")
        }
        // cursorMove carries no default keybinding.
        XCTAssertFalse(MonaCaretOperationsFeature.declaredKeybindingCommands.contains("cursorMove"))
    }

    // MARK: - 3. Routing through shared gateways

    func testModelMutationRoutesThroughTransactionGateway() {
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/caret")
        )
        let gateway = MonaTransactionGateway(model: model)
        let feature = MonaCaretOperationsFeature()
        let committed = feature.commitCaretMove(
            MonaPosition(line: 1, column: 1),
            target: .line(1),
            gateway: gateway,
            lineCount: model.getLineCount(),
            maxColumnOf: { model.getLineMaxColumn($0) }
        )
        XCTAssertEqual(committed.count, 1)
        // Moved down one line; column clamped to line 2's max column (4).
        XCTAssertEqual(committed[0].activePosition, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(committed[0].anchor, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(gateway.lastCommittedSelections, committed)
    }

    func testAsyncPublicationRoutesThroughProviderExecutorAndMicrotaskQueue() {
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/caret-async")
        )
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let feature = MonaCaretOperationsFeature()
        let moved = feature.moveCaret(MonaPosition(line: 1, column: 1),
                                      target: .character(2),
                                      lineCount: 1,
                                      maxColumnOf: { _ in 4 })
        let ticket = gate.captureTicket()
        var received: MonaPosition?
        let accepted = feature.publishCaretMove(moved, executor: executor, ticket: ticket) { pos in
            received = pos
        }
        XCTAssertTrue(accepted)
        XCTAssertNil(received)
        XCTAssertEqual(queue.pendingCount, 1)
        executor.drain()
        XCTAssertEqual(received, MonaPosition(line: 1, column: 3))
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testDisposalRoutesThroughEmitterAndIsIdempotent() {
        let feature = MonaCaretOperationsFeature()
        var fired: [MonaCaretEvent] = []
        _ = feature.onChange { event in fired.append(event) }
        _ = feature.moveCaret(MonaPosition(line: 1, column: 1),
                               target: .line(1),
                               lineCount: 2,
                               maxColumnOf: { _ in 2 })
        XCTAssertEqual(fired.count, 1)
        XCTAssertFalse(feature.isDisposed)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
        _ = feature.moveCaret(MonaPosition(line: 1, column: 1),
                               target: .line(1),
                               lineCount: 2,
                               maxColumnOf: { _ in 2 })
        XCTAssertEqual(fired.count, 1)
        feature.dispose()
        XCTAssertTrue(feature.isDisposed)
    }

    func testLocalizationRoutesThroughMonaLocalization() {
        let feature = MonaCaretOperationsFeature()
        // caretOperations has no actions; it localizes its declared command IDs
        // through the shared MonaLocalization surface.
        let enLabels = feature.localizedCommandLabels(profile: .default)
        XCTAssertEqual(enLabels.count, MonaCaretOperationsFeature.declaredCommandIds.count)
        XCTAssertEqual(enLabels.first, "cursorBottom")
        let pseudoLabels = feature.localizedCommandLabels(profile: .custom("pseudo"))
        XCTAssertTrue(pseudoLabels.first?.hasPrefix("\u{FF3B}") ?? false)
        XCTAssertTrue(pseudoLabels.first?.hasSuffix("\u{FF3D}") ?? false)
    }

    func testDegradedPlainTextRoutesThroughMonaPlainTextLanguage() {
        let feature = MonaCaretOperationsFeature()
        // caretOperations degrades to plain-text line geometry when no wrapping
        // / tokenization is registered.
        XCTAssertTrue(feature.isPlainTextDegraded)
        XCTAssertEqual(feature.degradedLanguage.id, MonaPlainTextLanguage.languageId)
        XCTAssertFalse(feature.degradedLanguage.hasTokenization)
    }

    // MARK: - Contract leaf

    func testCaretOperationsContractLeaf() {
        let features = MonaFeatureRegistry()
        let commands = MonaCommandRegistry()
        let feature = MonaCaretOperationsFeature()

        let featureLive = features.contains(MonaCaretOperationsFeature.featureId)
        let actionCount = MonaCaretOperationsFeature.declaredActionIds.count
        let commandCount = MonaCaretOperationsFeature.declaredCommandIds.count
        let contribCount = MonaCaretOperationsFeature.declaredContributionIds.count
        let kbCount = MonaCaretOperationsFeature.declaredKeybindingCommands.count
        let optionCount = MonaCaretOperationsFeature.declaredOptionIds.count
        let menuCount = MonaCaretOperationsFeature.declaredMenuIds.count

        let slicePass = MonaCaretOperationsFeature.declaredCommandIds.allSatisfy { commands.contains($0) }
            && MonaCaretOperationsFeature.declaredKeybindingCommands.allSatisfy {
                Set(MonaBuiltinKeybindings.rows.map { $0.keybinding.command }).contains($0)
            }

        let model = MonaCodeModel(text: "abc\ndef", uri: MonaURI(scheme: "inmemory", path: "/leaf"))
        let gateway = MonaTransactionGateway(model: model)
        let mutation = feature.commitCaretMove(
            MonaPosition(line: 1, column: 1),
            target: .documentEnd,
            gateway: gateway,
            lineCount: model.getLineCount(),
            maxColumnOf: { model.getLineMaxColumn($0) }
        ).count == 1 && gateway.lastCommittedSelections.count == 1

        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        var delivered = false
        let moved = feature.moveCaret(MonaPosition(line: 1, column: 1),
                                      target: .documentEnd,
                                      lineCount: model.getLineCount(),
                                      maxColumnOf: { model.getLineMaxColumn($0) })
        _ = feature.publishCaretMove(moved, executor: executor, ticket: gate.captureTicket()) { _ in delivered = true }
        executor.drain()
        let asyncPass = delivered && queue.pendingCount == 0

        feature.dispose()
        let disposalPass = feature.isDisposed
        let localizationPass = feature.localizedCommandLabels(profile: .default).count == commandCount
        let plaintextPass = feature.isPlainTextDegraded && feature.degradedLanguage.id == "plaintext"

        print("CARETOPERATIONS feature=\(featureLive ? "live" : "dead") actions=\(actionCount) commands=\(commandCount) contributions=\(contribCount) keybindings=\(kbCount) options=\(optionCount) menus=\(menuCount) mutation=\(mutation ? "pass" : "fail") async=\(asyncPass ? "pass" : "fail") disposal=\(disposalPass ? "pass" : "fail") localization=\(localizationPass ? "pass" : "fail") plaintext=\(plaintextPass ? "pass" : "fail")")

        XCTAssertTrue(featureLive)
        XCTAssertTrue(slicePass)
        XCTAssertTrue(mutation)
        XCTAssertTrue(asyncPass)
        XCTAssertTrue(disposalPass)
        XCTAssertTrue(localizationPass)
        XCTAssertTrue(plaintextPass)
    }
}
