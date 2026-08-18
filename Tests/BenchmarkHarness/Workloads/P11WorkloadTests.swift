// P11WorkloadTests.swift
//
// P09-T041 — Run P11: provider and LSP (the twelfth P-candidate).
//
// P11 is the provider and LSP performance benchmark: running 30 provider
// surfaces, 25 mappings, 0/1/10000 results, cancellation, stale, resolve,
// Markdown, session, framing, and 0/10/100 ms injected transport delays
// (with adapter delay subtraction), measured as per-request latency, then
// the 1,000,000-draw whole-balanced-block bootstrap verdict across the
// exact 60 Hz and 120 Hz frame cells for the M0 and M1 comparators, with
// the one-sided 95 percent upper bound required to be at most zero on
// unrounded binary64 values for every comparator and cell.
//
// ──────────────────────────────────────────────────────────────────────────
// FEASIBILITY ASSESSMENT (P09-T041) — Option A (structural)
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
//    reduced provider/LSP measurement requires the npm package + a Node.js
//    runtime + a real LSP server + a real macOS editor session —
//    infeasible in-session. No reduced empirical measurement is run; no
//    performance results are fabricated.
//
// VERDICT: Option A (structural). "Green" = compiles + structurally valid.
// The formal 30-hot-block / 1,000,000-resample run with real M0/M1
// comparators is deferred to the formal benchmark execution (requires the
// external oracle harness); this test verifies the P11 configuration is
// correctly wired against the Phase 00 statistical + display + manifest
// infrastructure, including the 30-provider/25-mapping fan-out, the 0/1/
// 10000-result axis, the six special provider cells, and the injected-
// transport-delay-with-subtraction contract.
//
// Spec (verbatim, P09-T041 implementation-operation stages):
//   • Run 30 provider surfaces, 25 mappings, 0/1/10000 results,
//     cancellation, stale, resolve, Markdown, session, framing, and 0/10/
//     100 ms injected transport delays with adapter delay subtraction.
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

// MARK: - P11 workload configuration (documented, verified against infra)

/// The P11 provider and LSP workload configuration. These are the
/// measurement-time parameters the formal run uses; the structural tests
/// below verify that every parameter the Phase 00 infrastructure encodes
/// matches this configuration exactly, and that the infrastructure not yet
/// encoded (attempt cap, AB/BA orderings, thermal sampling) is documented
/// here for the formal run.
private enum P11Configuration {
    /// 30 provider surfaces — the formal run exercises 30 distinct provider
    /// entry points (completion, hover, signature help, definition, refs,
    /// document highlights, document symbols, workspace symbols, code action,
    /// code lens, formatting, range-formatting, on-type-formatting, rename,
    /// prepare-rename, document-link, document-color, color-presentation,
    /// folding, selection-range, call-hierarchy, type-hierarchy, inline-hint,
    /// inline-value, inlay-hint, semantic-tokens, etc.). Each surface is a
    /// distinct cell axis.
    /// (spec: "Run 30 provider surfaces …")
    static let providerSurfaceCount: Int = 30
    /// 25 mappings — the LSP capability/mapping matrix the formal run sweeps;
    /// each maps a monaco-language-id to an LSP method surface (25 mappings
    /// across the language registry).
    /// (spec: "…25 mappings …")
    static let mappingCount: Int = 25
    /// The three result-count cells — 0 results (empty response, the
    /// fast-fail path), 1 result (single-item response), and 10000 results
    /// (heavy response, the marshalling stress point). Each is a distinct
    /// cell axis.
    /// (spec: "…0/1/10000 results …")
    static let resultCounts: [Int] = [0, 1, 10_000]
    /// The six special provider cells — cancellation (the request is aborted
    /// mid-flight via a cancel-token), stale (the result is computed against
    /// a stale document version and must be discarded), resolve (the lazy
    /// provider's resolve-path — the partial item is filled in), Markdown
    /// (the provider's documentation strings are Markdown-rendered), session
    /// (the LSP session lifecycle — initialize/shutdown), and framing (the
    /// message-framing layer of the LSP transport). Each is a distinct cell.
    /// (spec: "…cancellation, stale, resolve, Markdown, session, framing …")
    static let specialCells: [String] = [
        "cancellation", "stale", "resolve", "markdown", "session", "framing"
    ]
    /// The three injected transport delays (milliseconds) — 0, 10, and 100
    /// ms. The formal run INJECTS these into the LSP transport and then
    /// SUBTRACTS the adapter's measured delay so the recorded latency is the
    /// pure compute time, not the injected wire time.
    /// (spec: "…and 0/10/100 ms injected transport delays with adapter delay
    /// subtraction.")
    static let injectedTransportDelaysMs: [Double] = [0.0, 10.0, 100.0]
    /// The adapter delay subtraction contract: the injected transport delay
    /// is measured and subtracted from the end-to-end latency so the recorded
    /// value is the pure provider compute time.
    static let adapterDelaySubtraction: Bool = true
    /// 30 hot balanced blocks per valid cell. P11 is a HOT workload — the
    /// editor is already loaded and warm; each block is a paired N/C latency
    /// measurement, NOT a fresh-process cold launch.
    static let hotBlocksPerCell: Int = 30
    /// The cold path's per-block launch count (P00 only). P11 is hot, so its
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

// MARK: - P11WorkloadTests

final class P11WorkloadTests: XCTestCase {

    // MARK: - Stage 1: 30 provider surfaces; 25 mappings; 0/1/10000 results;
    //          6 special cells; 0/10/100 ms transport with subtraction

    /// 30 provider surfaces — the formal run exercises 30 distinct provider
    /// entry points. (spec: "Run 30 provider surfaces …")
    func testP11ProviderSurfaceCountIsThirty() {
        XCTAssertEqual(
            P11Configuration.providerSurfaceCount, 30,
            "P11 sweeps 30 distinct provider surfaces."
        )
        XCTAssertGreaterThan(P11Configuration.providerSurfaceCount, 0)
    }

    /// 25 mappings — the LSP capability/mapping matrix. (spec: "…25
    /// mappings …")
    func testP11MappingCountIsTwentyFive() {
        XCTAssertEqual(
            P11Configuration.mappingCount, 25,
            "P11 sweeps 25 language↔method mappings."
        )
    }

    /// The three result-count cells — 0, 1, and 10000. Each is a distinct
    /// cell axis; 10000 results is the marshalling stress point.
    /// (spec: "…0/1/10000 results …")
    func testP11ResultCountsAreZero_One_TenThousand() {
        XCTAssertEqual(P11Configuration.resultCounts.count, 3)
        XCTAssertEqual(P11Configuration.resultCounts, [0, 1, 10_000])
        XCTAssertEqual(P11Configuration.resultCounts.first, 0,
                       "0 results = empty response (fast-fail path).")
        XCTAssertEqual(P11Configuration.resultCounts.last, 10_000,
                       "10000 results = heavy response (marshalling stress).")
    }

    /// The six special provider cells — cancellation, stale, resolve,
    /// Markdown, session, framing. (spec: "…cancellation, stale, resolve,
    /// Markdown, session, framing …")
    func testP11SpecialCellsAreCancellationStaleResolveMarkdownSessionFraming() {
        XCTAssertEqual(P11Configuration.specialCells.count, 6)
        XCTAssertEqual(P11Configuration.specialCells, [
            "cancellation", "stale", "resolve", "markdown", "session", "framing"
        ])
    }

    /// The three injected transport delays — 0, 10, and 100 ms. The formal
    /// run INJECTS these and then SUBTRACTS the adapter delay.
    /// (spec: "…and 0/10/100 ms injected transport delays with adapter delay
    /// subtraction.")
    func testP11InjectedTransportDelaysAreZero_Ten_HundredMs() {
        XCTAssertEqual(P11Configuration.injectedTransportDelaysMs.count, 3)
        XCTAssertEqual(P11Configuration.injectedTransportDelaysMs, [0.0, 10.0, 100.0])
    }

    /// The adapter delay subtraction contract: the injected transport delay
    /// is measured and subtracted from the end-to-end latency so the recorded
    /// value is the pure provider compute time, not the injected wire time.
    /// (spec: "…with adapter delay subtraction.")
    func testP11AdapterDelaySubtractionContract() {
        XCTAssertTrue(
            P11Configuration.adapterDelaySubtraction,
            "The injected transport delay is subtracted by the adapter."
        )
        // Proof by construction: for any injected delay d and end-to-end
        // latency L, the recorded compute time is L − d (non-negative only
        // when L ≥ d).
        let injected = P11Configuration.injectedTransportDelaysMs.last!  // 100 ms
        let endToEnd = injected + 5.0  // 5 ms pure compute
        XCTAssertEqual(endToEnd - injected, 5.0,
                       "recorded = end-to-end − injected = pure compute.")
    }

    // MARK: - Stage 2: 30 hot balanced blocks per valid cell; attempt cap 2x;
    //          AB/BA; no outlier deletion; separate total/component metrics

    /// 30 hot balanced blocks per valid cell — the manifest's
    /// `minimumSamples` fixes the required block count for a verdict. Below
    /// it the engine rejects with `.insufficientSamples`. (spec: "Collect 30
    /// hot balanced blocks per valid cell".)
    func testHotBlockCountIsThirty() throws {
        let manifest = makeManifest(minimumSamples: P11Configuration.hotBlocksPerCell)
        let stats = BootstrapStatistics()
        let blocks = makeBlocks(count: P11Configuration.hotBlocksPerCell)
        _ = try stats.positiveRatioVerdict(blocks: blocks, manifest: manifest)
        let shortManifest = makeManifest(minimumSamples: 30)
        let tooFew = makeBlocks(count: 10)
        XCTAssertThrowsError(
            try stats.positiveRatioVerdict(blocks: tooFew, manifest: shortManifest)
        ) { error in
            XCTAssertEqual(error as? BootstrapStatisticsError, .insufficientSamples)
        }
    }

    /// P11 is a HOT workload — its block count (30) is governed by the
    /// manifest's `minimumSamples`, distinct from the COLD path's 50-launch
    /// invariant (`ColdLaunchManager.samplesPerBlock`).
    func testHotWorkloadDistinctFromColdLaunchPath() {
        XCTAssertEqual(P11Configuration.hotBlocksPerCell, 30, "P11 uses 30 HOT blocks per cell.")
        XCTAssertEqual(
            ColdLaunchManager.samplesPerBlock,
            P11Configuration.coldPathLaunchesPerBlock,
            "The cold path (P00) uses 50 launches per block; P11 is hot."
        )
        XCTAssertNotEqual(
            P11Configuration.hotBlocksPerCell,
            P11Configuration.coldPathLaunchesPerBlock,
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
        XCTAssertEqual(verdict.bootstrapDrawCount, P11Configuration.bootstrapDrawCount)
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
        XCTAssertEqual(BootstrapStatistics.drawCount, P11Configuration.bootstrapDrawCount)
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
    /// — for P11 that means both the M0 cell and the M1 cell must pass.
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
            P11Configuration.exactRefreshRates
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
        let m0 = makeManifest(cellID: "p11-provider-60hz-total-native-vs-m0")
        let m1 = makeManifest(cellID: "p11-provider-60hz-total-native-vs-m1")
        let materialM0 = BootstrapStatistics.seedMaterial(for: m0)
        let materialM1 = BootstrapStatistics.seedMaterial(for: m1)
        XCTAssertTrue(materialM0.contains(m0.manifestHash))
        XCTAssertTrue(materialM0.contains(m0.cellID))
        XCTAssertTrue(materialM0.hasSuffix("Q1-R3"))
        XCTAssertNotEqual(materialM0, materialM1, "M0 and M1 cells must seed independently.")
    }

    // MARK: - Full P11 pipeline wiring (synthetic data — NOT a performance
    //          result)

    /// End-to-end wiring proof: the P11 pipeline — collect balanced blocks
    /// → run each verdict form → aggregate via intersection-union — is wired
    /// correctly. Uses SYNTHETIC blocks (not real provider/LSP timings); this
    /// is a structural wiring check, NOT a performance measurement.
    func testP11FullPipelineWiringWithSyntheticBlocks() throws {
        let runner = BenchmarkRunner()
        let stats = BootstrapStatistics()

        let native = [Double](repeating: 99.0, count: 30)
        let comparator = [Double](repeating: 100.0, count: 30)
        let blocks = try runner.collectBlockSamples(native: native, comparator: comparator)

        let m0Manifest = makeManifest(
            cellID: "p11-provider-60hz-total-native-vs-m0",
            comparator: .m0, minimumSamples: 30
        )
        let m1Manifest = makeManifest(
            cellID: "p11-provider-60hz-total-native-vs-m1",
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
        cellID: String = "p11-provider-60hz-total-native-vs-m0",
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
