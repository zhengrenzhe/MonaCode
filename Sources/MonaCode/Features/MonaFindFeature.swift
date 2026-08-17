// MonaFindFeature.swift
//
// P05-T117 — Implement retained feature find.
//
// `MonaFindFeature` is the Swift counterpart of Monaco's `find` contribution
// (monaco-editor 0.56.0): it runs literal and RegExp find and replace with
// exact match, scope, and history semantics over a `MonaCodeModel`. Literal
// find reuses `MonaLiteralSearch` (P02-T003); RegExp find reuses
// `MonaRegExpParser` / `MonaRegExpExecutor` (P02-T004, via
// `monaRegExpCompile`); replacement reuses `MonaReplacePattern` (P02-T003).
// Replace edits route through `MonaTransactionGateway` as one ordered unit.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `findMatches`, `replaceNext`, `replaceAll`,
//      and the search / replace history.
//   2. Register the exact feature identity `find` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A find query: the search string, the match options, and the scope flag.
///
/// `matchCase` defaults to `true` (exact match, Monaco's `matchCase` default
/// for the find widget). `isRegex` selects the RegExp path (reuses
/// `MonaRegExpParser` / `MonaRegExpExecutor`); the literal path reuses
/// `MonaLiteralSearch`. `wholeWord` filters matches to word boundaries.
/// `findInSelection` scopes the search to a caller-supplied `MonaRange`.
public struct MonaFindQuery: Equatable {

    /// The search string (a literal needle, or a RegExp pattern when
    /// `isRegex` is `true`).
    public let searchString: String

    /// `true` to interpret `searchString` as a RegExp (reuses
    /// `MonaRegExpParser` / `MonaRegExpExecutor`).
    public let isRegex: Bool

    /// `true` (default) for case-sensitive exact match; `false` for
    /// case-insensitive.
    public let matchCase: Bool

    /// `true` to filter matches to word boundaries (the character before the
    /// start and after the end must be non-word characters or string
    /// boundaries).
    public let wholeWord: Bool

    /// `true` to scope the search to a caller-supplied `MonaRange` (the
    /// selection).
    public let findInSelection: Bool

    /// Creates a find query.
    public init(
        searchString: String,
        isRegex: Bool = false,
        matchCase: Bool = true,
        wholeWord: Bool = false,
        findInSelection: Bool = false
    ) {
        self.searchString = searchString
        self.isRegex = isRegex
        self.matchCase = matchCase
        self.wholeWord = wholeWord
        self.findInSelection = findInSelection
    }
}

/// A find result: the match ranges (as `MonaRange`, 1-based line / column).
public struct MonaFindResult: Equatable {

    /// The match ranges, in ascending start-position order.
    public let matches: [MonaRange]

    public init(matches: [MonaRange]) {
        self.matches = matches
    }
}

/// A find event: the result delivered by a find / replace run.
public struct MonaFindEvent: Equatable {

    /// The result delivered by this event.
    public let result: MonaFindResult

    public init(result: MonaFindResult) {
        self.result = result
    }
}

/// The find feature: run literal and RegExp find and replace with exact match,
/// scope, and history semantics.
///
/// The feature identity `find` and its declared slice are referenced verbatim
/// from the frozen registries. Literal find reuses `MonaLiteralSearch`; RegExp
/// find reuses `MonaRegExpParser` / `MonaRegExpExecutor` (via
/// `monaRegExpCompile`); replacement reuses `MonaReplacePattern`. Replace edits
/// are routed through `MonaTransactionGateway` as one ordered unit (the model
/// applies the batch in descending start-offset order so earlier ranges stay
/// valid). Asynchronous publication is routed through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaFindFeature: MonaDisposable {

    /// The frozen feature identity (`"find"`).
    public static let featureId = "find"

    /// The maximum number of search / replace history entries retained (Monaco's
    /// `find.history` default is per-workspace; this caps the in-memory list).
    private static let historyLimit = 50

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These
    /// are the labeled editor actions registered by the find contribution.
    public static let declaredActionIds: [String] = [
        "actions.find",
        "editor.action.nextMatchFindAction",
        "editor.action.previousMatchFindAction",
        "editor.action.startFindReplaceAction",
        "editor.actions.findWithArgs",
        "actions.findWithSelection",
        "editor.action.goToMatchFindAction",
        "editor.action.nextSelectionMatchFindAction",
        "editor.action.previousSelectionMatchFindAction"
    ]

    /// The declared command IDs in source order. These are the find command
    /// set: the find / replace / next / previous / selection / go-to-match
    /// actions, the replace-all / replace-one / select-all-matches commands,
    /// the close-widget command, and the four toggle commands.
    public static let declaredCommandIds: [String] = [
        "actions.find",
        "actions.findWithSelection",
        "closeFindWidget",
        "editor.action.goToMatchFindAction",
        "editor.action.nextMatchFindAction",
        "editor.action.nextSelectionMatchFindAction",
        "editor.action.previousMatchFindAction",
        "editor.action.previousSelectionMatchFindAction",
        "editor.action.replaceAll",
        "editor.action.replaceOne",
        "editor.action.selectAllMatches",
        "editor.action.startFindReplaceAction",
        "editor.actions.findWithArgs",
        "toggleFindCaseSensitive",
        "toggleFindInSelection",
        "toggleFindRegex",
        "toggleFindWholeWord"
    ]

    /// The declared contribution ID (`editor.contrib.findController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.findController"
    ]

    /// The declared keybinding commands — the find commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`, in source order. The
    /// `findWithArgs` and `goToMatchFindAction` commands carry no default
    /// keybinding.
    public static let declaredKeybindingCommands: [String] = [
        "actions.find",
        "actions.findWithSelection",
        "closeFindWidget",
        "editor.action.nextMatchFindAction",
        "editor.action.nextSelectionMatchFindAction",
        "editor.action.previousMatchFindAction",
        "editor.action.previousSelectionMatchFindAction",
        "editor.action.replaceAll",
        "editor.action.replaceOne",
        "editor.action.selectAllMatches",
        "editor.action.startFindReplaceAction",
        "toggleFindCaseSensitive",
        "toggleFindInSelection",
        "toggleFindRegex",
        "toggleFindWholeWord"
    ]

    /// The declared option names — the `find` option (an object with the
    /// find-widget defaults: `autoFindInSelection`, `findOnType`, `loop`,
    /// `seedSearchStringFromSelection`, etc.).
    public static let declaredOptionIds: [String] = [
        "find"
    ]

    /// The declared menu IDs — the menus that carry find menu items. `actions.find`
    /// and `editor.action.startFindReplaceAction` appear in the `MenubarEditMenu`.
    public static let declaredMenuIds: [String] = [
        "MenubarEditMenu"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaFindEvent>()

    /// The event stream for find / replace changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaFindEvent> { emitter.event }

    /// The search history (most-recent-first, de-duplicated).
    private var _searchHistory: [String] = []

    /// The replace history (most-recent-first, de-duplicated).
    private var _replaceHistory: [String] = []

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the find feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The search history (most-recent-first, de-duplicated).
    public var searchHistory: [String] {
        _lock.lock(); defer { _lock.unlock() }
        return _searchHistory
    }

    /// The replace history (most-recent-first, de-duplicated).
    public var replaceHistory: [String] {
        _lock.lock(); defer { _lock.unlock() }
        return _replaceHistory
    }

    // MARK: - 1. Feature-specific behavior: find / replace / history

    /// Runs a find over `model` with `query`, returning the match ranges. When
    /// `query.isRegex` is `false`, the literal path reuses `MonaLiteralSearch`;
    /// when `true`, the RegExp path reuses `MonaRegExpParser` /
    /// `MonaRegExpExecutor` (via `monaRegExpCompile`). `matchCase` selects
    /// case-sensitive exact match (the default) or case-insensitive. `wholeWord`
    /// filters matches to word boundaries. When `query.findInSelection` is `true`
    /// and `scope` is supplied, the search is scoped to that range. Fires an
    /// event with the result. Returns an empty result after `dispose()`.
    @discardableResult
    public func findMatches(
        in model: MonaCodeModel,
        query: MonaFindQuery,
        scope: MonaRange? = nil
    ) -> MonaFindResult {
        guard !isDisposed else { return MonaFindResult(matches: []) }
        let haystack = Array(model.getValue().utf16)
        let scopeBounds = scopeOffsets(model: model, scope: scope, haystack: haystack)
        let raw = rawMatches(haystack: haystack, query: query, from: scopeBounds.start)
        let filtered = raw.filter { match in
            // Scope: keep matches fully inside the scope range.
            match.endOffset <= scopeBounds.end
                // Whole-word: keep matches at word boundaries.
                && (!query.wholeWord || isWholeWord(haystack: haystack, start: match.startOffset, end: match.endOffset))
        }
        let ranges = filtered.map { match in
            MonaRange(
                startPosition: model.getPositionAt(match.startOffset),
                endPosition: model.getPositionAt(match.endOffset)
            )
        }
        let result = MonaFindResult(matches: ranges)
        fire(result)
        return result
    }

    /// Replaces the first match of `query` in `model` with `replaceString`,
    /// routing the edit through `gateway` as one ordered unit. Replacement reuses
    /// `MonaReplacePattern` (capture-group substitution for RegExp queries).
    /// Returns the reconciliation outcome. A no-op after `dispose()` (returns
    /// `.dropped`); returns `.dropped` when no match is found.
    @discardableResult
    public func replaceNext(
        in model: MonaCodeModel,
        query: MonaFindQuery,
        replaceString: String,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let haystack = Array(model.getValue().utf16)
        guard let first = rawMatches(haystack: haystack, query: query, from: 0).first else {
            return .dropped(reason: "no match")
        }
        let range = MonaRange(
            startPosition: model.getPositionAt(first.startOffset),
            endPosition: model.getPositionAt(first.endOffset)
        )
        let replacement = replacementText(
            haystack: haystack,
            match: first,
            replaceString: replaceString
        )
        let transaction = gateway.beginTransaction()
        transaction.prepareEdit(MonaModelEditOperation(range: range, text: replacement))
        return gateway.commit(transaction)
    }

    /// Replaces every match of `query` in `model` with `replaceString`, routing
    /// the edits through `gateway` as one ordered unit. Replacement reuses
    /// `MonaReplacePattern` (capture-group substitution for RegExp queries).
    /// The model applies the batch in descending start-offset order so earlier
    /// ranges stay valid. Returns the reconciliation outcome. A no-op after
    /// `dispose()` (returns `.dropped`).
    @discardableResult
    public func replaceAll(
        in model: MonaCodeModel,
        query: MonaFindQuery,
        replaceString: String,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let haystack = Array(model.getValue().utf16)
        let matches = rawMatches(haystack: haystack, query: query, from: 0)
        let ops: [MonaModelEditOperation] = matches.map { match in
            let range = MonaRange(
                startPosition: model.getPositionAt(match.startOffset),
                endPosition: model.getPositionAt(match.endOffset)
            )
            let replacement = replacementText(
                haystack: haystack,
                match: match,
                replaceString: replaceString
            )
            return MonaModelEditOperation(range: range, text: replacement)
        }
        let transaction = gateway.beginTransaction()
        if !ops.isEmpty {
            transaction.prepareEdits(ops)
        }
        return gateway.commit(transaction)
    }

    /// Records `string` in the search history (most-recent-first, de-duplicated,
    /// capped at the history limit). A no-op after `dispose()`.
    public func recordSearchHistory(_ string: String) {
        guard !isDisposed, !string.isEmpty else { return }
        _lock.lock()
        _searchHistory = Self.prepend(_searchHistory, string, limit: Self.historyLimit)
        _lock.unlock()
    }

    /// Records `string` in the replace history (most-recent-first,
    /// de-duplicated, capped at the history limit). A no-op after `dispose()`.
    public func recordReplaceHistory(_ string: String) {
        guard !isDisposed, !string.isEmpty else { return }
        _lock.lock()
        _replaceHistory = Self.prepend(_replaceHistory, string, limit: Self.historyLimit)
        _lock.unlock()
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `result` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishFindResult(
        _ result: MonaFindResult,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaFindResult) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(result),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, history is cleared, and `findMatches` /
    /// `replaceNext` / `replaceAll` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _searchHistory.removeAll()
        _replaceHistory.removeAll()
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

    /// The plain-text fallback language. find needs no tokenization; it degrades
    /// to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — find performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private: match computation

    /// A unified raw match: start / end UTF-16 offsets plus the capture groups
    /// (for RegExp) used by `MonaReplacePattern`.
    private struct RawMatch {
        let startOffset: Int
        let endOffset: Int
        let captures: [[UInt16]]
        let namedCaptures: [String: [UInt16]]
    }

    /// Resolves the scope's UTF-16 offset bounds. When no scope is supplied (or
    /// `findInSelection` is `false`), the bounds span the whole haystack.
    private func scopeOffsets(
        model: MonaCodeModel,
        scope: MonaRange?,
        haystack: [UInt16]
    ) -> (start: Int, end: Int) {
        guard queryScopeActive(scope: scope) else {
            return (0, haystack.count)
        }
        let s = model.getOffsetAt(scope!.startPosition)
        let e = model.getOffsetAt(scope!.endPosition)
        return (max(0, s), min(haystack.count, e))
    }

    /// `true` when a scope range is supplied and should bound the search.
    private func queryScopeActive(scope: MonaRange?) -> Bool {
        return scope != nil
    }

    /// Runs the literal or RegExp search and returns the raw matches in
    /// ascending start-offset order.
    private func rawMatches(
        haystack: [UInt16],
        query: MonaFindQuery,
        from: Int
    ) -> [RawMatch] {
        if query.isRegex {
            return regExpMatches(haystack: haystack, query: query, from: from)
        }
        return literalMatches(haystack: haystack, query: query, from: from)
    }

    /// Literal path: reuses `MonaLiteralSearch` (P02-T003).
    private func literalMatches(
        haystack: [UInt16],
        query: MonaFindQuery,
        from: Int
    ) -> [RawMatch] {
        let needle = Array(query.searchString.utf16)
        let search = MonaLiteralSearch(needle: needle, matchCase: query.matchCase)
        return search.findAll(in: haystack, fromOffset: from).map { match in
            RawMatch(
                startOffset: match.startOffset,
                endOffset: match.endOffset,
                captures: [],
                namedCaptures: [:]
            )
        }
    }

    /// RegExp path: reuses `MonaRegExpParser` / `MonaRegExpExecutor` (P02-T004)
    /// via `monaRegExpCompile`.
    private func regExpMatches(
        haystack: [UInt16],
        query: MonaFindQuery,
        from: Int
    ) -> [RawMatch] {
        let flags = query.matchCase ? "g" : "gi"
        guard let program = try? monaRegExpCompile(query.searchString, flags: flags) else {
            return []
        }
        let executor = MonaRegExpExecutor(program: program)
        guard let matches = try? executor.findAll(in: haystack, from: from) else {
            return []
        }
        return matches.map { match in
            let caps: [[UInt16]] = match.captures.dropFirst().map { cap in
                if cap.start >= 0 && cap.end >= 0 && cap.end <= haystack.count {
                    return Array(haystack[cap.start..<cap.end])
                }
                return []
            }
            let named: [String: [UInt16]] = match.namedCaptures.mapValues { cap in
                if cap.start >= 0 && cap.end >= 0 && cap.end <= haystack.count {
                    return Array(haystack[cap.start..<cap.end])
                }
                return []
            }
            return RawMatch(
                startOffset: match.startOffset,
                endOffset: match.endOffset,
                captures: caps,
                namedCaptures: named
            )
        }
    }

    /// Computes the replacement text for `match` using `MonaReplacePattern`
    /// (P02-T003), substituting the full match and capture groups.
    private func replacementText(
        haystack: [UInt16],
        match: RawMatch,
        replaceString: String
    ) -> String {
        let fullMatch = Array(haystack[match.startOffset..<match.endOffset])
        let pattern = MonaReplacePattern(Array(replaceString.utf16))
        let replacement = pattern.apply(
            MonaReplaceMatch(
                fullMatch: fullMatch,
                captures: match.captures,
                namedCaptures: match.namedCaptures
            )
        )
        return String(decoding: replacement, as: UTF16.self)
    }

    /// Returns `true` when the substring `[start, end)` is bounded by non-word
    /// characters (or string boundaries) — Monaco's default whole-word check.
    private func isWholeWord(haystack: [UInt16], start: Int, end: Int) -> Bool {
        let beforeIsBoundary = (start == 0) || !Self.isWordUnit(haystack[start - 1])
        let afterIsBoundary = (end == haystack.count) || !Self.isWordUnit(haystack[end])
        return beforeIsBoundary && afterIsBoundary
    }

    /// Returns `true` when `unit` is a word character: ASCII letter, digit, or
    /// underscore (Monaco's default word definition for the simple case).
    private static func isWordUnit(_ unit: UInt16) -> Bool {
        if unit >= 0x0061 && unit <= 0x007A { return true }  // a-z
        if unit >= 0x0041 && unit <= 0x005A { return true }  // A-Z
        if unit >= 0x0030 && unit <= 0x0039 { return true }  // 0-9
        if unit == 0x005F { return true }                    // _
        return false
    }

    /// Prepends `entry` to `history` (most-recent-first), removing any earlier
    /// duplicate and capping at `limit`.
    private static func prepend(_ history: [String], _ entry: String, limit: Int) -> [String] {
        var result = [entry] + history.filter { $0 != entry }
        if result.count > limit {
            result = Array(result.prefix(limit))
        }
        return result
    }

    // MARK: - Private: events

    /// Fires a find event when not disposed.
    private func fire(_ result: MonaFindResult) {
        guard !isDisposed else { return }
        emitter.fire(MonaFindEvent(result: result))
    }
}
