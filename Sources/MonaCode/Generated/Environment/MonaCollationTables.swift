// MonaCollationTables.swift
//
// P02-T007 — Implement fixed case conversion, collation, and normalization profiles.
//
// GENERATED FILE — do not edit by hand. Regenerate with:
//
//   /opt/homebrew/Cellar/node/26.7.0/bin/node \
//       Tools/Generators/generate-environment-tables.mjs
//
// Curated locale-sensitive collation tables for the MonaCode Phase-02
// collator (root + Swedish overrides). Primary weight distinguishes base
// letters; secondary distinguishes accent variants; case is tertiary and
// not surfaced in Phase 02.
//
// Provenance:
//   sourceVersion   = Unicode-16.0.0/ICU-78.2
//   generatorHash   = 8ae1eef67ad61ce0b322d4e0502ad53aa555567e6f443dc75cf62624ec909be7
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A primary/secondary collation weight pair for a single code unit.
public struct MonaCollationWeight: Equatable, Hashable, Sendable {
    /// The primary weight (distinguishes base letters).
    public let primary: UInt16
    /// The secondary weight (distinguishes accent variants).
    public let secondary: UInt16
    public init(primary: UInt16, secondary: UInt16) {
        self.primary = primary
        self.secondary = secondary
    }
}

/// The generated locale-sensitive collation tables for the Phase-02
/// collator.
///
/// `rootWeights` maps a curated subset of code units (ASCII letters +
/// common accented Latin-1 letters) to primary/secondary weights.
/// `localeOverrides` replaces specific weights per locale (e.g. Swedish
/// reassigns å/ä/ö to sort after z). Code units not present in the
/// table fall back to their own code-point value as primary (so they
/// remain collatable, sorting after the curated Latin letters).
public enum MonaCollationTables {

    public static let sourceVersion = "Unicode-16.0.0/ICU-78.2"
    public static let inputHash = "cb49754ec97fbac7d2fcb26669395c87c98de94b0ebfdc244beb20aef4a37270"
    public static let generatorHash = "8ae1eef67ad61ce0b322d4e0502ad53aa555567e6f443dc75cf62624ec909be7"
    public static let outputHash = "cb49754ec97fbac7d2fcb26669395c87c98de94b0ebfdc244beb20aef4a37270"
    public static let propertySet = "collation;primary;secondary;root;sv"
    public static let consumerSet = "MonaCollator"

    /// The locale identifiers supported by the override table.
    public static let supportedLocales: [String] = ["root","sv"]

    /// Root (default) collation weights for the curated subset.
    public static let rootWeights: [UInt16: MonaCollationWeight] = [
        0x0041: MonaCollationWeight(primary: 1, secondary: 0),
        0x0042: MonaCollationWeight(primary: 2, secondary: 0),
        0x0043: MonaCollationWeight(primary: 3, secondary: 0),
        0x0044: MonaCollationWeight(primary: 4, secondary: 0),
        0x0045: MonaCollationWeight(primary: 5, secondary: 0),
        0x0046: MonaCollationWeight(primary: 6, secondary: 0),
        0x0047: MonaCollationWeight(primary: 7, secondary: 0),
        0x0048: MonaCollationWeight(primary: 8, secondary: 0),
        0x0049: MonaCollationWeight(primary: 9, secondary: 0),
        0x004A: MonaCollationWeight(primary: 10, secondary: 0),
        0x004B: MonaCollationWeight(primary: 11, secondary: 0),
        0x004C: MonaCollationWeight(primary: 12, secondary: 0),
        0x004D: MonaCollationWeight(primary: 13, secondary: 0),
        0x004E: MonaCollationWeight(primary: 14, secondary: 0),
        0x004F: MonaCollationWeight(primary: 15, secondary: 0),
        0x0050: MonaCollationWeight(primary: 16, secondary: 0),
        0x0051: MonaCollationWeight(primary: 17, secondary: 0),
        0x0052: MonaCollationWeight(primary: 18, secondary: 0),
        0x0053: MonaCollationWeight(primary: 19, secondary: 0),
        0x0054: MonaCollationWeight(primary: 20, secondary: 0),
        0x0055: MonaCollationWeight(primary: 21, secondary: 0),
        0x0056: MonaCollationWeight(primary: 22, secondary: 0),
        0x0057: MonaCollationWeight(primary: 23, secondary: 0),
        0x0058: MonaCollationWeight(primary: 24, secondary: 0),
        0x0059: MonaCollationWeight(primary: 25, secondary: 0),
        0x005A: MonaCollationWeight(primary: 26, secondary: 0),
        0x0061: MonaCollationWeight(primary: 1, secondary: 0),
        0x0062: MonaCollationWeight(primary: 2, secondary: 0),
        0x0063: MonaCollationWeight(primary: 3, secondary: 0),
        0x0064: MonaCollationWeight(primary: 4, secondary: 0),
        0x0065: MonaCollationWeight(primary: 5, secondary: 0),
        0x0066: MonaCollationWeight(primary: 6, secondary: 0),
        0x0067: MonaCollationWeight(primary: 7, secondary: 0),
        0x0068: MonaCollationWeight(primary: 8, secondary: 0),
        0x0069: MonaCollationWeight(primary: 9, secondary: 0),
        0x006A: MonaCollationWeight(primary: 10, secondary: 0),
        0x006B: MonaCollationWeight(primary: 11, secondary: 0),
        0x006C: MonaCollationWeight(primary: 12, secondary: 0),
        0x006D: MonaCollationWeight(primary: 13, secondary: 0),
        0x006E: MonaCollationWeight(primary: 14, secondary: 0),
        0x006F: MonaCollationWeight(primary: 15, secondary: 0),
        0x0070: MonaCollationWeight(primary: 16, secondary: 0),
        0x0071: MonaCollationWeight(primary: 17, secondary: 0),
        0x0072: MonaCollationWeight(primary: 18, secondary: 0),
        0x0073: MonaCollationWeight(primary: 19, secondary: 0),
        0x0074: MonaCollationWeight(primary: 20, secondary: 0),
        0x0075: MonaCollationWeight(primary: 21, secondary: 0),
        0x0076: MonaCollationWeight(primary: 22, secondary: 0),
        0x0077: MonaCollationWeight(primary: 23, secondary: 0),
        0x0078: MonaCollationWeight(primary: 24, secondary: 0),
        0x0079: MonaCollationWeight(primary: 25, secondary: 0),
        0x007A: MonaCollationWeight(primary: 26, secondary: 0),
        0x00DF: MonaCollationWeight(primary: 19, secondary: 0),
        0x00E0: MonaCollationWeight(primary: 1, secondary: 1),
        0x00E1: MonaCollationWeight(primary: 1, secondary: 2),
        0x00E2: MonaCollationWeight(primary: 1, secondary: 3),
        0x00E4: MonaCollationWeight(primary: 1, secondary: 4),
        0x00E5: MonaCollationWeight(primary: 1, secondary: 5),
        0x00E8: MonaCollationWeight(primary: 5, secondary: 1),
        0x00E9: MonaCollationWeight(primary: 5, secondary: 2),
        0x00EA: MonaCollationWeight(primary: 5, secondary: 3),
        0x00EB: MonaCollationWeight(primary: 5, secondary: 4),
        0x00F6: MonaCollationWeight(primary: 15, secondary: 1),
        0x00FC: MonaCollationWeight(primary: 21, secondary: 1),
    ]

    /// Locale-specific weight overrides. A code unit present in the
    /// override map REPLACES its root weight for that locale.
    public static let localeOverrides: [String: [UInt16: MonaCollationWeight]] = [
        "sv": [
            0x00E4: MonaCollationWeight(primary: 28, secondary: 0),
            0x00E5: MonaCollationWeight(primary: 29, secondary: 0),
            0x00F6: MonaCollationWeight(primary: 30, secondary: 0),
        ],
    ]
}
