// MonaDecoration.swift
//
// P02-T002 — Port decoration interval trees and stickiness semantics.
//
// `MonaDecoration` is the immutable record of one tracked range held by a
// `MonaDecorationTree` — the Swift counterpart of Monaco's `IModelDecoration`
// (monaco-editor 0.56.0). A decoration carries:
//
//   - `id`          — a stable identifier assigned by the tree.
//   - `range`       — the tracked `MonaRange` (mutated in place by the tree on
//                     edit, so `range` is a `var`).
//   - `ownerId`     — the owner (0 = any owner). Owners partition decorations so
//                     a feature can query only its own.
//   - `stickiness`  — the Swift counterpart of Monaco's `TrackedRangeStickiness`.
//                     Decides how each endpoint resolves when an edit replaces a
//                     region the endpoint lands inside.
//   - `options`     — the rendering options (typed descriptors, not CSS class
//                     truth).
//
// `MonaDecorationStickiness` ports Monaco's four-value
// `TrackedRangeStickiness` enum. When an edit replaces `[from, to)` with text of
// length `L`, an endpoint that lies within `[from, to]` is resolved to either
// `from` (left affinity — sticks before the edit) or `from + L` (right affinity
// — sticks after the edit). The four stickiness values map to the endpoint
// affinities below; the names describe which edges grow when typing at them:
//
//   stickiness                       start  end
//   ---------------------------------------------------
//   alwaysGrowsWhenTypingAtEdges      left   right   (grows at both edges)
//   neverGrowsWhenTypingAtEdges       right  left    (grows at neither edge)
//   growsOnlyWhenTypingBefore         left   left    (grows only at the start edge)
//   growsOnlyWhenTypingAfter          right  right   (grows only at the end edge)
//
// `forceMoveMarkers == true` overrides stickiness and forces an endpoint exactly
// at the edit boundary to take right affinity (move with the inserted text).
//
// `MonaDecorationOptions` ports the rendering-option subset that the decoration
// tree needs to filter (whole-line, overview-ruler lane, inline/margin class
// names, zIndex). Style descriptors are typed names, not CSS class strings: the
// tree accepts and stores them but never interprets them.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The four tracked-range stickiness values — the Swift counterpart of Monaco's
/// `TrackedRangeStickiness`.
///
/// Decides how each endpoint of a decoration resolves when an edit replaces a
/// region the endpoint lands inside. See the file header for the
/// stickiness → endpoint-affinity table.
public enum MonaDecorationStickiness: Equatable, Hashable, Sendable {

    /// The range grows when typing at either edge. Start takes left affinity,
    /// end takes right affinity.
    case alwaysGrowsWhenTypingAtEdges

    /// The range never grows when typing at an edge. Start takes right affinity,
    /// end takes left affinity.
    case neverGrowsWhenTypingAtEdges

    /// The range grows only when typing at the start (before) edge. Both
    /// endpoints take left affinity.
    case growsOnlyWhenTypingBefore

    /// The range grows only when typing at the end (after) edge. Both
    /// endpoints take right affinity.
    case growsOnlyWhenTypingAfter

    /// The start endpoint's affinity for this stickiness.
    ///
    /// `true` means left affinity (the endpoint sticks before the edit and
    /// resolves to `from`).
    var startSticksLeft: Bool {
        switch self {
        case .alwaysGrowsWhenTypingAtEdges, .growsOnlyWhenTypingBefore:
            return true
        case .neverGrowsWhenTypingAtEdges, .growsOnlyWhenTypingAfter:
            return false
        }
    }

    /// The end endpoint's affinity for this stickiness.
    ///
    /// `true` means left affinity (the endpoint sticks before the edit and
    /// resolves to `from`).
    var endSticksLeft: Bool {
        switch self {
        case .alwaysGrowsWhenTypingAtEdges, .growsOnlyWhenTypingAfter:
            return false
        case .neverGrowsWhenTypingAtEdges, .growsOnlyWhenTypingBefore:
            return true
        }
    }
}

/// A bit-flag lane on the overview ruler — the Swift counterpart of Monaco's
/// `OverviewRulerLane`.
public struct MonaOverviewRulerLane: OptionSet, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let left   = MonaOverviewRulerLane(rawValue: 1)
    public static let center = MonaOverviewRulerLane(rawValue: 2)
    public static let right  = MonaOverviewRulerLane(rawValue: 4)
    public static let full: MonaOverviewRulerLane = [.left, .center, .right]
}

/// Overview-ruler rendering options for a decoration.
public struct MonaDecorationOverviewRulerOptions: Equatable, Sendable {

    /// The typed color descriptor (e.g. a theme color id), or `nil`.
    public var color: String?

    /// The lane(s) the decoration occupies on the overview ruler.
    public var lane: MonaOverviewRulerLane

    /// Creates overview-ruler options.
    public init(color: String? = nil, lane: MonaOverviewRulerLane = .right) {
        self.color = color
        self.lane = lane
    }
}

/// The rendering-option subset the decoration tree needs to filter on.
///
/// Style descriptors are typed names, not CSS class strings: the tree accepts and
/// stores them but never interprets them.
public struct MonaDecorationOptions: Equatable, Sendable {

    /// `true` when the decoration spans the whole line (line decoration);
    /// `false` for an inline (range) decoration.
    public var isWholeLine: Bool

    /// The typed inline class name, or `nil`.
    public var inlineClassName: String?

    /// The typed (glyph-margin) class name, or `nil`.
    public var marginClassName: String?

    /// The overview-ruler options, or `nil` when the decoration has no overview
    /// ruler contribution.
    public var overviewRuler: MonaDecorationOverviewRulerOptions?

    /// The stacking order for overlapping decorations.
    public var zIndex: Int

    /// Creates rendering options.
    public init(
        isWholeLine: Bool = false,
        inlineClassName: String? = nil,
        marginClassName: String? = nil,
        overviewRuler: MonaDecorationOverviewRulerOptions? = nil,
        zIndex: Int = 0
    ) {
        self.isWholeLine = isWholeLine
        self.inlineClassName = inlineClassName
        self.marginClassName = marginClassName
        self.overviewRuler = overviewRuler
        self.zIndex = zIndex
    }
}

/// The record of one tracked range held by a `MonaDecorationTree`.
///
/// `range` is a `var` because the tree mutates decoration positions in place on
/// edit (range movement). All other fields are immutable identity. Two
/// decorations with equal fields compare equal.
public struct MonaDecoration: Equatable {

    /// The stable identifier assigned by the tree.
    public let id: String

    /// The tracked range. Mutated in place by the tree on edit.
    public var range: MonaRange

    /// The owner (0 = any owner).
    public let ownerId: Int

    /// The stickiness — how each endpoint resolves under an edit.
    public let stickiness: MonaDecorationStickiness

    /// The rendering options.
    public var options: MonaDecorationOptions

    /// Creates a decoration.
    public init(
        id: String,
        range: MonaRange,
        ownerId: Int = 0,
        stickiness: MonaDecorationStickiness = .alwaysGrowsWhenTypingAtEdges,
        options: MonaDecorationOptions = MonaDecorationOptions()
    ) {
        self.id = id
        self.range = range
        self.ownerId = ownerId
        self.stickiness = stickiness
        self.options = options
    }
}
