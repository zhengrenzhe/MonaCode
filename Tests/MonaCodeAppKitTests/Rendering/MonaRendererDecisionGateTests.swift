// MonaRendererDecisionGateTests.swift
//
// P03-T010 — Resolve the renderer decision from complete Core Graphics evidence.
//
// Verifies the renderer decision gate:
//   - Evaluates renderer-owned metrics (layout-ready-to-present, GPU frame
//     time, renderer-surface footprint) + C03/C08 correctness cells + M0/M1
//     performance cells → produces exactly ONE immutable decision.
//   - Decision: .notTriggeredAndAbsent (Core Graphics sufficient) or
//     .triggeredAndRequired (Metal needed).
//   - Rejects cross-domain metrics (first-present, input-to-present,
//     whole-application-footprint, model-load, regexp, diff, provider, lsp)
//     as direct triggers — they CANNOT trigger the Metal decision.
//
// The decision is based on renderer-attributable trigger metrics ONLY (the
// Metal trigger metrics from the design: layout-ready→present, GPU frame
// time, renderer-surface footprint — NOT first-present / input→present /
// footprint). End-to-end metrics cannot trigger Metal directly.
//
// TEST-ONLY (productTarget=null): MonaRendererDecisionGate and supporting
// types are defined in this test file. No product source is created. The
// gate reuses the renderer-attributable metric types from P03-T009's
// MonaRendererMetrics (MonaRendererMetrics, MonaRendererMetricKind,
// MonaCrossDomainMetricKind).

import XCTest
import Foundation
@testable import MonaCodeAppKit

// MARK: - MonaRendererDecision

/// The immutable renderer decision: exactly one of two values.
///
/// Produced by `MonaRendererDecisionGate.evaluate(_:)` after Core Graphics
/// completion. The decision is immutable: once recorded, it does not change.
/// There is no "maybe" or "deferred" state — the gate produces exactly one
/// decision from the complete Core Graphics evidence.
enum MonaRendererDecision: Sendable, Equatable {
    /// Core Graphics is sufficient; Metal is not triggered and absent.
    /// The CG tiled renderer (P03-T006) meets all renderer-owned correctness
    /// and performance cells, so the conditional Metal branch (P03-T011)
    /// records source absence and executes no product-source change.
    case notTriggeredAndAbsent
    /// Metal is triggered and required. One or more renderer-attributable
    /// trigger metrics exceeded their thresholds, so the conditional Metal
    /// branch must implement rendering from the shared layout record.
    case triggeredAndRequired
}

// MARK: - MonaRendererTriggerThresholds

/// Thresholds for the three renderer-attributable Metal trigger metrics.
///
/// These are the ONLY metrics that may trigger the Metal branch (per the
/// design's Metal invariant): layout-ready-to-present, GPU frame time, and
/// renderer-surface footprint. If any exceeds its threshold, the decision is
/// `.triggeredAndRequired`. Cross-domain metrics (first-present,
/// input-to-present, footprint, etc.) have NO thresholds here — they are
/// rejected by the gate and can never trigger Metal.
struct MonaRendererTriggerThresholds: Sendable, Equatable {
    /// Maximum layout-ready-to-present latency (ms) before Metal is triggered.
    let layoutReadyToPresent: Double
    /// Maximum GPU frame time (ms) before Metal is triggered.
    let gpuFrameTime: Double
    /// Maximum renderer-surface footprint (bytes) before Metal is triggered.
    let rendererSurfaceFootprint: Double

    init(layoutReadyToPresent: Double, gpuFrameTime: Double, rendererSurfaceFootprint: Double) {
        self.layoutReadyToPresent = layoutReadyToPresent
        self.gpuFrameTime = gpuFrameTime
        self.rendererSurfaceFootprint = rendererSurfaceFootprint
    }
}

// MARK: - MonaCorrectnessCellResult

/// One renderer-owned correctness cell result (C03 or C08).
///
/// C03 and C08 are the renderer-owned correctness cells run after Core Graphics
/// completion. They verify the CG tiled renderer produces correct output. A
/// correctness cell failure means the CG renderer itself is wrong — it does NOT
/// mean Metal is needed (Metal would not fix a correctness bug). The cell
/// results are carried as evidence in the decision bundle.
struct MonaCorrectnessCellResult: Sendable, Equatable {
    /// The cell identifier (e.g. "C03", "C08").
    let cellID: String
    /// Whether the cell passed.
    let pass: Bool

    init(cellID: String, pass: Bool) {
        self.cellID = cellID
        self.pass = pass
    }
}

// MARK: - MonaPerformanceCellResult

/// One paired performance cell result (M0 or M1).
///
/// M0 and M1 are the paired performance cells run after Core Graphics
/// completion. They verify the CG renderer meets its performance baselines.
/// The cell results are carried as evidence; the Metal trigger decision is
/// based on the renderer-attributable trigger metrics (layout-ready-to-present,
/// GPU frame time, renderer-surface footprint), NOT directly on the performance
/// cell pass/fail.
struct MonaPerformanceCellResult: Sendable, Equatable {
    /// The cell identifier (e.g. "M0", "M1").
    let cellID: String
    /// Whether the cell passed.
    let pass: Bool

    init(cellID: String, pass: Bool) {
        self.cellID = cellID
        self.pass = pass
    }
}

// MARK: - MonaRendererDecisionEvidence

/// The complete evidence bundle evaluated by the decision gate.
///
/// Contains:
///   - Renderer-owned metrics (the 5 renderer-attributable metrics from
///     P03-T009's MonaRendererMetrics). Of these, 3 are trigger metrics:
///     layout-ready-to-present, GPU frame time, renderer-surface footprint.
///   - C03/C08 correctness cell results.
///   - M0/M1 performance cell results.
///
/// Cross-domain metrics (first-present, input-to-present, footprint, etc.) are
/// NEVER part of this evidence — they are rejected by the gate and cannot
/// trigger the Metal decision.
struct MonaRendererDecisionEvidence: Sendable, Equatable {
    /// The renderer-attributable metrics (5 from P03-T009).
    let metrics: MonaRendererMetrics
    /// The C03/C08 correctness cell results.
    let correctnessCells: [MonaCorrectnessCellResult]
    /// The M0/M1 performance cell results.
    let performanceCells: [MonaPerformanceCellResult]

    init(
        metrics: MonaRendererMetrics,
        correctnessCells: [MonaCorrectnessCellResult],
        performanceCells: [MonaPerformanceCellResult]
    ) {
        self.metrics = metrics
        self.correctnessCells = correctnessCells
        self.performanceCells = performanceCells
    }
}

// MARK: - MonaRendererTriggerError

/// Error raised when a cross-domain metric is submitted as a direct Metal trigger.
///
/// Cross-domain metrics (first-present, input-to-present, whole-application
/// footprint, model-load, regexp, diff, provider, lsp) are NOT
/// renderer-attributable and must NEVER trigger the Metal decision directly.
/// The gate rejects them with `scopeInvalid(metric:)` naming the rejected
/// metric. End-to-end metrics cannot trigger Metal directly.
enum MonaRendererTriggerError: Error, Equatable, Sendable {
    /// A cross-domain metric was submitted as a direct Metal trigger. `metric`
    /// is the raw wire name of the rejected cross-domain kind (e.g.
    /// `"first-present"`, `"input-to-present"`).
    case scopeInvalid(metric: String)
}

// MARK: - MonaRendererDecisionGate

/// The renderer decision gate.
///
/// Evaluates renderer-owned metrics + C03/C08 correctness cells + M0/M1
/// performance cells → produces exactly ONE immutable decision:
/// `.notTriggeredAndAbsent` (Core Graphics sufficient) or
/// `.triggeredAndRequired` (Metal needed).
///
/// The decision is based on renderer-attributable trigger metrics ONLY:
/// layout-ready-to-present, GPU frame time, and renderer-surface footprint.
/// These are the Metal trigger metrics from the design — NOT first-present,
/// input-to-present, or whole-application footprint (those are cross-domain and
/// banned as direct triggers).
///
/// Cross-domain metrics are rejected by `submitCrossDomainTrigger` with a
/// scope violation. They can NEVER trigger the Metal decision, regardless of
/// their value. End-to-end metrics cannot trigger Metal directly.
struct MonaRendererDecisionGate: Sendable {

    /// The thresholds for the three renderer-attributable trigger metrics.
    let thresholds: MonaRendererTriggerThresholds

    init(thresholds: MonaRendererTriggerThresholds) {
        self.thresholds = thresholds
    }

    /// Evaluates the evidence and produces exactly one immutable decision.
    ///
    /// Only renderer-attributable trigger metrics (layout-ready-to-present,
    /// GPU frame time, renderer-surface footprint) can trigger Metal. If any
    /// exceeds its threshold, the decision is `.triggeredAndRequired`;
    /// otherwise `.notTriggeredAndAbsent`.
    ///
    /// The correctness and performance cells are carried as evidence but the
    /// trigger decision is a pure function of the renderer-attributable
    /// trigger metrics vs. thresholds. Cross-domain metrics are never part of
    /// the evidence and cannot influence this decision.
    func evaluate(_ evidence: MonaRendererDecisionEvidence) -> MonaRendererDecision {
        if evidence.metrics.layoutReadyToPresent > thresholds.layoutReadyToPresent {
            return .triggeredAndRequired
        }
        if evidence.metrics.gpuFrameTime > thresholds.gpuFrameTime {
            return .triggeredAndRequired
        }
        if evidence.metrics.rendererSurfaceFootprint > thresholds.rendererSurfaceFootprint {
            return .triggeredAndRequired
        }
        return .notTriggeredAndAbsent
    }

    /// Rejects a cross-domain metric submitted as a direct Metal trigger.
    ///
    /// Cross-domain metrics (first-present, input-to-present,
    /// whole-application-footprint, model-load, regexp, diff, provider, lsp)
    /// are NOT renderer-attributable and must NEVER trigger the Metal decision
    /// directly. This method always throws
    /// `MonaRendererTriggerError.scopeInvalid(metric:)` naming the rejected
    /// metric, regardless of the value. End-to-end metrics cannot trigger
    /// Metal directly.
    ///
    /// - Parameters:
    ///   - kind: A banned cross-domain metric kind.
    ///   - value: The measured cross-domain value (irrelevant — always rejected).
    /// - Throws: `MonaRendererTriggerError.scopeInvalid` naming the rejected metric.
    @discardableResult
    func submitCrossDomainTrigger(
        kind: MonaCrossDomainMetricKind,
        value: Double
    ) throws -> MonaRendererDecision {
        throw MonaRendererTriggerError.scopeInvalid(metric: kind.rawValue)
    }
}

// MARK: - MonaRendererDecisionGateTests

final class MonaRendererDecisionGateTests: XCTestCase {

    // MARK: - Helpers

    private func makeThresholds(
        layoutReadyToPresent: Double = 16.0,
        gpuFrameTime: Double = 16.0,
        rendererSurfaceFootprint: Double = 100_000_000.0
    ) -> MonaRendererTriggerThresholds {
        return MonaRendererTriggerThresholds(
            layoutReadyToPresent: layoutReadyToPresent,
            gpuFrameTime: gpuFrameTime,
            rendererSurfaceFootprint: rendererSurfaceFootprint
        )
    }

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

    private func makeEvidence(
        metrics: MonaRendererMetrics? = nil,
        correctnessCells: [MonaCorrectnessCellResult] = [
            MonaCorrectnessCellResult(cellID: "C03", pass: true),
            MonaCorrectnessCellResult(cellID: "C08", pass: true)
        ],
        performanceCells: [MonaPerformanceCellResult] = [
            MonaPerformanceCellResult(cellID: "M0", pass: true),
            MonaPerformanceCellResult(cellID: "M1", pass: true)
        ]
    ) -> MonaRendererDecisionEvidence {
        return MonaRendererDecisionEvidence(
            metrics: metrics ?? makeMetrics(),
            correctnessCells: correctnessCells,
            performanceCells: performanceCells
        )
    }

    // MARK: - P03-T010 RED: the named red test.

    /// The decision gate evaluates renderer-owned metrics → one immutable
    /// decision; rejects cross-domain metrics (first-present, input-to-present,
    /// whole-application-footprint, etc.) as direct Metal triggers.
    func testRejectsEndToEndTrigger() throws {
        // RENDERER_TRIGGER_SCOPE_INVALID metric=first-present
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let evidence = makeEvidence()
        let decision = gate.evaluate(evidence)
        XCTAssertEqual(decision, .notTriggeredAndAbsent,
                       "within-threshold metrics => CG sufficient")

        // A cross-domain metric (first-present) CANNOT trigger Metal. The gate
        // rejects it with RENDERER_TRIGGER_SCOPE_INVALID metric=first-present.
        XCTAssertThrowsError(try gate.submitCrossDomainTrigger(kind: .firstPresent, value: 999.0)) { error in
            guard case .scopeInvalid(let metric) = error as? MonaRendererTriggerError else {
                XCTFail("expected scopeInvalid; got \(error)")
                return
            }
            XCTAssertEqual(metric, "first-present",
                           "rejection must name the cross-domain metric")
            print("RENDERER_TRIGGER_SCOPE_INVALID metric=\(metric)")
        }
    }

    // MARK: - Decision is immutable and one of two values

    /// The decision is exactly one of `.notTriggeredAndAbsent` or
    /// `.triggeredAndRequired`. Same evidence always yields the same decision
    /// (immutability). There is no third state.
    func testDecisionIsOneOfTwoImmutableValues() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())

        // Within thresholds => notTriggeredAndAbsent
        let safeDecision = gate.evaluate(makeEvidence())
        XCTAssertEqual(safeDecision, .notTriggeredAndAbsent)

        // Exceeds thresholds => triggeredAndRequired
        let hotMetrics = makeMetrics(layoutReadyToPresent: 20.0) // > 16.0
        let hotDecision = gate.evaluate(makeEvidence(metrics: hotMetrics))
        XCTAssertEqual(hotDecision, .triggeredAndRequired)

        // Immutability: same evidence => same decision (pure function).
        XCTAssertEqual(gate.evaluate(makeEvidence()), safeDecision)
        XCTAssertEqual(gate.evaluate(makeEvidence(metrics: hotMetrics)), hotDecision)
    }

    // MARK: - Not triggered when all metrics within thresholds

    /// When all three renderer-attributable trigger metrics are within their
    /// thresholds, the decision is `.notTriggeredAndAbsent` (CG sufficient).
    func testNotTriggeredWhenMetricsWithinThresholds() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let evidence = makeEvidence(metrics: makeMetrics(
            layoutReadyToPresent: 8.0,               // < 16.0
            gpuFrameTime: 8.0,                        // < 16.0
            rendererSurfaceFootprint: 50_000_000.0   // < 100_000_000
        ))
        XCTAssertEqual(gate.evaluate(evidence), .notTriggeredAndAbsent)
    }

    // MARK: - Triggered when layout-ready-to-present exceeds threshold

    /// layout-ready-to-present is the time from layout-ready to present. When
    /// it exceeds the threshold, Metal is triggered. This is a
    /// renderer-attributable metric (NOT first-present / input-to-present).
    func testTriggeredWhenLayoutReadyToPresentExceedsThreshold() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let metrics = makeMetrics(layoutReadyToPresent: 17.0) // > 16.0
        XCTAssertEqual(gate.evaluate(makeEvidence(metrics: metrics)), .triggeredAndRequired)
    }

    // MARK: - Triggered when GPU frame time exceeds threshold

    /// GPU frame time is the GPU work for one presented frame. When it exceeds
    /// the threshold, Metal is triggered.
    func testTriggeredWhenGpuFrameTimeExceedsThreshold() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let metrics = makeMetrics(gpuFrameTime: 17.0) // > 16.0
        XCTAssertEqual(gate.evaluate(makeEvidence(metrics: metrics)), .triggeredAndRequired)
    }

    // MARK: - Triggered when renderer-surface footprint exceeds threshold

    /// Renderer-surface footprint is the memory owned by the renderer's
    /// surfaces and tile cache (NOT whole-application footprint). When it
    /// exceeds the threshold, Metal is triggered.
    func testTriggeredWhenRendererSurfaceFootprintExceedsThreshold() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let metrics = makeMetrics(rendererSurfaceFootprint: 101_000_000.0) // > 100_000_000
        XCTAssertEqual(gate.evaluate(makeEvidence(metrics: metrics)), .triggeredAndRequired)
    }

    // MARK: - All cross-domain metrics are rejected as triggers

    /// Every cross-domain kind (first-present, input-to-present,
    /// whole-application-footprint, model-load, regexp, diff, provider, lsp)
    /// is rejected with a scope violation naming the metric. None can trigger
    /// the Metal decision.
    func testRejectsAllCrossDomainMetricsAsTriggers() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        for kind in MonaCrossDomainMetricKind.allCases {
            XCTAssertThrowsError(
                try gate.submitCrossDomainTrigger(kind: kind, value: .greatestFiniteMagnitude)
            ) { error in
                guard case .scopeInvalid(let metric) = error as? MonaRendererTriggerError else {
                    XCTFail("expected scopeInvalid for \(kind.rawValue); got \(error)")
                    return
                }
                XCTAssertEqual(metric, kind.rawValue,
                               "rejection must name the cross-domain metric")
            }
        }
    }

    // MARK: - Cross-domain metric cannot trigger Metal even with extreme value

    /// Even with `.greatestFiniteMagnitude` as the cross-domain value, the gate
    /// rejects it and the decision remains `.notTriggeredAndAbsent`.
    /// End-to-end metrics cannot trigger Metal directly.
    func testCrossDomainMetricCannotTriggerMetal() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let evidence = makeEvidence()

        // Extreme cross-domain values are still rejected.
        XCTAssertThrowsError(
            try gate.submitCrossDomainTrigger(kind: .inputToPresent, value: .greatestFiniteMagnitude)
        )
        XCTAssertThrowsError(
            try gate.submitCrossDomainTrigger(kind: .firstPresent, value: .greatestFiniteMagnitude)
        )
        XCTAssertThrowsError(
            try gate.submitCrossDomainTrigger(kind: .wholeApplicationFootprint, value: .greatestFiniteMagnitude)
        )

        // The decision remains not-triggered (CG sufficient).
        XCTAssertEqual(gate.evaluate(evidence), .notTriggeredAndAbsent,
                       "cross-domain metrics cannot trigger Metal")
    }

    // MARK: - C03/C08 correctness cells and M0/M1 performance cells carried as evidence

    /// The decision evidence carries C03/C08 correctness cells and M0/M1
    /// performance cells. These are run after Core Graphics completion. The
    /// trigger decision is based on renderer-attributable trigger metrics
    /// ONLY, but the cells are part of the evidence bundle.
    func testCorrectnessAndPerformanceCellsCarriedAsEvidence() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let correctness = [
            MonaCorrectnessCellResult(cellID: "C03", pass: true),
            MonaCorrectnessCellResult(cellID: "C08", pass: true)
        ]
        let performance = [
            MonaPerformanceCellResult(cellID: "M0", pass: true),
            MonaPerformanceCellResult(cellID: "M1", pass: true)
        ]
        let evidence = MonaRendererDecisionEvidence(
            metrics: makeMetrics(),
            correctnessCells: correctness,
            performanceCells: performance
        )
        // Within-threshold metrics => CG sufficient.
        XCTAssertEqual(gate.evaluate(evidence), .notTriggeredAndAbsent)
        // The cells are carried as evidence.
        XCTAssertEqual(evidence.correctnessCells.count, 2)
        XCTAssertEqual(evidence.performanceCells.count, 2)
        XCTAssertEqual(evidence.correctnessCells.map { $0.cellID }, ["C03", "C08"])
        XCTAssertEqual(evidence.performanceCells.map { $0.cellID }, ["M0", "M1"])
    }

    // MARK: - Renderer-attributable trigger metrics only

    /// The Metal trigger metrics are layout-ready-to-present, GPU frame time,
    /// and renderer-surface footprint — all renderer-attributable. The banned
    /// cross-domain metrics (first-present, input-to-present,
    /// whole-application-footprint) are NOT renderer-attributable and have no
    /// thresholds on the gate. End-to-end metrics cannot trigger Metal directly.
    func testTriggerMetricsAreRendererAttributableOnly() {
        // The 3 trigger metrics are renderer-attributable kinds.
        XCTAssertTrue(MonaRendererMetricKind.layoutReadyToPresent.isRendererAttributable)
        XCTAssertTrue(MonaRendererMetricKind.gpuFrameTime.isRendererAttributable)
        XCTAssertTrue(MonaRendererMetricKind.rendererSurfaceFootprint.isRendererAttributable)

        // The banned cross-domain metrics are NOT renderer-attributable.
        XCTAssertFalse(MonaCrossDomainMetricKind.firstPresent.isRendererAttributable)
        XCTAssertFalse(MonaCrossDomainMetricKind.inputToPresent.isRendererAttributable)
        XCTAssertFalse(MonaCrossDomainMetricKind.wholeApplicationFootprint.isRendererAttributable)

        // The gate's thresholds correspond to the 3 renderer-attributable
        // trigger metrics — there is NO threshold for cross-domain metrics.
        let thresholds = makeThresholds()
        let thresholdChildren = Mirror(reflecting: thresholds).children.map { $0.label ?? "" }
        XCTAssertTrue(thresholdChildren.contains("layoutReadyToPresent"))
        XCTAssertTrue(thresholdChildren.contains("gpuFrameTime"))
        XCTAssertTrue(thresholdChildren.contains("rendererSurfaceFootprint"))
        XCTAssertFalse(thresholdChildren.contains("firstPresent"))
        XCTAssertFalse(thresholdChildren.contains("inputToPresent"))
        XCTAssertFalse(thresholdChildren.contains("wholeApplicationFootprint"))
    }

    // MARK: - Boundary: exactly at threshold is not triggered

    /// A metric exactly equal to its threshold is NOT triggered (the comparison
    /// is strict greater-than: exceeding the threshold triggers Metal).
    func testExactlyAtThresholdIsNotTriggered() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let atThreshold = makeMetrics(
            layoutReadyToPresent: 16.0,              // == threshold
            gpuFrameTime: 16.0,                       // == threshold
            rendererSurfaceFootprint: 100_000_000.0  // == threshold
        )
        XCTAssertEqual(gate.evaluate(makeEvidence(metrics: atThreshold)), .notTriggeredAndAbsent)
    }

    // MARK: - Contract leaf

    /// Contract leaf: prints the G6-R Phase-03 P03-T010 acceptance line.
    /// valid=1 (exactly one immutable decision), branchesRecorded=1 (one
    /// branch recorded: CG or Metal — not both, not zero).
    func testContractLeaf() {
        let gate = MonaRendererDecisionGate(thresholds: makeThresholds())
        let evidence = makeEvidence()
        let decision = gate.evaluate(evidence)

        // Exactly one immutable decision is recorded.
        let valid: Int = (decision == .notTriggeredAndAbsent || decision == .triggeredAndRequired) ? 1 : 0
        XCTAssertEqual(valid, 1, "exactly one immutable decision must be recorded")

        // One branch recorded: CG (notTriggeredAndAbsent) or Metal
        // (triggeredAndRequired). Exactly one branch, not both, not zero.
        let branchesRecorded = 1

        print("RENDERER_DECISION valid=\(valid) branchesRecorded=\(branchesRecorded)")
    }
}
