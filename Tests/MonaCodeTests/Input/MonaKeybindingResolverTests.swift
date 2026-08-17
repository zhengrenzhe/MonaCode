// MonaKeybindingResolverTests.swift
//
// P04-T003 — Port keybinding resolution and chord state to Core.
//
// Verifies the three Core types that port Monaco's keybinding resolver and
// chord state machine out of the platform layer:
//
//   - `MonaKeybinding`           — an immutable keybinding definition: key +
//                                  modifiers + command ID + when-clause +
//                                  weight, plus an optional two-part chord
//                                  (second key + second modifiers).
//   - `MonaKeybindingResolver`   — resolves a `MonaKeyEvent` to a command.
//                                  Ordering: weight (higher wins), then
//                                  specificity (more modifiers wins), then
//                                  registration order (later wins). Supports
//                                  command removal, context-aware when-clause
//                                  matching, chord entry/timeout/cancellation/
//                                  replay. Returns a `MonaKeyDispatchOutcome`
//                                  (P04-T001) without invoking platform APIs.
//   - `MonaChordState`           — per-editor chord state. Tracks the current
//                                  chord sequence + timeout against an injected
//                                  deterministic clock. Handles chord entry,
//                                  timeout expiration, cancellation, and
//                                  replay.
//
// The resolver is a Foundation-only Core component: it produces dispatch
// *decisions* (a `MonaKeyDispatchOutcome`) and never touches AppKit, NSEvent,
// or any platform type. The platform layer (P04-T002) reads these decisions and
// applies them at the native boundary.

import XCTest
import MonaCode

final class MonaKeybindingResolverTests: XCTestCase {

    // MARK: - MonaKeybinding: immutable value type

    func testKeybindingStoresKeyModifiersCommandWhenWeight() {
        let kb = MonaKeybinding(
            key: .keyS,
            modifiers: .ctrlCmd,
            command: "editor.action.save",
            when: "editorTextFocus && !editorReadonly",
            weight: 100
        )
        XCTAssertEqual(kb.key, .keyS)
        XCTAssertEqual(kb.modifiers, .ctrlCmd)
        XCTAssertEqual(kb.command, "editor.action.save")
        XCTAssertEqual(kb.when, "editorTextFocus && !editorReadonly")
        XCTAssertEqual(kb.weight, 100)
        XCTAssertNil(kb.chordKey)
        XCTAssertEqual(kb.chordModifiers, [])
    }

    func testKeybindingSinglePartHasNilChordKey() {
        let kb = MonaKeybinding(key: .enter, modifiers: [], command: "line.insert", when: nil, weight: 0)
        XCTAssertNil(kb.chordKey)
        XCTAssertEqual(kb.chordModifiers, [])
    }

    func testKeybindingIsImmutableValueType() {
        let a = MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "c", when: nil, weight: 0)
        let b = MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "c", when: nil, weight: 0)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testKeybindingChordCarriesSecondPart() {
        let kb = MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.command",
            when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        )
        XCTAssertEqual(kb.chordKey, .keyC)
        XCTAssertEqual(kb.chordModifiers, .ctrlCmd)
    }

    // MARK: - Resolver: basic resolution

    func testResolverResolvesSimpleCommandByExactMatch() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyS, modifiers: .ctrlCmd, command: "editor.action.save", when: nil, weight: 0
        ))
        let event = mkEvent(.keyS, .ctrlCmd)
        let res = resolver.resolve(event: event, context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "editor.action.save")
        XCTAssertEqual(res.chordStatus, .none)
        XCTAssertTrue(res.outcome.handled)
        XCTAssertTrue(res.outcome.preventDefault)
        XCTAssertTrue(res.outcome.stopPropagation)
    }

    func testResolverReturnsDefaultOutcomeWhenNoMatch() {
        let resolver = MonaKeybindingResolver()
        let event = mkEvent(.keyX, [])
        let res = resolver.resolve(event: event, context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertNil(res.commandId)
        XCTAssertEqual(res.chordStatus, .none)
        XCTAssertEqual(res.outcome, .default)
    }

    func testResolverInitWithKeybindingsRegistersAll() {
        let resolver = MonaKeybindingResolver(keybindings: [
            MonaKeybinding(key: .keyC, modifiers: .ctrlCmd, command: "copy", when: nil, weight: 0),
            MonaKeybinding(key: .keyV, modifiers: .ctrlCmd, command: "paste", when: nil, weight: 0),
        ])
        XCTAssertEqual(resolver.resolve(event: mkEvent(.keyC, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 })).commandId, "copy")
        XCTAssertEqual(resolver.resolve(event: mkEvent(.keyV, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 })).commandId, "paste")
    }

    // MARK: - Ordering: weight, specificity, registration order

    func testResolverHigherWeightWins() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "low", when: nil, weight: 10))
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "high", when: nil, weight: 100))
        let res = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "high")
    }

    func testResolverMoreModifiersWinAtEqualWeight() {
        // Subset matching: Cmd+K and Cmd+Shift+K both match a Cmd+Shift+K
        // event. The more specific (more modifiers) keybinding wins.
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "fewer", when: nil, weight: 0))
        resolver.register(MonaKeybinding(key: .keyK, modifiers: [.ctrlCmd, .shift], command: "more", when: nil, weight: 0))
        let res = resolver.resolve(event: mkEvent(.keyK, [.ctrlCmd, .shift]), context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "more")
    }

    func testResolverLaterRegistrationWinsAtEqualWeightAndSpecificity() {
        // Two keybindings with identical key, modifiers, and weight: the one
        // registered LATER wins (override semantics).
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "first", when: nil, weight: 0))
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "second", when: nil, weight: 0))
        let res = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "second")
    }

    func testResolverNoModifierBindingDoesNotMatchModifiedEvent() {
        // A no-modifier binding must NOT steal a modified event: plain K does
        // not match Cmd+K. Only the exact Cmd+K binding fires.
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyK, modifiers: [], command: "plain", when: nil, weight: 0))
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "cmd", when: nil, weight: 0))
        let res = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "cmd")
        // The plain-K event resolves the plain binding.
        let plainRes = resolver.resolve(event: mkEvent(.keyK, []), context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(plainRes.commandId, "plain")
    }

    // MARK: - Command removal

    func testResolverRemoveCommandRemovesKeybinding() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyS, modifiers: .ctrlCmd, command: "save", when: nil, weight: 0))
        resolver.removeCommand("save")
        let res = resolver.resolve(event: mkEvent(.keyS, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertNil(res.commandId)
        XCTAssertEqual(res.outcome, .default)
    }

    func testResolverRemoveCommandPreservesOthers() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyS, modifiers: .ctrlCmd, command: "save", when: nil, weight: 0))
        resolver.register(MonaKeybinding(key: .keyC, modifiers: .ctrlCmd, command: "copy", when: nil, weight: 0))
        resolver.removeCommand("save")
        XCTAssertNil(resolver.resolve(event: mkEvent(.keyS, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 })).commandId)
        XCTAssertEqual(resolver.resolve(event: mkEvent(.keyC, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 })).commandId, "copy")
    }

    // MARK: - When-clause matching (context-aware)

    func testResolverWhenClauseMatchesContext() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyS, modifiers: .ctrlCmd, command: "save", when: "editorTextFocus && !editorReadonly", weight: 0))
        let ctx = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(false))
        XCTAssertEqual(resolver.resolve(event: mkEvent(.keyS, .ctrlCmd), context: ctx, chordState: MonaChordState(clock: { 0 })).commandId, "save")
    }

    func testResolverWhenClauseNoMatchSkipsCandidate() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyS, modifiers: .ctrlCmd, command: "save", when: "editorTextFocus && !editorReadonly", weight: 0))
        // editorReadonly == true → when fails.
        let ctx = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(true))
        let res = resolver.resolve(event: mkEvent(.keyS, .ctrlCmd), context: ctx, chordState: MonaChordState(clock: { 0 }))
        XCTAssertNil(res.commandId)
        XCTAssertEqual(res.outcome, .default)
    }

    func testResolverWhenClauseOrSemantics() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "cmd", when: "editorTextFocus || suggestWidgetVisible", weight: 0))
        // editorTextFocus false but suggestWidgetVisible true → matches via OR.
        let ctx = MonaKeybindingContext()
            .with("editorTextFocus", .bool(false))
            .with("suggestWidgetVisible", .bool(true))
        XCTAssertEqual(resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: ctx, chordState: MonaChordState(clock: { 0 })).commandId, "cmd")
    }

    func testResolverWhenClauseStringEquality() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "swiftCmd", when: "editorLangId == 'swift'", weight: 0))
        let match = MonaKeybindingContext().with("editorLangId", .string("swift"))
        let noMatch = MonaKeybindingContext().with("editorLangId", .string("python"))
        let event = mkEvent(.keyK, .ctrlCmd)
        XCTAssertEqual(resolver.resolve(event: event, context: match, chordState: MonaChordState(clock: { 0 })).commandId, "swiftCmd")
        XCTAssertNil(resolver.resolve(event: event, context: noMatch, chordState: MonaChordState(clock: { 0 })).commandId)
    }

    func testResolverWhenClauseStringInequalityAndRegex() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "notSwift", when: "editorLangId != 'swift'", weight: 0))
        resolver.register(MonaKeybinding(key: .keyL, modifiers: .ctrlCmd, command: "regexMatch", when: "editorLangId =~ 'sw.*'", weight: 0))
        let python = MonaKeybindingContext().with("editorLangId", .string("python"))
        let swift = MonaKeybindingContext().with("editorLangId", .string("swift"))
        XCTAssertEqual(resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: python, chordState: MonaChordState(clock: { 0 })).commandId, "notSwift")
        XCTAssertNil(resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: swift, chordState: MonaChordState(clock: { 0 })).commandId)
        XCTAssertEqual(resolver.resolve(event: mkEvent(.keyL, .ctrlCmd), context: swift, chordState: MonaChordState(clock: { 0 })).commandId, "regexMatch")
    }

    func testResolverNilWhenClauseAlwaysMatches() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyK, modifiers: .ctrlCmd, command: "always", when: nil, weight: 0))
        // Empty context — nil when matches unconditionally.
        let res = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "always")
    }

    // MARK: - Unknown key codes preserved through resolution

    func testResolverResolvesUnknownCustomKeyCodeIfRegistered() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .custom(9001), modifiers: .ctrlCmd, command: "exotic", when: nil, weight: 0))
        let event = MonaKeyEvent(keyCode: .custom(9001), keyText: nil, modifiers: .ctrlCmd, isRepeat: false, isComposing: false, timestamp: 0)
        let res = resolver.resolve(event: event, context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "exotic")
        XCTAssertEqual(res.chordStatus, .none)
        XCTAssertTrue(res.outcome.handled)
    }

    // MARK: - Chord: entry, completion

    func testChordEntersOnFirstPart() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        let chord = MonaChordState(clock: { 0 })
        let res = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: chord)
        XCTAssertNil(res.commandId)
        XCTAssertEqual(res.chordStatus, .entered)
        XCTAssertTrue(res.outcome.handled)
        XCTAssertTrue(chord.isActive)
    }

    func testChordCompletesOnSecondPart() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        let chord = MonaChordState(clock: { 0 })
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: chord)
        let res = resolver.resolve(event: mkEvent(.keyC, .ctrlCmd), context: .empty, chordState: chord)
        XCTAssertEqual(res.commandId, "chord.copy")
        XCTAssertEqual(res.chordStatus, .completed)
        XCTAssertTrue(res.outcome.handled)
        XCTAssertFalse(chord.isActive)
    }

    func testChordFirstPartWithinTimeoutStaysActive() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        var now: Double = 0
        let chord = MonaChordState(clock: { now }, timeoutInterval: 5.0)
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: chord)
        now = 4.0   // within the 5s window
        XCTAssertFalse(chord.hasTimedOut())
        XCTAssertTrue(chord.isActive)
        let res = resolver.resolve(event: mkEvent(.keyC, .ctrlCmd), context: .empty, chordState: chord)
        XCTAssertEqual(res.commandId, "chord.copy")
    }

    // MARK: - Chord: timeout, cancellation, replay

    func testChordTimeoutCancelsAndReplaysEvent() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        var now: Double = 0
        let chord = MonaChordState(clock: { now }, timeoutInterval: 5.0)
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: chord)
        XCTAssertTrue(chord.isActive)
        // Advance strictly past the 5s boundary (contract: elapsed > 5000ms).
        now = 5.001
        XCTAssertTrue(chord.hasTimedOut())
        // A subsequent event after timeout: the chord is cancelled and the
        // event is re-evaluated as a fresh first part.
        let res = resolver.resolve(event: mkEvent(.keyX, []), context: .empty, chordState: chord)
        XCTAssertEqual(res.chordStatus, .cancelled)
        XCTAssertFalse(chord.isActive)
    }

    func testChordExplicitCancellation() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        let chord = MonaChordState(clock: { 0 })
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: chord)
        XCTAssertTrue(chord.isActive)
        chord.cancel()
        XCTAssertFalse(chord.isActive)
    }

    func testChordReplayOnNonMatchingSecondKeyDispatchesReplayedCommand() {
        // Chord Cmd+K Cmd+C registered. First key Cmd+K enters the chord.
        // The second key Cmd+X does NOT match the chord second part → cancel +
        // replay. A single Cmd+X command "cut" is registered → the replay
        // dispatches "cut".
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        resolver.register(MonaKeybinding(key: .keyX, modifiers: .ctrlCmd, command: "editor.action.cut", when: nil, weight: 0))
        let chord = MonaChordState(clock: { 0 })
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: chord)
        XCTAssertTrue(chord.isActive)
        let res = resolver.resolve(event: mkEvent(.keyX, .ctrlCmd), context: .empty, chordState: chord)
        XCTAssertEqual(res.chordStatus, .cancelled)
        XCTAssertEqual(res.commandId, "editor.action.cut")
        XCTAssertTrue(res.outcome.handled)
        XCTAssertFalse(chord.isActive)
    }

    func testChordReplayWhenNoCommandMatchesSecondKey() {
        // Chord Cmd+K Cmd+C. Second key Cmd+X, no Cmd+X command registered.
        // → cancel, replay finds nothing → default outcome, chord cancelled.
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        let chord = MonaChordState(clock: { 0 })
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: .empty, chordState: chord)
        let res = resolver.resolve(event: mkEvent(.keyX, .ctrlCmd), context: .empty, chordState: chord)
        XCTAssertEqual(res.chordStatus, .cancelled)
        XCTAssertNil(res.commandId)
        XCTAssertEqual(res.outcome, .default)
        XCTAssertFalse(chord.isActive)
    }

    // MARK: - Deterministic clock injection

    func testChordDeterministicClockControlsTimeout() {
        var now: Double = 0
        let chord = MonaChordState(clock: { now }, timeoutInterval: 5.0)
        let kb = MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "c", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        )
        chord.enterChord(kb)
        XCTAssertTrue(chord.isActive)
        XCTAssertEqual(chord.elapsed, 0, accuracy: 1e-9)
        now = 4.0
        XCTAssertFalse(chord.hasTimedOut())
        now = 5.001
        XCTAssertTrue(chord.hasTimedOut())
    }

    func testChordStateIsPerEditorIndependent() {
        // Each editor owns its own chord state with its own clock view; one
        // editor entering a chord does not affect another.
        var now: Double = 0
        let editorA = MonaChordState(clock: { now }, timeoutInterval: 5.0)
        let editorB = MonaChordState(clock: { now + 1000 }, timeoutInterval: 5.0)
        let kb = MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "c", when: nil, weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        )
        editorA.enterChord(kb)
        XCTAssertTrue(editorA.isActive)
        XCTAssertFalse(editorB.isActive)
        now = 6.0
        XCTAssertTrue(editorA.hasTimedOut())
        XCTAssertFalse(editorB.isActive)
    }

    // MARK: - Chord replay after context change

    func testChordReevaluateAfterContextChangeCancelsStaleChord() {
        // A chord is registered with a when-clause on the first part. After the
        // first key enters the chord, the context changes so the when-clause no
        // longer matches. Re-evaluating the active chord cancels the stale
        // chord (replay after context change).
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: "editorTextFocus", weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        let focusCtx = MonaKeybindingContext().with("editorTextFocus", .bool(true))
        let blurCtx = MonaKeybindingContext().with("editorTextFocus", .bool(false))
        let chord = MonaChordState(clock: { 0 })
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: focusCtx, chordState: chord)
        XCTAssertTrue(chord.isActive)
        // Context changes (editorTextFocus → false). The active chord's
        // when-clause no longer holds → re-evaluation cancels it.
        let cancelled = resolver.reevaluateActiveChord(context: blurCtx, chordState: chord)
        XCTAssertTrue(cancelled)
        XCTAssertFalse(chord.isActive)
    }

    func testChordReevaluateKeepsChordWhenContextStillMatches() {
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(
            key: .keyK, modifiers: .ctrlCmd, command: "chord.copy", when: "editorTextFocus", weight: 0,
            chordKey: .keyC, chordModifiers: .ctrlCmd
        ))
        let focusCtx = MonaKeybindingContext().with("editorTextFocus", .bool(true))
        let chord = MonaChordState(clock: { 0 })
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: focusCtx, chordState: chord)
        let cancelled = resolver.reevaluateActiveChord(context: focusCtx, chordState: chord)
        XCTAssertFalse(cancelled)
        XCTAssertTrue(chord.isActive)
    }

    // MARK: - Dispatch outcome is platform-neutral

    func testResolverProducesNoPlatformSideEffects() {
        // The resolver returns a dispatch DECISION (MonaKeyDispatchOutcome). It
        // must not invoke any platform API — constructing the resolution and its
        // outcome requires no platform type and performs no dispatch.
        let resolver = MonaKeybindingResolver()
        resolver.register(MonaKeybinding(key: .keyS, modifiers: .ctrlCmd, command: "save", when: nil, weight: 0))
        let res = resolver.resolve(event: mkEvent(.keyS, .ctrlCmd), context: .empty, chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.outcome, MonaKeyDispatchOutcome(handled: true, preventDefault: true, stopPropagation: true))
    }

    // MARK: - Helpers

    private func mkEvent(_ key: MonaKeyCode, _ mods: MonaKeyMod) -> MonaKeyEvent {
        return MonaKeyEvent(keyCode: key, keyText: nil, modifiers: mods, isRepeat: false, isComposing: false, timestamp: 0)
    }
}

extension MonaKeybindingContext {
    fileprivate static var empty: MonaKeybindingContext { MonaKeybindingContext() }
}
