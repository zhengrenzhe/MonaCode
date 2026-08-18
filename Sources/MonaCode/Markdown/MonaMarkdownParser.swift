// MonaMarkdownParser.swift
//
// P06-T008 — Port Markdown semantics into a native presentation tree.
//
// The recursive-descent Markdown parser over raw `[UInt16]`. This is the Swift
// port of the pinned Marked 14.0.0 synchronous GFM default grammar subset
// (monaco-editor 0.56.0, `esm/vs/base/common/marked/marked.js`, SHA-256
// `75746ae6ff08f4e9b94090ed018e5ac1bf7dbb7e8fcdb4ec48784bd6569d9fda`).
//
// Pinned defaults (the MD1-R contract baseline; the parser honors these
// exactly — no extensions, hooks, custom tokenizer, walkTokens, async, breaks,
// or pedantic mode):
//
//   async = false
//   breaks = false
//   gfm = true
//   pedantic = false
//   silent = false
//   extensions = null
//   hooks = null
//   tokenizer = null
//   walkTokens = null
//   renderer = null
//
// The parser produces an immutable `MonaMarkdownDocument` — a typed semantic
// tree. It never emits an HTML string, never touches a DOM or WebView, and
// never fetches a byte. The native sanitizer is integrated at tree-build time:
//
//   - Raw HTML (block and inline) is captured as `rawHtml` nodes and rejected
//     before presentation (supportHtml is cut; default-false behavior).
//   - Markdown image syntax contributes its parsed alt text only; the src is
//     parsed and discarded — never retained, never fetched.
//   - Command links survive only when trusted (`fullyTrusted` or on the
//     `selectedCommands` allowlist); untrusted command links and the
//     always-dropped `command:_workbench.downloadResource` are dropped.
//   - `data:`, `javascript:`, and unknown schemes are dropped.
//
// Raw-UInt16 invariant: input is `[UInt16]`, never `String`. A lone surrogate
// is preserved as one code unit (never repaired). Source spans on every node
// count UTF-16 units, so a supplementary code point occupies two units and a
// lone surrogate occupies one — matching `MonaPieceTree`, `MonaLiteralSearch`,
// `MonaRegExpParser`, and `MonaSnippetParser`.
//
// Value cap: input longer than 100000 UTF-16 code units is truncated to the
// first 100000 units plus the truncation suffix "…" (U+2026), matching
// Monaco's baseMarkdownRenderer valueLimit.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The Markdown parser. A recursive-descent port of the pinned Marked 14.0.0
/// synchronous GFM default grammar subset over raw `[UInt16]`.
public enum MonaMarkdownParser {

    /// The MD1-R value cap (UTF-16 code units). Input longer than this is
    /// truncated to the first 100000 units plus the "…" suffix.
    public static let valueLimitUTF16 = 100_000

    /// The truncation suffix appended when the value exceeds the cap.
    public static let truncationSuffix: UInt16 = 0x2026 // "…"

    /// Parses `units` (raw UTF-16 code units) into a `MonaMarkdownDocument`.
    /// `trust` governs whether command links survive the sanitizer.
    /// `supportThemeIcons` enables `$(icon-id)` theme-icon parsing.
    ///
    /// - Parameter units: the raw UTF-16 code units of the Markdown value.
    ///   Lone surrogates are preserved verbatim.
    /// - Parameter trust: the admitted trust for command links.
    /// - Parameter supportThemeIcons: `true` to parse `$(icon-id)` tokens.
    /// - Returns: the parsed document (empty if `units` is empty).
    public static func parse(
        _ units: [UInt16],
        trust: MonaMarkdownTrust = .untrusted,
        supportThemeIcons: Bool = false
    ) -> MonaMarkdownDocument {
        let capped = capUnits(units)
        var lexer = _Lexer(units: capped, trust: trust, supportThemeIcons: supportThemeIcons)
        var blocks: [MonaMarkdownBlock] = []
        while !lexer.isAtEnd {
            // Skip blank lines between blocks.
            lexer.skipBlankLines()
            if lexer.isAtEnd { break }
            if let block = parseBlock(&lexer) {
                blocks.append(block)
            } else {
                // Unrecognized line — consume it as paragraph text fallback.
                if let para = parseParagraph(&lexer) {
                    blocks.append(para)
                } else {
                    _ = lexer.consumeLine() // make progress
                }
            }
        }
        return MonaMarkdownDocument(blocks: blocks, span: MonaMarkdownSpan(start: 0, end: capped.count))
    }

    /// Convenience: parses a Swift string (via `.utf16`).
    public static func parse(
        _ text: String,
        trust: MonaMarkdownTrust = .untrusted,
        supportThemeIcons: Bool = false
    ) -> MonaMarkdownDocument {
        return parse(Array(text.utf16), trust: trust, supportThemeIcons: supportThemeIcons)
    }

    /// Convenience: parses a `MonaMarkdownString` value.
    public static func parse(_ value: MonaMarkdownString) -> MonaMarkdownDocument {
        return parse(value.units, trust: value.trust, supportThemeIcons: value.supportThemeIcons)
    }

    // MARK: - Value cap

    /// Truncates `units` to the value cap plus the "…" suffix.
    private static func capUnits(_ units: [UInt16]) -> [UInt16] {
        if units.count <= valueLimitUTF16 {
            return units
        }
        var result = Array(units.prefix(valueLimitUTF16))
        result.append(truncationSuffix)
        return result
    }

    // MARK: - Block dispatch

    /// Tries the block-level rules in Marked's order against the current line.
    /// Returns the parsed block and advances the lexer, or `nil`.
    private static func parseBlock(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        if let block = parseHeading(&lexer) { return block }
        if let block = parseFencedCode(&lexer) { return block }
        if let block = parseThematicBreak(&lexer) { return block }
        if let block = parseBlockquote(&lexer) { return block }
        if let block = parseList(&lexer) { return block }
        if let block = parseTable(&lexer) { return block }
        if let block = parseHtmlBlock(&lexer) { return block }
        return parseParagraph(&lexer)
    }

    // MARK: - Heading (ATX)

    private static func parseHeading(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        let save = lexer.position
        lexer.skipSpaces(max: 3)
        var hashes = 0
        while lexer.peek() == 0x23 && hashes < 6 { // '#'
            _ = lexer.advance()
            hashes += 1
        }
        guard hashes >= 1, hashes <= 6 else {
            lexer.position = save
            return nil
        }
        // A '#' run is a heading only if followed by a space or EOL.
        let next = lexer.peek()
        let atEOL = next == nil || next == 0x0A
        let atSpace = next == 0x20 || next == 0x09
        guard atEOL || atSpace else {
            lexer.position = save
            return nil
        }
        // Consume leading spaces after the hashes.
        while lexer.peek() == 0x20 { _ = lexer.advance() }
        // Content extends to end of line (strip trailing `#` close sequence).
        let lineStart = lexer.position
        lexer.consumeToEOL()
        var content = Array(lexer.units[lineStart..<lexer.position])
        // Strip trailing whitespace.
        while let last = content.last, (last == 0x20 || last == 0x09) {
            content.removeLast()
        }
        // Strip trailing close-sequence `#` (not part of the text).
        while content.last == 0x23 {
            content.removeLast()
            while content.last == 0x20 || content.last == 0x09 {
                content.removeLast()
            }
        }
        // Strip the trailing newline by NOT including it in the inline span.
        let contentEnd = lineStart + content.count
        // Consume the newline.
        if lexer.peek() == 0x0A { _ = lexer.advance() }
        let inline = parseInline(content, baseOffset: lineStart, lexer: &lexer)
        let span = MonaMarkdownSpan(start: save, end: contentEnd)
        return .heading(level: hashes, inline: inline, span: span)
    }

    // MARK: - Fenced code

    private static func parseFencedCode(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        let save = lexer.position
        lexer.skipSpaces(max: 3)
        let fenceChar = lexer.peek()
        let isFence = fenceChar == 0x60 || fenceChar == 0x7E // '`' or '~'
        guard isFence else {
            lexer.position = save
            return nil
        }
        let c = fenceChar!
        var run = 0
        while lexer.peek() == c { _ = lexer.advance(); run += 1 }
        guard run >= 3 else {
            lexer.position = save
            return nil
        }
        // Info string: rest of the line (first token is the language).
        let infoStart = lexer.position
        lexer.consumeToEOL()
        let infoUnits = Array(lexer.units[infoStart..<lexer.position])
        let infoString = unitsToString(infoUnits).trimmingCharacters(in: .whitespaces)
        // First whitespace-delimited token is the language id.
        let lang: String?
        if let firstSpace = infoString.firstIndex(where: { $0 == " " || $0 == "\t" }) {
            lang = String(infoString[..<firstSpace])
        } else if infoString.isEmpty {
            lang = nil
        } else {
            lang = infoString
        }
        _ = lexer.consumeNewline()
        // Collect lines until a closing fence of at least `run` of `c`.
        var codeUnits: [UInt16] = []
        var closed = false
        while !lexer.isAtEnd {
            let lineSave = lexer.position
            lexer.skipSpaces(max: 3)
            var closeRun = 0
            while lexer.peek() == c { _ = lexer.advance(); closeRun += 1 }
            let afterFence = lexer.peek()
            let closeMatch = closeRun >= run && (afterFence == nil || afterFence == 0x0A || afterFence == 0x20 || afterFence == 0x09)
            if closeMatch && closeRun >= 3 {
                _ = lexer.consumeNewline()
                closed = true
                break
            }
            // Not a close fence — this line is code content.
            lexer.position = lineSave
            lexer.consumeToEOL()
            for u in lexer.units[lineSave..<lexer.position] {
                codeUnits.append(u)
            }
            codeUnits.append(0x0A)
            _ = lexer.consumeNewline()
        }
        _ = closed // unterminated fence → closed at EOF (Marked behavior)
        // Drop a single trailing newline if present.
        if codeUnits.last == 0x0A { codeUnits.removeLast() }
        let code = unitsToString(codeUnits)
        let span = MonaMarkdownSpan(start: save, end: lexer.position)
        return .codeBlock(info: lang, code: code, span: span)
    }

    // MARK: - Thematic break

    private static func parseThematicBreak(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        let save = lexer.position
        lexer.skipSpaces(max: 3)
        let c = lexer.peek()
        guard c == 0x2D || c == 0x2A || c == 0x5F else { // '-', '*', '_'
            lexer.position = save
            return nil
        }
        let mark = c!
        var count = 0
        var onlySpacesAndMark = true
        var p = lexer.position
        while p < lexer.units.count {
            let u = lexer.units[p]
            if u == mark { count += 1; p += 1 }
            else if u == 0x20 || u == 0x09 { p += 1 }
            else { onlySpacesAndMark = false; break }
        }
        // Also need to stop at EOL: redo with line scope.
        guard onlySpacesAndMark, count >= 3 else {
            lexer.position = save
            return nil
        }
        // Verify the rest of the line is only spaces and the mark (Marked
        // requires the line be entirely the mark + spaces).
        lexer.position = save
        lexer.skipSpaces(max: 3)
        var n = 0
        var ok = true
        while !lexer.isAtEnd {
            let u = lexer.peek()!
            if u == 0x0A { break }
            if u == mark { n += 1; _ = lexer.advance() }
            else if u == 0x20 || u == 0x09 { _ = lexer.advance() }
            else { ok = false; break }
        }
        guard ok, n >= 3 else {
            lexer.position = save
            return nil
        }
        _ = lexer.consumeNewline()
        return .thematicBreak(MonaMarkdownSpan(start: save, end: lexer.position))
    }

    // MARK: - Blockquote

    private static func parseBlockquote(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        let save = lexer.position
        lexer.skipSpaces(max: 3)
        guard lexer.peek() == 0x3E else { // '>'
            lexer.position = save
            return nil
        }
        // Collect consecutive blockquote lines, stripping the '>' prefix (and
        // one optional following space). Lazy continuation lines (non-blank
        // lines not starting with '>') are included verbatim, matching
        // Marked's blockquote token.
        var stripped: [UInt16] = []
        while !lexer.isAtEnd {
            let lineSave = lexer.position
            if lexer.isBlankLine(at: lineSave) {
                break
            }
            // Skip up to 3 leading spaces.
            var p = lineSave
            while p < lexer.units.count, (lexer.units[p] == 0x20 || lexer.units[p] == 0x09), (p - lineSave) < 3 {
                p += 1
            }
            if p < lexer.units.count && lexer.units[p] == 0x3E { // '>'
                // Strip '>' + one optional space.
                p += 1
                if p < lexer.units.count && (lexer.units[p] == 0x20) { p += 1 }
                let eol = nextEOL(in: lexer.units, from: p)
                for u in lexer.units[p..<eol] { stripped.append(u) }
                stripped.append(0x0A)
                lexer.position = eol
                _ = lexer.consumeNewline()
            } else {
                // Lazy continuation — include verbatim.
                let eol = nextEOL(in: lexer.units, from: lineSave)
                for u in lexer.units[lineSave..<eol] { stripped.append(u) }
                stripped.append(0x0A)
                lexer.position = eol
                _ = lexer.consumeNewline()
            }
        }
        // Recurse: parse the stripped content as blocks.
        var inner = _Lexer(units: stripped, trust: lexer.trust, supportThemeIcons: lexer.supportThemeIcons)
        var children: [MonaMarkdownBlock] = []
        while !inner.isAtEnd {
            inner.skipBlankLines()
            if inner.isAtEnd { break }
            if let block = parseBlock(&inner) {
                children.append(block)
            } else {
                _ = inner.consumeLine()
            }
        }
        return .blockquote(children, MonaMarkdownSpan(start: save, end: lexer.position))
    }

    /// Returns the index of the next `\n` (or `units.count`) at/after `from`.
    private static func nextEOL(in units: [UInt16], from: Int) -> Int {
        var p = from
        while p < units.count && units[p] != 0x0A { p += 1 }
        return p
    }

    // MARK: - List

    private static func parseList(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        let save = lexer.position
        lexer.skipSpaces(max: 3)
        // Detect list-ness on copies so the original cursor is not advanced
        // before the item loop.
        var detectOrdered = lexer
        var detectUnordered = lexer
        let orderedStart = parseOrderedMarker(&detectOrdered)
        let unordered = parseUnorderedMarker(&detectUnordered)
        guard orderedStart != nil || unordered else {
            lexer.position = save
            return nil
        }
        let isOrdered = orderedStart != nil
        let startOrdinal = orderedStart ?? 1
        // Reset to the line start; the item loop parses each marker itself.
        lexer.position = save
        var items: [MonaMarkdownListItem] = []

        while !lexer.isAtEnd {
            let lineSave = lexer.position
            // Skip up to 3 leading spaces.
            var p = lineSave
            while p < lexer.units.count, (lexer.units[p] == 0x20 || lexer.units[p] == 0x09), (p - lineSave) < 3 {
                p += 1
            }
            // Try a marker on copies at this position.
            var probeOrd = lexer
            probeOrd.position = p
            var probeUnord = lexer
            probeUnord.position = p
            let ord = parseOrderedMarker(&probeOrd)
            let unord = parseUnorderedMarker(&probeUnord)
            let isItem = (isOrdered && ord != nil) || (!isOrdered && unord)
            guard isItem else {
                // Not a list item line. A blank line may mean the list
                // continues (if the next non-blank line is an item); anything
                // else ends the list.
                if lexer.isBlankLine(at: lineSave) {
                    let peek = lexer.peekAfterBlanks(at: lineSave)
                    if peek >= 0 {
                        var probeA = lexer
                        probeA.position = peek
                        probeA.skipSpaces(max: 3)
                        var probeB = probeA
                        let ord2 = parseOrderedMarker(&probeA)
                        let unord2 = parseUnorderedMarker(&probeB)
                        let still = (isOrdered && ord2 != nil) || (!isOrdered && unord2)
                        if still {
                            // Consume the blank line and keep collecting.
                            lexer.position = lineSave
                            _ = lexer.consumeLine()
                            continue
                        }
                    }
                }
                break
            }
            // Consume the marker (advancing the real cursor).
            lexer.position = p
            if isOrdered {
                _ = parseOrderedMarker(&lexer)
            } else {
                _ = parseUnorderedMarker(&lexer)
            }
            let itemMarkerWidth = lexer.markerWidth
            // Optional task checkbox: [ ] or [x] or [X].
            var taskChecked: Bool? = nil
            if lexer.peek() == 0x5B { // '['
                let n1 = lexer.peek(at: 1)
                let n2 = lexer.peek(at: 2)
                if n2 == 0x5D && (n1 == 0x20 || n1 == 0x78 || n1 == 0x58) { // ' ', 'x', 'X'
                    taskChecked = (n1 != 0x20)
                    _ = lexer.advance() // '['
                    _ = lexer.advance() // char
                    _ = lexer.advance() // ']'
                    if lexer.peek() == 0x20 { _ = lexer.advance() } // one space
                }
            }
            // Collect this item's content: the remainder of the marker line,
            // plus continuation lines indented by >= itemMarkerWidth.
            var itemUnits: [UInt16] = []
            let contentStart = lexer.position
            lexer.consumeToEOL()
            for u in lexer.units[contentStart..<lexer.position] {
                itemUnits.append(u)
            }
            itemUnits.append(0x0A)
            _ = lexer.consumeNewline()
            while !lexer.isAtEnd {
                let contSave = lexer.position
                if lexer.isBlankLine(at: contSave) {
                    // Peek next non-blank line.
                    let peek = lexer.peekAfterBlanks(at: contSave)
                    if peek >= 0 {
                        let ind = lexer.countLeadingSpaces(at: peek)
                        var probeA = lexer
                        probeA.position = peek
                        probeA.skipSpaces(max: 3)
                        var probeB = probeA
                        let ord2 = parseOrderedMarker(&probeA)
                        let unord2 = parseUnorderedMarker(&probeB)
                        if ind >= itemMarkerWidth {
                            // Lazy continuation of this item.
                            lexer.position = contSave
                            _ = lexer.consumeLine()
                            continue
                        } else if (isOrdered && ord2 != nil) || (!isOrdered && unord2) {
                            // Next item begins.
                            lexer.position = contSave
                            break
                        } else {
                            // List ends.
                            lexer.position = contSave
                            break
                        }
                    } else {
                        lexer.position = contSave
                        break
                    }
                }
                let indent = lexer.countLeadingSpaces(at: contSave)
                if indent >= itemMarkerWidth {
                    // Indented → part of this item. Strip the indent.
                    lexer.position = contSave + itemMarkerWidth
                    let cs = lexer.position
                    lexer.consumeToEOL()
                    for u in lexer.units[cs..<lexer.position] { itemUnits.append(u) }
                    itemUnits.append(0x0A)
                    _ = lexer.consumeNewline()
                } else {
                    // Non-blank, non-indented, non-item line → list ends.
                    lexer.position = contSave
                    break
                }
            }
            // Recurse on the item content.
            var inner = _Lexer(units: itemUnits, trust: lexer.trust, supportThemeIcons: lexer.supportThemeIcons)
            var itemBlocks: [MonaMarkdownBlock] = []
            while !inner.isAtEnd {
                inner.skipBlankLines()
                if inner.isAtEnd { break }
                if let block = parseBlock(&inner) {
                    itemBlocks.append(block)
                } else {
                    _ = inner.consumeLine()
                }
            }
            items.append(MonaMarkdownListItem(taskChecked: taskChecked, blocks: itemBlocks, span: MonaMarkdownSpan(start: lineSave, end: lexer.position)))
        }
        guard !items.isEmpty else {
            lexer.position = save
            return nil
        }
        return .list(
            MonaMarkdownList(ordered: isOrdered, start: startOrdinal, items: items),
            MonaMarkdownSpan(start: save, end: lexer.position)
        )
    }

    private static func parseOrderedMarker(_ lexer: inout _Lexer) -> Int? {
        let save = lexer.position
        var digits = 0
        var ordinal = 0
        while let d = lexer.peek(), d >= 0x30 && d <= 0x39 { // 0-9
            ordinal = ordinal * 10 + (Int(d) - 0x30)
            _ = lexer.advance()
            digits += 1
            if digits > 9 { lexer.position = save; return nil } // too long
        }
        guard digits >= 1, lexer.peek() == 0x2E || lexer.peek() == 0x29 else { // '.' or ')'
            lexer.position = save
            return nil
        }
        _ = lexer.advance() // consume '.' or ')'
        // Require a following space (Marked list rule).
        guard lexer.peek() == 0x20 || lexer.peek() == 0x09 else {
            lexer.position = save
            return nil
        }
        // Compute marker width: digits + 1 (punct) + spaces consumed.
        var spaces = 0
        while lexer.peek() == 0x20 || lexer.peek() == 0x09 {
            _ = lexer.advance()
            spaces += 1
            if spaces >= 5 { break }
        }
        if spaces == 0 {
            // Need at least one space; but Marked allows tab too. Already
            // handled. If we consumed none, restore.
            lexer.position = save
            return nil
        }
        lexer.markerWidth = digits + 1 + spaces
        return ordinal
    }

    private static func parseUnorderedMarker(_ lexer: inout _Lexer) -> Bool {
        let save = lexer.position
        let c = lexer.peek()
        guard c == 0x2D || c == 0x2A || c == 0x2B else { // '-', '*', '+'
            return false
        }
        _ = lexer.advance()
        guard lexer.peek() == 0x20 || lexer.peek() == 0x09 else {
            lexer.position = save
            return false
        }
        var spaces = 0
        while lexer.peek() == 0x20 || lexer.peek() == 0x09 {
            _ = lexer.advance()
            spaces += 1
            if spaces >= 5 { break }
        }
        // A "-" alone could be a thematic break; but parseThematicBreak runs
        // first, so reaching here with "-" + space means a list item.
        lexer.markerWidth = 1 + spaces
        return true
    }

    // MARK: - Table (GFM)

    private static func parseTable(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        let save = lexer.position
        // First line: the header row. Must contain a pipe or be pipe-delimited.
        let firstLine = lexer.peekLine(at: lexer.position)
        guard firstLine.contains(0x7C) else { // '|'
            return nil
        }
        // Second line must be the separator: only pipes, hyphens, colons, spaces.
        let afterFirst = lexer.position + firstLine.count + 1 // +1 for newline
        guard afterFirst < lexer.units.count else { return nil }
        let sepLine = lexer.peekLine(at: afterFirst)
        guard isTableSeparator(sepLine) else {
            return nil
        }
        // Parse header cells.
        let headerCells = splitTableRow(firstLine)
        let alignments = parseRowAlignments(sepLine, columnCount: headerCells.count)
        var rows: [[MonaMarkdownTableCell]] = []
        // Consume header + separator lines.
        _ = lexer.consumeLine()
        _ = lexer.consumeLine()
        // Consume body rows until blank or non-table line.
        while !lexer.isAtEnd {
            let lineStart = lexer.position
            if lexer.isBlankLine(at: lineStart) { break }
            let line = lexer.peekLine(at: lineStart)
            if line.isEmpty { break }
            // A table row must contain a pipe (or be a single cell).
            _ = lexer.consumeLine()
            let cells = splitTableRow(line)
            if cells.isEmpty { break }
            var rowCells: [MonaMarkdownTableCell] = []
            for i in 0..<headerCells.count {
                let cellUnits = i < cells.count ? cells[i] : []
                var innerL = _Lexer(units: cellUnits, trust: lexer.trust, supportThemeIcons: lexer.supportThemeIcons)
                let inline = parseInline(cellUnits, baseOffset: 0, lexer: &innerL)
                rowCells.append(MonaMarkdownTableCell(inline: inline))
            }
            rows.append(rowCells)
        }
        // Build header cell inline.
        var headerRow: [MonaMarkdownTableCell] = []
        var probe = lexer
        probe.position = save
        _ = probe.peekLine(at: save)
        for i in 0..<headerCells.count {
            let cellUnits = splitTableRow(firstLine)[i]
            var innerL = _Lexer(units: cellUnits, trust: lexer.trust, supportThemeIcons: lexer.supportThemeIcons)
            let inline = parseInline(cellUnits, baseOffset: 0, lexer: &innerL)
            headerRow.append(MonaMarkdownTableCell(inline: inline))
        }
        let table = MonaMarkdownTable(header: headerRow, rows: rows, alignments: alignments)
        return .table(table, MonaMarkdownSpan(start: save, end: lexer.position))
    }

    private static func isTableSeparator(_ line: [UInt16]) -> Bool {
        if line.isEmpty { return false }
        var hasDash = false
        for u in line {
            switch u {
            case 0x7C: break            // '|'
            case 0x2D: hasDash = true   // '-'
            case 0x3A: break           // ':'
            case 0x20, 0x09: break     // space/tab
            default: return false
            }
        }
        return hasDash // pipe optional for single-column; dash required
    }

    private static func splitTableRow(_ line: [UInt16]) -> [[UInt16]] {
        // A leading/trailing pipe is optional. Split on unescaped pipes.
        var trimmed = line
        // Trim outer whitespace.
        while let first = trimmed.first, first == 0x20 || first == 0x09 { trimmed.removeFirst() }
        while let last = trimmed.last, last == 0x20 || last == 0x09 { trimmed.removeLast() }
        // Strip a single leading and trailing pipe if present.
        if trimmed.first == 0x7C { trimmed.removeFirst() }
        if trimmed.last == 0x7C { trimmed.removeLast() }
        var cells: [[UInt16]] = []
        var current: [UInt16] = []
        var i = 0
        while i < trimmed.count {
            let u = trimmed[i]
            if u == 0x5C && i + 1 < trimmed.count { // backslash escape
                current.append(trimmed[i + 1])
                i += 2
                continue
            }
            if u == 0x7C { // '|'
                cells.append(current)
                current = []
                i += 1
                continue
            }
            current.append(u)
            i += 1
        }
        cells.append(current)
        return cells
    }

    private static func parseRowAlignments(_ sep: [UInt16], columnCount: Int) -> [MonaMarkdownTableAlignment] {
        let cells = splitTableRow(sep)
        var result: [MonaMarkdownTableAlignment] = []
        for i in 0..<columnCount {
            let cell = i < cells.count ? cells[i] : []
            // A ':' before the first dash = left-align; a ':' after the last
            // dash = right-align; both = center.
            var leftColon = false
            var rightColon = false
            var seenDash = false
            for u in cell {
                if u == 0x2D { // '-'
                    seenDash = true
                } else if u == 0x3A { // ':'
                    if seenDash { rightColon = true } else { leftColon = true }
                }
            }
            if leftColon && rightColon { result.append(.center) }
            else if rightColon { result.append(.right) }
            else if leftColon { result.append(.left) }
            else { result.append(.none) }
        }
        return result
    }

    // MARK: - HTML block

    private static func parseHtmlBlock(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        let save = lexer.position
        lexer.skipSpaces(max: 3)
        guard lexer.peek() == 0x3C else { // '<'
            lexer.position = save
            return nil
        }
        // Peek the tag name; if it starts a known HTML block, consume to the
        // closing condition. For the security model, ANY '<' starting a line
        // (after up to 3 spaces) that looks like a tag is captured as a raw
        // HTML block — the sanitizer rejects it regardless of tag name.
        // Require a letter or '/' after '<' (a tag-looking start).
        let n = lexer.peek(at: 1)
        guard isTagNameStart(n) else {
            lexer.position = save
            return nil
        }
        // Consume to end of line (and subsequent lines until a blank line for
        // multi-line HTML blocks).
        var raw: [UInt16] = []
        while !lexer.isAtEnd {
            let lineStart = lexer.position
            if lexer.isBlankLine(at: lineStart) && !raw.isEmpty { break }
            lexer.consumeToEOL()
            for u in lexer.units[lineStart..<lexer.position] { raw.append(u) }
            raw.append(0x0A)
            _ = lexer.consumeNewline()
            // For a single-line HTML block, stop after one line (Marked's
            // HTML block ends at a blank line; consecutive non-blank lines
            // are part of the block).
        }
        if raw.last == 0x0A { raw.removeLast() }
        let html = unitsToString(raw)
        return .rawHtml(html, MonaMarkdownSpan(start: save, end: lexer.position))
    }

    private static func isTagNameStart(_ u: UInt16?) -> Bool {
        guard let u = u else { return false }
        return (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || u == 0x2F // A-Za-z or '/'
    }

    // MARK: - Paragraph

    private static func parseParagraph(_ lexer: inout _Lexer) -> MonaMarkdownBlock? {
        let save = lexer.position
        var content: [UInt16] = []
        while !lexer.isAtEnd {
            let lineStart = lexer.position
            if lexer.isBlankLine(at: lineStart) { break }
            // Stop if the line starts a new block (heading, fence, hr, quote,
            // list, table, html block).
            var probe = lexer
            probe.position = lineStart
            if startsBlock(&probe) {
                if content.isEmpty {
                    // The very first line is itself a block start — let the
                    // dispatcher handle it; not a paragraph.
                    break
                }
                break
            }
            lexer.consumeToEOL()
            for u in lexer.units[lineStart..<lexer.position] { content.append(u) }
            content.append(0x0A)
            _ = lexer.consumeNewline()
        }
        // Trim a single trailing newline.
        if content.last == 0x0A { content.removeLast() }
        guard !content.isEmpty else {
            if lexer.position == save { return nil }
            return nil
        }
        let inline = parseInline(content, baseOffset: save, lexer: &lexer)
        // End span: end of the consumed content (before trailing newline trim
        // is represented as the position after the last content byte).
        let end = save + content.count
        return .paragraph(inline, MonaMarkdownSpan(start: save, end: end))
    }

    /// Returns true if the line at `lexer.position` begins a non-paragraph
    /// block (heading, fence, hr, quote, list, table, html block).
    private static func startsBlock(_ lexer: inout _Lexer) -> Bool {
        let save = lexer.position
        defer { lexer.position = save }
        lexer.skipSpaces(max: 3)
        // Heading.
        if lexer.peek() == 0x23 { // '#'
            var p = lexer.position
            var n = 0
            while p < lexer.units.count && lexer.units[p] == 0x23 && n < 7 { p += 1; n += 1 }
            if n >= 1 && n <= 6 {
                let after = p < lexer.units.count ? lexer.units[p] : 0x0A
                if after == 0x20 || after == 0x09 || after == 0x0A || p == lexer.units.count {
                    return true
                }
            }
        }
        // Fenced code.
        let c = lexer.peek()
        if c == 0x60 || c == 0x7E { // '`' or '~'
            var p = lexer.position
            var n = 0
            while p < lexer.units.count && lexer.units[p] == c! { p += 1; n += 1 }
            if n >= 3 { return true }
        }
        // Thematic break.
        if c == 0x2D || c == 0x2A || c == 0x5F {
            var p = lexer.position
            var n = 0
            var ok = true
            while p < lexer.units.count && lexer.units[p] != 0x0A {
                let u = lexer.units[p]
                if u == c! { n += 1 }
                else if u == 0x20 || u == 0x09 { /* ok */ }
                else { ok = false; break }
                p += 1
            }
            if ok && n >= 3 { return true }
        }
        // Blockquote.
        if lexer.peek() == 0x3E { return true } // '>'
        // List.
        if c == 0x2D || c == 0x2A || c == 0x2B { // '-', '*', '+'
            // Need a following space (else it's text/hr).
            let n1 = lexer.peek(at: 1)
            if n1 == 0x20 || n1 == 0x09 { return true }
        }
        if let d = c, d >= 0x30 && d <= 0x39 { // digit
            // Ordered marker: digits then '.' or ')' then space.
            var p = lexer.position
            while p < lexer.units.count && lexer.units[p] >= 0x30 && lexer.units[p] <= 0x39 { p += 1 }
            if p < lexer.units.count && (lexer.units[p] == 0x2E || lexer.units[p] == 0x29) {
                let after = p + 1 < lexer.units.count ? lexer.units[p + 1] : 0x0A
                if after == 0x20 || after == 0x09 { return true }
            }
        }
        // Table: a line with a pipe followed by a separator line. Cheap check:
        // we only flag a potential table start; the real parser confirms.
        // (Avoid false positives: require a pipe on this line.)
        let line = lexer.peekLine(at: save)
        if line.contains(0x7C) {
            // Confirm the next line is a separator.
            let after = save + line.count + 1
            if after < lexer.units.count {
                let next = lexer.peekLine(at: after)
                if isTableSeparator(next) { return true }
            }
        }
        // HTML block.
        if lexer.peek() == 0x3C {
            let n = lexer.peek(at: 1)
            if isTagNameStart(n) { return true }
        }
        return false
    }

    // MARK: - Inline parsing

    /// Parses an inline run from `content` (UTF-16 units). `baseOffset` is the
    /// offset of `content[0]` in the original source, so spans are accurate.
    static func parseInline(
        _ content: [UInt16],
        baseOffset: Int,
        lexer: inout _Lexer
    ) -> [MonaMarkdownInline] {
        var nodes: [MonaMarkdownInline] = []
        var i = 0
        var textStart = 0
        var textUnits: [UInt16] = []

        func flushText() {
            if !textUnits.isEmpty {
                let span = MonaMarkdownSpan(start: baseOffset + textStart, end: baseOffset + i)
                nodes.append(.text(unitsToString(textUnits), span))
                textUnits.removeAll(keepingCapacity: true)
            }
            textStart = i
        }

        while i < content.count {
            let u = content[i]

            // Escape.
            if u == 0x5C && i + 1 < content.count { // '\'
                let esc = content[i + 1]
                // Only escape ASCII punctuation (Marked's escapable set).
                if isEscapable(esc) {
                    flushText()
                    let span = MonaMarkdownSpan(start: baseOffset + i, end: baseOffset + i + 2)
                    nodes.append(.text(unitsToString([esc]), span))
                    i += 2
                    textStart = i
                    continue
                }
            }

            // Inline code (`code` or ``code``).
            if u == 0x60 { // '`'
                if let (code, span, consumed) = tryInlineCode(content, from: i, baseOffset: baseOffset) {
                    flushText()
                    nodes.append(.code(code, span))
                    i += consumed
                    textStart = i
                    continue
                }
            }

            // Theme icon $(id) — only if supportThemeIcons.
            if lexer.supportThemeIcons && u == 0x24 && i + 1 < content.count && content[i + 1] == 0x28 { // '$('
                if let (id, span, consumed) = tryThemeIcon(content, from: i, baseOffset: baseOffset) {
                    flushText()
                    nodes.append(.themeIcon(id: id, span: span))
                    i += consumed
                    textStart = i
                    continue
                }
            }

            // Image ![alt](src) — alt text only, src discarded.
            if u == 0x21 && i + 1 < content.count && content[i + 1] == 0x5B { // '!'
                if let (alt, span, consumed) = tryImage(content, from: i, baseOffset: baseOffset) {
                    flushText()
                    nodes.append(.image(alt: alt, span: span))
                    i += consumed
                    textStart = i
                    continue
                }
            }

            // Link [text](href) or [text][ref].
            if u == 0x5B { // '['
                if let (link, span, consumed) = tryLink(content, from: i, baseOffset: baseOffset, lexer: lexer) {
                    flushText()
                    nodes.append(.link(link, span))
                    i += consumed
                    textStart = i
                    continue
                }
            }

            // Strong / emphasis.
            if u == 0x2A || u == 0x5F { // '*' or '_'
                // Strong (** or __) then emphasis.
                if i + 1 < content.count && content[i + 1] == u {
                    if let (children, span, consumed) = tryStrong(content, from: i, baseOffset: baseOffset, lexer: lexer) {
                        flushText()
                        nodes.append(.strong(children, span))
                        i += consumed
                        textStart = i
                        continue
                    }
                }
                if let (children, span, consumed) = tryEmphasis(content, from: i, baseOffset: baseOffset, lexer: lexer) {
                    flushText()
                    nodes.append(.emphasis(children, span))
                    i += consumed
                    textStart = i
                    continue
                }
            }

            // Raw inline HTML: <...>. Captured (rejected by presentation).
            if u == 0x3C { // '<'
                if let (html, span, consumed) = tryInlineHtml(content, from: i, baseOffset: baseOffset) {
                    flushText()
                    nodes.append(.rawHtml(html, span))
                    i += consumed
                    textStart = i
                    continue
                }
            }

            // Hard line break: `  \n` (two trailing spaces + newline).
            if u == 0x0A {
                // Check if the preceding text ended with two spaces.
                if textUnits.count >= 2 && textUnits[textUnits.count - 1] == 0x20 && textUnits[textUnits.count - 2] == 0x20 {
                    // Strip the two trailing spaces from the text.
                    textUnits.removeLast(2)
                    flushText()
                    let span = MonaMarkdownSpan(start: baseOffset + i, end: baseOffset + i + 1)
                    nodes.append(.lineBreak(span))
                    i += 1
                    textStart = i
                    continue
                }
                // Soft newline: keep as text (a single \n in the text run).
                // (breaks=false: a single newline is not a hard break.)
            }

            textUnits.append(u)
            i += 1
        }
        flushText()
        return nodes
    }

    private static func isEscapable(_ u: UInt16) -> Bool {
        // Marked's escapable ASCII punctuation.
        switch u {
        case 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A,
             0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
             0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40,
             0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60,
             0x7B, 0x7C, 0x7D, 0x7E:
            return true
        default:
            return false
        }
    }

    private static func tryInlineCode(
        _ content: [UInt16], from start: Int, baseOffset: Int
    ) -> (code: String, span: MonaMarkdownSpan, consumed: Int)? {
        // Count opening backticks.
        var i = start
        var n = 0
        while i < content.count && content[i] == 0x60 { i += 1; n += 1 }
        guard n >= 1 else { return nil }
        // Find a run of exactly n backticks.
        var closeStart = -1
        var j = i
        while j < content.count {
            if content[j] == 0x60 {
                var k = 0
                while j + k < content.count && content[j + k] == 0x60 { k += 1 }
                if k == n {
                    closeStart = j
                    break
                }
                j += k
            } else {
                j += 1
            }
        }
        guard closeStart >= 0 else { return nil }
        let codeUnits = Array(content[i..<closeStart])
        // Replace newlines in code with spaces (Marked normalizes).
        var normalized: [UInt16] = []
        for u in codeUnits {
            normalized.append(u == 0x0A ? 0x20 : u)
        }
        let code = unitsToString(normalized)
        let span = MonaMarkdownSpan(start: baseOffset + start, end: baseOffset + closeStart + n)
        return (code, span, closeStart + n - start)
    }

    private static func tryThemeIcon(
        _ content: [UInt16], from start: Int, baseOffset: Int
    ) -> (id: String, span: MonaMarkdownSpan, consumed: Int)? {
        // $(id) — until ')'.
        var i = start + 2 // past '$('
        var idUnits: [UInt16] = []
        while i < content.count && content[i] != 0x29 { // ')'
            if content[i] == 0x0A { return nil } // no newline in icon id
            idUnits.append(content[i])
            i += 1
        }
        guard i < content.count, content[i] == 0x29 else { return nil }
        let id = unitsToString(idUnits)
        guard !id.isEmpty else { return nil }
        let end = i + 1
        let span = MonaMarkdownSpan(start: baseOffset + start, end: baseOffset + end)
        return (id, span, end - start)
    }

    private static func tryImage(
        _ content: [UInt16], from start: Int, baseOffset: Int
    ) -> (alt: String, span: MonaMarkdownSpan, consumed: Int)? {
        // ![alt](src "title")
        var i = start + 2 // past '!' '['
        var altUnits: [UInt16] = []
        var depth = 1
        while i < content.count && depth > 0 {
            let u = content[i]
            if u == 0x5C && i + 1 < content.count {
                altUnits.append(content[i + 1])
                i += 2
                continue
            }
            if u == 0x5B { depth += 1 } // '['
            if u == 0x5D { depth -= 1; if depth == 0 { break } } // ']'
            if u == 0x0A { return nil }
            altUnits.append(u)
            i += 1
        }
        guard i < content.count, content[i] == 0x5D else { return nil }
        i += 1 // past ']'
        // Expect '('.
        guard i < content.count, content[i] == 0x28 else { return nil }
        i += 1
        // Skip whitespace.
        while i < content.count && (content[i] == 0x20 || content[i] == 0x09 || content[i] == 0x0A) { i += 1 }
        // The src extends to the first space, tab, or ')'. (Title handling:
        // we discard the src entirely; we just need to find the closing ')'.)
        var sawClose = false
        var inTitle = false
        var titleQuote: UInt16 = 0
        while i < content.count {
            let u = content[i]
            if !inTitle {
                if u == 0x29 { sawClose = true; break } // ')'
                if u == 0x20 || u == 0x09 {
                    // Possibly the start of a title.
                    let next = content[i < content.count - 1 ? i + 1 : i]
                    if next == 0x22 || next == 0x27 { // '"' or '\''
                        inTitle = true
                        titleQuote = next
                        i += 1
                        continue
                    }
                }
            } else {
                if u == 0x5C && i + 1 < content.count { i += 2; continue }
                if u == titleQuote { inTitle = false; titleQuote = 0 }
            }
            i += 1
        }
        guard sawClose else { return nil }
        i += 1 // past ')'
        // Alt text: parse the alt as inline for escaped chars, but we only
        // need the decoded text. Use a flat decode (backslash escapes).
        let alt = unitsToString(decodeEscapes(altUnits))
        let span = MonaMarkdownSpan(start: baseOffset + start, end: baseOffset + i)
        return (alt, span, i - start)
    }

    private static func tryLink(
        _ content: [UInt16], from start: Int, baseOffset: Int, lexer: _Lexer
    ) -> (link: MonaMarkdownLink, span: MonaMarkdownSpan, consumed: Int)? {
        // [text](href "title")
        var i = start + 1 // past '['
        var textUnits: [UInt16] = []
        var depth = 1
        while i < content.count && depth > 0 {
            let u = content[i]
            if u == 0x5C && i + 1 < content.count {
                textUnits.append(content[i + 1])
                i += 2
                continue
            }
            if u == 0x5B { depth += 1 }
            if u == 0x5D { depth -= 1; if depth == 0 { break } }
            if u == 0x0A { return nil }
            textUnits.append(u)
            i += 1
        }
        guard i < content.count, content[i] == 0x5D else { return nil }
        i += 1 // past ']'
        // Expect '('.
        guard i < content.count, content[i] == 0x28 else { return nil }
        i += 1
        // Skip leading whitespace.
        while i < content.count && (content[i] == 0x20 || content[i] == 0x09 || content[i] == 0x0A) { i += 1 }
        // href: <href> or bare href up to whitespace/title/close.
        var hrefUnits: [UInt16] = []
        if i < content.count && content[i] == 0x3C { // '<'
            i += 1
            while i < content.count && content[i] != 0x3E { // '>'
                if content[i] == 0x0A { return nil }
                hrefUnits.append(content[i])
                i += 1
            }
            guard i < content.count, content[i] == 0x3E else { return nil }
            i += 1
        } else {
            while i < content.count {
                let u = content[i]
                if u == 0x20 || u == 0x09 || u == 0x0A || u == 0x29 { break }
                hrefUnits.append(u)
                i += 1
            }
        }
        // Skip whitespace; optional title.
        var title: String? = nil
        while i < content.count && (content[i] == 0x20 || content[i] == 0x09) { i += 1 }
        if i < content.count && (content[i] == 0x22 || content[i] == 0x27) { // '"' or '\''
            let q = content[i]
            i += 1
            var titleUnits: [UInt16] = []
            while i < content.count && content[i] != q {
                if content[i] == 0x5C && i + 1 < content.count {
                    titleUnits.append(content[i + 1])
                    i += 2
                    continue
                }
                if content[i] == 0x0A { return nil }
                titleUnits.append(content[i])
                i += 1
            }
            guard i < content.count, content[i] == q else { return nil }
            i += 1
            title = unitsToString(decodeEscapes(titleUnits))
        }
        // Skip trailing whitespace.
        while i < content.count && (content[i] == 0x20 || content[i] == 0x09) { i += 1 }
        guard i < content.count, content[i] == 0x29 else { return nil } // ')'
        i += 1
        let href = unitsToString(decodeEscapes(hrefUnits))
        let trust = classifyLink(href: href, trust: lexer.trust)
        // Parse the link text as inline (so nested emphasis/code survive).
        var innerLexer = _Lexer(units: textUnits, trust: lexer.trust, supportThemeIcons: lexer.supportThemeIcons)
        let children = parseInline(textUnits, baseOffset: baseOffset + start + 1, lexer: &innerLexer)
        let span = MonaMarkdownSpan(start: baseOffset + start, end: baseOffset + i)
        let link = MonaMarkdownLink(href: href, title: title, children: children, trust: trust)
        return (link, span, i - start)
    }

    private static func tryStrong(
        _ content: [UInt16], from start: Int, baseOffset: Int, lexer: _Lexer
    ) -> ([MonaMarkdownInline], MonaMarkdownSpan, Int)? {
        return tryDelimited(content, from: start, baseOffset: baseOffset, lexer: lexer, run: 2) { kids, span in
            .strong(kids, span)
        }
    }

    private static func tryEmphasis(
        _ content: [UInt16], from start: Int, baseOffset: Int, lexer: _Lexer
    ) -> ([MonaMarkdownInline], MonaMarkdownSpan, Int)? {
        return tryDelimited(content, from: start, baseOffset: baseOffset, lexer: lexer, run: 1) { kids, span in
            .emphasis(kids, span)
        }
    }

    /// Generic delimiter-run matcher for `*`/`_` emphasis/strong. Finds a
    /// matching closing run of the same length and recurses on the content.
    private static func tryDelimited(
        _ content: [UInt16],
        from start: Int,
        baseOffset: Int,
        lexer: _Lexer,
        run: Int,
        wrap: ([MonaMarkdownInline], MonaMarkdownSpan) -> MonaMarkdownInline
    ) -> ([MonaMarkdownInline], MonaMarkdownSpan, Int)? {
        let mark = content[start]
        // Must not be preceded by a space (opening delimiter cannot have
        // whitespace right after) — Marked's left-flanking rule (simplified).
        // We allow it and rely on finding a closing run.
        var i = start + run
        let innerStart = i
        while i < content.count {
            let u = content[i]
            if u == 0x5C && i + 1 < content.count {
                i += 2
                continue
            }
            if u == mark {
                // Count the run.
                var k = 0
                while i + k < content.count && content[i + k] == mark { k += 1 }
                // Closing run: match the opening run length.
                if k >= run {
                    // Closing delimiter found.
                    let innerUnits = Array(content[innerStart..<i])
                    var innerLexer = _Lexer(units: innerUnits, trust: lexer.trust, supportThemeIcons: lexer.supportThemeIcons)
                    let kids = parseInline(innerUnits, baseOffset: baseOffset + innerStart, lexer: &innerLexer)
                    let span = MonaMarkdownSpan(start: baseOffset + start, end: baseOffset + i + run)
                    return (kids, span, i + run - start)
                }
                i += k
            } else if u == 0x5B {
                // A link inside emphasis — skip past its ']' to avoid false
                // close. Simplified: just advance.
                i += 1
            } else if u == 0x60 {
                // Inline code — skip past the code span.
                if let (_, _, consumed) = tryInlineCode(content, from: i, baseOffset: baseOffset) {
                    i += consumed
                    continue
                }
                i += 1
            } else {
                i += 1
            }
        }
        return nil
    }

    private static func tryInlineHtml(
        _ content: [UInt16], from start: Int, baseOffset: Int
    ) -> (html: String, span: MonaMarkdownSpan, consumed: Int)? {
        // A '<' followed by a letter or '/' starts a raw HTML run to the next '>'.
        guard start + 1 < content.count else { return nil }
        let n = content[start + 1]
        guard (n >= 0x41 && n <= 0x5A) || (n >= 0x61 && n <= 0x7A) || n == 0x2F else { return nil }
        var i = start + 1
        while i < content.count {
            if content[i] == 0x3E { // '>'
                let end = i + 1
                let html = unitsToString(Array(content[start..<end]))
                let span = MonaMarkdownSpan(start: baseOffset + start, end: baseOffset + end)
                return (html, span, end - start)
            }
            if content[i] == 0x0A { return nil } // no newline in inline tag
            i += 1
        }
        return nil
    }

    // MARK: - Sanitizer: link classification

    /// The admitted non-command schemes (MD1-R `untrustedLinkSchemes`). Links
    /// with these schemes produce `.ordinary` (inert until user activation).
    public static let admittedSchemes: Set<String> = [
        "http", "https", "mailto", "file",
        "vscode-file", "vscode-remote", "vscode-remote-resource",
        "vscode-notebook-cell", "private",
    ]

    /// The always-dropped schemes (MD1-R `alwaysDroppedLinks`).
    public static let droppedSchemes: Set<String> = [
        "data", "javascript",
    ]

    /// The always-dropped command target (resource download command).
    public static let droppedCommandTarget = "_workbench.downloadResource"

    /// Classifies a link href under the given trust. This is the sanitizer
    /// gate applied at tree-build time — before any control is created.
    public static func classifyLink(href: String, trust: MonaMarkdownTrust) -> MonaMarkdownLinkTrust {
        // Empty or whitespace-only href → ordinary (fragment/relative).
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .ordinary
        }
        let scheme = parseScheme(trimmed).lowercased()
        if scheme == "command" {
            // Decode the command id + raw query.
            let (id, rawQuery) = decodeCommandUri(trimmed)
            // Always-dropped command target.
            if id == droppedCommandTarget {
                return .dropped
            }
            switch trust {
            case .untrusted:
                return .dropped
            case .fullyTrusted:
                return .trustedCommand(MonaMarkdownCommandRef(id: id, rawQuery: rawQuery))
            case .selectedCommands(let allowed):
                if allowed.contains(id) {
                    return .trustedCommand(MonaMarkdownCommandRef(id: id, rawQuery: rawQuery))
                }
                return .dropped
            }
        }
        if droppedSchemes.contains(scheme) {
            return .dropped
        }
        if admittedSchemes.contains(scheme) {
            return .ordinary
        }
        // No scheme: a relative link/fragment — ordinary (resolved against
        // baseUri at activation; never a command).
        if scheme.isEmpty {
            return .ordinary
        }
        // Unknown scheme — conservative drop.
        return .dropped
    }

    /// Parses the scheme of a URI (the part before the first ':'). Returns the
    /// empty string when there is no scheme. A scheme must be
    /// `[a-zA-Z][a-zA-Z0-9+.-]*` followed by ':'.
    public static func parseScheme(_ href: String) -> String {
        guard let colon = href.firstIndex(of: ":") else { return "" }
        let scheme = String(href[..<colon])
        // A valid scheme starts with a letter and contains only the allowed
        // characters; otherwise the ':' is not a scheme separator (e.g. a
        // relative path "a:b").
        guard let first = scheme.first, first.isLetter else { return "" }
        for c in scheme {
            if !(c.isLetter || c.isNumber || c == "+" || c == "." || c == "-") {
                return ""
            }
        }
        return scheme
    }

    /// Decodes a `command:<id>?<query>` URI into (id, rawQuery).
    public static func decodeCommandUri(_ href: String) -> (id: String, rawQuery: String?) {
        // Strip "command:" prefix.
        guard href.lowercased().hasPrefix("command:") else {
            return (href, nil)
        }
        let after = String(href.dropFirst("command:".count))
        // Split at the first '?'.
        if let q = after.firstIndex(of: "?") {
            let idRaw = String(after[..<q])
            let query = String(after[after.index(after: q)...])
            return (percentDecode(idRaw), query.isEmpty ? nil : query)
        }
        return (percentDecode(after), nil)
    }

    /// Percent-decodes a string (never throws; malformed runs pass through
    /// verbatim, matching Monaco's `decodeURIComponentGraceful`).
    public static func percentDecode(_ s: String) -> String {
        let chars = Array(s)
        var out = ""
        var i = 0
        while i < chars.count {
            if chars[i] == "%" && i + 2 < chars.count {
                if let h = hexVal(chars[i + 1]), let l = hexVal(chars[i + 2]) {
                    let byte = UInt8(h * 16 + l)
                    out.append(Character(UnicodeScalar(byte)))
                    i += 3
                    continue
                }
            }
            out.append(chars[i])
            i += 1
        }
        return out
    }

    private static func hexVal(_ c: Character) -> Int? {
        guard let s = c.asciiValue else { return nil }
        switch s {
        case 0x30...0x39: return Int(s - 0x30)
        case 0x41...0x46: return Int(s - 0x41 + 10)
        case 0x61...0x66: return Int(s - 0x61 + 10)
        default: return nil
        }
    }

    // MARK: - UTF-16 ↔ String helpers

    /// Materializes a `[UInt16]` run into a Swift String. Lone surrogates are
    /// replaced with U+FFFD by Swift's decoder, but the source spans (which
    /// count raw UInt16 units) prove the parser preserved the unit count
    /// verbatim — matching `MonaSnippetParser.unitsToText`.
    static func unitsToString(_ units: [UInt16]) -> String {
        return String(decoding: units, as: UTF16.self)
    }

    /// Resolves backslash escapes in a UTF-16 run (for alt/href/title text).
    static func decodeEscapes(_ units: [UInt16]) -> [UInt16] {
        var out: [UInt16] = []
        var i = 0
        while i < units.count {
            if units[i] == 0x5C && i + 1 < units.count {
                out.append(units[i + 1])
                i += 2
                continue
            }
            out.append(units[i])
            i += 1
        }
        return out
    }
}

// MARK: - Lexer

/// The low-level cursor over a `[UInt16]` source. Tracks position, recognizes
/// lines, and carries the parser's trust + theme-icon settings.
struct _Lexer {
    let units: [UInt16]
    var position: Int = 0
    let trust: MonaMarkdownTrust
    let supportThemeIcons: Bool
    /// The indent width of the current list marker (set during list parsing).
    var markerWidth: Int = 0
    /// The position after the marker content start (used by blockquote strip).
    var contentStart: Int = 0

    init(units: [UInt16], trust: MonaMarkdownTrust, supportThemeIcons: Bool) {
        self.units = units
        self.trust = trust
        self.supportThemeIcons = supportThemeIcons
    }

    var isAtEnd: Bool { return position >= units.count }

    @discardableResult
    mutating func advance() -> UInt16? {
        guard position < units.count else { return nil }
        let u = units[position]
        position += 1
        return u
    }

    func peek() -> UInt16? {
        guard position < units.count else { return nil }
        return units[position]
    }

    func peek(at offset: Int) -> UInt16? {
        let idx = position + offset
        guard idx >= 0, idx < units.count else { return nil }
        return units[idx]
    }

    /// Skips up to `max` spaces/tabs (the CommonMark 3-space indent for block
    /// starts).
    mutating func skipSpaces(max: Int) {
        var n = 0
        while n < max, position < units.count, units[position] == 0x20 || units[position] == 0x09 {
            position += 1
            n += 1
        }
    }

    mutating func skipBlankLines() {
        while !isAtEnd {
            if isBlankLine(at: position) {
                _ = consumeLine()
            } else {
                break
            }
        }
    }

    /// True if the line at `offset` is blank (only whitespace).
    func isBlankLine(at offset: Int) -> Bool {
        var p = offset
        while p < units.count && units[p] != 0x0A {
            let u = units[p]
            if u != 0x20 && u != 0x09 { return false }
            p += 1
        }
        return true
    }

    /// Consumes bytes up to (not including) the next `\n` or EOF.
    @discardableResult
    mutating func consumeToEOL() -> Int {
        let start = position
        while position < units.count && units[position] != 0x0A {
            position += 1
        }
        contentStart = start
        return position - start
    }

    /// Consumes a single `\n` if present (the line terminator).
    @discardableResult
    mutating func consumeNewline() -> Bool {
        if position < units.count && units[position] == 0x0A {
            position += 1
            return true
        }
        return false
    }

    /// Consumes the current line (content + newline).
    @discardableResult
    mutating func consumeLine() -> Bool {
        consumeToEOL()
        return consumeNewline()
    }

    /// Returns the bytes of the line at `offset` (excluding the newline).
    func peekLine(at offset: Int) -> [UInt16] {
        var p = offset
        var line: [UInt16] = []
        while p < units.count && units[p] != 0x0A {
            line.append(units[p])
            p += 1
        }
        return line
    }

    /// Counts leading spaces/tabs at `offset`.
    func countLeadingSpaces(at offset: Int) -> Int {
        var p = offset
        var n = 0
        while p < units.count && (units[p] == 0x20 || units[p] == 0x09) {
            n += 1
            p += 1
        }
        return n
    }

    /// Returns the offset of the first non-blank line at/after `offset`, or
    /// `-1` if only blank lines remain.
    func peekAfterBlanks(at offset: Int) -> Int {
        var p = offset
        while p < units.count {
            if isBlankLine(at: p) {
                while p < units.count && units[p] != 0x0A { p += 1 }
                if p < units.count { p += 1 } // past newline
            } else {
                return p
            }
        }
        return -1
    }
}
