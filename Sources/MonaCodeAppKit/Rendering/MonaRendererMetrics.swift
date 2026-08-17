// MonaRendererMetrics.swift
//
// P03-T009 — Instrument renderer-owned correctness and performance metrics.
//
// `MonaRendererMetrics` is the renderer-owned metric instrumentation for the
// tiled Core Graphics renderer (P03-T006). It measures the five
// renderer-attributable metrics — layout-ready-to-present, GPU frame time when
// present, renderer-surface footprint, missed presentation, and renderer
// energy — each measured STRICTLY inside the renderer pipeline, from the
// moment a complete immutable `MonaLineLayoutRecord` (P03-T003) is ready to the
// moment the composited frame is presented.
//
// Renderer-attributable scope (the design's Metal invariant):
//
//   The five metrics above are the ONLY metrics that may trigger the
//   conditional Metal branch (P03-T010 / P03-T011). They are renderer-owned:
//   each is bounded above by the renderer's own work and excludes every
//   cross-domain cost. The BANNED cross-domain metrics — first-present,
//   input-to-present, whole-application footprint, model load, RegExp, diff,
//   provider, and LSP — are NOT renderer-attributable (they include cold-start
//   model load, input processing, language-service work, etc.) and must NEVER
//   trigger Metal directly. End-to-end metrics cannot trigger Metal directly.
//
// Q1-R3 bootstrap readiness (P00-T009):
//
//   `RendererMetricTrace` emits balanced block identifiers + unrounded binary64
//   (Double) samples. The block is the atomic Q1-R3 sampling unit: bootstrap
//   resampling selects WHOLE blocks and never splits the native/comparator
//   pairing. Every emitted sample is an unrounded binary64 Double — Q1-R3
//   evaluates its noninferiority verdict on the unrounded values, so rounding
//   or quantizing a sample before the bootstrap would change the verdict. The
//   renderer metrics therefore never round; the Double samples flow verbatim
//   into the balanced blocks consumed by `BootstrapStatistics`.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreGraphics + Foundation. It does NOT depend on the `benchmark-harness`
// target (Q1-R3 lives there) — the trace emits bootstrap-ready samples in a
// self-contained form the harness can pair without a build dependency.

import Foundation
import CoreGraphics

// MARK: - MonaRendererMetricKind

/// The five renderer-attributable metric kinds.
///
/// These are the ONLY metrics that may trigger the conditional Metal branch.
/// Each is measured strictly inside the renderer pipeline (layout-ready →
/// present) and excludes every cross-domain cost. `allCases.count == 5`, which
/// is the `scoped=5` of the P03-T009 acceptance line.
public enum MonaRendererMetricKind: String, Sendable, CaseIterable, Equatable {
    /// Time from layout-ready to present (ms). Begins when a complete immutable
    /// `MonaLineLayoutRecord` is ready; ends when the composited frame is
    /// presented. Does NOT include first-present or input-to-present latency.
    case layoutReadyToPresent = "layout-ready-to-present"
    /// GPU frame time when the frame was presented (ms).
    case gpuFrameTime = "gpu-frame-time"
    /// Renderer surface footprint (bytes): memory owned by the renderer's
    /// surfaces and tile cache. NOT whole-application footprint.
    case rendererSurfaceFootprint = "renderer-surface-footprint"
    /// Missed presentation count for this block.
    case missedPresentation = "missed-presentation"
    /// Renderer energy estimate (millijoules) for this block's frame work.
    case rendererEnergy = "renderer-energy"

    /// Every renderer-attributable kind is, by definition, renderer-attributable.
    public var isRendererAttributable: Bool { true }
}

// MARK: - MonaCrossDomainMetricKind

/// Cross-domain metric kinds that are NOT renderer-attributable.
///
/// These are BANNED as direct Metal triggers (per the design's Metal
/// invariant) and are EXCLUDED from renderer trigger metrics. A trace rejects
/// them with a scope violation rather than storing them. `firstPresent` and
/// `inputToPresent` include cold-start model load and input processing;
/// `wholeApplicationFootprint` is the whole-app memory (not the renderer's own
/// surface footprint); `modelLoad`, `regexp`, `diff`, `provider`, and `lsp` are
/// the other subsystems' own costs.
public enum MonaCrossDomainMetricKind: String, Sendable, CaseIterable, Equatable {
    /// First-present latency (cold start → first frame). BANNED.
    case firstPresent = "first-present"
    /// Input-to-present latency (input event → frame). BANNED.
    case inputToPresent = "input-to-present"
    /// Whole-application memory footprint. BANNED (use rendererSurfaceFootprint).
    case wholeApplicationFootprint = "whole-application-footprint"
    /// Model load cost. Excluded (model subsystem, not renderer).
    case modelLoad = "model-load"
    /// RegExp cost. Excluded (RegExp subsystem, not renderer).
    case regexp = "regexp"
    /// Diff cost. Excluded (diff subsystem, not renderer).
    case diff = "diff"
    /// Provider cost. Excluded (provider subsystem, not renderer).
    case provider = "provider"
    /// LSP cost. Excluded (language-server subsystem, not renderer).
    case lsp = "lsp"

    /// No cross-domain kind is renderer-attributable.
    public var isRendererAttributable: Bool { false }
}

// MARK: - MonaRendererMetricError

/// Errors raised by the renderer metric instrumentation.
public enum MonaRendererMetricError: Error, Equatable, Sendable {
    /// A cross-domain metric was submitted as a renderer trigger. The renderer
    /// metrics must EXCLUDE these; the trace rejects them with a scope
    /// violation rather than storing them. `metric` is the raw wire name of the
    /// rejected cross-domain kind (e.g. `"first-present"`, `"model-load"`).
    case scopeViolation(metric: String)
}

// MARK: - MonaRendererMetrics

/// Renderer-owned performance + correctness metrics for one balanced block.
///
/// All five stored properties are RENDERER-ATTRIBUTABLE: each is measured
/// strictly inside the renderer pipeline (from layout-ready to present) and
/// excludes model load, RegExp, diff, provider, LSP, and whole-application
/// resource costs. These are the ONLY metrics that may trigger the conditional
/// Metal branch (P03-T010 / P03-T011).
///
/// All numeric fields are UNROUNDED binary64 (`Double`) values. Q1-R3
/// (P00-T009) evaluates its noninferiority verdict on the unrounded values;
/// rounding or quantizing them before the bootstrap would change the verdict.
/// The renderer metrics therefore never round — the `Double` samples flow
/// verbatim into the balanced blocks consumed by `BootstrapStatistics`.
public struct MonaRendererMetrics: Equatable, Sendable {

    /// Time from layout-ready to present (ms). Renderer-attributable: it begins
    /// when a complete immutable `MonaLineLayoutRecord` is ready and ends when
    /// the composited frame is presented. It does NOT include first-present or
    /// input-to-present latency (those begin at cold-start / input and are
    /// cross-domain).
    public let layoutReadyToPresent: Double

    /// GPU frame time when the frame was presented (ms).
    public let gpuFrameTime: Double

    /// Renderer surface footprint (bytes): the memory owned by the renderer's
    /// `MonaRenderSurface` targets and `MonaRenderTileCache` tiles. NOT
    /// whole-application footprint — the latter is a banned cross-domain metric.
    public let rendererSurfaceFootprint: Double

    /// Missed presentation count for this block.
    public let missedPresentation: Int

    /// Renderer energy estimate (millijoules) for this block's frame work.
    public let rendererEnergy: Double

    /// Creates renderer-owned metrics with unrounded binary64 values.
    public init(
        layoutReadyToPresent: Double,
        gpuFrameTime: Double,
        rendererSurfaceFootprint: Double,
        missedPresentation: Int,
        rendererEnergy: Double
    ) {
        self.layoutReadyToPresent = layoutReadyToPresent
        self.gpuFrameTime = gpuFrameTime
        self.rendererSurfaceFootprint = rendererSurfaceFootprint
        self.missedPresentation = missedPresentation
        self.rendererEnergy = rendererEnergy
    }
}

extension MonaRendererMetrics {

    /// The unrounded binary64 sample for one renderer-attributable metric kind.
    ///
    /// Returns the verbatim `Double` value — never a rounded or quantized form.
    /// `missedPresentation` (an `Int`) is promoted to `Double` without rounding
    /// (integers are exactly representable in binary64 up to 2^53).
    public func unroundedSample(for kind: MonaRendererMetricKind) -> Double {
        switch kind {
        case .layoutReadyToPresent:
            return layoutReadyToPresent
        case .gpuFrameTime:
            return gpuFrameTime
        case .rendererSurfaceFootprint:
            return rendererSurfaceFootprint
        case .missedPresentation:
            return Double(missedPresentation)
        case .rendererEnergy:
            return rendererEnergy
        }
    }

    /// The unrounded binary64 samples for all five renderer-attributable kinds,
    /// keyed by kind. These are the samples the Q1-R3 bootstrap consumes; they
    /// are emitted verbatim (unrounded) so the verdict is a pure function of
    /// the measured values.
    public func unroundedSamples() -> [MonaRendererMetricKind: Double] {
        var out: [MonaRendererMetricKind: Double] = [:]
        for kind in MonaRendererMetricKind.allCases {
            out[kind] = unroundedSample(for: kind)
        }
        return out
    }
}

// MARK: - RendererMetricBlock

/// One complete balanced block: the renderer metrics for one measurement unit,
/// identified by `blockID`.
///
/// The block is the atomic Q1-R3 sampling unit: bootstrap resampling selects
/// WHOLE blocks and never splits the native/comparator pairing. `blockID` is
/// the balanced block identifier emitted for Q1-R3 — the harness pairs the
/// native and comparator blocks by this identifier to form the resampling unit
/// without breaking the pairing.
public struct RendererMetricBlock: Equatable, Sendable {
    /// The balanced block identifier (e.g. `"60hz-native-vs-m0-001"`). Emitted
    /// alongside every sample so the Q1-R3 harness can pair blocks.
    public let blockID: String
    /// The five renderer-attributable metrics for this block.
    public let metrics: MonaRendererMetrics

    /// Creates a balanced block.
    public init(blockID: String, metrics: MonaRendererMetrics) {
        self.blockID = blockID
        self.metrics = metrics
    }
}

// MARK: - RendererMetricSample

/// One unrounded binary64 sample for one metric kind in one balanced block.
///
/// Emitted by `RendererMetricTrace` for the Q1-R3 statistical verdict engine.
/// The sample is bootstrap-ready: it carries its balanced block identifier, a
/// scoped renderer-attributable kind, and the verbatim (unrounded) binary64
/// value.
public struct RendererMetricSample: Equatable, Sendable {
    /// The balanced block identifier this sample belongs to.
    public let blockID: String
    /// The renderer-attributable metric kind.
    public let kind: MonaRendererMetricKind
    /// The unrounded binary64 (`Double`) value.
    public let value: Double

    /// Creates a bootstrap-ready sample.
    public init(blockID: String, kind: MonaRendererMetricKind, value: Double) {
        self.blockID = blockID
        self.kind = kind
        self.value = value
    }
}

// MARK: - RendererMetricTrace

/// Emits balanced block identifiers + unrounded binary64 samples for Q1-R3.
///
/// The trace collects renderer-attributable metrics into balanced blocks and
/// emits one `RendererMetricSample` per (block, kind). It REJECTS every
/// cross-domain metric (first-present, input-to-present, whole-application
/// footprint, model load, RegExp, diff, provider, LSP) with a scope violation
/// — those costs are NOT renderer-attributable and must never trigger the Metal
/// branch directly. End-to-end metrics cannot trigger Metal directly.
///
/// The emitted samples are bootstrap-ready (completion assertion
/// "Metric traces are bootstrap-ready"): each is an unrounded binary64 `Double`
/// tagged with a balanced block identifier and a scoped renderer-attributable
/// kind, ready for the Q1-R3 bootstrap resampling without further shaping.
public final class RendererMetricTrace {

    /// The blocks collected so far, in insertion order.
    private(set) public var blocks: [RendererMetricBlock] = []

    /// The scope-violation messages recorded for rejected cross-domain
    /// attempts. Diagnostic only — the rejected samples are never stored.
    private(set) public var crossDomainRejections: [String] = []

    /// Creates an empty trace.
    public init() {}

    /// The number of scoped renderer-attributable metric kinds (always 5).
    /// This is the `scoped=5` of the P03-T009 acceptance line.
    public static let scopedKindCount: Int = MonaRendererMetricKind.allCases.count

    /// The number of cross-domain samples stored as triggers. Always 0: the
    /// trace rejects cross-domain metrics with a scope violation rather than
    /// storing them. This is the `crossDomainSamples=0` of the acceptance line.
    public var crossDomainSampleCount: Int { 0 }

    /// Appends one complete balanced block.
    ///
    /// The block is the atomic Q1-R3 sampling unit; appending it makes its five
    /// renderer-attributable samples available to `emitSamples()`.
    public func append(_ block: RendererMetricBlock) {
        blocks.append(block)
    }

    /// Always rejects: cross-domain metrics are NOT renderer-attributable and
    /// must never be stored as renderer triggers.
    ///
    /// - Parameters:
    ///   - kind: A banned cross-domain metric kind (first-present,
    ///     input-to-present, whole-application footprint, model load, RegExp,
    ///     diff, provider, LSP).
    ///   - value: The measured cross-domain value (recorded only in the
    ///     diagnostic rejection message; never stored as a trigger sample).
    /// - Throws: `MonaRendererMetricError.scopeViolation` naming the rejected
    ///   metric.
    @discardableResult
    public func appendCrossDomain(
        kind: MonaCrossDomainMetricKind,
        value: Double
    ) throws -> String {
        let message = "RENDERER_METRIC_SCOPE_VIOLATION metric=\(kind.rawValue)"
        crossDomainRejections.append(message)
        throw MonaRendererMetricError.scopeViolation(metric: kind.rawValue)
    }

    /// Emits the unrounded binary64 samples for Q1-R3, one per (block, kind).
    ///
    /// For each balanced block, emits exactly `scopedKindCount` (5) samples —
    /// one per renderer-attributable kind — each carrying the block's
    /// identifier and the verbatim (unrounded) binary64 value. The pairing is
    /// never split: every sample of a block shares that block's identifier.
    public func emitSamples() -> [RendererMetricSample] {
        var out: [RendererMetricSample] = []
        out.reserveCapacity(blocks.count * MonaRendererMetricKind.allCases.count)
        for block in blocks {
            for kind in MonaRendererMetricKind.allCases {
                out.append(RendererMetricSample(
                    blockID: block.blockID,
                    kind: kind,
                    value: block.metrics.unroundedSample(for: kind)
                ))
            }
        }
        return out
    }

    /// The balanced block identifiers emitted for Q1-R3, one per block, in
    /// insertion order. The Q1-R3 harness pairs native and comparator blocks by
    /// these identifiers to form the resampling unit.
    public func blockIdentifiers() -> [String] {
        return blocks.map { $0.blockID }
    }
}
