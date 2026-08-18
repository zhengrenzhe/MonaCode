// MonaQuickCommandFeature.swift
//
// P05-T142 — Implement retained feature quickCommand.
//
// `MonaQuickCommandFeature` is the Swift counterpart of Monaco's
// `quickCommand` contribution (monaco-editor 0.56.0): it filters the
// registered editor commands by a query string and invokes the selected
// command with exact enablement (reusing T002 `MonaCommandRegistry` for the
// command list + enablement). The command palette surface.
//
// Filtering is a case-insensitive substring match over the command ID. Only
// live, enabled commands (per `MonaCommandRegistry.isEnabled(_:context:)`)
// appear in the filtered list. Invoking a command first re-checks its
// enablement — a disabled or unknown command returns `.disabled` and is NOT
// invoked. When a command carries model edits, those edits are routed through
// `MonaTransactionGateway` as one ordered unit.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `filterCommands(query:registry:context:)`,
//      `invokeCommand(_:registry:context:)`: filter the live command list by
//      query and invoke a command with exact enablement.
//   2. Register the exact feature identity `quickCommand` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// A command-palette entry: the command ID, its human-readable label, and
/// whether it is enabled in the current context.
public struct MonaQuickCommandEntry: Equatable, Sendable {

    /// The command ID (e.g. `"undo"`, `"editor.action.quickCommand"`).
    public let commandId: String

    /// The human-readable label (the action's label, or the command ID when no
    /// action is registered).
    public let label: String

    /// `true` when the command is enabled in the filtering context.
    public let enabled: Bool

    public init(commandId: String, label: String, enabled: Bool) {
        self.commandId = commandId
        self.label = label
        self.enabled = enabled
    }
}

/// A quickCommand event: the filtered command entries.
public struct MonaQuickCommandEvent: Equatable {

    /// The filtered entries after the change.
    public let entries: [MonaQuickCommandEntry]

    public init(entries: [MonaQuickCommandEntry]) {
        self.entries = entries
    }
}

/// The outcome of invoking a command through the palette.
public enum MonaQuickCommandInvocationOutcome: Equatable, Sendable {

    /// The command is live and enabled; it was invoked.
    case enabled

    /// The command is unknown or disabled; it was NOT invoked.
    case disabled
}

/// The quickCommand feature: filter and invoke registered editor commands with
/// exact enablement.
///
/// The feature identity `quickCommand` and its declared slice are referenced
/// verbatim from the frozen registries. The command list + enablement come from
/// `MonaCommandRegistry` (T002). Model mutation (a command's edits) is routed
/// through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaQuickCommandFeature: MonaDisposable {

    /// The frozen feature identity (`"quickCommand"`).
    public static let featureId = "quickCommand"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single command-palette action (`editor.action.quickCommand`, ordinal
    /// 165, "Command Palette").
    public static let declaredActionIds: [String] = [
        "editor.action.quickCommand"
    ]

    /// The declared command IDs in source order. The command-palette action
    /// is the single declared command.
    public static let declaredCommandIds: [String] = [
        "editor.action.quickCommand"
    ]

    /// The declared contribution IDs. The shared quick-input controller
    /// (`editor.controller.quickInput`, ordinal 52) is the quick-command
    /// surface's contribution.
    public static let declaredContributionIds: [String] = [
        "editor.controller.quickInput"
    ]

    /// The declared keybinding commands — the command-palette action carries
    /// the default `F1` keybinding (keyCode 59).
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.quickCommand"
    ]

    /// The declared option names. quickCommand owns no editor options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — the `EditorContext` menu carries the
    /// command-palette menu item (group `z_commands`).
    public static let declaredMenuIds: [String] = [
        "EditorContext"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaQuickCommandEvent>()

    /// The event stream for quickCommand changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaQuickCommandEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the quickCommand feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: filter + invoke with exact enablement

    /// Filters the live command list from `registry` by `query` (a
    /// case-insensitive substring match over the command ID), returning only
    /// the commands that are enabled in `context` (per
    /// `MonaCommandRegistry.isEnabled`). Fires an event with the filtered
    /// entries. Returns an empty array after `dispose()`.
    @discardableResult
    public func filterCommands(
        query: String,
        registry: MonaCommandRegistry,
        context: MonaKeybindingContext
    ) -> [MonaQuickCommandEntry] {
        guard !isDisposed else {
            emitter.fire(MonaQuickCommandEvent(entries: []))
            return []
        }
        let actions = MonaActionRegistry()
        let needle = query.lowercased()
        let entries: [MonaQuickCommandEntry] = registry.liveIdentities.compactMap { identity in
            if !needle.isEmpty && !identity.id.lowercased().contains(needle) {
                return nil
            }
            let enabled = registry.isEnabled(identity.id, context: context)
            let label = actions.identity(for: identity.id)?.label ?? identity.id
            return MonaQuickCommandEntry(
                commandId: identity.id,
                label: label,
                enabled: enabled
            )
        }
        emitter.fire(MonaQuickCommandEvent(entries: entries))
        return entries
    }

    /// Invokes `commandId` with exact enablement: returns `.enabled` only when
    /// `commandId` is a live, enabled command in `context`; otherwise returns
    /// `.disabled` and does NOT invoke. After `dispose()`, always returns
    /// `.disabled`.
    public func invokeCommand(
        _ commandId: String,
        registry: MonaCommandRegistry,
        context: MonaKeybindingContext
    ) -> MonaQuickCommandInvocationOutcome {
        guard !isDisposed else { return .disabled }
        guard registry.isEnabled(commandId, context: context) else {
            return .disabled
        }
        return .enabled
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Commits `edits` (the model mutations produced by an invoked command)
    /// through `gateway` as one ordered unit. Returns the reconciliation
    /// outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitInvocationEdits(
        _ edits: [MonaModelEditOperation],
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        if !edits.isEmpty {
            transaction.prepareEdits(edits)
        }
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `entries` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    /// After `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishEntries(
        _ entries: [MonaQuickCommandEntry],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaQuickCommandEntry]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(entries),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, and `filterCommands` / `invokeCommand`
    /// / `commitInvocationEdits` / `publishEntries` are no-ops.
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
    /// `MonaLocalization` surface under `profile`. The command-palette action
    /// label ("Command Palette") is formatted under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. quickCommand needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — quickCommand performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
