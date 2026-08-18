// MonaDiffEngineDifferentialTests.swift
//
// P07-T001 — Implement legacy and advanced diff engines over raw UTF-16.
//
// Verifies the diff algorithm core: line hashing, sequence diff, character
// refinement, moved-block detection, inner changes, and result normalization
// for BOTH the legacy and advanced engines, operating over raw `[UInt16]`
// (lone surrogates preserved), with cancellation and timeout checks at the
// frozen algorithm checkpoints.
//
// On Green, `testContractBehavior` prints the contract line:
//     DIFFENGINE legacy=live advanced=live hashing=pass seqdiff=pass charrefine=pass moves=pass inner=pass norm=pass utf16=pass ordering=pass optional=pass cancel=pass timeout=pass

import XCTest
import Foundation
import MonaCode

final class MonaDiffEngineDifferentialTests: XCTestCase {

    // MARK: - Helpers

    /// Converts an array of strings into an array of raw UTF-16 lines.
    private func lines(_ ss: [String]) -> [[UInt16]] {
        return ss.map { Array($0.utf16) }
    }

    /// A mutable wall clock for timeout injection (E1-R wall-clock domain).
    private final class TestWallClock: MonaWallClocking {
        private var ms: Double
        private let step: Double
        init(start: Double = 0, step: Double = 0) {
            self.ms = start
            self.step = step
        }
        func wallMilliseconds() -> Double {
            let current = ms
            ms += step
            return current
        }
    }

    private var defaultOptions: MonaDiffOptions {
        return MonaDiffOptions(maxComputationTimeMs: 5000, ignoreTrimWhitespace: true, computeMoves: false)
    }

    // MARK: - 1. Line hashing + sequence diff (both engines)

    func testLegacyLineHashingAndSequenceDiff() {
        let engine = MonaLegacyDiffEngine()
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        // Line hashing identifies "a"(id0) and "c"(id2) as common; sequence
        // diff (LCS) aligns them. The change is line 2: "b"→"x".
        XCTAssertFalse(result.identical)
        XCTAssertFalse(result.quitEarly)
        XCTAssertEqual(result.changes.count, 1)
        let ch = result.changes[0]
        XCTAssertEqual(ch.originalRange.startPosition, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(ch.originalRange.endPosition, MonaPosition(line: 2, column: 2))
        XCTAssertEqual(ch.modifiedRange.startPosition, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(ch.modifiedRange.endPosition, MonaPosition(line: 2, column: 2))
    }

    func testAdvancedLineHashingAndSequenceDiff() {
        let engine = MonaAdvancedDiffEngine()
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        XCTAssertFalse(result.identical)
        XCTAssertFalse(result.quitEarly)
        XCTAssertEqual(result.changes.count, 1)
        let ch = result.changes[0]
        XCTAssertEqual(ch.originalRange.startPosition, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(ch.originalRange.endPosition, MonaPosition(line: 2, column: 2))
        XCTAssertEqual(ch.modifiedRange.startPosition, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(ch.modifiedRange.endPosition, MonaPosition(line: 2, column: 2))
    }

    // MARK: - 2. Character refinement + inner changes (both engines)

    func testLegacyCharacterRefinementProducesInnerChanges() {
        let engine = MonaLegacyDiffEngine()
        let original = lines(["old text"])
        let modified = lines(["new text"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        XCTAssertEqual(result.changes.count, 1)
        let ch = result.changes[0]
        // Line-level: orig [1,1] → mod [1,1]. "old text" (8 chars) → "new text" (8 chars).
        XCTAssertEqual(ch.originalRange, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 9))
        XCTAssertEqual(ch.modifiedRange, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 9))
        // Character refinement: "old"→"new" (cols 1-3 → 1-3), " text" common.
        XCTAssertEqual(ch.innerChanges.count, 1)
        let inner = ch.innerChanges[0]
        XCTAssertEqual(inner.originalRange, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 4))
        XCTAssertEqual(inner.modifiedRange, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 4))
    }

    func testAdvancedCharacterRefinementProducesInnerChanges() {
        let engine = MonaAdvancedDiffEngine()
        let original = lines(["old text"])
        let modified = lines(["new text"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        XCTAssertEqual(result.changes.count, 1)
        let ch = result.changes[0]
        XCTAssertEqual(ch.originalRange, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 9))
        XCTAssertEqual(ch.modifiedRange, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 9))
        XCTAssertEqual(ch.innerChanges.count, 1)
        let inner = ch.innerChanges[0]
        XCTAssertEqual(inner.originalRange, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 4))
        XCTAssertEqual(inner.modifiedRange, MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 4))
    }

    func testInnerChangesPresentForBothEngines() {
        let original = lines(["abc"])
        let modified = lines(["axc"])
        for engine: MonaDiffEngine in [MonaLegacyDiffEngine(), MonaAdvancedDiffEngine()] {
            let result = engine.compute(
                input: MonaDiffInput(originalLines: original, modifiedLines: modified),
                options: defaultOptions,
                clock: MonaWallClock(),
                cancellationToken: .none
            )
            XCTAssertEqual(result.changes.count, 1, "engine \(type(of: engine))")
            // "abc" → "axc": common "a"(col1) and "c"(col3), change "b"→"x"(col2).
            let inner = result.changes[0].innerChanges
            XCTAssertEqual(inner.count, 1, "engine \(type(of: engine))")
            XCTAssertEqual(inner[0].originalRange, MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 3))
            XCTAssertEqual(inner[0].modifiedRange, MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 3))
        }
    }

    // MARK: - 3. Moved-block detection (advanced only)

    func testAdvancedMovedBlockDetectionWhenComputeMoves() {
        let engine = MonaAdvancedDiffEngine()
        // "b" moves from line 2 to line 4; LCS = [a, c, d].
        let original = lines(["a", "b", "c", "d"])
        let modified = lines(["a", "c", "d", "b"])
        let opts = MonaDiffOptions(maxComputationTimeMs: 5000, ignoreTrimWhitespace: true, computeMoves: true)
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: opts,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        // The moved line "b" is lifted out of changes into moves.
        XCTAssertTrue(result.moves.count >= 1, "advanced with computeMoves must detect at least one move")
        let move = result.moves[0]
        XCTAssertEqual(move.originalRange.startPosition, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(move.originalRange.endPosition, MonaPosition(line: 2, column: 2))
        XCTAssertEqual(move.modifiedRange.startPosition, MonaPosition(line: 4, column: 1))
        XCTAssertEqual(move.modifiedRange.endPosition, MonaPosition(line: 4, column: 2))
    }

    func testAdvancedDoesNotDetectMovesWhenComputeMovesFalse() {
        let engine = MonaAdvancedDiffEngine()
        let original = lines(["a", "b", "c", "d"])
        let modified = lines(["a", "c", "d", "b"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,  // computeMoves = false
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        XCTAssertTrue(result.moves.isEmpty, "advanced without computeMoves must not emit moves")
    }

    func testLegacyHasNoMovedBlocks() {
        let engine = MonaLegacyDiffEngine()
        let original = lines(["a", "b", "c", "d"])
        let modified = lines(["a", "c", "d", "b"])
        let opts = MonaDiffOptions(maxComputationTimeMs: 5000, ignoreTrimWhitespace: true, computeMoves: true)
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: opts,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        XCTAssertTrue(result.moves.isEmpty, "legacy engine must never emit moves")
    }

    // MARK: - 4. Result normalization (sorted, contiguous, deduplicated)

    func testNormalizationProducesSortedNonOverlappingChanges() {
        let engine = MonaLegacyDiffEngine()
        let original = lines(["a", "b", "c", "d", "e"])
        let modified = lines(["x", "y", "c", "z", "e"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        // Two change regions: orig[1,2]→mod[1,2] and orig[4,4]→mod[4,4].
        // Normalization: sorted by original start line, non-overlapping.
        XCTAssertEqual(result.changes.count, 2)
        XCTAssertTrue(result.changes[0].originalRange.startPosition.line
                      <= result.changes[1].originalRange.startPosition.line)
        // The first change ends before the second starts (non-overlapping).
        XCTAssertTrue(result.changes[0].originalRange.endPosition.line
                      < result.changes[1].originalRange.startPosition.line)
    }

    func testNormalizationMergesContiguousChanges() {
        let engine = MonaLegacyDiffEngine()
        // Adjacent line deletions should form one contiguous change block.
        let original = lines(["a", "b", "c", "d"])
        let modified = lines(["a", "d"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        // "b" and "c" deleted → one contiguous change: orig[2,3]→mod[2,2](empty range on mod side).
        // A pure deletion maps the deleted original range to the insertion point in modified.
        XCTAssertEqual(result.changes.count, 1)
        XCTAssertEqual(result.changes[0].originalRange.startPosition, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(result.changes[0].originalRange.endPosition, MonaPosition(line: 3, column: 2))
    }

    // MARK: - 5. Raw UTF-16 (lone surrogate preserved)

    func testRawUTF16LoneSurrogatePreserved() {
        let engine = MonaLegacyDiffEngine()
        // A lone high surrogate (0xD800) as a line, followed by a normal line.
        let original: [[UInt16]] = [[0xD800], [0x0061, 0x0062]]  // [lone-surrogate, "ab"]
        let modified: [[UInt16]] = [[0xD800], [0x0061, 0x0063]]  // [lone-surrogate, "ac"]
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        // Line 1 (lone surrogate) is identical → not in changes.
        // Line 2 "ab"→"ac": change with inner change "b"→"c" at col 2.
        XCTAssertEqual(result.changes.count, 1)
        let ch = result.changes[0]
        XCTAssertEqual(ch.originalRange.startPosition, MonaPosition(line: 2, column: 1))
        XCTAssertEqual(ch.originalRange.endPosition, MonaPosition(line: 2, column: 3))
        XCTAssertEqual(ch.innerChanges.count, 1)
        XCTAssertEqual(ch.innerChanges[0].originalRange, MonaRange(startLine: 2, startColumn: 2, endLine: 2, endColumn: 3))
        XCTAssertEqual(ch.innerChanges[0].modifiedRange, MonaRange(startLine: 2, startColumn: 2, endLine: 2, endColumn: 3))
    }

    func testAdvancedRawUTF16LoneSurrogatePreserved() {
        let engine = MonaAdvancedDiffEngine()
        let original: [[UInt16]] = [[0xD800], [0x0061]]
        let modified: [[UInt16]] = [[0xDC00], [0x0061]]  // lone low surrogate instead
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        // Line 1 differs (0xD800 vs 0xDC00), line 2 identical.
        XCTAssertEqual(result.changes.count, 1)
        XCTAssertEqual(result.changes[0].originalRange.startPosition, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(result.changes[0].originalRange.endPosition, MonaPosition(line: 1, column: 2))
    }

    // MARK: - 6. Comparator ordering + optional fields

    func testComparatorOrderingIsDeterministic() {
        let original = lines(["a", "b", "c", "d", "e"])
        let modified = lines(["a", "x", "c", "y", "e"])
        let legacy = MonaLegacyDiffEngine()
        let advanced = MonaAdvancedDiffEngine()
        let clock = MonaWallClock()
        // Same input → same output (deterministic).
        let r1 = legacy.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions, clock: clock, cancellationToken: .none)
        let r2 = legacy.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions, clock: clock, cancellationToken: .none)
        XCTAssertEqual(r1, r2, "legacy must be deterministic")
        let a1 = advanced.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions, clock: clock, cancellationToken: .none)
        let a2 = advanced.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions, clock: clock, cancellationToken: .none)
        XCTAssertEqual(a1, a2, "advanced must be deterministic")
    }

    func testOptionalFieldsPresenceAbsence() {
        // hitTimeout: false on normal completion; moves: empty for legacy and
        // advanced-without-computeMoves; innerChanges: empty when lines are
        // identical (no refinement), non-empty when a changed pair is refined.
        let identical = lines(["same", "lines"])
        let legacy = MonaLegacyDiffEngine()
        let r = legacy.compute(
            input: MonaDiffInput(originalLines: identical, modifiedLines: identical),
            options: defaultOptions, clock: MonaWallClock(), cancellationToken: .none)
        XCTAssertTrue(r.identical)
        XCTAssertTrue(r.changes.isEmpty)
        XCTAssertTrue(r.moves.isEmpty)
        XCTAssertFalse(r.hitTimeout, "hitTimeout must be false on normal completion")

        // With a change, innerChanges are present (optional field populated).
        let r2 = legacy.compute(
            input: MonaDiffInput(originalLines: lines(["ab"]), modifiedLines: lines(["ac"])),
            options: defaultOptions, clock: MonaWallClock(), cancellationToken: .none)
        XCTAssertFalse(r2.identical)
        XCTAssertEqual(r2.changes.count, 1)
        XCTAssertFalse(r2.changes[0].innerChanges.isEmpty, "innerChanges must be populated when a pair is refined")

        // Advanced without computeMoves: moves absent.
        let advanced = MonaAdvancedDiffEngine()
        let r3 = advanced.compute(
            input: MonaDiffInput(originalLines: lines(["a","b"]), modifiedLines: lines(["a","c"])),
            options: defaultOptions, clock: MonaWallClock(), cancellationToken: .none)
        XCTAssertTrue(r3.moves.isEmpty, "moves must be absent without computeMoves")
    }

    // MARK: - 7. Cancellation at frozen checkpoints (cancelled → abort)

    func testCancellationAbortsAtFirstCheckpoint() {
        let engine = MonaLegacyDiffEngine()
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .cancelled  // already cancelled
        )
        // Cancelled at the first frozen checkpoint → abort: quitEarly true,
        // identical false, no changes, no moves.
        XCTAssertTrue(result.quitEarly)
        XCTAssertFalse(result.identical)
        XCTAssertTrue(result.changes.isEmpty)
        XCTAssertTrue(result.moves.isEmpty)
    }

    func testAdvancedCancellationAbortsAtFirstCheckpoint() {
        let engine = MonaAdvancedDiffEngine()
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .cancelled
        )
        XCTAssertTrue(result.quitEarly)
        XCTAssertFalse(result.identical)
        XCTAssertTrue(result.changes.isEmpty)
        XCTAssertTrue(result.moves.isEmpty)
    }

    // MARK: - 8. Timeout at frozen checkpoints (timed out → abort)

    func testLegacyTimeoutAbortsAtCheckpoint() {
        let engine = MonaLegacyDiffEngine()
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        // Stepping clock: first call (startTime) returns 0, second call (first
        // checkpoint) returns 1000 → elapsed 1000 >= maxComputationTime 100 →
        // timeout.
        let clock = TestWallClock(start: 0, step: 1000)
        let opts = MonaDiffOptions(maxComputationTimeMs: 100, ignoreTrimWhitespace: true, computeMoves: false)
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: opts,
            clock: clock,
            cancellationToken: .none
        )
        XCTAssertTrue(result.quitEarly, "timeout must set quitEarly")
        XCTAssertTrue(result.hitTimeout, "timeout must set hitTimeout")
    }

    func testAdvancedTimeoutAbortsAtCheckpoint() {
        let engine = MonaAdvancedDiffEngine()
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        let clock = TestWallClock(start: 0, step: 1000)
        let opts = MonaDiffOptions(maxComputationTimeMs: 100, ignoreTrimWhitespace: true, computeMoves: false)
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: modified),
            options: opts,
            clock: clock,
            cancellationToken: .none
        )
        XCTAssertTrue(result.quitEarly, "timeout must set quitEarly")
        XCTAssertTrue(result.hitTimeout, "timeout must set hitTimeout")
    }

    // MARK: - 9. Empty fast paths + identical

    func testIdenticalInputReturnsIdentical() {
        let engine = MonaLegacyDiffEngine()
        let original = lines(["hello", "world"])
        let result = engine.compute(
            input: MonaDiffInput(originalLines: original, modifiedLines: original),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        XCTAssertTrue(result.identical)
        XCTAssertFalse(result.quitEarly)
        XCTAssertTrue(result.changes.isEmpty)
        XCTAssertTrue(result.moves.isEmpty)
    }

    func testEmptyFastPathBothSidesEmpty() {
        let engine = MonaAdvancedDiffEngine()
        let empty: [[UInt16]] = [[]]
        let result = engine.compute(
            input: MonaDiffInput(originalLines: empty, modifiedLines: empty),
            options: defaultOptions,
            clock: MonaWallClock(),
            cancellationToken: .none
        )
        XCTAssertTrue(result.identical, "two single empty lines are identical")
        XCTAssertTrue(result.changes.isEmpty)
    }

    // MARK: - Contract behavior print

    func testContractBehavior() {
        // Prove all mechanism slices are live for both engines.
        let legacy = MonaLegacyDiffEngine()
        let advanced = MonaAdvancedDiffEngine()
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        let clock = MonaWallClock()

        // hashing + seqdiff
        let lr = legacy.compute(input: MonaDiffInput(originalLines: original, modifiedLines: modified),
                                options: defaultOptions, clock: clock, cancellationToken: .none)
        let ar = advanced.compute(input: MonaDiffInput(originalLines: original, modifiedLines: modified),
                                  options: defaultOptions, clock: clock, cancellationToken: .none)
        let hashing = (lr.changes.count == 1 && ar.changes.count == 1) ? "pass" : "fail"
        let seqdiff = hashing  // same proof

        // charrefine + inner
        let co = lines(["old text"])
        let cm = lines(["new text"])
        let lcr = legacy.compute(input: MonaDiffInput(originalLines: co, modifiedLines: cm),
                                 options: defaultOptions, clock: clock, cancellationToken: .none)
        let acr = advanced.compute(input: MonaDiffInput(originalLines: co, modifiedLines: cm),
                                   options: defaultOptions, clock: clock, cancellationToken: .none)
        let charrefine = (!lcr.changes.first!.innerChanges.isEmpty && !acr.changes.first!.innerChanges.isEmpty) ? "pass" : "fail"
        let inner = charrefine

        // moves
        let mo = lines(["a", "b", "c", "d"])
        let mm = lines(["a", "c", "d", "b"])
        let moveOpts = MonaDiffOptions(maxComputationTimeMs: 5000, ignoreTrimWhitespace: true, computeMoves: true)
        let am = advanced.compute(input: MonaDiffInput(originalLines: mo, modifiedLines: mm),
                                  options: moveOpts, clock: clock, cancellationToken: .none)
        let moves = (!am.moves.isEmpty) ? "pass" : "fail"

        // norm
        let no = lines(["a", "b", "c", "d"])
        let nm = lines(["x", "y", "c", "z", "d"])
        let ln = legacy.compute(input: MonaDiffInput(originalLines: no, modifiedLines: nm),
                                options: defaultOptions, clock: clock, cancellationToken: .none)
        let norm = (ln.changes.count == 2 && ln.changes[0].originalRange.startPosition.line <= ln.changes[1].originalRange.startPosition.line) ? "pass" : "fail"

        // utf16
        let uo: [[UInt16]] = [[0xD800], [0x0061]]
        let um: [[UInt16]] = [[0xD800], [0x0062]]
        let lu = legacy.compute(input: MonaDiffInput(originalLines: uo, modifiedLines: um),
                                options: defaultOptions, clock: clock, cancellationToken: .none)
        let utf16 = (lu.changes.count == 1) ? "pass" : "fail"

        // ordering
        let r1 = legacy.compute(input: MonaDiffInput(originalLines: original, modifiedLines: modified),
                                options: defaultOptions, clock: clock, cancellationToken: .none)
        let r2 = legacy.compute(input: MonaDiffInput(originalLines: original, modifiedLines: modified),
                                options: defaultOptions, clock: clock, cancellationToken: .none)
        let ordering = (r1 == r2) ? "pass" : "fail"

        // optional
        let optional = (!r1.hitTimeout && r1.moves.isEmpty && !r1.changes.first!.innerChanges.isEmpty) ? "pass" : "fail"

        // cancel
        let lc = legacy.compute(input: MonaDiffInput(originalLines: original, modifiedLines: modified),
                                options: defaultOptions, clock: clock, cancellationToken: .cancelled)
        let cancel = (lc.quitEarly && !lc.identical) ? "pass" : "fail"

        // timeout
        let tclock = TestWallClock(start: 0, step: 1000)
        let topts = MonaDiffOptions(maxComputationTimeMs: 100, ignoreTrimWhitespace: true, computeMoves: false)
        let lt = legacy.compute(input: MonaDiffInput(originalLines: original, modifiedLines: modified),
                                options: topts, clock: tclock, cancellationToken: .none)
        let timeout = (lt.quitEarly && lt.hitTimeout) ? "pass" : "fail"

        print("DIFFENGINE legacy=live advanced=live hashing=\(hashing) seqdiff=\(seqdiff) charrefine=\(charrefine) moves=\(moves) inner=\(inner) norm=\(norm) utf16=\(utf16) ordering=\(ordering) optional=\(optional) cancel=\(cancel) timeout=\(timeout)")
    }
}
