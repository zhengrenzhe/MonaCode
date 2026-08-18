// MonaInsertFinalNewLineFeature.swift
//
// P05-T131 — Implement retained feature insertFinalNewLine.
//
// `MonaInsertFinalNewLineFeature` is the Swift counterpart of Monaco's
// `insertFinalNewLine` action (monaco-editor 0.56.0): it inserts a final line
// terminator at the end of the document under explicit command control — but
// only when the document does not already end with one. The edit is applied
// transactionally through `MonaTransactionGateway`.
//
// "Already ends with a line terminator" covers `\n`, `\r\n`, and bare `\r`. The
// inserted terminator is the model's declared EOL (`MonaCodeModel.getEOL()`).
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `insertFinalNewLine(gateway:)`: append the
//      model EOL when the document does not already end with a line
//      terminator, committed through `MonaTransactionGateway`.
//   2. Register the exact feature identity `insertFinalNewLine` and its
//      declared commands, actions, contributions, options, menus, and
//      keybindings, referenced verbatim from the frozen registries (no rename /
//      coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// An insert-final-new-line event: the empty range at the document end where the
/// terminator was inserted, and the terminator string written.
public struct MonaInsertFinalNewLineEvent: Equatable {

    /// The insertion range (an empty range at the document end, in pre-edit
    /// coordinates).
    public let range: MonaRange

    /// The line terminator inserted (the model's declared EOL).
    public let terminator: String

    public init(range: MonaRange, terminator: String) {
        self.range = range
        self.terminator = terminator
    }
}

/// The insert-final-new-line feature: insert a final line terminator under
/// explicit command control.
///
/// The feature identity `insertFinalNewLine` and its declared slice are
/// referenced verbatim from the frozen registries. `insertFinalNewLine` appends
/// the model's EOL when the document does not already end with a line
/// terminator; otherwise it is a no-op. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaInsertFinalNewLineFeature: MonaDisposable {

    /// The frozen feature identity (`"insertFinalNewLine"`).
    public static let featureId = "insertFinalNewLine"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single insert-final-new-line action (ordinal 136).
    public static let declaredActionIds: [String] = [
        "editor.action.insertFinalNewLine"
    ]

    /// The declared command IDs in source order. The insert-final-new-line
    /// action is also registered as an editor command, so this slice equals
    /// `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution IDs. insertFinalNewLine declares no
    /// contributions in the F1-R3 scope manifest, so this slice is empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — insertFinalNewLine carries no default
    /// keybinding in `MonaBuiltinKeybindings`, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — insertFinalNewLine declares no options in the
    /// F1-R3 scope manifest, so this slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — insertFinalNewLine registers no menu items, so
    /// this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaInsertFinalNewLineEvent>()

    /// The event stream for insert-final-new-line changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaInsertFinalNewLineEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the insert-final-new-line feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: insert a final line terminator

    /// `true` when `value` already ends with a line terminator (`\n`, `\r\n`,
    /// or bare `\r`). Checked against the last unicode scalar so that a CRLF
    /// pair (which Swift collapses into a single extended grapheme cluster) is
    /// detected as a terminator.
    private func endsWithLineTerminator(_ value: String) -> Bool {
        guard let last = value.unicodeScalars.last else { return false }
        return last == "\n" || last == "\r"
    }

    /// Inserts a final line terminator at the end of `gateway.model` when the
    /// document does not already end with one. The inserted terminator is the
    /// model's declared EOL (`getEOL()`). The edit is committed transactionally
    /// through `gateway`. Returns `.dropped` when the document already ends with
    /// a line terminator, or after `dispose()`. Fires an event on success.
    @discardableResult
    public func insertFinalNewLine(gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let value = model.getValue()
        guard !endsWithLineTerminator(value) else {
            return .dropped(reason: "already ends with line terminator")
        }

        let lastLine = model.getLineCount()
        let endColumn = model.getLineMaxColumn(lastLine)
        let endPosition = MonaPosition(line: lastLine, column: endColumn)
        let terminator = model.getEOL()
        let range = MonaRange(startPosition: endPosition, endPosition: endPosition)
        let ops = [MonaModelEditOperation(range: range, text: terminator)]
        let outcome = commit(ops, gateway: gateway)
        if case .applied = outcome {
            fire(.init(range: range, terminator: terminator))
        }
        return outcome
    }

    /// Commits `ops` as one transactional batch through `gateway`. An empty
    /// batch still commits (a no-op transaction applies cleanly).
    private func commit(_ ops: [MonaModelEditOperation], gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        let transaction = gateway.beginTransaction()
        if !ops.isEmpty {
            transaction.prepareEdits(ops)
        }
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishInsertEvent(
        _ event: MonaInsertFinalNewLineEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaInsertFinalNewLineEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `insertFinalNewLine` is a no-op
    /// (returns `.dropped`).
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

    /// The plain-text fallback language. insertFinalNewLine performs no
    /// tokenization-dependent work; it degrades to plain text for any
    /// tokenization need.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — insertFinalNewLine performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires an insert-final-new-line event when not disposed.
    private func fire(_ event: MonaInsertFinalNewLineEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
