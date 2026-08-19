# MonaCode Command Dispatcher — Design Spec

**日期**: 2026-08-19
**缺口**: A3（`docs/equivalence/equivalence-gap.md` §6）—— commandId → 模型编辑/选区变更的执行半边缺失。
**范围**: 只做 dispatcher 组件本身，TDD 隔离验证（不接 NSView keyDown = A1；不接 undo 栈 = B1a）。

---

## 1. 目的与范围

键盘管线已能解析出 `commandId`（`MonaKeybindingResolver`/`MonaCompositionArbiter` 返回 `commandId: String?`），但**无人把 commandId 执行成模型编辑或选区变更**。本 spec 定义一个**薄 dispatcher** 把 commandId→handler 跑出来。

**In scope（v1）**：
- `MonaCommandDispatcher` 类型（扁平 String 键 handler 注册表 + `execute(id, args)`）
- `MonaCommandContext` value（传给 handler 的依赖包）
- core command handlers：`type`/`deleteLeft`/`deleteRight`/`insertText`/`selectAll`/`cursorLeft`/`cursorRight`/`cursorUp`/`cursorDown`/`cursorEnd`/`cursorHome`
- Foundation-only TDD（MonaCode Core 模块，MonaCodeTests target）

**Out of scope（明确排除）**：
- NSView `keyDown` 接线（= A1 驱动层，后续）
- `MonaCodeEditorView` conform `MonaInstanceICodeEditor`（= A2）
- undo/redo 真实现（= B1a：`MonaUndoRedoStack` 接进 push 路径；v1 的 edit 经同一条 `MonaTransactionGateway`，但"可撤销"要 B1a 成立）
- `IEditor.executeCommand(source, Any?)` 公共面填充（= A2；那是 command 对象 `Any?` 面，与内部 commandId:String dispatcher 是两回事）
- paste/cut/copy（需 `MonaPasteboardGateway` AppKit 依赖，后续 AppKit 层注册）
- find（= B1b）
- IME `interpretKeyEvents` 转发（= A5）

---

## 2. Ground truth（设计依据）

### 2.1 monaco 真实架构（拉取 monaco-editor@0.56.0 ESM + vscode 源验证）
- **无独立 dispatcher 类型**：扁平 `CommandsRegistry`（`Map<id, LinkedList<{id,handler,metadata?}>>` 存闭包）+ `KeybindingsRegistry`（键→id，分离）+ `KeybindingResolver`（join）+ `ICommandService.executeCommand`（`getCommand(id)` + `invokeFunction(handler, args)`）。
- **handler 签名 `(accessor: ServicesAccessor, ...args) => any`**，DI 是服务定位器 `accessor.get(SERVICE_ID)`，但 accessor 主活是取焦点 editor；之后状态从 `editor._getViewModel()` 对象树取（viewModel→CursorsController→model.EditStack）。
- **`type` 是注册命令**（`registerOverwritableCommand(Handler.Type)`），非特例；未命中键绑定的可打印字符走 textarea 原生 input 事件，两入口汇于 `viewModel.type`。
- **光标宿主** = `CursorsController._cursors: CursorCollection`（modelState/viewState 双份），经 IViewModel 暴露。
- **undo 栈** = Model.EditStack + IUndoRedoService；handler 只调 `editor.pushUndoStop()`/`executeCommands()` 控制 bracket，不直接碰栈。
- 核心命令是 `registerEditorCommand` 的 `EditorCommand` 薄壳，逻辑在 `runCoreEditorCommand(editor, viewModel, args)`。

### 2.2 MonaCode 已有架构（约束）
- **`MonaAXMutationGateway`** 是已有的"commandId→handler 注册+执行"先例：String 键 `() -> Void` handler + `perform(request)`（验前置→翻 `MonaMultiCursorInputPlan`→`barrier.prepare`+`commit(.reject)`→handler 仅 `.applied` 后触发）。构造注入、弱引用。**dispatcher 镜像此模式。**
- **`MonaModelInputBarrier` + `MonaMultiCursorInputPlan`** = 编辑原子咽喉（`prepare`+`commit`→`.applied(selections:)`/`.dropped`/`.rolledBack`）。**所有 edit 经此。**
- **无 ServicesAccessor / 服务定位器**（`MonaServiceCollection` 是定义注册表非实例；`ICommandService` 是定义非实现类）。DI 全构造注入。
- **无单一光标宿主**：`MonaCaretOperationsFeature` 是**纯函数**（`moveCaret`/`moveSelections` 取+返）；`MonaTransactionGateway.lastCommittedSelections` 是 `private(set)` 副作用（最近提交选区，最近的选区真值）；`MonaCodeEditorView` 持 0 选区引用。**与 monaco 的 CursorsController 最大分歧。**
- `MonaCommandRegistry` lookup-only 但冻结命令 id 字符串（`"type"`/`"undo"`/`"cursorLeft"`/`"cursorMove"`/`"setSelection"`/`"editor.action.clipboardPasteAction"`…）。**dispatcher 用这些冻结 id。**
- `MonaUndoRedoStack` 真实现（经 `MonaTransactionGateway`）但**未接 model**。

---

## 3. 架构决策（修正后的方案 1，含对抗式理由）

**形态：薄 `MonaCommandDispatcher`**（扁平 String 键 handler 表 + `execute(id, args)`），**不扩 `MonaCommandRegistry`**（冻结身份 lookup，加 write-side 破坏冻结性）。镜像 monaco 扁平结构 + MonaCode `MonaAXMutationGateway` 先例。

**handler 模型：`(MonaCommandContext) -> Void`，dispatcher 每次 execute 从其构造注入依赖构建一个 context value 传给 handler。**
- 理由（对抗式核出来的）：
  - **不用 ServicesAccessor**——MonaCode 无此模式。
  - **不让 handler 闭包捕获 dispatcher 自身**——会 retain cycle（dispatcher 存 handler，handler 捕获 dispatcher）。
  - **context 是固定 value 非 service-locator**——是 monaco accessor 的 Swift 适配（传依赖 by value），与 MonaCode 值类型+构造注入 idiom 一致。
  - handler 可独立单测（构造 context 调 handler，断言 model 变化）。

**`type` = 注册命令 handler（非特例）**：用冻结的 `"type"` id 注册。打印字符插入 = `type` 命令执行，与其他命令同构。修正原方案 1 的"默认 type 动作内置特例"。

**edit 命令经 `inputBarrier`**（咽喉）：`type`/`deleteLeft`/`deleteRight`/`insertText` 建 `MonaMultiCursorInputPlan`→`barrier.prepare`→`barrier.commit(.reject)`。镜像 monaco `pushEditOperations` + AX `perform`。

**selection 命令经 `MonaTransactionGateway`**（非 inputBarrier，因不改文本）：`selectAll`/`cursorLeft/Right/Up/Down`/`cursorEnd/Home` 读 `MonaTransactionGateway.lastCommittedSelections`→`MonaCaretOperationsFeature.moveSelections`（纯计算）→经 `MonaTransactionGateway` 提交新选区。**这是与 monaco 的必要分歧**（monaco 有 CursorsController，MonaCode 没有），与 MonaCode 纯函数+提交模式一致。

**undo 不进 v1**：edit 经 `inputBarrier`→`MonaTransactionGateway`（与 `MonaUndoRedoStack` 同一条 gateway），接栈是 B1a。`undo`/`redo` 命令 v1 不实现或调桩。

---

## 4. 设计

### 4.1 MonaCommandDispatcher 类型

```swift
// Sources/MonaCode/Input/MonaCommandDispatcher.swift  (Core, Foundation-only)
public final class MonaCommandDispatcher {
    // 构造注入（镜像 AX gateway）
    private let model: MonaCodeModel
    private let inputBarrier: MonaModelInputBarrier
    private let transactionGateway: MonaTransactionGateway       // 选区真值源 + 提交
    private let caretOps: MonaCaretOperationsFeature             // 纯选区计算
    private var handlers: [String: (MonaCommandContext, Any?) -> Void] = [:]

    public init(model: MonaCodeModel,
                inputBarrier: MonaModelInputBarrier,
                transactionGateway: MonaTransactionGateway,
                caretOps: MonaCaretOperationsFeature) {
        // ... 存依赖，然后 register core commands（闭包不捕获 self——通过 context 拿依赖）
    }

    public func register(_ commandId: String,
                         handler: @escaping (MonaCommandContext, Any?) -> Void)
    public func execute(_ commandId: String, args: Any? = nil) -> Bool   // 查表→构建 context→调 handler；未知 id 返回 false
    public func contains(_ commandId: String) -> Bool
}
```

**模块**：`MonaCode` Core（Foundation-only），因 v1 依赖（model/inputBarrier/transactionGateway/caretOps）全在 Core → 可在 `MonaCodeTests`（Foundation-only）TDD。AppKit 的 paste/cut/copy 命令后续由 AppKit 层注册（dispatcher 是 Core，扩展命令在 AppKit 注入）。

### 4.2 MonaCommandContext value

```swift
public struct MonaCommandContext {
    public let model: MonaCodeModel                       // 只读：getValue/getLineContent/getFullModelRange
    public let inputBarrier: MonaModelInputBarrier       // edit 命令用
    public let transactionGateway: MonaTransactionGateway // selection 命令用（读 lastCommittedSelections + 提交）
    public let caretOps: MonaCaretOperationsFeature       // 纯选区计算
    public let args: Any?                                // 命令参数（type 的 text 等）
}
```
- 每次 `execute` 构建一个，传给 handler；handler 不持有 dispatcher。
- `MonaCommandContext` 是值类型，避免 retain cycle。

### 4.3 Edit 命令（经 inputBarrier）

`type`（args = `["text": "x"]` 或 String）：
1. 读当前选区 `transactionGateway.lastCommittedSelections`（无则默认 `[MonaSelection(line:1,column:1,...)]`）
2. 对每个选区建 `MonaCursorInputEdit`（range = 选区 range，text = 插入文本，kind = `.text`，forceMoveMarkers = false）
3. `MonaMultiCursorInputPlan(primary: first, secondary: rest)`
4. `inputBarrier.prepare(plan)` → `barrier.commit(prepared, overlapPolicy: .reject)`
5. `.applied` → 成功（选区由 barrier outcome 带回）；`.dropped`/`.rolledBack` → 失败

`deleteLeft`/`deleteRight`：从选区算删除 range（deleteLeft = 选区 start 退一字符→start，空文本），同 plan+commit。若选区非空则删选区内容。

`insertText`（args = text）：与 `type` 同（语义别名，显式插入）。

### 4.4 Selection 命令（经 MonaTransactionGateway，不改文本）

`selectAll`：新选区 = `[MonaSelection(range: model.getFullModelRange(), ...)]` → `transactionGateway` 提交（prepareSelections）。

`cursorLeft`/`Right`/`Up`/`Down`/`cursorEnd`/`cursorHome`：
1. 读 `transactionGateway.lastCommittedSelections`
2. `caretOps.moveSelections(selections, target: .left/.right/.up/.down, ...)` → 新选区（纯函数）
3. 经 `MonaTransactionGateway` 提交新选区

> **硬约束**：v1 隔离测试时 `lastCommittedSelections` 可能为空（无驱动层喂数区）。单测**提供初始选区**（直接向 transactionGateway 提交一次 seed，或 handler 接受测试注入的选区）后断言移动结果。端到端 live 价值需 A1 驱动层喂数区。

### 4.5 v1 命令集

| commandId | kind | 经 | args |
|---|---|---|---|
| `type` | edit | inputBarrier | text: String |
| `deleteLeft` | edit | inputBarrier | – |
| `deleteRight` | edit | inputBarrier | – |
| `insertText` | edit | inputBarrier | text: String |
| `selectAll` | selection | transactionGateway | – |
| `cursorLeft`/`Right`/`Up`/`Down` | selection | transactionGateway + caretOps | – |
| `cursorEnd`/`cursorHome` | selection | transactionGateway + caretOps | – |

**排除 v1**：`undo`/`redo`（B1a）、`cut`/`copy`/`paste`（AppKit pasteboard，后续）、`find`（B1b）、`editor.action.*`（后续）。

---

## 5. 硬真相（影响 v1 验证范围）

1. **无光标宿主 → 光标命令 live 价值需驱动层**：selection 命令用 `lastCommittedSelections` + 纯计算；隔离测试提供初始选区断言移动，端到端要 A1 喂数区。
2. **undo 依赖 B1a**：edit 经同一条 `MonaTransactionGateway`，但"可撤销"要 B1a 把 `MonaUndoRedoStack` 接进 push 路径。v1 的 edit 不保证可撤销。

---

## 6. 验证策略

**TDD（Red→Green→Commit）**：每个命令一个测试——构造 dispatcher（真 model + inputBarrier + transactionGateway + caretOps），`execute(commandId, args)`，断言 model 文本/选区变化。

**monaco oracle 差分**（仿 RegExp/test262）：
- 对每个 edit 命令，用 monaco-editor 在 Node 跑同输入（同初始文本 + 选区 + 命令 + args）抓输出文本 + 选区，冻结成 fixture（`Tests/Fixtures/CommandDispatcherFixtures/`）。
- MonaCode `dispatcher.execute` 后比对 model.getValue() + lastCommittedSelections。
- 这证明等价而非声称；是 v1 验收的核心。

---

## 7. 开放问题

- `lastCommittedSelections` 为空时 selection 命令的 seed 策略：单测直接向 transactionGateway 提交 seed 选区（不通过 dispatcher），还是 dispatcher 暴露一个测试 hook？倾向前者（不污染产品 API）。
- `cursorUp`/`Down` 需要行高/几何（跨行移动）——`MonaCaretOperationsFeature` 是否支持无几何的行移动？若需几何，v1 只做 `cursorLeft/Right/End/Home`（行内），`Up/Down` 留到接 geometryBarrier。**待 TDD 时确认 caretOps 能力。**
