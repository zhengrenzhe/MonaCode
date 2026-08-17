// MonaContextMenuGateway.swift
//
// P04-T006 — Project pointer, scroll, and context-menu events through AppKit.
//
// `MonaContextMenuGateway` is the SINGLE native boundary that builds a native
// `NSMenu` from the ordered Core menu model and presents it at a position
// resolved through the geometry barrier (P03-T007). The rest of Core operates
// on the platform-neutral menu model and never touches `NSMenu`/`NSMenuItem`.
// This is the one place where the Core menu model becomes a native menu.
//
// Responsibilities (per the I3-R4 closure):
//
//   1. Build a native `NSMenu` from the ordered Core menu model:
//        - action items   — title, enabled state, checked state, keyboard
//                           shortcut (keyEquivalent + modifierMask).
//        - separators     — `NSMenuItem.separator()`.
//        - submenus       — nested `NSMenu` with the same projection.
//        - shortcuts      — `MonaAppMenuShortcut.keyText` becomes the
//                           `NSMenuItem.keyEquivalent` (lowercased);
//                           `modifiers` become `keyEquivalentModifierMask`
//                           (Command→`.command` on macOS, Control→`.control`,
//                           Option→`.option`, Shift→`.shift`).
//   2. Present the context menu at the resolved position. The model position's
//      caret rect (viewport space) is resolved through the geometry barrier
//      before `NSMenu.popUp(positioning:at:in:)` is called.
//   3. Do NOT present when the geometry barrier cannot resolve the position
//      (typed unavailable reason) — the menu is not popped up at a stale
//      location.
//
// The menu model value types (`MonaAppMenuModel`, `MonaAppMenuItem`,
// `MonaAppMenuShortcut`) are the AppKit-native projection of the Core menu
// model. The Core `MonaMenuModel` (authored by P05-T004, `target: MonaCode`)
// will be adapted to `MonaAppMenuModel` at the AppKit boundary; P04-T006 owns
// the projection and the `NSMenu` construction contract so the context-menu
// gateway is testable in isolation before the Core registry lands.
//
// `MonaCodeAppKit` may `import AppKit`, `import CoreGraphics`,
// `import Foundation`, and `import MonaCode`.

import AppKit
import CoreGraphics
import Foundation
import MonaCode

// MARK: - MonaAppMenuShortcut

/// A platform-neutral keyboard shortcut projected onto a menu item.
///
/// `keyText` is the scan-independent produced text (e.g. "x" for Cut); it
/// becomes the `NSMenuItem.keyEquivalent` (lowercased). `modifiers` is the
/// `MonaKeyMod` set; it becomes `NSMenuItem.keyEquivalentModifierMask` with
/// the macOS mapping (CtrlCmd→`.command`, WinCtrl→`.control`, Alt→`.option`,
/// Shift→`.shift`).
public struct MonaAppMenuShortcut: Equatable, Hashable, Sendable {

    /// The key text (e.g. "x", "c", "v"), or `nil` when the item has no
    /// key equivalent.
    public let keyText: String?

    /// The modifier set.
    public let modifiers: MonaKeyMod

    /// Creates a menu shortcut.
    public init(keyText: String?, modifiers: MonaKeyMod) {
        self.keyText = keyText
        self.modifiers = modifiers
    }
}

// MARK: - MonaAppMenuItem

/// One entry in the ordered Core menu model, projected for native rendering.
///
/// Action items carry an opaque identifier, a display label, an optional
/// shortcut, an enabled flag, and a checked flag. Separators are rendered as
/// `NSMenuItem.separator()`. Submenus carry a label and an ordered sub-model.
public enum MonaAppMenuItem: Equatable, Hashable, Sendable {

    /// An actionable menu item.
    case action(
        id: String,
        label: String,
        shortcut: MonaAppMenuShortcut?,
        isEnabled: Bool,
        isChecked: Bool
    )

    /// A separator between groups of items.
    case separator

    /// A submenu.
    case submenu(label: String, items: [MonaAppMenuItem], isEnabled: Bool)
}

// MARK: - MonaAppMenuModel

/// The ordered Core menu model, projected for native rendering.
///
/// The AppKit-native projection of the Core `MonaMenuModel` (P05-T004). Items
/// are kept in declaration order so the native `NSMenu` preserves the Core
/// ordering exactly.
public struct MonaAppMenuModel: Equatable, Hashable, Sendable {

    /// The ordered menu items.
    public let items: [MonaAppMenuItem]

    /// Creates a menu model.
    public init(items: [MonaAppMenuItem]) {
        self.items = items
    }
}

// MARK: - MonaContextMenuGateway

/// The single native gateway that builds a native `NSMenu` from the ordered
/// Core menu model and presents it at a position resolved through the geometry
/// barrier.
///
/// Stateless: two calls with equal inputs produce equal `NSMenu` structures.
public final class MonaContextMenuGateway {

    /// Creates a gateway. The gateway is stateless; the initializer exists so
    /// callers hold an instance (matching the "one native gateway per editor"
    /// boundary) rather than reaching for statics.
    public init() {}

    // MARK: - Build NSMenu from the Core menu model

    /// Builds a native `NSMenu` from the ordered Core menu model.
    ///
    /// Items are appended in declaration order. Action items project their
    /// label, enabled state, checked state, and shortcut onto an `NSMenuItem`.
    /// Separators become `NSMenuItem.separator()`. Submenus become a nested
    /// `NSMenu` with the same projection.
    ///
    /// - Parameter model: The ordered Core menu model.
    /// - Returns: A native `NSMenu` mirroring the model. The menu has no title
    ///   (context menus are title-less); items are in declaration order.
    public func buildMenu(from model: MonaAppMenuModel) -> NSMenu {
        return buildMenu(from: model.items)
    }

    /// Recursively builds a native `NSMenu` from an ordered item list.
    private func buildMenu(from items: [MonaAppMenuItem]) -> NSMenu {
        let menu = NSMenu()
        // Context menus are title-less; autoenabling is left at the AppKit
        // default so per-item `isEnabled` is respected.
        for item in items {
            menu.addItem(buildItem(from: item))
        }
        return menu
    }

    /// Builds a native `NSMenuItem` (or separator) from one model item.
    private func buildItem(from item: MonaAppMenuItem) -> NSMenuItem {
        switch item {
        case .separator:
            return NSMenuItem.separator()

        case let .action(_, label, shortcut, isEnabled, isChecked):
            let nsItem = NSMenuItem(title: label, action: nil, keyEquivalent: "")
            if let shortcut = shortcut {
                nsItem.keyEquivalent = shortcut.keyText ?? ""
                nsItem.keyEquivalentModifierMask = Self.monaShortcutModifiers(for: shortcut.modifiers)
            }
            nsItem.isEnabled = isEnabled
            nsItem.state = isChecked ? .on : .off
            return nsItem

        case let .submenu(label, subItems, isEnabled):
            let nsItem = NSMenuItem(title: label, action: nil, keyEquivalent: "")
            nsItem.submenu = buildMenu(from: subItems)
            nsItem.isEnabled = isEnabled
            return nsItem
        }
    }

    // MARK: - Present at the resolved position

    /// Resolves the viewport-space rect used to anchor the context menu for a
    /// model position, through the geometry barrier.
    ///
    /// The caret rect for `position` (viewport space) is resolved from one
    /// complete generation. When the barrier is absent or returns a typed
    /// unavailable reason, this returns `nil` and the menu is NOT presented at
    /// a stale location.
    ///
    /// - Parameters:
    ///   - position: The model position anchoring the menu.
    ///   - view: The `NSView` hosting the editor (unused for resolution, which
    ///     answers in viewport/view space; reserved for the `present` path).
    ///   - barrier: The geometry barrier (P03-T007).
    /// - Returns: The resolved viewport-space rect, or `nil`.
    public func resolvePresentationRect(
        for position: MonaPosition,
        in view: NSView?,
        with barrier: MonaQueryGeometryBarrier?
    ) -> CGRect? {
        guard let barrier = barrier else { return nil }
        let result = barrier.caretRect(for: position)
        switch result {
        case .available(let rect):
            return rect
        case .unavailable:
            return nil
        }
    }

    /// Presents the context menu at the resolved position.
    ///
    /// Resolves the caret rect for `position` through the geometry barrier and
    /// pops the menu up at the rect's origin (in `view`'s coordinate space). If
    /// the barrier cannot resolve the position, the menu is NOT presented.
    ///
    /// - Parameters:
    ///   - menu: The native `NSMenu` built by `buildMenu(from:)`.
    ///   - position: The model position anchoring the menu.
    ///   - view: The `NSView` hosting the editor.
    ///   - barrier: The geometry barrier (P03-T007).
    /// - Returns: `true` when the menu was presented; `false` when the position
    ///   could not be resolved (no stale presentation).
    @discardableResult
    public func present(
        menu: NSMenu,
        at position: MonaPosition,
        in view: NSView,
        with barrier: MonaQueryGeometryBarrier?
    ) -> Bool {
        guard let rect = resolvePresentationRect(for: position, in: view, with: barrier) else {
            return false
        }
        // `popUp(positioning:at:in:)` with item=nil presents the whole menu at
        // the location, in `view`'s coordinate space.
        return menu.popUp(positioning: nil, at: rect.origin, in: view)
    }

    // MARK: - Static field translators

    /// Maps a `MonaKeyMod` shortcut modifier set to the AppKit modifier mask
    /// for a menu item's `keyEquivalentModifierMask`.
    ///
    /// On macOS, CtrlCmd (the accelerator) is Command, WinCtrl (secondary) is
    /// Control, Alt is Option, Shift is Shift.
    public static func monaShortcutModifiers(for modifiers: MonaKeyMod) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.ctrlCmd) { flags.insert(.command) }
        if modifiers.contains(.winCtrl) { flags.insert(.control) }
        if modifiers.contains(.alt)     { flags.insert(.option) }
        if modifiers.contains(.shift)   { flags.insert(.shift) }
        return flags
    }
}

// MARK: - MonaContextMenuGateway.Sendable

// The gateway holds no stored state, so it is safe to share across isolation
// boundaries.
extension MonaContextMenuGateway: @unchecked Sendable {}
