// MonaInlayHintsFeature.swift
//
// P05-T127 — Implement retained feature inlayHints.
//
// `MonaInlayHintsFeature` is the Swift counterpart of Monaco's `inlayHints`
// contribution (monaco-editor 0.56.0): it requests, resolves, lays out, and
// releases version-gated inlay hints. An inlay hint is a label rendered inline
// at a position, paired with an optional tooltip and optional text edits;
// requesting retains the hints keyed by model version so a stale version's
// results can be released when the model advances, resolving completes a hint's
// payload (with no LSP resolver registered the hint is returned as-is), laying
// out projects the retained hints to position + label layouts for rendering,
// and releasing drops the hints cached for a stale model version.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `requestInlayHints`, `resolveInlayHint`,
//      `layoutInlayHints`, and `releaseInlayHints`, all keyed by model version.
//   2. Register the exact feature identity `inlayHints` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A single edit in an inlay hint: a range to replace + the replacement text.
/// Mirrors Monaco's `InlayHintLabelPart` command edits (monaco-editor 0.56.0).
public struct MonaInlayHintEdit: Equatable {

    /// The range to replace (raw UTF-16 offsets, 1-based line / column).
    public let range: MonaRange

    /// The replacement text (empty string = deletion).
    public let text: String

    public init(range: MonaRange, text: String) {
        self.range = range
        self.text = text
    }
}

/// An inlay hint: a label rendered inline at a position, paired with an optional
/// tooltip and optional text edits. Mirrors Monaco's `InlayHint`
/// (monaco-editor 0.56.0).
public struct MonaInlayHint: Equatable {

    /// The position the hint is anchored at.
    public let position: MonaPosition

    /// The label rendered inline at the position.
    public let label: String

    /// The optional tooltip shown when the hint is hovered, or `nil`.
    public let tooltip: String?

    /// The edits to apply when the hint is resolved / invoked.
    public let edits: [MonaInlayHintEdit]

    public init(position: MonaPosition, label: String, tooltip: String?, edits: [MonaInlayHintEdit] = []) {
        self.position = position
        self.label = label
        self.tooltip = tooltip
        self.edits = edits
    }
}

/// An inlay-hint event: the hints requested / resolved.
public struct MonaInlayHintsEvent: Equatable {

    /// The hints delivered by this event.
    public let hints: [MonaInlayHint]

    public init(hints: [MonaInlayHint]) {
        self.hints = hints
    }
}

/// A laid-out inlay hint: the position + label the renderer projects a retained
/// hint to. Mirrors Monaco's inlay-hint layout projection
/// (monaco-editor 0.56.0).
public struct MonaInlayHintLayout: Equatable {

    /// The position the rendered hint is anchored at.
    public let position: MonaPosition

    /// The label rendered at the position.
    public let label: String

    public init(position: MonaPosition, label: String) {
        self.position = position
        self.label = label
    }
}

/// The inlayHints feature: request, resolve, lay out, and release version-gated
/// inlay hints.
///
/// The feature identity `inlayHints` and its declared slice are referenced
/// verbatim from the frozen registries. Requested hints are retained per model
/// version so a stale version's results can be released when the model
/// advances. Model mutation is routed through `MonaTransactionGateway`;
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaInlayHintsFeature: MonaDisposable {

    /// The frozen feature identity (`"inlayHints"`).
    public static let featureId = "inlayHints"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// inlayHints declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. The inlay-hint command set is
    /// the single provider-execute command.
    public static let declaredCommandIds: [String] = [
        "_executeInlayHintProvider"
    ]

    /// The declared contribution ID (`editor.contrib.InlayHints`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.InlayHints"
    ]

    /// The declared keybinding commands — the inlay-hint commands that carry a
    /// default keybinding. inlayHints declares no default keybindings, so this
    /// slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — the inlay-hint editor option (`inlayHints`,
    /// an object carrying `enabled`, `fontFamily`, `fontSize`, `maximumLength`,
    /// and `padding`).
    public static let declaredOptionIds: [String] = [
        "inlayHints"
    ]

    /// The declared menu IDs — the menus that carry inlay-hint menu items.
    /// inlayHints declares no menu items, so this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The requested inlay hints retained by model version. A stale model
    /// version's hints are released by `releaseInlayHints(modelVersion:)`.
    private var requestedByVersion: [Int: [MonaInlayHint]] = [:]

    private let emitter = MonaEmitter<MonaInlayHintsEvent>()

    /// The event stream for inlay-hint changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaInlayHintsEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the inlayHints feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: request / resolve / lay out / release

    /// Requests `hints` against `modelVersion`, retaining them keyed by model
    /// version so a stale version's results can be released when the model
    /// advances. Fires an event with the requested hints. Returns the requested
    /// hints, or an empty array after `dispose()` (a disposed feature retains
    /// no hints).
    @discardableResult
    public func requestInlayHints(
        _ hints: [MonaInlayHint],
        modelVersion: Int
    ) -> [MonaInlayHint] {
        guard !isDisposed else { return [] }
        _lock.lock()
        requestedByVersion[modelVersion] = hints
        _lock.unlock()
        fire(hints)
        return hints
    }

    /// The number of hints retained for `modelVersion`. Zero when the version
    /// has no retained results (or after disposal).
    public func retainedHintCount(for modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        return requestedByVersion[modelVersion]?.count ?? 0
    }

    /// Resolves an inlay hint. Resolution completes the hint's payload; with no
    /// LSP resolver registered, the hint is returned as-is (its tooltip and
    /// edits are already resolved). Fires an event with the resolved hint.
    /// After `dispose()`, returns the hint unchanged and fires no event.
    @discardableResult
    public func resolveInlayHint(_ hint: MonaInlayHint) -> MonaInlayHint {
        guard !isDisposed else { return hint }
        fire([hint])
        return hint
    }

    /// Lays out the hints retained for `modelVersion`, projecting each to its
    /// position + label for rendering. Returns an empty array when the version
    /// has no retained results (or after disposal).
    public func layoutInlayHints(modelVersion: Int) -> [MonaInlayHintLayout] {
        _lock.lock(); defer { _lock.unlock() }
        guard let hints = requestedByVersion[modelVersion] else { return [] }
        return hints.map { MonaInlayHintLayout(position: $0.position, label: $0.label) }
    }

    /// Releases the requested hints retained for `modelVersion` (the model has
    /// advanced past that version, so the results are stale). Returns the number
    /// of hints released. After `dispose()`, returns `0`.
    @discardableResult
    public func releaseInlayHints(modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        return requestedByVersion.removeValue(forKey: modelVersion)?.count ?? 0
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Commits `hint`'s edits transactionally through `gateway` as one ordered
    /// unit. The edits are prepared on the transaction and committed; the
    /// model's text is mutated only when the transaction applies. Returns the
    /// reconciliation outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitInlayHintEdits(
        _ hint: MonaInlayHint,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        let ops = hint.edits.map { edit in
            MonaModelEditOperation(range: edit.range, text: edit.text)
        }
        if !ops.isEmpty {
            transaction.prepareEdits(ops)
        }
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `hints` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishInlayHints(
        _ hints: [MonaInlayHint],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaInlayHint]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(hints),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained hints are released, and
    /// `requestInlayHints` / `resolveInlayHint` / `layoutInlayHints` /
    /// `releaseInlayHints` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        requestedByVersion.removeAll()
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. inlayHints declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. inlayHints needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — inlayHints performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires an inlay-hints event when not disposed.
    private func fire(_ hints: [MonaInlayHint]) {
        guard !isDisposed else { return }
        emitter.fire(MonaInlayHintsEvent(hints: hints))
    }
}
