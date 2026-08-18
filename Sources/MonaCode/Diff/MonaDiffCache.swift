// MonaDiffCache.swift
//
// P07-T002 — Close diff timeouts, caches, maximum size, and unavailable external paths.
//
// `MonaDiffCache` is the bounded diff-result cache that sits under
// `MonaDiffCoordinator`. It is the Swift counterpart of Monaco's
// `DiffProviderFactoryService` static Map (monaco-editor 0.56.0,
// `esm/vs/editor/browser/widget/diffEditor/diffProviderFactoryService.js`):
// keyed by the original/modified URI pair with a context of model version ids
// + alternative versions + options, and an insertion-order eviction that
// checks `size > 10` before insert — so the hard maximum is exactly 11.
//
// Frozen truths (D1-R.cache, from `diff-d1r-engine-closure`):
//
//   - The cache holds AT MOST 11 entries. The bound is frozen.
//   - The key is the original/modified URI pair; the context is model version
//     ids + alternative versions + options. Together they uniquely identify a
//     diff input.
//   - Eviction is INSERTION-ORDER (FIFO), not LRU: a read hit does NOT update
//     recency. Before insert, when `size > 10` (i.e. the cache is at the 11
//     bound), the oldest insertion is evicted.
//   - `dispose` does not actively invalidate; the context prevents a stale hit
//     (a stale version id changes the key, so it misses).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The cache context: the original/modified URI pair plus the model version ids
/// and alternative version ids that, together with the options, uniquely
/// identify a diff input at capture time.
///
/// A bump in either model's version id (a direct mutation, an edit
/// transaction, or a flush) changes the context, so the key changes and the
/// stale entry misses — this is the "context prevents stale hit" guarantee.
public struct MonaDiffCacheContext: Equatable, Hashable, Sendable {

    /// The original (left) model URI string.
    public let originalUri: String

    /// The modified (right) model URI string.
    public let modifiedUri: String

    /// The original model's version id at capture time.
    public let originalVersionId: Int

    /// The modified model's version id at capture time.
    public let modifiedVersionId: Int

    /// The original model's alternative version id at capture time.
    public let originalAlternativeVersionId: Int

    /// The modified model's alternative version id at capture time.
    public let modifiedAlternativeVersionId: Int

    /// Creates a cache context.
    public init(
        originalUri: String,
        modifiedUri: String,
        originalVersionId: Int,
        modifiedVersionId: Int,
        originalAlternativeVersionId: Int,
        modifiedAlternativeVersionId: Int
    ) {
        self.originalUri = originalUri
        self.modifiedUri = modifiedUri
        self.originalVersionId = originalVersionId
        self.modifiedVersionId = modifiedVersionId
        self.originalAlternativeVersionId = originalAlternativeVersionId
        self.modifiedAlternativeVersionId = modifiedAlternativeVersionId
    }
}

/// The exact cache key: the URI pair + version ids + alternative versions +
/// the options hash. Two keys are equal only when the entire diff input
/// (documents, versions, and options) matches.
public struct MonaDiffCacheKey: Equatable, Hashable, @unchecked Sendable {

    /// The URI pair and version/alternative-version context.
    public let context: MonaDiffCacheContext

    /// A stable hash of the diff options (`maxComputationTimeMs`,
    /// `ignoreTrimWhitespace`, `computeMoves`).
    public let optionsHash: Int

    /// Creates a cache key from a context and options.
    public init(context: MonaDiffCacheContext, options: MonaDiffOptions) {
        self.context = context
        var hasher = Hasher()
        hasher.combine(options.maxComputationTimeMs)
        hasher.combine(options.ignoreTrimWhitespace)
        hasher.combine(options.computeMoves)
        self.optionsHash = hasher.finalize()
    }

    /// Creates a cache key from a context and a precomputed options hash.
    public init(context: MonaDiffCacheContext, optionsHash: Int) {
        self.context = context
        self.optionsHash = optionsHash
    }
}

/// The bounded diff-result cache (max 11 entries, insertion-order eviction).
///
/// The frozen bound (`maxEntries = 11`) and the insertion-order eviction policy
/// mirror Monaco's `DiffProviderFactoryService` static Map: before each insert,
/// when `size > 10`, the oldest insertion is evicted — so `size = 10` inserts an
/// 11th without eviction, and `size = 11` evicts the oldest before inserting.
/// A read hit does NOT update recency (FIFO, not LRU).
public final class MonaDiffCache: @unchecked Sendable {

    /// The frozen maximum number of entries the cache holds.
    public static let maxEntries: Int = 11

    private let lock = NSLock()

    /// The entries keyed by cache key.
    private var entries: [MonaDiffCacheKey: MonaDiffResult] = [:]

    /// The insertion order (oldest first). A read hit does NOT reorder; an
    /// update of an existing key does NOT reorder. Only new inserts append.
    private var insertionOrder: [MonaDiffCacheKey] = []

    /// Creates an empty diff cache.
    public init() {}

    /// The current number of cached entries.
    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return entries.count
    }

    /// Returns the cached result for `key` (hit), or `nil` (miss). A hit does
    /// NOT update recency — eviction is insertion-order (FIFO), not LRU.
    public func get(_ key: MonaDiffCacheKey) -> MonaDiffResult? {
        lock.lock(); defer { lock.unlock() }
        return entries[key]
    }

    /// `true` when `key` is present in the cache.
    public func contains(_ key: MonaDiffCacheKey) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return entries[key] != nil
    }

    /// Stores `result` for `key`. When the key already exists, the result is
    /// updated IN PLACE (the insertion order is unchanged — an update does not
    /// move the entry to the end). When the key is new and the cache is at the
    /// 11-entry bound, the oldest insertion is evicted first (the frozen
    /// pre-insert `size > 10` check), then the new entry is inserted.
    ///
    /// - Returns: the evicted key when a new insert displaced the oldest
    ///   insertion, or `nil` when no eviction occurred.
    @discardableResult
    public func put(_ key: MonaDiffCacheKey, result: MonaDiffResult) -> MonaDiffCacheKey? {
        lock.lock(); defer { lock.unlock() }
        if entries[key] != nil {
            // Update in place; do NOT change the insertion order.
            entries[key] = result
            return nil
        }
        // New key. Frozen pre-insert eviction: when `size > 10` (i.e. the cache
        // is at the 11-entry bound), evict the oldest insertion before insert.
        var evicted: MonaDiffCacheKey? = nil
        if entries.count > Self.maxEntries - 1 {
            // entries.count == maxEntries (11) here; evict the oldest insertion.
            if let oldest = insertionOrder.first {
                entries.removeValue(forKey: oldest)
                insertionOrder.removeFirst()
                evicted = oldest
            }
        }
        entries[key] = result
        insertionOrder.append(key)
        return evicted
    }

    /// Removes `key` from the cache. Returns `true` when the key was present.
    @discardableResult
    public func invalidate(_ key: MonaDiffCacheKey) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard entries.removeValue(forKey: key) != nil else {
            return false
        }
        if let idx = insertionOrder.firstIndex(of: key) {
            insertionOrder.remove(at: idx)
        }
        return true
    }

    /// Removes every entry from the cache.
    public func invalidateAll() {
        lock.lock(); defer { lock.unlock() }
        entries.removeAll()
        insertionOrder.removeAll()
    }
}
