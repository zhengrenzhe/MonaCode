// MonaPositionTests.swift
//
// P01-T001 — Implement raw UTF-16 positions and validation modes.
//
// Verifies:
//   - `MonaPosition` stores one-based `line` and `column` as `Int`, held as raw
//     UTF-16 code-unit offsets (no grapheme conversion).
//   - Three validation modes behave as separate code paths:
//       .strict    — rejects line < 1 or column < 1 (throws / returns nil).
//       .relaxed   — clamps line and column to a minimum of 1.
//       .rawOffset — accepts any value with no validation.
//   - Comparator identity: positions with equal line + column are equal and
//     hash-equal regardless of construction path, and transformations that
//     produce equal values are identity-preserving.

import XCTest
import MonaCode

final class MonaPositionTests: XCTestCase {

    // MARK: - Raw UTF-16 storage (one-based, no grapheme conversion)

    func testPositionStoresOneBasedLineAndColumnAsInt() {
        let position = MonaPosition(line: 3, column: 7)

        // Both fields are `Int` — the assignments below would not type-check
        // otherwise.
        let line: Int = position.line
        let column: Int = position.column

        XCTAssertEqual(line, 3)
        XCTAssertEqual(column, 7)
    }

    func testPositionStoresRawUTF16ColumnWithoutGraphemeConversion() {
        // The column is a raw UTF-16 code-unit offset, not a grapheme count.
        // A column of 2 lands between the two UTF-16 units of a surrogate pair
        // (e.g. position inside "𝓐" = U+1D4D0, which is two UTF-16 units). Monaco
        // deliberately permits such positions and never rounds them to grapheme
        // boundaries. MonaCode stores the raw offset verbatim: the value passed
        // in is the value stored, with no conversion applied.
        let surrogateMid = MonaPosition(line: 1, column: 2)

        XCTAssertEqual(surrogateMid.column, 2)

        // Larger offsets also round-trip exactly.
        let deep = MonaPosition(line: 100, column: 0x10FFFF)
        XCTAssertEqual(deep.column, 0x10FFFF)
    }

    // MARK: - Validation modes

    func testStrictValidationAcceptsValidOneBasedPositions() throws {
        let position = try MonaPosition.validate(line: 1, column: 1, mode: .strict)

        XCTAssertEqual(position.line, 1)
        XCTAssertEqual(position.column, 1)

        let further = try MonaPosition.validate(line: 4, column: 9, mode: .strict)
        XCTAssertEqual(further.line, 4)
        XCTAssertEqual(further.column, 9)
    }

    func testStrictValidationRejectsLineBelowOneByThrowing() {
        XCTAssertThrowsError(try MonaPosition.validate(line: 0, column: 1, mode: .strict))
        XCTAssertThrowsError(try MonaPosition.validate(line: -5, column: 1, mode: .strict))
    }

    func testStrictValidationRejectsColumnBelowOneByThrowing() {
        XCTAssertThrowsError(try MonaPosition.validate(line: 1, column: 0, mode: .strict))
        XCTAssertThrowsError(try MonaPosition.validate(line: 1, column: -3, mode: .strict))
    }

    func testStrictValidationReturnsNilForOutOfRangeViaFailableFactory() {
        // Strict rejection is also exposed as a failable factory that returns
        // nil instead of throwing.
        XCTAssertNil(MonaPosition.validateOrNil(line: 0, column: 1, mode: .strict))
        XCTAssertNil(MonaPosition.validateOrNil(line: 1, column: 0, mode: .strict))
        XCTAssertNotNil(MonaPosition.validateOrNil(line: 1, column: 1, mode: .strict))
    }

    func testRelaxedValidationClampsLineAndColumnToMinimumOne() {
        let clampedZero = try? MonaPosition.validate(line: 0, column: 0, mode: .relaxed)
        XCTAssertEqual(clampedZero?.line, 1)
        XCTAssertEqual(clampedZero?.column, 1)

        let clampedNegative = try? MonaPosition.validate(line: -12, column: -40, mode: .relaxed)
        XCTAssertEqual(clampedNegative?.line, 1)
        XCTAssertEqual(clampedNegative?.column, 1)
    }

    func testRelaxedValidationLeavesValidPositionsUnchanged() {
        let valid = try? MonaPosition.validate(line: 7, column: 13, mode: .relaxed)
        XCTAssertEqual(valid?.line, 7)
        XCTAssertEqual(valid?.column, 13)
    }

    func testRawOffsetValidationAcceptsAnyValueWithoutValidation() throws {
        let zero = try MonaPosition.validate(line: 0, column: 0, mode: .rawOffset)
        XCTAssertEqual(zero.line, 0)
        XCTAssertEqual(zero.column, 0)

        let negative = try MonaPosition.validate(line: -2, column: -8, mode: .rawOffset)
        XCTAssertEqual(negative.line, -2)
        XCTAssertEqual(negative.column, -8)

        let valid = try MonaPosition.validate(line: 3, column: 5, mode: .rawOffset)
        XCTAssertEqual(valid.line, 3)
        XCTAssertEqual(valid.column, 5)
    }

    // MARK: - Comparator identity

    func testEqualValuePositionsAreEqualRegardlessOfConstructionPath() throws {
        // The same line + column produced via four different construction
        // paths must all be `==`: raw init, strict, relaxed, and raw-offset.
        let raw = MonaPosition(line: 5, column: 10)
        let strict = try MonaPosition.validate(line: 5, column: 10, mode: .strict)
        let relaxed = try MonaPosition.validate(line: 5, column: 10, mode: .relaxed)
        let rawOffset = try MonaPosition.validate(line: 5, column: 10, mode: .rawOffset)

        XCTAssertEqual(raw, strict)
        XCTAssertEqual(raw, relaxed)
        XCTAssertEqual(raw, rawOffset)
        XCTAssertEqual(strict, relaxed)
    }

    func testEqualValuePositionsHashEqualRegardlessOfConstructionPath() throws {
        let raw = MonaPosition(line: 5, column: 10)
        let strict = try MonaPosition.validate(line: 5, column: 10, mode: .strict)
        let relaxed = try MonaPosition.validate(line: 5, column: 10, mode: .relaxed)

        XCTAssertEqual(raw.hashValue, strict.hashValue)
        XCTAssertEqual(raw.hashValue, relaxed.hashValue)
    }

    func testDistinctValuePositionsAreNotEqual() {
        let a = MonaPosition(line: 1, column: 1)
        let sameLineDiffColumn = MonaPosition(line: 1, column: 2)
        let diffLineSameColumn = MonaPosition(line: 2, column: 1)

        XCTAssertNotEqual(a, sameLineDiffColumn)
        XCTAssertNotEqual(a, diffLineSameColumn)
    }

    // MARK: - Comparable ordering (line-major, then column)

    func testComparableOrdersByLineThenColumn() {
        XCTAssertTrue(MonaPosition(line: 1, column: 1) < MonaPosition(line: 2, column: 1))
        XCTAssertTrue(MonaPosition(line: 1, column: 1) < MonaPosition(line: 1, column: 2))

        // Equal positions are not strictly less than each other.
        XCTAssertFalse(MonaPosition(line: 1, column: 1) < MonaPosition(line: 1, column: 1))

        // Greater line dominates regardless of column.
        XCTAssertFalse(MonaPosition(line: 2, column: 1) < MonaPosition(line: 1, column: 99))
    }

    // MARK: - Transformations preserve identity for equal values

    func testTranslationWithZeroDeltaIsIdentityPreserving() {
        let original = MonaPosition(line: 6, column: 11)

        // A zero-delta translation must yield a position equal to the original:
        // the transformation produces equal values, so identity is preserved.
        let translated = original.translated(lineDelta: 0, columnDelta: 0)

        XCTAssertEqual(translated, original)
        XCTAssertEqual(translated.hashValue, original.hashValue)
    }

    func testTranslationProducingEqualValuesIsIdentityPreserving() {
        // Two different transformations that land on the same line + column
        // must produce equal positions.
        let a = MonaPosition(line: 2, column: 3).translated(lineDelta: 4, columnDelta: 5)
        let b = MonaPosition(line: 6, column: 8).translated(lineDelta: 0, columnDelta: 0)

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testTranslationAppliesDeltasToLineAndColumn() {
        let position = MonaPosition(line: 10, column: 20)
        let moved = position.translated(lineDelta: 3, columnDelta: -7)

        XCTAssertEqual(moved.line, 13)
        XCTAssertEqual(moved.column, 13)
    }
}
