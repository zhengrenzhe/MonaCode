// sample-macOS-host entry point
//
// P07-T009 — Activate all three products in the sample host without adding
// production dependencies.
//
// The sample host is a NON-PRODUCT executable target (`sample-macOS-host`).
// Activating the three products here constructs representatives from each —
// MonaCode (model + URI), MonaCodeAppKit (native editor + diff views), and
// MonaCodeSwiftUI (lifecycle wrappers). Because the sample is a non-product
// target, this adds NO production dependencies (products=3 /
// nonProductTargets=3 preserved — same rationale as P04-T015's
// `conformance-and-failure-injection` target).

import AppKit
import MonaCode
import MonaCodeAppKit
import MonaCodeSwiftUI

// MARK: - A sample multi-diff data source (host-contract conformer)
//
// The sample host supplies a concrete `MonaMultiDiffDataSource` (P07-T005
// host group `multi-diff-data`): an ordered snapshot with stable item ids and
// a synchronous change emitter.

final class SampleMultiDiffDataSource: MonaMultiDiffDataSource {

    private let emitter = MonaEmitter<MonaMultiDiffSnapshotChange>()

    var snapshot: [MonaMultiDiffItem] = [
        MonaMultiDiffItem(
            id: "sample-diff-a",
            originalModelURI: MonaURI(scheme: "inmemory", path: "/sample/original-a"),
            modifiedModelURI: MonaURI(scheme: "inmemory", path: "/sample/modified-a"),
            label: "A.swift",
            description: "Sample diff item A"
        ),
        MonaMultiDiffItem(
            id: "sample-diff-b",
            originalModelURI: MonaURI(scheme: "inmemory", path: "/sample/original-b"),
            modifiedModelURI: MonaURI(scheme: "inmemory", path: "/sample/modified-b"),
            label: "B.swift",
            description: "Sample diff item B"
        ),
    ]

    var onDidChangeSnapshot: MonaEvent<MonaMultiDiffSnapshotChange> { emitter.event }
}

// MARK: - Activate the three products

// MonaCode: the Core text model + URI.
let original = MonaCodeModel(
    text: "line1\nline2\nline3",
    uri: MonaURI(scheme: "inmemory", path: "/sample/original")
)
let modified = MonaCodeModel(
    text: "line1\nchanged\nline3",
    uri: MonaURI(scheme: "inmemory", path: "/sample/modified")
)

// MonaCodeAppKit: the native editor + the diff + multi-diff views.
let editor = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
editor.attach(model: original)

let diffView = MonaDiffEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))
diffView.attach(original: original, modified: modified)

let multiDiffView = MonaMultiDiffEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))
multiDiffView.attach(dataSource: SampleMultiDiffDataSource())

// MonaCodeSwiftUI: the lifecycle wrappers (controllers hold stable identity).
let swiftUICode = MonaCodeEditor(controller: MonaSwiftUIEditorController(model: original))
let swiftUIDiff = MonaDiffEditor(
    controller: MonaDiffEditorController(original: original, modified: modified)
)
let swiftUIMultiDiff = MonaMultiDiffEditor(
    controller: MonaMultiDiffEditorController(dataSource: SampleMultiDiffDataSource())
)

// Tear down the native views (idempotent; models are never disposed here).
editor.detach()
diffView.detach()
multiDiffView.detach()

print("sample-macOS-host: activated MonaCode + MonaCodeAppKit + MonaCodeSwiftUI")
print("  MonaCode:        MonaCodeModel=\(original.getValueLength()) chars, MonaURI")
print("  MonaCodeAppKit:  MonaCodeEditorView + MonaDiffEditorView + MonaMultiDiffEditorView")
print("  MonaCodeSwiftUI: MonaCodeEditor + MonaDiffEditor + MonaMultiDiffEditor")
_ = (swiftUICode, swiftUIDiff, swiftUIMultiDiff)  // keep the wrappers live
