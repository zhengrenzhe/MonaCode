// MonaRegExpConsumerProfile.swift
//
// P02-T006 — Close ten RegExp consumer profiles with pinned Test262 vectors.
//
// A *consumer profile* binds a frozen RegExp occurrence (a fixed pattern +
// flags string) to a named downstream MonaCode consumer use case, and records
// which of the six P02-T005 Unicode profiles that consumer depends on. Each
// profile is the smallest closed unit of "which RegExp, for what purpose,
// over which Unicode data" — the answer to "who consumes this RegExp
// occurrence, and what tables must be present for it to be correct".
//
// Ten consumer profiles are generated, one per consumer type in
// `MonaRegExpConsumerType`:
//
//   1. find-literal              — find widget, literal occurrence.
//   2. navigation-next-match     — next/previous match navigation, global regex.
//   3. replace-capture            — replace model, capture-substitution occurrence.
//   4. word-boundary             — word-at-cursor, `\b`-anchored occurrence.
//   5. transform-case            — select-next-occurrence case transform.
//   6. filter-prefix             — list/filter view, line-anchored occurrence.
//   7. configuration-wordpattern — language configuration `wordPattern`.
//   8. validation-email         — input validation occurrence.
//   9. tokenization-number       — tokenizer number rule.
//   10. highlight-bracket       — bracket-pair highlight occurrence.
//
// Each profile carries:
//
//   - profileID              : the profile's unique identifier.
//   - pattern                : the frozen RegExp pattern string.
//   - flags                  : the frozen flag string.
//   - consumerType           : the consumer use case (one of ten).
//   - boundUnicodeProfileIDs : the P02-T005 profile IDs this consumer needs.
//
// The frozen occurrence is compiled through the P02-T004 parser/compiler via
// `compile()`, yielding a `MonaRegExpProgram` run by `MonaRegExpExecutor`.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// One of the ten enumerated RegExp consumer use cases in MonaCode.
///
/// Each case names a distinct downstream consumer of a frozen RegExp
/// occurrence. The ten cases are the closed set of RegExp consumers that
/// P02-T006 binds to pinned Test262 vectors.
public enum MonaRegExpConsumerType: String, Equatable, Hashable, Sendable, CaseIterable {

    /// The find widget — literal or regex search across the buffer.
    case find

    /// The replace model — capture-substitution replacement.
    case replace

    /// Word-at-cursor selection — `\b`-anchored word matching.
    case word

    /// Select-next-occurrence / case-aware transform.
    case transform

    /// List/filter views — line-anchored prefix or token filtering.
    case filter

    /// Language configuration — `wordPattern`, `onEnterRules`, etc.
    case configuration

    /// Input validation occurrences (e.g. email, identifier rules).
    case validation

    /// Grammar tokenizer rules (e.g. numeric tokens).
    case tokenization

    /// Bracket-pair / match highlighter.
    case highlight

    /// Next/previous match navigation.
    case navigation
}

/// A consumer profile: a frozen RegExp occurrence bound to a consumer use case
/// and to its required P02-T005 Unicode profiles.
public struct MonaRegExpConsumerProfile: Equatable, Hashable, Sendable {

    /// The profile's unique identifier (e.g. `"find-literal"`).
    public let profileID: String

    /// The frozen RegExp pattern string.
    public let pattern: String

    /// The frozen flag string (e.g. `"g"`, `"m"`, `""`).
    public let flags: String

    /// The consumer use case this occurrence is bound to.
    public let consumerType: MonaRegExpConsumerType

    /// The P02-T005 Unicode profile IDs this consumer depends on. Each entry
    /// must be one of the six profile IDs exposed by
    /// `MonaRegExpUnicodeTables.allProfiles`.
    public let boundUnicodeProfileIDs: [String]

    /// Creates a consumer profile.
    public init(
        profileID: String,
        pattern: String,
        flags: String,
        consumerType: MonaRegExpConsumerType,
        boundUnicodeProfileIDs: [String]
    ) {
        self.profileID = profileID
        self.pattern = pattern
        self.flags = flags
        self.consumerType = consumerType
        self.boundUnicodeProfileIDs = boundUnicodeProfileIDs
    }

    /// Compiles the frozen RegExp occurrence into a `MonaRegExpProgram`
    /// through the P02-T004 parser and compiler.
    public func compile() throws -> MonaRegExpProgram {
        return try monaRegExpCompile(pattern, flags: flags)
    }
}

/// The ten named RegExp consumer profiles, each binding a frozen RegExp
/// occurrence to a consumer use case and its bound P02-T005 Unicode profiles.
public enum MonaRegExpConsumerProfiles {

    /// 1. find-literal — find widget, a literal occurrence.
    public static let findLiteral: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "find-literal",
        pattern: "hello",
        flags: "",
        consumerType: .find,
        boundUnicodeProfileIDs: ["white-space"]
    )

    /// 2. navigation-next-match — next/previous match navigation, a global
    ///    word-boundary occurrence used to step through matches.
    public static let navigationNextMatch: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "navigation-next-match",
        pattern: "\\bcat\\b",
        flags: "g",
        consumerType: .navigation,
        boundUnicodeProfileIDs: ["white-space", "identifier-profiles"]
    )

    /// 3. replace-capture — replace model, a capture-substitution occurrence.
    public static let replaceCapture: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "replace-capture",
        pattern: "(\\w+)@(\\w+)",
        flags: "",
        consumerType: .replace,
        boundUnicodeProfileIDs: ["identifier-profiles"]
    )

    /// 4. word-boundary — word-at-cursor, a `\b`-anchored occurrence.
    public static let wordBoundary: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "word-boundary",
        pattern: "\\bword\\b",
        flags: "",
        consumerType: .word,
        boundUnicodeProfileIDs: ["white-space", "identifier-profiles"]
    )

    /// 5. transform-case — select-next-occurrence case transform.
    public static let transformCase: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "transform-case",
        pattern: "[A-Z][a-z]+",
        flags: "g",
        consumerType: .transform,
        boundUnicodeProfileIDs: ["general-category", "case-folding"]
    )

    /// 6. filter-prefix — list/filter view, a multiline line-anchored occurrence.
    public static let filterPrefix: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "filter-prefix",
        pattern: "^prefix",
        flags: "m",
        consumerType: .filter,
        boundUnicodeProfileIDs: ["white-space"]
    )

    /// 7. configuration-wordpattern — language configuration `wordPattern`.
    public static let configurationWordPattern: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "configuration-wordpattern",
        pattern: "[a-zA-Z_][a-zA-Z0-9_]*",
        flags: "",
        consumerType: .configuration,
        boundUnicodeProfileIDs: ["identifier-profiles"]
    )

    /// 8. validation-email — input validation occurrence.
    public static let validationEmail: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "validation-email",
        pattern: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$",
        flags: "",
        consumerType: .validation,
        boundUnicodeProfileIDs: ["white-space", "binary-properties"]
    )

    /// 9. tokenization-number — tokenizer numeric-token rule.
    public static let tokenizationNumber: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "tokenization-number",
        pattern: "\\d+(\\.\\d+)?",
        flags: "g",
        consumerType: .tokenization,
        boundUnicodeProfileIDs: ["general-category"]
    )

    /// 10. highlight-bracket — bracket-pair highlighter.
    public static let highlightBracket: MonaRegExpConsumerProfile = MonaRegExpConsumerProfile(
        profileID: "highlight-bracket",
        pattern: "[(){}\\[\\]]",
        flags: "g",
        consumerType: .highlight,
        boundUnicodeProfileIDs: ["general-category"]
    )

    /// All ten consumer profiles, in canonical order.
    public static let allProfiles: [MonaRegExpConsumerProfile] = [
        MonaRegExpConsumerProfiles.findLiteral,
        MonaRegExpConsumerProfiles.navigationNextMatch,
        MonaRegExpConsumerProfiles.replaceCapture,
        MonaRegExpConsumerProfiles.wordBoundary,
        MonaRegExpConsumerProfiles.transformCase,
        MonaRegExpConsumerProfiles.filterPrefix,
        MonaRegExpConsumerProfiles.configurationWordPattern,
        MonaRegExpConsumerProfiles.validationEmail,
        MonaRegExpConsumerProfiles.tokenizationNumber,
        MonaRegExpConsumerProfiles.highlightBracket,
    ]

    /// Resolves a profile by its identifier, or `nil` if no profile carries
    /// the given ID.
    public static func profile(id: String) -> MonaRegExpConsumerProfile? {
        return allProfiles.first { $0.profileID == id }
    }
}
