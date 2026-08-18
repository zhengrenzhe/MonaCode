// MonaReadOnlyMessageFeature.swift
//
// P05-T145 — Implement retained feature readOnlyMessage.
//
// `MonaReadOnlyMessageFeature` is the Swift counterpart of Monaco's
// `readOnlyMessage` contribution (monaco-editor 0.56.0): when a mutation is
// attempted against a read-only editor, the controller presents explicit
// localized feedback — the configured `readOnlyMessage` (when set) or the
// default localized "Cannot edit in read-only editor" message — instead of
// silently dropping the edit.
//
// The editability check reuses the `readOnly` editor option (the same source of
// truth Monaco's `ReadOnlyMessageController` reads): `evaluate(using:)` reads
// the `readOnly` option from the shared `MonaOptionStore`. A rejected mutation
// routes through `MonaTransactionGateway` as a `.dropped` outcome and fires a
// `MonaReadOnlyMessageEvent` carrying the native AppKit presentation.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `evaluateReadOnly(using:)`,
//      `message(for:profile:)`, `presentation(for:profile:)`,
//      `presentRejectedMutation(using:profile:)`, and `commitInput(...)`,
//      presenting localized feedback for rejected read-only mutations.
//   2. Register the exact feature identity `readOnlyMessage` and its declared
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

/// The read-only message presentation: the native AppKit attributed string, the
/// resolved localized message string, and whether the message is visible (the
/// editor is read-only).
public struct MonaReadOnlyMessagePresentation: Equatable {

    /// The native AppKit attributed string for the read-only message (dim
    /// secondary label color), or an empty attributed string when hidden.
    public let attributedString: NSAttributedString

    /// The resolved localized message string.
    public let message: String

    /// `true` when the read-only message is visible (the editor is read-only).
    public let visible: Bool

    public init(attributedString: NSAttributedString, message: String, visible: Bool) {
        self.attributedString = attributedString
        self.message = message
        self.visible = visible
    }
}

/// A read-only-message event: the current presentation.
public struct MonaReadOnlyMessageEvent: Equatable {

    /// The presentation after the change.
    public let presentation: MonaReadOnlyMessagePresentation

    public init(presentation: MonaReadOnlyMessagePresentation) {
        self.presentation = presentation
    }
}

/// The readOnlyMessage feature: present explicit localized feedback for
/// rejected read-only mutations.
///
/// The feature identity `readOnlyMessage` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (a rejected read-only
/// edit) is routed through `MonaTransactionGateway`; asynchronous publication
/// through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`. The editability check
/// reads the `readOnly` editor option from `MonaOptionStore`.
public final class MonaReadOnlyMessageFeature: MonaDisposable {

    /// The frozen feature identity (`"readOnlyMessage"`).
    public static let featureId = "readOnlyMessage"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// readOnlyMessage declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. readOnlyMessage declares no
    /// commands, so this slice is empty.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution ID (`editor.contrib.readOnlyMessageController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.readOnlyMessageController"
    ]

    /// The declared keybinding commands — readOnlyMessage registers no default
    /// keybindings, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option name — the `readOnlyMessage` option (the configured
    /// read-only message object, default `null`).
    public static let declaredOptionIds: [String] = [
        "readOnlyMessage"
    ]

    /// The declared menu IDs — readOnlyMessage registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The default localized "Cannot edit in read-only editor" message index
    /// (N1 identity `editor.readonly`, monaco 0.56.0).
    private static let defaultReadOnlyMessageIndex = 1428

    private let emitter = MonaEmitter<MonaReadOnlyMessageEvent>()

    /// The event stream for read-only-message presentations. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaReadOnlyMessageEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the readOnlyMessage feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: present localized read-only feedback

    /// Returns `true` when the editor is read-only — i.e. the `readOnly` editor
    /// option is `true`. A pure query: it reads the option and never mutates
    /// the model. After `dispose()`, returns `false`.
    public func evaluateReadOnly(using options: MonaOptionStore) -> Bool {
        guard !isDisposed else { return false }
        return options.value(for: "readOnly")?.boolValue ?? false
    }

    /// Resolves the read-only message for `options` under `profile`: the
    /// configured `readOnlyMessage` string (when set) or the default localized
    /// "Cannot edit in read-only editor" message (resolved + formatted through
    /// the shared `MonaLocalization` surface, including the pseudo transform).
    public func message(
        for options: MonaOptionStore,
        profile: MonaCodeEnvironmentProfile
    ) -> String {
        // A configured readOnlyMessage (a MarkdownString object carrying a
        // `value` string, or a plain string) overrides the default.
        let customString: String? = {
            switch options.value(for: "readOnlyMessage") {
            case .string(let s) where !s.isEmpty:
                return s
            case .object(let dict):
                if let v = dict["value"]?.stringValue, !v.isEmpty {
                    return v
                }
                return nil
            default:
                return nil
            }
        }()
        if let custom = customString {
            return MonaLocalization.format(custom, args: [], profile: profile)
        }
        // Default: resolve + format the localized "Cannot edit in read-only editor".
        let resolved = (try? MonaLocalization.resolve(
            Self.defaultReadOnlyMessageIndex,
            profile: profile
        )) ?? "Cannot edit in read-only editor"
        return MonaLocalization.format(resolved, args: [], profile: profile)
    }

    /// Builds the read-only message presentation for `options` under `profile`:
    /// the native AppKit attributed string (dim secondary label color) + the
    /// resolved message when the editor is read-only, or an empty hidden
    /// presentation when the editor is editable (or after disposal).
    public func presentation(
        for options: MonaOptionStore,
        profile: MonaCodeEnvironmentProfile
    ) -> MonaReadOnlyMessagePresentation {
        guard !isDisposed else {
            return MonaReadOnlyMessagePresentation(
                attributedString: NSAttributedString(),
                message: "",
                visible: false
            )
        }
        let visible = evaluateReadOnly(using: options)
        if visible {
            let text = message(for: options, profile: profile)
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let attributed = NSAttributedString(string: text, attributes: attrs)
            return MonaReadOnlyMessagePresentation(
                attributedString: attributed,
                message: text,
                visible: true
            )
        }
        return MonaReadOnlyMessagePresentation(
            attributedString: NSAttributedString(),
            message: "",
            visible: false
        )
    }

    /// Presents the read-only message when the editor is read-only, firing an
    /// event with the current presentation. Returns `true` when a message was
    /// presented (the editor is read-only); `false` when the editor is editable
    /// (no message) or after `dispose()`.
    @discardableResult
    public func presentRejectedMutation(
        using options: MonaOptionStore,
        profile: MonaCodeEnvironmentProfile
    ) -> Bool {
        guard !isDisposed else { return false }
        let presentation = self.presentation(for: options, profile: profile)
        guard presentation.visible else { return false }
        emitter.fire(MonaReadOnlyMessageEvent(presentation: presentation))
        return true
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Attempts to commit `text` at `range` through `gateway`. When the editor
    /// is read-only (the `readOnly` option is `true`), the mutation is rejected:
    /// no edit is applied, the outcome is `.dropped`, and a read-only message
    /// event is fired. When the editor is editable, the mutation is applied
    /// atomically through `MonaTransactionGateway`. A no-op after `dispose()`
    /// (returns `.dropped`).
    @discardableResult
    public func commitInput(
        text: String,
        at range: MonaRange,
        gateway: MonaTransactionGateway,
        options: MonaOptionStore,
        profile: MonaCodeEnvironmentProfile
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        // Read-only rejection: present the localized message and drop the edit.
        if evaluateReadOnly(using: options) {
            _ = presentRejectedMutation(using: options, profile: profile)
            return .dropped(reason: "editor is read-only")
        }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([
            MonaModelEditOperation(range: range, text: text)
        ])
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `presentation` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishReadOnlyMessage(
        _ presentation: MonaReadOnlyMessagePresentation,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaReadOnlyMessagePresentation) -> Void
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
    /// disposal, listeners are dropped, and `evaluateReadOnly` /
    /// `presentation` / `presentRejectedMutation` / `commitInput` /
    /// `publishReadOnlyMessage` are no-ops.
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
    /// `MonaLocalization` surface under `profile`. readOnlyMessage declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. readOnlyMessage needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — readOnlyMessage performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
