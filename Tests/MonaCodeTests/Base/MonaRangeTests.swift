// MonaRangeTests.swift
//
// P01-T002 — Implement ranges and oriented selections.
//
// Verifies:
//   - `MonaRange` stores `startPosition` + `endPosition` (`MonaPosition`) and
//     normalizes reversed endpoints (constructor swaps when start > end,
//     line-major — matching Monaco's `Range` constructor).
//   - `MonaSelection` stores `anchor` + `activePosition` (`MonaPosition`) and a
//     derived `orientation` (`.forward` / `.backward`), preserving the anchor +
//     active orientation when normalizing its range.
//   - Three intersection predicates ported branch-for-branch from Monaco:
//       contains(_:)        — Range.containsPosition (edges inclusive).
//       intersects(_:)       — Range.areIntersectingOrTouching (touching counts).
//       areIntersecting(_:)  — Range.areIntersecting (touching excluded).
//     The two intersect predicates are contrasted on the same touching inputs
//     so their source boundaries (not their names) drive the result.
//   - Surrogate-pair expansion: `expandedAcrossSurrogatePair` ports Monaco's
//     `TextModel.validateRange` surrogate block branch-for-branch. Non-folded
//     ranges expand outward; folded ranges move to a valid location; neither
//     endpoint inside a pair leaves the range unchanged.

import XCTest
import MonaCode

final class MonaRangeTests: XCTestCase {

    // MARK: - MonaRange: endpoints + reversed-endpoint normalization

    func testRangeStoresStartPositionAndEndPositionAsMonaPosition() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 2, column: 3),
            endPosition: MonaPosition(line: 4, column: 7)
        )

        XCTAssertEqual(range.startPosition, MonaPosition(line: 2, column: 3))
        XCTAssertEqual(range.endPosition, MonaPosition(line: 4, column: 7))
    }

    func testRangeConstructorNormalizesReversedEndpointsOnSameLine() {
        // Same line, start column > end column: swap columns (Monaco Range ctor).
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 9),
            endPosition: MonaPosition(line: 1, column: 2)
        )

        XCTAssertEqual(range.startPosition, MonaPosition(line: 1, column: 2))
        XCTAssertEqual(range.endPosition, MonaPosition(line: 1, column: 9))
    }

    func testRangeConstructorNormalizesReversedEndpointsAcrossLines() {
        // start line > end line: swap regardless of columns (line-major).
        let range = MonaRange(
            startPosition: MonaPosition(line: 5, column: 1),
            endPosition: MonaPosition(line: 2, column: 99)
        )

        XCTAssertEqual(range.startPosition, MonaPosition(line: 2, column: 99))
        XCTAssertEqual(range.endPosition, MonaPosition(line: 5, column: 1))
    }

    func testRangeConstructorLeavesAlreadyOrderedEndpointsUnchanged() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 3, column: 5)
        )

        XCTAssertEqual(range.startPosition, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(range.endPosition, MonaPosition(line: 3, column: 5))
    }

    func testRangeWithEqualEndpointsIsFoldedAndNotSwapped() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 2, column: 4),
            endPosition: MonaPosition(line: 2, column: 4)
        )

        XCTAssertTrue(range.isFolded)
        XCTAssertEqual(range.startPosition, MonaPosition(line: 2, column: 4))
        XCTAssertEqual(range.endPosition, MonaPosition(line: 2, column: 4))
    }

    func testRangeEqualityIsValueBasedAcrossNormalization() {
        // A reversed-input range normalizes to the same value as the ordered one.
        let reversed = MonaRange(
            startPosition: MonaPosition(line: 1, column: 9),
            endPosition: MonaPosition(line: 1, column: 2)
        )
        let ordered = MonaRange(
            startPosition: MonaPosition(line: 1, column: 2),
            endPosition: MonaPosition(line: 1, column: 9)
        )

        XCTAssertEqual(reversed, ordered)
        XCTAssertEqual(reversed.hashValue, ordered.hashValue)
    }

    // MARK: - contains(_:) — Range.containsPosition (edges inclusive)

    func testContainsReturnsTrueAtBothEdgesAndInteriorOnSingleLineRange() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 8)
        )

        // Start edge inclusive.
        XCTAssertTrue(range.contains(MonaPosition(line: 1, column: 3)))
        // End edge inclusive.
        XCTAssertTrue(range.contains(MonaPosition(line: 1, column: 8)))
        // Interior.
        XCTAssertTrue(range.contains(MonaPosition(line: 1, column: 5)))
    }

    func testContainsReturnsFalseBeforeStartAndAfterEndOnSameLine() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 8)
        )

        // column < startColumn on the start line.
        XCTAssertFalse(range.contains(MonaPosition(line: 1, column: 2)))
        // column > endColumn on the end line.
        XCTAssertFalse(range.contains(MonaPosition(line: 1, column: 9)))
    }

    func testContainsReturnsFalseForLinesOutsideRange() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 3, column: 5)
        )

        // lineNumber < startLineNumber.
        XCTAssertFalse(range.contains(MonaPosition(line: 0, column: 5)))
        // lineNumber > endLineNumber.
        XCTAssertFalse(range.contains(MonaPosition(line: 4, column: 1)))
    }

    func testContainsBranchForBranchOnMultiLineRange() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 3, column: 5)
        )

        // On the start line: column < startColumn -> false.
        XCTAssertFalse(range.contains(MonaPosition(line: 1, column: 2)))
        // On the start line: column == startColumn -> true (edge).
        XCTAssertTrue(range.contains(MonaPosition(line: 1, column: 3)))
        // On the start line: column > startColumn -> true (interior of multi-line range).
        XCTAssertTrue(range.contains(MonaPosition(line: 1, column: 10)))

        // Strictly between start and end lines -> true (any column).
        XCTAssertTrue(range.contains(MonaPosition(line: 2, column: 1)))

        // On the end line: column <= endColumn -> true.
        XCTAssertTrue(range.contains(MonaPosition(line: 3, column: 5)))
        XCTAssertTrue(range.contains(MonaPosition(line: 3, column: 4)))
        // On the end line: column > endColumn -> false.
        XCTAssertFalse(range.contains(MonaPosition(line: 3, column: 6)))
    }

    func testContainsAcceptsMidSurrogateColumnAsRawUTF16Offset() {
        // MonaCode stores raw UTF-16 columns without grapheme conversion. A
        // column that lands inside a surrogate pair (e.g. column 2 between the
        // two units of a surrogate pair at columns 1-2) is a valid raw position
        // and is contained by an inclusive range covering it.
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 3)
        )

        XCTAssertTrue(range.contains(MonaPosition(line: 1, column: 2)))
    }

    // MARK: - intersects(_:) vs areIntersecting(_:) — branch-for-branch contrast

    func testIntersectsCountsTouchingAreIntersectingExcludesIt() {
        // Two ranges touching at (1,5): a.end == b.start. This is the boundary
        // case where the two predicates diverge.
        let a = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 5)
        )
        let b = MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 10)
        )

        // areIntersectingOrTouching: touching counts -> true.
        XCTAssertTrue(a.intersects(b))
        // areIntersecting: touching excluded (endColumn <= startColumn) -> false.
        XCTAssertFalse(a.areIntersecting(b))
    }

    func testIntersectsAndAreIntersectingBothTrueForActualOverlap() {
        let a = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 5)
        )
        let b = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 8)
        )

        XCTAssertTrue(a.intersects(b))
        XCTAssertTrue(a.areIntersecting(b))
    }

    func testIntersectsAndAreIntersectingBothFalseForGapOnSameLine() {
        let a = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 5)
        )
        let b = MonaRange(
            startPosition: MonaPosition(line: 1, column: 6),
            endPosition: MonaPosition(line: 1, column: 10)
        )

        XCTAssertFalse(a.intersects(b))
        XCTAssertFalse(a.areIntersecting(b))
    }

    func testIntersectsCountsPointTouchingAreIntersectingExcludesIt() {
        // b is a folded range (point) exactly at a.end.
        let a = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 5)
        )
        let point = MonaRange(
            startPosition: MonaPosition(line: 1, column: 5),
            endPosition: MonaPosition(line: 1, column: 5)
        )

        XCTAssertTrue(a.intersects(point))
        XCTAssertFalse(a.areIntersecting(point))
    }

    func testIntersectsAndAreIntersectingAcrossLineBoundaryTouching() {
        // Touching across a line boundary: a ends at (2,5), b starts at (2,5).
        let a = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 2, column: 5)
        )
        let b = MonaRange(
            startPosition: MonaPosition(line: 2, column: 5),
            endPosition: MonaPosition(line: 3, column: 1)
        )

        XCTAssertTrue(a.intersects(b))
        XCTAssertFalse(a.areIntersecting(b))
    }

    func testIntersectsAndAreIntersectingBothFalseWhenSeparateByLine() {
        let a = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 1, column: 5)
        )
        let b = MonaRange(
            startPosition: MonaPosition(line: 3, column: 1),
            endPosition: MonaPosition(line: 4, column: 1)
        )

        XCTAssertFalse(a.intersects(b))
        XCTAssertFalse(a.areIntersecting(b))
    }

    func testIntersectsAndAreIntersectingBothTrueWhenOneContainsTheOther() {
        let outer = MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: 3, column: 10)
        )
        let inner = MonaRange(
            startPosition: MonaPosition(line: 2, column: 1),
            endPosition: MonaPosition(line: 2, column: 5)
        )

        XCTAssertTrue(outer.intersects(inner))
        XCTAssertTrue(outer.areIntersecting(inner))
    }

    // MARK: - Surrogate-pair expansion (TextModel.validateRange surrogate block)

    func testExpansionLeavesRangeUnchangedWhenNeitherEndpointInsideSurrogatePair() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 8)
        )

        let expanded = range.expandedAcrossSurrogatePair(
            startLandsInsideSurrogatePair: false,
            endLandsInsideSurrogatePair: false
        )

        XCTAssertEqual(expanded, range)
    }

    func testExpansionExpandsBothEndsOutwardWhenBothInsideNonFoldedRange() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 8)
        )

        let expanded = range.expandedAcrossSurrogatePair(
            startLandsInsideSurrogatePair: true,
            endLandsInsideSurrogatePair: true
        )

        // start - 1, end + 1 (embrace the surrogate pair at both ends).
        XCTAssertEqual(expanded.startPosition, MonaPosition(line: 1, column: 2))
        XCTAssertEqual(expanded.endPosition, MonaPosition(line: 1, column: 9))
    }

    func testExpansionExpandsOnlyStartWhenOnlyStartInsideNonFoldedRange() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 8)
        )

        let expanded = range.expandedAcrossSurrogatePair(
            startLandsInsideSurrogatePair: true,
            endLandsInsideSurrogatePair: false
        )

        XCTAssertEqual(expanded.startPosition, MonaPosition(line: 1, column: 2))
        XCTAssertEqual(expanded.endPosition, MonaPosition(line: 1, column: 8))
    }

    func testExpansionExpandsOnlyEndWhenOnlyEndInsideNonFoldedRange() {
        let range = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 8)
        )

        let expanded = range.expandedAcrossSurrogatePair(
            startLandsInsideSurrogatePair: false,
            endLandsInsideSurrogatePair: true
        )

        XCTAssertEqual(expanded.startPosition, MonaPosition(line: 1, column: 3))
        XCTAssertEqual(expanded.endPosition, MonaPosition(line: 1, column: 9))
    }

    func testExpansionMovesFoldedRangeBackByOneInsteadOfExpanding() {
        // A folded range (start == end) does not expand; Monaco moves both
        // endpoints back by one to a valid (non-mid-surrogate) location.
        let folded = MonaRange(
            startPosition: MonaPosition(line: 1, column: 3),
            endPosition: MonaPosition(line: 1, column: 3)
        )

        let expanded = folded.expandedAcrossSurrogatePair(
            startLandsInsideSurrogatePair: true,
            endLandsInsideSurrogatePair: true
        )

        XCTAssertEqual(expanded.startPosition, MonaPosition(line: 1, column: 2))
        XCTAssertEqual(expanded.endPosition, MonaPosition(line: 1, column: 2))
        XCTAssertTrue(expanded.isFolded)
    }

    func testExpansionAcrossLinesExpandsOutwardByColumnOnEachEndpointLine() {
        // Multi-line non-folded range, both endpoints inside surrogate pairs:
        // start moves back one column on its line, end moves forward one column
        // on its line.
        let range = MonaRange(
            startPosition: MonaPosition(line: 2, column: 4),
            endPosition: MonaPosition(line: 7, column: 9)
        )

        let expanded = range.expandedAcrossSurrogatePair(
            startLandsInsideSurrogatePair: true,
            endLandsInsideSurrogatePair: true
        )

        XCTAssertEqual(expanded.startPosition, MonaPosition(line: 2, column: 3))
        XCTAssertEqual(expanded.endPosition, MonaPosition(line: 7, column: 10))
    }

    // MARK: - MonaSelection: anchor + activePosition + orientation

    func testSelectionStoresAnchorAndActivePosition() {
        let selection = MonaSelection(
            anchor: MonaPosition(line: 1, column: 3),
            activePosition: MonaPosition(line: 1, column: 8)
        )

        XCTAssertEqual(selection.anchor, MonaPosition(line: 1, column: 3))
        XCTAssertEqual(selection.activePosition, MonaPosition(line: 1, column: 8))
    }

    func testSelectionForwardOrientationWhenAnchorPrecedesActive() {
        // anchor < activePosition: anchor is the normalized start -> forward.
        let selection = MonaSelection(
            anchor: MonaPosition(line: 1, column: 3),
            activePosition: MonaPosition(line: 1, column: 8)
        )

        XCTAssertEqual(selection.orientation, .forward)
        XCTAssertEqual(selection.startPosition, MonaPosition(line: 1, column: 3))
        XCTAssertEqual(selection.endPosition, MonaPosition(line: 1, column: 8))
    }

    func testSelectionBackwardOrientationWhenAnchorFollowsActive() {
        // anchor > activePosition: anchor is the normalized end -> backward. The
        // range is normalized (start = active, end = anchor) but the anchor +
        // active positions are preserved as given.
        let selection = MonaSelection(
            anchor: MonaPosition(line: 1, column: 8),
            activePosition: MonaPosition(line: 1, column: 3)
        )

        XCTAssertEqual(selection.orientation, .backward)
        // Normalized range: start = min(anchor, active), end = max(anchor, active).
        XCTAssertEqual(selection.startPosition, MonaPosition(line: 1, column: 3))
        XCTAssertEqual(selection.endPosition, MonaPosition(line: 1, column: 8))
        // Anchor + active preserved verbatim (not swapped).
        XCTAssertEqual(selection.anchor, MonaPosition(line: 1, column: 8))
        XCTAssertEqual(selection.activePosition, MonaPosition(line: 1, column: 3))
    }

    func testSelectionPreservesOrientationWhenNormalizingAcrossLines() {
        // Multi-line backward selection: anchor on a later line than active.
        let selection = MonaSelection(
            anchor: MonaPosition(line: 5, column: 1),
            activePosition: MonaPosition(line: 1, column: 4)
        )

        XCTAssertEqual(selection.orientation, .backward)
        XCTAssertEqual(selection.startPosition, MonaPosition(line: 1, column: 4))
        XCTAssertEqual(selection.endPosition, MonaPosition(line: 5, column: 1))
        XCTAssertEqual(selection.anchor, MonaPosition(line: 5, column: 1))
        XCTAssertEqual(selection.activePosition, MonaPosition(line: 1, column: 4))
    }

    func testSelectionCollapsedIsForwardAndRangeIsFolded() {
        let selection = MonaSelection(
            anchor: MonaPosition(line: 2, column: 6),
            activePosition: MonaPosition(line: 2, column: 6)
        )

        // Monaco getDirection: selectionStart == start -> LTR (forward).
        XCTAssertEqual(selection.orientation, .forward)
        XCTAssertEqual(selection.startPosition, selection.endPosition)
        XCTAssertEqual(selection.startPosition, MonaPosition(line: 2, column: 6))
    }

    func testSelectionConstructedFromRangeAndOrientationSetsAnchorAndActive() {
        let start = MonaPosition(line: 1, column: 3)
        let end = MonaPosition(line: 1, column: 8)

        let forward = MonaSelection(startPosition: start, endPosition: end, orientation: .forward)
        XCTAssertEqual(forward.anchor, start)
        XCTAssertEqual(forward.activePosition, end)
        XCTAssertEqual(forward.orientation, .forward)

        let backward = MonaSelection(startPosition: start, endPosition: end, orientation: .backward)
        XCTAssertEqual(backward.anchor, end)
        XCTAssertEqual(backward.activePosition, start)
        XCTAssertEqual(backward.orientation, .backward)
    }

    func testSelectionEqualityDistinguishesOrientationForSameRange() {
        // Same normalized range, opposite orientations: anchor/active differ, so
        // the selections are NOT equal. Orientation is part of selection identity.
        let forward = MonaSelection(
            anchor: MonaPosition(line: 1, column: 3),
            activePosition: MonaPosition(line: 1, column: 8)
        )
        let backward = MonaSelection(
            anchor: MonaPosition(line: 1, column: 8),
            activePosition: MonaPosition(line: 1, column: 3)
        )

        // Same normalized range.
        XCTAssertEqual(forward.startPosition, backward.startPosition)
        XCTAssertEqual(forward.endPosition, backward.endPosition)
        // Different orientation -> not equal.
        XCTAssertNotEqual(forward.orientation, backward.orientation)
        XCTAssertNotEqual(forward, backward)
    }

    func testSelectionEqualityIsValueBasedAndHashEqual() {
        let a = MonaSelection(
            anchor: MonaPosition(line: 4, column: 2),
            activePosition: MonaPosition(line: 9, column: 1)
        )
        let b = MonaSelection(
            anchor: MonaPosition(line: 4, column: 2),
            activePosition: MonaPosition(line: 9, column: 1)
        )

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}
