# Phase 8 — Correctness + Performance Acceptance

**Goal:** Run the full G4-R acceptance suite: C01–C10 correctness gates and P00–P13 performance workloads against both M0 and M1 baselines, plus cross-cutting gates (1000 lifecycle cycles, 24-hour soak, ASan/TSan/UBSan, failure injection, complexity). Implement Metal **only** if the locked renderer-owned gate fires. Stamps `QEnvironmentID.json` per run. Produces the final pass/fail evidence for every gate.

**G4-R mapping:** verification Q1-R5 (ten-gate partition; M1-R3/E1-R/X1-R/F1-R5/N1-R/MD1-R/S1-R/SN1-R/D1-R/H1-R2 overlays + 7 candidate artifacts + privacy filtering); §performanceDecision; §acceptance.

**Prerequisites:** Phases 0–7 (all product behavior + 5 of 7 candidate manifests produced). Phase 9 (distribution) runs concurrently for C10's final pass, but C10 evidence is gathered here.

**Exit Gates (this phase completes):**
- **C01–C09 pass + C10 evidence** (C10 final pass in Phase 9 after `MonaDistributionManifest`), **P00–P13 pass** (every cell × metric × {60,120}Hz × {M0,M1}), cross-cutting gates pass.
- Candidate artifacts: `QEnvironmentID.json` stamped per run; the remaining candidate manifest (`MonaDistributionManifest`) is produced in Phase 9 and C10's final pass depends on it.
- Preflight: `QEnvironmentID` clean; audit/verify-contract pass.

---

## Task 8.1 — Correctness gates C01–C05

**Dependencies:** 2.9, 5.8, 7.9
**Files:** Create `Tests/ConformanceAndFailureInjection/Correctness/C01_C05.swift`; Create `docs/implementation-phases/verification/phase-08-verification.md` (after verification)
**Tests:** C01 (model/Piece Tree: 73 decl/70 members; 256 seeds × 10K edit/EOL/undo/deco/search traces; large-model thresholds 20 Mi/300K-line/50 Mi/256 MiU16 at T−1/T/T+1; sticky grow-shrink; `largeFileOptimizations=false`). C02 (RegExp/search: 8 flags, 10 profiles, 2117 Test262, case/collation/normalize/Number::toString vs Chrome 151). C03 (projection/native geometry: Core Text property oracle; V1-R4 invariants). C04 (555 paths 434/121; 64 features; 454 commands; 379 keybindings; symbol-graph closure; `MonaResourceOpener` absent). C05 (174 options; 22+7 diff option groups; legacy/advanced; stable-ID multi-diff). Zero raw-unit diff for exact domains; Core-Text self-consistency for native-adapted.
**Contract:** G4-R §acceptance.correctnessGates C01–C05; §acceptance.overlays (C02/C04/C05); Q1-R5; §candidateGeneratedArtifacts (MonaRegExpUnicodeManifest, MonaEnvironmentManifest, MonaNativeDeclarationManifest, MonaSourceClosureManifest, MonaCacheManifest must be present).
**Produces:** —
**Exit-gate contribution:** C01–C05 pass.
**Steps:**
- [ ] Run C01–C05 differential suites; record results; commit.

## Task 8.2 — Correctness gates C06–C10

**Dependencies:** 6.9, 4.13, 7.9, 9.3
**Files:** Create `Tests/ConformanceAndFailureInjection/Correctness/C06_C10.swift`
**Tests:** C06 (30/25/5 provider surfaces; selector ordering; dynamic registration; resolve/release/cancel/dispose; framing/JSON/session/malformed matrices; 1 client + 3 cut transports; plain-text fallback). C07 (ABC + 拼音 IME; VoiceOver; copy/cut/paste/drag/drop/workspace-edit). C08 (CG CTLine goldens every scale/subpixel-phase/fallback/color-glyph; generation/rollover/stale/failure; Metal N/A or per-channel diff ≤1/255). C09 (3 products/3 views/4 wrappers/7 host groups/10 types; 4 WorkspaceEdit failure modes; 8 process-global/7 per-editor/3 initial-model states; MonaCacheManifest exact-set + bounds + plateau). C10 (3-product graph; release builds arm64 macOS 26.0+; symbol graphs; API digester; linked dylibs; resources; every artifact SHA-256; no forbidden runtime; license notices — depends on Phase 9 `MonaDistributionManifest`).
**Contract:** G4-R §acceptance.correctnessGates C06–C10; §acceptance.overlays (C06/C07/C08/C09/C10); §licensingProfile; §explicitCuts.
**Produces:** —
**Exit-gate contribution:** C06–C10 pass (C10 final pass after Phase 9 manifest).
**Steps:**
- [ ] Run C06–C09 fully; run C10 distribution scan (full after Phase 9); record; commit.

## Task 8.3 — Performance workloads P00–P05

**Dependencies:** 0.8, 3.10
**Files:** Create `Tests/BenchmarkHarness/Workloads/P00_P05.swift`
**Tests:** Each cell = baseline × workload × metric × statistic × {60,120}Hz × total/component, run against M0 and M1. P00 cold startup (1 MiU16/100K lines; 50 fresh-process/profile blocks, launch→ready, fresh process tree per launch, terminate after ready). P01 model load (1 Mi & 100 Mi; LF/CRLF; raw UTF-16 family matrix). P02 typing/undo (1 MiU16; 10K ABC actions). P03 batch edits (1/100/10K non-overlap; prepare/commit split). P04 vertical scroll (100 MiU16/1M lines; 60 & 120 Hz; ≥10K injected intervals). P05 long line (1M units; `stopRenderingLineAfter=10000` and `-1`). Paired one-sided 95% bootstrap upper bound `native/comparator ≤ 1.00`; no outlier deletion.
**Contract:** G4-R §performanceDecision (workloads P00–P05, baselines M0/M1, cells [60,120]Hz, frame budgets, ≤1.00, sample protocol); Q1-R2/R3/R4; §acceptance.overlays.P00–P13.
**Produces:** —
**Exit-gate contribution:** P00–P05 pass.
**Steps:**
- [ ] Run P00–P05; compute bootstrap verdicts; record; commit.

## Task 8.4 — Performance workloads P06–P10

**Dependencies:** 8.3, 7.9
**Files:** Create `Tests/BenchmarkHarness/Workloads/P06_P10.swift`
**Tests:** P06 wrap/resize (100K mixed-script; width 320/768/1440 cycled 10K×; fold/inlay/variable-height matrix). P07 decorations (100K model decorations; 10K visible/offscreen mixed updated per action). P08 find/replace (10 MiU16; literal, /gimu, zero-length, capture replace; match density 0/0.1/10/1000 per KiB; incl. M1-R3 compile/consumer + E1 case/normalize + SN1 transform-RegExp). P09 multicursor (1/100/10K cursors; type/paste/delete/undo; overlap merge on/off; incl. SN1 snippet insertion, 39 variables, clipboard spread, time-snapshot, original-index, injected random/UUID). P10 Diff/MultiDiff (1/10/50 MiU16; 1/10/30% changes; legacy/advanced; multi 1/10/100 items; incl. D1 timeout T−1/T/T+1, cache hit/miss, maxFileSize no-op, external-unavailable).
**Contract:** G4-R §performanceDecision; §acceptance.overlays (P08/P09/P10); Q1-R2/R3.
**Produces:** —
**Exit-gate contribution:** P06–P10 pass.
**Steps:**
- [ ] Run P06–P10; record; commit.

## Task 8.5 — Performance workloads P11–P13

**Dependencies:** 8.4, 6.9
**Files:** Create `Tests/BenchmarkHarness/Workloads/P11_P13.swift`
**Tests:** P11 provider/LSP (30 direct surfaces, 25 mappings; 0/1/10K results; cancel/stale/resolve; transport delay 0/10/100 ms; adapter overhead minus injected delay; incl. MD1-R Markdown, S1-R suggestion memory/scope switching/500 ms save/widget details/process-shared state, SN1 completion snippets, X1 native-style projection). P12 shared model (one 10 MiU16 model, 4 editors, independent wrap/fold/selection/scroll; 10K interleaved actions; commit fanout). P13 IME/AX query (ABC/拼音 marked-text traces; 10K small AX ranges; 100 full-document AX queries; VoiceOver on/off; callback latency).
**Contract:** G4-R §performanceDecision; §acceptance.overlays (P11/P12/P13); Q1-R2/R3/R4.
**Produces:** —
**Exit-gate contribution:** P11–P13 pass.
**Steps:**
- [ ] Run P11–P13; record; commit.

## Task 8.6 — Cross-cutting: lifecycle + 24-hour soak + sanitizers

**Dependencies:** 8.1–8.5
**Files:** Create `Tests/ConformanceAndFailureInjection/CrossCutting/LifecycleSoak.swift`, `Tests/ConformanceAndFailureInjection/CrossCutting/Sanitizers.swift`
**Tests:** 1000 lifecycle cycles (create/attach/detach/dispose; weak tracker returns to warm baseline). 24-hour soak (mixed P02–P13; quiescent live allocations ≤ declared cache bounds; cache counters within signed bounds). Separate ASan, TSan, UBSan full runs → 0 findings. Metal validation = 0 only when Metal exists (CG-only build = N/A). Zero-tolerance: 0 definite leaks, 0 Main Thread Checker findings, 0 data loss, 0 half-committed transactions, 0 crashes, 0 hangs.
**Contract:** G4-R §acceptance.crossCutting (1000 cycles + 24h soak; zero defects; ASan/TSan/UBSan; Metal validation); §acceptance.overlays.C09 (soak accounting).
**Produces:** —
**Exit-gate contribution:** cross-cutting gates pass.
**Steps:**
- [ ] Run lifecycle + soak + sanitizers; record; commit.

## Task 8.7 — Failure injection + complexity gates

**Dependencies:** 8.6, 7.6, 7.7
**Files:** Create `Tests/ConformanceAndFailureInjection/CrossCutting/FailureInjection.swift`, `Tests/ConformanceAndFailureInjection/CrossCutting/ComplexityGates.swift`
**Tests:** H2-R recoverable allocation checkpoints; Core Text NULL → `FailedLineRecord`; Metal resource/present failure → CG fallback; LSP malformed/oversized frame, disconnect, restart, late response, duplicate ID; provider throw/cancel/reentry/late-release; host opener/command/workspace rejection; IME reentry, folded composition, disposal during callback. Each verifies typed failure + R1 rollback/drop + model invariants. **Fatal OOM excluded** from recoverable claims (never injected as catchable Swift error). Complexity gates: Piece Tree edit/search/offset + decoration interval ops retain Monaco asymptotic upper bounds; projection/vertical prefix queries never scan full document on viewport hot path; render work scales with visible rows + changed dependencies; **operation counters** (not wall-time) prove the growth class; a worse order = immediate fail.
**Contract:** G4-R §acceptance.crossCutting (failure injection; complexity gates); H2-R (fatal OOM excluded); R1 (failure isolation); §architecture (operation counters prove Monaco asymptotic upper bounds).
**Produces:** —
**Exit-gate contribution:** failure-injection + complexity gates pass.
**Steps:**
- [ ] Run failure injection + complexity counters; record; commit.

## Task 8.8 — Conditional Metal implementation (ONLY if renderer gate fires)

**Dependencies:** 8.3–8.5
**Files:** Create `Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift` (only if triggered); Test `Tests/MonaCodeAppKitTests/Rendering/test_MetalParity.swift`
**Tests:** Implemented **only** if a **renderer-attributable sub-measurement** (`layout-ready→present`, GPU frame time, renderer-surface footprint, missed presentation, renderer energy) fails after a correct full CG implementation. The end-to-end metrics `first-present`/`input→present`/whole-process-`footprint` are **NOT** direct triggers (they span non-renderer compute — model load/LSP/diff — and a large-model slow `first-present` must NOT fire Metal); `frame CPU/GPU` is narrowed to GPU frame time. If CG passes all renderer-owned metrics, Metal stays N/A and this task is a no-op (documented "Metal not triggered"). When implemented: identical `LineLayoutRecord` + linear premultiplied RGBA (V1-R4; no sRGB qualifier); per-channel max absolute difference ≤1/255 vs CG; full Q1-R2 suite + CG/Metal parity gate; Metal device/resource failure falls back to CG at next complete generation. *(See also Revision 2 below — consistent with Phase 3 Task 3.9.)*
**Contract:** G4-R §performanceDecision.metalTrigger / metalNotTriggered; §architecture.rendering; V1-R4; §empiricalStatus.metal (`not-triggered-and-not-implemented` unless gate fires).
**Produces:** —
**Exit-gate contribution:** C08 (Metal if triggered; N/A otherwise).
**Steps:**
- [ ] Inspect renderer-owned gate verdict; if N/A, document and skip; if triggered, implement Metal + parity; commit.

## Task 8.9 — Release verdict aggregation

**Dependencies:** 8.1–8.8, 9.3
**Files:** Create `Tools/release_verdict.mjs`; Create `docs/implementation-phases/verification/phase-08-verification.md` (consolidated)
**Tests:** Aggregate C01–C10, P00–P13, cross-cutting, failure-injection, complexity into a single signed verdict. A missing artifact/permission/input source/sample/comparator/manifest entry, or any skipped/failed cell, leaves the release not-passed. `QEnvironmentID.json` stamped per run.
**Contract:** G4-R §acceptance.releaseVerdict / notPass; §empiricalStatus.releaseVerdict; Q1-R5.
**Produces:** `QEnvironmentID.json` (per-run); release verdict evidence.
**Exit-gate contribution:** release verdict (final pass depends on Phase 9 C10).
**Steps:**
- [ ] Implement verdict aggregator; run; record; commit; trigger per-phase adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-08-verification.md` (3 rounds; 1 BLOCKING + 2 MAJOR fixed):

- **Task 8.8 (B1 — cross-phase consistency):** the Metal trigger metric list is replaced with the **Phase-3-Revision-2 renderer-attributable sub-measurements**: `layout-ready→present`, GPU frame time, renderer-surface footprint, missed presentation, renderer energy. `first-present`/`input→present`/whole-process-`footprint` are **NOT** direct triggers (they span non-renderer compute — model load/LSP/diff — and a large-model slow `first-present` must NOT fire Metal); `frame CPU/GPU` narrowed to GPU frame time. This makes Phase 8 consistent with Phase 3 Revision 2 Task 3.9 M1.
- **Task 8.6 (M1):** depends on **8.8**; when Metal is triggered, ASan/TSan/UBSan full runs + 24-hour soak **re-run on the Metal-included build** (not just the CG-only build).
- **Task 8.3 (M2):** explicitly states "use Phase 0 `BootstrapStatistics` (Task 0.8)" and restates the Q1-R3 verdict-form rules: positive metric → `exp(mean block log-ratio)`; near-zero continuous (manifest-declared) → `mean(N−C)` difference estimator; discrete comparator=0 → all N=0; negative/zero/below-resolution component delta → pair invalid (not clamped); whole-balanced-block resampling; non-finite/non-positive rejection; `U = 2·θ̂ − q05 ≤ 0` on unrounded binary64; `B=1,000,000`; deterministic seed `SHA256(manifestHash || cellID || "Q1-R3")`; IUT (no Bonferroni). Plus component-cost formula (active − empty-host-idle) + sample protocol (50 cold / 30 hot / 30 resource; attempt cap 2×; no outlier deletion; six AB/BA orderings balanced; thermalState sampling).
- **Task 8.4:** P08 adds "E1 `Number::toString` + X1 binary64/decoder/StringSHA1"; P10 adds "each item 1 MiU16".
- **Task 8.1:** C04 enumerates X1 set-equality counts (956/98/1281/3120/84/8221) + N1 2120 messages; remove MonaCacheManifest from C01–C05 list (it is required for C09/C10/P00–P13/soak).
- **Task 8.2:** C09 enumerates S1-R 300/200/50/20 + E1 2×10000 normalization LRUs + D1 max-11 diff cache.
- **Task 8.7:** operation-counter clause cites **§acceptance.crossCutting** (not §architecture).
- **Tasks 8.3–8.5:** add QEnvironmentID preflight step; per-task deps noted as supplementary to the phase-level prereq.
- **Task 8.9:** sole creation of `phase-08-verification.md`; restate "refresh rate changes the frame deadline only and never relaxes the relative no-regression gate" (§equivalenceDomains.performance).
