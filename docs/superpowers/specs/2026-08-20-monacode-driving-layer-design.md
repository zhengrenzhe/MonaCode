# MonaCode Driving Layer — Deep Design Spec

**日期**: 2026-08-20
**北极星**: `MonaEditorFactory.create(model:options:) -> MonaCodeEditorView`（:163）最终返回一个**被驱动的全功能代码编辑器**——消费者 `create → 放进 NSWindow → 它就是编辑器`。本 spec 是其第一段 driving layer（让 view 能画 + 能打字 + 能点选 + 能滚 + 能 IME + 可访问）。undo(B1a)/find(B1b)/decorations(B1d)/Monarch(B4) 是后续 feature 子项目。
**事实状态**: 5 路并行深核 agent 读完源码全 API + 数据流 + 瓶颈分析；全部 file:line 证据（§8）。无推测。内部技术决策全 Ruled（§2）。
**性能**: 最高优先级。瓶颈 = Core Text 栅格化；解法 = layer-backed CG + scroll quantize + 性能 gate R01-R05。

---

## 1. Ground truth

### 1.1 monaco（`vs/editor/browser/view/view.ts`，未 vendor；g4-r closure 文档释义）
- `View` 注册 DOM keydown/mousedown/mousemove/mouseup/wheel/compositionstart·update·end/contextmenu/focus/blur；dispatch 到 viewModel/controller；每帧 layout→paint。
- `type` 注册命令 + textarea 原生 input 双入口汇于 `viewModel.type`。
- 光标宿主 `CursorsController`；undo 在 `Model.EditStack`。

### 1.2 MonaCode（5 agent 深核，§8 全证据）
**全部协作者已建+已验证，但 `MonaCodeEditorView` 零 override（白板）。** A3 dispatcher 已完成（Core，commandId→edit/selection 执行半边，monaco 差分验证）。关键 gap（5 agent 共暴露）：
- **GAP-1**（render，load-bearing）：`MonaQueryGeometryBarrier` 的 `records` dict + `MonaGeometrySnapshot` 都是 **private**（`buildSnapshot()` private），且**无人计算 `lineOrigins`**（全仓 grep 只有参数声明）。drawRect 必须：①给 barrier 加 public snapshot accessor；②自己算 lineOrigins（`origin.y = verticalOffsetForViewLine(L) - scrollY`）。
- **GAP-2**（render+scroll）：`scrollModel.setContentDimensions` **零生产调用方**；view 用 bounds 占位（performAttach:301-306）从不更新。真源：contentHeight←`verticalIndex.totalHeight`(:63)；contentWidth←max 行像素宽（从 `rawUnitBoundaries` 算）。attach/content-change/resize 要推。
- **GAP-3**（scroll）：`scrollModel.converge()` 是 **pull-only**（无 emitter/onChange）；scrollWheel override 必须自己调 converge + 读返回 event + setNeedsDisplay。
- **GAP-4**（scroll，微妙顺序）：converge 移动 publishedScrollY 后，barrier 的冻结 scrollOffsetX/Y（publishGeneration:285-286 捕获）**过期**直到下次 publishGeneration。scrollWheel 必须 converge 后调 `publishGeneration(nil)` 刷新冻结 scroll，否则下次 mouseDown hit-test 用旧 scroll。
- **GAP-5**（keyboard）：`MonaTextInputClient` **缺 `insertText(_:replacementRange:)`**（NSTextInputClient 必需）+ 未声明 conformance。**两条 printable-key 路径冲突**（Core type 命令 vs AppKit interpretKeyEvents）；`.committedThenDispatched` 的 arbiter `session.commit` 只记生命周期**不改 model**——driving 层必须先插 committed text 再 dispatch。`keybindingResolver` 是**空的**（commonInit:246 无参数）——必须调 `MonaBuiltinKeybindings.makeResolver()`(:451) 加载 379 行。`MonaKeybindingContext` view **没建**——要从 editor state 构造。
- **GAP-6**（AX，load-bearing）：`MonaAXElementNode` **不是 NSView/NSObject/NSAccessibilityProtocol 派生**——是纯 `final class : MonaAXRoleElement`（AnyObject 协议）。macOS AXUIElement 不能直接遍历它。view 的 `accessibilityChildren` 必须返回 NSView 或 NSAccessibilityProtocol-conforming 对象 → **桥接设计决策**：(1) 让 `MonaAXRoleElement`+3 具体类 conform `NSAccessibilityProtocol`，或 (2) 每次 AX walk 包 adapter。view 需 **~16 个 accessibility override** + 4 个 wiring gap（announcementBridge pump / focusCoordinator→NSAccessibility.post / recycleViewport on scroll / textArea.selectionRange sync on cursor change）。

---

## 2. Architecture decision + Internal Rulings（消费者不关心，MonaCode 自裁；性能最高优先级）

**形态**：在 `MonaCodeEditorView` 上加 NSView override + 渲染管线 + 重绘触发 + AX 接线 + dispatcher 归属 + GUI 宿主。镜像 monaco `View`。

**Rulings**：
1. **绘制 = `wantsLayer=true`（layer-backed）+ `override func draw(_:)` blit** cgRenderer tile 位图进 CALayer backing。理由（perf agent 事实）：Core Animation 在 GPU 上免费合成 CPU 位图 → GPU 合成 + layer-scroll translation（CALayer.bounds.origin 移动已缓存 tile 无需 redraw）；比非-layer drawRect（CPU blit）快。Metal 路径是 hybrid（CG 栅格 + Metal overlay，非全 GPU）+ 冻结 notTriggered + 会加 texture upload + GPU→CPU readback → 反而更慢。**Metal v1 不触发**（3 条事实理由：hybrid 非全 GPU + 冻结契约 + layer-backed CG 更优）。
2. **帧节奏 = `setNeedsDisplay(true)`**（AppKit 自动 coalesce）v1；**display-link measure-first 延后**（仅 profiling 显滚动掉帧才加 CVDisplayLink）。帧预算 16.67ms @60Hz / 8.33ms @120Hz（`DisplayModeEnforcer.deadline` :152-156）。
3. **坐标系 = `override var isFlipped: Bool { true }`**（view y-down 对齐 AppKit 文本布局）。tile 内部 y-up（MonaRenderSurface 左下原点 `:113-118`）；blit 用 `CGBitmapContextCreateImage(surface.bitmapContext)→CGImage→ctx.draw(img, in:destRect)` + y 翻转变换（`translateBy(x:0,y:dest.midY); scaleBy(x:1,y:-1); translateBy(x:0,y:-dest.midY)`）。
4. **scroll quantize**（缓解 subpixel cache thrash）：scroll 量化到整像素/tile 对齐（最大化 tile 缓存复用；subpixelPhase 在 key 中 `:61-64` → 分数 scroll 每相位新 tile → 缓存失效）。量化 residual 保存在 scrollModel Double（`:153-158`）。
5. **IME = view conform `NSTextInputClient`**（转发 `MonaTextInputClient`）。**补 `insertText(_:replacementRange:)`**（GAP-5）：route committed text 到 `commandDispatcher.execute("type", ["text": text])`（注入 `textInsertionProvider: (String, NSRange?) -> Void` 到 MonaTextInputClient.init）。`interpretKeyEvents([event])` 仅在 `.absorbedByComposition` 调用（IME 驱动时）；passThrough+printable 走 Core type 路径 + preventDefault（抑制 interpretKeyEvents 避免双插）。选区 provider 接 `inputBarrier.gateway.lastCommittedSelections`（非硬编码 (0,0)）。
6. **AX 桥接 = `MonaAXRoleElement` + 3 具体类 conform `NSAccessibilityProtocol`**（GAP-6 方案 1，低侵入，持久树）：实现 `accessibilityRole()`/`accessibilityChildren()`/`accessibilityParent()`/`accessibilityIsAttributeSettable(_:)`/`accessibilityAttributeValue(_:)`/`accessibilityParameterizedAttributeValue(_:for:)`/`accessibilityPerformAction(_:)` 委托 `descriptor` + `backingView` + `axElementGraph.children(of:)`。view 实现 ~16 个 `accessibility*` override 委托 `axElementGraph` + `axTextArea`。+ 4 wiring gap（announcementBridge pump → `NSAccessibility.post(.announcementRequested)` / focusCoordinator.transition → `NSAccessibility.post(.focusedWindowChanged)` + `accessibilityFocusedUIElement` / recycleViewport on scroll / textArea.selectionRange sync on cursor change）。
7. **dispatcher 接线 = `performAttach` 构造 `commandDispatcher`**（平级 axMutationGateway :343，依赖 model/inputBarrier/transactionGateway=inputBarrier.gateway/caretOps=MonaCaretOperationsFeature()），`performDetach` 释放。
8. **keyDown 分派 = 提取 `dispatchKeyEvent(_ keyEvent: MonaKeyEvent)` 可测内部**（7 步分支，§3.2）。
9. **keybindingResolver = `MonaBuiltinKeybindings.makeResolver()`**（加载 379 行内置键绑定，替换 commonInit:246 空 resolver）。
10. **keybindingContext = view 构造**（`editorTextFocus`/`editorReadonly` 等 from editor state）。
11. **性能 gate（R01-R05）**：渲染帧时间 <16.67ms / 滚动 ≥60fps / 首屏 <100ms / subpixel 重画量化 / content-change 重画 <16.67ms（§4）。

**性能杠杆（已在设计/已核）**：tile 缓存（generation-keyed LRU current-gen-protected 64 tiles/256MiB）；可见行-only record building（publishGeneration 只建可见行）；dirty-rect blit（只画脏 tile）；setNeedsDisplay coalesce；scroll quantize（避免 subpixel cache miss）；per-generation record caching（shaping 一次/代非一次/画）；O(log n) vertical lookups（MonaVerticalIndex segment tree）。
**瓶颈**（perf agent事实）：Core Text 栅格化——①`CTFontDrawGlyphs` per tile paint on scroll（新 tile → cache miss → 全 paint）；②`CTLineCreateWithAttributedString` per line on generation change（content 变 → 每可见行 reshaping；已按 generation 缓存缓解）；③subpixel scroll thrash（quantize 缓解）。projection/geometry/blit 不是瓶颈。

---

## 3. Design — per override

### 3.1 drawRect（渲染管线）
```
override func draw(_ dirtyRect: NSRect) {
    guard let barrier = geometryBarrier, let cg = cgRenderer, let scroll = scrollModel, let graph = viewGraph else { return }
    let ctx = NSGraphicsContext.current!.cgContext
    // 1. 可见行范围 via verticalIndex O(log n)
    let scrollY = scroll.publishedScrollOffsetYInt, scrollX = scroll.publishedScrollOffsetXInt
    let vi = graph.verticalIndex  // 冻结在 generation 中
    guard vi.viewLineCount > 0 else { return }
    let firstLine = max(1, vi.viewLineAtVerticalOffset(scrollY))
    let lastLine = max(firstLine, vi.viewLineAtVerticalOffset(scrollY + Int(bounds.height) - 1))
    // 2. publishGeneration（冻结一代 + 预建 visible records）
    _ = barrier.publishGeneration(visibleViewLines: firstLine...lastLine)
    let gen = barrier.currentGeneration ?? 1
    renderTileCache.setCurrentGeneration(gen); _ = renderTileCache.invalidate(olderThanGeneration: gen)
    // 3. GAP-1 解法：barrier 加 public accessor → 拿 snapshot 一次（per-drawRect，非 per-tile）
    //    buildSnapshot() 改 public（或加 public var snapshotRecords: [Int: MonaLineLayoutRecord]）
    let snapshot = barrier.snapshot()  // 新 public accessor（GAP-1 要加）；O(visible) per drawRect 一次
    let records = snapshot.records  // [Int: MonaLineLayoutRecord]（keyed by 1-based view-line）
    let vi = snapshot.verticalIndex  // MonaVerticalIndex（O(log n) segment tree）
    // 4. pre-compute 可见行 + verticalOffsets（O(visible × log n) 一次），按 tile y-band 分区
    let ts = cg.tileSide; let scale = window?.backingScaleFactor ?? 1
    var visibleLineInfo: [(viewLine: Int, offsetY: Int)] = []  // (viewLine, verticalOffsetForViewLine)
    for L in firstLine...lastLine { visibleLineInfo.append((L, vi.verticalOffsetForViewLine(L))) }
    // 5. per-tile: 按 y-band [tileY*ts, (tileY+1)*ts) 分区 visible 行 → records[] + lineOrigins[]
    for tileY in firstTileY...lastTileY { for tileX in firstTileX...lastTileX {
        // tile-local records + lineOrigins（paint 用 tile-local CG y-up 坐标）
        var tileRecords: [MonaLineLayoutRecord] = []; var tileOrigins: [CGPoint] = []
        for (L, offY) in visibleLineInfo where offY >= tileY*ts && offY < (tileY+1)*ts {
            if let rec = records[L] { tileRecords.append(rec); tileOrigins.append(
                // 正确公式（对抗 review #1 修正）：
                // origin.y = verticalOffset - tileY*tileSide（tile-local content-y，非 -scrollY）
                // origin.x = -tileX*tileSide（行起始 content-x=0 减 tile 原点；subpixel 由 renderer translateBy 处理）
                CGPoint(x: CGFloat(-tileX * ts), y: CGFloat(offY - tileY * ts))) }
        }
        guard !tileRecords.isEmpty else { continue }
        let key = MonaRenderTileKey(generation: gen, tileX: tileX, tileY: tileY, scale: scale,
            subpixelPhaseX: 0, subpixelPhaseY: 0)  // v1 整像素（Ruling 4/7：quantize → max cache reuse）
        let tile = cg.tile(for: key, records: tileRecords, lineOrigins: tileOrigins, layerInputs: .init())
        // blit（CGImage 从 surface 的 lazy cached cgImage 取——避免 per-frame CGBitmapContextCreateImage）
        guard let img = tile.surface.cgImage else { continue }  // 新 lazy cached（Ruling #6）
        let dest = CGRect(x: CGFloat(tileX*ts)-CGFloat(scrollX), y: CGFloat(tileY*ts)-CGFloat(scrollY), width: CGFloat(ts), height: CGFloat(ts))
        ctx.saveGState(); ctx.translateBy(x: 0, y: dest.midY); ctx.scaleBy(x: 1, y: -1); ctx.translateBy(x: 0, y: -dest.midY)
        ctx.draw(img, in: dest); ctx.restoreGState()
    }}
}
```
**GAP-1 解法**：`MonaQueryGeometryBarrier` 加 `public var snapshotRecords: [Int: MonaLineLayoutRecord]` (或 `public func snapshot() -> MonaGeometrySnapshot?`) 暴露 private `records`（或 `buildSnapshot()` 改 public）。这是 drawRect 的前提——barrier 有 records 但不暴露。

### 3.2 keyDown（键盘 7 步分支）
```
override func keyDown(with event: NSEvent) {
    guard isAttached else { super.keyDown(with: event); return }
    let isComposing = compositionArbiter.hasActiveComposition
    let key = keyEventGateway.translateKeyDown(event, isComposing: isComposing)
    dispatchKeyEvent(key, source: event)
}
func dispatchKeyEvent(_ key: MonaKeyEvent, source: NSEvent?) {
    let ctx = keybindingContext  // view 构造的 MonaKeybindingContext
    let arbitration = compositionArbiter.handleKey(key, context: ctx)
    switch arbitration {
    case .dispatched(let id):
        commandDispatcher.execute(id, args: nil)
    case .committedThenDispatched(let id):
        // GAP-5（#3 对抗修正）：arbiter 的 session.commit 只记生命周期不改 model
        // → 统一 insert path：调 textInputClient.insertText（textInsertionProvider）
        //   处理 session.replacementRange（NSNotFound→type at selection；specific→edit at range）
        if let committed = compositionSession.lastCommittedText {
            textInputClient.insertText(committed, replacementRange: compositionSession.replacementRange)
        }
        commandDispatcher.execute(id, args: nil)
    case .passThrough:
        // GAP-5：两条路径冲突——passThrough+printable 走 Core type 路径 + preventDefault
        if let text = key.keyText, !key.isComposing {
            commandDispatcher.execute("type", args: ["text": text])
        } else { super.keyDown(with: source!) }  // 非 printable（功能键等）→ super
    case .absorbedByComposition:
        // IME 拥有——调 interpretKeyEvents 让 inputContext 的 setMarkedText/insertText 触发
        interpretKeyEvents([source!])
    case .noOp:
        super.keyDown(with: source!)
    }
    let action = keyEventGateway.apply(arbitration.dispatchOutcome)
    // preventDefault=true → 不再 super.keyDown（已处理）；stopPropagation=true → 不传 nextResponder
}
```
**注**：`type` 的 text 从 `key.keyText`(:54)（passThrough 分支）；arbiter 的 `.dispatched(commandId:)` 不带 args(:65)。`MonaBuiltinKeybindings.makeResolver()`(:451) 替换空 resolver。`MonaKeybindingContext` view 构造（set `editorTextFocus=true`/`editorReadonly=false`）。

### 3.3 mouseDown/dragged/up + rightMouseDown + mouseEntered/Exited/moved + flagsChanged
```
override func mouseDown(with event: NSEvent) {
    guard isAttached, let gw = pointerGateway, let barrier = geometryBarrier else { return }
    let vp = convert(event.locationInWindow, from: nil)
    let pe = gw.translate(event, phase: .down, viewportPoint: vp, resolvingPositionThrough: barrier)
    guard let pos = pe.resolvedPosition else { return }  // nil = no generation / OOB → no-op
    // GAP-5 解法：pointer 设绝对 position → 用低层 gateway path（非 commitCaretMove 后者只相对移动）
    let sel = MonaSelection(anchor: pos, activePosition: pos)  // collapsed caret
    let tx = inputBarrier.gateway.beginTransaction()
    tx.prepareSelections([sel])
    _ = inputBarrier.gateway.commit(tx)  // → lastCommittedSelections = [sel]
    setNeedsDisplay(bounds)
    downPosition = pos  // for drag extension
}
override func mouseDragged(with event: NSEvent) {
    // ... translate(.dragged) → resolvedPosition → sel = MonaSelection(anchor: downPosition, activePosition: pos) → commit → setNeedsDisplay
}
// 右键上下文菜单
override func rightMouseDown(with event: NSEvent) {
    guard isAttached, let gw = pointerGateway, let barrier = geometryBarrier, let cmg = contextMenuGateway else { return }
    let vp = convert(event.locationInWindow, from: nil)
    let pe = gw.translate(event, phase: .down, viewportPoint: vp, resolvingPositionThrough: barrier)
    guard let pos = pe.resolvedPosition else { return }
    let menu = cmg.buildMenu(from: MonaAppMenuModel.builtin)  // 或从 BuiltinMenus
    _ = cmg.present(menu, at: pos, in: self, with: barrier)  // contextMenuGateway.present :223
}
// hover（MonaHoverFeature 已建，读 lastCommittedSelections :358）
override func mouseMoved(with event: NSEvent) {
    // translate(.moved) → resolvedPosition → MonaHoverFeature.hover(at: pos) → setNeedsDisplay (if hover region changed)
}
override func mouseExited(with event: NSEvent) {
    // MonaHoverFeature.clear() → setNeedsDisplay
}
// modifier-only 键（Shift/Cmd/Alt/Ctrl press/release）→ chord 重新评估
override func flagsChanged(with event: NSEvent) {
    guard isAttached else { super.flagsChanged(with: event); return }
    // modifier-only → 无 keyText → 无 type 命令；但可能影响 when-clause → chord 重新评估
    _ = keybindingResolver.reevaluateActiveChord(context: keybindingContext, chordState: chordState)  // :254
}
```
**注**：pointerGateway 是 stateless pure(:156)；`resolvedPosition` nil 时 no-op(:244-246)；选区经 `inputBarrier.gateway`（= `transactionGateway` 同一实例）。Shift+click/drag → 扩展选区。double-click → word select（需 B1c `getWordAtPosition`——桩，deferred）。rightMouseDown → contextMenuGateway.present(:223)。mouseMoved/Exited → MonaHoverFeature（已建:358）。flagsChanged → reevaluateActiveChord(:254)。tracking area（§3.7 updateTrackingAreas）喂 mouseMoved/Entered/Exited 事件。

### 3.4 scrollWheel（滚动）
```
override func scrollWheel(with event: NSEvent) {
    guard isAttached, let gw = scrollGateway, let sm = scrollModel, let barrier = geometryBarrier else { return }
    let vp = convert(event.locationInWindow, from: nil)
    let se = gw.translate(event, viewportPoint: vp, resolvingPositionThrough: barrier)
    // GAP-3：converge 是 pull-only——自己调
    sm.requestScroll(x: sm.publishedScrollX + se.deltaX, y: sm.publishedScrollY + se.deltaY)
    let evt = sm.converge()
    if evt.publishedScrollX != lastPublishedX || evt.publishedScrollY != lastPublishedY {
        setNeedsDisplay(bounds)  // 滚动 → 重画
    }
    // GAP-4：converge 后 barrier 冻结 scroll 过期 → 刷新
    _ = barrier.publishGeneration(visibleViewLines: nil)
}
```
**注**：scrollGateway 是 stateless pure(:153)；delta 归一 precise÷40 coarse 原样(:277-279)；方向不反(:249)；`MonaScrollChangeEvent` 结构(:57-113)；参考模式 `MonaMiddleScrollFeature.updateMiddleButtonScroll`(:198-221)（唯一生产 requestScroll+converge 调用方）。scroll quantize（Ruling 4）：量化 scrollX/Y 到整像素避免 subpixel cache miss。

### 3.5 IME（NSTextInputClient）
- view conform `NSTextInputClient`，selectors 委托 `MonaTextInputClient`（已有 8/9 selectors；缺 insertText）。
- **补 `insertText(_:replacementRange:)`** 到 MonaTextInputClient + 注入 `textInsertionProvider: (String, NSRange?) -> Void` → view 接 `{ [weak self] text, _ in self?.commandDispatcher.execute("type", ["text": text]) }`。
- `interpretKeyEvents([event])` 仅在 `.absorbedByComposition` 调（§3.2）——让 inputContext 的 setMarkedText/insertText 触发。passThrough+printable 走 Core type 路径 + preventDefault（抑制 interpretKeyEvents 避免双插）。
- 选区 provider 接 `inputBarrier.gateway.lastCommittedSelections`（替换 hardcoded (0,0) :373）；UTF-16 NSRange 从 MonaSelection 经 `positionForUTF16Offset`/`utf16OffsetForPosition`（MonaTextInputClient:313/340）转换。

### 3.6 AX（accessibility 桥接）
- **GAP-6 解法 1**（#4 对抗修正——明确结构性变更）：`MonaAXElementNode`/`MonaAXWidgetProxy`/`MonaAXDiagnosticElement` **extend `NSObject`** + conform `NSAccessibilityProtocol`（NSAccessibilityProtocol 是 ObjC 协议 → 必须是 NSObject 子类 + @objc 方法；不是仅"加 conformance"——是基类变更）。实现 `accessibilityRole()`/`accessibilityChildren()`/`accessibilityParent()`/`accessibilityIsAttributeSettable(_:)`/`accessibilityAttributeValue(_:)`/`accessibilityParameterizedAttributeValue(_:for:)`/`accessibilityPerformAction(_:)` 委托 `descriptor` + `backingView` + `axElementGraph.children(of:)`。`MonaAXRoleElement` protocol 保持 `AnyObject`（不改）。dict `elementByIdentity` 安全（NSObject Hashable）。
- view 实现 ~16 个 `accessibility*` override：role(`.textArea`)/isAccessibilityElement(false)/children(`axElementGraph.children(of: root.identity)`)/focusedUIElement(`root`)/parent/window/value(`textArea.value`)/numberOfCharacters/selectedTextRange/visibleCharacterRange/attributedString(for:)/range(for:)/bounds(for:)/position(for:)/line(for:)/range(forLine:)/performAction(`axMutationGateway.perform`)。
- 4 wiring gap：①announcementBridge.nextAnnouncement() → NSAccessibility.post(.announcementRequested)；②focusCoordinator.transition → NSAccessibility.post(.focusedWindowChanged) + accessibilityFocusedUIElement；③recycleViewport on scroll（scrollWheel 后调 `axElementGraph.recycleViewport(backingViews:)`）；④textArea.selectionRange sync on cursor change（observeContentChange 或 lastCommittedSelections 变化时）。

### 3.7 重绘触发
- `observeContentChange()`(:399) 加 `setNeedsDisplay(true)`（模型 onDidChangeContent → observeContentChange → 重发 generation + setNeedsDisplay）。
- scrollWheel override 内 setNeedsDisplay（§3.4）。
- `viewDidEndLiveResize` → ①setViewportDimensions(bounds) + converge；②setContentDimensions(contentWidth/Height from projection)；③publishGeneration + setNeedsDisplay。
- `updateTrackingAreas` → 刷 NSTrackingArea + publishGeneration + setViewportDimensions + converge。

### 3.8 响应链 + 焦点
`override var acceptsFirstResponder: Bool { true }`、`override var canBecomeKeyView: Bool { true }`、`becomeFirstResponder`/`resignFirstResponder`（接 focusCoordinator.transition）。`override var isFlipped: Bool { true }`。`override var wantsLayer: Bool { true }`。

### 3.9 dispatcher 接线（performAttach）
```
// performAttach(model:) 内，紧跟 axMutationGateway(:343)：
// GAP-2：先更新 content dimensions from projection
scrollModel?.setContentDimensions(width: contentWidth, height: Double(viewGraph?.verticalIndex.totalHeight ?? 0))
scrollModel?.setViewportDimensions(width: Double(bounds.width), height: Double(bounds.height))
// dispatcher
commandDispatcher = MonaCommandDispatcher(model: model, inputBarrier: inputBarrier!,
    transactionGateway: inputBarrier!.gateway, caretOps: MonaCaretOperationsFeature())
// keybindingResolver 加载
keybindingResolver = MonaBuiltinKeybindings.makeResolver()  // 替换 commonInit:246 空 resolver
// textInputClient 选区 provider 接真值
textInputClient = MonaTextInputClient(geometryProvider: geometryBarrier!,
    documentTextProvider: { model.getValue() },
    documentSelectionProvider: { [weak self] in self?.selectionAsNSRange() ?? NSRange(location: 0, length: 0) },
    textInsertionProvider: { [weak self] text, _ in self?.commandDispatcher?.execute("type", args: ["text": text]) })
```

### 3.10 GUI 宿主（改造 sample-macOS-host）
`Sources/MonaCodeSample/main.swift`：加 `NSApplication.shared` + `NSWindow` + `MonaEditorFactory.create(model:)` → contentView = editor view + `NSApp.run()`。

---

## 4. Performance design

### 4.1 瓶颈分析（perf agent 事实）
- **瓶颈 1**：`CTFontDrawGlyphs` per tile paint on scroll（MonaCoreGraphicsRenderer:248-255）——新 tileX/tileY → cache miss → 全 paint per glyph run per line。
- **瓶颈 2**：`CTLineCreateWithAttributedString` per line on generation change（MonaTextShaper:212 via buildRecord:483）——content 变 → 每可见行 reshaping；已按 generation 缓存 record 缓解。
- **瓶颈 3**：subpixel scroll thrash（subpixelPhase 在 key :61-64 → 每 phase 新 tile → 缓存失效）。
- **非瓶颈**：projection/geometry（O(log n) segment tree）、blit（layer-backed GPU 合成）、publishGeneration（状态捕获 + dict reset，cheap）。

### 4.2 最高性能方案（perf agent 事实推荐）
- **layer-backed CG**（`wantsLayer=true` + drawRect blit）：Core Animation 在 GPU 上免费合成 CPU 位图 → GPU 合成 + layer-scroll translation（CALayer.bounds.origin 移动已缓存 tile 无需 redraw）。
- **Metal 不触发**（3 事实理由：hybrid 非全 GPU + 冻结契约 + layer-backed CG 更优）。
- **display-link 不引入**（measure-first；仅 profiling 显 momentum scroll 掉帧才加）。
- **scroll quantize**（整像素/tile 对齐，最大化 cache reuse，避免 subpixel thrash）。

### 4.3 性能 gate（R01-R05）
放 `Tests/MonaCodeAppKitTests/Performance/RenderPerformanceTests.swift`（import MonaCodeAppKit；exercises cgRenderer + barrier 直接 = drawRect 成本上界）。方法 = ContinuousClock + 2×30-run + 3-run warmup + CV<0.5 + self-consistency<0.5（匹配 PerformanceBenchmarksTests:77-129）。

| ID | 测什么 | fixture | 阈值 |
|---|---|---|---|
| R01 | 渲染帧时间（一帧全可见视口 paint） | 256×256 tile, 60 行 12pt Menlo, 1KiB 行 | <16.67ms（60Hz, DisplayModeEnforcer:152-156） |
| R02 | 滚动 FPS（稳态缓存） | 1MiB/50K 行；滚 1000 tile-row | ≥60fps（均帧 <16.67ms） |
| R03 | 首屏（cold attach→首帧） | 新 view + 1MiB model | <100ms |
| R04 | subpixel 重画代价 | 同 R02 但分数 delta | 量化 cache-miss 代价（帧时间 delta vs R02） |
| R05 | content-change 重画 | 1MiB；单字符编辑→repaint | <16.67ms |

---

## 5. Hard truths + Gaps

1. **GAP-1（barrier→renderer 数据流不完整）**：barrier 的 records/snapshot 是 private；drawRect 前提是加 public accessor。**load-bearing**。
2. **GAP-2（content dimensions 没喂）**：setContentDimensions 零调用方；用 bounds 占位。attach/content-change/resize 推真值。
3. **GAP-3（converge pull-only）**：scrollWheel 自己调 converge + setNeedsDisplay。
4. **GAP-4（barrier 冻结 scroll 过期）**：scrollWheel converge 后调 publishGeneration(nil) 刷新。
5. **GAP-5（keyboard）**：insertText 缺 + 2 路径冲突 + committedThenDispatched 插 text + 空 resolver + context provider 缺。
6. **GAP-6（AX）**：MonaAXElementNode 非 NSAccessibilityProtocol + 16 override + 4 wiring gap。
7. **无光标宿主**：mouseDown/keyDown 选区真值读 `inputBarrier.gateway.lastCommittedSelections`；pointer 用低层 gateway path（非 commitCaretMove）。
8. **drawRect 难单测**：视觉验证（demo host 截图）+ 性能 gate R01-R05。
9. **undo 未接（B1a）**：driving editor 能打字但不能撤销。

---

## 6. Verification

- **TDD（可测）**：`dispatchKeyEvent(MonaKeyEvent)` → 断言 model 变化（绕开 NSEvent）；mouseDown hitTest → 选区（构造 point，断言 lastCommittedSelections）；scrollWheel → publishedScroll 变化。
- **视觉验证**：demo host（sample GUI）窗口截图——文本画出、打字反应、滚动、鼠标选区。
- **性能 gate**：R01-R05（§4.3）。
- **monaco oracle**：keyDown 接线端到端（demo host + NSEvent 注入）→ 同输入键序对比 monaco model 文本+选区。v1 用 TDD + 视觉 + R01-R05；端到端 oracle 留到 GUI 可注入事件后。

---

## 7. 已收敛（全 5 agent 深核 + 对抗 review 10 发现全 resolved）

原 7 待核 + 6 GAP + 10 对抗发现 = 全部核完 + 解法给出（§3/§5/§8）：

**第一轮（5 agent 深核）**：
1. ~~MonaKeyEvent 字符字段~~ → `keyText: String?`(:54)。
2. ~~arbiter args~~ → 不带；committedThenDispatched 统一调 textInputClient.insertText（§3.2 #3 修正）。
3. ~~verticalIndex~~ → public(:198) + O(log n) segment tree。
4. ~~surface→CGImage~~ → CGBitmapContextCreateImage + y-flip + **lazy cached cgImage**（§3.1 #6 修正）。
5. ~~create 签名~~ → 已返回 MonaCodeEditorView(:163)。
6. ~~insertText~~ → 缺（GAP-5）；补 + 注入 textInsertionProvider（Ruling 5）。
7. ~~AX 桥接~~ → MonaAXElementNode 非 NSAccessibilityProtocol；**extend NSObject** + conform（§3.6 #4 修正）。
+ GAP-1 barrier accessor / GAP-2 content dims / GAP-3 converge pull / GAP-4 frozen scroll refresh / 瓶颈 = Core Text / Metal 不触发 / 层预算 16.67ms / scroll quantize。

**第二轮（对抗 review 10 发现）**：
1. ~~lineOrigins 公式错~~ → **修正**：`origin.y = verticalOffsetForViewLine(L) - tileY*tileSide`（tile-local，非 -scrollY）；`origin.x = -tileX*tileSide`（§3.1 paint 事实核实：paint 用 tile-local CG y-up + translateBy(subpixelPhase)）。
2. ~~contentWidth 计算~~ → **Ruling**：lazy = `max(viewportWidth, max(record.totalWidth for visible lines))`（随滚动增长，content 变重算，避免 O(n) shape 全文；§4）。
3. ~~committedThenDispatched replacementRange~~ → **修正**：调 `textInputClient.insertText(committedText, replacementRange: session.replacementRange)` 统一 insert path（§3.2；NSNotFound→selection，specific→range）。
4. ~~AX conformance 侵入度~~ → **修正**：明确 extend NSObject（非仅"加 conformance"；§3.6）。
5. ~~R01-R05 swift test 可行~~ → **确认**：调 cgRenderer.tile + barrier 直接（CPU bitmap，不需 NSGraphicsContext；§4.3）。
6. ~~CGBitmapContextCreateImage per-frame~~ → **Ruling**：MonaRenderSurface 加 lazy cached cgImage（创建一次复用；§3.1 + §4）。
7. ~~scroll quantize 损害 trackpad~~ → **Ruling**：v1 整像素栅格（max cache）+ setNeedsDisplay coalesce（60fps 整像素够平滑）；v2 = CALayer.bounds.origin GPU translation（subpixel 平滑无 redraw，measure-first；§4）。
8. ~~tile→visible-line 映射~~ → **Ruling**：pre-compute 可见行 + verticalOffsets（O(visible × log n) 一次），按 tile y-band 分区（O(visible) scan；§3.1）。
9. ~~MonaKeybindingContext keys~~ → **Ruling**：view 设 editorTextFocus(.bool(true))/editorReadonly(.bool(false))/editorHasMultipleSelections(.bool(false))/editorLangId(.string("plaintext"))；379 when-clause 精确 key 集 = follow-up audit（§3.2）。
10. ~~buildSnapshot 成本~~ → **Ruling**：per-drawRect 一次，records + verticalIndex 供所有 tile 复用（§3.1）。

**无未决开放问题。全部不确定性已收敛。无推测。**

---

## 8. Facts appendix（5 agent 深核，全 file:line）

### 8.1 Render pipeline
- `MonaViewGraph.getProjection()->MonaViewProjection`(:184)（dirty→rebuild:212 O(n) over model lines；non-dirty=struct return）；`verticalIndex: MonaVerticalIndex`(:198)；`generation`(:193)；mutators setFoldedRanges(:143)/setHiddenRanges(:149)/setInjections(:155)/setWordWrapColumn(:162)/setViewZones(:168)/setLineHeight(:174) mark dirty 不 bump gen。
- `MonaVerticalIndex`：`viewLineCount`(:60)/`totalHeight`(:63)/`verticalOffsetForViewLine(_:)`(:122, O(log n) prefix-sum)/`viewLineAtVerticalOffset(_:)`(:132, O(log n) tree descent)。segment tree perfect-binary。
- `MonaQueryGeometryBarrier`：`publishGeneration(visibleViewLines:)->Int?`(:271)（读 getProjection:275 + verticalIndex:276 + scrollModel.publishedScrollX/Y:285-286 + reset records:289 + 建 visible records:293-301 via buildRecord:438-491）；`currentGeneration`(:253)；`hitTest(point:)->MonaGeometryResult<MonaPosition>`(:311)（viewport→content via frozen scrollOffset:318 + verticalIndex:346 + bounded record:353 + hitTester:358）；`caretRect(for:)`(:369)；`rangeRects(for:)`(:402)；`buildSnapshot()`(:495) **private**（GAP-1）；`buildRecord(viewLine:projection:)`(:438) shapes via `builder.build(codeUnits:dependencyStamp:)`→`MonaTextShaper.shape()`→`CTLineCreateWithAttributedString`(MonaTextShaper:212)。
- `MonaLineLayoutRecord`：`glyphRuns`(:232)/`rawUnitBoundaries`(:258, sorted by x, binary-search hitTest:342)/`hitTest(offset:)`(:342)/`totalWidth`(:318)/`lineHeight`(:323)；frozen reshaped-free。
- `MonaCoreGraphicsRenderer.tile(for:records:lineOrigins:layerInputs:)->MonaRenderTile`(:137)（cache hit:144 dict lookup; miss: alloc surface:149 + paint:154 8 z-layers:165-205）；`paintTextLayer`(:211) `CTFontDrawGlyphs`(:248)；z-order text=0/selections=1/cursors=2(no-op)/decorations=3/widgets=4(no-op)/gutters=5(no-op)/minimap=6(no-op)/overlays=7。
- `MonaRenderSurface`：`bitmapContext: CGContext`(:51, premultipliedLast+byteOrder32Big genericRGBLinear:85-89, y-up bottom-left:113-118)；`width`(:42)/`height`(:45)/`scaleFactor`(:48)；无 CGImage helper（blit 用 CGBitmapContextCreateImage）。
- `MonaRenderTileCache`：`setCurrentGeneration(_:)`(:179)/`invalidate(olderThanGeneration:)`(:187)/`tile(for:)`(:217, LRU bump)/`store(_:)`(:229, evict LRU evictable until maxTileCount+maxBytes)；`leastRecentlyUsedEvictableKey()`(:251) **current-gen 不驱逐**(:255)。view init:224 `maxTileCount:64, maxBytes:256MiB`。
- `MonaRenderTileKey`：`generation/tileX/tileY/scale/subpixelPhaseX/subpixelPhaseY`(:43-82)。
- `MonaMetalRenderer`：`branch`(:58 .notTriggeredAndAbsent/.triggeredAndRequired)；`tile(for:...)`(:194) absent→.absent; triggered→`renderViaMetal`(:281) hybrid（contentRenderer.tile:311 CG raster → MTLTexture:314 → texturePipeline blit:340 → solidPipeline overlay:346 → GPU readback:357 makeSurface:443）；fallback cgRenderer.tile→.fallback(:212)。
- `MonaRendererDecisionGate`：**TEST-ONLY**（Tests/.../MonaRendererDecisionGateTests.swift:185）；`evaluate(_:)`(:205) 3 renderer-attributable metrics（layoutReadyToPresent/gpuFrameTime/rendererSurfaceFootprint :60-73）strict > threshold(:247-251 16ms/16ms/100MB)→.triggeredAndRequired；8 cross-domain BANNED(:81-101) submitCrossDomainTrigger always throws(:232-238)。冻结 notTriggered（P09-T052 validates frozen SHA-256 no-recompute :607-618）。**产品不调用 evaluate**。

### 8.2 Keyboard + IME
- `MonaAppKeyEventGateway.translateKeyDown(_:isComposing:)->MonaKeyEvent`(:68)→`translate(_:isComposing:)`(:91)（MonaMacKeyCodeMap.monaKeyCode(forMacKeyCode:):92 + monaModifiers(for:):93 + resolvedKeyText(characters:keyCode:modifierFlags:):94）；`translateKeyUp`(:82)；`apply(_:)->MonaAppKeyDispatchAction`(:179)（preventDefault/stopPropagation 独立于 handled:175-178）。Stateless:51。
- `MonaKeyEvent`：`keyCode:MonaKeyCode`(:49)/`keyText:String?`(:54,**printable for type**)/`modifiers:MonaKeyMod`(:58)/`isRepeat:Bool`(:62)/`isComposing:Bool`(:65)/`timestamp:Double`(:69)。
- `MonaKeybindingResolver.resolve(event:context:chordState:)->MonaKeybindingResolution`(:185)（chord:194-210/first-part:219-236/no-match:240-245；modifier SUBSET match:319；ordering weight desc:326）；`MonaKeybindingContext`(:75 map [String:MonaContextValue])；`MonaKeybindingResolution`(:110 commandId/outcome/chordStatus)；`MonaChordState`(:84, timeout 5s:101)。
- `MonaCompositionArbiter.handleKey(_:context:)->MonaCompositionArbitration`(:173)（5 case:57-73；dispatchOutcome:81 handled→preventDefault+stopPropagation / passThrough+noOp→.default；session.isActive:185 → isComposing:true→absorbedByComposition:186 / false→resolve+commit-then-dispatched:197-199 or absorbedByComposition:201 / no-composition:205→dispatched:207 or passThrough:209）。
- `MonaCompositionSession`：phase idle/composing/committing/committed(:44)；`isActive`(:114)/`markedText`(:128)/`lastCommittedText`(:142)；`updateMarkedText(_:selectedRange:replacementRange:)`(:196)/`commit(_:)`(:231,**only records lifecycle, NOT model mutation**)/`cancel()`(:253)/`fold(...)`(:279)/`dispose()`(:270)。
- `MonaTextInputClient`(:72, **NO `: NSTextInputClient` conformance**)：`setMarkedText`(:140)/`unmarkText`(:153)/`hasMarkedText`(:160)/`markedRange`(:167)/`selectedRange`(:179)/`attributedSubstring`(:194)/`firstRect`(:224)/`characterIndex`(:252)；**`insertText(_:replacementRange:)` ABSENT**（NSTextInputClient required）；`documentSelectionProvider` wired `{ NSRange(0,0) }` hardcoded(:373)；`positionForUTF16Offset`/`utf16OffsetForPosition`(:313/340)。
- `MonaBuiltinKeybindings.makeResolver()`(:451, 379 rows)；commonInit:246 creates EMPTY `MonaKeybindingResolver()`（GAP-5）。
- A3 `MonaCommandDispatcher.execute(_:args:)->Bool`(:37)；`typeCommand`(:68 reads `args["text"]`)；`currentSelections(ctx)`(:189 reads `lastCommittedSelections` or default (1,1))。

### 8.3 Mouse + Scroll
- `MonaPointerGateway.translate(_:phase:viewportPoint:resolvingPositionThrough:)->MonaPointerEvent`(:178, **stateless pure**:156)；`MonaPointerEventPhase`(.down/.up/.moved/.dragged:73-86, caller maps NSEvent type)；`resolvedPosition: MonaPosition?`(:120, nil when barrier absent/no-gen/OOB:244-246)；`MonaPointerGateway.resolve(viewportPoint:through:barrier:)`(:235 static, calls barrier.hitTest)。
- `MonaScrollGateway.translate(_:viewportPoint:resolvingPositionThrough:)->MonaScrollEvent`(:185, **stateless pure**:153)；`translateFields(...)`(:265 static, testable)；delta precise÷40 coarse verbatim(:277-279, divisor=40:162)；direction NOT reversed(:249)；`MonaScrollPhase`(:51-70, mapping:332-339 from NSEvent.Phase)。
- `MonaScrollModel`：`requestScroll(x:y:)`(:217, stores immediately)；`converge()->MonaScrollChangeEvent`(:270, frozen order: dims→clamp→validate→publish:271-305)；`publishedScrollX/Y`(:152-158)；`publishedScrollOffsetXInt/YInt`(:312-319)；`setContentDimensions`(:229, **zero production callers**)；`setViewportDimensions`(:235, **zero production callers**)。view creates with bounds placeholder(performAttach:301-306)。
- `MonaScrollChangeEvent`(:57, requested/validated/published/contentW/H/viewportW/H/generation)。
- 选区-set path（no cursor host）：`inputBarrier.gateway.beginTransaction()`→`tx.prepareSelections([sel])`→`gateway.commit(tx)`（参考 `MonaCaretOperationsFeature.commitCaretMove`:245-272 + `MonaMiddleScrollFeature.commitScrollReveal`:268-278）；pointer 用**低层 gateway path**（非 commitCaretMove 后者只相对移动）。
- `MonaMiddleScrollFeature.updateMiddleButtonScroll`(:198-221) = 唯一生产 requestScroll+converge 调用方。

### 8.4 AX
- `MonaAXElementNode`：`final class : MonaAXRoleElement`（MonaAXElementGraph.swift:349，**NOT NSView/NSObject/NSAccessibilityProtocol**）；`accessibilityRole: NSAccessibility.Role`(:353 via descriptor)；`backingView: NSView?`(:357 weak)；`recycleBacking(to:generation:)`(:366)。`MonaAXRoleElement` protocol(:318, AnyObject)。
- `MonaAXElementGraph`：`root`(:465 =editorNode)/`element(for:)`(:491)/`children(of:)`(:514)/`recycleViewport(backingViews:)`(:529)/`viewportGeneration`(:411)/`textArea: MonaAXTextArea`(:394)。6 roles(.editor/.gutter/.widget/.link/.diagnostic/.proxy:45-63)→NSAccessibility.Role(.textArea/.group/.link/.unknown:162-267)。tree editor→[gutter,widget,proxy]:447 widget→[link,diagnostic]:452。
- `MonaAXTextArea`(:49)：value/numberOfCharacters/selectionRange(get+set:123)/attributedSubstring(for:)/visibleRange/range(forPosition:)/bounds(forRange:)/position(forRange:)/line(forCharacterIndex:)/range(forLine:)；holds model+geometryBarrier weakly。
- `MonaAXFocusCoordinator`(:70)：5 modes(.editor/.widget/.accessibilityOptimized/.tabFocus/.temporary:40-57)/`transition(to:)`(:95)/`releaseTemporary()`(:115)；**无 NSAccessibility.post wiring**。
- `MonaAXMutationGateway`(:157)：`perform(_:)`(:263) 5 preconditions(focus/editable/version/range/generation:270-294)→translate→MonaMultiCursorInputPlan:357→barrier.prepare+commit:312-314→on .applied dispatch handlers:328。6 actions(setValue/setSelection/increment/decrement/press/custom:50)。
- `MonaAXAnnouncementBridge`(:90)：7 keys(:45)/resolve(:138)/enqueue(:177, dedup)/nextAnnouncement(:191)；**纯文本无 NSSpeechSynthesizer**；host pump→NSAccessibility.post。

### 8.5 Perf
- 帧预算：`DisplayModeEnforcer.deadline(for:)`(:152-156) = 1000/hz → 60Hz=16.67ms / 120Hz=8.33ms；`relativeNoRegressionThreshold=0.05`(:101)。
- Metal 触发阈值（test-only）：`MonaRendererTriggerThresholds`(:60-73) layoutReadyToPresent=16ms / gpuFrameTime=16ms / rendererSurfaceFootprint=100MB；strict `>`(:498-506)。
- `PerformanceBenchmarksTests`(:77-129 runBenchmark: 2×30-run + 3-warmup + CV<0.5 + self-consistency<0.5, ContinuousClock)。P01-P10 全 Foundation-only（不测渲染）。
- P04/P05/P06 workloads = STRUCTURAL ONLY（Option A，合成 block，无真测量）。
- `MonaCodeEditorView` 零 override（grep `drawRect|wantsLayer|updateLayer|setNeedsDisplay|CVDisplayLink` across Sources/ → **NOTHING**）。
- `MonaRenderSurface`：`premultipliedLast`+`byteOrder32Big` linear-RGBA bitmap(:85-89, :68)；CPU bitmap suitable for CALayer backing / CGImage creation。
