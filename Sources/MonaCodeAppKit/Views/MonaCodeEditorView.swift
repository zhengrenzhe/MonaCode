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
        super.init(frame: frame)
        commonInit()
    }

    /// Creates the editor view from a decoder (Interface Builder / state restore).
    public required init?(coder: NSCoder) {
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
        keybindingResolver = MonaKeybindingResolver()
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
    }

    /// Hook invoked by the attachment when a model `onDidChangeContent` event
    /// fires while attached. Invalidates the projection: republishes the
    /// geometry generation so subsequent queries reflect the new model state.
    /// Also bumps the wiring diagnostic the lifecycle tests assert on.
    internal func observeContentChange() {
        contentChangeObservations &+= 1
        // Invalidate the projection: republish the complete generation so the
        // next geometry/render query reflects the new model state. The barrier
        // rebuilds from the view graph (which reads the live model).
        if let barrier = geometryBarrier {
            _ = barrier.publishGeneration(visibleViewLines: nil)
        }
    }

    // MARK: - Deinit (safety net)

    deinit {
        // Detach every subscription before the view is torn down. `detach()`
        // is idempotent: a no-op when not attached, and safe even if the
        // attachment already detached. The model is NEVER disposed here.
        detach()
    }
}
