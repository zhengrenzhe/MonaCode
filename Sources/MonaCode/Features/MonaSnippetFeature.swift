// MonaSnippetFeature.swift
//
// P05-T151 — Implement retained feature snippet.
//
// `MonaSnippetFeature` is the Swift counterpart of Monaco's `snippet`
// contribution (monaco-editor 0.56.0, registered as `snippetController2`): it
// inserts a snippet session and navigates its tab stops / placeholders, routing
// the snippet parse + expand to a Phase 06 snippet-engine attachment point (a
// protocol the engine will implement) — exactly like `diffEditor` (P05-T112)
// registers its command slice over the Phase 07 diff slots.
//
// The Phase 06 snippet engine is NOT built yet (Phase 06 comes after Phase 05).
// This feature defines the snippet-session surface — insert / navigate
// (next / previous tabstop) / leave / release — and routes the snippet parse +
// expand through `MonaSnippetEngineAttachment`, the attachment point the Phase
// 06 engine will implement. When no engine is attached, the feature degrades to
// a single final tabstop at the insertion point (the plain-text fallback). The
// session logic (tabstop retention, navigation, disposal) works against the
// attachment point today; the real engine arrives in Phase 06.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `insertSnippet`, `moveToNextTabstop`,
//      `moveToPreviousTabstop`, `leaveSnippet`, `releaseSession`, all keyed by
//      snippet-session id and routed through `MonaSnippetEngineAttachment`.
//   2. Register the exact feature identity `snippet` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A placeholder inside a snippet tab stop: an index (0 = final tab stop), an
/// optional label, the choice values (when the placeholder is a choice), and the
/// range the placeholder spans within the snippet text. Mirrors Monaco's
/// snippet placeholder / choice concepts (monaco-editor 0.56.0).
public struct MonaSnippetPlaceholder: Equatable {

    /// The tab-stop index this placeholder belongs to (0 = final tab stop).
    public let index: Int

    /// The optional placeholder label (e.g. a variable name).
    public let label: String?

    /// The choice values when the placeholder is a choice (`${1|a,b,c|}`).
    public let choices: [String]

    /// The range the placeholder spans within the snippet text.
    public let rangeInSnippet: MonaRange

    public init(index: Int, label: String? = nil, choices: [String] = [], rangeInSnippet: MonaRange) {
        self.index = index
        self.label = label
        self.choices = choices
        self.rangeInSnippet = rangeInSnippet
    }
}

/// A snippet tab stop: an ordinal (0 = final tab stop), the range it occupies in
/// model coordinates after the snippet is inserted, and the placeholders it
/// carries. Mirrors Monaco's `OneSnippet` tab-stop concept (monaco-editor 0.56.0).
public struct MonaSnippetSessionTabstop: Equatable {

    /// The tab-stop ordinal. `0` is the final tab stop (the cursor lands here
    /// when the session ends); `1`, `2`, … are traversed in order.
    public let index: Int

    /// The range the tab stop occupies in model coordinates after insertion.
    public let range: MonaRange

    /// The placeholders this tab stop carries.
    public let placeholders: [MonaSnippetPlaceholder]

    public init(index: Int, range: MonaRange, placeholders: [MonaSnippetPlaceholder] = []) {
        self.index = index
        self.range = range
        self.placeholders = placeholders
    }
}

/// A snippet session: the inserted snippet's identity, model version, insert
/// range, tab stops, the current tab-stop index, and the last insert outcome.
public struct MonaSnippetSession: Equatable {

    /// The session id (a UUID string).
    public let id: String

    /// The model version the session was inserted against.
    public let modelVersion: Int

    /// The range the snippet text was inserted at (zero-width before insertion).
    public let insertRange: MonaRange

    /// The tab stops parsed from the snippet, in traversal order.
    public let tabstops: [MonaSnippetSessionTabstop]

    /// The current tab-stop index into `tabstops` (0-based). `-1` after the
    /// session is left.
    public var currentIndex: Int

    /// The reconciliation outcome of the last insert edit (`.applied` on a
    /// successful commit through `MonaTransactionGateway`).
    public let lastInsertOutcome: MonaReconciliationOutcome

    public init(
        id: String,
        modelVersion: Int,
        insertRange: MonaRange,
        tabstops: [MonaSnippetSessionTabstop],
        currentIndex: Int,
        lastInsertOutcome: MonaReconciliationOutcome
    ) {
        self.id = id
        self.modelVersion = modelVersion
        self.insertRange = insertRange
        self.tabstops = tabstops
        self.currentIndex = currentIndex
        self.lastInsertOutcome = lastInsertOutcome
    }
}

/// A snippet-session event: the session id and the current tab-stop index.
public struct MonaSnippetSessionEvent: Equatable {

    /// The session id the event concerns.
    public let sessionId: String

    /// The current tab-stop index after the change (`-1` when the session was
    /// left).
    public let currentIndex: Int

    public init(sessionId: String, currentIndex: Int) {
        self.sessionId = sessionId
        self.currentIndex = currentIndex
    }
}

/// The Phase 06 snippet-engine attachment point. The real snippet engine
/// (Phase 06) implements this protocol; this feature routes snippet parsing and
/// expansion through it. When no engine is attached, the feature degrades to a
/// single final-tabstop session (the plain-text fallback).
///
/// This is the snippet counterpart of the Phase 07 diff slot
/// (`MonaEditorFactory.createDiffEditor`): the session logic works against the
/// attachment point today, and the real engine arrives in Phase 06.
public protocol MonaSnippetEngineAttachment: AnyObject {

    /// Parses `text` into tab stops placed relative to `insertRange` (the
    /// zero-width range the snippet was inserted at, in model coordinates). The
    /// returned tab stops are in traversal order.
    func parseSnippet(_ text: String, insertRange: MonaRange) -> [MonaSnippetSessionTabstop]

    /// Expands `text` (resolves placeholders / choices / variables) and returns
    /// the text to commit through `MonaTransactionGateway`.
    func expandSnippet(_ text: String) -> String
}

/// The snippet feature: insert and navigate snippet sessions using the Phase 06
/// snippet engine.
///
/// The feature identity `snippet` and its declared slice are referenced verbatim
/// from the frozen registries. Inserting a snippet expands the snippet text
/// through `MonaSnippetEngineAttachment` (or the plain-text fallback) and commits
/// the insert edit through `MonaTransactionGateway`; the engine then parses the
/// tab stops and the feature navigates them (`moveToNextTabstop` /
/// `moveToPreviousTabstop` / `leaveSnippet`), retaining the session keyed by id
/// so a disposed session's slice can be released. Asynchronous publication is
/// routed through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaSnippetFeature: MonaDisposable {

    /// The frozen feature identity (`"snippet"`).
    public static let featureId = "snippet"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). snippet
    /// declares no labeled editor actions — its commands carry no action labels.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order (alphabetical, no rename /
    /// coalesce). The four snippet-session commands: accept, next / previous
    /// placeholder, and leave.
    public static let declaredCommandIds: [String] = [
        "acceptSnippet",
        "jumpToNextSnippetPlaceholder",
        "jumpToPrevSnippetPlaceholder",
        "leaveSnippet"
    ]

    /// The declared contribution ID (`snippetController2`).
    public static let declaredContributionIds: [String] = [
        "snippetController2"
    ]

    /// The declared keybinding commands — the three snippet commands that carry
    /// a default keybinding in `MonaBuiltinKeybindings`. `acceptSnippet` carries
    /// no default keybinding.
    public static let declaredKeybindingCommands: [String] = [
        "jumpToNextSnippetPlaceholder",
        "jumpToPrevSnippetPlaceholder",
        "leaveSnippet"
    ]

    /// The declared option names — the two snippet options: `snippetSuggestions`
    /// (how snippets appear in the suggest widget) and `stickyTabStops` (whether
    /// tab stops remain sticky after a snippet session ends).
    public static let declaredOptionIds: [String] = [
        "snippetSuggestions",
        "stickyTabStops"
    ]

    /// The declared menu IDs — snippet registers no menu items in any builtin
    /// menu, so this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The retained snippet sessions by session id.
    private var sessions: [String: MonaSnippetSession] = [:]

    /// The currently active session id (the last inserted / navigated session).
    private var _activeSessionId: String?

    private let emitter = MonaEmitter<MonaSnippetSessionEvent>()

    /// The event stream for snippet-session changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaSnippetSessionEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the snippet feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The active session id, or `nil` when no session is active (or after
    /// disposal).
    public var activeSessionId: String? {
        _lock.lock(); defer { _lock.unlock() }
        return _activeSessionId
    }

    // MARK: - 1. Feature-specific behavior: insert / navigate / leave / release

    /// Inserts a snippet session at `position`: expands `text` through `engine`
    /// (or the plain-text fallback when `engine` is `nil`), commits the insert
    /// edit through `gateway` as one ordered unit, parses the tab stops through
    /// `engine` (or a single final tabstop when `engine` is `nil`), retains the
    /// session keyed by id, and stages it as the active session. Fires an event
    /// with the session id and the initial tab-stop index (0). Returns the
    /// session, or `nil` after `dispose()`.
    @discardableResult
    public func insertSnippet(
        _ text: String,
        at position: MonaPosition,
        modelVersion: Int,
        gateway: MonaTransactionGateway,
        engine: MonaSnippetEngineAttachment? = nil
    ) -> MonaSnippetSession? {
        guard !isDisposed else { return nil }
        let insertRange = MonaRange(startPosition: position, endPosition: position)
        let expandedText = engine?.expandSnippet(text) ?? text
        let transaction = gateway.beginTransaction()
        transaction.prepareEdit(MonaModelEditOperation(range: insertRange, text: expandedText))
        let outcome = gateway.commit(transaction)
        let tabstops = engine?.parseSnippet(text, insertRange: insertRange) ?? [
            MonaSnippetSessionTabstop(index: 0, range: insertRange, placeholders: [])
        ]
        let session = MonaSnippetSession(
            id: UUID().uuidString,
            modelVersion: modelVersion,
            insertRange: insertRange,
            tabstops: tabstops,
            currentIndex: 0,
            lastInsertOutcome: outcome
        )
        _lock.lock()
        sessions[session.id] = session
        _activeSessionId = session.id
        _lock.unlock()
        fire(.init(sessionId: session.id, currentIndex: 0))
        return session
    }

    /// The retained session for `sessionId`, or `nil` when no session is
    /// retained with that id (or after disposal).
    public func session(for sessionId: String) -> MonaSnippetSession? {
        _lock.lock(); defer { _lock.unlock() }
        return sessions[sessionId]
    }

    /// The current tab stop for `sessionId`, or `nil` when the session has no
    /// retained tab stops (or after disposal).
    public func currentTabstop(for sessionId: String) -> MonaSnippetSessionTabstop? {
        _lock.lock(); defer { _lock.unlock() }
        guard let session = sessions[sessionId] else { return nil }
        guard session.currentIndex >= 0, session.currentIndex < session.tabstops.count else {
            return nil
        }
        return session.tabstops[session.currentIndex]
    }

    /// Advances to the next tab stop for `sessionId`. Returns the new tab-stop
    /// index, or `nil` when the session is already at the last tab stop (the
    /// caller should leave the session). A no-op (returns `nil`) after `dispose()`
    /// or when the session is unknown.
    @discardableResult
    public func moveToNextTabstop(sessionId: String) -> Int? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard var session = sessions[sessionId] else {
            _lock.unlock()
            return nil
        }
        guard session.currentIndex < session.tabstops.count - 1 else {
            _lock.unlock()
            return nil
        }
        session.currentIndex += 1
        sessions[sessionId] = session
        let newIndex = session.currentIndex
        _lock.unlock()
        fire(.init(sessionId: sessionId, currentIndex: newIndex))
        return newIndex
    }

    /// Moves to the previous tab stop for `sessionId`. Returns the new tab-stop
    /// index, or `nil` when the session is already at the first tab stop. A
    /// no-op (returns `nil`) after `dispose()` or when the session is unknown.
    @discardableResult
    public func moveToPreviousTabstop(sessionId: String) -> Int? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard var session = sessions[sessionId] else {
            _lock.unlock()
            return nil
        }
        guard session.currentIndex > 0 else {
            _lock.unlock()
            return nil
        }
        session.currentIndex -= 1
        sessions[sessionId] = session
        let newIndex = session.currentIndex
        _lock.unlock()
        fire(.init(sessionId: sessionId, currentIndex: newIndex))
        return newIndex
    }

    /// Leaves the snippet session for `sessionId` (exits snippet mode): clears
    /// the active session id and fires an event with `currentIndex = -1`.
    /// Returns `true` when the session existed, `false` otherwise. A no-op
    /// (returns `false`) after `dispose()`.
    @discardableResult
    public func leaveSnippet(sessionId: String) -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        let existed = sessions[sessionId] != nil
        if _activeSessionId == sessionId {
            _activeSessionId = nil
        }
        if var session = sessions[sessionId] {
            session.currentIndex = -1
            sessions[sessionId] = session
        }
        _lock.unlock()
        if existed {
            fire(.init(sessionId: sessionId, currentIndex: -1))
        }
        return existed
    }

    /// Releases the retained session for `sessionId` (the editor instance has
    /// been disposed). Returns `1` when a session was released, `0` otherwise.
    /// After `dispose()`, returns `0`.
    @discardableResult
    public func releaseSession(sessionId: String) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        let removed = sessions.removeValue(forKey: sessionId) != nil
        if _activeSessionId == sessionId {
            _activeSessionId = nil
        }
        return removed ? 1 : 0
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `session` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishSnippetSession(
        _ session: MonaSnippetSession,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaSnippetSession) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(session),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained sessions are released, the
    /// active session is cleared, and `insertSnippet` / `moveToNextTabstop` /
    /// `moveToPreviousTabstop` / `leaveSnippet` / `releaseSession` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        sessions.removeAll()
        _activeSessionId = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. snippet declares no actions,
    /// so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. snippet needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — snippet performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a snippet-session event when not disposed.
    private func fire(_ event: MonaSnippetSessionEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
