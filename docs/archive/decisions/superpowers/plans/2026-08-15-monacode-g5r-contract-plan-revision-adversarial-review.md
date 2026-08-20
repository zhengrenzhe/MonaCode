# MonaCode G5-R revision execution-plan adversarial review

Status: structurally verified on 2026-08-15. This report reviews the execution plan that creates G5-R. It does not review a final G5-R product implementation plan because that artifact does not exist yet. Tasks 21-23 in the execution plan impose three additional blocking adversarial rounds on the final product plan before G5-R adoption.

## Reviewed inputs

- Approved design: `docs/superpowers/specs/2026-08-15-monacode-g5r-contract-plan-revision-design.md`
- Execution plan: `docs/superpowers/plans/2026-08-15-monacode-g5r-contract-plan-revision.md`
- Frozen parent contract: `docs/contracts/monaco-editor-0.56.0/g4-r/`
- Historical plan source: the current 24 files under `docs/implementation-phases/`

## Attack method

The review attacked factual inputs, scope containment, authority order, dependency order, hash topology, history preservation, task executability, module boundaries, conditional renderer ordering, privacy, evidence truthfulness, and commit isolation. Each finding required a concrete local-code or command observation. A disposition of `resolved` means the execution plan or approved design was edited and rechecked; it does not claim that G5-R has been produced.

## Findings and resolutions

| ID | Attack | Observed defect | Resolution | Status |
|---|---|---|---|---|
| ER-01 | Recompute current draft counts | `rg -h` printed ripgrep help and produced the false `135/135` count | Recounted with `rg --no-filename`: 99 unique task headings and 125 checkboxes; corrected design in commit `b85dcaf` | resolved |
| ER-02 | Remove external authority dependencies | Canonical plan Markdown outside G5-R made “self-contained archive” false | Moved the canonical plan beneath `g5-r/implementation-plan/`; root plan directory retains only index and history | resolved |
| ER-03 | Preserve history without dual authority | Copying the draft without removing root copies left two apparent current plans | Added 24/24 hash verification, exact removal of root duplicates, and a root authority index | resolved |
| ER-04 | Build the candidate hash graph in task order | Task 4 could not know the final plan hash, and mutual contract/plan hashes would create a cycle | Candidate-only selected hashes are schema-defined `null`; the plan references contract path/revision only; adoption record binds final contract and plan hashes | resolved |
| ER-05 | Topologically sort the execution plan itself | Numbering implied order but no explicit dependency graph existed | Added a 26-row direct-dependency DAG; every edge points to a lower task ID | resolved |
| ER-06 | Inject nested serial/UUID fields | A top-level-only key scan failed nested privacy violations and UUID values | Defined recursive key and UUID-value traversal before serialization | resolved |
| ER-07 | Put forbidden type names in Core negative-test prose | Scanning an entire task JSON falsely treated a negative test mentioning `NSView` as production leakage | Boundary audit now scans only production paths, produced interfaces, and implementation operations | resolved |
| ER-08 | Trigger Metal after static manifests are finalized | Phase 09 Metal source creation invalidated Phase 08 source, distribution, and candidate manifests | Moved renderer-owned decision and conditional Metal implementation to Phase 03; committed design correction `f7f0929`; Phase 09 is validation-only | resolved |
| ER-09 | Mutate an unindexed verifier test | A top-level archive test file sat outside the declared checksum scope | Moved it to `implementation-plan/tests/archive-verifier.test.mjs`, which the archive index covers | resolved |
| ER-10 | Add unrelated work under `g5-r/` before commit | Directory-wide `git add` commands captured files outside a task boundary | Replaced every directory-wide staging command with exact task paths | resolved |
| ER-11 | Force an audit failure during an evidence task | Dynamic repair inside audit/review tasks had no bounded file set or independent review gate | Audit and adversarial tasks now stop on any finding; a repair requires a new explicit task before the round is rerun | resolved |

## Coverage attacks

| Requirement | Execution-plan owner | Result |
|---|---|---|
| G4-R remains immutable and verifiable | Tasks 1, 2, 26 | covered |
| Current `25G76` and Chrome `.138` qualification | Task 3 | covered |
| Frozen product scope with leaf-level delta allowlist | Task 4 | covered |
| Machine plan schema and canonical task hashes | Task 5 | covered |
| Acyclic dependency graph and Markdown equality | Task 6 | covered |
| Full identity inventory and unique ownership | Task 7 | covered |
| Module, package, candidate, evidence, environment, and Metal boundaries | Task 8 | covered |
| Permanent malformed-plan fixtures | Task 9 | covered |
| Product phases 00-09 | Tasks 10-19 | covered |
| Complete machine plan audit | Task 20 | covered |
| Three blocking adversarial rounds on the final product plan | Tasks 21-23 | covered |
| Global archive verifier | Task 24 | covered |
| Immutable adoption | Task 25 | covered |
| Independent final verification and truthful handoff | Task 26 | covered |

## Structural verification result

The execution plan contains:

- 26 unique tasks;
- 26 `Files` sections;
- 26 `Interfaces` sections;
- exactly five checkbox steps per task, 130 total;
- 26 direct-dependency rows with no backward or self edge;
- no directory-wide `git add` of the G5-R archive;
- no `TBD`, `TODO`, `FIXME`, `maybe`, `probably`, `possibly`, `should`, vague “handle edge cases”, or “similar to another task” instruction; and
- no whitespace error under `git diff --check`.

## Verdict and boundary

Execution-plan unresolved findings: 0.

The execution plan is ready for task-by-task execution. The final G5-R product implementation plan remains nonexistent and therefore has no review verdict. G5-R adoption stays blocked until that plan exists, its machine audit reports zero findings, all negative fixtures are rejected, and Tasks 21-23 record `missed=0` and `unresolvedFindings=0`.
