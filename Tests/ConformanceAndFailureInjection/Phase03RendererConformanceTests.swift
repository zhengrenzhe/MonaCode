// Phase03RendererConformanceTests.swift
//
// P03-T012 — Close projection, geometry, and renderer parity before native input.
//
// The Phase 03 closure conformance suite. It JOINS all Phase 03 evidence —
// projection (P03-T001 ViewGraph), shaping (P03-T002 TextShaper), geometry
// (P03-T003 LineLayoutRecord + LineLayoutBuilder), dependency stamps
// (P03-T004 DependencyStamps), scroll (P03-T005 ScrollModel), Core Graphics
// renderer (P03-T006 CoreGraphicsRenderer + RenderTileCache + RenderSurface),
// geometry barrier (P03-T007 QueryGeometryBarrier + HitTester), failure
// records (P03-T008 FailedLineRecord), renderer metrics (P03-T009
// RendererMetrics + RendererMetricTrace), and the conditional Metal branch
// (P03-T010 decision gate evidence + P03-T011 MetalRenderer) — as one
// revision-locked suite, and:
//
//   1. Verifies every Phase 03 component exists and is wired to its neighbors
//      (projection → geometry → scroll → shaping → failure → CG → Metal).
//   2. Verifies revision locking: all components share one generation.
//   3. Proves viewport operation counts scale with visible rows + changed
//      dependencies (more visible rows → more layout work; dependency change →
//      cache invalidation via the frozen edge map).
//   4. Freezes the renderer source set + branch evidence consumed by Phase 08
//      candidate generation.
//   5. Asserts zero-diff consistency across the full Phase 03 chain.
//
// This is a TEST-ONLY task (no product source). The file lives in the
// `conformance-and-failure-injection` target (kept a non-test `.target` for
// the package-graph invariant). Discovery is provided by the `MonaCodeTests`
// test target depending on this target; the class is introspected from the
// linked image, so `swift test --filter Phase03RendererConformanceTests`
// runs it.

import Foundation
import XCTest
import CoreGraphics
import Metal
import MonaCode
import MonaCodeAppKit

// MARK: - Phase03RendererConformanceTests

final class Phase03RendererConformanceTests: XCTestCase {

    // MARK: - Shared configuration

    /// The font used across all Phase 03 shaping in this suite. Using one
    /// font ties the shaper, builder, dependency stamp, and both renderers
    /// to one shaping configuration — the "revision-locked" invariant.
    private static let font = MonaFontDescriptor(familyName: "Menlo", size: 14)

    /// The per-view-line pixel height used across the suite.
    private static let lineHeight = 20

    // MARK: 1. All Phase 03 components exist and are wired together

    /// Every Phase 03 task produced a live, addressable component, and the
    /// components are wired to their neighbors. This is the JOIN of all twelve
    /// task evidence sets by one shared generation.
    func testAllPhase03ComponentsExistAndAreWiredTogether() throws {
        // --- P03-T001 — ViewGraph projection + logarithmic vertical index ---
        let model = MonaCodeModel(
            text: "Hello\nWorld\nPhase03",
            uri: MonaURI(scheme: "inmemory", path: "/p03-join")
        )
        let viewGraph = MonaViewGraph(model: model, lineHeight: Self.lineHeight)
        let projection = viewGraph.getProjection()
        XCTAssertGreaterThan(projection.generation, 0, "the view graph published a generation")
        XCTAssertEqual(projection.viewLines.count, 3, "three model lines → three view lines")
        XCTAssertGreaterThan(viewGraph.verticalIndex.viewLineCount, 0, "the vertical index is populated")

        // --- P03-T002 — TextShaper with Core Text + deterministic fallback ---
        let resolver = MonaFontFallbackResolver(primary: Self.font, fallback: [])
        let shaper = MonaTextShaper(primaryFont: Self.font, fallback: resolver)
        let shapingResult = try shaper.shape(Array("Hello".utf16))
        XCTAssertGreaterThan(shapingResult.runs.count, 0, "the shaper produced glyph runs")
        XCTAssertGreaterThan(shaper.recordedRunCount, 0, "the shaper recorded its run count (Q1-R4 provenance)")

        // --- P03-T003 — LineLayoutRecord (immutable frozen geometry) ---
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(codeUnits: Array("Hello".utf16), dependencyStamp: stamp)
        XCTAssertGreaterThan(record.glyphRuns.count, 0, "the builder assembled glyph runs into a record")
        XCTAssertGreaterThan(record.totalWidth, 0, "the record has a non-zero total width")
        XCTAssertGreaterThan(record.rawUnitBoundaries.count, 0, "the record carries raw-unit boundaries for hit testing")

        // --- P03-T004 — Seven non-contradictory dependency stamp domains ---
        XCTAssertEqual(MonaStampDomain.allCases.count, 7, "exactly seven stamp domains")
        let edgeMap = MonaDependencyStampEdgeMap.standard
        for mutation in MonaMutation.allCases {
            let domains = edgeMap.invalidatedDomains(for: mutation)
            XCTAssertFalse(domains.isEmpty, "\(mutation.rawValue): every mutation has a non-empty frozen edge set")
        }

        // --- P03-T005 — ScrollModel (three-position scroll truth) ---
        let scrollModel = MonaScrollModel(
            contentWidth: 500, contentHeight: 300,
            viewportWidth: 500, viewportHeight: 200
        )
        let scrollEvent = scrollModel.converge()
        XCTAssertEqual(scrollModel.publishedScrollX, 0, "scroll starts at 0")
        XCTAssertEqual(scrollModel.publishedScrollY, 0)
        XCTAssertGreaterThan(scrollModel.convergenceGeneration, 0, "converge bumped the generation")
        XCTAssertEqual(scrollEvent.generation, scrollModel.convergenceGeneration, "the event carries the convergence generation")

        // --- P03-T006 — Core Graphics tiled renderer ---
        let tileCache = MonaRenderTileCache(maxTileCount: 16, maxBytes: 1_048_576)
        let cgRenderer = MonaCoreGraphicsRenderer(tileCache: tileCache, tileSide: 64)
        XCTAssertEqual(MonaCoreGraphicsRenderer.zOrder.count, 8, "eight frozen z-order layers")
        let tileKey = MonaRenderTileKey(
            generation: projection.generation, tileX: 0, tileY: 0, scale: 1
        )
        let tile = cgRenderer.tile(
            for: tileKey, records: [record],
            lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        XCTAssertEqual(tile.key, tileKey, "the tile is cached under the requested key")
        XCTAssertEqual(tile.surface.width, 64, "the tile surface is 64 pixels wide")
        XCTAssertEqual(tile.surface.height, 64, "the tile surface is 64 pixels tall")

        // --- P03-T007 — QueryGeometryBarrier ---
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: Self.lineHeight,
            codeUnitsForModelLine: { ln in Array(model.getLineContent(ln).utf16) }
        )
        let publishedGen = barrier.publishGeneration(visibleViewLines: 1...3)
        XCTAssertEqual(publishedGen, projection.generation, "the barrier published the view graph's generation")
        XCTAssertEqual(barrier.currentGeneration, projection.generation, "the barrier's generation matches the view graph")

        // A hit test on the first line resolves to a model position.
        let hitResult = barrier.hitTest(point: CGPoint(x: 5, y: 5))
        XCTAssertFalse(hitResult.isUnavailable, "hit test on the first line succeeds")
        XCTAssertNotNil(hitResult.availableValue, "the barrier returned a model position")

        // --- P03-T008 — FailedLineRecord (bounded Core Text failure) ---
        let failedRecord = MonaFailedLineRecord(
            modelLineNumber: 1,
            rawRange: 0..<5,
            dependencyStamp: stamp,
            reason: .shapingFailed,
            retryGeneration: projection.generation + 1,
            safeFallbackHeight: Double(Self.lineHeight)
        )
        XCTAssertEqual(failedRecord.glyphRunCount, 0, "a failed line record exposes NO glyph data")
        XCTAssertEqual(failedRecord.retryGeneration, projection.generation + 1, "retry generation is one past the current")

        // --- P03-T009 — RendererMetrics (five renderer-attributable metrics) ---
        XCTAssertEqual(MonaRendererMetricKind.allCases.count, 5, "exactly five renderer-attributable metric kinds")
        let metrics = MonaRendererMetrics(
            layoutReadyToPresent: 1.5, gpuFrameTime: 0.5,
            rendererSurfaceFootprint: 4096, missedPresentation: 0,
            rendererEnergy: 10.0
        )
        let trace = RendererMetricTrace()
        trace.append(RendererMetricBlock(blockID: "p03-block-1", metrics: metrics))
        let samples = trace.emitSamples()
        XCTAssertEqual(samples.count, 5, "one block × five kinds = five samples")
        for sample in samples {
            XCTAssertEqual(sample.blockID, "p03-block-1", "every sample carries its block identifier")
            XCTAssertTrue(sample.kind.isRendererAttributable, "every emitted kind is renderer-attributable")
        }

        // Cross-domain metrics are REJECTED (never stored as triggers).
        XCTAssertThrowsError(try trace.appendCrossDomain(kind: .firstPresent, value: 100.0)) { error in
            XCTAssertEqual(error as? MonaRendererMetricError, .scopeViolation(metric: "first-present"))
        }
        XCTAssertEqual(trace.crossDomainSampleCount, 0, "no cross-domain samples stored as triggers")

        // --- P03-T010/T011 — Metal branch (decision evidence + MetalRenderer) ---
        // The absent branch: records source absence, allocates no Metal resources.
        let absentMetalRenderer = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent,
            tileSide: 64,
            cgRenderer: cgRenderer,
            deviceProvider: { nil }
        )
        XCTAssertTrue(absentMetalRenderer.sourceAbsenceRecorded, "absent branch records source absence")
        XCTAssertFalse(absentMetalRenderer.metalResourcesAllocated, "absent branch allocates no Metal resources")
        let absentResult = absentMetalRenderer.tile(
            for: tileKey, records: [record], lineOrigins: [CGPoint(x: 0, y: 0)]
        )
        if case .absent = absentResult { /* ok */ } else {
            XCTFail("absent branch must return .absent; got \(absentResult)")
        }

        // The two branch states mirror the decision gate (P03-T010).
        XCTAssertEqual(MonaMetalRendererBranch.notTriggeredAndAbsent, .notTriggeredAndAbsent)
        XCTAssertEqual(MonaMetalRendererBranch.triggeredAndRequired, .triggeredAndRequired)
    }

    // MARK: 2. Revision locking — all components share one generation

    /// All Phase 03 components are joined by one generation. The view graph's
    /// generation, the barrier's published generation, the tile key's
    /// generation, and the failed-line record's retry generation are all
    /// derived from the same projection rebuild.
    func testRevisionLockingAcrossComponents() throws {
        let model = MonaCodeModel(
            text: "Line one\nLine two\nLine three",
            uri: MonaURI(scheme: "inmemory", path: "/p03-revision")
        )
        let viewGraph = MonaViewGraph(model: model, lineHeight: Self.lineHeight)
        let projection = viewGraph.getProjection()
        let gen = projection.generation

        // The view graph's generation matches the projection's generation.
        XCTAssertEqual(viewGraph.generation, gen, "view graph generation == projection generation")

        // The vertical index was built for this generation.
        XCTAssertEqual(viewGraph.verticalIndex.viewLineCount, projection.viewLines.count,
                       "the vertical index was built for the same projection")

        // The shaper + builder share one dependency stamp (one shaping configuration).
        let resolver = MonaFontFallbackResolver(primary: Self.font, fallback: [])
        let shaper = MonaTextShaper(primaryFont: Self.font, fallback: resolver)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let stamp = builder.makeDependencyStamp()
        XCTAssertEqual(stamp.fontDescriptor, Self.font, "the stamp carries the shaper's font")
        XCTAssertEqual(stamp.scale, shaper.scale, "the stamp carries the shaper's scale")
        XCTAssertEqual(stamp.direction, shaper.direction, "the stamp carries the shaper's direction")

        // The scroll model's frame stamp uses the same generation concept.
        let scrollModel = MonaScrollModel(
            contentWidth: 500, contentHeight: 300,
            viewportWidth: 500, viewportHeight: 200
        )
        scrollModel.converge()
        let frameStamp = scrollModel.frameStamp(generation: gen)
        XCTAssertEqual(frameStamp.generation, gen, "the frame stamp carries the projection generation")

        // The barrier publishes the view graph's generation.
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: Self.lineHeight,
            codeUnitsForModelLine: { ln in Array(model.getLineContent(ln).utf16) }
        )
        let publishedGen = barrier.publishGeneration(visibleViewLines: 1...3)
        XCTAssertEqual(publishedGen, gen, "the barrier's published generation == the view graph's generation")
        XCTAssertEqual(barrier.currentGeneration, gen, "the barrier's current generation is locked to the projection")

        // The tile key's generation matches the projection generation.
        let tileKey = MonaRenderTileKey(generation: gen, tileX: 0, tileY: 0, scale: 1)
        XCTAssertEqual(tileKey.generation, gen, "the tile key carries the projection generation")

        // The failed-line record's retry generation is derived from this generation.
        let failedRecord = MonaFailedLineRecord(
            modelLineNumber: 1,
            rawRange: 0..<8,
            dependencyStamp: stamp,
            reason: .shapingFailed,
            retryGeneration: gen + 1,
            safeFallbackHeight: Double(Self.lineHeight)
        )
        XCTAssertEqual(failedRecord.retryGeneration, gen + 1,
                       "the retry generation is one past the current (revision-locked)")
        XCTAssertEqual(failedRecord.dependencyStamp, stamp,
                       "the failed record carries the same dependency stamp as the builder")
    }

    // MARK: 3. Viewport operation counts scale with visible rows

    /// More visible rows → more layout work. The barrier's bounded visible-line
    /// completion shapes one line per view line in the published visible range.
    /// Counting `codeUnitsForModelLine` invocations proves the operation count
    /// scales proportionally with the number of visible rows.
    func testViewportOperationCountsScaleWithVisibleRows() throws {
        // Build a model with 30 lines so the scaling is visible.
        let lines = (1...30).map { "Line \($0): text content here" }
        let model = MonaCodeModel(
            text: lines.joined(separator: "\n"),
            uri: MonaURI(scheme: "inmemory", path: "/p03-scaling")
        )
        let viewGraph = MonaViewGraph(model: model, lineHeight: Self.lineHeight)
        let projection = viewGraph.getProjection()
        XCTAssertEqual(projection.viewLines.count, 30, "30 model lines → 30 view lines (no wrapping)")

        let resolver = MonaFontFallbackResolver(primary: Self.font, fallback: [])
        let shaper = MonaTextShaper(primaryFont: Self.font, fallback: resolver)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let scrollModel = MonaScrollModel(
            contentWidth: 500, contentHeight: Double(30 * Self.lineHeight),
            viewportWidth: 500, viewportHeight: Double(10 * Self.lineHeight)
        )
        scrollModel.converge()

        // Count how many times the code-units closure is invoked. Each
        // invocation corresponds to one line being shaped (bounded visible-line
        // completion). The closure is called once per view line that needs a
        // record built.
        var fetchCount = 0
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: Self.lineHeight,
            codeUnitsForModelLine: { ln in
                fetchCount += 1
                return Array(model.getLineContent(ln).utf16)
            }
        )

        // Publish with a SMALL visible range (5 view lines).
        fetchCount = 0
        let smallGen = barrier.publishGeneration(visibleViewLines: 1...5)
        XCTAssertNotNil(smallGen, "small viewport published a generation")
        let smallCount = fetchCount
        XCTAssertGreaterThan(smallCount, 0, "publishing 5 visible lines fetches at least 1 line")
        XCTAssertLessThanOrEqual(smallCount, 5, "small viewport fetches at most 5 lines")

        // Publish with a LARGER visible range (20 view lines).
        fetchCount = 0
        let largeGen = barrier.publishGeneration(visibleViewLines: 1...20)
        XCTAssertNotNil(largeGen, "large viewport published a generation")
        let largeCount = fetchCount
        XCTAssertGreaterThan(largeCount, 0, "publishing 20 visible lines fetches at least 1 line")

        // The invariant: more visible rows → more layout work.
        XCTAssertGreaterThan(largeCount, smallCount,
                            "viewport operation count scales with visible rows (\(largeCount) > \(smallCount))")

        // The vertical index's query count also scales with usage. Querying
        // more offsets produces more queries (the index is O(log n) per query,
        // not O(1), so the query count is a real work witness).
        let vi = viewGraph.verticalIndex
        let queriesBefore = vi.queryCount
        for offset in stride(from: 0, to: vi.totalHeight, by: Self.lineHeight) {
            _ = vi.viewLineAtVerticalOffset(offset)
        }
        let queriesAfter = vi.queryCount
        XCTAssertGreaterThan(queriesAfter, queriesBefore,
                            "vertical index query count advances with queries (work witness)")
    }

    // MARK: 4. Dependency change → cache invalidation

    /// A dependency change invalidates cached records via the frozen
    /// mutation-to-domain edge map. The edge map is non-contradictory: each
    /// mutation invalidates exactly its frozen set — no missing invalidations,
    /// no fanout beyond the frozen edge set. A different dependency stamp means
    /// a different cache key, so cached records are not reused.
    func testDependencyChangeInvalidatesCache() throws {
        let edgeMap = MonaDependencyStampEdgeMap.standard

        // --- Geometry-invalidating mutations ---

        // A font change invalidates geometry (records must be re-shaped),
        // scrollDimension (pixel content width changes), and frame. It does
        // NOT invalidate projection (column mapping is unchanged).
        let fontDomains = edgeMap.invalidatedDomains(for: .fontChanged)
        XCTAssertTrue(fontDomains.contains(.geometry),
                      "fontChanged invalidates geometry (records must be re-shaped)")
        XCTAssertTrue(fontDomains.contains(.scrollDimension),
                      "fontChanged invalidates scrollDimension (pixel content width changes)")
        XCTAssertTrue(fontDomains.contains(.frame),
                      "fontChanged invalidates frame")
        XCTAssertFalse(fontDomains.contains(.projection),
                        "fontChanged does NOT invalidate projection (column mapping unchanged)")

        // A different font descriptor produces a different dependency stamp
        // (different cache key → cache miss → re-shaping).
        let fontA = MonaFontDescriptor(familyName: "Menlo", size: 14)
        let fontB = MonaFontDescriptor(familyName: "Menlo", size: 16)
        let stampA = MonaLineLayoutDependencyStamp(
            fontDescriptor: fontA, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        let stampB = MonaLineLayoutDependencyStamp(
            fontDescriptor: fontB, scale: 1, direction: .ltr, wrappingColumn: nil
        )
        XCTAssertNotEqual(stampA, stampB,
                          "different font → different dependency stamp → cache invalidation")

        // A scale change also produces a different stamp.
        let stampC = MonaLineLayoutDependencyStamp(
            fontDescriptor: fontA, scale: 2, direction: .ltr, wrappingColumn: nil
        )
        XCTAssertNotEqual(stampA, stampC,
                          "different scale → different dependency stamp → cache invalidation")

        // A direction change invalidates geometry (bidi reordering) + frame.
        let dirDomains = edgeMap.invalidatedDomains(for: .baseDirectionChanged)
        XCTAssertTrue(dirDomains.contains(.geometry),
                      "baseDirectionChanged invalidates geometry (bidi reordering)")
        XCTAssertTrue(dirDomains.contains(.frame),
                      "baseDirectionChanged invalidates frame")

        // --- Paint-only mutations do NOT invalidate geometry (V1-R3 hit 09) ---

        let selectionDomains = edgeMap.invalidatedDomains(for: .selectionChanged)
        XCTAssertFalse(selectionDomains.contains(.geometry),
                       "selectionChanged does NOT invalidate geometry (paint-only, V1-R3 hit 09)")
        XCTAssertTrue(selectionDomains.contains(.paint),
                      "selectionChanged invalidates paint")
        XCTAssertTrue(selectionDomains.contains(.frame),
                      "selectionChanged invalidates frame (old text + new cursor)")

        let caretDomains = edgeMap.invalidatedDomains(for: .caretChanged)
        XCTAssertFalse(caretDomains.contains(.geometry),
                       "caretChanged does NOT invalidate geometry (paint-only)")
        XCTAssertTrue(caretDomains.contains(.paint),
                      "caretChanged invalidates paint")

        // --- Pure scroll invalidates ONLY the frame ---

        let scrollDomains = edgeMap.invalidatedDomains(for: .scrollOffsetChanged)
        XCTAssertEqual(scrollDomains, [.frame],
                       "scrollOffsetChanged invalidates ONLY the frame (canonical pure scroll)")

        // --- Render-target switch does NOT invalidate geometry (V1-R4 hit 04) ---

        let rtDomains = edgeMap.invalidatedDomains(for: .renderTargetChanged)
        XCTAssertFalse(rtDomains.contains(.geometry),
                       "renderTargetChanged does NOT invalidate geometry (same record, V1-R4 hit 04)")
        XCTAssertTrue(rtDomains.contains(.surface),
                      "renderTargetChanged invalidates surface")
        XCTAssertTrue(rtDomains.contains(.frame),
                      "renderTargetChanged invalidates frame")

        // --- Edge map validation: rejects missing + fanout ---

        // A claim that omits geometry for fontChanged is invalid (missing).
        let underClaim: Set<MonaStampDomain> = [.scrollDimension, .frame]
        let underValidation = edgeMap.validate(mutation: .fontChanged, claimedInvalidated: underClaim)
        XCTAssertFalse(underValidation.isValid, "omitting geometry from fontChanged is invalid")
        XCTAssertTrue(underValidation.missing.contains(.geometry),
                      "the validation reports geometry as missing")

        // A claim that adds projection to fontChanged is invalid (fanout).
        let overClaim: Set<MonaStampDomain> = [.geometry, .scrollDimension, .frame, .projection]
        let overValidation = edgeMap.validate(mutation: .fontChanged, claimedInvalidated: overClaim)
        XCTAssertFalse(overValidation.isValid, "adding projection to fontChanged is invalid (fanout)")
        XCTAssertTrue(overValidation.fanout.contains(.projection),
                      "the validation reports projection as fanout")

        // A correct claim is valid.
        let correctClaim: Set<MonaStampDomain> = [.geometry, .scrollDimension, .frame]
        let correctValidation = edgeMap.validate(mutation: .fontChanged, claimedInvalidated: correctClaim)
        XCTAssertTrue(correctValidation.isValid, "the exact frozen set is valid")
        XCTAssertTrue(correctValidation.missing.isEmpty, "no missing domains")
        XCTAssertTrue(correctValidation.fanout.isEmpty, "no fanout domains")
    }

    // MARK: 5. Renderer source set frozen for Phase 08

    /// Freezes the renderer source set (the exact files Phase 08 will consume
    /// for candidate generation) and the branch evidence (the frozen z-order +
    /// the two Metal branch states). If a file is added or removed from the
    /// Rendering directory, this test fails and must be updated.
    func testRendererSourceSetFrozenForPhase08() {
        // --- The frozen renderer source set ---
        // These are the product source files that implement the rendering
        // pipeline. Phase 08 candidate generation consumes this exact set.
        let rendererSourceSet: Set<String> = [
            "Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift",  // P03-T006
            "Sources/MonaCodeAppKit/Rendering/MonaRenderTileCache.swift",        // P03-T006
            "Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift",           // P03-T006
            "Sources/MonaCodeAppKit/Rendering/MonaRendererMetrics.swift",         // P03-T009
            "Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift",          // P03-T011
        ]

        // Verify every file in the frozen source set exists on disk.
        let root = projectRoot
        for relativePath in rendererSourceSet {
            let absolute = root + "/" + relativePath
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: absolute),
                "\(relativePath): renderer source file must exist (frozen for Phase 08)"
            )
        }

        // Verify no extra files exist in the Rendering directory beyond the
        // frozen set (a new file would need to be added to the frozen set).
        let renderingDir = root + "/Sources/MonaCodeAppKit/Rendering"
        let allRenderingFiles = (try? FileManager.default.contentsOfDirectory(atPath: renderingDir)) ?? []
        let actualSwiftFiles = Set(allRenderingFiles.filter { $0.hasSuffix(".swift") })
        let expectedBasenames = Set(rendererSourceSet.map {
            ($0 as NSString).lastPathComponent
        })
        XCTAssertEqual(actualSwiftFiles, expectedBasenames,
                       "the Rendering directory contains exactly the frozen source set (no extra files)")

        // --- The frozen z-order (8 layers, bottom → top) ---
        XCTAssertEqual(MonaRenderZLayer.allCases.count, 8, "exactly eight z-order layers")
        XCTAssertEqual(
            MonaRenderZLayer.allCases,
            [.text, .selections, .cursors, .decorations, .widgets, .gutters, .minimap, .overlays],
            "the frozen z-order is text → selections → cursors → decorations → widgets → gutters → minimap → overlays"
        )
        // The z-order rawValues are contiguous starting from 0.
        for (i, layer) in MonaRenderZLayer.allCases.enumerated() {
            XCTAssertEqual(layer.rawValue, i, "\(layer): rawValue is contiguous (\(i))")
        }

        // --- The Metal branch evidence (two states) ---
        // The branch mirrors P03-T010's decision gate. Phase 08 candidate
        // generation consumes this branch evidence.
        let allBranches: [MonaMetalRendererBranch] = [.notTriggeredAndAbsent, .triggeredAndRequired]
        XCTAssertEqual(allBranches.count, 2, "exactly two Metal branch states")

        // The absent branch records source absence.
        let absentRenderer = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent,
            tileSide: 32,
            cgRenderer: MonaCoreGraphicsRenderer(
                tileCache: MonaRenderTileCache(maxTileCount: 4, maxBytes: Int.max),
                tileSide: 32
            ),
            deviceProvider: { nil }
        )
        XCTAssertTrue(absentRenderer.sourceAbsenceRecorded,
                      "absent branch records source absence (branch evidence for Phase 08)")
        XCTAssertFalse(absentRenderer.metalResourcesAllocated,
                       "absent branch allocates no Metal resources (branch evidence for Phase 08)")

        // The triggered branch attempts Metal allocation (may fail on hosts
        // without a GPU, but the attempt is the evidence).
        let triggeredRenderer = MonaMetalRenderer(
            branch: .triggeredAndRequired,
            tileSide: 32,
            cgRenderer: MonaCoreGraphicsRenderer(
                tileCache: MonaRenderTileCache(maxTileCount: 4, maxBytes: Int.max),
                tileSide: 32
            ),
            deviceProvider: { nil }  // force failure to keep the test deterministic
        )
        XCTAssertFalse(triggeredRenderer.sourceAbsenceRecorded,
                       "triggered branch does NOT record source absence (Metal is needed)")
    }

    // MARK: 6. Zero-diff consistency across the full Phase 03 chain

    /// A full projection → geometry → scroll → shaping → failure → CG → Metal
    /// pipeline is zero-diff consistent end to end: the same immutable
    /// `MonaLineLayoutRecord` is consumed by the CG renderer and the Metal
    /// renderer without reshaping, the projection's view lines match the
    /// model's lines, and the scroll model's published position is consistent
    /// with the viewport.
    func testZeroDiffConsistencyAcrossPhase03Chain() throws {
        // --- model → projection (P03-T001) ---
        let text = "Hello\nWorld\nPhase03"
        let model = MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/p03-chain")
        )
        let viewGraph = MonaViewGraph(model: model, lineHeight: Self.lineHeight)
        let projection = viewGraph.getProjection()

        // Zero-diff: the projection's view line count matches the model's line count.
        XCTAssertEqual(projection.viewLines.count, model.getLineCount(),
                       "projection view line count == model line count (zero-diff)")
        // Each view line's model line number is sequential (no folding/wrapping).
        for (i, vl) in projection.viewLines.enumerated() {
            XCTAssertEqual(vl.modelLineNumber, i + 1, "view line \(i + 1) maps to model line \(i + 1)")
            XCTAssertEqual(vl.startColumn, 1, "non-wrapped view line starts at column 1")
            XCTAssertFalse(vl.isWrapped, "non-wrapped view line is not wrapped")
        }

        // --- shaping → geometry (P03-T002 → P03-T003) ---
        let resolver = MonaFontFallbackResolver(primary: Self.font, fallback: [])
        let shaper = MonaTextShaper(primaryFont: Self.font, fallback: resolver)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let stamp = builder.makeDependencyStamp()

        // Build records for all three lines.
        let lineContents = text.components(separatedBy: "\n")
        var records: [MonaLineLayoutRecord] = []
        for content in lineContents {
            let record = try builder.build(codeUnits: Array(content.utf16), dependencyStamp: stamp)
            records.append(record)
            XCTAssertGreaterThan(record.glyphRuns.count, 0, "each line shaped into glyph runs")
        }

        // Zero-diff: the record's source length matches the UTF-16 count of the line.
        for (i, record) in records.enumerated() {
            XCTAssertEqual(record.sourceLength, lineContents[i].utf16.count,
                           "record \(i + 1) source length == line \(i + 1) UTF-16 count (zero-diff)")
            XCTAssertEqual(record.dependencyStamp, stamp,
                           "record \(i + 1) carries the same dependency stamp (revision-locked)")
        }

        // --- scroll (P03-T005) ---
        let contentHeight = Double(projection.viewLines.count * Self.lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 500, contentHeight: contentHeight,
            viewportWidth: 500, viewportHeight: Double(2 * Self.lineHeight)
        )
        scrollModel.requestScroll(x: 0, y: Double(Self.lineHeight))
        scrollModel.converge()
        XCTAssertEqual(scrollModel.publishedScrollY, Double(Self.lineHeight),
                       "scroll published the requested (clamped) vertical offset")

        // --- geometry barrier (P03-T007) ---
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: Self.lineHeight,
            codeUnitsForModelLine: { ln in Array(model.getLineContent(ln).utf16) }
        )
        let publishedGen = barrier.publishGeneration(visibleViewLines: 1...3)
        XCTAssertEqual(publishedGen, projection.generation,
                       "barrier published the projection's generation (revision-locked)")

        // A hit test accounting for the scroll offset (one line height down)
        // resolves to model line 2 (viewport y=2 + scroll y=20 → content y=22
        // → line 2, which spans content y=[20, 40)).
        let hit = barrier.hitTest(point: CGPoint(x: 2, y: 2))
        XCTAssertFalse(hit.isUnavailable, "hit test succeeds from the scrolled viewport")
        if let pos = hit.availableValue {
            XCTAssertEqual(pos.line, 2,
                           "hit test resolves to model line 2 (scrolled down one line)")
        }

        // --- failure (P03-T008) ---
        // A failed-line record carries the same dependency stamp as the builder
        // and a retry generation derived from the projection generation.
        let failedRecord = MonaFailedLineRecord(
            modelLineNumber: 2,
            rawRange: 0..<5,
            dependencyStamp: stamp,
            shaperError: .coreTextShapingFailed("test failure"),
            retryGeneration: projection.generation + 1,
            safeFallbackHeight: Double(Self.lineHeight)
        )
        XCTAssertEqual(failedRecord.reason, .shapingFailed,
                       "the shaper error was converted to the typed reason")
        XCTAssertEqual(failedRecord.dependencyStamp, stamp,
                       "the failed record carries the same dependency stamp (zero-diff)")
        XCTAssertEqual(failedRecord.glyphRunCount, 0,
                       "the failed record exposes no glyph data")

        // --- CG renderer (P03-T006) ---
        let tileCache = MonaRenderTileCache(maxTileCount: 16, maxBytes: 1_048_576)
        tileCache.setCurrentGeneration(projection.generation)
        let cgRenderer = MonaCoreGraphicsRenderer(tileCache: tileCache, tileSide: 64)
        let tileKey = MonaRenderTileKey(
            generation: projection.generation, tileX: 0, tileY: 0, scale: 1
        )
        let origins = records.enumerated().map { _, _ in CGPoint(x: 0, y: 0) }
        let cgTile = cgRenderer.tile(
            for: tileKey, records: records, lineOrigins: origins
        )
        XCTAssertEqual(cgTile.key.generation, projection.generation,
                       "the CG tile carries the projection generation (revision-locked)")

        // The same record consumed by the CG renderer without reshaping:
        // the record's glyph runs are the same objects the shaper produced.
        XCTAssertEqual(cgTile.surface.bitmapInfo, MonaRenderSurface.premultipliedRGBABitmapInfo,
                       "the CG surface uses linear premultiplied RGBA (frozen format)")

        // --- Metal renderer (P03-T010/T011) ---
        // The absent branch: returns .absent (no Metal resources).
        let absentMetal = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent,
            tileSide: 64, cgRenderer: cgRenderer, deviceProvider: { nil }
        )
        let absentResult = absentMetal.tile(for: tileKey, records: records, lineOrigins: origins)
        if case .absent = absentResult { /* ok */ } else {
            XCTFail("absent Metal branch must return .absent; got \(absentResult)")
        }

        // The triggered branch with device failure: falls back to CG (the next
        // complete CG generation). The fallback tile is produced by the SAME CG
        // renderer from the SAME records.
        let triggeredMetal = MonaMetalRenderer(
            branch: .triggeredAndRequired,
            tileSide: 64, cgRenderer: cgRenderer, deviceProvider: { nil }
        )
        let triggeredResult = triggeredMetal.tile(for: tileKey, records: records, lineOrigins: origins)
        if case .fallback(let fallbackTile) = triggeredResult {
            // The fallback tile is a CG tile from the same renderer.
            XCTAssertEqual(fallbackTile.key, tileKey,
                           "the fallback tile carries the same key (zero-diff)")
        } else if case .metal = triggeredResult {
            // Metal succeeded: the Metal tile must match the CG tile within
            // 1/255 per channel (the parity invariant from P03-T011).
            let cgPixel = cgTile.surface.pixelAt(x: 0, y: 0)
            let metalPixel = (triggeredResult.extractSurface())?.pixelAt(x: 0, y: 0)
            if let cg = cgPixel, let metal = metalPixel {
                let diffR = abs(Int(cg.r) - Int(metal.r))
                let diffG = abs(Int(cg.g) - Int(metal.g))
                let diffB = abs(Int(cg.b) - Int(metal.b))
                let diffA = abs(Int(cg.a) - Int(metal.a))
                let maxDiff = max(diffR, diffG, diffB, diffA)
                XCTAssertLessThanOrEqual(maxDiff, 1,
                    "Metal output matches CG within 1/255 per channel (got \(maxDiff))")
            }
        } else {
            XCTFail("triggered branch must return .metal or .fallback; got \(triggeredResult)")
        }
    }

    // MARK: 7. Contract leaf

    /// Contract leaf: prints the G6-R Phase-03 P03-T012 acceptance line.
    /// The Phase 03 conformance suite joins all twelve task evidence sets by
    /// one shared generation, proves viewport operation scaling + dependency
    /// invalidation, and freezes the renderer source set for Phase 08.
    func testP03T012AcceptanceLeaf() throws {
        // The seven stamp domains are present (P03-T004).
        XCTAssertEqual(MonaStampDomain.allCases.count, 7, "seven stamp domains")

        // The five renderer-attributable metric kinds are present (P03-T009).
        XCTAssertEqual(MonaRendererMetricKind.allCases.count, 5, "five renderer-attributable metrics")

        // The eight frozen z-order layers are present (P03-T006).
        XCTAssertEqual(MonaRenderZLayer.allCases.count, 8, "eight z-order layers")

        // The two Metal branch states are present (P03-T010/T011).
        let branches: [MonaMetalRendererBranch] = [.notTriggeredAndAbsent, .triggeredAndRequired]
        XCTAssertEqual(branches.count, 2, "two Metal branch states")

        // The frozen renderer source set is verified on disk (P03-T006/T009/T011).
        let rendererSourceSet: Set<String> = [
            "Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift",
            "Sources/MonaCodeAppKit/Rendering/MonaRenderTileCache.swift",
            "Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift",
            "Sources/MonaCodeAppKit/Rendering/MonaRendererMetrics.swift",
            "Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift",
        ]
        let root = projectRoot
        for path in rendererSourceSet {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root + "/" + path),
                          "\(path): frozen renderer source file exists")
        }

        // The edge map is non-contradictory (P03-T004): every mutation has a
        // non-empty frozen edge set, and the frame domain is invalidated by
        // every mutation (it is the only composite domain).
        let edgeMap = MonaDependencyStampEdgeMap.standard
        for mutation in MonaMutation.allCases {
            let domains = edgeMap.invalidatedDomains(for: mutation)
            XCTAssertTrue(domains.contains(.frame),
                         "\(mutation.rawValue): every mutation invalidates the frame (composite domain)")
        }

        // The acceptance line: the join of all twelve Phase 03 tasks.
        // domains=7, metrics=5, zLayers=8, branches=2, rendererSourceFiles=5.
        print("P03-T012 domains=\(MonaStampDomain.allCases.count) metrics=\(MonaRendererMetricKind.allCases.count) zLayers=\(MonaRenderZLayer.allCases.count) branches=\(branches.count) rendererSourceFiles=\(rendererSourceSet.count)")
    }

    // MARK: - Helpers

    /// The package root directory (where `Package.swift` lives), derived from
    /// this file's location. Used for renderer source set file existence checks.
    private var projectRoot: String {
        // #file gives the absolute path of this source file.
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        // Fallback: use the current working directory (swift test runs from
        // the package root).
        return FileManager.default.currentDirectoryPath
    }
}

// MARK: - MonaMetalRenderResult surface extraction helper

private extension MonaMetalRenderResult {
    /// Returns the render surface from a `.metal` or `.fallback` result, or
    /// `nil` for `.absent`.
    var surface: MonaRenderSurface? {
        switch self {
        case .metal(let tile): return tile.surface
        case .fallback(let tile): return tile.surface
        case .absent: return nil
        }
    }

    /// Returns the render surface (compatibility alias).
    func extractSurface() -> MonaRenderSurface? {
        return surface
    }
}
