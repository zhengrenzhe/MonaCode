# MonaCode 服务与工厂接线设计（子项目 B）

> 本文件是设计文档（design spec），属证据/历史，**非当前进展权威**。当前进展权威为 [README 任务台账](../../../README.md#tasks)。

## 1. 背景与动机

product-integration-probe 报 5 个服务/工厂缺口（taskIDs P01-T012, P05-T001, P05-T012, P05-T112, P05-T122, P07-T009, P07-T010 等）：
- `MARKER_SERVICE_ABSENT` — 无 MonaMarkerService class（marker 存取）
- `GLOBAL_MODEL_REGISTRY_ABSENT` — 无 MonaGlobalModelRegistry class（URI→model）
- `DIFF_FACTORY_NOT_WIRED` — createDiffEditor/createMultiFileDiffEditor 抛 phase07NotWired（未接 view）
- `FEATURE_ACTIVATION_PATH_ABSENT` — editor attach 未装 MonaFeatureRegistry/MonaContributionRegistry
- `INSTANCE_SURFACE_UNCONFORMED` — concrete code/diff instance type 未 conform MonaInstanceICodeEditor/MonaInstanceIDiffEditor

B 不像 A（原语已实现，接线）——B 要 **2 新实现**（marker service, global registry）+ **3 接线**（diff factory 接 view, feature registry 安装, instance conformance）。

## 2. 范围

**在范围内**：
1. MonaMarkerService（新 class: set/get/remove markers + onDidChangeMarkers, probe MARKER_SERVICE_ABSENT 消除）。
2. MonaGlobalModelRegistry（新 class: model(for:uri:)/models()/setLanguage + 4 public functions impl, probe GLOBAL_MODEL_REGISTRY_ABSENT 消除）。
3. diff factory 接线（createDiffEditor→MonaDiffEditorView, createMultiFileDiffEditor→MonaMultiDiffEditorView, 不 throw phase07NotWired, probe DIFF_FACTORY_NOT_WIRED 消除）。
4. feature activation（editorView attach 装 MonaFeatureRegistry( + MonaContributionRegistry( + installFeatures + installContributions, probe FEATURE_ACTIVATION_PATH_ABSENT 消除）。
5. instance conformance（concrete code/diff instance type conform MonaInstanceICodeEditor/MonaInstanceIDiffEditor, probe INSTANCE_SURFACE_UNCONFORMED 消除）。
6. 行为测试（防 Ruling I exit-only 放过）+ probe 验证 + evidence rebind。

**不在范围内**：子项目 C（API payload）/ D（sample host）/ A（已完成）。

## 3. 数据来源（probe 检查 + monaco 对照）

probe 检查（product-integration-probe.mjs）：
- MARKER_SERVICE_ABSENT（250-276）: `final class MonaMarkerService` + onDidChangeMarkers/setModelMarkers/getModelMarkers/removeAllMarkers + 4 public functions（monaEditorSetModelMarkers/RemoveAllMarkers/GetModelMarkers/OnDidChangeMarkers）functionHasImplementation。
- GLOBAL_MODEL_REGISTRY_ABSENT（278-303）: `final class MonaGlobalModelRegistry` + model(for:uri:)/func models()/setLanguage + 4 public functions（monaEditorCreateModel/SetModelLanguage/GetModel/GetModels）impl。
- DIFF_FACTORY_NOT_WIRED（218-232）: diffFactory 不含 `throw MonaEditorFactoryError.phase07NotWired` + 含 `return MonaDiffEditorView(` + `return MonaMultiDiffEditorView(`。
- FEATURE_ACTIVATION_PATH_ABSENT（359-374）: editorView 含 `MonaFeatureRegistry(` + `MonaContributionRegistry(` + `installFeatures` + `installContributions`。
- INSTANCE_SURFACE_UNCONFORMED（200-216）: instances（instances/editorView/diffView/multiDiffView 拼接）concreteConformance MonaInstanceI(?:Standalone)?CodeEditor + MonaInstanceI(?:Standalone)?DiffEditor。

monaco 对照（.d.ts）: createModel/getModel/getModels/setModelLanguage（1032-1074, global registry）, createDiffEditor/createMultiFileDiffEditor（980/982, diff factory）。marker service（IMarkerService 不在 editor.api.d.ts，按 probe 检查 + monaco setModelMarkers/getModelMarkers 等）。

## 4. 核心设计

### 4.1 MonaMarkerService（新）
`Sources/MonaCode/Services/MonaMarkerService.swift`（或 StandaloneServices）:
```swift
public final class MonaMarkerService {
    private var modelMarkers: [MonaURI: [MonaMarker]] = [:]  // 或 by model id
    private let emitter = MonaEmitter<MonaMarkerChangeEvent>()
    public var onDidChangeMarkers: MonaEvent<MonaMarkerChangeEvent> { emitter.event }
    public func setModelMarkers(...) { /* update + emit */ }
    public func getModelMarkers(...) -> [MonaMarker] { /* read */ }
    public func removeAllMarkers(...) { /* clear + emit */ }
}
```
4 public functions（monaEditorSetModelMarkers etc）route through this service（Sources/MonaCode/Generated/MonaPublicAPI.swift）。

### 4.2 MonaGlobalModelRegistry（新）
`Sources/MonaCode/Runtime/MonaGlobalModelRegistry.swift`（或 Services）:
```swift
public final class MonaGlobalModelRegistry {
    private var models: [MonaURI: MonaCodeModel] = [:]
    public func model(for uri: MonaURI) -> MonaCodeModel? { models[uri] }
    public func models() -> [MonaCodeModel] { Array(models.values) }
    public func setLanguage(...) { /* delegate model.setLanguage */ }
    // register on createModel, unregister on dispose
}
```
4 public functions（monaEditorCreateModel/GetModel/GetModels/SetModelLanguage）route through this.

### 4.3 diff factory 接线
`Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift`: createDiffEditor/createMultiFileDiffEditor 不 throw phase07NotWired，返 `MonaDiffEditorView(` / `MonaMultiDiffEditorView(`（construct + attach）。

### 4.4 feature activation
`Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift` performAttach（或 init）: `let features = MonaFeatureRegistry(...)` + `let contributions = MonaContributionRegistry(...)` + `installFeatures(features)` + `installContributions(contributions)`。

### 4.5 instance conformance
concrete code/diff instance type（MonaEditorInstanceAdapters / MonaCodeEditorView / MonaDiffEditorView）conform MonaInstanceICodeEditor/MonaInstanceIDiffEditor（add conformance + implement protocol methods, 或 adapter）。

## 5. 验收
- probe 5 findings 消失（MARKER_SERVICE/GLOBAL_MODEL_REGISTRY/DIFF_FACTORY/FEATURE_ACTIVATION/INSTANCE_SURFACE）。
- 涉及 task（P01-T012/P05-T001/T012/T112/T122/P07-T009/T010）acceptancePassed + 无 finding → DONE。
- 全套 .mjs + swift（4 sampleHost known）过。
- evidence rebind（台账 done 增, blocked 减, verdict rebound 减）。

## 6. 治理合规 + 风险
- commit 绑对应 task ID（MARKER_SERVICE→MODEL/P05-T122? GLOBAL_REGISTRY→MODEL/P01-T012? DIFF_FACTORY→P05-T112? FEATURE→P05-T100? INSTANCE→P05-T012?）。
- 不动 g6-r；marker/global 新实现对照 monaco + probe 检查（非重写原语——这些原语缺失, 是新）。
- 风险：marker/global 新实现数据结构设计（marker/model registry 存取）；diff factory 接 view 需 view 构造 + attach；feature registry 构造参数；instance conformance protocol 方法多。subagent 读 monaco + probe + 现状实现。
