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
        //
        // Driving layer (Task 6 / GAP-5):
        //   - `documentSelectionProvider` reads the REAL selection from
        //     `inputBarrier.gateway.lastCommittedSelections` (was hardcoded to
        //     `(0,0)`), converting the MonaSelection (line/column) to a UTF-16
        //     NSRange via `selectionToNSRange`. Falls back to `(0,0)` when no
        //     selection is committed or the view/model is tearing down.
        //   - `textInsertionProvider` routes `insertText(_:replacementRange:)`
        //     to the command dispatcher's `type` command — the same chokepoint
        //     every resolved keybinding command routes through (Task 4).
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
            textInsertionProvider: { [weak self] text, _ in
                self?.commandDispatcher?.execute("type", args: ["text": text])
            }
        )
    }

    /// Converts a `MonaSelection` (anchor + active position) to a UTF-16
    /// `NSRange` using the model's `getOffsetAt` (0-based UTF-16 offset, per
    /// `MonaCodeModel.getOffsetAt` / Piece Tree `getOffsetAt`). The anchor +
    /// active positions are normalized so the range is forward regardless of
    /// the selection orientation — `NSTextInputClient` semantics are
    /// orientation-agnostic.
    ///
    /// Driving layer (Task 6 / GAP-5): replaces the hardcoded `(0,0)` the
    /// `selectedRange` selector used to report. Returns `(0,0)` when no model
    /// is attached (the client is tearing down).
    private func selectionToNSRange(_ sel: MonaSelection) -> NSRange {
        guard let model = attachment.attachedModel else {
            return NSRange(location: 0, length: 0)
        }
        let startOffset = model.getOffsetAt(sel.anchor)
        let endOffset = model.getOffsetAt(sel.activePosition)
        let loc = min(startOffset, endOffset)
        let len = abs(endOffset - startOffset)
        return NSRange(location: loc, length: len)
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

    // MARK: - keyDown + dispatchKeyEvent (driving layer — Task 5)

    /// The keyboard entry point of the AppKit responder chain.
    ///
    /// Driving layer (Task 5 / GAP-5): translates the native `NSEvent` into a
    /// platform-neutral `MonaKeyEvent` via `keyEventGateway` (exactly once —
    /// the gateway is the single translation point), then delegates the
    /// 7-step dispatch to `dispatchKeyEvent(_:source:)`.
    ///
    /// When no model is attached the view is dormant: it forwards to
    /// `super.keyDown(with:)` (the default NSResponder behavior) and returns —
    /// none of the model-dependent collaborators (composition arbiter,
    /// command dispatcher) exist yet.
    ///
    /// `isComposing` is sourced from the composition arbiter's
    /// `hasActiveComposition` so the gateway stamps the event with the live IME
    /// state (NSEvent itself carries no composition flag).
    override public func keyDown(with event: NSEvent) {
        guard isAttached else { super.keyDown(with: event); return }
        let isComposing = compositionArbiter?.hasActiveComposition ?? false
        let key = keyEventGateway.translateKeyDown(event, isComposing: isComposing)
        dispatchKeyEvent(key, source: event)
    }

    /// The 7-step keyboard dispatch branch (spec §3.2).
    ///
    /// Routes one `MonaKeyEvent` through the composition arbiter and acts on
    /// the returned `MonaCompositionArbitration`:
    ///
    ///   1. `.dispatched` — a command matched and no composition was active;
    ///      execute the command via the dispatcher.
    ///   2. `.committedThenDispatched` — a command matched during an active
    ///      composition; the arbiter already committed the composition, so
    ///      insert the committed text through the text-input client FIRST,
    ///      then execute the command.
    ///   3. `.passThrough` — no command matched and no composition; if the key
    ///      produced text and is not an IME-composing event, route the text
    ///      through the `type` command (the same chokepoint resolved
    ///      keybindings use); otherwise fall back to `super.keyDown(with:)`.
    ///   4. `.absorbedByComposition` — the IME owns the event; feed it to
    ///      `interpretKeyEvents(_:)` so AppKit drives the marked-text
    ///      selectors on this view (NSTextInputClient conformance from Task 6).
    ///   5. `.noOp` — the session is disposed or unable to arbitrate; fall
    ///      back to `super.keyDown(with:)`.
    ///
    /// Finally the derived `dispatchOutcome` is applied through the gateway
    /// to obtain the native `MonaAppKeyDispatchAction`. The switch above
    /// already honors `preventDefault` (no `super.keyDown` for the handled
    /// cases) and `stopPropagation` (no `nextResponder` forwarding — implicit,
    /// since `super` is not called for handled cases), so the resulting
    /// `action` is the documented bridge value; its flags are not re-checked.
    ///
    /// `internal` (not `private`) so the driving-layer tests can drive it
    /// directly via `@testable import` (constructing a `MonaKeyEvent` and
    /// calling `dispatchKeyEvent(_:source:)` without synthesizing an
    /// `NSEvent`).
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
        // Apply the derived dispatch outcome through the gateway (the single
        // native-boundary translation point). The switch above already honors
        // preventDefault/stopPropagation, so the resulting action's flags are
        // not re-checked — the call documents the bridge and keeps the gateway
        // the authoritative translator.
        _ = keyEventGateway.apply(arbitration.dispatchOutcome)
    }

    // MARK: - Mouse + flags overrides (driving layer — Task 7 / §3.3)
    //
    // The pointer entry points of the AppKit responder chain. Each override
    // translates the native `NSEvent` into a platform-neutral `MonaPointerEvent`
    // via `pointerGateway` (the single translation point — stateless pure,
    // spec §8.3 :178), resolves the viewport point to a model position through
    // `geometryBarrier` (`hitTest` — `resolvedPosition` nil = no generation /
    // OOB → no-op :244-246), and acts on the resolved position.
    //
    // Selection-set path (spec §3.3 + §5 hard-truth #7 — NO cursor host):
    // pointer sets an ABSOLUTE position, so it uses the LOW-LEVEL gateway path
    // (`beginTransaction → prepareSelections → commit`) on the SAME
    // `inputBarrier.gateway` instance every other collaborator reads — NOT
    // `commitCaretMove` (relative-only, would need a cursor host to interpret
    // a direction). For `mouseDown` the selection is a collapsed caret
    // (`anchor == activePosition == pos`); for `mouseDragged` it extends from
    // the stored `downPosition` to the current position. `lastCommittedSelections`
    // is the post-commit truth the next input / AX mutation reads.

    /// The model position captured at the last `mouseDown` — the anchor for
    /// drag extension (`mouseDragged` builds `MonaSelection(anchor: downPosition,
    /// activePosition: currentPos)`). Cleared on `mouseUp` so the next click
    /// starts a fresh selection. `nil` when no drag is in progress.
    private var downPosition: MonaPosition?

    /// A button press. Translates the event, resolves the viewport point to a
    /// model position through the geometry barrier, sets a collapsed caret at
    /// that position via the low-level gateway path, schedules a redraw, and
    /// stores the position for drag extension.
    ///
    /// No-op when not attached or when the barrier cannot resolve the position
    /// (typed unavailable — no stale caret is synthesized).
    override public func mouseDown(with event: NSEvent) {
        guard isAttached,
              let gw = pointerGateway,
              let barrier = geometryBarrier,
              let input = inputBarrier else { return }
        let vp = convert(event.locationInWindow, from: nil)
        let pe = gw.translate(event, phase: .down, viewportPoint: vp, resolvingPositionThrough: barrier)
        guard let pos = pe.resolvedPosition else { return }
        // GAP-5 / §5 hard-truth #7: pointer sets ABSOLUTE position → low-level
        // gateway path (NOT commitCaretMove — relative-only, needs a cursor
        // host). begin → prepareSelections([collapsed caret]) → commit on the
        // SAME gateway every other collaborator reads (inputBarrier.gateway).
        let sel = MonaSelection(anchor: pos, activePosition: pos)
        let tx = input.gateway.beginTransaction()
        tx.prepareSelections([sel])
        _ = input.gateway.commit(tx)  // → lastCommittedSelections = [sel]
        needsDisplay = true
        downPosition = pos  // for drag extension
    }

    /// A movement with the button held. Translates the event (`.dragged`
    /// phase), resolves the position, and extends the selection from the stored
    /// `downPosition` to the current position. No-op when not attached, when no
    /// `downPosition` is stored (no preceding `mouseDown`), or when the barrier
    /// cannot resolve the position.
    override public func mouseDragged(with event: NSEvent) {
        guard isAttached,
              let gw = pointerGateway,
              let barrier = geometryBarrier,
              let input = inputBarrier,
              let down = downPosition else { return }
        let vp = convert(event.locationInWindow, from: nil)
        let pe = gw.translate(event, phase: .dragged, viewportPoint: vp, resolvingPositionThrough: barrier)
        guard let pos = pe.resolvedPosition else { return }
        // Extend the selection: anchor stays at the press position, active
        // tracks the current position. Same low-level gateway path as mouseDown.
        let sel = MonaSelection(anchor: down, activePosition: pos)
        let tx = input.gateway.beginTransaction()
        tx.prepareSelections([sel])
        _ = input.gateway.commit(tx)
        needsDisplay = true
    }

    /// A button release. The selection was already finalized by the last
    /// `mouseDragged` (or by `mouseDown` itself when no drag followed); this
    /// clears the stored `downPosition` so the next click starts a fresh
    /// selection. monaco's `mouseUp` also dispatches selection-change / copy
    /// events; those are deferred (B1 features).
    override public func mouseUp(with event: NSEvent) {
        guard isAttached else { return }
        downPosition = nil
    }

    /// A right-button press. Translates the event, resolves the position, and
    /// presents the context menu at the resolved caret rect via
    /// `contextMenuGateway.present` (:223). The menu is NOT presented when the
    /// barrier cannot resolve the position (no stale popup location).
    ///
    /// API drift: spec §3.3 used `MonaAppMenuModel.builtin` — no such static
    /// exists. v1 presents an empty menu (the context-menu feature
    /// `MonaContextmenuFeature.buildAppMenuModel(context:)` is not wired into
    /// the view yet; a future task adapts the Core `MonaMenuModel` to
    /// `MonaAppMenuModel`). The gateway still resolves the caret rect and pops
    /// the menu — the path is exercised; only the content is empty.
    override public func rightMouseDown(with event: NSEvent) {
        guard isAttached,
              let gw = pointerGateway,
              let barrier = geometryBarrier,
              let cmg = contextMenuGateway else { return }
        let vp = convert(event.locationInWindow, from: nil)
        let pe = gw.translate(event, phase: .down, viewportPoint: vp, resolvingPositionThrough: barrier)
        guard let pos = pe.resolvedPosition else { return }
        let menu = cmg.buildMenu(from: MonaAppMenuModel(items: []))
        _ = cmg.present(menu: menu, at: pos, in: self, with: barrier)
    }

    /// A movement with no button held. Translates the event (`.moved` phase)
    /// and resolves the position so the gateway is exercised; hover staging is
    /// deferred (spec §3.3: "MonaHoverFeature — if available"). The view does
    /// not yet own a `MonaHoverFeature`; a future task wires `stageHover` when
    /// hover providers land. No redraw is scheduled (no region changed yet).
    override public func mouseMoved(with event: NSEvent) {
        guard isAttached,
              let gw = pointerGateway,
              let barrier = geometryBarrier else { return }
        let vp = convert(event.locationInWindow, from: nil)
        let pe = gw.translate(event, phase: .moved, viewportPoint: vp, resolvingPositionThrough: barrier)
        // Hover feature not wired (§3.3 "if available"). v1: resolve the
        // position so the pointer gateway is the single translation point;
        // a future task stages a hover when MonaHoverFeature lands.
        _ = pe.resolvedPosition
    }

    /// The pointer left the view. Clears hover state when a hover feature is
    /// wired (§3.3 "if available"). v1: no-op (no hover feature yet).
    override public func mouseExited(with event: NSEvent) {
        guard isAttached else { return }
        // Hover feature not wired (§3.3 "if available"). v1: no-op; a future
        // task calls MonaHoverFeature.releaseHover / clears the staged hover.
    }

    /// A modifier-only key press/release (Shift/Cmd/Alt/Ctrl). No `keyText` →
    /// no `type` command, but the modifier change may invalidate the active
    /// chord's when-clause → re-evaluate the chord via `keybindingResolver`
    /// (:254). Forwards to `super` when not attached.
    override public func flagsChanged(with event: NSEvent) {
        guard isAttached else { super.flagsChanged(with: event); return }
        _ = keybindingResolver.reevaluateActiveChord(context: keybindingContext, chordState: chordState)
    }

    // MARK: - scrollWheel + tracking areas + cursor rects (driving layer — Task 8 / §3.4 + §3.7)

    /// A scroll-wheel (or trackpad) gesture. Translates the native `NSEvent`
    /// into a platform-neutral `MonaScrollEvent` via `scrollGateway` (the single
    /// translation point — stateless pure, spec §8.3 :185), then drives the
    /// scroll model and the geometry barrier in the GAP-3 / GAP-4 order:
    ///
    ///   1. `requestScroll(x: published + deltaX, y: published + deltaY)` —
    ///      accumulate the delta onto the LAST published position (NOT the
    ///      requested position — `published` is the converged truth; `requested`
    ///      may lag by one converge and would drop deltas on rapid input).
    ///   2. `converge()` — pull-only (GAP-3: no emitter/onChange), so the caller
    ///      invokes it and reads the returned `MonaScrollChangeEvent`.
    ///   3. `setNeedsDisplay` ONLY when the published scroll actually moved
    ///      (the request may have been clamped at the content boundary — no
    ///      redraw for a no-op scroll). `prevX/prevY` are captured BEFORE
    ///      `requestScroll` so the comparison sees the pre-converge position.
    ///   4. `publishGeneration(visibleViewLines: nil)` — GAP-4 (critical): after
    ///      `converge` moves `publishedScrollY`, the barrier's frozen
    ///      `scrollOffsetX/Y` (captured at `publishGeneration` :285-286) are
    ///      STALE until the next `publishGeneration`. Refresh them now so the
    ///      next `mouseDown` hit-tests against the NEW scroll, not the stale one.
    ///
    /// Delta normalization is the gateway's job (precise ÷40, coarse verbatim,
    /// direction NOT reversed — spec §8.3 :249/:277-279); the view never touches
    /// `NSEvent.scrollingDeltaY`. No-op when not attached.
    override public func scrollWheel(with event: NSEvent) {
        guard isAttached,
              let gw = scrollGateway,
              let sm = scrollModel,
              let barrier = geometryBarrier else { return }
        let vp = convert(event.locationInWindow, from: nil)
        let se = gw.translate(event, viewportPoint: vp, resolvingPositionThrough: barrier)
        // GAP-3: converge is pull-only — the caller must invoke it + schedule
        // the redraw. Capture the pre-converge published position so the redraw
        // is gated on an ACTUAL move (clamped-at-boundary no-ops are skipped).
        let prevX = sm.publishedScrollX
        let prevY = sm.publishedScrollY
        sm.requestScroll(x: prevX + se.deltaX, y: prevY + se.deltaY)
        let evt = sm.converge()
        if evt.publishedScrollX != prevX || evt.publishedScrollY != prevY {
            needsDisplay = true  // scroll moved → redraw
        }
        // GAP-4: converge moved publishedScrollX/Y → the barrier's frozen
        // scrollOffsetX/Y (captured at publishGeneration :285-286) are STALE
        // until the next publishGeneration. Refresh so the next mouseDown
        // hit-tests against the new scroll.
        _ = barrier.publishGeneration(visibleViewLines: nil)
    }

    /// Refreshes the tracking areas + the frozen geometry + the scroll clamp
    /// envelope on AppKit's schedule (view setup, live resize, layer geometry
    /// change). Spec §3.7 order:
    ///   1. remove the tracking areas this view owns (stale bounds),
    ///   2. add one fresh `NSTrackingArea` over `bounds` with the options that
    ///      feed `mouseMoved` / `mouseEnteredAndExited` (the hover staging
    ///      surface, §3.3) while active in the key window, visible-rect-tracked,
    ///      and enabled during a mouse drag (so drag-selection keeps receiving
    ///      `mouseMoved`-class events),
    ///   3. `publishGeneration(nil)` — refresh the barrier's frozen scroll +
    ///      visible records for the current bounds,
    ///   4. `setViewportDimensions(bounds)` — push the new viewport into the
    ///      scroll clamp envelope,
    ///   5. `converge()` — re-clamp + re-publish the scroll for the new viewport.
    ///
    /// `.inVisibleRect` keeps the tracking rect in sync with the visible
    /// (scrolled) portion of the view automatically; the `rect: bounds` seed is
    /// the full bounds, which `.inVisibleRect` then tracks.
    ///
    /// API drift: the brief used `.enabledDuringMouseDragged` (with a trailing
    /// "d"). The macOS 26 SDK Swift overlay names the option
    /// `.enabledDuringMouseDrag` (matching the ObjC
    /// `NSTrackingEnabledDuringMouseDrag` minus the `NSTracking` prefix — no
    /// trailing "d"); the "Dragged" form does not resolve.
    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Remove the tracking areas this view owns (`owner === self`).
        // `trackingAreas` returns a snapshot array, so mutation during
        // iteration is safe.
        for ta in trackingAreas where ta.owner === self {
            removeTrackingArea(ta)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        _ = geometryBarrier?.publishGeneration(visibleViewLines: nil)
        scrollModel?.setViewportDimensions(width: Double(bounds.width), height: Double(bounds.height))
        _ = scrollModel?.converge()
    }

    /// Installs the I-beam cursor over the view bounds (the code-editor
    /// convention: the pointer is a text caret wherever it hovers over text).
    /// AppKit calls this on cursor rect invalidation; the override installs one
    /// cursor rect covering the whole bounds so the I-beam is the default
    /// pointer shape across the editor surface.
    ///
    /// API drift: the brief used `NSCursor.IBeamCursor`. In the macOS 26 SDK the
    /// Swift overlay renamed the `IBeamCursor` class property to `iBeam` (the
    /// ObjC name `IBeamCursor` is preserved in the header, but Swift imports it
    /// as `iBeam`); `NSCursor.iBeam` is the renamed accessor.
    override public func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: NSCursor.iBeam)
    }

    // MARK: - Deinit (safety net)

    deinit {
        // Detach every subscription before the view is torn down. `detach()`
        // is idempotent: a no-op when not attached, and safe even if the
        // attachment already detached. The model is NEVER disposed here.
        detach()
    }
}

// MARK: - NSTextInputClient conformance (driving layer — Task 6 / GAP-5)
//
// The view is the `NSTextInputClient` AppKit's `interpretKeyEvents` talks to
// (approach (b) — see `MonaTextInputClient`'s class doc for why the client
// itself cannot conform under the macOS 26 SDK: `hasMarkedText`/`markedRange`/
// `selectedRange` are imported as protocol *methods*, which would force
// converting the client's property accessors to methods and break the P04-T004
// composition tests). Every selector is forwarded to the `MonaTextInputClient`
// the view owns; the client owns the implementations, the view is the ObjC
// boundary.
//
// `insertText(_:replacementRange:)` forwards to the client, whose
// `textInsertionProvider` routes it to the command dispatcher's `type`
// command — the same chokepoint every resolved keybinding command routes
// through (Task 4). `doCommand(by:)` and `validAttributesForMarkedText()` have
// no client counterpart and are v1 no-ops/stubs (default command handling and
// marked-text attribute negotiation are deferred; `interpretKeyEvents` is not
// yet wired from a `keyDown` override, so this conformance is dormant until a
// future driving-layer task drives it).
//
// `@preconcurrency`: the `NSTextInputClient` ObjC protocol's requirements are
// `nonisolated`, but `NSView` (and so this view's methods) are
// `@MainActor`-isolated. Swift 6 would reject the cross-isolation conformance
// as a data-race hazard; `@preconcurrency` downgrades it to a warning (AppKit
// always calls these selectors synchronously on the main thread, so the
// hazard is theoretical — the runtime contract matches the static isolation).
extension MonaCodeEditorView: @preconcurrency NSTextInputClient {

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        textInputClient?.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    public func unmarkText() {
        textInputClient?.unmarkText()
    }

    public func hasMarkedText() -> Bool {
        return textInputClient?.hasMarkedText ?? false
    }

    public func markedRange() -> NSRange {
        return textInputClient?.markedRange ?? .notFound
    }

    public func selectedRange() -> NSRange {
        return textInputClient?.selectedRange ?? NSRange(location: 0, length: 0)
    }

    public func attributedSubstring(
        forProposedRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSAttributedString? {
        return textInputClient?.attributedSubstring(forProposedRange: range, actualRange: actualRange)
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        return textInputClient?.firstRect(forCharacterRange: range, actualRange: actualRange) ?? .zero
    }

    public func characterIndex(for point: NSPoint) -> Int {
        return textInputClient?.characterIndex(for: point) ?? NSNotFound
    }

    /// Routes the inserted text to the command dispatcher's `type` command
    /// via the client's `textInsertionProvider`. Forwards to the client, which
    /// coerces the `Any` argument to a `String` and calls the provider.
    public func insertText(_ string: Any, replacementRange: NSRange) {
        textInputClient?.insertText(string, replacementRange: replacementRange)
    }

    /// v1 returns no attributes — the client's `coerceMarkedText` builds plain
    /// `NSAttributedString(string:)` with no attribute keys, so `[]` is
    /// honest. Rich marked-text attributes are deferred.
    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        return []
    }
}
