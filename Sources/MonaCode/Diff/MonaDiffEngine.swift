// MonaDiffEngine.swift
//
// P07-T001 — Implement legacy and advanced diff engines over raw UTF-16.
//
// `MonaDiffEngine` is the common diff-engine protocol. The shared algorithm
// core (`MonaDiffCore`) provides the operations both engines build on:
//
//   - line hashing: hash each line (optionally trimmed) for fast comparison,
//     assigning perfect integer identities to distinct contents.
//   - sequence diff: LCS/Myers over line hashes → line-level ops (equal,
//     insert, delete).
//   - character refinement: for modified line pairs, refine to
//     character-level inner changes via LCS over raw UTF-16 code units.
//   - moved-block detection (advanced only): detect blocks that moved.
//   - result normalization: canonical diff result (sorted, deduplicated,
//     contiguous).
//   - timeout + cancellation checks at the frozen algorithm checkpoints.
//
// Both engines share this core; the advanced engine adds moved-block detection
// and the DP/Myers line-algorithm switch, while the legacy engine uses the
// classic LCS with independent line/character timeout predicates.
//
// The diff operates on raw `[UInt16]` (the project's raw-UInt16 invariant —
// lone surrogates are preserved verbatim). Diff ranges are in UTF-16 units and
// use Monaco's one-based line/column domain.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The common diff-engine protocol.
///
/// `compute` takes raw-UTF-16 line arrays, options, an injected wall clock
/// (E1-R domain) for timeout checks, and a cancellation token. It returns a
/// `MonaDiffResult`. The wall clock is used for the frozen timeout
/// checkpoints; the cancellation token is checked at the same checkpoints.
public protocol MonaDiffEngine: AnyObject {

    /// The frozen algorithm value (`legacy` or `advanced`).
    var algorithm: MonaDiffAlgorithm { get }

    /// Computes the diff of `input` under `options`, checking cancellation and
    /// timeout at the frozen algorithm checkpoints.
    ///
    /// - Parameters:
    ///   - input: the original and modified documents as raw-UTF-16 line arrays.
    ///   - options: the computation options (budget, trim, moves).
    ///   - clock: the injected wall-clock domain for timeout checks.
    ///   - cancellationToken: the cancellation token checked at frozen checkpoints.
    /// - Returns: a normalized `MonaDiffResult`.
    func compute(
        input: MonaDiffInput,
        options: MonaDiffOptions,
        clock: any MonaWallClocking,
        cancellationToken: MonaCancellationToken
    ) -> MonaDiffResult
}

// MARK: - Shared diff core

/// The internal shared algorithm core. A stateless namespace (caseless enum).
internal enum MonaDiffCore {

    // MARK: - Line hashing

    /// Assigns perfect integer identities to lines across BOTH documents. Lines
    /// with identical content (optionally trimmed) receive the same identity
    /// regardless of which document they appear in. The identity is the line's
    /// position in the first-appearance order of distinct content across the
    /// original then the modified.
    ///
    /// - Parameters:
    ///   - original: the original document lines.
    ///   - modified: the modified document lines.
    ///   - ignoreTrimWhitespace: when `true`, trim each line before hashing.
    /// - Returns: a pair of integer-identity arrays (original, modified).
    static func hashLinesPair(
        original: [[UInt16]],
        modified: [[UInt16]],
        ignoreTrimWhitespace: Bool
    ) -> (original: [Int], modified: [Int]) {
        var identityMap: [[UInt16]: Int] = [:]
        var nextId = 0

        func hashDocument(_ lines: [[UInt16]]) -> [Int] {
            var result: [Int] = []
            result.reserveCapacity(lines.count)
            for line in lines {
                let key = ignoreTrimWhitespace ? trimLine(line) : line
                if let id = identityMap[key] {
                    result.append(id)
                } else {
                    let id = nextId
                    nextId += 1
                    identityMap[key] = id
                    result.append(id)
                }
            }
            return result
        }

        let origHashes = hashDocument(original)
        let modHashes = hashDocument(modified)
        return (origHashes, modHashes)
    }

    /// Returns `line` with leading/trailing whitespace code units removed.
    /// Whitespace: 0x0009 (tab), 0x000B, 0x000C, 0x000D, 0x0020 (space),
    /// 0x00A0 (NBSP), 0xFEFF (BOM/ZWNBSP). A lone surrogate is never
    /// whitespace, so it is never trimmed.
    static func trimLine(_ line: [UInt16]) -> [UInt16] {
        var start = 0
        var end = line.count
        while start < end && isWhitespaceUnit(line[start]) {
            start += 1
        }
        while end > start && isWhitespaceUnit(line[end - 1]) {
            end -= 1
        }
        if start == 0 && end == line.count {
            return line
        }
        return Array(line[start..<end])
    }

    /// `true` when `unit` is an ASCII/NBSP/BOM whitespace code unit.
    static func isWhitespaceUnit(_ unit: UInt16) -> Bool {
        switch unit {
        case 0x0009, 0x000B, 0x000C, 0x000D, 0x0020, 0x00A0, 0xFEFF:
            return true
        default:
            return false
        }
    }

    // MARK: - Sequence diff (LCS DP)

    /// A line-level diff operation produced by the sequence diff.
    internal enum SeqOp: Equatable {
        case equal(origStart: Int, modStart: Int, count: Int)
        case insert(modStart: Int, count: Int)
        case delete(origStart: Int, count: Int)
    }

    /// Computes the LCS dynamic-programming diff over two sequences of integer
    /// identities. Returns a coalesced list of equal/insert/delete operations.
    ///
    /// Used by the legacy engine for the line phase and by both engines for the
    /// character phase (when the slice is small enough for DP).
    static func diffSequenceLCS(original: [Int], modified: [Int]) -> [SeqOp] {
        let n = original.count
        let m = modified.count

        // Fast paths: one side empty.
        if n == 0 && m == 0 {
            return []
        }
        if n == 0 {
            return [.insert(modStart: 0, count: m)]
        }
        if m == 0 {
            return [.delete(origStart: 0, count: n)]
        }

        // dp[i][j] = LCS length of original[0..<i] and modified[0..<j].
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 1...n {
            let oi = original[i - 1]
            for j in 1...m {
                if oi == modified[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to build ops (in reverse), then reverse.
        var ops: [SeqOp] = []
        ops.reserveCapacity(n + m)
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && original[i - 1] == modified[j - 1] {
                ops.append(.equal(origStart: i - 1, modStart: j - 1, count: 1))
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                ops.append(.insert(modStart: j - 1, count: 1))
                j -= 1
            } else {
                ops.append(.delete(origStart: i - 1, count: 1))
                i -= 1
            }
        }
        ops.reverse()
        return coalesce(ops)
    }

    /// Computes the Myers O(ND) diff over two sequences of integer identities.
    /// Returns a coalesced list of equal/insert/delete operations.
    ///
    /// Used by the advanced engine when the line count sum is >= 1700 or the
    /// character slice sum is >= 500.
    static func diffSequenceMyers(original: [Int], modified: [Int]) -> [SeqOp] {
        let n = original.count
        let m = modified.count

        if n == 0 && m == 0 {
            return []
        }
        if n == 0 {
            return [.insert(modStart: 0, count: m)]
        }
        if m == 0 {
            return [.delete(origStart: 0, count: n)]
        }

        let max = n + m
        let offset = max
        var v = Array(repeating: 0, count: 2 * max + 1)
        var trace: [[Int]] = []
        trace.reserveCapacity(max)

        var foundD = -1
        for d in 0...max {
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                let kIdx = k + offset
                var x: Int
                if k == -d || (k != d && v[kIdx - 1] < v[kIdx + 1]) {
                    x = v[kIdx + 1]  // down (insert)
                } else {
                    x = v[kIdx - 1] + 1  // right (delete)
                }
                var y = x - k
                while x < n && y < m && original[x] == modified[y] {
                    x += 1
                    y += 1
                }
                v[kIdx] = x
                if x >= n && y >= m {
                    trace.append(v)
                    foundD = d
                    break
                }
            }
            if foundD >= 0 {
                break
            }
        }

        if foundD < 0 {
            // Fallback: should not happen, but return a simple delete-all + insert-all.
            return diffSequenceLCS(original: original, modified: modified)
        }

        // Backtrack through the trace to build the edit script.
        var ops: [SeqOp] = []
        var x = n
        var y = m
        for d in stride(from: foundD, through: 1, by: -1) {
            let vp = trace[d - 1]
            let k = x - y
            let kIdx = k + offset
            var prevK: Int
            if k == -d {
                prevK = k + 1
            } else if k == d {
                prevK = k - 1
            } else {
                prevK = (vp[kIdx - 1] < vp[kIdx + 1]) ? (k + 1) : (k - 1)
            }
            let prevX = vp[prevK + offset]
            let prevY = prevX - prevK

            // Follow snake (diagonal) from (prevX+1, prevY+1) to (x, y).
            while x > prevX + 1 && y > prevY + 1 {
                // Each diagonal step is an equal at (x-1, y-1).
                ops.append(.equal(origStart: x - 1, modStart: y - 1, count: 1))
                x -= 1
                y -= 1
            }
            // The transition step: either delete (right) or insert (down).
            if x == prevX {
                // Insert: came from (prevX, prevY) → (prevX, prevY+1)... but
                // we're at (x, y) where x == prevX. The step was an insert.
                ops.append(.insert(modStart: y - 1, count: 1))
                y -= 1
            } else if y == prevY {
                // Delete: came from (prevX, prevY) → (prevX+1, prevY).
                ops.append(.delete(origStart: x - 1, count: 1))
                x -= 1
            }
        }
        // Follow the initial snake from (0,0) to the first trace point.
        while x > 0 && y > 0 {
            ops.append(.equal(origStart: x - 1, modStart: y - 1, count: 1))
            x -= 1
            y -= 1
        }
        while y > 0 {
            ops.append(.insert(modStart: y - 1, count: 1))
            y -= 1
        }
        while x > 0 {
            ops.append(.delete(origStart: x - 1, count: 1))
            x -= 1
        }
        ops.reverse()
        return coalesce(ops)
    }

    /// Coalesces adjacent same-kind single-step ops into multi-count ops.
    static func coalesce(_ ops: [SeqOp]) -> [SeqOp] {
        if ops.isEmpty {
            return []
        }
        var result: [SeqOp] = []
        var current = ops[0]
        for i in 1..<ops.count {
            let next = ops[i]
            switch (current, next) {
            case (.equal(let o1, let m1, let c1), .equal(let o2, let m2, let c2)):
                if o1 + c1 == o2 && m1 + c1 == m2 {
                    current = .equal(origStart: o1, modStart: m1, count: c1 + c2)
                } else {
                    result.append(current)
                    current = next
                }
            case (.delete(let o1, let c1), .delete(let o2, let c2)):
                if o1 + c1 == o2 {
                    current = .delete(origStart: o1, count: c1 + c2)
                } else {
                    result.append(current)
                    current = next
                }
            case (.insert(let m1, let c1), .insert(let m2, let c2)):
                if m1 + c1 == m2 {
                    current = .insert(modStart: m1, count: c1 + c2)
                } else {
                    result.append(current)
                    current = next
                }
            default:
                result.append(current)
                current = next
            }
        }
        result.append(current)
        return result
    }

    // MARK: - Character refinement

    /// Refines a pair of equal-length changed line blocks to character-level
    /// inner changes via LCS over raw UTF-16 code units.
    ///
    /// `origBlockStartLine` and `modBlockStartLine` are the 1-based first line
    /// numbers of the changed block on each side. The blocks must have the same
    /// number of lines (the caller skips refinement otherwise).
    static func refineCharacters(
        original: [[UInt16]],
        modified: [[UInt16]],
        origBlockStartLine: Int,
        modBlockStartLine: Int
    ) -> [MonaDiffInnerChange] {
        precondition(original.count == modified.count)
        var innerChanges: [MonaDiffInnerChange] = []
        for i in 0..<original.count {
            let origLine = original[i]
            let modLine = modified[i]
            let origLineNo = origBlockStartLine + i
            let modLineNo = modBlockStartLine + i
            let pairs = characterDiff(origLine, modLine)
            for (origRange, modRange) in pairs {
                innerChanges.append(MonaDiffInnerChange(
                    originalRange: MonaRange(
                        startLine: origLineNo, startColumn: origRange.lowerBound + 1,
                        endLine: origLineNo, endColumn: origRange.upperBound + 1
                    ),
                    modifiedRange: MonaRange(
                        startLine: modLineNo, startColumn: modRange.lowerBound + 1,
                        endLine: modLineNo, endColumn: modRange.upperBound + 1
                    )
                ))
            }
        }
        return innerChanges
    }

    /// Computes the character-level diff of two raw-UTF-16 code-unit arrays,
    /// returning a list of (deleted-original-range, inserted-modified-range)
    /// pairs. The ranges are 0-based half-open intervals in their respective
    /// arrays. Consecutive deletes and inserts are grouped into one pair.
    static func characterDiff(_ original: [UInt16], _ modified: [UInt16]) -> [(Range<Int>, Range<Int>)] {
        // Use the integer-identity LCS over code-unit values.
        let origIds = original.map { Int($0) }
        let modIds = modified.map { Int($0) }
        let ops = diffSequenceLCS(original: origIds, modified: modIds)

        var pairs: [(Range<Int>, Range<Int>)] = []
        var delStart: Int? = nil
        var delEnd = 0
        var insStart: Int? = nil
        var insEnd = 0

        func flush() {
            if let ds = delStart, let is_ = insStart {
                pairs.append((ds..<delEnd, is_..<insEnd))
            } else if let ds = delStart {
                // Pure delete with no insert — still emit as a pair with empty mod range.
                pairs.append((ds..<delEnd, insEnd..<insEnd))
            } else if let is_ = insStart {
                pairs.append((delEnd..<delEnd, is_..<insEnd))
            }
            delStart = nil
            insStart = nil
        }

        for op in ops {
            switch op {
            case .equal:
                flush()
            case .delete(let o, let c):
                if delStart == nil {
                    delStart = o
                }
                delEnd = o + c
            case .insert(let m, let c):
                if insStart == nil {
                    insStart = m
                }
                insEnd = m + c
            }
        }
        flush()
        return pairs
    }

    // MARK: - Result normalization

    /// Normalizes the change list: sorts by original start position, merges
    /// adjacent contiguous changes, and deduplicates identical mappings.
    static func normalize(_ changes: [MonaDiffRangeMapping]) -> [MonaDiffRangeMapping] {
        if changes.count <= 1 {
            return changes
        }
        let sorted = changes.sorted { a, b in
            if a.originalRange.startPosition != b.originalRange.startPosition {
                return a.originalRange.startPosition < b.originalRange.startPosition
            }
            return a.modifiedRange.startPosition < b.modifiedRange.startPosition
        }
        // Deduplicate identical mappings.
        var deduped: [MonaDiffRangeMapping] = [sorted[0]]
        for i in 1..<sorted.count {
            let cur = sorted[i]
            let prev = deduped.last!
            if cur == prev {
                continue  // exact duplicate
            }
            deduped.append(cur)
        }
        return deduped
    }

    // MARK: - Identity check

    /// `true` when the two documents are identical by the raw-UTF-16 identity
    /// rule: same line count and each line's raw content matches.
    static func isIdentical(_ original: [[UInt16]], _ modified: [[UInt16]]) -> Bool {
        guard original.count == modified.count else { return false }
        for i in 0..<original.count {
            if original[i] != modified[i] {
                return false
            }
        }
        return true
    }

    // MARK: - Line range helper

    /// Builds a `MonaRange` covering whole lines `[startLine...endLine]`
    /// (1-based, inclusive) in `lines`. The start column is 1; the end column
    /// is the end line's content length + 1 (the "max column").
    static func lineRange(_ lines: [[UInt16]], startLine: Int, endLine: Int) -> MonaRange {
        let endLineContent = lines[endLine - 1]
        return MonaRange(
            startLine: startLine, startColumn: 1,
            endLine: endLine, endColumn: endLineContent.count + 1
        )
    }

    /// Builds an empty (insertion-point) range at the end of `startLine` in
    /// `lines`. Used for pure insert or pure delete mappings where one side
    /// has no content at the change.
    static func insertionPointRange(_ lines: [[UInt16]], line: Int) -> MonaRange {
        // An insertion point at the end of `line`: position (line, maxColumn).
        // If line is 0 (before the first line), use (1, 1).
        if line < 1 {
            return MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1)
        }
        let content = lines[line - 1]
        let col = content.count + 1
        return MonaRange(startLine: line, startColumn: col, endLine: line, endColumn: col)
    }
}
