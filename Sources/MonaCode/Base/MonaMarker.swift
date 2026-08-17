// MonaMarker.swift
//
// P01-T004 — Implement key, modifier, token, and marker value types.
//
// This file ports Monaco's marker-related standalone enums and wraps them in a
// `MonaMarker` value type that carries a severity and an optional tag.
//
//   - `MonaMarkerSeverity` — ported verbatim from `monaco.MarkerSeverity`.
//     The raw values keep Monaco's bit-flag layout (Hint = 1, Info = 2,
//     Warning = 4, Error = 8): the gap between Info and Warning is intentional
//     and load-bearing (the values double as bit flags), so the enum is NOT
//     reordered or compressed. `Comparable` orders by severity, giving
//     Error > Warning > Info > Hint.
//   - `MonaMarkerTag`      — ported verbatim from `monaco.MarkerTag`
//     (Unnecessary = 1, Deprecated = 2).
//   - `MonaMarker`         — a value type carrying a `severity`, a `message`,
//     and an optional `tag`. Equality is over all three fields.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The severity of a marker, ported from `monaco.MarkerSeverity`.
///
/// The raw values are Monaco's bit flags (Hint = 1, Info = 2, Warning = 4,
/// Error = 8) — they are NOT reordered or compressed. `Comparable` orders by
/// severity: `Error > Warning > Info > Hint`.
public enum MonaMarkerSeverity: Int, Equatable, Hashable, Sendable, Comparable {

    /// The least severe marker (1).
    case hint = 1

    /// An informational marker (2).
    case info = 2

    /// A warning marker (4).
    case warning = 4

    /// The most severe marker — an error (8).
    case error = 8

    /// The least severity (`hint`).
    public static let min: MonaMarkerSeverity = .hint

    /// The greatest severity (`error`).
    public static let max: MonaMarkerSeverity = .error

    /// Orders by severity: `hint < info < warning < error`.
    public static func < (lhs: MonaMarkerSeverity, rhs: MonaMarkerSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// A marker tag, ported from `monaco.MarkerTag`.
public enum MonaMarkerTag: Int, Equatable, Hashable, Sendable {

    /// Marks a marker as pointing at unnecessary code (1).
    case unnecessary = 1

    /// Marks a marker as pointing at deprecated code (2).
    case deprecated = 2
}

/// A marker: a severity-bearing diagnostic value.
///
/// Carries the severity, a human-readable `message`, and an optional `tag`.
/// Equality is over all three fields. Severity ordering is provided by
/// `MonaMarkerSeverity`'s `Comparable` conformance.
public struct MonaMarker: Equatable, Hashable, Sendable {

    /// The severity of the marker.
    public let severity: MonaMarkerSeverity

    /// The human-readable marker message.
    public let message: String

    /// An optional marker tag (e.g. `.unnecessary`, `.deprecated`). `nil` when
    /// the marker carries no tag.
    public let tag: MonaMarkerTag?

    /// Creates a marker with a severity, message, and optional tag.
    public init(severity: MonaMarkerSeverity, message: String, tag: MonaMarkerTag? = nil) {
        self.severity = severity
        self.message = message
        self.tag = tag
    }
}
