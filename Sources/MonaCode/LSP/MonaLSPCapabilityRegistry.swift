// MonaLSPCapabilityRegistry.swift
//
// P06-T004 — Implement LSP session state and 25 capability mappings.
//
// `MonaLSPCapabilityRegistry` maps the 25 LSP-backed provider surfaces to
// their LSP method names and tracks each surface's capability availability
// (available / unavailable / dynamically-registered). It is the Swift
// counterpart of Monaco's `monaco-lsp-client` feature-adapter table
// (monaco-editor 0.56.0), fixed by the L2-R closure artifact to exactly 25
// surfaces (Navigation 9 + Editing 8 + Presentation 8).
//
// The 25 surfaces are enumerated by `MonaLSPProviderSurface` (the raw LSP
// method name is the case raw value). Each surface belongs to one of three
// groups — `.navigation`, `.editing`, `.presentation` — mirroring the L2-R
// closure matrix. Resolvable surfaces (completion, codeAction, codeLens,
// inlayHint, documentLink) expose a `resolveMethod` — the companion
// `*/resolve` request the server sends to complete a partial result.
//
// Capability availability (frozen by L2-R / P06-T004):
//
//   - `.unavailable`         — the server did not advertise the capability.
//   - `.available`           — the server advertised the capability at
//                               `initialize` (static registration).
//   - `.dynamicallyRegistered` — the server registered the capability at
//                               runtime via `client/registerCapability`
//                               (dynamic registration).
//
// Static registration: `setStaticAvailability(_:_,:)` sets a capability as
// available (or unavailable) — called from the `initialize` response handler
// as it reads the server's `ServerCapabilities` object. Dynamic registration:
// `registerDynamically(_:)` marks a capability as dynamically-registered,
// called from the `client/registerCapability` handler; `unregister(_:)` is
// the release path (called from `client/unregisterCapability`).
//
// All 25 surfaces start `.unavailable`; the registry is the authority the
// LSP client consults before dispatching a provider request to the server.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The three L2-R closure groups the 25 surfaces belong to.
public enum MonaLSPSurfaceGroup: String, Sendable {

    /// Reference, Definition, Declaration, TypeDefinition, Implementation,
    /// DocumentSymbol, DocumentHighlight, SelectionRange, Link (9 surfaces).
    case navigation

    /// Rename, Completion, SignatureHelp, CodeAction, CodeLens, Formatting,
    /// RangeFormatting, OnTypeFormatting (8 surfaces).
    case editing

    /// Hover, Color, FoldingRange, InlayHints, InlineCompletion,
    /// LinkedEditing, full/range SemanticTokens (8 surfaces).
    case presentation
}

/// The 25 LSP-backed provider surfaces. The raw value is the LSP method name.
/// `allCases` is exactly 25 (verified by the test suite).
public enum MonaLSPProviderSurface: String, CaseIterable, Sendable, Equatable {

    // MARK: - Navigation (9)

    case reference = "textDocument/references"
    case definition = "textDocument/definition"
    case declaration = "textDocument/declaration"
    case typeDefinition = "textDocument/typeDefinition"
    case implementation = "textDocument/implementation"
    case documentSymbol = "textDocument/documentSymbol"
    case documentHighlight = "textDocument/documentHighlight"
    case selectionRange = "textDocument/selectionRange"
    case documentLink = "textDocument/documentLink"

    // MARK: - Editing (8)

    case rename = "textDocument/rename"
    case completion = "textDocument/completion"
    case signatureHelp = "textDocument/signatureHelp"
    case codeAction = "textDocument/codeAction"
    case codeLens = "textDocument/codeLens"
    case formatting = "textDocument/formatting"
    case rangeFormatting = "textDocument/rangeFormatting"
    case onTypeFormatting = "textDocument/onTypeFormatting"

    // MARK: - Presentation (8)

    case hover = "textDocument/hover"
    case documentColor = "textDocument/documentColor"
    case foldingRange = "textDocument/foldingRange"
    case inlayHint = "textDocument/inlayHint"
    case inlineCompletion = "textDocument/inlineCompletion"
    case linkedEditingRange = "textDocument/linkedEditingRange"
    case semanticTokensFull = "textDocument/semanticTokens/full"
    case semanticTokensRange = "textDocument/semanticTokens/range"

    /// The LSP method name (the raw value).
    public var method: String { return rawValue }

    /// The L2-R closure group this surface belongs to.
    public var group: MonaLSPSurfaceGroup {
        switch self {
        case .reference, .definition, .declaration, .typeDefinition,
             .implementation, .documentSymbol, .documentHighlight,
             .selectionRange, .documentLink:
            return .navigation
        case .rename, .completion, .signatureHelp, .codeAction, .codeLens,
             .formatting, .rangeFormatting, .onTypeFormatting:
            return .editing
        case .hover, .documentColor, .foldingRange, .inlayHint,
             .inlineCompletion, .linkedEditingRange,
             .semanticTokensFull, .semanticTokensRange:
            return .presentation
        }
    }

    /// The companion `*/resolve` request for a resolvable surface, or `nil`
    /// if the surface does not support resolve. Resolvable surfaces: completion
    /// (completionItem/resolve), codeAction (codeAction/resolve), codeLens
    /// (codeLens/resolve), inlayHint (inlayHint/resolve), documentLink
    /// (documentLink/resolve).
    public var resolveMethod: String? {
        switch self {
        case .completion: return "completionItem/resolve"
        case .codeAction: return "codeAction/resolve"
        case .codeLens: return "codeLens/resolve"
        case .inlayHint: return "inlayHint/resolve"
        case .documentLink: return "documentLink/resolve"
        default: return nil
        }
    }
}

/// The capability availability for an LSP provider surface.
public enum MonaLSPCapabilityAvailability: Equatable, Sendable {

    /// The server did not advertise the capability (default).
    case unavailable

    /// The server advertised the capability at `initialize` (static
    /// registration).
    case available

    /// The server registered the capability at runtime via
    /// `client/registerCapability` (dynamic registration).
    case dynamicallyRegistered
}

/// A capability mapping: a surface, its LSP method name, and its current
/// availability. Constructed by `MonaLSPCapabilityRegistry.allMappings()`.
public struct MonaLSPCapabilityMapping: Equatable {

    /// The provider surface.
    public let surface: MonaLSPProviderSurface

    /// The LSP method name (equals `surface.method`).
    public let method: String

    /// The current capability availability.
    public let availability: MonaLSPCapabilityAvailability

    /// Creates a capability mapping.
    public init(
        surface: MonaLSPProviderSurface,
        method: String,
        availability: MonaLSPCapabilityAvailability
    ) {
        self.surface = surface
        self.method = method
        self.availability = availability
    }
}

/// The registry of the 25 LSP-backed capability mappings. The authority the
/// LSP client consults before dispatching a provider request: a request is
/// sent only when the surface's availability is `.available` or
/// `.dynamicallyRegistered`.
///
/// All 25 surfaces start `.unavailable`. Static registration
/// (`setStaticAvailability`) is called from the `initialize` response handler;
/// dynamic registration (`registerDynamically` / `unregister`) is called from
/// the `client/registerCapability` / `client/unregisterCapability` handlers.
public final class MonaLSPCapabilityRegistry {

    /// The fixed surface count: exactly 25 (verified by the test suite).
    public static let surfaceCount: Int = 25

    private let _lock = NSLock()

    /// The per-surface availability map. One entry per surface (all 25).
    private var _availability: [MonaLSPProviderSurface: MonaLSPCapabilityAvailability]

    /// Creates a registry with all 25 surfaces `.unavailable`.
    public init() {
        _availability = [:]
        for surface in MonaLSPProviderSurface.allCases {
            _availability[surface] = .unavailable
        }
    }

    /// The current availability for `surface`.
    public func availability(
        for surface: MonaLSPProviderSurface
    ) -> MonaLSPCapabilityAvailability {
        _lock.lock()
        defer { _lock.unlock() }
        return _availability[surface] ?? .unavailable
    }

    /// `true` when the capability for `surface` is available (statically or
    /// dynamically).
    public func isAvailable(_ surface: MonaLSPProviderSurface) -> Bool {
        let a = availability(for: surface)
        return a == .available || a == .dynamicallyRegistered
    }

    /// Static registration: sets the availability for `surface`. Called from
    /// the `initialize` response handler as it reads the server's
    /// `ServerCapabilities` object.
    public func setStaticAvailability(
        _ surface: MonaLSPProviderSurface,
        _ availability: MonaLSPCapabilityAvailability
    ) {
        _lock.lock()
        _availability[surface] = availability
        _lock.unlock()
    }

    /// Dynamic registration: marks `surface` as `.dynamicallyRegistered`.
    /// Returns `true` if the surface was not already
    /// `.dynamicallyRegistered`; `false` if it already was. A surface that is
    /// statically `.available` is upgraded to `.dynamicallyRegistered`.
    @discardableResult
    public func registerDynamically(
        _ surface: MonaLSPProviderSurface
    ) -> Bool {
        _lock.lock()
        defer { _lock.unlock() }
        let prev = _availability[surface] ?? .unavailable
        guard prev != .dynamicallyRegistered else { return false }
        _availability[surface] = .dynamicallyRegistered
        return true
    }

    /// Dynamic unregistration (release): returns `surface` to
    /// `.unavailable`. Returns `true` if the surface was available (static or
    /// dynamic); `false` if it was already `.unavailable`.
    @discardableResult
    public func unregister(
        _ surface: MonaLSPProviderSurface
    ) -> Bool {
        _lock.lock()
        defer { _lock.unlock() }
        let prev = _availability[surface] ?? .unavailable
        guard prev != .unavailable else { return false }
        _availability[surface] = .unavailable
        return true
    }

    /// Returns the 25 capability mappings, one per surface, in `allCases`
    /// order (Navigation, Editing, Presentation).
    public func allMappings() -> [MonaLSPCapabilityMapping] {
        _lock.lock()
        let snapshot = _availability
        _lock.unlock()
        return MonaLSPProviderSurface.allCases.map { surface in
            MonaLSPCapabilityMapping(
                surface: surface,
                method: surface.method,
                availability: snapshot[surface] ?? .unavailable)
        }
    }

    /// The current availability map snapshot (one entry per surface).
    public var mappings: [MonaLSPProviderSurface: MonaLSPCapabilityMapping] {
        _lock.lock()
        let snapshot = _availability
        _lock.unlock()
        var result: [MonaLSPProviderSurface: MonaLSPCapabilityMapping] = [:]
        for surface in MonaLSPProviderSurface.allCases {
            result[surface] = MonaLSPCapabilityMapping(
                surface: surface,
                method: surface.method,
                availability: snapshot[surface] ?? .unavailable)
        }
        return result
    }
}
