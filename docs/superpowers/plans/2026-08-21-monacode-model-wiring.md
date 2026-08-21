# MonaCode Model 接线实现计划（子项目 A）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MonaCodeModel 加 4 属性持有 Phase-02 已实现原语 + findMatches/canUndo/redo 等方法委托 + 删 stub，消除 probe MODEL_RETAINED_MEMBERS_STUBBED，让 MODEL-008/012/013/014 转 DONE。

**Architecture:** 接线级——原语（Search/Undo/Decorations/）已实现 + 测试过（P02-T001/T002/T003 全绿），MonaCodeModel 加 4 stored property + 方法委托 + 适配（haystack/MonaSearchMatch→MonaFindMatch/searchScope/outcome apply），不重新实现原语。

**Tech Stack:** Swift 6（SwiftPM）、XCTest、`/usr/bin/xcrun swift test`。

**Spec:** `docs/superpowers/specs/2026-08-21-monacode-model-wiring-design.md`

## Global Constraints

- **不重新实现原语**（Search/Undo/Decorations/ 已实现 + 测试过，只接线委托；若原语缺 apply/isEmpty/canUndo 这类小方法，可在原语侧加，但不重写原语逻辑）。
- 不动 `docs/contracts/.../g6-r/` 任何字节；不改 200 任务验收命令定义。
- commit subject 绑 `MODEL-008`（A 改 MonaCodeModel.swift，对应 P01-T008；涉及 MODEL-012/013/014 的 undo/decoration/search 部分可一并在 commit body 列）。
- Node `/opt/homebrew/Cellar/node/26.7.0/bin/node`；xcrun `/usr/bin/xcrun`。
- 验收 marker：P01-T008 surface（MonaCodeModelSurfaceTests）、P02-T001（UNDO_REDO_PARITY traces=420）、P02-T002（DECORATION_TREE_PARITY traces=10000）、P02-T003（WORD_SEARCH_PARITY fixtures=180）——A 不破坏原语测试。
- subagent 读原语 API（`MonaLiteralSearch.init/findNext/findPrevious/findAll`、`MonaWordClassifier.wordClass`、`MonaDecorationCollection`、`MonaUndoRedoStack.undo/redo`、`MonaPieceTree.getText/getLineContent`、`MonaSearchMatch`/`MonaFindMatch`/`MonaUndoRedoReplayOutcome` 字段）确认 init 参数 + 字段名后写适配。

---

## File Structure

| 文件 | 职责 | 动作 |
|---|---|---|
| `Sources/MonaCode/Model/MonaCodeModel.swift` | 4 stored property + 委托 + 删 stub | Modify |
| `Tests/MonaCodeTests/Model/MonaCodeModelSurfaceTests.swift` | 行为测试（findMatches/canUndo/deltaDecorations 返真值） | Modify |
| `Sources/MonaCode/Model/Decorations/MonaDecorationCollection.swift` | 加 apply（若缺） | Modify（小扩） |
| `Sources/MonaCode/Model/Undo/MonaUndoRedoStack.swift` | 加 isEmpty/canUndo（若缺） | Modify（小扩） |

---

### Task 1: 4 stored property + init

**Files:** Modify `Sources/MonaCode/Model/MonaCodeModel.swift`

**Interfaces:**
- Consumes: MonaLiteralSearch/MonaWordClassifier/MonaDecorationCollection/MonaUndoRedoStack（原语类型）
- Produces: MonaCodeModel 持有 `searchEngine`/`wordResolver`/`decorationStore`/`undoRedoStack` 4 属性（probe modelPositive tokens）

- [ ] **Step 1: 写测试** — 在 MonaCodeModelSurfaceTests 加（或确认已有）testSurfaceMembership 仍过（init 不破）。确认 4 token 在文件：`grep -nE "searchEngine|wordResolver|decorationStore|undoRedoStack" Sources/MonaCode/Model/MonaCodeModel.swift` 应有 4 行（声明）。

- [ ] **Step 2: 跑确认** — `/usr/bin/xcrun swift test --filter MonaCodeModelSurfaceTests --scratch-path /tmp/monacode-a` 应过（init 加 4 属性不破成员测试）。

- [ ] **Step 3: 实现** — MonaCodeModel 加 4 stored property + init 创建：
```swift
// 持有 Phase-02 已实现原语（probe MODEL_RETAINED_MEMBERS_STUBBED 的 modelPositive tokens）
private var searchEngine: MonaLiteralSearch
private var wordResolver: MonaWordClassifier
private var decorationStore: MonaDecorationCollection
private var undoRedoStack: MonaUndoRedoStack
// init 里创建（读各原语 init 签名填参数；MonaWordClassifier/MonaDecorationCollection/MonaUndoRedoStack 默认 init；
//  searchEngine 可在 find 时按 isRegex/matchCase 构造，或存默认后重建——读 MonaLiteralSearch.init 决定）
```
读各原语 `init` 签名填参数。searchEngine 若依赖 searchString/isRegex/matchCase（每次 find 不同），存一个默认 + find 时按参数重建，或 find 时局部构造。

- [ ] **Step 4: 跑确认过** — Step 2 命令 PASS。

- [ ] **Step 5: Commit**
```bash
git add Sources/MonaCode/Model/MonaCodeModel.swift
git commit -m "feat(MODEL-008): add 4 primitive stored properties to MonaCodeModel"
```

---

### Task 2: 搜索委托（findMatches/findNextMatch/findPreviousMatch）

**Files:** Modify `Sources/MonaCode/Model/MonaCodeModel.swift` + `Tests/MonaCodeTests/Model/MonaCodeModelSurfaceTests.swift`

**Interfaces:**
- Consumes: MonaLiteralSearch.findNext/findPrevious/findAll(in:[UInt16],fromOffset:limit:)→MonaSearchMatch?/[]；MonaPieceTree.getText()→[UInt16]；MonaSearchMatch 字段（offset/length）
- Produces: findMatches/findNextMatch/findPreviousMatch 委托返真 [MonaFindMatch]/MonaFindMatch?（非 stub []/nil）

- [ ] **Step 1: 写失败测试**
```swift
func testFindMatchesDelegatesToSearchEngine() {
    let model = MonaModelFactory.createModel(from: "Hello World Hello")
    let matches = model.findMatches(searchString: "Hello", searchScope: .fullModel, isRegex: false, matchCase: false, captureMatches: false)
    XCTAssertEqual(matches.count, 2, "findMatches returns real matches, not []")
    XCTAssertEqual(matches[0].range, MonaRange(startOffset: 0, endOffset: 5))  // 读 MonaRange init 确认 startOffset/endOffset or offset/length
}
```
（读 MonaRange init + MonaFindMatch.range 确认字段名；MonaModelSearchScope .fullModel 确认枚举 case）

- [ ] **Step 2: 跑确认 fail** — `swift test --filter testFindMatchesDelegatesToSearchEngine` fail（stub 返 []，count 0≠2）。

- [ ] **Step 3: 实现委托**
```swift
public func findMatches(searchString: String, searchScope: MonaModelSearchScope, isRegex: Bool, matchCase: Bool, captureMatches: Bool) -> [MonaFindMatch] {
    let engine = MonaLiteralSearch(needle: searchString, isRegex: isRegex, matchCase: matchCase, /* 读 init 参数 */)
    let haystack: [UInt16] = pieceTree.getText()  // fullModel；searchScope range 时取子区间
    return engine.findAll(in: haystack, fromOffset: 0).map { sm in
        MonaFindMatch(range: MonaRange(/* offset=sm.offset, length=sm.length — 读 MonaSearchMatch 字段 */))
    }
}
// findNextMatch/findPreviousMatch 委托 engine.findNext/findPrevious(in: haystack, fromOffset: position offset)
```
读 MonaSearchMatch 字段（offset/length）+ MonaRange init 适配。

- [ ] **Step 4: 跑确认过** — Step 1 PASS。

- [ ] **Step 5: Commit**
```bash
git add Sources/MonaCode/Model/MonaCodeModel.swift Tests/MonaCodeTests/Model/MonaCodeModelSurfaceTests.swift
git commit -m "feat(MODEL-008/014): wire findMatches/findNext/findPrevious to MonaLiteralSearch"
```

---

### Task 3: 单词委托（getWordAtPosition/getWordUntilPosition）

**Files:** Modify `Sources/MonaCode/Model/MonaCodeModel.swift` + surface tests

**Interfaces:**
- Consumes: MonaWordClassifier.wordClass/isWordCharacter(UInt16)；PieceTree getLineContent/position→offset
- Produces: getWordAtPosition/getWordUntilPosition 返真 MonaRange?（非 nil）

- [ ] **Step 1: 写失败测试**
```swift
func testGetWordAtPositionDelegatesToWordResolver() {
    let model = MonaModelFactory.createModel(from: "hello world")
    let range = model.getWordAtPosition(MonaPosition(line: 1, column: 1))
    XCTAssertNotNil(range, "getWordAtPosition returns real range, not nil")
    XCTAssertEqual(range?.startOffset, 0)  // word "hello" at offset 0
}
```

- [ ] **Step 2: 跑确认 fail**（stub 返 nil）。

- [ ] **Step 3: 实现** — 取 position 所在行的 UTF-16，从 column 起向前/向后找 word 边界（MonaWordClassifier.wordClass 判 word char vs separator），返 MonaRange(startOffset, endOffset)。

- [ ] **Step 4: 跑确认过**。

- [ ] **Step 5: Commit** — `feat(MODEL-008): wire getWordAtPosition/getWordUntilPosition to MonaWordClassifier`

---

### Task 4: 装饰委托（deltaDecorations）

**Files:** Modify `Sources/MonaCode/Model/MonaCodeModel.swift` + `Sources/MonaCode/Model/Decorations/MonaDecorationCollection.swift`（若缺 apply） + surface tests

**Interfaces:**
- Consumes: MonaDecorationCollection（count/get/allDecorations/decorations(in:)）；若缺 apply(removing:adding:)→[String] 则加
- Produces: deltaDecorations 返真 [String] ID（非 []）

- [ ] **Step 1: 写失败测试**
```swift
func testDeltaDecorationsReturnsNonEmptyIDs() {
    let model = MonaModelFactory.createModel(from: "abc")
    let ids = model.deltaDecorations([], [/* 读 MonaModelDeltaDecoration init 构造一个 */])
    XCTAssertFalse(ids.isEmpty, "deltaDecorations returns real IDs, not []")
}
```

- [ ] **Step 2: 跑确认 fail**（stub 返 []）。

- [ ] **Step 3: 实现** — deltaDecorations(oldDecorations, newDecorations) 委托 decorationStore.apply(removing: oldDecorations, adding: newDecorations)→[String]。若 MonaDecorationCollection 无 apply，加一个（属 A 小扩，组合 count/get/remove/add，不重写装饰树逻辑）。

- [ ] **Step 4: 跑确认过** + P02-T002 MonaDecorationTreeDifferentialTests 仍过（不破原语）。

- [ ] **Step 5: Commit** — `feat(MODEL-008/013): wire deltaDecorations to MonaDecorationCollection`

---

### Task 5: undo/redo 委托

**Files:** Modify `Sources/MonaCode/Model/MonaCodeModel.swift` + `Sources/MonaCode/Model/Undo/MonaUndoRedoStack.swift`（若缺 isEmpty） + surface tests

**Interfaces:**
- Consumes: MonaUndoRedoStack.undo()/redo()→MonaUndoRedoReplayOutcome；push(_:)；若缺 isEmpty/canUndo 则加
- Produces: canUndo/canRedo/undo/redo 委托返真值（非 false/no-op）

- [ ] **Step 1: 写失败测试**
```swift
func testCanUndoAfterEdit() {
    let model = MonaModelFactory.createModel(from: "abc")
    model.applyEdit(/* 读 model edit API，apply 一笔 edit */)
    XCTAssertTrue(model.canUndo(), "canUndo true after edit, not false")
    model.undo()
    XCTAssertTrue(model.canRedo(), "canRedo true after undo")
}
```

- [ ] **Step 2: 跑确认 fail**（canUndo 返 false）。

- [ ] **Step 3: 实现** — canUndo = !undoRedoStack.isEmpty（或 stack.canUndo；若无，加 isEmpty computed property 到 MonaUndoRedoStack，属 A 小扩）。undo()/redo() 委托 stack.undo()/redo()→outcome，读 MonaUndoRedoReplayOutcome 结构 apply edits 到 PieceTree（若 outcome 含 edit operations）。

- [ ] **Step 4: 跑确认过** + P02-T001 MonaUndoRedoTests 仍过（不破原语）。

- [ ] **Step 5: Commit** — `feat(MODEL-008/012): wire canUndo/canRedo/undo/redo to MonaUndoRedoStack`

---

### Task 6: 删 stub + No-op 注释 + probe 验证 + 验收

**Files:** Modify `Sources/MonaCode/Model/MonaCodeModel.swift`（删残留 stub + 注释）

- [ ] **Step 1: 删残留** — 删所有 "No-op until Phase 02" 注释（506/511/516/564/574 行附近）+ 任何残留 `return []/nil/false` stub（Task 2-5 应已替换，但检查 getWordUntilPosition 等未覆盖的）。

- [ ] **Step 2: probe 验证** — `/opt/homebrew/Cellar/node/26.7.0/bin/node Comparators/probes/product-integration-probe.mjs 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print([f['id'] for f in d['findings'] if f['id']=='MODEL_RETAINED_MEMBERS_STUBBED'])"` 应返 `[]`（finding 消失）。

- [ ] **Step 3: 全套验收**
```bash
/usr/bin/xcrun swift test --filter MonaCodeModelSurfaceTests --filter MonaWordSearchTests --filter MonaUndoRedoTests --filter MonaDecorationTreeDifferentialTests --scratch-path /tmp/monacode-a 2>&1 | grep -E "Executed [0-9]+ tests, with"
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/check-project-governance.mjs
```
surface + P02 原语 + governance 全过。

- [ ] **Step 4: 重跑 task-acceptance-runner + capture + README + release-verdict**（controller，让 MODEL-008/012/013/014 BLOCKED→DONE）：
```bash
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/task-acceptance-runner.mjs  # P01-T008/P02 GREEN exit 0
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/capture-project-evidence.mjs --write  # classify MODEL-008 等 BLOCKED→DONE
/opt/homebrew/Cellar/node/26.7.0/bin/node --input-type=module -e "/* README rebind lastIndexOf */"
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Release/release-verdict.mjs --write
/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Docs/check-project-governance.mjs
```
台账 done 数增（+MODEL-008/012/013/014）；probe MODEL_RETAINED_MEMBERS_STUBBED 消失；verdict rebound 任务数减 4。

- [ ] **Step 5: Commit** — `git add Sources/MonaCode/Model/ README.md artifacts/progress artifacts/releases && git commit -m "verify(MODEL-008): rebind — MODEL_RETAINED_MEMBERS_STUBBED resolved"`

---

## Self-Review

**1. Spec coverage:** spec §4.1 4 属性=Task1 ✓；§4.2 搜索委托=Task2 ✓ 单词=Task3 ✓ 装饰=Task4 ✓ undo=Task5 ✓；§4.3 删 stub=Task6 ✓；§4.4 行为测试=Task2-5 各 Step1 ✓；§4.5 验收=Task6 ✓。

**2. Placeholder scan:** 代码骨架用「读 X API 确认参数/字段」——这是 A 的本质（接线，subagent 读原语 API），非 placeholder（方向 + 委托目标 + 适配点明确）。MonaRange init（startOffset/endOffset vs offset/length）、MonaSearchMatch 字段、MonaModelSearchScope case、MonaUndoRedoReplayOutcome 结构——subagent 读源确认。这些不是 TBD（类型已存在，subagent 读即知）。

**3. Type consistency:** findMatches→[MonaFindMatch]（range:MonaRange）；MonaSearchMatch→MonaFindMatch via MonaRange；canUndo→Bool 委托 stack.isEmpty。consistent。

**4. 小扩（原语侧加方法）:** Task4 MonaDecorationCollection.apply / Task5 MonaUndoRedoStack.isEmpty——若缺则加，属 A 范围（组合现有方法，不重写原语逻辑）。spec §4.2/§6 已声明。
