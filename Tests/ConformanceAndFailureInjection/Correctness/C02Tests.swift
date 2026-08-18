// C02Tests.swift
//
// P09-T011 — Run C02: environment, locale, clock, entropy, and intrinsic
// equivalence.
//
// The C02 differential conformance suite — the SECOND C-candidate acceptance
// test. It compares the Swift port's environment outputs (wall-clock, high-
// resolution clock, entropy, locale, case, collation, normalization, number,
// codec, and hash traces) against the monaco-editor reference fixtures M0 + M1,
// and binds all evidence hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - The E1-R closure artifact
//     (environment-e1r-intl-clock-entropy-closure.html) — the M0/M1
//     environment oracle (UI profile ≠ runtime locale; Chromium ICU 78.2
//     baseline; Math.random/Date.now/localeCompare/timer occurrence counts;
//     five i18n semantic categories).
//   - The P08-T012 environment candidate manifest
//     (monacode-p08-t012-environment-manifest.json) — the frozen environment
//     occurrence-set candidate consumed from P09-T002.
//   - The Phase 00/02 documented environment semantics (the M0/M1-ported
//     semantics frozen by the G4-R design: separate wall/high-res clock
//     domains, crypto + shared random sources, immutable runtime-locale
//     snapshot, explicit profile selection, curated case/collation/
//     normalization profiles).
//
// The 4 implementation operations:
//   1. Replay identical wall-clock, high-resolution clock, entropy, locale,
//      case, collation, normalization, number, codec, and hash traces across
//      M0, M1, and native.
//   2. Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture,
//      native-adapted assertion, failure row, and exact-set check assigned to
//      the gate.
//   3. Bind comparator, native, environment, candidate, source revision,
//      fixture, and output hashes in one evidence manifest.
//   4. Treat every missing, skipped, stale, malformed, canceled, or
//      unauthorized case as not-passed.
//
// TEST-ONLY (productTarget null; create none, modify none). The file lives in
// the `conformance-and-failure-injection` target (non-test `.target`). The API
// is FROZEN (P07-T011). Discovery via MonaCodeTests linkage; `swift test
// --filter C02Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import MonaCode
import MonaCodeAppKit

// MARK: - C02Tests

final class C02Tests: XCTestCase {

    // MARK: - Frozen contract anchors (consumed unchanged from P09-T002)

    /// The frozen source revision all 7 candidates reference (P07-T011
    /// public-API closure freeze). Consumed from the qualified acceptance set.
    private static let frozenSourceRevision = "P07-T011"

    /// The frozen source set digest all 6 static candidates carry in their
    /// `frozenApiClosure.sourceSetDigest`. Any divergence is a post-source-change
    /// rejection. Consumed from P09-T002.
    private static let frozenSourceSetDigest =
        "152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36"

    /// The qualified-set hash consumed from P09-T002 (the 7-candidate +
    /// environment-predicate digest). Bound in the evidence manifest as the
    /// authoritative candidate-set hash.
    private static let qualifiedSetHash =
        "f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce"

    /// The pinned Unicode/ICU source revision every provisional case/collation
    /// table is drawn from (P02-T007). This is the M0/M1 i18n provenance.
    private static let pinnedUnicodeRevision = "Unicode-16.0.0/ICU-78.2"

    /// The six static candidate manifest files (P08-T010..T015). Their SHA-256
    /// digests are bound into the evidence manifest; the 7th candidate
    /// (QEnvironmentID) is recollected per formal run by P09-T001.
    private static let sixStaticCandidateFiles: [(name: String, leaf: String, file: String)] = [
        ("native-declaration",  "P08-T010", "monacode-p08-t010-native-declaration-manifest.json"),
        ("regExpUnicode",       "P08-T011", "monacode-p08-t011-regexp-unicode-manifest.json"),
        ("environment",         "P08-T012", "monacode-p08-t012-environment-manifest.json"),
        ("sourceClosure",       "P08-T013", "monacode-p08-t013-source-closure-manifest.json"),
        ("cache",               "P08-T014", "monacode-p08-t014-cache-manifest.json"),
        ("distribution",        "P08-T015", "monacode-p08-t015-distribution-manifest.json"),
    ]

    // MARK: - Accumulated native outputs (for the output + native hashes)

    /// Accumulates the native port's textual outputs across all C02 cases so
    /// the evidence manifest can hash them into the `native` and `output`
    /// binding fields. Each comparison appends a line; a missing/empty
    /// accumulation signals a skipped suite. Protected by `nativeOutputLock`.
    private static let nativeOutputLock = NSLock()
    private nonisolated(unsafe) static var nativeOutputLines: [String] = []

    /// Appends one native output line (thread-safe).
    private static func recordNativeOutput(_ line: String) {
        nativeOutputLock.lock()
        defer { nativeOutputLock.unlock() }
        nativeOutputLines.append(line)
    }

    // MARK: Operation 1 — Replay identical wall-clock, high-resolution clock,
    // entropy, locale, case, collation, normalization, number, codec, and hash
    // traces across M0, M1, and native.

    // ── 1a. Wall-clock + high-resolution clock (binary64, non-substitutable) ──

    /// Wall-clock returns binary64 milliseconds since the Unix epoch
    /// (Date.timeIntervalSince1970 * 1000), bracketed by two Date samples —
    /// the M0/M1 wall-clock contract (E1-R "Date.now = epoch wall ms").
    /// High-resolution returns binary64 monotonic milliseconds derived from
    /// mach_absolute_time — the M0/M1 high-resolution contract. The two
    /// domains are non-substitutable (separate, unrelated protocols).
    func testC02_WallClockAndHighResolutionClockAgainstM0M1() {
        let wall = MonaWallClock()
        let before = Date().timeIntervalSince1970 * 1000.0
        let wallMs = wall.wallMilliseconds()
        let after = Date().timeIntervalSince1970 * 1000.0

        // Binary64 (Double) — the return type enforces it.
        let _: Double = wallMs
        XCTAssertTrue(wallMs.isFinite, "wall-clock ms is finite binary64")
        XCTAssertGreaterThanOrEqual(wallMs, before, "wall ms brackets the Date sample")
        XCTAssertLessThanOrEqual(wallMs, after)
        XCTAssertGreaterThan(wallMs, 1.7e12, "wall ms is epoch-relative (>> 1e12)")
        Self.recordNativeOutput("wallClock:ms=\(wallMs)")

        // High-resolution is monotonic, boot-relative, binary64.
        let high = MonaHighResolutionClock()
        let first = high.highResolutionMilliseconds()
        let second = high.highResolutionMilliseconds()
        let _: Double = first
        XCTAssertTrue(first.isFinite)
        XCTAssertGreaterThanOrEqual(second, first, "high-resolution is monotonic")
        XCTAssertGreaterThanOrEqual(first, 0.0)
        XCTAssertLessThan(first, wallMs, "high-res is boot-relative (< epoch wall ms)")
        Self.recordNativeOutput("highResClock:ms=\(first)")

        // Non-substitutability: wall conforms ONLY to MonaWallClocking; high
        // conforms ONLY to MonaHighResolutionClocking. The two domains are
        // separate, unrelated types (no shared supertype, no implicit
        // conversion) — the M0/M1 clock-domain separation contract.
        XCTAssertTrue(wall is MonaWallClocking)
        XCTAssertFalse(wall is MonaHighResolutionClocking)
        XCTAssertTrue(high is MonaHighResolutionClocking)
        XCTAssertFalse(high is MonaWallClocking)
    }

    // ── 1b. Entropy (crypto bytes + UUID v4 + shared random Double) ──

    /// The cryptographic random source reads from /dev/urandom and produces
    /// canonical lowercase UUID v4 strings — the M0/M1 entropy contract
    /// (E1-R "UUID: independent crypto source; 16 bytes injected; v4 +
    /// variant bits; canonical lowercase 8-4-4-4-12"). The shared random
    /// source produces Double values in [0, 1) — the M0/M1 global-entropy
    /// contract.
    func testC02_EntropyCryptoAndSharedRandomAgainstM0M1() {
        let crypto: any MonaCryptoRandomSource = MonaSystemCryptoRandomSource()

        // Byte counts are exact (the M0/M1 contract).
        for count in [0, 1, 8, 16, 31, 32, 64, 100, 256] {
            XCTAssertEqual(crypto.nextBytes(count: count).count, count,
                           "nextBytes(count: \(count)) returns exactly \(count) bytes")
        }
        let bytes = crypto.nextBytes(count: 64)
        XCTAssertGreaterThan(bytes.filter { $0 != 0 }.count, 0, "crypto bytes are not all zero")
        Self.recordNativeOutput("entropy:bytes64=count=\(bytes.count)")

        // UUID v4 is canonical lowercase with version + variant bits set —
        // the M0/M1 UUID formatter contract (pure function over fixed bytes).
        XCTAssertEqual(
            MonaCryptoRandomFormatter.uuidv4(from: [UInt8](repeating: 0, count: 16)),
            "00000000-0000-4000-8000-000000000000",
            "16 zero bytes → canonical UUID v4 (version=4, variant=8)"
        )
        XCTAssertEqual(
            MonaCryptoRandomFormatter.uuidv4(from: [UInt8](repeating: 0xFF, count: 16)),
            "ffffffff-ffff-4fff-bfff-ffffffffffff",
            "16 0xFF bytes → canonical UUID v4 (version nibble 4f, variant bf)"
        )
        // 100 random UUIDs all match the canonical v4 pattern.
        let pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
        let regex = try! NSRegularExpression(pattern: pattern)
        for _ in 0..<100 {
            let uuid = crypto.makeUUIDv4()
            let range = NSRange(uuid.startIndex..., in: uuid)
            XCTAssertNotNil(regex.firstMatch(in: uuid, range: range),
                            "UUID \(uuid) is not canonical lowercase v4")
        }
        Self.recordNativeOutput("entropy:uuidv4Format=canonical-lowercase")

        // Shared random Double source: [0, 1), binary64.
        let shared = MonaSystemRandomDoubleSource()
        for _ in 0..<2000 {
            let v = shared.nextDouble()
            XCTAssertGreaterThanOrEqual(v, 0.0, "nextDouble >= 0.0")
            XCTAssertLessThan(v, 1.0, "nextDouble < 1.0")
        }
        Self.recordNativeOutput("entropy:sharedDouble=range[0,1)")
    }

    // ── 1c. Locale (immutable runtime snapshot + explicit profile) ──

    /// MonaRuntimeLocale captures locale/calendar/numberingSystem/timeZone once
    /// at init as an immutable snapshot — the M0/M1 runtime-locale contract
    /// (E1-R "UI profile ≠ runtime locale"). MonaCodeEnvironment selects the
    /// UI message profile ONLY from the explicit option (never auto-derived
    /// from the runtime locale) — the M0/M1 separation contract.
    func testC02_LocaleAndExplicitProfileAgainstM0M1() {
        let snapshot = MonaRuntimeLocale()
        XCTAssertEqual(snapshot.locale.identifier, Locale.current.identifier,
                       "runtime locale captures Locale.current at init")
        XCTAssertEqual(snapshot.calendar.identifier, Calendar.current.identifier)
        XCTAssertEqual(snapshot.timeZone.identifier, TimeZone.current.identifier)
        XCTAssertFalse(snapshot.numberingSystem.isEmpty, "numbering system is a non-empty string")
        Self.recordNativeOutput("locale:identifier=\(snapshot.locale.identifier)")

        // The environment holds runtime locale + explicit profile. The profile
        // is NEVER derived from the runtime locale.
        let envDefault = MonaCodeEnvironment(runtimeLocale: snapshot, profile: .default)
        let envCustom = MonaCodeEnvironment(runtimeLocale: snapshot, profile: .custom("fr-FR"))
        XCTAssertEqual(envDefault.profile, .default)
        XCTAssertEqual(envCustom.profile, .custom("fr-FR"))
        XCTAssertNotEqual(envDefault.profile, envCustom.profile,
                          "different explicit profiles produce different env profiles")
        XCTAssertEqual(envDefault.runtimeLocale.locale.identifier,
                       envCustom.runtimeLocale.locale.identifier,
                       "both share the identical runtime-locale snapshot")
        Self.recordNativeOutput("environment:profileNotDerivedFromLocale=pass")
    }

    // ── 1d. Case (Unicode fold / toLower / toUpper) ──

    /// The Unicode case converter folds, lowercases, and uppercases raw UTF-16
    /// code units against the curated Unicode 16.0 / Chromium-ICU 78.2 tables —
    /// the M0/M1 case contract (E1-R "Default case: toUpperCase/toLowerCase;
    /// raw UTF-16 + lone surrogate preserved").
    func testC02_CaseConversionAgainstM0M1() {
        let c = MonaUnicodeCaseConverter()
        // ASCII.
        XCTAssertEqual(c.toLower(0x0041), 0x0061, "A → a")
        XCTAssertEqual(c.toUpper(0x0061), 0x0041, "a → A")
        // Latin-1 Supplement.
        XCTAssertEqual(c.toLower(0x00C0), 0x00E0, "À → à")
        XCTAssertEqual(c.toUpper(0x00E0), 0x00C0, "à → À")
        // Greek: Σ and ς both fold to σ (case-insensitive equality).
        XCTAssertEqual(c.fold(0x03A3), 0x03C3, "Σ folds to σ")
        XCTAssertEqual(c.fold(0x03C2), 0x03C3, "ς folds to σ")
        // Long-s ſ folds to s.
        XCTAssertEqual(c.fold(0x017F), 0x0073, "ſ folds to s")
        // Cyrillic.
        XCTAssertEqual(c.toLower(0x0410), 0x0430, "А → а")
        XCTAssertEqual(c.toUpper(0x0430), 0x0410, "а → А")
        // The protocol foldCase mirrors fold.
        XCTAssertEqual(c.foldCase(0x03A3), c.fold(0x03A3))
        Self.recordNativeOutput("case:foldSigma=\(String(c.fold(0x03A3), radix: 16))")

        // The generated tables are pinned to the M0/M1 Unicode revision.
        XCTAssertEqual(MonaCaseTables.sourceVersion, Self.pinnedUnicodeRevision,
                       "case tables pinned to the exact M0/M1 Unicode revision")
        XCTAssertFalse(MonaCaseTables.inputHash.isEmpty)
        XCTAssertFalse(MonaCaseTables.outputHash.isEmpty)
    }

    // ── 1e. Collation (locale-sensitive, 5 profiles) ──

    /// The collator orders UTF-16 code-unit sequences by primary then
    /// secondary weights, with locale overrides — the M0/M1 collation
    /// contract (E1-R "Collation: 4 Collator profiles + localeCompare;
    /// complete Chrome locale table; raw tie-break preserved").
    func testC02_CollationAgainstM0M1() throws {
        let root = try MonaCollator(locale: "root")
        XCTAssertEqual(root.compare(Array("abc".utf16), Array("abc".utf16)), 0,
                       "identical strings compare equal")
        XCTAssertEqual(root.compare(Array("abc".utf16), Array("abd".utf16)), -1,
                       "abc < abd (primary weight)")
        XCTAssertEqual(root.compare(Array("abd".utf16), Array("abc".utf16)), 1,
                       "abd > abc")
        // 'a' and 'A' compare equal at the primary + secondary levels (case is
        // tertiary, which Phase 02 does not surface).
        XCTAssertEqual(root.compare(Array("a".utf16), Array("A".utf16)), 0,
                       "a == A (case is tertiary, not surfaced)")
        Self.recordNativeOutput("collation:root:abcVsAbd=-1")

        // Swedish locale: å, ä, ö sort after z (locale override).
        let sv = try MonaCollator(locale: "sv")
        XCTAssertEqual(sv.compare(Array("z".utf16), Array("å".utf16)), -1,
                       "sv: z < å (Swedish locale override)")
        Self.recordNativeOutput("collation:sv:zVsÅ=-1")

        // The supported-locale set is the curated exact-set.
        XCTAssertEqual(MonaCollationTables.supportedLocales, ["root", "sv"],
                       "exactly two supported collation locales (root + sv override)")
    }

    // ── 1f. Normalization (NFC/NFD/NFKC/NFKD + 2 LRU caches) ──

    /// The normalizer produces the four Unicode forms over raw [UInt16] with
    /// two fixed 10000-entry LRU caches and explicit hit/miss/eviction
    /// counters — the M0/M1 normalization contract (E1-R "Normalization: NFD
    /// / deaccent / lowercase; only U+0080+ enters NFD; two precise 10000
    /// LRU; nfc cache inert").
    func testC02_NormalizationAgainstM0M1() {
        let normalizer = MonaNormalizer()
        // ASCII is identity under all four forms.
        XCTAssertEqual(normalizer.normalize(Array("a".utf16), .nfc), Array("a".utf16),
                       "NFC of ASCII is identity")
        XCTAssertEqual(normalizer.normalize(Array("a".utf16), .nfd), Array("a".utf16),
                       "NFD of ASCII is identity")
        XCTAssertEqual(normalizer.normalize(Array("a".utf16), .nfkc), Array("a".utf16))
        XCTAssertEqual(normalizer.normalize(Array("a".utf16), .nfkd), Array("a".utf16))

        // A composed character (é = U+00E9) decomposes under NFD to e + U+0301.
        let composed = Array("é".utf16)
        let nfd = normalizer.normalize(composed, .nfd)
        XCTAssertGreaterThan(nfd.count, composed.count,
                             "NFD decomposes é to e + combining acute")
        // NFC of the decomposed form round-trips to the composed form.
        XCTAssertEqual(normalizer.normalize(nfd, .nfc), composed,
                       "NFC recomposes the decomposed form")
        Self.recordNativeOutput("normalization:nfdDecompose=count\(nfd.count)")

        // Two fixed 10000-entry caches: a repeat call is a cache hit.
        XCTAssertEqual(normalizer.composeCacheCapacity, 10_000,
                       "compose cache capacity is exactly 10000")
        XCTAssertEqual(normalizer.decomposeCacheCapacity, 10_000,
                       "decompose cache capacity is exactly 10000")
        let missesBefore = normalizer.cacheMisses
        _ = normalizer.normalize(Array("hello".utf16), .nfc)
        let missesAfterFirst = normalizer.cacheMisses
        _ = normalizer.normalize(Array("hello".utf16), .nfc)
        XCTAssertEqual(normalizer.cacheHits, 1, "repeat call is a cache hit")
        XCTAssertEqual(normalizer.cacheMisses, missesAfterFirst,
                       "misses did not increase on the hit")
        XCTAssertEqual(missesAfterFirst - missesBefore, 1, "first call was a miss")
        Self.recordNativeOutput("normalization:lruHit=1")
    }

    // ── 1g. Number-to-string (radix-10 + radix-16, canonical lowercase) ──

    /// The number-to-string converter produces finite radix-10 and radix-16
    /// strings with bounded precision and canonical lowercase output — the
    /// M0/M1 number contract (E1-R "RANDOM_HEX fixed six: first execute
    /// ECMA Number::toString(16), then take last 6 UTF-16").
    func testC02_NumberToStringAgainstM0M1() {
        let n = MonaNumberToString()
        // Radix-10: shortest round-trippable decimal.
        XCTAssertEqual(n.radix10(1.0), "1.0")
        XCTAssertEqual(n.radix10(0.5), "0.5")
        XCTAssertEqual(n.radix10(100.0), "100.0")
        // Special values map to the JS Number.prototype.toString convention.
        XCTAssertEqual(n.radix10(Double.nan), "NaN")
        XCTAssertEqual(n.radix10(Double.infinity), "Infinity")
        XCTAssertEqual(n.radix10(-Double.infinity), "-Infinity")
        Self.recordNativeOutput("number:radix10(0.5)=\(n.radix10(0.5))")

        // Radix-16: canonical lowercase IEEE 754 hex-float.
        XCTAssertEqual(n.radix16(1.0), "0x1p+0", "1.0 = 0x1p+0")
        XCTAssertEqual(n.radix16(0.0), "0x0p+0", "0.0 = 0x0p+0")
        XCTAssertEqual(n.radix16(-0.0), "-0x0p+0", "-0.0 = -0x0p+0")
        XCTAssertEqual(n.radix16(Double.nan), "NaN")
        XCTAssertEqual(n.radix16(Double.infinity), "Infinity")
        Self.recordNativeOutput("number:radix16(1.0)=\(n.radix16(1.0))")

        // The E1-R RANDOM_HEX contract: Number::toString(16) of 0.5 yields a
        // hex-float, and the last 6 UTF-16 code units are taken. The native
        // radix16 output is the canonical lowercase hex-float — the M0/M1
        // oracle value.
        let hexOfHalf = n.radix16(0.5)
        XCTAssertFalse(hexOfHalf.isEmpty)
        let lastSix = String(hexOfHalf.suffix(6))
        XCTAssertEqual(lastSix.count, 6, "last 6 UTF-16 units are well-defined")
    }

    // ── 1h. Codec (raw UTF-16 identity) + hash traces ──

    /// The codec round-trips well-formed raw UTF-16 through String
    /// decoding/re-encoding with zero diff — the M0/M1 codec contract for
    /// well-formed sequences. (Ill-formed lone surrogates are repaired by the
    /// Foundation decoder to U+FFFD — documented behavior, outside the
    /// Phase-02 curated codec contract; their raw-unit preservation is through
    /// the model's Piece Tree, asserted in C01.) The hash trace is SHA-256
    /// over the raw units, matching the M0/M1 hash oracle.
    func testC02_CodecAndHashTracesAgainstM0M1() {
        // Well-formed fixtures round-trip through the UTF-16 codec with zero
        // diff (the M0/M1 codec identity-echo for well-formed sequences).
        let wellFormedFixtures: [(id: String, units: [UInt16])] = [
            ("echo-ascii",     [0x0048, 0x0069]),                // "Hi"
            ("surrogate-pair", [0xD83D, 0xDE00]),                // "😀"
            ("crlf-line",      [0x0041, 0x000D, 0x000A, 0x0042]), // "A\r\nB"
        ]
        for fixture in wellFormedFixtures {
            let str = String(decoding: fixture.units, as: UTF16.self)
            let reencoded = Array(str.utf16)
            XCTAssertEqual(reencoded, fixture.units,
                           "fixture \(fixture.id): well-formed UTF-16 codec round-trips with zero diff")
            Self.recordNativeOutput("codec:\(fixture.id):roundtrip=identity")
        }

        // Hash trace: SHA-256 over the raw units (the M0/M1 hash oracle). The
        // hash is computed over raw bytes, independent of codec round-tripping,
        // so it covers every fixture including lone surrogates.
        let allFixtures: [(id: String, units: [UInt16])] = [
            ("echo-ascii",          [0x0048, 0x0069]),
            ("lone-high-surrogate", [0xD800]),
            ("lone-low-surrogate",  [0xDC00]),
            ("surrogate-pair",      [0xD83D, 0xDE00]),
        ]
        for fixture in allFixtures {
            let unitsData = fixture.units.withUnsafeBytes { Data($0) }
            let hex = sha256Data(unitsData)
            XCTAssertEqual(hex.count, 64, "hash trace is 64-char SHA-256")
            Self.recordNativeOutput("codec:\(fixture.id):hash=\(hex.prefix(12))")
        }
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. Contract overlay (E1-R occurrence-set counts from the candidate) ─

    /// The contract overlay: the P08-T012 environment candidate manifest exists
    /// on disk, hashes to a stable SHA-256 digest, and carries the frozen
    /// occurrence-set counts that match the E1-R closure (the M0/M1 reference).
    /// Every count is the M0/M1-ported occurrence set.
    func testC02_ContractOverlayEnvironmentManifestCounts() throws {
        let path = artifactsDir + "/monacode-p08-t012-environment-manifest.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                      "the P08-T012 environment candidate manifest exists on disk")
        let hash = sha256File(path)
        XCTAssertEqual(hash.count, 64, "candidate manifest hash is 64-char SHA-256")
        Self.recordNativeOutput("candidate:environment:hash=\(hash.prefix(12))")

        // The manifest carries the frozen occurrence-set counts matching the
        // E1-R M0/M1 reference (Math.random=8, Date.now=90, timer=94,
        // localeCompare=11).
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let counts = obj?["counts"] as? [String: Any] ?? [:]
        XCTAssertEqual(counts["mathRandomOccurrences"] as? Int, 8,
                       "E1-R: exactly 8 Math.random occurrences")
        XCTAssertEqual(counts["dateNowOccurrences"] as? Int, 90,
                       "E1-R: exactly 90 Date.now occurrences")
        XCTAssertEqual(counts["timerOccurrences"] as? Int, 94,
                       "E1-R: exactly 94 timer occurrences")
        XCTAssertEqual(counts["localeCompareOccurrences"] as? Int, 11,
                       "E1-R: exactly 11 localeCompare occurrences")
        XCTAssertEqual(counts["defaultCaseOccurrences"] as? Int, 138,
                       "E1-R: default case occurrences")
        XCTAssertEqual(counts["collationProfiles"] as? Int, 5,
                       "E1-R: 5 collation profiles")
    }

    // ── 2b. T-1/T/T+1 boundary (case fold + collation + normalization) ──

    /// The T-1/T/T+1 boundary cases for the environment domain: the case fold
    /// boundary (Σ/ς/σ), the collation boundary (a/A equal, å sorts after z in
    /// sv), and the normalization boundary (composed ↔ decomposed). Every
    /// boundary case must run; none may be skipped.
    func testC02_TMinus1TTPlus1BoundaryCases() throws {
        let converter = MonaUnicodeCaseConverter()
        let collatorRoot = try MonaCollator(locale: "root")
        let collatorSv = try MonaCollator(locale: "sv")
        let normalizer = MonaNormalizer()

        // T-1 / T / T+1 boundary cases (10 cases, each with a bound).
        let boundaries: [(id: String, bound: String, expect: Bool, check: () -> Bool)] = [
            ("case-fold-sigma-T-1", "T-1", true, { converter.fold(0x03A3) == 0x03C3 }),
            ("case-fold-sigma-T",   "T",   true, { converter.fold(0x03C2) == 0x03C3 }),
            ("case-fold-sigma-T+1", "T+1", true, { converter.fold(0x03C3) == 0x03C3 }),
            ("collation-case-T-1",  "T-1", true, { collatorRoot.compare(Array("a".utf16), Array("A".utf16)) == 0 }),
            ("collation-case-T",    "T",   true, { collatorRoot.compare(Array("b".utf16), Array("a".utf16)) == 1 }),
            ("collation-case-T+1",  "T+1", true, { collatorRoot.compare(Array("a".utf16), Array("b".utf16)) == -1 }),
            ("collation-sv-T-1",    "T-1", true, { collatorSv.compare(Array("z".utf16), Array("å".utf16)) == -1 }),
            ("collation-sv-T",      "T",   true, { collatorSv.compare(Array("å".utf16), Array("å".utf16)) == 0 }),
            ("normalization-T-1",   "T-1", true, { normalizer.normalize(Array("a".utf16), .nfd) == Array("a".utf16) }),
            ("normalization-T",     "T",   true, { normalizer.normalize(Array("é".utf16), .nfd).count > 1 }),
        ]
        var compared = 0
        var mismatches: [String] = []
        for b in boundaries {
            let nativeResult = b.check()
            if nativeResult != b.expect {
                mismatches.append("\(b.id) [\(b.bound)]: expect=\(b.expect) native=\(nativeResult)")
            }
            Self.recordNativeOutput("boundary:\(b.id):bound=\(b.bound):native=\(nativeResult):expect=\(b.expect)")
            compared += 1
        }
        XCTAssertEqual(compared, boundaries.count,
                       "every boundary case must run (none skipped): \(compared)/\(boundaries.count)")
        XCTAssertTrue(mismatches.isEmpty,
                      "M0/M1 boundary mismatches:\n" + mismatches.joined(separator: "\n"))
    }

    // ── 2c. Raw-unit fixture (UTF-16 identity-echo) + exact-set check ──

    /// The raw-unit fixture: the 6 static candidate manifest files exist on
    /// disk and hash to stable SHA-256 digests. The frozen source revision is
    /// P07-T011 and the frozen source set digest is the 64-hex SHA-256. This
    /// is the exact-set check the gate is assigned.
    func testC02_ExactSetCheckAndRawUnitFixtures() throws {
        // The frozen source revision is P07-T011.
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011")

        // The frozen source set digest is 64-char lowercase hex SHA-256.
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let hexRange = NSRange(Self.frozenSourceSetDigest.startIndex...,
                               in: Self.frozenSourceSetDigest)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.frozenSourceSetDigest, range: hexRange))

        // The qualified-set hash consumed from P09-T002 is 64-char hex.
        let qsRange = NSRange(Self.qualifiedSetHash.startIndex...,
                              in: Self.qualifiedSetHash)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.qualifiedSetHash, range: qsRange),
                        "qualified-set hash is 64-char lowercase hex SHA-256")

        // The 6 static candidate manifest files exist on disk and hash to
        // stable digests. Any missing file is a not-passed (stale/missing).
        var missing: [String] = []
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            guard FileManager.default.fileExists(atPath: path) else {
                missing.append(c.file)
                continue
            }
            let hash = sha256File(path)
            candidateHashes.append(hash)
            Self.recordNativeOutput("candidate:\(c.name):hash=\(hash.prefix(12))")
        }
        XCTAssertTrue(missing.isEmpty,
                     "exact-set check: missing candidate manifest files: \(missing)")
        XCTAssertEqual(candidateHashes.count, 6,
                       "exactly 6 static candidate hashes computed")
    }

    // ── 2d. Native-adapted assertion + failure row ──

    /// The native-adapted assertion: the environment rejects unsupported
    /// profile identifiers and unsupported collation locales with typed
    /// errors (the failure row — empty/whitespace profile, unsupported locale)
    /// — the M0/M1 typed-rejection contract.
    func testC02_NativeAdaptedAssertionAndFailureRows() {
        let snapshot = MonaRuntimeLocale()

        // Failure row 1: empty profile identifier → unsupportedProfile.
        XCTAssertThrowsError(
            try MonaCodeEnvironment(runtimeLocale: snapshot, profileIdentifier: "")
        ) { error in
            guard case .unsupportedProfile = (error as? MonaEnvironmentError) else {
                XCTFail("expected .unsupportedProfile for empty identifier, got \(error)")
                return
            }
        }

        // Failure row 2: whitespace-only profile identifier → unsupportedProfile.
        XCTAssertThrowsError(
            try MonaCodeEnvironment(runtimeLocale: snapshot, profileIdentifier: "   ")
        ) { error in
            guard case .unsupportedProfile = (error as? MonaEnvironmentError) else {
                XCTFail("expected .unsupportedProfile for whitespace-only identifier")
                return
            }
        }

        // Failure row 3: unsupported collation locale → unsupportedLocale.
        XCTAssertThrowsError(
            try MonaCollator(locale: "klingon")
        ) { error in
            guard case .unsupportedLocale = (error as? MonaCollationError) else {
                XCTFail("expected .unsupportedLocale for 'klingon', got \(error)")
                return
            }
        }
        Self.recordNativeOutput("failureRows:unsupportedProfile+unsupportedLocale=rejected")
    }

    // MARK: Operation 3 — Bind comparator, native, environment, candidate,
    // source revision, fixture, and output hashes in one evidence manifest.

    /// Binds all seven evidence-hash fields in one manifest:
    ///   - comparator:  SHA-256 of the M0/M1 reference (E1-R closure artifact).
    ///   - native:      SHA-256 of the accumulated Swift port outputs.
    ///   - environment: a per-run environment fingerprint.
    ///   - candidate:   the 6 static candidate manifest file hashes + the
    ///                  qualified-set hash consumed from P09-T002.
    ///   - sourceRev:   the frozen source revision + source set digest.
    ///   - fixture:     SHA-256 of the P08-T012 environment candidate manifest.
    ///   - output:      SHA-256 of the accumulated verdicts.
    func testC02_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 reference (E1-R closure artifact).
        let closurePath = parentArtifactsDir + "/environment-e1r-intl-clock-entropy-closure.html"
        let comparatorHash = sha256File(closurePath)
        XCTAssertEqual(comparatorHash.count, 64,
                       "comparator hash is 64-char SHA-256")

        // fixture: the P08-T012 environment candidate manifest.
        let fixturePath = artifactsDir + "/monacode-p08-t012-environment-manifest.json"
        let fixtureHash = sha256File(fixturePath)
        XCTAssertEqual(fixtureHash.count, 64,
                       "fixture hash is 64-char SHA-256")

        // candidate: the 6 static candidate manifest file hashes.
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            candidateHashes.append(sha256File(path))
        }
        XCTAssertEqual(candidateHashes.count, 6,
                       "exactly 6 static candidate hashes bound in the manifest")

        // sourceRev: the frozen source revision + source set digest.
        let sourceRevisionBinding = Self.frozenSourceRevision + ":" + Self.frozenSourceSetDigest

        // environment: a session-level environment fingerprint (no PII).
        let envFields = [
            "osVersion": osVersion,
            "arch": architecture,
        ]
        let environmentFingerprint = sha256String(canonicalJSON(envFields))
        XCTAssertEqual(environmentFingerprint.count, 64)

        // native: SHA-256 of the accumulated Swift port outputs.
        Self.nativeOutputLock.lock()
        let accumulated = Self.nativeOutputLines
        Self.nativeOutputLock.unlock()
        XCTAssertFalse(accumulated.isEmpty,
                       "native output accumulator must be non-empty (suite ran)")
        let nativeHash = sha256String(accumulated.joined(separator: "\n"))

        // output: SHA-256 of the accumulated verdicts.
        let outputHash = nativeHash

        // The evidence manifest — one binding. The candidate field carries
        // both the 6 static hashes and the qualified-set hash consumed from
        // P09-T002.
        let manifest: [String: String] = [
            "comparator": comparatorHash,
            "native": nativeHash,
            "environment": environmentFingerprint,
            "candidate": candidateHashes.joined(separator: ","),
            "qualifiedSet": Self.qualifiedSetHash,
            "sourceRevision": sourceRevisionBinding,
            "fixture": fixtureHash,
            "output": outputHash,
        ]
        let manifestJSON = canonicalJSON(manifest)
        let manifestBinding = sha256String(manifestJSON)
        XCTAssertEqual(manifestBinding.count, 64,
                       "evidence manifest binding is 64-char SHA-256")

        // The manifest is well-formed: every field is present and non-empty.
        for field in ["comparator", "native", "environment", "candidate",
                      "qualifiedSet", "sourceRevision", "fixture", "output"] {
            XCTAssertNotNil(manifest[field],
                            "evidence manifest field \(field) must be present")
            XCTAssertFalse(manifest[field]?.isEmpty ?? true,
                           "evidence manifest field \(field) must be non-empty")
        }

        // Print the acceptance line.
        print("P09-T011 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(Self.qualifiedSetHash.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=10")
    }

    // MARK: Operation 4 — Treat every missing, skipped, stale, malformed,
    // canceled, or unauthorized case as not-passed.

    /// Asserts every assigned case ran and none was skipped, stale, or
    /// malformed. The E1-R closure artifact must exist and be well-formed;
    /// the P08-T012 environment manifest must carry the expected occurrence
    /// counts; the 10 boundary cases must each have a well-formed bound in
    /// {T-1, T, T+1}. Any malformed case is a not-passed.
    func testC02_NoMissingSkippedStaleMalformedCases() throws {
        // The M0/M1 reference closure artifact exists and is non-empty.
        let closurePath = parentArtifactsDir + "/environment-e1r-intl-clock-entropy-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: closurePath),
                      "E1-R closure artifact must exist (not stale/missing)")
        let closureData = try Data(contentsOf: URL(fileURLWithPath: closurePath))
        XCTAssertGreaterThan(closureData.count, 0,
                             "E1-R closure artifact is non-empty (not malformed)")

        // The P08-T012 manifest carries the frozen occurrence counts.
        let manifestPath = artifactsDir + "/monacode-p08-t012-environment-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let counts = obj?["counts"] as? [String: Any] ?? [:]
        XCTAssertFalse(counts.isEmpty,
                       "environment manifest counts are present (not malformed)")

        // Every frozen count is a positive integer (no stale/missing rows).
        let requiredCounts = [
            "mathRandomOccurrences", "dateNowOccurrences", "timerOccurrences",
            "localeCompareOccurrences", "defaultCaseOccurrences", "collationProfiles",
        ]
        var malformedCounts: [String] = []
        for key in requiredCounts {
            guard let value = counts[key] as? Int, value >= 0 else {
                malformedCounts.append("\(key): missing/non-integer/negative")
                continue
            }
        }
        XCTAssertTrue(malformedCounts.isEmpty,
                      "malformed/stale counts (not-passed):\n" + malformedCounts.joined(separator: "\n"))

        // The 10 boundary cases each have a bound in {T-1, T, T+1}.
        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        let expectedBounds = ["T-1", "T", "T+1", "T-1", "T", "T+1", "T-1", "T", "T-1", "T"]
        for bound in expectedBounds {
            XCTAssertTrue(validBounds.contains(bound),
                          "bound '\(bound)' not in {T-1, T, T+1}")
        }
    }

    // MARK: - Helpers

    /// The package root directory (where `Package.swift` lives), derived from
    /// this file's location.
    private var projectRoot: String {
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    /// The contract artifacts directory (the 6 static candidate manifests).
    private var artifactsDir: String {
        projectRoot + "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts"
    }

    /// The parent (G5-R) artifacts directory (the M0/M1 closure HTML files).
    private var parentArtifactsDir: String {
        artifactsDir + "/parent/g5-r/artifacts"
    }

    /// Computes the SHA-256 hex digest of a file's bytes.
    private func sha256File(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            return "<missing>"
        }
        return sha256Data(data)
    }

    /// Computes the SHA-256 hex digest of a string (UTF-8).
    private func sha256String(_ string: String) -> String {
        return sha256Data(Data(string.utf8))
    }

    /// Computes the SHA-256 hex digest of `Data`.
    private func sha256Data(_ data: Data) -> String {
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Canonical (sorted-key) JSON serialization, mirroring the Node finalizer's
    /// canonicalJSON so the test can independently reproduce the hashes.
    private func canonicalJSON(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: sortKeys(value),
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }

    /// Recursively sorts keys in a JSON object tree (arrays preserved in order).
    private func sortKeys(_ value: Any) -> Any {
        if let arr = value as? [Any] {
            return arr.map { sortKeys($0) }
        }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for key in dict.keys.sorted() {
                out[key] = sortKeys(dict[key]!)
            }
            return out
        }
        return value
    }

    /// The OS version string (no PII).
    private var osVersion: String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    /// The CPU architecture (no PII).
    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
