// MonaCommandRegistry.swift
//
// P05-T002 — Implement command, action, contribution, and pure-text registries.
//
// `MonaCommandRegistry` holds the frozen command identities of monaco-editor
// 0.56.0, registered in the source order recorded by the F1-R3 scope manifest.
// Each identity exposes its enablement (is it enabled in this context?),
// argument shape (does it take typed arguments?), and an idempotent disposal
// path. Cut identities (the WebGPU debug command) are recorded as explicit
// UNAVAILABLE dispositions with NO live registration and NO production symbol.
//
// The frozen identities + their source order come from the F1-R3 scope manifest
// (monaco-0.56.0-f1r3-scope-manifest.json, `registries.commands`), the same
// artifact family P05-T001 used for the public declaration graph. They are
// emitted WITHOUT renaming or coalescing (one Swift entry per manifest row).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaRegistryDisposition

/// The disposition of a frozen identity: whether it is live in production or
/// explicitly excluded.
public enum MonaRegistryDisposition: String, Sendable, Equatable, CaseIterable {

    /// Retained as a live production identity (Foundation-only Core).
    case retained

    /// Retained as a live production identity on macOS.
    case retainedMacos

    /// The WebGPU debug identity is CUT from production. It is recorded as an
    /// explicit UNAVAILABLE disposition: no live registration, no production
    /// symbol.
    case cutWebGpuDebug

    /// A later mobile (iPadOS) contribution, excluded from production until the
    /// mobile product boundary ships. Recorded as UNAVAILABLE.
    case laterIpados

    /// `true` when this disposition is live in production (retained or
    /// retained-macos).
    public var isLive: Bool {
        switch self {
        case .retained, .retainedMacos: return true
        case .cutWebGpuDebug, .laterIpados: return false
        }
    }
}

// MARK: - MonaArgumentShape

/// The argument shape of a command: whether it accepts typed arguments and, if
/// so, the JSON schema describing them.
public struct MonaArgumentShape: Hashable, Sendable {

    /// `true` when the command accepts arguments.
    public let hasArguments: Bool

    /// The JSON schema string for the arguments, or `nil` when the command
    /// takes no arguments.
    public let schema: String?

    /// Creates an argument shape.
    public init(hasArguments: Bool, schema: String?) {
        self.hasArguments = hasArguments
        self.schema = schema
    }

    /// The no-arguments shape.
    public static let none = MonaArgumentShape(hasArguments: false, schema: nil)
}

// MARK: - MonaCommandIdentity

/// A frozen command identity, recorded in source order.
public struct MonaCommandIdentity: Hashable, Sendable {

    /// The command ID (e.g. `"_executeCodeActionProvider"`, `"cursorEnd"`).
    public let id: String

    /// The disposition (retained vs cut).
    public let disposition: MonaRegistryDisposition

    /// The argument shape.
    public let argumentShape: MonaArgumentShape

    /// `true` when this command is a live production identity.
    public var isLive: Bool { disposition.isLive }

    public init(
        id: String,
        disposition: MonaRegistryDisposition,
        hasArguments: Bool,
        argumentSchema: String?
    ) {
        self.id = id
        self.disposition = disposition
        self.argumentShape = MonaArgumentShape(
            hasArguments: hasArguments,
            schema: argumentSchema
        )
    }
}

// MARK: - MonaCommandRegistry

/// Holds the frozen command identities of monaco-editor 0.56.0 in source order.
///
/// The registry is populated at construction with every frozen command identity
/// from the F1-R3 scope manifest. Live (retained) commands are registered and
/// queryable; cut commands (the WebGPU debug identity) are recorded as
/// UNAVAILABLE dispositions and are never registered as live.
///
/// Disposal is idempotent: after `dispose()`, the registry is marked disposed
/// and further `dispose()` calls are no-ops. A disposed registry still reports
/// its frozen identity inventory (the identities are immutable) but enablement
/// queries return `false` (a disposed registry enables nothing).
public final class MonaCommandRegistry {

    /// Every frozen command identity in source order (live + cut).
    public static let frozenIdentities: [MonaCommandIdentity] = [
        MonaCommandIdentity(id: "_executeCodeActionProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeCodeLensProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeColorPresentationProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeCompletionItemProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeDeclarationProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeDeclarationProvider_recursive", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeDefinitionProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeDefinitionProvider_recursive", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeDocumentColorProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeDocumentHighlights", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeDocumentRenameProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeDocumentSymbolProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeFoldingRangeProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeFormatDocumentProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeFormatOnTypeProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeFormatRangeProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeHoverProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeHoverProvider_recursive", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeImplementationProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeImplementationProvider_recursive", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeInlayHintProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeLinkedEditingProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeLinkProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executePrepareRename", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeReferenceProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeReferenceProvider_recursive", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeSelectionRangeProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeSignatureHelpProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeTypeDefinitionProvider", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_executeTypeDefinitionProvider_recursive", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_generateContextKeyInfo", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_lastCursorMoveToSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_lineSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_lineSelectDrag", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_moveTo", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_moveToSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_provideDocumentRangeSemanticTokens", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_provideDocumentRangeSemanticTokensLegend", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_provideDocumentSemanticTokens", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_provideDocumentSemanticTokensLegend", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_setContext", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_wordSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "_wordSelectDrag", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "acceptAlternativeSelectedSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "acceptRenameInput", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "acceptRenameInputWithPreview", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "acceptSelectedCodeAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "acceptSelectedSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "acceptSelectedSuggestionOnEnter", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "acceptSnippet", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "actions.find", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "actions.findWithSelection", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cancelLinkedEditingInput", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cancelRenameInput", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cancelSelection", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "clearFilterCodeActionWidget", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "closeFindWidget", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "closeMarkersNavigation", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "closeParameterHints", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "closeReferenceSearch", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "closeReferenceSearchEditor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "codelens.showLensesInCurrentLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "collapseSectionCodeAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "columnSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "compositionEnd", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "compositionStart", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "compositionType", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "createCursor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorBottom", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorBottomSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorColumnSelectDown", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorColumnSelectLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorColumnSelectPageDown", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorColumnSelectPageUp", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorColumnSelectRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorColumnSelectUp", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorDown", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorDownSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorEnd", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"properties\":{\"sticky\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "cursorEndSelect", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"properties\":{\"sticky\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "cursorHome", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorHomeSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorLeftSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorLineEnd", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorLineEndSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorLineStart", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorLineStartSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorMove", disposition: .retained, hasArguments: true, argumentSchema: "[{\"constraint\":{\"$function\":true},\"name\":\"Cursor move argument object\",\"schema\":{\"properties\":{\"by\":{\"enum\":[\"line\",\"wrappedLine\",\"character\",\"halfLine\",\"foldedLine\"],\"type\":\"string\"},\"noHistory\":{\"default\":false,\"type\":\"boolean\"},\"select\":{\"default\":false,\"type\":\"boolean\"},\"to\":{\"enum\":[\"left\",\"right\",\"up\",\"down\",\"prevBlankLine\",\"nextBlankLine\",\"wrappedLineStart\",\"wrappedLineEnd\",\"wrappedLineColumnCenter\",\"wrappedLineFirstNonWhitespaceCharacter\",\"wrappedLineLastNonWhitespaceCharacter\",\"viewPortTop\",\"viewPortCenter\",\"viewPortBottom\",\"viewPortIfOutside\"],\"type\":\"string\"},\"value\":{\"default\":1,\"type\":\"number\"}},\"required\":[\"to\"],\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "cursorPageDown", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorPageDownSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorPageUp", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorPageUpSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorRedo", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorRightSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorTop", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorTopSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorUndo", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorUp", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorUpSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordAccessibilityLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordAccessibilityLeftSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordAccessibilityRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordAccessibilityRightSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordEndLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordEndLeftSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordEndRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordEndRightSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordLeftSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordPartLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordPartLeftSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordPartRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordPartRightSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordPartStartLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordPartStartLeftSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordRightSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordStartLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordStartLeftSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordStartRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cursorWordStartRightSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "cut", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:compositionEnd", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:compositionStart", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:compositionType", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:cut", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:paste", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:redo", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:replacePreviousChar", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:type", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "default:undo", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteAllLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteAllRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteInsideWord", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"properties\":{\"onlyWord\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "deleteLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteWordEndLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteWordEndRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteWordLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteWordPartLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteWordPartRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteWordRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteWordStartLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "deleteWordStartRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "diffEditor.collapseAllUnchangedRegions", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "diffEditor.exitCompareMove", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "diffEditor.revert", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "diffEditor.showAllUnchangedRegions", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "diffEditor.switchSide", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "diffEditor.toggleCollapseUnchangedRegions", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "diffEditor.toggleShowMovedCodeBlocks", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "diffEditor.toggleUseInlineViewWhenSpaceIsLimited", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.accessibleDiffViewer.next", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.accessibleDiffViewer.prev", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.addCommentLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.addCursorsToBottom", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.addCursorsToTop", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.addSelectionToNextFindMatch", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.addSelectionToPreviousFindMatch", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.autoFix", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.blockComment", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.cancelSelectionAnchor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.changeAll", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.changeTabDisplaySize", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.clipboardCopyAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.clipboardCopyWithSyntaxHighlightingAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.clipboardCutAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.clipboardPasteAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.codeAction", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"defaultSnippets\":[{\"body\":{\"kind\":\"\"}}],\"properties\":{\"apply\":{\"default\":\"ifSingle\",\"enum\":[\"first\",\"ifSingle\",\"never\"],\"type\":\"string\"},\"kind\":{\"type\":\"string\"},\"preferred\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "editor.action.commentLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.copyLinesDownAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.copyLinesUpAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.debugEditorGpuRenderer", disposition: .cutWebGpuDebug, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.decreaseHoverVerbosityLevel", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.deleteLines", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.detectIndentation", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.diffReview.next", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.diffReview.prev", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.duplicateSelection", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.findReferences", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.fixAll", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.focusNextCursor", disposition: .retained, hasArguments: true, argumentSchema: "[]"),
        MonaCommandIdentity(id: "editor.action.focusPreviousCursor", disposition: .retained, hasArguments: true, argumentSchema: "[]"),
        MonaCommandIdentity(id: "editor.action.focusStickyScroll", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.fontZoomIn", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.fontZoomOut", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.fontZoomReset", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.forceRetokenize", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.format", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.formatDocument", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.formatSelection", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToBottomHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToDeclaration", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToFocusedStickyScrollLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToImplementation", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.gotoLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToLocations", disposition: .retained, hasArguments: true, argumentSchema: "[{\"constraint\":{\"$function\":true},\"name\":\"uri\"},{\"constraint\":{\"$function\":true},\"name\":\"position\"},{\"constraint\":{\"$function\":true},\"name\":\"locations\"},{\"name\":\"multiple\"},{\"name\":\"noResultsMessage\"}]"),
        MonaCommandIdentity(id: "editor.action.goToMatchFindAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.gotoOffset", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToReferences", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToSelectionAnchor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToTopHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.goToTypeDefinition", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.hideColorPicker", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.hideHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.hideLongLineWarningHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.increaseHoverVerbosityLevel", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.indentationToSpaces", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.indentationToTabs", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.indentLines", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.indentUsingSpaces", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.indentUsingTabs", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.acceptNextLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.acceptNextWord", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.cancelSnooze", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.commit", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.commitAlternativeAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.dev.extractRepro", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.hide", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.jump", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.showNext", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.showPrevious", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.snooze", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.toggleAlwaysShowToolbar", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.toggleShowCollapsed", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inlineSuggest.trigger", disposition: .retained, hasArguments: true, argumentSchema: "[{\"isOptional\":true,\"name\":\"args\",\"schema\":{\"oneOf\":[{\"properties\":{\"changeHintData\":{},\"explicit\":{\"type\":\"boolean\"},\"providerId\":{\"$ref\":\"vscode://schemas/inlineCompletionProviderIdArgs\"},\"showNoResultNotification\":{\"type\":\"boolean\"}},\"type\":\"object\"}]}}]"),
        MonaCommandIdentity(id: "editor.action.inPlaceReplace.down", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inPlaceReplace.up", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.insertColorWithStandaloneColorPicker", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.insertCursorAbove", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.insertCursorAtEndOfEachLineSelected", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.insertCursorBelow", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.insertFinalNewLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.insertLineAfter", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.insertLineBefore", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.inspectTokens", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.joinLines", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.jumpToBracket", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.linkedEditing", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.marker.next", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.marker.nextInFiles", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.marker.prev", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.marker.prevInFiles", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.moveCarretLeftAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.moveCarretRightAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.moveLinesDownAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.moveLinesUpAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.moveSelectionToNextFindMatch", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.moveSelectionToPreviousFindMatch", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.nextMatchFindAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.nextSelectionMatchFindAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.openDeclarationToTheSide", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.openLink", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.organizeImports", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.outdentLines", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.pageDownHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.pageUpHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.pasteAs", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"oneOf\":[{\"properties\":{\"kind\":{\"type\":\"string\"}},\"required\":[\"kind\"],\"type\":\"object\"},{\"properties\":{\"preferences\":{\"items\":{\"type\":\"string\"},\"type\":\"array\"}},\"required\":[\"preferences\"],\"type\":\"object\"}]}}]"),
        MonaCommandIdentity(id: "editor.action.pasteAsText", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.peekDeclaration", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.peekDefinition", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.peekImplementation", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.peekLocations", disposition: .retained, hasArguments: true, argumentSchema: "[{\"constraint\":{\"$function\":true},\"name\":\"uri\"},{\"constraint\":{\"$function\":true},\"name\":\"position\"},{\"constraint\":{\"$function\":true},\"name\":\"locations\"},{\"name\":\"multiple\"}]"),
        MonaCommandIdentity(id: "editor.action.peekTypeDefinition", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.previewDeclaration", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.previousMatchFindAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.previousSelectionMatchFindAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.quickCommand", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.quickFix", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.quickOutline", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.refactor", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"defaultSnippets\":[{\"body\":{\"kind\":\"\"}}],\"properties\":{\"apply\":{\"default\":\"ifSingle\",\"enum\":[\"first\",\"ifSingle\",\"never\"],\"type\":\"string\"},\"kind\":{\"type\":\"string\"},\"preferred\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "editor.action.referenceSearch.trigger", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.reindentlines", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.reindentselectedlines", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.removeBrackets", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.removeCommentLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.removeDuplicateLines", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.rename", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.replaceAll", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.replaceOne", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.resetSuggestSize", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.revealDeclaration", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.revealDefinition", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.revealDefinitionAside", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.reverseLines", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.scrollDownHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.scrollLeftHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.scrollRightHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.scrollUpHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.selectAll", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.selectAllMatches", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.selectEditor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.selectFromAnchorToCursor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.selectHighlights", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.selectNextStickyScrollLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.selectPreviousStickyScrollLine", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.selectToBracket", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"properties\":{\"selectBrackets\":{\"default\":true,\"type\":\"boolean\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "editor.action.setSelectionAnchor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.showContextMenu", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.showDefinitionPreviewHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.showHover", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"properties\":{\"focus\":{\"default\":\"focusIfVisible\",\"enum\":[\"noAutoFocus\",\"focusIfVisible\",\"autoFocusImmediately\"]}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "editor.action.showOrFocusStandaloneColorPicker", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.showReferences", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.smartSelect.expand", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.smartSelect.grow", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.smartSelect.shrink", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.sortLinesAscending", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.sortLinesDescending", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.sourceAction", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"defaultSnippets\":[{\"body\":{\"kind\":\"\"}}],\"properties\":{\"apply\":{\"default\":\"ifSingle\",\"enum\":[\"first\",\"ifSingle\",\"never\"],\"type\":\"string\"},\"kind\":{\"type\":\"string\"},\"preferred\":{\"default\":false,\"type\":\"boolean\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "editor.action.startFindReplaceAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.toggleHighContrast", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.toggleStickyScroll", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.toggleTabFocusMode", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transformToCamelcase", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transformToKebabcase", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transformToLowercase", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transformToPascalcase", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transformToSnakecase", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transformToTitlecase", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transformToUppercase", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transpose", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.transposeLetters", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.triggerParameterHints", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.triggerSuggest", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.trimTrailingWhitespace", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.unicodeHighlight.disableHighlightingOfAmbiguousCharacters", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.unicodeHighlight.disableHighlightingOfInvisibleCharacters", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.unicodeHighlight.disableHighlightingOfNonBasicAsciiCharacters", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.unicodeHighlight.showExcludeOptions", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.wordHighlight.next", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.wordHighlight.prev", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.action.wordHighlight.trigger", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.actions.findWithArgs", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"Open a new In-Editor Find Widget args\",\"schema\":{\"properties\":{\"findInSelection\":{\"type\":\"boolean\"},\"isCaseSensitive\":{\"type\":\"boolean\"},\"isRegex\":{\"type\":\"boolean\"},\"matchWholeWord\":{\"type\":\"boolean\"},\"preserveCase\":{\"type\":\"boolean\"},\"replaceString\":{\"type\":\"string\"},\"searchString\":{\"type\":\"string\"}}}}]"),
        MonaCommandIdentity(id: "editor.cancelOperation", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.changeDropType", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.changePasteType", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.createFoldingRangeFromSelection", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.fold", disposition: .retained, hasArguments: true, argumentSchema: "[{\"constraint\":{\"$function\":true},\"name\":\"Fold editor argument\",\"schema\":{\"properties\":{\"direction\":{\"enum\":[\"up\",\"down\"],\"type\":\"string\"},\"levels\":{\"type\":\"number\"},\"selectionLines\":{\"items\":{\"type\":\"number\"},\"type\":\"array\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "editor.foldAll", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldAllBlockComments", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldAllExcept", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldAllMarkerRegions", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldLevel1", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldLevel2", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldLevel3", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldLevel4", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldLevel5", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldLevel6", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldLevel7", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.foldRecursively", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.gotoNextFold", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.gotoNextSymbolFromResult", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.gotoNextSymbolFromResult.cancel", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.gotoParentFold", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.gotoPreviousFold", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.hideDropWidget", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.hidePasteWidget", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.removeManualFoldingRanges", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.toggleFold", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.toggleFoldRecursively", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.toggleImportFold", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.unfold", disposition: .retained, hasArguments: true, argumentSchema: "[{\"constraint\":{\"$function\":true},\"name\":\"Unfold editor argument\",\"schema\":{\"properties\":{\"direction\":{\"default\":\"down\",\"enum\":[\"up\",\"down\"],\"type\":\"string\"},\"levels\":{\"default\":1,\"type\":\"number\"},\"selectionLines\":{\"items\":{\"type\":\"number\"},\"type\":\"array\"}},\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "editor.unfoldAll", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.unfoldAllExcept", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.unfoldAllMarkerRegions", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editor.unfoldRecursively", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "editorScroll", disposition: .retained, hasArguments: true, argumentSchema: "[{\"constraint\":{\"$function\":true},\"name\":\"Editor scroll argument object\",\"schema\":{\"properties\":{\"by\":{\"enum\":[\"line\",\"wrappedLine\",\"page\",\"halfPage\",\"editor\"],\"type\":\"string\"},\"revealCursor\":{\"type\":\"boolean\"},\"to\":{\"enum\":[\"up\",\"down\"],\"type\":\"string\"},\"value\":{\"default\":1,\"type\":\"number\"}},\"required\":[\"to\"],\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "expandLineSelection", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "expandSectionCodeAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "focusAndAcceptSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "focusNextRenameSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "focusPreviousRenameSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "focusSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "getContextKeyInfo", disposition: .retained, hasArguments: true, argumentSchema: "[]"),
        MonaCommandIdentity(id: "goToNextReference", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "goToNextReferenceFromEmbeddedEditor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "goToPreviousReference", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "goToPreviousReferenceFromEmbeddedEditor", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "hideCodeActionWidget", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "hideSuggestWidget", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "history.showNext", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "history.showPrevious", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "insertBestCompletion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "insertNextSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "insertPrevSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "jumpToNextSnippetPlaceholder", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "jumpToPrevSnippetPlaceholder", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "lastCursorLineSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "lastCursorLineSelectDrag", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "lastCursorWordSelect", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "leaveEditorMessage", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "leaveSnippet", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "lineBreakInsert", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "noop", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "openReference", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "openReferenceToSide", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "outdent", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "paste", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "previewSelectedCodeAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.accept", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.acceptInBackground", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.first", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.hide", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.last", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.next", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.nextSeparator", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.nextSeparatorWithQuickAccessFallback", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.pageNext", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.pagePrevious", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.previous", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.previousSeparator", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.previousSeparatorWithQuickAccessFallback", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.toggleCheckbox", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "quickInput.toggleHover", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "redo", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "removeSecondaryCursors", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "replacePreviousChar", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "revealLine", disposition: .retained, hasArguments: true, argumentSchema: "[{\"constraint\":{\"$function\":true},\"name\":\"Reveal line argument object\",\"schema\":{\"properties\":{\"at\":{\"enum\":[\"top\",\"center\",\"bottom\"],\"type\":\"string\"},\"lineNumber\":{\"type\":[\"number\",\"string\"]}},\"required\":[\"lineNumber\"],\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "revealReference", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "scrollEditorBottom", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "scrollEditorTop", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "scrollLeft", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "scrollLineDown", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "scrollLineUp", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "scrollPageDown", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "scrollPageUp", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "scrollRight", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "selectFirstSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "selectLastSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "selectNextCodeAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "selectNextPageSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "selectNextSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "selectPrevCodeAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "selectPrevPageSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "selectPrevSuggestion", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "setSelection", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "showNextParameterHint", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "showPrevParameterHint", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "suggestWidgetCopy", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "tab", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "toggleExplainMode", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "toggleFindCaseSensitive", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "toggleFindInSelection", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "toggleFindRegex", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "toggleFindWholeWord", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "togglePeekWidgetFocus", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "togglePreserveCase", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "toggleSectionCodeAction", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "toggleSuggestionDetails", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "toggleSuggestionFocus", disposition: .retained, hasArguments: false, argumentSchema: nil),
        MonaCommandIdentity(id: "type", disposition: .retained, hasArguments: true, argumentSchema: "[{\"name\":\"args\",\"schema\":{\"properties\":{\"text\":{\"type\":\"string\"}},\"required\":[\"text\"],\"type\":\"object\"}}]"),
        MonaCommandIdentity(id: "undo", disposition: .retained, hasArguments: false, argumentSchema: nil)
    ]

    /// The live (retained) command identities, in source order.
    public let liveIdentities: [MonaCommandIdentity]

    /// The cut (UNAVAILABLE) command identities, in source order.
    public let cutIdentities: [MonaCommandIdentity]

    /// A map from command ID to its identity, for O(1) lookup.
    private let byId: [String: MonaCommandIdentity]

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates a registry populated with all frozen command identities.
    public init() {
        let frozen = Self.frozenIdentities
        self.liveIdentities = frozen.filter { $0.isLive }
        self.cutIdentities = frozen.filter { !$0.isLive }
        var map: [String: MonaCommandIdentity] = [:]
        for identity in frozen where identity.isLive {
            map[identity.id] = identity
        }
        self.byId = map
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _isDisposed
    }

    /// The total number of frozen identities (live + cut).
    public var totalCount: Int { Self.frozenIdentities.count }

    /// The number of live (retained) identities.
    public var liveCount: Int { liveIdentities.count }

    /// The number of cut (UNAVAILABLE) identities.
    public var cutCount: Int { cutIdentities.count }

    // MARK: - Lookup

    /// Returns the identity for `id`, or `nil` if no live command is registered
    /// with that ID.
    public func identity(for id: String) -> MonaCommandIdentity? {
        byId[id]
    }

    /// Returns `true` when a live command with `id` is registered.
    public func contains(_ id: String) -> Bool {
        byId[id] != nil
    }

    // MARK: - Enablement

    /// Evaluates whether the command `id` is enabled in `context`.
    ///
    /// A command is enabled when:
    ///   1. it is a live (retained) identity,
    ///   2. the registry is not disposed, and
    ///   3. the command has no precondition (commands carry no when-clause;
    ///      they are enabled whenever live and registered).
    public func isEnabled(_ id: String, context: MonaKeybindingContext) -> Bool {
        guard !isDisposed else { return false }
        guard byId[id] != nil else { return false }
        return true
    }

    // MARK: - Argument shape

    /// Returns the argument shape for `id`, or `nil` if no live command is
    /// registered with that ID.
    public func argumentShape(for id: String) -> MonaArgumentShape? {
        byId[id]?.argumentShape
    }

    // MARK: - Disposal

    /// Disposes the registry. Idempotent: calling it again is a no-op.
    ///
    /// After disposal, `isEnabled` returns `false` for every command. The
    /// frozen identity inventory remains queryable (identities are immutable).
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        _ = already
    }
}
