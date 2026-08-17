// MonaGotoLineFeature.swift
//
// P05-T123 — Implement retained feature gotoLine.
//
// `MonaGotoLineFeature` is the Swift counterpart of Monaco's `gotoLine`
// contribution (monaco-editor 0.56.0): it parses line and column input
// (`line`, `line:column`, `line,column`), validates the parsed coordinate
// through the base-model `MonaPosition` validation (P01-T001), and reveals the
// validated model position through the shared `MonaTransactionGateway`.
//
// Parsing mirrors Monaco's `GotoLine` input contract: a bare line number
// defaults the column to 1; a `line:column` or `line,column` pair supplies both.
// Whitespace is trimmed. Validation reuses `MonaPosition.validate` /
// `MonaPosition.validateOrNil` (P01-T001) — the feature introduces no parallel
// validation path. Revealing the validated position prepares a collapsed
// selection at that position on a transaction and commits the unit through the
// gateway.
//
// The feature is a Foundation-only surface (`import Foundation` only — the
// gotoLine types live in the MonaCode module). It performs the three
// implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `parse` / `validate` / `parseAndValidate`:
//      parse line/column input and validate the coordinate through
//      `MonaPosition`; `reveal(position:)`: stage the reveal;
//      `commitReveal(gateway:position:)`: reveal through the transaction gateway.
//   2. Register the exact feature identity `gotoLine` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A parsed goto-line input: a line and (optional) column. When the input omits
/// the column, `column` defaults to 1.
public struct MonaGotoLineInput: Equatable {

    /// The parsed line number (1-based).
    public let line: Int

    /// The parsed column (1-based). Defaults to 1 when the input omits it.
    public let column: Int

    /// Creates a parsed goto-line input.
    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

/// A gotoLine event: the position revealed by the most recent `reveal`.
public struct MonaGotoLineEvent: Equatable {

    /// The revealed position, or `nil` when no position has been revealed.
    public let revealedPosition: MonaPosition?

    /// Creates a gotoLine event.
    public init(revealedPosition: MonaPosition?) {
        self.revealedPosition = revealedPosition
    }
}

/// The gotoLine feature: parse line/column input, validate the coordinate
/// through `MonaPosition`, and reveal the validated model position.
///
/// The feature identity `gotoLine` and its declared slice are referenced verbatim
/// from the frozen registries. Parsing accepts `line`, `line:column`, and
/// `line,column` (whitespace trimmed); validation reuses
/// `MonaPosition.validateOrNil(line:column:mode:)` (P01-T001). Model mutation is
/// routed through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaGotoLineFeature: MonaDisposable {

    /// The frozen feature identity (`"gotoLine"`).
    public static let featureId = "gotoLine"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The one
    /// gotoLine action (ordinal 70).
    public static let declaredActionIds: [String] = [
        "editor.action.gotoLine"
    ]

    /// The declared command IDs in source order. The gotoLine action is also
    /// registered as an editor command, so this slice equals `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution IDs. gotoLine owns no contribution of its own
    /// (it is a command + action with no controller), so this slice is empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the one gotoLine command that carries
    /// a default keybinding in `MonaBuiltinKeybindings`.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.gotoLine"
    ]

    /// The declared option names — gotoLine owns no editor options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — gotoLine registers no menu items, so this slice
    /// is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaGotoLineEvent>()

    /// The event stream for gotoLine changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaGotoLineEvent> { emitter.event }

    /// The most recently revealed position (staged by `reveal(position:)`), or
    /// `nil` when none has been staged.
    private var _revealedPosition: MonaPosition? = nil

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the gotoLine feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: parse + validate + reveal

    /// Parses `input` into a line/column pair. Accepts `line`, `line:column`, and
    /// `line,column` (whitespace trimmed). A bare line defaults the column to 1.
    /// Returns `nil` when the input is empty or non-numeric.
    public func parse(_ input: String) -> MonaGotoLineInput? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Split on the first ':' or ',' separator.
        var separatorIndex: String.Index? = nil
        for sep in [":", ","] {
            if let idx = trimmed.firstIndex(of: Character(sep)) {
                separatorIndex = idx
                break
            }
        }
        if let sep = separatorIndex {
            let linePart = String(trimmed[..<sep]).trimmingCharacters(in: .whitespaces)
            let columnPart = String(trimmed[trimmed.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
            guard let line = Int(linePart), let column = Int(columnPart) else {
                return nil
            }
            return MonaGotoLineInput(line: line, column: column)
        }
        guard let line = Int(trimmed) else { return nil }
        return MonaGotoLineInput(line: line, column: 1)
    }

    /// Validates `line` and `column` according to `mode`, reusing
    /// `MonaPosition.validateOrNil(line:column:mode:)` (P01-T001). Returns the
    /// validated position, or `nil` when rejected.
    public func validate(
        line: Int,
        column: Int,
        mode: MonaPositionValidationMode
    ) -> MonaPosition? {
        return MonaPosition.validateOrNil(line: line, column: column, mode: mode)
    }

    /// Convenience: parses `input` and validates the parsed coordinate according
    /// to `mode`. Returns the validated position, or `nil` when the input fails
    /// to parse or the coordinate is rejected.
    public func parseAndValidate(
        _ input: String,
        mode: MonaPositionValidationMode
    ) -> MonaPosition? {
        guard let parsed = parse(input) else { return nil }
        return validate(line: parsed.line, column: parsed.column, mode: mode)
    }

    /// Stages `position` as the revealed position and fires a gotoLine event.
    /// A no-op after `dispose()`.
    public func reveal(position: MonaPosition) {
        guard !isDisposed else { return }
        _lock.lock()
        _revealedPosition = position
        _lock.unlock()
        fire(.init(revealedPosition: position))
    }

    /// Reveals `position` through the shared transaction gateway: begins a
    /// transaction, prepares a collapsed selection at `position`, and commits
    /// the unit. Returns the committed selections (empty when the feature is
    /// disposed or the commit dropped).
    @discardableResult
    public func commitReveal(
        gateway: MonaTransactionGateway,
        position: MonaPosition
    ) -> [MonaSelection] {
        guard !isDisposed else { return [] }
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
    public func publishGotoLineEvent(
        _ event: MonaGotoLineEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaGotoLineEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the staged reveal is cleared, and
    /// `reveal` / `commitReveal` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _revealedPosition = nil
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

    /// The plain-text fallback language. gotoLine needs no tokenization; it
    /// degrades to plain text for any tokenization need.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — gotoLine performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a gotoLine event when not disposed.
    private func fire(_ event: MonaGotoLineEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
