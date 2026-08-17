// MonaFailedLineRecordTests.swift
//
// P03-T008 — Represent bounded Core Text failure with FailedLineRecord.
//
// Verifies `MonaFailedLineRecord` (the immutable placeholder produced when
// shaping or line construction for one line fails) and its typed
// `MonaFailedLineReason`:
//   - The record is immutable with value semantics.
//   - It retains the model line number, raw UTF-16 range, the
//     `MonaLineLayoutDependencyStamp` (from P03-T003) captured at failure time,
//     a typed reason, the retry generation, and a safe fallback height.
//   - The typed reason covers shaping, font-unavailable, font-descriptor-
//     invalid, memory-exceeded, and line-construction failures, and a bounded
//     `MonaTextShaperError` (from P03-T002) maps to the typed reason.
//   - The record PREVENTS hit testing, selection geometry, or renderer code
//     from consuming partial glyph data: no glyph runs are exposed
//     (`glyphRunCount` is always 0) — the record is a placeholder that takes
//     space but has no glyph data.
//
// One contract case: immutable failed-line record + typed reason + raw range
// + dependency stamp + retry generation + safe fallback height + no glyph data.

import XCTest
import CoreGraphics
@testable import MonaCodeAppKit

final class MonaFailedLineRecordTests: XCTestCase {

    // MARK: - Helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    private func makeStamp(
        scale: CGFloat = 1,
        direction: MonaTextDirection = .ltr,
        wrappingColumn: Int? = nil
    ) -> MonaLineLayoutDependencyStamp {
        return MonaLineLayoutDependencyStamp(
            fontDescriptor: menlo,
            scale: scale,
            direction: direction,
            wrappingColumn: wrappingColumn
        )
    }

    private func makeRecord(
        modelLineNumber: Int = 1,
        rawRange: Range<Int> = 0..<1,
        reason: MonaFailedLineReason = .shapingFailed,
        retryGeneration: Int = 0,
        safeFallbackHeight: Double = 16.0
    ) -> MonaFailedLineRecord {
        return MonaFailedLineRecord(
            modelLineNumber: modelLineNumber,
            rawRange: rawRange,
            dependencyStamp: makeStamp(),
            reason: reason,
            retryGeneration: retryGeneration,
            safeFallbackHeight: safeFallbackHeight
        )
    }

    // MARK: - Immutability + value semantics

    func testRecordIsImmutableWithValueSemantics() {
        let stamp = makeStamp()
        let recordA = MonaFailedLineRecord(
            modelLineNumber: 4,
            rawRange: 10..<20,
            dependencyStamp: stamp,
            reason: .shapingFailed,
            retryGeneration: 7,
            safeFallbackHeight: 16.0
        )
        let recordB = MonaFailedLineRecord(
            modelLineNumber: 4,
            rawRange: 10..<20,
            dependencyStamp: stamp,
            reason: .shapingFailed,
            retryGeneration: 7,
            safeFallbackHeight: 16.0
        )
        XCTAssertEqual(recordA, recordB)

        // Value semantics: a distinct field yields a non-equal record.
        let recordC = MonaFailedLineRecord(
            modelLineNumber: 4,
            rawRange: 10..<20,
            dependencyStamp: stamp,
            reason: .fontUnavailable,
            retryGeneration: 7,
            safeFallbackHeight: 16.0
        )
        XCTAssertNotEqual(recordA, recordC)
    }

    // MARK: - Retained fields

    func testRetainsModelLineNumberAndRawRange() {
        let record = makeRecord(
            modelLineNumber: 12,
            rawRange: 30..<48,
            reason: .memoryExceeded
        )
        XCTAssertEqual(record.modelLineNumber, 12)
        XCTAssertEqual(record.rawRange, 30..<48)
    }

    func testRetainsDependencyStamp() {
        let stamp = makeStamp(scale: 2, direction: .rtl, wrappingColumn: 80)
        let record = MonaFailedLineRecord(
            modelLineNumber: 1,
            rawRange: 0..<5,
            dependencyStamp: stamp,
            reason: .shapingFailed,
            retryGeneration: 1,
            safeFallbackHeight: 14.0
        )
        XCTAssertEqual(record.dependencyStamp, stamp)
        XCTAssertEqual(record.dependencyStamp.fontDescriptor, menlo)
        XCTAssertEqual(record.dependencyStamp.scale, 2)
        XCTAssertEqual(record.dependencyStamp.direction, .rtl)
        XCTAssertEqual(record.dependencyStamp.wrappingColumn, 80)
    }

    func testRetainsRetryGeneration() {
        let record = makeRecord(retryGeneration: 42)
        XCTAssertEqual(record.retryGeneration, 42)
    }

    func testRetainsSafeFallbackHeight() {
        let record = makeRecord(safeFallbackHeight: 19.25)
        XCTAssertEqual(record.safeFallbackHeight, 19.25, accuracy: 1e-9)
    }

    // MARK: - Typed reasons

    func testAllReasonCasesRoundTrip() {
        let reasons: [MonaFailedLineReason] = [
            .shapingFailed,
            .fontUnavailable,
            .fontDescriptorInvalid,
            .memoryExceeded,
            .lineConstructionFailed
        ]
        for reason in reasons {
            let record = makeRecord(reason: reason)
            XCTAssertEqual(record.reason, reason)
        }
    }

    func testReasonEqualityDistinguishesCases() {
        XCTAssertNotEqual(MonaFailedLineReason.shapingFailed, .fontUnavailable)
        XCTAssertNotEqual(MonaFailedLineReason.fontUnavailable, .fontDescriptorInvalid)
        XCTAssertNotEqual(MonaFailedLineReason.fontDescriptorInvalid, .memoryExceeded)
        XCTAssertNotEqual(MonaFailedLineReason.memoryExceeded, .lineConstructionFailed)
        XCTAssertNotEqual(MonaFailedLineReason.lineConstructionFailed, .shapingFailed)
    }

    // MARK: - Shaper-error → reason conversion

    func testShaperErrorMapsToTypedReason() {
        let stamp = makeStamp()

        // fontDescriptorInvalid -> .fontDescriptorInvalid
        let invalidDesc = MonaFontDescriptor(familyName: "", size: 0)
        let invalidRecord = MonaFailedLineRecord(
            modelLineNumber: 1,
            rawRange: 0..<1,
            dependencyStamp: stamp,
            shaperError: .fontDescriptorInvalid(invalidDesc),
            retryGeneration: 0,
            safeFallbackHeight: 16.0
        )
        XCTAssertEqual(invalidRecord.reason, .fontDescriptorInvalid)

        // primaryFontUnavailable -> .fontUnavailable
        let unavailableRecord = MonaFailedLineRecord(
            modelLineNumber: 2,
            rawRange: 0..<1,
            dependencyStamp: stamp,
            shaperError: .primaryFontUnavailable(menlo, resolvedFamilyName: "Helvetica"),
            retryGeneration: 1,
            safeFallbackHeight: 16.0
        )
        XCTAssertEqual(unavailableRecord.reason, .fontUnavailable)

        // coreTextShapingFailed -> .shapingFailed
        let shapingRecord = MonaFailedLineRecord(
            modelLineNumber: 3,
            rawRange: 0..<1,
            dependencyStamp: stamp,
            shaperError: .coreTextShapingFailed("CTLine returned nil"),
            retryGeneration: 2,
            safeFallbackHeight: 16.0
        )
        XCTAssertEqual(shapingRecord.reason, .shapingFailed)
    }

    func testReasonFactoryMapsEachShaperErrorCase() {
        XCTAssertEqual(
            MonaFailedLineReason.reason(for: .fontDescriptorInvalid(menlo)),
            .fontDescriptorInvalid
        )
        XCTAssertEqual(
            MonaFailedLineReason.reason(for: .primaryFontUnavailable(menlo, resolvedFamilyName: nil)),
            .fontUnavailable
        )
        XCTAssertEqual(
            MonaFailedLineReason.reason(for: .coreTextShapingFailed("boom")),
            .shapingFailed
        )
    }

    // MARK: - Prevents partial glyph consumption

    func testExposesNoGlyphData() {
        let record = makeRecord(
            modelLineNumber: 5,
            rawRange: 0..<10,
            reason: .shapingFailed
        )
        // The record is a placeholder: it exposes zero glyph runs so hit
        // testing, selection geometry, and renderer code cannot consume any
        // partial glyph data from the failed line.
        XCTAssertEqual(record.glyphRunCount, 0)
    }

    func testSafeFallbackHeightReservesVerticalSpace() {
        let record = makeRecord(safeFallbackHeight: 22.0)
        // The only geometry a failed-line record exposes is its safe fallback
        // height, used to reserve vertical space so the line still takes room.
        XCTAssertEqual(record.safeFallbackHeight, 22.0, accuracy: 1e-9)
        XCTAssertEqual(record.glyphRunCount, 0)
    }

    func testPlaceholderContractHoldsAcrossAllReasons() {
        // Regardless of the failure reason, a failed-line record never exposes
        // glyph data and always reserves vertical space.
        for reason in [
            MonaFailedLineReason.shapingFailed,
            .fontUnavailable,
            .fontDescriptorInvalid,
            .memoryExceeded,
            .lineConstructionFailed
        ] {
            let record = makeRecord(reason: reason, safeFallbackHeight: 18.0)
            XCTAssertEqual(record.glyphRunCount, 0, "reason \(reason) must not expose glyph data")
            XCTAssertGreaterThan(record.safeFallbackHeight, 0, "reason \(reason) must reserve space")
        }
    }
}
