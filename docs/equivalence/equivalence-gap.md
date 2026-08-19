# MonaCode ↔ monaco-editor@0.56.0 — Equivalence Gap

> **目的**：以 monaco-editor@0.56.0 官方 typed 公共 API 为权威 ground truth，逐声明对照 MonaCode Swift port 的实现，坐实"等价到什么程度、缺口在哪、是否遗漏"。本文不替代发布裁决 `RELEASE_VERDICT.md`（那是组件级契约验收）；本文回答的是"与 monaco-editor 作为产品/库的公共能力是否对等"。

---

## §0 Ground truth 与方法

### 0.1 权威参照

monaco-editor 的完整公共能力以 **monaco-editor@0.56.0 官方发布的 TypeScript 声明文件**为权威枚举（每一个 API 及其类型）：

- **文件**：`docs/equivalence/monaco-editor-0.56.0.editor.api.d.ts`（本仓内固定，可复现/可审计/可 diff）
- **来源**：npm `monaco-editor@0.56.0`，`esm/vs/editor/editor.api.d.ts`，经 `https://unpkg.com/monaco-editor@0.56.0/...` 于 2026-08-19 拉取
- **许可**：MIT（monaco-editor 上游许可证；本仓 LICENSE 已记录其 provenance）
- **SHA-256**：`72d6fbbfc8a719ae58a8a24da8c34324bf60a2b1bf47b0692979711a9f55bf94`
- **规模**：8800 行；顶层 = 8 个类（`Uri`/`Position`/`Range`/`Selection`/`Token`/`KeyMod`/`Emitter`/`CancellationTokenSource`）+ 3 个 namespace（`editor` / `languages` / `worker`）

> 这比早先 `docs/contracts/.../g4-r/artifacts/*.html` 那批按 SHA-256 释义的 closure 文档更硬：那是反向工程释义，这是 monaco 自己发布的 typed 表，逐 API 带类型签名。

### 0.2 MonaCode 被对照面

- **权威公共 API**：FROZEN P07-T011 `native-declaration` manifest（`docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p08-t010-native-declaration-manifest.json`）——产品冻结的公共符号图。
- **实现体定位**：对 `Sources/MonaCode`（Core，Foundation-only）/ `Sources/MonaCodeAppKit`（native）/ `Sources/MonaCodeSwiftUI` 做 live `public` 扫描（约 4429 条 public 声明），grep + 读源码确认。
- **命名约定**：monaco `Foo`/`IFoo` 通常 → Swift `MonaFoo`；有例外（如 `Uri`→`MonaURI`）。命名匹配不充分时读 Swift 类型成员逐个确认。

### 0.3 方法

1. 按 `.d.ts` 的命名空间切片，枚举每个顶层声明（interface/class/enum/function/type/const）。
2. 每个声明对照 MonaCode 等价物，赋一个状态（见 §2）+ 证据 `file:line`。
3. 对 🟡/🔴/🟠/⚫ 钻到成员级（缺哪个方法、签名差在哪、是否 no-op）。
4. 不凭记忆下结论；每条都 grep + 读源码核；查不到就标 ⚫/❓，不臆造。

---

## §1 规模

| 命名空间 | interface | class | enum | function | type | const | 小计 |
|---|---|---|---|---|---|---|---|
| 顶层类 | – | 8 | – | – | – | – | 8 |
| `editor` | 140 | 16 | 26 | 35 | 17 | 3 | 237 |
| `languages` | 139 | – | 18 | 36 | – | – | 193 |
| `worker` | 3 | – | – | – | – | – | 3 |
| **合计顶层声明** | | | | | | | **441** |

> 每个 interface/class 含多个成员，成员总数数千。按"逐声明 + 缺口钻深"原则，成员级仅在出现缺口/分歧时展开。

---

## §2 状态分类

| 标记 | 状态 | 含义 |
|---|---|---|
| ✅ | implemented-equivalent | API 存在，签名+行为与 monaco 对等 |
| 🟡 | partial | 存在但是子集（行为/签名不全） |
| 🔴 | stub | 存在但是 no-op / 返回空（如 `undo`/`findMatches`/`deltaDecorations`） |
| 🟠 | type-divergent | 存在但命名/签名/类型不同（如 `Uri`→`MonaURI`） |
| ⚫ | missing | MonaCode 公共面无等价物 |
| ❓ | unverifiable | 仅凭源码无法判定 |

---

## §3 等价矩阵

> 以下五张表由并行交叉引用代理产出（按 monaco 命名空间切片）。每行：`monacoAPI | kind | monaCodeEquiv | status | evidence(file:line) | memberGaps/notes`。

### 3.1 顶层类（Uri / Position / Range / Selection / Token / KeyMod / Emitter / CancellationTokenSource）

> 代理逐成员核验（`.d.ts` 66–932）。计数：✅:21 🟡:4 🔴:0 🟠:40 ⚫:49 ❓:0。

| monacoAPI | kind | monaCodeEquiv | status | evidence(file:line) | memberGaps/notes |
|---|---|---|---|---|---|
| **Emitter<T>** (66–71) | class | `MonaEmitter<T>` (functional); `MonaTopLevelEmitter{}` 空 stub | — | Sources/MonaCode/Base/MonaEmitter.swift:71 ; Generated/MonaPublicAPI.swift:63 | 功能实现是 MonaEmitter；生成的顶层壳是空 `public final class {}` |
| Emitter.constructor() | ctor | `MonaEmitter.init(options:=)` | ✅ | MonaEmitter.swift:74 | `options` 增参但有默认值 → `MonaEmitter<T>()` 可用 |
| Emitter.event | readonly-prop | `MonaEmitter.event: MonaEvent<T>` | 🟡 | MonaEmitter.swift:84 ; MonaEvent.swift:46 | 省略 `thisArg` + `disposables[]`（显式省略，MonaEvent.swift:11–16） |
| Emitter.fire(event) | method | `MonaEmitter.fire(_:)` | ✅ | MonaEmitter.swift:98 | 非 throwing；失败走 onListenerError |
| Emitter.dispose() | method | `MonaEmitter.dispose()` | ✅ | MonaEmitter.swift:122 | 幂等 |
| **CancellationTokenSource** (85–90) | class | `MonaCancellationTokenSource` (functional); `MonaTopLevelCancellationTokenSource{}` 空 stub | — | MonaCancellation.swift:319 ; MonaPublicAPI.swift:45 | 生成的顶层壳是空 stub |
| CTS.constructor(parent?) | ctor | `MonaCancellationTokenSource.init()` | 🟠 | MonaCancellation.swift:324 | 无 `parent` 参数；父子链路经独立 `createChild()` 暴露（:354，不在 .d.ts） |
| CTS.token | get-prop | `MonaCancellationTokenSource.token` | ✅ | MonaCancellation.swift:335 | 返回 `MonaCancellationToken` |
| CTS.cancel() | method | `MonaCancellationTokenSource.cancel()` | ✅ | MonaCancellation.swift:343 | 幂等；传播子 |
| CTS.dispose(cancel?) | method | `MonaCancellationTokenSource.dispose()` | 🟡 | MonaCancellation.swift:361 | 无 `cancel:boolean` 参数；Swift dispose 不触发监听器（≡ 默认 `dispose(false)`） |
| (CancellationToken).isCancellationRequested | readonly-prop | `MonaCancellationToken.isCancellationRequested` | ✅ | MonaCancellation.swift:80 | 另有 `.none`/`.cancelled` 单例 |
| (CancellationToken).onCancellationRequested(listener,thisArgs?,disposables?) | readonly-prop | `MonaCancellationToken.onCancellationRequested(_:)` | 🟡 | MonaCancellation.swift:94 | 省略 `thisArgs` + `disposables[]` |
| **Uri** (123–251) | class | `MonaURI` | — | MonaURI.swift:92 | final class；缓存 toString/fsPath |
| Uri.isUri(thing) | static | — | ⚫ | — | MonaURI.swift 无 `isUri` |
| Uri.scheme | readonly-prop | `MonaURI.scheme` | ✅ | MonaURI.swift:96 | `let` |
| Uri.authority | readonly-prop | `MonaURI.authority` | ✅ | MonaURI.swift:97 | |
| Uri.path | readonly-prop | `MonaURI.path` | ✅ | MonaURI.swift:98 | |
| Uri.query | readonly-prop | `MonaURI.query` | ✅ | MonaURI.swift:99 | |
| Uri.fragment | readonly-prop | `MonaURI.fragment` | ✅ | MonaURI.swift:100 | |
| Uri.fsPath | get-prop | `MonaURI.fsPath` | ✅ | MonaURI.swift:226 | 缓存；仅 posix 分隔符 |
| Uri.with(change) | method | — | ⚫ | — | 无 `with()` |
| Uri.parse(value,_strict?) | static | `MonaURI.parse(_:) -> MonaURI?` | 🟡 | MonaURI.swift:149 | 返回 Optional（monaco 非可选）；无 `_strict`（仅非严格）；roots file/http/https |
| Uri.file(path) | static | — | ⚫ | — | 无 `file()` |
| Uri.from(components,strict?) | static | — | ⚫ | — | 无 `from()` |
| Uri.joinPath(uri,...fragments) | static | — | ⚫ | — | 无 `joinPath()` |
| Uri.toString(skipEncoding?) | method | `MonaURI.toString() throws -> String` | 🟠 | MonaURI.swift:204 | throws loneSurrogate；无 `skipEncoding` |
| Uri.toJSON() | method | `MonaURI.toJSON() -> MonaURIJSON` | 🟠 | MonaURI.swift:248 | 返回 `MonaURIJSON`（超集）vs `UriComponents` |
| Uri.revive(data) [4 overloads] | static | — | ⚫ | — | 无 `revive()` |
| **KeyMod** (464–470) | class | `MonaKeyMod: OptionSet` | — | MonaKeyMod.swift:40 | 位布局保留（WinCtrl=256,Alt=512,Shift=1024,CtrlCmd=2048） |
| KeyMod.CtrlCmd | static readonly number | `MonaKeyMod.ctrlCmd` | 🟠 | MonaKeyMod.swift:51 | `static let` OptionSet 值 vs 裸数字；经 `.rawValue` 取 Int |
| KeyMod.Shift | static readonly number | `MonaKeyMod.shift` | 🟠 | MonaKeyMod.swift:54 | 1024 |
| KeyMod.Alt | static readonly number | `MonaKeyMod.alt` | 🟠 | MonaKeyMod.swift:57 | 512 |
| KeyMod.WinCtrl | static readonly number | `MonaKeyMod.winCtrl` | 🟠 | MonaKeyMod.swift:61 | 256 |
| KeyMod.chord(firstPart,secondPart) | static method | `MonaKeyMod.chord(firstPart:secondPart:) -> Int` | ✅ | MonaKeyMod.swift:72 | 位打包匹配；增 `firstPart(of:)`/`secondPart(of:)` |
| **Position** (549–622) | class | `MonaPosition: Equatable,Hashable,Comparable` | — | MonaPosition.swift:42 | 值类型；原始 UTF-16 列 |
| Position.lineNumber | readonly-prop | `MonaPosition.line` | 🟠 | MonaPosition.swift:45 | 改名 `line` |
| Position.column | readonly-prop | `MonaPosition.column` | ✅ | MonaPosition.swift:49 | |
| Position.constructor(lineNumber,column) | ctor | `MonaPosition.init(line:column:)` | 🟠 | MonaPosition.swift:56 | 参数名 `line` |
| Position.with(newLineNumber?,newColumn?) | method | — | ⚫ | — | 无绝对替换 `with()`；`translated()` 是 delta |
| Position.delta(deltaLineNumber?,deltaColumn?) | method | `MonaPosition.translated(lineDelta:columnDelta:)` | 🟠 | MonaPosition.swift:162 | 改名；同 delta 语义 |
| Position.equals(other) / static | method | 经 `==` (Equatable) | 🟠 | MonaPosition.swift:42 | 运算符，无命名 `equals()` |
| Position.isBefore(other) / static | method | 经 `<` (Comparable) | 🟠 | MonaPosition.swift:62 | 运算符，无命名 `isBefore()` |
| Position.isBeforeOrEqual(other) / static | method | 经 `<=` | 🟠 | MonaPosition.swift:42 | |
| Position.compare(a,b) static | static | — | ⚫ | — | 无三态 Int 比较器 |
| Position.clone() | method | — | ⚫ | — | 值类型隐式拷贝，无命名方法 |
| Position.toString() | method | — | ⚫ | — | 缺 |
| Position.lift(pos) static | static | — | ⚫ | — | 无 IPosition/Position 分层 |
| Position.isIPosition(obj) static | static | — | ⚫ | — | 缺 |
| Position.toJSON() | method | — | ⚫ | — | 缺 |
| **Range** (649–815) | class | `MonaRange: Equatable,Hashable` | — | MonaRange.swift:48 | 值类型；构造器规范化反转端点 |
| Range.startLineNumber | readonly-prop | `MonaRange.startPosition.line` | 🟠 | MonaRange.swift:51 | 组合 `startPosition`，非扁平 `startLineNumber` |
| Range.startColumn | readonly-prop | `MonaRange.startPosition.column` | 🟠 | MonaRange.swift:51 | 组合 |
| Range.endLineNumber | readonly-prop | `MonaRange.endPosition.line` | 🟠 | MonaRange.swift:54 | 组合 |
| Range.endColumn | readonly-prop | `MonaRange.endPosition.column` | 🟠 | MonaRange.swift:54 | 组合 |
| Range.constructor(sLN,sC,eLN,eC) | ctor | `MonaRange.init(startLine:startColumn:endLine:endColumn:)` | ✅ | MonaRange.swift:74 | 4 数 ctor 在（另有 `init(startPosition:endPosition:)` :62） |
| Range.isEmpty() | method | `MonaRange.isFolded` (computed Bool) | 🟠 | MonaRange.swift:87 | 改名 `isFolded`；属性非方法；同 start==end |
| Range.isEmpty(range) static | static | — | ⚫ | — | 用实例 `isFolded` |
| Range.containsPosition(position) | method | `MonaRange.contains(_:)` | 🟠 | MonaRange.swift:110 | 改名；含端点分支移植 |
| Range.containsPosition(range,position) static | static | — | ⚫ | — | |
| Range.containsRange / static | method | — | ⚫ | — | |
| Range.strictContainsRange / static | method | — | ⚫ | — | |
| Range.plusRange / static | method | — | ⚫ | — | 无并集/plus |
| Range.intersectRanges / static | method | — | ⚫ | — | 仅布尔谓词，无 Range 结果交集 |
| Range.equalsRange(other) / static | method | 经 `==` | 🟠 | MonaRange.swift:48 | |
| Range.getEndPosition() | method | `MonaRange.endPosition` (属性) | 🟠 | MonaRange.swift:54 | |
| Range.getStartPosition() | method | `MonaRange.startPosition` (属性) | 🟠 | MonaRange.swift:51 | |
| Range.toString() | method | — | ⚫ | — | |
| Range.setEndPosition(eLN,eC) | method | — | ⚫ | — | |
| Range.setStartPosition(sLN,sC) | method | — | ⚫ | — | |
| Range.collapseToStart() / static | method | — | ⚫ | — | |
| Range.collapseToEnd() / static | method | — | ⚫ | — | |
| Range.delta(lineCount) | method | — | ⚫ | — | 无 range `delta()` |
| Range.isSingleLine() | method | — | ⚫ | — | |
| Range.fromPositions(start,end?) static | static | — | ⚫ | — | |
| Range.lift [overloads] static | static | — | ⚫ | — | |
| Range.isIRange(obj) static | static | — | ⚫ | — | |
| Range.areIntersectingOrTouching(a,b) static | static | `MonaRange.intersects(_:)` | 🟠 | MonaRange.swift:131 | 实例非静态；改名；含 touching 分支移植 |
| Range.areIntersecting(a,b) static | static | `MonaRange.areIntersecting(_:)` | 🟠 | MonaRange.swift:156 | 实例非静态；不含 touching 分支移植 |
| Range.areOnlyIntersecting(a,b) static | static | — | ⚫ | — | |
| Range.compareRangesUsingStarts(a,b) static | static | — | ⚫ | — | |
| Range.compareRangesUsingEnds(a,b) static | static | — | ⚫ | — | |
| Range.spansMultipleLines(range) static | static | — | ⚫ | — | |
| Range.toJSON() | method | — | ⚫ | — | |
| **Selection** (844–918, extends Range) | class | `MonaSelection: Equatable,Hashable` | — | MonaSelection.swift:48 | 不继承 MonaRange（独立 struct）；Range 扁平成员未再暴露 |
| Selection.selectionStartLineNumber | readonly-prop | `MonaSelection.anchor.line` | 🟠 | MonaSelection.swift:52 | 组合 anchor |
| Selection.selectionStartColumn | readonly-prop | `MonaSelection.anchor.column` | 🟠 | MonaSelection.swift:52 | |
| Selection.positionLineNumber | readonly-prop | `MonaSelection.activePosition.line` | 🟠 | MonaSelection.swift:56 | 组合 activePosition |
| Selection.positionColumn | readonly-prop | `MonaSelection.activePosition.column` | 🟠 | MonaSelection.swift:56 | |
| Selection.constructor(sSLN,sSC,pLN,pC) | ctor | `MonaSelection.init(anchor:activePosition:)` | 🟠 | MonaSelection.swift:63 | 取 position，非 4 数 |
| Selection.toString() | method | — | ⚫ | — | |
| Selection.equalsSelection(other) / selectionsEqual(a,b) | method | 经 `==` | 🟠 | MonaSelection.swift:48 | |
| Selection.getDirection() | method | `MonaSelection.orientation` (computed) | 🟠 | MonaSelection.swift:107 | 改名；枚举 `.forward`/`.backward` vs `LTR`/`RTL` |
| Selection.setEndPosition(eLN,eC) | method | — | ⚫ | — | |
| Selection.getPosition() | method | `MonaSelection.activePosition` (属性) | 🟠 | MonaSelection.swift:56 | |
| Selection.getSelectionStart() | method | `MonaSelection.anchor` (属性) | 🟠 | MonaSelection.swift:52 | |
| Selection.setStartPosition(sLN,sC) | method | — | ⚫ | — | |
| Selection.fromPositions(start,end?) static | static | — | ⚫ | — | |
| Selection.fromRange(range,direction) static | static | `MonaSelection.init(startPosition:endPosition:orientation:)` | 🟠 | MonaSelection.swift:74 | 实例 init 非静态；同 orientation 语义 |
| Selection.liftSelection(sel) static | static | — | ⚫ | — | |
| Selection.selectionsArrEqual(a,b) static | static | — | ⚫ | — | |
| Selection.isISelection(obj) static | static | — | ⚫ | — | |
| Selection.createWithDirection(sLN,sC,eLN,eC,dir) static | static | `MonaSelection.init(startPosition:endPosition:orientation:)` | 🟠 | MonaSelection.swift:74 | 实例 init；取 position 非 4 数 |
| **Token** (934–941) | class | `MonaToken: Equatable,Hashable,Sendable` | — | MonaToken.swift:37 | 值类型 |
| Token.offset | readonly-prop | `MonaToken.offset` | ✅ | MonaToken.swift:41 | Int |
| Token.type | readonly-prop | `MonaToken.type` | ✅ | MonaToken.swift:46 | String |
| Token.language | readonly-prop | `MonaToken.language` | ✅ | MonaToken.swift:49 | String |
| Token._tokenBrand | field | `MonaToken._tokenBrand: Void` | ✅ | MonaToken.swift:56 | computed Void（无存储）；语义等价 |
| Token.constructor(offset,type,language) | ctor | `MonaToken.init(offset:type:language:)` | ✅ | MonaToken.swift:61 | |
| Token.toString() | method | `MonaToken.toString() -> String` | ✅ | MonaToken.swift:68 | 返回 `[offset|type|language]` |

### 3.2 `editor` 命名空间 · part 1（.d.ts 934–2440）

> 代理逐声明核验（含 ITextModel 跨 2400 边界至 2440）。计数：✅:15 🟡:14 🔴:33 🟠:13 ⚫:19 ❓:0。
> 关键：`ITextModel→MonaCodeModel` 是最深等价（44/70 真实现、17 桩、8 分歧）；marker 服务整片缺席；WebWorker 三件刻意 CUT；diff 构造 throw `.phase07NotWired`。

| monacoAPI | kind | monaCodeEquiv | status | evidence(file:line) | memberGaps/notes |
|---|---|---|---|---|---|
| Token | class | MonaToken(struct) | ✅ | MonaToken.swift:37 | offset/type/language/_tokenBrand/init/toString 全在；struct 非 class |
| editor.create(domElement,opts?,override?) | function | MonaEditorFactory.create(model:options:)/create(model:) | 🟡 | MonaEditorFactory.swift:163,175 | 无 domElement/override；取 MonaCodeModel?+MonaOptionSnapshot?（无 value/language/theme 自动建）；返回 NSView 非 IStandaloneCodeEditor |
| editor.onDidCreateEditor | function | MonaEditorFactory.onDidCreateEditor:MonaEvent<MonaCodeEditorView> | ✅ | MonaEditorFactory.swift:131 | 发 MonaCodeEditorView 非 ICodeEditor |
| editor.onDidCreateDiffEditor | function | — | ⚫ | MonaPublicAPI.swift:679 | 空 stub，无 diff 创建事件 |
| editor.getEditors() | function | MonaEditorFactory.getEditors()->[MonaCodeEditorView] | ✅ | MonaEditorFactory.swift:199 | 返回 [MonaCodeEditorView] 非 [ICodeEditor] |
| editor.getDiffEditors() | function | — | ⚫ | MonaPublicAPI.swift:707 | 空 stub |
| editor.createDiffEditor(...) | function | MonaEditorFactory.createDiffEditor(original:modified:options:) throws | 🔴 | MonaEditorFactory.swift:282 | 签名分歧；体无条件 throw `.phase07NotWired` |
| editor.createMultiFileDiffEditor(...) | function | MonaEditorFactory.createMultiFileDiffEditor(options:) throws | 🔴 | MonaEditorFactory.swift:294 | 签名分歧；体 throw `.phase07NotWired` |
| ICommandDescriptor | interface | MonaEditorICommandDescriptor(空 protocol) | 🔴 | MonaPublicAPI.swift:751 | 无 id/run；MonaCommandIdentity 仅 lookup 不可 add |
| editor.addCommand(descriptor) | function | — | ⚫ | MonaPublicAPI.swift:765 | 全局缺；仅实例 addCommand on MonaInstanceIStandaloneCodeEditor:324 |
| editor.addEditorAction(descriptor) | function | — | ⚫ | MonaPublicAPI.swift:779 | 全局缺；仅实例 addAction:326 |
| IKeybindingRule | interface | MonaKeybinding(struct) | 🟠 | MonaKeybinding.swift:57 | 结构化 key+modifiers+command+when+weight+chord，非 keybinding Int；无 commandArgs |
| editor.addKeybindingRule(rule) | function | — | ⚫ | MonaPublicAPI.swift:808 | resolver 有 register(MonaKeybinding) 签名分歧；无 rule 形式 |
| editor.addKeybindingRules(rules) | function | — | ⚫ | MonaPublicAPI.swift:822 | 无批量注册 |
| editor.createModel(value,language?,uri?) | function | MonaEditorFactory.createModel(text:uri:) | 🟡 | MonaEditorFactory.swift:211 | 无 language 参数；fire onDidCreateModel+track will-dispose |
| editor.setModelLanguage(model,langId) | function | — | ⚫ | MonaPublicAPI.swift:838 | 仅实例 onDidChangeModelLanguage 事件:206 |
| editor.setModelMarkers(model,owner,markers) | function | — | ⚫ | MonaPublicAPI.swift:852 | MonaMarker:69 仅值类型，无 marker-service 写 API |
| editor.removeAllMarkers(owner) | function | — | ⚫ | MonaPublicAPI.swift:866 | 缺 |
| editor.getModelMarkers(filter) | function | — | ⚫ | MonaPublicAPI.swift:880 | 缺 |
| editor.onDidChangeMarkers(listener) | function | — | ⚫ | MonaPublicAPI.swift:894 | 缺 |
| editor.getModel(uri) | function | — | ⚫ | MonaPublicAPI.swift:908 | 全局 URI 查 model 缺；仅实例 getModel() |
| editor.getModels() | function | — | ⚫ | MonaPublicAPI.swift:922 | 缺 |
| editor.onDidCreateModel(listener) | function | MonaEditorFactory.onDidCreateModel:MonaEvent<MonaCodeModel> | ✅ | MonaEditorFactory.swift:143 | 仅 factory.createModel 触发 |
| editor.onWillDisposeModel(listener) | function | MonaEditorFactory.onWillDisposeModel:MonaEvent<MonaCodeModel> | ✅ | MonaEditorFactory.swift:149 | 重发 model.onWillDispose |
| editor.onDidChangeModelLanguage(listener) | function | — | ⚫ | MonaPublicAPI.swift:964 | 全局缺；仅实例事件:206 |
| editor.createWebWorker<T>(opts) | function | — | ⚫ | MonaPublicAPI.swift:978 ; MonaStandaloneServices.swift:143 | 刻意 CUT（.explicitCut），无符号 |
| editor.colorizeElement(domNode,opts) | function | MonaColorizeView.render(source:)/MonaColorizeHost | 🟠 | MonaColorizeView.swift:174,:69 | HTMLElement→NSTextStorage；options bag 缺；返回 void 非 Promise |
| editor.colorize(text,langId,opts) | function | MonaColorizeSource.colorize(source:[UInt16])->NSAttributedString | 🟠 | MonaColorizeSource.swift:140 | 取 [UInt16] 非 String+langId+opts；返回 NSAttributedString 非 Promise<string> |
| editor.colorizeModelLine(model,line,tabSize?) | function | MonaColorizeModelLine.colorize(model:lineNumber:layoutRecord:layoutGeneration:) throws | 🟠 | MonaColorizeModelLine.swift:219 | 无 tabSize；需 layoutRecord+generation；返回 native 结果非 HTML |
| editor.tokenize(text,langId) | function | MonaTokenizationFeature.tokenize(text:languageId:)->[[MonaToken]] | 🟡 | MonaTokenizationFeature.swift:179 | feature 类方法非全局；无 provider 时 plaintext 回退 |
| editor.defineTheme(name,data) | function | MonaThemeRegistry.defineTheme(_ theme:MonaTokenTheme)->Bool | ✅ | MonaThemeRegistry.swift:122 | 单 MonaTokenTheme 参数 vs (name,data)；返回 Bool |
| editor.setTheme(name) | function | MonaThemeRegistry.setTheme(_ id:String) | ✅ | MonaThemeRegistry.swift:100 | 拒未知 id，同 id no-op，fire onDidChangeTheme |
| editor.remeasureFonts() | function | — | ⚫ | MonaPublicAPI.swift:1089 | 缺 |
| editor.registerCommand(id,handler) | function | — | ⚫ | MonaPublicAPI.swift:1103 | MonaCommandRegistry 仅 identity/contains/isEnabled lookup |
| ILinkOpener | interface | MonaLinkOpener(protocol) | ✅ | MonaHostContracts.swift:286 | openLink(uri:MonaURI) throws->Bool；同步非 Promise；取 MonaURI |
| editor.registerLinkOpener(opener) | function | MonaHostContracts.registerLinkOpener(_:)->MonaDisposable | ✅ | MonaHostContracts.swift:258 | 在 MonaCodeEnvironment；LIFO registry |
| ICodeEditorOpener | interface | MonaCodeEditorOpener(protocol) | 🟠 | MonaHostContracts.swift:311 | 无 source 参数；target 是 enum 非 selectionOrPosition；openCodeEditor(uri:target:) throws->Bool（同步） |
| editor.registerEditorOpener(opener) | function | MonaHostContracts.registerCodeEditorOpener(_:)->MonaDisposable | ✅ | MonaHostContracts.swift:265 | 改名 registerCodeEditorOpener；在 MonaCodeEnvironment |
| BuiltinTheme | type | String+MonaColorVariant+MonaBuiltinThemes.ids | 🟡 | MonaTokenTheme.swift:35,:61 ; MonaColorRegistry.swift:86 | 无专用 string-union enum；base 存 String；stub MonaEditorBuiltinTheme:1176 |
| IStandaloneThemeData | interface | MonaTokenTheme(struct)+MonaTokenColorRule | 🟡 | MonaTokenTheme.swift:35,:20 | base 为 String 非 BuiltinTheme；rules/colors 在；无 encodedTokensColors |
| IColors | type | [String:String](MonaTokenTheme.colors) | ✅ | MonaTokenTheme.swift:39 | 字典匹配；无命名 IColors 类型 |
| ITokenThemeRule | interface | MonaTokenColorRule(struct) | ✅ | MonaTokenTheme.swift:20 | token/foreground/background/fontStyle 全在 |
| MonacoWebWorker<T> | interface | — | ⚫ | MonaPublicAPI.swift:1223 | 刻意 CUT，无符号 |
| IInternalWebWorkerOptions | interface | — | ⚫ | MonaPublicAPI.swift:1237 | 刻意 CUT |
| IActionDescriptor | interface | MonaEditorIActionDescriptor(空 protocol) | 🔴 | MonaPublicAPI.swift:1265 | 无成员；仅作 addAction 不透明参数:326；MonaActionIdentity 仅 lookup |
| IGlobalEditorOptions | interface | MonaEditorIGlobalEditorOptions(空 protocol) | 🔴 | MonaPublicAPI.swift:1280 | 无 option 成员；概念在 MonaIndentationFeature/MonaOptionStore 非 typed bag |
| IStandaloneEditorConstructionOptions | interface | MonaEditorIStandaloneEditorConstructionOptions(空 protocol) | 🔴 | MonaAppKitPublicAPI.swift:74 | 无 model/value/language/theme/accessibilityHelpUrl；仅不透明 updateOptions 参数 |
| IStandaloneDiffEditorConstructionOptions | interface | 空 protocol | 🔴 | MonaPublicAPI.swift:1295 | 无 theme/autoDetectHighContrast |
| IStandaloneCodeEditor | interface | MonaInstanceIStandaloneCodeEditor(protocol)+MonaCodeEditorView(NSView) | 🟡 | MonaEditorInstanceAdapters.swift:322 ; MonaCodeEditorView.swift:62 | updateOptions/addCommand/createContextKey/addAction 在；命名分歧；MonaCodeEditorView **不声明 conformance**；createContextKey 仅 name 无 default value |
| IStandaloneDiffEditor | interface | MonaInstanceIStandaloneDiffEditor(protocol)+MonaDiffEditorView(throws) | 🟡 | MonaEditorInstanceAdapters.swift:354 ; MonaDiffEditorEditorView.swift:44 | addCommand/createContextKey/addAction/getOriginal/ModifiedEditor 在；构造 throw `.phase07NotWired`；命名分歧 |
| ICommandHandler | interface | MonaEditorICommandHandler(空 protocol) | 🔴 | MonaPublicAPI.swift:1340 | 无 callable 成员；handler 表为 @escaping 内联闭包非命名类型 |
| ILocalizedString | interface | MonaEditorILocalizedString(空 protocol) | 🔴 | MonaPublicAPI.swift:1355 | 无 original/value；label 为 plain String |
| ICommandMetadata | interface | MonaEditorICommandMetadata(空 protocol) | 🔴 | MonaPublicAPI.swift:1370 | 无 description；MonaCommandIdentity 无 description |
| IContextKey<T> | interface | MonaContextKey(struct) | 🟠 | MonaContextKey.swift:34 | 非 generic；无 set/reset/get（只读 name wrapper）；突变经 MonaKeybindingContext.with |
| ContextKeyValue | type | MonaContextValue(enum) | 🟠 | MonaKeybindingResolver.swift:65 | 仅 .bool/.string；缺 null/undefined/number |
| IEditorOverrideServices | interface | MonaEditorIEditorOverrideServices(空 protocol) | 🔴 | MonaPublicAPI.swift:1415 | 无 subscript；override 经 MonaServiceCollection 非 index-signature bag |
| IMarker | interface | MonaMarker(3 字段)+stub | 🟠 | MonaMarker.swift:69 ; MonaPublicAPI.swift:1430 | **仅 {severity,message,tag?}——非 13 字段诊断记录**；缺 owner/resource(Uri)/code/source/start·end Line·Col/modelVersionId/relatedInformation/tags/origin |
| IMarkerData | interface | MonaMarker(3 字段)+stub | 🟠 | MonaMarker.swift:69 ; MonaPublicAPI.swift:1445 | 同 IMarker 减形状；缺 code/source/.../origin |
| IRelatedInformation | interface | MonaEditorIRelatedInformation(空 protocol) | 🔴 | MonaPublicAPI.swift:1460 | 无真类型；resource/message/start·end 全缺 |
| IColorizerOptions | interface | MonaEditorIColorizerOptions(空 protocol) | 🔴 | MonaPublicAPI.swift:1475 | 无 tabSize? |
| IColorizerElementOptions | interface | 空 protocol | 🔴 | MonaPublicAPI.swift:1490 | 无 theme?/mimeType? |
| ScrollbarVisibility | enum | MonaEditorScrollbarVisibility(空 enum) | 🔴 | MonaPublicAPI.swift:1505 | 无 Auto/Hidden/Visible case |
| ThemeColor | interface | MonaEditorThemeColor(空 protocol) | 🔴 | MonaPublicAPI.swift:1520 | 无 id；MonaColorValue/MonaResolvedColor 是分歧概念 |
| ThemeIcon | interface | MonaEditorThemeIcon(空 protocol) | 🔴 | MonaPublicAPI.swift:1535 | 无 id/color；Markdown themeIcon 无关 |
| ISingleEditOperation | interface | MonaModelEditOperation(struct) | ✅ | MonaModelEvents.swift:159 | range/text/forceMoveMarkers(=false)；text 非 null（monaco 允许 null） |
| IWordAtPosition | interface | MonaEditorIWordAtPosition(空 protocol) | 🔴 | MonaPublicAPI.swift:1565 | word/startColumn/endColumn 全缺；getWordAtPosition 返回 MonaRange?(nil) 非 IWordAtPosition |
| OverviewRulerLane | enum | MonaOverviewRulerLane(OptionSet) | 🟠 | MonaDecoration.swift:99 ; MonaPublicAPI.swift:1580 | OptionSet 非 enum；raw 值匹配(left=1,center=2,right=4,full=7) |
| GlyphMarginLane | enum | MonaEditorGlyphMarginLane(空 enum) | 🔴 | MonaPublicAPI.swift:1595 | 无 case 无 raw；Left=1/Center=2/Right=3 缺 |
| IGlyphMarginLanesModel | interface | 空 protocol | 🔴 | MonaPublicAPI.swift:1610 | requiredLanes/getLanesAtLine/reset/push 缺 |
| MinimapPosition | enum | 空 enum | 🔴 | MonaPublicAPI.swift:1625 | 无 Inline=1/Gutter=2 |
| MinimapSectionHeaderStyle | enum | 空 enum | 🔴 | MonaPublicAPI.swift:1640 | 无 Normal=1/Underlined=2 |
| IDecorationOptions | interface | 空 protocol | 🔴 | MonaPublicAPI.swift:1655 | 无 color/darkColor |
| IModelDecorationGlyphMarginOptions | interface | 空 protocol | 🔴 | MonaPublicAPI.swift:1670 | 无 position/persistLane |
| IModelDecorationOverviewRulerOptions | interface | MonaDecorationOverviewRulerOptions(struct) | 🟡 | MonaDecoration.swift:114 ; MonaPublicAPI.swift:1685 | 有 color:String?/lane；position 改名 lane；缺 darkColor?；不继承 IDecorationOptions |
| IModelDecorationMinimapOptions | interface | 空 protocol | 🔴 | MonaPublicAPI.swift:1700 | 无 position/sectionHeaderStyle/sectionHeaderText |
| IModelDecorationOptions | interface | MonaDecorationOptions(struct)+MonaModelDecorationOptions(空) | 🟡 | MonaDecoration.swift:133 ; MonaModelEvents.swift:216 | **5/34**：isWholeLine/inlineClassName/marginClassName/overviewRuler/zIndex；缺 29（stickiness/className/blockClassName/glyphMargin/hoverMessage/minimap/before/after/textDirection/...）；model 侧 MonaModelDecorationOptions 空{}，deltaDecorations→[] 桩 |
| TextDirection | enum | MonaTextDirection(enum) | 🟠 | MonaGlyphRun.swift:53 ; MonaPublicAPI.swift:1730 | ltr/rtl 在命名对；无 Int raw（monaco LTR=0/RTL=1） |
| InjectedTextOptions | interface | MonaEditorInjectedTextOptions(空 protocol) | 🔴 | MonaPublicAPI.swift:1745 | content/inlineClassName/.../cursorStops 全缺 |
| InjectedTextCursorStops | enum | 空 enum | 🔴 | MonaPublicAPI.swift:1760 | Both=0/Right=1/Left=2/None=3 缺 |
| IModelDeltaDecoration | interface | MonaEditorIModelDeltaDecoration(空 protocol) | 🔴 | MonaPublicAPI.swift:1775 | range+options 对缺；deltaDecorations 取 [MonaModelDecorationOptions](仅 options 无 range)→[] 桩 |
| IModelDecoration | interface | MonaDecoration(struct) | ✅ | MonaDecoration.swift:173 | id/range/ownerId/options 全 4 在（extra stickiness） |
| EndOfLinePreference | enum | 空 enum | 🔴 | MonaPublicAPI.swift:1805 | TextDefined=0/LF=1/CRLF=2 缺 |
| DefaultEndOfLine | enum | 空 enum | 🔴 | MonaPublicAPI.swift:1820 | LF=1/CRLF=2 缺 |
| EndOfLineSequence | enum | MonaEndOfLineSequence(enum Int) | ✅ | MonaModelOptions.swift:26 | lf=0/crlf=1 raw 匹配 |
| IIdentifiedSingleEditOperation | interface | MonaModelEditOperation(struct) | 🟡 | MonaModelEvents.swift:159 ; MonaPublicAPI.swift:1850 | 头部声称 port 此，但仅 {range,text,forceMoveMarkers}（=ISingleEditOperation 形）；缺 identifier 字段 |
| IValidEditOperation | interface | 空 protocol | 🔴 | MonaPublicAPI.swift:1865 | range/text 缺；push/applyEdits 返回 [MonaModelEditOperation] 非 IValidEditOperation |
| ICursorStateComputer | interface | 内联闭包+stub | 🔴 | MonaCodeModel.swift:525 ; MonaPublicAPI.swift:1880 | 无命名类型；内联闭包 `([MonaModelEditOperation])->[MonaSelection]?` 作 pushEditOperations 参数（签名分歧） |
| TextModelResolvedOptions | class | MonaModelOptions(struct)+stub | 🟡 | MonaModelOptions.swift:42 ; MonaPublicAPI.swift:1895 | 有 tabSize/indentSize/insertSpaces/trimAutoWhitespace；缺 defaultEOL/bracketPairColorizationOptions/originalIndentSize；class→struct；indentSize 仅 Int |
| BracketPairColorizationOptions | interface | 空 protocol | 🔴 | MonaPublicAPI.swift:1910 | enabled/independentColorPoolPerBracketType 缺；仅作 option-key string 存在 |
| ITextModelUpdateOptions | interface | MonaModelOptions(struct)+stub | 🟡 | MonaModelOptions.swift:42 ; MonaPublicAPI.swift:1925 | 有 4 字段；缺 bracketColorizationOptions?；indentSize 仅 Int |
| FindMatch | class | MonaFindMatch(struct)+stub | 🟡 | MonaModelEvents.swift:249 ; MonaPublicAPI.swift:1940 | 仅 range:MonaRange；缺 matches:string[]\|null；被桩 findMatches/findNext/Prev 用(→[]/nil) |
| TrackedRangeStickiness | enum | MonaDecorationStickiness(enum) | 🟠 | MonaDecoration.swift:52 ; MonaPublicAPI.swift:1955 | 4 case 命名对；无 Int raw |
| ITextSnapshot | interface | MonaTextSnapshot(struct) | 🟠 | MonaTextSnapshot.swift:25 | 持 units:[UInt16]+lineStarts；getText/getLineContent/getOffsetAt/getPositionAt/length/lineCount；无 read():string\|null（Swift 物化 [UInt16] 非流 string） |
| ITextModel | interface | MonaCodeModel(class) | 🟡 | MonaCodeModel.swift:41 | **最深等价，70 成员**：✅ 44（content/snapshot 13 + position/range 11 + getLanguageId + normalizeIndentation/updateOptions/pushEOL/setEOL + identity/version/events 15）；🔴 桩 17（findMatches:343→[]、findNext:354→nil、findPrev:365→nil、getWordAtPosition:382→nil、getWordUntilPosition:387→nil、deltaDecorations:394→[]、getDecorationOptions:402→nil、getDecorationRange:407→nil、getLineDecorations:412→[]、getLinesDecorations:421→[]、getDecorationsInRange:431→[]、getAllDecorations:440→[]、getAllMarginDecorations:448→[]、getOverviewRulerDecorations:453→[]、getInjectedTextDecorations:461→[]、getCustomLineHeightsDecorations:466→[]、getCustomLineHeightsDecorationsInRange:471→[]、detectIndentation:505 no-op、pushStackElement:510 no-op、popStackElement:515 no-op、undo:563 no-op、canUndo:568→false、redo:573 no-op、canRedo:578→false）；🟠 分歧 8（search 单 searchScope vs 2 overload+缺 wordSeparators/limitResultCount、word 返回 MonaRange? 非 IWordAtPosition、pushEditOperations:522 cursorStateComputer 签名分歧返回 Void、applyEdits:546 返回 reverse edits 非 overload-gated、onDidChangeLanguageConfiguration:628 payload MonaEvent<Void>） |

### 3.3 `editor` 命名空间 · part 2（.d.ts 2400–4100）

> 代理逐声明核验。计数：✅:1 🟡:5 🟠:3 🔴:33 ⚫:0 ❓:0。
> **两层模式**：`Sources/MonaCode/Generated/MonaPublicAPI.swift` 存一对一空桩保留 monaco 声明图；真实实现另放。🔴 既有"声明图桩（别处有真实实现）"也有"真缺"——见 evidence 列与 §4。

| monacoAPI | kind | monaCodeEquiv | status | evidence(file:line) | memberGaps/notes |
|---|---|---|---|---|---|
| `PositionAffinity` | enum | `MonaEditorPositionAffinity` | 🔴 | MonaPublicAPI.swift:2000 | 空 enum；5 case 全缺（Left/Right/None/LeftOfInjectedText/RightOfInjectedText） |
| `IChange` | interface | `MonaEditorIChange` | 🔴 | MonaPublicAPI.swift:2015 | 空 protocol；4 成员缺（original/modifiedStart/End LineNumber） |
| `ICharChange` | interface | `MonaEditorICharChange` | 🔴 | MonaPublicAPI.swift:2030 | 空 protocol；4 列成员缺；无 IChange 继承 |
| `ILineChange` | interface | `MonaEditorILineChange` | 🔴 | MonaPublicAPI.swift:2045 | 空 protocol；`charChanges` 缺；无 IChange 继承；在 :343 被引用 |
| `IDimension` | interface | `MonaEditorIDimension` | 🔴 | MonaPublicAPI.swift:2060 | 空 protocol；`width`/`height` 缺 |
| `IEditOperationBuilder` | interface | `MonaEditorIEditOperationBuilder` | 🔴 | MonaPublicAPI.swift:2075 | 空 protocol；`addEditOperation`/`addTrackedEditOperation`/`trackSelection` 缺 |
| `ICursorStateComputerData` | interface | `MonaEditorICursorStateComputerData` | 🔴 | MonaPublicAPI.swift:2090 | 空 protocol；`getInverseEditOperations`/`getTrackedSelection` 缺 |
| `ICommand` | interface | `MonaEditorICommand` | 🔴 | MonaPublicAPI.swift:2105 | 空 protocol；`getEditOperations`/`computeCursorState` 缺 |
| `IDiffEditorModel` | interface | `MonaEditorIDiffEditorModel` | 🔴 | MonaPublicAPI.swift:2120 | 空 protocol；`original`/`modified` 缺；在 :335,338,340 被引用 |
| `IDiffEditorViewModel` | interface | `MonaEditorIDiffEditorViewModel` | 🔴 | MonaPublicAPI.swift:2135 | 空 protocol；`model`/`waitForDiff()` 缺；无 IDisposable 继承 |
| `IModelChangedEvent` | interface | `MonaEditorIModelChangedEvent` | 🔴 | MonaPublicAPI.swift:2150 | 空 protocol；`oldModelUrl`/`newModelUrl` 缺；无 concrete struct |
| `IContentSizeChangedEvent` | interface | `MonaEditorIContentSizeChangedEvent` | 🔴 | MonaPublicAPI.swift:2165 | 空 protocol；4 成员缺；在 :238 被引用 |
| `INewScrollPosition` | interface | `MonaEditorINewScrollPosition` | 🔴 | MonaPublicAPI.swift:2180 | 空 protocol；`scrollLeft?`/`scrollTop?` 缺；在 :267 被引用 |
| `IEditorAction` | interface | `MonaEditorIEditorAction` | 🔴 | MonaPublicAPI.swift:2195 | 空 protocol；`id`/`label`/`alias`/`metadata`/`isSupported()`/`run()` 全缺 |
| `IEditorModel` | type | `MonaEditorIEditorModel` | 🔴 | MonaPublicAPI.swift:2210 | 空 struct；联合（ITextModel\|IDiffEditorModel\|IDiffEditorViewModel）未表示；MonaCodeModel 是真文本模型（别名 :78） |
| `ICursorState` | interface | `MonaEditorICursorState` | 🔴 | MonaPublicAPI.swift:2225 | 空 protocol；`inSelectionMode`/`selectionStart`/`position` 缺 |
| `IViewState` | interface | `MonaEditorIViewState` | 🔴 | MonaPublicAPI.swift:2240 | 空 protocol；5 成员缺（scrollTop/scrollTopWithoutViewZones/scrollLeft/firstPosition/firstPositionDeltaTop） |
| `ICodeEditorViewState` | interface | `MonaEditorICodeEditorViewState` | 🔴 | MonaPublicAPI.swift:2255 | 空 protocol；`cursorState`/`viewState`/`contributionsState` 缺 |
| `IDiffEditorViewState` | interface | `MonaEditorIDiffEditorViewState` | 🔴 | MonaPublicAPI.swift:2270 | 空 protocol；`original`/`modified`/`modelState?` 缺 |
| `IEditorViewState` | type | `MonaEditorIEditorViewState` | 🔴 | MonaPublicAPI.swift:2285 | 空 struct；在 :155-156 被用作参数/返回但无成员 |
| `ScrollType` | enum | `MonaEditorScrollType` | 🔴 | MonaPublicAPI.swift:2300 | 空 enum；`Smooth`/`Immediate` 缺 |
| `IEditor` | interface | `MonaInstanceIEditor`(真 protocol)+`MonaEditorIEditor`(空桩) | 🟡 | MonaEditorInstanceAdapters.swift:137 ; MonaPublicAPI.swift:2315 ; MonaCodeEditorView.swift:62 | 43 成员协议全在（onDidDispose/dispose/getId/.../createDecorationsCollection），但**无具体类型 conform**；MonaCodeEditorView 是 NSView 但无 drawRect/keyDown/mouseDown/scrollWheel/interpretKeyEvents override → 驱动层缺、组件不可驱动 |
| `IEditorDecorationsCollection` | interface | `MonaDecorationCollection`(模型级)+空桩 | 🟠 | MonaDecorationCollection.swift:28 ; MonaPublicAPI.swift:2330 | 真实集合在但形状不同：有 clear/count≈length/add/remove/decorations/allDecorations/get；缺 onDidChange、getRange(index)、getRanges、has、set(替换全部)、append([array])；add 是逐个、无索引访问、无变更事件 |
| `IEditorContribution` | interface | `MonaEditorIEditorContribution` | 🔴 | MonaPublicAPI.swift:2345 | 空 protocol；`dispose()`/`saveViewState?`/`restoreViewState?` 缺；MonaContributionRegistry 存冻结身份记录非此接口 |
| `EditorType` | const | `MonaEditorEditorType` | 🔴 | MonaPublicAPI.swift:2359 | 空 enum；ICodeEditor/IDiffEditor 常量缺 |
| `IModelLanguageChangedEvent` | interface | `MonaModelLanguageChangeEvent`(真 struct)+空桩 | 🟡 | MonaModelEvents.swift:123 ; MonaPublicAPI.swift:2374 | 有 oldLanguageId/newLanguageId；缺 `source`；命名分歧 oldLanguageId vs oldLanguage；Phase 01 不触发（恒 plaintext） |
| `IModelLanguageConfigurationChangedEvent` | interface | `MonaEditorIModelLanguageConfigurationChangedEvent`(空 marker) | 🟡 | MonaPublicAPI.swift:2389 | monaco 接口本就空，Swift 空 protocol 结构同；但 model 用 `MonaEvent<Void>` (:628) 非 Void 载荷未接此类型 |
| `IModelContentChangedEvent` | interface | `MonaModelContentChangeEvent`(真 struct)+空桩 | 🟡 | MonaModelEvents.swift:58 ; MonaPublicAPI.swift:2404 | 6/8：changes/eol/versionId/isUndoing/isRedoing/isFlush；缺 `isEolChange`、`detailedReasonsChangeLengths`；eol 用 enum vs string（语义等价小分歧） |
| `ISerializedModelContentChangedEvent` | interface | `MonaEditorISerializedModelContentChangedEvent` | 🔴 | MonaPublicAPI.swift:2419 | 仅空 protocol，无 concrete struct（异于非序列化兄弟）；7 成员缺 |
| `IModelDecorationsChangedEvent` | interface | `MonaModelDecorationChangeEvent`(真 struct)+空桩 | 🟡 | MonaModelEvents.swift:103 ; MonaPublicAPI.swift:2434 | 2/4：affectsMinimap/affectsOverviewRuler；缺 affectsGlyphMargin/affectsLineNumber；单数 Decoration vs 复数；Phase 01 不触发 |
| `IModelOptionsChangedEvent` | interface | `MonaModelOptionsChangeEvent`(真 struct)+空桩 | 🟠 | MonaModelOptions.swift:85 ; MonaPublicAPI.swift:2449 | 形状分歧：monaco 4 布尔 change-flag；Swift 包 oldOptions/newOptions 快照（含 4 字段）；布尔标志可比较推导但扁平布尔缺 |
| `IModelContentChange` | interface | `MonaModelTextChange`(真 struct)+空桩 | ✅ | MonaModelEvents.swift:30 ; MonaPublicAPI.swift:2464 | 4 成员全在：range/rangeOffset/rangeLength/text（range 用 MonaRange） |
| `CursorChangeReason` | enum | `MonaEditorCursorChangeReason` | 🔴 | MonaPublicAPI.swift:2479 | 空 enum；7 case 全缺（NotSet/ContentFlush/RecoverFromMarkers/Explicit/Paste/Undo/Redo） |
| `ICursorPositionChangedEvent` | interface | `MonaEditorICursorPositionChangedEvent` | 🔴 | MonaPublicAPI.swift:2494 | 空 protocol，无 concrete struct；position/secondaryPositions/reason/source 缺；在 :210 被引用 |
| `ICursorSelectionChangedEvent` | interface | `MonaEditorICursorSelectionChangedEvent` | 🔴 | MonaPublicAPI.swift:2509 | 空 protocol，无 concrete struct；7 成员缺；在 :177,211 被引用 |
| `AccessibilitySupport` | enum | `MonaEditorAccessibilitySupport` | 🔴 | MonaPublicAPI.swift:2524 | 空 enum；Unknown/Disabled/Enabled 缺；注：IEditorOptions.accessibilitySupport 选项值以 string-union 存在（MonaBuiltinOptions.swift:36），非此 enum |
| `EditorAutoClosingStrategy` | type | `MonaEditorEditorAutoClosingStrategy` | 🔴 | MonaPublicAPI.swift:2539 | 空 struct；4 string-union 值未实例化 |
| `EditorAutoSurroundStrategy` | type | `MonaEditorEditorAutoSurroundStrategy` | 🔴 | MonaPublicAPI.swift:2554 | 空 struct；值未实例化 |
| `EditorAutoClosingEditStrategy` | type | `MonaEditorEditorAutoClosingEditStrategy` | 🔴 | MonaPublicAPI.swift:2569 | 空 struct；值未实例化 |
| `EditorAutoIndentStrategy` | enum | `MonaEditorEditorAutoIndentStrategy` | 🔴 | MonaPublicAPI.swift:2584 | 空 enum；None/Keep/Brackets/Advanced/Full 缺 |
| `IEditorOptions` | interface | `MonaOptionStore`+`MonaBuiltinOptions`(174 选项表)+空桩 | 🟠 | MonaOptionStore.swift:34 ; MonaBuiltinOptions.swift ; MonaEditorOption.swift:199 ; MonaPublicAPI.swift:2599 | 非扁平 struct；动态 string-key 选项注册表：157 retained-input+6 computed+11 cut=174；~77/79 字段按名在（2 改名 fontLigatures/guides；3 .cut：domReadOnly/disableLayerHinting/editContext）；经 `value(for:"readOnly")` 访问非字段；语义面在、访问分歧 |
| `IDiffEditorBaseOptions` | interface | 空桩+`MonaDiffOptions`(仅计算,~2/15) | 🔴 | MonaPublicAPI.swift:2614 ; MonaDiffResult.swift:59 | 空 protocol；diff 选项不在 MonaBuiltinOptions；MonaDiffOptions 仅 maxComputationTimeMs+ignoreTrimWhitespace(+computeMoves)；13/15 缺（enableSplitViewResizing/renderSideBySide/maxFileSize/renderIndicators/originalEditable/diffWordWrap/diffAlgorithm/.../hideUnchangedRegions 等） |

### 3.4 `editor` 命名空间 · part 3（.d.ts 4100–6555）

> 代理逐声明核验。计数：✅:1 🟡:5 🟠:27 🔴:60 ⚫:6 ❓:0。
> 🔴 高主要由"空 placeholder 壳"撑起（声明图 stamp，无成员无行为）。关键：选项压平进单一 `MonaOptionStore`；ICodeEditor/IDiffEditor/IEditor 成员面协议全声明但**无具体类型 conform**（MonaCodeEditorView 只暴露 attach/detach）→ 行为面未接。

| monacoAPI | kind | monaCodeEquiv | status | evidence(file:line) | memberGaps/notes |
|---|---|---|---|---|---|
| IDiffEditorBaseOptions | interface | MonaEditorIDiffEditorBaseOptions(shell) | 🔴 | MonaPublicAPI.swift:2614 | 空 protocol；diff 选项不在 MonaOptionStore，无 MonaDiffEditorOptions 表 |
| IDiffEditorOptions | interface | MonaEditorIDiffEditorOptions(shell) | 🔴 | MonaPublicAPI.swift:2629 | 空 protocol；extends 空 IDiffEditorBaseOptions+IEditorOptions；无 conformance |
| ConfigurationChangedEvent | class | MonaOptionChangeEvent+空壳 | 🟠 | MonaEditorOption.swift:267 ; MonaOptionStore.swift:230 ; MonaPublicAPI.swift:2644 | 行为经分歧类型：MonaOptionChangeEvent 带 optionName/oldValue/newValue/isComputed；缺 monaco `hasChanged(id):boolean` 查询 API |
| IComputedEditorOptions | interface | MonaOptionStore.value(for:)+snapshot()+空壳 | 🟡 | MonaOptionStore.swift:96,214 ; MonaOptionSnapshot.swift:17 ; MonaPublicAPI.swift:2659 | 读面在：value(for)->MonaOptionValue? + snapshot()；但返回 untyped 盒非 typed `get<T>(id):T`；FindComputedEditorOptionValueById 被 CUT(:3346) |
| IEditorOption<K,V> | interface | MonaEditorOption(struct)+空壳 | 🟠 | MonaEditorOption.swift:199 ; MonaPublicAPI.swift:2674 | 带 id/name/runtimeName/disposition/kind/defaultValue/bounds/enumMembers/reads；丢 generic `<K,V>`、丢 `applyUpdate(value,update):ApplyUpdateResult<V>` |
| ApplyUpdateResult<T> | class | — | ⚫ | — | 无 Swift 类型；applyUpdate 未移植到 MonaEditorOption |
| IEditorCommentsOptions | interface | (opt "comments")+空壳 | 🟠 | MonaBuiltinOptions.swift:30 ; MonaPublicAPI.swift:2704 | 压平为 .object 默认{insertSpace,ignoreEmptyLines}；无 typed struct |
| TextEditorCursorBlinkingStyle | enum | 空 shell | 🔴 | MonaPublicAPI.swift:2719 | 空 enum 无 case（Hidden/Blink/Smooth/Phase/Expand/Solid）；cursorBlinking 选项存为 .string("blink") |
| TextEditorCursorStyle | enum | 空 shell | 🔴 | MonaPublicAPI.swift:2734 | 空 enum 无 case（Line/Block/Underline/...Thin）；cursorStyle=.string("line") |
| IEditorFindOptions | interface | (opt "find")+空壳 | 🟠 | MonaPublicAPI.swift:2749 | 压平为 .object（cursorMoveOnType/findOnType/seedSearchString/autoFindInSelection/loop/...）；无 typed struct |
| GoToLocationValues | type | 空 shell | 🔴 | MonaPublicAPI.swift:2764 | 空 struct；'peek'\|'gotoAndPeek'\|'goto' 联合未建模 |
| IGotoLocationOptions | interface | (opt "gotoLocation")+空壳 | 🟠 | MonaPublicAPI.swift:2779 | 压平为 .object（multiple*/alternative*Command）；无 typed struct |
| IEditorHoverOptions | interface | (opt "hover")+空壳 | 🟠 | MonaPublicAPI.swift:2794 | 压平为 .object（enabled/delay/sticky/hidingDelay/above/showLongLineWarning）；无 typed struct |
| OverviewRulerPosition | interface | 空 shell | 🔴 | MonaPublicAPI.swift:2809 | 空 protocol；width/height/top/right 缺 |
| RenderMinimap | enum | 空 shell | 🔴 | MonaPublicAPI.swift:2824 | 空 enum 无 case（None/Text/Blocks） |
| EditorLayoutInfo | interface | 空 shell+MonaOptionStore.layoutInfo(payload) | 🟡 | MonaPublicAPI.swift:2839 ; MonaOptionStore.swift:303 | 空 protocol；computed 选项返回占位 .object{fontInfo,glyphMargin,lineDecorationsWidth}（非 20 字段 EditorLayoutInfo）；真几何由 layout 阶段算（P0x-V1R） |
| EditorMinimapLayoutInfo | interface | 空 shell | 🔴 | MonaPublicAPI.swift:2854 | 空 protocol；renderMinimap/minimapLeft/Width/IsSampling/Scale/... 全缺 |
| ShowLightbulbIconMode | enum | 空 shell | 🔴 | MonaPublicAPI.swift:2869 | 空 enum 无 case（Off/OnCode/On） |
| IEditorLightbulbOptions | interface | (opt "lightbulb")+空壳 | 🟠 | MonaPublicAPI.swift:2884 | 压平 .object{enabled} |
| IEditorStickyScrollOptions | interface | (opt "stickyScroll")+空壳 | 🟠 | MonaPublicAPI.swift:2899 | 压平 .object{enabled,maxLineCount,defaultModel,scrollWithEditor} |
| IEditorInlayHintsOptions | interface | (opt "inlayHints")+空壳 | 🟠 | MonaPublicAPI.swift:2914 | 压平 .object{enabled,fontSize,fontFamily,padding,maximumLength} |
| IEditorMinimapOptions | interface | (opt "minimap")+空壳 | 🟠 | MonaPublicAPI.swift:2929 | 压平 .object 14 字段；无 typed struct |
| IEditorPaddingOptions | interface | (opt "padding")+空壳 | 🟠 | MonaPublicAPI.swift:2944 | 压平 .object{top,bottom} |
| IEditorParameterHintOptions | interface | (opt "parameterHints")+空壳 | 🟠 | MonaPublicAPI.swift:2959 | 压平 .object{enabled,cycle} |
| QuickSuggestionsValue | type | 空 shell | 🔴 | MonaPublicAPI.swift:2974 | 空 struct；'on'\|'inline'\|'off'\|... 联合未建模 |
| IQuickSuggestionsOptions | interface | (opt "quickSuggestions")+空壳 | 🟠 | MonaPublicAPI.swift:2989 | 压平 .object{other,comments,strings} |
| InternalQuickSuggestionsOptions | interface | (computed)+空壳 | 🟠 | MonaPublicAPI.swift:3004 | 压平 |
| LineNumbersType | type | 空 shell | 🔴 | MonaPublicAPI.swift:3019 | 空 struct；'on'\|'off'\|'relative'\|'interval'\|function 联合未建模，函数形式缺 |
| RenderLineNumbersType | enum | 空 shell | 🔴 | MonaPublicAPI.swift:3034 | 空 enum 无 case（Off/On/Relative/Interval/Custom） |
| InternalEditorRenderLineNumbersOptions | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3049 | 空 protocol；renderType/renderFn 缺 |
| IRulerOption | interface | (opt "rulers" array)+空壳 | 🟠 | MonaPublicAPI.swift:3064 | 压平 .array of {column,color} |
| IEditorScrollbarOptions | interface | (opt "scrollbar")+空壳 | 🟠 | MonaPublicAPI.swift:3079 | 压平 .object 14 字段 |
| InternalEditorScrollbarOptions | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3094 | 空 protocol；只读 resolved 字段缺 |
| InUntrustedWorkspace | type | 空 shell | 🔴 | MonaPublicAPI.swift:3109 | 空 struct；marker 类型未建模 |
| IUnicodeHighlightOptions | interface | (opt "unicodeHighlight")+空壳 | 🟠 | MonaPublicAPI.swift:3124 | 压平 .object（nonBasicASCII/invisibleCharacters/.../allowedLocales） |
| IInlineSuggestOptions | interface | (opt "inlineSuggest")+空壳 | 🟠 | MonaPublicAPI.swift:3139 | 压平 .object（enabled/mode/showToolbar/.../fontFamily） |
| RequiredRecursive<T> | type | (cut) | ⚫ | MonaPublicAPI.swift:3141 | TS 类型系统 helper，无 Swift 符号（metadata retained 但只 emit 注释块） |
| IBracketPairColorizationOptions | interface | (opt "bracketPairColorization")+空壳 | 🟠 | MonaBuiltinOptions.swift:55 ; MonaPublicAPI.swift:3168 | 压平 .object{enabled,independentColorPoolPerBracketType} |
| IGuidesOptions | interface | (opt "guides")+空壳 | 🟠 | MonaBuiltinOptions.swift:56 ; MonaPublicAPI.swift:3183 | 压平 .object{bracketPairs,bracketPairsHorizontal,highlightActiveBracketPair,highlightActiveIndentation,indentation} |
| ISuggestOptions | interface | (opt "suggest")+空壳 | 🟠 | MonaPublicAPI.swift:3198 | 压平 .object ~33 字段；无 typed struct |
| ISmartSelectOptions | interface | (opt "smartSelect")+空壳 | 🟠 | MonaPublicAPI.swift:3213 | 压平 .object{selectLeadingAndTrailingWhitespace,selectSubwords} |
| WrappingIndent | enum | 空 shell | 🔴 | MonaPublicAPI.swift:3228 | 空 enum 无 case（None/Same/Indent/DeepIndent） |
| EditorWrappingInfo | interface | 空 shell+payload | 🟡 | MonaPublicAPI.swift:3243 ; MonaOptionStore.swift:294 | 空 protocol；computed 返回 .object{wordWrap,wordWrapColumn,wrappingStrategy}（3/4，isDominatedByLongLines/isWordWrapMinified/isViewportWrapping 缺，wrappingColumn 在） |
| IDropIntoEditorOptions | interface | (opt "dropIntoEditor")+空壳 | 🟠 | MonaPublicAPI.swift:3258 | 压平 .object{enabled,showDropSelector} |
| IPasteAsOptions | interface | (opt "pasteAs")+空壳 | 🟠 | MonaPublicAPI.swift:3273 | 压平 .object{enabled,showPasteSelector} |
| EditorOption(174 ids) | enum | MonaEditorOption.id(Int)+空壳 | 🟠 | MonaEditorOption.swift:202 ; MonaBuiltinOptions.swift:33 ; MonaPublicAPI.swift:3288 | 174 稳定 id 作 Int(0..173) 源序保留；但无 174-case Swift enum；身份是运行时 Int 字段非 enum case |
| EditorOptions(174 descriptors) | const | MonaBuiltinOptions.options(array) | ✅ | MonaBuiltinOptions.swift:30,33 | 全 174 描述符移植：id/name/runtimeName/disposition/kind/defaultValue/bounds/enumMembers/reads 源序逐字；157 retained-input+6 computed+11 cut=174；MonaOptionStore 拓扑解算 computed 依赖(:44) |
| EditorOptionsType | type | (cut) | ⚫ | MonaPublicAPI.swift:3304 | `typeof EditorOptions` helper；CUT: mapped/conditional/keyof 无独立运行时值 |
| FindEditorOptionsKeyById<T> | type | (cut) | ⚫ | MonaPublicAPI.swift:3318 | CUT: TS conditional/mapped type |
| ComputedEditorOptionValue<T> | type | (cut) | ⚫ | MonaPublicAPI.swift:3332 | CUT: TS infer type |
| FindComputedEditorOptionValueById<T> | type | (cut) | ⚫ | MonaPublicAPI.swift:3346 | CUT: TS conditional type |
| MouseMiddleClickAction | type | 空 shell | 🔴 | MonaPublicAPI.swift:3373 | 空 struct；'default'\|'openLink'\|'ctrlLeftClick' 联合未建模 |
| IEditorConstructionOptions | interface | 空 shell(AppKit) | 🔴 | MonaAppKitPublicAPI.swift:90 | 空 protocol；dimension/overflowWidgetsDomNode 缺；MonaEditorFactory.create 取 MonaOptionSnapshot 非此接口(:163) |
| IViewZone | interface | 空 shell+MonaInstanceDOMWidget marker | 🔴 | MonaAppKitPublicAPI.swift:106 ; MonaEditorInstanceAdapters.swift:54 | 空 protocol；afterLineNumber/afterColumn/showInHiddenAreas/ordinal/heightInPx/domNode/... 全缺；MonaInstanceDOMWidget 仅 marker{domNode}；无具体 widget 视图 |
| IViewZoneChangeAccessor | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3388 | 空 protocol；addZone/removeZone/layoutZone 缺 |
| ContentWidgetPositionPreference | enum | 空 shell | 🔴 | MonaPublicAPI.swift:3403 | 空 enum 无 case（EXACT/ABOVE/BELOW） |
| IContentWidgetPosition | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3418 | 空 protocol；position/preference/positionAffinity 缺 |
| IContentWidget | interface | 空 shell+MonaInstanceDOMWidget | 🔴 | MonaAppKitPublicAPI.swift:122 ; MonaEditorInstanceAdapters.swift:54 | 空 protocol；getId/getDomNode/getPosition/beforeRender/afterRender/... 缺 |
| IContentWidgetRenderedCoordinate | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3433 | 空 protocol；top/left 缺 |
| OverlayWidgetPositionPreference | enum | 空 shell | 🔴 | MonaPublicAPI.swift:3448 | 空 enum 无 case（TOP_RIGHT_CORNER/BOTTOM_RIGHT_CORNER/TOP_CENTER） |
| IOverlayWidgetPositionCoordinates | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3463 | 空 protocol；top/left 缺 |
| IOverlayWidgetPosition | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3478 | 空 protocol；preference/stackOrdinal 缺 |
| IOverlayWidget | interface | 空 shell(AppKit) | 🔴 | MonaAppKitPublicAPI.swift:138 | 空 protocol；onDidLayout/getId/getDomNode/getPosition/... 缺 |
| IGlyphMarginWidget | interface | 空 shell(AppKit) | 🔴 | MonaAppKitPublicAPI.swift:154 | 空 protocol；getId/getDomNode/getPosition 缺 |
| IGlyphMarginWidgetPosition | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3493 | 空 protocol；lane/zIndex/range 缺 |
| MouseTargetType | enum | 空 shell | 🔴 | MonaPublicAPI.swift:3508 | 空 enum 无 case（14 个 UNKNOWN/TEXTAREA/GUTTER_*/CONTENT_*/...）；hit-test 未实现 |
| IBaseMouseTarget | interface | 空 shell(AppKit) | 🔴 | MonaAppKitPublicAPI.swift:170 | 空 protocol；element/position/mouseColumn/range 缺 |
| IMouseTargetUnknown..OutsideEditor (11 变体接口) | interface | 各空 shell | 🔴 | MonaPublicAPI.swift:3523–3733 | 11 个 mouse-target 变体接口全空；成员缺 |
| IMouseTarget(union) | type | 空 shell | 🔴 | MonaPublicAPI.swift:3748 | 空 struct；11 变体联合未建模；getTargetAtClientPoint 返回空 struct 无 impl(:312) |
| IEditorMouseEvent | interface | 空 shell+MonaPointerEvent(native) | 🟠 | MonaPublicAPI.swift:3763 ; MonaPointerGateway.swift:96 | 空 shell；原生 MouseEvent 适配为 MonaPointerEvent（真 struct 带 viewportPoint/deltaX/deltaY/button/modifiers）；IEditorMouseEvent wrapper(event+target)未建模；IMouseTarget 半缺 |
| IPartialEditorMouseEvent | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3778 | 空 protocol；target nullable 变体缺 |
| IPasteEvent | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3793 | 空 protocol；range/languageId/clipboardEvent 缺；onDidPaste 引用它(:225) |
| IDiffEditorConstructionOptions | interface | 空 shell(AppKit) | 🔴 | MonaAppKitPublicAPI.swift:186 | 空 protocol；overflowWidgetsDomNode/originalAriaLabel/modifiedAriaLabel 缺 |
| ICodeEditor | interface | MonaInstanceICodeEditor(面,94 成员)+空壳 | 🟡 | MonaEditorInstanceAdapters.swift:202 ; MonaAppKitPublicAPI.swift:202 | 成员面协议全声明（94 own：events/getModel/setModel/getOptions/getOption/getValue/setValue/scroll*/executeEdits/deltaDecorations/getLayoutInfo/addContentWidget/addOverlayWidget/addGlyphMarginWidget/changeViewZones/render/getTargetAtClientPoint/handleInitialized），原生类型适配（DOMNode→NSView,MouseEvent→MonaPointerEvent）；**但无具体 conformance**：MonaCodeEditorView 只暴露 attach/detach/isAttached/attachment/id，ICodeEditor 行为面全未接，驱动层缺 |
| IDiffEditor | interface | MonaInstanceIDiffEditor(面,17 成员)+空壳 | 🟡 | MonaEditorInstanceAdapters.swift:332 ; MonaAppKitPublicAPI.swift:218 | 成员面协议全声明（getContainerDomNode/onDidUpdateDiff/onDidChangeModel/saveViewState/restoreViewState/getModel/createViewModel/setModel/getOriginalEditor/getModifiedEditor/getLineChanges/updateOptions/goToDiff/revealFirstDiff/accessibleDiffViewerNext/Prev/handleInitialized）；**无 conformance**：MonaDiffEditorView 是 NSView slot；MonaEditorFactory.createDiffEditor throw .phase07NotWired(:287) |
| FontInfo | class | 空 shell+payload | 🟡 | MonaPublicAPI.swift:3808 ; MonaOptionStore.swift:270,198 | 空 final class；computed 返回 .object{fontFamily,fontSize,lineHeight,pixelRatio}（4/11 字段；缺 version/isTrusted/isMonospace/typicalHalfwidthCharacterWidth/.../maxDigitWidth） |
| BareFontInfo | class | 空 shell | 🔴 | MonaPublicAPI.swift:3823 | 空 final class；pixelRatio/fontFamily/fontWeight/fontSize/fontFeatureSettings/fontVariationSettings/lineHeight/letterSpacing 全缺 |
| EditorZoom | const | 空 shell+MonaFontZoomFeature | 🟠 | MonaPublicAPI.swift:3837 ; MonaFontZoomFeature.swift:70 | 空 enum（singleton const 未建模）；zoom 行为在 MonaFontZoomFeature（setZoom/currentZoom/onChange clamp[0.5,8.0]）—— per-feature 类非全局 EditorZoom singleton |
| IEditorZoom | interface | 空 shell | 🔴 | MonaPublicAPI.swift:3852 | 空 protocol；onDidChangeZoomLevel/getZoomLevel/setZoomLevel 缺 |
| IReadOnlyModel | type(alias) | 空 shell+MonaInstanceITextModel | 🟠 | MonaPublicAPI.swift:3867 ; MonaEditorInstanceAdapters.swift:78 | monaco `IReadOnlyModel=ITextModel`；真别名 MonaInstanceITextModel=MonaCodeModel；但公开壳是空 struct 非 typealias；MonaCodeModel 有 undo/findMatches/deltaDecorations 桩(:343,382,394,563) |
| IModel | type(alias) | 空 shell+MonaInstanceITextModel | 🟠 | MonaPublicAPI.swift:3882 ; MonaEditorInstanceAdapters.swift:78 | 同上：monaco `IModel=ITextModel`；真别名→MonaCodeModel；公开壳空 struct |

### 3.5 `languages` + `worker` 命名空间（.d.ts 6556–8785）

> 代理逐声明核验。计数（约）：✅:9 🟡:59 🔴:0 🟠:25 ⚫:105 ❓:0（总数因 TokensProvider/EncodedTokensProvider 等计法略有出入）。
> **结构**：`Sources/MonaCode/Generated/MonaPublicAPI.swift`(8257 行) 为每个 monaco `languages.*` 类型存空壳；`MonaProviderRegistry` 有 30 个 provider 挂载点（25 LSP-backed + 5 direct-only）但 `bundledLanguageServer=nil`/`bundledLanguageImplementation=nil`（**无内置语言**）；`MonaLanguageRegistry` 仅 `"plaintext"` live，其余内置语言 CUT；feature 文件有真 Swift 类型（MonaCompletionItem/MonaHover 等）；**worker 命名空间整片 CUT**（`cut-webworker-namespace`）；css/html/json/typescript 旧别名整片 CUT。

**Classes (3)**

| monacoAPI | status | monaCodeEquiv | evidence | notes |
|---|---|---|---|---|
| EditDeltaInfo | ⚫ | MonaLanguagesEditDeltaInfo | MonaPublicAPI.swift:3897 | 空 stub，无实现 |
| SelectedSuggestionInfo | ⚫ | MonaLanguagesSelectedSuggestionInfo | :5210 | 空 stub，无实现 |
| FoldingRangeKind | 🟠 | MonaFoldingRangeSource | MonaFoldingFeature.swift:47 | Swift 是 enum（manual/indentation/marker/provider）非 class；不同概念 |

**Enums (18)**

| monacoAPI | status | monaCodeEquiv | evidence | notes |
|---|---|---|---|---|
| DocumentHighlightKind | ✅ | MonaWordHighlightKind | MonaWordHighlighterFeature.swift:42 | text/read/write 对应 0/1/2；string raw vs Int |
| SymbolKind | ✅ | MonaDocumentSymbolKind | MonaDocumentSymbolsFeature.swift:35 | 全 26 case（File=0..TypeParameter=25）带 Int raw；命名分歧 |
| CompletionItemKind | 🟠 | MonaCompletionItemKind | MonaSuggestFeature.swift:39 | 26/29 case；缺 Customcolor/Issue/Tool；无 Int raw |
| CompletionTriggerKind | 🟠 | MonaCompletionTriggerKind | MonaSuggestFeature.swift:71 | 3 case 但命名分歧；无 Int raw |
| IndentAction | ⚫ | 空 stub | :4761 | 无 None/Indent/IndentOutdent/Outdent |
| HoverVerbosityAction | ⚫ | 空 stub | :4898 | 无 Increase/Decrease |
| CompletionItemTag | ⚫ | 空 stub | :4943 | 无 Deprecated=1 |
| CompletionItemInsertTextRule | ⚫ | 空 stub | :4958 | 无 None/KeepWhitespace/InsertAsSnippet |
| PartialAcceptTriggerKind | ⚫ | 空 stub | :5033 | 无 Word/Line/Suggest |
| InlineCompletionTriggerKind | ⚫ | 空 stub | :5093 | 无 Automatic/Explicit |
| InlineCompletionHintStyle | ⚫ | 空 stub | :5243 | 无 Code/Label |
| InlineCompletionEndOfLifeReasonKind | ⚫ | 空 stub | :5363 | 无 Accepted/Rejected/Ignored |
| CodeActionTriggerType | ⚫ | 空 stub | :5423 | 无 Invoke=1/Auto=2 |
| SignatureHelpTriggerKind | ⚫ | 空 stub | :5513 | 无 Invoke/TriggerCharacter/ContentChange |
| SymbolTag | ⚫ | 空 stub | :5813 | 无 Deprecated=1 |
| NewSymbolNameTag | ⚫ | 空 stub | :6263 | 无 AIGenerated=1 |
| NewSymbolNameTriggerKind | ⚫ | 空 stub | :6278 | 无 Invoke/Automatic |
| InlayHintKind | ⚫ | 空 stub | :6443 | 无 Type=1/Parameter=2 |

**Functions (36)** — `register`/`getLanguages`/`setTokensProvider`/`registerTokensProviderFactory` + 26 个 `register*Provider` 全 🟡（registry/挂载点在，无内置语言、无 function 级 API、多数无 provider protocol）；6 个 ⚫：`getEncodedLanguageId`/`onLanguage`/`onLanguageEncountered`/`setLanguageConfiguration`/`setColorMap`/`setMonarchTokensProvider`（空 stub，无实现；Monarch tokenizer 全缺）。

**Interfaces — 有真实 Swift feature 等价物（✅/🟠，28）**

| monacoAPI | status | monaCodeEquiv | evidence | notes |
|---|---|---|---|---|
| Hover | ✅ | MonaHover | MonaHoverFeature.swift:68 | contents/range；缺 canIncreaseVerbosity/canDecreaseVerbosity |
| CompletionList | ✅ | MonaCompletionList | MonaSuggestFeature.swift:157 | items/incomplete；缺 dispose() |
| CompletionContext | ✅ | MonaCompletionContext | :86 | triggerKind/triggerCharacter |
| DocumentHighlight | ✅ | MonaDocumentHighlight | MonaWordHighlighterFeature.swift:56 | range/kind |
| SemanticTokensLegend | ✅ | MonaSemanticTokenLegend | MonaSemanticTokensFeature.swift:49 | tokenTypes/tokenModifiers |
| SemanticTokensEdit | ✅ | MonaSemanticTokensEdit | :84 | start/deleteCount/data? |
| RenameLocation | ✅ | MonaRenameLocation | MonaRenameFeature.swift:40 | range/text |
| CompletionItem | 🟠 | MonaCompletionItem | MonaSuggestFeature.swift:104 | 8/~15 成员；缺 tags/preselect/insertTextRules/commitCharacters/additionalTextEdits/command/action；label/documentation/range 类型简化 |
| LinkedEditingRanges | 🟠 | MonaLinkedEditingRanges | MonaLinkedEditingFeature.swift:70 | 有 ranges；缺 wordPattern?:RegExp |
| CodeAction | 🟠 | MonaCodeAction | MonaCodeActionFeature.swift:82 | 有 title/kind/edit；缺 command/diagnostics/isPreferred/isAI/disabled/ranges |
| CodeLens | 🟠 | MonaCodelens | MonaCodelensFeature.swift:66 | 有 range/command；缺 id? |
| DocumentSymbol | 🟠 | MonaDocumentSymbol | MonaDocumentSymbolsFeature.swift:103 | 有 name/detail/kind/range/selectionRange；缺 tags/containerName/children |
| FoldingRange | 🟠 | MonaFoldingRange | MonaFoldingFeature.swift:64 | Swift 用 range+source，非 start/end/kind |
| IColorPresentation | 🟠 | MonaColorPresentation | MonaColorPickerFeature.swift:35 | 有 label；缺 textEdit/additionalTextEdits |
| IColorInformation | 🟠 | MonaColorInformation | :52 | 有 range；color 是 String 非 IColor；加 presentations |
| ILink | 🟠 | MonaLink | MonaLinksFeature.swift:42 | 待核成员，可能分歧 |
| InlineCompletion | 🟠 | MonaInlineCompletion | MonaInlineCompletionsFeature.swift:39 | 简化，缺 additionalTextEdits/uri/command/completeBracketPairs/isInlineEdit/showRange/... |
| InlayHint | 🟠 | MonaInlayHint | MonaInlayHintsFeature.swift:51 | 简化，缺 tooltip/textEdits/paddingLeft/Right/kind；label 可能 String 非 labelParts[] |
| SemanticTokens | 🟠 | MonaSemanticTokensData | :66 | 有 data；缺 resultId? |
| ParameterInformation | 🟠 | MonaParameterHintParameter | MonaParameterHintsFeature.swift:33 | 命名分歧；documentation 简化 |
| SignatureInformation | 🟠 | MonaParameterHintSignature | :50 | 命名分歧；缺 activeParameter? |
| SignatureHelp | 🟠 | MonaParameterHintsResult | :80 | 命名分歧；待核 |
| Location | 🟠 | MonaReferenceLocation | MonaReferenceSearchFeature.swift:39 | uri 是 String 非 Uri；reference-scoped 命名 |
| TextEdit | 🟠 | MonaFormatEdit | MonaFormatFeature.swift:53 | 命名分歧（format-scoped）；缺 eol? |
| SelectionRange | 🟠 | MonaSmartSelectSelectionRange | MonaSmartSelectFeature.swift:52 | 命名分歧 |
| WorkspaceEdit | 🟠 | MonaWorkspaceEdit | MonaWorkspaceEdit.swift:77 | openModelEdits/externalOperations vs monaco edits[]；重设计 |
| CommentRule | 🟠 | MonaCommentConfiguration | MonaCommentFeature.swift:36 | lineComment/blockComment{Open,Close} vs monaco string\|LineCommentConfig + CharacterPair；形状分歧 |
| ILanguageExtensionPoint | 🟠 | MonaLanguageDescriptor/Identity | MonaLanguageRegistry.swift:71,102 | 有 id/aliases/extensions/mimetypes；缺 filenames/filenamePatterns/firstLine/configuration |

**Interfaces — provider 协议（🟡，6 有协议 + 23 仅 LSP 挂载点无协议）**：有 Swift protocol 的 → CompletionItemProvider(MonaSuggestProvider)、DocumentHighlightProvider、LinkedEditingRangeProvider、TokensProvider/EncodedTokensProvider(→MonaTokenizationProvider 简化无 IState)、LinkProvider。仅 LSP 挂载点无 protocol 的 → HoverProvider/SignatureHelpProvider/ReferenceProvider/DefinitionProvider/DeclarationProvider/ImplementationProvider/TypeDefinitionProvider/DocumentSymbolProvider/CodeActionProvider/CodeLensProvider/DocumentFormattingEditProvider/DocumentRangeFormattingEditProvider/OnTypeFormattingEditProvider/DocumentColorProvider/FoldingRangeProvider/SelectionRangeProvider/DocumentSemanticTokensProvider/DocumentRangeSemanticTokensProvider/InlineCompletionsProvider/InlayHintsProvider/RenameProvider/NewSymbolNamesProvider/MultiDocumentHighlightProvider。**均无内置语言接入。**

**Interfaces — 缺失（⚫ 空壳，62）**：IRelativePattern、LanguageFilter、IToken、ILineTokens、IEncodedLineTokens、TokensProviderFactory、CodeActionContext、CodeActionProviderMetadata、LineCommentConfig、LanguageConfiguration、IndentationRule、FoldingMarkers、FoldingRules、OnEnterRule、IDocComment、IAutoClosingPair、IAutoClosingPairConditional、EnterAction、SyntaxNode、QueryCapture、IState、HoverContext、HoverVerbosityRequest、CompletionItemLabel、CompletionItemRanges、PartialAcceptInfo、IInlineCompletionChangeHint、InlineCompletionContext、IInlineCompletionModelInfo、IInlineCompletionModel、IInlineCompletionProviderOption、IInlineCompletionProviderOptionValue、InlineCompletionWarning、IInlineCompletionHint、InlineCompletions、CodeActionList、SignatureHelpResult、SignatureHelpContext、MultiDocumentHighlight、ReferenceContext、LocationLink、FormattingOptions、ILinksList、IColor、FoldingContext、WorkspaceEditMetadata、WorkspaceFileEditOptions、IWorkspaceFileEdit、IWorkspaceTextEdit、ICustomEdit、Rejection、NewSymbolName、Command、CommentThreadRevealOptions、CommentAuthorInformation、PendingCommentThread、PendingComment、CodeLensList、InlayHintLabelPart、InlayHintList、SemanticTokensEdits、IMonarchLanguage、IExpandedMonarchLanguageRule、IExpandedMonarchLanguageAction、IMonarchLanguageBracket。**全为 MonaPublicAPI.swift 空 stub，成员零，无别处实现。Monarch tokenizer DSL 完全缺席。**

**Types (15)**：ProviderResult→MonaProviderResult<Value>（🟠，7-case enum vs T\|null\|Thenable）；LanguageSelector/CharacterPair/Definition/IconPath/InlineCompletionCommand/InlineCompletionProviderGroupId/InlineCompletionsDisposeReason/InlineCompletionEndOfLifeReason/LifetimeSummary/IShortMonarchLanguageRule1/2/IMonarchLanguageRule/IShortMonarchLanguageAction/IMonarchLanguageAction（14 ⚫ 空 stub）。

**Consts (4)**：css/html/json/typescript（⚫ 整片 CUT，`cut-deprecated-builtin-pack-alias`）。

**Worker 命名空间 (3)**：worker.IMirrorTextModel/IMirrorModel/IWorkerContext（⚫ 整片 CUT，`cut-webworker-namespace`，无 Swift 符号）。

---

## §4 缺口汇总

### 4.1 计数总览

| 片段 | 范围 | ✅ | 🟡 | 🔴 | 🟠 | ⚫ | ❓ |
|---|---|---|---|---|---|---|---|
| §3.1 顶层类（成员级） | .d.ts 66–932 | 21 | 4 | 0 | 40 | 49 | 0 |
| §3.2 editor·p1 | 934–2440 | 15 | 14 | 33 | 13 | 19 | 0 |
| §3.3 editor·p2 | 2400–4100 | 1 | 5 | 33 | 3 | 0 | 0 |
| §3.4 editor·p3 | 4100–6555 | 1 | 5 | 60 | 27 | 6 | 0 |
| §3.5 languages+worker | 6556–8785 | 9 | 59 | 0 | 25 | 105 | 0 |
| **声明级合计（§3.2–3.5）** | | **26** | **83** | **126** | **68** | **130** | 0 |

> §3.1 是成员级计数（不可与声明级直接相加）。声明级（§3.2–3.5）约 433 项中，🔴126 + ⚫130 = **256 项为桩或缺失**，约 59%。但这个比例有重大前提——见 4.2。

### 4.2 结构性发现（读懂计数的前提）

**🔴/⚫ 高并不等于"59% 功能没做"。** 两个结构性设计选择使计数虚高：

1. **两层模式 / 声明图壳**：`Sources/MonaCode/Generated/MonaPublicAPI.swift`（8257 行）为 monaco **每一个** `editor.*`/`languages.*` 类型存一个空 `public protocol/enum/struct/class MonaEditorXxx {}`（零成员），仅 stamp 声明图（SHA-pinned）。真实实现另放。所以大量 🔴 是"壳在、成员未实例化"，**若别处有真实实现则行为不缺**；若别处也无才是真缺口。下文 4.3 只列后者。
2. **选项压平**：monaco ~30 个 per-domain 选项 interface（IEditorFindOptions/IEditorHoverOptions/ISuggestOptions/...）未保留为独立 typed struct，全压进单一 `MonaOptionStore`（string-key、untyped `MonaOptionValue` 盒）。但 **174 个选项描述符逐字移植 ✅**（id/name/runtimeName/disposition/kind/default/...），拓扑解算 computed 依赖。访问模式分歧（🟠），语义面在。

**另一关键结构**：`ICodeEditor`(94 成员)/`IDiffEditor`(17)/`IEditor`(43)/`IStandaloneCodeEditor` 的**成员面协议全声明**（`MonaInstanceI*`，含原生类型适配 DOMNode→NSView、MouseEvent→MonaPointerEvent），**但无任何具体类型 conform**。`MonaCodeEditorView: NSView` 仅暴露 `init/attach/detach/isAttached/attachment/id`——ICodeEditor 的 94 个行为成员（getValue/setValue/setPosition/scroll*/executeEdits/getLayoutInfo/addContentWidget/getTargetAtClientPoint/render/...）**全未接**。这就是驱动层缺口的本质（4.6）。

### 4.3 真实行为缺口（无任何实现）

按子系统列**真缺**（壳或桩且别处无真实实现）：

**A. 模型语义桩**（`Sources/MonaCode/Model/MonaCodeModel.swift`）——`ITextModel` 70 成员中 17 桩：
- undo/redo/canUndo/canRedo（no-op/恒 false）；pushStackElement/popStackElement（no-op，**无 undo 栈**）；detectIndentation（no-op）
- findMatches/findNextMatch/findPreviousMatch（→[]/nil）；getWordAtPosition/getWordUntilPosition（→nil）
- deltaDecorations + 13 个 decoration 读成员（→[]/nil）；`IModelDecorationOptions` 仅 5/34 字段

**B. marker 服务整片缺席**：setModelMarkers/getModelMarkers/removeAllMarkers/onDidChangeMarkers 全 ⚫；`IMarker`/`IMarkerData` 仅 3 字段 {severity,message,tag?}（非 monaco 13 字段）；IRelatedInformation 空。

**C. 全局模型注册缺席**：getModel(uri)/getModels()/setModelLanguage/onDidChangeModelLanguage（全局）全 ⚫；仅实例级事件在。

**D. WebWorker / worker 整片刻意 CUT**：editor.createWebWorker + MonacoWebWorker + IInternalWebWorkerOptions（`.explicitCut`）；worker 命名空间 3 接口（IMirrorTextModel/IMirrorModel/IWorkerContext）整片 CUT（`cut-webworker-namespace`）。

**E. Monarch tokenizer DSL 完全缺席**：IMonarchLanguage + IExpandedMonarchLanguageRule/Action + IMonarchLanguageBracket + 5 Monarch 类型/规则 全 ⚫；setMonarchTokensProvider ⚫。无任何 Monarch 实现。

**F. diff editor 未接**：createDiffEditor/createMultiFileDiffEditor 体无条件 throw `.phase07NotWired`；IDiffEditor 17 成员面协议声明但 MonaDiffEditorView 仅 NSView slot，无 conformance。

**G. 视图层接口全空壳**（驱动层未接的直接后果）：mouse-target 层（MouseTargetType 14 case 空 + 11 变体接口 + IMouseTarget 联合 + getTargetAtClientPoint 无 impl + hit-test 未实现）；view-zone/content-widget/overlay-widget/glyph-margin-widget 接口全空；IViewZoneChangeAccessor 空。

**H. cursor 事件无 concrete struct**：ICursorPositionChangedEvent/ICursorSelectionChangedEvent 仅空 protocol（在 adapter 里被引用但无实现）；CursorChangeReason 7 case 空。

**I. 顶层值类型 API 面约半缺**（§3.1）：Uri/Position/Range/Selection 核心值语义在，但大量 monaco 静态工具方法 ⚫——toString/clone/lift/toJSON/with/from/parse(strict)/file/revive/joinPath/isIPosition/isIRange/isISelection/compare/containsRange/plusRange/intersectRanges(结果)/setEndPosition/collapseTo*/fromPositions/compareRangesUsingStarts/Ends/spansMultipleLines 等。

**J. languages 62 个 context/result 接口空壳**（§3.5）：LanguageConfiguration/IndentationRule/OnEnterRule/IAutoClosingPair(Conditional)/IState/FormattingOptions/IColor/LocationLink/InlineCompletionContext/... 全空。且 **provider 基建在但无内置语言**（`bundledLanguageServer=nil`），仅 5 个 provider protocol 存在，23 个只挂 LSP 能力点无 protocol，css/html/json/typescript 旧别名整片 CUT。

**K. 选项枚举多 case-less**：TextEditorCursorStyle/BlinkingStyle、RenderMinimap、MouseTargetType、WrappingIndent、ContentWidgetPositionPreference、GlyphMarginLane、MinimapPosition、EndOfLinePreference、DefaultEndOfLine、ScrollbarVisibility、EditorAutoIndentStrategy、CursorChangeReason 等 空 enum（值仅作 string 存在 MonaOptionValue 盒里）。

### 4.4 类型/签名分歧（🟠，68 项）

多为 **Swift 惯用法**（可接受，但 API 面与 monaco 不一致）：
- 值类型运算符替代命名方法：`Position.equals/isBefore/isBeforeOrEqual` → `== / < / <=`；`Range.equalsRange` → `==`
- OptionSet 替代 number/bitfield：`KeyMod`、`OverviewRulerLane`
- 值类型隐式拷贝 → 无 `clone()`
- 命名分歧：`Uri→MonaURI`、`Position.lineNumber→line`、`Range.isEmpty→isFolded`、`Selection.getDirection→orientation`、`delta→translated`
- 组合替代扁平：`Range.startLineNumber→startPosition.line`、`Selection.*→anchor/activePosition`
- 实例替代静态：monaco 大量静态方法 → Swift 实例方法

**真实签名分歧**（非纯惯用法）：IEditorOptions 动态 store 非 flat struct；IModelOptionsChangedEvent 用快照非 change-flag；ProviderResult 7-case enum vs T|null|Thenable；ITextSnapshot 物化 [UInt16] 非流 string；hover/selection 类型简化（label/documentation/range 类型收窄）。

### 4.5 强等价点（✅，确证实现）

- **RegExp/Unicode**：对 test262 真实 oracle 差分（30 边界用例）——这是全仓最强的行为等价证据。
- **Piece Tree 文本模型**：ITextModel 44/70 成员（content/snapshot/position/range/events/identity）真实现 over MonaCodeModel。
- **值类型核心**：Token 全 ✅；Uri/Position/Range/Selection 的数据语义在（含端点规范化、UTF-16 列、orientation）。
- **选项表**：174 EditorOptions 描述符逐字移植 ✅。
- **主题/链接/opener**：defineTheme/setTheme/registerLinkOpener/registerEditorOpener ✅。
- **languages feature 类型**：Hover/CompletionList/CompletionContext/DocumentHighlight/SemanticTokensLegend/SemanticTokensEdit/RenameLocation ✅；SymbolKind/DocumentHighlightKind ✅。
- **事件**：EndOfLineSequence ✅；IModelContentChange 4/4 ✅。
- **取消/发射**：Emitter/CancellationTokenSource 核心功能 ✅；ISingleEditOperation ✅；IModelDecoration ✅。

### 4.6 产品级缺口（最重要）

**驱动层缺失 = 不可用编辑器**。所有组件（含上述 ✅ 等价点）在被 `MonaCodeEditorView` 的 NSView override 驱动前，端到端不可用：无 `drawRect`（CG tile 画不出来）、无 `keyDown`（keyEventGateway 收不到 NSEvent）、无 `mouseDown`（pointerGateway 收不到事件）、无 `scrollWheel`/`interpretKeyEvents`。`observeContentChange()` 重发 geometry generation 但**从不 `setNeedsDisplay`**；`MonaScrollChangeEvent` 无人订阅。`metalRenderer` 硬编码 `.notTriggeredAndAbsent`。sample 宿主是构造/attach/detach/print 冒烟测试，非 GUI 应用。

> **结论**：MonaCode 在**组件级**对 monaco-editor@0.56.0 有**真实差分等价**（RegExp/test262 + Piece Tree + 值类型 + 选项表 + 部分事件/feature 类型），但**远未达到产品级 API 对等**：~59% 声明级条目为桩/空壳（虽部分由两层模式虚高），模型语义有 17 桩（undo/redo/search/decorations），marker/全局注册/Monarch/worker/diff-构造/cursor-事件/视图层 widget/mouse-target 等子系统**真缺**，且 ICodeEditor 行为面协议声明但无 conformance、驱动层未接 → 无可用编辑器。发布裁决 `RELEASE_VERDICT.md` 的 `passed` 是**组件级契约验收 + 用户接受的非正式证据**，**不等于**本文意义上的"与 monaco-editor 公共能力对等"。

---

## §5 无法判定项 / 局限

- **无 vendored monaco 源**：本仓未 vendor monaco-editor 的 TS 源（无 `source-acquisitions/`、无 `vs/` 树）。因此本文"等价"判定基于 `.d.ts` 类型签名 + MonaCode 源码**静态对照**，**运行时行为差分**（同一输入两端实跑对比）无法做——需驱动层补完后端到端跑。
- **两层模式使 🔴/⚫ 计数虚高**：MonaPublicAPI.swift 的空声明图壳被计为 🔴/⚫，但其中部分有别处真实实现（行为不缺）。本文逐行标了 evidence，但"真实行为缺口"的精确清单仍需逐个核"壳外是否有实现"——§4.3 已做此区分，但边界项（如某些 option 枚举的 case 是否在别处以 string union 实质覆盖）可能仍需复核。
- **closure 文档覆盖盲区**：早先 `g4-r` closure 文档按 SHA-256 释义，本文以 `.d.ts` 为准后遗漏风险大幅降低，但"行为语义"仍不如源码逐行 diff 精确。
- **性能非头对头**：5 个组件级基准是绝对阈值，非 monaco 同负载同机器对比。
- **生成文件**：`Generated/MonaPublicAPI.swift` 是机器生成产物，其空壳可能随生成器变化而变；本文以当前 committed 状态为准。

---

## §6 缺口后果与功能影响

> 每个缺口 → 造成什么后果 → 导致哪些 monaco 功能无法实现。

### Tier A — 阻断可用编辑器（产品级，最高优先）

| 缺口 | 后果 | 导致无法实现的功能 |
|---|---|---|
| **A1 驱动层未接** | `MonaCodeEditorView` 无 drawRect/keyDown/mouseDown/scrollWheel/interpretKeyEvents override；`observeContentChange` 不 `setNeedsDisplay`；scroll 事件无订阅者 | **整个编辑器 UX**：窗口画不出文本、键盘无反应、鼠标点击/拖选无效、滚轮无效、IME 无效。sample app 启动 = 空白 NSView |
| **A2 ICodeEditor 94 成员无 conformance** | 行为面协议声明但 `MonaCodeEditorView` 只暴露 attach/detach | 通过 ICodeEditor API 的全部能力：`getValue/setValue`（程序化读写）、`setPosition/getPosition`、`scrollTo/revealLine/revealPosition`（跳转滚动）、`executeEdits`（批量编辑）、`addContentWidget/addOverlayWidget`（浮窗）、`getTargetAtClientPoint`（命中测试）、`render`。宿主只能直接改模型，屏幕不更新 |
| **A3 commandId→edit 未接线** | 解析器返回 commandId 但无 dispatcher 执行 | **所有键绑定命令**：Cmd+C/V/X/Z/Y/A、Cmd+F、Cmd+S、自定义快捷键全不生效；连默认"打字插入字符"都断 |
| **A4 diff 构造 throw `.phase07NotWired`** | `createDiffEditor` 一调就抛 | side-by-side 差异对比、行内 diff、multi-file diff 全不可用 |
| **A5 IME/选区未接** | `interpretKeyEvents` 不转发 compositionSession；选区 provider 恒 (0,0) | ① 中日韩输入法（合成窗/候选词）无效；② 选区真值错 → 复制/粘贴范围、IME 插入点、AX 读选区全错 |

### Tier B — 真实功能缺口（monaco 有、MonaCode 桩/缺）

| 缺口 | 后果 | 导致无法实现的功能 |
|---|---|---|
| **B1a undo/redo 桩**（no-op/恒 false，无栈） | undo() 不还原、canUndo 恒 false | **撤销/重做完全失效**（Cmd+Z/Y）、cursor undo 导航、所有可逆编辑语义 |
| **B1b findMatches/findNext/Prev 桩**（→[]/nil） | model 侧搜索返回空 | **查找/替换**：Cmd+F、找下一个/上一个、正则搜索、替换全部、高亮所有匹配、增量搜索 |
| **B1c getWordAtPosition/Until 桩**（→nil） | 不识别词边界 | 双击选词、按词移动光标、Ctrl+Click 跳转、拼写/词边界特性 |
| **B1d deltaDecorations + 13 decoration 成员桩** | 装饰读写返回空 | **所有基于 decoration 的视觉**：错误/警告波浪线、搜索高亮、断点、行号区图标、minimap/概览尺标记、注入文本、悬浮提示 |
| **B2 marker 服务缺席**（IMarker 仅 3 字段，无写 API） | 无诊断载体 | **诊断显示**：LSP diagnostics、编译错误、squiggly 下划线、问题面板、F8 错误导航 |
| **B3 全局模型注册缺席** | getModel(uri)/getModels() ⚫ | 跨编辑器按 URI 查模型、全局监听模型创建/销毁/语言变更、多编辑器共享模型、文件↔模型映射 |
| **B4 Monarch tokenizer DSL 完全缺席** | 无声明式词法分析器 | **内置语言除 plaintext 外无语法高亮**（css/html/json/ts 靠 Monarch） |
| **B5 cursor 事件无 concrete struct** | onDidChangeCursorPosition/Selection 发不出有效载荷 | 光标移动联动：状态栏行列号、面包屑、word highlight 触发、选区变更响应 |
| **B6 widget/mouse-target 层全空壳** | IContentWidget/IOverlayWidget/IGlyphMarginWidget/IViewZone 空；MouseTargetType 14 case 空；getTargetAtClientPoint 无 impl | ① 内容 widget（hover/completion/参数提示/诊断浮窗/内联提示）；② overlay widget（find 栏/minimap/滚动指示）；③ glyph margin widget（折叠/断点/git 装饰）；④ view zone（折叠/sticky scroll/嵌入视图）；⑤ hit-test（点击命中、链接/折叠点击、光标定位） |
| **B7 顶层值类型静态工具约半缺** | Uri/Position/Range/Selection 缺 toString/clone/with/from/parse(strict)/file/revive/joinPath/compare/containsRange/plusRange/intersectRanges/collapseTo* 等 | 宿主用 monaco 惯用 API 操作位置/范围时缺方法；**Uri.file/parse/joinPath 缺 → 文件 URI 构造/路径拼接失效**（打开文件、资源定位）。移植上游/扩展处处卡壳 |
| **B8 languages 62 context/result 接口空壳** | LSP 请求/响应上下文与结果类型未实现 | LSP 集成完整性：SignatureHelpContext（triggerKind/isRetrigger）、CodeActionList/InlineCompletions/SignatureHelpResult/ILinksList（缺 items/dispose）等 |
| **B9 无内置语言**（bundledLanguageServer=nil） | 仅 plaintext live | **开箱无语法高亮、无语言配置**（括号自动闭合/缩进/注释/折叠规则）、无语言感知补全/格式化/跳转。必须外接 LSP 但无语言接入 → .ts/.json/.css 都是纯文本 |
| **B10 选项枚举多 case-less** | 选项值仅作 string 存在 MonaOptionValue 盒，无类型安全枚举 | 选项无编译期校验（拼错不报）；枚举渲染分支可能不完整（cursorStyle/minimap 回显 string 而非 enum case）。功能值在但类型安全 + 部分分支缺 |
| **B11 布局/字体信息不全** | EditorLayoutInfo 仅 3 字段、FontInfo 4/11、wrappingInfo 3/4；layout 阶段（P0x-V1R）未做 | 精确像素布局算不出：区域宽度不准 → 自定义渲染对齐错位；FontInfo 缺 typicalHalfwidthCharacterWidth → 光标像素定位/等宽测算不准；换行分支不完整 |
| **B12 contribution/action 框架空壳** | IEditorContribution/IEditorAction/ICommandDescriptor 空；全局 addCommand/addEditorAction/registerCommand ⚫ | **扩展模型**：第三方无法注册命令/快捷键/动作；contribution 生命周期（saveViewState/restoreViewState/dispose）无接口 |

### Tier C — 类型/签名分歧（🟠）

| 类别 | 后果 |
|---|---|
| Swift 惯用法（运算符 `==/</<=` 替代命名方法、OptionSet、值类型无 clone、命名/组合/静态分歧） | **移植摩擦**：把 monaco 上游 TS 代码或现有扩展搬到 Swift 时处处需改 API 形态。不阻断功能，但移植成本高、API 文档不一致 |
| 真签名分歧（IEditorOptions 动态 store、ProviderResult 7-case enum、ITextSnapshot 物化 [UInt16]、hover/completion 类型收窄、IMarker/WorkspaceEdit 重设计） | 与 monaco 生态互操作摩擦：不能直接 `options.fontSize` 读取；provider 实现要适配 7-case enum；hover/completion 结构比 monaco 窄，承载不全上游语义 |

### Tier D — 刻意 CUT（设计决定，非缺陷）

| 缺口 | 后果 |
|---|---|
| worker 命名空间 + WebWorker CUT | **语言服务 worker 模式不可用**——monaco 重型语言特性（TS 语义补全/诊断）跑在 Web Worker 防阻塞；Swift 整片 CUT → 语言服务须主线程跑或不跑。结合 B9，重型语言智能不存在 |
| css/html/json/typescript 旧别名 CUT | 旧全局别名不可用（上游已 deprecated，影响小） |
| TS 类型 helper CUT（RequiredRecursive/FindEditorOptionsKeyById/...） | 泛型/条件类型查找 API 无 Swift 对应（TS-only，影响可忽略） |

### 最致命的三条

A1（驱动层）+ A2（ICodeEditor 未 conform）+ B1a（undo/redo 桩）——前两条让编辑器完全不可用，第三条让即使接通也"无 undo 不可用"。其次：A3（命令未接）+ B1d（decorations 桩）+ B2（marker 缺）+ B4（Monarch 缺）——分别断掉快捷键/视觉装饰/诊断/语法高亮。

