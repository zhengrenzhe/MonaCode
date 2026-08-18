// MonaLineSelectionFeature.swift
//
// P05-T133 — Implement retained feature lineSelection.
//
// `MonaLineSelectionFeature` is the Swift counterpart of Monaco's `lineSelection`
// contribution (monaco-editor 0.56.0): it creates and extends whole-line
// selections against a model, applying the final-line edge handling Monaco's
// gutter-click line selection uses. A non-final line's whole-line range spans
// column 1 of the line to column 1 of the next line (the line terminator is
// included); the final line — which has no trailing terminator — ends at the
// line's max column (length + 1). Replacements committed against a whole-line
// range are applied transactionally through `MonaTransactionGateway`.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `wholeLineRange(line:model:)`,
//      `extendWholeLineRange(from:to:model:)`, and
//      `applyReplacement(to:text:gateway:)`, all with final-line edge handling.
//   2. Register the exact feature identity `lineSelection` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//      `lineSelection` is a pure mouse-interaction contribution and declares no
//      actions, commands, contributions, options, menus, or keybindings, so every
//      declared slice is empty; only the feature identity is live.
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A line-selection kind: whether a whole-line range was just created, extended,
/// or had its content replaced.
public enum MonaLineSelectionKind: String, Equatable {

    /// A whole-line selection was created (single-line gutter click).
    case created

    /// A whole-line selection was extended across multiple lines (shift-click).
    case extended

    /// A whole-line selection's content was replaced through the transaction
    /// gateway.
    case replaced
}

/// A line-selection event: the kind and the affected whole-line range.
public struct MonaLineSelectionEvent: Equatable {

    /// The kind that fired.
    public let kind: MonaLineSelectionKind

    /// The whole-line range the event covers.
    public let range: MonaRange

    public init(kind: MonaLineSelectionKind, range: MonaRange) {
        self.kind = kind
        self.range = range
    }
}

/// The line-selection feature: create and extend whole-line selections with
/// final-line edge handling, committing replacements through the transaction
/// gateway.
///
/// The feature identity `lineSelection` and its declared slice are referenced
/// verbatim from the frozen registries. Because `lineSelection` is a pure
/// mouse-interaction contribution, every declared slice (actions, commands,
/// contributions, options, menus, keybindings) is empty; only the feature
/// identity is live. Model mutation is routed through `MonaTransactionGateway`;
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaLineSelectionFeature: MonaDisposable {

    /// The frozen feature identity (`"lineSelection"`).
    public static let featureId = "lineSelection"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// `lineSelection` is a pure mouse-interaction contribution and registers no
    /// editor actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. `lineSelection` registers no
    /// editor commands, so this slice is empty.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs. `lineSelection` registers no contribution
    /// descriptor in the F1-R3 scope manifest, so this slice is empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands. `lineSelection` carries no default
    /// keybinding, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. `lineSelection` declares no options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs. `lineSelection` registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaLineSelectionEvent>()

    /// The event stream for line-selection changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaLineSelectionEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the line-selection feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: create + extend whole-line selections

    /// Returns the whole-line range for `line` in `model`, applying the
    /// final-line edge handling Monaco's gutter-click line selection uses.
    ///
    /// A non-final line's range spans column 1 of `line` to column 1 of the next
    /// line (the line terminator is included). The final line — which has no
    /// trailing terminator — ends at the line's max column (length + 1). Returns
    /// `nil` when `line` is out of range or after `dispose()`.
    public func wholeLineRange(line: Int, model: MonaCodeModel) -> MonaRange? {
        guard !isDisposed else { return nil }
        let count = model.getLineCount()
        guard line >= 1, line <= count else { return nil }
        let start = MonaPosition(line: line, column: 1)
        if line == count {
            // Final line: no trailing terminator to include; end at max column.
            let end = MonaPosition(line: line, column: model.getLineMaxColumn(line))
            return MonaRange(startPosition: start, endPosition: end)
        }
        // Non-final line: include the line terminator (column 1 of next line).
        let end = MonaPosition(line: line + 1, column: 1)
        return MonaRange(startPosition: start, endPosition: end)
    }

    /// Returns a whole-line range spanning `from` to `to` (inclusive) in `model`,
    /// normalized so that the earlier line is the start. The range ends at column
    /// 1 of the line after the later line, unless the later line is the final line
    /// — in which case it ends at the final line's max column. Returns `nil` when
    /// either line is out of range or after `dispose()`.
    public func extendWholeLineRange(from: Int, to: Int, model: MonaCodeModel) -> MonaRange? {
        guard !isDisposed else { return nil }
        let count = model.getLineCount()
        let lower = min(from, to)
        let upper = max(from, to)
        guard lower >= 1, upper <= count, lower <= upper else { return nil }
        let start = MonaPosition(line: lower, column: 1)
        let end: MonaPosition
        if upper == count {
            end = MonaPosition(line: upper, column: model.getLineMaxColumn(upper))
        } else {
            end = MonaPosition(line: upper + 1, column: 1)
        }
        return MonaRange(startPosition: start, endPosition: end)
    }

    /// Replaces `range`'s content with `text`, committed transactionally through
    /// `gateway` as one ordered unit. Returns `.dropped` after `dispose()`;
    /// otherwise returns the reconciliation outcome. Fires a `.replaced` event
    /// on a successful application.
    @discardableResult
    public func applyReplacement(
        to range: MonaRange,
        text: String,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([MonaModelEditOperation(range: range, text: text)])
        let outcome = gateway.commit(transaction)
        if case .applied = outcome {
            fire(.init(kind: .replaced, range: range))
        }
        return outcome
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishLineSelectionEvent(
        _ event: MonaLineSelectionEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaLineSelectionEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `wholeLineRange` /
    /// `extendWholeLineRange` / `applyReplacement` are no-ops (return `nil` /
    /// `.dropped`).
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
    /// `MonaLocalization` surface under `profile`. `lineSelection` declares no
    /// actions, so this is always empty.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. lineSelection performs no
    /// tokenization-dependent work and degrades gracefully to the plain-text
    /// fallback.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — lineSelection performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a line-selection event when not disposed.
    private func fire(_ event: MonaLineSelectionEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
