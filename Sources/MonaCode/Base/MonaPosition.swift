// MonaPosition.swift
//
// P01-T001 — Implement raw UTF-16 positions and validation modes.
//
// `MonaPosition` is the base-model position value type. It stores one-based
// `line` and `column` as `Int`, where `column` is a raw UTF-16 code-unit offset
// into a line. No grapheme conversion is ever applied: the integer passed in is
// the integer stored, including for offsets that land inside a surrogate pair.
// This matches Monaco's contract that positions are raw UTF-16 coordinates and
// are never rounded to grapheme boundaries.
//
// Three validation modes are provided as separate code paths:
//   - `.strict`    rejects `line < 1` or `column < 1` (throws, or returns nil
//                  via the failable factory).
//   - `.relaxed`   clamps `line` and `column` to a minimum of 1.
//   - `.rawOffset` accepts any value with no validation.
//
// `MonaPosition` is `Equatable`, `Hashable`, and `Comparable`. Comparator
// identity is value-based: two positions with equal `line` and `column` are
// equal and hash-equal regardless of which construction path produced them, and
// transformations that produce equal values are identity-preserving.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A one-based line + column position stored as raw UTF-16 code-unit offsets.
///
/// `line` and `column` are both 1-based `Int` values. The `column` is a raw
/// UTF-16 code-unit offset into the line's text — it is never converted to a
/// grapheme count, so offsets that land inside a surrogate pair are preserved
/// verbatim. This is the raw UTF-16 contract inherited from Monaco.
///
/// The plain initializer `init(line:column:)` stores the values without
/// validation (the raw path). Use `validate(line:column:mode:)` or
/// `validateOrNil(line:column:mode:)` to apply one of the three validation
/// modes.
///
/// Equality and ordering are value-based: two positions with equal `line` and
/// `column` are equal and hash-equal regardless of construction path.
/// `Comparable` orders line-major (line first, then column).
public struct MonaPosition: Equatable, Hashable, Comparable {

    /// One-based line number.
    public let line: Int

    /// One-based column, as a raw UTF-16 code-unit offset (no grapheme
    /// conversion).
    public let column: Int

    /// Creates a position storing `line` and `column` verbatim.
    ///
    /// No validation is applied: this is the raw construction path. Negative or
    /// zero values are stored as given. To reject or clamp out-of-range values,
    /// use `validate(line:column:mode:)`.
    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    /// Line-major ordering: compares `line` first, then `column`.
    public static func < (lhs: MonaPosition, rhs: MonaPosition) -> Bool {
        if lhs.line != rhs.line {
            return lhs.line < rhs.line
        }
        return lhs.column < rhs.column
    }
}

/// The validation policy applied when constructing a `MonaPosition`.
public enum MonaPositionValidationMode {

    /// Reject positions whose `line` or `column` is below 1.
    ///
    /// `validate(line:column:mode:)` throws when `line < 1` or `column < 1`;
    /// `validateOrNil(line:column:mode:)` returns `nil` for the same inputs.
    case strict

    /// Clamp `line` and `column` to a minimum of 1.
    ///
    /// Values below 1 are raised to 1; valid values are left unchanged. This
    /// path never throws and never returns `nil`.
    case relaxed

    /// Accept any value with no validation.
    ///
    /// `line` and `column` are stored verbatim, including negatives and zero.
    /// This path never throws and never returns `nil`.
    case rawOffset
}

/// A validation error raised by `MonaPosition.validate(line:column:mode:)`
/// when `.strict` mode rejects an out-of-range coordinate.
public enum MonaPositionValidationError: Error, Equatable {

    /// `line` was below the 1-based minimum.
    case lineBelowMinimum(Int)

    /// `column` was below the 1-based minimum.
    case columnBelowMinimum(Int)
}

extension MonaPosition {

    /// Validates `line` and `column` according to `mode` and returns the
    /// resulting position.
    ///
    /// - `.strict`: throws `MonaPositionValidationError` when `line < 1` or
    ///   `column < 1`. The line check runs first.
    /// - `.relaxed`: clamps `line` and `column` to a minimum of 1; never
    ///   throws.
    /// - `.rawOffset`: stores `line` and `column` verbatim; never throws.
    public static func validate(
        line: Int,
        column: Int,
        mode: MonaPositionValidationMode
    ) throws -> MonaPosition {
        switch mode {
        case .strict:
            guard line >= 1 else {
                throw MonaPositionValidationError.lineBelowMinimum(line)
            }
            guard column >= 1 else {
                throw MonaPositionValidationError.columnBelowMinimum(column)
            }
            return MonaPosition(line: line, column: column)
        case .relaxed:
            return MonaPosition(line: max(line, 1), column: max(column, 1))
        case .rawOffset:
            return MonaPosition(line: line, column: column)
        }
    }

    /// Validates `line` and `column` according to `mode` and returns the
    /// resulting position, or `nil` if rejected.
    ///
    /// - `.strict`: returns `nil` when `line < 1` or `column < 1`.
    /// - `.relaxed`: clamps to a minimum of 1; never returns `nil`.
    /// - `.rawOffset`: stores verbatim; never returns `nil`.
    public static func validateOrNil(
        line: Int,
        column: Int,
        mode: MonaPositionValidationMode
    ) -> MonaPosition? {
        switch mode {
        case .strict:
            guard line >= 1, column >= 1 else { return nil }
            return MonaPosition(line: line, column: column)
        case .relaxed:
            return MonaPosition(line: max(line, 1), column: max(column, 1))
        case .rawOffset:
            return MonaPosition(line: line, column: column)
        }
    }

    /// Returns a new position with `lineDelta` and `columnDelta` applied.
    ///
    /// The deltas are raw UTF-16 code-unit offsets and are added directly to
    /// the stored values with no clamping or grapheme conversion. A zero-delta
    /// translation returns a position equal to the receiver, preserving
    /// comparator identity.
    public func translated(lineDelta: Int = 0, columnDelta: Int = 0) -> MonaPosition {
        return MonaPosition(line: line + lineDelta, column: column + columnDelta)
    }
}
