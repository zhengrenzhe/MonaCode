// MonaInlineCompletionsFeature.swift
//
// P05-T128 — Implement retained feature inlineCompletions.
//
// `MonaInlineCompletionsFeature` is the Swift counterpart of Monaco's
// `inlineCompletions` contribution (monaco-editor 0.56.0): it requests,
// updates, partially accepts, accepts, and releases inline completions keyed by
// model version. An inline completion is ghost text — a range to replace (or a
// zero-width range to insert at) plus the insert text and an optional filter
// text; requesting stages and retains the completion keyed by model version so a
// stale version's result can be released when the model advances, updating
// replaces the staged completion in place, partially accepting applies the
// first word of the insert text as a committed edit through
// `MonaTransactionGateway`, accepting applies the full insert text, and
// releasing drops the completion retained for a stale model version.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `requestInlineCompletion`,
//      `updateInlineCompletion`, `partiallyAcceptInlineCompletion`,
//      `acceptInlineCompletion`, and `releaseInlineCompletion`, all keyed by
//      model version.
//   2. Register the exact feature identity `inlineCompletions` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation / edits), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// An inline completion: ghost text — a range to replace (or a zero-width range
/// to insert at) plus the insert text and an optional filter text. Mirrors
/// Monaco's `InlineCompletion` (monaco-editor 0.56.0).
public struct MonaInlineCompletion: Equatable {

    /// The range the completion replaces. A zero-width range is a pure
    /// insertion at the position.
    public let range: MonaRange

    /// The text to insert / replace the range with.
    public let insertText: String

    /// The optional filter text used to match the completion against the
    /// current text, or `nil` when it equals `insertText`.
    public let filterText: String?

    public init(range: MonaRange, insertText: String, filterText: String? = nil) {
        self.range = range
        self.insertText = insertText
        self.filterText = filterText
    }
}

/// An inline-completion event: the staged completion (or `nil` when released)
/// and the model version it is retained against.
public struct MonaInlineCompletionEvent: Equatable {

    /// The staged completion, or `nil` when no completion is staged.
    public let completion: MonaInlineCompletion?

    /// The model version the completion is retained against.
    public let modelVersion: Int

    public init(completion: MonaInlineCompletion?, modelVersion: Int) {
        self.completion = completion
        self.modelVersion = modelVersion
    }
}

/// The inlineCompletions feature: request, update, partially accept, accept, and
/// release version-gated inline completions.
///
/// The feature identity `inlineCompletions` and its declared slice are
/// referenced verbatim from the frozen registries. Requested completions are
/// retained per model version so a stale version's result can be released when
/// the model advances. Edits (partial / full accept) are routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaInlineCompletionsFeature: MonaDisposable {

    /// The frozen feature identity (`"inlineCompletions"`).
    public static let featureId = "inlineCompletions"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// eleven labeled inline-suggest actions: trigger, cycle next / previous,
    /// the two partial accepts, commit, the alternative-action commit, toggle
    /// collapsed, hide, jump, and the developer extract-repro.
    public static let declaredActionIds: [String] = [
        "editor.action.inlineSuggest.trigger",
        "editor.action.inlineSuggest.showNext",
        "editor.action.inlineSuggest.showPrevious",
        "editor.action.inlineSuggest.acceptNextWord",
        "editor.action.inlineSuggest.acceptNextLine",
        "editor.action.inlineSuggest.commit",
        "editor.action.inlineSuggest.commitAlternativeAction",
        "editor.action.inlineSuggest.toggleShowCollapsed",
        "editor.action.inlineSuggest.hide",
        "editor.action.inlineSuggest.jump",
        "editor.action.inlineSuggest.dev.extractRepro"
    ]

    /// The declared command IDs in source order. The inline-completion command
    /// set: the fourteen inline-suggest commands (the provider-execute command
    /// is implicit; the snooze / cancel-snooze / toggle-always-show-toolbar
    /// commands are included alongside the action commands).
    public static let declaredCommandIds: [String] = [
        "editor.action.inlineSuggest.acceptNextLine",
        "editor.action.inlineSuggest.acceptNextWord",
        "editor.action.inlineSuggest.cancelSnooze",
        "editor.action.inlineSuggest.commit",
        "editor.action.inlineSuggest.commitAlternativeAction",
        "editor.action.inlineSuggest.dev.extractRepro",
        "editor.action.inlineSuggest.hide",
        "editor.action.inlineSuggest.jump",
        "editor.action.inlineSuggest.showNext",
        "editor.action.inlineSuggest.showPrevious",
        "editor.action.inlineSuggest.snooze",
        "editor.action.inlineSuggest.toggleAlwaysShowToolbar",
        "editor.action.inlineSuggest.toggleShowCollapsed",
        "editor.action.inlineSuggest.trigger"
    ]

    /// The declared contribution ID (`editor.contrib.inlineCompletionsController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.inlineCompletionsController"
    ]

    /// The declared keybinding commands — the seven inline-suggest actions that
    /// carry a default keybinding in `MonaBuiltinKeybindings`, in declared
    /// action order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.inlineSuggest.showNext",
        "editor.action.inlineSuggest.showPrevious",
        "editor.action.inlineSuggest.acceptNextWord",
        "editor.action.inlineSuggest.commit",
        "editor.action.inlineSuggest.commitAlternativeAction",
        "editor.action.inlineSuggest.hide",
        "editor.action.inlineSuggest.jump"
    ]

    /// The declared option names — the inline-completion editor options:
    /// `screenReaderAnnounceInlineSuggestion`, `inlineSuggest`, and
    /// `inlineCompletionsAccessibilityVerbose`.
    public static let declaredOptionIds: [String] = [
        "screenReaderAnnounceInlineSuggestion",
        "inlineSuggest",
        "inlineCompletionsAccessibilityVerbose"
    ]

    /// The declared menu IDs — the three menus that carry inline-suggest menu
    /// items: the command palette, the inline-edits actions menu, and the
    /// inline-suggestion toolbar.
    public static let declaredMenuIds: [String] = [
        "CommandPalette",
        "InlineEditsActions",
        "InlineSuggestionToolbar"
    ]

    // MARK: - Routing state

    /// The inline completions retained by model version. A stale model
    /// version's completion is released by
    /// `releaseInlineCompletion(modelVersion:)`.
    private var retainedByVersion: [Int: MonaInlineCompletion] = [:]

    /// The currently staged completion (the most recent requested / updated).
    private var _stagedCompletion: MonaInlineCompletion? = nil

    /// The model version the staged completion is retained against.
    private var _stagedVersion: Int? = nil

    private let emitter = MonaEmitter<MonaInlineCompletionEvent>()

    /// The event stream for inline-completion changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaInlineCompletionEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the inlineCompletions feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The currently staged completion, or `nil` when none is staged (or after
    /// disposal).
    public var stagedCompletion: MonaInlineCompletion? {
        _lock.lock(); defer { _lock.unlock() }
        return _stagedCompletion
    }

    // MARK: - 1. Feature-specific behavior: request / update / partially accept / accept / release

    /// Requests `completion` against `modelVersion`, retaining it keyed by model
    /// version and staging it as the current completion. Fires an event with the
    /// staged completion. Returns the completion, or `nil` after `dispose()`.
    @discardableResult
    public func requestInlineCompletion(
        _ completion: MonaInlineCompletion,
        modelVersion: Int
    ) -> MonaInlineCompletion? {
        guard !isDisposed else { return nil }
        _lock.lock()
        retainedByVersion[modelVersion] = completion
        _stagedCompletion = completion
        _stagedVersion = modelVersion
        _lock.unlock()
        fire(completion, modelVersion: modelVersion)
        return completion
    }

    /// The completion retained for `modelVersion`, or `nil` when the version has
    /// no retained completion (or after disposal).
    public func retainedCompletion(for modelVersion: Int) -> MonaInlineCompletion? {
        _lock.lock(); defer { _lock.unlock() }
        return retainedByVersion[modelVersion]
    }

    /// Updates the staged completion to `completion` in place, also updating the
    /// retained copy for the staged version. Fires an event. Returns the updated
    /// completion, or `nil` after `dispose()` or when no completion is staged.
    @discardableResult
    public func updateInlineCompletion(_ completion: MonaInlineCompletion) -> MonaInlineCompletion? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard _stagedCompletion != nil else {
            _lock.unlock()
            return nil
        }
        _stagedCompletion = completion
        let version = _stagedVersion
        if let v = version {
            retainedByVersion[v] = completion
        }
        _lock.unlock()
        fire(completion, modelVersion: version ?? 0)
        return completion
    }

    /// Partially accepts the staged completion: applies the first word of its
    /// insert text as a committed edit through `gateway`. Returns the
    /// reconciliation outcome. Returns `.dropped` after `dispose()` or when no
    /// completion is staged.
    @discardableResult
    public func partiallyAcceptInlineCompletion(
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        _lock.lock()
        let staged = _stagedCompletion
        _lock.unlock()
        guard let completion = staged else {
            return .dropped(reason: "no staged completion")
        }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([
            MonaModelEditOperation(range: completion.range, text: firstWord(of: completion.insertText))
        ])
        return gateway.commit(transaction)
    }

    /// Accepts the staged completion: applies its full insert text as a
    /// committed edit through `gateway`. Returns the reconciliation outcome.
    /// Returns `.dropped` after `dispose()` or when no completion is staged.
    @discardableResult
    public func acceptInlineCompletion(
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        _lock.lock()
        let staged = _stagedCompletion
        _lock.unlock()
        guard let completion = staged else {
            return .dropped(reason: "no staged completion")
        }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([
            MonaModelEditOperation(range: completion.range, text: completion.insertText)
        ])
        return gateway.commit(transaction)
    }

    /// Releases the completion retained for `modelVersion` (the model has
    /// advanced past that version, so the result is stale). Returns `1` when a
    /// completion was released, `0` otherwise. After `dispose()`, returns `0`.
    @discardableResult
    public func releaseInlineCompletion(modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        return retainedByVersion.removeValue(forKey: modelVersion) != nil ? 1 : 0
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `completion` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishInlineCompletion(
        _ completion: MonaInlineCompletion,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaInlineCompletion) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(completion),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained completions are released, the
    /// staged completion is cleared, and `requestInlineCompletion` /
    /// `updateInlineCompletion` / `partiallyAcceptInlineCompletion` /
    /// `acceptInlineCompletion` / `releaseInlineCompletion` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        retainedByVersion.removeAll()
        _stagedCompletion = nil
        _stagedVersion = nil
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

    /// The plain-text fallback language. inlineCompletions needs no
    /// tokenization; it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — inlineCompletions performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires an inline-completion event when not disposed.
    private func fire(_ completion: MonaInlineCompletion?, modelVersion: Int) {
        guard !isDisposed else { return }
        emitter.fire(MonaInlineCompletionEvent(completion: completion, modelVersion: modelVersion))
    }

    /// Returns the first word of `text` — the substring up to the first space,
    /// or the whole text when it has no space. This is the partial-accept
    /// boundary (the next word of the ghost text).
    private func firstWord(of text: String) -> String {
        return text.components(separatedBy: " ").first ?? text
    }
}
