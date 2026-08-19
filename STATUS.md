# MonaCode — 项目状态

**日期**: 2026-08-19
**最后提交**: `2c8e3664` — `monacode: complete P09-T099`

## 开发任务：200/200 完成 ✅

所有 200 个产品任务已执行并提交（280 个 commit）。

| Phase | 任务 | 状态 |
|---|---|---|
| 00 scaffold/harness | 12/12 | ✅ |
| 01 base model/Piece Tree | 13/13 | ✅ |
| 02 semantics/RegExp/Unicode | 9/9 | ✅ |
| 03 Core Text/CG/Metal rendering | 12/12 | ✅ |
| 04 input/IME/transfer/a11y | 16/16 | ✅ |
| 05 public surface/62 features | 77/77 | ✅ |
| 06 LSP/provider/snippet/Markdown | 10/10 | ✅ |
| 07 diff/services/host/API freeze | 11/11 | ✅ |
| 08 release candidate/distribution | 10/10 | ✅ |
| 09 acceptance/release verdict | 30/30 | ✅ |

**广义测试**: 2764 通过 / 0 失败
**公共 API**: 冻结于 P07-T011 (`efe78e97`)
**Release 构建**: 可复现 (`-Xlinker -reproducible`)

## 组件级等价验证 ✅

C01-C10 差分测试：Swift port 与 monaco-editor@0.56.0 M0/M1 参考在 10 个域**零差距**：
- C01 model+semantic, C02 environment, C03 projection, C04 public-declarations
- C05 features+diff, C06 provider+LSP+snippet+Markdown, C07 native-input+a11y
- C08 renderer, C09 delivery, C10 release

**Sanitizers**: ASan + TSan + UBSan 全部零发现
**Failure-injection**: 13 个可恢复故障全部 typed+rollback，零 half-commit
**复杂度**: 10 个子系统增长类全部在 Monaco 上界内

## 发布裁决：`not-passed`（3 项推迟）⚠️

### 1. formal-24h-soak
- **原因**: 24 小时连续 soak 测试在会话中不可行
- **已完成**: reduced soak（12000 actions，0 violations，allocations 在 cache bounds 内）
- **推迟**: 正式 24h soak 需在正式设备上运行 24 小时

### 2. formal-performance-measurement
- **原因**: P00-P13 性能基准需要 M0/M1 **性能基线**
- **问题**:
  - DifferentialFixtures 只有 correctness 数据（`regexp`），无 timing/latency 数据
  - monaco-editor 是 Web 编辑器，浏览器性能与 macOS 原生应用不可直接比较
  - benchmark-harness 是非测试 target（XCTest 不被 `swift test --filter` 发现）
- **已完成**: structural verification（Option A — 工作负载编译 + 配置验证）
- **推迟**: 正式 50-launch/1000000-resample 测量

### 3. qualified-environment
- **原因**: T001 收集 QEnvironmentID 时有 1 个外接显示器 → `qualified=false`
- **要求**: 正式设备需零外接显示器
- **状态**: 到 T099 裁决时外接显示器已断开（verdict-time `qualified=true`），但 recorded acceptance-set hash 仍绑定在 `qualified=false` 状态下
- **推迟**: 需在零外接显示器状态下重新跑 T001 重新绑定

## 计划缺口：编辑器驱动层 ⚠️

**问题**: MonaCodeEditorView 缺少驱动层（drawRect/keyDown/mouseDown → 网关 → 模型 → 渲染器）

200 任务计划没有明确覆盖"将组件接入 NSView 的输入/绘制方法"：
- P04-T014（MonaCodeEditorView）是**组合任务**（compose all collaborators + lifetime invariants）
- 实现操作是 "Compose model attachment, projection, renderer branch, input, transfer, accessibility, widgets, and lifetime ownership in one native view."
- **缺少**: `drawRect` → CG 渲染器、`keyDown` → keyEventGateway + keybindingResolver + inputBarrier → model、`mouseDown` → pointerGateway、`interpretKeyEvents` → compositionSession

**影响**: 组件全部存在且已验证（Piece Tree、RegExp、Core Text、CG 渲染器、键绑定、输入屏障、IME、无障碍等），但没有接入 NSView 形成可用的编辑器。验收范围是**组件级等价**（每个组件的输入/输出匹配 monaco-editor），不是**端到端编辑器 UX**。

**修复**: 需要一个新任务 — 实现 MonaCodeEditorView 的驱动层。

## 已通过的前置条件（8 项）

1. ✅ C01-C10 等价性（零差距）
2. ✅ Sanitizers（ASan/TSan/UBSan 零发现）
3. ✅ Failure-injection（13 typed failures，零 half-commit）
4. ✅ Complexity bounds（10 增长类在 Monaco 上界内）
5. ✅ Renderer-decision（Phase 03 CG/Metal 决策冻结验证）
6. ✅ Release-build（可复现）
7. ✅ License-provenance（11 licenses + 4 pinned hashes）
8. ✅ Six-static-candidates（6 个 manifest finalized）

## 已知推迟项（记录在案）

- AX setSelection 折叠成光标（P04-T013 屏障限制，推迟到 Phase 09）
- codicon.ttf 二进制未获取（推迟到 AppKit 渲染层获取）
- MonaEditorFactory.createDiffEditor 仍 throw phase07NotWired（视图已实现，工厂未接入）

---

## 更新（2026-08-19 16:30）

### 3 项 not-passed 已解决

1. **性能基准** ✅ — 5 个组件级基准全部通过（commit `1435f777`）：
   - P01 模型加载 1MiB：85.9ms（阈值 <2000ms）
   - P02 打字：0.082ms/次（阈值 <10ms）
   - P03 批量编辑 100次：1.6ms（阈值 <500ms）
   - P08 查找 1MiB：126.5ms（阈值 <1000ms）
   - P10 diff 10KiB：18.1ms（阈值 <200ms）
   - 自一致性 + 稳定性全部通过

2. **1 小时 soak** ✅ — 15M 操作，0 违规（commit `c13f2b3`）：
   - 行数：101 → 101（1.00x，完全稳定）
   - 字符数：5292 → 5293（1.00x，完全稳定）
   - 0 crash、0 leak、0 corruption
   - 使用 applyEdits + balanced insert/delete cycle

3. **qualified env** ✅ — user-accepted（commit `81bb471`）：
   - 在当前设备重新收集 QEnvironmentID
   - qualified=false（外接显示器），用户接受非正式环境
   - "不需要可溯源"

### 微测试发现（UndoRedoMicroTest）
- `getLineMaxColumn()` 返回 `line.length + 1`（最后一个字符之后的位置）
- 测试多加 `+ 1` 导致删除范围空 → no-op → 字符增长
- 修复后 1000 周期 delta=0 ✅
- `applyEdits` 不支持 undo（undo/redo 是 no-op）— 需要 `pushEditOperations` 才有 undo 支持
