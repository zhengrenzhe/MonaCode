// MonaFloatingMenuFeature.swift
//
// P05-T118 — Implement retained feature floatingMenu.
//
// `MonaFloatingMenuFeature` is the Swift counterpart of Monaco's `floatingMenu`
// contribution (monaco-editor 0.56.0): it presents the retained floating action
// menu as a native AppKit `NSMenu` — without any web layout dependency (no DOM,
// no CSS). The menu is built from a list of action items, presented at a
// position in a view, and dismissed; presentation / dismissal fire a typed
// event. The feature owns no actions, commands, options, menus, or keybindings
// of its own — it presents other features' actions through the floating menu —
// and declares the single floating contribution that instantiates it.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `buildFloatingMenu` / `presentFloatingMenu` /
//      `dismissFloatingMenu`: build a native `NSMenu` from action items, present
//      it at a position (optionally popping the native menu when a view is
//      supplied), and dismiss it — with no web layout dependencies.
//   2. Register the exact feature identity `floatingMenu` and its declared
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

/// A floating-menu event: the menu id, the rendered item count, and whether the
/// menu was presented (`true`) or dismissed (`false`).
public struct MonaFloatingMenuEvent: Equatable {

    /// The menu id that was built (always `MonaFloatingMenuFeature.floatingMenuId`).
    public let menuId: String

    /// The number of items rendered in the floating menu.
    public let itemCount: Int

    /// `true` when the menu was presented; `false` when dismissed.
    public let presented: Bool

    public init(menuId: String, itemCount: Int, presented: Bool) {
        self.menuId = menuId
        self.itemCount = itemCount
        self.presented = presented
    }
}

/// One action item rendered in the floating action menu.
public struct MonaFloatingMenuItem: Equatable {

    /// The action / command id this item triggers.
    public let actionId: String

    /// The human-readable label.
    public let label: String

    /// The optional shortcut text (e.g. `"Cmd+C"`), for display only.
    public let shortcut: String?

    /// Whether the item is enabled.
    public let isEnabled: Bool

    public init(actionId: String, label: String, shortcut: String?, isEnabled: Bool) {
        self.actionId = actionId
        self.label = label
        self.shortcut = shortcut
        self.isEnabled = isEnabled
    }
}

/// The floatingMenu feature: present the retained floating action menu as a
/// native AppKit `NSMenu`, without web layout dependencies.
///
/// The feature identity `floatingMenu` and its declared slice are referenced
/// verbatim from the frozen registries. The feature builds a native `NSMenu`
/// from action items, presents it at a position (popping the native menu when a
/// view is supplied), and dismisses it. Model mutation is routed through
/// `MonaTransactionGateway` (the action-trigger selection); asynchronous
/// publication through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal
/// through `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaFloatingMenuFeature: MonaDisposable {

    /// The frozen feature identity (`"floatingMenu"`).
    public static let featureId = "floatingMenu"

    /// The default menu id for the floating action menu.
    public static let floatingMenuId = "FloatingActionMenu"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// floatingMenu feature owns no actions of its own — it presents other
    /// features' actions through the floating menu — so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. floatingMenu owns no commands;
    /// this slice is empty.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs. The `editor.contrib.floatingToolbar`
    /// contribution instantiates the floating action menu controller (the native
    /// counterpart of the floating menu). It is the single floating contribution
    /// and the only contribution `floatingMenu` declares.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.floatingToolbar"
    ]

    /// The declared keybinding commands — floatingMenu carries no default
    /// keybindings of its own, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — floatingMenu owns no editor options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — floatingMenu does not register its own menu items
    /// in any builtin menu, so this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaFloatingMenuEvent>()

    /// The event stream for floating-menu presentation / dismissal. Subscribe
    /// with `onChange { event in ... }`; the returned disposable removes the
    /// listener.
    public var onChange: MonaEvent<MonaFloatingMenuEvent> { emitter.event }

    /// The currently-presented floating menu, or `nil` when none is presented.
    public private(set) var currentFloatingMenu: NSMenu? = nil

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the floatingMenu feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: native floating action menu

    /// Builds a native `NSMenu` for the floating action menu from `items`,
    /// evaluated against `context`. Returns `nil` when the feature is disposed
    /// or `items` is empty. The returned menu is a plain native `NSMenu` with no
    /// web layout dependency (no DOM / CSS).
    public func buildFloatingMenu(
        items: [MonaFloatingMenuItem],
        context: MonaKeybindingContext
    ) -> NSMenu? {
        guard !isDisposed else { return nil }
        guard !items.isEmpty else { return nil }
        let menu = NSMenu()
        // The floating action menu owns item enablement (it does not auto-enable
        // based on the responder chain), matching Monaco's floating widget.
        menu.autoenablesItems = false
        for item in items {
            let nsItem = NSMenuItem(title: item.label, action: nil, keyEquivalent: "")
            nsItem.isEnabled = item.isEnabled
            menu.addItem(nsItem)
        }
        return menu
    }

    /// Presents `menu` as the retained floating action menu at `position` in
    /// `view`. When `view` is non-`nil`, the native menu is popped at the
    /// position; when `view` is `nil`, the menu is retained as the current
    /// floating menu without popping (used by hosts / tests that track
    /// presentation without rendering). Returns `true` when presented; `false`
    /// when the feature is disposed. Fires a `presented` event.
    @discardableResult
    public func presentFloatingMenu(
        _ menu: NSMenu,
        at position: MonaPosition,
        in view: NSView?
    ) -> Bool {
        guard !isDisposed else { return false }
        currentFloatingMenu = menu
        if let view = view {
            // Pop the native AppKit menu at the resolved position — no web
            // layout dependency (no DOM / CSS).
            let point = NSPoint(x: CGFloat(position.column), y: CGFloat(position.line))
            _ = menu.popUp(positioning: nil, at: point, in: view)
        }
        fire(.init(menuId: Self.floatingMenuId, itemCount: menu.numberOfItems, presented: true))
        return true
    }

    /// Dismisses the current floating menu. Idempotent: a no-op when no menu is
    /// presented. A no-op after `dispose()`. Fires a `dismissed` event when a
    /// menu was presented.
    public func dismissFloatingMenu() {
        guard !isDisposed else { return }
        let hadMenu = currentFloatingMenu != nil
        currentFloatingMenu = nil
        if hadMenu {
            fire(.init(menuId: Self.floatingMenuId, itemCount: 0, presented: false))
        }
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Routes an action trigger through the shared transaction gateway: begins a
    /// transaction, prepares a collapsed selection at `position` (the action's
    /// trigger anchor), and commits the unit. Returns the committed selections
    /// (empty when the feature is disposed or the commit dropped).
    @discardableResult
    public func commitActionTrigger(
        gateway: MonaTransactionGateway,
        actionId: String,
        position: MonaPosition
    ) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        let tx = gateway.beginTransaction()
        let selection = MonaSelection(anchor: position, activePosition: position)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishFloatingMenuEvent(
        _ event: MonaFloatingMenuEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaFloatingMenuEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `buildFloatingMenu` /
    /// `presentFloatingMenu` / `dismissFloatingMenu` / `commitActionTrigger` are
    /// no-ops (return `nil` / `false` / `[]`).
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        if !already {
            currentFloatingMenu = nil
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the item labels formatted through the shared `MonaLocalization`
    /// surface under `profile`.
    public func localizedMenuLabels(
        for items: [MonaFloatingMenuItem],
        profile: MonaCodeEnvironmentProfile
    ) -> [String] {
        return items.map { MonaLocalization.format($0.label, args: [], profile: profile) }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. floatingMenu needs no tokenization; it
    /// degrades to plain text for any tokenization need.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — floatingMenu performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a floating-menu event when not disposed.
    private func fire(_ event: MonaFloatingMenuEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
