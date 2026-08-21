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

    // MARK: - 5. Search delegation to MonaLiteralSearch (Task 2)

    /// `findMatches` must delegate to `MonaLiteralSearch.findAll` and return real
    /// matches (not the Phase-01 stub `[]`), with each match's range adapted from
    /// the engine's UTF-16 `startOffset`/`length` to a `MonaRange` of positions.
    func testFindMatchesDelegatesToSearchEngine() {
        // "Hello World Hello"
        //  offsets: H=0..4, ' '=5, W=6..10, ' '=11, H=12..16
        let model = MonaCodeModel(text: "Hello World Hello", uri: MonaURI(scheme: "inmemory", path: "/m"))

        let matches = model.findMatches(
            searchString: "Hello",
            searchScope: .fullModel,
            isRegex: false,
            matchCase: false,
            captureMatches: false
        )
        XCTAssertEqual(matches.count, 2, "findMatches returns real matches, not the stub []")

        // First "Hello" spans UTF-16 offsets 0..<5 → (1,1)..(1,6).
        XCTAssertEqual(
            matches[0].range,
            MonaRange(startPosition: MonaPosition(line: 1, column: 1), endPosition: MonaPosition(line: 1, column: 6))
        )
        // Second "Hello" spans UTF-16 offsets 12..<17 → (1,13)..(1,18).
        XCTAssertEqual(
            matches[1].range,
            MonaRange(startPosition: MonaPosition(line: 1, column: 13), endPosition: MonaPosition(line: 1, column: 18))
        )
    }

    /// Case sensitivity must reach the engine: case-sensitive search for
    /// `"hello"` finds nothing in `"Hello World Hello"`; case-insensitive finds 2.
    /// This guards against a stub or a re-implementation that ignores `matchCase`.
    func testFindMatchesHonorsMatchCaseThroughEngine() {
        let model = MonaCodeModel(text: "Hello World Hello", uri: MonaURI(scheme: "inmemory", path: "/m"))

        let caseSensitive = model.findMatches(
            searchString: "hello",
            searchScope: .fullModel,
            isRegex: false,
            matchCase: true,
            captureMatches: false
        )
        XCTAssertTrue(caseSensitive.isEmpty, "case-sensitive findMatches for 'hello' must be empty")

        let caseInsensitive = model.findMatches(
            searchString: "hello",
            searchScope: .fullModel,
            isRegex: false,
            matchCase: false,
            captureMatches: false
        )
        XCTAssertEqual(caseInsensitive.count, 2, "case-insensitive findMatches for 'hello' finds both 'Hello's")
    }

    /// `findNextMatch` delegates to `MonaLiteralSearch.findNext` from offset 0 and
    /// returns the first match (not the Phase-01 stub `nil`).
    func testFindNextMatchDelegatesToSearchEngine() {
        let model = MonaCodeModel(text: "Hello World Hello", uri: MonaURI(scheme: "inmemory", path: "/m"))

        let next = model.findNextMatch(
            searchString: "Hello",
            searchScope: .fullModel,
            isRegex: false,
            matchCase: false,
            captureMatches: false
        )
        guard let match = next else {
            XCTFail("findNextMatch must return the first match, not nil")
            return
        }
        XCTAssertEqual(
            match.range,
            MonaRange(startPosition: MonaPosition(line: 1, column: 1), endPosition: MonaPosition(line: 1, column: 6))
        )
    }

    /// `findPreviousMatch` delegates to `MonaLiteralSearch.findPrevious` from the
    /// end of the text and returns the last match (not the Phase-01 stub `nil`).
    func testFindPreviousMatchDelegatesToSearchEngine() {
        let model = MonaCodeModel(text: "Hello World Hello", uri: MonaURI(scheme: "inmemory", path: "/m"))

        let previous = model.findPreviousMatch(
            searchString: "Hello",
            searchScope: .fullModel,
            isRegex: false,
            matchCase: false,
            captureMatches: false
        )
        guard let match = previous else {
            XCTFail("findPreviousMatch must return the last match, not nil")
            return
        }
        XCTAssertEqual(
            match.range,
            MonaRange(startPosition: MonaPosition(line: 1, column: 13), endPosition: MonaPosition(line: 1, column: 18))
        )
    }

    /// A needle absent from the text yields no matches through the real engine.
    func testFindMatchesNoMatchReturnsEmpty() {
        let model = MonaCodeModel(text: "Hello World", uri: MonaURI(scheme: "inmemory", path: "/m"))

        let matches = model.findMatches(
            searchString: "Goodbye",
            searchScope: .fullModel,
            isRegex: false,
            matchCase: false,
            captureMatches: false
        )
        XCTAssertTrue(matches.isEmpty, "absent needle yields zero matches")

        XCTAssertNil(
            model.findNextMatch(searchString: "Goodbye", searchScope: .fullModel, isRegex: false, matchCase: false, captureMatches: false),
            "absent needle yields nil next match"
        )
        XCTAssertNil(
            model.findPreviousMatch(searchString: "Goodbye", searchScope: .fullModel, isRegex: false, matchCase: false, captureMatches: false),
            "absent needle yields nil previous match"
        )
    }

    // MARK: - 6. Word delegation to MonaWordClassifier (Task 3)

    /// `getWordAtPosition` must delegate to `MonaWordClassifier` to find the
    /// maximal word-character run around the position, returning a real range
    /// (not the Phase-01 stub `nil`). For "hello world", column 1 sits on 'h';
    /// the run is "hello" spanning columns 1..<6.
    func testGetWordAtPositionDelegatesToWordResolver() {
        // "hello world": h=1 e=2 l=3 l=4 o=5 ' '=6 w=7 o=8 r=9 l=10 d=11
        let model = MonaCodeModel(text: "hello world", uri: MonaURI(scheme: "inmemory", path: "/m"))

        // Column 1 ('h'): backward scan stops at line start, forward scan stops
        // at the space → "hello" at columns 1..<6.
        let range = model.getWordAtPosition(MonaPosition(line: 1, column: 1))
        XCTAssertNotNil(range, "getWordAtPosition returns a real range, not the stub nil")
        XCTAssertEqual(
            range,
            MonaRange(startPosition: MonaPosition(line: 1, column: 1), endPosition: MonaPosition(line: 1, column: 6))
        )

        // Column 8 ('o' of "world"): backward scan stops at the space (col 6),
        // forward scan runs to end-of-line → "world" at columns 7..<12.
        XCTAssertEqual(
            model.getWordAtPosition(MonaPosition(line: 1, column: 8)),
            MonaRange(startPosition: MonaPosition(line: 1, column: 7), endPosition: MonaPosition(line: 1, column: 12))
        )

        // Column 12 (just past 'd'): the position is past the last unit, which
        // is a word char, so the enclosing run is still "world".
        XCTAssertEqual(
            model.getWordAtPosition(MonaPosition(line: 1, column: 12)),
            MonaRange(startPosition: MonaPosition(line: 1, column: 7), endPosition: MonaPosition(line: 1, column: 12))
        )

        // Column 6 (the space): not a word character → no enclosing run → nil.
        XCTAssertNil(
            model.getWordAtPosition(MonaPosition(line: 1, column: 6)),
            "a position on a non-word character yields no word"
        )
    }

    /// `getWordUntilPosition` returns the run from the word's start up to (not
    /// including) the position, delegating boundary detection to
    /// `MonaWordClassifier`. It never returns nil (matching Monaco's
    /// `getWordUntilPosition`); a position off a word yields a folded range at
    /// the position.
    func testGetWordUntilPositionDelegatesToWordResolver() {
        let model = MonaCodeModel(text: "hello world", uri: MonaURI(scheme: "inmemory", path: "/m"))

        // Column 4 ('l' of "hello"): word start col 1, end at position col 4 →
        // "hel" at columns 1..<4. Requires the backward scan to find col 1.
        XCTAssertEqual(
            model.getWordUntilPosition(MonaPosition(line: 1, column: 4)),
            MonaRange(startPosition: MonaPosition(line: 1, column: 1), endPosition: MonaPosition(line: 1, column: 4))
        )

        // Column 1 (first char of "hello"): word-until is empty → folded range
        // at the position (end == position, not the full word end col 6).
        XCTAssertEqual(
            model.getWordUntilPosition(MonaPosition(line: 1, column: 1)),
            MonaRange(startPosition: MonaPosition(line: 1, column: 1), endPosition: MonaPosition(line: 1, column: 1))
        )

        // Column 6 (the space): no enclosing word → folded range at col 6
        // (non-nil, matching Monaco).
        XCTAssertEqual(
            model.getWordUntilPosition(MonaPosition(line: 1, column: 6)),
            MonaRange(startPosition: MonaPosition(line: 1, column: 6), endPosition: MonaPosition(line: 1, column: 6))
        )
    }

    /// Word resolution is per-line: a position on line 2 reads line 2's UTF-16
    /// content and finds the word there, proving `getLineContent(line)` feeds
    /// the scan (not the whole model text).
    func testGetWordAtPositionReadsThePositionLine() {
        // Line 1 = "ab cd", line 2 = "ef gh".
        let model = MonaCodeModel(text: "ab cd\nef gh", uri: MonaURI(scheme: "inmemory", path: "/m"))

        // Line 2 "ef gh": e=1 f=2 ' '=3 g=4 h=5. Column 4 ('g') → "gh" 4..<6.
        XCTAssertEqual(
            model.getWordAtPosition(MonaPosition(line: 2, column: 4)),
            MonaRange(startPosition: MonaPosition(line: 2, column: 4), endPosition: MonaPosition(line: 2, column: 6))
        )
        // Column 2 ('f'): the whole word "ef" at 1..<3 on line 2.
        XCTAssertEqual(
            model.getWordAtPosition(MonaPosition(line: 2, column: 2)),
            MonaRange(startPosition: MonaPosition(line: 2, column: 1), endPosition: MonaPosition(line: 2, column: 3))
        )
    }

    // MARK: - 7. Decoration delegation to MonaDecorationCollection (Task 4)

    /// `deltaDecorations` must delegate to `MonaDecorationCollection` (the live
    /// decoration store) and return real, non-empty ids — not the Phase-02 stub
    /// `[]`. Each new decoration option yields one fresh id.
    func testDeltaDecorationsReturnsNonEmptyIDs() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))

        let ids = model.deltaDecorations([], [MonaModelDecorationOptions()])
        XCTAssertFalse(ids.isEmpty, "deltaDecorations returns real IDs, not the stub []")
        XCTAssertEqual(ids.count, 1, "one new decoration option yields one id")
    }

    /// `deltaDecorations` applies the remove/add diff: old ids are removed and
    /// new decorations are added, returning the new ids. Removing all (empty new
    /// list) returns an empty list, and a subsequent add yields fresh ids that
    /// differ from the removed ones (proving the old decorations were consumed).
    func testDeltaDecorationsAddsThenRemovesDecorations() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))

        // Add two decorations → two unique ids.
        let added = model.deltaDecorations([], [MonaModelDecorationOptions(), MonaModelDecorationOptions()])
        XCTAssertEqual(added.count, 2, "two new decoration options yield two ids")
        XCTAssertEqual(Set(added).count, 2, "the two ids are distinct")

        // Remove both (old = added, new = empty) → no new ids.
        let afterRemove = model.deltaDecorations(added, [])
        XCTAssertTrue(afterRemove.isEmpty, "removing with no new decorations yields no new ids")

        // A subsequent add yields a fresh id that was not in the removed set,
        // proving the diff advanced past the removed decorations.
        let readded = model.deltaDecorations([], [MonaModelDecorationOptions()])
        XCTAssertEqual(readded.count, 1)
        XCTAssertTrue(Set(added).isDisjoint(with: readded), "the fresh id is not a reuse of a removed id")
    }
}
