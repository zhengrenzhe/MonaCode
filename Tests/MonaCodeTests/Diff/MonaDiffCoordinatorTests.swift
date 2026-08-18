// MonaDiffCoordinatorTests.swift
//
// P07-T002 — Close diff timeouts, caches, maximum size, and unavailable external paths.
//
// Verifies the diff coordinator + cache: the T-1/T/T+1 timeout truth under an
// injected wall clock, the bounded maximum-11 cache (exact key, hit, miss,
// invalidation, insertion-order eviction at the 11-bound), the explicit no-op
// results for max-file-size and external/WASM-unavailable algorithm paths, and
// the version-gated publication that drops stale or non-complete results.
//
// On Green, `testContractBehavior` prints the contract line:
//     DIFF_COORDINATOR timeout=exact cacheMax=11 external=unavailable

import XCTest
import Foundation
import MonaCode

final class MonaDiffCoordinatorTests: XCTestCase {

    // MARK: - Helpers

    /// Converts an array of strings into an array of raw UTF-16 lines.
    private func lines(_ ss: [String]) -> [[UInt16]] {
        return ss.map { Array($0.utf16) }
    }

    /// A controllable wall clock for timeout injection (E1-R wall-clock domain).
    /// Returns successive values `start`, `start + step`, `start + 2*step`, ...
    /// on each `wallMilliseconds()` call, so tests can place time exactly at
    /// T-1, T, or T+1 relative to a budget.
    private final class TestWallClock: MonaWallClocking {
        private var ms: Double
        private let step: Double
        init(start: Double = 0, step: Double = 0) {
            self.ms = start
            self.step = step
        }
        func wallMilliseconds() -> Double {
            let current = ms
            ms += step
            return current
        }
    }

    /// A small diff input that the legacy engine processes in one line phase +
    /// one character phase, exercising the frozen timeout checkpoints.
    private var sampleInput: MonaDiffInput {
        MonaDiffInput(originalLines: lines(["a", "b", "c"]), modifiedLines: lines(["a", "x", "c"]))
    }

    private var defaultOptions: MonaDiffOptions {
        MonaDiffOptions(maxComputationTimeMs: 5000, ignoreTrimWhitespace: true, computeMoves: false)
    }

    /// A cache context for key construction (URI pair + version IDs + alt versions).
    private func context(_ suffix: String, ov: Int = 1, mv: Int = 1) -> MonaDiffCacheContext {
        return MonaDiffCacheContext(
            originalUri: "monacode://diff/original/\(suffix)",
            modifiedUri: "monacode://diff/modified/\(suffix)",
            originalVersionId: ov,
            modifiedVersionId: mv,
            originalAlternativeVersionId: ov,
            modifiedAlternativeVersionId: mv
        )
    }

    private func budgetOptions(_ budget: Int) -> MonaDiffOptions {
        MonaDiffOptions(maxComputationTimeMs: budget, ignoreTrimWhitespace: true, computeMoves: false)
    }

    // MARK: - 1. T-1, T, and T+1 timeout truth (injected monotonic wall clock)

    func testTimeoutTMinusOneTPlusOne() {
        let budget = 100
        let t = Double(budget)

        // T-1: stepping clock advances (t-1) ms between the start read and the
        // first frozen checkpoint → elapsed 99 < 100 → the diff completes.
        let coordTMinus1 = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: t - 1),
            legacyEngine: MonaLegacyDiffEngine(),
            advancedEngine: MonaAdvancedDiffEngine()
        )
        let resTMinus1 = coordTMinus1.computeDiff(
            input: sampleInput, options: budgetOptions(budget),
            algorithm: .legacy, context: context("t-1"), cancellationToken: .none
        )
        guard case .complete(let completeResult) = resTMinus1 else {
            XCTFail("T-1 (elapsed \(t - 1) < \(budget)) must complete; got \(resTMinus1)")
            return
        }
        XCTAssertFalse(completeResult.quitEarly, "T-1 must not quit early")
        XCTAssertFalse(completeResult.hitTimeout, "T-1 must not hit timeout")

        // T: elapsed = 100 == budget → the strict `elapsed < limit` fails →
        // timeout. The result must be `.timedOut` with quitEarly + hitTimeout.
        let coordT = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: t),
            legacyEngine: MonaLegacyDiffEngine(),
            advancedEngine: MonaAdvancedDiffEngine()
        )
        let resT = coordT.computeDiff(
            input: sampleInput, options: budgetOptions(budget),
            algorithm: .legacy, context: context("t"), cancellationToken: .none
        )
        guard case .timedOut(let timedResult) = resT else {
            XCTFail("T (elapsed \(t) == budget \(budget)) must time out; got \(resT)")
            return
        }
        XCTAssertTrue(timedResult.quitEarly, "T must quit early")
        XCTAssertTrue(timedResult.hitTimeout, "T must record hitTimeout")

        // T+1: elapsed = 101 > budget → timeout as well.
        let coordTPlus1 = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: t + 1),
            legacyEngine: MonaLegacyDiffEngine(),
            advancedEngine: MonaAdvancedDiffEngine()
        )
        let resTPlus1 = coordTPlus1.computeDiff(
            input: sampleInput, options: budgetOptions(budget),
            algorithm: .legacy, context: context("t+1"), cancellationToken: .none
        )
        guard case .timedOut(let tpResult) = resTPlus1 else {
            XCTFail("T+1 (elapsed \(t + 1) > \(budget)) must time out; got \(resTPlus1)")
            return
        }
        XCTAssertTrue(tpResult.quitEarly, "T+1 must quit early")
        XCTAssertTrue(tpResult.hitTimeout, "T+1 must record hitTimeout")
    }

    // MARK: - 2. Bounded maximum-11 cache: key, hit, miss, invalidation, eviction

    func testCacheHitMissInvalidationEviction() {
        let cache = MonaDiffCache()
        XCTAssertEqual(MonaDiffCache.maxEntries, 11, "the frozen cache bound is 11")
        XCTAssertEqual(cache.count, 0)

        // 11 distinct keys, each with a distinct result.
        var keys: [MonaDiffCacheKey] = []
        for i in 1...11 {
            let key = MonaDiffCacheKey(context: context("k\(i)"), options: defaultOptions)
            keys.append(key)
            let evicted = cache.put(key, result: MonaDiffResult())
            XCTAssertNil(evicted, "insert \(i) must not evict (under the bound)")
            XCTAssertEqual(cache.count, i, "count after inserting \(i)")
        }
        XCTAssertEqual(cache.count, 11, "the cache holds at most 11 entries")

        // Hit: key present → return cached.
        XCTAssertNotNil(cache.get(keys[0]), "key1 must be a hit (present)")
        // Miss: key absent → nil.
        let missKey = MonaDiffCacheKey(context: context("miss"), options: defaultOptions)
        XCTAssertNil(cache.get(missKey), "an unknown key must be a miss")

        // FIFO ordering: a hit must NOT update recency. Access key1 (oldest),
        // then insert a 12th key; the oldest insertion (key1) must be evicted,
        // not the least-recently-used (key2). This distinguishes insertion-
        // order eviction from LRU.
        _ = cache.get(keys[0])  // hit on the oldest key
        let key12 = MonaDiffCacheKey(context: context("k12"), options: defaultOptions)
        let evictedKey = cache.put(key12, result: MonaDiffResult())
        XCTAssertEqual(evictedKey, keys[0], "FIFO: the oldest insertion (key1) is evicted, not key2")
        XCTAssertEqual(cache.count, 11, "count stays at the bound after a replacement insert")
        XCTAssertNil(cache.get(keys[0]), "evicted key1 is now a miss")
        XCTAssertNotNil(cache.get(key12), "key12 is present")
        XCTAssertNotNil(cache.get(keys[1]), "key2 is still present")

        // Invalidation: remove a single key.
        XCTAssertTrue(cache.invalidate(keys[1]), "invalidate an existing key")
        XCTAssertNil(cache.get(keys[1]), "invalidated key is now a miss")
        XCTAssertEqual(cache.count, 10)
        XCTAssertFalse(cache.invalidate(keys[1]), "invalidating an absent key is false")

        // Invalidation of all: clear.
        cache.invalidateAll()
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.get(keys[2]))
    }

    // MARK: - 3. No-op for max-file-size and external/WASM-unavailable paths

    func testNoOpForMaxFileSize() {
        // A tiny threshold so the test stays fast (the frozen default is 50 MiU16).
        let coordinator = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: 0),
            legacyEngine: MonaLegacyDiffEngine(),
            advancedEngine: MonaAdvancedDiffEngine(),
            maxFileSizeMiU16: 5
        )
        // 6 code units > 5 → exceeds the max-file-size gate.
        let tooLarge = MonaDiffInput(
            originalLines: lines(["abcdef"]),  // 6 units
            modifiedLines: lines(["abc"])
        )
        let res = coordinator.computeDiff(
            input: tooLarge, options: defaultOptions, algorithm: .legacy,
            context: context("big"), cancellationToken: .none
        )
        guard case .unavailable(let reason) = res else {
            XCTFail("max-file-size input must return .unavailable; got \(res)")
            return
        }
        XCTAssertEqual(reason, .maxFileSize, "the reason must be maxFileSize")

        // Under the threshold → the diff runs (not unavailable).
        let small = MonaDiffInput(
            originalLines: lines(["abc"]), modifiedLines: lines(["abd"])
        )
        let smallRes = coordinator.computeDiff(
            input: small, options: defaultOptions, algorithm: .legacy,
            context: context("small"), cancellationToken: .none
        )
        if case .unavailable = smallRes {
            XCTFail("input under the max-file-size gate must not be unavailable")
        }
    }

    func testNoOpForExternalAndWasmAlgorithms() {
        let coordinator = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: 0),
            legacyEngine: MonaLegacyDiffEngine(),
            advancedEngine: MonaAdvancedDiffEngine()
        )
        // advancedExternal and advancedWasm are retained enum values that are
        // always unavailable in the fixed baseline; the coordinator returns an
        // explicit no-op without loading any external code.
        let externalRes = coordinator.computeDiff(
            input: sampleInput, options: defaultOptions, algorithm: .advancedExternal,
            context: context("ext"), cancellationToken: .none
        )
        guard case .unavailable(let extReason) = externalRes else {
            XCTFail("advancedExternal must return .unavailable; got \(externalRes)")
            return
        }
        XCTAssertEqual(extReason, .externalAlgorithm, "the reason must be externalAlgorithm")

        let wasmRes = coordinator.computeDiff(
            input: sampleInput, options: defaultOptions, algorithm: .advancedWasm,
            context: context("wasm"), cancellationToken: .none
        )
        guard case .unavailable(let wasmReason) = wasmRes else {
            XCTFail("advancedWasm must return .unavailable; got \(wasmRes)")
            return
        }
        XCTAssertEqual(wasmReason, .wasmAlgorithm, "the reason must be wasmAlgorithm")

        // The functional algorithms are NOT unavailable.
        let legacyRes = coordinator.computeDiff(
            input: sampleInput, options: defaultOptions, algorithm: .legacy,
            context: context("legacy"), cancellationToken: .none
        )
        if case .unavailable = legacyRes {
            XCTFail("legacy must not be unavailable")
        }
    }

    // MARK: - 4. Version-gated publication (stale → drop, non-complete → drop)

    func testVersionGatedPublicationStaleDropped() {
        let originalModel = MonaCodeModel(text: "a\nb\nc", uri: MonaURI(scheme: "monacode", path: "/o"))
        let modifiedModel = MonaCodeModel(text: "a\nx\nc", uri: MonaURI(scheme: "monacode", path: "/m"))
        let originalGate = MonaPublicationGate(model: originalModel)
        let modifiedGate = MonaPublicationGate(model: modifiedModel)

        // Capture the validity snapshot at compute time.
        let snapshot = MonaDiffValiditySnapshot(
            originalTicket: originalGate.captureTicket(),
            modifiedTicket: modifiedGate.captureTicket()
        )

        let coordinator = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: 0),
            legacyEngine: MonaLegacyDiffEngine(),
            advancedEngine: MonaAdvancedDiffEngine()
        )
        let result = coordinator.computeDiff(
            input: MonaDiffInput(
                originalLines: lines(["a", "b", "c"]),
                modifiedLines: lines(["a", "x", "c"])
            ),
            options: defaultOptions,
            algorithm: .legacy,
            context: context("pub", ov: originalModel.getVersionId(), mv: modifiedModel.getVersionId()),
            cancellationToken: .none
        )
        guard case .complete = result else {
            XCTFail("the diff must complete for publication; got \(result)")
            return
        }

        // Fresh snapshot → publish.
        var published = false
        let ok = coordinator.publishDiff(
            result, snapshot: snapshot,
            originalGate: originalGate, modifiedGate: modifiedGate
        ) { _ in published = true }
        XCTAssertTrue(ok, "a fresh, complete result must be published")
        XCTAssertTrue(published, "the receive closure must be invoked on publish")

        // Stale: mutate the original model (bump versionId) → snapshot is stale.
        originalModel.setValue("a\nB\nc")
        var stalePublished = false
        let staleOk = coordinator.publishDiff(
            result, snapshot: snapshot,
            originalGate: originalGate, modifiedGate: modifiedGate
        ) { _ in stalePublished = true }
        XCTAssertFalse(staleOk, "a stale result must be dropped (not published)")
        XCTAssertFalse(stalePublished, "the receive closure must NOT be invoked on a stale result")

        // Non-complete (timed out) → dropped even with a fresh snapshot.
        let timedOut = MonaDiffCoordinatorResult.timedOut(
            MonaDiffResult(quitEarly: true, hitTimeout: true)
        )
        var nonCompletePublished = false
        let nonOk = coordinator.publishDiff(
            timedOut, snapshot: snapshot,
            originalGate: originalGate, modifiedGate: modifiedGate
        ) { _ in nonCompletePublished = true }
        XCTAssertFalse(nonOk, "a non-complete (timed out) result must not be published")
        XCTAssertFalse(nonCompletePublished, "receive must NOT be invoked for a non-complete result")
    }

    // MARK: - Contract behavior print

    func testContractBehavior() {
        let legacy = MonaLegacyDiffEngine()
        let advanced = MonaAdvancedDiffEngine()

        // timeout = exact (T-1 completes, T times out, T+1 times out).
        let budget = 100
        let t = Double(budget)
        let coordMinus = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: t - 1),
            legacyEngine: legacy, advancedEngine: advanced
        )
        let rMinus = coordMinus.computeDiff(
            input: sampleInput, options: budgetOptions(budget),
            algorithm: .legacy, context: context("cb-1"), cancellationToken: .none
        )
        let coordT = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: t),
            legacyEngine: legacy, advancedEngine: advanced
        )
        let rT = coordT.computeDiff(
            input: sampleInput, options: budgetOptions(budget),
            algorithm: .legacy, context: context("cb0"), cancellationToken: .none
        )
        let coordPlus = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: t + 1),
            legacyEngine: legacy, advancedEngine: advanced
        )
        let rPlus = coordPlus.computeDiff(
            input: sampleInput, options: budgetOptions(budget),
            algorithm: .legacy, context: context("cb+1"), cancellationToken: .none
        )
        let timeoutIsExact: String = {
            if case .complete(let c) = rMinus, !c.quitEarly, !c.hitTimeout,
               case .timedOut(let tt) = rT, tt.quitEarly, tt.hitTimeout,
               case .timedOut(let tp) = rPlus, tp.quitEarly, tp.hitTimeout {
                return "exact"
            }
            return "mismatch"
        }()

        // cacheMax = 11.
        let cache = MonaDiffCache()
        let cacheMax: String = (MonaDiffCache.maxEntries == 11 && cache.count == 0) ? "11" : "wrong"

        // external = unavailable.
        let coord = MonaDiffCoordinator(
            clock: TestWallClock(start: 0, step: 0),
            legacyEngine: legacy, advancedEngine: advanced
        )
        let extRes = coord.computeDiff(
            input: sampleInput, options: defaultOptions,
            algorithm: .advancedExternal, context: context("cb-ext"), cancellationToken: .none
        )
        let externalUnavailable: String = {
            if case .unavailable(.externalAlgorithm) = extRes { return "unavailable" }
            return "loaded"
        }()

        print("DIFF_COORDINATOR timeout=\(timeoutIsExact) cacheMax=\(cacheMax) external=\(externalUnavailable)")
    }
}
