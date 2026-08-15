# Phase 5 — Commands, Options, Theme, Localization, Features

**Goal:** Implement the public feature surface: the F1-R4/R5 native-type public declaration graph (555 paths → Swift symbol graph), the command/action/keybinding/menu/contribution registries, the 174 editor options, the theme/token/icon registry (T1-R), UI localization (N1-R), and the 62 retained features. Produces `MonaNativeDeclarationManifest.json`. Completes **C04** and the options portion of **C05**.

**G4-R mapping:** feature-public-surface F1-R, F1-R2, F1-R3, F1-R4, F1-R5; theme-token-icon T1-R; ui-localization N1-R.

**Prerequisites:** Phase 3 (options affect layout; theme drives rendering), Phase 4 (input/AX event paths), Phase 1 (registries scaffolding).

**Exit Gates (this phase completes):**
- **C04 (symbol-graph + registries + localization contribution; full pass at Phase 7)** — 555 source declaration paths (434 retained / 121 cut) mapped one-to-one to the Swift symbol graph; 62 retained features / 166 actions / 126 pure-text / 453 commands / 52 contributions / 379 keybindings / 18 menus-121 items / 21 command descriptors; 5 editor-instance interface sequences; no silent no-op; `MonaResourceOpener` absent. (Full C04 — + H1-R2 openers, S1-R services, SN1/MD1 paths, X1 source-closure set equality — passes at Phase 7.)
- **C05 (options pass)** — 174 options (157 retained + 6 computed + 11 cut); diff portion lands in Phase 7.
- Candidate artifact produced: `MonaNativeDeclarationManifest.json`.
- Preflight: manifest validates; audit/verify-contract pass.

---

## Task 5.1 — F1-R4/R5 native-type public declaration graph

**Dependencies:** 0.3, 1.8
**Files:** Create `Sources/MonaCode/Features/MonaNativeTypes.swift` (MonaThenable, MonaDisposable, MonaArray, MonaReadonlyArray, MonaURIIdentityMap, MonaResourceMap, MonaUInt32Buffer, MonaStringRecord, MonaPresence, MonaNullable, MonaNullish, MonaJSONValue, MonaCommandValue, MonaOpaqueAttachment, MonaCodeEnvironmentOverrides); Test `Tests/MonaCodeTests/Features/test_NativeTypes.swift`
**Tests:** 434 retained paths mapped one-to-one to Swift symbols. DOM/HTMLElement → typed `NSView` protocol; client point → `CGPoint`; DOM widget → Mona content/overlay/glyph NSView protocol; KeyboardEvent/MouseEvent → immutable Mona snapshots. `Promise`/`Thenable` → `MonaThenable` (sync invocation, deferred settlement, microtask normalization via `MonaMicrotaskQueue`). `IDisposable` → `MonaDisposable`. Canonical containers (NOT Swift Array/Dictionary/Optional defaults): `MonaArray<T>` (@MainActor mutable ref, shared alias), `MonaReadonlyArray<T>` (immutable snapshot, Sendable), `MonaURIIdentityMap<V>` (ObjectIdentifier key), `MonaResourceMap<V>` (`uri.toString()` key), `MonaUInt32Buffer` (explicit LE wire), `MonaStringRecord<V>` (numeric keys ascending then insertion-order), `MonaRegExp` (M1-R3, not NSRegularExpression). Presence: `MonaPresence<T>`/`MonaNullable<T>`/`MonaNullish<T>` — three separate types. `createMultiFileDiffEditor` (source `any`) → typed `MonaMultiDiffEditorView` (native typed extension). 121 cut paths absent from the symbol graph. `MonaResourceOpener` NOT a symbol.
**Contract:** G4-R §surfaceCounts.publicDeclarations (total 555, retained 434, cut 121; retainedDispositionCountsAfterMD1: native-mapping 407, appkit-type-adaptation 12, native-replacement 4, native-event-adaptation 3, lsp-client 1, lsp-umbrella 1, swift-async-adaptation 1, explicit-member-cuts 5; explicitMemberCuts total 13); F1-R4, F1-R5; §implementationOutputRules.publicSwiftSpelling.
**Produces:** — (manifest in 5.8).
**Exit-gate contribution:** C04 (symbol graph closure).
**Steps:**
- [ ] Implement the native-type catalog; map the 434 retained paths; confirm 121 cut paths + `MonaResourceOpener` absent; commit.

## Task 5.2 — Command / action / keybinding / menu / contribution registries

**Dependencies:** 5.1, 1.12, 4.2
**Files:** Create `Sources/MonaCode/Commands/MonaCommandRegistry.swift`, `Sources/MonaCode/Commands/MonaActionRegistry.swift`, `Sources/MonaCode/Commands/MonaKeybindingRegistry.swift`, `Sources/MonaCode/Commands/MonaMenuRegistry.swift`; Test `Tests/MonaCodeTests/Commands/test_Registries.swift`
**Tests:** Counts from F1-R3 scope manifest: actions 166 retained (167−1 WebGPU debug cut); pure-text 126 (127−1); commands 453 (454−1); contributions 52 (53−1 iPadShowKeyboard later-iPadOS); keybindings 379; menus 18 / items 121 / command descriptors 21. `IStandaloneCodeEditor.addCommand` returns an ID, installs a process-global dynamic command + keybinding, no public disposal handle. `addAction` is editor-ID context-gated; its disposable owns command/menu/keybinding/editor-action entries. Duplicate command IDs form newest-first stack; dispose restores prior. WebGPU debug action + its command ID are cut.
**Contract:** G4-R §surfaceCounts (actions 167→166, pureTextActions 127→126, commands 454→453, contributions 53→52, keybindings 379, menus 18, menuItems 121, menuCommandDescriptors 21); F1-R (feature and registry semantic base); F1-R3 (machine manifest, identity, order); §explicitCuts (WebGPU debug action).
**Produces:** —
**Exit-gate contribution:** C04 registries.
**Steps:**
- [ ] Implement the 4 registries with exact counts/order; confirm WebGPU cut; commit.

## Task 5.3 — Editor options (174)

**Dependencies:** 5.1, 3.6
**Files:** Create `Sources/MonaCode/Editor/MonaEditorOptions.swift`, `Sources/MonaCode/Editor/MonaConfigurationChangedEvent.swift`; Test `Tests/MonaCodeTests/Editor/test_Options.swift`
**Tests:** 174 options = 157 retained input + 6 computed-only + 11 explicit cut. 11 cut options absent: `disableLayerHinting`, `domReadOnly`, `editContext`/`effectiveEditContextEnabled`, `extraEditorClassName`/`editorClassName`, `useShadowDOM`, `selectionClipboard`, `experimentalGpuAcceleration`, `experimentalWhitespaceRendering`, `wordSegmenterLocales`. `ConfigurationChangedEvent` preserves option identity/order. `wordSegmenterLocales` cut → `Intl.Segmenter` path absent (X1). Options that affect layout trigger the correct `DependencyStamp` domain (font→`GeometryStamp`; theme→`PaintStamp`; wrapping→`GeometryStamp`+`ProjectionStamp`).
**Contract:** G4-R §surfaceCounts.options (baseline 174, retainedInput 157, computedOnly 6, cut 11); §explicitCuts.editorOptions (the 11); §acceptance.overlays.C05 (174 options).
**Produces:** —
**Exit-gate contribution:** C05 (options).
**Steps:**
- [ ] Implement the 174 options + change event + stamp routing; confirm 11 cuts absent; commit.

## Task 5.4 — Theme / token / icon registry (T1-R)

**Dependencies:** 5.1, 3.6
**Files:** Create `Sources/MonaCode/Theme/MonaColorRegistry.swift` (431 colors), `Sources/MonaCode/Theme/MonaProductIconRegistry.swift` (776 icons), `Sources/MonaCode/Theme/MonaStandaloneThemeService.swift` (4 builtin themes), `Sources/MonaCode/Theme/MonaTokenTheme.swift`; Generated `Sources/MonaCode/Generated/Codicon/codicon.ttf` (140,956 bytes, SHA `cc2472e2…`); Test `Tests/MonaCodeTests/Theme/test_Theme.swift`
**Tests:** 431 color IDs (sorted-ID SHA `3a20a42d…`); default graph, transform arithmetic (lighten/darken/transparency), undefined fallback, explicit override — exact. RGBA extended-sRGB; alpha by compositor; output `MonaTheme` immutable snapshot (no CSS class API). 4 builtin themes `vs`/`vs-dark`/`hc-black`/`hc-light`. `autoDetectHighContrast` option/event exact; base theme tracks AppKit accessibility display state. Token theme: scope hierarchy, rule order, fontStyle, encoded color map, `setColorMap` override — converts to `LineLayoutRecord` token runs + AX attributed runs. 776 product icon IDs (sorted-ID SHA `d9542a8e…`); alias chain, modifier, resolved `fontCharacter` exact; Codicon TTF is a licensed asset (CC BY 4.0) not linked runtime; missing icon ID → failure marker, NEVER an SF Symbol substitute. 0 theme cuts.
**Contract:** G4-R §surfaceCounts.theme (colors 431, productIcons 776, builtinThemes 4); T1-R; §licensingProfile.codiconArtworkAndFont (CC BY 4.0); §architecture (Core Text/AppKit/Core Graphics projections retain Codicon glyph identities); §explicitCuts (none in theme graph).
**Produces:** —
**Exit-gate contribution:** C04 theme counts; C08 token runs; C10 Codicon license/font hash.
**Steps:**
- [ ] Generate color/icon/theme tables; implement registries; verify Codicon font hash + license notice; commit.

## Task 5.5 — UI localization (N1-R) + MonaCodeEnvironment profile

**Dependencies:** 0.6, 5.1
**Files:** Create `Sources/MonaCode/Localization/MonaLocalizationProfile.swift`, `Sources/MonaCode/Localization/MonaLocalization.swift`; Generated `Sources/MonaCode/Generated/Localization/*.swift` (15 profiles × 2120 keys); Test `Tests/MonaCodeTests/Localization/test_Localization.swift`
**Tests:** 2120 message keys across 180 source modules (`nls.keys.json` SHA `fe0b719b…`). 13 packaged locales: cs/de/es/fr/it/ja/ko/pl/pt-br/ru/tr/zh-cn/zh-tw; 12 fully translated (each 2120 strings); 1 all-fallback (pt-br = 2120 nulls → English, NOT fabricated Portuguese). Default `en` + pseudo (runtime transform) → 15 selectable profiles. `MonaCodeEnvironment` localization profile immutable, selected once before first access; default `en`; unsupported IDs typed-rejected; process restart to change. Generated Swift tables immutable; lookup never calls Foundation localization or network. Custom `/\{(\d+)\}/g` formatting (first captured digit = arg index; `{10}` behavior; String/number/boolean/null/absent stringify exactly; other values leave placeholder unchanged) — NOT `Foundation.String(format:)`. Lookup chain: locale → English fallback → typed missing-message failure (no silent empty). `localize2` carries localized value + separately formatted original English. Pseudo: English fallback wrapped in fullwidth `【】`; lowercase a/o/u/e/i doubled in source order.
**Contract:** G4-R §surfaceCounts.uiLocalization (messageKeys 2120, sourceModules 180, selectableProfiles 15, packagedLocales 13, fullyTranslated 12, allFallback 1); N1-R; §hostContractClosure.environmentLocalization; §explicitCuts (system locale auto-selection; runtime locale mutation); §licensingProfile.monacoLocalization.
**Produces:** —
**Exit-gate contribution:** C04 (localization profile + 2120 identities); C07 (localized controls/AX); C10 (15 profiles + 2120 keys + MIT notices).
**Steps:**
- [ ] Generate the 15 profile tables from pinned MIT artifacts; wire `MonaCodeEnvironment` profile selection; implement custom formatter; capture 15×2120 fixtures; commit.

## Task 5.6 — 62 retained features + 5 instance interface sequences

**Dependencies:** 5.2, 5.3
**Files:** Create `Sources/MonaCode/Features/MonaFeatureRegistry.swift`, `Sources/MonaCode/Editor/MonaEditorInstances.swift` (IEditor 43/40, ICodeEditor 137/130, IStandaloneCodeEditor 141/133, IDiffEditor 60/52, IStandaloneDiffEditor 65/55); Test `Tests/MonaCodeTests/Features/test_Features.swift`
**Tests:** 64 features → 62 macOS retained (+1 iPad later, +1 WebGPU debug cut). 5 instance interface declaration/unique sequences match F1-R3 instance manifest exactly. `renderRichScreenReaderContent` option: `false` → plain text; `true` → `accessibilityAttributedStringForRange` generating AppKit AX font/color/underline from token/decoration runs.
**Contract:** G4-R §surfaceCounts.features (baseline 64, retainedMacOS 62, laterIPadOS 1, cutWebGPUDebug 1); §surfaceCounts.editorInstances; F1-R2 (instance, option, native-domain); F1-R3 (machine manifest, identity, order, instance-surface).
**Produces:** —
**Exit-gate contribution:** C04 features + instances.
**Steps:**
- [ ] Implement feature registry (62) + instance sequences; confirm WebGPU cut + iPad later; commit.

## Task 5.7 — Provider execution model (F1-R5) + microtask queue

**Dependencies:** 5.1, 1.10
**Files:** Create `Sources/MonaCode/Language/MonaProviderResult.swift`, `Sources/MonaCode/Language/MonaMicrotaskQueue.swift`, `Sources/MonaCode/Language/MonaSelector.swift`; Test `Tests/MonaCodeTests/Language/test_ProviderExecution.swift`
**Tests:** Direct providers are `@MainActor`, invoked synchronously, receive the live model, may reenter live model APIs. `MonaProviderResult<T>` has value/null/undefined/thenable cases. Every immediate or deferred completion routes through the repository-owned `MonaMicrotaskQueue` (MainActor) before consumer code continues — immediate results NOT processed inline in the provider's call stack. Mutable result aliasing (`MonaArray`/`MonaURIIdentityMap`/`MonaUInt32Buffer`/`MonaOpaqueAttachment`) preserves the same reference until consumer releases it; later queued mutation observable in the same relative turn (Chrome 151 probe: 7 array + 9 typed-array mutations after resolution). LSP background decoding produces immutable Sendable snapshots, materialized to canonical buffers on MainActor. `TokensProviderFactory.create()` return union narrows to `TokensProvider | EncodedTokensProvider`; `IMonarchLanguage` member cut. Selector scoring ported branch-by-branch (exact=10, wildcard=5, exclusive=1000; equal → non-builtin first, later registration first).
**Contract:** G4-R §architecture.providerExecution; F1-R5 (native presence, container, dynamic value, provider scheduling, TokensProviderFactory member-cut); §acceptance.overlays.C06 (F1-R5 synchronous provider invocation, nullish states, thenable normalization, mutable aliasing).
**Produces:** —
**Exit-gate contribution:** C04 (TokensProviderFactory disposition); C06 (Phase 6) substrate.
**Steps:**
- [ ] Implement provider result union + microtask queue + selector; verify aliasing vectors; commit.

## Task 5.8 — MonaNativeDeclarationManifest producer + C04/C05(options) validation

**Dependencies:** 5.1–5.7
**Files:** Create `Tools/MonaNativeDeclarationManifest.swift` (Swift symbol graph + declaration mapper); Create `docs/implementation-phases/verification/phase-05-verification.md` (after verification)
**Tests:** `MonaNativeDeclarationManifest.json` is set-equal to the 434 retained paths with one canonical Swift mapping each; 121 cut paths absent; `MonaResourceOpener` absent; every public symbol classified. C04 differential passes (symbol presence/absence, member cuts, registry counts). C05 options differential passes (174, 11 cuts absent).
**Contract:** G4-R §implementationOutputRules.publicSwiftSpelling; §candidateGeneratedArtifacts (MonaNativeDeclarationManifest required for C04, C05, C06, C09, C10); §acceptance.overlays.C04/C05.
**Produces:** `MonaNativeDeclarationManifest.json` (present).
**Exit-gate contribution:** C04 pass, C05(options) pass; Phase 5 done when manifest validates + three adversarial rounds pass.
**Steps:**
- [ ] Implement the symbol-graph → declaration mapper; emit manifest; validate against F1-R4 public declaration manifest; commit; trigger per-phase adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-05-verification.md` (3 rounds; 1 BLOCKING fixed):

- **Exit gate (B1):** Phase 5 completes the **C04 symbol-graph + registries + localization contribution** only. C04 aggregates H1-R2 openers (Phase 7 Task 7.5), S1-R 40 services (Phase 7 Task 7.3), SN1 counts (Phase 6), MD1-R `supportHtml` cut (Phase 6), and X1-R source-closure set equality (Phase 7 Task 7.8). **Full C04 pass is at the Phase 7 exit.** (Master-plan C04 row + per-phase summary updated.)
- **Task 5.6 (M1):** dependencies add **5.4** (tests `renderRichScreenReaderContent` → `accessibilityAttributedStringForRange` from token/decoration runs, which are 5.4 `MonaTokenTheme` output).
- **Task 5.1 (M2):** Tests narrowed to "native-type retained paths mapped; 121 cut paths + `MonaResourceOpener` absent from the native-type catalog." The 434-path set-equality is a **Task 5.8** exit criterion only. `createMultiFileDiffEditor` is a "native typed **replacement**" (disposition `retained-native-replacement`), not "extension." Add the F1-R5→MD1-R correction chain note (native-mapping 409→408→407; member-cut paths 3→4→5; total member cuts 11→12→13). `MonaMicrotaskQueue` tests scoped to sync invocation + deferred settlement here; microtask-normalization test lives in 5.7.
- **Exit-gate counts:** use retained (62 features / 166 actions / 126 pure-text / 453 commands / 52 contributions) + cut split (1 iPad-later, 1 WebGPU); add command descriptors 21.
- **Task 5.3:** add `layers=F1-R2` (options are the F1-R2 instance/option/native-domain overlay).
- **Task 5.1:** name `IMarkdownString.supportHtml` as the 13th explicit member cut (MD1-R; 11 editorOptions + 1 tokensProviderFactory + 1 markdownString = 13).
- **Task 5.4:** Codicon license adds the Git Logo **CC BY 3.0** exception (when the bundled full font includes the Git Logo glyph).
- **Task 5.5:** "**14 generated tables** (en + 13 packaged) + 1 pseudo runtime transform = 15 selectable profiles" (pseudo is `kind: runtime-transform`, not a static table).
- **Prerequisites:** relabel "Phase 1 (H2-R process-global state, R1 DependencyStamp, base types)."
