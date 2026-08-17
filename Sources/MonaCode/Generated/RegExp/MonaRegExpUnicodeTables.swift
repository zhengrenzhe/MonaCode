// MonaRegExpUnicodeTables.swift
//
// P02-T005 — Generate six non-mergeable RegExp Unicode profiles.
//
// GENERATED FILE — do not edit by hand. Regenerate with:
//
//   /opt/homebrew/Cellar/node/26.7.0/bin/node \
//       Tools/Generators/generate-regexp-unicode.mjs
//
// This file is the repo-owned Swift port of the Unicode tables consumed by
// the MonaCode ECMAScript RegExp engine. It is a curated, pinned subset of
// Unicode 16.0 (pinned behavioral oracle: Chromium-ICU 78.2) sufficient for
// ECMAScript RegExp matching. The full Unicode database acquisition is owned
// by P00-T003; this generator derives the RegExp-relevant tables from a
// licensed excerpt (see UNICODE-LICENSE.txt alongside this file).
//
// Six SEPARATELY IDENTIFIED profiles are generated:
//
//   1. general-category      — General_Category (Lu, Ll, Nd, ...).
//   2. script                — Script (Latin, Greek, Cyrillic, ...).
//   3. binary-properties     — Binary properties (Alphabetic, Hex_Digit,
//                              White_Space, ID_Start, ...).
//   4. case-folding          — Domain of code points with a case fold.
//   5. white-space           — The White_Space property (dedicated).
//   6. identifier-profiles   — ID_Start / ID_Continue.
//
// Each profile records six provenance fields:
//
//   - sourceVersion : Unicode/ICU revision the curated data is drawn from.
//   - inputHash     : SHA-256 of the canonical input-definition serialization.
//   - generatorHash : SHA-256 of the generator source (shared by all six).
//   - outputHash    : SHA-256 of the canonical merged-range serialization.
//   - propertySet   : property names carried by this profile.
//   - consumerSet   : downstream MonaCode consumers bound to this profile.
//
// NON-MERGEABILITY (structural invariant): each profile carries an
// independent profileID + provenance tuple + consumer set. Two profiles are
// NEVER merged, even when their flattened range tables compare equal. The
// `MonaRegExpUnicodeProfile.canMerge(with:)` accessor is unconditionally
// `false`.
//
// Provenance summary:
//   sourceVersion   = Unicode-16.0.0/ICU-78.2
//   generatorHash   = 8595b6c61ad41d3354c3a3d1d95d11bae1d3360c68dfd74e064df51faecfb2ca
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A separately identified Unicode table profile with full provenance.
///
/// A profile is the smallest non-mergeable unit of Unicode data consumed by
/// the MonaCode RegExp engine. Each profile carries:
///
///   - a unique `profileID` that names the profile's identity;
///   - six provenance fields (`sourceVersion`, `inputHash`,
///     `generatorHash`, `outputHash`, `propertySet`, `consumerSet`);
///   - the flattened, merged, non-overlapping `ranges` it emits.
///
/// Identity is the FULL provenance tuple (profileID + the six fields),
/// NOT the range bytes. Two profiles whose `ranges` compare equal remain
/// distinct identities. `canMerge(with:)` is therefore unconditionally
/// `false`: merging is forbidden because each profile carries independent
/// provenance and a distinct consumer set that must be preserved separately.
public struct MonaRegExpUnicodeProfile: Equatable, Hashable, Sendable {

    /// The profile's unique identifier (e.g. `"general-category"`).
    public let profileID: String

    /// The Unicode / ICU revision the curated data is drawn from.
    public let sourceVersion: String

    /// SHA-256 (64-char lowercase hex) of the canonical input-definition
    /// serialization for this profile.
    public let inputHash: String

    /// SHA-256 (64-char lowercase hex) of the generator source bytes. Shared
    /// by all six profiles — one generator produced them all.
    public let generatorHash: String

    /// SHA-256 (64-char lowercase hex) of the canonical merged-range
    /// serialization for this profile.
    public let outputHash: String

    /// The property names carried by this profile (e.g. `["Lu", "Ll"]`).
    public let propertySet: [String]

    /// The downstream MonaCode consumers bound to this profile.
    public let consumerSet: [String]

    /// The flattened, merged, non-overlapping code-point ranges.
    public let ranges: [CodeRange]

    /// A single inclusive code-point range [start, end].
    public struct CodeRange: Equatable, Hashable, Sendable {

        /// Inclusive start code point.
        public let start: UInt32

        /// Inclusive end code point (>= `start`).
        public let end: UInt32

        public init(start: UInt32, end: UInt32) {
            self.start = start
            self.end = end
        }
    }

    public init(
        profileID: String,
        sourceVersion: String,
        inputHash: String,
        generatorHash: String,
        outputHash: String,
        propertySet: [String],
        consumerSet: [String],
        ranges: [CodeRange]
    ) {
        self.profileID = profileID
        self.sourceVersion = sourceVersion
        self.inputHash = inputHash
        self.generatorHash = generatorHash
        self.outputHash = outputHash
        self.propertySet = propertySet
        self.consumerSet = consumerSet
        self.ranges = ranges
    }

    /// Profiles are NEVER mergeable.
    ///
    /// Merging is forbidden because each profile carries independent
    /// provenance (source version, input hash, generator hash, output hash,
    /// property set) and a distinct consumer set that must be preserved
    /// separately. This returns `false` unconditionally — even when called
    /// with a profile whose `ranges` compare equal to this profile's, and
    /// even when called with `self`.
    public func canMerge(with other: MonaRegExpUnicodeProfile) -> Bool {
        _ = other
        return false
    }
}

/// The six generated Unicode table profiles consumed by the MonaCode
/// ECMAScript RegExp engine.
public enum MonaRegExpUnicodeTables {

    /// generalCategory — profile `general-category`.
    public static let generalCategory: MonaRegExpUnicodeProfile = MonaRegExpUnicodeProfile(
        profileID: "general-category",
        sourceVersion: "Unicode-16.0.0/ICU-78.2",
        inputHash: "ddc886fd94913b204509ecd46f8f41aa2fb9ba1783bc8677675482a2494e34cf",
        generatorHash: "8595b6c61ad41d3354c3a3d1d95d11bae1d3360c68dfd74e064df51faecfb2ca",
        outputHash: "40b9fcea50606d4fd0f755519f4549e554aba76a88f6613f52219ce071cc59d1",
        propertySet: ["Lu", "Ll", "Lt", "Lm", "Lo", "Mn", "Mc", "Me", "Nd", "Nl", "No", "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po", "Sm", "Sc", "Sk", "So", "Zs", "Zl", "Zp", "Cc", "Cf", "Cs", "Co", "Cn"],
        consumerSet: ["MonaRegExpParser", "MonaRegExpExecutor"],
        ranges: [
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0000, end: 0x0021),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0024, end: 0x0024),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0028, end: 0x0029),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x002B, end: 0x002B),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x002D, end: 0x002E),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0030, end: 0x0039),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x003B, end: 0x003F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0041, end: 0x005B),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x005D, end: 0x00A0),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00A2, end: 0x00A6),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00A8, end: 0x00A9),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00AB, end: 0x00B4),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00B8, end: 0x00B9),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00BB, end: 0x00BE),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00C0, end: 0x00FF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0192, end: 0x0192),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x01C5, end: 0x01C5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x01C8, end: 0x01C8),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x01CB, end: 0x01CB),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x01F2, end: 0x01F2),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x02B0, end: 0x02C1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x02C6, end: 0x02D1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x02E0, end: 0x02E4),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0300, end: 0x0373),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0376, end: 0x0383),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0386, end: 0x0386),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0388, end: 0x03A1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03A3, end: 0x03E1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03F0, end: 0x03F5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0482, end: 0x0489),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0588, end: 0x0588),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x058A, end: 0x058A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0591, end: 0x05BD),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05BF, end: 0x05BF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05C1, end: 0x05C2),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05C4, end: 0x05C5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05C7, end: 0x05C7),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0600, end: 0x0605),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0610, end: 0x061C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x061F, end: 0x061F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x064B, end: 0x066D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x06DD, end: 0x06DD),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x06F0, end: 0x06F9),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x070F, end: 0x070F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x07C0, end: 0x07C9),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0903, end: 0x0903),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x093B, end: 0x093B),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x093E, end: 0x0940),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0949, end: 0x094C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x094E, end: 0x094F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0982, end: 0x0983),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x09F4, end: 0x09F9),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0F3A, end: 0x0F3B),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1680, end: 0x1680),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1806, end: 0x1806),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x180E, end: 0x180E),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2000, end: 0x2015),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2018, end: 0x201A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x201C, end: 0x201E),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2028, end: 0x202F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2039, end: 0x203A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x203F, end: 0x2040),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2054, end: 0x2054),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x205F, end: 0x2064),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2066, end: 0x206F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x20A0, end: 0x20BF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2160, end: 0x2182),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2185, end: 0x2188),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2E02, end: 0x2E05),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2E09, end: 0x2E0A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2E0C, end: 0x2E0D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2E17, end: 0x2E17),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2E1C, end: 0x2E1D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3000, end: 0x3000),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3007, end: 0x3007),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3021, end: 0x3029),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xD800, end: 0xF8FF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFE33, end: 0xFE34),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFEFF, end: 0xFEFF),
        ]
    )

    /// script — profile `script`.
    public static let script: MonaRegExpUnicodeProfile = MonaRegExpUnicodeProfile(
        profileID: "script",
        sourceVersion: "Unicode-16.0.0/ICU-78.2",
        inputHash: "d7c297ef89ef0d2a42585bbaf1b49208ae284e8fd4bcff6f6105f6df7bab6ca9",
        generatorHash: "8595b6c61ad41d3354c3a3d1d95d11bae1d3360c68dfd74e064df51faecfb2ca",
        outputHash: "3d243bea9c130e253ea3da6d2fa87b253f526a63ee16ad1d0e6f798b7aa53dfd",
        propertySet: ["Latin", "Greek", "Cyrillic", "Hebrew", "Arabic", "Common", "Inherited"],
        consumerSet: ["MonaRegExpExecutor"],
        ranges: [
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0000, end: 0x0373),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0375, end: 0x0377),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x037A, end: 0x037D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x037F, end: 0x037F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0384, end: 0x0384),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0386, end: 0x0386),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0388, end: 0x038A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x038C, end: 0x038C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x038E, end: 0x03A1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03A3, end: 0x03E1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03F0, end: 0x03F5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03F7, end: 0x052F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0591, end: 0x05C4),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05C6, end: 0x05C7),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05D0, end: 0x05EA),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05EF, end: 0x05F4),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0600, end: 0x0603),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0606, end: 0x061A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x061C, end: 0x061C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x061E, end: 0x06DC),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x06DE, end: 0x06EF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x06FA, end: 0x06FF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1C80, end: 0x1C8F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1D00, end: 0x1D25),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1D2C, end: 0x1D5C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1D62, end: 0x1D65),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1D6B, end: 0x1D77),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1D79, end: 0x1DBE),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1E00, end: 0x1FFE),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x200C, end: 0x200D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2010, end: 0x2027),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2030, end: 0x205E),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2060, end: 0x2064),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2066, end: 0x2071),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2074, end: 0x208E),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2090, end: 0x209C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x20A0, end: 0x20BF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2100, end: 0x214F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2160, end: 0x2188),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2190, end: 0x23FF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2500, end: 0x2775),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2794, end: 0x2BFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2C60, end: 0x2C7F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2DE0, end: 0x2E7F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3000, end: 0x3004),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xA640, end: 0xA69F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xA722, end: 0xA787),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xA78B, end: 0xA7CA),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xA7F5, end: 0xA7FF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFB1D, end: 0xFB4F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFE00, end: 0xFE0F),
        ]
    )

    /// binaryProperties — profile `binary-properties`.
    public static let binaryProperties: MonaRegExpUnicodeProfile = MonaRegExpUnicodeProfile(
        profileID: "binary-properties",
        sourceVersion: "Unicode-16.0.0/ICU-78.2",
        inputHash: "3942af370f8ec3023bd0d5bee3cc82dac8822304058d3ac015bf93511ca596b0",
        generatorHash: "8595b6c61ad41d3354c3a3d1d95d11bae1d3360c68dfd74e064df51faecfb2ca",
        outputHash: "23cb61025e6fd99c96f3c42eba2e5b9d452db43100c1a1611346d05b93aa36b3",
        propertySet: ["Alphabetic", "Hex_Digit", "ASCII", "ID_Start", "ID_Continue", "XID_Start", "XID_Continue", "Math", "Dash", "Extender", "Join_Control", "Bidi_Control", "Default_Ignorable_Code_Point", "Deprecated", "Noncharacter_Code_Point", "White_Space"],
        consumerSet: ["MonaRegExpExecutor"],
        ranges: [
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0000, end: 0x007F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0085, end: 0x0085),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00A0, end: 0x00A0),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00AA, end: 0x00AA),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00AC, end: 0x00AD),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00B1, end: 0x00B1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00B5, end: 0x00B5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00B7, end: 0x00B7),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00BA, end: 0x00BA),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00C0, end: 0x02C1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x02C6, end: 0x02D1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x02E0, end: 0x02E4),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0300, end: 0x0374),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0376, end: 0x0377),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x037A, end: 0x037D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x037F, end: 0x037F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0386, end: 0x0386),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0388, end: 0x038A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x038C, end: 0x038C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x038E, end: 0x03A1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03A3, end: 0x03F5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03F7, end: 0x0481),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0531, end: 0x0556),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0559, end: 0x055F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0561, end: 0x0587),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x058A, end: 0x058A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05D0, end: 0x05EA),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05F0, end: 0x05F2),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x061C, end: 0x061C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0640, end: 0x0640),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0660, end: 0x0669),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x066E, end: 0x066F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0673, end: 0x0673),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0E46, end: 0x0E46),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0EC6, end: 0x0EC6),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0F77, end: 0x0F77),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0F79, end: 0x0F79),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x115F, end: 0x1160),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1680, end: 0x1680),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x17A3, end: 0x17A4),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x17B4, end: 0x17B5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1806, end: 0x1806),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x180B, end: 0x180F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1843, end: 0x1843),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2000, end: 0x2015),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2028, end: 0x202F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x205F, end: 0x206F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2200, end: 0x22FF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x27C0, end: 0x27EF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2980, end: 0x2AFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2E17, end: 0x2E17),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2E1A, end: 0x2E1A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2E3A, end: 0x2E3B),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3000, end: 0x3000),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3005, end: 0x3005),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x301C, end: 0x301C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3030, end: 0x3035),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x309D, end: 0x309E),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x30A0, end: 0x30A0),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x30FC, end: 0x30FE),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3164, end: 0x3164),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xA015, end: 0xA015),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xA60C, end: 0xA60C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xA9CF, end: 0xA9CF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xAA70, end: 0xAA70),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFDD0, end: 0xFDEF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFE00, end: 0xFE0F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFE31, end: 0xFE32),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFE58, end: 0xFE58),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFE63, end: 0xFE63),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFEFF, end: 0xFEFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFF0D, end: 0xFF0D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFF10, end: 0xFF19),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFF21, end: 0xFF26),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFF41, end: 0xFF46),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFFA0, end: 0xFFA0),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFFF0, end: 0xFFF8),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFFFE, end: 0xFFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1BCA0, end: 0x1BCA3),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1D173, end: 0x1D17A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1FFFE, end: 0x1FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2FFFE, end: 0x2FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3FFFE, end: 0x3FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x4FFFE, end: 0x4FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x5FFFE, end: 0x5FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x6FFFE, end: 0x6FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x7FFFE, end: 0x7FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x8FFFE, end: 0x8FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x9FFFE, end: 0x9FFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xAFFFE, end: 0xAFFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xBFFFE, end: 0xBFFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xCFFFE, end: 0xCFFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xDFFFE, end: 0xDFFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xEFFFE, end: 0xEFFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFFFFE, end: 0xFFFFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x10FFFE, end: 0x10FFFF),
        ]
    )

    /// caseFolding — profile `case-folding`.
    public static let caseFolding: MonaRegExpUnicodeProfile = MonaRegExpUnicodeProfile(
        profileID: "case-folding",
        sourceVersion: "Unicode-16.0.0/ICU-78.2",
        inputHash: "cade7375e85059d115553f6fdc364f088e76fabd5e6a8be22547587bceef07b4",
        generatorHash: "8595b6c61ad41d3354c3a3d1d95d11bae1d3360c68dfd74e064df51faecfb2ca",
        outputHash: "f2a728c787f2bede4764cd53c731dec82a7f84654caf489f3dc1178c2ea5b149",
        propertySet: ["Simple_Case_Folding", "Full_Case_Folding", "Turkic_Case_Folding"],
        consumerSet: ["MonaRegExpExecutor", "MonaCaseConverter"],
        ranges: [
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0041, end: 0x005A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0061, end: 0x007A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00B5, end: 0x00B5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00C0, end: 0x00D6),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00D8, end: 0x00F6),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00F8, end: 0x02AF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0370, end: 0x0373),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0375, end: 0x0377),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x037A, end: 0x037D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0386, end: 0x0386),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0388, end: 0x038A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x038C, end: 0x038C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x038E, end: 0x03A1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03A3, end: 0x03E1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03F0, end: 0x03F5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03F7, end: 0x0481),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x048A, end: 0x052F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0531, end: 0x0556),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0561, end: 0x0587),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x10A0, end: 0x10C5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1E00, end: 0x1FFF),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFB00, end: 0xFB06),
            MonaRegExpUnicodeProfile.CodeRange(start: 0xFB13, end: 0xFB17),
        ]
    )

    /// whiteSpace — profile `white-space`.
    public static let whiteSpace: MonaRegExpUnicodeProfile = MonaRegExpUnicodeProfile(
        profileID: "white-space",
        sourceVersion: "Unicode-16.0.0/ICU-78.2",
        inputHash: "5c4a67dfefa7d477e83ace004e2fe4082c3b75d66e58620b42e63f81f9449c0f",
        generatorHash: "8595b6c61ad41d3354c3a3d1d95d11bae1d3360c68dfd74e064df51faecfb2ca",
        outputHash: "ac9a5bb8d1d05a95900deaceed5aece631114eac20c0dc72b4ad25b751df81bd",
        propertySet: ["White_Space"],
        consumerSet: ["MonaRegExpExecutor", "MonaWordClassifier"],
        ranges: [
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0009, end: 0x000D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0020, end: 0x0020),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0085, end: 0x0085),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00A0, end: 0x00A0),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x1680, end: 0x1680),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2000, end: 0x200A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x2028, end: 0x2029),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x202F, end: 0x202F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x205F, end: 0x205F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x3000, end: 0x3000),
        ]
    )

    /// identifierProfiles — profile `identifier-profiles`.
    public static let identifierProfiles: MonaRegExpUnicodeProfile = MonaRegExpUnicodeProfile(
        profileID: "identifier-profiles",
        sourceVersion: "Unicode-16.0.0/ICU-78.2",
        inputHash: "54020a5867cbed8eaf2f0e16898c4e3f86d823b80a3516c4540dcec3e4f60c9e",
        generatorHash: "8595b6c61ad41d3354c3a3d1d95d11bae1d3360c68dfd74e064df51faecfb2ca",
        outputHash: "dad0d22fa89015289611eba833c7c7a743be8d3dbe588d24fc04055c9d6ad4df",
        propertySet: ["ID_Start", "ID_Continue"],
        consumerSet: ["MonaRegExpParser", "MonaRegExpExecutor"],
        ranges: [
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0030, end: 0x0039),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0041, end: 0x005A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x005F, end: 0x005F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0061, end: 0x007A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00AA, end: 0x00AA),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00B5, end: 0x00B5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00B7, end: 0x00B7),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00BA, end: 0x00BA),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00C0, end: 0x00D6),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00D8, end: 0x00F6),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x00F8, end: 0x02C1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x02C6, end: 0x02D1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x02E0, end: 0x02E4),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0300, end: 0x0374),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0376, end: 0x0377),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x037A, end: 0x037D),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x037F, end: 0x037F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0386, end: 0x0386),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0388, end: 0x038A),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x038C, end: 0x038C),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x038E, end: 0x03A1),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03A3, end: 0x03F5),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x03F7, end: 0x0481),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0531, end: 0x0556),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0559, end: 0x055F),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0561, end: 0x0587),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05D0, end: 0x05EA),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x05F0, end: 0x05F2),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x0660, end: 0x0669),
            MonaRegExpUnicodeProfile.CodeRange(start: 0x066E, end: 0x066F),
        ]
    )

    /// All six profiles, in canonical order.
    public static let allProfiles: [MonaRegExpUnicodeProfile] = [
            MonaRegExpUnicodeTables.generalCategory,
            MonaRegExpUnicodeTables.script,
            MonaRegExpUnicodeTables.binaryProperties,
            MonaRegExpUnicodeTables.caseFolding,
            MonaRegExpUnicodeTables.whiteSpace,
            MonaRegExpUnicodeTables.identifierProfiles
    ]
}
