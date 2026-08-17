// MonaCompositionTests.swift
//
// P04-T004 — Implement marked-text input and composition arbitration.
//
// Verifies three AppKit-boundary composition components:
//
//   - `MonaTextInputClient`     — the marked-text input client (NSTextInputClient
//                                  surface): marked text, selected range,
//                                  replacement range, attributed substring,
//                                  first-rect, character-index. Routes every
//                                  synchronous geometry query through the
//                                  geometry barrier (P03-T007). Preserves raw
//                                  UTF-16 replacement ranges (ABC/Pinyin IME
//                                  traces) without grapheme conversion.
//   - `MonaCompositionSession`  — the IME composition session state machine:
//                                  idle → composing → committing → committed.
//                                  Handles marked-text update, commit, cancel,
//                                  fold (mark+insert), disposal, and timeout via
//                                  the deterministic clock (P04-T003).
//   - `MonaCompositionArbiter`  — arbitrates keybinding (P04-T003), command
//                                  insertion, marked-text update, commit, cancel,
//                                  fold, and disposal through ONE session state
//                                  machine. Ensures one session per editor and
//                                  resolves keybinding-during-composition conflicts
//                                  (absorb vs. commit-first-then-dispatch).

import XCTest
import AppKit
import CoreGraphics
import MonaCode
@testable import MonaCodeAppKit

final class MonaCompositionTests: XCTestCase {

    // MARK: - Shared helpers

    /// A deterministic geometry provider that stands in for
    /// `MonaQueryGeometryBarrier` (P03-T007). The composition path must route
    /// first-rect and character-index queries through this provider and must NOT
    /// bypass the barrier.
    private final class FakeGeometryProvider: MonaCompositionGeometryProvider {
        var caretRects: [MonaPosition: CGRect] = [:]
        var hitTestResults: [CGPoint: MonaPosition] = [:]

        func caretRect(for position: MonaPosition) -> MonaGeometryResult<CGRect> {
            if let rect = caretRects[position] {
                return .available(rect)
            }
            return .unavailable(.positionUnresolvable)
        }

        func hitTest(point: CGPoint) -> MonaGeometryResult<MonaPosition> {
            if let pos = hitTestResults[point] {
                return .available(pos)
            }
            return .unavailable(.outOfBounds)
        }
    }

    /// A mutable clock for deterministic time advancement.
    private final class FakeClock {
        var now: Double = 0
        var closure: () -> Double { return { [unowned self] in self.now } }
    }

    /// A string containing a surrogate pair (U+1D54F MATHEMATICAL DOUBLE-STRUCK
    /// CAPITAL X) so replacement ranges that span the pair can verify raw UTF-16
    /// preservation. UTF-16 layout: a(0) b(1) hi(2) lo(3) c(4) d(5) = 6 units.
    private let surrogateDoc = "ab\u{1D54F}cd"

    // MARK: - MonaTextInputClient: marked text, selected range, replacement range

    func testTextInputClientHasNoMarkedTextInitially() {
        let client = makeClient(document: "hello")
        XCTAssertFalse(client.hasMarkedText)
        XCTAssertEqual(client.markedRange, NSRange(location: NSNotFound, length: 0))
    }

    func testTextInputClientSetMarkedTextStoresTextAndRanges() {
        let client = makeClient(document: "hello world")
        client.setMarkedText(
            "abc",
            selectedRange: NSRange(location: 1, length: 1),
            replacementRange: NSRange(location: 6, length: 5)
        )
        XCTAssertTrue(client.hasMarkedText)
        XCTAssertEqual(client.markedAttributedText?.string, "abc")
        XCTAssertEqual(client.markedSelectedRange, NSRange(location: 1, length: 1))
        XCTAssertEqual(client.rawReplacementRange, NSRange(location: 6, length: 5))
    }

    func testTextInputClientMarkedRangeIsDocumentRangeOfMarkedText() {
        // After setMarkedText, the marked range in the document spans from the
        // replacement range's location for the marked text's UTF-16 length.
        let client = makeClient(document: "hello world")
        client.setMarkedText(
            "abc",
            selectedRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: 6, length: 5)
        )
        // "abc" is 3 UTF-16 units; markedRange = [6, 6+3) = [6, 3).
        XCTAssertEqual(client.markedRange, NSRange(location: 6, length: 3))
    }

    func testTextInputClientUnmarkTextClearsMarkedState() {
        let client = makeClient(document: "hello world")
        client.setMarkedText(
            "abc",
            selectedRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: 0, length: 0)
        )
        XCTAssertTrue(client.hasMarkedText)

        client.unmarkText()
        XCTAssertFalse(client.hasMarkedText)
        XCTAssertEqual(client.markedRange, NSRange(location: NSNotFound, length: 0))
    }

    func testTextInputClientSelectedRangeReflectsDocumentSelection() {
        let selection = NSRange(location: 2, length: 3)
        let client = makeClient(document: "hello world", selection: selection)
        XCTAssertEqual(client.selectedRange, selection)
    }

    // MARK: - MonaTextInputClient: attributed substring

    func testTextInputClientAttributedSubstringReturnsDocumentSlice() {
        let client = makeClient(document: "hello world")
        let sub = client.attributedSubstring(
            forProposedRange: NSRange(location: 0, length: 5),
            actualRange: nil
        )
        XCTAssertEqual(sub?.string, "hello")
    }

    func testTextInputClientAttributedSubstringClampsToDocumentLength() {
        let client = makeClient(document: "hi")
        var actual = NSRange(location: 0, length: 99)
        let sub = client.attributedSubstring(
            forProposedRange: NSRange(location: 0, length: 99),
            actualRange: &actual
        )
        XCTAssertEqual(sub?.string, "hi")
        XCTAssertEqual(actual, NSRange(location: 0, length: 2))
    }

    // MARK: - MonaTextInputClient: first-rect via geometry barrier

    func testTextInputClientFirstRectRoutesThroughGeometryProvider() {
        let provider = FakeGeometryProvider()
        // Document "hello\nworld": the 'w' is at line 2, column 1, UTF-16 offset 6.
        let pos = MonaPosition(line: 2, column: 1)
        provider.caretRects[pos] = CGRect(x: 10, y: 20, width: 7, height: 16)
        let client = makeClient(document: "hello\nworld", geometryProvider: provider)

        let rect = client.firstRect(
            forCharacterRange: NSRange(location: 6, length: 1),
            actualRange: nil
        )
        XCTAssertEqual(rect.origin.x, 10, accuracy: 1e-9)
        XCTAssertEqual(rect.origin.y, 20, accuracy: 1e-9)
        XCTAssertEqual(rect.width, 7, accuracy: 1e-9)
        XCTAssertEqual(rect.height, 16, accuracy: 1e-9)
    }

    func testTextInputClientFirstRectReturnsZeroWhenGeometryUnavailable() {
        let provider = FakeGeometryProvider()
        // No caret rects registered → unavailable.
        let client = makeClient(document: "hello", geometryProvider: provider)
        let rect = client.firstRect(
            forCharacterRange: NSRange(location: 0, length: 1),
            actualRange: nil
        )
        XCTAssertEqual(rect, .zero)
    }

    // MARK: - MonaTextInputClient: character-index via geometry barrier

    func testTextInputClientCharacterIndexRoutesThroughGeometryProvider() {
        let provider = FakeGeometryProvider()
        // Document "hello\nworld": offset 6 = line 2 column 1.
        let point = CGPoint(x: 10, y: 20)
        provider.hitTestResults[point] = MonaPosition(line: 2, column: 1)
        let client = makeClient(document: "hello\nworld", geometryProvider: provider)

        let index = client.characterIndex(for: point)
        XCTAssertEqual(index, 6)
    }

    func testTextInputClientCharacterIndexReturnsNotFoundWhenUnavailable() {
        let provider = FakeGeometryProvider()
        let client = makeClient(document: "hello", geometryProvider: provider)
        let index = client.characterIndex(for: CGPoint(x: 999, y: 999))
        XCTAssertEqual(index, NSNotFound)
    }

    // MARK: - MonaTextInputClient: raw UTF-16 replacement range preservation

    func testTextInputClientPreservesRawUTF16ReplacementRangeSpanningSurrogatePair() {
        // Document "ab<U+1D54F>cd": the surrogate pair occupies UTF-16 offsets
        // 2 and 3. A replacement range [2, 2) spans the surrogate pair. It must
        // be preserved verbatim as raw UTF-16 code units — NOT converted to a
        // grapheme count (which would be 1).
        let client = makeClient(document: surrogateDoc)
        let rawRange = NSRange(location: 2, length: 2)
        client.setMarkedText(
            "xy",
            selectedRange: NSRange(location: 0, length: 0),
            replacementRange: rawRange
        )
        XCTAssertEqual(client.rawReplacementRange, rawRange)
        // The marked range is derived from the raw replacement range location +
        // the marked text's UTF-16 length (2), NOT from grapheme conversion.
        XCTAssertEqual(client.markedRange, NSRange(location: 2, length: 2))
    }

    func testTextInputClientReplacementRangeSurvivesMultipleUpdatesPinyinTrace() {
        // Simulate a Pinyin IME trace: successive setMarkedText calls refine the
        // marked text while the replacement range stays anchored at the same
        // raw UTF-16 location (which spans a surrogate pair in the doc).
        let client = makeClient(document: surrogateDoc)
        let anchor = NSRange(location: 2, length: 2)

        client.setMarkedText("n", selectedRange: NSRange(location: 1, length: 0), replacementRange: anchor)
        XCTAssertEqual(client.rawReplacementRange, anchor)
        XCTAssertEqual(client.markedAttributedText?.string, "n")

        client.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0), replacementRange: anchor)
        XCTAssertEqual(client.rawReplacementRange, anchor)
        XCTAssertEqual(client.markedAttributedText?.string, "ni")

        client.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0), replacementRange: anchor)
        XCTAssertEqual(client.rawReplacementRange, anchor)
        XCTAssertEqual(client.markedAttributedText?.string, "nihao")
    }

    func testTextInputClientMarkedRangeUpdatesAcrossSurrogateSpanningText() {
        // Marked text containing a surrogate pair: "你" (U+4F60, 1 UTF-16 unit)
        // vs "𝕏" (U+1D54F, 2 UTF-16 units). The marked range length must reflect
        // UTF-16 code units, not grapheme count.
        let client = makeClient(document: "abc")
        client.setMarkedText(
            "𝕏",  // 2 UTF-16 units
            selectedRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: 1, length: 0)
        )
        XCTAssertEqual(client.markedRange, NSRange(location: 1, length: 2))
    }

    // MARK: - MonaCompositionSession: state machine

    func testSessionStartsIdle() {
        let session = MonaCompositionSession(clock: { 0 })
        XCTAssertEqual(session.phase, .idle)
        XCTAssertFalse(session.isActive)
        XCTAssertFalse(session.isTerminal)
        XCTAssertNil(session.markedText)
    }

    func testSessionUpdateMarkedTextTransitionsIdleToComposing() {
        let session = MonaCompositionSession(clock: { 0 })
        let ok = session.updateMarkedText(
            "abc",
            selectedRange: NSRange(location: 1, length: 1),
            replacementRange: NSRange(location: 0, length: 0)
        )
        XCTAssertTrue(ok)
        XCTAssertEqual(session.phase, .composing)
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.markedText, "abc")
        XCTAssertEqual(session.markedSelectedRange, NSRange(location: 1, length: 1))
        XCTAssertEqual(session.replacementRange, NSRange(location: 0, length: 0))
    }

    func testSessionUpdateMarkedTextWhileComposingUpdatesMarkedText() {
        let session = MonaCompositionSession(clock: { 0 })
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        session.updateMarkedText("abcdef", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: 0, length: 0))

        XCTAssertEqual(session.phase, .composing)
        XCTAssertEqual(session.markedText, "abcdef")
        XCTAssertEqual(session.markedSelectedRange, NSRange(location: 3, length: 0))
    }

    func testSessionCommitTransitionsComposingToCommitted() {
        let session = MonaCompositionSession(clock: { 0 })
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))

        let outcome = session.commit("你好")
        XCTAssertEqual(outcome, .committed("你好"))
        XCTAssertEqual(session.phase, .committed)
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(session.isTerminal)
        XCTAssertEqual(session.lastCommittedText, "你好")
        XCTAssertNil(session.markedText)
    }

    func testSessionCommitWhileIdleReturnsNothingToCommit() {
        let session = MonaCompositionSession(clock: { 0 })
        let outcome = session.commit("x")
        XCTAssertEqual(outcome, .nothingToCommit)
        XCTAssertEqual(session.phase, .idle)
    }

    func testSessionCommitWhileAlreadyCommittedReturnsAlreadyTerminal() {
        let session = MonaCompositionSession(clock: { 0 })
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        _ = session.commit("done")

        let outcome = session.commit("again")
        XCTAssertEqual(outcome, .alreadyTerminal)
    }

    func testSessionCancelTransitionsComposingToCommittedDiscardingMarkedText() {
        let session = MonaCompositionSession(clock: { 0 })
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))

        let outcome = session.cancel()
        XCTAssertEqual(outcome, .cancelled("abc"))
        XCTAssertEqual(session.phase, .committed)
        XCTAssertTrue(session.isTerminal)
        XCTAssertEqual(session.lastDiscardedMarkedText, "abc")
        XCTAssertNil(session.markedText)
    }

    func testSessionCancelWhileIdleReturnsNothingToCommit() {
        let session = MonaCompositionSession(clock: { 0 })
        let outcome = session.cancel()
        XCTAssertEqual(outcome, .nothingToCommit)
    }

    // MARK: - MonaCompositionSession: fold (mark + insert)

    func testSessionFoldTransitionsIdleToComposingWithCommittedInsertion() {
        let session = MonaCompositionSession(clock: { 0 })
        let ok = session.fold(
            committedText: "你",
            markedText: "好",
            markedSelectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: 0, length: 0)
        )
        XCTAssertTrue(ok)
        XCTAssertEqual(session.phase, .composing)
        XCTAssertEqual(session.lastCommittedText, "你")
        XCTAssertEqual(session.markedText, "好")
        XCTAssertEqual(session.markedSelectedRange, NSRange(location: 1, length: 0))
    }

    func testSessionFoldWhileComposingCommitsOldFirstThenFolds() {
        let session = MonaCompositionSession(clock: { 0 })
        session.updateMarkedText("old", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))

        let ok = session.fold(
            committedText: "mid",
            markedText: "new",
            markedSelectedRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: 0, length: 0)
        )
        XCTAssertTrue(ok)
        XCTAssertEqual(session.phase, .composing)
        // The old marked text was committed before the fold.
        XCTAssertEqual(session.lastCommittedText, "mid")
        XCTAssertEqual(session.markedText, "new")
    }

    // MARK: - MonaCompositionSession: disposal

    func testSessionDisposeTransitionsToCommittedAndBlocksFurtherOps() {
        let session = MonaCompositionSession(clock: { 0 })
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))

        session.dispose()
        XCTAssertEqual(session.phase, .committed)
        XCTAssertTrue(session.isTerminal)

        // After disposal, all operations are rejected.
        let updateOk = session.updateMarkedText("x", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        XCTAssertFalse(updateOk)
        let commitOutcome = session.commit("y")
        XCTAssertEqual(commitOutcome, .alreadyTerminal)
    }

    // MARK: - MonaCompositionSession: timeout via deterministic clock

    func testSessionHasTimedOutFalseBeforeTimeout() {
        let clock = FakeClock()
        let session = MonaCompositionSession(clock: clock.closure, timeoutInterval: 5.0)
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        clock.now = 3.0
        XCTAssertFalse(session.hasTimedOut())
    }

    func testSessionHasTimedOutTrueAfterTimeout() {
        let clock = FakeClock()
        let session = MonaCompositionSession(clock: clock.closure, timeoutInterval: 5.0)
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        clock.now = 6.0
        XCTAssertTrue(session.hasTimedOut())
    }

    func testSessionElapsedUsesInjectedClock() {
        let clock = FakeClock()
        let session = MonaCompositionSession(clock: clock.closure)
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        clock.now = 4.0
        XCTAssertEqual(session.elapsed, 4.0, accuracy: 1e-9)
    }

    // MARK: - MonaCompositionSession: reset for reuse

    func testSessionResetReturnsCommittedToIdle() {
        let session = MonaCompositionSession(clock: { 0 })
        session.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        _ = session.commit("done")
        XCTAssertEqual(session.phase, .committed)

        session.reset()
        XCTAssertEqual(session.phase, .idle)
        XCTAssertNil(session.markedText)
    }

    // MARK: - MonaCompositionArbiter: keybinding with no composition

    func testArbiterHandleKeyNoCompositionNoMatchReturnsPassThrough() {
        let arbiter = makeArbiter()
        // A bare 'x' with no matching keybinding and no composition.
        let event = MonaKeyEvent(keyCode: .keyX, keyText: "x", modifiers: [], isRepeat: false, isComposing: false, timestamp: 0)
        let result = arbiter.handleKey(event, context: MonaKeybindingContext())
        XCTAssertEqual(result, .passThrough)
    }

    func testArbiterHandleKeyNoCompositionMatchReturnsDispatched() {
        let arbiter = makeArbiter(withSaveKeybinding: true)
        // Cmd+S matches the "save" keybinding.
        let event = MonaKeyEvent(keyCode: .keyS, keyText: "s", modifiers: .ctrlCmd, isRepeat: false, isComposing: false, timestamp: 0)
        let result = arbiter.handleKey(event, context: MonaKeybindingContext())
        XCTAssertEqual(result, .dispatched(commandId: "save"))
    }

    // MARK: - MonaCompositionArbiter: keybinding during composition

    func testArbiterHandleKeyDuringCompositionIsComposingTrueAbsorbs() {
        // When the IME is driving (isComposing == true), the composition absorbs
        // the event — the keybinding service must NOT dispatch.
        let arbiter = makeArbiter(withSaveKeybinding: true)
        arbiter.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))

        let event = MonaKeyEvent(keyCode: .keyS, keyText: "s", modifiers: .ctrlCmd, isRepeat: false, isComposing: true, timestamp: 0)
        let result = arbiter.handleKey(event, context: MonaKeybindingContext())
        XCTAssertEqual(result, .absorbedByComposition)
        // The composition is still active.
        XCTAssertEqual(arbiter.sessionPhase, .composing)
    }

    func testArbiterHandleKeyDuringCompositionIsComposingFalseMatchCommitsThenDispatches() {
        // A keybinding during composition with isComposing == false commits the
        // composition first, then dispatches the command.
        let arbiter = makeArbiter(withSaveKeybinding: true)
        arbiter.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))

        let event = MonaKeyEvent(keyCode: .keyS, keyText: "s", modifiers: .ctrlCmd, isRepeat: false, isComposing: false, timestamp: 0)
        let result = arbiter.handleKey(event, context: MonaKeybindingContext())
        XCTAssertEqual(result, .committedThenDispatched(commandId: "save"))
        // The composition was committed.
        XCTAssertEqual(arbiter.sessionPhase, .committed)
    }

    func testArbiterHandleKeyDuringCompositionIsComposingFalseNoMatchAbsorbs() {
        // A non-keybinding key during composition (isComposing == false, no
        // match) is absorbed — the input context / IME handles it.
        let arbiter = makeArbiter(withSaveKeybinding: true)
        arbiter.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))

        let event = MonaKeyEvent(keyCode: .keyX, keyText: "x", modifiers: [], isRepeat: false, isComposing: false, timestamp: 0)
        let result = arbiter.handleKey(event, context: MonaKeybindingContext())
        XCTAssertEqual(result, .absorbedByComposition)
    }

    // MARK: - MonaCompositionArbiter: session operations through the arbiter

    func testArbiterUpdateMarkedTextStartsComposition() {
        let arbiter = makeArbiter()
        let ok = arbiter.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        XCTAssertTrue(ok)
        XCTAssertEqual(arbiter.sessionPhase, .composing)
        XCTAssertTrue(arbiter.hasActiveComposition)
    }

    func testArbiterCommitReturnsCommittedTextAndTransitions() {
        let arbiter = makeArbiter()
        arbiter.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        let outcome = arbiter.commit("done")
        XCTAssertEqual(outcome, .committed("done"))
        XCTAssertEqual(arbiter.sessionPhase, .committed)
        XCTAssertFalse(arbiter.hasActiveComposition)
    }

    func testArbiterCancelDiscardsMarkedText() {
        let arbiter = makeArbiter()
        arbiter.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        let outcome = arbiter.cancel()
        XCTAssertEqual(outcome, .cancelled("abc"))
        XCTAssertEqual(arbiter.sessionPhase, .committed)
    }

    func testArbiterFoldInsertsAndMarks() {
        let arbiter = makeArbiter()
        let ok = arbiter.fold(
            committedText: "你",
            markedText: "好",
            markedSelectedRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: 0, length: 0)
        )
        XCTAssertTrue(ok)
        XCTAssertEqual(arbiter.sessionPhase, .composing)
    }

    func testArbiterDisposeTerminatesSession() {
        let arbiter = makeArbiter()
        arbiter.updateMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        arbiter.dispose()
        XCTAssertEqual(arbiter.sessionPhase, .committed)

        // Further operations are rejected.
        let ok = arbiter.updateMarkedText("x", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        XCTAssertFalse(ok)
    }

    // MARK: - MonaCompositionArbiter: one-session invariant

    func testArbiterSecondCompositionStartCommitsFirst() {
        // Only one composition session per editor. Starting a new composition
        // while one is active commits the old first, then begins the new.
        let arbiter = makeArbiter()
        arbiter.updateMarkedText("first", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))

        let ok = arbiter.updateMarkedText("second", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: 0, length: 0))
        XCTAssertTrue(ok)
        XCTAssertEqual(arbiter.sessionPhase, .composing)
        // The first composition was committed before the second began.
        XCTAssertEqual(arbiter.sessionLastCommittedText, "first")
    }

    func testArbiterHandleKeyAfterDisposeReturnsNoOp() {
        let arbiter = makeArbiter(withSaveKeybinding: true)
        arbiter.dispose()

        let event = MonaKeyEvent(keyCode: .keyS, keyText: "s", modifiers: .ctrlCmd, isRepeat: false, isComposing: false, timestamp: 0)
        let result = arbiter.handleKey(event, context: MonaKeybindingContext())
        XCTAssertEqual(result, .noOp)
    }

    // MARK: - MonaCompositionArbiter: dispatch outcome derivation

    func testArbiterAbsorbedOutcomeIsHandledWithPreventDefault() {
        // Absorbed compositions must prevent the platform default (the platform
        // must not also feed the input context or beep).
        let outcome = MonaCompositionArbitration.absorbedByComposition.dispatchOutcome
        XCTAssertTrue(outcome.handled)
        XCTAssertTrue(outcome.preventDefault)
        XCTAssertTrue(outcome.stopPropagation)
    }

    func testArbiterPassThroughOutcomeIsDefault() {
        let outcome = MonaCompositionArbitration.passThrough.dispatchOutcome
        XCTAssertEqual(outcome, .default)
    }

    // MARK: - Helpers

    private func makeClient(
        document: String,
        selection: NSRange = NSRange(location: 0, length: 0),
        geometryProvider: MonaCompositionGeometryProvider = FakeGeometryProvider()
    ) -> MonaTextInputClient {
        return MonaTextInputClient(
            geometryProvider: geometryProvider,
            documentTextProvider: { document },
            documentSelectionProvider: { selection }
        )
    }

    private func makeArbiter(withSaveKeybinding: Bool = false) -> MonaCompositionArbiter {
        let resolver: MonaKeybindingResolver
        if withSaveKeybinding {
            resolver = MonaKeybindingResolver(keybindings: [
                MonaKeybinding(key: .keyS, modifiers: .ctrlCmd, command: "save", when: nil, weight: 0)
            ])
        } else {
            resolver = MonaKeybindingResolver()
        }
        let chordState = MonaChordState(clock: { 0 })
        let session = MonaCompositionSession(clock: { 0 })
        return MonaCompositionArbiter(
            resolver: resolver,
            chordState: chordState,
            session: session,
            clock: { 0 }
        )
    }
}
