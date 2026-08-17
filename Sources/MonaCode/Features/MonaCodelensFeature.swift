// MonaCodelensFeature.swift
//
// P05-T106 — Implement retained feature codelens.
//
// `MonaCodelensFeature` is the Swift counterpart of Monaco's `codelens`
// contribution (monaco-editor 0.56.0): it renders, resolves, invokes, and
// releases code-lens results keyed by model version. A code lens is a ranged
// command rendered inline above a line; resolving completes the command,
// invoking applies its edits transactionally through `MonaTransactionGateway`,
// and releasing drops the results cached for a stale model version.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `renderCodeLenses`, `resolveCodeLens`,
//      `invokeCodeLens`, and `releaseCodeLenses`, all keyed by model version.
//   2. Register the exact feature identity `codelens` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A single edit in a code-lens command: a range to replace + the replacement
/// text.
public struct MonaCodelensEdit: Equatable {

    /// The range to replace (raw UTF-16 offsets, 1-based line / column).
    public let range: MonaRange

    /// The replacement text (empty string = deletion).
    public let text: String

    public init(range: MonaRange, text: String) {
        self.range = range
        self.text = text
    }
}

/// A command a code lens invokes: an id, a human-readable title, and the edits
/// to apply when the lens is invoked.
public struct MonaCodelensCommand: Equatable {

    /// The command id (e.g. `codelens.showReferences`).
    public let id: String

    /// The human-readable title rendered inline above the line.
    public let title: String

    /// The edits to apply when the lens command is invoked.
    public let edits: [MonaCodelensEdit]

    public init(id: String, title: String, edits: [MonaCodelensEdit] = []) {
        self.id = id
        self.title = title
        self.edits = edits
    }
}

/// A code lens: a ranged command rendered inline above a line.
public struct MonaCodelens: Equatable {

    /// The range the lens annotates.
    public let range: MonaRange

    /// The command the lens invokes.
    public let command: MonaCodelensCommand

    public init(range: MonaRange, command: MonaCodelensCommand) {
        self.range = range
        self.command = command
    }
}

/// A code-lens event: the lenses rendered / resolved / invoked.
public struct MonaCodelensEvent: Equatable {

    /// The lenses delivered by this event.
    public let lenses: [MonaCodelens]

    public init(lenses: [MonaCodelens]) {
        self.lenses = lenses
    }
}

/// The codelens feature: render, resolve, invoke, and release code-lens results
/// by model version.
///
/// The feature identity `codelens` and its declared slice are referenced
/// verbatim from the frozen registries. Rendered lenses are retained per model
/// version so a stale version's results can be released when the model
/// advances. Model mutation is routed through `MonaTransactionGateway`;
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaCodelensFeature: MonaDisposable {

    /// The frozen feature identity (`"codelens"`).
    public static let featureId = "codelens"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// `codelens.showLensesInCurrentLine` is the single labeled code-lens action.
    public static let declaredActionIds: [String] = [
        "codelens.showLensesInCurrentLine"
    ]

    /// The declared command IDs in source order. These are the code-lens command
    /// set: the provider-execute command and the show-lenses action.
    public static let declaredCommandIds: [String] = [
        "_executeCodeLensProvider",
        "codelens.showLensesInCurrentLine"
    ]

    /// The declared contribution ID (`css.editor.codeLens`).
    public static let declaredContributionIds: [String] = [
        "css.editor.codeLens"
    ]

    /// The declared keybinding commands — the code-lens commands that carry a
    /// default keybinding. codelens declares no default keybindings, so this
    /// slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — the code-lens options.
    public static let declaredOptionIds: [String] = [
        "codeLens",
        "codeLensFontFamily",
        "codeLensFontSize"
    ]

    /// The declared menu IDs — the menus that carry code-lens menu items.
    /// codelens declares no menu items, so this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The rendered code-lens results retained by model version. A stale model
    /// version's results are released by `releaseCodeLenses(modelVersion:)`.
    private var renderedByVersion: [Int: [MonaCodelens]] = [:]

    private let emitter = MonaEmitter<MonaCodelensEvent>()

    /// The event stream for code-lens changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaCodelensEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the codelens feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: render / resolve / invoke / release

    /// Renders `lenses` against `modelVersion`, retaining them keyed by model
    /// version so a stale version's results can be released when the model
    /// advances. Fires an event with the rendered lenses. Returns the rendered
    /// lenses, or an empty array after `dispose()` (a disposed feature retains
    /// no lenses).
    @discardableResult
    public func renderCodeLenses(
        _ lenses: [MonaCodelens],
        modelVersion: Int
    ) -> [MonaCodelens] {
        guard !isDisposed else { return [] }
        _lock.lock()
        renderedByVersion[modelVersion] = lenses
        _lock.unlock()
        fire(lenses)
        return lenses
    }

    /// The number of rendered lenses retained for `modelVersion`. Zero when the
    /// version has no retained results (or after disposal).
    public func renderedLensCount(for modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        return renderedByVersion[modelVersion]?.count ?? 0
    }

    /// Resolves a code lens. Resolution completes the command's payload; with no
    /// LSP resolver registered, the lens is returned as-is (its command is
    /// already resolved). Fires an event with the resolved lens. After
    /// `dispose()`, returns the lens unchanged and fires no event.
    @discardableResult
    public func resolveCodeLens(_ lens: MonaCodelens) -> MonaCodelens {
        guard !isDisposed else { return lens }
        fire([lens])
        return lens
    }

    /// Invokes `lens`'s command, applying its edits transactionally through
    /// `gateway` as one ordered unit. The edits are prepared on the transaction
    /// (labeled with the command's id) and committed; the model's text is
    /// mutated only when the transaction applies. Returns the reconciliation
    /// outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func invokeCodeLens(
        _ lens: MonaCodelens,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        let ops = lens.command.edits.map { edit in
            MonaModelEditOperation(range: edit.range, text: edit.text)
        }
        if !ops.isEmpty {
            transaction.prepareEdits(ops)
        }
        return gateway.commit(transaction)
    }

    /// Releases the rendered code-lens results retained for `modelVersion`
    /// (the model has advanced past that version, so the results are stale).
    /// Returns the number of lenses released. After `dispose()`, returns `0`.
    @discardableResult
    public func releaseCodeLenses(modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        return renderedByVersion.removeValue(forKey: modelVersion)?.count ?? 0
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `lenses` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishCodeLenses(
        _ lenses: [MonaCodelens],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaCodelens]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(lenses),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained lenses are released, and
    /// `renderCodeLenses` / `resolveCodeLens` / `invokeCodeLens` /
    /// `releaseCodeLenses` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        renderedByVersion.removeAll()
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

    /// The plain-text fallback language. codelens needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — codelens performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a code-lens event when not disposed.
    private func fire(_ lenses: [MonaCodelens]) {
        guard !isDisposed else { return }
        emitter.fire(MonaCodelensEvent(lenses: lenses))
    }
}
