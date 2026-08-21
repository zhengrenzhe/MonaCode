# MonaCode 公共 API payload 填充设计（子项目 C）

> 本文件是设计文档，非当前进展权威。当前进展权威为 [README 任务台账](../../../README.md#tasks)。

## 1. 背景与动机
probe 报 3 个 API payload 空壳缺口：
- `CURSOR_EVENT_PAYLOADS_EMPTY`（P04-T007/P05-T012）— MonaEditorICursorPositionChangedEvent/MonaEditorICursorSelectionChangedEvent 零成员。
- `WIDGET_MOUSE_TARGET_SURFACE_EMPTY`（P03-T007/P05-T104…）— MonaEditorIViewZone/IContentWidget/IOverlayWidget/IGlyphMarginWidget/IBaseMouseTarget 零成员 + 无 MonaWidgetMouseTargetController。
- `LANGUAGE_CONTEXT_TYPES_EMPTY`（P05-T001/P05-T013/P06-T005）— MonaLanguages*Context/Result 9 个 protocol 零成员。

C 是填 protocol 成员（从空壳到有 payload），对照 monaco .d.ts protocol 成员 + probe RESOLVED_SOURCES fixture。比 B 轻（填成员，非新 class/接线）。

## 2. 范围
**在范围内**：3 缺口 protocol 填成员 + MonaWidgetMouseTargetController + 行为测试 + probe 验证 + evidence rebind。
**不在范围**：D（sample host）/ A/B（已完成）。

## 3. 数据来源
probe 检查（product-integration-probe.mjs）：
- CURSOR（313）: MonaEditorICursorPositionChangedEvent/MonaEditorICursorSelectionChangedEvent `declarationHasMembers`（非 `{}`）+ 无零成员 shell。
- WIDGET（337）: MonaEditorIViewZone/IContentWidget/IOverlayWidget/IGlyphMarginWidget/IBaseMouseTarget `declarationHasMembers` + `final class MonaWidgetMouseTargetController` + `getTargetAtClientPoint`。
- LANGUAGE（351）: 9 个 MonaLanguages* protocol `declarationHasMembers`。

probe RESOLVED_SOURCES fixture（ProductIntegrationProbeTests.mjs）对照各 protocol 成员（如 `var position`/`var selection`/`var afterLineNumber`/`var id`/`var type`/`var trigger`/`var value`/`var verbosity`/`var triggerKind`/`var maxRanges`/`var includeDeclaration`）。

protocol 在 Generated 文件（MonaPublicAPI.swift + MonaAppKitPublicAPI.swift）——probe 读这些。

## 4. 核心设计
### 4.1 CURSOR payload
`MonaPublicAPI.swift`:
- MonaEditorICursorPositionChangedEvent: `var position: MonaPosition { get }` + `var secondaryPositions: [MonaPosition]? { get }`（monaco ICursorPositionChangedEvent）。
- MonaEditorICursorSelectionChangedEvent: `var selection: MonaSelection { get }`（monaco ICursorSelectionChangedEvent）。

### 4.2 WIDGET payload
`MonaAppKitPublicAPI.swift`:
- MonaEditorIViewZone: `var afterLineNumber: Int { get }` + `var heightInPx: Double { get }`。
- MonaEditorIContentWidget: `var id: String { get }` + `var position: MonaEditorIContentWidgetPosition? { get }`。
- MonaEditorIOverlayWidget: `var id: String { get }`。
- MonaEditorIGlyphMarginWidget: `var id: String { get }`。
- MonaEditorIBaseMouseTarget: `var type: Int { get }` + `var position: MonaPosition? { get }`。
- `MonaWidgetMouseTargetController`（class）+ `getTargetAtClientPoint(_:)` → MonaEditorIBaseMouseTarget?。

### 4.3 LANGUAGE payload
`MonaPublicAPI.swift` 9 个 protocol 填 monaco 对照成员（CodeActionContext trigger, ProviderResult value, HoverContext verbosity, CompletionContext triggerKind, InlineCompletionContext triggerKind, SignatureHelpResult value, SignatureHelpContext triggerKind, ReferenceContext includeDeclaration, FoldingContext maxRanges）。

## 5. 验收
- probe 3 findings 消失（CURSOR/WIDGET/LANGUAGE）。
- 涉及 task acceptancePassed + 无 finding → DONE。
- 全套 .mjs + swift（4 sampleHost known）过。
- evidence rebind。

## 6. 治理 + 风险
- commit 绑对应 task ID（CURSOR→INPUT/P04-T007, WIDGET→RENDER/P03-T007, LANGUAGE→LANG/P05-T001）。
- 不动 g6-r；填 protocol 成员对照 monaco .d.ts + probe RESOLVED。
- 风险：protocol 成员类型（对照 monaco .d.ts）；Generated 文件改（probe 读, 不被覆盖——frozen at P07-T011）。
