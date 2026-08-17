// MonaURI.swift
//
// P01-T003 — Implement cache-observable Monaco URI semantics.
//
// `MonaURI` is the base-model URI reference type. It stores the five canonical
// Monaco components — `scheme`, `authority`, `path`, `query`, `fragment` — as
// the canonical truth, mirroring Monaco's `URI` (monaco-editor 0.56.0,
// vendored from vscode's `vs/base/common/uri.ts`). It is a `final class`
// (reference type) so that the lazily-computed `toString`/`fsPath`/`toJSON`
// cache is shared across all references to one instance and is *observable*
// through `toJSON`, matching Monaco's cache-observable behavior: after
// `fsPath`/`toString` run, `toJSON` additionally carries the cached
// `external` (the formatted string), `fsPath`, and `_sep` fields.
//
// Parsing uses the frozen Monaco comparator regex:
//
//     ^(([^:/?#]+?):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?
//       12             3  4          5       6   7      8 9
//
// scheme=2, authority=4, path=5, query=7, fragment=9. In non-strict mode (the
// only mode `parse` exposes) a missing scheme defaults to `file`, matching
// Monaco's `URI.parse(value, /* _strict */ false)`.
//
// The percent-decoder is the graceful port of Monaco's
// `decodeURIComponentGraceful`: it never throws. If the string contains any
// incomplete or malformed percent run (e.g. `%` at end, `%GG`), the entire
// string is returned verbatim — a malformed triplet poisons the whole run, so
// valid triplets before it are not partially decoded. This matches Monaco,
// where `decodeURIComponent` throws on any malformed sequence and the graceful
// wrapper falls back to the original.
//
// `format` (the operation behind `toString`) rejects lone UTF-16 surrogates
// with the typed `MonaURIError.loneSurrogate`, mirroring Monaco's
// `encodeURIComponent` raising `URIError` on a lone surrogate. The rejection
// inspects each component's UTF-16 code units.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Errors raised by `MonaURI` format operations.
public enum MonaURIError: Error, Equatable {

    /// A URI component contained a lone UTF-16 surrogate (a high surrogate not
    /// followed by a low surrogate, or a low surrogate not preceded by a
    /// high surrogate). A lone surrogate cannot be percent-encoded into valid
    /// UTF-8, so `format`/`toString` reject it.
    case loneSurrogate
}

/// The filesystem separator recorded alongside `fsPath`, matching Monaco's
/// `Separator` enum (`Posix = 1`, `Windows = 2`). MonaCode targets macOS, so
/// the recorded separator is always `.posix`.
public enum MonaURISeparator: Int {
    case posix = 1
    case windows = 2
}

/// The cache-observable JSON projection of a `MonaURI`, returned by `toJSON()`.
///
/// The five component fields are always present. The `external`, `fsPath`, and
/// `sep` fields are `nil` until the corresponding accessor (`toString` or
/// `fsPath`) has run on the owning instance; once populated they reflect the
/// cached values. This makes the `toString`/`fsPath` cache observable through
/// `toJSON`, matching Monaco's `toJSON` shape (`external`/`fsPath`/`_sep`).
public struct MonaURIJSON: Equatable {

    public var scheme: String
    public var authority: String
    public var path: String
    public var query: String
    public var fragment: String

    /// The cached `toString()` result (`external` in Monaco's JSON). `nil`
    /// until `toString()` has run.
    public var external: String?

    /// The cached `fsPath`. `nil` until `fsPath` has been read.
    public var fsPath: String?

    /// The separator recorded with `fsPath` (`_sep` in Monaco's JSON). `nil`
    /// until `fsPath` has been read.
    public var sep: Int?
}

/// A cache-observable Monaco URI.
///
/// `MonaURI` is a reference type: the lazily-computed `toString`/`fsPath`
/// results are cached on the instance and shared across all references, and
/// `toJSON` reports the cache state. Parse with `parse(_:)`; construct directly
/// with `init(scheme:authority:path:query:fragment:)`.
public final class MonaURI {

    // MARK: - Components (canonical truth)

    public let scheme: String
    public let authority: String
    public let path: String
    public let query: String
    public let fragment: String

    // MARK: - Cache storage (cache-observable, lock-protected)

    private let _lock = NSLock()
    private var _cachedString: String?
    private var _cachedFsPath: String?
    private var _cachedSep: Int?

    /// Number of times `toString` actually computed (cache misses). Internal
    /// — exposed for cache-observable invariant tests.
    internal private(set) var _stringComputeCount: Int = 0

    /// Number of times `fsPath` actually computed (cache misses). Internal —
    /// exposed for cache-observable invariant tests.
    internal private(set) var _fsPathComputeCount: Int = 0

    /// Creates a URI from its canonical components.
    public init(
        scheme: String,
        authority: String = "",
        path: String = "",
        query: String = "",
        fragment: String = ""
    ) {
        self.scheme = scheme
        self.authority = authority
        self.path = path
        self.query = query
        self.fragment = fragment
    }

    // MARK: - Parse

    /// The frozen Monaco comparator regex. Capture groups (1-based):
    /// 1=`scheme:`, 2=scheme, 3=`//authority`, 4=authority, 5=path,
    /// 6=`?query`, 7=query, 8=`#fragment`, 9=fragment.
    private static let parseRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: "^(([^:/?#]+?):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?",
            options: []
        )
    }()

    /// Parses `string` into a `MonaURI` using the frozen Monaco comparator
    /// regex. Returns `nil` for an empty input. In non-strict mode a missing
    /// scheme defaults to `file`; for `file`/`http`/`https` the path is rooted
    /// with a leading `/`.
    public static func parse(_ string: String) -> MonaURI? {
        guard !string.isEmpty else { return nil }

        let nsRange = NSRange(string.startIndex..., in: string)
        guard
            let match = parseRegex.firstMatch(in: string, options: [], range: nsRange)
        else {
            return nil
        }

        func component(_ group: Int) -> String {
            let range = match.range(at: group)
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: string)
            else {
                return ""
            }
            return String(string[swiftRange])
        }

        var scheme = component(2)
        let authority = component(4)
        var path = component(5)
        let query = component(7)
        let fragment = component(9)

        if scheme.isEmpty {
            // Non-strict: a missing scheme defaults to `file`.
            scheme = "file"
        }

        // For file/http/https, Monaco roots the path with a leading slash.
        if scheme == "file" || scheme == "http" || scheme == "https" {
            if path.isEmpty {
                path = "/"
            } else if !path.hasPrefix("/") {
                path = "/" + path
            }
        }

        return MonaURI(
            scheme: scheme,
            authority: authority,
            path: path,
            query: query,
            fragment: fragment
        )
    }

    // MARK: - Format (cache-observable; throws on lone surrogate)

    /// Formats the URI as a string, caching the result. Throws
    /// `MonaURIError.loneSurrogate` if any component contains a lone UTF-16
    /// surrogate. The cached value is reused on subsequent calls and is
    /// observable through `toJSON` as `external`.
    public func toString() throws -> String {
        _lock.lock(); defer { _lock.unlock() }
        if let cached = _cachedString {
            return cached
        }
        _stringComputeCount += 1
        let formatted = try MonaURI.format(
            scheme: scheme,
            authority: authority,
            path: path,
            query: query,
            fragment: fragment
        )
        _cachedString = formatted
        return formatted
    }

    // MARK: - fsPath (cache-observable; graceful decode)

    /// The filesystem path, caching the result. The path is percent-decoded
    /// with the graceful decoder (which never throws). The cached value and
    /// its separator are observable through `toJSON` as `fsPath` and `_sep`.
    public var fsPath: String {
        _lock.lock(); defer { _lock.unlock() }
        if let cached = _cachedFsPath {
            return cached
        }
        _fsPathComputeCount += 1
        let computed: String
        if scheme == "file" || scheme == "http" || scheme == "https" || scheme == "untitled" {
            computed = MonaURI.percentDecodeGraceful(path)
        } else {
            computed = path
        }
        _cachedFsPath = computed
        _cachedSep = MonaURISeparator.posix.rawValue
        return computed
    }

    // MARK: - toJSON (cache-observable projection)

    /// Returns the cache-observable JSON projection of this URI. The five
    /// components are always present; `external`, `fsPath`, and `sep` reflect
    /// whether `toString`/`fsPath` have populated the cache.
    public func toJSON() -> MonaURIJSON {
        _lock.lock(); defer { _lock.unlock() }
        return MonaURIJSON(
            scheme: scheme,
            authority: authority,
            path: path,
            query: query,
            fragment: fragment,
            external: _cachedString,
            fsPath: _cachedFsPath,
            sep: _cachedSep
        )
    }

    // MARK: - Lone-surrogate rejection

    /// Throws `MonaURIError.loneSurrogate` if `codeUnits` contains a lone
    /// surrogate (a high surrogate not followed by a low surrogate, or a low
    /// surrogate not preceded by a high surrogate). This is the rejection
    /// seam `format` invokes on each component's UTF-16 code units.
    ///
    /// Internal — the public rejection surface is `toString()`/`format`.
    internal static func _throwIfLoneSurrogate(in codeUnits: [UInt16]) throws {
        if let error = detectLoneSurrogate(in: codeUnits) {
            throw error
        }
    }

    /// Returns `.loneSurrogate` if `codeUnits` contains a lone surrogate, else
    /// `nil`. A valid surrogate pair (high followed by low) is not rejected.
    private static func detectLoneSurrogate(in codeUnits: [UInt16]) -> MonaURIError? {
        var i = 0
        while i < codeUnits.count {
            let unit = Int(codeUnits[i])
            if (0xD800...0xDBFF).contains(unit) {
                // High surrogate must be followed by a low surrogate.
                let next = i + 1 < codeUnits.count ? Int(codeUnits[i + 1]) : -1
                if !(0xDC00...0xDFFF).contains(next) {
                    return .loneSurrogate
                }
                i += 2
            } else if (0xDC00...0xDFFF).contains(unit) {
                // Low surrogate not preceded by a high surrogate.
                return .loneSurrogate
            } else {
                i += 1
            }
        }
        return nil
    }

    // MARK: - Graceful percent-decoder

    /// Percent-decodes `value` using the graceful decoder. Valid `%XX`
    /// sequences are decoded. If the string contains any incomplete or
    /// malformed percent run (e.g. `%` at end, `%GG`), the original string is
    /// returned verbatim — never an error. A malformed triplet anywhere in the
    /// string poisons the whole run: valid triplets before it are not
    /// partially decoded.
    public static func percentDecodeGraceful(_ value: String) -> String {
        // Fast path: no percent sign means nothing to decode.
        guard value.contains("%") else { return value }

        // If any percent-run is incomplete or malformed, the decode fails
        // gracefully and the original string is preserved verbatim.
        guard allPercentRunsValid(value) else { return value }

        // All percent-runs are valid hex; decode. If Foundation cannot form a
        // valid Unicode string from the decoded bytes (e.g. invalid UTF-8),
        // fall back to the original string.
        return value.removingPercentEncoding ?? value
    }

    /// Returns `true` iff every `%` in `value` is followed by exactly two
    /// hexadecimal digits (a complete, well-formed percent run).
    private static func allPercentRunsValid(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        var i = 0
        while i < bytes.count {
            if bytes[i] == 0x25 { // '%'
                guard i + 2 < bytes.count,
                      isHexDigit(bytes[i + 1]),
                      isHexDigit(bytes[i + 2])
                else {
                    return false
                }
                i += 3
            } else {
                i += 1
            }
        }
        return true
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x30...0x39, 0x41...0x46, 0x61...0x66: // 0-9, A-F, a-f
            return true
        default:
            return false
        }
    }

    // MARK: - Format (private)

    /// Formats the components into a URI string, mirroring Monaco's `_format`.
    /// Throws `MonaURIError.loneSurrogate` if any component contains a lone
    /// surrogate.
    private static func format(
        scheme: String,
        authority: String,
        path: String,
        query: String,
        fragment: String
    ) throws -> String {
        // Reject lone surrogates in every component before encoding.
        try _throwIfLoneSurrogate(in: Array(scheme.utf16))
        try _throwIfLoneSurrogate(in: Array(authority.utf16))
        try _throwIfLoneSurrogate(in: Array(path.utf16))
        try _throwIfLoneSurrogate(in: Array(query.utf16))
        try _throwIfLoneSurrogate(in: Array(fragment.utf16))

        var result = ""
        if !scheme.isEmpty {
            result += scheme
            result += ":"
        }
        // Emit `//` when there is an authority, or always for the file scheme
        // (matching Monaco's `_format`).
        if !authority.isEmpty || scheme == "file" {
            result += "//"
            if !authority.isEmpty {
                result += encodeAuthority(authority)
            }
        }
        result += encodePath(path)
        if !query.isEmpty {
            result += "?"
            result += encodeSegment(query, allow: Self.queryAllow)
        }
        if !fragment.isEmpty {
            result += "#"
            result += encodeSegment(fragment, allow: Self.fragmentAllow)
        }
        return result
    }

    // MARK: - Component encoders (private)

    private static let pathAllow: Set<UInt8> = subDelims.union([0x2F, 0x3A, 0x40]) // / : @
    private static let queryAllow: Set<UInt8> = subDelims.union([0x2F, 0x3A, 0x40, 0x3F]) // / : @ ?
    private static let fragmentAllow: Set<UInt8> = subDelims.union([0x2F, 0x3A, 0x40, 0x3F])
    private static let authoritySegmentAllow: Set<UInt8> =
        subDelims.union([0x3A, 0x40, 0x5B, 0x5D]) // : @ [ ]

    private static let subDelims: Set<UInt8> = [
        0x21, 0x24, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x3B, 0x3D, // ! $ & ' ( ) * + , ; =
    ]

    /// Encodes the authority: splits `userinfo@host:port`, lowercases the host,
    /// and percent-encodes userinfo/port. Existing valid `%XX` sequences are
    /// preserved verbatim (no double-encoding).
    private static func encodeAuthority(_ authority: String) -> String {
        if let at = authority.lastIndex(of: "@") {
            let userinfo = String(authority[..<at])
            let hostport = String(authority[authority.index(after: at)...])
            let (host, port) = splitHostPort(hostport)
            var result = encodeSegment(userinfo, allow: authoritySegmentAllow)
            result += "@"
            result += host.lowercased()
            if !port.isEmpty {
                result += ":"
                result += encodeSegment(port, allow: authoritySegmentAllow)
            }
            return result
        } else {
            let (host, port) = splitHostPort(authority)
            var result = host.lowercased()
            if !port.isEmpty {
                result += ":"
                result += encodeSegment(port, allow: authoritySegmentAllow)
            }
            return result
        }
    }

    /// Splits `host:port` into `(host, port)`. IPv6 literals in brackets are
    /// treated as the host (the colon inside `[]` is not a port separator).
    private static func splitHostPort(_ hostport: String) -> (host: String, port: String) {
        if hostport.hasPrefix("[") {
            // IPv6 literal: [addr]:port
            if let close = hostport.firstIndex(of: "]") {
                let host = String(hostport[...close])
                let after = hostport.index(after: close)
                if after < hostport.endIndex, hostport[after] == ":" {
                    return (host, String(hostport[hostport.index(after: after)...]))
                }
                return (host, "")
            }
            return (hostport, "")
        }
        if let colon = hostport.lastIndex(of: ":") {
            return (String(hostport[..<colon]), String(hostport[hostport.index(after: colon)...]))
        }
        return (hostport, "")
    }

    /// Encodes the path component, lowercasing a leading drive letter (e.g.
    /// `/C:/` → `/c:/`). Existing valid `%XX` sequences are preserved.
    private static func encodePath(_ path: String) -> String {
        let bytes = Array(path.utf8)
        // Drive-letter lowercasing: `/<letter>:` → `/<letter-lower>:`.
        if bytes.count >= 3,
           bytes[0] == 0x2F, // '/'
           isAsciiAlpha(bytes[1]),
           bytes[2] == 0x3A // ':'
        {
            var lowered = bytes
            lowered[1] = asciiLowercase(lowered[1])
            return encodeBytes(lowered, allow: pathAllow)
        }
        return encodeBytes(bytes, allow: pathAllow)
    }

    /// Encodes a component, preserving existing valid `%XX` sequences and
    /// leaving unreserved characters and `allow`ed bytes verbatim.
    private static func encodeSegment(_ value: String, allow: Set<UInt8>) -> String {
        encodeBytes(Array(value.utf8), allow: allow)
    }

    private static func encodeBytes(_ bytes: [UInt8], allow: Set<UInt8>) -> String {
        var result = ""
        var i = 0
        while i < bytes.count {
            let byte = bytes[i]
            if byte == 0x25, // '%'
               i + 2 < bytes.count,
               isHexDigit(bytes[i + 1]),
               isHexDigit(bytes[i + 2])
            {
                // Existing valid percent-sequence: preserve verbatim.
                result.append(Character(UnicodeScalar(byte)))
                result.append(Character(UnicodeScalar(bytes[i + 1])))
                result.append(Character(UnicodeScalar(bytes[i + 2])))
                i += 3
            } else if isUnreserved(byte) || allow.contains(byte) {
                result.append(Character(UnicodeScalar(byte)))
                i += 1
            } else {
                result.append(String(format: "%%%02X", byte))
                i += 1
            }
        }
        return result
    }

    private static func isUnreserved(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, // 0-9 A-Z a-z
             0x2D, 0x2E, 0x5F, 0x7E:                 // - . _ ~
            return true
        default:
            return false
        }
    }

    private static func isAsciiAlpha(_ byte: UInt8) -> Bool {
        return (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
    }

    private static func asciiLowercase(_ byte: UInt8) -> UInt8 {
        if (0x41...0x5A).contains(byte) {
            return byte + 0x20
        }
        return byte
    }
}
