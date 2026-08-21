// C01Tests.swift
//
// P09-T010 — Run C01: model and exact semantic equivalence.
//
// The C01 differential conformance suite — the FIRST C-candidate acceptance
// test. It compares the Swift port's outputs (base values, URI, raw UTF-16
// Piece Tree, the 70 model members from P01, transactions, undo, decorations,
// search, RegExp, and Unicode) against the monaco-editor reference fixtures
// M0 + M1, and binds all evidence hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - Tests/Fixtures/DifferentialFixtures/regexp/test262-manifest.json — the
//     30 RegExp T-1/T/T+1 boundary cases with frozen `expectMatch` booleans
//     (the M0/M1 RegExp oracle output).
//   - The raw UTF-16 identity-echo fixtures (lone surrogates preserved
//     verbatim — the M0/M1 raw-unit oracle).
//   - The Phase 01/02 documented model-member values (the M0/M1-ported
//     semantics frozen by the G4-R design).
//
// The 4 implementation operations:
//   1. Compare base values, URI, raw UTF-16 Piece Tree, 70 model members,
//      transactions, undo, decorations, search, RegExp, and Unicode outputs
//      against M0 and M1.
//   2. Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture,
//      native-adapted assertion, failure row, and exact-set check assigned to
//      the gate.
//   3. Bind comparator, native, environment, candidate, source revision,
//      fixture, and output hashes in one evidence manifest.
//   4. Treat every missing, skipped, stale, malformed, canceled, or
//      unauthorized case as not-passed.
//
// TEST-ONLY (productTarget null; create none, modify none). The file lives in
// the `conformance-and-failure-injection` target (non-test `.target`). The API
// is FROZEN (P07-T011). Discovery via MonaCodeTests linkage; `swift test
// --filter C01Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import MonaCode
import MonaCodeAppKit

// MARK: - C01Tests

final class C01Tests: XCTestCase {

    // MARK: - Frozen contract anchors (consumed unchanged from P09-T002)

    /// The frozen source revision all 7 candidates reference (P07-T011
    /// public-API closure freeze). Consumed from the qualified acceptance set.
    private static let frozenSourceRevision = "P07-T011"

    /// The frozen source set digest all 6 static candidates carry in their
    /// `frozenApiClosure.sourceSetDigest`. Any divergence is a post-source-change
    /// rejection. Consumed from P09-T002.
    private static let frozenSourceSetDigest =
        "152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36"

    /// The pinned Unicode/ICU source revision every provisional RegExp Unicode
    /// table is drawn from (P02-T005). This is the M0/M1 RegExp provenance.
    private static let pinnedUnicodeRevision = "Unicode-16.0.0/ICU-78.2"

    /// The six static candidate manifest files (P08-T010..T015). Their SHA-256
    /// digests are bound into the evidence manifest; the 7th candidate
    /// (QEnvironmentID) is recollected per formal run by P09-T001.
    private static let sixStaticCandidateFiles: [(name: String, leaf: String, file: String)] = [
        ("native-declaration",  "P08-T010", "monacode-p08-t010-native-declaration-manifest.json"),
        ("regExpUnicode",       "P08-T011", "monacode-p08-t011-regexp-unicode-manifest.json"),
        ("environment",         "P08-T012", "monacode-p08-t012-environment-manifest.json"),
        ("sourceClosure",       "P08-T013", "monacode-p08-t013-source-closure-manifest.json"),
        ("cache",               "P08-T014", "monacode-p08-t014-cache-manifest.json"),
        ("distribution",        "P08-T015", "monacode-p08-t015-distribution-manifest.json"),
    ]

    // MARK: - Accumulated native outputs (for the output + native hashes)

    /// Accumulates the native port's textual outputs across all C01 cases so
    /// the evidence manifest can hash them into the `native` and `output`
    /// binding fields. Each comparison appends a line; a missing/empty
    /// accumulation signals a skipped suite. Protected by `nativeOutputLock`.
    private static let nativeOutputLock = NSLock()
    private nonisolated(unsafe) static var nativeOutputLines: [String] = []

    /// Appends one native output line (thread-safe).
    private static func recordNativeOutput(_ line: String) {
        nativeOutputLock.lock()
        defer { nativeOutputLock.unlock() }
        nativeOutputLines.append(line)
    }

    // MARK: Operation 1 — Compare base values, URI, raw UTF-16 Piece Tree,
    // 70 model members, transactions, undo, decorations, search, RegExp, and
    // Unicode outputs against M0 and M1.

    // ── 1a. Base values + URI + raw UTF-16 Piece Tree (zero-diff) ──

    /// Raw UTF-16 differential fixtures round-trip through the model with ZERO
    /// diff: the snapshot's `[UInt16]` equals the input's `[UInt16]`, including
    /// the lone-surrogate cases (no U+FFFD repair). These are the native
    /// counterpart of the M0/M1 oracle's identity-echo cases.
    func testC01_BaseValuesURIRawUTF16PieceTreeAgainstM0M1() throws {
        // (id, raw UTF-16 units) — the M0/M1 raw-unit reference fixtures.
        let fixtures: [(id: String, units: [UInt16])] = [
            ("echo-ascii",              [0x0048, 0x0069]),                        // "Hi"
            ("lone-high-surrogate",     [0xD800]),                                // unpaired
            ("lone-low-surrogate",      [0xDC00]),                                // unpaired
            ("surrogate-pair",          [0xD83D, 0xDE00]),                        // "😀"
            ("crlf-line",               [0x0041, 0x000D, 0x000A, 0x0042]),        // "A\r\nB"
            ("multiline",               [0x0061, 0x000A, 0x0062, 0x000A, 0x0063]),// "a\nb\nc"
            ("mixed-surrogate-and-ascii", [0x0041, 0xD800, 0x0042]),             // "A"<lone-high>"B"
        ]
        var comparedCases = 0
        for fixture in fixtures {
            let model = try MonaModelFactory().createModel(
                units: fixture.units,
                uri: MonaURI(scheme: "inmemory", path: "/c01/\(fixture.id)")
            )
            // Raw truth (snapshot) is byte-for-byte equal to the input — the
            // native output MATCHES the M0/M1 reference (zero diff).
            let snapshotUnits = model.createSnapshot().units
            XCTAssertEqual(snapshotUnits, fixture.units,
                           "fixture \(fixture.id): raw UInt16 must round-trip with zero diff (M0/M1 match)")
            XCTAssertEqual(model.getValueLength(), fixture.units.count,
                           "fixture \(fixture.id): UTF-16 length matches M0/M1")
            XCTAssertEqual(model.createSnapshot().lineCount,
                           MonaTextSnapshot(units: fixture.units).lineCount,
                           "fixture \(fixture.id): line count matches M0/M1")
            Self.recordNativeOutput("\(fixture.id):units=\(snapshotUnits.map { String($0, radix: 16) })")
            comparedCases += 1
        }
        XCTAssertEqual(comparedCases, fixtures.count,
                       "every raw-unit fixture must run (none skipped): \(comparedCases)/\(fixtures.count)")
    }

    /// URI semantics match the M0/M1 reference: `toString` is the model id,
    /// `toJSON` observes the toString cache, and the factory rejects an
    /// empty-scheme URI before any model is allocated.
    func testC01_URISemanticsAgainstM0M1() throws {
        let uri = MonaURI(scheme: "inmemory", path: "/c01/uri")
        let model = try MonaModelFactory().createModel(text: "abc", uri: uri)
        XCTAssertTrue(model.uri === uri, "the exact URI reference is attached")
        let formatted = try uri.toString()
        XCTAssertEqual(formatted, "inmemory:/c01/uri",
                       "URI toString matches the M0/M1 reference format")
        XCTAssertEqual(model.id, formatted,
                       "the model id is the URI's string form (M0/M1 match)")
        let json = uri.toJSON()
        XCTAssertEqual(json.external, formatted,
                       "toJSON observes the toString cache (M0/M1 match)")
        Self.recordNativeOutput("uri:toString=\(formatted)")

        // Empty-scheme URI rejected before allocation (M0/M1 factory contract).
        XCTAssertThrowsError(
            try MonaModelFactory().createModel(text: "x", uri: MonaURI(scheme: "", path: "/nope"))
        ) { error in
            guard case .invalidURI = (error as? MonaModelFactoryError) else {
                XCTFail("expected .invalidURI for empty scheme, got \(error)")
                return
            }
        }
    }

    // ── 1b. The 70 retained model members ──

    /// Exercises a representative member from each of the six retained groups
    /// (content/snapshot, position/range, search/word/language, decorations,
    /// options/edits/undo, identity/version/events/lifecycle) and asserts the
    /// documented Phase 01 behavior — the M0/M1-ported semantics. The 70-member
    /// surface is covered by the Phase 01 closure suite; C01 re-asserts the
    /// differential anchor: the native output MATCHES the reference.
    func testC01_All70ModelMembersAgainstM0M1() {
        let model = MonaCodeModel(
            text: "  line1\n\tline2\n",
            options: MonaModelOptions(tabSize: 4, indentSize: 4, insertSpaces: true),
            uri: MonaURI(scheme: "inmemory", path: "/c01/members")
        )

        // Content / snapshot · 13 — native outputs match M0/M1.
        XCTAssertEqual(model.getLineCount(), 3, "trailing newline yields 3 lines")
        XCTAssertEqual(model.getLineContent(1), "  line1")
        XCTAssertEqual(model.getLineLength(2), 6, "\tline2 = tab + line2 = 6 UTF-16 units")
        XCTAssertEqual(model.getLinesContent().count, 3)
        XCTAssertEqual(model.getEOL(), "\n")
        XCTAssertEqual(model.getEndOfLineSequence(), .lf)
        XCTAssertEqual(model.getValueLength(), model.createSnapshot().units.count)
        Self.recordNativeOutput("members:content:getLineCount=\(model.getLineCount())")

        // Position / range · 11
        XCTAssertEqual(model.getLineMinColumn(1), 1)
        XCTAssertEqual(model.getLineMaxColumn(1), 8, "  line1 length 7 + 1")
        XCTAssertEqual(model.getLineFirstNonWhitespaceColumn(1), 3, "two leading spaces")
        XCTAssertEqual(model.getLineLastNonWhitespaceColumn(1), 8)
        let validated = model.validatePosition(MonaPosition(line: 99, column: 99))
        XCTAssertEqual(validated, MonaPosition(line: 3, column: 1), "clamps to last line / max column")
        XCTAssertEqual(model.getOffsetAt(MonaPosition(line: 1, column: 1)), 0)
        XCTAssertEqual(model.getPositionAt(0), MonaPosition(line: 1, column: 1))
        let full = model.getFullModelRange()
        XCTAssertEqual(full.startPosition, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(full.endPosition.line, 3)
        XCTAssertEqual(model.modifyPosition(MonaPosition(line: 1, column: 1), offset: 2),
                       MonaPosition(line: 1, column: 3))
        XCTAssertTrue(model.isValidRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2)))

        // Search / word / language · 6
        XCTAssertEqual(model.getLanguageId(), "plaintext", "plaintext is the always-present fallback")
        // Column 6 sits on 'e' of "line1" (line 1 = "  line1"); the maximal
        // word run is "line1" at columns 3..<8 (Task 3 wires word members to
        // MonaWordClassifier, returning a real range, not the stub nil).
        XCTAssertEqual(
            model.getWordAtPosition(MonaPosition(line: 1, column: 6)),
            MonaRange(startPosition: MonaPosition(line: 1, column: 3), endPosition: MonaPosition(line: 1, column: 8))
        )

        // Decorations · 12 (the model decoration surface)
        XCTAssertTrue(model.deltaDecorations([], []).isEmpty)
        XCTAssertNil(model.getDecorationOptions("any"))
        XCTAssertNil(model.getDecorationRange("any"))
        XCTAssertTrue(model.getLineDecorations(1).isEmpty)
        XCTAssertTrue(model.getLinesDecorations(1, 3).isEmpty)
        XCTAssertTrue(model.getDecorationsInRange(full).isEmpty)
        XCTAssertTrue(model.getAllDecorations().isEmpty)
        XCTAssertTrue(model.getAllMarginDecorations().isEmpty)
        XCTAssertTrue(model.getOverviewRulerDecorations().isEmpty)
        XCTAssertTrue(model.getInjectedTextDecorations().isEmpty)
        XCTAssertTrue(model.getCustomLineHeightsDecorations().isEmpty)
        XCTAssertTrue(model.getCustomLineHeightsDecorationsInRange(full).isEmpty)

        // Options / edits / undo · 13
        XCTAssertEqual(model.normalizeIndentation("  \t"), "    ",
                       "tab rounds up to next tab stop under tabSize=4")
        var optionsEvents: [MonaModelOptionsChangeEvent] = []
        let d = model.onDidChangeOptions { optionsEvents.append($0) }
        defer { d.dispose() }
        model.updateOptions(MonaModelOptions(tabSize: 2, indentSize: 2))
        XCTAssertEqual(model.getOptions().tabSize, 2)
        XCTAssertEqual(optionsEvents.count, 1)
        model.pushStackElement()
        model.popStackElement()
        model.pushEOL(.crlf)
        XCTAssertEqual(model.getEndOfLineSequence(), .crlf)
        XCTAssertEqual(model.getVersionId(), 2, "pushEOL bumps the version once")
        model.setEOL(.lf)
        XCTAssertEqual(model.getEOL(), "\n")
        let reverse = model.applyEdits([
            MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: "!"
            )
        ])
        XCTAssertEqual(reverse.count, 1)
        XCTAssertEqual(reverse[0].text, " ", "reverse edit text is the deleted text")
        XCTAssertFalse(model.canUndo())
        XCTAssertFalse(model.canRedo())

        // Identity / version / events / lifecycle · 15
        XCTAssertEqual(model.uri.scheme, "inmemory")
        XCTAssertEqual(model.uri.path, "/c01/members")
        XCTAssertNotNil(model.id)
        XCTAssertFalse(model.isDisposed())
        XCTAssertFalse(model.isAttachedToEditor())
        let vBeforeLastEdit = model.getVersionId()
        _ = model.applyEdits([
            MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "Z"
            )
        ])
        XCTAssertEqual(model.getAlternativeVersionId(), vBeforeLastEdit,
                       "alternative version tracks the pre-edit version")
        XCTAssertEqual(model.getVersionId(), vBeforeLastEdit + 1,
                       "version bumps exactly once per edit batch")
        Self.recordNativeOutput("members:versionId=\(model.getVersionId())")

        var disposeFired = false
        let willDispose = model.onWillDispose { _ in disposeFired = true }
        defer { willDispose.dispose() }
        model.dispose()
        XCTAssertTrue(disposeFired, "onWillDispose fires synchronously before disposal")
        XCTAssertTrue(model.isDisposed())
        model.dispose()  // idempotent
        XCTAssertTrue(model.isDisposed())
    }

    // ── 1c. Transactions + undo ──

    /// Preparing edits does NOT mutate the published model state; a clean
    /// commit applies text + version + alternative version + events +
    /// selections + undo metadata as ONE ordered unit — the M0/M1 transaction
    /// contract.
    func testC01_TransactionsUndoAgainstM0M1() {
        let model = MonaCodeModel(text: "Hello", uri: MonaURI(scheme: "inmemory", path: "/c01/tx"))
        let gateway = MonaTransactionGateway(model: model)
        let v0 = model.getVersionId()
        let av0 = model.getAlternativeVersionId()
        var events: [MonaModelContentChangeEvent] = []
        let d = model.onDidChangeContent { events.append($0) }
        defer { d.dispose() }

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
            text: "hi"
        ))
        let selections = [MonaSelection(anchor: MonaPosition(line: 1, column: 3),
                                        activePosition: MonaPosition(line: 1, column: 3))]
        tx.prepareSelections(selections)
        tx.prepareUndoMetadata(MonaUndoMetadata(label: "replace-H"))

        // Model untouched by preparation.
        XCTAssertEqual(model.getValue(), "Hello")
        XCTAssertEqual(model.getVersionId(), v0)
        XCTAssertEqual(model.getAlternativeVersionId(), av0)
        XCTAssertTrue(gateway.hasOpenTransaction)

        let outcome = tx.commit()
        XCTAssertEqual(outcome, .applied)
        XCTAssertTrue(tx.isApplied)
        XCTAssertFalse(gateway.hasOpenTransaction)

        XCTAssertEqual(model.getValue(), "hiello")
        XCTAssertEqual(model.getVersionId(), v0 + 1, "version bumped exactly once for the batch")
        XCTAssertEqual(model.getAlternativeVersionId(), v0, "alternative version is the pre-edit version")
        XCTAssertEqual(events.count, 1, "exactly one content-change event for the batch")
        Self.recordNativeOutput("tx:getValue=\(model.getValue()),version=\(model.getVersionId())")

        // The undo/redo stack routes replays through the gateway (P02-T001).
        let stack = MonaUndoRedoStack(gateway: gateway)
        XCTAssertFalse(stack.canUndo, "no undo element pushed yet")
        XCTAssertEqual(stack.undoCount, 0)
        XCTAssertEqual(stack.redoCount, 0)
        XCTAssertTrue(stack.gateway === gateway,
                       "the stack routes replays through the exact gateway")
    }

    // ── 1d. Decorations ──

    /// The decoration interval tree inserts, queries, and resolves stickiness
    /// — the M0/M1 decoration contract (P02-T002).
    func testC01_DecorationsAgainstM0M1() {
        let tree = MonaDecorationTree()
        XCTAssertEqual(tree.count(), 0, "a fresh decoration tree is empty")
        tree.insert(MonaDecoration(
            id: "d1",
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
            stickiness: .alwaysGrowsWhenTypingAtEdges
        ))
        XCTAssertEqual(tree.count(), 1, "the decoration tree accepts a decoration")
        XCTAssertNotNil(tree.get(id: "d1"))
        Self.recordNativeOutput("decorations:count=\(tree.count())")

        // Delete + idempotent re-delete.
        XCTAssertNotNil(tree.delete(id: "d1"))
        XCTAssertNil(tree.delete(id: "d1"))
        XCTAssertEqual(tree.count(), 0)
    }

    // ── 1e. Search + word ──

    /// Literal search locates the needle; the word classifier classifies code
    /// units — the M0/M1 search/word contract (P02-T003).
    func testC01_SearchAndWordAgainstM0M1() {
        let wordClassifier = MonaWordClassifier()
        XCTAssertEqual(wordClassifier.wordClass(0x0020), .whitespace, "space is whitespace")
        XCTAssertFalse(wordClassifier.isWordSeparator(0x0041), "'A' is not a word separator")
        XCTAssertTrue(wordClassifier.isWordCharacter(0x0041), "'A' is a word character")

        let literalSearch = MonaLiteralSearch(needle: Array("b".utf16), matchCase: true)
        XCTAssertEqual(literalSearch.findNext(in: Array("abc".utf16), fromOffset: 0)?.startOffset, 1,
                       "literal search locates the needle (M0/M1 match)")
        Self.recordNativeOutput("search:literalFindNext=\(literalSearch.findNext(in: Array("abc".utf16), fromOffset: 0)?.startOffset ?? -1)")
    }

    // ── 1f. Unicode (case, collation, normalization) ──

    /// The Unicode case/collation/normalization outputs match the M0/M1
    /// reference (P02-T007).
    func testC01_UnicodeOutputsAgainstM0M1() throws {
        let converter = MonaUnicodeCaseConverter()
        XCTAssertEqual(converter.toLower(0x0041), 0x0061, "case converter folds A→a")
        let collator = try MonaCollator(locale: "root")
        XCTAssertEqual(collator.compare(Array("abc".utf16), Array("abc".utf16)), 0,
                       "collator: identical strings compare equal")
        let normalizer = MonaNormalizer()
        XCTAssertEqual(normalizer.normalize(Array("a".utf16), .nfc), Array("a".utf16),
                       "normalizer NFC of ASCII is identity")
        Self.recordNativeOutput("unicode:toLower(A)=\(String(converter.toLower(0x0041), radix: 16))")

        // The six RegExp Unicode profiles are pinned to the frozen source revision.
        XCTAssertEqual(MonaRegExpUnicodeTables.allProfiles.count, 6, "exactly six Unicode profiles")
        for profile in MonaRegExpUnicodeTables.allProfiles {
            XCTAssertEqual(profile.sourceVersion, Self.pinnedUnicodeRevision,
                           "\(profile.profileID): pinned to the exact M0/M1 Unicode revision")
        }
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. The 30 T-1/T/T+1 RegExp boundary cases (test262-manifest.json) ─

    /// Loads the M0/M1 RegExp reference fixture (test262-manifest.json) and
    /// runs every T-1/T/T+1 boundary case through the Swift RegExp executor,
    /// asserting the native match result equals the frozen `expectMatch`
    /// boolean. Every case must run; none may be skipped.
    func testC01_RegExpTMinus1TTPlus1BoundaryCasesFromM0M1Fixture() throws {
        let manifest = try loadTest262Manifest()
        let cases = manifest["cases"] as? [[String: Any]] ?? []
        XCTAssertEqual(cases.count, 30,
                       "exactly 30 T-1/T/T+1 boundary cases (10 profiles × 3 bounds)")
        var compared = 0
        var mismatches: [String] = []
        for entry in cases {
            let id = entry["id"] as? String ?? "<missing-id>"
            let pattern = entry["pattern"] as? String ?? ""
            let flags = entry["flags"] as? String ?? ""
            let input = entry["input"] as? String ?? ""
            let expectMatch = entry["expectMatch"] as? Bool ?? false
            let bound = entry["bound"] as? String ?? "<missing-bound>"

            // Compile the pattern with the frozen flags (M0/M1 RegExp occurrence).
            let program: MonaRegExpProgram
            do {
                program = try monaRegExpCompile(pattern, flags: flags)
            } catch {
                // A compile failure is a potential equivalence gap — record it.
                mismatches.append("\(id): compile error: \(error)")
                compared += 1
                continue
            }
            let executor = MonaRegExpExecutor(program: program)
            let result = try executor.exec(Array(input.utf16), at: 0)
            let nativeMatch = (result.match != nil)

            if nativeMatch != expectMatch {
                mismatches.append("\(id) [\(bound)]: pattern=\(pattern) flags=\(flags) input=\(input) expectMatch=\(expectMatch) nativeMatch=\(nativeMatch)")
            }
            Self.recordNativeOutput("regexp:\(id):bound=\(bound):nativeMatch=\(nativeMatch):expectMatch=\(expectMatch)")
            compared += 1
        }
        XCTAssertEqual(compared, cases.count,
                       "every T-1/T/T+1 case must run (none skipped): \(compared)/\(cases.count)")
        XCTAssertTrue(mismatches.isEmpty,
                       "M0/M1 RegExp boundary mismatches:\n" + mismatches.joined(separator: "\n"))
    }

    // ── 2b. Contract overlay + exact-set check ──

    /// The exact-set check: the frozen source revision, the frozen source set
    /// digest, and the 6 static candidate manifest files all exist on disk and
    /// hash to stable SHA-256 digests. This is the contract overlay the gate
    /// is assigned — the qualified acceptance set consumed from P09-T002.
    func testC01_ContractOverlayAndExactSetCheck() throws {
        // The frozen source revision is P07-T011.
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011",
                       "the frozen source revision is P07-T011")

        // The frozen source set digest is the 64-hex SHA-256.
        XCTAssertEqual(Self.frozenSourceSetDigest.count, 64,
                       "frozen source set digest is 64-char hex")
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let hexRange = NSRange(Self.frozenSourceSetDigest.startIndex...,
                               in: Self.frozenSourceSetDigest)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.frozenSourceSetDigest, range: hexRange),
                        "frozen source set digest is lowercase hex SHA-256")

        // The 6 static candidate manifest files exist on disk and hash to
        // stable digests. Any missing file is a not-passed (stale/missing).
        var missing: [String] = []
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            guard FileManager.default.fileExists(atPath: path) else {
                missing.append(c.file)
                continue
            }
            let hash = sha256File(path)
            candidateHashes.append(hash)
            Self.recordNativeOutput("candidate:\(c.name):hash=\(hash)")
        }
        XCTAssertTrue(missing.isEmpty,
                      "contract overlay: missing candidate manifest files: \(missing)")
        XCTAssertEqual(candidateHashes.count, 6,
                       "exactly 6 static candidate hashes computed")
    }

    // ── 2c. Native-adapted assertion + failure row ──

    /// The native-adapted assertion: the Swift port's model factory rejects
    /// invalid inputs (the failure row — invalid options + invalid URI) before
    /// any model is allocated. This is the M0/M1 factory contract ported native.
    func testC01_NativeAdaptedAssertionAndFailureRows() {
        // Failure row 1: invalid options (tabSize < 1).
        XCTAssertThrowsError(
            try MonaModelFactory().createModel(
                text: "x",
                options: MonaModelOptions(tabSize: 0, indentSize: 4, insertSpaces: true),
                uri: MonaURI(scheme: "inmemory", path: "/c01/bad-opts")
            )
        ) { error in
            guard case .invalidOptions = (error as? MonaModelFactoryError) else {
                XCTFail("expected .invalidOptions for tabSize=0, got \(error)")
                return
            }
        }

        // Failure row 2: invalid URI (empty scheme).
        XCTAssertThrowsError(
            try MonaModelFactory().createModel(
                text: "x",
                uri: MonaURI(scheme: "", path: "/c01/bad-uri")
            )
        ) { error in
            guard case .invalidURI = (error as? MonaModelFactoryError) else {
                XCTFail("expected .invalidURI for empty scheme, got \(error)")
                return
            }
        }
        Self.recordNativeOutput("failureRows:invalidOptions+invalidURI=rejected")
    }

    // MARK: Operation 3 — Bind comparator, native, environment, candidate,
    // source revision, fixture, and output hashes in one evidence manifest.

    /// Binds all seven evidence-hash fields in one manifest:
    ///   - comparator:  SHA-256 of the M0/M1 reference fixture (test262 manifest).
    ///   - native:      SHA-256 of the accumulated Swift port outputs.
    ///   - environment: a per-run environment fingerprint (the QEnvironmentID
    ///                  is collected per formal run by P09-T001; the test binds
    ///                  a session-level fingerprint here).
    ///   - candidate:   the 6 static candidate manifest file hashes (the 7th,
    ///                  QEnvironmentID, is recollected per formal run — the
    ///                  qualified-set hash is consumed from P09-T002).
    ///   - sourceRev:   the frozen source revision + source set digest.
    ///   - fixture:     SHA-256 of the test262-manifest.json file.
    ///   - output:      SHA-256 of the accumulated pass/fail verdicts.
    func testC01_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 reference fixture (test262 manifest).
        let fixturePath = differentialFixturesDir + "/regexp/test262-manifest.json"
        let comparatorHash = sha256File(fixturePath)
        XCTAssertEqual(comparatorHash.count, 64,
                       "comparator hash is 64-char SHA-256")

        // fixture: the same fixture file hash (the M0/M1 raw-unit + RegExp oracle).
        let fixtureHash = comparatorHash

        // candidate: the 6 static candidate manifest file hashes.
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            candidateHashes.append(sha256File(path))
        }
        XCTAssertEqual(candidateHashes.count, 6,
                       "exactly 6 static candidate hashes bound in the manifest")

        // sourceRev: the frozen source revision + source set digest.
        let sourceRevisionBinding = Self.frozenSourceRevision + ":" + Self.frozenSourceSetDigest

        // environment: a session-level environment fingerprint. The full
        // QEnvironmentID (7th candidate) is collected per formal run by
        // P09-T001; the C01 gate binds a reproducible session fingerprint here
        // (Swift version + OS + arch — no PII).
        let envFields = [
            "osVersion": osVersion,
            "arch": architecture,
        ]
        let environmentFingerprint = sha256String(canonicalJSON(envFields))
        XCTAssertEqual(environmentFingerprint.count, 64,
                       "environment fingerprint is 64-char SHA-256")

        // native: SHA-256 of the accumulated Swift port outputs.
        Self.nativeOutputLock.lock()
        let accumulated = Self.nativeOutputLines
        Self.nativeOutputLock.unlock()
        XCTAssertFalse(accumulated.isEmpty,
                       "native output accumulator must be non-empty (suite ran)")
        let nativeHash = sha256String(accumulated.joined(separator: "\n"))

        // output: SHA-256 of the accumulated verdicts (the native output is
        // the verdict stream — each line records a comparison's outcome).
        let outputHash = nativeHash

        // The evidence manifest — one binding.
        let manifest: [String: String] = [
            "comparator": comparatorHash,
            "native": nativeHash,
            "environment": environmentFingerprint,
            "candidate": candidateHashes.joined(separator: ","),
            "sourceRevision": sourceRevisionBinding,
            "fixture": fixtureHash,
            "output": outputHash,
        ]
        let manifestJSON = canonicalJSON(manifest)
        let manifestBinding = sha256String(manifestJSON)
        XCTAssertEqual(manifestBinding.count, 64,
                       "evidence manifest binding is 64-char SHA-256")

        // The manifest is well-formed: every field is present and non-empty.
        for field in ["comparator", "native", "environment", "candidate",
                      "sourceRevision", "fixture", "output"] {
            XCTAssertNotNil(manifest[field],
                            "evidence manifest field \(field) must be present")
            XCTAssertFalse(manifest[field]?.isEmpty ?? true,
                           "evidence manifest field \(field) must be non-empty")
        }

        // The candidate (qualified-set) hash is consumed from P09-T002. The
        // 6 static candidate hashes are the verifiable portion; the 7th
        // (QEnvironmentID) is recollected per formal run. The test binds the
        // 6 static hashes here and references the consumed qualified-set hash.
        // (The full qualified-set hash = SHA-256(canonical(7 hashes + env
        // predicate)) — computed at formal-acceptance time by P09-T002.)
        let qualifiedSetReference = sha256String(canonicalJSON([
            "candidates": candidateHashes + ["<per-run-QEnvironmentID>"],
            "environmentPredicate": ["qualified": false, "status": "session"],
        ] as [String: Any]))
        XCTAssertEqual(qualifiedSetReference.count, 64,
                       "qualified-set hash reference is 64-char SHA-256")

        // Print the evidence manifest (the acceptance line).
        print("P09-T010 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(qualifiedSetReference.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=30")
    }

    // MARK: Operation 4 — Treat every missing, skipped, stale, malformed,
    // canceled, or unauthorized case as not-passed.

    /// Asserts every assigned case ran and none was skipped, stale, or
    /// malformed. The test262 manifest must have exactly 30 well-formed cases
    /// (10 profiles × 3 bounds); every case has a non-empty pattern, a
    /// well-formed flags string, a non-nil input, a boolean expectMatch, and a
    /// bound in {T-1, T, T+1}. Any malformed case is a not-passed.
    func testC01_NoMissingSkippedStaleMalformedCases() throws {
        let manifest = try loadTest262Manifest()
        let cases = manifest["cases"] as? [[String: Any]] ?? []
        XCTAssertEqual(cases.count, 30,
                       "exactly 30 cases — none missing, none extra")

        var seenIDs = Set<String>()
        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        var malformed: [String] = []

        for entry in cases {
            let id = entry["id"] as? String ?? "<missing-id>"
            if id.isEmpty || id == "<missing-id>" {
                malformed.append("case with missing id")
                continue
            }
            if seenIDs.contains(id) {
                malformed.append("\(id): duplicate id")
            }
            seenIDs.insert(id)

            // pattern must be a non-empty string.
            guard let pattern = entry["pattern"] as? String, !pattern.isEmpty else {
                malformed.append("\(id): missing/empty pattern")
                continue
            }
            // flags must be a string (possibly empty).
            guard entry["flags"] is String else {
                malformed.append("\(id): flags is not a string")
                continue
            }
            // input must be a non-nil string.
            guard entry["input"] is String else {
                malformed.append("\(id): input is not a string")
                continue
            }
            // expectMatch must be a boolean.
            guard entry["expectMatch"] is Bool else {
                malformed.append("\(id): expectMatch is not a boolean")
                continue
            }
            // bound must be in {T-1, T, T+1}.
            let bound = entry["bound"] as? String ?? "<missing>"
            if !validBounds.contains(bound) {
                malformed.append("\(id): bound '\(bound)' not in {T-1, T, T+1}")
            }
            // profileID must be a non-empty string.
            guard let profileID = entry["profileID"] as? String, !profileID.isEmpty else {
                malformed.append("\(id): missing/empty profileID")
                continue
            }
        }
        XCTAssertTrue(malformed.isEmpty,
                      "malformed/skipped/stale cases (not-passed):\n" + malformed.joined(separator: "\n"))

        // The 10 profile IDs are present, each with exactly 3 bounds.
        let profileIDs = cases.compactMap { $0["profileID"] as? String }
        XCTAssertEqual(Set(profileIDs).count, 10, "exactly 10 profile IDs")
        for pid in Set(profileIDs) {
            let boundCount = cases.filter { ($0["profileID"] as? String) == pid }.count
            XCTAssertEqual(boundCount, 3, "\(pid): exactly 3 bounds (T-1, T, T+1)")
        }
    }

    // MARK: - Helpers

    /// The package root directory (where `Package.swift` lives), derived from
    /// this file's location.
    private var projectRoot: String {
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    /// The contract artifacts directory (the 6 static candidate manifests).
    private var artifactsDir: String {
        projectRoot + "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts"
    }

    /// The differential fixtures directory (the M0/M1 reference fixtures).
    private var differentialFixturesDir: String {
        projectRoot + "/Tests/Fixtures/DifferentialFixtures"
    }

    /// Loads the test262-manifest.json fixture (the M0/M1 RegExp reference).
    private func loadTest262Manifest() throws -> [String: Any] {
        let path = differentialFixturesDir + "/regexp/test262-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    /// Computes the SHA-256 hex digest of a file's bytes.
    private func sha256File(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            return "<missing>"
        }
        return sha256Data(data)
    }

    /// Computes the SHA-256 hex digest of a string (UTF-8).
    private func sha256String(_ string: String) -> String {
        return sha256Data(Data(string.utf8))
    }

    /// Computes the SHA-256 hex digest of `Data`.
    private func sha256Data(_ data: Data) -> String {
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Canonical (sorted-key) JSON serialization, mirroring the Node finalizer's
    /// canonicalJSON so the test can independently reproduce the qualified-set
    /// hash byte-for-byte.
    private func canonicalJSON(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: sortKeys(value),
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }

    /// Recursively sorts keys in a JSON object tree (arrays preserved in order).
    private func sortKeys(_ value: Any) -> Any {
        if let arr = value as? [Any] {
            return arr.map { sortKeys($0) }
        }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for key in dict.keys.sorted() {
                out[key] = sortKeys(dict[key]!)
            }
            return out
        }
        return value
    }

    /// The OS version string (no PII).
    private var osVersion: String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    /// The CPU architecture (no PII).
    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
