// MonaJSONValue.swift
//
// P06-T003 — Implement deterministic JSON-RPC wire values and errors.
//
// `MonaJSONValue` is the JSON value tree carried by JSON-RPC messages:
// object, array, string, number, bool, null. It is the Swift counterpart of
// the value representation that Monaco's JSON-RPC reader/writer
// (monaco-editor 0.56.0, vendored from vscode's JSON-RPC stack) decodes
// message bodies into and encodes them from.
//
// Two L2-R3-frozen properties make this tree the canonical MonaCode JSON
// representation:
//
//   1. Type preservation WITHOUT coercion. A JSON number is stored as either
//      `.integer` or `.decimal` depending on whether the literal had a `.`
//      or exponent. This lets the JSON-RPC `id` field (integer | string |
//      null) be preserved exactly — a string id `"5"` never becomes integer
//      `5`, and an integer `5` never becomes `"5"`. A `null` is `.null`, not
//      a coerced empty value.
//
//   2. Canonical byte representation. Objects are stored in raw UTF-16
//      lexicographic key order with duplicate keys resolved last-value-wins
//      (matching the fixed JS oracle). Numbers spell integers without
//      leading zeros or a trailing `.0`, and decimals via the shortest
//      round-trip binary64 spelling. Strings escape `"`, `\`, and the
//      control characters per the L2-R3 encoder table, leaving `/`,
//      U+2028, and U+2029 unescaped. The serialized bytes are therefore
//      reproducible — identical values always produce identical bytes, so
//      fixture hashes are stable.
//
// `MonaJSONValue` is a value type (an `enum`): it is a pure, copyable,
// identity-free tree. Objects store an `Array<(String, MonaJSONValue)>`
// normalized to canonical (sorted, deduped) form at construction, so two
// trees representing the same JSON compare equal regardless of the input
// key order.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A JSON number, stored in a way that preserves the integer/decimal
/// distinction for canonical spelling. A literal without a `.` or exponent
/// parses to `.integer`; a literal with one parses to `.decimal`.
public enum MonaJSONNumber: Equatable, Hashable {

    /// An integer literal (no `.`, no exponent). Spelled canonically as
    /// decimal digits with no leading zeros and no trailing `.0`.
    case integer(Int64)

    /// A decimal literal (has `.` and/or an exponent). Spelled canonically
    /// via the shortest round-trip binary64 representation.
    case decimal(Double)
}

/// A JSON value tree — object, array, string, number, bool, or null.
///
/// Objects are stored in canonical form: keys in raw UTF-16 lexicographic
/// order, duplicates resolved last-value-wins. Construction (both the public
/// initializers and the decoder) normalizes to this form, so equality is
/// order-independent for objects and the canonical serialization is
/// reproducible.
public enum MonaJSONValue: Equatable {

    /// JSON `null`.
    case null

    /// JSON `true` / `false`.
    case bool(Bool)

    /// A JSON number, preserving integer-vs-decimal spelling.
    case number(MonaJSONNumber)

    /// A JSON string.
    case string(String)

    /// A JSON array, in source order.
    case array([MonaJSONValue])

    /// A JSON object, stored in canonical (UTF-16-lexicographic, deduped)
    /// key order. Construct via `MonaJSONValue.object(_:)`, which normalizes.
    case object([(key: String, value: MonaJSONValue)])

    // MARK: - Convenience constructors

    /// Convenience for integer literals.
    public static func integer(_ value: Int64) -> MonaJSONValue {
        return .number(.integer(value))
    }

    /// Convenience for decimal literals.
    public static func decimal(_ value: Double) -> MonaJSONValue {
        return .number(.decimal(value))
    }

    // MARK: - Parsing

    /// Parses `data` (UTF-8 JSON bytes) into a `MonaJSONValue`.
    ///
    /// Returns `.failure(.parseError)` if the bytes are not valid UTF-8 or
    /// not well-formed JSON. Duplicate object keys resolve to the last value
    /// (matching the fixed JS oracle). Objects are stored in canonical key
    /// order.
    public static func parse(
        _ data: Data
    ) -> Result<MonaJSONValue, MonaJSONRPCError> {
        guard let source = String(data: data, encoding: .utf8) else {
            return .failure(.parseError)
        }
        var parser = _MonaJSONParser(source: source)
        parser.skipWhitespace()
        guard let value = parser.parseValue() else {
            return .failure(.parseError)
        }
        parser.skipWhitespace()
        guard parser.isAtEnd else {
            return .failure(.parseError)
        }
        return .success(value)
    }

    // MARK: - Canonical serialization

    /// Serializes this value to canonical UTF-8 JSON bytes.
    ///
    /// Objects emit keys in stored (UTF-16-lexicographic) order. Integers
    /// spell without leading zeros or a trailing `.0`; decimals spell via
    /// the shortest round-trip binary64 form. Returns
    /// `.failure(.numberNotRepresentable)` if a `.decimal` holds `NaN` or
    /// infinity (L2-R3: NaN/Infinity are rejected, never coerced to `null`).
    public func encode() -> Result<Data, MonaJSONRPCError> {
        var sink = _MonaJSONEncodeSink()
        switch _MonaJSONEncoder.encode(self, into: &sink) {
        case .failure(let err):
            return .failure(err)
        case .success:
            return .success(Data(sink.bytes))
        }
    }

    // MARK: - Private

    /// `true` iff `a` precedes `b` in raw UTF-16 code-unit lexicographic
    /// order (the L2-R3 canonical object-key order, matching the fixed JS
    /// oracle's `Array.prototype.sort` default).
    static func utf16Less(_ a: String, _ b: String) -> Bool {
        let aUnits = Array(a.utf16)
        let bUnits = Array(b.utf16)
        let limit = Swift.min(aUnits.count, bUnits.count)
        for i in 0..<limit {
            if aUnits[i] != bUnits[i] {
                return aUnits[i] < bUnits[i]
            }
        }
        return aUnits.count < bUnits.count
    }

    // MARK: - Equatable

    /// Manual equality. Objects compare as order-independent maps with
    /// duplicate keys resolved last-value-wins, so a constructed (unsorted)
    /// object compares equal to its decoded (canonical) form regardless of
    /// stored key order.
    public static func == (
        lhs: MonaJSONValue, rhs: MonaJSONValue
    ) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let a), .bool(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.string(let a), .string(let b)): return a == b
        case (.array(let a), .array(let b)): return a == b
        case (.object(let a), .object(let b)):
            // Build last-value-wins maps from both sides and compare.
            let mapA = MonaJSONValue.asMap(a)
            let mapB = MonaJSONValue.asMap(b)
            return mapA == mapB
        default: return false
        }
    }

    /// Reduces `pairs` to a last-value-wins `[String: MonaJSONValue]` map.
    private static func asMap(
        _ pairs: [(key: String, value: MonaJSONValue)]
    ) -> [String: MonaJSONValue] {
        var map: [String: MonaJSONValue] = [:]
        for entry in pairs {
            map[entry.key] = entry.value
        }
        return map
    }
}

// MARK: - JSON Parser

/// A recursive-descent JSON parser that produces `MonaJSONValue`.
///
/// Objects normalize to canonical key order (sorted + deduped) at parse
/// time. Numbers are classified as integer (no `.`/exponent, fits `Int64`)
/// or decimal (everything else). Returns `nil` on any grammar violation;
/// callers surface this as `.parseError`.
struct _MonaJSONParser {

    private let source: [Character]
    private(set) var index: Int = 0

    init(source: String) {
        self.source = Array(source)
    }

    var isAtEnd: Bool { return index >= source.count }

    mutating func skipWhitespace() {
        while index < source.count {
            let c = source[index]
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                index += 1
            } else {
                return
            }
        }
    }

    mutating func parseValue() -> MonaJSONValue? {
        skipWhitespace()
        guard index < source.count else { return nil }
        let c = source[index]
        switch c {
        case "{": return parseObject()
        case "[": return parseArray()
        case "\"":
            if let s = parseString() { return .string(s) }
            return nil
        case "t", "f": return parseBool()
        case "n": return parseNull()
        case "-", "0"..."9": return parseNumber()
        default: return nil
        }
    }

    private mutating func parseObject() -> MonaJSONValue? {
        // Consume '{'.
        index += 1
        var pairs: [(key: String, value: MonaJSONValue)] = []
        skipWhitespace()
        if index < source.count && source[index] == "}" {
            index += 1
            return .object(pairs)
        }
        while true {
            skipWhitespace()
            guard index < source.count, source[index] == "\"" else {
                return nil
            }
            guard let key = parseString() else { return nil }
            skipWhitespace()
            guard index < source.count, source[index] == ":" else {
                return nil
            }
            index += 1  // consume ':'
            guard let value = parseValue() else { return nil }
            pairs.append((key: key, value: value))
            skipWhitespace()
            guard index < source.count else { return nil }
            if source[index] == "," {
                index += 1
                continue
            } else if source[index] == "}" {
                index += 1
                return .object(pairs)
            } else {
                return nil
            }
        }
    }

    private mutating func parseArray() -> MonaJSONValue? {
        // Consume '['.
        index += 1
        var values: [MonaJSONValue] = []
        skipWhitespace()
        if index < source.count && source[index] == "]" {
            index += 1
            return .array(values)
        }
        while true {
            guard let value = parseValue() else { return nil }
            values.append(value)
            skipWhitespace()
            guard index < source.count else { return nil }
            if source[index] == "," {
                index += 1
                continue
            } else if source[index] == "]" {
                index += 1
                return .array(values)
            } else {
                return nil
            }
        }
    }

    mutating func parseString() -> String? {
        // Assumes current char is '"'. Consume it.
        index += 1
        var result = String()
        while index < source.count {
            let c = source[index]
            if c == "\"" {
                index += 1
                return result
            } else if c == "\\" {
                index += 1
                guard index < source.count else { return nil }
                let esc = source[index]
                switch esc {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "u":
                    // 4 hex digits.
                    let hexStart = index + 1
                    guard hexStart + 4 <= source.count else { return nil }
                    let hex = String(source[hexStart..<(hexStart + 4)])
                    guard let code = UInt32(hex, radix: 16) else {
                        return nil
                    }
                    // Surrogate pair: a high surrogate (0xD800-0xDBFF)
                    // immediately followed by a `\u` low-surrogate
                    // escape combines into a single scalar. Isolated
                    // surrogates that don't form a pair are dropped (Swift's
                    // String cannot hold a lone surrogate; the L2-R3 inbound
                    // rule is best-effort here).
                    if code >= 0xD800 && code <= 0xDBFF,
                       hexStart + 4 + 6 <= source.count,
                       source[hexStart + 4] == "\\",
                       source[hexStart + 5] == "u" {
                        let secondHex = String(
                            source[(hexStart + 6)..<(hexStart + 10)])
                        if let low = UInt32(secondHex, radix: 16),
                           low >= 0xDC00 && low <= 0xDFFF {
                            let combined = 0x10000
                                + ((code - 0xD800) << 10)
                                + (low - 0xDC00)
                            if let s = Unicode.Scalar(combined) {
                                result.append(Character(s))
                            }
                            // Consume both `\uXXXX` escapes (10 chars);
                            // -1 because the trailing `index += 1` follows.
                            index = hexStart + 10 - 1
                            break
                        }
                    }
                    if let s = Unicode.Scalar(code) {
                        result.append(Character(s))
                    }
                    // Consume the 4 hex digits; -1 because the trailing
                    // `index += 1` follows.
                    index = hexStart + 4 - 1
                default:
                    return nil
                }
                index += 1
            } else if c.asciiValue != nil && c.asciiValue! < 0x20 {
                // Unescaped control character — invalid JSON.
                return nil
            } else {
                result.append(c)
                index += 1
            }
        }
        return nil  // unterminated string
    }

    private mutating func parseBool() -> MonaJSONValue? {
        if matchKeyword("true") { return .bool(true) }
        if matchKeyword("false") { return .bool(false) }
        return nil
    }

    private mutating func parseNull() -> MonaJSONValue? {
        if matchKeyword("null") { return .null }
        return nil
    }

    private mutating func parseNumber() -> MonaJSONValue? {
        let start = index
        var isDecimal = false
        if index < source.count && source[index] == "-" {
            index += 1
        }
        // Integer part.
        guard index < source.count, source[index].isASCII && source[index].isNumber else {
            return nil
        }
        if source[index] == "0" {
            index += 1
        } else if source[index] >= "1" && source[index] <= "9" {
            while index < source.count && source[index].isASCII
                    && source[index].isNumber {
                index += 1
            }
        } else {
            return nil
        }
        // Fraction.
        if index < source.count && source[index] == "." {
            isDecimal = true
            index += 1
            guard index < source.count, source[index].isASCII,
                  source[index].isNumber else { return nil }
            while index < source.count && source[index].isASCII
                    && source[index].isNumber {
                index += 1
            }
        }
        // Exponent.
        if index < source.count && (source[index] == "e" || source[index] == "E") {
            isDecimal = true
            index += 1
            if index < source.count && (source[index] == "+" || source[index] == "-") {
                index += 1
            }
            guard index < source.count, source[index].isASCII,
                  source[index].isNumber else { return nil }
            while index < source.count && source[index].isASCII
                    && source[index].isNumber {
                index += 1
            }
        }
        let literal = String(source[start..<index])
        if !isDecimal {
            if let intValue = Int64(literal) {
                return .number(.integer(intValue))
            }
            // Integer too large for Int64 — fall back to decimal if
            // representable, else parse error.
            if let dbl = Double(literal) {
                return .number(.decimal(dbl))
            }
            return nil
        }
        if let dbl = Double(literal) {
            return .number(.decimal(dbl))
        }
        return nil
    }

    private mutating func matchKeyword(_ keyword: String) -> Bool {
        let keyChars = Array(keyword)
        guard index + keyChars.count <= source.count else { return false }
        for (offset, ch) in keyChars.enumerated() {
            if source[index + offset] != ch { return false }
        }
        index += keyChars.count
        return true
    }
}

// MARK: - JSON Encoder

/// A byte sink for canonical JSON serialization.
struct _MonaJSONEncodeSink {
    var bytes: [UInt8] = []
    mutating func append(_ s: String) {
        bytes.append(contentsOf: s.utf8)
    }
}

/// The canonical JSON encoder for `MonaJSONValue`.
enum _MonaJSONEncoder {

    static func encode(
        _ value: MonaJSONValue, into sink: inout _MonaJSONEncodeSink
    ) -> Result<Void, MonaJSONRPCError> {
        switch value {
        case .null:
            sink.append("null")
            return .success(())
        case .bool(let b):
            sink.append(b ? "true" : "false")
            return .success(())
        case .number(let n):
            return encodeNumber(n, into: &sink)
        case .string(let s):
            encodeString(s, into: &sink)
            return .success(())
        case .array(let values):
            sink.append("[")
            for (i, v) in values.enumerated() {
                if i > 0 { sink.append(",") }
                switch encode(v, into: &sink) {
                case .success: break
                case .failure(let err): return .failure(err)
                }
            }
            sink.append("]")
            return .success(())
        case .object(let pairs):
            // Canonicalize at emit time: dedup (last value wins) and sort
            // keys by raw UTF-16 lexicographic order. This makes the
            // serialized bytes reproducible regardless of stored order.
            var map: [String: MonaJSONValue] = [:]
            for entry in pairs {
                map[entry.key] = entry.value
            }
            let sortedKeys = map.keys.sorted(by: MonaJSONValue.utf16Less)
            sink.append("{")
            for (i, key) in sortedKeys.enumerated() {
                if i > 0 { sink.append(",") }
                encodeString(key, into: &sink)
                sink.append(":")
                switch encode(map[key]!, into: &sink) {
                case .success: break
                case .failure(let err): return .failure(err)
                }
            }
            sink.append("}")
            return .success(())
        }
    }

    static func encodeNumber(
        _ n: MonaJSONNumber, into sink: inout _MonaJSONEncodeSink
    ) -> Result<Void, MonaJSONRPCError> {
        switch n {
        case .integer(let i):
            // `String(Int64)` yields decimal digits with no leading zeros
            // and no trailing `.0`. Int64 cannot hold -0, so `-0` is
            // spelled `0`.
            sink.append(String(i))
            return .success(())
        case .decimal(let d):
            if d.isNaN || d.isInfinite {
                // L2-R3: NaN/Infinity are rejected, not coerced to `null`.
                return .failure(.numberNotRepresentable)
            }
            // Swift's `String(Double)` uses the shortest round-trip
            // binary64 spelling (Ryu-like), matching the L2-R3 rule.
            sink.append(String(d))
            return .success(())
        }
    }

    static func encodeString(_ s: String, into sink: inout _MonaJSONEncodeSink) {
        sink.append("\"")
        for scalar in s.unicodeScalars {
            let v = scalar.value
            switch v {
            case 0x22:  // "
                sink.append("\\\"")
            case 0x5C:  // backslash
                sink.append("\\\\")
            case 0x08:  // backspace
                sink.append("\\b")
            case 0x09:  // tab
                sink.append("\\t")
            case 0x0A:  // line feed
                sink.append("\\n")
            case 0x0C:  // form feed
                sink.append("\\f")
            case 0x0D:  // carriage return
                sink.append("\\r")
            default:
                if v < 0x20 {
                    // Other control characters: \u00xx with lowercase hex.
                    let hex = String(v, radix: 16)
                    let padded = String(repeating: "0", count: max(0, 4 - hex.count))
                    sink.append("\\u")
                    sink.append(padded)
                    sink.append(hex)
                } else {
                    // All other scalars (including `/`, U+2028, U+2029)
                    // pass through unescaped per the L2-R3 encoder table.
                    sink.append(String(scalar))
                }
            }
        }
        sink.append("\"")
    }
}
