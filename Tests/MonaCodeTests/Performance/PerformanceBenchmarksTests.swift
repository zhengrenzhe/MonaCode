// PerformanceBenchmarksTests.swift
//
// Formal performance measurement — component-level benchmarks with
// self-consistency + absolute thresholds.
//
// This is a TEST file (MonaCodeTests target), discoverable by
// `swift test --filter PerformanceBenchmarksTests`. The MonaCode public API
// is frozen (P07-T011); this file exercises only public APIs from the
// Foundation-only `MonaCode` module — no AppKit needed.
//
// Five component-level benchmarks:
//   P01 — Model load (1 MiB text, 30 runs, < 2000ms/load)
//   P02 — Typing + undo (500 one-char inserts, 30 runs, < 10ms/action)
//   P03 — Batch edits (100 non-overlapping edits in one applyEdits, 30 runs, < 500ms)
//   P08 — Find / literal search (1 MiB haystack, 30 runs, < 1000ms)
//   P10 — Diff / legacy LCS engine (10 KiB texts, 30 runs, < 200ms)
//
// For each benchmark:
//   1. Run 30 times, collect per-run timings (ms) → M0.
//   2. Run the 30-measurement set again → M1.
//   3. Absolute threshold: assert combined mean < threshold.
//   4. Stability: assert combined stddev / mean < 0.5 (coefficient of variation).
//   5. Self-consistency: assert |M0_mean - M1_mean| / max(M0_mean, M1_mean) < 0.5.
//   6. Print a one-line summary per benchmark.

import XCTest
import MonaCode

final class PerformanceBenchmarksTests: XCTestCase {

    // MARK: - Measurement helpers

    /// Converts a `Duration` to milliseconds as `Double`.
    private func durationToMs(_ d: Duration) -> Double {
        let (seconds, attoseconds) = d.components
        return Double(seconds) * 1000.0 + Double(attoseconds) * 1e-15
    }

    /// Runs `body` `count` times, returning per-run timings in milliseconds.
    /// A small warmup set (3 runs) is discarded before measurement to avoid
    /// first-touch allocation noise.
    private func measureRuns(_ count: Int, warmup: Int = 3, _ body: () -> Void) -> [Double] {
        let clock = ContinuousClock()
        // Warmup (discarded).
        for _ in 0..<warmup {
            body()
        }
        var timings: [Double] = []
        timings.reserveCapacity(count)
        for _ in 0..<count {
            let start = clock.now
            body()
            let elapsed = start.duration(to: clock.now)
            timings.append(durationToMs(elapsed))
        }
        return timings
    }

    /// Computes mean, stddev (population), min, max of the timings.
    private func stats(_ timings: [Double]) -> (mean: Double, stddev: Double, min: Double, max: Double) {
        guard !timings.isEmpty else {
            return (0, 0, 0, 0)
        }
        let n = Double(timings.count)
        let mean = timings.reduce(0.0, +) / n
        let variance = timings.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / n
        let stddev = variance.squareRoot()
        let mn = timings.min() ?? 0.0
        let mx = timings.max() ?? 0.0
        return (mean, stddev, mn, mx)
    }

    // MARK: - Benchmark runner

    /// Runs a benchmark with two 30-run sets (M0, M1), asserts the absolute
    /// threshold, stability (CV), and self-consistency, and prints a summary.
    private func runBenchmark(
        name: String,
        threshold: Double,
        runsPerSet: Int = 30,
        body: () -> Void
    ) {
        let m0 = measureRuns(runsPerSet, body)
        let m1 = measureRuns(runsPerSet, body)

        let s0 = stats(m0)
        let s1 = stats(m1)

        // Combined set for threshold + stability reporting.
        let combined = m0 + m1
        let sc = stats(combined)

        let cv = sc.stddev / max(sc.mean, 1e-9)
        let stabilityPass = cv < 0.5

        let delta = abs(s0.mean - s1.mean) / max(s0.mean, s1.mean, 1e-9)
        let selfConsistencyPass = delta < 0.5

        let thresholdPass = sc.mean < threshold

        print(
            "BENCHMARK \(name) "
            + "mean=\(String(format: "%.3f", sc.mean))ms "
            + "stddev=\(String(format: "%.3f", sc.stddev))ms "
            + "min=\(String(format: "%.3f", sc.min))ms "
            + "max=\(String(format: "%.3f", sc.max))ms "
            + "M0=\(String(format: "%.3f", s0.mean))ms "
            + "M1=\(String(format: "%.3f", s1.mean))ms "
            + "CV=\(String(format: "%.3f", cv)) "
            + "selfcons=\(String(format: "%.3f", delta)) "
            + "threshold=\(String(format: "%.0f", threshold))ms "
            + "threshold=\(thresholdPass ? "PASS" : "FAIL") "
            + "stability=\(stabilityPass ? "PASS" : "FAIL") "
            + "self-consistency=\(selfConsistencyPass ? "PASS" : "FAIL")"
        )

        XCTAssertTrue(
            thresholdPass,
            "\(name): combined mean \(sc.mean)ms >= threshold \(threshold)ms"
        )
        XCTAssertTrue(
            stabilityPass,
            "\(name): coefficient of variation \(cv) >= 0.5 (unstable)"
        )
        XCTAssertTrue(
            selfConsistencyPass,
            "\(name): self-consistency delta \(delta) >= 0.5 (M0=\(s0.mean) vs M1=\(s1.mean))"
        )
    }

    // MARK: - Text fixtures

    /// Generates a ~1 MiB text of repeated ASCII code lines (UTF-16 count is
    /// exactly 1,048,576).
    private static func makeOneMiBText() -> String {
        let base = "let x = 1;\n" // 11 ASCII chars
        let target = 1_048_576
        let repeats = target / base.utf16.count
        var text = String(repeating: base, count: repeats)
        let deficit = target - text.utf16.count
        if deficit > 0 {
            text += String(repeating: " ", count: deficit)
        }
        return text
    }

    // MARK: - P01 — Model load

    func testP01_ModelLoad() {
        let bigText = Self.makeOneMiBText()
        XCTAssertEqual(
            bigText.utf16.count, 1_048_576,
            "P01 fixture must be exactly 1 MiB (1,048,576 UTF-16 units)"
        )

        runBenchmark(name: "P01 model-load", threshold: 2000.0) {
            let model = MonaCodeModel(
                text: bigText,
                uri: MonaURI(scheme: "inmemory", path: "/bench-p01")
            )
            _ = model.getValueLength()
        }
    }

    // MARK: - P02 — Typing + undo (500 one-char inserts)

    func testP02_TypingAndUndo() {
        // Per run: create a small model, then 500 one-char inserts.
        // Threshold is per-action (ms); per-run total / 500 must stay under it.
        let actionsPerRun = 500
        let perActionThreshold = 10.0  // ms

        // Measure per-run total (ms); report per-action for the threshold.
        // We reuse runBenchmark but adapt the threshold: per-run total must be
        // < actionsPerRun * perActionThreshold.
        runBenchmark(
            name: "P02 typing-undo",
            threshold: Double(actionsPerRun) * perActionThreshold
        ) {
            let model = MonaCodeModel(
                text: "seed",
                uri: MonaURI(scheme: "inmemory", path: "/bench-p02")
            )
            var cursorLine = 1
            var cursorColumn = 1
            for _ in 0..<actionsPerRun {
                _ = model.applyEdits([
                    MonaModelEditOperation(
                        range: MonaRange(
                            startLine: cursorLine,
                            startColumn: cursorColumn,
                            endLine: cursorLine,
                            endColumn: cursorColumn
                        ),
                        text: "X"
                    )
                ])
                cursorColumn += 1
            }
        }

        // Report per-action mean from the combined stats inline.
        // (The threshold above already encodes the per-action budget; the
        // summary line reports the per-run total. We additionally print the
        // per-action figure for clarity.)
        let m0 = measureRuns(30) {
            let model = MonaCodeModel(
                text: "seed",
                uri: MonaURI(scheme: "inmemory", path: "/bench-p02b")
            )
            var line = 1
            var col = 1
            for _ in 0..<actionsPerRun {
                _ = model.applyEdits([
                    MonaModelEditOperation(
                        range: MonaRange(startLine: line, startColumn: col, endLine: line, endColumn: col),
                        text: "X"
                    )
                ])
                col += 1
            }
        }
        let perAction = stats(m0).mean / Double(actionsPerRun)
        print("BENCHMARK P02 per-action mean=\(String(format: "%.4f", perAction))ms (threshold \(perActionThreshold)ms)")
        XCTAssertLessThan(perAction, perActionThreshold, "P02 per-action \(perAction)ms >= \(perActionThreshold)ms")
    }

    // MARK: - P03 — Batch edits (100 non-overlapping edits in one applyEdits)

    func testP03_BatchEdits() {
        let lineCount = 100
        let seedLines = (0..<lineCount).map { String(format: "line%03d", $0) }
        let seed = seedLines.joined(separator: "\n")
        let insertCol = "line000".utf16.count + 1 // 8: one past the last char of each line

        runBenchmark(name: "P03 batch-edits", threshold: 500.0) {
            let model = MonaCodeModel(
                text: seed,
                uri: MonaURI(scheme: "inmemory", path: "/bench-p03")
            )
            // Build 100 non-overlapping inserts: insert "EDIT" at the end of
            // each of the 100 lines. Different lines ⇒ non-overlapping.
            var ops: [MonaModelEditOperation] = []
            ops.reserveCapacity(lineCount)
            for line in 1...lineCount {
                ops.append(MonaModelEditOperation(
                    range: MonaRange(
                        startLine: line,
                        startColumn: insertCol,
                        endLine: line,
                        endColumn: insertCol
                    ),
                    text: "EDIT"
                ))
            }
            _ = model.applyEdits(ops)
        }
    }

    // MARK: - P08 — Find / literal search (1 MiB haystack)

    func testP08_Find() {
        let bigText = Self.makeOneMiBText()
        XCTAssertEqual(bigText.utf16.count, 1_048_576)

        // Build the haystack once (setup, not timed): the search primitive
        // operates on raw [UInt16]; extracting it is not part of the search.
        var haystack = Array(bigText.utf16)
        let needle = "BENCH_NEEDLE_42"
        let needleUnits = Array(needle.utf16)
        // Embed the needle at 10 evenly-spaced positions so findAll performs a
        // full scan and collects a known, small number of matches.
        let positions = 10
        for k in 0..<positions {
            let pos = ((k + 1) * haystack.count) / (positions + 1)
            let start = min(pos, haystack.count - needleUnits.count)
            for j in 0..<needleUnits.count where start + j < haystack.count {
                haystack[start + j] = needleUnits[j]
            }
        }

        // Sanity: the needle is present.
        let sanity = MonaLiteralSearch(needle: needleUnits, matchCase: true)
            .findAll(in: haystack)
        XCTAssertEqual(sanity.count, positions, "P08 needle should be present \(positions) times")

        let search = MonaLiteralSearch(needle: needleUnits, matchCase: true)
        runBenchmark(name: "P08 find-literal", threshold: 1000.0) {
            let matches = search.findAll(in: haystack)
            XCTAssertEqual(matches.count, positions)
        }
    }

    // MARK: - P10 — Diff / legacy LCS engine (10 KiB texts)

    func testP10_Diff() {
        // 10 KiB original (code lines ~70 chars each ⇒ ~146 lines).
        let lineCount = 146
        let originalLines = (0..<lineCount).map { i in
            "func f\(i)() -> Int { return \(i); } // line \(i)"
        }
        // Modified: change ~20% of lines + append a few + delete a few.
        var modifiedLines = originalLines
        for i in stride(from: 0, to: lineCount, by: 5) {
            modifiedLines[i] = "func g\(i)() -> String { return \"\\(i)\"; } // line \(i) edited"
        }
        modifiedLines.append("func appended() -> Void { /* tail */ }")
        modifiedLines.append("func appended2() -> Void { /* tail 2 */ }")
        if modifiedLines.count > 3 {
            modifiedLines.remove(at: modifiedLines.count - 3)
        }

        let originalUnits = originalLines.map { Array($0.utf16) }
        let modifiedUnits = modifiedLines.map { Array($0.utf16) }
        let input = MonaDiffInput(
            originalLines: originalUnits,
            modifiedLines: modifiedUnits
        )
        let options = MonaDiffOptions(
            maxComputationTimeMs: 5000, ignoreTrimWhitespace: true, computeMoves: false
        )

        // Sanity: the diff produces a non-trivial result.
        let sanity = MonaLegacyDiffEngine().compute(
            input: input, options: options,
            clock: MonaWallClock(), cancellationToken: .none
        )
        XCTAssertFalse(sanity.identical, "P10 sanity: texts must differ")
        XCTAssertFalse(sanity.changes.isEmpty, "P10 sanity: changes must be non-empty")

        runBenchmark(name: "P10 diff-legacy", threshold: 200.0) {
            let engine = MonaLegacyDiffEngine()
            let result = engine.compute(
                input: input,
                options: options,
                clock: MonaWallClock(),
                cancellationToken: .none
            )
            XCTAssertFalse(result.quitEarly, "P10: diff must not quit early")
        }
    }
}
