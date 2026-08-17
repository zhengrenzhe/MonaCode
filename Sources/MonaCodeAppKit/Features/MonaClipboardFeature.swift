// MonaClipboardFeature.swift
//
// P05-T103 — Implement retained feature clipboard.
//
// `MonaClipboardFeature` is the Swift counterpart of Monaco's `clipboard`
// contribution (monaco-editor 0.56.0): the editor copy / cut / paste actions
// routed over the native transfer gateway. It registers the editor's copy,
// cut, paste, and copy-with-syntax-highlighting actions and binds them to
// `MonaPasteboardGateway` (the single native pasteboard gateway from P04-T008)
// and `MonaPasteEditPipeline` (the paste-edit + barrier commit pipeline from
// P04-T008).
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `copy`, `cut`, `paste`, and
//      `copyWithSyntaxHighlighting` over the native transfer gateway.
//   2. Register the exact feature identity `clipboard` and its declared
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

/// A clipboard action kind: which editor copy / cut / paste action fired.
public enum MonaClipboardAction: String, Equatable {

    /// `editor.action.clipboardCopyAction` — copy selection to the pasteboard.
    case copy

    /// `editor.action.clipboardCutAction` — copy + delete through the barrier.
    case cut

    /// `editor.action.clipboardPasteAction` — read + insert through the barrier.
    case paste

    /// `editor.action.clipboardCopyWithSyntaxHighlightingAction` — copy rich text.
    case copyWithSyntaxHighlighting
}

/// A clipboard event: the action that fired and the plain-text payload carried
/// over the transfer gateway.
public struct MonaClipboardEvent: Equatable {

    /// The action that fired.
    public let action: MonaClipboardAction

    /// The plain-text payload written to / read from the pasteboard, if any.
    public let plainText: String?

    public init(action: MonaClipboardAction, plainText: String?) {
        self.action = action
        self.plainText = plainText
    }
}

/// The clipboard feature: register editor copy, cut, and paste actions over
/// the native transfer gateway.
///
/// The feature identity `clipboard` and its declared slice are referenced
/// verbatim from the frozen registries (`MonaFeatureRegistry`,
/// `MonaCommandRegistry`, `MonaActionRegistry`, `MonaContributionRegistry`,
/// and `MonaBuiltinKeybindings`). Model mutation is routed through
/// `MonaTransactionGateway` (selection recording) and `MonaPasteEditPipeline`
/// + `MonaModelInputBarrier` (cut / paste commits); asynchronous publication
/// through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaClipboardFeature: MonaDisposable {

    /// The frozen feature identity (`"clipboard"`).
    public static let featureId = "clipboard"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These are
    /// the labeled editor actions registered by the clipboard contribution.
    /// Copy / cut / paste are registered as `EditorCommand`s (command-only, no
    /// action label) and so appear in `declaredCommandIds`, not here.
    public static let declaredActionIds: [String] = [
        "editor.action.clipboardCopyWithSyntaxHighlightingAction"
    ]

    /// The declared command IDs in source order. These are the four clipboard
    /// editor commands (copy, cut, paste, and copy-with-syntax-highlighting).
    public static let declaredCommandIds: [String] = [
        "editor.action.clipboardCopyAction",
        "editor.action.clipboardCutAction",
        "editor.action.clipboardPasteAction",
        "editor.action.clipboardCopyWithSyntaxHighlightingAction"
    ]

    /// The declared contribution ID (`CopyPasteActionController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.copyPasteActionController"
    ]

    /// The declared keybinding commands — the clipboard commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`. Copy / cut / paste use
    /// the native OS keybindings (Cmd+C / Cmd+X / Cmd+V) and are NOT registered
    /// through the keybinding service, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — the clipboard options. `selectionClipboard`
    /// is a `cut` disposition and is excluded; `emptySelectionClipboard` is the
    /// single retained-input clipboard option.
    public static let declaredOptionIds: [String] = [
        "emptySelectionClipboard"
    ]

    /// The declared menu IDs — the menus that carry clipboard menu items, in
    /// menu-registry source order.
    public static let declaredMenuIds: [String] = [
        "CommandPalette",
        "EditorContext",
        "MenubarEditMenu",
        "SimpleEditorContext"
    ]

    // MARK: - Routing state

    /// The native pasteboard gateway (the single read / write boundary for the
    /// macOS pasteboard).
    public let transferGateway: MonaPasteboardGateway

    /// The paste-edit pipeline (provider chain + barrier commit for cut / paste).
    public let pasteEditPipeline: MonaPasteEditPipeline

    /// The emitter that delivers clipboard events. Disposal is routed through
    /// this emitter (idempotent): after `dispose()`, listeners are dropped and
    /// `fire` is a no-op.
    private let emitter = MonaEmitter<MonaClipboardEvent>()

    /// The event stream for clipboard actions. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaClipboardEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the clipboard feature over `transferGateway` (defaults to the
    /// system general pasteboard) and `pasteEditPipeline` (defaults to an empty
    /// provider chain).
    public init(
        transferGateway: MonaPasteboardGateway = MonaPasteboardGateway(),
        pasteEditPipeline: MonaPasteEditPipeline = MonaPasteEditPipeline()
    ) {
        self.transferGateway = transferGateway
        self.pasteEditPipeline = pasteEditPipeline
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: copy / cut / paste over the gateway

    /// Copies `text` (the selected text) to the pasteboard, carrying editor
    /// metadata snapshot from `model` + `selection` so a paste into the
    /// originating editor can restore the source selection. Fires a `.copy`
    /// event. A no-op after `dispose()`.
    @discardableResult
    public func copy(
        text: String,
        selection: MonaSelection,
        model: MonaCodeModel
    ) -> MonaClipboardContent {
        guard !isDisposed else {
            return MonaClipboardContent(plainText: nil, richText: nil, metadata: nil)
        }
        let metadata = MonaClipboardEditorMetadata(model: model, selection: selection)
        let content = MonaClipboardContent(plainText: text, richText: nil, metadata: metadata)
        transferGateway.write(content)
        fire(.copy, plainText: text)
        return content
    }

    /// Copies `text` to the pasteboard (with editor metadata from the primary
    /// selection), then commits the deletion of `selections` through the
    /// paste-edit pipeline + `barrier`. Fires a `.cut` event. A no-op after
    /// `dispose()`.
    @discardableResult
    public func cut(
        text: String,
        selections: [MonaSelection],
        model: MonaCodeModel,
        barrier: MonaModelInputBarrier
    ) -> MonaModelInputBarrierOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let metadata = selections.first.map { MonaClipboardEditorMetadata(model: model, selection: $0) }
        let content = MonaClipboardContent(plainText: text, richText: nil, metadata: metadata)
        transferGateway.write(content)
        let outcome = pasteEditPipeline.commitCut(selections: selections, barrier: barrier)
        fire(.cut, plainText: text)
        return outcome
    }

    /// Reads the pasteboard and, when it carries a plain-text flavor, commits
    /// the paste at each cursor position through the paste-edit pipeline +
    /// `barrier`. Returns `.dropped` when the pasteboard is empty. Fires a
    /// `.paste` event on a non-empty paste. A no-op after `dispose()`.
    @discardableResult
    public func paste(
        cursorPositions: [MonaPosition],
        barrier: MonaModelInputBarrier
    ) -> MonaPasteEditOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        guard let content = transferGateway.read(), let text = content.plainText else {
            return .dropped(reason: "empty pasteboard")
        }
        let outcome = pasteEditPipeline.pasteThroughBarrier(
            text: text,
            cursorPositions: cursorPositions,
            barrier: barrier
        )
        fire(.paste, plainText: text)
        return outcome
    }

    /// Copies `richText` to the pasteboard with both the plain-text and RTF
    /// flavors (the `editor.action.clipboardCopyWithSyntaxHighlightingAction`).
    /// Fires a `.copyWithSyntaxHighlighting` event. A no-op after `dispose()`.
    @discardableResult
    public func copyWithSyntaxHighlighting(richText: NSAttributedString) -> MonaClipboardContent {
        guard !isDisposed else {
            return MonaClipboardContent(plainText: nil, richText: nil, metadata: nil)
        }
        let content = MonaClipboardContent(plainText: richText.string, richText: richText, metadata: nil)
        transferGateway.write(content)
        fire(.copyWithSyntaxHighlighting, plainText: richText.string)
        return content
    }

    // MARK: - 3a. Model mutation → MonaTransactionGateway

    /// Commits a copy-selection transaction through `gateway` as one ordered
    /// unit. The selection is prepared on the transaction and recorded as the
    /// gateway's committed selections; the model's text is untouched (a
    /// selection-only transaction applies no text edits).
    ///
    /// Returns the gateway's committed selections, or an empty array when the
    /// transaction could not be committed.
    @discardableResult
    public func commitCopySelection(
        gateway: MonaTransactionGateway,
        selection: MonaSelection
    ) -> [MonaSelection] {
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

    /// Publishes `plainText` (the clipboard payload) through the shared provider
    /// executor, normalized onto the deterministic microtask queue. `receive`
    /// runs ONLY when the queue is drained (FIFO), after the publication ticket
    /// is validated.
    ///
    /// Returns `true` when the result was accepted onto the publication path.
    @discardableResult
    public func publishClipboardContent(
        _ plainText: String?,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (String?) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(plainText),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and copy / cut / paste are no-ops.
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
    /// `MonaLocalization` surface under `profile` (Monaco's raw UTF-16
    /// placeholder rule + the pseudo transform when applicable).
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. clipboard operates over plain-text
    /// representations and degrades to the plain-text fallback when no
    /// tokenization / grammar provider is registered.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — clipboard performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a clipboard event when not disposed.
    private func fire(_ action: MonaClipboardAction, plainText: String?) {
        guard !isDisposed else { return }
        emitter.fire(MonaClipboardEvent(action: action, plainText: plainText))
    }
}
