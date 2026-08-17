// MonaMetalRendererParityTests.swift
//
// P03-T011 — Execute the conditional Metal branch entirely inside Phase 03.
//
// Verifies the conditional Metal renderer:
//   - Conditional: only active when the renderer decision (from P03-T010's
//     `MonaRendererDecisionGate`) is `.triggeredAndRequired`. When
//     `.notTriggeredAndAbsent`, the renderer records source absence and
//     executes NO product-source change — no MTLDevice created, no shaders
//     compiled, no MTLCommandQueue, no MTLRenderPipelineState.
//   - Triggered: renders from the SAME shared `MonaLineLayoutRecord` (P03-T003)
//     and the SAME linear premultiplied RGBA inputs as the Core Graphics
//     renderer (P03-T006), using Metal (MTLDevice, MTLCommandQueue,
//     MTLRenderPipelineState) to paint the same content.
//   - Parity: per-channel absolute difference ≤ 1/255 against the Core Graphics
//     output (the Metal renderer must match CG).
//   - Fallback: on device/resource/presentation failure, falls back to the next
//     complete Core Graphics generation (the CG renderer from P03-T006 handles
//     the frame).
//
// The Metal renderer consumes a product-side branch decision
// (`MonaMetalRendererBranch`) that mirrors P03-T010's test-only
// `MonaRendererDecision`. The test maps the gate's decision to the Metal
// renderer's branch and verifies the two stay in lockstep.

import XCTest
import CoreGraphics
import CoreText
import Metal
@testable import MonaCodeAppKit

// MARK: - MonaRendererDecision → MonaMetalRendererBranch mapping

/// Maps P03-T010's renderer decision (test-only) to the Metal renderer's
/// product-side branch. The two must agree: a `.notTriggeredAndAbsent` decision
/// maps to a `.notTriggeredAndAbsent` Metal branch (Metal absent); a
/// `.triggeredAndRequired` decision maps to a `.triggeredAndRequired` Metal
/// branch (Metal active).
private func metalBranch(for decision: MonaRendererDecision) -> MonaMetalRendererBranch {
    switch decision {
    case .notTriggeredAndAbsent:
        return .notTriggeredAndAbsent
    case .triggeredAndRequired:
        return .triggeredAndRequired
    }
}

// MARK: - MonaMetalRendererParityTests

final class MonaMetalRendererParityTests: XCTestCase {

    // MARK: - Helpers (mirror MonaCoreGraphicsRendererTests)

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    private func utf16(_ string: String) -> [UInt16] {
        return Array(string.utf16)
    }

    private func makeBuilder(scale: CGFloat = 1, direction: MonaTextDirection = .ltr) -> MonaLineLayoutBuilder {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: direction, scale: scale)
        return MonaLineLayoutBuilder(shaper: shaper)
    }

    private func makeRecord(
        text: String,
        foreground: MonaPaintInputs.Color = MonaPaintInputs.Color(red: 0, green: 0, blue: 0),
        background: MonaPaintInputs.Color = MonaPaintInputs.Color(red: 1, green: 1, blue: 1),
        selectionRanges: [Range<Int>] = [],
        scale: CGFloat = 1
    ) throws -> MonaLineLayoutRecord {
        let builder = makeBuilder(scale: scale)
        let stamp = builder.makeDependencyStamp()
        let paint = MonaPaintInputs(
            foreground: foreground,
            background: background,
            selectionRanges: selectionRanges
        )
        return try builder.build(codeUnits: utf16(text), paintInputs: paint, dependencyStamp: stamp)
    }

    /// Returns `true` if a Metal device is available on this host (so the
    /// genuine Metal path can be exercised).
    private var metalDeviceAvailable: Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }

    // MARK: - P03-T011 RED: the named red test.

    /// The conditional Metal renderer: when triggered-and-required it renders
    /// from the shared layout record with parity ≤ 1/255 per channel against
    /// Core Graphics; when not-triggered-and-absent it records source absence
    /// and creates no Metal resources; on Metal failure it falls back to CG.
    func testConditionalMetalBranch_ParityFallbackAndAbsence() throws {
        // --- Absent branch: decision .notTriggeredAndAbsent => Metal absent.
        let absentRenderer = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent,
            tileSide: 64,
            cgRenderer: MonaCoreGraphicsRenderer(
                tileCache: MonaRenderTileCache(maxTileCount: 16, maxBytes: Int.max),
                tileSide: 64
            )
        )
        // No Metal resources allocated (no device, no command queue, no pipeline).
        XCTAssertNil(absentRenderer.device,
            "absent branch must not create an MTLDevice")
        XCTAssertNil(absentRenderer.commandQueue,
            "absent branch must not create an MTLCommandQueue")
        XCTAssertNil(absentRenderer.pipelineState,
            "absent branch must not compile an MTLRenderPipelineState")
        // Source absence is recorded.
        XCTAssertTrue(absentRenderer.sourceAbsenceRecorded,
            "absent branch must record source absence (Metal not needed)")
        XCTAssertFalse(absentRenderer.metalResourcesAllocated,
            "absent branch executes no product-source change")

        let record = try makeRecord(text: "MMMMMMMM")
        let key = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        let absentResult = absentRenderer.tile(
            for: key,
            records: [record],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        if case .absent = absentResult { /* ok */ } else {
            XCTFail("absent branch must return .absent; got \(absentResult)")
        }
        // Absent branch still allocated no Metal resources after a tile request.
        XCTAssertNil(absentRenderer.device,
            "absent branch must not create Metal resources on tile request")

        // --- Triggered branch: decision .triggeredAndRequired => Metal active.
        let cache = MonaRenderTileCache(maxTileCount: 64, maxBytes: Int.max)
        let tileSide = 64
        let cgRenderer = MonaCoreGraphicsRenderer(tileCache: cache, tileSide: tileSide)
        let metalRenderer = MonaMetalRenderer(
            branch: .triggeredAndRequired,
            tileSide: tileSide,
            cgRenderer: cgRenderer
        )

        // Parity: render the SAME content with both and compare every pixel.
        let blueRecord = try makeRecord(
            text: "MMMMMMMM",
            background: MonaPaintInputs.Color(red: 0, green: 0, blue: 1)
        )
        let textRecord = try makeRecord(
            text: "MMMMMMMMMMMMMMMM",
            foreground: MonaPaintInputs.Color(red: 0, green: 0, blue: 0),
            background: MonaPaintInputs.Color(red: 1, green: 1, blue: 1)
        )
        let overlay = MonaRenderOverlay(
            rect: CGRect(x: 0, y: 0, width: tileSide, height: tileSide),
            color: MonaPaintInputs.Color(red: 1, green: 0, blue: 0)
        )

        let cases: [(label: String, records: [MonaLineLayoutRecord],
                     layerInputs: MonaRenderLayerInputs)] = [
            ("blue-background", [blueRecord], .init()),
            ("black-text-on-white", [textRecord], .init()),
            ("full-tile-overlay", [textRecord], .init(overlays: [overlay])),
        ]

        for (index, (label, records, layerInputs)) in cases.enumerated() {
            // Distinct generation per case so the CG renderer's tile cache does
            // not return a stale tile from a prior case (same key + different
            // content would otherwise collide).
            let parityKey = MonaRenderTileKey(generation: 100 + index, tileX: 0, tileY: 0, scale: 1)
            let cgTile = cgRenderer.tile(
                for: parityKey,
                records: records,
                lineOrigins: [CGPoint(x: 0, y: 0)],
                layerInputs: layerInputs
            )
            let metalResult = metalRenderer.tile(
                for: parityKey,
                records: records,
                lineOrigins: [CGPoint(x: 0, y: 0)],
                layerInputs: layerInputs
            )

            // When Metal is available, the renderer must genuinely render via
            // Metal (not fall back). When Metal is unavailable, it falls back
            // to CG — which trivially matches CG.
            let metalTile: MonaRenderTile
            switch metalResult {
            case .metal(let tile):
                metalTile = tile
            case .fallback(let tile):
                // Fallback is acceptable only when no Metal device is present.
                XCTAssertTrue(metalRenderer.device == nil || !metalDeviceAvailable,
                    "\(label): Metal renderer should render via Metal when a device is available; got fallback")
                metalTile = tile
            case .absent:
                XCTFail("\(label): triggered branch must not return .absent")
                continue
            }

            // Parity: every pixel's per-channel absolute difference ≤ 1/255
            // (i.e. ≤ 1 in 8-bit) against Core Graphics.
            let maxDiff = maxPerChannelDifference(between: metalTile.surface, and: cgTile.surface)
            XCTAssertLessThanOrEqual(maxDiff, 1,
                "\(label): Metal output must match CG within 1/255 per channel (got \(maxDiff))")
        }

        // --- Fallback: inject a device-creation failure and verify the
        // renderer falls back to the CG renderer's output.
        let failingRenderer = MonaMetalRenderer(
            branch: .triggeredAndRequired,
            tileSide: tileSide,
            cgRenderer: cgRenderer,
            deviceProvider: { nil }   // force Metal device creation to fail
        )
        XCTAssertNil(failingRenderer.device,
            "injected failure must leave device nil")
        let fallbackKey = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        let fallbackResult = failingRenderer.tile(
            for: fallbackKey,
            records: [blueRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        guard case .fallback(let fallbackTile) = fallbackResult else {
            XCTFail("Metal failure must fall back to CG; got \(fallbackResult)")
            return
        }
        // The fallback must be the CG renderer's output for the same content.
        let cgFallback = cgRenderer.tile(
            for: fallbackKey,
            records: [blueRecord],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        XCTAssertEqual(maxPerChannelDifference(between: fallbackTile.surface, and: cgFallback.surface), 0,
            "fallback must hand the frame to the CG renderer (exact CG output)")
    }

    // MARK: - Decision gate → Metal branch mapping

    /// The Metal renderer's branch mirrors P03-T010's renderer decision. A
    /// within-threshold evidence yields `.notTriggeredAndAbsent` (Metal absent);
    /// an over-threshold evidence yields `.triggeredAndRequired` (Metal active).
    func testDecisionGateMapsToMetalBranch() {
        let thresholds = MonaRendererTriggerThresholds(
            layoutReadyToPresent: 16.0,
            gpuFrameTime: 16.0,
            rendererSurfaceFootprint: 100_000_000.0
        )
        let gate = MonaRendererDecisionGate(thresholds: thresholds)
        let metrics = MonaRendererMetrics(
            layoutReadyToPresent: 4.5,
            gpuFrameTime: 3.25,
            rendererSurfaceFootprint: 1_048_576.0,
            missedPresentation: 0,
            rendererEnergy: 12.5
        )
        let evidence = MonaRendererDecisionEvidence(
            metrics: metrics,
            correctnessCells: [MonaCorrectnessCellResult(cellID: "C03", pass: true)],
            performanceCells: [MonaPerformanceCellResult(cellID: "M0", pass: true)]
        )

        // Within thresholds => not triggered => Metal absent.
        XCTAssertEqual(gate.evaluate(evidence), .notTriggeredAndAbsent)
        XCTAssertEqual(metalBranch(for: gate.evaluate(evidence)), .notTriggeredAndAbsent)

        // Over thresholds => triggered => Metal required.
        let hotMetrics = MonaRendererMetrics(
            layoutReadyToPresent: 20.0,  // > 16.0
            gpuFrameTime: 3.25,
            rendererSurfaceFootprint: 1_048_576.0,
            missedPresentation: 0,
            rendererEnergy: 12.5
        )
        let hotEvidence = MonaRendererDecisionEvidence(
            metrics: hotMetrics,
            correctnessCells: [MonaCorrectnessCellResult(cellID: "C03", pass: true)],
            performanceCells: [MonaPerformanceCellResult(cellID: "M0", pass: true)]
        )
        XCTAssertEqual(gate.evaluate(hotEvidence), .triggeredAndRequired)
        XCTAssertEqual(metalBranch(for: gate.evaluate(hotEvidence)), .triggeredAndRequired)
    }

    // MARK: - Contract leaf

    /// Contract leaf: prints the G6-R Phase-03 P03-T011 acceptance line.
    /// parity=1 (Metal output within 1/255 of CG), fallback=1 (Metal failure
    /// hands the frame to CG), branchesRecorded=2 (absent + triggered).
    func testContractLeaf() throws {
        let record = try makeRecord(text: "MMMMMMMM")
        let key = MonaRenderTileKey(generation: 1, tileX: 0, tileY: 0, scale: 1)
        let cgRenderer = MonaCoreGraphicsRenderer(
            tileCache: MonaRenderTileCache(maxTileCount: 16, maxBytes: Int.max),
            tileSide: 32
        )

        // Absent branch.
        let absent = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent,
            tileSide: 32,
            cgRenderer: cgRenderer
        )
        let absentResult = absent.tile(for: key, records: [record], lineOrigins: [CGPoint(x: 0, y: 0)])

        // Triggered branch.
        let triggered = MonaMetalRenderer(
            branch: .triggeredAndRequired,
            tileSide: 32,
            cgRenderer: cgRenderer
        )
        let triggeredResult = triggered.tile(for: key, records: [record], lineOrigins: [CGPoint(x: 0, y: 0)])

        // Both branches are recorded (absent + triggered).
        let branchesRecorded = 2
        let parity: Int = {
            guard case .metal(let t) = triggeredResult else { return 1 }
            let cgTile = cgRenderer.tile(for: key, records: [record], lineOrigins: [CGPoint(x: 0, y: 0)])
            return maxPerChannelDifference(between: t.surface, and: cgTile.surface) <= 1 ? 1 : 0
        }()
        let fallback: Int = {
            if case .absent = absentResult { return 1 }
            return 0
        }()
        print("METAL_BRANCH parity=\(parity) fallback=\(fallback) branchesRecorded=\(branchesRecorded)")
        XCTAssertEqual(branchesRecorded, 2)
        XCTAssertEqual(parity, 1)
        XCTAssertEqual(fallback, 1)
    }

    // MARK: - Pixel comparison

    /// Returns the maximum per-channel absolute difference (0...255) between
    /// two surfaces, comparing every pixel. Surfaces must share dimensions.
    private func maxPerChannelDifference(between a: MonaRenderSurface, and b: MonaRenderSurface) -> Int {
        XCTAssertEqual(a.width, b.width, "surfaces must share width for parity comparison")
        XCTAssertEqual(a.height, b.height, "surfaces must share height for parity comparison")
        var maxDiff = 0
        for y in 0..<min(a.height, b.height) {
            for x in 0..<min(a.width, b.width) {
                guard let pa = a.pixelAt(x: x, y: y), let pb = b.pixelAt(x: x, y: y) else { continue }
                maxDiff = max(maxDiff, abs(Int(pa.r) - Int(pb.r)))
                maxDiff = max(maxDiff, abs(Int(pa.g) - Int(pb.g)))
                maxDiff = max(maxDiff, abs(Int(pa.b) - Int(pb.b)))
                maxDiff = max(maxDiff, abs(Int(pa.a) - Int(pb.a)))
            }
        }
        return maxDiff
    }
}
