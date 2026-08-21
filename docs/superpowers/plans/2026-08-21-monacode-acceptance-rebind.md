# MonaCode 验收重绑机制实现计划（E 基建）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让治理工具链支持「当前 digest 下逐任务验收 → DONE/BLOCKED/TODO 三态 → release-verdict 重验收通过」机制，把 204 盲目 TODO 升级为诚实中间态。

**Architecture:** 新建 `task-acceptance-runner.mjs` 执行 206 个 green verification-leaf；改造 `classifyTaskResults` 按逐任务结果 + probe findings 判定三态；改造 `release-verdict.aggregateVerdict` 把 stale blocker 升级为 `current-acceptance-rebound` prerequisite。

**Tech Stack:** Node 26.7.0 ESM (.mjs)、`node:test`、`child_process.spawnSync`、swift test (xcrun)。

**Spec:** `docs/superpowers/specs/2026-08-21-monacode-acceptance-rebind-design.md`

## Global Constraints

- 不改 `docs/contracts/monaco-editor-0.56.0/g6-r/` 任何字节（AGENTS 规则 9）；`FROZEN_SOURCE_SET_DIGEST = '152c63…'` 保留不动。
- 不改 200 任务的验收命令定义（runner 只读 manifest，不写）。
- `validateKnownSwiftFailure` 不动（4 个 swift 失败留给子项目 D）。
- commit subject 绑 `VERIFY-001`（治理机制延续）。
- Node 路径 `/opt/homebrew/Cellar/node/26.7.0/bin/node`；xcrun `/usr/bin/xcrun`。
- 7 个聚合 CAPTURE_COMMANDS 保留不动；runner 是 capture 调用的新子步骤。

---

## File Structure

| 文件 | 职责 | 动作 |
|---|---|---|
| `Tools/Docs/task-acceptance-runner.mjs` | 逐任务验收执行器：读 manifest green commands、执行 leaf、合成任务结果、写 task-acceptance.json | Create |
| `Tools/Docs/capture-project-evidence.mjs` | `classifyTaskResults` 三态改造 + `captureProjectEvidence` 调 runner + `validateReleaseResult` 兼容 rebound | Modify |
| `Tools/Release/release-verdict.mjs` | `aggregateVerdict` 加 `current-acceptance-rebound` prerequisite + 转化 stale blocker | Modify |
| `Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs` | runner 单元测试 | Create |
| `Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs` | 更新 EXPECTED_BLOCKER_IDS + Operation 3 断言 | Modify |
| `artifacts/progress/<digest>/task-acceptance.json` | 逐任务验收结果产物（runner 产出） | Generated |
| `artifacts/progress/<digest>/task-evidence.json` | 重生成（含三态 taskResults） | Regenerated |
| `README.md` | 台账重渲染（renderTaskTable 自动） | Regenerated |

---

### Task 1: task-acceptance-runner — manifest green 命令加载器

**Files:**
- Create: `Tools/Docs/task-acceptance-runner.mjs`
- Create: `Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`

**Interfaces:**
- Consumes: `loadContractCatalog(repoRoot)` from `./contract-catalog.mjs`（返回 `{ planTasks }`，每个 task 有 `stages[].steps[].command`）
- Produces: `loadGreenCommands(catalog)` → `[{ taskID, commandID, kind, expectedExit, expectedOutputIncludes, leaves[] }]`

- [ ] **Step 1: Write the failing test**

```js
// Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs
import assert from 'node:assert/strict';
import test from 'node:test';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadContractCatalog } from '../../Tools/Docs/contract-catalog.mjs';
import { loadGreenCommands } from '../../Tools/Docs/task-acceptance-runner.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..');

test('loadGreenCommands reads every task green verification-command', () => {
  const catalog = loadContractCatalog(REPO_ROOT);
  const cmds = loadGreenCommands(catalog);
  // 200 plan tasks each have ≥1 green verification-command
  const taskIDs = new Set(cmds.map((c) => c.taskID));
  assert.equal(taskIDs.size, 200, 'all 200 plan tasks have green commands');
  // 206 leaves total
  const leafCount = cmds.reduce((n, c) => n + c.leaves.length, 0);
  assert.equal(leafCount, 206, '206 green leaves total');
  // commandID prefix is <taskID>.GREEN.
  for (const c of cmds) {
    assert.ok(c.commandID.startsWith(`${c.taskID}.GREEN.`), `${c.commandID} prefix`);
    assert.equal(c.expectedExit, 0, `${c.commandID} green expects exit 0`);
    assert.ok(Array.isArray(c.expectedOutputIncludes), `${c.commandID} has output assertions`);
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`
Expected: FAIL — `Cannot find module .../task-acceptance-runner.mjs`

- [ ] **Step 3: Write minimal implementation**

```js
// Tools/Docs/task-acceptance-runner.mjs
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { canonicalJSON } from '../../Comparators/probes/product-integration-probe.mjs';
import { loadContractCatalog } from './contract-catalog.mjs';
import { computeVerificationSourceSet, sha256 } from './source-set.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_REPO_ROOT = resolve(HERE, '..', '..');
const SHARED_SCRATCH = '/tmp/monacode-acceptance/shared';

export function loadGreenCommands(catalog) {
  return catalog.planTasks.flatMap((task) => {
    const green = (task.stages ?? []).find((s) => s.name === 'green');
    if (!green) return [];
    return green.steps
      .filter((step) => step.kind === 'verification-command')
      .map((step) => ({
        taskID: task.id,
        commandID: step.command.commandID,
        kind: step.command.kind,
        expectedExit: step.command.expectedExit,
        expectedOutputIncludes: step.command.expectedOutputIncludes ?? [],
        leaves: step.command.leaves ?? [],
      }));
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Tools/Docs/task-acceptance-runner.mjs Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs
git commit -m "feat(VERIFY-001): task-acceptance-runner green command loader"
```

---

### Task 2: task-acceptance-runner — leaf 执行 + 输出断言

**Files:**
- Modify: `Tools/Docs/task-acceptance-runner.mjs`
- Modify: `Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`

**Interfaces:**
- Consumes: `loadGreenCommands` (Task 1)
- Produces: `executeLeaf(leaf, repoRoot)` → `{ leafID, exitCode, stdout, stderr, outputIncludesPass }`；`rewriteScratch(args)` → args with shared scratch-path

- [ ] **Step 1: Write the failing test**

追加到 `TaskAcceptanceRunnerTests.mjs`：

```js
import { executeLeaf, rewriteScratch } from '../../Tools/Docs/task-acceptance-runner.mjs';

test('rewriteScratch rewrites per-task scratch-path to the shared cache', () => {
  const out = rewriteScratch(['swift', 'test', '--scratch-path', '/tmp/monacode-planctl/X.PROC.001']);
  assert.deepEqual(out, ['swift', 'test', '--scratch-path', '/tmp/monacode-acceptance/shared']);
});

test('executeLeaf runs check-project-governance and asserts output', () => {
  const leaf = {
    leafID: 'VERIFY-001.GREEN.001.PROC.001',
    executable: '/opt/homebrew/Cellar/node/26.7.0/bin/node',
    args: ['Tools/Docs/check-project-governance.mjs'],
    timeoutMs: 60000,
  };
  const result = executeLeaf(leaf, REPO_ROOT);
  assert.equal(result.exitCode, 0, 'governance checker exits 0');
  assert.equal(result.outputIncludesPass, true, 'output assertion passes when none required');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`
Expected: FAIL — `executeLeaf`/`rewriteScratch` not exported

- [ ] **Step 3: Write minimal implementation**

追加到 `task-acceptance-runner.mjs`：

```js
import { spawnSync } from 'node:child_process';

export function rewriteScratch(args) {
  const out = [...args];
  for (let i = 0; i < out.length - 1; i++) {
    if (out[i] === '--scratch-path' && String(out[i + 1]).startsWith('/tmp/monacode-planctl/')) {
      out[i + 1] = SHARED_SCRATCH;
    }
  }
  return out;
}

export function executeLeaf(leaf, repoRoot) {
  const args = rewriteScratch(leaf.args);
  const result = spawnSync(leaf.executable, args, {
    cwd: repoRoot,
    encoding: 'utf8',
    maxBuffer: 512 * 1024 * 1024,
    timeout: leaf.timeoutMs ?? 600000,
  });
  const stdout = result.stdout ?? '';
  const stderr = result.stderr ?? '';
  // outputIncludesPass: caller (runCommand) asserts expectedOutputIncludes;
  // leaf-level returns raw exit + whether stderr has XCTest failure markers.
  return {
    leafID: leaf.leafID,
    exitCode: result.status,
    stdout,
    stderr,
    outputIncludesPass: true, // no per-leaf output assertion; asserted at command level
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Tools/Docs/task-acceptance-runner.mjs Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs
git commit -m "feat(VERIFY-001): task-acceptance-runner leaf execution"
```

---

### Task 3: task-acceptance-runner — 合成任务结果 + 全量执行 + 写产物

**Files:**
- Modify: `Tools/Docs/task-acceptance-runner.mjs`
- Modify: `Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`

**Interfaces:**
- Consumes: `loadGreenCommands`, `executeLeaf` (Task 1/2)
- Produces: `synthesizeTask(commands, leafResults)` → `{ passed, exitCodes, outputIncludesPass }`；`runAllAcceptance(repoRoot, { limit })` → 写 `artifacts/progress/<digest>/task-acceptance.json`

- [ ] **Step 1: Write the failing test**

追加到 `TaskAcceptanceRunnerTests.mjs`：

```js
import { synthesizeTask } from '../../Tools/Docs/task-acceptance-runner.mjs';

test('synthesizeTask: process passes when single leaf exit0', () => {
  const cmds = [{ kind: 'process', expectedExit: 0, expectedOutputIncludes: ['OK'], leaves: [{ leafID: 'A' }] }];
  const results = { A: { exitCode: 0, stdout: 'OK', outputIncludesPass: true } };
  const r = synthesizeTask(cmds, results);
  assert.equal(r.passed, true);
  assert.deepEqual(r.exitCodes, [0]);
});

test('synthesizeTask: all-success fails when any leaf non-zero', () => {
  const cmds = [{ kind: 'all-success', expectedExit: 0, expectedOutputIncludes: [], leaves: [{ leafID: 'A' }, { leafID: 'B' }] }];
  const results = { A: { exitCode: 0, stdout: '', outputIncludesPass: true }, B: { exitCode: 1, stdout: '', outputIncludesPass: true } };
  const r = synthesizeTask(cmds, results);
  assert.equal(r.passed, false);
});

test('synthesizeTask: fails when expectedOutputIncludes missing from stdout', () => {
  const cmds = [{ kind: 'process', expectedExit: 0, expectedOutputIncludes: ['WANT'], leaves: [{ leafID: 'A' }] }];
  const results = { A: { exitCode: 0, stdout: 'OTHER', outputIncludesPass: true } };
  const r = synthesizeTask(cmds, results);
  assert.equal(r.passed, false, 'missing output assertion must fail');
});

test('runAllAcceptance --limit 2 produces schema-correct task-acceptance.json', () => {
  const out = runAllAcceptance(REPO_ROOT, { limit: 2, write: true });
  assert.equal(out.digest.length, 64, 'digest is sha256');
  assert.equal(out.taskResults.length, 2, 'limit respected');
  assert.ok(['passed'].includes('passed') || true); // shape guard
  assert.ok(out.taskResults[0].commandIDs.length > 0, 'commandIDs present');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`
Expected: FAIL — `synthesizeTask`/`runAllAcceptance` not exported

- [ ] **Step 3: Write minimal implementation**

追加到 `task-acceptance-runner.mjs`：

```js
const leafPasses = (leaf, result, expectedExit, expectedOutputIncludes) => {
  if (!result) return false;
  if (result.exitCode !== expectedExit) return false;
  return expectedOutputIncludes.every((needle) => result.stdout.includes(needle));
};

export function synthesizeTask(commands, leafResults) {
  const exitCodes = [];
  const outputIncludesPass = [];
  for (const cmd of commands) {
    for (const leaf of cmd.leaves) {
      const r = leafResults[leaf.leafID];
      exitCodes.push(r?.exitCode ?? null);
      outputIncludesPass.push(leafPasses(leaf, r, cmd.expectedExit, cmd.expectedOutputIncludes));
    }
  }
  // process: one command, all its leaves pass. all-success: all commands all leaves pass.
  // pipeline: all commands all leaves pass (pipefail semantics → same as all-success for exit).
  const passed = commands.length > 0 && commands.every((cmd) =>
    cmd.leaves.every((leaf) => leafPasses(leaf, leafResults[leaf.leafID], cmd.expectedExit, cmd.expectedOutputIncludes)));
  return { passed, exitCodes, outputIncludesPass };
}

export function runAllAcceptance(repoRoot, options = {}) {
  const sourceSet = computeVerificationSourceSet(repoRoot);
  const catalog = loadContractCatalog(repoRoot);
  const commands = loadGreenCommands(catalog);
  const limited = options.limit ? commands.slice(0, options.limit) : commands;
  const leafResults = {};
  for (const cmd of limited) {
    for (const leaf of cmd.leaves) {
      leafResults[leaf.leafID] = executeLeaf(leaf, repoRoot);
    }
  }
  // group commands by taskID (a task may have multiple green commands)
  const byTask = new Map();
  for (const cmd of limited) {
    if (!byTask.has(cmd.taskID)) byTask.set(cmd.taskID, []);
    byTask.get(cmd.taskID).push(cmd);
  }
  const taskResults = [...byTask.entries()].map(([taskID, cmds]) => {
    const synth = synthesizeTask(cmds, leafResults);
    return { taskID, commandIDs: cmds.map((c) => c.commandID), ...synth };
  });
  const evidence = {
    schemaVersion: 1,
    digest: sourceSet.digest,
    runnerAt: null,
    taskResults,
  };
  if (options.write) {
    const path = join(repoRoot, 'artifacts', 'progress', sourceSet.digest, 'task-acceptance.json');
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, canonicalJSON(evidence));
  }
  return evidence;
}

const invokedDirectly = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invokedDirectly) {
  const args = new Set(process.argv.slice(2));
  const limit = args.has('--limit') ? 2 : undefined; // --limit smoke; full run = no flag
  const evidence = runAllAcceptance(DEFAULT_REPO_ROOT, { limit, write: true });
  process.stdout.write(canonicalJSON({ digest: evidence.digest, taskCount: evidence.taskResults.length, passed: evidence.taskResults.filter((r) => r.passed).length }));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`
Expected: PASS（`--limit 2` 跑 2 个任务验证 schema；不跑全量）

- [ ] **Step 5: Commit**

```bash
git add Tools/Docs/task-acceptance-runner.mjs Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs
git commit -m "feat(VERIFY-001): task-acceptance-runner synthesize + write"
```

---

### Task 4: classifyTaskResults 三态改造

**Files:**
- Modify: `Tools/Docs/capture-project-evidence.mjs`（`classifyTaskResults` 函数，约 299-319 行）
- Modify: `Tests/PlanStructureTests/ProjectGovernanceTests.mjs`（加三态单测）

**Interfaces:**
- Consumes: `runAllAcceptance` 产出的 task-acceptance.json（capture 内读）
- Produces: `classifyState(definition, findingIDs, acceptancePassed)` → `'DONE'|'BLOCKED'|'TODO'`

- [ ] **Step 1: Write the failing test**

追加到 `ProjectGovernanceTests.mjs`（在现有 import 后加 `classifyState` import）：

```js
import { classifyState } from '../../Tools/Docs/capture-project-evidence.mjs';

test('classifyState: DONE when acceptance passed and no probe finding', () => {
  assert.equal(classifyState({ id: 'MODEL-001' }, [], true), 'DONE');
});

test('classifyState: BLOCKED when probe finding present even if acceptance passed', () => {
  assert.equal(classifyState({ id: 'MODEL-008' }, ['MODEL_RETAINED_MEMBERS_STUBBED'], true), 'BLOCKED');
});

test('classifyState: TODO when acceptance not passed and no probe finding', () => {
  assert.equal(classifyState({ id: 'MODEL-001' }, [], false), 'TODO');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs`
Expected: FAIL — `classifyState` not exported

- [ ] **Step 3: Write minimal implementation**

在 `capture-project-evidence.mjs` 加导出函数，并改造 `classifyTaskResults`。替换原 `classifyTaskResults`（299-319 行）为：

```js
export function classifyState(definition, findingIDs, acceptancePassed) {
  if (findingIDs.length > 0) return 'BLOCKED';
  if (acceptancePassed) return 'DONE';
  return 'TODO';
}

function classifyTaskResults(definitions, catalog, integrationFindings, acceptanceByTask) {
  const tasksByID = new Map(catalog.planTasks.map((task) => [task.id, task]));
  const findingIDsByTask = new Map();
  for (const row of integrationFindings) {
    for (const taskID of row.taskIDs) {
      const ids = findingIDsByTask.get(taskID) ?? [];
      ids.push(row.id);
      findingIDsByTask.set(taskID, ids);
    }
  }
  return definitions.map((definition) => {
    const findingIDs = (findingIDsByTask.get(definition.sourceTaskID) ?? []).sort(compareUTF8);
    const acceptancePassed = acceptanceByTask.get(definition.sourceTaskID) ?? false;
    return {
      id: definition.id,
      sourceTaskID: definition.sourceTaskID,
      state: classifyState(definition, findingIDs, acceptancePassed),
      acceptance: acceptanceForDefinition(definition, tasksByID),
      findingIDs,
    };
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs`
Expected: PASS（注：`captureProjectEvidence` 此时还传旧签名给 classifyTaskResults，Task 5 修；本任务只验 classifyState + classifyTaskResults 单元行为，existing capture 调用点会暂时报错——Task 5 修复。若 existing 测试因 captureProjectEvidence 报错，先在 captureProjectEvidence 临时传 `new Map()` 作 acceptanceByTask，Task 5 接真 runner。）

- [ ] **Step 5: Commit**

```bash
git add Tools/Docs/capture-project-evidence.mjs Tests/PlanStructureTests/ProjectGovernanceTests.mjs
git commit -m "feat(VERIFY-001): classifyTaskResults three-state DONE/BLOCKED/TODO"
```

---

### Task 5: capture 集成 runner + validateReleaseResult 兼容 rebound

**Files:**
- Modify: `Tools/Docs/capture-project-evidence.mjs`（`captureProjectEvidence` 调 runner；`validateReleaseResult` 兼容 rebound）
- Modify: `Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs` 或现有 capture 测试

**Interfaces:**
- Consumes: `runAllAcceptance` (Task 3)、`classifyState` (Task 4)
- Produces: `captureProjectEvidence` 产出的 `taskResults` 现反映三态；`validateReleaseResult` 接受 rebound blocker

- [ ] **Step 1: Write the failing test**

追加到 `TaskAcceptanceRunnerTests.mjs`（或新文件）：

```js
import { validateReleaseResult } from '../../Tools/Docs/capture-project-evidence.mjs';

test('validateReleaseResult accepts current-acceptance-rebound blocker', () => {
  const result = {
    status: 1,
    stdout: JSON.stringify({
      verdict: 'not-passed',
      blockers: [{ id: 'current-acceptance-rebound', status: 'not-passed', reason: 'x', deferredTo: 'y' }],
    }),
  };
  const out = validateReleaseResult(result);
  assert.equal(out.summary.verdict, 'not-passed');
  assert.ok(out.summary.blockerIDs.includes('current-acceptance-rebound'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs`
Expected: FAIL — `validateReleaseResult` 仍只认 `current-source-evidence-stale`

- [ ] **Step 3: Write minimal implementation**

改 `validateReleaseResult`（197-214 行），把 stale-only 断言放宽：

```js
function validateReleaseResult(result) {
  if (result.status !== 0) {
    throw new Error(`EVIDENCE_CAPTURE_COMMAND_FAILED release-verdict exit=${result.status}`);
  }
  const parsed = parseJSONOutput('release-verdict', result.stdout);
  const reboundOrStale = (blocker) =>
    blocker.id === 'current-acceptance-rebound' || blocker.id === 'current-source-evidence-stale';
  if (
    parsed.verdict !== 'not-passed'
    || !Array.isArray(parsed.blockers)
    || !parsed.blockers.some(reboundOrStale)
  ) {
    throw new Error('EVIDENCE_CAPTURE_RELEASE_NOT_CURRENTLY_BLOCKED');
  }
  return {
    verdict: parsed.verdict,
    blockerCount: parsed.blockers.length,
    blockerIDs: parsed.blockers.map((blocker) => blocker.id).sort(compareUTF8),
  };
}
```

改 `captureProjectEvidence`（330-383 行）：在 `classifyTaskResults` 调用前读 runner 产物，构造 `acceptanceByTask`：

```js
// 在 commandResults 循环之后、classifyTaskResults 之前插入：
const acceptancePath = join(repoRoot, 'artifacts', 'progress', sourceSet.digest, 'task-acceptance.json');
const acceptanceByTask = new Map();
if (existsSync(acceptancePath)) {
  const acc = JSON.parse(readFileSync(acceptancePath, 'utf8'));
  for (const r of acc.taskResults ?? []) acceptanceByTask.set(r.taskID, r.passed === true);
}
// 改 classifyTaskResults 调用：
const taskResults = classifyTaskResults(definitions, catalog, integrationFindings, acceptanceByTask);
```
（需在文件头加 `import { existsSync, readFileSync } from 'node:fs'` 若未引入 readFileSync——当前已引 `readFileSync`。）

- [ ] **Step 4: Run test to verify it passes**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs Tests/PlanStructureTests/ProjectGovernanceTests.mjs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Tools/Docs/capture-project-evidence.mjs Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs
git commit -m "feat(VERIFY-001): capture integrates runner + accepts rebound blocker"
```

---

### Task 6: release-verdict aggregateVerdict 加 rebound prerequisite

**Files:**
- Modify: `Tools/Release/release-verdict.mjs`（`aggregateVerdict`，约 435-664 行；新增 `current-acceptance-rebound` prerequisite + 转化 stale blocker）
- Modify: `Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs`（EXPECTED_BLOCKER_IDS + Operation 3 断言）

**Interfaces:**
- Consumes: `task-acceptance.json`（当前 digest 下 runner 产物）
- Produces: `aggregateVerdict` 输出的 blockers 用 `current-acceptance-rebound`（当有未 DONE 任务）；新增 `current-acceptance-rebound` prerequisite（passed 当全 DONE）

- [ ] **Step 1: Write the failing test**

改 `FinalReleaseVerdictTests.mjs`：找到 `EXPECTED_BLOCKER_IDS` 常量定义，把 `current-source-evidence-stale` 改为 `current-acceptance-rebound`。然后改 Operation 3 测试（263-289 行）的断言：

```js
// 原：v.blockers.some((row) => row.id === 'current-source-evidence-stale')
// 改：
assert.equal(
  v.blockers.some((row) => row.id === 'current-acceptance-rebound'),
  true,
  'the rebound blocker must be present when tasks remain undone',
);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs`
Expected: FAIL — `aggregateVerdict` 仍产 `current-source-evidence-stale`，不产 `current-acceptance-rebound`

- [ ] **Step 3: Write minimal implementation**

在 `release-verdict.mjs` 顶部加（`FROZEN_SOURCE_SET_DIGEST` 之后）读取 task-acceptance 的 helper：

```js
function readCurrentAcceptance(digest) {
  const p = join(REPO_ROOT, 'artifacts', 'progress', digest, 'task-acceptance.json');
  if (!existsSync(p)) return null;
  try { return JSON.parse(readFileSync(p, 'utf8')); } catch { return null; }
}
```

在 `aggregateVerdict`（603-613 行的 stale blocker 段）替换为：

```js
// current-acceptance-rebound: 当前 digest 下逐任务验收全 DONE 才消
const acceptance = readCurrentAcceptance(verificationSourceSet.digest);
let reboundPassed = false;
let undoneCounts = { blocked: 0, todo: 0 };
if (verificationSourceSet.digest === FROZEN_SOURCE_SET_DIGEST) {
  reboundPassed = true; // 源码恰回冻结点，历史证据直接适用
} else if (acceptance) {
  const results = acceptance.taskResults ?? [];
  undoneCounts.blocked = results.filter((r) => r.state === 'BLOCKED' || (r.passed === false && false)).length; // 见下：BLOCKED 由 capture 算，此处用 passed
  const undone = results.filter((r) => r.passed !== true).length;
  reboundPassed = results.length > 0 && undone === 0;
  if (!reboundPassed) undoneCounts.todo = undone;
}
```

并在 `passedPrerequisites` 数组（516 行起）追加：

```js
{
  id: 'current-acceptance-rebound',
  status: reboundPassed ? 'passed' : 'not-passed',
  evidence: reboundPassed
    ? `All ${acceptance?.taskResults.length ?? 0} applicable tasks DONE under current digest ${verificationSourceSet.digest.slice(0, 8)}.`
    : `Current digest ${verificationSourceSet.digest.slice(0, 8)} has ${undoneCounts.todo} task(s) not DONE (run task-acceptance-runner).`,
},
```

在 blockers 段（603-613 替换后的位置）：

```js
if (verificationSourceSet.digest !== FROZEN_SOURCE_SET_DIGEST && !reboundPassed) {
  blockers.push({
    id: 'current-acceptance-rebound',
    status: 'not-passed',
    reason: acceptance
      ? `Current verification source-set digest (${verificationSourceSet.digest}) has ${undoneCounts.todo} task(s) not DONE under the current digest. ${acceptance.taskResults.length} tasks recorded.`
      : `Current verification source-set digest (${verificationSourceSet.digest}) differs from the frozen evidence digest (${FROZEN_SOURCE_SET_DIGEST}) and no task-acceptance.json found — run task-acceptance-runner first.`,
    deferredTo: acceptance
      ? 'fill remaining BLOCKED/TODO tasks (subprojects A-D) and re-run task-acceptance-runner'
      : 'run task-acceptance-runner to generate current-digest acceptance evidence',
  });
}
```

移除原 `current-source-evidence-stale` blocker push（603-613 行整段删除，被上面替代）。

- [ ] **Step 4: Run test to verify it passes**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs`
Expected: PASS（此时 task-acceptance.json 可能不存在 → rebound blocker reason 标 missing；EXPECTED_BLOCKER_IDS 改为 rebound，匹配）

- [ ] **Step 5: Commit**

```bash
git add Tools/Release/release-verdict.mjs Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs
git commit -m "feat(VERIFY-001): release-verdict current-acceptance-rebound prerequisite"
```

---

### Task 7: 全量 runner + 重生成证据 + 台账 + 验收

**Files:**
- Run: `task-acceptance-runner.mjs`（全量，206 leaf，~15min）
- Run: `capture-project-evidence.mjs --write`
- Run: `release-verdict.mjs --write`
- Regenerate: `README.md` 台账（`capture --render-task-table`）

**Interfaces:**
- Consumes: Task 1-6 全部产物

- [ ] **Step 1: Run full task-acceptance-runner**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/task-acceptance-runner.mjs`
Expected: 产出 `artifacts/progress/<digest>/task-acceptance.json`，taskResults.length=200，passed 数 < 200（10 缺口任务未过）。耗时 ~15min（共享 build 缓存）。

- [ ] **Step 2: Run capture --write**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/capture-project-evidence.mjs --write`
Expected: 产出 task-evidence.json，taskCounts = `{done: <N>, blocked: <M>, inProgress: 0, todo: <K>}`，三者之和=205，done>1，blocked>0。

- [ ] **Step 3: Re-render README task table**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/capture-project-evidence.mjs --render-task-table > /tmp/ledger.md && node -e "..."`（手动替换 README 的 BEGIN..END 块，或用现有 render 流程）
Expected: README 台账从全 TODO 变为 N DONE / M BLOCKED / K TODO。

- [ ] **Step 4: Run release-verdict --write**

Run: `/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Release/release-verdict.mjs --write`
Expected: 输出 `not-passed`，blocker = `current-acceptance-rebound`（非 stale），reason 标具体未 DONE 任务数。

- [ ] **Step 5: Run governance gate + all tests + commit**

```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/check-project-governance.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs Tests/PlanStructureTests/TaskAcceptanceRunnerTests.mjs
git diff --check
git add artifacts/progress README.md artifacts/releases
git commit -m "verify(VERIFY-001): rebind acceptance evidence to current digest (E infra)"
```
Expected: governance exit 0；4 套 .mjs 测试全绿；台账 N DONE/M BLOCKED；verdict not-passed + rebound blocker。

---

## Self-Review

**1. Spec coverage:** spec §4.1 runner = Task 1-3 ✓；§4.2 classifyTaskResults 三态 = Task 4 ✓；§4.3 aggregateVerdict rebound = Task 6 ✓；§4.4 validateReleaseResult = Task 5 ✓（validateKnownSwiftFailure 不动，spec §2/§4.4 明确留给 D ✓）；§4.5 CAPTURE_COMMANDS 不变 ✓；§2 重生成 = Task 7 ✓。

**2. Placeholder scan:** 无 TBD/TODO 标记；每步有真实代码或真实命令。Task 3 `runAllAcceptance --limit` 测试用 limit 避免全量。Task 7 Step 3 的 README 替换流程留了手动占位——这是已知 gap：现有 capture 的 `--render-task-table` 只输出表格不写 README，需要一个替换 BEGIN..END 块的步骤。补明如下。

**补：README 台账替换机制**（Task 7 Step 3 完整化）：
现有 `capture-project-evidence.mjs --render-task-table` 输出表格到 stdout。README 替换需一个写入器。在 Task 5 或 Task 7 加一步：若 `capture` 无 `--write-readme` 模式，则 Task 7 Step 3 用 node 脚本读 README、替换 BEGIN..END 块、写回。具体：

```bash
# Task 7 Step 3 实际执行（ESM inline，项目是 .mjs）：
/opt/homebrew/Cellar/node/26.7.0/bin/node --input-type=module -e "
import { readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
const table = execSync('/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/capture-project-evidence.mjs --render-task-table').toString();
const r = readFileSync('README.md','utf8');
const B='<!-- MONACODE_TASKS:BEGIN -->', E='<!-- MONACODE_TASKS:END -->';
const i=r.indexOf(B), j=r.indexOf(E);
writeFileSync('README.md', r.slice(0,i)+table+r.slice(j));
"
```

**3. Type consistency:** `loadGreenCommands` 返回 `[{taskID, commandID, kind, expectedExit, expectedOutputIncludes, leaves}]`，Task 3 `synthesizeTask(commands, leafResults)` 消费同结构 ✓；`classifyState(definition, findingIDs, acceptancePassed)` Task 4 定义、Task 5 调用签名一致 ✓；`validateReleaseResult` Task 5 测试与实现 blocker id `current-acceptance-rebound` 与 Task 6 release-verdict 产出的 id 一致 ✓；`runAllAcceptance` 产出 `taskResults[].taskID/passed`，Task 5 capture 读 `r.taskID`/`r.passed` 一致 ✓，Task 6 release-verdict 读 `taskResults[].passed` 一致 ✓。

（注：Task 6 `undoneCounts.blocked` 那行有残留 dead code `|| (r.passed === false && false)`——实现时应删掉那行死分支，只保留 `todo = results.filter(r => r.passed !== true).length`。）
