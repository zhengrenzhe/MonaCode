// MonaHighResolutionClock.swift
//
// P00-T005 — Implement separate wall and high-resolution clock domains.
//
// Concrete high-resolution domain. Returns monotonic high-resolution
// milliseconds derived from `mach_absolute_time`, converted to milliseconds
// via the mach timebase. Conforms ONLY to `MonaHighResolutionClocking`; does
// not conform to `MonaWallClocking` and is not substitutable for it.
//
// MonaCode is Foundation-only: the Darwin symbols `mach_absolute_time`,
// `mach_timebase_info`, `mach_timebase_info_data_t`, and `KERN_SUCCESS` are
// re-exported by `Foundation` on Apple platforms, so `import Foundation` is the
// sole import. `import Dispatch` is intentionally avoided to keep the
// Foundation-only boundary enforced by P00-T002.

import Foundation

/// Concrete high-resolution domain.
///
/// Returns monotonic high-resolution milliseconds derived from
/// `mach_absolute_time`, converted to nanoseconds via `mach_timebase_info` and
/// then to milliseconds as a binary64 `Double`.
///
/// `MonaHighResolutionClock` conforms only to `MonaHighResolutionClocking`. It
/// deliberately does NOT conform to `MonaWallClocking`, so the two domains
/// remain non-substitutable at the type level.
public struct MonaHighResolutionClock: MonaHighResolutionClocking {

    /// Creates a high-resolution domain instance.
    public init() {}

    public func highResolutionMilliseconds() -> Double {
        // `mach_absolute_time` returns monotonic Mach absolute time units. The
        // per-boot conversion ratio to nanoseconds is given by
        // `mach_timebase_info`. On Apple Silicon the ratio is 1/1; on Intel it
        // is 125/3. The timebase is constant for the lifetime of a boot and the
        // call never fails in practice.
        let absolute = mach_absolute_time()

        var info = mach_timebase_info_data_t()
        let status = mach_timebase_info(&info)
        precondition(status == KERN_SUCCESS, "mach_timebase_info failed")

        // Convert absolute units to nanoseconds using UInt64 arithmetic, then
        // promote the nanosecond count to binary64 milliseconds. The final
        // value is `Double`, preserving the injected binary64 trace format
        // required by the frozen vectors.
        let nanoseconds = (absolute * UInt64(info.numer)) / UInt64(info.denom)
        return Double(nanoseconds) / 1_000_000.0
    }
}
