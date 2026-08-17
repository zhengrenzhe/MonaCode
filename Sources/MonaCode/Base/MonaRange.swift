// MonaRange.swift
//
// P01-T002 — Implement ranges and oriented selections.
//
// `MonaRange` is the base-model range value type. It stores a `startPosition`
// and an `endPosition` (both `MonaPosition`, one-based line + raw UTF-16
// column). The constructor normalizes reversed endpoints branch-for-branch from
// Monaco's `Range` constructor: when the start would sort after the end
// (line-major, then column), the two endpoints are swapped so that
// `startPosition <= endPosition` always holds. This matches Monaco's invariant
// that `(startLineNumber, startColumn) <= (endLineNumber, endColumn)`.
//
// Three intersection predicates are ported branch-for-branch from Monaco's
// `Range` (monaco-editor 0.56.0, vscodeRef f487add297079a02eb836810185b165e50cadabc):
//   - `contains(_:)`         — `Range.containsPosition`. Edges are inclusive.
//   - `intersects(_:)`        — `Range.areIntersectingOrTouching`. Touching
//                               (adjacency) counts as intersecting (strict `<`).
//   - `areIntersecting(_:)`   — `Range.areIntersecting`. Touching is excluded
//                               (`<=`). The method name reads as if touching
//                               counts, but the source uses `<=` so it does
//                               not; the branch logic, not the name, is ported.
//
// `expandedAcrossSurrogatePair` ports the surrogate-pair block of Monaco's
// `TextModel.validateRange` branch-for-branch. A position "lands inside a
// surrogate pair" when the UTF-16 unit immediately before it is a high
// surrogate (the position sits between the high and low surrogate). The caller,
// which owns the text, computes the two booleans. For a non-folded range the
// nearer endpoint expands outward by one UTF-16 unit so the pair is wholly
// embraced; for a folded range the collapsed position moves back by one to a
// valid location instead of expanding. If neither endpoint lands inside a pair
// the range is returned unchanged.
//
// `MonaRange` is `Equatable` and `Hashable` with value semantics: two ranges
// with equal start + end positions are equal and hash-equal regardless of
// construction path (including the reversed-input normalization).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A normalized range between two `MonaPosition` endpoints.
///
/// The constructor swaps reversed endpoints so that `startPosition` always
/// sorts at or before `endPosition` (line-major, then column), matching
/// Monaco's `Range` constructor. The three intersection predicates are ported
/// branch-for-branch from Monaco's `Range`; see each method's documentation for
/// the exact boundary behavior, which is driven by the source, not the name.
public struct MonaRange: Equatable, Hashable {

    /// The normalized start position (sorts at or before `endPosition`).
    public let startPosition: MonaPosition

    /// The normalized end position (sorts at or after `startPosition`).
    public let endPosition: MonaPosition

    /// Creates a range, normalizing reversed endpoints so that
    /// `startPosition <= endPosition`.
    ///
    /// When `startPosition` sorts after `endPosition` (line-major, then
    /// column), the two are swapped. This is the branch-for-branch port of
    /// Monaco's `Range` constructor.
    public init(startPosition: MonaPosition, endPosition: MonaPosition) {
        if startPosition > endPosition {
            self.startPosition = endPosition
            self.endPosition = startPosition
        } else {
            self.startPosition = startPosition
            self.endPosition = endPosition
        }
    }

    /// Creates a range from raw one-based line/column coordinates, normalizing
    /// reversed endpoints.
    public init(
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int
    ) {
        self.init(
            startPosition: MonaPosition(line: startLine, column: startColumn),
            endPosition: MonaPosition(line: endLine, column: endColumn)
        )
    }

    /// `true` when the range is folded (collapsed): `startPosition == endPosition`.
    public var isFolded: Bool {
        return startPosition == endPosition
    }
}

extension MonaRange {

    // MARK: - contains(_:) — Range.containsPosition (edges inclusive)

    /// Returns `true` when `position` lies within this range, edges inclusive.
    ///
    /// Branch-for-branch port of `Range.containsPosition`:
    ///   - `false` when `position.line` is below `startPosition.line` or above
    ///     `endPosition.line`;
    ///   - `false` when `position` is on the start line and its column is below
    ///     `startPosition.column`;
    ///   - `false` when `position` is on the end line and its column is above
    ///     `endPosition.column`;
    ///   - `true` otherwise (positions at either edge are contained).
    ///
    /// Columns are raw UTF-16 offsets; a column that lands inside a surrogate
    /// pair is a valid raw position and is contained by an inclusive range
    /// covering it.
    public func contains(_ position: MonaPosition) -> Bool {
        if position.line < startPosition.line || position.line > endPosition.line {
            return false
        }
        if position.line == startPosition.line && position.column < startPosition.column {
            return false
        }
        if position.line == endPosition.line && position.column > endPosition.column {
            return false
        }
        return true
    }

    // MARK: - intersects(_:) — Range.areIntersectingOrTouching (touching counts)

    /// Returns `true` when this range and `other` overlap or touch.
    ///
    /// Branch-for-branch port of `Range.areIntersectingOrTouching`. Touching
    /// (one range's end equals the other's start) counts as intersecting: the
    /// boundary comparison uses strict `<`, so equality does not trigger the
    /// `false` branch.
    public func intersects(_ other: MonaRange) -> Bool {
        // Check if `self` is completely before `other`.
        if endPosition.line < other.startPosition.line
            || (endPosition.line == other.startPosition.line
                && endPosition.column < other.startPosition.column) {
            return false
        }
        // Check if `other` is completely before `self`.
        if other.endPosition.line < startPosition.line
            || (other.endPosition.line == startPosition.line
                && other.endPosition.column < startPosition.column) {
            return false
        }
        return true
    }

    // MARK: - areIntersecting(_:) — Range.areIntersecting (touching excluded)

    /// Returns `true` when this range and `other` strictly overlap (touching
    /// does not count).
    ///
    /// Branch-for-branch port of `Range.areIntersecting`. Despite the name
    /// reading as if touching counts, the source uses `<=`, so ranges that only
    /// touch (one's end equals the other's start) return `false`. The branch
    /// logic is ported verbatim, not inferred from the name.
    public func areIntersecting(_ other: MonaRange) -> Bool {
        // Check if `self` is before or only touching `other`.
        if endPosition.line < other.startPosition.line
            || (endPosition.line == other.startPosition.line
                && endPosition.column <= other.startPosition.column) {
            return false
        }
        // Check if `other` is before or only touching `self`.
        if other.endPosition.line < startPosition.line
            || (other.endPosition.line == startPosition.line
                && other.endPosition.column <= startPosition.column) {
            return false
        }
        return true
    }

    // MARK: - Surrogate-pair expansion (TextModel.validateRange surrogate block)

    /// Returns this range expanded outward across any surrogate pair that the
    /// start or end position lands inside.
    ///
    /// Branch-for-branch port of the surrogate-pair block of Monaco's
    /// `TextModel.validateRange`. A position "lands inside a surrogate pair"
    /// when the UTF-16 unit immediately before it is a high surrogate (the
    /// position sits between the high and low surrogate). Because `MonaRange`
    /// holds no text, the caller — which owns the text — computes
    /// `startLandsInsideSurrogatePair` and `endLandsInsideSurrogatePair`.
    ///
    /// - If neither endpoint lands inside a surrogate pair, returns `self`.
    /// - If the range is folded (`startPosition == endPosition`) and at least
    ///   one endpoint lands inside a pair, does not expand; instead moves both
    ///   endpoints back by one UTF-16 unit to a valid location.
    /// - If both endpoints land inside a pair (non-folded), expands outward at
    ///   both ends: start moves back one, end moves forward one.
    /// - If only the start lands inside a pair, expands only the start back one.
    /// - If only the end lands inside a pair, expands only the end forward one.
    public func expandedAcrossSurrogatePair(
        startLandsInsideSurrogatePair: Bool,
        endLandsInsideSurrogatePair: Bool
    ) -> MonaRange {
        if !startLandsInsideSurrogatePair && !endLandsInsideSurrogatePair {
            return self
        }
        // At least one endpoint lands inside a surrogate pair.
        if startPosition == endPosition {
            // Do not expand a folded range; move both endpoints back by one to
            // a valid (non-mid-surrogate) location.
            return MonaRange(
                startPosition: startPosition.translated(columnDelta: -1),
                endPosition: endPosition.translated(columnDelta: -1)
            )
        }
        if startLandsInsideSurrogatePair && endLandsInsideSurrogatePair {
            // Expand at both ends.
            return MonaRange(
                startPosition: startPosition.translated(columnDelta: -1),
                endPosition: endPosition.translated(columnDelta: 1)
            )
        }
        if startLandsInsideSurrogatePair {
            // Only expand at the start.
            return MonaRange(
                startPosition: startPosition.translated(columnDelta: -1),
                endPosition: endPosition
            )
        }
        // Only expand at the end.
        return MonaRange(
            startPosition: startPosition,
            endPosition: endPosition.translated(columnDelta: 1)
        )
    }
}
