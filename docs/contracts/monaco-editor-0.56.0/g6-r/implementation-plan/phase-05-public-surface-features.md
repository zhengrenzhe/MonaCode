<!-- G6-R-PHASE:05 -->

# Phase 05 — Public surface and retained features

- Phase: `05`
- Title: Public surface and retained features
- Document: `implementation-plan/phase-05-public-surface-features.md`
- Dependencies: `04` 
- Tasks: 77

## Tasks

<!-- G6-R-TASK:P05-T001:016955532ec6b3b839335d576c679d6d1af15da6f8fcf7c7158c4e57bf724377 -->

### P05-T001 — Generate the exact 555-path native public declaration graph

- Record SHA-256: `016955532ec6b3b839335d576c679d6d1af15da6f8fcf7c7158c4e57bf724377`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T009`, `P04-T016` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T001`
- Evidence commit message: `evidence(monacode): complete P05-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/PublicDeclarationGraphTests.mjs`

### Stage `red`

- verification-command: `P05-T001.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Read the copied F1-R3 and F1-R4 machine artifacts and emit individual rows without renaming or coalescing identities.`
- implementation-operation: `Generate native declarations with exact optionals, overloads, extensible raw values, reference/value identity, throwing, async, and event adaptation.`
- implementation-operation: `Reject selectors that expand to zero identities and reject output not set-equal to all 555 paths.`
- implementation-operation: `Keep cut declarations recorded as explicit unavailable dispositions without production symbols.`

### Stage `green`

- verification-command: `P05-T001.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Generators/generate-contract-registries.mjs
  - Sources/MonaCode/Generated/MonaPublicAPI.swift
  - Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift
  - Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/PublicDeclarationGraphTests.mjs

<!-- G6-R-TASK:P05-T002:48ff628d5b7920c4207085d8f01cf094af407c36339eec54cd84981203e8587a -->

### P05-T002 — Implement command, action, contribution, and pure-text registries

- Record SHA-256: `48ff628d5b7920c4207085d8f01cf094af407c36339eec54cd84981203e8587a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T003`, `P05-T001` 
- Test contract cases: 1
- Red-scaffold rows: 5
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T002`
- Evidence commit message: `evidence(monacode): complete P05-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Registry/MonaCommandActionRegistryTests.swift`

### Stage `red`

- verification-command: `P05-T002.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Register all frozen command, action, pure-text action, and contribution identities in source order.`
- implementation-operation: `Evaluate enablement, precondition, toggled state, argument shape, and disposal deterministically.`
- implementation-operation: `Exclude the WebGPU debug identities and later mobile contribution from production.`

### Stage `green`

- verification-command: `P05-T002.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Registry/MonaCommandRegistry.swift
  - Sources/MonaCode/Registry/MonaActionRegistry.swift
  - Sources/MonaCode/Registry/MonaContributionRegistry.swift
  - Sources/MonaCode/Registry/MonaContextKey.swift
  - Sources/MonaCode/Registry/MonaFeatureRegistry.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Registry/MonaCommandActionRegistryTests.swift

<!-- G6-R-TASK:P05-T003:0e0b277f28b5972d0c07fd79911ada8d6660f7ec423ffdc1db65793bc2d0210f -->

### P05-T003 — Populate all 379 keybinding rows over the Core resolver

- Record SHA-256: `0e0b277f28b5972d0c07fd79911ada8d6660f7ec423ffdc1db65793bc2d0210f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T003`, `P05-T002` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T003`
- Evidence commit message: `evidence(monacode): complete P05-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Registry/MonaBuiltinKeybindingTests.swift`

### Stage `red`

- verification-command: `P05-T003.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Generate every ordinal, command, primary key, secondary key, weight, and when-clause row from F1-R3.`
- implementation-operation: `Keep source ordinals as stable identity even when command text repeats.`
- implementation-operation: `Validate ABC and chord conflicts against the I3-R2 resolver truth table.`

### Stage `green`

- verification-command: `P05-T003.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Generated/MonaBuiltinKeybindings.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Registry/MonaBuiltinKeybindingTests.swift

<!-- G6-R-TASK:P05-T004:534b730bf9c17e253fa84a0063d8fd3989576f066386524e76548f6d6474dfe9 -->

### P05-T004 — Implement menu, menu-item, and menu-command registries

- Record SHA-256: `534b730bf9c17e253fa84a0063d8fd3989576f066386524e76548f6d6474dfe9`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T003` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T004`
- Evidence commit message: `evidence(monacode): complete P05-T004`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T004.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Registry/MonaMenuRegistryTests.swift`

### Stage `red`

- verification-command: `P05-T004.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Generate 18 menu identities, 121 ordinal menu-item identities, and 21 menu-command identities.`
- implementation-operation: `Evaluate group, order, when, enablement, submenu, alternative, and command arguments in stable order.`
- implementation-operation: `Produce a platform-neutral menu model consumed by the native context-menu gateway.`

### Stage `green`

- verification-command: `P05-T004.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Registry/MonaMenuRegistry.swift
  - Sources/MonaCode/Generated/MonaBuiltinMenus.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Registry/MonaMenuRegistryTests.swift

<!-- G6-R-TASK:P05-T005:0b6a4deb7a7e3f5897ae1468e805696496291c540ed054a5c2ff98caa2c71a42 -->

### P05-T005 — Implement all 174 editor options and computed option truth

- Record SHA-256: `0b6a4deb7a7e3f5897ae1468e805696496291c540ed054a5c2ff98caa2c71a42`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T013`, `P05-T001` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T005`
- Evidence commit message: `evidence(monacode): complete P05-T005`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T005.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Options/MonaEditorOptionTests.swift`

### Stage `red`

- verification-command: `P05-T005.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Generate retained-input, computed-only, and cut dispositions exactly from F1-R3.`
- implementation-operation: `Validate input types, defaults, bounds, enum extensibility, dependency ordering, and changed-option events.`
- implementation-operation: `Compute six computed-only options without exposing them as mutable input.`
- implementation-operation: `Exclude all eleven cut options from production input APIs.`

### Stage `green`

- verification-command: `P05-T005.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Options/MonaEditorOption.swift
  - Sources/MonaCode/Options/MonaOptionStore.swift
  - Sources/MonaCode/Options/MonaOptionSnapshot.swift
  - Sources/MonaCode/Generated/MonaBuiltinOptions.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Options/MonaEditorOptionTests.swift

<!-- G6-R-TASK:P05-T006:9854741a49233166ae18f76928f93c8ea6e4cc7e8d6a8926d63c183a118b122b -->

### P05-T006 — Implement theme, token, color, icon, and Codicon registries

- Record SHA-256: `9854741a49233166ae18f76928f93c8ea6e4cc7e8d6a8926d63c183a118b122b`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T001`, `P05-T005` 
- Test contract cases: 1
- Red-scaffold rows: 5
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T006`
- Evidence commit message: `evidence(monacode): complete P05-T006`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T006.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Theme/MonaThemeRegistryTests.swift`

### Stage `red`

- verification-command: `P05-T006.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Register exactly 431 colors, 776 icons, four built-in themes, token rules, and licensed Codicon glyph mappings.`
- implementation-operation: `Resolve inheritance, defaults, high contrast, token scopes, icon modifiers, and theme change events deterministically.`
- implementation-operation: `Hash the bundled font and keep provenance attached to the generated map.`

### Stage `green`

- verification-command: `P05-T006.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Theme/MonaThemeRegistry.swift
  - Sources/MonaCode/Theme/MonaTokenTheme.swift
  - Sources/MonaCode/Theme/MonaColorRegistry.swift
  - Sources/MonaCode/Theme/MonaIconRegistry.swift
  - Sources/MonaCode/Generated/MonaCodiconMap.swift
  - Sources/MonaCode/Resources/codicon.ttf
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Theme/MonaThemeRegistryTests.swift

<!-- G6-R-TASK:P05-T007:b858cef562dc7c5bf7efb701e25f3a320a83c32985cbe43320f3d21d00a0e35c -->

### P05-T007 — Generate 15 immutable UI localization profiles with 2120 messages

- Record SHA-256: `b858cef562dc7c5bf7efb701e25f3a320a83c32985cbe43320f3d21d00a0e35c`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T007`, `P05-T001` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T007`
- Evidence commit message: `evidence(monacode): complete P05-T007`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T007.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Localization/MonaLocalizationTests.swift`

### Stage `red`

- verification-command: `P05-T007.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Generate 15 explicit profile tables and all 2120 message identities from the frozen N1-R artifact.`
- implementation-operation: `Keep profile selection immutable and independent from runtime locale.`
- implementation-operation: `Apply placeholder validation, fallback, plural behavior, and Monaco MIT provenance exactly.`

### Stage `green`

- verification-command: `P05-T007.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Tools/Generators/generate-localization.mjs
  - Sources/MonaCode/Localization/MonaLocalization.swift
  - Sources/MonaCode/Generated/MonaLocalizationProfiles.swift
  - Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Localization/MonaLocalizationTests.swift

<!-- G6-R-TASK:P05-T008:9452398b3b8d1f5ec8201b73535091d3295400ddea53d58ca4ca86924b530f96 -->

### P05-T008 — Retain only core language metadata and explicit plain-text fallback

- Record SHA-256: `9452398b3b8d1f5ec8201b73535091d3295400ddea53d58ca4ca86924b530f96`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T001` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T008`
- Evidence commit message: `evidence(monacode): complete P05-T008`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T008.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Language/MonaLanguageRegistryTests.swift`

### Stage `red`

- verification-command: `P05-T008.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Retain exactly the core fallback metadata identity.`
- implementation-operation: `Record all 90 built-in language descriptors as cut-built-in-language-content with no bundled grammar or provider.`
- implementation-operation: `Expose explicit registration for host-provided metadata and plain-text behavior when none exists.`

### Stage `green`

- verification-command: `P05-T008.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Language/MonaLanguageRegistry.swift
  - Sources/MonaCode/Language/MonaPlainTextLanguage.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Language/MonaLanguageRegistryTests.swift

<!-- G6-R-TASK:P05-T009:bfffb44abdffe4ade848062ea1b20449d33be903d989bf8334e9b117c4240dfb -->

### P05-T009 — Implement editor.colorize as a native attributed-text replacement

- Record SHA-256: `bfffb44abdffe4ade848062ea1b20449d33be903d989bf8334e9b117c4240dfb`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T006`, `P05-T008` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T009`
- Evidence commit message: `evidence(monacode): complete P05-T009`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T009.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeSourceTests.swift`

### Stage `red`

- verification-command: `P05-T009.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Tokenize provided source through an attached direct token provider or plain-text fallback.`
- implementation-operation: `Return a native attributed-text value with raw UTF-16 token boundaries and resolved theme colors.`
- implementation-operation: `Never emit HTML or require a DOM/CSS renderer.`

### Stage `green`

- verification-command: `P05-T009.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Colorize/MonaColorizeSource.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Colorize/MonaColorizeSourceTests.swift

<!-- G6-R-TASK:P05-T010:f58742742caf8f8e4520a7991672a1396ca6e2fc087cb59718b52a6e18325d9b -->

### P05-T010 — Implement editor.colorizeElement as a native view mutation replacement

- Record SHA-256: `f58742742caf8f8e4520a7991672a1396ca6e2fc087cb59718b52a6e18325d9b`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T014`, `P05-T009` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T010`
- Evidence commit message: `evidence(monacode): complete P05-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeViewTests.swift`

### Stage `red`

- verification-command: `P05-T010.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Apply attributed token presentation to an explicit native text host.`
- implementation-operation: `Update only changed theme and token ranges and dispose every observation with the host lifetime.`
- implementation-operation: `Replace the web element parameter with the frozen AppKit-native type adaptation.`

### Stage `green`

- verification-command: `P05-T010.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Colorize/MonaColorizeView.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Colorize/MonaColorizeViewTests.swift

<!-- G6-R-TASK:P05-T011:011ff950bafc003377cab6f656548dbab26cc97bd17569cfab26526d00fcefcf -->

### P05-T011 — Implement editor.colorizeModelLine from immutable layout geometry

- Record SHA-256: `011ff950bafc003377cab6f656548dbab26cc97bd17569cfab26526d00fcefcf`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T003`, `P05-T009` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T011`
- Evidence commit message: `evidence(monacode): complete P05-T011`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T011.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Colorize/MonaColorizeModelLineTests.swift`

### Stage `red`

- verification-command: `P05-T011.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Project tokens, injected text, bidi segments, and theme styling from one immutable line-layout record.`
- implementation-operation: `Return native runs and geometry without HTML string construction.`
- implementation-operation: `Reject mixed model and layout generations.`

### Stage `green`

- verification-command: `P05-T011.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Colorize/MonaColorizeModelLine.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Colorize/MonaColorizeModelLineTests.swift

<!-- G6-R-TASK:P05-T012:a6f21079012ee60cbfd69c0cf91c0e3b2d09bb63d105785b4cd966c726698125 -->

### P05-T012 — Close editor factories and five instance-interface sequences

- Record SHA-256: `a6f21079012ee60cbfd69c0cf91c0e3b2d09bb63d105785b4cd966c726698125`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T015`, `P05-T001`, `P05-T005` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T012`
- Evidence commit message: `evidence(monacode): complete P05-T012`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T012.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Views/MonaEditorInstanceSurfaceTests.swift`

### Stage `red`

- verification-command: `P05-T012.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement editor creation, model attachment, retrieval, disposal, and global editor/model event sequences.`
- implementation-operation: `Expose the five F1-R3 instance surfaces with exact retained member counts and native type adaptations.`
- implementation-operation: `Keep diff and multi-diff construction behind Phase 07 adapters while preserving their declaration slots.`

### Stage `green`

- verification-command: `P05-T012.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift
  - Sources/MonaCodeAppKit/Views/MonaEditorInstanceAdapters.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Views/MonaEditorInstanceSurfaceTests.swift

<!-- G6-R-TASK:P05-T013:f51bd373e80ffa0998edb4e9881149f59924ca0ee86eb7651e6f2605124f5af9 -->

### P05-T013 — Implement deterministic provider execution and microtask publication

- Record SHA-256: `f51bd373e80ffa0998edb4e9881149f59924ca0ee86eb7651e6f2605124f5af9`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T010`, `P05-T001` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T013`
- Evidence commit message: `evidence(monacode): complete P05-T013`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T013.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Language/MonaProviderExecutorTests.swift`

### Stage `red`

- verification-command: `P05-T013.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Normalize synchronous, asynchronous, optional, throwing, cancelable, resolvable, and releasable provider results.`
- implementation-operation: `Serialize publication on one deterministic microtask queue.`
- implementation-operation: `Validate tickets immediately before publication and release every owned list exactly once.`

### Stage `green`

- verification-command: `P05-T013.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Language/MonaProviderExecutor.swift
  - Sources/MonaCode/Runtime/MonaMicrotaskQueue.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Language/MonaProviderExecutorTests.swift

<!-- G6-R-TASK:P05-T100:e1c55b6f222d7f2b40ed3b2a4b3db128007098c65b28d34dc4f08f6673afa424 -->

### P05-T100 — Implement retained feature anchorSelect

- Record SHA-256: `e1c55b6f222d7f2b40ed3b2a4b3db128007098c65b28d34dc4f08f6673afa424`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T100`
- Evidence commit message: `evidence(monacode): complete P05-T100`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T100.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaAnchorSelectFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T100.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement extend selections from their anchors with exact cursor ordering.`
- implementation-operation: `Register the exact feature identity anchorSelect and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T100.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaAnchorSelectFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaAnchorSelectFeatureTests.swift

<!-- G6-R-TASK:P05-T101:8e924fa1a845fa36e3df0861ce0a3cd615b165e3f29f8f0df375e4b2017d3060 -->

### P05-T101 — Implement retained feature bracketMatching

- Record SHA-256: `8e924fa1a845fa36e3df0861ce0a3cd615b165e3f29f8f0df375e4b2017d3060`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T101`
- Evidence commit message: `evidence(monacode): complete P05-T101`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T101.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaBracketMatchingFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T101.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement match, navigate, select, and highlight bracket pairs from the active tokenization state.`
- implementation-operation: `Register the exact feature identity bracketMatching and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T101.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaBracketMatchingFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaBracketMatchingFeatureTests.swift

<!-- G6-R-TASK:P05-T102:389d6689610a88f62a29a7c88d2080eab0325daade50ed7106507da968091dfe -->

### P05-T102 — Implement retained feature caretOperations

- Record SHA-256: `389d6689610a88f62a29a7c88d2080eab0325daade50ed7106507da968091dfe`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T102`
- Evidence commit message: `evidence(monacode): complete P05-T102`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T102.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaCaretOperationsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T102.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement move carets by line, wrapped line, column, page, viewport, and document boundaries.`
- implementation-operation: `Register the exact feature identity caretOperations and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T102.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaCaretOperationsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaCaretOperationsFeatureTests.swift

<!-- G6-R-TASK:P05-T103:4281f3f99626c380d3e65515faba5ab2f60965885d5e977fe429c14b988d209d -->

### P05-T103 — Implement retained feature clipboard

- Record SHA-256: `4281f3f99626c380d3e65515faba5ab2f60965885d5e977fe429c14b988d209d`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T103`
- Evidence commit message: `evidence(monacode): complete P05-T103`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T103.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaClipboardFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T103.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement register editor copy, cut, and paste actions over the native transfer gateway.`
- implementation-operation: `Register the exact feature identity clipboard and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T103.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaClipboardFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaClipboardFeatureTests.swift

<!-- G6-R-TASK:P05-T104:992cce8f53ec12f8884445b8464522d68a6a6d6f2cf6dae1c54d8b8a55a14eb0 -->

### P05-T104 — Implement retained feature codeAction

- Record SHA-256: `992cce8f53ec12f8884445b8464522d68a6a6d6f2cf6dae1c54d8b8a55a14eb0`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T104`
- Evidence commit message: `evidence(monacode): complete P05-T104`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T104.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaCodeActionFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T104.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement surface provider code actions, resolve them, and apply accepted edits transactionally.`
- implementation-operation: `Register the exact feature identity codeAction and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T104.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaCodeActionFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaCodeActionFeatureTests.swift

<!-- G6-R-TASK:P05-T105:6ff87d63c723a5b240b0dd1160c80db3ed61240d78f5d161320d169b27872999 -->

### P05-T105 — Implement retained feature codeEditor

- Record SHA-256: `6ff87d63c723a5b240b0dd1160c80db3ed61240d78f5d161320d169b27872999`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T105`
- Evidence commit message: `evidence(monacode): complete P05-T105`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T105.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaCodeEditorFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T105.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement register the standalone code-editor contribution set and lifecycle hooks.`
- implementation-operation: `Register the exact feature identity codeEditor and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T105.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaCodeEditorFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaCodeEditorFeatureTests.swift

<!-- G6-R-TASK:P05-T106:ba694db671c90fc40fa64211f8d46382eaf0098de6c0fbfd3f928e0bb1054e45 -->

### P05-T106 — Implement retained feature codelens

- Record SHA-256: `ba694db671c90fc40fa64211f8d46382eaf0098de6c0fbfd3f928e0bb1054e45`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T106`
- Evidence commit message: `evidence(monacode): complete P05-T106`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T106.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaCodelensFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T106.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement render, resolve, invoke, and release code-lens results by model version.`
- implementation-operation: `Register the exact feature identity codelens and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T106.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaCodelensFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaCodelensFeatureTests.swift

<!-- G6-R-TASK:P05-T107:49c4585bd220cd5ced7c971f8b5ca2bf4641bdc4ff9b150ee8d787969f7f3a53 -->

### P05-T107 — Implement retained feature codicon

- Record SHA-256: `49c4585bd220cd5ced7c971f8b5ca2bf4641bdc4ff9b150ee8d787969f7f3a53`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T107`
- Evidence commit message: `evidence(monacode): complete P05-T107`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T107.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaCodiconFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T107.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement resolve Codicon identifiers and licensed glyph assets through the theme registry.`
- implementation-operation: `Register the exact feature identity codicon and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T107.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaCodiconFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaCodiconFeatureTests.swift

<!-- G6-R-TASK:P05-T108:c6ab616997de698cb87fdcaf9dfb6916ec3e205787c2f0703be0c4a17c462dda -->

### P05-T108 — Implement retained feature colorPicker

- Record SHA-256: `c6ab616997de698cb87fdcaf9dfb6916ec3e205787c2f0703be0c4a17c462dda`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T108`
- Evidence commit message: `evidence(monacode): complete P05-T108`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T108.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaColorPickerFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T108.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement present, update, and commit document-color provider results.`
- implementation-operation: `Register the exact feature identity colorPicker and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T108.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaColorPickerFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaColorPickerFeatureTests.swift

<!-- G6-R-TASK:P05-T109:5132abf735e224284d5a1ae5de12aba8eb3a2cfb816ab52cf4904d47e1552bc2 -->

### P05-T109 — Implement retained feature comment

- Record SHA-256: `5132abf735e224284d5a1ae5de12aba8eb3a2cfb816ab52cf4904d47e1552bc2`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T109`
- Evidence commit message: `evidence(monacode): complete P05-T109`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T109.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaCommentFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T109.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement execute line and block comment commands from explicit language configuration only.`
- implementation-operation: `Register the exact feature identity comment and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T109.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaCommentFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaCommentFeatureTests.swift

<!-- G6-R-TASK:P05-T110:9cced9b52029d4a28b9461e1ef41848e2246c5244c0c280841fd1091e5aed6c1 -->

### P05-T110 — Implement retained feature contextmenu

- Record SHA-256: `9cced9b52029d4a28b9461e1ef41848e2246c5244c0c280841fd1091e5aed6c1`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T110`
- Evidence commit message: `evidence(monacode): complete P05-T110`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T110.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaContextmenuFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T110.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement construct the ordered native editor context menu from menu registries.`
- implementation-operation: `Register the exact feature identity contextmenu and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T110.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaContextmenuFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaContextmenuFeatureTests.swift

<!-- G6-R-TASK:P05-T111:9d9222b635e5649ebcc21e6c0020241c02cb21e148fbc7f7b0a8028f683868a6 -->

### P05-T111 — Implement retained feature cursorUndo

- Record SHA-256: `9d9222b635e5649ebcc21e6c0020241c02cb21e148fbc7f7b0a8028f683868a6`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T111`
- Evidence commit message: `evidence(monacode): complete P05-T111`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T111.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaCursorUndoFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T111.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement record and restore cursor-only navigation states independently from model undo.`
- implementation-operation: `Register the exact feature identity cursorUndo and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T111.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaCursorUndoFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaCursorUndoFeatureTests.swift

<!-- G6-R-TASK:P05-T112:2a87ee4fd4be60c0a07cd1b20cc3557bf96c157f5a982da5329f60dafd1d284c -->

### P05-T112 — Implement retained feature diffEditor

- Record SHA-256: `2a87ee4fd4be60c0a07cd1b20cc3557bf96c157f5a982da5329f60dafd1d284c`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T112`
- Evidence commit message: `evidence(monacode): complete P05-T112`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T112.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaDiffEditorFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T112.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement register diff-editor commands and contributions over the Phase 07 diff interfaces.`
- implementation-operation: `Register the exact feature identity diffEditor and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T112.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaDiffEditorFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaDiffEditorFeatureTests.swift

<!-- G6-R-TASK:P05-T113:abaad5322513642a5d49ac41da48141e75504313a171b325d63990fc61a58b43 -->

### P05-T113 — Implement retained feature diffEditorBreadcrumbs

- Record SHA-256: `abaad5322513642a5d49ac41da48141e75504313a171b325d63990fc61a58b43`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T113`
- Evidence commit message: `evidence(monacode): complete P05-T113`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T113.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaDiffEditorBreadcrumbsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T113.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement present multi-diff navigation breadcrumbs from host-owned item metadata.`
- implementation-operation: `Register the exact feature identity diffEditorBreadcrumbs and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T113.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaDiffEditorBreadcrumbsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaDiffEditorBreadcrumbsFeatureTests.swift

<!-- G6-R-TASK:P05-T114:535400649d84c23ee7c9f0261705439475c59748a725f4235bf6d6b4cba31a74 -->

### P05-T114 — Implement retained feature dnd

- Record SHA-256: `535400649d84c23ee7c9f0261705439475c59748a725f4235bf6d6b4cba31a74`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T114`
- Evidence commit message: `evidence(monacode): complete P05-T114`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T114.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaDndFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T114.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement register drag-and-drop editor behavior over the native drop gateway.`
- implementation-operation: `Register the exact feature identity dnd and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T114.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaDndFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaDndFeatureTests.swift

<!-- G6-R-TASK:P05-T115:feb3bd7c4813e4ffc4e0cfb900dd7c12b255f9195aa79d11259249ab670abb04 -->

### P05-T115 — Implement retained feature documentSymbols

- Record SHA-256: `feb3bd7c4813e4ffc4e0cfb900dd7c12b255f9195aa79d11259249ab670abb04`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T115`
- Evidence commit message: `evidence(monacode): complete P05-T115`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T115.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaDocumentSymbolsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T115.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement request, version-gate, sort, and expose document-symbol provider results.`
- implementation-operation: `Register the exact feature identity documentSymbols and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T115.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaDocumentSymbolsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaDocumentSymbolsFeatureTests.swift

<!-- G6-R-TASK:P05-T116:41d657cbe94dbf9f9efd76bec0bb9c32de86375048455bc31509f0efcc4dddca -->

### P05-T116 — Implement retained feature dropOrPasteInto

- Record SHA-256: `41d657cbe94dbf9f9efd76bec0bb9c32de86375048455bc31509f0efcc4dddca`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T116`
- Evidence commit message: `evidence(monacode): complete P05-T116`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T116.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaDropOrPasteIntoFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T116.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement select and apply explicit drop-or-paste edit proposals.`
- implementation-operation: `Register the exact feature identity dropOrPasteInto and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T116.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaDropOrPasteIntoFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaDropOrPasteIntoFeatureTests.swift

<!-- G6-R-TASK:P05-T117:cf47a89505d244155c179c6e0ebe950361ee3f891f5598299adcf2fb6f4b87a5 -->

### P05-T117 — Implement retained feature find

- Record SHA-256: `cf47a89505d244155c179c6e0ebe950361ee3f891f5598299adcf2fb6f4b87a5`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T117`
- Evidence commit message: `evidence(monacode): complete P05-T117`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T117.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaFindFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T117.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement run literal and RegExp find and replace with exact match, scope, and history semantics.`
- implementation-operation: `Register the exact feature identity find and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T117.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaFindFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaFindFeatureTests.swift

<!-- G6-R-TASK:P05-T118:a8b186c9ad4da722bdd665f6574a874d7368ede693fac730120052a6778b7596 -->

### P05-T118 — Implement retained feature floatingMenu

- Record SHA-256: `a8b186c9ad4da722bdd665f6574a874d7368ede693fac730120052a6778b7596`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T118`
- Evidence commit message: `evidence(monacode): complete P05-T118`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T118.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaFloatingMenuFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T118.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement present the retained floating action menu without web layout dependencies.`
- implementation-operation: `Register the exact feature identity floatingMenu and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T118.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaFloatingMenuFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaFloatingMenuFeatureTests.swift

<!-- G6-R-TASK:P05-T119:59ee29b744b3e18d7ee4afba621cb23e9b94ffcf407b76f6949d740033afd8ca -->

### P05-T119 — Implement retained feature folding

- Record SHA-256: `59ee29b744b3e18d7ee4afba621cb23e9b94ffcf407b76f6949d740033afd8ca`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T119`
- Evidence commit message: `evidence(monacode): complete P05-T119`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T119.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaFoldingFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T119.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement combine manual, indentation, marker, and provider folding ranges with exact precedence.`
- implementation-operation: `Register the exact feature identity folding and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T119.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaFoldingFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaFoldingFeatureTests.swift

<!-- G6-R-TASK:P05-T120:17c258adf69e9ba379bfc28ff09654952713841c981608a37dc962d22cbe88d1 -->

### P05-T120 — Implement retained feature fontZoom

- Record SHA-256: `17c258adf69e9ba379bfc28ff09654952713841c981608a37dc962d22cbe88d1`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T120`
- Evidence commit message: `evidence(monacode): complete P05-T120`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T120.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaFontZoomFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T120.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement apply bounded editor font zoom and invalidate the exact layout stamp domains.`
- implementation-operation: `Register the exact feature identity fontZoom and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T120.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaFontZoomFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaFontZoomFeatureTests.swift

<!-- G6-R-TASK:P05-T121:0a657bec40aba9edeba8d7dd911ff016868830007db794ec04f1ddba4235acd3 -->

### P05-T121 — Implement retained feature format

- Record SHA-256: `0a657bec40aba9edeba8d7dd911ff016868830007db794ec04f1ddba4235acd3`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T121`
- Evidence commit message: `evidence(monacode): complete P05-T121`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T121.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaFormatFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T121.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement run document, range, and on-type formatting providers and apply accepted edits.`
- implementation-operation: `Register the exact feature identity format and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T121.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaFormatFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaFormatFeatureTests.swift

<!-- G6-R-TASK:P05-T122:3a46c202521c8c9b4bce100bf02aaa821587e2227f3cbe7a4b87a7602093cb69 -->

### P05-T122 — Implement retained feature gotoError

- Record SHA-256: `3a46c202521c8c9b4bce100bf02aaa821587e2227f3cbe7a4b87a7602093cb69`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T122`
- Evidence commit message: `evidence(monacode): complete P05-T122`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T122.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaGotoErrorFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T122.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement navigate marker severities and announce the selected diagnostic.`
- implementation-operation: `Register the exact feature identity gotoError and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T122.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaGotoErrorFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaGotoErrorFeatureTests.swift

<!-- G6-R-TASK:P05-T123:78ad26e0a724cef3ac6a1ff75f5d1039a1589aa1a16733c56fe19a94e86ab724 -->

### P05-T123 — Implement retained feature gotoLine

- Record SHA-256: `78ad26e0a724cef3ac6a1ff75f5d1039a1589aa1a16733c56fe19a94e86ab724`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T123`
- Evidence commit message: `evidence(monacode): complete P05-T123`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T123.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaGotoLineFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T123.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement parse line and column input and reveal the validated model position.`
- implementation-operation: `Register the exact feature identity gotoLine and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T123.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaGotoLineFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaGotoLineFeatureTests.swift

<!-- G6-R-TASK:P05-T124:f6d79f693464bf7414f9886be0aba739d8f575c9dbd5369d4728172c41601144 -->

### P05-T124 — Implement retained feature gotoSymbol

- Record SHA-256: `f6d79f693464bf7414f9886be0aba739d8f575c9dbd5369d4728172c41601144`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T124`
- Evidence commit message: `evidence(monacode): complete P05-T124`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T124.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaGotoSymbolFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T124.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement filter and navigate document symbols while preserving provider order.`
- implementation-operation: `Register the exact feature identity gotoSymbol and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T124.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaGotoSymbolFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaGotoSymbolFeatureTests.swift

<!-- G6-R-TASK:P05-T125:5be74e4cb08a6c1b77be17fe02681ba81977be10188274d0f6b03b4c8a703111 -->

### P05-T125 — Implement retained feature hover

- Record SHA-256: `5be74e4cb08a6c1b77be17fe02681ba81977be10188274d0f6b03b4c8a703111`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T125`
- Evidence commit message: `evidence(monacode): complete P05-T125`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T125.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaHoverFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T125.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement merge, render, update verbosity, and release hover provider results.`
- implementation-operation: `Register the exact feature identity hover and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T125.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaHoverFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaHoverFeatureTests.swift

<!-- G6-R-TASK:P05-T126:b7ab67f7458cba93a510897100196a776271993e79128f5a24614451379c12ae -->

### P05-T126 — Implement retained feature indentation

- Record SHA-256: `b7ab67f7458cba93a510897100196a776271993e79128f5a24614451379c12ae`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T126`
- Evidence commit message: `evidence(monacode): complete P05-T126`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T126.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaIndentationFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T126.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement detect, convert, and reindent whitespace from explicit model options.`
- implementation-operation: `Register the exact feature identity indentation and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T126.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaIndentationFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaIndentationFeatureTests.swift

<!-- G6-R-TASK:P05-T127:03425338b4cf673bfe1136494f6f87cad7c2bea9246384579437b5eb4913b72f -->

### P05-T127 — Implement retained feature inlayHints

- Record SHA-256: `03425338b4cf673bfe1136494f6f87cad7c2bea9246384579437b5eb4913b72f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T127`
- Evidence commit message: `evidence(monacode): complete P05-T127`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T127.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaInlayHintsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T127.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement request, resolve, lay out, and release version-gated inlay hints.`
- implementation-operation: `Register the exact feature identity inlayHints and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T127.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaInlayHintsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaInlayHintsFeatureTests.swift

<!-- G6-R-TASK:P05-T128:ee69f6309da5aa18acc6e4800ec16481f01486a3e611889407c5cd8b8f96160f -->

### P05-T128 — Implement retained feature inlineCompletions

- Record SHA-256: `ee69f6309da5aa18acc6e4800ec16481f01486a3e611889407c5cd8b8f96160f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T128`
- Evidence commit message: `evidence(monacode): complete P05-T128`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T128.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaInlineCompletionsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T128.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement request, update, partially accept, accept, and release inline completions.`
- implementation-operation: `Register the exact feature identity inlineCompletions and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T128.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaInlineCompletionsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaInlineCompletionsFeatureTests.swift

<!-- G6-R-TASK:P05-T129:46bafb81d20eae85906e716e5dd61d2dafbee2da9f6cf68e1afe201a01d8ce97 -->

### P05-T129 — Implement retained feature inlineProgress

- Record SHA-256: `46bafb81d20eae85906e716e5dd61d2dafbee2da9f6cf68e1afe201a01d8ce97`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T129`
- Evidence commit message: `evidence(monacode): complete P05-T129`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T129.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaInlineProgressFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T129.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement render retained inline progress feedback without notification-center UI.`
- implementation-operation: `Register the exact feature identity inlineProgress and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T129.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaInlineProgressFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaInlineProgressFeatureTests.swift

<!-- G6-R-TASK:P05-T130:a2fdbfa16ae814cab0925b5c0d66069bee6cc9d0ac700cda3c78909e319a6849 -->

### P05-T130 — Implement retained feature inPlaceReplace

- Record SHA-256: `a2fdbfa16ae814cab0925b5c0d66069bee6cc9d0ac700cda3c78909e319a6849`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T130`
- Evidence commit message: `evidence(monacode): complete P05-T130`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T130.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaInPlaceReplaceFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T130.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement replace the active word from exact previous and next candidate calculations.`
- implementation-operation: `Register the exact feature identity inPlaceReplace and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T130.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaInPlaceReplaceFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaInPlaceReplaceFeatureTests.swift

<!-- G6-R-TASK:P05-T131:a52b3391c06721946109511a024547ef68be7dbafb813f06990d04ec7090e2fe -->

### P05-T131 — Implement retained feature insertFinalNewLine

- Record SHA-256: `a52b3391c06721946109511a024547ef68be7dbafb813f06990d04ec7090e2fe`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T131`
- Evidence commit message: `evidence(monacode): complete P05-T131`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T131.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaInsertFinalNewLineFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T131.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement insert a final line terminator under explicit command control.`
- implementation-operation: `Register the exact feature identity insertFinalNewLine and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T131.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaInsertFinalNewLineFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaInsertFinalNewLineFeatureTests.swift

<!-- G6-R-TASK:P05-T132:ac122c28a9e147ec48ea87ab3e39f54d0b5d4398cf60e2ebd4141f56e0a4e287 -->

### P05-T132 — Implement retained feature inspectTokens

- Record SHA-256: `ac122c28a9e147ec48ea87ab3e39f54d0b5d4398cf60e2ebd4141f56e0a4e287`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T132`
- Evidence commit message: `evidence(monacode): complete P05-T132`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T132.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaInspectTokensFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T132.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement expose token, scope, foreground, background, and source inspection data.`
- implementation-operation: `Register the exact feature identity inspectTokens and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T132.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaInspectTokensFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaInspectTokensFeatureTests.swift

<!-- G6-R-TASK:P05-T133:5398d5257215cc91df00e37de1e4ae2d0a31867f5684544e02b4de1ae0036f56 -->

### P05-T133 — Implement retained feature lineSelection

- Record SHA-256: `5398d5257215cc91df00e37de1e4ae2d0a31867f5684544e02b4de1ae0036f56`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T133`
- Evidence commit message: `evidence(monacode): complete P05-T133`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T133.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaLineSelectionFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T133.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement create and extend whole-line selections with final-line edge handling.`
- implementation-operation: `Register the exact feature identity lineSelection and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T133.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaLineSelectionFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaLineSelectionFeatureTests.swift

<!-- G6-R-TASK:P05-T134:3b711b9448a4986c315ff821e66875392e1091b69f567f6af495c1cc52e82c0c -->

### P05-T134 — Implement retained feature linesOperations

- Record SHA-256: `3b711b9448a4986c315ff821e66875392e1091b69f567f6af495c1cc52e82c0c`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T134`
- Evidence commit message: `evidence(monacode): complete P05-T134`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T134.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaLinesOperationsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T134.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement move, copy, delete, join, sort, trim, transpose, and duplicate lines transactionally.`
- implementation-operation: `Register the exact feature identity linesOperations and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T134.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaLinesOperationsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaLinesOperationsFeatureTests.swift

<!-- G6-R-TASK:P05-T135:8aa3e3997a81d63e75677fcb9e32c25a6b69de40423897acb6acefd975f4d518 -->

### P05-T135 — Implement retained feature linkedEditing

- Record SHA-256: `8aa3e3997a81d63e75677fcb9e32c25a6b69de40423897acb6acefd975f4d518`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T135`
- Evidence commit message: `evidence(monacode): complete P05-T135`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T135.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaLinkedEditingFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T135.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement mirror linked-editing ranges under provider version and cancellation gates.`
- implementation-operation: `Register the exact feature identity linkedEditing and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T135.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaLinkedEditingFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaLinkedEditingFeatureTests.swift

<!-- G6-R-TASK:P05-T136:ccc8bc705d6ecf4dabeccfcd0eaa8d3205a2dee6be6536635e2bdcfe84f954dc -->

### P05-T136 — Implement retained feature links

- Record SHA-256: `ccc8bc705d6ecf4dabeccfcd0eaa8d3205a2dee6be6536635e2bdcfe84f954dc`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T136`
- Evidence commit message: `evidence(monacode): complete P05-T136`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T136.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaLinksFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T136.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement request, resolve, underline, activate, and release document links.`
- implementation-operation: `Register the exact feature identity links and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T136.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaLinksFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaLinksFeatureTests.swift

<!-- G6-R-TASK:P05-T137:d353a6c35218555a9db46c2c049686a403bd5214fa95fb999c1c4e4b1dd47acd -->

### P05-T137 — Implement retained feature longLinesHelper

- Record SHA-256: `d353a6c35218555a9db46c2c049686a403bd5214fa95fb999c1c4e4b1dd47acd`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T137`
- Evidence commit message: `evidence(monacode): complete P05-T137`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T137.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaLongLinesHelperFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T137.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement enforce the configured long-line rendering cutoff and explicit unlimited mode.`
- implementation-operation: `Register the exact feature identity longLinesHelper and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T137.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaLongLinesHelperFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaLongLinesHelperFeatureTests.swift

<!-- G6-R-TASK:P05-T138:98be0a0a93b2aa119f6110d3f398fcb4d6071b12bd0e071fe0fc83bbcb8392ed -->

### P05-T138 — Implement retained feature middleScroll

- Record SHA-256: `98be0a0a93b2aa119f6110d3f398fcb4d6071b12bd0e071fe0fc83bbcb8392ed`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T138`
- Evidence commit message: `evidence(monacode): complete P05-T138`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T138.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaMiddleScrollFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T138.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement implement native middle-button scrolling with bounded velocity and cancellation.`
- implementation-operation: `Register the exact feature identity middleScroll and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T138.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaMiddleScrollFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaMiddleScrollFeatureTests.swift

<!-- G6-R-TASK:P05-T139:0f5530e436913a376f5379cd74a0eef96de136824254288d0b3d04c575d29b2d -->

### P05-T139 — Implement retained feature multicursor

- Record SHA-256: `0f5530e436913a376f5379cd74a0eef96de136824254288d0b3d04c575d29b2d`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T139`
- Evidence commit message: `evidence(monacode): complete P05-T139`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T139.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaMulticursorFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T139.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement add, remove, merge, select, and edit 1, 100, and 10000 cursors in stable order.`
- implementation-operation: `Register the exact feature identity multicursor and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T139.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaMulticursorFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaMulticursorFeatureTests.swift

<!-- G6-R-TASK:P05-T140:fc3102d58483e48865e4953cf3457056373ef7c59c36df63c0f27e2fd3395eaa -->

### P05-T140 — Implement retained feature parameterHints

- Record SHA-256: `fc3102d58483e48865e4953cf3457056373ef7c59c36df63c0f27e2fd3395eaa`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T140`
- Evidence commit message: `evidence(monacode): complete P05-T140`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T140.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaParameterHintsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T140.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement trigger, cycle, update, and dismiss signature-help results.`
- implementation-operation: `Register the exact feature identity parameterHints and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T140.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaParameterHintsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaParameterHintsFeatureTests.swift

<!-- G6-R-TASK:P05-T141:cf170f6cc446c02114c25f02ce66935bca852de5e1b78cc97fcfe17df7136f25 -->

### P05-T141 — Implement retained feature placeholderText

- Record SHA-256: `cf170f6cc446c02114c25f02ce66935bca852de5e1b78cc97fcfe17df7136f25`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T141`
- Evidence commit message: `evidence(monacode): complete P05-T141`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T141.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaPlaceholderTextFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T141.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement render placeholder presentation only while the model is empty.`
- implementation-operation: `Register the exact feature identity placeholderText and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T141.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaPlaceholderTextFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaPlaceholderTextFeatureTests.swift

<!-- G6-R-TASK:P05-T142:cf875e6069a4acaa7d286d7b6727214cb3a2ec33ea59feb2781303a42e358d6a -->

### P05-T142 — Implement retained feature quickCommand

- Record SHA-256: `cf875e6069a4acaa7d286d7b6727214cb3a2ec33ea59feb2781303a42e358d6a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T142`
- Evidence commit message: `evidence(monacode): complete P05-T142`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T142.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaQuickCommandFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T142.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement filter and invoke registered editor commands with exact enablement.`
- implementation-operation: `Register the exact feature identity quickCommand and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T142.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaQuickCommandFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaQuickCommandFeatureTests.swift

<!-- G6-R-TASK:P05-T143:0bccf07c2a009548a675184b298d07205bbd5b08ac42dd53924de3ea7f4191d4 -->

### P05-T143 — Implement retained feature quickHelp

- Record SHA-256: `0bccf07c2a009548a675184b298d07205bbd5b08ac42dd53924de3ea7f4191d4`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T143`
- Evidence commit message: `evidence(monacode): complete P05-T143`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T143.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaQuickHelpFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T143.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement present retained keyboard and accessibility help from localized messages.`
- implementation-operation: `Register the exact feature identity quickHelp and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T143.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaQuickHelpFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaQuickHelpFeatureTests.swift

<!-- G6-R-TASK:P05-T144:0e0fa90edc9fe71ff8e42713a43f977147922b85b4e4430beb89e2cee614038b -->

### P05-T144 — Implement retained feature quickOutline

- Record SHA-256: `0e0fa90edc9fe71ff8e42713a43f977147922b85b4e4430beb89e2cee614038b`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T144`
- Evidence commit message: `evidence(monacode): complete P05-T144`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T144.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaQuickOutlineFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T144.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement filter, group, and navigate document symbols in the quick outline.`
- implementation-operation: `Register the exact feature identity quickOutline and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T144.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaQuickOutlineFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaQuickOutlineFeatureTests.swift

<!-- G6-R-TASK:P05-T145:b0c7659f46ad27951cc0021c07ab420fae74e09ccb0f156394a423bb14429ba1 -->

### P05-T145 — Implement retained feature readOnlyMessage

- Record SHA-256: `b0c7659f46ad27951cc0021c07ab420fae74e09ccb0f156394a423bb14429ba1`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T145`
- Evidence commit message: `evidence(monacode): complete P05-T145`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T145.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaReadOnlyMessageFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T145.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement present explicit localized feedback for rejected read-only mutations.`
- implementation-operation: `Register the exact feature identity readOnlyMessage and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T145.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaReadOnlyMessageFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaReadOnlyMessageFeatureTests.swift

<!-- G6-R-TASK:P05-T146:0a2de3fd1f615912245a09f43fda08d3b2fc98ba61a67e3d984c340963c2e81c -->

### P05-T146 — Implement retained feature referenceSearch

- Record SHA-256: `0a2de3fd1f615912245a09f43fda08d3b2fc98ba61a67e3d984c340963c2e81c`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T146`
- Evidence commit message: `evidence(monacode): complete P05-T146`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T146.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaReferenceSearchFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T146.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement stream, group, navigate, and cancel reference provider results.`
- implementation-operation: `Register the exact feature identity referenceSearch and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T146.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaReferenceSearchFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaReferenceSearchFeatureTests.swift

<!-- G6-R-TASK:P05-T147:f25759f0eceaa4cfbbe6f7661a842ea97a4d5b16de4d786c27d43741ab28fff2 -->

### P05-T147 — Implement retained feature rename

- Record SHA-256: `f25759f0eceaa4cfbbe6f7661a842ea97a4d5b16de4d786c27d43741ab28fff2`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T147`
- Evidence commit message: `evidence(monacode): complete P05-T147`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T147.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaRenameFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T147.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement prepare rename, collect workspace edits, preview failures, and apply atomically.`
- implementation-operation: `Register the exact feature identity rename and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T147.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaRenameFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaRenameFeatureTests.swift

<!-- G6-R-TASK:P05-T148:d030130042a1c1cabf7463f7db04cb7e0c2ad99ac3f42e371c17f03135e64999 -->

### P05-T148 — Implement retained feature sectionHeaders

- Record SHA-256: `d030130042a1c1cabf7463f7db04cb7e0c2ad99ac3f42e371c17f03135e64999`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T148`
- Evidence commit message: `evidence(monacode): complete P05-T148`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T148.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaSectionHeadersFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T148.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement derive and render section-header decorations from configured patterns.`
- implementation-operation: `Register the exact feature identity sectionHeaders and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T148.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaSectionHeadersFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaSectionHeadersFeatureTests.swift

<!-- G6-R-TASK:P05-T149:e6dfd6a406a73d9dc9b1e1c7cc50b0001516f028eb490a6aa01ac2f0e7f9e6ce -->

### P05-T149 — Implement retained feature semanticTokens

- Record SHA-256: `e6dfd6a406a73d9dc9b1e1c7cc50b0001516f028eb490a6aa01ac2f0e7f9e6ce`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T149`
- Evidence commit message: `evidence(monacode): complete P05-T149`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T149.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaSemanticTokensFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T149.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement apply full and delta semantic-token results by version and result identifier.`
- implementation-operation: `Register the exact feature identity semanticTokens and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T149.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaSemanticTokensFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaSemanticTokensFeatureTests.swift

<!-- G6-R-TASK:P05-T150:77ccbb395b6ad8c3a09eab9e47dda33ab6229212acac074806651919af05ba89 -->

### P05-T150 — Implement retained feature smartSelect

- Record SHA-256: `77ccbb395b6ad8c3a09eab9e47dda33ab6229212acac074806651919af05ba89`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T150`
- Evidence commit message: `evidence(monacode): complete P05-T150`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T150.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaSmartSelectFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T150.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement expand and shrink provider selection ranges while retaining orientation.`
- implementation-operation: `Register the exact feature identity smartSelect and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T150.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaSmartSelectFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaSmartSelectFeatureTests.swift

<!-- G6-R-TASK:P05-T151:eed120eea88cad423cdf1624b801f7db1ac7d2ae860abd576162ba9d04678cdd -->

### P05-T151 — Implement retained feature snippet

- Record SHA-256: `eed120eea88cad423cdf1624b801f7db1ac7d2ae860abd576162ba9d04678cdd`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T151`
- Evidence commit message: `evidence(monacode): complete P05-T151`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T151.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaSnippetFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T151.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement insert and navigate snippet sessions using the Phase 06 snippet engine.`
- implementation-operation: `Register the exact feature identity snippet and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T151.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaSnippetFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaSnippetFeatureTests.swift

<!-- G6-R-TASK:P05-T152:b25e5933989678b53e236a3a4666b67b15f88bc1852e58b43c22756e4a8651c4 -->

### P05-T152 — Implement retained feature stickyScroll

- Record SHA-256: `b25e5933989678b53e236a3a4666b67b15f88bc1852e58b43c22756e4a8651c4`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T152`
- Evidence commit message: `evidence(monacode): complete P05-T152`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T152.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaStickyScrollFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T152.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement project nested symbol and folding context into sticky viewport rows.`
- implementation-operation: `Register the exact feature identity stickyScroll and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T152.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaStickyScrollFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaStickyScrollFeatureTests.swift

<!-- G6-R-TASK:P05-T153:16e42d9a57b386ba10ac763ee72b29576fa2550292e92b1367206835ada121db -->

### P05-T153 — Implement retained feature suggest

- Record SHA-256: `16e42d9a57b386ba10ac763ee72b29576fa2550292e92b1367206835ada121db`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T153`
- Evidence commit message: `evidence(monacode): complete P05-T153`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T153.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaSuggestFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T153.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement trigger, filter, rank, resolve, accept, release, and remember completion items.`
- implementation-operation: `Register the exact feature identity suggest and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T153.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaSuggestFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaSuggestFeatureTests.swift

<!-- G6-R-TASK:P05-T154:4bc02df5e25ac63245319502f66b133841e5f5ce19f0afc1ad4840c96dcb42f6 -->

### P05-T154 — Implement retained feature toggleHighContrast

- Record SHA-256: `4bc02df5e25ac63245319502f66b133841e5f5ce19f0afc1ad4840c96dcb42f6`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T154`
- Evidence commit message: `evidence(monacode): complete P05-T154`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T154.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaToggleHighContrastFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T154.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement toggle the explicit high-contrast theme profile and invalidate paint state.`
- implementation-operation: `Register the exact feature identity toggleHighContrast and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T154.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaToggleHighContrastFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaToggleHighContrastFeatureTests.swift

<!-- G6-R-TASK:P05-T155:b61b77f3b90983f84817895ef4042ca06989581e15370cfe2a461092f7538012 -->

### P05-T155 — Implement retained feature toggleTabFocusMode

- Record SHA-256: `b61b77f3b90983f84817895ef4042ca06989581e15370cfe2a461092f7538012`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T155`
- Evidence commit message: `evidence(monacode): complete P05-T155`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T155.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Features/MonaToggleTabFocusModeFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T155.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement switch Tab between editor command handling and native focus traversal.`
- implementation-operation: `Register the exact feature identity toggleTabFocusMode and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T155.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Features/MonaToggleTabFocusModeFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Features/MonaToggleTabFocusModeFeatureTests.swift

<!-- G6-R-TASK:P05-T156:d19087010c4baabeae09a8e087931c712a0d19d37efb0b5700dd0ebebeb9c184 -->

### P05-T156 — Implement retained feature tokenization

- Record SHA-256: `d19087010c4baabeae09a8e087931c712a0d19d37efb0b5700dd0ebebeb9c184`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T156`
- Evidence commit message: `evidence(monacode): complete P05-T156`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T156.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaTokenizationFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T156.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement consume direct token providers and retain plain-text tokens when none is attached.`
- implementation-operation: `Register the exact feature identity tokenization and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T156.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaTokenizationFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaTokenizationFeatureTests.swift

<!-- G6-R-TASK:P05-T157:27bf638e42c84f2c73892b97d5bd252131d2df0f695eca133486458c21c1ae80 -->

### P05-T157 — Implement retained feature unicodeHighlighter

- Record SHA-256: `27bf638e42c84f2c73892b97d5bd252131d2df0f695eca133486458c21c1ae80`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T157`
- Evidence commit message: `evidence(monacode): complete P05-T157`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T157.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaUnicodeHighlighterFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T157.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement detect configured invisible, ambiguous, and non-basic Unicode spans.`
- implementation-operation: `Register the exact feature identity unicodeHighlighter and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T157.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaUnicodeHighlighterFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaUnicodeHighlighterFeatureTests.swift

<!-- G6-R-TASK:P05-T158:4e46a473080da75df0a0733ac636a7e0275924b8606be03e15c4d367056a890e -->

### P05-T158 — Implement retained feature unusualLineTerminators

- Record SHA-256: `4e46a473080da75df0a0733ac636a7e0275924b8606be03e15c4d367056a890e`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T158`
- Evidence commit message: `evidence(monacode): complete P05-T158`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T158.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaUnusualLineTerminatorsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T158.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement detect and explicitly remove unusual line terminators transactionally.`
- implementation-operation: `Register the exact feature identity unusualLineTerminators and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T158.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaUnusualLineTerminatorsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaUnusualLineTerminatorsFeatureTests.swift

<!-- G6-R-TASK:P05-T159:9b359dc3ce80cdf3e8a7a8b071291bdf13b83bf421449e7080fdf37121e7189d -->

### P05-T159 — Implement retained feature wordHighlighter

- Record SHA-256: `9b359dc3ce80cdf3e8a7a8b071291bdf13b83bf421449e7080fdf37121e7189d`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T159`
- Evidence commit message: `evidence(monacode): complete P05-T159`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T159.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaWordHighlighterFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T159.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement combine textual and provider document highlights with version gating.`
- implementation-operation: `Register the exact feature identity wordHighlighter and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T159.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaWordHighlighterFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaWordHighlighterFeatureTests.swift

<!-- G6-R-TASK:P05-T160:bbbfa89e7b9bf1d4739b5bc7217d631aacd365642fcca85d4b65cb394641c62d -->

### P05-T160 — Implement retained feature wordOperations

- Record SHA-256: `bbbfa89e7b9bf1d4739b5bc7217d631aacd365642fcca85d4b65cb394641c62d`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T160`
- Evidence commit message: `evidence(monacode): complete P05-T160`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T160.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaWordOperationsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T160.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement move, delete, and transform by the frozen word boundary profile.`
- implementation-operation: `Register the exact feature identity wordOperations and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T160.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaWordOperationsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaWordOperationsFeatureTests.swift

<!-- G6-R-TASK:P05-T161:da0a8300633268fe070496ef3ba0832c8b76f6dc5825cd56ab82cb69f7478703 -->

### P05-T161 — Implement retained feature wordPartOperations

- Record SHA-256: `da0a8300633268fe070496ef3ba0832c8b76f6dc5825cd56ab82cb69f7478703`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T012`, `P05-T013` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T161`
- Evidence commit message: `evidence(monacode): complete P05-T161`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T161.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Features/MonaWordPartOperationsFeatureTests.swift`

### Stage `red`

- verification-command: `P05-T161.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement move and delete by camel, underscore, digit, and punctuation word parts.`
- implementation-operation: `Register the exact feature identity wordPartOperations and its declared commands, actions, contributions, options, menus, and keybindings.`
- implementation-operation: `Route model mutation, asynchronous publication, disposal, localization, and degraded plain-text behavior through the shared gateways.`

### Stage `green`

- verification-command: `P05-T161.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Features/MonaWordPartOperationsFeature.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Features/MonaWordPartOperationsFeatureTests.swift

<!-- G6-R-TASK:P05-T190:88afd5ac070f5c81ce575d3d9b2b5d5940e2a50214ef677b20558d7d07635f02 -->

### P05-T190 — Produce and validate the provisional native declaration manifest

- Record SHA-256: `88afd5ac070f5c81ce575d3d9b2b5d5940e2a50214ef677b20558d7d07635f02`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T002`, `P05-T004`, `P05-T007`, `P05-T009`, `P05-T010`, `P05-T011`, `P05-T012`, `P05-T013`, `P05-T100`, `P05-T101`, `P05-T102`, `P05-T103`, `P05-T104`, `P05-T105`, `P05-T106`, `P05-T107`, `P05-T108`, `P05-T109`, `P05-T110`, `P05-T111`, `P05-T112`, `P05-T113`, `P05-T114`, `P05-T115`, `P05-T116`, `P05-T117`, `P05-T118`, `P05-T119`, `P05-T120`, `P05-T121`, `P05-T122`, `P05-T123`, `P05-T124`, `P05-T125`, `P05-T126`, `P05-T127`, `P05-T128`, `P05-T129`, `P05-T130`, `P05-T131`, `P05-T132`, `P05-T133`, `P05-T134`, `P05-T135`, `P05-T136`, `P05-T137`, `P05-T138`, `P05-T139`, `P05-T140`, `P05-T141`, `P05-T142`, `P05-T143`, `P05-T144`, `P05-T145`, `P05-T146`, `P05-T147`, `P05-T148`, `P05-T149`, `P05-T150`, `P05-T151`, `P05-T152`, `P05-T153`, `P05-T154`, `P05-T155`, `P05-T156`, `P05-T157`, `P05-T158`, `P05-T159`, `P05-T160`, `P05-T161` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T190`
- Evidence commit message: `evidence(monacode): complete P05-T190`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T190.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/NativeDeclarationManifestTests.mjs`

### Stage `red`

- verification-command: `P05-T190.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Join all retained and disposition-only declaration, registry, option, theme, localization, feature, and native-adaptation rows.`
- implementation-operation: `Verify exact identity, disposition, native symbol, signature, owner, test owner, and source hash.`
- implementation-operation: `Mark the output provisional because Phase 07 public API closure and Phase 08 regeneration have not occurred.`

### Stage `green`

- verification-command: `P05-T190.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Candidates/build-native-declaration-manifest.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/NativeDeclarationManifestTests.mjs

<!-- G6-R-TASK:P05-T200:766d21ffd91ae66da8f30b03092b9f494ff349d8cd00709a6bbd1f774a6797ae -->

### P05-T200 — Close the retained public surface, registries, options, themes, localization, and features

- Record SHA-256: `766d21ffd91ae66da8f30b03092b9f494ff349d8cd00709a6bbd1f774a6797ae`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T190` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P05-T200`
- Evidence commit message: `evidence(monacode): complete P05-T200`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-05/P05-T200.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Phase05PublicSurfaceConformanceTests.swift`

### Stage `red`

- verification-command: `P05-T200.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run identity-set, signature, native adaptation, registry ordering, option boundary, theme, localization, feature behavior, disposal, and plain-text degradation matrices.`
- implementation-operation: `Assert exactly 62 retained feature IDs, zero missing retained feature IDs, and three distinct native colorize replacements.`
- implementation-operation: `Reject any cut, later, built-in language, or WebGPU identity that becomes production-owned.`

### Stage `green`

- verification-command: `P05-T200.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - _(none)_
- modify:
  - _(none)_
- test:
  - Tests/ConformanceAndFailureInjection/Phase05PublicSurfaceConformanceTests.swift
