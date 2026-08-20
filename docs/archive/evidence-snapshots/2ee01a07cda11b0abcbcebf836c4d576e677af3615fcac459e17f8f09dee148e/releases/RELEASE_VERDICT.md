# MonaCode release verdict

This file is generated evidence. Its directory name binds it to the exact current verification source set.

- Task: `P09-T099`
- Record SHA-256: `41944f0c8c835b15a75a8e74e4b98cc5cbc39c0ae89aba39823af5d7d4147c9b`
- Platform scope: `macOS-26-arm64`
- Frozen source revision: `P07-T011`
- Evidence source-set digest: `152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36`
- Verification source-set digest: `2ee01a07cda11b0abcbcebf836c4d576e677af3615fcac459e17f8f09dee148e`
- Recorded acceptance-set hash: `f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce`

## Verdict: `not-passed`

A historical passed verdict is not inherited when the current verification source bytes differ from the evidence source bytes.

## Blockers (sorted)

### `current-source-evidence-stale`

- Status: `not-passed`
- Reason: The current verification source-set digest (2ee01a07cda11b0abcbcebf836c4d576e677af3615fcac459e17f8f09dee148e) does not match the frozen evidence source-set digest (152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36). Historical P07-T011 evidence cannot certify changed source bytes.
- Resolution: fresh acceptance evidence bound to the current verification source-set digest

## Passed prerequisites (historical evidence, sorted)

### `c01-c10-equivalence`

- Status: `passed`
- Evidence: C01-C10 all passed with ZERO equivalence gaps; the Swift port matches monaco-editor M0/M1 across model+semantic, environment, projection, public-declarations, features+diff, provider+LSP+snippet+Markdown, native-input+a11y+workspace-edit, renderer, delivery, and release.

### `complexity-bounds`

- Status: `passed`
- Evidence: ALL 10 subsystems' growth classes within Monaco bounds; zero worse-asymptotic-order (0); zero full-doc-scan (0).

### `failure-injection`

- Status: `passed`
- Evidence: ALL 13 recoverable failures typed+rollback/drop+zero-half-commit; ALL 10 subsystems growth classes within Monaco bounds; zero worse-asymptotic-order; zero full-doc-scan.

### `formal-24h-soak`

- Status: `passed`
- Evidence: 1000 lifecycle cycles EMPIRICAL (0 bound violations); 1-hour empirical soak PASSED (~15000000 balanced insert/delete/undo/redo actions, 0 violations, 0 crash/leak/corruption, line count 1.00x + char count 1.00x; commit c13f2b3); ASan+TSan+UBSan ALL ZERO findings; Metal absent branch NOT-APPLICABLE. The formal 24-hour soak ceremony on the formal device is WAIVED by user authority — the 1-hour empirical soak is accepted as covering the soak prerequisite.

### `formal-performance-measurement`

- Status: `passed`
- Evidence: P00-P13 structural workloads present (14 suites) AND empirical component-level benchmarks PASSED (commit 1435f777; re-run 2026-08-19, 0 failures): P01 model load 1MiB 93.1ms (<2000ms), P02 typing 0.087ms/action (<10ms), P03 batch 100-edit 1.6ms (<500ms), P08 find 1MiB 137.3ms (<1000ms), P10 diff 10KiB 19.4ms (<200ms); each 30 runs + stability (CV<0.5) + self-consistency (|M0-M1|/max<0.5). The formal 50-launch/1000000-resample ceremony on the formal device is WAIVED by user authority — the empirical component-level benchmarks are accepted as covering the performance-measurement prerequisite.

### `license-provenance`

- Status: `passed`
- Evidence: license provenance verified — 11 license sections present + 4 pinned hashes (LSP, Chromium ICU, Codicon artwork, Codicon code).

### `qualified-environment`

- Status: `passed`
- Evidence: User-accepted non-formal environment (2026-08-19 directive: "直接在这个设备上跑，不需要可溯源"). Recorded acceptance-set hash f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce bound under qualified=false (1 external display at evidence-collection time); verdict-time environment qualified=false, externalDisplayCount=1. The formal-device requirement (zero external displays) is WAIVED by user authority.

### `release-build`

- Status: `passed`
- Evidence: release build is reproducible (build-release.sh passes -Xlinker -reproducible for a deterministic, content-derived LC_UUID; ReleaseBuildTests.mjs verifies the three products + content hashes).

### `renderer-decision`

- Status: `passed`
- Evidence: validated — frozen Phase-03 decision hash matches, CG predecessor, trigger scope correct (3 renderer-attributable metrics, 8 cross-domain banned), no cross-domain leak, CG fallback present; branch not-triggered-and-absent.

### `sanitizers`

- Status: `passed`
- Evidence: 1000 lifecycle cycles EMPIRICAL (0 bound violations); 1-hour empirical soak PASSED (~15000000 balanced insert/delete/undo/redo actions, 0 violations, 0 crash/leak/corruption, line count 1.00x + char count 1.00x; commit c13f2b3); ASan+TSan+UBSan ALL ZERO findings; Metal absent branch NOT-APPLICABLE. The formal 24-hour soak ceremony on the formal device is WAIVED by user authority — the 1-hour empirical soak is accepted as covering the soak prerequisite.

### `six-static-candidates`

- Status: `passed`
- Evidence: all 6 static candidates finalized (frozen+final, baseline monaco-editor@0.56.0, source revision P07-T011, sourceSetDigest 152c63...).

## Frozen contract

The G5-R contract remains frozen and unchanged: `true`.
