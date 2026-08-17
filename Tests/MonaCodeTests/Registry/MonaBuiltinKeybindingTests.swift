// MonaBuiltinKeybindingTests.swift
//
// P05-T003 — Populate all 379 keybinding rows over the Core resolver.
//
// Verifies the builtin keybinding table (`MonaBuiltinKeybindings`) that drives
// the Core keybinding resolver (`MonaKeybindingResolver` from P04-T003). The
// 379 rows are transcribed verbatim from the F1-R3 scope manifest and validated
// against the I3-R2 keybinding closure truth table:
//
//   - Row count is exactly 379, ordinals 0…378 stable and unique.
//   - Source ordinals are the stable identity even when a command repeats
//     across rows (platform variants are NOT coalesced).
//   - Modifier mapping (macOS, per I3-R2): metaKey→CtrlCmd, ctrlKey→WinCtrl,
//     altKey→Alt, shiftKey→Shift.
//   - ABC (single-key) resolution: the resolver, fed the 379 rows, resolves
//     single-key events exactly as I3-R2 specifies — including conflict
//     cases (same key → highest weight wins, then specificity; ambiguous →
//     registration order).
//   - Chord (two-key) resolution: first part enters the chord state; second
//     part completes; a non-matching second key cancels and replays; the
//     5 s timeout (elapsed > 5000 ms) cancels.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import XCTest
import MonaCode

final class MonaBuiltinKeybindingTests: XCTestCase {

    // MARK: - Row count & stable ordinals (I3-R2: 379 defaults, source-ordered)

    func testBuiltinRowCountIsExactly379() {
        XCTAssertEqual(MonaBuiltinKeybindings.rows.count, 379,
                       "the F1-R3 builtin table must contain exactly 379 rows")
    }

    func testOrdinalsAreStableZeroBasedSourceOrder() {
        let ordinals = MonaBuiltinKeybindings.rows.map { $0.ordinal }
        // Ordinals are the stable source identity: 0…378, each exactly once.
        XCTAssertEqual(Array(ordinals.sorted()), Array(0..<379))
        XCTAssertEqual(Set(ordinals).count, 379, "ordinals must be unique")
        // The array is emitted in source-ordinal order, so rows[i].ordinal == i.
        for (index, row) in MonaBuiltinKeybindings.rows.enumerated() {
            XCTAssertEqual(row.ordinal, index,
                           "rows must be in source-ordinal order; row \(index) has ordinal \(row.ordinal)")
        }
    }

    func testOrdinalIsStableIdentityForDuplicateCommands() {
        // `closeReferenceSearch` is bound at TWO source ordinals (Shift+Esc and
        // plain Esc) — two rows, same command, distinct ordinals. They must NOT
        // be coalesced: the ordinal is the stable identity.
        let closeRows = MonaBuiltinKeybindings.rows.filter { $0.keybinding.command == "closeReferenceSearch" }
        XCTAssertGreaterThanOrEqual(closeRows.count, 2,
                                     "closeReferenceSearch has multiple platform/source variants")
        let closeOrdinals = Set(closeRows.map { $0.ordinal })
        XCTAssertEqual(closeOrdinals.count, closeRows.count,
                       "rows sharing a command must keep distinct ordinals")
        // The first two source rows are both closeReferenceSearch (ordinals 0 and 1).
        XCTAssertEqual(MonaBuiltinKeybindings.rows[0].keybinding.command, "closeReferenceSearch")
        XCTAssertEqual(MonaBuiltinKeybindings.rows[1].keybinding.command, "closeReferenceSearch")
        XCTAssertEqual(MonaBuiltinKeybindings.rows[0].ordinal, 0)
        XCTAssertEqual(MonaBuiltinKeybindings.rows[1].ordinal, 1)
    }

    // MARK: - Modifier mapping (I3-R2: meta→CtrlCmd, ctrl→WinCtrl, alt→Alt, shift→Shift)

    func testModifierMappingMetaKeyToCtrlCmd() {
        // Row 51: editor.action.selectAll, Cmd+A (metaKey=true → CtrlCmd).
        let row = self.row(51)
        XCTAssertEqual(row.keybinding.command, "editor.action.selectAll")
        XCTAssertEqual(row.keybinding.key, .keyA)
        XCTAssertEqual(row.keybinding.modifiers, .ctrlCmd)
        XCTAssertNil(row.keybinding.chordKey, "selectAll is a single-part keybinding")
    }

    func testModifierMappingCtrlKeyToWinCtrl() {
        // Row 30: cursorLineStart, Ctrl+A (ctrlKey=true → WinCtrl on macOS).
        let row = self.row(30)
        XCTAssertEqual(row.keybinding.command, "cursorLineStart")
        XCTAssertEqual(row.keybinding.key, .keyA)
        XCTAssertEqual(row.keybinding.modifiers, .winCtrl)
    }

    func testModifierMappingShiftAndMetaCombined() {
        // Row 55: redo, Cmd+Shift+Z (metaKey+shiftKey → CtrlCmd|Shift).
        let row = self.row(55)
        XCTAssertEqual(row.keybinding.command, "redo")
        XCTAssertEqual(row.keybinding.key, .keyZ)
        XCTAssertEqual(row.keybinding.modifiers, [.ctrlCmd, .shift])
    }

    // MARK: - Resolver ingests all 379 defaults

    func testResolverIngestsAll379Defaults() {
        // A resolver pre-loaded with the 379 defaults (in source order) resolves
        // a known builtin command out of the box.
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let res = resolver.resolve(event: mkEvent(.keyA, .ctrlCmd),
                                    context: MonaKeybindingContext(),
                                    chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "editor.action.selectAll")
        XCTAssertTrue(res.outcome.handled)
    }

    // MARK: - ABC (single-key) resolution against I3-R2

    func testABCSelectAllResolvesUnconditionally() {
        // Cmd+A → selectAll; when-clause is nil, so it resolves under any
        // context (including the empty context).
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let res = resolver.resolve(event: mkEvent(.keyA, .ctrlCmd),
                                    context: MonaKeybindingContext(),
                                    chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "editor.action.selectAll")
        XCTAssertEqual(res.chordStatus, .none)
    }

    func testABCUndoResolvesUnconditionally() {
        // Cmd+Z → undo (when nil).
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let res = resolver.resolve(event: mkEvent(.keyZ, .ctrlCmd),
                                    context: MonaKeybindingContext(),
                                    chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "undo")
        XCTAssertEqual(res.chordStatus, .none)
    }

    func testABCConflictSpecificityRedoWinsOverUndo() {
        // I3-R2 conflict: same key (Z), same weight (0) → specificity wins.
        // Cmd+Shift+Z matches BOTH undo (Cmd+Z, 1 modifier — subset) and redo
        // (Cmd+Shift+Z, 2 modifiers — exact). Redo has more modifiers → wins.
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let res = resolver.resolve(event: mkEvent(.keyZ, [.ctrlCmd, .shift]),
                                    context: MonaKeybindingContext(),
                                    chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "redo")
        // And plain Cmd+Z still resolves undo (Shift binding is NOT a subset).
        let resPlain = resolver.resolve(event: mkEvent(.keyZ, .ctrlCmd),
                                        context: MonaKeybindingContext(),
                                        chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(resPlain.commandId, "undo")
    }

    func testABCConflictHighestWeightWins() {
        // I3-R2 conflict: same key+modifiers, different weights → highest wins.
        // Tab (no modifiers): the `tab` default (weight 0, when editorTextFocus
        // && !editorReadonly && !editorTabMovesFocus) is shadowed by
        // `acceptSelectedSuggestion` (weight 190, when suggest-widget focused &
        // visible). Under a context where BOTH when-clauses match, the
        // weight-190 binding wins.
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let ctx = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("textInputFocus", .bool(true))
            .with("editorReadonly", .bool(false))
            .with("editorTabMovesFocus", .bool(false))
            .with("suggestWidgetHasFocusedSuggestion", .bool(true))
            .with("suggestWidgetVisible", .bool(true))
            .with("inSnippetMode", .bool(false))
            .with("inInlineEditsPreviewEditor", .bool(false))
            .with("inlineEditIsVisible", .bool(false))
            .with("hasNextTabstop", .bool(false))
            .with("atEndOfWord", .bool(false))
            .with("hasOtherSuggestions", .bool(false))
            .with("config.editor.tabCompletion", .string("on"))
        let res = resolver.resolve(event: mkEvent(.tab, []),
                                    context: ctx,
                                    chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "acceptSelectedSuggestion",
                       "weight-190 acceptSelectedSuggestion must outrank weight-0 tab")
    }

    func testABCConflictRegistrationOrderLaterWins() {
        // I3-R2 conflict: equal weight AND equal specificity → registration
        // order (later wins). The 379 defaults are registered first; an
        // equal-weight, equal-specificity binding registered AFTER the defaults
        // wins over the default for the same key.
        let resolver = MonaBuiltinKeybindings.makeResolver()
        // selectAll (Cmd+A, CtrlCmd, weight 0) is a default. Register an
        // equal-weight clone of the same key+modifiers AFTER the defaults.
        resolver.register(MonaKeybinding(
            key: .keyA, modifiers: .ctrlCmd,
            command: "test.selectAllOverride", when: nil, weight: 0
        ))
        let res = resolver.resolve(event: mkEvent(.keyA, .ctrlCmd),
                                    context: MonaKeybindingContext(),
                                    chordState: MonaChordState(clock: { 0 }))
        XCTAssertEqual(res.commandId, "test.selectAllOverride",
                       "at equal weight+specificity the later-registered binding wins")
    }

    // MARK: - Chord (two-key) resolution against I3-R2

    func testChordFirstPartEntersChordState() {
        // Cmd+K (first part of many builtin chords) enters the chord state and
        // dispatches no command yet.
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let ctx = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(false))
        let chord = MonaChordState(clock: { 0 })
        let res = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd),
                                    context: ctx, chordState: chord)
        XCTAssertNil(res.commandId)
        XCTAssertEqual(res.chordStatus, .entered)
        XCTAssertTrue(chord.isActive)
        XCTAssertTrue(res.outcome.handled)
    }

    func testChordCmdKCmdBCompletesToSetSelectionAnchor() {
        // I3-R2 chord: Cmd+K Cmd+B → editor.action.setSelectionAnchor (the
        // unique builtin chord whose second part is Cmd+B / keyB).
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let ctx = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(false))
        let chord = MonaChordState(clock: { 0 })
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: ctx, chordState: chord)
        XCTAssertTrue(chord.isActive)
        let res = resolver.resolve(event: mkEvent(.keyB, .ctrlCmd),
                                    context: ctx, chordState: chord)
        XCTAssertEqual(res.commandId, "editor.action.setSelectionAnchor")
        XCTAssertEqual(res.chordStatus, .completed)
        XCTAssertFalse(chord.isActive)
    }

    func testChordNonMatchingSecondKeyCancelsAndReplays() {
        // I3-R2: a non-matching second key cancels the chord and is REPLAYED as
        // a fresh first part. Cmd+K enters; Cmd+Z is no chord's second part for
        // Cmd+K → cancel + replay → undo (a registered single Cmd+Z command).
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let ctx = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(false))
        let chord = MonaChordState(clock: { 0 })
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: ctx, chordState: chord)
        XCTAssertTrue(chord.isActive)
        let res = resolver.resolve(event: mkEvent(.keyZ, .ctrlCmd),
                                    context: ctx, chordState: chord)
        XCTAssertEqual(res.chordStatus, .cancelled)
        XCTAssertEqual(res.commandId, "undo")
        XCTAssertFalse(chord.isActive)
    }

    func testChordTimeoutCancelsExactlyPast5000ms() {
        // I3-R2: the chord expires when elapsed is STRICTLY greater than 5000 ms.
        let resolver = MonaBuiltinKeybindings.makeResolver()
        let ctx = MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(false))
        var now: Double = 0
        let chord = MonaChordState(clock: { now }, timeoutInterval: 5.0)
        _ = resolver.resolve(event: mkEvent(.keyK, .ctrlCmd), context: ctx, chordState: chord)
        XCTAssertTrue(chord.isActive)
        now = 5.0
        XCTAssertFalse(chord.hasTimedOut(), "elapsed == 5000 ms must NOT time out (strictly greater)")
        now = 5.001
        XCTAssertTrue(chord.hasTimedOut(), "elapsed > 5000 ms must time out")
        // Resolving after timeout cancels the chord and replays the event fresh.
        let res = resolver.resolve(event: mkEvent(.keyZ, .ctrlCmd),
                                    context: ctx, chordState: chord)
        XCTAssertEqual(res.chordStatus, .cancelled)
        XCTAssertFalse(chord.isActive)
    }

    // MARK: - Helpers

    private func row(_ ordinal: Int) -> MonaBuiltinKeybindings.Row {
        // Ordinals are 0…378 in source order, so rows[ordinal] is the row.
        return MonaBuiltinKeybindings.rows[ordinal]
    }

    private func mkEvent(_ key: MonaKeyCode, _ mods: MonaKeyMod) -> MonaKeyEvent {
        return MonaKeyEvent(keyCode: key, keyText: nil, modifiers: mods,
                            isRepeat: false, isComposing: false, timestamp: 0)
    }
}
