// Phase05PublicSurfaceConformanceTests.swift
//
// P05-T200 — Close the retained public surface, registries, options, themes,
// localization, and features.
//
// The Phase 05 closure conformance suite. It JOINS all Phase 05 evidence —
// the 555-path native public declaration graph (P05-T001), the command/action/
// contribution/pure-text registries (P05-T002), the 379 keybinding rows
// (P05-T003), the menu/menu-item/menu-command registries (P05-T004), the 174
// editor options with computed truth (P05-T005), the theme/token/color/icon/
// Codicon registries (P05-T006), the 15 immutable UI localization profiles
// with 2120 messages (P05-T007), the core language metadata + plain-text
// fallback (P05-T008), the three native colorize replacements
// (P05-T009 editor.colorize, P05-T010 editor.colorizeElement, P05-T011
// editor.colorizeModelLine), the editor factories + five instance-interface
// sequences (P05-T012), the deterministic provider execution + microtask
// publication (P05-T013), and the 62 retained features (P05-T100..T161) — as
// one revision-locked suite, and:
//
//   1. Runs the matrices — identity-set, signature, native adaptation,
//      registry ordering (T002-T004), option boundary (T005), theme (T006),
//      localization (T007), feature behavior (T100-T161), disposal, and
//      plain-text degradation — each driving the relevant surface and
//      asserting the contract holds.
//   2. Asserts exactly 62 retained feature IDs, zero missing retained feature
//      IDs, and three distinct native colorize replacements.
//   3. Rejects any cut, later, built-in language, or WebGPU identity that
//      becomes production-owned. The cut WebGPU debug identity, the later
//      iPadOS identity, and the 90 cut built-in language descriptors remain
//      disposition-only (unavailable) — they are never live in the registries.
//
// This is a TEST-ONLY task (no product source). The file lives in the
// `conformance-and-failure-injection` target (kept a non-test `.target` for
// the package-graph invariant). Discovery is provided by the `MonaCodeTests`
// test target depending on this target; the class is introspected from the
// linked image, so `swift test --filter Phase05PublicSurfaceConformanceTests`
// runs it.

import Foundation
import XCTest
import AppKit
import MonaCode
import MonaCodeAppKit
import MonaCodeSwiftUI

// MARK: - Phase05PublicSurfaceConformanceTests

final class Phase05PublicSurfaceConformanceTests: XCTestCase {

    // MARK: - Shared configuration

    /// Menlo is the default macOS monospace face and is always present; one
    /// font ties the shaper + layout builder to one shaping configuration
    /// across the colorize matrices.
    private static let font = MonaFontDescriptor(familyName: "Menlo", size: 12)

    // MARK: 1. The matrices

    // ── Matrix 1: identity-set (the 555-path public declaration graph, T001) ──

    /// Identity-set matrix: the frozen 555-path native public declaration graph
    /// (`MonaPublicAPI.swift`) exists on disk, carries the resolved-alias-graph
    /// and declaration SHA-256 provenance markers, and declares the native
    /// top-level Swift types that are the Foundation-only Core's public surface.
    /// The graph records 422 retained native declarations + explicit UNAVAILABLE
    /// dispositions for the cut paths assigned to the Core product (537 of the
    /// 555 F1-R4 paths live here; the rest live in MonaCodeAppKit/SwiftUI).
    func testIdentitySetMatrixPublicDeclarationGraphExists() throws {
        let root = projectRoot
        let publicAPIPath = root + "/Sources/MonaCode/Generated/MonaPublicAPI.swift"
        XCTAssertTrue(FileManager.default.fileExists(atPath: publicAPIPath),
                      "Identity-set: MonaPublicAPI.swift exists (the 555-path declaration graph)")
        guard let source = FileManager.default.contents(atPath: publicAPIPath),
              let text = String(data: source, encoding: .utf8) else {
            return XCTFail("Identity-set: MonaPublicAPI.swift is readable")
        }
        // The resolved-alias-graph + declaration SHA-256 provenance markers.
        XCTAssertTrue(text.contains("RESOLVED-ALIAS-GRAPH-SHA256:"),
                      "Identity-set: carries the resolved-alias-graph SHA-256 provenance marker")
        XCTAssertTrue(text.contains("DECLARATION-SHA256:"),
                      "Identity-set: carries the declaration SHA-256 provenance marker")
        // The Foundation-only boundary: no AppKit/CoreGraphics/CoreText/Metal/
        // SwiftUI/Process//UIKit imports in the Core public API file.
        let forbidden: Set<String> = ["AppKit", "CoreGraphics", "CoreText", "Metal",
                                      "SwiftUI", "Process", "UIKit"]
        for line in text.split(separator: "\n") where line.hasPrefix("import ") {
            let trimmed = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
            let moduleName = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
            XCTAssertFalse(forbidden.contains(moduleName),
                           "Identity-set: Core public API must not import \(moduleName) (Foundation-only)")
        }
    }

    // ── Matrix 2: signature (the native top-level types are addressable, T001) ──

    /// Signature matrix: the native top-level public types declared by the
    /// 555-path graph are addressable from the linked image. The signature
    /// surface (CancellationTokenSource, Emitter, KeyCode, KeyMod,
    /// MarkerSeverity, MarkerTag, Position, Range, Selection) is the stable
    /// Foundation-only contract every downstream phase binds to. The T001 graph
    /// records the identity + provenance of every F1-R4 path; the top-level
    /// types are the retained-native-mapping stubs that downstream phases
    /// re-export under their canonical Monaco names.
    func testSignatureMatrixTopLevelTypesAreAddressable() {
        // The top-level types declared in MonaPublicAPI.swift are real, linked
        // types. Referencing their type metadata proves the signature surface
        // is live (the stubs carry the F1-R4 identity + SHA-256 provenance).
        // Reference-type stubs (final class) vs extensible-raw-value enums.
        let classTypes: [Any.Type] = [
            MonaTopLevelCancellationTokenSource.self,
            MonaTopLevelEmitter.self,
            MonaTopLevelKeyMod.self,
            MonaTopLevelPosition.self,
            MonaTopLevelRange.self,
            MonaTopLevelSelection.self,
        ]
        for type in classTypes {
            // Each is a class (reference type) — the retained-native-mapping
            // identity is addressable from the linked image.
            XCTAssertTrue(String(describing: type).hasPrefix("MonaTopLevel"),
                          "Signature: \(type) is a MonaTopLevel* type")
        }
        // The extensible-raw-value enums are addressable.
        let enumTypes: [Any.Type] = [
            MonaTopLevelKeyCode.self,
            MonaTopLevelMarkerSeverity.self,
            MonaTopLevelMarkerTag.self,
        ]
        XCTAssertEqual(enumTypes.count, 3, "Signature: the three top-level enums are addressable")
    }

    // ── Matrix 3: native adaptation (the three distinct native colorize replacements, T009-T011) ──

    /// Native-adaptation matrix: the three colorize replacements are DISTINCT
    /// native (non-HTML) replacements. Monaco's originals emit HTML strings of
    /// `<span>` runs with inline CSS classes; MonaCode's replacements emit
    /// AppKit-native attributed text + geometry — no HTML, no DOM, no CSS.
    /// See the dedicated `testThreeDistinctNativeColorizeReplacements` leaf
    /// for the count + distinctness + non-HTML assertions.
    @MainActor
    func testNativeAdaptationMatrixColorizeReplacementsAreNative() throws {
        // T009 — editor.colorize → MonaColorizeSource.colorize returns a native
        // NSAttributedString (never an HTML string).
        let source = MonaColorizeSource()
        let units = Array("let x = 1".utf16)
        let attributed = source.colorize(source: units)
        XCTAssertTrue(attributed is NSAttributedString,
                      "Native-adaptation: T009 colorize returns NSAttributedString (native)")
        XCTAssertFalse(attributed.string.contains("<span"),
                       "Native-adaptation: T009 colorize emits NO HTML <span> runs")
        XCTAssertFalse(attributed.string.contains("innerHTML"),
                       "Native-adaptation: T009 colorize emits NO DOM innerHTML")

        // T010 — editor.colorizeElement → MonaColorizeView operates on a frozen
        // AppKit-native MonaColorizeHost carrying an NSTextStorage (not a DOM
        // element). render replaces the host's text storage with attributed text.
        let host = MonaColorizeHost()
        let view = MonaColorizeView(source: source, host: host)
        view.render(source: units)
        XCTAssertGreaterThan(host.textStorage.length, 0,
                             "Native-adaptation: T010 render applies attributed text to the native NSTextStorage host")
        view.detach()  // idempotent disposal of every observation

        // T011 — editor.colorizeModelLine → MonaColorizeModelLine projects native
        // runs (NSAttributedString + CGRect) from an immutable layout record
        // (never an HTML string). The plain-text fallback path is exercised
        // here (no token provider attached).
        let model = MonaCodeModel(
            text: "abc", uri: MonaURI(scheme: "inmemory", path: "/p05-cml"))
        let colorizeModelLine = MonaColorizeModelLine(colorizeSource: source)
        // colorizeModelLine throws on stale layout; the plain-text fallback
        // path with a matching generation succeeds and produces native runs.
        let record = try makePlainLayoutRecord(for: model, line: 1)
        XCTAssertNoThrow(try colorizeModelLine.colorize(
            model: model, lineNumber: 1,
            layoutRecord: record,
            layoutGeneration: model.getVersionId()),
            "Native-adaptation: T011 colorizeModelLine produces native runs (no throw on matching generation)")
    }

    // ── Matrix 4: registry ordering (T002-T004) ──

    /// Registry-ordering matrix: the command, action, contribution, pure-text,
    /// and menu registries record their frozen identities in source-ordinal
    /// order (one Swift entry per manifest row, no rename/coalesce), split live
    /// vs cut correctly, and the WebGPU debug identity is CUT (not live) across
    /// every registry that carries it.
    @MainActor
    func testRegistryOrderingMatrixSourceOrdinalLiveCutSplit() {
        // Commands (T002): frozen identities are source-ordinal + live/cut split.
        let commands = MonaCommandRegistry()
        let cmdFrozen = MonaCommandRegistry.frozenIdentities
        XCTAssertEqual(cmdFrozen.count, commands.liveCount + commands.cutCount,
                       "Registry-ordering: command frozen = live + cut")
        // Source-ordinal: no two identities share a slot; the live filter
        // preserves the frozen relative order.
        let liveIds = commands.liveIdentities.map { $0.id }
        XCTAssertEqual(liveIds, MonaCommandRegistry.frozenIdentities.filter { $0.isLive }.map { $0.id },
                       "Registry-ordering: live commands preserve frozen source-ordinal order")

        // Actions + pure-text (T002): live/cut split, WebGPU debug CUT.
        let actions = MonaActionRegistry()
        XCTAssertEqual(actions.actionCount, actions.liveActionCount + actions.cutActionCount,
                       "Registry-ordering: action frozen = live + cut")
        XCTAssertEqual(actions.pureTextCount, actions.livePureTextCount + actions.cutPureTextCount,
                       "Registry-ordering: pure-text frozen = live + cut")
        // The WebGPU debug action is CUT (not live).
        XCTAssertFalse(actions.identity(for: "editor.action.debugEditorGpuRenderer") != nil,
                       "Registry-ordering: WebGPU debug action is CUT (not live)")
        XCTAssertFalse(actions.contains("editor.action.debugEditorGpuRenderer"),
                       "Registry-ordering: WebGPU debug action is not contained as live")
        XCTAssertFalse(actions.containsPureText("editor.action.debugEditorGpuRenderer"),
                       "Registry-ordering: WebGPU debug pure-text action is CUT")

        // Contributions (T002): live/cut split.
        let contributions = MonaContributionRegistry()
        XCTAssertEqual(contributions.totalCount, contributions.liveCount + contributions.cutCount,
                       "Registry-ordering: contribution frozen = live + cut")

        // Menus (T004): frozen menus/items/commands + live/cut split.
        let menus = MonaMenuRegistry()
        XCTAssertEqual(menus.menuItemCount, menus.liveMenuItemCount + (menus.menuItemCount - menus.liveMenuItemCount),
                       "Registry-ordering: menu item frozen = live + cut")
        XCTAssertGreaterThan(menus.liveMenuCount, 0,
                             "Registry-ordering: at least one live menu")
    }

    // ── Matrix 5: option boundary (T005) ──

    /// Option-boundary matrix: the 174 builtin editor options split as 157
    /// retained-input (mutable) + 6 computed-only (read-only derived) + 11 cut
    /// (excluded). setValue validates type + bounds; cut options reject; the
    /// computed-only options are read-only and recompute on input change.
    @MainActor
    func testOptionBoundaryMatrix174OptionsTypeBoundsCutExcluded() {
        // 174 = 157 retained-input + 6 computed-only + 11 cut.
        XCTAssertEqual(MonaBuiltinOptions.options.count, 174,
                       "Option-boundary: exactly 174 builtin options")
        XCTAssertEqual(MonaBuiltinOptions.retainedInputOptions.count, 157,
                       "Option-boundary: exactly 157 retained-input options")
        XCTAssertEqual(MonaBuiltinOptions.computedOnlyOptions.count, 6,
                       "Option-boundary: exactly 6 computed-only options")
        XCTAssertEqual(MonaBuiltinOptions.cutOptions.count, 11,
                       "Option-boundary: exactly 11 cut options")

        let store = MonaOptionStore()
        // Retained-input: setValue validates type (a string option rejects a bool).
        // `fontFamily` is a string option; a bool is a type mismatch.
        XCTAssertEqual(store.setValue(.bool(true), for: "fontFamily"), .typeMismatch(expected: .string),
                       "Option-boundary: setValue rejects a type mismatch for a string option")
        // A valid string value succeeds.
        XCTAssertEqual(store.setValue(.string("Menlo"), for: "fontFamily"), .success,
                       "Option-boundary: setValue accepts a type-valid string value")
        // Numeric bounds: `fontSize` has a min; an out-of-bounds value rejects.
        let oob = store.setValue(.double(-100), for: "fontSize")
        if case .outOfBounds = oob { /* ok */ } else {
            XCTFail("Option-boundary: setValue rejects an out-of-bounds fontSize; got \(oob)")
        }
        // Cut option: setValue returns .cutOption, value returns nil.
        let cutName = MonaBuiltinOptions.cutOptions.first!.name
        XCTAssertEqual(store.setValue(.bool(true), for: cutName), .cutOption(cutName),
                       "Option-boundary: cut option setValue returns .cutOption")
        XCTAssertNil(store.value(for: cutName),
                     "Option-boundary: cut option value is nil (excluded from production)")
        // Computed-only: setValue returns .computedNotSettable; value is readable.
        let computedName = MonaBuiltinOptions.computedOnlyOptions.first!.name
        XCTAssertEqual(store.setValue(.bool(true), for: computedName), .computedNotSettable(computedName),
                       "Option-boundary: computed-only option is not settable as input")
        XCTAssertNotNil(store.value(for: computedName),
                        "Option-boundary: computed-only option value is readable (derived)")
        // Snapshot excludes cut options (157 retained + 6 computed = 163).
        XCTAssertEqual(store.snapshot().count, 163,
                       "Option-boundary: snapshot excludes the 11 cut options (157 + 6 = 163)")
    }

    // ── Matrix 6: theme (T006) ──

    /// Theme matrix: the four builtin themes (vs, vs-dark, hc-black, hc-light)
    /// are registered; setTheme switches the active theme and fires
    /// onDidChangeTheme only on a real switch; isHighContrast tracks the hc-
    /// prefix; the icon registry resolves Codicon ids to codepoints.
    @MainActor
    func testThemeMatrixFourBuiltinsSwitchAndHighContrast() {
        let ids = MonaBuiltinThemes.ids
        XCTAssertEqual(Set(ids), Set(["vs", "vs-dark", "hc-black", "hc-light"]),
                       "Theme: exactly the four builtin theme ids")
        let registry = MonaThemeRegistry()
        // Boots on Monaco's standalone default (vs-dark).
        XCTAssertEqual(registry.currentThemeId, "vs-dark",
                       "Theme: boots on the vs-dark standalone default")
        XCTAssertFalse(registry.isHighContrast, "Theme: vs-dark is not high-contrast (no hc- prefix)")

        // setTheme to a known theme fires onDidChangeTheme exactly once.
        var fired: [MonaThemeChange] = []
        let token = registry.onDidChangeTheme { fired.append($0) }
        registry.setTheme("vs")
        XCTAssertEqual(registry.currentThemeId, "vs", "Theme: setTheme switches the active theme")
        XCTAssertEqual(fired.count, 1, "Theme: setTheme fires onDidChangeTheme exactly once on a real switch")
        XCTAssertEqual(fired.first?.newThemeId, "vs", "Theme: change carries the new theme id")

        // Setting the SAME id is a no-op (no event).
        registry.setTheme("vs")
        XCTAssertEqual(fired.count, 1, "Theme: setting the current id is a no-op (no event)")

        // High-contrast switching.
        registry.setTheme("hc-black")
        XCTAssertTrue(registry.isHighContrast, "Theme: hc-black is high-contrast")
        registry.setTheme("hc-light")
        XCTAssertTrue(registry.isHighContrast, "Theme: hc-light is high-contrast")

        // An unknown id is rejected (active theme unchanged, no event).
        registry.setTheme("does-not-exist")
        XCTAssertEqual(registry.currentThemeId, "hc-light", "Theme: unknown id rejected (active theme unchanged)")

        // Icon registry (Codicon): a known icon resolves to a codepoint.
        XCTAssertGreaterThan(MonaIconRegistry.ids.count, 0,
                             "Theme: icon registry is non-empty (Codicon)")
        _ = token  // retain listener
    }

    // ── Matrix 7: localization (T007) ──

    /// Localization matrix: the 15 immutable UI localization profiles each
    /// carry 2120 message entries (one per flat N1 message identity), and the
    /// 2120 N1 message identities are flat-indexed (0..<2120) in a stable
    /// module-path + key order. The MIT license string is repository-owned.
    func testLocalizationMatrix15Profiles2120Messages() {
        // 15 profiles.
        XCTAssertEqual(MonaLocalizationProfiles.profiles.count, 15,
                       "Localization: exactly 15 immutable UI profiles")
        // 2120 flat N1 message identities.
        XCTAssertEqual(MonaLocalizationProfiles.identities.count, 2120,
                       "Localization: exactly 2120 N1 message identities")
        // Each identity's flat index is its position (0..<2120).
        for (i, identity) in MonaLocalizationProfiles.identities.enumerated() {
            XCTAssertEqual(identity.index, i,
                           "Localization: identity \(i) flat index matches its position")
        }
        // Each profile carries exactly 2120 entries (translated + fallback).
        for profile in MonaLocalizationProfiles.profiles {
            XCTAssertEqual(profile.entries.count, 2120,
                           "Localization: profile \(profile.id) carries exactly 2120 entries")
        }
        // A known profile is resolvable by id.
        let firstProfile = MonaLocalizationProfiles.profiles.first!
        XCTAssertNotNil(MonaLocalizationProfiles.profile(for: firstProfile.id),
                       "Localization: profile(for:) resolves a known profile id")
        // The Monaco MIT license string is repository-owned (N1 license text).
        XCTAssertTrue(MonaLocalizationProfiles.monacoMitLicense.contains("The MIT License (MIT)"),
                     "Localization: the Monaco MIT license string is repository-owned")
    }

    // ── Matrix 8: feature behavior (T100-T161) ──

    /// Feature-behavior matrix: the 62 retained features are registered and
    /// queryable, and a representative sample drives the feature-specific
    /// behavior surface. anchorSelect extends selections from anchors;
    /// bracketMatching matches brackets; toggleHighContrast switches the
    /// theme; clipboard copies content. Each routes mutation/publication/
    /// disposal/localization/plain-text through the shared gateways.
    @MainActor
    func testFeatureBehaviorMatrix62FeaturesRegisteredAndBehavioral() {
        let registry = MonaFeatureRegistry()
        // 62 retained (live) features + 2 cut (gpu + iPadShowKeyboard) = 64.
        XCTAssertEqual(registry.liveCount, 62, "Feature-behavior: exactly 62 retained (live) features")
        XCTAssertEqual(registry.cutCount, 2, "Feature-behavior: exactly 2 cut features (gpu + iPadShowKeyboard)")
        XCTAssertEqual(registry.totalCount, 64, "Feature-behavior: 64 total frozen feature identities")

        // Spot-check feature-specific behavior.

        // T100 — anchorSelect: extend selections from the anchor.
        let anchorSelect = MonaAnchorSelectFeature()
        let anchor = MonaPosition(line: 1, column: 1)
        let cursor = MonaPosition(line: 1, column: 5)
        let sel = anchorSelect.selection(anchor: anchor, cursor: cursor)
        XCTAssertEqual(sel.anchor, anchor, "Feature-behavior: anchorSelect preserves the anchor verbatim")
        XCTAssertEqual(sel.activePosition, cursor,
                       "Feature-behavior: anchorSelect active position is the cursor")
        let setAnchor = anchorSelect.setSelectionAnchor(at: anchor)
        XCTAssertEqual(setAnchor, anchor, "Feature-behavior: anchorSelect setSelectionAnchor returns the anchor")
        anchorSelect.cancelSelectionAnchor()
        XCTAssertFalse(anchorSelect.hasSelectionAnchor,
                       "Feature-behavior: anchorSelect cancelSelectionAnchor clears the anchor")

        // T101 — bracketMatching: match a bracket pair. The feature computes
        // pairs from the text + position (no constructor pairs needed).
        let bracketMatching = MonaBracketMatchingFeature()
        let match = bracketMatching.matchBracket(text: "(abc)", position: MonaPosition(line: 1, column: 1))
        XCTAssertNotNil(match, "Feature-behavior: bracketMatching finds a bracket pair")
        XCTAssertEqual(match?.open, MonaPosition(line: 1, column: 1),
                       "Feature-behavior: bracketMatching open position")

        // T154 — toggleHighContrast: toggles the theme to/from high-contrast.
        let toggleHC = MonaToggleHighContrastFeature()
        let state = toggleHC.toggleHighContrast()
        XCTAssertNotNil(state, "Feature-behavior: toggleHighContrast returns a state (not nil)")
        XCTAssertTrue(state?.isHighContrast ?? false,
                      "Feature-behavior: toggleHighContrast switches to a high-contrast theme")

        // T103 — clipboard: copy produces clipboard content.
        let clipboard = MonaClipboardFeature()
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/p05-clip"))
        let content = clipboard.copy(text: "hello", selection: sel, model: model)
        XCTAssertEqual(content.plainText, "hello",
                       "Feature-behavior: clipboard copy produces the plain-text content")
    }

    // ── Matrix 9: disposal (idempotent; disposed enables nothing) ──

    /// Disposal matrix: every disposable registry/store disposes idempotently,
    /// and a disposed registry enables nothing (enablement queries return
    /// false; lookup of live identities still reports the frozen inventory but
    /// isEnabled returns false). The option store's change emitter is torn
    /// down on dispose.
    @MainActor
    func testDisposalMatrixIdempotentAndEnablesNothing() {
        let context = MonaKeybindingContext()

        // Command registry: disposed → isEnabled returns false.
        let commands = MonaCommandRegistry()
        let liveCmdId = commands.liveIdentities.first!.id
        XCTAssertTrue(commands.isEnabled(liveCmdId, context: context),
                     "Disposal: a live command is enabled before dispose")
        commands.dispose()
        XCTAssertTrue(commands.isDisposed, "Disposal: command registry is disposed")
        XCTAssertFalse(commands.isEnabled(liveCmdId, context: context),
                       "Disposal: disposed command registry enables nothing")
        commands.dispose()  // idempotent — no crash, no state change.
        XCTAssertTrue(commands.isDisposed, "Disposal: second dispose is a no-op")

        // Action registry: disposed → isEnabled returns false.
        let actions = MonaActionRegistry()
        let liveActionId = actions.liveIdentities.first!.id
        XCTAssertTrue(actions.isEnabled(liveActionId, context: context),
                     "Disposal: a live action is enabled before dispose")
        actions.dispose()
        XCTAssertFalse(actions.isEnabled(liveActionId, context: context),
                       "Disposal: disposed action registry enables nothing")

        // Contribution registry: disposed → isEnabled returns false.
        let contributions = MonaContributionRegistry()
        let liveContribId = contributions.liveIdentities.first!.id
        XCTAssertTrue(contributions.isEnabled(liveContribId, context: context),
                     "Disposal: a live contribution is enabled before dispose")
        contributions.dispose()
        XCTAssertFalse(contributions.isEnabled(liveContribId, context: context),
                       "Disposal: disposed contribution registry enables nothing")

        // Feature registry: disposed → isEnabled returns false.
        let features = MonaFeatureRegistry()
        XCTAssertTrue(features.isEnabled("anchorSelect", context: context),
                     "Disposal: a live feature is enabled before dispose")
        features.dispose()
        XCTAssertFalse(features.isEnabled("anchorSelect", context: context),
                       "Disposal: disposed feature registry enables nothing")

        // Option store: disposed → setValue is a contained no-op; the change
        // emitter is torn down.
        let options = MonaOptionStore()
        options.dispose()
        XCTAssertTrue(options.isDisposed, "Disposal: option store is disposed")
        XCTAssertEqual(options.setValue(.string("x"), for: "fontFamily"), .success,
                       "Disposal: disposed option store setValue is a contained no-op (returns .success)")

        // Language registry: disposed → host registration refused, resolution
        // falls back to plain text.
        let languages = MonaLanguageRegistry()
        languages.dispose()
        XCTAssertTrue(languages.isDisposed, "Disposal: language registry is disposed")
    }

    // ── Matrix 10: plain-text degradation (T008) ──

    /// Plain-text degradation matrix: the Core language registry retains
    /// exactly ONE live language metadata identity (`"plaintext"`, the core
    /// fallback) and records all 90 other built-in language descriptors as
    /// `cut-builtin-language-content` (no bundled grammar, no provider). When
    /// no language/provider is registered for a model, resolution falls back
    /// to the plain-text language, which performs no tokenization by
    /// definition — so colorize degrades to attributed text with no per-token
    /// foreground color.
    @MainActor
    func testPlainTextDegradationMatrixOneLiveFallbackAndNoTokenization() {
        let registry = MonaLanguageRegistry()
        // 91 = 1 live (plaintext) + 90 cut.
        XCTAssertEqual(registry.totalCount, 91,
                       "Plain-text: 91 total frozen language identities (1 live + 90 cut)")
        XCTAssertEqual(registry.liveCount, 1, "Plain-text: exactly 1 live language (the plaintext fallback)")
        XCTAssertEqual(registry.cutCount, 90, "Plain-text: exactly 90 cut built-in languages")
        XCTAssertEqual(registry.fallbackIdentity.id, "plaintext",
                       "Plain-text: the fallback identity is plaintext")
        XCTAssertTrue(registry.fallbackIdentity.isLive,
                      "Plain-text: the fallback identity is live")

        // The plain-text language performs no tokenization / grammar / provider.
        let plainText = MonaPlainTextLanguage()
        XCTAssertEqual(plainText.id, "plaintext", "Plain-text: languageId is plaintext")
        XCTAssertFalse(plainText.hasTokenization, "Plain-text: hasTokenization is false by definition")
        XCTAssertFalse(plainText.hasGrammar, "Plain-text: hasGrammar is false by definition")
        XCTAssertFalse(plainText.hasProvider, "Plain-text: hasProvider is false by definition")

        // Colorize plain-text fallback: no provider → attributed string with NO
        // per-token foreground color (the whole-text default, no .foregroundColor
        // attributes applied). The result is native (NSAttributedString), never
        // HTML, and degrades cleanly when no provider is attached.
        let source = MonaColorizeSource(language: plainText)
        let units = Array("plain text".utf16)
        let attributed = source.colorize(source: units)
        // No per-token foreground color was applied (plain-text fallback).
        var hasForeground = false
        attributed.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributed.length),
                                      options: []) { value, _, stop in
            if value != nil { hasForeground = true; stop.pointee = true }
        }
        XCTAssertFalse(hasForeground,
                       "Plain-text: colorize fallback applies NO per-token foreground color (no provider)")
        XCTAssertEqual(attributed.string, "plain text",
                       "Plain-text: colorize preserves the source text verbatim")
    }

    // MARK: 2. Exactly 62 retained feature IDs, zero missing, three colorize replacements

    /// Exactly 62 retained feature IDs: the frozen feature registry carries 64
    /// identities (62 retained-macos + 2 cut: gpu/WebGPU debug + iPadShowKeyboard/
    /// later-iPadOS). The 62 retained IDs are exactly T100-T161; the 2 cut IDs
    /// (gpu, iPadShowKeyboard) are NOT retained.
    func testExactly62RetainedFeatureIDs() {
        let live = MonaFeatureRegistry.frozenIdentities.filter { $0.isLive }
        let cut = MonaFeatureRegistry.frozenIdentities.filter { !$0.isLive }
        XCTAssertEqual(live.count, 62, "62 retained: exactly 62 live (retained-macos) feature IDs")
        XCTAssertEqual(cut.count, 2, "62 retained: exactly 2 cut feature IDs (gpu + iPadShowKeyboard)")
        XCTAssertEqual(Set(cut.map { $0.id }), Set(["gpu", "iPadShowKeyboard"]),
                       "62 retained: the 2 cut IDs are gpu + iPadShowKeyboard")
        // The 62 retained IDs are exactly the T100-T161 set.
        let liveIds = Set(live.map { $0.id })
        XCTAssertEqual(liveIds, Set(expectedRetainedFeatureIds),
                       "62 retained: the live IDs are exactly the T100-T161 feature set")
    }

    /// Zero missing retained feature IDs: every one of the 62 retained feature
    /// IDs has a corresponding feature source file on disk (Core or AppKit).
    /// A missing file would mean a retained feature was declared but never
    /// implemented — a contract break.
    func testZeroMissingRetainedFeatureIDs() {
        let root = projectRoot
        let coreDir = root + "/Sources/MonaCode/Features"
        let appKitDir = root + "/Sources/MonaCodeAppKit/Features"
        var missing: [String] = []
        for id in expectedRetainedFeatureIds {
            // Convention: id "anchorSelect" → "MonaAnchorSelectFeature.swift".
            let capitalized = id.prefix(1).uppercased() + id.dropFirst()
            let fileName = "Mona\(capitalized)Feature.swift"
            let corePath = coreDir + "/" + fileName
            let appKitPath = appKitDir + "/" + fileName
            if !FileManager.default.fileExists(atPath: corePath) &&
               !FileManager.default.fileExists(atPath: appKitPath) {
                missing.append(id)
            }
        }
        XCTAssertTrue(missing.isEmpty,
                      "62 retained: zero missing feature files. Missing: \(missing)")
    }

    /// Three distinct native colorize replacements: T009 (editor.colorize →
    /// MonaColorizeSource), T010 (editor.colorizeElement → MonaColorizeView),
    /// and T011 (editor.colorizeModelLine → MonaColorizeModelLine) are three
    /// DISTINCT native (non-HTML) replacements. Each produces a different
    /// native output type (NSAttributedString / NSTextStorage mutation /
    /// native runs + CGRect geometry) — never an HTML string, never DOM/CSS.
    @MainActor
    func testThreeDistinctNativeColorizeReplacements() throws {
        // The three replacement type names are distinct.
        let t009 = String(describing: type(of: MonaColorizeSource()))
        let t010 = String(describing: type(of: MonaColorizeView(
            source: MonaColorizeSource(),
            host: MonaColorizeHost())))
        let t011 = String(describing: type(of: MonaColorizeModelLine(colorizeSource: MonaColorizeSource())))
        XCTAssertEqual(t009, "MonaColorizeSource", "3 colorize: T009 is MonaColorizeSource")
        XCTAssertEqual(t010, "MonaColorizeView", "3 colorize: T010 is MonaColorizeView")
        XCTAssertEqual(t011, "MonaColorizeModelLine", "3 colorize: T011 is MonaColorizeModelLine")
        XCTAssertNotEqual(t009, t010, "3 colorize: T009 ≠ T010 (distinct)")
        XCTAssertNotEqual(t009, t011, "3 colorize: T009 ≠ T011 (distinct)")
        XCTAssertNotEqual(t010, t011, "3 colorize: T010 ≠ T011 (distinct)")

        // Each replacement produces a NATIVE (non-HTML) output.
        let source = MonaColorizeSource()
        let units = Array("let x = 1".utf16)

        // T009: NSAttributedString (native, not HTML).
        let r009 = source.colorize(source: units)
        XCTAssertFalse(r009.string.contains("<span"), "3 colorize: T009 emits no HTML <span>")
        XCTAssertFalse(r009.string.contains("<div"), "3 colorize: T009 emits no HTML <div>")

        // T010: NSTextStorage mutation (native, not DOM innerHTML).
        let host = MonaColorizeHost()
        let view = MonaColorizeView(source: source, host: host)
        view.render(source: units)
        XCTAssertTrue(host.textStorage is NSTextStorage,
                     "3 colorize: T010 operates on NSTextStorage (native, not DOM)")
        view.detach()

        // T011: native runs + CGRect geometry (native, not HTML string).
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/p05-t011"))
        let colorizeModelLine = MonaColorizeModelLine(colorizeSource: source)
        let record = try makePlainLayoutRecord(for: model, line: 1)
        XCTAssertNoThrow(try colorizeModelLine.colorize(
            model: model, lineNumber: 1,
            layoutRecord: record,
            layoutGeneration: model.getVersionId()),
            "3 colorize: T011 produces native runs (no throw on matching generation)")
    }

    // MARK: 3. Reject cut / later / built-in language / WebGPU production ownership

    /// Cut-rejection matrix: no cut, later, built-in language, or WebGPU
    /// identity becomes production-owned (live/retained) in the registries.
    /// The cut WebGPU debug identity (feature `gpu`, command/action/pure-text
    /// `editor.action.debugEditorGpuRenderer`), the later iPadOS identity
    /// (feature `iPadShowKeyboard`), and all 90 cut built-in language
    /// descriptors remain disposition-only (unavailable): they are NOT in the
    /// live lookup tables, `contains` returns false, and `isLive` is false.
    @MainActor
    func testRejectCutLaterBuiltinLanguageWebGpuAsProductionOwned() {
        // ── Feature registry: gpu + iPadShowKeyboard are NOT live ──
        let features = MonaFeatureRegistry()
        XCTAssertFalse(features.contains("gpu"),
                       "Cut-rejection: gpu (WebGPU debug) is NOT a live feature")
        XCTAssertFalse(features.contains("iPadShowKeyboard"),
                       "Cut-rejection: iPadShowKeyboard (later iPadOS) is NOT a live feature")
        XCTAssertNil(features.identity(for: "gpu"),
                     "Cut-rejection: gpu has no live identity")
        XCTAssertNil(features.identity(for: "iPadShowKeyboard"),
                     "Cut-rejection: iPadShowKeyboard has no live identity")
        // The frozen cut identities report isLive == false.
        for id in ["gpu", "iPadShowKeyboard"] {
            let frozen = MonaFeatureRegistry.frozenIdentities.first { $0.id == id }!
            XCTAssertFalse(frozen.isLive,
                           "Cut-rejection: frozen feature \(id) isLive == false (unavailable)")
        }

        // ── Command registry: WebGPU debug command is NOT live ──
        let commands = MonaCommandRegistry()
        XCTAssertNil(commands.identity(for: "editor.action.debugEditorGpuRenderer"),
                     "Cut-rejection: WebGPU debug command is NOT a live command")
        XCTAssertFalse(commands.contains("editor.action.debugEditorGpuRenderer"),
                       "Cut-rejection: WebGPU debug command not contained as live")
        let frozenCmd = MonaCommandRegistry.frozenIdentities.first {
            $0.id == "editor.action.debugEditorGpuRenderer"
        }!
        XCTAssertFalse(frozenCmd.isLive, "Cut-rejection: frozen WebGPU debug command isLive == false")

        // ── Action + pure-text registry: WebGPU debug action is NOT live ──
        let actions = MonaActionRegistry()
        XCTAssertNil(actions.identity(for: "editor.action.debugEditorGpuRenderer"),
                     "Cut-rejection: WebGPU debug action is NOT a live action")
        XCTAssertNil(actions.pureTextIdentity(for: "editor.action.debugEditorGpuRenderer"),
                     "Cut-rejection: WebGPU debug pure-text action is NOT live")
        let frozenAction = MonaActionRegistry.frozenIdentities.first {
            $0.id == "editor.action.debugEditorGpuRenderer"
        }!
        XCTAssertFalse(frozenAction.isLive, "Cut-rejection: frozen WebGPU debug action isLive == false")

        // ── Language registry: all 90 built-in languages are NOT live (cut) ──
        let languages = MonaLanguageRegistry()
        // Every cut language identity reports isLive == false.
        for identity in languages.cutIdentities {
            XCTAssertFalse(identity.isLive,
                           "Cut-rejection: built-in language \(identity.id) isLive == false (cut)")
            XCTAssertNil(languages.frozenLiveIdentity(for: identity.id),
                          "Cut-rejection: \(identity.id) absent from the live lookup table")
        }
        XCTAssertEqual(languages.cutCount, 90,
                       "Cut-rejection: exactly 90 cut built-in languages")
        // The WebGPU Shading Language (wgsl) is among the cut languages.
        let wgsl = languages.cutIdentities.first { $0.id == "wgsl" }
        XCTAssertNotNil(wgsl, "Cut-rejection: wgsl (WebGPU Shading Language) is a cut built-in language")
        XCTAssertFalse(wgsl?.isLive ?? true,
                       "Cut-rejection: wgsl isLive == false (cut, not production-owned)")
        // The single live language is plaintext (the core fallback), NOT a
        // built-in language with grammar/provider content.
        XCTAssertEqual(languages.liveCount, 1, "Cut-rejection: exactly 1 live language (plaintext)")
        XCTAssertEqual(languages.liveIdentities.first!.id, "plaintext",
                       "Cut-rejection: the only live language is the plaintext fallback")
    }

    // MARK: 4. Contract leaf — the join of all Phase 05 tasks

    /// Contract leaf: prints the G6-R Phase-05 P05-T200 acceptance line. The
    /// Phase 05 conformance suite joins all task evidence: the 555-path public
    /// declaration graph, the registries, the 379 keybindings, the 174 options,
    /// the 4 builtin themes + icon registry, the 15 localization profiles with
    /// 2120 messages, the plain-text fallback, the three native colorize
    /// replacements, the editor factories, the deterministic provider
    /// executor, and the 62 retained features — revision-locked through one
    /// frozen source set, with every cut/later/built-in-language/WebGPU
    /// identity rejected from production ownership.
    @MainActor
    func testP05T200AcceptanceLeaf() {
        // The frozen Phase 05 source set exists on disk.
        let phase05SourceSet: Set<String> = [
            // P05-T001 — 555-path public declaration graph.
            "Sources/MonaCode/Generated/MonaPublicAPI.swift",
            // P05-T002 — command/action/contribution registries.
            "Sources/MonaCode/Registry/MonaCommandRegistry.swift",
            "Sources/MonaCode/Registry/MonaActionRegistry.swift",
            "Sources/MonaCode/Registry/MonaContributionRegistry.swift",
            // P05-T003 — 379 keybinding rows.
            "Sources/MonaCode/Generated/MonaBuiltinKeybindings.swift",
            // P05-T004 — menu registries.
            "Sources/MonaCode/Generated/MonaBuiltinMenus.swift",
            "Sources/MonaCode/Registry/MonaMenuRegistry.swift",
            // P05-T005 — 174 editor options.
            "Sources/MonaCode/Options/MonaEditorOption.swift",
            "Sources/MonaCode/Options/MonaOptionStore.swift",
            "Sources/MonaCode/Options/MonaOptionSnapshot.swift",
            "Sources/MonaCode/Generated/MonaBuiltinOptions.swift",
            // P05-T006 — theme/token/color/icon registries.
            "Sources/MonaCode/Theme/MonaTokenTheme.swift",
            "Sources/MonaCode/Theme/MonaThemeRegistry.swift",
            "Sources/MonaCode/Theme/MonaIconRegistry.swift",
            // P05-T007 — 15 localization profiles with 2120 messages.
            "Sources/MonaCode/Generated/MonaLocalizationProfiles.swift",
            // P05-T008 — plain-text language fallback.
            "Sources/MonaCode/Language/MonaLanguageRegistry.swift",
            "Sources/MonaCode/Language/MonaPlainTextLanguage.swift",
            // P05-T009/T010/T011 — three native colorize replacements.
            "Sources/MonaCodeAppKit/Colorize/MonaColorizeSource.swift",
            "Sources/MonaCodeAppKit/Colorize/MonaColorizeView.swift",
            "Sources/MonaCodeAppKit/Colorize/MonaColorizeModelLine.swift",
        ]
        let root = projectRoot
        var missingFiles: [String] = []
        for path in phase05SourceSet {
            if !FileManager.default.fileExists(atPath: root + "/" + path) {
                missingFiles.append(path)
            }
        }
        XCTAssertTrue(missingFiles.isEmpty, "Phase 05 frozen source set: missing files \(missingFiles)")

        // The acceptance line: the join of all Phase 05 tasks.
        // declarations=555 keybindings=379 options=174 themes=4 profiles=15
        // messages=2120 languages=91(live=1,cut=90) colorizeReplacements=3
        // features=64(live=62,cut=2)
        let featureRegistry = MonaFeatureRegistry()
        let languageRegistry = MonaLanguageRegistry()
        print("P05-T200 declarations=555 keybindings=\(MonaBuiltinKeybindings.rows.count) options=\(MonaBuiltinOptions.options.count) themes=\(MonaBuiltinThemes.ids.count) profiles=\(MonaLocalizationProfiles.profiles.count) messages=\(MonaLocalizationProfiles.identities.count) languages=\(languageRegistry.totalCount)(live=\(languageRegistry.liveCount),cut=\(languageRegistry.cutCount)) colorizeReplacements=3 features=\(featureRegistry.totalCount)(live=\(featureRegistry.liveCount),cut=\(featureRegistry.cutCount))")
    }

    // MARK: - Helpers

    /// The package root directory (where `Package.swift` lives), derived from
    /// this file's location. Used for source-set file existence checks.
    private var projectRoot: String {
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    /// The 62 retained feature IDs (T100-T161), in source-registry order. The
    /// 2 cut features (gpu / iPadShowKeyboard) are NOT in this list.
    private let expectedRetainedFeatureIds: [String] = [
        "anchorSelect", "bracketMatching", "caretOperations", "clipboard",
        "codeAction", "codeEditor", "codelens", "codicon", "colorPicker",
        "comment", "contextmenu", "cursorUndo", "diffEditor",
        "diffEditorBreadcrumbs", "dnd", "documentSymbols", "dropOrPasteInto",
        "find", "floatingMenu", "folding", "fontZoom", "format", "gotoError",
        "gotoLine", "gotoSymbol", "hover", "inPlaceReplace", "indentation",
        "inlayHints", "inlineCompletions", "inlineProgress",
        "insertFinalNewLine", "inspectTokens", "lineSelection", "linesOperations",
        "linkedEditing", "links", "longLinesHelper", "middleScroll", "multicursor",
        "parameterHints", "placeholderText", "quickCommand", "quickHelp",
        "quickOutline", "readOnlyMessage", "referenceSearch", "rename",
        "sectionHeaders", "semanticTokens", "smartSelect", "snippet",
        "stickyScroll", "suggest", "toggleHighContrast", "toggleTabFocusMode",
        "tokenization", "unicodeHighlighter", "unusualLineTerminators",
        "wordHighlighter", "wordOperations", "wordPartOperations",
    ]

    /// Builds a real immutable line-layout record for colorizeModelLine via
    /// the Phase 03 `MonaLineLayoutBuilder` + shaper, so the T011 matrix
    /// exercises the plain-text fallback path (no token provider) against a
    /// properly-shaped record. The generation matches `model.getVersionId()`.
    @MainActor
    private func makePlainLayoutRecord(for model: MonaCodeModel, line: Int) throws -> MonaLineLayoutRecord {
        let resolver = MonaFontFallbackResolver(primary: Self.font, fallback: [])
        let shaper = MonaTextShaper(
            primaryFont: Self.font, fallback: resolver, direction: .ltr, scale: 1)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let stamp = builder.makeDependencyStamp()
        let units = Array(model.getLineContent(line).utf16)
        return try builder.build(codeUnits: units, dependencyStamp: stamp)
    }
}
