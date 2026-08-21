// sample-macOS-host entry point
//
// Task 12 (GUI host) — reworked from a non-GUI smoke test into a windowed
// macOS app that constructs a `MonaCodeEditorView` via `MonaEditorFactory`
// and displays it in an `NSWindow`.
//
// The sample host is a NON-PRODUCT executable target (`sample-macOS-host`).
// It activates all three products — MonaCode (model + URI), MonaCodeAppKit
// (native editor + diff views + factory), and MonaCodeSwiftUI (lifecycle
// wrappers incl. diff + multi-diff). Because the sample is a non-product
// target, this adds NO production dependencies (products=3 /
// nonProductTargets=3 preserved).

import AppKit
import MonaCode
import MonaCodeAppKit
import MonaCodeSwiftUI

// MARK: - Sample multi-diff data source (MonaMultiDiffDataSource conformer)

// A minimal `MonaMultiDiffDataSource` (P07-T005 host group) conformer for the
// sample host: an ordered snapshot + a synchronous change emitter. The sample
// activates the multi-diff data-source contract without wiring real workspace
// diff events — the emitter exists only to satisfy the protocol's
// `onDidChangeSnapshot` requirement.
final class SampleMultiDiffDataSource: MonaMultiDiffDataSource {
    private let emitter = MonaEmitter<MonaMultiDiffSnapshotChange>()
    let snapshot: [MonaMultiDiffItem]
    var onDidChangeSnapshot: MonaEvent<MonaMultiDiffSnapshotChange> { emitter.event }
    init(items: [MonaMultiDiffItem]) { self.snapshot = items }
}

// MARK: - Construct the model + editor

// MonaCode: the Core text model + URI.
let model = MonaCodeModel(
    text: "Hello, MonaCode!\nLine 2\nLine 3\n",
    uri: MonaURI(scheme: "inmemory", path: "/demo")
)

// MonaCodeAppKit: create the native editor view through the factory. The
// factory borrows `model` (weak ref) — the editor never owns the model's
// lifetime. `create(model:)` attaches the model and registers the editor.
let factory = MonaEditorFactory()
let editor = factory.create(model: model)

// MARK: - Construct the diff + multi-diff views (AppKit)

// MonaCodeAppKit: the diff + multi-diff views through the factory. The
// factory borrows the models weakly via the sub-editors (lifetime independent).
// `createDiffEditor` attaches the original + modified models to the view's two
// sub-editors; `createMultiFileDiffEditor` constructs the view (its data
// source attaches separately via `MonaMultiDiffEditorView.attach(dataSource:)`).
let originalModel = MonaCodeModel(
    text: "Hello, MonaCode!\nLine 2\nLine 3\n",
    uri: MonaURI(scheme: "inmemory", path: "/original")
)
let modifiedModel = MonaCodeModel(
    text: "Hello, MonaCode!\nLine two\nLine 3\nAdded line\n",
    uri: MonaURI(scheme: "inmemory", path: "/modified")
)
let diffView = factory.createDiffEditor(
    original: originalModel, modified: modifiedModel, options: nil
)
let multiDiffView = factory.createMultiFileDiffEditor(options: nil)

// MARK: - Construct the SwiftUI diff + multi-diff wrappers

// MonaCodeSwiftUI: keep the diff + multi-diff lifecycle wrappers live
// alongside the native views (the sample activates all three products; the
// wrappers are not shown in the window but prove the SwiftUI product links).
let multiDiffDataSource = SampleMultiDiffDataSource(items: [
    MonaMultiDiffItem(
        id: "demo",
        originalModelURI: originalModel.uri,
        modifiedModelURI: modifiedModel.uri,
        label: "demo.diff",
        description: "sample diff item"
    )
])
let swiftUIDiff = MonaDiffEditor(
    controller: MonaDiffEditorController(
        original: originalModel, modified: modifiedModel))
let swiftUIMultiDiff = MonaMultiDiffEditor(
    controller: MonaMultiDiffEditorController(dataSource: multiDiffDataSource))
_ = diffView
_ = multiDiffView
_ = swiftUIDiff
_ = swiftUIMultiDiff

// MARK: - Host the editor in a window

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.contentView = editor
window.title = "MonaCode Editor"
window.center()
window.makeKeyAndOrderFront(nil)

// MonaCodeSwiftUI: keep a lifecycle wrapper live alongside the native view
// (the sample activates all three products; the wrapper is not shown in the
// window but proves the SwiftUI product links).
let swiftUICode = MonaCodeEditor(controller: MonaSwiftUIEditorController(model: model))
_ = swiftUICode

// MARK: - Run the app

print("sample-macOS-host: GUI host ready")
print("  MonaCode:        MonaCodeModel=\(model.getValueLength()) chars, MonaURI")
print("  MonaCodeAppKit:  MonaCodeEditorView + MonaDiffEditorView + MonaMultiDiffEditorView")
print("  MonaCodeSwiftUI: MonaCodeEditor + MonaDiffEditor + MonaMultiDiffEditor")
print("  window:          \(window.frame.size) — contentView=MonaCodeEditorView")

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.run()
