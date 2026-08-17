// MonaCancellationTests.swift
//
// P01-T006 — Implement cancellation tokens and sources.
//
// Verifies:
//   - `MonaCancellationToken.none` (never cancels) and `.cancelled` (already
//     cancelled) singletons.
//   - `MonaCancellationTokenSource.cancel()` fires cancellation exactly once
//     (idempotent on repeat calls).
//   - Listeners registered AFTER cancellation still fire (immediately and
//     synchronously) — the comparator-order "fire-immediately" behavior.
//   - Listener registration order is preserved on `cancel()`.
//   - `onCancellationRequested` returns a `MonaDisposable` that removes the
//     listener (and is a no-op after cancellation has already fired it).
//   - Child sources (via `createChild()`): disposing a child does NOT cancel
//     the parent (nor unrelated siblings); parent cancellation cancels all
//     live children (including grandchildren via propagation).

import XCTest
import MonaCode

final class MonaCancellationTests: XCTestCase {

    /// A mutable, reference-typed recorder captured by escaping closures so the
    /// test can observe listener delivery order and timing.
    private final class Recorder {
        var fired: [String] = []
    }

    // MARK: - MonaCancellationToken.None singleton

    func testNoneTokenIsNotCancelled() {
        XCTAssertFalse(MonaCancellationToken.none.isCancellationRequested)
    }

    func testNoneTokenListenerNeverFiresAndDisposableIsSafe() {
        let token = MonaCancellationToken.none
        let recorder = Recorder()
        let disposable = token.onCancellationRequested { recorder.fired.append("nope") }

        XCTAssertEqual(recorder.fired, [])
        disposable.dispose()
        XCTAssertEqual(recorder.fired, [])
    }

    // MARK: - MonaCancellationToken.Cancelled singleton

    func testCancelledTokenIsAlreadyCancelled() {
        XCTAssertTrue(MonaCancellationToken.cancelled.isCancellationRequested)
    }

    func testCancelledTokenFiresListenerImmediatelyAndSynchronously() {
        let token = MonaCancellationToken.cancelled
        let recorder = Recorder()
        let disposable = token.onCancellationRequested { recorder.fired.append("yes") }

        // Fires immediately, synchronously, at registration time.
        XCTAssertEqual(recorder.fired, ["yes"])
        // The returned disposable is inert and safe to dispose repeatedly.
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(recorder.fired, ["yes"])
    }

    func testMultipleListenersOnCancelledTokenAllFireImmediately() {
        let token = MonaCancellationToken.cancelled
        let recorder = Recorder()
        token.onCancellationRequested { recorder.fired.append("a") }
        token.onCancellationRequested { recorder.fired.append("b") }
        token.onCancellationRequested { recorder.fired.append("c") }
        XCTAssertEqual(recorder.fired, ["a", "b", "c"])
    }

    func testNoneAndCancelledSingletonsAreStableAcrossAccesses() {
        XCTAssertEqual(MonaCancellationToken.none.isCancellationRequested, false)
        XCTAssertEqual(MonaCancellationToken.cancelled.isCancellationRequested, true)
        XCTAssertEqual(MonaCancellationToken.none.isCancellationRequested, false)
        XCTAssertEqual(MonaCancellationToken.cancelled.isCancellationRequested, true)
    }

    // MARK: - MonaCancellationTokenSource — cancel fires once

    func testSourceTokenStartsNotCancelled() {
        let source = MonaCancellationTokenSource()
        XCTAssertFalse(source.token.isCancellationRequested)
    }

    func testCancelFiresRegisteredListenersOnce() {
        let source = MonaCancellationTokenSource()
        let recorder = Recorder()
        source.token.onCancellationRequested { recorder.fired.append("a") }
        source.token.onCancellationRequested { recorder.fired.append("b") }

        XCTAssertEqual(recorder.fired, [])
        source.cancel()
        XCTAssertEqual(recorder.fired, ["a", "b"])
        XCTAssertTrue(source.token.isCancellationRequested)
    }

    func testCancelIsIdempotent() {
        let source = MonaCancellationTokenSource()
        let recorder = Recorder()
        source.token.onCancellationRequested { recorder.fired.append("x") }

        source.cancel()
        source.cancel()
        source.cancel()

        XCTAssertEqual(recorder.fired, ["x"])
        XCTAssertTrue(source.token.isCancellationRequested)
    }

    func testCancelFiresListenersInRegistrationOrder() {
        let source = MonaCancellationTokenSource()
        let recorder = Recorder()
        for i in 0..<5 {
            source.token.onCancellationRequested { recorder.fired.append("L\(i)") }
        }
        source.cancel()
        XCTAssertEqual(recorder.fired, ["L0", "L1", "L2", "L3", "L4"])
    }

    // MARK: - Listeners registered after cancellation still work

    func testListenerRegisteredAfterCancellationFiresImmediately() {
        let source = MonaCancellationTokenSource()
        let recorder = Recorder()
        source.cancel()

        source.token.onCancellationRequested { recorder.fired.append("late") }
        XCTAssertEqual(recorder.fired, ["late"])
    }

    func testMultipleLateListenersAllFireImmediatelyInOrder() {
        let source = MonaCancellationTokenSource()
        let recorder = Recorder()
        source.cancel()

        source.token.onCancellationRequested { recorder.fired.append("late1") }
        source.token.onCancellationRequested { recorder.fired.append("late2") }
        source.token.onCancellationRequested { recorder.fired.append("late3") }
        XCTAssertEqual(recorder.fired, ["late1", "late2", "late3"])
    }

    func testLateListenerFiresAfterEarlyListenersAlreadyFired() {
        let source = MonaCancellationTokenSource()
        let recorder = Recorder()
        source.token.onCancellationRequested { recorder.fired.append("early") }
        source.cancel()
        source.token.onCancellationRequested { recorder.fired.append("late") }
        XCTAssertEqual(recorder.fired, ["early", "late"])
    }

    // MARK: - Listener removal disposable

    func testDisposalRemovesListenerBeforeCancel() {
        let source = MonaCancellationTokenSource()
        let recorder = Recorder()
        source.token.onCancellationRequested { recorder.fired.append("keep") }
        let removable = source.token.onCancellationRequested { recorder.fired.append("drop") }

        removable.dispose()
        source.cancel()
        XCTAssertEqual(recorder.fired, ["keep"])
    }

    func testDisposalAfterCancelIsNoOp() {
        let source = MonaCancellationTokenSource()
        let recorder = Recorder()
        let d = source.token.onCancellationRequested { recorder.fired.append("a") }
        source.cancel()
        XCTAssertEqual(recorder.fired, ["a"])
        d.dispose()  // already fired; must not fire again
        XCTAssertEqual(recorder.fired, ["a"])
    }

    // MARK: - Child sources: disposing a child does not cancel the parent

    func testCreateChildReturnsIndependentSource() {
        let parent = MonaCancellationTokenSource()
        let child = parent.createChild()
        XCTAssertFalse(parent.token.isCancellationRequested)
        XCTAssertFalse(child.token.isCancellationRequested)
    }

    func testDisposingChildDoesNotCancelParent() {
        let parent = MonaCancellationTokenSource()
        let child = parent.createChild()
        let recorder = Recorder()
        parent.token.onCancellationRequested { recorder.fired.append("parent") }

        child.dispose()
        XCTAssertFalse(parent.token.isCancellationRequested)
        XCTAssertEqual(recorder.fired, [])
    }

    func testDisposingChildDoesNotCancelSiblingOrParent() {
        let parent = MonaCancellationTokenSource()
        let childA = parent.createChild()
        let childB = parent.createChild()
        let recorder = Recorder()
        childB.token.onCancellationRequested { recorder.fired.append("B") }
        parent.token.onCancellationRequested { recorder.fired.append("parent") }

        childA.dispose()
        XCTAssertFalse(parent.token.isCancellationRequested)
        XCTAssertFalse(childB.token.isCancellationRequested)
        XCTAssertEqual(recorder.fired, [])
    }

    func testDisposedChildListenersDoNotFireOnParentCancel() {
        let parent = MonaCancellationTokenSource()
        let childA = parent.createChild()
        let childB = parent.createChild()
        let recorder = Recorder()
        childA.token.onCancellationRequested { recorder.fired.append("A") }
        childB.token.onCancellationRequested { recorder.fired.append("B") }

        childA.dispose()
        parent.cancel()
        XCTAssertEqual(recorder.fired, ["B"])
        // childA was disposed (not cancelled).
        XCTAssertFalse(childA.token.isCancellationRequested)
        XCTAssertTrue(childB.token.isCancellationRequested)
    }

    // MARK: - Parent cancellation cancels all children

    func testParentCancelCancelsAllChildren() {
        let parent = MonaCancellationTokenSource()
        let childA = parent.createChild()
        let childB = parent.createChild()
        let recorder = Recorder()
        childA.token.onCancellationRequested { recorder.fired.append("A") }
        childB.token.onCancellationRequested { recorder.fired.append("B") }

        parent.cancel()
        XCTAssertTrue(parent.token.isCancellationRequested)
        XCTAssertTrue(childA.token.isCancellationRequested)
        XCTAssertTrue(childB.token.isCancellationRequested)
        // Both children's listeners fired. Sibling firing order is not part of
        // the contract, so compare as a sorted set.
        XCTAssertEqual(recorder.fired.sorted(), ["A", "B"])
    }

    func testParentCancelPropagatesToGrandchildren() {
        let grand = MonaCancellationTokenSource()
        let parent = grand.createChild()
        let child = parent.createChild()
        let recorder = Recorder()
        child.token.onCancellationRequested { recorder.fired.append("grandchild") }

        grand.cancel()
        XCTAssertTrue(grand.token.isCancellationRequested)
        XCTAssertTrue(parent.token.isCancellationRequested)
        XCTAssertTrue(child.token.isCancellationRequested)
        XCTAssertEqual(recorder.fired, ["grandchild"])
    }

    func testChildCreatedAfterParentCancelStartsCancelled() {
        let parent = MonaCancellationTokenSource()
        parent.cancel()
        let child = parent.createChild()
        XCTAssertTrue(child.token.isCancellationRequested)
    }

    func testChildCreatedAfterParentCancelFiresLateListenerImmediately() {
        let parent = MonaCancellationTokenSource()
        parent.cancel()
        let child = parent.createChild()
        let recorder = Recorder()
        child.token.onCancellationRequested { recorder.fired.append("late-child") }
        XCTAssertEqual(recorder.fired, ["late-child"])
    }
}
