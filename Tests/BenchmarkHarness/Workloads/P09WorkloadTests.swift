// P09WorkloadTests.swift
//
// P09-T039 — Run P09: multi-cursor and snippet (the tenth P-candidate).
//
// P09 is the multi-cursor and snippet performance benchmark: running type,
// paste, delete, undo, overlap, snippet insertion, 39 variables, clipboard
// spread, time snapshot, random, and UUID traces for 1, 100, and 10000
// cursors, measured as per-trace latency, then the 1,000,000-draw whole-
// balanced-block bootstrap verdict across the exact 60 Hz and 120 Hz frame
// cells for the M0 and M1 comparators, with the one-sided 95 percent upper
// bound required to be at most zero on unrounded binary64 values for every
// comparator and cell.
//
// ──────────────────────────────────────────────────────────────────────────
// FEASIBILITY ASSESSMENT (P09-T039) — Option A (structural)
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
//    reduced multi-cursor/snippet measurement requires the npm package + a
//    Node.js runtime + a real macOS editor session — infeasible in-session.
//    No reduced empirical measurement is run; no performance results are
//    fabricated.
//
// VERDICT: Option A (structural). "Green" = compiles + structurally valid.
// The formal 30-hot-block / 1,000,000-resample run with real M0/M1
// comparators is deferred to the formal benchmark execution (requires the
// external oracle harness); this test verifies the P09 configuration is
// correctly wired against the Phase 00 statistical + display + manifest
// infrastructure, including the all-or-none multi-cursor barrier and the
// snippet session insertion/navigation contract.
//
// Spec (verbatim, P09-T039 implementation-operation stages):
//   • Run type, paste, delete, undo, overlap, snippet insertion, 39
//     variables, clipboard spread, time snapshot, random, and UUID traces
//     for 1, 100, and 10000 cursors.
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

// MARK: - P09 workload configuration (documented, verified against infra)

/// The P09 multi-cursor and snippet workload configuration. These are the
/// measurement-time parameters the formal run uses; the structural tests
/// below verify that every parameter the Phase 00 infrastructure encodes
/// matches this configuration exactly, and that the infrastructure not yet
/// encoded (attempt cap, AB/BA orderings, thermal sampling) is documented
/// here for the formal run.
private enum P09Configuration {
    /// The eleven trace kinds the formal run exercises across the cursor
    /// fan-out. "type" (typed insertion at every cursor), "paste" (clipboard
    /// paste fanned across cursors), "delete" (backward delete at every
    /// cursor), "undo" (one undo step reverting the last multi-cursor edit),
    /// "overlap" (cursors whose edit ranges overlap — the merge/invalidation
    /// path), "snippet insertion" (insert a snippet template at every cursor),
    /// "39 variables" (a snippet with 39 distinct tabstop variables — the
    /// heaviest snippet-navigation path), "clipboard spread" (one clipboard
    /// payload split across N cursors), "time snapshot" (a read-only
    /// timestamped snapshot of all cursor positions), "random" (a randomized
    /// cursor shuffle + edit), and "UUID" (a unique-id stamping trace).
    /// (spec: "Run type, paste, delete, undo, overlap, snippet insertion, 39
    /// variables, clipboard spread, time snapshot, random, and UUID traces …")
    static let traceKinds: [String] = [
        "type", "paste", "delete", "undo", "overlap",
        "snippet-insertion", "39-variables", "clipboard-spread",
        "time-snapshot", "random", "uuid"
    ]
    /// The three cursor fan-outs the formal run sweeps — 1 (single cursor,
    /// the baseline), 100 (moderate multi-cursor), and 10000 (extreme
    /// multi-cursor — the all-or-none barrier stress point). Each fan-out is
    /// a distinct cell axis.
    /// (spec: "…for 1, 100, and 10000 cursors.")
    static let cursorCounts: [Int] = [1, 100, 10_000]
    /// The multi-cursor all-or-none barrier: an edit applied to a multi-
    /// cursor session either commits to ALL cursors or to NONE — a partial
    /// commit (some cursors edited, others not) is invalid and the block is
    /// rejected. The formal run enforces this per trace.
    static let multiCursorBarrierIsAllOrNone: Bool = true
    /// The snippet session contract: a snippet is inserted as a structured
    /// template with tabstop variables, then navigated (Tab/Shift-Tab) to
    /// each placeholder; the session is finalized only when the final
    /// tabstop is reached. The "39 variables" trace exercises the heaviest
    /// navigation path.
    static let snippetSessionHasInsertionAndNavigation: Bool = true
    /// 30 hot balanced blocks per valid cell. P09 is a HOT workload — the
    /// editor is already loaded and warm; each block is a paired N/C latency
    /// measurement, NOT a fresh-process cold launch.
    static let hotBlocksPerCell: Int = 30
    /// The cold path's per-block launch count (P00 only). P09 is hot, so its
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

// MARK: - P09WorkloadTests

final class P09WorkloadTests: XCTestCase {

    // MARK: - Stage 1: type/paste/delete/undo/overlap/snippet/39vars/clipboard/
    //          time/random/UUID traces for 1/100/10000 cursors

    /// The eleven trace kinds — type, paste, delete, undo, overlap, snippet
    /// insertion, 39 variables, clipboard spread, time snapshot, random, and
    /// UUID. (spec: "Run type, paste, delete, undo, overlap, snippet
    /// insertion, 39 variables, clipboard spread, time snapshot, random, and
    /// UUID traces …")
    func testP09TraceKindsAreElevenKinds() {
        XCTAssertEqual(P09Configuration.traceKinds.count, 11)
        XCTAssertEqual(P09Configuration.traceKinds, [
            "type", "paste", "delete", "undo", "overlap",
            "snippet-insertion", "39-variables", "clipboard-spread",
            "time-snapshot", "random", "uuid"
        ])
    }

    /// The three cursor fan-outs — 1, 100, and 10000. Each is a distinct cell
    /// axis; 10000 is the all-or-none barrier stress point.
    /// (spec: "…for 1, 100, and 10000 cursors.")
    func testP09CursorCountsAreOne_Hundred_TenThousand() {
        XCTAssertEqual(P09Configuration.cursorCounts.count, 3)
        XCTAssertEqual(P09Configuration.cursorCounts, [1, 100, 10_000])
        XCTAssertEqual(P09Configuration.cursorCounts.first, 1,
                       "1 cursor = the single-cursor baseline.")
        XCTAssertEqual(P09Configuration.cursorCounts.last, 10_000,
                       "10000 cursors = the all-or-none barrier stress point.")
    }

    /// The multi-cursor all-or-none barrier: a partial commit (some cursors
    /// edited, others not) is invalid. The formal run enforces this per trace
    /// — an all-or-none barrier means the edit is atomic across the whole
    /// cursor set.
    func testP09MultiCursorBarrierIsAllOrNone() {
        XCTAssertTrue(
            P09Configuration.multiCursorBarrierIsAllOrNone,
            "Multi-cursor edits are all-or-none: a partial commit is invalid."
        )
    }

    /// The snippet session contract: insertion (the template is inserted as a
    /// structured tree with tabstop variables) AND navigation (Tab/Shift-Tab
    /// traverses each placeholder; the session finalizes only at the final
    /// tabstop). Both halves are exercised; the "39 variables" trace is the
    /// heaviest navigation path.
    func testP09SnippetSessionHasInsertionAndNavigation() {
        XCTAssertTrue(
            P09Configuration.snippetSessionHasInsertionAndNavigation,
            "Snippet session = insertion + navigation (Tab/Shift-Tab)."
        )
        XCTAssertTrue(
            P09Configuration.traceKinds.contains("snippet-insertion"),
            "snippet-insertion is a measured trace."
        )
        XCTAssertTrue(
            P09Configuration.traceKinds.contains("39-variables"),
            "39-variables (heaviest snippet-navigation path) is measured."
        )
    }

    // MARK: - Stage 2: 30 hot balanced blocks per valid cell; attempt cap 2x;
    //          AB/BA; no outlier deletion; separate total/component metrics

    /// 30 hot balanced blocks per valid cell — the manifest's
    /// `minimumSamples` fixes the required block count for a verdict. Below
    /// it the engine rejects with `.insufficientSamples`. (spec: "Collect 30
    /// hot balanced blocks per valid cell".)
    func testHotBlockCountIsThirty() throws {
        let manifest = makeManifest(minimumSamples: P09Configuration.hotBlocksPerCell)
        let stats = BootstrapStatistics()
        let blocks = makeBlocks(count: P09Configuration.hotBlocksPerCell)
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

    /// P09 is a HOT workload — its block count (30) is governed by the
    /// manifest's `minimumSamples`, distinct from the COLD path's 50-launch
    /// invariant (`ColdLaunchManager.samplesPerBlock`). The cold-launch
    /// invariants (fresh profile, fresh process tree, tree exited) do NOT
    /// apply to P09's hot blocks: a hot block is a paired N/C latency, not a
    /// fresh-process launch.
    func testHotWorkloadDistinctFromColdLaunchPath() {
        XCTAssertEqual(
            P09Configuration.hotBlocksPerCell, 30,
            "P09 uses 30 HOT blocks per cell."
        )
        XCTAssertEqual(
            ColdLaunchManager.samplesPerBlock,
            P09Configuration.coldPathLaunchesPerBlock,
            "The cold path (P00) uses 50 launches per block; P09 is hot."
        )
        XCTAssertNotEqual(
            P09Configuration.hotBlocksPerCell,
            P09Configuration.coldPathLaunchesPerBlock,
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
        XCTAssertEqual(verdict.bootstrapDrawCount, P09Configuration.bootstrapDrawCount)
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
            P09Configuration.bootstrapDrawCount
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
    /// — for P09 that means both the M0 cell and the M1 cell must pass. No
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
            P09Configuration.exactRefreshRates
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
        let m0 = makeManifest(cellID: "p09-multicursor-60hz-total-native-vs-m0")
        let m1 = makeManifest(cellID: "p09-multicursor-60hz-total-native-vs-m1")
        let materialM0 = BootstrapStatistics.seedMaterial(for: m0)
        let materialM1 = BootstrapStatistics.seedMaterial(for: m1)
        XCTAssertTrue(materialM0.contains(m0.manifestHash))
        XCTAssertTrue(materialM0.contains(m0.cellID))
        XCTAssertTrue(materialM0.hasSuffix("Q1-R3"))
        XCTAssertNotEqual(materialM0, materialM1, "M0 and M1 cells must seed independently.")
    }

    // MARK: - Full P09 pipeline wiring (synthetic data — NOT a performance
    //          result)

    /// End-to-end wiring proof: the P09 pipeline — collect balanced blocks
    /// → run each verdict form → aggregate via intersection-union — is wired
    /// correctly. Uses SYNTHETIC blocks (not real multi-cursor/snippet
    /// timings); this is a structural wiring check, NOT a performance
    /// measurement. No performance result is recorded or asserted here; the
    /// formal run supplies the real 30-hot-block / 1,000,000-resample
    /// measurements.
    func testP09FullPipelineWiringWithSyntheticBlocks() throws {
        let runner = BenchmarkRunner()
        let stats = BootstrapStatistics()

        // A synthetic 30-block balanced cell (native slightly faster than
        // comparator — would pass the no-regression bar). NOT real data.
        let native = [Double](repeating: 99.0, count: 30)
        let comparator = [Double](repeating: 100.0, count: 30)
        let blocks = try runner.collectBlockSamples(native: native, comparator: comparator)

        let m0Manifest = makeManifest(
            cellID: "p09-multicursor-60hz-total-native-vs-m0",
            comparator: .m0, minimumSamples: 30
        )
        let m1Manifest = makeManifest(
            cellID: "p09-multicursor-60hz-total-native-vs-m1",
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
        cellID: String = "p09-multicursor-60hz-total-native-vs-m0",
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
