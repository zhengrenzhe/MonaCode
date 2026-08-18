// MonaSemanticTokensFeature.swift
//
// P05-T149 — Implement retained feature semanticTokens.
//
// `MonaSemanticTokensFeature` is the Swift counterpart of Monaco's
// `semanticTokens` contribution (monaco-editor 0.56.0, registered as
// `editor.contrib.viewportSemanticTokens`): it applies full and delta
// semantic-token results by version and result identifier, retaining the
// current token set for the viewport.
//
// Version gating: every full / delta result carries the model version it was
// requested against. A result is applied ONLY when its version is at least the
// retained version — a stale response (version < currentVersion) is dropped
// silently. This mirrors Monaco's `SemanticTokensStylingService`, which
// discards responses for moved models.
//
// Result-identifier gating: a delta result builds on a prior full result. The
// delta's `previousResultId` MUST match the retained `currentResultId`; a
// mismatched delta is dropped silently (the server's delta is for a different
// base than what the client holds). This mirrors Monaco's resultId contract.
//
// The four provider-execute commands (`_provideDocumentSemanticTokens`,
// `_provideDocumentSemanticTokensLegend`, `_provideDocumentRangeSemanticTokens`,
// `_provideDocumentRangeSemanticTokensLegend`) are the internal commands the
// viewport contribution registers to drive the document / range semantic-token
// providers.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `applyFull(_:version:)`,
//      `applyDelta(_:version:)`, `reset()`, `currentTokens` / `currentResultId`
//      / `currentVersion`, and `commitRetainedTokens(version:gateway:)`.
//   2. Register the exact feature identity `semanticTokens` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// The semantic-token legend: the token type and modifier vocabularies the
/// provider uses to encode tokens. Mirrors Monaco's `SemanticTokensLegend`
/// (monaco-editor 0.56.0).
public struct MonaSemanticTokenLegend: Equatable {

    /// The token types, indexed by the first entry of each token's 5-tuple.
    public let tokenTypes: [String]

    /// The token modifiers, indexed by the bitmask in the third entry of each
    /// token's 5-tuple.
    public let tokenModifiers: [String]

    public init(tokenTypes: [String], tokenModifiers: [String]) {
        self.tokenTypes = tokenTypes
        self.tokenModifiers = tokenModifiers
    }
}

/// A full semantic-token result: the flattened token data and an optional
/// result identifier. Mirrors Monaco's `SemanticTokens` (monaco-editor 0.56.0).
public struct MonaSemanticTokensData: Equatable {

    /// The flattened token data (5 integers per token: deltaLine, deltaStart,
    /// length, tokenType, tokenModifiers).
    public let data: [Int]

    /// The result identifier the server assigned to this result, or `nil` when
    /// the server does not support delta requests.
    public let resultId: String?

    public init(data: [Int], resultId: String? = nil) {
        self.data = data
        self.resultId = resultId
    }
}

/// A single delta edit: delete `deleteCount` integers starting at `start`, then
/// insert `data`. Mirrors Monaco's `SemanticTokensEdit` (monaco-editor 0.56.0).
public struct MonaSemanticTokensEdit: Equatable {

    /// The offset in the flattened data array where the edit begins.
    public let start: Int

    /// The number of integers to delete starting at `start`.
    public let deleteCount: Int

    /// The integers to insert at `start` (after the deletion).
    public let data: [Int]

    public init(start: Int, deleteCount: Int, data: [Int]) {
        self.start = start
        self.deleteCount = deleteCount
        self.data = data
    }
}

/// A delta semantic-token result: the new result identifier, the result
/// identifier it deltas from, and the edits. Mirrors Monaco's
/// `SemanticTokensDelta` (monaco-editor 0.56.0), with an explicit
/// `previousResultId` so result-identifier gating is observable.
public struct MonaSemanticTokensDelta: Equatable {

    /// The new result identifier assigned to the result after the delta.
    public let resultId: String

    /// The result identifier the delta was requested against (the client's
    /// retained resultId at request time). The delta is applied ONLY when this
    /// matches the feature's `currentResultId`.
    public let previousResultId: String

    /// The edits to apply to the retained data.
    public let edits: [MonaSemanticTokensEdit]

    public init(resultId: String, previousResultId: String, edits: [MonaSemanticTokensEdit]) {
        self.resultId = resultId
        self.previousResultId = previousResultId
        self.edits = edits
    }
}

/// A semantic-tokens event: the retained result after a change (or `nil` after
/// `reset()` / `dispose()`).
public struct MonaSemanticTokensEvent: Equatable {

    /// The retained result, or `nil` when no result is retained.
    public let result: MonaSemanticTokensData?

    public init(result: MonaSemanticTokensData?) {
        self.result = result
    }
}

/// The semanticTokens feature: apply full and delta semantic-token results by
/// version and result identifier.
///
/// The feature identity `semanticTokens` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (acknowledging the
/// retained tokens) is routed through `MonaTransactionGateway` (version-gated);
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaSemanticTokensFeature: MonaDisposable {

    /// The frozen feature identity (`"semanticTokens"`).
    public static let featureId = "semanticTokens"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// semanticTokens declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. These are the provider-execute
    /// commands the viewport semantic-tokens contribution registers to drive the
    /// document / range semantic-token providers.
    public static let declaredCommandIds: [String] = [
        "_provideDocumentSemanticTokens",
        "_provideDocumentSemanticTokensLegend",
        "_provideDocumentRangeSemanticTokens",
        "_provideDocumentRangeSemanticTokensLegend"
    ]

    /// The declared contribution ID (`editor.contrib.viewportSemanticTokens`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.viewportSemanticTokens"
    ]

    /// The declared keybinding commands — semanticTokens registers no default
    /// keybindings, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option name — semanticTokens owns no top-level option (the
    /// `semanticTokens` feature is configured through the language provider and
    /// the `editor.semanticTokenColorCustomizations`), so this slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — semanticTokens registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private var _tokens: MonaSemanticTokensData? = nil
    private var _resultId: String? = nil
    private var _version: Int = 0
    private let emitter = MonaEmitter<MonaSemanticTokensEvent>()

    /// The event stream for semantic-token changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaSemanticTokensEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the semanticTokens feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The model version the retained tokens were applied against (0 before any
    /// successful application).
    public var currentVersion: Int {
        _lock.lock(); defer { _lock.unlock() }
        return _version
    }

    /// The retained result identifier, or `nil` when no result is retained (or
    /// the server does not support deltas).
    public var currentResultId: String? {
        _lock.lock(); defer { _lock.unlock() }
        return _resultId
    }

    /// The retained token data, or `nil` before the first successful
    /// application (or after `reset()` / `dispose()`).
    public var currentTokens: MonaSemanticTokensData? {
        _lock.lock(); defer { _lock.unlock() }
        return _tokens
    }

    // MARK: - 1. Feature-specific behavior: apply full / delta by version + resultId

    /// Applies a full semantic-token result. Version-gated: the result is applied
    /// ONLY when `version >= currentVersion`. A stale result (version <
    /// currentVersion) is dropped silently. On application, the retained tokens,
    /// result identifier, and version are updated, and an event is fired.
    /// Returns `true` when applied; `false` when dropped or after `dispose()`.
    @discardableResult
    public func applyFull(_ data: MonaSemanticTokensData, version: Int) -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        if version < _version {
            _lock.unlock()
            return false
        }
        _tokens = data
        _resultId = data.resultId
        _version = version
        let snapshot = data
        _lock.unlock()
        emitter.fire(MonaSemanticTokensEvent(result: snapshot))
        return true
    }

    /// Applies a delta semantic-token result. Version-gated AND result-identifier
    /// gated: the delta is applied ONLY when `version >= currentVersion` AND
    /// `delta.previousResultId` matches the retained `currentResultId` AND a
    /// prior full result exists. On application, the edits are applied to the
    /// retained data, the result identifier advances to `delta.resultId`, the
    /// version is updated, and an event is fired. Returns `true` when applied;
    /// `false` when dropped or after `dispose()`.
    @discardableResult
    public func applyDelta(_ delta: MonaSemanticTokensDelta, version: Int) -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        if version < _version {
            _lock.unlock()
            return false
        }
        guard let currentResult = _resultId, currentResult == delta.previousResultId,
              let currentData = _tokens else {
            _lock.unlock()
            return false
        }
        let merged = Self.applyEdits(delta.edits, to: currentData.data)
        let updated = MonaSemanticTokensData(data: merged, resultId: delta.resultId)
        _tokens = updated
        _resultId = delta.resultId
        _version = version
        let snapshot = updated
        _lock.unlock()
        emitter.fire(MonaSemanticTokensEvent(result: snapshot))
        return true
    }

    /// Clears the retained tokens, result identifier, and version. A no-op after
    /// `dispose()`. Fires an event with a `nil` result.
    public func reset() {
        guard !isDisposed else { return }
        _lock.lock()
        _tokens = nil
        _resultId = nil
        _version = 0
        _lock.unlock()
        emitter.fire(MonaSemanticTokensEvent(result: nil))
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Acknowledges the retained tokens through the shared transaction gateway,
    /// version-gated: begins a transaction and commits it (no text edits —
    /// semantic tokens are overlay data, not model text). Returns `.applied`
    /// when `version == currentVersion`; `.dropped(reason: "stale version")`
    /// when `version != currentVersion`; `.dropped(reason: "disposed")` after
    /// `dispose()`.
    @discardableResult
    public func commitRetainedTokens(
        version: Int,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        _lock.lock()
        let current = _version
        _lock.unlock()
        guard version == current else { return .dropped(reason: "stale version") }
        let transaction = gateway.beginTransaction()
        // No edits: semantic tokens are overlay data. The transaction commits as
        // an acknowledged unit through the gateway (version truth + selections).
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `data` through the shared provider executor, normalized onto the
    /// deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishSemanticTokens(
        _ data: MonaSemanticTokensData,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaSemanticTokensData) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(data),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the retained tokens are cleared, and
    /// `applyFull` / `applyDelta` / `reset` / `commitRetainedTokens` /
    /// `publishSemanticTokens` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _tokens = nil
        _resultId = nil
        _version = 0
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. semanticTokens declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. semanticTokens needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — semanticTokens performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Delta edit application

    /// Applies `edits` to `data` in order: for each edit, delete `deleteCount`
    /// integers starting at `start`, then insert `data`. Pure function.
    private static func applyEdits(
        _ edits: [MonaSemanticTokensEdit],
        to data: [Int]
    ) -> [Int] {
        var buffer = data
        for edit in edits {
            let start = max(0, min(edit.start, buffer.count))
            let deleteCount = max(0, min(edit.deleteCount, buffer.count - start))
            buffer.removeSubrange(start..<(start + deleteCount))
            buffer.insert(contentsOf: edit.data, at: start)
        }
        return buffer
    }
}
