// MonaScrollModelTests.swift
//
// P03-T005 — Implement scroll truth and dimension convergence.
//
// Verifies `MonaScrollModel`, the single source of scroll truth for the
// renderer. The model separates three distinct scroll positions:
//   - requestedScrollX/Y  — what the requester asked for (may be out of bounds).
//   - validatedScrollX/Y   — clamped to content bounds (the "truth").
//   - publishedScrollX/Y   — the final position emitted to the renderer
//                              (after dimension convergence).
//
// `converge()` reconciles content + viewport dimensions + clamping in the
// frozen event order (update dimensions → clamp requested → validate →
// publish) and emits a scroll-change event. Scroll values are `Double` so
// subpixel phase is preserved until the final surface transform (V1-R3:
// Double prefix sums; I3-R4: preserve Double residual; integer contract
// applies only to the published stamp / frame identity key).
//
// One contract case: requested/validated/published separation + clamping +
// subpixel preservation + dimension convergence in the frozen event order.

import XCTest
import CoreGraphics
@testable import MonaCodeAppKit

final class MonaScrollModelTests: XCTestCase {

    // MARK: - 1. Initial state

    func testInitialStateIsZeroScrollWithGivenDimensions() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )

        // All three scroll positions start at zero.
        XCTAssertEqual(model.requestedScrollX, 0)
        XCTAssertEqual(model.requestedScrollY, 0)
        XCTAssertEqual(model.validatedScrollX, 0)
        XCTAssertEqual(model.validatedScrollY, 0)
        XCTAssertEqual(model.publishedScrollX, 0)
        XCTAssertEqual(model.publishedScrollY, 0)

        // Dimensions are stored as given.
        XCTAssertEqual(model.contentWidth, 1000)
        XCTAssertEqual(model.contentHeight, 800)
        XCTAssertEqual(model.viewportWidth, 400)
        XCTAssertEqual(model.viewportHeight, 300)

        // No convergence has run yet.
        XCTAssertEqual(model.convergenceGeneration, 0)
        XCTAssertNil(model.lastEmittedEvent)

        // Derived max scrollable extent = content - viewport (clamped at 0).
        XCTAssertEqual(model.maxScrollX, 600, accuracy: 1e-9)
        XCTAssertEqual(model.maxScrollY, 500, accuracy: 1e-9)
    }

    // MARK: - 2. Three positions are distinct; validated/published lag requested

    func testRequestScrollUpdatesRequestedOnlyUntilConverge() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )

        // Requester asks for an in-bounds position.
        model.requestScroll(x: 100, y: 50)

        // Requested reflects the ask immediately.
        XCTAssertEqual(model.requestedScrollX, 100)
        XCTAssertEqual(model.requestedScrollY, 50)

        // Validated and published have NOT moved yet (no convergence).
        XCTAssertEqual(model.validatedScrollX, 0)
        XCTAssertEqual(model.validatedScrollY, 0)
        XCTAssertEqual(model.publishedScrollX, 0)
        XCTAssertEqual(model.publishedScrollY, 0)

        // Converge reconciles validated + published.
        let event = model.converge()

        XCTAssertEqual(model.validatedScrollX, 100)
        XCTAssertEqual(model.validatedScrollY, 50)
        XCTAssertEqual(model.publishedScrollX, 100)
        XCTAssertEqual(model.publishedScrollY, 50)

        // The emitted event carries all three positions.
        XCTAssertEqual(event.requestedScrollX, 100)
        XCTAssertEqual(event.requestedScrollY, 50)
        XCTAssertEqual(event.validatedScrollX, 100)
        XCTAssertEqual(event.validatedScrollY, 50)
        XCTAssertEqual(event.publishedScrollX, 100)
        XCTAssertEqual(event.publishedScrollY, 50)
    }

    // MARK: - 3. Clamping: out-of-bounds high → clamped to maxScroll

    func testClampsRequestedBeyondMaxScrollToEnvelope() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        // maxScrollX = 600, maxScrollY = 500.
        model.requestScroll(x: 9999, y: 9999)
        let event = model.converge()

        // Requested preserves the raw (out-of-bounds) ask.
        XCTAssertEqual(model.requestedScrollX, 9999)
        XCTAssertEqual(model.requestedScrollY, 9999)

        // Validated is clamped to the envelope.
        XCTAssertEqual(model.validatedScrollX, 600, accuracy: 1e-9)
        XCTAssertEqual(model.validatedScrollY, 500, accuracy: 1e-9)

        // Published equals validated after converge.
        XCTAssertEqual(model.publishedScrollX, 600, accuracy: 1e-9)
        XCTAssertEqual(model.publishedScrollY, 500, accuracy: 1e-9)

        // Event reports both the raw requested and the clamped validated.
        XCTAssertEqual(event.requestedScrollX, 9999)
        XCTAssertEqual(event.validatedScrollX, 600, accuracy: 1e-9)
        XCTAssertEqual(event.publishedScrollX, 600, accuracy: 1e-9)
    }

    // MARK: - 4. Clamping: negative → clamped to 0

    func testClampsNegativeRequestedToZero() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        model.requestScroll(x: -50, y: -25)
        let event = model.converge()

        XCTAssertEqual(model.requestedScrollX, -50)
        XCTAssertEqual(model.requestedScrollY, -25)
        XCTAssertEqual(model.validatedScrollX, 0)
        XCTAssertEqual(model.validatedScrollY, 0)
        XCTAssertEqual(model.publishedScrollX, 0)
        XCTAssertEqual(model.publishedScrollY, 0)

        XCTAssertEqual(event.requestedScrollX, -50)
        XCTAssertEqual(event.validatedScrollX, 0)
        XCTAssertEqual(event.publishedScrollX, 0)
    }

    // MARK: - 5. Subpixel preservation (Double, not Int)

    func testSubpixelValuesPreservedAsDoubleThroughConverge() {
        let model = MonaScrollModel(
            contentWidth: 1000.0,
            contentHeight: 800.0,
            viewportWidth: 400.0,
            viewportHeight: 300.0
        )
        // A trackpad-derived fractional scroll request.
        model.requestScroll(x: 123.75, y: 45.25)
        let event = model.converge()

        // The fractional parts survive clamping and publish (Double, not Int).
        XCTAssertEqual(model.validatedScrollX, 123.75, accuracy: 1e-9)
        XCTAssertEqual(model.validatedScrollY, 45.25, accuracy: 1e-9)
        XCTAssertEqual(model.publishedScrollX, 123.75, accuracy: 1e-9)
        XCTAssertEqual(model.publishedScrollY, 45.25, accuracy: 1e-9)

        XCTAssertEqual(event.validatedScrollX, 123.75, accuracy: 1e-9)
        XCTAssertEqual(event.publishedScrollY, 45.25, accuracy: 1e-9)

        // Fractional clamping at the envelope edge is also preserved.
        model.requestScroll(x: 600.6, y: 500.4)
        let event2 = model.converge()
        // maxScrollX = 600.0, so 600.6 clamps to 600.0 (fractional part lost
        // only because it exceeds the envelope, not because of Int rounding).
        XCTAssertEqual(model.validatedScrollX, 600.0, accuracy: 1e-9)
        XCTAssertEqual(model.validatedScrollY, 500.0, accuracy: 1e-9)
        XCTAssertEqual(event2.publishedScrollX, 600.0, accuracy: 1e-9)
    }

    // MARK: - 6. Dimension convergence re-clamps in the frozen event order

    func testDimensionChangeReclampsValidatedOnNextConverge() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        // Scroll to the right edge.
        model.requestScroll(x: 600, y: 500)
        model.converge()
        XCTAssertEqual(model.publishedScrollX, 600, accuracy: 1e-9)
        XCTAssertEqual(model.publishedScrollY, 500, accuracy: 1e-9)

        // Content shrinks so the previous published position is now out of
        // bounds. The shrink must re-clamp on the NEXT converge (not before).
        model.setContentDimensions(width: 500, height: 400)
        // maxScrollX is now 100, maxScrollY is now 100.
        // Before converge, published still holds the stale (now out-of-bounds)
        // value — convergence is the only point that re-clamps.
        XCTAssertEqual(model.publishedScrollX, 600, accuracy: 1e-9)
        XCTAssertEqual(model.contentWidth, 500)

        let event = model.converge()
        // After converge, validated + published are re-clamped to the new
        // envelope (update dimensions → clamp requested → validate → publish).
        XCTAssertEqual(model.validatedScrollX, 100, accuracy: 1e-9)
        XCTAssertEqual(model.validatedScrollY, 100, accuracy: 1e-9)
        XCTAssertEqual(model.publishedScrollX, 100, accuracy: 1e-9)
        XCTAssertEqual(model.publishedScrollY, 100, accuracy: 1e-9)
        XCTAssertEqual(event.contentWidth, 500)
        XCTAssertEqual(event.contentHeight, 400)
    }

    func testViewportGrowthCanExposePreviouslyClampedScroll() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        // Viewport smaller than content: maxScrollX = 600.
        model.requestScroll(x: 700, y: 0)
        model.converge()
        XCTAssertEqual(model.publishedScrollX, 600, accuracy: 1e-9)

        // Viewport grows to cover all content: maxScrollX becomes 0.
        model.setViewportDimensions(width: 1000, height: 300)
        let event = model.converge()
        XCTAssertEqual(model.publishedScrollX, 0, accuracy: 1e-9)
        XCTAssertEqual(event.viewportWidth, 1000)
    }

    // MARK: - 7. Viewport larger than content → no scrollable room

    func testViewportLargerThanContentClampsToZero() {
        let model = MonaScrollModel(
            contentWidth: 200,
            contentHeight: 150,
            viewportWidth: 800,
            viewportHeight: 600
        )
        // maxScrollX = max(0, 200 - 800) = 0; maxScrollY = 0.
        XCTAssertEqual(model.maxScrollX, 0, accuracy: 1e-9)
        XCTAssertEqual(model.maxScrollY, 0, accuracy: 1e-9)

        model.requestScroll(x: 500, y: 500)
        let event = model.converge()
        XCTAssertEqual(model.validatedScrollX, 0)
        XCTAssertEqual(model.validatedScrollY, 0)
        XCTAssertEqual(model.publishedScrollX, 0)
        XCTAssertEqual(model.publishedScrollY, 0)
        XCTAssertEqual(event.publishedScrollX, 0)
    }

    // MARK: - 8. Converge emits scroll-change event with full state snapshot

    func testConvergeEmitsEventWithFullStateAndGeneration() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        model.requestScroll(x: 10, y: 20)
        XCTAssertNil(model.lastEmittedEvent)

        let event1 = model.converge()
        XCTAssertEqual(model.convergenceGeneration, 1)
        XCTAssertEqual(model.lastEmittedEvent, event1)
        XCTAssertEqual(event1.generation, 1)
        XCTAssertEqual(event1.contentWidth, 1000)
        XCTAssertEqual(event1.contentHeight, 800)
        XCTAssertEqual(event1.viewportWidth, 400)
        XCTAssertEqual(event1.viewportHeight, 300)
        XCTAssertEqual(event1.requestedScrollX, 10)
        XCTAssertEqual(event1.requestedScrollY, 20)
        XCTAssertEqual(event1.validatedScrollX, 10)
        XCTAssertEqual(event1.validatedScrollY, 20)
        XCTAssertEqual(event1.publishedScrollX, 10)
        XCTAssertEqual(event1.publishedScrollY, 20)

        // A second converge bumps the generation again and emits a fresh event
        // (distinct from the first by generation, even though scroll is unchanged).
        let event2 = model.converge()
        XCTAssertEqual(model.convergenceGeneration, 2)
        XCTAssertEqual(event2.generation, 2)
        XCTAssertNotEqual(event1, event2) // differ by generation
    }

    // MARK: - 9. Integer accessors truncate per V1-R3 |0 rule (for stamps)

    func testIntegerAccessorsTruncateForStampProduction() {
        let model = MonaScrollModel(
            contentWidth: 999.7,
            contentHeight: 800.2,
            viewportWidth: 400.0,
            viewportHeight: 300.0
        )
        model.requestScroll(x: 123.9, y: 45.1)
        model.converge()

        // V1-R3 |0 truncation (toward zero), not rounding.
        XCTAssertEqual(model.contentWidthInt, 999)
        XCTAssertEqual(model.contentHeightInt, 800)
        XCTAssertEqual(model.viewportWidthInt, 400)
        XCTAssertEqual(model.viewportHeightInt, 300)
        XCTAssertEqual(model.publishedScrollOffsetXInt, 123)
        XCTAssertEqual(model.publishedScrollOffsetYInt, 45)
    }

    func testIntegerAccessorsTruncateNegativeToZeroRange() {
        // Published scroll is always >= 0 (clamped), so the integer accessor
        // only needs to truncate non-negative values; verify a subpixel
        // published position truncates correctly.
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        model.requestScroll(x: 0.9, y: 0.1)
        model.converge()
        XCTAssertEqual(model.publishedScrollOffsetXInt, 0)
        XCTAssertEqual(model.publishedScrollOffsetYInt, 0)
    }

    // MARK: - 10. Stamp production integrates with P03-T004 dependency stamps

    func testScrollDimensionStampCarriesIntegerDimensions() {
        let model = MonaScrollModel(
            contentWidth: 999.7,
            contentHeight: 800.2,
            viewportWidth: 400.0,
            viewportHeight: 300.0
        )
        model.converge()

        let stamp = model.scrollDimensionStamp(viewportColumn: 50)
        XCTAssertEqual(stamp.contentWidth, 999)
        XCTAssertEqual(stamp.contentHeight, 800)
        XCTAssertEqual(stamp.viewportWidth, 400)
        XCTAssertEqual(stamp.viewportHeight, 300)
        XCTAssertEqual(stamp.viewportColumn, 50)
        XCTAssertEqual(MonaScrollDimensionStamp.domain, .scrollDimension)
    }

    func testFrameStampCarriesIntegerPublishedScrollOffset() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        model.requestScroll(x: 123.7, y: 45.2)
        model.converge()

        let stamp = model.frameStamp(generation: 7)
        XCTAssertEqual(stamp.scrollOffsetX, 123)
        XCTAssertEqual(stamp.scrollOffsetY, 45)
        XCTAssertEqual(stamp.generation, 7)
        XCTAssertEqual(MonaFrameStamp.domain, .frame)
    }

    // MARK: - 11. Independent axes: clamping one axis does not perturb the other

    func testAxesClampIndependently() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        // X in bounds, Y out of bounds.
        model.requestScroll(x: 100, y: 9999)
        model.converge()
        XCTAssertEqual(model.publishedScrollX, 100, accuracy: 1e-9)
        XCTAssertEqual(model.publishedScrollY, 500, accuracy: 1e-9)

        // Y in bounds, X out of bounds.
        model.requestScroll(x: 9999, y: 100)
        model.converge()
        XCTAssertEqual(model.publishedScrollX, 600, accuracy: 1e-9)
        XCTAssertEqual(model.publishedScrollY, 100, accuracy: 1e-9)
    }

    // MARK: - 12. Published only moves at converge (frozen publish step)

    func testPublishedOnlyAdvancesAtConverge() {
        let model = MonaScrollModel(
            contentWidth: 1000,
            contentHeight: 800,
            viewportWidth: 400,
            viewportHeight: 300
        )
        model.requestScroll(x: 50, y: 60)
        model.converge()
        XCTAssertEqual(model.publishedScrollX, 50)
        XCTAssertEqual(model.publishedScrollY, 60)

        // A new request does NOT move published until converge.
        model.requestScroll(x: 200, y: 300)
        XCTAssertEqual(model.requestedScrollX, 200)
        XCTAssertEqual(model.publishedScrollX, 50, "published must not advance without converge")
        XCTAssertEqual(model.validatedScrollX, 50, "validated must not advance without converge")

        model.converge()
        XCTAssertEqual(model.publishedScrollX, 200)
        XCTAssertEqual(model.publishedScrollY, 300)
    }
}
