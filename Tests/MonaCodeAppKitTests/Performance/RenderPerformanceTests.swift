// RenderPerformanceTests.swift
//
// Task 13 — Performance gates R01-R05 (spec §4.3, the LAST task in the
// MonaCode driving-layer SDD).
//
// These benchmarks exercise `cgRenderer.tile(for:records:lineOrigins:layerInputs:)`
// (MonaCoreGraphicsRenderer.swift:137) + `barrier.publishGeneration(visibleViewLines:)`
// (MonaQueryGeometryBarrier.swift:271) DIRECTLY — i.e. the CPU bitmap work
// with no GUI context, no NSGraphicsContext, and no window. They measure the
// renderer+barrier cost in isolation, which is the upper bound on what
// `drawRect` would pay per frame.
//
// Method = ContinuousClock + 2×30-run sets + 3-run warmup (discarded) +
// CV<0.5 (stability) + self-consistency<0.5 (|M0-M1|/max), matching
// PerformanceBenchmarksTests.runBenchmark
// (Tests/MonaCodeTests/Performance/PerformanceBenchmarksTests.swift:77-129).
//
// Frame deadline: `1000.0 / 60.0` = 16.6̄ms, the same formula as
// `DisplayModeEnforcer.deadline(for:.hz60)` (Tests/BenchmarkHarness/
// DisplayModeEnforcer.swift:152-156). API drift: `DisplayModeEnforcer` lives
// in the `benchmark-harness` target, which is NOT a dependency of
// `MonaCodeAppKitTests` (Package.swift:91 deps = MonaCodeAppKit + MonaCodeSwiftUI).
// Replicating the value here per the spec's stated formula avoids modifying
// Package.swift (global constraint: only create the new test file).

import XCTest
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit

final class RenderPerformanceTests: XCTestCase {

    // MARK: - Constants

    /// 60Hz frame deadline in ms (DisplayModeEnforcer.deadline(for:.hz60) = 1000/hz).
    /// 1000.0 / 60.0 = 16.6666̄ms. The hard upper bound for one frame of work.
    private static let frameDeadline60Hz: Double = 1000.0 / 60.0

    /// First-paint (cold attach→first frame) deadline in ms (spec §4.3 R03).
    private static let firstPaintDeadlineMs: Double = 100.0

    /// Square tile side in device pixels (spec §4.3: 256×256 tile).
    private static let tileSide: Int = 256

    /// Per-view-line pixel height for 12pt Menlo (ascent+descent+leading ≈ 16).
    /// Used to stack line origins and to compute the visible view-line band.
    private static let lineHeight: Int = 16

    /// Viewport tile count for the scroll benchmarks (R02/R04). A real
    /// `drawRect` paints the whole visible viewport, not one tile; 4 tiles
    /// (1024px) is a representative viewport. Steady-state scroll: each frame
    /// advances by 1 tile-row → 1 new tile (cache miss) + 3 reused (cache hits).
    private static let viewportTileCount: Int = 4

    /// Sustained-scroll warmup in tile-rows (spec §4.3 R02: "scroll 1000
    /// tile-rows"). This pre-warmup is discarded; it brings the tile cache to
    /// steady state before the 60 measured frames sample the per-frame cost.
    private static let scrollWarmupTileRows: Int = 1000

    // MARK: - Measurement helpers (mirror PerformanceBenchmarksTests:31-129)

    /// Converts a `Duration` to milliseconds as `Double`.
    private func durationToMs(_ d: Duration) -> Double {
        let (seconds, attoseconds) = d.components
        return Double(seconds) * 1000.0 + Double(attoseconds) * 1e-15
    }

    /// Runs `body` `count` times, returning per-run timings in milliseconds.
    /// A small warmup set (3 runs) is discarded before measurement to avoid
    /// first-touch allocation noise.
    private func measureRuns(_ count: Int, warmup: Int = 3, _ body: () -> Void) -> [Double] {
        let clock = ContinuousClock()
        for _ in 0..<warmup { body() }
        var timings: [Double] = []
        timings.reserveCapacity(count)
        for _ in 0..<count {
            let start = clock.now
            body()
            let elapsed = start.duration(to: clock.now)
            timings.append(durationToMs(elapsed))
        }
        return timings
    }

    /// Computes mean, stddev (population), min, max of the timings.
    private func stats(_ timings: [Double]) -> (mean: Double, stddev: Double, min: Double, max: Double) {
        guard !timings.isEmpty else { return (0, 0, 0, 0) }
        let n = Double(timings.count)
        let mean = timings.reduce(0.0, +) / n
        let variance = timings.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / n
        let stddev = variance.squareRoot()
        let mn = timings.min() ?? 0.0
        let mx = timings.max() ?? 0.0
        return (mean, stddev, mn, mx)
    }

    /// Runs a benchmark with two 30-run sets (M0, M1), asserts the absolute
    /// threshold, stability (CV<0.5), and self-consistency (delta<0.5), prints
    /// a one-line summary, and returns the combined mean (ms) so callers can
    /// compute deltas between benchmarks (R04 vs R02).
    @discardableResult
    private func runBenchmark(
        name: String,
        threshold: Double,
        runsPerSet: Int = 30,
        body: () -> Void
    ) -> Double {
        let m0 = measureRuns(runsPerSet, body)
        let m1 = measureRuns(runsPerSet, body)

        let s0 = stats(m0)
        let s1 = stats(m1)

        let combined = m0 + m1
        let sc = stats(combined)

        let cv = sc.stddev / max(sc.mean, 1e-9)
        let stabilityPass = cv < 0.5

        let delta = abs(s0.mean - s1.mean) / max(s0.mean, s1.mean, 1e-9)
        let selfConsistencyPass = delta < 0.5

        let thresholdPass = sc.mean < threshold

        print(
            "BENCHMARK \(name) "
            + "mean=\(String(format: "%.3f", sc.mean))ms "
            + "stddev=\(String(format: "%.3f", sc.stddev))ms "
            + "min=\(String(format: "%.3f", sc.min))ms "
            + "max=\(String(format: "%.3f", sc.max))ms "
            + "M0=\(String(format: "%.3f", s0.mean))ms "
            + "M1=\(String(format: "%.3f", s1.mean))ms "
            + "CV=\(String(format: "%.3f", cv)) "
            + "selfcons=\(String(format: "%.3f", delta)) "
            + "threshold=\(String(format: "%.0f", threshold))ms "
            + "threshold=\(thresholdPass ? "PASS" : "FAIL") "
            + "stability=\(stabilityPass ? "PASS" : "FAIL") "
            + "self-consistency=\(selfConsistencyPass ? "PASS" : "FAIL")"
        )

        XCTAssertTrue(thresholdPass,
            "\(name): combined mean \(sc.mean)ms >= threshold \(threshold)ms")
        XCTAssertTrue(stabilityPass,
            "\(name): coefficient of variation \(cv) >= 0.5 (unstable)")
        XCTAssertTrue(selfConsistencyPass,
            "\(name): self-consistency delta \(delta) >= 0.5 (M0=\(s0.mean) vs M1=\(s1.mean))")
        return sc.mean
    }

    // MARK: - Text fixtures

    /// A ~1 MiB document split across ~50K lines (spec §4.3 R02/R03/R05
    /// fixture: "1MiB / 50K-line doc"). Returns the text and the view-line
    /// count (no folding ⇒ view-line count == model line count).
    private static func makeOneMiB50KLineDoc() -> (text: String, lineCount: Int) {
        // ~21 bytes/line × 50000 lines = ~1.05 MiB (≥ 1 MiB).
        let line = "let xi = 0x1ABCDEF;\n"   // 20 chars + '\n' = 21
        let lineCount = 50_000
        let text = String(repeating: line, count: lineCount)
        return (text, lineCount)
    }

    /// A single 1 KiB line (1024 chars) for the R01 fixture ("1KiB line").
    private static func make1KiBLine() -> String {
        return String(repeating: "M", count: 1024)
    }

    // MARK: - Component construction (mirror DrivingLayerTests.makeBarrier)

    /// Menlo 12pt — the default macOS monospace face, always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// Builds a `MonaLineLayoutBuilder` over a Menlo shaper (no fallback).
    private func makeBuilder() -> MonaLineLayoutBuilder {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
        return MonaLineLayoutBuilder(shaper: shaper)
    }

    /// Builds a barrier over a real model + view graph + scroll model, mirroring
    /// the construction in `DrivingLayerTests.makeBarrier` and
    /// `MonaQueryGeometryBarrierTests`. The scroll model starts at scroll 0.
    private func makeBarrier(text: String, lineHeight: Int) -> MonaQueryGeometryBarrier {
        let model = MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/perf"))
        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        return makeBarrier(model: model, lineHeight: lineHeight, lineCount: lineCount)
    }

    /// Builds a barrier reusing a pre-built model (so model construction — an
    /// attach cost `drawRect` never pays — stays out of the timed body for
    /// R03/R05). Constructs a FRESH view graph (dirty), so the first
    /// `publishGeneration` pays the cold projection rebuild inside
    /// `getProjection()` (the first-frame cost `drawRect` pays on attach).
    private func makeBarrier(
        model: MonaCodeModel, lineHeight: Int, lineCount: Int
    ) -> MonaQueryGeometryBarrier {
        let viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)
        // Content height = lineCount × lineHeight (uniform lines). Content width
        // is set wide so no horizontal clamping interferes with the visible band.
        let contentHeight = Double(lineCount * lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: Double(Self.tileSide * Self.viewportTileCount),
            contentHeight: contentHeight,
            viewportWidth: Double(Self.tileSide),
            viewportHeight: Double(Self.tileSide * Self.viewportTileCount)
        )
        let builder = makeBuilder()
        let provider: (Int) -> [UInt16] = { Array(model.getLineContent($0).utf16) }
        return MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: provider
        )
    }

    /// Builds one `MonaLineLayoutRecord` from `text` via the owned shaper.
    /// Setup-time helper (not part of any timed body).
    private func makeRecord(text: String) throws -> MonaLineLayoutRecord {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        return try builder.build(codeUnits: Array(text.utf16), paintInputs: .plain, dependencyStamp: stamp)
    }

    // MARK: - Frame renderer (exercises barrier.publishGeneration + cgRenderer.tile)

    /// Renders one viewport frame (K tiles) for the scroll position
    /// `baseTileY` (in tile units). This is the per-frame work `drawRect` would
    /// pay: (1) `barrier.publishGeneration(visibleViewLines:)` re-builds the
    /// layout records for the visible band (shaping cost), and (2) `cgRenderer.tile`
    /// rasterizes each viewport tile (cache hit reuses pixels; cache miss
    /// rasterizes a fresh 256×256 bitmap).
    ///
    /// `phaseY` is the subpixel phase baked into every tile key. R02 passes 0
    /// (whole-pixel quantized scroll → stable keys → reused tiles are cache
    /// hits). R04 alternates `phaseY` between 0 and 1 across frames so that
    /// even tiles at a revisited `(tileX, tileY)` miss the cache (subpixel
    /// scroll forces re-rasterization) — the cache-miss penalty.
    @discardableResult
    private func renderViewportFrame(
        barrier: MonaQueryGeometryBarrier,
        renderer: MonaCoreGraphicsRenderer,
        baseTileY: Int,
        phaseY: Int,
        viewLineCount: Int
    ) -> [MonaRenderTile] {
        let tileSide = Self.tileSide
        let lineHeight = Self.lineHeight
        let bandHeight = tileSide * Self.viewportTileCount
        let scrollY = baseTileY * tileSide

        // Visible view-line band for this scroll position (1-based, closed).
        let firstVL = max(1, scrollY / lineHeight + 1)
        let lastVL = min(viewLineCount, (scrollY + bandHeight) / lineHeight + 1)
        guard firstVL <= lastVL else { return [] }

        // (1) Barrier: publish the generation + pre-build the visible records.
        //    publishGeneration re-reads the projection, captures the published
        //    scroll, RESETS the record cache, and shapes the visible band.
        _ = barrier.publishGeneration(visibleViewLines: firstVL...lastVL)
        guard let snap = barrier.snapshot(), !snap.records.isEmpty else { return [] }

        // Parallel arrays sorted by 1-based view-line number.
        let sortedKeys = snap.records.keys.sorted()
        let records: [MonaLineLayoutRecord] = sortedKeys.compactMap { snap.records[$0] }

        // (2) Renderer: paint each viewport tile. Per spec §8 fact #1
        //    (corrected): origin.y = (viewLine-1)*lineHeight - tileY*tileSide
        //    (tile-local CG y-up); origin.x = -tileX*tileSide (0 here).
        var tiles: [MonaRenderTile] = []
        tiles.reserveCapacity(Self.viewportTileCount)
        for offset in 0..<Self.viewportTileCount {
            let tileY = baseTileY + offset
            let origins: [CGPoint] = records.indices.map { i in
                let vl = sortedKeys[i]
                return CGPoint(x: 0, y: CGFloat((vl - 1) * lineHeight - tileY * tileSide))
            }
            let key = MonaRenderTileKey(
                generation: snap.generation,
                tileX: 0,
                tileY: tileY,
                scale: 1,
                subpixelPhaseX: 0,
                subpixelPhaseY: phaseY
            )
            let tile = renderer.tile(for: key, records: records, lineOrigins: origins)
            tiles.append(tile)
        }
        return tiles
    }

    // MARK: - R01 — Render frame time (one full visible-viewport paint)

    /// R01: render frame time for one full visible-viewport paint.
    /// Fixture: 256×256 tile, 60 lines of 12pt Menlo, 1KiB line.
    /// Threshold: <16.67ms (60Hz frame deadline).
    ///
    /// The 60-line/1KiB-line fixture is the *document*; the 256×256 tile shows
    /// the ~16 visible lines (the rest are CG-clipped). `drawRect` culls to the
    /// visible band, so the benchmark passes all 60 records to the renderer and
    /// lets CG clip the off-tile ones — measuring the one-tile paint cost with
    /// the fixture's stated 60 lines / 1KiB-line content.
    func testR01_RenderFrameTime() throws {
        let line = Self.make1KiBLine()
        // Build the 60 records once (setup; shaping is not part of the gate).
        let records: [MonaLineLayoutRecord] = try (0..<60).map { _ in try makeRecord(text: line) }
        // Origins: stack 60 lines at y = i * lineHeight (CG y-up; tile-local).
        let origins: [CGPoint] = (0..<60).map { CGPoint(x: 0, y: CGFloat($0) * CGFloat(Self.lineHeight)) }

        let cache = MonaRenderTileCache(maxTileCount: 64, maxBytes: 256 * 1024 * 1024)
        let renderer = MonaCoreGraphicsRenderer(tileCache: cache, tileSide: Self.tileSide)

        // Each run paints one 256×256 tile at (0,0) with all 60 records. A
        // fresh key per run (incrementing generation) forces a cache miss so
        // every measured run pays the full rasterization cost (the drawRect
        // upper bound for one tile).
        var gen = 0
        runBenchmark(name: "R01 render-frame", threshold: Self.frameDeadline60Hz) {
            gen += 1
            let key = MonaRenderTileKey(generation: gen, tileX: 0, tileY: 0, scale: 1)
            _ = renderer.tile(for: key, records: records, lineOrigins: origins)
        }
    }

    // MARK: - R02 — Scroll FPS (sustained scroll, cache steady-state)

    /// R02: sustained scroll FPS with the tile cache in steady state.
    /// Fixture: 1MiB / 50K-line doc; scroll 1000 tile-rows.
    /// Threshold: ≥60fps (mean frame <16.67ms) after warmup.
    ///
    /// Each frame advances the scroll by 1 tile-row and renders the 4-tile
    /// viewport. Steady state: 1 new tile (cache miss, rasterized) + 3 reused
    /// tiles (cache hits, dict lookup). The 1000-tile-row pre-warmup (discarded)
    /// brings the cache to steady state before the 60 measured frames sample the
    /// per-frame cost. The mean frame time is the drawRect upper bound per
    /// scroll frame.
    func testR02_ScrollFPS() {
        let doc = Self.makeOneMiB50KLineDoc()
        let barrier = makeBarrier(text: doc.text, lineHeight: Self.lineHeight)
        let cache = MonaRenderTileCache(maxTileCount: 64, maxBytes: 256 * 1024 * 1024)
        let renderer = MonaCoreGraphicsRenderer(tileCache: cache, tileSide: Self.tileSide)

        // Pre-warmup: sustained scroll to steady state (discarded).
        var baseTileY = 0
        for _ in 0..<Self.scrollWarmupTileRows {
            _ = renderViewportFrame(barrier: barrier, renderer: renderer,
                baseTileY: baseTileY, phaseY: 0, viewLineCount: doc.lineCount)
            baseTileY += 1
        }

        // Measure steady-state per-frame cost.
        runBenchmark(name: "R02 scroll-fps", threshold: Self.frameDeadline60Hz) {
            _ = renderViewportFrame(barrier: barrier, renderer: renderer,
                baseTileY: baseTileY, phaseY: 0, viewLineCount: doc.lineCount)
            baseTileY += 1
        }
    }

    // MARK: - R03 — First paint (cold attach→first frame)

    /// R03: first-paint time (cold attach→first frame).
    /// Fixture: fresh view + 1MiB model.
    /// Threshold: <100ms.
    ///
    /// Each measured run constructs a FRESH view graph + barrier over a
    /// pre-built 1MiB model (the model is the fixture; model construction is an
    /// attach cost `drawRect` never pays, so it stays out of the timed body),
    /// then publishes the first generation and rasterizes the 4-tile viewport.
    /// The first `publishGeneration` pays the cold projection rebuild (the
    /// first `getProjection()` over 50K lines, inside `publishGeneration`) plus
    /// the visible-band shaping — this is the first-frame cost `drawRect` pays
    /// on attach. The 3-run `measureRuns` warmup (discarded) stabilizes the
    /// process allocator/Core Text font cache; each measured run is still a
    /// cold first-paint of a fresh (dirty) view graph.
    func testR03_FirstPaint() throws {
        let doc = Self.makeOneMiB50KLineDoc()
        // Pre-build the 1MiB model once (attach fixture; not renderer+barrier work).
        let model = MonaCodeModel(text: doc.text, uri: MonaURI(scheme: "inmemory", path: "/perf-r03"))

        runBenchmark(name: "R03 first-paint", threshold: Self.firstPaintDeadlineMs) {
            // Cold attach: fresh view graph (dirty) + fresh barrier + fresh cache.
            // The first publishGeneration pays the cold projection rebuild over
            // 50K lines (inside getProjection), the visible-band shaping, then
            // rasterizes 4 cold-cache tiles — the first-frame cost drawRect pays.
            let barrier = makeBarrier(model: model, lineHeight: Self.lineHeight, lineCount: doc.lineCount)
            let cache = MonaRenderTileCache(maxTileCount: 64, maxBytes: 256 * 1024 * 1024)
            let renderer = MonaCoreGraphicsRenderer(tileCache: cache, tileSide: Self.tileSide)
            _ = renderViewportFrame(barrier: barrier, renderer: renderer,
                baseTileY: 0, phaseY: 0, viewLineCount: doc.lineCount)
        }
    }

    // MARK: - R04 — Subpixel-scroll repaint cost

    /// R04: subpixel-scroll repaint cost — quantifies the cache-miss penalty.
    /// Fixture: same as R02 but subpixel-delta scroll.
    /// Threshold: mean frame <16.67ms (subpixel repaint must still fit a frame);
    ///   the cache-miss penalty is reported as (R04 mean − R02 mean).
    ///
    /// Each frame advances the scroll by 1 tile-row (like R02) BUT bakes an
    /// alternating subpixel phase (`phaseY = counter % 2`) into every tile key.
    /// Even tiles at a revisited `(tileX, tileY)` miss the cache because the
    /// phase differs from the previous frame — so the 3 tiles R02 would reuse
    /// as cache hits are re-rasterized every frame. The delta vs R02 isolates
    /// the cost of the subpixel-induced cache misses (the cache-miss penalty).
    func testR04_SubpixelRepaintCost() {
        let doc = Self.makeOneMiB50KLineDoc()
        let barrier = makeBarrier(text: doc.text, lineHeight: Self.lineHeight)
        let cache = MonaRenderTileCache(maxTileCount: 64, maxBytes: 256 * 1024 * 1024)
        let renderer = MonaCoreGraphicsRenderer(tileCache: cache, tileSide: Self.tileSide)

        // Baseline (whole-pixel scroll, phase=0). R04 runs its own baseline so
        // it is self-contained when filtered in isolation (XCTest does not
        // guarantee cross-test ordering / shared state).
        var baseTileY = 0
        for _ in 0..<Self.scrollWarmupTileRows {
            _ = renderViewportFrame(barrier: barrier, renderer: renderer,
                baseTileY: baseTileY, phaseY: 0, viewLineCount: doc.lineCount)
            baseTileY += 1
        }
        let baselineMean = runBenchmark(
            name: "R04 baseline (whole-pixel)", threshold: Self.frameDeadline60Hz) {
            _ = renderViewportFrame(barrier: barrier, renderer: renderer,
                baseTileY: baseTileY, phaseY: 0, viewLineCount: doc.lineCount)
            baseTileY += 1
        }

        // Subpixel-delta scroll: alternating phase forces cache misses on the
        // 3 tiles R02 would have reused. Pre-warmup to repopulate the cache at
        // the alternating-phase rhythm, then measure.
        var subBaseTileY = 0
        var counter = 0
        for _ in 0..<Self.scrollWarmupTileRows {
            _ = renderViewportFrame(barrier: barrier, renderer: renderer,
                baseTileY: subBaseTileY, phaseY: counter % 2, viewLineCount: doc.lineCount)
            subBaseTileY += 1
            counter += 1
        }
        let subpixelMean = runBenchmark(
            name: "R04 subpixel-repaint", threshold: Self.frameDeadline60Hz) {
            _ = renderViewportFrame(barrier: barrier, renderer: renderer,
                baseTileY: subBaseTileY, phaseY: counter % 2, viewLineCount: doc.lineCount)
            subBaseTileY += 1
            counter += 1
        }

        let penalty = subpixelMean - baselineMean
        print(
            "BENCHMARK R04 cache-miss penalty: "
            + "subpixel=\(String(format: "%.3f", subpixelMean))ms "
            + "baseline=\(String(format: "%.3f", baselineMean))ms "
            + "delta=\(String(format: "%.3f", penalty))ms "
            + "(subpixel scroll forces re-rasterization of tiles R02 reuses)"
        )
        // The cache-miss penalty is the delta; it must be non-negative
        // (subpixel misses are at least as expensive as whole-pixel hits+misses)
        // and bounded (subpixel repaint must still fit one frame).
        XCTAssertGreaterThanOrEqual(penalty, 0.0,
            "R04: subpixel cache-miss penalty \(penalty)ms should be >= 0 (subpixel misses are at least as expensive as whole-pixel hits+misses)")
        XCTAssertLessThan(subpixelMean, Self.frameDeadline60Hz,
            "R04: subpixel repaint mean \(subpixelMean)ms >= frame deadline \(Self.frameDeadline60Hz)ms")
    }

    // MARK: - R05 — Content-change repaint

    /// R05: content-change repaint.
    /// Fixture: 1MiB doc; single 1-char edit→repaint.
    /// Threshold: <16.67ms.
    ///
    /// Measures the repaint cost (publishGeneration + render) after a 1-char
    /// edit. The edit itself (`applyEdits`, ~77ms on 1MiB — a model-mutation
    /// cost `drawRect` never pays) is applied once as the content-change
    /// trigger and is NOT in the timed body; the brief mandates measuring
    /// `cgRenderer.tile` + `barrier.publishGeneration` in isolation (the
    /// renderer+barrier cost, the upper bound on what drawRect pays).
    ///
    /// API drift / known gap: the production `MonaViewGraph` does NOT observe
    /// model content edits (no model-change→dirty wiring; content edits route
    /// through `observeContentChange` → `setNeedsDisplay` and composite against
    /// cached tiles on the SAME generation — a cache-hit, not a repaint). So
    /// that the benchmark measures the repaint cost a correct
    /// content-change→repaint pipeline would pay, each run forces a cache miss
    /// via `cache.invalidateAll()` before the render (the production pipeline
    /// would bump the generation on content change, producing a fresh tile key
    /// and the same cache-miss→re-rasterize outcome).
    func testR05_ContentChangeRepaint() {
        let doc = Self.makeOneMiB50KLineDoc()
        let model = MonaCodeModel(text: doc.text, uri: MonaURI(scheme: "inmemory", path: "/perf-r05"))
        let barrier = makeBarrier(model: model, lineHeight: Self.lineHeight, lineCount: doc.lineCount)
        let cache = MonaRenderTileCache(maxTileCount: 64, maxBytes: 256 * 1024 * 1024)
        let renderer = MonaCoreGraphicsRenderer(tileCache: cache, tileSide: Self.tileSide)

        // Seed: publish + render once so the barrier is attached and the
        // projection is built (the attach; not part of the repaint measurement).
        _ = renderViewportFrame(barrier: barrier, renderer: renderer,
            baseTileY: 0, phaseY: 0, viewLineCount: doc.lineCount)

        // Single 1-char edit (the content-change trigger; NOT timed —
        // applyEdits on 1MiB is ~77ms of model-mutation work drawRect never
        // pays, out of scope for this renderer+barrier gate).
        _ = model.applyEdits([MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        )])

        // Measure the repaint: invalidate the cache (forces the miss a
        // generation-bump would produce) + publishGeneration (re-shapes with
        // the edited content via the provider) + render 4 tiles (re-rasterize).
        runBenchmark(name: "R05 content-change-repaint", threshold: Self.frameDeadline60Hz) {
            cache.invalidateAll()
            _ = renderViewportFrame(barrier: barrier, renderer: renderer,
                baseTileY: 0, phaseY: 0, viewLineCount: doc.lineCount)
        }
    }
}
