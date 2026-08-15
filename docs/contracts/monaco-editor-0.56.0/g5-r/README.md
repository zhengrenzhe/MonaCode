# MonaCode G5-R contract candidate

Status: candidate; not adopted.

This directory is the self-contained candidate archive for the MonaCode full-scope contract and implementation plan against `monaco-editor@0.56.0`. G5-R inherits the frozen G4-R product scope byte-for-byte and changes only qualification-environment authority and implementation-plan governance.

## Candidate authority order

1. `artifacts/monacode-g5r-authoritative-manifest.json` will be the normative machine contract after it exists and G5-R is adopted.
2. `implementation-plan/00-master-plan.md` and the plan manifest will define the complete product execution order after plan verification.
3. `artifacts/global-g5r-authoritative-contract.html` will be the human-readable companion.
4. The 72 copied G4-R artifacts remain immutable inherited evidence.

The inherited bytes are indexed by `artifacts/monacode-g5r-inherited-artifacts.json`. The adopted parent remains `../g4-r/` until the final G5-R adoption record exists and the default G5-R verifier passes.

## Verification

Candidate verification is added later in this revision. Until then, verify the parent directly:

```sh
node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
```

No product Swift source or product acceptance evidence exists in this candidate.
