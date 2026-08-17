// MonaGotoErrorFeature.swift
//
// P05-T122 — Implement retained feature gotoError.
//
// `MonaGotoErrorFeature` is the Swift counterpart of Monaco's `gotoError`
// contribution (monaco-editor 0.56.0): it navigates marker severities (error >
// warning > info > hint, then by position) in next/prev direction, reveals the
// selected diagnostic's position through the shared `MonaTransactionGateway`,
// and announces the selected diagnostic through the shared
// `MonaAXAnnouncementBridge` (P04-T012). Markers/diagnostics come from the
// model.
//
// Navigation orders the diagnostics by severity (most severe first), then by
// position (ascending), and walks that order in the requested direction with
// wrap-around. The selected diagnostic is revealed (its position becomes the
// editor selection via the transaction gateway) and announced (its selection
// change is enqueued on the AX announcement bridge, which deduplicates and
// serializes the announcement text through the N1 localization profile).
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `navigate(_:)`: navigate marker severities
//      next/prev with wrap-around; `announceSelectedDiagnostic(bridge:)`:
//      announce the selected diagnostic through the AX announcement bridge;
//      `commitReveal(gateway:)`: reveal the selection through the transaction
//      gateway.
//   2. Register the exact feature identity `gotoError` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      degraded plain-text behavior, and the AX announcement through the shared
//      gateways — reusing `MonaTransactionGateway` (mutation),
//      `MonaProviderExecutor` + `MonaMicrotaskQueue` (async publication),
//      `MonaEmitter` (disposal), `MonaLocalization` (localization),
//      `MonaPlainTextLanguage` (degraded plain text), and
//      `MonaAXAnnouncementBridge` (announcement). No parallel mechanisms are
//      introduced.

import AppKit
import Foundation
import MonaCode

/// A diagnostic navigable by gotoError: a marker (severity + message) paired
/// with the model position it points at. The marker value reuses the base-model
/// `MonaMarker` (P01-T004); the position is a raw UTF-16 one-based coordinate.
public struct MonaGotoErrorDiagnostic: Equatable, Hashable {

    /// The marker (severity + message + optional tag).
    public let marker: MonaMarker

    /// The position the marker points at (1-based line / column).
    public let position: MonaPosition

    /// Creates a diagnostic pairing `marker` with `position`.
    public init(marker: MonaMarker, position: MonaPosition) {
        self.marker = marker
        self.position = position
    }
}

/// A navigation direction: next or previous marker.
public enum MonaGotoErrorDirection: String, Equatable, Sendable {

    /// Navigate to the next marker (severity-desc order, wrap-around).
    case next

    /// Navigate to the previous marker (severity-desc order, wrap-around).
    case prev
}

/// A gotoError event: the selected diagnostic and its index in the ordered list
/// (`nil` / `-1` when no diagnostic is selected).
public struct MonaGotoErrorEvent: Equatable {

    /// The selected diagnostic, or `nil` when none is selected.
    public let selectedDiagnostic: MonaGotoErrorDiagnostic?

    /// The index of the selected diagnostic in the ordered list, or `-1` when
    /// none is selected.
    public let index: Int

    /// Creates a gotoError event.
    public init(selectedDiagnostic: MonaGotoErrorDiagnostic?, index: Int) {
        self.selectedDiagnostic = selectedDiagnostic
        self.index = index
    }
}

/// The gotoError feature: navigate marker severities and announce the selected
/// diagnostic.
///
/// The feature identity `gotoError` and its declared slice are referenced verbatim
/// from the frozen registries. Diagnostics are ordered by severity (most severe
/// first), then by position. `navigate(_:)` walks that order with wrap-around;
/// `announceSelectedDiagnostic(bridge:)` enqueues the selection-change
/// announcement on the shared `MonaAXAnnouncementBridge`; `commitReveal(gateway:)`
/// reveals the selection through the `MonaTransactionGateway`. Model mutation is
/// routed through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; degraded plain-text behavior through
/// `MonaPlainTextLanguage`; and the announcement through `MonaAXAnnouncementBridge`.
public final class MonaGotoErrorFeature: MonaDisposable {

    /// The frozen feature identity (`"gotoError"`).
    public static let featureId = "gotoError"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The four
    /// marker-navigation actions registered by the gotoError contribution
    /// (ordinals 68–71).
    public static let declaredActionIds: [String] = [
        "editor.action.marker.next",
        "editor.action.marker.prev",
        "editor.action.marker.nextInFiles",
        "editor.action.marker.prevInFiles"
    ]

    /// The declared command IDs in source order (manifest order). The
    /// `closeMarkersNavigation` close command and the four marker-navigation
    /// actions.
    public static let declaredCommandIds: [String] = [
        "closeMarkersNavigation",
        "editor.action.marker.next",
        "editor.action.marker.nextInFiles",
        "editor.action.marker.prev",
        "editor.action.marker.prevInFiles"
    ]

    /// The declared contribution IDs in source order. The marker decorations
    /// (squiggles), the marker navigation controller, and the marker
    /// selection-status bar item — the marker/error surface.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.markerDecorations",
        "editor.contrib.markerController",
        "editor.contrib.markerSelectionStatus"
    ]

    /// The declared keybinding commands — the five marker-navigation commands
    /// that carry a default keybinding in `MonaBuiltinKeybindings`, in manifest
    /// source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.marker.next",
        "editor.action.marker.nextInFiles",
        "editor.action.marker.prev",
        "editor.action.marker.prevInFiles",
        "closeMarkersNavigation"
    ]

    /// The declared option names — gotoError owns no editor options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — the menus that carry marker-navigation menu
    /// items: `gotoErrorTitleMenu` (next/prev) and `MenubarGoMenu`
    /// (next/prev in files).
    public static let declaredMenuIds: [String] = [
        "gotoErrorTitleMenu",
        "MenubarGoMenu"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaGotoErrorEvent>()

    /// The event stream for gotoError changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaGotoErrorEvent> { emitter.event }

    /// The diagnostics in navigation order (severity desc, then position asc).
    private var orderedDiagnostics: [MonaGotoErrorDiagnostic] = []

    /// The index of the currently selected diagnostic in
    /// `orderedDiagnostics`, or `nil` when none is selected.
    private var selectedIndex: Int? = nil

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the gotoError feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The currently selected diagnostic, or `nil` when none is selected.
    public var selectedDiagnostic: MonaGotoErrorDiagnostic? {
        _lock.lock(); defer { _lock.unlock() }
        guard let index = selectedIndex, orderedDiagnostics.indices.contains(index) else {
            return nil
        }
        return orderedDiagnostics[index]
    }

    // MARK: - 1. Feature-specific behavior: navigate severities + announce

    /// Sets the diagnostics (markers/diagnostics from the model) and resets the
    /// selection. The diagnostics are ordered by severity (most severe first),
    /// then by position (ascending). A no-op after `dispose()`.
    public func setDiagnostics(_ diagnostics: [MonaGotoErrorDiagnostic]) {
        guard !isDisposed else { return }
        _lock.lock()
        orderedDiagnostics = diagnostics.sorted { a, b in
            if a.marker.severity != b.marker.severity {
                return a.marker.severity > b.marker.severity
            }
            return a.position < b.position
        }
        selectedIndex = nil
        _lock.unlock()
    }

    /// Navigates in `direction` (`.next` / `.prev`) through the ordered
    /// diagnostics with wrap-around. Sets the selection, fires an event, and
    /// returns the selected diagnostic. Returns `nil` when there are no
    /// diagnostics or after `dispose()`.
    @discardableResult
    public func navigate(_ direction: MonaGotoErrorDirection) -> MonaGotoErrorDiagnostic? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard !orderedDiagnostics.isEmpty else {
            _lock.unlock()
            return nil
        }
        let count = orderedDiagnostics.count
        let nextIndex: Int
        switch direction {
        case .next:
            nextIndex = (selectedIndex.map { ($0 + 1) % count } ?? 0)
        case .prev:
            nextIndex = (selectedIndex.map { ($0 - 1 + count) % count } ?? (count - 1))
        }
        selectedIndex = nextIndex
        let selected = orderedDiagnostics[nextIndex]
        _lock.unlock()
        fire(.init(selectedDiagnostic: selected, index: nextIndex))
        return selected
    }

    /// Announces the selected diagnostic through the shared
    /// `MonaAXAnnouncementBridge`, enqueuing the selection-change announcement.
    /// The bridge resolves the announcement text through its N1 profile,
    /// deduplicates a repeat, and serializes the announcement (FIFO). Returns
    /// `true` if the announcement was queued; `false` if it was deduplicated.
    /// A no-op after `dispose()` (returns `false`). Throws
    /// `MonaAXAnnouncementError.missingMessage` if the announcement key has no
    /// resolvable entry for the bridge's profile.
    @discardableResult
    public func announceSelectedDiagnostic(
        bridge: MonaAXAnnouncementBridge
    ) throws -> Bool {
        guard !isDisposed, selectedDiagnostic != nil else { return false }
        return try bridge.enqueue(.selectionChanged)
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals the selected diagnostic's position through the shared transaction
    /// gateway: begins a transaction, prepares a collapsed selection at the
    /// diagnostic's position (the reveal anchor), and commits the unit. Returns
    /// the committed selections (empty when the feature is disposed, no
    /// diagnostic is selected, or the commit dropped).
    @discardableResult
    public func commitReveal(gateway: MonaTransactionGateway) -> [MonaSelection] {
        guard !isDisposed, let position = selectedDiagnostic?.position else { return [] }
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
    public func publishGotoErrorEvent(
        _ event: MonaGotoErrorEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaGotoErrorEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, diagnostics are cleared, and `navigate`
    /// / `announceSelectedDiagnostic` / `commitReveal` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        orderedDiagnostics = []
        selectedIndex = nil
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

    /// The plain-text fallback language. gotoError needs no tokenization; it
    /// degrades to plain text for any tokenization need.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — gotoError performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a gotoError event when not disposed.
    private func fire(_ event: MonaGotoErrorEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
