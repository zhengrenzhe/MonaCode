// MonaMenuRegistry.swift
//
// P05-T004 — Implement menu, menu-item, and menu-command registries.
//
// `MonaMenuRegistry` holds the frozen menu / menu-item / menu-command identities
// of monaco-editor 0.56.0, registered in the source order recorded by the F1-R3
// scope manifest. Each menu-item identity carries its group, order, when-clause
// (visibility), enablement (command precondition), submenu reference,
// alternative command, toggled state, and icon — all evaluated in stable order
// through the shared `MonaContextKey` / `MonaPreconditionEvaluator` +
// `MonaKeybindingContext` mechanism established by P05-T002 (NO parallel
// when-clause / context-key mechanism).
//
// The frozen identities + their source order come from the F1-R3 scope manifest
// (`registries.menus` / `registries.menuItems` (the flattened `items` across the
// 18 menus) / `registries.menuCommands`), emitted WITHOUT renaming or coalescing
// (one Swift entry per manifest row). The global menu-item ordinal is the stable
// identity: two items MAY share a per-menu sourceOrdinal but the global ordinal
// is unique and preserves source order — same rule as P05-T002/T003.
//
// The registry also produces a platform-neutral `MonaMenuModel` (Foundation-only:
// a tree of menu → group → item) consumed by the native context-menu gateway
// (P04-T006's `MonaContextMenuGateway` in MonaCodeAppKit). The Core produces the
// neutral model; AppKit renders it to `NSMenu` via the `MonaAppMenuModel`
// projection. The neutral model's item cases (`.action` / `.separator` /
// `.submenu`) mirror `MonaAppMenuItem` one-to-one so the AppKit adaptation is
// trivial.
//
// Disposal is idempotent and NSLock-guarded: after `dispose()`, the registry is
// marked disposed and further `dispose()` calls are no-ops. A disposed registry
// still reports its frozen identity inventory (the identities are immutable) but
// enablement / visibility / model-building queries return disabled / empty.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaMenuIdentity

/// A frozen menu identity (a registered menu id), recorded in source order.
public struct MonaMenuIdentity: Hashable, Sendable {

    /// The menu id (e.g. `"EditorContext"`, `"CommandPalette"`).
    public let id: String

    /// The disposition (all builtin menus in 0.56.0 are `retained`).
    public let disposition: MonaRegistryDisposition

    /// The number of menu-items registered under this menu (verbatim from the
    /// manifest).
    public let itemCount: Int

    /// `true` when this menu is a live production identity.
    public var isLive: Bool { disposition.isLive }

    public init(id: String, disposition: MonaRegistryDisposition, itemCount: Int) {
        self.id = id
        self.disposition = disposition
        self.itemCount = itemCount
    }
}

// MARK: - MonaMenuItemIdentity

/// A frozen menu-item identity, recorded in flattened source order across all
/// 18 menus. The global `ordinal` is the stable identity; `sourceOrdinal` is the
/// per-menu ordinal recorded verbatim from the manifest (it restarts at 0 within
/// each menu and MAY repeat across menus — the global ordinal disambiguates).
///
/// A menu-item is EITHER a command item (`commandId != nil`) OR a submenu item
/// (`submenuId != nil`). It carries its group, order, when-clause (visibility),
/// enablement (command precondition), toggled state, icon, alternative command,
/// and category — evaluated in stable order through `MonaPreconditionEvaluator`.
public struct MonaMenuItemIdentity: Hashable, Sendable {

    /// The global source ordinal (`0..<121`). Stable identity — unique and
    /// source-ordered, preserved even when a command repeats across menus.
    public let ordinal: Int

    /// The parent menu id (e.g. `"EditorContext"`).
    public let menuId: String

    /// The per-menu source ordinal, verbatim from the manifest (restarts at 0
    /// within each menu; MAY repeat across menus).
    public let sourceOrdinal: Int

    /// The command id for a command item, or `nil` for a submenu item.
    public let commandId: String?

    /// The submenu id for a submenu item, or `nil` for a command item.
    public let submenuId: String?

    /// The display title.
    public let title: String

    /// The submenu grouping (e.g. `"1_modification"`, `"navigation"`). `""`
    /// when the manifest did not record a group.
    public let group: String

    /// The within-group order. `0` when the manifest did not record an order.
    public let order: Int

    /// The menu-item visibility when-clause, or `nil` for unconditional
    /// visibility. Evaluated via `MonaPreconditionEvaluator`.
    public let whenExpression: String?

    /// The command precondition (enablement when-clause), or `nil` for
    /// unconditional enablement. Evaluated via `MonaPreconditionEvaluator`.
    public let enablement: String?

    /// The checked-state (toggled) when-clause, or `nil` when the item is not
    /// a toggle. Evaluated via `MonaPreconditionEvaluator`.
    public let toggled: String?

    /// The icon id (e.g. `"light-bulb"`), or `nil` when the item has no icon.
    public let iconId: String?

    /// The alternative command id, or `nil`. The model supports this field (per
    /// the P05-T004 spec) but no builtin menu-item in 0.56.0 carries an
    /// alternative — it is `nil` for all 121 builtin items.
    public let alternativeCommandId: String?

    /// The command category (e.g. `"Diff Editor"`), or `nil`.
    public let category: String?

    /// `true` when this item is a live production identity. All builtin
    /// menu-items in 0.56.0 are implicitly retained (the manifest records no
    /// disposition on menu-items).
    public var isLive: Bool { true }

    /// `true` when this item is a submenu item (carries a submenu reference).
    public var isSubmenu: Bool { submenuId != nil }

    /// The visibility when-clause as a `MonaPrecondition`.
    public var whenPrecondition: MonaPrecondition { MonaPrecondition(whenExpression) }

    /// The enablement (command precondition) as a `MonaPrecondition`.
    public var enablementPrecondition: MonaPrecondition { MonaPrecondition(enablement) }

    /// The toggled state as a `MonaPrecondition`.
    public var toggledPrecondition: MonaPrecondition { MonaPrecondition(toggled) }

    public init(
        ordinal: Int,
        menuId: String,
        sourceOrdinal: Int,
        commandId: String?,
        submenuId: String?,
        title: String,
        group: String,
        order: Int,
        whenExpression: String?,
        enablement: String?,
        toggled: String?,
        iconId: String?,
        alternativeCommandId: String?,
        category: String?
    ) {
        self.ordinal = ordinal
        self.menuId = menuId
        self.sourceOrdinal = sourceOrdinal
        self.commandId = commandId
        self.submenuId = submenuId
        self.title = title
        self.group = group
        self.order = order
        self.whenExpression = whenExpression
        self.enablement = enablement
        self.toggled = toggled
        self.iconId = iconId
        self.alternativeCommandId = alternativeCommandId
        self.category = category
    }
}

// MARK: - MonaMenuCommandIdentity

/// A frozen menu-command identity (a command surfaced through a menu), recorded
/// in source order. Carries its title, enablement (precondition), icon, and
/// category.
public struct MonaMenuCommandIdentity: Hashable, Sendable {

    /// The global source ordinal (`0..<21`). Stable identity.
    public let ordinal: Int

    /// The command id (e.g. `"diffEditor.revert"`).
    public let id: String

    /// The display title.
    public let title: String

    /// The enablement (command precondition) when-clause, or `nil` for
    /// unconditional enablement. Evaluated via `MonaPreconditionEvaluator`.
    public let enablement: String?

    /// The icon id, or `nil` when the command has no icon.
    public let iconId: String?

    /// The command category, or `nil`.
    public let category: String?

    /// The enablement as a `MonaPrecondition`.
    public var enablementPrecondition: MonaPrecondition { MonaPrecondition(enablement) }

    /// `true` when this command is a live production identity. All builtin
    /// menu-commands in 0.56.0 are implicitly retained.
    public var isLive: Bool { true }

    public init(
        ordinal: Int,
        id: String,
        title: String,
        enablement: String?,
        iconId: String?,
        category: String?
    ) {
        self.ordinal = ordinal
        self.id = id
        self.title = title
        self.enablement = enablement
        self.iconId = iconId
        self.category = category
    }
}

// MARK: - Neutral menu model (platform-neutral, Foundation-only)

/// A platform-neutral keyboard shortcut projected onto a menu item. This is the
/// Foundation-only mirror of `MonaAppMenuShortcut` (P04-T006); the AppKit
/// boundary adapts one to the other.
public struct MonaMenuShortcut: Equatable, Hashable, Sendable {

    /// The key text (e.g. `"x"`, `"c"`), or `nil` when the item has no key
    /// equivalent.
    public let keyText: String?

    /// The modifier set (`MonaKeyMod`).
    public let modifiers: MonaKeyMod

    public init(keyText: String?, modifiers: MonaKeyMod) {
        self.keyText = keyText
        self.modifiers = modifiers
    }
}

/// One entry in the ordered, platform-neutral menu model. The three cases
/// (`.action` / `.separator` / `.submenu`) mirror `MonaAppMenuItem` (P04-T006)
/// one-to-one so the AppKit boundary can adapt a neutral model to a native
/// `NSMenu` with a trivial projection.
public enum MonaMenuModelItem: Equatable, Hashable, Sendable {

    /// An actionable menu item: opaque command id, display label, optional
    /// shortcut, evaluated enabled state, and evaluated checked state.
    case action(
        id: String,
        label: String,
        shortcut: MonaMenuShortcut?,
        isEnabled: Bool,
        isChecked: Bool
    )

    /// A separator between groups of items.
    case separator

    /// A submenu: display label, ordered sub-items, and evaluated enabled state.
    case submenu(label: String, items: [MonaMenuModelItem], isEnabled: Bool)
}

/// The ordered, platform-neutral menu model produced by `MonaMenuRegistry`,
/// consumed by the native context-menu gateway (P04-T006). Items are kept in
/// declaration order (grouped by `group`, separated by `.separator` between
/// distinct groups) so the native `NSMenu` preserves the Core ordering exactly.
public struct MonaMenuModel: Equatable, Hashable, Sendable {

    /// The menu id this model was built for.
    public let id: String

    /// The ordered menu items.
    public let items: [MonaMenuModelItem]

    public init(id: String, items: [MonaMenuModelItem]) {
        self.id = id
        self.items = items
    }
}

// MARK: - MonaMenuRegistry

/// Holds the frozen menu / menu-item / menu-command identities of
/// monaco-editor 0.56.0 in source order, and produces the platform-neutral
/// `MonaMenuModel` consumed by the native context-menu gateway.
///
/// All builtin identities are `retained` (no cut dispositions in 0.56.0's
/// menus). When-clause visibility, enablement (command precondition), and
/// toggled state are evaluated through the shared `MonaPreconditionEvaluator`
/// against a `MonaKeybindingContext` — the same mechanism P05-T002's command /
/// action registries and P04-T003's keybinding resolver use.
///
/// Disposal is idempotent and NSLock-guarded: after `dispose()`, the registry
/// is marked disposed and further `dispose()` calls are no-ops. A disposed
/// registry still reports its frozen identity inventory but enablement /
/// visibility / model-building return disabled / empty.
public final class MonaMenuRegistry {

    /// Every frozen menu identity in source order.
    public static let frozenMenus: [MonaMenuIdentity] = MonaBuiltinMenus.menus

    /// Every frozen menu-item identity in flattened source order (global
    /// `ordinal` is the stable identity).
    public static let frozenMenuItems: [MonaMenuItemIdentity] = MonaBuiltinMenus.menuItems

    /// Every frozen menu-command identity in source order.
    public static let frozenMenuCommands: [MonaMenuCommandIdentity] = MonaBuiltinMenus.menuCommands

    /// The live (retained) menu identities, in source order.
    public let menus: [MonaMenuIdentity]

    /// The live (retained) menu-item identities, in flattened source order.
    public let menuItems: [MonaMenuItemIdentity]

    /// The live (retained) menu-command identities, in source order.
    public let menuCommands: [MonaMenuCommandIdentity]

    /// A map from menu id to its identity, for O(1) lookup.
    private let menuById: [String: MonaMenuIdentity]

    /// A map from menu id to its items (in source order), for O(1) grouping.
    private let itemsByMenu: [String: [MonaMenuItemIdentity]]

    /// A map from global ordinal to its item identity, for O(1) lookup.
    private let itemByOrdinal: [Int: MonaMenuItemIdentity]

    /// A map from menu-command id to its identity, for O(1) lookup.
    private let menuCommandById: [String: MonaMenuCommandIdentity]

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates a registry populated with all frozen menu / menu-item /
    /// menu-command identities.
    public init() {
        let frozenMenus = Self.frozenMenus
        let frozenItems = Self.frozenMenuItems
        let frozenCommands = Self.frozenMenuCommands

        self.menus = frozenMenus.filter { $0.isLive }
        self.menuItems = frozenItems.filter { $0.isLive }
        self.menuCommands = frozenCommands.filter { $0.isLive }

        var mb: [String: MonaMenuIdentity] = [:]
        for m in frozenMenus where m.isLive { mb[m.id] = m }
        self.menuById = mb

        var ibm: [String: [MonaMenuItemIdentity]] = [:]
        for item in frozenItems where item.isLive {
            ibm[item.menuId, default: []].append(item)
        }
        self.itemsByMenu = ibm

        var ibo: [Int: MonaMenuItemIdentity] = [:]
        for item in frozenItems where item.isLive { ibo[item.ordinal] = item }
        self.itemByOrdinal = ibo

        var mcb: [String: MonaMenuCommandIdentity] = [:]
        for c in frozenCommands where c.isLive { mcb[c.id] = c }
        self.menuCommandById = mcb
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - Counts

    /// The total number of frozen menus (live + cut).
    public var menuCount: Int { Self.frozenMenus.count }
    /// The number of live (retained) menus.
    public var liveMenuCount: Int { menus.count }

    /// The total number of frozen menu-items (live + cut).
    public var menuItemCount: Int { Self.frozenMenuItems.count }
    /// The number of live (retained) menu-items.
    public var liveMenuItemCount: Int { menuItems.count }

    /// The total number of frozen menu-commands (live + cut).
    public var menuCommandCount: Int { Self.frozenMenuCommands.count }
    /// The number of live (retained) menu-commands.
    public var liveMenuCommandCount: Int { menuCommands.count }

    // MARK: - Lookup

    /// Returns the identity for `id`, or `nil` if no live menu is registered.
    public func identity(forMenu id: String) -> MonaMenuIdentity? {
        menuById[id]
    }

    /// Returns `true` when a live menu with `id` is registered.
    public func contains(menu id: String) -> Bool {
        menuById[id] != nil
    }

    /// Returns the menu-items registered under `menuId`, in source order, or
    /// `[]` when the menu is unknown.
    public func items(in menuId: String) -> [MonaMenuItemIdentity] {
        itemsByMenu[menuId] ?? []
    }

    /// Returns the menu-item identity for global `ordinal`, or `nil`.
    public func menuItemIdentity(forOrdinal ordinal: Int) -> MonaMenuItemIdentity? {
        itemByOrdinal[ordinal]
    }

    /// Returns the menu-command identity for `id`, or `nil`.
    public func menuCommandIdentity(for id: String) -> MonaMenuCommandIdentity? {
        menuCommandById[id]
    }

    /// Returns `true` when a live menu-command with `id` is registered.
    public func contains(menuCommand id: String) -> Bool {
        menuCommandById[id] != nil
    }

    // MARK: - Stable-order evaluation (group, order, when, enablement, submenu,
    // alternative, toggled, args)

    /// Evaluates whether the menu-item `ordinal` is VISIBLE in `context` (its
    /// `when` when-clause holds). A `nil` when-clause is unconditionally
    /// visible. Returns `false` when the item is unknown or the registry is
    /// disposed.
    public func isVisible(_ ordinal: Int, context: MonaKeybindingContext) -> Bool {
        guard !isDisposed else { return false }
        guard let item = itemByOrdinal[ordinal] else { return false }
        return MonaPreconditionEvaluator.evaluate(item.whenPrecondition, context: context)
    }

    /// Evaluates whether the menu-item `ordinal` is ENABLED in `context` (its
    /// command `enablement` precondition holds). A `nil` enablement is
    /// unconditionally enabled. Returns `false` when the item is unknown or the
    /// registry is disposed.
    public func isEnabled(_ ordinal: Int, context: MonaKeybindingContext) -> Bool {
        guard !isDisposed else { return false }
        guard let item = itemByOrdinal[ordinal] else { return false }
        guard item.commandId != nil else { return false }
        return MonaPreconditionEvaluator.evaluate(item.enablementPrecondition, context: context)
    }

    /// Evaluates whether the menu-item `ordinal` is TOGGLED (checked) in
    /// `context` (its `toggled` when-clause holds). Returns `false` when the
    /// item has no toggled state, is unknown, or the registry is disposed.
    public func isToggled(_ ordinal: Int, context: MonaKeybindingContext) -> Bool {
        guard !isDisposed else { return false }
        guard let item = itemByOrdinal[ordinal] else { return false }
        guard let toggled = item.toggled else { return false }
        return MonaPreconditionEvaluator.evaluate(MonaPrecondition(toggled), context: context)
    }

    /// Evaluates whether the menu-command `id` is enabled in `context` (its
    /// enablement precondition holds). A `nil` enablement is unconditionally
    /// enabled. Returns `false` when the command is unknown or the registry is
    /// disposed.
    public func isMenuCommandEnabled(_ id: String, context: MonaKeybindingContext) -> Bool {
        guard !isDisposed else { return false }
        guard let cmd = menuCommandById[id] else { return false }
        return MonaPreconditionEvaluator.evaluate(cmd.enablementPrecondition, context: context)
    }

    // MARK: - Neutral model production

    /// Builds the platform-neutral `MonaMenuModel` for `menuId`, evaluated
    /// against `context`.
    ///
    /// Items are filtered by their `when` (visibility) when-clause, grouped by
    /// `group` (sorted by `order` within each group, groups kept in
    /// first-appearance order), and separated by `.separator` between distinct
    /// groups. Command items project as `.action` with evaluated `isEnabled` /
    /// `isChecked`; submenu items project as `.submenu` whose sub-items are
    /// resolved when the referenced menu is a registered builtin (otherwise the
    /// submenu is emitted with an empty sub-model — a cleanly consumable
    /// placeholder).
    ///
    /// Returns `nil` when `menuId` is unknown or the registry is disposed.
    public func buildModel(menuId: String, context: MonaKeybindingContext) -> MonaMenuModel? {
        guard !isDisposed else { return nil }
        guard let menu = menuById[menuId] else { return nil }
        let items = itemsByMenu[menuId] ?? []
        let projected = buildItems(items, context: context, visited: [menuId])
        return MonaMenuModel(id: menu.id, items: projected)
    }

    /// Recursively projects a sorted, filtered, grouped item list into the
    /// neutral model. `visited` guards against submenu cycles.
    private func buildItems(
        _ items: [MonaMenuItemIdentity],
        context: MonaKeybindingContext,
        visited: Set<String>
    ) -> [MonaMenuModelItem] {
        // 1. Filter by visibility (when-clause).
        let visible = items.filter {
            MonaPreconditionEvaluator.evaluate($0.whenPrecondition, context: context)
        }
        guard !visible.isEmpty else { return [] }

        // 2. Group by `group`, preserving first-appearance order of groups.
        var groupOrder: [String] = []
        var byGroup: [String: [MonaMenuItemIdentity]] = [:]
        for item in visible {
            if byGroup[item.group] == nil {
                groupOrder.append(item.group)
                byGroup[item.group] = []
            }
            byGroup[item.group]?.append(item)
        }

        // 3. Within each group, sort by `order` (stable — preserves source order
        //    for ties, matching Monaco's menu rendering).
        var result: [MonaMenuModelItem] = []
        for (index, group) in groupOrder.enumerated() {
            if index > 0 {
                result.append(.separator)
            }
            let grouped = byGroup[group] ?? []
            let sorted = grouped.enumerated().map { (i, item) in
                (order: item.order, source: i, item: item)
            }.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.source < rhs.source
            }.map { $0.item }
            for item in sorted {
                if let submenuId = item.submenuId {
                    let subItems: [MonaMenuModelItem]
                    if visited.contains(submenuId) {
                        subItems = []
                    } else if let sub = itemsByMenu[submenuId] {
                        subItems = buildItems(sub, context: context, visited: visited.union([submenuId]))
                    } else {
                        subItems = []
                    }
                    result.append(.submenu(label: item.title, items: subItems, isEnabled: true))
                } else if let commandId = item.commandId {
                    let enabled = MonaPreconditionEvaluator.evaluate(item.enablementPrecondition, context: context)
                    let checked = item.toggled.map {
                        MonaPreconditionEvaluator.evaluate(MonaPrecondition($0), context: context)
                    } ?? false
                    result.append(.action(
                        id: commandId,
                        label: item.title,
                        shortcut: nil,
                        isEnabled: enabled,
                        isChecked: checked
                    ))
                }
            }
        }
        return result
    }

    // MARK: - Disposal

    /// Disposes the registry. Idempotent: calling it again is a no-op.
    ///
    /// After disposal, `isEnabled` / `isVisible` / `isToggled` / `buildModel`
    /// return disabled / empty. The frozen identity inventory remains queryable
    /// (identities are immutable).
    public func dispose() {
        _lock.lock()
        _isDisposed = true
        _lock.unlock()
    }
}
