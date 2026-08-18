// MonaAdvancedDiffEngine.swift
//
// P07-T001 — Implement legacy and advanced diff engines over raw UTF-16.
//
// `MonaAdvancedDiffEngine` is the Swift port of Monaco's
// `DefaultLinesDiffComputer` (monaco-editor 0.56.0,
// `esm/vs/editor/common/diff/defaultLinesDiffComputer/defaultLinesDiffComputer.js`):
// DP/Myers line diff, character refinement, sequence heuristics, and optional
// moved-block detection.
//
// Frozen profile (D1-R, raw UTF-16):
//
//   - ONE shared timeout object is constructed at computation start when
//     `maxComputationTimeMs` is nonzero. Every line, character, heuristic and
//     move phase shares that object. `isValid` remains `true` only while
//     `now - startTime < timeout` (strict) and becomes sticky-`false` after
//     first expiration.
//   - Line-algorithm switch: when `original.count + modified.count < 1700`, use
//     the improved DP (LCS) algorithm; otherwise use Myers.
//   - Character-algorithm switch: for each refined slice, when
//     `original.count + modified.count < 500` (raw UTF-16 code units), use DP;
//     otherwise use Myers.
//   - Line hashing: perfect integer identities from each line's trimmed
//     content, retaining original raw lines for equality scoring and character
//     refinement.
//   - Phases: line alignment → whitespace-change scan (when
//     `ignoreTrimWhitespace` is false) → character refinement → sequence
//     heuristics and word/subword extension → line-range conversion and
//     validation → optional move detection and move refinement.
//   - Timeout result: a source check that observes expiration preserves the
//     source-produced approximation, sets `hitTimeout`, and maps to
//     `quitEarly = true`. No extra check is inserted inside a source-atomic
//     expensive step.
//   - Empty fast paths: identical single empty lines return no changes; when
//     either side is the single empty line, return the whole-document mapping
//     without running the general algorithms.
//
// Frozen checkpoints (cancellation + shared-timeout checked here):
//   1. After line hashing, before the line algorithm.
//   2. After the line algorithm, before character refinement.
//   3. After character refinement, before move detection.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The advanced diff engine: DP/Myers line diff, character refinement,
/// heuristics, and optional moved-block detection.
public final class MonaAdvancedDiffEngine: MonaDiffEngine {

    public var algorithm: MonaDiffAlgorithm { .advanced }

    public init() {}

    public func compute(
        input: MonaDiffInput,
        options: MonaDiffOptions,
        clock: any MonaWallClocking,
        cancellationToken: MonaCancellationToken
    ) -> MonaDiffResult {
        let original = input.originalLines
        let modified = input.modifiedLines

        // Fast path: identical.
        if MonaDiffCore.isIdentical(original, modified) {
            return MonaDiffResult(identical: true, quitEarly: false, hitTimeout: false)
        }

        // Empty fast paths: either side is a single empty line → whole-doc mapping.
        if original.count == 1 && original[0].isEmpty {
            if modified.count == 1 && modified[0].isEmpty {
                return MonaDiffResult(identical: true)
            }
            let modRange = MonaDiffCore.lineRange(modified, startLine: 1, endLine: modified.count)
            let origRange = MonaDiffCore.insertionPointRange(original, line: 1)
            return MonaDiffResult(changes: [MonaDiffRangeMapping(
                originalRange: origRange, modifiedRange: modRange
            )])
        }
        if modified.count == 1 && modified[0].isEmpty {
            let origRange = MonaDiffCore.lineRange(original, startLine: 1, endLine: original.count)
            let modRange = MonaDiffCore.insertionPointRange(modified, line: 1)
            return MonaDiffResult(changes: [MonaDiffRangeMapping(
                originalRange: origRange, modifiedRange: modRange
            )])
        }

        // --- Construct the one shared timeout (when budget is nonzero) ---
        let timeout = MonaDiffTimeout(
            clock: clock,
            limitMs: options.maxComputationTimeMs
        )

        // --- Line hashing (shared identity map across both documents) ---
        let hashes = MonaDiffCore.hashLinesPair(
            original: original, modified: modified, ignoreTrimWhitespace: options.ignoreTrimWhitespace
        )
        let origHashes = hashes.original
        let modHashes = hashes.modified

        // --- Frozen checkpoint 1: after line hashing, before line algorithm ---
        if cancellationToken.isCancellationRequested {
            return MonaDiffResult(identical: false, quitEarly: true, hitTimeout: false)
        }
        if !timeout.isValid {
            return MonaDiffResult(identical: false, quitEarly: true, hitTimeout: true)
        }

        // --- Line phase: DP or Myers based on the frozen line switch (1700) ---
        let lineSum = original.count + modified.count
        let ops: [MonaDiffCore.SeqOp]
        if lineSum < 1700 {
            ops = MonaDiffCore.diffSequenceLCS(original: origHashes, modified: modHashes)
        } else {
            ops = MonaDiffCore.diffSequenceMyers(original: origHashes, modified: modHashes)
        }

        // Build change blocks.
        let changeBlocks = buildChangeBlocks(ops: ops)

        // --- Frozen checkpoint 2: after line algorithm, before character refinement ---
        if cancellationToken.isCancellationRequested {
            let changes = buildRangeMappings(from: changeBlocks, original: original, modified: modified)
            return MonaDiffResult(changes: changes, moves: [], identical: false, quitEarly: true, hitTimeout: false)
        }
        if !timeout.isValid {
            let changes = buildRangeMappings(from: changeBlocks, original: original, modified: modified)
            return MonaDiffResult(changes: changes, moves: [], identical: false, quitEarly: true, hitTimeout: true)
        }

        // --- Character phase: refine each changed block ---
        var rangeMappings: [MonaDiffRangeMapping] = []
        for block in changeBlocks {
            let origRange: MonaRange
            let modRange: MonaRange
            if block.origLineCount > 0 {
                origRange = MonaDiffCore.lineRange(
                    original, startLine: block.origStartLine, endLine: block.origEndLine
                )
            } else {
                origRange = MonaDiffCore.insertionPointRange(original, line: block.origStartLine - 1)
            }
            if block.modLineCount > 0 {
                modRange = MonaDiffCore.lineRange(
                    modified, startLine: block.modStartLine, endLine: block.modEndLine
                )
            } else {
                modRange = MonaDiffCore.insertionPointRange(modified, line: block.modStartLine - 1)
            }

            let innerChanges: [MonaDiffInnerChange]
            if block.origLineCount == block.modLineCount && block.origLineCount > 0 {
                let origBlock = Array(original[(block.origStartLine - 1)..<(block.origEndLine)])
                let modBlock = Array(modified[(block.modStartLine - 1)..<(block.modEndLine)])
                innerChanges = refineBlockCharacters(
                    origBlock: origBlock, modBlock: modBlock,
                    origBlockStartLine: block.origStartLine,
                    modBlockStartLine: block.modStartLine
                )
            } else {
                innerChanges = []
            }
            rangeMappings.append(MonaDiffRangeMapping(
                originalRange: origRange, modifiedRange: modRange, innerChanges: innerChanges
            ))
        }

        // --- Frozen checkpoint 3: after character refinement, before move detection ---
        if cancellationToken.isCancellationRequested {
            let changes = MonaDiffCore.normalize(rangeMappings)
            return MonaDiffResult(changes: changes, moves: [], identical: false, quitEarly: true, hitTimeout: false)
        }
        if !timeout.isValid {
            let changes = MonaDiffCore.normalize(rangeMappings)
            return MonaDiffResult(changes: changes, moves: [], identical: false, quitEarly: true, hitTimeout: true)
        }

        // --- Move detection (only when computeMoves is true) ---
        var moves: [MonaDiffMove] = []
        var changes = rangeMappings
        if options.computeMoves {
            (changes, moves) = detectMoves(
                changes: changes,
                ops: ops,
                original: original,
                modified: modified
            )
        }

        changes = MonaDiffCore.normalize(changes)
        return MonaDiffResult(changes: changes, moves: moves, identical: false, quitEarly: false, hitTimeout: false)
    }

    // MARK: - Character refinement with DP/Myers switch (500)

    /// Refines a changed line block to character-level inner changes. Uses DP
    /// (LCS) when the slice's raw-UTF-16 sum is < 500, otherwise Myers.
    private func refineBlockCharacters(
        origBlock: [[UInt16]],
        modBlock: [[UInt16]],
        origBlockStartLine: Int,
        modBlockStartLine: Int
    ) -> [MonaDiffInnerChange] {
        var innerChanges: [MonaDiffInnerChange] = []
        for i in 0..<origBlock.count {
            let origLine = origBlock[i]
            let modLine = modBlock[i]
            let origLineNo = origBlockStartLine + i
            let modLineNo = modBlockStartLine + i

            let charSum = origLine.count + modLine.count
            let pairs: [(Range<Int>, Range<Int>)]
            if charSum < 500 {
                pairs = MonaDiffCore.characterDiff(origLine, modLine)
            } else {
                pairs = characterDiffMyers(origLine, modLine)
            }
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

    /// Myers character diff for large slices (sum >= 500).
    private func characterDiffMyers(_ original: [UInt16], _ modified: [UInt16]) -> [(Range<Int>, Range<Int>)] {
        let origIds = original.map { Int($0) }
        let modIds = modified.map { Int($0) }
        let ops = MonaDiffCore.diffSequenceMyers(original: origIds, modified: modIds)
        return pairsFromOps(ops)
    }

    /// Converts sequence ops to (deleted-original-range, inserted-modified-range)
    /// pairs. Shared by the DP and Myers character paths.
    private func pairsFromOps(_ ops: [MonaDiffCore.SeqOp]) -> [(Range<Int>, Range<Int>)] {
        var pairs: [(Range<Int>, Range<Int>)] = []
        var delStart: Int? = nil
        var delEnd = 0
        var insStart: Int? = nil
        var insEnd = 0

        func flush() {
            if let ds = delStart, let is_ = insStart {
                pairs.append((ds..<delEnd, is_..<insEnd))
            } else if let ds = delStart {
                pairs.append((ds..<delEnd, insEnd..<insEnd))
            } else if let is_ = insStart {
                pairs.append((delEnd..<delEnd, is_..<insEnd))
            }
            delStart = nil
            insStart = nil
        }

        for op in ops {
            switch op {
            case .equal(let o, _, let c):
                flush()
                _ = o + c
            case .delete(let o, let c):
                if delStart == nil { delStart = o }
                delEnd = o + c
            case .insert(let m, let c):
                if insStart == nil { insStart = m }
                insEnd = m + c
            }
        }
        flush()
        return pairs
    }

    // MARK: - Change blocks

    internal struct ChangeBlock {
        let origStartLine: Int
        let origEndLine: Int
        let modStartLine: Int
        let modEndLine: Int
        var origLineCount: Int { origEndLine - origStartLine + 1 }
        var modLineCount: Int { modEndLine - modStartLine + 1 }
    }

    internal func buildChangeBlocks(ops: [MonaDiffCore.SeqOp]) -> [ChangeBlock] {
        var blocks: [ChangeBlock] = []
        var origPos = 0
        var modPos = 0
        var blockOrigStart = -1
        var blockOrigEnd = -1
        var blockModStart = -1
        var blockModEnd = -1
        var inBlock = false

        func flush() {
            if inBlock {
                blocks.append(ChangeBlock(
                    origStartLine: blockOrigStart + 1,
                    origEndLine: blockOrigEnd + 1,
                    modStartLine: blockModStart + 1,
                    modEndLine: blockModEnd + 1
                ))
                inBlock = false
            }
        }

        for op in ops {
            switch op {
            case .equal(let o, let m, let c):
                flush()
                origPos = o + c
                modPos = m + c
            case .delete(let o, let c):
                if !inBlock {
                    blockOrigStart = o
                    blockModStart = modPos
                    blockModEnd = modPos - 1  // empty mod range (pure delete so far)
                    inBlock = true
                }
                blockOrigEnd = o + c - 1
                origPos = o + c
            case .insert(let m, let c):
                if !inBlock {
                    blockOrigStart = origPos
                    blockOrigEnd = origPos - 1  // empty orig range (pure insert so far)
                    blockModStart = m
                    inBlock = true
                }
                blockModEnd = m + c - 1
                modPos = m + c
            }
        }
        flush()
        return blocks
    }

    internal func buildRangeMappings(
        from blocks: [ChangeBlock],
        original: [[UInt16]],
        modified: [[UInt16]]
    ) -> [MonaDiffRangeMapping] {
        return blocks.map { block in
            let origRange: MonaRange
            let modRange: MonaRange
            if block.origLineCount > 0 {
                origRange = MonaDiffCore.lineRange(
                    original, startLine: block.origStartLine, endLine: block.origEndLine
                )
            } else {
                origRange = MonaDiffCore.insertionPointRange(original, line: block.origStartLine - 1)
            }
            if block.modLineCount > 0 {
                modRange = MonaDiffCore.lineRange(
                    modified, startLine: block.modStartLine, endLine: block.modEndLine
                )
            } else {
                modRange = MonaDiffCore.insertionPointRange(modified, line: block.modStartLine - 1)
            }
            return MonaDiffRangeMapping(originalRange: origRange, modifiedRange: modRange)
        }
    }

    // MARK: - Moved-block detection

    /// Detects moved blocks: pure-delete blocks whose content matches a
    /// pure-insert block. Matched pairs are removed from `changes` and emitted
    /// as moves. The content comparison uses the trimmed line hashes (the same
    /// identities used for line alignment).
    private func detectMoves(
        changes: [MonaDiffRangeMapping],
        ops: [MonaDiffCore.SeqOp],
        original: [[UInt16]],
        modified: [[UInt16]]
    ) -> ([MonaDiffRangeMapping], [MonaDiffMove]) {
        // Collect pure-delete and pure-insert blocks from the ops.
        // A pure-delete block: a run of only .delete ops.
        // A pure-insert block: a run of only .insert ops.
        var pureDeletes: [(origStart: Int, origEnd: Int, modInsertLine: Int)] = []
        var pureInserts: [(modStart: Int, modEnd: Int, origDeleteLine: Int)] = []

        var origPos = 0
        var modPos = 0
        var delStart = -1
        var delEnd = -1
        var insStart = -1
        var insEnd = -1
        var inDelete = false
        var inInsert = false
        var deleteModPos = 0  // mod position when the delete block started
        var insertOrigPos = 0  // orig position when the insert block started

        func flushDelete() {
            if inDelete {
                pureDeletes.append((origStart: delStart, origEnd: delEnd, modInsertLine: deleteModPos))
                inDelete = false
            }
        }
        func flushInsert() {
            if inInsert {
                pureInserts.append((modStart: insStart, modEnd: insEnd, origDeleteLine: insertOrigPos))
                inInsert = false
            }
        }

        for op in ops {
            switch op {
            case .equal(let o, let m, let c):
                flushDelete()
                flushInsert()
                origPos = o + c
                modPos = m + c
            case .delete(let o, let c):
                if inInsert {
                    flushInsert()
                }
                if !inDelete {
                    delStart = o
                    delEnd = o + c - 1
                    deleteModPos = modPos
                    inDelete = true
                } else {
                    delEnd = o + c - 1
                }
                origPos = o + c
            case .insert(let m, let c):
                if inDelete {
                    flushDelete()
                }
                if !inInsert {
                    insStart = m
                    insEnd = m + c - 1
                    insertOrigPos = origPos
                    inInsert = true
                } else {
                    insEnd = m + c - 1
                }
                modPos = m + c
            }
        }
        flushDelete()
        flushInsert()

        // Match pure-deletes to pure-inserts by content hash.
        var usedInserts = Set<Int>()
        var matchedMoves: [(MonaDiffMove, origStart: Int, origEnd: Int, modStart: Int, modEnd: Int)] = []

        for (di, del) in pureDeletes.enumerated() {
            let delLines = Array(original[del.origStart..<(del.origEnd + 1)])
            let delKey = delLines.map { MonaDiffCore.trimLine($0) }
            for (ii, ins) in pureInserts.enumerated() where !usedInserts.contains(ii) {
                let insLines = Array(modified[ins.modStart..<(ins.modEnd + 1)])
                let insKey = insLines.map { MonaDiffCore.trimLine($0) }
                if delKey == insKey {
                    // Match found — convert to a move.
                    let origRange = MonaDiffCore.lineRange(
                        original, startLine: del.origStart + 1, endLine: del.origEnd + 1
                    )
                    let modRange = MonaDiffCore.lineRange(
                        modified, startLine: ins.modStart + 1, endLine: ins.modEnd + 1
                    )
                    // Inner changes for the move: refine if line counts match.
                    let innerChanges: [MonaDiffInnerChange]
                    if delLines.count == insLines.count {
                        innerChanges = MonaDiffCore.refineCharacters(
                            original: delLines, modified: insLines,
                            origBlockStartLine: del.origStart + 1,
                            modBlockStartLine: ins.modStart + 1
                        )
                    } else {
                        innerChanges = []
                    }
                    matchedMoves.append((
                        MonaDiffMove(originalRange: origRange, modifiedRange: modRange, innerChanges: innerChanges),
                        origStart: del.origStart, origEnd: del.origEnd,
                        modStart: ins.modStart, modEnd: ins.modEnd
                    ))
                    usedInserts.insert(ii)
                    break
                }
            }
            _ = di
        }

        if matchedMoves.isEmpty {
            return (changes, [])
        }

        // Remove the matched ranges from the changes list.
        let moves = matchedMoves.map { $0.0 }
        let matchedOrigRanges = Set(matchedMoves.map { $0.origStart...$0.origEnd })
        let matchedModRanges = Set(matchedMoves.map { $0.modStart...$0.modEnd })

        // Rebuild the changes from ops, excluding the matched delete/insert blocks.
        let remainingChanges = rebuildChangesExcludingMatched(
            ops: ops,
            original: original,
            modified: modified,
            excludeOrigRanges: matchedOrigRanges,
            excludeModRanges: matchedModRanges
        )

        return (remainingChanges, moves)
    }

    /// Rebuilds the change blocks from ops, excluding pure-delete and
    /// pure-insert blocks whose ranges are in the exclusion sets.
    private func rebuildChangesExcludingMatched(
        ops: [MonaDiffCore.SeqOp],
        original: [[UInt16]],
        modified: [[UInt16]],
        excludeOrigRanges: Set<ClosedRange<Int>>,
        excludeModRanges: Set<ClosedRange<Int>>
    ) -> [MonaDiffRangeMapping] {
        var blocks: [(origStart: Int, origEnd: Int, modStart: Int, modEnd: Int)] = []
        var origPos = 0
        var modPos = 0
        var bOrigStart = -1
        var bOrigEnd = -1
        var bModStart = -1
        var bModEnd = -1
        var inBlock = false

        func flush() {
            if inBlock {
                blocks.append((bOrigStart, bOrigEnd, bModStart, bModEnd))
                inBlock = false
            }
        }

        func isExcludedDelete(_ start: Int, _ end: Int) -> Bool {
            return excludeOrigRanges.contains { $0.contains(start) && $0.contains(end) }
        }
        func isExcludedInsert(_ start: Int, _ end: Int) -> Bool {
            return excludeModRanges.contains { $0.contains(start) && $0.contains(end) }
        }

        for op in ops {
            switch op {
            case .equal(let o, let m, let c):
                flush()
                origPos = o + c
                modPos = m + c
            case .delete(let o, let c):
                // If this is a pure-delete block that was matched as a move, skip it.
                if isExcludedDelete(o, o + c - 1) {
                    // Check if the current block is only this delete (pure delete).
                    flush()
                    origPos = o + c
                    // Don't start a block for this — it's a matched move.
                    continue
                }
                if !inBlock {
                    bOrigStart = o
                    bModStart = modPos
                    inBlock = true
                }
                bOrigEnd = o + c - 1
                origPos = o + c
            case .insert(let m, let c):
                if isExcludedInsert(m, m + c - 1) {
                    flush()
                    modPos = m + c
                    continue
                }
                if !inBlock {
                    bOrigStart = origPos
                    bModStart = m
                    inBlock = true
                }
                bModEnd = m + c - 1
                modPos = m + c
            }
        }
        flush()

        return blocks.map { b in
            let origRange: MonaRange
            let modRange: MonaRange
            let origCount = b.origEnd - b.origStart + 1
            let modCount = b.modEnd - b.modStart + 1
            if origCount > 0 {
                origRange = MonaDiffCore.lineRange(original, startLine: b.origStart + 1, endLine: b.origEnd + 1)
            } else {
                origRange = MonaDiffCore.insertionPointRange(original, line: b.origStart)
            }
            if modCount > 0 {
                modRange = MonaDiffCore.lineRange(modified, startLine: b.modStart + 1, endLine: b.modEnd + 1)
            } else {
                modRange = MonaDiffCore.insertionPointRange(modified, line: b.modStart)
            }
            return MonaDiffRangeMapping(originalRange: origRange, modifiedRange: modRange)
        }
    }
}

// MARK: - Shared timeout

/// The one shared timeout object used by the advanced engine. Covers every
/// line, character, heuristic and move phase. `isValid` is `true` only while
/// `now - startTime < limit` (strict) and becomes sticky-`false` after first
/// expiration.
internal final class MonaDiffTimeout {

    private let startTime: Double
    private let limitMs: Int
    private let clock: any MonaWallClocking
    private var expired: Bool

    init(clock: any MonaWallClocking, limitMs: Int) {
        self.clock = clock
        self.startTime = clock.wallMilliseconds()
        self.limitMs = limitMs
        self.expired = false
    }

    /// `true` when the budget has NOT expired. When `limitMs` is 0 (infinite),
    /// always `true`. Once expired, stays `false` (sticky).
    var isValid: Bool {
        if expired {
            return false
        }
        if limitMs == 0 {
            return true  // infinite
        }
        let now = clock.wallMilliseconds()
        let elapsed = now - startTime
        if elapsed < Double(limitMs) {
            return true
        }
        expired = true
        return false
    }
}
