// Tests/MonaCodeTests/Input/MonaCommandDispatcherTests.swift
import XCTest
import MonaCode

final class MonaCommandDispatcherTests: XCTestCase {
    func makeDispatcher(text: String = "") -> (MonaCommandDispatcher, MonaCodeModel, MonaModelInputBarrier, MonaTransactionGateway) {
        let model = MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/t"))
        let barrier = MonaModelInputBarrier(model: model)
        let dispatcher = MonaCommandDispatcher(model: model, inputBarrier: barrier,
                                               transactionGateway: barrier.gateway,
                                               caretOps: MonaCaretOperationsFeature())
        return (dispatcher, model, barrier, barrier.gateway)
    }

    func testExecuteUnknownCommandReturnsFalse() {
        let (dispatcher, _, _, _) = makeDispatcher()
        XCTAssertFalse(dispatcher.execute("nope"))
        XCTAssertFalse(dispatcher.contains("nope"))
    }

    func testRegisterAndExecuteCustomCommand() {
        var called = false
        let (dispatcher, model, _, _) = makeDispatcher()
        dispatcher.register("test.echo") { ctx, _ in called = true; _ = ctx }
        XCTAssertTrue(dispatcher.contains("test.echo"))
        XCTAssertTrue(dispatcher.execute("test.echo"))
        XCTAssertTrue(called)
        _ = model
    }

    // MARK: - type

    func testTypeInsertsAtCaret() {
        let (dispatcher, model, _, gateway) = makeDispatcher(text: "")
        // seed caret at (1,1)
        seedSelections(gateway, [MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))])
        XCTAssertTrue(dispatcher.execute("type", args: ["text": "X"]))
        XCTAssertEqual(model.getValue(), "X")
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition.column, 2)
    }

    func testTypeReplacesSelection() {
        let (dispatcher, model, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 1, 1, 4)])
        XCTAssertTrue(dispatcher.execute("type", args: ["text": "X"]))
        XCTAssertEqual(model.getValue(), "X")
    }

    func testTypeMatchesMonacoFixture() {
        let fixture = loadFixture("type")
        for case_ in fixture {
            let (dispatcher, model, _, gateway) = makeDispatcher(text: case_.initialText)
            seedSelections(gateway, case_.initialSelection.map { sel($0[0], $0[1], $0[2], $0[3]) })
            dispatcher.execute("type", args: case_.args?.text.map { ["text": $0] })
            XCTAssertEqual(model.getValue(), case_.expected.value)
            XCTAssertEqual(selectionsArray(gateway.lastCommittedSelections), case_.expected.selections)
        }
    }

    // MARK: - deleteLeft

    func testDeleteLeftChar() {
        let (dispatcher, model, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 2, 1, 2)])
        dispatcher.execute("deleteLeft")
        XCTAssertEqual(model.getValue(), "bc")
    }

    func testDeleteLeftCrossLineJoin() {
        let (dispatcher, model, _, gateway) = makeDispatcher(text: "ab\ncd")
        seedSelections(gateway, [sel(2, 1, 2, 1)])
        dispatcher.execute("deleteLeft")
        XCTAssertEqual(model.getValue(), "abcd")           // join
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition, MonaPosition(line: 1, column: 3))
    }

    func testDeleteLeftAtDocStartNoop() {
        let (dispatcher, model, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 1, 1, 1)])
        dispatcher.execute("deleteLeft")
        XCTAssertEqual(model.getValue(), "abc")
    }

    func testDeleteLeftDeletesSelection() {
        let (dispatcher, model, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 1, 1, 3)])
        dispatcher.execute("deleteLeft")
        XCTAssertEqual(model.getValue(), "c")
    }

    func testDeleteLeftMatchesMonacoFixture() {
        for case_ in loadFixture("deleteLeft") {
            let (dispatcher, model, _, gateway) = makeDispatcher(text: case_.initialText)
            seedSelections(gateway, case_.initialSelection.map { sel($0[0], $0[1], $0[2], $0[3]) })
            dispatcher.execute("deleteLeft")
            XCTAssertEqual(model.getValue(), case_.expected.value)
        }
    }

    // MARK: - deleteRight

    func testDeleteRightChar() {
        let (dispatcher, model, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 1, 1, 1)])
        dispatcher.execute("deleteRight")
        XCTAssertEqual(model.getValue(), "bc")
    }

    func testDeleteRightCrossLineJoin() {
        let (dispatcher, model, _, gateway) = makeDispatcher(text: "ab\ncd")
        seedSelections(gateway, [sel(1, 3, 1, 3)])            // end of line 1 (maxCol)
        dispatcher.execute("deleteRight")
        XCTAssertEqual(model.getValue(), "abcd")               // join next line
    }

    func testDeleteRightMatchesMonacoFixture() {
        for case_ in loadFixture("deleteRight") {
            let (dispatcher, model, _, gateway) = makeDispatcher(text: case_.initialText)
            seedSelections(gateway, case_.initialSelection.map { sel($0[0], $0[1], $0[2], $0[3]) })
            dispatcher.execute("deleteRight")
            XCTAssertEqual(model.getValue(), case_.expected.value)
        }
    }

    // MARK: - cursorLeft / cursorRight

    func testCursorLeft() {
        let (dispatcher, _, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 2, 1, 2)])
        dispatcher.execute("cursorLeft")
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition, MonaPosition(line: 1, column: 1))
    }

    func testCursorRight() {
        let (dispatcher, _, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 1, 1, 1)])
        dispatcher.execute("cursorRight")
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition, MonaPosition(line: 1, column: 2))
    }

    func testCursorLeftMatchesMonacoFixture() {
        for case_ in loadFixture("cursorLeft") {
            let (dispatcher, _, _, gateway) = makeDispatcher(text: case_.initialText)
            seedSelections(gateway, case_.initialSelection.map { sel($0[0], $0[1], $0[2], $0[3]) })
            dispatcher.execute("cursorLeft")
            XCTAssertEqual(selectionsArray(gateway.lastCommittedSelections), case_.expected.selections)
        }
    }

    // MARK: - cursorUp / cursorDown

    func testCursorUp() {
        let (dispatcher, _, _, gateway) = makeDispatcher(text: "ab\ncd")
        seedSelections(gateway, [sel(2, 2, 2, 2)])
        dispatcher.execute("cursorUp")
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition.line, 1)
    }

    func testCursorDown() {
        let (dispatcher, _, _, gateway) = makeDispatcher(text: "ab\ncd")
        seedSelections(gateway, [sel(1, 2, 1, 2)])
        dispatcher.execute("cursorDown")
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition.line, 2)
    }

    func testCursorUpDownMatchesMonacoFixture() {
        for cmd in ["cursorUp", "cursorDown"] {
            for case_ in loadFixture(cmd) {
                let (dispatcher, _, _, gateway) = makeDispatcher(text: case_.initialText)
                seedSelections(gateway, case_.initialSelection.map { sel($0[0], $0[1], $0[2], $0[3]) })
                dispatcher.execute(cmd)
                XCTAssertEqual(selectionsArray(gateway.lastCommittedSelections), case_.expected.selections)
            }
        }
    }

    // MARK: - cursorEnd / cursorHome

    func testCursorEnd() {
        let (dispatcher, _, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 1, 1, 1)])
        dispatcher.execute("cursorEnd", args: ["sticky": true])   // sticky ignored
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition, MonaPosition(line: 1, column: 4))  // maxCol
    }

    func testCursorHome() {
        let (dispatcher, _, _, gateway) = makeDispatcher(text: "abc")
        seedSelections(gateway, [sel(1, 3, 1, 3)])
        dispatcher.execute("cursorHome")
        XCTAssertEqual(gateway.lastCommittedSelections.first?.activePosition, MonaPosition(line: 1, column: 1))
    }

    func testCursorEndHomeMatchesMonacoFixture() {
        for cmd in ["cursorEnd", "cursorHome"] {
            for case_ in loadFixture(cmd) {
                let (dispatcher, _, _, gateway) = makeDispatcher(text: case_.initialText)
                seedSelections(gateway, case_.initialSelection.map { sel($0[0], $0[1], $0[2], $0[3]) })
                dispatcher.execute(cmd)
                XCTAssertEqual(selectionsArray(gateway.lastCommittedSelections), case_.expected.selections)
            }
        }
    }

    // MARK: - Shared test helpers (reused by T4–T8 command tests)

    /// Seeds `gateway.lastCommittedSelections` by committing a selections-only
    /// transaction (no edits). The committed selections become the cursor state
    /// the next command reads via `MonaCommandDispatcher.currentSelections`.
    func seedSelections(_ gateway: MonaTransactionGateway, _ sels: [MonaSelection]) {
        let tx = gateway.beginTransaction()
        tx.prepareSelections(sels)
        _ = gateway.commit(tx)
    }

    /// Builds a `MonaSelection` from raw one-based `[startLine, startColumn,
    /// endLine, endColumn]` coordinates. `anchor = start`, `active = end`
    /// (forward selection; for the `type` fixtures all selections are forward).
    func sel(_ sL: Int, _ sC: Int, _ eL: Int, _ eC: Int) -> MonaSelection {
        MonaSelection(anchor: MonaPosition(line: sL, column: sC), activePosition: MonaPosition(line: eL, column: eC))
    }

    /// Maps a `[MonaSelection]` to the fixture's `[[Int]]` form as
    /// `[anchor.line, anchor.column, activePosition.line, activePosition.column]`.
    /// For forward selections (anchor == start) this matches Monaco's
    /// `[startLine, startColumn, endLine, endColumn]`.
    func selectionsArray(_ sels: [MonaSelection]) -> [[Int]] {
        sels.map { [$0.anchor.line, $0.anchor.column, $0.activePosition.line, $0.activePosition.column] }
    }

    /// Loads `Tests/Fixtures/CommandDispatcherFixtures/<cmd>.json` as an array
    /// of `FixtureCase`. The fixture path is resolved by walking up from this
    /// source file to the repo root (the directory containing `Package.swift`),
    /// so it is independent of the process working directory.
    func loadFixture(_ cmd: String) -> [FixtureCase] {
        let fm = FileManager.default
        var dir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        for _ in 0..<12 {
            if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                let url = dir.appendingPathComponent("Tests/Fixtures/CommandDispatcherFixtures/\(cmd).json")
                let data = try! Data(contentsOf: url)
                return try! JSONDecoder().decode([FixtureCase].self, from: data)
            }
            dir = dir.deletingLastPathComponent()
        }
        // Fallback: assume the process working directory is the repo root.
        let url = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("Tests/Fixtures/CommandDispatcherFixtures/\(cmd).json")
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode([FixtureCase].self, from: data)
    }
}

// MARK: - Fixture Codable (shared by T4–T8 command tests)

/// A single command-dispatcher fixture case decoded from
/// `Tests/Fixtures/CommandDispatcherFixtures/<cmd>.json`.
///
/// JSON shape:
/// ```
/// { "command": String,
///   "args": { "text"?: String, "sticky"?: Bool } | null,
///   "initialText": String,
///   "initialSelection": [[sL,sC,eL,eC]],
///   "expected": { "value": String, "selections": [[sL,sC,eL,eC]] } }
/// ```
struct FixtureCase: Decodable {
    let command: String
    let args: FixtureArgs?
    let initialText: String
    let initialSelection: [[Int]]
    let expected: FixtureExpected
}

/// Optional command args. `text` is used by `type`; `sticky` is used by the
/// cursor commands (T4–T8). Both optional so fixtures may omit either.
struct FixtureArgs: Decodable {
    let text: String?
    let sticky: Bool?
}

/// The expected post-command model value and selections.
struct FixtureExpected: Decodable {
    let value: String
    let selections: [[Int]]
}
