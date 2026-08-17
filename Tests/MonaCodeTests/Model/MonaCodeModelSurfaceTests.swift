// MonaCodeModelSurfaceTests.swift
//
// P01-T008 — Implement all 70 retained text-model members on Piece Tree truth.
//
// Verifies that `MonaCodeModel` exposes the 70 retained M1-R2 members of
// Monaco's `ITextModel` and delegates text truth EXCLUSIVELY to the Piece Tree
// (P01-T007). The 70 members are partitioned into six groups (see the M1-R2
// public-surface closure):
//
//   - Content / snapshot            · 13
//   - Position / range              · 11
//   - Search / word / language      ·  6
//   - Decorations                   · 12
//   - Options / edits / undo        · 13
//   - Identity / version / events   · 15
//
// `testSurfaceMembership` is the compile-time gate: it touches every one of the
// 70 member names. If any member is missing or renamed, this file fails to
// compile (the Red contract). The remaining tests exercise the key delegating
// members (`getValue`, `setValue`, `getLineCount`, `getLineContent`,
// `getPositionAt`, `getOffsetAt`, `applyEdits`, `createSnapshot`) and the event
// emitters, asserting they delegate correctly to the Piece Tree.
//
// Undo, decorations, word, RegExp, and search behavior are left behind explicit
// Phase 02 interfaces (stubs returning defaults); the surface test still calls
// them so their existence is enforced.

import XCTest
import MonaCode

final class MonaCodeModelSurfaceTests: XCTestCase {

    // MARK: - 1. Surface membership (compile-time gate for all 70 members)

    /// Touches every one of the 70 retained M1-R2 member names. This method
    /// exists primarily so that the Swift compiler enforces the presence of all
    /// 70 members on `MonaCodeModel`. Stubs (undo / decorations / word / search)
    /// are called with placeholder arguments and their default return values are
    /// discarded — the point is that they exist and are callable.
    func testSurfaceMembership() {
        let model = MonaCodeModel(
            text: "line1\nline2\nline3",
            options: MonaModelOptions.defaults,
            uri: MonaURI(scheme: "inmemory", path: "/model1")
        )

        // --- Content / snapshot · 13 ---
        _ = model.getValue()
        model.setValue("replacement")
        _ = model.createSnapshot()
        _ = model.getValueLength()
        _ = model.getValueInRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1))
        _ = model.getValueLengthInRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1))
        _ = model.getCharacterCountInRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1))
        _ = model.getLineCount()
        _ = model.getLineContent(1)
        _ = model.getLineLength(1)
        _ = model.getLinesContent()
        _ = model.getEOL()
        _ = model.getEndOfLineSequence()

        // --- Position / range · 11 ---
        _ = model.getLineMinColumn(1)
        _ = model.getLineMaxColumn(1)
        _ = model.getLineFirstNonWhitespaceColumn(1)
        _ = model.getLineLastNonWhitespaceColumn(1)
        _ = model.validatePosition(MonaPosition(line: 1, column: 1))
        _ = model.modifyPosition(MonaPosition(line: 1, column: 1), offset: 0)
        _ = model.validateRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1))
        _ = model.isValidRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1))
        _ = model.getOffsetAt(MonaPosition(line: 1, column: 1))
        _ = model.getPositionAt(0)
        _ = model.getFullModelRange()

        // --- Search / word / language · 6 ---
        _ = model.findMatches(searchString: "x", searchScope: .fullModel, isRegex: false, matchCase: false, captureMatches: false)
        _ = model.findNextMatch(searchString: "x", searchScope: .fullModel, isRegex: false, matchCase: false, captureMatches: false)
        _ = model.findPreviousMatch(searchString: "x", searchScope: .fullModel, isRegex: false, matchCase: false, captureMatches: false)
        _ = model.getLanguageId()
        _ = model.getWordAtPosition(MonaPosition(line: 1, column: 1))
        _ = model.getWordUntilPosition(MonaPosition(line: 1, column: 1))

        // --- Decorations · 12 ---
        _ = model.deltaDecorations([], [])
        _ = model.getDecorationOptions("id")
        _ = model.getDecorationRange("id")
        _ = model.getLineDecorations(1)
        _ = model.getLinesDecorations(1, 2)
        _ = model.getDecorationsInRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1))
        _ = model.getAllDecorations()
        _ = model.getAllMarginDecorations()
        _ = model.getOverviewRulerDecorations()
        _ = model.getInjectedTextDecorations()
        _ = model.getCustomLineHeightsDecorations()
        _ = model.getCustomLineHeightsDecorationsInRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1))

        // --- Options / edits / undo · 13 ---
        _ = model.normalizeIndentation("  code")
        model.updateOptions(MonaModelOptions(tabSize: 2))
        model.detectIndentation(defaultInsertSpaces: true, defaultTabSize: 4)
        model.pushStackElement()
        model.popStackElement()
        model.pushEditOperations([], [MonaModelEditOperation(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "")])
        model.pushEOL(.crlf)
        _ = model.applyEdits([MonaModelEditOperation(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "")])
        model.setEOL(.lf)
        model.undo()
        _ = model.canUndo()
        model.redo()
        _ = model.canRedo()

        // --- Identity / version / events / lifecycle · 15 ---
        _ = model.uri
        _ = model.id
        _ = model.getOptions()
        _ = model.getVersionId()
        _ = model.getAlternativeVersionId()
        _ = model.isDisposed()
        _ = model.onDidChangeContent
        _ = model.onDidChangeDecorations
        _ = model.onDidChangeOptions
        _ = model.onDidChangeLanguage
        _ = model.onDidChangeLanguageConfiguration
        _ = model.onDidChangeAttached
        _ = model.onWillDispose
        model.dispose()
        _ = model.isAttachedToEditor()

        // If we reached here, all 70 members compiled.
        XCTAssertTrue(true, "All 70 M1-R2 members are present on MonaCodeModel.")
    }

    // MARK: - 2. Delegation to the Piece Tree (the key members)

    func testGetValueAndSetValueDelegateToPieceTree() {
        let model = MonaCodeModel(text: "Hello, World", uri: MonaURI(scheme: "inmemory", path: "/m"))

        XCTAssertEqual(model.getValue(), "Hello, World")
        XCTAssertEqual(model.getValueLength(), 12) // UTF-16 length
        XCTAssertEqual(model.getLineCount(), 1)

        model.setValue("abc\ndef")
        XCTAssertEqual(model.getValue(), "abc\ndef")
        XCTAssertEqual(model.getValueLength(), 7)
        XCTAssertEqual(model.getLineCount(), 2)

        // createSnapshot delegates to the Piece Tree and preserves raw units.
        let snapshot = model.createSnapshot()
        XCTAssertEqual(snapshot.getText(), Array("abc\ndef".utf16))
        XCTAssertEqual(snapshot.length, 7)
    }

    func testLineQueriesDelegateToPieceTree() {
        let model = MonaCodeModel(text: "line1\nline2\nline3", uri: MonaURI(scheme: "inmemory", path: "/m"))

        XCTAssertEqual(model.getLineCount(), 3)
        XCTAssertEqual(model.getLineContent(1), "line1")
        XCTAssertEqual(model.getLineContent(2), "line2")
        XCTAssertEqual(model.getLineContent(3), "line3")
        XCTAssertEqual(model.getLineLength(1), 5)
        XCTAssertEqual(model.getLinesContent(), ["line1", "line2", "line3"])
        // An out-of-range line is an empty string.
        XCTAssertEqual(model.getLineContent(99), "")
    }

    func testOffsetAndPositionRoundTripDelegateToPieceTree() {
        // "line1\nline2\nline3"
        //  offsets: line1=0..4, \n=5, line2=6..10, \n=11, line3=12..16
        let model = MonaCodeModel(text: "line1\nline2\nline3", uri: MonaURI(scheme: "inmemory", path: "/m"))

        XCTAssertEqual(model.getOffsetAt(MonaPosition(line: 1, column: 1)), 0)
        XCTAssertEqual(model.getOffsetAt(MonaPosition(line: 2, column: 1)), 6)
        XCTAssertEqual(model.getOffsetAt(MonaPosition(line: 3, column: 1)), 12)

        XCTAssertEqual(model.getPositionAt(0), MonaPosition(line: 1, column: 1))
        XCTAssertEqual(model.getPositionAt(6), MonaPosition(line: 2, column: 1))
        XCTAssertEqual(model.getPositionAt(12), MonaPosition(line: 3, column: 1))

        // Round trip: offset -> position -> offset is identity.
        for offset in 0..<model.getValueLength() {
            let pos = model.getPositionAt(offset)
            XCTAssertEqual(model.getOffsetAt(pos), offset, "round trip failed at offset \(offset)")
        }
    }

    func testApplyEditsDelegatesToPieceTree() {
        let model = MonaCodeModel(text: "Hello, World", uri: MonaURI(scheme: "inmemory", path: "/m"))

        // Replace "Hello" with "Hi".
        let op = MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 6),
            text: "Hi"
        )
        _ = model.applyEdits([op])

        XCTAssertEqual(model.getValue(), "Hi, World")
        XCTAssertEqual(model.getValueLength(), 9)

        // Insert at end.
        let op2 = MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 10, endLine: 1, endColumn: 10),
            text: "!"
        )
        _ = model.applyEdits([op2])
        XCTAssertEqual(model.getValue(), "Hi, World!")
    }

    func testPushEditOperationsAppliesAndBumpsVersion() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let v0 = model.getVersionId()

        model.pushEditOperations(
            [],
            [MonaModelEditOperation(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "X")]
        )
        XCTAssertEqual(model.getValue(), "Xabc")
        let v1 = model.getVersionId()
        XCTAssertGreaterThan(v1, v0, "pushEditOperations must bump the version id")
        XCTAssertEqual(model.getAlternativeVersionId(), v0, "alternative version tracks the pre-edit version")
    }

    func testGetFullModelRangeAndValidatePosition() {
        let model = MonaCodeModel(text: "ab\ncd", uri: MonaURI(scheme: "inmemory", path: "/m"))

        let full = model.getFullModelRange()
        XCTAssertEqual(full.startPosition, MonaPosition(line: 1, column: 1))
        // Last line "cd" has max column 3 (length 2 + 1).
        XCTAssertEqual(full.endPosition, MonaPosition(line: 2, column: 3))

        // validatePosition clamps an out-of-range position back into bounds.
        let clamped = model.validatePosition(MonaPosition(line: 99, column: 99))
        XCTAssertEqual(clamped, MonaPosition(line: 2, column: 3))
    }

    // MARK: - 3. Event emitters

    func testOnDidChangeContentFiresOnApplyEdits() {
        let model = MonaCodeModel(text: "Hello", uri: MonaURI(scheme: "inmemory", path: "/m"))

        var received: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { event in
            received.append(event)
        }
        defer { disposable.dispose() }

        let op = MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        )
        _ = model.applyEdits([op])

        XCTAssertEqual(received.count, 1, "onDidChangeContent must fire exactly once per applyEdits batch")
        let event = received[0]
        XCTAssertFalse(event.isFlush, "applyEdits events are not flush events")
        XCTAssertFalse(event.isUndoing)
        XCTAssertFalse(event.isRedoing)
        XCTAssertEqual(event.changes.count, 1)
        XCTAssertEqual(event.changes[0].text, "X")
        XCTAssertEqual(event.changes[0].rangeOffset, 0)
        XCTAssertEqual(event.changes[0].rangeLength, 0)
    }

    func testOnDidChangeContentFiresFlushOnSetValue() {
        let model = MonaCodeModel(text: "Hello", uri: MonaURI(scheme: "inmemory", path: "/m"))

        var received: [MonaModelContentChangeEvent] = []
        let disposable = model.onDidChangeContent { event in
            received.append(event)
        }
        defer { disposable.dispose() }

        model.setValue("Brand new text")
        XCTAssertEqual(received.count, 1)
        XCTAssertTrue(received[0].isFlush, "setValue must emit a flush content-change event")
        XCTAssertEqual(model.getValue(), "Brand new text")
    }

    func testOnDidChangeOptionsFiresOnUpdateOptions() {
        let model = MonaCodeModel(text: "x", uri: MonaURI(scheme: "inmemory", path: "/m"))

        var received: [MonaModelOptionsChangeEvent] = []
        let disposable = model.onDidChangeOptions { event in
            received.append(event)
        }
        defer { disposable.dispose() }

        let old = model.getOptions()
        model.updateOptions(MonaModelOptions(tabSize: 8))
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0].oldOptions, old)
        XCTAssertEqual(received[0].newOptions.tabSize, 8)
    }

    func testOnWillDisposeFiresOnDispose() {
        let model = MonaCodeModel(text: "x", uri: MonaURI(scheme: "inmemory", path: "/m"))

        var disposedModels: [MonaCodeModel] = []
        let disposable = model.onWillDispose { model in
            disposedModels.append(model)
        }
        defer { disposable.dispose() }

        XCTAssertFalse(model.isDisposed())
        model.dispose()
        XCTAssertTrue(model.isDisposed(), "isDisposed() is true after dispose()")
        XCTAssertEqual(disposedModels.count, 1, "onWillDispose must fire on dispose()")
    }

    // MARK: - 4. Language fallback + EOL

    func testGetLanguageIdReturnsPlaintextFallback() {
        let model = MonaCodeModel(text: "x", uri: MonaURI(scheme: "inmemory", path: "/m"))
        // Per the M1-R2 closure: plaintext is the always-present fallback.
        XCTAssertEqual(model.getLanguageId(), "plaintext")
    }

    func testEOLAccessors() {
        let model = MonaCodeModel(text: "a\nb", uri: MonaURI(scheme: "inmemory", path: "/m"))
        XCTAssertEqual(model.getEndOfLineSequence(), .lf)
        XCTAssertEqual(model.getEOL(), "\n")

        model.setEOL(.crlf)
        XCTAssertEqual(model.getEndOfLineSequence(), .crlf)
        XCTAssertEqual(model.getEOL(), "\r\n")
    }
}
