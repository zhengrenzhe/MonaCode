# MonaCode sample host 设计（子项目 D）

> 非当前进展权威。

## 1. 背景
probe SAMPLE_HOST_DIFF_ACTIVATION_ABSENT（P07-T009/T010）：sample main.swift 没激活 4 diff 类型（MonaDiffEditorView/MonaMultiDiffEditorView/MonaDiffEditor/MonaMultiDiffEditor）。这是 4 swift fail（testSampleHostActivatesThreeProducts 4 assertion）的根因。B diff factory 已完成（createDiffEditor/createMultiFileDiffEditor 返 view）。

## 2. 范围
**在范围内**：sample main.swift 加 4 diff 类型 construct + probe 验证 + validateKnownSwiftFailure 4→0 fail（swift 0 fail）+ evidence rebind。
**不在范围**：8 TODO（acceptancePassed=false 无 finding，非 D scope，后续查）。

## 3. 数据
probe PATHS.sample = `Sources/MonaCodeSample/main.swift`。检查 4 类型字符串。B diff factory createDiffEditor/createMultiFileDiffEditor 返 MonaDiffEditorView/MonaMultiDiffEditorView。SwiftUI wrapper MonaDiffEditor/MonaMultiDiffEditor。

## 4. 设计
main.swift 加 4 construct（对照 B diff factory + SwiftUI wrapper init）：
- `MonaDiffEditorView()` 或 `MonaEditorFactory.createDiffEditor(...)` 
- `MonaMultiDiffEditorView()` 或 factory
- `MonaDiffEditor(model: ...)` SwiftUI wrapper
- `MonaMultiDiffEditor(models: ...)` SwiftUI wrapper

## 5. 验收
- probe SAMPLE_HOST_DIFF_ACTIVATION_ABSENT 消失。
- testSampleHostActivatesThreeProducts 4 assertion pass（swift 0 fail sampleHost）。
- validateKnownSwiftFailure 改（4→0 fail, swift-tests status accepted-known-product-failure→passed）。
- evidence rebind（台账 done 增, blocked 减, verdict rebound 减）。

## 6. 治理 + 风险
commit EDITOR-002/P07-T009；不动 g6-r；sample 是 non-product target。validateKnownSwiftFailure/fixture 4→0 是 D evidence rebind（swift 0 fail 后 capture validateCommand 要改）。
