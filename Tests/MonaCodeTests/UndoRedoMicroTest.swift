import XCTest
import MonaCode

final class UndoRedoMicroTest: XCTestCase {
    func testSingleCycle() {
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/test"))
        let initial = model.getValueLength()
        let lastLine = model.getLineCount()

        // Insert "x" at end (getLineMaxColumn returns position after last char)
        let insertCol = model.getLineMaxColumn(lastLine)
        _ = model.applyEdits([MonaModelEditOperation(
            range: MonaRange(startLine: lastLine, startColumn: insertCol, endLine: lastLine, endColumn: insertCol),
            text: "x")])
        print("after insert: \(model.getValueLength()) (expected \(initial + 1))")

        // Delete "x" from end (range: maxCol-1 → maxCol)
        let deleteCol = model.getLineMaxColumn(lastLine)
        _ = model.applyEdits([MonaModelEditOperation(
            range: MonaRange(startLine: lastLine, startColumn: deleteCol - 1, endLine: lastLine, endColumn: deleteCol),
            text: "")])
        print("after delete: \(model.getValueLength()) (expected \(initial))")

        model.undo()
        print("after undo: \(model.getValueLength()) (expected \(initial + 1))")

        model.redo()
        print("after redo: \(model.getValueLength()) (expected \(initial))")

        print("net change: \(model.getValueLength() - initial) (expected 0)")
        XCTAssertEqual(model.getValueLength(), initial, "single cycle should be net-zero")
    }

    func test1000Cycles() {
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/test"))
        let initial = model.getValueLength()

        for _ in 0..<1000 {
            let lastLine = model.getLineCount()

            let insertCol = model.getLineMaxColumn(lastLine)
            _ = model.applyEdits([MonaModelEditOperation(
                range: MonaRange(startLine: lastLine, startColumn: insertCol, endLine: lastLine, endColumn: insertCol),
                text: "x")])

            let deleteCol = model.getLineMaxColumn(lastLine)
            _ = model.applyEdits([MonaModelEditOperation(
                range: MonaRange(startLine: lastLine, startColumn: deleteCol - 1, endLine: lastLine, endColumn: deleteCol),
                text: "")])

            model.undo()
            model.redo()
        }

        let final = model.getValueLength()
        print("1000 cycles: initial=\(initial), final=\(final), delta=\(final - initial)")
        XCTAssertEqual(final, initial, "1000 cycles should be net-zero, got delta=\(final - initial)")
    }
}
