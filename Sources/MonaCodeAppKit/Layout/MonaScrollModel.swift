// MonaScrollModel.swift
//
// P03-T005 — Implement scroll truth and dimension convergence.
//
// `MonaScrollModel` is the single source of scroll truth for the renderer. It
// separates three distinct scroll positions so that a requester's raw ask, the
// clamped truth, and the position actually emitted to the renderer never
// contaminate one another:
//
//   - `requestedScrollX/Y` — what the user/requester asked for. May be out of
//                            bounds; never silently clamped here.
//   - `validatedScrollX/Y` — clamped to the content bounds (the "truth" after
//                             validation). Updated only by `converge()`.
//   - `publishedScrollX/Y`  — the final position emitted to the renderer
//                             (after dimension convergence). Updated only by
//                             `converge()`; lags `requested` between
//                             convergences so the renderer never observes a
//                             pre-clamp or pre-dimension value.
//
// `converge()` reconciles content + viewport dimensions + clamping in the
// frozen event order:
//     1. update dimensions  — the current content/viewport dimensions define
//                              the clamp envelope (dimensions may have changed
//                              since the last convergence).
//     2. clamp requested      — clamp `requested` to `[0, maxScroll]`.
//     3. validate             — the clamped value becomes `validated` (truth).
//     4. publish               — `published = validated`; emit a scroll-change
//                              event recording all three positions + dimensions.
//
// Subpixel preservation: scroll values are `Double` (not `Int`). A trackpad's
// fractional residual is preserved through requested → validated → published
// and only truncated to integer logical points at the final surface transform
// (the renderer's rasterization / frame identity key). This honors:
//   - V1-R3 "纵向数值": Double prefix sums; integer contract applies only to
//     public scroll/dimension values (the frame identity key), not to the
//     internal subpixel phase.
//   - I3-R4 "保留 Double residual；写入公开 scroll state 时才服从 V1-R3
//     integer contract" — the Double residual is preserved internally; the
//     integer contract is satisfied by the integer accessors / stamps exposed
//     for frame-identity and public-API consumption.
//
// The integer accessors (`publishedScrollOffsetXInt`, `contentWidthInt`, …)
// truncate toward zero (V1-R3 `|0` rule) and feed the P03-T004 dependency
// stamps (`MonaScrollDimensionStamp`, `MonaFrameStamp`).

import Foundation
import CoreGraphics

// MARK: - MonaScrollChangeEvent

/// The scroll-change event emitted by `MonaScrollModel.converge()`.
///
/// Captures a full snapshot of the converged scroll truth: all three positions
/// (requested / validated / published), the four dimensions, and the convergence
/// generation. Callers diff against the previous event to detect whether the
/// published position actually moved.
public struct MonaScrollChangeEvent: Equatable, Sendable {

    /// The requester's raw horizontal ask (may be out of bounds).
    public let requestedScrollX: Double
    /// The requester's raw vertical ask (may be out of bounds).
    public let requestedScrollY: Double

    /// The clamped horizontal position (the truth).
    public let validatedScrollX: Double
    /// The clamped vertical position (the truth).
    public let validatedScrollY: Double

    /// The published horizontal position emitted to the renderer.
    public let publishedScrollX: Double
    /// The published vertical position emitted to the renderer.
    public let publishedScrollY: Double

    /// The observed content width (Double logical points).
    public let contentWidth: Double
    /// The content height (Double logical points).
    public let contentHeight: Double

    /// The viewport width (Double logical points).
    public let viewportWidth: Double
    /// The viewport height (Double logical points).
    public let viewportHeight: Double

    /// The convergence generation that produced this event (monotonic).
    public let generation: Int

    /// Creates a scroll-change event snapshot.
    public init(
        requestedScrollX: Double,
        requestedScrollY: Double,
        validatedScrollX: Double,
        validatedScrollY: Double,
        publishedScrollX: Double,
        publishedScrollY: Double,
        contentWidth: Double,
        contentHeight: Double,
        viewportWidth: Double,
        viewportHeight: Double,
        generation: Int
    ) {
        self.requestedScrollX = requestedScrollX
        self.requestedScrollY = requestedScrollY
        self.validatedScrollX = validatedScrollX
        self.validatedScrollY = validatedScrollY
        self.publishedScrollX = publishedScrollX
        self.publishedScrollY = publishedScrollY
        self.contentWidth = contentWidth
        self.contentHeight = contentHeight
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.generation = generation
    }
}

// MARK: - MonaScrollModel

/// The single source of scroll truth for the renderer.
///
/// Manages three distinct scroll positions — requested, validated, and
/// published — plus the content and viewport dimensions that define the clamp
/// envelope. `converge()` reconciles dimensions + clamping in the frozen event
/// order (update dimensions → clamp requested → validate → publish) and emits
/// a scroll-change event. Scroll values are `Double` so subpixel phase is
/// preserved until the renderer's final surface transform.
///
/// Thread-safety: instances are not thread-safe; the renderer pipeline that
/// owns one model is expected to drive it from a single coordinator. Value
/// semantics for the emitted event (`MonaScrollChangeEvent`) allow safe
/// snapshot handoff to the renderer.
public final class MonaScrollModel {

    // MARK: - The three scroll positions (Double for subpixel preservation)

    /// What the requester asked for horizontally (may be out of bounds).
    /// Updated immediately by `requestScroll(x:y:)`.
    public private(set) var requestedScrollX: Double

    /// What the requester asked for vertically (may be out of bounds).
    /// Updated immediately by `requestScroll(x:y:)`.
    public private(set) var requestedScrollY: Double

    /// The clamped horizontal position (the truth after validation).
    /// Updated only by `converge()`.
    public private(set) var validatedScrollX: Double

    /// The clamped vertical position (the truth after validation).
    /// Updated only by `converge()`.
    public private(set) var validatedScrollY: Double

    /// The final horizontal position emitted to the renderer.
    /// Updated only by `converge()`; equals `validatedScrollX` after a
    /// convergence. Lags `requestedScrollX` between convergences.
    public private(set) var publishedScrollX: Double

    /// The final vertical position emitted to the renderer.
    /// Updated only by `converge()`; equals `validatedScrollY` after a
    /// convergence. Lags `requestedScrollY` between convergences.
    public private(set) var publishedScrollY: Double

    // MARK: - Dimensions (Double for clean Double clamping)

    /// The observed content width (Double logical points; the raw pixel width
    /// of the longest line before integer truncation).
    public private(set) var contentWidth: Double

    /// The content height (Double logical points; from the Double vertical
    /// prefix sums before integer truncation).
    public private(set) var contentHeight: Double

    /// The viewport width (Double logical points).
    public private(set) var viewportWidth: Double

    /// The viewport height (Double logical points).
    public private(set) var viewportHeight: Double

    // MARK: - Convergence state

    /// The monotonic convergence generation (bumped on every `converge()`).
    public private(set) var convergenceGeneration: Int = 0

    /// The most recently emitted scroll-change event, or `nil` before the
    /// first `converge()`.
    public private(set) var lastEmittedEvent: MonaScrollChangeEvent?

    // MARK: - Init

    /// Creates a scroll model with the given content and viewport dimensions.
    ///
    /// All three scroll positions start at zero. No convergence has run; call
    /// `converge()` to publish the initial position and emit the first event.
    public init(
        contentWidth: Double,
        contentHeight: Double,
        viewportWidth: Double,
        viewportHeight: Double
    ) {
        self.contentWidth = contentWidth
        self.contentHeight = contentHeight
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight

        self.requestedScrollX = 0
        self.requestedScrollY = 0
        self.validatedScrollX = 0
        self.validatedScrollY = 0
        self.publishedScrollX = 0
        self.publishedScrollY = 0
    }

    // MARK: - Live setters (requester + dimension inputs)

    /// Records the requester's raw scroll ask.
    ///
    /// The ask is stored immediately in `requestedScrollX/Y` and may be out of
    /// bounds; clamping happens later in `converge()`. `validated` and
    /// `published` do not move until the next `converge()`.
    public func requestScroll(x: Double, y: Double) {
        requestedScrollX = x
        requestedScrollY = y
    }

    /// Updates the content dimensions.
    ///
    /// The new dimensions take effect as the clamp envelope at the next
    /// `converge()` (frozen order: update dimensions → clamp → validate →
    /// publish). `contentWidth`/`contentHeight` are updated immediately so
    /// `maxScrollX/Y` reflect the new envelope right away, but `validated`
    /// and `published` are re-clamped only by `converge()`.
    public func setContentDimensions(width: Double, height: Double) {
        contentWidth = width
        contentHeight = height
    }

    /// Updates the viewport dimensions.
    public func setViewportDimensions(width: Double, height: Double) {
        viewportWidth = width
        viewportHeight = height
    }

    // MARK: - Derived clamp envelope

    /// The maximum horizontal scroll offset (`max(0, contentWidth - viewportWidth)`).
    public var maxScrollX: Double {
        return max(0, contentWidth - viewportWidth)
    }

    /// The maximum vertical scroll offset (`max(0, contentHeight - viewportHeight)`).
    public var maxScrollY: Double {
        return max(0, contentHeight - viewportHeight)
    }

    // MARK: - Converge (frozen event order)

    /// Reconciles content + viewport dimensions + clamping in the frozen event
    /// order and emits a scroll-change event.
    ///
    /// Frozen order:
    ///   1. update dimensions — the current dimensions define the clamp
    ///      envelope (they may have changed since the last convergence).
    ///   2. clamp requested   — clamp `requested` to `[0, maxScroll]`.
    ///   3. validate           — the clamped value becomes `validated`.
    ///   4. publish             — `published = validated`; emit event.
    ///
    /// Subpixel values are preserved throughout (all `Double`); integer
    /// truncation happens only at the integer accessors / stamps consumed by
    /// the frame identity key and the renderer's surface transform.
    ///
    /// - Returns: The emitted scroll-change event.
    @discardableResult
    public func converge() -> MonaScrollChangeEvent {
        // Step 1: update dimensions — read the current clamp envelope.
        // (Dimensions are set immediately by their setters; this step fixes
        // the envelope used for this convergence.)
        let envelopeMaxX = maxScrollX
        let envelopeMaxY = maxScrollY

        // Step 2: clamp requested to [0, envelopeMax].
        let clampedX = clampNonNegative(requestedScrollX, max: envelopeMaxX)
        let clampedY = clampNonNegative(requestedScrollY, max: envelopeMaxY)

        // Step 3: validate — the clamped value is the truth.
        validatedScrollX = clampedX
        validatedScrollY = clampedY

        // Step 4: publish — emit validated as the published position.
        publishedScrollX = validatedScrollX
        publishedScrollY = validatedScrollY
        convergenceGeneration &+= 1

        let event = MonaScrollChangeEvent(
            requestedScrollX: requestedScrollX,
            requestedScrollY: requestedScrollY,
            validatedScrollX: validatedScrollX,
            validatedScrollY: validatedScrollY,
            publishedScrollX: publishedScrollX,
            publishedScrollY: publishedScrollY,
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            generation: convergenceGeneration
        )
        lastEmittedEvent = event
        return event
    }

    // MARK: - Integer accessors (V1-R3 |0 truncation, for stamps / public API)

    /// The published horizontal scroll offset truncated to integer logical
    /// points (V1-R3 `|0` rule, toward zero). Consumed by the frame identity
    /// key (`MonaFrameStamp`) and the public scroll API.
    public var publishedScrollOffsetXInt: Int {
        return Int(publishedScrollX.rounded(.towardZero))
    }

    /// The published vertical scroll offset truncated to integer logical points.
    public var publishedScrollOffsetYInt: Int {
        return Int(publishedScrollY.rounded(.towardZero))
    }

    /// The content width truncated to integer logical points.
    public var contentWidthInt: Int {
        return Int(contentWidth.rounded(.towardZero))
    }

    /// The content height truncated to integer logical points.
    public var contentHeightInt: Int {
        return Int(contentHeight.rounded(.towardZero))
    }

    /// The viewport width truncated to integer logical points.
    public var viewportWidthInt: Int {
        return Int(viewportWidth.rounded(.towardZero))
    }

    /// The viewport height truncated to integer logical points.
    public var viewportHeightInt: Int {
        return Int(viewportHeight.rounded(.towardZero))
    }

    // MARK: - Stamp production (integration with P03-T004)

    /// Builds the `MonaScrollDimensionStamp` (the scroll-dimension domain
    /// identity key) from the current integer-truncated dimensions.
    ///
    /// `viewportColumn` is provided by the caller (it depends on font metrics,
    /// which the scroll model deliberately does not own) — this keeps the model
    /// font-agnostic while still producing the complete stamp.
    public func scrollDimensionStamp(viewportColumn: Int) -> MonaScrollDimensionStamp {
        return MonaScrollDimensionStamp(
            contentWidth: contentWidthInt,
            contentHeight: contentHeightInt,
            viewportWidth: viewportWidthInt,
            viewportHeight: viewportHeightInt,
            viewportColumn: viewportColumn
        )
    }

    /// Builds the `MonaFrameStamp` (the frame domain identity key) from the
    /// current integer-truncated published scroll offset.
    ///
    /// `generation` is the frame generation supplied by the frame coordinator
    /// (distinct from the scroll model's `convergenceGeneration`).
    public func frameStamp(generation: Int) -> MonaFrameStamp {
        return MonaFrameStamp(
            scrollOffsetX: publishedScrollOffsetXInt,
            scrollOffsetY: publishedScrollOffsetYInt,
            generation: generation
        )
    }

    // MARK: - Private

    /// Clamps `value` to `[0, max]`. If `max < 0` (viewport larger than
    /// content), the result is `0`.
    private func clampNonNegative(_ value: Double, max: Double) -> Double {
        let upper = Swift.max(0, max)
        return Swift.max(0, Swift.min(value, upper))
    }
}
