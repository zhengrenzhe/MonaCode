# Phase 4 Adversarial Verification Report

Three independent rounds. No BLOCKING. Three MAJOR. Citation integrity clean (379 keybindings, 18/121 menus, 24 widget contracts, 8 focus modes, 39=30+9 announcements, 20000 cap, 8 MiB, 65536, 14 pointer targets — all verified, incl. 24/8 against the A2-R manifest JSON). Composition arbitration, multi-cursor, transfer, accessibility, R1 termination all confirmed clean.

## MAJOR (fixed)

| # | Finding | Rounds | Disposition |
|---|---------|--------|-------------|
| M1 | C07 "full differential passes" over-claims — C07 binds to N1-R/MD1-R/S1-R/SN1/X1 overlays (Phases 5–7); Phase 4 verifies only the I3/I4/A1/A2 core. | R1,R2 | **Fixed**: exit gate reworded "C07 native-interaction core (input/IME/transfer/AX) passes; N1/MD1/S1/SN1/X1 overlay clauses vacuously satisfied until their phases; full C07 in Phase 7/8." Master-plan C07 row corrected. |
| M2 | `monaco-0.56.0-a2r-accessibility-manifest.json` (assigned to Phase 4) never cited in any task Contract block. | R3 | **Fixed**: Tasks 4.9–4.12 Contract blocks cite `artifact=monaco-0.56.0-a2r-accessibility-manifest.json (f8f8123c…)`. |
| M3 | Paste (4.7) + drop (4.8) write paths bypass `ModelInputBarrier` — they are model mutations lacking the composition token and must enter the barrier (finish active composition, clear marks) before R1. | R1 | **Fixed**: 4.7/4.8 add 4.4 dependency; state "paste/drop → ModelInputBarrier → R1 PreparedModelCommit with DependencyStamp/ApplyTicket revalidation" (consistent with copy/cut disabled during marked text). |

## MINOR (noted; high-value applied)

- `§explicitCuts` misattribution (RTF/RTFD, cross-editor drag-move, AXTextCompletion, NSTextView notifications) → cite owning layer (I4-R/A1-R/A1-R2). [applied]
- Task 4.12 typo `MonoCodeAppKitTests` → `MonaCodeAppKitTests`. [applied]
- Task 4.8 add 3.7 dependency (drop uses `rangeForPosition` hit-test). [applied]
- Task 4.7 name SHA-256 source for `CopyMetadataV1` (CryptoKit, allowed Apple framework). [applied]
- Task 4.11 A1-R accessibility-mode computed-option effects beyond wrappingStrategy/wrappingIndent (allowVariableFonts effective-font, disable optimized-*); defer to Phase 5 with A1-R cross-ref. [applied]
- Task 4.4 split citation (I3-R for NSNotFound/PrimaryOnly replication; I3-R3 for ModelInputBarrier). [applied]
- Task 4.1 drop spurious 3.5 dependency (key-event gateway doesn't touch scroll). [applied]

## Outcome
Phase 4 approved. All MAJOR fixed. No architecture/scope/freeze-rule issue.
