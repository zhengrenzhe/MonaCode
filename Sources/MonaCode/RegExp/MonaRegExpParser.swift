// MonaRegExpParser.swift
//
// P02-T004 — Implement the finite ECMAScript RegExp parser and compiler.
//
// `MonaRegExpParser` is a recursive-descent parser that turns a RegExp pattern
// string plus a flag string into a `MonaRegExpNode` AST. It is the Swift
// counterpart of Monaco's RegExp parsing (monaco-editor 0.56.0, the TypeScript
// regex engine parser). It handles the full ECMAScript RegExp grammar retained
// by the M1-R frozen profile:
//
//   - Escape sequences: control chars (`\n`, `\t`, `\r`, ...), hex (`\xHH`),
//     unicode (`\uHHHH`, `\u{...}` under `u`), builtins, backreferences.
//   - Character classes: `[a-z]`, `[^a-z]`, ranges, builtins inside classes.
//   - Quantifiers: `*`, `+`, `?`, `{n}`, `{n,}`, `{n,m}`, each greedy or lazy.
//   - Groups: capturing, non-capturing `(?:...)`, named `(?<name>...)`.
//   - Named captures and `\k<name>` backreferences.
//   - Assertions: `^`, `$`, `\b`, `\B`, lookahead `(?=X)`/`(?!X)`, lookbehind
//     `(?<=X)`/`(?<!X)`.
//   - Flags: all eight ECMAScript flags (`gimsuydv`).
//
// Syntax errors are reported as `MonaRegExpSyntaxError` carrying an exact
// source offset (the index of the offending code unit within the pattern, or
// the index of the offending flag within the flag string).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A typed RegExp syntax error with an exact source offset.
public struct MonaRegExpSyntaxError: Error, Equatable, Sendable {

    /// The offset of the offending code unit within the pattern (or flag
    /// string). `-1` when the error is not position-specific.
    public let offset: Int

    /// A human-readable message describing the error.
    public let message: String

    /// Creates a syntax error.
    public init(offset: Int, message: String) {
        self.offset = offset
        self.message = message
    }
}

/// A recursive-descent RegExp parser.
public struct MonaRegExpParser {

    /// The parsed AST.
    public let ast: MonaRegExpNode

    /// The parsed flags.
    public let flags: MonaRegExpFlags

    /// The number of capturing groups (excluding group 0).
    public let captureCount: Int

    /// Named captures: name → 1-based capture index.
    public let namedCaptures: [String: Int]

    /// Parses `pattern` with `flags`.
    public init(pattern: String, flags: String) throws {
        let parsedFlags = try MonaRegExpFlags.parse(flags)
        var parser = _MonaRegExpParser(pattern: Array(pattern.utf16), flags: parsedFlags)
        let node = try parser.parse()
        self.ast = node
        self.flags = parsedFlags
        self.captureCount = parser.captureCount
        self.namedCaptures = parser.namedCaptures
    }
}

/// The internal mutable parser state.
fileprivate struct _MonaRegExpParser {

    let pattern: [UInt16]
    let flags: MonaRegExpFlags
    private(set) var pos: Int = 0
    private(set) var captureCount: Int = 0
    private(set) var namedCaptures: [String: Int] = [:]

    var count: Int { pattern.count }

    func syntaxError(_ message: String, at offset: Int) -> MonaRegExpSyntaxError {
        return MonaRegExpSyntaxError(offset: offset, message: message)
    }

    /// Entry: parse the full pattern as a Disjunction, then require end-of-input.
    mutating func parse() throws -> MonaRegExpNode {
        let node = try parseDisjunction()
        if pos < count {
            // A stray `)` is the typical cause.
            throw syntaxError("Unexpected character in pattern", at: pos)
        }
        return node
    }

    // MARK: - Disjunction / Alternative / Term

    /// Disjunction := Alternative ('|' Alternative)*
    mutating func parseDisjunction() throws -> MonaRegExpNode {
        var alts: [MonaRegExpNode] = [try parseAlternative()]
        while pos < count && pattern[pos] == 0x007C {  // '|'
            pos += 1
            alts.append(try parseAlternative())
        }
        return alts.count == 1 ? alts[0] : .alternation(alts)
    }

    /// Alternative := [Term]*  (empty allowed → .empty)
    mutating func parseAlternative() throws -> MonaRegExpNode {
        var terms: [MonaRegExpNode] = []
        while pos < count {
            let c = pattern[pos]
            if c == 0x007C || c == 0x0029 { break }  // '|' or ')'
            terms.append(try parseTerm())
        }
        if terms.isEmpty { return .empty }
        if terms.count == 1 { return terms[0] }
        return .concatenation(terms)
    }

    /// Term := Assertion | QuantifiedAtom
    mutating func parseTerm() throws -> MonaRegExpNode {
        // Lookaround assertions begin with "(?" + a lookaround marker.
        if pos + 1 < count && pattern[pos] == 0x0028 && pattern[pos + 1] == 0x003F {
            if let la = try parseLookaroundIfPresent() {
                return la
            }
        }
        // Bare assertions: ^, $, \b, \B.
        if pos < count {
            let c = pattern[pos]
            if c == 0x005E { pos += 1; return .assertion(.start) }       // ^
            if c == 0x0024 { pos += 1; return .assertion(.end) }         // $
            if c == 0x005C && pos + 1 < count {                            // '\'
                let n = pattern[pos + 1]
                if n == 0x0062 { pos += 2; return .assertion(.wordBoundary) }    // \b
                if n == 0x0042 { pos += 2; return .assertion(.notWordBoundary) }   // \B
            }
        }
        var atom = try parseAtom()
        if pos < count && Self.isQuantifierChar(pattern[pos]) {
            atom = try parseQuantifier(atom)
        }
        return atom
    }

    /// Attempts to parse a lookaround assertion `(?=X)`, `(?!X)`, `(?<=X)`,
    /// `(?<!X)` if the cursor is at one. Returns `nil` if it's a group
    /// (`(?:...)`, `(?<name>...)`) — handled by `parseAtom`.
    mutating func parseLookaroundIfPresent() throws -> MonaRegExpNode? {
        // Cursor at '(' '?'. Peek the marker after '(?'.
        guard pos + 2 < count else { return nil }
        let m2 = pattern[pos + 2]
        // Positive/negative lookahead: (?= ...) / (?! ...)
        if m2 == 0x003D || m2 == 0x0021 {  // '=' or '!'
            let negated = (m2 == 0x0021)
            let start = pos
            pos += 3  // consume '(?' marker
            let body = try parseDisjunction()
            try expect(0x0029, at: start, what: "lookahead")
            return .assertion(.lookahead(body, negated))
        }
        // Lookbehind: (?<= ...) / (?<! ...) — marker is '<' then '=' or '!'
        if m2 == 0x003C {  // '<'
            guard pos + 3 < count else { return nil }
            let m3 = pattern[pos + 3]
            if m3 == 0x003D || m3 == 0x0021 {
                let negated = (m3 == 0x0021)
                let start = pos
                pos += 4  // consume '(?<' marker
                let body = try parseDisjunction()
                try expect(0x0029, at: start, what: "lookbehind")
                return .assertion(.lookbehind(body, negated))
            }
            // Otherwise (?<name>...) is a named group — not a lookaround.
            return nil
        }
        return nil
    }

    // MARK: - Atom

    /// Atom := '.' | '\' Escape | '[' CharClass ']' | '(' Group ')' | char
    mutating func parseAtom() throws -> MonaRegExpNode {
        guard pos < count else {
            throw syntaxError("Unexpected end of pattern", at: pos)
        }
        let c = pattern[pos]
        switch c {
        case 0x002E:  // '.'
            pos += 1
            return .anyChar
        case 0x005B:  // '['
            return try parseCharClass()
        case 0x0028:  // '('
            return try parseGroup()
        case 0x005C:  // '\'
            return try parseAtomEscape()
        case 0x0029, 0x007C, 0x005D:  // ')', '|', ']' — should not reach here
            throw syntaxError("Unexpected '\(String(c, radix: 16))' in pattern", at: pos)
        case 0x002A, 0x002B, 0x003F, 0x007B:  // '*', '+', '?', '{' — quantifier with no atom
            throw syntaxError("Nothing to repeat (quantifier with no preceding atom)", at: pos)
        default:
            pos += 1
            return .character(c)
        }
    }

    /// Parses an escape sequence as an atom (outside a character class).
    mutating func parseAtomEscape() throws -> MonaRegExpNode {
        // Assumes pattern[pos] == '\'.
        let start = pos
        pos += 1
        guard pos < count else {
            throw syntaxError("Trailing backslash in pattern", at: start)
        }
        let c = pattern[pos]
        switch c {
        case 0x0064: pos += 1; return .charClass(MonaRegExpCharClass(items: [.builtin(.digit)]))      // \d
        case 0x0044: pos += 1; return .charClass(MonaRegExpCharClass(items: [.builtin(.notDigit)]))   // \D
        case 0x0077: pos += 1; return .charClass(MonaRegExpCharClass(items: [.builtin(.word)]))        // \w
        case 0x0057: pos += 1; return .charClass(MonaRegExpCharClass(items: [.builtin(.notWord)]))     // \W
        case 0x0073: pos += 1; return .charClass(MonaRegExpCharClass(items: [.builtin(.whitespace)])) // \s
        case 0x0053: pos += 1; return .charClass(MonaRegExpCharClass(items: [.builtin(.notWhitespace)]))// \S
        case 0x006E: pos += 1; return .character(0x000A)   // \n
        case 0x0072: pos += 1; return .character(0x000D)   // \r
        case 0x0074: pos += 1; return .character(0x0009)   // \t
        case 0x0076: pos += 1; return .character(0x000B)   // \v
        case 0x0066: pos += 1; return .character(0x000C)   // \f
        case 0x0078: pos += 1; return .character(try parseHexEscape(at: start))             // \xHH
        case 0x0075: pos += 1; return try parseUnicodeEscapeAtom(at: start)                 // \uHHHH / \u{...}
        case 0x006B: pos += 1; return try parseNamedBackreference(at: start)                // \k<name>
        case 0x0030:   // \0
            pos += 1
            // \0 followed by a decimal digit is an octal escape; otherwise NUL.
            if pos < count && Self.isOctalDigit(pattern[pos]) {
                return .character(try parseOctalEscape(firstDigit: 0, at: start))
            }
            return .character(0x0000)
        case 0x0031...0x0039:   // \1..\9 — backreference or octal
            let digit = Int(c) - 0x0030
            if digit <= captureCount {
                pos += 1
                return .backreference(digit)
            }
            return .character(try parseOctalEscape(firstDigit: digit, at: start))
        default:
            pos += 1
            return .character(c)
        }
    }

    /// Parses a named backreference `\k<name>`. The `\k` has been consumed.
    mutating func parseNamedBackreference(at start: Int) throws -> MonaRegExpNode {
        guard pos < count, pattern[pos] == 0x003C else {  // '<'
            throw syntaxError("Invalid named backreference (expected '<')", at: start)
        }
        pos += 1  // consume '<'
        let name = try parseGroupName(openAt: start)
        guard namedCaptures[name] != nil else {
            throw syntaxError("Invalid named reference '\(name)' (no such group)", at: start)
        }
        return .namedBackreference(name)
    }

    // MARK: - Group

    /// Parses a group: capturing, non-capturing, or named.
    mutating func parseGroup() throws -> MonaRegExpNode {
        // Assumes pattern[pos] == '('.
        let start = pos
        pos += 1  // consume '('
        guard pos < count else {
            throw syntaxError("Unterminated group", at: start)
        }
        if pattern[pos] == 0x003F {  // '?'
            pos += 1
            guard pos < count else {
                throw syntaxError("Unterminated group", at: start)
            }
            let c = pattern[pos]
            switch c {
            case 0x003A:  // '?:' non-capturing
                pos += 1
                let body = try parseDisjunction()
                try expect(0x0029, at: start, what: "non-capturing group")
                return .group(MonaRegExpGroup(kind: .nonCapturing, node: body, index: 0))
            case 0x003C:  // '(?<...'
                pos += 1
                guard pos < count else {
                    throw syntaxError("Unterminated group", at: start)
                }
                let c2 = pattern[pos]
                if c2 == 0x003D || c2 == 0x0021 {
                    // (?<=...) / (?<!...) — but lookaround is handled earlier; reaching
                    // here means it appeared where an atom was expected, which is fine.
                    let negated = (c2 == 0x0021)
                    pos += 1
                    let body = try parseDisjunction()
                    try expect(0x0029, at: start, what: "lookbehind")
                    return .assertion(.lookbehind(body, negated))
                }
                // (?<name>...) named capture
                let name = try parseGroupName(openAt: start - 1)
                captureCount += 1
                let idx = captureCount
                if namedCaptures[name] != nil {
                    throw syntaxError("Duplicate named capture '\(name)'", at: start)
                }
                namedCaptures[name] = idx
                let body = try parseDisjunction()
                try expect(0x0029, at: start, what: "named group")
                return .group(MonaRegExpGroup(kind: .named(name), node: body, index: idx))
            default:
                throw syntaxError("Invalid group qualifier", at: start)
            }
        }
        // Capturing (...)
        captureCount += 1
        let idx = captureCount
        let body = try parseDisjunction()
        try expect(0x0029, at: start, what: "capturing group")
        return .group(MonaRegExpGroup(kind: .capturing, node: body, index: idx))
    }

    /// Parses a group name between `<` and `>`, consuming the closing `>`.
    mutating func parseGroupName(openAt start: Int) throws -> String {
        var nameUnits: [UInt16] = []
        while pos < count && pattern[pos] != 0x003E {  // '>'
            nameUnits.append(pattern[pos])
            pos += 1
        }
        guard pos < count, pattern[pos] == 0x003E else {
            throw syntaxError("Unterminated group name (expected '>')", at: start)
        }
        pos += 1  // consume '>'
        let name = String(decoding: nameUnits, as: UTF16.self)
        guard !name.isEmpty else {
            throw syntaxError("Empty group name", at: start)
        }
        return name
    }

    // MARK: - Character class

    /// Parses a character class `[...]` (possibly negated `[^...]`).
    mutating func parseCharClass() throws -> MonaRegExpNode {
        // Assumes pattern[pos] == '['.
        let start = pos
        pos += 1  // consume '['
        var negated = false
        if pos < count && pattern[pos] == 0x005E {  // '^'
            negated = true
            pos += 1
        }
        var items: [MonaRegExpCharClassItem] = []
        var first = true
        while pos < count {
            let c = pattern[pos]
            if c == 0x005D && !first {  // ']' (literal ']' as first char)
                pos += 1
                return .charClass(MonaRegExpCharClass(negated: negated, items: items))
            }
            first = false
            let atom = try parseClassAtom()
            // Range? `atom '-' hi`.
            if case .char(let lo) = atom,
               pos < count && pattern[pos] == 0x002D,  // '-'
               pos + 1 < count && pattern[pos + 1] != 0x005D {  // not ']' (trailing '-' is literal)
                pos += 1  // consume '-'
                let hiAtom = try parseClassAtom()
                guard case .char(let hi) = hiAtom else {
                    // Mixed range with a builtin: treat as atom + literal '-' + hiAtom.
                    items.append(atom)
                    items.append(.char(0x002D))
                    items.append(hiAtom)
                    continue
                }
                if hi < lo {
                    throw syntaxError("Range out of order in character class", at: start)
                }
                items.append(.range(lo, hi))
            } else {
                items.append(atom)
            }
        }
        throw syntaxError("Unterminated character class", at: start)
    }

    /// Parses one class atom (a literal char or a builtin escape).
    mutating func parseClassAtom() throws -> MonaRegExpCharClassItem {
        let c = pattern[pos]
        if c == 0x005C {  // '\'
            return try parseClassEscape()
        }
        pos += 1
        return .char(c)
    }

    /// Parses an escape inside a character class.
    mutating func parseClassEscape() throws -> MonaRegExpCharClassItem {
        // Assumes pattern[pos] == '\'.
        let start = pos
        pos += 1
        guard pos < count else {
            throw syntaxError("Trailing backslash in character class", at: start)
        }
        let c = pattern[pos]
        switch c {
        case 0x0064: pos += 1; return .builtin(.digit)         // \d
        case 0x0044: pos += 1; return .builtin(.notDigit)     // \D
        case 0x0077: pos += 1; return .builtin(.word)         // \w
        case 0x0057: pos += 1; return .builtin(.notWord)       // \W
        case 0x0073: pos += 1; return .builtin(.whitespace)    // \s
        case 0x0053: pos += 1; return .builtin(.notWhitespace) // \S
        case 0x0062: pos += 1; return .char(0x0008)            // \b → backspace inside class
        case 0x006E: pos += 1; return .char(0x000A)            // \n
        case 0x0072: pos += 1; return .char(0x000D)            // \r
        case 0x0074: pos += 1; return .char(0x0009)            // \t
        case 0x0076: pos += 1; return .char(0x000B)            // \v
        case 0x0066: pos += 1; return .char(0x000C)            // \f
        case 0x0030:  // \0 or octal
            pos += 1
            if pos < count && Self.isOctalDigit(pattern[pos]) {
                return .char(try parseOctalEscape(firstDigit: 0, at: start))
            }
            return .char(0x0000)
        case 0x0031...0x0037:  // octal escape
            let digit = Int(c) - 0x0030
            return .char(try parseOctalEscape(firstDigit: digit, at: start))
        case 0x0078:  // \xHH
            pos += 1
            return .char(try parseHexEscape(at: start))
        case 0x0075:  // \uHHHH / \u{...}
            pos += 1
            let units = try parseUnicodeEscapeUnits(at: start)
            // A BMP code point yields one char; an astral code point yields a
            // surrogate pair, represented as two char items.
            if units.count == 1 {
                return .char(units[0])
            }
            // A surrogate pair inside a class: emit the high surrogate as a
            // single char. Full code-point class semantics under `u` arrive
            // with the Unicode profiles (P02-T005); this frozen profile
            // preserves the raw-UTF-16 code-unit view.
            return .char(units[0])
        default:
            pos += 1
            return .char(c)
        }
    }

    // MARK: - Quantifier

    static func isQuantifierChar(_ u: UInt16) -> Bool {
        return u == 0x002A || u == 0x002B || u == 0x003F || u == 0x007B  // * + ? {
    }

    /// Parses a quantifier following `atom`.
    mutating func parseQuantifier(_ atom: MonaRegExpNode) throws -> MonaRegExpNode {
        let c = pattern[pos]
        var min: Int
        var max: Int?
        switch c {
        case 0x002A: pos += 1; min = 0; max = nil    // *
        case 0x002B: pos += 1; min = 1; max = nil    // +
        case 0x003F: pos += 1; min = 0; max = 1      // ?
        case 0x007B:  // '{'
            guard let bounds = try parseBraceQuantifier() else {
                // Not a valid quantifier form — `{` is a literal char (handled
                // by the caller's alternative loop). This is unreachable from
                // parseTerm (which only calls parseQuantifier when '{' is a
                // quantifier char), but guard for safety.
                return atom
            }
            min = bounds.min
            max = bounds.max
        default:
            return atom
        }
        var greedy = true
        if pos < count && pattern[pos] == 0x003F {  // '?'
            pos += 1
            greedy = false
        }
        return .quantifier(MonaRegExpQuantifier(atom: atom, min: min, max: max, greedy: greedy))
    }

    /// Parses a `{n}`, `{n,}`, or `{n,m}` quantifier body (the leading `{` is at
    /// `pos`). Returns `nil` if it is not a valid quantifier form (so `{` is
    /// treated as a literal). Throws if `m < n` (out-of-order range).
    mutating func parseBraceQuantifier() throws -> (min: Int, max: Int?)? {
        let save = pos
        pos += 1  // consume '{'
        var nStr = ""
        while pos < count && Self.isDigit(pattern[pos]) {
            nStr.append(Character(UnicodeScalar(UInt32(pattern[pos]))!))
            pos += 1
        }
        if nStr.isEmpty {
            pos = save
            return nil
        }
        guard let n = Int(nStr) else {
            pos = save
            return nil
        }
        if pos < count && pattern[pos] == 0x007D {  // '}'
            pos += 1
            return (n, n)
        }
        if pos < count && pattern[pos] == 0x002C {  // ','
            pos += 1
            var mStr = ""
            while pos < count && Self.isDigit(pattern[pos]) {
                mStr.append(Character(UnicodeScalar(UInt32(pattern[pos]))!))
                pos += 1
            }
            if pos < count && pattern[pos] == 0x007D {  // '}'
                pos += 1
                if mStr.isEmpty {
                    return (n, nil)  // {n,}
                }
                guard let m = Int(mStr) else {
                    pos = save
                    return nil
                }
                if m < n {
                    throw syntaxError("Quantifier range out of order ({\(n),\(m)})", at: save)
                }
                return (n, m)
            }
        }
        // Malformed — treat '{' as a literal.
        pos = save
        return nil
    }

    // MARK: - Escapes (hex / unicode / octal)

    /// Parses 1-3 octal digits following `firstDigit`. Returns the UInt16 value.
    mutating func parseOctalEscape(firstDigit: Int, at start: Int) throws -> UInt16 {
        var value = firstDigit
        var digits = 1
        while digits < 3 && pos < count && Self.isOctalDigit(pattern[pos]) {
            let d = Int(pattern[pos]) - 0x0030
            let candidate = value * 8 + d
            if candidate > 0xFF { break }
            value = candidate
            pos += 1
            digits += 1
        }
        return UInt16(value)
    }

    /// Parses a `\xHH` escape (exactly two hex digits). The `\x` has been consumed.
    mutating func parseHexEscape(at start: Int) throws -> UInt16 {
        guard pos + 1 < count else {
            throw syntaxError("Invalid hex escape (expected two hex digits)", at: start)
        }
        let hi = Self.hexValue(pattern[pos])
        let lo = Self.hexValue(pattern[pos + 1])
        guard let hi = hi, let lo = lo else {
            throw syntaxError("Invalid hex escape (non-hex digit)", at: start)
        }
        pos += 2
        return UInt16(hi * 16 + lo)
    }

    /// Parses a `\u` escape as an atom. The `\u` has been consumed.
    mutating func parseUnicodeEscapeAtom(at start: Int) throws -> MonaRegExpNode {
        let units = try parseUnicodeEscapeUnits(at: start)
        if units.count == 1 {
            return .character(units[0])
        }
        return .concatenation(units.map { .character($0) })
    }

    /// Parses a `\uHHHH` or `\u{...}` escape into one or two UTF-16 code units.
    /// The `\u` has been consumed.
    mutating func parseUnicodeEscapeUnits(at start: Int) throws -> [UInt16] {
        if pos < count && pattern[pos] == 0x007B {  // '{'
            guard flags.contains(.unicode) else {
                throw syntaxError("'\\u{...}' requires the 'u' flag", at: start)
            }
            let braceStart = pos
            pos += 1  // consume '{'
            var hex = ""
            while pos < count && Self.isHexDigit(pattern[pos]) {
                hex.append(Self.hexChar(pattern[pos]))
                pos += 1
            }
            guard pos < count, pattern[pos] == 0x007D else {  // '}'
                throw syntaxError("Invalid unicode escape (expected '}')", at: braceStart)
            }
            pos += 1  // consume '}'
            guard let cp = UInt32(hex, radix: 16) else {
                throw syntaxError("Invalid unicode code point", at: braceStart)
            }
            if cp > 0x10FFFF {
                throw syntaxError("Unicode code point out of range", at: braceStart)
            }
            return Self.utf16FromCodePoint(cp)
        }
        // \uHHHH — exactly four hex digits.
        guard pos + 3 < count else {
            throw syntaxError("Invalid unicode escape (expected four hex digits)", at: start)
        }
        var value: UInt32 = 0
        for k in 0..<4 {
            guard let d = Self.hexValue(pattern[pos + k]) else {
                throw syntaxError("Invalid unicode escape (non-hex digit)", at: start)
            }
            value = value * 16 + UInt32(d)
        }
        pos += 4
        return [UInt16(value)]
    }

    // MARK: - Helpers

    static func utf16FromCodePoint(_ cp: UInt32) -> [UInt16] {
        if cp <= 0xFFFF {
            return [UInt16(cp)]
        }
        let adjusted = cp - 0x10000
        let hi = 0xD800 + (adjusted >> 10)
        let lo = 0xDC00 + (adjusted & 0x3FF)
        return [UInt16(hi), UInt16(lo)]
    }

    static func isDigit(_ u: UInt16) -> Bool {
        return u >= 0x0030 && u <= 0x0039
    }

    static func isOctalDigit(_ u: UInt16) -> Bool {
        return u >= 0x0030 && u <= 0x0037
    }

    static func isHexDigit(_ u: UInt16) -> Bool {
        return (u >= 0x0030 && u <= 0x0039)
            || (u >= 0x0041 && u <= 0x0046)
            || (u >= 0x0061 && u <= 0x0066)
    }

    static func hexValue(_ u: UInt16) -> Int? {
        if u >= 0x0030 && u <= 0x0039 { return Int(u) - 0x0030 }
        if u >= 0x0041 && u <= 0x0046 { return Int(u) - 0x0041 + 10 }
        if u >= 0x0061 && u <= 0x0066 { return Int(u) - 0x0061 + 10 }
        return nil
    }

    static func hexChar(_ u: UInt16) -> Character {
        return Character(UnicodeScalar(UInt32(u))!)
    }

    /// Requires `pattern[pos] == expected`; consumes it, else throws.
    mutating func expect(_ expected: UInt16, at start: Int, what: String) throws {
        guard pos < count, pattern[pos] == expected else {
            let got = pos < count ? String(pattern[pos], radix: 16) : "EOF"
            throw syntaxError("Unterminated \(what) (expected ')', got 0x\(got))", at: start)
        }
        pos += 1
    }
}
