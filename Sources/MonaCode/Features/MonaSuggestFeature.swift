// MonaSuggestFeature.swift
//
// P05-T153 — Implement retained feature suggest.
//
// `MonaSuggestFeature` is the Swift counterpart of Monaco's `suggest`
// contribution (monaco-editor 0.56.0, registered as
// `editor.contrib.suggestController`): it triggers, filters, ranks, resolves,
// accepts, releases, and remembers completion items — the seven operations of
// the suggest widget — keyed by model version. A completion item is a label,
// kind, insert text, filter / sort text, range, and optional documentation; the
// feature requests the completion list from a `MonaSuggestProvider` (the
// attachment point a Phase 06/07 completion engine implements), filters the
// staged items by the current query, ranks them by sort text, resolves
// documentation through the provider, accepts an item by committing its insert
// text through `MonaTransactionGateway`, releases the items retained for a
// stale model version, and remembers a selected item for
// `shareSuggestSelections` / `suggestSelection` memory.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `trigger`, `filter`, `rank`, `resolve`,
//      `accept`, `release`, `remember`, all keyed by model version and routed
//      through `MonaSuggestProvider`.
//   2. Register the exact feature identity `suggest` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation / edits), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A completion-item kind, mirroring Monaco's `CompletionItemKind` taxonomy
/// (monaco-editor 0.56.0).
public enum MonaCompletionItemKind: Equatable, Sendable {

    case method
    case function
    case constructor
    case field
    case variable
    case classKind
    case structKind
    case interface
    case module
    case property
    case event
    case operatorKind
    case unit
    case value
    case constant
    case enumKind
    case enumMember
    case keyword
    case snippet
    case color
    case file
    case reference
    case folder
    case typeParameter
    case user
    case text
}

/// How a completion was triggered. Mirrors Monaco's
/// `CompletionTriggerKind` (monaco-editor 0.56.0).
public enum MonaCompletionTriggerKind: Equatable, Sendable {

    /// Completion was triggered manually (e.g. via the trigger command).
    case manual

    /// Completion was triggered by a trigger character.
    case triggerCharacter

    /// Completion was triggered automatically (e.g. while typing).
    case automatic
}

/// The context in which a completion is triggered: the trigger kind and the
/// optional trigger character. Mirrors Monaco's `CompletionContext`
/// (monaco-editor 0.56.0).
public struct MonaCompletionContext: Equatable {

    /// How the completion was triggered.
    public let triggerKind: MonaCompletionTriggerKind

    /// The character that triggered the completion, when `triggerKind` is
    /// `.triggerCharacter`; `nil` otherwise.
    public let triggerCharacter: String?

    public init(triggerKind: MonaCompletionTriggerKind, triggerCharacter: String?) {
        self.triggerKind = triggerKind
        self.triggerCharacter = triggerCharacter
    }
}

/// A completion item: a label, kind, insert text, optional filter / sort text,
/// the range to replace, and optional detail / documentation. Mirrors Monaco's
/// `CompletionItem` (monaco-editor 0.56.0).
public struct MonaCompletionItem: Equatable {

    /// The label shown in the suggest widget.
    public let label: String

    /// The completion kind.
    public let kind: MonaCompletionItemKind

    /// Optional detail (e.g. a type signature).
    public let detail: String?

    /// The text to insert / replace the range with.
    public let insertText: String

    /// The optional filter text used to match the item against the current text;
    /// `nil` means filter on `label`.
    public let filterText: String?

    /// The optional sort text used to order items in the widget; `nil` means
    /// sort on `label`.
    public let sortText: String?

    /// The range the completion replaces. A zero-width range is a pure
    /// insertion at the position.
    public let range: MonaRange

    /// Optional documentation for the item.
    public let documentation: String?

    public init(
        label: String,
        kind: MonaCompletionItemKind,
        detail: String? = nil,
        insertText: String,
        filterText: String? = nil,
        sortText: String? = nil,
        range: MonaRange,
        documentation: String? = nil
    ) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.insertText = insertText
        self.filterText = filterText
        self.sortText = sortText
        self.range = range
        self.documentation = documentation
    }
}

/// A completion list: the items and whether the list is incomplete (the
/// provider can supply more on re-trigger). Mirrors Monaco's `CompletionList`
/// (monaco-editor 0.56.0).
public struct MonaCompletionList: Equatable {

    /// The completion items.
    public let items: [MonaCompletionItem]

    /// `true` when the list is incomplete and the provider can supply more.
    public let isIncomplete: Bool

    public init(items: [MonaCompletionItem], isIncomplete: Bool) {
        self.items = items
        self.isIncomplete = isIncomplete
    }
}

/// A suggest event: the staged items and the model version they are retained
/// against.
public struct MonaSuggestEvent: Equatable {

    /// The staged items.
    public let items: [MonaCompletionItem]

    /// The model version the items are retained against.
    public let modelVersion: Int

    public init(items: [MonaCompletionItem], modelVersion: Int) {
        self.items = items
        self.modelVersion = modelVersion
    }
}

/// The suggest-provider attachment point. A Phase 06/07 completion engine
/// implements this protocol; the feature requests completion lists and resolves
/// documentation through it. This is the suggest counterpart of the snippet
/// engine attachment (`MonaSnippetEngineAttachment`): the seven operations work
/// against the attachment point today, and the real engine arrives later.
public protocol MonaSuggestProvider: AnyObject {

    /// Supplies the completion list for `modelVersion` under `context`.
    func provideCompletions(
        modelVersion: Int,
        context: MonaCompletionContext
    ) -> MonaCompletionList

    /// Resolves `item` (e.g. enriches its documentation / detail). Returns the
    /// resolved item.
    func resolveCompletion(_ item: MonaCompletionItem) -> MonaCompletionItem
}

/// The suggest feature: trigger, filter, rank, resolve, accept, release, and
/// remember completion items.
///
/// The feature identity `suggest` and its declared slice are referenced verbatim
/// from the frozen registries. Triggered completions are retained per model
/// version so a stale version's results can be released when the model advances.
/// Accepting an item routes its insert text through `MonaTransactionGateway` as
/// one ordered unit; asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaSuggestFeature: MonaDisposable {

    /// The frozen feature identity (`"suggest"`).
    public static let featureId = "suggest"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The two
    /// labeled suggest actions: trigger ("Trigger Suggest") and reset size
    /// ("Reset Suggest Widget Size").
    public static let declaredActionIds: [String] = [
        "editor.action.triggerSuggest",
        "editor.action.resetSuggestSize"
    ]

    /// The declared command IDs in source order (alphabetical, no rename /
    /// coalesce). The twenty suggest-widget commands: the two accept variants,
    /// the two action commands, the focus commands, the hide command, the
    /// insert-best / insert-next / insert-prev commands, the select commands,
    /// the copy command, and the toggle commands.
    public static let declaredCommandIds: [String] = [
        "acceptAlternativeSelectedSuggestion",
        "acceptSelectedSuggestion",
        "acceptSelectedSuggestionOnEnter",
        "editor.action.resetSuggestSize",
        "editor.action.triggerSuggest",
        "focusAndAcceptSuggestion",
        "focusSuggestion",
        "hideSuggestWidget",
        "insertBestCompletion",
        "insertNextSuggestion",
        "insertPrevSuggestion",
        "selectFirstSuggestion",
        "selectLastSuggestion",
        "selectNextPageSuggestion",
        "selectNextSuggestion",
        "selectPrevPageSuggestion",
        "selectPrevSuggestion",
        "suggestWidgetCopy",
        "toggleSuggestionDetails",
        "toggleSuggestionFocus"
    ]

    /// The declared contribution ID (`editor.contrib.suggestController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.suggestController"
    ]

    /// The declared keybinding commands — the fourteen suggest commands that
    /// carry a default keybinding in `MonaBuiltinKeybindings`.
    public static let declaredKeybindingCommands: [String] = [
        "acceptAlternativeSelectedSuggestion",
        "acceptSelectedSuggestion",
        "editor.action.triggerSuggest",
        "focusSuggestion",
        "hideSuggestWidget",
        "insertNextSuggestion",
        "insertPrevSuggestion",
        "selectNextPageSuggestion",
        "selectNextSuggestion",
        "selectPrevPageSuggestion",
        "selectPrevSuggestion",
        "suggestWidgetCopy",
        "toggleSuggestionDetails",
        "toggleSuggestionFocus"
    ]

    /// The declared option names — the ten suggest options: the two accept
    /// options, the two quick-suggest options, the `suggest` object option, the
    /// three suggest-rendering options, the selection-mode option, and the
    /// tab-completion option.
    public static let declaredOptionIds: [String] = [
        "acceptSuggestionOnCommitCharacter",
        "acceptSuggestionOnEnter",
        "quickSuggestions",
        "quickSuggestionsDelay",
        "suggest",
        "suggestFontSize",
        "suggestLineHeight",
        "suggestOnTriggerCharacters",
        "suggestSelection",
        "tabCompletion"
    ]

    /// The declared menu IDs — the one menu that carries suggest menu items: the
    /// suggest widget status bar.
    public static let declaredMenuIds: [String] = [
        "suggestWidgetStatusBar"
    ]

    // MARK: - Routing state

    /// The completion items retained by model version. A stale model version's
    /// items are released by `release(modelVersion:)`.
    private var retainedByVersion: [Int: [MonaCompletionItem]] = [:]

    /// The currently staged items (the most recent triggered / filtered).
    private var _stagedItems: [MonaCompletionItem] = []

    /// The model version the staged items are retained against.
    private var _stagedVersion: Int?

    /// The remembered items by label (for `shareSuggestSelections` /
    /// `suggestSelection` memory).
    private var remembered: [String: MonaCompletionItem] = [:]

    private let emitter = MonaEmitter<MonaSuggestEvent>()

    /// The event stream for suggest changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaSuggestEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the suggest feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The currently staged items, or an empty array when none are staged (or
    /// after disposal).
    public var stagedItems: [MonaCompletionItem] {
        _lock.lock(); defer { _lock.unlock() }
        return _stagedItems
    }

    // MARK: - 1. Feature-specific behavior: trigger / filter / rank / resolve / accept / release / remember

    /// Triggers a completion request against `provider` for `modelVersion` under
    /// `context`, retaining the returned items keyed by model version and staging
    /// them as the current items. Fires an event with the staged items. Returns
    /// the completion list, or `nil` after `dispose()`.
    @discardableResult
    public func trigger(
        provider: MonaSuggestProvider,
        modelVersion: Int,
        context: MonaCompletionContext
    ) -> MonaCompletionList? {
        guard !isDisposed else { return nil }
        let list = provider.provideCompletions(modelVersion: modelVersion, context: context)
        _lock.lock()
        retainedByVersion[modelVersion] = list.items
        _stagedItems = list.items
        _stagedVersion = modelVersion
        _lock.unlock()
        fire(list.items, modelVersion: modelVersion)
        return list
    }

    /// The number of retained items for `modelVersion`. Zero when the version
    /// has no retained items (or after disposal).
    public func retainedCount(for modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        return retainedByVersion[modelVersion]?.count ?? 0
    }

    /// Filters the staged items by `query`: an item matches when its filter
    /// text (or label when filter text is `nil`) contains `query`
    /// (case-insensitive). Returns the matching items in staged order, or an
    /// empty array after `dispose()`.
    public func filter(_ query: String) -> [MonaCompletionItem] {
        guard !isDisposed else { return [] }
        _lock.lock()
        let items = _stagedItems
        _lock.unlock()
        let q = query.lowercased()
        return items.filter { ($0.filterText ?? $0.label).lowercased().contains(q) }
    }

    /// Ranks `items` by sort text (or label when sort text is `nil`) ascending.
    /// A pure ordering: it never mutates the model. Returns an empty array after
    /// `dispose()`.
    public func rank(_ items: [MonaCompletionItem]) -> [MonaCompletionItem] {
        guard !isDisposed else { return [] }
        return items.sorted {
            ($0.sortText ?? $0.label) < ($1.sortText ?? $1.label)
        }
    }

    /// Resolves `item` through `provider` (e.g. enriches its documentation /
    /// detail). Returns the resolved item, or `nil` after `dispose()`.
    public func resolve(
        _ item: MonaCompletionItem,
        provider: MonaSuggestProvider
    ) -> MonaCompletionItem? {
        guard !isDisposed else { return nil }
        return provider.resolveCompletion(item)
    }

    /// Accepts `item`: applies its insert text as a committed edit through
    /// `gateway` as one ordered unit. Returns the reconciliation outcome.
    /// Returns `.dropped` after `dispose()`.
    @discardableResult
    public func accept(
        _ item: MonaCompletionItem,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdit(MonaModelEditOperation(range: item.range, text: item.insertText))
        return gateway.commit(transaction)
    }

    /// Releases the items retained for `modelVersion` (the model has advanced
    /// past that version, so the results are stale). Returns the number of items
    /// released. After `dispose()`, returns `0`.
    @discardableResult
    public func release(modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        return retainedByVersion.removeValue(forKey: modelVersion)?.count ?? 0
    }

    /// Remembers `item` as the last selected completion for its label (for
    /// `shareSuggestSelections` / `suggestSelection` memory). Returns `true`
    /// when the item was newly remembered, `false` when the label was already
    /// remembered (a duplicate) or after `dispose()`.
    @discardableResult
    public func remember(_ item: MonaCompletionItem) -> Bool {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return false }
        if remembered[item.label] != nil { return false }
        remembered[item.label] = item
        return true
    }

    /// The remembered item for `label`, or `nil` when no item is remembered for
    /// that label (or after disposal).
    public func rememberedItem(for label: String) -> MonaCompletionItem? {
        _lock.lock(); defer { _lock.unlock() }
        return remembered[label]
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `items` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishCompletions(
        _ items: [MonaCompletionItem],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaCompletionItem]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(items),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained items are released, the staged
    /// items are cleared, the remembered items are cleared, and `trigger` /
    /// `filter` / `rank` / `resolve` / `accept` / `release` / `remember` are
    /// no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        retainedByVersion.removeAll()
        _stagedItems = []
        _stagedVersion = nil
        remembered.removeAll()
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

    /// The plain-text fallback language. suggest needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — suggest performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a suggest event when not disposed.
    private func fire(_ items: [MonaCompletionItem], modelVersion: Int) {
        guard !isDisposed else { return }
        emitter.fire(MonaSuggestEvent(items: items, modelVersion: modelVersion))
    }
}
