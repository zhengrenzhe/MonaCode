// MonaLinkedEditingFeature.swift
//
// P05-T135 — Implement retained feature linkedEditing.
//
// `MonaLinkedEditingFeature` is the Swift counterpart of Monaco's
// `linkedEditing` contribution (monaco-editor 0.56.0): it mirrors edits across
// linked-editing ranges provided by a `MonaLinkedEditingRangeProvider`, under
// provider-version and cancellation gates. Starting a session asks the provider
// for the linked ranges at a position; the result is published through the
// shared `MonaProviderExecutor` (which validates a `MonaAsyncValidityTicket`
// immediately before publication — the version gate) and may be gated by a
// `MonaCancellationToken` (the cancellation gate). Once a session is retained,
// `mirrorEdit(text:gateway:)` replaces every linked range with `text` in one
// transactional batch through `MonaTransactionGateway`.
//
// Under the degraded plain-text path (no language provider is registered in
// Foundation-only Core), no `MonaLinkedEditingRangeProvider` is registered, so
// `startLinkedEditing` publishes no ranges and the feature stays inert — the
// degradation is graceful, not an error.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `startLinkedEditing`, `mirrorEdit`,
//      `stopLinkedEditing`, all gated by the publication ticket + cancellation
//      token and committed through `MonaTransactionGateway`.
//   2. Register the exact feature identity `linkedEditing` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A linked-editing event kind: whether a session was started, an edit was
/// mirrored, or the session was stopped.
public enum MonaLinkedEditingKind: String, Equatable {

    /// A linked-editing session was started (ranges retained from a provider).
    case started

    /// An edit was mirrored across the active session's linked ranges.
    case mirrored

    /// The linked-editing session was stopped.
    case stopped
}

/// A linked-editing event: the kind and the affected ranges.
public struct MonaLinkedEditingEvent: Equatable {

    /// The kind that fired.
    public let kind: MonaLinkedEditingKind

    /// The linked ranges the event covers (empty for `.stopped`).
    public let ranges: [MonaRange]

    public init(kind: MonaLinkedEditingKind, ranges: [MonaRange]) {
        self.kind = kind
        self.ranges = ranges
    }
}

/// A set of linked-editing ranges: the word range at the trigger position and
/// the full list of ranges to mirror edits across.
public struct MonaLinkedEditingRanges: Equatable {

    /// The ranges to mirror edits across (includes the trigger word's range).
    public let ranges: [MonaRange]

    /// The word range at the trigger position (the range of the token under the
    /// cursor when linked editing started).
    public let wordRange: MonaRange

    public init(ranges: [MonaRange], wordRange: MonaRange) {
        self.ranges = ranges
        self.wordRange = wordRange
    }
}

/// A linked-editing range provider — the Swift counterpart of Monaco's
/// `LinkedEditingRangeProvider`. Returns the linked ranges for `position`, or
/// `nil` when no linked ranges exist.
///
/// The result is published through `MonaProviderExecutor`, so a provider may
/// return its result in any of the seven normalized shapes (synchronous,
/// asynchronous, optional, throwing, cancelable, resolvable, releasable). The
/// `token` is the cancellation gate: a provider that performs async work should
/// observe it and short-circuit when cancellation is requested.
public protocol MonaLinkedEditingRangeProvider {

    /// Returns the linked-editing ranges for `position` in `model`, gated by
    /// `token`.
    func provideLinkedEditingRanges(
        at position: MonaPosition,
        model: MonaCodeModel,
        token: MonaCancellationToken
    ) -> MonaProviderResult<MonaLinkedEditingRanges?>
}

/// The linked-editing feature: mirror edits across linked ranges under provider
/// version and cancellation gates.
///
/// The feature identity `linkedEditing` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication (including the provider
/// result) through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal
/// through `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaLinkedEditingFeature: MonaDisposable {

    /// The frozen feature identity (`"linkedEditing"`).
    public static let featureId = "linkedEditing"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single linked-editing action: `editor.action.linkedEditing` (ordinal
    /// 138, "Start Linked Editing").
    public static let declaredActionIds: [String] = [
        "editor.action.linkedEditing"
    ]

    /// The declared command IDs in source order. The linked-editing action is
    /// also registered as an editor command, so this slice equals
    /// `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution ID. The linked-editing controller — the single
    /// linked-editing contribution (ordinal 32).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.linkedEditing"
    ]

    /// The declared keybinding commands — the single linked-editing action that
    /// carries a default keybinding in `MonaBuiltinKeybindings`
    /// (`Cmd+Shift+F2`).
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.linkedEditing"
    ]

    /// The declared option names — the `linkedEditing` editor option and its
    /// deprecated alias `renameOnType` (the F1-R3 manifest records
    /// `renameOnType` as deprecated in favor of `#editor.linkedEditing#`).
    public static let declaredOptionIds: [String] = [
        "linkedEditing",
        "renameOnType"
    ]

    /// The declared menu IDs — linkedEditing registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaLinkedEditingEvent>()

    /// The event stream for linked-editing changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaLinkedEditingEvent> { emitter.event }

    private var _isDisposed = false
    private var currentSession: MonaLinkedEditingRanges? = nil
    private let _lock = NSLock()

    /// Creates the linked-editing feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// `true` when a linked-editing session is currently retained.
    public var hasActiveSession: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return currentSession != nil
    }

    // MARK: - 1. Feature-specific behavior: mirror linked-editing ranges

    /// Starts a linked-editing session at `position`, asking `provider` for the
    /// linked ranges. The provider's result is published through the shared
    /// `executor`, normalized onto the deterministic microtask queue with
    /// `ticket` validated immediately before publication (the version gate) and
    /// `token` available as the cancellation gate.
    ///
    /// `receive` runs ONLY when the queue is drained (FIFO), after the ticket is
    /// validated and the cancellation gate has not suppressed publication. When
    /// the result carries non-nil ranges, they are retained as the active
    /// session. Returns `true` when the result was accepted onto the publication
    /// path (enqueued / armed); `false` when the shape normalized to "no value
    /// to publish" (a nil optional or an already-cancelled token). Returns
    /// `false` after `dispose()`.
    @discardableResult
    public func startLinkedEditing(
        at position: MonaPosition,
        provider: MonaLinkedEditingRangeProvider,
        model: MonaCodeModel,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        token: MonaCancellationToken,
        receive: @escaping (MonaLinkedEditingRanges?) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        let result = provider.provideLinkedEditingRanges(
            at: position,
            model: model,
            token: token
        )
        return executor.publish(result, ticket: ticket) { [weak self] ranges in
            self?.retainSession(ranges)
            receive(ranges)
        }
    }

    /// Mirrors `text` across every range in the active linked-editing session,
    /// committed as one transactional batch through `gateway`. Returns `.dropped`
    /// when no session is active, after `dispose()`, or when the session has no
    /// ranges. Fires a `.mirrored` event on a successful application.
    @discardableResult
    public func mirrorEdit(
        text: String,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        _lock.lock()
        let session = currentSession
        _lock.unlock()
        guard let session = session, !session.ranges.isEmpty else {
            return .dropped(reason: "no active session")
        }
        let ops = session.ranges.map {
            MonaModelEditOperation(range: $0, text: text)
        }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits(ops)
        let outcome = gateway.commit(transaction)
        if case .applied = outcome {
            fire(.init(kind: .mirrored, ranges: session.ranges))
        }
        return outcome
    }

    /// Stops the active linked-editing session, releasing the retained ranges.
    /// Idempotent: a second call is a no-op. A no-op after `dispose()`.
    public func stopLinkedEditing() {
        _lock.lock()
        let hadSession = currentSession != nil
        currentSession = nil
        let disposed = _isDisposed
        _lock.unlock()
        guard !disposed, hadSession else { return }
        fire(.init(kind: .stopped, ranges: []))
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishLinkedEditingEvent(
        _ event: MonaLinkedEditingEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaLinkedEditingEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the active session is released, and
    /// `startLinkedEditing` / `mirrorEdit` are no-ops (return `false` /
    /// `.dropped`).
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        currentSession = nil
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

    /// The plain-text fallback language. linkedEditing performs no
    /// tokenization-dependent work (the provider decides the ranges); it
    /// degrades gracefully to the plain-text fallback when no provider is
    /// registered.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — linkedEditing degrades gracefully to the plain-text fallback
    /// when no linked-editing range provider is registered (Foundation-only
    /// Core).
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Retains `ranges` as the active session, firing a `.started` event when
    /// non-nil. Called inside the executor's publication microtask, so the
    /// ticket has already been validated.
    private func retainSession(_ ranges: MonaLinkedEditingRanges?) {
        _lock.lock()
        let disposed = _isDisposed
        if !disposed {
            currentSession = ranges
        }
        let retained = ranges
        _lock.unlock()
        if let r = retained {
            fire(.init(kind: .started, ranges: r.ranges))
        }
    }

    /// Fires a linked-editing event when not disposed.
    private func fire(_ event: MonaLinkedEditingEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
