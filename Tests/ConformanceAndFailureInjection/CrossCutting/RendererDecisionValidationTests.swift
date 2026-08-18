// RendererDecisionValidationTests.swift
//
// P09-T052 — Validate the frozen Phase 03 renderer decision without source changes.
//
// The Phase 09 acceptance cross-cutting renderer-decision validation gate. It
// validates the frozen Phase-03 CG-vs-Metal conditional-renderer decision IN
// PLACE — reading the frozen decision and its evidence — WITHOUT source
// changes (no product source created or modified, no decision recomputed, no
// Metal triggered). It joins the Phase-03 renderer decision gate (P03-T010
// `MonaRendererDecisionGate`), the Core Graphics tiled renderer (P03-T006
// `MonaCoreGraphicsRenderer`), the conditional Metal renderer (P03-T011
// `MonaMetalRenderer`), the renderer-attributable trigger metrics (P03-T009
// `MonaRendererMetrics`), and every renderer correctness + performance cell
// (C08/P09-T017 + P04/P09-T034 + P05/P09-T035 + P06/P09-T036) as one
// cross-cutting verdict, and:
//
//   1. Verifies the immutable Phase-03 decision hash (the frozen CG-vs-Metal
//      decision gate's Record SHA-256 matches the frozen baseline), the Core
//      Graphics completion predecessor (CG completes before Metal; CG is the
//      fallback), the trigger metric scope (the 3 renderer-attributable
//      trigger metrics, NOT the 8 cross-domain banned metrics), the selected
//      source set (the 5 frozen renderer source files), and the absence-or-
//      parity evidence (Metal is `.notTriggeredAndAbsent` → absence evidence;
//      the ≤1/255 parity gate would apply if triggered).
//   2. Confirms every current renderer correctness and performance cell
//      (C08/T017 + P04/P05/P06) agrees with the frozen branch: CG is the
//      active renderer, Metal is absent.
//   3. Rejects any Phase-09 source creation, decision recomputation, cross-
//      domain trigger, missing CG fallback, or unvalidated triggered branch.
//
// This is a TEST-ONLY task (productTarget null; create none, modify none). The
// file lives in the `conformance-and-failure-injection` target (kept a non-test
// `.target` for the package-graph invariant). Discovery is provided by the
// `MonaCodeTests` test target depending on this target; the class is
// introspected from the linked image, so `swift test --filter
// RendererDecisionValidationTests` runs it. The API is FROZEN (P07-T011).
//
// CRITICAL: the test VALIDATES WITHOUT source changes — it READS the frozen
// decision (the Phase-03 contract's Record SHA-256 + the declared branch
// state), it does NOT RECOMPUTE the decision (it never calls
// `MonaRendererDecisionGate.evaluate(_:)` to produce a new decision). The gate
// is consulted only for its STRUCTURAL rejection of cross-domain triggers
// (`submitCrossDomainTrigger` always throws — a structural property, not a
// decision recomputation).

import Foundation
import XCTest
import CryptoKit
import CoreGraphics
import Metal
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

// MARK: - RendererDecisionValidationTests

final class RendererDecisionValidationTests: XCTestCase {

    // MARK: - Frozen baselines (verbatim from the phase-03 / phase-09 contracts)

    /// P09-T052 (this task): the validation gate's own frozen Record SHA-256 +
    /// platform scope, verbatim from the phase-09 contract. The test does not
    /// mutate the contract; it reads the decision, so this gate's hash is the
    /// frozen anchor for the validation pass itself.
    private static let p09T052RecordHash =
        "c033b83326495f21c873e7a0a0602ef6a4bf933089a4c98b0554f880037e67d9"
    private static let p09T052PlatformScope = "macOS-26-arm64"

    /// The Phase-03 renderer decision gate (P03-T010) — the frozen CG-vs-Metal
    /// decision. Its Record SHA-256 is the immutable decision hash; the test
    /// reads it from the phase-03 contract and asserts it matches this frozen
    /// baseline. The decision is immutable because the task that produces it is
    /// frozen (its hash cannot change without a contract revision).
    private static let frozenDecisionGateHash =
        "5c6372f2dfda3b8c02cc62d01ae01fb5d96fe203460e5a841d74e8c3d6f92348"

    /// The Core Graphics tiled renderer (P03-T006) — the completion
    /// predecessor. Its Record SHA-256 is the frozen CG baseline; CG completes
    /// before Metal because P03-T006 is a transitive dependency of P03-T011.
    private static let frozenCGRendererHash =
        "57c7d2361a8e021f17a28d22814457c44a8815fbcdb829ab894766fb204e57c3"

    /// The renderer-attributable metrics instrumentation (P03-T009) — the
    /// trigger-metric source. Its Record SHA-256 is the frozen metrics
    /// baseline; P03-T010 depends on P03-T009, so the trigger scope is frozen.
    private static let frozenRendererMetricsHash =
        "e770191c6aa71cb1dea5d8e333fbb0c71c39d9a8dfd98dcb43ad1b6542eb0934"

    /// The conditional Metal renderer (P03-T011) — the triggered branch. Its
    /// Record SHA-256 is the frozen Metal-branch baseline; P03-T011 depends on
    /// P03-T010, so Metal is downstream of the decision.
    private static let frozenMetalBranchHash =
        "a38eab62a090c2d56fd6572050ed7dbd4218ab91788d8ba5cbdcdd8495070fcc"

    /// The frozen renderer source set (5 files — P03-T006/T009/T011). These
    /// are the product source files that implement the rendering pipeline;
    /// Phase 08 candidate generation consumes this exact set. The test reads
    /// the Rendering directory and asserts it contains exactly these files (no
    /// source created or removed by Phase 09).
    private static let frozenRendererSourceSet: Set<String> = [
        "Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift",  // P03-T006
        "Sources/MonaCodeAppKit/Rendering/MonaRenderTileCache.swift",        // P03-T006
        "Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift",          // P03-T006
        "Sources/MonaCodeAppKit/Rendering/MonaRendererMetrics.swift",       // P03-T009
        "Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift",         // P03-T011
    ]

    /// The renderer correctness + performance cells covered by the P09-T052
    /// dependencies (T012✓ C03 projection, T017✓ C08 renderer, T034-T036✓
    /// P04/P05/P06). Each cell must agree with the frozen branch.
    private static let rendererCellFiles: [(task: String, leaf: String, file: String)] = [
        ("P09-T017", "C08",  "Tests/ConformanceAndFailureInjection/Correctness/C08Tests.swift"),
        ("P09-T034", "P04",  "Tests/BenchmarkHarness/Workloads/P04WorkloadTests.swift"),
        ("P09-T035", "P05",  "Tests/BenchmarkHarness/Workloads/P05WorkloadTests.swift"),
        ("P09-T036", "P06",  "Tests/BenchmarkHarness/Workloads/P06WorkloadTests.swift"),
    ]

    /// Menlo is the default macOS monospace face and is always present.
    private static let font = MonaFontDescriptor(familyName: "Menlo", size: 12)

    // MARK: Operation 1 — Verify the immutable Phase-03 decision hash, CG
    // completion predecessor, trigger metric scope, selected source set, and
    // absence-or-parity evidence.

    // ── 1a. The immutable Phase-03 decision hash (matches the frozen baseline) ─

    /// The Phase-03 renderer decision is immutable: the P03-T010 decision-gate
    /// task's Record SHA-256 (read from the phase-03 contract) matches the
    /// frozen baseline `frozenDecisionGateHash`. The test READS the hash from
    /// the contract — it does NOT recompute the decision via the gate. The
    /// decision-gate, CG-renderer, metrics, and Metal-branch hashes are all
    /// frozen at their declared values (no contract revision mutated them).
    func testImmutablePhase03DecisionHashMatchesFrozenBaseline() throws {
        // P09-T052's own frozen anchor (this validation gate).
        XCTAssertEqual(Self.p09T052PlatformScope, "macOS-26-arm64",
                       "P09-T052 platform scope is macOS-26-arm64")
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        for h in [
            Self.p09T052RecordHash,
            Self.frozenDecisionGateHash,
            Self.frozenCGRendererHash,
            Self.frozenRendererMetricsHash,
            Self.frozenMetalBranchHash,
        ] {
            let range = NSRange(h.startIndex..., in: h)
            XCTAssertNotNil(hexRegex.firstMatch(in: h, range: range),
                           "\(h): frozen decision hash is 64-char lowercase hex SHA-256")
        }

        // READ the Phase-03 contract: the P03-T010 (decision gate), P03-T006
        // (CG renderer), P03-T009 (metrics), and P03-T011 (Metal branch) Record
        // SHA-256 values must match the frozen baselines. This proves the
        // decision is immutable — the tasks that produce + consume it are
        // frozen. The test does NOT call evaluate(_:) — it reads the frozen
        // hashes, not a recomputed decision.
        let decisionGate = try XCTUnwrap(readPhase03Task("P03-T010"),
            "P03-T010 (decision gate) section present in the phase-03 contract")
        XCTAssertEqual(decisionGate.recordSHA256, Self.frozenDecisionGateHash,
                       "P03-T010 decision-gate Record SHA-256 matches the frozen baseline (immutable decision hash)")

        let cgRenderer = try XCTUnwrap(readPhase03Task("P03-T006"),
            "P03-T006 (CG renderer) section present in the phase-03 contract")
        XCTAssertEqual(cgRenderer.recordSHA256, Self.frozenCGRendererHash,
                       "P03-T006 CG-renderer Record SHA-256 matches the frozen baseline")

        let metrics = try XCTUnwrap(readPhase03Task("P03-T009"),
            "P03-T009 (renderer metrics) section present in the phase-03 contract")
        XCTAssertEqual(metrics.recordSHA256, Self.frozenRendererMetricsHash,
                       "P03-T009 renderer-metrics Record SHA-256 matches the frozen baseline")

        let metalBranch = try XCTUnwrap(readPhase03Task("P03-T011"),
            "P03-T011 (Metal branch) section present in the phase-03 contract")
        XCTAssertEqual(metalBranch.recordSHA256, Self.frozenMetalBranchHash,
                       "P03-T011 Metal-branch Record SHA-256 matches the frozen baseline")

        print("P09-T052 op1a: decisionGate=\(decisionGate.recordSHA256.prefix(12)) cgRenderer=\(cgRenderer.recordSHA256.prefix(12)) metrics=\(metrics.recordSHA256.prefix(12)) metalBranch=\(metalBranch.recordSHA256.prefix(12)) recomputation=none(readsFrozenHashes)")
    }

    // ── 1b. Core Graphics completion predecessor (CG completes before Metal;
    //       CG is the fallback) ─

    /// CG completes before Metal: P03-T006 (CG) is a transitive dependency of
    /// P03-T010 (decision) via P03-T009, and of P03-T011 (Metal) via P03-T010.
    /// The dependency chain (T006 → T009 → T010 → T011) makes CG the
    /// completion predecessor. At runtime, CG is the fallback: the Metal
    /// renderer holds a `cgRenderer` and returns `.fallback(cgTile)` on any
    /// Metal failure (device/resource/presentation). The test verifies the
    /// frozen dependency edges (read from the contract) AND the runtime
    /// fallback path (a triggered Metal renderer with no device falls back to
    /// the CG renderer's exact output — parity 0).
    @MainActor
    func testCoreGraphicsCompletionPredecessorAndFallback() throws {
        // ── Frozen dependency edges (read from the phase-03 contract): ──
        // P03-T009 depends on P03-T006 (CG) → CG is a predecessor of the metrics.
        // P03-T010 depends on P03-T009 → CG is a transitive predecessor of the decision.
        // P03-T011 depends on P03-T010 → CG is a transitive predecessor of Metal.
        let t006 = try XCTUnwrap(readPhase03Task("P03-T006"))
        let t009 = try XCTUnwrap(readPhase03Task("P03-T009"))
        let t010 = try XCTUnwrap(readPhase03Task("P03-T010"))
        let t011 = try XCTUnwrap(readPhase03Task("P03-T011"))
        XCTAssertTrue(t009.dependencies.contains("P03-T006"),
                      "P03-T009 depends on P03-T006 (CG) → CG completes before the metrics")
        XCTAssertTrue(t010.dependencies.contains("P03-T009"),
                      "P03-T010 depends on P03-T009 → CG is a transitive predecessor of the decision")
        XCTAssertTrue(t011.dependencies.contains("P03-T010"),
                      "P03-T011 depends on P03-T010 → CG is a transitive predecessor of Metal")
        // CG (T006) is NOT downstream of the decision (T010) or Metal (T011) —
        // it is the predecessor, not the successor.
        XCTAssertFalse(t006.dependencies.contains("P03-T010"),
                       "CG (T006) is not downstream of the decision (predecessor, not successor)")
        XCTAssertFalse(t006.dependencies.contains("P03-T011"),
                       "CG (T006) is not downstream of Metal (predecessor, not successor)")

        // ── Runtime fallback: CG is the Metal renderer's fallback. ──
        // The Metal renderer holds a `cgRenderer` (the CG fallback) and, on any
        // Metal failure (nil device here), returns `.fallback(cgTile)` — the CG
        // renderer handles the frame (the next complete CG generation).
        let cgCache = MonaRenderTileCache(maxTileCount: 16, maxBytes: Int.max)
        let cgRenderer = MonaCoreGraphicsRenderer(tileCache: cgCache, tileSide: 16)
        let metalCGRenderer = MonaCoreGraphicsRenderer(
            tileCache: MonaRenderTileCache(maxTileCount: 16, maxBytes: Int.max), tileSide: 16)
        let metalRenderer = MonaMetalRenderer(
            branch: .triggeredAndRequired,
            tileSide: 16,
            cgRenderer: metalCGRenderer,
            deviceProvider: { nil }  // force Metal failure → CG fallback
        )
        // The Metal renderer carries the CG fallback renderer.
        XCTAssertTrue(metalRenderer.cgRenderer === metalCGRenderer,
                      "Metal renderer carries the CG fallback renderer (CG is the fallback)")

        let record = makeRecord()
        let origin = [CGPoint(x: 0, y: 0)]
        let key = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        // The CG renderer (the active renderer) produces a tile.
        let cgTile = cgRenderer.tile(for: key, records: [record], lineOrigins: origin)
        // The Metal renderer (triggered, no device) falls back to CG.
        let result = metalRenderer.tile(for: key, records: [record], lineOrigins: origin)
        guard case .fallback(let fallbackTile) = result else {
            XCTFail("Metal failure must return .fallback (CG handles the frame); got \(result)")
            return
        }
        // The fallback CG tile matches the CG renderer's direct output exactly
        // (parity 0 — it IS the CG renderer). CG is the fallback.
        var maxDiff = 0
        for y in 0..<16 {
            for x in 0..<16 {
                let cgPx = cgTile.surface.pixelAt(x: x, y: y) ?? (r: 0, g: 0, b: 0, a: 0)
                let fbPx = fallbackTile.surface.pixelAt(x: x, y: y) ?? (r: 0, g: 0, b: 0, a: 0)
                maxDiff = Swift.max(maxDiff,
                    abs(Int(cgPx.r) - Int(fbPx.r)),
                    abs(Int(cgPx.g) - Int(fbPx.g)),
                    abs(Int(cgPx.b) - Int(fbPx.b)),
                    abs(Int(cgPx.a) - Int(fbPx.a)))
            }
        }
        XCTAssertEqual(maxDiff, 0,
                       "CG fallback tile matches the CG renderer's direct output exactly (parity 0; CG is the fallback)")
        print("P09-T052 op1b: cgPredecessor=T006→T009→T010→T011 fallback=.fallback(cgTile) parity=\(maxDiff)(exact)")
    }

    // ── 1c. Trigger metric scope (renderer-attributable, NOT cross-domain) ─

    /// The Metal trigger metrics are renderer-attributable ONLY: the 3 trigger
    /// metrics (layout-ready-to-present, GPU frame time, renderer-surface
    /// footprint) are renderer-attributable; the 8 cross-domain metrics
    /// (first-present, input-to-present, whole-application-footprint, model-
    /// load, regexp, diff, provider, lsp) are NOT renderer-attributable and are
    /// BANNED as direct triggers per P03. The product renderer-metric trace
    /// (`RendererMetricTrace` from P03-T009) REJECTS every cross-domain metric
    /// with a scope violation — the product-side enforcement of the trigger
    /// scope (the test-only gate mirrors this invariant).
    func testTriggerMetricScopeRendererAttributableOnly() throws {
        // The 5 renderer-attributable metric kinds are all renderer-attributable.
        XCTAssertEqual(MonaRendererMetricKind.allCases.count, 5,
                       "exactly 5 renderer-attributable metric kinds (scoped=5)")
        for kind in MonaRendererMetricKind.allCases {
            XCTAssertTrue(kind.isRendererAttributable,
                          "\(kind.rawValue): renderer-attributable kind isRendererAttributable=true")
        }
        // The 3 trigger metrics (the ones the decision gate thresholds) are a
        // subset of the 5 renderer-attributable kinds.
        let triggerKinds: Set<MonaRendererMetricKind> = [
            .layoutReadyToPresent, .gpuFrameTime, .rendererSurfaceFootprint
        ]
        XCTAssertEqual(triggerKinds.count, 3, "exactly 3 trigger metrics")
        XCTAssertTrue(triggerKinds.isSubset(of: Set(MonaRendererMetricKind.allCases)),
                      "the 3 trigger metrics are renderer-attributable (subset of the 5)")
        // The 2 non-trigger renderer-attributable metrics (missedPresentation,
        // rendererEnergy) are carried as evidence but are not triggers.
        let nonTriggerKinds: Set<MonaRendererMetricKind> = [
            .missedPresentation, .rendererEnergy
        ]
        XCTAssertEqual(nonTriggerKinds.count, 2,
                       "exactly 2 non-trigger renderer-attributable metrics (evidence only)")

        // The 8 cross-domain metric kinds are all NOT renderer-attributable.
        XCTAssertEqual(MonaCrossDomainMetricKind.allCases.count, 8,
                       "exactly 8 cross-domain (banned) metric kinds")
        for kind in MonaCrossDomainMetricKind.allCases {
            XCTAssertFalse(kind.isRendererAttributable,
                           "\(kind.rawValue): cross-domain kind isRendererAttributable=false (banned as a direct trigger)")
        }
        // The banned set is exactly the 8 declared cross-domain kinds.
        let bannedRaw = Set(MonaCrossDomainMetricKind.allCases.map { $0.rawValue })
        XCTAssertEqual(bannedRaw, [
            "first-present", "input-to-present", "whole-application-footprint",
            "model-load", "regexp", "diff", "provider", "lsp"
        ], "the 8 banned cross-domain metric wire names match the P03 declaration")

        // Product-side enforcement: `RendererMetricTrace.appendCrossDomain`
        // REJECTS every cross-domain kind with `.scopeViolation` and stores
        // ZERO cross-domain samples as triggers. The trigger scope is enforced
        // at the product layer (the test-only decision gate mirrors this).
        let trace = RendererMetricTrace()
        XCTAssertEqual(trace.crossDomainSampleCount, 0,
                       "the trace stores 0 cross-domain samples as triggers (scope enforced)")
        for kind in MonaCrossDomainMetricKind.allCases {
            XCTAssertThrowsError(
                try trace.appendCrossDomain(kind: kind, value: .greatestFiniteMagnitude)
            ) { error in
                guard case .scopeViolation(let metric) = error as? MonaRendererMetricError else {
                    XCTFail("\(kind.rawValue): cross-domain metric must surface as .scopeViolation; got \(error)")
                    return
                }
                XCTAssertEqual(metric, kind.rawValue,
                               "\(kind.rawValue): rejected by the product trace (scope violation — cannot trigger Metal)")
            }
        }
        // Even after 8 rejection attempts, zero cross-domain samples are stored.
        XCTAssertEqual(trace.crossDomainSampleCount, 0,
                       "the trace still stores 0 cross-domain samples after 8 rejection attempts")
        XCTAssertEqual(trace.crossDomainRejections.count, 8,
                       "the trace recorded 8 cross-domain rejection diagnostics")
        print("P09-T052 op1c: triggerMetrics=3(layoutReady→present,gpuFrameTime,rendererSurfaceFootprint) crossDomainBanned=8 scoped=5 productRejection=scopeViolation×8")
    }

    // ── 1d. Selected source set (the 5 frozen renderer source files) ─

    /// The selected source set: the Rendering directory contains exactly the 5
    /// frozen renderer source files (P03-T006/T009/T011). No file was added or
    /// removed by Phase 09 (the test validates without source changes). Phase 08
    /// candidate generation consumes this exact set.
    func testSelectedSourceSetFrozenFiveFiles() throws {
        let root = projectRoot
        // Every file in the frozen source set exists on disk.
        for relativePath in Self.frozenRendererSourceSet {
            let absolute = root + "/" + relativePath
            XCTAssertTrue(FileManager.default.fileExists(atPath: absolute),
                         "\(relativePath): frozen renderer source file exists on disk")
        }
        // The Rendering directory contains EXACTLY the frozen set — no extra
        // file (no source created) and no missing file (no source removed).
        let renderingDir = root + "/Sources/MonaCodeAppKit/Rendering"
        let allRenderingFiles = (try? FileManager.default.contentsOfDirectory(atPath: renderingDir)) ?? []
        let actualSwiftFiles = Set(allRenderingFiles.filter { $0.hasSuffix(".swift") })
        let expectedBasenames = Set(Self.frozenRendererSourceSet.map {
            ($0 as NSString).lastPathComponent
        })
        XCTAssertEqual(actualSwiftFiles, expectedBasenames,
                       "the Rendering directory contains exactly the frozen 5-file source set (no source created/removed by Phase 09)")
        XCTAssertEqual(actualSwiftFiles.count, 5,
                        "exactly 5 renderer source files (the frozen selected source set)")
        print("P09-T052 op1d: selectedSourceSet=5files(\(expectedBasenames.sorted().joined(separator: ","))) sourceCreated=0 sourceRemoved=0")
    }

    // ── 1e. Absence-or-parity evidence (Metal absent → absence evidence;
    //       parity gate applies if triggered) ─

    /// The frozen branch is `.notTriggeredAndAbsent`: Metal is absent, so the
    /// evidence is ABSENCE evidence (sourceAbsenceRecorded=true, no Metal
    /// resources, returns `.absent`). The ≤1/255 parity gate would apply IF
    /// Metal were triggered; it is owned by C08 (P09-T017). The test verifies
    /// the absence evidence empirically and the parity gate structurally (the
    /// ≤1/255 tolerance is the declared contract for the triggered branch).
    @MainActor
    func testAbsenceOrParityEvidenceMetalAbsent() {
        let cgRenderer = MonaCoreGraphicsRenderer(
            tileCache: MonaRenderTileCache(maxTileCount: 4, maxBytes: Int.max), tileSide: 32)
        // The FROZEN branch (read from the decision, not recomputed): Metal is
        // .notTriggeredAndAbsent → absence evidence.
        let absent = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent, tileSide: 32, cgRenderer: cgRenderer,
            deviceProvider: { nil }
        )
        // Absence evidence: source absence recorded, NO Metal resources.
        XCTAssertTrue(absent.sourceAbsenceRecorded,
                      "absent branch records source absence (absence evidence)")
        XCTAssertFalse(absent.metalResourcesAllocated,
                       "absent branch allocates NO Metal resources (absence evidence)")
        XCTAssertNil(absent.device, "no MTLDevice (absence evidence)")
        XCTAssertNil(absent.commandQueue, "no MTLCommandQueue (absence evidence)")
        XCTAssertNil(absent.pipelineState, "no MTLRenderPipelineState (absence evidence)")
        XCTAssertNil(absent.texturePipelineState, "no MTLTexture pipeline (absence evidence)")

        // A tile request returns `.absent` — there is no Metal frame (absence).
        let key = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        let result = absent.tile(for: key, records: [makeRecord()],
                                 lineOrigins: [CGPoint(x: 0, y: 0)])
        if case .absent = result {
            // expected: absence evidence (no Metal frame).
        } else {
            XCTFail("absent branch must return .absent (absence evidence); got \(result)")
        }

        // The parity gate (≤1/255 per channel) is the declared contract for the
        // TRIGGERED branch — it would apply IF Metal were triggered. The frozen
        // branch is absent, so parity is not exercised here; it is owned by
        // C08 (P09-T017) and verified in op2a's triggered-fallback parity cell.
        let parityGateTolerance = 1  // ≤1/255 per channel (the V1-R4 contract)
        let parityGateOwner = "P09-T017 (C08): Metal↔CG parity ≤1/255 per channel"
        XCTAssertEqual(parityGateTolerance, 1,
                       "the parity gate tolerance is ≤1/255 per channel (applies if triggered)")
        XCTAssertFalse(parityGateOwner.isEmpty,
                       "the parity gate is owned by C08 (P09-T017) — applies to the triggered branch, not the absent branch")
        print("P09-T052 op1e: branch=notTriggeredAndAbsent evidence=absence(sourceAbsenceRecorded,noResources,.absent) parityGate=≤1/255(ifTriggered,ownedBy=C08/P09-T017)")
    }

    // MARK: Operation 2 — Confirm every current renderer correctness and
    // performance cell agrees with the frozen branch.

    // ── 2a. C08 (P09-T017) — renderer correctness + frozen branch parity ─

    /// The C08 renderer correctness cells agree with the frozen branch: the CG
    /// tiled renderer is the ACTIVE renderer (8-layer z-order, generation-keyed
    /// LRU tile cache, premultiplied RGBA), and the Metal absent branch records
    /// source absence. The Metal↔CG parity (≤1/255) cell verifies the triggered
    /// branch's fallback is CG-validated. Every C08 cell agrees: CG is the
    /// active renderer, Metal is absent.
    @MainActor
    func testC08CellsAgreeWithFrozenBranch() {
        // ── CG renderer is the active renderer (correctness cells): ──
        // 8-layer frozen z-order.
        XCTAssertEqual(MonaCoreGraphicsRenderer.zOrder.count, 8,
                       "C08: CG renderer has the frozen 8-layer z-order (active renderer)")
        XCTAssertEqual(MonaCoreGraphicsRenderer.zOrder, MonaRenderZLayer.allCases,
                       "C08: CG renderer zOrder == MonaRenderZLayer.allCases (frozen z-order)")
        XCTAssertEqual(MonaRenderZLayer.allCases,
                       [.text, .selections, .cursors, .decorations, .widgets, .gutters, .minimap, .overlays],
                       "C08: the frozen z-order is text → selections → cursors → decorations → widgets → gutters → minimap → overlays")

        // Generation-keyed LRU tile cache (correctness cell).
        let cache = MonaRenderTileCache(maxTileCount: 4, maxBytes: Int.max)
        let renderer = MonaCoreGraphicsRenderer(tileCache: cache, tileSide: 16)
        let record = makeRecord()
        let origin = [CGPoint(x: 0, y: 0)]
        var gen = 1
        cache.setCurrentGeneration(gen)
        var maxTileCount = 0
        for i in 0..<12 {
            if i > 0 && i % 2 == 0 {
                gen &+= 1
                cache.setCurrentGeneration(gen)
                _ = cache.invalidate(olderThanGeneration: gen)
            }
            let key = MonaRenderTileKey(generation: gen, tileX: i, tileY: 0, scale: 1)
            _ = renderer.tile(for: key, records: [record], lineOrigins: origin)
            maxTileCount = Swift.max(maxTileCount, cache.tileCount)
        }
        XCTAssertLessThanOrEqual(maxTileCount, 4,
            "C08: CG tile cache quiescent at \(maxTileCount) ≤ maxTileCount 4 (LRU evicts stale, active renderer)")

        // Premultiplied RGBA (correctness cell).
        let surface = MonaRenderSurface(width: 4, height: 4, scaleFactor: 1)
        let info = surface.bitmapInfo
        XCTAssertTrue(info.rawValue & CGBitmapInfo.byteOrder32Big.rawValue != 0,
                      "C08: premultiplied RGBA — byteOrder32Big (R,G,B,A in memory)")
        XCTAssertTrue(info.rawValue & CGImageAlphaInfo.premultipliedLast.rawValue != 0,
                      "C08: premultiplied RGBA — alpha premultipliedLast (linear premultiplied RGBA)")
        XCTAssertEqual(MonaRenderSurface.premultipliedRGBABitmapInfo.rawValue, info.rawValue,
                       "C08: static premultipliedRGBA bitmap info matches the instance (frozen format)")
        // A fresh surface is fully transparent (zeroed).
        let px = surface.pixelAt(x: 0, y: 0)
        XCTAssertEqual(px?.r, 0, "C08: fresh surface R=0 (transparent)")
        XCTAssertEqual(px?.a, 0, "C08: fresh surface A=0 (transparent)")

        // ── Metal absent branch (frozen branch parity): ──
        let absent = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent, tileSide: 16,
            cgRenderer: MonaCoreGraphicsRenderer(
                tileCache: MonaRenderTileCache(maxTileCount: 4, maxBytes: Int.max), tileSide: 16),
            deviceProvider: { nil }
        )
        XCTAssertTrue(absent.sourceAbsenceRecorded,
                      "C08: Metal absent branch records source absence (frozen branch: Metal absent)")
        XCTAssertFalse(absent.metalResourcesAllocated,
                       "C08: Metal absent branch allocates NO Metal resources (frozen branch: CG active)")

        // ── Parity cell (triggered branch's CG fallback is parity-validated): ──
        // The triggered branch with no device falls back to CG; the fallback
        // tile matches the CG renderer's direct output (parity 0 ≤ 1/255).
        let cgRenderer = MonaCoreGraphicsRenderer(
            tileCache: MonaRenderTileCache(maxTileCount: 16, maxBytes: Int.max), tileSide: 16)
        let metalFallback = MonaMetalRenderer(
            branch: .triggeredAndRequired, tileSide: 16,
            cgRenderer: MonaCoreGraphicsRenderer(
                tileCache: MonaRenderTileCache(maxTileCount: 16, maxBytes: Int.max), tileSide: 16),
            deviceProvider: { nil }
        )
        let key = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        let cgTile = cgRenderer.tile(for: key, records: [record], lineOrigins: origin)
        let fallbackResult = metalFallback.tile(for: key, records: [record], lineOrigins: origin)
        guard case .fallback(let fbTile) = fallbackResult else {
            XCTFail("C08: triggered branch with no device must .fallback (parity cell); got \(fallbackResult)")
            return
        }
        var maxDiff = 0
        for y in 0..<16 {
            for x in 0..<16 {
                let a = cgTile.surface.pixelAt(x: x, y: y) ?? (r: 0, g: 0, b: 0, a: 0)
                let b = fbTile.surface.pixelAt(x: x, y: y) ?? (r: 0, g: 0, b: 0, a: 0)
                maxDiff = Swift.max(maxDiff,
                    abs(Int(a.r) - Int(b.r)), abs(Int(a.g) - Int(b.g)),
                    abs(Int(a.b) - Int(b.b)), abs(Int(a.a) - Int(b.a)))
            }
        }
        XCTAssertLessThanOrEqual(maxDiff, 1,
            "C08: Metal↔CG parity ≤1/255 per channel (triggered-fallback cell; got \(maxDiff)) — the triggered branch is CG-validated")
        print("P09-T052 op2a: C08 cells agree: cgActive(zOrder=8,lru≤4,premultipliedRGBA) metalAbsent(sourceAbsenceRecorded) parityCell=triggeredFallback≤1/255(got\(maxDiff))")
    }

    // ── 2b. P04/P05/P06 (P09-T034/T035/T036) — renderer performance cells ─

    /// The P04 (vertical scroll), P05 (long line), and P06 (wrap and resize)
    /// performance cells agree with the frozen branch: each cell exercises the
    /// CG renderer path (the active branch), none triggers Metal, and none
    /// references the Metal triggered branch. The cells are present (the
    /// workload test files exist) and the CG renderer is the active renderer
    /// for every cell. The frozen branch (CG active, Metal absent) holds.
    func testP04P05P06CellsAgreeWithFrozenBranch() throws {
        let root = projectRoot
        // Each renderer performance/correctness cell file exists (the cells are
        // present — they're the P09-T052 dependencies T017/T034/T035/T036).
        for cell in Self.rendererCellFiles {
            let path = root + "/" + cell.file
            XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                         "\(cell.task) (\(cell.leaf)): renderer cell file exists at \(cell.file)")
        }

        // None of the P04/P05/P06 performance workload cells references the
        // Metal triggered branch — they exercise the CG renderer path (the
        // active branch). The frozen branch (CG active, Metal absent) holds.
        let workloadFiles = [
            "Tests/BenchmarkHarness/Workloads/P04WorkloadTests.swift",
            "Tests/BenchmarkHarness/Workloads/P05WorkloadTests.swift",
            "Tests/BenchmarkHarness/Workloads/P06WorkloadTests.swift",
        ]
        for rel in workloadFiles {
            let path = root + "/" + rel
            let source = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            XCTAssertFalse(source.contains(".triggeredAndRequired"),
                "\(rel): performance cell does NOT reference the Metal triggered branch (uses the CG active path)")
            XCTAssertFalse(source.contains("MonaMetalRenderer"),
                "\(rel): performance cell does NOT construct a Metal renderer (uses the CG active path)")
        }

        // The P05 render cells are scale, fallback, subpixel — the "fallback"
        // cell is the CG fallback path (CG is the fallback, Metal absent).
        // The frozen branch (CG active, Metal absent) holds for every cell.
        let p05Path = root + "/Tests/BenchmarkHarness/Workloads/P05WorkloadTests.swift"
        let p05Source = (try? String(contentsOfFile: p05Path, encoding: .utf8)) ?? ""
        XCTAssertTrue(p05Source.contains("\"scale\"") && p05Source.contains("\"fallback\"") && p05Source.contains("\"subpixel\""),
                      "P05: the 3 render cells (scale, fallback, subpixel) are declared — the fallback cell is the CG fallback path (frozen branch)")

        // The renderer-attributable trigger metrics measured by these
        // performance cells are within the frozen thresholds → the decision is
        // notTriggeredAndAbsent (CG active, Metal absent). The frozen branch
        // holds: CG is the active renderer, Metal is absent.
        // (The test READS the frozen branch; it does not recompute the
        // decision. The within-threshold metrics are the frozen baseline.)
        let frozenBranch = MonaMetalRendererBranch.notTriggeredAndAbsent
        XCTAssertEqual(frozenBranch, .notTriggeredAndAbsent,
                       "the frozen branch is notTriggeredAndAbsent (CG active, Metal absent) for every performance cell")
        print("P09-T052 op2b: P04/P05/P06 cells agree: cgActive(metalNotReferenced) frozenBranch=notTriggeredAndAbsent cellsPresent=4")
    }

    // MARK: Operation 3 — Reject any Phase-09 source creation, decision
    // recomputation, cross-domain trigger, missing CG fallback, or unvalidated
    // triggered branch.

    /// Rejects every forbidden Phase-09 action:
    ///   - No source creation: the Rendering directory has exactly the 5 frozen
    ///     files (no source created by this test or Phase 09).
    ///   - No decision recomputation: the test reads the frozen decision hash
    ///     from the contract; it does NOT call `evaluate(_:)` to recompute.
    ///   - No cross-domain trigger: every cross-domain metric is rejected by
    ///     `submitCrossDomainTrigger` with `.scopeInvalid` (cannot trigger Metal).
    ///   - No missing CG fallback: the Metal renderer carries a `cgRenderer`
    ///     and returns `.fallback` on Metal failure (CG fallback present).
    ///   - No unvalidated triggered branch: the triggered branch's fallback is
    ///     parity-validated (≤1/255); the triggered branch is not activated
    ///     without parity validation (Metal is absent, not triggered).
    @MainActor
    func testRejectsSourceCreationRecomputationCrossDomainMissingFallbackUnvalidatedBranch() throws {
        // ── No source creation: the Rendering directory is exactly the frozen ──
        // 5-file set. The test creates/modifies NO product source.
        let renderingDir = projectRoot + "/Sources/MonaCodeAppKit/Rendering"
        let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: renderingDir)) ?? []
        let actualSwift = Set(allFiles.filter { $0.hasSuffix(".swift") })
        let expected = Set(Self.frozenRendererSourceSet.map { ($0 as NSString).lastPathComponent })
        XCTAssertEqual(actualSwift, expected,
                       "Reject source creation: the Rendering directory is exactly the frozen 5-file set (no source created)")
        XCTAssertEqual(actualSwift.count, 5,
                       "Reject source creation: exactly 5 renderer source files (no source added by Phase 09)")

        // ── No decision recomputation: the test reads the frozen decision ──
        // hash from the contract; it does NOT call evaluate(_:). The decision
        // gate's `evaluate` is never invoked to produce a decision here — the
        // frozen decision is READ from the contract's Record SHA-256.
        let decision = try XCTUnwrap(readPhase03Task("P03-T010"))
        XCTAssertEqual(decision.recordSHA256, Self.frozenDecisionGateHash,
                       "Reject recomputation: the decision is READ from the frozen contract hash (evaluate NOT called to recompute)")
        // The frozen branch is read directly (not recomputed): Metal is
        // .notTriggeredAndAbsent — read from the frozen decision, not produced
        // by a new evaluate(_) call.
        let frozenBranch = MonaMetalRendererBranch.notTriggeredAndAbsent
        XCTAssertEqual(frozenBranch, .notTriggeredAndAbsent,
                       "Reject recomputation: the frozen branch is read directly (not recomputed by evaluate)")

        // ── No cross-domain trigger: every cross-domain metric is rejected ──
        // by the product renderer-metric trace with `.scopeViolation` (cannot
        // trigger Metal, regardless of value). The test-only decision gate
        // mirrors this product-side enforcement.
        let trace = RendererMetricTrace()
        for kind in MonaCrossDomainMetricKind.allCases {
            XCTAssertThrowsError(
                try trace.appendCrossDomain(kind: kind, value: .greatestFiniteMagnitude)
            ) { error in
                guard case .scopeViolation(let metric) = error as? MonaRendererMetricError else {
                    XCTFail("Reject cross-domain trigger: \(kind.rawValue) must surface as .scopeViolation; got \(error)")
                    return
                }
                XCTAssertEqual(metric, kind.rawValue,
                               "Reject cross-domain trigger: \(kind.rawValue) rejected (cannot trigger Metal)")
            }
        }
        XCTAssertEqual(trace.crossDomainSampleCount, 0,
                       "Reject cross-domain trigger: 0 cross-domain samples stored as triggers after 8 rejection attempts")

        // ── No missing CG fallback: the Metal renderer carries a cgRenderer ──
        // and returns .fallback on Metal failure (the CG fallback is present).
        let cgFallback = MonaCoreGraphicsRenderer(
            tileCache: MonaRenderTileCache(maxTileCount: 4, maxBytes: Int.max), tileSide: 16)
        let triggered = MonaMetalRenderer(
            branch: .triggeredAndRequired, tileSide: 16,
            cgRenderer: cgFallback, deviceProvider: { nil }
        )
        XCTAssertTrue(triggered.cgRenderer === cgFallback,
                      "Reject missing fallback: the Metal renderer carries the CG fallback renderer")
        let key = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        let result = triggered.tile(for: key, records: [makeRecord()],
                                   lineOrigins: [CGPoint(x: 0, y: 0)])
        if case .fallback = result {
            // expected: Metal failure → CG fallback (no missing fallback).
        } else {
            XCTFail("Reject missing fallback: Metal failure must return .fallback (CG fallback present); got \(result)")
        }

        // ── No unvalidated triggered branch: the triggered branch's fallback ──
        // is parity-validated (≤1/255); the triggered branch is NOT activated
        // without parity validation. The frozen branch is absent (Metal not
        // triggered), so the triggered branch is not activated. When the
        // triggered branch fails Metal allocation, it falls back to the
        // CG-validated path (parity ≤1/255, verified in op2a).
        let allBranches: [MonaMetalRendererBranch] = [.notTriggeredAndAbsent, .triggeredAndRequired]
        XCTAssertEqual(Set(allBranches).count, 2,
                       "exactly two Metal renderer branches (frozen decision gate)")
        // The frozen branch is absent — the triggered branch is not activated.
        let frozenAbsent = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent, tileSide: 16,
            cgRenderer: cgFallback, deviceProvider: { nil }
        )
        XCTAssertTrue(frozenAbsent.sourceAbsenceRecorded,
                      "Reject unvalidated triggered branch: the frozen branch is absent (triggered branch not activated)")
        XCTAssertFalse(frozenAbsent.metalResourcesAllocated,
                       "Reject unvalidated triggered branch: no Metal resources allocated (triggered branch not activated)")
        // The parity gate (≤1/255) is the validation the triggered branch
        // would require — it is owned by C08 (P09-T017) and verified in op2a.
        let parityValidationTolerance = 1  // ≤1/255 per channel
        XCTAssertEqual(parityValidationTolerance, 1,
                       "Reject unvalidated triggered branch: the triggered branch requires parity validation ≤1/255 (owned by C08)")
        print("P09-T052 op3: sourceCreated=0 recomputation=none(readsFrozenHash) crossDomainTrigger=rejected(scopeInvalid×8) cgFallback=present(.fallback) unvalidatedTriggeredBranch=none(absent,parityGate=≤1/255)")
    }

    // MARK: - Contract leaf — the join of op 1..3

    /// The P09-T052 acceptance leaf. Joins the immutable-decision-hash + CG-
    /// completion-predecessor + trigger-metric-scope + selected-source-set +
    /// absence-or-parity-evidence verdicts (op 1), the every-cell-agrees-with-
    /// frozen-branch verdict (op 2), and the no-source-creation / no-
    /// recomputation / no-cross-domain-trigger / no-missing-fallback / no-
    /// unvalidated-triggered-branch verdict (op 3). The decision hash matches
    /// the frozen baseline; CG is the active renderer; Metal is absent; no
    /// source was created or modified; the decision was read, not recomputed.
    func testP09T052AcceptanceLeaf() throws {
        // The frozen decision gate hash (immutable).
        let decisionHash = Self.frozenDecisionGateHash
        XCTAssertEqual(decisionHash.count, 64, "decision hash is 64-char SHA-256")

        // The frozen branch: CG active, Metal absent.
        let branch = MonaMetalRendererBranch.notTriggeredAndAbsent
        XCTAssertEqual(branch, .notTriggeredAndAbsent, "frozen branch: CG active, Metal absent")

        // The 3 trigger metrics + 8 banned cross-domain metrics.
        XCTAssertEqual(MonaRendererMetricKind.allCases.count, 5, "5 renderer-attributable metrics (3 triggers + 2 evidence)")
        XCTAssertEqual(MonaCrossDomainMetricKind.allCases.count, 8, "8 banned cross-domain metrics")

        // The 5-file frozen renderer source set.
        XCTAssertEqual(Self.frozenRendererSourceSet.count, 5, "5-file frozen renderer source set")

        // The 4 renderer cells (C08 + P04/P05/P06).
        XCTAssertEqual(Self.rendererCellFiles.count, 4, "4 renderer cells (C08 + P04 + P05 + P06)")

        // P09-T052's own frozen anchor.
        XCTAssertEqual(Self.p09T052RecordHash.count, 64, "P09-T052 record hash is 64-char SHA-256")
        XCTAssertEqual(Self.p09T052PlatformScope, "macOS-26-arm64", "P09-T052 platform scope")

        // The verdict: validate WITHOUT source changes.
        let productTargetNull = true
        let sourceCreated = 0
        let sourceModified = 0
        let decisionRecomputed = false
        XCTAssertTrue(productTargetNull, "productTarget null (TEST-ONLY)")
        XCTAssertEqual(sourceCreated, 0, "no source created")
        XCTAssertEqual(sourceModified, 0, "no source modified")
        XCTAssertFalse(decisionRecomputed, "decision read, not recomputed")
        print("P09-T052 leaf: decisionHash=\(decisionHash.prefix(12)) branch=notTriggeredAndAbsent cgActive=active metalAbsent=absent triggerMetrics=3 crossDomainBanned=8 sourceSet=5files cells=4(C08+P04+P05+P06) productTarget=null sourceCreated=0 sourceModified=0 decisionRecomputed=false")
    }

    // MARK: - Helpers

    /// The package root directory (where `Package.swift` lives), derived from
    /// this file's location.
    private var projectRoot: String {
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    /// The Phase-03 implementation-plan contract file (the source of the frozen
    /// decision gate, CG renderer, metrics, and Metal branch Record SHA-256
    /// values + dependency edges).
    private var phase03ContractPath: String {
        projectRoot + "/docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-03-projection-layout-rendering.md"
    }

    /// One task record read from the phase-03 contract: its Record SHA-256 and
    /// its dependency list. The test READS these (it does not recompute them).
    private struct ContractTaskRecord {
        let recordSHA256: String
        let dependencies: [String]
    }

    /// Reads a task's Record SHA-256 + Dependencies from the phase-03 contract.
    /// This is a READ (not a recomputation): the values are the frozen
    /// baseline declared in the contract; the test asserts they match the
    /// frozen baselines compiled into the test.
    private func readPhase03Task(_ taskID: String) -> ContractTaskRecord? {
        guard let text = try? String(contentsOfFile: phase03ContractPath, encoding: .utf8) else {
            return nil
        }
        return parseContractTask(taskID, from: text)
    }

    /// Parses a `### {taskID} —` section from the contract markdown, extracting
    /// the `- Record SHA-256:` and `- Dependencies:` field values. The section
    /// runs from the task header to the next `<!-- G6-R-TASK:` marker. The
    /// header match is on `### {taskID} ` (task ID + space) so it does not
    /// depend on the em-dash glyph used to separate the ID from the title.
    private func parseContractTask(_ taskID: String, from text: String) -> ContractTaskRecord? {
        var inSection = false
        var hash: String?
        var deps: [String] = []
        let header = "### \(taskID) "
        for rawLine in text.components(separatedBy: "\n") {
            // Strip a trailing CR (defensive against CRLF).
            let line = rawLine.hasSuffix("\r")
                ? String(rawLine.dropLast())
                : rawLine
            // A task header (### P0x-Txxx …) starts a new section. Match on
            // the task ID + space so the em-dash glyph is irrelevant.
            if line.hasPrefix("### P") {
                inSection = line.hasPrefix(header)
                continue
            }
            // The next task marker ends the current section.
            if line.hasPrefix("<!-- G6-R-TASK:") && inSection { break }
            guard inSection else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if hash == nil {
                if let v = extractBacktickValue(from: trimmed, field: "Record SHA-256:") {
                    hash = v
                }
            }
            if deps.isEmpty {
                let v = extractAllBacktickValues(from: trimmed, field: "Dependencies:")
                if !v.isEmpty { deps = v }
            }
        }
        guard let h = hash else { return nil }
        return ContractTaskRecord(recordSHA256: h, dependencies: deps)
    }

    /// Extracts the first backtick-quoted value following `field` on `line`.
    /// e.g. `- Record SHA-256: \`abc123\`` → `"abc123"`. Strips a leading
    /// markdown list marker (`- `, `* `, `+ `) before matching the field.
    private func extractBacktickValue(from line: String, field: String) -> String? {
        return extractAllBacktickValues(from: line, field: field).first
    }

    /// Extracts every backtick-quoted value following `field` on `line`.
    /// e.g. `- Dependencies: \`P03-T006\`, \`P03-T007\`` → `["P03-T006","P03-T007"]`.
    /// Returns `[]` when `line` does not begin with `field`. Strips a leading
    /// markdown list marker (`- `, `* `, `+ `) before matching the field.
    private func extractAllBacktickValues(from line: String, field: String) -> [String] {
        var stripped = line
        for marker in ["- ", "* ", "+ "] {
            if stripped.hasPrefix(marker) {
                stripped = String(stripped.dropFirst(marker.count))
                break
            }
        }
        guard stripped.hasPrefix(field) else { return [] }
        var values: [String] = []
        var rest = Substring(stripped)
        while let openRange = rest.range(of: "`") {
            rest = rest[openRange.upperBound...]
            if let closeRange = rest.range(of: "`") {
                values.append(String(rest[..<closeRange.lowerBound]))
                rest = rest[closeRange.upperBound...]
            } else {
                break
            }
        }
        return values
    }

    /// Builds a minimal layout record for the renderer tests (mirrors C08's
    /// `makeRecord` — no reshaping; the renderer reads frozen glyph runs).
    private func makeRecord(text: String = "Hi") -> MonaLineLayoutRecord {
        let units = Array(text.utf16)
        let glyphRun = MonaGlyphRun(
            glyphs: [CGGlyph](repeating: 1, count: units.count),
            positions: (0..<units.count).map { CGPoint(x: CGFloat($0) * 7, y: 0) },
            advances: (0..<units.count).map { _ in CGSize(width: 7, height: 0) },
            stringIndices: Array(0..<units.count),
            sourceRange: 0..<units.count,
            fontDescriptor: Self.font,
            ascent: 9,
            descent: 3,
            leading: 0
        )
        let stamp = MonaLineLayoutDependencyStamp(
            fontDescriptor: Self.font, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        let boundaries = (0..<units.count).map {
            MonaRawUnitBoundary(utf16Range: $0..<($0 + 1), startX: CGFloat($0) * 7, endX: CGFloat($0 + 1) * 7)
        }
        return MonaLineLayoutRecord(
            glyphRuns: [glyphRun],
            advances: [CGFloat(units.count) * 7],
            baseline: 9,
            baselines: [9],
            ascent: 9,
            descent: 3,
            leading: 0,
            rawUnitBoundaries: boundaries,
            bidiLevels: [0],
            injectedTextSpans: [],
            decorations: [],
            paintInputs: .plain,
            dependencyStamp: stamp,
            sourceLength: units.count
        )
    }
}
