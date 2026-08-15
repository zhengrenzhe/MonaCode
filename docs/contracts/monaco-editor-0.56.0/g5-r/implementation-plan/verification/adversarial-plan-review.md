# G5-R implementation-plan adversarial review

Status: round 1 complete; rounds 2 and 3 pending.

All mutations run against in-memory copies of the canonical plan. No attack rewrites a canonical contract, plan, or phase document. A detection counts only when the targeted audit emits the invariant-specific finding; incidental Markdown hash drift is excluded.

## Round 1 — graph, identity, and phase-order attacks

Initial run: 17 attacks, 16 detected, 1 missed. `R1-G04-acceptance-before-distribution` bypassed `P09-T002` and the distribution/candidate chain without an invariant-specific finding. This blocked the round.

Correction: commit `f44d0b000d57141d51bc2f87205da1d84e2a35e1` added `PLAN_ACCEPTANCE_ORDER`, a permanent negative fixture, targeted unit coverage, and full-audit composition. No product or plan scope changed.

Final command: `node /tmp/monacode-g5r-round1.mjs /Users/bytedance/Documents/ChatGPT/MonaCode`

Final result: `attacks=17`, `detected=17`, `missed=0`, `unresolvedFindings=0`.

| attackId | Input | Invariant | Command | Expected rejection | Observed result | Disposition | Changed paths | Verification commit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `R1-G01-former-cycle` | Add `P08-T001 -> P09-T099`, closing the distribution/verdict/candidate cycle | Task graph is acyclic | Round 1 runner, graph audit | `PLAN_DEPENDENCY_CYCLE` | `PLAN_DEPENDENCY_CYCLE`, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-G02-absent-dependency` | Add absent `P99-T999` to `P01-T001` | Every dependency resolves | Round 1 runner, graph audit | `PLAN_DEPENDENCY_ABSENT` | `PLAN_DEPENDENCY_ABSENT`, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-G03-duplicate-edge` | Repeat `P01-T001` on `P01-T002` | Dependency edges are unique | Round 1 runner, graph audit | `PLAN_DEPENDENCY_DUPLICATE` | `PLAN_DEPENDENCY_DUPLICATE`, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-G04-acceptance-before-distribution` | Make C01 depend only on Phase 00 and bypass `P09-T002` | Every Phase 09 acceptance task follows the qualified seven-candidate join | Round 1 runner, acceptance-order audit | `PLAN_ACCEPTANCE_ORDER` | `PLAN_ACCEPTANCE_ORDER`, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `f44d0b0` |
| `R1-G05-finalizer-before-api-closure` | Make native declaration finalization depend only on provisional Phase 05 output | Native declaration finalizer follows public API closure | Round 1 runner, candidate-order audit | `PLAN_CANDIDATE_ORDER` | `PLAN_CANDIDATE_ORDER`, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I01-retained-feature` | Remove `feature:anchorSelect` ownership row | Every retained identity is mapped | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I02-colorize` | Remove `publicPath:editor.colorize` | Each native colorize replacement has its own row | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I03-colorize-element` | Remove `publicPath:editor.colorizeElement` | Each native colorize replacement has its own row | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I04-colorize-model-line` | Remove `publicPath:editor.colorizeModelLine` | Each native colorize replacement has its own row | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I05-command` | Remove retained `command:_executeCodeActionProvider` | Every retained command is mapped | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I06-public-path` | Remove `publicPath:editor.create` | Every retained public path is mapped | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I07-keybinding` | Remove `keybinding:000:closeReferenceSearch` | Every keybinding ordinal is mapped | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I08-correctness-gate` | Remove `correctnessGate:C01` | C01–C10 all have owners | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I09-performance-workload` | Remove `performanceWorkload:P00` | P00–P13 all have owners | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I10-candidate-artifact` | Remove `candidateArtifact:MonaNativeDeclarationManifest.json` | Seven candidate identities all have owners | Round 1 runner, ownership audit | `PLAN_RETAINED_IDENTITY_UNMAPPED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I11-duplicate-implementation-owner` | Add `P05-T101` as a second `anchorSelect` implementation owner | Retained identities have exactly one implementation owner | Round 1 runner, ownership audit | `PLAN_DUPLICATE_IMPLEMENTATION_OWNER` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |
| `R1-I12-cut-production-owner` | Assign `feature:gpu` to `P05-T100` | Cut/later identities have no production or test owner | Round 1 runner, ownership audit | `PLAN_CUT_IDENTITY_OWNED` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `f44d0b0` |

Canonical revalidation after correction:

- `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/*.test.mjs` — 49 passed, 0 failed.
- `node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs` — `status=pass`, `findingCount=0`.
- Persisted `verification/plan-audit.json` remains byte-identical to fresh verifier output.

Round 1 blocking condition: cleared. `unresolvedFindings=0`.
