// MonaWordOperationsFeature.swift
//
// P05-T160 — Implement retained feature wordOperations.
//
// `MonaWordOperationsFeature` is the Swift counterpart of Monaco's
// `wordOperations` surface (monaco-editor 0.56.0): it moves, deletes, and
// transposes by the frozen word boundary profile — the three-way
// `MonaWordClassifier` (P02-T003) over raw UTF-16 code units, which classifies
// each code unit as a word character (`.other`), a configured word separator
// (`.wordSeparator`), or whitespace (`.whitespace`).
//
// A "word" for navigation is a maximal run of code units of the same
// `MonaWordClass`. Move stops at the start of each run; delete removes the run
// to the left / right of the cursor (skipping trailing whitespace on the
// delete side so that `deleteWordLeft` eats a trailing whitespace run and the
// preceding word run together, matching Monaco's Ctrl+Backspace behavior);
// `deleteInsideWord` removes the word run containing the cursor (or the next
// word run to the right when the cursor sits on whitespace); and
// `transposeWord` swaps the two word runs adjacent to the cursor, preserving
// the gap between them.
//
//   - move:   `moveWordLeft` / `moveWordRight` (cursorWordLeft /
//     cursorWordStartLeft, cursorWordRight / cursorWordStartRight) move to the
//     start of the previous / next word run. `moveWordLeftSelect` /
//     `moveWordRightSelect` (cursorWordLeftSelect / cursorWordRightSelect)
//     extend the selection to that start.
//   - delete: `deleteWordLeft` / `deleteWordRight` (deleteWordLeft /
//     deleteWordRight) delete the word run to the left / right.
//     `deleteInsideWord` (deleteInsideWord) deletes the containing word run.
//   - transform: `transposeWord` swaps the word at the cursor with the
//     preceding word.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — the move / delete / transform operations
//      above, with deletes and transposes committed through
//      `MonaTransactionGateway`.
//   2. Register the exact feature identity `wordOperations` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A word-operations kind: which of the move / delete / transform operations
/// fired.
public enum MonaWordOperation: String, Equatable {

    /// A move operation (`cursorWordLeft` / `cursorWordRight` and their select
    /// variants). Move does not mutate the model.
    case move

    /// A delete operation (`deleteWordLeft` / `deleteWordRight` /
    /// `deleteInsideWord`).
    case delete

    /// A delete-inside-word operation (`deleteInsideWord`).
    case deleteInside

    /// A transform operation (`transposeWord`).
    case transpose
}

/// A word-operations event: the operation that fired and the affected range.
public struct MonaWordOperationsEvent: Equatable {

    /// The operation that fired.
    public let operation: MonaWordOperation

    /// The range the operation affected (in pre-edit coordinates; for moves,
    /// the range from the source position to the destination).
    public let range: MonaRange

    public init(operation: MonaWordOperation, range: MonaRange) {
        self.operation = operation
        self.range = range
    }
}

/// The wordOperations feature: move, delete, and transform by the frozen word
/// boundary profile, transactionally.
///
/// The feature identity `wordOperations` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaWordOperationsFeature: MonaDisposable {

    /// The frozen feature identity (`"wordOperations"`).
    public static let featureId = "wordOperations"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single word-operations action — `deleteInsideWord` (ordinal 160).
    public static let declaredActionIds: [String] = [
        "deleteInsideWord"
    ]

    /// The declared command IDs in source order. The twenty word cursor / delete
    /// commands (non-part, non-accessibility, excluding `inlineSuggest` and
    /// `toggleFind`), referenced verbatim from the command registry.
    public static let declaredCommandIds: [String] = [
        "cursorWordEndLeft",
        "cursorWordEndLeftSelect",
        "cursorWordEndRight",
        "cursorWordEndRightSelect",
        "cursorWordLeft",
        "cursorWordLeftSelect",
        "cursorWordRight",
        "cursorWordRightSelect",
        "cursorWordStartLeft",
        "cursorWordStartLeftSelect",
        "cursorWordStartRight",
        "cursorWordStartRightSelect",
        "deleteInsideWord",
        "deleteWordEndLeft",
        "deleteWordEndRight",
        "deleteWordLeft",
        "deleteWordRight",
        "deleteWordStartLeft",
        "deleteWordStartRight",
        "lastCursorWordSelect"
    ]

    /// The declared contribution IDs. `wordOperations` registers no
    /// contribution descriptor in the F1-R3 scope manifest, so this slice is
    /// empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the word-operations commands that
    /// carry a default keybinding in `MonaBuiltinKeybindings`, in keybinding
    /// ordinal order.
    public static let declaredKeybindingCommands: [String] = [
        "cursorWordEndRight",
        "cursorWordEndRightSelect",
        "cursorWordLeft",
        "cursorWordLeftSelect",
        "deleteWordLeft",
        "deleteWordRight"
    ]

    /// The declared option names — wordOperations declares no options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — wordOperations registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaWordOperationsEvent>()

    /// The event stream for word-operations changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaWordOperationsEvent> { emitter.event }

    private let classifier = MonaWordClassifier()
    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the word-operations feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: move / delete / transform

    /// Moves to the start of the previous word run (`cursorWordLeft` /
    /// `cursorWordStartLeft`). Returns the destination position (or the
    /// position at the start of the previous line when already at column 1, or
    /// the same position when at the very start of the document).
    public func moveWordLeft(
        from position: MonaPosition,
        model: MonaCodeModel
    ) -> MonaPosition {
        guard !isDisposed else { return position }
        let validated = model.validatePosition(position)
        let line = validated.line
        if validated.column == 1 {
            // At start of line: move to end of previous line (or stay).
            guard line > 1 else { return validated }
            return MonaPosition(line: line - 1, column: model.getLineMaxColumn(line - 1))
        }
        let codeUnits = Array(model.getLineContent(line).utf16)
        let pos = validated.column - 1 // 0-based count of units before cursor
        let dest = runStartLeft(codeUnits: codeUnits, pos: pos)
        return MonaPosition(line: line, column: dest + 1)
    }

    /// Moves to the start of the next word run (`cursorWordRight` /
    /// `cursorWordStartRight`). Returns the destination position (or the
    /// position at the start of the next line when already at the line end, or
    /// the same position when at the very end of the document).
    public func moveWordRight(
        from position: MonaPosition,
        model: MonaCodeModel
    ) -> MonaPosition {
        guard !isDisposed else { return position }
        let validated = model.validatePosition(position)
        let line = validated.line
        let maxColumn = model.getLineMaxColumn(line)
        if validated.column == maxColumn {
            // At end of line: move to start of next line (or stay).
            guard line < model.getLineCount() else { return validated }
            return MonaPosition(line: line + 1, column: 1)
        }
        let codeUnits = Array(model.getLineContent(line).utf16)
        let pos = validated.column - 1
        let dest = runStartRight(codeUnits: codeUnits, pos: pos)
        return MonaPosition(line: line, column: dest + 1)
    }

    /// Extends the selection to the start of the previous word run
    /// (`cursorWordLeftSelect`). Returns the range from the destination
    /// position to the source position.
    public func moveWordLeftSelect(
        from position: MonaPosition,
        model: MonaCodeModel
    ) -> MonaRange {
        guard !isDisposed else {
            return MonaRange(startPosition: position, endPosition: position)
        }
        let dest = moveWordLeft(from: position, model: model)
        return MonaRange(startPosition: dest, endPosition: position)
    }

    /// Extends the selection to the start of the next word run
    /// (`cursorWordRightSelect`). Returns the range from the source position to
    /// the destination position.
    public func moveWordRightSelect(
        from position: MonaPosition,
        model: MonaCodeModel
    ) -> MonaRange {
        guard !isDisposed else {
            return MonaRange(startPosition: position, endPosition: position)
        }
        let dest = moveWordRight(from: position, model: model)
        return MonaRange(startPosition: position, endPosition: dest)
    }

    /// Deletes the word run to the left of the cursor (`deleteWordLeft`).
    /// Trailing whitespace immediately left of the cursor is skipped first and
    /// deleted together with the preceding word run (matching Monaco's
    /// Ctrl+Backspace). Returns `.dropped` when at column 1 of the first line
    /// or after `dispose()`. Fires a `.delete` event on success.
    @discardableResult
    public func deleteWordLeft(
        from position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let validated = model.validatePosition(position)
        let line = validated.line
        if validated.column == 1 {
            // At start of line: delete the line break (join with previous line).
            guard line > 1 else { return .dropped(reason: "at start of document") }
            let prevMax = model.getLineMaxColumn(line - 1)
            let range = MonaRange(
                startPosition: MonaPosition(line: line - 1, column: prevMax),
                endPosition: MonaPosition(line: line, column: 1)
            )
            return commitSingle(range: range, text: "", operation: .delete, gateway: gateway)
        }
        let codeUnits = Array(model.getLineContent(line).utf16)
        let pos = validated.column - 1
        let dest = runStartLeft(codeUnits: codeUnits, pos: pos)
        guard dest < pos else {
            return .dropped(reason: "no word to the left")
        }
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: dest + 1),
            endPosition: MonaPosition(line: line, column: validated.column)
        )
        return commitSingle(range: range, text: "", operation: .delete, gateway: gateway)
    }

    /// Deletes the word run to the right of the cursor (`deleteWordRight`).
    /// Leading whitespace immediately right of the cursor is skipped first and
    /// deleted together with the following word run. Returns `.dropped` when at
    /// the end of the last line or after `dispose()`. Fires a `.delete` event
    /// on success.
    @discardableResult
    public func deleteWordRight(
        from position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let validated = model.validatePosition(position)
        let line = validated.line
        let maxColumn = model.getLineMaxColumn(line)
        if validated.column == maxColumn {
            // At end of line: delete the line break (join with next line).
            guard line < model.getLineCount() else {
                return .dropped(reason: "at end of document")
            }
            let range = MonaRange(
                startPosition: MonaPosition(line: line, column: maxColumn),
                endPosition: MonaPosition(line: line + 1, column: 1)
            )
            return commitSingle(range: range, text: "", operation: .delete, gateway: gateway)
        }
        let codeUnits = Array(model.getLineContent(line).utf16)
        let pos = validated.column - 1
        let dest = runEndRight(codeUnits: codeUnits, pos: pos)
        guard dest > pos else {
            return .dropped(reason: "no word to the right")
        }
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: validated.column),
            endPosition: MonaPosition(line: line, column: dest + 1)
        )
        return commitSingle(range: range, text: "", operation: .delete, gateway: gateway)
    }

    /// Deletes the word run containing the cursor, or the next word run to the
    /// right when the cursor sits on whitespace (`deleteInsideWord`). Returns
    /// `.dropped` when no word run is available, or after `dispose()`. Fires a
    /// `.deleteInside` event on success.
    @discardableResult
    public func deleteInsideWord(
        at position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let validated = model.validatePosition(position)
        let line = validated.line
        let codeUnits = Array(model.getLineContent(line).utf16)
        let pos = validated.column - 1
        guard pos < codeUnits.count else {
            return .dropped(reason: "at end of line")
        }
        // If the cursor sits on a whitespace unit, advance to the next run.
        var p = pos
        if classifier.wordClass(codeUnits[p]) == .whitespace {
            while p < codeUnits.count && classifier.wordClass(codeUnits[p]) == .whitespace {
                p += 1
            }
            guard p < codeUnits.count else {
                return .dropped(reason: "no word to the right")
            }
        }
        // Find the run [start, end) containing p.
        var start = p
        while start > 0 && classifier.wordClass(codeUnits[start - 1]) == classifier.wordClass(codeUnits[p]) {
            start -= 1
        }
        var end = p + 1
        while end < codeUnits.count && classifier.wordClass(codeUnits[end]) == classifier.wordClass(codeUnits[p]) {
            end += 1
        }
        guard start < end else {
            return .dropped(reason: "no containing word")
        }
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: start + 1),
            endPosition: MonaPosition(line: line, column: end + 1)
        )
        return commitSingle(range: range, text: "", operation: .deleteInside, gateway: gateway)
    }

    /// Transposes the word at the cursor with the preceding word
    /// (`transposeWord`). The gap between the two words is preserved. Returns
    /// `.dropped` when fewer than two word runs precede the cursor, or after
    /// `dispose()`. Fires a `.transpose` event on success.
    @discardableResult
    public func transposeWord(
        at position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let validated = model.validatePosition(position)
        let line = validated.line
        let codeUnits = Array(model.getLineContent(line).utf16)
        let pos = validated.column - 1

        // Locate the second word run: the latest non-whitespace run ending at or
        // before `pos`.
        guard let second = lastWordRunEnding(atOrBefore: pos, in: codeUnits) else {
            return .dropped(reason: "no word at cursor")
        }
        // Locate the first word run: the latest non-whitespace run ending before
        // the gap that precedes `second`.
        guard let first = lastWordRunEnding(atOrBefore: second.start - 1, in: codeUnits) else {
            return .dropped(reason: "no preceding word")
        }
        // The transposed range is [first.start, second.end). Preserve the gap
        // (the whitespace between first.end and second.start) verbatim.
        let firstText = String(decoding: codeUnits[first.start..<first.end], as: UTF16.self)
        let secondText = String(decoding: codeUnits[second.start..<second.end], as: UTF16.self)
        let gap = String(decoding: codeUnits[first.end..<second.start], as: UTF16.self)
        let replacement = secondText + gap + firstText
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: first.start + 1),
            endPosition: MonaPosition(line: line, column: second.end + 1)
        )
        return commitSingle(range: range, text: replacement, operation: .transpose, gateway: gateway)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishWordOperationsEvent(
        _ event: MonaWordOperationsEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaWordOperationsEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and every operation is a no-op (moves
    /// return the source position; deletes / transposes return `.dropped`).
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

    /// The plain-text fallback language. wordOperations performs no
    /// tokenization-dependent work and degrades gracefully to the plain-text
    /// fallback.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — wordOperations performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private: word-run walk on the frozen three-way classifier

    /// Returns the 0-based start of the run to the left of `pos`: skip
    /// whitespace going left, then walk left over the run containing the unit
    /// at `pos - 1`. Returns `pos` when no movement is possible (already at the
    /// start of the line / only whitespace to the left).
    private func runStartLeft(codeUnits: [UInt16], pos: Int) -> Int {
        var p = pos
        // Skip whitespace going left.
        while p > 0 && classifier.wordClass(codeUnits[p - 1]) == .whitespace {
            p -= 1
        }
        if p == 0 {
            return 0
        }
        let cls = classifier.wordClass(codeUnits[p - 1])
        // Walk left over the run of `cls`.
        while p > 0 && classifier.wordClass(codeUnits[p - 1]) == cls {
            p -= 1
        }
        return p
    }

    /// Returns the 0-based index of the start of the next non-whitespace run
    /// after `pos`. If `pos` is in the middle of a run, the next run start is
    /// the end of the current run; whitespace runs are skipped. Returns `pos`
    /// when no movement is possible.
    private func runStartRight(codeUnits: [UInt16], pos: Int) -> Int {
        let n = codeUnits.count
        var j = pos + 1
        // Find the smallest j > pos that is a run start and non-whitespace.
        while j < n {
            let isRunStart = (j == 0)
                || (classifier.wordClass(codeUnits[j - 1]) != classifier.wordClass(codeUnits[j]))
            if isRunStart && classifier.wordClass(codeUnits[j]) != .whitespace {
                return j
            }
            j += 1
        }
        return n
    }

    /// Returns the 0-based index just past the end of the run to the right of
    /// `pos`: skip whitespace going right, then walk right over the run
    /// starting at `pos`. Returns `pos` when no movement is possible.
    private func runEndRight(codeUnits: [UInt16], pos: Int) -> Int {
        let n = codeUnits.count
        var p = pos
        // Skip whitespace going right.
        while p < n && classifier.wordClass(codeUnits[p]) == .whitespace {
            p += 1
        }
        if p >= n {
            return n
        }
        let cls = classifier.wordClass(codeUnits[p])
        // Walk right over the run of `cls`.
        while p < n && classifier.wordClass(codeUnits[p]) == cls {
            p += 1
        }
        return p
    }

    /// The latest non-whitespace run whose end is `<= limit`. A run is a
    /// maximal run of code units of the same `MonaWordClass` other than
    /// `.whitespace`.
    private func lastWordRunEnding(atOrBefore limit: Int, in codeUnits: [UInt16]) -> (start: Int, end: Int)? {
        let n = codeUnits.count
        var i = min(limit, n)
        // Skip whitespace going left from `limit`.
        while i > 0 && classifier.wordClass(codeUnits[i - 1]) == .whitespace {
            i -= 1
        }
        if i == 0 {
            return nil
        }
        // `i` is now just past the end of the candidate run. The run's last
        // unit is at index i - 1. But we want a non-whitespace run; if the unit
        // at i-1 is a separator or word char, walk back to the run start.
        let cls = classifier.wordClass(codeUnits[i - 1])
        guard cls != .whitespace else {
            return nil
        }
        var end = i
        var start = i - 1
        while start > 0 && classifier.wordClass(codeUnits[start - 1]) == cls {
            start -= 1
        }
        // Advance `end` to cover the full run to the right (in case `limit`
        // fell mid-run, we still want the whole run).
        while end < n && classifier.wordClass(codeUnits[end]) == cls {
            end += 1
        }
        return (start, end)
    }

    /// Commits a single edit operation as one transaction. Fires `event` on a
    /// successful application.
    private func commitSingle(
        range: MonaRange,
        text: String,
        operation: MonaWordOperation,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        let ops = [MonaModelEditOperation(range: range, text: text)]
        return commit(ops: ops, operation: operation, affectedRange: range, gateway: gateway)
    }

    /// Commits `ops` as one transactional batch through `gateway`. Fires an
    /// event for `affectedRange` on a successful application.
    private func commit(
        ops: [MonaModelEditOperation],
        operation: MonaWordOperation,
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

    /// Fires a word-operations event when not disposed.
    private func fire(_ event: MonaWordOperationsEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
