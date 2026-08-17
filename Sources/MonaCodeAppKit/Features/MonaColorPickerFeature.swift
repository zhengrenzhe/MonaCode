// MonaColorPickerFeature.swift
//
// P05-T108 — Implement retained feature colorPicker.
//
// `MonaColorPickerFeature` is the Swift counterpart of Monaco's `colorPicker`
// contribution (monaco-editor 0.56.0): it presents, updates, and commits
// document-color provider results. A document color is a ranged color value
// (`#ff0000`) plus the color presentations a provider offers for it
// (`rgb(255,0,0)`, `#ff0000`, ...); presenting retains the provider results,
// updating replaces them, and committing applies a chosen presentation's text
// at the color's range transactionally through `MonaTransactionGateway`.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `presentColors`, `updateColors`, and
//      `commitColor`.
//   2. Register the exact feature identity `colorPicker` and its declared
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

/// A color presentation offered by a document-color provider: a human-readable
/// label and the text to insert when this presentation is committed.
public struct MonaColorPresentation: Equatable {

    /// The human-readable label (e.g. `"RGB"`, `"HEX"`).
    public let label: String

    /// The text to insert at the color's range when this presentation is
    /// committed (e.g. `"rgb(255, 0, 0)"`, `"#ff0000"`).
    public let text: String

    public init(label: String, text: String) {
        self.label = label
        self.text = text
    }
}

/// A document color: a range, the color value, and the presentations a
/// document-color provider offers for it.
public struct MonaColorInformation: Equatable {

    /// The range the color annotates.
    public let range: MonaRange

    /// The color value (e.g. `"#ff0000"`).
    public let color: String

    /// The presentations offered for this color.
    public let presentations: [MonaColorPresentation]

    public init(range: MonaRange, color: String, presentations: [MonaColorPresentation]) {
        self.range = range
        self.color = color
        self.presentations = presentations
    }
}

/// A color-picker event: the colors presented / updated / committed.
public struct MonaColorPickerEvent: Equatable {

    /// The colors delivered by this event.
    public let colors: [MonaColorInformation]

    public init(colors: [MonaColorInformation]) {
        self.colors = colors
    }
}

/// The colorPicker feature: present, update, and commit document-color provider
/// results.
///
/// The feature identity `colorPicker` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaColorPickerFeature: MonaDisposable {

    /// The frozen feature identity (`"colorPicker"`).
    public static let featureId = "colorPicker"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// `editor.action.showOrFocusStandaloneColorPicker` is registered as a
    /// command (no action label) and appears in `declaredCommandIds`.
    public static let declaredActionIds: [String] = [
        "editor.action.hideColorPicker",
        "editor.action.insertColorWithStandaloneColorPicker"
    ]

    /// The declared command IDs in source order. These are the colorPicker
    /// command set: the two provider-execute commands, the hide / insert /
    /// show-or-focus standalone-picker commands.
    public static let declaredCommandIds: [String] = [
        "_executeColorPresentationProvider",
        "_executeDocumentColorProvider",
        "editor.action.hideColorPicker",
        "editor.action.insertColorWithStandaloneColorPicker",
        "editor.action.showOrFocusStandaloneColorPicker"
    ]

    /// The declared contribution IDs (`colorContribution` +
    /// `standaloneColorPickerController` + `colorDetector`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.colorContribution",
        "editor.contrib.standaloneColorPickerController",
        "editor.contrib.colorDetector"
    ]

    /// The declared keybinding commands — the colorPicker commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`, in source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.hideColorPicker",
        "editor.action.insertColorWithStandaloneColorPicker"
    ]

    /// The declared option names — the colorDecorator options.
    public static let declaredOptionIds: [String] = [
        "colorDecorators",
        "colorDecoratorsLimit",
        "defaultColorDecorators",
        "colorDecoratorActivatedOn"
    ]

    /// The declared menu IDs — the menus that carry colorPicker menu items.
    public static let declaredMenuIds: [String] = [
        "CommandPalette"
    ]

    // MARK: - Routing state

    /// The presented document-color provider results.
    private var _presentedColors: [MonaColorInformation] = []

    private let emitter = MonaEmitter<MonaColorPickerEvent>()

    /// The event stream for color-picker changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaColorPickerEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the colorPicker feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: present / update / commit

    /// Presents `colors` (the document-color provider results for `model`),
    /// retaining them as the active presented set. Fires an event with the
    /// presented colors. Returns the presented colors, or an empty array after
    /// `dispose()` (a disposed feature retains no colors).
    @discardableResult
    public func presentColors(
        _ colors: [MonaColorInformation],
        model: MonaCodeModel
    ) -> [MonaColorInformation] {
        guard !isDisposed else { return [] }
        _lock.lock()
        _presentedColors = colors
        _lock.unlock()
        fire(colors)
        return colors
    }

    /// Updates the presented colors, replacing the active set with `colors`.
    /// Fires an event with the updated colors. Returns the updated colors, or an
    /// empty array after `dispose()`.
    @discardableResult
    public func updateColors(_ colors: [MonaColorInformation]) -> [MonaColorInformation] {
        guard !isDisposed else { return [] }
        _lock.lock()
        _presentedColors = colors
        _lock.unlock()
        fire(colors)
        return colors
    }

    /// The number of presented colors retained. Zero after disposal.
    public var presentedColorCount: Int {
        _lock.lock(); defer { _lock.unlock() }
        return _presentedColors.count
    }

    /// A snapshot of the presented colors. Empty after disposal.
    public var presentedColors: [MonaColorInformation] {
        _lock.lock(); defer { _lock.unlock() }
        return _presentedColors
    }

    /// Commits `color`'s chosen `presentation`, applying the presentation's text
    /// at `color`'s range transactionally through `gateway` as one ordered unit.
    /// The edit is prepared on the transaction (labeled with the presentation's
    /// label) and committed; the model's text is mutated only when the
    /// transaction applies. Returns the reconciliation outcome. A no-op after
    /// `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitColor(
        _ color: MonaColorInformation,
        presentation: MonaColorPresentation,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([
            MonaModelEditOperation(range: color.range, text: presentation.text)
        ])
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `colors` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishColorPresentations(
        _ colors: [MonaColorInformation],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaColorInformation]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(colors),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained colors are released, and
    /// `presentColors` / `updateColors` / `commitColor` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _presentedColors.removeAll()
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

    /// The plain-text fallback language. colorPicker needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — colorPicker performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a color-picker event when not disposed.
    private func fire(_ colors: [MonaColorInformation]) {
        guard !isDisposed else { return }
        emitter.fire(MonaColorPickerEvent(colors: colors))
    }
}
