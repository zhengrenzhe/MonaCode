// MonaNumberToString.swift
//
// P00-T006 — Implement deterministic random, cryptographic random, and
// Number-to-string sources.
//
// Finite, bounded-precision conversion of binary64 (`Double`) to radix-10 and
// radix-16 strings. Both conversions always terminate — there is no unbounded
// digit emission — and both produce canonical lowercase output.
//
//   - `radix10` uses Swift's shortest round-trippable decimal representation
//     (via `String(value)`), which is finite and bounded.
//   - `radix16` produces the canonical lowercase IEEE 754 hex-float form
//     `0x1.<hex>p<exp>` (or `0x0p+0` for zero), built directly from the binary64
//     bit pattern with trailing fractional zeros trimmed. This is always finite
//     (at most 13 hex digits) and unambiguously represents every binary64
//     value.
//
// Special values (NaN, ±Infinity) are mapped to the canonical identifiers
// "NaN", "Infinity", "-Infinity" for both radixes, matching the JavaScript
// `Number.prototype.toString` convention used by the Monaco reference.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Finite radix-10 and radix-16 conversion of binary64 values to strings.
///
/// Both conversions always terminate with bounded precision and produce
/// canonical lowercase output. The type is stateless; create instances freely.
public struct MonaNumberToString {

    public init() {}

    /// Converts `value` to its shortest round-trippable decimal string.
    ///
    /// Finite and bounded: Swift's `String(_:)` for `Double` emits the shortest
    /// decimal that round-trips to the same binary64, which always terminates.
    ///
    /// Special values:
    ///   - NaN → `"NaN"`
    ///   - +Infinity → `"Infinity"`
    ///   - -Infinity → `"-Infinity"`
    public func radix10(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
        return String(value)
    }

    /// Converts `value` to its canonical lowercase IEEE 754 hex-float string.
    ///
    /// The result has the form `0x1.<hex-digits>p<exp>` (with trailing zeros
    /// trimmed, and the fractional part omitted entirely when there are no
    /// significant digits), or `0x0p+0` for zero. Negative values are prefixed
    /// with `-`.
    ///
    /// Finite and bounded: the fractional part is at most 13 hex digits (52
    /// bits of mantissa), and the algorithm never emits more digits than the
    /// binary64 mantissa can hold.
    ///
    /// Special values:
    ///   - NaN → `"NaN"`
    ///   - +Infinity → `"Infinity"`
    ///   - -Infinity → `"-Infinity"`
    public func radix16(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
        if value == 0 {
            return value.sign == .minus ? "-0x0p+0" : "0x0p+0"
        }

        let bits = value.bitPattern
        let negative = (bits & (UInt64(1) << 63)) != 0
        let biasedExp = Int((bits >> 52) & 0x7FF)
        let rawMantissa = bits & ((UInt64(1) << 52) - 1)

        var exponent: Int
        var mantissa: UInt64  // 52-bit fractional mantissa (implicit bit removed)

        if biasedExp == 0 {
            // Subnormal: normalize so the leading 1 sits at bit 52.
            mantissa = rawMantissa
            exponent = -1022
            while mantissa < (UInt64(1) << 52) {
                mantissa <<= 1
                exponent -= 1
            }
            mantissa &= (UInt64(1) << 52) - 1  // drop the implicit leading 1
        } else {
            exponent = biasedExp - 1023
            mantissa = rawMantissa
        }

        // Convert the 52-bit fractional mantissa to 13 hex digits (MSB first),
        // then trim trailing zeros for the canonical form.
        let hexChars: [Character] = [
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
            "a", "b", "c", "d", "e", "f",
        ]
        var digits: [Character] = []
        digits.reserveCapacity(13)
        for i in 0..<13 {
            let shift = 48 - (i * 4)  // 48, 44, ..., 0
            let nibble = Int((mantissa >> shift) & 0xF)
            digits.append(hexChars[nibble])
        }
        while let last = digits.last, last == "0" {
            digits.removeLast()
        }

        let sign = negative ? "-" : ""
        let mantissaPart = digits.isEmpty ? "" : "." + String(digits)
        let expPart = exponent >= 0 ? "p+\(exponent)" : "p\(exponent)"
        return "\(sign)0x1\(mantissaPart)\(expPart)"
    }
}
