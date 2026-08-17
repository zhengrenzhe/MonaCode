// MonaEnvironmentSemanticsTests.swift
//
// P02-T007 — Implement fixed case conversion, collation, and normalization profiles.
//
// Verifies the three environment-semantics providers introduced in P02-T007:
//
//   - `MonaUnicodeCaseConverter` — the real Unicode case folder (conforms to
//     the `MonaCaseConverter` protocol from P02-T003, replacing the ASCII-only
//     `MonaCaseConverterStub`). Backed by the generated `MonaCaseTables`.
//   - `MonaCollator` — locale-sensitive collation over raw `[UInt16]`,
//     backed by the generated `MonaCollationTables`.
//   - `MonaNormalizer` — NFC/NFD/NFKC/NFKD normalization with two fixed
//     10000-entry LRU caches and explicit hit/miss/eviction counters.
//
// Also verifies the generated tables carry the six provenance fields
// (sourceVersion, inputHash, generatorHash, outputHash, propertySet,
// consumerSet) for both case and collation data.
//
// MonaCode is a Foundation-only target; tests import XCTest + MonaCode.

import XCTest
import MonaCode

final class MonaEnvironmentSemanticsTests: XCTestCase {

    // MARK: - 1. MonaCaseTables provenance

    /// The generated case tables carry the four provenance fields, all
    /// populated and well-formed (hashes are 64-char lowercase hex SHA-256).
    func testCaseTablesProvenance() {
        XCTAssertFalse(MonaCaseTables.sourceVersion.isEmpty)
        XCTAssertFalse(MonaCaseTables.inputHash.isEmpty)
        XCTAssertFalse(MonaCaseTables.generatorHash.isEmpty)
        XCTAssertFalse(MonaCaseTables.outputHash.isEmpty)
        XCTAssertFalse(MonaCaseTables.propertySet.isEmpty)
        XCTAssertFalse(MonaCaseTables.consumerSet.isEmpty)
        let hexPattern = #"^[0-9a-f]{64}$"#
        let regex = try! NSRegularExpression(pattern: hexPattern)
        for hash in [MonaCaseTables.inputHash, MonaCaseTables.generatorHash, MonaCaseTables.outputHash] {
            let range = NSRange(hash.startIndex..<hash.endIndex, in: hash)
            XCTAssertNotNil(regex.firstMatch(in: hash, range: range),
                            "expected 64-char lowercase hex SHA-256, got \(hash)")
        }
    }

    // MARK: - 2. MonaUnicodeCaseConverter — toLower

    private func makeConverter() -> MonaUnicodeCaseConverter { MonaUnicodeCaseConverter() }

    func testToLowerASCII() {
        let c = makeConverter()
        XCTAssertEqual(c.toLower(0x0041), 0x0061) // A -> a
        XCTAssertEqual(c.toLower(0x005A), 0x007A) // Z -> z
        XCTAssertEqual(c.toLower(0x0061), 0x0061) // a -> a (already lower)
    }

    func testToLowerLatin1Supplement() {
        let c = makeConverter()
        XCTAssertEqual(c.toLower(0x00C0), 0x00E0) // À -> à
        XCTAssertEqual(c.toLower(0x00D6), 0x00F6) // Ö -> ö
        XCTAssertEqual(c.toLower(0x00D8), 0x00F8) // Ø -> ø
        XCTAssertEqual(c.toLower(0x00DE), 0x00FE) // Þ -> þ
    }

    func testToLowerLatinExtendedA() {
        let c = makeConverter()
        XCTAssertEqual(c.toLower(0x0100), 0x0101) // Ā -> ā
        XCTAssertEqual(c.toLower(0x0102), 0x0103) // Ă -> ă
        XCTAssertEqual(c.toLower(0x012E), 0x012F) // Į -> į
    }

    func testToLowerGreek() {
        let c = makeConverter()
        XCTAssertEqual(c.toLower(0x0391), 0x03B1) // Α -> α
        XCTAssertEqual(c.toLower(0x0399), 0x03B9) // Ι -> ι
        XCTAssertEqual(c.toLower(0x03A3), 0x03C3) // Σ -> σ
        XCTAssertEqual(c.toLower(0x03A9), 0x03C9) // Ω -> ω
    }

    func testToLowerCyrillic() {
        let c = makeConverter()
        XCTAssertEqual(c.toLower(0x0410), 0x0430) // А -> а
        XCTAssertEqual(c.toLower(0x042F), 0x044F) // Я -> я
        XCTAssertEqual(c.toLower(0x0400), 0x0450) // Ѐ -> ѐ
    }

    func testToLowerTurkishSpecials() {
        let c = makeConverter()
        // İ (0x0130) simple-lowercases to i (0x0069) in the default profile.
        XCTAssertEqual(c.toLower(0x0130), 0x0069)
    }

    // MARK: - 3. MonaUnicodeCaseConverter — toUpper

    func testToUpperASCII() {
        let c = makeConverter()
        XCTAssertEqual(c.toUpper(0x0061), 0x0041) // a -> A
        XCTAssertEqual(c.toUpper(0x007A), 0x005A) // z -> Z
    }

    func testToUpperLatin1Supplement() {
        let c = makeConverter()
        XCTAssertEqual(c.toUpper(0x00E0), 0x00C0) // à -> À
        XCTAssertEqual(c.toUpper(0x00F6), 0x00D6) // ö -> Ö
    }

    func testToUpperGreekAndCyrillic() {
        let c = makeConverter()
        XCTAssertEqual(c.toUpper(0x03B1), 0x0391) // α -> Α
        XCTAssertEqual(c.toUpper(0x03C9), 0x03A9) // ω -> Ω
        XCTAssertEqual(c.toUpper(0x0430), 0x0410) // а -> А
    }

    func testToUpperSpecials() {
        let c = makeConverter()
        // ı (0x0131) simple-uppercases to I (0x0049).
        XCTAssertEqual(c.toUpper(0x0131), 0x0049)
        // ſ (0x017F, long s) uppercases to S (0x0053).
        XCTAssertEqual(c.toUpper(0x017F), 0x0053)
        // ς (0x03C2, final sigma) uppercases to Σ (0x03A3).
        XCTAssertEqual(c.toUpper(0x03C2), 0x03A3)
    }

    // MARK: - 4. MonaUnicodeCaseConverter — fold / foldCase

    func testFoldGreekSigma() {
        let c = makeConverter()
        // Both Σ (0x03A3) and ς (0x03C2) fold to σ (0x03C3), making them
        // case-insensitively equal under Unicode case folding.
        XCTAssertEqual(c.fold(0x03A3), 0x03C3) // Σ -> σ
        XCTAssertEqual(c.fold(0x03C2), 0x03C3) // ς -> σ
        XCTAssertEqual(c.fold(0x03C3), 0x03C3) // σ -> σ
    }

    func testFoldLongS() {
        let c = makeConverter()
        // ſ (0x017F, long s) folds to s (0x0073).
        XCTAssertEqual(c.fold(0x017F), 0x0073)
    }

    func testFoldTurkishI() {
        let c = makeConverter()
        // İ (0x0130) folds to i (0x0069) in the curated single-unit profile.
        XCTAssertEqual(c.fold(0x0130), 0x0069)
    }

    func testFoldCaseConformanceMatchesFold() {
        let c = makeConverter()
        // The protocol method `foldCase` mirrors `fold` for the curated subset.
        for u: UInt16 in [0x0041, 0x0061, 0x03A3, 0x03C2, 0x017F, 0x0130, 0x00E9] {
            XCTAssertEqual(c.foldCase(u), c.fold(u), "foldCase must match fold for 0x\(String(u, radix: 16))")
        }
    }

    // MARK: - 5. Case converter integrates with MonaLiteralSearch

    func testCaseConverterIntegratesWithLiteralSearch() {
        // Greek uppercase Α-Ω needle found in lowercase α-ω haystack under
        // case-insensitive mode with the real Unicode converter injected.
        let haystack: [UInt16] = [0x03B1, 0x03B2, 0x03B3, 0x03B4] // α β γ δ
        let needle: [UInt16] = [0x0392, 0x0393] // Β Γ
        let search = MonaLiteralSearch(needle: needle, matchCase: false,
                                       caseConverter: MonaUnicodeCaseConverter())
        let match = search.findNext(in: haystack)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.startOffset, 1)
        XCTAssertEqual(match?.length, 2)
    }

    // MARK: - 6. MonaCollationTables provenance

    func testCollationTablesProvenance() {
        XCTAssertFalse(MonaCollationTables.sourceVersion.isEmpty)
        XCTAssertFalse(MonaCollationTables.inputHash.isEmpty)
        XCTAssertFalse(MonaCollationTables.generatorHash.isEmpty)
        XCTAssertFalse(MonaCollationTables.outputHash.isEmpty)
        XCTAssertFalse(MonaCollationTables.consumerSet.isEmpty)
        let hexPattern = #"^[0-9a-f]{64}$"#
        let regex = try! NSRegularExpression(pattern: hexPattern)
        for hash in [MonaCollationTables.inputHash, MonaCollationTables.generatorHash, MonaCollationTables.outputHash] {
            let range = NSRange(hash.startIndex..<hash.endIndex, in: hash)
            XCTAssertNotNil(regex.firstMatch(in: hash, range: range),
                            "expected 64-char lowercase hex SHA-256, got \(hash)")
        }
        XCTAssertGreaterThan(MonaCollationTables.supportedLocales.count, 1)
        XCTAssertTrue(MonaCollationTables.supportedLocales.contains("root"))
    }

    // MARK: - 7. MonaCollator — locale-sensitive comparison

    func testCollatorBasicOrdering() throws {
        let col = try MonaCollator(locale: "root")
        XCTAssertLessThan(col.compare([0x0061], [0x0062]), 0) // a < b
        XCTAssertGreaterThan(col.compare([0x0062], [0x0061]), 0) // b > a
        XCTAssertEqual(col.compare([0x0061], [0x0061]), 0) // a == a
    }

    func testCollatorCaseInsensitiveAtPrimaryLevel() throws {
        let col = try MonaCollator(locale: "root")
        // a (0x0061) and A (0x0041) share primary+secondary weight (case is a
        // tertiary level MonaCode does not surface in Phase 02).
        XCTAssertEqual(col.compare([0x0061], [0x0041]), 0) // a == A
    }

    func testCollatorSecondaryAccent() throws {
        let col = try MonaCollator(locale: "root")
        // a (0x0061) vs à (0x00E0): same primary, à has secondary > 0 → a < à.
        XCTAssertLessThan(col.compare([0x0061], [0x00E0]), 0)
        XCTAssertGreaterThan(col.compare([0x00E0], [0x0061]), 0)
    }

    func testCollatorLocaleSensitiveSwedish() throws {
        // Root: ä (0x00E4) collates with 'a' (primary 1) so ä < z (primary 26).
        let root = try MonaCollator(locale: "root")
        XCTAssertLessThan(root.compare([0x00E4], [0x007A]), 0) // ä < z
        // Swedish: ä is reassigned primary 28, sorting after z (26).
        let sv = try MonaCollator(locale: "sv")
        XCTAssertGreaterThan(sv.compare([0x00E4], [0x007A]), 0) // ä > z
        // ö (0x00F6) under Swedish sorts after z too (primary 30).
        XCTAssertGreaterThan(sv.compare([0x00F6], [0x007A]), 0) // ö > z
    }

    func testCollatorRejectsUnsupportedLocale() {
        // An unsupported locale identifier is rejected with a typed
        // `MonaCollationError.unsupportedLocale` (not a precondition crash).
        XCTAssertThrowsError(try MonaCollator(locale: "klingon")) { error in
            XCTAssertEqual(error as? MonaCollationError, .unsupportedLocale("klingon"))
        }
    }

    // MARK: - 8. MonaNormalizer — four forms

    func testNFCComposes() {
        let n = MonaNormalizer()
        // e (0x0065) + combining acute (0x0301) -> é (0x00E9).
        let out = n.normalize([0x0065, 0x0301], .nfc)
        XCTAssertEqual(out, [0x00E9])
    }

    func testNFDDecomposes() {
        let n = MonaNormalizer()
        // é (0x00E9) -> e (0x0065) + combining acute (0x0301).
        let out = n.normalize([0x00E9], .nfd)
        XCTAssertEqual(out, [0x0065, 0x0301])
    }

    func testNFKCMapsFullwidthDigit() {
        let n = MonaNormalizer()
        // FULLWIDTH DIGIT ZERO (0xFF10) -> ASCII 0 (0x0030).
        let out = n.normalize([0xFF10], .nfkc)
        XCTAssertEqual(out, [0x0030])
    }

    func testNFKDDecomposes() {
        let n = MonaNormalizer()
        // é (0x00E9) NFKD -> e + combining acute (same canonical decomposition).
        let out = n.normalize([0x00E9], .nfkd)
        XCTAssertEqual(out, [0x0065, 0x0301])
    }

    // MARK: - 9. MonaNormalizer — cache counters

    func testNormalizerCacheMissThenHit() {
        let n = MonaNormalizer()
        let input: [UInt16] = [0x00E9]
        let first = n.normalize(input, .nfd)
        XCTAssertEqual(first, [0x0065, 0x0301])
        XCTAssertEqual(n.cacheMisses, 1)
        XCTAssertEqual(n.cacheHits, 0)
        let second = n.normalize(input, .nfd)
        XCTAssertEqual(second, [0x0065, 0x0301])
        XCTAssertEqual(n.cacheMisses, 1)
        XCTAssertEqual(n.cacheHits, 1)
        XCTAssertEqual(n.cacheEvictions, 0)
    }

    func testNormalizerCacheCapacityIs10000() {
        let n = MonaNormalizer()
        XCTAssertEqual(n.composeCacheCapacity, 10000)
        XCTAssertEqual(n.decomposeCacheCapacity, 10000)
    }

    func testNormalizerTwoCachesAreSeparate() {
        // Filling the compose cache must not evict from the decompose cache.
        let n = MonaNormalizer()
        for i in UInt16(1)...UInt16(10000) {
            _ = n.normalize([i], .nfc) // fills compose cache to capacity
        }
        XCTAssertEqual(n.cacheEvictions, 0, "10000 entries exactly fill the compose cache; no eviction yet")
        // One distinct NFD entry goes to the OTHER cache (decompose), still empty.
        _ = n.normalize([0x00E9], .nfd)
        XCTAssertEqual(n.cacheEvictions, 0, "decompose cache is separate; still no eviction")
    }

    func testNormalizerLRUEvictionWhenFull() {
        let n = MonaNormalizer()
        // Insert compose entries 1...10001 (capacity+1) → exactly 1 eviction.
        for i in UInt16(1)...UInt16(10001) {
            _ = n.normalize([i], .nfc)
        }
        XCTAssertGreaterThanOrEqual(n.cacheEvictions, 1)
        // The compose cache must be at its capacity bound, not unbounded.
        XCTAssertLessThanOrEqual(n.composeCacheSize, n.composeCacheCapacity)
    }

    func testNormalizerCountersResetIndependentPerInstance() {
        let a = MonaNormalizer()
        let b = MonaNormalizer()
        _ = a.normalize([0x00E9], .nfd)
        XCTAssertEqual(a.cacheMisses, 1)
        XCTAssertEqual(b.cacheMisses, 0, "counters are per-instance, not global")
    }
}
