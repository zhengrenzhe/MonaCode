// MonaToken.swift
//
// P01-T004 — Implement key, modifier, token, and marker value types.
//
// `MonaToken` is a faithful port of `monaco.Token` — the value type Monaco uses
// to describe a single tokenized span on a line. It carries five unique
// aspects, matching Monaco's `Token` class exactly:
//
//   - `offset`     — the raw UTF-16 code-unit offset where the token starts.
//   - `type`       — the token type as a free-form string (e.g. "keyword.ts").
//   - `language`   — the language identifier (e.g. "typescript").
//   - `_tokenBrand` — a `Void` brand field that Monaco carries on the class for
//                     structural identity; it holds no data.
//   - `toString()`  — Monaco formats this as `[offset|type|language]`.
//
// Offsets are preserved verbatim: the integer passed in is the integer stored,
// including zero and large offsets up to `0x10FFFF`. No grapheme conversion is
// applied, matching Monaco's raw UTF-16 contract.
//
// `MonaTokenType` is a companion extensible raw-value wrapper for the numeric
// `StandardTokenType` encoding Monaco uses internally in encoded token
// metadata (`Other = 0`, `Comment = 1`, `String = 2`, `RegEx = 3`). Unknown
// numeric encodings are accepted via `custom(_:)` / `init(rawValue:)`, so the
// wrapper can carry values the tokenizer surfaces before the known set catches
// up — exactly the extensible-raw-value contract required for key codes.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A tokenized span on a line, ported from `monaco.Token`.
///
/// Stores the raw UTF-16 `offset`, the `type` string, and the `language`
/// identifier. The `_tokenBrand` `Void` field is carried for structural
/// fidelity with Monaco's class but holds no data. `toString()` produces
/// Monaco's `[offset|type|language]` format.
public struct MonaToken: Equatable, Hashable, Sendable {

    /// The raw UTF-16 code-unit offset where the token starts. Preserved
    /// verbatim — no grapheme conversion, no clamping.
    public let offset: Int

    /// The token type as a free-form string (e.g. `"keyword.ts"`). Token types
    /// are inherently extensible: Monaco encodes them as `<type>.<language>`
    /// strings and accepts arbitrary values.
    public let type: String

    /// The language identifier (e.g. `"typescript"`).
    public let language: String

    /// Monaco carries a `_tokenBrand: void` field on the `Token` class for
    /// structural identity. It holds no data and is always `()`; it participates
    /// in the API surface but never affects equality (two tokens with equal
    /// offset/type/language are equal). Exposed as a computed `Void` property so
    /// it occupies no storage and is excluded from synthesized equality/hash.
    public var _tokenBrand: Void {
        return ()
    }

    /// Creates a token storing `offset`, `type`, and `language` verbatim.
    public init(offset: Int, type: String, language: String) {
        self.offset = offset
        self.type = type
        self.language = language
    }

    /// Returns the Monaco format `[offset|type|language]`.
    public func toString() -> String {
        return "[\(offset)|\(type)|\(language)]"
    }
}

/// An extensible raw-value wrapper for the numeric token-type encoding Monaco
/// uses internally in encoded token metadata (`StandardTokenType`).
///
/// The four known encodings (`Other = 0`, `Comment = 1`, `String = 2`,
/// `RegEx = 3`) are exposed as static constants; any other integer is accepted
/// via `custom(_:)` / `init(rawValue:)`, so a tokenizer can surface values the
/// known set does not yet cover. Equality is by raw value.
public struct MonaTokenType: Equatable, Hashable, Sendable {

    /// The numeric token-type encoding.
    public let rawValue: Int

    /// Creates a token type from a raw integer value.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Creates a token type for an unknown numeric encoding not covered by the
    /// known constants. Functionally identical to `init(rawValue:)`.
    public static func custom(_ value: Int) -> MonaTokenType {
        return MonaTokenType(rawValue: value)
    }

    // MARK: - Known standard token types (ported from StandardTokenType)

    /// Any token that is not a comment, string, or regular expression.
    public static let other = MonaTokenType(rawValue: 0)

    /// A comment token.
    public static let comment = MonaTokenType(rawValue: 1)

    /// A string literal token.
    public static let string = MonaTokenType(rawValue: 2)

    /// A regular-expression literal token.
    public static let regEx = MonaTokenType(rawValue: 3)
}
