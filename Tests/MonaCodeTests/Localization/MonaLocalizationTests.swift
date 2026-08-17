// MonaLocalizationTests.swift
//
// P05-T007 — Generate 15 immutable UI localization profiles with 2120 messages.
//
// Verifies the N1 UI localization surface ported verbatim from
// monaco-editor-core@0.56.0 final NLS artifacts (the frozen N1-R manifest):
//   - Exactly 15 selectable profiles (en + 13 packaged + pseudo), exact-set.
//   - Each profile carries exactly 2120 message entries (180 modules / 2120
//     ordered keys), transcribed verbatim from the pinned MIT artifacts.
//   - The 2120 message identities (module path + key + flat index) are
//     retained in source-ordinal order.
//   - Profiles are immutable value types (repository-owned, not user-mutable).
//   - Message text is resolved through the explicit N1 localization profile
//     mechanism (`MonaCodeEnvironmentProfile` from P00-T007) — the SAME
//     mechanism P04-T012's announcement bridge already uses — NOT through
//     Foundation localization, the runtime system locale, or a network.
//   - N1 lookup semantics: profile string wins; null/absent falls back to the
//     English (en) source string; absence of both yields a typed
//     `MonaLocalizationError.missingMessage`.
//   - Monaco format rule: `/\{(\d+)\}/g` replacement using the FIRST captured
//     digit as the argument index (the `{10}` → args[1] quirk), with
//     string/number/boolean/null/absent stringification and the pseudo
//     transform (fullwidth brackets + doubled lowercase a/o/u/e/i).
//   - Monaco MIT provenance accompanies the generated tables.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import XCTest
import MonaCode

final class MonaLocalizationTests: XCTestCase {

    // MARK: - 1. Exactly 15 selectable profiles, exact-set

    func testSelectableProfileIdentifiersAreExact15Set() {
        let ids = MonaLocalization.selectableProfileIdentifiers
        XCTAssertEqual(ids.count, 15, "exactly 15 selectable N1 profiles")
        XCTAssertEqual(ids, [
            "en", "cs", "de", "es", "fr", "it",
            "ja", "ko", "pl", "pt-br", "ru", "tr",
            "zh-cn", "zh-tw", "pseudo",
        ], "the 15 ids must be the N1-R exact-set, in manifest order")
    }

    func testProfileTablesAreExactly15() {
        XCTAssertEqual(MonaLocalizationProfiles.profiles.count, 15,
                       "exactly 15 generated profile tables")
    }

    // MARK: - 2. Each profile carries exactly 2120 messages

    func testMessageCountIs2120() {
        XCTAssertEqual(MonaLocalization.messageCount, 2120)
        XCTAssertEqual(MonaLocalizationProfiles.identities.count, 2120,
                       "2120 message identities (180 modules / 2120 ordered keys)")
    }

    func testEveryProfileHasExactly2120Entries() {
        for profile in MonaLocalizationProfiles.profiles {
            XCTAssertEqual(profile.entries.count, 2120,
                           "profile \(profile.id) must carry exactly 2120 entries")
        }
    }

    func testProfileIdsCoverExact15Set() {
        let ids = Set(MonaLocalizationProfiles.profiles.map { $0.id })
        XCTAssertEqual(ids, Set(MonaLocalization.selectableProfileIdentifiers),
                       "generated profile ids must be the 15-id exact-set")
    }

    // MARK: - 3. Immutable (value types, repository-owned)

    func testProfilesAreImmutableValueTypes() {
        // Profile tables and identities are immutable `let` value types
        // ([String?] entries, value-type structs). Mutating after construction
        // is impossible because every field is a `let` on an immutable struct.
        let en = MonaLocalizationProfiles.profile(for: "en")
        XCTAssertNotNil(en)
        // Re-fetching yields equal value types (no shared mutable state).
        XCTAssertEqual(en, MonaLocalizationProfiles.profile(for: "en"))
    }

    // MARK: - 4. Resolved through the MonaCodeEnvironmentProfile mechanism

    func testDefaultProfileResolvesAsEnglish() throws {
        // `.default` is the N1 "en" profile (kind: default).
        let env = MonaCodeEnvironmentProfile.default
        let resolved = try MonaLocalization.resolve(0, profile: env)
        // Index 0 is "{0} ({1})" in the English source table.
        XCTAssertEqual(resolved, "{0} ({1})")
    }

    func testCustomProfileIdentifierResolvesThroughSameMechanism() throws {
        // A custom identifier "cs" resolves through the same
        // MonaCodeEnvironmentProfile mechanism as the announcement bridge.
        let cs = try MonaCodeEnvironmentProfile(identifier: "cs")
        let resolved = try MonaLocalization.resolve(0, profile: cs)
        // Index 0 is "{0} ({1})" in cs (untranslated placeholder header).
        XCTAssertEqual(resolved, "{0} ({1})")
    }

    func testPtBrAllNullFallsBackToEnglish() throws {
        // pt-br is the packaged-all-fallback profile: every entry is null and
        // falls back to the English source string.
        let ptBr = try MonaCodeEnvironmentProfile(identifier: "pt-br")
        let en = MonaCodeEnvironmentProfile.default
        for index in 0..<MonaLocalization.messageCount {
            let fallback = try MonaLocalization.resolve(index, profile: ptBr)
            let english = try MonaLocalization.resolve(index, profile: en)
            XCTAssertEqual(fallback, english,
                           "pt-br index \(index) must fall back to English")
        }
    }

    func testPtBrProfileEntriesAreAllNil() {
        let ptBr = MonaLocalizationProfiles.profile(for: "pt-br")
        XCTAssertNotNil(ptBr)
        XCTAssertEqual(ptBr!.entries.filter { $0 == nil }.count, 2120,
                       "pt-br must be 2120 nulls (all-fallback, not fabricated)")
    }

    func testEnglishProfileHasNoNullEntries() {
        let en = MonaLocalizationProfiles.profile(for: "en")
        XCTAssertNotNil(en)
        XCTAssertEqual(en!.entries.filter { $0 == nil }.count, 0,
                       "en must carry 2120 real strings (the source profile)")
    }

    func testPseudoResolvesToEnglishThenTransformsAtFormat() throws {
        // pseudo (runtime-transform) resolves to the English source message,
        // then _format applies the pseudo transform.
        let pseudo = try MonaCodeEnvironmentProfile(identifier: "pseudo")
        let resolved = try MonaLocalization.resolve(0, profile: pseudo)
        XCTAssertEqual(resolved, "{0} ({1})",
                       "pseudo resolves to the English source string")
    }

    func testMissingIndexThrowsTypedError() {
        let env = MonaCodeEnvironmentProfile.default
        XCTAssertThrowsError(try MonaLocalization.resolve(2120, profile: env)) { error in
            XCTAssertEqual(error as? MonaLocalizationError,
                           .missingMessage(index: 2120))
        }
    }

    // MARK: - 5. Message identities (module path + key + flat index)

    func testFirstAndLastMessageIdentity() {
        let first = MonaLocalizationProfiles.identities[0]
        XCTAssertEqual(first.index, 0)
        XCTAssertEqual(first.modulePath, "vs/base/browser/ui/actionbar/actionViewItems")
        XCTAssertEqual(first.key, "titleLabel")

        let last = MonaLocalizationProfiles.identities[MonaLocalization.messageCount - 1]
        XCTAssertEqual(last.index, MonaLocalization.messageCount - 1)
        XCTAssertEqual(last.modulePath, "vs/platform/workspace/common/workspace")
        XCTAssertEqual(last.key, "codeWorkspace")
    }

    func testIdentitiesAreSourceOrderedAndUnique() {
        let indices = MonaLocalizationProfiles.identities.map { $0.index }
        XCTAssertEqual(indices, Array(0..<2120), "identities are flat-index ordered 0..<2120")
        // Identities are unique by flat index (0..<2120). The same module/key
        // string may legitimately repeat across indices — Monaco permits a
        // module to define the same key string at multiple NLS call sites.
        XCTAssertEqual(Set(indices).count, 2120, "flat indices must be unique")
    }

    // MARK: - 6. Monaco format rule (raw UTF-16, {N} first-digit quirk)

    func testFormatNoArgsReturnsMessageUnchanged() {
        let en = MonaCodeEnvironmentProfile.default
        XCTAssertEqual(MonaLocalization.format("{0} ({1})", args: [], profile: en),
                       "{0} ({1})")
    }

    func testFormatStringArgReplacesPlaceholder() {
        let en = MonaCodeEnvironmentProfile.default
        XCTAssertEqual(MonaLocalization.format("Hello {0}", args: [.string("World")], profile: en),
                       "Hello World")
    }

    func testFormatFirstDigitIndexQuirk() {
        // Monaco uses `rest[0]` (first captured digit) as the arg index, so
        // {10} resolves to args[1], not args[10].
        let en = MonaCodeEnvironmentProfile.default
        XCTAssertEqual(
            MonaLocalization.format("{10}", args: [.string("a"), .string("b")], profile: en),
            "b"
        )
    }

    func testFormatAbsentArgStringifiesAsUndefined() {
        // arg === undefined → String(undefined) → "undefined".
        let en = MonaCodeEnvironmentProfile.default
        XCTAssertEqual(MonaLocalization.format("v={0}", args: [.absent], profile: en),
                       "v=undefined")
    }

    func testFormatNullArgStringifiesAsNull() {
        let en = MonaCodeEnvironmentProfile.default
        XCTAssertEqual(MonaLocalization.format("v={0}", args: [.null], profile: en),
                       "v=null")
    }

    func testFormatOtherValueLeavesPlaceholderUnchanged() {
        let en = MonaCodeEnvironmentProfile.default
        XCTAssertEqual(MonaLocalization.format("v={0}", args: [.other], profile: en),
                       "v={0}")
    }

    // MARK: - 7. Pseudo transform

    func testPseudoTransformWrapsAndDoublesVowels() throws {
        // _format: result = '［' + result.replace(/[aouei]/g, '$&$&') + '］'
        // (FF3B / FF3D fullwidth square brackets; doubles lowercase a/o/u/e/i.)
        let pseudo = try MonaCodeEnvironmentProfile(identifier: "pseudo")
        // "label" -> lowercase a,e -> "laabeel" -> wrapped "［laabeel］"
        XCTAssertEqual(MonaLocalization.format("label", args: [], profile: pseudo),
                       "［laabeel］")
        // No lowercase a/o/u/e/i → only wrapped.
        XCTAssertEqual(MonaLocalization.format("{0}", args: [], profile: pseudo),
                       "［{0}］")
    }

    // MARK: - 8. localize + localize2

    func testLocalizeResolvesAndFormats() throws {
        let en = MonaCodeEnvironmentProfile.default
        // Index 0 = "{0} ({1})"; with args ["a","b"] -> "a (b)".
        let result = try MonaLocalization.localize(0, args: [.string("a"), .string("b")], profile: en)
        XCTAssertEqual(result, "a (b)")
    }

    func testLocalize2ReturnsValueAndOriginal() throws {
        let en = MonaCodeEnvironmentProfile.default
        let result = try MonaLocalization.localize2(0, args: [.string("a"), .string("b")], profile: en)
        // For the en profile, the looked-up message IS the English original,
        // so value == original.
        XCTAssertEqual(result.value, "a (b)")
        XCTAssertEqual(result.original, "a (b)")
    }

    func testLocalize2TranslatedProfileValueAndOriginalDiffer() throws {
        let cs = try MonaCodeEnvironmentProfile(identifier: "cs")
        // Find an index where cs differs from en (index 1 = "input" in en).
        let result = try MonaLocalization.localize2(1, args: [], profile: cs)
        // value = formatted cs message; original = formatted en message.
        let enResult = try MonaLocalization.localize2(1, args: [], profile: .default)
        XCTAssertEqual(result.original, enResult.value,
                       "localize2.original is the formatted English source")
        // cs index 1 is "vstup" (Czech for "input").
        XCTAssertEqual(result.value, "vstup")
        XCTAssertEqual(result.original, "input")
    }

    // MARK: - 9. Provenance: Monaco MIT license notice accompanies the tables

    func testMonacoMitLicenseNoticeIsPresent() {
        let license = MonaLocalizationProfiles.monacoMitLicense
        XCTAssertTrue(license.contains("MIT License"), "MIT license header present")
        XCTAssertTrue(license.contains("Microsoft Corporation"),
                       "Microsoft copyright notice present")
    }

    func testProfileTablesCarrySourceSha256() {
        // Every generated profile table carries its pinned source SHA-256
        // (acceptance C10: "generated table hashes … are exact-set release
        // resources").
        for profile in MonaLocalizationProfiles.profiles {
            XCTAssertEqual(profile.sha256.count, 64,
                           "profile \(profile.id) must carry a 64-hex SHA-256")
        }
        // Spot-check the en and pt-br hashes against the N1-R manifest.
        let en = MonaLocalizationProfiles.profile(for: "en")
        XCTAssertEqual(en?.sha256,
                       "151c64af095d6b49f349ab56544cb6d4ada9195de7c30d2c7b2743a3db7d24c6")
        let ptBr = MonaLocalizationProfiles.profile(for: "pt-br")
        XCTAssertEqual(ptBr?.sha256,
                       "dd586f64a76f072ca7f301e753af5e34bc4efe97d1e84f5f3ed4283b487147d8")
    }

    func testProfileSelectionIndependentFromRuntimeLocale() throws {
        // The profile is selected ONLY from the explicit option; two
        // environments with the SAME runtime locale but DIFFERENT explicit
        // profiles resolve differently. This mirrors P00-T007's invariant.
        let locale = MonaRuntimeLocale()
        let envEn = try MonaCodeEnvironment(runtimeLocale: locale, profileIdentifier: "en")
        let envCs = try MonaCodeEnvironment(runtimeLocale: locale, profileIdentifier: "cs")
        XCTAssertNotEqual(envEn.profile, envCs.profile,
                           "different explicit profiles despite same locale")
        // cs index 2 ("Match Case" in en) is "Rozlišovat malá a velká písmena".
        let enMsg = try MonaLocalization.resolve(2, profile: envEn.profile)
        let csMsg = try MonaLocalization.resolve(2, profile: envCs.profile)
        XCTAssertEqual(enMsg, "Match Case")
        XCTAssertEqual(csMsg, "Rozlišovat malá a velká písmena")
        XCTAssertNotEqual(enMsg, csMsg,
                          "profile drives the text, not the runtime locale")
    }
}
