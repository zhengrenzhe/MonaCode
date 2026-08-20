# MonaCode

MonaCode 是面向 Apple 平台、使用 Swift 原生开发的代码编辑器组件，以 `monaco-editor@0.56.0` 的行为和公开接口作为对标基线。当前发布目标为 arm64 macOS；iOS 与 iPadOS 属于后续版本范围。

## 权威来源

| 事项 | 唯一权威来源 | 含义 |
| --- | --- | --- |
| 当前实施进展 | 本 README 中由机器标记限定的任务区块 | 当前哪些任务已完成、进行中、受阻或尚未开始 |
| 产品范围与已接受裁剪 | [冻结的 G6-R 权威清单](docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json)及其采纳记录 | 已接受的 macOS 版本必须实现哪些内容 |
| 贡献者规则 | [仓库根目录 AGENTS.md](AGENTS.md) | 后续 Agent 如何选择、实现、验证并更新任务 |
| 验证证据 | 源码、测试、基准输出以及与源码集绑定的证据产物 | 用于证明任务状态，不能独立声明项目进展 |
| 历史决策与审计 | 冻结合同及其[归档](docs/archive/README.md) | 仅提供背景与来源追溯，不代表当前状态 |

## 已验证快照

- 验证日期：2026-08-20。
- 验证源码集摘要：`ca434479aab98cb2b756569879d55236131f4e9cda25ca4cc15a8998909d9622`。
- 验证证据：[task-evidence.json](artifacts/progress/ca434479aab98cb2b756569879d55236131f4e9cda25ca4cc15a8998909d9622/task-evidence.json)，SHA-256 为 `4632e52be3853070418503f17ac3fd259e6cef708c12dfcee481f3d7c50331c7`。
- 该产物记录下列 7 条命令、退出码、输出哈希、解析后的集成问题以及任务分类。

```bash
/usr/bin/xcrun swift test --skip Soak4HourTests
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Comparators/probes/product-integration-probe.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Release/release-verdict.mjs
```

<a id="tasks"></a>

## 任务

下表中的 `ID`、`State`、`Deliverable`、`Contract coverage`、`Acceptance`、`Evidence`，状态值 `TODO`、`IN PROGRESS`、`BLOCKED`、`DONE`，以及 `digest/source/tests/results/exit` 是机器解析协议，因此保留英文；任务说明均使用中文。

<!-- MONACODE_TASKS:BEGIN -->
| ID | State | Deliverable | Contract coverage | Acceptance | Evidence |
| --- | --- | --- | --- | --- | --- |
| VERIFY-001 | DONE | 建立并验证项目治理单一真源 | governance:single-source | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/check-project-governance.mjs</code> ⇒ exit 0 | digest:ca434479aab98cb2b756569879d55236131f4e9cda25ca4cc15a8998909d9622<br>source:[治理检查器](Tools/Docs/check-project-governance.mjs)<br>tests:[治理测试](Tests/PlanStructureTests/ProjectGovernanceTests.mjs)<br>results:[任务证据](artifacts/progress/ca434479aab98cb2b756569879d55236131f4e9cda25ca4cc15a8998909d9622/task-evidence.json) sha256:4632e52be3853070418503f17ac3fd259e6cef708c12dfcee481f3d7c50331c7 |
| SURFACE-001 | TODO | 创建精确的 SwiftPM 产品、Target 与测试夹具资源图 | plan:P00-T001/* | <code>set -o pipefail; /usr/bin/xcrun swift package dump-package &#124; /opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs</code> ⇒ exit 0 | — |
| VERIFY-002 | TODO | 强制执行 MonaCode 仅依赖 Foundation 的边界 | plan:P00-T002/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-003 | TODO | 固定 Monaco 0.56.0 的 M0/M1 对照器来源 | plan:P00-T003/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/PlanChecks/verify-provenance.mjs</code> ⇒ exit 0 | — |
| SURFACE-002 | TODO | 复现冻结的范围、声明与实例接口清单 | plan:P00-T004/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ScopeProbeTests.mjs</code> ⇒ exit 0 | — |
| SERVICE-001 | TODO | 实现分离的墙上时钟与高精度时钟域 | plan:P00-T005/* | <code>/usr/bin/xcrun swift test --filter MonaClockTests --scratch-path /tmp/monacode-planctl/P00-T005.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-002 | TODO | 实现确定性随机源、密码学随机源与 Number 到字符串转换源 | plan:P00-T006/* | <code>/usr/bin/xcrun swift test --filter MonaEntropyTests --scratch-path /tmp/monacode-planctl/P00-T006.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-003 | TODO | 将不可变 UI 本地化配置与运行时区域设置分离 | plan:P00-T007/* | <code>/usr/bin/xcrun swift test --filter MonaLocaleBoundaryTests --scratch-path /tmp/monacode-planctl/P00-T007.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-004 | TODO | 构建差分夹具与对照器框架 | plan:P00-T008/* | <code>/usr/bin/xcrun swift test --filter DifferentialHarnessTests --scratch-path /tmp/monacode-planctl/P00-T008.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-005 | TODO | 实现完整的 Q1-R3 统计裁决引擎 | plan:P00-T009/* | <code>/usr/bin/xcrun swift test --filter BootstrapStatisticsTests --scratch-path /tmp/monacode-planctl/P00-T009.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-006 | TODO | 强制校验字体来源、冷启动、显示器隔离与刷新率单元 | plan:P00-T010/* | <code>/usr/bin/xcrun swift test --filter Q1R4ControlsTests --scratch-path /tmp/monacode-planctl/P00-T010.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-007 | TODO | 收集经过隐私过滤的 QEnvironmentID 并执行正式预检 | plan:P00-T011/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/QEnvironmentCollectorTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-008 | TODO | 集成阶段 00 门禁且不声明产品证据 | plan:P00-T012/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/Phase00IntegrationTests.mjs</code> ⇒ exit 0 | — |
| MODEL-001 | TODO | 实现原始 UTF-16 位置与验证模式 | plan:P01-T001/* | <code>/usr/bin/xcrun swift test --filter MonaPositionTests --scratch-path /tmp/monacode-planctl/P01-T001.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-002 | TODO | 实现范围与有方向的选择区 | plan:P01-T002/* | <code>/usr/bin/xcrun swift test --filter MonaRangeTests --scratch-path /tmp/monacode-planctl/P01-T002.GREEN.001.PROC.001 &amp;&amp; /usr/bin/xcrun swift test --filter MonaSelectionTests --scratch-path /tmp/monacode-planctl/P01-T002.GREEN.001.PROC.002</code> ⇒ exit 0 | — |
| MODEL-003 | TODO | 实现缓存行为可观测的 Monaco URI 语义 | plan:P01-T003/* | <code>/usr/bin/xcrun swift test --filter MonaURITests --scratch-path /tmp/monacode-planctl/P01-T003.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-004 | TODO | 实现按键、修饰键、令牌与标记值类型 | plan:P01-T004/* | <code>/usr/bin/xcrun swift test --filter MonaValueEnumTests --scratch-path /tmp/monacode-planctl/P01-T004.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-005 | TODO | 实现确定性事件与幂等释放 | plan:P01-T005/* | <code>/usr/bin/xcrun swift test --filter MonaEmitterTests --scratch-path /tmp/monacode-planctl/P01-T005.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-006 | TODO | 实现取消令牌与取消源 | plan:P01-T006/* | <code>/usr/bin/xcrun swift test --filter MonaCancellationTests --scratch-path /tmp/monacode-planctl/P01-T006.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-007 | TODO | 基于原始 UInt16 存储移植 Piece Tree | plan:P01-T007/* | <code>/usr/bin/xcrun swift test --filter MonaPieceTreeDifferentialTests --scratch-path /tmp/monacode-planctl/P01-T007.GREEN.001.PROC.001 &amp;&amp; /usr/bin/xcrun swift test --filter MonaPieceTreeComplexityTests --scratch-path /tmp/monacode-planctl/P01-T007.GREEN.001.PROC.002</code> ⇒ exit 0 | — |
| MODEL-008 | TODO | 基于 Piece Tree 事实源实现全部 70 个保留文本模型成员 | plan:P01-T008/* | <code>/usr/bin/xcrun swift test --filter MonaCodeModelSurfaceTests --scratch-path /tmp/monacode-planctl/P01-T008.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-009 | TODO | 由单一编辑事务网关统一管理修改与版本事实 | plan:P01-T009/* | <code>/usr/bin/xcrun swift test --filter MonaTransactionGatewayTests --scratch-path /tmp/monacode-planctl/P01-T009.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-010 | TODO | 使用有效性票据控制异步结果发布 | plan:P01-T010/* | <code>/usr/bin/xcrun swift test --filter MonaAsyncValidityTicketTests --scratch-path /tmp/monacode-planctl/P01-T010.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-011 | TODO | 实现模型构造与大型模型状态 | plan:P01-T011/* | <code>/usr/bin/xcrun swift test --filter MonaModelFactoryTests --scratch-path /tmp/monacode-planctl/P01-T011.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-004 | TODO | 实现应用全局与单编辑器生命周期注册表 | plan:P01-T012/* | <code>/usr/bin/xcrun swift test --filter MonaLifetimeRegistryTests --scratch-path /tmp/monacode-planctl/P01-T012.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-009 | TODO | 通过完整模型差分与失败矩阵完成阶段 01 闭环 | plan:P01-T013/* | <code>/usr/bin/xcrun swift test --filter Phase01ModelConformanceTests --scratch-path /tmp/monacode-planctl/P01-T013.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-012 | TODO | 基于事务事实源实现撤销与重做元素 | plan:P02-T001/* | <code>/usr/bin/xcrun swift test --filter MonaUndoRedoTests --scratch-path /tmp/monacode-planctl/P02-T001.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-013 | TODO | 移植装饰区间树与粘滞性语义 | plan:P02-T002/* | <code>/usr/bin/xcrun swift test --filter MonaDecorationTreeDifferentialTests --scratch-path /tmp/monacode-planctl/P02-T002.GREEN.001.PROC.001 &amp;&amp; /usr/bin/xcrun swift test --filter MonaDecorationTreeComplexityTests --scratch-path /tmp/monacode-planctl/P02-T002.GREEN.001.PROC.002</code> ⇒ exit 0 | — |
| MODEL-014 | TODO | 实现单词、字素、字面量搜索与替换原语 | plan:P02-T003/* | <code>/usr/bin/xcrun swift test --filter MonaWordSearchTests --scratch-path /tmp/monacode-planctl/P02-T003.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-015 | TODO | 实现有限范围的 ECMAScript RegExp 解析器与编译器 | plan:P02-T004/* | <code>/usr/bin/xcrun swift test --filter MonaRegExpParserCompilerTests --scratch-path /tmp/monacode-planctl/P02-T004.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-016 | TODO | 生成 6 个不可合并的 RegExp Unicode 配置 | plan:P02-T005/* | <code>/usr/bin/xcrun swift test --filter MonaRegExpUnicodeProfileTests --scratch-path /tmp/monacode-planctl/P02-T005.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-017 | TODO | 使用固定的 Test262 向量完成 10 个 RegExp 消费方配置 | plan:P02-T006/* | <code>/usr/bin/xcrun swift test --filter MonaRegExpConsumerProfileTests --scratch-path /tmp/monacode-planctl/P02-T006.GREEN.001.PROC.001 &amp;&amp; /usr/bin/xcrun swift test --filter MonaRegExpTest262Tests --scratch-path /tmp/monacode-planctl/P02-T006.GREEN.001.PROC.002</code> ⇒ exit 0 | — |
| MODEL-018 | TODO | 实现固定的大小写转换、排序与规范化配置 | plan:P02-T007/* | <code>/usr/bin/xcrun swift test --filter MonaEnvironmentSemanticsTests --scratch-path /tmp/monacode-planctl/P02-T007.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| MODEL-019 | TODO | 实现有限范围的 ECMAScript 内建能力、编解码器与 String SHA-1 | plan:P02-T008/* | <code>/usr/bin/xcrun swift test --filter MonaFiniteIntrinsicTests --scratch-path /tmp/monacode-planctl/P02-T008.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-010 | TODO | 验证暂定的 RegExp 与环境候选输入 | plan:P02-T009/* | <code>/usr/bin/xcrun swift test --filter Phase02SemanticConformanceTests --scratch-path /tmp/monacode-planctl/P02-T009.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-001 | TODO | 构建 ViewGraph 投影与对数复杂度垂直索引 | plan:P03-T001/* | <code>/usr/bin/xcrun swift test --filter MonaViewGraphDifferentialTests --scratch-path /tmp/monacode-planctl/P03-T001.GREEN.001.PROC.001 &amp;&amp; /usr/bin/xcrun swift test --filter MonaVerticalIndexComplexityTests --scratch-path /tmp/monacode-planctl/P03-T001.GREEN.001.PROC.002</code> ⇒ exit 0 | — |
| RENDER-002 | TODO | 使用 Core Text 和确定性回退塑形混合文字行 | plan:P03-T002/* | <code>/usr/bin/xcrun swift test --filter MonaTextShaperTests --scratch-path /tmp/monacode-planctl/P03-T002.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-003 | TODO | 冻结共享且不可变的 LineLayoutRecord 几何数据 | plan:P03-T003/* | <code>/usr/bin/xcrun swift test --filter MonaLineLayoutRecordTests --scratch-path /tmp/monacode-planctl/P03-T003.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-004 | TODO | 定义 7 个互不矛盾的依赖版本戳域 | plan:P03-T004/* | <code>/usr/bin/xcrun swift test --filter MonaDependencyStampTests --scratch-path /tmp/monacode-planctl/P03-T004.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-005 | TODO | 实现滚动事实源与尺寸收敛 | plan:P03-T005/* | <code>/usr/bin/xcrun swift test --filter MonaScrollModelTests --scratch-path /tmp/monacode-planctl/P03-T005.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-006 | TODO | 完成正确的 Core Graphics 分块渲染器 | plan:P03-T006/* | <code>/usr/bin/xcrun swift test --filter MonaCoreGraphicsRendererTests --scratch-path /tmp/monacode-planctl/P03-T006.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-007 | TODO | 对命中测试与原生查询强制执行 QueryGeometryBarrier | plan:P03-T007/* | <code>/usr/bin/xcrun swift test --filter MonaQueryGeometryBarrierTests --scratch-path /tmp/monacode-planctl/P03-T007.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-008 | TODO | 使用 FailedLineRecord 表达有界 Core Text 失败 | plan:P03-T008/* | <code>/usr/bin/xcrun swift test --filter MonaFailedLineRecordTests --scratch-path /tmp/monacode-planctl/P03-T008.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-009 | TODO | 检测并记录渲染器负责的正确性与性能指标 | plan:P03-T009/* | <code>/usr/bin/xcrun swift test --filter MonaRendererMetricsTests --scratch-path /tmp/monacode-planctl/P03-T009.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-010 | TODO | 基于完整 Core Graphics 证据确定渲染器决策 | plan:P03-T010/* | <code>/usr/bin/xcrun swift test --filter MonaRendererDecisionGateTests --scratch-path /tmp/monacode-planctl/P03-T010.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-011 | TODO | 在阶段 03 内完整执行条件式 Metal 分支 | plan:P03-T011/* | <code>/usr/bin/xcrun swift test --filter MonaMetalRendererParityTests --scratch-path /tmp/monacode-planctl/P03-T011.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-012 | TODO | 在原生输入实现前完成投影、几何与渲染器等价闭环 | plan:P03-T012/* | <code>/usr/bin/xcrun swift test --filter Phase03RendererConformanceTests --scratch-path /tmp/monacode-planctl/P03-T012.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-001 | TODO | 在 Core 中定义平台无关的键盘事件语义 | plan:P04-T001/* | <code>/usr/bin/xcrun swift test --filter MonaKeyEventTests --scratch-path /tmp/monacode-planctl/P04-T001.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-002 | TODO | 通过单一原生网关转换 AppKit 键盘事件 | plan:P04-T002/* | <code>/usr/bin/xcrun swift test --filter MonaAppKeyEventGatewayTests --scratch-path /tmp/monacode-planctl/P04-T002.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-003 | TODO | 将快捷键解析与组合键状态移植到 Core | plan:P04-T003/* | <code>/usr/bin/xcrun swift test --filter MonaKeybindingResolverTests --scratch-path /tmp/monacode-planctl/P04-T003.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-004 | TODO | 实现标记文本输入与输入法组合仲裁 | plan:P04-T004/* | <code>/usr/bin/xcrun swift test --filter MonaCompositionTests --scratch-path /tmp/monacode-planctl/P04-T004.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-005 | TODO | 通过 ModelInputBarrier 复制多光标输入 | plan:P04-T005/* | <code>/usr/bin/xcrun swift test --filter MonaModelInputBarrierTests --scratch-path /tmp/monacode-planctl/P04-T005.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-006 | TODO | 通过 AppKit 投影指针、滚动与上下文菜单事件 | plan:P04-T006/* | <code>/usr/bin/xcrun swift test --filter MonaPointerScrollMenuTests --scratch-path /tmp/monacode-planctl/P04-T006.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-007 | TODO | 实现公开 EventControl 与原生事件适配 | plan:P04-T007/* | <code>/usr/bin/xcrun swift test --filter MonaEventControlTests --scratch-path /tmp/monacode-planctl/P04-T007.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-008 | TODO | 实现复制、剪切、粘贴与粘贴编辑流水线 | plan:P04-T008/* | <code>/usr/bin/xcrun swift test --filter MonaPasteboardTests --scratch-path /tmp/monacode-planctl/P04-T008.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-009 | TODO | 实现拖动、放置与 macOS 服务传输 | plan:P04-T009/* | <code>/usr/bin/xcrun swift test --filter MonaDragDropServicesTests --scratch-path /tmp/monacode-planctl/P04-T009.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-010 | TODO | 公开原始 UTF-16 原生文本无障碍接口 | plan:P04-T010/* | <code>/usr/bin/xcrun swift test --filter MonaAXTextAreaTests --scratch-path /tmp/monacode-planctl/P04-T010.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-011 | TODO | 实现无障碍控件、代理、链接、诊断与操作 | plan:P04-T011/* | <code>/usr/bin/xcrun swift test --filter MonaAXElementGraphTests --scratch-path /tmp/monacode-planctl/P04-T011.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-012 | TODO | 实现焦点模式与本地化播报桥接 | plan:P04-T012/* | <code>/usr/bin/xcrun swift test --filter MonaAXFocusAnnouncementTests --scratch-path /tmp/monacode-planctl/P04-T012.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-013 | TODO | 通过 ModelInputBarrier 路由无障碍属性写入 | plan:P04-T013/* | <code>/usr/bin/xcrun swift test --filter MonaAXMutationGatewayTests --scratch-path /tmp/monacode-planctl/P04-T013.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-001 | TODO | 以 MonaCodeEditorView 作为 AppKit 编辑器边界 | plan:P04-T014/* | <code>/usr/bin/xcrun swift test --filter MonaCodeEditorViewLifecycleTests --scratch-path /tmp/monacode-planctl/P04-T014.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-002 | TODO | 交付 MonaCodeEditor 与 MonaSwiftUIEditorController 生命周期包装器 | plan:P04-T015/* | <code>/usr/bin/xcrun swift test --filter MonaCodeEditorSwiftUILifecycleTests --scratch-path /tmp/monacode-planctl/P04-T015.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-011 | TODO | 完成原生输入、传输、无障碍与编辑器嵌入闭环 | plan:P04-T016/* | <code>/usr/bin/xcrun swift test --filter Phase04NativeBoundaryConformanceTests --scratch-path /tmp/monacode-planctl/P04-T016.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SURFACE-003 | TODO | 生成精确的 555 路径原生公开声明图 | plan:P05-T001/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/PublicDeclarationGraphTests.mjs</code> ⇒ exit 0 | — |
| COMMAND-001 | TODO | 实现命令、操作、贡献点与纯文本注册表 | plan:P05-T002/* | <code>/usr/bin/xcrun swift test --filter MonaCommandActionRegistryTests --scratch-path /tmp/monacode-planctl/P05-T002.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-002 | TODO | 基于 Core 解析器填充全部 379 条快捷键记录 | plan:P05-T003/* | <code>/usr/bin/xcrun swift test --filter MonaBuiltinKeybindingTests --scratch-path /tmp/monacode-planctl/P05-T003.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-003 | TODO | 实现菜单、菜单项与菜单命令注册表 | plan:P05-T004/* | <code>/usr/bin/xcrun swift test --filter MonaMenuRegistryTests --scratch-path /tmp/monacode-planctl/P05-T004.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| REGISTRY-001 | TODO | 实现全部 174 个编辑器选项及其计算结果事实源 | plan:P05-T005/* | <code>/usr/bin/xcrun swift test --filter MonaEditorOptionTests --scratch-path /tmp/monacode-planctl/P05-T005.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| REGISTRY-002 | TODO | 实现主题、令牌、颜色、图标与 Codicon 注册表 | plan:P05-T006/* | <code>/usr/bin/xcrun swift test --filter MonaThemeRegistryTests --scratch-path /tmp/monacode-planctl/P05-T006.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| REGISTRY-003 | TODO | 生成包含 2120 条消息的 15 个不可变 UI 本地化配置 | plan:P05-T007/* | <code>/usr/bin/xcrun swift test --filter MonaLocalizationTests --scratch-path /tmp/monacode-planctl/P05-T007.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-001 | TODO | 仅保留核心语言元数据与明确的纯文本回退 | plan:P05-T008/* | <code>/usr/bin/xcrun swift test --filter MonaLanguageRegistryTests --scratch-path /tmp/monacode-planctl/P05-T008.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-013 | TODO | 将 editor.colorize 实现为原生富文本替代方案 | plan:P05-T009/* | <code>/usr/bin/xcrun swift test --filter MonaColorizeSourceTests --scratch-path /tmp/monacode-planctl/P05-T009.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-014 | TODO | 将 editor.colorizeElement 实现为原生视图修改替代方案 | plan:P05-T010/* | <code>/usr/bin/xcrun swift test --filter MonaColorizeViewTests --scratch-path /tmp/monacode-planctl/P05-T010.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-015 | TODO | 基于不可变布局几何实现 editor.colorizeModelLine | plan:P05-T011/* | <code>/usr/bin/xcrun swift test --filter MonaColorizeModelLineTests --scratch-path /tmp/monacode-planctl/P05-T011.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-003 | TODO | 完成编辑器工厂与 5 组实例接口序列闭环 | plan:P05-T012/* | <code>/usr/bin/xcrun swift test --filter MonaEditorInstanceSurfaceTests --scratch-path /tmp/monacode-planctl/P05-T012.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-002 | TODO | 实现确定性的 Provider 执行与微任务发布 | plan:P05-T013/* | <code>/usr/bin/xcrun swift test --filter MonaProviderExecutorTests --scratch-path /tmp/monacode-planctl/P05-T013.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-004 | TODO | 实现保留功能 anchorSelect | plan:P05-T100/* | <code>/usr/bin/xcrun swift test --filter MonaAnchorSelectFeatureTests --scratch-path /tmp/monacode-planctl/P05-T100.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-004 | TODO | 实现保留功能 bracketMatching | plan:P05-T101/* | <code>/usr/bin/xcrun swift test --filter MonaBracketMatchingFeatureTests --scratch-path /tmp/monacode-planctl/P05-T101.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-005 | TODO | 实现保留功能 caretOperations | plan:P05-T102/* | <code>/usr/bin/xcrun swift test --filter MonaCaretOperationsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T102.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-014 | TODO | 实现保留功能 clipboard | plan:P05-T103/* | <code>/usr/bin/xcrun swift test --filter MonaClipboardFeatureTests --scratch-path /tmp/monacode-planctl/P05-T103.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-003 | TODO | 实现保留功能 codeAction | plan:P05-T104/* | <code>/usr/bin/xcrun swift test --filter MonaCodeActionFeatureTests --scratch-path /tmp/monacode-planctl/P05-T104.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-005 | TODO | 实现保留功能 codeEditor | plan:P05-T105/* | <code>/usr/bin/xcrun swift test --filter MonaCodeEditorFeatureTests --scratch-path /tmp/monacode-planctl/P05-T105.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-004 | TODO | 实现保留功能 codelens | plan:P05-T106/* | <code>/usr/bin/xcrun swift test --filter MonaCodelensFeatureTests --scratch-path /tmp/monacode-planctl/P05-T106.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-016 | TODO | 实现保留功能 codicon | plan:P05-T107/* | <code>/usr/bin/xcrun swift test --filter MonaCodiconFeatureTests --scratch-path /tmp/monacode-planctl/P05-T107.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-017 | TODO | 实现保留功能 colorPicker | plan:P05-T108/* | <code>/usr/bin/xcrun swift test --filter MonaColorPickerFeatureTests --scratch-path /tmp/monacode-planctl/P05-T108.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-006 | TODO | 实现保留功能 comment | plan:P05-T109/* | <code>/usr/bin/xcrun swift test --filter MonaCommentFeatureTests --scratch-path /tmp/monacode-planctl/P05-T109.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-006 | TODO | 实现保留功能 contextmenu | plan:P05-T110/* | <code>/usr/bin/xcrun swift test --filter MonaContextmenuFeatureTests --scratch-path /tmp/monacode-planctl/P05-T110.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-015 | TODO | 实现保留功能 cursorUndo | plan:P05-T111/* | <code>/usr/bin/xcrun swift test --filter MonaCursorUndoFeatureTests --scratch-path /tmp/monacode-planctl/P05-T111.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| DIFF-001 | TODO | 实现保留功能 diffEditor | plan:P05-T112/* | <code>/usr/bin/xcrun swift test --filter MonaDiffEditorFeatureTests --scratch-path /tmp/monacode-planctl/P05-T112.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| DIFF-002 | TODO | 实现保留功能 diffEditorBreadcrumbs | plan:P05-T113/* | <code>/usr/bin/xcrun swift test --filter MonaDiffEditorBreadcrumbsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T113.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-016 | TODO | 实现保留功能 dnd | plan:P05-T114/* | <code>/usr/bin/xcrun swift test --filter MonaDndFeatureTests --scratch-path /tmp/monacode-planctl/P05-T114.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-005 | TODO | 实现保留功能 documentSymbols | plan:P05-T115/* | <code>/usr/bin/xcrun swift test --filter MonaDocumentSymbolsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T115.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-017 | TODO | 实现保留功能 dropOrPasteInto | plan:P05-T116/* | <code>/usr/bin/xcrun swift test --filter MonaDropOrPasteIntoFeatureTests --scratch-path /tmp/monacode-planctl/P05-T116.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-007 | TODO | 实现保留功能 find | plan:P05-T117/* | <code>/usr/bin/xcrun swift test --filter MonaFindFeatureTests --scratch-path /tmp/monacode-planctl/P05-T117.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-018 | TODO | 实现保留功能 floatingMenu | plan:P05-T118/* | <code>/usr/bin/xcrun swift test --filter MonaFloatingMenuFeatureTests --scratch-path /tmp/monacode-planctl/P05-T118.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-006 | TODO | 实现保留功能 folding | plan:P05-T119/* | <code>/usr/bin/xcrun swift test --filter MonaFoldingFeatureTests --scratch-path /tmp/monacode-planctl/P05-T119.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-019 | TODO | 实现保留功能 fontZoom | plan:P05-T120/* | <code>/usr/bin/xcrun swift test --filter MonaFontZoomFeatureTests --scratch-path /tmp/monacode-planctl/P05-T120.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-007 | TODO | 实现保留功能 format | plan:P05-T121/* | <code>/usr/bin/xcrun swift test --filter MonaFormatFeatureTests --scratch-path /tmp/monacode-planctl/P05-T121.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-007 | TODO | 实现保留功能 gotoError | plan:P05-T122/* | <code>/usr/bin/xcrun swift test --filter MonaGotoErrorFeatureTests --scratch-path /tmp/monacode-planctl/P05-T122.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-008 | TODO | 实现保留功能 gotoLine | plan:P05-T123/* | <code>/usr/bin/xcrun swift test --filter MonaGotoLineFeatureTests --scratch-path /tmp/monacode-planctl/P05-T123.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-008 | TODO | 实现保留功能 gotoSymbol | plan:P05-T124/* | <code>/usr/bin/xcrun swift test --filter MonaGotoSymbolFeatureTests --scratch-path /tmp/monacode-planctl/P05-T124.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-009 | TODO | 实现保留功能 hover | plan:P05-T125/* | <code>/usr/bin/xcrun swift test --filter MonaHoverFeatureTests --scratch-path /tmp/monacode-planctl/P05-T125.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-010 | TODO | 实现保留功能 indentation | plan:P05-T126/* | <code>/usr/bin/xcrun swift test --filter MonaIndentationFeatureTests --scratch-path /tmp/monacode-planctl/P05-T126.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-011 | TODO | 实现保留功能 inlayHints | plan:P05-T127/* | <code>/usr/bin/xcrun swift test --filter MonaInlayHintsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T127.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-012 | TODO | 实现保留功能 inlineCompletions | plan:P05-T128/* | <code>/usr/bin/xcrun swift test --filter MonaInlineCompletionsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T128.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-020 | TODO | 实现保留功能 inlineProgress | plan:P05-T129/* | <code>/usr/bin/xcrun swift test --filter MonaInlineProgressFeatureTests --scratch-path /tmp/monacode-planctl/P05-T129.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-009 | TODO | 实现保留功能 inPlaceReplace | plan:P05-T130/* | <code>/usr/bin/xcrun swift test --filter MonaInPlaceReplaceFeatureTests --scratch-path /tmp/monacode-planctl/P05-T130.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-010 | TODO | 实现保留功能 insertFinalNewLine | plan:P05-T131/* | <code>/usr/bin/xcrun swift test --filter MonaInsertFinalNewLineFeatureTests --scratch-path /tmp/monacode-planctl/P05-T131.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-021 | TODO | 实现保留功能 inspectTokens | plan:P05-T132/* | <code>/usr/bin/xcrun swift test --filter MonaInspectTokensFeatureTests --scratch-path /tmp/monacode-planctl/P05-T132.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-018 | TODO | 实现保留功能 lineSelection | plan:P05-T133/* | <code>/usr/bin/xcrun swift test --filter MonaLineSelectionFeatureTests --scratch-path /tmp/monacode-planctl/P05-T133.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-011 | TODO | 实现保留功能 linesOperations | plan:P05-T134/* | <code>/usr/bin/xcrun swift test --filter MonaLinesOperationsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T134.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-013 | TODO | 实现保留功能 linkedEditing | plan:P05-T135/* | <code>/usr/bin/xcrun swift test --filter MonaLinkedEditingFeatureTests --scratch-path /tmp/monacode-planctl/P05-T135.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-022 | TODO | 实现保留功能 links | plan:P05-T136/* | <code>/usr/bin/xcrun swift test --filter MonaLinksFeatureTests --scratch-path /tmp/monacode-planctl/P05-T136.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-012 | TODO | 实现保留功能 longLinesHelper | plan:P05-T137/* | <code>/usr/bin/xcrun swift test --filter MonaLongLinesHelperFeatureTests --scratch-path /tmp/monacode-planctl/P05-T137.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-013 | TODO | 实现保留功能 middleScroll | plan:P05-T138/* | <code>/usr/bin/xcrun swift test --filter MonaMiddleScrollFeatureTests --scratch-path /tmp/monacode-planctl/P05-T138.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-019 | TODO | 实现保留功能 multicursor | plan:P05-T139/* | <code>/usr/bin/xcrun swift test --filter MonaMulticursorFeatureTests --scratch-path /tmp/monacode-planctl/P05-T139.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-014 | TODO | 实现保留功能 parameterHints | plan:P05-T140/* | <code>/usr/bin/xcrun swift test --filter MonaParameterHintsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T140.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-023 | TODO | 实现保留功能 placeholderText | plan:P05-T141/* | <code>/usr/bin/xcrun swift test --filter MonaPlaceholderTextFeatureTests --scratch-path /tmp/monacode-planctl/P05-T141.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-008 | TODO | 实现保留功能 quickCommand | plan:P05-T142/* | <code>/usr/bin/xcrun swift test --filter MonaQuickCommandFeatureTests --scratch-path /tmp/monacode-planctl/P05-T142.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-009 | TODO | 实现保留功能 quickHelp | plan:P05-T143/* | <code>/usr/bin/xcrun swift test --filter MonaQuickHelpFeatureTests --scratch-path /tmp/monacode-planctl/P05-T143.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| EDITOR-010 | TODO | 实现保留功能 quickOutline | plan:P05-T144/* | <code>/usr/bin/xcrun swift test --filter MonaQuickOutlineFeatureTests --scratch-path /tmp/monacode-planctl/P05-T144.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-014 | TODO | 实现保留功能 readOnlyMessage | plan:P05-T145/* | <code>/usr/bin/xcrun swift test --filter MonaReadOnlyMessageFeatureTests --scratch-path /tmp/monacode-planctl/P05-T145.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-015 | TODO | 实现保留功能 referenceSearch | plan:P05-T146/* | <code>/usr/bin/xcrun swift test --filter MonaReferenceSearchFeatureTests --scratch-path /tmp/monacode-planctl/P05-T146.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-016 | TODO | 实现保留功能 rename | plan:P05-T147/* | <code>/usr/bin/xcrun swift test --filter MonaRenameFeatureTests --scratch-path /tmp/monacode-planctl/P05-T147.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-024 | TODO | 实现保留功能 sectionHeaders | plan:P05-T148/* | <code>/usr/bin/xcrun swift test --filter MonaSectionHeadersFeatureTests --scratch-path /tmp/monacode-planctl/P05-T148.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-017 | TODO | 实现保留功能 semanticTokens | plan:P05-T149/* | <code>/usr/bin/xcrun swift test --filter MonaSemanticTokensFeatureTests --scratch-path /tmp/monacode-planctl/P05-T149.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-018 | TODO | 实现保留功能 smartSelect | plan:P05-T150/* | <code>/usr/bin/xcrun swift test --filter MonaSmartSelectFeatureTests --scratch-path /tmp/monacode-planctl/P05-T150.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-019 | TODO | 实现保留功能 snippet | plan:P05-T151/* | <code>/usr/bin/xcrun swift test --filter MonaSnippetFeatureTests --scratch-path /tmp/monacode-planctl/P05-T151.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-025 | TODO | 实现保留功能 stickyScroll | plan:P05-T152/* | <code>/usr/bin/xcrun swift test --filter MonaStickyScrollFeatureTests --scratch-path /tmp/monacode-planctl/P05-T152.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-020 | TODO | 实现保留功能 suggest | plan:P05-T153/* | <code>/usr/bin/xcrun swift test --filter MonaSuggestFeatureTests --scratch-path /tmp/monacode-planctl/P05-T153.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-026 | TODO | 实现保留功能 toggleHighContrast | plan:P05-T154/* | <code>/usr/bin/xcrun swift test --filter MonaToggleHighContrastFeatureTests --scratch-path /tmp/monacode-planctl/P05-T154.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| INPUT-020 | TODO | 实现保留功能 toggleTabFocusMode | plan:P05-T155/* | <code>/usr/bin/xcrun swift test --filter MonaToggleTabFocusModeFeatureTests --scratch-path /tmp/monacode-planctl/P05-T155.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-021 | TODO | 实现保留功能 tokenization | plan:P05-T156/* | <code>/usr/bin/xcrun swift test --filter MonaTokenizationFeatureTests --scratch-path /tmp/monacode-planctl/P05-T156.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-027 | TODO | 实现保留功能 unicodeHighlighter | plan:P05-T157/* | <code>/usr/bin/xcrun swift test --filter MonaUnicodeHighlighterFeatureTests --scratch-path /tmp/monacode-planctl/P05-T157.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-015 | TODO | 实现保留功能 unusualLineTerminators | plan:P05-T158/* | <code>/usr/bin/xcrun swift test --filter MonaUnusualLineTerminatorsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T158.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| RENDER-028 | TODO | 实现保留功能 wordHighlighter | plan:P05-T159/* | <code>/usr/bin/xcrun swift test --filter MonaWordHighlighterFeatureTests --scratch-path /tmp/monacode-planctl/P05-T159.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-016 | TODO | 实现保留功能 wordOperations | plan:P05-T160/* | <code>/usr/bin/xcrun swift test --filter MonaWordOperationsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T160.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| COMMAND-017 | TODO | 实现保留功能 wordPartOperations | plan:P05-T161/* | <code>/usr/bin/xcrun swift test --filter MonaWordPartOperationsFeatureTests --scratch-path /tmp/monacode-planctl/P05-T161.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SURFACE-004 | TODO | 生成并验证暂定的原生声明清单 | plan:P05-T190/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/NativeDeclarationManifestTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-012 | TODO | 完成保留公开接口、注册表、选项、主题、本地化与功能闭环 | plan:P05-T200/* | <code>/usr/bin/xcrun swift test --filter Phase05PublicSurfaceConformanceTests --scratch-path /tmp/monacode-planctl/P05-T200.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-022 | TODO | 在 Core 中定义与传输方式无关的字节通道 | plan:P06-T001/* | <code>/usr/bin/xcrun swift test --filter MonaMessageTransportContractTests --scratch-path /tmp/monacode-planctl/P06-T001.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-023 | TODO | 实现流式 LSP 帧解码与编码 | plan:P06-T002/* | <code>/usr/bin/xcrun swift test --filter MonaLSPFrameCodecTests --scratch-path /tmp/monacode-planctl/P06-T002.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-024 | TODO | 实现确定性的 JSON-RPC 线上值与错误 | plan:P06-T003/* | <code>/usr/bin/xcrun swift test --filter MonaJSONRPCCodecTests --scratch-path /tmp/monacode-planctl/P06-T003.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-025 | TODO | 实现 LSP 会话状态与 25 项能力映射 | plan:P06-T004/* | <code>/usr/bin/xcrun swift test --filter MonaLSPClientCapabilityTests --scratch-path /tmp/monacode-planctl/P06-T004.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-026 | TODO | 完成全部 30 个 Provider 注册表与 5 个仅直接调用接口 | plan:P06-T005/* | <code>/usr/bin/xcrun swift test --filter MonaProviderRegistryClosureTests --scratch-path /tmp/monacode-planctl/P06-T005.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-027 | TODO | 移植完整的代码片段解析器与语法 | plan:P06-T006/* | <code>/usr/bin/xcrun swift test --filter MonaSnippetParserTests --scratch-path /tmp/monacode-planctl/P06-T006.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-028 | TODO | 实现代码片段变量、解析器、会话与多光标顺序 | plan:P06-T007/* | <code>/usr/bin/xcrun swift test --filter MonaSnippetSessionTests --scratch-path /tmp/monacode-planctl/P06-T007.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-029 | TODO | 将 Markdown 语义移植为原生呈现树 | plan:P06-T008/* | <code>/usr/bin/xcrun swift test --filter MonaMarkdownSecurityTests --scratch-path /tmp/monacode-planctl/P06-T008.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-005 | TODO | 在 Core 外实现 macOS 宿主字节传输适配器 | plan:P06-T009/* | <code>/usr/bin/xcrun swift test --filter MonaProcessMessageTransportTests --scratch-path /tmp/monacode-planctl/P06-T009.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| LANG-030 | TODO | 完成 LSP、Provider、代码片段、Markdown 与纯文本回退行为闭环 | plan:P06-T010/* | <code>/usr/bin/xcrun swift test --filter Phase06LanguageInfrastructureTests --scratch-path /tmp/monacode-planctl/P06-T010.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| DIFF-003 | TODO | 基于原始 UTF-16 实现传统与高级差异算法 | plan:P07-T001/* | <code>/usr/bin/xcrun swift test --filter MonaDiffEngineDifferentialTests --scratch-path /tmp/monacode-planctl/P07-T001.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| DIFF-004 | TODO | 完成差异超时、缓存、最大尺寸与不可用外部路径闭环 | plan:P07-T002/* | <code>/usr/bin/xcrun swift test --filter MonaDiffCoordinatorTests --scratch-path /tmp/monacode-planctl/P07-T002.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-006 | TODO | 实现 40 个独立服务与有界会话状态 | plan:P07-T003/* | <code>/usr/bin/xcrun swift test --filter MonaStandaloneServiceTests --scratch-path /tmp/monacode-planctl/P07-T003.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-007 | TODO | 将 4 个对话框调用点投影为宿主授权的原生对话框 | plan:P07-T004/* | <code>/usr/bin/xcrun swift test --filter MonaDialogServiceTests --scratch-path /tmp/monacode-planctl/P07-T004.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-008 | TODO | 实现 7 个宿主分组与 10 个具体宿主类型 | plan:P07-T005/* | <code>/usr/bin/xcrun swift test --filter MonaHostContractClosureTests --scratch-path /tmp/monacode-planctl/P07-T005.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-009 | TODO | 实现具有 4 种结果的 WorkspaceEdit 事务 | plan:P07-T006/* | <code>/usr/bin/xcrun swift test --filter MonaWorkspaceEditTests --scratch-path /tmp/monacode-planctl/P07-T006.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-010 | TODO | 完成有界缓存注册表与暂定缓存清单闭环 | plan:P07-T007/* | <code>/usr/bin/xcrun swift test --filter MonaCacheRegistryTests --scratch-path /tmp/monacode-planctl/P07-T007.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SERVICE-011 | TODO | 完成运行时替代方案与完整源码清单闭环 | plan:P07-T008/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/SourceRuntimeStyleTests.mjs</code> ⇒ exit 0 | — |
| DIFF-005 | TODO | 交付差异与多重差异视图、SwiftUI 包装器及示例宿主激活路径 | plan:P07-T009/* | <code>/usr/bin/xcrun swift test --filter MonaDiffViewLifecycleTests --scratch-path /tmp/monacode-planctl/P07-T009.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-013 | TODO | 完成差异、服务、宿主、缓存、源码与视图一致性闭环 | plan:P07-T010/* | <code>/usr/bin/xcrun swift test --filter Phase07HostAndDiffConformanceTests --scratch-path /tmp/monacode-planctl/P07-T010.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| SURFACE-005 | TODO | 在生成候选版本前冻结最终公开 API 闭环 | plan:P07-T011/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/PublicAPIClosureTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-014 | TODO | 构建冻结的三产品发布包 | plan:P08-T001/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ReleaseBuildTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-015 | TODO | 扫描包图、符号、链接、资源与禁用运行时 | plan:P08-T002/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/DistributionScanTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-016 | TODO | 汇总精确的许可证来源与分发声明 | plan:P08-T003/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/LicenseNoticeTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-017 | TODO | 在公开 API 闭环后最终确定 MonaNativeDeclarationManifest | plan:P08-T010/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalNativeDeclarationManifestTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-018 | TODO | 在所有语义消费方完成后最终确定 MonaRegExpUnicodeManifest | plan:P08-T011/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalRegExpUnicodeManifestTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-019 | TODO | 在所有环境敏感消费方完成后最终确定 MonaEnvironmentManifest | plan:P08-T012/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalEnvironmentManifestTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-020 | TODO | 基于发布源码集最终确定 MonaSourceClosureManifest | plan:P08-T013/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalSourceClosureManifestTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-021 | TODO | 基于全部已注册缓存最终确定 MonaCacheManifest | plan:P08-T014/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalCacheManifestTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-022 | TODO | 在包与声明闭环后最终确定 MonaDistributionManifest | plan:P08-T015/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalDistributionManifestTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-023 | TODO | 验证精确的 6 个静态发布候选集合 | plan:P08-T016/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/SixStaticCandidateSetTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-024 | TODO | 重新收集并最终确定每次运行经隐私过滤的 QEnvironmentID | plan:P09-T001/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FormalQEnvironmentPreflightTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-025 | TODO | 将全部 7 个候选合并为单一合格验收集合 | plan:P09-T002/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/QualifiedCandidateSetTests.mjs</code> ⇒ exit 0 | — |
| VERIFY-026 | TODO | 执行 C01：模型与精确语义等价验证 | plan:P09-T010/* | <code>/usr/bin/xcrun swift test --filter C01Tests --scratch-path /tmp/monacode-planctl/P09-T010.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-027 | TODO | 执行 C02：环境、区域设置、时钟、熵与内建能力等价验证 | plan:P09-T011/* | <code>/usr/bin/xcrun swift test --filter C02Tests --scratch-path /tmp/monacode-planctl/P09-T011.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-028 | TODO | 执行 C03：投影、布局、滚动与几何等价验证 | plan:P09-T012/* | <code>/usr/bin/xcrun swift test --filter C03Tests --scratch-path /tmp/monacode-planctl/P09-T012.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-029 | TODO | 执行 C04：公开声明、注册表、选项、主题、本地化与运行时替代闭环 | plan:P09-T013/* | <code>/usr/bin/xcrun swift test --filter C04Tests --scratch-path /tmp/monacode-planctl/P09-T013.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-030 | TODO | 执行 C05：保留功能与差异编辑等价验证 | plan:P09-T014/* | <code>/usr/bin/xcrun swift test --filter C05Tests --scratch-path /tmp/monacode-planctl/P09-T014.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-031 | TODO | 执行 C06：Provider、LSP、代码片段与 Markdown 等价验证 | plan:P09-T015/* | <code>/usr/bin/xcrun swift test --filter C06Tests --scratch-path /tmp/monacode-planctl/P09-T015.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-032 | TODO | 执行 C07：原生输入、传输、无障碍与工作区编辑等价验证 | plan:P09-T016/* | <code>/usr/bin/xcrun swift test --filter C07Tests --scratch-path /tmp/monacode-planctl/P09-T016.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-033 | TODO | 执行 C08：渲染器正确性与冻结分支等价验证 | plan:P09-T017/* | <code>/usr/bin/xcrun swift test --filter C08Tests --scratch-path /tmp/monacode-planctl/P09-T017.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-034 | TODO | 执行 C09：交付视图、宿主、生命周期、服务与资源边界验证 | plan:P09-T018/* | <code>/usr/bin/xcrun swift test --filter C09Tests --scratch-path /tmp/monacode-planctl/P09-T018.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-035 | TODO | 执行 C10：发布包、API、依赖、资源、哈希与许可证闭环 | plan:P09-T019/* | <code>/usr/bin/xcrun swift test --filter C10Tests --scratch-path /tmp/monacode-planctl/P09-T019.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-036 | TODO | 执行 P00：冷启动 | plan:P09-T030/* | <code>/usr/bin/xcrun swift test --filter P00WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T030.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-037 | TODO | 执行 P01：模型加载 | plan:P09-T031/* | <code>/usr/bin/xcrun swift test --filter P01WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T031.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-038 | TODO | 执行 P02：输入与撤销 | plan:P09-T032/* | <code>/usr/bin/xcrun swift test --filter P02WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T032.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-039 | TODO | 执行 P03：批量编辑 | plan:P09-T033/* | <code>/usr/bin/xcrun swift test --filter P03WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T033.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-040 | TODO | 执行 P04：垂直滚动 | plan:P09-T034/* | <code>/usr/bin/xcrun swift test --filter P04WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T034.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-041 | TODO | 执行 P05：长行 | plan:P09-T035/* | <code>/usr/bin/xcrun swift test --filter P05WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T035.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-042 | TODO | 执行 P06：换行与调整尺寸 | plan:P09-T036/* | <code>/usr/bin/xcrun swift test --filter P06WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T036.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-043 | TODO | 执行 P07：装饰项 | plan:P09-T037/* | <code>/usr/bin/xcrun swift test --filter P07WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T037.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-044 | TODO | 执行 P08：查找与替换 | plan:P09-T038/* | <code>/usr/bin/xcrun swift test --filter P08WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T038.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-045 | TODO | 执行 P09：多光标与代码片段 | plan:P09-T039/* | <code>/usr/bin/xcrun swift test --filter P09WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T039.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-046 | TODO | 执行 P10：差异与多重差异 | plan:P09-T040/* | <code>/usr/bin/xcrun swift test --filter P10WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T040.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-047 | TODO | 执行 P11：Provider 与 LSP | plan:P09-T041/* | <code>/usr/bin/xcrun swift test --filter P11WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T041.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-048 | TODO | 执行 P12：共享模型 | plan:P09-T042/* | <code>/usr/bin/xcrun swift test --filter P12WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T042.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-049 | TODO | 执行 P13：输入法与无障碍查询 | plan:P09-T043/* | <code>/usr/bin/xcrun swift test --filter P13WorkloadTests --scratch-path /tmp/monacode-planctl/P09-T043.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-050 | TODO | 执行生命周期、24 小时浸泡、Sanitizer 与验证分层测试 | plan:P09-T050/* | <code>/usr/bin/xcrun swift test --filter LifecycleSoakSanitizerTests --scratch-path /tmp/monacode-planctl/P09-T050.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-051 | TODO | 执行故障注入与算法复杂度门禁 | plan:P09-T051/* | <code>/usr/bin/xcrun swift test --filter FailureAndComplexityTests --scratch-path /tmp/monacode-planctl/P09-T051.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-052 | TODO | 在不修改源码的条件下验证冻结的阶段 03 渲染器决策 | plan:P09-T052/* | <code>/usr/bin/xcrun swift test --filter RendererDecisionValidationTests --scratch-path /tmp/monacode-planctl/P09-T052.GREEN.001.PROC.001</code> ⇒ exit 0 | — |
| VERIFY-053 | TODO | 汇总最终的 G5-R 全有或全无发布裁决 | plan:P09-T099/* | <code>/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs</code> ⇒ exit 0 | — |
| MOBILE-001 | TODO | iOS 26+ UIKit 适配器 | mobile:00/* | <code>/usr/bin/test -d Sources/MonaCodeMobile</code> ⇒ exit 0 | — |
| MOBILE-002 | TODO | iPadOS 26+ UIKit 适配器 | mobile:01/* | <code>/usr/bin/test -d Sources/MonaCodeMobile</code> ⇒ exit 0 | — |
| MOBILE-003 | TODO | 触控与软键盘合同 | mobile:02/* | <code>/usr/bin/test -d Sources/MonaCodeMobile</code> ⇒ exit 0 | — |
| MOBILE-004 | TODO | 移动端剪贴板、拖放、无障碍与设备性能基线 | mobile:03/* | <code>/usr/bin/test -d Sources/MonaCodeMobile</code> ⇒ exit 0 | — |
<!-- MONACODE_TASKS:END -->

## 完成定义

仅当同一验证源码集摘要下的所有适用条件全部通过时，任务才可标记为 `DONE`：

1. 每个归属本任务的合同标识都具有生产实现，或具有 G6-R 固定并接受的精确原生适配实现。
2. 实现已接入公开执行路径或宿主执行路径；仅有声明、仅有构造器、仅有注册表、仅有测试夹具或无法到达的实现均不算完成。
3. 自动化行为测试覆盖任务行中指定的成功、边界与失败路径。
4. 存在 Monaco 参照实现时，Monaco 差分探针通过；采用已接受的原生替代方案时，平台原生验收通过。
5. 所有必需的性能单元均在合格环境中通过冻结的 G6-R 阈值。
6. 证据记录的验证源码集摘要及精确命令与本台账一致。
7. 治理检查器、冻结合同验证器及相关仓库测试门禁全部通过。

计划构建、Schema 验证、生成的声明、已通过的共享门禁和历史发布证据，只能证明各自的交付物，不能单独证明产品行为已经完成。

## 构建与验证

```bash
/usr/bin/xcrun swift build
/usr/bin/xcrun swift test --skip Soak4HourTests
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/check-project-governance.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tests/PlanStructureTests/ProjectGovernanceTests.mjs Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
/opt/homebrew/Cellar/node/26.7.0/bin/node docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs
git diff --check
```

命令的精确验收结果以对应任务行及其摘要绑定证据为准。产品缺口探针返回非零退出码，或当前限定范围内的 Swift Diff 断言失败，均不代表仓库整体通过。

## 合同与历史

- [G6-R 冻结合同及采纳入口](docs/contracts/monaco-editor-0.56.0/g6-r/README.md)
- [G6-R 实施计划清单](docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-implementation-plan-manifest.json)
- [实施阶段来源索引](docs/implementation-phases/README.md)
- [非权威归档索引](docs/archive/README.md)
