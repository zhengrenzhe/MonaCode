# MonaCode 进度真源（唯一真源）

> 本文件是 MonaCode 开发进度的**唯一真源**，替代一切已删除的治理/过程文档。
> 对标基准：monaco-editor@0.56.0 公开接口/功能（`reference/` 下的 .d.ts）。
> 证据基线：`CHECKLIST-monaco.md`（501 条 API/功能）+ `INVENTORY-core.md` + `INVENTORY-appkit.md`（逐文件 file:line 证据）。
> 复盘日期：2026-08-22。

## 0. 项目目标

MonaCode 是面向 Apple 平台、Swift 原生开发的代码编辑器组件，对标 monaco-editor@0.56.0 的行为与公开接口。当前发布目标 **arm64 macOS**；iOS/iPadOS 属后续版本。提供编辑器组件 + LSP 的 API/功能侧面对标。

---

## 1. 总体真实进度

| 目标 | 文件数 | REAL | PARTIAL | STUB/DATA | 真实率 |
|---|---|---|---|---|---|
| Core（Sources/MonaCode） | 174 | 152 | 10 | 3 STUB + 9 DATA | 87% |
| AppKit+SwiftUI+Sample | 83 | 76 | 3 | 4 STUB | 92% |
| **合计** | **257** | **228** | **13** | **16** | **89%** |

**结论**：底层与编辑器边界大体真实（Piece Tree、命令、输入屏障、事务、渲染管线、AppKit 输入/AX/传输都真），但**运行起来不对**：① 文字模糊；② 不可编辑；③ 语言智能层未接通。**没有纯注册空壳**——每个 Feature 文件都有真实计算逻辑，缺的是"最后一公里"接线与数据源。

---

## 2. 两个已确认的运行期缺陷（最高优先）

### BUG-1：Retina 文字模糊（已确认根因，单点）

`MonaRenderSurface.init`（`Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift:86-131`）把 `scaleFactor` 仅作属性存储（:92），**位图缓冲按 `width×height` 分配（:103-108）、`CGContext` 按 `width×height` 创建（:110-118），全文件无 `ctx.scaleBy`**。`MonaCoreGraphicsRenderer.tile(...)` 始终创建 `256×256` 与 scale 无关（`MonaCoreGraphicsRenderer.swift:149-153`）。`draw(_:)` 读了 `window?.backingScaleFactor`（`MonaCodeEditorView.swift:726`）并塞进 tile key（:762），但位图未被缩放。2× Retina 上 256px 位图被上采样到 512 设备像素 → 模糊。
**修复点**：`MonaRenderSurface` 位图尺寸乘 `scale` + paint CTM `scaleBy`；渲染管线是唯一缩放缺陷。

### BUG-2：不可编辑（首响应者缺口 + 待运行期确认）

编辑输入路径代码完整：`keyDown`→`dispatchKeyEvent`→`"type"` handler→`inputBarrier.commit`→事务 gateway→Piece Tree 变更→`onDidChangeContent`→`observeContentChange`→`needsDisplay`（`MonaCodeEditorView.swift:835/888`、`MonaCommandDispatcher.swift:68-74`、`MonaModelInputBarrier.swift:167-205`、`MonaEditorAttachment.swift:146-199`）。
但 `makeFirstResponder(view)` **仅在 `MonaEditorInstanceAdapters.focus()`（:780/:1046）调用**；sample host `main.swift` 只 `makeKeyAndOrderFront(nil)`（:102），未 makeFirstResponder/setInitialFirstResponder；SwiftUI controller 也未接 AppKit 焦点（`MonaSwiftUIEditorController.swift` 不调 makeFirstResponder）。因此打字能否工作取决于 AppKit 响应者链是否自动选中该视图——非保证。
**修复点**：sample host（及视图 `mouseDown`/控制器）显式 `makeFirstResponder(editor)`；并运行期追踪 keystroke 是否真到 `keyDown`。

---

## 3. 按 monaco 命名空间的对照复盘

图例：✅已实现 · 🟡部分/接线缺 · ❌未实现/空 · ⚪真实但运行期不触发

| monaco 命名空间 | 条目 | MonaCode 状态 | 证据/缺口 |
|---|---|---|---|
| **types**（Uri/Position/Range/Selection/Token/KeyCode/KeyMod/Marker/IMarkdownString/IKeyboardEvent/IMouseEvent/IScrollEvent） | 17 | ✅ | `Base/`：MonaPosition/MonaRange/MonaSelection/MonaToken/MonaURI/MonaKeyCode/MonaKeyMod/MonaMarker 全 REAL |
| **platform**（Environment/IDisposable/IEvent/Emitter/CancellationToken/MarkerSeverity/MarkerTag/Thenable/ITrustedTypePolicy） | 12 | 🟡 | MonaDisposable/MonaEmitter/MonaEvent/MonaCancellation/MonaClock REAL；全局 MonacoEnvironment 未接 host |
| **editor — 创建**（create/createDiffEditor/createMultiFileDiffEditor） | — | ✅ | `MonaEditorFactory.swift` create/createDiffEditor/createMultiFileDiffEditor REAL |
| **editor — ITextModel** | — | 🟡 | 文本/编辑/查询/undo REAL（`MonaCodeModel.swift`）；**装饰查询全 stub**（:590-661 返 nil/[]）；**search 仅 literal**（regex 不在 model 层兑现，FindFeature 用 RegExp）；detectIndentation no-op（:694）；getLanguageId 恒 "plaintext" |
| **editor — IEditorOptions**（174 选项 + ~20 子选项接口） | — | ✅ | `MonaEditorOption`/`MonaOptionSnapshot`/`MonaOptionStore` REAL（174 选项） |
| **editor — ICodeEditor/IDiffEditor 实例接口** | — | 🟡 | `MonaEditorInstanceAdapters`：identity/lifetime/focus/getModel/getValue/layout REAL；**events/reveal/selection/executeCommand/executeEdits/widgets 全 stub**（fatalError/空/[]） |
| **editor — decorations**（InjectedText/GlyphMargin/OverviewRuler/Minimap decorations） | — | 🟡 | 装饰区间树/集合原语 REAL（`Model/Decorations/`）；**模型查询未接通** + 渲染层 widgets/gutters/minimap no-op |
| **editor — markers/IMarkerService** | — | 🟡 | MonaMarker 数据类型 + GotoErrorFeature 导航 REAL；setMarkers/IMarkerService 接线未确认 |
| **editor — commands/actions/keybindings** | — | 🟡 | 9 核心命令 REAL（type/deleteLeft/deleteRight/cursor*）；379 keybinding 行 + 解析器 REAL；**其余命令仅注册身份、无 handler** |
| **editor — ViewZone/ContentWidget/OverlayWidget/GlyphMarginWidget** | — | ❌ | 实例适配器 widget add/remove 空；渲染 widget 层 no-op |
| **editor — MouseTarget** | — | 🟡 | MonaPointerEvent + barrier hitTest REAL；14 MouseTargetType 未全映射 |
| **editor — 主题/着色**（defineTheme/setTheme/colorize/colorizeElement/tokenize） | — | 🟡 | 主题注册 REAL；native colorize REAL（`Colorize/`）；tokenize 仅 plain-text 回退 |
| **editor — WebWorker**（createWebWorker/MonacoWebWorker） | — | ❌ | 无 worker 运行时 |
| **languages — 注册/配置**（register/getLanguages/onLanguage/LanguageConfiguration） | — | 🟡 | MonaLanguageRegistry REAL 但**所有内置语言 CUT**，仅 plaintext live（`:50`） |
| **languages — Monarch**（setMonarchTokensProvider/IMonarchLanguage） | — | ❌ | **无 Monarch 实现**（全库 grep 零命中） |
| **languages — tokens providers**（TokensProvider/EncodedTokensProvider/setColorMap） | — | 🟡 | 挂载点存在，无 provider；plain-text 回退 |
| **languages — 26 provider 注册+接口** | — | 🟡 | MonaProviderRegistry 30 挂载点（25 LSP-backed+5 direct）全未挂载；**Feature 计算逻辑 REAL**（filter/rank/sort/commit），但无数据源供给 |
| **languages — WorkspaceEdit/Command** | — | ✅ | MonaWorkspaceEdit/MonaHostContracts REAL |
| **workers**（IMirrorModel/IWorkerContext/createWebWorker） | 8 | ❌ | 无 worker 运行时 |
| **basic-languages**（CSS/SCSS/LESS/HTML/JSON/TypeScript/JavaScript） | 57 | ❌ | 全 CUT，无基础语言注册（`MonaLanguageRegistry.swift:50`） |
| **lsp**（MonacoLspClient/WebSocketTransport/transport） | 6 | 🟡 | Core：JSON-RPC codec/frame enc-dec/session/client/25 capability/25 provider adapter 全 REAL，**零真实 I/O**（内存 emitter 通道）；AppKit：`MonaProcessMessageTransport` 真实 Process+stdin/stdout+读线程+SIGPIPE；`MonaAppKitLSPTransportFactory` 复用之。**但未端到端接进编辑器、未配任何语言服务器** |

### 真实但运行期不触发
- `MonaMetalRenderer`：真实 Metal 实现（device/queue/shader/pipeline/render pass），默认分支 `.notTriggeredAndAbsent`，运行期不分配 Metal 资源（`MonaCodeEditorView.swift:287`）。
- `MonaAdvancedDiffEngine`/`MonaLegacyDiffEngine`：真实 DP/Myers diff，但 `MonaDiffEditorFeature` 的 diff 构造在 Core 未接（推迟到适配器）。

---

## 4. 已真实实现的核心（可信赖的地基）

- **文本缓冲**：Piece Tree（AVL 自平衡 BST，insert/delete/查询/快照）— `Model/PieceTree/`
- **事务与版本真源**：MonaTransactionGateway（版本捕获/范围校验/全有或全无/rollback/reconcile）— `Transactions/`
- **多光标输入**：MonaModelInputBarrier（overlap 解析/逆序/选区计算/原子提交）— `Input/`
- **命令分发**：9 核心命令真实变更模型 — `MonaCommandDispatcher.swift`
- **Undo/redo**：LIFO 栈经 gateway 回放 — `Model/Undo/`
- **RegExp**：完整 ECMAScript 语法 + 回溯 VM（capture/named/lastIndex；case-insensitive 仅 ASCII stub，真实 Unicode 已实现未注入）
- **Markdown**：Marked 14.0.0 GFM port + sanitizer，1602 行
- **布局/命中**：Core Text shaping、完美二叉段树 verticalIndex、geometry barrier、hitTester、scroll model — `MonaCodeAppKit/Layout/` 全 REAL
- **渲染**：CG 平铺渲染器（text/selection/decoration/overlay 真实层）+ LRU tile cache — 唯一缺陷是 backing scale
- **输入**：键盘 gateway + composition arbiter/session + pointer/scroll/contextmenu gateway + NSTextInputClient — 全 REAL
- **AX**：~16 selector + element graph + mutation gateway + focus coordinator + announcement bridge — 全 REAL
- **LSP 协议**：codec/framing/session/client/capability/adapter + Process 传输原语 — 真实但未接通
- **39 Core Features**：37 REAL（含 suggest/format/folding/inlay/semantic-tokens/document-symbol/code-lens/rename/bracket/comment/lines-ops/smart-select/snippet…），每个有真实计算逻辑，缺的是 provider 数据源

---

## 5. 下一步优先级

1. **跑通基线（清晰 + 可编辑）**——修 BUG-1（渲染位图按 scale 分配 + CTM scaleBy）+ BUG-2（显式 makeFirstResponder，并运行期确认 keystroke 到 keyDown）。让 sample host 真正可用。
2. **装饰查询接通 + 命令面补全**——把 MonaCodeModel 装饰查询接到装饰原语；补齐实例接口 events/reveal/selection/executeCommand。
3. **语言智能层**——任选一条路径：① Monarch tokenizer + 几个 basic-languages（自有高亮/分词）；或 ② 用现成 LSP（如 `sourcekit-lsp` / `typescript-language-server`）经 MonaProcessMessageTransport 接进编辑器，跑通 completion/diagnostics/hover。
4. **tokenization→渲染着色**——把 token 真正喂进渲染的 text 层（当前高亮层因 plain-text 回退而不上色）。

> 进度判定一律以本文件 + 三份证据文件为准；旧治理 verdict/ledger/probe 全部作废。
