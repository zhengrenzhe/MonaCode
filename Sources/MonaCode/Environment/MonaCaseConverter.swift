// MonaCaseConverter.swift
//
// P02-T007 — Implement fixed case conversion, collation, and normalization profiles.
//
// The real Unicode case converter for MonaCode. This replaces the ASCII-only
// `MonaCaseConverterStub` (P02-T003) with a converter backed by the generated
// `MonaCaseTables` (curated Unicode 16.0 / Chromium-ICU 78.2 case data). It
// conforms to the `MonaCaseConverter` protocol from P02-T003, so it can be
// injected anywhere the stub was accepted — `MonaLiteralSearch` and the
// `MonaRegExpExecutor` case-insensitive path use it unchanged.
//
// Frozen profile (M1-R model, raw UTF-16):
//
//   - `fold(_:)`        — the Unicode case fold used for case-insensitive
//                         comparison. Two code units that fold to the same
//                         value compare equal under `/i` (e.g. Σ and ς both
//                         fold to σ).
//   - `toLower(_:)`     — simple lowercase mapping (uppercase -> lowercase).
//   - `toUpper(_:)`     — simple uppercase mapping (lowercase -> uppercase).
//   - `foldCase(_:)`    — the `MonaCaseConverter` protocol method; mirrors
//                         `fold(_:)` for the curated subset so the converter
//                         is a drop-in replacement for the stub.
//
// Curated subset: ASCII, Latin-1 Supplement, Latin Extended-A (0x0100-0x012F),
// Greek, Cyrillic, plus Turkish İ/ı, long-s ſ, and final-sigma ς specials.
// Sufficient for ECMAScript RegExp case-insensitive matching in Phase 02.
//
// NOTE on naming: the P02-T003 protocol is named `MonaCaseConverter`. A class
// cannot share that name in the same module, so the concrete converter is
// `MonaUnicodeCaseConverter`. This does not change any existing call site
// (the protocol type is what callers reference); it only names the real impl.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The real Unicode case converter, backed by the generated `MonaCaseTables`.
///
/// Conforms to the `MonaCaseConverter` protocol (P02-T003) and provides the
/// three Phase-02 case operations — `fold`, `toLower`, `toUpper` — over raw
/// `UInt16` code units. The tables are a curated, pinned subset of Unicode
/// 16.0 sufficient for ECMAScript RegExp case-insensitive matching.
public final class MonaUnicodeCaseConverter: MonaCaseConverter {

    /// Creates the converter. Stateless beyond the shared generated tables.
    public init() {}

    /// Returns the simple lowercase mapping of `codeUnit`, or `codeUnit`
    /// itself when no mapping is recorded in the curated subset.
    public func toLower(_ codeUnit: UInt16) -> UInt16 {
        MonaCaseTables.upperToLower[codeUnit] ?? codeUnit
    }

    /// Returns the simple uppercase mapping of `codeUnit`, or `codeUnit`
    /// itself when no mapping is recorded in the curated subset.
    public func toUpper(_ codeUnit: UInt16) -> UInt16 {
        MonaCaseTables.lowerToUpper[codeUnit] ?? codeUnit
    }

    /// Returns the Unicode case fold of `codeUnit`.
    ///
    /// The fold is the simple lowercase mapping, then any fold exception is
    /// applied. This makes distinct code units that should compare equal
    /// under case-insensitive matching fold to a common form — most notably
    /// Σ (0x03A3) and ς (0x03C2) both fold to σ (0x03C3), and ſ (0x017F)
    /// folds to s (0x0073).
    public func fold(_ codeUnit: UInt16) -> UInt16 {
        let lowered = toLower(codeUnit)
        return MonaCaseTables.foldExceptions[lowered] ?? lowered
    }

    /// The `MonaCaseConverter` protocol entry point. Mirrors `fold(_:)` for
    /// the curated subset, so this converter is a drop-in replacement for the
    /// ASCII-only `MonaCaseConverterStub` in `MonaLiteralSearch` and the
    /// `MonaRegExpExecutor`.
    public func foldCase(_ codeUnit: UInt16) -> UInt16 {
        fold(codeUnit)
    }
}
