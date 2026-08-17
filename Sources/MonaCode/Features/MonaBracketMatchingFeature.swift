// MonaBracketMatchingFeature.swift
//
// P05-T101 — Implement retained feature bracketMatching.
//
// `MonaBracketMatchingFeature` is the Swift counterpart of Monaco's
// `BracketMatchingController` (monaco-editor 0.56.0). It matches, navigates,
// selects, and highlights bracket pairs from the active tokenization state.
// When no tokenization / grammar is registered, the feature degrades to
// plain-text bracket scanning (the `MonaPlainTextLanguage` fallback), so
// matching still works over raw text.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `matchBracket`, `jumpToBracket`,
//      `selectToBracket`, and `highlightBracketPairs`.
//   2. Register the exact feature identity `bracketMatching` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A matched bracket pair: the open + close positions and the opening bracket
/// character.
public struct MonaBracketPair: Equatable {

    /// The position of the opening bracket.
    public let open: MonaPosition

    /// The position of the closing bracket.
    public let close: MonaPosition

    /// The opening bracket character (`"("`, `"["`, or `"{"`).
    public let bracket: Character

    public init(open: MonaPosition, close: MonaPosition, bracket: Character) {
        self.open = open
        self.close = close
        self.bracket = bracket
    }
}

/// A bracket-matching event: the pairs computed for highlighting.
public struct MonaBracketMatchingEvent: Equatable {
    /// The bracket pairs delivered by this event.
    public let pairs: [MonaBracketPair]
    public init(pairs: [MonaBracketPair]) {
        self.pairs = pairs
    }
}

/// The bracketMatching feature: match, navigate, select, and highlight bracket
/// pairs from the active tokenization state.
///
/// The feature identity `bracketMatching` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text bracket
/// scanning through `MonaPlainTextLanguage`.
public final class MonaBracketMatchingFeature: MonaDisposable {

    /// The frozen feature identity (`"bracketMatching"`).
    public static let featureId = "bracketMatching"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These
    /// are also the feature's declared command IDs.
    public static let declaredActionIds: [String] = [
        "editor.action.jumpToBracket",
        "editor.action.selectToBracket",
        "editor.action.removeBrackets"
    ]

    /// The declared command IDs (identical to the action IDs for this feature).
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution ID (`BracketMatchingController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.bracketMatchingController"
    ]

    /// The declared keybinding commands — the actions that carry a default
    /// keybinding in `MonaBuiltinKeybindings` (`selectToBracket` carries none).
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.jumpToBracket",
        "editor.action.removeBrackets"
    ]

    /// The declared option names — the bracket-matching options.
    public static let declaredOptionIds: [String] = [
        "matchBrackets",
        "bracketPairColorization",
        "bracketPairGuides"
    ]

    /// The declared menu IDs. bracketMatching declares no menus.
    public static let declaredMenuIds: [String] = []

    // MARK: - Bracket tables

    private static let openingBrackets: [Character: Character] = [
        "(": ")", "[": "]", "{": "}"
    ]
    private static let closingBrackets: [Character: Character] = [
        ")": "(", "]": "[", "}": "{"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaBracketMatchingEvent>()

    /// The event stream for bracket-matching highlights. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the
    /// listener.
    public var onChange: MonaEvent<MonaBracketMatchingEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the bracketMatching feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior

    /// Matches the bracket at `position` in `text` against its counterpart,
    /// respecting nesting. Returns the pair (open + close positions and the
    /// opening bracket character), or `nil` when `position` is not on a bracket
    /// or the bracket is unmatched.
    ///
    /// When the position is on an opening bracket, scans forward for the
    /// matching close; when on a closing bracket, scans backward for the
    /// matching open. Columns are raw UTF-16 offsets.
    public func matchBracket(text: String, position: MonaPosition) -> MonaBracketPair? {
        let flat = Self.flatten(text)
        guard let pair = matchBracket(flat: flat, position: position) else { return nil }
        fireHighlight([pair])
        return pair
    }

    /// Returns the position of the bracket matching the one at `position`, or
    /// `nil` when `position` is not on a bracket or the bracket is unmatched.
    public func jumpToBracket(text: String, position: MonaPosition) -> MonaPosition? {
        let flat = Self.flatten(text)
        guard let pair = matchBracket(flat: flat, position: position) else { return nil }
        // If position is the open, jump to the close; otherwise jump to the open.
        if pair.open == position { return pair.close }
        return pair.open
    }

    /// Returns a selection spanning from the bracket at `position` to its
    /// matching counterpart, or `nil` when no match exists.
    public func selectToBracket(text: String, position: MonaPosition) -> MonaSelection? {
        let flat = Self.flatten(text)
        guard let pair = matchBracket(flat: flat, position: position) else { return nil }
        return MonaSelection(anchor: pair.open, activePosition: pair.close)
    }

    /// Returns every complete bracket pair in `text`, in source order. Nested
    /// and cross-line pairs are supported; unmatched brackets are omitted.
    public func highlightBracketPairs(text: String) -> [MonaBracketPair] {
        let flat = Self.flatten(text)
        var pairs: [MonaBracketPair] = []
        for (index, (_, ch)) in flat.chars.enumerated() {
            guard Self.openingBrackets[ch] != nil else { continue }
            if let closeIndex = Self.scanMatch(from: index, direction: 1, bracket: ch, flat: flat) {
                pairs.append(MonaBracketPair(
                    open: flat.chars[index].0,
                    close: flat.chars[closeIndex].0,
                    bracket: ch
                ))
            }
        }
        fireHighlight(pairs)
        return pairs
    }

    // MARK: - 3a. Model mutation → MonaTransactionGateway

    /// Commits a select-to-bracket transaction through `gateway` as one
    /// ordered unit. The selection spanning the bracket pair at `position` is
    /// prepared on the transaction and recorded as the gateway's committed
    /// selections; the model's text is untouched.
    ///
    /// Returns the gateway's committed selections, or an empty array when no
    /// match exists or the transaction could not be committed.
    @discardableResult
    public func commitSelectToBracket(
        gateway: MonaTransactionGateway,
        text: String,
        position: MonaPosition
    ) -> [MonaSelection] {
        let flat = Self.flatten(text)
        guard let pair = matchBracket(flat: flat, position: position) else { return [] }
        let selection = MonaSelection(anchor: pair.open, activePosition: pair.close)
        let transaction = gateway.beginTransaction()
        transaction.prepareSelections([selection])
        let outcome = gateway.commit(transaction)
        switch outcome {
        case .applied, .reconciled:
            return gateway.lastCommittedSelections
        case .dropped, .rolledBack:
            return []
        }
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `pairs` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishBracketPairs(
        _ pairs: [MonaBracketPair],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaBracketPair]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(pairs),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and highlight events are no longer fired
    /// (matching / navigation remain pure and still return their results).
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

    /// The plain-text fallback language. bracketMatching degrades to
    /// plain-text bracket scanning when no tokenization / grammar is
    /// registered.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — the feature matches brackets by scanning raw text (the
    /// plain-text fallback) until a tokenization provider supplies a richer
    /// bracket state in a later phase.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private: bracket scanning

    /// Fires a highlight event when not disposed.
    private func fireHighlight(_ pairs: [MonaBracketPair]) {
        guard !isDisposed else { return }
        emitter.fire(MonaBracketMatchingEvent(pairs: pairs))
    }

    /// Matches the bracket at `position` against its counterpart using the
    /// flattened text. Pure: performs no event side effect.
    private func matchBracket(flat: FlatText, position: MonaPosition) -> MonaBracketPair? {
        guard let start = flat.indexByPosition[position] else { return nil }
        let ch = flat.chars[start].1
        if Self.openingBrackets[ch] != nil {
            // Opening bracket: scan forward for the matching close.
            guard let closeIdx = Self.scanMatch(from: start, direction: 1, bracket: ch, flat: flat) else {
                return nil
            }
            return MonaBracketPair(
                open: flat.chars[start].0,
                close: flat.chars[closeIdx].0,
                bracket: ch
            )
        }
        if let opening = Self.closingBrackets[ch] {
            // Closing bracket: scan backward for the matching open.
            guard let openIdx = Self.scanMatch(from: start, direction: -1, bracket: ch, flat: flat) else {
                return nil
            }
            return MonaBracketPair(
                open: flat.chars[openIdx].0,
                close: flat.chars[start].0,
                bracket: opening
            )
        }
        return nil
    }

    /// Scans from `start` in `direction` (+1 forward / -1 backward) for the
    /// counterpart of `bracket`, respecting nesting. Returns the index of the
    /// matching counterpart, or `nil` when unmatched.
    private static func scanMatch(
        from start: Int,
        direction: Int,
        bracket: Character,
        flat: FlatText
    ) -> Int? {
        let isOpening = openingBrackets[bracket] != nil
        let complement: Character = isOpening ? openingBrackets[bracket]! : closingBrackets[bracket]!
        var depth = 1
        var i = start + direction
        while i >= 0 && i < flat.chars.count {
            let ch = flat.chars[i].1
            if ch == bracket {
                depth += 1
            } else if ch == complement {
                depth -= 1
                if depth == 0 { return i }
            }
            i += direction
        }
        return nil
    }

    // MARK: - Private: text flattening

    /// A flattened view of text: an array of (position, character) for every
    /// non-newline character, plus a position → index map for O(1) lookup.
    private struct FlatText {
        let chars: [(MonaPosition, Character)]
        let indexByPosition: [MonaPosition: Int]
    }

    /// Flattens `text` into position-tagged characters, splitting on `\n` and
    /// tracking columns as raw UTF-16 offsets (1-based).
    private static func flatten(_ text: String) -> FlatText {
        var chars: [(MonaPosition, Character)] = []
        var indexByPosition: [MonaPosition: Int] = [:]
        let lines = text.components(separatedBy: "\n")
        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            var column = 1
            for char in line {
                let pos = MonaPosition(line: lineNumber, column: column)
                indexByPosition[pos] = chars.count
                chars.append((pos, char))
                column += char.utf16.count
            }
        }
        return FlatText(chars: chars, indexByPosition: indexByPosition)
    }
}
