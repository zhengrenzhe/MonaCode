// MonaPieceTree.swift
//
// P01-T007 — Port the Piece Tree over raw UInt16 storage.
//
// `MonaPieceTree` is the MonaCode port of Monaco's `PieceTreeTextBuffer` /
// `pieceTreeBase.ts` (monaco-editor 0.56.0). It is a self-balancing BST (an AVL
// tree — the Swift idiom for Monaco's red-black `rbTree`) over text pieces.
// Each piece references a contiguous slice of one of the tree's raw `[UInt16]`
// buffers; the in-order traversal of the tree yields the document text.
//
// Invariants (from the G6-R contract):
//   - Raw UInt16 storage: text is held as `[UInt16]` (UTF-16 code units).
//     Isolated (unpaired) surrogates are NEVER repaired — they are preserved
//     verbatim, never substituted with U+FFFD. This matches Monaco's UTF-16
//     code-unit semantics, which a Swift `String` would repair.
//   - Node balancing: the BST splits pieces (left/right part) when an edit
//     lands mid-piece and removes whole pieces when an edit fully covers them;
//     AVL rotations rebalance after every structural change, keeping
//     insert/delete/search O(log n).
//   - Line-start metadata: each piece carries its line-feed offsets; the tree
//     exposes O(log n) line→offset and offset→position queries via the
//     accumulated `subtreeLineFeeds` metadata.
//   - Snapshots: `createSnapshot()` materializes an immutable copy.
//   - Operation counts: edit/search/offset/position counters are instrumented
//     for later complexity gates.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Operation counters instrumenting a `MonaPieceTree`.
///
/// Each counter advances as the corresponding operation family is performed.
/// The counts are used by later complexity gates to verify the O(log n)
/// asymptotic upper bound under adversarial edit sequences.
public struct MonaPieceTreeOperationCounts: Equatable {

    /// Insert and delete operations.
    public var edit: Int = 0

    /// Text-collection traversals (`getText`, `getLineContent`).
    public var search: Int = 0

    /// Position → offset conversions (`getOffsetAt`).
    public var offset: Int = 0

    /// Offset → position conversions (`getPositionAt`).
    public var position: Int = 0

    /// Creates zeroed counters.
    public init() {}
}

/// The Piece Tree text buffer: a balanced BST over raw `[UInt16]` text pieces.
///
/// Supports `insert`, `delete`, `getLineContent`, `getText`, `getOffsetAt`,
/// `getPositionAt`, and `createSnapshot`. All operations are O(log n) except
/// `getText` / `createSnapshot`, which materialize the full text in O(n).
public final class MonaPieceTree {

    // MARK: - Buffers (raw UInt16, never mutated after a piece references them)

    /// `buffers[0]` is the initial text; `buffers[1]` is the change buffer that
    /// every `insert` appends to. Pieces reference slices of these buffers.
    private var buffers: [[UInt16]]

    /// The root of the balanced BST, or `nil` for an empty tree.
    private var root: MonaPieceTreeNode?

    /// Instrumented operation counts.
    private var counts: MonaPieceTreeOperationCounts

    // MARK: - Initialization

    /// Creates an empty Piece Tree.
    public init() {
        self.buffers = [[], []]
        self.root = nil
        self.counts = MonaPieceTreeOperationCounts()
    }

    /// Creates a Piece Tree initialized with raw UTF-16 `units`.
    public init(units: [UInt16]) {
        self.buffers = [units, []]
        self.counts = MonaPieceTreeOperationCounts()
        if !units.isEmpty {
            let piece = MonaPiece(
                bufferIndex: 0,
                start: 0,
                length: units.count,
                lineStarts: MonaLineStarts(units)
            )
            self.root = MonaPieceTreeNode(piece: piece)
        } else {
            self.root = nil
        }
    }

    /// Convenience: creates a Piece Tree from a `String` (converted to UTF-16).
    public convenience init(text: String) {
        self.init(units: Array(text.utf16))
    }

    // MARK: - Public read-only state

    /// The total number of UTF-16 code units in the document.
    public var length: Int {
        return root?.subtreeLength ?? 0
    }

    /// The number of lines. An empty document has 1 line.
    public var lineCount: Int {
        return (root?.subtreeLineFeeds ?? 0) + 1
    }

    /// The current operation counts.
    public var operationCounts: MonaPieceTreeOperationCounts {
        return counts
    }

    // MARK: - Insert

    /// Inserts `units` (raw UTF-16) at `offset` (0-based UTF-16).
    ///
    /// `offset` is clamped to `[0, length]`. The inserted units are appended to
    /// the change buffer and a new piece referencing them is inserted into the
    /// BST at the correct in-order position, splitting any piece that the
    /// offset lands inside. AVL rotations rebalance the tree. O(log n).
    public func insert(_ units: [UInt16], at offset: Int) {
        counts.edit += 1
        guard !units.isEmpty else { return }

        let totalLength = length
        let clampedOffset = min(max(offset, 0), totalLength)

        // Append the text to the change buffer and reference it.
        let changeBuffer = buffers[1]
        let start = changeBuffer.count
        buffers[1] = changeBuffer + units
        let newPiece = MonaPiece(
            bufferIndex: 1,
            start: start,
            length: units.count,
            lineStarts: MonaLineStarts(units)
        )

        guard let r = root else {
            root = MonaPieceTreeNode(piece: newPiece)
            return
        }
        _ = r

        if clampedOffset == 0 {
            // Insert as the in-order predecessor of the leftmost node.
            let leftmost = minimumNode(from: root!)
            let newNode = MonaPieceTreeNode(piece: newPiece)
            insertNode(newNode, asPredecessorOf: leftmost)
        } else if clampedOffset >= totalLength {
            // Insert as the in-order successor of the rightmost node.
            let rightmost = maximumNode(from: root!)
            let newNode = MonaPieceTreeNode(piece: newPiece)
            insertNode(newNode, asSuccessorOf: rightmost)
        } else {
            let (node, rel, _, _) = nodeAtOffset(clampedOffset)!
            if rel == 0 {
                let newNode = MonaPieceTreeNode(piece: newPiece)
                insertNode(newNode, asPredecessorOf: node)
            } else if rel == node.piece.length {
                let newNode = MonaPieceTreeNode(piece: newPiece)
                insertNode(newNode, asSuccessorOf: node)
            } else {
                // Split the piece: keep the left part in `node`, insert the
                // new piece then the right part as in-order successors.
                let leftPiece = node.piece.leftPart(keepingLength: rel)
                let rightPiece = node.piece.rightPart(droppingFirst: rel)
                node.piece = leftPiece
                updateMetadata(node)
                rebalanceUp(from: node)
                let newNode = MonaPieceTreeNode(piece: newPiece)
                insertNode(newNode, asSuccessorOf: node)
                let rightNode = MonaPieceTreeNode(piece: rightPiece)
                insertNode(rightNode, asSuccessorOf: newNode)
            }
        }
    }

    /// Convenience: inserts a `String` (converted to UTF-16) at `offset`.
    public func insert(_ text: String, at offset: Int) {
        insert(Array(text.utf16), at: offset)
    }

    // MARK: - Delete

    /// Deletes the UTF-16 units in `range` (half-open: `lowerBound..<upperBound`).
    ///
    /// Pieces fully inside the range are removed (BST delete + AVL rebalance);
    /// pieces at the boundaries are split and trimmed. O(k log n) for k pieces
    /// touched. `range` is clamped to the document bounds.
    ///
    /// The deletion position `lo` is held FIXED in shifted coordinates: after
    /// deleting `delLen` units at `lo`, the remaining text shifts left to `lo`,
    /// so the next iteration re-queries `nodeAtOffset(lo)` in the CURRENT tree
    /// (not a pre-deletion cursor). This avoids coordinate drift after node
    /// removal (which restructures the tree and shifts in-order positions).
    public func delete(_ range: Range<Int>) {
        counts.edit += 1
        let hi = min(range.upperBound, length)
        var lo = range.lowerBound
        if lo < 0 { lo = 0 }
        if lo >= hi || root == nil {
            return
        }
        var count = hi - lo
        while count > 0 {
            guard let (node, rel, _, _) = nodeAtOffset(lo), root != nil else {
                break
            }
            let avail = node.piece.length - rel
            let delLen = min(count, avail)
            if rel == 0 && delLen >= node.piece.length {
                // Whole piece: remove the node.
                removeNode(node)
            } else if rel == 0 {
                // Trim the left part [0, delLen) of the piece.
                node.piece = node.piece.rightPart(droppingFirst: delLen)
                updateMetadata(node)
                rebalanceUp(from: node)
            } else if delLen >= avail {
                // Trim the right part [rel, length) of the piece.
                node.piece = node.piece.leftPart(keepingLength: rel)
                updateMetadata(node)
                rebalanceUp(from: node)
            } else {
                // Middle split: keep [0, rel) and [rel+delLen, length).
                let leftPiece = node.piece.leftPart(keepingLength: rel)
                let rightPiece = node.piece.rightPart(droppingFirst: rel + delLen)
                node.piece = leftPiece
                updateMetadata(node)
                rebalanceUp(from: node)
                let rightNode = MonaPieceTreeNode(piece: rightPiece)
                insertNode(rightNode, asSuccessorOf: node)
            }
            count -= delLen
        }
    }

    // MARK: - getText / getLineContent

    /// Returns the full document text as raw `[UInt16]`. O(n).
    public func getText() -> [UInt16] {
        counts.search += 1
        var result: [UInt16] = []
        result.reserveCapacity(length)
        var node = root
        var stack: [MonaPieceTreeNode] = []
        while let n = node {
            stack.append(n)
            node = n.left
        }
        while let n = stack.popLast() {
            let buf = buffers[n.piece.bufferIndex]
            let s = n.piece.start
            let e = s + n.piece.length
            result.append(contentsOf: buf[s..<e])
            var child = n.right
            while let c = child {
                stack.append(c)
                child = c.left
            }
        }
        return result
    }

    /// Returns the content of `line` (1-based) excluding its trailing newline,
    /// as raw `[UInt16]`. O(log n + line length). Returns `[]` for an
    /// out-of-range line.
    public func getLineContent(_ line: Int) -> [UInt16] {
        counts.search += 1
        if line < 1 {
            return []
        }
        let totalLength = length
        // Start offset of `line`: after the (line-1)th line feed, or 0 for line 1.
        let startOffset: Int
        if line == 1 {
            startOffset = 0
        } else {
            guard let feedOff = findNthLineFeedGlobalOffset(line - 1) else {
                return []
            }
            startOffset = feedOff + 1
        }
        // End offset: at the `line`th line feed, or end of text.
        let endOffset: Int
        if let feedOff = findNthLineFeedGlobalOffset(line) {
            endOffset = feedOff
        } else {
            endOffset = totalLength
        }
        if startOffset >= endOffset {
            return []
        }
        return collectText(in: startOffset..<endOffset)
    }

    // MARK: - offset <-> position

    /// Returns the 0-based UTF-16 offset for a 1-based `(line, column)` position.
    /// Clamped to `[0, length]`. O(log n).
    public func getOffsetAt(_ position: MonaPosition) -> Int {
        counts.offset += 1
        let line = position.line
        let column = position.column
        let startOffset: Int
        if line <= 1 {
            startOffset = 0
        } else {
            if let feedOff = findNthLineFeedGlobalOffset(line - 1) {
                startOffset = feedOff + 1
            } else {
                startOffset = length
            }
        }
        let offset = startOffset + (column - 1)
        return min(max(offset, 0), length)
    }

    /// Returns the 1-based `(line, column)` position for a 0-based UTF-16 offset.
    /// Clamped to `[0, length]`. O(log n).
    public func getPositionAt(_ offset: Int) -> MonaPosition {
        counts.position += 1
        let clamped = min(max(offset, 0), length)
        if length == 0 {
            return MonaPosition(line: 1, column: 1)
        }
        if clamped == length {
            // Position just past the last unit.
            let prev = rawPositionAt(clamped - 1)
            if let unit = unitAt(clamped - 1), unit == 0x000A {
                return MonaPosition(line: prev.line + 1, column: 1)
            } else {
                return MonaPosition(line: prev.line, column: prev.column + 1)
            }
        }
        return rawPositionAt(clamped)
    }

    // MARK: - Snapshot

    /// Creates an immutable snapshot of the current text. O(n).
    public func createSnapshot() -> MonaTextSnapshot {
        return MonaTextSnapshot(units: getText())
    }

    // MARK: - Internal: tree queries

    /// Finds the node containing `offset` and returns it with the piece-relative
    /// offset and the total UTF-16 length / line-feed count of all pieces that
    /// come before it in-order. O(log n).
    private func nodeAtOffset(_ offset: Int) -> (node: MonaPieceTreeNode, rel: Int, lenBefore: Int, lfBefore: Int)? {
        var node = root
        var lenBefore = 0
        var lfBefore = 0
        while let n = node {
            let leftLen = n.left?.subtreeLength ?? 0
            let leftLF = n.left?.subtreeLineFeeds ?? 0
            if offset < lenBefore + leftLen {
                node = n.left
            } else if offset < lenBefore + leftLen + n.piece.length {
                let rel = offset - (lenBefore + leftLen)
                return (n, rel, lenBefore + leftLen, lfBefore + leftLF)
            } else {
                lenBefore += leftLen + n.piece.length
                lfBefore += leftLF + n.piece.lineFeedCount
                node = n.right
            }
        }
        return nil
    }

    /// Returns the global UTF-16 offset of the `k`th (1-based) line feed, or
    /// `nil` if there are fewer than `k` line feeds. O(log n).
    private func findNthLineFeedGlobalOffset(_ k: Int) -> Int? {
        if k < 1 { return nil }
        var node = root
        var lenBefore = 0
        var remaining = k
        while let n = node {
            let leftLF = n.left?.subtreeLineFeeds ?? 0
            let leftLen = n.left?.subtreeLength ?? 0
            if remaining <= leftLF {
                node = n.left
            } else if remaining <= leftLF + n.piece.lineFeedCount {
                let idx = remaining - leftLF - 1
                let feedOffset = n.piece.lineStarts.lineFeedOffsets[idx]
                return lenBefore + leftLen + feedOffset
            } else {
                remaining -= leftLF + n.piece.lineFeedCount
                lenBefore += leftLen + n.piece.length
                node = n.right
            }
        }
        return nil
    }

    /// Collects the raw `[UInt16]` text in `range` (half-open). O(pieces in
    /// range + range length).
    ///
    /// This is an in-order traversal: when a node is popped, its entire left
    /// subtree has already been visited, so `lenBefore` already accounts for
    /// it. The node's piece therefore starts at `lenBefore` (no `leftLen` is
    /// added — that would double-count the left subtree).
    private func collectText(in range: Range<Int>) -> [UInt16] {
        var result: [UInt16] = []
        let lo = range.lowerBound
        let hi = range.upperBound
        var lenBefore = 0
        var stack: [MonaPieceTreeNode] = []
        var node = root
        while let n = node {
            stack.append(n)
            node = n.left
        }
        while let n = stack.popLast() {
            let pieceStart = lenBefore
            let pieceEnd = pieceStart + n.piece.length
            if pieceEnd > lo && pieceStart < hi {
                let buf = buffers[n.piece.bufferIndex]
                let sliceLo = max(lo - pieceStart, 0)
                let sliceHi = min(hi - pieceStart, n.piece.length)
                let s = n.piece.start + sliceLo
                let e = n.piece.start + sliceHi
                result.append(contentsOf: buf[s..<e])
            }
            lenBefore += n.piece.length
            if lenBefore >= hi {
                break
            }
            var child = n.right
            while let c = child {
                stack.append(c)
                child = c.left
            }
        }
        return result
    }

    /// Reads a single UTF-16 unit at `offset`, or `nil` if out of range.
    private func unitAt(_ offset: Int) -> UInt16? {
        guard let (node, rel, _, _) = nodeAtOffset(offset) else { return nil }
        let buf = buffers[node.piece.bufferIndex]
        return buf[node.piece.start + rel]
    }

    /// Computes the (line, column) for an in-bounds offset strictly before
    /// `length`. O(log n).
    ///
    /// A `\n` at position `p` belongs to the line it terminates (its last
    /// column), so the column is measured from the start of the current line —
    /// which may have begun in an earlier piece. When no feed falls strictly
    /// before `rel` within the containing piece, the previous feed is in an
    /// earlier piece and is looked up by its global offset.
    private func rawPositionAt(_ offset: Int) -> MonaPosition {
        guard let (node, rel, lenBefore, lfBefore) = nodeAtOffset(offset) else {
            return MonaPosition(line: 1, column: 1)
        }
        let feeds = node.piece.lineStarts.lineFeedOffsets
        // Feeds strictly before `rel` within this piece.
        var lfInPieceBefore = 0
        var lastFeedInPiece: Int? = nil
        for f in feeds {
            if f < rel {
                lfInPieceBefore += 1
                lastFeedInPiece = f
            } else {
                break
            }
        }
        let prevFeedGlobal: Int
        let lineFeedsBefore: Int
        if let lastInPiece = lastFeedInPiece {
            // The greatest feed strictly before `offset` is in this piece.
            prevFeedGlobal = lenBefore + lastInPiece
            lineFeedsBefore = lfBefore + lfInPieceBefore
        } else {
            // No feed in this piece before `rel`; the previous feed is in an
            // earlier piece (or there is none).
            if lfBefore > 0, let g = findNthLineFeedGlobalOffset(lfBefore) {
                prevFeedGlobal = g
            } else {
                prevFeedGlobal = -1
            }
            lineFeedsBefore = lfBefore
        }
        let line = lineFeedsBefore + 1
        let column = offset - prevFeedGlobal
        return MonaPosition(line: line, column: column)
    }

    // MARK: - Internal: BST min/max

    private func minimumNode(from start: MonaPieceTreeNode) -> MonaPieceTreeNode {
        var n = start
        while let l = n.left { n = l }
        return n
    }

    private func maximumNode(from start: MonaPieceTreeNode) -> MonaPieceTreeNode {
        var n = start
        while let r = n.right { n = r }
        return n
    }

    // MARK: - Internal: BST insertion (with AVL rebalance)

    /// Inserts `newNode` as the in-order successor of `anchor`.
    private func insertNode(_ newNode: MonaPieceTreeNode, asSuccessorOf anchor: MonaPieceTreeNode) {
        if let r = anchor.right {
            let l = minimumNode(from: r)
            l.left = newNode
            newNode.parent = l
        } else {
            anchor.right = newNode
            newNode.parent = anchor
        }
        rebalanceUp(from: newNode)
    }

    /// Inserts `newNode` as the in-order predecessor of `anchor`.
    private func insertNode(_ newNode: MonaPieceTreeNode, asPredecessorOf anchor: MonaPieceTreeNode) {
        if let l = anchor.left {
            let r = maximumNode(from: l)
            r.right = newNode
            newNode.parent = r
        } else {
            anchor.left = newNode
            newNode.parent = anchor
        }
        rebalanceUp(from: newNode)
    }

    // MARK: - Internal: BST removal (with AVL rebalance)

    /// Removes `node` from the tree.
    private func removeNode(_ node: MonaPieceTreeNode) {
        var target = node
        if target.left != nil && target.right != nil {
            // Two children: copy the in-order successor's piece and remove it.
            let succ = minimumNode(from: target.right!)
            target.piece = succ.piece
            target = succ
        }
        let child = target.left ?? target.right
        let parent = target.parent
        if let c = child {
            c.parent = parent
        }
        if let p = parent {
            if p.left === target {
                p.left = child
            } else {
                p.right = child
            }
            rebalanceUp(from: p)
        } else {
            root = child
        }
    }

    // MARK: - Internal: AVL balancing

    private func height(_ n: MonaPieceTreeNode?) -> Int {
        return n?.height ?? 0
    }

    private func balanceFactor(_ n: MonaPieceTreeNode) -> Int {
        return height(n.left) - height(n.right)
    }

    /// Recomputes `subtreeLength`, `subtreeLineFeeds`, and `height` from the
    /// node's children and own piece.
    private func updateMetadata(_ n: MonaPieceTreeNode) {
        n.subtreeLength = n.piece.length
            + (n.left?.subtreeLength ?? 0)
            + (n.right?.subtreeLength ?? 0)
        n.subtreeLineFeeds = n.piece.lineFeedCount
            + (n.left?.subtreeLineFeeds ?? 0)
            + (n.right?.subtreeLineFeeds ?? 0)
        n.height = 1 + max(height(n.left), height(n.right))
    }

    private func rotateLeft(_ x: MonaPieceTreeNode) {
        guard let y = x.right else { return }
        let t2 = y.left
        // Capture x's original parent BEFORE reassigning `x.parent`.
        let parent = x.parent
        // Restructure: y takes x's place, x becomes y's left child.
        y.left = x
        x.parent = y
        x.right = t2
        if let t2 = t2 { t2.parent = x }
        y.parent = parent
        if parent == nil {
            root = y
        } else if parent?.left === x {
            parent?.left = y
        } else {
            parent?.right = y
        }
        // Update lower node first, then the new subtree root.
        updateMetadata(x)
        updateMetadata(y)
    }

    private func rotateRight(_ y: MonaPieceTreeNode) {
        guard let x = y.left else { return }
        let t2 = x.right
        // Capture y's original parent BEFORE reassigning `y.parent`.
        let parent = y.parent
        x.right = y
        y.parent = x
        y.left = t2
        if let t2 = t2 { t2.parent = y }
        x.parent = parent
        if parent == nil {
            root = x
        } else if parent?.left === y {
            parent?.left = x
        } else {
            parent?.right = x
        }
        updateMetadata(y)
        updateMetadata(x)
    }

    /// Walks from `node` to the root, recomputing metadata and rebalancing.
    private func rebalanceUp(from node: MonaPieceTreeNode?) {
        var n = node
        while let current = n {
            updateMetadata(current)
            let bf = balanceFactor(current)
            if bf > 1 {
                if balanceFactor(current.left!) < 0 {
                    rotateLeft(current.left!)
                }
                rotateRight(current)
            } else if bf < -1 {
                if balanceFactor(current.right!) > 0 {
                    rotateRight(current.right!)
                }
                rotateLeft(current)
            }
            n = current.parent
        }
    }
}
