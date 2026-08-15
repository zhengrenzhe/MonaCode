# Phase 03: Projection, layout, and rendering

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 02.

Task count: 12.

<!-- monacode-plan-task:{"id":"P03-T001","recordSha256":"ccf22e868700f3f61947e5dd54926c0f065c9832787d3c4361c5565b9b5bb948"} -->
## P03-T001 — Build ViewGraph projection and logarithmic vertical indexes

Contract: `V1-R3.projection`, `V1-R3.verticalIndex`, `C03`, `P04`, `P06`

Dependencies:
- `P02-T009`

Ownership selectors:
- `layout:view-graph`
- `layout:vertical-indexes`

Files to create:
- `Sources/MonaCodeAppKit/Layout/MonaViewGraph.swift`
- `Sources/MonaCodeAppKit/Layout/MonaViewLine.swift`
- `Sources/MonaCodeAppKit/Layout/MonaVerticalIndex.swift`
- `Sources/MonaCodeAppKit/Layout/MonaViewZoneIndex.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Layout/MonaViewGraphDifferentialTests.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaVerticalIndexComplexityTests.swift`

Interfaces consumed:
- `MonaCodeModel`
- `MonaDecorationTree`
- `MonaAsyncValidityTicket`

Interfaces produced:
- `MonaViewGraph`
- `MonaVerticalIndex`
- `MonaViewZoneIndex`

Red verification:
- Run: `swift test --filter MonaViewGraphDifferentialTests/testFoldInjectedWrapProjection`
  - Expected exit: `1`
  - Expected output includes: `PROJECTION_DIFFERENTIAL_MISMATCH fixture=fold-injected-wrap`

Minimal implementation operations:
- `Project model lines, folding, hidden ranges, injected text, wrapping, and view zones into immutable view-line identities.`
- `Maintain prefix-height and line-mapping indexes without viewport-path full-document scans.`
- `Publish a new projection generation only after every affected index is complete.`

Green verification:
- Run: `swift test --filter MonaViewGraphDifferentialTests && swift test --filter MonaVerticalIndexComplexityTests`
  - Expected exit: `0`
  - Expected output includes: `VIEW_GRAPH_PARITY mappings=exact complexity=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T001.json`

Completion assertions:
- `Projection mappings match comparator fixtures.`
- `Vertical queries retain logarithmic growth.`
- `Incomplete generations are never visible.`

Commit boundary:
- `Sources/MonaCodeAppKit/Layout/MonaViewGraph.swift`
- `Sources/MonaCodeAppKit/Layout/MonaViewLine.swift`
- `Sources/MonaCodeAppKit/Layout/MonaVerticalIndex.swift`
- `Sources/MonaCodeAppKit/Layout/MonaViewZoneIndex.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaViewGraphDifferentialTests.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaVerticalIndexComplexityTests.swift`

<!-- monacode-plan-task:{"id":"P03-T002","recordSha256":"9491fca6cff70db7b58d939a78d0044d1f6921eb923103c284fd563e8c1fa396"} -->
## P03-T002 — Shape mixed-script lines with Core Text and deterministic fallback

Contract: `V1-R3.shaping`, `V1-R4.crossEngineGeometry`, `C03`, `C08`

Dependencies:
- `P03-T001`

Ownership selectors:
- `layout:core-text-shaping`
- `layout:font-fallback`

Files to create:
- `Sources/MonaCodeAppKit/Layout/MonaTextShaper.swift`
- `Sources/MonaCodeAppKit/Layout/MonaFontFallbackResolver.swift`
- `Sources/MonaCodeAppKit/Layout/MonaGlyphRun.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Layout/MonaTextShaperTests.swift`

Interfaces consumed:
- `MonaViewGraph`
- `FontProvenanceRecord`

Interfaces produced:
- `MonaTextShaper`
- `MonaGlyphRun`
- `MonaFontFallbackResolution`

Red verification:
- Run: `swift test --filter MonaTextShaperTests/testBidiFallbackColorGlyphMatrix`
  - Expected exit: `1`
  - Expected output includes: `SHAPING_GEOMETRY_MISMATCH fixture=bidi-fallback-color-glyph`

Minimal implementation operations:
- `Shape raw UTF-16 lines with explicit font descriptors, direction, scale, tab stops, and fallback order.`
- `Preserve isolated-surrogate input positions even when no glyph is emitted.`
- `Record every face and run for Q1-R4 font provenance.`
- `Return a bounded typed failure instead of publishing partial runs.`

Green verification:
- Run: `swift test --filter MonaTextShaperTests`
  - Expected exit: `0`
  - Expected output includes: `TEXT_SHAPING matrices=64 failedPartialRuns=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T002.json`

Completion assertions:
- `Mixed-script geometry passes fixed goldens.`
- `Fallback order is deterministic.`
- `Raw-unit mappings survive missing glyphs and isolated surrogates.`

Commit boundary:
- `Sources/MonaCodeAppKit/Layout/MonaTextShaper.swift`
- `Sources/MonaCodeAppKit/Layout/MonaFontFallbackResolver.swift`
- `Sources/MonaCodeAppKit/Layout/MonaGlyphRun.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaTextShaperTests.swift`

<!-- monacode-plan-task:{"id":"P03-T003","recordSha256":"d0d3fba484d0beb18522dab938a3ee314e1a224dbee2260a9bb152dce7a23c9a"} -->
## P03-T003 — Freeze shared immutable LineLayoutRecord geometry

Contract: `V1-R3.lineLayoutRecord`, `V1-R4.rendererParity`, `C03`, `C08`

Dependencies:
- `P03-T002`

Ownership selectors:
- `layout:line-layout-record`
- `renderer:shared-geometry`

Files to create:
- `Sources/MonaCodeAppKit/Layout/MonaLineLayoutRecord.swift`
- `Sources/MonaCodeAppKit/Layout/MonaLineLayoutBuilder.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Layout/MonaLineLayoutRecordTests.swift`

Interfaces consumed:
- `MonaGlyphRun`
- `MonaViewGraph`

Interfaces produced:
- `MonaLineLayoutRecord`
- `MonaLineLayoutBuilder`

Red verification:
- Run: `swift test --filter MonaLineLayoutRecordTests/testRawOffsetGeometryRoundTrip`
  - Expected exit: `1`
  - Expected output includes: `LINE_LAYOUT_ROUNDTRIP_MISMATCH offset=isolated-surrogate`

Minimal implementation operations:
- `Store glyph runs, advances, baselines, raw-unit boundaries, bidi levels, injected-text spans, decorations, and paint inputs in one immutable record.`
- `Make hit testing and every renderer consume the same record without reshaping.`
- `Key records by complete dependency stamps rather than viewport position alone.`

Green verification:
- Run: `swift test --filter MonaLineLayoutRecordTests`
  - Expected exit: `0`
  - Expected output includes: `LINE_LAYOUT_RECORD roundTrips=512 immutable=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T003.json`

Completion assertions:
- `Geometry round-trips raw offsets and points.`
- `Core Graphics and conditional Metal share one record.`
- `No renderer owns separate text layout.`

Commit boundary:
- `Sources/MonaCodeAppKit/Layout/MonaLineLayoutRecord.swift`
- `Sources/MonaCodeAppKit/Layout/MonaLineLayoutBuilder.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaLineLayoutRecordTests.swift`

<!-- monacode-plan-task:{"id":"P03-T004","recordSha256":"e6b7d5d18f76dab9fa2889033d92ee07aa7c685857315a7a4ac3b3bf2f25d7df"} -->
## P03-T004 — Define seven non-contradictory dependency stamp domains

Contract: `V1-R3.generationModel`, `V1-R4.crossEngineInvalidation`, `R1.validity`

Dependencies:
- `P03-T003`

Ownership selectors:
- `layout:seven-dependency-stamps`

Files to create:
- `Sources/MonaCodeAppKit/Layout/MonaDependencyStamps.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Layout/MonaDependencyStampTests.swift`

Interfaces consumed:
- `MonaLineLayoutRecord`
- `MonaAsyncValidityTicket`

Interfaces produced:
- `ProjectionStamp`
- `VerticalStamp`
- `ScrollDimensionStamp`
- `GeometryStamp`
- `PaintStamp`
- `SurfaceStamp`
- `FrameStamp`

Red verification:
- Run: `swift test --filter MonaDependencyStampTests/testEveryMutationInvalidatesExactDomains`
  - Expected exit: `1`
  - Expected output includes: `DEPENDENCY_STAMP_UNDER_INVALIDATION mutation=font-fallback`

Minimal implementation operations:
- `Define ProjectionStamp, VerticalStamp, ScrollDimensionStamp, GeometryStamp, PaintStamp, SurfaceStamp, and FrameStamp as distinct immutable values.`
- `Enumerate every mutation-to-domain edge from V1-R3 and V1-R4.`
- `Reject both missing invalidations and invalidation fanout beyond the frozen edge set.`

Green verification:
- Run: `swift test --filter MonaDependencyStampTests`
  - Expected exit: `0`
  - Expected output includes: `DEPENDENCY_STAMPS domains=7 mutationEdges=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T004.json`

Completion assertions:
- `Exactly seven stamp domains exist.`
- `Every frozen dependency edge is represented once.`
- `No six-domain compatibility prose remains normative.`

Commit boundary:
- `Sources/MonaCodeAppKit/Layout/MonaDependencyStamps.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaDependencyStampTests.swift`

<!-- monacode-plan-task:{"id":"P03-T005","recordSha256":"f20c1907c04a0888d8e189fc65c11ce84ffa4f205c56046e18c5f943cca5aeff"} -->
## P03-T005 — Implement scroll truth and dimension convergence

Contract: `V1-R3.scrollTruth`, `I3-R4.scrollEvents`, `C03`, `P04`

Dependencies:
- `P03-T001`
- `P03-T004`

Ownership selectors:
- `layout:scroll-model`
- `layout:scroll-dimensions`

Files to create:
- `Sources/MonaCodeAppKit/Layout/MonaScrollModel.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Layout/MonaScrollModelTests.swift`

Interfaces consumed:
- `MonaVerticalIndex`
- `ScrollDimensionStamp`

Interfaces produced:
- `MonaScrollModel`
- `MonaScrollSnapshot`

Red verification:
- Run: `swift test --filter MonaScrollModelTests/testDimensionShrinkClampOrder`
  - Expected exit: `1`
  - Expected output includes: `SCROLL_DIFFERENTIAL_MISMATCH fixture=dimension-shrink-clamp`

Minimal implementation operations:
- `Separate requested, validated, and published scroll positions.`
- `Converge content dimensions, viewport dimensions, and clamping in the frozen event order.`
- `Preserve subpixel values until the final surface transform.`

Green verification:
- Run: `swift test --filter MonaScrollModelTests`
  - Expected exit: `0`
  - Expected output includes: `SCROLL_MODEL traces=240 eventOrder=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T005.json`

Completion assertions:
- `Scroll traces match comparator order.`
- `Dimension shrink never publishes an out-of-range position.`
- `Subpixel coordinates remain stable.`

Commit boundary:
- `Sources/MonaCodeAppKit/Layout/MonaScrollModel.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaScrollModelTests.swift`

<!-- monacode-plan-task:{"id":"P03-T006","recordSha256":"a11ac1fbb005850d529980f7aef3881e88c66b8bc0a5fb47a4194c076e92d899"} -->
## P03-T006 — Complete the correct Core Graphics tiled renderer

Contract: `V1-R3.coreGraphicsRenderer`, `V1-R4.colorSpace`, `C03`, `C08`, `P04`

Dependencies:
- `P03-T003`
- `P03-T004`
- `P03-T005`

Ownership selectors:
- `renderer:core-graphics-complete`

Files to create:
- `Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift`
- `Sources/MonaCodeAppKit/Rendering/MonaRenderTileCache.swift`
- `Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Rendering/MonaCoreGraphicsRendererTests.swift`

Interfaces consumed:
- `MonaLineLayoutRecord`
- `PaintStamp`
- `SurfaceStamp`
- `FrameStamp`
- `MonaScrollSnapshot`

Interfaces produced:
- `MonaCoreGraphicsRenderer`
- `MonaRenderTileCache`
- `MonaRenderSurface`

Red verification:
- Run: `swift test --filter MonaCoreGraphicsRendererTests/testScaleSubpixelFallbackMatrix`
  - Expected exit: `1`
  - Expected output includes: `CORE_GRAPHICS_GOLDEN_MISMATCH cell=scale2-phase0.5-fallback`

Minimal implementation operations:
- `Paint only complete immutable layout records into generation-keyed tiles.`
- `Composite text, selections, cursors, decorations, widgets, gutters, minimap inputs, and overlays in frozen z-order.`
- `Use linear premultiplied RGBA and preserve scale plus subpixel phase in cache keys.`
- `Bound tile memory and evict without losing current-generation truth.`

Green verification:
- Run: `swift test --filter MonaCoreGraphicsRendererTests`
  - Expected exit: `0`
  - Expected output includes: `CORE_GRAPHICS_RENDERER goldens=all cacheBounded=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T006.json`

Completion assertions:
- `Core Graphics is functionally complete before any Metal decision.`
- `All scale/subpixel/fallback/color-glyph goldens pass.`
- `Tile memory remains within the declared bound.`

Commit boundary:
- `Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift`
- `Sources/MonaCodeAppKit/Rendering/MonaRenderTileCache.swift`
- `Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift`
- `Tests/MonaCodeAppKitTests/Rendering/MonaCoreGraphicsRendererTests.swift`

<!-- monacode-plan-task:{"id":"P03-T007","recordSha256":"cbb6874915c6e2d70f28546cfb02cc9661b4808543ec0ac2b5e2e5877d71526a"} -->
## P03-T007 — Enforce the QueryGeometryBarrier for hit testing and native queries

Contract: `V1-R3.geometryBarrier`, `I3-R3.compositionGeometry`, `A1-R.textQueries`

Dependencies:
- `P03-T005`
- `P03-T006`

Ownership selectors:
- `layout:query-geometry-barrier`
- `layout:hit-testing`

Files to create:
- `Sources/MonaCodeAppKit/Layout/MonaQueryGeometryBarrier.swift`
- `Sources/MonaCodeAppKit/Layout/MonaHitTester.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Layout/MonaQueryGeometryBarrierTests.swift`

Interfaces consumed:
- `MonaLineLayoutRecord`
- `MonaScrollSnapshot`
- `FrameStamp`

Interfaces produced:
- `MonaQueryGeometryBarrier`
- `MonaHitTester`

Red verification:
- Run: `swift test --filter MonaQueryGeometryBarrierTests/testRejectsMixedGenerationQuery`
  - Expected exit: `1`
  - Expected output includes: `GEOMETRY_BARRIER_MIXED_GENERATION requested=8 available=7`

Minimal implementation operations:
- `Answer point, range, caret, selection, composition, and accessibility geometry only from one complete generation.`
- `Synchronously finish bounded visible-line work when the contract requires an immediate query.`
- `Return typed unavailable geometry when bounded completion fails.`

Green verification:
- Run: `swift test --filter MonaQueryGeometryBarrierTests`
  - Expected exit: `0`
  - Expected output includes: `GEOMETRY_BARRIER mixedGeneration=0 boundedFailure=typed`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T007.json`

Completion assertions:
- `No query combines generations.`
- `Hit testing round-trips with layout records.`
- `Failure never fabricates geometry.`

Commit boundary:
- `Sources/MonaCodeAppKit/Layout/MonaQueryGeometryBarrier.swift`
- `Sources/MonaCodeAppKit/Layout/MonaHitTester.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaQueryGeometryBarrierTests.swift`

<!-- monacode-plan-task:{"id":"P03-T008","recordSha256":"d35d9ddf487ce04746ed5519b15535f36d24f85c1685b88d132ebd2a6fb4651b"} -->
## P03-T008 — Represent bounded Core Text failure with FailedLineRecord

Contract: `V1-R3.failedLineRecord`, `R1.failureIsolation`, `C08`

Dependencies:
- `P03-T002`
- `P03-T007`

Ownership selectors:
- `layout:failed-line-record`

Files to create:
- `Sources/MonaCodeAppKit/Layout/MonaFailedLineRecord.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Layout/MonaFailedLineRecordTests.swift`

Interfaces consumed:
- `MonaTextShaper`
- `MonaQueryGeometryBarrier`

Interfaces produced:
- `MonaFailedLineRecord`

Red verification:
- Run: `swift test --filter MonaFailedLineRecordTests/testInjectedShapingFailure`
  - Expected exit: `1`
  - Expected output includes: `PARTIAL_LINE_LAYOUT_PUBLISHED line=17`

Minimal implementation operations:
- `Convert bounded shaping and line-construction failures into immutable failed-line records.`
- `Retain raw range, dependency stamps, typed reason, retry generation, and safe fallback height.`
- `Prevent hit testing, selection geometry, or renderer code from consuming partial glyph data.`

Green verification:
- Run: `swift test --filter MonaFailedLineRecordTests`
  - Expected exit: `0`
  - Expected output includes: `FAILED_LINE_RECORD injections=12 partialPublished=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T008.json`

Completion assertions:
- `Injected failures never publish partial geometry.`
- `Retry follows dependency generation changes.`
- `The editor remains responsive with typed degraded lines.`

Commit boundary:
- `Sources/MonaCodeAppKit/Layout/MonaFailedLineRecord.swift`
- `Tests/MonaCodeAppKitTests/Layout/MonaFailedLineRecordTests.swift`

<!-- monacode-plan-task:{"id":"P03-T009","recordSha256":"1c428e5a29111157ba63089115d3a6df7c4ba8b053deb69096a6b1ee0836d0b5"} -->
## P03-T009 — Instrument renderer-owned correctness and performance metrics

Contract: `V1-R4.measurementPartition`, `Q1-R2.componentMetrics`, `Q1-R3.statistics`

Dependencies:
- `P03-T006`
- `P03-T007`
- `P03-T008`

Ownership selectors:
- `renderer:metric-instrumentation`

Files to create:
- `Sources/MonaCodeAppKit/Rendering/MonaRendererMetrics.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Rendering/MonaRendererMetricsTests.swift`

Interfaces consumed:
- `MonaCoreGraphicsRenderer`
- `MonaRenderSurface`
- `MonaFailedLineRecord`
- `MonaHighResolutionClock`

Interfaces produced:
- `MonaRendererMetrics`
- `RendererMetricTrace`

Red verification:
- Run: `swift test --filter MonaRendererMetricsTests/testExcludesModelAndProviderTime`
  - Expected exit: `1`
  - Expected output includes: `RENDERER_METRIC_SCOPE_VIOLATION metric=layout-ready-to-present`

Minimal implementation operations:
- `Measure layout-ready-to-present, GPU frame time when present, renderer-surface footprint, missed presentation, and renderer energy.`
- `Exclude model load, RegExp, diff, provider, LSP, and whole-application resource costs from renderer trigger metrics.`
- `Emit balanced block identifiers and unrounded binary64 samples for Q1-R3.`

Green verification:
- Run: `swift test --filter MonaRendererMetricsTests`
  - Expected exit: `0`
  - Expected output includes: `RENDERER_METRICS scoped=5 crossDomainSamples=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T009.json`

Completion assertions:
- `Every trigger metric is renderer-attributable.`
- `End-to-end metrics cannot trigger Metal directly.`
- `Metric traces are bootstrap-ready.`

Commit boundary:
- `Sources/MonaCodeAppKit/Rendering/MonaRendererMetrics.swift`
- `Tests/MonaCodeAppKitTests/Rendering/MonaRendererMetricsTests.swift`

<!-- monacode-plan-task:{"id":"P03-T010","recordSha256":"b0dcc7429f88b2be9273205e5edc696c6f8bb871c9b685de8ad4f8060f7c1222"} -->
## P03-T010 — Resolve the renderer decision from complete Core Graphics evidence

Contract: `G5-R.performanceDecision.metalTrigger`, `V1-R4.rendererDecision`, `C03`, `C08`

Dependencies:
- `P03-T009`

Ownership selectors:
- `renderer:decision-gate`
- `renderer-metric:C03`
- `renderer-metric:C08`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Rendering/MonaRendererDecisionGateTests.swift`

Interfaces consumed:
- `MonaCoreGraphicsRenderer`
- `RendererMetricTrace`
- `BootstrapVerdict`

Interfaces produced:
- `MonaRendererDecision`

Red verification:
- Run: `swift test --filter MonaRendererDecisionGateTests/testRejectsEndToEndTrigger`
  - Expected exit: `1`
  - Expected output includes: `RENDERER_TRIGGER_SCOPE_INVALID metric=first-present`

Minimal implementation operations:
- `Run all renderer-owned C03/C08 correctness cells and paired M0/M1 performance cells after Core Graphics completion.`
- `Record exactly one immutable decision: not-triggered-and-absent or triggered-and-required.`
- `Reject first-present, input-to-present, whole-application footprint, and other cross-domain metrics as direct triggers.`

Green verification:
- Run: `swift test --filter MonaRendererDecisionGateTests`
  - Expected exit: `0`
  - Expected output includes: `RENDERER_DECISION valid=1 branchesRecorded=1`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T010.json`

Completion assertions:
- `Exactly one renderer branch is recorded.`
- `The decision consumes complete Core Graphics evidence.`
- `Only C03/C08 renderer-owned metrics affect the branch.`

Commit boundary:
- `Tests/MonaCodeAppKitTests/Rendering/MonaRendererDecisionGateTests.swift`

<!-- monacode-plan-task:{"id":"P03-T011","recordSha256":"b90e4787f2752a28f2765c33461d4d4432bafd9ff0dcfbbdf6b8ea2b8bd22555"} -->
## P03-T011 — Execute the conditional Metal branch entirely inside Phase 03

Contract: `G5-R.performanceDecision.metalTrigger`, `V1-R4.crossEngineEquivalence`, `C08`

Dependencies:
- `P03-T010`

Ownership selectors:
- `renderer:metal-conditional`

Files to create:
- `Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Rendering/MonaMetalRendererParityTests.swift`

Interfaces consumed:
- `MonaRendererDecision`
- `MonaLineLayoutRecord`
- `MonaRenderSurface`

Interfaces produced:
- `ConditionalMonaMetalRenderer`
- `RendererBranchEvidence`

Red verification:
- Run: `swift test --filter MonaMetalRendererParityTests/testRequiredBranchCannotRemainAbsent`
  - Expected exit: `1`
  - Expected output includes: `METAL_BRANCH_INCOMPLETE decision=triggered-and-required`

Minimal implementation operations:
- `When the decision is not-triggered-and-absent, record source absence and execute no product-source change.`
- `When the decision is triggered-and-required, implement rendering from the shared layout record and linear premultiplied RGBA inputs.`
- `Require per-channel absolute difference at most 1/255 against Core Graphics.`
- `Fall back to the next complete Core Graphics generation on device, resource, or presentation failure.`

Green verification:
- Run: `swift test --filter MonaMetalRendererParityTests`
  - Expected exit: `0`
  - Expected output includes: `RENDERER_BRANCH valid=1 parityOrAbsence=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T011.json`

Completion assertions:
- `The not-triggered branch contains no Metal source.`
- `The triggered branch completes parity and failure fallback.`
- `No later phase creates renderer source.`

Commit boundary:
- `Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift`
- `Tests/MonaCodeAppKitTests/Rendering/MonaMetalRendererParityTests.swift`

<!-- monacode-plan-task:{"id":"P03-T012","recordSha256":"a68a5a356b37da19d1ddd32c417aede9a621d9aefc94c19096dca856ddee5d55"} -->
## P03-T012 — Close projection, geometry, and renderer parity before native input

Contract: `V1-R3`, `V1-R4`, `C03`, `C08`, `P04`, `P06`

Dependencies:
- `P03-T011`

Ownership selectors:
- `normativeLayer:layout-rendering:V1-R3`
- `normativeLayer:layout-rendering:V1-R4`
- `phase-gate:03`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Phase03RendererConformanceTests.swift`

Interfaces consumed:
- `MonaViewGraph`
- `MonaLineLayoutRecord`
- `MonaScrollModel`
- `MonaCoreGraphicsRenderer`
- `MonaQueryGeometryBarrier`
- `MonaFailedLineRecord`
- `RendererBranchEvidence`

Interfaces produced:
- `Phase03RendererGate`

Red verification:
- Run: `swift test --filter Phase03RendererConformanceTests/testSeededGenerationTear`
  - Expected exit: `1`
  - Expected output includes: `PHASE03_RENDERER_GATE_FAILED reason=mixed-generation-frame`

Minimal implementation operations:
- `Run projection, geometry, scroll, shaping, failure, Core Graphics, and selected renderer-branch matrices as one revision-locked suite.`
- `Prove viewport operation counts scale with visible rows plus changed dependencies.`
- `Freeze the renderer source set and branch evidence consumed by Phase 08 candidate generation.`

Green verification:
- Run: `swift test --filter Phase03RendererConformanceTests`
  - Expected exit: `0`
  - Expected output includes: `PHASE03_RENDERER_GATE C03=pass C08=pass mixedGeneration=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-03/P03-T012.json`

Completion assertions:
- `C03 and C08 renderer prerequisites pass.`
- `The renderer decision is immutable.`
- `Renderer source production is closed at Phase 03.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Phase03RendererConformanceTests.swift`
