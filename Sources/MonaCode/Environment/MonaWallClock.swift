// MonaWallClock.swift
//
// P00-T005 — Implement separate wall and high-resolution clock domains.
//
// Concrete wall-clock domain. Returns wall-clock milliseconds since the Unix
// epoch, derived from `Date.timeIntervalSince1970 * 1000`. Conforms ONLY to
// `MonaWallClocking`; does not conform to `MonaHighResolutionClocking` and is
// not substitutable for it.
//
// MonaCode is Foundation-only: `import Foundation` is the sole import.

import Foundation

/// Concrete wall-clock domain.
///
/// Returns wall-clock milliseconds since the Unix epoch
/// (1970-01-01T00:00:00Z), computed as
/// `Date.timeIntervalSince1970 * 1000.0`. The value is binary64 (`Double`); no
/// integer narrowing or rounding is applied, so the injected binary64 trace is
/// preserved exactly.
///
/// `MonaWallClock` conforms only to `MonaWallClocking`. It deliberately does
/// NOT conform to `MonaHighResolutionClocking`, so the two domains remain
/// non-substitutable at the type level.
public struct MonaWallClock: MonaWallClocking {

    /// Creates a wall-clock domain instance.
    public init() {}

    public func wallMilliseconds() -> Double {
        // `Date().timeIntervalSince1970` is a binary64 `Double` of seconds
        // since 1970-01-01T00:00:00Z. Multiplying by 1000 yields milliseconds
        // in binary64; the result preserves the injected trace exactly because
        // no integer conversion or rounding is applied.
        return Date().timeIntervalSince1970 * 1000.0
    }
}
