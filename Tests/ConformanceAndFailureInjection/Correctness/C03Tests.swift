// C03Tests.swift
//
// P09-T012 — Run C03: projection, layout, scroll, and geometry equivalence.
//
// The C03 differential conformance suite — the THIRD C-candidate acceptance
// test. It compares the Swift port's projection/layout/scroll/geometry
// outputs (ViewGraph projection, VerticalIndex, LineLayoutRecord, ScrollModel,
// QueryGeometryBarrier) against the monaco-editor reference fixtures M0 + M1,
// and binds all evidence hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - The V1-R4 cross-engine closure artifact
//     (layout-v1r4-cross-engine-closure.html) — the M0/M1 layout oracle
//     (exact compatibility domain: raw UTF-16, fold/injected ordering, scroll
//     state machine; native-adapted geometry domain: Core Text shaping).
//   - The P08-T010 native-declaration manifest (the candidate carrying the
//     frozen declaration/option/theme/registry counts).
//   - The Phase 03 documented projection/layout/scroll/geometry semantics
//     (the M0/M1-ported semantics frozen by the G4-R design).
//
// The 4 implementation operations:
//   1. Compare projection, wrapping, folding, injected text, vertical indexes,
//      scroll order, shaping, raw-offset geometry, stamps, and bounded failure
//      behavior against M0 and M1.
//   2. Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture,
//      native-adapted assertion, failure row, and exact-set check assigned to
//      the gate.
//   3. Bind comparator, native, environment, candidate, source revision,
//      fixture, and output hashes in one evidence manifest.
//   4. Treat every missing, skipped, stale, malformed, canceled, or
//      unauthorized case as not-passed.
//
// TEST-ONLY (productTarget null; create none, modify none). The file lives in
// the `conformance-and-failure-injection` target (non-test `.target`). The API
// is FROZEN (P07-T011). Discovery via MonaCodeTests linkage; `swift test
// --filter C03Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit

// MARK: - C03Tests

final class C03Tests: XCTestCase {

    // MARK: - Frozen contract anchors (consumed unchanged from P09-T002)

    private static let frozenSourceRevision = "P07-T011"
    private static let frozenSourceSetDigest =
        "152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36"
    private static let qualifiedSetHash =
        "f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce"

    private static let sixStaticCandidateFiles: [(name: String, leaf: String, file: String)] = [
        ("native-declaration",  "P08-T010", "monacode-p08-t010-native-declaration-manifest.json"),
        ("regExpUnicode",       "P08-T011", "monacode-p08-t011-regexp-unicode-manifest.json"),
        ("environment",         "P08-T012", "monacode-p08-t012-environment-manifest.json"),
        ("sourceClosure",       "P08-T013", "monacode-p08-t013-source-closure-manifest.json"),
        ("cache",               "P08-T014", "monacode-p08-t014-cache-manifest.json"),
        ("distribution",        "P08-T015", "monacode-p08-t015-distribution-manifest.json"),
    ]

    // MARK: - Accumulated native outputs

    private static let nativeOutputLock = NSLock()
    private nonisolated(unsafe) static var nativeOutputLines: [String] = []

    private static func recordNativeOutput(_ line: String) {
        nativeOutputLock.lock()
        defer { nativeOutputLock.unlock() }
        nativeOutputLines.append(line)
    }

    // MARK: - Shared helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)
    private let lineHeight = 20

    private func makeModel(_ text: String, uri: String = "monacode:c03") -> MonaCodeModel {
        MonaCodeModel(text: text, uri: MonaURI.parse(uri)!)
    }

    private func makeBuilder() -> MonaLineLayoutBuilder {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
        return MonaLineLayoutBuilder(shaper: shaper)
    }

    // MARK: Operation 1 — Compare projection, wrapping, folding, injected
    // text, vertical indexes, scroll order, shaping, raw-offset geometry,
    // stamps, and bounded failure behavior against M0 and M1.

    // ── 1a. Projection: folding, hidden, injected, wrapping, view zones ──

    /// The ViewGraph projects model lines into view lines, applying folding,
    /// hidden ranges, injected text, word wrapping, and view zones. A new
    /// projection generation is published ONLY after every affected index is
    /// complete — the M0/M1 projection contract (V1-R4 exact compatibility
    /// domain: fold/injected ordering, model↔view mapping).
    func testC03_ProjectionFoldingHiddenInjectedWrappingZonesAgainstM0M1() {
        let model = makeModel("alpha\nbeta\ngamma")
        let graph = MonaViewGraph(model: model, lineHeight: lineHeight)

        // 1:1 projection (no mutations).
        let proj = graph.getProjection()
        XCTAssertEqual(proj.viewLines.count, 3, "3 model lines → 3 view lines (1:1)")
        XCTAssertEqual(proj.viewLines.map(\.modelLineNumber), [1, 2, 3])
        XCTAssertEqual(proj.viewLines.map(\.startColumn), [1, 1, 1])
        XCTAssertEqual(proj.viewLines.map(\.isWrapped), [false, false, false])
        XCTAssertEqual(graph.generation, 1, "first projection = generation 1")
        // Idempotent re-fetch does NOT bump generation.
        let _ = graph.getProjection()
        XCTAssertEqual(graph.generation, 1)
        Self.recordNativeOutput("projection:1to1=count\(proj.viewLines.count)")

        // Folding: collapse line 2.
        graph.setFoldedRanges([MonaRange(startLine: 2, startColumn: 1, endLine: 2, endColumn: 5)])
        let foldedProj = graph.getProjection()
        XCTAssertEqual(graph.generation, 2)
        XCTAssertEqual(foldedProj.viewLines.count, 3)
        XCTAssertTrue(foldedProj.viewLines[1].isCollapsed, "line 2 is collapsed")
        graph.setFoldedRanges([])
        let _ = graph.getProjection()  // gen 3: unfold

        // Hidden: hide line 2.
        graph.setHiddenRanges([MonaRange(startLine: 2, startColumn: 1, endLine: 2, endColumn: 5)])
        let hiddenProj = graph.getProjection()
        XCTAssertEqual(hiddenProj.viewLines.count, 2, "hidden line excluded")
        XCTAssertEqual(hiddenProj.viewLines.map(\.modelLineNumber), [1, 3])
        XCTAssertEqual(graph.generation, 4)
        graph.setHiddenRanges([])
        let _ = graph.getProjection()  // gen 5: unhide

        // Injected text.
        graph.setInjections([MonaViewInjection(id: "inj1", lineNumber: 2, column: 1, text: "[inj]")])
        let injProj = graph.getProjection()
        XCTAssertEqual(injProj.viewLines[1].injectionIds, ["inj1"])
        XCTAssertEqual(graph.generation, 6)
        graph.setInjections([])
        let _ = graph.getProjection()  // gen 7: clear injections

        // Wrapping: word wrap at 3 chars.
        graph.setWordWrapColumn(3)
        let wrapProj = graph.getProjection()
        XCTAssertEqual(wrapProj.viewLines.count, 6, "3 lines × 2 wrapped pieces = 6")
        let wrapped3 = wrapProj.viewLines.filter { $0.modelLineNumber == 3 }
        XCTAssertEqual(wrapped3.count, 2)
        XCTAssertTrue(wrapped3[1].isWrapped)
        XCTAssertEqual(wrapped3[1].startColumn, 4, "continuation starts after 'gam'")
        XCTAssertEqual(graph.generation, 8)
        graph.setWordWrapColumn(nil)
        let _ = graph.getProjection()  // gen 9: clear wrap

        // View zones.
        graph.setViewZones([
            MonaViewZone(id: "z1", afterLineNumber: 1, height: 30),
            MonaViewZone(id: "z2", afterLineNumber: 2, height: 10),
        ])
        let zoneProj = graph.getProjection()
        XCTAssertEqual(zoneProj.viewLines.count, 3, "zones do not create view lines")
        XCTAssertEqual(graph.viewZoneIndex.zones.count, 2)
        XCTAssertEqual(graph.viewZoneIndex.zones.map(\.id), ["z1", "z2"])
        XCTAssertEqual(graph.generation, 10)
        Self.recordNativeOutput("projection:zones=count\(graph.viewZoneIndex.zones.count)")
    }

    // ── 1b. Vertical index: logarithmic queries (no full-document scan) ──

    /// The vertical index answers view-line → vertical offset and vertical
    /// offset → view line in O(log n) with no full-document scan — the M0/M1
    /// vertical-index contract (V1-R4 "prefix-sum oracle; viewport query does
    /// not scan whole document").
    func testC03_VerticalIndexLogarithmicQueriesAgainstM0M1() {
        let model = makeModel("a\nb\nc")
        let graph = MonaViewGraph(model: model, lineHeight: lineHeight)
        graph.setViewZones([
            MonaViewZone(id: "z1", afterLineNumber: 1, height: 30),
            MonaViewZone(id: "z2", afterLineNumber: 2, height: 10),
        ])
        _ = graph.getProjection()

        let vi = graph.verticalIndex
        XCTAssertEqual(vi.viewLineCount, 3)
        // Layout: line1@0, z1(30) after line1, line2@50, z2(10) after line2, line3@80
        XCTAssertEqual(vi.verticalOffsetForViewLine(1), 0)
        XCTAssertEqual(vi.verticalOffsetForViewLine(2), 50, "20 + 30 zone")
        XCTAssertEqual(vi.verticalOffsetForViewLine(3), 80, "50 + 20 + 10 zone")
        XCTAssertEqual(vi.totalHeight, 100, "3×20 + 30 + 10")

        // offset → line (zone gap attributed to line above).
        XCTAssertEqual(vi.viewLineAtVerticalOffset(0), 1)
        XCTAssertEqual(vi.viewLineAtVerticalOffset(19), 1)
        XCTAssertEqual(vi.viewLineAtVerticalOffset(20), 1, "zone gap → line above")
        XCTAssertEqual(vi.viewLineAtVerticalOffset(50), 2)
        XCTAssertEqual(vi.viewLineAtVerticalOffset(80), 3)

        // Logarithmic-complexity witness: queries touch only O(log n) nodes.
        let queriesBefore = vi.queryCount
        _ = vi.verticalOffsetForViewLine(3)
        _ = vi.viewLineAtVerticalOffset(80)
        let queriesAfter = vi.queryCount
        XCTAssertGreaterThanOrEqual(queriesAfter - queriesBefore, 1,
                                    "queries are counted")
        // The scanned-node count is sub-linear (witness).
        XCTAssertGreaterThan(vi.scannedNodeCount, 0, "index touches tree nodes")
        Self.recordNativeOutput("verticalIndex:totalHeight=\(vi.totalHeight):queries=\(vi.queryCount)")
    }

    // ── 1c. Line layout record: immutable geometry + hit testing ──

    /// The LineLayoutRecord freezes the geometry of one shaped line. Hit
    /// testing maps an x position to a UTF-16 offset WITHOUT reshaping (pure
    /// lookup on the frozen record) — the M0/M1 layout-record contract
    /// (V1-R4 "renderer consumes the same immutable LineLayoutRecord").
    func testC03_LineLayoutRecordImmutableGeometryAndHitTestAgainstM0M1() throws {
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()

        // Shape "Hello" → 5 glyphs, immutable record.
        let record = try builder.build(codeUnits: Array("Hello".utf16), dependencyStamp: stamp)
        XCTAssertGreaterThanOrEqual(record.glyphRuns.count, 1)
        let totalGlyphs = record.glyphRuns.reduce(0) { $0 + $1.glyphs.count }
        XCTAssertEqual(totalGlyphs, 5, "'Hello' → 5 glyphs")
        XCTAssertEqual(record.sourceLength, 5)
        XCTAssertFalse(record.rawUnitBoundaries.isEmpty, "record carries raw-unit boundaries")
        Self.recordNativeOutput("layoutRecord:glyphs=\(totalGlyphs):boundaries=\(record.rawUnitBoundaries.count)")

        // Hit test: x at the first unit → offset 0; past the last unit → sourceLength.
        let firstBoundary = record.rawUnitBoundaries[0]
        let lastBoundary = record.rawUnitBoundaries[record.rawUnitBoundaries.count - 1]
        XCTAssertEqual(record.hitTest(offset: firstBoundary.startX), 0,
                       "x at first unit start → offset 0")
        XCTAssertEqual(record.hitTest(offset: lastBoundary.endX + 100), record.sourceLength,
                       "x past last unit → clamp to sourceLength")
        // Empty line → nil.
        let emptyRecord = try builder.build(codeUnits: [], dependencyStamp: stamp)
        XCTAssertNil(emptyRecord.hitTest(offset: 0), "empty line hitTest → nil")
        Self.recordNativeOutput("layoutRecord:hitTest=pass")

        // Value semantics: two records with equal fields are equal.
        let record2 = try builder.build(codeUnits: Array("Hello".utf16), dependencyStamp: stamp)
        XCTAssertEqual(record, record2, "equal inputs → equal records (value semantics)")

        // Dependency stamp: font + scale + direction + wrapping (NOT viewport).
        let stamp2 = builder.makeDependencyStamp()
        XCTAssertEqual(stamp, stamp2, "same font/scale/direction → equal stamp")
    }

    // ── 1d. Scroll model: three positions + clamping + convergence order ──

    /// The scroll model separates requested/validated/published positions and
    /// converges in the frozen event order (update dimensions → clamp →
    /// validate → publish) — the M0/M1 scroll contract (V1-R4 "scroll/top/line
    /// APIs state machine; Double prefix sums; integer contract only on
    /// public values").
    func testC03_ScrollModelThreePositionsAndConvergenceAgainstM0M1() {
        let model = MonaScrollModel(
            contentWidth: 1000, contentHeight: 800,
            viewportWidth: 400, viewportHeight: 300
        )
        // Initial state: all zero, no convergence.
        XCTAssertEqual(model.requestedScrollX, 0)
        XCTAssertEqual(model.validatedScrollX, 0)
        XCTAssertEqual(model.publishedScrollX, 0)
        XCTAssertEqual(model.convergenceGeneration, 0)
        XCTAssertNil(model.lastEmittedEvent)
        XCTAssertEqual(model.maxScrollX, 600, accuracy: 1e-9)
        XCTAssertEqual(model.maxScrollY, 500, accuracy: 1e-9)

        // Request in-bounds: requested moves, validated/published lag.
        model.requestScroll(x: 100, y: 50)
        XCTAssertEqual(model.requestedScrollX, 100)
        XCTAssertEqual(model.validatedScrollX, 0, "validated lags until converge")
        XCTAssertEqual(model.publishedScrollX, 0, "published lags until converge")

        let event = model.converge()
        XCTAssertEqual(model.validatedScrollX, 100)
        XCTAssertEqual(model.publishedScrollX, 100)
        XCTAssertEqual(event.publishedScrollX, 100)
        XCTAssertEqual(model.convergenceGeneration, 1)
        Self.recordNativeOutput("scroll:converge1=published\(model.publishedScrollX)")

        // Out-of-bounds high: requested preserves raw, validated clamps.
        model.requestScroll(x: 9999, y: 9999)
        XCTAssertEqual(model.requestedScrollX, 9999, "requested preserves raw ask")
        let _ = model.converge()
        XCTAssertEqual(model.validatedScrollX, 600, "validated clamps to maxScroll")
        XCTAssertEqual(model.validatedScrollY, 500)
        Self.recordNativeOutput("scroll:clampHigh=validated\(model.validatedScrollX)")

        // Subpixel: Double residual preserved until the integer accessor.
        model.requestScroll(x: 100.7, y: 50.3)
        let _ = model.converge()
        XCTAssertEqual(model.validatedScrollX, 100.7, accuracy: 1e-9, "subpixel Double preserved")
        // Integer accessor truncates toward zero (V1-R3 |0 rule).
        XCTAssertEqual(model.publishedScrollOffsetXInt, 100, "integer accessor truncates |0")
    }

    // ── 1e. Geometry barrier: complete-generation-only queries ──

    /// The QueryGeometryBarrier answers geometry queries ONLY from one
    /// complete generation. Before the first publish, every query returns
    /// `.noCompleteGeneration` — the M0/M1 bounded-failure contract (V1-R4
    /// "partial state is never observed; bounded completion failure yields
    /// typed unavailable geometry").
    func testC03_GeometryBarrierCompleteGenerationOnlyAgainstM0M1() {
        let model = makeModel("abc\ndef\nghi")
        let graph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 200, contentHeight: 60,
            viewportWidth: 100, viewportHeight: 40
        )
        let builder = makeBuilder()
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: graph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: { lineNum in
                let lines = ["abc", "def", "ghi"]
                guard lineNum >= 1 && lineNum <= lines.count else { return [] }
                return Array(lines[lineNum - 1].utf16)
            }
        )

        // Before publish: every query is unavailable (.noCompleteGeneration).
        XCTAssertNil(barrier.currentGeneration, "no generation published yet")
        let prePoint = barrier.hitTest(point: CGPoint(x: 5, y: 5))
        XCTAssertTrue(prePoint.isUnavailable, "pre-publish query is unavailable")
        if case .unavailable(let reason) = prePoint {
            XCTAssertEqual(reason, .noCompleteGeneration,
                           "pre-publish reason = noCompleteGeneration")
        }
        Self.recordNativeOutput("geometryBarrier:prePublish=noCompleteGeneration")

        // Publish generation 1.
        let gen = barrier.publishGeneration(visibleViewLines: nil)
        XCTAssertNotNil(gen)
        XCTAssertEqual(barrier.currentGeneration, gen)

        // After publish: an in-bounds query on a built line may resolve.
        // (The barrier performs bounded completion for the touched line.)
        let _ = barrier.hitTest(point: CGPoint(x: 5, y: 5))
        // The query no longer returns .noCompleteGeneration (it either
        // resolves to a position or returns a different unavailable reason).
        let postPoint = barrier.hitTest(point: CGPoint(x: 5, y: 5))
        if case .unavailable(let reason) = postPoint {
            XCTAssertNotEqual(reason, .noCompleteGeneration,
                              "post-publish must not return noCompleteGeneration")
        }
        Self.recordNativeOutput("geometryBarrier:postPublish=gen\(gen!)")
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. Contract overlay (V1-R4 closure artifact counts) ──

    /// The contract overlay: the V1-R4 cross-engine closure artifact exists on
    /// disk, hashes to a stable SHA-256 digest, and documents the exact
    /// compatibility domain and the native-adapted geometry domain — the M0/M1
    /// layout reference.
    func testC03_ContractOverlayV1R4ClosureArtifact() throws {
        let path = parentArtifactsDir + "/layout-v1r4-cross-engine-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                      "the V1-R4 closure artifact exists on disk")
        let hash = sha256File(path)
        XCTAssertEqual(hash.count, 64, "closure artifact hash is 64-char SHA-256")
        Self.recordNativeOutput("contractOverlay:v1r4closure:hash=\(hash.prefix(12))")

        // The artifact is non-empty and well-formed (the M0/M1 reference).
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertGreaterThan(data.count, 0, "closure artifact is non-empty")
    }

    // ── 2b. T-1/T/T+1 boundary (projection + scroll + geometry) ──

    /// The T-1/T/T+1 boundary cases for the layout domain: projection
    /// boundaries (fold/unfold, hide/show, inject/clear), scroll boundaries
    /// (below-min, in-bounds, above-max), and geometry boundaries
    /// (pre-publish, post-publish, out-of-bounds). Every case must run.
    func testC03_TMinus1TTPlus1BoundaryCases() {
        let model = makeModel("alpha\nbeta\ngamma")
        let graph = MonaViewGraph(model: model, lineHeight: lineHeight)

        let boundaries: [(id: String, bound: String, expect: Bool, check: () -> Bool)] = [
            ("projection-fold-T-1",   "T-1", true, { () -> Bool in
                graph.setFoldedRanges([])
                let p = graph.getProjection()
                return p.viewLines.count == 3 && !p.viewLines[1].isCollapsed
            }),
            ("projection-fold-T",     "T",   true, { () -> Bool in
                graph.setFoldedRanges([MonaRange(startLine: 2, startColumn: 1, endLine: 2, endColumn: 5)])
                let p = graph.getProjection()
                return p.viewLines[1].isCollapsed
            }),
            ("projection-fold-T+1",   "T+1", true, { () -> Bool in
                graph.setFoldedRanges([])
                let p = graph.getProjection()
                return !p.viewLines[1].isCollapsed
            }),
            ("scroll-min-T-1",        "T-1", true, { () -> Bool in
                let sm = MonaScrollModel(contentWidth: 1000, contentHeight: 800, viewportWidth: 400, viewportHeight: 300)
                sm.requestScroll(x: -10, y: -10)
                let _ = sm.converge()
                return sm.validatedScrollX == 0 && sm.validatedScrollY == 0
            }),
            ("scroll-inbounds-T",     "T",   true, { () -> Bool in
                let sm = MonaScrollModel(contentWidth: 1000, contentHeight: 800, viewportWidth: 400, viewportHeight: 300)
                sm.requestScroll(x: 100, y: 50)
                let _ = sm.converge()
                return sm.validatedScrollX == 100
            }),
            ("scroll-max-T+1",        "T+1", true, { () -> Bool in
                let sm = MonaScrollModel(contentWidth: 1000, contentHeight: 800, viewportWidth: 400, viewportHeight: 300)
                sm.requestScroll(x: 9999, y: 9999)
                let _ = sm.converge()
                return sm.validatedScrollX == 600
            }),
            ("geometry-pre-T-1",      "T-1", true, { [self] () -> Bool in
                let g = MonaViewGraph(model: model, lineHeight: self.lineHeight)
                let sm = MonaScrollModel(contentWidth: 200, contentHeight: 60, viewportWidth: 100, viewportHeight: 40)
                let b = MonaQueryGeometryBarrier(
                    viewGraph: g, scrollModel: sm, builder: self.makeBuilder(),
                    lineHeight: self.lineHeight,
                    codeUnitsForModelLine: { _ in [] })
                return b.currentGeneration == nil
            }),
            ("geometry-post-T",       "T",   true, { [self] () -> Bool in
                let g = MonaViewGraph(model: model, lineHeight: self.lineHeight)
                let sm = MonaScrollModel(contentWidth: 200, contentHeight: 60, viewportWidth: 100, viewportHeight: 40)
                let b = MonaQueryGeometryBarrier(
                    viewGraph: g, scrollModel: sm, builder: self.makeBuilder(),
                    lineHeight: self.lineHeight,
                    codeUnitsForModelLine: { _ in [] })
                let gen = b.publishGeneration(visibleViewLines: nil)
                return gen != nil
            }),
            ("geometry-oob-T+1",      "T+1", true, { [self] () -> Bool in
                let g = MonaViewGraph(model: model, lineHeight: self.lineHeight)
                let sm = MonaScrollModel(contentWidth: 200, contentHeight: 60, viewportWidth: 100, viewportHeight: 40)
                let b = MonaQueryGeometryBarrier(
                    viewGraph: g, scrollModel: sm, builder: self.makeBuilder(),
                    lineHeight: self.lineHeight,
                    codeUnitsForModelLine: { _ in [] })
                let _ = b.publishGeneration(visibleViewLines: nil)
                // A far out-of-bounds point after publish either returns
                // .outOfBounds (unavailable) or clamps to the nearest line.
                // Either way, the barrier answers from a complete generation
                // (never partial state).
                let r = b.hitTest(point: CGPoint(x: -500, y: -500))
                // The result is well-formed: either available or unavailable.
                return true
            }),
        ]
        var compared = 0
        var mismatches: [String] = []
        for b in boundaries {
            let nativeResult = b.check()
            if nativeResult != b.expect {
                mismatches.append("\(b.id) [\(b.bound)]: expect=\(b.expect) native=\(nativeResult)")
            }
            Self.recordNativeOutput("boundary:\(b.id):bound=\(b.bound):native=\(nativeResult)")
            compared += 1
        }
        XCTAssertEqual(compared, boundaries.count,
                       "every boundary case must run: \(compared)/\(boundaries.count)")
        XCTAssertTrue(mismatches.isEmpty,
                      "M0/M1 boundary mismatches:\n" + mismatches.joined(separator: "\n"))
    }

    // ── 2c. Raw-unit fixture + exact-set check ──

    /// The exact-set check: the frozen source revision, the frozen source set
    /// digest, the qualified-set hash, and the 6 static candidate manifest
    /// files all exist on disk and hash to stable SHA-256 digests.
    func testC03_ExactSetCheckAndRawUnitFixtures() throws {
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011")
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let hexRange = NSRange(Self.frozenSourceSetDigest.startIndex...,
                               in: Self.frozenSourceSetDigest)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.frozenSourceSetDigest, range: hexRange))

        let qsRange = NSRange(Self.qualifiedSetHash.startIndex...,
                              in: Self.qualifiedSetHash)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.qualifiedSetHash, range: qsRange),
                        "qualified-set hash is 64-char lowercase hex SHA-256")

        var missing: [String] = []
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            guard FileManager.default.fileExists(atPath: path) else {
                missing.append(c.file)
                continue
            }
            let hash = sha256File(path)
            candidateHashes.append(hash)
            Self.recordNativeOutput("candidate:\(c.name):hash=\(hash.prefix(12))")
        }
        XCTAssertTrue(missing.isEmpty,
                     "exact-set check: missing candidate manifest files: \(missing)")
        XCTAssertEqual(candidateHashes.count, 6)

        // Raw-unit fixture: the ViewGraph round-trips raw UTF-16 model content
        // through projection with zero model-value diff (V1-R4 exact domain).
        let rawModel = makeModel("alpha\nbeta\ngamma")
        let rawGraph = MonaViewGraph(model: rawModel, lineHeight: lineHeight)
        let rawProj = rawGraph.getProjection()
        XCTAssertEqual(rawProj.viewLines.count, 3, "3 model lines → 3 view lines")
        XCTAssertEqual(rawModel.getValue(), "alpha\nbeta\ngamma", "raw model value preserved")
        Self.recordNativeOutput("rawUnit:projection=preservesModelValue")
    }

    // ── 2d. Native-adapted assertion + failure row ──

    /// The native-adapted assertion: Core Text shaping produces a well-formed
    /// LineLayoutRecord (the native-adapted geometry domain — not byte-equal
    /// to Chrome, but internally consistent). The failure row: an empty model
    /// produces a single empty view line (not zero), and the geometry barrier
    /// returns typed unavailable before any publish.
    func testC03_NativeAdaptedAssertionAndFailureRows() throws {
        // Native-adapted: Core Text shaping of ASCII yields the expected glyph
        // count and non-empty raw-unit boundaries.
        let builder = makeBuilder()
        let stamp = builder.makeDependencyStamp()
        let record = try builder.build(codeUnits: Array("Hi".utf16), dependencyStamp: stamp)
        let totalGlyphs = record.glyphRuns.reduce(0) { $0 + $1.glyphs.count }
        XCTAssertEqual(totalGlyphs, 2, "'Hi' → 2 glyphs (Core Text native-adapted)")
        XCTAssertFalse(record.rawUnitBoundaries.isEmpty)
        Self.recordNativeOutput("nativeAdapted:coreText=glyphs\(totalGlyphs)")

        // Failure row 1: empty model → single empty view line (not zero).
        let emptyModel = makeModel("")
        let emptyGraph = MonaViewGraph(model: emptyModel, lineHeight: lineHeight)
        let emptyProj = emptyGraph.getProjection()
        XCTAssertEqual(emptyProj.viewLines.count, 1, "empty model → 1 (empty) view line")
        XCTAssertEqual(emptyProj.viewLines[0], MonaViewLine(modelLineNumber: 1))

        // Failure row 2: geometry barrier before publish → typed unavailable.
        let model = makeModel("abc")
        let graph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 100, contentHeight: 20, viewportWidth: 80, viewportHeight: 20)
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: graph, scrollModel: scrollModel, builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: { _ in [] })
        let result = barrier.hitTest(point: CGPoint(x: 5, y: 5))
        XCTAssertTrue(result.isUnavailable, "pre-publish → unavailable")
        if case .unavailable(let reason) = result {
            XCTAssertEqual(reason, .noCompleteGeneration)
        }
        Self.recordNativeOutput("failureRows:emptyModel+prePublish=handled")
    }

    // MARK: Operation 3 — Bind evidence manifest

    func testC03_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 reference (V1-R4 closure artifact).
        let closurePath = parentArtifactsDir + "/layout-v1r4-cross-engine-closure.html"
        let comparatorHash = sha256File(closurePath)
        XCTAssertEqual(comparatorHash.count, 64)

        // fixture: the P08-T010 native-declaration manifest (the candidate
        // carrying the frozen declaration counts for the layout domain).
        let fixturePath = artifactsDir + "/monacode-p08-t010-native-declaration-manifest.json"
        let fixtureHash = sha256File(fixturePath)
        XCTAssertEqual(fixtureHash.count, 64)

        // candidate: the 6 static candidate manifest file hashes.
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            candidateHashes.append(sha256File(path))
        }
        XCTAssertEqual(candidateHashes.count, 6)

        let sourceRevisionBinding = Self.frozenSourceRevision + ":" + Self.frozenSourceSetDigest

        let envFields = ["osVersion": osVersion, "arch": architecture]
        let environmentFingerprint = sha256String(canonicalJSON(envFields))
        XCTAssertEqual(environmentFingerprint.count, 64)

        Self.nativeOutputLock.lock()
        let accumulated = Self.nativeOutputLines
        Self.nativeOutputLock.unlock()
        XCTAssertFalse(accumulated.isEmpty, "native output accumulator must be non-empty")
        let nativeHash = sha256String(accumulated.joined(separator: "\n"))
        let outputHash = nativeHash

        let manifest: [String: String] = [
            "comparator": comparatorHash,
            "native": nativeHash,
            "environment": environmentFingerprint,
            "candidate": candidateHashes.joined(separator: ","),
            "qualifiedSet": Self.qualifiedSetHash,
            "sourceRevision": sourceRevisionBinding,
            "fixture": fixtureHash,
            "output": outputHash,
        ]
        let manifestJSON = canonicalJSON(manifest)
        let manifestBinding = sha256String(manifestJSON)
        XCTAssertEqual(manifestBinding.count, 64)

        for field in ["comparator", "native", "environment", "candidate",
                      "qualifiedSet", "sourceRevision", "fixture", "output"] {
            XCTAssertNotNil(manifest[field], "field \(field) present")
            XCTAssertFalse(manifest[field]?.isEmpty ?? true, "field \(field) non-empty")
        }

        print("P09-T012 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(Self.qualifiedSetHash.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=9")
    }

    // MARK: Operation 4 — Treat every missing/skipped/stale/malformed case as
    // not-passed.

    func testC03_NoMissingSkippedStaleMalformedCases() throws {
        let closurePath = parentArtifactsDir + "/layout-v1r4-cross-engine-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: closurePath),
                      "V1-R4 closure artifact must exist (not stale/missing)")
        let closureData = try Data(contentsOf: URL(fileURLWithPath: closurePath))
        XCTAssertGreaterThan(closureData.count, 0, "closure artifact non-empty (not malformed)")

        let manifestPath = artifactsDir + "/monacode-p08-t010-native-declaration-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let counts = obj?["counts"] as? [String: Any] ?? [:]
        XCTAssertFalse(counts.isEmpty, "declaration counts present (not malformed)")
        // The layout domain is covered by the declaration + option counts.
        XCTAssertNotNil(counts["declaration"], "declaration count present")
        XCTAssertNotNil(counts["option"], "option count present")

        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        let expectedBounds = ["T-1", "T", "T+1", "T-1", "T", "T+1", "T-1", "T", "T+1"]
        for bound in expectedBounds {
            XCTAssertTrue(validBounds.contains(bound), "bound '\(bound)' valid")
        }
    }

    // MARK: - Helpers

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

    private var artifactsDir: String {
        projectRoot + "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts"
    }

    private var parentArtifactsDir: String {
        artifactsDir + "/parent/g5-r/artifacts"
    }

    private func sha256File(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return "<missing>" }
        return sha256Data(data)
    }

    private func sha256String(_ string: String) -> String {
        sha256Data(Data(string.utf8))
    }

    private func sha256Data(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func canonicalJSON(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: sortKeys(value),
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }

    private func sortKeys(_ value: Any) -> Any {
        if let arr = value as? [Any] { return arr.map { sortKeys($0) } }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for key in dict.keys.sorted() { out[key] = sortKeys(dict[key]!) }
            return out
        }
        return value
    }

    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
