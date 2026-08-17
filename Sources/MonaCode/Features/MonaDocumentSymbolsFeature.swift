// MonaDocumentSymbolsFeature.swift
//
// P05-T115 — Implement retained feature documentSymbols.
//
// `MonaDocumentSymbolsFeature` is the Swift counterpart of Monaco's
// `documentSymbols` contribution (monaco-editor 0.56.0): it requests,
// version-gates, sorts, and exposes document-symbol provider results keyed by
// model version. A document symbol is a named, kinded, ranged outline entry
// (the `quickOutline` / symbol-outline tree); the results are retained per
// model version so a stale version's results can be released when the model
// advances, and a symbol command's edits apply transactionally through
// `MonaTransactionGateway`.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `requestDocumentSymbols`,
//      `releaseDocumentSymbols`, `invokeDocumentSymbol`, all keyed by model
//      version.
//   2. Register the exact feature identity `documentSymbols` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A document-symbol kind, mirroring the Monaco `SymbolKind` taxonomy
/// (monaco-editor 0.56.0, `SymbolKind`). The numeric raw values match Monaco's
/// `SymbolKind` constants verbatim.
public enum MonaDocumentSymbolKind: Int, Equatable, Sendable {

    case file = 0
    case module = 1
    case namespace = 2
    case package = 3
    case classKind = 4
    case method = 5
    case property = 6
    case field = 7
    case constructor = 8
    case enumKind = 9
    case interface = 10
    case function = 11
    case variable = 12
    case constant = 13
    case string = 14
    case number = 15
    case boolean = 16
    case array = 17
    case object = 18
    case key = 19
    case null = 20
    case enumMember = 21
    case `struct` = 22
    case event = 23
    case operatorKind = 24
    case typeParameter = 25
}

/// A single edit in a document-symbol command: a range to replace + the
/// replacement text.
public struct MonaDocumentSymbolEdit: Equatable {

    /// The range to replace (raw UTF-16 offsets, 1-based line / column).
    public let range: MonaRange

    /// The replacement text (empty string = deletion).
    public let text: String

    public init(range: MonaRange, text: String) {
        self.range = range
        self.text = text
    }
}

/// A command a document symbol invokes: an id, a human-readable title, and the
/// edits to apply when the command is invoked.
public struct MonaDocumentSymbolCommand: Equatable {

    /// The command id (e.g. `editor.action.quickOutline`).
    public let id: String

    /// The human-readable title.
    public let title: String

    /// The edits to apply when the command is invoked.
    public let edits: [MonaDocumentSymbolEdit]

    public init(id: String, title: String, edits: [MonaDocumentSymbolEdit] = []) {
        self.id = id
        self.title = title
        self.edits = edits
    }
}

/// A document symbol: a named, kinded, ranged outline entry with optional
/// children and an optional command.
public struct MonaDocumentSymbol: Equatable {

    /// The symbol name.
    public let name: String

    /// Optional detail (e.g. a type signature).
    public let detail: String?

    /// The symbol kind.
    public let kind: MonaDocumentSymbolKind

    /// The full range the symbol spans.
    public let range: MonaRange

    /// The range to select when navigating to the symbol.
    public let selectionRange: MonaRange

    /// The child symbols (nested outline entries).
    public let children: [MonaDocumentSymbol]

    /// The command the symbol invokes, when present.
    public let command: MonaDocumentSymbolCommand?

    public init(
        name: String,
        detail: String? = nil,
        kind: MonaDocumentSymbolKind,
        range: MonaRange,
        selectionRange: MonaRange,
        children: [MonaDocumentSymbol] = [],
        command: MonaDocumentSymbolCommand? = nil
    ) {
        self.name = name
        self.detail = detail
        self.kind = kind
        self.range = range
        self.selectionRange = selectionRange
        self.children = children
        self.command = command
    }
}

/// A document-symbols event: the symbols requested / released.
public struct MonaDocumentSymbolsEvent: Equatable {

    /// The symbols delivered by this event.
    public let symbols: [MonaDocumentSymbol]

    public init(symbols: [MonaDocumentSymbol]) {
        self.symbols = symbols
    }
}

/// The documentSymbols feature: request, version-gate, sort, and expose
/// document-symbol provider results.
///
/// The feature identity `documentSymbols` and its declared slice are referenced
/// verbatim from the frozen registries. Requested symbols are retained per model
/// version so a stale version's results can be released when the model advances.
/// Symbols are sorted by range start position (line, then column) then by name
/// (matching Monaco's outline ordering). A symbol command's edits are routed
/// through `MonaTransactionGateway` as one ordered unit; asynchronous publication
/// through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaDocumentSymbolsFeature: MonaDisposable {

    /// The frozen feature identity (`"documentSymbols"`).
    public static let featureId = "documentSymbols"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// `editor.action.quickOutline` is the single labeled document-symbol action
    /// ("Go to Symbol...").
    public static let declaredActionIds: [String] = [
        "editor.action.quickOutline"
    ]

    /// The declared command IDs in source order. These are the document-symbol
    /// command set: the provider-execute command and the quick-outline action.
    public static let declaredCommandIds: [String] = [
        "_executeDocumentSymbolProvider",
        "editor.action.quickOutline"
    ]

    /// The declared contribution IDs. documentSymbols declares no contributions
    /// — it is a provider registry, not a contribution controller.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the document-symbol commands that
    /// carry a default keybinding. `editor.action.quickOutline` carries the
    /// default `Cmd+Shift+O` keybinding.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.quickOutline"
    ]

    /// The declared option names. documentSymbols declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — the menus that carry document-symbol menu items.
    /// `editor.action.quickOutline` appears in the `EditorContext` menu.
    public static let declaredMenuIds: [String] = [
        "EditorContext"
    ]

    // MARK: - Routing state

    /// The requested document-symbol results retained by model version. A stale
    /// model version's results are released by
    /// `releaseDocumentSymbols(modelVersion:)`.
    private var retainedByVersion: [Int: [MonaDocumentSymbol]] = [:]

    private let emitter = MonaEmitter<MonaDocumentSymbolsEvent>()

    /// The event stream for document-symbol changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaDocumentSymbolsEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the documentSymbols feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: request / version-gate / sort / expose

    /// Requests `symbols` against `modelVersion`, sorting them by range start
    /// position (line, then column) then by name, retaining them keyed by model
    /// version so a stale version's results can be released when the model
    /// advances. Fires an event with the sorted symbols. Returns the sorted
    /// symbols, or an empty array after `dispose()` (a disposed feature retains
    /// no symbols).
    @discardableResult
    public func requestDocumentSymbols(
        _ symbols: [MonaDocumentSymbol],
        modelVersion: Int
    ) -> [MonaDocumentSymbol] {
        guard !isDisposed else { return [] }
        let sorted = Self.sortDocumentSymbols(symbols)
        _lock.lock()
        retainedByVersion[modelVersion] = sorted
        _lock.unlock()
        fire(sorted)
        return sorted
    }

    /// The number of retained symbols for `modelVersion`. Zero when the version
    /// has no retained results (or after disposal).
    public func retainedSymbolCount(for modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        return retainedByVersion[modelVersion]?.count ?? 0
    }

    /// Releases the requested document-symbol results retained for
    /// `modelVersion` (the model has advanced past that version, so the results
    /// are stale). Returns the number of symbols released. After `dispose()`,
    /// returns `0`.
    @discardableResult
    public func releaseDocumentSymbols(modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        return retainedByVersion.removeValue(forKey: modelVersion)?.count ?? 0
    }

    /// Invokes `symbol`'s command, applying its edits transactionally through
    /// `gateway` as one ordered unit. The edits are prepared on the transaction
    /// (labeled with the command's id) and committed; the model's text is mutated
    /// only when the transaction applies. When the symbol carries no command,
    /// the invocation is acknowledged (`.applied`, no edit prepared). Returns
    /// the reconciliation outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func invokeDocumentSymbol(
        _ symbol: MonaDocumentSymbol,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        guard let command = symbol.command else {
            // No command: acknowledged (navigation only, no model mutation).
            return .applied
        }
        let transaction = gateway.beginTransaction()
        let ops = command.edits.map { edit in
            MonaModelEditOperation(range: edit.range, text: edit.text)
        }
        if !ops.isEmpty {
            transaction.prepareEdits(ops)
        }
        return gateway.commit(transaction)
    }

    /// Sorts `symbols` by range start position (line, then column) then by name.
    /// This is the stable ordering Monaco's outline uses to present symbols.
    public static func sortDocumentSymbols(
        _ symbols: [MonaDocumentSymbol]
    ) -> [MonaDocumentSymbol] {
        return symbols.sorted { a, b in
            let aStart = a.range.startPosition
            let bStart = b.range.startPosition
            if aStart.line != bStart.line {
                return aStart.line < bStart.line
            }
            if aStart.column != bStart.column {
                return aStart.column < bStart.column
            }
            return a.name < b.name
        }
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `symbols` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishDocumentSymbols(
        _ symbols: [MonaDocumentSymbol],
        modelVersion: Int,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaDocumentSymbol]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(symbols),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained symbols are released, and
    /// `requestDocumentSymbols` / `releaseDocumentSymbols` / `invokeDocumentSymbol`
    /// are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        retainedByVersion.removeAll()
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

    /// The plain-text fallback language. documentSymbols needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — documentSymbols performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a document-symbols event when not disposed.
    private func fire(_ symbols: [MonaDocumentSymbol]) {
        guard !isDisposed else { return }
        emitter.fire(MonaDocumentSymbolsEvent(symbols: symbols))
    }
}
