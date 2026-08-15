# Phase 7 — Diff, Services, Host, Resources, Source Closure

**Goal:** Implement the legacy + advanced diff engines (D1-R), the 40 standalone services + session store + dialogs (S1-R), the 7 host contract groups / 10 concrete types + WorkspaceEdit state machine (H1-R/R2, R1), the H2-R cache registry, and the full X1-R source-closure manifest. Produces `MonaSourceClosureManifest.json` + `MonaCacheManifest.json`. Completes the diff portion of **C05** and **C09**.

**G4-R mapping:** diff-engine D1-R; standalone-services-session-feedback S1-R; native-embedding-host H1-R, H1-R2; runtime-lifetime-resource H2-R (cache registry); source-runtime-style X1-R (full closure).

**Prerequisites:** Phase 6 (provider/LSP/consumers), Phase 5 (host command/opener registries, options), Phase 1 (R1 transactions, registries), Phase 2 (intrinsics/encoding substrate for source-closure cross-reference).

**Exit Gates (this phase completes):**
- **C05 (diff pass)** — legacy/advanced mappings, inner changes, moves, timeout, scheduling, accumulated edits, four algorithm-value dispositions, maxFileSize no-op, 11-entry process cache.
- **C09 (pass)** — 3 products / 3 AppKit views / 4 SwiftUI wrappers / 7 host groups / 10 concrete types; `MonaCacheManifest` exact-set + bounds; H2 recoverable checkpoints.
- **C04 (full pass)** — H1-R2 openers (7.5) + S1-R 40 services (7.3) + X1 source-closure set equality (7.8) + `MonaResourceOpener` absence; completes the C04 contribution started in Phase 5.
- **C07 (full pass)** — S1 dialog roles/focus (7.4) + X1 native style goldens (7.8); completes the C07 native-interaction core from Phase 4.
- Candidate artifacts produced: `MonaSourceClosureManifest.json`, `MonaCacheManifest.json`.
- Preflight: both manifests validate; audit/verify-contract pass.

---

## Task 7.1 — Diff legacy + advanced engines (D1-R)

**Dependencies:** 1.9, 2.8
**Files:** Create `Sources/MonaCode/Diff/MonaLegacyDiffComputer.swift`, `Sources/MonaCode/Diff/MonaAdvancedDiffComputer.swift` (Default + DP + Myers + heuristics + moves); Test `Tests/MonaCodeTests/Diff/test_DiffEngines.swift`
**Tests:** 2 functional engines (legacy `LegacyLinesDiffComputer`; advanced `Default`+`DP`+`Myers`+heuristics+moves) — NOT the same algorithm renamed. 1700 line switch (`original + modified line count < 1700` → improved DP, else Myers). 500 char switch (per-slice `original + modified raw-UTF16 length < 500` → DP, else Myers). Repository-owned Swift source ports of the complete pinned source graph (20 files — the exact file set is enumerated in the D1-R manifest `monacode-d1r-diff-engine-manifest.json` `authorities.sourceFiles`). Execution: capture immutable original/modified snapshots + options on MainActor → compute in Sendable off-main task → return to MainActor for normalization, accumulated-edit application, publication. One serial compute lane per diff editor; different editors compute concurrently; one editor never has two algorithm bodies running concurrently or publishing out of source order.
**Contract:** G4-R §architecture.diffEngine (legacy + advanced Swift source ports; serialized per-editor lanes); D1-R; §surfaceCounts.diffEngine (functionalAlgorithms 2, lineAlgorithmThreshold 1700, characterAlgorithmThreshold 500); §equivalenceDomains.exact (diff mappings).
**Produces:** —
**Exit-gate contribution:** C05 (diff); P10 substrate.
**Steps:**
- [ ] Port legacy + advanced engines; capture diff-result fixtures (deterministic corpus: original/modified text pairs from the Q1-R5 corpus types — ASCII, CRLF, CJK, bidi, 1M-unit line, lone-surrogate — at change ratios 0/1/10/30% and sizes 1/10/50 MiU16; expected = M0/M1 golden diff results captured by the differential harness, zero raw-unit diff for mappings/inner-changes/moves/identical); commit.

## Task 7.2 — Diff algorithms, timeout, cache, external/WASM unavailable (D1-R)

**Dependencies:** 7.1, 0.4
**Files:** Create `Sources/MonaCode/Diff/MonaDiffAlgorithm.swift` (4 values + aliases), `Sources/MonaCode/Diff/MonaDiffTimeout.swift`, `Sources/MonaCode/Diff/MonaDiffCache.swift`, `Sources/MonaCode/Diff/MonaDiffUnavailableEvent.swift`; Test `Tests/MonaCodeTests/Diff/test_DiffOptionsCache.swift`
**Tests:** 4 algorithm values `legacy`/`advanced`/`advanced-external`/`advanced-wasm` (default `advanced`; aliases `smart`→`legacy`, `experimental`→`advanced`). external/wasm: enum values retained, implementation cut; native accepts them, marks diff stale, emits one sanitized `MonaDiffAlgorithmUnavailable` event per computation, publishes no new result, fires no diff-update event, NEVER falls back to legacy/advanced. `maxFileSize` default 50 MB but compute reads = 0 (4 source occurrences are default/schema/clamp only — never gates computation); native must NOT add a 50 MB reject/truncate. `maxComputationTime` default 5000 ms; range [0, 1073741824]; 0 = infinite. Timeout uses wall-clock `Date.now` (E1 injects wall-clock jumps; strict `elapsed < limit`); advanced shares one `DateTimeout` across phases (sticky-false `isValid` after first expiration); legacy has separate line (full `maxComputationTime`) + char (0 infinite, else `min(max, 5000)`) predicates. Content change: if last result transformable by raw edits, update synchronously + `isDiffUpToDate=false` + debounce full recompute by exactly 200 ms; edits during compute recorded/normalized/applied in source order before publication. Cache `diff.document-result.process-fifo`: process-global MainActor; key = JSON `[originalURI, modifiedURI]`; context = model IDs + altVersionIds + serialized options; FIFO insertion-order eviction; maximum 11 (pre-insert `> 10` check admits the 11th — comment "max 10" corrected to 11). Identical rule: compares line count + each line's raw UTF-16 content; does NOT compare EOL bytes.
**Contract:** G4-R §architecture.diffEngine; D1-R (4 values, external/WASM unavailable no-fallback, timeout, maxFileSize no-op, 11-entry cache); §surfaceCounts.diffEngine (publicAlgorithmValues 4, fixedBaselineUnavailableAlgorithms 2, maxFileSizeComputationReads 0, processCacheMaximumEntries 11); §explicitCuts.diffImplementations (@vscode/diff JS + WASM); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C05 (diff dispositions/cache/timeout); C10 (no @vscode/diff/WASM); P10 (timeout/cache/maxFileSize cells).
**Steps:**
- [ ] Implement 4-value enum + timeout + cache + unavailable event; capture external-unavailable + T−1/T/T+1 timeout fixtures (deterministic corpus: inputs sized to approach the 5000ms `maxComputationTime` on M0/M1 at `elapsed = 4999/5000/5001` ms via E1-injected wall-clock jumps; expected = M0/M1 golden `hitTimeout`/`quitEarly=true` + source-produced approximation); commit.

## Task 7.3 — 40 standalone services + session store (S1-R)

**Dependencies:** 1.12, 5.2
**Files:** Create `Sources/MonaCode/Services/MonaStandaloneServices.swift` (40 dispositions), `Sources/MonaCode/Services/MonaSessionStateStore.swift`, `Sources/MonaCode/Services/MonaInMemoryStorageService.swift`; Test `Tests/MonaCodeTests/Services/test_StandaloneServices.swift`
**Tests:** 40 default service registrations, each with one disposition: retained-native-core 14; fixed-standalone-semantic 2 (workspace context = one synthetic `inmemory://model/` workspace; workspace trust = always true); native-adaptation 10 (label/dialog/environment/accessibility/list/keybinding/quick-input/context-view/clipboard/context-menu → AppKit); host-adaptation 2 (log → MonaLogSink; opener → H1); session-memory 1 (storage = InMemoryStorageService, 4 scopes); mixed-log-noop 1 (notification: info/warn/error/notify → log; prompt/status → no-op); baseline-noop 8 (telemetry, 2 progress, accessibility signal, logger resource, data channel, default account, rename tracker); explicit-cut 2 (IWebWorkerService, ITreeSitterLibraryService). `MonaSessionStateStore`: process-global MainActor typed store with application/profile/workspace/applicationShared namespaces; initialized empty, destroyed with process; survives editor disposal, not process. `InMemoryStorageService`: 4 logical scopes as process-memory namespaces only; `shouldFlushWhenIdle` inapplicable (no flush target — process-memory-only per S1-R; the property is absent, not false). Session-state groups: find (4 bool flags + find/replace histories insertion-ordered unique, no source eviction bound); suggest-memory (LRU 300, ratio 0.66, prefix 200, 500 ms save); suggest-widget (2 size identities + docs flag); peek (layout); quick-input (view state + zero-based flag + command MRU 50); inline-completions (snooze 300000 ms); menu (hidden commands); codelens-storage (cache2 save unreachable). Bounds 300/200/50/20.
**Contract:** G4-R §architecture.standaloneServices (40 dispositions; MonaSessionStateStore 4 namespaces; 4 dialogs; notification/progress/telemetry/signal no-op); S1-R; §surfaceCounts.standaloneServices (defaultRegistrations 40, classifiedRegistrations 40, addressableSessionKeyIdentities 22, dialogCallSites 4, shutdownFlushCallSites 0, splitButtonRegistrations 0); §explicitCuts (persistent backends, telemetry, notification/progress UI, signal audio); §acceptance.overlays.C09 (300/200/50/20 bounds).
**Produces:** —
**Exit-gate contribution:** C04 (40 services); C05 (session state); C09 (session process-only + bounds); C10 (no persistence/telemetry/UI/audio).
**Steps:**
- [ ] Implement 40 services + session store + bounded states; commit.

## Task 7.4 — 4 dialog sites (S1-R)

**Dependencies:** 7.3, 4.10
**Files:** Create `Sources/MonaCodeAppKit/Services/MonaDialogCoordinator.swift`; Test `Tests/MonaCodeAppKitTests/Services/test_Dialogs.swift`
**Tests:** 4 dialog call sites via AppKit sheets owned by the initiating editor window; each result carries dialog/editor/model/version/transaction identity and revalidates before mutation; no-window fallback returns non-mutating cancel/false branch + sanitized log event. Outcomes: unusual-line → Remove/Ignore (Remove requires generation + model/version revalidation); workspace-undo → Undo in N Files/Dismiss — BOTH buttons continue the all-files undo path after edit-stack revalidation (`window.confirm` first-button value 0 and undefined both map to `UndoChoice.All`); "Undo this File" unreachable in fixed standalone; undo-confirm → Yes/No (Yes re-enters undo; No no mutation); command-error → OK (localized command label + error detail; dismiss no side effect). No host dialog protocol added.
**Contract:** G4-R §architecture.standaloneServices (4 dialog sites use internal AppKit sheets); S1-R (4 dialog outcomes); §surfaceCounts.standaloneServices.dialogCallSites 4; §acceptance.overlays.C07 (dialogs native roles/focus); §acceptance.overlays.C05 (4 dialog outcomes).
**Produces:** —
**Exit-gate contribution:** C05 (dialog outcomes); C07 (native roles/focus).
**Steps:**
- [ ] Implement the dialog coordinator + 4 outcomes + no-window fallback; capture dialog fixtures; commit.

## Task 7.5 — Host contracts: 7 groups / 10 concrete types (H1-R/R2)

**Dependencies:** 5.7, 6.1
**Files:** Create `Sources/MonaCode/Host/MonaCodeEnvironment.swift` (complete), `Sources/MonaCode/Host/MonaLinkOpener.swift`, `Sources/MonaCode/Host/MonaCodeEditorOpener.swift`, `Sources/MonaCode/Host/MonaWorkspaceEditHost.swift`, `Sources/MonaCode/Host/MonaPreparedWorkspaceTransaction.swift`, `Sources/MonaCode/Host/MonaCommandHost.swift`, `Sources/MonaCode/Host/MonaLogSink.swift`, `Sources/MonaCode/Host/MonaMultiDiffDataSource.swift`; Test `Tests/MonaCodeTests/Host/test_HostContracts.swift`
**Tests:** 7 groups / 10 concrete types: environment→`MonaCodeEnvironment`; opener→`MonaLinkOpener`+`MonaCodeEditorOpener` (+ `registerLinkOpener`/`registerCodeEditorOpener`); workspace→`MonaWorkspaceEditHost`+`MonaPreparedWorkspaceTransaction`; command→`MonaCommandHost`; log→`MonaLogSink`; lsp-transport→`MonaMessageTransport`+`MonaLSPTransportFactory`; multidiff→`MonaMultiDiffDataSource`. `MonaCodeEnvironment.initialize(overrides:)` exactly once before first service access; later calls return `alreadyInitialized`. Opener registries: two independent last-registered-first stacks; `false` continues traversal; `true`/non-null stops; rejection → mapped operation failure (no catch, no fallback to older opener); default unhandled → NO implicit `NSWorkspace.open`/URL/file/network. `MonaLogSink` (Sendable, nonthrowing): no document text, no blocking, no control-flow authority, non-reentrant. `MonaMultiDiffDataSource` for `MonaMultiDiffEditorView`. `MonaResourceOpener` NOT a symbol.
**Contract:** G4-R §hostContractClosure (groups 7, concreteTypes 10, openerCorrection, defaultExternalOpen); H1-R, H1-R2; §surfaceCounts.nativeEmbedding (products 3, appKitViews 3, swiftUITypes 4, hostContractGroups 7, h1DefinedTypes 8, allConcreteContractTypes 10); §architecture.embedding.
**Produces:** —
**Exit-gate contribution:** C04 (opener protocols + register functions present; MonaResourceOpener absent); C09 (7 groups / 10 types).
**Steps:**
- [ ] Implement the 10 host types + registries; confirm MonaResourceOpener absent; commit.

## Task 7.6 — WorkspaceEdit 4-state machine (H1-R/R1)

**Dependencies:** 7.5, 1.9
**Files:** Create `Sources/MonaCode/Host/MonaWorkspaceEditMachine.swift`, `Sources/MonaCode/Host/MonaWorkspaceEditCapability.swift`; Test `Tests/MonaCodeTests/Host/test_WorkspaceEdit.swift`
**Tests:** 4-state machine: `abort` (protocol order, stop at first failure, earlier successes remain, `applied=false`, `failedChange`=index); `transactional` (full preflight + host prepare + all `DependencyStamp` revalidation + nonthrowing commit + root swap; enqueue entire event batch then drain; NO await/allocation/callback between commit and root swaps); `textOnlyTransactional` (pure textDocumentChanges → transactional; any create/rename/delete → entire edit uses `abort`); `undo` (protocol order; on failure reverse-attempt receipts + model inverse; `applied=false` always). Capability advertised only when prepare makes commit allocation-free with no externally reportable failure: full-resource atomic → `transactional`; all text-resource atomic → `textOnlyTransactional`; otherwise `abort`. `MonaPreparedWorkspaceTransaction.commit()` synchronous nonthrowing + callback-free; `abort()` async idempotent. 4 WorkspaceEdit failure modes (validation/version conflict, host rejection, resource failure, partial publication) handled per R1 failure-isolation table.
**Contract:** G4-R §architecture (WorkspaceEdit base); H1-R (WorkspaceEdit base); R1 (cross-model text transaction, PreparedModelCommit, failure isolation); §acceptance.overlays.C09 (4 WorkspaceEdit failure modes); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C09 (4 failure modes); R1 failure-injection gate (Phase 8).
**Steps:**
- [ ] Implement the 4-state machine + capability advertisement; capture failure-injection fixtures; commit.

## Task 7.7 — H2-R cache registry + MonaCacheManifest

**Dependencies:** 7.3, 3.6, 1.12
**Files:** Create `Sources/MonaCode/Runtime/MonaCacheRegistry.swift`, `Tools/MonaCacheManifest.swift`; Test `Tests/MonaCodeTests/Runtime/test_CacheRegistry.swift`
**Tests:** Every strong derived cache registers: stable ID + owner scope/key/max entries or bytes/eviction order/invalidation epochs/memory-pressure action/instrumentation counter. Existing hard bounds: Metal atlas ≤ 16 pages; LSP 8 KiB/64 MiB/256 MiB/128/4096; clipboard metadata 8 MiB; announcement 20,000 units; normalization LRUs 10000×2 (Phase 2); diff cache 11 (Task 7.2). Linked product cache registry and manifest IDs set-equal; an unregistered strong derived cache is a release failure. Semantic state (model text, undo/redo, decorations, markers, view state, registrations, host-owned LSP transports) is NOT cache — never evicted. Memory pressure evicts only recomputable unpinned derived caches and cancels stale unpublished proposals; never discards semantic state, a prepared commit, or an in-flight presented frame. Fixed corpus 100 cycles must plateau at each declared bound.
**Contract:** G4-R §architecture (H2 cache/failure contract); H2-R (cache bounds); §implementationOutputRules.cacheBounds; §candidateGeneratedArtifacts (MonaCacheManifest required for C09, C10, P00–P13, soak); §acceptance.overlays.C09.
**Produces:** `MonaCacheManifest.json` (present).
**Exit-gate contribution:** C09 (cache registry set-equal + bounds); C10; 24h soak (Phase 8).
**Steps:**
- [ ] Implement the cache registry + manifest producer; verify set-equality + bounds; commit.

## Task 7.8 — X1-R full source-closure manifest

**Dependencies:** 2.8, 0.3, 5.1
**Files:** Create `Tools/MonaSourceClosureScanner.swift` (module mapper + runtime-effect registry + intrinsic-profile exporter + native-style registry), `Tools/MonaSourceClosureManifest.swift`; Test `Tests/MonaCodeTests/SourceClosure/test_ClosureManifest.swift`
**Tests:** `MonaSourceClosureManifest.json` set-equal to: 956 reachable JS modules (set SHA `0dd3fb5c…`) + 38 unreachable-package exclusion rows (set SHA `1cf6ed3e…`) + 98 imported style resources (set SHA `0b63cc44…`) + 1281 source style rules + 3120 declarations + 257 style-variable names + 566 references + 84 direct global identifiers + 8221 direct global references + every retained platform-effect call site + 3099 targeted runtime visual-mutation rows (row-set SHA `b2b36a48…`). Cross-references 14 N1-owned localization tables + 3 unreachable styles. Closed-world rule: every observable row exact-retained by default; can differ only by citing an existing G4 cut/adaptation/baseline-inert/later-target; candidate CANNOT invent a cut/no-op/fallback/adaptation/later-target/discretion. Runtime dynamic import (1, `externalLinesDiffComputer.js:19`) classified as D1 fixed-baseline unavailable.
**Contract:** G4-R §architecture.sourceRuntimeStyle; X1-R (full closure); §implementationOutputRules.sourceClosure; §candidateGeneratedArtifacts (MonaSourceClosureManifest required for C02, C04, C05, C07, C09, C10, P00–P13, soak); §surfaceCounts.sourceRuntimeStyle.
**Produces:** `MonaSourceClosureManifest.json` (present).
**Exit-gate contribution:** C04 (set equality); C10 (zero unclassified reachable module/exclusion/style/rule/global/effect row; Codicon font hash `cc2472e2…` 140956 bytes); P00–P13 + 24h soak.
**Steps:**
- [ ] Implement the scanner + manifest producer; cross-validate against `monacode-x1r-source-runtime-style-manifest.json`; commit.

## Task 7.9 — Phase 7 integration + C05(diff)/C09 validation

**Dependencies:** 7.1–7.8
**Files:** Create `docs/implementation-phases/verification/phase-07-verification.md` (after verification)
**Tests:** C05 (diff) differential passes (legacy/advanced results, 4-value dispositions, 200 ms scheduling, wall-clock timeout, maxFileSize no-op, update events, 11-entry cache, external-unavailable) vs M0/M1; C09 differential passes (3 products, 7 host groups/10 types, cache registry set-equal + bounds, 4 WorkspaceEdit failure modes); both candidate manifests validate.
**Contract:** G4-R §designClosure.phaseRule; §acceptance.overlays.C05/C09.
**Produces:** `MonaSourceClosureManifest.json`, `MonaCacheManifest.json` (present).
**Exit-gate contribution:** C05(diff) pass, C09 pass; Phase 7 done when manifests validate + three adversarial rounds pass.
**Steps:**
- [ ] Run C05(diff)/C09 differential + manifest validation; commit; trigger per-phase adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-07-verification.md` (3 rounds; 1 BLOCKING + 2 MAJOR fixed):

- **Exit Gates block + Task 7.9 (B1):** add **C04 (full)** = H1-R2 openers (7.5) + S1-R 40 services (7.3) + X1 source-closure set equality (7.8) + `MonaResourceOpener` absence; and **C07 (full)** = S1 dialogs (7.4) + X1 native style goldens (7.8). Task 7.9 validation scope runs C04-full + C07-full differentials in addition to C05(diff)/C09. (Matches the corrected master-plan per-phase summary.)
- **Task 7.8 (M1):** exit-gate contribution adds **C07** (X1 covers every retained style row with native visual/geometry/focus/reduced-motion/high-contrast/accessibility goldens).
- **Task 7.3/7.7:** the "20" of 300/200/50/20 is the **CodeLens LRU 20** — a strong derived cache registered in 7.7 (not session state in 7.3); add to 7.7's hard-bounds list.
- **Task 7.7:** cite **fatal-OOM exclusion** (H2-R `fatalOOMBoundary` — fatal OOM is outside recoverable claims, never catchable); cite Phase 4/6 cache sources (clipboard 8 MiB, announcement 20000, LSP 8 KiB/64 MiB/256 MiB/128/4096).
- **Task 7.2:** add D1-R **cancellation post-computation only** (algorithm body NOT shortened by cancel token; canceled → no-changes/identical=false/quitEarly=true/no-moves) + **disposed-input fast path** (no-changes/identical=true/quitEarly=false); verify the timeout type name matches D1-R exactly.
- **Task 7.5:** state the LSP transport ownership dispositions (`ownedRestartable`/`remoteReconnectable`/`embeddedRecreatable`) boundary — host-owned here, client-lifecycle in Phase 6.
- **Task 7.6:** cite **R1 failure-isolation** for the 4 WorkspaceEdit failure modes (not §acceptance.overlays.C09).
- **C09 pass line:** add "(soak accounting verified in Phase 8)".

---

## Task 7.9b — Delivery-scope diff views + SwiftUI types + sample-host wiring

**Dependencies:** 7.1, 7.2, 7.5, 4.13b
**Files:**
- Create: `Sources/MonaCodeAppKit/Views/MonaDiffEditorView.swift` (`: NSView`; consumes D1 legacy/advanced diff on a serialized per-editor lane + `MonaMultiDiffDataSource`)
- Create: `Sources/MonaCodeAppKit/Views/MonaMultiDiffEditorView.swift` (`: NSView`; the typed native extension replacing source `any` return of `createMultiFileDiffEditor` — disposition `retained-native-replacement`)
- Create: `Sources/MonaCodeSwiftUI/MonaDiffEditor.swift` + `MonaMultiDiffEditor.swift` (`NSViewRepresentable`, lifecycle-only)
- Modify: `Sources/sample-macOS-host/main.swift` (replace the Phase-0 stub: instantiate `MonaCodeEditor` from `MonaCodeSwiftUI`, attach a `MonaCodeModel`, present in an `NSWindow`)
**Tests:** `MonaDiffEditorView`/`MonaMultiDiffEditorView` are `NSView`; `MonaMultiDiffEditorView` is the typed return of `createMultiFileDiffEditor` (not `any`); the 2 SwiftUI Representables are lifecycle-only; `sample-macOS-host` builds + launches + displays an editor with a model. Symbol-graph present in `MonaNativeDeclarationManifest`.
**Contract:** G4-R §deliveryScope.requiredViews (`MonaDiffEditorView`, `MonaMultiDiffEditorView`), requiredSwiftUITypes (`MonaDiffEditor`, `MonaMultiDiffEditor`), requiredNonProductTargets (`sample-macOS-host`); §nativeReplacements (`createMultiFileDiffEditor` → `MonaMultiDiffEditorView`); §architecture.embedding.
**Produces:** —
**Exit-gate contribution:** C09 (completes 3 AppKit views / 4 SwiftUI types); C10 (sample-macOS-host release build).
**Steps:**
- [ ] Implement the 2 diff AppKit views (serialized diff lane + multi-diff data source).
- [ ] Implement the 2 SwiftUI Representables.
- [ ] Wire `sample-macOS-host` to `MonaCodeEditor` + `MonaCodeModel`; build + launch; commit.
