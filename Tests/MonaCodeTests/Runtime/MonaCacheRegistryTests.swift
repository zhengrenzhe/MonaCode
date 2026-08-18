// MonaCacheRegistryTests.swift
//
// P07-T007 — Close the bounded cache registry and provisional cache manifest.
//
// Verifies the bounded cache registry (`MonaCacheRegistry`):
//   - Every strong derived cache MonaCode uses is registered with exact owner,
//     key shape, entry bound, byte bound, counter width, invalidation,
//     eviction, and quiescent plateau (H2-R `cacheBounds`).
//   - The specific caches: the four S1-R suggestion caches 300/200/50/20, the
//     two E1-R normalization caches of 10000, and the D1-R maximum-11 diff
//     cache (FIFO).
//   - Unregistered cache allocations are rejected with a typed error (closed
//     set: an unregistered strong derived cache is a release failure).
//   - Signed-counter overflow is rejected with a typed error (no silent wrap,
//     trap, or UB).
//
// On Green, `testExactSetBoundsAndPlateau` prints the contract line:
//     CACHE_REGISTRY exactSet=pass bounds=pass plateau=pass

import XCTest
import MonaCode

final class MonaCacheRegistryTests: XCTestCase {

    // MARK: - Exact set + bounds + plateau

    /// The closed cache set: exactly 7 caches (4 suggestion + 2 normalization
    /// + 1 diff), each registered with every frozen field.
    func testExactSetBoundsAndPlateau() {
        let registrations = MonaCacheRegistry.registrations
        // Exact set: 7 strong derived caches.
        XCTAssertEqual(
            registrations.count,
            7,
            "exactly 7 strong derived caches (4 suggestion + 2 normalization + 1 diff)"
        )
        // Set-equality: no duplicate ids.
        let ids = registrations.map { $0.id }.sorted()
        XCTAssertEqual(Set(ids).count, ids.count, "no duplicate cache ids")

        // Every registration carries every frozen field non-empty/positive.
        for r in registrations {
            XCTAssertFalse(r.owner.isEmpty, "\(r.id) owner must be non-empty")
            XCTAssertFalse(r.keyShape.isEmpty, "\(r.id) keyShape must be non-empty")
            XCTAssertGreaterThan(r.entryBound, 0, "\(r.id) entryBound must be > 0")
            XCTAssertGreaterThanOrEqual(r.byteBound, 0, "\(r.id) byteBound must be >= 0")
            XCTAssertGreaterThan(r.counterWidth, 0, "\(r.id) counterWidth must be > 0")
            XCTAssertFalse(r.invalidation.isEmpty, "\(r.id) invalidation must be non-empty")
            XCTAssertGreaterThan(r.quiescentPlateau, 0, "\(r.id) plateau must be > 0")
            // Plateau is the steady-state settle point: at or below the bound.
            XCTAssertLessThanOrEqual(
                r.quiescentPlateau,
                r.entryBound,
                "\(r.id) plateau (\(r.quiescentPlateau)) must be <= entryBound (\(r.entryBound))"
            )
        }

        // Contract line on Green.
        print("CACHE_REGISTRY exactSet=pass bounds=pass plateau=pass")
    }

    // MARK: - Specific caches (300/200/50/20 + 10000x2 + 11)

    /// The four S1-R suggestion caches: 300 / 200 / 50 / 20.
    func testSuggestionCachesExactBounds() {
        let mem = MonaCacheRegistry.registration(for: .sessionSuggestionMemory)
        XCTAssertEqual(mem.entryBound, 300)
        XCTAssertEqual(mem.eviction, .lru)
        XCTAssertEqual(mem.quiescentPlateau, 300)

        let pre = MonaCacheRegistry.registration(for: .sessionSuggestionPrefix)
        XCTAssertEqual(pre.entryBound, 200)
        XCTAssertEqual(pre.eviction, .lru)
        XCTAssertEqual(pre.quiescentPlateau, 200)

        let mru = MonaCacheRegistry.registration(for: .sessionCommandMRU)
        XCTAssertEqual(mru.entryBound, 50)
        XCTAssertEqual(mru.eviction, .lru)
        XCTAssertEqual(mru.quiescentPlateau, 50)

        let lens = MonaCacheRegistry.registration(for: .sessionCodeLensLRU)
        XCTAssertEqual(lens.entryBound, 20)
        XCTAssertEqual(lens.eviction, .lru)
        XCTAssertEqual(lens.quiescentPlateau, 20)
    }

    /// The two E1-R normalization caches: 10000 each (compose + decompose).
    func testNormalizationCachesExactBounds() {
        let compose = MonaCacheRegistry.registration(for: .normalizerCompose)
        XCTAssertEqual(compose.entryBound, 10000)
        XCTAssertEqual(compose.eviction, .lru)
        XCTAssertEqual(compose.quiescentPlateau, 10000)

        let decompose = MonaCacheRegistry.registration(for: .normalizerDecompose)
        XCTAssertEqual(decompose.entryBound, 10000)
        XCTAssertEqual(decompose.eviction, .lru)
        XCTAssertEqual(decompose.quiescentPlateau, 10000)
    }

    /// The D1-R diff cache: maximum 11, FIFO eviction, exact frozen id.
    func testDiffCacheExactBound() {
        let diff = MonaCacheRegistry.registration(for: .diffDocumentResult)
        XCTAssertEqual(diff.entryBound, 11)
        XCTAssertEqual(diff.eviction, .fifo)
        XCTAssertEqual(diff.quiescentPlateau, 11)
        XCTAssertEqual(diff.id, "diff.document-result.process-fifo")
    }

    // MARK: - Reject unregistered cache allocations

    /// Allocating an unregistered cache is rejected with a typed error (the
    /// closed-set gate: an unregistered strong derived cache is a release
    /// failure).
    func testRejectUnregisteredCacheAllocation() {
        XCTAssertThrowsError(
            try MonaCacheRegistry.allocate("rogue.unregistered.cache")
        ) { err in
            guard case .unregisteredCache(let id) = err as? MonaCacheRegistryError else {
                XCTFail("expected unregisteredCache, got \(err)")
                return
            }
            XCTAssertEqual(id, "rogue.unregistered.cache")
        }
    }

    /// Allocating a registered cache returns its registration.
    func testAllocateRegisteredCache() throws {
        let diff = try MonaCacheRegistry.allocate("diff.document-result.process-fifo")
        XCTAssertEqual(diff.entryBound, 11)
        XCTAssertEqual(diff.eviction, .fifo)
    }

    // MARK: - Reject signed-counter overflow

    /// A signed counter that overflows its declared bit width is rejected
    /// with a typed error (no silent wrap, trap, or UB).
    func testRejectSignedCounterOverflow() {
        let diff = MonaCacheRegistry.registration(for: .diffDocumentResult)
        let width = diff.counterWidth
        let near = MonaCacheRegistry.SignedCounter.maxValue(forWidth: width)
        XCTAssertThrowsError(
            try MonaCacheRegistry.SignedCounter.increment(
                cache: diff.id,
                counter: "hit",
                current: near,
                by: 1,
                width: width
            )
        ) { err in
            guard case .counterOverflow(let cache, let counter, let width) =
                err as? MonaCacheRegistryError else {
                XCTFail("expected counterOverflow, got \(err)")
                return
            }
            XCTAssertEqual(cache, "diff.document-result.process-fifo")
            XCTAssertEqual(counter, "hit")
            XCTAssertEqual(width, diff.counterWidth)
        }
    }

    /// A non-overflowing increment returns the new value.
    func testCounterIncrementWithinBounds() throws {
        let diff = MonaCacheRegistry.registration(for: .diffDocumentResult)
        let next = try MonaCacheRegistry.SignedCounter.increment(
            cache: diff.id,
            counter: "hit",
            current: 0,
            by: 1,
            width: diff.counterWidth
        )
        XCTAssertEqual(next, 1)
    }

    // MARK: - Reject bound exceeded (CACHE_BOUND_EXCEEDED)

    /// Inserting past the frozen entry bound is rejected with the exact
    /// `CACHE_BOUND_EXCEEDED cache=diff actual=12 max=11` message.
    func testRejectBoundExceededDiff() {
        let diff = MonaCacheRegistry.registration(for: .diffDocumentResult)
        XCTAssertThrowsError(
            try MonaCacheRegistry.checkEntryBound(
                cache: diff.id,
                actual: 12,
                max: diff.entryBound
            )
        ) { err in
            guard case .boundExceeded(let cache, let actual, let max) =
                err as? MonaCacheRegistryError else {
                XCTFail("expected boundExceeded, got \(err)")
                return
            }
            XCTAssertEqual(cache, "diff.document-result.process-fifo")
            XCTAssertEqual(actual, 12)
            XCTAssertEqual(max, 11)
            // The error description carries the exact contract message.
            let desc = String(describing: err)
            XCTAssertTrue(desc.contains("CACHE_BOUND_EXCEEDED"), desc)
            XCTAssertTrue(desc.contains("cache=diff"), desc)
            XCTAssertTrue(desc.contains("actual=12"), desc)
            XCTAssertTrue(desc.contains("max=11"), desc)
        }
    }

    /// An entry count at or below the bound is accepted.
    func testBoundCheckAcceptsAtOrBelow() throws {
        let diff = MonaCacheRegistry.registration(for: .diffDocumentResult)
        XCTAssertNoThrow(
            try MonaCacheRegistry.checkEntryBound(
                cache: diff.id, actual: 11, max: diff.entryBound
            )
        )
        XCTAssertNoThrow(
            try MonaCacheRegistry.checkEntryBound(
                cache: diff.id, actual: 0, max: diff.entryBound
            )
        )
    }
}
