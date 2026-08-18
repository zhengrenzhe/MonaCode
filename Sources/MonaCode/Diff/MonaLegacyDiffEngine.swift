// MonaLegacyDiffEngine.swift
//
// P07-T001 — Implement legacy and advanced diff engines over raw UTF-16.
//
// `MonaLegacyDiffEngine` is the Swift port of Monaco's
// `LegacyLinesDiffComputer` (monaco-editor 0.56.0,
// `esm/vs/editor/common/diff/legacyLinesDiffComputer.js`). It is the classic
// LCS-based line + character diff engine — NOT a rename of the advanced
// engine.
//
// Frozen profile (D1-R, raw UTF-16):
//
//   - Line phase: LCS dynamic programming over line hashes (trimmed content
//     identities). The line timeout predicate captures wall-clock at
//     construction and uses the full `maxComputationTime` (0 = infinite).
//   - Character phase: LCS over raw UTF-16 code units for modified line pairs.
//     A SEPARATE timeout predicate captures wall-clock at construction and uses
//     0 for infinite or `min(maxComputationTime, 5000)` otherwise.
//   - Both predicates continue only while `now - start < limit` (strict).
//   - Empty fast paths: identical single empty lines return no changes;
//     when either side is the single empty line, return the whole-document
//     mapping without running the general algorithms.
//   - No moved-block detection (the `moves` array is always empty).
//
// Frozen checkpoints (cancellation + timeout checked here, not inside atomic
// expensive steps):
//   1. After line hashing, before the line LCS.
//   2. After the line LCS, before character refinement.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The legacy LCS-based diff engine.
///
/// Implements the classic line + character diff using LCS dynamic programming.
/// Uses two independent timeout predicates (line phase = full budget;
/// character phase = `min(budget, 5000)` or 0 for infinite). Does not detect
/// moved blocks.
public final class MonaLegacyDiffEngine: MonaDiffEngine {

    public var algorithm: MonaDiffAlgorithm { .legacy }

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
            // Original empty → entire modified is an insertion.
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

        // --- Line hashing (shared identity map across both documents) ---
        let hashes = MonaDiffCore.hashLinesPair(
            original: original, modified: modified, ignoreTrimWhitespace: options.ignoreTrimWhitespace
        )
        let origHashes = hashes.original
        let modHashes = hashes.modified

        // --- Frozen checkpoint 1: after line hashing, before line LCS ---
        if cancellationToken.isCancellationRequested {
            return MonaDiffResult(identical: false, quitEarly: true, hitTimeout: false)
        }
        let lineStartTime = clock.wallMilliseconds()
        if options.maxComputationTimeMs > 0
            && !(clock.wallMilliseconds() - lineStartTime < Double(options.maxComputationTimeMs)) {
            return MonaDiffResult(identical: false, quitEarly: true, hitTimeout: true)
        }

        // --- Line phase: LCS over line hashes ---
        let ops = MonaDiffCore.diffSequenceLCS(original: origHashes, modified: modHashes)

        // Build change blocks (maximal runs of non-equal ops).
        let changeBlocks = buildChangeBlocks(ops: ops)

        // --- Frozen checkpoint 2: after line LCS, before character refinement ---
        if cancellationToken.isCancellationRequested {
            // Return partial result (line-level changes, no inner changes).
            let changes = buildRangeMappings(from: changeBlocks, original: original, modified: modified)
            return MonaDiffResult(changes: changes, identical: false, quitEarly: true, hitTimeout: false)
        }
        let charStartTime = clock.wallMilliseconds()
        let charLimit: Int
        if options.maxComputationTimeMs == 0 {
            charLimit = 0  // infinite
        } else {
            charLimit = min(options.maxComputationTimeMs, 5000)
        }
        if charLimit > 0
            && !(clock.wallMilliseconds() - charStartTime < Double(charLimit)) {
            let changes = buildRangeMappings(from: changeBlocks, original: original, modified: modified)
            return MonaDiffResult(changes: changes, identical: false, quitEarly: true, hitTimeout: true)
        }

        // --- Character phase: refine each changed block ---
        var rangeMappings: [MonaDiffRangeMapping] = []
        for block in changeBlocks {
            let origRange = MonaDiffCore.lineRange(
                original, startLine: block.origStartLine, endLine: block.origEndLine
            )
            let modRange = MonaDiffCore.lineRange(
                modified, startLine: block.modStartLine, endLine: block.modEndLine
            )
            let innerChanges: [MonaDiffInnerChange]
            if block.origLineCount == block.modLineCount && block.origLineCount > 0 {
                let origBlock = Array(original[(block.origStartLine - 1)..<(block.origEndLine)])
                let modBlock = Array(modified[(block.modStartLine - 1)..<(block.modEndLine)])
                innerChanges = MonaDiffCore.refineCharacters(
                    original: origBlock, modified: modBlock,
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

        let normalized = MonaDiffCore.normalize(rangeMappings)
        return MonaDiffResult(changes: normalized, moves: [], identical: false, quitEarly: false, hitTimeout: false)
    }

    // MARK: - Internal

    /// A maximal run of non-equal ops (a change block).
    internal struct ChangeBlock {
        let origStartLine: Int  // 1-based
        let origEndLine: Int    // 1-based, inclusive
        let modStartLine: Int   // 1-based
        let modEndLine: Int     // 1-based, inclusive
        var origLineCount: Int { origEndLine - origStartLine + 1 }
        var modLineCount: Int { modEndLine - modStartLine + 1 }
    }

    /// Builds change blocks from the sequence diff ops.
    internal func buildChangeBlocks(ops: [MonaDiffCore.SeqOp]) -> [ChangeBlock] {
        var blocks: [ChangeBlock] = []
        var origPos = 0  // 0-based line position in original
        var modPos = 0   // 0-based line position in modified

        var blockOrigStart = -1
        var blockOrigEnd = -1
        var blockModStart = -1
        var blockModEnd = -1
        var inBlock = false

        func flush() {
            if inBlock {
                blocks.append(ChangeBlock(
                    origStartLine: blockOrigStart + 1,  // 1-based
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

    /// Builds range mappings from change blocks (without inner changes).
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
                // Pure insertion: original insertion point.
                origRange = MonaDiffCore.insertionPointRange(
                    original, line: block.origStartLine - 1
                )
            }
            if block.modLineCount > 0 {
                modRange = MonaDiffCore.lineRange(
                    modified, startLine: block.modStartLine, endLine: block.modEndLine
                )
            } else {
                modRange = MonaDiffCore.insertionPointRange(
                    modified, line: block.modStartLine - 1
                )
            }
            return MonaDiffRangeMapping(originalRange: origRange, modifiedRange: modRange)
        }
    }
}
