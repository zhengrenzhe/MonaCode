// MonaDiffResult.swift
//
// P07-T001 — Implement legacy and advanced diff engines over raw UTF-16.
//
// The diff result types: the algorithm enum, the computation options, the
// raw-UTF-16 diff input, and the structured diff result (changes, moves, inner
// changes, identical, quitEarly, hitTimeout). These are the public surface
// consumed by the diff-editor feature (T112) and diff views (T009).
//
// The four public `MonaDiffAlgorithm` values — `legacy`, `advanced`,
// `advancedExternal`, `advancedWasm` — are frozen by D1-R. Only `legacy` and
// `advanced` are functional Swift ports; `advancedExternal` and
// `advancedWasm` are retained enum values that are always unavailable (their
// disposition is handled by the diff coordinator, T002).
//
// All line, column and inner-change ranges use Monaco's one-based line/column
// and raw-UTF-16 column domain fixed by M1/F1. The `identical` field compares
// line count and each line's raw UTF-16 content; it does not compare an EOL
// byte sequence separately.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The four frozen diff algorithm values (D1-R).
///
/// `legacy` and `advanced` are functional Swift ports. `advancedExternal` and
/// `advancedWasm` are retained enum values that are always unavailable in the
/// fixed official npm baseline — their disposition (mark stale, emit
/// unavailable event, publish no result) is handled by the diff coordinator.
public enum MonaDiffAlgorithm: String, Equatable, Sendable {

    /// The legacy LCS-based line + character diff engine.
    case legacy

    /// The advanced diff engine: DP/Myers line diff, character refinement,
    /// heuristics, and optional moved-block detection.
    case advanced

    /// Retained enum value; always unavailable in the fixed baseline.
    case advancedExternal

    /// Retained enum value; always unavailable in the fixed baseline.
    case advancedWasm
}

/// The diff computation options.
///
/// `maxComputationTimeMs` is the wall-clock budget (0 = infinite). The legacy
/// engine uses the full budget for the line phase and `min(budget, 5000)` (or
/// 0 for infinite) for the character phase. The advanced engine constructs one
/// shared timeout covering all phases.
///
/// `ignoreTrimWhitespace` (default `true`) controls whether line hashing trims
/// leading/trailing whitespace before assigning integer identities.
///
/// `computeMoves` (default `false`) enables moved-block detection in the
/// advanced engine; the legacy engine ignores this flag.
public struct MonaDiffOptions: Equatable, Sendable {

    /// The wall-clock computation budget in milliseconds. 0 means infinite.
    public let maxComputationTimeMs: Int

    /// When `true`, line hashing trims each line before assigning an identity.
    public let ignoreTrimWhitespace: Bool

    /// When `true`, the advanced engine detects moved line blocks.
    public let computeMoves: Bool

    /// Creates diff options.
    public init(maxComputationTimeMs: Int, ignoreTrimWhitespace: Bool, computeMoves: Bool) {
        self.maxComputationTimeMs = maxComputationTimeMs
        self.ignoreTrimWhitespace = ignoreTrimWhitespace
        self.computeMoves = computeMoves
    }

    /// The Monaco default options: 5000 ms, trim whitespace, no moves.
    public static let monacoDefault: MonaDiffOptions = MonaDiffOptions(
        maxComputationTimeMs: 5000, ignoreTrimWhitespace: true, computeMoves: false
    )
}

/// The raw-UTF-16 diff input: the original and modified documents as arrays of
/// lines, where each line is a `[UInt16]` (content excluding the trailing
/// newline). Lone surrogates are preserved verbatim.
public struct MonaDiffInput: Equatable, Sendable {

    /// The original document lines, as raw UTF-16 code-unit arrays.
    public let originalLines: [[UInt16]]

    /// The modified document lines, as raw UTF-16 code-unit arrays.
    public let modifiedLines: [[UInt16]]

    /// Creates a diff input.
    public init(originalLines: [[UInt16]], modifiedLines: [[UInt16]]) {
        self.originalLines = originalLines
        self.modifiedLines = modifiedLines
    }
}

/// A character-level inner change within a changed line block.
///
/// `originalRange` and `modifiedRange` are raw-UTF-16 column ranges (one-based
/// line + column) within the changed block's line span.
public struct MonaDiffInnerChange: Equatable, Hashable, @unchecked Sendable {

    /// The character range in the original document that was removed.
    public let originalRange: MonaRange

    /// The character range in the modified document that replaced it.
    public let modifiedRange: MonaRange

    /// Creates an inner change.
    public init(originalRange: MonaRange, modifiedRange: MonaRange) {
        self.originalRange = originalRange
        self.modifiedRange = modifiedRange
    }
}

/// A line-level range mapping: a region of the original that maps to a region of
/// the modified, optionally refined to character-level inner changes.
public struct MonaDiffRangeMapping: Equatable, Hashable, @unchecked Sendable {

    /// The line range in the original document.
    public let originalRange: MonaRange

    /// The line range in the modified document.
    public let modifiedRange: MonaRange

    /// Character-level inner changes within this line block. Empty when no
    /// character refinement was performed (e.g. different line counts, or
    /// refinement skipped due to timeout).
    public let innerChanges: [MonaDiffInnerChange]

    /// Creates a range mapping.
    public init(originalRange: MonaRange, modifiedRange: MonaRange, innerChanges: [MonaDiffInnerChange] = []) {
        self.originalRange = originalRange
        self.modifiedRange = modifiedRange
        self.innerChanges = innerChanges
    }
}

/// A moved line block: a range in the original that was removed and a range in
/// the modified that was inserted, where the content matches (a move, not a
/// pure insert/delete). Emitted only by the advanced engine with
/// `computeMoves = true`.
public struct MonaDiffMove: Equatable, Hashable, @unchecked Sendable {

    /// The line range in the original document that moved.
    public let originalRange: MonaRange

    /// The line range in the modified document where it landed.
    public let modifiedRange: MonaRange

    /// Character-level inner changes within the moved block.
    public let innerChanges: [MonaDiffInnerChange]

    /// Creates a move.
    public init(originalRange: MonaRange, modifiedRange: MonaRange, innerChanges: [MonaDiffInnerChange] = []) {
        self.originalRange = originalRange
        self.modifiedRange = modifiedRange
        self.innerChanges = innerChanges
    }
}

/// The structured diff result.
///
/// - `changes`: the line-level change blocks (sorted, contiguous, deduplicated).
/// - `moves`: the moved blocks (advanced + `computeMoves` only; empty otherwise).
/// - `identical`: `true` when original and modified have the same line count and
///   each line's raw UTF-16 content matches.
/// - `quitEarly`: `true` when the computation aborted (cancellation or timeout).
/// - `hitTimeout`: an optional field — `false` on normal completion, `true` when
///   a frozen timeout checkpoint observed expiration.
public struct MonaDiffResult: Equatable, @unchecked Sendable {

    /// The line-level change blocks, normalized (sorted, contiguous, dedup).
    public let changes: [MonaDiffRangeMapping]

    /// The moved blocks. Empty unless advanced + `computeMoves`.
    public let moves: [MonaDiffMove]

    /// `true` when the two sides are identical by the raw-UTF-16 identity rule.
    public var identical: Bool

    /// `true` when the computation aborted early (cancellation or timeout).
    public var quitEarly: Bool

    /// Optional field: `true` only when a frozen timeout checkpoint expired.
    public var hitTimeout: Bool

    /// Creates a diff result.
    public init(
        changes: [MonaDiffRangeMapping] = [],
        moves: [MonaDiffMove] = [],
        identical: Bool = false,
        quitEarly: Bool = false,
        hitTimeout: Bool = false
    ) {
        self.changes = changes
        self.moves = moves
        self.identical = identical
        self.quitEarly = quitEarly
        self.hitTimeout = hitTimeout
    }
}
