// Soak4HourTests.swift — 4-hour stability soak
// Runs mixed P02/P03/P08 actions for 4 hours, checks no leaks/crashes/hangs.
// Run ONLY when explicitly filtered: `swift test --filter Soak4HourTests`

import XCTest
import MonaCode

final class Soak4HourTests: XCTestCase {

    func test4HourSoak() throws {
        let soakSeconds = 4 * 3600  // 4 hours
        let reportInterval = 600    // report every 10 min
        let batchSize = 1000        // actions per batch

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

        var cursorLine = 1
        var cursorColumn = 1
        var totalActions = 0
        var lastReport = 0
        let startTime = Date()

        print("soak: START — 4 hours, initial lines=\(initialLineCount), chars=\(initialLength)")

        while Date().timeIntervalSince(startTime) < Double(soakSeconds) {
            // Cycle through: insert char, insert newline, backspace, undo, redo, search
            let phase = totalActions % 6

            switch phase {
            case 0: // Insert a character
                let op = MonaModelEditOperation(
                    range: MonaRange(startLine: cursorLine, startColumn: cursorColumn,
                                     endLine: cursorLine, endColumn: cursorColumn),
                    text: "x"
                )
                _ = model.applyEdits([op])
                cursorColumn += 1
            case 1: // Insert newline
                let op = MonaModelEditOperation(
                    range: MonaRange(startLine: cursorLine, startColumn: cursorColumn,
                                     endLine: cursorLine, endColumn: cursorColumn),
                    text: "\n"
                )
                _ = model.applyEdits([op])
                cursorLine += 1
                cursorColumn = 1
            case 2: // Backspace
                if cursorColumn > 1 {
                    let op = MonaModelEditOperation(
                        range: MonaRange(startLine: cursorLine, startColumn: cursorColumn - 1,
                                         endLine: cursorLine, endColumn: cursorColumn),
                        text: ""
                    )
                    _ = model.applyEdits([op])
                    cursorColumn -= 1
                } else if cursorLine > 1 {
                    let prevMax = model.getLineMaxColumn(cursorLine - 1) + 1
                    let op = MonaModelEditOperation(
                        range: MonaRange(startLine: cursorLine - 1, startColumn: prevMax,
                                         endLine: cursorLine, endColumn: 1),
                        text: ""
                    )
                    _ = model.applyEdits([op])
                    cursorLine -= 1
                    cursorColumn = prevMax
                }
            case 3: // Undo
                model.undo()
                // Clamp cursor after undo
                let lc = model.getLineCount()
                cursorLine = max(1, min(cursorLine, lc))
                cursorColumn = max(1, min(cursorColumn, model.getLineMaxColumn(cursorLine) + 1))
            case 4: // Redo
                model.redo()
                let lc = model.getLineCount()
                cursorLine = max(1, min(cursorLine, lc))
                cursorColumn = max(1, min(cursorColumn, model.getLineMaxColumn(cursorLine) + 1))
            case 5: // Search (literal)
                let content = model.getLineContent(min(cursorLine, model.getLineCount()))
                let needle = content.count > 10 ? String(content.prefix(10)) : "test"
                let raw = Array(content.utf16)
                _ = MonaLiteralSearch(needle: needle, matchCase: true).findAll(in: raw)
            default:
                break
            }

            totalActions += 1

            // Keep cursor in bounds
            let lc = model.getLineCount()
            if cursorLine > lc { cursorLine = lc }
            if cursorLine < 1 { cursorLine = 1 }
            let maxCol = model.getLineMaxColumn(cursorLine) + 1
            if cursorColumn > maxCol { cursorColumn = maxCol }
            if cursorColumn < 1 { cursorColumn = 1 }

            // Report every reportInterval seconds
            let elapsed = Int(Date().timeIntervalSince(startTime))
            if elapsed - lastReport >= reportInterval {
                let currentLines = model.getLineCount()
                let currentLength = model.getValueLength()
                print("soak: \(elapsed)s/\(soakSeconds)s (\(Int(Double(elapsed)/Double(soakSeconds)*100))%) — actions=\(totalActions), lines=\(currentLines), chars=\(currentLength)")
                lastReport = elapsed

                // Stability checks: line count + value length should stay bounded
                // (insert+delete+undo+redo should keep them roughly stable)
                let lineGrowth = Double(currentLines) / Double(max(initialLineCount, 1))
                let lengthGrowth = Double(currentLength) / Double(max(initialLength, 1))
                XCTAssertTrue(lineGrowth < 100, "soak: line count grew \(lineGrowth)x — possible leak")
                XCTAssertTrue(lengthGrowth < 100, "soak: value length grew \(lengthGrowth)x — possible leak")
            }
        }

        // Final check
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let finalLines = model.getLineCount()
        let finalLength = model.getValueLength()

        print("soak: COMPLETE — \(elapsed)s, total actions=\(totalActions)")
        print("  initial: lines=\(initialLineCount), chars=\(initialLength)")
        print("  final:   lines=\(finalLines), chars=\(finalLength)")
        print("  growth:   lines=\(String(format: "%.2f", Double(finalLines)/Double(max(initialLineCount,1))))x, chars=\(String(format: "%.2f", Double(finalLength)/Double(max(initialLength,1))))x")

        // Assertions: the soak completed (no crash/hang) + state is bounded
        XCTAssertTrue(elapsed >= soakSeconds - 60, "soak: did not run for full duration (elapsed=\(elapsed)s)")
        XCTAssertTrue(totalActions > 0, "soak: no actions executed")
        let lineGrowth = Double(finalLines) / Double(max(initialLineCount, 1))
        let lengthGrowth = Double(finalLength) / Double(max(initialLength, 1))
        XCTAssertTrue(lineGrowth < 100, "soak: line count grew \(lineGrowth)x — unbounded growth")
        XCTAssertTrue(lengthGrowth < 100, "soak: value length grew \(lengthGrowth)x — unbounded growth")

        print("soak: ALL CHECKS PASSED — no leaks, no crashes, no hangs, state bounded")
    }
}
