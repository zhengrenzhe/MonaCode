// MonaLocalization.swift
//
// P05-T007 — Generate 15 immutable UI localization profiles with 2120 messages.
//
// Defines the N1 UI localization surface: the runtime resolution, format, and
// localization entry points that resolve message text through the explicit N1
// localization profile mechanism (`MonaCodeEnvironmentProfile` from P00-T007).
//
// This is the SAME mechanism P04-T012's announcement bridge already uses
// (`MonaAXAnnouncementBridge` takes a `MonaCodeEnvironmentProfile` directly so
// it cannot accidentally consult the runtime locale). MonaLocalization reuses
// that exact profile type — it does NOT invent a parallel localization path.
// There is no `Bundle.main.localizedString`, no Foundation locale lookup, no
// network: lookup is over the immutable repository-owned generated tables
// (MonaLocalizationProfiles.swift).
//
// Resolution follows the N1-R localization manifest observable semantics
// (monacode-n1r-localization-manifest.json):
//   - identity : the 2120-entry ordered nls.keys module/key identity.
//   - lookup   : a profile string wins; null or absent entries fall back to
//                the English (en) source string; absence of both yields a
//                typed `MonaLocalizationError.missingMessage`.
//   - format   : Monaco's raw UTF-16 `/\{(\d+)\}/g` replacement using the
//                FIRST captured digit as the argument index (the `{10}` →
//                args[1] quirk). string/number/boolean/null/absent arguments
//                stringify exactly as Monaco; other values leave the
//                placeholder unchanged.
//   - localize2: the result carries the localized value plus the separately
//                formatted original English message.
//   - pseudo   : the English fallback is wrapped in fullwidth square brackets
//                (U+FF3B / U+FF3D) and every lowercase a, o, u, e, i is
//                doubled in source order.
//   - selection: the profile is fixed before first service; default is en;
//                 unsupported identifiers are rejected and never mapped through
//                 the system locale.
//   - storage  : tables are immutable repository-owned Swift resources; lookup
//                never calls Foundation localization or a network service.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A typed missing-message failure raised when a message index has neither a
/// profile-specific entry nor an English (en) fallback entry. Mirrors Monaco's
/// `!!! NLS MISSING: {index} !!!` as a typed Swift error.
public enum MonaLocalizationError: Error, Equatable, Sendable {

    /// The message at `index` has no resolvable entry — no profile-specific
    /// string and no English fallback string.
    case missingMessage(index: Int)
}

/// A single format argument for Monaco's `/\{(\d+)\}/g` placeholder rule.
///
/// Monaco's `_format` stringifies arguments by `typeof`:
///   - `string`          → the string itself
///   - `number`          → `String(number)`
///   - `boolean`         → `String(boolean)` ("true" / "false")
///   - `undefined`       → `String(undefined)` ("undefined")
///   - `null`            → `String(null)` ("null")
///   - anything else     → the placeholder is left unchanged
///
/// `.absent` models an out-of-bounds argument (Monaco reads `args[index]`
/// where `index` is the first digit of the captured number; a missing slot is
/// `undefined`). `.other` models an object/array value that Monaco leaves as
/// the literal placeholder.
public enum MonaLocalizationArgument: Sendable, Equatable {

    /// A string argument — replaces the placeholder verbatim.
    case string(String)
    /// A number argument — stringified via `String(number)`.
    case number(Double)
    /// A boolean argument — stringified as "true" / "false".
    case boolean(Bool)
    /// A `null` argument — stringified as "null".
    case null
    /// An absent / `undefined` argument — stringified as "undefined".
    case absent
    /// Any other value — the placeholder is left unchanged.
    case other
}

/// The N1 UI localization surface: 15 immutable profiles × 2120 messages,
/// resolved through the explicit `MonaCodeEnvironmentProfile` mechanism.
///
/// `MonaLocalization` is a namespace (caseless enum) over the generated
/// `MonaLocalizationProfiles` tables. It performs NO Foundation localization
/// and NO network access: every lookup is over immutable repository-owned
/// Swift resources generated from the pinned monaco-editor-core@0.56.0 MIT
/// artifacts.
public enum MonaLocalization {

    /// The exact 15 selectable N1 profile identifiers, in manifest order
    /// (N1-R manifest `scopeDisposition.selectableProfiles`):
    /// English + 13 packaged locales + pseudo.
    public static let selectableProfileIdentifiers: [String] = [
        "en", "cs", "de", "es", "fr", "it",
        "ja", "ko", "pl", "pt-br", "ru", "tr",
        "zh-cn", "zh-tw", "pseudo",
    ]

    /// The number of messages every profile carries (the 2120 ordered nls.keys
    /// identities across 180 source modules).
    public static let messageCount: Int = 2120

    // MARK: - Profile → language identifier

    /// Maps a `MonaCodeEnvironmentProfile` to its N1 language identifier.
    ///
    /// `.default` maps to `"en"` (the N1 default profile; manifest
    /// `localeProfiles[0]` id="en" kind="default"). `.custom(identifier)` maps
    /// to the identifier verbatim. This is the SAME `MonaCodeEnvironmentProfile`
    /// mechanism P04-T012's announcement bridge uses — no parallel path.
    public static func languageIdentifier(for profile: MonaCodeEnvironmentProfile) -> String {
        switch profile {
        case .default: return "en"
        case .custom(let identifier): return identifier
        }
    }

    // MARK: - Lookup (N1 lookup semantics)

    /// Resolves the raw (unformatted) message at `index` under `profile`.
    ///
    /// N1 lookup semantics (manifest `observableSemantics.lookup`):
    ///   1. A profile-specific entry wins (the profile's string at `index`).
    ///   2. A null/absent profile entry falls back to the English (en) source
    ///      string at `index`.
    ///   3. Absence of both yields `MonaLocalizationError.missingMessage`.
    ///
    /// For the `pseudo` profile, the English source string is returned (the
    /// pseudo transform is applied later by `format`/`localize`).
    ///
    /// - Parameters:
    ///   - index: The flat message index (`0..<2120`).
    ///   - profile: The explicit N1 localization profile.
    /// - Returns: The raw message string for `profile` at `index`.
    /// - Throws: `MonaLocalizationError.missingMessage` when `index` is out
    ///   of range or has no resolvable entry.
    public static func resolve(
        _ index: Int,
        profile: MonaCodeEnvironmentProfile
    ) throws -> String {
        let lang = languageIdentifier(for: profile)
        // Profile-specific entry wins.
        if let table = MonaLocalizationProfiles.profile(for: lang),
           index >= 0 && index < table.entries.count,
           let entry = table.entries[index] {
            return entry
        }
        // Null/absent profile entry → English (en) fallback.
        if lang != "en",
           let en = MonaLocalizationProfiles.profile(for: "en"),
           index >= 0 && index < en.entries.count,
           let entry = en.entries[index] {
            return entry
        }
        throw MonaLocalizationError.missingMessage(index: index)
    }

    // MARK: - Format (Monaco raw UTF-16 rule + pseudo transform)

    /// Formats `message` with `args` using Monaco's raw UTF-16
    /// `/\{(\d+)\}/g` replacement rule, applying the pseudo transform when
    /// `profile` is the pseudo profile.
    ///
    /// Rule (verbatim from `vs/nls.js` `_format`):
    ///   - If `args` is empty, `message` is returned unchanged (then pseudo-
    ///     transformed if applicable).
    ///   - Otherwise each `{N}` (N one or more digits) is replaced: the
    ///     argument index is the FIRST digit of N (`rest[0]`, so `{10}` →
    ///     args[1]). A string arg replaces the placeholder; a number/boolean/
    ///     null/absent arg stringifies as Monaco (`String(arg)`); any other
    ///     value leaves the placeholder unchanged.
    ///   - If `profile` is `pseudo`, the result is wrapped in fullwidth
    ///     square brackets (U+FF3B / U+FF3D) and every lowercase a, o, u, e, i
    ///     is doubled in source order.
    public static func format(
        _ message: String,
        args: [MonaLocalizationArgument],
        profile: MonaCodeEnvironmentProfile
    ) -> String {
        let result: String
        if args.isEmpty {
            result = message
        } else {
            result = MonaLocalization.applyPlaceholderFormat(message, args: args)
        }
        let lang = languageIdentifier(for: profile)
        if lang == "pseudo" {
            return MonaLocalization.applyPseudoTransform(result)
        }
        return result
    }

    /// Applies Monaco's `/\{(\d+)\}/g` replacement (no pseudo transform).
    private static func applyPlaceholderFormat(
        _ message: String,
        args: [MonaLocalizationArgument]
    ) -> String {
        // Match /\{(\d+)\}/g: a `{` followed by one or more digits followed
        // by `}`. Use the first captured digit as the argument index.
        var output = ""
        output.reserveCapacity(message.count)
        var i = message.startIndex
        while i < message.endIndex {
            if message[i] == "{" {
                // Try to parse a {digits} run.
                if let (replacement, next) = tryPlaceholder(message: message, start: i, args: args) {
                    output.append(replacement)
                    i = next
                    continue
                }
            }
            output.append(message[i])
            i = message.index(after: i)
        }
        return output
    }

    /// Attempts to parse a `{digits}` placeholder at `start`. Returns the
    /// replacement string and the index just past `}` on success.
    private static func tryPlaceholder(
        message: String,
        start: String.Index,
        args: [MonaLocalizationArgument]
    ) -> (String, String.Index)? {
        // message[start] == '{'. Collect digits until '}'.
        var idx = message.index(after: start)
        var digits: [Character] = []
        while idx < message.endIndex {
            let c = message[idx]
            if c.isASCII && c.isNumber {
                digits.append(c)
                idx = message.index(after: idx)
            } else if c == "}" {
                if digits.isEmpty { return nil }
                // Monaco uses rest[0] (the first captured digit) as the index.
                // That digit's numeric value is the argument slot.
                let firstDigit = digits[0]
                let slot = Int(String(firstDigit)) ?? 0
                let placeholderText = String(message[start...idx])
                if let replacement = stringifyArgument(at: slot, args: args) {
                    return (replacement, message.index(after: idx))
                } else {
                    // `.other` value: leave the placeholder unchanged.
                    return (placeholderText, message.index(after: idx))
                }
            } else {
                return nil
            }
        }
        return nil
    }

    /// Stringifies `args[slot]` exactly as Monaco's `_format`:
    /// - string → the string
    /// - number/boolean → String(arg)
    /// - undefined (absent / out of bounds) → "undefined"
    /// - null → "null"
    /// - other → unchanged placeholder (caller leaves `{N}` as-is)
    private static func stringifyArgument(
        at slot: Int,
        args: [MonaLocalizationArgument]
    ) -> String? {
        // Out of bounds → undefined.
        guard slot >= 0 && slot < args.count else {
            return "undefined"
        }
        switch args[slot] {
        case .string(let s): return s
        case .number(let n):
            // String(number): integers render without a trailing ".0".
            if n == n && n.isFinite {
                if n == n.rounded() && abs(n) < 1e21 {
                    return String(Int64(n))
                }
                return String(n)
            }
            return String(n)
        case .boolean(let b): return b ? "true" : "false"
        case .absent: return "undefined"
        case .null: return "null"
        case .other: return nil   // leave placeholder unchanged
        }
    }

    /// Applies the Monaco pseudo transform:
    /// `'［' + result.replace(/[aouei]/g, '$&$&') + '］'`
    /// (U+FF3B / U+FF3D fullwidth brackets; doubles lowercase a, o, u, e, i.)
    private static func applyPseudoTransform(_ message: String) -> String {
        var doubled = ""
        doubled.reserveCapacity(message.count * 2)
        for scalar in message.unicodeScalars {
            switch scalar {
            case "a", "o", "u", "e", "i":
                doubled.unicodeScalars.append(scalar)
                doubled.unicodeScalars.append(scalar)
            default:
                doubled.unicodeScalars.append(scalar)
            }
        }
        return "\u{FF3B}" + doubled + "\u{FF3D}"
    }

    // MARK: - localize (resolve + format)

    /// The full Monaco `localize`: resolves the message at `index` under
    /// `profile` (N1 lookup semantics), then formats it with `args`
    /// (including the pseudo transform when applicable).
    ///
    /// - Throws: `MonaLocalizationError.missingMessage` when `index` has no
    ///   resolvable entry.
    public static func localize(
        _ index: Int,
        args: [MonaLocalizationArgument] = [],
        profile: MonaCodeEnvironmentProfile
    ) throws -> String {
        let message = try resolve(index, profile: profile)
        return format(message, args: args, profile: profile)
    }

    // MARK: - localize2 (value + original)

    /// The Monaco `localize2` result: the localized `value` plus the
    /// separately formatted `original` English message.
    public struct Localization2Result: Sendable, Equatable {
        /// The formatted localized message.
        public let value: String
        /// The formatted original English message.
        public let original: String
        public init(value: String, original: String) {
            self.value = value
            self.original = original
        }
    }

    /// The full Monaco `localize2`: resolves the message at `index` under
    /// `profile`, formats it as `value`, and separately formats the original
    /// English source message as `original`.
    ///
    /// When the looked-up message equals the original English (no translation,
    /// or the en/pseudo profile), `original == value`. Otherwise `original` is
    /// the formatted English source.
    ///
    /// - Throws: `MonaLocalizationError.missingMessage` when `index` has no
    ///   resolvable entry.
    public static func localize2(
        _ index: Int,
        args: [MonaLocalizationArgument] = [],
        profile: MonaCodeEnvironmentProfile
    ) throws -> Localization2Result {
        let message = try resolve(index, profile: profile)
        let value = format(message, args: args, profile: profile)
        // The original English source message at this index.
        let originalEnglish = try resolve(index, profile: .default)
        let original: String
        if originalEnglish == message {
            original = value
        } else {
            original = format(originalEnglish, args: args, profile: profile)
        }
        return Localization2Result(value: value, original: original)
    }
}
