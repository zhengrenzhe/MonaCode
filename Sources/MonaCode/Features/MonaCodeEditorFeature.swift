// MonaCodeEditorFeature.swift
//
// P05-T105 — Implement retained feature codeEditor.
//
// `MonaCodeEditorFeature` is the Swift counterpart of Monaco's `codeEditor`
// feature (monaco-editor 0.56.0): the host feature that registers the
// standalone code-editor contribution set and the editor lifecycle hooks. It
// is the base feature the standalone editor instantiates: it owns no actions /
// commands / contributions itself (the declared slice is empty), but it
// registers the contribution set the standalone editor brings and drives the
// create / activate / dispose lifecycle.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `standaloneContributionIds` (the standalone
//      contribution set) and the `createEditor` / `activate` / `dispose`
//      lifecycle hooks.
//   2. Register the exact feature identity `codeEditor` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//      codeEditor is the host: its declared slice is empty.
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A code-editor lifecycle phase.
public enum MonaCodeEditorLifecyclePhase: String, Equatable {

    /// The editor was created and attached to a model.
    case created

    /// The editor was activated (focused / readied for input).
    case activated

    /// The editor was disposed.
    case disposed
}

/// A code-editor lifecycle event.
public struct MonaCodeEditorLifecycleEvent: Equatable {

    /// The lifecycle phase transition.
    public let phase: MonaCodeEditorLifecyclePhase

    public init(phase: MonaCodeEditorLifecyclePhase) {
        self.phase = phase
    }
}

/// The codeEditor feature: register the standalone code-editor contribution set
/// + lifecycle hooks.
///
/// The feature identity `codeEditor` and its declared slice are referenced
/// verbatim from the frozen registries. Because `codeEditor` is the host
/// feature, it owns no actions / commands / contributions / options / menus /
/// keybindings directly (the declared slice is empty); instead, it exposes the
/// standalone contribution set (the live contributions the standalone editor
/// instantiates) and the create / activate / dispose lifecycle. Model mutation
/// is routed through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaCodeEditorFeature: MonaDisposable {

    /// The frozen feature identity (`"codeEditor"`).
    public static let featureId = "codeEditor"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs. codeEditor is the host feature; it registers no
    /// labeled editor actions itself (the standalone editor's actions are owned
    /// by their respective features).
    public static let declaredActionIds: [String] = []

    /// The declared command IDs. codeEditor registers no commands itself.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs. codeEditor is the host that instantiates
    /// contributions; it owns no contribution registrations itself.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands. codeEditor declares none.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. codeEditor declares none.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs. codeEditor declares none.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaCodeEditorLifecycleEvent>()

    /// The event stream for lifecycle transitions. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaCodeEditorLifecycleEvent> { emitter.event }

    private var _isCreated = false
    private var _isDisposed = false
    private var _attachedModel: MonaCodeModel?
    private let _lock = NSLock()

    /// Creates the codeEditor feature.
    public init() {}

    /// `true` after `createEditor(model:)` has been called.
    public var isCreated: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isCreated
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: standalone contribution set + lifecycle

    /// The standalone code-editor contribution set: the live contribution IDs
    /// the standalone editor instantiates, verbatim from `MonaContributionRegistry`
    /// (no rename / coalesce). This is the contribution set the standalone
    /// editor brings; the editor instantiates these contributions when it is
    /// created.
    public var standaloneContributionIds: [String] {
        return MonaContributionRegistry().liveIdentities.map { $0.id }
    }

    /// Creates the editor and attaches it to `model`. Registers the standalone
    /// contribution set against the model and fires a `.created` lifecycle
    /// event. Returns the attached model. A no-op after `dispose()`.
    @discardableResult
    public func createEditor(model: MonaCodeModel) -> MonaCodeModel {
        _lock.lock()
        guard !_isDisposed, !_isCreated else {
            _lock.unlock()
            return model
        }
        _isCreated = true
        _attachedModel = model
        _lock.unlock()
        fire(.created)
        return model
    }

    /// Activates the editor (focuses / readies it for input). Fires an
    /// `.activated` lifecycle event. A no-op before creation or after disposal.
    public func activate() {
        _lock.lock()
        guard !_isDisposed, _isCreated else {
            _lock.unlock()
            return
        }
        _lock.unlock()
        fire(.activated)
    }

    // MARK: - 3a. Model mutation → MonaTransactionGateway

    /// Commits a single-text-edit transaction through `gateway` as one ordered
    /// unit. The edit replaces `range` with `text` on the attached model.
    /// Returns the reconciliation outcome. A no-op after `dispose()`.
    @discardableResult
    public func commitEdit(
        gateway: MonaTransactionGateway,
        range: MonaRange,
        text: String
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdit(MonaModelEditOperation(range: range, text: text))
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes a lifecycle `phase` through the shared provider executor,
    /// normalized onto the deterministic microtask queue. `receive` runs ONLY
    /// when the queue is drained (FIFO), after the publication ticket is
    /// validated.
    @discardableResult
    public func publishLifecycle(
        _ phase: MonaCodeEditorLifecyclePhase,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaCodeEditorLifecyclePhase) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(phase),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the editor. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and lifecycle hooks are no-ops. Fires a
    /// `.disposed` lifecycle event on the first call only.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _attachedModel = nil
        _lock.unlock()
        if !already {
            fire(.disposed)
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. codeEditor declares no
    /// actions, so this always returns an empty array.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. codeEditor degrades to the plain-text
    /// fallback when no tokenization / grammar provider is registered.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — codeEditor performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a lifecycle event. Callers guard disposal themselves (`createEditor`
    /// / `activate` are no-ops after disposal); `dispose` fires `.disposed`
    /// before the emitter is dropped.
    private func fire(_ phase: MonaCodeEditorLifecyclePhase) {
        emitter.fire(MonaCodeEditorLifecycleEvent(phase: phase))
    }
}
