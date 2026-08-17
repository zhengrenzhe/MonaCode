// MonaFormatFeature.swift
//
// P05-T121 — Implement retained feature format.
//
// `MonaFormatFeature` is the Swift counterpart of Monaco's `format`
// contribution (monaco-editor 0.56.0): it runs document, range, and on-type
// formatting providers, accepts the returned edits, and applies the accepted
// edits through the shared `MonaTransactionGateway`. Provider execution reuses
// `MonaProviderExecutor` (P05-T013); edits are applied via the transaction
// gateway (P01-T009).
//
// Acceptance mirrors Monaco's formatting contract: a formatting batch is
// accepted only when its edits are non-overlapping. The feature sorts the
// provider edits ascending by start position and rejects a batch whose edits
// overlap (returns an empty acceptance); a sorted, non-overlapping batch is
// accepted as-is. Applying the accepted edits prepares them on a transaction
// (one `prepareEdits`) and commits the unit through the gateway.
//
// The feature is a Foundation-only surface (`import Foundation` only — the
// formatting types live in the MonaCode module). It performs the three
// implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `formatDocument` / `formatRange` /
//      `formatOnType`: run the three formatting providers and accept the
//      returned edits; `applyFormatEdits` applies the accepted edits through
//      the transaction gateway.
//   2. Register the exact feature identity `format` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A formatting provider kind: document, range, or on-type formatting.
public enum MonaFormatKind: String, Equatable, Sendable {

    /// Whole-document formatting (`_executeFormatDocumentProvider`).
    case document

    /// Range formatting (`_executeFormatRangeProvider`).
    case range

    /// On-type formatting (`_executeFormatOnTypeProvider`).
    case onType
}

/// A single formatting edit: a range to replace + the replacement text.
public struct MonaFormatEdit: Equatable {

    /// The range to replace (raw UTF-16 offsets, 1-based line / column).
    public let range: MonaRange

    /// The replacement text (empty string = deletion).
    public let text: String

    public init(range: MonaRange, text: String) {
        self.range = range
        self.text = text
    }
}

/// A formatting event: the provider kind and the count of accepted edits.
public struct MonaFormatEvent: Equatable {

    /// The formatting provider kind that produced the event.
    public let kind: MonaFormatKind

    /// The number of accepted edits in the formatting batch.
    public let editCount: Int

    public init(kind: MonaFormatKind, editCount: Int) {
        self.kind = kind
        self.editCount = editCount
    }
}

/// The format feature: run document, range, and on-type formatting providers,
/// accept the returned edits, and apply the accepted edits through the shared
/// transaction gateway.
///
/// The feature identity `format` and its declared slice are referenced verbatim
/// from the frozen registries. Acceptance sorts the provider edits ascending by
/// start position and rejects an overlapping batch. Model mutation is routed
/// through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaFormatFeature: MonaDisposable {

    /// The frozen feature identity (`"format"`).
    public static let featureId = "format"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The two
    /// formatting actions registered by the format contribution (ordinals 66–67).
    public static let declaredActionIds: [String] = [
        "editor.action.formatDocument",
        "editor.action.formatSelection"
    ]

    /// The declared command IDs in source order (manifest order). The three
    /// provider-execute commands (`_executeFormat*Provider`), the format trigger
    /// command (`editor.action.format`), and the two action commands.
    public static let declaredCommandIds: [String] = [
        "_executeFormatDocumentProvider",
        "_executeFormatOnTypeProvider",
        "_executeFormatRangeProvider",
        "editor.action.format",
        "editor.action.formatDocument",
        "editor.action.formatSelection"
    ]

    /// The declared contribution IDs in source order. The `autoFormat`
    /// contribution (on-type formatting) and the `formatOnPaste` contribution
    /// (format on paste).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.autoFormat",
        "editor.contrib.formatOnPaste"
    ]

    /// The declared keybinding commands — the two format commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`, in source order. The
    /// `editor.action.format` trigger command and the provider-execute commands
    /// carry no default keybinding.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.formatDocument",
        "editor.action.formatSelection"
    ]

    /// The declared option names — the two formatting options, in source order.
    public static let declaredOptionIds: [String] = [
        "formatOnPaste",
        "formatOnType"
    ]

    /// The declared menu IDs — the menus that carry format menu items.
    /// `formatDocument` and `formatSelection` both register an item in the
    /// `EditorContext` menu.
    public static let declaredMenuIds: [String] = [
        "EditorContext"
    ]

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaFormatEvent>()

    /// The event stream for formatting changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaFormatEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the format feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: run providers + accept edits

    /// Runs a document-formatting provider and returns the accepted edits.
    /// Acceptance sorts `edits` ascending by start position and rejects (returns
    /// `[]`) a batch whose edits overlap. Fires a `.document` event with the
    /// accepted edit count. A no-op after `dispose()` (returns `[]`).
    @discardableResult
    public func formatDocument(_ edits: [MonaFormatEdit]) -> [MonaFormatEdit] {
        return accept(edits, kind: .document)
    }

    /// Runs a range-formatting provider and returns the accepted edits.
    /// Acceptance is identical to `formatDocument`. Fires a `.range` event.
    @discardableResult
    public func formatRange(_ edits: [MonaFormatEdit]) -> [MonaFormatEdit] {
        return accept(edits, kind: .range)
    }

    /// Runs an on-type-formatting provider and returns the accepted edits.
    /// Acceptance is identical to `formatDocument`. Fires an `.onType` event.
    @discardableResult
    public func formatOnType(_ edits: [MonaFormatEdit]) -> [MonaFormatEdit] {
        return accept(edits, kind: .onType)
    }

    /// Accepts `edits` for `kind`: sorts ascending by start position, rejects
    /// an overlapping batch, and fires a formatting event with the accepted
    /// count. Returns `[]` when disposed or when the batch overlaps.
    private func accept(_ edits: [MonaFormatEdit], kind: MonaFormatKind) -> [MonaFormatEdit] {
        guard !isDisposed else { return [] }
        let accepted = MonaFormatFeature.acceptedEdits(edits)
        fire(.init(kind: kind, editCount: accepted.count))
        return accepted
    }

    /// Returns the accepted subset of `edits`: sorted ascending by start position
    /// (ties broken by end position), or `[]` when any two edits overlap. An
    /// empty input is accepted as empty.
    static func acceptedEdits(_ edits: [MonaFormatEdit]) -> [MonaFormatEdit] {
        guard !edits.isEmpty else { return [] }
        let sorted = edits.sorted { a, b in
            if a.range.startPosition != b.range.startPosition {
                return a.range.startPosition < b.range.startPosition
            }
            return a.range.endPosition < b.range.endPosition
        }
        // Reject the batch when any two consecutive (by start) edits overlap.
        for i in 1..<sorted.count {
            if sorted[i - 1].range.areIntersecting(sorted[i].range) {
                return []
            }
        }
        return sorted
    }

    /// Applies the accepted `edits` transactionally through `gateway` as one
    /// ordered unit. The edits are prepared on the transaction and committed;
    /// the model's text is mutated only when the transaction applies. Returns
    /// the reconciliation outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func applyFormatEdits(
        _ edits: [MonaFormatEdit],
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        let ops = edits.map { edit in
            MonaModelEditOperation(range: edit.range, text: edit.text)
        }
        if !ops.isEmpty {
            transaction.prepareEdits(ops)
        }
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `edits` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishFormatEdits(
        _ edits: [MonaFormatEdit],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaFormatEdit]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(edits),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `formatDocument` / `formatRange` /
    /// `formatOnType` / `applyFormatEdits` are no-ops.
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

    /// The plain-text fallback language. format needs no tokenization; it
    /// degrades to plain text for any tokenization need.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — format performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a formatting event when not disposed.
    private func fire(_ event: MonaFormatEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
