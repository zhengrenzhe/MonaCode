# MonaCode G6-R Execution-Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and adopt a self-contained G6-R archive whose complete 200-task MonaCode implementation plan is machine-verifiable, stage-ordered, cold-checkout preflighted, and free of undeclared execution decisions.

**Architecture:** Preserve G4-R and G5-R byte-for-byte, snapshot the exact G5-R parent authority into a new G6-R sibling archive, and transform the existing G5-R task graph into a structured seven-stage execution graph. Implement independent command, path, file-state, interface, mutation, evidence, and task-state validators behind a single `planctl.mjs` entry point, then block adoption on clean-checkout reproduction and four adversarial rounds.

**Tech Stack:** Node.js 26.7.0 ESM, `node:test`, Node HTTPS, JSON Schema 2020-12 represented by repository-owned validators, SHA-256, `/usr/bin/sandbox-exec`, `/usr/bin/bsdtar`, Swift 6.3.3 interface-stub type checking, Xcode 26.6 build 17F113, Chrome 151.0.7922.138 comparator runtime, Git 2.50.1 Apple Git-155, macOS 26.6.1 build 25G76 on arm64.

## Global Constraints

- Approved design authority: `docs/superpowers/specs/2026-08-15-monacode-g6r-execution-readiness-design.md` with SHA-256 `7d03a74183f34619e4f306793136e030a3078498305e79bd6e3c9c060c769dda`.
- Never modify any file under `docs/contracts/monaco-editor-0.56.0/g4-r/` or `docs/contracts/monaco-editor-0.56.0/g5-r/`.
- G6-R inherits the complete G5-R product scope and acceptance thresholds; the permitted delta set contains planning governance only.
- Create no MonaCode product Swift source, product candidate, C01-C10 result, P00-P13 result, or release verdict during this plan.
- Preserve all 200 G5-R task IDs, 3,582 identity ownership rows, 200 evidence-contract identities, 200 Red commands, and 200 Green commands. Remap each evidence path only by replacing the exact segment `artifacts/acceptance-evidence/g5-r/` with `artifacts/acceptance-evidence/g6-r/`; retain the complete phase/task suffix and reject every other path delta.
- G5-R exposes 340 symbolic produced-interface IDs; 300 have no ASCII-identifier-boundary occurrence in product-contract artifacts outside the plan manifest. G6-R therefore authors and verifies exact interface contracts as new planning governance and never labels symbolic-name copying as interface closure.
- Convert the 400 inherited command records into the observed closed topology: 393 single-process, 5 all-success, and 2 pipeline records containing 407 leaf processes—359 Swift-test, 42 Node-test, 4 Node-script, and 2 Swift-package leaves.
- Normalize the 20 Node-test Red leaves whose inherited `--test-name-pattern` follows the positional file into option-before-file argv; Node.js 26.7.0 local controls prove the inherited order does not filter and the normalized order does.
- Lock Node, sandbox-exec, xcrun, Swift, Xcode, SDK, Git, bsdtar, system_profiler, Chrome, ICU data, macOS, and architecture to the exact current-device paths, versions, byte counts, and SHA-256 values captured by Task 1; every external executable is absolute and preflight rejects any mismatch.
- Every task contains the ordered stages `preflight`, `test-authoring`, `red`, `implementation`, `green`, `commit`, and `evidence`.
- G5-R defines zero task commit-message fields and zero `git commit` commands. Every G6-R product task therefore uses the new governance subject `monacode: complete <TASK_ID>` and only `planctl commit-task` can create that commit.
- Exactly 139 Swift-Red tasks receive compile-only scaffolds for 249 newly created Swift source paths; every scaffold is replaced in the same task and absent from final simulated state.
- Every local command input resolves to `baseline`, `dependency`, `task-step`, or `temporary`; no fifth availability class exists.
- All planning commands are non-interactive, use structured executable/argument arrays, declare timeouts, prohibit network by default, and isolate temporary mutations.
- Formal product evidence remains under `artifacts/acceptance-evidence/g6-r/`; planning verification remains under the G6-R documentation archive.
- An external display is valid for plan authoring and product development, and invalid for formal C01-C10 or P00-P13 evidence.
- Normative task text rejects the exact ambiguity lexicon defined in the approved design. Typed negative-fixture payloads are the only path-scoped exemption.
- Use literal exact paths for every commit except Task 2's committed, tested 148-line `--pathspec-from-file` input. Never stage an unenumerated directory or the entire worktree.
- Every authoring commit sets both author and committer to `zhengrenzhe <zhengrenzhe0416@outlook.com>`, disables hooks and signing, and is verified over the complete authoring range. Immediately after each authoring commit, run `/usr/bin/git status --porcelain=v1` and require empty output before the next task or evidence-generation command.
- Every authoring and final-verification test command enumerates literal test-file paths; shell glob expansion and directory test discovery are forbidden.

## File Responsibility Map

| Path | Responsibility |
| --- | --- |
| `Tools/G6PlanAuthoring/` | Reproducible authoring-only inventory, migration, fragment, render, and archive-build tools |
| `Tools/G6PlanAuthoring/fragments/` | Reviewable phase fragments generated from G5-R plus exact G6-R overrides |
| `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/` | Immutable parent snapshot, G6 authority, plan, command, and interface manifests |
| `g6-r/implementation-plan/lib/command-grammar.mjs` | Closed structured process and pipeline grammar |
| `g6-r/implementation-plan/lib/command-executor.mjs` | Sandboxed verification-command execution and controlled HTTPS source acquisition |
| `g6-r/implementation-plan/lib/command-paths.mjs` | Stage-time command-input producer proof |
| `g6-r/implementation-plan/lib/file-state.mjs` | Deterministic repository-state simulation |
| `g6-r/implementation-plan/lib/interfaces.mjs` | Exact interface contract and generated-stub checks |
| `g6-r/implementation-plan/lib/mutation-policy.mjs` | Repository and temporary mutation allowlist enforcement |
| `g6-r/implementation-plan/lib/task-state.mjs` | Seven-stage ordering, dependencies, and next-task selection |
| `g6-r/implementation-plan/lib/evidence.mjs` | Task evidence schema and stale-evidence rejection |
| `g6-r/implementation-plan/runtime/planctl.mjs` | Single non-interactive plan verification and preflight CLI |
| `g6-r/implementation-plan/tests/fixtures/` | Permanent positive controls and one-finding negative mutations |
| `g6-r/implementation-plan/verification/` | Plan audit, cold-checkout record, and four-round adversarial record |

## Task Dependency Graph

Tasks execute in numeric order. Task 7 also consumes Tasks 3 and 6; Task 10 consumes Tasks 4-9; Task 11 consumes Tasks 3-10; Tasks 12-23 form the product-phase fragment chain; Task 24 consumes all fragments; Tasks 25-34 form the adoption chain. No task depends on a later task.

---

### Task 1: Capture the immutable G5-R migration inventory

**Files:**
- Create: `Tools/G6PlanAuthoring/lib/baseline.mjs`
- Create: `Tools/G6PlanAuthoring/tests/baseline.test.mjs`
- Create: `Tools/G6PlanAuthoring/baseline-inventory.json`
- Create: `Tools/G6PlanAuthoring/parent-snapshot-paths.txt`

**Interfaces:**
- Produces: `buildBaselineInventory(repoRoot: string): BaselineInventory`
- Produces CLI `baseline.mjs --verify-authoring-range`, which selects `authoringBaseCommit` from the committed inventory and verifies the complete commit range through `HEAD` without a branch-name assumption.
- Produces read-only CLI `baseline.mjs --observe-display`, which invokes `/usr/sbin/system_profiler SPDisplaysDataType -json`, counts online displays and rows explicitly marked internal, derives `external = online - internal`, and emits canonical JSON without changing the toolchain lock.
- `BaselineInventory` contains exact G5-R hashes and counts for tasks, phases, commands, command forms, interfaces, files, evidence, ownership, and parent archive rows.

- [ ] **Step 1: Write the failing baseline test**

Before creating a Task 1 file, run `/usr/bin/git status --porcelain=v1` and require empty output; record `/usr/bin/git rev-parse HEAD` as the authoring base. Then write the test below.

```js
import assert from 'node:assert/strict';
import test from 'node:test';
import { buildBaselineInventory } from '../lib/baseline.mjs';

test('captures the exact G5-R execution migration surface', () => {
  const inventory = buildBaselineInventory(process.cwd());
  assert.match(inventory.authoringBaseCommit, /^[0-9a-f]{40}$/);
  assert.equal(inventory.plannedCommitSubjects.length, 35);
  assert.equal(new Set(inventory.plannedCommitSubjects).size, 35);
  assert.equal(inventory.tasks, 200);
  assert.deepEqual(inventory.phaseTaskCounts, {
    '00': 12, '01': 13, '02': 9, '03': 12, '04': 16,
    '05': 77, '06': 10, '07': 11, '08': 10, '09': 30
  });
  assert.deepEqual(inventory.commandTopologies, {
    allSuccess: 5, pipeline: 2, process: 393
  });
  assert.deepEqual(inventory.leafForms, {
    nodeScript: 4, nodeTest: 42, swiftPackage: 2, swiftTest: 359
  });
  assert.equal(inventory.leafProcesses, 407);
  assert.equal(inventory.redScaffoldTasks, 139);
  assert.equal(inventory.redScaffoldPaths, 249);
  assert.equal(inventory.redExitOneWithOneMarker, 200);
  assert.equal(inventory.greenExitZeroWithOneMarker, 200);
  assert.equal(inventory.nodeTestOptionReorders, 20);
  assert.equal(inventory.interfaces, 340);
  assert.equal(inventory.interfaceIDsMentionedOutsidePlan, 40);
  assert.equal(inventory.interfaceIDsOnlyInPlan, 300);
  assert.equal(inventory.contractIdentities, 3582);
  assert.equal(inventory.ownershipRows, 3582);
  assert.equal(inventory.taskOwnershipTokens, 326);
  assert.equal(inventory.createPaths, 314);
  assert.equal(inventory.modifyPaths, 2);
  assert.equal(inventory.testPaths, 198);
  assert.equal(inventory.commitPaths, 512);
  assert.equal(inventory.evidencePaths, 200);
  assert.equal(inventory.g5EvidencePrefixRows, 200);
  assert.equal(inventory.evidencePathsInsideCommitBoundaries, 0);
  assert.equal(inventory.g5TaskCommitMessageFields, 0);
  assert.equal(inventory.g5MarkdownGitCommitCommands, 0);
  assert.equal(inventory.parentFiles, 148);
  assert.equal(inventory.parentBytes, 4050132);
  assert.equal(inventory.parentChecksumRows, 144);
  assert.deepEqual(inventory.parentGitModes, { '100644': 148 });
  assert.deepEqual(inventory.toolchain, {
    architecture: 'arm64',
    bsdtar: { path: '/usr/bin/bsdtar', sha256: 'bc069dd7ef2ecea4c27ff9daa97f4ba4c5a1a41938bad8050e96bce5daa64346', version: '3.5.3', libarchive: '3.7.4' },
    chrome: { path: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', sha256: 'ee37661755341e9fc1babf9c20ec09d6a36e50aa8713ceb08082f8bbe2d8217d', version: '151.0.7922.138', icu: { path: '/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/151.0.7922.138/Resources/icudtl.dat', bytes: 10876560, sha256: '9f48c7f9c7c94d516a14870707e910ab94d75ae640ff6842c4af53276cd26ebe' } },
    git: { path: '/usr/bin/git', sha256: '44a68ddc1983d6cff3fd35ba3f9ba5f82004216f1dcde69892b3d1b06e408698', version: '2.50.1 (Apple Git-155)' },
    macOS: { version: '26.6.1', build: '25G76' },
    node: { path: '/opt/homebrew/Cellar/node/26.7.0/bin/node', sha256: '1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040', version: 'v26.7.0' },
    sandboxExec: { path: '/usr/bin/sandbox-exec', sha256: 'e3d7a792c58a5d3783d2f7274c82d70062393830d8cb1ded713ca554a470bd2f' },
    sdk: { path: '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk', version: '26.5' },
    swift: { path: '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift', sha256: '2ed38571e92c0283091838c1649e27650ad9c99950288e883c7b2dc6c4ce89fb', version: '6.3.3', swiftlang: '6.3.3.1.3', target: 'arm64-apple-macosx26.0' },
    systemProfiler: { path: '/usr/sbin/system_profiler', sha256: '6b868d95b01d44045fc434d5e867cd9ac5de15634fef126522d0a6919ccd2652' },
    xcode: { version: '26.6', build: '17F113' },
    xcrun: { path: '/usr/bin/xcrun', sha256: '4bc0cc7099775fbe35c653ceb09e0e393d2e5ada024db872e0eb8c43500b4dc6' }
  });
});
```

- [ ] **Step 2: Run the baseline test and observe the missing module**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/baseline.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/baseline.mjs`.

- [ ] **Step 3: Implement canonical inventory extraction**

```js
import fs from 'node:fs';
import { createHash } from 'node:crypto';

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const uniqueCount = (rows) => new Set(rows).size;

export function buildBaselineInventory(repoRoot) {
  const path = `${repoRoot}/docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`;
  const parentRoot = `${repoRoot}/docs/contracts/monaco-editor-0.56.0/g5-r`;
  const bytes = fs.readFileSync(path);
  const plan = JSON.parse(bytes);
  const parentRows = collectRegularFileRows(parentRoot);
  const tasks = plan.tasks;
  const commands = tasks.flatMap((task) => ['red', 'green'].flatMap(
    (stage) => task[stage].map((row) => row.run)
  ));
  const leafForm = (run) => run.startsWith('swift test ') ? 'swiftTest'
    : run === 'swift package dump-package' ? 'swiftPackage'
    : run.startsWith('node --test ') ? 'nodeTest'
    : run.startsWith('node ') ? 'nodeScript'
    : 'invalid';
  const parse = (run) => {
    if (run.includes(' && ')) return { topology: 'allSuccess', leaves: run.split(' && ') };
    if (run.includes(' | ')) return { topology: 'pipeline', leaves: run.split(' | ') };
    return { topology: 'process', leaves: [run] };
  };
  const parsed = commands.map(parse);
  const leaves = parsed.flatMap((row) => row.leaves);
  const interfaceIDs = [...new Set(tasks.flatMap((task) => task.interfaces.produces))].sort();
  const artifactCorpus = readArtifactCorpusExcludingPlanManifest(`${parentRoot}/artifacts`);
  const isIdentifierByte = (value) => value !== undefined && /[A-Za-z0-9_]/.test(value);
  const containsExactIdentifier = (corpus, id) => {
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(id)) throw new Error('G6_BASELINE_INTERFACE_ID');
    for (let offset = 0; ; offset += 1) {
      const index = corpus.indexOf(id, offset);
      if (index === -1) return false;
      if (!isIdentifierByte(corpus[index - 1]) && !isIdentifierByte(corpus[index + id.length])) return true;
      offset = index;
    }
  };
  const interfaceCoverage = {
    mentioned: interfaceIDs.filter((id) => containsExactIdentifier(artifactCorpus, id)),
    absent: interfaceIDs.filter((id) => !containsExactIdentifier(artifactCorpus, id))
  };
  const redScaffoldTasks = tasks.filter((task) => task.red.some((row) => row.run.startsWith('swift test '))
    && task.files.create.some((path) => path.startsWith('Sources/') && path.endsWith('.swift')));
  if (leaves.some((run) => leafForm(run) === 'invalid')) throw new Error('G6_BASELINE_COMMAND_FORM');
  const countBy = (rows, kinds, classify) => Object.fromEntries(kinds.map((kind) => [
    kind, rows.filter((row) => classify(row) === kind).length
  ]));
  return {
    authoringBaseCommit: resolveCommit(repoRoot, 'HEAD'),
    plannedCommitSubjects: collectPlannedCommitSubjects(repoRoot),
    planSha256: sha256(bytes),
    tasks: tasks.length,
    phaseTaskCounts: Object.fromEntries([...new Set(tasks.map((task) => task.phase))].sort()
      .map((phase) => [phase, tasks.filter((task) => task.phase === phase).length])),
    commandTopologies: countBy(parsed, ['allSuccess', 'pipeline', 'process'], (row) => row.topology),
    leafForms: countBy(leaves, ['nodeScript', 'nodeTest', 'swiftPackage', 'swiftTest'], leafForm),
    leafProcesses: leaves.length,
    redScaffoldTasks: redScaffoldTasks.length,
    redScaffoldPaths: redScaffoldTasks.flatMap((task) => task.files.create
      .filter((path) => path.startsWith('Sources/') && path.endsWith('.swift'))).length,
    redExitOneWithOneMarker: tasks.flatMap((task) => task.red)
      .filter((row) => row.expectedExit === 1 && row.expectedOutputIncludes.length === 1).length,
    greenExitZeroWithOneMarker: tasks.flatMap((task) => task.green)
      .filter((row) => row.expectedExit === 0 && row.expectedOutputIncludes.length === 1).length,
    nodeTestOptionReorders: leaves.filter((run) => /^node --test \S+ --test-name-pattern \S+$/.test(run)).length,
    interfaces: uniqueCount(tasks.flatMap((task) => [
      ...task.interfaces.produces, ...task.interfaces.consumes
    ])),
    interfaceIDsMentionedOutsidePlan: interfaceCoverage.mentioned.length,
    interfaceIDsOnlyInPlan: interfaceCoverage.absent.length,
    contractIdentities: plan.ownership.length,
    ownershipRows: plan.ownership.length,
    taskOwnershipTokens: tasks.flatMap((task) => task.ownership).length,
    createPaths: uniqueCount(tasks.flatMap((task) => task.files.create)),
    modifyPaths: uniqueCount(tasks.flatMap((task) => task.files.modify)),
    testPaths: uniqueCount(tasks.flatMap((task) => task.files.test)),
    commitPaths: uniqueCount(tasks.flatMap((task) => task.commitBoundary)),
    evidencePaths: uniqueCount(tasks.flatMap((task) => task.evidence)),
    g5EvidencePrefixRows: tasks.flatMap((task) => task.evidence)
      .filter((path) => path.startsWith('artifacts/acceptance-evidence/g5-r/')).length,
    evidencePathsInsideCommitBoundaries: tasks.reduce((count, task) => count
      + task.evidence.filter((path) => task.commitBoundary.includes(path)).length, 0),
    g5TaskCommitMessageFields: tasks.filter((task) => Object.hasOwn(task, 'commitMessage')).length,
    g5MarkdownGitCommitCommands: countExactGitCommitCommands(`${parentRoot}/implementation-plan`),
    toolchain: collectToolchainLock(),
    parentFiles: parentRows.length,
    parentBytes: parentRows.reduce((sum, row) => sum + row.bytes, 0),
    parentGitModes: countBy(parentRows, ['100644'], (row) => row.gitMode),
    parentChecksumRows: fs.readFileSync(`${repoRoot}/docs/contracts/monaco-editor-0.56.0/g5-r/SHA256SUMS`, 'utf8')
      .trim().split('\n').length
  };
}
```

Build `interfaceCoverage` by requiring every produced-interface ID to match the ASCII identifier grammar and searching G5-R `artifacts/`, excluding the G5 implementation-plan manifest, with non-identifier boundaries on both sides; record the 40 sorted mentioned IDs and 300 sorted absent IDs. The test includes `MonaDecoration`/`MonaDecorationCollection`, `MonaLocalization`/`MonaLocalizationProfileSet`, and `MonaWorkspaceEdit`/`MonaWorkspaceEditOutcome` negative controls so a prefix-only occurrence cannot count. This is a source-coverage fact, not proof of a complete declaration. Build `parentRows` by pairing recursive regular-file inspection with locked `/usr/bin/git ls-tree -r -z --full-tree HEAD -- docs/contracts/monaco-editor-0.56.0/g5-r`, rejecting symlinks, non-files, non-blob rows, path mismatches, and every mode except the observed `100644`, then sorting bytewise by relative path. Each row stores relative path, byte length, SHA-256, and Git mode; the frozen mode distribution is exactly `{ "100644": 148 }`. `countExactGitCommitCommands` reads every regular `.md`, `.mjs`, and `.json` file below the G5 implementation-plan root as UTF-8, counts lines matching the JavaScript regular expression `^\s*git\s+commit(?:\s|$)`, and rejects invalid UTF-8; the frozen result is zero. Record the Step 1 `authoringBaseCommit` and the ordered 35 commit subjects fixed by Tasks 1-33. Capture the exact toolchain lock shown in the test by invoking only absolute executable paths with argument arrays, resolving the Homebrew Node symlink once, and hashing the resolved regular file; reject every path, hash, version, SDK, OS-build, or architecture mismatch. Add a closed CLI `baseline.mjs --write-inventory PATH --write-parent-pathspec PATH`; it serializes the inventory with stable key order and a trailing newline, then writes exactly 148 newline-terminated destination paths, each prefixed `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/`, in the same bytewise order. `--verify-authoring-range` requires empty status, resolves the stored base and `HEAD` as commits, requires exactly 35 commits, requires their ordered subjects to equal the stored 35-subject sequence, checks every author and committer equal `zhengrenzhe <zhengrenzhe0416@outlook.com>`, requires every adversarial variant to record `resolutionCommit: null`, and runs Git's whitespace check across the complete range. Reject newline, NUL, Git pathspec magic, duplicate path input, unknown flags, and output paths outside the repository.

`resolveCommit` invokes locked Git with `['rev-parse', '--verify', 'HEAD^{commit}']`. `collectPlannedCommitSubjects` reads this committed implementation plan, extracts only the exact authoring command grammar used by Tasks 1-33, and requires the same 35 unique subjects in task/step order that the structural gate verifies. `collectToolchainLock` invokes and hashes only the absolute paths fixed by the preceding test.

- [ ] **Step 4: Run the test and verify the frozen counts**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/baseline.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/lib/baseline.mjs --write-inventory Tools/G6PlanAuthoring/baseline-inventory.json --write-parent-pathspec Tools/G6PlanAuthoring/parent-snapshot-paths.txt
```

Expected: 1 test passes, 0 fail; the writer prints `G6_BASELINE tasks=200 commands=400 leaves=407 parentFiles=148 parentBytes=4050132 parentMode100644=148 toolchain=locked`; both output files are byte-identical across two writer runs.

- [ ] **Step 5: Commit the migration inventory**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/lib/baseline.mjs \
  Tools/G6PlanAuthoring/tests/baseline.test.mjs \
  Tools/G6PlanAuthoring/baseline-inventory.json \
  Tools/G6PlanAuthoring/parent-snapshot-paths.txt
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: freeze G6-R migration inventory"
```

### Task 2: Create the unadopted G6-R skeleton and embedded parent snapshot

**Files:**
- Create: `Tools/G6PlanAuthoring/lib/skeleton.mjs`
- Create: `Tools/G6PlanAuthoring/tests/skeleton.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/README.md`
- Create exact set: the 148 paths under `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/` enumerated by `Tools/G6PlanAuthoring/parent-snapshot-paths.txt`.

**Interfaces:**
- Consumes: `BaselineInventory`
- Produces: `copyParentArchive(repoRoot: string): ParentSnapshotResult`
- `ParentSnapshotResult` contains 148 source/destination/hash/Git-mode rows, `bytes: 4050132`, `checksumRows: 144`, `mode100644: 148`, and `mismatches: 0`.

- [ ] **Step 1: Write the missing-snapshot test**

The test calls `copyParentArchive()` against a temporary target, compares each copied byte sequence with G5-R, and asserts the complete path set equals `parent-snapshot-paths.txt` after removing the fixed destination prefix:

```js
assert.equal(result.rows.length, 148);
assert.equal(result.bytes, 4050132);
assert.equal(result.checksumRows, 144);
assert.equal(result.mode100644, 148);
assert.deepEqual(result.rows.map((row) => row.source), expectedParentPaths);
assert.ok(result.rows.every((row) => row.gitMode === '100644'));
assert.equal(result.mismatches, 0);
```

- [ ] **Step 2: Run the test and observe the missing implementation**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/skeleton.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/skeleton.mjs`.

- [ ] **Step 3: Implement byte-copy and path confinement**

Use `fs.copyFileSync`, reject symlinks and special files, resolve every destination beneath the supplied target, set and verify every destination as non-executable Git mode `100644`, hash source and destination independently, compare the generated destination list with the committed pathspec, and sort rows bytewise by source path. Run the copied `verify-contract.mjs` from the embedded root and require its exact G5-R pass result. Write the G6 README with status `candidate`, parent `G5-R-full-scope-final`, plan `not-authored`, implementation `not-started`, and release acceptance `not-passed`.

- [ ] **Step 4: Run the test and build the repository skeleton**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/skeleton.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/lib/skeleton.mjs --write docs/contracts/monaco-editor-0.56.0/g6-r
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/verify-contract.mjs
```

Expected: test exit 0; writer prints `G6_PARENT_SNAPSHOT files=148 bytes=4050132 checksumRows=144 mode100644=148 mismatches=0`; the embedded verifier exits 0 with `adoptedRevision=G5-R-full-scope-final artifactHashesVerified=144`.

- [ ] **Step 5: Commit only the skeleton and parent bytes**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/lib/skeleton.mjs \
  Tools/G6PlanAuthoring/tests/skeleton.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/README.md
/usr/bin/git add --pathspec-from-file=Tools/G6PlanAuthoring/parent-snapshot-paths.txt
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: create MonaCode G6-R candidate skeleton"
```

### Task 3: Define the G6-R execution schema and strict validator

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-execution-schema.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/canonical-json.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/findings.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/schema.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/schema.test.mjs`

**Interfaces:**
- Produces: `validateExecutionPlan(value: unknown): Finding[]`
- Produces: `canonicalJSONStringify(value: unknown): string`
- Produces: `makeFinding({ id, category, taskID, path, message }): Finding`
- Produces: `sortFindings(findings: Finding[]): Finding[]`
- Produces exact record types `ExecutionPlan`, `TaskRecord`, `StageRecord`, `StageStep`, `ControllerAction`, `CommandSpec`, `ProcessSpec`, `PathInput`, `SourceAcquisition`, `InterfaceContract`, `InterfaceSource`, `ImplementationOperation`, `TaskTestContract`, `TestCaseContract`, `RedScaffold`, `MutationPolicy`, `TaskWorkspace`, `EvidenceContract`, `ProductCommitContract`, and `EvidenceCommitContract`.

- [ ] **Step 1: Write schema rejection tests**

Create one minimal valid plan fixture in the test, then mutate it to omit each stage, use an eighth stage, swap commit/evidence order, use a free-form command string, omit timeout, add an unknown availability class, omit evidence schema, and add an extra property. Assert exact finding IDs:

```js
assert.deepEqual(ids(validateExecutionPlan(withoutGreen)), ['PLAN_STAGE_SET']);
assert.deepEqual(ids(validateExecutionPlan(evidenceBeforeCommit)), ['PLAN_STAGE_ORDER']);
assert.deepEqual(ids(validateExecutionPlan(freeFormCommand)), ['PLAN_COMMAND_SHAPE']);
assert.deepEqual(ids(validateExecutionPlan(unknownAvailability)), ['PLAN_PATH_AVAILABILITY']);
assert.deepEqual(ids(validateExecutionPlan(extraProperty)), ['PLAN_SCHEMA_ADDITIONAL_PROPERTY']);
```

- [ ] **Step 2: Run the schema test and observe missing validator failure**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/schema.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/schema.mjs`.

- [ ] **Step 3: Implement the closed schema**

The JSON schema requires exactly the ordered stage array `preflight`, `test-authoring`, `red`, `implementation`, `green`, `commit`, `evidence` and one or more steps per stage. `StageStep` is a closed discriminated union of `controller-action`, `authoring-operation`, `verification-command`, `source-acquisition`, and `implementation-operation`. Stage/kind compatibility is exact: preflight contains exactly one `begin-task`; test-authoring contains one or more plan-selected authoring operations that collectively select the task's single `TaskTestContract`; Red contains exactly one selected verification command; implementation contains one or more selected source acquisitions or implementation operations and at least one implementation operation; Green contains exactly one selected verification command; commit contains exactly one `commit-task`; evidence contains exactly one `finalize-evidence`. Each `TaskTestContract` contains one or more closed `TestCaseContract` rows with exact file/checker path, target, Swift test symbol or Node name pattern, inline fixture values or fixture path/hash, ordered assertion IDs and operands, Red/Green leaf IDs, inherited output marker, failure class, authoring operation, and baseline/dependency/task-step source. Every Red and Green leaf is selected exactly once; no test case is unselected. The existing two-to-four completion assertions remain an exact task-level array and `finalize-evidence` verifies every assertion ID. Top-level command IDs match `^P[0-9]{2}-T[0-9]{3}\.(RED|GREEN)\.[0-9]{3}$`, and leaf IDs match the parent command ID plus `\.PROC\.[0-9]{3}`; the complete plan therefore has exactly 400 verification-command records while lifecycle actions remain separately typed. Command-record kind is exactly `process`, `all-success`, or `pipeline`; composition cannot nest; `all-success` and `pipeline` each contain at least two leaf processes; only pipeline records carry `pipefail: true`. Every leaf executable is an absolute path selecting one exact row in the Task 1 toolchain lock, and every inherited verification command has network mode `forbidden`. A `SourceAcquisition` requires an HTTPS URL without credentials, exact allowed host and redirect chain, positive expected and maximum byte counts, SHA-256, license identity, output path, closed output disposition `temporary` or `task-step`, task/stage owner, timeout, and existing-output behavior `require-same-hash`; temporary outputs resolve below the selected task root, while task-step outputs are repository-relative declared mutations. An archive source additionally requires format, exact entry count, exact and maximum expanded bytes, extraction root, and fixed rejections for absolute/traversal paths, symlinks, hard links, devices, duplicate normalized paths, collisions under the component key `component.normalize('NFC').toLowerCase().normalize('NFC')`, and collisions observed by exclusive creation in a probe root on the extraction target volume. A `RedScaffold` requires source path, complete declaration text/hash, sentinel behavior, `test-authoring` create owner, `implementation` replacement owner, Red assertion ID, and final-absence assertion. `TaskWorkspace` requires an opaque 256-bit ownership token, realpath-normalized task root, exact plan/task/base hashes, current stage, and lifecycle state. Every `ProductCommitContract` requires exact author and committer name `zhengrenzhe`, email `zhengrenzhe0416@outlook.com`, message matching `^monacode: complete P[0-9]{2}-T[0-9]{3}$` and the enclosing task ID exactly, exact preflight-base parent, exact staged product path set, hooks/signing disabled, and evidence exclusion. Every `EvidenceCommitContract` requires the same identity, message matching `^evidence\(monacode\): complete P[0-9]{2}-T[0-9]{3}$` and task ID, sole parent equal to the product commit, immediate first-parent-successor selection on the execution history, exact staged set containing only the task evidence path, zero later first-parent commits touching that path, hooks/signing disabled, selector mode `external-git`, and a prohibition on embedding its own blob hash or commit ID in the evidence JSON. The schema also requires positive integer timeouts, closed local availability values, and `additionalProperties: false` at every object layer. `canonical-json.mjs` recursively sorts object keys and preserves array order. `findings.mjs` owns the one finding shape and sort order used by every later module. `schema.mjs` returns sorted findings without throwing for data errors.

- [ ] **Step 4: Run schema tests**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/schema.test.mjs`

Expected: all positive and negative schema cases pass with zero unexpected findings.

- [ ] **Step 5: Commit schema and validator**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-execution-schema.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/canonical-json.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/findings.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/schema.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/schema.test.mjs
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: define G6-R execution schema"
```

### Task 4: Implement the closed command grammar and G5-R converter

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/command-grammar.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-grammar.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs`

**Interfaces:**
- Produces: `convertG5Command({ task, stage, index, row }): CommandSpec`
- Produces: `auditCommandSpec(command: CommandSpec): Finding[]`
- Produces: `assertPackageGraph(packageJSON: unknown): { exit: number, output: string }`
- Produces: `parseObservedG5Command(run: string): { topology: 'process' | 'all-success' | 'pipeline', leaves: string[] }`
- Defines module-private helpers `convertLeaf({ parentID, leafIndex, task, run }): ProcessSpec`, `processCommand({ id, leaf, policy }): CommandSpec`, `allSuccessCommand({ id, leaves, policy }): CommandSpec`, and `pipelineCommand({ id, leaves, policy, pipefail: true }): CommandSpec` in `command-grammar.mjs`.

- [ ] **Step 1: Write topology, leaf-form, and forbidden-shell tests**

Assert exact conversion counts from the embedded G5-R parent plan: 393 process, 5 all-success, and 2 pipeline records; 359 Swift-test, 42 Node-test, 4 Node-script, and 2 Swift-package leaves; and 20 Node-test option reorders. Execute a Node control proving file-before-option selects all cases while normalized option-before-file selects one. Reject mixed or nested composition, an all-success record with fewer than two leaves, command substitution, implicit globbing, interactive flags, an absent timeout, any verification-command network mode other than `forbidden`, a pipeline without `pipefail: true`, any changed all-success short-circuit order, an unnormalized Node-test option, and a Red record whose failure class is outside `behavioral`, `structural`, `package-graph`, `provenance`, or `qualification` or whose expected output marker is absent. Every Swift-test Red uses `behavioral`.

- [ ] **Step 2: Run the command tests and observe missing implementation**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-grammar.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/command-grammar.mjs`.

- [ ] **Step 3: Implement deterministic conversion**

```js
export function convertG5Command({ task, stage, index, row }) {
  const id = `${task.id}.${stage === 'red' ? 'RED' : 'GREEN'}.${String(index + 1).padStart(3, '0')}`;
  const parsed = parseObservedG5Command(row.run);
  const leaves = parsed.leaves.map((run, leafIndex) => convertLeaf({
    parentID: id, leafIndex, task, run
  }));
  const timeoutMs = task.phase === '09' ? 1_800_000
    : leaves.some((leaf) => leaf.form === 'swift-test' || leaf.form === 'swift-package') ? 600_000
    : 120_000;
  const policy = buildCommandPolicy({ id, stage, row, timeoutMs, leaves });
  if (parsed.topology === 'process') return processCommand({ id, leaf: leaves[0], policy });
  if (parsed.topology === 'all-success') return allSuccessCommand({ id, leaves, policy });
  if (parsed.topology === 'pipeline') return pipelineCommand({ id, leaves, policy, pipefail: true });
  throw new Error(`PLAN_COMMAND_FORM_UNSUPPORTED ${task.id} ${stage}`);
}
```

Every Swift-test leaf uses executable `/usr/bin/xcrun`, starts its argv with `swift test`, and adds `--scratch-path` pointing to a `planctl`-allocated temporary directory. Every Swift-package leaf uses the same executable and starts its argv with `swift package`. Every Node leaf uses `/opt/homebrew/Cellar/node/26.7.0/bin/node`. Red records declare the exact test/checker paths and Red scaffolds produced by `test-authoring`; Green records declare those paths plus every product path replaced, created, or modified by `implementation`; Swift leaves also declare `Package.swift` and package inputs available at that stage. Every Red expected-result record declares one closed failure class and retains its G5 required output marker, so compilation, linking, missing-module, or unrelated package-graph failure cannot satisfy it. `convertLeaf` rewrites exactly the 20 inherited Node-test argv arrays from `['--test', FILE, '--test-name-pattern', VALUE]` to `['--test', '--test-name-pattern', VALUE, FILE]`; every other token retains order. Node-test and Node-script leaves declare their exact repository-local script paths from their argument arrays. P00-T001 rewrites only its checker leaf to the baseline G6-R `runtime/assert-package-graph.mjs`; no command retains `Tools/PlanChecks/assert-package-graph.mjs`. The checker emits `PLAN_PACKAGE_GRAPH_MISSING` for absent input and the exact Green summary for the required graph. Aggregate expected exit and output assertions remain on the parent command record; evidence records every leaf exit and stream hash in order. Command audit compares all executable paths and the complete toolchain lock before accepting a record.

- [ ] **Step 4: Run conversion and checker tests**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-grammar.test.mjs`

Expected: all tests pass; conversion summary is `records=400 process=393 allSuccess=5 pipeline=2 leaves=407 swiftTest=359 nodeTest=42 nodeScript=4 swiftPackage=2 nodeOptionReorders=20 unsupported=0`; the P00-T001 Red control emits `PLAN_PACKAGE_GRAPH_MISSING` without `MODULE_NOT_FOUND`.

- [ ] **Step 5: Commit command grammar and baseline checker**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/command-grammar.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-grammar.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: enforce G6-R command grammar"
```

### Task 5: Prove command-input availability and producer order

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/command-paths.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-dependencies.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/command-input-missing.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/command-input-future.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/command-input-duplicate.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/command-input-hash-drift.json`

**Interfaces:**
- Produces: `buildPathProducerIndex(plan, baselineRows): Map<string, PathProducer[]>`
- Produces: `auditCommandDependencies(plan, baselineRows): Finding[]`
- Produces: `auditImplementationSourceInputs(plan, baselineRows): Finding[]`

- [ ] **Step 1: Write exact one-finding dependency tests**

Each fixture declares one expected finding: `PLAN_COMMAND_INPUT_UNAVAILABLE`, `PLAN_COMMAND_INPUT_FROM_FUTURE`, `PLAN_COMMAND_INPUT_AMBIGUOUS`, or `PLAN_COMMAND_INPUT_HASH_MISMATCH`. Inline source controls also assert `PLAN_SOURCE_INPUT_UNDECLARED`, `PLAN_SOURCE_OUTPUT_COLLISION`, and `PLAN_SOURCE_PRODUCER_ORDER`. Assert deep equality, not set containment.

- [ ] **Step 2: Run tests and observe missing resolver**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-dependencies.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/command-paths.mjs`.

- [ ] **Step 3: Implement stage-aware resolution**

```js
export function auditCommandDependencies(plan, baselineRows) {
  const index = buildPathProducerIndex(plan, baselineRows);
  const findings = [];
  for (const task of plan.tasks) {
    for (const [stageIndex, stage] of plan.stageOrder.entries()) {
      for (const step of task.stages[stage]) {
        for (const input of step.command?.inputs ?? []) {
          findings.push(...resolveInput({ input, task, stageIndex, plan, index }));
        }
      }
    }
  }
  return findings.sort(compareFindings);
}
```

Resolution walks every process leaf in parent-record order and checks the exact availability class, producer uniqueness, same-task step order, transitive task dependency, and baseline checksum. The parent record and all leaf IDs appear in each finding subject so an all-success or pipeline input cannot hide behind aggregate validation. It also walks every implementation operation source reference: a local source resolves through the same four availability classes; a remote source selects one `SourceAcquisition` owned by that task before the consuming operation, with one output path/disposition that does not collide with a baseline or another producer. Remote bytes become a temporary or task-step path only after `planctl acquire-source` records a matching acquisition result; a temporary output cannot be consumed by a later task.

- [ ] **Step 4: Run dependency tests**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-dependencies.test.mjs`

Expected: command and source positive controls return `[]`; each mutation returns its one declared finding.

- [ ] **Step 5: Commit command dependency proof**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/command-paths.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-dependencies.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/command-input-missing.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/command-input-future.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/command-input-duplicate.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/command-input-hash-drift.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: prove G6-R command dependencies"
```

### Task 6: Simulate every task's file-state transition

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/file-state.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/file-state.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/file-created-twice.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/file-modified-before-create.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/file-consumed-before-step.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/commit-boundary-drift.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/red-scaffold-missing.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/red-scaffold-unreplaced.json`

**Interfaces:**
- Produces: `simulateFileState(plan, baselineRows): SimulationResult`
- `SimulationResult` contains sorted findings, 200 task-state hashes, and one final-state SHA-256.

- [ ] **Step 1: Write file-state mutation tests**

Assert exact IDs `PLAN_FILE_CREATE_COLLISION`, `PLAN_FILE_MODIFY_UNAVAILABLE`, `PLAN_FILE_INPUT_UNAVAILABLE_AT_STAGE`, `PLAN_COMMIT_BOUNDARY_DRIFT`, `PLAN_RED_SCAFFOLD_MISSING`, and `PLAN_RED_SCAFFOLD_UNREPLACED`.

- [ ] **Step 2: Run tests and observe missing simulator**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/file-state.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/file-state.mjs`.

- [ ] **Step 3: Implement immutable path-state transitions**

Represent each product path state as `{ path, kind, ownerTask, ownerStage, contentSource, disposition }`. Clone the map before each step, apply declared mutations, hash the canonical sorted rows, and compare the task's product commit path set with every product mutation accumulated since task preflight. A declared new Swift path in a Swift-Red task transitions `absent -> red-scaffold` during test-authoring and `red-scaffold -> implementation` during implementation; any other transition or final scaffold disposition is a finding. Track the 200 evidence paths and their exact `.g6-beginning`, `.g6-part`, `.g6-committing`, and `.g6-finalizing` journal states in a separate evidence map: the product commit must precede passed evidence; no evidence or journal path can enter the product staged set; only finalization can stage the current evidence path; no journal is ever staged or tracked; and only a `passed` evidence blob whose evidence-only commit is the immediate first-parent successor of its selected product commit on the current execution history can satisfy a successor dependency. No later first-parent commit can modify or delete that evidence path.

- [ ] **Step 4: Run simulator tests**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/file-state.test.mjs`

Expected: positive fixture returns zero findings and a stable hash on two runs; each mutation returns its exact one finding.

- [ ] **Step 5: Commit the file-state simulator**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/file-state.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/file-state.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/file-created-twice.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/file-modified-before-create.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/file-consumed-before-step.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/commit-boundary-drift.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/red-scaffold-missing.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/red-scaffold-unreplaced.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: simulate G6-R file state"
```

### Task 7: Define exact interface contracts and compile planning stubs

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/interfaces.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/interfaces.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/interface-signature-drift.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/interface-order-drift.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/interface-duplicate-producer.json`

**Interfaces:**
- Produces: `buildInterfaceContract({ task, interfaceID, contractSources }): InterfaceContract`
- Produces: `auditInterfaceContracts(plan, contracts): Finding[]`
- Produces: `renderInterfaceStubPackage(contracts, outputDirectory): string[]`

- [ ] **Step 1: Write signature, order, and compilation tests**

Use one Swift-declaration contract, one JSON-schema contract, and one command contract. Assert exact signature hashing and exact findings `PLAN_INTERFACE_SIGNATURE_MISMATCH`, `PLAN_INTERFACE_ORDER`, and `PLAN_INTERFACE_PRODUCER_DUPLICATE`. Compile the Swift control with `xcrun swiftc -typecheck`.

- [ ] **Step 2: Run tests and observe the missing interface module**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/interfaces.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/interfaces.mjs`.

- [ ] **Step 3: Implement three closed interface kinds**

```js
const INTERFACE_KINDS = new Set(['swift-declaration', 'json-schema', 'command-contract']);

export function auditInterfaceContracts(plan, contracts) {
  const byID = new Map(contracts.map((row) => [row.id, row]));
  const findings = [];
  for (const task of plan.tasks) {
    for (const input of task.interfaces.consumes) {
      const contract = byID.get(input.id);
      if (!contract || contract.signatureSha256 !== input.signatureSha256) {
        findings.push(finding('PLAN_INTERFACE_SIGNATURE_MISMATCH', `${task.id}:${input.id}`, 'signature hash mismatch'));
      }
    }
  }
  return findings.concat(auditProducerOrder(plan, contracts)).sort(compareFindings);
}
```

Swift rows include declaration text, target, visibility, availability, actor isolation, ownership, `Sendable` disposition, and signature hash. JSON rows include selected schema path/hash and closed schema identity. Command rows include the structured command-record hash, ordered leaf hashes, input contract hashes, output schema, and expected-result contract. Symbolic-only interface rows and any fourth kind fail with `PLAN_INTERFACE_CONTRACT_INCOMPLETE`.

- [ ] **Step 4: Run interface tests and repeat type checking**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/interfaces.test.mjs`

Expected: all tests pass; generated control stubs type-check twice with identical file hashes.

- [ ] **Step 5: Commit interface validation**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/interfaces.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/interfaces.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/interface-signature-drift.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/interface-order-drift.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/interface-duplicate-producer.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: enforce G6-R interface contracts"
```

### Task 8: Enforce command and task mutation policies

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/mutation-policy.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-policy.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/repository-mutation-leak.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/temporary-mutation-leak.json`

**Interfaces:**
- Produces: `auditMutationPolicy(task): Finding[]`
- Produces: `compareObservedMutations(policy, observedPaths): Finding[]`

- [ ] **Step 1: Write allowlist and leakage tests**

Verify that `begin-task` mutates only the selected untracked evidence path, `.g6-beginning` journal, and token-owned task root; test-authoring mutates only declared tests, fixtures, checkers, and Red-scaffold paths; every process leaf under Red and Green mutates only the parent record's declared command child; all-success stops after its first non-zero leaf; pipelines report every leaf and aggregate `pipefail` status; implementation mutates only task file rows, declared source-acquisition task-step/partial paths, and scaffold replacements; commit stages stage only the exact product commit boundary and mutate only the selected `.g6-committing` journal plus running evidence, never stage evidence; and evidence finalization mutates only its evidence path, `.g6-part`/`.g6-finalizing` journals, token-owned root/tombstone, and Git index/history for the single evidence-only commit. Require the evidence commit diff to contain exactly the evidence path and no product or journal path. Assert `PLAN_REPOSITORY_MUTATION_UNDECLARED`, `PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT`, `PLAN_EVIDENCE_JOURNAL_STATE`, `PLAN_EVIDENCE_COMMIT_BOUNDARY`, `PLAN_ALL_SUCCESS_ORDER`, `PLAN_PIPELINE_STATUS`, and `PLAN_RED_SCAFFOLD_MUTATION`.

- [ ] **Step 2: Run tests and observe the missing module**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-policy.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/mutation-policy.mjs`.

- [ ] **Step 3: Implement path-normalized mutation comparison**

Reject absolute repository paths, parent traversal, symlink escape, overlapping wildcard policies, and paths outside the repository or command temporary root. Compare normalized sorted exact rows.

- [ ] **Step 4: Run mutation-policy tests**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-policy.test.mjs`

Expected: positive controls pass; both leakage fixtures return their one exact finding.

- [ ] **Step 5: Commit mutation-policy enforcement**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/mutation-policy.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-policy.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/repository-mutation-leak.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/temporary-mutation-leak.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: bound G6-R task mutations"
```

### Task 9: Implement task-state and evidence truth

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/schemas/task-evidence.schema.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/schemas/task-state.schema.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/task-state.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/evidence.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/task-state.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/evidence.test.mjs`

**Interfaces:**
- Produces: `nextTask({ plan, evidenceByTask }): NextTaskResult`
- Produces: `beginTaskEvidence({ plan, taskID, evidencePath, repositoryState, taskWorkspace }): EvidenceRecord`
- Produces: `resumeTaskEvidence({ plan, taskID, evidence, repositoryState, taskWorkspace }): EvidenceRecord`
- Produces: `auditTaskEvidence({ plan, taskID, evidence, dependencyEvidence }): Finding[]`
- Produces: `finalizeTaskEvidence({ plan, taskID, evidence, productCommit }): EvidenceRecord`
- Produces: `selectEvidenceCommit({ repoHead, productCommit, evidencePath, git }): EvidenceCommitSelection`
- Evidence states are exactly `absent`, `running`, `failed`, and `passed`.

- [ ] **Step 1: Write state and stale-evidence tests**

Assert that `nextTask` returns one task, completion, or one blocking finding. Prove `beginTaskEvidence` records one base commit and one 256-bit workspace token through a recoverable beginning journal, an unexpected Red/Green attempt stays `running` at `test-authoring`/`implementation`, an invariant failure moves to `failed`, and `resumeTaskEvidence` accepts only `failed` or `running` with exact crash residue plus the unchanged pre-commit base, empty index, policy-bounded worktree, matching task-root token, and matching plan/task hashes. Build a linear temporary Git history with two completed tasks and prove the first task remains valid when `HEAD` is the second task's evidence commit. Mutate plan hash, task hash, dependency hash, command result, mutation result, beginning journal, workspace token, base commit, index state, crash-residue path/type/target state, assertion result, product ancestry, immediate evidence successor, evidence commit parent/identity/message/boundary/blob, and a later modify-then-restore sequence on the evidence path; assert stable evidence finding IDs.

- [ ] **Step 2: Run both test files and observe missing modules**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/task-state.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/evidence.test.mjs
```

Expected: both exit 1 with missing-module errors.

- [ ] **Step 3: Implement fail-closed state transitions**

`selectEvidenceCommit` first proves the recorded product commit is on `repoHead`'s first-parent ancestry. Using locked `/usr/bin/git` argument arrays, it enumerates `productCommit..repoHead` in first-parent chronological order and selects the first commit; that commit must exist, have the product commit as its sole parent, match the evidence identity/subject contract, and change exactly the declared evidence path to the bytes currently under validation. It then requires `git rev-list --first-parent EVIDENCE_COMMIT..repoHead -- EVIDENCE_PATH` to return no commit, which rejects every later modification, deletion, or modify-then-restore sequence. `nextTask` uses lexicographic topological order and accepts a dependency only when its evidence file is `passed` with matching plan/task hashes and this selector returns exactly one valid evidence commit. `beginTaskEvidence` accepts only `absent`, the single task selected by `nextTask`, an empty index, clean tracked prior evidence, and the preflight-approved product/evidence status. It creates and fsyncs `EVIDENCE_PATH.g6-beginning` with `HEAD`, plan/task hashes, a controller-generated 32-byte token, and the deterministic root name `monacode-g6-<TASK_ID>-<first16-of-token-sha256>`; creates that mode-0700 root exclusively; writes/fsyncs its mode-0600 raw-token marker and root directory; atomically publishes untracked `running` containing only the token SHA-256; and removes the raw-token journal. A retry accepts only the five non-empty prefix states of those five ordered operations and produces identical running bytes. Before product commit, command and acquisition handlers append canonical attempts only to that task's untracked `running` evidence record. A Red or Green expected-result mismatch appends the attempt without advancing and leaves the current stage at `test-authoring` or `implementation`; a toolchain, authority, workspace-token, mutation-policy, or evidence-integrity finding moves to `failed`. `resumeTaskEvidence` accepts `failed` or `running` with exact crash residue only when `HEAD` still equals the recorded base, the index is empty, observed changes are a subset of the current task policy, the same task root and token hash validate, and authority hashes match. It removes only exact plan-derived `.g6-part` files or token-owned command children when each candidate is a non-symlink node below the selected workspace and its final target still has the prior recorded hash or declared-absent state; it then appends a resume record and returns to the recorded stage without deleting, reverting, staging, or committing a product path. `finalizeTaskEvidence` builds the passed bytes after product commit and requires that commit's parent to equal the task preflight base, its author/committer/`monacode: complete <TASK_ID>` subject to equal the product contract, its committed path set to equal that task's exact boundary drawn from the plan-wide 512-path domain, and no evidence path in its tree delta. Evidence validation compares the selected command-executor and sandbox-profile hashes, exact parent command IDs, ordered leaf IDs, every leaf exit status and stdout/stderr hash, aggregate expected result, source-acquisition URL/host/redirect/byte/hash/license/output results, file hashes, environment hash, mutation result, actual before/product commit pair, beginning/committing/finalizing journal state, workspace cleanup result, externally selected evidence blob/commit contract, and every completion assertion ID. The passed JSON contains the product commit and selector mode `external-git`, but neither its own blob hash nor evidence commit ID. A command result without selected executor provenance, an acquisition result without the selected source contract, or passed bytes without the matching evidence commit fails closed.

- [ ] **Step 4: Run task-state and evidence tests**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/task-state.test.mjs docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/evidence.test.mjs`

Expected: all controls and mutations pass with zero unexpected findings.

- [ ] **Step 5: Commit state and evidence modules**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/schemas/task-evidence.schema.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/schemas/task-state.schema.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/task-state.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/evidence.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/task-state.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/evidence.test.mjs
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: enforce G6-R task evidence truth"
```

### Task 10: Build the non-interactive `planctl` controller

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/command-executor.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/planctl.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-executor.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/planctl.test.mjs`

**Interfaces:**
- Produces: `executeVerificationCommand({ command, task, repoRoot, evidencePath, toolchain }): Promise<CommandExecutionResult>`.
- Produces: `acquireSource({ source, task, repoRoot, evidencePath, httpsClient }): Promise<SourceAcquisitionResult>`.
- Produces: `commitTask({ plan, taskID, repoRoot, evidencePath, git }): Promise<CommitTaskResult>`.
- Produces CLI commands `verify-archive`, `audit`, `simulate`, `begin-task --task --evidence-path`, `resume-task --task --evidence-path`, `preflight --task`, `preflight --all`, `run-command --id --evidence-path`, `acquire-source --task --source --evidence-path`, `commit-task --task --evidence-path`, `finalize-evidence --task --path`, `interfaces compile`, `next`, `verify-evidence`, and `render`.
- Every command writes canonical JSON to stdout and findings to the same JSON payload; exit 0 means zero findings.

- [ ] **Step 1: Write CLI dispatch and exit-code tests**

Spawn `planctl.mjs` with every command, one unknown command, one absent required flag, and one fixture with a finding. Assert stdout parses as JSON and exit codes are exact. Prove `begin-task` creates one owned task root and canonical `running` record, `resume-task` enforces its exact pre-commit recovery predicate, and neither command mutates product files or Git history. Inject a stop after every beginning-journal operation and prove rerun convergence. Executor tests use synthetic process, all-success, and pipeline records to prove ordered leaves, short-circuiting, pipefail, timeout termination, stream hashing, expected-result matching, and exact running-evidence updates. A local loopback server plus the production sandbox proves a verification leaf cannot connect; write probes prove only a fresh command child below the selected task root is writable. Source-acquisition controls inject a deterministic HTTPS client and attack scheme, credentials, host, redirect chain, timeout, download and expanded-byte caps, exact download and expanded bytes, archive entries, SHA-256, license identity, partial path, output collision, foreign workspace token, and idempotent same-hash reuse; command/evidence/acquisition crash residues converge only through `resume-task`. A temporary Git fixture proves `commit-task` is the sole product-commit creator: it accepts the exact base, Green result, author/committer/message, path boundary, unchanged tracked prior evidence, and untracked current evidence; disables hooks and signing; and rejects wrong base, an unjournaled dirty index, wrong identity/message, underreach, overreach, current evidence staged/tracked early, modified prior evidence, or a second product commit. Inject a stop after journal creation, each staged path, product commit creation, evidence append, and journal removal; every rerun produces the same sole product commit. The same fixture proves `finalize-evidence` accepts that exact product commit, rejects every identity/tree/evidence mismatch, removes only the token-owned task root, publishes and commits only the passed evidence path, and creates one evidence commit with exact identity/message/parent/blob. Inject a stop after every finalizing-journal, cleanup, publish, stage, commit, and journal-removal operation; every rerun converges to the same sole evidence commit, and passed JSON contains neither its own blob hash nor commit ID.

- [ ] **Step 2: Run the controller test and observe the missing entry point**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-executor.test.mjs docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/planctl.test.mjs`

Expected: exit 1 with missing-module errors for `lib/command-executor.mjs` and `runtime/planctl.mjs`.

- [ ] **Step 3: Implement explicit dispatch**

```js
const handlers = new Map([
  ['acquire-source', runAcquireSource],
  ['audit', runAudit],
  ['begin-task', runBeginTask],
  ['commit-task', runCommitTask],
  ['finalize-evidence', runFinalizeEvidence],
  ['interfaces compile', runInterfaceCompile],
  ['next', runNext],
  ['preflight --all', runPreflightAll],
  ['preflight --task', runPreflightTask],
  ['render', runRender],
  ['resume-task', runResumeTask],
  ['run-command', runCommand],
  ['simulate', runSimulate],
  ['verify-archive', runVerifyArchive],
  ['verify-evidence', runVerifyEvidence]
]);
```

Parse only the documented flags, reject duplicates and unknown flags, remove only token-owned temporary roots/transients, and never modify repository files during preflight. `begin-task` invokes the same read-only task preflight, creates/fsyncs `EVIDENCE_PATH.g6-beginning` first, selects the root `monacode-g6-<TASK_ID>-<first16-of-token-sha256>` below the realpath of the closed controller `TMPDIR`, creates it exclusively with mode 0700, writes/fsyncs the random 32-byte token in a mode-0600 marker, atomically publishes the prehashed running evidence, fsyncs its parent, and removes the journal. It emits `${TASK_TEMP}` only as a display placeholder plus the selected realpath in the canonical result. Re-entry accepts only the ordered prefix states of that journal protocol. `resume-task` requires the same marker/token/root and the Task 9 recovery predicate; it also accepts a `running` record with exact orphan controller residue created before publication of a failure record. Export `createPlanctl({ handlers }): { run(argv): Promise<PlanctlResult> }` so tests inject deterministic handlers. The CLI entry point uses pre-assembly handlers that return the exact finding `PLAN_AUTHORITY_NOT_ASSEMBLED` until Task 26 replaces them with the complete audit/runtime handlers; dispatch and argument tests assert this result instead of claiming an assembled plan exists.

`preflight --all` validates the exact encoding, ownership, producer order, and stage-time enforcement point of every future qualification predicate, but creates no `QEnvironmentID` and makes zero live C/P qualification claims. The read-only display observation is reported separately. `preflight --task` and `begin-task` evaluate a live environment predicate only for the selected task; Phase 09 formal tasks require the frozen zero-external-display predicate at that time and record the resulting `QEnvironmentID` in task evidence. This separation lets the currently attached external display qualify plan authoring and product development without qualifying a future formal cell.

`executeVerificationCommand` first compares the complete Task 1 toolchain lock, validates the task-root marker/token selected by the `running` evidence, and captures `/usr/bin/git status --porcelain=v2 -z --untracked-files=all`. It permits validated `passed` evidence paths with no journal, the selected current running evidence path, and only the exact controller journal permitted by that current lifecycle operation; every other evidence or journal row is outside product state and is still a finding. It creates a fresh realpath-normalized command child below the selected task root and an exact child environment containing `PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/Cellar/node/26.7.0/bin`, `LC_ALL=C`, `LANG=C`, `TZ=UTC`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, plus `HOME`, `TMPDIR`, `XDG_CACHE_HOME`, `CLANG_MODULE_CACHE_PATH`, and `SWIFTPM_MODULECACHE_OVERRIDE` below that child. Every leaf is wrapped by locked `/usr/bin/sandbox-exec` with profile `(version 1) (allow default) (deny network*) (deny file-write* (require-not (subpath REAL_COMMAND_TEMP)))`. The executor implements parent-record order, all-success short-circuit, connected pipeline streams, aggregate pipefail, timeout with TERM then KILL after 5 seconds, an 8,388,608-byte cap on each leaf's stdout and stderr, exact expected matching, a second Git snapshot, and cleanup of only the command child. Any product repository delta, unclassified evidence path, sandbox denial, stream-cap overflow, timeout, cleanup failure, workspace-token mismatch, or toolchain drift is a finding. It atomically advances only the declared task's `running` evidence JSON through a derived `EVIDENCE_PATH.g6-part` controller transient that must be absent before and after a successful call, and records the executor module hash, sandbox profile hash, parent and leaf results, and before/after product-state hashes; a direct leaf result lacks these fields and fails evidence validation.

`acquireSource` accepts only a plan-selected `SourceAcquisition` and the selected running task-root marker/token. It clears proxy, credential, cookie, authorization, and ambient header inputs; uses Node HTTPS with certificate validation; sets the caller-controlled header set exactly to `Accept: application/octet-stream`, `Accept-Encoding: identity`, and `User-Agent: MonaCode-G6-R-SourceAcquisition/1`; and records the locked Node runtime's generated protocol headers separately. It accepts only status 200 from the declared URL, host, port 443, and exact ordered redirect chain and rejects every other status. It enforces timeout and maximum bytes while streaming to the declared `.g6-part` path, requires an advertised `Content-Length` to equal the expected count when the header exists, and always requires the observed download byte count and SHA-256 exactly. For an archive row it invokes locked `/usr/bin/bsdtar` only on the downloaded partial, validates every entry type and normalized path before extraction, rejects duplicate component keys computed as `normalize('NFC').toLowerCase().normalize('NFC')`, and builds the complete directory/file topology with exclusive create operations in a separate probe root below the same task root and target volume. A collision or non-exclusive node fails before extraction; the probe is removed only through its ownership token. It then requires the exact entry count plus exact/maximum expanded-byte totals, fsyncs the file and parent directory, atomically renames to the declared output, and records status, redirect, header, license, acquisition, archive, collision-key, and probe-result hashes in the same task evidence. A temporary output remains below that task root for same-task operations and is never selected by another task; a task-step output is an exact repository mutation. A pre-existing output passes only when its hash and archive contract match; a pre-existing partial path or any mismatch fails without deletion or promotion.

`commitTask` accepts only a `running` task whose selected Green command has the expected result and whose current stage is `commit`. Using only locked `/usr/bin/git` argument-array invocations, it verifies `HEAD` equals the recorded base, rejects merge/rebase/cherry-pick/bisect state, classifies the worktree as exactly the task product commit-boundary paths plus unchanged tracked prior evidence and the selected untracked current evidence/journal state, proves the current evidence path is not tracked, and initially requires an empty index. Before staging, it writes/fsyncs `EVIDENCE_PATH.g6-committing` with the base, bytewise-sorted boundary, add/modify/delete dispositions, file hashes, author/committer/message, and expected evidence prior hash. Under a matching journal, re-entry accepts only an index containing the exact prefix subset produced by staging those ordered literal product paths, completes `git add -- <PATH>` one path at a time, requires the final `git diff --cached --name-status -z` to equal the declared dispositions, and requires `git diff --name-only -z` to contain no undeclared product path. It invokes Git with `core.hooksPath=/dev/null`, `commit.gpgSign=false`, `--no-verify`, `--no-gpg-sign`, and exact subject `monacode: complete <TASK_ID>`. The closed environment contains the same locale, time-zone, PATH, and developer-directory values as command execution plus only `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, and `GIT_COMMITTER_EMAIL`, all selecting `zhengrenzhe <zhengrenzhe0416@outlook.com>`; it excludes every other inherited `GIT_*`, signing, editor, and askpass variable. Git supplies the UTC author/committer timestamps, and the evidence records them as observations without using them as acceptance selectors. It verifies the new product commit has exactly the recorded base as its sole parent, the selected identity/message, and the exact product-boundary diff; atomically appends the commit hash to running evidence; and removes the committing journal. If `HEAD` is already the exact matching direct single-parent product commit whose parent is the recorded base and the journal matches, re-entry appends or verifies the same evidence result without another commit. It never amends, resets, cleans, or stages an evidence path; the same index or commit state without the matching journal is a finding.

`finalize-evidence` accepts only the exact current task after `commit-task`. It verifies `HEAD` is the product commit with the preflight base as sole parent, exact product identity/message/boundary, unchanged prior evidence under `selectEvidenceCommit`, current evidence untracked, and an empty index; revalidates every running command, acquisition, file, assertion, environment, and mutation result; and validates the task-root realpath, mode-0600 marker, and ownership-token hash. It writes/fsyncs `EVIDENCE_PATH.g6-finalizing` with the authority hashes, product commit/tree, root, token hash, tombstone, prehashed passed bytes, evidence path, evidence subject `evidence(monacode): complete <TASK_ID>`, and evidence identity/parent contract. It atomically renames the root to `<ROOT>.g6-delete-<TOKEN_SHA256>`, removes only that lstat-validated non-symlink tombstone, atomically publishes the passed bytes through `EVIDENCE_PATH.g6-part`, fsyncs the evidence parent, stages exactly the evidence path, verifies the cached diff is one added evidence blob and no journal, and creates the evidence commit with the same closed Git environment/hooks/signing rules as `commit-task`. It verifies that commit's sole parent is the product commit, identity/message match, only diff is the expected evidence path, and its blob bytes equal the prehashed passed bytes; then removes the finalizing journal. At successful current-task finalization `HEAD` is this evidence commit; later task validation selects it through first-parent history rather than requiring it to remain `HEAD`. The passed JSON stores selector mode `external-git` and the product commit but omits its own blob hash and evidence commit ID. Tests stop after every operation and prove a second invocation accepts only the corresponding root/tombstone/journal/passed/index/evidence-commit prefix state and converges to the same evidence commit. Any unrecorded partial, second tombstone, token mismatch, symlink, extra index path, wrong commit, or state combination fails without deletion or another commit. A failed finalization leaves the product commit intact; rerunning against that product commit or its exact evidence-only child is the sole post-product recovery.

- [ ] **Step 4: Run the controller tests**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-executor.test.mjs docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/planctl.test.mjs`

Expected: all executor, source-acquisition, dispatch, sandbox, JSON output, cleanup, and exit-code cases pass; loopback network and outside-root writes are denied.

- [ ] **Step 5: Commit `planctl`**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/command-executor.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/planctl.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-executor.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/planctl.test.mjs
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "feat: add G6-R plan controller"
```

### Task 11: Implement deterministic G5-R task migration and fragment validation

**Files:**
- Create: `Tools/G6PlanAuthoring/lib/migrate-task.mjs`
- Create: `Tools/G6PlanAuthoring/lib/build-fragment.mjs`
- Create: `Tools/G6PlanAuthoring/lib/render-task.mjs`
- Create: `Tools/G6PlanAuthoring/build-fragment.mjs`
- Create: `Tools/G6PlanAuthoring/validate-overrides.mjs`
- Create: `Tools/G6PlanAuthoring/verify-fragment.mjs`
- Create: `Tools/G6PlanAuthoring/tests/migrate-task.test.mjs`

**Interfaces:**
- Produces: `migrateTask({ g5Task, commandConverter, interfaceRows, overrides }): TaskRecord`
- Produces: `buildPhaseFragment({ phase, taskIDs, parentPlan, overrides }): PhaseFragment`
- Produces: `validatePhaseOverrides({ phase, taskIDs, parentPlan, productArtifacts, overrides }): Finding[]`
- Produces: `verifyFragment(fragment, expected): Finding[]`
- Produces: `renderTask(task): string` with a stable task marker containing the canonical task-record hash.
- Produces: `buildCommitMessage(taskID: string): string`, exact result `monacode: complete ${taskID}` after validating the task-ID grammar.
- Produces: `buildEvidenceCommitMessage(taskID: string): string`, exact result `evidence(monacode): complete ${taskID}` after validating the task-ID grammar.

- [ ] **Step 1: Write migration invariance tests**

Use P00-T001 and P01-T001 as controls. Assert preservation of ID, phase, dependencies, contract references, ownership, file rows, completion assertions, and product commit path set. Assert the evidence path differs only by the exact `g5-r` to `g6-r` revision segment and retains its full phase/task suffix. Assert G5 provides no commit-message field; G6 derives exactly `monacode: complete P00-T001` plus `evidence(monacode): complete P00-T001` and the corresponding P01 subjects; and any message/ID, parent, or staged-set mismatch is rejected. Assert exactly seven ordered stages, one task-test contract selecting every Red/Green leaf exactly once, one converted Red command, one converted Green command, and canonical record-hash stability across two runs.

- [ ] **Step 2: Run the migration test and observe missing modules**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/migrate-task.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/migrate-task.mjs`.

- [ ] **Step 3: Implement migration without semantic inference**

```js
export function migrateTask({ g5Task, commandConverter, interfaceRows, overrides }) {
  const task = {
    id: g5Task.id,
    phase: g5Task.phase,
    title: g5Task.title,
    platformScope: [...g5Task.platformScope],
    dependencies: [...g5Task.dependencies].sort(),
    contractRefs: [...g5Task.contractRefs].sort(),
    ownership: [...g5Task.ownership],
    paths: normalizePathRows(g5Task, overrides.paths ?? []),
    interfaces: selectInterfaceRows(g5Task, interfaceRows),
    stages: buildSevenStages(g5Task, commandConverter, overrides, [
      'preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence'
    ]),
    evidence: buildEvidenceContract(g5Task, { fromRevision: 'g5-r', toRevision: 'g6-r' }),
    completion: [...g5Task.completion],
    commits: {
      product: buildProductCommitContract(g5Task),
      evidence: buildEvidenceCommitContract(g5Task)
    }
  };
  return { ...task, recordSha256: recordSha256(task) };
}
```

The converter cannot invent a missing path, interface signature, environment value, mutation, source input, test behavior, or implementation decision. The only automatic product-task path rewrite is the exact evidence-root segment from `artifacts/acceptance-evidence/g5-r/` to `artifacts/acceptance-evidence/g6-r/`; it requires all 200 unique inputs to match the G5 prefix, preserves each remaining suffix byte-for-byte, and rejects collisions. Every migrated task places commit before evidence, keeps the inherited product commit-boundary path set, derives product subject `monacode: complete <TASK_ID>` and evidence subject `evidence(monacode): complete <TASK_ID>` by exact ASCII concatenation, sets both identities to `zhengrenzhe <zhengrenzhe0416@outlook.com>`, prohibits product-stage evidence staging, uses exactly one `planctl commit-task` operation in commit, and ends with exactly one `planctl finalize-evidence` operation that commits only the evidence path. Tasks 12-23 author all other planning decisions explicitly in phase override files; this is G6 plan-contract work and cannot count as product implementation. `validate-overrides.mjs` loads only `g6-r/artifacts/parent/g5-r/artifacts/monacode-g5r-authoritative-manifest.json`, `g6-r/artifacts/parent/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`, and normative files selected by the embedded G5-R checksum index. It requires one row for every selected task, one complete task-test contract selecting every Red/Green leaf, every one of its produced interfaces, and every external or generated input named by an implementation operation. Each task-test row fixes file/checker path, target, symbol or name pattern, fixture values/hashes, assertion IDs/operands/order, Red/Green leaf mapping, output marker, failure class, authoring operation, and source producer. Each interface/operation row contains an exact interface kind, full declaration/schema/command contract, implementation operation record, Red failure class, source artifact path and hash, source JSON pointer or HTML section identity, contract references, and explicit native design decision where the frozen source does not prescribe a Swift spelling. Every local test or implementation source selects one baseline, dependency, or earlier task-step producer. Every remote source supplies the complete `SourceAcquisition` record and is consumed only after its owning acquisition step; undeclared URLs, host inference, ambient package registries, floating versions, and unhashed bytes are invalid. Each of the 139 Swift-Red tasks also contains one exact compile-only scaffold row for every newly created Swift source path, totaling 249. A scaffold contains the full selected declaration, compile-only bodies, and marker `G6_RED_SCAFFOLD:<task-id>:<source-path-sha256>`, where the suffix hashes the UTF-8 bytes of the normalized repository-relative path with `/` separators and no leading `./`; the task test checks all declared source files for that marker and emits the inherited G5 Red marker before executing behavior, while Green requires every scaffold marker absent. Missing rows return `PLAN_OVERRIDE_TASK_MISSING`, `PLAN_TEST_CONTRACT_MISSING`, `PLAN_TEST_LEAF_UNSELECTED`, `PLAN_OVERRIDE_INTERFACE_MISSING`, or `PLAN_SOURCE_INPUT_UNDECLARED`; symbolic-only declarations return `PLAN_INTERFACE_CONTRACT_INCOMPLETE`; scaffold errors return `PLAN_RED_SCAFFOLD_MISSING`, `PLAN_RED_SCAFFOLD_EXTRA`, or `PLAN_RED_SCAFFOLD_ASSERTION`; unused or conflicting rows return `PLAN_OVERRIDE_ROW_UNUSED` or `PLAN_OVERRIDE_ROW_CONFLICT`. Its CLI is `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase PHASE_SELECTOR --path OVERRIDE_PATH`; `PHASE_SELECTOR` is exactly one of `00`, `01`, `02`, `03`, `04`, `05-foundation`, `05-features`, `05-closure`, `06`, `07`, `08`, or `09`. Unknown selectors or flags fail closed.

- [ ] **Step 4: Run migration tests and verify deterministic rendering**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/migrate-task.test.mjs`

Expected: all invariance and hash tests pass; rendering the same task twice produces byte-identical Markdown.

- [ ] **Step 5: Commit migration and fragment tools**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/lib/migrate-task.mjs \
  Tools/G6PlanAuthoring/lib/build-fragment.mjs \
  Tools/G6PlanAuthoring/lib/render-task.mjs \
  Tools/G6PlanAuthoring/build-fragment.mjs \
  Tools/G6PlanAuthoring/validate-overrides.mjs \
  Tools/G6PlanAuthoring/verify-fragment.mjs \
  Tools/G6PlanAuthoring/tests/migrate-task.test.mjs
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "feat: add G6-R plan migration tools"
```

### Task 12: Author and verify the Phase 00 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-00.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-00.json`

**Interfaces:**
- Consumes: Tasks 3-11 and G5-R tasks `P00-T001` through `P00-T012`.
- Produces: 12 task records, 24 command records, 27 produced interface contracts, 14 consumed interface selections, 48 commit paths, and 12 evidence contracts.

- [ ] **Step 1: Run the missing-fragment Red check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 00 --path Tools/G6PlanAuthoring/fragments/phase-00.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=00`.

- [ ] **Step 2: Author and validate the exact Phase 00 overrides**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 00 --path Tools/G6PlanAuthoring/overrides/phase-00.json`

The override file contains exactly 12 task keys. P00-T001 selects the G6 baseline `runtime/assert-package-graph.mjs` for `test-authoring`, Red, and Green. P00-T003 selects its task-step `Tools/PlanChecks/verify-provenance.mjs`. P00-T008 through P00-T011 select the exact test or checker paths already listed in their create rows. Every Swift command receives a temporary scratch path, and every one of the 24 inherited Phase 00 verification commands prohibits network.

P00-T003 declares three `SourceAcquisition` rows owned by task `P00-T003`, stage `implementation`, with scheme `https`, port `443`, output disposition `temporary`, timeout `300000` ms, archive format `tar-gzip`, empty redirect chains, existing-output behavior `require-same-hash`, and distinct extraction roots below `${TASK_TEMP}/sources/extracted/<SOURCE_ID>`:

- `monaco-editor-npm`: `https://registry.npmjs.org/monaco-editor/-/monaco-editor-0.56.0.tgz`, host `registry.npmjs.org`, 18,276,145 expected and maximum download bytes, SHA-256 `b74bc4437205c194b779b0f21e5e7fcd3b4e9acbf3f7c8732a545d2059fb7412`, 1,909 archive entries, 97,911,464 exact and maximum expanded bytes, license identity `P1-R:MIT`, output `${TASK_TEMP}/sources/monaco-editor-0.56.0.tgz`;
- `monaco-editor-core-final-npm`: `https://registry.npmjs.org/monaco-editor-core/-/monaco-editor-core-0.56.0.tgz`, host `registry.npmjs.org`, 6,853,917 expected and maximum download bytes, SHA-256 `78e222c77e7ef6402ea0bfb20e02caad7b63156f5d2798bc3c398a8bb396f4ed`, 2,112 archive entries, 39,830,541 exact and maximum expanded bytes, license identity `P1-R:MIT`, output `${TASK_TEMP}/sources/monaco-editor-core-0.56.0.tgz`;
- `monaco-source-tag`: `https://codeload.github.com/microsoft/monaco-editor/tar.gz/13f0c872dcf352815cc28d92dfff496c9839ea5c`, host `codeload.github.com`, 4,148,536 expected and maximum download bytes, SHA-256 `6f0cbd553b17588af4af5d38d151590b060914e3169043dcbb13e1de2938810a`, 1,293 archive entries containing 993 regular files and 300 directory rows, 21,103,534 exact and maximum expanded bytes, license identity `P1-R:MIT`, output `${TASK_TEMP}/sources/monaco-editor-13f0c872dcf352815cc28d92dfff496c9839ea5c.tar.gz`.

The P00-T003 operation first requires the exact archive-entry counts above, then extracts only inside `${TASK_TEMP}`, rejects absolute paths, parent traversal, symlinks, hard links, devices, duplicate normalized paths, collisions under the exact NFC/lowercase/NFC component key, and collisions in the same-volume exclusive-creation probe, and verifies the inherited npm archive hashes, `package/monaco.d.ts` at 327,877 bytes with SHA-256 `fbbab04ba04224a04b2bc3243e536d1af6e26d14eb00fe8b3177bf3daef8d3f2`, source commit identity, and every selected per-file hash before creating the five declared repository outputs. The Chrome comparator and ICU inputs select the exact Task 1 lock; no browser download occurs in Phase 00. All remaining phase operations select a local producer or author their own complete acquisition row under the same schema.

Expected: `G6_OVERRIDES_VALID phase=00 tasks=12 interfaces=27 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=3 scaffoldPaths=8 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 00 --overrides Tools/G6PlanAuthoring/overrides/phase-00.json --output Tools/G6PlanAuthoring/fragments/phase-00.json`

Expected: `G6_FRAGMENT_WRITTEN phase=00 tasks=12 commands=24 producedInterfaces=27 evidence=12`.

- [ ] **Step 4: Verify Phase 00 counts and executable P00-T001 Red control**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 00 --path Tools/G6PlanAuthoring/fragments/phase-00.json
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs </dev/null
```

Expected: fragment exit 0 with `tasks=12 commands=24 create=42 modify=1 test=6 commit=48 ownership=22 produced=27 consumed=14 evidence=12`; checker exit 1 with `PLAN_PACKAGE_GRAPH_MISSING` and no `MODULE_NOT_FOUND`.

- [ ] **Step 5: Commit the Phase 00 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-00.json \
  Tools/G6PlanAuthoring/fragments/phase-00.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 00 execution fragment"
```

### Task 13: Author and verify the Phase 01 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-01.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-01.json`

**Interfaces:**
- Consumes: Phase 00 fragment and G5-R tasks `P01-T001` through `P01-T013`.
- Produces: 13 task records, 26 commands, 35 produced interface contracts, 16 consumed selections, 44 commit paths, and 13 evidence contracts.

- [ ] **Step 1: Run the missing Phase 01 fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 01 --path Tools/G6PlanAuthoring/fragments/phase-01.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=01`.

- [ ] **Step 2: Author and validate Phase 01 exact contracts and stage overrides**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 01 --path Tools/G6PlanAuthoring/overrides/phase-01.json`

Record exact Swift declarations, JSON schemas, or command contracts for values, events, URI, Piece Tree storage, UTF-16 coordinates, edits, undo, transactions, reconciliation, snapshots, cancellation, lifecycle, and resource ownership. Copy all G5-R behavioral operations and completion assertions without weakening raw UTF-16, atomicity, ordering, version, rollback, or bounded-resource rules.

Expected: `G6_OVERRIDES_VALID phase=01 tasks=13 interfaces=35 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=12 scaffoldPaths=29 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the Phase 01 fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 01 --overrides Tools/G6PlanAuthoring/overrides/phase-01.json --output Tools/G6PlanAuthoring/fragments/phase-01.json`

Expected: `G6_FRAGMENT_WRITTEN phase=01 tasks=13 commands=26 producedInterfaces=35 evidence=13`.

- [ ] **Step 4: Verify Phase 01 exact inventory**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 01 --path Tools/G6PlanAuthoring/fragments/phase-01.json --dependency Tools/G6PlanAuthoring/fragments/phase-00.json`

Expected: exit 0 with `tasks=13 commands=26 create=29 modify=0 test=15 commit=44 ownership=26 produced=35 consumed=16 evidence=13`.

- [ ] **Step 5: Commit the Phase 01 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-01.json \
  Tools/G6PlanAuthoring/fragments/phase-01.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 01 execution fragment"
```

### Task 14: Author and verify the Phase 02 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-02.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-02.json`

**Interfaces:**
- Consumes: Phase 01 fragment and G5-R tasks `P02-T001` through `P02-T009`.
- Produces: 9 task records, 18 commands, 27 produced contracts, 21 consumed selections, 40 commit paths, and 9 evidence contracts.

- [ ] **Step 1: Run the missing Phase 02 fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 02 --path Tools/G6PlanAuthoring/fragments/phase-02.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=02`.

- [ ] **Step 2: Author and validate exact model-semantics contracts**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 02 --path Tools/G6PlanAuthoring/overrides/phase-02.json`

Define exact contracts for positions, ranges, words, search, RegExp profiles, Unicode, EOL, indentation, normalization, and environment-sensitive semantics. Bind every RegExp/Unicode contract to the frozen manifest and comparator oracle. Preserve isolated-surrogate and binary64 semantics.

Expected: `G6_OVERRIDES_VALID phase=02 tasks=9 interfaces=27 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=8 scaffoldPaths=25 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the Phase 02 fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 02 --overrides Tools/G6PlanAuthoring/overrides/phase-02.json --output Tools/G6PlanAuthoring/fragments/phase-02.json`

Expected: `G6_FRAGMENT_WRITTEN phase=02 tasks=9 commands=18 producedInterfaces=27 evidence=9`.

- [ ] **Step 4: Verify Phase 02 inventory and predecessor signatures**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 02 --path Tools/G6PlanAuthoring/fragments/phase-02.json --dependency Tools/G6PlanAuthoring/fragments/phase-01.json`

Expected: exit 0 with `tasks=9 commands=18 create=30 modify=0 test=10 commit=40 ownership=24 produced=27 consumed=21 evidence=9`.

- [ ] **Step 5: Commit the Phase 02 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-02.json \
  Tools/G6PlanAuthoring/fragments/phase-02.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 02 execution fragment"
```

### Task 15: Author and verify the Phase 03 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-03.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-03.json`

**Interfaces:**
- Consumes: Phase 02 fragment and G5-R tasks `P03-T001` through `P03-T012`.
- Produces: 12 task records, 24 commands, 29 produced contracts, 24 consumed selections, 32 commit paths, and 12 evidence contracts.

- [ ] **Step 1: Run the missing Phase 03 fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 03 --path Tools/G6PlanAuthoring/fragments/phase-03.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=03`.

- [ ] **Step 2: Author and validate exact projection, layout, rendering, and Metal-branch contracts**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 03 --path Tools/G6PlanAuthoring/overrides/phase-03.json`

Record Core Text as shaping and geometry authority, Core Graphics as the complete first renderer, and the existing renderer-owned predicate as the only Metal branch selector. Encode both branches, their exact output path sets, the parity join, and the prohibition on later renderer selection.

Expected: `G6_OVERRIDES_VALID phase=03 tasks=12 interfaces=29 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=10 scaffoldPaths=19 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the Phase 03 fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 03 --overrides Tools/G6PlanAuthoring/overrides/phase-03.json --output Tools/G6PlanAuthoring/fragments/phase-03.json`

Expected: `G6_FRAGMENT_WRITTEN phase=03 tasks=12 commands=24 producedInterfaces=29 evidence=12`.

- [ ] **Step 4: Verify inventory and both deterministic renderer states**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 03 --path Tools/G6PlanAuthoring/fragments/phase-03.json --renderer core-graphics
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 03 --path Tools/G6PlanAuthoring/fragments/phase-03.json --renderer core-graphics-plus-metal
```

Expected: both exit 0 with identical task/command/ownership/interface counts and branch-specific final path hashes; summary is `tasks=12 commands=24 create=19 test=13 commit=32 ownership=21 produced=29 consumed=24 evidence=12`.

- [ ] **Step 5: Commit the Phase 03 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-03.json \
  Tools/G6PlanAuthoring/fragments/phase-03.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 03 execution fragment"
```

### Task 16: Author and verify the Phase 04 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-04.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-04.json`

**Interfaces:**
- Consumes: Phase 03 fragment and G5-R tasks `P04-T001` through `P04-T016`.
- Produces: 16 task records, 32 commands, 36 produced contracts, 31 consumed selections, 49 commit paths, and 16 evidence contracts.

- [ ] **Step 1: Run the missing Phase 04 fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 04 --path Tools/G6PlanAuthoring/fragments/phase-04.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=04`.

- [ ] **Step 2: Author and validate native input, transfer, accessibility, and embedding contracts**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 04 --path Tools/G6PlanAuthoring/overrides/phase-04.json`

Define exact AppKit event, IME arbitration, pointer, scrolling, clipboard, drag/drop, Services, accessibility text, selector/action, focus, AppKit view, and SwiftUI lifecycle contracts. Keep all AppKit types outside the Foundation-only product.

Expected: `G6_OVERRIDES_VALID phase=04 tasks=16 interfaces=36 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=15 scaffoldPaths=33 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the Phase 04 fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 04 --overrides Tools/G6PlanAuthoring/overrides/phase-04.json --output Tools/G6PlanAuthoring/fragments/phase-04.json`

Expected: `G6_FRAGMENT_WRITTEN phase=04 tasks=16 commands=32 producedInterfaces=36 evidence=16`.

- [ ] **Step 4: Verify Phase 04 inventory and package boundaries**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 04 --path Tools/G6PlanAuthoring/fragments/phase-04.json --dependency Tools/G6PlanAuthoring/fragments/phase-03.json`

Expected: exit 0 with `tasks=16 commands=32 create=33 modify=0 test=16 commit=49 ownership=32 produced=36 consumed=31 evidence=16` and zero Core/AppKit leakage findings.

- [ ] **Step 5: Commit the Phase 04 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-04.json \
  Tools/G6PlanAuthoring/fragments/phase-04.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 04 execution fragment"
```

### Task 17: Author Phase 05 foundation task contracts

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-05-foundation.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-05-foundation.json`

**Interfaces:**
- Consumes: Phase 04 and exact tasks `P05-T001`, `P05-T002`, `P05-T003`, `P05-T004`, `P05-T005`, `P05-T006`, `P05-T007`, `P05-T008`, `P05-T009`, `P05-T010`, `P05-T011`, `P05-T012`, `P05-T013`.
- Produces: 13 task records, 26 commands, 28 produced contracts, 19 consumed selections, 48 commit paths, and 13 evidence contracts.

- [ ] **Step 1: Run the missing foundation fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 05-foundation --path Tools/G6PlanAuthoring/fragments/phase-05-foundation.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=05-foundation`.

- [ ] **Step 2: Author and validate exact registry and public-surface foundation contracts**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 05-foundation --path Tools/G6PlanAuthoring/overrides/phase-05-foundation.json`

Define commands, actions, keybindings, menus, options, themes, colors, icons, localization, registries, public declaration generation, and native colorization replacement contracts. Preserve F1-R through F1-R5 identity and type semantics.

Expected: `G6_OVERRIDES_VALID phase=05-foundation tasks=13 interfaces=28 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=12 scaffoldPaths=28 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the foundation fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 05-foundation --overrides Tools/G6PlanAuthoring/overrides/phase-05-foundation.json --output Tools/G6PlanAuthoring/fragments/phase-05-foundation.json`

Expected: `G6_FRAGMENT_WRITTEN phase=05-foundation tasks=13 commands=26 producedInterfaces=28 evidence=13`.

- [ ] **Step 4: Verify foundation counts**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 05-foundation --path Tools/G6PlanAuthoring/fragments/phase-05-foundation.json --dependency Tools/G6PlanAuthoring/fragments/phase-04.json`

Expected: exit 0 with `tasks=13 commands=26 create=35 test=13 commit=48 ownership=30 produced=28 consumed=19 evidence=13`.

- [ ] **Step 5: Commit Phase 05 foundation**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-05-foundation.json \
  Tools/G6PlanAuthoring/fragments/phase-05-foundation.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 05 foundation fragment"
```

### Task 18: Author all 62 retained Phase 05 feature task contracts

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-05-features.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-05-features.json`

**Interfaces:**
- Consumes the exact feature task IDs:
  `P05-T100`, `P05-T101`, `P05-T102`, `P05-T103`, `P05-T104`, `P05-T105`, `P05-T106`, `P05-T107`, `P05-T108`, `P05-T109`, `P05-T110`, `P05-T111`, `P05-T112`, `P05-T113`, `P05-T114`, `P05-T115`, `P05-T116`, `P05-T117`, `P05-T118`, `P05-T119`, `P05-T120`, `P05-T121`, `P05-T122`, `P05-T123`, `P05-T124`, `P05-T125`, `P05-T126`, `P05-T127`, `P05-T128`, `P05-T129`, `P05-T130`, `P05-T131`, `P05-T132`, `P05-T133`, `P05-T134`, `P05-T135`, `P05-T136`, `P05-T137`, `P05-T138`, `P05-T139`, `P05-T140`, `P05-T141`, `P05-T142`, `P05-T143`, `P05-T144`, `P05-T145`, `P05-T146`, `P05-T147`, `P05-T148`, `P05-T149`, `P05-T150`, `P05-T151`, `P05-T152`, `P05-T153`, `P05-T154`, `P05-T155`, `P05-T156`, `P05-T157`, `P05-T158`, `P05-T159`, `P05-T160`, `P05-T161`.
- Produces: 62 task records, 124 commands, 62 produced contracts, 4 consumed selections, 124 commit paths, and 62 evidence contracts.

- [ ] **Step 1: Run the missing feature fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 05-features --path Tools/G6PlanAuthoring/fragments/phase-05-features.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=05-features`.

- [ ] **Step 2: Author and validate one exact override row per retained feature**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 05-features --path Tools/G6PlanAuthoring/overrides/phase-05-features.json`

Join every task to one exact retained feature identity from the frozen feature manifest. Each row carries its feature ID, implementation entry point, test name, accessibility disposition, command or registry identity, consumed registry signature hash, produced feature capability hash, and unchanged G5-R completion assertions. Reject aggregate or missing rows.

Expected: `G6_OVERRIDES_VALID phase=05-features tasks=62 interfaces=62 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=62 scaffoldPaths=62 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the feature fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 05-features --overrides Tools/G6PlanAuthoring/overrides/phase-05-features.json --output Tools/G6PlanAuthoring/fragments/phase-05-features.json`

Expected: `G6_FRAGMENT_WRITTEN phase=05-features tasks=62 commands=124 producedInterfaces=62 evidence=62`.

- [ ] **Step 4: Verify exact feature set equality and counts**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 05-features --path Tools/G6PlanAuthoring/fragments/phase-05-features.json --feature-manifest docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-authoritative-manifest.json`

Expected: exit 0 with `tasks=62 commands=124 create=62 test=62 commit=124 ownership=62 produced=62 consumed=4 evidence=62 missingFeatures=0 extraFeatures=0`.

- [ ] **Step 5: Commit all feature task contracts**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-05-features.json \
  Tools/G6PlanAuthoring/fragments/phase-05-features.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R retained feature fragments"
```

### Task 19: Author Phase 05 closure and verify the complete phase

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-05-closure.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-05-closure.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-05.json`

**Interfaces:**
- Consumes: `P05-T190`, `P05-T200`, Phase 05 foundation, and all 62 feature records.
- Produces: complete Phase 05 with 77 tasks, 154 commands, 92 produced contracts, 26 consumed selections, 175 commit paths, and 77 evidence contracts.

- [ ] **Step 1: Run the missing closure fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 05-closure --path Tools/G6PlanAuthoring/fragments/phase-05-closure.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=05-closure`.

- [ ] **Step 2: Author, validate, and build closure records**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 05-closure --path Tools/G6PlanAuthoring/overrides/phase-05-closure.json`

P05-T190 consumes the complete feature set and produces the exact completeness gate. P05-T200 consumes the public-surface foundation, all feature capabilities, and the three native colorization replacements, then produces the Phase 05 closure contract. Build the closure fragment with 2 tasks and 4 commands.

Expected: `G6_OVERRIDES_VALID phase=05-closure tasks=2 interfaces=2 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=0 scaffoldPaths=0 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Merge the three Phase 05 fragments**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 05-closure --overrides Tools/G6PlanAuthoring/overrides/phase-05-closure.json --output Tools/G6PlanAuthoring/fragments/phase-05-closure.json
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --merge-phase 05 --input Tools/G6PlanAuthoring/fragments/phase-05-foundation.json --input Tools/G6PlanAuthoring/fragments/phase-05-features.json --input Tools/G6PlanAuthoring/fragments/phase-05-closure.json --output Tools/G6PlanAuthoring/fragments/phase-05.json
```

Expected: merged task IDs are unique and lexicographically ordered within their dependency topology.

- [ ] **Step 4: Verify complete Phase 05 inventory**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 05 --path Tools/G6PlanAuthoring/fragments/phase-05.json --dependency Tools/G6PlanAuthoring/fragments/phase-04.json`

Expected: exit 0 with `tasks=77 commands=154 create=98 modify=0 test=77 commit=175 ownership=101 produced=92 consumed=26 evidence=77`.

- [ ] **Step 5: Commit Phase 05 closure and merged fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-05-closure.json \
  Tools/G6PlanAuthoring/fragments/phase-05-closure.json \
  Tools/G6PlanAuthoring/fragments/phase-05.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: close G6-R phase 05 execution plan"
```

### Task 20: Author and verify the Phase 06 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-06.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-06.json`

**Interfaces:**
- Consumes: Phase 05 and G5-R tasks `P06-T001` through `P06-T010`.
- Produces: 10 task records, 20 commands, 26 produced contracts, 25 consumed selections, 35 commit paths, and 10 evidence contracts.

- [ ] **Step 1: Run the missing Phase 06 fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 06 --path Tools/G6PlanAuthoring/fragments/phase-06.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=06`.

- [ ] **Step 2: Author and validate provider, LSP, snippet, Markdown, and fallback contracts**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 06 --path Tools/G6PlanAuthoring/overrides/phase-06.json`

Record all 30 provider surfaces, LSP 3.18 framing and wire errors, transport-neutral capability mapping, snippets, Markdown security, and plain-text fallback. Encode zero bundled languages, grammars, snippet catalogs, LSP servers, JavaScript runtimes, and WebViews as explicit production exclusions.

Expected: `G6_OVERRIDES_VALID phase=06 tasks=10 interfaces=26 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=9 scaffoldPaths=24 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the Phase 06 fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 06 --overrides Tools/G6PlanAuthoring/overrides/phase-06.json --output Tools/G6PlanAuthoring/fragments/phase-06.json`

Expected: `G6_FRAGMENT_WRITTEN phase=06 tasks=10 commands=20 producedInterfaces=26 evidence=10`.

- [ ] **Step 4: Verify Phase 06 exact inventory**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 06 --path Tools/G6PlanAuthoring/fragments/phase-06.json --dependency Tools/G6PlanAuthoring/fragments/phase-05.json`

Expected: exit 0 with `tasks=10 commands=20 create=25 modify=0 test=10 commit=35 ownership=19 produced=26 consumed=25 evidence=10` and zero forbidden runtime paths.

- [ ] **Step 5: Commit the Phase 06 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-06.json \
  Tools/G6PlanAuthoring/fragments/phase-06.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 06 execution fragment"
```

### Task 21: Author and verify the Phase 07 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-07.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-07.json`

**Interfaces:**
- Consumes: Phase 06 and G5-R tasks `P07-T001` through `P07-T011`.
- Produces: 11 task records, 22 commands, 26 produced contracts, 32 consumed selections, 36 commit paths, and 11 evidence contracts.

- [ ] **Step 1: Run the missing Phase 07 fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 07 --path Tools/G6PlanAuthoring/fragments/phase-07.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=07`.

- [ ] **Step 2: Author and validate diff, services, host, resource, and source-closure contracts**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 07 --path Tools/G6PlanAuthoring/overrides/phase-07.json`

Define the diff engine, standalone services, WorkspaceEdit, session feedback, native host, opener counts, global lifetime resources, source/runtime/style closure, remaining public views, SwiftUI types, and final public API closure. Preserve the exact public-manifest finalization dependency.

Expected: `G6_OVERRIDES_VALID phase=07 tasks=11 interfaces=26 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=8 scaffoldPaths=21 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the Phase 07 fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 07 --overrides Tools/G6PlanAuthoring/overrides/phase-07.json --output Tools/G6PlanAuthoring/fragments/phase-07.json`

Expected: `G6_FRAGMENT_WRITTEN phase=07 tasks=11 commands=22 producedInterfaces=26 evidence=11`.

- [ ] **Step 4: Verify Phase 07 inventory and source closure**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 07 --path Tools/G6PlanAuthoring/fragments/phase-07.json --dependency Tools/G6PlanAuthoring/fragments/phase-06.json`

Expected: exit 0 with `tasks=11 commands=22 create=24 modify=1 test=11 commit=36 ownership=24 produced=26 consumed=32 evidence=11`.

- [ ] **Step 5: Commit the Phase 07 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-07.json \
  Tools/G6PlanAuthoring/fragments/phase-07.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 07 execution fragment"
```

### Task 22: Author and verify the Phase 08 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-08.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-08.json`

**Interfaces:**
- Consumes exact tasks `P08-T001`, `P08-T002`, `P08-T003`, `P08-T010`, `P08-T011`, `P08-T012`, `P08-T013`, `P08-T014`, `P08-T015`, `P08-T016` and Phase 07 closure.
- Produces: 10 task records, 20 commands, 11 produced contracts, 23 consumed selections, 21 commit paths, and 10 evidence contracts.

- [ ] **Step 1: Run the missing Phase 08 fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 08 --path Tools/G6PlanAuthoring/fragments/phase-08.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=08`.

- [ ] **Step 2: Author and validate release-candidate and six static-manifest contracts**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 08 --path Tools/G6PlanAuthoring/overrides/phase-08.json`

Record package assembly, notices, symbols, resources, links, and finalization of `MonaNativeDeclarationManifest`, `MonaRegExpUnicodeManifest`, `MonaEnvironmentManifest`, `MonaSourceClosureManifest`, `MonaCacheManifest`, and `MonaDistributionManifest`. Every finalizer consumes Phase 07 public/source closure and the Phase 03 renderer branch.

Expected: `G6_OVERRIDES_VALID phase=08 tasks=10 interfaces=11 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=0 scaffoldPaths=0 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the Phase 08 fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 08 --overrides Tools/G6PlanAuthoring/overrides/phase-08.json --output Tools/G6PlanAuthoring/fragments/phase-08.json`

Expected: `G6_FRAGMENT_WRITTEN phase=08 tasks=10 commands=20 producedInterfaces=11 evidence=10`.

- [ ] **Step 4: Verify Phase 08 candidate order**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 08 --path Tools/G6PlanAuthoring/fragments/phase-08.json --dependency Tools/G6PlanAuthoring/fragments/phase-07.json`

Expected: exit 0 with `tasks=10 commands=20 create=11 modify=0 test=10 commit=21 ownership=18 produced=11 consumed=23 evidence=10` and zero candidate-before-producer findings.

- [ ] **Step 5: Commit the Phase 08 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-08.json \
  Tools/G6PlanAuthoring/fragments/phase-08.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 08 execution fragment"
```

### Task 23: Author and verify the Phase 09 execution fragment

**Files:**
- Create: `Tools/G6PlanAuthoring/overrides/phase-09.json`
- Create: `Tools/G6PlanAuthoring/fragments/phase-09.json`

**Interfaces:**
- Consumes exact tasks `P09-T001`, `P09-T002`, `P09-T010`, `P09-T011`, `P09-T012`, `P09-T013`, `P09-T014`, `P09-T015`, `P09-T016`, `P09-T017`, `P09-T018`, `P09-T019`, `P09-T030`, `P09-T031`, `P09-T032`, `P09-T033`, `P09-T034`, `P09-T035`, `P09-T036`, `P09-T037`, `P09-T038`, `P09-T039`, `P09-T040`, `P09-T041`, `P09-T042`, `P09-T043`, `P09-T050`, `P09-T051`, `P09-T052`, `P09-T099` and all Phase 08 candidates.
- Produces: 30 task records, 60 commands, 31 produced contracts, 44 consumed selections, 33 commit paths, and 30 evidence contracts.

- [ ] **Step 1: Run the missing Phase 09 fragment check**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 09 --path Tools/G6PlanAuthoring/fragments/phase-09.json`

Expected: exit 1 with `PLAN_FRAGMENT_MISSING phase=09`.

- [ ] **Step 2: Author and validate qualification, C/P, reliability, and verdict contracts**

After writing the override file described below, run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/validate-overrides.mjs --phase 09 --path Tools/G6PlanAuthoring/overrides/phase-09.json`

Encode fresh `QEnvironmentID`, C01-C10, P00-P13, 60/120 Hz cells, M0/M1/native cells, bootstrap statistics, failure injection, soak, sanitizers, complexity, and the final verdict. Every formal command has timeout `1800000`, consumes zero-external-display qualification, and cannot create or modify product source.

Expected: `G6_OVERRIDES_VALID phase=09 tasks=30 interfaces=31 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=0 scaffoldPaths=0 authoringGaps=0 symbolicOnly=0`.

- [ ] **Step 3: Build the Phase 09 fragment**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/build-fragment.mjs --phase 09 --overrides Tools/G6PlanAuthoring/overrides/phase-09.json --output Tools/G6PlanAuthoring/fragments/phase-09.json`

Expected: `G6_FRAGMENT_WRITTEN phase=09 tasks=30 commands=60 producedInterfaces=31 evidence=30`.

- [ ] **Step 4: Verify Phase 09 inventory and final-verdict ordering**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/verify-fragment.mjs --phase 09 --path Tools/G6PlanAuthoring/fragments/phase-09.json --dependency Tools/G6PlanAuthoring/fragments/phase-08.json`

Expected: exit 0 with `tasks=30 commands=60 create=3 modify=0 test=30 commit=33 ownership=39 produced=31 consumed=44 evidence=30`, `sourceMutations=0`, and `verdictIsLast=true`.

- [ ] **Step 5: Commit the Phase 09 fragment**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/overrides/phase-09.json \
  Tools/G6PlanAuthoring/fragments/phase-09.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: author G6-R phase 09 execution fragment"
```

### Task 24: Assemble the complete plan manifests and render all human documents

**Files:**
- Create: `Tools/G6PlanAuthoring/assemble-plan.mjs`
- Create: `Tools/G6PlanAuthoring/render-plan.mjs`
- Create: `Tools/G6PlanAuthoring/tests/assemble-plan.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-implementation-plan-manifest.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-command-dependency-manifest.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-interface-contract-manifest.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/README.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/00-master-plan.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-00-scaffold-harness.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-01-base-model.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-02-model-semantics.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-03-projection-layout-rendering.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-04-input-transfer-accessibility.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-05-public-surface-features.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-06-language-lsp-snippet-markdown.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-07-diff-services-host-source-closure.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-08-release-candidate-distribution.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-09-acceptance-release-verdict.md`

**Interfaces:**
- Produces: one plan with 200 tasks, 200 task-test contracts, 400 structured verification-command records, 407 structured leaf processes, 200 begin actions, 200 commit actions, 200 finalize actions, 200 product-commit contracts, 200 evidence-commit contracts, the complete deduplicated source-acquisition set, 139 scaffolded tasks, 249 Red-scaffold paths, 340 interface contracts, 3,582 ownership rows, 512 unique product-commit paths, and 200 evidence contracts.
- Produces: `assemblePlan(fragments): ExecutionPlan` and `renderPlan(plan): Map<string, string>`.

- [ ] **Step 1: Write assembly rejection tests**

Reject a missing phase, duplicate task, wrong seven-stage order, missing or duplicate `begin-task`, evidence before the product commit, missing or duplicate `commit-task`, wrong product-commit identity/message/parent/boundary, current evidence staged or tracked before finalization, missing or duplicate finalization, missing or wrong evidence-commit ancestry/identity/message/parent/boundary, a later first-parent commit touching passed evidence, an evidence record containing its own blob hash or evidence-commit ID, missing command, missing implementation source, incomplete acquisition contract, missing interface, duplicate ownership row, Markdown marker drift, and nondeterministic fragment order. Assert the exact final task and phase counts, exactly 200 begin/commit/finalize lifecycle actions, exactly 200 product-commit contracts, exactly 200 evidence-commit contracts, and zero local/remote source gaps.

- [ ] **Step 2: Run assembly tests and observe missing modules**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/assemble-plan.test.mjs`

Expected: exit 1 because `assemble-plan.mjs` does not exist.

- [ ] **Step 3: Implement canonical assembly and rendering**

Load fragments in phase order `00` through `09`, topologically sort all tasks with lexicographic tie-breaking, deduplicate interface, verification-command, and source-acquisition rows by ID, preserve all 3,582 ownership rows from G5-R, compute record hashes, and render every task from its machine record. Require every implementation source reference to select one preceding local producer or one complete acquisition row. Human documents contain no normative content absent from the machine record.

- [ ] **Step 4: Build and verify all complete-plan artifacts**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/assemble-plan.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/render-plan.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/assemble-plan.test.mjs
```

Expected: `G6_PLAN_ASSEMBLED phases=10 tasks=200 testContracts=200 commands=400 leaves=407 beginActions=200 commitActions=200 finalizeActions=200 productCommitContracts=200 evidenceCommitContracts=200 sourceGaps=0 acquisitionGaps=0 scaffoldTasks=139 scaffoldPaths=249 interfaces=340 ownership=3582 evidence=200`; all tests pass; rendering twice changes zero bytes.

- [ ] **Step 5: Commit complete plan manifests and documents**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/assemble-plan.mjs \
  Tools/G6PlanAuthoring/render-plan.mjs \
  Tools/G6PlanAuthoring/tests/assemble-plan.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-implementation-plan-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-command-dependency-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-interface-contract-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/README.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/00-master-plan.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-00-scaffold-harness.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-01-base-model.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-02-model-semantics.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-03-projection-layout-rendering.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-04-input-transfer-accessibility.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-05-public-surface-features.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-06-language-lsp-snippet-markdown.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-07-diff-services-host-source-closure.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-08-release-candidate-distribution.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-09-acceptance-release-verdict.md
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: assemble complete G6-R execution plan"
```

### Task 25: Prove G5-R product-scope equality and author the G6-R contract candidate

**Files:**
- Create: `Tools/G6PlanAuthoring/compare-g5-g6-scope.mjs`
- Create: `Tools/G6PlanAuthoring/tests/scope-delta.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/global-g6r-authoritative-contract.html`

**Interfaces:**
- Produces: `compareFrozenScope(g5, g6): Finding[]`
- After arrays with an `id` field are normalized to ID-keyed objects, the bytewise-sorted permitted pointer prefixes are exactly `/authorityRules/companion`, `/authorityRules/global`, `/authorityRules/hashMismatch`, `/identity/revision`, `/identity/status`, `/machineArtifacts/implementationPlan`, `/parent`, `/planGovernance`, `/schemaVersion`, and `/verificationTools/planVerifier`. No other prefix is permitted.

- [ ] **Step 1: Write scope mutation tests**

Start from a candidate with zero deltas, then mutate one product feature, public count, architecture rule, language exclusion, Metal trigger, correctness gate, performance threshold, platform scope, and qualification predicate. Assert `G6_FORBIDDEN_SCOPE_DELTA` with the exact JSON pointer for each mutation.

- [ ] **Step 2: Run scope tests and observe missing comparator**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/scope-delta.test.mjs`

Expected: exit 1 because `compare-g5-g6-scope.mjs` does not exist.

- [ ] **Step 3: Implement normalized leaf comparison and write the candidate**

Normalize authority arrays by ID, compare every JSON leaf, and accept only the ten bytewise-sorted pointer prefixes listed above. Build the G6 authoritative manifest by copying every non-permitted G5 JSON value exactly and comparing its canonical encoding. Set schema version `3`; revision `G6-R-execution-ready-candidate`; status `design-and-execution-plan-candidate`; and a parent object selecting embedded root `artifacts/parent/g5-r`, revision `G5-R-full-scope-final`, `files=148`, `bytes=4050132`, `checksumRows=144`, checksum-index SHA-256 `b8546da4a43056ca4b0f944ac33c872d0d12fa14fe29e5e296b0eedb10423e8f`, adoption-record SHA-256 `9f2e0e8be14940050bc2d649f2c27cc3237379f31617e019d5f7389943b6513c`, authoritative-manifest SHA-256 `b8f9b31f739d2b5587b3bef1699786cef465af3f7173a1c413d276772c81f94f`, and implementation-plan SHA-256 `114979c5faf1369d1f74a8a3905981c1cbef85b9dd93b6a12f8fc48460e64b5c`. Every unchanged inherited `file`, `path`, or schema reference resolves relative to that embedded parent root; only G6 planning-governance rows resolve relative to the G6 archive root. Replace the normalized `implementationPlan` row with the G6 paths and hashes already produced by Task 24. Replace `planVerifier` with its exact Task 26 destination path, availability state `declared-by-plan`, and producer `Task 26`; candidate mode rejects any other path or producer and Task 33 requires the final file hash. Update only the three authority-rule strings needed to name G6 and its companion. Add `planGovernance` with plan state `execution-ready-candidate`, adoption state `candidate`, implementation `not-started`, release acceptance `not-passed`, 200 task-test contracts, 400 verification commands, 407 leaves, 200 begin actions, 200 commit actions, 200 finalize actions, 200 product-commit contracts, 200 evidence-commit contracts, product-commit subject template `monacode: complete <TASK_ID>`, evidence-commit subject template `evidence(monacode): complete <TASK_ID>`, evidence-commit selector mode `external-git`, workspace lifecycle `token-bound`, the assembled exact source-acquisition count with `sourceGaps=0` and `acquisitionGaps=0`, exact planning artifact paths, and exact authoring-task producers for audit, review, and cold-checkout evidence.

- [ ] **Step 4: Run scope equality and companion consistency tests**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/scope-delta.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/compare-g5-g6-scope.mjs
```

Expected: tests pass; comparator prints `G6_SCOPE_EQUAL forbiddenDeltas=0 permittedDeltasOnly=true`; every value rendered in the HTML companion equals its machine source.

- [ ] **Step 5: Commit the G6 contract candidate**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/compare-g5-g6-scope.mjs \
  Tools/G6PlanAuthoring/tests/scope-delta.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/global-g6r-authoritative-contract.html
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: define MonaCode G6-R contract candidate"
```

### Task 26: Integrate the complete G6-R audit and plan verifier

**Files:**
- Create: `Tools/G6PlanAuthoring/update-payload-index.mjs`
- Create: `Tools/G6PlanAuthoring/tests/payload-index.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/audit.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/ambiguity.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/boundaries.mjs`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/canonical-json.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/coverage.mjs`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/findings.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/graph.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/inventory.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/markdown.mjs`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/planctl.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-audit.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/archive-verifier.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/audit.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/boundaries.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/coverage.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/markdown.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json`

**Interfaces:**
- Produces: `auditPlan({ contract, plan, commands, interfaces, archiveRoot }): AuditResult`
- Produces CLI `update-payload-index.mjs --through-task TASK_NUMBER` for Tasks 26-32 and pure `buildPayloadIndex({ completedThroughTask, overlay }): bytes` for the Task 33 adoption transaction; these are the only payload-index byte producers, derive all 232 row-presence values from the closed producer table, and accept only one exact authoring transition from the closed transition table below.
- Produces one closed authoring mode `verify-plan.mjs --write-audit AUDIT_PATH`: it is valid only at the Task 27 base with the exact Task 27 declared working set other than the not-yet-written audit output and later-refreshed payload index, projects `completedThroughTask=27` plus both outputs in memory, and writes only `AUDIT_PATH`; normal verification has no write flag.
- `AuditResult` contains sorted findings, category counts, inventory counts, topological order, document hashes, command counts, interface counts, simulation hash, and mutation-coverage status.

- [ ] **Step 1: Write integration tests that expose each audit category**

Compose schema, graph, coverage, boundary, ambiguity, verification-command, executor, source-acquisition, path, file-state, interface, mutation, task-workspace, product-commit, evidence-commit, commit-lifecycle, evidence, Markdown, scope, payload-inventory, checksum-index, and adoption-selector checks. Mutate one input per category and assert its category count increments by one while unrelated category counts remain zero. The lifecycle controls mutate a missing begin action, foreign workspace token, wrong product-commit message/identity/parent/boundary, direct Git commit substitution, pre-product-commit finalization, post-product-commit resume, wrong evidence-commit ancestry/message/identity/parent/boundary, premature evidence staging, a later modify/delete/modify-then-restore sequence on passed evidence, and an evidence record containing its own blob hash or evidence-commit ID. The payload-index test asserts exactly 232 final archive rows, exact `gitMode: "100644"` and one authoring-task producer on all 232 rows, exactly 230 checksum payload rows, exact orthogonal `presence` and `checksumDisposition` fields, one `self-index` row without a self-hash, exactly two `hash-cycle-excluded` rows for `SHA256SUMS` and `adoption-record.json`, and exact present/planned counts `223/9` through Task 26, `228/4` through Task 27, `229/3` through Task 28, `230/2` through Tasks 29-32, and `232/0` through Task 33. Mutate the completion cursor, producer, presence, absent/present physical state, byte hash, Git mode, checksum disposition, unknown-path set, HEAD, index state, prior cursor, and every transition dirty-path set; require the exact finding for each and refuse every undeclared diff. The archive test builds a complete synthetic adopted archive in a temporary directory, proves it passes default mode, and proves the real pre-adoption archive returns `G6_ADOPTION_MISSING` while `--candidate` passes.

- [ ] **Step 2: Run integration tests and observe missing audit module**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/audit.test.mjs`

Expected: exit 1 with `ERR_MODULE_NOT_FOUND` for `lib/audit.mjs`.

- [ ] **Step 3: Implement fail-closed audit orchestration**

Port the verified G5-R inventory, graph, coverage, boundary, Markdown, canonical JSON, and finding-order behavior into G6-R without cross-directory imports. Add the new execution-readiness checks, including exactly 200 task-test contracts selecting all 407 Red/Green leaves without duplication, 200 `begin-task`, 200 `commit-task`, 200 `finalize-evidence` actions, 200 product-commit contracts, and 200 evidence-commit contracts; exact product/evidence commit identities, messages, parents, boundaries, first-parent selection, and historical evidence immutability; evidence self-reference prohibition; task-root ownership-token lifecycle; pre-commit retry predicates; and post-commit finalization-only recovery. Replace every Task 10 pre-assembly handler with the production module for its command and retain dependency injection for tests. Implement the payload-index writer from a closed 232-path final-path/producer/mode/checksum-disposition table, require `gitMode: "100644"` for every G6-R archive row, derive `presence` only from `producerTask <= completedThroughTask`, generate the Task 26 index only after every other Task 26 payload is final, and make candidate archive verification require exact present and planned physical path sets plus hashes and modes from that index. The final table contains 232 archive rows, 230 checksum payload rows, one self-index disposition, and two hash-cycle exclusions.

The payload-index CLI requires an empty Git index, the exact expected `HEAD` subject/position from the 35-commit sequence, and one of these complete unstaged path sets before it atomically replaces only the index: no prior index plus every Task 26 declared path except the index for transition `none -> 26`; every Task 27 declared path except the index for `26 -> 27`; only `cold-checkout-preflight.json` for `27 -> 28`; only `adversarial-plan-review.md` for `28 -> 29`, `29 -> 30`, and `30 -> 31`; only `adversarial-plan-review.md` for the first `31 -> 32` transition; and only `cold-checkout-preflight.json` for the second `32 -> 32` transition after the fixed R4 review commit. The CLI rejects target 33. `buildPayloadIndex` accepts target 33 only from the adoption module with the exact cursor-32 base, empty index, Task 33 tool/test dirty set, and seven-path virtual final overlay fixed by Task 33; it performs no write itself. No other target, repeated cursor, partial set, superset, staged path, or HEAD is valid. Each output row is recomputed from regular-file bytes or the exact virtual final bytes and selected Git mode; neither producer trusts a previous row hash.

The Task 27 `--write-audit` mode requires `HEAD` to equal the Task 26 commit, the committed index cursor to equal 26, an empty index, and the unstaged path set to equal the Task 27 declarations other than the not-yet-written audit path and unchanged payload-index path; it projects both the audit output and cursor-27 payload index, writes only the audit path atomically, and refuses every other state or flag combination. `AuditResult.documentHashes` excludes the audit output and payload-index bytes, preventing a hash cycle; normal verification compares the committed audit semantics with a fresh read-only result after the index refresh. `verify-plan.mjs` and `monacode-g6r-audit.mjs` load only G6-R-local authority bytes and exit with their exact finding counts; the audit runs the embedded parent verifier before comparing scope. Create the complete `verify-contract.mjs` once: closed `--candidate` mode verifies parent selections, G6 scope equality, plan verification, payload classification, Git modes, and truthful pre-adoption state; default mode additionally verifies the checksum index and adoption selectors. Default mode returns `G6_ADOPTION_MISSING` until Task 33 writes the two adoption files. No later task changes verifier code.

- [ ] **Step 4: Run all audit unit and integration tests**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/payload-index.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/update-payload-index.mjs --through-task 26
/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/audit.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/archive-verifier.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/boundaries.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/coverage.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/markdown.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-audit.mjs --candidate
```

Expected: the payload-index tests pass in isolated temporary repositories without reading a real index; the writer creates the real cursor-26 index before any real-archive positive control; all remaining tests pass; both verifiers exit 0 with `status=pass findingCount=0 parentFiles=148 parentBytes=4050132 archiveFiles=232 present=223 planned=9 mode100644=232 payloads=230 tasks=200 testContracts=200 commands=400 leaves=407 beginActions=200 commitActions=200 finalizeActions=200 productCommitContracts=200 evidenceCommitContracts=200 sourceGaps=0 acquisitionGaps=0 executor=locked sandbox=locked workspaceLifecycle=locked scaffoldTasks=139 scaffoldPaths=249 interfaces=340 ownership=3582 evidence=200`.

- [ ] **Step 5: Commit the complete audit and verifier**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/update-payload-index.mjs \
  Tools/G6PlanAuthoring/tests/payload-index.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/audit.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/ambiguity.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/boundaries.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/canonical-json.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/coverage.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/findings.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/graph.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/inventory.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/markdown.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/planctl.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-audit.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/archive-verifier.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/audit.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/boundaries.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/coverage.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/markdown.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: integrate G6-R execution audit"
```

### Task 27: Add complete mutation coverage and emit the zero-finding plan audit

**Files:**
- Create: `Tools/G6PlanAuthoring/run-adversarial-round.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/mutation-coverage.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/mutation-fixtures.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-coverage.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/negative-fixtures.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/plan-audit.json`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json`

**Interfaces:**
- Produces: `auditMutationCoverage(ruleIDs, fixtures): Finding[]`
- Produces CLI `run-adversarial-round.mjs --round ROUND --review PATH`, with mutually exclusive read-only flags `--list` and `--verify-only`. `ROUND` is exactly one of `R1`, `R2`, `R3`, or `R4`. Default mode reads the committed attack catalog, executes the selected fixtures, verifies exact finding equality, and appends canonical evidence only when `missed=0`, `unresolved=0`, and every variant has `resolutionCommit: null`; any mismatch emits canonical failure JSON and writes no repository byte. `--list` prints the ordered catalog; `--verify-only` validates an existing review record without changing it.
- The coverage matrix contains exactly the 35 ordered family keys `AF01` through `AF35` fixed by the approved design. The round ledger contains exactly 75 top-level attack IDs—R1=12, R2=22, R3=29, and R4=12—plus one positive control per production audit rule. Every top-level attack selects one or more family keys and owns a closed, non-empty ordered variant array; each distinct `plus`, `or`, slash-delimited, or named bypass case in the design and Tasks 29-32 is a separate variant row with ID `<ATTACK_ID>.V<NNN>`, mutation payload hash, expected finding array, and owning production command. No family key, attack, or variant exists only in prose.

- [ ] **Step 1: Write the mutation-coverage test before the fixture catalog**

The test enumerates production finding IDs exported by all audit modules and asserts exactly one or more negative fixtures for every ID, exact expected finding arrays, and zero fixture IDs without a production rule. It owns the exact ordered family-key set `AF01` through `AF35`, the exact ordered 75-attack key set transcribed from Tasks 29-32, and the ordered required variant-key set transcribed from the approved design and Tasks 29-32. It requires exact equality with the catalog's flattened family, attack, and variant keys and rejects a missing, duplicate, empty, prose-only, or multiply selected row. Every production rule and every attack variant has one positive control and at least one exact negative fixture.

- [ ] **Step 2: Run the test and observe the absent fixture catalog**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-coverage.test.mjs`

Expected: exit 1 with `ENOENT` for `mutation-fixtures.json`.

- [ ] **Step 3: Create typed mutations for every rule**

Implement the mutation-coverage library and the closed R1-R4 runner, then populate the exact attack families from the approved design: local and remote inputs, future/duplicate producers, byte caps and hashes, cwd, shell behavior, globbing, pipefail, all-success order, Node option order, streams, timeout, interaction, sandbox execution, network, source host and redirects, environment, repository mutation, task-root token/lifetime/cleanup, missing/ambiguous task-test contracts and leaf selection, test-before-Red order, missing/extra/unreplaced Red scaffolds, Red compile-failure substitution, file ownership, commit boundary/identity/message/executor, interfaces, task graph, evidence order/staging/recovery/hashes and executor provenance, false states, Metal predicate, scope/threshold drift, ambiguity, Markdown order, checksum or Git-mode omission/drift, and parent-byte mutation. The runner hashes the canonical catalog, executes every selected variant exactly once in catalog order, and reports top-level attack totals separately from `variants`, `passedVariants`, `missingVariants`, and `duplicateVariants`.

- [ ] **Step 4: Run all negative fixtures and write the canonical audit result**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/schema.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-grammar.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-dependencies.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/file-state.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/interfaces.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-policy.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/task-state.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/evidence.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-executor.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/planctl.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/archive-verifier.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/audit.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/boundaries.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/coverage.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/markdown.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-coverage.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/negative-fixtures.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs --write-audit docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/plan-audit.json
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/update-payload-index.mjs --through-task 27
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-audit.mjs --candidate
```

Expected: every positive control passes; every mutation is rejected under its exact finding array; the projected writer and both post-refresh read-only verifiers report `status=pass`, `findingCount=0`, `uncoveredRuleCount=0`, `archiveFiles=232`, `present=228`, and `planned=4` with the fixed inventory totals.

- [ ] **Step 5: Commit mutation coverage and audit evidence**

```sh
/usr/bin/git add -- Tools/G6PlanAuthoring/run-adversarial-round.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/mutation-coverage.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/mutation-fixtures.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-coverage.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/negative-fixtures.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/plan-audit.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: adversarially mutate G6-R plan rules"
```

### Task 28: Reproduce execution readiness from a clean exported checkout

**Files:**
- Create: `Tools/G6PlanAuthoring/cold-checkout-preflight.mjs`
- Create: `Tools/G6PlanAuthoring/tests/cold-checkout-preflight.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/cold-checkout-preflight.json`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json`

**Interfaces:**
- Produces: `runColdCheckoutPreflight({ repoRoot, commit, outputPath, verifyOnly = false }): ColdCheckoutResult`
- Produces CLI modes `--commit COMMIT_OBJECT --output OUTPUT_PATH` for pre-adoption evidence, `--commit COMMIT_OBJECT --repeat 2 --output OUTPUT_PATH` for canonical double-run comparison, and `--commit COMMIT_OBJECT --verify-only` for post-adoption read-only verification.
- `ColdCheckoutResult` records exported commit, payload-index `completedThroughTask`, 232 archive rows, exact present/planned counts, Git blob count/bytes, tar bytes, ten command results, output hashes, finding counts, interface compile result, simulation hash, and cleanup result.

- [ ] **Step 1: Write archive confinement and dirty-tree tests**

Use a temporary Git fixture with nested `100644` and `100755` paths. Assert export uses one explicit commit, recursively enumerates every blob, ignores uncommitted files, removes every inherited `GIT_*` value, sets exact `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_TERMINAL_PROMPT=0`, and `GIT_OPTIONAL_LOCKS=0`, and passes `-c tar.umask=0002` regardless of system/global/local `tar.umask` injection. Require exact verbose-tar mappings `100644 -> -rw-rw-r--`, `100755 -> -rwxrwxr-x`, and directory -> `drwxrwxr-x`. Reject more than 16,384 blobs, a blob over 67,108,864 bytes, aggregate blob bytes over 1,073,741,824, a repository path over 4,096 UTF-8 bytes, a component over 255 UTF-8 bytes, or tar output over 1,342,177,280 bytes before extraction. Also reject symlink/submodule modes, a `100755` mode on any G6-R archive payload, archive traversal, bytewise duplicate paths, exact NFC/lowercase/NFC-key collisions, same-volume exclusive-probe collisions, unexpected tar entry types, missing/extra regular files, missing/extra directory prefixes, extracted-size drift, and extracted Git-blob-ID drift; keep all writes inside the realpath-normalized temporary root, remove only that root, and make `--repeat 2` fail on any canonical field drift other than collection time. Mutate each locked Git, bsdtar, Node, sandbox, xcrun, Swift, Xcode, SDK, system_profiler, Chrome, ICU, OS, and architecture observation and assert the exact toolchain finding.

- [ ] **Step 2: Run the test and observe missing preflight tool**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/cold-checkout-preflight.test.mjs`

Expected: exit 1 because `cold-checkout-preflight.mjs` does not exist.

- [ ] **Step 3: Implement the ten-command clean-checkout sequence**

Use `mkdtemp` and only locked `/usr/bin/git` and `/usr/bin/bsdtar`. Build every Git child environment by discarding inherited `GIT_*` keys and setting exact `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_TERMINAL_PROMPT=0`, and `GIT_OPTIONAL_LOCKS=0`. Resolve `COMMIT_OBJECT` with Git arguments `['rev-parse', '--verify', `${commit}^{commit}`]`; inspect `['ls-tree', '-r', '-l', '-z', '--full-tree', resolvedCommit]` as raw NUL-delimited records, require at most 16,384 blob rows, each declared blob size at most 67,108,864 bytes, and aggregate blob bytes at most 1,073,741,824 before archive generation. Accept only blob modes `100644` and `100755` for the repository as a whole, require exactly `100644` for every materialized path below `docs/contracts/monaco-editor-0.56.0/g6-r/`, and reject mode `120000`, `160000`, every tree record, duplicate path, invalid UTF-8, CR/LF in a path, absolute path, normalized parent traversal, any repository-relative path over 4,096 UTF-8 bytes, any component over 255 UTF-8 bytes, and any collision under the per-component key `component.normalize('NFC').toLowerCase().normalize('NFC')`. Apply the same collision key and length checks to every proper directory prefix. Load the selected commit's payload index and require exactly 232 unique rows, one exact producer task and `gitMode: "100644"` per row, `presence = "present"` exactly when `producerTask <= completedThroughTask`, and `presence = "planned"` otherwise. Require the physical G6-R path set to equal the present rows and exclude every planned row; verify a SHA-256 for every present `checksumDisposition = "sha256"` row, no self-hash for the sole `self-index` row, and exactly two `hash-cycle-excluded` rows owned by Task 33. Spawn Git arguments `['-c', 'tar.umask=0002', 'archive', '--format=tar', resolvedCommit]`, stream stdout to an exclusively created archive file, kill the child on byte 1,342,177,281, and retain no partial after the token-owned cleanup. Before extraction, run both `bsdtar -tf ARCHIVE` and `bsdtar -tvf ARCHIVE` under `LC_ALL=C` with an 8,388,608-byte cap on each stdout/stderr stream, reject CR/LF inside an entry name, require the two line arrays to have identical counts and order, and classify each entry from the first ten mode characters of its paired verbose row. Require exact mappings `100644 -> -rw-rw-r--`, `100755 -> -rwxrwxr-x`, and directory -> `drwxrwxr-x`; reject every other first-ten-character string. Require the bytewise-sorted tar regular-file paths to equal the recursive Git blob paths exactly, and require the bytewise-sorted tar directory paths to equal exactly the unique proper directory prefixes of those blob paths, each normalized without a trailing slash. Reject duplicate or collision-key-equal tar rows and every path/type/mode disagreement. Before extraction, reproduce the full directory/file topology with exclusive create operations under a separate probe root on the same target volume; reject any collision, remove only the token-owned probe, then extract below the realpath-normalized export root. For every extracted regular file, require `lstat` size to equal its `ls-tree -l` size and locked `/usr/bin/git -C REPO hash-object --no-filters -- EXTRACTED_PATH` to equal its selected blob object ID; reject every mismatch before executing exported bytes. Recheck every present G6-R row as a non-executable regular file and every planned row as absent. Use argument-array process spawning for every child and the same closed environment values and controller-owned cache roots as Task 10. Run exactly ten exported-checkout commands: G4 verification; G5 verification; `verify-contract.mjs --candidate`; all G6 tests; `planctl audit`; `planctl simulate`; `planctl preflight --all`; `planctl interfaces compile`; `planctl render`; and `planctl verify-archive --candidate`. Then run source-checkout `git diff --check` as a separately named invariant outside the ten-command array. Record every exit code and SHA-256 of stdout/stderr. In `--verify-only` mode require adopted G6-R, require `completedThroughTask=33`, `present=232`, and `planned=0`, replace candidate invocations with final archive/checksum verification, write no repository file, and reject `--output`. In `--repeat 2` mode execute two fresh exports of the same resolved commit and fail with `G6_COLD_CHECKOUT_NONDETERMINISTIC` unless all canonical fields except collection time are byte-identical.

The exported all-G6-tests command receives the same 17 literal test paths fixed by Task 27 Step 4 in that displayed order. It performs no directory discovery and receives no glob token.

- [ ] **Step 4: Commit current files, then run and record the preflight**

Commit the tool and its tests so the exported commit contains the executable preflight, then confirm an empty status before generating evidence. Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/cold-checkout-preflight.test.mjs
/usr/bin/git add -- Tools/G6PlanAuthoring/cold-checkout-preflight.mjs \
  Tools/G6PlanAuthoring/tests/cold-checkout-preflight.test.mjs
/usr/bin/git diff --cached --check
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: add G6-R clean-checkout preflight"
/usr/bin/git status --porcelain=v1
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/cold-checkout-preflight.mjs --commit HEAD --output docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/cold-checkout-preflight.json
```

Expected: the status command prints nothing before the preflight; the selected commit contains the Task 27 payload index and exactly 228 present plus 4 planned archive rows; the preflight prints `COLD_CHECKOUT_PASS archiveRows=232 present=228 planned=4 commands=10 resourceCaps=pass findings=0 missingInputs=0 interfaceErrors=0 cleanup=pass`.

- [ ] **Step 5: Commit the pre-adoption evidence**

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/update-payload-index.mjs --through-task 28
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs --candidate
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/cold-checkout-preflight.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: reproduce G6-R from clean checkout"
```

### Task 29: Execute adversarial round R1 for authority and scope

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json`

**Interfaces:**
- Produces: R1 record with 12 attacks, `missed=0`, and `unresolvedFindings=0`.

- [ ] **Step 1: Verify the closed R1 attack ledger**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R1 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md --list`

Expected: `G6_ADVERSARIAL_CATALOG round=R1 attacks=12 first=R1-A01 last=R1-A12 consecutive=true`. In order, the IDs cover parent-byte mutation, parent selector drift, archive omission plus Git-mode drift variants, checksum mutation, forbidden product delta, performance relaxation, platform expansion, language-pack insertion, Metal preselection, false product state, cross-revision runtime dependency, and human/machine authority conflict.

- [ ] **Step 2: Execute every R1 mutation and write evidence**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R1 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md`

Expected: `G6_ADVERSARIAL_R1 attacks=12 passed=12 missed=0 unresolved=0 missingVariants=0 duplicateVariants=0 resolutionCommits=0`; `passedVariants` equals `variants`, and the runner records variant ID, input hash, expected finding, observed finding, exit code, output hash, and `resolutionCommit: null` for every mutation.

- [ ] **Step 3: Verify the immutable R1 record**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R1 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md --verify-only`

Expected: `G6_ADVERSARIAL_RECORD_VALID round=R1 attacks=12 missed=0 unresolved=0 missingVariants=0 duplicateVariants=0 resolutionCommits=0`; `passedVariants` equals `variants` and every `resolutionCommit` is null.

- [ ] **Step 4: Refresh the payload index and rerun full plan verification after R1**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/update-payload-index.mjs --through-task 29
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs
```

Expected: the index reports `present=230 planned=2`; verification exits 0 with zero findings and no modified normative bytes.

- [ ] **Step 5: Commit R1 evidence**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: review G6-R authority and scope"
```

### Task 30: Execute adversarial round R2 for graph, files, interfaces, and evidence

**Files:**
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json`

**Interfaces:**
- Produces: R2 record with 22 attacks, `missed=0`, and `unresolvedFindings=0`.

- [ ] **Step 1: Verify the closed R2 attack ledger**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R2 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md --list`

Expected: `G6_ADVERSARIAL_CATALOG round=R2 attacks=22 first=R2-A01 last=R2-A22 consecutive=true`. In order, the IDs attack unknown dependencies, cycles, future producers, duplicate owners, create collisions, pre-create modifications, stage-time missing files, missing Red scaffolds, unreplaced Red scaffolds, conditional-branch leakage, product-commit underreach, product-commit overreach plus direct-Git/identity/message/parent bypass variants, evidence before the product commit, premature current-evidence staging/tracking plus changed, missing, or modify-then-restore prior evidence and evidence-commit ancestry/identity/message/parent/boundary/self-reference variants, missing interface producers, duplicate producers, signature drift, actor-isolation drift, target leakage, evidence-before-producer, stale evidence/workspace hashes plus invalid recovery variants, and false passed states.

- [ ] **Step 2: Execute all R2 mutations and write evidence**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R2 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md`

Expected: `G6_ADVERSARIAL_R2 attacks=22 passed=22 missed=0 unresolved=0 missingVariants=0 duplicateVariants=0 resolutionCommits=0`; `passedVariants` equals `variants`, every `resolutionCommit` is null, and each mutation is routed through its declared `planctl audit`, `planctl simulate`, `planctl finalize-evidence`, or `planctl verify-evidence` owner.

- [ ] **Step 3: Verify the immutable R2 record**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R2 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md --verify-only`

Expected: `G6_ADVERSARIAL_RECORD_VALID round=R2 attacks=22 missed=0 unresolved=0 missingVariants=0 duplicateVariants=0 resolutionCommits=0`; `passedVariants` equals `variants` and every `resolutionCommit` is null.

- [ ] **Step 4: Rerun simulation and interface compilation**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/update-payload-index.mjs --through-task 30
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/planctl.mjs simulate
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/planctl.mjs interfaces compile
```

Expected: the index reports `present=230 planned=2`; both read-only commands exit 0; simulation has zero findings and 200 task hashes; interface validation reports `contracts=340 findings=0`, and every `swift-declaration` row is rendered and type-checked with zero compiler errors.

- [ ] **Step 5: Commit R2 evidence**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: review G6-R graph and state"
```

### Task 31: Execute adversarial round R3 for all structured commands

**Files:**
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json`

**Interfaces:**
- Produces: R3 record with 29 attacks plus 400-command and 407-leaf coverage tables, `missed=0`, and `unresolvedFindings=0`.

- [ ] **Step 1: Verify the closed R3 attack ledger**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R3 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md --list`

Expected: `G6_ADVERSARIAL_CATALOG round=R3 attacks=29 first=R3-A01 last=R3-A29 consecutive=true`. In order, the IDs attack missing executables, missing local inputs, undeclared remote sources, future inputs, duplicate inputs, baseline or source byte/hash drift, wrong cwd, shell substitution, implicit glob, absent pipefail, changed all-success short-circuit order, unnormalized Node test-runner option order, wrong stream expectation, missing timeout, interactive flags, undeclared network, wrong source host, redirect-host escape, environment leakage, repository mutation, task-root escape plus foreign/reused-token and command-child-cleanup variants, missing/ambiguous task-test contract plus unselected/duplicate-leaf and test-after-Red variants, Red compile-failure substitution, unsupported command form, scratch-path omission, wrong expected exit, nondeterministic output matching, direct-leaf evidence substitution, and sandbox profile or executor-hash substitution.

- [ ] **Step 2: Execute mutations, enumerate all command records, and write evidence**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R3 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md`

Expected: `G6_ADVERSARIAL_R3 attacks=29 passed=29 commands=400 covered=400 leaves=407 leavesCovered=407 missing=0 missed=0 unresolved=0 missingVariants=0 duplicateVariants=0 resolutionCommits=0`. `passedVariants` equals `variants`; every `resolutionCommit` is null; the runner records every grammar form, verifies every input source, executes baseline-only controls including P00-T001 Red through `planctl run-command` in an isolated temporary checkout with non-product evidence, and never executes future product tests or live remote acquisitions.

- [ ] **Step 3: Verify the immutable R3 record and coverage**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R3 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md --verify-only`

Expected: `G6_ADVERSARIAL_RECORD_VALID round=R3 attacks=29 commands=400 covered=400 leaves=407 leavesCovered=407 missing=0 missed=0 unresolved=0 missingVariants=0 duplicateVariants=0 resolutionCommits=0`; `passedVariants` equals `variants` and every `resolutionCommit` is null.

- [ ] **Step 4: Refresh the payload index and run all-task preflight**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/update-payload-index.mjs --through-task 31
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/planctl.mjs preflight --all
```

Expected: the index reports `present=230 planned=2`; preflight exits 0 with `tasks=200 testContracts=200 unselectedTestLeaves=0 commands=400 leaves=407 beginActions=200 commitActions=200 finalizeActions=200 productCommitContracts=200 evidenceCommitContracts=200 sourceGaps=0 acquisitionGaps=0 toolchainMismatches=0 executorMismatches=0 workspaceLifecycleMismatches=0 productCommitContractMismatches=0 evidenceCommitContractMismatches=0 qualificationPredicates=validated liveQualificationClaims=0 scaffoldTasks=139 scaffoldPaths=249 unavailableInputs=0 ambiguousInputs=0 unsupportedCommands=0 findings=0`.

- [ ] **Step 5: Commit R3 evidence**

```sh
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: review all G6-R commands"
```

### Task 32: Execute adversarial round R4 for clean-checkout reproduction

**Files:**
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/cold-checkout-preflight.json`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json`

**Interfaces:**
- Produces: R4 record with 12 attacks, fresh clean-checkout evidence, `missed=0`, and `unresolvedFindings=0`.

- [ ] **Step 1: Verify the closed R4 attack ledger**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R4 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md --list`

Expected: `G6_ADVERSARIAL_CATALOG round=R4 attacks=12 first=R4-A01 last=R4-A12 consecutive=true`. In order, the IDs attack dirty-worktree leakage, uncommitted dependency reliance, archive traversal plus blob/path/tar resource-cap overflow, non-recursive blob enumeration, bytewise/NFC-lowercase-key/target-volume probe collisions, G6 Git-mode drift, and tar file/directory/mode/size/blob-ID mismatch variants, missing executable in exported tree, host environment leakage, locale drift, time-zone drift, tool-version drift, temporary-root escape, cleanup overreach, nondeterministic rendering, and second-run hash drift.

- [ ] **Step 2: Execute all R4 mutations in isolated temporary repositories and write evidence**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R4 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md`

Expected: `G6_ADVERSARIAL_R4 attacks=12 passed=12 missed=0 unresolved=0 missingVariants=0 duplicateVariants=0 resolutionCommits=0`; `passedVariants` equals `variants`, every `resolutionCommit` is null, and each variant record contains exact expected and observed findings.

- [ ] **Step 3: Verify and commit the immutable R4 record before replay**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/run-adversarial-round.mjs --round R4 --review docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md --verify-only`

Expected: `G6_ADVERSARIAL_RECORD_VALID round=R4 attacks=12 missed=0 unresolved=0 missingVariants=0 duplicateVariants=0 resolutionCommits=0`; `passedVariants` equals `variants` and every `resolutionCommit` is null. Then run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/update-payload-index.mjs --through-task 32
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/adversarial-plan-review.md \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: review G6-R clean checkout"
```

- [ ] **Step 4: Regenerate clean-checkout evidence twice**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/cold-checkout-preflight.mjs --commit HEAD --repeat 2 --output docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/cold-checkout-preflight.json
```

Expected: `COLD_CHECKOUT_PASS archiveRows=232 present=230 planned=2 repeats=2 commandsPerRun=10 findings=0 deterministic=true cleanup=pass`; command-output hashes, simulation hash, interface hashes, and finding counts are identical.

- [ ] **Step 5: Commit refreshed preflight evidence**

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/update-payload-index.mjs --through-task 32
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs
/usr/bin/git add -- docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/cold-checkout-preflight.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "test: reproduce G6-R adversarially"
```

### Task 33: Build checksums and adopt G6-R with the verified global verifier

**Files:**
- Create: `Tools/G6PlanAuthoring/adopt-g6r.mjs`
- Create: `Tools/G6PlanAuthoring/tests/adopt-g6r.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/SHA256SUMS`
- Create: `docs/contracts/monaco-editor-0.56.0/g6-r/adoption-record.json`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/global-g6r-authoritative-contract.html`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json`
- Modify: `docs/contracts/monaco-editor-0.56.0/g6-r/README.md`
- Modify: `docs/implementation-phases/README.md`

**Interfaces:**
- Produces write CLI `adopt-g6r.mjs --archive PATH --phase-index PATH --revision G6-R-execution-ready-final` and read-only CLI with the same arguments plus `--verify-only`.
- Produces immutable adoption revision `G6-R-execution-ready-final`.
- Produces archive verification of every immutable payload row, selected checksum-index hash, contract hash, plan hash, audit hash, review hash, and cold-checkout hash.

- [ ] **Step 1: Write deterministic adoption-tool tests**

Build a temporary candidate archive fixture. Assert bytewise path sorting, exact checksum scope, exact `gitMode: "100644"` for all 232 payload rows, the two exclusions, exact selected hashes including the repository phase-index hash, refusal to overwrite a non-matching adoption, a repository-file mutation allowlist containing only the authoritative manifest, its HTML companion, payload index, `README.md`, `SHA256SUMS`, `adoption-record.json`, and the supplied phase index, plus one transient journal resolved inside the selected Git directory. Prove the tool computes all seven final byte strings before its first repository-file replacement, the checksum table hashes the projected final payload index, and the adoption record selects that exact checksum-table and phase-index hash. Inject a stop after journal publication and after each of the seven fixed path replacements; rerun must accept only that exact journal prefix, publish the same remaining bytes, remove the journal, and converge to the same final hashes. Mutate the base HEAD, cursor, initial dirty set, journal, publish order, projected byte, archive mode, partial path, phase-index bytes, and already-existing adoption; require the exact finding and no out-of-allowlist write. Mutate one archive mode to `100755` without changing its bytes and require the exact mode finding. Assert that `verify-contract.mjs` is byte-identical before and after adoption. `--verify-only` rejects every write-capable flag combination, compares the supplied phase index with the adoption-record hash, and changes no byte.

- [ ] **Step 2: Run Red controls before the adoption tool exists**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/adopt-g6r.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs --candidate
```

Expected: the test exits 1 with `ERR_MODULE_NOT_FOUND` for `adopt-g6r.mjs`; default verification exits 1 with exactly `G6_ADOPTION_MISSING`; candidate verification exits 0 with zero findings.

- [ ] **Step 3: Implement the adoption tool and generate the final authority**

Require the cursor-32 committed base, empty index, and dirty paths exactly `Tools/G6PlanAuthoring/adopt-g6r.mjs` plus its test. In memory, promote the authoritative manifest to revision `G6-R-execution-ready-final`, status `design-and-execution-plan-adopted`, plan state `execution-ready`, and adoption state `adopted`; fill the exact verifier, audit, review, and cold-checkout hashes; keep implementation `not-started` and release acceptance `not-passed`; regenerate the HTML companion solely from that machine source; finalize `README.md`; and update the phase index to select G6-R as plan authority. Pass those four final byte strings plus virtual final `SHA256SUMS` and adoption-record rows to `buildPayloadIndex({ completedThroughTask: 33, overlay })` and obtain the final cursor-33 index bytes without writing. Generate final `SHA256SUMS` bytes over `README.md`, `verify-contract.mjs`, every file under `artifacts/`, and every file under `implementation-plan`, using the projected final bytes and bytewise relative-path order; include the final payload index and exclude only `SHA256SUMS` and `adoption-record.json`. Generate final `adoption-record.json` bytes selecting that checksum-index SHA-256 plus the exact contract, plan, audit, review, cold-checkout, and projected phase-index hashes.

Before replacing a repository file, resolve the journal with locked Git arguments `['rev-parse', '--path-format=absolute', '--git-path', 'monacode-g6r-adoption-journal.json']`, require its parent to be the selected repository's realpath-normalized Git directory, and write/fsync that non-symlink journal with base commit, cursor, initial path hashes, seven ordered output paths, all seven final byte hashes, and next operation. Atomically replace and fsync the seven paths in this fixed order: authoritative manifest, HTML companion, `README.md`, phase index, payload index, `SHA256SUMS`, adoption record. Set each G6-R output's filesystem mode to map to non-executable Git mode `100644`, verify all final byte hashes, then remove and fsync the journal parent. A retry with the journal accepts only the matching untouched suffix and exact already-published prefix; a retry after journal removal accepts only the complete final output set. Every other partial or pre-existing adoption fails without another write. Step 4 verifies the actual staged Git modes for all 232 rows. Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/adopt-g6r.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/adopt-g6r.mjs --archive docs/contracts/monaco-editor-0.56.0/g6-r --phase-index docs/implementation-phases/README.md --revision G6-R-execution-ready-final
```

Expected: tests pass; the generator prints `G6_ADOPTED revision=G6-R-execution-ready-final archiveFiles=232 present=232 planned=0 mode100644=232 payloads=230 planState=execution-ready tasks=200 testContracts=200 beginActions=200 commitActions=200 finalizeActions=200 productCommitContracts=200 evidenceCommitContracts=200 implementation=not-started`; only the seven allowlisted authority/index paths change and the adoption journal is absent.

- [ ] **Step 4: Run archive mutations, all three contract verifiers, and repository-integration verification**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/archive-verifier.test.mjs
/usr/bin/git add -- Tools/G6PlanAuthoring/adopt-g6r.mjs \
  Tools/G6PlanAuthoring/tests/adopt-g6r.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/SHA256SUMS \
  docs/contracts/monaco-editor-0.56.0/g6-r/adoption-record.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/global-g6r-authoritative-contract.html \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verification/payload-index.json \
  docs/contracts/monaco-editor-0.56.0/g6-r/README.md \
  docs/implementation-phases/README.md
/usr/bin/git diff --cached --check
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/compare-g5-g6-scope.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/adopt-g6r.mjs --archive docs/contracts/monaco-editor-0.56.0/g6-r --phase-index docs/implementation-phases/README.md --revision G6-R-execution-ready-final --verify-only
```

Expected: the adopted positive control passes; mutations of parent bytes, Git mode, contract, plan, command manifest, interface manifest, one phase document, audit, review, cold-checkout evidence, checksum row, adoption selector, and repository phase-index bytes each produce their exact finding. The staged index contains exactly the nine Task 33 paths and records `100644` for every G6-R path. Scope comparison prints `G6_SCOPE_EQUAL forbiddenDeltas=0 permittedDeltasOnly=true`. Every archive and repository-integration verifier exits 0; G6 reports `adopted=true adoptedRevision=G6-R-execution-ready-final planState=execution-ready present=232 planned=0 mode100644=232 implementation=not-started unresolvedFindings=0`.

- [ ] **Step 5: Commit immutable adoption**

```sh
GIT_AUTHOR_NAME=zhengrenzhe GIT_AUTHOR_EMAIL=zhengrenzhe0416@outlook.com GIT_COMMITTER_NAME=zhengrenzhe GIT_COMMITTER_EMAIL=zhengrenzhe0416@outlook.com /usr/bin/git -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --no-verify --no-gpg-sign -m "docs: adopt MonaCode G6-R execution-ready plan"
```

### Task 34: Run independent final verification and hand off truthfully

**Files:**
- Modify: none.

**Interfaces:**
- Consumes: adopted G6-R commit.
- Produces: an evidence-backed handoff with exact commit, branch, test counts, audit counts, and remaining product state.

- [ ] **Step 1: Verify repository and author state**

Run:

```sh
/usr/bin/git status --porcelain=v1
/usr/bin/git log -1 --format='%H%n%an <%ae>%n%cn <%ce>%n%s'
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/lib/baseline.mjs --verify-authoring-range
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/lib/baseline.mjs --observe-display
```

Expected: empty status; the latest commit author and committer are both `zhengrenzhe <zhengrenzhe0416@outlook.com>`; range verification prints `G6_AUTHORING_RANGE plannedCommits=35 resolutionCommits=0 totalCommits=35 authors=1 committers=1 whitespaceErrors=0` and exits 0. No other authoring-range shape is accepted. Display observation exits 0 with integer fields `online`, `internal`, and `external`, equality `external = online - internal`, and the sorted online display names; the value is observational and cannot qualify a product acceptance run.

- [ ] **Step 2: Run every plan and archive test from the adopted commit**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node --test \
  Tools/G6PlanAuthoring/tests/baseline.test.mjs \
  Tools/G6PlanAuthoring/tests/skeleton.test.mjs \
  Tools/G6PlanAuthoring/tests/migrate-task.test.mjs \
  Tools/G6PlanAuthoring/tests/assemble-plan.test.mjs \
  Tools/G6PlanAuthoring/tests/scope-delta.test.mjs \
  Tools/G6PlanAuthoring/tests/payload-index.test.mjs \
  Tools/G6PlanAuthoring/tests/cold-checkout-preflight.test.mjs \
  Tools/G6PlanAuthoring/tests/adopt-g6r.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node --test \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/schema.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-grammar.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-dependencies.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/file-state.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/interfaces.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-policy.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/task-state.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/evidence.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/command-executor.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/planctl.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/archive-verifier.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/audit.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/boundaries.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/coverage.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/markdown.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-coverage.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/negative-fixtures.test.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs
```

Expected: the Node TAP summary reports zero failures, zero skipped tests, zero cancellations, and zero deferred-test directives; plan finding count is zero.

- [ ] **Step 3: Run original and successor contract verifiers**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/adopt-g6r.mjs --archive docs/contracts/monaco-editor-0.56.0/g6-r --phase-index docs/implementation-phases/README.md --revision G6-R-execution-ready-final --verify-only
```

Expected: all exit 0; G4 and G5 selected hashes remain unchanged; G6 is adopted and execution-ready; the repository phase index matches the adoption-record hash and selects G6-R.

- [ ] **Step 4: Repeat cold-checkout and P00-T001 baseline Red proof**

Run:

```sh
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/cold-checkout-preflight.mjs --commit HEAD --verify-only
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/planctl.mjs preflight --task P00-T001
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs </dev/null
```

Expected: cold checkout and task preflight exit 0; the direct package-checker diagnostic exits 1 with `PLAN_PACKAGE_GRAPH_MISSING` and no missing-module error. This diagnostic is not a task command result and does not create product evidence.

- [ ] **Step 5: Report the exact boundary**

Report G6-R plan `execution-ready`, product implementation `not-started`, release acceptance `not-passed`, the exact Step 1 display observation as excluded from formal evidence, and `P00-T001` as the single next task. Do not push, merge, delete the branch, or start product implementation without a separate user instruction.
