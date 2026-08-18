// MonaMarkdownAST.swift
//
// P06-T008 — Port Markdown semantics into a native presentation tree.
//
// The Markdown semantic tree: the immutable, value-typed document the parser
// produces. This is the Swift counterpart of the typed-node projection of
// Marked 14.0.0's synchronous GFM default grammar (monaco-editor 0.56.0,
// `esm/vs/base/common/marked/marked.js`, SHA-256
// `75746ae6ff08f4e9b94090ed018e5ac1bf7dbb7e8fcdb4ec48784bd6569d9fda`).
//
// The AST deliberately carries NO HTML string, NO DOM node, and NO WebView
// handle. Raw HTML tokens (block and inline) are captured as `rawHtml` nodes
// only so the sanitizer can reject them before presentation; they never
// execute, style, load media, or lay out content. Markdown image syntax
// contributes its parsed alt text only — the src URI is parsed and discarded
// at parse time, so no data/file/http/host byte is ever retained for a fetch.
//
// Every node carries a `MonaMarkdownSpan` — the half-open `[start, end)` range
// of UTF-16 code-unit offsets into the *source* `[UInt16]` the parser
// consumed. Offsets count UTF-16 units (a supplementary code point is two
// units; a lone surrogate is one), matching the project's raw-UInt16
// invariant (`MonaPieceTree`, `MonaLiteralSearch`, `MonaRegExpParser`, and
// the snippet parser `MonaSnippetParser`).
//
// The AST is immutable and value-typed (Equatable, Hashable, Sendable) so a
// parsed document can be shared across widgets/cursors without defensive
// copies.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A half-open `[start, end)` range of UTF-16 code-unit offsets into the source
/// Markdown text. `start` and `end` count UTF-16 units (a supplementary code
/// point is two units; a lone surrogate is one).
public struct MonaMarkdownSpan: Equatable, Hashable, Sendable {

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

// MARK: - Link trust + command metadata

/// The trust disposition of a parsed link, applied by the native sanitizer at
/// tree-build time (before any control is created). Mirrors the MD1-R trust
/// contract: untrusted command links are removed; admitted non-command
/// schemes are inert until user activation; trusted command links survive and
/// route through the component command registry then the host fallback.
public enum MonaMarkdownLinkTrust: Equatable, Hashable, Sendable {

    /// An admitted non-command scheme (http, https, mailto, file, vscode-file,
    /// vscode-remote, vscode-remote-resource, vscode-notebook-cell, private).
    /// Inert until a user gesture routes it through the host link opener.
    case ordinary

    /// A trusted command link that survived the allowlist. The command ref
    /// carries the decoded id and raw query (the pinned URI/JSON argument
    /// rules are applied at activation time, never implicitly).
    case trustedCommand(MonaMarkdownCommandRef)

    /// A rejected link: `data:`, `javascript:`, the always-dropped
    /// `command:_workbench.downloadResource`, an untrusted `command:` URI,
    /// or any scheme not on the admitted list. The link does not appear in
    /// presentation output and never activates.
    case dropped
}

/// A decoded command reference for a trusted command link
/// (`command:<id>?<args>`). The `id` is the URL-decoded path component; the
/// `rawQuery` is the undecoded query string (activation applies the pinned
/// URI/JSON argument rules). This is the "trusted command metadata" the
/// semantic tree admits.
public struct MonaMarkdownCommandRef: Equatable, Hashable, Sendable {

    /// The command id (URL-decoded path component of `command:<id>?…`).
    public let id: String

    /// The raw, undecoded query string (everything after the first `?`), or
    /// `nil` when the command URI has no query component.
    public let rawQuery: String?

    /// Creates a command reference.
    public init(id: String, rawQuery: String?) {
        self.id = id
        self.rawQuery = rawQuery
    }
}

// MARK: - Inline nodes

/// A parsed inline node. The recursive enum mirrors the inline-level grammar
/// the pinned Marked 14.0.0 GFM subset admits. Every case carries its source
/// `MonaMarkdownSpan`.
public indirect enum MonaMarkdownInline: Equatable, Hashable, Sendable {

    /// Literal UTF-16 text.
    case text(String, MonaMarkdownSpan)

    /// Inline code (`` `code` `` or ``` `` code `` ```). The payload is the
    /// decoded code text (delimiter backticks stripped).
    case code(String, MonaMarkdownSpan)

    /// Strong / bold (`**text**` or `__text__`).
    case strong([MonaMarkdownInline], MonaMarkdownSpan)

    /// Emphasis / italic (`*text*` or `_text_`).
    case emphasis([MonaMarkdownInline], MonaMarkdownSpan)

    /// A link `[text](href)` or `[text][ref]`. The payload carries the
    /// decoded href, optional title, child inline nodes, and the trust
    /// disposition the sanitizer computed at build time.
    case link(MonaMarkdownLink, MonaMarkdownSpan)

    /// An image `![alt](src)`. The payload is the decoded **alt text only**.
    /// The src URI is parsed and discarded at parse time — it is never
    /// retained in the AST, never appears in presentation output, and is
    /// never fetched (media is an explicit feature cut).
    case image(alt: String, span: MonaMarkdownSpan)

    /// A hard line break (`  \n`, a backslash at EOL, or a GFM `---`-style
    /// break inside prose).
    case lineBreak(MonaMarkdownSpan)

    /// A captured raw-HTML run (block or inline). The sanitizer rejects these
    /// before presentation — they never execute, style, load media, or lay
    /// out content. Retained in the AST only so callers can observe what was
    /// rejected (and so the security tests can assert the bytes were parsed,
    /// not silently dropped before classification).
    case rawHtml(String, MonaMarkdownSpan)

    /// A theme-icon token `$(icon-id)` parsed when `supportThemeIcons` is on.
    /// Substitution against the T1-R icon registry happens at presentation
    /// time; this node carries only the icon id.
    case themeIcon(id: String, span: MonaMarkdownSpan)

    /// The source span of this inline node.
    public var span: MonaMarkdownSpan {
        switch self {
        case .text(_, let s),
             .code(_, let s),
             .strong(_, let s),
             .emphasis(_, let s),
             .link(_, let s),
             .image(_, let s),
             .lineBreak(let s),
             .rawHtml(_, let s),
             .themeIcon(_, let s):
            return s
        }
    }
}

/// A parsed link with its sanitizer-computed trust disposition.
public struct MonaMarkdownLink: Equatable, Hashable, Sendable {

    /// The decoded href (URL escapes resolved).
    public let href: String

    /// The optional link title (`[text](href "title")`).
    public let title: String?

    /// The link's child inline nodes (the visible text).
    public let children: [MonaMarkdownInline]

    /// The trust disposition the sanitizer computed at build time.
    public let trust: MonaMarkdownLinkTrust

    /// Creates a link.
    public init(
        href: String,
        title: String?,
        children: [MonaMarkdownInline],
        trust: MonaMarkdownLinkTrust
    ) {
        self.href = href
        self.title = title
        self.children = children
        self.trust = trust
    }
}

// MARK: - Block nodes

/// A list item — the inline/blocks it contains, an optional task checkbox
/// state, and its source span.
public struct MonaMarkdownListItem: Equatable, Hashable, Sendable {

    /// `nil` when the item is not a GFM task item; otherwise the checkbox
    /// state (`true` = checked `[x]`, `false` = unchecked `[ ]`).
    public let taskChecked: Bool?

    /// The block children of the item (paragraphs, nested lists, etc.).
    public let blocks: [MonaMarkdownBlock]

    /// The source span of the item (marker + content).
    public let span: MonaMarkdownSpan

    /// Creates a list item.
    public init(taskChecked: Bool?, blocks: [MonaMarkdownBlock], span: MonaMarkdownSpan) {
        self.taskChecked = taskChecked
        self.blocks = blocks
        self.span = span
    }
}

/// A GFM list — ordered or unordered, with the start ordinal for ordered
/// lists.
public struct MonaMarkdownList: Equatable, Hashable, Sendable {

    /// `true` for ordered lists (`1.` / `2.`), `false` for unordered
    /// (`-` / `*` / `+`).
    public let ordered: Bool

    /// The start ordinal for ordered lists (e.g. `3` for `3.`); `0` for
    /// unordered lists.
    public let start: Int

    /// The items, in source order.
    public let items: [MonaMarkdownListItem]

    /// Creates a list.
    public init(ordered: Bool, start: Int, items: [MonaMarkdownListItem]) {
        self.ordered = ordered
        self.start = start
        self.items = items
    }
}

/// A GFM table cell — its inline content.
public struct MonaMarkdownTableCell: Equatable, Hashable, Sendable {

    /// The inline nodes in the cell.
    public let inline: [MonaMarkdownInline]

    /// Creates a cell.
    public init(inline: [MonaMarkdownInline]) {
        self.inline = inline
    }
}

/// The column alignment for a GFM table (`:---`, `:--:`, `---:`).
public enum MonaMarkdownTableAlignment: Equatable, Hashable, Sendable {
    case none
    case left
    case center
    case right
}

/// A GFM table — header row, body rows, and per-column alignment.
public struct MonaMarkdownTable: Equatable, Hashable, Sendable {

    /// The header row cells.
    public let header: [MonaMarkdownTableCell]

    /// The body rows (each a list of cells).
    public let rows: [[MonaMarkdownTableCell]]

    /// The per-column alignment (one entry per column).
    public let alignments: [MonaMarkdownTableAlignment]

    /// Creates a table.
    public init(
        header: [MonaMarkdownTableCell],
        rows: [[MonaMarkdownTableCell]],
        alignments: [MonaMarkdownTableAlignment]
    ) {
        self.header = header
        self.rows = rows
        self.alignments = alignments
    }
}

/// A parsed block node. The recursive enum mirrors the block-level grammar
/// the pinned Marked 14.0.0 GFM subset admits. Every case carries its source
/// `MonaMarkdownSpan`.
public indirect enum MonaMarkdownBlock: Equatable, Hashable, Sendable {

    /// An ATX heading (`#` … `######`). `level` is 1–6.
    case heading(level: Int, inline: [MonaMarkdownInline], span: MonaMarkdownSpan)

    /// A paragraph.
    case paragraph([MonaMarkdownInline], MonaMarkdownSpan)

    /// A blockquote (`> …`); children are the blocks inside the quote.
    case blockquote([MonaMarkdownBlock], MonaMarkdownSpan)

    /// A list (ordered/unordered, nested, with optional task items).
    case list(MonaMarkdownList, MonaMarkdownSpan)

    /// A fenced code block (``` ``` ``` or `~~~`). `info` is the first
    /// language-info token (the info string after the opening fence, first
    /// whitespace-delimited token); `code` is the decoded content.
    case codeBlock(info: String?, code: String, span: MonaMarkdownSpan)

    /// A thematic break (`---`, `***`, `___`).
    case thematicBreak(MonaMarkdownSpan)

    /// A GFM table.
    case table(MonaMarkdownTable, MonaMarkdownSpan)

    /// A captured raw-HTML block. The sanitizer rejects these before
    /// presentation — they never execute, style, load media, or lay out
    /// content.
    case rawHtml(String, MonaMarkdownSpan)

    /// The source span of this block.
    public var span: MonaMarkdownSpan {
        switch self {
        case .heading(_, _, let s),
             .paragraph(_, let s),
             .blockquote(_, let s),
             .list(_, let s),
             .codeBlock(_, _, let s),
             .thematicBreak(let s),
             .table(_, let s),
             .rawHtml(_, let s):
            return s
        }
    }
}

/// The parsed document — the root of the semantic tree.
public struct MonaMarkdownDocument: Equatable, Hashable, Sendable {

    /// The top-level blocks, in source (depth-first) order.
    public let blocks: [MonaMarkdownBlock]

    /// The span covering the whole document.
    public let span: MonaMarkdownSpan

    /// Creates a document.
    public init(blocks: [MonaMarkdownBlock], span: MonaMarkdownSpan) {
        self.blocks = blocks
        self.span = span
    }
}

// MARK: - Input value type

/// The trust the parser admits for a `MonaMarkdownString`. Mirrors Monaco's
/// `isTrusted` boolean and `enabledCommands` allowlist.
public enum MonaMarkdownTrust: Equatable, Hashable, Sendable {

    /// `isTrusted = false` (the default). Command links are dropped; admitted
    /// non-command schemes are inert until user activation.
    case untrusted

    /// `isTrusted = true`. Every command id is admitted; command activation
    /// routes through the component command registry then the host fallback.
    case fullyTrusted

    /// `enabledCommands = […]`. A command link survives only when its id is
    /// in the array; otherwise it is consumed without execution.
    case selectedCommands([String])
}

/// A Markdown value — the Swift counterpart of Monaco's `IMarkdownString` with
/// the `supportHtml` member cut. Carries the raw UTF-16 value, explicit trust,
/// and the theme-icon bit. (`baseUri` and the `uris` href-to-URI map are
/// integration concerns outside this layer; the parser does not read them.)
public struct MonaMarkdownString: Equatable, Hashable, Sendable {

    /// The raw UTF-16 code units of the value. Lone surrogates are preserved
    /// verbatim (never repaired).
    public let units: [UInt16]

    /// The trust the parser admits for command links.
    public let trust: MonaMarkdownTrust

    /// `true` when `$(icon-id)` theme-icon tokens should be parsed.
    public let supportThemeIcons: Bool

    /// Creates a Markdown value. `trust` defaults to `.untrusted`.
    public init(units: [UInt16], trust: MonaMarkdownTrust = .untrusted, supportThemeIcons: Bool = false) {
        self.units = units
        self.trust = trust
        self.supportThemeIcons = supportThemeIcons
    }

    /// Convenience: creates a value from a Swift string (via `.utf16`).
    public init(_ text: String, trust: MonaMarkdownTrust = .untrusted, supportThemeIcons: Bool = false) {
        self.units = Array(text.utf16)
        self.trust = trust
        self.supportThemeIcons = supportThemeIcons
    }
}
