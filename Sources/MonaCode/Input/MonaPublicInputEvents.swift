// MonaPublicInputEvents.swift
//
// P04-T007 — Implement public EventControl and native event adaptation.
//
// The three public input event value types adapt the Core platform-neutral
// input events for the PUBLIC callback surface:
//
//   - `MonaPublicKeyboardEvent` — projects the fields of `MonaKeyEvent`
//                                  (P04-T001) into public native-adapted values.
//   - `MonaPublicMouseEvent`    — projects the fields of `MonaPointerEvent`
//                                  (P04-T006) into public native-adapted values.
//   - `MonaPublicScrollEvent`   — projects the fields of `MonaScrollEvent`
//                                  (P04-T006) into public native-adapted values.
//
// All three are IMMUTABLE value types (structs with `let` stored properties).
// A public callback receives one of these snapshots and can READ its fields,
// but it CANNOT mutate the underlying native event object: the public event is
// a value copy of the platform-neutral fields, not a reference to the native
// `NSEvent` and not a wrapper holding the source `MonaKeyEvent` /
// `MonaPointerEvent` / `MonaScrollEvent`. There is no path from the public
// event back to a native object.
//
// The dispatch DECISION (prevent-default / stop-propagation) is signaled
// through a SEPARATE `MonaEventControl` handle (see `MonaEventControl.swift`),
// not stored on the event. This keeps the event data the callback reads fully
// immutable and decoupled from the mutable control the callback writes — the
// event carries no control reference, and mutating the control never alters the
// event's fields.
//
// Coordinate representation: the Core target is Foundation-only (no CoreGraphics),
// so pointer/scroll viewport coordinates use `MonaPublicPoint` (Double x/y),
// not `CGPoint`. The model position uses `MonaPosition` (P01-T001), the same
// raw-UTF-16 line/column value type the rest of Core uses.
//
// The `MonaPublicMouseButton`, `MonaPublicMousePhase`, `MonaPublicScrollPhase`,
// and `MonaPublicPoint` helper types are Foundation-only public mirrors of the
// AppKit-side `MonaPointerButton` / `MonaPointerEventPhase` / `MonaScrollPhase`
// (P04-T006). They carry the same semantics so the AppKit adapter can project a
// `MonaPointerEvent` / `MonaScrollEvent` into the public event field-for-field
// without loss. Defining them here (in Core) keeps the public callback surface
// free of any AppKit dependency.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaPublicPoint

/// A Foundation-only 2D point used for public input-event viewport coordinates.
///
/// The Core target has no CoreGraphics dependency, so pointer/scroll events
/// carry their viewport location as a `MonaPublicPoint` (Double x/y) rather than
/// a `CGPoint`. The AppKit adapter converts `NSEvent.locationInWindow` → view
/// space (`CGPoint`) → `MonaPublicPoint` when projecting the public event.
public struct MonaPublicPoint: Equatable, Hashable, Sendable {

    /// The horizontal coordinate.
    public let x: Double

    /// The vertical coordinate.
    public let y: Double

    /// Creates a point from its coordinates.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - MonaPublicMouseButton

/// A public mouse button, mirroring the AppKit-side `MonaPointerButton`.
///
/// macOS button numbering: 0=left, 1=right, 2=middle, others≥3=`.other(_:)`.
/// The integer for `.other` is preserved verbatim so exotic buttons are not
/// collapsed to a known case.
public enum MonaPublicMouseButton: Equatable, Hashable, Sendable {

    /// The primary (left) button.
    case left

    /// The secondary (right) button.
    case right

    /// The middle (center) button.
    case middle

    /// Any other button — `Int` preserved verbatim.
    case other(Int)
}

// MARK: - MonaPublicMousePhase

/// The phase of a public mouse event, mirroring `MonaPointerEventPhase`.
public enum MonaPublicMousePhase: Equatable, Hashable, Sendable {

    /// A button press.
    case down

    /// A button release.
    case up

    /// A movement with no button held.
    case moved

    /// A movement with a button held (drag).
    case dragged
}

// MARK: - MonaPublicScrollPhase

/// A public scroll phase, mirroring the AppKit-side `MonaScrollPhase`.
public enum MonaPublicScrollPhase: Equatable, Hashable, Sendable {

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

// MARK: - MonaPublicKeyboardEvent

/// A public, immutable snapshot of a keyboard event.
///
/// Projects the platform-neutral fields of a `MonaKeyEvent` (P04-T001) into
/// public native-adapted values. A public callback receives this snapshot and
/// reads its fields; it cannot mutate the underlying native event because the
/// snapshot holds no reference back to it (value copy, no wrapper).
///
/// The dispatch decision is signaled through a separate `MonaEventControl`,
/// not stored here.
public struct MonaPublicKeyboardEvent: Equatable, Hashable {

    /// The logical key code (P01-T004). Unknown values are preserved via
    /// `MonaKeyCode.custom(_:)` and are not collapsed.
    public let keyCode: MonaKeyCode

    /// The scan-independent text the key produces, or `nil` for non-printing
    /// keys.
    public let keyText: String?

    /// The active modifier set (P01-T004).
    public let modifiers: MonaKeyMod

    /// `true` when this event is a hardware key repeat (key held), not a fresh
    /// press.
    public let isRepeat: Bool

    /// `true` while an IME composition is in progress.
    public let isComposing: Bool

    /// The event timestamp in the platform's native time base, carried verbatim
    /// for ordering.
    public let timestamp: Double

    /// Creates a public keyboard event snapshot from its projected fields.
    public init(
        keyCode: MonaKeyCode,
        keyText: String?,
        modifiers: MonaKeyMod,
        isRepeat: Bool,
        isComposing: Bool,
        timestamp: Double
    ) {
        self.keyCode = keyCode
        self.keyText = keyText
        self.modifiers = modifiers
        self.isRepeat = isRepeat
        self.isComposing = isComposing
        self.timestamp = timestamp
    }

    /// Creates a public keyboard event snapshot by projecting the fields of a
    /// `MonaKeyEvent` (P04-T001).
    ///
    /// The snapshot is a value copy of the source's fields; it holds no
    /// reference to the source `MonaKeyEvent` and no reference to any platform
    /// native event. Mutating the source after projection (where possible) does
    /// not affect this snapshot.
    public init(projectingFrom source: MonaKeyEvent) {
        self.keyCode = source.keyCode
        self.keyText = source.keyText
        self.modifiers = source.modifiers
        self.isRepeat = source.isRepeat
        self.isComposing = source.isComposing
        self.timestamp = source.timestamp
    }
}

// MARK: - MonaPublicMouseEvent

/// A public, immutable snapshot of a mouse (pointer) event.
///
/// Projects the platform-neutral fields of a `MonaPointerEvent` (P04-T006) into
/// Foundation-only public values. Viewport coordinates use `MonaPublicPoint`
/// (no CoreGraphics dependency in Core). A public callback receives this
/// snapshot and reads its fields; it cannot mutate the underlying native event
/// because the snapshot holds no reference back to it.
///
/// The dispatch decision is signaled through a separate `MonaEventControl`,
/// not stored here.
public struct MonaPublicMouseEvent: Equatable, Hashable {

    /// The translated button.
    public let button: MonaPublicMouseButton

    /// The event phase (down / up / moved / dragged).
    public let phase: MonaPublicMousePhase

    /// The raw click count, carried verbatim as input. The Monaco 400 ms /
    /// same-position clamp is a Core concern, not projected here.
    public let clickCount: Int

    /// The active modifier set.
    public let modifiers: MonaKeyMod

    /// Force-touch pressure in [0, 1], carried as a `Double`.
    public let pressure: Double

    /// The viewport-space point (Foundation-only; the AppKit adapter converts
    /// from `CGPoint`).
    public let viewportPoint: MonaPublicPoint

    /// The model position resolved through the geometry barrier, or `nil` when
    /// the barrier was absent or returned an unavailable reason.
    public let resolvedPosition: MonaPosition?

    /// The event timestamp in the platform's native time base, carried verbatim
    /// for ordering.
    public let timestamp: Double

    /// Creates a public mouse event snapshot from its projected fields.
    public init(
        button: MonaPublicMouseButton,
        phase: MonaPublicMousePhase,
        clickCount: Int,
        modifiers: MonaKeyMod,
        pressure: Double,
        viewportPoint: MonaPublicPoint,
        resolvedPosition: MonaPosition?,
        timestamp: Double
    ) {
        self.button = button
        self.phase = phase
        self.clickCount = clickCount
        self.modifiers = modifiers
        self.pressure = pressure
        self.viewportPoint = viewportPoint
        self.resolvedPosition = resolvedPosition
        self.timestamp = timestamp
    }
}

// MARK: - MonaPublicScrollEvent

/// A public, immutable snapshot of a scroll / pinch event.
///
/// Projects the platform-neutral fields of a `MonaScrollEvent` (P04-T006) into
/// Foundation-only public values. A public callback receives this snapshot and
/// reads its fields; it cannot mutate the underlying native event because the
/// snapshot holds no reference back to it.
///
/// The dispatch decision is signaled through a separate `MonaEventControl`,
/// not stored here.
public struct MonaPublicScrollEvent: Equatable, Hashable {

    /// The normalized horizontal delta. Precise deltas are
    /// `scrollingDeltaX ÷ 40`; coarse deltas are carried verbatim.
    public let deltaX: Double

    /// The normalized vertical delta. Precise deltas are
    /// `scrollingDeltaY ÷ 40`; coarse deltas are carried verbatim.
    public let deltaY: Double

    /// `true` when the source event had precise scrolling deltas; `false` for
    /// coarse (line-based) deltas.
    public let isPrecise: Bool

    /// The scroll phase, projected from `NSEvent.phase`.
    public let phase: MonaPublicScrollPhase

    /// The momentum phase, projected from `NSEvent.momentumPhase`. After the
    /// user lifts their fingers, AppKit delivers momentum scroll events with
    /// `phase = .none` and `momentumPhase != .none`.
    public let momentumPhase: MonaPublicScrollPhase

    /// The pinch-zoom magnification delta, carried verbatim from
    /// `NSEvent.magnification` for magnify-type events. `0` for scrollWheel
    /// events.
    public let magnification: Double

    /// The viewport-space point (Foundation-only).
    public let viewportPoint: MonaPublicPoint

    /// The model position resolved through the geometry barrier, or `nil` when
    /// the barrier was absent or returned an unavailable reason.
    public let resolvedPosition: MonaPosition?

    /// The active modifier set.
    public let modifiers: MonaKeyMod

    /// The event timestamp in the platform's native time base, carried verbatim
    /// for ordering.
    public let timestamp: Double

    /// Creates a public scroll event snapshot from its projected fields.
    public init(
        deltaX: Double,
        deltaY: Double,
        isPrecise: Bool,
        phase: MonaPublicScrollPhase,
        momentumPhase: MonaPublicScrollPhase,
        magnification: Double,
        viewportPoint: MonaPublicPoint,
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
