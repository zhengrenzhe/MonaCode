// MonaAnchorSelectFeature.swift
//
// P05-T100 — Implement retained feature anchorSelect.
//
// `MonaAnchorSelectFeature` is the Swift counterpart of Monaco's
// `SelectionAnchorController` (monaco-editor 0.56.0). It extends selections
// from their anchors with exact cursor ordering: the anchor is preserved
// verbatim and the active position is the cursor, so the orientation is derived
// branch-for-branch from the anchor-vs-active comparison (forward when the
// anchor sorts at or before the cursor, backward otherwise).
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `extendSelections(fromAnchors:toCursors:)`,
//      `selection(anchor:cursor:)`, and the anchor set / cancel lifecycle.
//   2. Register the exact feature identity `anchorSelect` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// An anchor-select event: the anchor + the selections derived from it.
public struct MonaAnchorSelectEvent: Equatable {

    /// The current selection anchor, or `nil` when no anchor is set.
    public let anchor: MonaPosition?

    /// The selections extended from the anchor.
    public let selections: [MonaSelection]

    public init(anchor: MonaPosition?, selections: [MonaSelection]) {
        self.anchor = anchor
        self.selections = selections
    }
}

/// The anchorSelect feature: extend selections from their anchors with exact
/// cursor ordering.
///
/// The feature identity `anchorSelect` and its declared slice are referenced
/// verbatim from the frozen registries (`MonaFeatureRegistry`,
/// `MonaCommandRegistry`, `MonaActionRegistry`, `MonaContributionRegistry`,
/// and `MonaBuiltinKeybindings`). Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaAnchorSelectFeature: MonaDisposable {

    /// The frozen feature identity (`"anchorSelect"`).
    public static let featureId = "anchorSelect"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These
    /// are also the feature's declared command IDs.
    public static let declaredActionIds: [String] = [
        "editor.action.setSelectionAnchor",
        "editor.action.goToSelectionAnchor",
        "editor.action.selectFromAnchorToCursor",
        "editor.action.cancelSelectionAnchor"
    ]

    /// The declared command IDs (identical to the action IDs for this feature).
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution ID (`SelectionAnchorController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.selectionAnchorController"
    ]

    /// The declared keybinding commands — the actions that carry a default
    /// keybinding in `MonaBuiltinKeybindings`.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.setSelectionAnchor",
        "editor.action.selectFromAnchorToCursor",
        "editor.action.cancelSelectionAnchor"
    ]

    /// The declared option IDs. anchorSelect declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs. anchorSelect declares no menus.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The emitter that delivers anchor-select events. Disposal is routed
    /// through this emitter (idempotent): after `dispose()`, listeners are
    /// dropped and `fire` is a no-op.
    private let emitter = MonaEmitter<MonaAnchorSelectEvent>()

    /// The event stream for anchor-select changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the
    /// listener.
    public var onChange: MonaEvent<MonaAnchorSelectEvent> { emitter.event }

    private var _anchor: MonaPosition? = nil
    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the anchorSelect feature with no anchor set.
    public init() {}

    // MARK: - State

    /// `true` when a selection anchor is currently set.
    public var hasSelectionAnchor: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _anchor != nil
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior

    /// Extends selections from `anchors` to `cursors`, preserving each anchor
    /// verbatim and setting the active position to the matching cursor.
    ///
    /// The orientation is derived from the anchor-vs-active comparison (forward
    /// when the anchor sorts at or before the cursor, backward otherwise),
    /// matching Monaco's `new Selection(selectionStart, position)` branch. When
    /// the counts differ, no consistent extension is possible and an empty
    /// array is returned.
    public func extendSelections(
        fromAnchors anchors: [MonaPosition],
        toCursors cursors: [MonaPosition]
    ) -> [MonaSelection] {
        guard anchors.count == cursors.count, !anchors.isEmpty else { return [] }
        var selections: [MonaSelection] = []
        selections.reserveCapacity(anchors.count)
        for (anchor, cursor) in zip(anchors, cursors) {
            selections.append(MonaSelection(anchor: anchor, activePosition: cursor))
        }
        return selections
    }

    /// Builds a single selection from `anchor` to `cursor` with the orientation
    /// derived from the anchor-vs-active comparison (exact cursor ordering).
    public func selection(anchor: MonaPosition, cursor: MonaPosition) -> MonaSelection {
        return MonaSelection(anchor: anchor, activePosition: cursor)
    }

    /// Sets the selection anchor at `position` and fires an event. Returns the
    /// recorded anchor. A no-op after `dispose()`.
    @discardableResult
    public func setSelectionAnchor(at position: MonaPosition) -> MonaPosition {
        guard !isDisposed else { return position }
        _lock.lock()
        _anchor = position
        let anchor = position
        _lock.unlock()
        emitter.fire(MonaAnchorSelectEvent(anchor: anchor, selections: []))
        return anchor
    }

    /// Cancels the selection anchor. A no-op after `dispose()`.
    public func cancelSelectionAnchor() {
        guard !isDisposed else { return }
        _lock.lock()
        _anchor = nil
        _lock.unlock()
    }

    // MARK: - 3a. Model mutation → MonaTransactionGateway

    /// Commits a selection-extension transaction through `gateway` as one
    /// ordered unit. The extended selections are prepared on the transaction
    /// and recorded as the gateway's committed selections; the model's text is
    /// untouched (a selection-only transaction applies no text edits).
    ///
    /// Returns the gateway's committed selections, or an empty array when the
    /// transaction could not be committed.
    @discardableResult
    public func commitSelectionExtension(
        gateway: MonaTransactionGateway,
        fromAnchors anchors: [MonaPosition],
        toCursors cursors: [MonaPosition]
    ) -> [MonaSelection] {
        let selections = extendSelections(fromAnchors: anchors, toCursors: cursors)
        let transaction = gateway.beginTransaction()
        transaction.prepareSelections(selections)
        let outcome = gateway.commit(transaction)
        switch outcome {
        case .applied, .reconciled:
            return gateway.lastCommittedSelections
        case .dropped, .rolledBack:
            return []
        }
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `selections` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    ///
    /// Returns `true` when the result was accepted onto the publication path.
    @discardableResult
    public func publishSelections(
        _ selections: [MonaSelection],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaSelection]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(selections),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `setSelectionAnchor` / `fire` are
    /// no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _anchor = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile` (Monaco's raw UTF-16
    /// placeholder rule + the pseudo transform when applicable).
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. anchorSelect needs no tokenization,
    /// so it always operates in the degraded plain-text mode for its
    /// tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — anchorSelect performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback when no grammar /
    /// tokenization provider is registered.
    public var isPlainTextDegraded: Bool { true }
}
