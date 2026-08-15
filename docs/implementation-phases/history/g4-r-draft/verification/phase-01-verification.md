# Phase 1 Adversarial Verification Report

Three independent rounds. No BLOCKING. Five MAJOR (all specification-precision gaps; end-state design correct). Citation integrity clean (73/70/0 model, 8+7 runtime, 3 initial-model states, 6 ReconciliationContract, 65535 buffer, 20Mi/300K/50Mi/256Mi — all verified). Scope isolation + large-model policy confirmed clean.

## MAJOR (fixed)

| # | Finding | Rounds | Disposition |
|---|---------|--------|-------------|
| M1 | DependencyStamp lists `projection`/`fold` as model fields; they are view-model concepts (Phase 3). Only `injected text` is a true model stamp field. | R1 | **Fixed**: Task 1.10 — `projection`/`fold`/`font`/`theme`/`viewport`/`scale`/`renderer-generation` all declared Phase-3 layout fields (optional/`nil` in Phase 1, comparing equal to `nil`); only `injectedText` + model identity fields populated in Phase 1. |
| M2 | Task 1.8 stubbed-member accounting incomplete — markers/word-boundary/bracket-matching/injected-text/tokenization not clearly excluded or subsumed; "70-member surface" not reconcilable to 70. | R3 | **Fixed**: Task 1.8 — explicit exclusion list: decorations (subsumes markers + injected-text observation), search (subsumes `findMatches`/word-boundary/`findMatchingBracket`/`matchBracket`), tokenization, language state; all stubbed `unsupported`; implemented + stubbed = 70. M1-R2 manifest file `model-m1r2-public-surface-closure.html` (SHA `eaaa4ed865d56b0eabc745a38af7ab4dde8598d079e6e7788d4f0b44eebf9666`) cited as the member-list authority. |
| M3 | `tooLargeForHeapOperation` gate (getValue/getLinesContent fail) implemented in Task 1.8 but computed in Task 1.11 — no cross-reference; implementer following 1.8 omits the check. | R2 | **Fixed**: Task 1.8 — `getValue`/`getLinesContent` consult a `tooLargeForHeapOperation` property declared in 1.8 (default false), computed in 1.11. |
| M4 | Large-model flag methods (`isTooLargeForTokenization`/`isTooLargeForSyncing`) are ITextModel members; membership in the 70-member surface unresolved. | R2 | **Fixed**: Task 1.8 — these are among the 70 (identity/version/lifecycle group); declared as stubs returning the Phase-1.11-computed flags (0 cuts preserved). |
| M5 | Undo/redo version rules stated as testable but `undo()`/`redo()` throw `unsupported` in Phase 1. | R2 | **Fixed**: Task 1.9 — undo/redo version rules marked "specified in Phase 1, verified in Phase 2 exit gate"; the 4 testable rules (non-empty +1, empty unchanged, EOL +1, setValue +1) are Phase-1-verified. |

## MINOR (noted; high-value applied)

- Task 1.8 dependency add 1.5 (MonaEmitter for events/lifecycle). [applied]
- Task 1.7 dependency 1.3→0.6 (Piece Tree has no URI dependency). [applied]
- Task 1.11 exit-gate add C01 large-model thresholds (not C09-only). [applied]
- Task 1.3 Foundation.URL citation: §equivalenceDomains.nativeAdapted (not §explicitCuts — Foundation.URL is not a listed cut). [applied]
- Task 1.12 enumerate 8 distinct process-global classes (separate command/keybinding/menu registries). [applied]
- Task 1.8 `applyEdits` 3 overloads = 3 edit-operation types (`IIdentifiedSingleEditOperation`/`ISingleEditOperation`/`IValidatedEditOperation`); note the Promise-returning path → MainActor async (M1-R2 actor overlay, F1-R5). [applied]
- Task 1.9 cross-model version-mismatch rule qualified "when `baseVersion` is provided (async path)". [applied]
- Task 1.8 `ITextSnapshot` is `Sendable`; `read` returns a stack-allocated `SnapshotReader` value type (mutation on reader, not snapshot). [applied]
- Task 1.9 Invalidate stage scope (Phase 1): line index / cached line starts / EOL metadata only. [applied]
- Task 1.13 preflight: run `Tools/forbidden-imports.sh`. [applied]
- "0.6" Phase-0 reference: master plan does not enumerate Phase-0 task numbers — references use capability names. [noted]

## Outcome
Phase 1 approved. All MAJOR fixed; high-value MINOR applied; remaining MINOR documented. No architecture/scope/freeze-rule issue.
