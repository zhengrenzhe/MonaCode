// BenchmarkRunner.swift
//
// P00-T009 — Implement the complete Q1-R3 statistical verdict engine.
//
// `BenchmarkRunner` runs benchmark samples and collects the timing data into
// the Q1-R3 sampling unit: one COMPLETE BALANCED BLOCK. A balanced block pairs
// the native (N) timing with the comparator (C) timing for one measurement
// unit; the block is atomic — the bootstrap resamples WHOLE blocks WITH
// replacement and never splits a block or breaks the N/C pairing.
//
// The runner does not perform statistics; it only assembles balanced blocks
// from paired native/comparator sample streams and validates the pairing.
// `BootstrapStatistics` consumes the blocks.
//
// MonaCode is a Foundation-only boundary: `import Foundation` is the sole
// import. This file lives in the `benchmark-harness` non-product target.

import Foundation

// MARK: - BenchmarkSampleBlock

/// One complete balanced block: the native (treatment) sample paired with the
/// comparator (baseline) sample for a single measurement unit.
///
/// The block is the atomic Q1-R3 sampling unit. Bootstrap resampling selects
/// whole blocks; the native/comparator pairing is never split.
public struct BenchmarkSampleBlock: Equatable, Sendable {
    /// The native (MonaCode) sample value (e.g. a p50 latency in ms, or a unit
    /// cost). For positive metrics this must be finite, strictly positive, and
    /// strictly above the manifest resolution.
    public let native: Double

    /// The comparator (M0/M1) sample value paired with `native` in this block.
    public let comparator: Double

    /// Creates a balanced block from a native/comparator pair.
    public init(native: Double, comparator: Double) {
        self.native = native
        self.comparator = comparator
    }
}

// MARK: - BenchmarkRunnerError

/// Errors raised while collecting balanced blocks.
public enum BenchmarkRunnerError: Error, Equatable, Sendable {
    /// The native and comparator sample streams have different lengths; the
    /// pairing is broken and no balanced block can be formed.
    case unbalanced
}

// MARK: - BenchmarkRunner

/// Collects benchmark samples into balanced blocks for the statistical verdict
/// engine.
///
/// The runner pairs the native and comparator sample streams element-by-element
/// into `BenchmarkSampleBlock` values. The streams MUST have equal length — an
/// unequal length means a product or idle pairing has been broken, which Q1-R3
/// forbids (the bootstrap may only resample whole balanced blocks).
public final class BenchmarkRunner {

    /// Creates a runner.
    public init() {}

    /// Collects paired native/comparator sample streams into balanced blocks.
    ///
    /// - Parameters:
    ///   - native: The native (treatment) sample stream.
    ///   - comparator: The comparator (baseline) sample stream.
    /// - Returns: The balanced blocks, one per paired sample.
    /// - Throws: `BenchmarkRunnerError.unbalanced` if the streams differ in
    ///   length.
    public func collectBlockSamples(
        native: [Double],
        comparator: [Double]
    ) throws -> [BenchmarkSampleBlock] {
        guard native.count == comparator.count else {
            throw BenchmarkRunnerError.unbalanced
        }
        return zip(native, comparator).map { BenchmarkSampleBlock(native: $0.0, comparator: $0.1) }
    }
}
