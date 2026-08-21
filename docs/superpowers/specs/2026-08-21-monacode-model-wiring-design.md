# MonaCode Model 接线设计（子项目 A）

> 本文件是设计文档（design spec），属证据/历史，**非当前进展权威**。当前进展权威为 [README 任务台账](../../../README.md#tasks)；贡献者规则见 [AGENTS.md](../../../AGENTS.md)。

## 1. 背景与动机

product-integration-probe 报 `MODEL_RETAINED_MEMBERS_STUBBED`（taskIDs P01-T008/P02-T001/T002/T003）：MonaCodeModel 的 search/word/decoration/undo-redo 是 no-op stub（findMatches 返 []、findNextMatch 返 nil、deltaDecorations 返 []、canUndo/canRedo 返 false、"No-op until Phase 02" 注释），且无 searchEngine/wordResolver/decorationStore/undoRedoStack 4 个 token。

**关键发现（降低工作量）**：底层原语**已实现 + 测试全过**——
- 搜索原语（`Sources/MonaCode/Model/Search/`：MonaLiteralSearch/MonaWordClassifier/MonaGraphemeSegmenter/MonaReplacePattern）：P02-T003 MonaWordSearchTests 34/0 过。
- undo 原语（`Sources/MonaCode/Model/Undo/`：MonaUndoRedoStack/MonaUndoRedoElement）：P02-T001 MonaUndoRedoTests 19/0 过。
- 装饰原语（`Sources/MonaCode/Model/Decorations/`：MonaDecorationCollection/MonaDecorationTree/MonaDecoration）：P02-T002 MonaDecorationTreeDifferentialTests 18/0 过。

所以 A 不是从零实现——是 **MonaCodeModel 接线**：model 加 4 属性持有原语 + 方法委托 + 删 stub。不重复开发原语（用户明确要求）。

## 2. 范围

**在范围内**：
1. MonaCodeModel 加 4 stored property（持有原语，正好是 probe 要的 4 token）。
2. 委托 + 适配：findMatches/findNextMatch/findPreviousMatch/getWordAtPosition/getWordUntilPosition/deltaDecorations/canUndo/canRedo/undo/redo 委托到原语。
3. 删 stub（`return []/nil/false` + "No-op until Phase 02" 注释）。
4. 补行为测试（surface tests 加断言，防 Ruling I exit-only 放过行为错）。
5. probe MODEL_RETAINED_MEMBERS_STUBBED 消除 + P01-T008 surface 过 + 新行为测试过。

**不在范围内**：
- 重新实现原语（已实现 + 测试过，不重复开发）。
- model 的 70 成员中非 search/word/decoration/undo 的部分（已过）。
- 子项目 B/C/D（服务接线/API payload/sample host）。

## 3. 数据来源（已确认）

- **stub 方法签名**（MonaCodeModel.swift）：findMatches(searchString, searchScope: MonaModelSearchScope, isRegex, matchCase, captureMatches)→[MonaFindMatch]；findNextMatch/findPreviousMatch(同)→MonaFindMatch?；getWordAtPosition/getWordUntilPosition(position:MonaPosition)→MonaRange?；deltaDecorations(...)；undo()/canUndo()→Bool/redo()/canRedo()→Bool。
- **原语 API**：
  - MonaLiteralSearch：findNext(in:[UInt16], fromOffset:)→MonaSearchMatch?；findPrevious(in:fromOffset:)→MonaSearchMatch?；findAll(in:fromOffset:limit:)→[MonaSearchMatch]。
  - MonaWordClassifier：wordClass/isWordSeparator/isWhitespace/isWordCharacter(codeUnit:UInt16)。
  - MonaDecorationCollection：count/decorations(in:)/allDecorations/get(id:)。
  - MonaUndoRedoStack：push/clear/undo()→MonaUndoRedoReplayOutcome/redo()→outcome。
- **类型**：MonaFindMatch={range:MonaRange}（MonaModelEvents.swift:249）；PieceTree.getText()→[UInt16]（MonaPieceTree.swift:250）/getLineContent→[UInt16]。
- **surface tests 现状**：testSurfaceMembership 是「成员存在」夹具（`_ = model.findMatches(...)` 不断言结果）；testGetValue/LineQueries/OffsetDelegate 是 PieceTree 委托测试（有断言）。findMatches/canUndo 部分无行为断言 → A 要补。

## 4. 核心设计

### 4.1 MonaCodeModel 加 4 stored property

```swift
// 持有 Phase-02 已实现的原语（probe modelPositive tokens）
private var searchEngine: MonaLiteralSearch  // 按 isRegex/matchCase 构造
private var wordResolver: MonaWordClassifier
private var decorationStore: MonaDecorationCollection
private var undoRedoStack: MonaUndoRedoStack
```
model init（或 lazy）创建。searchEngine 按 isRegex/matchCase 构造（或每次 find 构造）。`private` 即可（probe 只查 token 字符串在文件，不查可见性）。

### 4.2 委托 + 适配

**搜索**：
```swift
public func findMatches(searchString, searchScope, isRegex, matchCase, captureMatches) -> [MonaFindMatch] {
  let engine = MonaLiteralSearch(needle: searchString, isRegex: isRegex, matchCase: matchCase, ...)  // 读原语 init
  let haystack = pieceTree.getText()  // [UInt16]，按 searchScope 取范围（fullModel=全文）
  return engine.findAll(in: haystack, fromOffset: 0).map { MonaFindMatch(range: MonaRange(from: $0)) }
}
```
- findNextMatch/findPreviousMatch 委托 engine.findNext/findPrevious（fromOffset = position offset）。
- MonaSearchMatch → MonaFindMatch：MonaSearchMatch 含 offset/length → MonaRange（offset/length）。读 MonaSearchMatch 字段适配。
- searchScope: MonaModelSearchScope——实现时确认枚举（fullModel vs range），fullModel=全文。

**单词**：
- getWordAtPosition/getWordUntilPosition：取 position 附近 UTF-16 → MonaWordClassifier 找 word 边界 → MonaRange。
- MonaWordClassifier.wordClass 逐 code unit 分类，找 word 起止。

**装饰**：
- deltaDecorations(oldDecorations: [String], newDecorations: [...])：委托 decorationStore（MonaDecorationCollection）apply diff（移除 old、加 new、返新 ID）。读 MonaDecorationCollection 全 API 确认 apply/replace 方法；若无，加一个 apply 方法（属 A 范围，原语侧小扩）。

**undo/redo**：
- canUndo = !undoRedoStack.isEmpty（或 stack 公开 canUndo；若无，加 isEmpty/canUndo 到 stack，属 A 范围小扩）。
- undo()/redo() 委托 stack.undo()/redo()，apply outcome 到 PieceTree（读 MonaUndoRedoReplayOutcome 结构）。

### 4.3 删 stub + "No-op until Phase 02" 注释

删除所有 `return []/nil/false` stub 体（343-394, 563-578 行附近）+ "No-op until Phase 02" 注释（506/511/516/564/574 行附近）。

### 4.4 补行为测试

surface tests 加断言（MonaCodeModelSurfaceTests.swift 或新测试）：
- `testFindMatchesDelegatesToSearchEngine`：model("Hello World") findMatches("World") → [MonaFindMatch(range: offset 6 length 5)]，非空。
- `testCanUndoAfterEdit`：model edit 后 canUndo()==true，undo 后 canRedo()==true。
- `testDeltaDecorationsReturnsNonEmpty`：deltaDecorations([], [decoration]) → 非空 ID。
对照 monaco 行为（findMatches 返真 matches）。

### 4.5 验收

- probe `MODEL_RETAINED_MEMBERS_STUBBED` 消失（4 token 在 + 无 stub 模式 + 无 "No-op" 注释）。
- P01-T008 MonaCodeModelSurfaceTests 过（成员存在 + 新行为断言）。
- P02-T001/T002/T003 原语测试仍过（已过，不破）。
- 全套 .mjs governance 仍过（A 不碰治理工具）。
- 重跑 task-acceptance-runner → P01-T008（+P02-T001/T002/T003）GREEN exit 0 → MODEL-008/012/013/014 task acceptancePassed=true + probe finding 消失 → capture classify MODEL-008 等 BLOCKED→DONE → 台账 done 数增。

## 5. 治理合规

- **commit 绑 task ID**：A 改 MonaCodeModel.swift（MODEL-008 task 的 product target）。commit subject 绑 `MODEL-008`（+涉及 MODEL-012/013/014 的部分）。或绑 `VERIFY-001`（E 基建延续——但 A 是产品实现, 绑 MODEL-008 更准）。**ruling：绑 MODEL-008**（对应 task）。
- **不动 g6-r 冻结字节**；不改 200 任务验收命令定义。
- **marker 契约**：A 实现后 P01-T008/P02 的 expectedOutputIncludes marker（WORD_SEARCH_PARITY 等）应仍过（原语测试已 print marker）。A 不碰 marker。

## 6. 风险与缓解

| 风险 | 缓解 |
|---|---|
| Ruling I exit-only 放过行为错（委托适配错但 exit 0） | 补行为测试（4.4）断言 findMatches 返真 matches，防放过 |
| MonaSearchMatch→MonaFindMatch 适配错（offset/length 映射） | 行为测试断言 range，对照 monaco |
| searchScope 类型不明 | 实现时确认 MonaModelSearchScope 枚举，fullModel=全文 |
| decorationStore/undoRedoStack 缺 apply/canUndo 方法 | 属 A 小扩（加 apply/isEmpty 到原语侧，不重复实现原语逻辑） |
| undo outcome apply 到 PieceTree 复杂 | 读 MonaUndoRedoReplayOutcome 结构，apply edits 到 PieceTree |

## 7. 后续

A 完成后，probe MODEL_RETAINED_MEMBERS_STUBBED 消失，MODEL-008/012/013/014 转 DONE。但 B/C/D 仍有 9 个缺口（marker/diff factory/feature 等），台账仍 BLOCKED。A 是关键路径（model 底层），B 部分依赖 A（marker service 可能用 model decoration/search）。
