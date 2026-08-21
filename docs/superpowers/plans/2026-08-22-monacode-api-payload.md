# MonaCode 公共 API payload 填充实现计划（子项目 C）

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** 填 3 缺口 protocol 成员（cursor/widget/language）+ MonaWidgetMouseTargetController，消除 probe 3 findings，相关 task BLOCKED→DONE。

**Architecture:** 填 protocol 成员（从空壳 `{}` 到有 payload），对照 monaco .d.ts + probe RESOLVED_SOURCES fixture。比 B 轻（填成员，非新 class/接线）。

**Spec:** `docs/superpowers/specs/2026-08-22-monacode-api-payload-design.md`

## Global Constraints
- 不动 g6-r；填 protocol 成员对照 monaco .d.ts + probe RESOLVED（Generated 文件 MonaPublicAPI.swift + MonaAppKitPublicAPI.swift，frozen P07-T011 不被覆盖）。
- commit 绑对应 task ID（CURSOR→INPUT-007, WIDGET→RENDER-007, LANGUAGE→LANG-001）。
- Ruling I exit-only——行为测试防放过。
- subagent 读 probe RESOLVED_SOURCES fixture（ProductIntegrationProbeTests.mjs）确认各 protocol 成员名 + 类型 + probe 检查模式。

## Tasks

### Task 1: CURSOR payload（2 protocol）
**Files:** Modify `Sources/MonaCode/Generated/MonaPublicAPI.swift`（MonaEditorICursorPositionChangedEvent/MonaEditorICursorSelectionChangedEvent）
- 读 probe RESOLVED fixture（`var position`/`var selection`）+ monaco .d.ts ICursorPositionChangedEvent/ICursorSelectionChangedEvent。
- 填 `var position: MonaPosition { get }` + `var secondaryPositions: [MonaPosition]? { get }`；`var selection: MonaSelection { get }`。
- 行为测试（concrete event 携带 position/selection）+ probe CURSOR_EVENT_PAYLOADS_EMPTY 消失。

### Task 2: WIDGET payload（5 protocol + controller）
**Files:** Modify `Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift`（5 widget protocol）+ `Sources/MonaCodeAppKit/Accessibility/MonaAXWidgetProxy.swift`（MonaWidgetMouseTargetController）
- 读 probe RESOLVED fixture（`var afterLineNumber`/`var id`/`var type`）+ monaco .d.ts。
- 填 MonaEditorIViewZone/IContentWidget/IOverlayWidget/IGlyphMarginWidget/IBaseMouseTarget 成员 + `final class MonaWidgetMouseTargetController` + `getTargetAtClientPoint(_:)`。
- 行为测试 + probe WIDGET_MOUSE_TARGET_SURFACE_EMPTY 消失。

### Task 3: LANGUAGE payload（9 protocol）
**Files:** Modify `Sources/MonaCode/Generated/MonaPublicAPI.swift`（9 MonaLanguages* protocol）
- 读 probe RESOLVED fixture（`var trigger`/`var value`/`var verbosity`/`var triggerKind`/`var maxRanges`/`var includeDeclaration`）+ monaco .d.ts。
- 填 9 protocol 成员（CodeActionContext/ProviderResult/HoverContext/CompletionContext/InlineCompletionContext/SignatureHelpResult/SignatureHelpContext/ReferenceContext/FoldingContext）。
- 行为测试 + probe LANGUAGE_CONTEXT_TYPES_EMPTY 消失。

### Task 4: probe 验证 + evidence rebind（controller）
- probe 3 findings 消失。
- validateKnownSwiftFailure test count 更新（C 加 test）。
- runner + capture + README + release-verdict。
- governance + commit + push。

## Self-Review
1. Spec coverage: §4.1 cursor=Task1 ✓ widget=Task2 ✓ language=Task3 ✓ §5 验收=Task4 ✓。
2. Placeholder: 成员名/类型用 probe RESOLVED fixture + monaco .d.ts（subagent 读源确认），非 TBD。
3. Type consistency: protocol 成员对照 monaco + probe RESOLVED。
