// DrivingLayerTests.swift
//
// Driving-layer GAP-1 / Task 1 — Barrier public snapshot + RenderSurface cgImage.
//
// Prerequisites for the `drawRect` render pipeline (Task 2):
//   - `MonaQueryGeometryBarrier.snapshot()` is public so the driving layer can
//     read the ready geometry of one complete generation without observing
//     partial state.
//   - `MonaRenderSurface.cgImage` exposes a lazily-derived, cached `CGImage`
//     of the bitmap context so a finished tile can be composited into the host
//     `NSGraphicsContext` in `drawRect` without rebuilding the image each frame.

import XCTest
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit

final class DrivingLayerTests: XCTestCase {

    // MARK: - Shared helpers (constructed against the real MonaCodeAppKit API)

    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// Builds a barrier over a real model + view graph + scroll model + builder,
    /// mirroring the construction used by `MonaQueryGeometryBarrierTests`.
    private func makeBarrier(
        text: String = "hello\nworld\n",
        lineHeight: Int = 20
    ) -> MonaQueryGeometryBarrier {
        let model = MonaCodeModel(text: text, uri: MonaURI.parse("monacode:driving")!)
        let viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 400,
            contentHeight: Double(2 * lineHeight),
            viewportWidth: 400,
            viewportHeight: Double(lineHeight)
        )
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let provider: (Int) -> [UInt16] = { Array(model.getLineContent($0).utf16) }
        return MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: provider
        )
    }

    // MARK: - Barrier: public snapshot accessor (Task 1 / GAP-1)

    func testBarrierSnapshotIsPublic() {
        let barrier = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...1)
        let snap = barrier.snapshot()
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.records.count, 1)
    }

    // MARK: - RenderSurface: lazy cached cgImage (Task 1 / GAP-1)

    func testRenderSurfaceHasCachedCGImage() {
        let surface = MonaRenderSurface(width: 256, height: 256, scaleFactor: 1)
        XCTAssertNotNil(surface.cgImage)
        // Same instance on second access (cached, not re-created).
        let img1 = surface.cgImage
        let img2 = surface.cgImage
        XCTAssertNotNil(img1)
        XCTAssertNotNil(img2)
        XCTAssertEqual(img1, img2)
    }
}
