# Phase 8 Adversarial Verification Report

Three independent rounds. **One BLOCKING** (cross-phase consistency) + two MAJOR (fixed). Cross-cutting, failure-injection, and complexity-gate logic all verified clean. Full gate/workload coverage (10 C-gates + 14 P-workloads), C10→Phase-9 dependency, release-verdict text, QEnvironmentID preflight, P-workload parameters all verified.

## BLOCKING / MAJOR (fixed)

| # | Finding | Rounds | Disposition |
|---|---------|--------|-------------|
| B1 | Task 8.8 Metal trigger metric list still carries `first-present`/`input→present`/`footprint` — the exact metrics Phase 3 Revision 2 **banned** as direct triggers (they span non-renderer compute; a large-model slow `first-present` must NOT fire Metal) — plus over-broad `frame CPU/GPU`. Cross-phase consistency failure (Phase 3 fixed, Phase 8 not propagated). | R2(B) | **Fixed**: Task 8.8 metric list replaced with the Phase-3-Rev-2 renderer-attributable sub-measurements: `layout-ready→present`, GPU frame time, renderer-surface footprint, missed presentation, renderer energy. `input→present` dropped entirely. `frame CPU/GPU` narrowed to GPU frame time. |
| M1 | Sanitizer + 24h soak (Task 8.6, deps 8.1–8.5) don't depend on Task 8.8 (Metal) — if Metal fires, sanitizers/soak run on the CG-only build, leaving Metal code uncovered. | R1 | **Fixed**: Task 8.6 depends on 8.8; when Metal is triggered, sanitizers + soak re-run on the Metal-included build. |
| M2 | Task 8.3 invokes "bootstrap" generically without naming the Phase 0 `BootstrapStatistics` (Task 0.8) or restating the Q1-R3 verdict-form rules. | R2 | **Fixed**: Task 8.3 states "use Phase 0 `BootstrapStatistics` (Task 0.8)" and restates the verdict-form rules: positive→`exp(mean log-ratio)`; near-zero continuous→`mean(N−C)`; discrete comparator=0→all N=0; negative/zero/below-res component delta→pair invalid; whole-block resampling; non-finite/non-positive rejection; `U≤0` on unrounded binary64; B=1,000,000; deterministic seed; IUT no-Bonferroni; + component-cost formula (active−empty-host-idle) + sample protocol. |

## MINOR (noted; high-value applied)

- Task 8.4 P08 add "E1 `Number::toString` + X1 binary64/decoder/StringSHA1"; P10 add "each item 1 MiU16". [applied]
- Task 8.1 C04 enumerate X1 set-equality counts + N1 2120 messages; Task 8.2 C09 enumerate S1-R 300/200/50/20 + E1 2×10000 LRUs + D1 max-11 cache. [applied]
- Task 8.1 remove MonaCacheManifest from C01–C05 list (it's required for C09/C10/P00–P13/soak). [applied]
- Task 8.7 operation-counter clause cite §acceptance.crossCutting (not §architecture). [applied]
- Tasks 8.3–8.5 add QEnvironmentID preflight step; note per-task deps are supplementary to the phase-level prereq. [applied]
- Task 8.9 sole creation of `phase-08-verification.md`; restate "refresh rate changes frame deadline only, never relaxes the relative no-regression gate". [applied]

## Outcome
Phase 8 approved. BLOCKING + MAJOR fixed. Metal remains gate-only unless the renderer-owned trigger fires (Phase 8 Task 8.8, metrics now consistent with Phase 3 Rev 2).
