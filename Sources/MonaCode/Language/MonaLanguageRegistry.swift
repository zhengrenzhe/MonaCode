// MonaLanguageRegistry.swift
//
// P05-T008 — Retain only core language metadata and explicit plain-text fallback.
//
// `MonaLanguageRegistry` is the Core language registry. It retains ONLY the
// core fallback metadata identity (`"plaintext"`, `core-fallback-metadata`) as
// live; every other built-in language descriptor from monaco-editor 0.56.0 is
// recorded as an explicit CUT disposition (`cut-builtin-language-content`) with
// NO bundled grammar and NO provider — those arrive via providers in Phase 06.
//
// The frozen identities + their source order come from the F1-R3 scope manifest
// (`monaco-0.56.0-f1r3-scope-manifest.json`, `registries.languageDescriptors`),
// the same artifact family P05-T001..T005 used. They are emitted WITHOUT
// renaming or coalescing (one Swift entry per manifest row).
//
// The registry also exposes explicit host registration: a host may register its
// own language metadata. When no language/provider is registered for a model,
// the plain-text language (`MonaPlainTextLanguage`) provides the fallback
// behavior.
//
// Disposal is idempotent: after `dispose()`, the registry is marked disposed
// and further `dispose()` calls are no-ops. A disposed registry still reports
// its frozen identity inventory (the identities are immutable) but host
// registration and resolution fall back to plain text.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaLanguageDisposition

/// The disposition of a frozen language identity: whether it is the retained
/// Core fallback metadata, an explicitly CUT built-in language, or a
/// host-provided runtime registration.
///
/// The two frozen dispositions match the F1-R3 scope manifest's
/// `registries.languageDescriptors[*].disposition` strings verbatim (raw
/// values). `hostProvided` is a runtime-only disposition for metadata
/// registered by the host; it is not present in the manifest.
public enum MonaLanguageDisposition: String, Sendable, Equatable, CaseIterable {

    /// The single retained Core fallback metadata identity (`"plaintext"`).
    /// Live in production: it is the plain-text fallback.
    case coreFallbackMetadata = "core-fallback-metadata"

    /// A built-in language descriptor CUT from production. Recorded as an
    /// explicit UNAVAILABLE disposition: no live registration, no bundled
    /// grammar, no provider. Grammar/provider content arrives via providers
    /// in Phase 06.
    case cutBuiltinLanguageContent = "cut-builtin-language-content"

    /// A host-provided language metadata registration. Live at runtime: the
    /// host registered its own metadata via `MonaLanguageRegistry.register`.
    case hostProvided = "host-provided"

    /// `true` when this disposition is live (the Core fallback or a
    /// host-provided registration). `cutBuiltinLanguageContent` is NOT live.
    public var isLive: Bool {
        switch self {
        case .coreFallbackMetadata, .hostProvided: return true
        case .cutBuiltinLanguageContent: return false
        }
    }
}

// MARK: - MonaLanguageDescriptor

/// The metadata descriptor of a language: aliases, file extensions, and MIME
/// types. Recorded verbatim from the F1-R3 scope manifest. Carries NO grammar
/// and NO provider — only identity metadata.
public struct MonaLanguageDescriptor: Hashable, Sendable {

    /// The language id (e.g. `"plaintext"`, `"python"`).
    public let id: String

    /// The aliases (alternative names for fuzzy matching), in manifest order.
    public let aliases: [String]

    /// The file extensions (e.g. `[".txt"]`, `[".py", ".pyw"]`).
    public let extensions: [String]

    /// The MIME types (e.g. `["text/plain"]`).
    public let mimetypes: [String]

    public init(id: String, aliases: [String], extensions: [String], mimetypes: [String]) {
        self.id = id
        self.aliases = aliases
        self.extensions = extensions
        self.mimetypes = mimetypes
    }
}

// MARK: - MonaLanguageIdentity

/// A frozen language identity, recorded in source order.
///
/// The identity carries ONLY metadata (`id`, `disposition`, `hasLoader`, and
/// the descriptor). It bundles NO grammar, NO `TokenizerConfig`, and NO
/// language provider. `hasLoader` records whether the original monaco-editor
/// built-in language had a loader — it is a recorded metadata fact, NOT a
/// bundled loader instance.
public struct MonaLanguageIdentity: Hashable, Sendable {

    /// The language id (e.g. `"plaintext"`, `"python"`).
    public let id: String

    /// The disposition (core-fallback-metadata vs cut-built-in-language-content
    /// vs host-provided).
    public let disposition: MonaLanguageDisposition

    /// `true` when the original monaco-editor built-in language had a loader.
    /// MonaCode bundles NO loader — this is a recorded metadata fact only.
    public let hasLoader: Bool

    /// The metadata descriptor (aliases, extensions, MIME types).
    public let descriptor: MonaLanguageDescriptor

    /// `true` when this identity is a live production identity.
    public var isLive: Bool { disposition.isLive }

    public init(
        id: String,
        disposition: MonaLanguageDisposition,
        hasLoader: Bool,
        aliases: [String],
        extensions: [String],
        mimetypes: [String]
    ) {
        self.id = id
        self.disposition = disposition
        self.hasLoader = hasLoader
        self.descriptor = MonaLanguageDescriptor(
            id: id,
            aliases: aliases,
            extensions: extensions,
            mimetypes: mimetypes
        )
    }
}

// MARK: - MonaLanguageRegistry

/// The Core language registry.
///
/// Retains exactly ONE language metadata identity as live — the core fallback
/// (`"plaintext"`, `core-fallback-metadata`). All 90 other built-in language
/// descriptors from monaco-editor 0.56.0 are recorded as
/// `cut-builtin-language-content` with NO bundled grammar and NO provider.
///
/// Hosts may register their own language metadata via `register(_:)`. When no
/// language/provider is registered for a model, `resolveLanguage(for:)` returns
/// the plain-text fallback, and `plainTextFallback()` returns the
/// `MonaPlainTextLanguage` behavior.
///
/// Disposal is idempotent: after `dispose()`, the registry is marked disposed
/// and further `dispose()` calls are no-ops. The frozen identity inventory
/// remains queryable (identities are immutable); host registration is refused
/// and resolution falls back to plain text.
public final class MonaLanguageRegistry {

    /// Every frozen language identity in source order (live + cut).
    ///
    /// 91 identities: 1 `core-fallback-metadata` (`"plaintext"`) + 90
    /// `cut-builtin-language-content`.
    public static let frozenIdentities: [MonaLanguageIdentity] = [
        MonaLanguageIdentity(id: "abap", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["abap", "ABAP"], extensions: [".abap"], mimetypes: []),
        MonaLanguageIdentity(id: "aes", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["aes", "sophia", "Sophia"], extensions: [".aes"], mimetypes: []),
        MonaLanguageIdentity(id: "apex", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Apex", "apex"], extensions: [".cls"], mimetypes: ["text/x-apex-source", "text/x-apex"]),
        MonaLanguageIdentity(id: "azcli", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Azure CLI", "azcli"], extensions: [".azcli"], mimetypes: []),
        MonaLanguageIdentity(id: "bat", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Batch", "bat"], extensions: [".bat", ".cmd"], mimetypes: []),
        MonaLanguageIdentity(id: "bicep", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Bicep"], extensions: [".bicep"], mimetypes: []),
        MonaLanguageIdentity(id: "c", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["C", "c"], extensions: [".c", ".h"], mimetypes: []),
        MonaLanguageIdentity(id: "cameligo", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Cameligo"], extensions: [".mligo"], mimetypes: []),
        MonaLanguageIdentity(id: "clojure", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["clojure", "Clojure"], extensions: [".clj", ".cljs", ".cljc", ".edn"], mimetypes: []),
        MonaLanguageIdentity(id: "coffeescript", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["CoffeeScript", "coffeescript", "coffee"], extensions: [".coffee"], mimetypes: ["text/x-coffeescript", "text/coffeescript"]),
        MonaLanguageIdentity(id: "cpp", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["C++", "Cpp", "cpp"], extensions: [".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx"], mimetypes: []),
        MonaLanguageIdentity(id: "csharp", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["C#", "csharp"], extensions: [".cs", ".csx", ".cake"], mimetypes: []),
        MonaLanguageIdentity(id: "csp", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["CSP", "csp"], extensions: [".csp"], mimetypes: []),
        MonaLanguageIdentity(id: "css", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["CSS", "css"], extensions: [".css"], mimetypes: ["text/css"]),
        MonaLanguageIdentity(id: "cypher", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Cypher", "OpenCypher"], extensions: [".cypher", ".cyp"], mimetypes: []),
        MonaLanguageIdentity(id: "dart", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Dart", "dart"], extensions: [".dart"], mimetypes: ["text/x-dart-source", "text/x-dart"]),
        MonaLanguageIdentity(id: "dockerfile", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Dockerfile"], extensions: [".dockerfile"], mimetypes: []),
        MonaLanguageIdentity(id: "ecl", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["ECL", "Ecl", "ecl"], extensions: [".ecl"], mimetypes: []),
        MonaLanguageIdentity(id: "elixir", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Elixir", "elixir", "ex"], extensions: [".ex", ".exs"], mimetypes: []),
        MonaLanguageIdentity(id: "flow9", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Flow9", "Flow", "flow9", "flow"], extensions: [".flow"], mimetypes: []),
        MonaLanguageIdentity(id: "freemarker2", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["FreeMarker2", "Apache FreeMarker2"], extensions: [".ftl", ".ftlh", ".ftlx"], mimetypes: []),
        MonaLanguageIdentity(id: "freemarker2.tag-angle.interpolation-bracket", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["FreeMarker2 (Angle/Bracket)", "Apache FreeMarker2 (Angle/Bracket)"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "freemarker2.tag-angle.interpolation-dollar", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["FreeMarker2 (Angle/Dollar)", "Apache FreeMarker2 (Angle/Dollar)"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "freemarker2.tag-auto.interpolation-bracket", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["FreeMarker2 (Auto/Bracket)", "Apache FreeMarker2 (Auto/Bracket)"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "freemarker2.tag-auto.interpolation-dollar", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["FreeMarker2 (Auto/Dollar)", "Apache FreeMarker2 (Auto/Dollar)"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "freemarker2.tag-bracket.interpolation-bracket", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["FreeMarker2 (Bracket/Bracket)", "Apache FreeMarker2 (Bracket/Bracket)"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "freemarker2.tag-bracket.interpolation-dollar", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["FreeMarker2 (Bracket/Dollar)", "Apache FreeMarker2 (Bracket/Dollar)"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "fsharp", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["F#", "FSharp", "fsharp"], extensions: [".fs", ".fsi", ".ml", ".mli", ".fsx", ".fsscript"], mimetypes: []),
        MonaLanguageIdentity(id: "go", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Go"], extensions: [".go"], mimetypes: []),
        MonaLanguageIdentity(id: "graphql", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["GraphQL", "graphql", "gql"], extensions: [".graphql", ".gql"], mimetypes: ["application/graphql"]),
        MonaLanguageIdentity(id: "handlebars", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Handlebars", "handlebars", "hbs"], extensions: [".handlebars", ".hbs"], mimetypes: ["text/x-handlebars-template"]),
        MonaLanguageIdentity(id: "hcl", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Terraform", "tf", "HCL", "hcl"], extensions: [".tf", ".tfvars", ".hcl"], mimetypes: []),
        MonaLanguageIdentity(id: "html", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["HTML", "htm", "html", "xhtml"], extensions: [".html", ".htm", ".shtml", ".xhtml", ".mdoc", ".jsp", ".asp", ".aspx", ".jshtm"], mimetypes: ["text/html", "text/x-jshtm", "text/template", "text/ng-template"]),
        MonaLanguageIdentity(id: "ini", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Ini", "ini"], extensions: [".ini", ".properties", ".gitconfig"], mimetypes: []),
        MonaLanguageIdentity(id: "java", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Java", "java"], extensions: [".java", ".jav"], mimetypes: ["text/x-java-source", "text/x-java"]),
        MonaLanguageIdentity(id: "javascript", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["JavaScript", "javascript", "js"], extensions: [".js", ".es6", ".jsx", ".mjs", ".cjs"], mimetypes: ["text/javascript"]),
        MonaLanguageIdentity(id: "json", disposition: .cutBuiltinLanguageContent, hasLoader: false, aliases: ["JSON", "json"], extensions: [".json", ".bowerrc", ".jshintrc", ".jscsrc", ".eslintrc", ".babelrc", ".har"], mimetypes: ["application/json"]),
        MonaLanguageIdentity(id: "julia", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["julia", "Julia"], extensions: [".jl"], mimetypes: []),
        MonaLanguageIdentity(id: "kotlin", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Kotlin", "kotlin"], extensions: [".kt", ".kts"], mimetypes: ["text/x-kotlin-source", "text/x-kotlin"]),
        MonaLanguageIdentity(id: "less", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Less", "less"], extensions: [".less"], mimetypes: ["text/x-less", "text/less"]),
        MonaLanguageIdentity(id: "lexon", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Lexon"], extensions: [".lex"], mimetypes: []),
        MonaLanguageIdentity(id: "liquid", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Liquid", "liquid"], extensions: [".liquid", ".html.liquid"], mimetypes: ["application/liquid"]),
        MonaLanguageIdentity(id: "lua", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Lua", "lua"], extensions: [".lua"], mimetypes: []),
        MonaLanguageIdentity(id: "m3", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Modula-3", "Modula3", "modula3", "m3"], extensions: [".m3", ".i3", ".mg", ".ig"], mimetypes: []),
        MonaLanguageIdentity(id: "markdown", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Markdown", "markdown"], extensions: [".md", ".markdown", ".mdown", ".mkdn", ".mkd", ".mdwn", ".mdtxt", ".mdtext"], mimetypes: []),
        MonaLanguageIdentity(id: "mdx", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["MDX", "mdx"], extensions: [".mdx"], mimetypes: []),
        MonaLanguageIdentity(id: "mips", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["MIPS", "MIPS-V"], extensions: [".s"], mimetypes: ["text/x-mips", "text/mips", "text/plaintext"]),
        MonaLanguageIdentity(id: "msdax", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["DAX", "MSDAX"], extensions: [".dax", ".msdax"], mimetypes: []),
        MonaLanguageIdentity(id: "mysql", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["MySQL", "mysql"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "objective-c", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Objective-C"], extensions: [".m"], mimetypes: []),
        MonaLanguageIdentity(id: "pascal", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Pascal", "pas"], extensions: [".pas", ".p", ".pp"], mimetypes: ["text/x-pascal-source", "text/x-pascal"]),
        MonaLanguageIdentity(id: "pascaligo", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Pascaligo", "ligo"], extensions: [".ligo"], mimetypes: []),
        MonaLanguageIdentity(id: "perl", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Perl", "pl"], extensions: [".pl", ".pm"], mimetypes: []),
        MonaLanguageIdentity(id: "pgsql", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["PostgreSQL", "postgres", "pg", "postgre"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "php", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["PHP", "php"], extensions: [".php", ".php4", ".php5", ".phtml", ".ctp"], mimetypes: ["application/x-php"]),
        MonaLanguageIdentity(id: "pla", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: [], extensions: [".pla"], mimetypes: []),
        MonaLanguageIdentity(id: "plaintext", disposition: .coreFallbackMetadata, hasLoader: false, aliases: ["Plain Text", "text"], extensions: [".txt"], mimetypes: ["text/plain"]),
        MonaLanguageIdentity(id: "postiats", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["ATS", "ATS/Postiats"], extensions: [".dats", ".sats", ".hats"], mimetypes: []),
        MonaLanguageIdentity(id: "powerquery", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["PQ", "M", "Power Query", "Power Query M"], extensions: [".pq", ".pqm"], mimetypes: []),
        MonaLanguageIdentity(id: "powershell", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["PowerShell", "powershell", "ps", "ps1"], extensions: [".ps1", ".psm1", ".psd1"], mimetypes: []),
        MonaLanguageIdentity(id: "proto", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["protobuf", "Protocol Buffers"], extensions: [".proto"], mimetypes: []),
        MonaLanguageIdentity(id: "pug", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Pug", "Jade", "jade"], extensions: [".jade", ".pug"], mimetypes: []),
        MonaLanguageIdentity(id: "python", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Python", "py"], extensions: [".py", ".rpy", ".pyw", ".cpy", ".gyp", ".gypi"], mimetypes: []),
        MonaLanguageIdentity(id: "qsharp", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Q#", "qsharp"], extensions: [".qs"], mimetypes: []),
        MonaLanguageIdentity(id: "r", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["R", "r"], extensions: [".r", ".rhistory", ".rmd", ".rprofile", ".rt"], mimetypes: []),
        MonaLanguageIdentity(id: "razor", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Razor", "razor"], extensions: [".cshtml"], mimetypes: ["text/x-cshtml"]),
        MonaLanguageIdentity(id: "redis", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["redis"], extensions: [".redis"], mimetypes: []),
        MonaLanguageIdentity(id: "redshift", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Redshift", "redshift"], extensions: [], mimetypes: []),
        MonaLanguageIdentity(id: "restructuredtext", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["reStructuredText", "restructuredtext"], extensions: [".rst"], mimetypes: []),
        MonaLanguageIdentity(id: "ruby", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Ruby", "rb"], extensions: [".rb", ".rbx", ".rjs", ".gemspec", ".pp"], mimetypes: []),
        MonaLanguageIdentity(id: "rust", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Rust", "rust"], extensions: [".rs", ".rlib"], mimetypes: []),
        MonaLanguageIdentity(id: "sb", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Small Basic", "sb"], extensions: [".sb"], mimetypes: []),
        MonaLanguageIdentity(id: "scala", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Scala", "scala", "SBT", "Sbt", "sbt", "Dotty", "dotty"], extensions: [".scala", ".sc", ".sbt"], mimetypes: ["text/x-scala-source", "text/x-scala", "text/x-sbt", "text/x-dotty"]),
        MonaLanguageIdentity(id: "scheme", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["scheme", "Scheme"], extensions: [".scm", ".ss", ".sch", ".rkt"], mimetypes: []),
        MonaLanguageIdentity(id: "scss", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Sass", "sass", "scss"], extensions: [".scss"], mimetypes: ["text/x-scss", "text/scss"]),
        MonaLanguageIdentity(id: "shell", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Shell", "sh"], extensions: [".sh", ".bash"], mimetypes: []),
        MonaLanguageIdentity(id: "sol", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["sol", "solidity", "Solidity"], extensions: [".sol"], mimetypes: []),
        MonaLanguageIdentity(id: "sparql", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["sparql", "SPARQL"], extensions: [".rq"], mimetypes: []),
        MonaLanguageIdentity(id: "sql", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["SQL"], extensions: [".sql"], mimetypes: []),
        MonaLanguageIdentity(id: "st", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["StructuredText", "scl", "stl"], extensions: [".st", ".iecst", ".iecplc", ".lc3lib", ".TcPOU", ".TcDUT", ".TcGVL", ".TcIO"], mimetypes: []),
        MonaLanguageIdentity(id: "swift", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Swift", "swift"], extensions: [".swift"], mimetypes: ["text/swift"]),
        MonaLanguageIdentity(id: "systemverilog", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["SV", "sv", "SystemVerilog", "systemverilog"], extensions: [".sv", ".svh"], mimetypes: []),
        MonaLanguageIdentity(id: "tcl", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["tcl", "Tcl", "tcltk", "TclTk", "tcl/tk", "Tcl/Tk"], extensions: [".tcl"], mimetypes: []),
        MonaLanguageIdentity(id: "twig", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Twig", "twig"], extensions: [".twig"], mimetypes: ["text/x-twig"]),
        MonaLanguageIdentity(id: "typescript", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["TypeScript", "ts", "typescript"], extensions: [".ts", ".tsx", ".cts", ".mts"], mimetypes: ["text/typescript"]),
        MonaLanguageIdentity(id: "typespec", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["TypeSpec"], extensions: [".tsp"], mimetypes: []),
        MonaLanguageIdentity(id: "vb", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["Visual Basic", "vb"], extensions: [".vb"], mimetypes: []),
        MonaLanguageIdentity(id: "verilog", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["V", "v", "Verilog", "verilog"], extensions: [".v", ".vh"], mimetypes: []),
        MonaLanguageIdentity(id: "wgsl", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["WebGPU Shading Language", "WGSL", "wgsl"], extensions: [".wgsl"], mimetypes: []),
        MonaLanguageIdentity(id: "xml", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["XML", "xml"], extensions: [".xml", ".xsd", ".dtd", ".ascx", ".csproj", ".config", ".props", ".targets", ".wxi", ".wxl", ".wxs", ".xaml", ".svg", ".svgz", ".opf", ".xslt", ".xsl"], mimetypes: ["text/xml", "application/xml", "application/xaml+xml", "application/xml-dtd"]),
        MonaLanguageIdentity(id: "yaml", disposition: .cutBuiltinLanguageContent, hasLoader: true, aliases: ["YAML", "yaml", "YML", "yml"], extensions: [".yaml", ".yml"], mimetypes: ["application/x-yaml", "text/x-yaml"]),
    ]

    /// The live (retained) language identities, in source order (the plain-text
    /// fallback only).
    public let liveIdentities: [MonaLanguageIdentity]

    /// The cut (UNAVAILABLE) language identities, in source order (the 90
    /// built-in language descriptors).
    public let cutIdentities: [MonaLanguageIdentity]

    /// The single retained live fallback identity (`"plaintext"`).
    public let fallbackIdentity: MonaLanguageIdentity

    /// A map from language id to its frozen LIVE identity, for O(1) lookup
    /// (the plain-text fallback).
    private let frozenLiveById: [String: MonaLanguageIdentity]

    /// A map from language id to its frozen CUT identity, for O(1) lookup of
    /// built-in cut descriptors (metadata only — not live).
    private let frozenCutById: [String: MonaLanguageIdentity]

    /// Host-provided language metadata registrations, by language id.
    private var _hostRegistrations: [String: MonaLanguageIdentity] = [:]

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates a registry populated with all frozen language identities.
    public init() {
        let frozen = Self.frozenIdentities
        self.liveIdentities = frozen.filter { $0.isLive }
        self.cutIdentities = frozen.filter { !$0.isLive }
        self.fallbackIdentity = self.liveIdentities[0]
        self.frozenLiveById = Dictionary(
            uniqueKeysWithValues: self.liveIdentities.map { ($0.id, $0) }
        )
        self.frozenCutById = Dictionary(
            uniqueKeysWithValues: self.cutIdentities.map { ($0.id, $0) }
        )
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _isDisposed
    }

    /// The total number of frozen identities (live + cut).
    public var totalCount: Int { Self.frozenIdentities.count }

    /// The number of live (retained) identities — always 1 (the plain-text
    /// fallback).
    public var liveCount: Int { liveIdentities.count }

    /// The number of cut (UNAVAILABLE) identities — always 90.
    public var cutCount: Int { cutIdentities.count }

    /// The number of host-provided language metadata registrations.
    public var hostRegisteredCount: Int {
        _lock.lock()
        defer { _lock.unlock() }
        return _hostRegistrations.count
    }

    // MARK: - Lookup

    /// Returns the host-provided language metadata registered for `id`, or
    /// `nil` if no host registration exists for `id`.
    public func hostRegisteredIdentity(for id: String) -> MonaLanguageIdentity? {
        _lock.lock()
        defer { _lock.unlock() }
        return _hostRegistrations[id]
    }

    /// Returns the frozen LIVE language identity for `id` (the plain-text
    /// fallback), or `nil` if `id` is not a frozen live identity.
    public func frozenLiveIdentity(for id: String) -> MonaLanguageIdentity? {
        frozenLiveById[id]
    }

    /// Returns the frozen CUT built-in language descriptor for `id`, or `nil`
    /// if `id` is not a recorded cut built-in language.
    ///
    /// The returned identity carries metadata only — NO bundled grammar and
    /// NO provider.
    public func cutBuiltInIdentity(for id: String) -> MonaLanguageIdentity? {
        frozenCutById[id]
    }

    /// Returns `true` when a live language (host-registered or the frozen
    /// plain-text fallback) is registered for `id`.
    public func contains(_ id: String) -> Bool {
        if frozenLiveById[id] != nil { return true }
        _lock.lock()
        defer { _lock.unlock() }
        return _hostRegistrations[id] != nil
    }

    /// Resolves the language identity for `id`.
    ///
    /// Resolution order:
    ///   1. a host-provided registration for `id` (live host metadata), else
    ///   2. the frozen LIVE identity for `id` (the plain-text fallback), else
    ///   3. the plain-text fallback identity (no language/provider registered).
    ///
    /// Cut built-in language descriptors (e.g. `"python"`) are NOT live and
    /// resolve to the plain-text fallback until a host registers metadata for
    /// them.
    public func resolveLanguage(for id: String) -> MonaLanguageIdentity {
        if let host = hostRegisteredIdentity(for: id) { return host }
        if let frozen = frozenLiveById[id] { return frozen }
        return fallbackIdentity
    }

    /// Returns the plain-text fallback language behavior. Used when no
    /// language/provider is registered for a model.
    public func plainTextFallback() -> MonaPlainTextLanguage {
        MonaPlainTextLanguage()
    }

    // MARK: - Host registration

    /// Registers a host-provided language metadata identity.
    ///
    /// Idempotent: re-registering the same id replaces the prior registration.
    /// Registration is refused (no-op) after the registry is disposed.
    public func register(_ identity: MonaLanguageIdentity) {
        _lock.lock()
        if !_isDisposed {
            _hostRegistrations[identity.id] = identity
        }
        _lock.unlock()
    }

    /// Unregisters a host-provided language metadata identity. No-op if `id`
    /// is not host-registered (frozen identities are immutable and cannot be
    /// unregistered).
    public func unregister(_ id: String) {
        _lock.lock()
        _hostRegistrations.removeValue(forKey: id)
        _lock.unlock()
    }

    // MARK: - Disposal

    /// Disposes the registry. Idempotent: calling it again is a no-op.
    ///
    /// After disposal, host registration is refused (no-op) and
    /// `resolveLanguage(for:)` still returns the plain-text fallback (the
    /// frozen fallback identity remains queryable).
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        _ = already
    }
}

