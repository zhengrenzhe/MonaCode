// MonaRegExpAST.swift
//
// P02-T004 — Implement the finite ECMAScript RegExp parser and compiler.
//
// `MonaRegExpAST` defines the abstract syntax tree (AST) node types produced by
// `MonaRegExpParser` and consumed by `MonaRegExpCompiler`. It is the Swift
// counterpart of Monaco's RegExp parse tree (monaco-editor 0.56.0, the
// TypeScript regex engine in `vs/editor/common/model/regex.ts` and its
// dependencies). The AST is a faithful, frozen representation of the
// ECMAScript RegExp grammar subset retained by the M1-R model:
//
//   - Character literals (raw UTF-16 code units).
//   - Character classes: `[a-z]`, `[^a-z]`, `\d`, `\D`, `\w`, `\W`, `\s`,
//     `\S`, `.`.
//   - Quantifiers: `*`, `+`, `?`, `{n}`, `{n,}`, `{n,m}`, each greedy or lazy
//     (`?` suffix).
//   - Groups: capturing `(...)`, non-capturing `(?:...)`, named `(?<name>...)`.
//   - Alternation `a|b|c` and concatenation.
//   - Assertions: `^`, `$`, `\b`, `\B`, lookahead `(?=X)` / `(?!X)`, lookbehind
//     `(?<=X)` / `(?<!X)`.
//   - Backreferences: `\1`..`\9` and `\k<name>`.
//
// Flags: the eight ECMAScript RegExp flags are accepted by the parser:
// `g` (global), `i` (ignore case), `m` (multiline), `s` (dotAll), `u` (unicode),
// `y` (sticky), `d` (indices), `v` (unicode sets). Only `g`, `i`, `m`, `s`, `u`,
// and `y` carry runtime semantics in the Phase-02 frozen profile; `d` and `v`
// are accepted and stored for forward compatibility (their full semantics arrive
// with the Unicode profiles in P02-T005/P02-T006).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The eight ECMAScript RegExp flags as an OptionSet.
public struct MonaRegExpFlags: OptionSet, Equatable, Hashable, Sendable {

    public var rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// `g` — global search (find all matches; update `lastIndex`).
    public static let global = MonaRegExpFlags(rawValue: 1 << 0)

    /// `i` — ignore case (case-insensitive matching via the Phase-02
    /// `MonaCaseConverter` provider).
    public static let ignoreCase = MonaRegExpFlags(rawValue: 1 << 1)

    /// `m` — multiline (`^` and `$` match at line boundaries).
    public static let multiline = MonaRegExpFlags(rawValue: 1 << 2)

    /// `s` — dotAll (`.` matches line terminators).
    public static let dotAll = MonaRegExpFlags(rawValue: 1 << 3)

    /// `u` — unicode (code-point-aware parsing and `\u{...}` escapes).
    public static let unicode = MonaRegExpFlags(rawValue: 1 << 4)

    /// `y` — sticky (match must begin exactly at `lastIndex`).
    public static let sticky = MonaRegExpFlags(rawValue: 1 << 5)

    /// `d` — indices (capture start/end exposed; accepted, not yet runtime).
    public static let indices = MonaRegExpFlags(rawValue: 1 << 6)

    /// `v` — unicode sets (superset of `u`; accepted, not yet runtime).
    public static let unicodeSets = MonaRegExpFlags(rawValue: 1 << 7)

    /// Parses a flag string into a `MonaRegExpFlags`, throwing on unknown or
    /// duplicate flags. The `offset` in a thrown `MonaRegExpSyntaxError` is the
    /// index of the offending flag character within the flag string.
    public static func parse(_ flagString: String) throws -> MonaRegExpFlags {
        var flags = MonaRegExpFlags(rawValue: 0)
        var seen: Set<UInt8> = []
        for (i, scalar) in flagString.unicodeScalars.enumerated() {
            let value = UInt16(scalar.value)
            let bit: UInt8
            let name: String
            switch value {
            case 0x0067: bit = 1 << 0; name = "g"   // global
            case 0x0069: bit = 1 << 1; name = "i"   // ignoreCase
            case 0x006D: bit = 1 << 2; name = "m"   // multiline
            case 0x0073: bit = 1 << 3; name = "s"   // dotAll
            case 0x0075: bit = 1 << 4; name = "u"   // unicode
            case 0x0079: bit = 1 << 5; name = "y"   // sticky
            case 0x0064: bit = 1 << 6; name = "d"   // indices
            case 0x0076: bit = 1 << 7; name = "v"   // unicodeSets
            default:
                throw MonaRegExpSyntaxError(
                    offset: i,
                    message: "Unknown RegExp flag 'U+\(String(value, radix: 16))'"
                )
            }
            if seen.contains(bit) {
                throw MonaRegExpSyntaxError(
                    offset: i,
                    message: "Duplicate RegExp flag '\(name)'"
                )
            }
            seen.insert(bit)
            flags.rawValue |= bit
        }
        return flags
    }
}

/// A backslash builtin character class: `\d`, `\D`, `\w`, `\W`, `\s`, `\S`.
public enum MonaRegExpBuiltinClass: String, Equatable, Hashable, Sendable {

    /// `\d` — a decimal digit `[0-9]`.
    case digit
    /// `\D` — not a decimal digit.
    case notDigit
    /// `\w` — a word character `[a-zA-Z0-9_]`.
    case word
    /// `\W` — not a word character.
    case notWord
    /// `\s` — whitespace.
    case whitespace
    /// `\S` — not whitespace.
    case notWhitespace
}

/// One item inside a character class `[...]`.
public enum MonaRegExpCharClassItem: Equatable, Hashable, Sendable {

    /// A single literal code unit.
    case char(UInt16)

    /// A closed range of code units `[lo, hi]`.
    case range(UInt16, UInt16)

    /// A builtin class (`\d`, `\w`, `\s`, ...).
    case builtin(MonaRegExpBuiltinClass)
}

/// A character class `[...]` (possibly negated `[^...]`), with a list of items.
public struct MonaRegExpCharClass: Equatable, Hashable, Sendable {

    /// `true` for a negated class `[^...]`.
    public let negated: Bool

    /// The class items (chars, ranges, builtins).
    public let items: [MonaRegExpCharClassItem]

    /// Creates a character class.
    public init(negated: Bool = false, items: [MonaRegExpCharClassItem]) {
        self.negated = negated
        self.items = items
    }

    /// Returns `true` if `codeUnit` is a member of this class under the
    /// optional case-conversion provider.
    ///
    /// When `converter` is non-nil (case-insensitive mode), char and range
    /// items are compared through `foldCase`. Builtins are case-agnostic
    /// (`\w`/`\d`/`\s` already include both cases or are case-neutral), so they
    /// are not folded. This preserves the frozen raw-UTF-16 contract: lone
    /// surrogates and non-ASCII code units are never repaired.
    public func matches(_ codeUnit: UInt16, converter: MonaCaseConverter? = nil) -> Bool {
        var member = false
        for item in items {
            switch item {
            case .char(let c):
                if let conv = converter {
                    if conv.foldCase(codeUnit) == conv.foldCase(c) { member = true }
                } else if codeUnit == c {
                    member = true
                }
            case .range(let lo, let hi):
                if let conv = converter {
                    let f = conv.foldCase(codeUnit)
                    if f >= conv.foldCase(lo) && f <= conv.foldCase(hi) { member = true }
                } else if codeUnit >= lo && codeUnit <= hi {
                    member = true
                }
            case .builtin(let b):
                switch b {
                case .digit:
                    if Self.isDigit(codeUnit) { member = true }
                case .notDigit:
                    if !Self.isDigit(codeUnit) { member = true }
                case .word:
                    if Self.isWord(codeUnit) { member = true }
                case .notWord:
                    if !Self.isWord(codeUnit) { member = true }
                case .whitespace:
                    if Self.isWhitespace(codeUnit) { member = true }
                case .notWhitespace:
                    if !Self.isWhitespace(codeUnit) { member = true }
                }
            }
            if member { break }
        }
        return negated ? !member : member
    }

    /// `\d` — a decimal digit `[0-9]`.
    static func isDigit(_ u: UInt16) -> Bool {
        return u >= 0x0030 && u <= 0x0039
    }

    /// `\w` — a word character `[a-zA-Z0-9_]`.
    static func isWord(_ u: UInt16) -> Bool {
        return (u >= 0x0061 && u <= 0x007A)   // a-z
            || (u >= 0x0041 && u <= 0x005A)   // A-Z
            || (u >= 0x0030 && u <= 0x0039)   // 0-9
            || u == 0x005F                    // _
    }

    /// `\s` — ECMAScript whitespace (the principal set).
    static func isWhitespace(_ u: UInt16) -> Bool {
        switch u {
        case 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0020,  // \t\n\v\f\r space
             0x00A0,                                            // nbsp
             0x1680,                                            // ogham space
             0x2000...0x200A,                                   // en-quad..hair space
             0x2028, 0x2029,                                     // line/para separator
             0x202F, 0x205F, 0x3000,                            // narrow/medium/ideographic
             0xFEFF:                                            // bom/zwnbsp
            return true
        default:
            return false
        }
    }

    /// `true` if `u` is a line terminator (LF, CR, LS, PS) per ECMAScript.
    static func isLineTerminator(_ u: UInt16) -> Bool {
        return u == 0x000A || u == 0x000D || u == 0x2028 || u == 0x2029
    }
}

/// A quantifier `atom{min,max}` (greedy or lazy).
public struct MonaRegExpQuantifier: Equatable, Hashable, Sendable {

    /// The quantified atom.
    public let atom: MonaRegExpNode

    /// The minimum repetition count.
    public let min: Int

    /// The maximum repetition count, or `nil` for infinity.
    public let max: Int?

    /// `true` for greedy (`*`, `+`, `?`, `{n,m}`); `false` for lazy (`*?`...).
    public let greedy: Bool

    /// Creates a quantifier.
    public init(atom: MonaRegExpNode, min: Int, max: Int?, greedy: Bool) {
        self.atom = atom
        self.min = min
        self.max = max
        self.greedy = greedy
    }
}

/// The kind of a group node.
public enum MonaRegExpGroupKind: Equatable, Hashable, Sendable {

    /// A capturing group `(...)`.
    case capturing

    /// A non-capturing group `(?:...)`.
    case nonCapturing

    /// A named capturing group `(?<name>...)`.
    case named(String)
}

/// A group node: capturing, non-capturing, or named.
public struct MonaRegExpGroup: Equatable, Hashable, Sendable {

    /// The group kind.
    public let kind: MonaRegExpGroupKind

    /// The group body.
    public let node: MonaRegExpNode

    /// The 1-based capture index for capturing/named groups; 0 for
    /// non-capturing.
    public let index: Int

    /// Creates a group node.
    public init(kind: MonaRegExpGroupKind, node: MonaRegExpNode, index: Int) {
        self.kind = kind
        self.node = node
        self.index = index
    }
}

/// A zero-width assertion.
public indirect enum MonaRegExpAssertion: Equatable, Hashable, Sendable {

    /// `^` — start of input (or line, under `m`).
    case start

    /// `$` — end of input (or line, under `m`).
    case end

    /// `\b` — word boundary.
    case wordBoundary

    /// `\B` — not a word boundary.
    case notWordBoundary

    /// `(?=X)` (negated=false) or `(?!X)` (negated=true).
    case lookahead(MonaRegExpNode, Bool)

    /// `(?<=X)` (negated=false) or `(?<!X)` (negated=true).
    case lookbehind(MonaRegExpNode, Bool)
}

/// A RegExp AST node.
public indirect enum MonaRegExpNode: Equatable, Hashable, Sendable {

    /// An empty alternative / matches the empty string.
    case empty

    /// A single literal UTF-16 code unit.
    case character(UInt16)

    /// `.` — any code unit (dotAll/multiline handled at execution).
    case anyChar

    /// A character class `[...]`.
    case charClass(MonaRegExpCharClass)

    /// A quantified atom.
    case quantifier(MonaRegExpQuantifier)

    /// A group (capturing, non-capturing, named).
    case group(MonaRegExpGroup)

    /// A concatenation (sequence) of terms.
    case concatenation([MonaRegExpNode])

    /// An alternation `a|b|c`.
    case alternation([MonaRegExpNode])

    /// A zero-width assertion.
    case assertion(MonaRegExpAssertion)

    /// A numeric backreference `\1`..`\9`.
    case backreference(Int)

    /// A named backreference `\k<name>`.
    case namedBackreference(String)
}
