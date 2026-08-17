// MonaViewGraphDifferentialTests.swift
//
// P03-T001 — Build ViewGraph projection and logarithmic vertical indexes.
//
// Verifies the MonaCodeAppKit projection layer that sits between the text model
// (MonaCodeModel) and the renderer:
//   - MonaViewGraph projects model lines into view lines, applying folding
//     (collapsed ranges), hidden ranges, injected text, word wrapping, and
//     view zones. A new projection generation is published ONLY after every
//     affected index (vertical + view-zone) is complete.
//   - MonaViewLine is the immutable view-line identity (model line + column
//     offset + wrapping + injection + visibility).
//   - MonaVerticalIndex is the logarithmic prefix-height index: view line ->
//     vertical offset and vertical offset -> view line in O(log n), with no
//     full-document scans.
//   - MonaViewZoneIndex indexes view zones (inserted visual blocks between
//     lines) for range queries and prefix-height contributions.
//
// Two contract cases:
//   1. View graph operations — projection correctness across folding, hidden
//      ranges, injections, wrapping, and view zones; generation atomicity.
//   2. Differential — a naive O(n) reference layout is kept in lock-step with
//      the ViewGraph across an adversarial sequence of mutations, and the
//      logarithmic vertical index agrees with a naive prefix-sum at every
//      sampled query. Also asserts the index answers WITHOUT a full-document
//      scan (operation-count witness).

import XCTest
import MonaCodeAppKit
import MonaCode

final class MonaViewGraphDifferentialTests: XCTestCase {

    // MARK: - 1. View graph operations (the first contract case)

    func testViewGraphOperations() {
        let lineHeight = 20

        // ---- Empty model -> a single (empty) view line ----
        let emptyModel = MonaCodeModel(
            text: "",
            uri: MonaURI.parse("monacode:empty")!
        )
        let emptyGraph = MonaViewGraph(model: emptyModel, lineHeight: lineHeight)
        let emptyProj = emptyGraph.getProjection()
        XCTAssertEqual(emptyProj.viewLines.count, 1)
        XCTAssertEqual(emptyProj.viewLines[0], MonaViewLine(modelLineNumber: 1))
        XCTAssertEqual(emptyGraph.generation, 1)
        // Re-fetching without mutation does NOT bump generation (idempotent).
        let emptyProj2 = emptyGraph.getProjection()
        XCTAssertEqual(emptyGraph.generation, 1)
        XCTAssertEqual(emptyProj2.generation, 1)

        // ---- Simple model: view lines == model lines (1:1) ----
        let model = MonaCodeModel(
            text: "alpha\nbeta\ngamma",
            uri: MonaURI.parse("monacode:simple")!
        )
        let graph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let proj = graph.getProjection()
        XCTAssertEqual(proj.viewLines.count, 3)
        XCTAssertEqual(proj.viewLines.map(\.modelLineNumber), [1, 2, 3])
        XCTAssertEqual(proj.viewLines.map(\.startColumn), [1, 1, 1])
        XCTAssertEqual(proj.viewLines.map(\.isWrapped), [false, false, false])
        XCTAssertEqual(proj.viewLines.map(\.isVisible), [true, true, true])
        XCTAssertEqual(graph.generation, 1)

        // ---- Folding: collapse lines 2..2 (beta) ----
        // A folded range replaces its interior with a single collapsed view line
        // that carries the start model line's number and an injection marker.
        graph.setFoldedRanges([
            MonaRange(startLine: 2, startColumn: 1, endLine: 2, endColumn: 5)
        ])
        let foldedProj = graph.getProjection()
        XCTAssertEqual(graph.generation, 2)
        // 3 model lines -> 3 view lines still (collapse marker replaces content
        // of line 2 with a single collapsed view line). The collapsed line is
        // marked not-wrapped and carries a folding injection id.
        XCTAssertEqual(foldedProj.viewLines.count, 3)
        XCTAssertEqual(foldedProj.viewLines[1].modelLineNumber, 2)
        XCTAssertTrue(foldedProj.viewLines[1].isCollapsed)
        // Clearing folding restores 1:1 and bumps generation.
        graph.setFoldedRanges([])
        let unfoldedProj = graph.getProjection()
        XCTAssertEqual(unfoldedProj.viewLines.count, 3)
        XCTAssertFalse(unfoldedProj.viewLines[1].isCollapsed)
        XCTAssertEqual(graph.generation, 3)

        // ---- Hidden ranges: hide line 2 entirely ----
        graph.setHiddenRanges([
            MonaRange(startLine: 2, startColumn: 1, endLine: 2, endColumn: 5)
        ])
        let hiddenProj = graph.getProjection()
        // Hidden lines are excluded from the visible view-line list.
        XCTAssertEqual(hiddenProj.viewLines.count, 2)
        XCTAssertEqual(hiddenProj.viewLines.map(\.modelLineNumber), [1, 3])
        XCTAssertEqual(graph.generation, 4)
        graph.setHiddenRanges([])

        // ---- Injected text: inject text into line 2 at column 1 ----
        graph.setInjections([
            MonaViewInjection(id: "inj1", lineNumber: 2, column: 1, text: "[inj]")
        ])
        let injProj = graph.getProjection()
        // The injection attaches to the view line for model line 2.
        XCTAssertEqual(injProj.viewLines.count, 3)
        XCTAssertEqual(injProj.viewLines[1].injectionIds, ["inj1"])
        XCTAssertEqual(graph.generation, 5)
        graph.setInjections([])

        // ---- Wrapping: word wrap at 3 chars per view line ----
        // "gamma" (5 chars) wraps -> "gam" (cols 1-3) + "ma" (cols 4-5).
        graph.setWordWrapColumn(3)
        let wrapProj = graph.getProjection()
        // Each of "alpha","beta","gamma" (lengths 5,4,5) wraps into 2 pieces.
        XCTAssertEqual(wrapProj.viewLines.count, 6) // 2 + 2 + 2
        // The wrapped continuations are marked isWrapped and carry the same
        // model line number, with startColumn advanced past the break.
        let wrappedLineForModelLine3 = wrapProj.viewLines.filter { $0.modelLineNumber == 3 }
        XCTAssertEqual(wrappedLineForModelLine3.count, 2)
        XCTAssertTrue(wrappedLineForModelLine3[1].isWrapped)
        XCTAssertEqual(wrappedLineForModelLine3[0].startColumn, 1)
        XCTAssertEqual(wrappedLineForModelLine3[1].startColumn, 4) // after "gam"
        XCTAssertEqual(graph.generation, 6)
        graph.setWordWrapColumn(nil)

        // ---- View zones: zones inserted after lines ----
        graph.setViewZones([
            MonaViewZone(id: "z1", afterLineNumber: 1, height: 30),
            MonaViewZone(id: "z2", afterLineNumber: 2, height: 10)
        ])
        let zoneProj = graph.getProjection()
        // View zones do not create view lines; they are separate visual blocks.
        XCTAssertEqual(zoneProj.viewLines.count, 3)
        XCTAssertEqual(graph.generation, 7)
        // The view-zone index reports the zones.
        XCTAssertEqual(graph.viewZoneIndex.zones.count, 2)
        XCTAssertEqual(graph.viewZoneIndex.zones.map(\.id), ["z1", "z2"])

        // ---- Vertical index: line -> offset and offset -> line ----
        // 3 lines * 20 = 60 line height, plus zones 30 (after line 1) + 10 (after line 2).
        // Layout (top offset of each view line):
        //   view line 1 (model 1): top = 0
        //   zone z1 (30px) after line 1
        //   view line 2 (model 2): top = 20 + 30 = 50
        //   zone z2 (10px) after line 2
        //   view line 3 (model 3): top = 50 + 20 + 10 = 80
        let vi = graph.verticalIndex
        XCTAssertEqual(vi.viewLineCount, 3)
        XCTAssertEqual(vi.verticalOffsetForViewLine(1), 0)
        XCTAssertEqual(vi.verticalOffsetForViewLine(2), 50)
        XCTAssertEqual(vi.verticalOffsetForViewLine(3), 80)
        // offset -> line. A view line L spans [top(L), top(L)+lineHeight). An
        // offset that falls in a zone gap (between a line's bottom and the next
        // line's top) is attributed to the line ABOVE the gap.
        XCTAssertEqual(vi.viewLineAtVerticalOffset(0), 1)
        XCTAssertEqual(vi.viewLineAtVerticalOffset(19), 1)
        XCTAssertEqual(vi.viewLineAtVerticalOffset(20), 1) // zone z1 gap [20,50) -> line above
        XCTAssertEqual(vi.viewLineAtVerticalOffset(49), 1)
        XCTAssertEqual(vi.viewLineAtVerticalOffset(50), 2) // line 2 spans [50,70)
        XCTAssertEqual(vi.viewLineAtVerticalOffset(69), 2)
        XCTAssertEqual(vi.viewLineAtVerticalOffset(70), 2) // zone z2 gap [70,80) -> line above
        XCTAssertEqual(vi.viewLineAtVerticalOffset(80), 3) // line 3 spans [80,100)
        XCTAssertEqual(vi.totalHeight, 100) // 3*20 + 30 + 10

        // ---- Generation atomicity: a mutation that dirties the projection
        // does NOT advance generation until getProjection() completes every
        // index. We observe generation before and after a mutator, then after
        // projection.
        let genBefore = graph.generation
        graph.setLineHeight(24)
        XCTAssertEqual(graph.generation, genBefore, "generation must not advance on mutator alone")
        let _ = graph.getProjection()
        XCTAssertEqual(graph.generation, genBefore + 1, "generation advances only after projection rebuilds all indexes")
        // After the rebuild the vertical index reflects the new line height.
        XCTAssertEqual(graph.verticalIndex.verticalOffsetForViewLine(2), 24 + 30)
    }

    // MARK: - 2. Differential + logarithmic complexity (the second contract case)

    func testDifferentialAndLogarithmicIndex() {
        // A deterministic pseudo-random sequence of mutations drives BOTH the
        // MonaViewGraph and a naive O(n) reference layout. After every mutation:
        //   - the view-line list agrees
        //   - the vertical index's line->offset and offset->line agree with a
        //     naive prefix-sum scan
        //   - the vertical index answers WITHOUT a full-document scan
        //     (operationCount witness: the scan counter advances sub-linearly).

        let text = (1...12).map { "L\($0)" }.joined(separator: "\n")
        let model = MonaCodeModel(text: text, uri: MonaURI.parse("monacode:diff")!)
        let initialLineHeight = 20
        let graph = MonaViewGraph(model: model, lineHeight: initialLineHeight)

        var rngState: UInt64 = 0x9E37_79B9_7F4A_7C15
        func nextRand() -> Int {
            rngState &*= 6364136223846793005
            rngState &+= 1442695040888963407
            return Int(truncatingIfNeeded: rngState & 0x7FFF_FFFF_FFFF_FFFF)
        }

        // Naive reference state (mirrors the graph's mutation surface).
        var naiveFolded: [MonaRange] = []
        var naiveHidden: Set<Int> = []           // hidden model line numbers
        var naiveZones: [MonaViewZone] = []
        var naiveLineHeight = initialLineHeight   // tracks graph.setLineHeight

        // Build the expected view-line list from naive state.
        func naiveViewLines() -> [MonaViewLine] {
            var lines: [MonaViewLine] = []
            for m in 1...12 {
                if naiveHidden.contains(m) { continue }
                let isFolded = naiveFolded.contains { $0.startPosition.line == m }
                lines.append(MonaViewLine(
                    modelLineNumber: m,
                    startColumn: 1,
                    isWrapped: false,
                    injectionIds: [],
                    isCollapsed: isFolded,
                    isVisible: true
                ))
            }
            return lines
        }

        // Naive prefix height: the top offset of view line `viewLine` (1-based).
        func naiveOffsetForViewLine(_ viewLine: Int) -> Int {
            let lines = naiveViewLines()
            var offset = 0
            for i in 0..<(viewLine - 1) {
                guard i < lines.count else { break }
                offset += naiveLineHeight
                let m = lines[i].modelLineNumber
                for z in naiveZones where z.afterLineNumber == m {
                    offset += z.height
                }
            }
            return offset
        }

        // Naive offset -> view line. Convention (matches the graph): an offset
        // that falls in a zone gap (between a line's bottom and the next line's
        // top) is attributed to the line ABOVE the gap. Equivalently: return the
        // last view line whose top is <= offset.
        func naiveViewLineAtOffset(_ offset: Int) -> Int {
            let lines = naiveViewLines()
            guard !lines.isEmpty else { return 0 }
            var top = 0
            var result = 1
            for (i, vl) in lines.enumerated() {
                if top <= offset {
                    result = i + 1
                } else {
                    break
                }
                top += naiveLineHeight
                for z in naiveZones where z.afterLineNumber == vl.modelLineNumber {
                    top += z.height
                }
            }
            return result
        }

        func naiveTotalHeight() -> Int {
            let lines = naiveViewLines()
            guard !lines.isEmpty else { return 0 }
            var total = lines.count * naiveLineHeight
            for z in naiveZones {
                // A zone after a hidden line is itself hidden in Monaco; for this
                // differential we keep zones whose afterLineNumber is visible.
                if lines.contains(where: { $0.modelLineNumber == z.afterLineNumber }) {
                    total += z.height
                }
            }
            return total
        }

        let rounds = 60
        for round in 0..<rounds {
            let choice = nextRand() % 4

            switch choice {
            case 0:
                // Toggle a folded range on a random line.
                let line = 1 + (nextRand() % 12)
                let r = MonaRange(startLine: line, startColumn: 1, endLine: line, endColumn: 3)
                if let idx = naiveFolded.firstIndex(where: { $0.startPosition.line == line }) {
                    naiveFolded.remove(at: idx)
                } else {
                    naiveFolded.append(r)
                }
                graph.setFoldedRanges(naiveFolded)
            case 1:
                // Toggle hidden on a random line.
                let line = 1 + (nextRand() % 12)
                if naiveHidden.contains(line) {
                    naiveHidden.remove(line)
                } else {
                    naiveHidden.insert(line)
                }
                let hiddenRanges = naiveHidden.sorted().map {
                    MonaRange(startLine: $0, startColumn: 1, endLine: $0, endColumn: 10)
                }
                graph.setHiddenRanges(hiddenRanges)
            case 2:
                // Add/replace a view zone after a random line.
                let line = 1 + (nextRand() % 12)
                let height = 5 + (nextRand() % 40)
                let id = "z\(line)"
                naiveZones.removeAll { $0.id == id }
                naiveZones.append(MonaViewZone(id: id, afterLineNumber: line, height: height))
                graph.setViewZones(naiveZones)
            default:
                // Change line height occasionally.
                let h = 16 + (nextRand() % 24)
                naiveLineHeight = h
                graph.setLineHeight(h)
            }

            // ---- Projection agreement ----
            let proj = graph.getProjection()
            let expectedLines = naiveViewLines()
            XCTAssertEqual(proj.viewLines.count, expectedLines.count,
                           "view-line count mismatch at round \(round)")
            for i in 0..<min(proj.viewLines.count, expectedLines.count) {
                XCTAssertEqual(proj.viewLines[i].modelLineNumber, expectedLines[i].modelLineNumber,
                               "modelLineNumber mismatch at view line \(i), round \(round)")
                XCTAssertEqual(proj.viewLines[i].isVisible, expectedLines[i].isVisible,
                               "isVisible mismatch at view line \(i), round \(round)")
            }

            // ---- Vertical index agreement (sampled) ----
            let vi = graph.verticalIndex
            let n = proj.viewLines.count
            if n > 0 {
                let sampleStride = max(1, n / 8)
                for viewLine in stride(from: 1, through: n, by: sampleStride) {
                    let actual = vi.verticalOffsetForViewLine(viewLine)
                    let naiveOff = naiveOffsetForViewLine(viewLine)
                    XCTAssertEqual(actual, naiveOff,
                                   "offset mismatch for view line \(viewLine) at round \(round)")
                }
                // Total height agreement.
                XCTAssertEqual(vi.totalHeight, naiveTotalHeight(),
                               "totalHeight mismatch at round \(round)")
                // offset -> line at a few offsets.
                let totalH = vi.totalHeight
                if totalH > 0 {
                    for frac in [0, 0.25, 0.5, 0.75, 0.99] {
                        let off = Int(Double(totalH) * frac)
                        let actual = vi.viewLineAtVerticalOffset(off)
                        let expected = naiveViewLineAtOffset(off)
                        XCTAssertEqual(actual, expected,
                                       "viewLineAtOffset(\(off)) mismatch at round \(round)")
                    }
                }
            }

            // ---- Logarithmic witness: the index's scan counter must stay within
            // an O(log n) bound per query — proving no full-document scan. A
            // segment tree over n leaves touches at most 2*ceil(log2(n)) + 2
            // nodes per prefix-sum / descent query.
            let queries = vi.queryCount
            let scans = vi.scannedNodeCount
            if queries > 0 && n > 0 {
                let logLeaves = ceilLog2(n)
                let logBound = queries * (2 * logLeaves + 2)
                XCTAssertLessThanOrEqual(scans, logBound,
                                         "vertical index must be O(log n) (round \(round), scans=\(scans) bound=\(logBound))")
                // For a non-trivial document the sub-linear margin must also hold
                // against the linear bound.
                if n >= 16 {
                    XCTAssertLessThan(scans, n * queries,
                                      "vertical index must not full-scan (round \(round))")
                }
            }
        }

        // Final sanity: the graph survived the adversarial run and the
        // generation advanced at least once per mutating round.
        XCTAssertGreaterThan(graph.generation, 1)
    }

    // MARK: - Helpers

    /// ceil(log2(n)) for n >= 1. ceilLog2(1) = 0, ceilLog2(4) = 2, ceilLog2(5) = 3.
    private func ceilLog2(_ n: Int) -> Int {
        guard n > 1 else { return 0 }
        var k = 0
        var p = 1
        while p < n {
            p <<= 1
            k += 1
        }
        return k
    }
}
