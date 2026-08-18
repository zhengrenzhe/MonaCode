// MonaDirectProviderAdapters.swift
//
// P06-T005 — Close all 30 provider registries and five direct-only surfaces.
//
// The five direct-only provider surfaces — direct token factory,
// new-symbol-name, multi-document-highlight, paste-edit, and drop-edit —
// are host-provided providers that are NOT LSP capabilities. They are
// registered as direct-only, distinct from the 25 LSP-backed surfaces
// (MonaLSPProviderSurface from T004).
//
// Direct-only invariant (frozen by P06-T005):
//
//   - NOT LSP capabilities: each direct-only surface has no LSP method name
//     (`lspMethod == nil`) and `isLSPCapability == false`. They are never
//     dispatched through the LSP session and never appear in the LSP
//     capability registry (MonaLSPCapabilityRegistry).
//   - Published through the deterministic executor: every direct adapter
//     funnels through `MonaProviderExecutor` (P05-T013), the SAME path the
//     25 LSP-backed adapters use. No parallel publication mechanism.
//   - Explicit fallback when no provider is attached: the direct token
//     factory falls back to plain-text behavior (reuses MonaPlainTextLanguage
//     from P05-T008); the other four direct-only surfaces return
//     `.unavailable`. Never crash.
//   - No bundled language/server: the adapters are attachment points; they
//     bundle NO built-in language implementation and NO language server.
//     Hosts supply the direct providers; the Core provides the adapter +
//     plain-text fallback (direct token factory only).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaDirectProviderSurface

/// The five direct-only provider surfaces. These are host-provided providers
/// that are NOT LSP capabilities — distinct from the 25 LSP-backed surfaces.
/// The raw value is a stable surface id (never an LSP method name).
public enum MonaDirectProviderSurface: String, CaseIterable, Sendable, Equatable {

    /// The tokenization provider (T009/T156). Host-provided; falls back to
    /// plain-text behavior (MonaPlainTextLanguage) when no provider attached.
    case directTokenFactory = "direct-token-factory"

    /// Rename's new-name provider. Host-provided; returns unavailable when no
    /// provider attached.
    case newSymbolName = "new-symbol-name"

    /// Multi-document highlight (multiple highlight sources). Host-provided;
    /// returns unavailable when no provider attached.
    case multiDocumentHighlight = "multi-document-highlight"

    /// Paste-edit pipeline providers (P04-T008). Host-provided; returns
    /// unavailable when no provider attached.
    case pasteEdit = "paste-edit"

    /// Drop-edit providers (P04-T009). Host-provided; returns unavailable
    /// when no provider attached.
    case dropEdit = "drop-edit"

    /// `false` — these are direct host providers, NOT LSP capabilities.
    /// They do NOT map to any LSP method name and are never dispatched
    /// through the LSP session. (Contrast the 25 LSP-backed surfaces, whose
    /// raw value IS the LSP method name and `isLSPCapability == true`.)
    public var isLSPCapability: Bool { false }

    /// `nil` — direct-only surfaces have no LSP method name. (The 25
    /// LSP-backed surfaces' raw value IS the LSP method name.)
    public var lspMethod: String? { nil }

    /// The fallback behavior when no direct provider is attached for this
    /// surface. The direct token factory falls back to plain-text (reuses
    /// MonaPlainTextLanguage P05-T008); the other four return `.unavailable`.
    public var fallback: MonaProviderFallback {
        switch self {
        case .directTokenFactory: return .plainText
        case .newSymbolName, .multiDocumentHighlight,
             .pasteEdit, .dropEdit: return .unavailable
        }
    }
}

// MARK: - MonaDirectProviderAdapter

/// A direct-only provider adapter that publishes provider results through the
/// deterministic executor (`MonaProviderExecutor` from P05-T013), validating a
/// `MonaAsyncValidityTicket` immediately before publication. Does NOT pretend
/// to be an LSP capability — no LSP method name, no LSP surface, no dispatch
/// through the LSP session.
///
/// Create with `init(surface:executor:)`. Attach a host provider with
/// `attach()`; release it with `release()` (idempotent). Publish a result
/// with `publish(value:ticket:owned:receive:)`. The adapter reuses the SAME
/// publication path as the 25 LSP-backed adapters (no parallel mechanism).
public final class MonaDirectProviderAdapter {

    /// The direct-only surface this adapter serves.
    public let surface: MonaDirectProviderSurface

    /// The deterministic executor every result is funneled through (the SAME
    /// path the 25 LSP-backed adapters use — no parallel publication
    /// mechanism).
    public let executor: MonaProviderExecutor

    private let _lock = NSLock()
    private var _attached = false

    /// Creates an adapter for `surface` that publishes through `executor`.
    public init(
        surface: MonaDirectProviderSurface,
        executor: MonaProviderExecutor
    ) {
        self.surface = surface
        self.executor = executor
    }

    /// The fallback behavior when no provider is attached for this surface
    /// (delegates to `surface.fallback`).
    public var fallback: MonaProviderFallback { surface.fallback }

    /// `true` when a host direct provider is attached for this surface.
    /// `false` by default (the Core provides the attachment point, not the
    /// provider).
    public var isAttached: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _attached
    }

    /// Attaches a host direct provider for this surface. The host supplies
    /// the provider; the Core provides the attachment point.
    public func attach() {
        _lock.lock()
        _attached = true
        _lock.unlock()
    }

    /// Releases the attached host direct provider (idempotent — a second call
    /// is a no-op). The adapter returns to the unattached state, and the
    /// surface's `fallback` applies again.
    public func release() {
        _lock.lock()
        _attached = false
        _lock.unlock()
    }

    /// Publishes `value` through the deterministic executor, validating
    /// `ticket` immediately before publication. A stale / cancelled ticket
    /// drops the publication SILENTLY (`receive` is never invoked); the owned
    /// list is still released exactly once. Reuses the SAME publication path
    /// as the 25 LSP-backed adapters (no parallel mechanism).
    ///
    /// - Returns: `true` when the result was accepted onto the publication
    ///   path (enqueued); always `true` for a synchronous value.
    @discardableResult
    public func publish<Value>(
        value: Value,
        ticket: MonaAsyncValidityTicket,
        owned: [MonaDisposable] = [],
        receive: @escaping (Value) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(value),
            ticket: ticket,
            owned: owned,
            receive: receive)
    }
}
