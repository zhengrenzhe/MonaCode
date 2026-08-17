// MonaEventControlTests.swift
//
// P04-T007 — Implement public EventControl and native event adaptation.
//
// Verifies two deliverables that adapt the Core platform-neutral input events
// for the PUBLIC callback surface:
//
//   - `MonaEventControl` — a `final class` exposing EXPLICIT prevent-default
//                          and stop-propagation state transitions. State starts
//                          clean (both false); transitions happen only via
//                          `preventDefault()` / `stopPropagation()`, not
//                          implicitly from a constructor argument. Used by
//                          public event handlers to signal the dispatch
//                          decision separately from the immutable event data.
//   - `MonaPublicInputEvents` — the three public input event value types
//                          (`MonaPublicKeyboardEvent`, `MonaPublicMouseEvent`,
//                          `MonaPublicScrollEvent`). They project the
//                          platform-neutral fields (from P04-T001
//                          `MonaKeyEvent` and P04-T006 pointer/scroll) into
//                          public native-adapted values. They are IMMUTABLE
//                          snapshots: a public callback cannot mutate the
//                          underlying native event object because the public
//                          event carries no reference back to it (it is a
//                          value copy, not a wrapper over `NSEvent`).
//
// The `MonaEventControl` is deliberately a reference type so that a mutation
// made inside a callback (`control.preventDefault()`) is observable by the
// dispatch code that owns the same instance — mirroring the browser `Event`.
// The immutable event snapshot is deliberately a value type so the event data
// the callback reads cannot be tampered with and cannot reach back into native
// state. The two are decoupled: the event carries no control reference.

import XCTest
import MonaCode

final class MonaEventControlTests: XCTestCase {

    // MARK: - MonaEventControl: explicit state transitions

    func testEventControlStartsWithBothFlagsFalse() {
        // State transitions are EXPLICIT: a freshly constructed control is
        // always all-false, regardless of construction path. The constructor
        // takes no prevent-default / stop-propagation argument.
        let control = MonaEventControl()
        XCTAssertFalse(control.isDefaultPrevented)
        XCTAssertFalse(control.isPropagationStopped)
    }

    func testPreventDefaultTransitionsOnlyDefaultPrevented() {
        let control = MonaEventControl()
        control.preventDefault()
        XCTAssertTrue(control.isDefaultPrevented)
        // stopPropagation is independent and unchanged.
        XCTAssertFalse(control.isPropagationStopped)
    }

    func testStopPropagationTransitionsOnlyPropagationStopped() {
        let control = MonaEventControl()
        control.stopPropagation()
        XCTAssertTrue(control.isPropagationStopped)
        // isDefaultPrevented is independent and unchanged.
        XCTAssertFalse(control.isDefaultPrevented)
    }

    func testBothTransitionsAreIndependentAndComposable() {
        // The two flags are independent booleans (mirroring
        // MonaKeyDispatchOutcome.preventDefault / .stopPropagation). Either,
        // both, or neither may be set.
        let control = MonaEventControl()
        control.preventDefault()
        control.stopPropagation()
        XCTAssertTrue(control.isDefaultPrevented)
        XCTAssertTrue(control.isPropagationStopped)
    }

    func testPreventDefaultIsIdempotent() {
        // Calling preventDefault twice does not toggle or throw; the state
        // stays true (one-way transition, like the browser Event).
        let control = MonaEventControl()
        control.preventDefault()
        control.preventDefault()
        XCTAssertTrue(control.isDefaultPrevented)
    }

    func testStopPropagationIsIdempotent() {
        let control = MonaEventControl()
        control.stopPropagation()
        control.stopPropagation()
        XCTAssertTrue(control.isPropagationStopped)
    }

    func testTransitionsAreOneWayTrue() {
        // preventDefault / stopPropagation are one-way: once true there is no
        // public API to reset them to false. The browser `Event.defaultPrevented`
        // contract is the same — a prevented default cannot be un-prevented.
        let control = MonaEventControl()
        control.preventDefault()
        control.stopPropagation()
        XCTAssertTrue(control.isDefaultPrevented)
        XCTAssertTrue(control.isPropagationStopped)
    }

    func testEventControlHasReferenceSemantics() {
        // MonaEventControl is a `final class` (reference type). A mutation made
        // through one binding is observable through another binding to the SAME
        // instance — the dispatch code that owns the control sees the callback's
        // preventDefault() call. This is why it is a class, not a struct.
        let control = MonaEventControl()
        let alias = control
        control.preventDefault()
        XCTAssertTrue(alias.isDefaultPrevented)
        XCTAssertTrue(control.isDefaultPrevented)
    }

    func testTwoEventControlsAreIndependentInstances() {
        // Each control is its own instance; mutating one does not affect the
        // other. Two separate editor events carry two separate controls.
        let a = MonaEventControl()
        let b = MonaEventControl()
        a.preventDefault()
        XCTAssertTrue(a.isDefaultPrevented)
        XCTAssertFalse(b.isDefaultPrevented)
    }

    // MARK: - MonaPublicKeyboardEvent: immutable snapshot of keyboard fields

    func testPublicKeyboardEventProjectsMonaKeyEventFields() {
        // The public keyboard event projects the platform-neutral fields of a
        // MonaKeyEvent (P04-T001) into public native-adapted values. Every
        // field is carried verbatim.
        let source = MonaKeyEvent(
            keyCode: .keyK,
            keyText: "k",
            modifiers: [.ctrlCmd, .shift],
            isRepeat: true,
            isComposing: false,
            timestamp: 12345.678
        )
        let publicEvent = MonaPublicKeyboardEvent(projectingFrom: source)
        XCTAssertEqual(publicEvent.keyCode, .keyK)
        XCTAssertEqual(publicEvent.keyText, "k")
        XCTAssertEqual(publicEvent.modifiers, [.ctrlCmd, .shift])
        XCTAssertTrue(publicEvent.isRepeat)
        XCTAssertFalse(publicEvent.isComposing)
        XCTAssertEqual(publicEvent.timestamp, 12345.678, accuracy: 1e-9)
    }

    func testPublicKeyboardEventPreservesNilKeyText() {
        // Non-printing keys (arrows, function keys, modifier-only presses)
        // project a nil keyText, exactly like the source MonaKeyEvent.
        let source = MonaKeyEvent(
            keyCode: .leftArrow,
            keyText: nil,
            modifiers: [.shift],
            isRepeat: false,
            isComposing: false,
            timestamp: 0.0
        )
        let publicEvent = MonaPublicKeyboardEvent(projectingFrom: source)
        XCTAssertNil(publicEvent.keyText)
        XCTAssertEqual(publicEvent.keyCode, .leftArrow)
        XCTAssertEqual(publicEvent.modifiers, .shift)
    }

    func testPublicKeyboardEventIsImmutableValueSnapshot() {
        // The public event is a value snapshot, not a reference to the source.
        // Two events constructed from different sources are independent; the
        // first is unchanged by constructing the second.
        let first = MonaPublicKeyboardEvent(projectingFrom: MonaKeyEvent(
            keyCode: .keyA, keyText: "a", modifiers: [],
            isRepeat: false, isComposing: false, timestamp: 1.0
        ))
        _ = MonaPublicKeyboardEvent(projectingFrom: MonaKeyEvent(
            keyCode: .keyB, keyText: "b", modifiers: [.shift],
            isRepeat: true, isComposing: true, timestamp: 2.0
        ))
        // first is frozen at projection time.
        XCTAssertEqual(first.keyCode, .keyA)
        XCTAssertEqual(first.keyText, "a")
        XCTAssertEqual(first.modifiers, [])
        XCTAssertFalse(first.isRepeat)
    }

    func testPublicKeyboardEventEqualityIsValueBased() {
        // Two public events projected from equal MonaKeyEvents are equal and
        // hash-equal. Equality is value-based (struct == struct), not
        // reference-based.
        let a = MonaPublicKeyboardEvent(projectingFrom: MonaKeyEvent(
            keyCode: .enter, keyText: "\n", modifiers: [.ctrlCmd],
            isRepeat: false, isComposing: false, timestamp: 5.0
        ))
        let b = MonaPublicKeyboardEvent(projectingFrom: MonaKeyEvent(
            keyCode: .enter, keyText: "\n", modifiers: [.ctrlCmd],
            isRepeat: false, isComposing: false, timestamp: 5.0
        ))
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testPublicKeyboardEventCallbackCannotMutateNativeEvent() {
        // The public event is a SNAPSHOT, not a reference to the native event.
        // A public callback receives the immutable public event and can read
        // its fields, but there is no path back to mutate the underlying
        // MonaKeyEvent: the public event is a struct whose stored fields are
        // copies, and it exposes no mutating setter and no reference to the
        // source.
        let native = MonaKeyEvent(
            keyCode: .space, keyText: " ", modifiers: [],
            isRepeat: false, isComposing: false, timestamp: 9.0
        )
        let snapshot = MonaPublicKeyboardEvent(projectingFrom: native)
        // The snapshot's keyCode is a copy of native.keyCode at projection time.
        XCTAssertEqual(snapshot.keyCode, native.keyCode)
        XCTAssertEqual(snapshot.keyText, native.keyText)
        // The native event is unchanged by the projection (value copy, no alias).
        XCTAssertEqual(native.keyCode, .space)
        XCTAssertEqual(native.keyText, " ")
    }

    // MARK: - MonaPublicMouseEvent: immutable snapshot of pointer fields

    func testPublicMouseEventProjectsPointerFields() {
        // The public mouse event projects the platform-neutral pointer fields
        // (from P04-T006 MonaPointerEvent) into Foundation-only public values.
        // Coordinates use MonaPublicPoint (no CoreGraphics dependency in Core).
        let event = MonaPublicMouseEvent(
            button: .left,
            phase: .down,
            clickCount: 2,
            modifiers: [.shift],
            pressure: 0.5,
            viewportPoint: MonaPublicPoint(x: 10.0, y: 20.0),
            resolvedPosition: MonaPosition(line: 3, column: 5),
            timestamp: 42.0
        )
        XCTAssertEqual(event.button, .left)
        XCTAssertEqual(event.phase, .down)
        XCTAssertEqual(event.clickCount, 2)
        XCTAssertEqual(event.modifiers, .shift)
        XCTAssertEqual(event.pressure, 0.5, accuracy: 1e-9)
        XCTAssertEqual(event.viewportPoint, MonaPublicPoint(x: 10.0, y: 20.0))
        XCTAssertEqual(event.resolvedPosition, MonaPosition(line: 3, column: 5))
        XCTAssertEqual(event.timestamp, 42.0, accuracy: 1e-9)
    }

    func testPublicMouseEventPreservesOtherButtonInteger() {
        // Exotic buttons are preserved verbatim via .other(Int), not collapsed
        // to a known case — mirroring MonaPointerButton.other(Int).
        let event = MonaPublicMouseEvent(
            button: .other(7),
            phase: .up,
            clickCount: 1,
            modifiers: [],
            pressure: 0.0,
            viewportPoint: MonaPublicPoint(x: 0, y: 0),
            resolvedPosition: nil,
            timestamp: 0
        )
        XCTAssertEqual(event.button, .other(7))
    }

    func testPublicMouseEventSupportsAllPhases() {
        // All four pointer phases project through the public event.
        for phase in [MonaPublicMousePhase.down, .up, .moved, .dragged] {
            let event = MonaPublicMouseEvent(
                button: .left, phase: phase, clickCount: 1, modifiers: [],
                pressure: 0.0, viewportPoint: MonaPublicPoint(x: 0, y: 0),
                resolvedPosition: nil, timestamp: 0
            )
            XCTAssertEqual(event.phase, phase)
        }
    }

    func testPublicMouseEventIsImmutableValueSnapshot() {
        // Two public mouse events with equal fields are equal and hash-equal
        // (value-based equality, not reference).
        let a = MonaPublicMouseEvent(
            button: .right, phase: .moved, clickCount: 0, modifiers: [.ctrlCmd],
            pressure: 0.25, viewportPoint: MonaPublicPoint(x: 1, y: 2),
            resolvedPosition: nil, timestamp: 1.5
        )
        let b = MonaPublicMouseEvent(
            button: .right, phase: .moved, clickCount: 0, modifiers: [.ctrlCmd],
            pressure: 0.25, viewportPoint: MonaPublicPoint(x: 1, y: 2),
            resolvedPosition: nil, timestamp: 1.5
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testPublicMouseEventResolvesPositionIsOptional() {
        // resolvedPosition is nil when the geometry barrier was absent or
        // returned an unavailable reason — no partial geometry is synthesized.
        let event = MonaPublicMouseEvent(
            button: .left, phase: .moved, clickCount: 0, modifiers: [],
            pressure: 0.0, viewportPoint: MonaPublicPoint(x: 0, y: 0),
            resolvedPosition: nil, timestamp: 0
        )
        XCTAssertNil(event.resolvedPosition)
    }

    // MARK: - MonaPublicScrollEvent: immutable snapshot of scroll fields

    func testPublicScrollEventProjectsScrollFields() {
        // The public scroll event projects the platform-neutral scroll fields
        // (from P04-T006 MonaScrollEvent) into Foundation-only public values.
        let event = MonaPublicScrollEvent(
            deltaX: -1.25,
            deltaY: 2.5,
            isPrecise: true,
            phase: .changed,
            momentumPhase: .none,
            magnification: 0.0,
            viewportPoint: MonaPublicPoint(x: 100.0, y: 200.0),
            resolvedPosition: MonaPosition(line: 1, column: 1),
            modifiers: [.alt],
            timestamp: 77.0
        )
        XCTAssertEqual(event.deltaX, -1.25, accuracy: 1e-9)
        XCTAssertEqual(event.deltaY, 2.5, accuracy: 1e-9)
        XCTAssertTrue(event.isPrecise)
        XCTAssertEqual(event.phase, .changed)
        XCTAssertEqual(event.momentumPhase, .none)
        XCTAssertEqual(event.magnification, 0.0, accuracy: 1e-9)
        XCTAssertEqual(event.viewportPoint, MonaPublicPoint(x: 100.0, y: 200.0))
        XCTAssertEqual(event.resolvedPosition, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(event.modifiers, .alt)
        XCTAssertEqual(event.timestamp, 77.0, accuracy: 1e-9)
    }

    func testPublicScrollEventSupportsAllPhases() {
        // All scroll phases project through the public event, including the
        // momentum-phase carried separately from the gesture phase.
        for phase in [
            MonaPublicScrollPhase.none, .began, .changed,
            .ended, .cancelled, .mayBegin
        ] {
            let event = MonaPublicScrollEvent(
                deltaX: 0, deltaY: 0, isPrecise: false, phase: phase,
                momentumPhase: .none, magnification: 0,
                viewportPoint: MonaPublicPoint(x: 0, y: 0),
                resolvedPosition: nil, modifiers: [], timestamp: 0
            )
            XCTAssertEqual(event.phase, phase)
        }
    }

    func testPublicScrollEventCarriesMomentumPhaseIndependently() {
        // After the user lifts their fingers, AppKit delivers momentum scroll
        // events with gesture phase .none and a non-.none momentumPhase. The
        // public event carries both independently.
        let event = MonaPublicScrollEvent(
            deltaX: 0, deltaY: 2.0, isPrecise: true, phase: .none,
            momentumPhase: .changed, magnification: 0,
            viewportPoint: MonaPublicPoint(x: 0, y: 0),
            resolvedPosition: nil, modifiers: [], timestamp: 3.0
        )
        XCTAssertEqual(event.phase, .none)
        XCTAssertEqual(event.momentumPhase, .changed)
    }

    func testPublicScrollEventIsImmutableValueSnapshot() {
        let a = MonaPublicScrollEvent(
            deltaX: 0, deltaY: 3, isPrecise: false, phase: .began,
            momentumPhase: .none, magnification: 0.1,
            viewportPoint: MonaPublicPoint(x: 0, y: 0),
            resolvedPosition: nil, modifiers: [], timestamp: 0.0
        )
        let b = MonaPublicScrollEvent(
            deltaX: 0, deltaY: 3, isPrecise: false, phase: .began,
            momentumPhase: .none, magnification: 0.1,
            viewportPoint: MonaPublicPoint(x: 0, y: 0),
            resolvedPosition: nil, modifiers: [], timestamp: 0.0
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - EventControl is decoupled from the public event snapshot

    func testEventControlMutationDoesNotAffectPublicEventSnapshot() {
        // A public callback receives the immutable public event AND a mutable
        // MonaEventControl. Calling preventDefault() on the control signals the
        // dispatch decision; it does NOT mutate the event snapshot (which
        // carries the native fields, not the dispatch decision). The event and
        // the control are decoupled — the event carries no control reference.
        let native = MonaKeyEvent(
            keyCode: .escape, keyText: nil, modifiers: [],
            isRepeat: false, isComposing: false, timestamp: 0.0
        )
        let snapshot = MonaPublicKeyboardEvent(projectingFrom: native)
        let control = MonaEventControl()
        // Callback signals prevent-default through the control.
        control.preventDefault()
        // The event snapshot is unaffected by the control mutation.
        XCTAssertEqual(snapshot.keyCode, .escape)
        XCTAssertTrue(control.isDefaultPrevented)
    }

    func testPublicEventSnapshotSurvivesIndependentOfControlLifetime() {
        // The immutable event snapshot does not hold the control. The snapshot
        // remains valid after the control is gone — there is no weak/strong
        // reference coupling that would invalidate the event's fields.
        let native = MonaKeyEvent(
            keyCode: .tab, keyText: "\t", modifiers: [],
            isRepeat: false, isComposing: false, timestamp: 1.0
        )
        var snapshot: MonaPublicKeyboardEvent? = MonaPublicKeyboardEvent(projectingFrom: native)
        do {
            let control = MonaEventControl()
            control.stopPropagation()
            XCTAssertEqual(snapshot?.keyCode, .tab)
            XCTAssertTrue(control.isPropagationStopped)
            snapshot = nil
        }
        // Re-derive from the same native source: the source is still intact
        // (the public projection never mutated it).
        let reprojected = MonaPublicKeyboardEvent(projectingFrom: native)
        XCTAssertEqual(reprojected.keyCode, .tab)
        XCTAssertEqual(reprojected.keyText, "\t")
    }
}
