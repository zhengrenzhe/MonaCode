// MonaFiniteIntrinsicTests.swift
//
// P02-T008 — Implement finite ECMAScript intrinsics, codecs, and String SHA-1.
//
// Verifies the four Phase-02 runtime leaves closed by X1-R:
//   - `MonaFiniteIntrinsics`: the exact finite intrinsic profile (12 categories,
//     X1-R reference counts). Unsupported operations are rejected with a typed
//     `MonaFiniteIntrinsicError.unsupportedOperation`.
//   - `MonaBinary64`: binary64 (Double) rounding (floor, ceil, round, trunc),
//     signed zero (+0 / -0), and NaN classification (isNaN, isFinite,
//     isInfinite). Faithful to ECMAScript Number semantics.
//   - `MonaTextCodec`: UTF-8 encoding/decoding over raw `[UInt16]`. Encoding
//     converts lone surrogates to U+FFFD; decoding replaces malformed sequences
//     with U+FFFD (graceful, never crashes).
//   - `MonaStringSHA1`: SHA-1 over the UTF-16 code units of a string (the input
//     units are converted to a UTF-8 byte stream, including lone-surrogate
//     replacement, and a high surrogate split across update calls is rejoined).
//     Matches the pinned Chrome 151 vectors from X1-R. Pure Swift — no
//     CryptoKit.
//
// On Green, `testContractLeaf` prints the contract line:
//     INTRINSICS categories=12 binary64=pass codec=pass sha1=pass

import XCTest
import MonaCode

final class MonaFiniteIntrinsicTests: XCTestCase {

    // MARK: - MonaFiniteIntrinsics

    /// The exact 12 X1-R intrinsic categories form a closed, finite set.
    func testFiniteIntrinsicCategoriesMatchX1R() {
        let categories = MonaFiniteIntrinsics.categories
        XCTAssertEqual(categories.count, 12, "X1-R lists exactly 12 intrinsic categories")

        // Every category carries its X1-R reference count.
        let expected: [MonaFiniteIntrinsicCategory: Int] = [
            .array: 250, .object: 638, .reflect: 618, .map: 230, .set: 176,
            .promise: 192, .math: 1099, .number: 107, .string: 131,
            .json: 73, .regexp: 74, .symbol: 39
        ]
        for (cat, count) in expected {
            XCTAssertEqual(cat.referenceCount, count,
                           "\(cat.rawValue) reference count must match X1-R")
            XCTAssertTrue(MonaFiniteIntrinsics.contains(cat),
                          "\(cat.rawValue) must be in the finite profile")
        }
    }

    /// Supported operations within the finite profile are performed.
    func testFiniteIntrinsicsPerformSupportedOperations() throws {
        XCTAssertNoThrow(try MonaFiniteIntrinsics.perform(.math, "floor"))
        XCTAssertNoThrow(try MonaFiniteIntrinsics.perform(.number, "parseInt"))
        XCTAssertNoThrow(try MonaFiniteIntrinsics.perform(.string, "slice"))
        XCTAssertNoThrow(try MonaFiniteIntrinsics.perform(.json, "parse"))
        XCTAssertNoThrow(try MonaFiniteIntrinsics.perform(.array, "push"))

        XCTAssertTrue(MonaFiniteIntrinsics.supports(.math, "floor"))
        XCTAssertTrue(MonaFiniteIntrinsics.supports(.json, "stringify"))
        XCTAssertFalse(MonaFiniteIntrinsics.supports(.math, "eval"),
                       "eval is never in the finite profile")
    }

    /// Operations outside the finite profile are rejected with a typed error.
    func testFiniteIntrinsicsRejectUnsupportedOperations() {
        XCTAssertThrowsError(try MonaFiniteIntrinsics.perform(.math, "eval")) { err in
            guard case .unsupportedOperation(let op) = err as? MonaFiniteIntrinsicError else {
                XCTFail("expected unsupportedOperation, got \(err)")
                return
            }
            XCTAssertTrue(op.contains("math"), "error should name the category")
            XCTAssertTrue(op.contains("eval"), "error should name the operation")
        }

        XCTAssertThrowsError(try MonaFiniteIntrinsics.perform(.math, "Function")) { err in
            XCTAssertEqual(err as? MonaFiniteIntrinsicError, .unsupportedOperation("math.Function"))
        }
    }

    /// The perform(_:operation:_:) body executes only when the operation is
    /// supported, and is skipped (rejected) otherwise.
    func testFiniteIntrinsicsGuardedBodyExecution() throws {
        var ran = false
        let result = try MonaFiniteIntrinsics.perform(.math, "abs") {
            ran = true
            return 42
        }
        XCTAssertTrue(ran)
        XCTAssertEqual(result, 42)

        var skipped = true
        XCTAssertThrowsError(
            try MonaFiniteIntrinsics.perform(.math, "dangerous") { skipped = false }
        ) { _ in }
        XCTAssertTrue(skipped, "body must not run for unsupported operations")
    }

    // MARK: - MonaBinary64

    /// ECMAScript Math rounding: floor rounds toward -Infinity.
    func testBinary64Floor() {
        XCTAssertEqual(MonaBinary64.floor(2.7), 2.0)
        XCTAssertEqual(MonaBinary64.floor(-2.3), -3.0)
        XCTAssertEqual(MonaBinary64.floor(0.0), 0.0)
        XCTAssertEqual(MonaBinary64.floor(-0.0).sign, .minus, "floor(-0) preserves -0")
        XCTAssertTrue(MonaBinary64.floor(.nan).isNaN)
        XCTAssertTrue(MonaBinary64.floor(.infinity).isInfinite)
    }

    /// ECMAScript Math rounding: ceil rounds toward +Infinity.
    func testBinary64Ceil() {
        XCTAssertEqual(MonaBinary64.ceil(2.1), 3.0)
        XCTAssertEqual(MonaBinary64.ceil(-2.9), -2.0)
        XCTAssertEqual(MonaBinary64.ceil(0.0), 0.0)
        XCTAssertTrue(MonaBinary64.ceil(.nan).isNaN)
        XCTAssertTrue(MonaBinary64.ceil(.infinity).isInfinite)
    }

    /// ECMAScript Math.round: round half toward +Infinity.
    func testBinary64Round() {
        XCTAssertEqual(MonaBinary64.round(0.5), 1.0)
        XCTAssertEqual(MonaBinary64.round(1.5), 2.0)
        XCTAssertEqual(MonaBinary64.round(2.5), 3.0)
        XCTAssertEqual(MonaBinary64.round(-0.5), 0.0,
                       "Math.round(-0.5) returns +0 in ECMAScript")
        XCTAssertEqual(MonaBinary64.round(-0.5).sign, .plus,
                       "Math.round(-0.5) returns +0, not -0")
        XCTAssertEqual(MonaBinary64.round(-1.5), -1.0,
                       "Math.round(-1.5) rounds toward +Infinity → -1")
        XCTAssertEqual(MonaBinary64.round(-2.5), -2.0)
        XCTAssertEqual(MonaBinary64.round(2.4), 2.0)
        XCTAssertEqual(MonaBinary64.round(-2.4), -2.0)
    }

    /// ECMAScript Math.trunc: round toward zero.
    func testBinary64Trunc() {
        XCTAssertEqual(MonaBinary64.trunc(2.9), 2.0)
        XCTAssertEqual(MonaBinary64.trunc(-2.9), -2.0)
        XCTAssertEqual(MonaBinary64.trunc(0.0), 0.0)
        XCTAssertTrue(MonaBinary64.trunc(.nan).isNaN)
    }

    /// Signed zero: +0 and -0 compare equal but are distinguishable.
    func testBinary64SignedZero() {
        XCTAssertEqual(MonaBinary64.positiveZero, 0.0)
        XCTAssertEqual(MonaBinary64.negativeZero, 0.0)
        XCTAssertEqual(MonaBinary64.positiveZero, MonaBinary64.negativeZero,
                       "+0 === -0 under IEEE 754 equality")
        XCTAssertTrue(MonaBinary64.isNegativeZero(MonaBinary64.negativeZero))
        XCTAssertFalse(MonaBinary64.isNegativeZero(MonaBinary64.positiveZero))
        XCTAssertTrue(MonaBinary64.isNegativeZero(-0.0))
        XCTAssertFalse(MonaBinary64.isNegativeZero(0.0))
        // 1/+0 = +Infinity, 1/-0 = -Infinity (distinguishes signed zero)
        XCTAssertEqual(1.0 / MonaBinary64.positiveZero, .infinity)
        XCTAssertEqual(1.0 / MonaBinary64.negativeZero, -.infinity)
    }

    /// NaN and infinity classification (ECMAScript Number.isNaN etc.).
    func testBinary64Classification() {
        XCTAssertTrue(MonaBinary64.isNaN(.nan))
        XCTAssertTrue(MonaBinary64.isNaN(-.nan))
        XCTAssertFalse(MonaBinary64.isNaN(0.0))
        XCTAssertFalse(MonaBinary64.isNaN(1.0))

        XCTAssertTrue(MonaBinary64.isInfinite(.infinity))
        XCTAssertTrue(MonaBinary64.isInfinite(-.infinity))
        XCTAssertFalse(MonaBinary64.isInfinite(1.0))
        XCTAssertFalse(MonaBinary64.isInfinite(.nan))

        XCTAssertTrue(MonaBinary64.isFinite(0.0))
        XCTAssertTrue(MonaBinary64.isFinite(42.0))
        XCTAssertFalse(MonaBinary64.isFinite(.infinity))
        XCTAssertFalse(MonaBinary64.isFinite(.nan))
    }

    /// ECMAScript Math.sign semantics.
    func testBinary64Sign() {
        XCTAssertEqual(MonaBinary64.sign(5.0), 1.0)
        XCTAssertEqual(MonaBinary64.sign(-5.0), -1.0)
        XCTAssertEqual(MonaBinary64.sign(0.0), 0.0)
        XCTAssertEqual(MonaBinary64.sign(-0.0).sign, .minus,
                       "Math.sign(-0) returns -0")
        XCTAssertTrue(MonaBinary64.sign(.nan).isNaN)
        XCTAssertEqual(MonaBinary64.sign(.infinity), 1.0)
        XCTAssertEqual(MonaBinary64.sign(-.infinity), -1.0)
    }

    // MARK: - MonaTextCodec

    /// UTF-8 encoding of ASCII and BMP code units.
    func testTextCodecEncodeASCII() {
        let bytes = MonaTextCodec.encodeUTF8([0x0041, 0x0042, 0x0043]) // "ABC"
        XCTAssertEqual(bytes, [0x41, 0x42, 0x43])
    }

    /// UTF-8 encoding of a supplementary character via surrogate pair.
    func testTextCodecEncodeSurrogatePair() {
        // U+1F4A9 (💩) = [D83D, DCA9] → F0 9F 92 A9
        let bytes = MonaTextCodec.encodeUTF8([0xD83D, 0xDCA9])
        XCTAssertEqual(bytes, [0xF0, 0x9F, 0x92, 0xA9])
    }

    /// UTF-8 encoding of lone surrogates produces U+FFFD (EF BF BD).
    func testTextCodecEncodeLoneSurrogate() {
        let lone = MonaTextCodec.encodeUTF8([0xD800])
        XCTAssertEqual(lone, [0xEF, 0xBF, 0xBD])
        let reversed = MonaTextCodec.encodeUTF8([0xDCA9, 0xD83D])
        XCTAssertEqual(reversed, [0xEF, 0xBF, 0xBD, 0xEF, 0xBF, 0xBD])
    }

    /// UTF-8 decoding of valid bytes.
    func testTextCodecDecodeValid() {
        let units = MonaTextCodec.decodeUTF8([0x41, 0x42, 0x43])
        XCTAssertEqual(units, [0x0041, 0x0042, 0x0043])
        // U+00E9 (é) → C3 A9
        let units2 = MonaTextCodec.decodeUTF8([0xC3, 0xA9])
        XCTAssertEqual(units2, [0x00E9])
    }

    /// UTF-8 decoding of a supplementary character (4-byte) yields a surrogate
    /// pair in UTF-16.
    func testTextCodecDecodeSupplementary() {
        // U+1F600 (😀): F0 9F 98 80 → [D83D, DE00]
        let units = MonaTextCodec.decodeUTF8([0xF0, 0x9F, 0x98, 0x80])
        XCTAssertEqual(units, [0xD83D, 0xDE00])
    }

    /// UTF-8 decoding of malformed sequences yields U+FFFD (graceful, no crash).
    func testTextCodecDecodeMalformed() {
        // Lone continuation byte → U+FFFD
        XCTAssertEqual(MonaTextCodec.decodeUTF8([0x80]), [0xFFFD])
        // Truncated 2-byte sequence → U+FFFD
        XCTAssertEqual(MonaTextCodec.decodeUTF8([0xC3]), [0xFFFD])
        // Truncated 4-byte sequence → U+FFFD
        XCTAssertEqual(MonaTextCodec.decodeUTF8([0xF0, 0x9F, 0x98]), [0xFFFD])
        // Overlong encoding (C0 80) → U+FFFD
        XCTAssertEqual(MonaTextCodec.decodeUTF8([0xC0, 0x80]), [0xFFFD, 0xFFFD])
        // Empty input
        XCTAssertEqual(MonaTextCodec.decodeUTF8([]), [])
    }

    /// Round-trip: encode then decode preserves valid text.
    func testTextCodecRoundTrip() {
        let original: [UInt16] = [0x0048, 0x0065, 0x006C, 0x006C, 0x006F] // "Hello"
        let encoded = MonaTextCodec.encodeUTF8(original)
        let decoded = MonaTextCodec.decodeUTF8(encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - MonaStringSHA1

    /// SHA-1 of empty input (standard empty-string hash).
    func testSHA1Empty() {
        XCTAssertEqual(
            MonaStringSHA1.hash([]),
            "da39a3ee5e6b4b0d3255bfef95601890afd80709"
        )
    }

    /// SHA-1 of a lone high surrogate (U+FFFD replacement in the UTF-8 stream).
    func testSHA1LoneHighSurrogate() {
        XCTAssertEqual(
            MonaStringSHA1.hash([0xD800]),
            "9bdb77276c1852e1fb067820472812fcf6084024"
        )
    }

    /// SHA-1 of a valid surrogate pair (U+1F600).
    func testSHA1ValidSurrogatePair() {
        XCTAssertEqual(
            MonaStringSHA1.hash([0xD83D, 0xDCA9]),
            "82ab1e5bf66129bdbb3d5477dfe48bfcb2545cbd"
        )
    }

    /// SHA-1 of a reversed surrogate pair (two lone surrogates → two U+FFFD).
    func testSHA1ReversedSurrogatePair() {
        XCTAssertEqual(
            MonaStringSHA1.hash([0xDCA9, 0xD83D]),
            "8750ec9ddfe293cd1dc39b4245c21c270f8f52b7"
        )
    }

    /// SHA-1 of BOM + A (U+FEFF is NOT stripped — included in the hash stream).
    func testSHA1BOMAndA() {
        XCTAssertEqual(
            MonaStringSHA1.hash([0xFEFF, 0x0041]),
            "3a61e1ebace0447cb4a49ceb642e627cf3643b3e"
        )
    }

    /// SHA-1 of plain ASCII text matches the standard SHA-1.
    func testSHA1Ascii() {
        // SHA-1("abc") = a9993e364706816aba3e25717850c26c9cd0d89d
        XCTAssertEqual(
            MonaStringSHA1.hash([0x0061, 0x0062, 0x0063]),
            "a9993e364706816aba3e25717850c26c9cd0d89d"
        )
    }

    /// A high surrogate split across two update calls equals the whole-pair
    /// hash (X1-R splitSurrogateSha1 vector).
    func testSHA1SplitSurrogateAcrossUpdates() {
        var hasher = MonaStringSHA1.Hasher()
        hasher.update([0xD83D])       // high surrogate at end of first chunk
        hasher.update([0xDCA9])       // low surrogate at start of second chunk
        XCTAssertEqual(
            hasher.finalize(),
            "82ab1e5bf66129bdbb3d5477dfe48bfcb2545cbd"
        )
    }

    /// Streaming update then finalize equals one-shot hash for whole input.
    func testSHA1StreamingEqualsOneShot() {
        let units: [UInt16] = [0x0048, 0x0065, 0x006C, 0x006C, 0x006F] // "Hello"
        var hasher = MonaStringSHA1.Hasher()
        hasher.update(Array(units.prefix(2)))
        hasher.update(Array(units.dropFirst(2)))
        XCTAssertEqual(hasher.finalize(), MonaStringSHA1.hash(units))
    }

    // MARK: - Contract leaf

    /// Contract leaf: prints the G6-R Phase-02 P02-T008 acceptance line.
    func testContractLeaf() {
        let cats = MonaFiniteIntrinsics.categories.count
        let binary64Pass = MonaBinary64.round(-0.5) == 0.0 && MonaBinary64.round(-0.5).sign == .plus
        let codecPass = MonaTextCodec.encodeUTF8([0xD800]) == [0xEF, 0xBF, 0xBD]
        let sha1Pass = MonaStringSHA1.hash([0xD83D, 0xDCA9]) == "82ab1e5bf66129bdbb3d5477dfe48bfcb2545cbd"
        XCTAssertTrue(binary64Pass, "binary64 must round -0.5 to +0")
        XCTAssertTrue(codecPass, "codec must encode lone surrogate to U+FFFD")
        XCTAssertTrue(sha1Pass, "sha1 must match the X1-R surrogate-pair vector")
        print("INTRINSICS categories=\(cats) binary64=\(binary64Pass ? "pass" : "fail") codec=\(codecPass ? "pass" : "fail") sha1=\(sha1Pass ? "pass" : "fail")")
    }
}
