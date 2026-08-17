// MonaThemeRegistryTests.swift
//
// P05-T006 — Implement theme, token, color, icon, and Codicon registries.
//
// Verifies the theme/color/icon/Codicon registry system ported verbatim from
// monaco-editor@0.56.0 (F1-R3 scope manifest):
//   - Exactly 431 color contributions (source-ordered, unique ids).
//   - Exactly 776 product-icon definitions (source-ordered; 34 deprecated
//     aliases resolve to their target codepoint).
//   - Four builtin themes (vs / vs-dark / hc-black / hc-light) with their
//     editor color maps and tokenization rules transcribed verbatim.
//   - Codicon glyph map: 776 entries, the contract-pinned expected TTF
//     SHA-256 (cc2472e2…6333a8) and CC BY 4.0 license provenance. The font
//     binary is intentionally not bundled in the Foundation-only Core.
//   - Deterministic default resolution: references follow, high-contrast
//     variants fall back to their dark/light base, concrete literals resolve
//     to values, transforms resolve to descriptors for the native renderer.
//   - Theme change events fire via the shared `MonaEmitter` on `setTheme`.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import XCTest
import MonaCode

final class MonaThemeRegistryTests: XCTestCase {

    // MARK: - 1. Colors: exactly 431, source-ordered, unique

    func testColorRegistryHasExactly431Entries() {
        XCTAssertEqual(MonaColorRegistry.colors.count, 431,
                       "the F1-R3 builtin color table must contain exactly 431 colors")
    }

    func testColorIdsAreUniqueAndSourceOrdered() {
        let ids = MonaColorRegistry.ids
        XCTAssertEqual(Set(ids).count, 431, "color ids must be unique")
        // First and last ids are pinned to the manifest source order.
        XCTAssertEqual(ids.first, "actionBar.toggledBackground")
        XCTAssertEqual(ids.last, "widget.shadow")
    }

    // MARK: - 2. Color default resolution (references, literals, fallback)

    func testColorReferenceResolvesThroughTarget() {
        // actionBar.toggledBackground -> reference("inputOption.activeBackground")
        // -> a per-variant object; its dark variant is a transform, but the
        // reference itself resolves into a non-.none value for the variant.
        let resolved = MonaColorRegistry.resolve("actionBar.toggledBackground", variant: .dark)
        XCTAssertNotEqual(resolved, .none,
                          "a referenced color must resolve through its target, not .none")
    }

    func testColorHexLiteralResolvesToValue() {
        // activityErrorBadge.background.dark == "#F14C4C" (hex string literal).
        let resolved = MonaColorRegistry.resolve("activityErrorBadge.background", variant: .dark)
        if case .value(let v) = resolved {
            XCTAssertEqual(v.css, "#F14C4C")
        } else {
            XCTFail("expected .value for hex literal, got \(resolved)")
        }
    }

    func testColorToStringResolvesToValue() {
        // activityErrorBadge.foreground.light has `_toString` "#ffffff".
        let resolved = MonaColorRegistry.resolve("activityErrorBadge.foreground", variant: .light)
        if case .value(let v) = resolved {
            XCTAssertEqual(v.css, "#ffffff")
        } else {
            XCTFail("expected .value for _toString, got \(resolved)")
        }
    }

    func testColorRgbaOnlyResolvesToComputedHex() {
        // chart.axis.dark is rgba(r:191,g:191,b:191,a:0.4) with no _toString ->
        // resolved to an rgba(...) css string (alpha < 1).
        let resolved = MonaColorRegistry.resolve("chart.axis", variant: .dark)
        if case .value(let v) = resolved {
            XCTAssertTrue(v.css.hasPrefix("rgba("), "rgba-only color resolves to rgba(...) string; got \(v.css)")
        } else {
            XCTFail("expected .value for rgba-only color, got \(resolved)")
        }
    }

    func testHighContrastDarkFallsBackToDarkWhenNull() {
        // Many colors have hcDark == null; the resolver falls back to the dark
        // variant. activityErrorBadge.background.hcDark is null -> dark value.
        let dark = MonaColorRegistry.resolve("activityErrorBadge.background", variant: .dark)
        let hcDark = MonaColorRegistry.resolve("activityErrorBadge.background", variant: .hcDark)
        XCTAssertEqual(dark, hcDark, "hcDark null must fall back to the dark variant")
    }

    func testHighContrastLightFallsBackToLightWhenNull() {
        // diffEditor.diagonalFill has hcLight == null and light == "#22222233";
        // the resolver falls back from hcLight to the light variant.
        let light = MonaColorRegistry.resolve("diffEditor.diagonalFill", variant: .light)
        let hcLight = MonaColorRegistry.resolve("diffEditor.diagonalFill", variant: .hcLight)
        XCTAssertEqual(light, hcLight, "hcLight null must fall back to the light variant")
        if case .value(let v) = light {
            XCTAssertEqual(v.css, "#22222233")
        } else {
            XCTFail("expected .value for diffEditor.diagonalFill light, got \(light)")
        }
    }

    func testColorTransformResolvesToTransformDescriptor() {
        // widget.shadow.dark is {factor:0.36, op:2, value:#000000} -> a
        // transform descriptor for the native renderer (not a collapsed value).
        let resolved = MonaColorRegistry.resolve("widget.shadow", variant: .dark)
        if case .transform(let t) = resolved {
            XCTAssertEqual(t.kind, 2)
            XCTAssertEqual(t.factor, 0.36)
        } else {
            XCTFail("expected .transform for widget.shadow, got \(resolved)")
        }
    }

    func testUnknownColorResolvesToNone() {
        XCTAssertEqual(MonaColorRegistry.resolve("no.such.color", variant: .dark), .none)
    }

    func testNeedsTransparencyFlagIsPresent() {
        // 41 of 431 colors declare needsTransparency == true.
        let transparent = MonaColorRegistry.colors.filter { $0.needsTransparency }
        XCTAssertEqual(transparent.count, 41)
    }

    // MARK: - 3. Icons: exactly 776, aliases resolve

    func testIconRegistryHasExactly776Entries() {
        XCTAssertEqual(MonaIconRegistry.icons.count, 776,
                       "the F1-R3 builtin icon table must contain exactly 776 icons")
    }

    func testIconIdsAreUniqueAndSourceOrdered() {
        let ids = MonaIconRegistry.ids
        XCTAssertEqual(Set(ids).count, 776, "icon ids must be unique")
        XCTAssertEqual(ids.first, "account")
        XCTAssertEqual(ids.last, "zoom-out")
    }

    func testIconCodepointResolvesForConcreteIcon() {
        // account -> codepoint eb99 -> Character U+EB99.
        XCTAssertEqual(MonaIconRegistry.codepointHex(for: "account"), "eb99")
        XCTAssertEqual(MonaIconRegistry.character(for: "account"),
                       Character(UnicodeScalar(0xEB99)!))
    }

    func testDeprecatedAliasResolvesThroughTarget() {
        // diff-insert is a deprecated alias of `add`.
        let diffInsert = MonaIconRegistry.definition(for: "diff-insert")!
        XCTAssertTrue(diffInsert.isAlias)
        XCTAssertEqual(diffInsert.deprecatedAliasOf, "add")
        // The alias resolves to the target's codepoint.
        let addTarget = MonaIconRegistry.codepointHex(for: "add")!
        XCTAssertEqual(MonaIconRegistry.codepointHex(for: "diff-insert"), addTarget)
        XCTAssertEqual(MonaIconRegistry.character(for: "diff-insert"),
                       MonaIconRegistry.character(for: "add"))
    }

    func testExactly34DeprecatedAliases() {
        XCTAssertEqual(MonaIconRegistry.aliases.count, 34,
                       "exactly 34 icons are deprecated aliases of another icon")
    }

    func testUnknownIconResolvesToNil() {
        XCTAssertNil(MonaIconRegistry.codepointHex(for: "no-such-icon"))
        XCTAssertNil(MonaIconRegistry.definition(for: "no-such-icon"))
    }

    func testIconModifiersAreDefined() {
        // Spin + the three alignment modifiers, matching Monaco's IconModifier.
        XCTAssertEqual(Set(MonaIconModifier.allCases.map { $0.rawValue }),
                       ["spin", "align-left", "align-right", "align-center"])
    }

    // MARK: - 4. Themes: exactly four, verbatim

    func testBuiltinThemesCountIsFour() {
        XCTAssertEqual(MonaBuiltinThemes.builtinThemes.count, 4)
        XCTAssertEqual(MonaBuiltinThemes.ids, ["vs", "vs-dark", "hc-black", "hc-light"])
    }

    func testBuiltinThemeBasesAndInheritance() {
        // All four builtins declare inherit == false (standalone definitions).
        for theme in MonaBuiltinThemes.builtinThemes {
            XCTAssertEqual(theme.base, theme.id, "builtin base must equal its id")
            XCTAssertFalse(theme.inherit, "builtins are standalone (inherit: false)")
        }
    }

    func testBuiltinHighContrastFlags() {
        XCTAssertTrue(MonaBuiltinThemes.theme(for: "hc-black")!.isHighContrast)
        XCTAssertTrue(MonaBuiltinThemes.theme(for: "hc-light")!.isHighContrast)
        XCTAssertFalse(MonaBuiltinThemes.theme(for: "vs")!.isHighContrast)
        XCTAssertFalse(MonaBuiltinThemes.theme(for: "vs-dark")!.isHighContrast)
    }

    func testBuiltinThemeEditorColorMapsTranscribed() {
        // vs has 6 editor colors; hc-black has 4.
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "vs")?.colors.count, 6)
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "vs-dark")?.colors.count, 6)
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "hc-black")?.colors.count, 4)
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "hc-light")?.colors.count, 4)
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "vs")?.colors["editor.background"], "#FFFFFE")
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "vs-dark")?.colors["editor.background"], "#1E1E1E")
    }

    func testBuiltinTokenRuleCounts() {
        // Pinned to the manifest rule counts.
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "vs")?.rules.count, 46)
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "vs-dark")?.rules.count, 45)
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "hc-black")?.rules.count, 36)
        XCTAssertEqual(MonaBuiltinThemes.theme(for: "hc-light")?.rules.count, 36)
    }

    func testTokenRuleScopeLookup() {
        // The default (empty-token) rule carries the theme background/foreground.
        let vs = MonaBuiltinThemes.theme(for: "vs")!
        let baseRule = vs.rule(for: "")!
        XCTAssertEqual(baseRule.background, "fffffe")
        XCTAssertEqual(baseRule.foreground, "000000")
        let comment = vs.rule(for: "comment")!
        XCTAssertEqual(comment.foreground, "008000")
    }

    // MARK: - 5. Codicon map + hash + provenance

    func testCodiconGlyphMapHas776Entries() {
        XCTAssertEqual(MonaCodiconMap.count, 776)
        XCTAssertEqual(MonaCodiconMap.glyphs.count, 776)
        XCTAssertEqual(Set(MonaCodiconMap.ids).count, 776)
    }

    func testCodiconExpectedFontHashAndSize() {
        // The contract-pinned canonical Codicon TTF SHA-256 (T1-R closure).
        XCTAssertEqual(MonaCodiconMap.expectedFontSHA256,
                       "cc2472e239e17062e7760af87f8f5997720cc0d94aa014a615c418baaf6333a8")
        XCTAssertEqual(MonaCodiconMap.expectedFontSizeBytes, 140956)
        XCTAssertEqual(MonaCodiconMap.fontFilename, "codicon.ttf")
    }

    func testCodiconFontBinaryIsIntentionallyNotBundled() {
        // The Core is Foundation-only and cannot load fonts; the binary is
        // acquired by the AppKit layer where it must match the pinned hash.
        XCTAssertFalse(MonaCodiconMap.fontBinaryBundled,
                       "the font binary must not be fabricated/bundled in the Core")
    }

    func testCodiconLicenseProvenanceIsPresent() {
        let p = MonaCodiconMap.provenance
        XCTAssertEqual(p.artworkAndFontLicense,
                       "CC BY 4.0; retain attribution, license reference and modification notice")
        XCTAssertEqual(p.gitLogoException,
                       "CC BY 3.0 attribution and license are retained when the bundled full font includes the Git Logo glyph")
        XCTAssertEqual(p.generatorAndCodeLicense, "MIT")
        XCTAssertTrue(p.monacoMitNotice.contains("MIT"))
    }

    func testCodiconGlyphLookup() {
        XCTAssertEqual(MonaCodiconMap.glyph(for: "account")?.codepointHex, "eb99")
        // Alias glyph resolves to its target's codepoint.
        XCTAssertEqual(MonaCodiconMap.glyph(for: "diff-insert")?.codepointHex,
                       MonaCodiconMap.glyph(for: "add")?.codepointHex)
    }

    // MARK: - 6. Theme registry: setTheme, high contrast, change events

    func testThemeRegistryDefaultsToVsDark() {
        let reg = MonaThemeRegistry()
        XCTAssertEqual(reg.currentThemeId, "vs-dark")
        XCTAssertFalse(reg.isHighContrast)
    }

    func testSetThemeSwitchesCurrentAndHighContrast() {
        let reg = MonaThemeRegistry()
        reg.setTheme("hc-black")
        XCTAssertEqual(reg.currentThemeId, "hc-black")
        XCTAssertTrue(reg.isHighContrast)
        reg.setTheme("vs")
        XCTAssertEqual(reg.currentThemeId, "vs")
        XCTAssertFalse(reg.isHighContrast)
    }

    func testSetThemeFiresChangeEventWithOldAndNewIds() {
        let reg = MonaThemeRegistry()
        var received: [MonaThemeChange] = []
        let token = reg.onDidChangeTheme { change in
            received.append(change)
        }
        reg.setTheme("hc-light")
        reg.setTheme("vs-dark")
        token.dispose()
        // A third setTheme after dispose must not deliver.
        reg.setTheme("vs")

        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[0], MonaThemeChange(oldThemeId: "vs-dark", newThemeId: "hc-light"))
        XCTAssertEqual(received[1], MonaThemeChange(oldThemeId: "hc-light", newThemeId: "vs-dark"))
    }

    func testSetSameThemeDoesNotFireChangeEvent() {
        let reg = MonaThemeRegistry()
        var fired = 0
        let token = reg.onDidChangeTheme { _ in fired += 1 }
        reg.setTheme("vs-dark")  // already current
        token.dispose()
        XCTAssertEqual(fired, 0, "setting the same theme must be a no-op (no event)")
    }

    func testSetUnknownThemeIsRejectedAndFiresNothing() {
        let reg = MonaThemeRegistry()
        var fired = 0
        let token = reg.onDidChangeTheme { _ in fired += 1 }
        reg.setTheme("no-such-theme")
        token.dispose()
        XCTAssertEqual(reg.currentThemeId, "vs-dark", "unknown theme leaves the current theme unchanged")
        XCTAssertEqual(fired, 0)
    }

    func testDefineCustomThemeRegistersAndActivates() {
        let reg = MonaThemeRegistry()
        let custom = MonaTokenTheme(
            id: "my-theme", base: "vs-dark", inherit: true,
            colors: ["editor.background": "#111111"], rules: [])
        reg.defineTheme(custom)
        XCTAssertTrue(reg.availableThemes.contains("my-theme"))
        reg.setTheme("my-theme")
        XCTAssertEqual(reg.currentThemeId, "my-theme")
        XCTAssertEqual(reg.currentTheme.colors["editor.background"], "#111111")
    }

    func testThemeRegistryExposesAllFourBuiltinThemes() {
        let reg = MonaThemeRegistry()
        for id in ["vs", "vs-dark", "hc-black", "hc-light"] {
            XCTAssertTrue(reg.availableThemes.contains(id), "builtin \(id) must be available")
        }
    }
}
