// MonaCacheRegistry.swift
//
// P07-T007 — Close the bounded cache registry and provisional cache manifest.
//
// `MonaCacheRegistry` is the bounded cache registry — the closed set of every
// strong derived cache MonaCode uses. It is the Swift counterpart of the
// H2-R `derivedCacheManifest` rule (monaco-editor 0.56.0, fixed by the
// H2-R `runtime-h2r-global-lifetime-resource-closure`):
//
//   "every strong derived cache in a product target registers one stable ID
//    and records owner scope, key, maximum entries or bytes, eviction order,
//    invalidation epochs, memory-pressure action and instrumentation counter"
//
// and the closed-set gate:
//
//   "the linked product cache registry and MonaCacheManifest IDs must be
//    set-equal; an unregistered strong derived cache is a release failure"
//
// Frozen truths (from the G6-R contract artifacts):
//
//   - The closed set has exactly 7 strong derived caches:
//       * 4 S1-R suggestion caches (300 / 200 / 50 / 20) — LRU.
//       * 2 E1-R normalization caches (10000 each) — LRU (compose + decompose).
//       * 1 D1-R diff cache (maximum 11) — insertion-order (FIFO).
//   - Each registration carries: owner (which subsystem owns it), key shape
//     (the cache key's structure), entry bound (max entries), byte bound
//     (max bytes; 0 = entry-bound only), counter width (the instrumentation
//     counter's signed bit width), invalidation (when/how it invalidates),
//     eviction (FIFO or LRU), and quiescent plateau (the steady-state size
//     the cache settles to).
//   - Unregistered cache allocations are rejected with a typed error
//     (`MonaCacheRegistryError.unregisteredCache`).
//   - Signed-counter overflow is rejected with a typed error
//     (`MonaCacheRegistryError.counterOverflow`) — no silent wrap, trap, or UB.
//   - Entry-bound violations are rejected with a typed error
//     (`MonaCacheRegistryError.boundExceeded`).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - Errors

/// A typed error raised by the bounded cache registry.
///
/// All three failures are typed (no silent wrap, trap, or UB): an unregistered
/// cache, a counter overflow, and a bound violation each surface as a
/// machine-checkable error.
public enum MonaCacheRegistryError: Error, Equatable, Sendable {

    /// A subsystem tried to allocate a cache that is not in the closed
    /// registry. The rejected cache id is preserved verbatim.
    case unregisteredCache(String)

    /// A signed instrumentation counter overflowed its declared bit width.
    /// The cache id, counter name, and width are preserved.
    case counterOverflow(cache: String, counter: String, width: Int)

    /// A cache's entry count exceeded its frozen entry bound. The cache id,
    /// actual count, and max are preserved.
    case boundExceeded(cache: String, actual: Int, max: Int)
}

extension MonaCacheRegistryError: CustomStringConvertible {

    public var description: String {
        switch self {
        case .unregisteredCache(let id):
            return "UNREGISTERED_CACHE cache=\(id)"
        case .counterOverflow(let cache, let counter, let width):
            return "COUNTER_OVERFLOW cache=\(MonaCacheRegistry.label(for: cache)) counter=\(counter) width=\(width)"
        case .boundExceeded(let cache, let actual, let max):
            return "CACHE_BOUND_EXCEEDED cache=\(MonaCacheRegistry.label(for: cache)) actual=\(actual) max=\(max)"
        }
    }
}

// MARK: - Eviction policy

/// The eviction policy of a registered cache.
public enum MonaCacheEviction: String, Sendable, Equatable, CaseIterable {

    /// Insertion-order (first-in-first-out). A read hit does NOT update
    /// recency. Used by the D1-R diff cache.
    case fifo = "FIFO"

    /// Least-recently-used. A read hit promotes the entry to most-recently-used.
    /// Used by the S1-R suggestion caches and the E1-R normalization caches.
    case lru = "LRU"
}

// MARK: - Cache id

/// The stable id of a registered strong derived cache.
///
/// The cases form the closed set: every cache MonaCode uses is one of these,
/// and no other cache may be allocated. The raw values are the exact stable
/// ids the D1-R / S1-R / E1-R contracts pin and that `MonaCacheManifest.json`
/// must contain set-equal.
public enum MonaCacheId: String, Sendable, Equatable, CaseIterable {

    /// S1-R recentlyUsed suggestion-memory LRU (bound 300).
    case sessionSuggestionMemory = "session.suggestion-memory.recently-used"

    /// S1-R prefix-serialization suggestion memory (bound 200).
    case sessionSuggestionPrefix = "session.suggestion-prefix"

    /// S1-R command-MRU runtime cache (bound 50).
    case sessionCommandMRU = "session.command-mru"

    /// S1-R live CodeLens LRU (bound 20).
    case sessionCodeLensLRU = "session.codelens-lru"

    /// E1-R compose (NFC/NFKC) normalization LRU (bound 10000).
    case normalizerCompose = "normalizer.compose"

    /// E1-R decompose (NFD/NFKD) normalization LRU (bound 10000).
    case normalizerDecompose = "normalizer.decompose"

    /// D1-R document diff-result process-FIFO cache (maximum 11).
    case diffDocumentResult = "diff.document-result.process-fifo"
}

// MARK: - Registration

/// One strong derived cache registration: the immutable, frozen record of one
/// cache's bounds and lifetime contract.
///
/// Every field is fixed at registration time and never mutates. The
/// `quiescentPlateau` is the steady-state size the cache settles to under
/// normal operation (at or below `entryBound`).
public struct MonaCacheRegistration: Sendable, Equatable {

    /// The stable id (also a `MonaCacheId` raw value).
    public let id: String

    /// Which subsystem owns this cache (e.g. "D1-R/MonaDiffCoordinator").
    public let owner: String

    /// The cache key's structure (a human-readable shape description).
    public let keyShape: String

    /// The maximum number of entries the cache holds.
    public let entryBound: Int

    /// The maximum bytes the cache holds. `0` means the cache is entry-bound
    /// only (no separate byte bound); a non-zero value is the byte ceiling.
    public let byteBound: Int

    /// The instrumentation counter's signed bit width (e.g. 32 -> the signed
    /// range [-2^31, +2^31-1]).
    public let counterWidth: Int

    /// When/how the cache invalidates.
    public let invalidation: String

    /// The eviction policy (FIFO or LRU).
    public let eviction: MonaCacheEviction

    /// The steady-state size the cache settles to (at or below `entryBound`).
    public let quiescentPlateau: Int

    /// The memory-pressure action (H2-R: evict recomputable unpinned derived
    /// caches; never discard semantic state).
    public let memoryPressure: String

    public init(
        id: String,
        owner: String,
        keyShape: String,
        entryBound: Int,
        byteBound: Int,
        counterWidth: Int,
        invalidation: String,
        eviction: MonaCacheEviction,
        quiescentPlateau: Int,
        memoryPressure: String
    ) {
        self.id = id
        self.owner = owner
        self.keyShape = keyShape
        self.entryBound = entryBound
        self.byteBound = byteBound
        self.counterWidth = counterWidth
        self.invalidation = invalidation
        self.eviction = eviction
        self.quiescentPlateau = quiescentPlateau
        self.memoryPressure = memoryPressure
    }
}

// MARK: - Registry

/// The bounded cache registry — the closed set of every strong derived cache
/// MonaCode uses.
///
/// `MonaCacheRegistry` is a namespace (caseless enum) exposing:
///
///   - `registrations` — the frozen, closed set of registrations (exactly 7).
///   - `registration(for:)` — lookup by `MonaCacheId`.
///   - `contains(_:)` — membership test by id string.
///   - `allocate(_:)` — the closed-set gate: returns the registration for a
///     registered id, or throws `unregisteredCache` for an id outside the set.
///   - `checkEntryBound(cache:actual:max:)` — the bound gate: throws
///     `boundExceeded` when `actual > max`.
///   - `SignedCounter` — signed-counter arithmetic that rejects overflow past
///     the declared bit width (typed error, no silent wrap or UB).
///   - `label(for:)` — the short cache label (the first id segment) used in
///     diagnostic messages.
public enum MonaCacheRegistry {

    /// The frozen, closed set of strong derived cache registrations.
    ///
    /// Exactly 7: 4 S1-R suggestion caches (300/200/50/20, LRU), 2 E1-R
    /// normalization caches (10000 each, LRU), and 1 D1-R diff cache
    /// (maximum 11, FIFO).
    public static let registrations: [MonaCacheRegistration] = [
        // S1-R suggestion caches (300 / 200 / 50 / 20) — LRU.
        MonaCacheRegistration(
            id: MonaCacheId.sessionSuggestionMemory.rawValue,
            owner: "S1-R/MonaSessionStore",
            keyShape: "suggestion string (LRU de-dup: re-insert moves to back)",
            entryBound: 300,
            byteBound: 0,
            counterWidth: 32,
            invalidation: "process termination clears; editor disposal does not",
            eviction: .lru,
            quiescentPlateau: 300,
            memoryPressure: "evict recomputable unpinned entries; never discard semantic state"
        ),
        MonaCacheRegistration(
            id: MonaCacheId.sessionSuggestionPrefix.rawValue,
            owner: "S1-R/MonaSessionStore",
            keyShape: "prefix string (LRU de-dup)",
            entryBound: 200,
            byteBound: 0,
            counterWidth: 32,
            invalidation: "process termination clears; editor disposal does not",
            eviction: .lru,
            quiescentPlateau: 200,
            memoryPressure: "evict recomputable unpinned entries; never discard semantic state"
        ),
        MonaCacheRegistration(
            id: MonaCacheId.sessionCommandMRU.rawValue,
            owner: "S1-R/MonaSessionStore",
            keyShape: "command id (LRU de-dup)",
            entryBound: 50,
            byteBound: 0,
            counterWidth: 32,
            invalidation: "process termination clears; editor disposal does not",
            eviction: .lru,
            quiescentPlateau: 50,
            memoryPressure: "evict recomputable unpinned entries; never discard semantic state"
        ),
        MonaCacheRegistration(
            id: MonaCacheId.sessionCodeLensLRU.rawValue,
            owner: "S1-R/MonaSessionStore",
            keyShape: "CodeLens cache key (LRU)",
            entryBound: 20,
            byteBound: 0,
            counterWidth: 32,
            invalidation: "process termination clears; editor disposal does not",
            eviction: .lru,
            quiescentPlateau: 20,
            memoryPressure: "evict recomputable unpinned entries; never discard semantic state"
        ),
        // E1-R normalization caches (10000 each) — LRU.
        MonaCacheRegistration(
            id: MonaCacheId.normalizerCompose.rawValue,
            owner: "E1-R/MonaNormalizer",
            keyShape: "(normalizationForm, [UInt16] input) — NFC/NFKC share compose cache",
            entryBound: 10000,
            byteBound: 0,
            counterWidth: 32,
            invalidation: "recomputable; evict on memory pressure or editor/process disposal",
            eviction: .lru,
            quiescentPlateau: 10000,
            memoryPressure: "evict recomputable unpinned entries; never discard semantic state"
        ),
        MonaCacheRegistration(
            id: MonaCacheId.normalizerDecompose.rawValue,
            owner: "E1-R/MonaNormalizer",
            keyShape: "(normalizationForm, [UInt16] input) — NFD/NFKD share decompose cache",
            entryBound: 10000,
            byteBound: 0,
            counterWidth: 32,
            invalidation: "recomputable; evict on memory pressure or editor/process disposal",
            eviction: .lru,
            quiescentPlateau: 10000,
            memoryPressure: "evict recomputable unpinned entries; never discard semantic state"
        ),
        // D1-R diff cache (maximum 11) — FIFO.
        MonaCacheRegistration(
            id: MonaCacheId.diffDocumentResult.rawValue,
            owner: "D1-R/MonaDiffCoordinator",
            keyShape: "originalUri+modifiedUri+originalVersionId+modifiedVersionId+originalAlternativeVersionId+modifiedAlternativeVersionId+optionsHash",
            entryBound: 11,
            byteBound: 0,
            counterWidth: 32,
            invalidation: "version/context mismatch prevents stale reuse; FIFO and process termination remove entries",
            eviction: .fifo,
            quiescentPlateau: 11,
            memoryPressure: "H2 may evict this recomputable cache early without changing semantic state; ordinary execution must preserve the source FIFO rule and counters"
        ),
    ]

    /// Returns `true` if `id` is a registered cache id.
    public static func contains(_ id: String) -> Bool {
        registrations.contains { $0.id == id }
    }

    /// Returns the registration for `cacheId`. Falls back to a string lookup
    /// for ids that are not enumerated (returns nil if unregistered).
    public static func registration(for cacheId: MonaCacheId) -> MonaCacheRegistration {
        // The enum cases are the closed set; lookup is total over the enum.
        registrations.first { $0.id == cacheId.rawValue }
            ?? MonaCacheRegistration(
                id: cacheId.rawValue, owner: "", keyShape: "", entryBound: 0,
                byteBound: 0, counterWidth: 0, invalidation: "",
                eviction: .fifo, quiescentPlateau: 0, memoryPressure: ""
            )
    }

    /// Looks up a registration by id string. Returns nil if unregistered.
    public static func registration(forId id: String) -> MonaCacheRegistration? {
        registrations.first { $0.id == id }
    }

    /// The closed-set allocation gate.
    ///
    /// Returns the registration for `id` when it is in the closed registry.
    /// Throws `MonaCacheRegistryError.unregisteredCache` when `id` is not
    /// registered — an unregistered strong derived cache is a release failure.
    public static func allocate(_ id: String) throws -> MonaCacheRegistration {
        guard let r = registration(forId: id) else {
            throw MonaCacheRegistryError.unregisteredCache(id)
        }
        return r
    }

    /// The entry-bound gate.
    ///
    /// Throws `MonaCacheRegistryError.boundExceeded` when `actual > max`.
    /// The error message carries the short cache label (the first id segment)
    /// so the contract line reads, e.g.,
    /// `CACHE_BOUND_EXCEEDED cache=diff actual=12 max=11`.
    public static func checkEntryBound(cache id: String, actual: Int, max: Int) throws {
        guard actual <= max else {
            throw MonaCacheRegistryError.boundExceeded(cache: id, actual: actual, max: max)
        }
    }

    /// The short cache label used in diagnostic messages: the first segment
    /// of the id (before the first `.`). For example,
    /// `diff.document-result.process-fifo` -> `diff`.
    public static func label(for id: String) -> String {
        if let dot = id.firstIndex(of: ".") {
            return String(id[..<dot])
        }
        return id
    }

    // MARK: - SignedCounter

    /// Signed instrumentation-counter arithmetic.
    ///
    /// A namespace (caseless enum) over the cache instrumentation counters
    /// (hit / miss / eviction / retained-byte). A counter is a signed integer
    /// of a declared bit `width`; incrementing past the signed range for that
    /// width is rejected with `MonaCacheRegistryError.counterOverflow` — no
    /// silent wrap, trap, or UB.
    public enum SignedCounter {

        /// The maximum signed value for a counter of `width` bits
        /// (`2^(width-1) - 1`). `width` must be in 1...63.
        public static func maxValue(forWidth width: Int) -> Int64 {
            precondition(width > 0 && width <= 63, "counterWidth must be in 1...63")
            return Int64(1 &<< (width - 1)) - 1
        }

        /// The minimum signed value for a counter of `width` bits
        /// (`-2^(width-1)`). `width` must be in 1...63.
        public static func minValue(forWidth width: Int) -> Int64 {
            precondition(width > 0 && width <= 63, "counterWidth must be in 1...63")
            return -(Int64(1 &<< (width - 1)))
        }

        /// Increments `current` by `delta` for a counter of `width` bits.
        ///
        /// Returns the new value when it fits the signed `width`-bit range.
        /// Throws `MonaCacheRegistryError.counterOverflow` when the result
        /// would overflow the signed `width`-bit range (no silent wrap, trap,
        /// or UB). `cache` and `counter` are carried in the error for
        /// diagnostics.
        public static func increment(
            cache: String,
            counter: String,
            current: Int64,
            by delta: Int64,
            width: Int
        ) throws -> Int64 {
            precondition(width > 0 && width <= 63, "counterWidth must be in 1...63")
            let max = maxValue(forWidth: width)
            let min = minValue(forWidth: width)
            // Int64-level overflow is detected without trapping.
            let (result, overflow) = current.addingReportingOverflow(delta)
            if overflow || result > max || result < min {
                throw MonaCacheRegistryError.counterOverflow(
                    cache: cache, counter: counter, width: width
                )
            }
            return result
        }
    }
}
