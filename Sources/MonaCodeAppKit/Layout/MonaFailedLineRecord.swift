// MonaFailedLineRecord.swift
//
// P03-T008 — Represent bounded Core Text failure with FailedLineRecord.
//
// `MonaFailedLineRecord` is the immutable value produced when shaping (P03-T002)
// or line construction (P03-T003) for one line fails. Instead of publishing
// partial glyph data, the pipeline emits a `MonaFailedLineRecord`: a PLACEHOLDER
// that reserves vertical space (via `safeFallbackHeight`) so the line still
// takes room in the layout, but exposes NO glyph runs, advances, positions, or
// raw-unit boundaries. Hit testing, selection geometry, and renderer code
// therefore cannot consume partial glyph data from a failed line — there is no
// glyph API to read (`glyphRunCount` is always `0`).
//
// The record retains everything the pipeline needs to retry the line at a later
// generation: the 1-based model line number, the raw UTF-16 range that failed,
// the `MonaLineLayoutDependencyStamp` (from P03-T003) captured at failure time,
// a typed `MonaFailedLineReason`, the generation at which to retry, and the safe
// fallback height.
//
// The convenience initializer `init(modelLineNumber:rawRange:dependencyStamp:
// shaperError:retryGeneration:safeFallbackHeight:)` converts a bounded
// `MonaTextShaperError` (from P03-T002) into the typed reason, directly
// implementing the "Convert bounded shaping and line-construction failures into
// immutable failed-line records" operation.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// Foundation + CoreGraphics (per the P03-T008 contract).

import Foundation
import CoreGraphics

// MARK: - MonaFailedLineReason

/// A typed reason a line failed to shape or construct.
///
/// The reason is the typed tag carried by every `MonaFailedLineRecord`. It is
/// derived from the bounded failure that produced the record: a
/// `MonaTextShaperError` (from P03-T002) maps to one of `.shapingFailed`,
/// `.fontUnavailable`, or `.fontDescriptorInvalid`; a bounded resource
/// exhaustion maps to `.memoryExceeded`; any other line-construction failure
/// maps to `.lineConstructionFailed`.
public enum MonaFailedLineReason: Equatable, Hashable, Sendable {

    /// Core Text failed to shape the line (e.g. `CTLineCreateWithAttributedString`
    /// returned nil). No glyph runs are published.
    case shapingFailed

    /// The primary font could not be resolved to the requested family — Core
    /// Text silently substituted a different face.
    case fontUnavailable

    /// The font descriptor was malformed (empty family name or non-positive
    /// size) and could not be used to shape.
    case fontDescriptorInvalid

    /// A bounded resource (e.g. memory) was exceeded while shaping or building
    /// the line. The line may be retried once the resource pressure eases.
    case memoryExceeded

    /// Line construction failed for a reason other than shaping (e.g. the
    /// `MonaLineLayoutBuilder` could not assemble the record from a valid
    /// `MonaShapingResult`).
    case lineConstructionFailed

    /// Maps a bounded `MonaTextShaperError` (from P03-T002) to the typed reason
    /// carried by a `MonaFailedLineRecord`. This is the "Convert bounded shaping
    /// failures into immutable failed-line records" conversion.
    public static func reason(for error: MonaTextShaperError) -> MonaFailedLineReason {
        switch error {
        case .fontDescriptorInvalid:
            return .fontDescriptorInvalid
        case .primaryFontUnavailable:
            return .fontUnavailable
        case .coreTextShapingFailed:
            return .shapingFailed
        }
    }
}

// MARK: - MonaFailedLineRecord

/// An immutable placeholder record for a line that failed to shape or construct.
///
/// When bounded shaping (P03-T002) or line construction (P03-T003) fails for a
/// line, the pipeline emits a `MonaFailedLineRecord` instead of publishing
/// partial glyph data. The record is a PLACEHOLDER: it reserves vertical space
/// (via `safeFallbackHeight`) so the line still takes room in the layout, but it
/// exposes NO glyph runs, advances, positions, or raw-unit boundaries. Hit
/// testing, selection geometry, and renderer code therefore cannot consume any
/// partial glyph data from a failed line — there is no glyph API to read
/// (`glyphRunCount` is always `0`).
///
/// The record retains everything the pipeline needs to retry the line at a
/// later generation: the 1-based model line number, the raw UTF-16 range, the
/// `MonaLineLayoutDependencyStamp` (from P03-T003) captured at failure time, a
/// typed `MonaFailedLineReason`, and the retry generation.
public struct MonaFailedLineRecord: Equatable, Hashable, Sendable {

    /// The 1-based model line that failed.
    public let modelLineNumber: Int

    /// The raw UTF-16 range in the model that failed to shape or construct.
    public let rawRange: Range<Int>

    /// The dependency stamp captured at failure time (from P03-T003). Captures
    /// the font descriptor, scale, direction, and wrapping column that were in
    /// effect when the line failed, so the pipeline can decide whether a retry
    /// would face the same shaping inputs.
    public let dependencyStamp: MonaLineLayoutDependencyStamp

    /// The typed reason the line failed.
    public let reason: MonaFailedLineReason

    /// The generation at which to retry shaping/construction for this line.
    public let retryGeneration: Int

    /// A safe line height used to reserve vertical space so the failed line
    /// still takes room in the layout. This is the ONLY geometry the record
    /// exposes; no glyph data is published. Must be greater than zero.
    public let safeFallbackHeight: Double

    /// Creates an immutable failed-line record from a typed reason.
    ///
    /// - Parameters:
    ///   - modelLineNumber: The 1-based model line that failed.
    ///   - rawRange: The raw UTF-16 range in the model that failed.
    ///   - dependencyStamp: The dependency stamp captured at failure time.
    ///   - reason: The typed failure reason.
    ///   - retryGeneration: The generation at which to retry.
    ///   - safeFallbackHeight: A positive safe line height reserving vertical
    ///     space so the line still takes room. Must be greater than zero.
    public init(
        modelLineNumber: Int,
        rawRange: Range<Int>,
        dependencyStamp: MonaLineLayoutDependencyStamp,
        reason: MonaFailedLineReason,
        retryGeneration: Int,
        safeFallbackHeight: Double
    ) {
        precondition(
            safeFallbackHeight > 0,
            "MonaFailedLineRecord.safeFallbackHeight must be positive so the failed line still takes space"
        )
        self.modelLineNumber = modelLineNumber
        self.rawRange = rawRange
        self.dependencyStamp = dependencyStamp
        self.reason = reason
        self.retryGeneration = retryGeneration
        self.safeFallbackHeight = safeFallbackHeight
    }

    /// Creates an immutable failed-line record from a bounded
    /// `MonaTextShaperError` (from P03-T002), deriving the typed `reason` from
    /// the error. This convenience directly implements the "Convert bounded
    /// shaping failures into immutable failed-line records" operation: the
    /// caller supplies the shaping error, and the record stores the
    /// corresponding typed reason.
    ///
    /// - Parameters:
    ///   - modelLineNumber: The 1-based model line that failed.
    ///   - rawRange: The raw UTF-16 range in the model that failed.
    ///   - dependencyStamp: The dependency stamp captured at failure time.
    ///   - shaperError: The bounded shaping error thrown by `MonaTextShaper`.
    ///   - retryGeneration: The generation at which to retry.
    ///   - safeFallbackHeight: A positive safe line height reserving vertical
    ///     space so the line still takes room. Must be greater than zero.
    public init(
        modelLineNumber: Int,
        rawRange: Range<Int>,
        dependencyStamp: MonaLineLayoutDependencyStamp,
        shaperError: MonaTextShaperError,
        retryGeneration: Int,
        safeFallbackHeight: Double
    ) {
        self.init(
            modelLineNumber: modelLineNumber,
            rawRange: rawRange,
            dependencyStamp: dependencyStamp,
            reason: MonaFailedLineReason.reason(for: shaperError),
            retryGeneration: retryGeneration,
            safeFallbackHeight: safeFallbackHeight
        )
    }

    /// The number of glyph runs this record exposes for rendering or hit
    /// testing. Always `0`.
    ///
    /// A failed-line record is a PLACEHOLDER: it never publishes partial glyph
    /// data. Hit testing, selection geometry, and renderer code must check this
    /// (or branch on the record type) and never attempt to consume glyph runs
    /// from a failed line. There is no glyph-run, advance, position, or
    /// raw-unit-boundary API on this record.
    public var glyphRunCount: Int { 0 }
}
