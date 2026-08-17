// DisplayModeEnforcer.swift
//
// P00-T010 — Enforce font provenance, cold launch, display isolation, and refresh cells.
//
// `DisplayModeEnforcer` locks every measurement block to the built-in display
// and one exact refresh cell (60.0 or 120.0 Hz). 59.94 Hz is NOT folded to
// 60.0. 60 Hz and 120 Hz cells are never mixed within a block. The relative
// no-regression threshold is identical across both rates; only the presentation
// deadlines differ (120 Hz covers 60 Hz but has a strictly shorter deadline).
//
// Q1-R4 environment/font/cold closure (verification-q1r4-environment-font-cold-closure):
//   - Display: built-in only; session-local slot; connection, logical frame,
//     pixel dimensions, backingScale, refresh EXACT, maxFPS, ICC bytes SHA-256,
//     EDR values. A mode/screen change mid-block invalidates the measurement.
//   - 60.0 and 120.0 are never mixed; 59.94 is not rounded to 60.
//   - 120 Hz covers 60 Hz: presentation deadline, missed-frame, and merge
//     behavior differ → separate verdicts. The relative no-regression threshold
//     is unchanged across both rates.
//
// MonaCode is a Foundation-only boundary: `import Foundation` is the sole
// import. This file lives in the `benchmark-harness` non-product target.

import Foundation

// MARK: - DisplayMode

/// One observed display mode at measurement time. The enforcer requires
/// `isBuiltIn == true`, an exact refresh rate of 60.0 or 120.0, and that every
/// sample within a block shares the same display identity (`sessionSlot` +
/// `iccHash`).
public struct DisplayMode: Equatable, Sendable {
    /// `true` iff this is the built-in Retina display. External displays are
    /// rejected.
    public let isBuiltIn: Bool
    /// The session-local display slot (e.g. `"built-in-0"`). Persistent display
    /// identifiers are intentionally not stored.
    public let sessionSlot: String
    /// The exact refresh rate in Hz. Only 60.0 and 120.0 are valid; 59.94 is
    /// not folded to 60.0.
    public let refreshRateHz: Double
    /// Hex SHA-256 of the ICC profile bytes. A change mid-block invalidates.
    public let iccHash: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let backingScale: Double

    public init(
        isBuiltIn: Bool,
        sessionSlot: String,
        refreshRateHz: Double,
        iccHash: String,
        pixelWidth: Int,
        pixelHeight: Int,
        backingScale: Double
    ) {
        self.isBuiltIn = isBuiltIn
        self.sessionSlot = sessionSlot
        self.refreshRateHz = refreshRateHz
        self.iccHash = iccHash
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.backingScale = backingScale
    }

    /// The display identity used to detect a mode/screen change mid-block. Two
    /// samples with different identities within one block invalidate it.
    public var identityKey: String {
        return sessionSlot + "\u{0}" + iccHash + "\u{0}" + "\(isBuiltIn)"
    }
}

// MARK: - DisplayModeError

/// Errors raised while enforcing display isolation and refresh-cell locking.
public enum DisplayModeError: Error, Equatable, Sendable {
    /// A non-built-in (external) display was observed.
    case externalDisplay
    /// The refresh rate was not exactly 60.0 or 120.0 (e.g. 59.94).
    case refreshRateNotExact60Or120(actual: Double)
    /// The display mode or screen changed mid-block.
    case modeChange
    /// A sample's refresh rate did not match the block's declared refresh cell.
    case refreshRateMixedInBlock(found: Double, expected: Double)
}

// MARK: - DisplayModeEnforcer

/// Locks every measurement block to the built-in display and one exact refresh
/// cell, keeping 60 Hz and 120 Hz deadlines separate without changing the
/// relative no-regression threshold.
public final class DisplayModeEnforcer {

    /// The exact refresh rates that form valid refresh cells. 59.94 is
    /// deliberately absent — it is not folded to 60.0.
    public static let exactRefreshRates: Set<Double> = [60.0, 120.0]

    /// The relative no-regression threshold, identical for 60 Hz and 120 Hz.
    /// Only the absolute deadlines differ; the relative threshold is unchanged
    /// across rates (Q1-R4: 120 Hz covers 60 Hz but the relative no-regression
    /// bar does not move).
    public static let relativeNoRegressionThreshold: Double = 0.05

    public init() {}

    // MARK: - Single-display validation

    /// Validates a single observed display mode: built-in only, exact refresh
    /// rate (60.0 or 120.0). Throws on the first violation.
    public func validateDisplay(_ mode: DisplayMode) throws {
        guard mode.isBuiltIn else {
            throw DisplayModeError.externalDisplay
        }
        guard Self.exactRefreshRates.contains(mode.refreshRateHz) else {
            throw DisplayModeError.refreshRateNotExact60Or120(actual: mode.refreshRateHz)
        }
    }

    // MARK: - Block locking

    /// Locks a measurement block to one exact refresh cell. Every sample must:
    ///   1. pass single-display validation (built-in, exact rate),
    ///   2. match the block's declared refresh rate exactly (no 60/120 mixing),
    ///   3. share the same display identity as the first sample (no mode/screen
    ///      change mid-block).
    public func lockBlock(
        refreshRate: BenchmarkRefreshRate,
        samples: [DisplayMode]
    ) throws {
        let expectedHz = Self.hertz(for: refreshRate)
        var baselineIdentity: String? = nil
        for sample in samples {
            try validateDisplay(sample)
            if sample.refreshRateHz != expectedHz {
                throw DisplayModeError.refreshRateMixedInBlock(
                    found: sample.refreshRateHz, expected: expectedHz)
            }
            if let baseline = baselineIdentity {
                if sample.identityKey != baseline {
                    throw DisplayModeError.modeChange
                }
            } else {
                baselineIdentity = sample.identityKey
            }
        }
    }

    // MARK: - Deadlines and thresholds

    /// The presentation deadline for one refresh cell, in milliseconds. 120 Hz
    /// has a strictly shorter deadline than 60 Hz. The two deadlines are kept
    /// separate: a 60 Hz block never borrows the 120 Hz deadline or vice versa.
    public func deadline(for rate: BenchmarkRefreshRate) -> Double {
        let hz = Self.hertz(for: rate)
        // Frame budget: 1000 ms / refresh rate.
        return 1000.0 / hz
    }

    /// The relative no-regression threshold for one refresh cell. Identical for
    /// 60 Hz and 120 Hz — keeping deadlines separate WITHOUT changing the
    /// relative no-regression threshold.
    public func relativeThreshold(for rate: BenchmarkRefreshRate) -> Double {
        return Self.relativeNoRegressionThreshold
    }

    // MARK: - Internal

    /// Maps a refresh-rate cell axis to its exact Hz value.
    static func hertz(for rate: BenchmarkRefreshRate) -> Double {
        switch rate {
        case .hz60: return 60.0
        case .hz120: return 120.0
        }
    }
}
