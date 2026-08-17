// MonaDiffEditorFeature.swift
//
// P05-T112 — Implement retained feature diffEditor.
//
// `MonaDiffEditorFeature` is the Swift counterpart of Monaco's `diffEditor`
// contribution (monaco-editor 0.56.0): it registers the diff-editor command
// slice — `diffEditor.*`, `editor.action.accessibleDiffViewer.*`, and
// `editor.action.diffReview.*` commands — over the Phase 07 diff interfaces,
// and routes the one mutating command (`diffEditor.revert`) through the
// transaction gateway.
//
// Diff construction itself is behind a Phase 07 adapter: P05-T012 preserved the
// `MonaDiffEditorView` / `MonaMultiDiffEditorView` declaration slots and
// `MonaEditorFactory.createDiffEditor` throws `.phase07NotWired` until the
// Phase 07 diff engine is wired. This feature registers the diff-editor
// command/contribution slice OVER those slots — it does NOT implement diff
// logic. A diff-editor instance is identified by its instance id (the would-be
// `MonaDiffEditorView`); the registered command slice is retained per instance
// so a disposed instance's slice can be released.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `registerDiffEditorCommands`,
//      `executeDiffEditorCommand`, `releaseDiffEditorCommands`, all keyed by
//      diff-editor instance.
//   2. Register the exact feature identity `diffEditor` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A diff-editor instance bound to the Phase 07 diff slot. The instance id is
/// the would-be `MonaDiffEditorView` (construction is Phase 07); the original /
/// modified model URIs identify the diff pair the slice is registered against.
public struct MonaDiffEditorInstance {

    /// The diff-editor instance id (the would-be `MonaDiffEditorView`).
    public let instanceId: String

    /// The original (left) model URI, when known.
    public let originalModelUri: MonaURI?

    /// The modified (right) model URI, when known.
    public let modifiedModelUri: MonaURI?

    public init(instanceId: String, originalModelUri: MonaURI? = nil, modifiedModelUri: MonaURI? = nil) {
        self.instanceId = instanceId
        self.originalModelUri = originalModelUri
        self.modifiedModelUri = modifiedModelUri
    }
}

/// A diff-editor event: the instance id and the command slice registered /
/// released / invoked.
public struct MonaDiffEditorEvent: Equatable {

    /// The diff-editor instance id the event concerns.
    public let instanceId: String

    /// The command slice carried by this event.
    public let registeredCommands: [String]

    public init(instanceId: String, registeredCommands: [String]) {
        self.instanceId = instanceId
        self.registeredCommands = registeredCommands
    }
}

/// The diffEditor feature: register diff-editor commands and contributions over
/// the Phase 07 diff interfaces.
///
/// The feature identity `diffEditor` and its declared slice are referenced
/// verbatim from the frozen registries. The declared command slice is retained
/// per diff-editor instance so a disposed instance's slice can be released. The
/// `diffEditor.revert` command routes its revert edit through
/// `MonaTransactionGateway`; non-mutating commands (`collapseAllUnchangedRegions`,
/// `switchSide`, `toggle*`, `accessibleDiffViewer.*`, `diffReview.*`) are
/// acknowledged — their diff logic is behind the Phase 07 diff engine.
/// Asynchronous publication is routed through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaDiffEditorFeature: MonaDisposable {

    /// The frozen feature identity (`"diffEditor"`).
    public static let featureId = "diffEditor"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). diffEditor
    /// declares no labeled editor actions — its commands carry no action labels.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. These are the diff-editor
    /// command set: the unchanged-region controls, the revert action, the
    /// compare-move exit, the side switch, the toggles, the accessible diff
    /// viewer navigation, and the legacy diff-review navigation.
    public static let declaredCommandIds: [String] = [
        "diffEditor.collapseAllUnchangedRegions",
        "diffEditor.exitCompareMove",
        "diffEditor.revert",
        "diffEditor.showAllUnchangedRegions",
        "diffEditor.switchSide",
        "diffEditor.toggleCollapseUnchangedRegions",
        "diffEditor.toggleShowMovedCodeBlocks",
        "diffEditor.toggleUseInlineViewWhenSpaceIsLimited",
        "editor.action.accessibleDiffViewer.next",
        "editor.action.accessibleDiffViewer.prev",
        "editor.action.diffReview.next",
        "editor.action.diffReview.prev"
    ]

    /// The declared contribution IDs. `diffContributions` is 0 in the F1-R3
    /// scope manifest — diffEditor owns no contribution registrations.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the diff-editor commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.accessibleDiffViewer.next",
        "editor.action.accessibleDiffViewer.prev",
        "diffEditor.exitCompareMove"
    ]

    /// The declared option names — the `inDiffEditor` context input option that
    /// gates the diff-editor context (`isInDiffEditor`).
    public static let declaredOptionIds: [String] = [
        "inDiffEditor"
    ]

    /// The declared menu IDs — the diff-editor hunk / selection toolbars.
    public static let declaredMenuIds: [String] = [
        "DiffEditorHunkToolbar",
        "DiffEditorSelectionToolbar"
    ]

    /// The diff-editor command that mutates the modified model (`revert`).
    private static let revertCommandId = "diffEditor.revert"

    // MARK: - Routing state

    /// The registered command slices retained by diff-editor instance id. A
    /// disposed instance's slice is released by `releaseDiffEditorCommands`.
    private var registeredByInstance: [String: [String]] = [:]

    private let emitter = MonaEmitter<MonaDiffEditorEvent>()

    /// The event stream for diff-editor changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaDiffEditorEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the diffEditor feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: register commands over the Phase 07 slots

    /// Registers the declared diff-editor command slice against `instance`,
    /// retaining it keyed by instance id so a disposed instance's slice can be
    /// released. Diff construction itself stays behind the Phase 07 adapter;
    /// this registers the slice OVER the slot, it does not construct a diff
    /// editor. Fires an event with the registered slice. Returns the registered
    /// commands, or an empty array after `dispose()`.
    @discardableResult
    public func registerDiffEditorCommands(for instance: MonaDiffEditorInstance) -> [String] {
        guard !isDisposed else { return [] }
        let slice = Self.declaredCommandIds
        _lock.lock()
        registeredByInstance[instance.instanceId] = slice
        _lock.unlock()
        fire(.init(instanceId: instance.instanceId, registeredCommands: slice))
        return slice
    }

    /// The number of registered commands retained for `instance`. Zero when the
    /// instance has no retained slice (or after disposal).
    public func registeredCommandCount(for instance: MonaDiffEditorInstance) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        return registeredByInstance[instance.instanceId]?.count ?? 0
    }

    /// Executes a diff-editor command for `instance`. The `diffEditor.revert`
    /// command is the one mutating command: when `revertEdit` is supplied, it is
    /// prepared on a transaction (labeled with the command id) and committed
    /// through `gateway` as one ordered unit; the modified model is mutated only
    /// when the transaction applies. Non-mutating commands are acknowledged
    /// (`.applied`, no edit prepared) — their diff logic is behind the Phase 07
    /// diff engine. Unknown commands are dropped. Returns the reconciliation
    /// outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func executeDiffEditorCommand(
        _ commandId: String,
        for instance: MonaDiffEditorInstance,
        gateway: MonaTransactionGateway,
        revertEdit: (range: MonaRange, text: String)?
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        guard Self.declaredCommandIds.contains(commandId) else {
            return .dropped(reason: "unknown command")
        }
        if commandId == Self.revertCommandId, let edit = revertEdit {
            let transaction = gateway.beginTransaction()
            transaction.prepareEdit(MonaModelEditOperation(range: edit.range, text: edit.text))
            return gateway.commit(transaction)
        }
        // Non-mutating command: acknowledged. The diff behavior is behind the
        // Phase 07 diff engine; this feature does not implement diff logic.
        return .applied
    }

    /// Releases the registered command slice retained for `instance` (the diff
    /// editor instance has been disposed). Returns the number of commands
    /// released. After `dispose()`, returns `0`.
    @discardableResult
    public func releaseDiffEditorCommands(for instance: MonaDiffEditorInstance) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        return registeredByInstance.removeValue(forKey: instance.instanceId)?.count ?? 0
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishDiffEditorEvent(
        _ event: MonaDiffEditorEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaDiffEditorEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained slices are released, and
    /// `registerDiffEditorCommands` / `executeDiffEditorCommand` /
    /// `releaseDiffEditorCommands` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        registeredByInstance.removeAll()
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. diffEditor declares no
    /// actions, so this is always empty.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    /// Returns the declared command labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. diffEditor commands carry no
    /// label in the registry, so the command id is the label fallback (formatted
    /// verbatim). This routes the command slice through the same localization
    /// surface the actions use.
    public func localizedCommandLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaCommandRegistry()
        return Self.declaredCommandIds.map { id in
            let label = registry.identity(for: id)?.id ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. diffEditor needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — diffEditor performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a diff-editor event when not disposed.
    private func fire(_ event: MonaDiffEditorEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
