// MonaCommentFeature.swift
//
// P05-T109 — Implement retained feature comment.
//
// `MonaCommentFeature` is the Swift counterpart of Monaco's `comment`
// contribution (monaco-editor 0.56.0): it executes line and block comment
// commands from explicit language configuration only. A line comment toggles
// `// ` (the configured line-comment token + one space) at the start of each
// selected line; a block comment wraps / unwraps the selection in the
// configured block-comment open / close tokens. The edits are applied
// transactionally through `MonaTransactionGateway`.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `toggleLineComment`, `addLineComment`,
//      `removeLineComment`, and `toggleBlockComment`, all driven by an explicit
//      `MonaCommentConfiguration` (line-comment token, block-comment open / close
//      tokens) and committed through `MonaTransactionGateway`.
//   2. Register the exact feature identity `comment` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// The explicit language configuration for comments: a line-comment token and a
/// block-comment open / close pair. Comment commands read these tokens verbatim
/// — the feature performs no tokenization-dependent work and so degrades to the
/// plain-text fallback for its tokenization needs.
public struct MonaCommentConfiguration: Equatable {

    /// The line-comment token (e.g. `"//"`), or `nil` when the language has no
    /// line-comment syntax.
    public let lineComment: String?

    /// The block-comment opening token (e.g. `"/*"`).
    public let blockCommentOpen: String?

    /// The block-comment closing token (e.g. `"*/"`).
    public let blockCommentClose: String?

    public init(
        lineComment: String?,
        blockCommentOpen: String?,
        blockCommentClose: String?
    ) {
        self.lineComment = lineComment
        self.blockCommentOpen = blockCommentOpen
        self.blockCommentClose = blockCommentClose
    }
}

/// A comment action kind: which line / block comment command fired.
public enum MonaCommentAction: String, Equatable {

    /// `editor.action.commentLine` — toggle line comments on selected lines.
    case toggleLineComment

    /// `editor.action.addCommentLine` — add line comments to selected lines.
    case addLineComment

    /// `editor.action.removeCommentLine` — remove line comments from selected lines.
    case removeLineComment

    /// `editor.action.blockComment` — toggle block comment around the selection.
    case toggleBlockComment
}

/// A comment event: the action that fired and the affected line numbers.
public struct MonaCommentEvent: Equatable {

    /// The action that fired.
    public let action: MonaCommentAction

    /// The 1-based line numbers affected by the command (empty for block
    /// comments that wrap a single-line selection).
    public let lines: [Int]

    public init(action: MonaCommentAction, lines: [Int] = []) {
        self.action = action
        self.lines = lines
    }
}

/// The comment feature: execute line and block comment commands from explicit
/// language configuration only.
///
/// The feature identity `comment` and its declared slice are referenced
/// verbatim from the frozen registries. Line-comment edits are computed against
/// the original line positions and applied as one transactional batch through
/// `MonaTransactionGateway` (the model applies the batch in descending
/// start-offset order so earlier offsets remain valid). Block-comment wrap /
/// unwrap is two edits (open at the start, close at the end). Asynchronous
/// publication is routed through `MonaProviderExecutor` + `MonaMicrotaskQueue`;
/// disposal through `MonaEmitter`; localization through `MonaLocalization`; and
/// degraded plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaCommentFeature: MonaDisposable {

    /// The frozen feature identity (`"comment"`).
    public static let featureId = "comment"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These are
    /// the labeled editor actions registered by the comment feature: the four
    /// line / block comment commands.
    public static let declaredActionIds: [String] = [
        "editor.action.commentLine",
        "editor.action.addCommentLine",
        "editor.action.removeCommentLine",
        "editor.action.blockComment"
    ]

    /// The declared command IDs in source order. The comment command set is the
    /// four line / block comment actions (each action registers as its own
    /// command).
    public static let declaredCommandIds: [String] = [
        "editor.action.commentLine",
        "editor.action.addCommentLine",
        "editor.action.removeCommentLine",
        "editor.action.blockComment"
    ]

    /// The declared contribution IDs. comment declares no contributions in the
    /// F1-R3 scope manifest (the comment commands are registered as actions, not
    /// as a contribution), so this slice is empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the comment commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`, in source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.commentLine",
        "editor.action.addCommentLine",
        "editor.action.removeCommentLine",
        "editor.action.blockComment"
    ]

    /// The declared option names — the `comments` option
    /// (`editor.comments.{ignoreEmptyLines, insertSpace}`) that governs comment
    /// command behavior.
    public static let declaredOptionIds: [String] = [
        "comments"
    ]

    /// The declared menu IDs — the menus that carry comment menu items. The
    /// `MenubarEditMenu` carries the Toggle Line Comment and Toggle Block
    /// Comment items.
    public static let declaredMenuIds: [String] = [
        "MenubarEditMenu"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaCommentEvent>()

    /// The event stream for comment changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaCommentEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the comment feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: line / block comment from explicit config

    /// The token + single trailing space inserted at the start of a line when
    /// line-commenting (e.g. `"// "`).
    private func lineCommentInsertToken(_ configuration: MonaCommentConfiguration) -> String? {
        guard let token = configuration.lineComment, !token.isEmpty else { return nil }
        return token + " "
    }

    /// The 1-based line numbers spanned by `range` (inclusive).
    private func lines(in range: MonaRange, model: MonaCodeModel) -> [Int] {
        let start = max(1, range.startPosition.line)
        let end = min(model.getLineCount(), max(start, range.endPosition.line))
        guard end >= start else { return [] }
        return Array(start...end)
    }

    /// `true` when `line` (after leading whitespace) begins with the line-comment
    /// insert token.
    private func lineHasComment(_ line: String, insertToken: String) -> Bool {
        return line.hasPrefix(insertToken) || line.trimmingCharacters(in: .whitespaces).hasPrefix(insertToken)
    }

    /// Computes the edit operations to toggle line comments on `range` using
    /// `configuration`. If all non-empty lines already carry the comment token,
    /// the edits remove it; otherwise the edits add it.
    private func toggleLineCommentEdits(
        range: MonaRange,
        configuration: MonaCommentConfiguration,
        model: MonaCodeModel
    ) -> [MonaModelEditOperation] {
        guard let insertToken = lineCommentInsertToken(configuration) else { return [] }
        let lineNumbers = lines(in: range, model: model)
        guard !lineNumbers.isEmpty else { return [] }

        let allCommented = lineNumbers.allSatisfy { lineNumber in
            let content = model.getLineContent(lineNumber)
            return content.trimmingCharacters(in: .whitespaces).isEmpty
                || lineHasComment(content, insertToken: insertToken)
        }

        var ops: [MonaModelEditOperation] = []
        for lineNumber in lineNumbers {
            let content = model.getLineContent(lineNumber)
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                continue // ignoreEmptyLines: skip blank lines
            }
            if allCommented {
                // Remove the insert token (token + one space) from the start of
                // the line content (after any leading whitespace).
                let trimmed = content.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(insertToken) {
                    // Find the absolute column of the token in the original line.
                    let leadingCount = content.countingLeadingWhitespace
                    let tokenStartColumn = leadingCount + 1
                    let tokenEndColumn = tokenStartColumn + insertToken.count
                    ops.append(MonaModelEditOperation(
                        range: MonaRange(
                            startPosition: MonaPosition(line: lineNumber, column: tokenStartColumn),
                            endPosition: MonaPosition(line: lineNumber, column: tokenEndColumn)
                        ),
                        text: ""
                    ))
                }
            } else {
                if !lineHasComment(content, insertToken: insertToken) {
                    ops.append(MonaModelEditOperation(
                        range: MonaRange(
                            startPosition: MonaPosition(line: lineNumber, column: 1),
                            endPosition: MonaPosition(line: lineNumber, column: 1)
                        ),
                        text: insertToken
                    ))
                }
            }
        }
        return ops
    }

    /// Toggles line comments on the lines spanned by `range`, using the explicit
    /// `configuration`. The edits are committed transactionally through `gateway`
    /// as one ordered unit. Fires an event with the affected lines. Returns the
    /// reconciliation outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func toggleLineComment(
        range: MonaRange,
        configuration: MonaCommentConfiguration,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let ops = toggleLineCommentEdits(range: range, configuration: configuration, model: model)
        let outcome = commit(ops, gateway: gateway)
        let affected = lines(in: range, model: model)
        fire(.init(action: .toggleLineComment, lines: affected))
        return outcome
    }

    /// Adds line comments to every line spanned by `range`, using the explicit
    /// `configuration`. Lines that already carry the token are left untouched.
    /// Fires an event with the affected lines. A no-op after `dispose()`.
    @discardableResult
    public func addLineComment(
        range: MonaRange,
        configuration: MonaCommentConfiguration,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        guard let insertToken = lineCommentInsertToken(configuration) else {
            return .dropped(reason: "no line comment token")
        }
        let model = gateway.model
        let lineNumbers = lines(in: range, model: model)
        var ops: [MonaModelEditOperation] = []
        for lineNumber in lineNumbers {
            let content = model.getLineContent(lineNumber)
            if content.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if !lineHasComment(content, insertToken: insertToken) {
                ops.append(MonaModelEditOperation(
                    range: MonaRange(
                        startPosition: MonaPosition(line: lineNumber, column: 1),
                        endPosition: MonaPosition(line: lineNumber, column: 1)
                    ),
                    text: insertToken
                ))
            }
        }
        let outcome = commit(ops, gateway: gateway)
        fire(.init(action: .addLineComment, lines: lineNumbers))
        return outcome
    }

    /// Removes line comments from every line spanned by `range`, using the
    /// explicit `configuration`. Lines without the token are left untouched.
    /// Fires an event with the affected lines. A no-op after `dispose()`.
    @discardableResult
    public func removeLineComment(
        range: MonaRange,
        configuration: MonaCommentConfiguration,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        guard let insertToken = lineCommentInsertToken(configuration) else {
            return .dropped(reason: "no line comment token")
        }
        let model = gateway.model
        let lineNumbers = lines(in: range, model: model)
        var ops: [MonaModelEditOperation] = []
        for lineNumber in lineNumbers {
            let content = model.getLineContent(lineNumber)
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(insertToken) {
                let leadingCount = content.countingLeadingWhitespace
                let tokenStartColumn = leadingCount + 1
                let tokenEndColumn = tokenStartColumn + insertToken.count
                ops.append(MonaModelEditOperation(
                    range: MonaRange(
                        startPosition: MonaPosition(line: lineNumber, column: tokenStartColumn),
                        endPosition: MonaPosition(line: lineNumber, column: tokenEndColumn)
                    ),
                    text: ""
                ))
            }
        }
        let outcome = commit(ops, gateway: gateway)
        fire(.init(action: .removeLineComment, lines: lineNumbers))
        return outcome
    }

    /// Toggles the block comment around `range`, using the explicit
    /// `configuration`. If the range text is already wrapped in the block-comment
    /// open / close tokens, they are removed; otherwise the tokens are inserted
    /// at the range boundaries. Fires an event. A no-op after `dispose()`.
    @discardableResult
    public func toggleBlockComment(
        range: MonaRange,
        configuration: MonaCommentConfiguration,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        guard let open = configuration.blockCommentOpen,
              let close = configuration.blockCommentClose,
              !open.isEmpty, !close.isEmpty else {
            return .dropped(reason: "no block comment tokens")
        }
        let model = gateway.model
        let selected = model.getValueInRange(range)
        var ops: [MonaModelEditOperation] = []
        if selected.hasPrefix(open) && selected.hasSuffix(close) && selected.count >= (open.count + close.count) {
            // Unwrap: remove the open token at the start and the close token at
            // the end of the selection.
            let openEndColumn = range.startPosition.column + open.count
            let closeStartColumn = range.endPosition.column - close.count
            ops.append(MonaModelEditOperation(
                range: MonaRange(
                    startPosition: MonaPosition(line: range.startPosition.line, column: range.startPosition.column),
                    endPosition: MonaPosition(line: range.startPosition.line, column: openEndColumn)
                ),
                text: ""
            ))
            ops.append(MonaModelEditOperation(
                range: MonaRange(
                    startPosition: MonaPosition(line: range.endPosition.line, column: closeStartColumn),
                    endPosition: MonaPosition(line: range.endPosition.line, column: range.endPosition.column)
                ),
                text: ""
            ))
        } else {
            // Wrap: insert the open token at the start and the close token at the
            // end of the selection.
            ops.append(MonaModelEditOperation(
                range: MonaRange(
                    startPosition: range.startPosition,
                    endPosition: range.startPosition
                ),
                text: open
            ))
            ops.append(MonaModelEditOperation(
                range: MonaRange(
                    startPosition: range.endPosition,
                    endPosition: range.endPosition
                ),
                text: close
            ))
        }
        let outcome = commit(ops, gateway: gateway)
        fire(.init(action: .toggleBlockComment, lines: []))
        return outcome
    }

    /// Commits `ops` as one transactional batch through `gateway`. An empty batch
    /// still commits (a no-op transaction applies cleanly).
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
    public func publishCommentEvent(
        _ event: MonaCommentEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaCommentEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `toggleLineComment` /
    /// `addLineComment` / `removeLineComment` / `toggleBlockComment` are
    /// no-ops (return `.dropped`).
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

    /// The plain-text fallback language. comment needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — comment performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a comment event when not disposed.
    private func fire(_ event: MonaCommentEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}

// MARK: - String leading-whitespace helper

private extension String {
    /// The number of leading whitespace characters.
    var countingLeadingWhitespace: Int {
        var count = 0
        for ch in self {
            if ch.isWhitespace { count += 1 } else { break }
        }
        return count
    }
}
