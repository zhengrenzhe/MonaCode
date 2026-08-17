// MonaCodeActionFeature.swift
//
// P05-T104 — Implement retained feature codeAction.
//
// `MonaCodeActionFeature` is the Swift counterpart of Monaco's `codeAction`
// contribution (monaco-editor 0.56.0): it surfaces provider code actions,
// resolves them, and applies accepted edits transactionally through the
// `MonaTransactionGateway`. The feature identity `codeAction` and its declared
// slice are referenced verbatim from the frozen registries.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `provideCodeActions`, `resolveCodeAction`,
//      and `applyCodeAction`.
//   2. Register the exact feature identity `codeAction` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A code-action kind: the Monaco `CodeActionKind` taxonomy (verbatim).
public enum MonaCodeActionKind: String, Equatable, Sendable {

    /// `quickfix` — quick fixes.
    case quickFix = "quickfix"

    /// `refactor` — refactorings.
    case refactor = "refactor"

    /// `refactor.extract` — extract refactorings.
    case refactorExtract = "refactor.extract"

    /// `refactor.inline` — inline refactorings.
    case refactorInline = "refactor.inline"

    /// `refactor.rewrite` — rewrite refactorings.
    case refactorRewrite = "refactor.rewrite"

    /// `source` — source actions (whole-file).
    case source = "source"

    /// `source.organizeImports` — organize imports.
    case sourceOrganizeImports = "source.organizeImports"

    /// `source.fixAll` — fix all.
    case sourceFixAll = "source.fixAll"

    /// `true` when `self` is `kind` or a sub-kind of `kind` (prefix match on
    /// the dotted taxonomy). `nil` matches everything.
    public func isSubkind(of kind: MonaCodeActionKind?) -> Bool {
        guard let kind = kind else { return true }
        if self == kind { return true }
        return rawValue.hasPrefix(kind.rawValue + ".")
    }
}

/// A single edit in a code action: a range to replace + the replacement text.
public struct MonaCodeActionEdit: Equatable {

    /// The range to replace (raw UTF-16 offsets, 1-based line / column).
    public let range: MonaRange

    /// The replacement text (empty string = deletion).
    public let text: String

    public init(range: MonaRange, text: String) {
        self.range = range
        self.text = text
    }
}

/// A code action: a titled, kinded set of edits offered by a code-action
/// provider. `isPreferred` marks the preferred action within a kind (Monaco's
/// `isPreferred` flag).
public struct MonaCodeAction: Equatable {

    /// The human-readable title.
    public let title: String

    /// The action kind.
    public let kind: MonaCodeActionKind

    /// The edits to apply when the action is accepted.
    public let edits: [MonaCodeActionEdit]

    /// `true` when this is the preferred action within its kind.
    public let isPreferred: Bool

    public init(
        title: String,
        kind: MonaCodeActionKind,
        edits: [MonaCodeActionEdit],
        isPreferred: Bool
    ) {
        self.title = title
        self.kind = kind
        self.edits = edits
        self.isPreferred = isPreferred
    }
}

/// A code-action event: the actions surfaced / resolved / applied.
public struct MonaCodeActionEvent: Equatable {

    /// The actions delivered by this event.
    public let actions: [MonaCodeAction]

    public init(actions: [MonaCodeAction]) {
        self.actions = actions
    }
}

/// The codeAction feature: surface provider code actions, resolve them, and
/// apply accepted edits transactionally.
///
/// The feature identity `codeAction` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaCodeActionFeature: MonaDisposable {

    /// The frozen feature identity (`"codeAction"`).
    public static let featureId = "codeAction"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These
    /// are the labeled editor actions registered by the codeAction contribution.
    /// `editor.action.quickFix` is registered as a command + menuCommand (no
    /// action label in the actions registry) and appears in `declaredCommandIds`.
    public static let declaredActionIds: [String] = [
        "editor.action.refactor",
        "editor.action.sourceAction",
        "editor.action.organizeImports",
        "editor.action.autoFix",
        "editor.action.fixAll"
    ]

    /// The declared command IDs in source order. These are the codeAction
    /// command set: the provider-execute command, the code-action trigger, the
    /// quick-fix / refactor / source-action / organize-imports / auto-fix /
    /// fix-all actions, and the code-action widget navigation commands.
    public static let declaredCommandIds: [String] = [
        "_executeCodeActionProvider",
        "acceptSelectedCodeAction",
        "clearFilterCodeActionWidget",
        "collapseSectionCodeAction",
        "editor.action.autoFix",
        "editor.action.codeAction",
        "editor.action.fixAll",
        "editor.action.organizeImports",
        "editor.action.quickFix",
        "editor.action.refactor",
        "editor.action.sourceAction",
        "expandSectionCodeAction",
        "hideCodeActionWidget",
        "previewSelectedCodeAction",
        "selectNextCodeAction",
        "selectPrevCodeAction",
        "toggleSectionCodeAction"
    ]

    /// The declared contribution IDs (`CodeActionController` + `LightBulbWidget`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.codeActionController",
        "editor.contrib.lightbulbWidget"
    ]

    /// The declared keybinding commands — the codeAction commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`, in source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.autoFix",
        "editor.action.organizeImports",
        "editor.action.quickFix",
        "editor.action.refactor",
        "acceptSelectedCodeAction",
        "collapseSectionCodeAction",
        "expandSectionCodeAction",
        "hideCodeActionWidget",
        "previewSelectedCodeAction",
        "selectNextCodeAction",
        "selectPrevCodeAction",
        "toggleSectionCodeAction",
        "clearFilterCodeActionWidget"
    ]

    /// The declared option names. codeAction declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — the menus that carry codeAction menu items.
    public static let declaredMenuIds: [String] = [
        "CommandPalette",
        "EditorContext",
        "InlineChatEditorAffordance"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaCodeActionEvent>()

    /// The event stream for code-action changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaCodeActionEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the codeAction feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: surface / resolve / apply

    /// Surfaces provider code actions, filtered by `kind`. When `kind` is nil,
    /// all provider actions are surfaced unchanged. When `kind` is supplied,
    /// only actions whose kind is `kind` or a sub-kind of `kind` are surfaced.
    public func provideCodeActions(
        _ providerActions: [MonaCodeAction],
        kind: MonaCodeActionKind? = nil
    ) -> [MonaCodeAction] {
        guard let kind = kind else { return providerActions }
        return providerActions.filter { $0.kind.isSubkind(of: kind) }
    }

    /// Resolves a code action. Resolution completes the edit payload; with no
    /// LSP resolver registered, the action is returned as-is (its edits are
    /// already resolved). Fires an event with the resolved action.
    @discardableResult
    public func resolveCodeAction(_ action: MonaCodeAction) -> MonaCodeAction {
        guard !isDisposed else { return action }
        emitter.fire(MonaCodeActionEvent(actions: [action]))
        return action
    }

    /// Applies `action`'s edits transactionally through `gateway` as one
    /// ordered unit. The edits are prepared on the transaction (labeled with
    /// the action's title) and committed; the model's text is mutated only when
    /// the transaction applies. Returns the reconciliation outcome. A no-op
    /// after `dispose()` (returns `.dropped`).
    @discardableResult
    public func applyCodeAction(
        _ action: MonaCodeAction,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        let ops = action.edits.map { edit in
            MonaModelEditOperation(range: edit.range, text: edit.text)
        }
        if !ops.isEmpty {
            transaction.prepareEdits(ops)
        }
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `actions` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishCodeActions(
        _ actions: [MonaCodeAction],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaCodeAction]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(actions),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `resolveCodeAction` / `applyCodeAction`
    /// are no-ops.
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

    /// The plain-text fallback language. codeAction needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — codeAction performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
