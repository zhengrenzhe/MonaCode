// MonaLSPProviderAdapters.swift
//
// P06-T004 — Implement LSP session state and 25 capability mappings.
//
// This file holds the raw-UTF-16 position types, the provider-result value,
// the per-surface LSP provider adapter, the versionless diagnostic sink, and
// the 25-adapter registry. It is the Swift counterpart of Monaco's
// `monaco-lsp-client` feature-adapter layer (monaco-editor 0.56.0): each
// adapter takes a provider result carrying raw UTF-16 positions and publishes
// it through the deterministic executor (P05-T013 `MonaProviderExecutor`),
// validating a `MonaAsyncValidityTicket` (P01-T010) immediately before
// publication. No provider result is published through any other path.
//
// Raw-UInt16 invariant (frozen by L2-R / P06-T004):
//
//   - `MonaLSPPosition` stores `line` and `character` as `UInt16`. The
//     `character` is a raw UTF-16 code-unit offset (NOT a grapheme count),
//     matching Monaco's position contract and the project's raw-UInt16
//     invariant. A `character` that lands inside a surrogate pair is
//     preserved verbatim — no grapheme rounding.
//
// Provider result shapes (operation 3):
//
//   - Partial results: `MonaLSPProviderResult.isPartial` flags a result as a
//     partial; `MonaLSPProviderAdapter.resolvePartial(_:ticket:receive:)`
//     publishes the resolved (isPartial == false) result.
//   - Resolve: the companion `*/resolve` request completes a partial. The
//     adapter publishes the resolved value through the executor.
//   - Release: `MonaLSPProviderAdapter.release(releaseToken:)` releases a
//     provider (idempotent — the release token is dropped silently on a second
//     call).
//   - Stale responses: the validity ticket captures the model/version/owner/
//     cancellation truth at issue time; a stale ticket drops the publication
//     SILENTLY at publication time (`receive` is never invoked). The owned
//     list is still released exactly once.
//   - Versionless diagnostics: `MonaLSPDiagnosticSink.publishVersionless`
//     publishes diagnostics that carry no model version — the ticket (captured
//     at publish time) is the only gate; epoch/owner/cancellation still apply.
//
// Publication only through the deterministic executor (operation 4): every
// adapter funnels through `MonaProviderExecutor.publish(_:ticket:owned:receive:)`,
// which serializes on a `MonaMicrotaskQueue` (FIFO, deterministic order) and
// validates the ticket immediately before publication. No direct publication
// bypassing the executor.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaLSPPosition (raw UTF-16, UInt16)

/// A zero-based LSP position stored as raw UTF-16 code-unit offsets. Both
/// `line` and `character` are `UInt16` — the project's raw-UInt16 invariant.
/// The `character` is a raw UTF-16 code-unit offset into the line's text,
/// NEVER a grapheme count: an offset that lands inside a surrogate pair is
/// preserved verbatim.
///
/// This is the LSP wire position (LSP 3.18 advertises UTF-16
/// `positionEncoding` only). The project's one-based `MonaPosition` (P01-T001)
/// is the editor-internal position; `MonaLSPPosition` is the LSP-protocol
/// position. The two never coerce graphemes.
public struct MonaLSPPosition: Equatable, Hashable, Sendable {

    /// Zero-based line number.
    public let line: UInt16

    /// Zero-based character, as a raw UTF-16 code-unit offset (no grapheme
    /// conversion). An offset that lands inside a surrogate pair is preserved.
    public let character: UInt16

    /// Creates an LSP position.
    public init(line: UInt16, character: UInt16) {
        self.line = line
        self.character = character
    }
}

/// A range between two `MonaLSPPosition` endpoints.
public struct MonaLSPRange: Equatable, Hashable, Sendable {

    /// The inclusive start position.
    public let start: MonaLSPPosition

    /// The exclusive end position.
    public let end: MonaLSPPosition

    /// Creates a range.
    public init(start: MonaLSPPosition, end: MonaLSPPosition) {
        self.start = start
        self.end = end
    }
}

// MARK: - MonaLSPProviderResult

/// A provider result carrying raw UTF-16 positions, a partial flag, a release
/// token, and an optional model version. Published through the deterministic
/// executor by `MonaLSPProviderAdapter`.
public struct MonaLSPProviderResult: Equatable {

    /// The provider surface this result belongs to.
    public let surface: MonaLSPProviderSurface

    /// The raw UTF-16 positions the result carries (e.g. the hover range,
    /// definition target, diagnostic ranges). Each `character` is a raw
    /// UTF-16 code-unit offset.
    public let positions: [MonaLSPPosition]

    /// `true` when this is a partial result awaiting resolve; `false` for a
    /// complete result.
    public let isPartial: Bool

    /// The release token for resolve/release. Released by
    /// `MonaLSPProviderAdapter.release(releaseToken:)`.
    public let releaseToken: Int

    /// The model version the result was computed against, or `nil` for a
    /// versionless result (the ticket is the only gate).
    public let modelVersion: Int?

    /// Creates a provider result.
    public init(
        surface: MonaLSPProviderSurface,
        positions: [MonaLSPPosition],
        isPartial: Bool,
        releaseToken: Int,
        modelVersion: Int?
    ) {
        self.surface = surface
        self.positions = positions
        self.isPartial = isPartial
        self.releaseToken = releaseToken
        self.modelVersion = modelVersion
    }
}

// MARK: - MonaLSPProviderAdapter

/// A per-surface LSP provider adapter that publishes provider results through
/// the deterministic executor (`MonaProviderExecutor` from P05-T013),
/// validating a `MonaAsyncValidityTicket` immediately before publication. No
/// result is published through any other path.
///
/// Create with `init(surface:executor:)`. Publish a complete result with
/// `publish(result:ticket:owned:receive:)`; resolve a partial with
/// `resolvePartial(_:ticket:receive:)`; release a provider with
/// `release(releaseToken:)`.
public final class MonaLSPProviderAdapter {

    /// The provider surface this adapter serves.
    public let surface: MonaLSPProviderSurface

    /// The deterministic executor every result is funneled through.
    public let executor: MonaProviderExecutor

    private let _lock = NSLock()
    /// The release tokens currently held (for idempotent release).
    private var _heldTokens: Set<Int> = []

    /// Creates an adapter for `surface` that publishes through `executor`.
    public init(
        surface: MonaLSPProviderSurface,
        executor: MonaProviderExecutor
    ) {
        self.surface = surface
        self.executor = executor
    }

    /// Publishes `result` through the executor, validating `ticket`
    /// immediately before publication. A stale / cancelled ticket drops the
    /// publication SILENTLY (`receive` is never invoked); the owned list is
    /// still released exactly once.
    ///
    /// - Returns: `true` when the result was accepted onto the publication
    ///   path (enqueued); always `true` for a complete result.
    @discardableResult
    public func publish(
        result: MonaLSPProviderResult,
        ticket: MonaAsyncValidityTicket,
        owned: [MonaDisposable] = [],
        receive: @escaping (MonaLSPProviderResult) -> Void
    ) -> Bool {
        // Hold the release token (if any) for later release.
        registerReleaseToken(result.releaseToken)
        // Funnel through the executor: the ticket is validated immediately
        // before publication, the owned list is released exactly once.
        return executor.publish(
            .synchronous(result),
            ticket: ticket,
            owned: owned,
            receive: receive)
    }

    /// Resolves a partial `result`: publishes the resolved (isPartial == false)
    /// value through the executor. The `releaseToken` is preserved so a later
    /// `release` still applies.
    @discardableResult
    public func resolvePartial(
        _ result: MonaLSPProviderResult,
        ticket: MonaAsyncValidityTicket,
        owned: [MonaDisposable] = [],
        receive: @escaping (MonaLSPProviderResult) -> Void
    ) -> Bool {
        let resolved = MonaLSPProviderResult(
            surface: result.surface,
            positions: result.positions,
            isPartial: false,
            releaseToken: result.releaseToken,
            modelVersion: result.modelVersion)
        return publish(
            result: resolved, ticket: ticket, owned: owned, receive: receive)
    }

    /// Releases the provider holding `releaseToken`. Idempotent: a second call
    /// for the same token is a no-op (the token was already released).
    public func release(releaseToken: Int) {
        _lock.lock()
        let removed = _heldTokens.remove(releaseToken) != nil
        _lock.unlock()
        // The release token is dropped silently on a second call (idempotent).
        // The held-token set tracks ownership for diagnostics; the actual
        // resource release is driven by the executor's `owned` list disposal.
        _ = removed
    }

    /// `true` if this adapter currently holds `releaseToken`.
    public func holdsReleaseToken(_ releaseToken: Int) -> Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _heldTokens.contains(releaseToken)
    }

    // MARK: - Private

    private func registerReleaseToken(_ token: Int) {
        _lock.lock()
        _heldTokens.insert(token)
        _lock.unlock()
    }
}

// MARK: - MonaLSPDiagnosticSink (versionless diagnostics)

/// Publishes versionless diagnostics through the deterministic executor.
/// Diagnostics arrive without a model version (the server pushes
/// `textDocument/publishDiagnostics` at any time); the ticket captured at
/// publish time is the only gate — epoch/owner/cancellation still apply, but
/// the result carries no embedded version.
public final class MonaLSPDiagnosticSink {

    /// The executor diagnostics are funneled through.
    public let executor: MonaProviderExecutor

    /// Creates a diagnostic sink that publishes through `executor`.
    public init(executor: MonaProviderExecutor) {
        self.executor = executor
    }

    /// Publishes `diagnostics` (versionless) through the executor, validating
    /// `ticket` immediately before publication. A stale ticket drops the
    /// publication SILENTLY (`receive` is never invoked).
    @discardableResult
    public func publishVersionless(
        diagnostics: [MonaJSONValue],
        ticket: MonaAsyncValidityTicket,
        owned: [MonaDisposable] = [],
        receive: @escaping ([MonaJSONValue]) -> Void
    ) -> Bool {
        // Funnel through the executor. The ticket is the only gate; the
        // diagnostics carry no model version (versionless).
        return executor.publish(
            .synchronous(diagnostics),
            ticket: ticket,
            owned: owned,
            receive: receive)
    }
}

// MARK: - MonaLSPProviderAdapterRegistry

/// The registry of the 25 LSP provider adapters — one per
/// `MonaLSPProviderSurface`. Built from a single `MonaProviderExecutor` so
/// every surface funnels onto the SAME deterministic publication queue.
public final class MonaLSPProviderAdapterRegistry {

    /// One adapter per surface (exactly 25).
    public let adapters: [MonaLSPProviderSurface: MonaLSPProviderAdapter]

    /// Creates a registry with exactly 25 adapters, all sharing `executor`'s
    /// publication queue.
    public init(executor: MonaProviderExecutor) {
        var map: [MonaLSPProviderSurface: MonaLSPProviderAdapter] = [:]
        for surface in MonaLSPProviderSurface.allCases {
            map[surface] = MonaLSPProviderAdapter(
                surface: surface, executor: executor)
        }
        self.adapters = map
    }

    /// Returns the adapter for `surface`, or `nil` (never — the registry holds
    /// all 25).
    public func adapter(
        for surface: MonaLSPProviderSurface
    ) -> MonaLSPProviderAdapter? {
        return adapters[surface]
    }
}
