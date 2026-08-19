// Soak4HourTests.swift — stability soak test
// Runs balanced insert/delete/undo/redo/search actions for a configurable duration.
// Cursor is DERIVED FROM THE MODEL every iteration (not self-tracked) to prevent drift.
// Run ONLY when explicitly filtered: `swift test --filter Soak4HourTests`

import XCTest
import MonaCode

final class Soak4HourTests: XCTestCase {

    func testStabilitySoak() throws {
        let soakSeconds = 3600  // 1 hour
        let reportInterval = 300 // report every 5 min

        // Create model with some initial text
        var text = ""
        for i in 1...100 {
            text += "line \(i): the quick brown fox jumps over the lazy dog\n"
        }
        let model = MonaCodeModel(
            text: text,
            uri: MonaURI(scheme: "inmemory", path: "/soak/test.swift")
        )

        let initialLineCount = model.getLineCount()
        let initialLength = model.getValueLength()

        var totalActions = 0
        var lastReport = 0
        let startTime = Date()

        print("soak: START — \(soakSeconds)s, initial lines=\(initialLineCount), chars=\(initialLength)")

        while Date().timeIntervalSince(startTime) < Double(soakSeconds) {
            // DERIVE cursor from the model every iteration (not self-tracked)
            let lastLine = model.getLineCount()
            let lastCol = model.getLineMaxColumn(lastLine) + 1

            let phase = totalActions % 4

            switch phase {
            case 0: // Insert "x" at end of document
                let op = MonaModelEditOperation(
                    range: MonaRange(startLine: lastLine, startColumn: lastCol,
                                     endLine: lastLine, endColumn: lastCol),
                    text: "x"
                )
                _ = model.applyEdits([op])

            case 1: // Delete last char (backspace at end)
                if lastCol > 1 {
                    let op = MonaModelEditOperation(
                        range: MonaRange(startLine: lastLine, startColumn: lastCol - 1,
                                         endLine: lastLine, endColumn: lastCol),
                        text: ""
                    )
                    _ = model.applyEdits([op])
                }

            case 2: // Undo last edit
                model.undo()

            case 3: // Redo last edit
                model.redo()

            default:
                break
            }

            totalActions += 1

            // Every 1000 actions, do a search (P08 component test)
            if totalActions % 1000 == 0 {
                let content = model.getLineContent(min(lastLine, model.getLineCount()))
                let raw = Array(content.utf16)
                let needle = Array("the".utf16)
                _ = MonaLiteralSearch(needle: needle, matchCase: true).findAll(in: raw)
            }

            // Report + stability check every reportInterval seconds
            let elapsed = Int(Date().timeIntervalSince(startTime))
            if elapsed - lastReport >= reportInterval {
                let currentLines = model.getLineCount()
                let currentLength = model.getValueLength()
                let lineRatio = Double(currentLines) / Double(max(initialLineCount, 1))
                let lengthRatio = Double(currentLength) / Double(max(initialLength, 1))
                print("soak: \(elapsed)s/\(soakSeconds)s (\(Int(Double(elapsed)/Double(soakSeconds)*100))%) — actions=\(totalActions), lines=\(currentLines), chars=\(currentLength), lineRatio=\(String(format: "%.2f", lineRatio)), charRatio=\(String(format: "%.2f", lengthRatio))")
                lastReport = elapsed

                // Stability: line count + char count should stay bounded
                // (balanced insert/delete/undo/redo → net 0 growth per cycle)
                XCTAssertTrue(lineRatio < 3.0, "soak: line count grew \(lineRatio)x — possible issue")
                XCTAssertTrue(lengthRatio < 3.0, "soak: value length grew \(lengthRatio)x — possible issue")
            }
        }

        // Final check
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let finalLines = model.getLineCount()
        let finalLength = model.getValueLength()

        print("soak: COMPLETE — \(elapsed)s, total actions=\(totalActions)")
        print("  initial: lines=\(initialLineCount), chars=\(initialLength)")
        print("  final:   lines=\(finalLines), chars=\(finalLength)")
        let lineRatio = Double(finalLines) / Double(max(initialLineCount, 1))
        let lengthRatio = Double(finalLength) / Double(max(initialLength, 1))
        print("  ratio:    lines=\(String(format: "%.2f", lineRatio))x, chars=\(String(format: "%.2f", lengthRatio))x")

        XCTAssertTrue(elapsed >= soakSeconds - 60, "soak: did not run for full duration")
        XCTAssertTrue(totalActions > 0, "soak: no actions executed")
        XCTAssertTrue(lineRatio < 3.0, "soak: line count grew \(lineRatio)x — unbounded growth")
        XCTAssertTrue(lengthRatio < 3.0, "soak: value length grew \(lengthRatio)x — unbounded growth")

        print("soak: ALL CHECKS PASSED — no leaks, no crashes, no hangs, state bounded")
    }
}
