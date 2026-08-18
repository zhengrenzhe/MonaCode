// MonaProviderRegistry.swift
//
// P06-T005 — Close all 30 provider registries and five direct-only surfaces.
//
// `MonaProviderRegistry` is the unified registry of all 30 provider
// attachment points: 25 LSP-backed (delegating to MonaLSPCapabilityRegistry
// + MonaLSPProviderAdapterRegistry from T004) + 5 direct-only
// (MonaDirectProviderAdapter). Hosts/LSP supply providers; the Core provides
// the registry + plain-text fallback. The registry bundles NO built-in
// language implementation and NO language server.
//
// The 30 identities (frozen by P06-T005):
//
//   - 25 LSP-backed — the capabilities from T004 (textDocument/completion,
//     /hover, /definition, etc.), enumerated by MonaLSPProviderSurface.
//     Availability tracked by MonaLSPCapabilityRegistry (all 25 start
//     `.unavailable`). Publication through MonaLSPProviderAdapterRegistry.
//   - 5 direct-only — direct token factory, new-symbol-name,
//     multi-document-highlight, paste-edit, drop-edit (host-provided
//     providers that are NOT LSP capabilities), enumerated by
//     MonaDirectProviderSurface. All 5 start unattached. Publication through
//     MonaDirectProviderAdapter.
//
// Fallback when no provider is attached (operation 3):
//
//   - LSP-backed surfaces: `.unavailable` (the server did not advertise the
//     capability).
//   - Direct token factory: plain-text behavior (reuses MonaPlainTextLanguage
//     from P05-T008) — the no-grammar fallback.
//   - The other four direct-only surfaces: `.unavailable`.
//   Never crash.
//
// No bundled language/server (operation 4): the registry holds attachment
// points only — it does NOT ship a built-in language server or a built-in
// language implementation. `bundledLanguageServer` and
// `bundledLanguageImplementation` are both `nil`. Hosts/LSP supply providers;
// the Core provides the registry + plain-text fallback.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaProviderIdentity

/// A unified provider identity — one of 30 (25 LSP-backed + 5 direct-only).
/// The LSP-backed identities wrap a `MonaLSPProviderSurface` (whose raw value
/// IS the LSP method name); the direct-only identities wrap a
/// `MonaDirectProviderSurface` (whose raw value is a stable surface id that
/// is NOT an LSP method name).
public enum MonaProviderIdentity: Equatable, Hashable, Sendable {

    /// An LSP-backed capability (one of 25).
    case lsp(MonaLSPProviderSurface)

    /// A direct-only host provider (one of 5).
    case direct(MonaDirectProviderSurface)

    /// `true` when this identity is an LSP-backed capability.
    public var isLSPBacked: Bool {
        if case .lsp = self { return true }
        return false
    }

    /// `true` when this identity is a direct-only host provider.
    public var isDirectOnly: Bool {
        if case .direct = self { return true }
        return false
    }

    /// `true` when this identity is an LSP capability; `false` for direct-only.
    /// (Direct-only surfaces are NOT LSP capabilities — they have no LSP
    /// method name and are never dispatched through the LSP session.)
    public var isLSPCapability: Bool {
        switch self {
        case .lsp: return true
        case .direct: return false
        }
    }
}

// MARK: - MonaProviderFallback

/// The fallback behavior when no provider is attached for a surface.
public enum MonaProviderFallback: Equatable, Sendable {

    /// No provider attached; the capability is unavailable.
    case unavailable

    /// No provider attached; plain-text behavior (direct token factory only,
    /// reuses MonaPlainTextLanguage P05-T008 — the no-grammar fallback).
    case plainText
}

// MARK: - MonaProviderRegistry

/// The registry of all 30 provider attachment points: 25 LSP-backed +
/// 5 direct-only. Hosts/LSP supply providers; the Core provides the registry
/// + plain-text fallback. The registry bundles NO built-in language
/// implementation and NO language server.
///
/// Create with `init(executor:)`, passing the single `MonaProviderExecutor`
/// (P05-T013) every surface funnels through — the 25 LSP-backed adapters and
/// the 5 direct-only adapters share the SAME deterministic publication queue
/// (no parallel mechanism). Register / look up providers via `allIdentities`,
/// `isAttached(_:)`, `fallback(for:)`, `attachDirect(_:)`, `releaseDirect(_:)`.
public final class MonaProviderRegistry {

    /// The fixed total identity count: exactly 30 (25 LSP-backed + 5
    /// direct-only).
    public static let identityCount: Int = 30

    /// The LSP-backed identity count: exactly 25 (verified by T004).
    public static let lspBackedCount: Int = 25

    /// The direct-only identity count: exactly 5.
    public static let directOnlyCount: Int = 5

    /// The 25 LSP-backed capability mappings (from T004). All 25 start
    /// `.unavailable`; the LSP client fills them from the server's
    /// `initialize` response (static) and `client/registerCapability`
    /// (dynamic).
    public let lspCapabilities: MonaLSPCapabilityRegistry

    /// The 25 LSP-backed provider adapters (from T004). Built from a single
    /// `MonaProviderExecutor` so every LSP surface funnels onto the SAME
    /// deterministic publication queue as the 5 direct-only adapters.
    public let lspAdapters: MonaLSPProviderAdapterRegistry

    /// The 5 direct-only provider adapters. Each publishes through the same
    /// `MonaProviderExecutor` as the 25 LSP-backed adapters — no parallel
    /// publication mechanism. All 5 start unattached.
    public let directAdapters: [MonaDirectProviderSurface: MonaDirectProviderAdapter]

    /// Creates a registry with all 30 attachment points (25 LSP-backed
    /// `.unavailable` + 5 direct-only unattached), all sharing `executor`'s
    /// publication queue.
    public init(executor: MonaProviderExecutor) {
        self.lspCapabilities = MonaLSPCapabilityRegistry()
        self.lspAdapters = MonaLSPProviderAdapterRegistry(executor: executor)
        var directMap: [MonaDirectProviderSurface: MonaDirectProviderAdapter] = [:]
        for surface in MonaDirectProviderSurface.allCases {
            directMap[surface] = MonaDirectProviderAdapter(
                surface: surface, executor: executor)
        }
        self.directAdapters = directMap
    }

    /// All 30 provider identities (25 LSP-backed in `MonaLSPProviderSurface`
    /// order, then 5 direct-only in `MonaDirectProviderSurface` order).
    public var allIdentities: [MonaProviderIdentity] {
        var ids: [MonaProviderIdentity] = []
        for s in MonaLSPProviderSurface.allCases { ids.append(.lsp(s)) }
        for s in MonaDirectProviderSurface.allCases { ids.append(.direct(s)) }
        return ids
    }

    /// Returns the direct adapter for `surface`, or `nil` (never — the
    /// registry holds all 5).
    public func directAdapter(
        for surface: MonaDirectProviderSurface
    ) -> MonaDirectProviderAdapter? {
        return directAdapters[surface]
    }

    /// The fallback behavior when no provider is attached for `identity`:
    /// `.unavailable` for the 25 LSP-backed and the 4 non-tokenization
    /// direct-only surfaces; `.plainText` for the direct token factory
    /// (reuses MonaPlainTextLanguage P05-T008).
    public func fallback(
        for identity: MonaProviderIdentity
    ) -> MonaProviderFallback {
        switch identity {
        case .lsp:
            return .unavailable
        case .direct(let surface):
            return surface.fallback
        }
    }

    /// `true` when a provider is attached for `identity` — the LSP capability
    /// is available (static or dynamic) for an LSP-backed surface, or a host
    /// direct provider is attached for a direct-only surface.
    public func isAttached(_ identity: MonaProviderIdentity) -> Bool {
        switch identity {
        case .lsp(let surface):
            return lspCapabilities.isAvailable(surface)
        case .direct(let surface):
            return directAdapters[surface]?.isAttached ?? false
        }
    }

    /// Attaches a host direct provider for `surface` (direct-only only —
    /// never an LSP capability). The host supplies the provider; the Core
    /// provides the attachment point.
    public func attachDirect(_ surface: MonaDirectProviderSurface) {
        directAdapters[surface]?.attach()
    }

    /// Releases the host direct provider for `surface` (idempotent — a second
    /// call is a no-op). Direct-only only — never an LSP capability.
    public func releaseDirect(_ surface: MonaDirectProviderSurface) {
        directAdapters[surface]?.release()
    }

    /// The plain-text language used as the direct token factory fallback when
    /// no tokenization provider is attached (reuses MonaPlainTextLanguage
    /// P05-T008). The single Core-provided fallback behavior. Plain text
    /// performs no tokenization, bundles no grammar, and bundles no provider.
    public var plainTextFallback: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `nil` — the registry bundles NO built-in language server. Hosts/LSP
    /// supply the server; the Core provides the registry + plain-text fallback.
    public var bundledLanguageServer: Any? { nil }

    /// `nil` — the registry bundles NO built-in language implementation.
    /// Hosts/LSP supply providers; the Core provides the registry +
    /// plain-text fallback.
    public var bundledLanguageImplementation: Any? { nil }
}
