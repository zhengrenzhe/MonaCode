// MonaColorizeViewTests.swift
//
// P05-T010 — Implement editor.colorizeElement as a native view mutation replacement.
//
// Verifies `MonaColorizeView` — the native view-mutation replacement for
// Monaco's `editor.colorizeElement` API. Monaco's original `colorizeElement`
// takes a DOM `HTMLElement`, reads its text, colorizes it into HTML spans, and
// replaces the element's `innerHTML`. MonaCode is a native macOS/AppKit port:
// the replacement applies a `MonaColorizeSource`'s attributed token
// presentation (P05-T009) to a frozen AppKit-native text host
// (`MonaColorizeHost` carrying an `NSTextStorage`) — no web element, no DOM,
// no CSS. Theme/token changes trigger INCREMENTAL range updates (only changed
// ranges re-applied), and every observation is disposed with the host lifetime.
//
// Test contract (P05-T010): 1 case, covering:
//   - attributed presentation applied to the host;
//   - incremental update on theme change (only changed ranges re-applied — a
//     full re-render does NOT happen when only one range changed);
//   - incremental update on token change (same boundaries, only changed scope
//     re-applied);
//   - all observations disposed with host lifetime (no leak after teardown);
//   - the host type is the frozen AppKit-native type (no web element).

import XCTest
import AppKit
import Foundation
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

@MainActor
final class MonaColorizeViewTests: XCTestCase {

    // MARK: - Helpers

    /// A minimal in-process direct token provider for tests: produces tokens at
    /// caller-supplied raw UTF-16 offsets, each tagged with a scope id. The
    /// `tokens` array is mutable so a test can swap the token layout between
    /// renders to exercise the incremental token-change path.
    private final class StubTokenProvider: MonaDirectTokenProvider {
        var tokens: [MonaColorToken]

        init(tokens: [MonaColorToken]) {
            self.tokens = tokens
        }

        func tokens(for source: [UInt16]) -> [MonaColorToken] {
            return tokens
        }
    }

    /// Builds raw UTF-16 units from a Swift string.
    private func makeUnits(_ s: String) -> [UInt16] {
        return Array(s.utf16)
    }

    /// Formats an `NSColor` as a 6-digit lowercase hex string (no leading `#`),
    /// matching the foreground strings stored in `MonaTokenColorRule`.
    private func hexString(from color: NSColor?) -> String? {
        guard let color = color else { return nil }
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "%02x%02x%02x", r, g, b)
    }

    // MARK: - 1. Attributed presentation applied to the host

    /// `render(source:)` colorizes the source and applies the attributed token
    /// presentation to the host's `NSTextStorage`. Each token's range carries
    /// its resolved `.foregroundColor` from the active theme.
    func testAttributedPresentationAppliedToHost() {
        let registry = MonaThemeRegistry()
        let colorize = MonaColorizeSource(themeRegistry: registry)
        let host = MonaColorizeHost()
        let view = MonaColorizeView(source: colorize, host: host)

        let provider = StubTokenProvider(tokens: [
            MonaColorToken(startUTF16: 0, endUTF16: 3, scope: "keyword"),
        ])
        colorize.directTokenProvider = provider
        view.render(source: makeUnits("abc"))

        // The host's text storage carries the source text verbatim.
        XCTAssertEqual(host.textStorage.string, "abc",
                       "the host must carry the colorized source text")
        XCTAssertEqual(host.textStorage.length, 3,
                       "host length equals raw UTF-16 unit count")

        // The token's range carries its resolved foreground color.
        let color = host.textStorage.attribute(.foregroundColor, at: 0,
                                                 effectiveRange: nil) as? NSColor
        XCTAssertNotNil(color,
                        "the token foreground color must be applied to the host")
        let expectedHex = registry.currentTheme.rule(for: "keyword")?.foreground?.lowercased()
        XCTAssertEqual(hexString(from: color), expectedHex,
                       "the applied color must match the active theme's rule for the scope")

        // The initial render is a FULL render.
        XCTAssertEqual(view.fullRerenderCount, 1,
                        "the initial render must be a full render")
    }

    // MARK: - 2. Incremental update on theme change (only changed ranges)

    /// On theme change, only the token ranges whose resolved color actually
    /// changed are re-applied — a full re-render does NOT happen when only one
    /// range changed.
    func testIncrementalUpdateOnThemeChangeOnlyChangedRanges() {
        let registry = MonaThemeRegistry()

        // Build a custom theme identical to `vs-dark` but with the `keyword`
        // foreground changed. Switching `vs-dark` → this theme changes exactly
        // ONE token's color, exercising the incremental path.
        let vsDark = MonaBuiltinThemes.theme(for: "vs-dark")!
        var rules = vsDark.rules
        if let i = rules.firstIndex(where: { $0.token == "keyword" }) {
            rules[i] = MonaTokenColorRule(token: "keyword",
                                          foreground: "FF0000",
                                          background: rules[i].background,
                                          fontStyle: rules[i].fontStyle)
        }
        let customTheme = MonaTokenTheme(id: "custom-kw",
                                          base: "vs-dark",
                                          inherit: false,
                                          colors: vsDark.colors,
                                          rules: rules)
        registry.defineTheme(customTheme)

        let colorize = MonaColorizeSource(themeRegistry: registry)
        let host = MonaColorizeHost()
        let view = MonaColorizeView(source: colorize, host: host)

        let provider = StubTokenProvider(tokens: [
            MonaColorToken(startUTF16: 0, endUTF16: 1, scope: "keyword"),
            MonaColorToken(startUTF16: 1, endUTF16: 2, scope: "string"),
            MonaColorToken(startUTF16: 2, endUTF16: 3, scope: "comment"),
        ])
        colorize.directTokenProvider = provider
        view.render(source: [0x0061, 0x0062, 0x0063]) // "abc"
        XCTAssertEqual(view.fullRerenderCount, 1,
                       "initial render must be a full render")

        // Switch to the custom theme — only the keyword color changes
        // (569CD6 → FF0000); string and comment colors are identical to vs-dark.
        registry.setTheme("custom-kw")

        // NO full re-render happened.
        XCTAssertEqual(view.fullRerenderCount, 1,
                       "theme change must NOT trigger a full re-render")
        // ONLY the keyword range (0..<1) was incrementally updated.
        XCTAssertEqual(view.lastIncrementalRanges, [NSRange(location: 0, length: 1)],
                       "only the changed range must be incrementally updated")
        // The keyword color actually changed to FF0000.
        let kwColor = host.textStorage.attribute(.foregroundColor, at: 0,
                                                   effectiveRange: nil) as? NSColor
        XCTAssertEqual(hexString(from: kwColor), "ff0000",
                       "the changed token must reflect the new theme's foreground")
        // The string color did NOT change (still vs-dark's CE9178).
        let strColor = host.textStorage.attribute(.foregroundColor, at: 1,
                                                   effectiveRange: nil) as? NSColor
        XCTAssertEqual(hexString(from: strColor), "ce9178",
                       "an unchanged token's color must NOT be re-applied")
        // The comment color did NOT change (still vs-dark's 608B4E).
        let cmtColor = host.textStorage.attribute(.foregroundColor, at: 2,
                                                   effectiveRange: nil) as? NSColor
        XCTAssertEqual(hexString(from: cmtColor), "608b4e",
                       "an unchanged token's color must NOT be re-applied")
    }

    // MARK: - 3. Incremental update on token change (only changed ranges)

    /// When the token provider changes a token's scope (but keeps the same
    /// boundaries), only the changed token's range is re-applied — no full
    /// re-render.
    func testIncrementalUpdateOnTokenChangeOnlyChangedRanges() {
        let registry = MonaThemeRegistry()
        let colorize = MonaColorizeSource(themeRegistry: registry)
        let host = MonaColorizeHost()
        let view = MonaColorizeView(source: colorize, host: host)

        let provider = StubTokenProvider(tokens: [
            MonaColorToken(startUTF16: 0, endUTF16: 1, scope: "keyword"),
            MonaColorToken(startUTF16: 1, endUTF16: 2, scope: "string"),
        ])
        colorize.directTokenProvider = provider
        view.render(source: [0x0061, 0x0062]) // "ab"
        XCTAssertEqual(view.fullRerenderCount, 1)

        // Change only the second token's scope (same boundaries).
        provider.tokens = [
            MonaColorToken(startUTF16: 0, endUTF16: 1, scope: "keyword"),
            MonaColorToken(startUTF16: 1, endUTF16: 2, scope: "comment"),
        ]
        view.refresh()

        // Same boundaries — incremental, NOT a full re-render.
        XCTAssertEqual(view.fullRerenderCount, 1,
                       "token change with same boundaries must NOT full re-render")
        // Only the second token's range (1..<2) was incrementally updated.
        XCTAssertEqual(view.lastIncrementalRanges, [NSRange(location: 1, length: 1)],
                       "only the changed token's range must be incrementally updated")
        // The second token's color changed to comment's (608B4E under vs-dark).
        let secondColor = host.textStorage.attribute(.foregroundColor, at: 1,
                                                       effectiveRange: nil) as? NSColor
        XCTAssertEqual(hexString(from: secondColor), "608b4e",
                       "the changed token must reflect the new scope's color")
        // The first token's color did NOT change (still keyword's 569CD6).
        let firstColor = host.textStorage.attribute(.foregroundColor, at: 0,
                                                     effectiveRange: nil) as? NSColor
        XCTAssertEqual(hexString(from: firstColor), "569cd6",
                       "an unchanged token's color must NOT be re-applied")
    }

    // MARK: - 4. All observations disposed with host lifetime (no leak)

    /// After `detach()`, a theme change must NOT mutate the host — every
    /// observation (theme-change subscription) is disposed with the host
    /// lifetime. No retained closure leaks.
    func testObservationsDisposedWithHostLifetime() {
        let registry = MonaThemeRegistry()
        let colorize = MonaColorizeSource(themeRegistry: registry)
        let host = MonaColorizeHost()
        let view = MonaColorizeView(source: colorize, host: host)

        let provider = StubTokenProvider(tokens: [
            MonaColorToken(startUTF16: 0, endUTF16: 1, scope: "keyword"),
        ])
        colorize.directTokenProvider = provider
        view.render(source: [0x0061]) // "a"

        // Snapshot the host's color before detach.
        let colorBefore = host.textStorage.attribute(.foregroundColor, at: 0,
                                                       effectiveRange: nil) as? NSColor

        // Detach — every observation must be disposed.
        view.detach()

        // Change the theme — the handler must NOT fire (no leak).
        // vs-dark keyword = 569CD6; vs keyword = 0000FF — they differ, so if the
        // handler leaked, the host color would change.
        registry.setTheme("vs")

        let colorAfter = host.textStorage.attribute(.foregroundColor, at: 0,
                                                      effectiveRange: nil) as? NSColor
        XCTAssertEqual(hexString(from: colorBefore), hexString(from: colorAfter),
                       "theme change after detach must NOT mutate the host (no leak)")
        // The render/incremental counters are unchanged after detach.
        XCTAssertEqual(view.fullRerenderCount, 1,
                       "full rerender count must be unchanged after detach")
        XCTAssertEqual(view.lastIncrementalRanges, [],
                       "incremental ranges must be unchanged after detach")
    }

    // MARK: - 5. Host type is the frozen AppKit-native type (no web element)

    /// The host is the frozen AppKit-native replacement for Monaco's DOM
    /// `HTMLElement` parameter — it carries an `NSTextStorage`, not a web
    /// element. No DOM, no CSS.
    func testHostIsFrozenAppKitNativeType() {
        let host = MonaColorizeHost()

        // The host carries an NSTextStorage — AppKit's native attributed-text
        // backing store. No web element, no DOM, no CSS.
        XCTAssertTrue(host.textStorage is NSTextStorage,
                      "the host must carry an AppKit-native NSTextStorage")
        XCTAssertEqual(host.textStorage.length, 0,
                       "a fresh host has an empty text storage")

        // The host type is MonaColorizeHost — the frozen AppKit-native
        // replacement for Monaco's DOM HTMLElement parameter.
        XCTAssertTrue(type(of: host) == MonaColorizeHost.self,
                      "the host type is the frozen AppKit-native MonaColorizeHost")

        // The view binds a source to a host — no web element parameter.
        let colorize = MonaColorizeSource()
        let view = MonaColorizeView(source: colorize, host: host)
        XCTAssertTrue(view.host === host,
                      "the view binds the frozen native host, not a web element")
        XCTAssertTrue(view.source === colorize,
                      "the view binds the colorize source")
    }
}
