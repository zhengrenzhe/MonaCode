# G5-R implementation-plan adversarial review

Status: all three adversarial rounds complete.

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

## Round 2 — architecture, package-graph, and product-boundary attacks

Initial run: 20 attacks, 10 detected, 10 missed. The missed attacks added a bundled language, an LSP server, a JavaScript runtime, an ICU runtime, WebView, TextKit, persistence, telemetry UI, eager Metal source, and a relaxed native/comparator threshold. This blocked the round.

Correction: commit `1720a4678c86ed84a98cad099187fba7fee17c99` added exact frozen-global-constraint checks, forbidden product-path checks, a unique conditional Metal-trigger scope check, ten permanent negative fixtures, targeted unit coverage, and full-audit composition. No product or plan scope changed.

Final command: `node /tmp/monacode-g5r-round2.mjs /Users/bytedance/Documents/ChatGPT/MonaCode`

Final result: `attacks=20`, `detected=20`, `missed=0`, `unresolvedFindings=0`.

| attackId | Input | Invariant | Command | Expected rejection | Observed result | Disposition | Changed paths | Verification commit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `R2-M-nsview` | Inject `NSView` into `P01-T001` Core operations | Core tasks contain no AppKit types | Round 2 runner, boundary audit | `PLAN_FORBIDDEN_CORE_IMPORT` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-M-cgpoint` | Inject `CGPoint` into `P01-T001` Core operations | Core tasks contain no CoreGraphics types | Round 2 runner, boundary audit | `PLAN_FORBIDDEN_CORE_IMPORT` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-M-process` | Inject `Process` into `P01-T001` Core operations | Core tasks contain no process APIs | Round 2 runner, boundary audit | `PLAN_FORBIDDEN_CORE_IMPORT` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-M-coretext` | Inject `import CoreText` into `P01-T001` | Core tasks contain no CoreText imports | Round 2 runner, boundary audit | `PLAN_FORBIDDEN_CORE_IMPORT` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-M-coregraphics` | Inject `import CoreGraphics` into `P01-T001` | Core tasks contain no CoreGraphics imports | Round 2 runner, boundary audit | `PLAN_FORBIDDEN_CORE_IMPORT` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-M-metal-import` | Inject `import Metal` into `P01-T001` | Core tasks contain no Metal imports | Round 2 runner, boundary audit | `PLAN_FORBIDDEN_CORE_IMPORT` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-P01-swiftui-core-dependency` | Remove `MonaCode` from `MonaCodeSwiftUI` dependencies | Package target graph is exact | Round 2 runner, package-graph audit | `PLAN_PACKAGE_GRAPH_MISMATCH` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-P02-target-name-drift` | Rename `benchmark-harness` to `benchmark-runner` | Package target names are exact | Round 2 runner, package-graph audit | `PLAN_PACKAGE_GRAPH_MISMATCH` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-P03-fixture-resource-drift` | Move `DifferentialFixtures` to another fixture directory | Differential fixture resource path is exact | Round 2 runner, package-graph audit | `PLAN_PACKAGE_GRAPH_MISMATCH` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-P04-sample-host-delay` | Remove `MonaCodeSwiftUI` from sample-host dependencies | Phase 01 sample host exercises both adapters | Round 2 runner, package-graph audit | `PLAN_PACKAGE_GRAPH_MISMATCH` | exact expected finding, non-zero attack verdict | detected | temporary in-memory plan only | `1720a46` |
| `R2-D01-bundled-language` | Add a bundled TypeScript language source | No bundled language implementation ships | Round 2 runner, product-path audit | `PLAN_FORBIDDEN_PRODUCT_PATH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D02-lsp-server` | Add an in-process LSP server source | MonaCode is an LSP client, not a server | Round 2 runner, product-path audit | `PLAN_FORBIDDEN_PRODUCT_PATH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D03-javascript-runtime` | Add a JavaScript runtime source | No JavaScript runtime ships | Round 2 runner, product-path audit | `PLAN_FORBIDDEN_PRODUCT_PATH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D04-icu-runtime` | Add an ICU runtime source | No ICU runtime ships | Round 2 runner, product-path audit | `PLAN_FORBIDDEN_PRODUCT_PATH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D05-webview` | Add a WebView renderer backend | Rendering remains native | Round 2 runner, product-path audit | `PLAN_FORBIDDEN_PRODUCT_PATH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D06-textkit` | Add a TextKit renderer backend | TextKit is not a parallel renderer path | Round 2 runner, product-path audit | `PLAN_FORBIDDEN_PRODUCT_PATH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D08-persistence` | Add a persistent state store | Persistent storage is outside G5-R | Round 2 runner, product-path audit | `PLAN_FORBIDDEN_PRODUCT_PATH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D09-telemetry-ui` | Add a telemetry UI panel | Telemetry UI is outside G5-R | Round 2 runner, product-path audit | `PLAN_FORBIDDEN_PRODUCT_PATH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D07-eager-metal` | Add a Phase 02 Metal warm-up source | Metal source exists only in the conditional Phase 03 trigger task | Round 2 runner, Metal-scope audit | `PLAN_METAL_TRIGGER_SCOPE` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |
| `R2-D10-relaxed-threshold` | Replace native/comparator ratio `1.00` with `1.10` | Frozen performance thresholds are exact | Round 2 runner, global-constraint audit | `PLAN_GLOBAL_CONSTRAINT_MISMATCH` | exact expected finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `1720a46` |

Canonical revalidation after correction:

- `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/*.test.mjs` — 69 passed, 0 failed.
- `node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs` — `status=pass`, `findingCount=0`.
- Persisted `verification/plan-audit.json` remains byte-identical to fresh verifier output.

Round 2 blocking condition: cleared. `unresolvedFindings=0`.

## Round 3 — evidence, environment, and executability attacks

Initial run: 16 attacks, 10 detected, 6 missed. The missed attacks reused a plan-review artifact as product evidence, inserted a forbidden qualification UUID, modified a source with no create owner, consumed an undefined interface, replaced an executable command with prose, and removed the dependency ordering an interface after its producer. This blocked the round.

The new executability audit was also run against the unmutated canonical plan. It found 131 real interface-order failures: one missing `MonaURI` predecessor on `P01-T008`, 124 missing command/feature-registry predecessor relationships across the 62 retained-feature tasks, and six missing registry relationships propagated through `P05-T190`, `P05-T200`, `P07-T003`, and `P07-T005`.

Correction: commit `5559b2a1d36faeaa0a32498b18ae2850bd996c17` added product-evidence path normalization, qualification privacy composition, file provenance, interface definition/uniqueness/order, and executable-command checks; added six permanent negative fixtures and focused tests; and added the exact missing task dependencies. The corrected canonical scan has zero undefined interfaces, duplicate interface producers, interface-order failures, duplicate file producers, file-provenance failures, and prose commands. No product scope changed.

Final command: `node /tmp/monacode-g5r-round3.mjs /Users/bytedance/Documents/ChatGPT/MonaCode`

Final result: `attacks=16`, `detected=16`, `missed=0`, `unresolvedFindings=0`.

| attackId | Input | Invariant | Command | Expected rejection | Observed result | Disposition | Changed paths | Verification commit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `R3-E01-implemented-state` | Change `planState` to `implemented` | Plan evidence never claims implementation | Round 3 runner, schema and evidence audits | `PLAN_FALSE_EVIDENCE_STATE` | target finding plus schema rejection, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-E02-review-as-product-evidence` | Use implementation-plan verification output as acceptance evidence | Plan-review output is not product evidence | Round 3 runner, evidence audit | `PLAN_FALSE_EVIDENCE_STATE` | target finding plus marker drift, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `5559b2a` |
| `R3-E03-remove-red-result` | Remove expected output from a red command | Every red command declares its exact rejection evidence | Round 3 runner, schema audit | `PLAN_SCHEMA_INVALID` | target finding plus marker drift, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-E04-remove-green-command` | Remove every green command from a task | Every task has an executable green proof | Round 3 runner, schema audit | `PLAN_SCHEMA_INVALID` | target finding plus marker drift, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-E05-forbidden-uuid-key` | Insert a forbidden UUID key and value into `qualificationEnvironment` | Qualification data contains no persistent identity | Round 3 runner, privacy audit | `PLAN_ENVIRONMENT_PRIVACY` | exact target finding, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `5559b2a` |
| `R3-E06-stale-macos-build` | Restore stale macOS build `25G72` | Qualified macOS build is exact | Round 3 runner, environment audit | `PLAN_ENVIRONMENT_MISMATCH` | exact target finding, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-E07-stale-chrome` | Restore stale Chrome `151.0.7922.109` | Comparator version is exact | Round 3 runner, environment audit | `PLAN_ENVIRONMENT_MISMATCH` | exact target finding, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-E08-external-display` | Allow one external display in formal qualification | Formal qualification requires zero external displays | Round 3 runner, environment audit | `PLAN_ENVIRONMENT_MISMATCH` | exact target finding, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-E09-remove-refresh-cell` | Remove the required 120 Hz refresh cell | The 60/120 Hz matrix is frozen | Round 3 runner, global-constraint audit | `PLAN_GLOBAL_CONSTRAINT_MISMATCH` | exact target finding, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-X01-remove-interfaces` | Remove an interface signature object | Every task declares consumed or produced interfaces | Round 3 runner, schema audit | `PLAN_SCHEMA_INVALID` | target finding plus undefined-interface and marker findings, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-X02-nonexistent-source` | Modify a nonexistent source file with no producer | Every modified file has one predecessor create owner | Round 3 runner, executability audit | `PLAN_FILE_PROVENANCE` | target finding plus marker drift, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `5559b2a` |
| `R3-X03-undefined-type` | Consume an undefined interface type | Every consumed interface has one producer | Round 3 runner, executability audit | `PLAN_INTERFACE_UNDEFINED` | target finding plus marker drift, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `5559b2a` |
| `R3-X04-broad-commit-boundary` | Add a commit path outside declared task files | Commit boundary is a subset of declared files | Round 3 runner, schema audit | `PLAN_SCHEMA_INVALID` | target finding plus marker drift, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-X05-markdown-hash-drift` | Change a task record without changing its Markdown marker | Markdown task marker equals canonical record hash | Round 3 runner, Markdown audit | `PLAN_MARKDOWN_DRIFT` | exact target finding, non-zero attack verdict | detected | temporary in-memory plan only | `5559b2a` |
| `R3-X06-prose-command` | Replace an exact command with prose | Red and green steps are executable commands | Round 3 runner, executability audit | `PLAN_COMMAND_NOT_EXECUTABLE` | target finding plus marker drift, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `5559b2a` |
| `R3-X07-interface-before-producer` | Remove the dependency ordering a consumed interface after its producer | Every consumer transitively follows its producer | Round 3 runner, executability audit | `PLAN_INTERFACE_ORDER` | target finding plus marker drift, non-zero attack verdict | detected after blocking correction | permanent fixture added; attack remains in-memory | `5559b2a` |

Canonical revalidation after correction:

- `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/*.test.mjs` — 77 passed, 0 failed.
- `node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs` — `status=pass`, `findingCount=0`, `executabilityFailures=0`.
- Persisted `verification/plan-audit.json` is byte-identical to fresh verifier output.

Round 3 blocking condition: cleared. `unresolvedFindings=0`.

## Final summary

- `rounds: 3`
- `attacks: 53`
- `detected: 53`
- `missed: 0`
- `unresolvedFindings: 0`
