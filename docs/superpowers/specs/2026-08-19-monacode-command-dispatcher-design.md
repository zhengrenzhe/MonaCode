# MonaCode Command Dispatcher — Design Spec

**日期**: 2026-08-19
**缺口**: A3（`docs/equivalence/equivalence-gap.md` §6）—— commandId → 模型编辑/选区变更的执行半边缺失。
**范围**: 只做 dispatcher 组件本身，TDD 隔离验证（不接 NSView keyDown = A1；不接 undo 栈 = B1a）。
**事实状态**: 全部基于源码核实 + 实证（§8）。**无推测、无未决开放问题**。
**架构**: 候选 (i)——新 `MonaCommandDispatcher` 兄弟类型，归属 `MonaCodeEditorView.performAttach`（§3）。

---

## 1. 目的与范围

键盘管线已能解析出 `commandId`（`MonaKeybindingResolver`/`MonaCompositionArbiter` 返回 `commandId: String?`），但**无人把 commandId 执行成模型编辑或选区变更**。本 spec 定义一个**薄 dispatcher** 把 commandId→handler 跑出来。它填补的正是 `MonaInstanceICodeEditor.executeCommand(source, Any?)->Bool`（`MonaEditorInstanceAdapters.swift:272` 协议声明、全仓无实现）+ `MonaQuickCommandFeature.invokeCommand` 只查 enablement 不执行（`:192-202`）的缺口。

**In scope（v1）**：`MonaCommandDispatcher` 类型（Core, Foundation-only）+ `MonaCommandContext` value + 9 个 core command handler（§4.5），Foundation-only TDD（MonaCodeTests）。

**Out of scope（明确排除，附事实理由）**：
- NSView `keyDown` 接线（= A1 驱动层）；`MonaCodeEditorView` conform `MonaInstanceICodeEditor`（= A2）
- undo/redo 真实现（= B1a：`MonaUndoRedoStack` 接 push 路径；v1 edit 经同一条 gateway 但"可撤销"要 B1a）
- `IEditor.executeCommand(source, Any?)` 公共面填充（= A2；command 对象 `Any?` 面，与内部 commandId:String dispatcher 两回事）
- paste/cut/copy（AppKit `MonaPasteboardGateway` 依赖）；find（= B1b）；IME `interpretKeyEvents`（= A5）
- `insertText`/`selectAll`（**不在冻结命令 id**，§8.9；deferred）
- `*Select`（Shift 选区扩展）命令（冻结但需 `moveSelections` 保留 anchor + 手动 tx，非 `commitCaretMove` 坍缩；v1 排除，§4.5）
- 多光标 move（v1 单光标，§4.4）

---

## 2. Ground truth（设计依据，详见 §8 事实附录）

### 2.1 monaco 真实架构（拉取 monaco-editor@0.56.0 ESM + vscode 源验证）
- **无 dispatcher 类型**：扁平 `CommandsRegistry`（`Map<id, LinkedList<{id,handler,metadata?}>>`）+ `ICommandService`（DI service，`accessor.get(ICommandService)` 全局共享）+ `KeybindingsRegistry`（分离）+ `KeybindingResolver`。`ICommandService.executeCommand` = `CommandsRegistry.getCommand(id)` + `instantiationService.invokeFunction(handler, args)`——本质"包裹 registry lookup + invoke"的 executor。
- handler 签名 `(accessor: ServicesAccessor, ...args) => any`，DI 是服务定位器 `accessor.get(SERVICE_ID)`。
- `type` 是注册命令（非特例）；核心命令是 `EditorCommand` 薄壳，逻辑在 `runCoreEditorCommand(editor, viewModel, args)`。
- 光标宿主 = `CursorsController._cursors: CursorCollection`；undo 栈 = Model.EditStack + IUndoRedoService。

### 2.2 MonaCode 已有架构（约束，已核实）
- **`MonaAXMutationGateway`** = executor 类型先例（`final class` :157，`register` :241/247，`perform` :262，post-commit `dispatchPostCommitHandlers` :445，`import AppKit` :27）。构造注入（init :221-235），弱引用长生命周期依赖（:163-178）。
- **归属先例**：`MonaAXMutationGateway` 由 `MonaCodeEditorView.performAttach(model:)`（:343，紧跟 `inputBarrier`:332）构造；视图存 `internal private(set) var axMutationGateway?`（:165）；`performDetach`（:381/387）释放；`MonaEditorAttachment`（:132/188）编排生命周期**不构造协作者**。
- **`MonaModelInputBarrier`** = 编辑原子咽喉（`prepare` :136 / `commit(prepared, overlapPolicy:)` :167 / `commit(plan, overlapPolicy:)` :209 便捷版）；`commit` 体（:190-196）`gateway.beginTransaction()`→`transaction.prepareEdits(ops)`→`transaction.prepareSelections(selections)`→`commit()`——**edit 后回写 `gateway.lastCommittedSelections`**；outcome `.applied(selections:)`/`.dropped`/`.rolledBack`。
- **`MonaTransactionGateway`**：`lastCommittedSelections`（`public private(set)`，最近提交选区真值）；`beginTransaction()`/`commit()`/`rollback()`。`MonaEditTransaction.prepareSelections(_:)`（:192）。
- **`MonaCaretOperationsFeature`**（Foundation-only :31，`final class` :93，无状态 `init()` :172）：纯函数 `moveSelections(_ selections:, target:, lineCount:, maxColumnOf:, viewportTopLine:=1, viewportBottomLine:=1)` :215；`commitCaretMove(_ position:, target:, gateway:, lineCount:, maxColumnOf:, ...)` :245（体内 beginTransaction→prepareSelections→commit→返 lastCommittedSelections）。`MonaCaretMoveTarget`（:343-380）case `.line(n)`/`.wrappedLine(n)`/`.character(n)`/`.page(lines,pageSize)`/`.viewPortTop/Center/Bottom`/`.documentStart/End`/`.lineStart`/`.lineEnd`——**无 left/right/up/down**。
- **无 ServicesAccessor / DI accessor**：grep `ServicesAccessor|accessor.get|createDecorator|instantiationService` 全仓 **0 命中**。DI 全构造注入。
- `MonaCommandRegistry` lookup-only，冻结命令 id 字符串（§8.9）。
- **无 char 级 `deleteLeft`/`deleteRight` helper**：只有 `deleteWordLeft/Right`/`deleteLines` 等（§8.10）——delete 命令要**自己实现跨行删除**。
- `MonaUndoRedoStack` 真实现（经 `MonaTransactionGateway`）但**未接 model**（B1a）。

### 2.3 monaco oracle 实证（§8.11）
monaco-editor@0.56.0 + jsdom 在 Node 真能跑 `editor.trigger('keyboard', '<cmd>', args)` + `getValue()`/`getSelections()`；9 命令 9/9 pass，3 次运行确定一致，model 级 `applyEdits` 与 editor 级 `trigger('type')` 交叉验证一致。→ **§6 用真差分，不退化弱断言**。

---

## 3. 架构决策（对抗式三选一，从事实推出候选 i）

**选 (i) 新 `MonaCommandDispatcher` 兄弟类型**，否决 (ii) 泛化 AX / (iii) 宿主闭包。事实理由：

1. **AX 先例一致**：MonaCode 已为 AX 路径选 executor 类型（`MonaAXMutationGateway` final class + register+perform+post-commit-dispatch）。(i) 是同形兄弟。(ii)/(iii) 偏离先例。
2. **Foundation-only 可测**：(i) 依赖（model/inputBarrier/transactionGateway/caretOps）全 Core + Foundation-only（§8.1）→ 放 Core `import Foundation` 可在 MonaCodeTests TDD。(ii) 拖入 `import AppKit`（`MonaAXMutationGateway:27`）、(iii) 拖入 NSView（`MonaCodeEditorView:203`）——破坏 Core 可测。
3. **monaco 保真（无 accessor 下的最佳等价）**：`ICommandService.executeCommand`=`getCommand`+`invokeFunction`（executor）。MonaCode 无 DI accessor（grep 0 命中）→ 无法做 DI service；(i) 的构造注入 executor 包裹 registry-lookup + handler-dispatch 是 ICommandService 在无 accessor 下的最自然等价。(iii) 省略 executor 层（monaco 有）→ 保真度更低。
4. **避 (ii) 硬伤**：AX dispatch 是 post-barrier-commit（`:314-328`）；非 mutating 命令（`MonaCaretOperationsFeature:105-130` 声明的 cursorMove/scroll）不该过 barrier。(ii) 会把它们拖入伪造事务；(i) 让 mutating→barrier、非 mutating→直调，不污染任一路径。
5. (i) 与 AX 的薄重复（一个 dict+lookup）是正常服务分离（monaco CommandsRegistry 也独立于 AX 路径）。

**权衡明示**：(i) 不如 (iii) 贴 monaco"无 dispatcher 类型"原貌，但 (iii) 牺牲 Foundation-only 可测性。MonaCode 的 Core 必须 Foundation-only TDD（`MonaCommandRegistry:19`、`MonaCaretOperationsFeature:31` 均 Foundation-only）——(i) 是保真度与可测性的正确交点。

**handler 模型：`(MonaCommandContext, Any?) -> Void`，dispatcher 每次 execute 从构造注入依赖构建 context value 传给 handler。** 不用 ServicesAccessor（仓库无）；不让 handler 闭包捕获 dispatcher（retain cycle）；context 是固定 value 非 locator（monaco accessor 的 Swift 适配，与值类型+构造注入 idiom 一致）；handler 可独立单测。

**`type` = 注册命令 handler（非特例）**：用冻结的 `"type"` id（:576）。

---

## 4. 设计

### 4.1 MonaCommandDispatcher 类型 + 归属

```swift
// Sources/MonaCode/Input/MonaCommandDispatcher.swift  (Core, Foundation-only — §8.1)
public final class MonaCommandDispatcher {
    private let model: MonaCodeModel
    private let inputBarrier: MonaModelInputBarrier
    private let transactionGateway: MonaTransactionGateway   // 经 inputBarrier.gateway 可达（§8.4）
    private let caretOps: MonaCaretOperationsFeature         // 无状态（§8.7 init()）
    private var handlers: [String: (MonaCommandContext, Any?) -> Void] = [:]
    public init(model:, inputBarrier:, transactionGateway:, caretOps:)   // + register 9 core commands
    public func register(_ commandId: String, handler: @escaping (MonaCommandContext, Any?) -> Void)
    public func execute(_ commandId: String, args: Any? = nil) -> Bool   // 查表→构建 context→调；未知 id→false
    public func contains(_ commandId: String) -> Bool
}
```

**归属（跟 AX 先例，零偏离）**：
- 构造在 `MonaCodeEditorView.performAttach(model:)`（:290），紧跟 `inputBarrier`（:332）/`axMutationGateway`（:343）——dispatcher 模型相关。
- 视图存 `internal private(set) var commandDispatcher: MonaCommandDispatcher?`（平级 `axMutationGateway` :165）。
- `performDetach()`（:381）内 `commandDispatcher = nil`（平级 `axMutationGateway = nil` :387）。
- `MonaEditorAttachment`（:132/188）编排生命周期，不构造 dispatcher。
- 依赖：model（weak）、inputBarrier（weak，:332 已构造）、transactionGateway（经 `inputBarrier.gateway` :104/116，或直接注入）、caretOps（无状态 `init()` :172）。构造后宿主调 `register(_:handler:)` 注册（同 AX `registerPressHandler` :241）。
- **dispatcher 是 Core 类型，由 AppKit 视图在 performAttach 构造**——Core 类型被 AppKit 宿主构造注入，与视图构造 `MonaModelInputBarrier`（Core）同形；TDD 时在 MonaCodeTests 直接构造 dispatcher（不经视图）。

### 4.2 MonaCommandContext value

```swift
public struct MonaCommandContext {
    public let model: MonaCodeModel                  // getValue()/getLineCount()/getLineMaxColumn(_:)/getFullModelRange() — §8.5
    public let inputBarrier: MonaModelInputBarrier   // commit(_:overlapPolicy:) 便捷版 → .applied(selections:) — §8.2
    public let transactionGateway: MonaTransactionGateway // lastCommittedSelections(public private(set)) — §8.4
    public let caretOps: MonaCaretOperationsFeature   // commitCaretMove(_:target:gateway:lineCount:maxColumnOf:) — §8.7
    public let args: Any?                            // type 的 ["text":String] / cursorEnd 的 ["sticky":Bool]（§8.9 schema）
}
```
每次 `execute` 构建，传给 handler；值类型避免 retain cycle。

### 4.3 选区真值来源（无光标宿主的解法）

dispatcher 不持光标，读 `transactionGateway.lastCommittedSelections`（`public private(set)`）作当前选区真值。edit 命令经 `inputBarrier.commit`（体内 `prepareSelections` :196）**也回写**它 → edit/selection 命令读同一真值。**空时默认** `MonaSelection(anchor: MonaPosition(line:1,column:1), activePosition: MonaPosition(line:1,column:1))`（§8.8；monaco 初始光标 (1,1)，oracle test4 验证）。

### 4.4 Edit 命令（经 inputBarrier）

`type`（args=`["text":"x"]`）：读 `lastCommittedSelections`（空则默认）→ 每选区建 `MonaCursorInputEdit(range: sel.range, text: args.text)`（kind/forceMoveMarkers/tabstops 默认，§8.3）→ `MonaMultiCursorInputPlan(primary: edits.first!, secondary: Array(edits.dropFirst()))`（`secondary` 默认 `[]`）→ `inputBarrier.commit(plan, overlapPolicy: .reject)`（便捷版 §8.2）→ `.applied` 成功 / `.dropped`/`.rolledBack` 失败。**`edits.first!` 前需 guard 非空**（默认 seed 保证 ≥1，仍 guard，§8 硬伤 9）。

`deleteLeft`/`deleteRight`：**无现成 char 级 helper**（§8.10 只有 word/line delete）。dispatcher 内**自己算删除 range**：选区非空→删选区内容（空文本）；选区空→deleteLeft 删 `start` 退一字符（行首则 join 上一行——**跨行删除需实现**），deleteRight 删 `end` 进一字符。同 plan+commit。**这是真实现复杂度，非接线**——writing-plans 需单列任务。

### 4.5 Selection 命令（经 commitCaretMove + gateway，不改文本；v1 单光标）

读当前 position（`lastCommittedSelections` 首 selection 的 `activePosition`，空则 (1,1)），调：
```swift
caretOps.commitCaretMove(position, target: <映射>, gateway: transactionGateway,
    lineCount: model.getLineCount(), maxColumnOf: { model.getLineMaxColumn($0) })  // §8.5/§8.7
```

| 命令 | target |
|---|---|
| `cursorLeft` | `.character(-1)` |
| `cursorRight` | `.character(1)` |
| `cursorUp` | `.line(-1)` |
| `cursorDown` | `.line(1)` |
| `cursorEnd` | `.lineEnd`（**sticky 参数忽略**——`MonaCaretMoveTarget.lineEnd` 无关联值、move API 无 sticky；等同 monaco sticky=false 默认，oracle test4 验证 cursorEnd→行末） |
| `cursorHome` | `.lineStart` |

> `cursorUp/Down`=`.line(±1)` 需 `lineCount`+`maxColumnOf`（`getLineCount`/`getLineMaxColumn`，模型派生非像素几何）→ Foundation-only 可跑。
> **v1 单光标**：`commitCaretMove` 移**一个** position（多光标会丢次选区）。多光标 move 需 `moveSelections`（纯）+ 手动 transaction（beginTransaction→prepareSelections→commit），deferred。
> **`*Select`（Shift 扩展）命令排除**：冻结着（§8.9 :201-224）但需 `moveSelections`（保留 anchor）+ 手动 tx，非 `commitCaretMove`（坍缩）。deferred。

### 4.6 v1 命令集（9 个冻结 id，§8.9）

| commandId | kind | 经 | args | 冻结行 |
|---|---|---|---|---|
| `type` | edit | inputBarrier | `["text":String]` | :576 |
| `deleteLeft` | edit | inputBarrier（自实现跨行删除） | – | :260 |
| `deleteRight` | edit | inputBarrier（自实现跨行删除） | – | :261 |
| `cursorLeft` | selection | `.character(-1)` | – | :206 |
| `cursorRight` | selection | `.character(1)` | – | :218 |
| `cursorUp` | selection | `.line(-1)` | – | :223 |
| `cursorDown` | selection | `.line(1)` | – | :200 |
| `cursorEnd` | selection | `.lineEnd`（sticky 忽略） | `["sticky":Bool]`(忽略) | :202 |
| `cursorHome` | selection | `.lineStart` | – | :204 |

**排除 v1**：`insertText`/`selectAll`（不在冻结 id，§8.9）；`*Select`（需扩展 move+手动 tx）；`undo`/`redo`（B1a）；`cut`/`copy`/`paste`（AppKit）；`find`（B1b）。

---

## 5. 硬真相（影响 v1 验证范围）

1. **无光标宿主 → selection 真值从 `gateway.lastCommittedSelections` 读**（edit 经 inputBarrier 也回写）。隔离测试可空→默认 (1,1)；端到端 live 需 A1 驱动层喂数区。
2. **undo 依赖 B1a**：edit 经同一条 `MonaTransactionGateway`，但"可撤销"要 B1a 接 `MonaUndoRedoStack`。
3. **delete 无 helper → 自实现跨行删除**（§4.4）。
4. **v1 单光标 + sticky 忽略 + 无 *Select**（§4.5）。

---

## 6. 验证策略（真差分，实证可行 §8.11）

**oracle harness**（实证跑通）：monaco-editor@0.56.0 + jsdom 在 Node，`editor.trigger('keyboard', '<commandId>', args)` + `editor.getModel().getValue()` + `editor.getSelections()`。形状 `(initial_text, initial_cursor, command, args) → {value: String, selections: [sel]}`。

**TDD（Red→Green→Commit）**：每命令一 fixture——同初始文本+选区+命令+args，monaco 跑出 oracle `{value, selections}`，冻结成 `Tests/Fixtures/CommandDispatcherFixtures/`；MonaCode `dispatcher.execute` 后比对 `model.getValue()` + `gateway.lastCommittedSelections`。

实证已证：9/9 pass、3 次确定一致、model 级 `applyEdits` 与 editor 级 `trigger('type')` 交叉验证一致（§8.11）。harness 脚本在 `/tmp/monaco-oracle-test/`（`test4-all9.mjs`/`test5-crossval.mjs`），writing-plans 应将其 vendor 进 `Tests/`。

---

## 7. 已收敛（原开放问题全部由事实解决）

1. ~~结构 i/ii/iii~~ → **(i)**，对抗式事实推出（§3）。
2. ~~归属~~ → view performAttach，AX 先例（§4.1）。
3. ~~oracle 可行性~~ → **可行**，实证 9/9 确定（§6/§8.11）。
4. ~~delete helper~~ → 无，自实现跨行（§4.4）。
5. ~~cursorEnd sticky~~ → 忽略（无 API 落点；等同 monaco 默认 false，oracle 验证）。
6. ~~cursorUp/Down 几何~~ → `.line(±1)` 需 lineCount+maxColumnOf（模型派生），Foundation-only 可跑。
7. ~~selection seed~~ → `lastCommittedSelections`，空默认 (1,1)。
8. ~~单光标 vs 多光标~~ → v1 单光标；多光标 deferred。
9. ~~*Select~~ → 排除（需扩展 move+手动 tx）。
10. ~~`insertText`/`selectAll`~~ → 不在冻结 id，deferred。

**无未决开放问题。**

---

## 8. 事实依据附录（全部 file:line 源码核实 + 实证，无推测）

### 8.1 模块归属（全 Core，Foundation-only）
`MonaCodeModel`(Model/)、`MonaModelInputBarrier`/`MonaPreparedMultiCursorInput`/`MonaModelInputBarrierOutcome`(Input/)、`MonaMultiCursorInputPlan`/`MonaCursorInputEdit`/`MonaMultiCursorInputKind`/`MonaOverlapPolicy`(Input/)、`MonaTransactionGateway`(Transactions/)、`MonaCaretOperationsFeature`/`MonaCaretMoveTarget`(Features/)。四文件 grep `^import AppKit` 均**无命中**。

### 8.2 inputBarrier（`MonaModelInputBarrier.swift`）
`prepare(_:)->MonaPreparedMultiCursorInput`(:136)；`commit(_:overlapPolicy:)->MonaModelInputBarrierOutcome`(:167，体 :190-196 `beginTransaction`→`prepareEdits`→`prepareSelections`→`commit`)；`commit(_:overlapPolicy:)`便捷(:209)。Outcome `.applied(selections:)`(:70)/`.dropped(reason:)`(:76)/`.rolledBack(reason:)`(:82)。

### 8.3 plan/edit（`MonaMultiCursorInputPlan.swift`）
`MonaMultiCursorInputKind`：`.text`/`.snippet`/`.clipboard`/`.composition`(:37-49)。`MonaCursorInputEdit(range:text:kind:forceMoveMarkers:tabstops:)`，后三**均默认**(:123)。`MonaMultiCursorInputPlan(primary:secondary:)`，`secondary`**默认 `[]`**(:172)。

### 8.4 transactionGateway（`MonaTransactionGateway.swift`）
`public private(set) var lastCommittedSelections: [MonaSelection]`(~:63)；`beginTransaction()->MonaEditTransaction`(:93)；`commit(_:)`(117)/`rollback(_:)`(171)。`MonaEditTransaction.prepareSelections(_:)`(`MonaEditTransaction.swift:192`)+`prepareEdits(_:)`。

### 8.5 model 只读 API（`MonaCodeModel.swift`）
`getValue()`(:129)/`getLineCount()`(:203)/`getLineContent(_:)`(:208)/`getLineLength(_:)`(:213)/`getLineMaxColumn(_:)`(:240)/`getFullModelRange()`(:331)。

### 8.6 无 ServicesAccessor
grep `ServicesAccessor|accessor.get|createDecorator|instantiationService` 全仓 0 命中；`MonaServiceCollection`(:38)是定义注册表非实例；`ICommandService` 是定义非实现类。

### 8.7 caretOps（`MonaCaretOperationsFeature.swift`）
Foundation-only(:31,`import Foundation`)；`final class`(:93)；无状态`init()`(:172)。`MonaCaretMoveTarget`(:36)case(:343-380)：`.line(n)`/`.wrappedLine(n)`/`.character(n)`/`.page(lines,pageSize)`/`.viewPortTop/Center/Bottom`/`.documentStart/End`/`.lineStart`/`.lineEnd`（**无 left/right/up/down**）。`moveSelections(...)`(:215)纯；`commitCaretMove(_ position:, target:, gateway:, lineCount:, maxColumnOf:, viewportTopLine:=1, viewportBottomLine:=1)`(:245)体内 beginTransaction→prepareSelections→commit→返 lastCommittedSelections。声明非 mutating 命令 id(:105-130)。

### 8.8 position/selection init
`MonaPosition.init(line:column:)`(`MonaPosition.swift:56`)；`MonaSelection.init(anchor:activePosition:)`(`MonaSelection.swift:63`)。

### 8.9 冻结命令 id（`MonaCommandRegistry.swift` `frozenIdentities`）
v1 全命中：`type`(:576,hasArgs,schema text:string)/`deleteLeft`(:260)/`deleteRight`(:261)/`cursorLeft`(:206)/`cursorRight`(:218)/`cursorUp`(:223)/`cursorDown`(:200)/`cursorEnd`(:202,args sticky:bool)/`cursorHome`(:204)。`*Select`：`cursorDownSelect`(:201)/`cursorEndSelect`(:203)/`cursorHomeSelect`(:205)/`cursorLeftSelect`(:207)/`cursorRightSelect`(:219)/`cursorUpSelect`(:224)。`insertText`/`selectAll`：grep **无命中**。

### 8.10 无 char 级 delete helper
grep `deleteLeft|deleteRight|DeleteOperations|func delete` 仅命中 `deleteWordLeft/Right`(`MonaWordOperationsFeature.swift:261,298`)/`deleteInsideWord`(:336)/`deleteLines`(`MonaLinesOperationsFeature.swift:287`)/`deleteWordPart*`/`MonaPieceTree.delete`(:205)/`MonaDecorationTree.delete`(:167)/冻结 id(:260-261)。**无 char 级实现**。

### 8.11 monaco oracle 实证（Node v26.7.0 + jsdom + monaco@0.56.0，真跑）
- model 级 DOM-free（jsdom polyfill，不调 `editor.create`）：`createModel`+`applyEdits`/`pushEditOperations`/`findMatches` 全跑通（`/tmp/monaco-oracle-test/test2-model-jsdom.mjs`）。
- editor 级（jsdom + `editor.create(jsdomEl, model)` + `editor.trigger('keyboard', cmd, args)`）：9 命令 9/9 pass（`test4-all9.mjs`：type/deleteLeft/deleteRight/cursorLeft/Right/Up/Down/End/Home 各产出文本+选区，与预期符）。
- 确定性：同序列 3 次运行完全一致（`test5-crossval.mjs`，`DETERMINISTIC: YES`）。
- 交叉验证：model 级 `applyEdits` 与 editor 级 `trigger('type')` 同输入产出相同文本（`CROSS_VALIDATE_MATCH: YES`）。
- 机制：`editor.trigger('keyboard', '<commandId>', args)` 是 monaco 官方命令入口（与真实键盘走同一 `CoreNavigationCommands`/`CoreEditingCommands`），故为**真 oracle**。polyfill 成本：CSS no-op ESM hook + jsdom window/document/matchMedia stub + 安全 perf polyfill（详见 agent 报告）。
