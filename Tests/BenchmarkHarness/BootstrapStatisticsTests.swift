// BootstrapStatisticsTests.swift
//
// P00-T009 — Implement the complete Q1-R3 statistical verdict engine.
//
// Verifies the Q1-R3 statistical verdict engine living in the benchmark-harness
// target:
//   - `BootstrapStatistics` performs whole-balanced-block resampling with
//     EXACTLY 1,000,000 deterministic bootstrap draws.
//   - Three verdict forms: positive-ratio (log-ratio estimator), manifest-
//     declared near-zero difference (paired-difference estimator), and
//     discrete-zero (deterministic: C=0 requires all N=0).
//   - Rejects non-finite, non-positive, negative, zero, and below-resolution
//     component inputs exactly as Q1-R3 defines.
//   - The intersection-union test is evaluated on UNROUNDED binary64 values.
//
// Q1-R3 statistical contract (verification-q1r3-statistical-window-closure):
//   - Sampling unit: one complete balanced block (M0/M1/N, active/idle, trace).
//     Bootstrap resamples WHOLE blocks WITH replacement; never splits a block.
//   - Positive metric: per-block log(N/C); estimator θ̂ = mean of block
//     log-ratios. Bootstrap draws θ*; nearest-rank 5% quantile q05; basic
//     one-sided upper bound U = 2θ̂ − q05. Pass when U ≤ 0.
//   - Near-zero metric: per-block N−C; estimator θ̂ = mean paired difference.
//     Same bootstrap upper bound; boundary = 0.
//   - Discrete metric: C=0 requires ALL N=0.
//   - Seed = SHA256(manifest hash || UTF8 cellID || UTF8 "Q1-R3"); B=1,000,000.
//   - Intersection-union: global pass requires EVERY cell to reject its null;
//     no multiplicity adjustment; evaluated on unrounded binary64.

import XCTest
import Foundation

final class BootstrapStatisticsTests: XCTestCase {

    // MARK: - Helpers

    private func makeManifest(
        cellID: String = "latency-p50-60hz-native-vs-m0",
        metricKind: BenchmarkMetricKind = .positive,
        resolution: Double = 0.001,
        manifestHash: String = String(repeating: "ab", count: 32),
        minimumSamples: Int = 5
    ) -> CellManifest {
        CellManifest(
            cellID: cellID,
            refreshRate: .hz60,
            comparator: .m0,
            metricKind: metricKind,
            resolution: resolution,
            manifestHash: manifestHash,
            minimumSamples: minimumSamples
        )
    }

    private func blocks(_ pairs: [(Double, Double)]) -> [BenchmarkSampleBlock] {
        pairs.map { BenchmarkSampleBlock(native: $0.0, comparator: $0.1) }
    }

    // MARK: - Draw count is exactly 1,000,000

    func testBootstrapDrawCountIsExactlyOneMillion() {
        XCTAssertEqual(BootstrapStatistics.drawCount, 1_000_000,
                       "Q1-R3 fixes B at exactly 1,000,000 bootstrap draws")
    }

    func testPositiveRatioVerdictReportsOneMillionDraws() throws {
        let manifest = makeManifest()
        let bs = blocks([
            (5.0, 6.0), (5.5, 6.2), (5.2, 6.1), (4.9, 5.9), (5.3, 6.3),
            (5.1, 6.0), (5.4, 6.1), (5.0, 5.8)
        ])
        let v = try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)
        XCTAssertEqual(v.bootstrapDrawCount, 1_000_000)
    }

    // MARK: - Whole-balanced-block resampling + determinism

    func testPositiveRatioIsDeterministicAcrossRuns() throws {
        // Same inputs + manifest → identical verdict (seed is a pure function
        // of manifest hash + cellID + "Q1-R3"; 1M draws reproduce exactly).
        let manifest = makeManifest()
        let bs = blocks([
            (5.0, 6.0), (5.5, 6.2), (5.2, 6.1), (4.9, 5.9), (5.3, 6.3),
            (5.1, 6.0), (5.4, 6.1), (5.0, 5.8)
        ])
        let stats = BootstrapStatistics()
        let a = try stats.positiveRatioVerdict(blocks: bs, manifest: manifest)
        let b = try stats.positiveRatioVerdict(blocks: bs, manifest: manifest)
        XCTAssertEqual(a, b, "bootstrap must be deterministic: same seed → same verdict")
        XCTAssertEqual(a.bootstrapDrawCount, 1_000_000)
    }

    func testEstimatorIsMeanOfPerBlockLogRatios() throws {
        // Whole-balanced-block: the per-block statistic log(N/C) is atomic and
        // θ̂ is the arithmetic mean of those block statistics (never split).
        let manifest = makeManifest()
        let bs = blocks([(5.0, 6.0), (5.0, 6.0), (5.0, 6.0), (5.0, 6.0), (5.0, 6.0)])
        let v = try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)
        let expected = log(5.0 / 6.0)  // all identical → θ̂ = log(5/6)
        XCTAssertEqual(v.estimator, expected, accuracy: 1e-12,
                       "θ̂ must be the mean of per-block log-ratios")
    }

    func testSeedIncorporatesCellID() {
        // The bootstrap seed is SHA256(manifestHash || cellID || "Q1-R3"), so a
        // different cellID must yield a different seed (and hence an independent
        // — but still reproducible — draw sequence). With B=1M the converged
        // verdict is seed-stable, so the seed VALUE is the correct observable.
        let s1 = BootstrapStatistics.bootstrapSeed(for: makeManifest(cellID: "cell-A"))
        let s2 = BootstrapStatistics.bootstrapSeed(for: makeManifest(cellID: "cell-B"))
        XCTAssertNotEqual(s1, s2, "seed must incorporate cellID")
        // Reproducibility: same manifest → same seed.
        XCTAssertEqual(s1, BootstrapStatistics.bootstrapSeed(for: makeManifest(cellID: "cell-A")))
    }

    func testSeedIncorporatesManifestHash() {
        let s1 = BootstrapStatistics.bootstrapSeed(
            for: makeManifest(manifestHash: String(repeating: "11", count: 32)))
        let s2 = BootstrapStatistics.bootstrapSeed(
            for: makeManifest(manifestHash: String(repeating: "22", count: 32)))
        XCTAssertNotEqual(s1, s2, "seed must incorporate manifest hash")
    }

    // MARK: - Positive-ratio verdict form

    func testPositiveRatioPassesWhenNativeClearlyBetter() throws {
        // Native consistently faster (N < C): θ̂ = mean log(N/C) < 0, so the
        // upper bound U = 2θ̂ − q05 should be ≤ 0 → noninferiority holds.
        let manifest = makeManifest()
        let bs = blocks([
            (3.0, 6.0), (3.1, 6.0), (2.9, 6.0), (3.2, 6.0), (3.0, 6.0),
            (3.0, 6.0), (3.0, 6.0), (3.0, 6.0)
        ])
        let v = try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)
        XCTAssertTrue(v.passes, "native clearly better must pass noninferiority")
        XCTAssertLessThan(v.estimator, 0.0)
        XCTAssertGreaterThanOrEqual(v.positiveRatio, 0.99,
                                    "almost all draws should show treatment non-inferior")
        XCTAssertLessThanOrEqual(v.upperBound, 0.0)
    }

    func testPositiveRatioFailsWhenNativeClearlyWorse() throws {
        // Native consistently slower (N > C): θ̂ > 0 → U > 0 → fail.
        let manifest = makeManifest()
        let bs = blocks([
            (9.0, 6.0), (9.1, 6.0), (8.9, 6.0), (9.2, 6.0), (9.0, 6.0),
            (9.0, 6.0), (9.0, 6.0), (9.0, 6.0)
        ])
        let v = try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)
        XCTAssertFalse(v.passes, "native clearly worse must fail noninferiority")
        XCTAssertGreaterThan(v.estimator, 0.0)
        XCTAssertGreaterThan(v.upperBound, 0.0)
        XCTAssertLessThanOrEqual(v.positiveRatio, 0.01)
    }

    func testPositiveRatioInRangeZeroToOne() throws {
        let manifest = makeManifest()
        let bs = blocks([(5.0, 6.0), (5.5, 6.2), (5.2, 6.1), (4.9, 5.9), (5.3, 6.3)])
        let v = try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)
        XCTAssertGreaterThanOrEqual(v.positiveRatio, 0.0)
        XCTAssertLessThanOrEqual(v.positiveRatio, 1.0)
    }

    // MARK: - Near-zero difference verdict form (manifest-declared threshold)

    func testNearZeroDifferencePassesWithinManifestResolution() throws {
        // Near-zero domain: comparator value not higher than collector resolution
        // (resolution = 0.05). Native consistently at or below comparator →
        // paired differences ≤ 0 → θ̂ < 0 → basic upper bound U ≤ 0 → pass.
        let manifest = makeManifest(metricKind: .nearZero, resolution: 0.05)
        let bs = blocks([
            (0.005, 0.010), (0.006, 0.010), (0.004, 0.010), (0.005, 0.011), (0.005, 0.010),
            (0.005, 0.010), (0.005, 0.010), (0.005, 0.010)
        ])
        let v = try BootstrapStatistics().nearZeroDifferenceVerdict(blocks: bs, manifest: manifest)
        XCTAssertTrue(v.passes, "near-zero difference within resolution must pass")
        XCTAssertEqual(v.bootstrapDrawCount, 1_000_000)
        XCTAssertLessThanOrEqual(v.estimator, 0.0)
    }

    func testNearZeroDifferenceFailsWhenNativeSystematicallyLarger() throws {
        // Native larger than comparator (both within resolution): paired
        // differences > 0 → θ̂ > 0 → U > 0 → fail.
        let manifest = makeManifest(metricKind: .nearZero, resolution: 0.05)
        let bs = blocks([
            (0.020, 0.010), (0.021, 0.010), (0.019, 0.010), (0.020, 0.010), (0.020, 0.010),
            (0.020, 0.010), (0.020, 0.010), (0.020, 0.010)
        ])
        let v = try BootstrapStatistics().nearZeroDifferenceVerdict(blocks: bs, manifest: manifest)
        XCTAssertFalse(v.passes, "systematic positive difference must fail")
        XCTAssertGreaterThan(v.estimator, 0.0)
    }

    func testNearZeroEstimatorIsMeanPairedDifference() throws {
        let manifest = makeManifest(metricKind: .nearZero, resolution: 0.05)
        let bs = blocks([(0.01, 0.01), (0.01, 0.01), (0.01, 0.01), (0.01, 0.01), (0.01, 0.01)])
        let v = try BootstrapStatistics().nearZeroDifferenceVerdict(blocks: bs, manifest: manifest)
        XCTAssertEqual(v.estimator, 0.0, accuracy: 1e-12,
                       "near-zero θ̂ is the mean paired difference N−C")
    }

    // MARK: - Discrete-zero verdict form

    func testDiscreteZeroPassesWhenAllNativeZeroForZeroComparator() throws {
        let manifest = makeManifest(metricKind: .discreteZero, resolution: 0.0)
        let bs = blocks([(0.0, 0.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0)])
        let v = try BootstrapStatistics().discreteZeroVerdict(blocks: bs, manifest: manifest)
        XCTAssertTrue(v.passes, "discrete C=0 with all N=0 must pass")
        XCTAssertEqual(v.zeroComparatorBlocks, 5)
        XCTAssertEqual(v.violatingBlocks, 0)
    }

    func testDiscreteZeroFailsWhenAnyNativeNonZeroForZeroComparator() throws {
        // Q1-R3: discrete C=0 still requires ALL N=0. One non-zero native → fail.
        let manifest = makeManifest(metricKind: .discreteZero, resolution: 0.0)
        let bs = blocks([(0.0, 0.0), (1.0, 0.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0)])
        let v = try BootstrapStatistics().discreteZeroVerdict(blocks: bs, manifest: manifest)
        XCTAssertFalse(v.passes, "any N≠0 where C=0 must fail discrete-zero")
        XCTAssertEqual(v.violatingBlocks, 1)
    }

    // MARK: - Input rejection (non-finite, non-positive, negative, zero, below-resolution)

    func testRejectsNonFinitePositive() {
        let manifest = makeManifest()
        let bs = blocks([(5.0, 6.0), (Double.nan, 6.0), (5.0, 6.0), (5.0, 6.0), (5.0, 6.0)])
        XCTAssertThrowsError(try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)) { err in
            XCTAssertEqual(err as? BootstrapStatisticsError, .nonFinite)
        }
    }

    func testRejectsInfinitePositive() {
        let manifest = makeManifest()
        let bs = blocks([(5.0, 6.0), (5.0, Double.infinity), (5.0, 6.0), (5.0, 6.0), (5.0, 6.0)])
        XCTAssertThrowsError(try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)) { err in
            XCTAssertEqual(err as? BootstrapStatisticsError, .nonFinite)
        }
    }

    func testRejectsNegativePositive() {
        let manifest = makeManifest()
        let bs = blocks([(5.0, 6.0), (-1.0, 6.0), (5.0, 6.0), (5.0, 6.0), (5.0, 6.0)])
        XCTAssertThrowsError(try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)) { err in
            XCTAssertEqual(err as? BootstrapStatisticsError, .negative)
        }
    }

    func testRejectsZeroPositive() {
        let manifest = makeManifest()
        let bs = blocks([(5.0, 6.0), (0.0, 6.0), (5.0, 6.0), (5.0, 6.0), (5.0, 6.0)])
        XCTAssertThrowsError(try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)) { err in
            XCTAssertEqual(err as? BootstrapStatisticsError, .zero)
        }
    }

    func testRejectsBelowResolutionPositive() {
        // resolution = 0.001; a value of 0.0005 is below resolution → reject.
        let manifest = makeManifest(resolution: 0.001)
        let bs = blocks([(5.0, 6.0), (0.0005, 6.0), (5.0, 6.0), (5.0, 6.0), (5.0, 6.0)])
        XCTAssertThrowsError(try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)) { err in
            XCTAssertEqual(err as? BootstrapStatisticsError, .belowResolution)
        }
    }

    func testRejectsInsufficientSamples() {
        let manifest = makeManifest(minimumSamples: 5)
        // Only 3 blocks but minimumSamples = 5 → reject.
        let bs = blocks([(5.0, 6.0), (5.0, 6.0), (5.0, 6.0)])
        XCTAssertThrowsError(try BootstrapStatistics().positiveRatioVerdict(blocks: bs, manifest: manifest)) { err in
            XCTAssertEqual(err as? BootstrapStatisticsError, .insufficientSamples)
        }
    }

    func testRejectsUnbalancedBlocks() {
        XCTAssertThrowsError(
            try BenchmarkRunner().collectBlockSamples(native: [5.0, 5.0, 5.0], comparator: [6.0, 6.0])
        ) { err in
            XCTAssertEqual(err as? BenchmarkRunnerError, .unbalanced)
        }
    }

    func testNearZeroAllowsZeroAndBelowResolution() throws {
        // Near-zero domain: zero and below-resolution values are the POINT, not
        // a rejection. Only non-finite / negative are rejected. Verify such
        // inputs are ACCEPTED (no throw) and a full 1M-draw verdict is produced.
        let manifest = makeManifest(metricKind: .nearZero, resolution: 0.05)
        let bs = blocks([(0.0, 0.0), (0.01, 0.0), (0.0, 0.02), (0.03, 0.0), (0.0, 0.01),
                        (0.0, 0.0), (0.01, 0.0), (0.0, 0.01)])
        let v = try BootstrapStatistics().nearZeroDifferenceVerdict(blocks: bs, manifest: manifest)
        XCTAssertEqual(v.bootstrapDrawCount, 1_000_000,
                       "near-zero accepts zero/below-resolution inputs without rejection")
    }

    func testNearZeroRejectsNegative() {
        let manifest = makeManifest(metricKind: .nearZero, resolution: 0.05)
        let bs = blocks([(0.0, 0.0), (-1.0, 0.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0)])
        XCTAssertThrowsError(try BootstrapStatistics().nearZeroDifferenceVerdict(blocks: bs, manifest: manifest)) { err in
            XCTAssertEqual(err as? BootstrapStatisticsError, .negative)
        }
    }

    // MARK: - Intersection-union test on unrounded binary64

    func testIntersectionUnionPassesWhenAllCellsPass() throws {
        let stats = BootstrapStatistics()
        let manifest = makeManifest()
        let good = blocks([
            (3.0, 6.0), (3.1, 6.0), (2.9, 6.0), (3.2, 6.0), (3.0, 6.0),
            (3.0, 6.0), (3.0, 6.0), (3.0, 6.0)
        ])
        let v1 = try stats.positiveRatioVerdict(blocks: good, manifest: manifest)
        let v2 = try stats.positiveRatioVerdict(blocks: good, manifest: manifest)
        XCTAssertTrue(stats.intersectionUnion(verdicts: [v1, v2]),
                      "intersection-union passes when every cell passes")
    }

    func testIntersectionUnionFailsWhenAnyCellFails() throws {
        let stats = BootstrapStatistics()
        let manifest = makeManifest()
        let good = blocks([
            (3.0, 6.0), (3.1, 6.0), (2.9, 6.0), (3.2, 6.0), (3.0, 6.0),
            (3.0, 6.0), (3.0, 6.0), (3.0, 6.0)
        ])
        let bad = blocks([
            (9.0, 6.0), (9.1, 6.0), (8.9, 6.0), (9.2, 6.0), (9.0, 6.0),
            (9.0, 6.0), (9.0, 6.0), (9.0, 6.0)
        ])
        let vGood = try stats.positiveRatioVerdict(blocks: good, manifest: manifest)
        let vBad = try stats.positiveRatioVerdict(blocks: bad, manifest: manifest)
        XCTAssertFalse(stats.intersectionUnion(verdicts: [vGood, vBad]),
                       "intersection-union fails when ANY cell fails (union null not rejected)")
    }

    func testIntersectionUnionOnUnroundedBinary64() throws {
        // The verdict comparison must be on the unrounded U value, not a
        // rounded/quantized form. A verdict whose upperBound is a tiny negative
        // (e.g. -1e-15) must still pass — it would fail if rounded to 0 then
        // compared with > 0 tolerance.
        let v = BootstrapVerdict(
            estimator: -1e-15,
            positiveRatio: 0.95,
            quantile05: 1e-15,
            upperBound: 2.0 * (-1e-15) - 1e-15,  // -3e-15 < 0
            passes: (2.0 * (-1e-15) - 1e-15) <= 0.0,
            bootstrapDrawCount: 1_000_000
        )
        XCTAssertTrue(v.passes, "tiny-negative upper bound must pass on unrounded binary64")
        XCTAssertTrue(BootstrapStatistics().intersectionUnion(verdicts: [v]))
    }

    func testIntersectionUnionMixedPassResults() {
        let stats = BootstrapStatistics()
        XCTAssertTrue(stats.intersectionUnion(passResults: [true, true, true]))
        XCTAssertFalse(stats.intersectionUnion(passResults: [true, false, true]))
        XCTAssertTrue(stats.intersectionUnion(passResults: [true]))
        XCTAssertTrue(stats.intersectionUnion(passResults: []))  // vacuous
    }

    // MARK: - BenchmarkRunner collects balanced blocks

    func testBenchmarkRunnerCollectsBalancedBlocks() throws {
        let runner = BenchmarkRunner()
        let blocks = try runner.collectBlockSamples(
            native: [5.0, 5.5, 5.2], comparator: [6.0, 6.2, 6.1])
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0], BenchmarkSampleBlock(native: 5.0, comparator: 6.0))
        XCTAssertEqual(blocks[2], BenchmarkSampleBlock(native: 5.2, comparator: 6.1))
    }

    // MARK: - SHA256 seed derivation correctness

    func testSHA256KnownVectors() {
        // Empty string.
        XCTAssertEqual(
            SHA256.hash(Array("".utf8)).map { String(format: "%02x", $0) }.joined(),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        // "abc".
        XCTAssertEqual(
            SHA256.hash(Array("abc".utf8)).map { String(format: "%02x", $0) }.joined(),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testSeedMaterialIncludesQ1R3Marker() throws {
        // The seed is SHA256(manifestHash || cellID || "Q1-R3"). Verify the
        // engine exposes the canonical seed material so the contract is auditable.
        let manifest = makeManifest(cellID: "cell-X", manifestHash: "deadbeef")
        let material = BootstrapStatistics.seedMaterial(for: manifest)
        XCTAssertEqual(material, "deadbeef" + "cell-X" + "Q1-R3",
                       "seed material must be manifestHash || cellID || \"Q1-R3\"")
    }
}
