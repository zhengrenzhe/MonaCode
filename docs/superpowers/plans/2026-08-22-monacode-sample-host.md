# MonaCode sample host 实现计划（子项目 D）

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** sample main.swift 加 4 diff 类型，消除 SAMPLE_HOST_DIFF_ACTIVATION_ABSENT + 4 swift fail（testSampleHostActivatesThreeProducts）。

**Spec:** `docs/superpowers/specs/2026-08-22-monacode-sample-host-design.md`

## Global Constraints
- 不动 g6-r；sample 是 non-product target（加 diff 类型不增 production deps）。
- commit EDITOR-002/P07-T009。
- Ruling I exit-only——testSampleHostActivatesThreeProducts 4 assertion 是行为测试。
- Ruling O：main commit，不开分支。

## Task 1: sample 加 4 diff 类型
**Files:** Modify `Sources/MonaCodeSample/main.swift`
- 读 probe SAMPLE_HOST_DIFF_ACTIVATION_ABSENT（4 类型字符串检查）+ B diff factory（createDiffEditor/createMultiFileDiffEditor 返 view）+ SwiftUI wrapper init（MonaDiffEditor/MonaMultiDiffEditor）。
- main.swift 加 4 construct：MonaDiffEditorView / MonaMultiDiffEditorView / MonaDiffEditor / MonaMultiDiffEditor。
- testSampleHostActivatesThreeProducts 4 assertion 过（4 swift fail 消除）。
- probe SAMPLE_HOST_DIFF_ACTIVATION_ABSENT 消失。
- commit EDITOR-002。

## Task 2: evidence rebind（controller）
- validateKnownSwiftFailure 4→0 fail（swift 0 fail, status accepted-known-product-failure→passed）+ ProjectGovernanceTests fixture 4→0。
- runner + capture + README + release-verdict。
- governance + commit + push。

## Self-Review
1. Spec coverage: §4 sample 加 4 类型=Task1 ✓ §5 验收=Task2 ✓。
2. Placeholder: construct 对照 B diff factory + SwiftUI init（subagent 读源确认）。
