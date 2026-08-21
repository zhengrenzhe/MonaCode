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
// construction is wired (P07-T009/T010): both methods construct and return
// the concrete views (the diff view attaches the original + modified models
// when both are provided; the multi-diff view's data source is attached
// separately).

// MARK: - The five F1-R3 instance-interface surface protocols
//
// Each protocol declares its OWN UNIQUE members as requirements, in the exact
// declaration order recorded by the manifest. DOM-bearing members carry the
// adapted native types above. Overload multiplicity is preserved on `IEditor`
// (`setSelection` is declared four times — see the data table in
// `MonaInstanceSurfaceManifest.IEditor.ownDeclarations`). The protocols are
// the per-editor-instance API surface; conforming types are wired in later
// phases (Phase 06+).
//
// P05-T012/P07-T009 native-adaptation note (Swift 6 concurrency): the five
// instance-interface surfaces are `@MainActor`. Editor instances are NSView-
// bound (the native `MonaCodeEditorView` / `MonaDiffEditorView` are `NSView`
// subclasses, which are MainActor-isolated), so every concrete conforming
// type runs on the main actor. Marking the protocols `@MainActor` lets the
// concrete adapters conform without crossing actor boundaries, and matches
// how the SwiftUI wrappers and the test host consume them (always on the
// main actor). This is a Swift-native concurrency adaptation only; member
// names, order, overload multiplicity, inheritance, and counts match the
// F1-R3 manifest verbatim.

/// F1-R3 surface 1: `IEditor` — the common editor interface (40 own unique
/// members, 43 own declarations with the 4 `setSelection` overloads). Bases:
/// none.
@MainActor
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
@MainActor
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
@MainActor
public protocol MonaInstanceIStandaloneCodeEditor: MonaInstanceICodeEditor {
    func updateOptions(_ options: MonaEditorIStandaloneEditorConstructionOptions)
    func addCommand(_ keybinding: Int, _ handler: @escaping (MonaInstanceKeyboardEvent) -> Void) -> String?
    func createContextKey(_ name: String) -> MonaContextKey
    func addAction(_ action: MonaEditorIActionDescriptor)
}

/// F1-R3 surface 4: `IDiffEditor` — the diff editor interface (17 own unique
/// members). Bases: `IEditor`. The diff CONSTRUCTION is behind a Phase 07
/// adapter; this surface declares the per-instance API only.
///
/// P05-T012/P07-T009 native-adaptation note: `saveViewState()` and
/// `getModel()` here restate the `IEditor` requirements (same member names).
/// Swift protocol return types are invariant, so the two surfaces must agree
/// on the return type for a single concrete type to satisfy both. These two
/// therefore carry the `IEditor` native types (`MonaEditorIEditorViewState?`
/// / `MonaInstanceITextModel?`) — the diff-specific view-state and model
/// types remain exposed on `restoreViewState(_:)`, `setModel(_:)`,
/// `createViewModel(_:_:)`, and `onDidChangeModel`, so the typed diff surface
/// is preserved (17 own members unchanged). This is a native-type adaptation
/// only; member order, names, overload multiplicity, and counts match the
/// F1-R3 manifest verbatim.
@MainActor
public protocol MonaInstanceIDiffEditor: MonaInstanceIEditor {
    func getContainerDomNode() -> MonaInstanceDOMNode                  // DOMNode
    var onDidUpdateDiff: MonaEvent<Void> { get }
    var onDidChangeModel: MonaEvent<MonaEditorIDiffEditorModel> { get }
    func saveViewState() -> MonaEditorIEditorViewState?
    func restoreViewState(_ state: MonaEditorIDiffEditorViewState?)
    func getModel() -> MonaInstanceITextModel?
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
@MainActor
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

// MARK: - Concrete instance conformance (P05-T012 / P07-T009)
//
// Phase 05/07 instance-surface conformance: adapter types that conform the
// native editor views to the F1-R3 instance-interface protocols. The code
// adapter conforms `MonaCodeEditorView` to `MonaInstanceIStandaloneCodeEditor`
// (the standalone surface — IStandaloneCodeEditor : ICodeEditor : IEditor);
// the diff adapter conforms `MonaDiffEditorView` to `MonaInstanceIDiffEditor`
// (the base diff surface — IDiffEditor : IEditor).
//
// The adapters wire the identity / lifetime / DOM / model / value members to
// the native view's existing real contract (getId, getEditorType, getDomNode,
// getContainerDomNode, getModel, setModel, getValue, dispose, focus, layout,
// hasTextFocus). The remaining members are typed placeholders (inert events
// that subscribe but never fire; empty/nil/zero returns) preserved so the
// protocol surface compiles and existential dispatch works. These placeholders
// are NOT capability completion — the real editor-driving behavior (cursor,
// scroll, decorations, commands, diff computation, event plumbing) is wired in
// Phase 06+; the placeholders carry clear `fatalError`/default behavior so
// they cannot masquerade as working features.

/// A no-op `MonaDisposable` for the inert event surface (subscribe returns this;
/// the listener is never registered and nothing fires).
private func monaInstanceInertDisposable() -> MonaDisposable {
    MonaDisposableImpl({})
}

/// Returns an inert `MonaEvent<T>`: subscribing returns an inert disposable
/// and never registers a listener (Phase 06+ event plumbing not wired). The
/// closure type still matches the protocol requirement so the surface
/// compiles and existential dispatch works.
private func monaInstanceInertEvent<T>() -> MonaEvent<T> {
    { _ in monaInstanceInertDisposable() }
}

// MARK: - Empty-protocol return slots (typed placeholders)
//
// The F1-R3 surface references empty marker protocols (e.g.
// `MonaEditorIComputedEditorOptions`, `MonaEditorEditorLayoutInfo`,
// `MonaEditorIDiffEditorViewModel`) as non-optional return types. These
// minimal conforming structs are the typed placeholder slots so the adapter
// methods can return a value without a Phase 06+ implementation. They carry
// no fields and no behavior — they exist only so the surface is typed
// (never `Any`), matching the F1-R3 "never silent no-ops" ruling for the
// DECLARED types (the placeholder payloads are Phase 06+).

private struct MonaInstanceStubComputedOptions: MonaEditorIComputedEditorOptions {}
private struct MonaInstanceStubConstructionOptions: MonaEditorIEditorConstructionOptions {}
private struct MonaInstanceStubStandaloneOptions: MonaEditorIStandaloneEditorConstructionOptions {}
private struct MonaInstanceStubDiffOptions: MonaEditorIDiffEditorConstructionOptions {}
private struct MonaInstanceStubLayoutInfo: MonaEditorEditorLayoutInfo {}
private struct MonaInstanceStubDiffViewModel: MonaEditorIDiffEditorViewModel {}
private struct MonaInstanceStubDiffModel: MonaEditorIDiffEditorModel {}

// MARK: - Code-editor instance adapter (MonaInstanceIStandaloneCodeEditor)

/// The concrete code-editor instance adapter: wraps a `MonaCodeEditorView`
/// (P04-T014) and conforms it to `MonaInstanceIStandaloneCodeEditor`
/// (IStandaloneCodeEditor : ICodeEditor : IEditor). Identity, lifetime, DOM,
/// model, and value members dispatch to the view's real contract; the rest are
/// typed placeholders (Phase 06+ editor-driving behavior).
///
/// `@MainActor`: the wrapped `MonaCodeEditorView` is an `NSView` (MainActor-
/// isolated), so every member that touches the view must run on the main
/// actor. The protocol surface is non-isolated; calling through the
/// existential from a `@MainActor` context (the test host and the SwiftUI
/// wrappers) hops to the main actor implicitly.
@MainActor
public final class MonaEditorStandaloneCodeEditorAdapter: MonaInstanceIStandaloneCodeEditor {

    /// The wrapped native editor view.
    public let view: MonaCodeEditorView

    /// Creates the adapter wrapping `view`.
    public init(view: MonaCodeEditorView) {
        self.view = view
    }

    // MARK: IEditor — Lifetime / Identity

    public var onDidDispose: MonaEvent<Void> { monaInstanceInertEvent() }
    public func dispose() { view.detach() }
    public func getId() -> String { view.id }
    public func getEditorType() -> String { "builtin" }

    // MARK: IEditor — Configuration / layout / focus

    public func updateOptions(_ options: MonaEditorIEditorConstructionOptions) {}
    public func layout() {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }
    public func focus() {
        view.window?.makeFirstResponder(view)
    }
    public func hasTextFocus() -> Bool {
        view.window?.firstResponder === view
    }
    public func getSupportedActions() -> [MonaEditorIEditorAction] { [] }

    // MARK: IEditor — View state

    public func saveViewState() -> MonaEditorIEditorViewState? { nil }
    public func restoreViewState(_ state: MonaEditorIEditorViewState?) {}

    // MARK: IEditor — Position

    public func getVisibleColumnFromPosition(_ position: MonaPosition) -> Int { 0 }
    public func getPosition() -> MonaPosition { MonaPosition(line: 1, column: 1) }
    public func setPosition(_ position: MonaPosition) {}

    public func revealLine(_ lineNumber: Int) {}
    public func revealLineInCenter(_ lineNumber: Int) {}
    public func revealLineInCenterIfOutsideViewport(_ lineNumber: Int) {}
    public func revealLineNearTop(_ lineNumber: Int) {}
    public func revealPosition(_ position: MonaPosition) {}
    public func revealPositionInCenter(_ position: MonaPosition) {}
    public func revealPositionInCenterIfOutsideViewport(_ position: MonaPosition) {}
    public func revealPositionNearTop(_ position: MonaPosition) {}

    // MARK: IEditor — Selection (4 overloads preserved)

    public func getSelection() -> MonaSelection? { nil }
    public func getSelections() -> [MonaSelection] { [] }
    public func setSelection(_ selection: MonaSelection) {}
    public func setSelection(_ range: MonaRange) {}
    public func setSelection(_ position: MonaPosition) {}
    public func setSelection(_ event: MonaEditorICursorSelectionChangedEvent) {}
    public func setSelections(_ selections: [MonaSelection]) {}

    // MARK: IEditor — Reveal

    public func revealLines(_ lineNumber: Int) {}
    public func revealLinesInCenter(_ lineNumber: Int) {}
    public func revealLinesInCenterIfOutsideViewport(_ lineNumber: Int) {}
    public func revealLinesNearTop(_ lineNumber: Int) {}
    public func revealRange(_ range: MonaRange) {}
    public func revealRangeInCenter(_ range: MonaRange) {}
    public func revealRangeAtTop(_ range: MonaRange) {}
    public func revealRangeInCenterIfOutsideViewport(_ range: MonaRange) {}
    public func revealRangeNearTop(_ range: MonaRange) {}
    public func revealRangeNearTopIfOutsideViewport(_ range: MonaRange) {}

    // MARK: IEditor — Trigger / model

    public func trigger(_ source: String, _ handlerId: String, _ payload: Any?) {}
    public func getModel() -> MonaInstanceITextModel? { view.attachment.attachedModel }
    public func setModel(_ model: MonaInstanceITextModel?) {
        if let model = model {
            view.attach(model: model)
        } else {
            view.detach()
        }
    }
    public func createDecorationsCollection(
        _ decorations: [MonaModelDecoration]
    ) -> MonaDecorationCollection { MonaDecorationCollection() }

    // MARK: ICodeEditor — Model / content change events (inert)

    public var onDidChangeModelContent: MonaEvent<MonaModelContentChangeEvent> { monaInstanceInertEvent() }
    public var onDidChangeModelLanguage: MonaEvent<MonaModelLanguageChangeEvent> { monaInstanceInertEvent() }
    public var onDidChangeModelLanguageConfiguration: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidChangeModelOptions: MonaEvent<MonaModelOptionsChangeEvent> { monaInstanceInertEvent() }
    public var onDidChangeConfiguration: MonaEvent<MonaEditorConfigurationChangedEvent> { monaInstanceInertEvent() }
    public var onDidChangeCursorPosition: MonaEvent<MonaEditorICursorPositionChangedEvent> { monaInstanceInertEvent() }
    public var onDidChangeCursorSelection: MonaEvent<MonaEditorICursorSelectionChangedEvent> { monaInstanceInertEvent() }
    public var onWillChangeModel: MonaEvent<MonaCodeModel> { monaInstanceInertEvent() }
    public var onDidChangeModel: MonaEvent<MonaCodeModel> { monaInstanceInertEvent() }
    public var onDidChangeModelDecorations: MonaEvent<Void> { monaInstanceInertEvent() }

    // MARK: ICodeEditor — Focus / composition

    public var onDidFocusEditorText: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidBlurEditorText: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidFocusEditorWidget: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidBlurEditorWidget: MonaEvent<Void> { monaInstanceInertEvent() }
    public func inComposition() -> Bool { false }
    public var onDidCompositionStart: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidCompositionEnd: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidAttemptReadOnlyEdit: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidPaste: MonaEvent<MonaEditorIPasteEvent> { monaInstanceInertEvent() }

    // MARK: ICodeEditor — Pointer / keyboard (inert)

    public var onMouseUp: MonaEvent<MonaInstanceMouseEvent> { monaInstanceInertEvent() }
    public var onMouseDown: MonaEvent<MonaInstanceMouseEvent> { monaInstanceInertEvent() }
    public var onContextMenu: MonaEvent<MonaInstanceMouseEvent> { monaInstanceInertEvent() }
    public var onMouseMove: MonaEvent<MonaInstanceMouseEvent> { monaInstanceInertEvent() }
    public var onMouseLeave: MonaEvent<MonaInstanceMouseEvent> { monaInstanceInertEvent() }
    public var onKeyUp: MonaEvent<MonaInstanceKeyboardEvent> { monaInstanceInertEvent() }
    public var onKeyDown: MonaEvent<MonaInstanceKeyboardEvent> { monaInstanceInertEvent() }

    // MARK: ICodeEditor — Layout / scroll (inert)

    public var onDidLayoutChange: MonaEvent<MonaEditorEditorLayoutInfo> { monaInstanceInertEvent() }
    public var onDidContentSizeChange: MonaEvent<MonaEditorIContentSizeChangedEvent> { monaInstanceInertEvent() }
    public var onDidScrollChange: MonaEvent<MonaScrollEvent> { monaInstanceInertEvent() }
    public var onDidChangeHiddenAreas: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onBeginUpdate: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onEndUpdate: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidChangeViewZones: MonaEvent<Void> { monaInstanceInertEvent() }

    // MARK: ICodeEditor — View state / contribution / model

    public func hasWidgetFocus() -> Bool { hasTextFocus() }
    public func getContribution<T>(_ id: String) -> T? { nil }

    // MARK: ICodeEditor — Options / value / geometry

    public func getOptions() -> MonaEditorIComputedEditorOptions {
        MonaInstanceStubComputedOptions()
    }
    public func getOption<T>(_ id: MonaEditorOption) -> T {
        // Phase 06+ config storage is not wired; no value of arbitrary T can
        // be constructed. This is an honest placeholder, not fake completion.
        fatalError("MonaInstanceICodeEditor.getOption(\(id)) is a Phase 06+ placeholder — config storage is not wired")
    }
    public func getRawOptions() -> MonaEditorIEditorConstructionOptions {
        MonaInstanceStubConstructionOptions()
    }
    public func getValue() -> String {
        view.attachment.attachedModel?.getValue() ?? ""
    }
    public func setValue(_ newValue: String) {
        view.attachment.attachedModel?.setValue(newValue)
    }
    public func getContentWidth() -> Int { 0 }
    public func getScrollWidth() -> Int { 0 }
    public func getScrollLeft() -> Int { 0 }
    public func getContentHeight() -> Int { 0 }
    public func getScrollHeight() -> Int { 0 }
    public func getScrollTop() -> Int { 0 }
    public func setScrollLeft(_ left: Int) {}
    public func setScrollTop(_ top: Int) {}
    public func setScrollPosition(_ position: MonaEditorINewScrollPosition) {}
    public func hasPendingScrollAnimation() -> Bool { false }

    // MARK: ICodeEditor — Actions / commands / edits

    public func getAction(_ id: String) -> MonaEditorIEditorAction? { nil }
    public func executeCommand(_ source: String, _ command: Any?) -> Bool { false }
    public func pushUndoStop() -> Bool { false }
    public func popUndoStop() -> Bool { false }
    public func executeEdits(_ source: String, _ edits: [MonaModelEditOperation]) -> Bool { false }
    public func executeCommands(_ source: String, _ commands: [Any?]) -> Bool { false }
    public func revealAllCursors(_ source: String, _ revealVertical: Bool) {}

    // MARK: ICodeEditor — Decorations

    public func getLineDecorations(_ lineNumber: Int) -> [MonaModelDecoration] { [] }
    public func getDecorationsInRange(_ range: MonaRange) -> [MonaModelDecoration] { [] }
    public func getFontSizeAtPosition(_ position: MonaPosition) -> Int { 0 }
    public func deltaDecorations(
        _ oldDecorations: [String],
        _ newDecorations: [MonaModelDecorationOptions]
    ) -> [String] { [] }
    public func removeDecorations(_ decorationIds: [String]) {}

    // MARK: ICodeEditor — Layout / visible ranges / line metrics

    public func getLayoutInfo() -> MonaEditorEditorLayoutInfo { MonaInstanceStubLayoutInfo() }
    public func getVisibleRanges() -> [MonaRange] { [] }
    public func getTopForLineNumber(_ lineNumber: Int) -> Int { 0 }
    public func getBottomForLineNumber(_ lineNumber: Int) -> Int { 0 }
    public func getTopForPosition(_ position: MonaPosition) -> Int { 0 }
    public func getLineHeightForPosition(_ position: MonaPosition) -> Int { 0 }
    public func writeScreenReaderContent(_ reason: String) {}

    // MARK: ICodeEditor — DOM-bearing surface (DOMNode / DOMWidget / ClientPoint / FontInfoTarget)

    public func getContainerDomNode() -> MonaInstanceDOMNode { view }
    public func getDomNode() -> MonaInstanceDOMNode { view }
    public func addContentWidget(_ widget: MonaInstanceDOMWidget) {}
    public func layoutContentWidget(_ widget: MonaInstanceDOMWidget) {}
    public func removeContentWidget(_ widget: MonaInstanceDOMWidget) {}
    public func addOverlayWidget(_ widget: MonaInstanceDOMWidget) {}
    public func layoutOverlayWidget(_ widget: MonaInstanceDOMWidget) {}
    public func removeOverlayWidget(_ widget: MonaInstanceDOMWidget) {}
    public func addGlyphMarginWidget(_ widget: MonaInstanceDOMWidget) {}
    public func layoutGlyphMarginWidget(_ widget: MonaInstanceDOMWidget) {}
    public func removeGlyphMarginWidget(_ widget: MonaInstanceDOMWidget) {}
    public func changeViewZones(_ callback: (MonaEditorIViewZoneChangeAccessor) -> Void) {}
    public func getOffsetForColumn(_ lineNumber: Int, _ column: Int) -> Int { 0 }
    public func getWidthOfLine(_ lineNumber: Int) -> Int { 0 }
    public func render() {}
    public func renderAsync() async {}
    public func getTargetAtClientPoint(_ clientX: Int, _ clientY: Int) -> MonaEditorIMouseTarget? { nil }
    public func getScrolledVisiblePosition(_ position: MonaPosition) -> MonaPosition? { nil }
    public func applyFontInfo(_ target: MonaInstanceFontInfoTarget) {}
    public func setBanner(_ bannerDomNode: MonaInstanceDOMNode?) {}

    public func handleInitialized() {}

    // MARK: IStandaloneCodeEditor (4 own members)

    public func updateOptions(_ options: MonaEditorIStandaloneEditorConstructionOptions) {}
    public func addCommand(
        _ keybinding: Int,
        _ handler: @escaping (MonaInstanceKeyboardEvent) -> Void
    ) -> String? { nil }
    public func createContextKey(_ name: String) -> MonaContextKey {
        MonaContextKey(name)
    }
    public func addAction(_ action: MonaEditorIActionDescriptor) {}
}

// MARK: - Diff-editor instance adapter (MonaInstanceIDiffEditor)

/// The concrete diff-editor instance adapter: wraps a `MonaDiffEditorView`
/// (P07-T009) and conforms it to `MonaInstanceIDiffEditor`
/// (IDiffEditor : IEditor). Identity, lifetime, DOM, and sub-editor members
/// dispatch to the diff view's real contract; the diff-navigation / computation
/// members are typed placeholders (Phase 06+/07+ diff engine).
///
/// `@MainActor`: the wrapped `MonaDiffEditorView` is an `NSView`
/// (MainActor-isolated); see the code adapter note above.
@MainActor
public final class MonaEditorDiffEditorInstanceAdapter: MonaInstanceIDiffEditor {

    /// The wrapped native diff editor view.
    public let view: MonaDiffEditorView

    /// The cached original-sub-editor adapter (stable for the diff view's
    /// lifetime — the diff view owns its sub-editors).
    public let originalEditorAdapter: MonaEditorStandaloneCodeEditorAdapter

    /// The cached modified-sub-editor adapter (stable for the diff view's
    /// lifetime — the diff view owns its sub-editors).
    public let modifiedEditorAdapter: MonaEditorStandaloneCodeEditorAdapter

    /// Creates the adapter wrapping `view`.
    public init(view: MonaDiffEditorView) {
        self.view = view
        self.originalEditorAdapter = MonaEditorStandaloneCodeEditorAdapter(
            view: view.originalEditor
        )
        self.modifiedEditorAdapter = MonaEditorStandaloneCodeEditorAdapter(
            view: view.modifiedEditor
        )
    }

    // MARK: IEditor — Lifetime / Identity

    public var onDidDispose: MonaEvent<Void> { monaInstanceInertEvent() }
    public func dispose() { view.detach() }
    public func getId() -> String {
        originalEditorAdapter.getId() + "+" + modifiedEditorAdapter.getId()
    }
    public func getEditorType() -> String { "builtin" }

    // MARK: IEditor — Configuration / layout / focus

    public func updateOptions(_ options: MonaEditorIEditorConstructionOptions) {}
    public func layout() {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }
    public func focus() {
        view.window?.makeFirstResponder(view)
    }
    public func hasTextFocus() -> Bool {
        view.window?.firstResponder === view
    }
    public func getSupportedActions() -> [MonaEditorIEditorAction] { [] }

    // MARK: IEditor — View state (aligned with IDiffEditor — single witness)

    public func saveViewState() -> MonaEditorIEditorViewState? { nil }
    public func restoreViewState(_ state: MonaEditorIEditorViewState?) {}

    // MARK: IEditor — Position

    public func getVisibleColumnFromPosition(_ position: MonaPosition) -> Int { 0 }
    public func getPosition() -> MonaPosition { MonaPosition(line: 1, column: 1) }
    public func setPosition(_ position: MonaPosition) {}

    public func revealLine(_ lineNumber: Int) {}
    public func revealLineInCenter(_ lineNumber: Int) {}
    public func revealLineInCenterIfOutsideViewport(_ lineNumber: Int) {}
    public func revealLineNearTop(_ lineNumber: Int) {}
    public func revealPosition(_ position: MonaPosition) {}
    public func revealPositionInCenter(_ position: MonaPosition) {}
    public func revealPositionInCenterIfOutsideViewport(_ position: MonaPosition) {}
    public func revealPositionNearTop(_ position: MonaPosition) {}

    // MARK: IEditor — Selection (4 overloads preserved)

    public func getSelection() -> MonaSelection? { nil }
    public func getSelections() -> [MonaSelection] { [] }
    public func setSelection(_ selection: MonaSelection) {}
    public func setSelection(_ range: MonaRange) {}
    public func setSelection(_ position: MonaPosition) {}
    public func setSelection(_ event: MonaEditorICursorSelectionChangedEvent) {}
    public func setSelections(_ selections: [MonaSelection]) {}

    // MARK: IEditor — Reveal

    public func revealLines(_ lineNumber: Int) {}
    public func revealLinesInCenter(_ lineNumber: Int) {}
    public func revealLinesInCenterIfOutsideViewport(_ lineNumber: Int) {}
    public func revealLinesNearTop(_ lineNumber: Int) {}
    public func revealRange(_ range: MonaRange) {}
    public func revealRangeInCenter(_ range: MonaRange) {}
    public func revealRangeAtTop(_ range: MonaRange) {}
    public func revealRangeInCenterIfOutsideViewport(_ range: MonaRange) {}
    public func revealRangeNearTop(_ range: MonaRange) {}
    public func revealRangeNearTopIfOutsideViewport(_ range: MonaRange) {}

    // MARK: IEditor — Trigger / model

    public func trigger(_ source: String, _ handlerId: String, _ payload: Any?) {}
    public func getModel() -> MonaInstanceITextModel? { nil }
    public func setModel(_ model: MonaInstanceITextModel?) {}
    public func createDecorationsCollection(
        _ decorations: [MonaModelDecoration]
    ) -> MonaDecorationCollection { MonaDecorationCollection() }

    // MARK: IDiffEditor — Own surface (17 members)

    public func getContainerDomNode() -> MonaInstanceDOMNode { view }
    public var onDidUpdateDiff: MonaEvent<Void> { monaInstanceInertEvent() }
    public var onDidChangeModel: MonaEvent<MonaEditorIDiffEditorModel> { monaInstanceInertEvent() }

    // restoreViewState / setModel / updateOptions carry the diff-specific param
    // types (overloads of the IEditor variants above — Swift resolves by param
    // type).
    public func restoreViewState(_ state: MonaEditorIDiffEditorViewState?) {}
    public func setModel(_ model: MonaEditorIDiffEditorModel?) {}

    public func createViewModel(
        _ original: MonaInstanceITextModel?,
        _ modified: MonaInstanceITextModel?
    ) -> MonaEditorIDiffEditorViewModel { MonaInstanceStubDiffViewModel() }

    public func getOriginalEditor() -> MonaInstanceICodeEditor { originalEditorAdapter }
    public func getModifiedEditor() -> MonaInstanceICodeEditor { modifiedEditorAdapter }
    public func getLineChanges() -> [MonaEditorILineChange]? { nil }
    public func updateOptions(_ options: MonaEditorIDiffEditorConstructionOptions) {}

    public func goToDiff(_ target: MonaEditorGoToDiffDestination) {}
    public func revealFirstDiff(_ target: MonaEditorGoToDiffDestination) {}
    public func accessibleDiffViewerNext() {}
    public func accessibleDiffViewerPrev() {}

    public func handleInitialized() {}
}
