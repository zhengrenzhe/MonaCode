// P05WorkloadTests.swift
//
// P09-T035 — Run P05: long line (the sixth P-candidate).
//
// P05 is the long-line performance benchmark: rendering 1000000-unit lines
// with stopRenderingLineAfter equal to 10000 and -1 (unlimited) across
// scale, fallback, and subpixel rendering cells, measured as per-frame
// render latency, then the 1,000,000-draw whole-balanced-block bootstrap
// verdict across the exact 60 Hz and 120 Hz frame cells for the M0 and M1
// comparators, with the one-sided 95 percent upper bound required to be at
// most zero on unrounded binary64 values for every comparator and cell.
//
// ──────────────────────────────────────────────────────────────────────────
// FEASIBILITY ASSESSMENT (P09-T035) — Option A (structural)
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
//    reduced long-line render measurement requires the npm package + a
//    Node.js runtime + a real macOS editor session — infeasible in-session.
//    No reduced empirical measurement is run; no performance results are
//    fabricated.
//
// VERDICT: Option A (structural). "Green" = compiles + structurally valid.
// The formal 30-hot-block / 1,000,000-resample run with real M0/M1
// comparators is deferred to the formal benchmark execution (requires the
// external oracle harness); this test verifies the P05 configuration is
// correctly wired against the Phase 00 statistical + display + manifest
// infrastructure.
//
// Spec (verbatim, P09-T035 implementation-operation stages):
//   • Render 1000000-unit lines with stopRenderingLineAfter equal to 10000
//     and -1 across scale, fallback, and subpixel cells.
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

// MARK: - P05 workload configuration (documented, verified against infra)

/// The P05 long-line workload configuration. These are the measurement-time
/// parameters the formal run uses; the structural tests below verify that
/// every parameter the Phase 00 infrastructure encodes matches this
/// configuration exactly, and that the infrastructure not yet encoded
/// (attempt cap, AB/BA orderings, thermal sampling) is documented here for
/// the formal run.
private enum P05Configuration {
    /// 1000000 UTF-16 code units per line — the long-line length the formal
    /// run renders. (spec: "Render 1000000-unit lines …")
    static let lineCodeUnits: Int = 1_000_000
    /// The two stopRenderingLineAfter values: 10000 (stop rendering after
    /// 10000 units — early cutoff) and -1 (unlimited — render the whole
    /// line). Each value is a distinct cell axis.
    /// (spec: "…with stopRenderingLineAfter equal to 10000 and -1…")
    static let stopRenderingLineAfterValues: [Int] = [10_000, -1]
    /// The three rendering cells the formal run measures — scale (GPU-
    /// accelerated scale path), fallback (CPU fallback path), and subpixel
    /// (subpixel-positioned glyph path). Each is a distinct cell with its
    /// own verdict.
    /// (spec: "…across scale, fallback, and subpixel cells.")
    static let renderCells: [String] = ["scale", "fallback", "subpixel"]
    /// 30 hot balanced blocks per valid cell. P05 is a HOT workload — the
    /// editor is already loaded and warm; each block is a paired N/C frame
    /// latency measurement, NOT a fresh-process cold launch.
    static let hotBlocksPerCell: Int = 30
    /// The cold path's per-block launch count (P00 only). P05 is hot, so its
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

// MARK: - P05WorkloadTests

final class P05WorkloadTests: XCTestCase {

    // MARK: - Stage 1: 1000000-unit lines; stopRenderingLineAfter 10000/-1;
    //          scale/fallback/subpixel cells

    /// P05 renders 1000000-unit (UTF-16 code unit) lines. (spec: "Render
    /// 1000000-unit lines …")
    func testP05LineIsOneMillionCodeUnits() {
        XCTAssertEqual(
            P05Configuration.lineCodeUnits, 1_000_000,
            "P05 renders 1000000-unit lines."
        )
    }

    /// The two stopRenderingLineAfter values — 10000 (early cutoff) and -1
    /// (unlimited). Each is a distinct cell axis. (spec: "…with
    /// stopRenderingLineAfter equal to 10000 and -1…")
    func testP05StopRenderingLineAfterIsTenThousandAndUnlimited() {
        XCTAssertEqual(
            P05Configuration.stopRenderingLineAfterValues, [10_000, -1]
        )
        XCTAssertEqual(P05Configuration.stopRenderingLineAfterValues.count, 2)
        // -1 is the "unlimited" sentinel (render the whole line).
        XCTAssertEqual(P05Configuration.stopRenderingLineAfterValues.last, -1)
        // 10000 is the early-cutoff value.
        XCTAssertEqual(P05Configuration.stopRenderingLineAfterValues.first, 10_000)
    }

    /// The three rendering cells — scale, fallback, and subpixel. Each is a
    /// distinct cell with its own verdict. (spec: "…across scale, fallback,
    /// and subpixel cells.")
    func testP05RenderCellsAreScaleFallbackSubpixel() {
        XCTAssertEqual(P05Configuration.renderCells.count, 3)
        XCTAssertEqual(
            P05Configuration.renderCells, ["scale", "fallback", "subpixel"]
        )
    }

    // MARK: - Stage 2: 30 hot balanced blocks per valid cell; attempt cap 2x;
    //          AB/BA; no outlier deletion; separate total/component metrics

    /// 30 hot balanced blocks per valid cell — the manifest's
    /// `minimumSamples` fixes the required block count for a verdict. Below
    /// it the engine rejects with `.insufficientSamples`. (spec: "Collect 30
    /// hot balanced blocks per valid cell".)
    func testHotBlockCountIsThirty() throws {
        let manifest = makeManifest(minimumSamples: P05Configuration.hotBlocksPerCell)
        let stats = BootstrapStatistics()
        let blocks = makeBlocks(count: P05Configuration.hotBlocksPerCell)
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

    /// P05 is a HOT workload — its block count (30) is governed by the
    /// manifest's `minimumSamples`, distinct from the COLD path's 50-launch
    /// invariant (`ColdLaunchManager.samplesPerBlock`). The cold-launch
    /// invariants (fresh profile, fresh process tree, tree exited) do NOT
    /// apply to P05's hot blocks: a hot block is a paired N/C latency, not a
    /// fresh-process launch.
    func testHotWorkloadDistinctFromColdLaunchPath() {
        XCTAssertEqual(
            P05Configuration.hotBlocksPerCell, 30,
            "P05 uses 30 HOT blocks per cell."
        )
        XCTAssertEqual(
            ColdLaunchManager.samplesPerBlock,
            P05Configuration.coldPathLaunchesPerBlock,
            "The cold path (P00) uses 50 launches per block; P05 is hot."
        )
        XCTAssertNotEqual(
            P05Configuration.hotBlocksPerCell,
            P05Configuration.coldPathLaunchesPerBlock,
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
        XCTAssertEqual(verdict.bootstrapDrawCount, P05Configuration.bootstrapDrawCount)
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
            P05Configuration.bootstrapDrawCount
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
    /// — for P05 that means both the M0 cell and the M1 cell must pass. No
    /// multiplicity adjustment; evaluated on unrounded binary64 per-cell
    /// results.
    func testIntersectionUnionRequiresEveryComparatorCellToPass() {
        let stats = BootstrapStatistics()
        // Both M0 and M1 cells pass → global pass.
        XCTAssertTrue(stats.intersectionUnion(passResults: [true, true]))
        // Either comparator fails → global fail.
        XCTAssertFalse(stats.intersectionUnion(passResults: [false, true]))
        XCTAssertFalse(stats.intersectionUnion(passResults: [true, false]))
        XCTAssertFalse(stats.intersectionUnion(passResults: [false, false]))
    }

    // MARK: - Stage 5: exact 60 Hz and 120 Hz cells kept separate; deadline
    //          differs; relative threshold identical

    /// Exact 60.0 and 120.0 Hz form the valid refresh cells. 59.94 is NOT
    /// folded to 60.0 (it is deliberately absent from the set).
    func testRefreshCellsAreExact60And120() {
        XCTAssertEqual(
            DisplayModeEnforcer.exactRefreshRates,
            P05Configuration.exactRefreshRates
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
        let m0 = makeManifest(cellID: "p05-longline-60hz-total-native-vs-m0")
        let m1 = makeManifest(cellID: "p05-longline-60hz-total-native-vs-m1")
        let materialM0 = BootstrapStatistics.seedMaterial(for: m0)
        let materialM1 = BootstrapStatistics.seedMaterial(for: m1)
        XCTAssertTrue(materialM0.contains(m0.manifestHash))
        XCTAssertTrue(materialM0.contains(m0.cellID))
        XCTAssertTrue(materialM0.hasSuffix("Q1-R3"))
        XCTAssertNotEqual(materialM0, materialM1, "M0 and M1 cells must seed independently.")
    }

    // MARK: - Full P05 pipeline wiring (synthetic data — NOT a performance
    //          result)

    /// End-to-end wiring proof: the P05 pipeline — collect balanced blocks
    /// → run each verdict form → aggregate via intersection-union — is wired
    /// correctly. Uses SYNTHETIC blocks (not real long-line render timings);
    /// this is a structural wiring check, NOT a performance measurement. No
    /// performance result is recorded or asserted here; the formal run
    /// supplies the real 30-hot-block / 1,000,000-resample measurements.
    func testP05FullPipelineWiringWithSyntheticBlocks() throws {
        let runner = BenchmarkRunner()
        let stats = BootstrapStatistics()

        // A synthetic 30-block balanced cell (native slightly faster than
        // comparator — would pass the no-regression bar). NOT real data.
        let native = [Double](repeating: 99.0, count: 30)
        let comparator = [Double](repeating: 100.0, count: 30)
        let blocks = try runner.collectBlockSamples(native: native, comparator: comparator)

        let m0Manifest = makeManifest(
            cellID: "p05-longline-60hz-total-native-vs-m0",
            comparator: .m0, minimumSamples: 30
        )
        let m1Manifest = makeManifest(
            cellID: "p05-longline-60hz-total-native-vs-m1",
            comparator: .m1, minimumSamples: 30
        )

        // M0 and M1 evaluated independently (each its own verdict).
        let m0Verdict = try stats.positiveRatioVerdict(blocks: blocks, manifest: m0Manifest)
        let m1Verdict = try stats.positiveRatioVerdict(blocks: blocks, manifest: m1Manifest)

        // Every comparator cell's upper bound is at most zero on unrounded
        // binary64 (synthetic native < comparator → passes).
        XCTAssertTrue(m0Verdict.passes)
        XCTAssertTrue(m1Verdict.passes)
        XCTAssertEqual(m0Verdict.bootstrapDrawCount, 1_000_000)
        XCTAssertEqual(m1Verdict.bootstrapDrawCount, 1_000_000)

        // Intersection-union: global no-regression requires BOTH M0 and M1
        // cells to pass.
        XCTAssertTrue(stats.intersectionUnion(verdicts: [m0Verdict, m1Verdict]))
    }

    // MARK: - Helpers

    private func makeManifest(
        cellID: String = "p05-longline-60hz-total-native-vs-m0",
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
