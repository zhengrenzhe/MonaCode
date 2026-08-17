// MonaReplacePattern.swift
//
// P02-T003 — Implement word, grapheme, literal search, and replacement primitives.
//
// `MonaReplacePattern` is the replacement-pattern primitive: it parses a
// replacement template over raw UTF-16 code units and applies it to a match's
// captures, producing the replacement text. It is the Swift counterpart of
// Monaco's replacement-string substitution (monaco-editor 0.56.0,
// `vs/editor/common/commands/replaceCommand.ts` and the `applyReplace` helper
// in `vs/base/common/strings.ts`).
//
// Capture syntax (the Phase-02 frozen subset of ECMAScript
// `String.prototype.replace` replacement-specifier semantics):
//
//   - `$$`  — a literal `$`.
//   - `$&`  — the full match text (group 0).
//   - `$n`  — the nth numbered capture, where n is a single digit 1..9 not
//             followed by another digit. If group n does not exist
//             (n > captures.count), the literal `$n` is emitted.
//   - `$nn` — the nnth numbered capture, where nn is two digits 10..99. If
//             group nn exists, it is used; otherwise, if the first digit is an
//             existing group, that group is used followed by a literal second
//             digit; otherwise the literal `$nn` is emitted.
//   - `$<name>` — a named capture. If `name` is absent from the named-capture
//             map, the empty string is emitted. (Named captures are populated
//             by the RegExp executor in P02-T004; the parser is ready here.)
//   - `$` followed by any other character (or a trailing `$`) is a literal `$`
//             followed by that character.
//
// Case conversion and RegExp execution are deliberately NOT used here: the
// pattern is a pure template over captures supplied by the caller (or by the
// RegExp executor in a later phase).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// One token in a parsed replacement pattern.
public enum MonaReplaceToken: Equatable, Hashable {

    /// A literal run of UTF-16 code units emitted verbatim.
    case literal([UInt16])

    /// The full match text (`$&`).
    case fullMatch

    /// A single-digit numbered capture (`$1`..`$9`). The number is 1-indexed.
    case capture(Int)

    /// A two-digit numbered capture (`$10`..`$99`). The number is 1-indexed.
    case captureTwoDigit(Int)

    /// A named capture (`$<name>`).
    case namedCapture(String)
}

/// The captures and full-match text a `MonaReplacePattern` is applied against.
public struct MonaReplaceMatch: Equatable {

    /// The full match text (group 0).
    public let fullMatch: [UInt16]

    /// The numbered captures, 1-indexed: `captures[0]` is group 1. A group that
    /// exists but did not participate is represented by an empty array.
    public let captures: [[UInt16]]

    /// The named captures, keyed by name.
    public let namedCaptures: [String: [UInt16]]

    /// Creates a replace match.
    public init(
        fullMatch: [UInt16],
        captures: [[UInt16]] = [],
        namedCaptures: [String: [UInt16]] = [:]
    ) {
        self.fullMatch = fullMatch
        self.captures = captures
        self.namedCaptures = namedCaptures
    }
}

/// A parsed replacement pattern.
public struct MonaReplacePattern: Equatable {

    /// The parsed tokens, in emission order.
    public let tokens: [MonaReplaceToken]

    /// Creates a pattern from pre-parsed tokens.
    public init(tokens: [MonaReplaceToken]) {
        self.tokens = tokens
    }

    /// Parses `pattern` into tokens.
    public init(_ pattern: [UInt16]) {
        self.tokens = MonaReplacePattern.parse(pattern)
    }

    /// Applies this pattern to `match`, substituting captures and the full
    /// match, and returns the resulting UTF-16 code units.
    public func apply(_ match: MonaReplaceMatch) -> [UInt16] {
        var out: [UInt16] = []
        for token in tokens {
            switch token {
            case .literal(let u):
                out.append(contentsOf: u)
            case .fullMatch:
                out.append(contentsOf: match.fullMatch)
            case .capture(let n):
                if n >= 1 && n <= match.captures.count {
                    out.append(contentsOf: match.captures[n - 1])
                } else {
                    out.append(Self.dollar)
                    out.append(UInt16(0x0030 + n))
                }
            case .captureTwoDigit(let nn):
                let d1 = nn / 10
                let d2 = nn % 10
                if nn >= 1 && nn <= match.captures.count {
                    out.append(contentsOf: match.captures[nn - 1])
                } else if d1 >= 1 && d1 <= match.captures.count {
                    out.append(contentsOf: match.captures[d1 - 1])
                    out.append(UInt16(0x0030 + d2))
                } else {
                    out.append(Self.dollar)
                    out.append(UInt16(0x0030 + d1))
                    out.append(UInt16(0x0030 + d2))
                }
            case .namedCapture(let name):
                if let v = match.namedCaptures[name] {
                    out.append(contentsOf: v)
                }
                // Absent named capture → empty string.
            }
        }
        return out
    }

    // MARK: - Internals

    /// `$`.
    private static let dollar: UInt16 = 0x0024

    /// Parses `pattern` into tokens.
    private static func parse(_ pattern: [UInt16]) -> [MonaReplaceToken] {
        var tokens: [MonaReplaceToken] = []
        var lit: [UInt16] = []
        let n = pattern.count
        var i = 0

        func flushLiteral() {
            if !lit.isEmpty {
                tokens.append(.literal(lit))
                lit = []
            }
        }

        while i < n {
            let u = pattern[i]
            guard u == dollar else {
                lit.append(u)
                i += 1
                continue
            }
            // u == '$'
            if i + 1 >= n {
                // Trailing '$' → literal '$'.
                lit.append(dollar)
                i += 1
                continue
            }
            let next = pattern[i + 1]
            if next == dollar {
                // `$$` → literal `$`.
                lit.append(dollar)
                i += 2
            } else if next == 0x0026 {
                // `$&` → full match.
                flushLiteral()
                tokens.append(.fullMatch)
                i += 2
            } else if next == 0x003C {
                // `$<name>` → named capture (requires a closing `>`).
                var j = i + 2
                while j < n && pattern[j] != 0x003E {
                    j += 1
                }
                if j < n && pattern[j] == 0x003E {
                    flushLiteral()
                    let nameUnits = Array(pattern[(i + 2)..<j])
                    let name = String(decoding: nameUnits, as: UTF16.self)
                    tokens.append(.namedCapture(name))
                    i = j + 1
                } else {
                    // No closing `>` → literal `$`.
                    lit.append(dollar)
                    i += 1
                }
            } else if let d1 = digitValue(next) {
                // First digit 1..9.
                if i + 2 < n, let d2 = digitValue(pattern[i + 2]) {
                    // Two-digit `$nn`.
                    flushLiteral()
                    tokens.append(.captureTwoDigit(d1 * 10 + d2))
                    i += 3
                } else {
                    // Single-digit `$n`.
                    flushLiteral()
                    tokens.append(.capture(d1))
                    i += 2
                }
            } else {
                // `$` + other → literal `$` (the other char is processed next).
                lit.append(dollar)
                i += 1
            }
        }
        flushLiteral()
        return tokens
    }

    /// Returns the decimal value 0..9 of `u`, or `nil` if `u` is not an ASCII
    /// digit.
    private static func digitValue(_ u: UInt16) -> Int? {
        if u >= 0x0030 && u <= 0x0039 {
            return Int(u) - 0x0030
        }
        return nil
    }
}
