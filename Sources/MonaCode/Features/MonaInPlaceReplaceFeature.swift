// MonaInPlaceReplaceFeature.swift
//
// P05-T130 — Implement retained feature inPlaceReplace.
//
// `MonaInPlaceReplaceFeature` is the Swift counterpart of Monaco's
// `inPlaceReplace` contribution (monaco-editor 0.56.0): it replaces the active
// word at a position with the previous or next candidate value, cycling through
// candidates on repeated invocations at the same position. The previous value
// (`editor.action.inPlaceReplace.up`) steps the base value down; the next value
// (`editor.action.inPlaceReplace.down`) steps it up. Edits are applied
// transactionally through `MonaTransactionGateway`.
//
// Candidates are computed from the active word under the degraded plain-text
// path (no language provider is registered in Foundation-only Core):
//   - integer words step by ±1 per invocation (base + signed step);
//   - boolean words (`true` / `false`) toggle on each step;
//   - any other word has no candidate and the command is dropped.
//
// Cycling is anchored to the position: consecutive replacements at the same
// position continue the signed step from the original base word, so a sequence
// `next, next, previous` walks `5 → 6 → 7 → 6`. Moving to a different word, or
// an external edit that diverges from the last written value, resets the
// anchor.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `activeWord(at:model:)`, `candidates(for:)`,
//      `replacePrevious(at:gateway:)`, `replaceNext(at:gateway:)`, all committed
//      through `MonaTransactionGateway`.
//   2. Register the exact feature identity `inPlaceReplace` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// An in-place replace direction: which candidate calculation fired.
public enum MonaInPlaceReplaceDirection: String, Equatable {

    /// `editor.action.inPlaceReplace.up` — replace with the previous value
    /// (step the base down).
    case previous

    /// `editor.action.inPlaceReplace.down` — replace with the next value
    /// (step the base up).
    case next
}

/// The candidate values computed for an active word: the descending (previous)
/// and ascending (next) candidate lists. Under the degraded plain-text path
/// each list is the single step value derived from the base word; the cycle
/// across repeated invocations is tracked by the feature, not by this list.
public struct MonaInPlaceReplaceCandidates: Equatable {

    /// The previous (descending) candidate at offset 0, or `nil` when the word
    /// admits no candidate.
    public let previous: String?

    /// The next (ascending) candidate at offset 0, or `nil` when the word
    /// admits no candidate.
    public let next: String?

    public init(previous: String?, next: String?) {
        self.previous = previous
        self.next = next
    }
}

/// An in-place replace event: the direction that fired and the affected range,
/// the previous text, and the new text.
public struct MonaInPlaceReplaceEvent: Equatable {

    /// The direction that fired.
    public let direction: MonaInPlaceReplaceDirection

    /// The replaced range (in pre-edit coordinates).
    public let range: MonaRange

    /// The active word's text before the replacement.
    public let oldText: String

    /// The candidate text written by the replacement.
    public let newText: String

    public init(
        direction: MonaInPlaceReplaceDirection,
        range: MonaRange,
        oldText: String,
        newText: String
    ) {
        self.direction = direction
        self.range = range
        self.oldText = oldText
        self.newText = newText
    }
}

/// The in-place replace feature: replace the active word from exact previous
/// and next candidate calculations, cycling through candidates on repeat.
///
/// The feature identity `inPlaceReplace` and its declared slice are referenced
/// verbatim from the frozen registries. The active word at a position is the
/// maximal alphanumeric / underscore run containing the column. Candidates are
/// computed under the degraded plain-text path (integers step ±1; booleans
/// toggle). Model mutation is routed through `MonaTransactionGateway`;
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaInPlaceReplaceFeature: MonaDisposable {

    /// The frozen feature identity (`"inPlaceReplace"`).
    public static let featureId = "inPlaceReplace"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These are
    /// the two labeled in-place replace actions: `up` (replace with previous)
    /// then `down` (replace with next), ordinals 134 and 135.
    public static let declaredActionIds: [String] = [
        "editor.action.inPlaceReplace.up",
        "editor.action.inPlaceReplace.down"
    ]

    /// The declared command IDs in source order. The two in-place replace
    /// actions are also registered as editor commands, so this slice equals
    /// `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution ID. The in-place replace controller — the
    /// single in-place replace contribution (ordinal 31).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.inPlaceReplaceController"
    ]

    /// The declared keybinding commands — the two in-place replace actions that
    /// carry a default keybinding in `MonaBuiltinKeybindings`
    /// (`Cmd+Shift+,` previous, `Cmd+Shift+.` next), in declared action order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.inPlaceReplace.up",
        "editor.action.inPlaceReplace.down"
    ]

    /// The declared option names — in-place replace declares no options in the
    /// F1-R3 scope manifest, so this slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — in-place replace registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaInPlaceReplaceEvent>()

    /// The event stream for in-place replace changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaInPlaceReplaceEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Cycling anchor: the position of the active word, the original base word,
    /// the signed step from the base, and the last value written. Reset when the
    /// position moves or the model diverges from the last written value.
    private var anchorPosition: MonaPosition?
    private var baseWord: String = ""
    private var step: Int = 0
    private var lastWrittenValue: String = ""

    /// Creates the in-place replace feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: replace the active word, cycling candidates

    /// Returns the active word at `position` in `model`: the maximal run of
    /// alphanumeric / underscore characters containing the column, with its
    /// range (in 1-based column coordinates) and text. Returns `nil` when the
    /// column is on whitespace or past the end of the line.
    public func activeWord(
        at position: MonaPosition,
        model: MonaCodeModel
    ) -> (range: MonaRange, text: String)? {
        let lineNumber = position.line
        guard lineNumber >= 1, lineNumber <= model.getLineCount() else { return nil }
        let content = model.getLineContent(lineNumber)
        let column = position.column
        guard column >= 1 else { return nil }
        let index = column - 1 // 0-based character index
        let chars = Array(content)
        guard index < chars.count else { return nil }
        let target = chars[index]
        guard Self.isWordCharacter(target) else { return nil }

        // Expand left and right while the run stays a word character.
        var start = index
        while start > 0, Self.isWordCharacter(chars[start - 1]) {
            start -= 1
        }
        var end = index
        while end + 1 < chars.count, Self.isWordCharacter(chars[end + 1]) {
            end += 1
        }
        // `end` is inclusive; the range spans columns (start+1)...(end+2).
        let word = String(chars[start...end])
        let range = MonaRange(
            startPosition: MonaPosition(line: lineNumber, column: start + 1),
            endPosition: MonaPosition(line: lineNumber, column: end + 2)
        )
        return (range, word)
    }

    /// Computes the previous and next candidate at offset 0 for `text` under the
    /// degraded plain-text path: integers step ±1; booleans (`true` / `false`)
    /// toggle; any other word has no candidate.
    public func candidates(for text: String) -> MonaInPlaceReplaceCandidates {
        if let n = Int(text) {
            return MonaInPlaceReplaceCandidates(
                previous: String(n - 1),
                next: String(n + 1)
            )
        }
        if text == "true" {
            return MonaInPlaceReplaceCandidates(previous: "false", next: "false")
        }
        if text == "false" {
            return MonaInPlaceReplaceCandidates(previous: "true", next: "true")
        }
        return MonaInPlaceReplaceCandidates(previous: nil, next: nil)
    }

    /// Computes the candidate for `base` at the signed `step` from the base.
    /// Integers return `base + step`; booleans return the base when `step` is
    /// even and the opposite when `step` is odd. Returns `nil` for words that
    /// admit no candidate.
    private func candidate(base: String, step: Int) -> String? {
        if let n = Int(base) {
            return String(n + step)
        }
        if base == "true" {
            return step.isMultiple(of: 2) ? "true" : "false"
        }
        if base == "false" {
            return step.isMultiple(of: 2) ? "false" : "true"
        }
        return nil
    }

    /// The signed delta for `direction` (+1 for next, -1 for previous).
    private func delta(for direction: MonaInPlaceReplaceDirection) -> Int {
        return direction == .next ? 1 : -1
    }

    /// Replaces the active word at `position` with the candidate in
    /// `direction`, cycling through candidates on repeated invocations at the
    /// same position. The edit is committed transactionally through `gateway`.
    /// Returns `.dropped` when the word admits no candidate, when no active
    /// word exists at the position, or after `dispose()`. Fires an event on
    /// success.
    @discardableResult
    public func replace(
        at position: MonaPosition,
        direction: MonaInPlaceReplaceDirection,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        guard let active = activeWord(at: position, model: gateway.model) else {
            return .dropped(reason: "no active word")
        }

        let isContinuation = anchorPosition == position && active.text == lastWrittenValue
        let newStep: Int
        if isContinuation {
            newStep = step + delta(for: direction)
        } else {
            baseWord = active.text
            newStep = delta(for: direction)
        }

        guard let replacement = candidate(base: baseWord, step: newStep) else {
            // Reset the anchor so a later word at the same position re-anchors.
            anchorPosition = nil
            return .dropped(reason: "no candidate")
        }

        let ops = [MonaModelEditOperation(range: active.range, text: replacement)]
        let outcome = commit(ops, gateway: gateway)

        // Record the anchor only on a successful application.
        if case .applied = outcome {
            _lock.lock()
            anchorPosition = position
            step = newStep
            lastWrittenValue = replacement
            _lock.unlock()
            fire(.init(
                direction: direction,
                range: active.range,
                oldText: active.text,
                newText: replacement
            ))
        }
        return outcome
    }

    /// Replaces the active word at `position` with the previous value (step the
    /// base down). Cycles through candidates on repeat. A no-op after
    /// `dispose()`.
    @discardableResult
    public func replacePrevious(
        at position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        return replace(at: position, direction: .previous, gateway: gateway)
    }

    /// Replaces the active word at `position` with the next value (step the
    /// base up). Cycles through candidates on repeat. A no-op after `dispose()`.
    @discardableResult
    public func replaceNext(
        at position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        return replace(at: position, direction: .next, gateway: gateway)
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
    public func publishReplaceEvent(
        _ event: MonaInPlaceReplaceEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaInPlaceReplaceEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `replacePrevious` / `replaceNext` are
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

    /// The plain-text fallback language. inPlaceReplace computes candidates
    /// from the active word under the plain-text fallback (no language provider
    /// is registered in Foundation-only Core); it degrades to plain text for
    /// its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — inPlaceReplace performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires an in-place replace event when not disposed.
    private func fire(_ event: MonaInPlaceReplaceEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }

    /// `true` when `character` participates in an in-place replace word
    /// (alphanumeric or underscore).
    private static func isWordCharacter(_ character: Character) -> Bool {
        return character.isLetter || character.isNumber || character == "_"
    }
}
