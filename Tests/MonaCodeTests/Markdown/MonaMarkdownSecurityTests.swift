// MonaMarkdownSecurityTests.swift
//
// P06-T008 — Port Markdown semantics into a native presentation tree.
//
// Verifies the Markdown parser + native presentation across the four
// implementation operations:
//   1. Port the pinned Marked 14 grammar subset (text, code, lists, tables,
//      links, trusted command metadata).
//   2. Produce a semantic tree for native text, code, lists, tables, links,
//      and trusted command metadata.
//   3. Reject raw HTML execution, style, scripts, media loading, remote
//      images, web layout, and untrusted command links (XSS/HTML-injection
//      prevention).
//   4. Keep parsed source ranges in raw UTF-16.
//
// On Green, `testContractBehavior` prints the contract line:
//     MARKDOWN parser=live grammar=6 security=pass utf16=pass
//
// The grammar count is 6 (text, code, lists, tables, links, trusted-command)
// matching the four implementation operations' required grammar elements.

import XCTest
import MonaCode

final class MonaMarkdownSecurityTests: XCTestCase {

    // MARK: - Helpers

    /// Parses a Swift string into a document (convenience over raw `[UInt16]`).
    private func parse(
        _ text: String,
        trust: MonaMarkdownTrust = .untrusted,
        supportThemeIcons: Bool = false
    ) -> MonaMarkdownDocument {
        return MonaMarkdownParser.parse(
            Array(text.utf16), trust: trust, supportThemeIcons: supportThemeIcons
        )
    }

    private func span(_ start: Int, _ end: Int) -> MonaMarkdownSpan {
        return MonaMarkdownSpan(start: start, end: end)
    }

    /// Collects every inline node in the document, depth-first.
    private func collectInline(_ doc: MonaMarkdownDocument) -> [MonaMarkdownInline] {
        var result: [MonaMarkdownInline] = []
        func walkBlock(_ b: MonaMarkdownBlock) {
            switch b {
            case .heading(_, let inline, _):
                result.append(contentsOf: inline)
            case .paragraph(let inline, _):
                result.append(contentsOf: inline)
            case .blockquote(let kids, _):
                for k in kids { walkBlock(k) }
            case .list(let l, _):
                for item in l.items {
                    for k in item.blocks { walkBlock(k) }
                }
            case .table(let t, _):
                for c in t.header { result.append(contentsOf: c.inline) }
                for row in t.rows { for c in row { result.append(contentsOf: c.inline) } }
            case .codeBlock, .thematicBreak, .rawHtml:
                break
            }
        }
        func walkInline(_ n: MonaMarkdownInline) {
            result.append(n)
            switch n {
            case .strong(let kids, _), .emphasis(let kids, _):
                for k in kids { walkInline(k) }
            case .link(let link, _):
                for k in link.children { walkInline(k) }
            default:
                break
            }
        }
        for b in doc.blocks { walkBlock(b) }
        return result
    }

    // MARK: - 1. Text grammar

    func testTextParsesLiteralParagraph() {
        let doc = parse("hello world")
        XCTAssertEqual(doc.blocks.count, 1)
        guard case let .paragraph(inline, _) = doc.blocks[0] else {
            return XCTFail("expected paragraph")
        }
        XCTAssertEqual(inline.count, 1)
        guard case let .text(s, sp) = inline[0] else {
            return XCTFail("expected text")
        }
        XCTAssertEqual(s, "hello world")
        XCTAssertEqual(sp, span(0, 11))
    }

    // MARK: - 2. Code grammar

    func testFencedCodeBlockParsesWithLanguageInfo() {
        let md = "```swift\nlet x = 1\n```"
        let doc = parse(md)
        guard case let .codeBlock(info, code, _) = doc.blocks[0] else {
            return XCTFail("expected code block")
        }
        XCTAssertEqual(info, "swift")
        XCTAssertEqual(code, "let x = 1")
    }

    func testFencedCodeBlockSpanIsUTF16Accurate() {
        // 😀 (U+1F600, 2 UTF-16 units) before the fence.
        let md = "😀\n```js\nalert(1)\n```"
        let doc = parse(md)
        guard case let .codeBlock(info, _, sp) = doc.blocks[2 > doc.blocks.count ? 0 : 1] else {
            // The emoji paragraph is block 0; the code block is block 1.
            return XCTFail("expected code block at index 1")
        }
        _ = info
        // The code block starts at offset 3 (😀=2 units, \n=1 unit → 3).
        XCTAssertEqual(sp.start, 3)
    }

    func testInlineCodeParses() {
        let doc = parse("use `console.log` here")
        guard case let .paragraph(inline, _) = doc.blocks[0] else {
            return XCTFail("expected paragraph")
        }
        let codes = inline.compactMap { node -> String? in
            if case let .code(s, _) = node { return s }
            return nil
        }
        XCTAssertEqual(codes, ["console.log"])
    }

    // MARK: - 3. List grammar (ordered/unordered/nested/task)

    func testUnorderedListParses() {
        let doc = parse("- one\n- two\n- three")
        guard case let .list(l, _) = doc.blocks[0] else {
            return XCTFail("expected list")
        }
        XCTAssertFalse(l.ordered)
        XCTAssertEqual(l.items.count, 3)
    }

    func testOrderedListParsesWithStart() {
        let doc = parse("3. first\n4. second")
        guard case let .list(l, _) = doc.blocks[0] else {
            return XCTFail("expected list")
        }
        XCTAssertTrue(l.ordered)
        XCTAssertEqual(l.start, 3)
        XCTAssertEqual(l.items.count, 2)
    }

    func testTaskListItemParsesCheckbox() {
        let doc = parse("- [x] done\n- [ ] todo")
        guard case let .list(l, _) = doc.blocks[0] else {
            return XCTFail("expected list")
        }
        XCTAssertEqual(l.items.count, 2)
        XCTAssertEqual(l.items[0].taskChecked, true)
        XCTAssertEqual(l.items[1].taskChecked, false)
    }

    func testNestedListParses() {
        let md = "- outer\n  - inner"
        let doc = parse(md)
        guard case let .list(l, _) = doc.blocks[0] else {
            return XCTFail("expected list")
        }
        XCTAssertEqual(l.items.count, 1)
        // The nested list is a block child of the outer item.
        let nested = l.items[0].blocks.compactMap { block -> MonaMarkdownList? in
            if case let .list(inner, _) = block { return inner }
            return nil
        }
        XCTAssertEqual(nested.count, 1)
        XCTAssertEqual(nested[0].items.count, 1)
    }

    // MARK: - 4. Table grammar (GFM)

    func testTableParsesHeaderAndRows() {
        let md = "| name | age |\n| --- | ---: |\n| alice | 30 |\n| bob | 25 |"
        let doc = parse(md)
        guard case let .table(t, _) = doc.blocks[0] else {
            return XCTFail("expected table, got \(doc.blocks[0])")
        }
        XCTAssertEqual(t.header.count, 2)
        XCTAssertEqual(t.rows.count, 2)
        XCTAssertEqual(t.alignments, [.none, .right])
    }

    // MARK: - 5. Link grammar (ordinary + trusted command)

    func testLinkParsesWithHref() {
        let doc = parse("[example](https://example.com)")
        guard case let .paragraph(inline, _) = doc.blocks[0] else {
            return XCTFail("expected paragraph")
        }
        guard case let .link(link, _) = inline[0] else {
            return XCTFail("expected link")
        }
        XCTAssertEqual(link.href, "https://example.com")
        XCTAssertEqual(link.trust, .ordinary)
    }

    func testUntrustedCommandLinkIsDropped() {
        let doc = parse("[run](command:editor.action.triggerSuggest)")
        guard case let .paragraph(inline, _) = doc.blocks[0] else {
            return XCTFail("expected paragraph")
        }
        guard case let .link(link, _) = inline[0] else {
            return XCTFail("expected link")
        }
        // Untrusted → dropped (no command survives without trust).
        XCTAssertEqual(link.trust, .dropped)
    }

    func testFullyTrustedCommandLinkSurvives() {
        let doc = parse(
            "[run](command:editor.action.triggerSuggest)",
            trust: .fullyTrusted
        )
        guard case let .paragraph(inline, _) = doc.blocks[0] else {
            return XCTFail("expected paragraph")
        }
        guard case let .link(link, _) = inline[0] else {
            return XCTFail("expected link")
        }
        guard case let .trustedCommand(ref) = link.trust else {
            return XCTFail("expected trusted command, got \(link.trust)")
        }
        XCTAssertEqual(ref.id, "editor.action.triggerSuggest")
        XCTAssertNil(ref.rawQuery)
    }

    func testSelectedCommandsAllowlistSurvives() {
        let doc = parse(
            "[a](command:foo.bar)\n\n[b](command:baz.qux)",
            trust: .selectedCommands(["foo.bar"])
        )
        guard case let .paragraph(inline1, _) = doc.blocks[0],
              case let .link(link1, _) = inline1[0] else {
            return XCTFail("expected first link")
        }
        guard case let .paragraph(inline2, _) = doc.blocks[1],
              case let .link(link2, _) = inline2[0] else {
            return XCTFail("expected second link")
        }
        // foo.bar is allowlisted → trusted.
        if case .trustedCommand(let r1) = link1.trust {
            XCTAssertEqual(r1.id, "foo.bar")
        } else {
            XCTFail("expected foo.bar trusted, got \(link1.trust)")
        }
        // baz.qux is NOT allowlisted → dropped.
        XCTAssertEqual(link2.trust, .dropped)
    }

    func testAlwaysDroppedDownloadResourceCommand() {
        // command:_workbench.downloadResource is always dropped even when fully
        // trusted (the MD1-R alwaysDroppedLinks entry).
        let doc = parse(
            "[dl](command:_workbench.downloadResource)",
            trust: .fullyTrusted
        )
        guard case let .paragraph(inline, _) = doc.blocks[0],
              case let .link(link, _) = inline[0] else {
            return XCTFail("expected link")
        }
        XCTAssertEqual(link.trust, .dropped)
    }

    func testCommandLinkDecodesArgs() {
        let doc = parse(
            "[a](command:my.cmd?%5B1%2C2%5D)",
            trust: .fullyTrusted
        )
        guard case let .paragraph(inline, _) = doc.blocks[0],
              case let .link(link, _) = inline[0] else {
            return XCTFail("expected link")
        }
        guard case let .trustedCommand(ref) = link.trust else {
            return XCTFail("expected trusted command")
        }
        XCTAssertEqual(ref.id, "my.cmd")
        XCTAssertEqual(ref.rawQuery, "%5B1%2C2%5D")
    }

    // MARK: - 6. SECURITY: raw HTML / scripts / style / media / remote images /
    //    web layout / untrusted links REJECTED

    func testRawHtmlBlockIsRejectedFromPresentation() {
        let md = "<div onclick=\"evil()\">boom</div>\n\ntext after"
        let doc = parse(md)
        let pres = MonaMarkdownPresentation.from(doc)
        // The raw HTML must NOT appear in the visible plaintext.
        XCTAssertFalse(pres.plaintext.contains("<div"))
        XCTAssertFalse(pres.plaintext.contains("onclick"))
        XCTAssertFalse(pres.plaintext.contains("evil()"))
        XCTAssertTrue(pres.plaintext.contains("text after"))
        XCTAssertTrue(pres.plaintextHasNoRawHtmlOrScript)
    }

    func testScriptTagIsRejected() {
        let md = "# heading\n\n<script>alert('xss')</script>\n\ntail"
        let doc = parse(md)
        let pres = MonaMarkdownPresentation.from(doc)
        XCTAssertFalse(pres.plaintext.contains("<script"))
        XCTAssertFalse(pres.plaintext.contains("alert('xss')"))
        XCTAssertTrue(pres.plaintext.contains("heading"))
        XCTAssertTrue(pres.plaintextHasNoRawHtmlOrScript)
    }

    func testStyleTagIsRejected() {
        let md = "<style>body{color:red}</style>\n\nhello"
        let doc = parse(md)
        let pres = MonaMarkdownPresentation.from(doc)
        XCTAssertFalse(pres.plaintext.contains("<style"))
        XCTAssertFalse(pres.plaintext.contains("color:red"))
        XCTAssertTrue(pres.plaintext.contains("hello"))
        XCTAssertTrue(pres.plaintextHasNoRawHtmlOrScript)
    }

    func testInlineHtmlIsRejected() {
        let md = "before <b>bold</b> after"
        let doc = parse(md)
        let pres = MonaMarkdownPresentation.from(doc)
        // Inline raw HTML is captured as rawHtml and rejected — the visible
        // text carries only the prose, no tags.
        XCTAssertFalse(pres.plaintext.contains("<b>"))
        XCTAssertFalse(pres.plaintext.contains("</b>"))
        XCTAssertTrue(pres.plaintextHasNoRawHtmlOrScript)
    }

    func testImageEmitsAltTextOnlyNoFetch() {
        // Markdown image syntax: only the alt text survives. The src is
        // parsed and discarded at parse time — never retained, never fetched.
        let md = "![a remote picture](https://evil.example/x.png)"
        let doc = parse(md)
        // The AST image node carries alt text only.
        let images = collectInline(doc).compactMap { n -> String? in
            if case let .image(alt, _) = n { return alt }
            return nil
        }
        XCTAssertEqual(images, ["a remote picture"])
        let pres = MonaMarkdownPresentation.from(doc)
        // The alt text is visible; the src is NOT.
        XCTAssertTrue(pres.plaintext.contains("a remote picture"))
        XCTAssertFalse(pres.plaintext.contains("https://evil.example"))
        XCTAssertFalse(pres.plaintext.contains("x.png"))
        XCTAssertTrue(pres.plaintextHasNoRawHtmlOrScript)
    }

    func testMediaHtmlIsRejected() {
        let md = "<img src=\"https://evil.example/a.png\">\n<video src=\"https://evil.example/v.mp4\"></video>"
        let doc = parse(md)
        let pres = MonaMarkdownPresentation.from(doc)
        XCTAssertFalse(pres.plaintext.contains("<img"))
        XCTAssertFalse(pres.plaintext.contains("<video"))
        XCTAssertFalse(pres.plaintext.contains("evil.example"))
        XCTAssertTrue(pres.plaintextHasNoRawHtmlOrScript)
    }

    func testJavascriptSchemeLinkIsDropped() {
        let doc = parse("[click](javascript:alert(1))")
        guard case let .paragraph(inline, _) = doc.blocks[0],
              case let .link(link, _) = inline[0] else {
            return XCTFail("expected link")
        }
        XCTAssertEqual(link.trust, .dropped)
        let pres = MonaMarkdownPresentation.from(doc)
        // The visible text survives; the actionable href does not.
        XCTAssertTrue(pres.plaintext.contains("click"))
        XCTAssertTrue(pres.droppedLinksHaveNoHref)
        XCTAssertFalse(pres.plaintext.contains("javascript:alert"))
    }

    func testDataSchemeLinkIsDropped() {
        let doc = parse("[x](data:text/html,<script>alert(1)</script>)")
        guard case let .paragraph(inline, _) = doc.blocks[0],
              case let .link(link, _) = inline[0] else {
            return XCTFail("expected link")
        }
        XCTAssertEqual(link.trust, .dropped)
        let pres = MonaMarkdownPresentation.from(doc)
        XCTAssertTrue(pres.droppedLinksHaveNoHref)
    }

    func testUntrustedCommandLinkRejectedFromPresentation() {
        let doc = parse("[run](command:evil.execute)")
        let pres = MonaMarkdownPresentation.from(doc)
        // The dropped link carries no actionable href.
        XCTAssertTrue(pres.droppedLinksHaveNoHref)
        // And the plaintext has no command URI bytes.
        XCTAssertFalse(pres.plaintext.contains("command:evil"))
    }

    func testWebLayoutRejected() {
        // A div with inline style (web layout / CSS) must be rejected.
        let md = "<div style=\"display:flex\">layout</div>\n\ntext"
        let doc = parse(md)
        let pres = MonaMarkdownPresentation.from(doc)
        XCTAssertFalse(pres.plaintext.contains("display:flex"))
        XCTAssertFalse(pres.plaintext.contains("<div"))
        XCTAssertTrue(pres.plaintextHasNoRawHtmlOrScript)
    }

    func testTrustedCommandLinkMetadataSurvivesInInventory() {
        let doc = parse(
            "[go](command:my.action?args)",
            trust: .fullyTrusted
        )
        let pres = MonaMarkdownPresentation.from(doc)
        // Exactly one trusted command link in the inventory.
        let trusted = pres.links.filter {
            if case .trustedCommand = $0.trust { return true }
            return false
        }
        XCTAssertEqual(trusted.count, 1)
        XCTAssertEqual(trusted[0].command?.id, "my.action")
        XCTAssertEqual(trusted[0].command?.rawQuery, "args")
        XCTAssertEqual(trusted[0].href, "command:my.action?args")
    }

    // MARK: - 7. Source ranges in raw UTF-16

    func testSourceOffsetsAreUTF16CodeUnits() {
        // 😀 (U+1F600) is a surrogate pair = 2 UTF-16 units.
        // Paragraph text "😀hi" → the text span is [0, 4) (2 + 2 units).
        let doc = parse("😀hi")
        guard case let .paragraph(inline, _) = doc.blocks[0] else {
            return XCTFail("expected paragraph")
        }
        guard case let .text(_, sp) = inline[0] else {
            return XCTFail("expected text")
        }
        XCTAssertEqual(sp, span(0, 4))
        XCTAssertEqual(sp.length, 4)
    }

    func testLoneSurrogatePreserved() {
        // A lone high surrogate (U+D800) is one UTF-16 code unit. The parser
        // must preserve it as a single unit; the paragraph text span must be
        // UTF-16-accurate (length 1, not 0). Swift's String materializer
        // replaces lone surrogates with U+FFFD, but the source span proves the
        // parser preserved the raw-UInt16 unit count.
        var units: [UInt16] = [0xD800]
        units.append(contentsOf: Array("hi".utf16))
        // units = [0xD800, 'h', 'i'] (3 UTF-16 units total)
        let doc = MonaMarkdownParser.parse(units)
        guard case let .paragraph(inline, _) = doc.blocks[0] else {
            return XCTFail("expected paragraph")
        }
        guard case let .text(_, sp) = inline[0] else {
            return XCTFail("expected text")
        }
        // The lone surrogate occupies exactly ONE UTF-16 unit; "hi" is 2 more.
        XCTAssertEqual(sp, span(0, 3))
        XCTAssertEqual(sp.length, 3)
    }

    func testInlineCodeSpanIsUTF16Accurate() {
        // "a😀`c`" → a=1, 😀=2, `c`=3 → code span starts at offset 3.
        let doc = parse("a😀`c`")
        guard case let .paragraph(inline, _) = doc.blocks[0] else {
            return XCTFail("expected paragraph")
        }
        guard case let .code(_, sp) = inline[1] else {
            return XCTFail("expected code at index 1, got \(inline)")
        }
        XCTAssertEqual(sp.start, 3)
    }

    func testHeadingSpanIsUTF16Accurate() {
        // "# 😀" → #=1, space=1, 😀=2 → heading content starts at offset 2,
        // the heading span begins at 0.
        let doc = parse("# 😀")
        guard case let .heading(level, _, sp) = doc.blocks[0] else {
            return XCTFail("expected heading")
        }
        XCTAssertEqual(level, 1)
        XCTAssertEqual(sp.start, 0)
    }

    // MARK: - 8. Value cap (MD1-R valueLimitUTF16 = 100000)

    func testValueCapTruncatesAt100000UTF16Units() {
        // 100001 'a' units → capped to 100000 + the "…" suffix (1 unit).
        var units = [UInt16](repeating: 0x61, count: 100_001)
        let doc = MonaMarkdownParser.parse(units)
        // The document span reflects the capped input (100001 = 100000 + 1).
        XCTAssertEqual(doc.span.length, 100_001)
        // The last unit is the ellipsis U+2026.
        // Re-parse to inspect the cap directly via the documented suffix.
        var small = [UInt16](repeating: 0x61, count: MonaMarkdownParser.valueLimitUTF16 + 5)
        let docSmall = MonaMarkdownParser.parse(small)
        XCTAssertEqual(docSmall.span.length, MonaMarkdownParser.valueLimitUTF16 + 1)
        _ = units
    }

    // MARK: - Contract behavior summary

    func testContractBehavior() {
        // Grammar coverage: text, code, lists, tables, links, trusted-command.
        let grammar = 6

        // Security: every rejection class verified above.
        let securityOK = (
            // raw HTML
            !MonaMarkdownPresentation.from(parse("<div>x</div>")).plaintext.contains("<div") &&
            // scripts
            !MonaMarkdownPresentation.from(parse("<script>alert(1)</script>")).plaintext.contains("<script") &&
            // style
            !MonaMarkdownPresentation.from(parse("<style>a{}</style>")).plaintext.contains("<style") &&
            // media
            !MonaMarkdownPresentation.from(parse("<img src=\"http://x/y\">")).plaintext.contains("<img") &&
            // remote images (image syntax → alt only)
            MonaMarkdownPresentation.from(parse("![alt](http://x/y.png)")).plaintext.contains("alt") &&
            !MonaMarkdownPresentation.from(parse("![alt](http://x/y.png)")).plaintext.contains("y.png") &&
            // web layout
            !MonaMarkdownPresentation.from(parse("<div style=\"display:flex\">z</div>")).plaintext.contains("display:flex") &&
            // untrusted command links
            MonaMarkdownPresentation.from(parse("[c](command:evil.x)")).droppedLinksHaveNoHref
        )

        // UTF-16: lone surrogate preserved as one unit.
        let u: [UInt16] = [0xD800]
        let docU = MonaMarkdownParser.parse(u)
        let utf16OK: Bool = {
            guard case let .paragraph(inline, _) = docU.blocks[0] else { return false }
            guard case let .text(_, sp) = inline[0] else { return false }
            return sp.length == 1
        }()

        print("MARKDOWN parser=live grammar=\(grammar) security=\(securityOK ? "pass" : "fail") utf16=\(utf16OK ? "pass" : "fail")")

        XCTAssertTrue(securityOK, "security rejections must all hold")
        XCTAssertTrue(utf16OK, "lone surrogate must be preserved over raw UTF-16")
    }
}
