# MonaCode AppKit/SwiftUI/Sample Implementation Inventory

> Audit date: 2026-08-22. Scope: `Sources/MonaCodeAppKit/`, `Sources/MonaCodeSwiftUI/`, `Sources/MonaCodeSample/main.swift`. 83 Swift files total (76 AppKit + 6 SwiftUI + 1 Sample).

## Quantified Summary

| Status | Count | Files |
|--------|-------|-------|
| **REAL** | 76 | Files with genuine functional logic (state machines, data transformations, real API calls, real model interactions). Includes files with explicitly-reserved no-op slots (e.g. CG renderer's cursors/widgets/gutters/minimap layers) and Metal renderer (real code, `.notTriggeredAndAbsent` by design at runtime). |
| **PARTIAL** | 3 | `MonaRenderSurface` (scaleFactor stored but not applied to bitmap dims/CTM — Retina blur root cause), `MonaEditorInstanceAdapters` (identity/lifetime/focus real; most members inert + 1 fatalError), `MonaAXWidgetProxy` (proxy real; `MonaWidgetMouseTargetController.getTargetAtClientPoint` returns nil — documented placeholder) |
| **STUB** | 4 | `AppKit/Scaffold.swift` (1-line comment), `SwiftUI/Scaffold.swift` (2-line comment), `AppKit/Generated/MonaAppKitPublicAPI.swift` (generated declaration shapes with empty bodies), `SwiftUI/Generated/MonaSwiftUIPublicAPI.swift` (generated manifest of 3 CUT paths, 0 declarations) |

**Three critical findings:**

1. **Retina blur root cause**: `MonaRenderSurface.init` stores `scaleFactor` (line 92) but does NOT multiply bitmap dimensions (`width`/`height` at lines 90-91, 103-108) or apply a CTM scale. `MonaCodeEditorView.draw(_:)` reads `window?.backingScaleFactor` (line 726) and passes it into the tile key, but the tile bitmap is always allocated at `tileSide x tileSide` (256x256) regardless of scale. On a 2x Retina display, a 256-pixel bitmap is drawn into a 256-point (512-device-pixel) rect, causing 2x upsampling blur.

2. **First responder at runtime**: `acceptsFirstResponder` returns `true` (line 1202) and `becomeFirstResponder` is real (line 1223). `makeFirstResponder(view)` is called only in `MonaEditorInstanceAdapters.focus()` (lines 780, 1046). The sample host (`main.swift`) does NOT call `makeFirstResponder` or `setInitialFirstResponder` — it makes the window key+front but never explicitly assigns first responder to the editor. Keyboard input works only if AppKit's responder chain selects the view automatically.

3. **SwiftUI/Sample realness**: All 3 SwiftUI wrappers (`MonaCodeEditor`, `MonaDiffEditor`, `MonaMultiDiffEditor`) + `MonaSwiftUIEditorController` are REAL `NSViewRepresentable` bridges with genuine `makeNSView`/`updateNSView`. The sample constructs a real `NSWindow` + editor + diff views + SwiftUI wrappers and runs `NSApplication`. 2 stubs: `Scaffold.swift` files and the generated manifest.

---

## MonaCodeAppKit

### Rendering/

#### MonaCoreGraphicsRenderer.swift (397 lines) — **REAL** (4/8 layers no-op)
- **Implements**: Tiled Core Graphics renderer painting `MonaLineLayoutRecord`s into generation-keyed `MonaRenderSurface` tiles, compositing in frozen z-order.
- **Status**: REAL for text/selections/decorations/overlays; STUB (no-op) for cursors/widgets/gutters/minimap layers.
- **Evidence**:
  - `tile(for:records:lineOrigins:layerInputs:)` at line 137: real cache-miss rasterization.
  - `paintTextLayer` at line 211: real `CTFontDrawGlyphs` (line 248) + per-line background fill (line 228).
  - `paintSelectionsLayer` at line 264: real selection rect fills (line 291).
  - `paintDecorationsLayer` at line 305: real underline rects (line 329).
  - `paintOverlaysLayer` at line 347: real overlay fills (line 350).
  - `paintCursorsLayer` at line 301: `{ _ = ctx }` — no-op.
  - `paintWidgetsLayer` at line 336: `{ _ = ctx }` — no-op.
  - `paintGuttersLayer` at line 339: `{ _ = ctx }` — no-op.
  - `paintMinimapLayer` at line 342: `{ _ = ctx }` — no-op.
  - `pixelX(for:in:)` at line 372: real raw-unit boundary lookup (no reshaping).

#### MonaRenderSurface.swift (158 lines) — **PARTIAL**
- **Implements**: Bitmap `CGContext` render target in linear premultiplied RGBA (8 bpc, 32 bpp).
- **Status**: PARTIAL — `scaleFactor` stored but never applied to bitmap dimensions or CTM.
- **Evidence**:
  - `init(width:height:scaleFactor:)` at line 86: receives `scaleFactor`.
  - Line 90-91: `self.width = width` / `self.height = height` — dimensions NOT multiplied by scaleFactor.
  - Line 92: `self.scaleFactor = scaleFactor` — stored as property only.
  - Line 103: `let rowBytes = width * 4` — NOT `width * scaleFactor * 4`.
  - Line 106: `UnsafeMutableRawPointer.allocate(byteCount: rowBytes * height, ...)` — buffer at `width x height`, NOT scaled.
  - Lines 110-118: `CGContext(data: buffer, width: width, height: height, ...)` — context at `width x height`, NOT scaled.
  - No `ctx.scaleBy(x: scaleFactor, y: scaleFactor)` call anywhere in the file.
  - **CRITICAL**: This is the Retina blur root cause. On a 2x display, the 256x256 bitmap is drawn into a 256-point (512-device-pixel) rect, causing 2x upsampling.

#### MonaMetalRenderer.swift (565 lines) — **REAL code, NOT triggered at runtime**
- **Implements**: Conditional Metal renderer with device, command queue, shader library, pipeline states, and render passes. Falls back to CG on failure.
- **Status**: REAL Metal implementation, but the default branch is `.notTriggeredAndAbsent` — no Metal resources allocated at runtime.
- **Evidence**:
  - `MonaMetalRendererBranch` at line 58: `.notTriggeredAndAbsent` / `.triggeredAndRequired`.
  - In `MonaCodeEditorView.commonInit` (line 287): `metalRenderer = MonaMetalRenderer(branch: .notTriggeredAndAbsent, ...)`.
  - `prepareMetalResources()` at line 227: real `MTLCreateSystemDefaultDevice`, `makeCommandQueue`, `makeLibrary`, `makeRenderPipelineState` — only called when `.triggeredAndRequired`.
  - `renderViaMetal(...)` at line 281: real Metal render — creates textures, encodes draw calls, reads back. Lines 311-363.
  - `shaderSource` at line 501: real Metal shader source (vertex + fragment for solid fills + textured blit). Lines 501-564.
  - When `.notTriggeredAndAbsent` (the runtime default): `sourceAbsenceRecorded = true` (line 180), returns `.absent` (line 203).

#### MonaRenderTileCache.swift — **REAL**
- **Implements**: Generation-keyed LRU tile cache bounded by max tile count and byte budget. Current-generation tiles never evicted.
- **Evidence**: `MonaRenderTileKey` (line 43) with generation/tileX/tileY/scale/subpixelPhase fields; LRU eviction logic in store/invalidate methods.

#### MonaRendererMetrics.swift — **REAL**
- **Implements**: Renderer-owned metrics instrumentation (layout-to-present, GPU frame time, surface footprint, missed presentation, energy).
- **Evidence**: Real metric definitions and measurement logic (lines 1-30+).

### Views/

#### MonaCodeEditorView.swift (1493 lines) — **REAL**
- **Implements**: The native `NSView` editor boundary composing all Phase 03-04 subsystems: rendering, input, transfer, AX, widgets, lifetime.
- **Status**: REAL — `draw`, `keyDown`, `mouseDown/Dragged/Up`, `scrollWheel`, `rightMouseDown`, `mouseMoved/Exited`, `flagsChanged`, `updateTrackingAreas`, `resetCursorRects`, responder-chain, AX overrides, `NSTextInputClient` conformance all implemented.
- **Key evidence**:
  - `draw(_:)` at line 704: real visible-line tile rendering — computes visible range from scroll+viewport (line 717-718), publishes generation (line 719), partitions lines into tiles (line 738-756), calls `cgRenderer.tile(...)` (line 766), composites via `ctx.draw(img, in: dest)` with y-flip (line 777-782).
  - `keyDown(with:)` at line 835: real — translates event via `keyEventGateway.translateKeyDown` (line 838), delegates to `dispatchKeyEvent` (line 839).
  - `dispatchKeyEvent(_:source:)` at line 874: real 5-branch arbitration (dispatched/committedThenDispatched/passThrough/absorbedByComposition/noOp), calls `interpretKeyEvents([src])` for IME absorption (line 893).
  - `mouseDown(with:)` at line 937: real — resolves position via barrier (line 943-944), sets selection via low-level gateway (line 950-952), schedules redraw (line 959).
  - `mouseDragged(with:)` at line 968: real — extends selection from `downPosition` (line 979).
  - `mouseUp(with:)` at line 995: real — clears `downPosition`.
  - `scrollWheel(with:)` at line 1083: real — translates event, `requestScroll` + `converge` + conditional redraw + `publishGeneration` (lines 1089-1104).
  - `acceptsFirstResponder` at line 1202: `override public var acceptsFirstResponder: Bool { true }` — REAL.
  - `canBecomeKeyView` at line 1208: `{ true }` — REAL.
  - `becomeFirstResponder()` at line 1223: real — drives AX focus + posts `.focusedUIElementChanged` (line 1225).
  - `resignFirstResponder()` at line 1237: real — releases temporary focus + posts notification (line 1239).
  - AX overrides (lines 1262-1405): ~16 selectors — `accessibilityRole` (line 1262), `isAccessibilityElement` (line 1273), `accessibilityChildren` (line 1278), `accessibilityFocusedUIElement` (line 1293), `accessibilityParent` (line 1297), `accessibilityValue` (line 1303), `accessibilityNumberOfCharacters` (line 1309), `accessibilitySelectedTextRange` (line 1318), `accessibilityVisibleCharacterRange` (line 1326), `accessibilityAttributedString(for:)` (line 1333), `accessibilityRange(for:)` (line 1341), `accessibilityFrame(for:)` (line 1354), `accessibilityLine(for:)` (line 1360), `accessibilityRange(forLine:)` (line 1367), `accessibilityPerformAction` (line 1381). All delegate to `axElementGraph`/`axMutationGateway`.
  - `NSTextInputClient` conformance at line 1443: real — forwards all selectors to `textInputClient`. `insertText` at line 1483 forwards to client which routes to `commandDispatcher.execute("type", ...)`.
  - `makeFirstResponder`: NOT called in this file. Called only in `MonaEditorInstanceAdapters.swift:780` and `:1046` via `focus()`.
  - `scaleFactor` handling: `let scale = window?.backingScaleFactor ?? 1` at line 726 — read and passed to tile key (line 762), but bitmap not scaled (see MonaRenderSurface PARTIAL).
  - `wantsLayer = true` at line 322 (layer-backed rendering).
  - `isFlipped` at line 656: `{ true }` (y-down coordinate system).
  - `updateTrackingAreas()` at line 1144: real — removes stale areas, adds fresh `NSTrackingArea` with `[.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .enabledDuringMouseDrag]` (line 1154), converges scroll, publishes generation.
  - `resetCursorRects()` at line 1184: real — `addCursorRect(bounds, cursor: NSCursor.iBeam)` (line 1186).
  - `observeContentChange()` at line 587: real — republishes generation, pushes content dims to scroll model, converges, syncs AX selection, pumps AX announcements, schedules redraw (line 625).
  - `viewDidEndLiveResize()` at line 804: real — recomputes content dims, converges, publishes generation, redraws.

#### MonaDiffEditorView.swift — **REAL** (composition)
- **Implements**: `NSView` composing two `MonaCodeEditorView` sub-editors (original + modified) side-by-side over a shared `MonaDiffCoordinator`.
- **Evidence**: `init(frame:)` at line 64 constructs real sub-editors + coordinator; `commonInit()` at line 85 adds subviews + activates `NSLayoutConstraint`s; `attach(original:modified:)` at line 115 forwards to both sub-editors' `attach(model:)`; `detach()` at line 122 forwards to both.

#### MonaMultiDiffEditorView.swift — **REAL** (data consumer, no rendering)
- **Implements**: `NSView` that consumes ordered multi-diff snapshots from a `MonaMultiDiffDataSource`, subscribing to `onDidChangeSnapshot`.
- **Evidence**: `attach(dataSource:)` at line 86 records source, reads snapshot, subscribes to changes; `detach()` at line 102 disposes subscription. No subviews/layout for rendering items.

#### MonaEditorAttachment.swift — **REAL**
- **Implements**: `@MainActor` attachment helper that attaches/detaches a `MonaCodeModel` to/from the view, holding the model weakly and tracking every emitter subscription as a `MonaDisposable`.
- **Evidence**: `attach(model:)` at line 124 — sets weak model ref, calls `view?.performAttach(model:)`, subscribes to `onDidChangeContent` + `onWillDispose` via `@Sendable` closures with `MainActor.assumeIsolated` hop (lines 146-162); `detach()` at line 172 — disposes every disposable idempotently, calls `view?.performDetach()`, nils model.

#### MonaEditorFactory.swift — **REAL**
- **Implements**: `@MainActor` AppKit editor factory — `editor.create`/`createModel`/`getEditors`/`dispose`/`onDidCreateEditor`/`onWillDisposeModel` + diff/multi-diff construction.
- **Evidence**: `create(model:options:)` at line 168 constructs `MonaCodeEditorView`, attaches model, registers by id, fires emitter; `createModel(text:uri:)` at line 216 creates model, subscribes to `onWillDispose`, tracks weakly, fires emitter; `dispose(editor:)` at line 253 detaches + removes + fires; `createDiffEditor` at line 294 constructs + attaches; `createMultiFileDiffEditor` at line 312 constructs.

#### MonaEditorInstanceAdapters.swift — **PARTIAL**
- **Implements**: F1-R3 instance-interface surface (5 protocol declarations) + 2 concrete `@MainActor` adapters wrapping `MonaCodeEditorView` / `MonaDiffEditorView`.
- **Status**: PARTIAL — real for identity/lifetime/DOM/model/value/layout/focus; inert placeholders for events/position/selection/reveal/scroll/decorations/commands/diff-navigation.
- **Evidence (REAL)**:
  - `focus()` at line 779: `view.window?.makeFirstResponder(view)` — REAL (makeFirstResponder call #1).
  - `focus()` at line 1045: `view.window?.makeFirstResponder(view)` — REAL (makeFirstResponder call #2, diff adapter).
  - `hasTextFocus()` at line 782: `view.window?.firstResponder === view` — REAL.
  - `getModel()` at line 833: `view.attachment.attachedModel` — REAL.
  - `getValue()` at line 908: `view.attachment.attachedModel?.getValue() ?? ""` — REAL.
  - `dispose()` at line 768: `view.detach()` — REAL.
  - `layout()` at line 775: `needsLayout` + `layoutSubtreeIfNeeded()` — REAL.
- **Evidence (STUBS)**:
  - `getOption<T>(_)` at line 900: `fatalError(...)` — config storage not wired.
  - `onDidChange*`/`onDid*` events (lines 847-868): `monaInstanceInertEvent()` — subscribe returns inert disposable, never fires.
  - `reveal*`/`setPosition` (lines 796-828): empty `{}`.
  - `getSelection`/`setSelection*` (lines 809-815): `nil`/`[]` or empty.
  - `executeCommand`/`executeEdits` (lines 928-933): `false`.
  - Widget add/remove/layout (lines 960-977): empty.
  - Diff `getLineChanges()` at line 1124: `nil`.
  - Diff `goToDiff`/`revealFirstDiff` (lines 1127-1130): empty.

### Input/

#### MonaAppKeyEventGateway.swift — **REAL**
- **Implements**: Single native gateway translating AppKit `NSEvent` keyDown into platform-neutral `MonaKeyEvent` + applying `MonaKeyDispatchOutcome`.
- **Evidence**: `translateKeyDown(_:isComposing:)` at line 91 — calls `MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode:)`, `Self.monaModifiers(for:)`, `resolvedKeyText(...)`; constructs `MonaKeyEvent` (lines 99-106). `apply(_:)` at line 179 — real `MonaAppKeyDispatchOutcome` → `MonaAppKeyDispatchAction` projection.

#### MonaCompositionArbiter.swift — **REAL**
- **Implements**: Arbitration between keybinding resolution and IME composition through one `MonaCompositionSession` state machine.
- **Evidence**: `handleKey(_:context:)` at line 173 — 4-branch arbitration (disposed → `.noOp`; composition active + isComposing → `.absorbedByComposition`; composition active + command match → commit then `.committedThenDispatched`; no composition + match → `.dispatched`; no match → `.passThrough`).

#### MonaCompositionSession.swift — **REAL**
- **Implements**: IME composition session state machine (idle → composing → committing → committed, with disposal).
- **Evidence**: State phases at line 44-55; `updateMarkedText(...)` at line 196 — real transition with `precondition` guard; `commit(_:)` at line 231 — real `composing → committing → committed` transition; `cancel()` at line 253; `fold(committedText:markedText:...)` at line 279 — real commit-old-then-begin-new; `dispose()` at line 308.

#### MonaContextMenuGateway.swift — **REAL**
- **Implements**: Gateway building an `NSMenu` from the Core menu model and presenting it at a barrier-resolved position.
- **Evidence**: `buildItem(from:)` at line 155 — real `NSMenuItem` construction with title/keyEquivalent/state; `present(menu:at:in:with:)` at line 223 — `menu.popUp(positioning: nil, at: rect.origin, in: view)` at line 234.

#### MonaMacKeyCodeMap.swift — **REAL**
- **Implements**: Stateless bridge mapping macOS virtual key codes to Monaco's `MonaKeyCode`, preserving unmapped codes via `custom(_:)`.
- **Evidence**: `monaKeyCode(forMacKeyCode:)` at line 44 — dictionary lookup with `custom(macKeyCode)` fallback (line 51, no collapse to `.unknown`); `known` table at lines 62-201 with ~100 entries (Return/Tab/Space, arrows, F1-F20, A-Z, 0-9, punctuation, keypad, modifiers, media).

#### MonaPointerGateway.swift — **REAL**
- **Implements**: Gateway translating AppKit mouse `NSEvent`s into `MonaPointerEvent`s, resolving target position through the geometry barrier.
- **Evidence**: `translate(_:phase:viewportPoint:resolvingPositionThrough:)` at line 178 — calls `monaButton(for:)`, `monaModifiers(for:)`, `resolve(viewportPoint:through:)`; constructs `MonaPointerEvent` with clickCount/pressure/timestamp (lines 188-197). `resolve(viewportPoint:through:)` at line 235 — real barrier `hitTest` query, returns nil on `.unavailable`.

#### MonaScrollGateway.swift — **REAL**
- **Implements**: Gateway translating AppKit scrollWheel/magnify `NSEvent`s into `MonaScrollEvent`s, with delta normalization (precise /40, coarse verbatim) and phase projection.
- **Evidence**: `translate(_:viewportPoint:resolvingPositionThrough:)` at line 185 — per-`event.type` dispatch; `translateFields(...)` at line 265 — `divisor = hasPreciseScrollingDeltas ? 40 : 1` (line 277), `deltaX = Double(scrollingDeltaX) / divisor` (line 278), preserves positive direction; `monaPhase(for:)` at line 332 — real `NSEvent.Phase` → `MonaScrollPhase` mapping.

#### MonaTextInputClient.swift — **REAL** (one deferred sub-feature)
- **Implements**: `NSTextInputClient`-surface selectors (marked text, selection, insertion, attributed substring, first-rect, character-index) routing geometry through the barrier and insertion through an injected provider.
- **Status**: REAL — all selectors implemented. One deferred sub-feature: specific-range `insertText` (always inserts at current selection; specific-range handling deferred per line 227 comment).
- **Evidence**: `insertText(_:replacementRange:)` at line 233 — coerces to String, routes through `textInsertionProvider` (line 245). In the view (line 484-486), `textInsertionProvider` routes to `commandDispatcher?.execute("type", args: ["text": text])`. `setMarkedText` at line 166 — real state storage with `NSNotFound` anchor fallback. `markedRange` at line 193 — real UTF-16 code-unit-length derivation. `firstRect(forCharacterRange:actualRange:)` at line 289 — real barrier `caretRect(for:)` routing. `characterIndex(for:)` at line 317 — real barrier `hitTest` routing.

### Features/

All 23 files are **REAL**. Each has genuine functional logic in non-disposed methods (state mutations under locks, real data transformations, real registry/gateway/model interactions). The "no-op" comments throughout exclusively describe post-`dispose()` behavior (the normal idempotent-dispose pattern).

| File | One-line | Key evidence (file:line) |
|------|----------|--------------------------|
| MonaClipboardFeature.swift | Copy/cut/paste/copy-with-syntax-highlighting | `copy`/`cut`/`paste` through transferGateway + pasteEditPipeline (lines 173-228); `commitCopySelection` real transaction (lines 254-267) |
| MonaCodiconFeature.swift | Resolve Codicon icon identifiers to codepoints/characters/glyphs | `resolveCodicon`/`resolveGlyph` delegate to `MonaIconRegistry`/`MonaCodiconMap` (lines 142-162); `resolve(id:)` combines + fires (lines 168-175) |
| MonaColorPickerFeature.swift | Present/update/commit document-color provider results | `presentColors`/`updateColors` mutate `_presentedColors` + fire (lines 174-197); `commitColor` prepares edit ops (lines 218-229) |
| MonaContextmenuFeature.swift | Build native NSMenu editor context menu from menu registries | `buildContextMenu` calls `menuRegistry.buildModel` → `adaptMenuModel` → `gateway.buildMenu` (lines 195-206); `showContextMenu` calls `gateway.present` (lines 213-221) |
| MonaDiffEditorBreadcrumbsFeature.swift | Present multi-diff navigation breadcrumbs | `buildBreadcrumbs` projects metadata + marks active (lines 180-197); `navigate(toIndex:)` re-marks + fires (lines 203-225) |
| MonaDndFeature.swift | Register drag-and-drop behavior + commit/orchestrate drops | `commitDrop` inserts text via transaction (lines 156-173); `performDrop` runs 4-stage pipeline (lines 182-216) |
| MonaDropOrPasteIntoFeature.swift | Surface/select/apply explicit drop-or-paste proposals | `surfaceProposals` filters by kind (lines 195-201); `applyProposal` maps edits + commits (lines 221-234) |
| MonaFloatingMenuFeature.swift | Present retained floating action menu as native NSMenu | `buildFloatingMenu` creates NSMenu + items (lines 159-175); `presentFloatingMenu` calls `menu.popUp(positioning:at:in:)` (lines 184-199) |
| MonaFontZoomFeature.swift | Apply bounded editor font zoom + invalidate layout stamps | `applyZoom` clamps to `[minZoom, maxZoom]` + fires (lines 178-187); `invalidatedDomainsForZoomChange` delegates to stamp edge map (lines 156-158) |
| MonaGotoErrorFeature.swift | Navigate marker severities (next/prev with wrap-around) | `setDiagnostics` sorts by severity+position (lines 205-216); `navigate` modular wrap-around index math (lines 223-243) |
| MonaHoverFeature.swift | Merge/render/update verbosity of/release hover provider results | `mergeHovers` concatenates contents (lines 236-247); `renderHover` builds NSMutableAttributedString (lines 253-269); `increaseVerbosity`/`decreaseVerbosity` clamped (lines 291-311) |
| MonaInlineProgressFeature.swift | Render retained inline progress keyed by model version | `stageInlineProgress`/`updateInlineProgress` mutate `retainedByVersion` (lines 176-187, 230-241); `renderInlineProgress` builds attributed string (lines 200-212) |
| MonaLinksFeature.swift | Request/resolve/underline/activate/release document links | `requestLinks` calls `provider.provideLinks` + publishes (lines 195-210); `underlineLink` adds attributes (lines 236-253); `activateLink` commits selection (lines 261-274) |
| MonaMiddleScrollFeature.swift | Native middle-button scrolling with bounded velocity | `currentVelocity` computes `(anchor.y - point.y) * sensitivity` clamped (lines 181-191); `updateMiddleButtonScroll` calls `scrollModel.requestScroll` + `converge()` (lines 198-221) |
| MonaPlaceholderTextFeature.swift | Render native AppKit placeholder while model is empty | `evaluate` returns `model.getValueLength() == 0` (line 166); `attach` subscribes to `onDidChangeContent` + re-evaluates (lines 196-212); `commitInput` commits through gateway (lines 236-247) |
| MonaQuickCommandFeature.swift | Filter registered commands by query + invoke selected | `filterCommands` case-insensitive substring match over `registry.liveIdentities` (lines 161-186); `invokeCommand` re-checks enablement (lines 192-202) |
| MonaQuickHelpFeature.swift | Present retained keyboard + accessibility help | `keyboardHelp` maps over `MonaBuiltinKeybindings.rows` (lines 156-181); `formatKeyLabel`/`keyName` full key-code-to-name mapper (lines 301-363) |
| MonaQuickOutlineFeature.swift | Filter/group/navigate document symbols | `filterSymbols` recursive flatten with case-insensitive matching (lines 169-182, 307-327); `navigateToSymbol` commits selection (lines 209-220) |
| MonaReadOnlyMessageFeature.swift | Present localized feedback for rejected read-only mutations | `evaluateReadOnly` reads `readOnly` option (lines 146-149); `message` resolves custom or localized default (lines 155-183); `commitInput` rejects `.dropped` when read-only (lines 245-263) |
| MonaSectionHeadersFeature.swift | Derive/render MARK / `#region` section-header decorations | `deriveSectionHeaders` scans lines with `NSRegularExpression` for MARK + `hasPrefix("#region")` (lines 254-297); `presentation` builds attributed string (lines 303-338) |
| MonaStickyScrollFeature.swift | Project nested symbol + folding context onto sticky viewport rows | `projectStickyRows` walks symbol tree with `spans(range:viewportTopLine:)`, stops at folded ranges, caps to `maxLineCount` (lines 214-253); `presentation` renders rows (lines 267-306) |
| MonaToggleHighContrastFeature.swift | Toggle explicit high-contrast theme profile + invalidate paint | `toggleHighContrast` calls `themeRegistry.setTheme(target)` (lines 201-216); `invalidatePaintState(reason:)` fires (lines 226-229) |
| MonaToggleTabFocusModeFeature.swift | Switch Tab key between editor command and native focus traversal | `toggleTabFocusMode` flips `_tabMovesFocus` + fires (lines 157-165); `resolveTab` delegates to resolver or returns `.default` pass-through (lines 176-190) |

### Scaffold.swift — **STUB**
- 1-line comment: `// MonaCodeAppKit scaffold`.

### Layout/

All 14 files are **REAL** — no stubs, no fatalError, no "not yet" markers. The only "PLACEHOLDER" hits are in `MonaFailedLineRecord.swift`, where "placeholder" is the documented contract (failed lines reserve vertical space but publish zero glyph runs).

#### MonaQueryGeometryBarrier.swift — **REAL**
- **Implements**: Geometry-query gate answering hit-test/caret/range queries only from one complete projection generation, performing bounded per-line record completion (shapes + assembles on demand) and wrapping failures into typed `MonaGeometryUnavailable` reasons.
- **Evidence**: `publishGeneration(visibleViewLines:)` at line 271 — reads projection + verticalIndex, captures scroll offsets, resets record cache, pre-builds visible range; `hitTest(point:)` at line 311 — viewport→content conversion, clamping, `buildRecord` for bounded completion, delegates to `hitTester.hitTest(point:)`; `buildRecord(viewLine:projection:)` at line 438 — slices piece code units from model line (`Array(fullUnits[startIdx..<endIdx])`, line 475), calls `builder.build(codeUnits:pieceUnits, dependencyStamp:stamp)` in `do/catch` (lines 481-490), on catch inserts into `failedLines` and returns nil (no partial geometry on failure).

#### MonaLineLayoutBuilder.swift — **REAL**
- **Implements**: Assembler building immutable `MonaLineLayoutRecord`s from shaped text — either by shaping raw UTF-16 via the owned `MonaTextShaper` or by assembling a pre-shaped `MonaShapingResult`.
- **Evidence**: `build(from:sourceLength:...)` at line 114 — per-run advances via `run.advances.reduce(0) { $0 + $1.width }` (line 126), max ascent/descent/leading (lines 131-133), per-run baselines (line 136), bidi levels (line 139); `buildRawUnitBoundaries` at line 173 — real per-glyph x-extent computation, splits advance evenly across UTF-16 units (`perUnit = advWidth / CGFloat(unitCount)`, line 198), sorts boundaries by ascending `startX` for binary-search hit testing (lines 225-230).

#### MonaTextShaper.swift — **REAL**
- **Implements**: Sole typography authority — shapes raw UTF-16 `[UInt16]` lines via Core Text (`CTLine`/`CTRun`) with font cascade, base-direction forcing, scale, tab stops, isolated-surrogate handling, and provenance recording.
- **Evidence**: `shape(_:)` at line 152 — resolves cascade (line 164), detects isolated surrogates (line 177) and replaces with `0xFFFD` (line 179), prepends directional mark `0x200E`/`0x200F` (lines 185-189), creates `CFStringCreateWithCharacters` + `CFAttributedStringCreate` with `kCTFontAttributeName` (lines 193-207), calls `CTLineCreateWithAttributedString` (line 212), walks `CTLineGetGlyphRuns` (line 215); `extractRun` at line 280 — uses `CTRunGetGlyphs`, `CTRunGetPositions`, `CTRunGetAdvances`, `CTRunGetStringIndices`, `CTRunGetTypographicBounds` (lines 286-319); `applyTabStops` at line 448 — snaps tab advances to next tab stop `> cumX`.

#### MonaGlyphRun.swift — **REAL**
- **Implements**: Foundational Core Text shaping value types — `MonaFontDescriptor`, `MonaTextDirection`, `MonaTabStop`, and `MonaGlyphRun` (one shaped glyph run carrying glyph IDs, positions, advances, UTF-16 indices, font descriptor, metrics, RTL flag).
- **Evidence**: `MonaGlyphRun` at line 86 stores `glyphs: [CGGlyph]`, `positions: [CGPoint]`, `advances: [CGSize]`, `stringIndices: [Int]`, `sourceRange: Range<Int>`, `fontDescriptor`, `ascent`/`descent`/`leading`, `isRightToLeft` (lines 86-145); `font` computed property at line 150 re-derives a real `CTFont` via `CTFontDescriptorCreateWithAttributes` + `CTFontCreateWithFontDescriptor`.

#### MonaHitTester.swift — **REAL**
- **Implements**: Coordinate-conversion engine mapping viewport points to model positions and model positions/ranges to viewport-space caret/selection rects, consuming one frozen `MonaGeometrySnapshot`.
- **Evidence**: `hitTest(point:)` at line 80 — viewport→content conversion, bounds check, resolves view line via `snap.verticalIndex.viewLineAtVerticalOffset`, looks up record, calls `record.hitTest(offset:)`; `getCaretRect` at line 134 — collects view-line pieces, finds containing piece, clamps offset, resolves pixel x, returns real `CGRect`; `getRangeRects` at line 202 — iterates view lines in range span, computes column intersection, resolves pixel x-extents; `pixelX(for:in:)` at line 262 — linear scan over `rawUnitBoundaries` with edge clamping.

#### MonaScrollModel.swift — **REAL**
- **Implements**: Single source of scroll truth — separates requested/validated/published scroll positions, reconciling via frozen 4-step `converge()` order, producing scroll-dimension/frame dependency stamps.
- **Evidence**: `converge()` at line 270 — reads envelope (`maxScrollX = max(0, contentWidth - viewportWidth)`, line 243), clamps via `clampNonNegative` (line 278), assigns `validatedScrollX/Y` (step 3), assigns `publishedScrollX/Y` (step 4), bumps generation, emits `MonaScrollChangeEvent`; integer accessors at line 312 — `Int(...rounded(.towardZero))` truncation for V1-R3 `|0` rule; `scrollDimensionStamp`/`frameStamp` at lines 349-370 build real stamps.

#### MonaViewGraph.swift — **REAL**
- **Implements**: Projection layer between `MonaCodeModel` and renderer — projects model lines into view lines applying folding, hidden ranges, injected text, word wrapping, and view zones, maintaining vertical + view-zone indexes with generation contract.
- **Evidence**: `rebuild()` at line 212 — resolves hidden/folded line sets from `MonaRange`s (lines 217-233), groups injections (lines 236-239), builds view lines handling folded (collapses to one `isCollapsed` view line, lines 254-266), wrapped (`while startCol <= lineLen` loop splitting into pieces, lines 271-291), and single (lines 292-305) cases; rebuilds `MonaVerticalIndex` and `MonaViewZoneIndex` (lines 309-317) then advances generation (lines 323-324).

#### MonaVerticalIndex.swift — **REAL**
- **Implements**: Logarithmic prefix-height index over one projection's vertical layout, backed by a perfect-binary segment tree, answering `verticalOffsetForViewLine` and `viewLineAtVerticalOffset` in O(log n).
- **Evidence**: `init` at line 77 — builds segments, computes next power of two `s` (lines 98-100), constructs perfect-binary segment tree of size `2 * s` (lines 102-110); `prefixSum(upTo:)` at line 147 — iterative segment-tree prefix sum (`l & 1 != 0` / `r & 1 != 0` loop); `findContainingSegment` at line 171 — real tree descent.

#### MonaViewLine.swift — **REAL**
- **Implements**: Immutable view-line identity value type (`modelLineNumber`, `startColumn`, `isWrapped`, `injectionIds`, `isCollapsed`, `isVisible`).
- **Evidence**: Fully implemented value type with real stored fields + defaults in `init` (lines 40-82). Pure data struct consumed by `MonaViewGraph.rebuild`, `MonaHitTester`, `MonaQueryGeometryBarrier`.

#### MonaViewZoneIndex.swift — **REAL**
- **Implements**: Index over view zones of one projection generation — stores zones sorted by `afterLineNumber` with prefix-height array, answering `zones(afterLine:)` and `prefixHeight(beforeLineNumber:)` in O(log n).
- **Evidence**: `init` at line 69 — filters by visible lines, sorts by `afterLineNumber` then `id`, builds prefix-height array; `zones(afterLine:)` at line 89 — binary search + linear scan; `prefixHeight(beforeLineNumber:)` at line 103 — binary search; `firstIndexWhere` at line 123 — real binary search.

#### MonaLineLayoutRecord.swift — **REAL**
- **Implements**: Immutable frozen geometry of one shaped line + supporting value types (`MonaRawUnitBoundary`, `MonaInjectedTextSpan`, `MonaLineDecoration`, `MonaPaintInputs`).
- **Evidence**: Struct at line 229 stores all real fields (`glyphRuns`, `advances`, `baseline`, `rawUnitBoundaries`, `bidiLevels`, `paintInputs`, etc.); `totalWidth`/`lineHeight` computed at lines 318-325 (`advances.reduce(0, +)` and `ascent + descent + leading`); `hitTest(offset:)` at line 342 — real binary search over `rawUnitBoundaries` with midpoint snapping.

#### MonaFailedLineRecord.swift — **REAL**
- **Implements**: Immutable record for a line that failed to shape/construct, carrying typed failure reason, retry generation, and safe fallback height; intentionally publishes zero glyph runs.
- **Evidence**: `reason(for:)` at line 68 — real switch from `MonaTextShaperError` to `MonaFailedLineReason`; `init` at line 132 — `precondition(safeFallbackHeight > 0, ...)` guard; `glyphRunCount: Int { 0 }` at line 193 — documented contract (reserve vertical space, no partial glyph data).

#### MonaFontFallbackResolver.swift — **REAL**
- **Implements**: Deterministic primary→fallback font cascade resolver building `CTFont` instances, dropping silently-substituted fallbacks, offering code-point coverage lookup.
- **Evidence**: `resolveCascade()` at line 64 — `CTFontDescriptorCreateWithAttributes` + `CTFontCreateWithFontDescriptor` (lines 127-145), reads `CTFontCopyFamilyName`, filters by `caseInsensitiveCompare`; `font(_:coversCodePoint:)` at line 153 — `CTFontCopyCharacterSet` + `CFCharacterSetIsLongCharacterMember`.

#### MonaDependencyStamps.swift — **REAL**
- **Implements**: Seven immutable dependency-stamp value types + `MonaMutation` enum + frozen mutation→domain edge map with validation.
- **Evidence**: `frozenEdges` dictionary at lines 575-594 mapping all 17 mutation cases to `Set<MonaStampDomain>`; `invalidatedDomains(for:)`/`validate(mutation:claimedInvalidated:)` at lines 522-540 — real set subtraction.

### Accessibility/

#### MonaAXTextArea.swift — **REAL**
- **Implements**: Persistent native-text AX surface exposing value/selection/visible-range/attributed-substring/geometry-queries/line-mapping to macOS AX clients, reading raw UTF-16 truth from the model.
- **Evidence**: `value` getter at line 106 — builds `NSString` from `model.createSnapshot().units` via `NSString(characters:length:)` (line 292); `attributedSubstring(for:)` at line 135; `range(forPosition:)` at line 197 — routes through `barrier.hitTest`; `bounds(forRange:)` at line 219 — calls `barrier.rangeRects(for:)` and unions rects; `visibleRange` at line 164 — hit-tests viewport corners through barrier.

#### MonaAXElementGraph.swift — **REAL**
- **Implements**: AX element-graph root owning six role elements (editor, gutter, widget, link, diagnostic, proxy), parent→children relationships, viewport-recycle machinery preserving element identity.
- **Evidence**: init at line 467 — instantiates six role roots; wires parent→children at line 484; `element(for:)` at line 528 — lazily creates line-scoped elements keyed on `(role, line)` identity; `recycleViewport(backingViews:)` at line 566 — advances generation + swaps backing views preserving identity.

#### MonaAXMutationGateway.swift — **REAL**
- **Implements**: AX mutation gateway translating AX setter calls (set-value, set-selection, increment, decrement, press, custom) into Core input plans, routing through `MonaModelInputBarrier` after validating five preconditions.
- **Evidence**: `perform(_:)` at line 263 — validates focus/editability/model-version/range/generation, translates, then `barrier.prepare(plan)` + `barrier.commit(prepared, overlapPolicy: .reject)` (actual barrier invocation); `translate(_:model:)` at line 357 — maps each action to real `MonaMultiCursorInputPlan` with `MonaCursorInputEdit`.

#### MonaAXFocusCoordinator.swift — **REAL**
- **Implements**: AX focus state machine modeling five mutually-exclusive focus modes (editor, widget, accessibilityOptimized, tabFocus, temporary) with push/pop for temporary mode.
- **Evidence**: `transition(to:)` at line 95 — full push/pop state machine (entering `.temporary` saves `currentMode`; direct exit discards saved; idempotent on same-mode); `releaseTemporary()` at line 115 — restores `savedMode`, clears slot, returns restored mode.

#### MonaAXAnnouncementBridge.swift — **REAL**
- **Implements**: VoiceOver announcement bridge deduplicating + serializing announcement text, resolving each through N1 localization profile (never runtime system locale) with real localized message catalog.
- **Evidence**: `resolve(_:)` at line 138 — N1 lookup (profile-specific entry wins, then `"default"` fallback); `enqueue(_:)` at line 177 — resolves text, deduplicates against `lastAnnounced`; `nextAnnouncement()` at line 191 — pops FIFO queue; `defaultCatalog` at line 205 — real localized entries (`"zh-cn": "编辑器"`, `"ja": "エディター"`, etc.).

#### MonaAXDiagnosticElement.swift — **REAL**
- **Implements**: Diagnostic role element — squiggly-wave/marker AX element for errors/warnings/info/hints, reporting `group` AX role with severity as `AXValue` and message as `AXDescription`.
- **Evidence**: Subclasses `NSAccessibilityElement` at line 53; `accessibilityRole()` at line 99 returns `descriptor.accessibilityRole` (`.group`); `recycleBacking(to:generation:)` at line 89 — swaps weak backing view preserving identity.

#### MonaAXTextRangeMapper.swift — **REAL**
- **Implements**: Converts between AX integer ranges (`NSRange`) and raw model UTF-16 offsets / `MonaRange` with no surrogate repair; AX-to-model offset mapping is identity.
- **Evidence**: `monaRange(for:)` at line 59 — `model.getPositionAt` on raw UTF-16 offsets; `axRange(for:)` at line 75 — `model.getOffsetAt` on positions; identity conversions at lines 90-92, 97-99 (documented design, not stub).

#### MonaAXWidgetProxy.swift — **PARTIAL**
- **Implements**: Proxy role element (stand-in AX element for widgets without own backing view) + `MonaWidgetMouseTargetController` for widget mouse-target hit testing.
- **Status**: PARTIAL — `MonaAXWidgetProxy` is REAL; `MonaWidgetMouseTargetController.getTargetAtClientPoint` returns nil (documented placeholder).
- **Evidence (REAL)****: `MonaAXWidgetProxy` at line 37 — subclasses `NSAccessibilityElement`, implements `accessibilityRole()` (line 75), `attach(to:)` (line 62), `recycleBacking` (line 66).
- **Evidence (STUB)**: `MonaAXWidgetProxy.swift:116-122` — `getTargetAtClientPoint(_:)` returns `nil` with comment "Placeholder: the hit-test geometry is resolved by the driving layer."

### Host/

#### MonaAppKitHostAdapters.swift — **REAL**
- **Implements**: Three concrete macOS host adapters — `MonaAppKitLogSink` (lock-guarded ring buffer), `MonaAppKitLSPTransportFactory` (reuses `MonaProcessMessageTransport`), `MonaAppKitWorkspaceEditHost` (declines all external resource operations by contract).
- **Evidence**: `record(_:)` at line 58 — appends under `NSLock`, caps FIFO to `capacity`; `makeTransport` at line 122 — constructs real `MonaProcessMessageTransport`; `applyExternalOperation` at line 163 — throws `.workspaceAuthorityDeclined` (this IS the real contract — declining is the documented no-implicit-authority behavior).

#### MonaProcessMessageTransport.swift — **REAL**
- **Implements**: macOS host byte-transport adapter launching an explicitly-authorized process, bridging stdin/stdout to the transport-neutral Core `MonaMessageTransport` protocol, with background stdout read thread, partial-write loop, SIGPIPE ignore, and first-terminal-wins/dispose semantics.
- **Evidence**: init at line 135 — validates absolute paths, creates `Process`/`Pipe`, calls `process.run()`, wires `terminationHandler`; `send(_:)` at line 226 — partial-write loop using POSIX `write()` to stdin fd; `startReadLoopOnce()` at line 379 — spawns real `Thread` looping `fh.availableData`, calls `receive(chunk)` or `close()` on EOF; `signal(SIGPIPE, SIG_IGN)` at line 423 — installed once via `static let`.

### Transfer/

#### MonaPasteboardGateway.swift — **REAL**
- **Implements**: Single native gateway reading/writing the macOS pasteboard (`NSPasteboard`) for plain-text, rich-text (RTF round-trip), and custom MonaCode editor-metadata clipboard format.
- **Evidence**: `read()` at line 148 — reads plain via `pasteboard.string(forType:)`, rich via `readObjects`, metadata via JSON decode; `write(_:)` at line 163 — clears contents, publishes string/rtf/metadata types conditionally; `readRichText()` at line 193 — `pasteboard.readObjects(forClasses: [NSAttributedString.self])`; `writeRichText` at line 204 — RTF round-trip via `attributedString.rtf(from:documentAttributes:)`; metadata read/write at lines 234-246 via `JSONDecoder`/`JSONEncoder` under `com.monacode.editor-metadata` type.

#### MonaDragDropGateway.swift — **REAL**
- **Implements**: Native gateway handling drag and drop — drag-type validation, operation-mask masking, drop-geometry resolution through the geometry barrier, drop-edit provider chain, and transfer-payload reading via shared pasteboard gateway.
- **Evidence**: `accepts(dragTypes:)` at line 268; `validate(operation:)` at line 278 — returns `operation.intersection(acceptedOperations)`; `resolveDropGeometry` at line 291 — calls `geometryBarrier.hitTest(point:)`, stamps version + generation; `runDropEditProviders` at line 336 — provider chain with cancellation re-checks, validity-ticket gate; `readTransferPayload` at line 399 — validates drag types + operation, reads via real `MonaPasteboardGateway`.

#### MonaPasteEditPipeline.swift — **REAL**
- **Implements**: Runs direct paste-edit providers in deterministic order, then commits cut and multi-cursor paste through `MonaModelInputBarrier` as one atomic transaction.
- **Evidence**: `run(_:...)` at line 105 — provider chain with cancellation/ticket pre-checks; `commitMultiCursorPaste` at line 159 — builds `MonaMultiCursorInputPlan.replicateClipboardPaste(...)` and calls `barrier.commit(plan)`; `commitCut` at line 178 — builds deletion `MonaCursorInputEdit`s from selections and commits through barrier; `pasteThroughBarrier` at line 225 — runs providers, commits, maps outcome to `.applied`/`.dropped`/`.rolledBack`.

#### MonaServicesGateway.swift — **REAL**
- **Implements**: Thin adapter mapping macOS Services (NSPasteboard read/write selection) to the same transfer pipeline as copy/paste, forwarding to shared `MonaPasteboardGateway` and `MonaPasteEditPipeline`.
- **Evidence**: `readSelection()` at line 82 delegates to `pasteboardGateway.read()`; `writeSelection(_:)` at line 93 delegates to `pasteboardGateway.write(content)`; `runSelectionEditProviders` at line 112 delegates to `pipeline.run(...)`. Thin-forwarding is the documented contract, not a stub.

### Services/

#### MonaDialogService.swift — **REAL**
- **Implements**: Projects the four retained monaco-editor dialog call sites (unusualLine, workspaceUndo, undoConfirm, commandError) onto host-authorized native macOS `NSAlert` sheet/alert requests with a host-authorization gate that never fabricates acceptance.
- **Evidence**: `attachAuthorizedHost(_:)` at line 195 — sets `hostWindow` and `hostAuthorized = true`; `present(site:)` at line 244 — `guard let window = hostWindow, hostAuthorized else { return .unavailable }` (authorization gate); `nativePresent` at line 262 — configures real `NSAlert` (`alertStyle = .warning`, `addButton(withTitle:)`), calls `alert.runModal()`, maps `.alertFirstButtonReturn`→`.accepted`.

### Colorize/

#### MonaColorizeView.swift — **REAL**
- **Implements**: Native view-mutation replacement for Monaco's `editor.colorizeElement` — applies attributed token presentation to a frozen AppKit-native `MonaColorizeHost` (`NSTextStorage`), with incremental re-application of only changed token ranges on theme/token change.
- **Evidence**: `render(source:)` at line 174 — colorizes via `source.colorize(source:)`, replaces host `NSTextStorage` via `applyFullRender(attr)`, caches `lastUnits`/`lastTokens`/`lastTokenHex`; `reapplyChangedRanges()` at line 265 — diffs token hex colors against `lastTokenHex`, collects only changed ranges, applies in `beginEditing()`/`endEditing()` transaction; `attach()` at line 241 — subscribes to `themeRegistry.onDidChangeTheme` with `@Sendable` closure + `MainActor.assumeIsolated` hop.

#### MonaColorizeModelLine.swift — **REAL**
- **Implements**: Native layout-geometry colorizer for a single model line — projects tokens, injected text, bidi segments, and theme styling from an immutable `MonaLineLayoutRecord` into native runs (attributed text + `CGRect`), rejecting mixed model/layout generations.
- **Evidence**: `colorize(model:lineNumber:layoutRecord:layoutGeneration:)` at line 219 — stale-layout check (`guard modelVersion == layoutGeneration else { throw .staleLayout(...) }`, lines 232-238), fetches raw UTF-16 units (line 243), calls `colorizeSource.colorize(source: lineUnits)` (line 252), builds `MonaColorizeLineRun` per glyph run with real geometry (lines 260-301), projects `injectedTextSpans` to line-relative rects (lines 308-321).

#### MonaColorizeSource.swift — **REAL**
- **Implements**: Native attributed-text replacement for Monaco's `editor.colorize` API — produces an `NSAttributedString` with per-token `.foregroundColor` attributes resolved from the active theme, built directly from raw UTF-16 units.
- **Evidence**: `colorize(source:)` at line 140 — builds `NSString` from raw units via `NSString(characters:length:)` (line 210), resolves tokens (or `[]` when no provider — plain-text fallback), applies foreground colors per token range via `addAttribute(.foregroundColor,...)` (lines 168-173); `nsColor(fromHex:)` at line 220 — parses 6-digit hex to `NSColor(srgbRed:green:blue:alpha:)`.

### Generated/

#### MonaAppKitPublicAPI.swift — **STUB**
- **Implements**: GENERATED declaration graph — 12 retained native Swift declarations + 3 explicit UNAVAILABLE cut dispositions mapping the F1-R4 public declaration manifest to AppKit-adapted Swift shapes. All declaration bodies are empty by design (manifest-emitted shapes, not functional logic).
- **Evidence**: `public func monaEditorCreate() async throws {}` at line 43 (empty body); `public func monaEditorCreateDiffEditor() async throws {}` at line 58 (empty body); 10+ empty/near-empty protocols (lines 74-239); `_MonaAppKitBoundary` at line 287 — just `typealias View = NSView` compile-anchor. Header at line 1: "GENERATED FILE — do not edit by hand."

---

## MonaCodeSwiftUI

#### MonaCodeEditor.swift — **REAL**
- **Implements**: SwiftUI→AppKit bridge (`MonaCodeEditor: NSViewRepresentable`) wrapping `MonaCodeEditorView`, with `MonaCodeEditorOptions` and `MonaCodeEditorFocusRequest` declared-state value types.
- **Evidence**: `public struct MonaCodeEditor: NSViewRepresentable` at line 88; `makeNSView(context:)` at line 131 calls `controller.makeEditorView(frame:)`; `updateNSView(_:context:)` at line 141 calls `controller.applyDeclaredChanges(...)`.

#### MonaDiffEditor.swift — **REAL**
- **Implements**: SwiftUI→AppKit bridge (`MonaDiffEditor: NSViewRepresentable`) wrapping `MonaDiffEditorView` + owning `MonaDiffEditorController`.
- **Evidence**: `public struct MonaDiffEditor: NSViewRepresentable` at line 157; `makeNSView` at line 181; `makeDiffView(frame:)` at lines 101-112 instantiates `MonaDiffEditorView` and calls `view.attach(original:modified:)`.

#### MonaMultiDiffEditor.swift — **REAL**
- **Implements**: SwiftUI→AppKit bridge (`MonaMultiDiffEditor: NSViewRepresentable`) wrapping `MonaMultiDiffEditorView` + owning `MonaMultiDiffEditorController`.
- **Evidence**: `public struct MonaMultiDiffEditor: NSViewRepresentable` at line 141; `makeNSView` at line 167; `makeMultiDiffView(frame:)` at lines 89-100 instantiates view and calls `view.attach(dataSource:)`.

#### MonaSwiftUIEditorController.swift — **REAL**
- **Implements**: Explicit controller owning `MonaCodeModel` + `MonaCodeEditorView` attachment with stable identity across SwiftUI re-renders.
- **Evidence**: `public final class MonaSwiftUIEditorController` at line 46; `makeEditorView(frame:)` at line 94 instantiates `MonaCodeEditorView` and calls `view.attach(model:)` (line 102); `applyDeclaredChanges(...)` at line 122 records options/focus + re-attaches on model change (lines 135-147). **Does NOT call `makeFirstResponder`** — focus is recorded only, delegated to AppKit.

#### Generated/MonaSwiftUIPublicAPI.swift — **STUB**
- Generated manifest recording 3 CUT transport-constructor paths as `UNAVAILABLE`. 0 production declarations. Only a compile-anchor `internal enum _MonaSwiftUIBoundary`.

#### Scaffold.swift — **STUB**
- 2-line placeholder: `// MonaCodeSwiftUI scaffold`.

---

## MonaCodeSample

#### main.swift — **REAL** (but missing `makeFirstResponder`)
- **Implements**: Windowed macOS sample app constructing `MonaCodeEditorView` via `MonaEditorFactory`, plus diff/multi-diff views and SwiftUI wrappers, displayed in an `NSWindow`.
- **Evidence**:
  - Model construction at line 36-39: real `MonaCodeModel(text:uri:)`.
  - Editor creation at line 45: `factory.create(model: model)` — real factory.
  - Diff view at line 62: `factory.createDiffEditor(original:modified:options:)`.
  - Multi-diff view at line 65: `factory.createMultiFileDiffEditor(options:)`.
  - SwiftUI wrappers at lines 81-85, 107: `MonaDiffEditor`, `MonaMultiDiffEditor`, `MonaCodeEditor` with real controllers.
  - Window at line 93: real `NSWindow(contentRect:styleMask:backing:defer:)`.
  - `window.contentView = editor` at line 99.
  - `window.makeKeyAndOrderFront(nil)` at line 102.
  - `app.run()` at line 120.
  - **MISSING**: No `window.makeFirstResponder(editor)` or `window.setInitialFirstResponder(editor)` call. The editor view is never explicitly assigned as first responder. Keyboard input depends on AppKit's default responder-chain selection.
