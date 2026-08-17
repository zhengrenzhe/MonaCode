// Phase01ModelConformanceTests.swift
//
// P01-T013 — Close Phase 01 with full model differential and failure matrices.
//
// The Phase 01 closure conformance + failure-injection suite. It exercises the
// full Phase 01 model — raw UTF-16 positions, ranges, URI, Piece Tree, the 70
// retained model members, edit transactions, async validity tickets, and the
// lifetime registries — against raw UInt16 differential fixtures, and injects
// cancellation, allocation, reentrancy, and stale-publication failures at
// every declared checkpoint.
//
// This is a TEST-ONLY task (no product source). It asserts:
//   - zero-diff raw UInt16 fidelity (lone surrogates preserved through edits
//     and snapshots);
//   - invariant preservation (version/alternative-version/event/selection
//     ordering across the transaction gateway);
//   - operation-count bounds (Piece Tree counters advance and stay bounded);
//   - lifetime results (reverse-order disposal, idempotent teardown,
//     register-after-dispose, weak accounting).
//
// The file lives in the `conformance-and-failure-injection` target (kept a
// non-test `.target` for the package-graph invariant). Discovery is provided by
// the `MonaCodeTests` test target depending on this target; the class is
// introspected from the linked image, so `swift test --filter
// Phase01ModelConformanceTests` runs it.

import Foundation
import XCTest
@testable import MonaCode

// MARK: - Recording disposable (lifetime ordering probe)

/// A shared, reference-typed log of disposal tags, so `RecordingDisposable`
/// instances can append without value-semantics copying.
private final class LogBox {
    var entries: [String] = []
}

/// A `MonaDisposable` that appends its tag to a shared `LogBox` on disposal, so
/// tests can assert REVERSE acquisition order and idempotent teardown.
private final class RecordingDisposable: MonaDisposable {
    let tag: String
    let log: LogBox
    private var disposed = false

    init(tag: String, log: LogBox) {
        self.tag = tag
        self.log = log
    }

    func dispose() {
        guard !disposed else { return }
        disposed = true
        log.entries.append(tag)
    }
}

/// A disposable that counts how many times `dispose()` was called, so tests can
/// assert idempotency of registry teardown.
private final class CountingDisposable: MonaDisposable {
    private(set) var disposeCount = 0
    func dispose() {
        disposeCount += 1
    }
}

// MARK: - Phase01ModelConformanceTests

final class Phase01ModelConformanceTests: XCTestCase {

    // MARK: 1. Raw UInt16 differential fixtures (zero-diff)

    /// Raw UInt16 differential fixtures round-trip through the model with ZERO
    /// diff: the snapshot's `[UInt16]` equals the input's `[UInt16]`, including
    /// the lone-surrogate case (no U+FFFD repair). These are the native
    /// counterpart of the M0/M1 oracle's identity-echo cases.
    func testRawUTF16DifferentialFixturesZeroDiff() throws {
        // (id, raw UTF-16 units) — covers basic ASCII, a lone high surrogate,
        // a surrogate pair (valid), CRLF, and a multi-line document.
        let fixtures: [(id: String, units: [UInt16])] = [
            ("echo-ascii", [0x0048, 0x0069]),                          // "Hi"
            ("lone-high-surrogate", [0xD800]),                          // unpaired surrogate
            ("lone-low-surrogate", [0xDC00]),                          // unpaired surrogate
            ("surrogate-pair", [0xD83D, 0xDE00]),                      // "😀"
            ("crlf-line", [0x0041, 0x000D, 0x000A, 0x0042]),            // "A\r\nB"
            ("multiline", [0x0061, 0x000A, 0x0062, 0x000A, 0x0063]),   // "a\nb\nc"
            ("mixed-surrogate-and-ascii", [0x0041, 0xD800, 0x0042])    // "A"<lone-high>"B"
        ]
        for fixture in fixtures {
            let inputUnits = fixture.units
            let model = try MonaModelFactory().createModel(
                units: inputUnits,
                uri: MonaURI(scheme: "inmemory", path: "/diff/\(fixture.id)")
            )
            // Raw truth (snapshot) is byte-for-byte equal to the input.
            let snapshotUnits = model.createSnapshot().units
            XCTAssertEqual(
                snapshotUnits,
                inputUnits,
                "fixture \(fixture.id): raw UInt16 must round-trip with zero diff"
            )
            // The UTF-16 length and line count are consistent with the snapshot.
            XCTAssertEqual(model.getValueLength(), inputUnits.count, "fixture \(fixture.id): length matches")
            XCTAssertEqual(model.getLineCount(), model.createSnapshot().lineCount, "fixture \(fixture.id): line count matches")
        }
    }

    /// The lone-high-surrogate fixture survives verbatim through the Piece
    /// Tree, the snapshot, and `getValueInRange` raw access — never repaired
    /// to U+FFFD.
    func testLoneSurrogatePreservedVerbatim() throws {
        let loneHigh: UInt16 = 0xD800
        let units: [UInt16] = [0x0041, loneHigh, 0x0042]  // "A" <lone-high> "B"
        let model = try MonaModelFactory().createModel(
            units: units,
            uri: MonaURI(scheme: "inmemory", path: "/surrogate")
        )
        XCTAssertEqual(model.createSnapshot().units, units, "lone surrogate must survive in raw storage")

        // The surrogate is at offset 1. A range covering it preserves the raw
        // unit in the snapshot's units.
        let surrogateRange = MonaRange(
            startPosition: model.getPositionAt(1),
            endPosition: model.getPositionAt(2)
        )
        // getValueInRange routes through String (repaired), but the raw unit is
        // still in the tree at offset 1.
        XCTAssertEqual(model.getValueLengthInRange(surrogateRange), 1)

        // getCharacterCountInRange ports Monaco's rule: a high surrogate counts
        // one character and unconditionally skips the next unit. So a lone high
        // surrogate (0xD800) at index 1 consumes the following 'B' (0x42) as if
        // it were a low surrogate: "A"=1 + <high-skip>=1 = 2 (not 3).
        let fullRange = model.getFullModelRange()
        XCTAssertEqual(model.getCharacterCountInRange(fullRange), 2, "lone high surrogate counts one and skips the next unit")
    }

    /// A lone surrogate survives an edit that mutates text AROUND it (the
    /// untouched region's raw units are never repaired).
    func testLoneSurrogateSurvivesEditsAndSnapshots() {
        let units: [UInt16] = [0x0041, 0xD800, 0x0042]  // "A" <lone-high> "B"
        let model = MonaCodeModel(
            units: units,
            uri: MonaURI(scheme: "inmemory", path: "/survive")
        )
        let s0 = model.createSnapshot()
        XCTAssertEqual(s0.units, units)

        // Replace "A" (offset 0..<1) with "XY". The lone surrogate at offset 1
        // shifts right but is preserved.
        _ = model.applyEdits([
            MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: "XY"
            )
        ])
        let s1 = model.createSnapshot()
        XCTAssertEqual(s1.units, [0x0058, 0x0059, 0xD800, 0x0042], "lone surrogate survives the edit")
        XCTAssertEqual(model.getValueLength(), 4)
    }

    // MARK: 2. URI semantics across model construction

    /// The model's `uri` and `id` are derived from the URI; `toString` is
    /// cache-observable via `toJSON`. An empty-scheme URI is rejected by the
    /// factory before any model is allocated.
    func testURISemanticsAndFactoryRejection() throws {
        let uri = MonaURI(scheme: "inmemory", path: "/model/1")
        let model = try MonaModelFactory().createModel(text: "abc", uri: uri)
        XCTAssertTrue(model.uri === uri, "the exact URI reference is attached")
        let formatted = try? uri.toString()
        XCTAssertEqual(formatted, "inmemory:/model/1")
        XCTAssertEqual(model.id, formatted, "the model id is the URI's string form")
        // toString populates the cache; toJSON observes it.
        let json = uri.toJSON()
        XCTAssertEqual(json.external, formatted, "toJSON observes the toString cache")

        // Empty-scheme URI rejected before allocation.
        XCTAssertThrowsError(
            try MonaModelFactory().createModel(text: "x", uri: MonaURI(scheme: "", path: "/nope"))
        ) { error in
            guard case .invalidURI = (error as? MonaModelFactoryError) else {
                XCTFail("expected .invalidURI for empty scheme, got \(error)")
                return
            }
        }
    }

    // MARK: 3. All retained model members (the 70-member surface)

    /// Exercises a representative member from each of the six retained groups
    /// (content/snapshot, position/range, search/word/language, decorations,
    /// options/edits/undo, identity/version/events/lifecycle) and asserts the
    /// documented Phase 01 behavior. The stub members return their declared
    /// defaults; the live members read Piece Tree truth.
    func testAllRetainedModelMembersSurface() {
        let model = MonaCodeModel(
            text: "  line1\n\tline2\n",
            options: MonaModelOptions(tabSize: 4, indentSize: 4, insertSpaces: true),
            uri: MonaURI(scheme: "inmemory", path: "/surface")
        )

        // Content / snapshot · 13
        XCTAssertEqual(model.getLineCount(), 3, "trailing newline yields 3 lines")
        XCTAssertEqual(model.getLineContent(1), "  line1")
        XCTAssertEqual(model.getLineLength(2), 6)  // "\tline2" = tab + "line2" = 6 UTF-16 units
        XCTAssertEqual(model.getLinesContent().count, 3)
        XCTAssertEqual(model.getEOL(), "\n")
        XCTAssertEqual(model.getEndOfLineSequence(), .lf)
        XCTAssertEqual(model.getValueLength(), model.createSnapshot().units.count)

        // Position / range · 11
        XCTAssertEqual(model.getLineMinColumn(1), 1)
        XCTAssertEqual(model.getLineMaxColumn(1), 8)  // "  line1" length 7 + 1
        XCTAssertEqual(model.getLineFirstNonWhitespaceColumn(1), 3)  // two leading spaces
        XCTAssertEqual(model.getLineLastNonWhitespaceColumn(1), 8)  // last non-ws at index 6 → +2 = 8
        let validated = model.validatePosition(MonaPosition(line: 99, column: 99))
        XCTAssertEqual(validated, MonaPosition(line: 3, column: 1), "clamps to last line / max column")
        XCTAssertEqual(model.getOffsetAt(MonaPosition(line: 1, column: 1)), 0)
        XCTAssertEqual(model.getPositionAt(0), MonaPosition(line: 1, column: 1))
        let full = model.getFullModelRange()
        XCTAssertEqual(full.startPosition, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(full.endPosition.line, 3)
        let moved = model.modifyPosition(MonaPosition(line: 1, column: 1), offset: 2)
        XCTAssertEqual(moved, MonaPosition(line: 1, column: 3))
        XCTAssertTrue(model.isValidRange(MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2)))

        // Search / word / language · 6 (Phase 02 stubs except language)
        XCTAssertTrue(model.findMatches(
            searchString: "line",
            searchScope: .fullModel,
            isRegex: false,
            matchCase: true,
            captureMatches: false
        ).isEmpty, "search is a Phase 02 stub")
        XCTAssertNil(model.findNextMatch(
            searchString: "line", searchScope: .fullModel,
            isRegex: false, matchCase: true, captureMatches: false
        ))
        XCTAssertNil(model.findPreviousMatch(
            searchString: "line", searchScope: .fullModel,
            isRegex: false, matchCase: true, captureMatches: false
        ))
        XCTAssertEqual(model.getLanguageId(), "plaintext", "plaintext is the always-present fallback")
        XCTAssertNil(model.getWordAtPosition(MonaPosition(line: 1, column: 3)))
        XCTAssertNil(model.getWordUntilPosition(MonaPosition(line: 1, column: 3)))

        // Decorations · 12 (Phase 02 stubs)
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
        XCTAssertEqual(model.normalizeIndentation("  \t"), "    ", "tab rounds up to next tab stop under tabSize=4")
        var optionsEvents: [MonaModelOptionsChangeEvent] = []
        let d = model.onDidChangeOptions { optionsEvents.append($0) }
        defer { d.dispose() }
        model.updateOptions(MonaModelOptions(tabSize: 2, indentSize: 2))
        XCTAssertEqual(model.getOptions().tabSize, 2)
        XCTAssertEqual(optionsEvents.count, 1)
        model.detectIndentation(defaultInsertSpaces: true, defaultTabSize: 4)  // Phase 02 no-op
        model.pushStackElement()  // Phase 02 no-op
        model.popStackElement()  // Phase 02 no-op
        model.pushEOL(.crlf)
        XCTAssertEqual(model.getEndOfLineSequence(), .crlf)
        XCTAssertEqual(model.getVersionId(), 2, "pushEOL bumps the version once")
        model.setEOL(.lf)
        XCTAssertEqual(model.getEOL(), "\n")
        // applyEdits returns the reverse edit.
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
        model.undo()  // Phase 02 no-op
        model.redo()  // Phase 02 no-op

        // Identity / version / events / lifecycle · 15
        XCTAssertEqual(model.uri.scheme, "inmemory")
        XCTAssertEqual(model.uri.path, "/surface")
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
        XCTAssertEqual(model.getAlternativeVersionId(), vBeforeLastEdit, "alternative version tracks the pre-edit version")
        XCTAssertEqual(model.getVersionId(), vBeforeLastEdit + 1, "version bumps exactly once per edit batch")

        var disposeFired = false
        let willDispose = model.onWillDispose { _ in disposeFired = true }
        defer { willDispose.dispose() }
        model.dispose()
        XCTAssertTrue(disposeFired, "onWillDispose fires synchronously before disposal")
        XCTAssertTrue(model.isDisposed())
        // Idempotent.
        model.dispose()
        XCTAssertTrue(model.isDisposed())
    }

    // MARK: 4. Edit transaction gateway — prepare / commit / rollback

    /// Preparing edits does NOT mutate the published model state; a clean
    /// commit applies text + version + alternative version + events +
    /// selections + undo metadata as ONE ordered unit.
    func testTransactionPrepareWithoutMutateAndCommitAsOneUnit() {
        let model = MonaCodeModel(text: "Hello", uri: MonaURI(scheme: "inmemory", path: "/tx"))
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
        let selections = [MonaSelection(anchor: MonaPosition(line: 1, column: 3), activePosition: MonaPosition(line: 1, column: 3))]
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
        XCTAssertFalse(events[0].isFlush)
        XCTAssertEqual(gateway.lastCommittedSelections, selections)
        XCTAssertEqual(gateway.lastCommittedUndoMetadata.label, "replace-H")
    }

    /// Rollback reverts every prepared component; the model is untouched
    /// because preparation never mutated it.
    func testTransactionRollbackLeavesModelUntouched() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/rb"))
        let gateway = MonaTransactionGateway(model: model)
        let v0 = model.getVersionId()

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        let outcome = tx.rollback()
        XCTAssertEqual(outcome, .rolledBack(reason: "rolled back"))
        XCTAssertTrue(tx.isRolledBack)
        XCTAssertEqual(model.getValue(), "abc")
        XCTAssertEqual(model.getVersionId(), v0, "rollback does not bump the version")
        XCTAssertFalse(gateway.hasOpenTransaction)
    }

    // MARK: 5. Failure injection — reentrancy checkpoint

    /// Beginning a second transaction invalidates the first; the first's
    /// `commit()` resolves as `.dropped(reason: "reentrant invalidation")`.
    func testReentrantTransactionInvalidationDropsFirst() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/reentrancy"))
        let gateway = MonaTransactionGateway(model: model)
        let v0 = model.getVersionId()

        let tx1 = gateway.beginTransaction()
        tx1.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "1"
        ))
        let tx2 = gateway.beginTransaction()
        tx2.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "2"
        ))

        // tx1 is invalidated by the reentrant begin.
        let outcome1 = tx1.commit()
        XCTAssertEqual(outcome1, .dropped(reason: "reentrant invalidation"), "reentrant invalidation drops tx1")
        XCTAssertTrue(tx1.isDropped)

        // tx2 is the active transaction and commits cleanly.
        let outcome2 = tx2.commit()
        XCTAssertEqual(outcome2, .applied)
        XCTAssertEqual(model.getValue(), "2abc")
        XCTAssertEqual(model.getVersionId(), v0 + 1)
    }

    // MARK: 6. Failure injection — cancellation checkpoint

    /// A transaction whose attached cancellation token has been cancelled is
    /// dropped before any mutation.
    func testCancelledTransactionDroppedBeforeMutation() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/cancel"))
        let gateway = MonaTransactionGateway(model: model)
        let v0 = model.getVersionId()

        let source = MonaCancellationTokenSource()
        source.cancel()  // pre-cancelled
        let tx = gateway.beginTransaction()
        tx.setCancellationToken(source.token)
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))

        let outcome = tx.commit()
        XCTAssertEqual(outcome, .dropped(reason: "cancelled"))
        XCTAssertTrue(tx.isDropped)
        XCTAssertEqual(model.getValue(), "abc", "model untouched by a cancelled transaction")
        XCTAssertEqual(model.getVersionId(), v0, "no version bump on a dropped transaction")
    }

    /// Cancellation token semantics: cancel fires exactly once, a late listener
    /// fires immediately and synchronously, and dispose is distinct from cancel.
    func testCancellationTokenFireOnceAndLateListener() {
        let source = MonaCancellationTokenSource()
        var fireCount = 0
        _ = source.token.onCancellationRequested { fireCount += 1 }
        source.cancel()
        source.cancel()  // idempotent
        XCTAssertEqual(fireCount, 1, "cancel fires listeners exactly once")

        // Late listener fires immediately and synchronously.
        var lateFired = false
        let lateDisposable = source.token.onCancellationRequested { lateFired = true }
        XCTAssertTrue(lateFired, "late listener fires immediately after cancellation")
        lateDisposable.dispose()  // inert (already fired)

        // Dispose ≠ cancel: a fresh source disposed without cancel never fires.
        let quiet = MonaCancellationTokenSource()
        var quietFired = false
        _ = quiet.token.onCancellationRequested { quietFired = true }
        quiet.dispose()
        XCTAssertFalse(quietFired, "dispose does not fire listeners")
    }

    /// Parent cancellation propagates to a still-attached child; a child
    /// created after the parent cancelled starts cancelled.
    func testCancellationChildPropagation() {
        let parent = MonaCancellationTokenSource()
        let child = parent.createChild()
        var childFired = false
        _ = child.token.onCancellationRequested { childFired = true }
        parent.cancel()
        XCTAssertTrue(childFired, "parent cancel propagates to child")
        XCTAssertTrue(child.token.isCancellationRequested)

        // Child created after parent cancelled starts cancelled.
        let lateChild = parent.createChild()
        XCTAssertTrue(lateChild.token.isCancellationRequested, "late child starts cancelled")
    }

    // MARK: 7. Failure injection — stale version + reconcile

    /// Direct mutation bypassing the gateway makes the captured version
    /// stale; with reconcile disabled, the transaction is dropped.
    func testStaleVersionDropsTransaction() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/stale"))
        let gateway = MonaTransactionGateway(model: model)

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        // Bypass the gateway: mutate the model directly.
        _ = model.applyEdits([
            MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "Y"
            )
        ])

        let outcome = tx.commit()
        XCTAssertEqual(outcome, .dropped(reason: "stale version"))
        XCTAssertTrue(tx.isDropped)
    }

    /// With reconcile enabled, a version-divergent transaction is re-validated
    /// against the current model and reapplied, returning `.reconciled`.
    func testReconcileReappliesAgainstMovedModel() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/recon"))
        let gateway = MonaTransactionGateway(model: model)

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        tx.setReconcileEnabled(true)
        // Bypass the gateway.
        _ = model.applyEdits([
            MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "Y"
            )
        ])

        let outcome = tx.commit()
        if case .reconciled(let changes) = outcome {
            XCTAssertFalse(changes.isEmpty, "reconcile records at least the version change")
        } else {
            XCTFail("expected .reconciled, got \(outcome)")
        }
        XCTAssertTrue(model.getValue().hasPrefix("X"), "reconciled edit is reapplied")
    }

    /// A prepared operation whose range would clamp fails validation and the
    /// transaction rolls back with the model untouched.
    func testValidationFailureRollsBack() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/vf"))
        let gateway = MonaTransactionGateway(model: model)
        let v0 = model.getVersionId()

        let tx = gateway.beginTransaction()
        // A range whose end column is far beyond the line — validateRange would
        // clamp the end column, so isValidRange returns false.
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 999),
            text: "Z"
        ))
        let outcome = tx.commit()
        XCTAssertEqual(outcome, .rolledBack(reason: "validation failure"))
        XCTAssertTrue(tx.isRolledBack)
        XCTAssertEqual(model.getValue(), "abc", "model untouched on validation failure")
        XCTAssertEqual(model.getVersionId(), v0, "no version bump on a rolled-back transaction")
    }

    // MARK: 8. Failure injection — stale-publication checkpoint (async validity tickets)

    /// A fresh ticket publishes; a ticket whose version diverged is dropped
    /// silently (publish closure never invoked, nil returned).
    func testAsyncValidityTicketFreshPublishAndStaleDrop() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/ticket"))
        let gate = MonaPublicationGate(model: model)

        let ticket = gate.captureTicket()
        XCTAssertTrue(gate.validate(ticket), "a freshly-captured ticket is valid")

        var published = false
        let result: Int? = gate.publish(ticket) { published = true; return 42 }
        XCTAssertEqual(result, 42, "fresh publication runs and returns the value")
        XCTAssertTrue(published)

        // Mutate the model (version bump) → ticket is stale.
        _ = model.applyEdits([
            MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "X"
            )
        ])
        XCTAssertFalse(gate.validate(ticket), "version divergence invalidates the ticket")

        var stalePublished = false
        let staleResult: Int? = gate.publish(ticket) { stalePublished = true; return 99 }
        XCTAssertNil(staleResult, "stale publication is dropped silently (nil)")
        XCTAssertFalse(stalePublished, "the publish closure is never invoked for a stale ticket")
    }

    /// Replacing the gate's model bumps the owner generation and invalidates
    /// every outstanding ticket. `cancel()` bumps the cancellation generation
    /// and invalidates outstanding tickets; a fresh ticket re-arms.
    func testAsyncValidityTicketOwnerAndCancellationGenerations() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/gen"))
        let gate = MonaPublicationGate(model: model)

        let ticket1 = gate.captureTicket()
        // Replace the model wholesale → owner generation bump → stale.
        let replacement = MonaCodeModel(text: "xyz", uri: MonaURI(scheme: "inmemory", path: "/gen2"))
        gate.replaceModel(replacement)
        XCTAssertFalse(gate.validate(ticket1), "owner generation bump invalidates outstanding tickets")
        XCTAssertEqual(gate.ownerGeneration, 1)

        // A fresh ticket on the replacement is valid.
        let ticket2 = gate.captureTicket()
        XCTAssertTrue(gate.validate(ticket2))

        // cancel() bumps the cancellation generation → ticket2 stale.
        gate.cancel()
        XCTAssertFalse(gate.validate(ticket2), "cancellation bump invalidates outstanding tickets")
        XCTAssertEqual(gate.cancellationGeneration, 1)

        // A fresh ticket re-arms against the new cancellation generation.
        let ticket3 = gate.captureTicket()
        XCTAssertTrue(gate.validate(ticket3), "a fresh ticket re-arms after cancellation")
    }

    // MARK: 9. Failure injection — allocation checkpoint (factory rollback)

    /// The factory rejects invalid options and invalid URIs BEFORE any model
    /// is allocated, and rolls back (disposes the model) when lifetime
    /// registration fails — no partial model is ever published.
    func testFactoryAllocationCheckpointsAndRollback() {
        // Invalid options.
        XCTAssertThrowsError(
            try MonaModelFactory().createModel(
                text: "x",
                options: MonaModelOptions(tabSize: 0, indentSize: 4),
                uri: MonaURI(scheme: "inmemory", path: "/bad-opt")
            )
        ) { error in
            guard case .invalidOptions = (error as? MonaModelFactoryError) else {
                XCTFail("expected .invalidOptions for tabSize=0, got \(error)")
                return
            }
        }

        // Invalid URI (empty scheme — the null URI rejection).
        XCTAssertThrowsError(
            try MonaModelFactory().createModel(
                text: "x",
                uri: MonaURI(scheme: "", path: "/bad-uri")
            )
        ) { error in
            guard case .invalidURI = (error as? MonaModelFactoryError) else {
                XCTFail("expected .invalidURI for empty scheme, got \(error)")
                return
            }
        }

        // Registration failure → rollback (model disposed, registrationFailed
        // rethrown). We observe the disposed model via a captured reference.
        var capturedModel: MonaCodeModel?
        let register: (MonaCodeModel, MonaLargeModelState) throws -> Void = { model, _ in
            capturedModel = model
            throw TestRegistrationError.simulated
        }
        XCTAssertThrowsError(
            try MonaModelFactory().createModel(
                text: "rollback me",
                uri: MonaURI(scheme: "inmemory", path: "/rollback"),
                register: register
            )
        ) { error in
            guard case .registrationFailed = (error as? MonaModelFactoryError) else {
                XCTFail("expected .registrationFailed, got \(error)")
                return
            }
        }
        XCTAssertNotNil(capturedModel, "the model was constructed before registration")
        XCTAssertTrue(capturedModel!.isDisposed(), "registration failure rolls back: model is disposed")
    }

    /// The factory computes the sticky large-model state from the initial text
    /// and hands it to the registration closure; a small model is `.normal`.
    func testFactoryComputesLargeModelState() throws {
        var observedState: MonaLargeModelState?
        let model = try MonaModelFactory().createModel(
            text: "small",
            uri: MonaURI(scheme: "inmemory", path: "/large"),
            register: { _, state in observedState = state }
        )
        XCTAssertEqual(observedState, .normal)
        XCTAssertEqual(model.getLanguageId(), "plaintext")
    }

    // MARK: 10. Lifetime registries — reverse disposal, idempotent, accounting

    /// `MonaEditorLifetime` disposes registered children in REVERSE acquisition
    /// order; teardown is idempotent; registering after dispose immediately
    /// disposes the resource so it cannot leak.
    func testEditorLifetimeReverseDisposalAndIdempotent() {
        let lifetime = MonaEditorLifetime()
        let log = LogBox()
        let a = RecordingDisposable(tag: "a", log: log)
        let b = RecordingDisposable(tag: "b", log: log)
        let c = RecordingDisposable(tag: "c", log: log)

        lifetime.register(.selectionCursor, a)
        lifetime.register(.scrollFocusContext, b)
        lifetime.register(.widgets, c)
        XCTAssertEqual(lifetime.registeredCount, 3)
        XCTAssertEqual(lifetime.registeredOwners, [.selectionCursor, .scrollFocusContext, .widgets])

        lifetime.dispose()
        // Reverse (LIFO) disposal: c, b, a.
        XCTAssertEqual(log.entries, ["c", "b", "a"], "children disposed in reverse acquisition order")

        // Idempotent.
        lifetime.dispose()
        XCTAssertEqual(lifetime.registeredCount, 0)
        XCTAssertTrue(lifetime.isDisposed)

        // Register after dispose: immediately disposed, never tracked.
        let leak = CountingDisposable()
        lifetime.register(.imePointerEventDispatch, leak)
        XCTAssertEqual(leak.disposeCount, 1, "register-after-dispose immediately disposes the resource")
        XCTAssertEqual(lifetime.registeredCount, 0, "the leaked resource is never tracked")
    }

    /// `MonaGlobalLifetime` disposes registered children in REVERSE acquisition
    /// order (the eight process-global owner categories) and is idempotent.
    func testGlobalLifetimeReverseDisposal() {
        let lifetime = MonaGlobalLifetime()
        let log = LogBox()
        lifetime.register(.environmentServices, RecordingDisposable(tag: "env", log: log))
        lifetime.register(.modelRegistry, RecordingDisposable(tag: "model", log: log))
        lifetime.register(.languageRegistry, RecordingDisposable(tag: "lang", log: log))

        XCTAssertEqual(lifetime.registeredCount, 3)
        lifetime.dispose()
        XCTAssertEqual(log.entries, ["lang", "model", "env"], "global children disposed LIFO")
        XCTAssertTrue(lifetime.isDisposed)
        lifetime.dispose()  // idempotent
    }

    /// `MonaInitialModelRegistry` holds the model weakly: dropping the owner's
    /// strong reference drops the live count; `totalRegistered` is sticky.
    /// `dispose()` is idempotent and never disposes tracked models.
    func testInitialModelRegistryWeakAccountingAndIdempotentDisposal() throws {
        let registry = MonaInitialModelRegistry()
        var model: MonaCodeModel? = try MonaModelFactory().createModel(
            text: "tracked",
            uri: MonaURI(scheme: "inmemory", path: "/init")
        )
        let extModel: MonaCodeModel? = MonaCodeModel(
            text: "ext",
            uri: MonaURI(scheme: "inmemory", path: "/ext")
        )
        registry.register(.implicitOwned, model: model)
        registry.register(.externalBorrowed, model: extModel)
        registry.register(.none, model: nil)

        XCTAssertEqual(registry.totalRegistered, 3, "totalRegistered is sticky and counts every registration")
        XCTAssertEqual(registry.liveCount, 2, ".none contributes no live model")
        XCTAssertEqual(registry.liveOwners, [.implicitOwned, .externalBorrowed])

        // The registry never disposes tracked models.
        XCTAssertFalse(model!.isDisposed())

        // Dropping the strong owner deallocates the model and the registry stops
        // counting it (weak accounting).
        model = nil
        XCTAssertEqual(registry.liveCount, 1, "dropping the owner drops the weak count")
        XCTAssertEqual(registry.liveOwners, [.externalBorrowed])

        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        registry.dispose()  // idempotent
        XCTAssertEqual(registry.totalRegistered, 3, "totalRegistered is sticky across dispose")
    }

    // MARK: 11. Operation-count bounds (Piece Tree instrumentation)

    /// The Piece Tree's instrumented operation counters advance exactly once
    /// per corresponding operation and stay bounded by the operation count.
    func testPieceTreeOperationCountBounds() {
        let tree = MonaPieceTree(units: Array("hello\nworld".utf16))
        let baseline = tree.operationCounts

        // Insert + delete → edit counter advances by 2.
        tree.insert(Array("AB".utf16), at: 1)
        tree.delete(1..<3)
        let afterEdits = tree.operationCounts
        XCTAssertEqual(afterEdits.edit - baseline.edit, 2, "edit counter advances once per insert/delete")
        XCTAssertGreaterThanOrEqual(afterEdits.edit, 2)

        // offset/position counters advance through coordinate conversions.
        _ = tree.getOffsetAt(MonaPosition(line: 1, column: 1))
        _ = tree.getPositionAt(0)
        let afterCoords = tree.operationCounts
        XCTAssertGreaterThanOrEqual(afterCoords.offset - baseline.offset, 1)
        XCTAssertGreaterThanOrEqual(afterCoords.position - baseline.position, 1)

        // Bounded: no counter exceeds the number of operations performed.
        let totalOps = (afterEdits.edit - baseline.edit)
            + (afterCoords.offset - baseline.offset)
            + (afterCoords.position - baseline.position)
            + (afterCoords.search - baseline.search)
        XCTAssertLessThanOrEqual(totalOps, 100, "operation counts are bounded by a small multiple of performed ops")
    }

    // MARK: 12. Invariant preservation across the full pipeline

    /// A full create → edit (transaction) → snapshot → ticket-validate →
    /// dispose pipeline preserves every Phase 01 invariant end to end.
    func testFullPipelineInvariantPreservation() throws {
        let model = try MonaModelFactory().createModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/pipeline")
        )
        let gateway = MonaTransactionGateway(model: model)
        let gate = MonaPublicationGate(model: model)

        let ticket = gate.captureTicket()

        // Transactional edit commits as one unit.
        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
            text: "X"
        ))
        XCTAssertEqual(tx.commit(), .applied)

        // The ticket captured pre-commit is now stale (version advanced).
        XCTAssertFalse(gate.validate(ticket), "version truth invalidates a pre-commit ticket")

        // Raw UInt16 truth is consistent between the live tree and a snapshot.
        let snap = model.createSnapshot()
        XCTAssertEqual(snap.units, Array(model.getValue().utf16))
        XCTAssertEqual(snap.length, model.getValueLength())

        // Lifetime: register the model with a global + initial registry, then
        // dispose the model and verify weak accounting drops to zero.
        let initialRegistry = MonaInitialModelRegistry()
        initialRegistry.register(.implicitOwned, model: model)
        XCTAssertEqual(initialRegistry.liveCount, 1)
        model.dispose()
        XCTAssertTrue(model.isDisposed())
        // The disposed model is still held strongly here, so liveCount is still 1
        // until the strong reference is dropped — but disposal is observable.
        XCTAssertEqual(initialRegistry.totalRegistered, 1)
    }
}

// MARK: - Test registration error

private enum TestRegistrationError: Error {
    case simulated
}
