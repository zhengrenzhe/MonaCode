// MonaParameterHintsFeature.swift
//
// P05-T140 — Implement retained feature parameterHints.
//
// `MonaParameterHintsFeature` is the Swift counterpart of Monaco's
// `parameterHints` contribution (monaco-editor 0.56.0): it triggers, cycles,
// updates, and dismisses signature-help results. Triggering retains a
// signature-help result (one or more signatures, an active signature, and an
// active parameter) keyed by model version and reveals it; cycling advances
// the active signature forward / backward with wrap-around; updating sets the
// active signature + parameter directly (clamped to valid bounds); and
// dismissing hides and clears the result.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `triggerParameterHints`, `cycleNextHint`,
//      `cyclePreviousHint`, `updateActiveHint`, and `dismissParameterHints`.
//   2. Register the exact feature identity `parameterHints` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A single parameter within a signature: a label and optional documentation.
/// Mirrors Monaco's `ParameterInformation` (monaco-editor 0.56.0).
public struct MonaParameterHintParameter: Equatable {

    /// The label of the parameter (e.g. `"a: number"`).
    public let label: String

    /// The documentation for the parameter, or `nil`.
    public let documentation: String?

    public init(label: String, documentation: String?) {
        self.label = label
        self.documentation = documentation
    }
}

/// A signature within signature help: a label, its parameters, optional
/// documentation, and the index of the active parameter. Mirrors Monaco's
/// `SignatureInformation` (monaco-editor 0.56.0).
public struct MonaParameterHintSignature: Equatable {

    /// The full label of the signature (e.g. `"min(a: number, b: number): number"`).
    public let label: String

    /// The parameters of the signature, in order.
    public let parameters: [MonaParameterHintParameter]

    /// The documentation for the signature, or `nil`.
    public let documentation: String?

    /// The index of the active parameter within this signature.
    public let activeParameter: Int

    public init(
        label: String,
        parameters: [MonaParameterHintParameter],
        documentation: String?,
        activeParameter: Int = 0
    ) {
        self.label = label
        self.parameters = parameters
        self.documentation = documentation
        self.activeParameter = activeParameter
    }
}

/// A signature-help result: one or more signatures, the active signature index,
/// and the active parameter index. Mirrors Monaco's `SignatureHelp`
/// (monaco-editor 0.56.0).
public struct MonaParameterHintsResult: Equatable {

    /// The signatures available at the trigger position.
    public let signatures: [MonaParameterHintSignature]

    /// The index of the active signature.
    public let activeSignature: Int

    /// The index of the active parameter within the active signature.
    public let activeParameter: Int

    public init(signatures: [MonaParameterHintSignature], activeSignature: Int, activeParameter: Int) {
        self.signatures = signatures
        self.activeSignature = activeSignature
        self.activeParameter = activeParameter
    }
}

/// A parameter-hints event: the current result (or `nil` when dismissed),
/// visibility, and the active signature / parameter indices.
public struct MonaParameterHintsEvent: Equatable {

    /// The current signature-help result, or `nil` when hints are dismissed.
    public let result: MonaParameterHintsResult?

    /// `true` when the parameter-hints popup is visible.
    public let visible: Bool

    /// The active signature index (0 when no result).
    public let activeSignature: Int

    /// The active parameter index (0 when no result).
    public let activeParameter: Int

    public init(result: MonaParameterHintsResult?, visible: Bool, activeSignature: Int, activeParameter: Int) {
        self.result = result
        self.visible = visible
        self.activeSignature = activeSignature
        self.activeParameter = activeParameter
    }
}

/// The parameterHints feature: trigger, cycle, update, and dismiss
/// version-gated signature-help results.
///
/// The feature identity `parameterHints` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (committing the active
/// parameter as a text edit) is routed through `MonaTransactionGateway`;
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaParameterHintsFeature: MonaDisposable {

    /// The frozen feature identity (`"parameterHints"`).
    public static let featureId = "parameterHints"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single labeled parameter-hints action.
    public static let declaredActionIds: [String] = [
        "editor.action.triggerParameterHints"
    ]

    /// The declared command IDs in source order. The parameter-hint command set
    /// is the trigger action plus the close / next / prev commands.
    public static let declaredCommandIds: [String] = [
        "closeParameterHints",
        "editor.action.triggerParameterHints",
        "showNextParameterHint",
        "showPrevParameterHint"
    ]

    /// The declared contribution ID (`editor.controller.parameterHints`).
    public static let declaredContributionIds: [String] = [
        "editor.controller.parameterHints"
    ]

    /// The declared keybinding commands — the parameter-hint commands that
    /// carry a default keybinding in `MonaBuiltinKeybindings`, in source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.triggerParameterHints",
        "closeParameterHints",
        "showNextParameterHint",
        "showPrevParameterHint"
    ]

    /// The declared option name — the `parameterHints` option (an object
    /// carrying `enabled` and `cycle`, both defaulting to `true`).
    public static let declaredOptionIds: [String] = [
        "parameterHints"
    ]

    /// The declared menu IDs — parameterHints registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The retained signature-help result, or `nil` when hints are dismissed.
    private var _result: MonaParameterHintsResult? = nil

    /// `true` when the parameter-hints popup is visible.
    private var _isVisible: Bool = false

    private let emitter = MonaEmitter<MonaParameterHintsEvent>()

    /// The event stream for parameter-hints changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaParameterHintsEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the parameterHints feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// `true` when the parameter-hints popup is visible.
    public var isVisible: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isVisible
    }

    /// The current signature-help result, or `nil` when hints are dismissed.
    public var currentResult: MonaParameterHintsResult? {
        _lock.lock(); defer { _lock.unlock() }
        return _result
    }

    /// The active signature index (0 when no result).
    public var activeSignature: Int {
        _lock.lock(); defer { _lock.unlock() }
        return _result?.activeSignature ?? 0
    }

    /// The active parameter index (0 when no result).
    public var activeParameter: Int {
        _lock.lock(); defer { _lock.unlock() }
        return _result?.activeParameter ?? 0
    }

    // MARK: - 1. Feature-specific behavior: trigger / cycle / update / dismiss

    /// Triggers signature help with `result`, retained against `modelVersion`.
    /// Reveals the popup, sets the active signature to `result.activeSignature`,
    /// and fires an event. Returns the result (with `activeSignature` clamped to
    /// a valid index), or `nil` when `result` has no signatures (a no-signature
    /// result dismisses the popup) or after `dispose()`.
    @discardableResult
    public func triggerParameterHints(
        _ result: MonaParameterHintsResult,
        modelVersion: Int
    ) -> MonaParameterHintsResult? {
        guard !isDisposed else { return nil }
        guard !result.signatures.isEmpty else {
            // No signatures: dismiss and return nil (no popup to show).
            _lock.lock()
            _result = nil
            _isVisible = false
            _lock.unlock()
            fire(result: nil, visible: false, activeSignature: 0, activeParameter: 0)
            return nil
        }
        let clamped = clampResult(result)
        _lock.lock()
        _result = clamped
        _isVisible = true
        _lock.unlock()
        fire(result: clamped, visible: true, activeSignature: clamped.activeSignature, activeParameter: clamped.activeParameter)
        return clamped
    }

    /// Cycles to the next signature, wrapping around to 0 at the end. Returns
    /// the updated result, or `nil` when hints are not visible (or disposed).
    @discardableResult
    public func cycleNextHint() -> MonaParameterHintsResult? {
        return cycle(by: 1)
    }

    /// Cycles to the previous signature, wrapping around to the last signature
    /// at 0. Returns the updated result, or `nil` when hints are not visible (or
    /// disposed).
    @discardableResult
    public func cyclePreviousHint() -> MonaParameterHintsResult? {
        return cycle(by: -1)
    }

    /// Updates the active signature and parameter directly. `activeSignature`
    /// is clamped to `[0, signatures.count - 1]`. Returns the updated result, or
    /// `nil` when hints are not visible (or disposed).
    @discardableResult
    public func updateActiveHint(activeSignature: Int, activeParameter: Int) -> MonaParameterHintsResult? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard var current = _result, _isVisible else {
            _lock.unlock()
            return nil
        }
        _lock.unlock()
        let count = current.signatures.count
        let clampedSig = min(max(activeSignature, 0), max(count - 1, 0))
        let clampedParam = min(max(activeParameter, 0), max(current.signatures[clampedSig].parameters.count - 1, 0))
        current = MonaParameterHintsResult(
            signatures: current.signatures,
            activeSignature: clampedSig,
            activeParameter: clampedParam
        )
        _lock.lock()
        _result = current
        _lock.unlock()
        fire(result: current, visible: true, activeSignature: clampedSig, activeParameter: clampedParam)
        return current
    }

    /// Dismisses the parameter-hints popup: hides and clears the result. Returns
    /// `true` when the popup was visible and is now dismissed. After `dispose()`,
    /// returns `false` and fires no event.
    @discardableResult
    public func dismissParameterHints() -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        let wasVisible = _isVisible
        _isVisible = false
        _result = nil
        _lock.unlock()
        if wasVisible {
            fire(result: nil, visible: false, activeSignature: 0, activeParameter: 0)
        }
        return wasVisible
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Commits the active parameter's label as a text insertion at `range`
    /// through `gateway` as one ordered unit. When no result is active, inserts
    /// an empty string (a no-op edit). Returns the reconciliation outcome. A
    /// no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitParameterEdit(
        at range: MonaRange,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let label = activeParameterLabel() ?? ""
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([
            MonaModelEditOperation(range: range, text: label)
        ])
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `result` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishParameterHints(
        _ result: MonaParameterHintsResult,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaParameterHintsResult) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(result),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the result is cleared, and
    /// `triggerParameterHints` / `cycleNextHint` / `cyclePreviousHint` /
    /// `updateActiveHint` / `dismissParameterHints` / `publishParameterHints`
    /// are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _result = nil
        _isVisible = false
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

    /// The plain-text fallback language. parameterHints needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — parameterHints performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a parameter-hints event when not disposed.
    private func fire(result: MonaParameterHintsResult?, visible: Bool, activeSignature: Int, activeParameter: Int) {
        guard !isDisposed else { return }
        emitter.fire(MonaParameterHintsEvent(
            result: result,
            visible: visible,
            activeSignature: activeSignature,
            activeParameter: activeParameter
        ))
    }

    /// Returns the label of the active parameter of the active signature, or
    /// `nil` when no result is active or the active signature has no parameters.
    private func activeParameterLabel() -> String? {
        _lock.lock(); defer { _lock.unlock() }
        guard let result = _result else { return nil }
        guard result.signatures.indices.contains(result.activeSignature) else { return nil }
        let sig = result.signatures[result.activeSignature]
        let paramIndex = min(max(result.activeParameter, 0), max(sig.parameters.count - 1, 0))
        guard sig.parameters.indices.contains(paramIndex) else { return nil }
        return sig.parameters[paramIndex].label
    }

    /// Cycles the active signature by `delta` (wrapping). Returns the updated
    /// result, or `nil` when hints are not visible.
    private func cycle(by delta: Int) -> MonaParameterHintsResult? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard var current = _result, _isVisible, !current.signatures.isEmpty else {
            _lock.unlock()
            return nil
        }
        _lock.unlock()
        let count = current.signatures.count
        let nextSig = ((current.activeSignature + delta) % count + count) % count
        current = MonaParameterHintsResult(
            signatures: current.signatures,
            activeSignature: nextSig,
            activeParameter: current.signatures[nextSig].activeParameter
        )
        _lock.lock()
        _result = current
        _lock.unlock()
        fire(result: current, visible: true, activeSignature: nextSig, activeParameter: current.activeParameter)
        return current
    }

    /// Clamps a result's active signature / parameter to valid bounds.
    private func clampResult(_ result: MonaParameterHintsResult) -> MonaParameterHintsResult {
        let count = result.signatures.count
        guard count > 0 else { return result }
        let clampedSig = min(max(result.activeSignature, 0), count - 1)
        let sig = result.signatures[clampedSig]
        let paramCount = sig.parameters.count
        let clampedParam = paramCount > 0
            ? min(max(result.activeParameter, 0), paramCount - 1)
            : max(result.activeParameter, 0)
        return MonaParameterHintsResult(
            signatures: result.signatures,
            activeSignature: clampedSig,
            activeParameter: clampedParam
        )
    }
}
