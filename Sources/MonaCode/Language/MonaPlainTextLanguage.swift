// MonaPlainTextLanguage.swift
//
// P05-T008 — Retain only core language metadata and explicit plain-text fallback.
//
// `MonaPlainTextLanguage` is the plain-text language: the single Core fallback
// language used when no language (and no language provider) is registered for a
// model. It owns the one retained `core-fallback-metadata` identity
// (`"plaintext"`) and exposes the plain-text fallback behavior.
//
// MonaCode is a Foundation-only target. Plain text carries NO bundled grammar
// and NO tokenization provider — those arrive via providers in Phase 06. The
// plain-text language therefore performs no tokenization: it is the
// no-grammar fallback.
//
// `import Foundation` is the sole import.

import Foundation

// MARK: - MonaPlainTextLanguage

/// The plain-text language — the Core fallback used when no language/provider
/// is registered for a model.
///
/// Plain text is the single retained `core-fallback-metadata` identity
/// (`"plaintext"`). It provides the fallback behavior: no tokenization, no
/// grammar, no provider. When a host has not registered metadata (or a
/// provider) for a model's language, the model resolves to this plain-text
/// fallback.
public struct MonaPlainTextLanguage: Hashable, Sendable {

    /// The language id of the plain-text fallback (`"plaintext"`).
    public static let languageId: String = "plaintext"

    /// The frozen plain-text identity — the single `core-fallback-metadata`
    /// entry retained as live by the Core language registry.
    public static let identity: MonaLanguageIdentity = MonaLanguageIdentity(
        id: "plaintext",
        disposition: .coreFallbackMetadata,
        hasLoader: false,
        aliases: ["Plain Text", "text"],
        extensions: [".txt"],
        mimetypes: ["text/plain"]
    )

    /// Creates the plain-text fallback language.
    public init() {}

    /// The language id (`"plaintext"`).
    public var id: String { Self.languageId }

    /// The aliases of the plain-text language.
    public var aliases: [String] { Self.identity.descriptor.aliases }

    /// The file extensions of the plain-text language.
    public var extensions: [String] { Self.identity.descriptor.extensions }

    /// The MIME types of the plain-text language.
    public var mimetypes: [String] { Self.identity.descriptor.mimetypes }

    /// `false` — plain text performs no tokenization. It is the no-grammar,
    /// no-provider fallback; tokenization arrives via providers in Phase 06.
    public var hasTokenization: Bool { false }

    /// `false` — plain text bundles no grammar (no `TokenizerConfig`,
    /// no `MonacoTokensProvider`). The Core retains only metadata identity.
    public var hasGrammar: Bool { false }

    /// `false` — plain text bundles no language provider.
    public var hasProvider: Bool { false }
}
