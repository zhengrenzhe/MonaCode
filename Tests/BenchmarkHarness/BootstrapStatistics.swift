// BootstrapStatistics.swift
//
// P00-T009 — Implement the complete Q1-R3 statistical verdict engine.
//
// The Q1-R3 statistical verdict engine. `BootstrapStatistics` consumes paired
// balanced blocks (one complete balanced block per sampling unit) and produces
// the Q1-R3 noninferiority verdict for one cell, plus the intersection-union
// aggregation across cells.
//
// Statistical contract (verification-q1r3-statistical-window-closure):
//
//   • Sampling unit — one complete balanced block. Bootstrap resamples WHOLE
//     blocks WITH replacement; the native/comparator pairing is never split.
//
//   • Positive metric — per-block statistic log(N/C); estimator θ̂ is the
//     arithmetic mean of the per-block log-ratios. Bootstrap draws θ*; the
//     nearest-rank 5% quantile is q05; the basic one-sided upper bound is
//     U = 2θ̂ − q05. Pass (noninferior) when U ≤ 0.
//
//   • Near-zero metric — per-block paired difference N−C; estimator θ̂ is the
//     mean paired difference; same basic upper bound; boundary = 0.
//
//   • Discrete metric — C = 0 still requires ALL N = 0. A deterministic
//     per-cell verdict (no bootstrap).
//
//   • Bootstrap — B = 1,000,000 deterministic draws. The seed is
//     SHA256(manifestHash || UTF8 cellID || UTF8 "Q1-R3"), so the entire draw
//     sequence and hence the verdict is a pure, reproducible function of the
//     manifest + blocks.
//
//   • Intersection-union — the global null ("at least one pre-registered cell
//     gets worse") is rejected iff EVERY cell rejects its own null. No
//     multiplicity adjustment (Berger & Hsu). Equality is evaluated on
//     UNROUNDED binary64 values.
//
// Input rejection (exactly as Q1-R3 defines):
//   positive metric components must be finite, strictly positive, and strictly
//   above the manifest resolution — non-finite, non-positive, negative, zero,
//   and below-resolution values are rejected. Near-zero and discrete metrics
//   relax the resolution/zero rules (those are the domain) but still reject
//   non-finite and negative values.
//
// MonaCode is a Foundation-only boundary: `import Foundation` is the sole
// import. SHA256 and the PRNG are implemented in pure Swift so the engine stays
// reproducible without CryptoKit. This file lives in the `benchmark-harness`
// non-product target.

import Foundation

// MARK: - Errors

/// Input-rejection errors raised by the verdict engine, exactly as Q1-R3
/// defines them for positive-metric component values.
public enum BootstrapStatisticsError: Error, Equatable, Sendable {
    /// NaN, +∞, or −∞.
    case nonFinite
    /// A value that is not strictly positive (≤ 0), when not specifically zero
    /// or negative (the umbrella rejection category).
    case nonPositive
    /// A strictly negative value.
    case negative
    /// Exactly zero (positive or negative zero).
    case zero
    /// A positive value at or below the manifest-declared collector resolution.
    case belowResolution
    /// Fewer balanced blocks than the manifest's `minimumSamples`.
    case insufficientSamples
}

// MARK: - Verdict records

/// The Q1-R3 noninferiority verdict for one bootstrap-evaluated cell.
///
/// All numeric fields are UNROUNDED binary64 values. `passes` is `upperBound
/// <= 0.0` evaluated on the unrounded `upperBound`, never on a rounded or
/// quantized form.
public struct BootstrapVerdict: Equatable, Sendable {
    /// θ̂ — the point estimator (mean of per-block statistics: log(N/C) for the
    /// positive metric, N−C for the near-zero metric).
    public let estimator: Double
    /// Fraction of the B bootstrap draws whose θ* ≤ 0 (treatment non-inferior
    /// or better in that draw). In [0, 1].
    public let positiveRatio: Double
    /// q05 — the nearest-rank 5% quantile of the B bootstrap θ* draws.
    public let quantile05: Double
    /// U = 2θ̂ − q05 — the basic one-sided 95% upper confidence bound.
    public let upperBound: Double
    /// `upperBound <= 0.0` on the unrounded binary64 value.
    public let passes: Bool
    /// The number of bootstrap draws used (always 1,000,000).
    public let bootstrapDrawCount: Int

    /// Creates a verdict record. Public so tests can construct explicit
    /// unrounded-binary64 cases for the intersection-union checks.
    public init(
        estimator: Double,
        positiveRatio: Double,
        quantile05: Double,
        upperBound: Double,
        passes: Bool,
        bootstrapDrawCount: Int
    ) {
        self.estimator = estimator
        self.positiveRatio = positiveRatio
        self.quantile05 = quantile05
        self.upperBound = upperBound
        self.passes = passes
        self.bootstrapDrawCount = bootstrapDrawCount
    }
}

/// The Q1-R3 discrete-zero verdict for one cell. Discrete metrics use no
/// bootstrap: C = 0 still requires ALL N = 0.
public struct DiscreteZeroVerdict: Equatable, Sendable {
    /// `true` iff no block has a zero comparator with a non-zero native.
    public let passes: Bool
    /// The number of blocks whose comparator value is exactly zero.
    public let zeroComparatorBlocks: Int
    /// The number of blocks that violate the discrete-zero rule
    /// (comparator == 0 AND native != 0).
    public let violatingBlocks: Int

    public init(passes: Bool, zeroComparatorBlocks: Int, violatingBlocks: Int) {
        self.passes = passes
        self.zeroComparatorBlocks = zeroComparatorBlocks
        self.violatingBlocks = violatingBlocks
    }
}

// MARK: - SHA256 (pure Swift, Foundation-only)

/// Pure-Swift SHA-256. Implemented here (rather than via CryptoKit) so the
/// engine stays Foundation-only and reproducible without additional imports.
public enum SHA256 {

    /// Computes the SHA-256 digest of `data`.
    public static func hash(_ data: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        ]
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
        ]

        // Pre-processing: append 0x80, pad with zeros to len ≡ 56 (mod 64),
        // then append the 64-bit big-endian bit length.
        var msg = data
        let bitLen = UInt64(msg.count) &* 8
        msg.append(0x80)
        while msg.count % 64 != 56 { msg.append(0x00) }
        for i in (0..<8).reversed() {
            msg.append(UInt8((bitLen >> UInt64(i * 8)) & 0xff))
        }

        // Process each 512-bit chunk.
        var chunkStart = 0
        while chunkStart < msg.count {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let b = chunkStart + i * 4
                w[i] = (UInt32(msg[b]) << 24)
                    | (UInt32(msg[b + 1]) << 16)
                    | (UInt32(msg[b + 2]) << 8)
                    | UInt32(msg[b + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                hh = g; g = f; f = e; e = d &+ temp1
                d = c; c = b; b = a; a = temp1 &+ temp2
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh

            chunkStart += 64
        }

        var out = [UInt8]()
        out.reserveCapacity(32)
        for v in h {
            out.append(UInt8((v >> 24) & 0xff))
            out.append(UInt8((v >> 16) & 0xff))
            out.append(UInt8((v >> 8) & 0xff))
            out.append(UInt8(v & 0xff))
        }
        return out
    }

    @inline(__always)
    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        return (x >> n) | (x << (32 - n))
    }
}

// MARK: - SplitMix64 PRNG (deterministic, seeded from the SHA-256 digest)

/// A deterministic SplitMix64 generator. Seeded once from the SHA-256 digest
/// of the seed material, it yields the reproducible draw sequence used by the
/// bootstrap. Mutating is confined to the instance so a single seeded generator
/// drives all 1,000,000 draws for one cell.
struct SplitMix64 {
    var state: UInt64

    init(state: UInt64) {
        self.state = state
    }

    @inline(__always)
    mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    @inline(__always)
    mutating func nextDouble() -> Double {
        // 53-bit precision in [0, 1).
        return Double(nextUInt64() >> 11) * (1.0 / 9007199254740992.0)
    }
}

// MARK: - BootstrapStatistics

/// The Q1-R3 statistical verdict engine.
public final class BootstrapStatistics {

    /// The fixed bootstrap draw count: exactly 1,000,000 deterministic draws
    /// per cell, as Q1-R3 requires.
    public static let drawCount: Int = 1_000_000

    /// The alpha level for the one-sided upper bound (q05 = nearest-rank 5%).
    private static let alpha: Double = 0.05

    /// Creates a verdict engine.
    public init() {}

    // MARK: - Positive-ratio verdict

    /// Computes the positive-ratio (log-ratio) verdict for one cell.
    ///
    /// Per-block statistic is log(N/C); θ̂ is the mean of the per-block
    /// log-ratios. Rejects non-finite, non-positive, negative, zero, and
    /// below-resolution component values exactly as Q1-R3 defines.
    public func positiveRatioVerdict(
        blocks: [BenchmarkSampleBlock],
        manifest: CellManifest
    ) throws -> BootstrapVerdict {
        try Self.requireSampleCount(blocks.count, manifest: manifest)
        var statistics = [Double](repeating: 0.0, count: blocks.count)
        for i in 0..<blocks.count {
            try Self.validatePositiveComponent(blocks[i].native, resolution: manifest.resolution)
            try Self.validatePositiveComponent(blocks[i].comparator, resolution: manifest.resolution)
            statistics[i] = log(blocks[i].native / blocks[i].comparator)
        }
        let r = bootstrap(statistics: statistics, manifest: manifest)
        let upper = 2.0 * r.thetaHat - r.q05
        return BootstrapVerdict(
            estimator: r.thetaHat,
            positiveRatio: r.positiveRatio,
            quantile05: r.q05,
            upperBound: upper,
            passes: upper <= 0.0,
            bootstrapDrawCount: Self.drawCount
        )
    }

    // MARK: - Near-zero difference verdict (manifest-declared threshold)

    /// Computes the manifest-declared near-zero difference verdict for one cell.
    ///
    /// Per-block statistic is the paired difference N−C; θ̂ is the mean paired
    /// difference. Zero and below-resolution values are the domain (not a
    /// rejection); only non-finite and negative values are rejected.
    public func nearZeroDifferenceVerdict(
        blocks: [BenchmarkSampleBlock],
        manifest: CellManifest
    ) throws -> BootstrapVerdict {
        try Self.requireSampleCount(blocks.count, manifest: manifest)
        var statistics = [Double](repeating: 0.0, count: blocks.count)
        for i in 0..<blocks.count {
            try Self.validateNonNegativeComponent(blocks[i].native)
            try Self.validateNonNegativeComponent(blocks[i].comparator)
            statistics[i] = blocks[i].native - blocks[i].comparator
        }
        let r = bootstrap(statistics: statistics, manifest: manifest)
        let upper = 2.0 * r.thetaHat - r.q05
        return BootstrapVerdict(
            estimator: r.thetaHat,
            positiveRatio: r.positiveRatio,
            quantile05: r.q05,
            upperBound: upper,
            passes: upper <= 0.0,
            bootstrapDrawCount: Self.drawCount
        )
    }

    // MARK: - Discrete-zero verdict

    /// Computes the discrete-zero verdict for one cell. Discrete metrics use no
    /// bootstrap: C = 0 still requires ALL N = 0. A block violates iff its
    /// comparator is zero AND its native is non-zero.
    public func discreteZeroVerdict(
        blocks: [BenchmarkSampleBlock],
        manifest: CellManifest
    ) throws -> DiscreteZeroVerdict {
        try Self.requireSampleCount(blocks.count, manifest: manifest)
        var zeroComparatorBlocks = 0
        var violatingBlocks = 0
        for block in blocks {
            try Self.validateNonNegativeComponent(block.native)
            try Self.validateNonNegativeComponent(block.comparator)
            if block.comparator == 0.0 {
                zeroComparatorBlocks += 1
                if block.native != 0.0 { violatingBlocks += 1 }
            }
        }
        return DiscreteZeroVerdict(
            passes: violatingBlocks == 0,
            zeroComparatorBlocks: zeroComparatorBlocks,
            violatingBlocks: violatingBlocks
        )
    }

    // MARK: - Intersection-union test (unrounded binary64)

    /// Intersection-union aggregation across bootstrap-evaluated cells.
    ///
    /// The global null ("at least one pre-registered cell gets worse") is
    /// rejected iff EVERY cell rejects its own null. No multiplicity
    /// adjustment. Each cell's `passes` is already evaluated on the unrounded
    /// binary64 upper bound, so this aggregation inherits that property.
    public func intersectionUnion(verdicts: [BootstrapVerdict]) -> Bool {
        return verdicts.allSatisfy { $0.passes }
    }

    /// Intersection-union aggregation over raw per-cell pass results, for
    /// mixing bootstrap-evaluated and discrete-zero cells. Each input is the
    /// cell's own noninferiority verdict (already on unrounded binary64 for the
    /// bootstrap cells). Empty input passes vacuously.
    public func intersectionUnion(passResults: [Bool]) -> Bool {
        return passResults.allSatisfy { $0 }
    }

    // MARK: - Seed material (auditable)

    /// The canonical seed material for a cell:
    /// `manifestHash || cellID || "Q1-R3"`. The bootstrap seed is the SHA-256 of
    /// this material's UTF-8 bytes.
    public static func seedMaterial(for manifest: CellManifest) -> String {
        return manifest.manifestHash + manifest.cellID + "Q1-R3"
    }

    // MARK: - Internal bootstrap

    /// Runs the B-draw whole-balanced-block bootstrap over `statistics`.
    /// Returns the positive ratio (fraction of θ* ≤ 0), the nearest-rank 5%
    /// quantile q05, and the point estimator θ̂.
    private func bootstrap(
        statistics: [Double],
        manifest: CellManifest
    ) -> (positiveRatio: Double, q05: Double, thetaHat: Double) {
        let n = statistics.count
        let thetaHat: Double = {
            var s = 0.0
            for v in statistics { s += v }
            return s / Double(n)
        }()

        let B = Self.drawCount
        var rng = SplitMix64(state: Self.bootstrapSeed(for: manifest))
        let un = UInt64(n)
        var stars = [Double](repeating: 0.0, count: B)
        var positiveCount = 0

        statistics.withUnsafeBufferPointer { buf in
            for d in 0..<B {
                var sum = 0.0
                for _ in 0..<n {
                    let idx = Int(rng.nextUInt64() % un)
                    sum += buf[idx]
                }
                let thetaStar = sum / Double(n)
                stars[d] = thetaStar
                if thetaStar <= 0.0 { positiveCount += 1 }
            }
        }

        stars.sort()

        // Nearest-rank 5% quantile: the ceil(α * B)-th value, 1-indexed →
        // index ceil(α * B) - 1. For B = 1,000,000 and α = 0.05 → index 49,999.
        let rank = Int((Double(B) * Self.alpha).rounded(.up)) - 1
        let safeRank = max(0, min(B - 1, rank))
        let q05 = stars[safeRank]
        let positiveRatio = Double(positiveCount) / Double(B)
        return (positiveRatio, q05, thetaHat)
    }

    // MARK: - Internal seed

    /// The SplitMix64 seed: the 32-byte SHA-256 of the seed material's UTF-8,
    /// folded (XOR of the four little-endian UInt64 words) into one UInt64.
    static func bootstrapSeed(for manifest: CellManifest) -> UInt64 {
        let digest = SHA256.hash(Array(seedMaterial(for: manifest).utf8))
        var seed: UInt64 = 0
        for i in 0..<4 {
            let off = i * 8
            var v: UInt64 = 0
            for j in 0..<8 {
                v |= UInt64(digest[off + j]) << (UInt64(j) * 8)
            }
            seed ^= v
        }
        return seed
    }

    // MARK: - Validation

    /// Validates a positive-metric component: finite, strictly positive, and
    /// strictly above the manifest resolution. Emits the specific Q1-R3
    /// rejection category.
    static func validatePositiveComponent(_ v: Double, resolution: Double) throws {
        guard v.isFinite else { throw BootstrapStatisticsError.nonFinite }
        if v.isZero { throw BootstrapStatisticsError.zero }
        if v < 0.0 { throw BootstrapStatisticsError.negative }
        if v <= resolution { throw BootstrapStatisticsError.belowResolution }
        if v <= 0.0 { throw BootstrapStatisticsError.nonPositive }
    }

    /// Validates a non-negative component (near-zero / discrete metrics): finite
    /// and ≥ 0. Zero and below-resolution values are accepted (they are the
    /// near-zero domain).
    static func validateNonNegativeComponent(_ v: Double) throws {
        guard v.isFinite else { throw BootstrapStatisticsError.nonFinite }
        if v < 0.0 { throw BootstrapStatisticsError.negative }
    }

    /// Requires at least `manifest.minimumSamples` balanced blocks (and at
    /// least one).
    static func requireSampleCount(_ count: Int, manifest: CellManifest) throws {
        guard count > 0 else { throw BootstrapStatisticsError.insufficientSamples }
        guard count >= manifest.minimumSamples else {
            throw BootstrapStatisticsError.insufficientSamples
        }
    }
}
