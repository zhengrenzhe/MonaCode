// MonaMenuRegistryTests.swift
//
// P05-T004 — Implement menu, menu-item, and menu-command registries.
//
// Verifies the Core menu registry (`MonaMenuRegistry`) and the generated builtin
// menu table (`MonaBuiltinMenus`):
//   - Exactly 18 menus / 121 menu-items / 21 menu-commands (verbatim, no
//     rename / coalesce, source-ordered, ordinals stable).
//   - group / order / when / enablement / submenu / alternative / command
//     arguments evaluate deterministically (reusing `MonaContextKey` /
//     `MonaPreconditionEvaluator` + `MonaKeybindingContext` from P05-T002).
//   - The platform-neutral `MonaMenuModel` is well-formed and consumable by the
//     AppKit context-menu gateway's expected shape (action / separator /
//     submenu cases mirroring `MonaAppMenuItem`).
//   - Disposal is idempotent and NSLock-guarded.
//
// On Green, `testMenuRegistryContractLeaf` prints the contract line:
//     REGISTRY menus=18 menuItems=121 menuCommands=21 idempotent=pass

import XCTest
import MonaCode

final class MonaMenuRegistryTests: XCTestCase {

    // MARK: - 1. Counts — 18 / 121 / 21

    func testBuiltinTableHasExactly18Menus121Items21Commands() {
        XCTAssertEqual(MonaBuiltinMenus.menus.count, 18)
        XCTAssertEqual(MonaBuiltinMenus.menuItems.count, 121)
        XCTAssertEqual(MonaBuiltinMenus.menuCommands.count, 21)
    }

    func testRegistryReportsExactCounts() {
        let registry = MonaMenuRegistry()
        XCTAssertEqual(registry.menuCount, 18)
        XCTAssertEqual(registry.menuItemCount, 121)
        XCTAssertEqual(registry.menuCommandCount, 21)
        // All builtin menus/items/commands are retained (no cut dispositions).
        XCTAssertEqual(registry.liveMenuCount, 18)
        XCTAssertEqual(registry.liveMenuItemCount, 121)
        XCTAssertEqual(registry.liveMenuCommandCount, 21)
    }

    // MARK: - 2. Source order + ordinal stability

    func testMenuOrdinalsAreStableZeroBasedSourceOrder() {
        let menus = MonaBuiltinMenus.menus
        XCTAssertEqual(menus.map { $0.id }, MonaMenuRegistry.frozenMenus.map { $0.id })
        // First 5 menu ids in manifest source order.
        let expectedFirst = ["CommandPalette", "DiffEditorHunkToolbar", "DiffEditorSelectionToolbar", "EditorContext", "EditorContextPeek"]
        XCTAssertEqual(Array(menus.prefix(5)).map { $0.id }, expectedFirst)
        // Last 3 menu ids.
        let expectedLast = ["SimpleEditorContext", "StickyScrollContext", "suggestWidgetStatusBar"]
        XCTAssertEqual(Array(menus.suffix(3)).map { $0.id }, expectedLast)
    }

    func testMenuItemGlobalOrdinalsAreStableZeroBasedSourceOrder() {
        let items = MonaBuiltinMenus.menuItems
        // Global ordinal is the stable identity: 0..120, unique, source-ordered.
        XCTAssertEqual(items.map { $0.ordinal }, Array(0..<121))
        // First 3 items belong to CommandPalette.
        XCTAssertEqual(items[0].menuId, "CommandPalette")
        XCTAssertEqual(items[0].sourceOrdinal, 0)
        XCTAssertEqual(items[0].commandId, "undo")
        XCTAssertEqual(items[1].commandId, "redo")
        XCTAssertEqual(items[2].commandId, "editor.action.selectAll")
        // Last item is suggestWidgetStatusBar ordinal 7.
        XCTAssertEqual(items[120].menuId, "suggestWidgetStatusBar")
        XCTAssertEqual(items[120].sourceOrdinal, 7)
    }

    func testMenuItemPerMenuSourceOrdinalsMatchManifest() {
        // Per-menu sourceOrdinal restarts at 0 within each menu and is preserved
        // verbatim (no rename / coalesce). Two items in different menus MAY
        // share a sourceOrdinal; the global ordinal disambiguates.
        let registry = MonaMenuRegistry()
        let editorContext = registry.items(in: "EditorContext")
        XCTAssertEqual(editorContext.count, 19)
        XCTAssertEqual(editorContext.map { $0.sourceOrdinal }, Array(0..<19))
        // The EditorContext submenu item (ordinal 2) references EditorContextCopy.
        let submenuItem = editorContext.first { $0.submenuId != nil }
        XCTAssertNotNil(submenuItem)
        XCTAssertEqual(submenuItem?.submenuId, "EditorContextCopy")
        XCTAssertNil(submenuItem?.commandId)
    }

    func testNoMenuItemIdentityCoalescing() {
        // Even when the same command id repeats (e.g. diffEditor.revert appears
        // in multiple menus), each menu-item identity is distinct (global ordinal
        // is the stable identity).
        let ordinals = MonaBuiltinMenus.menuItems.map { $0.ordinal }
        XCTAssertEqual(Set(ordinals).count, ordinals.count)
        // diffEditor.revert appears in 3 distinct menu-items.
        let reverts = MonaBuiltinMenus.menuItems.filter { $0.commandId == "diffEditor.revert" }
        XCTAssertGreaterThanOrEqual(reverts.count, 3)
        XCTAssertEqual(Set(reverts.map { $0.ordinal }).count, reverts.count)
    }

    func testMenuCommandOrdinalsAreStableZeroBasedSourceOrder() {
        let cmds = MonaBuiltinMenus.menuCommands
        XCTAssertEqual(cmds.map { $0.ordinal }, Array(0..<21))
        XCTAssertEqual(cmds[0].id, "diffEditor.collapseAllUnchangedRegions")
        XCTAssertEqual(cmds[20].id, "editor.action.toggleTabFocusMode")
    }

    // MARK: - 3. group / order / when / enablement / submenu / alternative / args

    func testGroupOrderWhenEnablementFieldsArePreservedVerbatim() {
        let registry = MonaMenuRegistry()
        let editorContext = registry.items(in: "EditorContext")
        // The refactor item carries group, order, when, and enablement.
        let refactor = editorContext.first { $0.commandId == "editor.action.refactor" }
        XCTAssertNotNil(refactor)
        XCTAssertEqual(refactor?.group, "1_modification")
        XCTAssertEqual(refactor?.order, 2)
        XCTAssertEqual(refactor?.whenExpression, "editorHasCodeActionsProvider && !editorReadonly && supportedCodeAction =~ /(\\s|^)refactor\\b/")
        XCTAssertEqual(refactor?.enablement, "editorHasCodeActionsProvider && !editorReadonly")
    }

    func testSubmenuItemsCarrySubmenuIdAndTitle() {
        let registry = MonaMenuRegistry()
        // 5 submenu items total across all menus.
        let submenus = registry.menuItems.filter { $0.submenuId != nil }
        XCTAssertEqual(submenus.count, 5)
        // EditorContext ordinal 7 → EditorContextPeek submenu.
        let peek = registry.items(in: "EditorContext").first { $0.commandId == nil && $0.submenuId == "EditorContextPeek" }
        XCTAssertNotNil(peek)
        XCTAssertEqual(peek?.title, "Peek")
        XCTAssertEqual(peek?.group, "navigation")
        XCTAssertEqual(peek?.order, 100)
    }

    func testAlternativeFieldIsSupportedButAbsentInBuiltins() {
        // The model supports an `alternativeCommandId` field (per the spec), but
        // no builtin menu-item in 0.56.0 carries an alternative. The field is
        // nil for all 121 items — proving the field is wired without inventing
        // data the manifest does not contain.
        for item in MonaBuiltinMenus.menuItems {
            XCTAssertNil(item.alternativeCommandId)
        }
    }

    func testToggledStatePreservedForToggleCommands() {
        // editor.action.toggleStickyScroll (CommandPalette ordinal 27) carries a
        // toggled condition referencing config.editor.stickyScroll.enabled.
        let toggle = MonaBuiltinMenus.menuItems.first { $0.commandId == "editor.action.toggleStickyScroll" && $0.menuId == "CommandPalette" }
        XCTAssertNotNil(toggle)
        XCTAssertEqual(toggle?.toggled, "config.editor.stickyScroll.enabled")
    }

    // MARK: - 4. Deterministic when / enablement / toggled evaluation

    func testIsVisibleEvaluatesWhenClauseDeterministically() {
        let registry = MonaMenuRegistry()
        let context = MonaKeybindingContext()
            .with("editorHasCodeActionsProvider", .bool(true))
            .with("editorReadonly", .bool(false))
            .with("supportedCodeAction", .string("refactor"))
        // The refactor item is visible when its when-clause holds.
        let refactorOrdinal = registry.items(in: "EditorContext").first { $0.commandId == "editor.action.refactor" }!.ordinal
        XCTAssertTrue(registry.isVisible(refactorOrdinal, context: context))
        // Invisible when the when-clause fails (readonly editor).
        let readonly = context.with("editorReadonly", .bool(true))
        XCTAssertFalse(registry.isVisible(refactorOrdinal, context: readonly))
        // A nil when-clause is unconditionally visible.
        let undoOrdinal = registry.items(in: "CommandPalette")[0].ordinal
        XCTAssertTrue(registry.isVisible(undoOrdinal, context: MonaKeybindingContext()))
    }

    func testIsEnabledEvaluatesEnablementDeterministically() {
        let registry = MonaMenuRegistry()
        let context = MonaKeybindingContext()
            .with("editorHasCodeActionsProvider", .bool(true))
            .with("editorReadonly", .bool(false))
        let refactorOrdinal = registry.items(in: "EditorContext").first { $0.commandId == "editor.action.refactor" }!.ordinal
        XCTAssertTrue(registry.isEnabled(refactorOrdinal, context: context))
        // Disabled when the command precondition fails.
        let readonly = context.with("editorReadonly", .bool(true))
        XCTAssertFalse(registry.isEnabled(refactorOrdinal, context: readonly))
        // A nil enablement is unconditionally enabled.
        let undoOrdinal = registry.items(in: "CommandPalette")[0].ordinal
        XCTAssertTrue(registry.isEnabled(undoOrdinal, context: MonaKeybindingContext()))
    }

    func testIsToggledEvaluatesToggledConditionDeterministically() {
        let registry = MonaMenuRegistry()
        let on = MonaKeybindingContext().with("config.editor.stickyScroll.enabled", .bool(true))
        let off = MonaKeybindingContext().with("config.editor.stickyScroll.enabled", .bool(false))
        let toggleOrdinal = MonaBuiltinMenus.menuItems.first { $0.commandId == "editor.action.toggleStickyScroll" && $0.menuId == "CommandPalette" }!.ordinal
        XCTAssertTrue(registry.isToggled(toggleOrdinal, context: on))
        XCTAssertFalse(registry.isToggled(toggleOrdinal, context: off))
        // An item with no toggled state is never toggled.
        let undoOrdinal = registry.items(in: "CommandPalette")[0].ordinal
        XCTAssertFalse(registry.isToggled(undoOrdinal, context: on))
    }

    func testMenuCommandEnablementEvaluatesDeterministically() {
        let registry = MonaMenuRegistry()
        let inDiff = MonaKeybindingContext().with("isInDiffEditor", .bool(true))
        let notDiff = MonaKeybindingContext()
        // diffEditor.revert is a menu-command gated on isInDiffEditor.
        XCTAssertTrue(registry.isMenuCommandEnabled("diffEditor.revert", context: inDiff))
        XCTAssertFalse(registry.isMenuCommandEnabled("diffEditor.revert", context: notDiff))
        // editor.action.toggleTabFocusMode has no precondition → always enabled.
        XCTAssertTrue(registry.isMenuCommandEnabled("editor.action.toggleTabFocusMode", context: notDiff))
    }

    // MARK: - 5. Neutral menu model (consumable by the AppKit gateway)

    func testBuildModelProducesWellFormedNeutralModel() {
        let registry = MonaMenuRegistry()
        let context = MonaKeybindingContext()
            .with("editorReadonly", .bool(false))
            .with("editorHasDefinitionProvider", .bool(true))
            .with("editorHasReferenceProvider", .bool(true))
            .with("editorHasCodeActionsProvider", .bool(true))
        guard let model = registry.buildModel(menuId: "EditorContext", context: context) else {
            return XCTFail("expected a model for EditorContext")
        }
        XCTAssertEqual(model.id, "EditorContext")
        // The model is non-empty and every item is one of the three gateway-
        // consumable cases (action / separator / submenu).
        XCTAssertFalse(model.items.isEmpty)
        for item in model.items {
            switch item {
            case .action, .separator, .submenu:
                break
            }
        }
        // Groups are separated by separators (more than one group present).
        let groupCount = Set(registry.items(in: "EditorContext").map { $0.group }).count
        if groupCount > 1 {
            XCTAssertTrue(model.items.contains(.separator))
        }
    }

    func testBuildModelActionCarriesEvaluatedEnabledAndCheckedState() {
        let registry = MonaMenuRegistry()
        let context = MonaKeybindingContext()
            .with("editorReadonly", .bool(false))
            .with("editorHasCodeActionsProvider", .bool(true))
            .with("supportedCodeAction", .string("refactor"))
        let model = registry.buildModel(menuId: "EditorContext", context: context)!
        // The refactor action is present and enabled.
        let actions: [MonaMenuModelItem] = model.items.compactMap {
            if case let .action(id, _, _, isEnabled, _) = $0, id == "editor.action.refactor" { return $0 } else { return nil }
        }
        XCTAssertEqual(actions.count, 1)
        if case let .action(_, _, _, isEnabled, _) = actions[0] {
            XCTAssertTrue(isEnabled)
        }
        // A toggle command projects its checked state.
        let toggleModel = registry.buildModel(menuId: "MenubarAppearanceMenu", context: MonaKeybindingContext().with("config.editor.stickyScroll.enabled", .bool(true)))!
        let toggleAction = toggleModel.items.compactMap { item -> MonaMenuModelItem? in
            if case let .action(id, _, _, _, isChecked) = item, id == "editor.action.toggleStickyScroll" { return item } else { return nil }
        }
        XCTAssertEqual(toggleAction.count, 1)
        if case let .action(_, _, _, _, isChecked) = toggleAction[0] {
            XCTAssertTrue(isChecked)
        }
    }

    func testBuildModelSubmenuResolvesSubItemsWhenTargetMenuRegistered() {
        let registry = MonaMenuRegistry()
        let context = MonaKeybindingContext()
            .with("editorHasDefinitionProvider", .bool(true))
            .with("editorHasDeclarationProvider", .bool(true))
            .with("editorHasTypeDefinitionProvider", .bool(true))
            .with("editorHasImplementationProvider", .bool(true))
            .with("editorHasReferenceProvider", .bool(true))
        // EditorContext contains a Peek submenu that references EditorContextPeek,
        // which IS a registered builtin menu — so its sub-items resolve.
        let model = registry.buildModel(menuId: "EditorContext", context: context)!
        let submenus = model.items.compactMap { item -> MonaMenuModelItem? in
            if case .submenu = item { return item } else { return nil }
        }
        XCTAssertFalse(submenus.isEmpty)
        // At least one submenu resolved to the EditorContextPeek sub-model.
        let resolvedSubmenus = submenus.compactMap { item -> [MonaMenuModelItem]? in
            if case let .submenu(_, items, _) = item { return items.isEmpty ? nil : items } else { return nil }
        }
        XCTAssertFalse(resolvedSubmenus.isEmpty, "the Peek submenu should resolve to EditorContextPeek's items")
    }

    func testBuildModelReturnsNilForUnknownMenu() {
        let registry = MonaMenuRegistry()
        XCTAssertNil(registry.buildModel(menuId: "no.such.menu", context: MonaKeybindingContext()))
    }

    func testNeutralModelShapeMirrorsAppKitGatewayCases() {
        // The neutral `MonaMenuModelItem` must be adaptable to
        // `MonaAppMenuItem` (action / separator / submenu) at the AppKit
        // boundary. Verify the case set matches one-to-one.
        let cases: [MonaMenuModelItem] = [
            .action(id: "x", label: "X", shortcut: nil, isEnabled: true, isChecked: false),
            .separator,
            .submenu(label: "Sub", items: [], isEnabled: true),
        ]
        XCTAssertEqual(cases.count, 3)
        // Shortcut round-trips.
        let shortcut = MonaMenuShortcut(keyText: "c", modifiers: .ctrlCmd)
        XCTAssertEqual(shortcut.keyText, "c")
        XCTAssertTrue(shortcut.modifiers.contains(.ctrlCmd))
    }

    // MARK: - 6. Disposal (idempotent, NSLock-guarded)

    func testDisposalIsIdempotent() {
        let registry = MonaMenuRegistry()
        XCTAssertFalse(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        registry.dispose()
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        // A disposed registry enables nothing and builds no models.
        let context = MonaKeybindingContext()
        XCTAssertFalse(registry.isEnabled(0, context: context))
        XCTAssertNil(registry.buildModel(menuId: "EditorContext", context: context))
    }

    // MARK: - 7. Contract leaf

    func testMenuRegistryContractLeaf() {
        let registry = MonaMenuRegistry()
        let menus = registry.liveMenuCount
        let items = registry.liveMenuItemCount
        let commands = registry.liveMenuCommandCount

        registry.dispose()
        registry.dispose()
        let idempotentPass = registry.isDisposed

        print("REGISTRY menus=\(menus) menuItems=\(items) menuCommands=\(commands) idempotent=\(idempotentPass ? "pass" : "fail")")

        XCTAssertEqual(menus, 18)
        XCTAssertEqual(items, 121)
        XCTAssertEqual(commands, 21)
        XCTAssertTrue(idempotentPass)
    }
}
