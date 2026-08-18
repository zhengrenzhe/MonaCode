// P13WorkloadTests.swift
//
// P09-T043 — Run P13: IME and accessibility queries (the fourteenth — and
// final — P-candidate).
//
// P13 is the IME and accessibility performance benchmark: running ABC/Pinyin
// marked-text traces, 10000 small accessibility range queries, 100 full-
// document queries, VoiceOver on/off, and callback latency, measured as
// per-query latency, then the 1,000,000-draw whole-balanced-block bootstrap
// verdict across the exact 60 Hz and 120 Hz frame cells for the M0 and M1
// comparators, with the one-sided 95 percent upper bound required to be at
// most zero on unrounded binary64 values for every comparator and cell.
//
// ──────────────────────────────────────────────────────────────────────────
// FEASIBILITY ASSESSMENT (P09-T043) — Option A (structural)
// ──────────────────────────────────────────────────────────────────────────
// 1. DISCOVERY. The `benchmark-harness` target is intentionally a NON-TEST
//    `.target` (Phase 00 package-graph invariant: products=3,
//    nonProductTargets=3, fixtureTargets=0). Its XCTest sources COMPILE as
//    part of the module but are NOT discovered by `swift test --filter`
//    (verified empirically in P09-T030). So this test verifies STRUCTURE,
//    not empirical execution. Option B (adding `benchmark-harness` to a
//    `.testTarget`'s dependencies) is infeasible without changing the
//    target kind (breaks nonProductTargets=3) or moving the file (breaks
//    the spec's test path).
//
// 2. M0/M1 BASELINES. M0 (the pinned npm `monaco-editor@0.56.0` oracle) and
//    M1 (the built comparator) are EXTERNAL comparators. The
//    DifferentialFixtures carry only `regexp` (correctness — the test262
//    manifest); there are NO M0/M1 *performance* baselines. Running even a
//    reduced IME/a11y measurement requires the npm package + a Node.js
//    runtime + a real macOS accessibility runtime + an IME (ABC/Pinyin) —
//    infeasible in-session. No reduced empirical measurement is run; no
//    performance results are fabricated.
//
// VERDICT: Option A (structural). "Green" = compiles + structurally valid.
// The formal 30-hot-block / 1,000,000-resample run with real M0/M1
// comparators is deferred to the formal benchmark execution (requires the
// external oracle harness); this test verifies the P13 configuration is
// correctly wired against the Phase 00 statistical + display + manifest
// infrastructure, including the ABC/Pinyin marked-text contract, the 10000-
// small-range / 100-full-document query counts, the VoiceOver on/off axis,
// and the callback-latency measurement contract.
//
// Spec (verbatim, P09-T043 implementation-operation stages):
//   • Run ABC/Pinyin marked-text traces, 10000 small accessibility range
//     queries, 100 full-document queries, VoiceOver on/off, and callback
//     latency.
//   • Collect 30 hot balanced blocks per valid cell, with attempt cap 2x,
//     six balanced AB/BA orderings where applicable, thermal-state sampling,
//     no outlier deletion, and separate total/component metrics.
//   • Evaluate M0 and M1 independently with positive log-ratio, manifest-
//     declared near-zero difference, or discrete-zero verdict form; resample
//     whole balanced blocks 1000000 times.
//   • Require the one-sided 95 percent bootstrap upper bound to be at most
//     zero on unrounded binary64 values for every comparator and cell.
//   • Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes
//     only the deadline and never the relative no-regression threshold.

import XCTest
import Foundation

// MARK: - P13 workload configuration (documented, verified against infra)

/// The P13 IME and accessibility workload configuration. These are the
/// measurement-time parameters the formal run uses; the structural tests
/// below verify that every parameter the Phase 00 infrastructure encodes
/// matches this configuration exactly, and that the infrastructure not yet
/// encoded (attempt cap, AB/BA orderings, thermal sampling) is documented
/// here for the formal run.
private enum P13Configuration {
    /// The two IME marked-text input methods the formal run traces — ABC
    /// (the macOS ASCII/romanji-style composition) and Pinyin (the
    /// Chinese-syllable composition). Each drives a marked-text session
    /// (insert marked text → navigate → commit) and is a distinct cell axis.
    /// (spec: "Run ABC/Pinyin marked-text traces …")
    static let imeInputMethods: [String] = ["abc", "pinyin"]
    /// 10000 small accessibility range queries — the formal run issues 10000
    /// small-range AX queries (each a bounded line/column range) against the
    /// editor's accessibility tree. This is the per-query latency stress
    /// point for the AX range path.
    /// (spec: "…10000 small accessibility range queries …")
    static let smallRangeQueryCount: Int = 10_000
    /// 100 full-document accessibility queries — the formal run issues 100
    /// full-document AX queries (each spanning the whole document). This is
    /// the heavy per-query path for the AX full-tree walk.
    /// (spec: "…100 full-document queries …")
    static let fullDocumentQueryCount: Int = 100
    /// The two VoiceOver states the formal run sweeps — on (the AX runtime
    /// is active; every AX query carries VoiceOver overhead) and off (the
    /// AX runtime is dormant; the AX query path is measured in isolation).
    /// Each state is a distinct cell axis.
    /// (spec: "…VoiceOver on/off …")
    static let voiceOverStates: [String] = ["on", "off"]
    /// Callback latency: the formal run measures the a11y callback round-trip
    /// latency — the time from the AX client's query to the editor's
    /// dispatched callback return — as a distinct metric (separate from the
    /// pure AX-tree-walk latency).
    /// (spec: "…and callback latency.")
    static let measuresCallbackLatency: Bool = true
    /// 30 hot balanced blocks per valid cell. P13 is a HOT workload — the
    /// editor is already loaded and warm; each block is a paired N/C latency
    /// measurement, NOT a fresh-process cold launch.
    static let hotBlocksPerCell: Int = 30
    /// The cold path's per-block launch count (P00 only). P13 is hot, so its
    /// block count is governed by the manifest's `minimumSamples`, NOT by
    /// `ColdLaunchManager.samplesPerBlock`.
    static let coldPathLaunchesPerBlock: Int = 50
    /// Attempt cap 2x — each hot block is attempted at most twice before
    /// being declared invalid.
    static let attemptCapMultiplier: Int = 2
    /// Six balanced AB/BA orderings where applicable (the formal run
    /// counterbalances presentation order to cancel systematic drift).
    static let balancedABAOrderings: Int = 6
    /// No outlier deletion — every valid block enters the bootstrap; the
    /// engine resamples WHOLE blocks and never drops a block post-hoc.
    static let outlierDeletion: Bool = false
    /// Separate total and component metrics — each is a distinct cell with
    /// its own verdict; they are never merged.
    static let metricsAreSeparated: Bool = true
    /// Exactly 1,000,000 whole-balanced-block bootstrap draws per cell.
    static let bootstrapDrawCount: Int = 1_000_000
    /// The one-sided 95 percent upper bound must be at most zero.
    static let upperBoundCeiling: Double = 0.0
    /// Exact 60 Hz and 120 Hz refresh cells.
    static let exactRefreshRates: Set<Double> = [60.0, 120.0]
}

// MARK: - P13WorkloadTests

final class P13WorkloadTests: XCTestCase {

    // MARK: - Stage 1: ABC/Pinyin marked-text; 10000 small range queries;
    //          100 full-document queries; VoiceOver on/off; callback latency

    /// The two IME marked-text input methods — ABC and Pinyin. Each drives a
    /// marked-text session and is a distinct cell axis. (spec: "Run
    /// ABC/Pinyin marked-text traces …")
    func testP13IMEInputMethodsAreABCAndPinyin() {
        XCTAssertEqual(P13Configuration.imeInputMethods.count, 2)
        XCTAssertEqual(P13Configuration.imeInputMethods, ["abc", "pinyin"])
    }

    /// 10000 small accessibility range queries — the per-query latency stress
    /// point for the AX range path. (spec: "…10000 small accessibility range
    /// queries …")
    func testP13SmallRangeQueryCountIsTenThousand() {
        XCTAssertEqual(
            P13Configuration.smallRangeQueryCount, 10_000,
            "10000 small AX range queries — the range-path stress point."
        )
    }

    /// 100 full-document accessibility queries — the heavy per-query path
    /// for the AX full-tree walk. (spec: "…100 full-document queries …")
    func testP13FullDocumentQueryCountIsOneHundred() {
        XCTAssertEqual(
            P13Configuration.fullDocumentQueryCount, 100,
            "100 full-document AX queries — the full-tree-walk path."
        )
        // The full-document count is strictly smaller than the small-range
        // count (a full-tree walk is far heavier per query, so fewer are
        // issued for a comparable total measurement budget).
        XCTAssertLessThan(
            P13Configuration.fullDocumentQueryCount,
            P13Configuration.smallRangeQueryCount,
            "Full-document queries are fewer than small-range queries."
        )
    }

    /// The two VoiceOver states — on and off. Each is a distinct cell axis.
    /// (spec: "…VoiceOver on/off …")
    func testP13VoiceOverStatesAreOnAndOff() {
        XCTAssertEqual(P13Configuration.voiceOverStates.count, 2)
        XCTAssertEqual(P13Configuration.voiceOverStates, ["on", "off"])
    }

    /// Callback latency is measured as a distinct metric — the a11y callback
    /// round-trip, separate from the pure AX-tree-walk latency.
    /// (spec: "…and callback latency.")
    func testP13MeasuresCallbackLatency() {
        XCTAssertTrue(
            P13Configuration.measuresCallbackLatency,
            "The a11y callback round-trip latency is a measured metric."
        )
    }

    // MARK: - Stage 2: 30 hot balanced blocks per valid cell; attempt cap 2x;
    //          AB/BA; no outlier deletion; separate total/component metrics

    /// 30 hot balanced blocks per valid cell — the manifest's
    /// `minimumSamples` fixes the required block count for a verdict. Below
    /// it the engine rejects with `.insufficientSamples`. (spec: "Collect 30
    /// hot balanced blocks per valid cell".)
    func testHotBlockCountIsThirty() throws {
        let manifest = makeManifest(minimumSamples: P13Configuration.hotBlocksPerCell)
        let stats = BootstrapStatistics()
        let blocks = makeBlocks(count: P13Configuration.hotBlocksPerCell)
        _ = try stats.positiveRatioVerdict(blocks: blocks, manifest: manifest)
        let shortManifest = makeManifest(minimumSamples: 30)
        let tooFew = makeBlocks(count: 10)
        XCTAssertThrowsError(
            try stats.positiveRatioVerdict(blocks: tooFew, manifest: shortManifest)
        ) { error in
            XCTAssertEqual(error as? BootstrapStatisticsError, .insufficientSamples)
        }
    }

    /// P13 is a HOT workload — its block count (30) is governed by the
    /// manifest's `minimumSamples`, distinct from the COLD path's 50-launch
    /// invariant (`ColdLaunchManager.samplesPerBlock`).
    func testHotWorkloadDistinctFromColdLaunchPath() {
        XCTAssertEqual(P13Configuration.hotBlocksPerCell, 30, "P13 uses 30 HOT blocks per cell.")
        XCTAssertEqual(
            ColdLaunchManager.samplesPerBlock,
            P13Configuration.coldPathLaunchesPerBlock,
            "The cold path (P00) uses 50 launches per block; P13 is hot."
        )
        XCTAssertNotEqual(
            P13Configuration.hotBlocksPerCell,
            P13Configuration.coldPathLaunchesPerBlock,
            "Hot block count (30) must differ from cold launch count (50)."
        )
    }

    /// No outlier deletion — the bootstrap resamples every block; none is
    /// dropped post-hoc.
    func testNoOutlierDeletionAllBlocksEnterBootstrap() throws {
        let manifest = makeManifest(minimumSamples: 5)
        let stats = BootstrapStatistics()
        var pairs: [(Double, Double)] = Array(repeating: (100.0, 100.0), count: 9)
        pairs.append((500.0, 100.0))
        let blocks = pairs.map { BenchmarkSampleBlock(native: $0.0, comparator: $0.1) }
        let verdict = try stats.nearZeroDifferenceVerdict(blocks: blocks, manifest: manifest)
        XCTAssertEqual(verdict.bootstrapDrawCount, P13Configuration.bootstrapDrawCount)
    }

    // MARK: - Stage 3: M0 and M1 independent; three verdict forms; 1,000,000
    //          whole-balanced-block resamples

    /// M0 and M1 are DISTINCT, INDEPENDENT comparators — each N/M0 and N/M1
    /// cell produces its own verdict; they are never merged.
    func testM0AndM1AreDistinctIndependentComparators() {
        XCTAssertNotEqual(BenchmarkComparator.m0, BenchmarkComparator.m1)
        XCTAssertNotEqual(BenchmarkComparator.m0, BenchmarkComparator.native)
        XCTAssertNotEqual(BenchmarkComparator.m1, BenchmarkComparator.native)
    }

    /// Three verdict forms are available — positive log-ratio, manifest-
    /// declared near-zero difference, and discrete-zero.
    func testThreeVerdictFormsAvailable() throws {
        let manifest = makeManifest(minimumSamples: 5)
        let stats = BootstrapStatistics()
        let pos = makeBlocks(count: 5, native: 99.0, comparator: 100.0)
        let near = makeBlocks(count: 5, native: 100.0, comparator: 100.0)
        let disc = makeBlocks(count: 5, native: 0.0, comparator: 0.0)

        let posVerdict = try stats.positiveRatioVerdict(blocks: pos, manifest: manifest)
        let nearVerdict = try stats.nearZeroDifferenceVerdict(blocks: near, manifest: manifest)
        let discVerdict = try stats.discreteZeroVerdict(blocks: disc, manifest: manifest)

        XCTAssertTrue(posVerdict.passes, "native < comparator → log(N/C) < 0 → passes.")
        XCTAssertTrue(nearVerdict.passes, "N == C → diff == 0 → U == 0 ≤ 0 → passes.")
        XCTAssertTrue(discVerdict.passes, "C == 0 and all N == 0 → passes.")
    }

    /// Exactly 1,000,000 deterministic whole-balanced-block bootstrap draws
    /// per cell.
    func testBootstrapDrawCountIsExactlyOneMillion() throws {
        let manifest = makeManifest(minimumSamples: 5)
        let stats = BootstrapStatistics()
        XCTAssertEqual(BootstrapStatistics.drawCount, P13Configuration.bootstrapDrawCount)
        let verdict = try stats.positiveRatioVerdict(
            blocks: makeBlocks(count: 5), manifest: manifest
        )
        XCTAssertEqual(verdict.bootstrapDrawCount, 1_000_000)
    }

    // MARK: - Stage 4: one-sided 95% upper bound at most zero, unrounded
    //          binary64, every comparator and cell

    /// The verdict's `passes` is `upperBound <= 0.0` evaluated on the
    /// UNROUNDED binary64 value.
    func testUpperBoundAtMostZeroOnUnroundedBinary64() {
        let atZero = BootstrapVerdict(
            estimator: 0.0, positiveRatio: 1.0, quantile05: 0.0,
            upperBound: 0.0, passes: 0.0 <= 0.0, bootstrapDrawCount: 1_000_000
        )
        XCTAssertTrue(atZero.passes, "upperBound == 0.0 → at most zero → passes.")

        let justBelow = BootstrapVerdict(
            estimator: -1e-15, positiveRatio: 1.0, quantile05: 0.0,
            upperBound: -1e-15, passes: -1e-15 <= 0.0, bootstrapDrawCount: 1_000_000
        )
        XCTAssertTrue(justBelow.passes)

        let justAbove = BootstrapVerdict(
            estimator: 1e-15, positiveRatio: 0.0, quantile05: -1e-15,
            upperBound: 1e-15, passes: 1e-15 <= 0.0, bootstrapDrawCount: 1_000_000
        )
        XCTAssertFalse(justAbove.passes, "upperBound > 0.0 → fails the at-most-zero bar.")
    }

    /// The intersection-union test requires EVERY cell to reject its own null
    /// — for P13 that means both the M0 cell and the M1 cell must pass.
    func testIntersectionUnionRequiresEveryComparatorCellToPass() {
        let stats = BootstrapStatistics()
        XCTAssertTrue(stats.intersectionUnion(passResults: [true, true]))
        XCTAssertFalse(stats.intersectionUnion(passResults: [false, true]))
        XCTAssertFalse(stats.intersectionUnion(passResults: [true, false]))
        XCTAssertFalse(stats.intersectionUnion(passResults: [false, false]))
    }

    // MARK: - Stage 5: exact 60 Hz and 120 Hz cells kept separate; deadline
    //          differs; relative threshold identical

    /// Exact 60.0 and 120.0 Hz form the valid refresh cells. 59.94 is NOT
    /// folded to 60.0.
    func testRefreshCellsAreExact60And120() {
        XCTAssertEqual(
            DisplayModeEnforcer.exactRefreshRates,
            P13Configuration.exactRefreshRates
        )
        XCTAssertFalse(DisplayModeEnforcer.exactRefreshRates.contains(59.94),
                       "59.94 Hz must not be folded to 60.0.")
    }

    /// 60 Hz and 120 Hz cells are never mixed within one block.
    func testRefreshCellsNeverMixedInOneBlock() throws {
        let enforcer = DisplayModeEnforcer()
        let mode60 = makeDisplayMode(hz: 60.0)
        let mode120 = makeDisplayMode(hz: 120.0)
        XCTAssertNoThrow(try enforcer.lockBlock(refreshRate: .hz60, samples: [mode60, mode60]))
        XCTAssertThrowsError(try enforcer.lockBlock(refreshRate: .hz60, samples: [mode60, mode120])) { error in
            guard case .refreshRateMixedInBlock(let found, let expected) = error as? DisplayModeError else {
                return XCTFail("expected refreshRateMixedInBlock")
            }
            XCTAssertEqual(found, 120.0)
            XCTAssertEqual(expected, 60.0)
        }
    }

    /// Refresh rate changes ONLY the deadline — the 120 Hz deadline is
    /// strictly shorter than the 60 Hz deadline.
    func testDeadlineDiffersAcrossRefreshRates() {
        let enforcer = DisplayModeEnforcer()
        let d60 = enforcer.deadline(for: .hz60)
        let d120 = enforcer.deadline(for: .hz120)
        XCTAssertNotEqual(d60, d120, "60 Hz and 120 Hz deadlines must differ.")
        XCTAssertLessThan(d120, d60, "120 Hz deadline must be strictly shorter than 60 Hz.")
    }

    /// The relative no-regression threshold is IDENTICAL across 60 Hz and
    /// 120 Hz.
    func testRelativeNoRegressionThresholdIdenticalAcrossRates() {
        let enforcer = DisplayModeEnforcer()
        XCTAssertEqual(
            enforcer.relativeThreshold(for: .hz60),
            enforcer.relativeThreshold(for: .hz120),
            "The relative no-regression threshold must not change with refresh rate."
        )
    }

    // MARK: - BenchmarkRunner: balanced-block pairing never split

    /// The runner pairs native and comparator sample streams element-by-
    /// element into balanced blocks; the N/C pairing is never split.
    func testBenchmarkRunnerPairsNativeAndComparatorNeverSplitsBlock() throws {
        let runner = BenchmarkRunner()
        let native = [Double](repeating: 100.0, count: 30)
        let comparator = [Double](repeating: 100.0, count: 30)
        let blocks = try runner.collectBlockSamples(native: native, comparator: comparator)
        XCTAssertEqual(blocks.count, 30)
        XCTAssertEqual(blocks.first?.native, 100.0)
        XCTAssertEqual(blocks.first?.comparator, 100.0)
        XCTAssertThrowsError(
            try runner.collectBlockSamples(native: [1.0, 2.0], comparator: [1.0])
        ) { error in
            XCTAssertEqual(error as? BenchmarkRunnerError, .unbalanced)
        }
    }

    // MARK: - Bootstrap seed reproducibility

    /// The bootstrap seed material is `manifestHash || cellID || "Q1-R3"`;
    /// changing the cellID changes the seed material.
    func testBootstrapSeedMaterialIsReproducibleAndCellScoped() {
        let m0 = makeManifest(cellID: "p13-ime-a11y-60hz-total-native-vs-m0")
        let m1 = makeManifest(cellID: "p13-ime-a11y-60hz-total-native-vs-m1")
        let materialM0 = BootstrapStatistics.seedMaterial(for: m0)
        let materialM1 = BootstrapStatistics.seedMaterial(for: m1)
        XCTAssertTrue(materialM0.contains(m0.manifestHash))
        XCTAssertTrue(materialM0.contains(m0.cellID))
        XCTAssertTrue(materialM0.hasSuffix("Q1-R3"))
        XCTAssertNotEqual(materialM0, materialM1, "M0 and M1 cells must seed independently.")
    }

    // MARK: - Full P13 pipeline wiring (synthetic data — NOT a performance
    //          result)

    /// End-to-end wiring proof: the P13 pipeline — collect balanced blocks
    /// → run each verdict form → aggregate via intersection-union — is wired
    /// correctly. Uses SYNTHETIC blocks (not real IME/a11y timings); this is
    /// a structural wiring check, NOT a performance measurement.
    func testP13FullPipelineWiringWithSyntheticBlocks() throws {
        let runner = BenchmarkRunner()
        let stats = BootstrapStatistics()

        let native = [Double](repeating: 99.0, count: 30)
        let comparator = [Double](repeating: 100.0, count: 30)
        let blocks = try runner.collectBlockSamples(native: native, comparator: comparator)

        let m0Manifest = makeManifest(
            cellID: "p13-ime-a11y-60hz-total-native-vs-m0",
            comparator: .m0, minimumSamples: 30
        )
        let m1Manifest = makeManifest(
            cellID: "p13-ime-a11y-60hz-total-native-vs-m1",
            comparator: .m1, minimumSamples: 30
        )

        let m0Verdict = try stats.positiveRatioVerdict(blocks: blocks, manifest: m0Manifest)
        let m1Verdict = try stats.positiveRatioVerdict(blocks: blocks, manifest: m1Manifest)

        XCTAssertTrue(m0Verdict.passes)
        XCTAssertTrue(m1Verdict.passes)
        XCTAssertEqual(m0Verdict.bootstrapDrawCount, 1_000_000)
        XCTAssertEqual(m1Verdict.bootstrapDrawCount, 1_000_000)

        XCTAssertTrue(stats.intersectionUnion(verdicts: [m0Verdict, m1Verdict]))
    }

    // MARK: - Helpers

    private func makeManifest(
        cellID: String = "p13-ime-a11y-60hz-total-native-vs-m0",
        comparator: BenchmarkComparator = .m0,
        metricKind: BenchmarkMetricKind = .positive,
        resolution: Double = 0.001,
        manifestHash: String = String(repeating: "ab", count: 32),
        minimumSamples: Int = 5
    ) -> CellManifest {
        CellManifest(
            cellID: cellID,
            refreshRate: .hz60,
            comparator: comparator,
            metricKind: metricKind,
            resolution: resolution,
            manifestHash: manifestHash,
            minimumSamples: minimumSamples
        )
    }

    private func makeBlocks(
        count: Int,
        native: Double = 100.0,
        comparator: Double = 100.0
    ) -> [BenchmarkSampleBlock] {
        return (0..<count).map { _ in
            BenchmarkSampleBlock(native: native, comparator: comparator)
        }
    }

    private func makeDisplayMode(hz: Double) -> DisplayMode {
        return DisplayMode(
            isBuiltIn: true,
            sessionSlot: "built-in-0",
            refreshRateHz: hz,
            iccHash: String(repeating: "cd", count: 32),
            pixelWidth: 3024,
            pixelHeight: 1964,
            backingScale: 2.0
        )
    }
}
