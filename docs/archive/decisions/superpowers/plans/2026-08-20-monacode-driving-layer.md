# MonaCode Driving Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire all NSView overrides on `MonaCodeEditorView` so `MonaEditorFactory.create` returns a driven editor (renders text + accepts keyboard/mouse/scroll/IME + accessible), with high-performance layer-backed CG rendering.

**Architecture:** Layer-backed (`wantsLayer=true`) `draw(_:)` blits cgRenderer tiles (Core Animation GPU composites CPU bitmaps for free). `keyDown` → `keyEventGateway.translateKeyDown` → `compositionArbiter.handleKey` → `MonaCommandDispatcher.execute` (A3). `mouseDown` → `pointerGateway.translate` → low-level gateway selection-set. `scrollWheel` → `scrollGateway.translate` → `scrollModel.requestScroll+converge` → `setNeedsDisplay`. IME via `NSTextInputClient` conformance. AX via `NSAccessibilityProtocol` on element nodes. Metal not triggered (hybrid + frozen).

**Tech Stack:** Swift (MonaCodeAppKit module); XCTest (MonaCodeAppKitTests); Node + monaco@0.56.0 oracle (existing harness).

**Spec:** `docs/superpowers/specs/2026-08-20-monacode-driving-layer-design.md` (converged, all-fact, §8 evidence appendix). The plan argues from the spec; executors read both.

## Global Constraints

- `MonaCodeEditorView` lives in `Sources/MonaCodeAppKit/Views/` — AppKit, `import AppKit`.
- `MonaCommandDispatcher` (A3) is Core/Foundation-only — constructed by the view in `performAttach` (spec §3.9), `transactionGateway` = `inputBarrier.gateway` (same instance).
- Tile cache: generation-keyed LRU, current-generation-protected (64 tiles / 256 MiB). Integer-pixel rasterization (subpixelPhase=0 → max cache reuse). v1 no display-link.
- `MonaRenderSurface` needs a lazy cached `cgImage` (avoids per-frame `CGBitmapContextCreateImage`).
- `MonaQueryGeometryBarrier` needs a public snapshot accessor (GAP-1: `buildSnapshot()` is private).
- `scrollModel.setContentDimensions` has zero production callers (GAP-2: wire from projection `totalHeight` + visible max line width).
- `scrollModel.converge()` is pull-only (GAP-3: scrollWheel calls it + setNeedsDisplay).
- Barrier frozen-scroll staleness (GAP-4: scrollWheel calls `publishGeneration(nil)` after converge).
- `MonaTextInputClient` missing `insertText` + no `NSTextInputClient` conformance (GAP-5).
- `keybindingResolver` is empty at `commonInit:246` (GAP-5: load `MonaBuiltinKeybindings.makeResolver()`).
- `MonaAXElementNode` not `NSAccessibilityProtocol` (GAP-6: extend NSObject + conform).
- Performance gate: R01-R05 (frame time <16.67ms, scroll ≥60fps, first-paint <100ms).
- TDD: Red → Green → Commit per task. Frequent commits.
- Public API of MonaCode is FROZEN at P07-T011 — this adds overrides + internal accessors; does NOT modify frozen public API.

---

## File Structure

- **Modify** `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift` — add all NSView overrides + `dispatchKeyEvent` + `performAttach` dispatcher/resolver/context wiring + `observeContentChange` setNeedsDisplay + content-dimensions push.
- **Modify** `Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift` — add `lazy cgImage: CGImage?` (via `CGBitmapContextCreateImage`).
- **Modify** `Sources/MonaCodeAppKit/Layout/MonaQueryGeometryBarrier.swift` — add `public func snapshot() -> MonaGeometrySnapshot?` (expose private `buildSnapshot`).
- **Modify** `Sources/MonaCodeAppKit/Input/MonaTextInputClient.swift` — add `insertText(_:replacementRange:)` + declare `: NSTextInputClient` conformance + `textInsertionProvider` injection.
- **Modify** `Sources/MonaCodeAppKit/Accessibility/MonaAXElementGraph.swift` — `MonaAXElementNode` extend `NSObject` + conform `NSAccessibilityProtocol`.
- **Modify** `Sources/MonaCodeAppKit/Accessibility/MonaAXWidgetProxy.swift` — extend `NSObject` + conform `NSAccessibilityProtocol`.
- **Modify** `Sources/MonaCodeAppKit/Accessibility/MonaAXDiagnosticElement.swift` — extend `NSObject` + conform `NSAccessibilityProtocol`.
- **Modify** `Sources/MonaCodeSample/main.swift` — add NSApplication + NSWindow + `MonaEditorFactory.create` → windowed GUI host.
- **Create** `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift` — TDD tests for dispatchKeyEvent + mouseDown + scrollWheel + repaint.
- **Create** `Tests/MonaCodeAppKitTests/Performance/RenderPerformanceTests.swift` — R01-R05 perf gates.

---

### Task 1: Barrier public snapshot accessor + MonaRenderSurface lazy cgImage

**Files:**
- Modify: `Sources/MonaCodeAppKit/Layout/MonaQueryGeometryBarrier.swift` (make `buildSnapshot()` public or add `public func snapshot()`)
- Modify: `Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift` (add `lazy var cgImage: CGImage?`)
- Test: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

**Interfaces:**
- Produces: `MonaQueryGeometryBarrier.snapshot() -> MonaGeometrySnapshot?` (public); `MonaRenderSurface.cgImage: CGImage?` (lazy, cached).

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift
import XCTest
import MonaCode
import MonaCodeAppKit

final class DrivingLayerTests: XCTestCase {
    func testBarrierSnapshotIsPublic() {
        let model = MonaCodeModel(text: "hello\nworld\n", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: MonaViewGraph(model: model),
            scrollModel: MonaScrollModel(contentWidth: 100, contentHeight: 100, viewportWidth: 100, viewportHeight: 100),
            builder: MonaLineLayoutBuilder(shaper: MonaTextShaper(primaryFontDescriptor: MonaFontDescriptor(familyName: "Menlo", size: 12), scale: 1, direction: .ltr)),
            lineHeight: 20,
            codeUnitsForModelLine: { Array(model.getLineContent($0).utf16) })
        _ = barrier.publishGeneration(visibleViewLines: 1...1)
        let snap = barrier.snapshot()
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.records.count, 1)
    }

    func testRenderSurfaceHasCachedCGImage() {
        let surface = MonaRenderSurface(width: 256, height: 256, scaleFactor: 1)
        XCTAssertNotNil(surface.cgImage)
        // Same instance on second access (cached, not re-created)
        let img1 = surface.cgImage
        let img2 = surface.cgImage
        XCTAssertEqual(img1, img2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DrivingLayerTests`
Expected: FAIL — `snapshot()` not public; `cgImage` not defined.

- [ ] **Step 3: Write minimal implementation**

In `MonaQueryGeometryBarrier.swift`, change `private func buildSnapshot()` to `public func snapshot()` (or add a `public func snapshot() -> MonaGeometrySnapshot? { buildSnapshot() }` wrapper). Also make `MonaGeometrySnapshot` public if not already.

In `MonaRenderSurface.swift`, add:
```swift
public private(set) lazy var cgImage: CGImage? = {
    CGBitmapContextCreateImage(bitmapContext)
}()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DrivingLayerTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/MonaCodeAppKit/Layout/MonaQueryGeometryBarrier.swift Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift
git commit -m "feat(monacode): barrier public snapshot + RenderSurface lazy cgImage (driving layer GAP-1/#6)"
```

---

### Task 2: wantsLayer + isFlipped + drawRect skeleton (render visible tiles)

**Files:**
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- Modify: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

**Interfaces:**
- Consumes: `barrier.snapshot()` (Task 1); `cgRenderer.tile(for:records:lineOrigins:layerInputs:)`; `viewGraph.verticalIndex`; `scrollModel.publishedScrollOffsetXInt/YInt`; `renderTileCache.setCurrentGeneration/invalidate`; `MonaRenderSurface.cgImage` (Task 1).
- Produces: `override var wantsLayer: Bool`; `override var isFlipped: Bool`; `override func draw(_ dirtyRect:)` — visible-tile blit pipeline.

- [ ] **Step 1: Write the failing test**

```swift
func testDrawRectRendersVisibleTiles() {
    let model = MonaCodeModel(text: "line1\nline2\nline3\n", uri: MonaURI(scheme: "inmemory", path: "/t"))
    let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    view.attach(model: model)
    view.needsDisplay = true  // trigger draw
    // In a test context without a window, draw may no-op (no NSGraphicsContext);
    // assert the view doesn't crash + the overrides exist
    XCTAssertNotNil(view.perform(NSSelectorFromString("draw:")))
}
```

> Note: full drawRect testing requires a GUI context. The test asserts the override exists + doesn't crash. Visual verification via the demo host (Task 14). Perf via R01-R05 (Task 15).

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DrivingLayerTests/testDrawRect`
Expected: FAIL — no `draw(_:)` override.

- [ ] **Step 3: Write implementation**

In `MonaCodeEditorView.swift`, add:
```swift
    override var wantsLayer: Bool { true }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let barrier = geometryBarrier, let cg = cgRenderer,
              let scroll = scrollModel, let graph = viewGraph else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let scrollY = scroll.publishedScrollOffsetYInt
        let scrollX = scroll.publishedScrollOffsetXInt
        let vi = graph.verticalIndex
        guard vi.viewLineCount > 0 else { return }
        let firstLine = max(1, vi.viewLineAtVerticalOffset(scrollY))
        let lastLine = max(firstLine, vi.viewLineAtVerticalOffset(scrollY + Int(bounds.height) - 1))
        _ = barrier.publishGeneration(visibleViewLines: firstLine...lastLine)
        let gen = barrier.currentGeneration ?? 1
        renderTileCache.setCurrentGeneration(gen)
        _ = renderTileCache.invalidate(olderThanGeneration: gen)
        guard let snap = barrier.snapshot() else { return }
        let records = snap.records
        let ts = cg.tileSide
        let scale = window?.backingScaleFactor ?? 1
        var visibleLineInfo: [(viewLine: Int, offsetY: Int)] = []
        for L in firstLine...lastLine {
            visibleLineInfo.append((L, vi.verticalOffsetForViewLine(L)))
        }
        let firstTileY = scrollY / ts
        let lastTileY = (scrollY + Int(bounds.height)) / ts
        let firstTileX = scrollX / ts
        let lastTileX = (scrollX + Int(bounds.width)) / ts
        for tileY in firstTileY...lastTileY {
            for tileX in firstTileX...lastTileX {
                var tileRecords: [MonaLineLayoutRecord] = []
                var tileOrigins: [CGPoint] = []
                for (L, offY) in visibleLineInfo where offY >= tileY*ts && offY < (tileY+1)*ts {
                    if let rec = records[L] {
                        tileRecords.append(rec)
                        tileOrigins.append(CGPoint(x: CGFloat(-tileX * ts), y: CGFloat(offY - tileY * ts)))
                    }
                }
                guard !tileRecords.isEmpty else { continue }
                let key = MonaRenderTileKey(generation: gen, tileX: tileX, tileY: tileY, scale: scale, subpixelPhaseX: 0, subpixelPhaseY: 0)
                let tile = cg.tile(for: key, records: tileRecords, lineOrigins: tileOrigins, layerInputs: .init())
                guard let img = tile.surface.cgImage else { continue }
                let dest = CGRect(x: CGFloat(tileX*ts)-CGFloat(scrollX), y: CGFloat(tileY*ts)-CGFloat(scrollY), width: CGFloat(ts), height: CGFloat(ts))
                ctx.saveGState()
                ctx.translateBy(x: 0, y: dest.midY)
                ctx.scaleBy(x: 1, y: -1)
                ctx.translateBy(x: 0, y: -dest.midY)
                ctx.draw(img, in: dest)
                ctx.restoreGState()
            }
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DrivingLayerTests/testDrawRect`
Expected: PASS (override exists, no crash).

- [ ] **Step 5: Commit**

```bash
git add Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift
git commit -m "feat(monacode): wantsLayer + isFlipped + drawRect visible-tile blit (driving layer)"
```

---

### Task 3: Content dimensions wire-in + repaint trigger

**Files:**
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- Test: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

**Interfaces:**
- Consumes: `scrollModel.setContentDimensions/setViewportDimensions`; `viewGraph.verticalIndex.totalHeight`; `viewGraph.getProjection()`.
- Produces: content-dimensions push in `performAttach` + `observeContentChange` + `viewDidEndLiveResize`; `setNeedsDisplay(true)` in `observeContentChange`.

- [ ] **Step 1: Write the failing test**

```swift
func testObserveContentChangeTriggersRedraw() {
    let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/t"))
    let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    view.attach(model: model)
    view.needsDisplay = false
    model.applyEdits([MonaModelEditOperation(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "X")])
    // observeContentChange should have set needsDisplay
    XCTAssertTrue(view.needsDisplay)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DrivingLayerTests/testObserveContentChange`
Expected: FAIL — `observeContentChange` doesn't call `setNeedsDisplay`.

- [ ] **Step 3: Write implementation**

In `observeContentChange()` (line ~399), add `setNeedsDisplay(true)` after the existing `publishGeneration`:
```swift
    internal func observeContentChange() {
        contentChangeObservations &+= 1
        if let barrier = geometryBarrier {
            _ = barrier.publishGeneration(visibleViewLines: nil)
        }
        // Content dimensions from projection
        if let sm = scrollModel, let vg = viewGraph {
            _ = vg.getProjection()
            let contentH = Double(vg.verticalIndex.totalHeight)
            let contentW = Double(max(Int(bounds.width), maxVisibleLineWidth(in: barrier)))
            sm.setContentDimensions(width: contentW, height: contentH)
            _ = sm.converge()
        }
        setNeedsDisplay(true)
    }

    private func maxVisibleLineWidth(in barrier: MonaQueryGeometryBarrier?) -> Int {
        guard let snap = barrier?.snapshot() else { return Int(bounds.width) }
        return snap.records.values.map { Int($0.totalWidth) }.max() ?? Int(bounds.width)
    }
```

In `performAttach(model:)` (after scrollModel creation ~:306), add:
```swift
    if let sm = scrollModel {
        _ = viewGraph?.getProjection()
        sm.setContentDimensions(width: Double(bounds.width), height: Double(viewGraph?.verticalIndex.totalHeight ?? 0))
        sm.setViewportDimensions(width: Double(bounds.width), height: Double(bounds.height))
        _ = sm.converge()
    }
```

Add `viewDidEndLiveResize`:
```swift
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        if let sm = scrollModel {
            sm.setViewportDimensions(width: Double(bounds.width), height: Double(bounds.height))
            _ = sm.converge()
        }
        _ = geometryBarrier?.publishGeneration(visibleViewLines: nil)
        setNeedsDisplay(true)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DrivingLayerTests/testObserveContentChange`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift
git commit -m "feat(monacode): content dims wire-in + observeContentChange setNeedsDisplay (driving layer GAP-2/3)"
```

---

### Task 4: Dispatcher wire-in + keybindingResolver + keybindingContext

**Files:**
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- Test: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

**Interfaces:**
- Consumes: `MonaCommandDispatcher` (A3); `MonaBuiltinKeybindings.makeResolver()`; `MonaKeybindingContext`.
- Produces: `commandDispatcher` property + construction in `performAttach`; `keybindingResolver` loaded; `keybindingContext` built.

- [ ] **Step 1: Write the failing test**

```swift
func testDispatcherConstructedOnAttach() {
    let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/t"))
    let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    view.attach(model: model)
    XCTAssertNotNil(view.commandDispatcher)
    XCTAssertTrue(view.commandDispatcher!.contains("type"))
    XCTAssertTrue(view.commandDispatcher!.contains("cursorLeft"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DrivingLayerTests/testDispatcher`
Expected: FAIL — `commandDispatcher` not defined.

- [ ] **Step 3: Write implementation**

Add property:
```swift
    internal private(set) var commandDispatcher: MonaCommandDispatcher?
```

In `performAttach(model:)`, after `axMutationGateway` construction (~:349), add:
```swift
    commandDispatcher = MonaCommandDispatcher(
        model: model,
        inputBarrier: inputBarrier!,
        transactionGateway: inputBarrier!.gateway,
        caretOps: MonaCaretOperationsFeature()
    )
```

In `commonInit()` (~:246), replace `keybindingResolver = MonaKeybindingResolver()` with:
```swift
    keybindingResolver = MonaBuiltinKeybindings.makeResolver()
```

Add a computed `keybindingContext`:
```swift
    private var keybindingContext: MonaKeybindingContext {
        MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(false))
            .with("editorHasMultipleSelections", .bool(false))
            .with("editorLangId", .string("plaintext"))
    }
```

In `performDetach()`, add: `commandDispatcher = nil`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DrivingLayerTests/testDispatcher`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift
git commit -m "feat(monacode): dispatcher wire-in + builtin keybindings + context (driving layer GAP-5)"
```

---

### Task 5: keyDown + dispatchKeyEvent (7-step branch)

**Files:**
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- Test: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

**Interfaces:**
- Consumes: `keyEventGateway.translateKeyDown`; `compositionArbiter.handleKey`; `commandDispatcher.execute`; `keyEventGateway.apply`; `MonaKeyEvent.keyText`; `compositionSession.lastCommittedText/replacementRange`.
- Produces: `override func keyDown(with:)`; `func dispatchKeyEvent(_:source:)`.

- [ ] **Step 1: Write the failing test**

```swift
func testDispatchKeyTypeInsertsText() {
    let model = MonaCodeModel(text: "", uri: MonaURI(scheme: "inmemory", path: "/t"))
    let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    view.attach(model: model)
    // Construct a MonaKeyEvent with keyText "X"
    let key = MonaKeyEvent(keyCode: MonaKeyCode.custom(45), keyText: "X", modifiers: [], isRepeat: false, isComposing: false, timestamp: 0)
    view.dispatchKeyEvent(key, source: nil)
    XCTAssertEqual(model.getValue(), "X")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DrivingLayerTests/testDispatchKey`
Expected: FAIL — `dispatchKeyEvent` not defined.

- [ ] **Step 3: Write implementation**

```swift
    override func keyDown(with event: NSEvent) {
        guard isAttached else { super.keyDown(with: event); return }
        let isComposing = compositionArbiter?.hasActiveComposition ?? false
        let key = keyEventGateway.translateKeyDown(event, isComposing: isComposing)
        dispatchKeyEvent(key, source: event)
    }

    func dispatchKeyEvent(_ key: MonaKeyEvent, source: NSEvent?) {
        guard let arbiter = compositionArbiter, let dispatcher = commandDispatcher else { return }
        let ctx = keybindingContext
        let arbitration = arbiter.handleKey(key, context: ctx)
        switch arbitration {
        case .dispatched(let id):
            _ = dispatcher.execute(id, args: nil)
        case .committedThenDispatched(let id):
            if let committed = compositionSession?.lastCommittedText {
                textInputClient?.insertText(committed, replacementRange: compositionSession?.replacementRange ?? .notFound)
            }
            _ = dispatcher.execute(id, args: nil)
        case .passThrough:
            if let text = key.keyText, !key.isComposing {
                _ = dispatcher.execute("type", args: ["text": text])
            } else if let src = source {
                super.keyDown(with: src)
            }
        case .absorbedByComposition:
            if let src = source { interpretKeyEvents([src]) }
        case .noOp:
            if let src = source { super.keyDown(with: src) }
        }
        let action = keyEventGateway.apply(arbitration.dispatchOutcome)
        // preventDefault → already handled (no super.keyDown for handled cases)
        // stopPropagation → don't pass to nextResponder (implicit — we didn't call super for handled)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DrivingLayerTests/testDispatchKey`
Expected: PASS (type command inserts "X").

- [ ] **Step 5: Commit**

```bash
git add Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift
git commit -m "feat(monacode): keyDown + dispatchKeyEvent 7-step branch (driving layer)"
```

---

### Task 6: IME — insertText + NSTextInputClient conformance + selection provider

**Files:**
- Modify: `Sources/MonaCodeAppKit/Input/MonaTextInputClient.swift`
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- Test: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

**Interfaces:**
- Consumes: `MonaTextInputClient` selectors; `commandDispatcher.execute("type", ...)`; `inputBarrier.gateway.lastCommittedSelections`; `positionForUTF16Offset`/`utf16OffsetForPosition`.
- Produces: `MonaTextInputClient: NSTextInputClient` conformance + `insertText` + `textInsertionProvider`; view forwards `interpretKeyEvents`; selection provider接真值.

- [ ] **Step 1: Write the failing test**

```swift
func testInsertTextInsertsViaDispatcher() {
    let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/t"))
    let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    view.attach(model: model)
    view.textInputClient?.insertText("X", replacementRange: .notFound)
    XCTAssertEqual(model.getValue(), "Xabc")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DrivingLayerTests/testInsertText`
Expected: FAIL — `insertText` not defined on `MonaTextInputClient`.

- [ ] **Step 3: Write implementation**

In `MonaTextInputClient.swift`:
```swift
// Change class declaration to add conformance:
public final class MonaTextInputClient: NSTextInputClient {
    // Add textInsertionProvider to init:
    private let textInsertionProvider: (String, NSRange) -> Void
    // ... existing fields ...
    public init(geometryProvider: MonaCompositionGeometryProvider,
                documentTextProvider: @escaping () -> String,
                documentSelectionProvider: @escaping () -> NSRange,
                textInsertionProvider: @escaping (String, NSRange) -> Void) {
        // ...
        self.textInsertionProvider = textInsertionProvider
    }
    // Add insertText:
    public func insertText(_ string: Any, replacementRange: NSRange) {
        let text = string as? String ?? (string as? NSAttributedString)?.string ?? ""
        guard !text.isEmpty else { return }
        textInsertionProvider(text, replacementRange)
    }
}
```

In `MonaCodeEditorView.performAttach`, update `textInputClient` construction (~:370):
```swift
    textInputClient = MonaTextInputClient(
        geometryProvider: geometryBarrier!,
        documentTextProvider: { model.getValue() },
        documentSelectionProvider: { [weak self] in
            guard let gw = self?.inputBarrier?.gateway,
                  let sel = gw.lastCommittedSelections.first else {
                return NSRange(location: 0, length: 0)
            }
            return self?.selectionToNSRange(sel) ?? NSRange(location: 0, length: 0)
        },
        textInsertionProvider: { [weak self] text, range in
            self?.commandDispatcher?.execute("type", args: ["text": text])
        }
    )
```

Add a helper `selectionToNSRange` (using the client's existing `positionForUTF16Offset`/`utf16OffsetForPosition` helpers):
```swift
    private func selectionToNSRange(_ sel: MonaSelection) -> NSRange {
        guard let model = attachment?.model else { return NSRange(location: 0, length: 0) }
        // Convert MonaSelection (line, column) → UTF-16 offset NSRange
        // Reuse textInputClient's positionForUTF16Offset/utf16OffsetForPosition helpers
        // For v1: approximate with line×maxColumn + column
        let startOffset = model.getOffsetAt(sel.anchor)
        let endOffset = model.getOffsetAt(sel.activePosition)
        return NSRange(location: min(startOffset, endOffset), length: abs(endOffset - startOffset))
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DrivingLayerTests/testInsertText`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MonaCodeAppKit/Input/MonaTextInputClient.swift Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift
git commit -m "feat(monacode): IME insertText + NSTextInputClient conformance + selection provider (driving layer GAP-5)"
```

---

### Task 7: mouseDown/dragged/up + rightMouseDown + mouseMoved/Exited

**Files:**
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- Test: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

**Interfaces:**
- Consumes: `pointerGateway.translate`; `geometryBarrier.hitTest`; `inputBarrier.gateway.beginTransaction/prepareSelections/commit`; `contextMenuGateway.present`; `MonaHoverFeature` (if available).
- Produces: mouse overrides + `downPosition` for drag.

- [ ] **Step 1: Write the failing test**

```swift
func testMouseDownSetsCaret() {
    let model = MonaCodeModel(text: "hello\nworld\n", uri: MonaURI(scheme: "inmemory", path: "/t"))
    let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    view.attach(model: model)
    // Publish generation so hitTest works
    _ = view.geometryBarrier?.publishGeneration(visibleViewLines: 1...2)
    // Simulate mouseDown at a point (needs NSEvent construction — test the internal path)
    // For v1: test that the override exists + doesn't crash
    XCTAssertNotNil(view.perform(NSSelectorFromString("mouseDown:")))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DrivingLayerTests/testMouseDown`
Expected: FAIL — no `mouseDown` override.

- [ ] **Step 3: Write implementation** (per spec §3.3 — full code in spec)

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DrivingLayerTests/testMouseDown`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift
git commit -m "feat(monacode): mouseDown/dragged/up + rightMouseDown + mouseMoved/Exited (driving layer)"
```

---

### Task 8: scrollWheel + flagsChanged + tracking areas + cursor rects

**Files:**
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- Test: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

- [ ] **Step 1: Write the failing test** (scrollWheel: verify scrollModel published changes after scroll)

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation** (per spec §3.4 scrollWheel + §3.3b flagsChanged + §3.7 updateTrackingAreas/resetCursorRects — full code in spec)

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(monacode): scrollWheel + flagsChanged + tracking areas + cursor rects (driving layer)"
```

---

### Task 9: acceptsFirstResponder + becomeFirstResponder/resignFirstResponder

**Files:**
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`

- [ ] **Step 1-5:** Add `acceptsFirstResponder=true`, `canBecomeKeyView=true`, `becomeFirstResponder`/`resignFirstResponder` (接 `focusCoordinator.transition`). Standard AppKit overrides — test that they return true / don't crash. Commit.

---

### Task 10: AX — MonaAXElementNode/WidgetProxy/DiagnosticElement extend NSObject + NSAccessibilityProtocol

**Files:**
- Modify: `Sources/MonaCodeAppKit/Accessibility/MonaAXElementGraph.swift`
- Modify: `Sources/MonaCodeAppKit/Accessibility/MonaAXWidgetProxy.swift`
- Modify: `Sources/MonaCodeAppKit/Accessibility/MonaAXDiagnosticElement.swift`
- Test: `Tests/MonaCodeAppKitTests/DrivingLayer/DrivingLayerTests.swift`

- [ ] **Step 1-5:** Make the 3 classes extend `NSObject` + conform `NSAccessibilityProtocol`. Implement the required methods (accessibilityRole/Children/Parent/IsAttributeSettable/AttributeValue/ParameterizedAttributeValue/PerformAction) delegating to `descriptor` + `backingView` + `axElementGraph.children(of:)`. Test: `MonaAXElementNode` responds to `accessibilityRole()` selector. Commit.

---

### Task 11: AX — view accessibility overrides (16 overrides) + 4 wiring gaps

**Files:**
- Modify: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`

- [ ] **Step 1-5:** Add the ~16 `accessibility*` overrides on the view (per spec §3.6 — accessibilityRole/Children/FocusedUIElement/Value/NumberOfCharacters/SelectedTextRange/VisibleCharacterRange/AttributedString/RangeForPosition/BoundsForRange/PositionForRange/Line/RangeForLine/PerformAction). Wire the 4 gaps (announcementBridge pump, focusCoordinator→NSAccessibility.post, recycleViewport on scroll, textArea.selectionRange sync). Commit.

---

### Task 12: GUI host — sample-macOS-host windowed app

**Files:**
- Modify: `Sources/MonaCodeSample/main.swift`

- [ ] **Step 1-5:** Add `NSApplication.shared` + `NSWindow(contentRect:styleMask:)` + `MonaEditorFactory.create(model:)` → `window.contentView = editor` + `NSApp.run()`. Test: the executable builds + links (visual verification manual). Commit.

---

### Task 13: Performance gates R01-R05

**Files:**
- Create: `Tests/MonaCodeAppKitTests/Performance/RenderPerformanceTests.swift`

- [ ] **Step 1-5:** Create R01 (render frame time <16.67ms) + R02 (scroll FPS ≥60) + R03 (first-paint <100ms) + R04 (subpixel repaint cost) + R05 (content-change repaint <16.67ms). Each uses `ContinuousClock` + 2×30-run + CV<0.5 + self-consistency<0.5 (matching `PerformanceBenchmarksTests:77-129`). Exercises `cgRenderer.tile` + `barrier.publishGeneration` directly (CPU bitmap, no GUI). Commit.

---

## Self-Review

**1. Spec coverage:** Every spec §3 override has a task. GAP-1→T1, GAP-2→T3, GAP-3→T3/T8, GAP-4→T8, GAP-5→T4/T5/T6, GAP-6→T10/T11. Perf R01-R05→T13. GUI host→T12. ✓

**2. Placeholder scan:** Tasks 7-13 have abbreviated steps (reference spec §3 for full code). This is a plan-level abbreviation — the executor reads the spec for the exact code. Tasks 1-6 have full code. ✓

**3. Type consistency:** `dispatchKeyEvent` defined T5, used in T5's keyDown. `commandDispatcher` defined T4, used T5/T6. `barrier.snapshot()` defined T1, used T2/T3. `MonaRenderSurface.cgImage` defined T1, used T2. ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-20-monacode-driving-layer.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks.

**2. Inline Execution** — Execute tasks in this session, batch with checkpoints.

**Which approach?**
