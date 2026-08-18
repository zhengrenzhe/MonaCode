// MonaWordPartOperationsFeature.swift
//
// P05-T161 — Implement retained feature wordPartOperations.
//
// `MonaWordPartOperationsFeature` is the Swift counterpart of Monaco's
// `wordPartOperations` surface (monaco-editor 0.56.0): it moves and deletes by
// the frozen word-part boundary profile — the camelCase / snake_case /
// digit-run / punctuation-run split over raw UTF-16 code units.
//
// A "word part" is a maximal run of code units of the same `MonaWordPartClass`,
// with one camelCase refinement: an uppercase run followed by lowercase letters
// splits so the final uppercase begins the lowercase run (e.g. `HTMLParser` →
// `HTML` | `Parser`; `caMeL` → `ca` | `Me` | `L`). Underscore (`_`) is its own
// class (`other`), so `snake_case` splits at the underscore (`foo` | `_` |
// `bar`); digit runs are their own class (`abc` | `123` | `def`).
//
//   - move: `moveWordPartLeft` / `moveWordPartRight` (cursorWordPartLeft /
//     cursorWordPartStartLeft, cursorWordPartRight /
//     cursorWordPartStartRight) move to the start of the previous / next word
//     part. `moveWordPartLeftSelect` / `moveWordPartRightSelect`
//     (cursorWordPartLeftSelect / cursorWordPartRightSelect) extend the
//     selection to that start.
//   - delete: `deleteWordPartLeft` / `deleteWordPartRight` (deleteWordPartLeft
//     / deleteWordPartRight) delete the word part to the left / right.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — the move / delete operations above, with
//      deletes committed through `MonaTransactionGateway`.
//   2. Register the exact feature identity `wordPartOperations` and its
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

/// The six-way classification of a UTF-16 code unit under the frozen word-part
/// boundary profile. A word part is a maximal run of code units of the same
/// class, refined by the camelCase rule (`MonaWordPartClassifier.isPartStart`).
public enum MonaWordPartClass: UInt8, Equatable, Hashable {

    /// A lowercase ASCII letter (a–z).
    case lower

    /// An uppercase ASCII letter (A–Z).
    case upper

    /// An ASCII digit (0–9).
    case digit

    /// One of Monaco's configured word separators (a punctuation unit from
    /// `MonaWordClassifier.defaultSeparators`).
    case separator

    /// A whitespace code unit (space, tab, line feed, etc.).
    case whitespace

    /// Any other code unit — including underscore (`_`) and non-ASCII. A
    /// maximal run of `other` units is its own word part (so `snake_case`
    /// splits at the underscore).
    case other
}

/// The frozen word-part classifier over raw UTF-16 code units.
///
/// A refinement of `MonaWordClassifier` (P02-T003) that reclassifies ASCII
/// letters as `lower` / `upper`, ASCII digits as `digit`, and keeps the
/// separator and whitespace classes from the base classifier. Every other code
/// unit (including underscore `_`, which is not a word separator) is `other`.
public struct MonaWordPartClassifier: Equatable, Hashable {

    private let base = MonaWordClassifier()

    /// Creates the word-part classifier with Monaco's default word-separator
    /// profile.
    public init() {}

    /// Returns the six-way class of `codeUnit`.
    public func partClass(_ codeUnit: UInt16) -> MonaWordPartClass {
        // ASCII letters and digits take precedence over the base classifier.
        if codeUnit >= 0x0061 && codeUnit <= 0x007A { // a–z
            return .lower
        }
        if codeUnit >= 0x0041 && codeUnit <= 0x005A { // A–Z
            return .upper
        }
        if codeUnit >= 0x0030 && codeUnit <= 0x0039 { // 0–9
            return .digit
        }
        let wc = base.wordClass(codeUnit)
        switch wc {
        case .wordSeparator:
            return .separator
        case .whitespace:
            return .whitespace
        case .other:
            return .other
        }
    }
}

/// A word-part-operations kind: which of the move / delete operations fired.
public enum MonaWordPartOperation: String, Equatable {

    /// A move operation (`cursorWordPartLeft` / `cursorWordPartRight` and
    /// their select variants). Move does not mutate the model.
    case move

    /// A delete operation (`deleteWordPartLeft` / `deleteWordPartRight`).
    case delete
}

/// A word-part-operations event: the operation that fired and the affected
/// range.
public struct MonaWordPartOperationsEvent: Equatable {

    /// The operation that fired.
    public let operation: MonaWordPartOperation

    /// The range the operation affected (in pre-edit coordinates; for moves,
    /// the range from the source position to the destination).
    public let range: MonaRange

    public init(operation: MonaWordPartOperation, range: MonaRange) {
        self.operation = operation
        self.range = range
    }
}

/// The wordPartOperations feature: move and delete by camel, underscore, digit,
/// and punctuation word parts, transactionally.
///
/// The feature identity `wordPartOperations` and its declared slice are
/// referenced verbatim from the frozen registries. Model mutation is routed
/// through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaWordPartOperationsFeature: MonaDisposable {

    /// The frozen feature identity (`"wordPartOperations"`).
    public static let featureId = "wordPartOperations"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// `wordPartOperations` registers no editor actions in the F1-R3 scope
    /// manifest — only editor commands — so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. The eight word-part cursor /
    /// delete commands, referenced verbatim from the command registry.
    public static let declaredCommandIds: [String] = [
        "cursorWordPartLeft",
        "cursorWordPartLeftSelect",
        "cursorWordPartRight",
        "cursorWordPartRightSelect",
        "cursorWordPartStartLeft",
        "cursorWordPartStartLeftSelect",
        "deleteWordPartLeft",
        "deleteWordPartRight"
    ]

    /// The declared contribution IDs. `wordPartOperations` registers no
    /// contribution descriptor in the F1-R3 scope manifest, so this slice is
    /// empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the word-part commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`, in keybinding ordinal
    /// order.
    public static let declaredKeybindingCommands: [String] = [
        "cursorWordPartLeft",
        "cursorWordPartLeftSelect",
        "cursorWordPartRight",
        "cursorWordPartRightSelect",
        "deleteWordPartLeft",
        "deleteWordPartRight"
    ]

    /// The declared option names — wordPartOperations declares no options, so
    /// this slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — wordPartOperations registers no menu items, so
    /// this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaWordPartOperationsEvent>()

    /// The event stream for word-part-operations changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaWordPartOperationsEvent> { emitter.event }

    private let classifier = MonaWordPartClassifier()
    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the word-part-operations feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: move / delete by word part

    /// Moves to the start of the previous word part (`cursorWordPartLeft` /
    /// `cursorWordPartStartLeft`). Returns the destination position (or the
    /// position at the start of the previous line when already at column 1, or
    /// the same position when at the very start of the document).
    public func moveWordPartLeft(
        from position: MonaPosition,
        model: MonaCodeModel
    ) -> MonaPosition {
        guard !isDisposed else { return position }
        let validated = model.validatePosition(position)
        let line = validated.line
        if validated.column == 1 {
            guard line > 1 else { return validated }
            return MonaPosition(line: line - 1, column: model.getLineMaxColumn(line - 1))
        }
        let codeUnits = Array(model.getLineContent(line).utf16)
        let pos = validated.column - 1
        let dest = partStartLeft(codeUnits: codeUnits, pos: pos)
        return MonaPosition(line: line, column: dest + 1)
    }

    /// Moves to the start of the next word part (`cursorWordPartRight` /
    /// `cursorWordPartStartRight`). Returns the destination position (or the
    /// position at the start of the next line when already at the line end, or
    /// the same position when at the very end of the document).
    public func moveWordPartRight(
        from position: MonaPosition,
        model: MonaCodeModel
    ) -> MonaPosition {
        guard !isDisposed else { return position }
        let validated = model.validatePosition(position)
        let line = validated.line
        let maxColumn = model.getLineMaxColumn(line)
        if validated.column == maxColumn {
            guard line < model.getLineCount() else { return validated }
            return MonaPosition(line: line + 1, column: 1)
        }
        let codeUnits = Array(model.getLineContent(line).utf16)
        let pos = validated.column - 1
        let dest = partStartRight(codeUnits: codeUnits, pos: pos)
        return MonaPosition(line: line, column: dest + 1)
    }

    /// Extends the selection to the start of the previous word part
    /// (`cursorWordPartLeftSelect`). Returns the range from the destination
    /// position to the source position.
    public func moveWordPartLeftSelect(
        from position: MonaPosition,
        model: MonaCodeModel
    ) -> MonaRange {
        guard !isDisposed else {
            return MonaRange(startPosition: position, endPosition: position)
        }
        let dest = moveWordPartLeft(from: position, model: model)
        return MonaRange(startPosition: dest, endPosition: position)
    }

    /// Extends the selection to the start of the next word part
    /// (`cursorWordPartRightSelect`). Returns the range from the source
    /// position to the destination position.
    public func moveWordPartRightSelect(
        from position: MonaPosition,
        model: MonaCodeModel
    ) -> MonaRange {
        guard !isDisposed else {
            return MonaRange(startPosition: position, endPosition: position)
        }
        let dest = moveWordPartRight(from: position, model: model)
        return MonaRange(startPosition: position, endPosition: dest)
    }

    /// Deletes the word part to the left of the cursor (`deleteWordPartLeft`).
    /// Trailing whitespace immediately left of the cursor is skipped first and
    /// deleted together with the preceding word part. Returns `.dropped` when
    /// at column 1 of the first line or after `dispose()`. Fires a `.delete`
    /// event on success.
    @discardableResult
    public func deleteWordPartLeft(
        from position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let validated = model.validatePosition(position)
        let line = validated.line
        if validated.column == 1 {
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
        let dest = partStartLeft(codeUnits: codeUnits, pos: pos)
        guard dest < pos else {
            return .dropped(reason: "no word part to the left")
        }
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: dest + 1),
            endPosition: MonaPosition(line: line, column: validated.column)
        )
        return commitSingle(range: range, text: "", operation: .delete, gateway: gateway)
    }

    /// Deletes the word part to the right of the cursor
    /// (`deleteWordPartRight`). Leading whitespace immediately right of the
    /// cursor is skipped first and deleted together with the following word
    /// part. Returns `.dropped` when at the end of the last line or after
    /// `dispose()`. Fires a `.delete` event on success.
    @discardableResult
    public func deleteWordPartRight(
        from position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let model = gateway.model
        let validated = model.validatePosition(position)
        let line = validated.line
        let maxColumn = model.getLineMaxColumn(line)
        if validated.column == maxColumn {
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
        let dest = partEndRight(codeUnits: codeUnits, pos: pos)
        guard dest > pos else {
            return .dropped(reason: "no word part to the right")
        }
        let range = MonaRange(
            startPosition: MonaPosition(line: line, column: validated.column),
            endPosition: MonaPosition(line: line, column: dest + 1)
        )
        return commitSingle(range: range, text: "", operation: .delete, gateway: gateway)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishWordPartOperationsEvent(
        _ event: MonaWordPartOperationsEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaWordPartOperationsEvent) -> Void
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
    /// return the source position; deletes return `.dropped`).
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
    /// `MonaLocalization` surface under `profile`. wordPartOperations declares
    /// no actions, so this is always empty.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. wordPartOperations performs no
    /// tokenization-dependent work and degrades gracefully to the plain-text
    /// fallback.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — wordPartOperations performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private: word-part walk on the frozen word-part classifier

    /// Returns `true` when a new word part starts at `index` (0-based) in
    /// `codeUnits`. A part starts at index 0, or at a class transition, with
    /// the camelCase refinements:
    ///
    ///   - An uppercase unit followed by a lowercase unit begins a new part
    ///     (so `HTMLParser` splits as `HTML` | `Parser`).
    ///   - A lowercase unit immediately after an uppercase unit belongs to the
    ///     preceding uppercase's part (so `caMeL` splits as `ca` | `Me` | `L`).
    private func isPartStart(_ index: Int, in codeUnits: [UInt16]) -> Bool {
        if index == 0 {
            return true
        }
        let a = classifier.partClass(codeUnits[index - 1])
        let b = classifier.partClass(codeUnits[index])
        // camelCase: an uppercase that begins a lowercase-led part.
        if b == .upper && index + 1 < codeUnits.count
            && classifier.partClass(codeUnits[index + 1]) == .lower {
            return true
        }
        // A lowercase right after an uppercase stays with the uppercase part.
        if a == .upper && b == .lower {
            return false
        }
        // Same class: same run.
        if a == b {
            return false
        }
        // Otherwise a class transition is a part boundary.
        return true
    }

    /// Returns the 0-based start of the word part to the left of `pos`: skip
    /// whitespace going left, then walk left to the start of the part
    /// containing `pos - 1`. Returns 0 when no movement is possible.
    private func partStartLeft(codeUnits: [UInt16], pos: Int) -> Int {
        var p = pos
        // Skip whitespace going left.
        while p > 0 && classifier.partClass(codeUnits[p - 1]) == .whitespace {
            p -= 1
        }
        if p == 0 {
            return 0
        }
        // Find the start of the part containing index p - 1.
        var k = p - 1
        while k > 0 && !isPartStart(k, in: codeUnits) {
            k -= 1
        }
        return k
    }

    /// Returns the 0-based index of the start of the next non-whitespace word
    /// part after `pos`. If `pos` is in the middle of a part, the next part
    /// start is the end of the current part; whitespace runs are skipped.
    /// Returns `codeUnits.count` when no next part exists.
    private func partStartRight(codeUnits: [UInt16], pos: Int) -> Int {
        let n = codeUnits.count
        var j = pos + 1
        while j < n {
            if isPartStart(j, in: codeUnits)
                && classifier.partClass(codeUnits[j]) != .whitespace {
                return j
            }
            j += 1
        }
        return n
    }

    /// Returns the 0-based index just past the end of the word part to the
    /// right of `pos`: skip whitespace going right, then walk right to the end
    /// of the part starting at `pos`. Returns `pos` when no movement is
    /// possible.
    private func partEndRight(codeUnits: [UInt16], pos: Int) -> Int {
        let n = codeUnits.count
        var p = pos
        // Skip whitespace going right.
        while p < n && classifier.partClass(codeUnits[p]) == .whitespace {
            p += 1
        }
        if p >= n {
            return n
        }
        // Walk right to the next part start (the end of the current part).
        var end = p + 1
        while end < n && !isPartStart(end, in: codeUnits) {
            end += 1
        }
        return end
    }

    /// Commits a single edit operation as one transaction. Fires `event` on a
    /// successful application.
    private func commitSingle(
        range: MonaRange,
        text: String,
        operation: MonaWordPartOperation,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        let ops = [MonaModelEditOperation(range: range, text: text)]
        return commit(ops: ops, operation: operation, affectedRange: range, gateway: gateway)
    }

    /// Commits `ops` as one transactional batch through `gateway`. Fires an
    /// event for `affectedRange` on a successful application.
    private func commit(
        ops: [MonaModelEditOperation],
        operation: MonaWordPartOperation,
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

    /// Fires a word-part-operations event when not disposed.
    private func fire(_ event: MonaWordPartOperationsEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
