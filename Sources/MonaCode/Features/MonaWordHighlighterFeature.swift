// MonaWordHighlighterFeature.swift
//
// P05-T159 — Implement retained feature wordHighlighter.
//
// `MonaWordHighlighterFeature` is the Swift counterpart of Monaco's
// `wordHighlighter` contribution (monaco-editor 0.56.0, registered as
// `editor.contrib.wordHighlighter`): it combines textual and provider document
// highlights for the word under the cursor, under provider-version and
// cancellation gates, and lets the host navigate forward / backward through
// the retained set.
//
// Textual highlights are a literal whole-word search for the word at the
// trigger position (the degraded plain-text path — no language provider is
// registered in Foundation-only Core). Provider highlights are produced by a
// `MonaDocumentHighlightProvider` and published through the shared
// `MonaProviderExecutor` (P05-T013), which validates a `MonaAsyncValidityTicket`
// immediately before publication (the version gate) and may be gated by a
// `MonaCancellationToken` (the cancellation gate). The combined set is the
// deduped union (the provider is authoritative on a shared range's kind).
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `textualHighlights(for:in:)`,
//      `combine(_:_:)`, `requestCombinedHighlights(...)`, `navigateNext()` /
//      `navigatePrevious()`, and `stopHighlights()`.
//   2. Register the exact feature identity `wordHighlighter` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation (read-only — none), asynchronous publication,
//      disposal, localization, and degraded plain-text behavior through the
//      shared gateways — reusing `MonaTransactionGateway` (mutation, vacuous),
//      `MonaProviderExecutor` + `MonaMicrotaskQueue` (async publication),
//      `MonaEmitter` (disposal), `MonaLocalization` (localization), and
//      `MonaPlainTextLanguage` (degraded plain text). No parallel mechanisms
//      are introduced.

import Foundation

/// A word-highlight kind — mirrors Monaco's `DocumentHighlightKind`
/// (Text = 0, Read = 1, Write = 2).
public enum MonaWordHighlightKind: String, Equatable {

    /// A textual occurrence (a literal whole-word match).
    case text

    /// A read reference.
    case read

    /// A write reference.
    case write
}

/// A document highlight: the 1-based range and the highlight kind. Mirrors
/// Monaco's `DocumentHighlight`.
public struct MonaDocumentHighlight: Equatable {

    /// The 1-based range of the highlighted occurrence.
    public let range: MonaRange

    /// The highlight kind.
    public let kind: MonaWordHighlightKind

    public init(range: MonaRange, kind: MonaWordHighlightKind) {
        self.range = range
        self.kind = kind
    }
}

/// A document-highlight provider — the Swift counterpart of Monaco's
/// `DocumentHighlightProvider`. Returns the highlights for `position`, gated by
/// `token`.
///
/// The result is published through `MonaProviderExecutor`, so a provider may
/// return its result in any of the seven normalized shapes (synchronous,
/// asynchronous, optional, throwing, cancelable, resolvable, releasable). The
/// `token` is the cancellation gate: a provider that performs async work
/// should observe it and short-circuit when cancellation is requested.
public protocol MonaDocumentHighlightProvider {

    /// Returns the document highlights for `position` in `model`, gated by
    /// `token`.
    func provideDocumentHighlights(
        at position: MonaPosition,
        model: MonaCodeModel,
        token: MonaCancellationToken
    ) -> MonaProviderResult<[MonaDocumentHighlight]>
}

/// A word-highlighter event: the retained highlight set and the active index.
public struct MonaWordHighlighterEvent: Equatable {

    /// The retained highlights (empty when none are active).
    public let highlights: [MonaDocumentHighlight]

    /// The active reference index within `highlights`.
    public let currentIndex: Int

    public init(highlights: [MonaDocumentHighlight], currentIndex: Int) {
        self.highlights = highlights
        self.currentIndex = currentIndex
    }
}

/// The wordHighlighter feature: combine textual and provider document
/// highlights with version gating.
///
/// The feature identity `wordHighlighter` and its declared slice are
/// referenced verbatim from the frozen registries. The feature is read-only: it
/// performs no model mutation (the vacuous mutation path is still routed
/// through `MonaTransactionGateway`). Asynchronous publication is routed
/// through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaWordHighlighterFeature: MonaDisposable {

    /// The frozen feature identity (`"wordHighlighter"`).
    public static let featureId = "wordHighlighter"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// three word-highlight actions: next, previous, and trigger (ordinals 157,
    /// 158, 159).
    public static let declaredActionIds: [String] = [
        "editor.action.wordHighlight.next",
        "editor.action.wordHighlight.prev",
        "editor.action.wordHighlight.trigger"
    ]

    /// The declared command IDs in source order. Each word-highlight action is
    /// also registered as an editor command, so this slice equals
    /// `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution ID (`editor.contrib.wordHighlighter`,
    /// ordinal 46).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.wordHighlighter"
    ]

    /// The declared keybinding commands — the word-highlight commands that
    /// carry a default keybinding in `MonaBuiltinKeybindings` (next = F7,
    /// previous = Shift+F7; trigger has no default keybinding).
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.wordHighlight.next",
        "editor.action.wordHighlight.prev"
    ]

    /// The declared option names — wordHighlighter declares no options in the
    /// F1-R3 scope manifest, so this slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — wordHighlighter registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The retained highlight set, or empty when none is active.
    private var activeHighlights: [MonaDocumentHighlight] = []

    /// The active reference index within `activeHighlights`.
    private var _currentIndex: Int = 0

    private let emitter = MonaEmitter<MonaWordHighlighterEvent>()

    /// The event stream for word-highlighter changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the
    /// listener.
    public var onChange: MonaEvent<MonaWordHighlighterEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the wordHighlighter feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// `true` when a highlight set is currently retained.
    public var hasActiveHighlights: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return !activeHighlights.isEmpty
    }

    /// The active reference index (0 when no highlights are retained).
    public var currentIndex: Int {
        _lock.lock(); defer { _lock.unlock() }
        return _currentIndex
    }

    /// The retained highlight set (empty when none is active).
    public var currentHighlights: [MonaDocumentHighlight] {
        _lock.lock(); defer { _lock.unlock() }
        return activeHighlights
    }

    // MARK: - 1. Feature-specific behavior: combine textual + provider highlights

    /// Returns the textual highlights for `position` in `model`: a literal,
    /// case-sensitive, whole-word search for the word at `position`. Each match
    /// is reported as a `.text` highlight. Returns an empty array when no active
    /// word exists at `position`, or after `dispose()`.
    public func textualHighlights(
        for position: MonaPosition,
        in model: MonaCodeModel
    ) -> [MonaDocumentHighlight] {
        guard !isDisposed else { return [] }
        guard let word = activeWord(at: position, in: model), !word.isEmpty else { return [] }

        var highlights: [MonaDocumentHighlight] = []
        var line = 1
        var column = 1 // 1-based UTF-16 code-unit column
        var runStartColumn = 0 // 1-based column where the current run started
        var runScalars: [Unicode.Scalar] = []
        for scalar in model.getValue().unicodeScalars {
            if scalar == "\n" {
                if !runScalars.isEmpty {
                    flushRun(runScalars, startColumn: runStartColumn, line: line, word: word, into: &highlights)
                }
                line += 1
                column = 1
                runStartColumn = 0
                runScalars = []
                continue
            }
            if Self.isWordCharacter(scalar) {
                if runScalars.isEmpty {
                    runStartColumn = column
                }
                runScalars.append(scalar)
            } else {
                if !runScalars.isEmpty {
                    flushRun(runScalars, startColumn: runStartColumn, line: line, word: word, into: &highlights)
                    runScalars = []
                    runStartColumn = 0
                }
            }
            column += scalar.value < 0x10000 ? 1 : 2
        }
        // Flush a trailing run at end-of-text.
        if !runScalars.isEmpty {
            flushRun(runScalars, startColumn: runStartColumn, line: line, word: word, into: &highlights)
        }
        return highlights
    }

    /// Combines `provider` and `textual` highlights into the deduped union. The
    /// provider is authoritative on a shared range's kind: when both sides
    /// produce a highlight for the same range, the provider's kind wins. Pure
    /// (no state, no disposal gate).
    public func combine(
        _ textual: [MonaDocumentHighlight],
        _ provider: [MonaDocumentHighlight]
    ) -> [MonaDocumentHighlight] {
        var seen: Set<MonaRange> = []
        var result: [MonaDocumentHighlight] = []
        result.reserveCapacity(provider.count + textual.count)
        for h in provider {
            if seen.insert(h.range).inserted {
                result.append(h)
            }
        }
        for h in textual {
            if seen.insert(h.range).inserted {
                result.append(h)
            }
        }
        return result
    }

    /// Requests the combined textual + provider highlights for `position`,
    /// published through the shared `executor` on the deterministic microtask
    /// queue. The provider's result is normalized onto the publication path,
    /// with `ticket` validated immediately before publication (the version
    /// gate) and `token` available as the cancellation gate. `receive` runs
    /// ONLY when the queue is drained (FIFO), after the ticket is validated
    /// and the cancellation gate has not suppressed publication; it receives
    /// the deduped union of the textual highlights (computed at request time,
    /// still valid because the version gate guarantees the model is unchanged)
    /// and the provider highlights. Returns `true` when the result was
    /// accepted onto the publication path (enqueued / armed); `false` when the
    /// shape normalized to "no value to publish" (an already-cancelled token).
    /// Returns `false` after `dispose()`.
    @discardableResult
    public func requestCombinedHighlights(
        at position: MonaPosition,
        provider: MonaDocumentHighlightProvider,
        model: MonaCodeModel,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        token: MonaCancellationToken,
        receive: @escaping ([MonaDocumentHighlight]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        let textual = textualHighlights(for: position, in: model)
        let result = provider.provideDocumentHighlights(
            at: position,
            model: model,
            token: token
        )
        return executor.publish(result, ticket: ticket) { [weak self] providerHighlights in
            guard let self = self else { return }
            let combined = self.combine(textual, providerHighlights)
            self.retainHighlights(combined)
            receive(combined)
        }
    }

    /// Navigates to the next highlight, wrapping around to 0 at the end. A
    /// no-op when no highlights are retained, or after `dispose()`.
    public func navigateNext() {
        navigate(by: 1)
    }

    /// Navigates to the previous highlight, wrapping around to the last at 0.
    /// A no-op when no highlights are retained, or after `dispose()`.
    public func navigatePrevious() {
        navigate(by: -1)
    }

    /// Clears the retained highlight set. Idempotent. A no-op after
    /// `dispose()`.
    public func stopHighlights() {
        guard !isDisposed else { return }
        _lock.lock()
        let had = !activeHighlights.isEmpty
        activeHighlights = []
        _currentIndex = 0
        _lock.unlock()
        if had {
            fire(.init(highlights: [], currentIndex: 0))
        }
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway (read-only: none performed)

    /// wordHighlighter is a read-only feature: it performs no model mutation.
    /// Mutation routing is therefore vacuous — the feature introduces no
    /// parallel mutation mechanism, and `requestCombinedHighlights` leaves the
    /// model untouched. This no-op is exposed so callers that route every
    /// feature action through the gateway can confirm the model is unchanged.
    @discardableResult
    public func confirmReadOnly(gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `highlights` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    /// After `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishHighlights(
        _ highlights: [MonaDocumentHighlight],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaDocumentHighlight]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(highlights),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the retained highlights are cleared,
    /// and `requestCombinedHighlights` / `navigateNext` / `navigatePrevious`
    /// are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        activeHighlights = []
        _currentIndex = 0
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

    /// The plain-text fallback language. wordHighlighter degrades to the
    /// textual (literal whole-word search) path when no document-highlight
    /// provider is registered (Foundation-only Core); the textual path needs no
    /// tokenization.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — wordHighlighter degrades gracefully to the textual plain-text
    /// path when no document-highlight provider is registered.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Retains `highlights` as the active set (resetting the index to 0) and
    /// fires an event. Called inside the executor's publication microtask, so
    /// the ticket has already been validated.
    private func retainHighlights(_ highlights: [MonaDocumentHighlight]) {
        _lock.lock()
        let disposed = _isDisposed
        if !disposed {
            activeHighlights = highlights
            _currentIndex = 0
        }
        let retained = disposed ? [] : highlights
        let idx = disposed ? 0 : _currentIndex
        _lock.unlock()
        if !retained.isEmpty {
            fire(.init(highlights: retained, currentIndex: idx))
        }
    }

    /// Navigates the active index by `delta` (wrapping). A no-op when no
    /// highlights are retained.
    private func navigate(by delta: Int) {
        guard !isDisposed else { return }
        _lock.lock()
        guard !activeHighlights.isEmpty else {
            _lock.unlock()
            return
        }
        let count = activeHighlights.count
        _currentIndex = ((_currentIndex + delta) % count + count) % count
        let highlights = activeHighlights
        let idx = _currentIndex
        _lock.unlock()
        fire(.init(highlights: highlights, currentIndex: idx))
    }

    /// Fires a word-highlighter event when not disposed.
    private func fire(_ event: MonaWordHighlighterEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }

    /// Returns the active word at `position` in `model`: the maximal run of
    /// alphanumeric / underscore scalars containing the column, as a string.
    /// Returns `nil` when the column is on a non-word scalar or past the end of
    /// the line.
    private func activeWord(at position: MonaPosition, in model: MonaCodeModel) -> String? {
        let lineNumber = position.line
        guard lineNumber >= 1, lineNumber <= model.getLineCount() else { return nil }
        let content = model.getLineContent(lineNumber)
        let column = position.column
        guard column >= 1 else { return nil }

        let scalars = Array(content.unicodeScalars)
        // Walk to the scalar whose UTF-16 offset is (column - 1).
        var offset = 0
        var index = 0
        while index < scalars.count && offset < column - 1 {
            offset += scalars[index].value < 0x10000 ? 1 : 2
            index += 1
        }
        guard index < scalars.count, offset == column - 1,
            Self.isWordCharacter(scalars[index]) else { return nil }

        var start = index
        while start > 0, Self.isWordCharacter(scalars[start - 1]) {
            start -= 1
        }
        var end = index
        while end + 1 < scalars.count, Self.isWordCharacter(scalars[end + 1]) {
            end += 1
        }
        return Self.string(from: scalars[start...end])
    }

    /// Flushes a completed word-run: if it equals `word`, appends a `.text`
    /// highlight at the run's 1-based range.
    private func flushRun(
        _ runScalars: [Unicode.Scalar],
        startColumn: Int,
        line: Int,
        word: String,
        into highlights: inout [MonaDocumentHighlight]
    ) {
        let runText = Self.string(from: runScalars)
        guard runText == word else { return }
        var utf16Length = 0
        for s in runScalars {
            utf16Length += s.value < 0x10000 ? 1 : 2
        }
        highlights.append(MonaDocumentHighlight(
            range: MonaRange(
                startLine: line,
                startColumn: startColumn,
                endLine: line,
                endColumn: startColumn + utf16Length
            ),
            kind: .text
        ))
    }

    /// `true` when `scalar` participates in a word (letter, digit, or
    /// underscore).
    private static func isWordCharacter(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == "_" { return true }
        let character = Character(scalar)
        return character.isLetter || character.isNumber
    }

    /// Builds a `String` from a sequence of unicode scalars. Used instead of
    /// `String(_:)` (which has no `Unicode.Scalar`-sequence overload) by
    /// appending each scalar to the view — reliable for any scalar slice.
    private static func string<S: Sequence>(from scalars: S) -> String where S.Element == Unicode.Scalar {
        var result = ""
        for scalar in scalars {
            result.unicodeScalars.append(scalar)
        }
        return result
    }
}
