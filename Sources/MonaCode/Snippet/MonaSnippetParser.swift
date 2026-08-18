// MonaSnippetParser.swift
//
// P06-T006 — Port the complete snippet parser and grammar.
//
// The recursive-descent snippet parser over raw `[UInt16]` input. This is the
// Swift counterpart of Monaco's `Scanner` + `SnippetParser`
// (monaco-editor 0.56.0, `snippetParser.js`).
//
// Raw-UInt16 invariant: input is `[UInt16]`, never `String`. A lone surrogate
// is preserved as one code unit (never repaired). Source spans on every marker
// count UTF-16 units, so a supplementary code point occupies two units and a
// lone surrogate occupies one — matching `MonaPieceTree`, `MonaLiteralSearch`,
// and `MonaRegExpParser`.
//
// The grammar (from the snippet contract `grammar` block):
//
//   simple    : '$1' | '$VAR'
//   complex   : '${1}' | '${1:children}' | '${VAR}' | '${VAR:children}'
//   choices   : '${1|one,two,three|}'  (comma, pipe, backslash escaped)
//   transforms: '${1/regex/format/flags}' | '${VAR/regex/format/flags}'
//   format    : '$1' | '${1}' | '${1:/shorthand}' | '${1:+if}' |
//               '${1:-else}' | '${1:?if:else}' | '${1:else}'
//   escapes   : '\$', '\}', '\\'
//
// Parse priority (from the contract `parsePriority`): escaped text, simple
// tabstop/variable, complex placeholder, complex variable, literal fallback.
// Malformed input restores the scanner to the source `$`/`${` and the outer
// parser consumes the text as literal UTF-16 — the `malformedInput` rule.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A recursive-descent snippet parser over raw `[UInt16]`.
public enum MonaSnippetParser {

    /// Parses `units` (raw UTF-16 code units) into a depth-first-ordered list
    /// of top-level snippet markers.
    ///
    /// - Parameter units: the raw UTF-16 code units of the snippet text. Lone
    ///   surrogates are preserved verbatim.
    /// - Returns: the parsed top-level markers, in source (depth-first) order.
    public static func parse(_ units: [UInt16]) -> [MonaSnippetMarker] {
        var scanner = _MonaSnippetScanner(units: units)
        var markers: [MonaSnippetMarker] = []
        while !scanner.isAtEnd {
            if let m = parseTopLevel(&scanner) {
                markers.append(m)
            }
        }
        return markers
    }

    /// Parses a Swift string into markers (convenience: converts via `.utf16`).
    public static func parse(_ text: String) -> [MonaSnippetMarker] {
        return parse(Array(text.utf16))
    }

    // MARK: - Top-level dispatch

    private static func parseTopLevel(_ scanner: inout _MonaSnippetScanner) -> MonaSnippetMarker? {
        // Priority: escape → $ → literal text.
        if scanner.peekIsBackslash() {
            return parseEscape(&scanner)
        }
        if scanner.peekIsDollar() {
            if let m = parseDollar(&scanner) {
                return m
            }
            // Malformed $: parseDollar restored the scanner to the `$`.
            // Consume the single `$` as literal text (the malformed-input
            // fallback rule) and let the next iteration handle the rest.
            return consumeOneLiteral(&scanner)
        }
        return parseText(&scanner)
    }

    private static func consumeOneLiteral(_ scanner: inout _MonaSnippetScanner) -> MonaSnippetMarker {
        let start = scanner.position
        let c = scanner.peek()
        _ = scanner.advance()
        return .text(unitsToText([c]), MonaSnippetSpan(start: start, end: scanner.position))
    }

    // MARK: - Text + escape

    private static func parseText(_ scanner: inout _MonaSnippetScanner, terminator: UInt16? = nil) -> MonaSnippetMarker {
        let start = scanner.position
        var units: [UInt16] = []
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c == 0x5C { // backslash
                if isKnownEscape(scanner) { break }
            }
            if c == 0x24 { // dollar
                break
            }
            if let term = terminator, c == term {
                break
            }
            units.append(c)
            _ = scanner.advance()
        }
        let value = unitsToText(units)
        return .text(value, MonaSnippetSpan(start: start, end: scanner.position))
    }

    private static func parseEscape(_ scanner: inout _MonaSnippetScanner) -> MonaSnippetMarker? {
        let start = scanner.position
        // Consume the backslash.
        _ = scanner.advance()
        guard !scanner.isAtEnd else {
            // Lone trailing backslash → literal backslash.
            return .escape("\\", MonaSnippetSpan(start: start, end: scanner.position))
        }
        let c = scanner.peek()
        _ = scanner.advance()
        switch c {
        case 0x24: // $
            return .escape("$", MonaSnippetSpan(start: start, end: scanner.position))
        case 0x7D: // }
            return .escape("}", MonaSnippetSpan(start: start, end: scanner.position))
        case 0x5C: // backslash
            return .escape("\\", MonaSnippetSpan(start: start, end: scanner.position))
        default:
            // Unknown escape: Monaco keeps both the backslash and the char.
            // Represent as a text run so rendering round-trips verbatim.
            return .text("\\" + String(UnicodeScalar(UInt32(c))!), MonaSnippetSpan(start: start, end: scanner.position))
        }
    }

    private static func isKnownEscape(_ scanner: _MonaSnippetScanner) -> Bool {
        guard let next = scanner.peek(at: 1) else { return false }
        let c = next
        return c == 0x24 || c == 0x7D || c == 0x5C // $ } backslash
    }

    // MARK: - $ dispatch (simple / complex)

    private static func parseDollar(_ scanner: inout _MonaSnippetScanner) -> MonaSnippetMarker? {
        let dollarStart = scanner.position
        _ = scanner.advance() // consume '$'
        if scanner.isAtEnd {
            scanner.restore(to: dollarStart)
            return nil
        }
        // Simple form: $1 or $NAME
        if scanner.peek() != 0x7B { // not '{'
            if scanner.peekIsDigit() {
                return parseSimpleTabstop(&scanner, start: dollarStart)
            }
            if scanner.peekIsVariableStart() {
                return parseSimpleVariable(&scanner, start: dollarStart)
            }
            scanner.restore(to: dollarStart)
            return nil
        }
        // Complex form: ${...}
        if let m = parseComplex(&scanner, dollarStart: dollarStart) {
            return m
        }
        // Malformed complex: restore to the `$` and signal failure so the
        // caller consumes the `$` as literal text.
        scanner.restore(to: dollarStart)
        return nil
    }

    private static func parseSimpleTabstop(
        _ scanner: inout _MonaSnippetScanner, start: Int
    ) -> MonaSnippetMarker {
        let _ = parseInteger(&scanner)  // consume digits
        let idx = scanner.lastInteger
        return .tabstop(index: idx, span: MonaSnippetSpan(start: start, end: scanner.position))
    }

    private static func parseSimpleVariable(
        _ scanner: inout _MonaSnippetScanner, start: Int
    ) -> MonaSnippetMarker {
        let name = parseVariableName(&scanner)
        return .variable(
            name: name, children: [],
            span: MonaSnippetSpan(start: start, end: scanner.position),
            transform: nil
        )
    }

    // MARK: - Complex ${...}

    private static func parseComplex(
        _ scanner: inout _MonaSnippetScanner, dollarStart: Int
    ) -> MonaSnippetMarker? {
        // Record restore point: position before '${'.
        let restorePos = dollarStart
        _ = scanner.advance() // consume '{'
        guard !scanner.isAtEnd else { return nil }

        // Branch: int (placeholder/choice/transform) or variable name.
        if scanner.peekIsDigit() {
            return parseIntComplex(&scanner, dollarStart: dollarStart, restorePos: restorePos)
        }
        if scanner.peekIsVariableStart() {
            return parseVarComplex(&scanner, dollarStart: dollarStart, restorePos: restorePos)
        }
        return nil  // malformed; caller restores
    }

    // MARK: - Integer complex (${n...})

    private static func parseIntComplex(
        _ scanner: inout _MonaSnippetScanner, dollarStart: Int, restorePos: Int
    ) -> MonaSnippetMarker? {
        let _ = parseInteger(&scanner)
        let idx = scanner.lastInteger
        if scanner.isAtEnd { return nil }
        let c = scanner.peek()
        switch c {
        case 0x7D: // }  → ${n}
            _ = scanner.advance()
            return .tabstop(index: idx, span: MonaSnippetSpan(start: dollarStart, end: scanner.position))
        case 0x3A: // :  → ${n:children}
            return parsePlaceholderBody(&scanner, idx: idx, dollarStart: dollarStart, restorePos: restorePos)
        case 0x7C: // |  → ${n|choices|}
            return parseChoiceBody(&scanner, idx: idx, dollarStart: dollarStart, restorePos: restorePos)
        case 0x2F: // /  → ${n/regex/format/flags}
            return parseTransformBody(&scanner, idx: idx, dollarStart: dollarStart, restorePos: restorePos)
        default:
            return nil
        }
    }

    private static func parsePlaceholderBody(
        _ scanner: inout _MonaSnippetScanner, idx: Int, dollarStart: Int, restorePos: Int
    ) -> MonaSnippetMarker? {
        _ = scanner.advance() // consume ':'
        let bodyStart = scanner.position
        let children = parseChildren(&scanner, terminator: 0x7D) // until '}'
        guard !scanner.isAtEnd, scanner.peek() == 0x7D else {
            scanner.restore(to: restorePos)
            return nil
        }
        _ = scanner.advance() // consume '}'
        return .placeholder(
            index: idx,
            children: children,
            span: MonaSnippetSpan(start: dollarStart, end: scanner.position),
            transform: nil
        )
    }

    // MARK: - Choice body ${n|a,b,c|}

    private static func parseChoiceBody(
        _ scanner: inout _MonaSnippetScanner, idx: Int, dollarStart: Int, restorePos: Int
    ) -> MonaSnippetMarker? {
        _ = scanner.advance() // consume '|'
        var options: [String] = []
        var current: [UInt16] = []
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c == 0x5C { // backslash — escape next char in choices
                _ = scanner.advance()
                if !scanner.isAtEnd {
                    current.append(scanner.peek())
                    _ = scanner.advance()
                }
                continue
            }
            if c == 0x2C { // comma — option separator
                options.append(unitsToText(current))
                current.removeAll(keepingCapacity: true)
                _ = scanner.advance()
                continue
            }
            if c == 0x7C { // | — end of choices
                _ = scanner.advance()
                options.append(unitsToText(current))
                // Expect closing '}'.
                guard !scanner.isAtEnd, scanner.peek() == 0x7D else {
                    scanner.restore(to: restorePos)
                    return nil
                }
                _ = scanner.advance()
                return .choice(
                    index: idx, options: options,
                    span: MonaSnippetSpan(start: dollarStart, end: scanner.position)
                )
            }
            current.append(c)
            _ = scanner.advance()
        }
        return nil  // ran off end
    }

    // MARK: - Transform body ${n/regex/format/flags}

    private static func parseTransformBody(
        _ scanner: inout _MonaSnippetScanner, idx: Int, dollarStart: Int, restorePos: Int
    ) -> MonaSnippetMarker? {
        return parseTransformBodyCommon(&scanner, targetIndex: idx, targetName: nil, dollarStart: dollarStart, restorePos: restorePos)
    }

    private static func parseVarTransformBody(
        _ scanner: inout _MonaSnippetScanner, name: String, dollarStart: Int, restorePos: Int
    ) -> MonaSnippetMarker? {
        return parseTransformBodyCommon(&scanner, targetIndex: nil, targetName: name, dollarStart: dollarStart, restorePos: restorePos)
    }

    private static func parseTransformBodyCommon(
        _ scanner: inout _MonaSnippetScanner, targetIndex: Int?, targetName: String?,
        dollarStart: Int, restorePos: Int
    ) -> MonaSnippetMarker? {
        _ = scanner.advance() // consume '/'
        let regex = parseTransformRegex(&scanner)
        guard !scanner.isAtEnd, scanner.peek() == 0x2F else {
            scanner.restore(to: restorePos)
            return nil
        }
        _ = scanner.advance() // consume the middle '/'
        let format = parseTransformFormat(&scanner)
        guard !scanner.isAtEnd, scanner.peek() == 0x2F else {
            scanner.restore(to: restorePos)
            return nil
        }
        _ = scanner.advance() // consume the trailing '/'
        let flags = parseTransformFlags(&scanner)
        guard !scanner.isAtEnd, scanner.peek() == 0x7D else {
            scanner.restore(to: restorePos)
            return nil
        }
        _ = scanner.advance() // consume '}'
        let transform = MonaSnippetTransform(regex: regex, format: format, flags: flags)
        if let idx = targetIndex {
            return .placeholder(
                index: idx, children: [],
                span: MonaSnippetSpan(start: dollarStart, end: scanner.position),
                transform: transform
            )
        } else {
            return .variable(
                name: targetName ?? "", children: [],
                span: MonaSnippetSpan(start: dollarStart, end: scanner.position),
                transform: transform
            )
        }
    }

    private static func parseTransformRegex(_ scanner: inout _MonaSnippetScanner) -> String {
        // The regex part: characters until the next unescaped '/'.
        // An escaped slash ('\ /') becomes a literal '/' in the pattern.
        var units: [UInt16] = []
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c == 0x5C { // backslash
                _ = scanner.advance()
                if scanner.isAtEnd { break }
                let next = scanner.peek()
                if next == 0x2F { // escaped slash → literal '/'
                    units.append(0x2F)
                    _ = scanner.advance()
                    continue
                }
                // Keep the backslash and the next char (regex escape sequence).
                units.append(0x5C)
                units.append(next)
                _ = scanner.advance()
                continue
            }
            if c == 0x2F { break } // end of regex
            units.append(c)
            _ = scanner.advance()
        }
        return unitsToText(units)
    }

    private static func parseTransformFormat(_ scanner: inout _MonaSnippetScanner) -> [MonaSnippetFormatString] {
        // The format part: characters until the next unescaped '/'.
        // Within the format, $1 / ${...} are capture references.
        var elements: [MonaSnippetFormatString] = []
        var literal: [UInt16] = []
        func flushLiteral() {
            if !literal.isEmpty {
                elements.append(.literal(unitsToText(literal)))
                literal.removeAll(keepingCapacity: true)
            }
        }
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c == 0x5C { // backslash
                _ = scanner.advance()
                if scanner.isAtEnd { break }
                let next = scanner.peek()
                if next == 0x2F { // escaped slash → literal '/'
                    literal.append(0x2F)
                    _ = scanner.advance()
                    continue
                }
                if next == 0x5C { // escaped backslash → literal '\'
                    literal.append(0x5C)
                    _ = scanner.advance()
                    continue
                }
                literal.append(0x5C)
                literal.append(next)
                _ = scanner.advance()
                continue
            }
            if c == 0x2F { break } // end of format
            if c == 0x24 { // '$' — format reference
                flushLiteral()
                if let el = parseFormatReference(&scanner) {
                    elements.append(el)
                } else {
                    // bare '$' with no valid reference → literal
                    literal.append(0x24)
                    _ = scanner.advance()
                }
                continue
            }
            literal.append(c)
            _ = scanner.advance()
        }
        flushLiteral()
        return elements
    }

    private static func parseFormatReference(_ scanner: inout _MonaSnippetScanner) -> MonaSnippetFormatString? {
        let refStart = scanner.position
        _ = scanner.advance() // consume '$'
        if scanner.isAtEnd { return nil }
        // $n form
        if scanner.peekIsDigit() {
            let _ = parseInteger(&scanner)
            let n = scanner.lastInteger
            return .capture(n)
        }
        // ${...} form
        if scanner.peek() != 0x7B { return nil }
        _ = scanner.advance() // consume '{'
        guard !scanner.isAtEnd, scanner.peekIsDigit() else { return nil }
        let _ = parseInteger(&scanner)
        let n = scanner.lastInteger
        guard !scanner.isAtEnd else { return nil }
        let next = scanner.peek()
        switch next {
        case 0x7D: // ${n}
            _ = scanner.advance()
            return .capture(n)
        case 0x3A: // ${n:...}
            return parseFormatShorthandOrConditional(&scanner, n: n)
        default:
            return nil
        }
    }

    private static func parseFormatShorthandOrConditional(
        _ scanner: inout _MonaSnippetScanner, n: Int
    ) -> MonaSnippetFormatString {
        _ = scanner.advance() // consume ':'
        guard !scanner.isAtEnd else { return .capture(n) }
        let c = scanner.peek()
        switch c {
        case 0x2F: // ${n:/shorthand}
            _ = scanner.advance()
            let name = parseFormatName(&scanner, terminator: 0x7D)
            guard !scanner.isAtEnd, scanner.peek() == 0x7D else {
                return .capture(n)
            }
            _ = scanner.advance()
            if let sh = MonaSnippetShorthand(rawValue: name) {
                return .shorthand(n, sh)
            }
            return .capture(n)
        case 0x2B: // ${n:+if}
            _ = scanner.advance()
            let body = parseFormatBodyUntilClose(&scanner)
            return .ifForm(n, body)
        case 0x2D: // ${n:-else}
            _ = scanner.advance()
            let body = parseFormatBodyUntilClose(&scanner)
            return .elseForm(n, body)
        case 0x3F: // ${n:?if:else}
            _ = scanner.advance()
            let ifPart = parseFormatBodyUntil(&scanner, terminator: 0x3A)
            var elsePart = ""
            if !scanner.isAtEnd, scanner.peek() == 0x3A {
                _ = scanner.advance()
                elsePart = parseFormatBodyUntilClose(&scanner)
            }
            return .ifElseForm(n, ifPart, elsePart)
        default: // ${n:default}
            let body = parseFormatBodyUntilClose(&scanner)
            return .defaultForm(n, body)
        }
    }

    private static func parseFormatBodyUntilClose(_ scanner: inout _MonaSnippetScanner) -> String {
        return parseFormatBodyUntil(&scanner, terminator: 0x7D)
    }

    private static func parseFormatBodyUntil(
        _ scanner: inout _MonaSnippetScanner, terminator: UInt16
    ) -> String {
        var units: [UInt16] = []
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c == 0x5C { // backslash escape
                _ = scanner.advance()
                if scanner.isAtEnd { break }
                let next = scanner.peek()
                if next == 0x7D || next == terminator {
                    units.append(next)
                    _ = scanner.advance()
                    continue
                }
                units.append(0x5C)
                units.append(next)
                _ = scanner.advance()
                continue
            }
            if c == terminator || c == 0x7D { break }
            units.append(c)
            _ = scanner.advance()
        }
        // Consume the terminator if it's the final close.
        if terminator == 0x7D, !scanner.isAtEnd, scanner.peek() == 0x7D {
            _ = scanner.advance()
        }
        return unitsToText(units)
    }

    private static func parseFormatName(_ scanner: inout _MonaSnippetScanner, terminator: UInt16) -> String {
        var units: [UInt16] = []
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c == terminator { break }
            units.append(c)
            _ = scanner.advance()
        }
        return unitsToText(units)
    }

    private static func parseTransformFlags(_ scanner: inout _MonaSnippetScanner) -> String {
        var units: [UInt16] = []
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c == 0x7D { break } // closing brace
            units.append(c)
            _ = scanner.advance()
        }
        return unitsToText(units)
    }

    // MARK: - Variable complex ${NAME...}

    private static func parseVarComplex(
        _ scanner: inout _MonaSnippetScanner, dollarStart: Int, restorePos: Int
    ) -> MonaSnippetMarker? {
        let name = parseVariableName(&scanner)
        if scanner.isAtEnd { return nil }
        let c = scanner.peek()
        switch c {
        case 0x7D: // ${NAME}
            _ = scanner.advance()
            return .variable(
                name: name, children: [],
                span: MonaSnippetSpan(start: dollarStart, end: scanner.position),
                transform: nil
            )
        case 0x3A: // ${NAME:children}
            return parseVarDefaultBody(&scanner, name: name, dollarStart: dollarStart, restorePos: restorePos)
        case 0x2F: // ${NAME/regex/format/flags}
            return parseVarTransformBody(&scanner, name: name, dollarStart: dollarStart, restorePos: restorePos)
        default:
            return nil
        }
    }

    private static func parseVarDefaultBody(
        _ scanner: inout _MonaSnippetScanner, name: String, dollarStart: Int, restorePos: Int
    ) -> MonaSnippetMarker? {
        _ = scanner.advance() // consume ':'
        let children = parseChildren(&scanner, terminator: 0x7D)
        guard !scanner.isAtEnd, scanner.peek() == 0x7D else {
            scanner.restore(to: restorePos)
            return nil
        }
        _ = scanner.advance()
        return .variable(
            name: name, children: children,
            span: MonaSnippetSpan(start: dollarStart, end: scanner.position),
            transform: nil
        )
    }

    // MARK: - Children (nested grammar until terminator)

    private static func parseChildren(
        _ scanner: inout _MonaSnippetScanner, terminator: UInt16
    ) -> [MonaSnippetMarker] {
        var markers: [MonaSnippetMarker] = []
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c == terminator { break }
            if c == 0x5C {
                if let m = parseEscape(&scanner) { markers.append(m) }
                continue
            }
            if c == 0x24 {
                if let m = parseDollar(&scanner) {
                    markers.append(m)
                    continue
                }
                // malformed → fall through to literal text
            }
            markers.append(parseText(&scanner, terminator: terminator))
        }
        return markers
    }

    // MARK: - Low-level helpers

    private static func parseInteger(_ scanner: inout _MonaSnippetScanner) {
        var value = 0
        var any = false
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if c >= 0x30 && c <= 0x39 {
                value = value * 10 + Int(c - 0x30)
                any = true
                _ = scanner.advance()
            } else {
                break
            }
        }
        if any { scanner.lastInteger = value }
    }

    private static func parseVariableName(_ scanner: inout _MonaSnippetScanner) -> String {
        var units: [UInt16] = []
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if isVariableNameChar(c) {
                units.append(c)
                _ = scanner.advance()
            } else {
                break
            }
        }
        return unitsToText(units)
    }

    private static func isVariableNameChar(_ c: UInt16) -> Bool {
        // [A-Za-z0-9_]
        if c >= 0x41 && c <= 0x5A { return true }
        if c >= 0x61 && c <= 0x7A { return true }
        if c >= 0x30 && c <= 0x39 { return true }
        if c == 0x5F { return true } // _
        return false
    }

    static func unitsToText(_ units: [UInt16]) -> String {
        // Convert raw UTF-16 code units to a Swift String. Swift's String
        // normalizes lone surrogates to U+FFFD (matching the project's
        // String-materialization convention — see MonaRegExpParser). The
        // raw-UInt16 invariant is preserved at the *parser* level: source
        // spans count UTF-16 units, so a lone surrogate occupies one unit
        // in every span (verified by the offset tests). The String content
        // is materialized only for rendering, never re-parsed.
        return String(decoding: units, as: UTF16.self)
    }
}

// MARK: - Scanner

/// The snippet scanner: a position cursor over raw `[UInt16]`. Carries a
/// `lastInteger` scratch field (the last parsed integer) and a restore
/// primitive for the malformed-input fallback path.
struct _MonaSnippetScanner {
    private(set) var units: [UInt16]
    var position: Int = 0
    var lastInteger: Int = 0

    init(units: [UInt16]) {
        self.units = units
    }

    var isAtEnd: Bool { return position >= units.count }

    @inline(__always)
    func peek() -> UInt16 {
        // precondition: !isAtEnd — callers guard.
        return units[position]
    }

    @inline(__always)
    func peek(at offset: Int) -> UInt16? {
        let p = position + offset
        guard p >= 0 && p < units.count else { return nil }
        return units[p]
    }

    @inline(__always)
    func peekIsDollar() -> Bool {
        guard !isAtEnd else { return false }
        return units[position] == 0x24
    }

    @inline(__always)
    func peekIsBackslash() -> Bool {
        guard !isAtEnd else { return false }
        return units[position] == 0x5C
    }

    @inline(__always)
    func peekIsDigit() -> Bool {
        guard !isAtEnd else { return false }
        let c = units[position]
        return c >= 0x30 && c <= 0x39
    }

    @inline(__always)
    func peekIsVariableStart() -> Bool {
        guard !isAtEnd else { return false }
        let c = units[position]
        if c >= 0x41 && c <= 0x5A { return true }
        if c >= 0x61 && c <= 0x7A { return true }
        if c == 0x5F { return true }
        return false
    }

    @discardableResult
    mutating func advance() -> UInt16? {
        guard !isAtEnd else { return nil }
        let c = units[position]
        position += 1
        return c
    }

    mutating func restore(to pos: Int) {
        position = pos
    }
}

// MARK: - TextmateSnippet (render + placeholder order)

/// A parsed snippet tree: the top-level markers plus the operations Monaco's
/// `TextmateSnippet` exposes — render to text, enumerate placeholders in
/// depth-first order, and place tab stops (with optional final-tabstop
/// enforcement).
public struct MonaSnippetTextmateSnippet: Equatable, Hashable, Sendable {

    /// The top-level markers, in source (depth-first) order.
    public let markers: [MonaSnippetMarker]

    /// Creates a snippet tree.
    public init(markers: [MonaSnippetMarker]) {
        self.markers = markers
    }

    // MARK: - Render

    /// Renders the snippet to plain text given a variable-binding map.
    ///
    /// Placeholders render their default children; choices render their first
    /// option; variables render the bound value (or their default children when
    /// unbound, or empty when unbound with no default). A bare tab stop (`$n`)
    /// renders empty (the session supplies cursor placement; text rendering has
    /// no value to mirror at parse time unless a prior placeholder of the same
    /// index supplied one — mirrors are resolved here).
    public func toText(variables: [String: String] = [:]) -> String {
        var ctx = _MonaSnippetRenderContext(variables: variables)
        var out = ""
        for marker in markers {
            out += ctx.render(marker)
        }
        return out
    }

    // MARK: - Placeholder order

    /// The placeholder/tabstop indices in depth-first walk order. A bare `$n`
    /// contributes `n`; a `${n:…}` / `${n|…|}` / `${n/…/…/…}` contributes `n`.
    /// `0` is the final tab stop.
    public func placeholderOrder() -> [Int] {
        var order: [Int] = []
        for marker in markers {
            collectOrder(marker, into: &order)
        }
        return order
    }

    private func collectOrder(_ marker: MonaSnippetMarker, into out: inout [Int]) {
        switch marker {
        case .text, .escape:
            break
        case .tabstop(let idx, _):
            out.append(idx)
        case .placeholder(let idx, let children, _, _):
            out.append(idx)
            for c in children { collectOrder(c, into: &out) }
        case .choice(let idx, _, _):
            out.append(idx)
        case .variable(_, let children, _, _):
            for c in children { collectOrder(c, into: &out) }
        }
    }

    // MARK: - Placement

    /// Places placeholders (tab stops / choices / placeholders) in depth-first
    /// order, optionally appending a final `0` tab stop when none exists and
    /// `enforceFinalTabstop` (or `insertFinalTabstop` with at least one
    /// existing placeholder) is requested.
    public func placeholders(
        enforceFinalTabstop: Bool = false,
        insertFinalTabstop: Bool = false
    ) -> [MonaSnippetPlacedPlaceholder] {
        var placed: [MonaSnippetPlacedPlaceholder] = []
        var ctx = _MonaSnippetRenderContext(variables: [:])
        for marker in markers {
            place(marker, into: &placed, ctx: &ctx)
        }
        let hasZero = placed.contains { $0.index == 0 }
        if !hasZero {
            let needsFinal = enforceFinalTabstop
                || (insertFinalTabstop && !placed.isEmpty)
            if needsFinal {
                let endSpan = MonaSnippetSpan(
                    start: markers.last?.span.end ?? 0,
                    end: markers.last?.span.end ?? 0
                )
                placed.append(MonaSnippetPlacedPlaceholder(
                    index: 0, value: "", sourceSpan: endSpan
                ))
            }
        }
        return placed
    }

    private func place(
        _ marker: MonaSnippetMarker,
        into out: inout [MonaSnippetPlacedPlaceholder],
        ctx: inout _MonaSnippetRenderContext
    ) {
        switch marker {
        case .text, .escape:
            break
        case .tabstop(let idx, let s):
            out.append(MonaSnippetPlacedPlaceholder(index: idx, value: "", sourceSpan: s))
        case .placeholder(let idx, let children, let s, _):
            let value = children.map { ctx.render($0) }.joined()
            ctx.placeholderValues[idx] = value
            out.append(MonaSnippetPlacedPlaceholder(index: idx, value: value, sourceSpan: s))
            for c in children { place(c, into: &out, ctx: &ctx) }
        case .choice(let idx, let options, let s):
            let value = options.first ?? ""
            ctx.placeholderValues[idx] = value
            out.append(MonaSnippetPlacedPlaceholder(index: idx, value: value, sourceSpan: s))
        case .variable(let name, let children, let s, _):
            let value = ctx.variables[name] ?? children.map { ctx.render($0) }.joined()
            if !name.isEmpty {
                ctx.placeholderValues[-1] = value  // not a tabstop
            }
            out.append(MonaSnippetPlacedPlaceholder(index: -1, value: value, sourceSpan: s))
            for c in children { place(c, into: &out, ctx: &ctx) }
        }
    }
}

// MARK: - Render context

struct _MonaSnippetRenderContext {
    var variables: [String: String]
    /// Resolved placeholder values for mirroring: index → value.
    var placeholderValues: [Int: String] = [:]

    mutating func render(_ marker: MonaSnippetMarker) -> String {
        switch marker {
        case .text(let v, _):
            return v
        case .escape(let c, _):
            return String(c)
        case .tabstop(let idx, _):
            // Mirror a prior placeholder of the same index, else empty.
            return placeholderValues[idx] ?? ""
        case .placeholder(let idx, let children, _, _):
            let value = children.map { render($0) }.joined()
            placeholderValues[idx] = value
            return value
        case .choice(let idx, let options, _):
            let value = options.first ?? ""
            placeholderValues[idx] = value
            return value
        case .variable(let name, let children, _, let transform):
            if let bound = variables[name] {
                if let t = transform {
                    return MonaSnippetTransformExecutor.apply(transform: t, to: bound)
                }
                return bound
            }
            // Unbound: render default children (empty when none).
            return children.map { render($0) }.joined()
        }
    }
}
