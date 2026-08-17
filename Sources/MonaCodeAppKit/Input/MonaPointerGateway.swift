// MonaPointerGateway.swift
//
// P04-T006 — Project pointer, scroll, and context-menu events through AppKit.
//
// `MonaPointerGateway` is the SINGLE native boundary that translates an AppKit
// `NSEvent` mouse event (mouseDown / mouseUp / mouseMoved / mouseDragged /
// otherMouse*) into the platform-neutral `MonaPointerEvent`. The rest of Core
// operates on `MonaPointerEvent` and never touches `NSEvent`. This is the one
// place where AppKit mouse-event fields become Core values.
//
// Responsibilities (per the I3-R4 closure):
//
//   1. Translate EXACTLY ONCE. Each `NSEvent` is mapped to one
//      `MonaPointerEvent` in a single, pure step. There is no re-translation
//      path and no mutating gateway state that could double-apply a translation.
//   2. Translate the mouse-event snapshot fields:
//        - button number     — left=0, right=1, middle=2, others≥3 →
//                              `MonaPointerButton`.
//        - click count       — `NSEvent.clickCount` carried verbatim as input.
//                              The Monaco 400 ms / same-logical-position clamp
//                              is a Core concern (not this gateway); the
//                              gateway does not clamp.
//        - modifiers         — Command→CtrlCmd, Control→WinCtrl, Option→Alt,
//                              Shift→Shift (matching `MonaAppKeyEventGateway`).
//        - pressure         — force-touch pressure as a `Double` in [0, 1].
//        - coordinates      — the viewport-space point (supplied by the caller,
//                              which converts `NSEvent.locationInWindow` to
//                              view space) is carried, AND resolved to a model
//                              position through the geometry barrier
//                              (P03-T007) before Core command dispatch.
//   3. Resolve the target position through the geometry barrier BEFORE Core
//      command dispatch. When the barrier is absent or returns a typed
//      unavailable reason, `resolvedPosition` is `nil` (no partial geometry is
//      synthesized).
//
// The live `NSEvent` is never retained: the gateway reads the immutable field
// snapshot once and produces an immutable value type. The caller owns the
// `NSEvent` and the `NSResponder` flow.
//
// `MonaCodeAppKit` may `import AppKit`, `import CoreGraphics`,
// `import Foundation`, and `import MonaCode`.

import AppKit
import CoreGraphics
import Foundation
import MonaCode

// MARK: - MonaPointerButton

/// A platform-neutral mouse button, mapped from the macOS button number.
///
/// macOS button numbering: 0=left, 1=right, 2=middle, others≥3=other. The
/// integer for `.other` is preserved verbatim so exotic buttons are not
/// collapsed.
public enum MonaPointerButton: Equatable, Hashable, Sendable {

    /// The primary (left) button — macOS buttonNumber 0.
    case left

    /// The secondary (right) button — macOS buttonNumber 1.
    case right

    /// The middle (center) button — macOS buttonNumber 2.
    case middle

    /// Any other button — `Int` preserved verbatim.
    case other(Int)
}

// MARK: - MonaPointerEventPhase

/// The phase of a pointer event, projected from the AppKit mouse event type.
public enum MonaPointerEventPhase: Equatable, Hashable, Sendable {

    /// A button press (mouseDown / rightMouseDown / otherMouseDown).
    case down

    /// A button release (mouseUp / rightMouseUp / otherMouseUp).
    case up

    /// A movement with no button held (mouseMoved).
    case moved

    /// A movement with a button held (mouseDragged / leftMouseDragged).
    case dragged
}

// MARK: - MonaPointerEvent

/// A platform-neutral pointer (mouse) event.
///
/// Constructed once at the platform boundary (`MonaPointerGateway`) and consumed
/// by the Core pointer-dispatch pipeline. Carries no platform type; the platform
/// layer reads the resolved position and applies dispatch outcomes at the native
/// boundary.
public struct MonaPointerEvent: Equatable, Hashable {

    /// The translated button.
    public let button: MonaPointerButton

    /// The event phase (down / up / moved / dragged).
    public let phase: MonaPointerEventPhase

    /// The raw AppKit click count, carried verbatim as input. The Monaco
    /// 400 ms / same-position clamp is applied in Core, not here.
    public let clickCount: Int

    /// The active modifier set, mapped from `NSEvent.modifierFlags`.
    public let modifiers: MonaKeyMod

    /// Force-touch pressure in [0, 1], carried as a `Double`.
    public let pressure: Double

    /// The viewport-space point supplied by the caller (the `NSView` converts
    /// `NSEvent.locationInWindow` to view space before calling the gateway).
    public let viewportPoint: CGPoint

    /// The model position resolved through the geometry barrier, or `nil` when
    /// the barrier is absent or returns a typed unavailable reason.
    public let resolvedPosition: MonaPosition?

    /// The event timestamp in the platform's native time base, carried verbatim
    /// for ordering.
    public let timestamp: Double

    /// Creates a platform-neutral pointer event.
    public init(
        button: MonaPointerButton,
        phase: MonaPointerEventPhase,
        clickCount: Int,
        modifiers: MonaKeyMod,
        pressure: Double,
        viewportPoint: CGPoint,
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

// MARK: - MonaPointerGateway

/// The single native gateway that translates AppKit `NSEvent` mouse events into
/// platform-neutral `MonaPointerEvent` values, resolving the target position
/// through the geometry barrier before Core command dispatch.
///
/// Stateless: two calls with equal inputs produce equal outputs. Construct one
/// per editor host (or share a singleton); it holds no per-event state.
public final class MonaPointerGateway {

    /// Creates a gateway. The gateway is stateless; the initializer exists so
    /// callers hold an instance (matching the "one native gateway per editor"
    /// boundary) rather than reaching for statics.
    public init() {}

    /// Translates an `NSEvent` mouse event into a `MonaPointerEvent`.
    ///
    /// - Parameters:
    ///   - event: The mouse `NSEvent` (mouseDown / mouseUp / mouseMoved /
    ///     mouseDragged / rightMouse* / otherMouse*).
    ///   - phase: The pointer phase to project. The caller (the `NSResponder`)
    ///     supplies this from the AppKit event type it received, so the gateway
    ///     does not own responder-routing logic.
    ///   - viewportPoint: The event location in viewport (view) space. The
    ///     caller converts `NSEvent.locationInWindow` to view space before
    ///     calling; the gateway does not touch the live `NSEvent` location.
    ///   - barrier: The geometry barrier (P03-T007) used to resolve the
    ///     viewport point to a model position before Core dispatch. `nil` leaves
    ///     `resolvedPosition` as `nil`.
    /// - Returns: The platform-neutral `MonaPointerEvent`. Translated exactly once.
    public func translate(
        _ event: NSEvent,
        phase: MonaPointerEventPhase,
        viewportPoint: CGPoint,
        resolvingPositionThrough barrier: MonaQueryGeometryBarrier?
    ) -> MonaPointerEvent {
        let button = Self.monaButton(for: event.buttonNumber)
        let modifiers = Self.monaModifiers(for: event.modifierFlags)
        let resolved = Self.resolve(viewportPoint: viewportPoint, through: barrier)

        return MonaPointerEvent(
            button: button,
            phase: phase,
            clickCount: event.clickCount,
            modifiers: modifiers,
            pressure: Double(event.pressure),
            viewportPoint: viewportPoint,
            resolvedPosition: resolved,
            timestamp: event.timestamp
        )
    }

    // MARK: - Static field translators

    /// Maps a macOS button number to a `MonaPointerButton`.
    ///
    /// macOS button numbering: 0=left, 1=right, 2=middle, others≥3=`.other(_:)`.
    /// The integer for `.other` is preserved verbatim.
    public static func monaButton(for buttonNumber: Int) -> MonaPointerButton {
        switch buttonNumber {
        case 0:  return .left
        case 1:  return .right
        case 2:  return .middle
        default: return .other(buttonNumber)
        }
    }

    /// Maps macOS modifier flags to `MonaKeyMod`, preserving Monaco's
    /// platform-abstract semantics (matching `MonaAppKeyEventGateway`):
    /// Command→CtrlCmd (accelerator), Control→WinCtrl (secondary),
    /// Option→Alt, Shift→Shift. Non-keyboard flags (`.function`, `.numericPad`,
    /// `.capsLock`, `.help`, device flags) are not `MonaKeyMod` modifiers and
    /// are intentionally not mapped.
    public static func monaModifiers(for flags: NSEvent.ModifierFlags) -> MonaKeyMod {
        var mods: MonaKeyMod = []
        if flags.contains(.command)  { mods.insert(.ctrlCmd) }
        if flags.contains(.shift)    { mods.insert(.shift) }
        if flags.contains(.option)   { mods.insert(.alt) }
        if flags.contains(.control)  { mods.insert(.winCtrl) }
        return mods
    }

    // MARK: - Geometry-barrier resolution

    /// Resolves a viewport-space point to a model position through the geometry
    /// barrier. Returns `nil` when the barrier is absent or returns a typed
    /// unavailable reason — no partial geometry is synthesized.
    static func resolve(
        viewportPoint: CGPoint,
        through barrier: MonaQueryGeometryBarrier?
    ) -> MonaPosition? {
        guard let barrier = barrier else { return nil }
        let result = barrier.hitTest(point: viewportPoint)
        switch result {
        case .available(let position):
            return position
        case .unavailable:
            return nil
        }
    }
}

// MARK: - MonaPointerGateway.Sendable

// The gateway holds no stored state beyond its dependencies (none), so it is
// safe to share across isolation boundaries. Declared via an extension so the
// primary type stays close to its contract.
extension MonaPointerGateway: @unchecked Sendable {}
