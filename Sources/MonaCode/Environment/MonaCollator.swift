// MonaCollator.swift
//
// P02-T007 — Implement fixed case conversion, collation, and normalization profiles.
//
// Locale-sensitive collation over raw `[UInt16]` code units, backed by the
// generated `MonaCollationTables` (curated Unicode 16.0 / Chromium-ICU 78.2
// collation weights). This is the Phase-02 collation profile enumerated by
// E1-R: primary weight distinguishes base letters, secondary distinguishes
// accent variants, and case is a tertiary level MonaCode does not surface in
// Phase 02 (so 'a' and 'A' compare equal).
//
// Locale sensitivity: a locale override REPLACES the root weight for specific
// code units. The curated subset ships a root table and a Swedish ("sv")
// override where å, ä, ö are reassigned primary weights that sort after z —
// so the same two strings can compare differently under different locales.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A typed error raised when a collation locale is not supported by the
/// curated `MonaCollationTables`.
public enum MonaCollationError: Error, Equatable, Sendable {
    /// The supplied locale identifier is not in the supported-locale table.
    case unsupportedLocale(String)
}

/// A locale-sensitive collator over raw `[UInt16]` code units.
///
/// Construct with a locale (defaulting to "root") and call `compare(_:_:)` to
/// order two UTF-16 code-unit sequences. The collation uses the generated
/// `MonaCollationTables` root weights plus any locale-specific overrides.
public final class MonaCollator {

    /// The locale identifier this collator is bound to (e.g. "root", "sv").
    public let locale: String

    /// Creates a collator bound to the root (default) collation table.
    public init() {
        self.locale = "root"
    }

    /// Creates a collator bound to `locale`.
    ///
    /// - Parameter locale: a supported locale identifier. Unsupported
    ///   identifiers are rejected with `MonaCollationError.unsupportedLocale`.
    public init(locale: String) throws {
        guard MonaCollationTables.supportedLocales.contains(locale) else {
            throw MonaCollationError.unsupportedLocale(locale)
        }
        self.locale = locale
    }

    /// Compares two UTF-16 code-unit sequences lexicographically by their
    /// collation sort keys (primary, then secondary).
    ///
    /// - Returns: `-1` if `a` sorts before `b`, `1` if after, `0` if equal
    ///   at the primary and secondary levels.
    public func compare(_ a: [UInt16], _ b: [UInt16]) -> Int {
        let ka = sortKey(a)
        let kb = sortKey(b)
        let n = min(ka.count, kb.count)
        for i in 0..<n {
            if ka[i].primary != kb[i].primary {
                return ka[i].primary < kb[i].primary ? -1 : 1
            }
            if ka[i].secondary != kb[i].secondary {
                return ka[i].secondary < kb[i].secondary ? -1 : 1
            }
        }
        if ka.count != kb.count {
            return ka.count < kb.count ? -1 : 1
        }
        return 0
    }

    // MARK: - Internals

    /// Returns the collation weight for `codeUnit` under this collator's
    /// locale: a locale override if present, else the root weight, else a
    /// fallback whose primary is the code unit itself (so unsupported code
    /// units remain collatable, sorting after the curated Latin letters).
    private func weight(for codeUnit: UInt16) -> MonaCollationWeight {
        if let override = MonaCollationTables.localeOverrides[locale]?[codeUnit] {
            return override
        }
        return MonaCollationTables.rootWeights[codeUnit]
            ?? MonaCollationWeight(primary: codeUnit, secondary: 0)
    }

    private func sortKey(_ codeUnits: [UInt16]) -> [MonaCollationWeight] {
        codeUnits.map { weight(for: $0) }
    }
}
