// MonaColorizeSourceTests.swift
//
// P05-T009 — Implement editor.colorize as a native attributed-text replacement.
//
// Verifies `MonaColorizeSource` — the native attributed-text replacement for
// Monaco's HTML-emitting `editor.colorize` API. The output is purely a native
// `NSAttributedString` (never HTML, never DOM/CSS). Token boundaries are RAW
// UTF-16 ranges (consistent with the project's raw-UInt16 invariant — lone
// surrogates preserved as exactly one unit, never repaired to U+FFFD). Each
// token's foreground color is resolved from the active theme (P05-T006
// `MonaColorRegistry` / `MonaThemeRegistry`) via the token's scope.
//
// Test contract (P05-T009):
//   - colorize with an attached direct token provider returns attributed text
//     with token-boundary colors (raw UTF-16 ranges, one color per token).
//   - colorize without a provider falls back to plain text (the whole source
//     is a single token, no per-token coloring — the default foreground or no
//     color applied).
//   - the output is always an `NSAttributedString` (never HTML).
//   - raw UTF-16 boundaries are honored: a lone surrogate (0xD800) counts as
//     exactly one UTF-16 unit in every token range.

import XCTest
import AppKit
import Foundation
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaColorizeSourceTests: XCTestCase {

    // MARK: - Helpers

    /// A minimal in-process direct token provider for tests: produces tokens
    /// at caller-supplied raw UTF-16 offsets, each tagged with a scope id.
    private final class StubTokenProvider: MonaDirectTokenProvider {
        var tokens: [MonaColorToken]

        init(tokens: [MonaColorToken]) {
            self.tokens = tokens
        }

        func tokens(for source: [UInt16]) -> [MonaColorToken] {
            return tokens
        }
    }

    /// Builds raw UTF-16 units from a Swift string (lone surrogates in a
    /// String literal are repaired by Swift; use `makeUnits(_:)` with explicit
    /// lone-surrogate values to test preservation).
    private func makeUnits(_ s: String) -> [UInt16] {
        return Array(s.utf16)
    }

    /// Returns the hex foreground color string for a scope from the active
    /// theme's token rules, mirroring the resolution the colorize source
    /// performs. Used only to compute the expected color in tests.
    private func expectedForeground(for scope: String, in themeId: String) -> String? {
        let registry = MonaThemeRegistry()
        registry.setTheme(themeId)
        let theme = registry.currentTheme
        return theme.rule(for: scope)?.foreground
    }

    // MARK: - Output type: always NSAttributedString, never HTML

    /// colorize returns an `NSAttributedString` — never HTML, never a DOM/CSS
    /// renderer artifact.
    func testColorizeReturnsNativeAttributedString() {
        let source = makeUnits("hello")
        let colorize = MonaColorizeSource(language: MonaPlainTextLanguage())
        let result = colorize.colorize(source: source)
        XCTAssertTrue(result is NSAttributedString,
                      "colorize must return a native NSAttributedString")
        // The string must NOT contain HTML markup.
        let plain = result.string
        XCTAssertFalse(plain.contains("<span"), "colorize must never emit HTML")
        XCTAssertFalse(plain.contains("<div"), "colorize must never emit HTML")
    }

    // MARK: - Plain-text fallback (no provider attached)

    /// Without a direct token provider, the colorize source falls back to the
    /// plain-text language: the whole source is one token, and no per-token
    /// foreground color is applied (the default — no `.foregroundColor`
    /// attribute on the whole range).
    func testColorizeWithoutProviderFallsBackToPlainText() {
        let source = makeUnits("plain text")
        let colorize = MonaColorizeSource(language: MonaPlainTextLanguage())
        let attr = colorize.colorize(source: source)

        // The full text survives verbatim.
        XCTAssertEqual(attr.string, "plain text",
                       "plain-text fallback must preserve the full source")
        XCTAssertEqual(attr.length, source.count,
                       "attributed length equals raw UTF-16 unit count")

        // No `.foregroundColor` attribute anywhere — the plain-text fallback
        // applies no per-token coloring.
        let fullRange = NSRange(location: 0, length: attr.length)
        let attrs = attr.attributes(at: 0, longestEffectiveRange: nil,
                                     in: fullRange)
        XCTAssertNil(attrs[NSAttributedString.Key.foregroundColor],
                     "plain-text fallback must apply no foreground color")
    }

    // MARK: - With a direct token provider: per-token colors, raw UTF-16 ranges

    /// With an attached direct token provider, each token's raw UTF-16 range
    /// receives a `.foregroundColor` resolved from the active theme.
    func testColorizeWithProviderAppliesPerTokenColors() {
        // Source: "abc" — three UTF-16 units, three single-unit tokens.
        let source: [UInt16] = [0x0061, 0x0062, 0x0063] // a, b, c
        let tokens: [MonaColorToken] = [
            MonaColorToken(startUTF16: 0, endUTF16: 1, scope: "keyword"),
            MonaColorToken(startUTF16: 1, endUTF16: 2, scope: "string"),
            MonaColorToken(startUTF16: 2, endUTF16: 3, scope: "comment"),
        ]
        let provider = StubTokenProvider(tokens: tokens)
        let colorize = MonaColorizeSource(language: MonaPlainTextLanguage(),
                                           themeRegistry: MonaThemeRegistry())
        colorize.directTokenProvider = provider

        let attr = colorize.colorize(source: source)
        XCTAssertEqual(attr.length, 3, "length equals raw UTF-16 unit count")

        // Each unit's foreground color matches the theme's rule for its scope.
        let registry = colorize.themeRegistry
        let theme = registry.currentTheme
        for (i, token) in tokens.enumerated() {
            let attrs = attr.attributes(at: i, longestEffectiveRange: nil,
                                         in: NSRange(location: 0, length: 3))
            let color = attrs[NSAttributedString.Key.foregroundColor] as? NSColor
            XCTAssertNotNil(color,
                            "token at UTF-16 offset \(i) (scope \(token.scope)) must have a foreground color")
            let expectedHex = theme.rule(for: token.scope)?.foreground?.lowercased()
            XCTAssertEqual(hexString(from: color), expectedHex,
                           "token color at offset \(i) must match theme rule for scope \(token.scope)")
        }
    }

    // MARK: - Raw UTF-16 boundaries: lone surrogate preserved as one unit

    /// A lone surrogate (0xD800) is exactly one UTF-16 unit in every token
    /// range. Token boundaries are raw UTF-16 offsets, never repaired.
    func testColorizePreservesLoneSurrogateAsOneUnit() {
        // Raw units: "a" + lone high surrogate (0xD800) + "b".
        let source: [UInt16] = [0x0061, 0xD800, 0x0062]
        // One token covers the lone surrogate alone.
        let tokens: [MonaColorToken] = [
            MonaColorToken(startUTF16: 0, endUTF16: 1, scope: "keyword"),
            MonaColorToken(startUTF16: 1, endUTF16: 2, scope: "string"),
            MonaColorToken(startUTF16: 2, endUTF16: 3, scope: "comment"),
        ]
        let provider = StubTokenProvider(tokens: tokens)
        let colorize = MonaColorizeSource(language: MonaPlainTextLanguage(),
                                           themeRegistry: MonaThemeRegistry())
        colorize.directTokenProvider = provider

        let attr = colorize.colorize(source: source)

        // Length is 3 UTF-16 units — the lone surrogate is one unit.
        XCTAssertEqual(attr.length, 3,
                       "lone surrogate must count as exactly one UTF-16 unit")
        // The lone surrogate survives verbatim in the attributed string's
        // backing store (NSString is a UTF-16 container). `String` bridge
        // repairs it to U+FFFD, so verify via CFString.
        let cf = attr.string as CFString
        XCTAssertEqual(CFStringGetCharacterAtIndex(cf, 1), 0xD800,
                       "lone surrogate must survive in the attributed string (no repair)")

        // The token covering the lone surrogate (offset 1) carries its own
        // foreground color — distinct from its neighbors when the theme
        // distinguishes the scopes.
        let midAttrs = attr.attributes(at: 1, longestEffectiveRange: nil,
                                        in: NSRange(location: 0, length: 3))
        XCTAssertNotNil(midAttrs[NSAttributedString.Key.foregroundColor],
                         "the lone-surrogate token must carry a foreground color")
    }

    // MARK: - Theme variant resolution

    /// The colorize source resolves token colors against the active theme's
    /// variant (dark/light/hc), honoring `MonaColorVariant`.
    func testColorizeResolvesAgainstActiveThemeVariant() {
        let source: [UInt16] = [0x0061] // "a"
        let tokens: [MonaColorToken] = [
            MonaColorToken(startUTF16: 0, endUTF16: 1, scope: "comment"),
        ]
        let provider = StubTokenProvider(tokens: tokens)
        let registry = MonaThemeRegistry()
        registry.setTheme("vs") // light theme
        let colorize = MonaColorizeSource(language: MonaPlainTextLanguage(),
                                           themeRegistry: registry)
        colorize.directTokenProvider = provider

        let attr = colorize.colorize(source: source)
        let attrs = attr.attributes(at: 0, longestEffectiveRange: nil,
                                     in: NSRange(location: 0, length: 1))
        let color = attrs[NSAttributedString.Key.foregroundColor] as? NSColor
        XCTAssertNotNil(color, "token must resolve to a color under the active theme")
        // The vs (light) theme's comment foreground is "008000".
        XCTAssertEqual(hexString(from: color), "008000".lowercased(),
                       "comment scope under the 'vs' theme must resolve to its rule foreground")
    }

    // MARK: - Private: hex-from-NSColor helper

    /// Formats an `NSColor` as a 6-digit lowercase hex string (no leading
    /// `#`), matching the foreground strings stored in `MonaTokenColorRule`.
    private func hexString(from color: NSColor?) -> String? {
        guard let color = color else { return nil }
        // The colorize source creates colors in the sRGB space; read components
        // back in sRGB (no genericRGB conversion, which shifts sRGB values).
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "%02x%02x%02x", r, g, b)
    }
}
