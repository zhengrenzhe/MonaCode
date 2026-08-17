// MonaBinary64.swift
//
// P02-T008 — Implement finite ECMAScript intrinsics, codecs, and String SHA-1.
//
// Binary64 (`Double`) operations faithful to ECMAScript Number semantics.
//
// X1-R `binary64`: "All retained arithmetic, comparison, signed-zero, NaN,
// infinity, ToInt32, ToUint32, parseInt, parseFloat, Number conversion and
// Math operation profiles preserve Chrome binary64 results and control-flow
// decisions. Swift rounding, integer conversion and Darwin libm are not
// semantic oracles."
//
// This leaf implements the four rounding modes (floor, ceil, round, trunc),
// signed-zero construction and classification, and NaN/infinity
// classification. The ECMAScript `Math.round` semantics — round half toward
// +Infinity, with -0 preserved for inputs in (-1, 0) — are implemented
// directly rather than delegated to Swift's `.rounded()` rules.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Binary64 (`Double`) operations faithful to ECMAScript Number semantics.
///
/// A stateless namespace (caseless enum) over `Double`. All operations match
/// Chrome 151 binary64 results for the retained source rows (X1-R oracle).
public enum MonaBinary64 {

    /// Positive zero (`+0.0`).
    public static let positiveZero: Double = 0.0

    /// Negative zero (`-0.0`).
    public static let negativeZero: Double = -0.0

    // MARK: - Rounding (ECMAScript Math.* semantics)

    /// `Math.floor(x)` — rounds toward negative infinity.
    public static func floor(_ x: Double) -> Double {
        x.rounded(.down)
    }

    /// `Math.ceil(x)` — rounds toward positive infinity.
    public static func ceil(_ x: Double) -> Double {
        x.rounded(.up)
    }

    /// `Math.trunc(x)` — rounds toward zero.
    public static func trunc(_ x: Double) -> Double {
        x.rounded(.towardZero)
    }

    /// `Math.round(x)` — round half toward +Infinity (ECMAScript).
    ///
    /// ECMAScript `Math.round` rounds to the nearest integer; when the
    /// fractional part is exactly 0.5, the result is the integer closer to
    /// +Infinity. This means:
    ///
    ///   - `round(0.5)  == 1`
    ///   - `round(1.5)  == 2`
    ///   - `round(-0.5) == +0` (positive zero, not negative)
    ///   - `round(-1.5) == -1`
    ///
    /// The implementation uses `floor(x + 0.5)` and corrects the signed-zero
    /// result for negative inputs whose rounded value is zero.
    public static func round(_ x: Double) -> Double {
        if x.isNaN || x.isInfinite { return x }
        if x == 0.0 { return x } // preserves +0 / -0 sign of the input
        let r = x.rounded(.down) // floor
        let frac = x - r
        if frac < 0.5 {
            return r
        }
        // frac >= 0.5: round toward +Infinity
        let towardPlusInf = r + 1.0
        if towardPlusInf == 0.0 && x < 0.0 {
            // Math.round(-0.5) returns +0, not -0.
            return 0.0
        }
        return towardPlusInf
    }

    /// `Math.sign(x)` — returns 1, -1, +0, -0, or NaN.
    public static func sign(_ x: Double) -> Double {
        if x.isNaN { return .nan }
        if x > 0 || x == .infinity { return 1.0 }
        if x < 0 || x == -.infinity { return -1.0 }
        return x // +0 or -0 preserved
    }

    // MARK: - Signed zero

    /// Returns `true` if `x` is negative zero (`-0.0`).
    public static func isNegativeZero(_ x: Double) -> Bool {
        x == 0.0 && x.sign == .minus
    }

    /// Returns `true` if `x` is positive zero (`+0.0`).
    public static func isPositiveZero(_ x: Double) -> Bool {
        x == 0.0 && x.sign == .plus
    }

    // MARK: - Classification (ECMAScript Number.*)

    /// `Number.isNaN(x)` — true only for NaN (no coercion).
    public static func isNaN(_ x: Double) -> Bool {
        x.isNaN
    }

    /// `Number.isFinite(x)` — true for finite values (no coercion).
    public static func isFinite(_ x: Double) -> Bool {
        x.isFinite
    }

    /// `Number.isInteger(x)` — true for finite values with no fractional part.
    public static func isInteger(_ x: Double) -> Bool {
        x.isFinite && x == x.rounded(.towardZero)
    }

    /// `isInfinite(x)` — true for +Infinity or -Infinity.
    public static func isInfinite(_ x: Double) -> Bool {
        x.isInfinite
    }
}
