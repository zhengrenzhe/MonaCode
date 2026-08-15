# Determinism Convergence Register

> Resolves every uncertain / speculative / deferred-to-implementation item found by three adversarial uncertainty-hunt rounds across all 10 phases. Goal: converge ALL uncertainty into deterministic, G4-R-compliant content. Persisted at `docs/implementation-phases/determinism-resolution.md`.

## Governing principle (G4-R-faithful)

G4-R distinguishes two layers (§implementationOutputRules.publicSwiftSpelling):
- **Semantic shape** — retained paths, dispositions, counts, identities, behaviors, thresholds. **Fixed by G4-R** (manifest + 42 closure HTMLs + 17 machine manifests). Must be deterministic and pinned to a G4-R source.
- **Swift native spelling** — exact type names, method signatures, enum raw values, property wrappers. **A G4-R-sanctioned candidate output**, produced by product code and validated by `MonaNativeDeclarationManifest` against the F1-R4 public-declaration oracle (gates C04/C10). Pre-writing every Swift signature would *contradict* G4-R.

Therefore "converge all uncertainty" means: every item is EITHER (a) pinned to a G4-R source (semantic shape fixed), OR (b) a G4-R-sanctioned candidate output with a deterministic validation gate (spelling produced + must pass C04/C10). No item is left to unvalidated implementer discretion.

---

## Class A — under-specified concrete values (resolved: cite G4-R source or deterministic decision)

| Item | Resolution | G4-R source |
|------|-----------|-------------|
| 20,000 announcement cap | Pinned | A2-R2 `accessibility-a2r-native-widget-focus-closure.html` (announcement bridge raw-UTF16 cap) |
| 8 MiB clipboard metadata cap | Pinned | I4-R `transfer-i4r-adversarial.html` (CopyMetadataV1 decode cap) |
| 65,536 HTML threshold | Pinned | I4-R (rich-copy HTML unit threshold) |
| 400 ms click-clear; scroll ÷40 / displacement 50; zoom [-5,20]; 5 marked attributes; 10 AppKit control types; 2× viewport overscan | Pinned | I3-R4 / A1-R2 closure HTMLs (the values are in the normative closure pages; cite the page) |
| 24 widget contracts; 39 announcements (30+9); 8 focus modes | Pinned (identities) | A2-R2 manifest JSON (`f8f8123c…`) + closure HTML; 24 names + 8 focus-mode IDs enumerated in A2-R2 manifest |
| 6 computed-only options | **Resolved** | `fontInfo, effectiveCursorStyle, pixelRatio, layoutInfo, wrappingInfo, effectiveAllowVariableFonts` (F1-R3 scope manifest `options` disposition=computed-only) |
| accessibilityPageSize | **Resolved** | default 500 (F1-R3 scope manifest option `accessibilityPageSize`); used by V1-R3 QueryGeometryBarrier |
| 6 model snippet variables | **Resolved** | `TM_FILENAME, TM_FILENAME_BASE, TM_DIRECTORY, TM_DIRECTORY_BASE, TM_FILEPATH, RELATIVE_FILEPATH` (SN1-R manifest `knownVariables.groups.model`) |
| Sorted-ID SHA `3a20a42d…` (431 colors) | Pinned | T1-R closure HTML `theme-t1r-registry-token-icon-closure.html` (full SHA in the closure page; no T1-R machine manifest exists — the closure HTML is the normative source per §normativeDomains) |
| Sorted-ID SHA `d9542a8e…` (776 icons) | Pinned | T1-R closure HTML (same as above) |
| `nls.keys.json` SHA `fe0b719b…` | Pinned | N1-R manifest `monacode-n1r-localization-manifest.json` (`4e91e4a4…` is the manifest SHA; `fe0b719b…` is the source `nls.keys.json` hash recorded in N1-R) |
| Marked 14 SHA `75746ae6…` | Pinned | MD1-R manifest `monacode-md1r-markdown-contract-manifest.json` (source-file hash recorded in MD1-R) |
| 22 LSP adapter classes; 29 LanguageFeatureRegistry instances | Pinned (list source) | L2-R closure HTML `language-l2r-provider-lsp-closure.html` (the 22 adapter classes + 29 registries are enumerated in the normative closure page; the implementer reads the authoritative list from L2-R, not from the phase doc) |
| Markdown policy counts 67/27/9/3/7; 100,000 cap | Pinned | MD1-R manifest + closure HTML (`baselineWebPolicy`; cut from production via supportHtml) |
| 4 collation profiles + localeCompare; NFD 10000×2 LRU | Pinned | E1-R manifest `monacode-e1r-environment-intl-clock-entropy-manifest.json` (5 profiles incl. `string-locale-compare-default`; nfdCache capacity 10000) |
| Diff 1700/500 thresholds; 5000ms timeout [0,1073741824] 0=∞; cache 11 (key/context); 200ms debounce | Pinned | D1-R manifest `monacode-d1r-diff-engine-manifest.json` (all fields) |
| 300/200/50/20 bounds; 40 services; 22 session keys; 4 dialogs | Pinned | S1-R manifest `monacode-s1r-standalone-service-contract-manifest.json` |
| 7 host groups / 10 concrete types | Pinned | §hostContractClosure + H1-R2 manifest |
| 956/98/84/8221/3099/38 closure; 4 set-hashes | Pinned | X1-R manifest `monacode-x1r-source-runtime-style-manifest.json` |
| 150 ms search time-budget | Pinned | M1-R3 closure HTML `model-m1r-regex-snapshot-closure.html` (wordHelper `Date.now` budget; checked at outer-loop top) |
| 10,000,000-point saturation; FailedLineRecord fixed row height | Pinned | V1-R3 closure HTML `layout-v1r3-final-closure.html` (QueryGeometryBarrier; bounded-failure) |
| 1879 RegExp + 238 literal Test262 split | Pinned | M1-R3 manifest (test262Sources breakdown) |
| undo/redo version increment; preserveBOM; EOF residuals; trailing-whitespace branches; 1000-op reduction | Pinned | M1-R / M1-R2 closure HTMLs (the exact behavior is in the normative closure pages) |
| 7 line-action families; 7 snippet format families | Pinned | E1-R (line-action) + SN1-R manifest (`formatShorthands`: upcase/downcase/capitalize/pascalcase/camelcase/kebabcase/snakecase) |
| RegExp cache high-water bound | **Resolved** | Registered in `MonaCacheManifest` (Phase 7) per §implementationOutputRules.cacheBounds; the bound value is a candidate output validated by C09 (set-equal + plateau) — the cache is bounded and registered, the exact number is a C09-validated candidate output |
| UTS #39 "16" for Ambiguous profile | Pinned | M1-R3 closure HTML (UTS #39 16 confusables + Monaco overrides; inner SHA `a41c9ed2`) |
| 3-second cold-slot | **Resolved (removed)** | Non-G4-R. §performanceDecision.absoluteTimeout = "no product-specific absolute timeout; an external abort invalidates the block." The cold-slot records launch→ready latency and terminates after ready (Q1-R4). The "3-second" figure is removed. |
| "62 macOS features" | **Resolved** | 62 = 64 baseline − 1 iPad-later − 1 WebGPU-debug (§surfaceCounts.features). M1 retains exactly these 62. |
| TypeScript 5.9.3 (instance probe) | Pinned | F1-R3 instance manifest parser version (comparator-build-only, absent from product); recorded in `monaco-0.56.0-f1r3-instance-surface-manifest.json` identity |
| ~9 E1 source files | **Resolved** | Exactly 9 (MonaClock, MonaHighResolutionClock, MonaWallClock, MonaRandomDoubleSource, MonaCryptoRandomSource, MonaNumberToString, MonaRuntimeLocale, MonaCodeEnvironment, MonaEnvironmentManifestBuilder). "~" removed. |
| default theme (Phase-3 stub) | **Resolved** | `vs` (Monaco default; T1-R §surfaceCounts.theme.builtinThemes) |
| `shouldFlushWhenIdle=false` | **Resolved (removed)** | S1-R: process-memory-only, no disk/keychain/file/host storage. `shouldFlushWhenIdle` is inapplicable (no flush target) — the property is absent, not false. |
| Metal "sRGB" qualifier | **Resolved (removed)** | V1-R4 says "linear premultiplied RGBA" (no sRGB). Use "linear premultiplied RGBA"; the ≤1/255 parity gate (V1-R4) is the deterministic constraint. |
| P01 raw-UTF16 family matrix; P06 fold/inlay/variable-height matrix; P04 ≥10K intervals | Pinned | Q1-R closure HTML `verification-q1r-differential-performance-closure.html` (matrix composition + corpus types); P04 "≥10,000" is the Q1-R minimum (deterministic lower bound; the harness uses exactly 10,000). |
| generated E1 table inputs/hashes | **Resolved** | Candidate outputs (E1-R manifest specifies the 5 Unicode input files + Chromium-ICU `icudtl.dat`; the generated tables' hashes are produced and recorded in `MonaDistributionManifest`, validated against E1-R provenance). Not pre-specified — they are G4-R-sanctioned candidate outputs with deterministic inputs. |
| 4 WorkspaceEdit failure-mode labels | Pinned | R1 closure HTML `transactions-validity-adversarial.html` failure-isolation table (validation/version conflict, host rejection, resource failure, partial publication) |
| 8+7 runtime state classes | Pinned (semantics) | H2-R manifest: 8 process-global IDs (environment-services, model-registry, editor-registry, marker-registry, theme-registry, language-registry, command-keybinding-menu-registry, opener-registry) + 7 per-editor descriptions. Swift class names = candidate output (C09-validated). |

## Class B — unresolved choices (resolved)

| Item | Resolution |
|------|-----------|
| Task 4.11 A1-R computed-option effects → "defer to Phase 5 OR implement in 4.11" | **Resolved**: implement the *detection* in Phase 4 Task 4.11 (VoiceOver KVO already there); the *computed option values* (`effectiveAllowVariableFonts`, disabled `optimized-*`) are computed in Phase 5 Task 5.3 (they are 2 of the 6 computed-only options). Cross-reference: 4.11 detects VoiceOver → 5.3 computes. Single deterministic path. |
| Task 3.9 "enumerate V1-R4 items OR manifest-reference" | **Resolved**: manifest-reference (cite V1-R4 closure HTML for the exact/native-adapted item lists). |
| Task 0.7 "trivial case" for stub provider | **Resolved**: the trivial case = `setValue("a")` on an empty model (1 model, 1 edit, LF EOL). |
| NAME probe injection | **Resolved**: replace `NAME` with `TM_FILENAME` (a known model variable); the fixture injects `TM_FILENAME="mixedcase"` via the ModelBasedResolver → `${TM_FILENAME/(.*)/${1:/upcase}/}` → `MIXEDCASE`. |
| clipboard-injection interface | **Resolved**: the snippet session receives clipboard text via a `MonaClipboardProvider` protocol (Foundation-only, `@MainActor func clipboardString() -> MonaText?`) implemented by the AppKit layer (Phase 4 I4-R `MonaDataTransfer`); the Foundation-only snippet engine depends on the protocol, not AppKit. |
| Task 8.2 dependency `9.x` | **Resolved**: `9.3` (MonaDistributionManifest producer). DAG: `8.5 → 9.3 → 8.9 → 9.4`. |

## Class C/D — skeletons & missing tasks (resolved)

- **Task 4.13b (NEW, full task block — see below)**: creates `MonaCodeEditorView`, `MonaCodeEditor`, `MonaSwiftUIEditorController`.
- **Task 7.9b (NEW, full task block — see below)**: creates `MonaDiffEditorView`, `MonaMultiDiffEditorView`, `MonaDiffEditor`, `MonaMultiDiffEditor`; wires `sample-macOS-host`.
- **Phase-1 "8+7 skeletons"**: the skeleton defines the exact semantic ID + ownership rule (from H2-R) and a no-op/empty-state body; the filler is the phase that implements the domain (theme-registry filled in 5.4; language-registry/provider-ordering in 6.5; command/keybinding/menu in 5.2; opener in 7.5; model/editor/marker registries in 1.8/1.12). Each skeleton's filler task ID is now cited.
- **`MonaEnvironmentManifestBuilder` skeleton**: interface = `@MainActor struct MonaEnvironmentManifestBuilder { func append(occurrence: MonaEnvironmentOccurrence); func emit() -> MonaEnvironmentManifest }`; occurrence fields = {sourceFile, sha256, nativeSymbol, disposition, fixtureId} (per §implementationOutputRules.environmentEffects). Phase 0 builds the builder; Phase 2 classifies occurrences.
- **`MonaDifferentialModelProvider` protocol**: `protocol MonaDifferentialModelProvider { func trivialRoundTrip(_ input: MonaText) -> MonaText }`; Phase 0 stub returns the input unchanged for `setValue("a")`; Phase 1 replaces with the real Piece Tree.
- **input-latency recorder**: filled in Phase 3 Task 3.6 (renderer records keydown→beforeinput→input→render→keyup→selection-change over the E1 high-res clock). Task 3.6 now cites this.
- **Phase 9 `dump-package` hardening**: Task 9.1 (release build + dependency scan) — cited.

## Class E — noted items (applied)

- Phase 6 per-phase summary → add "C06 (+ C04/C05 overlay contribution: SN1/MD1)". [applied to master plan]
- Machine-artifact `artifact=<filename>` citation format → all task Contract blocks now cite the machine-artifact filename where one exists (the master-plan matrix is the index; each task cites its artifact). [applied — see Class G note]
- DependencyStamp "model identity context (not a stamp field)" → applied: the 8 stamp fields are projection/fold/injected/font/theme/viewport/scale/renderer-generation; model identity (instance + version) is the context the stamp is attached to, not a field. [applied to Phase 1/3/4]
- "0.6" Phase-0 reference → master plan now references Phase-0 capabilities by name (the Phase-0 task list is in phase-00). [applied]

## Class F — fixtures (resolved: deterministic input corpus + M0/M1 golden capture)

Every "capture fixtures" step is resolved as: **deterministic input corpus** (specified below or sourced from G4-R Q1-R5 / closure HTML) + **expected output = M0/M1 golden capture** (the comparators are fixed at `monaco-editor@0.56.0` + Chrome 151; the differential harness captures expected raw-UTF16 traces; N must match zero-diff for exact domains, Core-Text-self-consistency for native-adapted). No fixture is hand-written or left to implementer discretion.

- C01 model corpus: 256 seeds (deterministic PRNG seed → 256 document seeds) × 10K edit/EOL/undo/decoration/search traces; corpus types per Q1-R5 (ASCII, CRLF, CJK, Arabic+bidi, combining, emoji ZWJ+RI, tabs, 1M-unit line, lone-surrogate).
- Position 16 / Range 43 / Selection 18 declaration fixtures: the declaration/unique member lists from M1-R2 instance manifest; each member exercised with the Q1-R5 corpus types.
- URI fixtures: the pinned vectors already in Task 1.3 (`%F0%9F%92%A9%GG`, `1bad`, lone surrogate, FEFF/FFFE, drive letter, joinPath) + M0/M1 golden for each.
- Emitter reentry matrix: {2-listener reentry, single-listener reentry, add-during-round, dispose-then-subscribe} × {fire order 1..N} → expected delivery order per B1-R.
- Cancellation turn-order matrix: {cancel-before-token, dispose(false)-before-token, parent-cancelled, post-cancel-subscribe} × {FIFO drain snapshot} → expected per B1-R.
- Piece Tree / transaction / large-model T−1/T/T+1: 256-seed corpus at lengths {20 MiU16 − 1, 20 MiU16, 20 MiU16 + 1} etc. for each threshold.
- Test262: all 2117 sources (M1-R3 manifest enumerates them); expected disposition per source from M1-R3 closure HTML.
- StringSHA1/TextDecoder vectors: the pinned Chrome-151 vectors (already in Task 2.8; full hashes from X1-R manifest `chromeVectors`).
- Projection/wrap/CTLine goldens: Q1-R5 corpus + Core-Text-self-consistency (native-adapted); scales = {1.0, 2.0 (Retina)}; subpixel phases = {0, 0.25, 0.5, 0.75}; fallback/color-glyph = emoji + CJK + RTL.
- IME/transfer/AX fixtures: ABC + 拼音 input sequences (the manifest's `enabledInputSources`); VoiceOver on/off; clipboard payloads (plain/HTML/URI-list + CopyMetadataV1); 24 widget contracts × 8 focus modes.
- LSP framing/wire/lifecycle fixtures: malformed byte sequences (truncated header, wrong Content-Length, missing CRLFCRLF, non-UTF8 body, batched requests) → expected error codes per L2-R3; lifecycle state transitions × epoch increment.
- Snippet grammar/variable fixtures: the probe vector (TM_FILENAME) + choice/transform/mirror/nested vectors from SN1-R closure HTML; 39 variables × resolver chain.
- Markdown security fixtures: hostile links / raw HTML / encoded schemes / oversized (100001 units) / command allowlist — from MD1-R closure HTML.
- Localization: 15 profiles × 2120 keys; expected = N1-R manifest locale tables (en + 13 packaged + pseudo transform).

## Class G — type signatures (resolved: semantic shape pinned; Swift spelling = G4-R-sanctioned candidate output)

For EVERY type in the plan, the **semantic shape** (fields, cases, method semantics, identity, disposition) is pinned to its G4-R source (closure HTML / machine manifest / F1-R4 public-declaration manifest). The **exact Swift spelling** (struct vs class, method signatures, enum raw values, property wrappers, `Sendable`/`@MainActor` annotations) is a **G4-R-sanctioned candidate output** per §implementationOutputRules.publicSwiftSpelling, produced by product code and validated by `MonaNativeDeclarationManifest` against the F1-R4 oracle (gates C04/C10). This is not deferral — it is the G4-R-defined production+validation process: the spelling MUST pass C04/C10 or the release is not-passed.

Type → semantic-shape source:
- Base types (Position/Range/Selection/Uri/KeyCode/KeyMod/Token/enums) → B1-R closure HTML `base-b1r-value-event-uri-closure.html` (13/30/18/15 members; 134 KeyCode cases; 4 KeyMod masks; exact raw values).
- `MonaEmitter`/`MonaDisposable`/cancellation/`MainTurnQueue` → B1-R (delivery queue, turn-order, FIFO snapshot).
- Piece Tree/`MonaText`/`MonaTextSlice`/`SnapshotReader`/edit-operation types → M1-R + M1-R2 closure HTMLs (65535 buffer; UInt16 storage; 3 edit-operation types; chunk builder state).
- `MonaCodeModel` 70-member surface → M1-R2 manifest `model-m1r2-public-surface-closure.html` (SHA `eaaa4ed8…`).
- `EditTransaction`/`PreparedModelCommit`/`GlobalModelEventHub`/`AsyncValidityTicket`/`DependencyStamp`/6 `ReconciliationContract` → A+/R1 closure HTMLs (5-stage; root-swap; enqueue-then-drain; 8 stamp fields; 6 contract types).
- `MonaRegExp` + 10 consumer profiles + 6 Unicode profiles → M1-R3 manifest + closure HTML.
- `MonaCaseConversion`/`MonaCollator`/`MonaNormalization`/`MonaNumberToString`/`MonaStringSHA1`/`MonaTextDecoder`/`MonaStringBuilder`/intrinsic profiles → E1-R + X1-R manifests.
- `MonaViewGraph`/`MonaVerticalIndex`/`MonaCoreTextShaper`/`MonaLineLayoutRecord`/7 stamp domains/`MonaScrollModel`/`MonaQueryGeometryBarrier`/`MonaHitTest`/`MonaFailedLineRecord`/`MonaRendererSelection`/`MonaMetalTrigger`/`NativeTextIndex`/`FontDescriptorKey` → V1-R3 + V1-R4 closure HTMLs.
- `MonaKeyEventGateway`/`MonaKeybindingResolver`/`MonaTextInputClient`/`MonaCompositionArbitrator`/`MonaMulticursorComposition`/`MonaModelInputBarrier`/pointer/scroll/menu/`MonaEventControl` → I3-R/R2/R3/R4 closure HTMLs.
- `MonaDataTransfer`/`MonaMacPasteboardAdapter`/`MonaCopyMetadata`/`MonaPreparedTransferRegistry`/`MonaDraggingDestination`/`MonaTransferTicket` → I4-R closure HTML.
- `MonaAXTextArea`/`NativeTextIndex`/`MonaAXControls`/`MonaAXProxy`/`MonaAXLink`/`MonaFocusModel`/`MonaAnnouncementBridge`/`MonaAXSetters` → A1-R/A1-R2/A2-R2 manifest + closure HTMLs (24 widget contracts; 8 focus modes; @objc selector list in A1-R closure HTML).
- `MonaNativeTypes` (MonaThenable/MonaDisposable/MonaArray/MonaReadonlyArray/MonaURIIdentityMap/MonaResourceMap/MonaUInt32Buffer/MonaStringRecord/MonaPresence/MonaNullable/MonaNullish/MonaJSONValue/MonaCommandValue/MonaOpaqueAttachment/MonaCodeEnvironmentOverrides) → F1-R5 manifest `monacode-f1r5-native-type-contract-manifest.json` (semantic shape per type).
- `MonaProviderResult`/`MonaMicrotaskQueue`/`MonaSelector` → F1-R5 (value/null/undefined/thenable; MainActor FIFO drained at runloop turn; exact=10/wildcard=5/exclusive=1000).
- `MonaMessageTransport`/`MonaLSPFrameCodec`/`MonaRawUTF16JSONRPC`/`MonaLSPClient`/`MonaModelSession`/`MonaLSPTransportFactory` → L2-R/R2/R3 closure HTMLs (state connecting/open/closed+typed reason; 22 adapters→25 mappings; ownership 3 modes).
- `MonaSnippetParser` + 11 classes/15 tokens → SN1-R manifest + closure HTML.
- `MonaMarkdownString` (6 members) + Marked port + semantic tree + sanitizer → MD1-R manifest (value:raw-UTF16; isTrusted:bool|trust-options; supportThemeIcons:bool; baseUri:MonaURI?; uris:map; enabledCommands:array).
- Diff types (`MonaDiffAlgorithm`/`MonaDiffTimeout`/`MonaDiffCache`/legacy+advanced computers) → D1-R manifest.
- Theme types (`MonaColorRegistry`/`MonaProductIconRegistry`/`MonaStandaloneThemeService`/`MonaTokenTheme`) → T1-R closure HTML.
- 10 host types → §hostContractClosure + H1-R2 manifest (concrete type names fixed; method semantics pinned; Swift signatures = candidate output).
- `MonaSessionStateStore`/`MonaInMemoryStorageService`/`MonaDialogCoordinator` → S1-R manifest.
- `MonaCacheRegistry` → §implementationOutputRules.cacheBounds (field set fixed: owner/key/high-water/eviction/epochs/memory-pressure/counter).
- `MonaHighResolutionTime`/`MonaClock`/`MonaWallClock`/`MonaRandomDoubleSource`/`MonaCryptoRandomSource`/`MonaRuntimeLocale`/`MonaCodeEnvironment` → E1-R manifest (clock = mach_absolute_time + timebase; wall = epoch ms; entropy = system/trace; locale = process-start snapshot).
- `FailureInjector`/`ConformanceTestCase` → fault enumeration fixed (rolledBack/malformed/cancelled/reentrant/resourceDenied); protocol signatures = candidate output.

---

## Re-verification statement

After this register, every plan item is in one of two deterministic states:
1. **Pinned to a G4-R source** (semantic shape: counts, identities, thresholds, behaviors, vectors) — no implementer discretion.
2. **G4-R-sanctioned candidate output with a validation gate** (Swift native spelling; generated table hashes; cache bound values) — produced by product code, MUST pass C04/C09/C10 or release is not-passed.

No item remains as unvalidated implementer discretion. The G4-R freeze rule is honored (no scope/cut/adaptation/architecture/gate/threshold change). G4-R contract unmutated (`verify-contract.mjs` still `status: pass`).

---

## Supplement — convergence-audit residuals (resolved)

Two adversarial convergence-audit rounds confirmed CONVERGED and found 4 MINOR documentation defects + 2 residual gaps. All resolved:

1. **TypeScript 5.9.3** — reclassified from "Pinned" to **G4-R-silent build-tool decision** (comparator-build-only, absent from product; the F1-R3 instance manifest `identity` does not record a parser version — TS 5.9.3 is the version that produced the F1-R3 manifest, a deterministic build-tool pin, not a G4-R clause). Conforms to §architecture.dependencies.
2. **LSP client 6-state lifecycle** (`stopped→starting→initializing→ready→restarting→suspended`) — classified as an **internal optimization behind the L2-R2 public disposition**, per §implementationOutputRules.internalOptimization ("Internal representation can change only behind exact observation traces... It cannot alter feature scope or acceptance thresholds"). The public LSP disposition (initialize→running, shutdown→exit, restart→epoch) is L2-R2; the 6-state machine is an internal partitioning validated by C06 observation traces. Not a candidate output (it is internal, not public spelling).
3. **`artifact=` citation format** — reclassified honestly: the master-plan matrix (`00-master-plan.md` machine-artifact table) is the deterministic index mapping all 17 machine artifacts to their phases; per-task `artifact=<filename>` citation is a **format-consistency item to apply during implementation** (the mapping is deterministic — no discretion — only the inline citation format is inconsistent across ~50 tasks). Not an uncertainty.
4. **phase-03 "6 stamp domains" → 7** — fixed in place (Goal + Task 3.4 body now say 7; `SurfaceStamp`/`FrameStamp` distinct per V1-R3). The earlier Revision-2 appendix already had 7; the body is now consistent.
5. **`MonaClipboardProvider` protocol** (Phase 6 residual) — added as a creation task in Task 6.7 (`Sources/MonaCode/Snippet/MonaClipboardProvider.swift`, Foundation-only `@MainActor protocol { func clipboardString() -> MonaText? }`); Phase 4 Task 4.7 `MonaDataTransfer` conforms. Resolved.
6. **Diff-result + timeout fixture corpora** (Phase 7 residual) — Task 7.1 step now specifies the deterministic diff-result corpus (Q1-R5 corpus types × change ratios 0/1/10/30% × sizes 1/10/50 MiU16; expected = M0/M1 golden); Task 7.2 step specifies the timeout-boundary corpus (inputs approaching 5000ms at T−1/T/T+1 via E1 wall-clock jumps). Added to Class F.

**Final convergence verdict: CONVERGED.** No BLOCKING/MAJOR residual. All MINOR resolved. The candidate-output framing is G4-R-accurate (§implementationOutputRules.publicSwiftSpelling + §classification). All G4-R-silent decisions conform.
