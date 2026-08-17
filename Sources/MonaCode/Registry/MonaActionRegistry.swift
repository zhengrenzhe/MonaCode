// MonaActionRegistry.swift
//
// P05-T002 — Implement command, action, contribution, and pure-text registries.
//
// `MonaActionRegistry` holds the frozen action identities and pure-text action
// identities of monaco-editor 0.56.0, registered in the source order recorded by
// the F1-R3 scope manifest. Each action identity exposes its enablement, its
// precondition (a when-clause evaluated via `MonaPreconditionEvaluator` against
// a `MonaKeybindingContext`), its toggled state, its argument shape, and an
// idempotent disposal path. Cut identities (the WebGPU debug action) are
// recorded as explicit UNAVAILABLE dispositions with NO live registration.
//
// The frozen identities + their source order come from the F1-R3 scope manifest
// (`registries.actions` and `registries.pureTextSupportedActions`), emitted
// WITHOUT renaming or coalescing (one Swift entry per manifest row).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaActionIdentity

/// A frozen action identity, recorded in source order.
public struct MonaActionIdentity: Hashable, Sendable {

    /// The ordinal (source position) within the actions registry.
    public let ordinal: Int

    /// The action ID (e.g. `"editor.action.setSelectionAnchor"`).
    public let id: String

    /// The disposition (retained vs cut).
    public let disposition: MonaRegistryDisposition

    /// The human-readable label.
    public let label: String

    /// The alias (alternative label for fuzzy matching).
    public let alias: String

    /// The precondition expression (when-clause), or `nil` for unconditional.
    public let precondition: String?

    /// `true` when this action has a default keybinding.
    public let hasKeybinding: Bool

    /// The keybinding weight, or `nil` when no keybinding.
    public let keybindingWeight: Int?

    /// The toggled-state expression (when-clause), or `nil` when the action is
    /// not a checkbox/toggle.
    public let toggled: String?

    /// The argument shape.
    public let argumentShape: MonaArgumentShape

    /// `true` when this action is a live production identity.
    public var isLive: Bool { disposition.isLive }

    /// The precondition as a `MonaPrecondition`.
    public var preconditionValue: MonaPrecondition { MonaPrecondition(precondition) }

    public init(
        ordinal: Int,
        id: String,
        disposition: MonaRegistryDisposition,
        label: String,
        alias: String,
        precondition: String?,
        hasKeybinding: Bool,
        keybindingWeight: Int?,
        toggled: String?,
        hasArguments: Bool,
        argumentSchema: String?
    ) {
        self.ordinal = ordinal
        self.id = id
        self.disposition = disposition
        self.label = label
        self.alias = alias
        self.precondition = precondition
        self.hasKeybinding = hasKeybinding
        self.keybindingWeight = keybindingWeight
        self.toggled = toggled
        self.argumentShape = MonaArgumentShape(
            hasArguments: hasArguments,
            schema: argumentSchema
        )
    }
}

// MARK: - MonaPureTextActionIdentity

/// A frozen pure-text action identity, recorded in source order.
///
/// Pure-text actions are command IDs resolvable via the command palette /
// standalone editor's `triggerEditorAction` without an explicit action
// descriptor. They carry only an ID and a disposition.
public struct MonaPureTextActionIdentity: Hashable, Sendable {

    /// The action ID (e.g. `"actions.find"`).
    public let id: String

    /// The disposition (retained vs cut).
    public let disposition: MonaRegistryDisposition

    /// `true` when this identity is a live production identity.
    public var isLive: Bool { disposition.isLive }

    public init(id: String, disposition: MonaRegistryDisposition) {
        self.id = id
        self.disposition = disposition
    }
}

// MARK: - MonaActionRegistry

/// Holds the frozen action identities and pure-text action identities of
/// monaco-editor 0.56.0 in source order.
///
/// Live (retained) actions are registered and queryable; cut actions (the
/// WebGPU debug identity) are recorded as UNAVAILABLE dispositions and are
/// never registered as live.
///
/// Disposal is idempotent: after `dispose()`, the registry is marked disposed
/// and further `dispose()` calls are no-ops. A disposed registry still reports
/// its frozen identity inventory but enablement queries return `false`.
public final class MonaActionRegistry {

    /// Every frozen action identity in source order (live + cut).
    public static let frozenIdentities: [MonaActionIdentity] = [
        MonaActionIdentity(ordinal: 0, id: "editor.action.setSelectionAnchor", disposition: .retained, label: "Set Selection Anchor", alias: "Set Selection Anchor", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 1, id: "editor.action.goToSelectionAnchor", disposition: .retained, label: "Go to Selection Anchor", alias: "Go to Selection Anchor", precondition: "selectionAnchorSet", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 2, id: "editor.action.selectFromAnchorToCursor", disposition: .retained, label: "Select from Anchor to Cursor", alias: "Select from Anchor to Cursor", precondition: "selectionAnchorSet", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 3, id: "editor.action.cancelSelectionAnchor", disposition: .retained, label: "Cancel Selection Anchor", alias: "Cancel Selection Anchor", precondition: "selectionAnchorSet", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 4, id: "editor.action.selectToBracket", disposition: .retained, label: "Select to Bracket", alias: "Select to Bracket", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"name\":\"args\",\"schema\":{\"properties\":{\"selectBrackets\":{\"default\":true,\"type\":\"boolean\"}},\"type\":\"object\"}}]}"),
        MonaActionIdentity(ordinal: 5, id: "editor.action.jumpToBracket", disposition: .retained, label: "Go to Bracket", alias: "Go to Bracket", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 6, id: "editor.action.removeBrackets", disposition: .retained, label: "Remove Brackets", alias: "Remove Brackets", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 7, id: "editor.action.moveCarretLeftAction", disposition: .retained, label: "Move Selected Text Left", alias: "Move Selected Text Left", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 8, id: "editor.action.moveCarretRightAction", disposition: .retained, label: "Move Selected Text Right", alias: "Move Selected Text Right", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 9, id: "editor.action.transposeLetters", disposition: .retained, label: "Transpose Letters", alias: "Transpose Letters", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 10, id: "editor.action.clipboardCopyWithSyntaxHighlightingAction", disposition: .retained, label: "Copy with Syntax Highlighting", alias: "Copy with Syntax Highlighting", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 11, id: "editor.action.refactor", disposition: .retained, label: "Refactor...", alias: "Refactor...", precondition: "editorHasCodeActionsProvider && !editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"name\":\"args\",\"schema\":{\"defaultSnippets\":[{\"body\":{\"kind\":\"\"}}],\"properties\":{\"apply\":{\"default\":\"ifSingle\",\"enum\":[\"first\",\"ifSingle\",\"never\"],\"type\":\"string\"},\"kind\":{\"type\":\"string\"},\"preferred\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]}"),
        MonaActionIdentity(ordinal: 12, id: "editor.action.sourceAction", disposition: .retained, label: "Source Action...", alias: "Source Action...", precondition: "editorHasCodeActionsProvider && !editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"name\":\"args\",\"schema\":{\"defaultSnippets\":[{\"body\":{\"kind\":\"\"}}],\"properties\":{\"apply\":{\"default\":\"ifSingle\",\"enum\":[\"first\",\"ifSingle\",\"never\"],\"type\":\"string\"},\"kind\":{\"type\":\"string\"},\"preferred\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]}"),
        MonaActionIdentity(ordinal: 13, id: "editor.action.organizeImports", disposition: .retained, label: "Organize Imports", alias: "Organize Imports", precondition: "!editorReadonly && supportedCodeAction =~ /(\\s|^)source\\.organizeImports\\b/", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 14, id: "editor.action.autoFix", disposition: .retained, label: "Auto Fix...", alias: "Auto Fix...", precondition: "!editorReadonly && supportedCodeAction =~ /(\\s|^)quickfix\\b/", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 15, id: "editor.action.fixAll", disposition: .retained, label: "Fix All", alias: "Fix All", precondition: "!editorReadonly && supportedCodeAction =~ /(\\s|^)source\\.fixAll\\b/", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 16, id: "codelens.showLensesInCurrentLine", disposition: .retained, label: "Show CodeLens Commands for Current Line", alias: "Show CodeLens Commands for Current Line", precondition: "editorHasCodeLensProvider", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 17, id: "editor.action.hideColorPicker", disposition: .retained, label: "Hide the Color Picker", alias: "Hide the Color Picker", precondition: "standaloneColorPickerVisible", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 18, id: "editor.action.insertColorWithStandaloneColorPicker", disposition: .retained, label: "Insert Color with Standalone Color Picker", alias: "Insert Color with Standalone Color Picker", precondition: "standaloneColorPickerFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 19, id: "editor.action.commentLine", disposition: .retained, label: "Toggle Line Comment", alias: "Toggle Line Comment", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 20, id: "editor.action.addCommentLine", disposition: .retained, label: "Add Line Comment", alias: "Add Line Comment", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 21, id: "editor.action.removeCommentLine", disposition: .retained, label: "Remove Line Comment", alias: "Remove Line Comment", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 22, id: "editor.action.blockComment", disposition: .retained, label: "Toggle Block Comment", alias: "Toggle Block Comment", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 23, id: "editor.action.showContextMenu", disposition: .retained, label: "Show Editor Context Menu", alias: "Show Editor Context Menu", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 24, id: "cursorUndo", disposition: .retained, label: "Cursor Undo", alias: "Cursor Undo", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 25, id: "cursorRedo", disposition: .retained, label: "Cursor Redo", alias: "Cursor Redo", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 26, id: "editor.action.pasteAs", disposition: .retained, label: "Paste As...", alias: "Paste As...", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"name\":\"args\",\"schema\":{\"oneOf\":[{\"properties\":{\"kind\":{\"type\":\"string\"}},\"required\":[\"kind\"],\"type\":\"object\"},{\"properties\":{\"preferences\":{\"items\":{\"type\":\"string\"},\"type\":\"array\"}},\"required\":[\"preferences\"],\"type\":\"object\"}]}}]}"),
        MonaActionIdentity(ordinal: 27, id: "editor.action.pasteAsText", disposition: .retained, label: "Paste as Text", alias: "Paste as Text", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 28, id: "actions.find", disposition: .retained, label: "Find", alias: "Find", precondition: "editorFocus || editorIsOpen", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 29, id: "editor.action.nextMatchFindAction", disposition: .retained, label: "Find Next", alias: "Find Next", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 30, id: "editor.action.previousMatchFindAction", disposition: .retained, label: "Find Previous", alias: "Find Previous", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 31, id: "editor.action.startFindReplaceAction", disposition: .retained, label: "Replace", alias: "Replace", precondition: "editorFocus || editorIsOpen", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 32, id: "editor.actions.findWithArgs", disposition: .retained, label: "Find with Arguments", alias: "Find with Arguments", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"name\":\"Open a new In-Editor Find Widget args\",\"schema\":{\"properties\":{\"findInSelection\":{\"type\":\"boolean\"},\"isCaseSensitive\":{\"type\":\"boolean\"},\"isRegex\":{\"type\":\"boolean\"},\"matchWholeWord\":{\"type\":\"boolean\"},\"preserveCase\":{\"type\":\"boolean\"},\"replaceString\":{\"type\":\"string\"},\"searchString\":{\"type\":\"string\"}}}}]}"),
        MonaActionIdentity(ordinal: 33, id: "actions.findWithSelection", disposition: .retained, label: "Find with Selection", alias: "Find with Selection", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 34, id: "editor.action.goToMatchFindAction", disposition: .retained, label: "Go to Match...", alias: "Go to Match...", precondition: "findWidgetVisible", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 35, id: "editor.action.nextSelectionMatchFindAction", disposition: .retained, label: "Find Next Selection", alias: "Find Next Selection", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 36, id: "editor.action.previousSelectionMatchFindAction", disposition: .retained, label: "Find Previous Selection", alias: "Find Previous Selection", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 37, id: "editor.unfold", disposition: .retained, label: "Unfold", alias: "Unfold", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"constraint\":{\"$function\":true},\"name\":\"Unfold editor argument\",\"schema\":{\"properties\":{\"direction\":{\"default\":\"down\",\"enum\":[\"up\",\"down\"],\"type\":\"string\"},\"levels\":{\"default\":1,\"type\":\"number\"},\"selectionLines\":{\"items\":{\"type\":\"number\"},\"type\":\"array\"}},\"type\":\"object\"}}]}"),
        MonaActionIdentity(ordinal: 38, id: "editor.unfoldRecursively", disposition: .retained, label: "Unfold Recursively", alias: "Unfold Recursively", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 39, id: "editor.fold", disposition: .retained, label: "Fold", alias: "Fold", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"constraint\":{\"$function\":true},\"name\":\"Fold editor argument\",\"schema\":{\"properties\":{\"direction\":{\"enum\":[\"up\",\"down\"],\"type\":\"string\"},\"levels\":{\"type\":\"number\"},\"selectionLines\":{\"items\":{\"type\":\"number\"},\"type\":\"array\"}},\"type\":\"object\"}}]}"),
        MonaActionIdentity(ordinal: 40, id: "editor.foldRecursively", disposition: .retained, label: "Fold Recursively", alias: "Fold Recursively", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 41, id: "editor.toggleFoldRecursively", disposition: .retained, label: "Toggle Fold Recursively", alias: "Toggle Fold Recursively", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 42, id: "editor.foldAll", disposition: .retained, label: "Fold All", alias: "Fold All", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 43, id: "editor.unfoldAll", disposition: .retained, label: "Unfold All", alias: "Unfold All", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 44, id: "editor.foldAllBlockComments", disposition: .retained, label: "Fold All Block Comments", alias: "Fold All Block Comments", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 45, id: "editor.foldAllMarkerRegions", disposition: .retained, label: "Fold All Regions", alias: "Fold All Regions", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 46, id: "editor.unfoldAllMarkerRegions", disposition: .retained, label: "Unfold All Regions", alias: "Unfold All Regions", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 47, id: "editor.foldAllExcept", disposition: .retained, label: "Fold All Except Selected", alias: "Fold All Except Selected", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 48, id: "editor.unfoldAllExcept", disposition: .retained, label: "Unfold All Except Selected", alias: "Unfold All Except Selected", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 49, id: "editor.toggleFold", disposition: .retained, label: "Toggle Fold", alias: "Toggle Fold", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 50, id: "editor.gotoParentFold", disposition: .retained, label: "Go to Parent Fold", alias: "Go to Parent Fold", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 51, id: "editor.gotoPreviousFold", disposition: .retained, label: "Go to Previous Folding Range", alias: "Go to Previous Folding Range", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 52, id: "editor.gotoNextFold", disposition: .retained, label: "Go to Next Folding Range", alias: "Go to Next Folding Range", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 53, id: "editor.createFoldingRangeFromSelection", disposition: .retained, label: "Create Folding Range from Selection", alias: "Create Folding Range from Selection", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 54, id: "editor.removeManualFoldingRanges", disposition: .retained, label: "Remove Manual Folding Ranges", alias: "Remove Manual Folding Ranges", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 55, id: "editor.toggleImportFold", disposition: .retained, label: "Toggle Import Fold", alias: "Toggle Import Fold", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 56, id: "editor.foldLevel1", disposition: .retained, label: "Fold Level 1", alias: "Fold Level 1", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 57, id: "editor.foldLevel2", disposition: .retained, label: "Fold Level 2", alias: "Fold Level 2", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 58, id: "editor.foldLevel3", disposition: .retained, label: "Fold Level 3", alias: "Fold Level 3", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 59, id: "editor.foldLevel4", disposition: .retained, label: "Fold Level 4", alias: "Fold Level 4", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 60, id: "editor.foldLevel5", disposition: .retained, label: "Fold Level 5", alias: "Fold Level 5", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 61, id: "editor.foldLevel6", disposition: .retained, label: "Fold Level 6", alias: "Fold Level 6", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 62, id: "editor.foldLevel7", disposition: .retained, label: "Fold Level 7", alias: "Fold Level 7", precondition: "foldingEnabled", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 63, id: "editor.action.fontZoomIn", disposition: .retained, label: "Increase Editor Font Size", alias: "Increase Editor Font Size", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 64, id: "editor.action.fontZoomOut", disposition: .retained, label: "Decrease Editor Font Size", alias: "Decrease Editor Font Size", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 65, id: "editor.action.fontZoomReset", disposition: .retained, label: "Reset Editor Font Size", alias: "Reset Editor Font Size", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 66, id: "editor.action.formatDocument", disposition: .retained, label: "Format Document", alias: "Format Document", precondition: "editorHasDocumentFormattingProvider && !editorReadonly && !inCompositeEditor", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 67, id: "editor.action.formatSelection", disposition: .retained, label: "Format Selection", alias: "Format Selection", precondition: "editorHasDocumentSelectionFormattingProvider && !editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 68, id: "editor.action.marker.next", disposition: .retained, label: "Go to Next Problem (Error, Warning, Info)", alias: "Go to Next Problem (Error, Warning, Info)", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 69, id: "editor.action.marker.prev", disposition: .retained, label: "Go to Previous Problem (Error, Warning, Info)", alias: "Go to Previous Problem (Error, Warning, Info)", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 70, id: "editor.action.marker.nextInFiles", disposition: .retained, label: "Go to Next Problem in Files (Error, Warning, Info)", alias: "Go to Next Problem in Files (Error, Warning, Info)", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 71, id: "editor.action.marker.prevInFiles", disposition: .retained, label: "Go to Previous Problem in Files (Error, Warning, Info)", alias: "Go to Previous Problem in Files (Error, Warning, Info)", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 72, id: "editor.action.copyLinesUpAction", disposition: .retained, label: "Copy Line Up", alias: "Copy Line Up", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 73, id: "editor.action.copyLinesDownAction", disposition: .retained, label: "Copy Line Down", alias: "Copy Line Down", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 74, id: "editor.action.duplicateSelection", disposition: .retained, label: "Duplicate Selection", alias: "Duplicate Selection", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 75, id: "editor.action.moveLinesUpAction", disposition: .retained, label: "Move Line Up", alias: "Move Line Up", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 76, id: "editor.action.moveLinesDownAction", disposition: .retained, label: "Move Line Down", alias: "Move Line Down", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 77, id: "editor.action.sortLinesAscending", disposition: .retained, label: "Sort Lines Ascending", alias: "Sort Lines Ascending", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 78, id: "editor.action.sortLinesDescending", disposition: .retained, label: "Sort Lines Descending", alias: "Sort Lines Descending", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 79, id: "editor.action.removeDuplicateLines", disposition: .retained, label: "Delete Duplicate Lines", alias: "Delete Duplicate Lines", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 80, id: "editor.action.trimTrailingWhitespace", disposition: .retained, label: "Trim Trailing Whitespace", alias: "Trim Trailing Whitespace", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 81, id: "editor.action.deleteLines", disposition: .retained, label: "Delete Line", alias: "Delete Line", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 82, id: "editor.action.indentLines", disposition: .retained, label: "Indent Line", alias: "Indent Line", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 83, id: "editor.action.outdentLines", disposition: .retained, label: "Outdent Line", alias: "Outdent Line", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 84, id: "editor.action.insertLineBefore", disposition: .retained, label: "Insert Line Above", alias: "Insert Line Above", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 85, id: "editor.action.insertLineAfter", disposition: .retained, label: "Insert Line Below", alias: "Insert Line Below", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 86, id: "deleteAllLeft", disposition: .retained, label: "Delete All Left", alias: "Delete All Left", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 87, id: "deleteAllRight", disposition: .retained, label: "Delete All Right", alias: "Delete All Right", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 88, id: "editor.action.joinLines", disposition: .retained, label: "Join Lines", alias: "Join Lines", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 89, id: "editor.action.transpose", disposition: .retained, label: "Transpose Characters around the Cursor", alias: "Transpose Characters around the Cursor", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 90, id: "editor.action.transformToUppercase", disposition: .retained, label: "Transform to Uppercase", alias: "Transform to Uppercase", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 91, id: "editor.action.transformToLowercase", disposition: .retained, label: "Transform to Lowercase", alias: "Transform to Lowercase", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 92, id: "editor.action.reverseLines", disposition: .retained, label: "Reverse lines", alias: "Reverse lines", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 93, id: "editor.action.transformToSnakecase", disposition: .retained, label: "Transform to Snake Case", alias: "Transform to Snake Case", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 94, id: "editor.action.transformToCamelcase", disposition: .retained, label: "Transform to Camel Case", alias: "Transform to Camel Case", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 95, id: "editor.action.transformToPascalcase", disposition: .retained, label: "Transform to Pascal Case", alias: "Transform to Pascal Case", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 96, id: "editor.action.transformToTitlecase", disposition: .retained, label: "Transform to Title Case", alias: "Transform to Title Case", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 97, id: "editor.action.transformToKebabcase", disposition: .retained, label: "Transform to Kebab Case", alias: "Transform to Kebab Case", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 98, id: "editor.action.rename", disposition: .retained, label: "Rename Symbol", alias: "Rename Symbol", precondition: "editorHasRenameProvider && !editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 99, id: "editor.action.triggerSuggest", disposition: .retained, label: "Trigger Suggest", alias: "Trigger Suggest", precondition: "editorHasCompletionItemProvider && !editorReadonly && !suggestWidgetVisible", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 100, id: "editor.action.resetSuggestSize", disposition: .retained, label: "Reset Suggest Widget Size", alias: "Reset Suggest Widget Size", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 101, id: "editor.action.inlineSuggest.trigger", disposition: .retained, label: "Trigger Inline Suggestion", alias: "Trigger Inline Suggestion", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"isOptional\":true,\"name\":\"args\",\"schema\":{\"oneOf\":[{\"properties\":{\"changeHintData\":{},\"explicit\":{\"type\":\"boolean\"},\"providerId\":{\"$ref\":\"vscode://schemas/inlineCompletionProviderIdArgs\"},\"showNoResultNotification\":{\"type\":\"boolean\"}},\"type\":\"object\"}]}}]}"),
        MonaActionIdentity(ordinal: 102, id: "editor.action.inlineSuggest.showNext", disposition: .retained, label: "Show Next Inline Suggestion", alias: "Show Next Inline Suggestion", precondition: "inlineSuggestionVisible && !editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 103, id: "editor.action.inlineSuggest.showPrevious", disposition: .retained, label: "Show Previous Inline Suggestion", alias: "Show Previous Inline Suggestion", precondition: "inlineSuggestionVisible && !editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 104, id: "editor.action.inlineSuggest.acceptNextWord", disposition: .retained, label: "Accept Next Word Of Inline Suggestion", alias: "Accept Next Word Of Inline Suggestion", precondition: "inlineSuggestionVisible && !editorReadonly", hasKeybinding: true, keybindingWeight: 101, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 105, id: "editor.action.inlineSuggest.acceptNextLine", disposition: .retained, label: "Accept Next Line Of Inline Suggestion", alias: "Accept Next Line Of Inline Suggestion", precondition: "inlineSuggestionVisible && !editorReadonly", hasKeybinding: true, keybindingWeight: 101, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 106, id: "editor.action.inlineSuggest.commit", disposition: .retained, label: "Accept Inline Suggestion", alias: "Accept Inline Suggestion", precondition: "inlineEditIsVisible || inlineSuggestionVisible", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 107, id: "editor.action.inlineSuggest.commitAlternativeAction", disposition: .retained, label: "Accept Inline Suggestion Alternative Action", alias: "Accept Inline Suggestion Alternative Action", precondition: "inlineEditIsVisible && inlineSuggestionAlternativeActionVisible", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 108, id: "editor.action.inlineSuggest.toggleShowCollapsed", disposition: .retained, label: "Toggle Inline Suggestions Show Collapsed", alias: "Toggle Inline Suggestions Show Collapsed", precondition: "true", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 109, id: "editor.action.inlineSuggest.hide", disposition: .retained, label: "Hide Inline Suggestion", alias: "Hide Inline Suggestion", precondition: "inlineEditIsVisible || inlineSuggestionVisible", hasKeybinding: true, keybindingWeight: 190, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 110, id: "editor.action.inlineSuggest.jump", disposition: .retained, label: "Jump to next inline edit", alias: "Jump to next inline edit", precondition: "inlineEditIsVisible", hasKeybinding: true, keybindingWeight: 201, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 111, id: "editor.action.inlineSuggest.dev.extractRepro", disposition: .retained, label: "Developer: Extract Inline Suggest State", alias: "Developer: Inline Suggest Extract Repro", precondition: "inlineEditIsVisible || inlineSuggestionVisible", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 112, id: "editor.action.debugEditorGpuRenderer", disposition: .cutWebGpuDebug, label: "Developer: Debug Editor GPU Renderer", alias: "Developer: Debug Editor GPU Renderer", precondition: "true", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 113, id: "editor.action.showHover", disposition: .retained, label: "Show or Focus Hover", alias: "Show or Focus Hover", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"name\":\"args\",\"schema\":{\"properties\":{\"focus\":{\"default\":\"focusIfVisible\",\"enum\":[\"noAutoFocus\",\"focusIfVisible\",\"autoFocusImmediately\"]}},\"type\":\"object\"}}]}"),
        MonaActionIdentity(ordinal: 114, id: "editor.action.showDefinitionPreviewHover", disposition: .retained, label: "Show Definition Preview Hover", alias: "Show Definition Preview Hover", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 115, id: "editor.action.hideHover", disposition: .retained, label: "Hide Hover", alias: "Hide Content Hover", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 116, id: "editor.action.scrollUpHover", disposition: .retained, label: "Scroll Up Hover", alias: "Scroll Up Hover", precondition: "editorHoverFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 117, id: "editor.action.scrollDownHover", disposition: .retained, label: "Scroll Down Hover", alias: "Scroll Down Hover", precondition: "editorHoverFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 118, id: "editor.action.scrollLeftHover", disposition: .retained, label: "Scroll Left Hover", alias: "Scroll Left Hover", precondition: "editorHoverFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 119, id: "editor.action.scrollRightHover", disposition: .retained, label: "Scroll Right Hover", alias: "Scroll Right Hover", precondition: "editorHoverFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 120, id: "editor.action.pageUpHover", disposition: .retained, label: "Page Up Hover", alias: "Page Up Hover", precondition: "editorHoverFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 121, id: "editor.action.pageDownHover", disposition: .retained, label: "Page Down Hover", alias: "Page Down Hover", precondition: "editorHoverFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 122, id: "editor.action.goToTopHover", disposition: .retained, label: "Go To Top Hover", alias: "Go To Top Hover", precondition: "editorHoverFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 123, id: "editor.action.goToBottomHover", disposition: .retained, label: "Go To Bottom Hover", alias: "Go To Bottom Hover", precondition: "editorHoverFocused", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 124, id: "editor.action.increaseHoverVerbosityLevel", disposition: .retained, label: "Increase Hover Verbosity Level", alias: "Increase Hover Verbosity Level", precondition: "editorHoverVisible", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 125, id: "editor.action.decreaseHoverVerbosityLevel", disposition: .retained, label: "Decrease Hover Verbosity Level", alias: "Decrease Hover Verbosity Level", precondition: "editorHoverVisible", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 126, id: "editor.action.indentationToSpaces", disposition: .retained, label: "Convert Indentation to Spaces", alias: "Convert Indentation to Spaces", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 127, id: "editor.action.indentationToTabs", disposition: .retained, label: "Convert Indentation to Tabs", alias: "Convert Indentation to Tabs", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 128, id: "editor.action.indentUsingTabs", disposition: .retained, label: "Indent Using Tabs", alias: "Indent Using Tabs", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 129, id: "editor.action.indentUsingSpaces", disposition: .retained, label: "Indent Using Spaces", alias: "Indent Using Spaces", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 130, id: "editor.action.changeTabDisplaySize", disposition: .retained, label: "Change Tab Display Size", alias: "Change Tab Display Size", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 131, id: "editor.action.detectIndentation", disposition: .retained, label: "Detect Indentation from Content", alias: "Detect Indentation from Content", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 132, id: "editor.action.reindentlines", disposition: .retained, label: "Reindent Lines", alias: "Reindent Lines", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 133, id: "editor.action.reindentselectedlines", disposition: .retained, label: "Reindent Selected Lines", alias: "Reindent Selected Lines", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 134, id: "editor.action.inPlaceReplace.up", disposition: .retained, label: "Replace with Previous Value", alias: "Replace with Previous Value", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 135, id: "editor.action.inPlaceReplace.down", disposition: .retained, label: "Replace with Next Value", alias: "Replace with Next Value", precondition: "!editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 136, id: "editor.action.insertFinalNewLine", disposition: .retained, label: "Insert Final New Line", alias: "Insert Final New Line", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 137, id: "expandLineSelection", disposition: .retained, label: "Expand Line Selection", alias: "Expand Line Selection", precondition: nil, hasKeybinding: true, keybindingWeight: 0, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 138, id: "editor.action.linkedEditing", disposition: .retained, label: "Start Linked Editing", alias: "Start Linked Editing", precondition: "editorHasRenameProvider && !editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 139, id: "editor.action.openLink", disposition: .retained, label: "Open Link", alias: "Open Link", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 140, id: "editor.action.insertCursorAbove", disposition: .retained, label: "Add Cursor Above", alias: "Add Cursor Above", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 141, id: "editor.action.insertCursorBelow", disposition: .retained, label: "Add Cursor Below", alias: "Add Cursor Below", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 142, id: "editor.action.insertCursorAtEndOfEachLineSelected", disposition: .retained, label: "Add Cursors to Line Ends", alias: "Add Cursors to Line Ends", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 143, id: "editor.action.addSelectionToNextFindMatch", disposition: .retained, label: "Add Selection to Next Find Match", alias: "Add Selection to Next Find Match", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 144, id: "editor.action.addSelectionToPreviousFindMatch", disposition: .retained, label: "Add Selection to Previous Find Match", alias: "Add Selection to Previous Find Match", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 145, id: "editor.action.moveSelectionToNextFindMatch", disposition: .retained, label: "Move Last Selection to Next Find Match", alias: "Move Last Selection to Next Find Match", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 146, id: "editor.action.moveSelectionToPreviousFindMatch", disposition: .retained, label: "Move Last Selection to Previous Find Match", alias: "Move Last Selection to Previous Find Match", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 147, id: "editor.action.selectHighlights", disposition: .retained, label: "Select All Occurrences of Find Match", alias: "Select All Occurrences of Find Match", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 148, id: "editor.action.changeAll", disposition: .retained, label: "Change All Occurrences", alias: "Change All Occurrences", precondition: "editorTextFocus && !editorReadonly", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 149, id: "editor.action.addCursorsToBottom", disposition: .retained, label: "Add Cursors to Bottom", alias: "Add Cursors to Bottom", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 150, id: "editor.action.addCursorsToTop", disposition: .retained, label: "Add Cursors to Top", alias: "Add Cursors to Top", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 151, id: "editor.action.focusNextCursor", disposition: .retained, label: "Focus Next Cursor", alias: "Focus Next Cursor", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[]}"),
        MonaActionIdentity(ordinal: 152, id: "editor.action.focusPreviousCursor", disposition: .retained, label: "Focus Previous Cursor", alias: "Focus Previous Cursor", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[]}"),
        MonaActionIdentity(ordinal: 153, id: "editor.action.triggerParameterHints", disposition: .retained, label: "Trigger Parameter Hints", alias: "Trigger Parameter Hints", precondition: "editorHasSignatureHelpProvider", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 154, id: "editor.action.smartSelect.expand", disposition: .retained, label: "Expand Selection", alias: "Expand Selection", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 155, id: "editor.action.smartSelect.shrink", disposition: .retained, label: "Shrink Selection", alias: "Shrink Selection", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 156, id: "editor.action.forceRetokenize", disposition: .retained, label: "Developer: Force Retokenize", alias: "Developer: Force Retokenize", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 157, id: "editor.action.wordHighlight.next", disposition: .retained, label: "Go to Next Symbol Highlight", alias: "Go to Next Symbol Highlight", precondition: "hasWordHighlights", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 158, id: "editor.action.wordHighlight.prev", disposition: .retained, label: "Go to Previous Symbol Highlight", alias: "Go to Previous Symbol Highlight", precondition: "hasWordHighlights", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 159, id: "editor.action.wordHighlight.trigger", disposition: .retained, label: "Trigger Symbol Highlight", alias: "Trigger Symbol Highlight", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 160, id: "deleteInsideWord", disposition: .retained, label: "Delete Word", alias: "Delete Word", precondition: "!editorReadonly", hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: true, argumentSchema: "{\"args\":[{\"name\":\"args\",\"schema\":{\"properties\":{\"onlyWord\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]}"),
        MonaActionIdentity(ordinal: 161, id: "editor.action.inspectTokens", disposition: .retained, label: "Developer: Inspect Tokens", alias: "Developer: Inspect Tokens", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 162, id: "editor.action.gotoLine", disposition: .retained, label: "Go to Line/Column...", alias: "Go to Line/Column...", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 163, id: "editor.action.gotoOffset", disposition: .retained, label: "Go to Offset...", alias: "Go to Offset...", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 164, id: "editor.action.quickOutline", disposition: .retained, label: "Go to Symbol...", alias: "Go to Symbol...", precondition: "editorHasDocumentSymbolProvider", hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 165, id: "editor.action.quickCommand", disposition: .retained, label: "Command Palette", alias: "Command Palette", precondition: nil, hasKeybinding: true, keybindingWeight: 100, toggled: nil, hasArguments: false, argumentSchema: nil),
        MonaActionIdentity(ordinal: 166, id: "editor.action.toggleHighContrast", disposition: .retained, label: "Toggle High Contrast Theme", alias: "Toggle High Contrast Theme", precondition: nil, hasKeybinding: false, keybindingWeight: nil, toggled: nil, hasArguments: false, argumentSchema: nil)
    ]

    /// Every frozen pure-text action identity in source order (live + cut).
    public static let frozenPureTextIdentities: [MonaPureTextActionIdentity] = [
        MonaPureTextActionIdentity(id: "actions.find", disposition: .retained),
        MonaPureTextActionIdentity(id: "actions.findWithSelection", disposition: .retained),
        MonaPureTextActionIdentity(id: "cursorRedo", disposition: .retained),
        MonaPureTextActionIdentity(id: "cursorUndo", disposition: .retained),
        MonaPureTextActionIdentity(id: "deleteAllLeft", disposition: .retained),
        MonaPureTextActionIdentity(id: "deleteAllRight", disposition: .retained),
        MonaPureTextActionIdentity(id: "deleteInsideWord", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.addCommentLine", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.addCursorsToBottom", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.addCursorsToTop", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.addSelectionToNextFindMatch", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.addSelectionToPreviousFindMatch", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.blockComment", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.changeTabDisplaySize", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.clipboardCopyWithSyntaxHighlightingAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.commentLine", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.copyLinesDownAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.copyLinesUpAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.debugEditorGpuRenderer", disposition: .cutWebGpuDebug),
        MonaPureTextActionIdentity(id: "editor.action.deleteLines", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.detectIndentation", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.duplicateSelection", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.focusNextCursor", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.focusPreviousCursor", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.fontZoomIn", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.fontZoomOut", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.fontZoomReset", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.forceRetokenize", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.gotoLine", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.gotoOffset", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.hideHover", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.inPlaceReplace.down", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.inPlaceReplace.up", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.indentLines", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.indentUsingSpaces", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.indentUsingTabs", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.indentationToSpaces", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.indentationToTabs", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.inlineSuggest.toggleShowCollapsed", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.inlineSuggest.trigger", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.insertCursorAbove", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.insertCursorAtEndOfEachLineSelected", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.insertCursorBelow", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.insertFinalNewLine", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.insertLineAfter", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.insertLineBefore", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.inspectTokens", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.joinLines", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.jumpToBracket", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.marker.next", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.marker.nextInFiles", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.marker.prev", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.marker.prevInFiles", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.moveCarretLeftAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.moveCarretRightAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.moveLinesDownAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.moveLinesUpAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.moveSelectionToNextFindMatch", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.moveSelectionToPreviousFindMatch", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.nextMatchFindAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.nextSelectionMatchFindAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.openLink", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.outdentLines", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.pasteAs", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.pasteAsText", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.previousMatchFindAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.previousSelectionMatchFindAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.quickCommand", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.reindentlines", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.reindentselectedlines", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.removeBrackets", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.removeCommentLine", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.removeDuplicateLines", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.resetSuggestSize", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.reverseLines", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.selectHighlights", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.selectToBracket", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.setSelectionAnchor", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.showContextMenu", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.showDefinitionPreviewHover", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.showHover", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.smartSelect.expand", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.smartSelect.shrink", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.sortLinesAscending", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.sortLinesDescending", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.startFindReplaceAction", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.toggleHighContrast", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transformToCamelcase", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transformToKebabcase", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transformToLowercase", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transformToPascalcase", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transformToSnakecase", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transformToTitlecase", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transformToUppercase", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transpose", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.transposeLetters", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.triggerSuggest", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.trimTrailingWhitespace", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.action.wordHighlight.trigger", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.actions.findWithArgs", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.createFoldingRangeFromSelection", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.fold", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldAll", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldAllBlockComments", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldAllExcept", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldAllMarkerRegions", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldLevel1", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldLevel2", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldLevel3", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldLevel4", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldLevel5", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldLevel6", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldLevel7", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.foldRecursively", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.gotoNextFold", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.gotoParentFold", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.gotoPreviousFold", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.removeManualFoldingRanges", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.toggleFold", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.toggleFoldRecursively", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.toggleImportFold", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.unfold", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.unfoldAll", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.unfoldAllExcept", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.unfoldAllMarkerRegions", disposition: .retained),
        MonaPureTextActionIdentity(id: "editor.unfoldRecursively", disposition: .retained),
        MonaPureTextActionIdentity(id: "expandLineSelection", disposition: .retained)
    ]

    /// The live (retained) action identities, in source order.
    public let liveIdentities: [MonaActionIdentity]

    /// The cut (UNAVAILABLE) action identities, in source order.
    public let cutIdentities: [MonaActionIdentity]

    /// The live (retained) pure-text action identities, in source order.
    public let livePureTextIdentities: [MonaPureTextActionIdentity]

    /// The cut (UNAVAILABLE) pure-text action identities, in source order.
    public let cutPureTextIdentities: [MonaPureTextActionIdentity]

    private let byId: [String: MonaActionIdentity]
    private let pureTextById: [String: MonaPureTextActionIdentity]
    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates a registry populated with all frozen action + pure-text identities.
    public init() {
        let frozen = Self.frozenIdentities
        let frozenPT = Self.frozenPureTextIdentities
        self.liveIdentities = frozen.filter { $0.isLive }
        self.cutIdentities = frozen.filter { !$0.isLive }
        self.livePureTextIdentities = frozenPT.filter { $0.isLive }
        self.cutPureTextIdentities = frozenPT.filter { !$0.isLive }
        var map: [String: MonaActionIdentity] = [:]
        for identity in frozen where identity.isLive {
            map[identity.id] = identity
        }
        self.byId = map
        var ptMap: [String: MonaPureTextActionIdentity] = [:]
        for identity in frozenPT where identity.isLive {
            ptMap[identity.id] = identity
        }
        self.pureTextById = ptMap
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - Counts

    public var actionCount: Int { Self.frozenIdentities.count }
    public var liveActionCount: Int { liveIdentities.count }
    public var cutActionCount: Int { cutIdentities.count }
    public var pureTextCount: Int { Self.frozenPureTextIdentities.count }
    public var livePureTextCount: Int { livePureTextIdentities.count }
    public var cutPureTextCount: Int { cutPureTextIdentities.count }

    // MARK: - Lookup

    /// Returns the action identity for `id`, or `nil` if no live action is
    /// registered with that ID.
    public func identity(for id: String) -> MonaActionIdentity? {
        byId[id]
    }

    /// Returns `true` when a live action with `id` is registered.
    public func contains(_ id: String) -> Bool {
        byId[id] != nil
    }

    /// Returns the pure-text action identity for `id`, or `nil` if no live
    /// pure-text action is registered with that ID.
    public func pureTextIdentity(for id: String) -> MonaPureTextActionIdentity? {
        pureTextById[id]
    }

    /// Returns `true` when a live pure-text action with `id` is registered.
    public func containsPureText(_ id: String) -> Bool {
        pureTextById[id] != nil
    }

    // MARK: - Enablement

    /// Evaluates whether the action `id` is enabled in `context`.
    ///
    /// An action is enabled when:
    ///   1. it is a live (retained) identity,
    ///   2. the registry is not disposed, and
    ///   3. its precondition (when-clause) evaluates to `true` against
    ///      `context` (a `nil` precondition is unconditionally enabled).
    public func isEnabled(_ id: String, context: MonaKeybindingContext) -> Bool {
        guard !isDisposed else { return false }
        guard let identity = byId[id] else { return false }
        return MonaPreconditionEvaluator.evaluate(identity.preconditionValue, context: context)
    }

    // MARK: - Precondition

    /// Returns the precondition for `id`, or `nil` if no live action is
    /// registered with that ID.
    public func precondition(for id: String) -> MonaPrecondition? {
        byId[id]?.preconditionValue
    }

    // MARK: - Toggled state

    /// Returns the toggled-state expression for `id`, or `nil` if the action is
    /// not a toggle or is not registered.
    public func toggled(for id: String) -> String? {
        byId[id]?.toggled
    }

    /// Evaluates whether the action `id` is toggled (checked) in `context`.
    /// Returns `false` when the action has no toggled state, is not registered,
    /// or the registry is disposed.
    public func isToggled(_ id: String, context: MonaKeybindingContext) -> Bool {
        guard !isDisposed else { return false }
        guard let identity = byId[id] else { return false }
        guard let toggled = identity.toggled else { return false }
        return MonaPreconditionEvaluator.evaluate(MonaPrecondition(toggled), context: context)
    }

    // MARK: - Argument shape

    /// Returns the argument shape for `id`, or `nil` if no live action is
    /// registered with that ID.
    public func argumentShape(for id: String) -> MonaArgumentShape? {
        byId[id]?.argumentShape
    }

    // MARK: - Disposal

    /// Disposes the registry. Idempotent: calling it again is a no-op.
    public func dispose() {
        _lock.lock()
        _isDisposed = true
        _lock.unlock()
    }
}
