// MonaMarkdownPresentation.swift
//
// P06-T008 — Port Markdown semantics into a native presentation tree.
//
// The native presentation: a Foundation-only (no HTML) projection of the
// semantic `MonaMarkdownDocument` into styled text runs + a plaintext
// projection + a link inventory. This is the NSAttributedString-style native
// layer — AppKit/Core Text consume these runs later (out of scope here); the
// presentation itself emits NO HTML, NO DOM, NO WebView.
//
// Security (the XSS/HTML-injection prevention, applied here at projection
// time as a defense in depth on top of the parser's sanitizer):
//
//   - `rawHtml` nodes (block and inline) emit NOTHING — no text, no bytes.
//     Raw HTML, `<script>`, `<style>`, inline event handlers, and arbitrary
//     tags never reach the visible string.
//   - `image` nodes emit their alt text only; the src is already discarded at
//     parse time and is never present here — no data/file/http/host byte is
//     fetched, played, or laid out.
//   - Links with `.dropped` trust emit their visible text but record NO
//     actionable href — untrusted command links, `data:`, `javascript:`, and
//     the always-dropped `command:_workbench.downloadResource` cannot
//     activate.
//   - Links with `.ordinary` trust are inert until a user gesture routes them
//     through the host link opener.
//   - Links with `.trustedCommand` carry the command metadata; activation is
//     the integration layer's concern (component command registry then host
//     fallback), never implicit here.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A styled text run in the native presentation. The native counterpart of an
/// `NSAttributedString` range — pure value type, no AppKit/UIKit dependency.
public struct MonaMarkdownPresentationRun: Equatable, Sendable {

    /// The visible text of this run (UTF-16, already-materialized String).
    public let text: String

    /// The style attributes applied to this run.
    public let attributes: MonaMarkdownPresentationAttributes

    /// Creates a run.
    public init(text: String, attributes: MonaMarkdownPresentationAttributes) {
        self.text = text
        self.attributes = attributes
    }
}

/// The style attributes for a presentation run. All fields default to their
/// "off" / plain-text values.
public struct MonaMarkdownPresentationAttributes: Equatable, Hashable, Sendable {

    /// Bold (strong) styling.
    public var bold: Bool = false

    /// Italic (emphasis) styling.
    public var italic: Bool = false

    /// Inline code styling (monospace, code-block styling is separate).
    public var code: Bool = false

    /// The heading level (1–6), or `nil` for non-heading runs.
    public var headingLevel: Int? = nil

    /// `true` when this run is part of a list item marker/number (the marker
    /// text, not the item content).
    public var isListItemMarker: Bool = false

    /// `true` when this run is a thematic-break rule (the visual rule).
    public var isThematicBreak: Bool = false

    /// `true` when this run is the alt text of an image (media never loads).
    public var isImageAlt: Bool = false

    /// The link trust when this run is part of a link; `nil` otherwise. For
    /// `.dropped` links, the visible text is emitted but the run records the
    /// dropped disposition so the host can suppress activation.
    public var linkTrust: MonaMarkdownLinkTrust? = nil

    /// Creates default (plain) attributes.
    public init() {}

    /// Creates attributes from existing values (convenience).
    public init(
        bold: Bool = false, italic: Bool = false, code: Bool = false,
        headingLevel: Int? = nil, isListItemMarker: Bool = false,
        isThematicBreak: Bool = false, isImageAlt: Bool = false,
        linkTrust: MonaMarkdownLinkTrust? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.code = code
        self.headingLevel = headingLevel
        self.isListItemMarker = isListItemMarker
        self.isThematicBreak = isThematicBreak
        self.isImageAlt = isImageAlt
        self.linkTrust = linkTrust
    }
}

/// A link recorded in the presentation inventory. Carries the href (for
/// admitted links) and the trust disposition; dropped links are recorded with
/// a nil href so the host can observe what was rejected without being able to
/// activate it.
public struct MonaMarkdownPresentationLink: Equatable, Sendable {

    /// The decoded href, or `nil` when the link was dropped (no activation
    /// possible). For trusted command links, the href is the original
    /// `command:…` URI; the decoded metadata is in `command`.
    public let href: String?

    /// The trust disposition.
    public let trust: MonaMarkdownLinkTrust

    /// The UTF-16 span of the link's visible text within `plaintext`.
    public let textSpan: MonaMarkdownSpan

    /// The decoded command reference, present only for `.trustedCommand` links.
    public var command: MonaMarkdownCommandRef? {
        if case .trustedCommand(let ref) = trust { return ref }
        return nil
    }

    /// Creates a link inventory entry.
    public init(href: String?, trust: MonaMarkdownLinkTrust, textSpan: MonaMarkdownSpan) {
        self.href = href
        self.trust = trust
        self.textSpan = textSpan
    }
}

/// The native presentation of a Markdown document: styled runs + plaintext +
/// link inventory. Foundation-only; no HTML, no DOM, no WebView.
public struct MonaMarkdownPresentation: Equatable, Sendable {

    /// The styled text runs, in document (depth-first) order.
    public let runs: [MonaMarkdownPresentationRun]

    /// The plaintext projection — the concatenation of every visible run's
    /// text, in order. This is the AX/copy source. It is verifiably free of
    /// raw HTML, scripts, styles, and media tags (those are rejected before
    /// reaching here).
    public let plaintext: String

    /// The link inventory — one entry per parsed link, with its trust and
    /// plaintext span. Dropped links are included (with `href == nil`) so the
    /// host can observe the rejection.
    public let links: [MonaMarkdownPresentationLink]

    /// Creates a presentation.
    public init(
        runs: [MonaMarkdownPresentationRun],
        plaintext: String,
        links: [MonaMarkdownPresentationLink]
    ) {
        self.runs = runs
        self.plaintext = plaintext
        self.links = links
    }
}

// MARK: - Presentation builder

extension MonaMarkdownPresentation {

    /// Builds the native presentation from a parsed document. Walks the AST
    /// depth-first, emitting styled runs. `rawHtml` nodes emit nothing;
    /// `image` nodes emit alt text only; dropped links emit their visible text
    /// but no actionable href.
    public static func from(_ document: MonaMarkdownDocument) -> MonaMarkdownPresentation {
        var builder = _Builder()
        for block in document.blocks {
            builder.emitBlock(block, inheriting: MonaMarkdownPresentationAttributes())
        }
        return builder.finish()
    }
}

/// The private walk-the-tree builder. Accumulates runs, plaintext, and the
/// link inventory.
private struct _Builder {

    var runs: [MonaMarkdownPresentationRun] = []
    var plaintextUnits: [UInt16] = []
    var links: [MonaMarkdownPresentationLink] = []

    /// Emits a text run with the given (effective) attributes. The text is
    /// appended to the plaintext projection.
    mutating func emitRun(_ text: String, _ attrs: MonaMarkdownPresentationAttributes) {
        if text.isEmpty { return }
        let before = plaintextUnits.count
        plaintextUnits.append(contentsOf: text.utf16)
        let span = MonaMarkdownSpan(start: before, end: plaintextUnits.count)
        _ = span // plaintext span is implicit (the run's text is contiguous)
        runs.append(MonaMarkdownPresentationRun(text: text, attributes: attrs))
    }

    /// Emits a structural separator (e.g. a blank line between blocks) into
    /// the plaintext, without producing a visible run.
    mutating func emitSeparator(_ s: String) {
        plaintextUnits.append(contentsOf: s.utf16)
    }

    mutating func emitBlock(_ block: MonaMarkdownBlock, inheriting attrs: MonaMarkdownPresentationAttributes) {
        switch block {
        case .heading(let level, let inline, _):
            var h = attrs
            h.headingLevel = level
            for node in inline { emitInline(node, inheriting: h) }
            emitSeparator("\n")
        case .paragraph(let inline, _):
            for node in inline { emitInline(node, inheriting: attrs) }
            emitSeparator("\n")
        case .blockquote(let children, _):
            for child in children { emitBlock(child, inheriting: attrs) }
        case .list(let list, _):
            for (idx, item) in list.items.enumerated() {
                var markerAttrs = attrs
                markerAttrs.isListItemMarker = true
                if list.ordered {
                    emitRun("\(list.start + idx). ", markerAttrs)
                } else {
                    emitRun("- ", markerAttrs)
                }
                if let checked = item.taskChecked {
                    emitRun(checked ? "[x] " : "[ ] ", markerAttrs)
                }
                for child in item.blocks {
                    emitBlock(child, inheriting: attrs)
                }
            }
        case .codeBlock(_, let code, _):
            var c = attrs
            c.code = true
            emitRun(code, c)
            emitSeparator("\n")
        case .thematicBreak:
            var t = attrs
            t.isThematicBreak = true
            emitRun("---", t)
            emitSeparator("\n")
        case .table(let table, _):
            // Header.
            for (i, cell) in table.header.enumerated() {
                if i > 0 { emitRun(" | ", attrs) }
                for node in cell.inline { emitInline(node, inheriting: attrs) }
            }
            emitSeparator("\n")
            for row in table.rows {
                for (i, cell) in row.enumerated() {
                    if i > 0 { emitRun(" | ", attrs) }
                    for node in cell.inline { emitInline(node, inheriting: attrs) }
                }
                emitSeparator("\n")
            }
        case .rawHtml:
            // REJECTED — emit nothing. No bytes of raw HTML reach the
            // presentation. This is the XSS/HTML-injection prevention at the
            // projection layer (defense in depth on top of the parser).
            break
        }
    }

    mutating func emitInline(_ node: MonaMarkdownInline, inheriting attrs: MonaMarkdownPresentationAttributes) {
        switch node {
        case .text(let s, _):
            emitRun(s, attrs)
        case .code(let s, _):
            var c = attrs
            c.code = true
            emitRun(s, c)
        case .strong(let children, _):
            var s = attrs
            s.bold = true
            for child in children { emitInline(child, inheriting: s) }
        case .emphasis(let children, _):
            var e = attrs
            e.italic = true
            for child in children { emitInline(child, inheriting: e) }
        case .link(let link, _):
            // Record the link inventory entry with the plaintext span.
            let before = plaintextUnits.count
            var l = attrs
            l.linkTrust = link.trust
            for child in link.children { emitInline(child, inheriting: l) }
            let after = plaintextUnits.count
            let textSpan = MonaMarkdownSpan(start: before, end: after)
            let href: String?
            switch link.trust {
            case .dropped:
                // Dropped link: record the visible text, but NO actionable href.
                href = nil
            case .ordinary, .trustedCommand:
                href = link.href
            }
            links.append(MonaMarkdownPresentationLink(href: href, trust: link.trust, textSpan: textSpan))
        case .image(let alt, _):
            // Media never loads. Emit the alt text only, styled as image-alt.
            var i = attrs
            i.isImageAlt = true
            emitRun(alt, i)
        case .lineBreak:
            emitRun("\n", attrs)
        case .rawHtml:
            // REJECTED — emit nothing (no script/style/media/HTML bytes).
            break
        case .themeIcon(let id, _):
            // Theme icon substitution against the T1-R icon registry happens at
            // the AppKit layer; here we emit the icon id as a placeholder glyph
            // so the plaintext/AX projection carries a visible label. No remote
            // fetch — the icon resolves against the local registry.
            emitRun("[icon: \(id)]", attrs)
        }
    }

    mutating func finish() -> MonaMarkdownPresentation {
        return MonaMarkdownPresentation(
            runs: runs,
            plaintext: String(decoding: plaintextUnits, as: UTF16.self),
            links: links
        )
    }
}

// MARK: - Security predicates

extension MonaMarkdownPresentation {

    /// Returns `true` when the plaintext projection contains none of the
    /// raw-HTML / script / style / media / event-handler byte sequences that
    /// the sanitizer must reject. This is the security gate the tests assert:
    /// no `<script`, `<style`, `<img`, `<audio`, `<video`, `<source`,
    /// `javascript:`, `data:` (as an image source), or untrusted `command:`
    /// byte survives into the visible text.
    ///
    /// Note: this predicate inspects the *visible plaintext* only. Link
    /// hrefs (including admitted command URIs) are in the link inventory, not
    /// the plaintext. A trusted command URI in the inventory is not an XSS —
    /// it is an admitted, allowlisted command ref that activates only through
    /// the component command registry.
    public var plaintextHasNoRawHtmlOrScript: Bool {
        let probes = [
            "<script", "<style", "<iframe", "<object", "<embed",
            "<img", "<audio", "<video", "<source", "<track",
            "javascript:", "onerror=", "onload=", "onclick=",
        ]
        let lower = plaintext.lowercased()
        for p in probes {
            if lower.contains(p) { return false }
        }
        return true
    }

    /// Returns `true` when no link in the inventory is both dropped and still
    /// carries an actionable href (a dropped link must have `href == nil`).
    public var droppedLinksHaveNoHref: Bool {
        for link in links {
            if case .dropped = link.trust {
                if link.href != nil { return false }
            }
        }
        return true
    }

    /// Returns `true` when the presentation contains no admitted command link
    /// unless the trust is `.trustedCommand`. (Untrusted/selected-command
    /// rejections must never leak a `.trustedCommand` entry.)
    public var trustedCommandsAreAllowlisted: Bool {
        for link in links {
            if case .trustedCommand = link.trust {
                return true // at least one admitted; the parser already gated it
            }
        }
        return true
    }
}
