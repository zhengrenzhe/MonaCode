// MonaCodeEditorView.swift
//
// P04-T014 — Deliver MonaCodeEditorView as the AppKit editor boundary.
//
// `MonaCodeEditorView` is the native `NSView` that composes EVERY Phase 03-04
// subsystem into one editor boundary — the surface the SwiftUI wrappers
// (P04-T015) and host app consume. It composes:
//
//   - model attachment      — a `MonaCodeModel` attached via `MonaEditorAttachment`
//                             (weak/borrow ref; lifetime independent from the view).
//   - projection            — `MonaViewGraph` (P03-T001) + `MonaVerticalIndex`
//                             (P03-T002) + `MonaQueryGeometryBarrier` (P03-T007).
//   - renderer branch        — the Core Graphics tiled renderer (P03-T006 /
//                             `MonaCoreGraphicsRenderer`) and the conditional
//                             Metal renderer (P03-T011 / `MonaMetalRenderer`).
//                             The view defaults to `.notTriggeredAndAbsent`
//                             (Core Graphics sufficient); Metal is triggered
//                             only by the renderer-owned decision gate.
//   - input                  — keyboard (`MonaAppKeyEventGateway` P04-T002),
//                             IME/composition (`MonaCompositionSession` P04-T004
//                             + `MonaCompositionArbiter`), multi-cursor
//                             (`MonaModelInputBarrier` P04-T005), pointer/scroll/
//                             menu (P04-T006).
//   - transfer               — clipboard (`MonaPasteboardGateway` /
//                             `MonaPasteEditPipeline` P04-T008), drag/drop +
//                             Services (`MonaDragDropGateway` /
//                             `MonaServicesGateway` P04-T009).
//   - accessibility          — AX text (`MonaAXTextArea` P04-T010), element
//                             graph (`MonaAXElementGraph` P04-T011), focus
//                             (`MonaAXFocusCoordinator` P04-T012), mutation
//                             (`MonaAXMutationGateway` P04-T013).
//   - widgets + lifetime     — owned by the view; torn down in `detach()`/deinit.
//
// The PUBLIC surface is exactly the contract: `init(frame:)`, `init?(coder:)`,
// `attach(model:)`, `detach()`, `isAttached`, and the `attachment` helper. Every
// internal gateway/coordinator is `internal` — no internal gateway type leaks as
// a public collaborator of the view.
//
// Lifetime invariants (enforced by `MonaEditorAttachment`):
//   1. Model lifetime is independent from view attachment (weak/borrow ref;
//      attach/detach never disposes the model).
//   2. All callbacks are detached before disposal (every model-event
//      subscription disposed in `detach()`/`deinit` before teardown).
//
// MonaCodeAppKit may import AppKit/CoreGraphics/CoreText; this file imports
// AppKit + Foundation + MonaCode (for the Core model types), matching the
// import pattern the other AppKit files use.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaCodeEditorView

/// The native `NSView` editor boundary that composes every Phase 03-04
/// subsystem: model attachment, projection, the renderer branch, input,
/// transfer, accessibility, widgets, and lifetime ownership.
///
/// Attach a `MonaCodeModel` via `attach(model:)` (or `attachment.attach(model:)`);
/// detach via `detach()`. The model's lifetime is independent from the view —
/// the view holds a weak (borrow) reference and never disposes the model.
public final class MonaCodeEditorView: NSView {

    // MARK: - Model-independent collaborators
    //
    // Alive for the view's entire lifetime; created once in `commonInit()`.
    // These do not reference a specific model.

    // Renderer branch (P03-T006 CG + P03-T011 conditional Metal).

    /// The tile cache shared by the Core Graphics renderer (P03-T006).
    internal private(set) var renderTileCache: MonaRenderTileCache!

    /// The Core Graphics tiled renderer (P03-T006). Always present.
    internal private(set) var cgRenderer: MonaCoreGraphicsRenderer!

    /// The conditional Metal renderer (P03-T011). Defaults to
    /// `.notTriggeredAndAbsent` — Core Graphics is sufficient until the
    /// renderer-owned decision gate (P03-T010) resolves `.triggeredAndRequired`.
    internal private(set) var metalRenderer: MonaMetalRenderer!

    // Input gateways (P04-T002 keyboard, P04-T004 IME, P04-T006 pointer/scroll/menu).

    /// The keyboard event gateway (P04-T002).
    internal private(set) var keyEventGateway: MonaAppKeyEventGateway!

    /// The IME composition session (P04-T004) — one per editor.
    internal private(set) var compositionSession: MonaCompositionSession!

    /// The per-editor chord state (P04-T003), driven by the keybinding resolver.
    internal private(set) var chordState: MonaChordState!

    /// The keybinding resolver (P04-T003).
    internal private(set) var keybindingResolver: MonaKeybindingResolver!

    /// The keybinding context — the set of monaco "when-clause" context keys
    /// the resolver evaluates against. v1 sets the common static defaults
    /// (per spec §3.2 Ruling #10): `editorTextFocus`, `editorReadonly`,
    /// `editorHasMultipleSelections`, `editorLangId`. A future task will make
    /// these reflect live editor state (focus, model read-only, language id).
    private var keybindingContext: MonaKeybindingContext {
        MonaKeybindingContext()
            .with("editorTextFocus", .bool(true))
            .with("editorReadonly", .bool(false))
            .with("editorHasMultipleSelections", .bool(false))
            .with("editorLangId", .string("plaintext"))
    }

    /// The pointer gateway (P04-T006).
    internal private(set) var pointerGateway: MonaPointerGateway!

    /// The scroll gateway (P04-T006).
    internal private(set) var scrollGateway: MonaScrollGateway!

    /// The context-menu gateway (P04-T006).
    internal private(set) var contextMenuGateway: MonaContextMenuGateway!

    // Transfer (P04-T008 clipboard paste-edit pipeline; model-independent).

    /// The paste-edit pipeline running provider-ordered transformations
    /// (P04-T008). Shared by clipboard paste, drop, and Services.
    internal private(set) var pasteEditPipeline: MonaPasteEditPipeline!

    // Accessibility coordinators (P04-T012; model-independent state machines).

    /// The accessibility focus state machine (P04-T012).
    internal private(set) var focusCoordinator: MonaAXFocusCoordinator!

    /// The VoiceOver announcement bridge (P04-T012) — the N1-localized
    /// notification text surface.
    internal private(set) var announcementBridge: MonaAXAnnouncementBridge!

    // MARK: - Editor identity
    //
    // The editor id — the Swift counterpart of monaco's `editor.getId()`. It is
    // a stable, unique string assigned once at construction (in each init,
    // before `commonInit()`) so the `MonaEditorFactory` (P05-T012) can
    // register, retrieve, and dispose editors by id (`getEditors` /
    // `retrieve(id:)`). P05-T012 fix-forward: the factory's `retrieve(id:)`
    // contract requires editors to carry a public id; this is the minimal
    // addition that unblocks it.

    /// The stable, unique editor id (assigned once at construction).
    public let id: String

    // MARK: - The attachment helper (enforces the lifetime invariants)

    /// The attachment helper that attaches/detaches a model to this view. Owns
    /// the weak model reference and every model-event subscription; enforces
    /// the P04-T014 lifetime invariants (model lifetime independent; all
    /// callbacks detached before disposal).
    public private(set) var attachment: MonaEditorAttachment!

    // MARK: - Model-dependent collaborators
    //
    // Created in `performAttach(model:)` and released in `performDetach()`.
    // Released on `detach()`/`deinit` — never disposed (the model's lifetime is
    // independent).

    /// The projection (P03-T001 `MonaViewGraph`); owns the vertical index
    /// (P03-T002) and view-zone index. `nil` when no model is attached.
    internal private(set) var viewGraph: MonaViewGraph?

    /// The scroll model (the renderer's scroll truth).
    internal private(set) var scrollModel: MonaScrollModel?

    /// The complete-generation geometry barrier (P03-T007). `nil` when detached.
    internal private(set) var geometryBarrier: MonaQueryGeometryBarrier?

    /// The multi-cursor input barrier (P04-T005) every input/AX mutation routes
    /// through. `nil` when detached.
    internal private(set) var inputBarrier: MonaModelInputBarrier?

    /// The AX element graph (P04-T011) — the role tree VoiceOver traverses.
    internal private(set) var axElementGraph: MonaAXElementGraph?

    /// The AX mutation gateway (P04-T013) — the chokepoint for AX-driven edits.
    internal private(set) var axMutationGateway: MonaAXMutationGateway?

    /// The clipboard pasteboard gateway (P04-T008). `nil` when detached.
    internal private(set) var pasteboardGateway: MonaPasteboardGateway?

    /// The drag/drop gateway (P04-T009). `nil` when detached.
    internal private(set) var dragDropGateway: MonaDragDropGateway?

    /// The Services gateway (P04-T009). `nil` when detached.
    internal private(set) var servicesGateway: MonaServicesGateway?

    /// The IME composition arbiter (P04-T004) over the resolver/chord/session.
    internal private(set) var compositionArbiter: MonaCompositionArbiter?

    /// The command dispatcher (A3) — the chokepoint every resolved keybinding
    /// command routes through. `nil` when detached. The `transactionGateway`
    /// is `inputBarrier.gateway` (same instance — the A3 spec §4.1 ownership
    /// ruling: the barrier owns the gateway; the dispatcher borrows it).
    internal private(set) var commandDispatcher: MonaCommandDispatcher?

    /// The AppKit text-input client (`NSTextInputClient`) over the geometry
    /// barrier. `nil` when detached.
    internal private(set) var textInputClient: MonaTextInputClient?

    /// The deterministic clock shared by the composition session, chord state,
    /// and composition arbiter.
    private let clock: () -> Double = { ProcessInfo.processInfo.systemUptime }

    /// The per-view-line pixel height used by the projection + geometry barrier.
    private let lineHeight: Int = 20

    /// The default monospace font descriptor (Menlo 12 — always present on macOS).
    private let primaryFont = MonaFontDescriptor(familyName: "Menlo", size: 12)

    // MARK: - Wiring diagnostic

    /// The number of model `onDidChangeContent` events observed while attached.
    /// Used by the lifecycle tests to assert that subscriptions are wired on
    /// attach and removed on detach (no retained closures leak). Reset on attach.
    internal private(set) var contentChangeObservations: Int = 0

    // MARK: - Init

    /// Creates the editor view with `frame`.
    public override init(frame: NSRect) {
        // Assign the stable editor id (monaco `getId()` counterpart) before
        // `commonInit()` — `id` is a `let`, so it must be assigned in the init
        // body itself, not in the helper.
        id = "monacode:editor:" + UUID().uuidString
        super.init(frame: frame)
        commonInit()
    }

    /// Creates the editor view from a decoder (Interface Builder / state restore).
    public required init?(coder: NSCoder) {
        id = "monacode:editor:" + UUID().uuidString
        super.init(coder: coder)
        commonInit()
    }

    /// Shared setup for both initializers. Creates the model-independent
    /// collaborators (renderer branch, input gateways, transfer pipeline, AX
    /// coordinators) and the attachment helper.
    private func commonInit() {
        // Renderer branch: Core Graphics tiled renderer + conditional Metal.
        renderTileCache = MonaRenderTileCache(
            maxTileCount: 64,
            maxBytes: 256 * 1024 * 1024
        )
        cgRenderer = MonaCoreGraphicsRenderer(
            tileCache: renderTileCache,
            tileSide: 256
        )
        // Default branch: Core Graphics is sufficient. Metal is triggered only
        // when the renderer-owned decision gate (P03-T010) resolves
        // `.triggeredAndRequired`; until then the Metal renderer records source
        // absence and allocates NO Metal resources.
        metalRenderer = MonaMetalRenderer(
            branch: .notTriggeredAndAbsent,
            tileSide: 256,
            cgRenderer: cgRenderer
        )

        // Input gateways.
        keyEventGateway = MonaAppKeyEventGateway()
        compositionSession = MonaCompositionSession(clock: clock)
        chordState = MonaChordState(clock: clock)
        // Driving layer (Task 4 / GAP-5): load the 379 builtin keybinding rows
        // into the resolver so `keyDown` (future task) can resolve events to
        // commands. Was `MonaKeybindingResolver()` (empty — no command could
        // ever resolve); now `MonaBuiltinKeybindings.makeResolver()`.
        keybindingResolver = MonaBuiltinKeybindings.makeResolver()
        pointerGateway = MonaPointerGateway()
        scrollGateway = MonaScrollGateway()
        contextMenuGateway = MonaContextMenuGateway()

        // Transfer (paste-edit pipeline — shared by clipboard, drop, Services).
        pasteEditPipeline = MonaPasteEditPipeline()

        // Accessibility coordinators (model-independent state machines).
        focusCoordinator = MonaAXFocusCoordinator(initial: .editor)
        announcementBridge = MonaAXAnnouncementBridge(profile: .default)

        // The attachment helper (enforces the lifetime invariants).
        attachment = MonaEditorAttachment(view: self)

        // Layer-backed rendering (driving layer — Task 2): make the view
        // layer-backed so Core Animation composites the rasterized CG tiles on
        // the GPU. Set here (after `super.init`) because the macOS 26 SDK
        // exposes `wantsLayer` as a mutable ObjC property, not an overridable
        // read-only computed property — see the `isFlipped`/`draw(_:)` section
        // below for the drift note.
        wantsLayer = true
    }

    // MARK: - Contract surface

    /// `true` while a model is attached to this view.
    public var isAttached: Bool {
        return attachment.isAttached
    }

    /// Attaches `model` to this view. The model is held weakly (borrow) — the
    /// view never owns its lifetime and never disposes it. Detaches any prior
    /// model first (idempotent). Delegates to `MonaEditorAttachment`.
    public func attach(model: MonaCodeModel) {
        attachment.attach(model: model)
    }

    /// Detaches the current model and removes every subscription registered on
    /// it, BEFORE the view tears down its model-dependent collaborators. The
    /// model is never disposed. Idempotent. Delegates to `MonaEditorAttachment`.
    public func detach() {
        attachment.detach()
    }

    // MARK: - Attachment hooks (called by MonaEditorAttachment)

    /// Creates the model-dependent subsystems over `model`: projection (view
    /// graph + vertical index), the geometry barrier, the multi-cursor input
    /// barrier, the AX element graph + mutation gateway, the clipboard /
    /// drag-drop / Services gateways, and the IME composition arbiter + text
    /// input client. Called by `MonaEditorAttachment.attach(model:)`.
    internal func performAttach(model: MonaCodeModel) {
        // Reset the wiring diagnostic.
        contentChangeObservations = 0

        // Projection: MonaViewGraph (P03-T001) owns the vertical index
        // (P03-T002) and the view-zone index.
        viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)

        // The scroll model (renderer scroll truth). Dimensions start at the
        // current view bounds; the host updates them on resize.
        let boundsSize = bounds.size
        scrollModel = MonaScrollModel(
            contentWidth: Double(max(boundsSize.width, 1)),
            contentHeight: Double(max(boundsSize.height, 1)),
            viewportWidth: Double(max(boundsSize.width, 1)),
            viewportHeight: Double(max(boundsSize.height, 1))
        )

        // Driving layer (Task 3 / GAP-2): push the initial content + viewport
        // dimensions into the scroll model and converge once, so the clamp
        // envelope + published scroll reflect the real content height (from
        // the projection's vertical index) and the real viewport (from bounds)
        // before the first draw. Subsequent updates flow through
        // `observeContentChange` (content edits) and `viewDidEndLiveResize`
        // (viewport changes).
        if let sm = scrollModel {
            _ = viewGraph?.getProjection()
            sm.setContentDimensions(
                width: Double(bounds.width),
                height: Double(viewGraph?.verticalIndex.totalHeight ?? 0)
            )
            sm.setViewportDimensions(width: Double(bounds.width), height: Double(bounds.height))
            _ = sm.converge()
        }

        // The text shaper + line layout builder feeding the geometry barrier.
        let fontFallback = MonaFontFallbackResolver(primary: primaryFont, fallback: [])
        let shaper = MonaTextShaper(
            primaryFont: primaryFont,
            fallback: fontFallback,
            direction: .ltr,
            scale: 1
        )
        let builder = MonaLineLayoutBuilder(shaper: shaper)

        // The complete-generation geometry barrier (P03-T007). The line-content
        // provider captures `model` — released when the barrier is torn down in
        // performDetach (the model's lifetime is independent: the external owner
        // keeps it alive; the view never disposes it).
        geometryBarrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph!,
            scrollModel: scrollModel!,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: { Array(model.getLineContent($0).utf16) }
        )

        // The multi-cursor input barrier (P04-T005) every input/AX mutation
        // routes through.
        inputBarrier = MonaModelInputBarrier(model: model)

        // Accessibility: the AX element graph (P04-T011) over the model + the
        // geometry barrier. The viewport-size provider reads the live view size.
        axElementGraph = MonaAXElementGraph(
            model: model,
            geometryBarrier: geometryBarrier,
            viewportSize: { [weak self] in self?.bounds.size }
        )

        // The AX mutation gateway (P04-T013) — the chokepoint for AX edits.
        axMutationGateway = MonaAXMutationGateway(
            model: model,
            barrier: inputBarrier!,
            geometryBarrier: geometryBarrier,
            focusCoordinator: focusCoordinator,
            announcementBridge: announcementBridge
        )

        // Driving layer (Task 4 / GAP-5): the command dispatcher (A3) — the
        // chokepoint every resolved keybinding command routes through.
        // `transactionGateway` is `inputBarrier.gateway` (the SAME instance —
        // the A3 spec §4.1 ownership ruling: the barrier owns the gateway; the
        // dispatcher borrows it so commits land on the same transaction
        // pipeline every other collaborator reads). `caretOps` is the
        // stateless `MonaCaretOperationsFeature()` (no-arg init).
        commandDispatcher = MonaCommandDispatcher(
            model: model,
            inputBarrier: inputBarrier!,
            transactionGateway: inputBarrier!.gateway,
            caretOps: MonaCaretOperationsFeature()
        )

        // Transfer: clipboard + drag/drop + Services. The pasteboard gateway
        // and paste-edit pipeline are shared so a provider registered once
        // applies to clipboard paste, drop, AND Services.
        pasteboardGateway = MonaPasteboardGateway()
        dragDropGateway = MonaDragDropGateway()
        servicesGateway = MonaServicesGateway(
            pasteboardGateway: pasteboardGateway!,
            pipeline: pasteEditPipeline
        )

        // IME: the composition arbiter (P04-T004) over the resolver/chord/session.
        compositionArbiter = MonaCompositionArbiter(
            resolver: keybindingResolver,
            chordState: chordState,
            session: compositionSession,
            clock: clock
        )

        // The AppKit text-input client over the geometry barrier.
        textInputClient = MonaTextInputClient(
            geometryProvider: geometryBarrier!,
            documentTextProvider: { model.getValue() },
            documentSelectionProvider: { NSRange(location: 0, length: 0) }
        )
    }

    /// Releases the model-dependent subsystems (does NOT dispose the model —
    /// its lifetime is owned outside the view). Called by
    /// `MonaEditorAttachment.detach()` AFTER every subscription has been
    /// detached. Also used as a safety net during `deinit`.
    internal func performDetach() {
        viewGraph = nil
        scrollModel = nil
        geometryBarrier = nil
        inputBarrier = nil
        axElementGraph = nil
        axMutationGateway = nil
        pasteboardGateway = nil
        dragDropGateway = nil
        servicesGateway = nil
        compositionArbiter = nil
        textInputClient = nil
        commandDispatcher = nil
    }

    /// Hook invoked by the attachment when a model `onDidChangeContent` event
    /// fires while attached. Invalidates the projection: republishes the
    /// geometry generation so subsequent queries reflect the new model state.
    /// Also bumps the wiring diagnostic the lifecycle tests assert on.
    ///
    /// Driving layer (Task 3 / GAP-2 + GAP-3): after republishing the
    /// generation, pushes the refreshed content dimensions (content height
    /// from `viewGraph.verticalIndex.totalHeight`, content width from the
    /// visible records' max line width) into `scrollModel`, converges so the
    /// clamp envelope + published scroll reflect the new content, and finally
    /// sets `needsDisplay = true` so AppKit schedules a redraw. This is the
    /// load-bearing repaint trigger for content edits. (The brief's
    /// `setNeedsDisplay(true)` is an API drift — see the `needsDisplay`
    /// override doc below.)
    internal func observeContentChange() {
        contentChangeObservations &+= 1
        // Invalidate the projection: republish the complete generation so the
        // next geometry/render query reflects the new model state. The barrier
        // rebuilds from the view graph (which reads the live model).
        if let barrier = geometryBarrier {
            _ = barrier.publishGeneration(visibleViewLines: nil)
        }
        // Push refreshed content dimensions + converge + schedule a redraw.
        if let sm = scrollModel, let vg = viewGraph {
            _ = vg.getProjection()
            let contentH = Double(vg.verticalIndex.totalHeight)
            let contentW = Double(max(Int(bounds.width), maxVisibleLineWidth(in: geometryBarrier)))
            sm.setContentDimensions(width: contentW, height: contentH)
            _ = sm.converge()
        }
        needsDisplay = true
    }

    /// Returns the maximum `totalWidth` across the barrier's current snapshot
    /// records (the visible-only approach per spec §4 Ruling #2 — NOT an O(n)
    /// shaping pass over all lines; only lines already materialized in the
    /// snapshot are considered). Falls back to the view bounds width when no
    /// snapshot or no records are available, so the content width is never
    /// smaller than the viewport (scroll clamp stays sane).
    private func maxVisibleLineWidth(in barrier: MonaQueryGeometryBarrier?) -> Int {
        guard let snap = barrier?.snapshot() else { return Int(bounds.width) }
        return snap.records.values.map { Int($0.totalWidth) }.max() ?? Int(bounds.width)
    }

    // MARK: - Layer-backed rendering (driving layer — Task 2)

    /// Layer-backed: Core Animation composites the view's layer (and the
    /// rasterized tiles blitted in `draw(_:)`) on the GPU. The layer hosts the
    /// CG bitmap tiles painted by `MonaCoreGraphicsRenderer`.
    ///
    /// API drift: in the macOS 26 SDK `NSView.wantsLayer` is a mutable ObjC
    /// `@property BOOL` (read-write), so it cannot be overridden as a read-only
    /// computed property. The view is made layer-backed by setting
    /// `wantsLayer = true` in `commonInit()` (the idiomatic AppKit pattern),
    /// which achieves the same layer-backed compositing behavior the brief's
    /// `override var wantsLayer: Bool { true }` intended.

    /// The view's coordinate system is flipped (y-down), matching AppKit's text
    /// layout convention (origin at the top-left). The renderer's tile bitmaps
    /// are y-up (Core Graphics native space), so `draw(_:)` applies a y-flip
    /// transform when blitting each tile.
    override public var isFlipped: Bool { true }

    /// Overridden so an explicit redraw request (set in `observeContentChange`
    /// and `viewDidEndLiveResize` via `needsDisplay = true`) is observable as
    /// `needsDisplay == true` until `draw(_:)` consumes it.
    ///
    /// Driving layer (Task 3 / GAP-3): the brief used `setNeedsDisplay(true)`.
    /// In the macOS 26 SDK `NSView.setNeedsDisplay(_:)` takes an `NSRect` (the
    /// dirty rect), not a `Bool` — the Bool overload was removed. Setting
    /// `needsDisplay = true` is the idiomatic replacement, but in a headless
    /// test context (no window / no display cycle) AppKit resets
    /// `super.needsDisplay` to `false` immediately, so the redraw request is not
    /// observable. The override adds a sticky `_redrawRequested` flag that is
    /// set by the setter and cleared at the top of `draw(_:)`, so
    /// `needsDisplay` reads `true` between a redraw request and the next draw
    /// in BOTH production (with a window) and headless tests. In production
    /// `super.needsDisplay` is also honored, so AppKit-driven dirty rects still
    /// work; the flag only adds fidelity, it never suppresses a real dirty state.
    override public var needsDisplay: Bool {
        get { super.needsDisplay || _redrawRequested }
        set {
            _redrawRequested = newValue
            super.needsDisplay = newValue
        }
    }
    private var _redrawRequested: Bool = false

    /// The visible-tile blit pipeline. Renders the complete generation's
    /// visible view-line records into generation-keyed tiles via the Core
    /// Graphics renderer, then composites each tile's `cgImage` into the
    /// current `NSGraphicsContext`.
    ///
    /// Algorithm (one snapshot per drawRect, not per tile):
    ///   1. Compute the visible view-line range from scroll + viewport via
    ///      `verticalIndex` (O(log n) bounds).
    ///   2. `publishGeneration(visibleViewLines:)` — freeze the generation and
    ///      pre-build the visible records.
    ///   3. Advance the tile cache generation + invalidate stale tiles.
    ///   4. `barrier.snapshot()` — read records + verticalIndex ONCE.
    ///   5. Pre-compute visible lines + their `verticalOffsetForViewLine`.
    ///   6. Per-tile: partition visible lines by tile y-band → tile-local
    ///      records + lineOrigins (tile-local: `origin.y = offY - tileY*ts`,
    ///      `origin.x = -tileX*ts`; subpixel phase 0 for v1 integer-pixel).
    ///   7. `cgRenderer.tile(...)` → `tile.surface.cgImage` → `ctx.draw(...)`
    ///      with a y-flip transform (tile bitmap is y-up, view is y-down).
    ///
    /// Subpixel phase is fixed at 0 for v1 integer-pixel rendering (maximizes
    /// cache reuse; a subpixel phase change forces a re-rasterization).
    override public func draw(_ dirtyRect: NSRect) {
        // Consume the sticky redraw-request flag (set by `observeContentChange`
        // / `viewDidEndLiveResize` via the `needsDisplay` override). The view is
        // now drawing, so the explicit request is satisfied; `super.needsDisplay`
        // is managed by AppKit's display cycle.
        _redrawRequested = false
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
        // Pre-compute visible lines + their vertical offset ONCE (O(visible ×
        // log n)) rather than per-tile. Lines without a record are skipped at
        // the tile-partition step below.
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
                // Partition: lines whose vertical offset falls in this tile's
                // y-band `[tileY*ts, (tileY+1)*ts)`. Origins are TILE-LOCAL
                // (the renderer paints in tile-local CG-native space):
                //   origin.y = verticalOffsetForViewLine(L) - tileY * ts
                //   origin.x = -tileX * ts
                var tileRecords: [MonaLineLayoutRecord] = []
                var tileOrigins: [CGPoint] = []
                for (L, offY) in visibleLineInfo where offY >= tileY * ts && offY < (tileY + 1) * ts {
                    if let rec = records[L] {
                        tileRecords.append(rec)
                        tileOrigins.append(CGPoint(x: CGFloat(-tileX * ts), y: CGFloat(offY - tileY * ts)))
                    }
                }
                guard !tileRecords.isEmpty else { continue }
                let key = MonaRenderTileKey(
                    generation: gen,
                    tileX: tileX,
                    tileY: tileY,
                    scale: scale,
                    subpixelPhaseX: 0,
                    subpixelPhaseY: 0
                )
                let tile = cg.tile(for: key, records: tileRecords, lineOrigins: tileOrigins, layerInputs: .init())
                guard let img = tile.surface.cgImage else { continue }
                // Destination in view space (scroll-adjusted). The tile bitmap
                // is y-up (CG native); the view is y-down (`isFlipped`). Flip
                // the bitmap around `dest.midY` so it composites upright.
                let dest = CGRect(
                    x: CGFloat(tileX * ts) - CGFloat(scrollX),
                    y: CGFloat(tileY * ts) - CGFloat(scrollY),
                    width: CGFloat(ts),
                    height: CGFloat(ts)
                )
                ctx.saveGState()
                ctx.translateBy(x: 0, y: dest.midY)
                ctx.scaleBy(x: 1, y: -1)
                ctx.translateBy(x: 0, y: -dest.midY)
                ctx.draw(img, in: dest)
                ctx.restoreGState()
            }
        }
    }

    // MARK: - Live resize (driving layer — Task 3 / GAP-2)

    /// Pushed by AppKit after a live resize (window drag/edge resize) finishes.
    /// Driving layer (Task 3 / GAP-2): the viewport dimensions changed, so push
    /// the new bounds into `scrollModel`, converge so the clamp envelope + the
    /// published scroll reflect the new viewport, republish the geometry
    /// generation (the visible view-line range may have changed), and schedule
    /// a redraw. Content dimensions are NOT recomputed here — content width/height
    /// only change on content edits (handled by `observeContentChange`), not on
    /// viewport resizes.
    ///
    /// API drift: the brief used `setNeedsDisplay(true)`. In the macOS 26 SDK
    /// `NSView.setNeedsDisplay(_:)` takes an `NSRect` (the dirty rect), not a
    /// `Bool` — the Bool overload was removed. Setting `needsDisplay = true`
    /// achieves the same "mark the whole view dirty" intent idiomatically.
    override public func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        if let sm = scrollModel {
            sm.setViewportDimensions(width: Double(bounds.width), height: Double(bounds.height))
            _ = sm.converge()
        }
        _ = geometryBarrier?.publishGeneration(visibleViewLines: nil)
        needsDisplay = true
    }

    // MARK: - Deinit (safety net)

    deinit {
        // Detach every subscription before the view is torn down. `detach()`
        // is idempotent: a no-op when not attached, and safe even if the
        // attachment already detached. The model is NEVER disposed here.
        detach()
    }
}
