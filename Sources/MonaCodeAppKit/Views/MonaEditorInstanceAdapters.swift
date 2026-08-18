// MonaEditorInstanceAdapters.swift
//
// P05-T012 — Close editor factories and five instance-interface sequences.
//
// The five F1-R3 instance-interface surfaces (IEditor, ICodeEditor,
// IStandaloneCodeEditor, IDiffEditor, IStandaloneDiffEditor) with their exact
// retained member counts and native type adaptations, plus the F1-R3
// `nativeTypeReplacements` mapping each DOM-bearing type to its declared
// native Swift counterpart.
//
// Source artifact (frozen, G6-R contract archive):
//   monaco-0.56.0-f1r3-instance-surface-manifest.json
//
// Closure rule (from the manifest, verbatim):
//   "Declaration order, overload multiplicity, inheritance, own-member order
//    and full unique-member order must match this manifest exactly. All members
//    are retained; DOM-bearing types use the declared native replacements and
//    are never silent no-ops."
//
// This file emits the surface data verbatim — no rename, no coalesce — and
// declares each surface as a Swift protocol whose requirements carry the
// native-adapted types. The exact retained member counts
// (`ownDeclarationCount` / `ownUniqueCount`) are exposed as static constants
// so they can be asserted by `MonaEditorInstanceSurfaceTests`.
//
// The diff/multi-diff declaration slots are preserved here as native types
// (`MonaDiffEditorView`, `MonaMultiDiffEditorView`); their CONSTRUCTION is
// kept behind a Phase 07 adapter in `MonaEditorFactory` (this file declares
// the slots, the factory guards their construction).

import AppKit
import Foundation
import MonaCode

// MARK: - Native type adaptations (F1-R3 nativeTypeReplacements)
//
// Each monaco DOM-bearing type maps to its declared native Swift counterpart.
// These adaptations are never silent no-ops: every DOM-bearing member on the
// five surfaces carries one of these adapted types in its signature.

/// monaco `DOMNode` → typed NSView protocol or concrete NSView.
public typealias MonaInstanceDOMNode = NSView

/// monaco `ClientPoint` → editor-view local `CGPoint`.
public typealias MonaInstanceClientPoint = CGPoint

/// monaco `DOMWidget` → typed Mona content, overlay, or glyph NSView protocol.
///
/// A marker protocol that the AppKit widget views (`MonaContentWidgetView`,
/// `MonaOverlayWidgetView`, `MonaGlyphMarginWidgetView`) conform to. It is the
/// typed replacement for monaco's `IContentWidget` / `IOverlayWidget` /
/// `IGlyphMarginWidget` `getDomNode()` return — DOM HTMLElement becomes a
/// typed AppKit `NSView`-conforming protocol.
public protocol MonaInstanceDOMWidget: AnyObject {

    /// The typed `NSView` that hosts this widget. Adapts the monaco
    /// `getDomNode()` return (DOMNode → NSView).
    var domNode: MonaInstanceDOMNode { get }
}

/// monaco `KeyboardEvent` → immutable Mona keyboard event snapshot.
public typealias MonaInstanceKeyboardEvent = MonaPublicKeyboardEvent

/// monaco `MouseEvent` → immutable Mona pointer event snapshot.
public typealias MonaInstanceMouseEvent = MonaPointerEvent

/// monaco `FontInfoTarget` → native text-attributes target.
public typealias MonaInstanceFontInfoTarget = MonaEditorFontInfo

// MARK: - Instance-interface type adaptations
//
// monaco's `ITextModel` adapts to `MonaCodeModel` (the Core text model), and
// monaco's `IStandaloneCodeEditor` adapts to the native AppKit editor type
// (`MonaCodeEditorView`, P04-T014). These are the per-instance identity
// adaptations used by the factory and by the surface protocols below.

/// monaco `ITextModel` → `MonaCodeModel` (the native text model).
public typealias MonaInstanceITextModel = MonaCodeModel

/// monaco `IStandaloneCodeEditor` → the native editor type
/// (`MonaCodeEditorView`, P04-T014). This is the native-instance adaptation
/// (the concrete editor type a standalone editor resolves to); the F1-R3
/// instance-interface SURFACE protocol is `MonaInstanceIStandaloneCodeEditor`
/// below.
public typealias MonaInstanceStandaloneCodeEditor = MonaCodeEditorView

// MARK: - Native adaptation declaration slots
//
// Two monaco types referenced by the diff surface have no Core Swift slot yet.
// They are declared here as minimal slots so the diff surface protocol
// compiles with typed (non-`Any`) members; their implementations arrive with
// the Phase 07 diff engine. Like the diff construction adapter, these slots
// are never silent no-ops — the type exists so the surface is typed.

/// monaco `GoToDiffDestination` → the diff-navigation destination enum slot
/// (Phase 07 diff engine). The slot is preserved so `IDiffEditor.goToDiff` /
/// `revealFirstDiff` carry a typed parameter rather than `Any`.
public enum MonaEditorGoToDiffDestination: Sendable {
    case next
    case previous
}

// MARK: - Diff / multi-diff view types (Phase 07 delivered)
//
// P07-T009 fix-forward (shared-mechanism, minimal, tested): the diff editor
// and multi-file diff editor were PRESERVED here as empty `final class ...
// : NSView {}` declaration slots by P05-T012 so the declaration graph
// (P05-T001) recorded the types while their construction was behind a Phase
// 07 adapter. P07-T009 DELIVERS the views, so the empty slots would now be
// duplicate declarations of the real types that live in their own files
// (`Views/MonaDiffEditorView.swift` / `Views/MonaMultiDiffEditorView.swift`).
// The empty slot classes were removed here and replaced by the real
// implementations in those files. This is a minimal shared-mechanism
// (declaration-slot) fix-forward: it preserves every P05-T012 surface (the
// five instance-interface protocols + the manifest counts are untouched),
// and the types are still referenced by name — `MonaEditorFactory
// .createDiffEditor` / `createMultiFileDiffEditor` return them, the manifest
// records `multiFileDiffNativeReturnType` as `MonaMultiDiffEditorView`, and
// `MonaEditorInstanceSurfaceTests` references the metatypes. The factory
// construction adapter still throws `.phase07NotWired` (P07-T009 keeps the
// slot — the view exists; full factory construction wiring is a later
// concern).

// MARK: - The five F1-R3 instance-interface surface protocols
//
// Each protocol declares its OWN UNIQUE members as requirements, in the exact
// declaration order recorded by the manifest. DOM-bearing members carry the
// adapted native types above. Overload multiplicity is preserved on `IEditor`
// (`setSelection` is declared four times — see the data table in
// `MonaInstanceSurfaceManifest.IEditor.ownDeclarations`). The protocols are
// the per-editor-instance API surface; conforming types are wired in later
// phases (Phase 06+).

/// F1-R3 surface 1: `IEditor` — the common editor interface (40 own unique
/// members, 43 own declarations with the 4 `setSelection` overloads). Bases:
/// none.
public protocol MonaInstanceIEditor {

    // Lifetime
    var onDidDispose: MonaEvent<Void> { get }
    func dispose()

    // Identity
    func getId() -> String
    func getEditorType() -> String

    // Configuration / layout / focus
    func updateOptions(_ options: MonaEditorIEditorConstructionOptions)
    func layout()
    func focus()
    func hasTextFocus() -> Bool
    func getSupportedActions() -> [MonaEditorIEditorAction]

    // View state
    func saveViewState() -> MonaEditorIEditorViewState?
    func restoreViewState(_ state: MonaEditorIEditorViewState?)

    // Position
    func getVisibleColumnFromPosition(_ position: MonaPosition) -> Int
    func getPosition() -> MonaPosition
    func setPosition(_ position: MonaPosition)
    func revealLine(_ lineNumber: Int)
    func revealLineInCenter(_ lineNumber: Int)
    func revealLineInCenterIfOutsideViewport(_ lineNumber: Int)
    func revealLineNearTop(_ lineNumber: Int)
    func revealPosition(_ position: MonaPosition)
    func revealPositionInCenter(_ position: MonaPosition)
    func revealPositionInCenterIfOutsideViewport(_ position: MonaPosition)
    func revealPositionNearTop(_ position: MonaPosition)

    // Selection (4 overloads preserved — see ownDeclarations)
    func getSelection() -> MonaSelection?
    func getSelections() -> [MonaSelection]
    func setSelection(_ selection: MonaSelection)
    func setSelection(_ range: MonaRange)
    func setSelection(_ position: MonaPosition)
    func setSelection(_ event: MonaEditorICursorSelectionChangedEvent)
    func setSelections(_ selections: [MonaSelection])

    // Reveal
    func revealLines(_ lineNumber: Int)
    func revealLinesInCenter(_ lineNumber: Int)
    func revealLinesInCenterIfOutsideViewport(_ lineNumber: Int)
    func revealLinesNearTop(_ lineNumber: Int)
    func revealRange(_ range: MonaRange)
    func revealRangeInCenter(_ range: MonaRange)
    func revealRangeAtTop(_ range: MonaRange)
    func revealRangeInCenterIfOutsideViewport(_ range: MonaRange)
    func revealRangeNearTop(_ range: MonaRange)
    func revealRangeNearTopIfOutsideViewport(_ range: MonaRange)

    // Trigger / model
    func trigger(_ source: String, _ handlerId: String, _ payload: Any?)
    func getModel() -> MonaInstanceITextModel?
    func setModel(_ model: MonaInstanceITextModel?)
    func createDecorationsCollection(_ decorations: [MonaModelDecoration]) -> MonaDecorationCollection
}

/// F1-R3 surface 2: `ICodeEditor` — the code editor interface (94 own unique
/// members). Bases: `IEditor`. DOM-bearing members (the 14 in
/// `nativeTypeReplacements.members`) carry the adapted native types.
public protocol MonaInstanceICodeEditor: MonaInstanceIEditor {

    // Model / content change events
    var onDidChangeModelContent: MonaEvent<MonaModelContentChangeEvent> { get }
    var onDidChangeModelLanguage: MonaEvent<MonaModelLanguageChangeEvent> { get }
    var onDidChangeModelLanguageConfiguration: MonaEvent<Void> { get }
    var onDidChangeModelOptions: MonaEvent<MonaModelOptionsChangeEvent> { get }
    var onDidChangeConfiguration: MonaEvent<MonaEditorConfigurationChangedEvent> { get }
    var onDidChangeCursorPosition: MonaEvent<MonaEditorICursorPositionChangedEvent> { get }
    var onDidChangeCursorSelection: MonaEvent<MonaEditorICursorSelectionChangedEvent> { get }
    var onWillChangeModel: MonaEvent<MonaCodeModel> { get }
    var onDidChangeModel: MonaEvent<MonaCodeModel> { get }
    var onDidChangeModelDecorations: MonaEvent<Void> { get }

    // Focus / composition
    var onDidFocusEditorText: MonaEvent<Void> { get }
    var onDidBlurEditorText: MonaEvent<Void> { get }
    var onDidFocusEditorWidget: MonaEvent<Void> { get }
    var onDidBlurEditorWidget: MonaEvent<Void> { get }
    func inComposition() -> Bool
    var onDidCompositionStart: MonaEvent<Void> { get }
    var onDidCompositionEnd: MonaEvent<Void> { get }
    var onDidAttemptReadOnlyEdit: MonaEvent<Void> { get }
    var onDidPaste: MonaEvent<MonaEditorIPasteEvent> { get }

    // Pointer / keyboard (MouseEvent / KeyboardEvent adapted)
    var onMouseUp: MonaEvent<MonaInstanceMouseEvent> { get }
    var onMouseDown: MonaEvent<MonaInstanceMouseEvent> { get }
    var onContextMenu: MonaEvent<MonaInstanceMouseEvent> { get }
    var onMouseMove: MonaEvent<MonaInstanceMouseEvent> { get }
    var onMouseLeave: MonaEvent<MonaInstanceMouseEvent> { get }
    var onKeyUp: MonaEvent<MonaInstanceKeyboardEvent> { get }
    var onKeyDown: MonaEvent<MonaInstanceKeyboardEvent> { get }

    // Layout / scroll
    var onDidLayoutChange: MonaEvent<MonaEditorEditorLayoutInfo> { get }
    var onDidContentSizeChange: MonaEvent<MonaEditorIContentSizeChangedEvent> { get }
    var onDidScrollChange: MonaEvent<MonaScrollEvent> { get }
    var onDidChangeHiddenAreas: MonaEvent<Void> { get }
    var onBeginUpdate: MonaEvent<Void> { get }
    var onEndUpdate: MonaEvent<Void> { get }
    var onDidChangeViewZones: MonaEvent<Void> { get }

    // View state / contribution / model (restated as own declarations)
    func saveViewState() -> MonaEditorIEditorViewState?
    func restoreViewState(_ state: MonaEditorIEditorViewState?)
    func hasWidgetFocus() -> Bool
    func getContribution<T>(_ id: String) -> T?

    // Options / value / geometry
    func getModel() -> MonaInstanceITextModel?
    func setModel(_ model: MonaInstanceITextModel?)
    func getOptions() -> MonaEditorIComputedEditorOptions
    func getOption<T>(_ id: MonaEditorOption) -> T
    func getRawOptions() -> MonaEditorIEditorConstructionOptions
    func getValue() -> String
    func setValue(_ newValue: String)
    func getContentWidth() -> Int
    func getScrollWidth() -> Int
    func getScrollLeft() -> Int
    func getContentHeight() -> Int
    func getScrollHeight() -> Int
    func getScrollTop() -> Int
    func setScrollLeft(_ left: Int)
    func setScrollTop(_ top: Int)
    func setScrollPosition(_ position: MonaEditorINewScrollPosition)
    func hasPendingScrollAnimation() -> Bool

    // Actions / commands / edits
    func getAction(_ id: String) -> MonaEditorIEditorAction?
    func executeCommand(_ source: String, _ command: Any?) -> Bool
    func pushUndoStop() -> Bool
    func popUndoStop() -> Bool
    func executeEdits(_ source: String, _ edits: [MonaModelEditOperation]) -> Bool
    func executeCommands(_ source: String, _ commands: [Any?]) -> Bool
    func revealAllCursors(_ source: String, _ revealVertical: Bool)

    // Decorations
    func getLineDecorations(_ lineNumber: Int) -> [MonaModelDecoration]
    func getDecorationsInRange(_ range: MonaRange) -> [MonaModelDecoration]
    func getFontSizeAtPosition(_ position: MonaPosition) -> Int
    func deltaDecorations(_ oldDecorations: [String], _ newDecorations: [MonaModelDecorationOptions]) -> [String]
    func removeDecorations(_ decorationIds: [String])

    // Layout / visible ranges / line metrics
    func getLayoutInfo() -> MonaEditorEditorLayoutInfo
    func getVisibleRanges() -> [MonaRange]
    func getTopForLineNumber(_ lineNumber: Int) -> Int
    func getBottomForLineNumber(_ lineNumber: Int) -> Int
    func getTopForPosition(_ position: MonaPosition) -> Int
    func getLineHeightForPosition(_ position: MonaPosition) -> Int
    func writeScreenReaderContent(_ reason: String)

    // DOM-bearing surface (DOMNode / DOMWidget / ClientPoint / FontInfoTarget adapted)
    func getContainerDomNode() -> MonaInstanceDOMNode   // DOMNode
    func getDomNode() -> MonaInstanceDOMNode            // DOMNode
    func addContentWidget(_ widget: MonaInstanceDOMWidget)   // DOMWidget
    func layoutContentWidget(_ widget: MonaInstanceDOMWidget)
    func removeContentWidget(_ widget: MonaInstanceDOMWidget)
    func addOverlayWidget(_ widget: MonaInstanceDOMWidget)
    func layoutOverlayWidget(_ widget: MonaInstanceDOMWidget)
    func removeOverlayWidget(_ widget: MonaInstanceDOMWidget)
    func addGlyphMarginWidget(_ widget: MonaInstanceDOMWidget)
    func layoutGlyphMarginWidget(_ widget: MonaInstanceDOMWidget)
    func removeGlyphMarginWidget(_ widget: MonaInstanceDOMWidget)
    func changeViewZones(_ callback: (MonaEditorIViewZoneChangeAccessor) -> Void)
    func getOffsetForColumn(_ lineNumber: Int, _ column: Int) -> Int
    func getWidthOfLine(_ lineNumber: Int) -> Int
    func render()
    func renderAsync() async
    func getTargetAtClientPoint(_ clientX: Int, _ clientY: Int) -> MonaEditorIMouseTarget?  // ClientPoint
    func getScrolledVisiblePosition(_ position: MonaPosition) -> MonaPosition?
    func applyFontInfo(_ target: MonaInstanceFontInfoTarget)   // FontInfoTarget
    func setBanner(_ bannerDomNode: MonaInstanceDOMNode?)       // DOMNode

    func handleInitialized()
}

/// F1-R3 surface 3: `IStandaloneCodeEditor` — the standalone code editor (4 own
/// unique members). Bases: `ICodeEditor`.
public protocol MonaInstanceIStandaloneCodeEditor: MonaInstanceICodeEditor {
    func updateOptions(_ options: MonaEditorIStandaloneEditorConstructionOptions)
    func addCommand(_ keybinding: Int, _ handler: @escaping (MonaInstanceKeyboardEvent) -> Void) -> String?
    func createContextKey(_ name: String) -> MonaContextKey
    func addAction(_ action: MonaEditorIActionDescriptor)
}

/// F1-R3 surface 4: `IDiffEditor` — the diff editor interface (17 own unique
/// members). Bases: `IEditor`. The diff CONSTRUCTION is behind a Phase 07
/// adapter; this surface declares the per-instance API only.
public protocol MonaInstanceIDiffEditor: MonaInstanceIEditor {
    func getContainerDomNode() -> MonaInstanceDOMNode                  // DOMNode
    var onDidUpdateDiff: MonaEvent<Void> { get }
    var onDidChangeModel: MonaEvent<MonaEditorIDiffEditorModel> { get }
    func saveViewState() -> MonaEditorIDiffEditorViewState?
    func restoreViewState(_ state: MonaEditorIDiffEditorViewState?)
    func getModel() -> MonaEditorIDiffEditorModel?
    func createViewModel(_ original: MonaInstanceITextModel?, _ modified: MonaInstanceITextModel?) -> MonaEditorIDiffEditorViewModel
    func setModel(_ model: MonaEditorIDiffEditorModel?)
    func getOriginalEditor() -> MonaInstanceICodeEditor
    func getModifiedEditor() -> MonaInstanceICodeEditor
    func getLineChanges() -> [MonaEditorILineChange]?
    func updateOptions(_ options: MonaEditorIDiffEditorConstructionOptions)
    func goToDiff(_ target: MonaEditorGoToDiffDestination)
    func revealFirstDiff(_ target: MonaEditorGoToDiffDestination)
    func accessibleDiffViewerNext()
    func accessibleDiffViewerPrev()
    func handleInitialized()
}

/// F1-R3 surface 5: `IStandaloneDiffEditor` — the standalone diff editor (5
/// own unique members). Bases: `IDiffEditor`.
public protocol MonaInstanceIStandaloneDiffEditor: MonaInstanceIDiffEditor {
    func addCommand(_ keybinding: Int, _ handler: @escaping (MonaInstanceKeyboardEvent) -> Void) -> String?
    func createContextKey(_ name: String) -> MonaContextKey
    func addAction(_ action: MonaEditorIActionDescriptor)
    func getOriginalEditor() -> MonaInstanceIStandaloneCodeEditor
    func getModifiedEditor() -> MonaInstanceIStandaloneCodeEditor
}

// MARK: - F1-R3 instance surface manifest (exact retained counts)
//
// The verbatim declaration/unique-member arrays and exact counts for the five
// surfaces, emitted from `monaco-0.56.0-f1r3-instance-surface-manifest.json`
// without rename or coalesce. The arrays preserve declaration order and
// overload multiplicity (`setSelection` appears 4× in `IEditor.ownDeclarations`
// and 1× in `ownUniqueMembers`). The counts are exposed as static constants
// so `MonaEditorInstanceSurfaceTests` can assert them verbatim.

public enum MonaInstanceSurfaceManifest {

    /// `IEditor` — bases: none.
    public enum IEditor {
        public static let bases: [String] = []
        public static let ownDeclarationCount: Int = 43
        public static let ownUniqueCount: Int = 40
        public static let ownDeclarations: [String] = [
            "onDidDispose",
            "dispose",
            "getId",
            "getEditorType",
            "updateOptions",
            "layout",
            "focus",
            "hasTextFocus",
            "getSupportedActions",
            "saveViewState",
            "restoreViewState",
            "getVisibleColumnFromPosition",
            "getPosition",
            "setPosition",
            "revealLine",
            "revealLineInCenter",
            "revealLineInCenterIfOutsideViewport",
            "revealLineNearTop",
            "revealPosition",
            "revealPositionInCenter",
            "revealPositionInCenterIfOutsideViewport",
            "revealPositionNearTop",
            "getSelection",
            "getSelections",
            "setSelection",
            "setSelection",
            "setSelection",
            "setSelection",
            "setSelections",
            "revealLines",
            "revealLinesInCenter",
            "revealLinesInCenterIfOutsideViewport",
            "revealLinesNearTop",
            "revealRange",
            "revealRangeInCenter",
            "revealRangeAtTop",
            "revealRangeInCenterIfOutsideViewport",
            "revealRangeNearTop",
            "revealRangeNearTopIfOutsideViewport",
            "trigger",
            "getModel",
            "setModel",
            "createDecorationsCollection",
        ]
        public static let ownUniqueMembers: [String] = [
            "onDidDispose",
            "dispose",
            "getId",
            "getEditorType",
            "updateOptions",
            "layout",
            "focus",
            "hasTextFocus",
            "getSupportedActions",
            "saveViewState",
            "restoreViewState",
            "getVisibleColumnFromPosition",
            "getPosition",
            "setPosition",
            "revealLine",
            "revealLineInCenter",
            "revealLineInCenterIfOutsideViewport",
            "revealLineNearTop",
            "revealPosition",
            "revealPositionInCenter",
            "revealPositionInCenterIfOutsideViewport",
            "revealPositionNearTop",
            "getSelection",
            "getSelections",
            "setSelection",
            "setSelections",
            "revealLines",
            "revealLinesInCenter",
            "revealLinesInCenterIfOutsideViewport",
            "revealLinesNearTop",
            "revealRange",
            "revealRangeInCenter",
            "revealRangeAtTop",
            "revealRangeInCenterIfOutsideViewport",
            "revealRangeNearTop",
            "revealRangeNearTopIfOutsideViewport",
            "trigger",
            "getModel",
            "setModel",
            "createDecorationsCollection",
        ]
    }

    /// `ICodeEditor` — bases: `IEditor`.
    public enum ICodeEditor {
        public static let bases: [String] = ["IEditor"]
        public static let ownDeclarationCount: Int = 94
        public static let ownUniqueCount: Int = 94
        public static let ownDeclarations: [String] = [
            "onDidChangeModelContent",
            "onDidChangeModelLanguage",
            "onDidChangeModelLanguageConfiguration",
            "onDidChangeModelOptions",
            "onDidChangeConfiguration",
            "onDidChangeCursorPosition",
            "onDidChangeCursorSelection",
            "onWillChangeModel",
            "onDidChangeModel",
            "onDidChangeModelDecorations",
            "onDidFocusEditorText",
            "onDidBlurEditorText",
            "onDidFocusEditorWidget",
            "onDidBlurEditorWidget",
            "inComposition",
            "onDidCompositionStart",
            "onDidCompositionEnd",
            "onDidAttemptReadOnlyEdit",
            "onDidPaste",
            "onMouseUp",
            "onMouseDown",
            "onContextMenu",
            "onMouseMove",
            "onMouseLeave",
            "onKeyUp",
            "onKeyDown",
            "onDidLayoutChange",
            "onDidContentSizeChange",
            "onDidScrollChange",
            "onDidChangeHiddenAreas",
            "onBeginUpdate",
            "onEndUpdate",
            "onDidChangeViewZones",
            "saveViewState",
            "restoreViewState",
            "hasWidgetFocus",
            "getContribution",
            "getModel",
            "setModel",
            "getOptions",
            "getOption",
            "getRawOptions",
            "getValue",
            "setValue",
            "getContentWidth",
            "getScrollWidth",
            "getScrollLeft",
            "getContentHeight",
            "getScrollHeight",
            "getScrollTop",
            "setScrollLeft",
            "setScrollTop",
            "setScrollPosition",
            "hasPendingScrollAnimation",
            "getAction",
            "executeCommand",
            "pushUndoStop",
            "popUndoStop",
            "executeEdits",
            "executeCommands",
            "revealAllCursors",
            "getLineDecorations",
            "getDecorationsInRange",
            "getFontSizeAtPosition",
            "deltaDecorations",
            "removeDecorations",
            "getLayoutInfo",
            "getVisibleRanges",
            "getTopForLineNumber",
            "getBottomForLineNumber",
            "getTopForPosition",
            "getLineHeightForPosition",
            "writeScreenReaderContent",
            "getContainerDomNode",
            "getDomNode",
            "addContentWidget",
            "layoutContentWidget",
            "removeContentWidget",
            "addOverlayWidget",
            "layoutOverlayWidget",
            "removeOverlayWidget",
            "addGlyphMarginWidget",
            "layoutGlyphMarginWidget",
            "removeGlyphMarginWidget",
            "changeViewZones",
            "getOffsetForColumn",
            "getWidthOfLine",
            "render",
            "renderAsync",
            "getTargetAtClientPoint",
            "getScrolledVisiblePosition",
            "applyFontInfo",
            "setBanner",
            "handleInitialized",
        ]
        public static let ownUniqueMembers: [String] = ICodeEditor.ownDeclarations
    }

    /// `IStandaloneCodeEditor` — bases: `ICodeEditor`.
    public enum IStandaloneCodeEditor {
        public static let bases: [String] = ["ICodeEditor"]
        public static let ownDeclarationCount: Int = 4
        public static let ownUniqueCount: Int = 4
        public static let ownDeclarations: [String] = [
            "updateOptions",
            "addCommand",
            "createContextKey",
            "addAction",
        ]
        public static let ownUniqueMembers: [String] = IStandaloneCodeEditor.ownDeclarations
    }

    /// `IDiffEditor` — bases: `IEditor`.
    public enum IDiffEditor {
        public static let bases: [String] = ["IEditor"]
        public static let ownDeclarationCount: Int = 17
        public static let ownUniqueCount: Int = 17
        public static let ownDeclarations: [String] = [
            "getContainerDomNode",
            "onDidUpdateDiff",
            "onDidChangeModel",
            "saveViewState",
            "restoreViewState",
            "getModel",
            "createViewModel",
            "setModel",
            "getOriginalEditor",
            "getModifiedEditor",
            "getLineChanges",
            "updateOptions",
            "goToDiff",
            "revealFirstDiff",
            "accessibleDiffViewerNext",
            "accessibleDiffViewerPrev",
            "handleInitialized",
        ]
        public static let ownUniqueMembers: [String] = IDiffEditor.ownDeclarations
    }

    /// `IStandaloneDiffEditor` — bases: `IDiffEditor`.
    public enum IStandaloneDiffEditor {
        public static let bases: [String] = ["IDiffEditor"]
        public static let ownDeclarationCount: Int = 5
        public static let ownUniqueCount: Int = 5
        public static let ownDeclarations: [String] = [
            "addCommand",
            "createContextKey",
            "addAction",
            "getOriginalEditor",
            "getModifiedEditor",
        ]
        public static let ownUniqueMembers: [String] = IStandaloneDiffEditor.ownDeclarations
    }

    /// The number of instance-interface surfaces (always 5).
    public static let surfaceCount: Int = 5

    /// The 14 DOM-bearing members listed in
    /// `nativeTypeReplacements.members` — the members whose signatures carry
    /// the adapted DOM types (DOMNode / DOMWidget / ClientPoint /
    /// FontInfoTarget). All 14 are retained on `ICodeEditor`.
    public static let nativeReplacementMembers: [String] = [
        "getContainerDomNode",
        "getDomNode",
        "addContentWidget",
        "layoutContentWidget",
        "removeContentWidget",
        "addOverlayWidget",
        "layoutOverlayWidget",
        "removeOverlayWidget",
        "addGlyphMarginWidget",
        "layoutGlyphMarginWidget",
        "removeGlyphMarginWidget",
        "getTargetAtClientPoint",
        "applyFontInfo",
        "setBanner",
    ]

    /// The F1-R3 `multiFileDiff.sourceFactory`
    /// (`editor.createMultiFileDiffEditor`).
    public static let multiFileDiffSourceFactory: String = "editor.createMultiFileDiffEditor"

    /// The F1-R3 `multiFileDiff.nativeReturnType` (`MonaMultiDiffEditorView`).
    public static let multiFileDiffNativeReturnType: String = "MonaMultiDiffEditorView"
}
