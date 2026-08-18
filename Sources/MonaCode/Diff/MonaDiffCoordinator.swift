// MonaDiffCoordinator.swift
//
// P07-T002 — Close diff timeouts, caches, maximum size, and unavailable external paths.
//
// `MonaDiffCoordinator` sits above the diff engines (P07-T001) and coordinates
// diff execution: the T-1/T/T+1 timeout truth under an injected wall clock, the
// bounded maximum-11 cache, the explicit no-op for max-file-size and
// external/WASM-unavailable algorithm paths, and the version-gated publication
// that drops stale or non-complete results.
//
// It is the Swift counterpart of Monaco's `DiffEditorWidget` diff-coordination
// surface (monaco-editor 0.56.0): the widget owns the injected clock budget
// (`maxComputationTime`), the per-editor compute lane, and the validity
// re-check before a computed diff may be published.
//
// Frozen truths (D1-R.timeout / D1-R.cache / D1-R.externalUnavailable):
//
//   - Timeout truth: strict `elapsed < limit` (the engines' frozen checkpoint
//     semantics, reused from T001 via the injected `any MonaWallClocking`).
//     At T-1 (elapsed < limit) the diff completes; at T (elapsed == limit) and
//     T+1 (elapsed > limit) it times out. The coordinator maps the engine's
//     `hitTimeout`/`quitEarly` to a typed `.timedOut` result.
//   - Cache: the bounded maximum-11 cache (`MonaDiffCache`) keyed by the URI
//     pair + version ids + alternative versions + options. A hit returns the
//     cached result; a miss computes, stores (complete results only), and
//     returns. Insertion-order eviction at the 11-bound.
//   - No-op: the coordinator returns an explicit `.unavailable` result for
//     max-file-size inputs (the option observation — the engine `compute`
//     path never reads `maxFileSize`) and for the retained-but-cut
//     `advancedExternal`/`advancedWasm` algorithm values, which never load
//     external code in the fixed baseline.
//   - Version-gated publication: a result is published ONLY when it is
//     `.complete` AND the captured `MonaAsyncValidityTicket` pair still
//     validates against the live publication gates. A stale version (or a
//     non-complete result) is dropped silently.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The reason a coordinated diff returned an explicit no-op (unavailable)
/// result.
public enum MonaDiffUnavailableReason: Equatable, Sendable {

    /// The input exceeded the max-file-size gate (the option observation; the
    /// engine `compute` path does not read `maxFileSize`).
    case maxFileSize

    /// The `advancedExternal` algorithm value — retained, always unavailable
    /// in the fixed baseline (no `@vscode/diff` dependency, no external code).
    case externalAlgorithm

    /// The `advancedWasm` algorithm value — retained, always unavailable in
    /// the fixed baseline (no JS+WASM bundle, no dynamic loader).
    case wasmAlgorithm
}

/// A coordinated diff result: the diff either ran to completion, timed out,
/// was aborted by cancellation, or was unavailable (no-op).
public enum MonaDiffCoordinatorResult: Equatable, @unchecked Sendable {

    /// The diff ran to completion (`quitEarly == false`).
    case complete(MonaDiffResult)

    /// The diff hit the timeout budget (`quitEarly && hitTimeout`).
    case timedOut(MonaDiffResult)

    /// The diff was aborted by cancellation (`quitEarly && !hitTimeout`).
    case aborted(MonaDiffResult)

    /// The diff was not run — an explicit no-op for a max-file-size input or
    /// an external/WASM-unavailable algorithm path.
    case unavailable(MonaDiffUnavailableReason)

    /// `true` only when the diff ran to completion (publishable). Timed-out,
    /// aborted, and unavailable results are NOT publishable.
    public var isComplete: Bool {
        if case .complete = self { return true }
        return false
    }
}

/// The validity snapshot captured at compute time: one `MonaAsyncValidityTicket`
/// per side (original + modified). The coordinator validates both against the
/// live publication gates before publishing a complete result.
public struct MonaDiffValiditySnapshot: Equatable, @unchecked Sendable {

    /// The original (left) model's validity ticket at compute time.
    public let originalTicket: MonaAsyncValidityTicket

    /// The modified (right) model's validity ticket at compute time.
    public let modifiedTicket: MonaAsyncValidityTicket

    /// Creates a validity snapshot from the two per-side tickets.
    public init(originalTicket: MonaAsyncValidityTicket, modifiedTicket: MonaAsyncValidityTicket) {
        self.originalTicket = originalTicket
        self.modifiedTicket = modifiedTicket
    }
}

/// Coordinates diff execution over the legacy and advanced engines (P07-T001):
/// applies the T-1/T/T+1 timeout truth via the injected wall clock, consults
/// the bounded maximum-11 cache, returns explicit no-op results for
/// max-file-size and external/WASM-unavailable paths, and gates publication on
/// model-version validity.
///
/// The coordinator is `@unchecked Sendable`: the injected clock and engines
/// are immutable after construction, and the cache is internally synchronized.
public final class MonaDiffCoordinator: @unchecked Sendable {

    /// The frozen default max-file-size gate, in mebi-`UInt16` code units
    /// (50 * 1024 * 1024 = 52,428,800). The engine `compute` path never reads
    /// this value; it is the coordinator's option observation only.
    public static let defaultMaxFileSizeMiU16: Int = 50 * 1024 * 1024

    /// The injected wall-clock domain for timeout checks. Reused by the
    /// engines (T001) so the T-1/T/T+1 truth is unified across the coordinator
    /// and the engine checkpoints.
    private let clock: any MonaWallClocking

    /// The legacy diff engine.
    private let legacyEngine: MonaLegacyDiffEngine

    /// The advanced diff engine.
    private let advancedEngine: MonaAdvancedDiffEngine

    /// The max-file-size gate, in mebi-`UInt16` code units.
    private let maxFileSizeMiU16: Int

    /// The bounded maximum-11 diff cache.
    public let cache: MonaDiffCache

    /// Creates a coordinator with an injected wall clock, the two diff engines,
    /// and a max-file-size gate (defaulting to the frozen 50 MiU16).
    public init(
        clock: any MonaWallClocking,
        legacyEngine: MonaLegacyDiffEngine = MonaLegacyDiffEngine(),
        advancedEngine: MonaAdvancedDiffEngine = MonaAdvancedDiffEngine(),
        maxFileSizeMiU16: Int = MonaDiffCoordinator.defaultMaxFileSizeMiU16
    ) {
        self.clock = clock
        self.legacyEngine = legacyEngine
        self.advancedEngine = advancedEngine
        self.maxFileSizeMiU16 = maxFileSizeMiU16
        self.cache = MonaDiffCache()
    }

    /// Computes (or returns the cached) diff for `input` under `options` with
    /// the `algorithm`, the cache `context`, and the `cancellationToken`.
    ///
    /// The coordinator:
    ///   1. Returns `.unavailable(.externalAlgorithm)`/`.wasmAlgorithm` for the
    ///      retained-but-cut `advancedExternal`/`advancedWasm` values — no
    ///      external code is loaded.
    ///   2. Returns `.unavailable(.maxFileSize)` when either side's total raw
    ///      UTF-16 code-unit count exceeds the max-file-size gate (the option
    ///      observation; the engine `compute` path never reads it).
    ///   3. Returns the cached result on a cache hit.
    ///   4. On a miss, runs the engine with the injected clock + options +
    ///      cancellation token, mapping the engine's `quitEarly`/`hitTimeout`
    ///      to `.complete`/`.timedOut`/`.aborted`. Only `.complete` results are
    ///      cached.
    public func computeDiff(
        input: MonaDiffInput,
        options: MonaDiffOptions,
        algorithm: MonaDiffAlgorithm,
        context: MonaDiffCacheContext,
        cancellationToken: MonaCancellationToken
    ) -> MonaDiffCoordinatorResult {
        // 1. External / WASM algorithm paths are always unavailable.
        switch algorithm {
        case .legacy, .advanced:
            break
        case .advancedExternal:
            return .unavailable(.externalAlgorithm)
        case .advancedWasm:
            return .unavailable(.wasmAlgorithm)
        }

        // 2. Max-file-size option observation (the compute path never reads it).
        if totalUnits(input.originalLines) > maxFileSizeMiU16
            || totalUnits(input.modifiedLines) > maxFileSizeMiU16 {
            return .unavailable(.maxFileSize)
        }

        // 3. Cache lookup (hit → return the cached complete result).
        let key = MonaDiffCacheKey(context: context, options: options)
        if let cached = cache.get(key) {
            return .complete(cached)
        }

        // 4. Miss: run the engine with the injected clock (T-1/T/T+1 truth).
        let engine: MonaDiffEngine = (algorithm == .advanced) ? advancedEngine : legacyEngine
        let result = engine.compute(
            input: input, options: options, clock: clock, cancellationToken: cancellationToken
        )

        // Map the engine result to the coordinator result type.
        let coordinated: MonaDiffCoordinatorResult
        if result.quitEarly && result.hitTimeout {
            coordinated = .timedOut(result)
        } else if result.quitEarly {
            coordinated = .aborted(result)
        } else {
            coordinated = .complete(result)
        }

        // Cache only complete results (timed-out / aborted / unavailable are
        // never cached — they are recomputed on the next request).
        if case .complete = coordinated {
            cache.put(key, result: result)
        }

        return coordinated
    }

    /// Publishes `result` only when it is `.complete` AND both tickets in
    /// `snapshot` still validate against the live publication gates. A stale
    /// version (either side) or a non-complete result is dropped SILENTLY:
    /// `receive` is never invoked and `false` is returned.
    @discardableResult
    public func publishDiff(
        _ result: MonaDiffCoordinatorResult,
        snapshot: MonaDiffValiditySnapshot,
        originalGate: MonaPublicationGate,
        modifiedGate: MonaPublicationGate,
        receive: (MonaDiffResult) -> Void
    ) -> Bool {
        // Publish only complete results.
        guard case .complete(let diff) = result else {
            return false
        }
        // Version-gated publication: both per-side tickets must still be fresh.
        guard originalGate.validate(snapshot.originalTicket) else {
            return false
        }
        guard modifiedGate.validate(snapshot.modifiedTicket) else {
            return false
        }
        receive(diff)
        return true
    }

    // MARK: - Private

    /// The total raw UTF-16 code-unit count across all `lines`.
    private func totalUnits(_ lines: [[UInt16]]) -> Int {
        var count = 0
        for line in lines {
            count += line.count
        }
        return count
    }
}
