// MonaDndFeature.swift
//
// P05-T114 — Implement retained feature dnd.
//
// `MonaDndFeature` is the Swift counterpart of Monaco's `dnd` contribution
// (monaco-editor 0.56.0): it registers drag-and-drop editor behavior over the
// native drop gateway (`MonaDragDropGateway` P04-T009). The feature registers
// the `editor.contrib.dragAndDrop` contribution + the `dragAndDrop` option over
// a gateway, commits a resolved drop through the transaction gateway, and
// orchestrates the full drop — stale-geometry rejection, transfer-payload
// reading, drop-edit provider chain, and commit.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `registerBehavior(gateway:)`,
//      `commitDrop(content:at:gateway:)`, `performDrop(...)`: register the dnd
//      behavior over the native drop gateway and commit drops through the
//      transaction gateway.
//   2. Register the exact feature identity `dnd` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// A drag-and-drop event: the operation, the resolved drop position, and the
/// committed text length.
public struct MonaDndEvent: Equatable {

    /// The accepted operation mask for the drop.
    public let operation: MonaDragOperation

    /// The model position the drop landed at.
    public let position: MonaPosition

    /// The number of characters committed by the drop (zero when the drop was
    /// rejected or committed no text).
    public let committedTextLength: Int

    public init(operation: MonaDragOperation, position: MonaPosition, committedTextLength: Int) {
        self.operation = operation
        self.position = position
        self.committedTextLength = committedTextLength
    }
}

/// The dnd feature: register drag-and-drop editor behavior over the native drop
/// gateway.
///
/// The feature identity `dnd` and its declared slice are referenced verbatim from
/// the frozen registries. dnd is the `editor.contrib.dragAndDrop` contribution
/// + the `dragAndDrop` option; it declares no commands, actions, keybindings, or
/// menus. The behavior is registered over a `MonaDragDropGateway`; a resolved
/// drop is committed through `MonaTransactionGateway` as one ordered unit. The
/// full drop orchestration rejects stale geometry (the model changed since the
/// drag started), reads the transfer payload through the gateway, runs the
/// drop-edit provider chain, and commits. Asynchronous publication is routed
/// through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaDndFeature: MonaDisposable {

    /// The frozen feature identity (`"dnd"`).
    public static let featureId = "dnd"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs. dnd declares no actions.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs. dnd declares no commands — it is the
    /// drag-and-drop contribution + the `dragAndDrop` option.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs. `editor.contrib.dragAndDrop` instantiates
    /// the drag-and-drop controller.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.dragAndDrop"
    ]

    /// The declared keybinding commands. dnd declares no keybindings.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — the `dragAndDrop` option (boolean, default
    /// `true`) that gates whether drag-and-drop text editing is enabled.
    public static let declaredOptionIds: [String] = [
        "dragAndDrop"
    ]

    /// The declared menu IDs. dnd declares no menu items.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The native drop gateway the behavior is registered over. `nil` until
    /// `registerBehavior(gateway:)` and after `dispose()`.
    private var registeredGateway: MonaDragDropGateway?

    private let emitter = MonaEmitter<MonaDndEvent>()

    /// The event stream for drag-and-drop commits. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaDndEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the dnd feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// `true` when the dnd behavior has been registered over a gateway (and the
    /// feature has not been disposed).
    public var isRegistered: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return registeredGateway != nil
    }

    // MARK: - 1. Feature-specific behavior: register dnd behavior over the gateway

    /// Registers the drag-and-drop behavior over `gateway`, returning the
    /// declared contribution slice. After this call, `commitDrop` /
    /// `performDrop` route drops through the registered gateway. Returns an
    /// empty array after `dispose()`.
    @discardableResult
    public func registerBehavior(gateway: MonaDragDropGateway) -> [String] {
        guard !isDisposed else { return [] }
        _lock.lock()
        registeredGateway = gateway
        _lock.unlock()
        return Self.declaredContributionIds
    }

    /// Commits a resolved `content` at `position` through `gateway` as one
    /// ordered unit. The content's plain text (or rich-text string fallback) is
    /// inserted at a zero-width range at `position`; the model is mutated only
    /// when the transaction applies. Returns the reconciliation outcome. A
    /// no-op after `dispose()` (returns `.dropped`); returns `.dropped` when the
    /// content carries no droppable text. Fires an event with the committed
    /// text length when the drop applies.
    @discardableResult
    public func commitDrop(
        content: MonaClipboardContent,
        at position: MonaPosition,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        guard let text = content.plainText ?? content.richTextString, !text.isEmpty else {
            return .dropped(reason: "no droppable text")
        }
        let insertRange = MonaRange(startPosition: position, endPosition: position)
        let transaction = gateway.beginTransaction()
        transaction.prepareEdit(MonaModelEditOperation(range: insertRange, text: text))
        let outcome = gateway.commit(transaction)
        if case .applied = outcome {
            fire(.init(operation: .copy, position: position, committedTextLength: text.count))
        }
        return outcome
    }

    /// Orchestrates the full drop over the native drop gateway. Rejects stale
    /// geometry (the model changed since the drag started), reads the transfer
    /// payload through `gateway.readTransferPayload`, runs the drop-edit provider
    /// chain through `gateway.runDropEditProviders`, and commits the resolved
    /// content through `transactionGateway`. Returns the reconciliation outcome,
    /// or `.dropped` when any stage rejects. A no-op after `dispose()`.
    @discardableResult
    public func performDrop(
        pasteboard: NSPasteboard,
        operation: MonaDragOperation,
        geometry: MonaDropGeometry,
        model: MonaCodeModel,
        gateway: MonaDragDropGateway,
        transactionGateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        // 1. Reject stale drop geometry: the model changed since the drag started.
        if gateway.isDropGeometryStale(geometry, model: model) {
            return .dropped(reason: "stale geometry")
        }
        // 2. Read the transfer payload (validates drag types + operation mask).
        guard let payload = gateway.readTransferPayload(
            from: pasteboard,
            operation: operation,
            geometry: geometry
        ) else {
            return .dropped(reason: "rejected payload")
        }
        // 3. Run the drop-edit provider chain.
        guard let resolved = gateway.runDropEditProviders(
            payload.content,
            geometry: geometry
        ) else {
            return .dropped(reason: "provider cancelled")
        }
        // 4. Commit the resolved content through the transaction gateway.
        return commitDrop(
            content: resolved,
            at: geometry.position,
            gateway: transactionGateway
        )
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishDndEvent(
        _ event: MonaDndEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaDndEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the gateway registration is released,
    /// and `registerBehavior` / `commitDrop` / `performDrop` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        registeredGateway = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. dnd declares no actions, so
    /// this is always empty.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. dnd needs no tokenization; it degrades
    /// to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — dnd performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a dnd event when not disposed.
    private func fire(_ event: MonaDndEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
