// MonaToggleTabFocusModeFeature.swift
//
// P05-T155 — Implement retained feature toggleTabFocusMode.
//
// `MonaToggleTabFocusModeFeature` is the Swift counterpart of Monaco's
// `toggleTabFocusMode` action (monaco-editor 0.56.0, registered as
// `editor.action.toggleTabFocusMode`, menu title "Toggle Tab Key Moves Focus"):
// it switches the Tab key between editor command handling and native focus
// traversal.
//
// The feature holds a single boolean, `tabMovesFocus`. When `tabMovesFocus` is
// `false`, the Tab key is resolved by the editor through the Phase 04 keybinding
// resolver (P04-T003 `MonaKeybindingResolver`): `resolveTab(event:context:chordState:resolver:)`
// delegates to `resolver.resolve(...)`, so the registered Tab keybinding
// dispatches its editor command. When `tabMovesFocus` is `true`, Tab moves
// focus: `resolveTab` returns a pass-through resolution (`.default` outcome, no
// command), so the platform performs native focus traversal. `toggleTabFocusMode()`
// flips the boolean.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `toggleTabFocusMode()`, `resolveTab(...)`,
//      `tabMovesFocus`, all reusing the P04-T003 keybinding resolver for the
//      editor-command branch.
//   2. Register the exact feature identity `toggleTabFocusMode` and its
//      declared commands, actions, contributions, options, menus, and
//      keybindings, referenced verbatim from the frozen registries (no rename /
//      coalesce).
//   3. Route model mutation (read-only — none performed), asynchronous
//      publication, disposal, localization, and degraded plain-text behavior
//      through the shared gateways — reusing `MonaTransactionGateway` (mutation,
//      vacuous), `MonaProviderExecutor` + `MonaMicrotaskQueue` (async
//      publication), `MonaEmitter` (disposal), `MonaLocalization` (localization),
//      and `MonaPlainTextLanguage` (degraded plain text). No parallel mechanisms
//      are introduced.

import AppKit
import Foundation
import MonaCode

/// A tab-focus state snapshot: whether the Tab key moves focus (native focus
/// traversal) instead of being handled by the editor.
public struct MonaTabFocusState: Equatable {

    /// `true` when Tab moves focus (native focus traversal); `false` when the
    /// editor handles Tab (editor command handling).
    public let tabMovesFocus: Bool

    public init(tabMovesFocus: Bool) {
        self.tabMovesFocus = tabMovesFocus
    }
}

/// A toggle event: the tab-focus state after the toggle.
public struct MonaTabFocusToggleEvent: Equatable {

    /// The tab-focus state after the toggle.
    public let state: MonaTabFocusState

    public init(state: MonaTabFocusState) {
        self.state = state
    }
}

/// The toggleTabFocusMode feature: switch Tab between editor command handling
/// and native focus traversal.
///
/// The feature identity `toggleTabFocusMode` and its declared slice are
/// referenced verbatim from the frozen registries. `toggleTabFocusMode()`
/// flips `tabMovesFocus`. `resolveTab(event:context:chordState:resolver:)`
/// reuses the P04-T003 keybinding resolver: when `tabMovesFocus` is `false` it
/// delegates to `resolver.resolve(...)` (editor command handling); when `true`
/// it returns a pass-through resolution so the platform performs native focus
/// traversal. The feature performs no model mutation: mutation routing is
/// vacuous. Asynchronous publication is routed through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaToggleTabFocusModeFeature: MonaDisposable {

    /// The frozen feature identity (`"toggleTabFocusMode"`).
    public static let featureId = "toggleTabFocusMode"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs — toggleTabFocusMode declares no labeled editor
    /// actions (its command carries no action label in the action registry).
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. The single toggleTabFocusMode
    /// command.
    public static let declaredCommandIds: [String] = [
        "editor.action.toggleTabFocusMode"
    ]

    /// The declared contribution IDs — toggleTabFocusMode declares no
    /// contributions.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — the single toggleTabFocusMode command
    /// carries a default keybinding in `MonaBuiltinKeybindings`
    /// (Ctrl+Shift+M / `.winCtrl + .shift + .keyM`).
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.toggleTabFocusMode"
    ]

    /// The declared option names — toggleTabFocusMode declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — toggleTabFocusMode registers a single Command
    /// Palette menu item (ordinal 29, title "Toggle Tab Key Moves Focus").
    public static let declaredMenuIds: [String] = [
        "CommandPalette"
    ]

    // MARK: - Routing state

    private var _tabMovesFocus = false
    private let toggleEmitter = MonaEmitter<MonaTabFocusToggleEvent>()

    /// The event stream for tab-focus toggles. Subscribe with
    /// `onToggle { event in ... }`; the returned disposable removes the listener.
    public var onToggle: MonaEvent<MonaTabFocusToggleEvent> { toggleEmitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the toggleTabFocusMode feature. `tabMovesFocus` defaults to
    /// `false` (editor command handling), matching Monaco's default.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// `true` when Tab moves focus (native focus traversal); `false` when the
    /// editor handles Tab (editor command handling). Defaults to `false`.
    public var tabMovesFocus: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _tabMovesFocus
    }

    /// The current tab-focus state.
    public var currentTabFocusState: MonaTabFocusState {
        return MonaTabFocusState(tabMovesFocus: tabMovesFocus)
    }

    // MARK: - 1. Feature-specific behavior: switch Tab between modes

    /// Toggles `tabMovesFocus` and fires an event with the new state. Returns
    /// the new state, or `nil` after `dispose()`.
    @discardableResult
    public func toggleTabFocusMode() -> MonaTabFocusState? {
        guard !isDisposed else { return nil }
        _lock.lock()
        _tabMovesFocus.toggle()
        let state = MonaTabFocusState(tabMovesFocus: _tabMovesFocus)
        _lock.unlock()
        toggleEmitter.fire(MonaTabFocusToggleEvent(state: state))
        return state
    }

    /// Resolves a Tab key event, switching between editor command handling and
    /// native focus traversal by reusing the P04-T003 keybinding resolver.
    ///
    /// When `tabMovesFocus` is `false`, delegates to `resolver.resolve(...)`
    /// (editor command handling — the resolver dispatches the registered Tab
    /// keybinding). When `tabMovesFocus` is `true`, returns a pass-through
    /// resolution (`.default` outcome, no command) so the platform performs
    /// native focus traversal. After `dispose()`, returns a pass-through
    /// resolution.
    public func resolveTab(
        event: MonaKeyEvent,
        context: MonaKeybindingContext,
        chordState: MonaChordState,
        resolver: MonaKeybindingResolver
    ) -> MonaKeybindingResolution {
        guard !isDisposed, !tabMovesFocus else {
            return MonaKeybindingResolution(
                commandId: nil,
                outcome: .default,
                chordStatus: .none
            )
        }
        return resolver.resolve(event: event, context: context, chordState: chordState)
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway (read-only: none performed)

    /// toggleTabFocusMode performs no model mutation: it flips a local boolean
    /// and delegates Tab resolution to the keybinding resolver (the shared
    /// input gateway). Mutation routing is therefore vacuous — this no-op
    /// commits an empty transaction through the shared gateway so callers that
    /// route every feature action through it can confirm the model is
    /// unchanged. A no-op after `dispose()`.
    @discardableResult
    public func confirmReadOnly(gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `state` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishToggle(
        _ state: MonaTabFocusState,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaTabFocusState) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(state),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, `tabMovesFocus` is frozen at its last
    /// value, and `toggleTabFocusMode()` / `resolveTab(...)` /
    /// `confirmReadOnly` / `publishToggle` are no-ops (`resolveTab` returns a
    /// pass-through resolution).
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        if !already {
            toggleEmitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. toggleTabFocusMode declares
    /// no actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. toggleTabFocusMode needs no
    /// tokenization; it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — toggleTabFocusMode performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
