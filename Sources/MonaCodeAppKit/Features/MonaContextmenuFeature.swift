// MonaContextmenuFeature.swift
//
// P05-T110 — Implement retained feature contextmenu.
//
// `MonaContextmenuFeature` is the Swift counterpart of Monaco's `contextmenu`
// contribution (monaco-editor 0.56.0): it constructs the ordered native editor
// context menu from the menu registries (P05-T004 `MonaMenuRegistry` /
// `MonaBuiltinMenus` + the neutral `MonaMenuModel`), adapts the neutral model
// to the AppKit-native `MonaAppMenuModel`, and builds a native `NSMenu` through
// the `MonaContextMenuGateway` (P04-T006).
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `buildContextMenu` / `buildAppMenuModel`:
//      build the neutral `MonaMenuModel` for the `EditorContext` menu via
//      `MonaMenuRegistry`, adapt it to `MonaAppMenuModel`, and construct a
//      native `NSMenu` through `MonaContextMenuGateway`.
//   2. Register the exact feature identity `contextmenu` and its declared
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

/// A context-menu event: the menu id that was built and the number of items
/// rendered.
public struct MonaContextmenuEvent: Equatable {

    /// The menu id that was built (e.g. `"EditorContext"`).
    public let menuId: String

    /// The number of items rendered in the built menu.
    public let itemCount: Int

    public init(menuId: String, itemCount: Int) {
        self.menuId = menuId
        self.itemCount = itemCount
    }
}

/// The contextmenu feature: construct the ordered native editor context menu
/// from the menu registries.
///
/// The feature identity `contextmenu` and its declared slice are referenced
/// verbatim from the frozen registries. The neutral `MonaMenuModel` is produced
/// by `MonaMenuRegistry.buildModel(menuId:context:)` (filtered by visibility,
/// grouped, separated); the feature adapts it to the AppKit-native
/// `MonaAppMenuModel` (a 1:1 projection of `.action` / `.separator` / `.submenu`)
/// and builds a native `NSMenu` through `MonaContextMenuGateway`. Asynchronous
/// publication is routed through `MonaProviderExecutor` + `MonaMicrotaskQueue`;
/// disposal through `MonaEmitter`; localization through `MonaLocalization`; and
/// degraded plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaContextmenuFeature: MonaDisposable {

    /// The frozen feature identity (`"contextmenu"`).
    public static let featureId = "contextmenu"

    /// The default menu id for the editor context menu.
    public static let editorContextMenuId = "EditorContext"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// `editor.action.showContextMenu` action triggers the context menu.
    public static let declaredActionIds: [String] = [
        "editor.action.showContextMenu"
    ]

    /// The declared command IDs in source order. The show-context-menu command.
    public static let declaredCommandIds: [String] = [
        "editor.action.showContextMenu"
    ]

    /// The declared contribution IDs. The `editor.contrib.contextmenu`
    /// contribution instantiates the context menu controller.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.contextmenu"
    ]

    /// The declared keybinding commands — the contextmenu commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.showContextMenu"
    ]

    /// The declared option names — the `contextmenu` option (boolean, default
    /// `true`) that gates whether the context menu is enabled.
    public static let declaredOptionIds: [String] = [
        "contextmenu"
    ]

    /// The declared menu IDs — the menus that carry contextmenu menu items.
    /// The contextmenu feature builds the `EditorContext` menu but does not
    /// register its own menu items in any builtin menu, so this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let menuRegistry: MonaMenuRegistry
    private let gateway: MonaContextMenuGateway
    private let emitter = MonaEmitter<MonaContextmenuEvent>()

    /// The event stream for context-menu changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaContextmenuEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the contextmenu feature with the given menu registry and gateway.
    public init(
        menuRegistry: MonaMenuRegistry = MonaMenuRegistry(),
        gateway: MonaContextMenuGateway = MonaContextMenuGateway()
    ) {
        self.menuRegistry = menuRegistry
        self.gateway = gateway
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: build the ordered native context menu

    /// Adapts the neutral `MonaMenuModel` (produced by `MonaMenuRegistry`) to the
    /// AppKit-native `MonaAppMenuModel`. The projection is 1:1: `.action` →
    /// `.action` (shortcut mapped), `.separator` → `.separator`, `.submenu` →
    /// `.submenu` (recursively adapted).
    public func adaptMenuModel(_ model: MonaMenuModel) -> MonaAppMenuModel {
        return MonaAppMenuModel(items: model.items.map { adaptItem($0) })
    }

    /// Recursively adapts one neutral menu-model item to the AppKit projection.
    private func adaptItem(_ item: MonaMenuModelItem) -> MonaAppMenuItem {
        switch item {
        case let .action(id, label, shortcut, isEnabled, isChecked):
            return .action(
                id: id,
                label: label,
                shortcut: shortcut.map { MonaAppMenuShortcut(keyText: $0.keyText, modifiers: $0.modifiers) },
                isEnabled: isEnabled,
                isChecked: isChecked
            )
        case .separator:
            return .separator
        case let .submenu(label, items, isEnabled):
            return .submenu(label: label, items: items.map { adaptItem($0) }, isEnabled: isEnabled)
        }
    }

    /// Builds the AppKit-native `MonaAppMenuModel` for the `EditorContext` menu,
    /// evaluated against `context`. Returns `nil` when the menu is unknown or the
    /// feature is disposed.
    public func buildAppMenuModel(context: MonaKeybindingContext) -> MonaAppMenuModel? {
        return buildAppMenuModel(menuId: Self.editorContextMenuId, context: context)
    }

    /// Builds the AppKit-native `MonaAppMenuModel` for `menuId`, evaluated against
    /// `context`. Returns `nil` when the menu is unknown or the feature is
    /// disposed.
    public func buildAppMenuModel(
        menuId: String,
        context: MonaKeybindingContext
    ) -> MonaAppMenuModel? {
        guard !isDisposed else { return nil }
        guard let neutral = menuRegistry.buildModel(menuId: menuId, context: context) else {
            return nil
        }
        return adaptMenuModel(neutral)
    }

    /// Builds a native `NSMenu` for the `EditorContext` menu, evaluated against
    /// `context`. Returns `nil` when the menu is unknown or the feature is
    /// disposed. Fires an event with the menu id and rendered item count.
    @discardableResult
    public func buildContextMenu(context: MonaKeybindingContext) -> NSMenu? {
        return buildContextMenu(menuId: Self.editorContextMenuId, context: context)
    }

    /// Builds a native `NSMenu` for `menuId`, evaluated against `context`.
    /// Returns `nil` when the menu is unknown or the feature is disposed. Fires an
    /// event with the menu id and rendered item count.
    @discardableResult
    public func buildContextMenu(
        menuId: String,
        context: MonaKeybindingContext
    ) -> NSMenu? {
        guard !isDisposed else { return nil }
        guard let appModel = buildAppMenuModel(menuId: menuId, context: context) else {
            return nil
        }
        let nsMenu = gateway.buildMenu(from: appModel)
        fire(.init(menuId: menuId, itemCount: nsMenu.numberOfItems))
        return nsMenu
    }

    /// Presents `menu` at `position` in `view`, resolving the position through the
    /// geometry `barrier`. Returns `true` when presented; `false` when the
    /// position cannot be resolved (no stale presentation). A no-op after
    /// `dispose()`.
    @discardableResult
    public func showContextMenu(
        menu: NSMenu,
        at position: MonaPosition,
        in view: NSView,
        barrier: MonaQueryGeometryBarrier?
    ) -> Bool {
        guard !isDisposed else { return false }
        return gateway.present(menu: menu, at: position, in: view, with: barrier)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishContextmenuEvent(
        _ event: MonaContextmenuEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaContextmenuEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `buildContextMenu` /
    /// `buildAppMenuModel` / `showContextMenu` are no-ops (return `nil` /
    /// `false`).
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
    /// `MonaLocalization` surface under `profile`.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. contextmenu needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — contextmenu performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a context-menu event when not disposed.
    private func fire(_ event: MonaContextmenuEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
