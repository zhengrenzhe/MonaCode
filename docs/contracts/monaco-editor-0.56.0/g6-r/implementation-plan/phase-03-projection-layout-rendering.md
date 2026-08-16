<!-- G6-R-PHASE:03 -->

# Phase 03 — Projection, layout, and rendering

- Phase: `03`
- Title: Projection, layout, and rendering
- Document: `implementation-plan/phase-03-projection-layout-rendering.md`
- Dependencies: `02` 
- Tasks: 12

## Tasks

<!-- G6-R-TASK:P03-T001:bd3e63b5ca7a89165638ac6e6654f5cec665bf8954f37b6b032ac80a951e1158 -->

### P03-T001 — Build ViewGraph projection and logarithmic vertical indexes

- Record SHA-256: `bd3e63b5ca7a89165638ac6e6654f5cec665bf8954f37b6b032ac80a951e1158`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T009` 
- Test contract cases: 2
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T001`
- Evidence commit message: `evidence(monacode): complete P03-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Layout/MonaViewGraphDifferentialTests.swift`

### Stage `red`

- verification-command: `P03-T001.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Project model lines, folding, hidden ranges, injected text, wrapping, and view zones into immutable view-line identities.`
- implementation-operation: `Maintain prefix-height and line-mapping indexes without viewport-path full-document scans.`
- implementation-operation: `Publish a new projection generation only after every affected index is complete.`

### Stage `green`

- verification-command: `P03-T001.GREEN.001` (kind=all-success, network=forbidden, timeout=600000ms, leaves=2)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Layout/MonaViewGraph.swift
  - Sources/MonaCodeAppKit/Layout/MonaViewLine.swift
  - Sources/MonaCodeAppKit/Layout/MonaVerticalIndex.swift
  - Sources/MonaCodeAppKit/Layout/MonaViewZoneIndex.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Layout/MonaViewGraphDifferentialTests.swift
  - Tests/MonaCodeAppKitTests/Layout/MonaVerticalIndexComplexityTests.swift

<!-- G6-R-TASK:P03-T002:5987b701728541f228a68d5b7d78795cf79e3932696ec9b8561ce108d7bd2803 -->

### P03-T002 — Shape mixed-script lines with Core Text and deterministic fallback

- Record SHA-256: `5987b701728541f228a68d5b7d78795cf79e3932696ec9b8561ce108d7bd2803`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T001` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T002`
- Evidence commit message: `evidence(monacode): complete P03-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Layout/MonaTextShaperTests.swift`

### Stage `red`

- verification-command: `P03-T002.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Shape raw UTF-16 lines with explicit font descriptors, direction, scale, tab stops, and fallback order.`
- implementation-operation: `Preserve isolated-surrogate input positions even when no glyph is emitted.`
- implementation-operation: `Record every face and run for Q1-R4 font provenance.`
- implementation-operation: `Return a bounded typed failure instead of publishing partial runs.`

### Stage `green`

- verification-command: `P03-T002.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Layout/MonaTextShaper.swift
  - Sources/MonaCodeAppKit/Layout/MonaFontFallbackResolver.swift
  - Sources/MonaCodeAppKit/Layout/MonaGlyphRun.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Layout/MonaTextShaperTests.swift

<!-- G6-R-TASK:P03-T003:2f7aef1faf498751a733bbbf3c87b79bde032b518208594fc3f3fea97155e041 -->

### P03-T003 — Freeze shared immutable LineLayoutRecord geometry

- Record SHA-256: `2f7aef1faf498751a733bbbf3c87b79bde032b518208594fc3f3fea97155e041`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T002` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T003`
- Evidence commit message: `evidence(monacode): complete P03-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Layout/MonaLineLayoutRecordTests.swift`

### Stage `red`

- verification-command: `P03-T003.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Store glyph runs, advances, baselines, raw-unit boundaries, bidi levels, injected-text spans, decorations, and paint inputs in one immutable record.`
- implementation-operation: `Make hit testing and every renderer consume the same record without reshaping.`
- implementation-operation: `Key records by complete dependency stamps rather than viewport position alone.`

### Stage `green`

- verification-command: `P03-T003.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Layout/MonaLineLayoutRecord.swift
  - Sources/MonaCodeAppKit/Layout/MonaLineLayoutBuilder.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Layout/MonaLineLayoutRecordTests.swift

<!-- G6-R-TASK:P03-T004:8e30df2393c810310aff22ad8ed47a0923c095d8b392ca8ed11e36e44a38f18f -->

### P03-T004 — Define seven non-contradictory dependency stamp domains

- Record SHA-256: `8e30df2393c810310aff22ad8ed47a0923c095d8b392ca8ed11e36e44a38f18f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T003` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T004`
- Evidence commit message: `evidence(monacode): complete P03-T004`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T004.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Layout/MonaDependencyStampTests.swift`

### Stage `red`

- verification-command: `P03-T004.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Define ProjectionStamp, VerticalStamp, ScrollDimensionStamp, GeometryStamp, PaintStamp, SurfaceStamp, and FrameStamp as distinct immutable values.`
- implementation-operation: `Enumerate every mutation-to-domain edge from V1-R3 and V1-R4.`
- implementation-operation: `Reject both missing invalidations and invalidation fanout beyond the frozen edge set.`

### Stage `green`

- verification-command: `P03-T004.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Layout/MonaDependencyStamps.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Layout/MonaDependencyStampTests.swift

<!-- G6-R-TASK:P03-T005:5891b87c2d24293f0f95d10070aa7dda1c606e02f068a25272ff4983103669dd -->

### P03-T005 — Implement scroll truth and dimension convergence

- Record SHA-256: `5891b87c2d24293f0f95d10070aa7dda1c606e02f068a25272ff4983103669dd`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T001`, `P03-T004` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T005`
- Evidence commit message: `evidence(monacode): complete P03-T005`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T005.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Layout/MonaScrollModelTests.swift`

### Stage `red`

- verification-command: `P03-T005.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Separate requested, validated, and published scroll positions.`
- implementation-operation: `Converge content dimensions, viewport dimensions, and clamping in the frozen event order.`
- implementation-operation: `Preserve subpixel values until the final surface transform.`

### Stage `green`

- verification-command: `P03-T005.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Layout/MonaScrollModel.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Layout/MonaScrollModelTests.swift

<!-- G6-R-TASK:P03-T006:57c7d2361a8e021f17a28d22814457c44a8815fbcdb829ab894766fb204e57c3 -->

### P03-T006 — Complete the correct Core Graphics tiled renderer

- Record SHA-256: `57c7d2361a8e021f17a28d22814457c44a8815fbcdb829ab894766fb204e57c3`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T003`, `P03-T004`, `P03-T005` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T006`
- Evidence commit message: `evidence(monacode): complete P03-T006`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T006.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Rendering/MonaCoreGraphicsRendererTests.swift`

### Stage `red`

- verification-command: `P03-T006.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Paint only complete immutable layout records into generation-keyed tiles.`
- implementation-operation: `Composite text, selections, cursors, decorations, widgets, gutters, minimap inputs, and overlays in frozen z-order.`
- implementation-operation: `Use linear premultiplied RGBA and preserve scale plus subpixel phase in cache keys.`
- implementation-operation: `Bound tile memory and evict without losing current-generation truth.`

### Stage `green`

- verification-command: `P03-T006.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift
  - Sources/MonaCodeAppKit/Rendering/MonaRenderTileCache.swift
  - Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Rendering/MonaCoreGraphicsRendererTests.swift

<!-- G6-R-TASK:P03-T007:e88c25010923d467f787c7af7bfd0321f9bad9ffe541de5eb4114aa020641403 -->

### P03-T007 — Enforce the QueryGeometryBarrier for hit testing and native queries

- Record SHA-256: `e88c25010923d467f787c7af7bfd0321f9bad9ffe541de5eb4114aa020641403`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T005`, `P03-T006` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T007`
- Evidence commit message: `evidence(monacode): complete P03-T007`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T007.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Layout/MonaQueryGeometryBarrierTests.swift`

### Stage `red`

- verification-command: `P03-T007.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Answer point, range, caret, selection, composition, and accessibility geometry only from one complete generation.`
- implementation-operation: `Synchronously finish bounded visible-line work when the contract requires an immediate query.`
- implementation-operation: `Return typed unavailable geometry when bounded completion fails.`

### Stage `green`

- verification-command: `P03-T007.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Layout/MonaQueryGeometryBarrier.swift
  - Sources/MonaCodeAppKit/Layout/MonaHitTester.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Layout/MonaQueryGeometryBarrierTests.swift

<!-- G6-R-TASK:P03-T008:c135857ea0ceb73810864d0d8f688df16b0555f0ee44b1b07b978cce371ad8e0 -->

### P03-T008 — Represent bounded Core Text failure with FailedLineRecord

- Record SHA-256: `c135857ea0ceb73810864d0d8f688df16b0555f0ee44b1b07b978cce371ad8e0`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T002`, `P03-T007` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T008`
- Evidence commit message: `evidence(monacode): complete P03-T008`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T008.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Layout/MonaFailedLineRecordTests.swift`

### Stage `red`

- verification-command: `P03-T008.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Convert bounded shaping and line-construction failures into immutable failed-line records.`
- implementation-operation: `Retain raw range, dependency stamps, typed reason, retry generation, and safe fallback height.`
- implementation-operation: `Prevent hit testing, selection geometry, or renderer code from consuming partial glyph data.`

### Stage `green`

- verification-command: `P03-T008.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Layout/MonaFailedLineRecord.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Layout/MonaFailedLineRecordTests.swift

<!-- G6-R-TASK:P03-T009:e770191c6aa71cb1dea5d8e333fbb0c71c39d9a8dfd98dcb43ad1b6542eb0934 -->

### P03-T009 — Instrument renderer-owned correctness and performance metrics

- Record SHA-256: `e770191c6aa71cb1dea5d8e333fbb0c71c39d9a8dfd98dcb43ad1b6542eb0934`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T006`, `P03-T007`, `P03-T008` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T009`
- Evidence commit message: `evidence(monacode): complete P03-T009`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T009.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Rendering/MonaRendererMetricsTests.swift`

### Stage `red`

- verification-command: `P03-T009.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Measure layout-ready-to-present, GPU frame time when present, renderer-surface footprint, missed presentation, and renderer energy.`
- implementation-operation: `Exclude model load, RegExp, diff, provider, LSP, and whole-application resource costs from renderer trigger metrics.`
- implementation-operation: `Emit balanced block identifiers and unrounded binary64 samples for Q1-R3.`

### Stage `green`

- verification-command: `P03-T009.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Rendering/MonaRendererMetrics.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Rendering/MonaRendererMetricsTests.swift

<!-- G6-R-TASK:P03-T010:5c6372f2dfda3b8c02cc62d01ae01fb5d96fe203460e5a841d74e8c3d6f92348 -->

### P03-T010 — Resolve the renderer decision from complete Core Graphics evidence

- Record SHA-256: `5c6372f2dfda3b8c02cc62d01ae01fb5d96fe203460e5a841d74e8c3d6f92348`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T009` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T010`
- Evidence commit message: `evidence(monacode): complete P03-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Rendering/MonaRendererDecisionGateTests.swift`

### Stage `red`

- verification-command: `P03-T010.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run all renderer-owned C03/C08 correctness cells and paired M0/M1 performance cells after Core Graphics completion.`
- implementation-operation: `Record exactly one immutable decision: not-triggered-and-absent or triggered-and-required.`
- implementation-operation: `Reject first-present, input-to-present, whole-application footprint, and other cross-domain metrics as direct triggers.`

### Stage `green`

- verification-command: `P03-T010.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - _(none)_
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Rendering/MonaRendererDecisionGateTests.swift

<!-- G6-R-TASK:P03-T011:a38eab62a090c2d56fd6572050ed7dbd4218ab91788d8ba5cbdcdd8495070fcc -->

### P03-T011 — Execute the conditional Metal branch entirely inside Phase 03

- Record SHA-256: `a38eab62a090c2d56fd6572050ed7dbd4218ab91788d8ba5cbdcdd8495070fcc`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T010` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T011`
- Evidence commit message: `evidence(monacode): complete P03-T011`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T011.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Rendering/MonaMetalRendererParityTests.swift`

### Stage `red`

- verification-command: `P03-T011.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `When the decision is not-triggered-and-absent, record source absence and execute no product-source change.`
- implementation-operation: `When the decision is triggered-and-required, implement rendering from the shared layout record and linear premultiplied RGBA inputs.`
- implementation-operation: `Require per-channel absolute difference at most 1/255 against Core Graphics.`
- implementation-operation: `Fall back to the next complete Core Graphics generation on device, resource, or presentation failure.`

### Stage `green`

- verification-command: `P03-T011.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Rendering/MonaMetalRendererParityTests.swift

<!-- G6-R-TASK:P03-T012:2cef26cb99856f5f7bcc094487ddc0528c5fca919e9a5f15654163738f99ee69 -->

### P03-T012 — Close projection, geometry, and renderer parity before native input

- Record SHA-256: `2cef26cb99856f5f7bcc094487ddc0528c5fca919e9a5f15654163738f99ee69`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T011` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P03-T012`
- Evidence commit message: `evidence(monacode): complete P03-T012`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-03/P03-T012.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Phase03RendererConformanceTests.swift`

### Stage `red`

- verification-command: `P03-T012.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run projection, geometry, scroll, shaping, failure, Core Graphics, and selected renderer-branch matrices as one revision-locked suite.`
- implementation-operation: `Prove viewport operation counts scale with visible rows plus changed dependencies.`
- implementation-operation: `Freeze the renderer source set and branch evidence consumed by Phase 08 candidate generation.`

### Stage `green`

- verification-command: `P03-T012.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - _(none)_
- modify:
  - _(none)_
- test:
  - Tests/ConformanceAndFailureInjection/Phase03RendererConformanceTests.swift
