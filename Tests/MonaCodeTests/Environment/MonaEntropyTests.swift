// MonaEntropyTests.swift
//
// P00-T006 — Implement deterministic random, cryptographic random, and
// Number-to-string sources.
//
// Verifies:
//   - `MonaRandomDoubleSource` — injectable shared random sequence producing
//     `Double` in [0,1).
//   - `MonaCryptoRandomSource` — cryptographic random (via /dev/urandom),
//     produces UUID v4 (canonical lowercase).
//   - `MonaNumberToString` — finite radix-10 + radix-16 conversion (canonical
//     lowercase hex).

import XCTest
import MonaCode

final class MonaEntropyTests: XCTestCase {

    // MARK: - MonaRandomDoubleSource

    func testRandomDoubleSourceProtocolIsInjectable() {
        // The protocol admits any conformer; the default impl is injectable
        // through the existential.
        let source: any MonaRandomDoubleSource = MonaSystemRandomDoubleSource()
        let v = source.nextDouble()
        let _: Double = v
        XCTAssertTrue(v.isFinite)
    }

    func testRandomDoubleProducesValuesInHalfOpenUnitInterval() {
        let source = MonaSystemRandomDoubleSource()
        for _ in 0..<2000 {
            let v = source.nextDouble()
            XCTAssertGreaterThanOrEqual(v, 0.0, "nextDouble must be >= 0.0")
            XCTAssertLessThan(v, 1.0, "nextDouble must be < 1.0")
        }
    }

    func testRandomDoubleSharedInstanceAdvancesSequence() {
        // A shared instance is the injected shared random sequence: successive
        // draws produce independent values.
        let source = MonaSystemRandomDoubleSource()
        var seen = Set<Double>()
        for _ in 0..<100 {
            seen.insert(source.nextDouble())
        }
        XCTAssertGreaterThan(seen.count, 1, "shared source must produce >1 distinct value")
    }

    func testRandomDoubleIsInjectableForDeterminism() {
        // Test determinism: a fixed-source conformer reproduces the injected
        // sequence exactly, and wraps around.
        let source = MonaFixedRandomDoubleSource(values: [0.0, 0.25, 0.5, 0.75])
        XCTAssertEqual(source.nextDouble(), 0.0)
        XCTAssertEqual(source.nextDouble(), 0.25)
        XCTAssertEqual(source.nextDouble(), 0.5)
        XCTAssertEqual(source.nextDouble(), 0.75)
        // Wraps around for a 5th draw.
        XCTAssertEqual(source.nextDouble(), 0.0)
    }

    // MARK: - MonaCryptoRandomSource

    func testCryptoRandomSourceProtocolIsInjectable() {
        let source: any MonaCryptoRandomSource = MonaSystemCryptoRandomSource()
        let bytes = source.nextBytes(count: 32)
        XCTAssertEqual(bytes.count, 32)
    }

    func testCryptoRandomProducesRequestedByteCounts() {
        let source = MonaSystemCryptoRandomSource()
        for count in [0, 1, 8, 16, 31, 32, 64, 100, 256] {
            XCTAssertEqual(source.nextBytes(count: count).count, count,
                          "nextBytes(count: \(count)) returned wrong count")
        }
    }

    func testCryptoRandomBytesAreNotAllZero() {
        let source = MonaSystemCryptoRandomSource()
        let bytes = source.nextBytes(count: 64)
        let nonZero = bytes.filter { $0 != 0 }
        XCTAssertGreaterThan(nonZero.count, 0, "crypto bytes must not be all zero")
    }

    func testCryptoRandomUUIDv4IsCanonicalLowercaseFormat() {
        let source = MonaSystemCryptoRandomSource()
        for _ in 0..<100 {
            let uuid = source.makeUUIDv4()
            // Canonical lowercase UUID v4: 8-4-4-4-12, version nibble = 4,
            // variant = 8/9/a/b.
            let pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
            let regex = try! NSRegularExpression(pattern: pattern)
            let range = NSRange(uuid.startIndex..., in: uuid)
            XCTAssertNotNil(regex.firstMatch(in: uuid, range: range),
                            "UUID \(uuid) is not canonical lowercase v4")
        }
    }

    func testCryptoRandomUUIDv4FromFixedBytesAllZero() {
        // 16 zero bytes → after version/variant fixup → canonical UUID.
        let bytes = [UInt8](repeating: 0, count: 16)
        let uuid = MonaCryptoRandomFormatter.uuidv4(from: bytes)
        // version nibble = 4, variant bits = 10 → 0x8
        XCTAssertEqual(uuid, "00000000-0000-4000-8000-000000000000")
    }

    func testCryptoRandomUUIDv4FromFixedBytesAllFF() {
        let bytes = [UInt8](repeating: 0xFF, count: 16)
        let uuid = MonaCryptoRandomFormatter.uuidv4(from: bytes)
        // byte[6] = 0xFF & 0x0F | 0x40 = 0x4F → "4f"
        // byte[8] = 0xFF & 0x3F | 0x80 = 0xBF → "bf"
        XCTAssertEqual(uuid, "ffffffff-ffff-4fff-bfff-ffffffffffff")
    }

    func testCryptoRandomFormatterIsLowercase() {
        // Verify canonical lowercase output from arbitrary bytes.
        let bytes: [UInt8] = [0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89,
                              0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89]
        let uuid = MonaCryptoRandomFormatter.uuidv4(from: bytes)
        // byte[6] = 0x67 & 0x0F | 0x40 = 0x47
        // byte[8] = 0xAB & 0x3F | 0x80 = 0xAB
        XCTAssertEqual(uuid, "abcdef01-2345-4789-abcd-ef0123456789")
    }

    // MARK: - MonaNumberToString — radix10

    func testNumberToStringRadix10Basic() {
        let conv = MonaNumberToString()
        XCTAssertEqual(conv.radix10(0.0), "0.0")
        XCTAssertEqual(conv.radix10(1.0), "1.0")
        XCTAssertEqual(conv.radix10(-1.0), "-1.0")
        XCTAssertEqual(conv.radix10(12.5), "12.5")
        XCTAssertEqual(conv.radix10(100.0), "100.0")
    }

    func testNumberToStringRadix10ShortestRoundTrippable() {
        let conv = MonaNumberToString()
        // 0.1 in binary64 round-trips to "0.1" (shortest representation).
        XCTAssertEqual(conv.radix10(0.1), "0.1")
        XCTAssertEqual(conv.radix10(0.2), "0.2")
        XCTAssertEqual(conv.radix10(0.3), "0.3")
    }

    func testNumberToStringRadix10SpecialValues() {
        let conv = MonaNumberToString()
        XCTAssertEqual(conv.radix10(Double.nan), "NaN")
        XCTAssertEqual(conv.radix10(Double.infinity), "Infinity")
        XCTAssertEqual(conv.radix10(-Double.infinity), "-Infinity")
    }

    func testNumberToStringRadix10FiniteTermination() {
        // 1.0/3.0 has an infinite decimal expansion; conversion must terminate.
        let conv = MonaNumberToString()
        let _ = conv.radix10(1.0 / 3.0)
        XCTAssertTrue(true)  // reached → finite
    }

    // MARK: - MonaNumberToString — radix16

    func testNumberToStringRadix16CanonicalLowercase() {
        let conv = MonaNumberToString()
        XCTAssertEqual(conv.radix16(0.0), "0x0p+0")
        XCTAssertEqual(conv.radix16(1.0), "0x1p+0")
        XCTAssertEqual(conv.radix16(12.5), "0x1.9p+3")
        XCTAssertEqual(conv.radix16(2.0), "0x1p+1")
    }

    func testNumberToStringRadix16IsLowercase() {
        let conv = MonaNumberToString()
        let s = conv.radix16(0.1)
        // Must not contain uppercase A-F (the 'x' in '0x' and 'p' are lowercase).
        XCTAssertFalse(s.contains("A"))
        XCTAssertFalse(s.contains("B"))
        XCTAssertFalse(s.contains("C"))
        XCTAssertFalse(s.contains("D"))
        XCTAssertFalse(s.contains("E"))
        XCTAssertFalse(s.contains("F"))
    }

    func testNumberToStringRadix16SpecialValues() {
        let conv = MonaNumberToString()
        XCTAssertEqual(conv.radix16(Double.nan), "NaN")
        XCTAssertEqual(conv.radix16(Double.infinity), "Infinity")
        XCTAssertEqual(conv.radix16(-Double.infinity), "-Infinity")
    }

    func testNumberToStringRadix16FiniteTermination() {
        // 1.0/3.0 has an infinite hex expansion; conversion must terminate.
        let conv = MonaNumberToString()
        let _ = conv.radix16(1.0 / 3.0)
        XCTAssertTrue(true)
    }
}

// MARK: - Test-only deterministic source

/// Test-only fixed-sequence conformer to `MonaRandomDoubleSource` for
/// deterministic verification of the injectable shared random sequence.
final class MonaFixedRandomDoubleSource: MonaRandomDoubleSource {
    private let values: [Double]
    private var index = 0

    init(values: [Double]) {
        precondition(!values.isEmpty, "fixed source requires at least one value")
        self.values = values
    }

    func nextDouble() -> Double {
        let v = values[index % values.count]
        index += 1
        return v
    }
}
