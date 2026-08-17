// MonaGotoSymbolFeature.swift
//
// P05-T124 — Implement retained feature gotoSymbol.
//
// `MonaGotoSymbolFeature` is the Swift counterpart of Monaco's `gotoSymbol`
// contribution (monaco-editor 0.56.0): it filters and navigates document
// symbols while preserving provider order, reusing T115
// `MonaDocumentSymbolsFeature`'s symbol results. A document symbol is a named,
// kinded, ranged outline entry produced by the document-symbol provider; the
// gotoSymbol feature is the navigation layer over those results — it filters by
// name (case-insensitive substring, stable / order-preserving) and walks the
// filtered list next/prev with wrap-around, revealing the selected symbol's
// `selectionRange` start through the shared `MonaTransactionGateway`.
//
// The feature reuses the document-symbol value type `MonaDocumentSymbol`
// (P05-T115) directly — it introduces no parallel symbol model. "Preserving
// provider order" means the filter is stable: the order of the symbols it
// receives (already sorted by `MonaDocumentSymbolsFeature.sortDocumentSymbols`)
// is the order it filters and navigates; no re-sort is introduced.
//
// The feature is a Foundation-only surface (`import Foundation` only — the
// gotoSymbol types live in the MonaCode module). It performs the three
// implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `filterSymbols(_:query:)`: filter by name
//      (case-insensitive substring, order-preserving); `setSymbols(_:)`: stage
//      the navigable list; `navigate(_:)`: walk next/prev with wrap-around;
//      `commitNavigate(gateway:)`: reveal the selected symbol's selectionRange
//      start through the transaction gateway.
//   2. Register the exact feature identity `gotoSymbol` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A navigation direction: next or previous symbol in the filtered list.
public enum MonaGotoSymbolDirection: String, Equatable, Sendable {

    /// Navigate to the next symbol (provider order, wrap-around).
    case next

    /// Navigate to the previous symbol (provider order, wrap-around).
    case prev
}

/// A gotoSymbol event: the selected symbol and its index in the navigable list
/// (`nil` / `-1` when no symbol is selected).
public struct MonaGotoSymbolEvent: Equatable {

    /// The selected symbol, or `nil` when none is selected.
    public let selectedSymbol: MonaDocumentSymbol?

    /// The index of the selected symbol in the navigable list, or `-1` when
    /// none is selected.
    public let index: Int

    /// Creates a gotoSymbol event.
    public init(selectedSymbol: MonaDocumentSymbol?, index: Int) {
        self.selectedSymbol = selectedSymbol
        self.index = index
    }
}

/// The gotoSymbol feature: filter and navigate document symbols while
/// preserving provider order.
///
/// The feature identity `gotoSymbol` and its declared slice are referenced
/// verbatim from the frozen registries. `filterSymbols(_:query:)` is a stable,
/// case-insensitive substring filter on symbol name — it preserves the order of
/// the symbols it receives (the order `MonaDocumentSymbolsFeature` produced).
/// `navigate(_:)` walks the filtered list next/prev with wrap-around;
/// `commitNavigate(gateway:)` reveals the selected symbol's `selectionRange`
/// start through the `MonaTransactionGateway`. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaGotoSymbolFeature: MonaDisposable {

    /// The frozen feature identity (`"gotoSymbol"`).
    public static let featureId = "gotoSymbol"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). gotoSymbol
    /// owns no labeled actions — its slice is command-only. The symbol-result
    /// navigation is driven by the two commands below, which are not labeled
    /// actions in the action registry.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. These are the symbol-result
    /// navigation commands: advance to the next symbol result, and cancel the
    /// symbol-result navigation. Both are gated on the `hasSymbols` context key
    /// (set while a symbol-result navigation is active).
    public static let declaredCommandIds: [String] = [
        "editor.gotoNextSymbolFromResult",
        "editor.gotoNextSymbolFromResult.cancel"
    ]

    /// The declared contribution IDs. gotoSymbol declares no contributions of
    /// its own — it is a navigation controller that reuses
    /// `MonaDocumentSymbolsFeature`'s provider results, so this slice is empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the two symbol-result navigation
    /// commands that carry a default keybinding in `MonaBuiltinKeybindings`
    /// (`F12` advances, `Escape` cancels), in manifest source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.gotoNextSymbolFromResult",
        "editor.gotoNextSymbolFromResult.cancel"
    ]

    /// The declared option names — gotoSymbol owns no editor options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — gotoSymbol registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The navigable symbols (filtered, provider order preserved). Set by
    /// `setSymbols(_:)` (typically from `filterSymbols(_:query:)` output).
    private var symbols: [MonaDocumentSymbol] = []

    /// The index of the currently selected symbol, or `nil` when none.
    private var selectedIndex: Int? = nil

    private let emitter = MonaEmitter<MonaGotoSymbolEvent>()

    /// The event stream for gotoSymbol changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaGotoSymbolEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the gotoSymbol feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The currently selected symbol, or `nil` when none is selected.
    public var selectedSymbol: MonaDocumentSymbol? {
        _lock.lock(); defer { _lock.unlock() }
        guard let index = selectedIndex, symbols.indices.contains(index) else {
            return nil
        }
        return symbols[index]
    }

    // MARK: - 1. Feature-specific behavior: filter + navigate (provider order)

    /// Filters `symbols` by name against `query` (case-insensitive substring),
    /// preserving provider order. An empty `query` returns every symbol in the
    /// order received. Returns an empty array after `dispose()`.
    ///
    /// This is a stable filter: the relative order of the symbols it receives
    /// (the order `MonaDocumentSymbolsFeature` produced) is preserved in the
    /// output; gotoSymbol introduces no re-sort.
    public func filterSymbols(
        _ symbols: [MonaDocumentSymbol],
        query: String
    ) -> [MonaDocumentSymbol] {
        guard !isDisposed else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return symbols
        }
        let lowered = trimmed.lowercased()
        return symbols.filter { $0.name.lowercased().contains(lowered) }
    }

    /// Stages `symbols` as the navigable list and resets the selection. Pass
    /// the output of `filterSymbols(_:query:)` to navigate a filtered view, or
    /// the full provider results to navigate all symbols. A no-op after
    /// `dispose()`.
    public func setSymbols(_ symbols: [MonaDocumentSymbol]) {
        guard !isDisposed else { return }
        _lock.lock()
        self.symbols = symbols
        self.selectedIndex = nil
        _lock.unlock()
    }

    /// The number of symbols in the navigable list.
    public var symbolCount: Int {
        _lock.lock(); defer { _lock.unlock() }
        return symbols.count
    }

    /// Navigates in `direction` (`.next` / `.prev`) through the navigable list
    /// with wrap-around. Sets the selection, fires an event, and returns the
    /// selected symbol. Returns `nil` when the list is empty or after
    /// `dispose()`.
    @discardableResult
    public func navigate(
        _ direction: MonaGotoSymbolDirection
    ) -> MonaDocumentSymbol? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard !symbols.isEmpty else {
            _lock.unlock()
            return nil
        }
        let count = symbols.count
        let nextIndex: Int
        switch direction {
        case .next:
            nextIndex = (selectedIndex.map { ($0 + 1) % count } ?? 0)
        case .prev:
            nextIndex = (selectedIndex.map { ($0 - 1 + count) % count } ?? (count - 1))
        }
        selectedIndex = nextIndex
        let selected = symbols[nextIndex]
        _lock.unlock()
        fire(.init(selectedSymbol: selected, index: nextIndex))
        return selected
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals the selected symbol through the shared transaction gateway:
    /// begins a transaction, prepares a collapsed selection at the selected
    /// symbol's `selectionRange` start position, and commits the unit. Returns
    /// the committed selections (empty when the feature is disposed, no symbol
    /// is selected, or the commit dropped).
    @discardableResult
    public func commitNavigate(gateway: MonaTransactionGateway) -> [MonaSelection] {
        guard !isDisposed, let symbol = selectedSymbol else { return [] }
        let position = symbol.selectionRange.startPosition
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
    public func publishGotoSymbolEvent(
        _ event: MonaGotoSymbolEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaGotoSymbolEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the navigable list is cleared, and
    /// `setSymbols` / `navigate` / `commitNavigate` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        symbols = []
        selectedIndex = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. gotoSymbol owns no labeled
    /// actions, so this is always empty; the route still resolves through
    /// `MonaLocalization` for consistency with the other features.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. gotoSymbol needs no tokenization; it
    /// degrades to plain text for any tokenization need.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — gotoSymbol performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a gotoSymbol event when not disposed.
    private func fire(_ event: MonaGotoSymbolEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
