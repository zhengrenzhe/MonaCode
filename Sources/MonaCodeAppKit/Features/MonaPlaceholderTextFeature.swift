// MonaPlaceholderTextFeature.swift
//
// P05-T141 — Implement retained feature placeholderText.
//
// `MonaPlaceholderTextFeature` is the Swift counterpart of Monaco's
// `placeholderText` contribution (monaco-editor 0.56.0): it renders a native
// AppKit placeholder presentation ONLY while the model is empty, and dismisses
// it the moment the model gains content (it disappears on first input). When
// the model is emptied again, the placeholder reappears.
//
// The presentation is an `NSAttributedString` carrying the native AppKit
// placeholder color (`NSColor.placeholderTextColor`) — the same dim color
// `NSTextView`/`NSTextField` use for their native placeholder. The feature
// attaches to a `MonaCodeModel`, observes its content changes through the
// shared `MonaEvent` surface, and re-evaluates visibility (empty model →
// visible; non-empty model → hidden) on every content change.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `evaluate(using:)`, `presentation(for:)`,
//      `attach(to:)`, `updatePlaceholder(_:)`, and `commitInput(_:at:gateway:)`,
//      rendering the placeholder only while the model is empty.
//   2. Register the exact feature identity `placeholderText` and its declared
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

/// The placeholder presentation: the native AppKit attributed string + whether
/// it is currently visible (the model is empty).
public struct MonaPlaceholderTextPresentation: Equatable {

    /// The native AppKit placeholder attributed string (dim color), or an empty
    /// attributed string when the placeholder is hidden.
    public let attributedString: NSAttributedString

    /// `true` when the placeholder is visible (the model is empty).
    public let visible: Bool

    public init(attributedString: NSAttributedString, visible: Bool) {
        self.attributedString = attributedString
        self.visible = visible
    }
}

/// A placeholder-text event: the current presentation.
public struct MonaPlaceholderTextEvent: Equatable {

    /// The presentation after the change.
    public let presentation: MonaPlaceholderTextPresentation

    public init(presentation: MonaPlaceholderTextPresentation) {
        self.presentation = presentation
    }
}

/// The placeholderText feature: render a native AppKit placeholder presentation
/// only while the model is empty.
///
/// The feature identity `placeholderText` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (the first input) is
/// routed through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`. The model is observed through its
/// `onDidChangeContent` `MonaEvent`.
public final class MonaPlaceholderTextFeature: MonaDisposable {

    /// The frozen feature identity (`"placeholderText"`).
    public static let featureId = "placeholderText"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// placeholderText declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. placeholderText declares no
    /// commands, so this slice is empty.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution ID (`editor.contrib.placeholderText`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.placeholderText"
    ]

    /// The declared keybinding commands — placeholderText registers no default
    /// keybindings, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option name — the `placeholder` editor option (an object
    /// carrying the placeholder text, default `null`).
    public static let declaredOptionIds: [String] = [
        "placeholder"
    ]

    /// The declared menu IDs — placeholderText registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The placeholder text string.
    private var _placeholderText: String

    /// The model this feature is attached to, or `nil` when detached.
    private var _attachedModel: MonaCodeModel?

    /// The subscription disposable for the attached model's content changes.
    private var _contentSubscription: MonaDisposable?

    /// `true` when the placeholder is currently visible (the model is empty).
    private var _isVisible: Bool = false

    private let emitter = MonaEmitter<MonaPlaceholderTextEvent>()

    /// The event stream for placeholder visibility changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaPlaceholderTextEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the placeholderText feature.
    /// - Parameter placeholder: The placeholder text shown while the model is
    ///   empty.
    public init(placeholder: String = "") {
        self._placeholderText = placeholder
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The placeholder text string.
    public var placeholderText: String {
        _lock.lock(); defer { _lock.unlock() }
        return _placeholderText
    }

    /// `true` when the placeholder is currently visible (the attached model is
    /// empty). `false` when no model is attached, the model has content, or the
    /// feature is disposed.
    public var isVisible: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isVisible
    }

    // MARK: - 1. Feature-specific behavior: render only while model is empty

    /// Returns `true` when the placeholder should be visible for `model` — i.e.
    /// `model` is empty (zero-length value). A pure query: it reads the model's
    /// length and never mutates it. After `dispose()`, returns `false`.
    public func evaluate(using model: MonaCodeModel) -> Bool {
        guard !isDisposed else { return false }
        return model.getValueLength() == 0
    }

    /// Builds the placeholder presentation for `model`: the native AppKit
    /// attributed string (dim placeholder color) when the model is empty, or an
    /// empty attributed string when the model has content (or after disposal).
    public func presentation(for model: MonaCodeModel) -> MonaPlaceholderTextPresentation {
        guard !isDisposed else {
            return MonaPlaceholderTextPresentation(attributedString: NSAttributedString(), visible: false)
        }
        let visible = evaluate(using: model)
        if visible {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.placeholderTextColor
            ]
            let attributed = NSAttributedString(string: placeholderText, attributes: attrs)
            return MonaPlaceholderTextPresentation(attributedString: attributed, visible: true)
        }
        return MonaPlaceholderTextPresentation(attributedString: NSAttributedString(), visible: false)
    }

    /// Attaches to `model`, observing its content changes through the shared
    /// `MonaEvent` surface. Re-evaluates visibility (firing an event) on attach
    /// and on every subsequent content change: empty model → visible; non-empty
    /// model → hidden. Detach by disposing the returned disposable, or by
    /// `dispose()`. After `dispose()`, this is a no-op returning an inert
    /// disposable.
    @discardableResult
    public func attach(to model: MonaCodeModel) -> MonaDisposable {
        guard !isDisposed else { return MonaDisposableImpl({}) }
        _lock.lock()
        _attachedModel = model
        _lock.unlock()
        // Initial evaluation: fire the current presentation.
        reevaluate(attachedModel: model, fireEvent: true)
        // Observe content changes: re-evaluate (and fire) on every change.
        let subscription = model.onDidChangeContent { [weak self] _ in
            guard let self else { return }
            self.reevaluate(attachedModel: model, fireEvent: true)
        }
        _lock.lock()
        _contentSubscription = subscription
        _lock.unlock()
        return subscription
    }

    /// Updates the placeholder text string, rebuilding the presentation. Fires
    /// an event with the rebuilt presentation. After `dispose()`, this is a
    /// no-op.
    public func updatePlaceholder(_ text: String) {
        guard !isDisposed else { return }
        _lock.lock()
        _placeholderText = text
        let model = _attachedModel
        _lock.unlock()
        if let model {
            reevaluate(attachedModel: model, fireEvent: true)
        }
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Commits `text` as an insertion at `range` through `gateway` as one
    /// ordered unit — the "first input" that dismisses the placeholder. After
    /// the gateway commits, the attached model fires its content-change event,
    /// the observer re-evaluates, and the placeholder hides. Returns the
    /// reconciliation outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitInput(
        text: String,
        at range: MonaRange,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([
            MonaModelEditOperation(range: range, text: text)
        ])
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `presentation` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the queue
    /// is drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishPlaceholder(
        _ presentation: MonaPlaceholderTextPresentation,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaPlaceholderTextPresentation) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(presentation),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the model observer is detached, and
    /// `evaluate` / `presentation` / `attach` / `commitInput` / `publishPlaceholder`
    /// are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        let subscription = _contentSubscription
        _contentSubscription = nil
        _attachedModel = nil
        _isVisible = false
        _lock.unlock()
        subscription?.dispose()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. placeholderText declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. placeholderText needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — placeholderText performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Re-evaluates visibility against `attachedModel` and updates `_isVisible`,
    /// firing an event with the current presentation when `fireEvent` and the
    /// visibility changed (or when forced on attach / update).
    private func reevaluate(attachedModel model: MonaCodeModel, fireEvent: Bool) {
        guard !isDisposed else { return }
        let visible = evaluate(using: model)
        _lock.lock()
        let changed = (visible != _isVisible)
        _isVisible = visible
        _lock.unlock()
        if fireEvent || changed {
            let presentation = self.presentation(for: model)
            emitter.fire(MonaPlaceholderTextEvent(presentation: presentation))
        }
    }
}
