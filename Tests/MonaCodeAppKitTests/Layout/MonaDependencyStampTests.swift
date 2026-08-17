// MonaDependencyStampTests.swift
//
// P03-T004 — Define seven non-contradictory dependency stamp domains.
//
// Verifies the seven immutable dependency-stamp domains that key every cached
// projection, layout, paint, surface, and frame artifact in the renderer:
//   - MonaProjectionStamp        — projection state (folding, wrapping,
//                                   injections, view zones).
//   - MonaVerticalStamp          — vertical layout state (line heights, zones).
//   - MonaScrollDimensionStamp   — scroll dimensions (content size, viewport).
//   - MonaGeometryStamp          — line geometry (glyph runs, advances,
//                                   baselines — from P03-T003).
//   - MonaPaintStamp             — paint state (colors, themes, decorations).
//   - MonaSurfaceStamp           — surface state (render target, scale, mode).
//   - MonaFrameStamp             — frame state (viewport position, scroll).
//
// Each stamp is an immutable value (let-only fields, value semantics, Equatable
// + Hashable). A frozen mutation-to-domain edge map (MonaDependencyStampEdgeMap)
// enumerates which mutations invalidate which stamps, derived from V1-R3 (layout
// final closure) and V1-R4 (cross-engine contract). The map rejects:
//   - missing invalidations: a claim that omits a stamp the frozen set requires.
//   - fanout: a claim that includes a stamp the frozen set does not permit.
//
// One contract case: 7 distinct immutable stamp domains + mutation-to-domain
// edge map that rejects missing invalidations and fanout.

import XCTest
import CoreGraphics
@testable import MonaCodeAppKit

final class MonaDependencyStampTests: XCTestCase {

    // MARK: - Helpers

    private let font = MonaFontDescriptor(familyName: "Menlo", size: 12)

    private func projectionStamp(
        generation: Int = 1,
        modelVersion: Int = 1,
        viewLineCount: Int = 10,
        wrappingColumn: Int? = 80,
        foldedRangeDigest: Int = 0,
        hiddenRangeDigest: Int = 0,
        injectionDigest: Int = 0,
        viewZoneDigest: Int = 0
    ) -> MonaProjectionStamp {
        return MonaProjectionStamp(
            generation: generation,
            modelVersion: modelVersion,
            viewLineCount: viewLineCount,
            wrappingColumn: wrappingColumn,
            foldedRangeDigest: foldedRangeDigest,
            hiddenRangeDigest: hiddenRangeDigest,
            injectionDigest: injectionDigest,
            viewZoneDigest: viewZoneDigest
        )
    }

    private func verticalStamp(
        generation: Int = 1,
        lineHeight: Int = 18,
        viewLineCount: Int = 10,
        viewZoneHeightDigest: Int = 0,
        totalHeight: Int = 180
    ) -> MonaVerticalStamp {
        return MonaVerticalStamp(
            generation: generation,
            lineHeight: lineHeight,
            viewLineCount: viewLineCount,
            viewZoneHeightDigest: viewZoneHeightDigest,
            totalHeight: totalHeight
        )
    }

    private func scrollDimensionStamp(
        contentWidth: Int = 600,
        contentHeight: Int = 180,
        viewportWidth: Int = 800,
        viewportHeight: Int = 600,
        viewportColumn: Int = 100
    ) -> MonaScrollDimensionStamp {
        return MonaScrollDimensionStamp(
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            viewportColumn: viewportColumn
        )
    }

    private func geometryStamp(
        font: MonaFontDescriptor = MonaFontDescriptor(familyName: "Menlo", size: 12),
        scale: CGFloat = 2,
        direction: MonaTextDirection = .ltr,
        wrappingColumn: Int? = 80
    ) -> MonaGeometryStamp {
        return MonaGeometryStamp(
            fontDescriptor: font,
            scale: scale,
            direction: direction,
            wrappingColumn: wrappingColumn
        )
    }

    private func paintStamp(
        themeDigest: Int = 1,
        decorationDigest: Int = 0,
        selectionDigest: Int = 0,
        caretDigest: Int = 0
    ) -> MonaPaintStamp {
        return MonaPaintStamp(
            themeDigest: themeDigest,
            decorationDigest: decorationDigest,
            selectionDigest: selectionDigest,
            caretDigest: caretDigest
        )
    }

    private func surfaceStamp(
        renderTargetKind: MonaRenderTargetKind = .coreGraphics,
        scaleFactor: CGFloat = 2,
        displayMode: MonaDisplayMode = .highDPI,
        generation: Int = 1
    ) -> MonaSurfaceStamp {
        return MonaSurfaceStamp(
            renderTargetKind: renderTargetKind,
            scaleFactor: scaleFactor,
            displayMode: displayMode,
            generation: generation
        )
    }

    private func frameStamp(
        scrollOffsetX: Int = 0,
        scrollOffsetY: Int = 0,
        generation: Int = 1
    ) -> MonaFrameStamp {
        return MonaFrameStamp(
            scrollOffsetX: scrollOffsetX,
            scrollOffsetY: scrollOffsetY,
            generation: generation
        )
    }

    // MARK: - 1. Seven stamp domains are distinct immutable values

    func testSevenStampDomainsAreDistinctImmutableValues() {
        // The MonaStampDomain enum enumerates exactly seven domains.
        XCTAssertEqual(MonaStampDomain.allCases.count, 7)
        XCTAssertEqual(
            MonaStampDomain.allCases,
            [
                .projection, .vertical, .scrollDimension,
                .geometry, .paint, .surface, .frame
            ]
        )

        // Each domain is a distinct case (no two domains compare equal).
        let domains = MonaStampDomain.allCases
        for i in 0..<domains.count {
            for j in (i + 1)..<domains.count {
                XCTAssertNotEqual(domains[i], domains[j],
                    "\(domains[i]) must be distinct from \(domains[j])")
            }
        }
    }

    func testStampsAreImmutableWithValueSemanticsAndHashable() {
        // Two projections constructed with equal fields are equal regardless
        // of construction site, and differing any field breaks equality.
        let p1 = projectionStamp()
        let p2 = projectionStamp()
        XCTAssertEqual(p1, p2)
        XCTAssertEqual(p1.hashValue, p2.hashValue)
        XCTAssertNotEqual(p1, projectionStamp(generation: 2))
        XCTAssertNotEqual(p1, projectionStamp(modelVersion: 2))
        XCTAssertNotEqual(p1, projectionStamp(wrappingColumn: nil))
        XCTAssertNotEqual(p1, projectionStamp(foldedRangeDigest: 7))
        XCTAssertNotEqual(p1, projectionStamp(injectionDigest: 9))
        XCTAssertNotEqual(p1, projectionStamp(viewZoneDigest: 11))

        // Vertical stamp.
        let v1 = verticalStamp()
        XCTAssertEqual(v1, verticalStamp())
        XCTAssertEqual(v1.hashValue, verticalStamp().hashValue)
        XCTAssertNotEqual(v1, verticalStamp(lineHeight: 20))
        XCTAssertNotEqual(v1, verticalStamp(viewLineCount: 99))
        XCTAssertNotEqual(v1, verticalStamp(viewZoneHeightDigest: 5))
        XCTAssertNotEqual(v1, verticalStamp(totalHeight: 999))

        // ScrollDimension stamp.
        let s1 = scrollDimensionStamp()
        XCTAssertEqual(s1, scrollDimensionStamp())
        XCTAssertEqual(s1.hashValue, scrollDimensionStamp().hashValue)
        XCTAssertNotEqual(s1, scrollDimensionStamp(contentWidth: 1))
        XCTAssertNotEqual(s1, scrollDimensionStamp(contentHeight: 1))
        XCTAssertNotEqual(s1, scrollDimensionStamp(viewportWidth: 1))
        XCTAssertNotEqual(s1, scrollDimensionStamp(viewportHeight: 1))
        XCTAssertNotEqual(s1, scrollDimensionStamp(viewportColumn: 1))

        // Geometry stamp.
        let g1 = geometryStamp()
        XCTAssertEqual(g1, geometryStamp())
        XCTAssertEqual(g1.hashValue, geometryStamp().hashValue)
        XCTAssertNotEqual(g1, geometryStamp(font: MonaFontDescriptor(familyName: "Monaco", size: 12)))
        XCTAssertNotEqual(g1, geometryStamp(scale: 3))
        XCTAssertNotEqual(g1, geometryStamp(direction: .rtl))
        XCTAssertNotEqual(g1, geometryStamp(wrappingColumn: nil))

        // Paint stamp.
        let pt1 = paintStamp()
        XCTAssertEqual(pt1, paintStamp())
        XCTAssertEqual(pt1.hashValue, paintStamp().hashValue)
        XCTAssertNotEqual(pt1, paintStamp(themeDigest: 2))
        XCTAssertNotEqual(pt1, paintStamp(decorationDigest: 2))
        XCTAssertNotEqual(pt1, paintStamp(selectionDigest: 2))
        XCTAssertNotEqual(pt1, paintStamp(caretDigest: 2))

        // Surface stamp.
        let su1 = surfaceStamp()
        XCTAssertEqual(su1, surfaceStamp())
        XCTAssertEqual(su1.hashValue, surfaceStamp().hashValue)
        XCTAssertNotEqual(su1, surfaceStamp(renderTargetKind: .metal))
        XCTAssertNotEqual(su1, surfaceStamp(scaleFactor: 3))
        XCTAssertNotEqual(su1, surfaceStamp(displayMode: .standard))
        XCTAssertNotEqual(su1, surfaceStamp(generation: 2))

        // Frame stamp.
        let f1 = frameStamp()
        XCTAssertEqual(f1, frameStamp())
        XCTAssertEqual(f1.hashValue, frameStamp().hashValue)
        XCTAssertNotEqual(f1, frameStamp(scrollOffsetX: 10))
        XCTAssertNotEqual(f1, frameStamp(scrollOffsetY: 10))
        XCTAssertNotEqual(f1, frameStamp(generation: 2))
    }

    func testEachStampReportsItsDomain() {
        XCTAssertEqual(MonaProjectionStamp.domain, .projection)
        XCTAssertEqual(MonaVerticalStamp.domain, .vertical)
        XCTAssertEqual(MonaScrollDimensionStamp.domain, .scrollDimension)
        XCTAssertEqual(MonaGeometryStamp.domain, .geometry)
        XCTAssertEqual(MonaPaintStamp.domain, .paint)
        XCTAssertEqual(MonaSurfaceStamp.domain, .surface)
        XCTAssertEqual(MonaFrameStamp.domain, .frame)
    }

    // MARK: - 2. Mutation-to-domain edge map (frozen from V1-R3 / V1-R4)

    func testFrozenMutationToDomainEdges() {
        let map = MonaDependencyStampEdgeMap.standard

        // Each mutation invalidates exactly its frozen stamp-domain set.
        // Derived from V1-R3 (layout final closure) and V1-R4 (cross-engine).
        let expected: [MonaMutation: Set<MonaStampDomain>] = [
            .modelEdit:           [.projection, .vertical, .scrollDimension, .geometry, .frame],
            .foldChanged:         [.projection, .vertical, .scrollDimension, .frame],
            .injectedTextChanged: [.projection, .geometry, .scrollDimension, .frame],
            .wordWrapChanged:     [.projection, .vertical, .scrollDimension, .geometry, .frame],
            .viewZonesChanged:    [.projection, .vertical, .scrollDimension, .frame],
            .lineHeightChanged:   [.vertical, .scrollDimension, .frame],
            .fontChanged:         [.geometry, .scrollDimension, .frame],
            .baseDirectionChanged:[.geometry, .frame],
            .themeChanged:        [.paint, .frame],
            .decorationsChanged:  [.paint, .frame],
            .selectionChanged:    [.paint, .frame],
            .caretChanged:        [.paint, .frame],
            .contentWidthChanged: [.projection, .scrollDimension, .frame],
            .viewportSizeChanged: [.scrollDimension, .frame],
            .scaleFactorChanged:  [.surface, .geometry, .scrollDimension, .frame],
            .displayModeChanged:  [.surface, .frame],
            .scrollOffsetChanged: [.frame],
            .renderTargetChanged: [.surface, .frame],
        ]

        // Every mutation must be present in the frozen map (no mutation is
        // unmapped — that would be a missing-invalidation failure).
        XCTAssertEqual(MonaMutation.allCases.count, expected.count,
            "Every mutation must have a frozen edge entry")
        for mutation in MonaMutation.allCases {
            let got = map.invalidatedDomains(for: mutation)
            let want = expected[mutation]!
            XCTAssertEqual(got, want,
                "mutation \(mutation) must invalidate exactly \(want), got \(got)")
        }
    }

    // MARK: - 3. V1-R3 / V1-R4 invariants encoded in the edge map

    /// V1-R3 hit 09: paint-only selection/caret updates must NOT invalidate
    /// geometry (no re-rasterization of text).
    func testPaintOnlyMutationsDoNotInvalidateGeometry() {
        let map = MonaDependencyStampEdgeMap.standard
        for mutation in [MonaMutation.selectionChanged, .caretChanged] {
            let invalidated = map.invalidatedDomains(for: mutation)
            XCTAssertFalse(invalidated.contains(.geometry),
                "paint-only \(mutation) must not invalidate geometry (V1-R3 hit 09)")
            XCTAssertFalse(invalidated.contains(.surface),
                "paint-only \(mutation) must not invalidate surface")
            XCTAssertTrue(invalidated.contains(.paint),
                "paint-only \(mutation) must invalidate paint")
            XCTAssertTrue(invalidated.contains(.frame),
                "paint-only \(mutation) must invalidate frame")
        }
    }

    /// V1-R3 hit 02: word-wrap change synchronously rebuilds projection AND
    /// vertical AND geometry (wrapping column is a shaping input).
    func testWordWrapChangedRebuildsProjectionAndGeometry() {
        let map = MonaDependencyStampEdgeMap.standard
        let invalidated = map.invalidatedDomains(for: .wordWrapChanged)
        XCTAssertTrue(invalidated.contains(.projection),
            "wordWrapChanged must invalidate projection (V1-R3 hit 02)")
        XCTAssertTrue(invalidated.contains(.vertical),
            "wordWrapChanged must invalidate vertical (wrap changes view-line count)")
        XCTAssertTrue(invalidated.contains(.geometry),
            "wordWrapChanged must invalidate geometry (wrappingColumn is a shaping input)")
    }

    /// V1-R4 hit 04: CG/Metal consume the same immutable LineLayoutRecord, so
    /// a render-target switch must NOT invalidate geometry.
    func testRenderTargetChangedDoesNotInvalidateGeometry() {
        let map = MonaDependencyStampEdgeMap.standard
        let invalidated = map.invalidatedDomains(for: .renderTargetChanged)
        XCTAssertTrue(invalidated.contains(.surface))
        XCTAssertTrue(invalidated.contains(.frame))
        XCTAssertFalse(invalidated.contains(.geometry),
            "renderTargetChanged must not invalidate geometry (V1-R4 hit 04)")
    }

    /// Canonical pure-scroll mutation: invalidates ONLY the frame.
    func testScrollOffsetChangedInvalidatesOnlyFrame() {
        let map = MonaDependencyStampEdgeMap.standard
        let invalidated = map.invalidatedDomains(for: .scrollOffsetChanged)
        XCTAssertEqual(invalidated, [.frame],
            "scrollOffsetChanged must invalidate only the frame")
    }

    /// V1-R3 plane-dependencies: after model/geometry changes, the old text
    /// and a new cursor must not form an accepted frame — so modelEdit and
    /// fontChanged must invalidate the frame.
    func testModelAndGeometryMutationsInvalidateFrame() {
        let map = MonaDependencyStampEdgeMap.standard
        for mutation in [MonaMutation.modelEdit, .fontChanged, .baseDirectionChanged] {
            let invalidated = map.invalidatedDomains(for: mutation)
            XCTAssertTrue(invalidated.contains(.frame),
                "\(mutation) must invalidate frame (old text + new cursor rule)")
        }
    }

    // MARK: - 4. Reject missing invalidations

    func testRejectMissingInvalidation() {
        let map = MonaDependencyStampEdgeMap.standard

        // modelEdit must invalidate {projection, vertical, scrollDimension,
        // geometry, frame}. A claim that omits .geometry is a missing
        // invalidation and must be rejected.
        let incompleteClaim: Set<MonaStampDomain> = [
            .projection, .vertical, .scrollDimension, .frame
        ]
        let validation = map.validate(mutation: .modelEdit, claimedInvalidated: incompleteClaim)
        XCTAssertFalse(validation.isValid,
            "a claim missing .geometry for modelEdit must be rejected")
        XCTAssertTrue(validation.missing.contains(.geometry),
            "missing set must report .geometry")
        XCTAssertTrue(validation.fanout.isEmpty,
            "no fanout when the claim is a strict subset")
    }

    func testRejectMissingInvalidationMultipleDomains() {
        let map = MonaDependencyStampEdgeMap.standard

        // wordWrapChanged must invalidate 5 domains; claim only 2.
        let claim: Set<MonaStampDomain> = [.projection, .frame]
        let validation = map.validate(mutation: .wordWrapChanged, claimedInvalidated: claim)
        XCTAssertFalse(validation.isValid)
        XCTAssertEqual(validation.missing,
            [.vertical, .scrollDimension, .geometry],
            "must report the three missing domains")
        XCTAssertTrue(validation.fanout.isEmpty)
    }

    // MARK: - 5. Reject fanout beyond the frozen edge set

    func testRejectFanout() {
        let map = MonaDependencyStampEdgeMap.standard

        // scrollOffsetChanged must invalidate ONLY .frame. A claim that also
        // invalidates .geometry is fanout and must be rejected.
        let overbroadClaim: Set<MonaStampDomain> = [.frame, .geometry, .surface]
        let validation = map.validate(mutation: .scrollOffsetChanged, claimedInvalidated: overbroadClaim)
        XCTAssertFalse(validation.isValid,
            "a claim with extra domains for scrollOffsetChanged must be rejected")
        XCTAssertTrue(validation.missing.isEmpty,
            "no missing domains when the claim is a strict superset")
        XCTAssertEqual(validation.fanout, [.geometry, .surface],
            "fanout set must report the two extra domains")
    }

    func testRejectFanoutOnPaintOnlyMutation() {
        let map = MonaDependencyStampEdgeMap.standard

        // selectionChanged must invalidate {paint, frame}. Claiming it also
        // invalidates geometry is fanout (V1-R3 hit 09 violation).
        let claim: Set<MonaStampDomain> = [.paint, .frame, .geometry, .vertical]
        let validation = map.validate(mutation: .selectionChanged, claimedInvalidated: claim)
        XCTAssertFalse(validation.isValid)
        XCTAssertEqual(validation.fanout, [.geometry, .vertical])
        XCTAssertTrue(validation.missing.isEmpty)
    }

    // MARK: - 6. Exact claim is valid

    func testExactClaimIsValid() {
        let map = MonaDependencyStampEdgeMap.standard

        // An exact match for every mutation must be valid.
        for mutation in MonaMutation.allCases {
            let exact = map.invalidatedDomains(for: mutation)
            let validation = map.validate(mutation: mutation, claimedInvalidated: exact)
            XCTAssertTrue(validation.isValid,
                "\(mutation): exact claim must be valid; missing=\(validation.missing) fanout=\(validation.fanout)")
            XCTAssertTrue(validation.missing.isEmpty)
            XCTAssertTrue(validation.fanout.isEmpty)
        }
    }

    func testSimultaneousMissingAndFanoutReported() {
        let map = MonaDependencyStampEdgeMap.standard

        // A claim that both omits a required domain AND adds a forbidden one:
        // modelEdit requires {projection, vertical, scrollDimension, geometry,
        // frame}. Claim {projection, vertical, scrollDimension, surface}:
        //   missing = {geometry, frame}
        //   fanout  = {surface}
        let claim: Set<MonaStampDomain> = [.projection, .vertical, .scrollDimension, .surface]
        let validation = map.validate(mutation: .modelEdit, claimedInvalidated: claim)
        XCTAssertFalse(validation.isValid)
        XCTAssertEqual(validation.missing, [.geometry, .frame])
        XCTAssertEqual(validation.fanout, [.surface])
    }
}
