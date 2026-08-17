// MonaSelection.swift
//
// P01-T002 — Implement ranges and oriented selections.
//
// `MonaSelection` is a range that has an orientation. It stores the two raw
// endpoints of the selection — `anchor` (where the selection started, Monaco's
// `selectionStart`) and `activePosition` (where the caret landed, Monaco's
// `position`) — and derives the normalized range (`startPosition` /
// `endPosition`) plus the orientation from them.
//
// The range is normalized (start sorts at or before end, line-major then column)
// exactly as `MonaRange` normalizes, but the anchor + active positions are
// preserved verbatim. This preserves the selection orientation when normalizing:
// a backward selection (anchor after active) keeps its anchor at the end and its
// active at the start, even though the exposed range is ordered start-to-end.
//
// `orientation` is ported branch-for-branch from Monaco's `Selection.getDirection`:
// `.forward` (LTR) when the anchor equals the normalized start position,
// `.backward` (RTL) otherwise. A collapsed selection (anchor == active) is
// forward, matching Monaco.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The orientation of a selection.
///
/// Ported from Monaco's `SelectionDirection`: `.forward` corresponds to `LTR`
/// (the anchor sorts at or before the active position), `.backward` to `RTL`
/// (the anchor sorts after the active position).
public enum MonaSelectionOrientation: Equatable, Hashable {

    /// The anchor is the normalized start position (selection flows forward).
    case forward

    /// The anchor is the normalized end position (selection flows backward).
    case backward
}

/// A selection: a range plus an orientation, stored as an anchor + active
/// position pair.
///
/// The anchor (`selectionStart`) and active position (`position`) are preserved
/// as given; the normalized `startPosition` / `endPosition` and the `orientation`
/// are derived. This preserves the selection orientation when the range is
/// normalized, matching Monaco's `Selection` (which stores both the normalized
/// range inherited from `Range` and the raw `selectionStart` / `position`).
public struct MonaSelection: Equatable, Hashable {

    /// Where the selection started (Monaco `selectionStart`). Preserved verbatim
    /// when the range is normalized.
    public let anchor: MonaPosition

    /// Where the selection ended / the caret rests (Monaco `position`). Preserved
    /// verbatim when the range is normalized.
    public let activePosition: MonaPosition

    /// Creates a selection from its raw anchor + active position pair.
    ///
    /// The anchor and active position are stored as given (not swapped), so a
    /// backward selection (anchor sorting after active) retains its orientation.
    /// The normalized range and orientation are derived from this pair.
    public init(anchor: MonaPosition, activePosition: MonaPosition) {
        self.anchor = anchor
        self.activePosition = activePosition
    }

    /// Creates a selection from a normalized range and an orientation, setting
    /// the anchor + active position per the orientation (ported from Monaco's
    /// `Selection.createWithDirection` / `fromRange`).
    ///
    /// - `.forward`: anchor = `startPosition`, active = `endPosition`.
    /// - `.backward`: anchor = `endPosition`, active = `startPosition`.
    public init(
        startPosition: MonaPosition,
        endPosition: MonaPosition,
        orientation: MonaSelectionOrientation
    ) {
        switch orientation {
        case .forward:
            self.anchor = startPosition
            self.activePosition = endPosition
        case .backward:
            self.anchor = endPosition
            self.activePosition = startPosition
        }
    }

    /// The normalized start position: the earlier of the anchor and active
    /// position (line-major, then column).
    public var startPosition: MonaPosition {
        return min(anchor, activePosition)
    }

    /// The normalized end position: the later of the anchor and active position
    /// (line-major, then column).
    public var endPosition: MonaPosition {
        return max(anchor, activePosition)
    }

    /// The selection orientation, ported branch-for-branch from Monaco's
    /// `Selection.getDirection`.
    ///
    /// `.forward` (LTR) when the anchor equals the normalized start position;
    /// `.backward` (RTL) otherwise. A collapsed selection (anchor == active) is
    /// `.forward`.
    public var orientation: MonaSelectionOrientation {
        return anchor == startPosition ? .forward : .backward
    }
}
