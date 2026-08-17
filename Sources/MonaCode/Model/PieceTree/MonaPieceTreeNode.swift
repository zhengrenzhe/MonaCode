// MonaPieceTreeNode.swift
//
// P01-T007 — Port the Piece Tree over raw UInt16 storage.
//
// A Piece Tree is a self-balancing binary search tree (an AVL tree — the Swift
// idiom for Monaco's red-black `TreeNode` in `pieceTreeBase.ts`) whose in-order
// traversal yields the document text. Each node holds a `MonaPiece` — a
// reference into one of the tree's raw `[UInt16]` buffers — plus accumulated
// subtree metadata (total UTF-16 length and total line-feed count) so that
// offset → node, line → offset, and offset → position queries are O(log n).
//
// Balancing (split/merge on insert/delete) is performed by AVL rotations after
// every structural change; each rotation recomputes the affected nodes'
// metadata from their children. Pieces are split (left/right part) when an edit
// lands mid-piece, and whole pieces are removed (BST delete + AVL rebalance)
// when an edit fully covers them.
//
// `MonaPiece` stores raw UTF-16 code units: the buffers are `[UInt16]` and are
// never mutated after a piece references them, so isolated surrogates are
// preserved verbatim (never repaired to U+FFFD).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A reference to a contiguous slice of one of the Piece Tree's raw `[UInt16]`
/// buffers, together with the line-feed offsets within that slice.
///
/// A piece is identified by `bufferIndex` (which buffer), `start` (the UTF-16
/// offset into that buffer where the piece begins), and `length` (the number of
/// UTF-16 units in the piece). `lineStarts` lists the 0-based offsets (relative
/// to the piece's own start) of each `\n` in the piece, so line/offset queries
/// within a piece need no buffer rescan.
///
/// Pieces are immutable values. Splitting a piece into left and right parts
/// produces new pieces that reference the same buffer at different offsets —
/// the underlying `[UInt16]` is never mutated, so raw code units (including
/// isolated surrogates) are preserved.
public struct MonaPiece: Equatable {

    /// The index of the buffer in the owning Piece Tree's buffer list.
    public let bufferIndex: Int

    /// The UTF-16 offset into the buffer where this piece begins.
    public let start: Int

    /// The number of UTF-16 code units in this piece.
    public let length: Int

    /// Line-feed offsets within this piece, 0-based relative to `start`.
    public let lineStarts: MonaLineStarts

    /// The number of `\n` characters in this piece.
    public var lineFeedCount: Int {
        return lineStarts.lineFeedCount
    }

    /// Creates a piece.
    public init(bufferIndex: Int, start: Int, length: Int, lineStarts: MonaLineStarts) {
        self.bufferIndex = bufferIndex
        self.start = start
        self.length = length
        self.lineStarts = lineStarts
    }

    /// Returns the left part of this piece: the slice `[0, length)` relative to
    /// the piece start, keeping only line feeds strictly before `k`.
    public func leftPart(keepingLength k: Int) -> MonaPiece {
        let kept = lineStarts.lineFeedOffsets.filter { $0 < k }
        return MonaPiece(
            bufferIndex: bufferIndex,
            start: start,
            length: k,
            lineStarts: MonaLineStarts(lineFeedOffsets: kept)
        )
    }

    /// Returns the right part of this piece: the slice `[k, length)` relative to
    /// the piece start, re-basing line feeds so they are 0-based in the result.
    public func rightPart(droppingFirst k: Int) -> MonaPiece {
        let rebased = lineStarts.lineFeedOffsets.filter { $0 >= k }.map { $0 - k }
        return MonaPiece(
            bufferIndex: bufferIndex,
            start: start + k,
            length: length - k,
            lineStarts: MonaLineStarts(lineFeedOffsets: rebased)
        )
    }
}

/// A node in the Piece Tree's balanced BST.
///
/// Each node holds one `MonaPiece` and the accumulated totals of its left and
/// right subtrees (`subtreeLength`, `subtreeLineFeeds`) plus an AVL `height`
/// for balancing. The in-order traversal of the tree yields the document text.
///
/// `subtreeLength` and `subtreeLineFeeds` are the totals of the ENTIRE subtree
/// rooted at this node (left + self + right), recomputed from children after
/// every rotation or piece replacement. They let offset-rank queries run in
/// O(log n): descend from the root, comparing the queried offset against the
/// left child's subtree total and the node's own piece length.
public final class MonaPieceTreeNode {

    /// The piece held by this node.
    public var piece: MonaPiece

    /// The left child, or `nil`.
    public var left: MonaPieceTreeNode?

    /// The right child, or `nil`.
    public var right: MonaPieceTreeNode?

    /// The parent, or `nil` for the root.
    public var parent: MonaPieceTreeNode?

    /// The AVL height of this node (a leaf is 1).
    public var height: Int

    /// Total UTF-16 length of the subtree rooted at this node
    /// (left + self + right).
    public var subtreeLength: Int

    /// Total line-feed count of the subtree rooted at this node
    /// (left + self + right).
    public var subtreeLineFeeds: Int

    /// Creates a node holding `piece` and no children.
    public init(piece: MonaPiece) {
        self.piece = piece
        self.left = nil
        self.right = nil
        self.parent = nil
        self.height = 1
        self.subtreeLength = piece.length
        self.subtreeLineFeeds = piece.lineFeedCount
    }
}
