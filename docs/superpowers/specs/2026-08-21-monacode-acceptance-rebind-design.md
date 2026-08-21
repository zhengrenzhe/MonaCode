# MonaCode 验收重绑机制设计（E 基建）

> 本文件是设计文档（design spec），属证据/历史，**非当前进展权威**。当前进展权威为 [README 任务台账](../../../README.md#tasks)；贡献者规则见 [AGENTS.md](../../../AGENTS.md)。

## 1. 背景与动机

VERIFY-001 治理迁移（2026-08-20）建立了 README 单一真源 + 机器解析任务台账，但只落了「治理框架」本身：

- **台账 1 DONE / 204 TODO**。根因不是「证据没收集」，而是 `Tools/Docs/capture-project-evidence.mjs` 的 `classifyTaskResults` 把非 VERIFY-001 任务**硬编码为 TODO**，与证据无关。
- **发布裁决 `not-passed`**，唯一阻塞项 `current-source-evidence-stale`。根因是 `Tools/Release/release-verdict.mjs` 第 603 行死比硬编码常量 `FROZEN_SOURCE_SET_DIGEST = '152c63…'`（P07-T011 冻结点）：源码一动，当前摘要就 ≠ 它，verdict 必然 not-passed。
- **product-integration-probe 报 11 个 finding**，其中 10 个是真实产品缺口（model stubs、marker service 缺失、diff factory 抛错、cursor/widget/language protocol 空壳、feature activation 路径缺失、sample host 未激活 diff 等），覆盖 P01/P02/P03/P04/P05/P06/P07 多个任务。

经用户裁决：走「方案 2——补完重验收机制」——**保留 152c63 作为 P07-T011 历史冻结点不动**（合规 AGENTS 规则 9，不改 G6-R 冻结字节），补完 release-verdict 缺的「当前 digest 下新鲜 acceptance 证据即通过」机制 + classifyTaskResults 缺的「逐任务按验收命令结果判定 DONE」机制。本设计是「全做（分阶段）」的**第 1 层基建**，后续子项目 A–D（实现 10 个产品缺口）依赖本层提供的统一判据。

## 2. 范围

**在范围内（本设计交付）：**
1. 新建逐任务验收执行器 `Tools/Docs/task-acceptance-runner.mjs`。
2. 改造 `capture-project-evidence.mjs` 的 `classifyTaskResults`：按逐任务验收结果 + probe findings 判定 DONE/BLOCKED/TODO。
3. 改造 `release-verdict.mjs` 的 `aggregateVerdict`：把 `current-source-evidence-stale` 从「死比常量」升级为「当前 digest 下逐任务全 DONE 即消」，新增 `current-acceptance-rebound` prerequisite。
4. 调整 capture 的前置校验函数（`validateReleaseResult`、`validateKnownSwiftFailure`）以适配新语义。
5. 更新受影响的 `.mjs` 测试：`ProjectGovernanceTests`、`FinalReleaseVerdictTests`、`ProductIntegrationProbeTests`。
6. 重生成 `task-evidence.json`、README 台账、RELEASE_VERDICT，得到「N DONE / M BLOCKED」诚实中间态。

**不在范围内（后续子项目，本设计不实现）：**
- 10 个真实产品缺口的 Swift 实现（子项目 A model / B 服务接线 / C API payload / D sample host）。
- 4 个 swift 失败（`testSampleHostActivatesThreeProducts`）的修复——属子项目 D。本设计阶段 swift 仍 4 失败，`validateKnownSwiftFailure` 保持「期望恰好 4 失败」不变；逐任务 runner 跑 P07-T009/T010 的验收命令会 fail → 这些任务诚实标 BLOCKED/TODO。

**完成定义（本设计本身的验收）：**
- `node Tools/Docs/check-project-governance.mjs` ⇒ exit 0（台账合规）。
- `node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs` ⇒ 全绿。
- `node Tools/Docs/capture-project-evidence.mjs --write` 产出当前 digest 的 task-evidence.json，taskCounts 反映真实状态（done>1、blocked>0、todo>0，三者之和=205）。
- `node Tools/Release/release-verdict.mjs` 输出 `not-passed`，但 blocker 从笼统的 `current-source-evidence-stale` 转为反映真实 BLOCKED 任务集的 `current-acceptance-rebound`（语义升级，状态仍 not-passed 是诚实的——因为 10 缺口未实现）。

## 3. 数据来源（已确认）

- **逐任务验收命令**：`docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-implementation-plan-manifest.json`。
  - 顶层 `commands`：400 条命令数组，每条 `{commandID, kind(pipeline|process|all-success), networkMode:forbidden, timeoutMs, stage, expectedExit, expectedOutputIncludes[], leaves[], failureClass, pipefail}`。
  - `tasks[].stages[name=green].steps[kind=verification-command]`：200/200 任务都有，共 206 个 leaf。
  - 任务 ↔ 命令映射：commandID 前缀 `<planTaskID>.GREEN.<n>`（如 `P01-T001.GREEN.001`）。
- **probe findings**：`Comparators/probes/product-integration-probe.mjs` 输出的 `findings[].taskIDs`（plan task ID，如 `P01-T008`）。
- **definition ↔ plan task**：`contract-catalog.mjs` 的 `deriveProjectTaskDefinitions` 已建立 `definition.sourceTaskID ↔ planTaskID` 映射；`classifyTaskResults` 已有 `findingIDsByTask`（按 sourceTaskID 聚合 finding）逻辑，可复用。

## 4. 核心设计

### 4.1 新建 `Tools/Docs/task-acceptance-runner.mjs`

职责：在当前验证源码集摘要下，逐个执行每个任务的 green verification-command，产出逐任务验收结果。

**输入**：repoRoot。
**流程**：
1. `computeVerificationSourceSet(repoRoot)` 取当前 digest。
2. `loadContractCatalog(repoRoot)` 取 plan tasks；对每个 `definition`（含 VERIFY-001 与 200 plan 任务 + MOBILE 任务），取其 green verification-command。
   - VERIFY-001：验收命令 = `node Tools/Docs/check-project-governance.mjs ⇒ exit 0`（沿用 `acceptanceForDefinition` 的特例）。
   - MOBILE 任务：验收命令 = `/usr/bin/test -d Sources/MonaCodeMobile ⇒ exit 0`（沿用特例）。
   - 其余 200 任务：从 plan task 的 green steps 取 `verification-command`（可能多条，kind=pipeline/all-success/process）。
3. 执行每个命令的 `leaves`（206 个 leaf）：
   - **共享 build 缓存**：swift 类 leaf 用统一 `--scratch-path /tmp/monacode-acceptance/shared`（非 manifest 的每任务独立 scratch-path），复用增量编译，把 200 次 swift 启动压到 ~15min 量级。牺牲 manifest 的「每任务隔离 build 确定性」，换取验收期可行性——这是验收证据收集，非 build 确定性验证。
   - **并行**：按 leaf 间的 `dependencies`（从 task.dependencies）拓扑排序，无依赖关系的 leaf 并发（受 CPU 上限约束）。
   - **断言**：每个 leaf 记录 `exitCode`；对 `expectedOutputIncludes` 逐条做子串断言。
4. **合成任务级结果**：
   - process（单 leaf）：leaf exit==expectedExit 且所有 expectedOutputIncludes 命中 → 任务验收通过。
   - all-success（多 leaf）：所有 leaf 通过 → 任务通过。
   - pipeline（多 leaf 管道）：按管道语义（stdout 链）判定，全部 expectedExit + expectedOutputIncludes 命中 → 通过。
**输出**：`artifacts/progress/<digest>/task-acceptance.json`，schema：
```json
{
  "schemaVersion": 1,
  "digest": "<当前 digest>",
  "runnerAt": null,
  "taskResults": [
    { "id": "MODEL-001", "sourceTaskID": "P01-T001",
      "commandIDs": ["P01-T001.GREEN.001"],
      "passed": true, "exitCodes": [0], "outputIncludesPass": [true] }
  ]
}
```
> 时间戳字段 `runnerAt` 设计为 nullable：runner 是普通 node CLI（非 workflow 脚本），可用 `new Date()`，但为可重现默认写 `null`，由需要时间戳的调用方注入。

### 4.2 改造 `classifyTaskResults`（capture-project-evidence.mjs）

当前（312 行）：
```js
state: definition.id === 'VERIFY-001'
  ? (governanceComplete ? 'DONE' : 'IN PROGRESS')
  : 'TODO',
```
改造为：
```js
function classifyState(definition, acceptance, findingIDs, acceptanceResult) {
  // VERIFY-001 不再特殊判定，统一走逐任务机制
  const passed = acceptanceResult?.passed === true;
  if (findingIDs.length > 0) return 'BLOCKED';   // probe 报了真实缺口
  if (passed) return 'DONE';                       // 验收命令全过且无 probe finding
  return 'TODO';                                   // 验收命令未过且无 probe finding
}
```
- DONE：验收命令 exit0+输出含 **且** probe 无对应 finding。
- BLOCKED：probe 报了对应 finding（无论验收命令是否过——probe finding 说明行为缺口未填，按完成定义第 4 条不算完成）。
- TODO：验收命令未过 **且** 无 probe finding（可能是验收命令本身失败、或 leaf 未跑）。
- 移除 `governanceComplete` 参数与 `--governance-complete` flag 的特殊判定路径；VERIFY-001 改由其验收命令（check-project-governance exit 0）统一判定。

`evidenceForResult` 的 DONE 证据四条款（digest/source/tests/results sha256）不变——仍指向当前 digest 的 task-evidence.json，治理检查器 `validateDoneEvidence` 校验 results 产物 hash 匹配，链路自洽。

### 4.3 改造 `aggregateVerdict`（release-verdict.mjs）

当前（603 行）：`if (verificationSourceSet.digest !== FROZEN_SOURCE_SET_DIGEST) → blocker current-source-evidence-stale`。

改造为「当前 digest 重验收」语义：
1. 保留 `FROZEN_SOURCE_SET_DIGEST = '152c63…'` 常量不动（历史冻结点，合规规则 9）。
2. 读当前 digest 的 `task-acceptance.json`（或 task-evidence.json 的逐任务结果），统计 `taskCounts`。
3. 新增 prerequisite `current-acceptance-rebound`：
   - passed：当前 digest 下所有适用任务 state==DONE（done==适用任务数）。
   - not-passed：存在 BLOCKED 或 TODO。
4. `current-source-evidence-stale` blocker 转化：
   - 当 `当前digest == 152c63`（源码恰回冻结点）→ 历史证据直接适用，`current-acceptance-rebound` prerequisite 视为 passed，不加 stale blocker。
   - 当 `当前digest != 152c63` **且** `current-acceptance-rebound` passed → **不加 blocker**（当前 digest 有新鲜全过证据，历史不继承的顾虑消除）。
   - 当 `当前digest != 152c63` **且** `current-acceptance-rebound` not-passed → blocker 改为 `current-acceptance-rebound`，reason 具体到「当前 digest 下 N 任务未 DONE（M BLOCKED + K TODO）」，比笼统的 stale 更诚实可操作。
   - 当 `task-acceptance.json` 缺失（runner 未跑）→ `current-acceptance-rebound` not-passed，blocker reason 标「acceptance evidence missing, run task-acceptance-runner first」。
5. 其余 11 个历史 prerequisites（c01-c10、complexity、soak、perf、licenses、release-build、renderer、sanitizers、6-candidates、qualified-env）逻辑**不动**——它们验证的是历史冻结证据产物存在 + 静态文件常量，保留为 historical-evidence passed。
6. verdict = passed 当且仅当 `current-acceptance-rebound` passed 且其余 prerequisite 全过。本设计阶段 verdict 仍 not-passed（因 10 缺口→BLOCKED 任务），但 blocker 语义从 stale 升级为 rebound，诚实反映真实阻塞。

### 4.4 capture 前置校验调整

- `validateReleaseResult`（197 行）：当前期望 release-verdict 输出「就是 not-passed + stale blocker」。新语义下 blocker id 可能是 `current-acceptance-rebound` 而非 `current-source-evidence-stale`。改为：期望 verdict==not-passed 且 blockers 含 `current-acceptance-rebound` 或 `current-source-evidence-stale` 之一（兼容过渡）。status 仍记 `passed-current-rejection`。
- `validateKnownSwiftFailure`（121 行）：**不动**。本设计阶段 swift 仍 4 失败，期望保持 2814/1/4。待子项目 D 修了 4 失败后，同步改此函数期望 0 失败。

### 4.5 CAPTURE_COMMANDS 不变

7 个聚合命令保留（swift-tests、governance-node-tests、g4/g5/g6-contract、product-integration-probe、release-verdict）。逐任务 runner 是 capture 调用的新子步骤（在 `captureProjectEvidence` 里、`classifyTaskResults` 之前调用 runner 或读 runner 产物），不替代 7 聚合命令——聚合命令产出 `integrationFindings`（probe）和整体 exit 哈希，逐任务 runner 产出逐任务 pass/fail，两者合并喂给 classifyTaskResults。

## 5. 数据流

```
manifest.tasks[].stages[green].steps   ──┐
                                        ├─ task-acceptance-runner.mjs ── task-acceptance.json (逐任务 pass/fail)
probe findings (integrationFindings) ──┐ │
                                       ├─classifyTaskResults ── taskResults[state=DONE/BLOCKED/TODO]
task-acceptance.json ─────────────────┘ │
                                        └─ renderTaskTable ── README 台账
taskResults ─────────────────────────────┐
                                         ├─ aggregateVerdict ── verdict (rebound blocker)
FROZEN_SOURCE_SET_DIGEST(不动) ─────────┘ │
                                         └─ RELEASE_VERDICT.md
```

## 6. 治理合规

- **commit 绑定 task ID**：本设计改动 Tools/Tests/docs，按 AGENTS 规则 3 绑 README task ID。本设计是 VERIFY-001 治理框架的补完（逐任务验收机制是「单一真源治理」的延续），commit subject 绑 `VERIFY-001`。如需独立追踪，由用户授权后另加 `VERIFY-NNN` 任务到台账（不在本设计范围）。
- **非权威标记**：本 spec 头部已声明非当前进展权威。
- **不动冻结契约**：不改 `docs/contracts/.../g6-r/` 任何字节；`FROZEN_SOURCE_SET_DIGEST` 常量保留 152c63 不动。
- **不动 200 任务的验收命令定义**：runner 只读 manifest、不写 manifest。

## 7. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 200 leaf 全跑慢 | 共享 build 缓存 + 拓扑并行，目标 ~15min；超时则分批 |
| 共享 scratch-path 牺牲隔离 | 可接受：这是验收证据收集非 build 确定性验证；build 确定性已由 release-build 验证 |
| BLOCKED 语义把「验收命令过但 probe 报缺口」标 BLOCKED 可能误伤 | probe finding 对应明确行为缺口，按完成定义第 4 条不算完成，BLOCKED 诚实；子项目 A-D 填缺口后 probe finding 消失 → 自动转 DONE |
| `current-acceptance-rebound` 引入循环依赖（verdict 读 task-evidence，capture 跑 release-verdict） | runner 产物 task-acceptance.json 独立于 release-verdict；verdict 读 task-acceptance.json 而非自己产出的 task-evidence，断环 |
| manifest 400 命令含 RED/其它 stage，runner 要只取 green | 按 commandID 前缀 `<planTaskID>.GREEN.` + task.stages[green] 双重过滤 |

## 8. 后续（不在本设计）

本设计（E 基建）完成后，子项目 A–D 在此判据基建上用 subagent-driven-development + TDD Red→Green→Commit 逐个填缺口：每填一个，重跑 runner → 对应任务 BLOCKED→DONE，verdict 的 rebound blocker 任务数递减。A–D 全过后 verdict → passed、台账 → 全 DONE。
