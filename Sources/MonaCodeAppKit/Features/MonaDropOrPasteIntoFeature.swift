// MonaDropOrPasteIntoFeature.swift
//
// P05-T116 — Implement retained feature dropOrPasteInto.
//
// `MonaDropOrPasteIntoFeature` is the Swift counterpart of Monaco's
// `dropOrPasteInto` contribution (monaco-editor 0.56.0): it selects and applies
// explicit drop-or-paste edit proposals over the native drop gateway (P04-T009
// `MonaDragDropGateway`) and the paste pipeline (P04-T008
// `MonaPasteboardGateway`). A drop-or-paste proposal is a titled, kinded set of
// edits offered by a drop/paste edit provider; the feature surfaces the
// proposals (optionally filtered by kind), selects one, and applies its edits
// transactionally through `MonaTransactionGateway`.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `surfaceProposals`, `selectProposal`, and
//      `applyProposal`.
//   2. Register the exact feature identity `dropOrPasteInto` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// A drop-or-paste kind, mirroring the Monaco `DropOrPasteEditKind` taxonomy
/// (monaco-editor 0.56.0). The provider kind identifies the flavor of a
/// drop-or-paste edit proposal (plain text, a URI list, etc.).
public enum MonaDropOrPasteKind: String, Equatable, Sendable {

    /// `text` — a plain-text drop-or-paste proposal.
    case text = "text"

    /// `uriList` — a URI-list drop-or-paste proposal.
    case uriList = "uriList"
}

/// A single edit in a drop-or-paste proposal: a range to replace + the
/// replacement text.
public struct MonaDropOrPasteEdit: Equatable {

    /// The range to replace (raw UTF-16 offsets, 1-based line / column).
    public let range: MonaRange

    /// The replacement text (empty string = deletion).
    public let text: String

    public init(range: MonaRange, text: String) {
        self.range = range
        self.text = text
    }
}

/// A drop-or-paste edit proposal: a titled, kinded set of edits offered by a
/// drop/paste edit provider. `isDefault` marks the default proposal (Monaco's
/// `isDefault` flag for the provider's preferred edit).
public struct MonaDropOrPasteProposal: Equatable {

    /// The human-readable title.
    public let title: String

    /// The proposal kind.
    public let kind: MonaDropOrPasteKind

    /// The edits to apply when the proposal is accepted.
    public let edits: [MonaDropOrPasteEdit]

    /// `true` when this is the default proposal.
    public let isDefault: Bool

    public init(
        title: String,
        kind: MonaDropOrPasteKind,
        edits: [MonaDropOrPasteEdit],
        isDefault: Bool
    ) {
        self.title = title
        self.kind = kind
        self.edits = edits
        self.isDefault = isDefault
    }
}

/// A drop-or-paste event: the proposals surfaced / selected / applied.
public struct MonaDropOrPasteIntoEvent: Equatable {

    /// The proposals delivered by this event.
    public let proposals: [MonaDropOrPasteProposal]

    public init(proposals: [MonaDropOrPasteProposal]) {
        self.proposals = proposals
    }
}

/// The dropOrPasteInto feature: select and apply explicit drop-or-paste edit
/// proposals.
///
/// The feature identity `dropOrPasteInto` and its declared slice are referenced
/// verbatim from the frozen registries. Proposals are surfaced (optionally
/// filtered by kind) and one is selected; the selected proposal's edits are
/// applied through `MonaTransactionGateway` as one ordered unit. Asynchronous
/// publication is routed through `MonaProviderExecutor` + `MonaMicrotaskQueue`;
/// disposal through `MonaEmitter`; localization through `MonaLocalization`;
/// and degraded plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaDropOrPasteIntoFeature: MonaDisposable {

    /// The frozen feature identity (`"dropOrPasteInto"`).
    public static let featureId = "dropOrPasteInto"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These
    /// are the labeled editor actions registered by the dropOrPasteInto
    /// contribution: `editor.action.pasteAs` ("Paste As...") and
    /// `editor.action.pasteAsText` ("Paste as Text").
    public static let declaredActionIds: [String] = [
        "editor.action.pasteAs",
        "editor.action.pasteAsText"
    ]

    /// The declared command IDs in source order. These are the dropOrPasteInto
    /// command set: the paste-as / paste-as-text actions and the drop/paste
    /// widget controls (change-type, hide-widget).
    public static let declaredCommandIds: [String] = [
        "editor.action.pasteAs",
        "editor.action.pasteAsText",
        "editor.changeDropType",
        "editor.changePasteType",
        "editor.hideDropWidget",
        "editor.hidePasteWidget"
    ]

    /// The declared contribution IDs. `editor.contrib.dropIntoEditorController`
    /// instantiates the drop controller and
    /// `editor.contrib.copyPasteActionController` instantiates the paste
    /// controller.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.dropIntoEditorController",
        "editor.contrib.copyPasteActionController"
    ]

    /// The declared keybinding commands — the dropOrPasteInto commands that
    /// carry a default keybinding. The widget controls (change-type, hide-widget)
    /// carry the default keybindings; the paste-as actions carry none.
    public static let declaredKeybindingCommands: [String] = [
        "editor.changeDropType",
        "editor.changePasteType",
        "editor.hideDropWidget",
        "editor.hidePasteWidget"
    ]

    /// The declared option names — the `dropIntoEditor` and `pasteAs` options
    /// (each an object with `enabled` + show-selector defaults).
    public static let declaredOptionIds: [String] = [
        "dropIntoEditor",
        "pasteAs"
    ]

    /// The declared menu IDs. dropOrPasteInto declares no menu items.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaDropOrPasteIntoEvent>()

    /// The event stream for drop-or-paste changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaDropOrPasteIntoEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the dropOrPasteInto feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: surface / select / apply

    /// Surfaces provider drop-or-paste proposals, filtered by `kind`. When
    /// `kind` is nil, all provider proposals are surfaced unchanged. When
    /// `kind` is supplied, only proposals of that kind are surfaced.
    public func surfaceProposals(
        _ proposals: [MonaDropOrPasteProposal],
        kind: MonaDropOrPasteKind?
    ) -> [MonaDropOrPasteProposal] {
        guard let kind = kind else { return proposals }
        return proposals.filter { $0.kind == kind }
    }

    /// Selects `proposal`, firing an event with the selected proposal. Returns
    /// the selected proposal unchanged. After `dispose()`, returns the proposal
    /// unchanged and fires no event.
    @discardableResult
    public func selectProposal(
        _ proposal: MonaDropOrPasteProposal
    ) -> MonaDropOrPasteProposal {
        guard !isDisposed else { return proposal }
        fire(MonaDropOrPasteIntoEvent(proposals: [proposal]))
        return proposal
    }

    /// Applies `proposal`'s edits transactionally through `gateway` as one
    /// ordered unit. The edits are prepared on the transaction (labeled with
    /// the proposal's title) and committed; the model's text is mutated only
    /// when the transaction applies. Returns the reconciliation outcome. A
    /// no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func applyProposal(
        _ proposal: MonaDropOrPasteProposal,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        let ops = proposal.edits.map { edit in
            MonaModelEditOperation(range: edit.range, text: edit.text)
        }
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
    public func publishDropOrPasteEvent(
        _ event: MonaDropOrPasteIntoEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaDropOrPasteIntoEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `selectProposal` / `applyProposal`
    /// are no-ops.
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

    /// The plain-text fallback language. dropOrPasteInto needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — dropOrPasteInto performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a drop-or-paste event when not disposed.
    private func fire(_ event: MonaDropOrPasteIntoEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
