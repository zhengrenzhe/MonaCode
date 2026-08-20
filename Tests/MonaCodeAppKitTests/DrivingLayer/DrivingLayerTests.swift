// DrivingLayerTests.swift
//
// Driving-layer GAP-1 / Task 1 — Barrier public snapshot + RenderSurface cgImage.
//
// Prerequisites for the `drawRect` render pipeline (Task 2):
//   - `MonaQueryGeometryBarrier.snapshot()` is public so the driving layer can
//     read the ready geometry of one complete generation without observing
//     partial state.
//   - `MonaRenderSurface.cgImage` exposes a lazily-derived, cached `CGImage`
//     of the bitmap context so a finished tile can be composited into the host
//     `NSGraphicsContext` in `drawRect` without rebuilding the image each frame.

import XCTest
import AppKit
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class DrivingLayerTests: XCTestCase {

    // MARK: - Shared helpers (constructed against the real MonaCodeAppKit API)

    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// Builds a barrier over a real model + view graph + scroll model + builder,
    /// mirroring the construction used by `MonaQueryGeometryBarrierTests`.
    private func makeBarrier(
        text: String = "hello\nworld\n",
        lineHeight: Int = 20
    ) -> MonaQueryGeometryBarrier {
        let model = MonaCodeModel(text: text, uri: MonaURI.parse("monacode:driving")!)
        let viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 400,
            contentHeight: Double(2 * lineHeight),
            viewportWidth: 400,
            viewportHeight: Double(lineHeight)
        )
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let provider: (Int) -> [UInt16] = { Array(model.getLineContent($0).utf16) }
        return MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: provider
        )
    }

    // MARK: - Barrier: public snapshot accessor (Task 1 / GAP-1)

    func testBarrierSnapshotIsPublic() {
        let barrier = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...1)
        let snap = barrier.snapshot()
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.records.count, 1)
    }

    // MARK: - RenderSurface: lazy cached cgImage (Task 1 / GAP-1)

    func testRenderSurfaceHasCachedCGImage() {
        let surface = MonaRenderSurface(width: 256, height: 256, scaleFactor: 1)
        XCTAssertNotNil(surface.cgImage)
        // Same instance on second access (cached, not re-created).
        let img1 = surface.cgImage
        let img2 = surface.cgImage
        XCTAssertNotNil(img1)
        XCTAssertNotNil(img2)
        XCTAssertEqual(img1, img2)
    }

    // MARK: - drawRect render pipeline (Task 2)

    func testDrawRectRendersVisibleTiles() {
        let model = MonaCodeModel(text: "line1\nline2\nline3\n", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.attach(model: model)
        view.needsDisplay = true  // trigger draw

        // Driving-layer overrides: NSView defaults are `isFlipped == false` and
        // `wantsLayer == false`; the Task 2 override block flips both to `true`.
        // `isFlipped` is the reliable detector for "the override block was added"
        // (NSView's base isFlipped is `false`), so this assertion fails before
        // the Task 2 implementation and passes after.
        XCTAssertTrue(view.isFlipped, "isFlipped override: view y-down for AppKit text layout")
        XCTAssertTrue(view.wantsLayer, "wantsLayer: layer-backed (Core Animation composites tiles)")

        // draw(_:) override present + doesn't crash. In a headless test context
        // there is no NSGraphicsContext, so draw early-returns at its ctx guard.
        //
        // API drift: the brief used `perform(NSSelectorFromString("draw:"))` to
        // assert the override exists. In the macOS 26 SDK the ObjC selector for
        // `NSView.draw(_:)` is `drawRect:` (the Swift overlay renamed
        // `drawRect(_:)` to `draw(_:)` but kept the ObjC name — see
        // NSView.h:206 `- (void)drawRect:(NSRect)dirtyRect;`). So `draw:` is
        // never recognized, and `drawRect:` is always recognized (NSView's
        // base) — `perform` cannot distinguish the override either way. A
        // direct Swift call exercises the override via dynamic dispatch
        // (lands on MonaCodeEditorView.draw).
        view.draw(NSRect(x: 0, y: 0, width: 400, height: 300))
    }

    // MARK: - observeContentChange: redraw trigger (Task 3 / GAP-3)

    @MainActor
    func testObserveContentChangeTriggersRedraw() {
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.attach(model: model)
        view.needsDisplay = false
        model.applyEdits([MonaModelEditOperation(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1), text: "X")])
        // observeContentChange should have set needsDisplay
        XCTAssertTrue(view.needsDisplay)
    }

    // MARK: - commandDispatcher wire-in (Task 4 / GAP-5)

    @MainActor
    func testDispatcherConstructedOnAttach() {
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.attach(model: model)
        XCTAssertNotNil(view.commandDispatcher)
        XCTAssertTrue(view.commandDispatcher!.contains("type"))
        XCTAssertTrue(view.commandDispatcher!.contains("cursorLeft"))
    }

    // MARK: - IME insertText + NSTextInputClient conformance (Task 6 / GAP-5)

    /// `insertText(_:replacementRange:)` on the text input client routes through
    /// the command dispatcher's `type` command, inserting at the current
    /// selection. With no committed selections the barrier defaults to a
    /// collapsed caret at `(1,1)`, so "X" lands before "abc" → "Xabc".
    @MainActor
    func testInsertTextInsertsViaDispatcher() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.attach(model: model)
        view.textInputClient?.insertText("X", replacementRange: .notFound)
        XCTAssertEqual(model.getValue(), "Xabc")
    }

    // MARK: - keyDown + dispatchKeyEvent 7-step branch (Task 5)

    /// `dispatchKeyEvent` routes a pass-through key (no keybinding match, plain
    /// keyText, not composing) through the `type` command. With an empty model
    /// and a default caret at `(1,1)`, typing "X" yields `"X"`.
    @MainActor
    func testDispatchKeyTypeInsertsText() {
        let model = MonaCodeModel(text: "", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.attach(model: model)
        // keyCode 45 == MonaKeyCode.keyO; no plain (no-modifier) keybinding
        // matches it, so the arbiter returns `.passThrough` and the
        // `keyText` ("X") routes through the `type` command.
        let key = MonaKeyEvent(
            keyCode: MonaKeyCode.custom(45),
            keyText: "X",
            modifiers: [],
            isRepeat: false,
            isComposing: false,
            timestamp: 0
        )
        view.dispatchKeyEvent(key, source: nil)
        XCTAssertEqual(model.getValue(), "X")
    }
}
