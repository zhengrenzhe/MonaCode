// MonaToggleHighContrastFeature.swift
//
// P05-T154 — Implement retained feature toggleHighContrast.
//
// `MonaToggleHighContrastFeature` is the Swift counterpart of Monaco's
// `toggleHighContrast` action (monaco-editor 0.56.0, registered as
// `editor.action.toggleHighContrast`, label "Toggle High Contrast Theme"): it
// toggles the explicit high-contrast theme profile and invalidates paint
// state.
//
// The feature reuses the Phase 05 theme registry (P05-T006 `MonaThemeRegistry`)
// for the theme switch: `toggleHighContrast()` calls `MonaThemeRegistry.setTheme(_:)`
// with `hc-black` when the active theme is not high-contrast, and `vs-dark`
// (Monaco's standalone default) when it is. `MonaThemeRegistry.setTheme` fires
// `onDidChangeTheme` only on a real switch to a known theme, so the toggle is a
// no-op when the target equals the current theme. After the switch the feature
// invalidates paint state by firing a paint-invalidation event through the
// shared `MonaEmitter` (B1-R).
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `toggleHighContrast()`,
//      `invalidatePaintState()`, `currentHighContrastState`, all reusing the
//      T006 theme registry for the theme switch.
//   2. Register the exact feature identity `toggleHighContrast` and its
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

/// A high-contrast state snapshot: the active theme id and whether it is a
/// high-contrast theme. Produced by `MonaToggleHighContrastFeature`.
public struct MonaHighContrastState: Equatable {

    /// The active theme id (`"vs-dark"`, `"hc-black"`, `"hc-light"`, or a
    /// registered custom id).
    public let themeId: String

    /// `true` when the active theme is a high-contrast theme (`hc-black` or
    /// `hc-light`).
    public let isHighContrast: Bool

    public init(themeId: String, isHighContrast: Bool) {
        self.themeId = themeId
        self.isHighContrast = isHighContrast
    }
}

/// A toggle event: the new high-contrast state and the previous theme id (the
/// theme that was active before the toggle).
public struct MonaHighContrastToggleEvent: Equatable {

    /// The high-contrast state after the toggle.
    public let state: MonaHighContrastState

    /// The theme id that was active before the toggle, or `nil` when the toggle
    /// was a no-op (the target equaled the current theme).
    public let previousThemeId: String?

    public init(state: MonaHighContrastState, previousThemeId: String?) {
        self.state = state
        self.previousThemeId = previousThemeId
    }
}

/// A paint-invalidation event: the feature signals that paint state must be
/// invalidated. Fired on `toggleHighContrast()` and `invalidatePaintState()`.
public struct MonaPaintInvalidationEvent: Equatable {

    /// The reason the paint state was invalidated (e.g.
    /// `"highContrastToggle"`, `"explicit"`).
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

/// The toggleHighContrast feature: toggle the explicit high-contrast theme
/// profile and invalidate paint state.
///
/// The feature identity `toggleHighContrast` and its declared slice are
/// referenced verbatim from the frozen registries. `toggleHighContrast()`
/// reuses the T006 theme registry (`MonaThemeRegistry.setTheme`) to switch the
/// active theme between the high-contrast profile (`hc-black`) and Monaco's
/// standalone default (`vs-dark`); after the switch it invalidates paint state
/// through the shared `MonaEmitter`. The feature performs no model mutation:
/// mutation routing is vacuous (it introduces no parallel mutation mechanism,
/// and `confirmReadOnly(gateway:)` commits an empty transaction). Asynchronous
/// publication is routed through `MonaProviderExecutor` + `MonaMicrotaskQueue`;
/// disposal through `MonaEmitter`; localization through `MonaLocalization`;
/// and degraded plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaToggleHighContrastFeature: MonaDisposable {

    /// The frozen feature identity (`"toggleHighContrast"`).
    public static let featureId = "toggleHighContrast"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single toggleHighContrast action (ordinal 166, label
    /// "Toggle High Contrast Theme").
    public static let declaredActionIds: [String] = [
        "editor.action.toggleHighContrast"
    ]

    /// The declared command IDs in source order. The toggleHighContrast action
    /// is also registered as an editor command, so this slice equals
    /// `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution IDs — toggleHighContrast declares no
    /// contributions in the F1-R3 scope manifest.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — toggleHighContrast carries no default
    /// keybinding in `MonaBuiltinKeybindings`, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — toggleHighContrast declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — toggleHighContrast registers no menu items.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The theme registry owning the active theme. Reused from T006 — the
    /// feature performs no theme-state management of its own.
    public let themeRegistry: MonaThemeRegistry

    private let toggleEmitter = MonaEmitter<MonaHighContrastToggleEvent>()
    private let paintEmitter = MonaEmitter<MonaPaintInvalidationEvent>()

    /// The event stream for high-contrast toggles. Subscribe with
    /// `onToggle { event in ... }`; the returned disposable removes the listener.
    public var onToggle: MonaEvent<MonaHighContrastToggleEvent> { toggleEmitter.event }

    /// The event stream for paint invalidations. Subscribe with
    /// `onPaintInvalidation { event in ... }`; the returned disposable removes
    /// the listener.
    public var onPaintInvalidation: MonaEvent<MonaPaintInvalidationEvent> { paintEmitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the toggleHighContrast feature reusing `themeRegistry` for the
    /// theme switch. Defaults to a fresh `MonaThemeRegistry` (active theme =
    /// `vs-dark`, Monaco's standalone default).
    public init(themeRegistry: MonaThemeRegistry = MonaThemeRegistry()) {
        self.themeRegistry = themeRegistry
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The current high-contrast state, derived from the theme registry's
    /// active theme.
    public var currentHighContrastState: MonaHighContrastState {
        return MonaHighContrastState(
            themeId: themeRegistry.currentThemeId,
            isHighContrast: themeRegistry.isHighContrast
        )
    }

    // MARK: - 1. Feature-specific behavior: toggle hc theme profile + invalidate paint

    /// The high-contrast theme the feature toggles ON to (`hc-black` — Monaco's
    /// default high-contrast builtin).
    public static let highContrastThemeId = "hc-black"

    /// The non-high-contrast theme the feature toggles OFF to (`vs-dark` —
    /// Monaco's standalone default).
    public static let standardThemeId = "vs-dark"

    /// Toggles the explicit high-contrast theme profile: switches the active
    /// theme to `hc-black` when it is not high-contrast, and to `vs-dark` when
    /// it is. After the switch, invalidates paint state. Returns the new
    /// high-contrast state, or `nil` after `dispose()`.
    ///
    /// The switch routes through `MonaThemeRegistry.setTheme(_:)` (T006), which
    /// fires `onDidChangeTheme` only on a real switch to a known theme — so the
    /// toggle is observable through both the registry's change event and this
    /// feature's `onToggle` / `onPaintInvalidation` events.
    @discardableResult
    public func toggleHighContrast() -> MonaHighContrastState? {
        guard !isDisposed else { return nil }
        let previous = themeRegistry.currentThemeId
        let target = themeRegistry.isHighContrast
            ? Self.standardThemeId
            : Self.highContrastThemeId
        themeRegistry.setTheme(target)
        let state = MonaHighContrastState(
            themeId: themeRegistry.currentThemeId,
            isHighContrast: themeRegistry.isHighContrast
        )
        let previousId = (state.themeId == previous) ? nil : previous
        toggleEmitter.fire(MonaHighContrastToggleEvent(state: state, previousThemeId: previousId))
        invalidatePaintState(reason: "highContrastToggle")
        return state
    }

    /// Invalidates paint state, firing a paint-invalidation event with the
    /// default reason. A no-op after `dispose()`. Does not touch the theme.
    public func invalidatePaintState() {
        invalidatePaintState(reason: "explicit")
    }

    /// Invalidates paint state with `reason`, firing the paint-invalidation
    /// event. A no-op after `dispose()`.
    public func invalidatePaintState(reason: String) {
        guard !isDisposed else { return }
        paintEmitter.fire(MonaPaintInvalidationEvent(reason: reason))
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway (read-only: none performed)

    /// toggleHighContrast performs no model mutation: it switches the theme
    /// through the T006 theme registry (the shared theme-state gateway) and
    /// invalidates paint state through the shared emitter. Mutation routing is
    /// therefore vacuous — this no-op commits an empty transaction through the
    /// shared gateway so callers that route every feature action through it can
    /// confirm the model is unchanged. A no-op after `dispose()`.
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
        _ state: MonaHighContrastState,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaHighContrastState) -> Void
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
    /// disposal, listeners are dropped and `toggleHighContrast()` /
    /// `invalidatePaintState()` / `confirmReadOnly` / `publishToggle` are
    /// no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        if !already {
            toggleEmitter.dispose()
            paintEmitter.dispose()
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

    /// The plain-text fallback language. toggleHighContrast needs no
    /// tokenization; it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — toggleHighContrast performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
