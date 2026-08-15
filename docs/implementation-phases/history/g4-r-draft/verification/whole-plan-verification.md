# Whole-Plan Adversarial Verification Report

Three independent whole-plan rounds (fresh-context agents) examined the complete 10-phase plan against G4-R. **No BLOCKING.** All MAJOR fixed. The plan is **scope-complete**: all 42 normative layers, 17 machine artifacts, 10 correctness gates, 14 performance workloads, and 7 candidate artifacts are owned by phase tasks with pass-paths and evidence. Freeze rule intact (no scope/cut/adaptation/architecture/host/gate/threshold delta). Gate aggregation consistent end-to-end (C04/C07 full pass at Phase 7; C10 final at Phase 9).

## MAJOR (fixed)

| # | Finding | Rounds | Disposition |
|---|---------|--------|-------------|
| M1 | **Circular dependency** Phase 8 Task 8.9 ↔ Phase 9 Task 9.3 (8.9 deps `9.x`; 9.3 deps `8.9`). | R2 | **Fixed**: Task 9.3 dep `8.9`→`8.5` (QEnvironmentID stamped by 8.3–8.5); Task 8.9 dep `9.x`→`9.3`. DAG: `8.5 → 9.3 → 8.9 → 9.4`. |
| M2 | Phase 8 exit-gate header over-claimed "C01–C10 pass" (C10 final is Phase 9). | R2 | **Fixed**: header → "C01–C09 pass + C10 evidence (C10 final pass in Phase 9)". |
| M3 | Master-plan DAG showed strict Phase 8→9 but they overlap (8.2/8.9 depend on 9.x). | R2 | **Fixed**: hard-ordering rationale adds "Phase 8 and Phase 9 overlap; convergence point `8.5 → 9.3 → 8.9 → 9.4`." |
| M4 | Revision-2 corrections existed only as appendices; original task bodies still carried banned text (Metal trigger metrics in Task 3.9/8.8; exit-gate over-claims in Phase 4/5/7/8). | R2 | **Fixed in place**: Task 3.9 + Task 8.8 Metal-trigger bodies now list the renderer-attributable sub-measurements (banned `first-present`/`input→present`/`footprint` removed). Phase 4 Goal/exit → "C07 native-interaction core". Phase 5 exit → "C04 contribution". Phase 7 exit → adds C04 full + C07 full. Phase 8 exit → "C01–C09 + C10 evidence". |
| M5 | The 7 required delivery-scope symbols (3 AppKit views + 4 SwiftUI types) had no explicit creation task; `MonaCodeSwiftUI` was created empty in Phase 0 and never populated → C09/C10 would fail. | R3 | **Fixed (task additions specified below)**. |
| M6 | `whole-plan-verification.md` did not exist (this file). | R3 | **Fixed** (this file). |

## M5 task additions (delivery-scope symbols)

- **Phase 4 — Task 4.13b (new):** Create `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift` (`: NSView + NSTextInputClient`; composes `MonaTextInputClient` + `MonaAXTextArea` + the CG renderer + `MonaScrollModel`; the hot view path) and `Sources/MonaCodeSwiftUI/MonaCodeEditor.swift` (`NSViewRepresentable`, lifecycle-only, holds no model/view state) + `Sources/MonaCodeSwiftUI/MonaSwiftUIEditorController.swift` (weak MainActor handle). **Contract:** G4-R §deliveryScope.requiredViews/requiredSwiftUITypes; §architecture.embedding (AppKit owns hot view path; SwiftUI owns lifecycle only). **Exit-gate:** C09 (3 views / 4 SwiftUI types present).
- **Phase 7 — Task 7.9b (new):** Create `Sources/MonaCodeAppKit/Views/MonaDiffEditorView.swift` + `MonaMultiDiffEditorView.swift` (`: NSView`; consume D1 diff + multi-diff data source) and `Sources/MonaCodeSwiftUI/MonaDiffEditor.swift` + `MonaMultiDiffEditor.swift` (`NSViewRepresentable`); wire `Sources/sample-macOS-host/main.swift` to `MonaCodeEditor` (replacing the Phase-0 stub). **Contract:** G4-R §deliveryScope; §nativeReplacements (`createMultiFileDiffEditor` → `MonaMultiDiffEditorView`). **Exit-gate:** C09/C10.

## MINOR (noted; high-value applied)

- Master-plan C02 row: add "(X1 intrinsics at Phase 2; full-closure validation at Phase 8)" — `MonaSourceClosureManifest` (Phase 7) lists C02 in `requiredFor` for final-acceptance validation, while C02's domain pass is Phase 2. [applied to C02 row context — consistent with the candidate `requiredFor` = final-acceptance dependency]
- Phase 6 per-phase summary: add "C04/C05 overlay contribution (SN1/MD1)" for symmetry with Phase 5. [noted]
- Machine-artifact citation format: several task Contract blocks cite the layer revision but omit the `artifact=<filename>` field; the master-plan matrix maps all 17 correctly. [noted — format consistency to apply during implementation]
- DependencyStamp "model identity fields" → clarify "model identity context (not a stamp field)". [noted]
- `sample-macOS-host` editor-view wiring now tasked (Task 7.9b). [applied]

## Dimensions confirmed clean (all three rounds)

- **Architecture coherence:** 10-phase sequence implements G4-R end-to-end; all 19 `architecture` clauses, 17 `nativeReplacements`, 16 `baselineInertPaths` owned; cross-cutting splits (E1/X1/H2) clean; C04/C07/C10 gate-aggregation corrections propagated end-to-end; Metal-trigger metric ban (Phase 3↔Phase 8) consistent.
- **Artifacts:** all 17 machine artifacts consumed; all 7 candidates produced by the correct phase with validated `requiredFor` gate chains (no breaks).
- **Gate aggregation completeness:** every gate's full-pass phase has all overlay sources available (C04/C07 at Phase 7; C05 at Phase 7; C09 at Phase 7+8; C10 at Phase 9).
- **Candidate pipeline:** all 7 traced producer → required-for → validation with no break.
- **Freeze-rule adherence:** no violations — no scope/cut/adaptation/architecture/host/gate/threshold added; no silent no-op.
- **Original-requirement coverage:** 10 phases (0–9) with specified content; every task carries Dependencies/Files/Tests/Contract/Produces/Exit-gate; 30 per-phase adversarial rounds (10 reports) + 3 whole-plan rounds (this file) delivered; all docs persisted to `docs/implementation-phases/`.

## Outcome

The full implementation phase plan is **approved**. All BLOCKING/MAJOR findings across the 30 per-phase rounds and 3 whole-plan rounds are fixed. The plan is scope-complete, contract-faithful, freeze-rule-compliant, and ready for implementation. Implementation has not started; this verification validates the *plan* only.
