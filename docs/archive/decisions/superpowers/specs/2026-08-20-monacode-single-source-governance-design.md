# MonaCode single-source project governance design

- **Date:** 2026-08-20
- **Status:** approved direction; implementation requires an approved execution plan
- **Selected approach:** README task ledger plus enforced repository governance
- **Product baseline:** `monaco-editor@0.56.0`
- **Current release platform:** arm64 macOS; iOS and iPadOS remain later revisions

## 1. Purpose

This change replaces conflicting progress narratives with one current progress ledger, preserves the adopted contract and its evidence chain, and makes drift a failing repository check.

The implementation creates these distinct authorities:

| Concern | Sole authority | Meaning |
| --- | --- | --- |
| Current implementation progress | Root `README.md`, inside the machine-delimited Tasks block | What is complete, active, blocked, and not started now |
| Product scope and accepted cuts | Frozen G6-R authoritative manifest and adoption record | What MonaCode must implement for the accepted macOS release |
| Contributor rules | Root `AGENTS.md` | How future agents select, implement, prove, and update work |
| Verification evidence | Source, tests, benchmark output, and source-set-bound evidence artifacts | Proof for a task state; never an independent progress claim |
| Historical decisions and audits | Frozen contracts plus `docs/archive/` | Context and provenance; never current status |

“Single source” applies per concern. Scope does not move into README, progress does not move into the frozen contract, and evidence does not set progress by itself.

## 2. Verified repository state that drives the migration

The implementation starts from these checked repository facts:

- Root `README.md` still reports the 2026-08-14 G4-R freeze and says implementation has not started.
- Root `STATUS.md` contains later implementation claims, `200/200` plan completion, a passed release narrative, and an approximately 59% equivalence-gap narrative in one mutable document.
- Root `RELEASE_VERDICT.md` is a revision-bound release artifact presented at a location that reads as current status.
- `docs/equivalence/equivalence-gap.md` predates the completed command-dispatcher and driving-layer work recorded by later source and tests.
- `docs/superpowers/specs/` and `docs/superpowers/plans/` contain decision and execution history, including completed work, but their location does not distinguish history from active progress.
- The adopted G6-R archive declares its bytes immutable. Its adoption record identifies `G6-R-execution-ready-final`, `monaco-editor@0.56.0`, and implementation status `not-started` at adoption time. That adoption-time status is historical, not current.
- `docs/implementation-phases/README.md` is an index whose SHA-256 and path are recorded by the G6-R adoption record. It points to the normative plan under the frozen G6-R archive.
- The G6-R authoritative manifest fixes 434 retained public declarations, 70 unique model members, 453 retained commands, 166 retained actions, 52 retained macOS contributions, 62 retained macOS features, 30 language-infrastructure surfaces, and 379 keybindings. It also fixes explicit cuts and later-revision mobile work.
- G6-R contains five editor-instance interface inventories: `IEditor` 40 unique members, `ICodeEditor` 130, `IStandaloneCodeEditor` 133, `IDiffEditor` 52, and `IStandaloneDiffEditor` 55. Inheritance creates overlap, so the governance checker uses canonical identities instead of summing these counts.
- Existing release tools and tests name root `RELEASE_VERDICT.md`; G6 plan-authoring code names existing plan and phase-index paths. Migration must update every live reference or preserve the referenced frozen path.

No statement in this section grants `DONE` status to a product capability. Task states are established during migration from current source, tests, and verification-source-set-bound evidence.

## 3. Authority and immutability boundaries

### 3.1 Current progress

Only the machine-delimited Tasks block in root `README.md` states current project progress. No other active Markdown or JSON file contains a parallel task list, completion percentage, “current status” table, or release-complete claim.

The block uses fixed markers:

```text
<!-- MONACODE_TASKS:BEGIN -->
...
<!-- MONACODE_TASKS:END -->
```

Text outside the block explains the product, authority boundaries, Definition of Done, and navigation. It does not duplicate task state.

### 3.2 Product scope

The frozen G6-R authority remains at:

```text
docs/contracts/monaco-editor-0.56.0/g6-r/
```

The migration does not change bytes under `docs/contracts/monaco-editor-0.56.0/{g4-r,g5-r,g6-r}/`. Scope changes require explicit user authorization and a new contract revision. README tasks reference G6-R identities; they do not redefine those identities.

### 3.3 Historical material

Historical material is retained byte-for-byte when it supplies provenance or evidence. `docs/archive/README.md` classifies each archived set by original path, bound revision or date, reason for archival, and normative status. The archive index contains no live task state.

`docs/implementation-phases/README.md` and its G4-R draft history remain at their current paths because the adopted G6-R record pins the index path and digest. The index already states that the G4-R draft is non-normative and that the G6-R plan is normative. Moving it would break the recorded provenance path.

## 4. Root README design

Root `README.md` has this fixed section order:

1. **MonaCode** — one-sentence component goal and the `monaco-editor@0.56.0` baseline.
2. **Authority** — the concern-to-authority table from section 1.
3. **Verified snapshot** — last verification date, the verification source-set digest, and the commands that produced the snapshot. This section contains facts, not a second task summary. Live branch and Git HEAD are printed by the command and are not embedded in the file, avoiding a self-referential commit hash.
4. **Tasks** — the sole current progress ledger, inside the fixed markers.
5. **Definition of Done** — the state transition rules from section 6.
6. **Build and verify** — canonical local commands.
7. **Contracts and history** — links to G6-R and `docs/archive/README.md`.

The README does not carry a manually maintained global completion percentage. The checker can print counts by state from the task rows; generated counts are not committed as another truth.

## 5. Task ledger schema

Each Markdown row has exactly these columns:

| ID | State | Deliverable | Contract coverage | Acceptance | Evidence |
| --- | --- | --- | --- | --- | --- |

### 5.1 Stable IDs

Every task ID follows `<DOMAIN>-<three digits>`. Domain prefixes are fixed:

| Prefix | Ownership |
| --- | --- |
| `MODEL` | text model, positions, ranges, edits, undo/redo, search, decorations, markers, events |
| `REGISTRY` | global model, marker, language, theme, command, keybinding, and service registries |
| `EDITOR` | editor-instance behavior and public controller surfaces |
| `COMMAND` | command dispatch, actions, menus, context keys, and keybinding execution |
| `RENDER` | projection, layout, view zones, widgets, minimap, rendering, themes, and frame performance |
| `INPUT` | keyboard, IME, selections, clipboard, drag/drop, mouse, accessibility, and native text input |
| `LANG` | language-provider infrastructure, LSP, snippets, Markdown, tokens, and plain-text fallback |
| `DIFF` | diff editor, multi-diff, algorithms, mappings, navigation, and accessibility |
| `SERVICE` | standalone services, host integration, lifecycle, caches, storage contracts, and environment adaptation |
| `SURFACE` | retained public declarations, options, native type closure, AppKit, and SwiftUI products |
| `VERIFY` | differential correctness, performance, failure injection, distribution, licensing, and release acceptance |
| `MOBILE` | accepted later-revision iOS and iPadOS adapters, touch, software keyboard, clipboard, accessibility, and device baselines |

IDs never get reused. A later authorized scope revision that removes a task records the ID in a `Retired task IDs` subsection with the authorizing contract revision; it does not assign the ID to different work. Existing G6-R cuts are read from G6-R and are not duplicated as manually maintained README data.

### 5.2 States

The only valid states are:

- `TODO`: acceptance is defined and not yet proven.
- `IN PROGRESS`: a named current change binds this task; no capability-complete claim follows from this state.
- `BLOCKED`: the row names the exact blocker and the exact condition that clears it.
- `DONE`: all conditions in section 6 pass for the same verification source-set digest.

An umbrella capability with completed and incomplete behavior is split into independently verifiable rows. The ledger never uses “partial,” percentages, or prose qualifiers as a substitute for binary rows.

### 5.3 Required cells

- **Deliverable** names one observable outcome, not a phase name or implementation activity.
- **Contract coverage** contains machine-resolvable selectors for every canonical G6-R identity owned by the task. Multiple selectors are separated by `<br>`. A task can own multiple selectors.
- **Acceptance** contains one or more exact commands followed by `⇒ <expected exit and marker or invariant>`. Multiple command clauses are separated by `<br>`.
- **Evidence** follows the state grammar below. Markdown links are required wherever the value names a repository file or evidence artifact.

Evidence-cell grammar:

```text
TODO        —
IN PROGRESS change:<change-ref><br>owner:<owner>
BLOCKED     blocker:<evidence-ref><br>unblock:<observable-condition>
DONE        digest:<64-lowercase-hex><br>source:<one-or-more-links><br>tests:<one-or-more-links><br>results:<link> sha256:<64-lowercase-hex>
```

`change-ref` is a branch, task, or pull-request reference visible to repository collaborators. `owner` is the person or agent task actively holding the change. A `DONE` result link points to digest-bound output that records every acceptance command’s exit and required marker; the following SHA-256 binds the artifact bytes. The checker rejects empty labels, nonexistent repository links, an artifact-hash mismatch, and a `DONE` digest that differs from the verified snapshot.

Evidence linked from a `DONE` row is tracked in the repository. Untracked local output, terminal scrollback, and prose recollection cannot establish `DONE`.

## 6. Definition of Done

A task is `DONE` only when all applicable conditions pass for one verification source-set digest:

1. Every owned contract identity has a production implementation or the exact accepted native adaptation fixed by G6-R.
2. The implementation is connected to the public or host execution path. Declaration-only, constructor-only, registry-only, fixture-only, and unreachable implementations fail this condition.
3. Automated behavior tests cover success, boundary, and failure paths named in the row.
4. Monaco differential probes pass for behavior with a Monaco oracle; platform-native acceptance passes for an accepted native replacement.
5. Required performance cells pass the G6-R thresholds on the qualified environment.
6. Evidence records the verification source-set digest and exact commands. An artifact bound to another digest fails this condition.
7. The governance checker, frozen-contract verifier, and relevant repository test gates pass.

Plan construction, schema validation, generated declarations, and a historical release verdict are evidence of their own deliverables only. They do not prove product behavior.

`VERIFY-RELEASE` is `DONE` only when the release verdict binds the same verification source-set digest as the README snapshot, every required correctness and performance gate passes, no required cell is skipped, and the distribution closure passes. An archived `passed` verdict cannot set this state.

The verification source set is `Package.swift` plus every tracked file under `Sources/`, `Tests/`, `Tools/`, and `Comparators/`, followed by the G6-R authoritative-manifest digest. It excludes README, AGENTS, generated evidence, archives, `.git/`, and `.build/`. `Tools/Docs/check-project-governance.mjs` sorts repository-relative paths by raw UTF-8 byte order and computes SHA-256 over `path + NUL + decimal-byte-length + NUL + bytes` for each path, followed by `g6-r-manifest + NUL + 64-hex-digest`. This definition lets implementation, tests, evidence, and README state change atomically without embedding the containing Git commit hash in its own contents.

## 7. Contract-coverage rule

README remains the progress source while the checker derives scope identities from the frozen contract artifacts.

Each canonical identity has exactly one owner task. Dependencies can reference an owner task but cannot claim duplicate coverage. The checker builds its catalogs from G6-R `surfaceCounts`, `deliveryScope`, `explicitCuts`, and the machine manifests embedded in the frozen G6-R parent artifact set. The identity catalogs include:

- all 434 retained public declarations and retained members;
- all 70 model members;
- the canonical member identities for the five editor-instance interfaces, with inherited duplicates normalized;
- all 30 language-infrastructure surfaces;
- all 453 retained commands;
- all 166 retained actions;
- all 52 retained macOS contributions;
- all 62 retained macOS features;
- all 379 keybindings;
- every retained option, native type-closure identity, service output, verification cell, and required host/product surface enumerated by G6-R and its authority artifacts;
- every later-revision mobile identity, owned by `MOBILE` tasks without treating it as current macOS release scope.

Explicit G6-R cuts remain solely in the frozen G6-R authority. The checker rejects a cut identity in active task coverage and rejects a retained identity without one owner.

Coverage selectors use a fixed grammar implemented by the checker:

```text
<catalog>:<exact-id>
<catalog>:<prefix>/*
```

Wildcards select only identities present in a frozen canonical catalog. Free-form prose, unmatched selectors, overlapping selectors, and repository file globs are invalid.

Angle-bracket tokens in the schema and path patterns are grammar metavariables whose values come from the task row, Git, or the checker’s digest algorithm. They do not represent unresolved design choices.

## 8. Initial task population

Migration populates the ledger from present code, not from old status labels:

1. Enumerate canonical contract identities and accepted cuts from G6-R authority artifacts.
2. Inventory production entry points, protocol conformances, registries, and host adapters under `Sources/`.
3. Inventory behavior, differential, failure-injection, performance, and plan-structure tests under `Tests/` and `Comparators/`.
4. Bind each candidate `DONE` row to the production path and tests, then run its acceptance commands at the migration revision.
5. Split rows wherever only a subset has implementation, integration, tests, differential proof, or performance proof.
6. Assign all remaining retained identities to `TODO`, `IN PROGRESS`, or `BLOCKED` rows with exact acceptance.
7. Run the coverage checker and reject missing or duplicate ownership.

The old equivalence findings A1, A3, and A5 are re-evaluated against current production code and tests. Completed command-dispatcher and driving-layer behavior can close only the rows their current acceptance proves. The migration does not copy the old approximately 59% figure or its pre-driver conclusion into current status.

Completed contract construction and execution-plan work is historical context linked outside the Tasks block. It does not become a product-progress row and cannot inflate task completion counts.

## 9. Root AGENTS.md design

The repository uses the standard root filename `AGENTS.md`. It applies to the whole repository. More deeply nested `AGENTS.md` files are prohibited unless the user authorizes a narrower rule set.

The file contains enforceable rules:

1. Read root README authority, Tasks, and Definition of Done before changing files.
2. Read the frozen G6-R manifest and the task’s referenced contract identities before implementation.
3. Bind every product, test, tool, or active-document change to an existing README task ID in the commit message or change record.
4. Do not implement work absent from the ledger. Add or split a task first; scope expansion and contract changes require user authorization.
5. Update implementation, tests, evidence, and README state in the same commit that changes the factual state.
6. Never infer capability completion from compilation, declaration presence, plan verification, fixture tests, or an artifact from another revision.
7. Never create `STATUS.md`, a second task list, a parallel roadmap, a mutable equivalence-status report, or a root release-status document.
8. Specs, plans, audits, and release artifacts are evidence or history. They contain an explicit non-authority classification and cannot set current progress.
9. Do not modify frozen G4-R, G5-R, or G6-R bytes. Create a new authorized contract revision for a scope change.
10. Preserve macOS current-release and mobile later-revision boundaries. A `MOBILE` task cannot block a macOS task unless G6-R explicitly defines that dependency.
11. State conclusions from current local code, executed commands, or identified evidence. When evidence is insufficient, stop and ask the user how to continue.
12. Run the governance checker, frozen-contract verifier, task-specific tests, and `git diff --check` before claiming completion.

## 10. Machine enforcement

Implementation adds:

```text
Tools/Docs/check-project-governance.mjs
Tests/PlanStructureTests/ProjectGovernanceTests.mjs
```

The checker performs these deterministic operations:

1. Locate exactly one Tasks marker pair in root README and parse one task table.
2. Validate the exact columns, ID grammar, ID uniqueness, state enum, and required cells.
3. Enforce state-specific evidence rules, recompute `DONE` result-artifact hashes, and reject “partial” or percentage states.
4. Resolve every contract-coverage selector against frozen canonical catalogs.
5. Reject missing, duplicate, unmatched, cut, or wrong-release ownership.
6. Verify all active README and AGENTS links.
7. Reject tracked root `STATUS.md` and root `RELEASE_VERDICT.md`.
8. Reject active progress ledgers outside root README. The scan excludes frozen contracts, generated evidence, vendored source, fixtures, and `docs/archive/`; those locations remain subject to path and classification checks.
9. Require `docs/archive/README.md` entries for each migrated document set and reject live-status language in the archive index.
10. Require a verification source-set digest match before a release-evidence link can support `VERIFY-RELEASE = DONE`.
11. Print task counts and uncovered identities to stdout without rewriting README.

The PlanStructure test suite covers valid parsing plus negative fixtures for duplicate IDs, invalid states, missing acceptance, false `DONE`, duplicate ownership, uncovered retained identity, active cut, unmatched selector, duplicate marker blocks, prohibited root status files, missing archive metadata, and stale release revision.

README and AGENTS define `node Tools/Docs/check-project-governance.mjs` as a mandatory repository check. The migration does not claim CI enforcement because the current repository contains no checked-in CI workflow.

## 11. Document migration

### 11.1 Target layout

```text
README.md                                      current progress authority
AGENTS.md                                      repository governance authority
docs/contracts/monaco-editor-0.56.0/           immutable scope and contract chain
docs/implementation-phases/                    pinned contract companion and frozen draft history
docs/archive/README.md                         history catalog, no current progress
docs/archive/decisions/                        completed specs, plans, and adversarial reviews
docs/archive/audits/<audit-id>/                historical point-in-time audit reports
docs/archive/status-snapshots/<git-revision>/  historical progress narratives
docs/archive/releases/<source-revision>/       historical release verdicts
artifacts/releases/<verification-source-set-digest>/ future generated release evidence
Comparators/Baselines/                         immutable external oracle inputs
```

### 11.2 Exact dispositions

- Move root `STATUS.md` byte-for-byte to `docs/archive/status-snapshots/0fd99e28b11f2eb1910be227b6f26c1aa15c8049/STATUS.md`. Merge only currently reverified facts into README task rows; the root path then ceases to exist.
- Move root `RELEASE_VERDICT.md` byte-for-byte to `docs/archive/releases/P07-T011/RELEASE_VERDICT.md`. Update release tools and tests to generate and validate digest-bound evidence under `artifacts/releases/<verification-source-set-digest>/`.
- Move `docs/equivalence/equivalence-gap.md` byte-for-byte to `docs/archive/audits/2026-08-19-monaco-api-equivalence/equivalence-gap.md`. Move its vendored official API input to `Comparators/Baselines/monaco-editor-0.56.0.editor.api.d.ts`, preserve its bytes and license provenance, and update live comparator references. Record audit revision `e52b1b7adcc9798737d63c499a447a9d739794fd`, the original and new input paths, and the superseded assumptions in the archive index without editing the archived report.
- Move completed `docs/superpowers/specs/` and `docs/superpowers/plans/` files under `docs/archive/decisions/superpowers/`, preserving the `specs/` and `plans/` subdirectories and file bytes. Update all live tool and test references. The governance design and its execution plan join that archive after implementation completes.
- Keep all files under the frozen G4-R, G5-R, and G6-R contract directories unchanged and at their current paths.
- Keep `docs/implementation-phases/` at its current path for the pinned G6-R index and byte-preserved G4-R draft history.
- Add archive metadata in `docs/archive/README.md`; do not inject banners into byte-preserved documents.
- Delete an old path only after repository-wide reference checks show that every live reference was updated and every frozen reference still resolves as designed.

Git moves preserve repository history; byte equality is checked before and after each migration group.

## 12. Verification and acceptance

The governance migration is complete only when all checks pass in the final migration worktree and pass again on its committed Git HEAD:

1. Root README contains the sole machine-valid task ledger and every task row satisfies the schema.
2. Every retained G6-R identity has exactly one task owner; every accepted cut has zero active task owners.
3. Every `DONE` row passes its declared acceptance and evidence-digest checks.
4. Root `AGENTS.md` contains all rules in section 9.
5. No tracked root `STATUS.md` or root `RELEASE_VERDICT.md` exists.
6. No active document outside README claims current progress or maintains a task list.
7. Every migrated document set appears in the archive index; links in active documents and the archive index resolve. Byte-preserved archived documents are allowed to retain original-path links, and the archive index supplies their old-to-new path map.
8. G4-R, G5-R, and G6-R verifiers pass before and after migration with unchanged frozen bytes.
9. The governance checker and all ProjectGovernance negative tests pass.
10. Existing affected release, G6 plan-authoring, and plan-structure tests pass after path updates.
11. `git diff --check` passes and `git status --short` contains no generated build output.

## 13. Non-goals

This governance change does not:

- implement or alter editor behavior;
- change the accepted G6-R feature set, cuts, performance thresholds, or platform boundary;
- claim that MonaCode has reached Monaco product equivalence;
- rewrite frozen contracts or byte-preserved historical evidence;
- create a new product roadmap outside root README;
- broaden the current release from arm64 macOS to iOS or iPadOS.

## 14. Failure behavior

Any migration conflict involving a frozen digest, unresolved canonical identity, unprovable `DONE` state, or ambiguous document disposition stops implementation. The executor reports the exact file, identity, command, and observed conflict to the user before changing the affected boundary.
