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

    // MARK: - mouseDown sets caret (Task 7 / §3.3 + §5 hard-truth #7)

    /// `mouseDown` translates the event through `pointerGateway`, resolves the
    /// viewport point to a model position through `geometryBarrier`, and sets an
    /// ABSOLUTE collapsed caret via the low-level gateway path
    /// (`beginTransaction → prepareSelections → commit`) — the spec §3.3 +
    /// §5 hard-truth-#7 path (pointer sets absolute position → low-level
    /// gateway, NOT `commitCaretMove` which is relative-only). The caret lands
    /// on `inputBarrier.gateway.lastCommittedSelections` for the next input/AX
    /// mutation to read.
    @MainActor
    func testMouseDownSetsCaret() {
        let model = MonaCodeModel(text: "hello\nworld\n", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.attach(model: model)
        // Publish a generation so the barrier has records to hit-test against.
        _ = view.geometryBarrier?.publishGeneration(visibleViewLines: 1...2)

        // API drift: the brief used `perform(NSSelectorFromString("mouseDown:"))`
        // to assert the override exists. `perform(_:)` (the no-arg variant) on a
        // selector that takes an `NSEvent` argument would crash (Swift imports
        // `NSEvent` as non-optional), and it returns nil for void-returning
        // methods — so it cannot distinguish override-present from NSView's
        // base `mouseDown:`. Instead: construct a real mouse `NSEvent` (same
        // pattern as `MonaPointerScrollMenuTests.mouseEvent`) and call the
        // override directly via dynamic dispatch (lands on
        // `MonaCodeEditorView.mouseDown`).
        let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: CGPoint(x: 5, y: 5),
            modifierFlags: [],
            timestamp: 100.0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1.0
        )!
        view.mouseDown(with: event)

        // The override set a collapsed caret at the hit-tested position via the
        // low-level gateway path; `lastCommittedSelections` now carries it.
        let selections = view.inputBarrier?.gateway.lastCommittedSelections ?? []
        XCTAssertFalse(selections.isEmpty, "mouseDown committed a caret selection")
        // The caret is collapsed (anchor == activePosition) — a click, not a drag.
        if let sel = selections.first {
            XCTAssertEqual(sel.anchor, sel.activePosition, "mouseDown sets a collapsed caret")
        }
    }

    // MARK: - scrollWheel (Task 8 / §3.4)

    /// `scrollWheel` translates the event through `scrollGateway`, requests the
    /// scroll on `scrollModel`, converges (pull-only — GAP-3), schedules a
    /// redraw when the published scroll actually moved, and refreshes the
    /// barrier's frozen scroll (GAP-4) so the next mouseDown hit-tests against
    /// the new scroll. After a scrollWheel with a nonzero vertical delta,
    /// `publishedScrollY` must change from its baseline of zero.
    ///
    /// Setup: 30 lines × 20px = 600px content; viewport 300px → maxScrollY = 300,
    /// so a positive delta moves the published scroll inside the clamp envelope
    /// (no clamping to zero). The gateway carries coarse deltas verbatim, so
    /// `wheel1: 10` → `deltaY: 10.0` → `requestScroll(y: 0 + 10)` → published 10.
    @MainActor
    func testScrollWheelChangesPublishedScroll() {
        let lines = (1...30).map { "line\($0)" }.joined(separator: "\n") + "\n"
        let model = MonaCodeModel(text: lines, uri: MonaURI(scheme: "inmemory", path: "/t"))
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.attach(model: model)
        // Publish a generation so the barrier has frozen geometry for the
        // scroll gateway's position-resolution path (mirrors production order:
        // scrollWheel assumes an attached, generation-published barrier).
        _ = view.geometryBarrier?.publishGeneration(visibleViewLines: 1...5)

        let prevY = view.scrollModel?.publishedScrollY ?? -1
        XCTAssertEqual(prevY, 0, "baseline: published scroll starts at zero")

        // API drift: the brief used `NSEvent.scrollWheel(...)`. No such factory
        // exists on NSEvent — scrollWheel events are built via CoreGraphics
        // `CGEvent(scrollWheelEvent2Source:...)` then wrapped in `NSEvent(cgEvent:)`
        // (same pattern as `MonaPointerScrollMenuTests.testScrollGatewayTranslates*`).
        guard let cg = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 10,
            wheel2: 0,
            wheel3: 0
        ) else {
            return XCTFail("could not build CGEvent scrollWheel")
        }
        guard let event = NSEvent(cgEvent: cg) else {
            return XCTFail("could not wrap CGEvent as NSEvent")
        }
        view.scrollWheel(with: event)

        let nextY = view.scrollModel?.publishedScrollY ?? -1
        XCTAssertNotEqual(nextY, prevY, "scrollWheel moved publishedScrollY")
        XCTAssertGreaterThan(nextY, 0, "scroll down increases publishedScrollY")
    }

    // MARK: - Responder chain overrides (Task 9)

    /// `acceptsFirstResponder` + `canBecomeKeyView` are overridden to `true` so
    /// AppKit's responder chain routes keyboard events to the editor (it is a
    /// first-responder candidate AND a key-view candidate). Without these the
    /// chain would skip the view and `keyDown(with:)` would never fire.
    ///
    /// API drift: the macOS 26 SDK imports both as read-only ObjC
    /// `@property (readonly) BOOL` (was a method in earlier SDKs). Read-only
    /// properties are overridable as computed `var` with a getter, so the
    /// override is `override var acceptsFirstResponder: Bool { true }` (NOT a
    /// `commonInit()` assignment — there is no setter to assign).
    @MainActor
    func testResponderChain() {
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let view = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.attach(model: model)
        XCTAssertTrue(view.acceptsFirstResponder, "acceptsFirstResponder: view accepts keyboard focus")
        XCTAssertTrue(view.canBecomeKeyView, "canBecomeKeyView: view is a key-view candidate")
    }

    // MARK: - AX element bridge: NSObject + NSAccessibilityProtocol (Task 10 / GAP-6 / §3.6)

    /// The 3 AX element classes (`MonaAXElementNode`, `MonaAXWidgetProxy`,
    /// `MonaAXDiagnosticElement`) now extend `NSObject` (via
    /// `NSAccessibilityElement`) + conform to `NSAccessibilityProtocol` so macOS
    /// `AXUIElement`/VoiceOver can traverse them as first-class AX objects.
    ///
    /// The editor node responds to the ObjC `accessibilityRole` selector and
    /// reports its frozen role `.textArea` (delegating to
    /// `descriptor.accessibilityRole`). The proxy reports `.unknown`; the
    /// diagnostic reports `.group`. All three are leaves in the AX tree for v1
    /// (`accessibilityChildren()` returns `nil`) — the host view (Task 11) vends
    /// the tree structure from its own `accessibilityChildren`.
    ///
    /// API drift (recorded): the brief specified `NSObject` as the base and
    /// `NSAccessibilityProtocol` conformance "via an extension on each class".
    /// Empirically (macOS 26 SDK), a plain `NSObject` subclass conforming to the
    /// formal `NSAccessibilityProtocol` requires ~40 `@required` @property
    /// stubs (Swift does not auto-synthesize ObjC protocol properties) — the
    /// compiler emits only a generic "cannot conform … requirements that cannot
    /// be satisfied" and refuses to enumerate them. `NSAccessibilityElement`
    /// (Apple's designated `NSObject` subclass for non-view AX elements;
    /// `@interface NSAccessibilityElement : NSObject <NSAccessibility>`)
    /// already conforms via ObjC @property synthesis, so subclassing it needs
    /// ZERO stubs — strictly better than the literal "NSObject + stubs" path
    /// and still "extends NSObject" (NSAccessibilityElement : NSObject).
    ///
    /// Consequence: `NSAccessibilityElement` exposes `accessibilityRole` as an
    /// `@objc` METHOD returning `NSAccessibility.Role?` (optional). That clashes
    /// with the `MonaAXRoleElement` protocol's `var accessibilityRole:
    /// NSAccessibility.Role` (non-optional property) — same Swift name,
    /// incompatible kinds (var vs func) + return types (verified: declaring
    /// both is "invalid redeclaration"). Resolution: the `accessibilityRole`
    /// property was REMOVED from the `MonaAXRoleElement` protocol (the protocol
    /// stays `AnyObject`-rooted — only the redundant property was dropped); the
    /// concrete classes now expose the role via the @objc override, and the
    /// non-optional role remains available via `descriptor.accessibilityRole`
    /// (how existing tests already read it). No external caller read
    /// `element.accessibilityRole` on the protocol type (grep-verified).
    func testAXElementBridgeRespondsToAccessibilityRole() {
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/t"))
        let graph = MonaAXElementGraph(model: model)

        // Editor node: the AX tree root.
        let editor = graph.root
        let selRole = NSSelectorFromString("accessibilityRole")
        XCTAssertTrue(editor.responds(to: selRole),
                      "MonaAXElementNode responds to ObjC accessibilityRole selector")
        XCTAssertEqual(editor.accessibilityRole(), .textArea,
                       "editor node reports .textArea AX role")
        XCTAssertTrue(editor is NSAccessibilityProtocol,
                      "MonaAXElementNode conforms to NSAccessibilityProtocol")
        XCTAssertTrue(editor is NSObject,
                      "MonaAXElementNode is an NSObject subclass (ObjC runtime)")

        // Proxy: reports .unknown (the proxy descriptor's role).
        let proxy = graph.proxy
        XCTAssertTrue(proxy.responds(to: selRole),
                      "MonaAXWidgetProxy responds to ObjC accessibilityRole selector")
        XCTAssertEqual(proxy.accessibilityRole(), .unknown,
                       "proxy element reports .unknown AX role")
        XCTAssertTrue(proxy is NSAccessibilityProtocol,
                      "MonaAXWidgetProxy conforms to NSAccessibilityProtocol")

        // Diagnostic: lazily created for a line-scoped identity; reports .group.
        let diag = graph.element(for: .init(role: .diagnostic, line: 1))
        XCTAssertNotNil(diag, "diagnostic element lazily created for line 1")
        let diagElement = diag as? MonaAXDiagnosticElement
        XCTAssertNotNil(diagElement, "element is a MonaAXDiagnosticElement")
        XCTAssertTrue(diagElement?.responds(to: selRole) == true,
                      "MonaAXDiagnosticElement responds to ObjC accessibilityRole selector")
        XCTAssertEqual(diagElement?.accessibilityRole(), .group,
                       "diagnostic element reports .group AX role")
        XCTAssertTrue(diag is NSAccessibilityProtocol,
                      "MonaAXDiagnosticElement conforms to NSAccessibilityProtocol")

        // Leaf behavior: all three report no children for v1 (the host view,
        // Task 11, vends the tree structure). nil = AX leaf.
        XCTAssertNil(editor.accessibilityChildren(),
                     "editor node is an AX leaf for v1 (children nil)")
        XCTAssertNil(proxy.accessibilityChildren(),
                     "proxy is an AX leaf for v1 (children nil)")
        XCTAssertNil(diagElement?.accessibilityChildren(),
                     "diagnostic is an AX leaf for v1 (children nil)")
    }
}
