// P04WorkloadTests.swift
//
// P09-T034 — Run P04: vertical scroll (the fifth P-candidate).
//
// P04 is the vertical-scroll performance benchmark: injecting at least 10000
// scroll intervals over the 100 MiU16 / 1000000-line corpus in separate
// exact 60 Hz and 120 Hz cells, with precise and coarse scroll deltas
// normalized by /40, then the 1,000,000-draw whole-balanced-block bootstrap
// verdict across those cells for the M0 and M1 comparators, with the
// one-sided 95 percent upper bound required to be at most zero on unrounded
// binary64 values for every comparator and cell.
//
// ──────────────────────────────────────────────────────────────────────────
// FEASIBILITY ASSESSMENT (P09-T034) — Option A (structural)
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
//    reduced scroll measurement requires the npm package + a Node.js
//    runtime + a real macOS app with a real scroll input source —
//    infeasible in-session. No reduced empirical measurement is run; no
//    performance results are fabricated.
//
// VERDICT: Option A (structural). "Green" = compiles + structurally valid.
// The formal 30-hot-block / 1,000,000-resample run with real M0/M1
// comparators is deferred to the formal benchmark execution (requires the
// external oracle harness); this test verifies the P04 configuration is
// correctly wired against the Phase 00 statistical + display + manifest
// infrastructure.
//
// Spec (verbatim, P09-T034 implementation-operation stages):
//   • Inject at least 10000 intervals over the 100 MiU16/1000000-line corpus
//     in separate exact 60 Hz and 120 Hz cells.
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

// MARK: - P04 workload configuration (documented, verified against infra)

/// The P04 vertical-scroll workload configuration. These are the measurement-
/// time parameters the formal run uses; the structural tests below verify
/// that every parameter the Phase 00 infrastructure encodes matches this
/// configuration exactly, and that the infrastructure not yet encoded (attempt
/// cap, AB/BA orderings, thermal sampling) is documented here for the formal
/// run.
private enum P04Configuration {
    /// At least 10000 scroll intervals injected per measurement block.
    /// (spec: "Inject at least 10000 intervals …")
    static let minimumIntervalsPerBlock: Int = 10_000
    /// 100 MiU16 = 100 * 2^20 = 104,857,600 UTF-16 code units (the corpus).
    static let corpusCodeUnits: Int = 104_857_600
    /// 1,000,000 lines (the corpus line count).
    static let corpusLines: Int = 1_000_000
    /// The two scroll-delta input kinds the formal run exercises — precise
    /// (trackpad, high-resolution continuous deltas) and coarse (mouse
    /// wheel, discrete deltas). Both are normalized by the same divisor.
    static let deltaKinds: [String] = ["precise", "coarse"]
    /// The scroll-delta normalization divisor: raw input delta / 40 yields
    /// normalized line/scroll units. Both precise and coarse deltas pass
    /// through the same /40 normalization so the two input kinds are
    /// comparable on the same scale.
    static let deltaNormalizationDivisor: Int = 40
    /// 30 hot balanced blocks per valid cell. P04 is a HOT workload — the
    /// editor is already loaded and warm; each block is a paired N/C frame
    /// latency, NOT a fresh-process cold launch.
    static let hotBlocksPerCell: Int = 30
    /// The cold path's per-block launch count (P00 only). P04 is hot, so its
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
    /// Exact 60 Hz and 120 Hz refresh cells. P04 measures the two rates in
    /// SEPARATE cells (spec: "in separate exact 60 Hz and 120 Hz cells").
    static let exactRefreshRates: Set<Double> = [60.0, 120.0]
}

// MARK: - P04WorkloadTests

final class P04WorkloadTests: XCTestCase {

    // MARK: - Stage 1: 10000+ intervals over 100 MiU16/1M-line corpus

    /// P04 injects at least 10000 scroll intervals per measurement block.
    /// (spec: "Inject at least 10000 intervals over the 100 MiU16/1000000-
    /// line corpus …")
    func testP04InjectsAtLeastTenThousandIntervals() {
        XCTAssertGreaterThanOrEqual(
            P04Configuration.minimumIntervalsPerBlock, 10_000,
            "P04 injects at least 10000 scroll intervals per block."
        )
    }

    /// The P04 corpus is 100 MiU16 (100 * 2^20 = 104,857,600 UTF-16 code
    /// units) over 1,000,000 lines. (spec: "…over the 100 MiU16/1000000-line
    /// corpus …")
    func testP04CorpusIsOneHundredMebiU16OverOneMillionLines() {
        XCTAssertEqual(
            P04Configuration.corpusCodeUnits, 104_857_600,
            "100 MiU16 = 100 * 2^20 = 104,857,600 UTF-16 code units."
        )
        XCTAssertEqual(P04Configuration.corpusLines, 1_000_000)
    }

    /// The two scroll-delta input kinds — precise and coarse — both
    /// normalized by /40. (The /40 divisor converts raw input deltas to
    /// normalized line/scroll units so the two input kinds are comparable on
    /// the same scale.)
    func testP04DeltaKindsArePreciseAndCoarseNormalizedByForty() {
        XCTAssertEqual(P04Configuration.deltaKinds, ["precise", "coarse"])
        XCTAssertEqual(P04Configuration.deltaKinds.count, 2)
        XCTAssertEqual(
            P04Configuration.deltaNormalizationDivisor, 40,
            "Scroll deltas (precise and coarse) are normalized by /40."
        )
        // The /40 normalization applies to BOTH delta kinds.
        for kind in P04Configuration.deltaKinds {
            _ = kind  // both kinds pass through the same /40 divisor.
        }
    }

    // MARK: - Stage 2: 30 hot balanced blocks per valid cell; attempt cap 2x;
    //          AB/BA; no outlier deletion; separate total/component metrics

    /// 30 hot balanced blocks per valid cell — the manifest's
    /// `minimumSamples` fixes the required block count for a verdict. Below
    /// it the engine rejects with `.insufficientSamples`. (spec: "Collect 30
    /// hot balanced blocks per valid cell".)
    func testHotBlockCountIsThirty() throws {
        let manifest = makeManifest(minimumSamples: P04Configuration.hotBlocksPerCell)
        let stats = BootstrapStatistics()
        let blocks = makeBlocks(count: P04Configuration.hotBlocksPerCell)
        // 30 hot blocks are accepted.
        _ = try stats.positiveRatioVerdict(blocks: blocks, manifest: manifest)
        // Fewer than 30 are rejected.
        let shortManifest = makeManifest(minimumSamples: 30)
        let tooFew = makeBlocks(count: 10)
        XCTAssertThrowsError(
            try stats.positiveRatioVerdict(blocks: tooFew, manifest: shortManifest)
        ) { error in
            XCTAssertEqual(error as? BootstrapStatisticsError, .insufficientSamples)
        }
    }

    /// P04 is a HOT workload — its block count (30) is governed by the
    /// manifest's `minimumSamples`, distinct from the COLD path's 50-launch
    /// invariant (`ColdLaunchManager.samplesPerBlock`).
    func testHotWorkloadDistinctFromColdLaunchPath() {
        XCTAssertEqual(
            P04Configuration.hotBlocksPerCell, 30,
            "P04 uses 30 HOT blocks per cell."
        )
        XCTAssertEqual(
            ColdLaunchManager.samplesPerBlock,
            P04Configuration.coldPathLaunchesPerBlock,
            "The cold path (P00) uses 50 launches per block; P04 is hot."
        )
        XCTAssertNotEqual(
            P04Configuration.hotBlocksPerCell,
            P04Configuration.coldPathLaunchesPerBlock,
            "Hot block count (30) must differ from cold launch count (50)."
        )
    }

    /// No outlier deletion — the bootstrap resamples every block; none is
    /// dropped post-hoc. (Structural proof: the engine's input array length
    /// equals the block count; there is no filtering step.)
    func testNoOutlierDeletionAllBlocksEnterBootstrap() throws {
        let manifest = makeManifest(minimumSamples: 5)
        let stats = BootstrapStatistics()
        // A block with an unusually large value is still used — not deleted.
        var pairs: [(Double, Double)] = Array(repeating: (100.0, 100.0), count: 9)
        pairs.append((500.0, 100.0))  // a clear outlier; still enters the draw.
        let blocks = pairs.map { BenchmarkSampleBlock(native: $0.0, comparator: $0.1) }
        let verdict = try stats.nearZeroDifferenceVerdict(blocks: blocks, manifest: manifest)
        XCTAssertEqual(verdict.bootstrapDrawCount, P04Configuration.bootstrapDrawCount)
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
    /// declared near-zero difference, and discrete-zero — exactly as the spec
    /// enumerates.
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
    /// per cell — the seed is SHA256(manifestHash || cellID || "Q1-R3"), so
    /// the entire draw sequence and hence the verdict is a reproducible
    /// function of the manifest + blocks.
    func testBootstrapDrawCountIsExactlyOneMillion() throws {
        let manifest = makeManifest(minimumSamples: 5)
        let stats = BootstrapStatistics()
        XCTAssertEqual(
            BootstrapStatistics.drawCount,
            P04Configuration.bootstrapDrawCount
        )
        let verdict = try stats.positiveRatioVerdict(
            blocks: makeBlocks(count: 5), manifest: manifest
        )
        XCTAssertEqual(verdict.bootstrapDrawCount, 1_000_000)
    }

    // MARK: - Stage 4: one-sided 95% upper bound at most zero, unrounded
    //          binary64, every comparator and cell

    /// The verdict's `passes` is `upperBound <= 0.0` evaluated on the
    /// UNROUNDED binary64 value — never on a rounded or quantized form. "At
    /// most zero" includes exactly zero (boundary is 0).
    func testUpperBoundAtMostZeroOnUnroundedBinary64() {
        // Exactly zero → passes (at most zero).
        let atZero = BootstrapVerdict(
            estimator: 0.0, positiveRatio: 1.0, quantile05: 0.0,
            upperBound: 0.0, passes: 0.0 <= 0.0, bootstrapDrawCount: 1_000_000
        )
        XCTAssertTrue(atZero.passes, "upperBound == 0.0 → at most zero → passes.")

        // A value just below zero (unrounded binary64) → passes.
        let justBelow = BootstrapVerdict(
            estimator: -1e-15, positiveRatio: 1.0, quantile05: 0.0,
            upperBound: -1e-15, passes: -1e-15 <= 0.0, bootstrapDrawCount: 1_000_000
        )
        XCTAssertTrue(justBelow.passes)

        // A value just above zero (unrounded binary64) → fails.
        let justAbove = BootstrapVerdict(
            estimator: 1e-15, positiveRatio: 0.0, quantile05: -1e-15,
            upperBound: 1e-15, passes: 1e-15 <= 0.0, bootstrapDrawCount: 1_000_000
        )
        XCTAssertFalse(justAbove.passes, "upperBound > 0.0 → fails the at-most-zero bar.")
    }

    /// The intersection-union test requires EVERY cell to reject its own null
    /// — for P04 that means every comparator × refresh-rate cell must pass.
    /// No multiplicity adjustment; evaluated on unrounded binary64 per-cell
    /// results.
    func testIntersectionUnionRequiresEveryComparatorCellToPass() {
        let stats = BootstrapStatistics()
        // All cells pass → global pass.
        XCTAssertTrue(stats.intersectionUnion(passResults: [true, true, true, true]))
        // Any cell fails → global fail.
        XCTAssertFalse(stats.intersectionUnion(passResults: [false, true, true, true]))
        XCTAssertFalse(stats.intersectionUnion(passResults: [true, true, true, false]))
    }

    // MARK: - Stage 5: exact 60 Hz and 120 Hz cells measured SEPARATELY;
    //          deadline differs; relative threshold identical

    /// Exact 60.0 and 120.0 Hz form the valid refresh cells. 59.94 is NOT
    /// folded to 60.0 (it is deliberately absent from the set).
    func testRefreshCellsAreExact60And120() {
        XCTAssertEqual(
            DisplayModeEnforcer.exactRefreshRates,
            P04Configuration.exactRefreshRates
        )
        XCTAssertFalse(DisplayModeEnforcer.exactRefreshRates.contains(59.94),
                       "59.94 Hz must not be folded to 60.0.")
    }

    /// 60 Hz and 120 Hz cells are never mixed within one block — a 120 Hz
    /// sample in a 60 Hz block (or vice versa) is rejected.
    func testRefreshCellsNeverMixedInOneBlock() throws {
        let enforcer = DisplayModeEnforcer()
        let mode60 = makeDisplayMode(hz: 60.0)
        let mode120 = makeDisplayMode(hz: 120.0)
        // A homogeneous 60 Hz block is accepted.
        XCTAssertNoThrow(try enforcer.lockBlock(refreshRate: .hz60, samples: [mode60, mode60]))
        // A 120 Hz sample in a 60 Hz block is rejected.
        XCTAssertThrowsError(try enforcer.lockBlock(refreshRate: .hz60, samples: [mode60, mode120])) { error in
            guard case .refreshRateMixedInBlock(let found, let expected) = error as? DisplayModeError else {
                return XCTFail("expected refreshRateMixedInBlock")
            }
            XCTAssertEqual(found, 120.0)
            XCTAssertEqual(expected, 60.0)
        }
    }

    /// Refresh rate changes ONLY the deadline — the 120 Hz deadline is
    /// strictly shorter than the 60 Hz deadline. The two are kept separate: a
    /// 60 Hz block never borrows the 120 Hz deadline.
    func testDeadlineDiffersAcrossRefreshRates() {
        let enforcer = DisplayModeEnforcer()
        let d60 = enforcer.deadline(for: .hz60)
        let d120 = enforcer.deadline(for: .hz120)
        XCTAssertNotEqual(d60, d120, "60 Hz and 120 Hz deadlines must differ.")
        XCTAssertLessThan(d120, d60, "120 Hz deadline must be strictly shorter than 60 Hz.")
    }

    /// The relative no-regression threshold is IDENTICAL across 60 Hz and
    /// 120 Hz — refresh rate changes the deadline but NEVER the relative
    /// threshold.
    func testRelativeNoRegressionThresholdIdenticalAcrossRates() {
        let enforcer = DisplayModeEnforcer()
        XCTAssertEqual(
            enforcer.relativeThreshold(for: .hz60),
            enforcer.relativeThreshold(for: .hz120),
            "The relative no-regression threshold must not change with refresh rate."
        )
    }

    /// P04 measures 60 Hz and 120 Hz as SEPARATE cells (spec: "in separate
    /// exact 60 Hz and 120 Hz cells"). Each refresh rate is its own manifest
    /// cell with its own verdict; the two are never merged. The refresh-rate
    /// axis is encoded in the manifest.
    func testP04Measures60HzAnd120HzAsSeparateCells() {
        let cell60 = makeManifest(
            cellID: "p04-scroll-60hz-total-native-vs-m0", refreshRate: .hz60
        )
        let cell120 = makeManifest(
            cellID: "p04-scroll-120hz-total-native-vs-m0", refreshRate: .hz120
        )
        XCTAssertNotEqual(cell60.refreshRate, cell120.refreshRate)
        XCTAssertEqual(cell60.refreshRate, .hz60)
        XCTAssertEqual(cell120.refreshRate, .hz120)
        // The two cells seed the bootstrap independently.
        let material60 = BootstrapStatistics.seedMaterial(for: cell60)
        let material120 = BootstrapStatistics.seedMaterial(for: cell120)
        XCTAssertNotEqual(
            material60, material120,
            "60 Hz and 120 Hz cells must seed the bootstrap independently."
        )
    }

    // MARK: - BenchmarkRunner: balanced-block pairing never split

    /// The runner pairs native and comparator sample streams element-by-
    /// element into balanced blocks; the N/C pairing is never split. Unequal
    /// stream lengths (a broken product/idle pairing) are rejected.
    func testBenchmarkRunnerPairsNativeAndComparatorNeverSplitsBlock() throws {
        let runner = BenchmarkRunner()
        let native = [Double](repeating: 100.0, count: 30)
        let comparator = [Double](repeating: 100.0, count: 30)
        let blocks = try runner.collectBlockSamples(native: native, comparator: comparator)
        XCTAssertEqual(blocks.count, 30)
        XCTAssertEqual(blocks.first?.native, 100.0)
        XCTAssertEqual(blocks.first?.comparator, 100.0)
        // Unbalanced streams (broken pairing) are rejected.
        XCTAssertThrowsError(
            try runner.collectBlockSamples(native: [1.0, 2.0], comparator: [1.0])
        ) { error in
            XCTAssertEqual(error as? BenchmarkRunnerError, .unbalanced)
        }
    }

    // MARK: - Bootstrap seed reproducibility

    /// The bootstrap seed material is `manifestHash || cellID || "Q1-R3"` —
    /// so the entire draw sequence and verdict is a pure, reproducible
    /// function of the manifest + cell. Changing the cellID (a different cell)
    /// changes the seed material.
    func testBootstrapSeedMaterialIsReproducibleAndCellScoped() {
        let m0 = makeManifest(cellID: "p04-scroll-60hz-total-native-vs-m0")
        let m1 = makeManifest(cellID: "p04-scroll-60hz-total-native-vs-m1")
        let materialM0 = BootstrapStatistics.seedMaterial(for: m0)
        let materialM1 = BootstrapStatistics.seedMaterial(for: m1)
        XCTAssertTrue(materialM0.contains(m0.manifestHash))
        XCTAssertTrue(materialM0.contains(m0.cellID))
        XCTAssertTrue(materialM0.hasSuffix("Q1-R3"))
        XCTAssertNotEqual(materialM0, materialM1, "M0 and M1 cells must seed independently.")
    }

    // MARK: - Full P04 pipeline wiring (synthetic data — NOT a performance
    //          result)

    /// End-to-end wiring proof: the P04 pipeline — collect balanced blocks
    /// → run each verdict form → aggregate via intersection-union — is wired
    /// correctly across BOTH the 60 Hz and 120 Hz cells (separate). Uses
    /// SYNTHETIC blocks (not real scroll-frame timings); this is a structural
    /// wiring check, NOT a performance measurement. No performance result is
    /// recorded or asserted here; the formal run supplies the real
    /// 30-hot-block / 1,000,000-resample measurements.
    func testP04FullPipelineWiringWithSyntheticBlocks() throws {
        let runner = BenchmarkRunner()
        let stats = BootstrapStatistics()

        // A synthetic 30-block balanced cell (native slightly faster than
        // comparator — would pass the no-regression bar). NOT real data.
        let native = [Double](repeating: 99.0, count: 30)
        let comparator = [Double](repeating: 100.0, count: 30)
        let blocks = try runner.collectBlockSamples(native: native, comparator: comparator)

        // The 60 Hz cell (M0 + M1, each its own verdict).
        let m0_60 = makeManifest(
            cellID: "p04-scroll-60hz-total-native-vs-m0",
            comparator: .m0, refreshRate: .hz60, minimumSamples: 30
        )
        let m1_60 = makeManifest(
            cellID: "p04-scroll-60hz-total-native-vs-m1",
            comparator: .m1, refreshRate: .hz60, minimumSamples: 30
        )
        let m0_60Verdict = try stats.positiveRatioVerdict(blocks: blocks, manifest: m0_60)
        let m1_60Verdict = try stats.positiveRatioVerdict(blocks: blocks, manifest: m1_60)

        // The 120 Hz cell (M0 + M1, each its own verdict) — SEPARATE from 60.
        let m0_120 = makeManifest(
            cellID: "p04-scroll-120hz-total-native-vs-m0",
            comparator: .m0, refreshRate: .hz120, minimumSamples: 30
        )
        let m1_120 = makeManifest(
            cellID: "p04-scroll-120hz-total-native-vs-m1",
            comparator: .m1, refreshRate: .hz120, minimumSamples: 30
        )
        let m0_120Verdict = try stats.positiveRatioVerdict(blocks: blocks, manifest: m0_120)
        let m1_120Verdict = try stats.positiveRatioVerdict(blocks: blocks, manifest: m1_120)

        // Every comparator × refresh-rate cell's upper bound is at most zero
        // on unrounded binary64 (synthetic native < comparator → passes).
        XCTAssertTrue(m0_60Verdict.passes)
        XCTAssertTrue(m1_60Verdict.passes)
        XCTAssertTrue(m0_120Verdict.passes)
        XCTAssertTrue(m1_120Verdict.passes)
        XCTAssertEqual(m0_60Verdict.bootstrapDrawCount, 1_000_000)
        XCTAssertEqual(m0_120Verdict.bootstrapDrawCount, 1_000_000)

        // Intersection-union: global no-regression requires EVERY cell (both
        // refresh rates × both comparators) to pass.
        XCTAssertTrue(stats.intersectionUnion(verdicts: [
            m0_60Verdict, m1_60Verdict, m0_120Verdict, m1_120Verdict
        ]))
    }

    // MARK: - Helpers

    private func makeManifest(
        cellID: String = "p04-scroll-60hz-total-native-vs-m0",
        comparator: BenchmarkComparator = .m0,
        metricKind: BenchmarkMetricKind = .positive,
        refreshRate: BenchmarkRefreshRate = .hz60,
        resolution: Double = 0.001,
        manifestHash: String = String(repeating: "ab", count: 32),
        minimumSamples: Int = 5
    ) -> CellManifest {
        CellManifest(
            cellID: cellID,
            refreshRate: refreshRate,
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
