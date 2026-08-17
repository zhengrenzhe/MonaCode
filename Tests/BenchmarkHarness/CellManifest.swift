// CellManifest.swift
//
// P00-T009 — Implement the complete Q1-R3 statistical verdict engine.
//
// A `CellManifest` describes one pre-registered Q1 benchmark cell before any
// sample is taken. Q1-R3 requires that every cell be enumerated and signed in a
// manifest BEFORE running; any post-hoc add/delete/merge or change of
// statistic creates a new Q revision. The manifest is therefore an immutable,
// value-typed record that fixes the cell's identity and statistical parameters.
//
// A cell is the Cartesian product of:
//   baseline (comparator: M0 / M1 / native) × workload × metric × statistic ×
//   refresh (60 Hz / 120 Hz) × total/component.
//
// 60 Hz and 120 Hz are DISTINCT cells — they are never mixed. The `resolution`
// field is the manifest-declared collector resolution: for positive metrics
// every per-block value must be strictly greater than `resolution`; for
// near-zero metrics the comparator value may be at or below `resolution`.
//
// MonaCode is a Foundation-only boundary: `import Foundation` is the sole
// import. This file lives in the `benchmark-harness` non-product target.

import Foundation

// MARK: - Cell axes

/// The display refresh-rate cell axis. 60 Hz and 120 Hz are distinct cells;
/// they are never mixed within one verdict.
public enum BenchmarkRefreshRate: String, Sendable, Equatable {
    case hz60 = "60Hz"
    case hz120 = "120Hz"
}

/// The comparator (baseline) cell axis. M0 is the pinned npm
/// `monaco-editor@0.56.0` oracle; M1 is the built comparator; `native` is
/// MonaCode's own subject. Each N/M0 and N/M1 cell is a separate verdict.
public enum BenchmarkComparator: String, Sendable, Equatable {
    case m0 = "M0"
    case m1 = "M1"
    case native = "native"
}

/// The statistical verdict form a cell uses. This selects the per-block
/// estimator and the input-rejection rules exactly as Q1-R3 defines them.
public enum BenchmarkMetricKind: String, Sendable, Equatable {
    /// Positive metric: per-block log(N/C); values must be finite, strictly
    /// positive, and strictly above the manifest resolution.
    case positive
    /// Near-zero metric: per-block paired difference N−C; the comparator value
    /// is not higher than collector resolution, so zero and below-resolution
    /// values are the domain (not a rejection).
    case nearZero
    /// Discrete metric: C=0 still requires ALL N=0. No bootstrap; a purely
    /// deterministic per-cell verdict.
    case discreteZero
}

// MARK: - CellManifest

/// An immutable, pre-registered manifest for one benchmark cell.
///
/// The manifest is signed before any sample is collected. The `manifestHash`
/// participates in the deterministic bootstrap seed
/// (SHA256(manifestHash || cellID || "Q1-R3")), so any change to a manifest
/// field that alters the hash produces a different bootstrap sequence — the
/// audit trail is reproducible.
public struct CellManifest: Equatable, Sendable {

    /// The unique, pre-registered cell identifier (e.g.
    /// `"latency-p50-60hz-native-vs-m0"`).
    public let cellID: String

    /// The display refresh-rate axis. 60 Hz and 120 Hz are distinct cells.
    public let refreshRate: BenchmarkRefreshRate

    /// The comparator (baseline) axis.
    public let comparator: BenchmarkComparator

    /// The statistical verdict form this cell uses.
    public let metricKind: BenchmarkMetricKind

    /// The manifest-declared collector resolution. For positive metrics every
    /// per-block value must be strictly greater than this; for near-zero
    /// metrics the comparator value may be at or below this.
    public let resolution: Double

    /// The hex SHA-256 of the signed manifest this cell belongs to. Enters the
    /// bootstrap seed verbatim.
    public let manifestHash: String

    /// The minimum number of balanced blocks required for a verdict. Below
    /// this count the engine rejects with `.insufficientSamples`.
    public let minimumSamples: Int

    /// Creates a pre-registered cell manifest.
    public init(
        cellID: String,
        refreshRate: BenchmarkRefreshRate,
        comparator: BenchmarkComparator,
        metricKind: BenchmarkMetricKind,
        resolution: Double,
        manifestHash: String,
        minimumSamples: Int
    ) {
        precondition(!cellID.isEmpty, "cellID must be non-empty")
        precondition(resolution.isFinite, "resolution must be finite")
        precondition(resolution >= 0.0, "resolution must be non-negative")
        precondition(!manifestHash.isEmpty, "manifestHash must be non-empty")
        precondition(minimumSamples > 0, "minimumSamples must be positive")
        self.cellID = cellID
        self.refreshRate = refreshRate
        self.comparator = comparator
        self.metricKind = metricKind
        self.resolution = resolution
        self.manifestHash = manifestHash
        self.minimumSamples = minimumSamples
    }
}
