// sample-macOS-host entry point
//
// Task 12 (GUI host) — reworked from a non-GUI smoke test into a windowed
// macOS app that constructs a `MonaCodeEditorView` via `MonaEditorFactory`
// and displays it in an `NSWindow`.
//
// The sample host is a NON-PRODUCT executable target (`sample-macOS-host`).
// It activates all three products — MonaCode (model + URI), MonaCodeAppKit
// (native editor view + factory), and MonaCodeSwiftUI (lifecycle wrappers).
// Because the sample is a non-product target, this adds NO production
// dependencies (products=3 / nonProductTargets=3 preserved).

import AppKit
import MonaCode
import MonaCodeAppKit
import MonaCodeSwiftUI

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
print("  MonaCodeAppKit:  MonaCodeEditorView via MonaEditorFactory.create(model:)")
print("  MonaCodeSwiftUI: MonaCodeEditor + MonaSwiftUIEditorController")
print("  window:          \(window.frame.size) — contentView=MonaCodeEditorView")

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.run()
