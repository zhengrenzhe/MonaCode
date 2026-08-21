// CursorEventPayloadTests.swift
//
// INPUT-007 (Task 1: CURSOR payload) — Behavior test for the cursor position +
// selection changed event protocols.
//
// Verifies that `MonaEditorICursorPositionChangedEvent` and
// `MonaEditorICursorSelectionChangedEvent` declare concrete payload members
// (not zero-member shells), and that a concrete conforming event carries its
// position / secondaryPositions / selection through the protocol witness.
//
// This is an exit-only behavior test (Ruling I): it guards against the
// protocols collapsing back to empty `{}` shells by asserting the payload is
// readable through the protocol type — a conformance that lacks the required
// member would not compile, and an empty protocol would offer no payload to
// read.

import XCTest
import MonaCode

final class CursorEventPayloadTests: XCTestCase {

    // MARK: - ICursorPositionChangedEvent

    /// A concrete cursor-position-changed event carrying a primary position
    /// and secondary positions. The `let` stored properties satisfy the
    /// protocol's `{ get }` requirements.
    private struct TestCursorPositionEvent: MonaEditorICursorPositionChangedEvent {
        let position: MonaPosition
        let secondaryPositions: [MonaPosition]?
    }

    func testCursorPositionEventCarriesPrimaryPositionThroughProtocol() {
        let position = MonaPosition(line: 3, column: 7)
        let event: MonaEditorICursorPositionChangedEvent = TestCursorPositionEvent(
            position: position,
            secondaryPositions: nil
        )

        // The primary position is readable through the protocol witness.
        XCTAssertEqual(event.position, position,
                       "ICursorPositionChangedEvent: primary position carries through the protocol")
    }

    func testCursorPositionEventCarriesSecondaryPositionsThroughProtocol() {
        // A multi-cursor event with one secondary cursor (two positions total).
        let primary = MonaPosition(line: 1, column: 1)
        let secondary = MonaPosition(line: 2, column: 5)
        let event: MonaEditorICursorPositionChangedEvent = TestCursorPositionEvent(
            position: primary,
            secondaryPositions: [secondary]
        )

        XCTAssertEqual(event.secondaryPositions, [secondary],
                       "ICursorPositionChangedEvent: secondary positions carry through the protocol")
        XCTAssertEqual(event.secondaryPositions?.count, 1,
                       "ICursorPositionChangedEvent: one secondary cursor reported")

        // A single-cursor event has no secondary positions (nil).
        let single: MonaEditorICursorPositionChangedEvent = TestCursorPositionEvent(
            position: primary,
            secondaryPositions: nil
        )
        XCTAssertNil(single.secondaryPositions,
                      "ICursorPositionChangedEvent: single-cursor event reports nil secondary positions")
    }

    // MARK: - ICursorSelectionChangedEvent

    /// A concrete cursor-selection-changed event carrying the primary selection.
    private struct TestCursorSelectionEvent: MonaEditorICursorSelectionChangedEvent {
        let selection: MonaSelection
    }

    func testCursorSelectionEventCarriesSelectionThroughProtocol() {
        let selection = MonaSelection(
            anchor: MonaPosition(line: 1, column: 1),
            activePosition: MonaPosition(line: 1, column: 5)
        )
        let event: MonaEditorICursorSelectionChangedEvent = TestCursorSelectionEvent(
            selection: selection
        )

        // The primary selection is readable through the protocol witness.
        XCTAssertEqual(event.selection, selection,
                       "ICursorSelectionChangedEvent: primary selection carries through the protocol")
        XCTAssertEqual(event.selection.anchor, MonaPosition(line: 1, column: 1),
                       "ICursorSelectionChangedEvent: selection anchor preserved")
        XCTAssertEqual(event.selection.activePosition, MonaPosition(line: 1, column: 5),
                       "ICursorSelectionChangedEvent: selection active position preserved")
    }
}
