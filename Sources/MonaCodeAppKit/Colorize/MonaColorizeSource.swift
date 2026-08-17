// MonaColorizeSource.swift
//
// P05-T009 — Implement editor.colorize as a native attributed-text replacement.
//
// `MonaColorizeSource` is the native attributed-text replacement for Monaco's
// `editor.colorize` API. Monaco's original colorize emits HTML (a `<div>` of
// `<span>` runs with inline CSS classes resolved against a theme). MonaCode is
// a native macOS/AppKit port: the colorize output is purely an
// `NSAttributedString` — no HTML serialization, no DOM, no CSS renderer. Each
// token's range carries a resolved `.foregroundColor` attribute drawn from the
// active theme (P05-T006 `MonaColorRegistry` / `MonaThemeRegistry`).
//
// The source accepts raw UTF-16 `[UInt16]` text and a language. Tokenization is
// supplied by an attached `MonaDirectTokenProvider` (a Phase 06 provider
// protocol defined minimally here). When no provider is attached, the source
// falls back to `MonaPlainTextLanguage` (P05-T008) — the plain-text fallback
// performs no tokenization (the whole source is one token) and applies no
// per-token color.
//
// Raw UTF-16 invariant (consistent with `MonaAXTextArea` / `MonaPieceTree`):
// token boundaries are RAW UTF-16 offsets. A lone surrogate counts as exactly
// one UTF-16 unit on both the input side (the `[UInt16]` source) and the
// output side (the `NSAttributedString`, whose backing `NSString` is a UTF-16
// container). The attributed string is built directly from the raw units via
// `NSString(characters:length:)` — bypassing Swift's lossy `String` decoder,
// which repairs lone surrogates to U+FFFD.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaColorToken

/// A single colorization token: a RAW UTF-16 range `[startUTF16, endUTF16)`
/// within the source plus the scope id used to resolve its theme color.
///
/// The range is expressed in raw UTF-16 code-unit offsets against the same
/// `[UInt16]` source passed to `MonaDirectTokenProvider.tokens(for:)`. A lone
/// surrogate occupies exactly one unit; token boundaries never repair it.
public struct MonaColorToken: Sendable, Equatable {

    /// The inclusive start UTF-16 offset (raw code-unit index).
    public let startUTF16: Int
    /// The exclusive end UTF-16 offset (raw code-unit index).
    public let endUTF16: Int
    /// The token scope id (e.g. `"keyword"`, `"string"`, `"comment"`). Resolved
    /// against the active theme's token rules (`MonaTokenTheme.rule(for:)`).
    public let scope: String

    public init(startUTF16: Int, endUTF16: Int, scope: String) {
        self.startUTF16 = startUTF16
        self.endUTF16 = endUTF16
        self.scope = scope
    }
}

// MARK: - MonaDirectTokenProvider

/// A direct tokenization provider: given the raw UTF-16 source units, returns
/// the tokens covering it. This is the attachment point for Phase 06
/// providers (Monaco `TokensProvider` / `EncodedTokensProvider` ports). Until
/// Phase 06, only the plain-text fallback path is exercised — a colorize
/// source with no attached provider performs no tokenization.
public protocol MonaDirectTokenProvider: AnyObject {

    /// Returns the tokens covering `source`, in raw UTF-16 offset order.
    ///
    /// - Parameter source: The raw UTF-16 code units of the source text. A lone
    ///   surrogate is one unit; providers must not repair it.
    /// - Returns: Tokens whose `startUTF16`/`endUTF16` ranges are raw UTF-16
    ///   offsets into `source`.
    func tokens(for source: [UInt16]) -> [MonaColorToken]
}

// MARK: - MonaColorizeSource

/// The native attributed-text replacement for Monaco's `editor.colorize`.
///
/// Construct with `init(language:themeRegistry:)`. Optionally attach a
/// `MonaDirectTokenProvider` via `directTokenProvider`. Call
/// `colorize(source:)` with the raw UTF-16 `[UInt16]` source to receive an
/// `NSAttributedString` whose token ranges carry resolved `.foregroundColor`
/// attributes from the active theme. When no provider is attached, the
/// plain-text fallback applies no per-token color.
///
/// The output is always a native `NSAttributedString` — never HTML, never a
/// DOM/CSS renderer artifact.
public final class MonaColorizeSource {

    // MARK: - Configuration

    /// The language. When no `directTokenProvider` is attached, the plain-text
    /// fallback (`MonaPlainTextLanguage`) is used and no tokenization occurs.
    public let language: MonaPlainTextLanguage

    /// The theme registry supplying the active theme + variant used to resolve
    /// token foreground colors. Defaults to a fresh `MonaThemeRegistry`
    /// (active theme = `vs-dark`, Monaco's standalone default).
    public let themeRegistry: MonaThemeRegistry

    /// The optional direct token provider (Phase 06 attachment point). When
    /// `nil`, colorize falls back to the plain-text path: one token spanning
    /// the whole source, no per-token foreground color applied.
    public var directTokenProvider: MonaDirectTokenProvider?

    // MARK: - Init

    /// Creates a colorize source.
    ///
    /// - Parameters:
    ///   - language: The plain-text fallback language (P05-T008). The
    ///     colorize surface currently exercises the plain-text fallback path;
    ///     Phase 06 will supply real languages through `directTokenProvider`.
    ///   - themeRegistry: The theme registry. Defaults to a fresh registry
    ///     with the active theme set to Monaco's standalone default (`vs-dark`).
    public init(language: MonaPlainTextLanguage = MonaPlainTextLanguage(),
                themeRegistry: MonaThemeRegistry = MonaThemeRegistry()) {
        self.language = language
        self.themeRegistry = themeRegistry
    }

    // MARK: - colorize

    /// Colorizes the raw UTF-16 `source` into a native `NSAttributedString`.
    ///
    /// Token boundaries are raw UTF-16 offsets (a lone surrogate is one unit,
    /// preserved verbatim). Each token's range receives a `.foregroundColor`
    /// attribute resolved from the active theme's rule for the token's scope.
    /// When no `directTokenProvider` is attached, the plain-text fallback
    /// applies no per-token color.
    ///
    /// The result is always an `NSAttributedString` — never HTML.
    ///
    /// - Parameter source: The raw UTF-16 code units of the source text. Lone
    ///   surrogates survive as single units.
    /// - Returns: A native attributed string carrying the source text and any
    ///   resolved per-token foreground colors.
    public func colorize(source: [UInt16]) -> NSAttributedString {
        // Build the NSString backing store directly from the raw units — no
        // surrogate repair. NSString is a UTF-16 container, so a lone
        // surrogate occupies exactly one unit in `length` and in every
        // NSRange we apply.
        let backing = Self.nsString(fromRawUnits: source)
        let result = NSMutableAttributedString(string: backing as String)

        // Resolve tokens. Plain-text fallback: no provider -> one whole-text
        // token with no per-token color (the default). The plain-text language
        // performs no tokenization by definition.
        let tokens: [MonaColorToken]
        if let provider = directTokenProvider {
            tokens = provider.tokens(for: source)
        } else {
            tokens = []
        }

        let theme = themeRegistry.currentTheme
        let variant = activeVariant(for: theme)

        // Apply each token's resolved foreground color to its raw UTF-16 range.
        for token in tokens {
            let start = max(0, min(token.startUTF16, result.length))
            let end = max(start, min(token.endUTF16, result.length))
            guard end > start else { continue }
            let range = NSRange(location: start, length: end - start)

            guard let hex = theme.rule(for: token.scope)?.foreground,
                  let color = Self.nsColor(fromHex: hex) else {
                continue
            }
            result.addAttribute(.foregroundColor, value: color, range: range)
        }

        return result
    }

    // MARK: - Private: variant + color resolution

    /// Maps the active theme to the color variant used to resolve editor
    /// colors. The four builtin themes map directly to their variant slot;
    /// custom themes derive from their `base`.
    private func activeVariant(for theme: MonaTokenTheme) -> MonaColorVariant {
        switch theme.id {
        case "vs": return .light
        case "vs-dark": return .dark
        case "hc-black": return .hcDark
        case "hc-light": return .hcLight
        default:
            // Custom theme: derive from its base.
            switch theme.base {
            case "vs": return .light
            case "vs-dark": return .dark
            case "hc-black": return .hcDark
            case "hc-light": return .hcLight
            default: return .dark
            }
        }
    }

    // MARK: - Private: raw UTF-16 → NSString (no repair)

    /// Builds an `NSString` from raw `[UInt16]` units without surrogate repair.
    ///
    /// Uses `NSString(characters:length:)` (which stores UTF-16 code units
    /// verbatim — `NSString` is a UTF-16 container) instead of
    /// `String(decoding:as:UTF16.self)` (which repairs lone surrogates to
    /// U+FFFD). A lone surrogate therefore survives as exactly one unit in the
    /// returned string's `length`.
    static func nsString(fromRawUnits units: [UInt16]) -> NSString {
        guard !units.isEmpty else { return "" }
        return units.withUnsafeBufferPointer { buffer -> NSString in
            NSString(characters: buffer.baseAddress!, length: buffer.count)
        }
    }

    /// Parses a 6-digit hex color string (with or without a leading `#`) into
    /// an `NSColor`. Returns `nil` for malformed strings. Token-theme rule
    /// foregrounds are stored without `#` (e.g. `"008000"`).
    static func nsColor(fromHex hex: String) -> NSColor? {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
