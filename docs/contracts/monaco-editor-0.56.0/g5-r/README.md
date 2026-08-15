# MonaCode G5-R adopted contract and implementation plan

Status: adopted on 2026-08-15 as `G5-R-full-scope-final`.

This directory is the self-contained adopted archive for the MonaCode full-scope contract and implementation plan against `monaco-editor@0.56.0`. G5-R inherits the frozen G4-R product scope byte-for-byte and changes only qualification-environment authority and implementation-plan governance.

## Authority order

1. `adoption-record.json` selects the exact adopted contract, plan, companion, audits, and review bytes.
2. `artifacts/monacode-g5r-authoritative-manifest.json` is the normative machine contract.
3. `implementation-plan/00-master-plan.md` and the plan manifest define the complete product execution order.
4. `artifacts/global-g5r-authoritative-contract.html` is the non-normative human-readable companion.
5. The 72 copied G4-R artifacts remain immutable inherited evidence.

The inherited bytes are indexed by `artifacts/monacode-g5r-inherited-artifacts.json`. `SHA256SUMS` fixes every file below `artifacts/` and `implementation-plan/`. The contract manifest's recursive self-hash field remains `null`; the adoption record selects the exact contract hash.

## Verification

Verify both frozen revisions and the full G5-R plan:

```sh
node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs
```

G5-R adopts the design contract and structurally verified implementation plan only. Product Swift implementation remains not-started, and release acceptance remains not-passed.
