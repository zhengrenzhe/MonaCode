// MonaNormalizer.swift
//
// P02-T007 — Implement fixed case conversion, collation, and normalization profiles.
//
// NFC/NFD/NFKC/NFKD normalization over raw `[UInt16]` code units with two
// fixed 10000-entry LRU caches and explicit hit/miss/eviction counters. This
// is the Phase-02 normalization profile enumerated by E1-R: only the four
// Unicode normalization forms are exposed.
//
// The four forms delegate to Foundation's Unicode normalization (the
// standard, deterministic algorithm). The fixed profile wrapper restricts
// the surface to exactly NFC/NFD/NFKC/NFKD, and the two bounded caches
// provide predictable memory and observable counters:
//
//   - composeCache   (capacity 10000) — caches NFC and NFKC results.
//   - decomposeCache (capacity 10000) — caches NFD and NFKD results.
//
// Each cache is a least-recently-used map: when full, inserting a new entry
// evicts the least-recently-used one and increments the eviction counter.
// Counters are per-instance (not global).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The four Unicode normalization forms exposed by the Phase-02 profile.
public enum MonaNormalizationForm {
    case nfc
    case nfd
    case nfkc
    case nfkd
}

/// A bounded least-recently-used cache with explicit counters.
///
/// Used internally by `MonaNormalizer` for the two fixed 10000-entry caches.
fileprivate struct MonaLRUCache<Key: Hashable, Value> {

    /// The fixed maximum number of entries the cache holds.
    let capacity: Int

    private var entries: [Key: Value] = [:]
    /// Access order, least-recently-used at the front, most-recently-used at
    /// the back. Maintained alongside `entries` to drive LRU eviction.
    private var order: [Key] = []

    private(set) var hits = 0
    private(set) var misses = 0
    private(set) var evictions = 0

    /// Creates an empty cache with the given fixed capacity.
    fileprivate init(capacity: Int) {
        self.capacity = capacity
    }

    /// The current number of cached entries.
    var count: Int { entries.count }

    /// Returns the cached value for `key`, computing it (via `compute`) and
    /// inserting it on a miss. On access the entry is promoted to
    /// most-recently-used; on insertion past capacity the least-recently-used
    /// entry is evicted and `evictions` is incremented.
    mutating func value(for key: Key, compute: () -> Value) -> Value {
        if let cached = entries[key] {
            hits += 1
            promote(key: key)
            return cached
        }
        misses += 1
        let computed = compute()
        entries[key] = computed
        order.append(key)
        while entries.count > capacity {
            let evictKey = order.removeFirst()
            entries.removeValue(forKey: evictKey)
            evictions += 1
        }
        return computed
    }

    /// Resets all entries and counters. Used by tests.
    mutating func reset() {
        entries.removeAll()
        order.removeAll()
        hits = 0
        misses = 0
        evictions = 0
    }

    private mutating func promote(key: Key) {
        guard let idx = order.firstIndex(where: { $0 == key }) else { return }
        order.remove(at: idx)
        order.append(key)
    }
}

/// The Phase-02 Unicode normalizer with two fixed 10000-entry LRU caches.
///
/// `normalize(_:_:)` returns the NFC/NFD/NFKC/NFKD form of a `[UInt16]`
/// input. Results are cached per form in one of two bounded LRU caches
/// (compose for NFC/NFKC, decompose for NFD/NFKD), each holding at most
/// 10000 entries with explicit hit/miss/eviction counters.
public final class MonaNormalizer {

    /// The fixed capacity of the compose (NFC/NFKC) cache.
    public let composeCacheCapacity: Int = 10_000

    /// The fixed capacity of the decompose (NFD/NFKD) cache.
    public let decomposeCacheCapacity: Int = 10_000

    private var composeCache: MonaLRUCache<CacheKey, [UInt16]>
    private var decomposeCache: MonaLRUCache<CacheKey, [UInt16]>

    /// Creates a normalizer with empty caches.
    public init() {
        composeCache = MonaLRUCache(capacity: 10_000)
        decomposeCache = MonaLRUCache(capacity: 10_000)
    }

    // MARK: - Normalization

    /// Returns the `form` normalization of `input`.
    ///
    /// Results are cached: a repeat call with the same `(form, input)` is a
    /// cache hit (no recomputation). NFC/NFKC share the compose cache;
    /// NFD/NFKD share the decompose cache.
    public func normalize(_ input: [UInt16], _ form: MonaNormalizationForm) -> [UInt16] {
        let key = CacheKey(form: form, input: input)
        switch form {
        case .nfc, .nfkc:
            return composeCache.value(for: key) { MonaNormalizer.compute(input, form: form) }
        case .nfd, .nfkd:
            return decomposeCache.value(for: key) { MonaNormalizer.compute(input, form: form) }
        }
    }

    // MARK: - Cache counters

    /// The current number of entries in the compose (NFC/NFKC) cache.
    public var composeCacheSize: Int { composeCache.count }

    /// The current number of entries in the decompose (NFD/NFKD) cache.
    public var decomposeCacheSize: Int { decomposeCache.count }

    /// Aggregate cache hits across both caches.
    public var cacheHits: Int { composeCache.hits + decomposeCache.hits }

    /// Aggregate cache misses across both caches.
    public var cacheMisses: Int { composeCache.misses + decomposeCache.misses }

    /// Aggregate cache evictions across both caches.
    public var cacheEvictions: Int { composeCache.evictions + decomposeCache.evictions }

    // MARK: - Internals

    fileprivate struct CacheKey: Hashable {
        let form: MonaNormalizationForm
        let input: [UInt16]
    }

    /// Computes the normalization without consulting the cache.
    ///
    /// The input `[UInt16]` is decoded to a Foundation `String`, normalized
    /// with the Foundation Unicode algorithm for the requested form, and
    /// re-encoded to UTF-16 code units. Well-formed inputs round-trip
    /// exactly; ill-formed sequences (lone surrogates) are repaired by the
    /// Foundation decoder and are outside the Phase-02 curated contract.
    fileprivate static func compute(_ input: [UInt16], form: MonaNormalizationForm) -> [UInt16] {
        let string = String(decoding: input, as: UTF16.self)
        let normalized: String
        switch form {
        case .nfc:
            normalized = string.precomposedStringWithCanonicalMapping
        case .nfd:
            normalized = string.decomposedStringWithCanonicalMapping
        case .nfkc:
            normalized = string.precomposedStringWithCompatibilityMapping
        case .nfkd:
            normalized = string.decomposedStringWithCompatibilityMapping
        }
        return Array(normalized.utf16)
    }
}
