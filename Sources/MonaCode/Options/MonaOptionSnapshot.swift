// MonaOptionSnapshot.swift
//
// P05-T005 — Implement all 174 editor options and computed option truth.
//
// `MonaOptionSnapshot` is an immutable snapshot of all readable option values
// (157 retained-input + 6 computed-only = 163) at a point in time. The public
// API exposes a consistent read: a snapshot taken after a `setValue` reflects
// both the new input value and the recomputed computed-only values. Cut
// options are excluded (they are never part of the readable surface).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An immutable snapshot of all readable editor option values (retained-input
/// + computed-only), for the public API to expose a consistent read.
public struct MonaOptionSnapshot: Sendable, Equatable {

    private let values: [String: MonaOptionValue]

    /// Creates a snapshot from a value dictionary.
    init(values: [String: MonaOptionValue]) {
        self.values = values
    }

    /// The number of readable option values (retained-input + computed-only).
    public var count: Int { values.count }

    /// Returns the value for `name`, or `nil` when absent (cut / unknown).
    public func value(for name: String) -> MonaOptionValue? {
        return values[name]
    }

    /// The names of all options in the snapshot, in no particular order.
    public var names: [String] { Array(values.keys) }
}
