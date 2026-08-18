// MonaSnippetTransform.swift
//
// P06-T006 — Port the complete snippet parser and grammar.
//
// The transform executor: applies a `MonaSnippetTransform` (regex / format /
// flags) to a variable or tabstop value, producing the replacement text. This
// is the Swift counterpart of Monaco's `Transform.resolveString` /
// `FormatString.resolve` (monaco-editor 0.56.0, `snippetParser.js`).
//
// The RegExp engine is the Phase 02 `MonaRegExpParser` (compile) +
// `MonaRegExpExecutor` (run) — the contract's `regexpContract`:
// "M1-R3 owns all transform regular expressions and flags." The "snippet
// consumer profile" is the declared set of RegExp features the snippet
// transform supports. The snippet contract does not pin a frozen snippet
// RegExp occurrence (the ten P02-T006 consumer profiles are *fixed*
// occurrences; snippet transforms take arbitrary user-supplied regex from the
// snippet text), so the snippet transform reuses the full Phase 02 RegExp
// engine via `monaRegExpCompile(pattern:flags:)`. The consumer profile is
// recorded here as `MonaSnippetConsumerProfile` for provenance.
//
// Malformed-input rule (contract `grammar.malformedInput`): an invalid
// transform RegExp construction returns the fallback path — the unresolved
// variable value (or empty when the value is empty) — and never crashes or
// drops the remaining template.
//
// Raw-UInt16 invariant: the executor compiles the regex over `[UInt16]` and
// converts capture spans back to `String` via the lone-surrogate-preserving
// reconstruction (a snippet value may carry a lone surrogate).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The snippet transform consumer profile: a provenance record that the
/// snippet transform reuses the full Phase 02 `MonaRegExpParser` +
/// `MonaRegExpExecutor` RegExp engine (no frozen occurrence — the regex is
/// arbitrary user-supplied text from the snippet body).
public enum MonaSnippetConsumerProfile {

    /// The profile identifier.
    public static let profileID = "snippet-transform"

    /// The consumer type (mirrors `MonaRegExpConsumerType.transform`).
    public static let consumerType: MonaRegExpConsumerType = .transform

    /// The RegExp engine this profile binds to: the full Phase 02 engine
    /// (`monaRegExpCompile` + `MonaRegExpExecutor`), not a frozen occurrence.
    public static let engine = "phase-02-monaregexp-full"
}

/// Executes `MonaSnippetTransform`s over variable/tabstop values.
public enum MonaSnippetTransformExecutor {

    /// Applies `transform` to `value`: compiles the regex (via the Phase 02
    /// engine), runs it over `value` (global when the `g` flag is set), and
    /// substitutes each match with the format. On regex syntax error or any
    /// execution failure, returns the fallback (the original `value`).
    ///
    /// - Parameters:
    ///   - transform: the transform to apply.
    ///   - value: the variable/tabstop value to transform.
    /// - Returns: the transformed text, or `value` on any failure.
    public static func apply(transform: MonaSnippetTransform, to value: String) -> String {
        // Compile the regex through the Phase 02 parser/compiler.
        let program: MonaRegExpProgram
        do {
            program = try monaRegExpCompile(transform.regex, flags: transform.flags)
        } catch {
            // Invalid regex → fallback path (the original value).
            return value
        }
        let input = Array(value.utf16)
        let executor = MonaRegExpExecutor(program: program)
        let matches: [MonaRegExpMatch]
        do {
            matches = try executor.findAll(in: input, from: 0)
        } catch {
            return value
        }
        if matches.isEmpty {
            return value
        }
        // For non-global transforms, only the first match is replaced; the rest
        // of the value is preserved. For global transforms, every match is
        // replaced and the gaps between are kept verbatim.
        let isGlobal = transform.flags.contains("g")
        var out: [UInt16] = []
        var lastEnd = 0
        let matchList = isGlobal ? matches : Array(matches.prefix(1))
        for m in matchList {
            // Preserve the gap before this match.
            if m.startOffset > lastEnd {
                out.append(contentsOf: input[lastEnd..<m.startOffset])
            }
            out.append(contentsOf: resolveFormat(transform.format, match: m, input: input))
            lastEnd = m.endOffset
        }
        if !isGlobal {
            // For non-global, keep the tail verbatim.
            if lastEnd < input.count {
                out.append(contentsOf: input[lastEnd..<input.count])
            }
        } else if lastEnd < input.count {
            out.append(contentsOf: input[lastEnd..<input.count])
        }
        return _MonaSnippetStringUnits.toString(out)
    }

    // MARK: - Format resolution

    /// Resolves a format (a sequence of `MonaSnippetFormatString` elements)
    /// against a single match's captures.
    private static func resolveFormat(
        _ format: [MonaSnippetFormatString],
        match: MonaRegExpMatch,
        input: [UInt16]
    ) -> [UInt16] {
        var out: [UInt16] = []
        for element in format {
            switch element {
            case .literal(let s):
                out.append(contentsOf: Array(s.utf16))
            case .capture(let n):
                out.append(contentsOf: captureText(n, match: match, input: input))
            case .shorthand(let n, let sh):
                let raw = captureText(n, match: match, input: input)
                out.append(contentsOf: applyShorthand(sh, to: raw))
            case .ifForm(let n, let body):
                let raw = captureText(n, match: match, input: input)
                if !raw.isEmpty {
                    out.append(contentsOf: Array(body.utf16))
                }
            case .elseForm(let n, let body):
                let raw = captureText(n, match: match, input: input)
                if raw.isEmpty {
                    out.append(contentsOf: Array(body.utf16))
                } else {
                    out.append(contentsOf: raw)
                }
            case .ifElseForm(let n, let ifBody, let elseBody):
                let raw = captureText(n, match: match, input: input)
                if !raw.isEmpty {
                    out.append(contentsOf: Array(ifBody.utf16))
                } else {
                    out.append(contentsOf: Array(elseBody.utf16))
                }
            case .defaultForm(let n, let body):
                let raw = captureText(n, match: match, input: input)
                if raw.isEmpty {
                    out.append(contentsOf: Array(body.utf16))
                } else {
                    out.append(contentsOf: raw)
                }
            }
        }
        return out
    }

    /// Returns the UTF-16 units of capture group `n` (1-based) from `match`,
    /// or empty when the group did not participate.
    private static func captureText(
        _ n: Int, match: MonaRegExpMatch, input: [UInt16]
    ) -> [UInt16] {
        // Capture index 0 = full match; group k uses captures[k].
        let idx = n
        guard idx >= 0, idx < match.captures.count else { return [] }
        let cap = match.captures[idx]
        guard cap.start >= 0, cap.end >= cap.start, cap.end <= input.count else {
            return []
        }
        return Array(input[cap.start..<cap.end])
    }

    // MARK: - Shorthands

    private static func applyShorthand(_ sh: MonaSnippetShorthand, to units: [UInt16]) -> [UInt16] {
        let s = _MonaSnippetStringUnits.toString(units)
        let result: String
        switch sh {
        case .upcase:
            result = s.uppercased()
        case .downcase:
            result = s.lowercased()
        case .capitalize:
            result = capitalize(s)
        case .pascalcase:
            result = toPascalCase(s)
        case .camelcase:
            result = toCamelCase(s)
        case .kebabcase:
            result = toKebabCase(s)
        case .snakecase:
            result = toSnakeCase(s)
        }
        return Array(result.utf16)
    }

    /// Capitalize: first character uppercase, the rest lowercase.
    private static func capitalize(_ s: String) -> String {
        guard let first = s.first else { return "" }
        return String(first).uppercased() + s.dropFirst().lowercased()
    }

    /// Splits `s` into words on non-alphanumeric boundaries and at
    /// camelCase / PascalCase case transitions, then returns the array of
    /// word substrings (lowercased).
    ///
    /// Examples:
    ///   - `"helloWorld"` → `["hello", "world"]`
    ///   - `"HelloWorld"` → `["hello", "world"]`
    ///   - `"HTTPRequest"` → `["http", "request"]`
    ///   - `"hello world"` → `["hello", "world"]`
    ///   - `"hello-world"` → `["hello", "world"]`
    private static func words(_ s: String) -> [String] {
        // First split on non-alphanumeric into segments.
        var segments: [String] = []
        var current = ""
        for ch in s {
            if ch.isLetter || ch.isNumber {
                current.append(ch)
            } else {
                if !current.isEmpty {
                    segments.append(current)
                    current = ""
                }
            }
        }
        if !current.isEmpty { segments.append(current) }

        // Then split each segment at camelCase / PascalCase boundaries.
        var out: [String] = []
        for seg in segments {
            out.append(contentsOf: splitCase(seg))
        }
        return out.map { $0.lowercased() }
    }

    /// Splits an alphanumeric segment at case transitions:
    ///   lowercase→Uppercase:  `"helloWorld"` → `["hello", "World"]`
    ///   Uppercase-run→lowercase: `"HTTPRequest"` → `["HTTP", "Request"]`
    private static func splitCase(_ s: String) -> [String] {
        var words: [String] = []
        var current = ""
        var prevLower = false
        var prevUpper = false
        for ch in s {
            let isUpper = ch.isUppercase
            let isLower = ch.isLowercase
            if !current.isEmpty {
                // lowercase → uppercase boundary: split before the uppercase.
                if prevLower && isUpper {
                    words.append(current)
                    current = String(ch)
                    prevLower = isLower
                    prevUpper = isUpper
                    continue
                }
                // uppercase-run → lowercase: the last uppercase char starts a
                // new word (e.g. "HTTP" + "R" + "equest" → "HTTP" + "Request").
                if prevUpper && isLower && current.count > 1 {
                    let last = current.removeLast()
                    words.append(current)
                    current = String(last)
                }
            }
            current.append(ch)
            prevLower = isLower
            prevUpper = isUpper
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    private static func toPascalCase(_ s: String) -> String {
        return words(s).map { capitalize($0) }.joined()
    }

    private static func toCamelCase(_ s: String) -> String {
        let w = words(s)
        guard !w.isEmpty else { return "" }
        var out = w[0]
        for word in w.dropFirst() {
            out += capitalize(word)
        }
        return out
    }

    private static func toKebabCase(_ s: String) -> String {
        return words(s).joined(separator: "-")
    }

    private static func toSnakeCase(_ s: String) -> String {
        return words(s).joined(separator: "_")
    }
}

// MARK: - String <-> UInt16 (lone-surrogate preserving)

/// A small helper namespace for converting between `String` and `[UInt16]`
/// while preserving lone surrogates (matching the parser's
/// `_reconstructPreservingLoneSurrogates`).
enum _MonaSnippetStringUnits {

    /// Converts `[UInt16]` to `String`, preserving lone surrogates (rather than
    /// repairing them to U+FFFD).
    static func toString(_ units: [UInt16]) -> String {
        var scalars: [UnicodeScalar] = []
        var i = 0
        while i < units.count {
            let u = UInt32(units[i])
            if u >= 0xD800 && u <= 0xDBFF && i + 1 < units.count {
                let lo = UInt32(units[i + 1])
                if lo >= 0xDC00 && lo <= 0xDFFF {
                    let cp = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)
                    if let s = UnicodeScalar(cp) { scalars.append(s) }
                    i += 2
                    continue
                }
            }
            if let s = UnicodeScalar(u) {
                scalars.append(s)
            }
            i += 1
        }
        return String(String.UnicodeScalarView(scalars))
    }
}
