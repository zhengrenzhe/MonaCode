// MonaBuiltinOptions.swift
//
// P05-T005 — Implement all 174 editor options and computed option truth.
//
// GENERATED FILE — do not edit by hand. Transcribed verbatim from the F1-R3
// scope manifest (monaco-editor@0.56.0 builtin editor options). Regenerate by
// re-running the P05-T005 transcription against the manifest at:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monaco-0.56.0-f1r3-scope-manifest.json
//
// `MonaBuiltinOptions` is the 174-option builtin table that drives the
// option store (`MonaOptionStore`). Each `MonaEditorOption` is emitted in
// source order with its stable id, name, runtime name, disposition
// (retained-input / computed-only / cut), input kind, canonical default
// value, numeric bounds, extensible-enum members, and — for computed-only
// options — the dependency edges (`reads`) the store resolves topologically.
//
// Split: 157 retained-input (mutable) + 6 computed-only (read-only derived)
// + 11 cut (excluded) = 174 total.
//
// Extensible enums: enum (`.enumString`) options declare their known members
// via `enumMembers`. The set is open — future raw values are accepted on
// set; the canonical default is always a known member.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The 174 builtin editor options ported verbatim from monaco-editor@0.56.0
/// (F1-R3 scope manifest), driving the option store.
public enum MonaBuiltinOptions {

    /// All 174 builtin options in source-ordinal order (`options[i].id == i`).
    public static let options: [MonaEditorOption] = [
        MonaEditorOption(id: 0, name: "acceptSuggestionOnCommitCharacter", runtimeName: "acceptSuggestionOnCommitCharacter", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 1, name: "acceptSuggestionOnEnter", runtimeName: "acceptSuggestionOnEnter", disposition: .retainedInput, kind: .enumString, defaultValue: .string("on"), enumMembers: ["on", "smart", "off"], reads: []),
        MonaEditorOption(id: 2, name: "accessibilitySupport", runtimeName: "accessibilitySupport", disposition: .retainedInput, kind: .enumString, defaultValue: .string("auto"), enumMembers: ["auto", "on", "off"], reads: []),
        MonaEditorOption(id: 3, name: "accessibilityPageSize", runtimeName: "accessibilityPageSize", disposition: .retainedInput, kind: .integer, defaultValue: .int(500), bounds: MonaOptionBounds(minInt: 1, maxInt: 1073741824), reads: []),
        MonaEditorOption(id: 4, name: "allowOverflow", runtimeName: "allowOverflow", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 5, name: "allowVariableLineHeights", runtimeName: "allowVariableLineHeights", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 6, name: "allowVariableFonts", runtimeName: "allowVariableFonts", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 7, name: "allowVariableFontsInAccessibilityMode", runtimeName: "allowVariableFontsInAccessibilityMode", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 8, name: "ariaLabel", runtimeName: "ariaLabel", disposition: .retainedInput, kind: .string, defaultValue: .string("Editor content"), reads: []),
        MonaEditorOption(id: 9, name: "ariaRequired", runtimeName: "ariaRequired", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 10, name: "autoClosingBrackets", runtimeName: "autoClosingBrackets", disposition: .retainedInput, kind: .enumString, defaultValue: .string("languageDefined"), enumMembers: ["always", "languageDefined", "beforeWhitespace", "never"], reads: []),
        MonaEditorOption(id: 11, name: "autoClosingComments", runtimeName: "autoClosingComments", disposition: .retainedInput, kind: .enumString, defaultValue: .string("languageDefined"), enumMembers: ["always", "languageDefined", "beforeWhitespace", "never"], reads: []),
        MonaEditorOption(id: 12, name: "screenReaderAnnounceInlineSuggestion", runtimeName: "screenReaderAnnounceInlineSuggestion", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 13, name: "autoClosingDelete", runtimeName: "autoClosingDelete", disposition: .retainedInput, kind: .enumString, defaultValue: .string("auto"), enumMembers: ["always", "auto", "never"], reads: []),
        MonaEditorOption(id: 14, name: "autoClosingOvertype", runtimeName: "autoClosingOvertype", disposition: .retainedInput, kind: .enumString, defaultValue: .string("auto"), enumMembers: ["always", "auto", "never"], reads: []),
        MonaEditorOption(id: 15, name: "autoClosingQuotes", runtimeName: "autoClosingQuotes", disposition: .retainedInput, kind: .enumString, defaultValue: .string("languageDefined"), enumMembers: ["always", "languageDefined", "beforeWhitespace", "never"], reads: []),
        MonaEditorOption(id: 16, name: "autoIndent", runtimeName: "autoIndent", disposition: .retainedInput, kind: .enumString, defaultValue: .string("full"), enumMembers: ["none", "keep", "brackets", "advanced", "full"], reads: []),
        MonaEditorOption(id: 17, name: "autoIndentOnPaste", runtimeName: "autoIndentOnPaste", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 18, name: "autoIndentOnPasteWithinString", runtimeName: "autoIndentOnPasteWithinString", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 19, name: "automaticLayout", runtimeName: "automaticLayout", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 20, name: "autoSurround", runtimeName: "autoSurround", disposition: .retainedInput, kind: .enumString, defaultValue: .string("languageDefined"), enumMembers: ["languageDefined", "quotes", "brackets", "never"], reads: []),
        MonaEditorOption(id: 21, name: "bracketPairColorization", runtimeName: "bracketPairColorization", disposition: .retainedInput, kind: .object, defaultValue: .object(["enabled": .bool(true), "independentColorPoolPerBracketType": .bool(false)]), reads: []),
        MonaEditorOption(id: 22, name: "bracketPairGuides", runtimeName: "guides", disposition: .retainedInput, kind: .object, defaultValue: .object(["bracketPairs": .bool(false), "bracketPairsHorizontal": .string("active"), "highlightActiveBracketPair": .bool(true), "highlightActiveIndentation": .bool(true), "indentation": .bool(true)]), reads: []),
        MonaEditorOption(id: 23, name: "codeLens", runtimeName: "codeLens", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 24, name: "codeLensFontFamily", runtimeName: "codeLensFontFamily", disposition: .retainedInput, kind: .string, defaultValue: .string(""), reads: []),
        MonaEditorOption(id: 25, name: "codeLensFontSize", runtimeName: "codeLensFontSize", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), bounds: MonaOptionBounds(minInt: 0, maxInt: 100), reads: []),
        MonaEditorOption(id: 26, name: "colorDecorators", runtimeName: "colorDecorators", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 27, name: "colorDecoratorsLimit", runtimeName: "colorDecoratorsLimit", disposition: .retainedInput, kind: .integer, defaultValue: .int(500), bounds: MonaOptionBounds(minInt: 1, maxInt: 1000000), reads: []),
        MonaEditorOption(id: 28, name: "columnSelection", runtimeName: "columnSelection", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 29, name: "comments", runtimeName: "comments", disposition: .retainedInput, kind: .object, defaultValue: .object(["ignoreEmptyLines": .bool(true), "insertSpace": .bool(true)]), reads: []),
        MonaEditorOption(id: 30, name: "contextmenu", runtimeName: "contextmenu", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 31, name: "copyWithSyntaxHighlighting", runtimeName: "copyWithSyntaxHighlighting", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 32, name: "cursorBlinking", runtimeName: "cursorBlinking", disposition: .retainedInput, kind: .enumString, defaultValue: .string("blink"), enumMembers: ["blink", "smooth", "phase", "expand", "solid"], reads: []),
        MonaEditorOption(id: 33, name: "cursorSmoothCaretAnimation", runtimeName: "cursorSmoothCaretAnimation", disposition: .retainedInput, kind: .enumString, defaultValue: .string("off"), enumMembers: ["off", "explicit", "on"], reads: []),
        MonaEditorOption(id: 34, name: "cursorStyle", runtimeName: "cursorStyle", disposition: .retainedInput, kind: .enumString, defaultValue: .string("line"), enumMembers: ["line", "block", "underline", "line-thin", "block-outline", "underline-thin"], reads: []),
        MonaEditorOption(id: 35, name: "cursorSurroundingLines", runtimeName: "cursorSurroundingLines", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), bounds: MonaOptionBounds(minInt: 0, maxInt: 1073741824), reads: []),
        MonaEditorOption(id: 36, name: "cursorSurroundingLinesStyle", runtimeName: "cursorSurroundingLinesStyle", disposition: .retainedInput, kind: .enumString, defaultValue: .string("default"), enumMembers: ["default", "all"], reads: []),
        MonaEditorOption(id: 37, name: "cursorWidth", runtimeName: "cursorWidth", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), bounds: MonaOptionBounds(minInt: 0, maxInt: 1073741824), reads: []),
        MonaEditorOption(id: 38, name: "cursorHeight", runtimeName: "cursorHeight", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), bounds: MonaOptionBounds(minInt: 0, maxInt: 1073741824), reads: []),
        MonaEditorOption(id: 39, name: "disableLayerHinting", runtimeName: "disableLayerHinting", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 40, name: "disableMonospaceOptimizations", runtimeName: "disableMonospaceOptimizations", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 41, name: "domReadOnly", runtimeName: "domReadOnly", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 42, name: "dragAndDrop", runtimeName: "dragAndDrop", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 43, name: "dropIntoEditor", runtimeName: "dropIntoEditor", disposition: .retainedInput, kind: .object, defaultValue: .object(["enabled": .bool(true), "showDropSelector": .string("afterDrop")]), reads: []),
        MonaEditorOption(id: 44, name: "editContext", runtimeName: "editContext", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 45, name: "emptySelectionClipboard", runtimeName: "emptySelectionClipboard", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 46, name: "experimentalGpuAcceleration", runtimeName: "experimentalGpuAcceleration", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 47, name: "experimentalWhitespaceRendering", runtimeName: "experimentalWhitespaceRendering", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 48, name: "extraEditorClassName", runtimeName: "extraEditorClassName", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 49, name: "fastScrollSensitivity", runtimeName: "fastScrollSensitivity", disposition: .retainedInput, kind: .number, defaultValue: .double(5.0), reads: []),
        MonaEditorOption(id: 50, name: "find", runtimeName: "find", disposition: .retainedInput, kind: .object, defaultValue: .object(["addExtraSpaceOnTop": .bool(true), "autoFindInSelection": .string("never"), "closeOnResult": .bool(false), "cursorMoveOnType": .bool(true), "findOnType": .bool(true), "globalFindClipboard": .bool(false), "history": .string("workspace"), "loop": .bool(true), "replaceHistory": .string("workspace"), "seedSearchStringFromSelection": .string("always")]), reads: []),
        MonaEditorOption(id: 51, name: "fixedOverflowWidgets", runtimeName: "fixedOverflowWidgets", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 52, name: "folding", runtimeName: "folding", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 53, name: "foldingStrategy", runtimeName: "foldingStrategy", disposition: .retainedInput, kind: .enumString, defaultValue: .string("auto"), enumMembers: ["auto", "indentation"], reads: []),
        MonaEditorOption(id: 54, name: "foldingHighlight", runtimeName: "foldingHighlight", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 55, name: "foldingImportsByDefault", runtimeName: "foldingImportsByDefault", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 56, name: "foldingMaximumRegions", runtimeName: "foldingMaximumRegions", disposition: .retainedInput, kind: .integer, defaultValue: .int(5000), bounds: MonaOptionBounds(minInt: 10, maxInt: 65000), reads: []),
        MonaEditorOption(id: 57, name: "unfoldOnClickAfterEndOfLine", runtimeName: "unfoldOnClickAfterEndOfLine", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 58, name: "fontFamily", runtimeName: "fontFamily", disposition: .retainedInput, kind: .string, defaultValue: .string("Menlo, Monaco, 'Courier New', monospace"), reads: []),
        MonaEditorOption(id: 59, name: "fontInfo", runtimeName: "_never_", disposition: .computedOnly, kind: nil, defaultValue: .null, reads: ["fontFamily", "fontWeight", "fontSize", "fontLigatures2", "letterSpacing", "lineHeight", "fontVariations", "pixelRatio"]),
        MonaEditorOption(id: 60, name: "fontLigatures2", runtimeName: "fontLigatures", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 61, name: "fontSize", runtimeName: "fontSize", disposition: .retainedInput, kind: .number, defaultValue: .double(12.0), bounds: MonaOptionBounds(minInt: 6, maxInt: 100), reads: []),
        MonaEditorOption(id: 62, name: "fontWeight", runtimeName: "fontWeight", disposition: .retainedInput, kind: .string, defaultValue: .string("normal"), reads: []),
        MonaEditorOption(id: 63, name: "fontVariations", runtimeName: "fontVariations", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 64, name: "formatOnPaste", runtimeName: "formatOnPaste", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 65, name: "formatOnType", runtimeName: "formatOnType", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 66, name: "glyphMargin", runtimeName: "glyphMargin", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 67, name: "gotoLocation", runtimeName: "gotoLocation", disposition: .retainedInput, kind: .object, defaultValue: .object(["alternativeDeclarationCommand": .string("editor.action.goToReferences"), "alternativeDefinitionCommand": .string("editor.action.goToReferences"), "alternativeImplementationCommand": .string(""), "alternativeReferenceCommand": .string(""), "alternativeTestsCommand": .string(""), "alternativeTypeDefinitionCommand": .string("editor.action.goToReferences"), "multiple": .string("peek"), "multipleDeclarations": .string("peek"), "multipleDefinitions": .string("peek"), "multipleImplementations": .string("peek"), "multipleReferences": .string("peek"), "multipleTests": .string("peek"), "multipleTypeDefinitions": .string("peek")]), reads: []),
        MonaEditorOption(id: 68, name: "hideCursorInOverviewRuler", runtimeName: "hideCursorInOverviewRuler", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 69, name: "hover", runtimeName: "hover", disposition: .retainedInput, kind: .object, defaultValue: .object(["above": .bool(true), "delay": .int(300), "enabled": .string("on"), "hidingDelay": .int(300), "showLongLineWarning": .bool(true), "sticky": .bool(true)]), reads: []),
        MonaEditorOption(id: 70, name: "inDiffEditor", runtimeName: "inDiffEditor", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 71, name: "inlineSuggest", runtimeName: "inlineSuggest", disposition: .retainedInput, kind: .object, defaultValue: .object(["edits": .object(["allowCodeShifting": .string("always"), "enabled": .bool(true), "renderSideBySide": .string("auto"), "showCollapsed": .bool(false), "showLongDistanceHint": .bool(true)]), "enabled": .bool(true), "experimental": .object(["emptyResponseInformation": .bool(true), "showOnSuggestConflict": .string("never"), "suppressInlineSuggestions": .string("")]), "fontFamily": .string("default"), "keepOnBlur": .bool(false), "minShowDelay": .int(0), "mode": .string("subwordSmart"), "showToolbar": .string("onHover"), "suppressInSnippetMode": .bool(true), "suppressSuggestions": .bool(false), "syntaxHighlightingEnabled": .bool(true), "triggerCommandOnProviderChange": .bool(false)]), reads: []),
        MonaEditorOption(id: 72, name: "letterSpacing", runtimeName: "letterSpacing", disposition: .retainedInput, kind: .number, defaultValue: .double(0.0), reads: []),
        MonaEditorOption(id: 73, name: "lightbulb", runtimeName: "lightbulb", disposition: .retainedInput, kind: .object, defaultValue: .object(["enabled": .string("onCode")]), reads: []),
        MonaEditorOption(id: 74, name: "lineDecorationsWidth", runtimeName: "lineDecorationsWidth", disposition: .retainedInput, kind: .integer, defaultValue: .int(10), reads: []),
        MonaEditorOption(id: 75, name: "lineHeight", runtimeName: "lineHeight", disposition: .retainedInput, kind: .number, defaultValue: .double(0.0), bounds: MonaOptionBounds(minInt: 0, maxInt: 150), reads: []),
        MonaEditorOption(id: 76, name: "lineNumbers", runtimeName: "lineNumbers", disposition: .retainedInput, kind: .enumString, defaultValue: .string("on"), enumMembers: ["off", "on", "relative", "interval"], reads: []),
        MonaEditorOption(id: 77, name: "lineNumbersMinChars", runtimeName: "lineNumbersMinChars", disposition: .retainedInput, kind: .integer, defaultValue: .int(5), reads: []),
        MonaEditorOption(id: 78, name: "linkedEditing", runtimeName: "linkedEditing", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 79, name: "links", runtimeName: "links", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 80, name: "matchBrackets", runtimeName: "matchBrackets", disposition: .retainedInput, kind: .enumString, defaultValue: .string("always"), enumMembers: ["always", "near", "never"], reads: []),
        MonaEditorOption(id: 81, name: "minimap", runtimeName: "minimap", disposition: .retainedInput, kind: .object, defaultValue: .object(["autohide": .string("none"), "enabled": .bool(true), "markSectionHeaderRegex": .string("\\bMARK:\\s*(?<separator>-?)\\s*(?<label>.*)$"), "maxColumn": .int(120), "renderCharacters": .bool(true), "scale": .int(1), "sectionHeaderFontSize": .int(9), "sectionHeaderLetterSpacing": .int(1), "showMarkSectionHeaders": .bool(true), "showRegionSectionHeaders": .bool(true), "showSlider": .string("mouseover"), "side": .string("right"), "size": .string("proportional")]), reads: []),
        MonaEditorOption(id: 82, name: "mouseStyle", runtimeName: "mouseStyle", disposition: .retainedInput, kind: .string, defaultValue: .string("text"), reads: []),
        MonaEditorOption(id: 83, name: "mouseWheelScrollSensitivity", runtimeName: "mouseWheelScrollSensitivity", disposition: .retainedInput, kind: .number, defaultValue: .double(1.0), reads: []),
        MonaEditorOption(id: 84, name: "mouseWheelZoom", runtimeName: "mouseWheelZoom", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 85, name: "multiCursorMergeOverlapping", runtimeName: "multiCursorMergeOverlapping", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 86, name: "multiCursorModifier", runtimeName: "multiCursorModifier", disposition: .retainedInput, kind: .enumString, defaultValue: .string("alt"), enumMembers: ["ctrlCmd", "alt"], reads: []),
        MonaEditorOption(id: 87, name: "mouseMiddleClickAction", runtimeName: "mouseMiddleClickAction", disposition: .retainedInput, kind: .enumString, defaultValue: .string("default"), enumMembers: ["default", "openLink", "ctrlLeftClick"], reads: []),
        MonaEditorOption(id: 88, name: "multiCursorPaste", runtimeName: "multiCursorPaste", disposition: .retainedInput, kind: .enumString, defaultValue: .string("spread"), enumMembers: ["spread", "full"], reads: []),
        MonaEditorOption(id: 89, name: "multiCursorLimit", runtimeName: "multiCursorLimit", disposition: .retainedInput, kind: .integer, defaultValue: .int(10000), bounds: MonaOptionBounds(minInt: 1, maxInt: 100000), reads: []),
        MonaEditorOption(id: 90, name: "occurrencesHighlight", runtimeName: "occurrencesHighlight", disposition: .retainedInput, kind: .enumString, defaultValue: .string("singleFile"), enumMembers: ["off", "singleFile", "multiFile"], reads: []),
        MonaEditorOption(id: 91, name: "occurrencesHighlightDelay", runtimeName: "occurrencesHighlightDelay", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), bounds: MonaOptionBounds(minInt: 0, maxInt: 2000), reads: []),
        MonaEditorOption(id: 92, name: "overtypeCursorStyle", runtimeName: "overtypeCursorStyle", disposition: .retainedInput, kind: .enumString, defaultValue: .string("block"), enumMembers: ["line", "block", "underline", "line-thin", "block-outline", "underline-thin"], reads: []),
        MonaEditorOption(id: 93, name: "overtypeOnPaste", runtimeName: "overtypeOnPaste", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 94, name: "overviewRulerBorder", runtimeName: "overviewRulerBorder", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 95, name: "overviewRulerLanes", runtimeName: "overviewRulerLanes", disposition: .retainedInput, kind: .integer, defaultValue: .int(2), reads: []),
        MonaEditorOption(id: 96, name: "padding", runtimeName: "padding", disposition: .retainedInput, kind: .object, defaultValue: .object(["bottom": .int(0), "top": .int(0)]), reads: []),
        MonaEditorOption(id: 97, name: "pasteAs", runtimeName: "pasteAs", disposition: .retainedInput, kind: .object, defaultValue: .object(["enabled": .bool(true), "showPasteSelector": .string("afterPaste")]), reads: []),
        MonaEditorOption(id: 98, name: "parameterHints", runtimeName: "parameterHints", disposition: .retainedInput, kind: .object, defaultValue: .object(["cycle": .bool(true), "enabled": .bool(true)]), reads: []),
        MonaEditorOption(id: 99, name: "peekWidgetDefaultFocus", runtimeName: "peekWidgetDefaultFocus", disposition: .retainedInput, kind: .enumString, defaultValue: .string("tree"), enumMembers: ["tree", "editor"], reads: []),
        MonaEditorOption(id: 100, name: "placeholder", runtimeName: "placeholder", disposition: .retainedInput, kind: .object, defaultValue: .null, reads: []),
        MonaEditorOption(id: 101, name: "definitionLinkOpensInPeek", runtimeName: "definitionLinkOpensInPeek", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 102, name: "quickSuggestions", runtimeName: "quickSuggestions", disposition: .retainedInput, kind: .object, defaultValue: .object(["comments": .string("off"), "other": .string("offWhenInlineCompletions"), "strings": .string("off")]), reads: []),
        MonaEditorOption(id: 103, name: "quickSuggestionsDelay", runtimeName: "quickSuggestionsDelay", disposition: .retainedInput, kind: .integer, defaultValue: .int(10), bounds: MonaOptionBounds(minInt: 0, maxInt: 1073741824), reads: []),
        MonaEditorOption(id: 104, name: "readOnly", runtimeName: "readOnly", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 105, name: "readOnlyMessage", runtimeName: "readOnlyMessage", disposition: .retainedInput, kind: .object, defaultValue: .null, reads: []),
        MonaEditorOption(id: 106, name: "renameOnType", runtimeName: "renameOnType", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 107, name: "renderRichScreenReaderContent", runtimeName: "renderRichScreenReaderContent", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 108, name: "renderControlCharacters", runtimeName: "renderControlCharacters", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 109, name: "renderFinalNewline", runtimeName: "renderFinalNewline", disposition: .retainedInput, kind: .enumString, defaultValue: .string("on"), enumMembers: ["off", "on", "dimmed"], reads: []),
        MonaEditorOption(id: 110, name: "renderLineHighlight", runtimeName: "renderLineHighlight", disposition: .retainedInput, kind: .enumString, defaultValue: .string("line"), enumMembers: ["none", "gutter", "line", "all"], reads: []),
        MonaEditorOption(id: 111, name: "renderLineHighlightOnlyWhenFocus", runtimeName: "renderLineHighlightOnlyWhenFocus", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 112, name: "renderValidationDecorations", runtimeName: "renderValidationDecorations", disposition: .retainedInput, kind: .string, defaultValue: .string("editable"), reads: []),
        MonaEditorOption(id: 113, name: "renderWhitespace", runtimeName: "renderWhitespace", disposition: .retainedInput, kind: .enumString, defaultValue: .string("selection"), enumMembers: ["none", "boundary", "selection", "trailing", "all"], reads: []),
        MonaEditorOption(id: 114, name: "revealHorizontalRightPadding", runtimeName: "revealHorizontalRightPadding", disposition: .retainedInput, kind: .integer, defaultValue: .int(15), reads: []),
        MonaEditorOption(id: 115, name: "roundedSelection", runtimeName: "roundedSelection", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 116, name: "rulers", runtimeName: "rulers", disposition: .retainedInput, kind: .array, defaultValue: .array([]), reads: []),
        MonaEditorOption(id: 117, name: "scrollbar", runtimeName: "scrollbar", disposition: .retainedInput, kind: .object, defaultValue: .object(["alwaysConsumeMouseWheel": .bool(true), "arrowSize": .int(11), "handleMouseWheel": .bool(true), "horizontal": .int(1), "horizontalHasArrows": .bool(false), "horizontalScrollbarSize": .int(12), "horizontalSliderSize": .int(12), "ignoreHorizontalScrollbarInContentHeight": .bool(false), "scrollByPage": .bool(false), "useShadows": .bool(true), "vertical": .int(1), "verticalHasArrows": .bool(false), "verticalScrollbarSize": .int(14), "verticalSliderSize": .int(14)]), reads: []),
        MonaEditorOption(id: 118, name: "scrollBeyondLastColumn", runtimeName: "scrollBeyondLastColumn", disposition: .retainedInput, kind: .integer, defaultValue: .int(4), bounds: MonaOptionBounds(minInt: 0, maxInt: 1073741824), reads: []),
        MonaEditorOption(id: 119, name: "scrollBeyondLastLine", runtimeName: "scrollBeyondLastLine", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 120, name: "scrollPredominantAxis", runtimeName: "scrollPredominantAxis", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 121, name: "selectionClipboard", runtimeName: "selectionClipboard", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 122, name: "selectionHighlight", runtimeName: "selectionHighlight", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 123, name: "selectionHighlightMaxLength", runtimeName: "selectionHighlightMaxLength", disposition: .retainedInput, kind: .integer, defaultValue: .int(200), bounds: MonaOptionBounds(minInt: 0, maxInt: 1073741824), reads: []),
        MonaEditorOption(id: 124, name: "selectionHighlightMultiline", runtimeName: "selectionHighlightMultiline", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 125, name: "selectOnLineNumbers", runtimeName: "selectOnLineNumbers", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 126, name: "showFoldingControls", runtimeName: "showFoldingControls", disposition: .retainedInput, kind: .enumString, defaultValue: .string("mouseover"), enumMembers: ["always", "never", "mouseover"], reads: []),
        MonaEditorOption(id: 127, name: "showUnused", runtimeName: "showUnused", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 128, name: "snippetSuggestions", runtimeName: "snippetSuggestions", disposition: .retainedInput, kind: .enumString, defaultValue: .string("inline"), enumMembers: ["top", "bottom", "inline", "none"], reads: []),
        MonaEditorOption(id: 129, name: "smartSelect", runtimeName: "smartSelect", disposition: .retainedInput, kind: .object, defaultValue: .object(["selectLeadingAndTrailingWhitespace": .bool(true), "selectSubwords": .bool(true)]), reads: []),
        MonaEditorOption(id: 130, name: "smoothScrolling", runtimeName: "smoothScrolling", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 131, name: "stickyScroll", runtimeName: "stickyScroll", disposition: .retainedInput, kind: .object, defaultValue: .object(["defaultModel": .string("outlineModel"), "enabled": .bool(true), "maxLineCount": .int(5), "scrollWithEditor": .bool(true)]), reads: []),
        MonaEditorOption(id: 132, name: "stickyTabStops", runtimeName: "stickyTabStops", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 133, name: "stopRenderingLineAfter", runtimeName: "stopRenderingLineAfter", disposition: .retainedInput, kind: .integer, defaultValue: .int(10000), reads: []),
        MonaEditorOption(id: 134, name: "suggest", runtimeName: "suggest", disposition: .retainedInput, kind: .object, defaultValue: .object(["filterGraceful": .bool(true), "insertMode": .string("insert"), "localityBonus": .bool(false), "matchOnWordStartOnly": .bool(true), "preview": .bool(false), "previewMode": .string("subwordSmart"), "selectionMode": .string("always"), "shareSuggestSelections": .bool(false), "showClasses": .bool(true), "showColors": .bool(true), "showConstants": .bool(true), "showConstructors": .bool(true), "showDeprecated": .bool(true), "showEnumMembers": .bool(true), "showEnums": .bool(true), "showEvents": .bool(true), "showFields": .bool(true), "showFiles": .bool(true), "showFolders": .bool(true), "showFunctions": .bool(true), "showIcons": .bool(true), "showInlineDetails": .bool(true), "showInterfaces": .bool(true), "showIssues": .bool(true), "showKeywords": .bool(true), "showMethods": .bool(true), "showModules": .bool(true), "showOperators": .bool(true), "showProperties": .bool(true), "showReferences": .bool(true), "showSnippets": .bool(true), "showStatusBar": .bool(false), "showStructs": .bool(true), "showTypeParameters": .bool(true), "showUnits": .bool(true), "showUsers": .bool(true), "showValues": .bool(true), "showVariables": .bool(true), "showWords": .bool(true), "snippetsPreventQuickSuggestions": .bool(false)]), reads: []),
        MonaEditorOption(id: 135, name: "suggestFontSize", runtimeName: "suggestFontSize", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), bounds: MonaOptionBounds(minInt: 0, maxInt: 1000), reads: []),
        MonaEditorOption(id: 136, name: "suggestLineHeight", runtimeName: "suggestLineHeight", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), bounds: MonaOptionBounds(minInt: 0, maxInt: 1000), reads: []),
        MonaEditorOption(id: 137, name: "suggestOnTriggerCharacters", runtimeName: "suggestOnTriggerCharacters", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 138, name: "suggestSelection", runtimeName: "suggestSelection", disposition: .retainedInput, kind: .enumString, defaultValue: .string("first"), enumMembers: ["first", "recentlyUsed", "recentlyUsedByPrefix"], reads: []),
        MonaEditorOption(id: 139, name: "tabCompletion", runtimeName: "tabCompletion", disposition: .retainedInput, kind: .enumString, defaultValue: .string("off"), enumMembers: ["on", "off", "onlySnippets"], reads: []),
        MonaEditorOption(id: 140, name: "tabIndex", runtimeName: "tabIndex", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), reads: []),
        MonaEditorOption(id: 141, name: "trimWhitespaceOnDelete", runtimeName: "trimWhitespaceOnDelete", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 142, name: "unicodeHighlight", runtimeName: "unicodeHighlight", disposition: .retainedInput, kind: .object, defaultValue: .object(["allowedCharacters": .object([:]), "allowedLocales": .object(["_os": .bool(true), "_vscode": .bool(true)]), "ambiguousCharacters": .bool(true), "includeComments": .string("inUntrustedWorkspace"), "includeStrings": .bool(true), "invisibleCharacters": .bool(true), "nonBasicASCII": .string("inUntrustedWorkspace")]), reads: []),
        MonaEditorOption(id: 143, name: "unusualLineTerminators", runtimeName: "unusualLineTerminators", disposition: .retainedInput, kind: .enumString, defaultValue: .string("prompt"), enumMembers: ["auto", "off", "prompt"], reads: []),
        MonaEditorOption(id: 144, name: "useShadowDOM", runtimeName: "useShadowDOM", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 145, name: "useTabStops", runtimeName: "useTabStops", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 146, name: "wordBreak", runtimeName: "wordBreak", disposition: .retainedInput, kind: .enumString, defaultValue: .string("normal"), enumMembers: ["normal", "keepAll"], reads: []),
        MonaEditorOption(id: 147, name: "wordSegmenterLocales", runtimeName: "wordSegmenterLocales", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 148, name: "wordSeparators", runtimeName: "wordSeparators", disposition: .retainedInput, kind: .string, defaultValue: .string("`~!@#$%^&*()-=+[{]}\\|;:'\",.<>/?"), reads: []),
        MonaEditorOption(id: 149, name: "wordWrap", runtimeName: "wordWrap", disposition: .retainedInput, kind: .enumString, defaultValue: .string("off"), enumMembers: ["off", "on", "wordWrapColumn", "bounded"], reads: []),
        MonaEditorOption(id: 150, name: "wordWrapBreakAfterCharacters", runtimeName: "wordWrapBreakAfterCharacters", disposition: .retainedInput, kind: .string, defaultValue: .string(" \t})]?|/&.,;¢°′″‰℃、。｡､￠，．：；？！％・･ゝゞヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎゕゖㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻ｧｨｩｪｫｬｭｮｯｰ”〉》」』】〕）］｝｣"), reads: []),
        MonaEditorOption(id: 151, name: "wordWrapBreakBeforeCharacters", runtimeName: "wordWrapBreakBeforeCharacters", disposition: .retainedInput, kind: .string, defaultValue: .string("([{‘“〈《「『【〔（［｛｢£¥＄￡￥+＋"), reads: []),
        MonaEditorOption(id: 152, name: "wordWrapColumn", runtimeName: "wordWrapColumn", disposition: .retainedInput, kind: .integer, defaultValue: .int(80), bounds: MonaOptionBounds(minInt: 1, maxInt: 1073741824), reads: []),
        MonaEditorOption(id: 153, name: "wordWrapOverride1", runtimeName: "wordWrapOverride1", disposition: .retainedInput, kind: .string, defaultValue: .string("inherit"), reads: []),
        MonaEditorOption(id: 154, name: "wordWrapOverride2", runtimeName: "wordWrapOverride2", disposition: .retainedInput, kind: .string, defaultValue: .string("inherit"), reads: []),
        MonaEditorOption(id: 155, name: "wrappingIndent", runtimeName: "wrappingIndent", disposition: .retainedInput, kind: .integer, defaultValue: .int(0), reads: []),
        MonaEditorOption(id: 156, name: "wrappingStrategy", runtimeName: "wrappingStrategy", disposition: .retainedInput, kind: .string, defaultValue: .string("simple"), reads: []),
        MonaEditorOption(id: 157, name: "showDeprecated", runtimeName: "showDeprecated", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
        MonaEditorOption(id: 158, name: "inertialScroll", runtimeName: "inertialScroll", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 159, name: "inlayHints", runtimeName: "inlayHints", disposition: .retainedInput, kind: .object, defaultValue: .object(["enabled": .string("on"), "fontFamily": .string(""), "fontSize": .int(0), "maximumLength": .int(43), "padding": .bool(false)]), reads: []),
        MonaEditorOption(id: 160, name: "wrapOnEscapedLineFeeds", runtimeName: "wrapOnEscapedLineFeeds", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 161, name: "effectiveCursorStyle", runtimeName: "_never_", disposition: .computedOnly, kind: nil, defaultValue: .null, reads: ["cursorStyle", "cursorWidth", "cursorBlinking"]),
        MonaEditorOption(id: 162, name: "editorClassName", runtimeName: "_never_", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 163, name: "pixelRatio", runtimeName: "_never_", disposition: .computedOnly, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 164, name: "tabFocusMode", runtimeName: "tabFocusMode", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 165, name: "layoutInfo", runtimeName: "_never_", disposition: .computedOnly, kind: nil, defaultValue: .null, reads: ["fontInfo", "wrappingInfo", "lineDecorationsWidth", "glyphMargin", "lineNumbersMinChars", "folding", "minimap", "scrollbar", "padding", "wordWrap"]),
        MonaEditorOption(id: 166, name: "wrappingInfo", runtimeName: "_never_", disposition: .computedOnly, kind: nil, defaultValue: .null, reads: ["wordWrap", "wordWrapColumn", "wordWrapOverride1", "wordWrapOverride2", "wrappingIndent", "wrappingStrategy", "fontInfo"]),
        MonaEditorOption(id: 167, name: "defaultColorDecorators", runtimeName: "defaultColorDecorators", disposition: .retainedInput, kind: .enumString, defaultValue: .string("auto"), enumMembers: ["auto", "always", "never"], reads: []),
        MonaEditorOption(id: 168, name: "colorDecoratorActivatedOn", runtimeName: "colorDecoratorsActivatedOn", disposition: .retainedInput, kind: .enumString, defaultValue: .string("clickAndHover"), enumMembers: ["clickAndHover", "hover", "click"], reads: []),
        MonaEditorOption(id: 169, name: "inlineCompletionsAccessibilityVerbose", runtimeName: "inlineCompletionsAccessibilityVerbose", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 170, name: "effectiveEditContextEnabled", runtimeName: "_never_", disposition: .cut, kind: nil, defaultValue: .null, reads: []),
        MonaEditorOption(id: 171, name: "scrollOnMiddleClick", runtimeName: "scrollOnMiddleClick", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(false), reads: []),
        MonaEditorOption(id: 172, name: "effectiveAllowVariableFonts", runtimeName: "_never_", disposition: .computedOnly, kind: nil, defaultValue: .null, reads: ["allowVariableFonts", "allowVariableFontsInAccessibilityMode", "accessibilitySupport"]),
        MonaEditorOption(id: 173, name: "doubleClickSelectsBlock", runtimeName: "doubleClickSelectsBlock", disposition: .retainedInput, kind: .boolean, defaultValue: .bool(true), reads: []),
    ]

    /// The 157 retained-input (mutable) options, in source order.
    public static let retainedInputOptions: [MonaEditorOption] = options.filter { $0.disposition == .retainedInput }

    /// The 6 computed-only (read-only derived) options, in source order.
    public static let computedOnlyOptions: [MonaEditorOption] = options.filter { $0.disposition == .computedOnly }

    /// The 11 cut (excluded) options, in source order.
    public static let cutOptions: [MonaEditorOption] = options.filter { $0.disposition == .cut }

    /// Lookup by name.
    public static func option(named name: String) -> MonaEditorOption? {
        return options.first { $0.name == name }
    }
}
