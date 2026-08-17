// MonaTokenTheme.swift
//
// P05-T006 — Implement theme, token, color, icon, and Codicon registries.
//
// GENERATED FILE — do not edit by hand. Transcribed verbatim from the F1-R3
// scope manifest (monaco-editor@0.56.0 builtin colors/icons/themes/Codicon
// glyphs). Regenerate by re-running the P05-T006 transcription against the
// manifest at:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monaco-0.56.0-f1r3-scope-manifest.json
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.
import Foundation

// MARK: - Token theme model

/// One tokenization color rule transcribed verbatim from a builtin theme's
/// `rules` array. `foreground`/`background` are hex strings without the
/// leading `#` (matching Monaco's `TokenTheme` rule format); `fontStyle` is the
/// upstream style token (e.g. "italic", "bold", "underline").
public struct MonaTokenColorRule: Sendable, Equatable {
    public let token: String
    public let foreground: String?
    public let background: String?
    public let fontStyle: String?
    public init(token: String, foreground: String?, background: String?, fontStyle: String?) {
        self.token = token; self.foreground = foreground
        self.background = background; self.fontStyle = fontStyle
    }
}

/// A builtin theme transcribed verbatim from the F1-R3 manifest
/// (`registries.builtinThemes`). `colors` is the theme's editor color map;
/// `rules` are the tokenization rules; `inherit` controls whether a custom
/// theme falls back to its `base` (all four builtins carry `inherit: false`).
public struct MonaTokenTheme: Sendable, Equatable {
    public let id: String
    public let base: String
    public let inherit: Bool
    public let colors: [String: String]
    public let rules: [MonaTokenColorRule]
    public init(id: String, base: String, inherit: Bool,
                colors: [String: String], rules: [MonaTokenColorRule]) {
        self.id = id; self.base = base; self.inherit = inherit
        self.colors = colors; self.rules = rules
    }

    /// `true` for the high-contrast bases (`hc-black`, `hc-light`).
    public var isHighContrast: Bool { base.hasPrefix("hc-") }

    /// Looks up the token rule whose `token` scope matches `scope` exactly.
    public func rule(for scope: String) -> MonaTokenColorRule? {
        rules.first { $0.token == scope }
    }
}

// MARK: - Builtin token themes

/// The four builtin token themes ported verbatim from monaco-editor@0.56.0
/// (F1-R3 manifest `registries.builtinThemes`): `vs`, `vs-dark`, `hc-black`,
/// `hc-light`.
public enum MonaBuiltinThemes {

    /// The four builtin themes in source-ordinal order (vs, vs-dark, hc-black, hc-light).
    public static let builtinThemes: [MonaTokenTheme] = [
        MonaTokenTheme(
            id: "vs",
            base: "vs",
            inherit: false,
            colors: ["editor.background": "#FFFFFE", "editor.foreground": "#000000", "editor.inactiveSelectionBackground": "#E5EBF1", "editor.selectionHighlightBackground": "#ADD6FF4D", "editorIndentGuide.activeBackground1": "#939393", "editorIndentGuide.background1": "#D3D3D3"],
            rules: [
                MonaTokenColorRule(token: "", foreground: "000000", background: "fffffe", fontStyle: nil),
                MonaTokenColorRule(token: "invalid", foreground: "cd3131", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "emphasis", foreground: nil, background: nil, fontStyle: "italic"),
                MonaTokenColorRule(token: "strong", foreground: nil, background: nil, fontStyle: "bold"),
                MonaTokenColorRule(token: "variable", foreground: "001188", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "variable.predefined", foreground: "4864AA", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "constant", foreground: "dd0000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "comment", foreground: "008000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "number", foreground: "098658", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "number.hex", foreground: "3030c0", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "regexp", foreground: "800000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "annotation", foreground: "808080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "type", foreground: "008080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter", foreground: "000000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter.html", foreground: "383838", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter.xml", foreground: "0000FF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag", foreground: "800000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag.id.pug", foreground: "4F76AC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag.class.pug", foreground: "4F76AC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "meta.scss", foreground: "800000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag", foreground: "e00000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.content.html", foreground: "FF0000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.html", foreground: "808080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.xml", foreground: "808080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.php", foreground: nil, background: nil, fontStyle: "bold"),
                MonaTokenColorRule(token: "key", foreground: "863B00", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.key.json", foreground: "A31515", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.value.json", foreground: "0451A5", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.name", foreground: "FF0000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value", foreground: "0451A5", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value.number", foreground: "098658", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value.unit", foreground: "098658", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value.html", foreground: "0000FF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value.xml", foreground: "0000FF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string", foreground: "A31515", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.html", foreground: "0000FF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.sql", foreground: "FF0000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.yaml", foreground: "0451A5", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword", foreground: "0000FF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword.json", foreground: "0451A5", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword.flow", foreground: "AF00DB", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword.flow.scss", foreground: "0000FF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.scss", foreground: "666666", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.sql", foreground: "778899", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.swift", foreground: "666666", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "predefined.sql", foreground: "C700C7", background: nil, fontStyle: nil),
            ]
        ),
        MonaTokenTheme(
            id: "vs-dark",
            base: "vs-dark",
            inherit: false,
            colors: ["editor.background": "#1E1E1E", "editor.foreground": "#D4D4D4", "editor.inactiveSelectionBackground": "#3A3D41", "editor.selectionHighlightBackground": "#ADD6FF26", "editorIndentGuide.activeBackground1": "#707070", "editorIndentGuide.background1": "#404040"],
            rules: [
                MonaTokenColorRule(token: "", foreground: "D4D4D4", background: "1E1E1E", fontStyle: nil),
                MonaTokenColorRule(token: "invalid", foreground: "f44747", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "emphasis", foreground: nil, background: nil, fontStyle: "italic"),
                MonaTokenColorRule(token: "strong", foreground: nil, background: nil, fontStyle: "bold"),
                MonaTokenColorRule(token: "variable", foreground: "74B0DF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "variable.predefined", foreground: "4864AA", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "variable.parameter", foreground: "9CDCFE", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "constant", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "comment", foreground: "608B4E", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "number", foreground: "B5CEA8", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "number.hex", foreground: "5BB498", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "regexp", foreground: "B46695", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "annotation", foreground: "cc6666", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "type", foreground: "3DC9B0", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter", foreground: "DCDCDC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter.html", foreground: "808080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter.xml", foreground: "808080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag.id.pug", foreground: "4F76AC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag.class.pug", foreground: "4F76AC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "meta.scss", foreground: "A79873", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "meta.tag", foreground: "CE9178", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag", foreground: "DD6A6F", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.content.html", foreground: "9CDCFE", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.html", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.xml", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.php", foreground: nil, background: nil, fontStyle: "bold"),
                MonaTokenColorRule(token: "key", foreground: "9CDCFE", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.key.json", foreground: "9CDCFE", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.value.json", foreground: "CE9178", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.name", foreground: "9CDCFE", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value", foreground: "CE9178", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value.number.css", foreground: "B5CEA8", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value.unit.css", foreground: "B5CEA8", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value.hex.css", foreground: "D4D4D4", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string", foreground: "CE9178", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.sql", foreground: "FF0000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword.flow", foreground: "C586C0", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword.json", foreground: "CE9178", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword.flow.scss", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.scss", foreground: "909090", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.sql", foreground: "778899", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.swift", foreground: "909090", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "predefined.sql", foreground: "FF00FF", background: nil, fontStyle: nil),
            ]
        ),
        MonaTokenTheme(
            id: "hc-black",
            base: "hc-black",
            inherit: false,
            colors: ["editor.background": "#000000", "editor.foreground": "#FFFFFF", "editorIndentGuide.activeBackground1": "#FFFFFF", "editorIndentGuide.background1": "#FFFFFF"],
            rules: [
                MonaTokenColorRule(token: "", foreground: "FFFFFF", background: "000000", fontStyle: nil),
                MonaTokenColorRule(token: "invalid", foreground: "f44747", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "emphasis", foreground: nil, background: nil, fontStyle: "italic"),
                MonaTokenColorRule(token: "strong", foreground: nil, background: nil, fontStyle: "bold"),
                MonaTokenColorRule(token: "variable", foreground: "1AEBFF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "variable.parameter", foreground: "9CDCFE", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "constant", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "comment", foreground: "608B4E", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "number", foreground: "FFFFFF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "regexp", foreground: "C0C0C0", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "annotation", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "type", foreground: "3DC9B0", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter", foreground: "FFFF00", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter.html", foreground: "FFFF00", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag.id.pug", foreground: "4F76AC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag.class.pug", foreground: "4F76AC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "meta", foreground: "D4D4D4", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "meta.tag", foreground: "CE9178", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.content.html", foreground: "1AEBFF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.html", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.xml", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.php", foreground: nil, background: nil, fontStyle: "bold"),
                MonaTokenColorRule(token: "key", foreground: "9CDCFE", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.key", foreground: "9CDCFE", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.value", foreground: "CE9178", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.name", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value", foreground: "3FF23F", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string", foreground: "CE9178", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.sql", foreground: "FF0000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword", foreground: "569CD6", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword.flow", foreground: "C586C0", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.sql", foreground: "778899", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.swift", foreground: "909090", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "predefined.sql", foreground: "FF00FF", background: nil, fontStyle: nil),
            ]
        ),
        MonaTokenTheme(
            id: "hc-light",
            base: "hc-light",
            inherit: false,
            colors: ["editor.background": "#FFFFFF", "editor.foreground": "#292929", "editorIndentGuide.activeBackground1": "#292929", "editorIndentGuide.background1": "#292929"],
            rules: [
                MonaTokenColorRule(token: "", foreground: "292929", background: "FFFFFF", fontStyle: nil),
                MonaTokenColorRule(token: "invalid", foreground: "B5200D", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "emphasis", foreground: nil, background: nil, fontStyle: "italic"),
                MonaTokenColorRule(token: "strong", foreground: nil, background: nil, fontStyle: "bold"),
                MonaTokenColorRule(token: "variable", foreground: "264F70", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "variable.predefined", foreground: "4864AA", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "constant", foreground: "dd0000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "comment", foreground: "008000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "number", foreground: "098658", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "number.hex", foreground: "3030c0", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "regexp", foreground: "800000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "annotation", foreground: "808080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "type", foreground: "008080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter", foreground: "000000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "delimiter.html", foreground: "383838", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag", foreground: "800000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag.id.pug", foreground: "4F76AC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "tag.class.pug", foreground: "4F76AC", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "meta.scss", foreground: "800000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag", foreground: "e00000", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.content.html", foreground: "B5200D", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.html", foreground: "808080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.xml", foreground: "808080", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "metatag.php", foreground: nil, background: nil, fontStyle: "bold"),
                MonaTokenColorRule(token: "key", foreground: "863B00", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.key.json", foreground: "A31515", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.value.json", foreground: "0451A5", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.name", foreground: "264F78", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "attribute.value", foreground: "0451A5", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string", foreground: "A31515", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "string.sql", foreground: "B5200D", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword", foreground: "0000FF", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "keyword.flow", foreground: "AF00DB", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.sql", foreground: "778899", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "operator.swift", foreground: "666666", background: nil, fontStyle: nil),
                MonaTokenColorRule(token: "predefined.sql", foreground: "C700C7", background: nil, fontStyle: nil),
            ]
        ),
    ]

    /// Looks up a builtin theme by id.
    public static func theme(for id: String) -> MonaTokenTheme? {
        builtinThemes.first { $0.id == id }
    }

    /// All four builtin theme ids in source-ordinal order.
    public static var ids: [String] { builtinThemes.map { $0.id } }
}

