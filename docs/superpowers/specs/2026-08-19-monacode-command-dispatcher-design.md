# MonaCode Command Dispatcher — Design Spec

**日期**: 2026-08-19
**缺口**: A3（`docs/equivalence/equivalence-gap.md` §6）—— commandId → 模型编辑/选区变更的执行半边缺失。
**范围**: 只做 dispatcher 组件本身，TDD 隔离验证（不接 NSView keyDown = A1；不接 undo 栈 = B1a）。
**事实状态**: 全部基于源码核实，证据见 §8。无推测。

---

## 1. 目的与范围

键盘管线已能解析出 `commandId`（`MonaKeybindingResolver`/`MonaCompositionArbiter` 返回 `commandId: String?`），但**无人把 commandId 执行成模型编辑或选区变更**。本 spec 定义一个**薄 dispatcher** 把 commandId→handler 跑出来。

**In scope（v1）**：`MonaCommandDispatcher` 类型 + `MonaCommandContext` value + 9 个 core command handler（§4.5），Foundation-only TDD（MonaCode Core 模块）。

**Out of scope（明确排除）**：
- NSView `keyDown` 接线（= A1 驱动层）；`MonaCodeEditorView` conform `MonaInstanceICodeEditor`（= A2）
- undo/redo 真实现（= B1a：`MonaUndoRedoStack` 接 push 路径；v1 edit 经同一条 gateway 但"可撤销"要 B1a）
- `IEditor.executeCommand(source, Any?)` 公共面（= A2；command 对象 `Any?` 面，与内部 commandId:String dispatcher 两回事）
- paste/cut/copy（AppKit `MonaPasteboardGateway` 依赖）；find（= B1b）；IME `interpretKeyEvents`（= A5）
- `insertText`/`selectAll`（**不在冻结命令 id**，见 §4.5；deferred）

---

## 2. Ground truth（设计依据，详见 §8 事实附录）

### 2.1 monaco 真实架构（拉取 monaco-editor@0.56.0 ESM + vscode 源验证）
- **无独立 dispatcher 类型**：扁平 `CommandsRegistry`（`Map<id, LinkedList<{id,handler,metadata?}>>`）+ `KeybindingsRegistry`（分离）+ `KeybindingResolver`（join）+ `ICommandService.executeCommand`（`getCommand(id)` + `invokeFunction(handler, args)`）。
- **handler 签名 `(accessor: ServicesAccessor, ...args) => any`**，DI 是服务定位器 `accessor.get(SERVICE_ID)`，但 accessor 主活是取焦点 editor；之后状态从 `editor._getViewModel()` 对象树取。
- **`type` 是注册命令**（非特例）；未命中键绑定的可打印字符走 textarea 原生 input 事件，两入口汇于 `viewModel.type`。
- **光标宿主** = `CursorsController._cursors: CursorCollection`（modelState/viewState 双份）。
- **undo 栈** = Model.EditStack + IUndoRedoService；handler 只调 `pushUndoStop()`/`executeCommands()` 控制 bracket。
- 核心命令是 `EditorCommand` 薄壳，逻辑在 `runCoreEditorCommand(editor, viewModel, args)`。

### 2.2 MonaCode 已有架构（约束，已核实）
- **`MonaAXMutationGateway`** = 已有的"commandId→handler 注册+执行"先例：String 键 `() -> Void` handler + `perform(request)`（验前置→翻 `MonaMultiCursorInputPlan`→`barrier.prepare`+`commit(.reject)`→handler 仅 `.applied` 后触发）。构造注入、弱引用。**dispatcher 镜像此模式。**
- **`MonaModelInputBarrier`** = 编辑原子咽喉：`prepare(plan)`/`commit(prepared, overlapPolicy:)`/`commit(plan, overlapPolicy:)`（便捷，= prepare+commit）→ `.applied(selections:)/.dropped/.rolledBack`。`commit` 体内调 `transaction.prepareEdits(ops)` + `transaction.prepareSelections(selections)`（:196）→ **edit 后 `gateway.lastCommittedSelections` 被更新**。
- **无 ServicesAccessor / 服务定位器**（`MonaServiceCollection` 是定义注册表非实例；`ICommandService` 是定义非实现类）。DI 全构造注入。
- **无单一光标宿主**：`MonaCaretOperationsFeature` 是**纯函数**；`MonaTransactionGateway.lastCommittedSelections`（`public private(set)`，最近提交选区，最近选区真值）。
- `MonaCommandRegistry` lookup-only 但冻结命令 id 字符串。
- `MonaUndoRedoStack` 真实现（经 `MonaTransactionGateway`）但**未接 model**。

---

## 3. 架构决策（修正后的方案 1，含对抗式理由）

**形态：薄 `MonaCommandDispatcher`**（扁平 String 键 handler 表 + `execute(id, args)`），**不扩 `MonaCommandRegistry`**（冻结身份 lookup，加 write-side 破坏冻结性）。镜像 monaco 扁平结构 + MonaCode `MonaAXMutationGateway` 先例。

**handler 模型：`(MonaCommandContext, Any?) -> Void`，dispatcher 每次 execute 从其构造注入依赖构建一个 context value 传给 handler。**
- 不用 ServicesAccessor——MonaCode 无此模式（§8.6）。
- 不让 handler 闭包捕获 dispatcher 自身——会 retain cycle（dispatcher 存 handler，handler 捕获 dispatcher）。context value 避免之。
- context 是固定 value 非 service-locator——monaco accessor 的 Swift 适配（传依赖 by value），与 MonaCode 值类型+构造注入 idiom 一致。
- handler 可独立单测（构造 context 调 handler，断言 model 变化）。

**`type` = 注册命令 handler（非特例）**：用冻结的 `"type"` id 注册。打印字符插入 = `type` 命令执行，与其他命令同构。

**edit 命令经 `inputBarrier`**（咽喉）；**selection 命令经 `MonaCaretOperationsFeature.commitCaretMove` + `MonaTransactionGateway`**（不改文本）。这是与 monaco 的必要分歧（monaco 有 CursorsController，MonaCode 没有），与 MonaCode 纯函数+提交模式一致。

**undo 不进 v1**：edit 经 `inputBarrier`→`MonaTransactionGateway`（与 `MonaUndoRedoStack` 同 gateway），接栈是 B1a。

---

## 4. 设计

### 4.1 MonaCommandDispatcher 类型

```swift
// Sources/MonaCode/Input/MonaCommandDispatcher.swift  (Core, Foundation-only — §8.1 已核实依赖全 Core 无 AppKit)
public final class MonaCommandDispatcher {
    private let model: MonaCodeModel
    private let inputBarrier: MonaModelInputBarrier
    private let transactionGateway: MonaTransactionGateway
    private let caretOps: MonaCaretOperationsFeature
    private var handlers: [String: (MonaCommandContext, Any?) -> Void] = [:]

    public init(model: MonaCodeModel,
                inputBarrier: MonaModelInputBarrier,
                transactionGateway: MonaTransactionGateway,
                caretOps: MonaCaretOperationsFeature)  // 存依赖 + register 9 core commands
    public func register(_ commandId: String,
                         handler: @escaping (MonaCommandContext, Any?) -> Void)
    public func execute(_ commandId: String, args: Any? = nil) -> Bool  // 查表→构建 context→调；未知 id→false
    public func contains(_ commandId: String) -> Bool
}
```

### 4.2 MonaCommandContext value

```swift
public struct MonaCommandContext {
    public let model: MonaCodeModel                  // getValue()/getLineContent(_:)/getLineCount()/getLineMaxColumn(_:)/getFullModelRange() — §8.5
    public let inputBarrier: MonaModelInputBarrier   // commit(_:overlapPolicy:) 便捷版 → .applied(selections:) — §8.2
    public let transactionGateway: MonaTransactionGateway // lastCommittedSelections(public private(set)) — §8.4
    public let caretOps: MonaCaretOperationsFeature   // commitCaretMove(_:target:gateway:lineCount:maxColumnOf:) — §8.7
    public let args: Any?                            // 命令参数（type 的 ["text":...] / cursorEnd 的 ["sticky":...]）
}
```
- 每次 `execute` 构建，传给 handler；handler 不持有 dispatcher；值类型避免 retain cycle。

### 4.3 选区真值来源（无光标宿主的解法）

dispatcher 不持光标，读 `transactionGateway.lastCommittedSelections`（`public private(set)`，§8.4）作为当前选区真值。edit 命令经 `inputBarrier.commit`（体内 `prepareSelections`，:196）**也会回写** `lastCommittedSelections`，故 edit/selection 命令读同一真值，一致。

**空时默认 seed**：若 `lastCommittedSelections` 为空（无 prior commit，TDD 隔离场景），默认 `MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))`（§8.8 init；monaco 初始光标在 (1,1)）。**不需要测试 hook**——§7 该问题已收敛。

### 4.4 Edit 命令（经 inputBarrier）

`type`（args = `["text": "x"]`）：
1. 读当前选区 `gateway.lastCommittedSelections`（空则 §4.3 默认）
2. 每个选区建 `MonaCursorInputEdit(range: selection.range, text: args.text)`（`kind=.text`/`forceMoveMarkers=false`/`tabstops=[]` 均默认，§8.3）
3. `MonaMultiCursorInputPlan(primary: edits.first!, secondary: Array(edits.dropFirst()))`（`secondary` 默认 `[]`，§8.3）
4. `inputBarrier.commit(plan, overlapPolicy: .reject)`（便捷版 = prepare+commit，§8.2）
5. `.applied` → 成功（选区由 commit 回写 gateway）；`.dropped`/`.rolledBack` → 失败返 false

`deleteLeft`/`deleteRight`：从每个选区算删除 range（选区非空→删选区内容；选区空→deleteLeft 删 start 退一字符、deleteRight 删 end 进一字符，空文本），同 plan+commit。

### 4.5 Selection 命令（经 commitCaretMove + gateway，不改文本）

读当前 position（`gateway.lastCommittedSelections` 首 selection 的 `activePosition`，空则 (1,1)），调：
```swift
caretOps.commitCaretMove(
    position, target: <映射>, gateway: transactionGateway,
    lineCount: model.getLineCount(),
    maxColumnOf: { model.getLineMaxColumn($0) }   // §8.5
)  // 返回新 selections + 内部 beginTransaction→prepareSelections→commit（§8.7）
```

**目标映射**（`MonaCaretMoveTarget` 实际 case，§8.7——无 left/right/up/down）：

| 命令 | target |
|---|---|
| `cursorLeft` | `.character(-1)` |
| `cursorRight` | `.character(1)` |
| `cursorUp` | `.line(-1)` |
| `cursorDown` | `.line(1)` |
| `cursorEnd` | `.lineEnd` |
| `cursorHome` | `.lineStart` |

> `cursorUp/Down` = `.line(±1)`，需 `lineCount` + `maxColumnOf`（**模型派生**，非像素几何——`getLineCount`/`getLineMaxColumn`）→ Foundation-only 可跑。§7 该问题已收敛。

### 4.6 v1 命令集（9 个冻结 id，§8.9 已核实存在）

| commandId | kind | 经 | args | 冻结行 |
|---|---|---|---|---|
| `type` | edit | inputBarrier | `["text": String]` | :576 |
| `deleteLeft` | edit | inputBarrier | – | :260 |
| `deleteRight` | edit | inputBarrier | – | :261 |
| `cursorLeft` | selection | commitCaretMove `.character(-1)` | – | :206 |
| `cursorRight` | selection | commitCaretMove `.character(1)` | – | :218 |
| `cursorUp` | selection | commitCaretMove `.line(-1)` | – | :223 |
| `cursorDown` | selection | commitCaretMove `.line(1)` | – | :200 |
| `cursorEnd` | selection | commitCaretMove `.lineEnd` | `["sticky": Bool]` | :202 |
| `cursorHome` | selection | commitCaretMove `.lineStart` | – | :204 |

**排除 v1**：`insertText`/`selectAll`（**不在冻结命令 id**，§8.9 核实无命中——registry 完整性缺口，非 dispatcher 事；deferred）；`undo`/`redo`（B1a）；`cut`/`copy`/`paste`（AppKit）；`find`（B1b）。

> 注：dispatcher 的 handler 表按 String 独立于 `MonaCommandRegistry`（后者仅身份 lookup）。v1 用冻结 id；`insertText`/`selectAll` 后续可按 string 注册（不需 registry 会员），但 v1 不做以保持纯事实。

---

## 5. 硬真相（影响 v1 验证范围）

1. **无光标宿主 → selection 真值从 `gateway.lastCommittedSelections` 读**（edit 经 `inputBarrier` 也回写它）。隔离测试时该值可空→默认 (1,1)；端到端 live 价值需 A1 驱动层喂数区。
2. **undo 依赖 B1a**：edit 经同一条 `MonaTransactionGateway`，但"可撤销"要 B1a 把 `MonaUndoRedoStack` 接进 push 路径。

---

## 6. 验证策略

**TDD（Red→Green→Commit）**：每命令一测试——构造 dispatcher（真 `MonaCodeModel`+`MonaModelInputBarrier`+`MonaTransactionGateway`+`MonaCaretOperationsFeature`），`execute(commandId, args)`，断言 model 文本/`lastCommittedSelections` 变化。

**monaco oracle 差分**（仿 RegExp/test262）：对每 edit 命令，用 monaco-editor 在 Node 跑同输入（同初始文本+选区+命令+args）抓输出文本+选区，冻结 fixture（`Tests/Fixtures/CommandDispatcherFixtures/`）；MonaCode `dispatcher.execute` 后比对。证明等价而非声称。

---

## 7. 已收敛的开放问题（原两问，均由事实解决）

1. ~~selection 命令 seed 策略~~ → **解决**：读 `gateway.lastCommittedSelections`，空则默认 `MonaSelection(anchor:(1,1), active:(1,1))`（§4.3）。不需测试 hook。
2. ~~`cursorUp/Down` 是否需几何~~ → **解决**：`= .line(±1)`，只需 `lineCount`+`maxColumnOf`（`getLineCount`/`getLineMaxColumn`，模型派生），Foundation-only 可跑（§4.5）。

---

## 8. 事实依据附录（全部 file:line 源码核实，无推测）

### 8.1 模块归属（全 Core，Foundation-only）
- `MonaCodeModel` → `Sources/MonaCode/Model/MonaCodeModel.swift`
- `MonaModelInputBarrier`/`MonaPreparedMultiCursorInput`/`MonaModelInputBarrierOutcome` → `Sources/MonaCode/Input/MonaModelInputBarrier.swift`
- `MonaMultiCursorInputPlan`/`MonaCursorInputEdit`/`MonaMultiCursorInputKind`/`MonaOverlapPolicy` → `Sources/MonaCode/Input/MonaMultiCursorInputPlan.swift`
- `MonaTransactionGateway` → `Sources/MonaCode/Transactions/MonaTransactionGateway.swift`
- `MonaCaretOperationsFeature`/`MonaCaretMoveTarget` → `Sources/MonaCode/Features/MonaCaretOperationsFeature.swift`
- 上述四文件 grep `^import AppKit` 均**无命中**（Foundation-only）。

### 8.2 inputBarrier 签名（`MonaModelInputBarrier.swift`）
- `public func prepare(_ plan: MonaMultiCursorInputPlan) -> MonaPreparedMultiCursorInput`（:136）
- `public func commit(_ prepared: MonaPreparedMultiCursorInput, overlapPolicy: MonaOverlapPolicy = .reject) -> MonaModelInputBarrierOutcome`（:167）；体（:196）`let transaction = gateway.beginTransaction(); transaction.prepareEdits(operations); transaction.prepareSelections(selections); ... transaction.commit()`
- `public func commit(_ plan: MonaMultiCursorInputPlan, overlapPolicy: MonaOverlapPolicy = .reject) -> MonaModelInputBarrierOutcome`（:209，便捷=prepare+commit）
- `MonaModelInputBarrierOutcome`：`.applied(selections: [MonaSelection])`（:70）/`.dropped(reason:)`（:76）/`.rolledBack(reason:)`（:82）

### 8.3 plan/edit（`MonaMultiCursorInputPlan.swift`）
- `MonaMultiCursorInputKind`：`.text`/`.snippet`/`.clipboard`/`.composition`（:37–49）
- `MonaCursorInputEdit`：`range/text/kind/forceMoveMarkers/tabstops`；`init(range:text:kind:forceMoveMarkers:tabstops:)`，`kind=.text`/`forceMoveMarkers=false`/`tabstops=[]` **均默认**（:123）
- `MonaMultiCursorInputPlan`：`primary: MonaCursorInputEdit`/`secondary: [MonaCursorInputEdit]`；`init(primary:secondary:)`，`secondary` **默认 `[]`**（:172）

### 8.4 transactionGateway（`MonaTransactionGateway.swift`）
- `public private(set) var lastCommittedSelections: [MonaSelection]`（~:63；公开可读，空直到 commit 记录选区）
- `public func beginTransaction() -> MonaEditTransaction`（:93）；`public func commit(_ transaction:) -> MonaReconciliationOutcome`（:117）；`rollback(_:)`（:171）
- `MonaEditTransaction.prepareSelections(_ selections: [MonaSelection])`（`MonaEditTransaction.swift:192`）+ `prepareEdits(_:)`

### 8.5 model 只读 API（`MonaCodeModel.swift`）
- `getValue()`（:129）/`getLineCount()`（:203）/`getLineContent(_:)`（:208）/`getLineLength(_:)`（:213）/`getLineMaxColumn(_:)`（:240）/`getFullModelRange()`（:331）

### 8.6 无 ServicesAccessor
- grep `ServicesAccessor|serviceAccessor` 全仓无命中；`MonaServiceCollection`（`MonaServiceCollection.swift:38`）是值定义注册表非实例；`ICommandService` 是定义非实现类。

### 8.7 caretOps（`MonaCaretOperationsFeature.swift`）
- `MonaCaretMoveTarget` case（:343–380）：`.line(n)`/`.wrappedLine(n)`/`.character(n)`/`.page(lines,pageSize)`/`.viewPortTop`/`.viewPortCenter`/`.viewPortBottom`/`.documentStart`/`.documentEnd`/`.lineStart`/`.lineEnd`（**无 left/right/up/down**）
- `public func moveSelections(_ selections:, target: MonaCaretMoveTarget, lineCount: Int, maxColumnOf: (Int)->Int, viewportTopLine: Int = 1, viewportBottomLine: Int = 1) -> [MonaSelection]`（:215）
- `@discardableResult public func commitCaretMove(_ position: MonaPosition, target: MonaCaretMoveTarget, gateway: MonaTransactionGateway, lineCount: Int, maxColumnOf: (Int)->Int, viewportTopLine: Int = 1, viewportBottomLine: Int = 1) -> [MonaSelection]`（:245）——体内 `gateway.beginTransaction()`→`transaction.prepareSelections([selection])`→`gateway.commit(transaction)`→`.applied/.reconciled` 返 `gateway.lastCommittedSelections`

### 8.8 position/selection init
- `MonaPosition.init(line: Int, column: Int)`（`MonaPosition.swift:56`）
- `MonaSelection.init(anchor: MonaPosition, activePosition: MonaPosition)`（`MonaSelection.swift:63`）

### 8.9 冻结命令 id（`MonaCommandRegistry.swift`，`frozenIdentities`）
- v1 集全部命中：`"type"`（:576，hasArguments, schema text:string）/`"deleteLeft"`（:260）/`"deleteRight"`（:261）/`"cursorLeft"`（:206）/`"cursorRight"`（:218）/`"cursorUp"`（:223）/`"cursorDown"`（:200）/`"cursorEnd"`（:202，args sticky:bool）/`"cursorHome"`（:204）
- `"insertText"` / `"selectAll"`：grep **无命中**（不在冻结 id）
