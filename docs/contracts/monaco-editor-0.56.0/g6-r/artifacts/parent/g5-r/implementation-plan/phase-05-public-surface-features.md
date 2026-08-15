# Phase 05: Public surface and retained features

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 04.

Task count: 77.

<!-- monacode-plan-task:{"id":"P05-T001","recordSha256":"74b141355de25f8054462f6e370634d4dec92ec6b9303d5fd098d993390174a0"} -->
## P05-T001 — Generate the exact 555-path native public declaration graph

Contract: `F1-R4.publicDeclarations`, `F1-R5.nativeTypeSemantics`, `C04`

Dependencies:
- `P04-T016`
- `P02-T009`

Ownership selectors:
- `public-surface:555-paths`
- `generator:contract-registries`

Files to create:
- `Tools/Generators/generate-contract-registries.mjs`
- `Sources/MonaCode/Generated/MonaPublicAPI.swift`
- `Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift`
- `Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/PublicDeclarationGraphTests.mjs`

Interfaces consumed:
- `PublicDeclarationProbe`
- `ScopeProbe`

Interfaces produced:
- `MonaPublicDeclarationGraph`
- `MonaContractRegistryGenerator`

Red verification:
- Run: `node --test Tests/PlanStructureTests/PublicDeclarationGraphTests.mjs --test-name-pattern zero-selector`
  - Expected exit: `1`
  - Expected output includes: `OWNERSHIP_SELECTOR_EMPTY selector=editor.missing`

Minimal implementation operations:
- `Read the copied F1-R3 and F1-R4 machine artifacts and emit individual rows without renaming or coalescing identities.`
- `Generate native declarations with exact optionals, overloads, extensible raw values, reference/value identity, throwing, async, and event adaptation.`
- `Reject selectors that expand to zero identities and reject output not set-equal to all 555 paths.`
- `Keep cut declarations recorded as explicit unavailable dispositions without production symbols.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/PublicDeclarationGraphTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `PUBLIC_DECLARATION_GRAPH identities=555 missing=0 extra=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T001.json`

Completion assertions:
- `All 555 paths appear as individual machine ownership rows.`
- `Retained native declarations are set-equal to F1-R4.`
- `Cut declarations produce no production symbol.`

Commit boundary:
- `Tools/Generators/generate-contract-registries.mjs`
- `Sources/MonaCode/Generated/MonaPublicAPI.swift`
- `Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift`
- `Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift`
- `Tests/PlanStructureTests/PublicDeclarationGraphTests.mjs`

<!-- monacode-plan-task:{"id":"P05-T002","recordSha256":"2e19d98f32f7094e2d80fdab5b6724181d1408ece7e71f2be831f72a53918fc8"} -->
## P05-T002 — Implement command, action, contribution, and pure-text registries

Contract: `F1-R3.actions`, `F1-R3.commands`, `F1-R3.contributions`, `C04`

Dependencies:
- `P04-T003`
- `P05-T001`

Ownership selectors:
- `registry:actions`
- `registry:pure-text-actions`
- `registry:commands`
- `registry:contributions`

Files to create:
- `Sources/MonaCode/Registry/MonaCommandRegistry.swift`
- `Sources/MonaCode/Registry/MonaActionRegistry.swift`
- `Sources/MonaCode/Registry/MonaContributionRegistry.swift`
- `Sources/MonaCode/Registry/MonaContextKey.swift`
- `Sources/MonaCode/Registry/MonaFeatureRegistry.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Registry/MonaCommandActionRegistryTests.swift`

Interfaces consumed:
- `MonaGlobalLifetime`
- `MonaKeyDispatchOutcome`

Interfaces produced:
- `MonaCommandRegistry`
- `MonaActionRegistry`
- `MonaContributionRegistry`
- `MonaContextKey`
- `MonaFeatureRegistry`

Red verification:
- Run: `swift test --filter MonaCommandActionRegistryTests/testFrozenIdentityAndOrder`
  - Expected exit: `1`
  - Expected output includes: `REGISTRY_IDENTITY_MISMATCH kind=command`

Minimal implementation operations:
- `Register all frozen command, action, pure-text action, and contribution identities in source order.`
- `Evaluate enablement, precondition, toggled state, argument shape, and disposal deterministically.`
- `Exclude the WebGPU debug identities and later mobile contribution from production.`

Green verification:
- Run: `swift test --filter MonaCommandActionRegistryTests`
  - Expected exit: `0`
  - Expected output includes: `COMMAND_ACTION_REGISTRY actions=166 pureText=126 commands=453 contributions=52`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T002.json`

Completion assertions:
- `All retained registry identities are present exactly once.`
- `Cut and later identities are absent from production.`
- `Registration and disposal order match the frozen manifests.`

Commit boundary:
- `Sources/MonaCode/Registry/MonaCommandRegistry.swift`
- `Sources/MonaCode/Registry/MonaActionRegistry.swift`
- `Sources/MonaCode/Registry/MonaContributionRegistry.swift`
- `Sources/MonaCode/Registry/MonaContextKey.swift`
- `Sources/MonaCode/Registry/MonaFeatureRegistry.swift`
- `Tests/MonaCodeTests/Registry/MonaCommandActionRegistryTests.swift`

<!-- monacode-plan-task:{"id":"P05-T003","recordSha256":"1ee62d94c4506b1cd752a97f369e5735268204374ef0ea7218e06ef3012199fe"} -->
## P05-T003 — Populate all 379 keybinding rows over the Core resolver

Contract: `F1-R3.keybindings`, `I3-R2.keybindingClosure`, `C04`

Dependencies:
- `P05-T002`
- `P04-T003`

Ownership selectors:
- `registry:keybindings-379`

Files to create:
- `Sources/MonaCode/Generated/MonaBuiltinKeybindings.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Registry/MonaBuiltinKeybindingTests.swift`

Interfaces consumed:
- `MonaKeybindingResolver`
- `MonaCommandRegistry`
- `MonaContextKey`

Interfaces produced:
- `MonaBuiltinKeybindings`

Red verification:
- Run: `swift test --filter MonaBuiltinKeybindingTests/testOrdinalCommandMatrix`
  - Expected exit: `1`
  - Expected output includes: `KEYBINDING_ROW_MISMATCH ordinal=000`

Minimal implementation operations:
- `Generate every ordinal, command, primary key, secondary key, weight, and when-clause row from F1-R3.`
- `Keep source ordinals as stable identity even when command text repeats.`
- `Validate ABC and chord conflicts against the I3-R2 resolver truth table.`

Green verification:
- Run: `swift test --filter MonaBuiltinKeybindingTests`
  - Expected exit: `0`
  - Expected output includes: `BUILTIN_KEYBINDINGS rows=379 missing=0 order=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T003.json`

Completion assertions:
- `All 379 ordinal identities are present.`
- `Conflict resolution matches I3-R2.`
- `No generated row targets a cut command.`

Commit boundary:
- `Sources/MonaCode/Generated/MonaBuiltinKeybindings.swift`
- `Tests/MonaCodeTests/Registry/MonaBuiltinKeybindingTests.swift`

<!-- monacode-plan-task:{"id":"P05-T004","recordSha256":"a6da070f5b8a7a9f47fd6496c8484f6f1dd2ae07990422e6cb459bc35725d549"} -->
## P05-T004 — Implement menu, menu-item, and menu-command registries

Contract: `F1-R3.menus`, `I3-R4.contextMenu`, `C04`

Dependencies:
- `P05-T002`
- `P05-T003`

Ownership selectors:
- `registry:menus`
- `registry:menu-items`
- `registry:menu-commands`

Files to create:
- `Sources/MonaCode/Registry/MonaMenuRegistry.swift`
- `Sources/MonaCode/Generated/MonaBuiltinMenus.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Registry/MonaMenuRegistryTests.swift`

Interfaces consumed:
- `MonaCommandRegistry`
- `MonaContextKey`

Interfaces produced:
- `MonaMenuRegistry`
- `MonaMenuModel`

Red verification:
- Run: `swift test --filter MonaMenuRegistryTests/testMenuItemOrdinalMatrix`
  - Expected exit: `1`
  - Expected output includes: `MENU_ITEM_MISMATCH menu=EditorContext ordinal=000`

Minimal implementation operations:
- `Generate 18 menu identities, 121 ordinal menu-item identities, and 21 menu-command identities.`
- `Evaluate group, order, when, enablement, submenu, alternative, and command arguments in stable order.`
- `Produce a platform-neutral menu model consumed by the native context-menu gateway.`

Green verification:
- Run: `swift test --filter MonaMenuRegistryTests`
  - Expected exit: `0`
  - Expected output includes: `MENU_REGISTRY menus=18 items=121 commands=21`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T004.json`

Completion assertions:
- `All frozen menu identities are exact.`
- `Native presentation receives one ordered model.`
- `Disabled and hidden items remain distinct.`

Commit boundary:
- `Sources/MonaCode/Registry/MonaMenuRegistry.swift`
- `Sources/MonaCode/Generated/MonaBuiltinMenus.swift`
- `Tests/MonaCodeTests/Registry/MonaMenuRegistryTests.swift`

<!-- monacode-plan-task:{"id":"P05-T005","recordSha256":"32f0fc39af9a354dce354a80b6951a5e81471a6a7beb2073f9cdbf2c1deb5ba5"} -->
## P05-T005 — Implement all 174 editor options and computed option truth

Contract: `F1-R2.optionDomains`, `F1-R3.options`, `C04`, `C05`

Dependencies:
- `P05-T001`
- `P01-T013`

Ownership selectors:
- `registry:options-174`

Files to create:
- `Sources/MonaCode/Options/MonaEditorOption.swift`
- `Sources/MonaCode/Options/MonaOptionStore.swift`
- `Sources/MonaCode/Options/MonaOptionSnapshot.swift`
- `Sources/MonaCode/Generated/MonaBuiltinOptions.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Options/MonaEditorOptionTests.swift`

Interfaces consumed:
- `MonaEmitter`
- `MonaCodeEnvironment`

Interfaces produced:
- `MonaEditorOption`
- `MonaOptionStore`
- `MonaOptionSnapshot`

Red verification:
- Run: `swift test --filter MonaEditorOptionTests/testTMinusOneTPlusOneMatrix`
  - Expected exit: `1`
  - Expected output includes: `OPTION_DOMAIN_MISMATCH option=stopRenderingLineAfter boundary=T`

Minimal implementation operations:
- `Generate retained-input, computed-only, and cut dispositions exactly from F1-R3.`
- `Validate input types, defaults, bounds, enum extensibility, dependency ordering, and changed-option events.`
- `Compute six computed-only options without exposing them as mutable input.`
- `Exclude all eleven cut options from production input APIs.`

Green verification:
- Run: `swift test --filter MonaEditorOptionTests`
  - Expected exit: `0`
  - Expected output includes: `EDITOR_OPTIONS total=174 retainedInput=157 computed=6 cut=11`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T005.json`

Completion assertions:
- `All option rows preserve exact dispositions.`
- `Boundary vectors pass.`
- `Computed option updates publish one consistent snapshot.`

Commit boundary:
- `Sources/MonaCode/Options/MonaEditorOption.swift`
- `Sources/MonaCode/Options/MonaOptionStore.swift`
- `Sources/MonaCode/Options/MonaOptionSnapshot.swift`
- `Sources/MonaCode/Generated/MonaBuiltinOptions.swift`
- `Tests/MonaCodeTests/Options/MonaEditorOptionTests.swift`

<!-- monacode-plan-task:{"id":"P05-T006","recordSha256":"19f027466e9cc37a85e8058c10b9576fd4c5c790479a0b65912f5ab52e2c6a33"} -->
## P05-T006 — Implement theme, token, color, icon, and Codicon registries

Contract: `T1-R`, `F1-R3.colors`, `F1-R3.icons`, `G5-R.licensingProfile.codiconArtworkAndFont`, `C04`

Dependencies:
- `P05-T001`
- `P05-T005`

Ownership selectors:
- `normativeLayer:theme-token-icon:T1-R`
- `registry:colors`
- `registry:icons`
- `registry:themes`

Files to create:
- `Sources/MonaCode/Theme/MonaThemeRegistry.swift`
- `Sources/MonaCode/Theme/MonaTokenTheme.swift`
- `Sources/MonaCode/Theme/MonaColorRegistry.swift`
- `Sources/MonaCode/Theme/MonaIconRegistry.swift`
- `Sources/MonaCode/Generated/MonaCodiconMap.swift`
- `Sources/MonaCode/Resources/codicon.ttf`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Theme/MonaThemeRegistryTests.swift`

Interfaces consumed:
- `MonaOptionSnapshot`

Interfaces produced:
- `MonaThemeRegistry`
- `MonaTokenTheme`
- `MonaColorRegistry`
- `MonaIconRegistry`

Red verification:
- Run: `swift test --filter MonaThemeRegistryTests/testFrozenRegistryIdentitySets`
  - Expected exit: `1`
  - Expected output includes: `THEME_REGISTRY_IDENTITY_MISMATCH kind=icon`

Minimal implementation operations:
- `Register exactly 431 colors, 776 icons, four built-in themes, token rules, and licensed Codicon glyph mappings.`
- `Resolve inheritance, defaults, high contrast, token scopes, icon modifiers, and theme change events deterministically.`
- `Hash the bundled font and keep provenance attached to the generated map.`

Green verification:
- Run: `swift test --filter MonaThemeRegistryTests`
  - Expected exit: `0`
  - Expected output includes: `THEME_REGISTRIES colors=431 icons=776 themes=4`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T006.json`

Completion assertions:
- `Registry identity sets are exact.`
- `Token and theme resolution fixtures match.`
- `Codicon asset hash and notice are recorded.`

Commit boundary:
- `Sources/MonaCode/Theme/MonaThemeRegistry.swift`
- `Sources/MonaCode/Theme/MonaTokenTheme.swift`
- `Sources/MonaCode/Theme/MonaColorRegistry.swift`
- `Sources/MonaCode/Theme/MonaIconRegistry.swift`
- `Sources/MonaCode/Generated/MonaCodiconMap.swift`
- `Sources/MonaCode/Resources/codicon.ttf`
- `Tests/MonaCodeTests/Theme/MonaThemeRegistryTests.swift`

<!-- monacode-plan-task:{"id":"P05-T007","recordSha256":"e4e504dcf599dd725d77923332f98abad4b9dced6e76e8578d8d7fe03c49951b"} -->
## P05-T007 — Generate 15 immutable UI localization profiles with 2120 messages

Contract: `N1-R`, `E1-R.localeBoundary`, `C04`, `C07`

Dependencies:
- `P05-T001`
- `P00-T007`

Ownership selectors:
- `normativeLayer:ui-localization:N1-R`
- `machineArtifact:N1-R-localization`
- `registry:localization-profiles`

Files to create:
- `Tools/Generators/generate-localization.mjs`
- `Sources/MonaCode/Localization/MonaLocalization.swift`
- `Sources/MonaCode/Generated/MonaLocalizationProfiles.swift`
- `Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Localization/MonaLocalizationTests.swift`

Interfaces consumed:
- `MonaCodeEnvironment`

Interfaces produced:
- `MonaLocalization`
- `MonaLocalizationProfileSet`

Red verification:
- Run: `swift test --filter MonaLocalizationTests/testProfileMessageIdentitySet`
  - Expected exit: `1`
  - Expected output includes: `LOCALIZATION_MESSAGE_MISSING profile=zh-hans key=editor.action.clipboardCopyAction`

Minimal implementation operations:
- `Generate 15 explicit profile tables and all 2120 message identities from the frozen N1-R artifact.`
- `Keep profile selection immutable and independent from runtime locale.`
- `Apply placeholder validation, fallback, plural behavior, and Monaco MIT provenance exactly.`

Green verification:
- Run: `swift test --filter MonaLocalizationTests`
  - Expected exit: `0`
  - Expected output includes: `LOCALIZATION profiles=15 messages=2120 missing=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T007.json`

Completion assertions:
- `All profile and message identities are exact.`
- `Runtime locale cannot switch UI profile.`
- `Accessibility and feedback messages resolve through the same tables.`

Commit boundary:
- `Tools/Generators/generate-localization.mjs`
- `Sources/MonaCode/Localization/MonaLocalization.swift`
- `Sources/MonaCode/Generated/MonaLocalizationProfiles.swift`
- `Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt`
- `Tests/MonaCodeTests/Localization/MonaLocalizationTests.swift`

<!-- monacode-plan-task:{"id":"P05-T008","recordSha256":"80fee62c9661512b0741bd311897f3f54bde3d0353ca7da5b92bad835d08983c"} -->
## P05-T008 — Retain only core language metadata and explicit plain-text fallback

Contract: `F1-R3.languageDescriptors`, `L2-R.plainTextFallback`, `G5-R.explicitCuts.builtinLanguageContent`

Dependencies:
- `P05-T001`

Ownership selectors:
- `registry:language-descriptors`
- `language:plain-text-fallback`

Files to create:
- `Sources/MonaCode/Language/MonaLanguageRegistry.swift`
- `Sources/MonaCode/Language/MonaPlainTextLanguage.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Language/MonaLanguageRegistryTests.swift`

Interfaces consumed:
- None.

Interfaces produced:
- `MonaLanguageRegistry`
- `MonaPlainTextLanguage`

Red verification:
- Run: `swift test --filter MonaLanguageRegistryTests/testBuiltinContentIsAbsent`
  - Expected exit: `1`
  - Expected output includes: `BUILTIN_LANGUAGE_CONTENT_PRESENT id=typescript`

Minimal implementation operations:
- `Retain exactly the core fallback metadata identity.`
- `Record all 90 built-in language descriptors as cut-built-in-language-content with no bundled grammar or provider.`
- `Expose explicit registration for host-provided metadata and plain-text behavior when none exists.`

Green verification:
- Run: `swift test --filter MonaLanguageRegistryTests`
  - Expected exit: `0`
  - Expected output includes: `LANGUAGE_DESCRIPTORS retained=1 cut=90 builtinContent=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T008.json`

Completion assertions:
- `One core fallback descriptor is retained.`
- `No built-in language implementation or grammar pack ships.`
- `Unknown language IDs remain plain text.`

Commit boundary:
- `Sources/MonaCode/Language/MonaLanguageRegistry.swift`
- `Sources/MonaCode/Language/MonaPlainTextLanguage.swift`
- `Tests/MonaCodeTests/Language/MonaLanguageRegistryTests.swift`

<!-- monacode-plan-task:{"id":"P05-T009","recordSha256":"07cd6661e367d2ac2b532c6cbdb3e8dcab2a1bae133fc5fbf7222dd56ea48a3a"} -->
## P05-T009 — Implement editor.colorize as a native attributed-text replacement

Contract: `F1-R4.editor.colorize`, `F1-R5.nativeReplacement`, `C04`

Dependencies:
- `P05-T006`
- `P05-T008`

Ownership selectors:
- `publicPath:editor.colorize`
- `native-colorize:source`

Files to create:
- `Sources/MonaCodeAppKit/Colorize/MonaColorizeSource.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeSourceTests.swift`

Interfaces consumed:
- `MonaLanguageRegistry`
- `MonaTokenTheme`

Interfaces produced:
- `MonaColorizeSource`

Red verification:
- Run: `swift test --filter MonaColorizeSourceTests/testRawUTF16TokenProjection`
  - Expected exit: `1`
  - Expected output includes: `NATIVE_COLORIZE_MISMATCH path=editor.colorize`

Minimal implementation operations:
- `Tokenize provided source through an attached direct token provider or plain-text fallback.`
- `Return a native attributed-text value with raw UTF-16 token boundaries and resolved theme colors.`
- `Never emit HTML or require a DOM/CSS renderer.`

Green verification:
- Run: `swift test --filter MonaColorizeSourceTests`
  - Expected exit: `0`
  - Expected output includes: `NATIVE_COLORIZE_OK path=editor.colorize`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T009.json`

Completion assertions:
- `editor.colorize has a distinct native interface.`
- `Raw-unit token ranges are preserved.`
- `No web presentation output exists.`

Commit boundary:
- `Sources/MonaCodeAppKit/Colorize/MonaColorizeSource.swift`
- `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeSourceTests.swift`

<!-- monacode-plan-task:{"id":"P05-T010","recordSha256":"10a6e5517ef3a37cf23e02648ebd487baa8c4304b85b96656bbbe2c7d38bfa87"} -->
## P05-T010 — Implement editor.colorizeElement as a native view mutation replacement

Contract: `F1-R4.editor.colorizeElement`, `F1-R5.nativeReplacement`, `C04`

Dependencies:
- `P05-T009`
- `P04-T014`

Ownership selectors:
- `publicPath:editor.colorizeElement`
- `native-colorize:view`

Files to create:
- `Sources/MonaCodeAppKit/Colorize/MonaColorizeView.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeViewTests.swift`

Interfaces consumed:
- `MonaColorizeSource`
- `MonaCodeEditorView`

Interfaces produced:
- `MonaColorizeView`

Red verification:
- Run: `swift test --filter MonaColorizeViewTests/testRecolorInvalidationAndDisposal`
  - Expected exit: `1`
  - Expected output includes: `NATIVE_COLORIZE_MISMATCH path=editor.colorizeElement`

Minimal implementation operations:
- `Apply attributed token presentation to an explicit native text host.`
- `Update only changed theme and token ranges and dispose every observation with the host lifetime.`
- `Replace the web element parameter with the frozen AppKit-native type adaptation.`

Green verification:
- Run: `swift test --filter MonaColorizeViewTests`
  - Expected exit: `0`
  - Expected output includes: `NATIVE_COLORIZE_OK path=editor.colorizeElement`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T010.json`

Completion assertions:
- `editor.colorizeElement has a distinct native host interface.`
- `Theme updates are bounded.`
- `Host disposal removes all observers.`

Commit boundary:
- `Sources/MonaCodeAppKit/Colorize/MonaColorizeView.swift`
- `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeViewTests.swift`

<!-- monacode-plan-task:{"id":"P05-T011","recordSha256":"2db08f3c852a0f0b103f84839f964e0ec2ba91c3ea1f2772911a55075ee267cf"} -->
## P05-T011 — Implement editor.colorizeModelLine from immutable layout geometry

Contract: `F1-R4.editor.colorizeModelLine`, `F1-R5.nativeReplacement`, `C04`

Dependencies:
- `P05-T009`
- `P03-T003`

Ownership selectors:
- `publicPath:editor.colorizeModelLine`
- `native-colorize:model-line`

Files to create:
- `Sources/MonaCodeAppKit/Colorize/MonaColorizeModelLine.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeModelLineTests.swift`

Interfaces consumed:
- `MonaColorizeSource`
- `MonaLineLayoutRecord`

Interfaces produced:
- `MonaColorizeModelLine`

Red verification:
- Run: `swift test --filter MonaColorizeModelLineTests/testInjectedTextAndBidiRanges`
  - Expected exit: `1`
  - Expected output includes: `NATIVE_COLORIZE_MISMATCH path=editor.colorizeModelLine`

Minimal implementation operations:
- `Project tokens, injected text, bidi segments, and theme styling from one immutable line-layout record.`
- `Return native runs and geometry without HTML string construction.`
- `Reject mixed model and layout generations.`

Green verification:
- Run: `swift test --filter MonaColorizeModelLineTests`
  - Expected exit: `0`
  - Expected output includes: `NATIVE_COLORIZE_OK path=editor.colorizeModelLine`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T011.json`

Completion assertions:
- `editor.colorizeModelLine has a distinct native interface.`
- `Injected-text and bidi ranges remain exact.`
- `Mixed generations are rejected.`

Commit boundary:
- `Sources/MonaCodeAppKit/Colorize/MonaColorizeModelLine.swift`
- `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeModelLineTests.swift`

<!-- monacode-plan-task:{"id":"P05-T012","recordSha256":"2a34695f1b8117624ff7c452359ca4bcc98139c92d9fb6096ec9b20c566d198b"} -->
## P05-T012 — Close editor factories and five instance-interface sequences

Contract: `F1-R2.instanceSurfaces`, `F1-R4.editorFactories`, `H1-R.editorView`, `C04`

Dependencies:
- `P05-T001`
- `P05-T005`
- `P04-T015`

Ownership selectors:
- `public-surface:instance-sequences`
- `public-factory:editor.create`

Files to create:
- `Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift`
- `Sources/MonaCodeAppKit/Views/MonaEditorInstanceAdapters.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Views/MonaEditorInstanceSurfaceTests.swift`

Interfaces consumed:
- `MonaPublicDeclarationGraph`
- `MonaCodeEditorView`
- `MonaOptionStore`

Interfaces produced:
- `MonaEditorFactory`
- `MonaEditorInstanceAdapters`

Red verification:
- Run: `swift test --filter MonaEditorInstanceSurfaceTests/testFiveFrozenSequences`
  - Expected exit: `1`
  - Expected output includes: `INSTANCE_SEQUENCE_MISMATCH surface=ICodeEditor`

Minimal implementation operations:
- `Implement editor creation, model attachment, retrieval, disposal, and global editor/model event sequences.`
- `Expose the five F1-R3 instance surfaces with exact retained member counts and native type adaptations.`
- `Keep diff and multi-diff construction behind Phase 07 adapters while preserving their declaration slots.`

Green verification:
- Run: `swift test --filter MonaEditorInstanceSurfaceTests`
  - Expected exit: `0`
  - Expected output includes: `INSTANCE_SURFACES surfaces=5 sequences=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T012.json`

Completion assertions:
- `Five instance sequences match the frozen manifests.`
- `Editor factory lifecycle is deterministic.`
- `Future diff adapters cannot change existing declaration hashes.`

Commit boundary:
- `Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift`
- `Sources/MonaCodeAppKit/Views/MonaEditorInstanceAdapters.swift`
- `Tests/MonaCodeAppKitTests/Views/MonaEditorInstanceSurfaceTests.swift`

<!-- monacode-plan-task:{"id":"P05-T013","recordSha256":"e760bd36295d5a0808d5756f5f8d240d51adfac907a378b848bf2c8de1cc542c"} -->
## P05-T013 — Implement deterministic provider execution and microtask publication

Contract: `F1-R5.providerExecution`, `L2-R.providerOrdering`, `R1.asyncValidity`

Dependencies:
- `P05-T001`
- `P01-T010`

Ownership selectors:
- `provider:execution-model`
- `runtime:microtask-queue`

Files to create:
- `Sources/MonaCode/Language/MonaProviderExecutor.swift`
- `Sources/MonaCode/Runtime/MonaMicrotaskQueue.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Language/MonaProviderExecutorTests.swift`

Interfaces consumed:
- `MonaPublicationGate`
- `MonaCancellationToken`
- `MonaEmitter`

Interfaces produced:
- `MonaProviderExecutor`
- `MonaMicrotaskQueue`

Red verification:
- Run: `swift test --filter MonaProviderExecutorTests/testResolveCancelReleaseOrder`
  - Expected exit: `1`
  - Expected output includes: `PROVIDER_EXECUTION_ORDER_MISMATCH fixture=resolve-cancel-release`

Minimal implementation operations:
- `Normalize synchronous, asynchronous, optional, throwing, cancelable, resolvable, and releasable provider results.`
- `Serialize publication on one deterministic microtask queue.`
- `Validate tickets immediately before publication and release every owned list exactly once.`

Green verification:
- Run: `swift test --filter MonaProviderExecutorTests`
  - Expected exit: `0`
  - Expected output includes: `PROVIDER_EXECUTION ordering=exact stalePublications=0 releases=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T013.json`

Completion assertions:
- `Provider ordering matches F1-R5.`
- `Stale and canceled results have no side effects.`
- `Resolve and release lifetimes are explicit.`

Commit boundary:
- `Sources/MonaCode/Language/MonaProviderExecutor.swift`
- `Sources/MonaCode/Runtime/MonaMicrotaskQueue.swift`
- `Tests/MonaCodeTests/Language/MonaProviderExecutorTests.swift`

<!-- monacode-plan-task:{"id":"P05-T100","recordSha256":"518c4a7428fff1c33ab7827c7354dd5b39a81e0fe638635891f65b1d7fdab0ea"} -->
## P05-T100 — Implement retained feature anchorSelect

Contract: `F1-R.retainedFeatures`, `feature:anchorSelect`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:anchorSelect`

Files to create:
- `Sources/MonaCode/Features/MonaAnchorSelectFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaAnchorSelectFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaAnchorSelectFeature`

Red verification:
- Run: `swift test --filter MonaAnchorSelectFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=anchorSelect`

Minimal implementation operations:
- `Implement extend selections from their anchors with exact cursor ordering.`
- `Register the exact feature identity anchorSelect and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaAnchorSelectFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=anchorSelect`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T100.json`

Completion assertions:
- `Feature identity anchorSelect is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaAnchorSelectFeature.swift`
- `Tests/MonaCodeTests/Features/MonaAnchorSelectFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T101","recordSha256":"500b6c2f1685222986406768c002c06a4849b33151192225b20d7b9679ef78cc"} -->
## P05-T101 — Implement retained feature bracketMatching

Contract: `F1-R.retainedFeatures`, `feature:bracketMatching`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:bracketMatching`

Files to create:
- `Sources/MonaCode/Features/MonaBracketMatchingFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaBracketMatchingFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaBracketMatchingFeature`

Red verification:
- Run: `swift test --filter MonaBracketMatchingFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=bracketMatching`

Minimal implementation operations:
- `Implement match, navigate, select, and highlight bracket pairs from the active tokenization state.`
- `Register the exact feature identity bracketMatching and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaBracketMatchingFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=bracketMatching`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T101.json`

Completion assertions:
- `Feature identity bracketMatching is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaBracketMatchingFeature.swift`
- `Tests/MonaCodeTests/Features/MonaBracketMatchingFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T102","recordSha256":"03cbf4b32dfaef44856cd4649bdd5b0f8e3e44db4c6461e5ff352db3080b3bab"} -->
## P05-T102 — Implement retained feature caretOperations

Contract: `F1-R.retainedFeatures`, `feature:caretOperations`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:caretOperations`

Files to create:
- `Sources/MonaCode/Features/MonaCaretOperationsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaCaretOperationsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaCaretOperationsFeature`

Red verification:
- Run: `swift test --filter MonaCaretOperationsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=caretOperations`

Minimal implementation operations:
- `Implement move carets by line, wrapped line, column, page, viewport, and document boundaries.`
- `Register the exact feature identity caretOperations and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaCaretOperationsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=caretOperations`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T102.json`

Completion assertions:
- `Feature identity caretOperations is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaCaretOperationsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaCaretOperationsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T103","recordSha256":"5abcd7ce36b052be057baf30d0cb2dd3618199032e51d462763ceb556e28756a"} -->
## P05-T103 — Implement retained feature clipboard

Contract: `F1-R.retainedFeatures`, `feature:clipboard`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:clipboard`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaClipboardFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaClipboardFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaClipboardFeature`

Red verification:
- Run: `swift test --filter MonaClipboardFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=clipboard`

Minimal implementation operations:
- `Implement register editor copy, cut, and paste actions over the native transfer gateway.`
- `Register the exact feature identity clipboard and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaClipboardFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=clipboard`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T103.json`

Completion assertions:
- `Feature identity clipboard is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaClipboardFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaClipboardFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T104","recordSha256":"908166d67e6ebf1c72b54710744bf1082fa570c9f5804181e55b51ccb2ccba6a"} -->
## P05-T104 — Implement retained feature codeAction

Contract: `F1-R.retainedFeatures`, `feature:codeAction`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:codeAction`

Files to create:
- `Sources/MonaCode/Features/MonaCodeActionFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaCodeActionFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaCodeActionFeature`

Red verification:
- Run: `swift test --filter MonaCodeActionFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=codeAction`

Minimal implementation operations:
- `Implement surface provider code actions, resolve them, and apply accepted edits transactionally.`
- `Register the exact feature identity codeAction and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaCodeActionFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=codeAction`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T104.json`

Completion assertions:
- `Feature identity codeAction is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaCodeActionFeature.swift`
- `Tests/MonaCodeTests/Features/MonaCodeActionFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T105","recordSha256":"aa0a3db7f1326f206e083f1bdfcef43998439db2775ba26f017338ca0ecb3073"} -->
## P05-T105 — Implement retained feature codeEditor

Contract: `F1-R.retainedFeatures`, `feature:codeEditor`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:codeEditor`

Files to create:
- `Sources/MonaCode/Features/MonaCodeEditorFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaCodeEditorFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaCodeEditorFeature`

Red verification:
- Run: `swift test --filter MonaCodeEditorFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=codeEditor`

Minimal implementation operations:
- `Implement register the standalone code-editor contribution set and lifecycle hooks.`
- `Register the exact feature identity codeEditor and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaCodeEditorFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=codeEditor`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T105.json`

Completion assertions:
- `Feature identity codeEditor is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaCodeEditorFeature.swift`
- `Tests/MonaCodeTests/Features/MonaCodeEditorFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T106","recordSha256":"5eb42f198560ef5e56453a034acbe701d6916b87a6491f705beae17f036c0a33"} -->
## P05-T106 — Implement retained feature codelens

Contract: `F1-R.retainedFeatures`, `feature:codelens`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:codelens`

Files to create:
- `Sources/MonaCode/Features/MonaCodelensFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaCodelensFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaCodelensFeature`

Red verification:
- Run: `swift test --filter MonaCodelensFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=codelens`

Minimal implementation operations:
- `Implement render, resolve, invoke, and release code-lens results by model version.`
- `Register the exact feature identity codelens and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaCodelensFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=codelens`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T106.json`

Completion assertions:
- `Feature identity codelens is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaCodelensFeature.swift`
- `Tests/MonaCodeTests/Features/MonaCodelensFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T107","recordSha256":"204227ccb164e97841e70c5b2c03e82b4a1be1a359fb61f9d0bea9d9c3eb37df"} -->
## P05-T107 — Implement retained feature codicon

Contract: `F1-R.retainedFeatures`, `feature:codicon`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:codicon`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaCodiconFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaCodiconFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaCodiconFeature`

Red verification:
- Run: `swift test --filter MonaCodiconFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=codicon`

Minimal implementation operations:
- `Implement resolve Codicon identifiers and licensed glyph assets through the theme registry.`
- `Register the exact feature identity codicon and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaCodiconFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=codicon`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T107.json`

Completion assertions:
- `Feature identity codicon is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaCodiconFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaCodiconFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T108","recordSha256":"a7309612ab778dd0ce7759180a5d45d7f516db7ba966a889f931bb47adc5a22c"} -->
## P05-T108 — Implement retained feature colorPicker

Contract: `F1-R.retainedFeatures`, `feature:colorPicker`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:colorPicker`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaColorPickerFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaColorPickerFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaColorPickerFeature`

Red verification:
- Run: `swift test --filter MonaColorPickerFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=colorPicker`

Minimal implementation operations:
- `Implement present, update, and commit document-color provider results.`
- `Register the exact feature identity colorPicker and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaColorPickerFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=colorPicker`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T108.json`

Completion assertions:
- `Feature identity colorPicker is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaColorPickerFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaColorPickerFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T109","recordSha256":"b0dc3c7ed388a6060810ec5f4b98254853195444d87797b25415ed973a780f39"} -->
## P05-T109 — Implement retained feature comment

Contract: `F1-R.retainedFeatures`, `feature:comment`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:comment`

Files to create:
- `Sources/MonaCode/Features/MonaCommentFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaCommentFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaCommentFeature`

Red verification:
- Run: `swift test --filter MonaCommentFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=comment`

Minimal implementation operations:
- `Implement execute line and block comment commands from explicit language configuration only.`
- `Register the exact feature identity comment and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaCommentFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=comment`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T109.json`

Completion assertions:
- `Feature identity comment is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaCommentFeature.swift`
- `Tests/MonaCodeTests/Features/MonaCommentFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T110","recordSha256":"bbc39ab46988da4f338d9704ff09f883ebc945bb3043608c3beec9c18dc26d4e"} -->
## P05-T110 — Implement retained feature contextmenu

Contract: `F1-R.retainedFeatures`, `feature:contextmenu`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:contextmenu`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaContextmenuFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaContextmenuFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaContextmenuFeature`

Red verification:
- Run: `swift test --filter MonaContextmenuFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=contextmenu`

Minimal implementation operations:
- `Implement construct the ordered native editor context menu from menu registries.`
- `Register the exact feature identity contextmenu and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaContextmenuFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=contextmenu`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T110.json`

Completion assertions:
- `Feature identity contextmenu is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaContextmenuFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaContextmenuFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T111","recordSha256":"55214a9bf48c0631bc0c946e2e9b3312f4ebfb2d53ca3ef3713b4463ed62d56e"} -->
## P05-T111 — Implement retained feature cursorUndo

Contract: `F1-R.retainedFeatures`, `feature:cursorUndo`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:cursorUndo`

Files to create:
- `Sources/MonaCode/Features/MonaCursorUndoFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaCursorUndoFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaCursorUndoFeature`

Red verification:
- Run: `swift test --filter MonaCursorUndoFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=cursorUndo`

Minimal implementation operations:
- `Implement record and restore cursor-only navigation states independently from model undo.`
- `Register the exact feature identity cursorUndo and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaCursorUndoFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=cursorUndo`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T111.json`

Completion assertions:
- `Feature identity cursorUndo is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaCursorUndoFeature.swift`
- `Tests/MonaCodeTests/Features/MonaCursorUndoFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T112","recordSha256":"a7eed050dee52cc87eb111e84bfc8cfbc924a7584a46e2873b9f7999ed7d232e"} -->
## P05-T112 — Implement retained feature diffEditor

Contract: `F1-R.retainedFeatures`, `feature:diffEditor`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:diffEditor`

Files to create:
- `Sources/MonaCode/Features/MonaDiffEditorFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaDiffEditorFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaDiffEditorFeature`

Red verification:
- Run: `swift test --filter MonaDiffEditorFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=diffEditor`

Minimal implementation operations:
- `Implement register diff-editor commands and contributions over the Phase 07 diff interfaces.`
- `Register the exact feature identity diffEditor and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaDiffEditorFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=diffEditor`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T112.json`

Completion assertions:
- `Feature identity diffEditor is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaDiffEditorFeature.swift`
- `Tests/MonaCodeTests/Features/MonaDiffEditorFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T113","recordSha256":"ee305e27f680b9a3502bfb34e2eb2ce03fa19d8f839b9e364e2f5229308e56da"} -->
## P05-T113 — Implement retained feature diffEditorBreadcrumbs

Contract: `F1-R.retainedFeatures`, `feature:diffEditorBreadcrumbs`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:diffEditorBreadcrumbs`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaDiffEditorBreadcrumbsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaDiffEditorBreadcrumbsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaDiffEditorBreadcrumbsFeature`

Red verification:
- Run: `swift test --filter MonaDiffEditorBreadcrumbsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=diffEditorBreadcrumbs`

Minimal implementation operations:
- `Implement present multi-diff navigation breadcrumbs from host-owned item metadata.`
- `Register the exact feature identity diffEditorBreadcrumbs and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaDiffEditorBreadcrumbsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=diffEditorBreadcrumbs`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T113.json`

Completion assertions:
- `Feature identity diffEditorBreadcrumbs is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaDiffEditorBreadcrumbsFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaDiffEditorBreadcrumbsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T114","recordSha256":"20a6a57d776eb58b79f501a6f56bda110e80a220b170f750c8b04a1dd484e4be"} -->
## P05-T114 — Implement retained feature dnd

Contract: `F1-R.retainedFeatures`, `feature:dnd`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:dnd`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaDndFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaDndFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaDndFeature`

Red verification:
- Run: `swift test --filter MonaDndFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=dnd`

Minimal implementation operations:
- `Implement register drag-and-drop editor behavior over the native drop gateway.`
- `Register the exact feature identity dnd and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaDndFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=dnd`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T114.json`

Completion assertions:
- `Feature identity dnd is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaDndFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaDndFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T115","recordSha256":"2a8c84335cc0cea8c8a882b08f5bce05b4387c43c7f150fd1347f4f97e584a7f"} -->
## P05-T115 — Implement retained feature documentSymbols

Contract: `F1-R.retainedFeatures`, `feature:documentSymbols`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:documentSymbols`

Files to create:
- `Sources/MonaCode/Features/MonaDocumentSymbolsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaDocumentSymbolsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaDocumentSymbolsFeature`

Red verification:
- Run: `swift test --filter MonaDocumentSymbolsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=documentSymbols`

Minimal implementation operations:
- `Implement request, version-gate, sort, and expose document-symbol provider results.`
- `Register the exact feature identity documentSymbols and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaDocumentSymbolsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=documentSymbols`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T115.json`

Completion assertions:
- `Feature identity documentSymbols is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaDocumentSymbolsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaDocumentSymbolsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T116","recordSha256":"c3ace186ec83d8dd8a7a1c98655f312376bbb294fefac3888c1f91499c448b17"} -->
## P05-T116 — Implement retained feature dropOrPasteInto

Contract: `F1-R.retainedFeatures`, `feature:dropOrPasteInto`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:dropOrPasteInto`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaDropOrPasteIntoFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaDropOrPasteIntoFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaDropOrPasteIntoFeature`

Red verification:
- Run: `swift test --filter MonaDropOrPasteIntoFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=dropOrPasteInto`

Minimal implementation operations:
- `Implement select and apply explicit drop-or-paste edit proposals.`
- `Register the exact feature identity dropOrPasteInto and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaDropOrPasteIntoFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=dropOrPasteInto`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T116.json`

Completion assertions:
- `Feature identity dropOrPasteInto is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaDropOrPasteIntoFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaDropOrPasteIntoFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T117","recordSha256":"9acfbb78c28ff16e27bcc66bc623822f557153fd7fb792752160291271e2b35f"} -->
## P05-T117 — Implement retained feature find

Contract: `F1-R.retainedFeatures`, `feature:find`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:find`

Files to create:
- `Sources/MonaCode/Features/MonaFindFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaFindFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaFindFeature`

Red verification:
- Run: `swift test --filter MonaFindFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=find`

Minimal implementation operations:
- `Implement run literal and RegExp find and replace with exact match, scope, and history semantics.`
- `Register the exact feature identity find and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaFindFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=find`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T117.json`

Completion assertions:
- `Feature identity find is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaFindFeature.swift`
- `Tests/MonaCodeTests/Features/MonaFindFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T118","recordSha256":"4c727337bff6690cde96a853ad7628dd8c372157727e5b11ee394da504ba4e86"} -->
## P05-T118 — Implement retained feature floatingMenu

Contract: `F1-R.retainedFeatures`, `feature:floatingMenu`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:floatingMenu`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaFloatingMenuFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaFloatingMenuFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaFloatingMenuFeature`

Red verification:
- Run: `swift test --filter MonaFloatingMenuFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=floatingMenu`

Minimal implementation operations:
- `Implement present the retained floating action menu without web layout dependencies.`
- `Register the exact feature identity floatingMenu and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaFloatingMenuFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=floatingMenu`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T118.json`

Completion assertions:
- `Feature identity floatingMenu is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaFloatingMenuFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaFloatingMenuFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T119","recordSha256":"6d6f294d117fc6ad4fe84c521c76ecb638b263d01e776f006b5b35ddd9681d2f"} -->
## P05-T119 — Implement retained feature folding

Contract: `F1-R.retainedFeatures`, `feature:folding`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:folding`

Files to create:
- `Sources/MonaCode/Features/MonaFoldingFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaFoldingFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaFoldingFeature`

Red verification:
- Run: `swift test --filter MonaFoldingFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=folding`

Minimal implementation operations:
- `Implement combine manual, indentation, marker, and provider folding ranges with exact precedence.`
- `Register the exact feature identity folding and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaFoldingFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=folding`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T119.json`

Completion assertions:
- `Feature identity folding is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaFoldingFeature.swift`
- `Tests/MonaCodeTests/Features/MonaFoldingFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T120","recordSha256":"94614626e7cb6bf352ded5899cd05ab7abfb2c63a414b7e468aa3034462bed48"} -->
## P05-T120 — Implement retained feature fontZoom

Contract: `F1-R.retainedFeatures`, `feature:fontZoom`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:fontZoom`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaFontZoomFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaFontZoomFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaFontZoomFeature`

Red verification:
- Run: `swift test --filter MonaFontZoomFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=fontZoom`

Minimal implementation operations:
- `Implement apply bounded editor font zoom and invalidate the exact layout stamp domains.`
- `Register the exact feature identity fontZoom and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaFontZoomFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=fontZoom`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T120.json`

Completion assertions:
- `Feature identity fontZoom is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaFontZoomFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaFontZoomFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T121","recordSha256":"8ce8a889cdf1dbdeba794d5ca211a43031167c668f977e3153f0a3a5a6c32d83"} -->
## P05-T121 — Implement retained feature format

Contract: `F1-R.retainedFeatures`, `feature:format`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:format`

Files to create:
- `Sources/MonaCode/Features/MonaFormatFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaFormatFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaFormatFeature`

Red verification:
- Run: `swift test --filter MonaFormatFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=format`

Minimal implementation operations:
- `Implement run document, range, and on-type formatting providers and apply accepted edits.`
- `Register the exact feature identity format and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaFormatFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=format`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T121.json`

Completion assertions:
- `Feature identity format is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaFormatFeature.swift`
- `Tests/MonaCodeTests/Features/MonaFormatFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T122","recordSha256":"59573b92ea4dfebf3d55fc3bc6bb2a3a8f18b3961898a93c45c827f838377f6d"} -->
## P05-T122 — Implement retained feature gotoError

Contract: `F1-R.retainedFeatures`, `feature:gotoError`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:gotoError`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaGotoErrorFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaGotoErrorFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaGotoErrorFeature`

Red verification:
- Run: `swift test --filter MonaGotoErrorFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=gotoError`

Minimal implementation operations:
- `Implement navigate marker severities and announce the selected diagnostic.`
- `Register the exact feature identity gotoError and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaGotoErrorFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=gotoError`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T122.json`

Completion assertions:
- `Feature identity gotoError is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaGotoErrorFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaGotoErrorFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T123","recordSha256":"b1e4fc2d1159ce45eb11cc55e87bf0178481ba13bc9a39eedc2a0ddd6105de32"} -->
## P05-T123 — Implement retained feature gotoLine

Contract: `F1-R.retainedFeatures`, `feature:gotoLine`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:gotoLine`

Files to create:
- `Sources/MonaCode/Features/MonaGotoLineFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaGotoLineFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaGotoLineFeature`

Red verification:
- Run: `swift test --filter MonaGotoLineFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=gotoLine`

Minimal implementation operations:
- `Implement parse line and column input and reveal the validated model position.`
- `Register the exact feature identity gotoLine and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaGotoLineFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=gotoLine`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T123.json`

Completion assertions:
- `Feature identity gotoLine is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaGotoLineFeature.swift`
- `Tests/MonaCodeTests/Features/MonaGotoLineFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T124","recordSha256":"f0905fbb9896c6bc419144407dad46b87964c11d268092915fe6b04b6083ecfd"} -->
## P05-T124 — Implement retained feature gotoSymbol

Contract: `F1-R.retainedFeatures`, `feature:gotoSymbol`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:gotoSymbol`

Files to create:
- `Sources/MonaCode/Features/MonaGotoSymbolFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaGotoSymbolFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaGotoSymbolFeature`

Red verification:
- Run: `swift test --filter MonaGotoSymbolFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=gotoSymbol`

Minimal implementation operations:
- `Implement filter and navigate document symbols while preserving provider order.`
- `Register the exact feature identity gotoSymbol and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaGotoSymbolFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=gotoSymbol`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T124.json`

Completion assertions:
- `Feature identity gotoSymbol is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaGotoSymbolFeature.swift`
- `Tests/MonaCodeTests/Features/MonaGotoSymbolFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T125","recordSha256":"35854461fcce7017f39e26083bc850799a06f378cc9d3eeeaf6fc0d3190a787e"} -->
## P05-T125 — Implement retained feature hover

Contract: `F1-R.retainedFeatures`, `feature:hover`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:hover`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaHoverFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaHoverFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaHoverFeature`

Red verification:
- Run: `swift test --filter MonaHoverFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=hover`

Minimal implementation operations:
- `Implement merge, render, update verbosity, and release hover provider results.`
- `Register the exact feature identity hover and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaHoverFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=hover`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T125.json`

Completion assertions:
- `Feature identity hover is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaHoverFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaHoverFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T126","recordSha256":"d3e19b684320aca878e2febc9e35b5b5c97e336bd8a6981b0eec4748497ed88f"} -->
## P05-T126 — Implement retained feature indentation

Contract: `F1-R.retainedFeatures`, `feature:indentation`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:indentation`

Files to create:
- `Sources/MonaCode/Features/MonaIndentationFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaIndentationFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaIndentationFeature`

Red verification:
- Run: `swift test --filter MonaIndentationFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=indentation`

Minimal implementation operations:
- `Implement detect, convert, and reindent whitespace from explicit model options.`
- `Register the exact feature identity indentation and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaIndentationFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=indentation`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T126.json`

Completion assertions:
- `Feature identity indentation is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaIndentationFeature.swift`
- `Tests/MonaCodeTests/Features/MonaIndentationFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T127","recordSha256":"d5e537db1821d1c62d570e984e2d712af96d28bc97ae6b9428b1520c6eecc1a1"} -->
## P05-T127 — Implement retained feature inlayHints

Contract: `F1-R.retainedFeatures`, `feature:inlayHints`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:inlayHints`

Files to create:
- `Sources/MonaCode/Features/MonaInlayHintsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaInlayHintsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaInlayHintsFeature`

Red verification:
- Run: `swift test --filter MonaInlayHintsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=inlayHints`

Minimal implementation operations:
- `Implement request, resolve, lay out, and release version-gated inlay hints.`
- `Register the exact feature identity inlayHints and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaInlayHintsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=inlayHints`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T127.json`

Completion assertions:
- `Feature identity inlayHints is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaInlayHintsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaInlayHintsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T128","recordSha256":"b3bb86f640f14f945223533603e6f8d0adcf6b610812a5eb9d475fa98e6415bd"} -->
## P05-T128 — Implement retained feature inlineCompletions

Contract: `F1-R.retainedFeatures`, `feature:inlineCompletions`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:inlineCompletions`

Files to create:
- `Sources/MonaCode/Features/MonaInlineCompletionsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaInlineCompletionsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaInlineCompletionsFeature`

Red verification:
- Run: `swift test --filter MonaInlineCompletionsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=inlineCompletions`

Minimal implementation operations:
- `Implement request, update, partially accept, accept, and release inline completions.`
- `Register the exact feature identity inlineCompletions and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaInlineCompletionsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=inlineCompletions`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T128.json`

Completion assertions:
- `Feature identity inlineCompletions is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaInlineCompletionsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaInlineCompletionsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T129","recordSha256":"6c763334829a9a17c5c25751ea1c4d4bc5f9611023b6241deb90996e492ff1ba"} -->
## P05-T129 — Implement retained feature inlineProgress

Contract: `F1-R.retainedFeatures`, `feature:inlineProgress`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:inlineProgress`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaInlineProgressFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaInlineProgressFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaInlineProgressFeature`

Red verification:
- Run: `swift test --filter MonaInlineProgressFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=inlineProgress`

Minimal implementation operations:
- `Implement render retained inline progress feedback without notification-center UI.`
- `Register the exact feature identity inlineProgress and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaInlineProgressFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=inlineProgress`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T129.json`

Completion assertions:
- `Feature identity inlineProgress is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaInlineProgressFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaInlineProgressFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T130","recordSha256":"e6982438507d3db44a5a255d0f1dd61f0e3719455b3cb03d927c032d44c7e1e8"} -->
## P05-T130 — Implement retained feature inPlaceReplace

Contract: `F1-R.retainedFeatures`, `feature:inPlaceReplace`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:inPlaceReplace`

Files to create:
- `Sources/MonaCode/Features/MonaInPlaceReplaceFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaInPlaceReplaceFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaInPlaceReplaceFeature`

Red verification:
- Run: `swift test --filter MonaInPlaceReplaceFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=inPlaceReplace`

Minimal implementation operations:
- `Implement replace the active word from exact previous and next candidate calculations.`
- `Register the exact feature identity inPlaceReplace and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaInPlaceReplaceFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=inPlaceReplace`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T130.json`

Completion assertions:
- `Feature identity inPlaceReplace is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaInPlaceReplaceFeature.swift`
- `Tests/MonaCodeTests/Features/MonaInPlaceReplaceFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T131","recordSha256":"0f82689d6df7fd6ef1b6ba96caf67144656980895321bb93f8580b5a234fcc27"} -->
## P05-T131 — Implement retained feature insertFinalNewLine

Contract: `F1-R.retainedFeatures`, `feature:insertFinalNewLine`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:insertFinalNewLine`

Files to create:
- `Sources/MonaCode/Features/MonaInsertFinalNewLineFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaInsertFinalNewLineFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaInsertFinalNewLineFeature`

Red verification:
- Run: `swift test --filter MonaInsertFinalNewLineFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=insertFinalNewLine`

Minimal implementation operations:
- `Implement insert a final line terminator under explicit command control.`
- `Register the exact feature identity insertFinalNewLine and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaInsertFinalNewLineFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=insertFinalNewLine`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T131.json`

Completion assertions:
- `Feature identity insertFinalNewLine is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaInsertFinalNewLineFeature.swift`
- `Tests/MonaCodeTests/Features/MonaInsertFinalNewLineFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T132","recordSha256":"3a3079ad7aeea689a3a16762ea375b1a3fc42f47cd259fd7a14868302362c552"} -->
## P05-T132 — Implement retained feature inspectTokens

Contract: `F1-R.retainedFeatures`, `feature:inspectTokens`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:inspectTokens`

Files to create:
- `Sources/MonaCode/Features/MonaInspectTokensFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaInspectTokensFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaInspectTokensFeature`

Red verification:
- Run: `swift test --filter MonaInspectTokensFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=inspectTokens`

Minimal implementation operations:
- `Implement expose token, scope, foreground, background, and source inspection data.`
- `Register the exact feature identity inspectTokens and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaInspectTokensFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=inspectTokens`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T132.json`

Completion assertions:
- `Feature identity inspectTokens is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaInspectTokensFeature.swift`
- `Tests/MonaCodeTests/Features/MonaInspectTokensFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T133","recordSha256":"98a49bbd0508c224a002aeb6d5b2a6b02e583f67a0b0b44aadacbfe0a25bfc34"} -->
## P05-T133 — Implement retained feature lineSelection

Contract: `F1-R.retainedFeatures`, `feature:lineSelection`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:lineSelection`

Files to create:
- `Sources/MonaCode/Features/MonaLineSelectionFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaLineSelectionFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaLineSelectionFeature`

Red verification:
- Run: `swift test --filter MonaLineSelectionFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=lineSelection`

Minimal implementation operations:
- `Implement create and extend whole-line selections with final-line edge handling.`
- `Register the exact feature identity lineSelection and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaLineSelectionFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=lineSelection`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T133.json`

Completion assertions:
- `Feature identity lineSelection is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaLineSelectionFeature.swift`
- `Tests/MonaCodeTests/Features/MonaLineSelectionFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T134","recordSha256":"388ce3dbc2b130d92cdcd2c9231cd45ace8451e617d051c81cd45d013b5e6080"} -->
## P05-T134 — Implement retained feature linesOperations

Contract: `F1-R.retainedFeatures`, `feature:linesOperations`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:linesOperations`

Files to create:
- `Sources/MonaCode/Features/MonaLinesOperationsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaLinesOperationsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaLinesOperationsFeature`

Red verification:
- Run: `swift test --filter MonaLinesOperationsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=linesOperations`

Minimal implementation operations:
- `Implement move, copy, delete, join, sort, trim, transpose, and duplicate lines transactionally.`
- `Register the exact feature identity linesOperations and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaLinesOperationsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=linesOperations`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T134.json`

Completion assertions:
- `Feature identity linesOperations is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaLinesOperationsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaLinesOperationsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T135","recordSha256":"96a32b52738122e0ca5dee340fbc27ad50b0b483f5a6f8838f1bdc21070da28f"} -->
## P05-T135 — Implement retained feature linkedEditing

Contract: `F1-R.retainedFeatures`, `feature:linkedEditing`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:linkedEditing`

Files to create:
- `Sources/MonaCode/Features/MonaLinkedEditingFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaLinkedEditingFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaLinkedEditingFeature`

Red verification:
- Run: `swift test --filter MonaLinkedEditingFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=linkedEditing`

Minimal implementation operations:
- `Implement mirror linked-editing ranges under provider version and cancellation gates.`
- `Register the exact feature identity linkedEditing and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaLinkedEditingFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=linkedEditing`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T135.json`

Completion assertions:
- `Feature identity linkedEditing is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaLinkedEditingFeature.swift`
- `Tests/MonaCodeTests/Features/MonaLinkedEditingFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T136","recordSha256":"016f5407dd16bede1d85f95116a5e364ac244e5d186917e609a0d8a8a2aa8931"} -->
## P05-T136 — Implement retained feature links

Contract: `F1-R.retainedFeatures`, `feature:links`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:links`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaLinksFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaLinksFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaLinksFeature`

Red verification:
- Run: `swift test --filter MonaLinksFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=links`

Minimal implementation operations:
- `Implement request, resolve, underline, activate, and release document links.`
- `Register the exact feature identity links and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaLinksFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=links`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T136.json`

Completion assertions:
- `Feature identity links is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaLinksFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaLinksFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T137","recordSha256":"86c8a2fd3f6f1ce44bf731cf812d1d7254c5c212a3c0b1cdc7d4d0ab4f5c4517"} -->
## P05-T137 — Implement retained feature longLinesHelper

Contract: `F1-R.retainedFeatures`, `feature:longLinesHelper`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:longLinesHelper`

Files to create:
- `Sources/MonaCode/Features/MonaLongLinesHelperFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaLongLinesHelperFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaLongLinesHelperFeature`

Red verification:
- Run: `swift test --filter MonaLongLinesHelperFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=longLinesHelper`

Minimal implementation operations:
- `Implement enforce the configured long-line rendering cutoff and explicit unlimited mode.`
- `Register the exact feature identity longLinesHelper and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaLongLinesHelperFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=longLinesHelper`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T137.json`

Completion assertions:
- `Feature identity longLinesHelper is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaLongLinesHelperFeature.swift`
- `Tests/MonaCodeTests/Features/MonaLongLinesHelperFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T138","recordSha256":"cf872a471429d0f9ab689cf13bd1ad666792eb53f6b677df403fa05775f25b2c"} -->
## P05-T138 — Implement retained feature middleScroll

Contract: `F1-R.retainedFeatures`, `feature:middleScroll`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:middleScroll`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaMiddleScrollFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaMiddleScrollFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaMiddleScrollFeature`

Red verification:
- Run: `swift test --filter MonaMiddleScrollFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=middleScroll`

Minimal implementation operations:
- `Implement implement native middle-button scrolling with bounded velocity and cancellation.`
- `Register the exact feature identity middleScroll and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaMiddleScrollFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=middleScroll`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T138.json`

Completion assertions:
- `Feature identity middleScroll is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaMiddleScrollFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaMiddleScrollFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T139","recordSha256":"d9511ae5238a89af40cf0393df8058cf6e35eaa69a391caecba9776b48039fef"} -->
## P05-T139 — Implement retained feature multicursor

Contract: `F1-R.retainedFeatures`, `feature:multicursor`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:multicursor`

Files to create:
- `Sources/MonaCode/Features/MonaMulticursorFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaMulticursorFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaMulticursorFeature`

Red verification:
- Run: `swift test --filter MonaMulticursorFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=multicursor`

Minimal implementation operations:
- `Implement add, remove, merge, select, and edit 1, 100, and 10000 cursors in stable order.`
- `Register the exact feature identity multicursor and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaMulticursorFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=multicursor`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T139.json`

Completion assertions:
- `Feature identity multicursor is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaMulticursorFeature.swift`
- `Tests/MonaCodeTests/Features/MonaMulticursorFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T140","recordSha256":"5290ada1ddcbcf67d78ef7d703fd04e1a6e56eaf1e13324878576e3dff6d19ca"} -->
## P05-T140 — Implement retained feature parameterHints

Contract: `F1-R.retainedFeatures`, `feature:parameterHints`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:parameterHints`

Files to create:
- `Sources/MonaCode/Features/MonaParameterHintsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaParameterHintsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaParameterHintsFeature`

Red verification:
- Run: `swift test --filter MonaParameterHintsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=parameterHints`

Minimal implementation operations:
- `Implement trigger, cycle, update, and dismiss signature-help results.`
- `Register the exact feature identity parameterHints and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaParameterHintsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=parameterHints`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T140.json`

Completion assertions:
- `Feature identity parameterHints is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaParameterHintsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaParameterHintsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T141","recordSha256":"381d6f5780192af206fa5ffa184b982525242b9c55373585a90d2b99ff054a33"} -->
## P05-T141 — Implement retained feature placeholderText

Contract: `F1-R.retainedFeatures`, `feature:placeholderText`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:placeholderText`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaPlaceholderTextFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaPlaceholderTextFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaPlaceholderTextFeature`

Red verification:
- Run: `swift test --filter MonaPlaceholderTextFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=placeholderText`

Minimal implementation operations:
- `Implement render placeholder presentation only while the model is empty.`
- `Register the exact feature identity placeholderText and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaPlaceholderTextFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=placeholderText`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T141.json`

Completion assertions:
- `Feature identity placeholderText is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaPlaceholderTextFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaPlaceholderTextFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T142","recordSha256":"ae9ec5a090e38f32cd201235d11b5a7fd917afeb43283b15bf3ff93e2dd1b417"} -->
## P05-T142 — Implement retained feature quickCommand

Contract: `F1-R.retainedFeatures`, `feature:quickCommand`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:quickCommand`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaQuickCommandFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaQuickCommandFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaQuickCommandFeature`

Red verification:
- Run: `swift test --filter MonaQuickCommandFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=quickCommand`

Minimal implementation operations:
- `Implement filter and invoke registered editor commands with exact enablement.`
- `Register the exact feature identity quickCommand and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaQuickCommandFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=quickCommand`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T142.json`

Completion assertions:
- `Feature identity quickCommand is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaQuickCommandFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaQuickCommandFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T143","recordSha256":"cba258b1739ddaf384e9a062e5f04dd8979196fe6616cca7d555d2d9c39575e1"} -->
## P05-T143 — Implement retained feature quickHelp

Contract: `F1-R.retainedFeatures`, `feature:quickHelp`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:quickHelp`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaQuickHelpFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaQuickHelpFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaQuickHelpFeature`

Red verification:
- Run: `swift test --filter MonaQuickHelpFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=quickHelp`

Minimal implementation operations:
- `Implement present retained keyboard and accessibility help from localized messages.`
- `Register the exact feature identity quickHelp and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaQuickHelpFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=quickHelp`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T143.json`

Completion assertions:
- `Feature identity quickHelp is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaQuickHelpFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaQuickHelpFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T144","recordSha256":"aeaee6f2439616c19730e67a14069d785ad629ab92489e15fe8f9084f5507002"} -->
## P05-T144 — Implement retained feature quickOutline

Contract: `F1-R.retainedFeatures`, `feature:quickOutline`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:quickOutline`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaQuickOutlineFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaQuickOutlineFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaQuickOutlineFeature`

Red verification:
- Run: `swift test --filter MonaQuickOutlineFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=quickOutline`

Minimal implementation operations:
- `Implement filter, group, and navigate document symbols in the quick outline.`
- `Register the exact feature identity quickOutline and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaQuickOutlineFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=quickOutline`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T144.json`

Completion assertions:
- `Feature identity quickOutline is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaQuickOutlineFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaQuickOutlineFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T145","recordSha256":"7855e1c6612a5036a29872c4ac02ee8328dcd46a7b198f50010a6f33ed872955"} -->
## P05-T145 — Implement retained feature readOnlyMessage

Contract: `F1-R.retainedFeatures`, `feature:readOnlyMessage`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:readOnlyMessage`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaReadOnlyMessageFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaReadOnlyMessageFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaReadOnlyMessageFeature`

Red verification:
- Run: `swift test --filter MonaReadOnlyMessageFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=readOnlyMessage`

Minimal implementation operations:
- `Implement present explicit localized feedback for rejected read-only mutations.`
- `Register the exact feature identity readOnlyMessage and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaReadOnlyMessageFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=readOnlyMessage`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T145.json`

Completion assertions:
- `Feature identity readOnlyMessage is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaReadOnlyMessageFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaReadOnlyMessageFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T146","recordSha256":"e7f125a756a82fd6d148b09ef48ef1513f59d61233468f37c3a78e671a04ee08"} -->
## P05-T146 — Implement retained feature referenceSearch

Contract: `F1-R.retainedFeatures`, `feature:referenceSearch`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:referenceSearch`

Files to create:
- `Sources/MonaCode/Features/MonaReferenceSearchFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaReferenceSearchFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaReferenceSearchFeature`

Red verification:
- Run: `swift test --filter MonaReferenceSearchFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=referenceSearch`

Minimal implementation operations:
- `Implement stream, group, navigate, and cancel reference provider results.`
- `Register the exact feature identity referenceSearch and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaReferenceSearchFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=referenceSearch`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T146.json`

Completion assertions:
- `Feature identity referenceSearch is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaReferenceSearchFeature.swift`
- `Tests/MonaCodeTests/Features/MonaReferenceSearchFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T147","recordSha256":"830b4d9de82adca952af96a4c226273e6b88e73786aa05966fb4fe11974950f0"} -->
## P05-T147 — Implement retained feature rename

Contract: `F1-R.retainedFeatures`, `feature:rename`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:rename`

Files to create:
- `Sources/MonaCode/Features/MonaRenameFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaRenameFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaRenameFeature`

Red verification:
- Run: `swift test --filter MonaRenameFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=rename`

Minimal implementation operations:
- `Implement prepare rename, collect workspace edits, preview failures, and apply atomically.`
- `Register the exact feature identity rename and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaRenameFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=rename`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T147.json`

Completion assertions:
- `Feature identity rename is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaRenameFeature.swift`
- `Tests/MonaCodeTests/Features/MonaRenameFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T148","recordSha256":"465bd88171bce9f25f8f5c3fd3c0e332a4365fc2f9a997613850a111e2727fb8"} -->
## P05-T148 — Implement retained feature sectionHeaders

Contract: `F1-R.retainedFeatures`, `feature:sectionHeaders`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:sectionHeaders`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaSectionHeadersFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaSectionHeadersFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaSectionHeadersFeature`

Red verification:
- Run: `swift test --filter MonaSectionHeadersFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=sectionHeaders`

Minimal implementation operations:
- `Implement derive and render section-header decorations from configured patterns.`
- `Register the exact feature identity sectionHeaders and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaSectionHeadersFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=sectionHeaders`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T148.json`

Completion assertions:
- `Feature identity sectionHeaders is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaSectionHeadersFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaSectionHeadersFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T149","recordSha256":"6104df1d03fad3f2b9ff930884f73cf65d087fec3da734aa8f10a5202f0f1492"} -->
## P05-T149 — Implement retained feature semanticTokens

Contract: `F1-R.retainedFeatures`, `feature:semanticTokens`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:semanticTokens`

Files to create:
- `Sources/MonaCode/Features/MonaSemanticTokensFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaSemanticTokensFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaSemanticTokensFeature`

Red verification:
- Run: `swift test --filter MonaSemanticTokensFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=semanticTokens`

Minimal implementation operations:
- `Implement apply full and delta semantic-token results by version and result identifier.`
- `Register the exact feature identity semanticTokens and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaSemanticTokensFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=semanticTokens`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T149.json`

Completion assertions:
- `Feature identity semanticTokens is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaSemanticTokensFeature.swift`
- `Tests/MonaCodeTests/Features/MonaSemanticTokensFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T150","recordSha256":"f291ae5426789f59c3972e4952c413e9cd37d25d0fff958461a2bd011874272c"} -->
## P05-T150 — Implement retained feature smartSelect

Contract: `F1-R.retainedFeatures`, `feature:smartSelect`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:smartSelect`

Files to create:
- `Sources/MonaCode/Features/MonaSmartSelectFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaSmartSelectFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaSmartSelectFeature`

Red verification:
- Run: `swift test --filter MonaSmartSelectFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=smartSelect`

Minimal implementation operations:
- `Implement expand and shrink provider selection ranges while retaining orientation.`
- `Register the exact feature identity smartSelect and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaSmartSelectFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=smartSelect`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T150.json`

Completion assertions:
- `Feature identity smartSelect is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaSmartSelectFeature.swift`
- `Tests/MonaCodeTests/Features/MonaSmartSelectFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T151","recordSha256":"242505f612ac1d47af1b76455b0e67633a3b25ca963fc7af85a0d6c1ef6d17f3"} -->
## P05-T151 — Implement retained feature snippet

Contract: `F1-R.retainedFeatures`, `feature:snippet`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:snippet`

Files to create:
- `Sources/MonaCode/Features/MonaSnippetFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaSnippetFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaSnippetFeature`

Red verification:
- Run: `swift test --filter MonaSnippetFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=snippet`

Minimal implementation operations:
- `Implement insert and navigate snippet sessions using the Phase 06 snippet engine.`
- `Register the exact feature identity snippet and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaSnippetFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=snippet`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T151.json`

Completion assertions:
- `Feature identity snippet is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaSnippetFeature.swift`
- `Tests/MonaCodeTests/Features/MonaSnippetFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T152","recordSha256":"207196abc4e33a878e6b42aef6414b4d9e4a10151c6841c9144800291953f841"} -->
## P05-T152 — Implement retained feature stickyScroll

Contract: `F1-R.retainedFeatures`, `feature:stickyScroll`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:stickyScroll`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaStickyScrollFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaStickyScrollFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaStickyScrollFeature`

Red verification:
- Run: `swift test --filter MonaStickyScrollFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=stickyScroll`

Minimal implementation operations:
- `Implement project nested symbol and folding context into sticky viewport rows.`
- `Register the exact feature identity stickyScroll and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaStickyScrollFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=stickyScroll`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T152.json`

Completion assertions:
- `Feature identity stickyScroll is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaStickyScrollFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaStickyScrollFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T153","recordSha256":"5467b293326982805320a0b4d863b63c18c9f25acaee85f9626159d1c3d77f06"} -->
## P05-T153 — Implement retained feature suggest

Contract: `F1-R.retainedFeatures`, `feature:suggest`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:suggest`

Files to create:
- `Sources/MonaCode/Features/MonaSuggestFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaSuggestFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaSuggestFeature`

Red verification:
- Run: `swift test --filter MonaSuggestFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=suggest`

Minimal implementation operations:
- `Implement trigger, filter, rank, resolve, accept, release, and remember completion items.`
- `Register the exact feature identity suggest and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaSuggestFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=suggest`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T153.json`

Completion assertions:
- `Feature identity suggest is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaSuggestFeature.swift`
- `Tests/MonaCodeTests/Features/MonaSuggestFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T154","recordSha256":"3299c1452be6e48c6a97ea74c0458c3c434d6050339610c1d5a9509cacd585aa"} -->
## P05-T154 — Implement retained feature toggleHighContrast

Contract: `F1-R.retainedFeatures`, `feature:toggleHighContrast`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:toggleHighContrast`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaToggleHighContrastFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaToggleHighContrastFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaToggleHighContrastFeature`

Red verification:
- Run: `swift test --filter MonaToggleHighContrastFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=toggleHighContrast`

Minimal implementation operations:
- `Implement toggle the explicit high-contrast theme profile and invalidate paint state.`
- `Register the exact feature identity toggleHighContrast and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaToggleHighContrastFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=toggleHighContrast`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T154.json`

Completion assertions:
- `Feature identity toggleHighContrast is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaToggleHighContrastFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaToggleHighContrastFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T155","recordSha256":"46aa50b26e585f0f440a2caea72e5d282dab1387929871e67188da101c0e7614"} -->
## P05-T155 — Implement retained feature toggleTabFocusMode

Contract: `F1-R.retainedFeatures`, `feature:toggleTabFocusMode`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:toggleTabFocusMode`

Files to create:
- `Sources/MonaCodeAppKit/Features/MonaToggleTabFocusModeFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Features/MonaToggleTabFocusModeFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaToggleTabFocusModeFeature`

Red verification:
- Run: `swift test --filter MonaToggleTabFocusModeFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=toggleTabFocusMode`

Minimal implementation operations:
- `Implement switch Tab between editor command handling and native focus traversal.`
- `Register the exact feature identity toggleTabFocusMode and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaToggleTabFocusModeFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=toggleTabFocusMode`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T155.json`

Completion assertions:
- `Feature identity toggleTabFocusMode is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCodeAppKit/Features/MonaToggleTabFocusModeFeature.swift`
- `Tests/MonaCodeAppKitTests/Features/MonaToggleTabFocusModeFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T156","recordSha256":"08bd9df0bd59d22891c090eee985b3ac8271438407d562041a079cb679994b95"} -->
## P05-T156 — Implement retained feature tokenization

Contract: `F1-R.retainedFeatures`, `feature:tokenization`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:tokenization`

Files to create:
- `Sources/MonaCode/Features/MonaTokenizationFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaTokenizationFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaTokenizationFeature`

Red verification:
- Run: `swift test --filter MonaTokenizationFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=tokenization`

Minimal implementation operations:
- `Implement consume direct token providers and retain plain-text tokens when none is attached.`
- `Register the exact feature identity tokenization and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaTokenizationFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=tokenization`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T156.json`

Completion assertions:
- `Feature identity tokenization is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaTokenizationFeature.swift`
- `Tests/MonaCodeTests/Features/MonaTokenizationFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T157","recordSha256":"8151fb7305d9695a59f2afb5cbabab8fed9688c7496aa43851218bb411572859"} -->
## P05-T157 — Implement retained feature unicodeHighlighter

Contract: `F1-R.retainedFeatures`, `feature:unicodeHighlighter`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:unicodeHighlighter`

Files to create:
- `Sources/MonaCode/Features/MonaUnicodeHighlighterFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaUnicodeHighlighterFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaUnicodeHighlighterFeature`

Red verification:
- Run: `swift test --filter MonaUnicodeHighlighterFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=unicodeHighlighter`

Minimal implementation operations:
- `Implement detect configured invisible, ambiguous, and non-basic Unicode spans.`
- `Register the exact feature identity unicodeHighlighter and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaUnicodeHighlighterFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=unicodeHighlighter`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T157.json`

Completion assertions:
- `Feature identity unicodeHighlighter is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaUnicodeHighlighterFeature.swift`
- `Tests/MonaCodeTests/Features/MonaUnicodeHighlighterFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T158","recordSha256":"51de9ce615a9a20d41e43d4886a5aa9b25f32450c0695267e6f0fd6075c0c39c"} -->
## P05-T158 — Implement retained feature unusualLineTerminators

Contract: `F1-R.retainedFeatures`, `feature:unusualLineTerminators`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:unusualLineTerminators`

Files to create:
- `Sources/MonaCode/Features/MonaUnusualLineTerminatorsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaUnusualLineTerminatorsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaUnusualLineTerminatorsFeature`

Red verification:
- Run: `swift test --filter MonaUnusualLineTerminatorsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=unusualLineTerminators`

Minimal implementation operations:
- `Implement detect and explicitly remove unusual line terminators transactionally.`
- `Register the exact feature identity unusualLineTerminators and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaUnusualLineTerminatorsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=unusualLineTerminators`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T158.json`

Completion assertions:
- `Feature identity unusualLineTerminators is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaUnusualLineTerminatorsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaUnusualLineTerminatorsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T159","recordSha256":"66b730c894b35e71b95609a9dc24b59f4b5b1e2f3d28bdb7f67f4b874feeab6b"} -->
## P05-T159 — Implement retained feature wordHighlighter

Contract: `F1-R.retainedFeatures`, `feature:wordHighlighter`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:wordHighlighter`

Files to create:
- `Sources/MonaCode/Features/MonaWordHighlighterFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaWordHighlighterFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaWordHighlighterFeature`

Red verification:
- Run: `swift test --filter MonaWordHighlighterFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=wordHighlighter`

Minimal implementation operations:
- `Implement combine textual and provider document highlights with version gating.`
- `Register the exact feature identity wordHighlighter and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaWordHighlighterFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=wordHighlighter`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T159.json`

Completion assertions:
- `Feature identity wordHighlighter is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaWordHighlighterFeature.swift`
- `Tests/MonaCodeTests/Features/MonaWordHighlighterFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T160","recordSha256":"8fe421848e0e05f0e26c9bda76f77b9762ef15421ab635a42ce80c2ee23d2d2c"} -->
## P05-T160 — Implement retained feature wordOperations

Contract: `F1-R.retainedFeatures`, `feature:wordOperations`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:wordOperations`

Files to create:
- `Sources/MonaCode/Features/MonaWordOperationsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaWordOperationsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaWordOperationsFeature`

Red verification:
- Run: `swift test --filter MonaWordOperationsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=wordOperations`

Minimal implementation operations:
- `Implement move, delete, and transform by the frozen word boundary profile.`
- `Register the exact feature identity wordOperations and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaWordOperationsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=wordOperations`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T160.json`

Completion assertions:
- `Feature identity wordOperations is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaWordOperationsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaWordOperationsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T161","recordSha256":"284bc2647ec29996d72e1d72d66e7517bd9d501cd4dbd9b6dbe9590fd884e13b"} -->
## P05-T161 — Implement retained feature wordPartOperations

Contract: `F1-R.retainedFeatures`, `feature:wordPartOperations`, `C05`

Dependencies:
- `P05-T002`
- `P05-T012`
- `P05-T013`

Ownership selectors:
- `feature:wordPartOperations`

Files to create:
- `Sources/MonaCode/Features/MonaWordPartOperationsFeature.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Features/MonaWordPartOperationsFeatureTests.swift`

Interfaces consumed:
- `MonaFeatureRegistry`
- `MonaCommandRegistry`
- `MonaOptionSnapshot`
- `MonaPublicationGate`

Interfaces produced:
- `MonaWordPartOperationsFeature`

Red verification:
- Run: `swift test --filter MonaWordPartOperationsFeatureTests/testContractBehavior`
  - Expected exit: `1`
  - Expected output includes: `FEATURE_CONTRACT_MISMATCH id=wordPartOperations`

Minimal implementation operations:
- `Implement move and delete by camel, underscore, digit, and punctuation word parts.`
- `Register the exact feature identity wordPartOperations and its declared commands, actions, contributions, options, menus, and keybindings.`
- `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

Green verification:
- Run: `swift test --filter MonaWordPartOperationsFeatureTests`
  - Expected exit: `0`
  - Expected output includes: `FEATURE_CONTRACT_OK id=wordPartOperations`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T161.json`

Completion assertions:
- `Feature identity wordPartOperations is present exactly once.`
- `Focused behavior and disposal tests pass.`
- `Unavailable provider capability degrades without fabricating language behavior.`

Commit boundary:
- `Sources/MonaCode/Features/MonaWordPartOperationsFeature.swift`
- `Tests/MonaCodeTests/Features/MonaWordPartOperationsFeatureTests.swift`

<!-- monacode-plan-task:{"id":"P05-T190","recordSha256":"67c3a4a164fbfe1de26be402fe64c9aa749698635152357a31e35e4032d366df"} -->
## P05-T190 — Produce and validate the provisional native declaration manifest

Contract: `F1-R`, `F1-R2`, `F1-R3`, `F1-R4`, `F1-R5`, `G5-R.candidateGeneratedArtifacts`

Dependencies:
- `P05-T002`
- `P05-T004`
- `P05-T007`
- `P05-T009`
- `P05-T010`
- `P05-T011`
- `P05-T012`
- `P05-T013`
- `P05-T100`
- `P05-T101`
- `P05-T102`
- `P05-T103`
- `P05-T104`
- `P05-T105`
- `P05-T106`
- `P05-T107`
- `P05-T108`
- `P05-T109`
- `P05-T110`
- `P05-T111`
- `P05-T112`
- `P05-T113`
- `P05-T114`
- `P05-T115`
- `P05-T116`
- `P05-T117`
- `P05-T118`
- `P05-T119`
- `P05-T120`
- `P05-T121`
- `P05-T122`
- `P05-T123`
- `P05-T124`
- `P05-T125`
- `P05-T126`
- `P05-T127`
- `P05-T128`
- `P05-T129`
- `P05-T130`
- `P05-T131`
- `P05-T132`
- `P05-T133`
- `P05-T134`
- `P05-T135`
- `P05-T136`
- `P05-T137`
- `P05-T138`
- `P05-T139`
- `P05-T140`
- `P05-T141`
- `P05-T142`
- `P05-T143`
- `P05-T144`
- `P05-T145`
- `P05-T146`
- `P05-T147`
- `P05-T148`
- `P05-T149`
- `P05-T150`
- `P05-T151`
- `P05-T152`
- `P05-T153`
- `P05-T154`
- `P05-T155`
- `P05-T156`
- `P05-T157`
- `P05-T158`
- `P05-T159`
- `P05-T160`
- `P05-T161`

Ownership selectors:
- `candidate-producer:MonaNativeDeclarationManifest.json`
- `machineArtifact:F1-R4-public`
- `machineArtifact:F1-R5-native-types`

Files to create:
- `Tools/Candidates/build-native-declaration-manifest.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/NativeDeclarationManifestTests.mjs`

Interfaces consumed:
- `MonaPublicDeclarationGraph`
- `MonaEditorInstanceAdapters`
- `MonaFeatureRegistry`
- `MonaProviderExecutor`

Interfaces produced:
- `ProvisionalMonaNativeDeclarationManifest`

Red verification:
- Run: `node --test Tests/PlanStructureTests/NativeDeclarationManifestTests.mjs --test-name-pattern seeded-drift`
  - Expected exit: `1`
  - Expected output includes: `NATIVE_DECLARATION_MANIFEST_DRIFT path=editor.colorize`

Minimal implementation operations:
- `Join all retained and disposition-only declaration, registry, option, theme, localization, feature, and native-adaptation rows.`
- `Verify exact identity, disposition, native symbol, signature, owner, test owner, and source hash.`
- `Mark the output provisional because Phase 07 public API closure and Phase 08 regeneration have not occurred.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/NativeDeclarationManifestTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `NATIVE_DECLARATION_MANIFEST identities=555 featureIds=62 state=provisional`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T190.json`

Completion assertions:
- `All declaration and feature identities are represented.`
- `Three native colorize replacements remain distinct.`
- `The manifest is not marked final or present.`

Commit boundary:
- `Tools/Candidates/build-native-declaration-manifest.mjs`
- `Tests/PlanStructureTests/NativeDeclarationManifestTests.mjs`

<!-- monacode-plan-task:{"id":"P05-T200","recordSha256":"ca1fef31547feff8ae33946f7a5cf92294ef32fa5d54720123fe24d2b98990d7"} -->
## P05-T200 — Close the retained public surface, registries, options, themes, localization, and features

Contract: `F1-R`, `F1-R2`, `F1-R3`, `F1-R4`, `F1-R5`, `T1-R`, `N1-R`, `C04`, `C05`

Dependencies:
- `P05-T190`

Ownership selectors:
- `normativeLayer:feature-public-surface:F1-R`
- `normativeLayer:feature-public-surface:F1-R2`
- `normativeLayer:feature-public-surface:F1-R3`
- `normativeLayer:feature-public-surface:F1-R4`
- `normativeLayer:feature-public-surface:F1-R5`
- `phase-gate:05`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Phase05PublicSurfaceConformanceTests.swift`

Interfaces consumed:
- `ProvisionalMonaNativeDeclarationManifest`
- `MonaCommandRegistry`
- `MonaMenuRegistry`
- `MonaOptionSnapshot`
- `MonaThemeRegistry`
- `MonaLocalizationProfileSet`

Interfaces produced:
- `Phase05PublicSurfaceGate`

Red verification:
- Run: `swift test --filter Phase05PublicSurfaceConformanceTests/testSeededIdentitySwap`
  - Expected exit: `1`
  - Expected output includes: `PHASE05_PUBLIC_SURFACE_FAILED kind=feature id=anchorSelect`

Minimal implementation operations:
- `Run identity-set, signature, native adaptation, registry ordering, option boundary, theme, localization, feature behavior, disposal, and plain-text degradation matrices.`
- `Assert exactly 62 retained feature IDs, zero missing retained feature IDs, and three distinct native colorize replacements.`
- `Reject any cut, later, built-in language, or WebGPU identity that becomes production-owned.`

Green verification:
- Run: `swift test --filter Phase05PublicSurfaceConformanceTests`
  - Expected exit: `0`
  - Expected output includes: `PHASE05_PUBLIC_SURFACE retainedFeatureIds=62 missingRetainedFeatureIds=0 nativeColorizeReplacements=3`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-05/P05-T200.json`

Completion assertions:
- `All phase-owned contract identities have one implementation owner and tests.`
- `Retained feature behavior is explicitly task-sized.`
- `Cut and later identities remain unowned.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Phase05PublicSurfaceConformanceTests.swift`
