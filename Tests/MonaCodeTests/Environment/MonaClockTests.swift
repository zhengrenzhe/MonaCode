// MonaClockTests.swift
//
// P00-T005 — Implement separate wall and high-resolution clock domains.
//
// Verifies:
//   - `MonaClock` protocol exists and defines the two separate clock domains.
//   - `MonaWallClock` provides wall-clock milliseconds (via `Date`).
//   - `MonaHighResolutionClock` provides monotonic high-resolution time
//     (via `mach_absolute_time`).
//   - The two domains are NOT substitutable (wall != high-res).
//   - Binary64 traces are preserved (clock values are `Double`).

import XCTest
import MonaCode

final class MonaClockTests: XCTestCase {

    // MARK: - MonaClock protocol existence

    func testMonaClockProtocolDefinesTwoSeparateDomains() {
        // `MonaClock` is the aggregate protocol that requires BOTH a wall-clock
        // domain and a high-resolution domain to be available. A conformer must
        // supply both, and the two slots are typed with their separate,
        // non-substitutable domain protocols (`any MonaWallClocking` and
        // `any MonaHighResolutionClocking`).
        struct BothDomains: MonaClock {
            let wallClock: any MonaWallClocking = MonaWallClock()
            let highResolutionClock: any MonaHighResolutionClocking = MonaHighResolutionClock()
        }
        let clock: MonaClock = BothDomains()

        let wall = clock.wallClock.wallMilliseconds()
        let high = clock.highResolutionClock.highResolutionMilliseconds()

        // Both domains are reachable and produce finite binary64 values.
        let wallDouble: Double = wall
        let highDouble: Double = high
        XCTAssertTrue(wallDouble.isFinite)
        XCTAssertTrue(highDouble.isFinite)
    }

    // MARK: - MonaWallClock (wall-clock domain)

    func testMonaWallClockReturnsBinary64WallMillisecondsFromDate() {
        let clock = MonaWallClock()

        // Bracket the call with two `Date` samples. Wall-clock ms derived from
        // `Date().timeIntervalSince1970 * 1000` must lie between the samples.
        let before = Date().timeIntervalSince1970 * 1000.0
        let ms = clock.wallMilliseconds()
        let after = Date().timeIntervalSince1970 * 1000.0

        // The value is binary64 (`Double`) — enforced by the return type, and
        // re-affirmed by this assignment which would not type-check otherwise.
        let _: Double = ms

        XCTAssertGreaterThanOrEqual(ms, before)
        XCTAssertLessThanOrEqual(ms, after)
        // Sanity: wall-clock ms since 1970 is well past 1.7e12 (year 2023).
        XCTAssertGreaterThan(ms, 1.7e12)
    }

    func testMonaWallClockConformsToWallClockingOnly() {
        let wall = MonaWallClock()
        XCTAssertTrue(wall is MonaWallClocking)
    }

    // MARK: - MonaHighResolutionClock (high-resolution domain)

    func testMonaHighResolutionClockReturnsBinary64MonotonicMilliseconds() {
        let clock = MonaHighResolutionClock()

        let first = clock.highResolutionMilliseconds()
        let second = clock.highResolutionMilliseconds()

        // The value is binary64 (`Double`).
        let _: Double = first

        // Monotonic: successive samples never go backwards.
        XCTAssertGreaterThanOrEqual(second, first)
        // Non-negative uptime.
        XCTAssertGreaterThanOrEqual(first, 0.0)
    }

    func testMonaHighResolutionClockConformsToHighResolutionClockingOnly() {
        let high = MonaHighResolutionClock()
        XCTAssertTrue(high is MonaHighResolutionClocking)
    }

    // MARK: - Non-substitutability (wall != high-res)

    func testWallClockIsNotHighResolution() {
        let wall = MonaWallClock()
        // MonaWallClock must NOT conform to MonaHighResolutionClocking. The two
        // domains are separate, unrelated types with no implicit conversion.
        XCTAssertFalse(wall is MonaHighResolutionClocking)
    }

    func testHighResolutionClockIsNotWall() {
        let high = MonaHighResolutionClock()
        // MonaHighResolutionClock must NOT conform to MonaWallClocking.
        XCTAssertFalse(high is MonaWallClocking)
    }

    func testDomainsAreUnrelatedProtocols() {
        // Each concrete clock conforms only to its own domain protocol, never
        // to the other. This is the runtime mirror of the compile-time
        // non-substitutability guarantee (separate, unrelated protocols with no
        // shared supertype).
        XCTAssertTrue(MonaWallClock() is MonaWallClocking)
        XCTAssertTrue(MonaHighResolutionClock() is MonaHighResolutionClocking)
        XCTAssertFalse(MonaWallClock() is MonaHighResolutionClocking)
        XCTAssertFalse(MonaHighResolutionClock() is MonaWallClocking)
    }

    // MARK: - Domain classification (no substitution)

    func testWallAndHighResolutionProduceDistinctValueClasses() {
        // Wall-clock ms (epoch-relative, ~1.78e12 in 2026) and high-resolution
        // uptime ms (boot-relative, typically orders of magnitude smaller) are
        // numerically disjoint in practice, demonstrating that the two domains
        // classify timing occurrences without substituting one for another.
        let wall = MonaWallClock().wallMilliseconds()
        let high = MonaHighResolutionClock().highResolutionMilliseconds()

        // Wall-clock is epoch-relative (>> 1e12); high-resolution is
        // boot-relative (must be < wall — no system boots before 1970 with
        // uptime exceeding the epoch count).
        XCTAssertGreaterThan(wall, 1.0e12)
        XCTAssertLessThan(high, wall)
    }
}
