# MonaCode Single-Source Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace conflicting project-status documents with one verified README task ledger, repository-wide AGENTS rules, machine enforcement, revision-bound evidence, and byte-preserved history.

**Architecture:** The frozen G6-R plan and ownership manifest remain the scope authority. Focused Node modules derive canonical contract identities and a non-self-referential source-set digest; README alone owns mutable task states, while tracked evidence proves those states. Historical documents move byte-for-byte into a catalogued archive, and the release verdict moves from a misleading root status file to digest-bound generated evidence.

**Tech Stack:** Node.js 26.7.0 ESM, `node:test`, Swift 6.3.3/SwiftPM, Markdown, JSON, Git.

**Spec:** `../specs/2026-08-20-monacode-single-source-governance-design.md`

## Global Constraints

- Root `README.md` is the sole current-progress authority.
- Frozen G4-R, G5-R, and G6-R bytes and paths remain unchanged.
- G6-R `monaco-editor@0.56.0` remains the sole product-scope and accepted-cut authority.
- The current release remains arm64 macOS; iOS and iPadOS remain later revisions.
- Task states are exactly `TODO`, `IN PROGRESS`, `BLOCKED`, and `DONE`.
- `DONE` requires implementation, public-path integration, tests, current source-set evidence, and every applicable G6-R threshold.
- Existing historical material is moved byte-for-byte; it is not rewritten.
- No product/editor behavior changes are part of this plan.
- Every file edit uses `apply_patch`; path-only moves use `git mv`.
- Commits use author `zhengrenzhe <zhengrenzhe0416@outlook.com>` and stage only the task’s files.
- Do not push during this plan; pushing requires a separate explicit instruction.

---

## File and responsibility map

| File | Responsibility |
| --- | --- |
| `Tools/Docs/source-set.mjs` | Compute the deterministic verification source-set digest without README/evidence self-reference |
| `Tools/Docs/contract-catalog.mjs` | Load G6-R task/ownership/cut/mobile catalogs and derive stable project task IDs |
| `Tools/Docs/task-ledger.mjs` | Parse, render, and validate the one README Tasks table |
| `Tools/Docs/check-project-governance.mjs` | Run repository-level single-source, coverage, link, archive, digest, and evidence checks |
| `Tools/Docs/capture-project-evidence.mjs` | Run current gates once, bind results to the source-set digest, and render the initial task table |
| `Comparators/probes/product-integration-probe.mjs` | Revalidate known product-path gaps against current code instead of copying the stale equivalence report |
| `Tests/PlanStructureTests/ProjectGovernanceTests.mjs` | Positive and adversarial tests for digest, catalog, ledger, archive, evidence, and CLI behavior |
| `Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs` | Seeded tests proving every integration rule fails closed and current findings name exact G6 task owners |
| `README.md` | Product overview, authority boundary, verified snapshot, sole current Tasks ledger, DoD, commands, history links |
| `AGENTS.md` | Repository-wide binding rules for scope, task selection, evidence, status updates, and completion claims |
| `.gitignore` | Ignore SwiftPM `.build/` output so verification does not dirty progress state |
| `docs/archive/README.md` | Non-normative archive catalog and old-to-new path map |
| `Tools/Release/release-verdict.mjs` | Generate and validate current digest-bound verdict JSON/Markdown while preserving frozen evidence anchors |
| `Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs` | Validate archived P07-T011 verdict and current stale-source rejection behavior |
| `Tools/G6PlanAuthoring/lib/baseline.mjs` | Point the historical G6 authoring baseline to the archived, byte-identical plan |

---

### Task 1: Build deterministic source-set and G6 catalog primitives

**Files:**
- Create: `Tools/Docs/source-set.mjs`
- Create: `Tools/Docs/contract-catalog.mjs`
- Create: `Tests/PlanStructureTests/ProjectGovernanceTests.mjs`

**Interfaces:**
- Produces: `computeVerificationSourceSet(repoRoot) -> { digest, rows, g6ManifestDigest }`
- Produces: `loadContractCatalog(repoRoot) -> { planTasks, activeIdentities, cutIdentities, laterIdentities, mobileScope }`
- Produces: `deriveProjectTaskDefinitions(catalog) -> ProjectTaskDefinition[]`
- `ProjectTaskDefinition`: `{ id, domain, sourceTaskID, title, selectors, platformScope }`
- Consumes: frozen `monacode-g6r-authoritative-manifest.json` and `monacode-g6r-implementation-plan-manifest.json`

- [ ] **Step 1: Add failing digest and catalog tests**

Append tests with exact assertions:

```js
test('verification source set is deterministic and excludes mutable truth/evidence files', () => {
  const a = computeVerificationSourceSet(REPO_ROOT);
  const b = computeVerificationSourceSet(REPO_ROOT);
  assert.equal(a.digest, b.digest);
  assert.match(a.digest, /^[0-9a-f]{64}$/);
  assert.equal(a.rows.some((row) => row.path === 'Package.swift'), true);
  assert.equal(a.rows.some((row) => row.path === 'README.md'), false);
  assert.equal(a.rows.some((row) => row.path === 'AGENTS.md'), false);
  assert.equal(a.rows.some((row) => row.path.startsWith('artifacts/')), false);
  assert.equal(a.rows.some((row) => row.path.startsWith('.build/')), false);
});

test('G6 catalog closes every owned, cut, and later identity', () => {
  const catalog = loadContractCatalog(REPO_ROOT);
  assert.equal(catalog.planTasks.length, 200);
  assert.equal(catalog.ownershipRows.length, 3582);
  assert.equal(catalog.activeIdentities.length, 3349);
  assert.equal(catalog.cutIdentities.length, 231);
  assert.equal(catalog.laterIdentities.length, 2);
  assert.equal(catalog.mobileScope.length, 4);
  assert.equal(catalog.ownershipRows.filter((row) => row.implementationOwners.length > 1).length, 0);
  assert.equal(catalog.surfaceCounts.publicDeclarations.retained, 434);
  assert.equal(catalog.surfaceCounts.model.uniqueMembers, 70);
  assert.equal(catalog.surfaceCounts.commands.retained, 453);
  assert.equal(catalog.surfaceCounts.actions.retained, 166);
  assert.equal(catalog.surfaceCounts.contributions.retainedMacOS, 52);
  assert.equal(catalog.surfaceCounts.features.retainedMacOS, 62);
  assert.equal(catalog.surfaceCounts.languageInfrastructure.surfaces, 30);
  assert.equal(catalog.surfaceCounts.keybindings, 379);
});

test('project task definitions contain one governance task, 200 G6 tasks, and four mobile tasks', () => {
  const definitions = deriveProjectTaskDefinitions(loadContractCatalog(REPO_ROOT));
  assert.equal(definitions.length, 205);
  assert.equal(definitions[0].id, 'VERIFY-001');
  assert.equal(new Set(definitions.map((row) => row.id)).size, 205);
  assert.equal(definitions.every((row) => /^(MODEL|REGISTRY|EDITOR|COMMAND|RENDER|INPUT|LANG|DIFF|SERVICE|SURFACE|VERIFY|MOBILE)-\d{3}$/.test(row.id)), true);
  assert.deepEqual(definitions.filter((row) => row.domain === 'MOBILE').map((row) => row.sourceTaskID), ['MOBILE-00', 'MOBILE-01', 'MOBILE-02', 'MOBILE-03']);
});
```

- [ ] **Step 2: Run the tests and verify Red**

Run:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs
```

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `Tools/Docs/source-set.mjs` or `Tools/Docs/contract-catalog.mjs`.

- [ ] **Step 3: Implement the source-set algorithm**

Create `Tools/Docs/source-set.mjs` with these exports and byte rules:

```js
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

export const SOURCE_ROOTS = ['Package.swift', 'Sources', 'Tests', 'Tools', 'Comparators'];
export const G6_MANIFEST = 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json';

const compareUTF8 = (a, b) => Buffer.compare(Buffer.from(a, 'utf8'), Buffer.from(b, 'utf8'));
export const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

export function computeVerificationSourceSet(repoRoot) {
  const listed = execFileSync('/usr/bin/git', ['ls-files', '-z', '--', ...SOURCE_ROOTS], { cwd: repoRoot });
  const paths = listed.toString('utf8').split('\0').filter(Boolean).sort(compareUTF8);
  const hash = createHash('sha256');
  const rows = paths.map((path) => {
    const bytes = readFileSync(resolve(repoRoot, path));
    hash.update(path).update('\0').update(String(bytes.length)).update('\0').update(bytes);
    return { path, bytes: bytes.length, sha256: sha256(bytes) };
  });
  const g6Bytes = readFileSync(resolve(repoRoot, G6_MANIFEST));
  const g6ManifestDigest = sha256(g6Bytes);
  hash.update('g6-r-manifest').update('\0').update(g6ManifestDigest);
  return { digest: hash.digest('hex'), rows, g6ManifestDigest };
}
```

- [ ] **Step 4: Implement the contract catalog and stable ID derivation**

`contract-catalog.mjs` must:

1. Parse the frozen G6 plan manifest.
2. Treat ownership rows with one implementation owner as active.
3. Treat zero-owner, non-`later-ipados` rows as cuts.
4. Treat `later-ipados` rows plus four `deliveryScope.laterRevisions` strings as mobile.
5. Create canonical identities `plan:<Pxx-Txxx>/self`, `plan:<Pxx-Txxx>/<kind>:<id>`, `mobile:<index>`, `mobile:ownership/<kind>:<id>`, and `governance:single-source`.
6. Map every P00–P09 task to exactly one domain; throw `GOVERNANCE_UNMAPPED_PLAN_TASK <id>` when no rule matches.
7. Sort source task IDs and assign three-digit ordinals per domain. Reserve `VERIFY-001` for `governance:single-source`.

Use exact phase rules and these Phase 05 feature sets:

```js
const FEATURE_DOMAINS = {
  INPUT: new Set(['P05-T103','P05-T111','P05-T114','P05-T116','P05-T133','P05-T139','P05-T155']),
  LANG: new Set(['P05-T104','P05-T106','P05-T115','P05-T119','P05-T121','P05-T124','P05-T125','P05-T126','P05-T127','P05-T128','P05-T135','P05-T140','P05-T146','P05-T147','P05-T149','P05-T150','P05-T151','P05-T153','P05-T156']),
  RENDER: new Set(['P05-T107','P05-T108','P05-T118','P05-T120','P05-T129','P05-T132','P05-T136','P05-T141','P05-T148','P05-T152','P05-T154','P05-T157','P05-T159']),
  DIFF: new Set(['P05-T112','P05-T113']),
  COMMAND: new Set(['P05-T100','P05-T102','P05-T109','P05-T117','P05-T123','P05-T130','P05-T131','P05-T134','P05-T137','P05-T138','P05-T145','P05-T158','P05-T160','P05-T161']),
};
```

All remaining P05-T100…P05-T161 tasks map to `EDITOR`. Phase rules are:

```text
P00: T001/T004 SURFACE; T005-T007 SERVICE; remaining VERIFY
P01: T001-T011 MODEL; T012 SERVICE; T013 VERIFY
P02: T001-T008 MODEL; T009 VERIFY
P03: all RENDER
P04: T001-T013 INPUT; T014-T015 EDITOR; T016 VERIFY
P05: T001/T190 SURFACE; T002-T004 COMMAND; T005-T007 REGISTRY;
     T008/T013 LANG; T009-T011 RENDER; T012 EDITOR; T100-T161 by FEATURE_DOMAINS;
     T200 VERIFY
P06: T009 SERVICE; remaining LANG
P07: T001/T002/T009 DIFF; T003-T008 SERVICE; T010 VERIFY; T011 SURFACE
P08/P09: all VERIFY
```

- [ ] **Step 5: Run Task 1 tests and frozen verifier**

Run:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
git diff --check
```

Expected: tests pass; verifier prints `adopted=true ... present=232 ... unresolvedFindings=0`; diff check is silent.

- [ ] **Step 6: Commit Task 1**

```bash
git add Tools/Docs/source-set.mjs Tools/Docs/contract-catalog.mjs Tests/PlanStructureTests/ProjectGovernanceTests.mjs
git commit -m "tools(VERIFY-001): add governance source and scope primitives"
```

---

### Task 2: Enforce the README ledger and single-source repository rules

**Files:**
- Create: `Tools/Docs/task-ledger.mjs`
- Create: `Tools/Docs/check-project-governance.mjs`
- Modify: `Tests/PlanStructureTests/ProjectGovernanceTests.mjs`

**Interfaces:**
- Consumes: `computeVerificationSourceSet`, `loadContractCatalog`, `deriveProjectTaskDefinitions`
- Produces: `parseTaskLedger(markdown) -> TaskRow[]`
- Produces: `validateTaskLedger({ markdown, definitions, catalog, repoRoot }) -> Finding[]`
- Produces: `validateEvidence({ state, evidence }) -> Finding[]`
- Produces: `validateCoverage({ rows, catalog }) -> Finding[]`
- Produces: `validateDoneEvidence({ row, currentDigest, repoRoot, trackedPaths }) -> Finding[]`
- Produces: `scanActiveProgressSources({ files, exclusions }) -> Finding[]`
- Produces: `checkProjectGovernance(repoRoot) -> { digest, taskCounts, coveredIdentities, findings }`
- CLI output: `PROJECT_GOVERNANCE tasks=205 done=<n> inProgress=<n> blocked=<n> todo=<n> identities=3556 findings=0 digest=<64hex>`

- [ ] **Step 1: Add failing parser, coverage, evidence, archive, and duplicate-source tests**

Add tests for:

```js
const ids = (findings) => findings.map((row) => row.id).sort();
const seedCoverageFailureFixture = () => ({
  rows: [
    { id: 'VERIFY-001', contractCoverage: 'governance:single-source<br>cut:editor.createWebWorker<br>plan:P00-T001/*' },
    { id: 'SURFACE-001', contractCoverage: 'plan:P00-T001/*<br>plan:missing/*' },
  ],
  catalog: {
    active: new Set(['governance:single-source', 'plan:P00-T001/self', 'plan:P00-T002/self']),
    cuts: new Set(['cut:editor.createWebWorker']),
  },
});
const seedDoneFailureFixture = () => ({
  row: {
    state: 'DONE',
    evidence: 'digest:' + '0'.repeat(64) + '<br>source:[missing](Sources/missing.swift)<br>tests:[missing](Tests/missing.swift)<br>results:[result](artifacts/result.json) sha256:' + '1'.repeat(64),
  },
  currentDigest: '2'.repeat(64),
  repoRoot: '/tmp/nonexistent-governance-fixture',
  trackedPaths: new Set(),
});
const seedRepositoryFailureFixture = () => ({
  files: new Map([
    ['STATUS.md', '# Current status'],
    ['RELEASE_VERDICT.md', '# Verdict'],
    ['docs/second.md', '<!-- MONACODE_TASKS:BEGIN -->'],
    ['docs/archive/README.md', '# Current status'],
  ]),
  exclusions: new Set(),
});
const validLedger = `<!-- MONACODE_TASKS:BEGIN -->
| ID | State | Deliverable | Contract coverage | Acceptance | Evidence |
| --- | --- | --- | --- | --- | --- |
| VERIFY-001 | TODO | Single-source governance | governance:single-source | \`node Tools/Docs/check-project-governance.mjs\` ⇒ exit 0 and findings=0 | — |
<!-- MONACODE_TASKS:END -->`;

test('parser accepts exactly one marker pair and one six-column table', () => {
  const parsed = parseTaskLedger(validLedger);
  assert.deepEqual(ids(parsed.findings), []);
  assert.equal(parsed.rows.length, 1);
  assert.equal(parsed.rows[0].id, 'VERIFY-001');
});

test('parser rejects duplicate task IDs and invalid state text', () => {
  const duplicate = validLedger.replace('<!-- MONACODE_TASKS:END -->', '| VERIFY-001 | PARTIAL | duplicate | governance:single-source | x ⇒ exit 0 | — |\n<!-- MONACODE_TASKS:END -->');
  assert.deepEqual(ids(parseTaskLedger(duplicate).findings), ['GOVERNANCE_STATE_INVALID', 'GOVERNANCE_TASK_ID_DUPLICATE']);
});

test('state-specific evidence grammar fails closed', () => {
  assert.deepEqual(ids(validateEvidence({ state: 'TODO', evidence: 'remembered pass' })), ['GOVERNANCE_TODO_EVIDENCE']);
  assert.deepEqual(ids(validateEvidence({ state: 'IN PROGRESS', evidence: 'change:main' })), ['GOVERNANCE_IN_PROGRESS_OWNER']);
  assert.deepEqual(ids(validateEvidence({ state: 'BLOCKED', evidence: 'blocker:artifact.json' })), ['GOVERNANCE_BLOCKED_UNBLOCK']);
});

test('coverage rejects missing, cut, unmatched, and duplicate ownership', () => {
  const findings = validateCoverage(seedCoverageFailureFixture());
  assert.deepEqual(ids(findings), ['GOVERNANCE_COVERAGE_DUPLICATE', 'GOVERNANCE_COVERAGE_MISSING', 'GOVERNANCE_CUT_ACTIVE', 'GOVERNANCE_SELECTOR_UNMATCHED']);
});

test('DONE rejects stale digest, missing links, and result SHA mismatch', () => {
  const findings = validateDoneEvidence(seedDoneFailureFixture());
  assert.deepEqual(ids(findings), ['GOVERNANCE_DONE_DIGEST_STALE', 'GOVERNANCE_DONE_LINK_MISSING', 'GOVERNANCE_DONE_RESULT_HASH']);
});

test('repository scan rejects prohibited roots, duplicate ledgers, and archive status claims', () => {
  const findings = scanActiveProgressSources(seedRepositoryFailureFixture());
  assert.deepEqual(ids(findings), ['GOVERNANCE_ARCHIVE_STATUS', 'GOVERNANCE_DUPLICATE_LEDGER', 'GOVERNANCE_ROOT_RELEASE_VERDICT', 'GOVERNANCE_ROOT_STATUS']);
});
```

- [ ] **Step 2: Run tests and verify Red**

Expected: exit 1 with missing `task-ledger.mjs`.

- [ ] **Step 3: Implement strict table parsing and evidence grammar**

Use these constants and output structure:

```js
export const TASKS_BEGIN = '<!-- MONACODE_TASKS:BEGIN -->';
export const TASKS_END = '<!-- MONACODE_TASKS:END -->';
export const TASK_COLUMNS = ['ID', 'State', 'Deliverable', 'Contract coverage', 'Acceptance', 'Evidence'];
export const STATES = new Set(['TODO', 'IN PROGRESS', 'BLOCKED', 'DONE']);

export function parseTaskLedger(markdown) {
  const findings = [];
  const beginCount = markdown.split(TASKS_BEGIN).length - 1;
  const endCount = markdown.split(TASKS_END).length - 1;
  if (beginCount !== 1 || endCount !== 1) {
    findings.push({ id: 'GOVERNANCE_MARKERS', message: `begin=${beginCount} end=${endCount}` });
    return { rows: [], findings };
  }
  const block = markdown.slice(markdown.indexOf(TASKS_BEGIN) + TASKS_BEGIN.length, markdown.indexOf(TASKS_END));
  const lines = block.split('\n').map((line) => line.trim()).filter((line) => line.startsWith('|'));
  const cells = (line) => line.slice(1, -1).split('|').map((cell) => cell.trim());
  if (lines.length < 2 || JSON.stringify(cells(lines[0])) !== JSON.stringify(TASK_COLUMNS)) {
    findings.push({ id: 'GOVERNANCE_COLUMNS', message: 'task table header differs from the six-column schema' });
    return { rows: [], findings };
  }
  const rows = lines.slice(2).map((line) => {
    const [id, state, deliverable, contractCoverage, acceptance, evidence] = cells(line);
    return { id, state, deliverable, contractCoverage, acceptance, evidence };
  });
  return { rows, findings };
}
```

Evidence validation uses the exact grammar from the approved spec. Coverage cells split only on `<br>`. Selector resolution accepts only `<catalog>:<exact-id>` and `<catalog>:<prefix>/*`; it rejects file globs and overlapping task ownership.

- [ ] **Step 4: Implement the repository checker CLI**

The CLI must:

1. Parse root README.
2. Validate exactly 205 canonical tasks.
3. Cover 3556 active identities exactly once.
4. Reject the 231 cut identities in active selectors.
5. Validate active README/AGENTS/archive-index links.
6. Reject tracked root `STATUS.md` and `RELEASE_VERDICT.md`.
7. Scan active docs for a second marker block, task-state table, mutable equivalence report, or current-status heading.
8. Exclude frozen contracts, `docs/implementation-phases/`, `docs/archive/`, vendored comparator inputs, generated artifacts, and fixtures from progress-source scanning.
9. Recompute every `DONE` result artifact SHA-256.
10. Exit 1 with sorted JSON findings or exit 0 with the exact summary line.

- [ ] **Step 5: Run focused tests**

Run:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs
git diff --check
```

Expected: all tests pass. Do not run the live CLI yet; the existing repository still contains the files it is designed to migrate.

- [ ] **Step 6: Commit Task 2**

```bash
git add Tools/Docs/task-ledger.mjs Tools/Docs/check-project-governance.mjs Tests/PlanStructureTests/ProjectGovernanceTests.mjs
git commit -m "tools(VERIFY-001): enforce the README task ledger"
```

---

### Task 3: Move release status to digest-bound evidence

**Files:**
- Modify: `Tools/Release/release-verdict.mjs`
- Modify: `Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs`
- Move: `RELEASE_VERDICT.md` -> `docs/archive/releases/P07-T011/RELEASE_VERDICT.md`
- Create at execution time: `artifacts/releases/<verification-source-set-digest>/release-verdict.json`
- Create at execution time: `artifacts/releases/<verification-source-set-digest>/RELEASE_VERDICT.md`

**Interfaces:**
- Consumes: `computeVerificationSourceSet(REPO_ROOT)`
- Produces: `releaseEvidenceDirectory(digest) -> absolute path`
- Produces: `renderVerdictDocument(verdict) -> Markdown`
- Produces: `writeVerdictEvidence(verdict) -> { jsonPath, markdownPath }`
- `aggregateVerdict()` retains frozen evidence fields and adds `verificationSourceSetDigest`, `evidenceSourceSetDigest`, and blocker `current-source-evidence-stale` when they differ.

- [ ] **Step 1: Change tests to require the archive and reject a false current pass**

Replace root-document assertions with:

```js
const ARCHIVED_VERDICT = resolve(REPO_ROOT, 'docs/archive/releases/P07-T011/RELEASE_VERDICT.md');

test('the historical P07-T011 verdict is byte-preserved', () => {
  assert.equal(sha256(readFileSync(ARCHIVED_VERDICT)), 'e760ffb971149bbb3afb70c7e6d99aadf5499b25b8202085062584af3037d339');
});

test('current source cannot inherit the frozen passed verdict', () => {
  const verdict = aggregateVerdict();
  assert.notEqual(verdict.verificationSourceSetDigest, verdict.evidenceSourceSetDigest);
  assert.equal(verdict.verdict, 'not-passed');
  assert.equal(verdict.blockers.some((row) => row.id === 'current-source-evidence-stale'), true);
});
```

- [ ] **Step 2: Run FinalReleaseVerdict tests and verify Red**

Expected: exit 1 because the archived path and current-source blocker do not exist.

- [ ] **Step 3: Move the old verdict byte-for-byte**

Use `git mv`, then verify:

```bash
shasum -a 256 docs/archive/releases/P07-T011/RELEASE_VERDICT.md
```

Expected SHA-256: `e760ffb971149bbb3afb70c7e6d99aadf5499b25b8202085062584af3037d339`.

- [ ] **Step 4: Implement current digest rejection and evidence writing**

Add:

```js
import { mkdirSync, writeFileSync } from 'node:fs';
import { computeVerificationSourceSet } from '../Docs/source-set.mjs';

export function releaseEvidenceDirectory(digest) {
  return join(REPO_ROOT, 'artifacts', 'releases', digest);
}

export function writeVerdictEvidence(verdict) {
  const dir = releaseEvidenceDirectory(verdict.verificationSourceSetDigest);
  mkdirSync(dir, { recursive: true });
  const jsonPath = join(dir, 'release-verdict.json');
  const markdownPath = join(dir, 'RELEASE_VERDICT.md');
  writeFileSync(jsonPath, JSON.stringify(verdict, null, 2) + '\n');
  writeFileSync(markdownPath, renderVerdictDocument(verdict));
  return { jsonPath, markdownPath };
}
```

`aggregateVerdict()` must preserve the frozen P07-T011 digest as `evidenceSourceSetDigest`, compute `verificationSourceSetDigest`, append a sorted blocker when unequal, and derive the final verdict after appending the blocker. `--write` writes both files; default invocation prints JSON without mutating the worktree.

- [ ] **Step 5: Run release tests and generate current evidence**

Run:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Release/release-verdict.mjs --write
```

Expected: tests pass; generated verdict is `not-passed`; blocker includes `current-source-evidence-stale`.

- [ ] **Step 6: Commit Task 3**

Stage the tool, test, archive move, and the exact generated digest directory printed by Step 5. Confirm the staged paths before committing:

```bash
git add Tools/Release/release-verdict.mjs Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs docs/archive/releases/P07-T011/RELEASE_VERDICT.md artifacts/releases
git diff --cached --name-status
git commit -m "verify(VERIFY-001): bind release verdicts to current source"
```

Expected staged paths are limited to the two modified files, the root-to-archive verdict rename, and one generated `artifacts/releases/<digest>/` directory.

---

### Task 4: Archive historical status, audit, decisions, and comparator input

**Files:**
- Move: `STATUS.md` -> `docs/archive/status-snapshots/0fd99e28b11f2eb1910be227b6f26c1aa15c8049/STATUS.md`
- Move: `docs/equivalence/equivalence-gap.md` -> `docs/archive/audits/2026-08-19-monaco-api-equivalence/equivalence-gap.md`
- Move: `docs/equivalence/monaco-editor-0.56.0.editor.api.d.ts` -> `Comparators/Baselines/monaco-editor-0.56.0.editor.api.d.ts`
- Move: the five pre-governance files under `docs/superpowers/specs/` -> `docs/archive/decisions/superpowers/specs/`
- Move: the five pre-governance files under `docs/superpowers/plans/` -> `docs/archive/decisions/superpowers/plans/`
- Create: `docs/archive/README.md`
- Modify: `Tools/G6PlanAuthoring/lib/baseline.mjs`
- Modify: live references discovered by the exact `rg` command below

**Interfaces:**
- Archive index records `{ originalPath, archivedPath, sha256, boundRevision, classification }` for every moved set.
- `Tools/G6PlanAuthoring/lib/baseline.mjs` reads archived G6 readiness plan bytes from `docs/archive/decisions/superpowers/plans/2026-08-15-monacode-g6r-execution-readiness.md`.

- [ ] **Step 1: Record pre-move hashes and live references**

Run:

```bash
shasum -a 256 STATUS.md docs/archive/releases/P07-T011/RELEASE_VERDICT.md docs/equivalence/equivalence-gap.md docs/equivalence/monaco-editor-0.56.0.editor.api.d.ts
rg -n "STATUS\.md|RELEASE_VERDICT\.md|docs/equivalence|docs/superpowers" --glob '!docs/contracts/**' --glob '!.build/**' .
```

The first command uses the release archive path after Task 3. Required preserved hashes:

```text
STATUS.md                                                    cc15502000089227f099eeb6b77e9d87ca57e453f19e2f5f7ef1507a31de5b05
archived P07-T011 RELEASE_VERDICT.md                          e760ffb971149bbb3afb70c7e6d99aadf5499b25b8202085062584af3037d339
equivalence-gap.md                                           5a5eb1b5209d38b1a524f5a3c4a271bec45fa855d184482889757660807bfdd3
monaco-editor-0.56.0.editor.api.d.ts                          72d6fbbfc8a719ae58a8a24da8c34324bf60a2b1bf47b0692979711a9f55bf94
```

- [ ] **Step 2: Move every historical set with `git mv`**

Preserve the `specs/` and `plans/` pairing under `docs/archive/decisions/superpowers/`. Move these exact pre-governance files and do not edit their bytes:

```text
specs/2026-08-14-monacode-g4r-design.md
specs/2026-08-15-monacode-g5r-contract-plan-revision-design.md
specs/2026-08-15-monacode-g6r-execution-readiness-design.md
specs/2026-08-19-monacode-command-dispatcher-design.md
specs/2026-08-20-monacode-driving-layer-design.md
plans/2026-08-15-monacode-g5r-contract-plan-revision-adversarial-review.md
plans/2026-08-15-monacode-g5r-contract-plan-revision.md
plans/2026-08-15-monacode-g6r-execution-readiness.md
plans/2026-08-19-monacode-command-dispatcher.md
plans/2026-08-20-monacode-driving-layer.md
```

Leave the current single-source governance spec and plan in `docs/superpowers/` until Task 7.

- [ ] **Step 3: Create the archive index**

`docs/archive/README.md` contains:

```markdown
# MonaCode archive

This directory preserves non-current decisions, audits, status snapshots, and release verdicts. It never defines current project progress; root README is the sole progress authority.

| Original path | Archived path | Bound revision/date | SHA-256 | Classification |
| --- | --- | --- | --- | --- |
```

Add one row for the status snapshot, release verdict, equivalence audit, comparator relocation, and each archived spec/plan file. The index states that frozen contracts and `docs/implementation-phases/` remain at original paths.

- [ ] **Step 4: Update live code references**

Change `PLAN_FILE` in `Tools/G6PlanAuthoring/lib/baseline.mjs` to:

```js
const PLAN_FILE = 'docs/archive/decisions/superpowers/plans/2026-08-15-monacode-g6r-execution-readiness.md';
```

Update live comparator references to `Comparators/Baselines/monaco-editor-0.56.0.editor.api.d.ts`. Do not edit frozen-contract or byte-preserved archive references.

- [ ] **Step 5: Verify byte preservation, links, G6 authoring tests, and contracts**

Run:

```bash
shasum -a 256 docs/archive/status-snapshots/0fd99e28b11f2eb1910be227b6f26c1aa15c8049/STATUS.md
shasum -a 256 docs/archive/audits/2026-08-19-monaco-api-equivalence/equivalence-gap.md
shasum -a 256 Comparators/Baselines/monaco-editor-0.56.0.editor.api.d.ts
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/baseline.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
git diff --check
```

Expected: hashes match; baseline test passes; all three contract verifiers pass.

- [ ] **Step 6: Commit Task 4**

```bash
git add -A docs Comparators/Baselines Tools/G6PlanAuthoring/lib/baseline.mjs
git commit -m "docs(VERIFY-001): archive superseded project narratives"
```

---

### Task 5: Capture current product-path evidence conservatively

**Files:**
- Create: `Comparators/probes/product-integration-probe.mjs`
- Create: `Tools/Docs/capture-project-evidence.mjs`
- Create: `Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs`
- Modify: `Tests/PlanStructureTests/ProjectGovernanceTests.mjs`
- Create at execution time: `artifacts/progress/<verification-source-set-digest>/task-evidence.json`

**Interfaces:**
- Produces: `auditProductIntegration(repoRoot) -> { findings }`
- Finding: `{ id, taskIDs, paths, observation, unblockCondition }`
- Produces: `captureProjectEvidence(repoRoot) -> { digest, commands, integrationFindings, taskResults }`
- Produces: `renderTaskTable(definitions, evidence) -> Markdown`
- Classification: every G6/mobile row starts as `TODO` because this migration creates no task-specific current-digest Definition-of-Done manifest. Passing shared gates and the absence of a known integration finding are insufficient to set a product row to `DONE`. `VERIFY-001` alone is `IN PROGRESS` through Task 6 and becomes `DONE` after Task 7 acceptance passes.

- [ ] **Step 1: Add seeded failing tests for every current integration rule**

Tests cover these exact rules and task bindings:

| Finding | Current observation | Bound G6 tasks |
| --- | --- | --- |
| `MODEL_RETAINED_MEMBERS_STUBBED` | search, word, decoration, undo/redo members still return empty/nil/false or no-op | `P01-T008`, `P02-T001`, `P02-T002`, `P02-T003` |
| `INSTANCE_SURFACE_UNCONFORMED` | no concrete type conforms to `MonaInstanceIEditor`/`ICodeEditor`/standalone/diff protocols | `P05-T012`, `P07-T009` |
| `DIFF_FACTORY_NOT_WIRED` | both diff constructors throw `.phase07NotWired` | `P05-T112`, `P07-T009`, `P07-T010` |
| `MARKER_SERVICE_ABSENT` | marker value type exists but global set/get/remove/change service is absent | `P05-T001`, `P05-T012`, `P05-T122` |
| `GLOBAL_MODEL_REGISTRY_ABSENT` | URI model lookup/list/language-change registry is absent | `P01-T012`, `P05-T012` |
| `CURSOR_EVENT_PAYLOADS_EMPTY` | cursor position/selection payload protocols have no concrete payload | `P04-T007`, `P05-T012` |
| `WIDGET_MOUSE_TARGET_SURFACE_EMPTY` | widget/view-zone/mouse-target public surfaces have no concrete controller path | `P03-T007`, `P05-T012` plus widget-dependent feature tasks |
| `LANGUAGE_CONTEXT_TYPES_EMPTY` | retained provider context/result declarations remain zero-member shells | `P05-T001`, `P05-T013`, `P06-T005` |
| `FEATURE_ACTIVATION_PATH_ABSENT` | editor attachment does not install a feature/contribution registry | every `P05-T100`…`P05-T161` task |
| `CURRENT_RELEASE_EVIDENCE_STALE` | current digest differs from P07-T011 evidence digest | every P08/P09 task |

Seeded fixtures remove or insert the exact source token for each rule and assert that the finding disappears or appears without relying on aggregate counts.

- [ ] **Step 2: Run probe tests and verify Red**

Expected: missing probe module.

- [ ] **Step 3: Implement source-backed integration rules**

Each rule reads the named current source files and matches both a positive implementation signature and the forbidden stub signature. Example:

```js
{
  id: 'DIFF_FACTORY_NOT_WIRED',
  taskIDs: ['P05-T112', 'P07-T009', 'P07-T010'],
  paths: ['Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift'],
  fails: ({ text }) => text.includes('throw MonaEditorFactoryError.phase07NotWired'),
  observation: 'createDiffEditor and createMultiFileDiffEditor throw phase07NotWired',
  unblockCondition: 'both constructors return attached concrete diff views and their public-path tests pass',
}
```

The probe prints canonical JSON and exits 1 while findings exist. Exit 1 is the correct current result; it proves incomplete rows without failing the governance checker.

- [ ] **Step 4: Implement evidence capture and task classification**

The capture tool runs and records these commands exactly once:

```text
/usr/bin/xcrun swift test --skip Soak4HourTests
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/*.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Comparators/probes/product-integration-probe.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Release/release-verdict.mjs
```

The tool treats the integration probe’s exit 1 as parsed findings, not a capture failure. It treats any other nonzero command as a shared-gate failure. `Soak4HourTests` is excluded because its source fixes `soakSeconds = 3600` and says it runs only under an explicit filter; its owning long-soak task remains `TODO`. The tool writes canonical sorted JSON only with `--write`, then prints the generated file path, artifact SHA-256, digest, command results, integration findings, and exact task counts. Initial counts are exactly `done=0 inProgress=1 blocked=0 todo=204`; implementation findings explain known gaps but never infer completion from silence.

- [ ] **Step 5: Run tests and capture current evidence**

Run:

```bash
git add Comparators/probes/product-integration-probe.mjs Tools/Docs/capture-project-evidence.mjs Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs Tests/PlanStructureTests/ProjectGovernanceTests.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs Tests/PlanStructureTests/ProjectGovernanceTests.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/capture-project-evidence.mjs --write
```

Staging the four source/test files before capture makes them members of the tracked source set. Expected: tests pass; capture creates exactly one `artifacts/progress/<digest>/task-evidence.json`; all current integration findings list exact task IDs and unblock conditions.

- [ ] **Step 6: Commit Task 5**

Stage the probe, tools, tests, and exact digest evidence directory. Confirm the staged paths before committing:

```bash
git add Comparators/probes/product-integration-probe.mjs Tools/Docs/capture-project-evidence.mjs Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs Tests/PlanStructureTests/ProjectGovernanceTests.mjs artifacts/progress
git diff --cached --name-status
git commit -m "verify(VERIFY-001): capture current product integration truth"
```

Expected staged paths are limited to the four source/test files and one generated `artifacts/progress/<digest>/task-evidence.json`.

---

### Task 6: Replace README and add repository-wide AGENTS enforcement

**Files:**
- Replace: `README.md`
- Create: `AGENTS.md`
- Modify: `.gitignore`
- Consume: `artifacts/progress/<verification-source-set-digest>/task-evidence.json`

**Interfaces:**
- README contains one marker pair and exactly 205 task rows.
- Every G6 row uses `plan:<Pxx-Txxx>/*`; four mobile rows use `mobile:<index>/*`; `VERIFY-001` uses `governance:single-source`.
- `DONE` evidence links to tracked source/test files and the captured artifact with its exact SHA-256.

- [ ] **Step 1: Render the exact 205-row table from the captured evidence**

Run:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/capture-project-evidence.mjs --render-task-table
```

Copy the complete stdout table into README with `apply_patch`. Do not pipe stdout into README. The renderer derives titles, selectors, stable IDs, exact acceptance command, source/test links, state, digest, result link, and artifact hash from frozen G6 plus captured evidence; it never reads or rewrites existing README state.

- [ ] **Step 2: Replace README with the approved section order**

README contains:

1. MonaCode goal and `monaco-editor@0.56.0` baseline.
2. Authority table.
3. Verified snapshot with date, source-set digest, artifact path/hash, and commands.
4. One Tasks marker pair and rendered 205-row table.
5. Definition of Done.
6. Build/verify commands.
7. Links to G6-R and archive index.

It contains no manually maintained percentage and no statement that 200 historical commits equal product completion.

- [ ] **Step 3: Create root AGENTS.md with all twelve approved rules**

Use the exact rules from spec section 9. Add a bootstrap record:

```markdown
## Governance bootstrap

The single-source migration is task `VERIFY-001`. After that task is DONE, every product, test, tool, and active-document change must bind an existing README task ID in its commit subject.
```

The file names the mandatory commands:

```bash
node Tools/Docs/check-project-governance.mjs
node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs
node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
git diff --check
```

- [ ] **Step 4: Ignore SwiftPM build output**

Add `.build/` to `.gitignore`. Preserve existing `.DS_Store`, `.superpowers/`, and command-oracle dependency rules.

- [ ] **Step 5: Run the live checker and focused tests**

Run:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs
git diff --check
git status --short
```

Validate the rendered README directly through `parseTaskLedger` and `validateTaskLedger` in the focused tests. The live repository checker remains blocked only by the current governance spec/plan, which Task 7 moves after execution finishes. Expected rendered counts satisfy:

```text
tasks=205 done=0 inProgress=1 blocked=0 todo=204 identities=3556 digest=<captured-digest>
```

`git status` does not list `.build/`.

- [ ] **Step 6: Commit Task 6**

```bash
git add README.md AGENTS.md .gitignore
git commit -m "docs(VERIFY-001): establish the project progress source of truth"
```

---

### Task 7: Rebind evidence after final source changes and close the migration

**Files:**
- Move: `docs/superpowers/specs/2026-08-20-monacode-single-source-governance-design.md` -> `docs/archive/decisions/superpowers/specs/2026-08-20-monacode-single-source-governance-design.md`
- Move: `docs/superpowers/plans/2026-08-20-monacode-single-source-governance.md` -> `docs/archive/decisions/superpowers/plans/2026-08-20-monacode-single-source-governance.md`
- Modify: `artifacts/progress/<final-digest>/task-evidence.json`
- Modify: `artifacts/releases/<final-digest>/release-verdict.json`
- Modify: `artifacts/releases/<final-digest>/RELEASE_VERDICT.md`
- Move when present: superseded `artifacts/progress/<old-digest>/` -> `docs/archive/evidence-snapshots/<old-digest>/progress/`
- Move when present: superseded `artifacts/releases/<old-digest>/` -> `docs/archive/evidence-snapshots/<old-digest>/releases/`
- Modify: `README.md` only when the final digest or measured task states differ
- Modify: `docs/archive/README.md` only when the plan/spec move paths need final index rows

**Interfaces:**
- Final source-set digest includes every tool/test/comparator change from Tasks 1–5.
- README digest, progress evidence, and release evidence use that same digest.
- `VERIFY-001` becomes `DONE` only after all governance acceptance commands pass.

- [ ] **Step 1: Recompute and compare the final digest**

First move the now-completed governance spec and plan with `git mv`, append their original path, archived path, Git revision, SHA-256, and `decision/implementation history; progress authority=false` classification to `docs/archive/README.md`, and verify their relative `../specs/...` link still resolves.

Run:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node -e "import('./Tools/Docs/source-set.mjs').then(({computeVerificationSourceSet})=>console.log(computeVerificationSourceSet(process.cwd()).digest))"
```

Compare the printed digest with every migration-created directory under `artifacts/progress/` and `artifacts/releases/`. For each differing digest, preserve the complete directory with `git mv` under `docs/archive/evidence-snapshots/<old-digest>/progress/` or `docs/archive/evidence-snapshots/<old-digest>/releases/`, then add its original path, archived path, digest, file SHA-256 values, and `superseded generated evidence; progress authority=false` classification to the archive index. Never delete migration evidence.

Generate release evidence for the printed final digest even when the Task 5 progress digest already matches:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Release/release-verdict.mjs --write
```

Expected: the live `artifacts/releases/` directory contains exactly the final-digest directory; every older migration-created release/progress directory is preserved under `docs/archive/evidence-snapshots/`.

- [ ] **Step 2: Run all governance and affected Node tests**

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/*.mjs Tools/G6PlanAuthoring/tests/*.test.mjs
```

Expected: exit 0, zero failing tests.

- [ ] **Step 3: Run the Swift suite without the explicit one-hour soak**

```bash
/usr/bin/xcrun swift test --skip Soak4HourTests
```

Expected: exit 0, zero failing tests, and the output records `Soak4HourTests` as skipped by filter. The formal long-soak task remains `TODO` because its current-digest one-hour evidence did not run.

- [ ] **Step 4: Verify all frozen contracts and archive hashes**

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/check-project-governance.mjs
```

Expected: all contracts pass; governance reports `findings=0`, `tasks=205`, `identities=3556`.

- [ ] **Step 5: Close the governance task and rebind final progress evidence**

Close the governance task only after Step 4 passes:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/capture-project-evidence.mjs --write --governance-complete
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/capture-project-evidence.mjs --render-task-table
```

Apply the complete rendered table to README with `apply_patch`, including the new progress-artifact SHA-256 and `VERIFY-001 = DONE`. Then run:

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/check-project-governance.mjs
```

Expected: `tasks=205`, `done=1`, `inProgress=0`, `blocked=0`, `todo=204`, `identities=3556`, and `findings=0`.

- [ ] **Step 6: Run final repository hygiene checks**

```bash
rg -n "MONACODE_TASKS:BEGIN|\| ID \| State \|" --glob '*.md' --glob '!README.md' --glob '!docs/contracts/**' --glob '!docs/archive/**' --glob '!docs/implementation-phases/**' .
rg -n "STATUS\.md|RELEASE_VERDICT\.md|docs/equivalence|docs/superpowers" --glob '!docs/contracts/**' --glob '!docs/archive/**' .
git diff --check
git status --short --branch
```

Expected: both `rg` commands print no active duplicate truth/reference; diff check is silent; only intentional final evidence/README changes are present before the final commit.

- [ ] **Step 7: Commit final evidence binding**

```bash
git add -A -- README.md docs artifacts
git diff --cached --name-status
git commit -m "verify(VERIFY-001): close single-source governance migration"
```

- [ ] **Step 8: Re-run post-commit checks without editing files**

On committed HEAD, rerun the commands from Steps 2, 3, 4, and 6 only. Do not rerun either evidence writer or the table renderer. Expected results remain identical and `git status --short` is empty. Report all commit hashes, exact task-state counts (`done=1 inProgress=0 blocked=0 todo=204`), final source-set digest, archived hashes, contract verifier outputs, test counts, and the fact that remote push was not performed.

---

## Self-review record

- **Spec coverage:** Sections 1–10 are implemented by Tasks 1, 2, 5, and 6; document migration in section 11 is Task 4; release relationship is Task 3; verification and failure behavior are Task 7.
- **No product scope expansion:** The plan creates governance/evidence tooling and moves documents; it does not change editor behavior, G6 cuts, thresholds, or platform scope.
- **Frozen path protection:** G4/G5/G6 remain untouched; `docs/implementation-phases/` remains in place; only the non-frozen G6 authoring baseline reference changes.
- **Intermediate artifact preservation:** STATUS, release verdict, equivalence audit, specs, plans, and superseded migration evidence are moved byte-for-byte and indexed; none are deleted.
- **Self-reference closure:** README and evidence use a digest that excludes README, AGENTS, archives, and generated evidence.
- **Progress honesty:** Historical `200/200` commits, passing shared gates, and missing probe findings are not `DONE` proof. Initial product/mobile rows remain `TODO` until a later task-specific current-digest Definition-of-Done manifest proves them.
- **Intentional `TODO` text:** Every occurrence of `TODO` in this plan refers to the approved task-state enum, not an implementation placeholder.
