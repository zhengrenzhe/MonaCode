// MonaSnippetAST.swift
//
// P06-T006 — Port the complete snippet parser and grammar.
//
// The snippet AST: the tree of marker nodes a parsed snippet produces. This is
// the Swift counterpart of Monaco's `Marker` / `Text` / `Placeholder` /
// `Choice` / `Variable` / `Transform` / `FormatString` classes
// (monaco-editor 0.56.0, `snippetParser.js`).
//
// The AST is a recursive enum over six marker kinds:
//
//   - `.text(value, span)`           — literal UTF-16 text.
//   - `.escape(escaped, span)`        — an escaped character (`\$`, `\\`, `\}`).
//   - `.tabstop(index, span)`         — `$n` / `${n}` (a bare tab stop).
//   - `.placeholder(index, children, span, transform)` — `${n:…}` or
//     `${n/regex/format/flags}`.
//   - `.choice(index, options, span)` — `${n|a,b,c|}`.
//   - `.variable(name, children, span, transform)` — `$NAME` /
//     `${NAME:…}` / `${NAME/regex/format/flags}`.
//
// Every marker carries a `MonaSnippetSpan` — the half-open `[start, end)` range
// of UTF-16 code-unit offsets into the *source* snippet text (the raw
// `[UInt16]` the parser consumed). Offsets are in UTF-16 units, not code
// points: a supplementary code point occupies two units and a lone surrogate
// occupies one. This matches the project's raw-UInt16 invariant
// (`MonaPieceTree`, `MonaLiteralSearch`, `MonaRegExpParser`).
//
// The AST is immutable and value-typed (Equatable, Hashable, Sendable) so parsed
// snippets can be shared across cursors without defensive copies.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A half-open `[start, end)` range of UTF-16 code-unit offsets into the source
/// snippet text. `start` and `end` count UTF-16 units (a supplementary code
/// point is two units; a lone surrogate is one).
public struct MonaSnippetSpan: Equatable, Hashable, Sendable {

    /// The inclusive start offset (UTF-16 code units).
    public let start: Int

    /// The exclusive end offset (UTF-16 code units).
    public let end: Int

    /// Creates a source span.
    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    /// The number of UTF-16 code units the span covers.
    public var length: Int { return end - start }
}

/// The seven transform format shorthands, verbatim from the snippet contract:
/// `upcase`, `downcase`, `capitalize`, `pascalcase`, `camelcase`,
/// `kebabcase`, `snakecase`.
public enum MonaSnippetShorthand: String, Equatable, Hashable, Sendable, CaseIterable {

    /// `/upcase` — uppercase every character.
    case upcase

    /// `/downcase` — lowercase every character.
    case downcase

    /// `/capitalize` — first character uppercase, the rest lowercase.
    case capitalize

    /// `/pascalcase` — PascalCase: words joined, each capitalized.
    case pascalcase

    /// `/camelcase` — camelCase: first word lowercase, rest capitalized.
    case camelcase

    /// `/kebabcase` — kebab-case: words separated by hyphens, all lowercase.
    case kebabcase

    /// `/snakecase` — snake_case: words separated by underscores, all lowercase.
    case snakecase
}

/// A single element of a transform replacement format. The format is the
/// `<format>` part of `${name/regex/<format>/flags}` — a sequence of literals
/// and capture references, exactly mirroring Monaco's `FormatString`.
///
/// The seven forms the grammar recognizes (from the contract `formatForms`):
///
///   - `.literal(s)`           — literal text.
///   - `.capture(n)`            — `$n` or `${n}`: substitute capture group `n`.
///   - `.shorthand(n, sh)`      — `${n:/shorthand}`: substitute capture `n`
///                                 after applying the named case shorthand.
///   - `.ifForm(n, s)`          — `${n:+s}`: emit `s` iff capture `n` matched.
///   - `.elseForm(n, s)`        — `${n:-s}`: emit `s` iff capture `n` did *not*
///                                 match (or matched empty); otherwise emit
///                                 the capture verbatim.
///   - `.ifElseForm(n, a, b)`   — `${n:?a:b}`: emit `a` iff capture `n` matched,
///                                 else `b`.
///   - `.defaultForm(n, s)`     — `${n:s}`: emit `s` iff capture `n` did not
///                                 match (or matched empty); otherwise emit
///                                 the capture verbatim.
public enum MonaSnippetFormatString: Equatable, Hashable, Sendable {

    /// Literal text emitted verbatim into the replacement.
    case literal(String)

    /// `$n` / `${n}`: substitute the text of capture group `n` (1-based).
    case capture(Int)

    /// `${n:/shorthand}`: substitute capture `n` after applying the shorthand.
    case shorthand(Int, MonaSnippetShorthand)

    /// `${n:+if}`: emit `if` iff capture `n` participated (matched non-empty).
    case ifForm(Int, String)

    /// `${n:-else}`: emit `else` when capture `n` is empty; otherwise emit the
    /// capture verbatim.
    case elseForm(Int, String)

    /// `${n:?if:else}`: emit `if` when capture `n` matched; else `else`.
    case ifElseForm(Int, String, String)

    /// `${n:default}`: emit `default` when capture `n` is empty; otherwise
    /// emit the capture verbatim.
    case defaultForm(Int, String)
}

/// A transform: the `regex / format / flags` triple inside
/// `${name/regex/format/flags}` or `${n/regex/format/flags}`.
///
/// `regex` is the *unescaped* pattern string (escaped forward slashes already
/// resolved to literal `/`). The Phase 02 `MonaRegExpParser` compiles it; on a
/// syntax error the transform falls back to the unresolved variable value
/// (never crashes — the contract's `malformedInput` rule).
public struct MonaSnippetTransform: Equatable, Hashable, Sendable {

    /// The RegExp pattern (unescaped; forward slashes literal).
    public let regex: String

    /// The replacement format — a sequence of `MonaSnippetFormatString` elements.
    public let format: [MonaSnippetFormatString]

    /// The flag string (e.g. `"g"`, `"i"`, `"gi"`, or `""`).
    public let flags: String

    /// Creates a transform.
    public init(regex: String, format: [MonaSnippetFormatString], flags: String) {
        self.regex = regex
        self.format = format
        self.flags = flags
    }
}

/// A parsed snippet marker. The recursive enum mirrors Monaco's `Marker` tree
/// (monaco-editor 0.56.0, `snippetParser.js`). Every case carries the source
/// `MonaSnippetSpan`; placeholders and variables carry their (possibly nested)
/// child markers and an optional transform.
public indirect enum MonaSnippetMarker: Equatable, Hashable, Sendable {

    /// Literal UTF-16 text.
    case text(String, MonaSnippetSpan)

    /// An escaped character (`\$`, `\\`, `\}`, or any unknown `\x` retained
    /// verbatim). `escaped` is the *resolved* character (e.g. `$` for `\$`).
    case escape(Character, MonaSnippetSpan)

    /// A bare tab stop: `$n` or `${n}`. `index == 0` is the final tab stop.
    case tabstop(index: Int, span: MonaSnippetSpan)

    /// A placeholder: `${n:children}` or `${n/regex/format/flags}`.
    /// `children` are the default markers (empty for a pure transform).
    /// `transform` is present for the `${n/regex/format/flags}` form.
    case placeholder(
        index: Int,
        children: [MonaSnippetMarker],
        span: MonaSnippetSpan,
        transform: MonaSnippetTransform?
    )

    /// A choice: `${n|opt1,opt2,…|}`. `options` is the resolved (unescaped)
    /// list; the first option is the rendered default.
    case choice(index: Int, options: [String], span: MonaSnippetSpan)

    /// A variable: `$NAME`, `${NAME:children}`, or
    /// `${NAME/regex/format/flags}`. `children` are the default markers
    /// (rendered when the resolver misses). `transform` is present for the
    /// `${NAME/regex/format/flags}` form.
    case variable(
        name: String,
        children: [MonaSnippetMarker],
        span: MonaSnippetSpan,
        transform: MonaSnippetTransform?
    )

    /// The source span of this marker.
    public var span: MonaSnippetSpan {
        switch self {
        case .text(_, let s),
             .tabstop(_, let s),
             .placeholder(_, _, let s, _),
             .choice(_, _, let s),
             .variable(_, _, let s, _),
             .escape(_, let s):
            return s
        }
    }
}

/// A placeholder record (index + rendered value + span), produced when the
/// snippet tree is flattened for session placement. Mirrors Monaco's
/// `Placeholder` / `OneSnippet` concept.
public struct MonaSnippetPlacedPlaceholder: Equatable, Hashable, Sendable {

    /// The tab-stop ordinal. `0` is the final tab stop.
    public let index: Int

    /// The rendered text the placeholder contributes (its default value or the
    /// first choice option).
    public let value: String

    /// The span the placeholder occupies in the *source* snippet text.
    public let sourceSpan: MonaSnippetSpan

    /// Creates a placed placeholder.
    public init(index: Int, value: String, sourceSpan: MonaSnippetSpan) {
        self.index = index
        self.value = value
        self.sourceSpan = sourceSpan
    }
}
