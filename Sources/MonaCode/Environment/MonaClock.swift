// MonaClock.swift
//
// P00-T005 — Implement separate wall and high-resolution clock domains.
//
// This file defines the two separate, non-substitutable clock domains used by
// MonaCode and the aggregate `MonaClock` protocol that requires both domains
// to be available. The two domain protocols (`MonaWallClocking` and
// `MonaHighResolutionClocking`) are intentionally UNRELATED: they share no
// supertype and admit no implicit conversion, so a value of one domain cannot
// be used where the other is required. This prevents the frozen timing
// occurrences from being substituted one for another.
//
// All clock values are binary64 (`Double`) to preserve injected traces exactly.
//
// MonaCode is a Foundation-only target: the only import permitted by the
// P00-T002 forbidden-imports gate is `Foundation`. The Darwin symbols used by
// the high-resolution clock (`mach_absolute_time`, `mach_timebase_info`,
// `mach_timebase_info_data_t`, `KERN_SUCCESS`) are re-exported by `Foundation`
// on Apple platforms, so no separate `import Darwin` / `import Dispatch` is
// needed.

import Foundation

/// Injected wall-clock domain.
///
/// Returns wall-clock milliseconds since the Unix epoch
/// (1970-01-01T00:00:00Z), derived from `Date.timeIntervalSince1970 * 1000`.
/// Wall-clock time is NOT monotonic: it is subject to NTP adjustments, manual
/// clock changes, and leap-second handling, and it must not be used where
/// monotonic high-resolution time is required.
///
/// This protocol is intentionally UNRELATED to `MonaHighResolutionClocking`.
/// The two domains are separate types with no shared supertype and no implicit
/// conversion: a value conforming to `MonaWallClocking` cannot be used where
/// `MonaHighResolutionClocking` is required, and vice versa. This enforces the
/// P00-T005 requirement that no frozen timing occurrence be substituted across
/// domains.
///
/// Values are binary64 (`Double`) to preserve injected traces exactly.
public protocol MonaWallClocking {
    /// Wall-clock milliseconds since 1970-01-01T00:00:00Z.
    func wallMilliseconds() -> Double
}

/// Injected high-resolution domain.
///
/// Returns monotonic high-resolution milliseconds derived from
/// `mach_absolute_time`, converted to milliseconds via the mach timebase.
/// Monotonic time is NOT wall-clock: it has no relationship to the calendar
/// epoch and must not be used where wall-clock time is required.
///
/// This protocol is intentionally UNRELATED to `MonaWallClocking`. See that
/// protocol's documentation for the non-substitutability guarantee.
///
/// Values are binary64 (`Double`) to preserve injected traces exactly.
public protocol MonaHighResolutionClocking {
    /// Monotonic high-resolution milliseconds since an arbitrary fixed origin.
    func highResolutionMilliseconds() -> Double
}

/// Aggregate clock protocol defining the two separate, non-substitutable clock
/// domains.
///
/// `MonaClock` requires BOTH a wall-clock domain and a high-resolution domain
/// to be available. It does NOT unify them into a single substitutable
/// interface: `wallClock` is typed `any MonaWallClocking` and
/// `highResolutionClock` is typed `any MonaHighResolutionClocking`, and the two
/// domain protocols remain unrelated. A wall-clock value cannot be assigned to
/// the high-resolution slot (and vice versa) — this is enforced at compile time
/// by the type system and at runtime by `is` checks (see `MonaClockTests`).
///
/// Both domains return binary64 (`Double`) values to preserve injected traces
/// exactly.
public protocol MonaClock {
    /// The wall-clock domain. Never substitutable for `highResolutionClock`.
    var wallClock: any MonaWallClocking { get }

    /// The high-resolution domain. Never substitutable for `wallClock`.
    var highResolutionClock: any MonaHighResolutionClocking { get }
}
