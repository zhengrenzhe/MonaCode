// MonaRenameFeature.swift
//
// P05-T147 — Implement retained feature rename.
//
// `MonaRenameFeature` is the Swift counterpart of Monaco's `rename`
// contribution (monaco-editor 0.56.0, registered as
// `editor.contrib.renameController`): it prepares a rename (the range to
// rename + the placeholder), collects the resulting workspace edits, previews
// failures before applying, and applies the workspace edits atomically
// (all-or-none) through `MonaTransactionGateway`.
//
// Atomic application reuses the gateway's own validation gate: every prepared
// edit's range is validated before any text is applied, and a single invalid
// range rolls the whole transaction back — the model is left untouched. This is
// the all-or-none guarantee Monaco's rename controller gives when applying a
// `WorkspaceEdit`.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `prepareRename(at:placeholder:)`,
//      `collectWorkspaceEdit(_:)`, `previewRename(_:model:)`,
//      `applyRename(_:gateway:)`, `acceptRenameInput(_:gateway:)`, and
//      `cancelRenameInput()`.
//   2. Register the exact feature identity `rename` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A single rename edit: the URI of the file, the range to replace, and the
/// new text. Mirrors Monaco's `TextEdit` within a `WorkspaceEdit`
/// (monaco-editor 0.56.0).
public struct MonaRenameLocation: Equatable {

    /// The URI of the file to edit.
    public let uri: String

    /// The range to replace with `newText`.
    public let range: MonaRange

    /// The replacement text.
    public let newText: String

    public init(uri: String, range: MonaRange, newText: String) {
        self.uri = uri
        self.range = range
        self.newText = newText
    }
}

/// The collected workspace edit: the rename edits to apply. Mirrors Monaco's
/// `WorkspaceEdit` (monaco-editor 0.56.0).
public struct MonaRenameWorkspaceEdit: Equatable {

    /// The rename edits, in source order.
    public let edits: [MonaRenameLocation]

    public init(edits: [MonaRenameLocation]) {
        self.edits = edits
    }
}

/// The prepare-rename result: the range to rename and the placeholder text shown
/// in the rename input. Mirrors Monaco's `prepareRename` result
/// (monaco-editor 0.56.0).
public struct MonaRenamePrepareResult: Equatable {

    /// The range of the symbol to rename.
    public let range: MonaRange

    /// The placeholder text for the rename input.
    public let placeholder: String

    public init(range: MonaRange, placeholder: String) {
        self.range = range
        self.placeholder = placeholder
    }
}

/// A rename preview: the workspace edit, the failures that would block
/// application, and whether the edit can be applied.
public struct MonaRenamePreview: Equatable {

    /// The workspace edit being previewed.
    public let workspaceEdit: MonaRenameWorkspaceEdit

    /// The failures that would block application (empty edits, invalid ranges).
    public let failures: [String]

    /// `true` when the edit can be applied (no failures).
    public let canApply: Bool

    public init(workspaceEdit: MonaRenameWorkspaceEdit, failures: [String], canApply: Bool) {
        self.workspaceEdit = workspaceEdit
        self.failures = failures
        self.canApply = canApply
    }
}

/// A rename event: the current prepare result (or `nil` when cancelled).
public struct MonaRenameEvent: Equatable {

    /// The current prepare result, or `nil` when no rename is in progress.
    public let prepare: MonaRenamePrepareResult?

    public init(prepare: MonaRenamePrepareResult?) {
        self.prepare = prepare
    }
}

/// The rename feature: prepare rename, collect workspace edits, preview
/// failures, and apply atomically.
///
/// The feature identity `rename` and its declared slice are referenced verbatim
/// from the frozen registries. Model mutation (applying the workspace edits) is
/// routed through `MonaTransactionGateway` atomically (all-or-none);
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaRenameFeature: MonaDisposable {

    /// The frozen feature identity (`"rename"`).
    public static let featureId = "rename"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single labeled rename action.
    public static let declaredActionIds: [String] = [
        "editor.action.rename"
    ]

    /// The declared command IDs in source order. These are the rename command
    /// set: the rename action, the input accept / cancel commands, the focus
    /// commands, and the provider-execute commands.
    public static let declaredCommandIds: [String] = [
        "editor.action.rename",
        "acceptRenameInput",
        "acceptRenameInputWithPreview",
        "cancelRenameInput",
        "focusNextRenameSuggestion",
        "focusPreviousRenameSuggestion",
        "_executeDocumentRenameProvider",
        "_executePrepareRename"
    ]

    /// The declared contribution ID (`editor.contrib.renameController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.renameController"
    ]

    /// The declared keybinding commands — the rename commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`, in source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.rename",
        "acceptRenameInput",
        "acceptRenameInputWithPreview",
        "cancelRenameInput",
        "focusNextRenameSuggestion",
        "focusPreviousRenameSuggestion"
    ]

    /// The declared option name — the `renameOnType` option (whether to rename
    /// as the user types, default `false`).
    public static let declaredOptionIds: [String] = [
        "renameOnType"
    ]

    /// The declared menu IDs — the menus that carry rename menu items (the
    /// rename action appears in `EditorContext`).
    public static let declaredMenuIds: [String] = [
        "EditorContext"
    ]

    // MARK: - Routing state

    /// The retained prepare-rename result, or `nil` when no rename is in progress.
    private var _prepare: MonaRenamePrepareResult? = nil

    private let emitter = MonaEmitter<MonaRenameEvent>()

    /// The event stream for rename changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaRenameEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the rename feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The current prepare-rename result, or `nil` when no rename is in progress.
    public var currentPrepare: MonaRenamePrepareResult? {
        _lock.lock(); defer { _lock.unlock() }
        return _prepare
    }

    // MARK: - 1. Feature-specific behavior: prepare / collect / preview / apply

    /// Prepares a rename at `range` with `placeholder`, retaining the prepare
    /// result and firing an event. Returns the prepare result, or `nil` after
    /// `dispose()`.
    @discardableResult
    public func prepareRename(
        at range: MonaRange,
        placeholder: String
    ) -> MonaRenamePrepareResult? {
        guard !isDisposed else { return nil }
        let prepared = MonaRenamePrepareResult(range: range, placeholder: placeholder)
        _lock.lock()
        _prepare = prepared
        _lock.unlock()
        emitter.fire(MonaRenameEvent(prepare: prepared))
        return prepared
    }

    /// Collects `edits` into a workspace edit. A pure query.
    public func collectWorkspaceEdit(_ edits: [MonaRenameLocation]) -> MonaRenameWorkspaceEdit {
        return MonaRenameWorkspaceEdit(edits: edits)
    }

    /// Previews `workspaceEdit` against `model`, reporting failures that would
    /// block application: empty edits, or any edit whose range is invalid
    /// against `model`. `canApply` is `true` when there are no failures. A pure
    /// query: it never mutates the model. After `dispose()`, reports a single
    /// "disposed" failure and `canApply == false`.
    public func previewRename(
        _ workspaceEdit: MonaRenameWorkspaceEdit,
        model: MonaCodeModel
    ) -> MonaRenamePreview {
        guard !isDisposed else {
            return MonaRenamePreview(
                workspaceEdit: workspaceEdit,
                failures: ["disposed"],
                canApply: false
            )
        }
        var failures: [String] = []
        if workspaceEdit.edits.isEmpty {
            failures.append("no rename edits")
        }
        for (index, edit) in workspaceEdit.edits.enumerated() {
            if !model.isValidRange(edit.range) {
                failures.append("invalid range at edit \(index)")
            }
        }
        return MonaRenamePreview(
            workspaceEdit: workspaceEdit,
            failures: failures,
            canApply: failures.isEmpty
        )
    }

    /// Applies `workspaceEdit` through `gateway` atomically (all-or-none): every
    /// edit is prepared in one transaction and committed once. If any edit's
    /// range is invalid, the gateway rolls the whole transaction back (model
    /// untouched). Returns the reconciliation outcome. A no-op after `dispose()`
    /// (returns `.dropped`).
    @discardableResult
    public func applyRename(
        _ workspaceEdit: MonaRenameWorkspaceEdit,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits(
            workspaceEdit.edits.map { edit in
                MonaModelEditOperation(range: edit.range, text: edit.newText)
            }
        )
        return gateway.commit(transaction)
    }

    /// Accepts the rename input: applies `workspaceEdit` through `gateway`
    /// atomically, clears the prepare result, and fires an event. Returns `true`
    /// when the edit was applied; `false` when it was dropped / rolled back (or
    /// after `dispose()`).
    @discardableResult
    public func acceptRenameInput(
        _ workspaceEdit: MonaRenameWorkspaceEdit,
        gateway: MonaTransactionGateway
    ) -> Bool {
        guard !isDisposed else { return false }
        let outcome = applyRename(workspaceEdit, gateway: gateway)
        _lock.lock()
        _prepare = nil
        _lock.unlock()
        emitter.fire(MonaRenameEvent(prepare: nil))
        if case .applied = outcome {
            return true
        }
        return false
    }

    /// Cancels the rename input: clears the prepare result and fires an event.
    /// Returns `true` when a prepare was in progress and is now cancelled.
    /// After `dispose()`, returns `false` and fires no event.
    @discardableResult
    public func cancelRenameInput() -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        let hadPrepare = _prepare != nil
        _prepare = nil
        _lock.unlock()
        if hadPrepare {
            emitter.fire(MonaRenameEvent(prepare: nil))
        }
        return hadPrepare
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `workspaceEdit` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the queue
    /// is drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishRename(
        _ workspaceEdit: MonaRenameWorkspaceEdit,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaRenameWorkspaceEdit) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(workspaceEdit),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the prepare result is cleared, and
    /// `prepareRename` / `previewRename` / `applyRename` / `acceptRenameInput` /
    /// `cancelRenameInput` / `publishRename` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _prepare = nil
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

    /// The plain-text fallback language. rename needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — rename performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
