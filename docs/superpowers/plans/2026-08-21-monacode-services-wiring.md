# MonaCode 服务与工厂接线实现计划（子项目 B）

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`).

**Goal:** 实现 marker service + global model registry（2 新 class）+ diff factory/feature/instance 接线（3），消除 probe 5 findings，相关 task BLOCKED→DONE。

**Architecture:** 2 新实现（MonaMarkerService, MonaGlobalModelRegistry，对照 monaco + probe）+ 3 接线（diff factory 接 view, feature registry install, instance conformance）。subagent 读 monaco .d.ts + probe 检查 + 现状实现。

**Tech Stack:** Swift 6, XCTest, xcrun, Node。

**Spec:** `docs/superpowers/specs/2026-08-21-monacode-services-wiring-design.md`

## Global Constraints
- 不动 g6-r；marker/global 是**新实现**（缺失, 非重写原语）；diff/feature/instance 是接线。
- commit 绑对应 task ID（MARKER_SERVICE→MODEL/P05-T122 等；具体见各 task）。
- Ruling I exit-only——每 task 行为测试防放过。
- probe 检查（product-integration-probe.mjs）是各缺口消除判据——subagent 读 probe 确认 class + 方法 + 检查模式。
- subagent 读 monaco .d.ts（createModel/getModel/getModels/setModelLanguage/createDiffEditor）+ probe 检查 + 现状 Sources。

## File Structure
| 文件 | 职责 | 动作 |
|---|---|---|
| `Sources/MonaCode/Services/MonaMarkerService.swift` | marker 存取 class | Create |
| `Sources/MonaCode/Runtime/MonaGlobalModelRegistry.swift` | URI→model class | Create |
| `Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift` | diff factory 接 view | Modify |
| `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift` | feature registry install | Modify |
| `Sources/MonaCodeAppKit/Views/MonaEditorInstanceAdapters.swift` | instance conformance | Modify |
| `Sources/MonaCode/Generated/MonaPublicAPI.swift` | 4+4 public functions route | Modify |

---

### Task 1: MonaMarkerService（新 class）

**Files:** Create `Sources/MonaCode/Services/MonaMarkerService.swift`；Modify `MonaPublicAPI.swift`（4 functions route）

**Interfaces:** probe MARKER_SERVICE_ABSENT（250-276）: `final class MonaMarkerService` + onDidChangeMarkers/setModelMarkers/getModelMarkers/removeAllMarkers + monaEditorSetModelMarkers/RemoveAllMarkers/GetModelMarkers/OnDidChangeMarkers functionHasImplementation。

- [ ] Step 1: 读 probe MARKER_SERVICE_ABSENT 检查（grep product-integration-probe.mjs MARKER_SERVICE）+ MonaMarker type（Sources/MonaCode/Base/MonaMarker.swift）。
- [ ] Step 2: 写行为测试（marker set/get/remove + change event）。
- [ ] Step 3: 实现 MonaMarkerService（marker 存取 + emit change）+ 4 public functions route。
- [ ] Step 4: probe MARKER_SERVICE_ABSENT 消失 + 测试过 + commit（绑 MODEL/P05-T122）。

### Task 2: MonaGlobalModelRegistry（新 class）

**Files:** Create `Sources/MonaCode/Runtime/MonaGlobalModelRegistry.swift`；Modify `MonaPublicAPI.swift`（4 functions）

**Interfaces:** probe GLOBAL_MODEL_REGISTRY_ABSENT（278-303）: `final class MonaGlobalModelRegistry` + model(for:uri:)/models()/setLanguage + monaEditorCreateModel/SetModelLanguage/GetModel/GetModels impl。monaco createModel/getModel/getModels/setModelLanguage（.d.ts 1032-1074）。

- [ ] Step 1: 读 probe + monaco .d.ts（createModel/getModel/getModels/setModelLanguage）。
- [ ] Step 2: 行为测试（create model + get by uri + list + setLanguage）。
- [ ] Step 3: 实现 MonaGlobalModelRegistry（URI→model map + register/unregister）+ 4 public functions。
- [ ] Step 4: probe 消失 + 测试过 + commit（绑 MODEL/P01-T012）。

### Task 3: diff factory 接线

**Files:** Modify `Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift`

**Interfaces:** probe DIFF_FACTORY_NOT_WIRED（218-232）: 不含 `throw MonaEditorFactoryError.phase07NotWired` + 含 `return MonaDiffEditorView(` + `return MonaMultiDiffEditorView(`。

- [ ] Step 1: 读 probe + MonaDiffEditorView/MonaMultiDiffEditorView 构造（Sources/MonaCodeAppKit/Views/）。
- [ ] Step 2: 行为测试（createDiffEditor 返 view 非 throw）。
- [ ] Step 3: createDiffEditor→`return MonaDiffEditorView(`, createMultiFileDiffEditor→`return MonaMultiDiffEditorView(`（删 throw phase07NotWired）。
- [ ] Step 4: probe 消失 + 测试过 + commit（绑 P05-T112）。

### Task 4: feature activation

**Files:** Modify `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`

**Interfaces:** probe FEATURE_ACTIVATION_PATH_ABSENT（359-374）: editorView 含 `MonaFeatureRegistry(` + `MonaContributionRegistry(` + `installFeatures` + `installContributions`。

- [ ] Step 1: 读 probe + MonaFeatureRegistry/MonaContributionRegistry 构造（Sources/MonaCodeAppKit/Features/）。
- [ ] Step 2: 行为测试（attach 后 registry installed）。
- [ ] Step 3: performAttach（或 init）加 `let features = MonaFeatureRegistry(...)` + `let contributions = MonaContributionRegistry(...)` + `installFeatures(features)` + `installContributions(contributions)`。
- [ ] Step 4: probe 消失 + 测试过 + commit（绑 P05-T100 等）。

### Task 5: instance conformance

**Files:** Modify `Sources/MonaCodeAppKit/Views/MonaEditorInstanceAdapters.swift`（+ MonaCodeEditorView/MonaDiffEditorView）

**Interfaces:** probe INSTANCE_SURFACE_UNCONFORMED（200-216）: instances concreteConformance MonaInstanceI(?:Standalone)?CodeEditor + MonaInstanceI(?:Standalone)?DiffEditor。

- [ ] Step 1: 读 probe + MonaInstanceICodeEditor/MonaInstanceIDiffEditor protocol（MonaEditorInstanceAdapters.swift:202/322）+ concrete type（MonaCodeEditorView/MonaDiffEditorView/adapter）。
- [ ] Step 2: 行为测试（concrete type conform + protocol methods）。
- [ ] Step 3: concrete code/diff instance type conform protocol（add conformance + implement methods, 或 adapter）。
- [ ] Step 4: probe 消失 + 测试过 + commit（绑 P05-T012）。

### Task 6: probe 验证 + evidence rebind（controller）

- [ ] Step 1: probe 5 findings 消失（MARKER/GLOBAL/DIFF/FEATURE/INSTANCE）。
- [ ] Step 2: 全套测试（swift 4 sampleHost known + .mjs）。
- [ ] Step 3: evidence rebind（runner + capture + README + release-verdict, 台账 done 增 blocked 减）。
- [ ] Step 4: commit + push（finishing）。

## Self-Review
1. Spec coverage: §4.1 marker=Task1 ✓ global=Task2 ✓ diff=Task3 ✓ feature=Task4 ✓ instance=Task5 ✓ §5 验收=Task6 ✓。
2. Placeholder: 代码方向用 probe 检查 + monaco 对照（subagent 读源确认签名），非 TBD。
3. Type consistency: marker/global class + 方法对照 probe；diff factory 返 view；feature registry 构造；instance conform protocol。
