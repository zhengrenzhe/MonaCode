# MonaCode Implementation Phase Plan

This directory holds the full implementation phase plan for MonaCode, derived strictly from the frozen G4-R contract (`docs/contracts/monaco-editor-0.56.0/g4-r/`). The plan changes implementation **order** only; it does not alter feature scope, cuts, native adaptations, architecture, host contracts, correctness gates, or performance thresholds (freeze rule).

## Reading order

1. [`00-master-plan.md`](00-master-plan.md) — goal, architecture, global constraints, repository layout, phase dependency graph, and the full G4-R cross-reference matrices (42 layers, 17 artifacts, C01–C10, P00–P13, 7 candidates → phases). **Start here.**
2. Phase plans 0–9, in dependency order:
   - [`phase-00-scaffold-harness.md`](phase-00-scaffold-harness.md)
   - [`phase-01-base-model.md`](phase-01-base-model.md)
   - [`phase-02-model-semantics.md`](phase-02-model-semantics.md)
   - [`phase-03-editorcore-layout-render.md`](phase-03-editorcore-layout-render.md)
   - [`phase-04-input-ime-transfer-a11y.md`](phase-04-input-ime-transfer-a11y.md)
   - [`phase-05-commands-options-theme-l10n-features.md`](phase-05-commands-options-theme-l10n-features.md)
   - [`phase-06-provider-lsp-snippet-markdown.md`](phase-06-provider-lsp-snippet-markdown.md)
   - [`phase-07-diff-services-host-resources-sourceclosure.md`](phase-07-diff-services-host-resources-sourceclosure.md)
   - [`phase-08-correctness-performance-acceptance.md`](phase-08-correctness-performance-acceptance.md)
   - [`phase-09-distribution-license-candidates-release.md`](phase-09-distribution-license-candidates-release.md)
3. `verification/` — per-phase and whole-plan adversarial verification reports.
4. [`determinism-resolution.md`](determinism-resolution.md) — resolves every uncertain/speculative/deferred-to-implementation item found by three adversarial uncertainty-hunt rounds into deterministic, G4-R-compliant content (semantic shape pinned to G4-R; Swift native spelling = G4-R-sanctioned candidate output validated by C04/C10).

## Per-task attributes

Every committable task carries: **Dependencies** (task IDs), **Files** (create/modify paths), **Tests**, **Contract** (G4-R domain/layers/artifact/gates), **Produces** (candidate artifacts), **Exit-gate contribution**.

## Authority

The normative authority is the hash-verified G4-R manifest. If any statement in this plan conflicts with G4-R, G4-R wins. Run `node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs` to confirm contract integrity at any time.
