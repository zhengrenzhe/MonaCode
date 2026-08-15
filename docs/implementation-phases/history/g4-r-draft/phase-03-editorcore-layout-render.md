# Phase 3 — EditorCore + ViewGraph + Core Text + Core Graphics

**Goal:** Implement the editor core: synchronous `ViewGraph` + vertical indexes (the editor coordinate domain), Core Text shaping/layout/hit-test (sole typography authority), the shared immutable `LineLayoutRecord`, the 7 `DependencyStamp` domains, `MonaScrollModel`, and the Core Graphics tiled renderer. Metal is scaffolded but NOT implemented unless the renderer-owned gate fires (Phase 8). Completes **C03** and the CG portion of **C08**.

**G4-R mapping:** layout-rendering V1-R3 (Core Text projection, geometry, Core Graphics base), V1-R4 (cross-engine equivalence, deterministic conditional-Metal overlay).

**Prerequisites:** Phase 1 (model + base types), Phase 2 (word boundary / RegExp for projection word boundaries; StringBuilder for glyph runs). E1 clocks for input-latency recording (Phase 0).

**Exit Gates (this phase completes):**
- **C03 (pass)** — projection exact domain (fold/inject/zones/bidi) differentially verified vs Monaco; Core Text property oracle for caret/hit/selection/scroll/AX geometry; full Unicode corpus; all V1-R4 native invariants.
- **C08 (CG partial)** — CG `CTLine` goldens for every scale/subpixel-phase/fallback/color-glyph; generation/rollover/stale/failure. Metal N/A unless triggered (Phase 8).
- No candidate artifact (cache/lifetime manifests are Phase 7).
- Preflight: audit/verify-contract pass.

---

## Task 3.1 — EditorCore + projection (ViewGraph + vertical indexes)

**Dependencies:** 1.8, 1.12
**Files:** Create `Sources/MonaCode/Editor/MonaEditorCore.swift`, `Sources/MonaCode/Editor/Projection/MonaViewGraph.swift`, `Sources/MonaCode/Editor/Projection/MonaVerticalIndex.swift`; Test `Tests/MonaCodeTests/Editor/test_Projection.swift`
**Tests:** Synchronous `ViewGraph` + vertical index commit before API return. Projection exact domain: folding, injected text, view zones, bidi ordering — zero raw-unit diff vs M0/M1. `ViewGraph` is the sole coordinate truth; vertical indexes are prefix-sum structures; viewport queries never scan the full document (complexity gate). Projection changes participate in the R1 `DependencyStamp` (Phase 1 `DependencyStamp` receives `ProjectionStamp` + `VerticalStamp` here).
**Contract:** G4-R §architecture.projection (synchronous ViewGraph + vertical indexes = exact editor coordinate domain); V1-R3; §equivalenceDomains.exact (projection, folding, injected-text, editor state); §acceptance.crossCutting (operation counters prove Monaco asymptotic upper bounds; projection/vertical prefix queries never scan full document on viewport hot path).
**Produces:** —
**Exit-gate contribution:** C03 projection exact domain.
**Steps:**
- [ ] Implement `MonaViewGraph` (fold/inject/zone/bidi projection) + `MonaVerticalIndex` (prefix sums); commit on `@MainActor` synchronously before API return; capture projection fixtures; commit.

## Task 3.2 — Core Text shaping, line layout, font fallback

**Dependencies:** 3.1, 2.8
**Files:** Create `Sources/MonaCodeAppKit/Layout/MonaCoreTextShaper.swift`, `Sources/MonaCodeAppKit/Layout/MonaFontFallback.swift`; Test `Tests/MonaCodeAppKitTests/Layout/test_CoreTextShaper.swift`
**Tests:** `CTTypesetter`/`CTLine`/`CTRun` are the single shaping, glyph-order, kerning, line-break, hit-test, font-fallback authority. `kCTTypesetterOptionAllowUnboundedLayout=false` fixed. Simple-wrap break trace (exact domain) differentially verified vs Monaco; advanced-wrap break offsets are native-adapted (Core Text self-consistency, NOT Blink/HarfBuzz equality — `AdvancedCompatibilityPatchTable` is absent per V1-R4). Font matching: editor `fontFamily`/`fontSize`/`fontLigatures`/`fontFeatureSettings` map to Core Text attributes; color glyphs (emoji) via fallback.
**Contract:** G4-R §architecture.typography (Core Text only production shaping/layout/hit-test); §architecture.rendering (both renderers consume immutable LineLayoutRecord); V1-R3 (Core Text projection/geometry); V1-R4 (cross-engine: exact compatibility domain vs native-adapted geometry domain; `AdvancedCompatibilityPatchTable` deleted); §equivalenceDomains.nativeAdapted (Core Text geometry internally consistent; Blink/HarfBuzz not the oracle).
**Produces:** —
**Exit-gate contribution:** C03 Core Text property oracle; C08 CG goldens substrate.
**Steps:**
- [ ] Implement the shaper + fallback; capture simple-wrap exact fixtures + advanced-wrap Core-Text-self-consistency goldens; commit.

## Task 3.3 — LineLayoutRecord (shared immutable geometry)

**Dependencies:** 3.2
**Files:** Create `Sources/MonaCodeAppKit/Layout/MonaLineLayoutRecord.swift`; Test `Tests/MonaCodeAppKitTests/Layout/test_LineLayoutRecord.swift`
**Tests:** One shared immutable `LineLayoutRecord` consumed by: CG renderer, Metal renderer (Phase 8), IME `firstRect` (Phase 4), AX `frameForRange` (Phase 4), pointer hit-test (Phase 4), caret/selection geometry. No second measurement pass; renderers consume pixels only, never re-shape or re-hit-test. Geometry = `Double` logical points (prefix sums); public scroll/dimensions = integer points; trackpad `Double` residual stays in the input adapter; frame-local origin subtraction before `CGFloat`/`Float` conversion.
**Contract:** G4-R §architecture.rendering (both consume immutable LineLayoutRecord geometry); V1-R3; V1-R4 (one shared record; QueryGeometryBarrier); §equivalenceDomains.nativeAdapted.
**Produces:** —
**Exit-gate contribution:** C03; C08; C07 (Phase 4 geometry consumers).
**Steps:**
- [ ] Define the immutable record; wire shaper output into it; commit.

## Task 3.4 — Six DependencyStamp domains

**Dependencies:** 3.3, 1.10
**Files:** Create `Sources/MonaCode/Editor/Projection/MonaDependencyStamp.swift`; Test `Tests/MonaCodeTests/Editor/test_DependencyStamp.swift`
**Tests:** Seven stamp domains (per V1-R3; Surface and Frame are distinct, NOT merged) replace the single monolithic `LayoutStamp`: `ProjectionStamp`, `VerticalStamp`, `ScrollDimensionStamp`, `GeometryStamp`, `PaintStamp`, `SurfaceStamp`, `FrameStamp`. Each line tile/plane writes its actual dependency key; paint-only selection/caret updates reuse geometry/text surfaces without re-rasterization. Full-field equality gate (Phase 1 `DependencyStamp` now complete: projection, fold, injected text, font, theme, viewport, scale, renderer generation). A version-gap result installs `FailedLineRecord`; renderer failure switches the entire generation.
**Contract:** G4-R §architecture; R1 (LineLayoutRecord by model version alone REJECTED — geometry depends on projection/fold/injected/font/theme/viewport/scale/renderer generation); V1-R4 (six stamp domains); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C03; R1 layout gate (Phase 8).
**Steps:**
- [ ] Implement the 6 stamps + full-field equality; wire into validity gate; commit.

## Task 3.5 — MonaScrollModel

**Dependencies:** 3.3
**Files:** Create `Sources/MonaCodeAppKit/Layout/MonaScrollModel.swift`; Test `Tests/MonaCodeAppKitTests/Layout/test_ScrollModel.swift`
**Tests:** `MonaScrollModel` is the sole scroll truth. `NSScroller`, wheel phase/momentum, natural-direction are input/output adapters only. No giant `NSScrollView` documentView. Vertical coordinates `Double` logical points; public scroll/dimensions integer points; trackpad `Double` residual in the input adapter. AppKit natural-scroll reversal is NOT re-inverted.
**Contract:** G4-R §architecture; V1-R3 (MonaScrollModel sole scroll truth; no NSScrollView documentView); §equivalenceDomains.nativeAdapted.
**Produces:** —
**Exit-gate contribution:** C03; P04 scroll workload substrate.
**Steps:**
- [ ] Implement the scroll model + adapters; commit.

## Task 3.6 — Core Graphics tiled renderer

**Dependencies:** 3.3, 3.4, 2.8
**Files:** Create `Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift`, `Sources/MonaCodeAppKit/Rendering/MonaRenderGeneration.swift`; Test `Tests/MonaCodeAppKitTests/Rendering/test_CoreGraphicsRenderer.swift`
**Tests:** CG tiled renderer built and validated first. Consumes immutable `LineLayoutRecord` geometry + token/decoration runs (T1-R colors from Phase 5; until then the `vs` builtin theme — Monaco default, T1-R §surfaceCounts.theme.builtinThemes — is the stub). Generation/rollover/stale handling; paint-only updates reuse geometry. `CTLine` goldens for every scale/subpixel-phase/fallback/color-glyph. No DOM/CSS/SVG. If CG passes all Q1-R2 metrics, Metal is fixed N/A.
**Contract:** G4-R §architecture.rendering (Core Graphics first; Metal only after renderer-owned gate; both consume LineLayoutRecord); V1-R4 (CG-first, renderer-owned Metal trigger); §explicitCuts (SVG/DOM renderers, WebGPU); §equivalenceDomains.nativeAdapted (CG pixels use native goldens).
**Produces:** —
**Exit-gate contribution:** C08 (CG partial); P00/P02/P04/P05/P06/P12 substrate.
**Steps:**
- [ ] Implement the CG renderer + generation management; capture CTLine goldens; commit.

## Task 3.7 — QueryGeometryBarrier + hit-test

**Dependencies:** 3.3, 3.5
**Files:** Create `Sources/MonaCodeAppKit/Layout/MonaQueryGeometryBarrier.swift`, `Sources/MonaCodeAppKit/Layout/MonaHitTest.swift`; Test `Tests/MonaCodeAppKitTests/Layout/test_QueryGeometry.swift`
**Tests:** IME `firstRect` and AX `frameForRange` share an LF-normalized `NativeTextIndex`. Ranges ≤ `accessibilityPageSize` model lines synchronously materialize tight visible-segment unions. Larger ranges return exact vertical extent + 10,000,000-point horizontal saturation (AppKit-compatible). Hidden-only ranges return `NSZeroRect`. No frame committed, no scroll, no long-term cache. Single hit-test (V1-R4) for `rangeForPosition`; `rangeForIndex` uses AppKit composed-character contract (combining sequences + valid surrogate pairs merged; isolated surrogate = length 1).
**Contract:** G4-R §architecture; V1-R3 (QueryGeometryBarrier); V1-R4 (single hit-test); §equivalenceDomains.nativeAdapted.
**Produces:** —
**Exit-gate contribution:** C03; C07 (Phase 4 IME/AX geometry).
**Steps:**
- [ ] Implement the barrier + hit-test; commit.

## Task 3.8 — FailedLineRecord (Core Text bounded failure)

**Dependencies:** 3.6
**Files:** Create `Sources/MonaCodeAppKit/Layout/MonaFailedLineRecord.swift`; Test `Tests/MonaCodeAppKitTests/Layout/test_FailedLineRecord.swift`
**Tests:** `kCTTypesetterOptionAllowUnboundedLayout=false`; NULL Core Text return installs a same-generation `FailedLineRecord` (fixed row height, diagnostic surface, hit zones, `outsideRenderedLine` geometry). Model/selection/copy/undo/LSP/projection remain intact. A `FailedLineRecord` on normal Unicode corpus FAILS correctness; an unreasonable-effort corpus passes by showing no hang/crash/model loss. Core Text NULL → `FailedLineRecord` (NOT a backend switch). Metal device/resource failure falls back to CG at the next complete renderer generation (Phase 8).
**Contract:** G4-R §architecture; V1-R3 (Core Text bounded failure; FailedLineRecord); R1 (CT NULL → FailedLineRecord, not backend switch); §acceptance.crossCutting (zero crash/hang/data loss).
**Produces:** —
**Exit-gate contribution:** C03; C08; failure-injection gate (Phase 8).
**Steps:**
- [ ] Implement `FailedLineRecord` + NULL handling; commit.

## Task 3.9 — Cross-engine equivalence partition + Metal trigger scaffolding

**Dependencies:** 3.6, 3.8
**Files:** Create `Sources/MonaCodeAppKit/Rendering/MonaRendererSelection.swift` (state machine), `Sources/MonaCodeAppKit/Rendering/MonaMetalTrigger.swift` (gate only; no Metal implementation); Test `Tests/MonaCodeAppKitTests/Rendering/test_RendererSelection.swift`
**Tests:** Two equivalence domains separated: **exact** (raw UTF-16 model value, EOL, positions, fold/injected ordering, view mapping, simple wrapping break trace, options/commands/context-keys) differentially verified vs Monaco; **native-adapted** (Core Text font matching, advanced wrap break offsets, caret x, selection polygons, hit-test, pixel rasterization, AX screen frames) verified against Core Text self-consistency (Chrome numerical equality NOT required). Metal trigger scoped to **renderer-attributable sub-measurements** (`layout-ready→present`, GPU frame time, renderer-surface footprint, missed presentation, renderer energy); the end-to-end metrics `first-present`/`input→present`/whole-process-`footprint` are **NOT** direct triggers (they span non-renderer compute — model load/LSP/diff — and a large-model slow `first-present` must NOT fire Metal); `frame CPU/GPU` narrowed to GPU frame time. CG-only release is a valid outcome (Metal status N/A). When Metal exists: identical `LineLayoutRecord` + linear-premultiplied RGBA, per-channel max diff ≤1/255. *(See Revision 2 below for the full M1 correction.)*
**Contract:** G4-R §architecture.rendering; V1-R4 (cross-engine equivalence; CG-first; renderer-owned Metal trigger; `metalNotTriggered`); §performanceDecision.metalTrigger / metalNotTriggered; §equivalenceDomains.nativeAdapted.
**Produces:** —
**Exit-gate contribution:** C03; C08 (CG pass; Metal N/A or ≤1/255 in Phase 8).
**Steps:**
- [ ] Implement the renderer-selection state machine + Metal trigger gate (gate only; Metal implementation deferred to Phase 8 conditional); document the exact/native-adapted partition; commit.

## Task 3.10 — Phase 3 integration + C03/C08(CG) differential

**Dependencies:** 3.1–3.9
**Files:** Modify `Tests/DifferentialFixtures/layout/`; Create `docs/implementation-phases/verification/phase-03-verification.md` (after verification)
**Tests:** C03 full differential passes (projection exact + Core Text self-consistency goldens); C08 CG goldens pass; Metal status N/A (CG-only). `swift test` green; `QEnvironmentID` preflight clean.
**Contract:** G4-R §designClosure.phaseRule; §performanceDecision.metalNotTriggered.
**Produces:** —
**Exit-gate contribution:** C03 pass, C08 CG pass; Phase 3 done when committed + three adversarial rounds pass.
**Steps:**
- [ ] Run C03/C08(CG) differential; confirm Metal N/A; commit; trigger per-phase adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-03-verification.md` (3 rounds, no BLOCKING):

- **Task 3.4 (M2):** three **distinct** failure paths — (a) **stamp-mismatch / version-gap → DROP** the stale result (the previous accepted record is retained; no `FailedLineRecord`); (b) **CT NULL → same-generation `FailedLineRecord`**; (c) **renderer failure → whole-generation CG switch**. (Do NOT install `FailedLineRecord` on stamp-mismatch — stale results during typing must not render failure surfaces.)
- **Task 3.4 (M3):** **7 stamp domains** (per V1-R3; Surface and Frame are distinct, NOT merged): `ProjectionStamp`, `VerticalStamp`, `ScrollDimensionStamp`, `GeometryStamp`, `PaintStamp`, `SurfaceStamp`, `FrameStamp`. Domain→field mapping: Projection→projection/fold/injected; Vertical→viewport/scroll; ScrollDimension→scroll extent; Geometry→font/scale/renderer-generation; Paint→theme; Surface→text/glyph surfaces; Frame→frame geometry. The 8-field `DependencyStamp` (projection, fold, injected, font, theme, viewport, scale, renderer-generation) is the union; Phase 1 supplies model fields, Phase 3 supplies layout fields.
- **Task 3.9 (M1):** each Metal trigger metric is a **renderer-attributable sub-measurement with explicit start/end boundaries** — `layout-ready→present`, GPU frame time, renderer-surface footprint, missed presentation, renderer energy — that **excludes model/search/LSP/diff compute**. The end-to-end names `first-present`/`input→present`/`footprint` are NOT used as triggers directly (they span non-renderer compute); a large-model slow `first-present` must NOT fire Metal. CG-only release remains valid (`metalNotTriggered`).
- **Task 3.5:** "adapters" = coordinate/natural-direction adapters (V1-R3); wheel/trackpad **event** handlers are Phase 4 (I3-R4).
- **Prerequisite:** corrected — Phase 2 uses the `wordSeparators` classifier (NOT regex `\b`) for projection word boundaries; add 3.1/3.2→2.3 dependency edge.
- **Task 3.1/3.2 bidi contract:** 3.1 produces directionally-tagged pre-reordered runs; 3.2 forces per-run direction (no Core Text re-bidi) — preserves exact visual order with native-adapted glyph metrics (no double-bidi).
- **Task 3.2:** `FontDescriptorKey` includes fontFamily/fontWeight/fontLigatures/fontFeatureSettings/**fontVariationSettings** (family/weight/feature/variation grammar).
- **Task 3.6:** Phase 3 Metal state = `not-triggered`/`not-implemented` (`empiricalStatus.metal`); trigger **evaluation** is Phase 8.
- **Task 3.7:** `FailedLineRecord` satisfies the `LineLayoutRecord` interface (`outsideRenderedLine` geometry) for hit-test/`firstRect`/`frameForRange` on failed lines; add 3.8 dependency.
- **Task 3.8:** no partial `CTLine` batch on mid-line NULL; define the normal-Unicode vs unreasonable-effort corpus boundary (a `FailedLineRecord` on normal Unicode FAILS correctness; unreasonable-effort corpus passes by no-hang/crash/model-loss).
- **Task 3.9:** partition enumerates V1-R4 exact items (scroll/top/line API state, reveal intent, save/restore schema, widgets/zones lifecycle, affinity) and native-adapted items (subpixel phase, scroll extent, fallback/glyph-shaping) or manifest-references them.
