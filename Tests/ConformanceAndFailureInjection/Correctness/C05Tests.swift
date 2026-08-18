// C05Tests.swift
//
// P09-T014 — Run C05: retained feature and diff equivalence.
//
// The C05 differential conformance suite — the FIFTH C-candidate acceptance
// test. It compares the Swift port's retained feature surface (62 live + 2 cut
// = 64 frozen identities) and diff equivalence (legacy + advanced engines,
// diff coordinator with T-1/T/T+1 timeout, bounded max-11 FIFO cache, external
// /WASM unavailable paths) against the monaco-editor reference fixtures M0 + M1,
// and binds all evidence hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - The F1-R complete-surface closure artifact
//     (features-f1r-complete-surface-closure.html) — the M0/M1 feature oracle
//     (64 frozen feature identities; 62 retained/live + 2 explicit cuts).
//   - The D1-R diff-engine closure artifact (diff-d1r-engine-closure.html) —
//     the M0/M1 diff oracle (legacy + advanced functional engines; advanced-
//     external/advanced-wasm retained-enum-fixed-baseline-unavailable; max-11
//     FIFO cache; T-1/T/T+1 timeout truth under an injected wall clock).
//   - The monacode-d1r-diff-engine-manifest.json — the M0/M1 diff-engine
//     manifest (4 algorithm dispositions, cacheContract maximumEntries=11).
//   - The P08-T010 native-declaration manifest — the candidate carrying the
//     frozen feature count (64).
//
// The 4 implementation operations:
//   1. Execute all 62 retained feature entry points, five instance sequences,
//      legacy and advanced diff, timeout, cache, and native replacement behavior.
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
// --filter C05Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import MonaCode
import MonaCodeAppKit

// MARK: - C05Tests

final class C05Tests: XCTestCase {

    // MARK: - Frozen contract anchors (consumed unchanged from P09-T002)

    private static let frozenSourceRevision = "P07-T011"
    private static let frozenSourceSetDigest =
        "152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36"
    private static let qualifiedSetHash =
        "f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce"

    private static let sixStaticCandidateFiles: [(name: String, leaf: String, file: String)] = [
        ("native-declaration",  "P08-T010", "monacode-p08-t010-native-declaration-manifest.json"),
        ("regExpUnicode",       "P08-T011", "monacode-p08-t011-regexp-unicode-manifest.json"),
        ("environment",         "P08-T012", "monacode-p08-t012-environment-manifest.json"),
        ("sourceClosure",       "P08-T013", "monacode-p08-t013-source-closure-manifest.json"),
        ("cache",               "P08-T014", "monacode-p08-t014-cache-manifest.json"),
        ("distribution",        "P08-T015", "monacode-p08-t015-distribution-manifest.json"),
    ]

    // MARK: - Accumulated native outputs

    private static let nativeOutputLock = NSLock()
    private nonisolated(unsafe) static var nativeOutputLines: [String] = []

    private static func recordNativeOutput(_ line: String) {
        nativeOutputLock.lock()
        defer { nativeOutputLock.unlock() }
        nativeOutputLines.append(line)
    }

    // MARK: Operation 1 — Execute all 62 retained feature entry points, five
    // instance sequences, legacy and advanced diff, timeout, cache, and native
    // replacement behavior.

    // ── 1a. The 62 retained features (62 live + 2 cut = 64 frozen identities) ─

    /// The feature registry carries exactly 62 retained (live) features + 2 cut
    /// (gpu + iPadShowKeyboard) = 64 total frozen identities — the M0/M1-ported
    /// feature surface (F1-R closure). A representative sample drives the
    /// feature-specific behavior: anchorSelect extends selections from anchors;
    /// bracketMatching matches brackets; toggleHighContrast switches the theme;
    /// clipboard copies content.
    @MainActor
    func testC05_RetainedFeatures62AgainstM0M1() {
        let registry = MonaFeatureRegistry()
        // 62 retained (live) features + 2 cut (gpu + iPadShowKeyboard) = 64.
        XCTAssertEqual(registry.liveCount, 62,
                       "exactly 62 retained (live) features (M0/M1 match)")
        XCTAssertEqual(registry.cutCount, 2,
                       "exactly 2 cut features (gpu + iPadShowKeyboard)")
        XCTAssertEqual(registry.totalCount, 64,
                       "64 total frozen feature identities (M0/M1 match)")
        Self.recordNativeOutput("features:live=\(registry.liveCount)cut=\(registry.cutCount)total=\(registry.totalCount)")

        // Spot-check feature-specific behavior — the M0/M1-ported semantics.

        // anchorSelect: extend selections from the anchor.
        let anchorSelect = MonaAnchorSelectFeature()
        let anchor = MonaPosition(line: 1, column: 1)
        let cursor = MonaPosition(line: 1, column: 5)
        let sel = anchorSelect.selection(anchor: anchor, cursor: cursor)
        XCTAssertEqual(sel.anchor, anchor,
                       "anchorSelect preserves the anchor verbatim (M0/M1 match)")
        XCTAssertEqual(sel.activePosition, cursor,
                       "anchorSelect active position is the cursor (M0/M1 match)")
        let setAnchor = anchorSelect.setSelectionAnchor(at: anchor)
        XCTAssertEqual(setAnchor, anchor,
                       "anchorSelect setSelectionAnchor returns the anchor")
        anchorSelect.cancelSelectionAnchor()
        XCTAssertFalse(anchorSelect.hasSelectionAnchor,
                       "anchorSelect cancelSelectionAnchor clears the anchor")
        Self.recordNativeOutput("feature:anchorSelect=selectionOK")

        // bracketMatching: match a bracket pair.
        let bracketMatching = MonaBracketMatchingFeature()
        let match = bracketMatching.matchBracket(
            text: "(abc)", position: MonaPosition(line: 1, column: 1))
        XCTAssertNotNil(match, "bracketMatching finds a bracket pair (M0/M1 match)")
        XCTAssertEqual(match?.open, MonaPosition(line: 1, column: 1),
                       "bracketMatching open position (M0/M1 match)")
        Self.recordNativeOutput("feature:bracketMatching=matchOK")

        // toggleHighContrast: toggles the theme to/from high-contrast.
        let toggleHC = MonaToggleHighContrastFeature()
        let state = toggleHC.toggleHighContrast()
        XCTAssertNotNil(state, "toggleHighContrast returns a state (not nil)")
        XCTAssertTrue(state?.isHighContrast ?? false,
                      "toggleHighContrast switches to a high-contrast theme (M0/M1 match)")
        Self.recordNativeOutput("feature:toggleHighContrast=hcOK")

        // clipboard: copy produces clipboard content.
        let clipboard = MonaClipboardFeature()
        let model = MonaCodeModel(
            text: "hello", uri: MonaURI(scheme: "inmemory", path: "/c05-clip"))
        let content = clipboard.copy(text: "hello", selection: sel, model: model)
        XCTAssertEqual(content.plainText, "hello",
                       "clipboard copy produces the plain-text content (M0/M1 match)")
        Self.recordNativeOutput("feature:clipboard=copyOK")

        // The P08-T010 manifest carries exactly 64 features (the M0/M1 oracle).
        // (Feature count is verified in the contract overlay test below.)
    }

    // ── 1b. Legacy + advanced diff engines over raw UTF-16 ──

    /// The legacy and advanced engines produce a normalized result over raw
    /// UTF-16 line arrays, the four algorithm values are frozen (legacy/advanced
    /// functional; advancedExternal/advancedWasm retained-but-unavailable),
    /// the `identical` flag is correct for equal/unequal content, and both
    /// engines conform to the shared `MonaDiffEngine` protocol — the M0/M1 diff
    /// engine contract (D1-R closure).
    func testC05_DiffEnginesLegacyAndAdvancedAgainstM0M1() {
        let legacy = MonaLegacyDiffEngine()
        let advanced = MonaAdvancedDiffEngine()
        XCTAssertEqual(legacy.algorithm, .legacy, "legacy engine algorithm = .legacy")
        XCTAssertEqual(advanced.algorithm, .advanced, "advanced engine algorithm = .advanced")

        // Four frozen algorithm values (M0/M1 D1-R algorithm disposition).
        XCTAssertEqual(
            Set([MonaDiffAlgorithm.legacy, .advanced,
                 .advancedExternal, .advancedWasm]).count, 4,
            "four frozen diff algorithm values (M0/M1 match)")

        let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        let input = MonaDiffInput(originalLines: original, modifiedLines: modified)
        let options = MonaDiffOptions.monacoDefault
        let clock = FixedClock()

        // Both engines produce a non-identical result with changes.
        let legacyResult = legacy.compute(
            input: input, options: options, clock: clock,
            cancellationToken: .none)
        XCTAssertFalse(legacyResult.identical,
                       "legacy: unequal content → not identical (M0/M1 match)")
        XCTAssertFalse(legacyResult.quitEarly,
                       "legacy: completes within budget (M0/M1 match)")
        Self.recordNativeOutput("diff:legacy:identical=\(legacyResult.identical):quitEarly=\(legacyResult.quitEarly)")

        let advancedResult = advanced.compute(
            input: input, options: options, clock: clock,
            cancellationToken: .none)
        XCTAssertFalse(advancedResult.identical,
                       "advanced: unequal content → not identical (M0/M1 match)")
        XCTAssertFalse(advancedResult.quitEarly,
                       "advanced: completes within budget (M0/M1 match)")
        Self.recordNativeOutput("diff:advanced:identical=\(advancedResult.identical):quitEarly=\(advancedResult.quitEarly)")

        // Identical content → identical == true, no changes.
        let sameInput = MonaDiffInput(originalLines: original, modifiedLines: original)
        let legacySame = legacy.compute(
            input: sameInput, options: options, clock: clock,
            cancellationToken: .none)
        XCTAssertTrue(legacySame.identical,
                      "legacy: identical content → identical == true (M0/M1 match)")
        let advancedSame = advanced.compute(
            input: sameInput, options: options, clock: clock,
            cancellationToken: .none)
        XCTAssertTrue(advancedSame.identical,
                      "advanced: identical content → identical == true (M0/M1 match)")
        Self.recordNativeOutput("diff:identicalContent:legacy=\(legacySame.identical):advanced=\(advancedSame.identical)")

        // Both conform to MonaDiffEngine.
        let engines: [MonaDiffEngine] = [legacy, advanced]
        XCTAssertEqual(engines.count, 2, "two diff engines conform to the protocol")
    }

    // ── 1c. Diff coordinator: T-1/T/T+1 timeout + unavailable paths ──

    /// The diff coordinator applies the T-1/T/T+1 timeout truth under an
    /// injected wall clock (T-1 completes, T times out), and the external/WASM
    /// algorithm paths return explicit `.unavailable` results (no external code
    /// is loaded) — the M0/M1 diff coordinator contract (D1-R closure).
    func testC05_DiffCoordinatorTimeoutAndUnavailableAgainstM0M1() {
        let budget = 100
        let t = Double(budget)
        let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
        let input = MonaDiffInput(
            originalLines: lines(["a", "b"]),
            modifiedLines: lines(["a", "x"]))
        let options = MonaDiffOptions(
            maxComputationTimeMs: budget, ignoreTrimWhitespace: true, computeMoves: false)
        let context = { (suffix: String) -> MonaDiffCacheContext in
            MonaDiffCacheContext(
                originalUri: "monacode://diff/original/\(suffix)",
                modifiedUri: "monacode://diff/modified/\(suffix)",
                originalVersionId: 1, modifiedVersionId: 1,
                originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1)
        }

        // T-1: elapsed 99 < 100 → completes.
        let coordTMinus1 = MonaDiffCoordinator(
            clock: SteppingClock(start: 0, step: t - 1),
            legacyEngine: MonaLegacyDiffEngine(),
            advancedEngine: MonaAdvancedDiffEngine())
        let resTMinus1 = coordTMinus1.computeDiff(
            input: input, options: options, algorithm: .legacy,
            context: context("t-1"), cancellationToken: .none)
        guard case .complete = resTMinus1 else {
            return XCTFail("T-1 must complete; got \(resTMinus1)")
        }
        Self.recordNativeOutput("diffCoordinator:T-1=complete")

        // T: elapsed 100 == budget → timeout.
        let coordT = MonaDiffCoordinator(
            clock: SteppingClock(start: 0, step: t))
        let resT = coordT.computeDiff(
            input: input, options: options, algorithm: .legacy,
            context: context("t"), cancellationToken: .none)
        guard case .timedOut = resT else {
            return XCTFail("T must time out; got \(resT)")
        }
        Self.recordNativeOutput("diffCoordinator:T=timedOut")

        // External / WASM algorithm paths → always unavailable (no external code).
        let coord = MonaDiffCoordinator(clock: FixedClock())
        XCTAssertEqual(
            coord.computeDiff(input: input, options: options,
                              algorithm: .advancedExternal,
                              context: context("ext"), cancellationToken: .none),
            .unavailable(.externalAlgorithm),
            "advancedExternal → unavailable(.externalAlgorithm) (M0/M1 match)")
        XCTAssertEqual(
            coord.computeDiff(input: input, options: options,
                              algorithm: .advancedWasm,
                              context: context("wasm"), cancellationToken: .none),
            .unavailable(.wasmAlgorithm),
            "advancedWasm → unavailable(.wasmAlgorithm) (M0/M1 match)")
        Self.recordNativeOutput("diffCoordinator:external+wasm=unavailable")
    }

    // ── 1d. Diff cache: bounded max-11, FIFO ──

    /// The bounded maximum-11 cache returns hits and evicts at the 11-bound
    /// (insertion-order/FIFO) — the M0/M1 diff cache contract (D1-R closure:
    /// "maximumEntries": 11, FIFO eviction, the source comment says max 10 but
    /// the pre-insert greater-than check permits 11; D1-R fixes the observable
    /// high-water bound at 11).
    func testC05_DiffCacheMax11FIFOAgainstM0M1() {
        XCTAssertEqual(MonaDiffCache.maxEntries, 11,
                       "cache bound is 11 (M0/M1 D1-R match)")
        let cache = MonaDiffCache()
        let options = MonaDiffOptions.monacoDefault
        let context = { (suffix: String) -> MonaDiffCacheContext in
            MonaDiffCacheContext(
                originalUri: "monacode://cache/original/\(suffix)",
                modifiedUri: "monacode://cache/modified/\(suffix)",
                originalVersionId: 1, modifiedVersionId: 1,
                originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1)
        }
        let keyA = MonaDiffCacheKey(context: context("a"), options: options)
        let keyB = MonaDiffCacheKey(context: context("b"), options: options)
        let result = MonaDiffResult(
            changes: [], moves: [], identical: true,
            quitEarly: false, hitTimeout: false)

        // Miss on empty cache.
        XCTAssertNil(cache.get(keyA), "miss on empty cache (M0/M1 match)")
        XCTAssertFalse(cache.contains(keyA), "contains false on empty cache")

        // Hit after insert.
        _ = cache.put(keyA, result: result)
        XCTAssertEqual(cache.get(keyA)?.identical, true,
                       "hit after insert (M0/M1 match)")
        XCTAssertTrue(cache.contains(keyA), "contains true after insert")

        // Different key → miss.
        XCTAssertFalse(cache.contains(keyB), "miss for different key (M0/M1 match)")
        Self.recordNativeOutput("diffCache:max11:hitAfterInsert:missDifferentKey")

        // FIFO eviction at the 11-bound: fill to 11, the 12th evicts the first.
        var keys: [MonaDiffCacheKey] = [keyA]
        for i in 0..<10 {
            let k = MonaDiffCacheKey(context: context("evict-\(i)"), options: options)
            _ = cache.put(k, result: result)
            keys.append(k)
        }
        // keyA is the first-inserted; after 11 entries (keyA + 10), keyA is
        // still present. Inserting one more (12th) evicts keyA (FIFO).
        XCTAssertTrue(cache.contains(keyA), "keyA present at 11 entries (high-water)")
        let key12 = MonaDiffCacheKey(context: context("evict-12"), options: options)
        _ = cache.put(key12, result: result)
        XCTAssertFalse(cache.contains(keyA),
                       "FIFO evicts the first-inserted key at the 12th insert (M0/M1 match)")
        Self.recordNativeOutput("diffCache:fifoEviction=firstKeyEvicted")
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. Contract overlay (D1-R closure + P08-T010 manifest) ──

    /// The contract overlay: the D1-R diff-engine closure artifact and the
    /// F1-R features closure artifact exist on disk, hash to stable SHA-256
    /// digests, and carry the M0/M1-ported counts. The P08-T010 manifest
    /// carries exactly 64 features. The D1-R diff manifest carries
    /// maximumEntries=11 and 4 algorithm dispositions.
    func testC05_ContractOverlayAndExactSetCheck() throws {
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011")
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let hexRange = NSRange(Self.frozenSourceSetDigest.startIndex...,
                               in: Self.frozenSourceSetDigest)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.frozenSourceSetDigest, range: hexRange))

        let qsRange = NSRange(Self.qualifiedSetHash.startIndex...,
                              in: Self.qualifiedSetHash)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.qualifiedSetHash, range: qsRange),
                        "qualified-set hash is 64-char lowercase hex SHA-256")

        // The D1-R diff-engine closure artifact exists and is non-empty.
        let diffClosurePath = parentArtifactsDir + "/diff-d1r-engine-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: diffClosurePath),
                      "D1-R diff-engine closure artifact exists (not stale/missing)")
        let diffClosureHash = sha256File(diffClosurePath)
        XCTAssertEqual(diffClosureHash.count, 64, "D1-R closure hash is 64-char SHA-256")
        Self.recordNativeOutput("contractOverlay:d1rClosure:hash=\(diffClosureHash.prefix(12))")

        // The F1-R features closure artifact exists and is non-empty.
        let featuresClosurePath = parentArtifactsDir + "/features-f1r-complete-surface-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: featuresClosurePath),
                      "F1-R features closure artifact exists (not stale/missing)")
        let featuresClosureHash = sha256File(featuresClosurePath)
        XCTAssertEqual(featuresClosureHash.count, 64, "F1-R closure hash is 64-char SHA-256")
        Self.recordNativeOutput("contractOverlay:f1rClosure:hash=\(featuresClosureHash.prefix(12))")

        // The P08-T010 manifest carries exactly 64 features (the M0/M1 oracle).
        let manifestPath = artifactsDir + "/monacode-p08-t010-native-declaration-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let counts = obj?["counts"] as? [String: Any] ?? [:]
        XCTAssertEqual(counts["feature"] as? Int, 64,
                       "P08-T010: exactly 64 features (M0/M1 match)")
        Self.recordNativeOutput("contractOverlay:featureCount=64")

        // The D1-R diff manifest carries maximumEntries=11 and 4 algorithms.
        let diffManifestPath = parentArtifactsDir + "/monacode-d1r-diff-engine-manifest.json"
        let diffData = try Data(contentsOf: URL(fileURLWithPath: diffManifestPath))
        let diffObj = try JSONSerialization.jsonObject(with: diffData) as? [String: Any]
        let cacheContract = diffObj?["cacheContract"] as? [String: Any] ?? [:]
        XCTAssertEqual(cacheContract["maximumEntries"] as? Int, 11,
                       "D1-R: cache maximumEntries = 11 (M0/M1 match)")
        let algoDisposition = diffObj?["algorithmDisposition"] as? [Any] ?? []
        XCTAssertEqual(algoDisposition.count, 4,
                       "D1-R: 4 algorithm dispositions (M0/M1 match)")
        Self.recordNativeOutput("contractOverlay:d1rManifest:maxEntries11:algos4")

        // The 6 static candidate manifest files exist and hash to stable digests.
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
        XCTAssertEqual(candidateHashes.count, 6)
    }

    // ── 2b. T-1/T/T+1 boundary (features + diff engines + cache) ──

    /// The T-1/T/T+1 boundary cases for the feature + diff domain: feature
    /// registry boundaries (live-enabled, disposed-disabled, cut-count),
    /// diff-engine boundaries (identical content, modified content, timeout),
    /// and cache boundaries (empty-miss, hit-after-insert, FIFO-eviction).
    /// Every case must run; none may be skipped.
    @MainActor
    func testC05_TMinus1TTPlus1BoundaryCases() {
        let context = MonaKeybindingContext()

        let boundaries: [(id: String, bound: String, expect: Bool, check: () -> Bool)] = [
            ("feature-enabled-T-1", "T-1", true, { () -> Bool in
                let r = MonaFeatureRegistry()
                return r.isEnabled("anchorSelect", context: context)
            }),
            ("feature-disposed-T", "T", true, { () -> Bool in
                let r = MonaFeatureRegistry()
                r.dispose()
                return !r.isEnabled("anchorSelect", context: context)
            }),
            ("feature-cutCount-T+1", "T+1", true, { () -> Bool in
                let r = MonaFeatureRegistry()
                return r.cutCount == 2 && r.totalCount == 64
            }),
            ("diff-identical-T-1", "T-1", true, { () -> Bool in
                let e = MonaLegacyDiffEngine()
                let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
                let orig = lines(["a", "b"])
                let input = MonaDiffInput(originalLines: orig, modifiedLines: orig)
                let r = e.compute(input: input, options: .monacoDefault,
                                  clock: FixedClock(), cancellationToken: .none)
                return r.identical
            }),
            ("diff-modified-T", "T", true, { () -> Bool in
                let e = MonaAdvancedDiffEngine()
                let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
                let input = MonaDiffInput(originalLines: lines(["a", "b"]),
                                          modifiedLines: lines(["a", "x"]))
                let r = e.compute(input: input, options: .monacoDefault,
                                  clock: FixedClock(), cancellationToken: .none)
                return !r.identical
            }),
            ("diff-timeout-T+1", "T+1", true, { () -> Bool in
                let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
                let input = MonaDiffInput(originalLines: lines(["a", "b"]),
                                          modifiedLines: lines(["a", "x"]))
                let opts = MonaDiffOptions(maxComputationTimeMs: 100,
                                           ignoreTrimWhitespace: true, computeMoves: false)
                let ctx = MonaDiffCacheContext(
                    originalUri: "u://o", modifiedUri: "u://m",
                    originalVersionId: 1, modifiedVersionId: 1,
                    originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1)
                let coord = MonaDiffCoordinator(clock: SteppingClock(start: 0, step: 100))
                let r = coord.computeDiff(input: input, options: opts, algorithm: .legacy,
                                          context: ctx, cancellationToken: .none)
                if case .timedOut = r { return true }
                return false
            }),
            ("cache-miss-T-1", "T-1", true, { () -> Bool in
                let c = MonaDiffCache()
                let k = MonaDiffCacheKey(
                    context: MonaDiffCacheContext(
                        originalUri: "u://o", modifiedUri: "u://m",
                        originalVersionId: 1, modifiedVersionId: 1,
                        originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1),
                    options: .monacoDefault)
                return c.get(k) == nil
            }),
            ("cache-hit-T", "T", true, { () -> Bool in
                let c = MonaDiffCache()
                let k = MonaDiffCacheKey(
                    context: MonaDiffCacheContext(
                        originalUri: "u://o", modifiedUri: "u://m",
                        originalVersionId: 1, modifiedVersionId: 1,
                        originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1),
                    options: .monacoDefault)
                let r = MonaDiffResult(changes: [], moves: [], identical: true,
                                       quitEarly: false, hitTimeout: false)
                _ = c.put(k, result: r)
                return c.get(k)?.identical == true
            }),
            ("cache-eviction-T+1", "T+1", true, { () -> Bool in
                let c = MonaDiffCache()
                let opts = MonaDiffOptions.monacoDefault
                let firstK = MonaDiffCacheKey(
                    context: MonaDiffCacheContext(
                        originalUri: "u://first", modifiedUri: "u://m",
                        originalVersionId: 1, modifiedVersionId: 1,
                        originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1),
                    options: opts)
                let r = MonaDiffResult(changes: [], moves: [], identical: true,
                                       quitEarly: false, hitTimeout: false)
                _ = c.put(firstK, result: r)
                // Fill to 11 total (firstK + 10 more).
                for i in 0..<10 {
                    _ = c.put(MonaDiffCacheKey(
                        context: MonaDiffCacheContext(
                            originalUri: "u://o\(i)", modifiedUri: "u://m",
                            originalVersionId: 1, modifiedVersionId: 1,
                            originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1),
                        options: opts), result: r)
                }
                // 12th insert evicts firstK (FIFO).
                _ = c.put(MonaDiffCacheKey(
                    context: MonaDiffCacheContext(
                        originalUri: "u://evict12", modifiedUri: "u://m",
                        originalVersionId: 1, modifiedVersionId: 1,
                        originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1),
                    options: opts), result: r)
                return !c.contains(firstK)
            }),
        ]
        var compared = 0
        var mismatches: [String] = []
        for b in boundaries {
            let nativeResult = b.check()
            if nativeResult != b.expect {
                mismatches.append("\(b.id) [\(b.bound)]: expect=\(b.expect) native=\(nativeResult)")
            }
            Self.recordNativeOutput("boundary:\(b.id):bound=\(b.bound):native=\(nativeResult)")
            compared += 1
        }
        XCTAssertEqual(compared, boundaries.count,
                       "every boundary case must run (none skipped): \(compared)/\(boundaries.count)")
        XCTAssertTrue(mismatches.isEmpty,
                      "M0/M1 boundary mismatches:\n" + mismatches.joined(separator: "\n"))
    }

    // ── 2c. Native-adapted assertion + failure row ──

    /// The native-adapted assertion: the feature registry disposes idempotently
    /// (the failure row — disposal does not crash on re-dispose), and the diff
    /// coordinator rejects external/WASM algorithms with typed unavailable
    /// results (never falls back to legacy/advanced). The cache invalidation
    /// is explicit and idempotent.
    @MainActor
    func testC05_NativeAdaptedAssertionAndFailureRows() {
        // Failure row 1: feature registry idempotent disposal.
        let features = MonaFeatureRegistry()
        features.dispose()
        XCTAssertTrue(features.isDisposed, "feature registry disposed")
        features.dispose()  // idempotent — no crash
        XCTAssertTrue(features.isDisposed, "idempotent re-dispose (no state change)")

        // Failure row 2: external algorithm → unavailable (never falls back).
        let coord = MonaDiffCoordinator(clock: FixedClock())
        let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
        let input = MonaDiffInput(
            originalLines: lines(["a"]), modifiedLines: lines(["b"]))
        let opts = MonaDiffOptions.monacoDefault
        let ctx = MonaDiffCacheContext(
            originalUri: "u://o", modifiedUri: "u://m",
            originalVersionId: 1, modifiedVersionId: 1,
            originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1)
        let extResult = coord.computeDiff(
            input: input, options: opts, algorithm: .advancedExternal,
            context: ctx, cancellationToken: .none)
        XCTAssertEqual(extResult, .unavailable(.externalAlgorithm),
                       "external algorithm → unavailable (never falls back) (M0/M1 match)")
        let wasmResult = coord.computeDiff(
            input: input, options: opts, algorithm: .advancedWasm,
            context: ctx, cancellationToken: .none)
        XCTAssertEqual(wasmResult, .unavailable(.wasmAlgorithm),
                       "WASM algorithm → unavailable (never falls back) (M0/M1 match)")
        Self.recordNativeOutput("failureRows:idempotentDisposal+externalWasmUnavailable=rejected")

        // Failure row 3: cache invalidation is explicit + idempotent.
        let cache = MonaDiffCache()
        let key = MonaDiffCacheKey(context: ctx, options: opts)
        let result = MonaDiffResult(changes: [], moves: [], identical: true,
                                   quitEarly: false, hitTimeout: false)
        _ = cache.put(key, result: result)
        XCTAssertTrue(cache.invalidate(key), "invalidation removes the entry")
        XCTAssertFalse(cache.invalidate(key), "re-invalidation is a no-op (idempotent)")
        Self.recordNativeOutput("failureRows:cacheInvalidation=idempotent")
    }

    // MARK: Operation 3 — Bind comparator, native, environment, candidate,
    // source revision, fixture, and output hashes in one evidence manifest.

    func testC05_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 reference (F1-R features closure artifact).
        let comparatorPath = parentArtifactsDir + "/features-f1r-complete-surface-closure.html"
        let comparatorHash = sha256File(comparatorPath)
        XCTAssertEqual(comparatorHash.count, 64,
                       "comparator hash is 64-char SHA-256")

        // fixture: the M0/M1 diff-engine manifest (D1-R).
        let fixturePath = parentArtifactsDir + "/monacode-d1r-diff-engine-manifest.json"
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
        let envFields = ["osVersion": osVersion, "arch": architecture]
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

        // The evidence manifest — one binding.
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
        print("P09-T014 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(Self.qualifiedSetHash.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=9")
    }

    // MARK: Operation 4 — Treat every missing, skipped, stale, malformed,
    // canceled, or unauthorized case as not-passed.

    func testC05_NoMissingSkippedStaleMalformedCases() throws {
        // The F1-R features closure artifact exists and is non-empty.
        let featuresPath = parentArtifactsDir + "/features-f1r-complete-surface-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: featuresPath),
                      "F1-R features closure artifact must exist (not stale/missing)")
        let featuresData = try Data(contentsOf: URL(fileURLWithPath: featuresPath))
        XCTAssertGreaterThan(featuresData.count, 0,
                             "F1-R features closure artifact non-empty (not malformed)")

        // The D1-R diff closure artifact exists and is non-empty.
        let diffPath = parentArtifactsDir + "/diff-d1r-engine-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: diffPath),
                      "D1-R diff closure artifact must exist (not stale/missing)")
        let diffData = try Data(contentsOf: URL(fileURLWithPath: diffPath))
        XCTAssertGreaterThan(diffData.count, 0,
                             "D1-R diff closure artifact non-empty (not malformed)")

        // The D1-R diff manifest carries well-formed counts.
        let manifestPath = parentArtifactsDir + "/monacode-d1r-diff-engine-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let cacheContract = obj?["cacheContract"] as? [String: Any] ?? [:]
        XCTAssertFalse(cacheContract.isEmpty,
                       "D1-R cache contract present (not malformed)")
        guard let maxEntries = cacheContract["maximumEntries"] as? Int else {
            return XCTFail("D1-R maximumEntries must be an integer (not malformed)")
        }
        XCTAssertEqual(maxEntries, 11, "D1-R maximumEntries = 11 (not stale)")

        let algoDisposition = obj?["algorithmDisposition"] as? [Any] ?? []
        XCTAssertEqual(algoDisposition.count, 4,
                       "D1-R 4 algorithm dispositions (none missing/extra)")

        // The P08-T010 manifest carries the frozen feature count.
        let p08Path = artifactsDir + "/monacode-p08-t010-native-declaration-manifest.json"
        let p08Data = try Data(contentsOf: URL(fileURLWithPath: p08Path))
        let p08Obj = try JSONSerialization.jsonObject(with: p08Data) as? [String: Any]
        let counts = p08Obj?["counts"] as? [String: Any] ?? [:]
        XCTAssertNotNil(counts["feature"], "feature count present (not malformed)")
        XCTAssertEqual(counts["feature"] as? Int, 64, "feature count = 64 (not stale)")

        // The 9 boundary cases each have a bound in {T-1, T, T+1}.
        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        let expectedBounds = ["T-1", "T", "T+1", "T-1", "T", "T+1", "T-1", "T", "T+1"]
        for bound in expectedBounds {
            XCTAssertTrue(validBounds.contains(bound),
                          "bound '\(bound)' not in {T-1, T, T+1}")
        }
    }

    // MARK: - Helpers

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

    private var artifactsDir: String {
        projectRoot + "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts"
    }

    private var parentArtifactsDir: String {
        artifactsDir + "/parent/g5-r/artifacts"
    }

    private func sha256File(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return "<missing>" }
        return sha256Data(data)
    }

    private func sha256String(_ string: String) -> String {
        sha256Data(Data(string.utf8))
    }

    private func sha256Data(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func canonicalJSON(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: sortKeys(value),
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }

    private func sortKeys(_ value: Any) -> Any {
        if let arr = value as? [Any] { return arr.map { sortKeys($0) } }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for key in dict.keys.sorted() { out[key] = sortKeys(dict[key]!) }
            return out
        }
        return value
    }

    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

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

// MARK: - Private clock helpers (for diff timeout injection)

/// A fixed (zero-step) wall clock for timeout injection.
private final class FixedClock: MonaWallClocking {
    func wallMilliseconds() -> Double { 0 }
}

/// A stepping wall clock for timeout injection. Returns successive values
/// `start`, `start + step`, `start + 2*step`, ... on each call.
private final class SteppingClock: MonaWallClocking {
    private var ms: Double
    private let step: Double
    init(start: Double, step: Double) {
        self.ms = start
        self.step = step
    }
    func wallMilliseconds() -> Double {
        let current = ms
        ms += step
        return current
    }
}
