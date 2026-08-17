// MonaScrollGateway.swift
//
// P04-T006 — Project pointer, scroll, and context-menu events through AppKit.
//
// `MonaScrollGateway` is the SINGLE native boundary that translates an AppKit
// `NSEvent` scrollWheel (and magnify) event into the platform-neutral
// `MonaScrollEvent`. The rest of Core operates on `MonaScrollEvent` and never
// touches `NSEvent`. This is the one place where AppKit scroll fields become
// Core values.
//
// Responsibilities (per the I3-R4 closure):
//
//   1. Translate EXACTLY ONCE. Each `NSEvent` is mapped to one `MonaScrollEvent`
//      in a single, pure step.
//   2. Delta normalization (the Monaco StandardWheel contract):
//        - precise scrollingDeltas (hasPreciseScrollingDeltas = true) are
//          AppKit points ÷ 40. Each AppKit point of precise delta produces 1.25
//          points of Monaco displacement (40 ÷ 40 ... wait: precise delta is
//          `scrollingDeltaX/Y`; the Monaco delta is `scrollingDelta ÷ 40`).
//        - coarse (line-based) deltas are carried verbatim.
//        - AppKit's positive direction already matches Monaco's StandardWheel
//          and is already reversed for natural scrolling; the gateway MUST NOT
//          reverse again.
//        - The Double residual is preserved here; the public integer scroll
//          state contract is a downstream concern.
//   3. Translate scroll phases (began / changed / ended / cancelled / mayBegin)
//      from `NSEvent.phase` and `NSEvent.momentumPhase`.
//   4. Translate magnification (pinch zoom) from `NSEvent.magnification` for
//      magnify-type events. Magnification is ONLY read for magnify-type events;
//      reading `.magnification` on a scrollWheel event throws an
//      `NSInternalInconsistencyException`, so the gateway type-guards the read.
//   5. Resolve the target position through the geometry barrier (P03-T007)
//      before Core command dispatch.
//
// The pure `translateFields(...)` static method performs the field translation
// without any `NSEvent` dependency; it is the exhaustively testable translation
// step. The `translate(_:...)` instance method reads fields from a real
// `NSEvent` and delegates to it.
//
// `MonaCodeAppKit` may `import AppKit`, `import CoreGraphics`,
// `import Foundation`, and `import MonaCode`.

import AppKit
import CoreGraphics
import Foundation
import MonaCode

// MARK: - MonaScrollPhase

/// A platform-neutral scroll phase, projected from `NSEvent.Phase`.
public enum MonaScrollPhase: Equatable, Hashable, Sendable {

    /// No active phase (no gesture in progress).
    case none

    /// The scroll gesture began.
    case began

    /// The scroll gesture changed (continued).
    case changed

    /// The scroll gesture ended.
    case ended

    /// The scroll gesture was cancelled.
    case cancelled

    /// The scroll gesture may begin (a touch anticipates a scroll).
    case mayBegin
}

// MARK: - MonaScrollEvent

/// A platform-neutral scroll / pinch event.
///
/// Constructed once at the platform boundary (`MonaScrollGateway`) and consumed
/// by the Core scroll/zoom pipeline. Carries no platform type.
public struct MonaScrollEvent: Equatable, Hashable {

    /// The normalized horizontal delta. Precise deltas are
    /// `scrollingDeltaX ÷ 40`; coarse deltas are carried verbatim.
    public let deltaX: Double

    /// The normalized vertical delta. Precise deltas are
    /// `scrollingDeltaY ÷ 40`; coarse deltas are carried verbatim.
    public let deltaY: Double

    /// `true` when the source event had precise scrolling deltas (AppKit
    /// points); `false` for coarse (line-based) deltas.
    public let isPrecise: Bool

    /// The scroll phase, projected from `NSEvent.phase`.
    public let phase: MonaScrollPhase

    /// The momentum phase, projected from `NSEvent.momentumPhase`. After the
    /// user lifts their fingers, AppKit delivers momentum scroll events with
    /// `phase = .none` and `momentumPhase != .none`.
    public let momentumPhase: MonaScrollPhase

    /// The pinch-zoom magnification delta, carried verbatim from
    /// `NSEvent.magnification` for magnify-type events. `0` for scrollWheel
    /// events.
    public let magnification: Double

    /// The viewport-space point supplied by the caller.
    public let viewportPoint: CGPoint

    /// The model position resolved through the geometry barrier, or `nil` when
    /// the barrier is absent or returns a typed unavailable reason.
    public let resolvedPosition: MonaPosition?

    /// The active modifier set, mapped from `NSEvent.modifierFlags`.
    public let modifiers: MonaKeyMod

    /// The event timestamp in the platform's native time base, carried verbatim
    /// for ordering.
    public let timestamp: Double

    /// Creates a platform-neutral scroll event.
    public init(
        deltaX: Double,
        deltaY: Double,
        isPrecise: Bool,
        phase: MonaScrollPhase,
        momentumPhase: MonaScrollPhase,
        magnification: Double,
        viewportPoint: CGPoint,
        resolvedPosition: MonaPosition?,
        modifiers: MonaKeyMod,
        timestamp: Double
    ) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.isPrecise = isPrecise
        self.phase = phase
        self.momentumPhase = momentumPhase
        self.magnification = magnification
        self.viewportPoint = viewportPoint
        self.resolvedPosition = resolvedPosition
        self.modifiers = modifiers
        self.timestamp = timestamp
    }
}

// MARK: - MonaScrollGateway

/// The single native gateway that translates AppKit `NSEvent` scrollWheel (and
/// magnify) events into platform-neutral `MonaScrollEvent` values, resolving
/// the target position through the geometry barrier before Core command
/// dispatch.
///
/// Stateless: two calls with equal inputs produce equal outputs.
public final class MonaScrollGateway {

    /// Creates a gateway. The gateway is stateless; the initializer exists so
    /// callers hold an instance (matching the "one native gateway per editor"
    /// boundary) rather than reaching for statics.
    public init() {}

    /// The StandardWheel constant: precise AppKit deltas are divided by this to
    /// yield Monaco deltas (matching Monaco's `StandardWheel` pixel÷40).
    static let preciseDeltaDivisor: Double = 40

    // MARK: - NSEvent → MonaScrollEvent

    /// Translates a scrollWheel or magnify `NSEvent` into a `MonaScrollEvent`.
    ///
    /// The gateway reads the appropriate fields based on `event.type`:
    ///
    ///   - `.scrollWheel`: reads `scrollingDeltaX/Y`, `hasPreciseScrollingDeltas`,
    ///     `phase`, `momentumPhase`; `magnification` is 0 (reading
    ///     `NSEvent.magnification` on a scrollWheel event throws an
    ///     `NSInternalInconsistencyException`).
    ///   - `.magnify` / `.smartMagnify` / `.beginGesture` / `.endGesture`:
    ///     reads `magnification` and `phase`; `scrollingDelta` is 0 and
    ///     `hasPreciseScrollingDeltas` is `false`.
    ///   - Other event types: produce a zero / `.none` event (defensive).
    ///
    /// - Parameters:
    ///   - event: The scrollWheel / magnify `NSEvent`.
    ///   - viewportPoint: The event location in viewport (view) space.
    ///   - barrier: The geometry barrier (P03-T007) used to resolve the
    ///     viewport point to a model position before Core dispatch.
    /// - Returns: The platform-neutral `MonaScrollEvent`. Translated exactly once.
    public func translate(
        _ event: NSEvent,
        viewportPoint: CGPoint,
        resolvingPositionThrough barrier: MonaQueryGeometryBarrier?
    ) -> MonaScrollEvent {
        switch event.type {
        case .scrollWheel:
            return Self.translateFields(
                scrollingDeltaX: event.scrollingDeltaX,
                scrollingDeltaY: event.scrollingDeltaY,
                hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas,
                phase: event.phase,
                momentumPhase: event.momentumPhase,
                magnification: 0,
                modifiers: event.modifierFlags,
                viewportPoint: viewportPoint,
                timestamp: event.timestamp,
                resolvingPositionThrough: barrier
            )
        case .magnify, .smartMagnify, .beginGesture, .endGesture:
            // Magnify events carry magnification and a phase; they do not carry
            // scroll deltas. `scrollingDeltaY` is NOT read here (it would throw
            // on a magnify event, symmetric to the scrollWheel magnification
            // case).
            return Self.translateFields(
                scrollingDeltaX: 0,
                scrollingDeltaY: 0,
                hasPreciseScrollingDeltas: false,
                phase: event.phase,
                momentumPhase: event.momentumPhase,
                magnification: event.magnification,
                modifiers: event.modifierFlags,
                viewportPoint: viewportPoint,
                timestamp: event.timestamp,
                resolvingPositionThrough: barrier
            )
        default:
            // A non-scroll event routed here is translated as a no-op scroll so
            // the gateway never synthesizes partial data.
            return Self.translateFields(
                scrollingDeltaX: 0,
                scrollingDeltaY: 0,
                hasPreciseScrollingDeltas: false,
                phase: [],
                momentumPhase: [],
                magnification: 0,
                modifiers: event.modifierFlags,
                viewportPoint: viewportPoint,
                timestamp: event.timestamp,
                resolvingPositionThrough: barrier
            )
        }
    }

    // MARK: - Pure field translation (testable without NSEvent)

    /// The pure, testable translation step: maps the extracted scroll fields to
    /// a `MonaScrollEvent` without any `NSEvent` dependency. Declared as an
    /// instance method so callers use the same gateway instance for both the
    /// `NSEvent`-based and the field-based entry points; it does not read
    /// `self`.
    ///
    /// Precise deltas (`hasPreciseScrollingDeltas = true`) are divided by 40
    /// (the Monaco StandardWheel constant); coarse deltas are carried verbatim.
    /// The AppKit positive direction is preserved (NOT reversed). The Double
    /// residual is preserved.
    ///
    /// - Parameters:
    ///   - scrollingDeltaX: The raw horizontal scroll delta from `NSEvent`.
    ///   - scrollingDeltaY: The raw vertical scroll delta from `NSEvent`.
    ///   - hasPreciseScrollingDeltas: Whether the source had precise (point)
    ///     deltas.
    ///   - phase: The `NSEvent.phase` of the source event.
    ///   - momentumPhase: The `NSEvent.momentumPhase` of the source event.
    ///   - magnification: The magnification delta (0 for scrollWheel events).
    ///   - modifiers: The modifier flags of the source event.
    ///   - viewportPoint: The event location in viewport (view) space.
    ///   - timestamp: The event timestamp.
    ///   - barrier: The geometry barrier used to resolve the viewport point.
    /// - Returns: The platform-neutral `MonaScrollEvent`.
    public static func translateFields(
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        hasPreciseScrollingDeltas: Bool,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        magnification: CGFloat,
        modifiers: NSEvent.ModifierFlags,
        viewportPoint: CGPoint,
        timestamp: Double,
        resolvingPositionThrough barrier: MonaQueryGeometryBarrier?
    ) -> MonaScrollEvent {
        let divisor: Double = hasPreciseScrollingDeltas ? preciseDeltaDivisor : 1
        let deltaX = Double(scrollingDeltaX) / divisor
        let deltaY = Double(scrollingDeltaY) / divisor
        let resolved = MonaPointerGateway.resolve(
            viewportPoint: viewportPoint, through: barrier
        )
        return MonaScrollEvent(
            deltaX: deltaX,
            deltaY: deltaY,
            isPrecise: hasPreciseScrollingDeltas,
            phase: monaPhase(for: phase),
            momentumPhase: monaPhase(for: momentumPhase),
            magnification: Double(magnification),
            viewportPoint: viewportPoint,
            resolvedPosition: resolved,
            modifiers: MonaPointerGateway.monaModifiers(for: modifiers),
            timestamp: timestamp
        )
    }

    /// Instance entry point delegating to the pure static `translateFields`.
    public func translateFields(
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        hasPreciseScrollingDeltas: Bool,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        magnification: CGFloat,
        modifiers: NSEvent.ModifierFlags,
        viewportPoint: CGPoint,
        timestamp: Double,
        resolvingPositionThrough barrier: MonaQueryGeometryBarrier?
    ) -> MonaScrollEvent {
        return Self.translateFields(
            scrollingDeltaX: scrollingDeltaX,
            scrollingDeltaY: scrollingDeltaY,
            hasPreciseScrollingDeltas: hasPreciseScrollingDeltas,
            phase: phase,
            momentumPhase: momentumPhase,
            magnification: magnification,
            modifiers: modifiers,
            viewportPoint: viewportPoint,
            timestamp: timestamp,
            resolvingPositionThrough: barrier
        )
    }

    // MARK: - Static field translators

    /// Maps an `NSEvent.Phase` (an OptionSet) to a `MonaScrollPhase`.
    ///
    /// NSEvent.Phase is an OptionSet but a single scroll event carries exactly
    /// one phase value. The mapping checks each flag in a stable priority order
    /// (cancelled mayBegin, began, changed, ended) and returns `.none` for an
    /// empty set.
    public static func monaPhase(for phase: NSEvent.Phase) -> MonaScrollPhase {
        if phase.contains(.cancelled) { return .cancelled }
        if phase.contains(.mayBegin)  { return .mayBegin }
        if phase.contains(.began)     { return .began }
        if phase.contains(.changed)   { return .changed }
        if phase.contains(.ended)     { return .ended }
        return .none
    }
}

// MARK: - MonaScrollGateway.Sendable

// The gateway holds no stored state, so it is safe to share across isolation
// boundaries.
extension MonaScrollGateway: @unchecked Sendable {}
