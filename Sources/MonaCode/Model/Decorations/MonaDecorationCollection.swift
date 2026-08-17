// MonaDecorationCollection.swift
//
// P02-T002 — Port decoration interval trees and stickiness semantics.
//
// `MonaDecorationCollection` is a collection of decorations for a model — the
// Swift counterpart of Monaco's `DecorationsCollection`
// (monaco-editor 0.56.0). It owns a `MonaDecorationTree` and exposes add /
// remove / clear / range-query / owner-filtered access over the decorations.
//
// The collection is the per-feature handle a model feature uses to manage its
// own decorations: it adds and removes decorations by id, queries the
// intersecting decorations for a range (for rendering), and lists its
// decorations (optionally owner-filtered). Range movement on edit is delegated
// to the underlying tree.
//
// `MonaDecorationCollection` is a `struct` that wraps a `MonaDecorationTree`
// (a reference type). The tree is the source of truth for the live decoration
// ranges, so the collection's mutating methods route through the tree.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A collection of decorations for a model.
///
/// Create with `init()`, then `add(_:)` / `remove(id:)` / `clear()` to manage
/// membership, and `decorations(in:)` / `allDecorations(ownerId:)` to query.
public struct MonaDecorationCollection {

    /// The underlying interval tree holding the collection's decorations.
    private var tree: MonaDecorationTree

    /// Creates an empty decoration collection.
    public init() {
        self.tree = MonaDecorationTree()
    }

    /// Adds (or, when `id` already exists, replaces) a decoration.
    public mutating func add(_ decoration: MonaDecoration) {
        tree.insert(decoration)
    }

    /// Removes the decoration with the given id, returning it, or `nil` when no
    /// such decoration exists.
    @discardableResult
    public mutating func remove(id: String) -> MonaDecoration? {
        return tree.delete(id: id)
    }

    /// Removes every decoration in the collection.
    public mutating func clear() {
        tree.removeAll()
    }

    /// The number of decorations in the collection.
    public func count() -> Int {
        return tree.count()
    }

    /// Returns every decoration whose range intersects `range` (touching
    /// counts).
    public func decorations(in range: MonaRange) -> [MonaDecoration] {
        return tree.query(range)
    }

    /// Returns every decoration in the collection, optionally owner-filtered,
    /// sorted by id.
    public func allDecorations(ownerId: Int = 0) -> [MonaDecoration] {
        return tree.allDecorations(ownerId: ownerId)
    }

    /// Returns the decoration with the given id, or `nil` when no such
    /// decoration exists.
    public func get(id: String) -> MonaDecoration? {
        return tree.get(id: id)
    }
}
