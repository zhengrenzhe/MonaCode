// MonaThemeRegistry.swift
//
// P05-T006 — Implement theme, token, color, icon, and Codicon registries.
//
// `MonaThemeRegistry` is the Swift counterpart of Monaco's
// `StandaloneThemeService` (monaco-editor 0.56.0). It owns the four builtin
// themes (`vs`, `vs-dark`, `hc-black`, `hc-light`), accepts custom themes via
// `defineTheme(_:)`, tracks the active theme, and emits a deterministic theme
// change event through the shared `MonaEmitter` whenever `setTheme(_:)`
// switches the active theme.
//
// The builtin themes and their token rules / editor color maps are transcribed
// verbatim in `MonaTokenTheme` / `MonaBuiltinThemes` (see MonaTokenTheme.swift).
// This file owns only the registry state machine and the change event.
//
// Semantics ported from Monaco and frozen by T1-R:
//
//   - Default theme: `vs-dark` (Monaco's standalone default), matching
//     `StandaloneThemeService` which boots on the dark builtin.
//   - Theme change events fire only on an actual switch: setting the same
//     theme id that is already active is a no-op (no event). Setting an
//     unknown id is rejected (the active theme is unchanged, no event).
//   - The change event carries both the previous and the new theme id so
//     listeners can diff without retaining prior state.
//   - High-contrast is derived from the active theme's base
//     (`hc-black` / `hc-light` -> true).
//   - Custom themes registered with `inherit: true` declare intent to fall
//     back to their `base` theme's colors/rules; the builtin four all carry
//     `inherit: false` (standalone definitions) and that is honored verbatim.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Describes a theme switch delivered to `MonaThemeRegistry.onDidChangeTheme`
/// listeners. Carries the previous theme id (nil for the initial activation)
/// and the newly active theme id.
public struct MonaThemeChange: Sendable, Equatable {
    public let oldThemeId: String?
    public let newThemeId: String
    public init(oldThemeId: String?, newThemeId: String) {
        self.oldThemeId = oldThemeId
        self.newThemeId = newThemeId
    }
}

/// The theme registry: owns the four builtin themes, accepts custom themes,
/// tracks the active theme, and emits a deterministic change event on switch.
///
/// Counterpart of Monaco's `StandaloneThemeService`. The active theme defaults
/// to `vs-dark`. `setTheme(_:)` fires `onDidChangeTheme` only on a real switch
/// to a known theme; setting the same id is a no-op and unknown ids are
/// rejected without firing.
public final class MonaThemeRegistry {

    /// The builtin theme ids in source-ordinal order.
    public static let builtinThemeIds: [String] = MonaBuiltinThemes.ids

    private let lock = NSLock()
    // The builtin themes are immutable; custom themes are appended here.
    private var customThemes: [String: MonaTokenTheme] = [:]
    // The id of the currently active theme. Boots on Monaco's standalone
    // default (`vs-dark`).
    private var _currentThemeId: String = "vs-dark"
    // The emitter backing `onDidChangeTheme`. Reused from B1-R (no parallel
    // event mechanism) per the reuse directive.
    private let changeEmitter = MonaEmitter<MonaThemeChange>()

    public init() {
        // Boots on the dark builtin theme, matching Monaco's
        // `StandaloneThemeService` standalone default.
    }

    // MARK: - Active theme

    /// The id of the currently active theme.
    public var currentThemeId: String {
        lock.lock(); defer { lock.unlock() }
        return _currentThemeId
    }

    /// The currently active theme definition.
    public var currentTheme: MonaTokenTheme {
        lock.lock(); defer { lock.unlock() }
        return resolvedTheme(for: _currentThemeId)
    }

    /// `true` when the active theme is a high-contrast theme (`hc-black` or
    /// `hc-light`).
    public var isHighContrast: Bool {
        currentTheme.isHighContrast
    }

    // MARK: - Theme switching

    /// Sets the active theme. Fires `onDidChangeTheme` only when `id` differs
    /// from the current theme and is a known (builtin or registered custom)
    /// theme. Setting the current id is a no-op; an unknown id is rejected
    /// (the active theme is unchanged and no event fires).
    public func setTheme(_ id: String) {
        lock.lock()
        let known = isKnownTheme(id)
        let same = (id == _currentThemeId)
        guard known, !same else {
            lock.unlock()
            return
        }
        let oldId = _currentThemeId
        _currentThemeId = id
        let change = MonaThemeChange(oldThemeId: oldId, newThemeId: id)
        lock.unlock()
        changeEmitter.fire(change)
    }

    /// Registers a custom theme. A custom theme with the same id as an
    /// existing custom theme replaces it. The four builtin ids cannot be
    /// overridden (a custom theme with a builtin id is stored alongside but
    /// `setTheme` still resolves to the builtin definition for that id — this
    /// mirrors Monaco, which does not let a standalone-defined theme clobber a
    /// builtin id).
    @discardableResult
    public func defineTheme(_ theme: MonaTokenTheme) -> Bool {
        lock.lock()
        customThemes[theme.id] = theme
        lock.unlock()
        return true
    }

    /// Looks up a theme by id (builtin or registered custom).
    public func theme(for id: String) -> MonaTokenTheme? {
        lock.lock(); defer { lock.unlock() }
        if let builtin = MonaBuiltinThemes.theme(for: id) { return builtin }
        return customThemes[id]
    }

    /// All available theme ids: the four builtins plus any registered custom
    /// themes, in source-then-registration order.
    public var availableThemes: [String] {
        lock.lock(); defer { lock.unlock() }
        var ids = Self.builtinThemeIds
        for id in customThemes.keys where !ids.contains(id) { ids.append(id) }
        return ids
    }

    // MARK: - Change event

    /// Subscribe to theme change events. The returned `MonaDisposable` removes
    /// the listener on `dispose()`. Reuses `MonaEmitter` (B1-R) — no parallel
    /// event mechanism.
    public var onDidChangeTheme: MonaEvent<MonaThemeChange> {
        changeEmitter.event
    }

    // MARK: - Private

    private func isKnownTheme(_ id: String) -> Bool {
        MonaBuiltinThemes.theme(for: id) != nil || customThemes[id] != nil
    }

    /// Returns the theme definition for `id`, falling back to the `vs-dark`
    /// builtin if the id is somehow unknown (defensive — `setTheme` guards
    /// this, but `currentTheme` must never return a missing value).
    private func resolvedTheme(for id: String) -> MonaTokenTheme {
        if let builtin = MonaBuiltinThemes.theme(for: id) { return builtin }
        if let custom = customThemes[id] { return custom }
        return MonaBuiltinThemes.theme(for: "vs-dark")!
    }
}
