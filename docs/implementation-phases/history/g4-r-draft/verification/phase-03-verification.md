# Phase 3 Adversarial Verification Report

Three independent rounds. No BLOCKING. Three MAJOR (specification-precision). Citation integrity clean — 6/7 stamp domains, FailedLineRecord, 10,000,000 saturation, metalTrigger/metalNotTriggered, frame budgets, exact/native-adapted partition all consistent with manifest + V1-R3/R4. Core Text sole authority, CG-first/Metal-conditional, one shared LineLayoutRecord, TextKit/WebGPU cut — all confirmed.

## MAJOR (fixed)

| # | Finding | Rounds | Disposition |
|---|---------|--------|-------------|
| M1 | Task 3.9 Metal trigger metrics (`first-present`/`input→present`/`footprint`) span non-renderer compute (model load, LSP, diff); guard excludes only *failures* not slow-but-correct compute → a large-model slow `first-present` could falsely fire Metal. | R1 (R2 judged clean; tightening resolves the ambiguity) | **Fixed**: Task 3.9 — each trigger metric redefined as a renderer-attributable sub-measurement with explicit start/end boundaries (layout-ready→present, GPU frame time, renderer-surface footprint) excluding model/search/LSP/diff compute; CG-only release remains valid (`metalNotTriggered`). |
| M2 | Task 3.4 conflates two failure modes: stamp-mismatch/version-gap should **drop** the stale result (retain previous accepted record), NOT install `FailedLineRecord`; only CT NULL installs same-gen `FailedLineRecord`. As written, stale results during typing render failure surfaces. | R2 | **Fixed**: Task 3.4 — stamp-mismatch → drop (previous record retained); CT NULL → same-generation `FailedLineRecord`; renderer failure → whole-generation CG switch. Three distinct paths. |
| M3 | Task 3.4 "6 stamp domains" imprecise — V1-R3 lists 7 (Surface and Frame distinct); Surface+Frame merge unjustified; no domain→field mapping. | R2 | **Fixed**: Task 3.4 — 7 stamp domains (`Projection`/`Vertical`/`ScrollDimension`/`Geometry`/`Paint`/`Surface`/`Frame`); domain→field mapping table added; Surface/Frame kept distinct per V1-R3. |

## MINOR (noted; high-value applied)

- Task 3.5 "adapters" clarified: coordinate/natural-direction adapters (V1-R3) vs wheel/trackpad event handlers (Phase 4, I3-R4). [applied]
- Prerequisite "RegExp for projection word boundaries" corrected: Phase 2 uses `wordSeparators` classifier (NOT regex `\b`); add 3.1/3.2→2.3 dependency edge; wrap-break classifier owned by 2.3. [applied]
- Task 3.1/3.2 bidi contract: 3.1 produces directionally-tagged pre-reordered runs; 3.2 forces per-run direction (no Core Text re-bidi) — preserves exact visual order with native-adapted glyph metrics. [applied]
- Task 3.8 add "no partial CTLine batch on mid-line NULL" + define normal-Unicode vs unreasonable-effort corpus boundary. [applied]
- Task 3.2 FontDescriptorKey includes fontWeight/fontVariationSettings (family/weight/feature/variation). [applied]
- Task 3.6 Metal determination: Phase 3 = not-triggered/not-implemented (`empiricalStatus.metal`); trigger evaluation is Phase 8. [applied]
- Task 3.7 note `FailedLineRecord` satisfies `LineLayoutRecord` interface (`outsideRenderedLine` geometry) for hit-test/firstRect/frameForRange on failed lines; add 3.8 dep. [applied]
- Task 3.9 partition enumerate V1-R4 exact + native-adapted items or manifest-reference. [applied]

## Outcome
Phase 3 approved. All MAJOR fixed; MINOR applied. No architecture/scope/freeze-rule issue. C03 pass + C08 CG partial honest; Metal N/A unless Phase-8 gate fires.
