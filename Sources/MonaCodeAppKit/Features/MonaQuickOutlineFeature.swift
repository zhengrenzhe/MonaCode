// MonaQuickOutlineFeature.swift
//
// P05-T144 — Implement retained feature quickOutline.
//
// `MonaQuickOutlineFeature` is the Swift counterpart of Monaco's
// `quickOutline` contribution (monaco-editor 0.56.0): it filters, groups, and
// navigates document symbols in the quick outline picker. The symbol results
// are reused from T115 `MonaDocumentSymbolsFeature` — this feature does NOT
// request symbols itself; it consumes the `MonaDocumentSymbol` results and
// presents them as filterable, groupable, navigable outline entries.
//
// Filtering is a case-insensitive substring match over the symbol name.
// Grouping collects entries by `MonaDocumentSymbolKind`, preserving the order
// of first appearance. Navigation reveals the symbol's selection-range start
// position through the shared `MonaTransactionGateway` (a collapsed selection
// at the reveal anchor).
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `filterSymbols(query:from:)`,
//      `groupSymbols(_:)`, `navigateToSymbol(_:gateway:)`: filter the document
//      symbols by query, group by kind, and navigate to a symbol's position.
//   2. Register the exact feature identity `quickOutline` and its declared
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

/// A quick-outline entry: a symbol's name, kind, selection range, and optional
/// detail, flattened from the `MonaDocumentSymbol` tree (T115).
public struct MonaQuickOutlineEntry: Equatable {

    /// The symbol name.
    public let name: String

    /// The symbol kind.
    public let kind: MonaDocumentSymbolKind

    /// The range to select when navigating to the symbol.
    public let selectionRange: MonaRange

    /// Optional detail (e.g. a type signature).
    public let detail: String?

    public init(name: String, kind: MonaDocumentSymbolKind, selectionRange: MonaRange, detail: String?) {
        self.name = name
        self.kind = kind
        self.selectionRange = selectionRange
        self.detail = detail
    }
}

/// A quick-outline group: all entries of one symbol kind.
public struct MonaQuickOutlineGroup: Equatable {

    /// The symbol kind shared by every entry in this group.
    public let kind: MonaDocumentSymbolKind

    /// The entries in this group, in filtered order.
    public let entries: [MonaQuickOutlineEntry]

    public init(kind: MonaDocumentSymbolKind, entries: [MonaQuickOutlineEntry]) {
        self.kind = kind
        self.entries = entries
    }
}

/// A quickOutline event: the filtered entries.
public struct MonaQuickOutlineEvent: Equatable {

    /// The filtered entries after the change.
    public let entries: [MonaQuickOutlineEntry]

    public init(entries: [MonaQuickOutlineEntry]) {
        self.entries = entries
    }
}

/// The quickOutline feature: filter, group, and navigate document symbols in
/// the quick outline.
///
/// The feature identity `quickOutline` and its declared slice are referenced
/// verbatim from the frozen registries. The symbol results are reused from
/// `MonaDocumentSymbolsFeature` (T115) — this feature does NOT request symbols
/// itself. Navigation (revealing a symbol's position) is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaQuickOutlineFeature: MonaDisposable {

    /// The frozen feature identity (`"quickOutline"`).
    public static let featureId = "quickOutline"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single quick-outline action (`editor.action.quickOutline`, ordinal 164,
    /// "Go to Symbol...").
    public static let declaredActionIds: [String] = [
        "editor.action.quickOutline"
    ]

    /// The declared command IDs in source order. The quick-outline action is
    /// the single declared command.
    public static let declaredCommandIds: [String] = [
        "editor.action.quickOutline"
    ]

    /// The declared contribution IDs. The shared quick-input controller
    /// (`editor.controller.quickInput`, ordinal 52) is the quick-outline
    /// surface's contribution.
    public static let declaredContributionIds: [String] = [
        "editor.controller.quickInput"
    ]

    /// The declared keybinding commands — the quick-outline action carries the
    /// default `Cmd+Shift+O` keybinding (keyCode 45).
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.quickOutline"
    ]

    /// The declared option names. quickOutline owns no editor options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — the `EditorContext` menu carries the
    /// quick-outline menu item (group `navigation`).
    public static let declaredMenuIds: [String] = [
        "EditorContext"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaQuickOutlineEvent>()

    /// The event stream for quickOutline changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaQuickOutlineEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the quickOutline feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: filter, group, navigate

    /// Filters `symbols` (T115 `MonaDocumentSymbol` results) by `query` (a
    /// case-insensitive substring match over the symbol name), flattening the
    /// symbol tree into outline entries. Fires an event with the filtered
    /// entries. Returns an empty array after `dispose()`.
    @discardableResult
    public func filterSymbols(
        query: String,
        from symbols: [MonaDocumentSymbol]
    ) -> [MonaQuickOutlineEntry] {
        guard !isDisposed else {
            emitter.fire(MonaQuickOutlineEvent(entries: []))
            return []
        }
        let needle = query.lowercased()
        var entries: [MonaQuickOutlineEntry] = []
        Self.flatten(symbols, needle: needle, into: &entries)
        emitter.fire(MonaQuickOutlineEvent(entries: entries))
        return entries
    }

    /// Groups `entries` by `MonaDocumentSymbolKind`, preserving the order of
    /// first appearance. Returns an empty array after `dispose()`.
    public func groupSymbols(
        _ entries: [MonaQuickOutlineEntry]
    ) -> [MonaQuickOutlineGroup] {
        guard !isDisposed else { return [] }
        var order: [MonaDocumentSymbolKind] = []
        var buckets: [MonaDocumentSymbolKind: [MonaQuickOutlineEntry]] = [:]
        for entry in entries {
            if buckets[entry.kind] == nil {
                order.append(entry.kind)
            }
            buckets[entry.kind, default: []].append(entry)
        }
        return order.map { kind in
            MonaQuickOutlineGroup(kind: kind, entries: buckets[kind] ?? [])
        }
    }

    /// Navigates to `entry` by revealing its selection-range start position
    /// through the shared `MonaTransactionGateway`: begins a transaction,
    /// prepares a collapsed selection at the reveal anchor, and commits the
    /// unit. Returns the committed selections (empty when the feature is
    /// disposed or the commit dropped).
    @discardableResult
    public func navigateToSymbol(
        _ entry: MonaQuickOutlineEntry,
        gateway: MonaTransactionGateway
    ) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        let position = entry.selectionRange.startPosition
        let tx = gateway.beginTransaction()
        let selection = MonaSelection(anchor: position, activePosition: position)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Commits `edits` (the model mutations produced by an outline command)
    /// through `gateway` as one ordered unit. Returns the reconciliation
    /// outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitOutlineEdits(
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
        _ entries: [MonaQuickOutlineEntry],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaQuickOutlineEntry]) -> Void
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
    /// disposal, listeners are dropped, and `filterSymbols` / `groupSymbols`
    /// / `navigateToSymbol` / `commitOutlineEdits` / `publishEntries` are
    /// no-ops.
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
    /// `MonaLocalization` surface under `profile`. The quick-outline action
    /// label ("Go to Symbol...") is formatted under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. quickOutline needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — quickOutline performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Recursively flattens the `MonaDocumentSymbol` tree into `entries`,
    /// filtering by `needle` (case-insensitive substring on the symbol name).
    /// A non-matching symbol with matching children is still traversed (its
    /// matching children appear), but the non-matching symbol itself is
    /// omitted.
    private static func flatten(
        _ symbols: [MonaDocumentSymbol],
        needle: String,
        into entries: inout [MonaQuickOutlineEntry]
    ) {
        for symbol in symbols {
            let matches = needle.isEmpty
                || symbol.name.lowercased().contains(needle)
            if matches {
                entries.append(MonaQuickOutlineEntry(
                    name: symbol.name,
                    kind: symbol.kind,
                    selectionRange: symbol.selectionRange,
                    detail: symbol.detail
                ))
            }
            if !symbol.children.isEmpty {
                flatten(symbol.children, needle: needle, into: &entries)
            }
        }
    }
}
