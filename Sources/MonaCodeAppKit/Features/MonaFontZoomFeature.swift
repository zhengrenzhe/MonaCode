// MonaFontZoomFeature.swift
//
// P05-T120 — Implement retained feature fontZoom.
//
// `MonaFontZoomFeature` is the Swift counterpart of Monaco's `fontZoom`
// contribution (monaco-editor 0.56.0): it applies a bounded editor font zoom
// and invalidates the EXACT layout stamp domains a font change dirties. The
// zoom is clamped to the frozen `[minZoom, maxZoom]` bounds (matching Monaco's
// `MAX_FONT_ZOOM`), and the invalidation set is the frozen edge set for the
// `fontChanged` mutation in `MonaDependencyStampEdgeMap` (P03-T004) — geometry,
// scrollDimension, and frame — no missing, no fanout.
//
// The stamp domains are the seven dependency-stamp domains from P03-T004
// (`MonaStampDomain`: projection, vertical, scrollDimension, geometry, paint,
// surface, frame). A font zoom changes the font descriptor, so the
// `fontChanged` mutation applies; the edge map is the single source of truth
// for which domains it dirties.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `zoomIn` / `zoomOut` / `applyZoom` /
//      `resetZoom` / `invalidatedDomainsForZoomChange` /
//      `validateStampInvalidation`: apply a bounded font zoom and invalidate
//      the exact layout stamp domains the `fontChanged` mutation dirties.
//   2. Register the exact feature identity `fontZoom` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// A font-zoom event: the applied zoom factor and the exact layout stamp
/// domains invalidated by the zoom change.
public struct MonaFontZoomEvent: Equatable {

    /// The applied zoom factor (clamped to `[minZoom, maxZoom]`).
    public let zoom: Double

    /// The exact stamp domains invalidated by the zoom change (the frozen
    /// `fontChanged` edge set: geometry, scrollDimension, frame), in
    /// `MonaStampDomain.allCases` order.
    public let invalidatedDomains: [MonaStampDomain]

    public init(zoom: Double, invalidatedDomains: [MonaStampDomain]) {
        self.zoom = zoom
        self.invalidatedDomains = invalidatedDomains
    }
}

/// The fontZoom feature: apply a bounded editor font zoom and invalidate the
/// exact layout stamp domains.
///
/// The feature identity `fontZoom` and its declared slice are referenced
/// verbatim from the frozen registries. The zoom is clamped to
/// `[minZoom, maxZoom]`; each zoom change fires an event carrying the applied
/// zoom and the exact invalidated domains (the frozen `fontChanged` edge set).
/// Model mutation is routed through `MonaTransactionGateway`; asynchronous
/// publication through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal
/// through `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaFontZoomFeature: MonaDisposable {

    /// The frozen feature identity (`"fontZoom"`).
    public static let featureId = "fontZoom"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The three
    /// font-zoom actions: zoom in, zoom out, and reset.
    public static let declaredActionIds: [String] = [
        "editor.action.fontZoomIn",
        "editor.action.fontZoomOut",
        "editor.action.fontZoomReset"
    ]

    /// The declared command IDs in source order. The three font-zoom actions are
    /// all registered as editor commands, so this slice equals `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution IDs. fontZoom owns no contribution of its own
    /// (the zoom is applied through the `EditorZoom` service), so this slice is
    /// empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — fontZoom carries no default keybindings
    /// (its actions are unbound), so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — fontZoom owns no editor options, so this slice
    /// is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — fontZoom registers no menu items, so this slice
    /// is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Zoom bounds

    /// The minimum zoom factor (50%). A conservative lower bound below the
    /// default `1.0`, allowing zoom-out.
    public static let minZoom: Double = 0.5

    /// The maximum zoom factor (800%), matching Monaco's `MAX_FONT_ZOOM`.
    public static let maxZoom: Double = 8.0

    /// The zoom step per `zoomIn` / `zoomOut` call (10%).
    public static let zoomStep: Double = 0.1

    /// The default (no-zoom) factor.
    public static let defaultZoom: Double = 1.0

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaFontZoomEvent>()

    /// The event stream for font-zoom changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaFontZoomEvent> { emitter.event }

    private var _currentZoom: Double = MonaFontZoomFeature.defaultZoom
    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the fontZoom feature at the default zoom (`1.0`).
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The current (clamped) zoom factor.
    public var currentZoom: Double {
        _lock.lock(); defer { _lock.unlock() }
        return _currentZoom
    }

    // MARK: - 1. Feature-specific behavior: bounded zoom + exact stamp invalidation

    /// The exact set of layout stamp domains invalidated by a font-zoom change —
    /// the frozen `fontChanged` edge set: geometry, scrollDimension, frame. This
    /// is the single source of truth (the `MonaDependencyStampEdgeMap`); a font
    /// change dirties geometry (re-shape), scrollDimension (pixel content size),
    /// and frame (composited frame), but NOT projection (column mapping is
    /// unchanged), vertical, paint, or surface.
    public func invalidatedDomainsForZoomChange() -> Set<MonaStampDomain> {
        return MonaDependencyStampEdgeMap.standard.invalidatedDomains(for: .fontChanged)
    }

    /// Validates a claimed invalidation set for a font-zoom change against the
    /// frozen edge set, reporting any missing or fanout domains. The claim is
    /// valid (`isValid == true`) iff it exactly equals
    /// `invalidatedDomainsForZoomChange()`.
    public func validateStampInvalidation(
        claimed: Set<MonaStampDomain>
    ) -> MonaStampEdgeValidation {
        return MonaDependencyStampEdgeMap.standard.validate(
            mutation: .fontChanged,
            claimedInvalidated: claimed
        )
    }

    /// Applies `delta` to the current zoom, clamps to `[minZoom, maxZoom]`, and
    /// fires an event with the applied zoom and the exact invalidated domains.
    /// Returns the new (clamped) zoom. A no-op after `dispose()` (returns the
    /// unchanged current zoom).
    @discardableResult
    public func applyZoom(delta: Double) -> Double {
        guard !isDisposed else { return currentZoom }
        _lock.lock()
        let raw = _currentZoom + delta
        let clamped = min(max(raw, Self.minZoom), Self.maxZoom)
        _currentZoom = clamped
        _lock.unlock()
        fireZoom(clamped)
        return clamped
    }

    /// Zooms in by one `zoomStep`. Returns the new (clamped) zoom.
    @discardableResult
    public func zoomIn() -> Double {
        return applyZoom(delta: Self.zoomStep)
    }

    /// Zooms out by one `zoomStep`. Returns the new (clamped) zoom.
    @discardableResult
    public func zoomOut() -> Double {
        return applyZoom(delta: -Self.zoomStep)
    }

    /// Sets the zoom to `zoom` (clamped). Returns the new (clamped) zoom. A
    /// no-op after `dispose()`.
    @discardableResult
    public func setZoom(_ zoom: Double) -> Double {
        guard !isDisposed else { return currentZoom }
        let clamped = min(max(zoom, Self.minZoom), Self.maxZoom)
        _lock.lock()
        _currentZoom = clamped
        _lock.unlock()
        fireZoom(clamped)
        return clamped
    }

    /// Resets the zoom to the default (`1.0`). Returns the reset zoom.
    @discardableResult
    public func resetZoom() -> Double {
        return setZoom(Self.defaultZoom)
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Routes a zoom change through the shared transaction gateway: begins a
    /// transaction, prepares a collapsed selection at `position` (the zoom's
    /// anchor), and commits the unit. Returns the committed selections (empty
    /// when the feature is disposed or the commit dropped).
    @discardableResult
    public func commitZoomChange(
        gateway: MonaTransactionGateway,
        position: MonaPosition
    ) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        let tx = gateway.beginTransaction()
        let selection = MonaSelection(anchor: position, activePosition: position)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishFontZoomEvent(
        _ event: MonaFontZoomEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaFontZoomEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `applyZoom` / `zoomIn` / `zoomOut` /
    /// `setZoom` / `commitZoomChange` are no-ops (return the unchanged zoom or
    /// an empty selection list).
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. fontZoom needs no tokenization; it
    /// degrades to plain text for any tokenization need.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — fontZoom performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a font-zoom event with `zoom` and the exact invalidated domains (in
    /// `MonaStampDomain.allCases` order), when not disposed.
    private func fireZoom(_ zoom: Double) {
        guard !isDisposed else { return }
        let domains = MonaStampDomain.allCases.filter { invalidatedDomainsForZoomChange().contains($0) }
        emitter.fire(.init(zoom: zoom, invalidatedDomains: domains))
    }
}
