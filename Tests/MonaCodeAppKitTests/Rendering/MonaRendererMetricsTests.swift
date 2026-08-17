// MonaRendererMetricsTests.swift
//
// P03-T009 — Instrument renderer-owned correctness and performance metrics.
//
// Verifies the renderer-owned metric instrumentation:
//   - MonaRendererMetrics          — the 5 renderer-attributable metrics
//                                    (layout-ready-to-present, GPU frame time,
//                                    renderer-surface footprint, missed
//                                    presentation, renderer energy). Each is
//                                    measured strictly inside the renderer
//                                    pipeline and excludes every cross-domain
//                                    cost (model load, RegExp, diff, provider,
//                                    LSP, whole-application resource costs).
//   - MonaRendererMetricKind       — the 5 scoped renderer-attributable kinds.
//   - MonaCrossDomainMetricKind    — the 8 BANNED cross-domain kinds that are
//                                    NOT renderer-attributable and must never
//                                    trigger the Metal branch directly.
//   - RendererMetricTrace          — emits balanced block identifiers +
//                                    unrounded binary64 samples for the Q1-R3
//                                    statistical verdict engine (P00-T009).
//
// The renderer metrics are RENDERER-ATTRIBUTABLE: layoutReadyToPresent,
// gpuFrameTime, rendererSurfaceFootprint. The BANNED metrics (per the design's
// Metal invariant) are: firstPresent, inputToPresent, footprint — these are NOT
// renderer-attributable (they include model load, input processing, etc.) and
// the renderer metrics must EXCLUDE these.
//
// One contract case: renderer metrics are scoped (5), cross-domain samples are
// excluded (0), and the trace emits balanced block IDs + unrounded binary64.

import XCTest
import Foundation
@testable import MonaCodeAppKit

final class MonaRendererMetricsTests: XCTestCase {

    // MARK: - Helpers

    private func makeMetrics(
        layoutReadyToPresent: Double = 4.5,
        gpuFrameTime: Double = 3.25,
        rendererSurfaceFootprint: Double = 1_048_576.0,
        missedPresentation: Int = 0,
        rendererEnergy: Double = 12.5
    ) -> MonaRendererMetrics {
        return MonaRendererMetrics(
            layoutReadyToPresent: layoutReadyToPresent,
            gpuFrameTime: gpuFrameTime,
            rendererSurfaceFootprint: rendererSurfaceFootprint,
            missedPresentation: missedPresentation,
            rendererEnergy: rendererEnergy
        )
    }

    // MARK: - P03-T009 RED: the named red test.

    /// The renderer metrics must EXCLUDE model load, RegExp, diff, provider,
    /// LSP, whole-application footprint, first-present, and input-to-present.
    /// A trace rejects every cross-domain kind with a scope violation and stores
    /// none of them; only the 5 renderer-attributable kinds are accepted.
    func testExcludesModelAndProviderTime() throws {
        let trace = RendererMetricTrace()

        // The 5 renderer-attributable kinds are accepted and stored.
        XCTAssertEqual(MonaRendererMetricKind.allCases.count, 5, "scoped kind count must be 5")
        XCTAssertEqual(RendererMetricTrace.scopedKindCount, 5, "scopedKindCount must be 5")

        // Each cross-domain kind is REJECTED with a scope violation and never
        // stored. The renderer metrics must exclude these.
        let crossDomainKinds = MonaCrossDomainMetricKind.allCases
        XCTAssertEqual(crossDomainKinds.count, 8, "expected 8 cross-domain (banned) kinds")
        for kind in crossDomainKinds {
            XCTAssertThrowsError(try trace.appendCrossDomain(kind: kind, value: 1.0)) { error in
                guard case .scopeViolation(let metric) = error as? MonaRendererMetricError else {
                    XCTFail("expected scopeViolation for \(kind.rawValue); got \(error)")
                    return
                }
                XCTAssertEqual(metric, kind.rawValue, "violation must name the rejected cross-domain metric")
            }
        }

        // No cross-domain sample was stored.
        XCTAssertEqual(trace.crossDomainSampleCount, 0, "cross-domain samples must never be stored")
    }

    // MARK: - Banned fields absent

    /// The banned metrics (firstPresent, inputToPresent, footprint) are NOT
    /// fields on MonaRendererMetrics. They include model load, input
    /// processing, etc., so they are NOT renderer-attributable.
    func testBannedMetricsNotPresentOnRendererMetrics() {
        let metrics = makeMetrics()
        let children = Mirror(reflecting: metrics).children.map { $0.label ?? "" }

        // The 5 renderer-attributable fields are present.
        XCTAssertTrue(children.contains("layoutReadyToPresent"), "layoutReadyToPresent must be present")
        XCTAssertTrue(children.contains("gpuFrameTime"), "gpuFrameTime must be present")
        XCTAssertTrue(children.contains("rendererSurfaceFootprint"), "rendererSurfaceFootprint must be present")
        XCTAssertTrue(children.contains("missedPresentation"), "missedPresentation must be present")
        XCTAssertTrue(children.contains("rendererEnergy"), "rendererEnergy must be present")

        // The banned cross-domain fields are ABSENT.
        XCTAssertFalse(children.contains("firstPresent"), "firstPresent is banned (not renderer-attributable)")
        XCTAssertFalse(children.contains("inputToPresent"), "inputToPresent is banned (not renderer-attributable)")
        XCTAssertFalse(children.contains("footprint"), "whole-application footprint is banned (not renderer-attributable)")
        XCTAssertFalse(children.contains("modelLoad"), "model load is excluded (not renderer-attributable)")
        XCTAssertFalse(children.contains("regexp"), "RegExp is excluded (not renderer-attributable)")
        XCTAssertFalse(children.contains("diff"), "diff is excluded (not renderer-attributable)")
        XCTAssertFalse(children.contains("provider"), "provider is excluded (not renderer-attributable)")
        XCTAssertFalse(children.contains("lsp"), "LSP is excluded (not renderer-attributable)")
    }

    // MARK: - Unrounded binary64 samples

    /// The 5 metric samples are unrounded binary64 (Double) values. They flow
    /// verbatim into the Q1-R3 bootstrap — rounding or quantizing them before
    /// the bootstrap would change the verdict. Sub-ULP fractional values and
    /// irrational values are preserved exactly.
    func testUnroundedBinary64Samples() {
        // Values with sub-ULP fractional parts and irrational-derived values
        // that would be destroyed by any rounding/quantization.
        let layoutReady = 4.500000000000001 // one ULP above 4.5
        let gpu = 3.141592653589793        // full binary64 precision (π)
        let footprint = 1_048_576.0000000001
        let missed = 2
        let energy = 12.500000000000002
        let metrics = MonaRendererMetrics(
            layoutReadyToPresent: layoutReady,
            gpuFrameTime: gpu,
            rendererSurfaceFootprint: footprint,
            missedPresentation: missed,
            rendererEnergy: energy
        )

        // layoutReadyToPresent is preserved bit-for-bit (unrounded binary64):
        // it is exactly one ULP above 4.5 (== 4.5.nextUp), not rounded down to 4.5.
        XCTAssertEqual(metrics.layoutReadyToPresent, layoutReady)
        XCTAssertEqual(metrics.layoutReadyToPresent, 4.5.nextUp, "must be exactly one ULP above 4.5, preserved bit-for-bit")
        XCTAssertNotEqual(metrics.layoutReadyToPresent, 4.5, "must not be rounded down to 4.5")

        // gpuFrameTime preserves full binary64 precision.
        XCTAssertEqual(metrics.gpuFrameTime, gpu)
        XCTAssertEqual(metrics.gpuFrameTime, .pi)

        // rendererSurfaceFootprint is preserved bit-for-bit.
        XCTAssertEqual(metrics.rendererSurfaceFootprint, footprint)

        // rendererEnergy is preserved bit-for-bit.
        XCTAssertEqual(metrics.rendererEnergy, energy)

        // The unrounded-sample accessor returns the verbatim binary64 value for
        // each kind — never a rounded/quantized form.
        XCTAssertEqual(metrics.unroundedSample(for: .layoutReadyToPresent), layoutReady)
        XCTAssertEqual(metrics.unroundedSample(for: .gpuFrameTime), gpu)
        XCTAssertEqual(metrics.unroundedSample(for: .rendererSurfaceFootprint), footprint)
        XCTAssertEqual(metrics.unroundedSample(for: .missedPresentation), Double(missed))
        XCTAssertEqual(metrics.unroundedSample(for: .rendererEnergy), energy)

        // The keyed samples cover exactly the 5 scoped kinds.
        let samples = metrics.unroundedSamples()
        XCTAssertEqual(samples.count, 5)
        for kind in MonaRendererMetricKind.allCases {
            XCTAssertNotNil(samples[kind], "sample for \(kind.rawValue) must be present")
        }
    }

    // MARK: - Balanced block identifiers

    /// The trace emits balanced block identifiers — one per complete balanced
    /// block. The block is the atomic Q1-R3 sampling unit: bootstrap
    /// resampling selects WHOLE blocks and never splits a block. Each emitted
    /// sample carries its block identifier so the Q1-R3 harness can pair the
    /// native/comparator samples without breaking the pairing.
    func testEmitBalancedBlockIdentifiers() throws {
        let trace = RendererMetricTrace()

        let blockA = RendererMetricBlock(blockID: "block-60hz-001", metrics: makeMetrics(layoutReadyToPresent: 4.0))
        let blockB = RendererMetricBlock(blockID: "block-60hz-002", metrics: makeMetrics(layoutReadyToPresent: 5.0))
        let blockC = RendererMetricBlock(blockID: "block-120hz-001", metrics: makeMetrics(layoutReadyToPresent: 3.5))

        trace.append(blockA)
        trace.append(blockB)
        trace.append(blockC)

        // The balanced block identifiers are emitted verbatim, one per block.
        let ids = trace.blockIdentifiers()
        XCTAssertEqual(ids, ["block-60hz-001", "block-60hz-002", "block-120hz-001"])

        // Each emitted sample carries its block identifier; the pairing is never
        // split. 3 blocks × 5 kinds = 15 samples, each tagged with its blockID.
        let samples = trace.emitSamples()
        XCTAssertEqual(samples.count, 15)

        let samplesByBlock = Dictionary(grouping: samples, by: { $0.blockID })
        XCTAssertEqual(samplesByBlock.count, 3, "each block's samples must carry its blockID")
        for id in ids {
            XCTAssertEqual(samplesByBlock[id]?.count, 5, "block \(id) must emit exactly 5 samples (one per kind)")
        }

        // Within one block, every kind is present exactly once.
        let blockASamples = samplesByBlock["block-60hz-001"]!
        let blockAKinds = Set(blockASamples.map { $0.kind })
        XCTAssertEqual(blockAKinds.count, 5)
        XCTAssertEqual(blockASamples.map { $0.value }, MonaRendererMetricKind.allCases.map { blockA.metrics.unroundedSample(for: $0) })
    }

    // MARK: - Renderer-attributable scope

    /// Every renderer metric kind is renderer-attributable; every cross-domain
    /// kind is NOT. The banned first-present / input-to-present / footprint are
    /// cross-domain (they include model load, input processing, etc.).
    func testRendererAttributableScope() {
        for kind in MonaRendererMetricKind.allCases {
            XCTAssertTrue(kind.isRendererAttributable, "\(kind.rawValue) must be renderer-attributable")
            XCTAssertFalse(MonaCrossDomainMetricKind(rawValue: kind.rawValue) != nil,
                           "\(kind.rawValue) must not appear in the cross-domain set")
        }
        for kind in MonaCrossDomainMetricKind.allCases {
            XCTAssertFalse(kind.isRendererAttributable, "\(kind.rawValue) must NOT be renderer-attributable")
            XCTAssertNil(MonaRendererMetricKind(rawValue: kind.rawValue),
                         "\(kind.rawValue) must not appear in the renderer-attributable set")
        }
    }

    // MARK: - Layout-ready-to-present is renderer-attributable, not first-present

    /// layoutReadyToPresent begins when a complete immutable layout record is
    /// READY and ends at PRESENT. It does NOT include first-present or
    /// input-to-present latency (those begin at input / cold-start and are
    /// cross-domain). The metric is therefore bounded above by the renderer's
    /// own work, never the whole input-to-present chain.
    func testLayoutReadyToPresentIsRendererAttributable() {
        let metrics = makeMetrics(layoutReadyToPresent: 4.5)
        // The metric is the renderer's own work (layout-ready → present), which
        // is strictly less than any input-to-present or first-present latency
        // that would include model load / input processing.
        XCTAssertGreaterThan(metrics.layoutReadyToPresent, 0)
        // The renderer-attributable metric kind's wire name is the frozen
        // "layout-ready-to-present" (not "first-present" / "input-to-present").
        XCTAssertEqual(MonaRendererMetricKind.layoutReadyToPresent.rawValue, "layout-ready-to-present")
        XCTAssertNotEqual(MonaRendererMetricKind.layoutReadyToPresent.rawValue,
                           MonaCrossDomainMetricKind.firstPresent.rawValue)
        XCTAssertNotEqual(MonaRendererMetricKind.layoutReadyToPresent.rawValue,
                           MonaCrossDomainMetricKind.inputToPresent.rawValue)
    }

    // MARK: - Bootstrap-ready trace

    /// Metric traces are bootstrap-ready: every emitted sample is an unrounded
    /// binary64 Double tagged with a balanced block identifier and a scoped
    /// renderer-attributable kind, ready for the Q1-R3 bootstrap resampling.
    func testTraceIsBootstrapReady() {
        let trace = RendererMetricTrace()
        let block = RendererMetricBlock(blockID: "blk-1", metrics: makeMetrics())
        trace.append(block)

        let samples = trace.emitSamples()
        XCTAssertEqual(samples.count, 5)
        for sample in samples {
            XCTAssertFalse(sample.blockID.isEmpty, "blockID must be non-empty")
            XCTAssertTrue(sample.kind.isRendererAttributable, "emitted kind must be renderer-attributable")
            // The value is an unrounded binary64 Double (verbatim).
            XCTAssertEqual(sample.value, block.metrics.unroundedSample(for: sample.kind))
        }
    }

    // MARK: - Contract leaf

    /// Contract leaf: prints the G6-R Phase-03 P03-T009 acceptance line.
    /// scoped=5 (the 5 renderer-attributable metrics), crossDomainSamples=0
    /// (no cross-domain metric is stored as a trigger).
    func testContractLeaf() {
        let trace = RendererMetricTrace()
        trace.append(RendererMetricBlock(blockID: "contract-leaf", metrics: makeMetrics()))

        let scoped = RendererMetricTrace.scopedKindCount
        let crossDomain = trace.crossDomainSampleCount
        let bootstrapReady = trace.emitSamples().allSatisfy { $0.kind.isRendererAttributable }

        XCTAssertEqual(scoped, 5, "scoped renderer-attributable metric count must be 5")
        XCTAssertEqual(crossDomain, 0, "no cross-domain sample may be stored")
        XCTAssertTrue(bootstrapReady, "every emitted sample must be renderer-attributable")

        print("RENDERER_METRICS scoped=\(scoped) crossDomainSamples=\(crossDomain)")
    }
}
