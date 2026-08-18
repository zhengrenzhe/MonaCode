// MonaLinesOperationsFeature.swift
//
// P05-T134 — Implement retained feature linesOperations.
//
// `MonaLinesOperationsFeature` is the Swift counterpart of Monaco's
// `linesOperations` contribution (monaco-editor 0.56.0): it performs the eight
// line-level editor operations — move, copy, delete, join, sort, trim,
// transpose, and duplicate — each committed transactionally through
// `MonaTransactionGateway`.
//
//   - move:   `moveLinesUp` / `moveLinesDown` swap a line with its neighbor.
//   - copy:   `copyLinesUp` / `copyLinesDown` insert a copy adjacent to the line.
//   - delete: `deleteLines` removes a line and its terminator.
//   - join:   `joinLines` merges a line with the next, trimming the gap.
//   - sort:   `sortLinesAscending` / `sortLinesDescending` reorder a range.
//   - trim:   `trimTrailingWhitespace` strips trailing whitespace per line.
//   - transpose: `transposeCharacters` swaps the two characters before the cursor.
//   - duplicate: `duplicateSelection` duplicates the selection (or the whole line
//     when the selection is collapsed).
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — the eight operations above, all committed
//      through `MonaTransactionGateway`.
//   2. Register the exact feature identity `linesOperations` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A lines-operations kind: which of the eight operations fired.
public enum MonaLinesOperation: String, Equatable {

    /// Move a line up or down (`editor.action.moveLinesUpAction` /
    /// `editor.action.moveLinesDownAction`).
    case move

    /// Copy a line up or down (`editor.action.copyLinesUpAction` /
    /// `editor.action.copyLinesDownAction`).
    case copy

    /// Delete a line (`editor.action.deleteLines`).
    case delete

    /// Join lines (`editor.action.joinLines`).
    case join

    /// Sort lines ascending or descending (`editor.action.sortLinesAscending` /
    /// `editor.action.sortLinesDescending`).
    case sort

    /// Trim trailing whitespace (`editor.action.trimTrailingWhitespace`).
    case trim

    /// Transpose characters (`editor.action.transpose` /
    /// `editor.action.transposeLetters`).
    case transpose

    /// Duplicate the selection (`editor.action.duplicateSelection`).
    case duplicate
}

/// A lines-operations event: the operation that fired and the affected range.
public struct MonaLinesOperationsEvent: Equatable {

    /// The operation that fired.
    public let operation: MonaLinesOperation

    /// The range the operation affected (in pre-edit coordinates).
    public let range: MonaRange

    public init(operation: MonaLinesOperation, range: MonaRange) {
        self.operation = operation
        self.range = range
    }
}

/// The lines-operations feature: move, copy, delete, join, sort, trim,
/// transpose, and duplicate lines transactionally.
///
/// The feature identity `linesOperations` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaLinesOperationsFeature: MonaDisposable {

    /// The frozen feature identity (`"linesOperations"`).
    public static let featureId = "linesOperations"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// twelve lines-operations actions: transpose letters (ordinal 9), then the
    /// copy/duplicate/move/sort/trim/delete/join/transpose actions (ordinals
    /// 72–89) that implement the eight operations.
    public static let declaredActionIds: [String] = [
        "editor.action.transposeLetters",
        "editor.action.copyLinesUpAction",
        "editor.action.copyLinesDownAction",
        "editor.action.duplicateSelection",
        "editor.action.moveLinesUpAction",
        "editor.action.moveLinesDownAction",
        "editor.action.sortLinesAscending",
        "editor.action.sortLinesDescending",
        "editor.action.trimTrailingWhitespace",
        "editor.action.deleteLines",
        "editor.action.joinLines",
        "editor.action.transpose"
    ]

    /// The declared command IDs in source order. The twelve lines-operations
    /// actions are also registered as editor commands, so this slice equals
    /// `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution IDs. `linesOperations` registers no
    /// contribution descriptor in the F1-R3 scope manifest, so this slice is
    /// empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the eight lines-operations actions
    /// that carry a default keybinding in `MonaBuiltinKeybindings`, in keybinding
    /// ordinal order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.copyLinesDownAction",
        "editor.action.copyLinesUpAction",
        "editor.action.deleteLines",
        "editor.action.joinLines",
        "editor.action.moveLinesDownAction",
        "editor.action.moveLinesUpAction",
        "editor.action.transposeLetters",
        "editor.action.trimTrailingWhitespace"
    ]

    /// The declared option names — linesOperations declares no options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — the `MenubarSelectionMenu` carries the
    /// copy/move/duplicate line menu items.
    public static let declaredMenuIds: [String] = [
        "MenubarSelectionMenu"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaLinesOperationsEvent>()

    /// The event stream for lines-operations changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaLinesOperationsEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the lines-operations feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: 8 operations via MonaTransactionGateway

    /// Moves line `line` up by one (swaps it with its predecessor). Returns
    /// `.dropped` when `line` is the first line, out of range, or after
    /// `dispose()`. Fires a `.move` event on success.
    @discardableResult
    public func moveLinesUp(
        line: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        guard line >= 2, line <= model.getLineCount() else {
            return .dropped(reason: "out of range")
        }
        let prev = model.getLineContent(line - 1)
        let curr = model.getLineContent(line)
        // Replace the two lines' content (prev + newline + curr) with (curr +
        // newline + prev), leaving the terminator after `line` untouched.
        let range = wholeLineContentRange(from: line - 1, to: line, in: model)
        let replacement = curr + "\n" + prev
        return commitSingle(
            range: range,
            text: replacement,
            operation: .move,
            gateway: gateway
        )
    }

    /// Moves line `line` down by one (swaps it with its successor). Returns
    /// `.dropped` when `line` is the last line, out of range, or after
    /// `dispose()`. Fires a `.move` event on success.
    @discardableResult
    public func moveLinesDown(
        line: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let count = model.getLineCount()
        guard line >= 1, line < count else {
            return .dropped(reason: "out of range")
        }
        let curr = model.getLineContent(line)
        let next = model.getLineContent(line + 1)
        let range = wholeLineContentRange(from: line, to: line + 1, in: model)
        let replacement = next + "\n" + curr
        return commitSingle(
            range: range,
            text: replacement,
            operation: .move,
            gateway: gateway
        )
    }

    /// Copies line `line` above itself (inserts a duplicate above). Returns
    /// `.dropped` when out of range or after `dispose()`. Fires a `.copy` event
    /// on success.
    @discardableResult
    public func copyLinesUp(
        line: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        guard line >= 1, line <= model.getLineCount() else {
            return .dropped(reason: "out of range")
        }
        let content = model.getLineContent(line)
        // Insert (content + newline) before line's content.
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: 1),
            endPosition: MonaPosition(line: line, column: 1)
        )
        return commitSingle(
            range: range,
            text: content + "\n",
            operation: .copy,
            gateway: gateway
        )
    }

    /// Copies line `line` below itself (inserts a duplicate below). Returns
    /// `.dropped` when out of range or after `dispose()`. Fires a `.copy` event
    /// on success.
    @discardableResult
    public func copyLinesDown(
        line: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        guard line >= 1, line <= model.getLineCount() else {
            return .dropped(reason: "out of range")
        }
        let content = model.getLineContent(line)
        // Insert (newline + content) at the end of the line's content.
        let endColumn = model.getLineMaxColumn(line)
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: endColumn),
            endPosition: MonaPosition(line: line, column: endColumn)
        )
        return commitSingle(
            range: range,
            text: "\n" + content,
            operation: .copy,
            gateway: gateway
        )
    }

    /// Deletes line `line` and its terminator. Returns `.dropped` when out of
    /// range or after `dispose()`. Fires a `.delete` event on success.
    @discardableResult
    public func deleteLines(
        line: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let count = model.getLineCount()
        guard line >= 1, line <= count else {
            return .dropped(reason: "out of range")
        }
        let range: MonaRange
        if line == count {
            if line == 1 {
                // Single-line document: clear its content.
                range = MonaRange(
                    startPosition: MonaPosition(line: 1, column: 1),
                    endPosition: MonaPosition(line: 1, column: model.getLineMaxColumn(1))
                )
            } else {
                // Final line: delete the preceding terminator + the line's
                // content.
                range = MonaRange(
                    startPosition: MonaPosition(line: line - 1, column: model.getLineMaxColumn(line - 1)),
                    endPosition: MonaPosition(line: line, column: model.getLineMaxColumn(line))
                )
            }
        } else {
            // Non-final line: delete the line's content + its terminator.
            range = MonaRange(
                startPosition: MonaPosition(line: line, column: 1),
                endPosition: MonaPosition(line: line + 1, column: 1)
            )
        }
        return commitSingle(
            range: range,
            text: "",
            operation: .delete,
            gateway: gateway
        )
    }

    /// Joins line `line` with the next line, trimming the gap between them to a
    /// single space when both sides carry non-whitespace content. Returns
    /// `.dropped` when `line` is the last line, out of range, or after
    /// `dispose()`. Fires a `.join` event on success.
    @discardableResult
    public func joinLines(
        line: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let count = model.getLineCount()
        guard line >= 1, line < count else {
            return .dropped(reason: "out of range")
        }
        let lineN = model.getLineContent(line)
        let trimmedEnd = Self.rstrip(lineN)
        let endColumn = trimmedEnd.count + 1
        let lineNext = model.getLineContent(line + 1)
        let firstNonWsNext = model.getLineFirstNonWhitespaceColumn(line + 1)
        let nextStartCol: Int
        let trimmedStart: String
        if firstNonWsNext > 0 {
            nextStartCol = firstNonWsNext
            trimmedStart = String(lineNext.dropFirst(firstNonWsNext - 1))
        } else {
            // Next line is empty or all whitespace: consume it entirely.
            nextStartCol = lineNext.count + 1
            trimmedStart = ""
        }
        let gap = (trimmedEnd.isEmpty || trimmedStart.isEmpty) ? "" : " "
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: endColumn),
            endPosition: MonaPosition(line: line + 1, column: nextStartCol)
        )
        return commitSingle(
            range: range,
            text: gap,
            operation: .join,
            gateway: gateway
        )
    }

    /// Sorts the lines in `[from, to]` ascending. Returns `.dropped` when the
    /// range is invalid, has fewer than two lines, or after `dispose()`. Fires a
    /// `.sort` event on success.
    @discardableResult
    public func sortLinesAscending(
        from: Int,
        to: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        return sortLines(from: from, to: to, ascending: true, gateway: gateway)
    }

    /// Sorts the lines in `[from, to]` descending. Returns `.dropped` when the
    /// range is invalid, has fewer than two lines, or after `dispose()`. Fires a
    /// `.sort` event on success.
    @discardableResult
    public func sortLinesDescending(
        from: Int,
        to: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        return sortLines(from: from, to: to, ascending: false, gateway: gateway)
    }

    /// Trims trailing whitespace on every line in `[from, to]`. Returns `.dropped`
    /// when the range is invalid or after `dispose()`. Fires a `.trim` event on
    /// success (even when no line had trailing whitespace, the transaction still
    /// applies cleanly).
    @discardableResult
    public func trimTrailingWhitespace(
        from: Int,
        to: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let count = model.getLineCount()
        guard from >= 1, to <= count, from <= to else {
            return .dropped(reason: "out of range")
        }
        var ops: [MonaModelEditOperation] = []
        for line in from...to {
            let maxColumn = model.getLineMaxColumn(line)
            let lastNonWs = model.getLineLastNonWhitespaceColumn(line)
            if lastNonWs == 0 {
                // All whitespace or empty: clear the whole line if it has content.
                if maxColumn > 1 {
                    ops.append(MonaModelEditOperation(
                        range: MonaRange(
                            startPosition: MonaPosition(line: line, column: 1),
                            endPosition: MonaPosition(line: line, column: maxColumn)
                        ),
                        text: ""
                    ))
                }
            } else if lastNonWs < maxColumn {
                // Trailing whitespace after the last non-whitespace column.
                ops.append(MonaModelEditOperation(
                    range: MonaRange(
                        startPosition: MonaPosition(line: line, column: lastNonWs),
                        endPosition: MonaPosition(line: line, column: maxColumn)
                    ),
                    text: ""
                ))
            }
        }
        return commit(
            ops: ops,
            operation: .trim,
            affectedRange: MonaRange(
                startPosition: MonaPosition(line: from, column: 1),
                endPosition: MonaPosition(line: to, column: 1)
            ),
            gateway: gateway
        )
    }

    /// Transposes the two characters immediately before `position` (swaps them).
    /// Returns `.dropped` when fewer than two characters precede the position,
    /// when the position is out of range, or after `dispose()`. Fires a
    /// `.transpose` event on success.
    @discardableResult
    public func transposeCharacters(
        at position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let line = position.line
        guard line >= 1, line <= model.getLineCount() else {
            return .dropped(reason: "out of range")
        }
        let content = model.getLineContent(line)
        let chars = Array(content)
        let i = position.column - 1 // 0-based count of characters before cursor
        guard i >= 2, i <= chars.count else {
            return .dropped(reason: "out of range")
        }
        // Swap the two characters at 0-based indices i-2 and i-1 (1-based
        // columns i-1 and i).
        let swapped = String(chars[i - 1]) + String(chars[i - 2])
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: i - 1),
            endPosition: MonaPosition(line: line, column: i + 1)
        )
        return commitSingle(
            range: range,
            text: swapped,
            operation: .transpose,
            gateway: gateway
        )
    }

    /// Duplicates the selection `range`. When the range is collapsed, duplicates
    /// the whole line containing the position (copy-line-down behavior).
    /// Returns `.dropped` when out of range or after `dispose()`. Fires a
    /// `.duplicate` event on success.
    @discardableResult
    public func duplicateSelection(
        range: MonaRange,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        if range.isFolded {
            // Collapsed selection: duplicate the whole line.
            let line = range.startPosition.line
            guard line >= 1, line <= model.getLineCount() else {
                return .dropped(reason: "out of range")
            }
            let content = model.getLineContent(line)
            let endColumn = model.getLineMaxColumn(line)
            let insertRange = MonaRange(
                startPosition: MonaPosition(line: line, column: endColumn),
                endPosition: MonaPosition(line: line, column: endColumn)
            )
            return commitSingle(
                range: insertRange,
                text: "\n" + content,
                operation: .duplicate,
                gateway: gateway
            )
        }
        // Non-empty selection: duplicate the selected text right after the
        // selection end.
        let selected = model.getValueInRange(range)
        let end = range.endPosition
        let insertRange = MonaRange(startPosition: end, endPosition: end)
        return commitSingle(
            range: insertRange,
            text: selected,
            operation: .duplicate,
            gateway: gateway
        )
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishLinesOperationsEvent(
        _ event: MonaLinesOperationsEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaLinesOperationsEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and every operation is a no-op (returns
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
    /// `MonaLocalization` surface under `profile`.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. linesOperations performs no
    /// tokenization-dependent work and degrades gracefully to the plain-text
    /// fallback.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — linesOperations performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Sorts the lines in `[from, to]` in the requested order.
    private func sortLines(
        from: Int,
        to: Int,
        ascending: Bool,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let count = model.getLineCount()
        guard from >= 1, to <= count, from < to else {
            return .dropped(reason: "out of range")
        }
        var lines: [String] = []
        for line in from...to {
            lines.append(model.getLineContent(line))
        }
        lines.sort()
        if !ascending { lines.reverse() }
        let toIsFinal = (to == count)
        let replacement = lines.joined(separator: "\n") + (toIsFinal ? "" : "\n")
        let range = MonaRange(
            startPosition: MonaPosition(line: from, column: 1),
            endPosition: toIsFinal
                ? MonaPosition(line: to, column: model.getLineMaxColumn(to))
                : MonaPosition(line: to + 1, column: 1)
        )
        return commitSingle(
            range: range,
            text: replacement,
            operation: .sort,
            gateway: gateway
        )
    }

    /// Commits a single edit operation as one transaction. Fires `event` on a
    /// successful application.
    private func commitSingle(
        range: MonaRange,
        text: String,
        operation: MonaLinesOperation,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        let ops = [MonaModelEditOperation(range: range, text: text)]
        return commit(
            ops: ops,
            operation: operation,
            affectedRange: range,
            gateway: gateway
        )
    }

    /// Commits `ops` as one transactional batch through `gateway`. An empty
    /// batch still commits (a no-op transaction applies cleanly). Fires an event
    /// for `affectedRange` on a successful application.
    private func commit(
        ops: [MonaModelEditOperation],
        operation: MonaLinesOperation,
        affectedRange: MonaRange,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        let transaction = gateway.beginTransaction()
        if !ops.isEmpty {
            transaction.prepareEdits(ops)
        }
        let outcome = gateway.commit(transaction)
        if case .applied = outcome {
            fire(.init(operation: operation, range: affectedRange))
        }
        return outcome
    }

    /// Fires a lines-operations event when not disposed.
    private func fire(_ event: MonaLinesOperationsEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }

    /// Returns the range covering the content of `fromLine` through the content
    /// of `toLine` (the two lines plus the newline between, excluding the
    /// terminator after `toLine`).
    private func wholeLineContentRange(from: Int, to: Int, in model: MonaCodeModel) -> MonaRange {
        return MonaRange(
            startPosition: MonaPosition(line: from, column: 1),
            endPosition: MonaPosition(line: to, column: model.getLineMaxColumn(to))
        )
    }

    /// Returns `text` with trailing whitespace removed.
    private static func rstrip(_ text: String) -> String {
        var end = text.endIndex
        while end > text.startIndex {
            let prev = text.index(before: end)
            if text[prev].isWhitespace {
                end = prev
            } else {
                break
            }
        }
        return String(text[text.startIndex..<end])
    }
}
