// MonaURITests.swift
//
// P01-T003 — Implement cache-observable Monaco URI semantics.
//
// Verifies:
//   - `MonaURI.parse` splits scheme/authority/path/query/fragment per the
//     frozen Monaco comparator regex; a missing scheme defaults to `file`
//     (non-strict).
//   - The graceful percent-decoder fails gracefully on incomplete or malformed
//     percent runs (e.g. `%` at end, `%GG`): the original string is returned
//     verbatim, never an error. A malformed triplet anywhere in a run poisons
//     the whole run, so valid triplets before it are not partially decoded.
//   - `toString`, `fsPath`, and `toJSON` are cache-observable on a reference
//     type: `toJSON` reports no cached `external`/`fsPath`/`_sep` until the
//     corresponding accessor runs, then reflects the cached values; the
//     accessors compute exactly once per instance.
//   - `format` rejects lone UTF-16 surrogates with the typed
//     `MonaURIError.loneSurrogate`.
//
// Note on lone surrogates: Swift `String` normalizes lone surrogates to
// U+FFFD on construction (every Foundation entry point — `UnicodeScalar`
// failable init, `String(utf16CodeUnits:count:)`, NSString/CFString bridging,
// `String(bytes:encoding:)` — replaces or rejects them). A Swift `String`
// therefore cannot hold a lone surrogate. The format path delegates lone-
// surrogate rejection to `_throwIfLoneSurrogate(in:)`, which inspects the
// UTF-16 code units of each component — the same units format encodes. The
// rejection is verified at that seam, with surrogate code-unit sequences,
// which is the level at which Monaco's `encodeURIComponent` raises URIError.

import XCTest
@testable import MonaCode

final class MonaURITests: XCTestCase {

    // MARK: - Parse: scheme/authority/path/query/fragment

    func testParsesSchemeAuthorityPathQueryFragment() throws {
        let uri = try XCTUnwrap(MonaURI.parse("http://user@example.com:8080/path/to/file?q=1&b=2#frag"))

        XCTAssertEqual(uri.scheme, "http")
        XCTAssertEqual(uri.authority, "user@example.com:8080")
        XCTAssertEqual(uri.path, "/path/to/file")
        XCTAssertEqual(uri.query, "q=1&b=2")
        XCTAssertEqual(uri.fragment, "frag")
    }

    func testParseExtractsFileUriComponents() throws {
        let uri = try XCTUnwrap(MonaURI.parse("file:///Users/foo/bar.txt"))

        XCTAssertEqual(uri.scheme, "file")
        XCTAssertEqual(uri.authority, "")
        XCTAssertEqual(uri.path, "/Users/foo/bar.txt")
        XCTAssertEqual(uri.query, "")
        XCTAssertEqual(uri.fragment, "")
    }

    func testParseDefaultsMissingSchemeToFileNonStrict() throws {
        // Non-strict parse: a string with no scheme defaults to the file scheme.
        let uri = try XCTUnwrap(MonaURI.parse("/Users/foo/bar.txt"))

        XCTAssertEqual(uri.scheme, "file")
        XCTAssertEqual(uri.path, "/Users/foo/bar.txt")
    }

    func testParseReturnsNilForEmptyInput() {
        XCTAssertNil(MonaURI.parse(""))
    }

    func testParseRoundTripsViaToString() throws {
        let original = "http://example.com/path?q=1#frag"
        let uri = try XCTUnwrap(MonaURI.parse(original))

        XCTAssertEqual(try uri.toString(), original)
    }

    // MARK: - Percent decoder: graceful failure on incomplete/malformed runs

    func testPercentDecoderFailsGracefullyOnIncompletePercentRun() {
        // A trailing `%` with no following hex digits is an incomplete run.
        // The graceful decoder returns the original string verbatim — never
        // throws, never returns nil.
        XCTAssertEqual(MonaURI.percentDecodeGraceful("abc%"), "abc%")
        XCTAssertEqual(MonaURI.percentDecodeGraceful("abc%4"), "abc%4")
        XCTAssertEqual(MonaURI.percentDecodeGraceful("%"), "%")
    }

    func testPercentDecoderPreservesMalformedTriplet() {
        // `%GG` is not a valid hex triplet; the whole string is preserved.
        XCTAssertEqual(MonaURI.percentDecodeGraceful("%GG"), "%GG")
    }

    func testPercentDecoderPreservesEntireRunWhenAnyTripletIsMalformed() {
        // A valid UTF-8 sequence followed by a malformed triplet: the entire
        // string is preserved verbatim (the bad triplet poisons the run, so
        // the valid triplets before it are not partially decoded).
        XCTAssertEqual(
            MonaURI.percentDecodeGraceful("%F0%9F%92%A9%GG"),
            "%F0%9F%92%A9%GG"
        )
    }

    func testPercentDecoderDecodesValidTriplet() {
        XCTAssertEqual(MonaURI.percentDecodeGraceful("%41"), "A")
        XCTAssertEqual(MonaURI.percentDecodeGraceful("%41%42"), "AB")
        XCTAssertEqual(MonaURI.percentDecodeGraceful("/Users/%66oo"), "/Users/foo")
        // A valid UTF-8 percent-sequence decodes to the scalar.
        XCTAssertEqual(MonaURI.percentDecodeGraceful("%F0%9F%92%A9"), "\u{1F4A9}")
    }

    func testPercentDecoderLeavesStringsWithoutPercentUnchanged() {
        XCTAssertEqual(MonaURI.percentDecodeGraceful("plain text"), "plain text")
        XCTAssertEqual(MonaURI.percentDecodeGraceful("/Users/foo/bar.txt"), "/Users/foo/bar.txt")
    }

    // MARK: - Cache-observable toString / fsPath / toJSON

    func testToJSONReportsNoCacheBeforeFormatCalls() {
        let uri = MonaURI(scheme: "file", path: "/Users/foo/bar.txt")
        let json = uri.toJSON()

        XCTAssertEqual(json.scheme, "file")
        XCTAssertEqual(json.path, "/Users/foo/bar.txt")
        // Before any toString/fsPath call, the cache is empty.
        XCTAssertNil(json.external)
        XCTAssertNil(json.fsPath)
        XCTAssertNil(json.sep)
    }

    func testToStringCachesResultObservableViaToJSON() throws {
        let uri = MonaURI(scheme: "file", path: "/Users/foo/bar.txt")
        let formatted = try uri.toString()

        // After toString, toJSON reflects the cached external string.
        let json = uri.toJSON()
        XCTAssertEqual(json.external, formatted)

        // toString computes exactly once: subsequent calls reuse the cache.
        _ = try uri.toString()
        _ = try uri.toString()
        XCTAssertEqual(uri._stringComputeCount, 1)
    }

    func testFsPathCachesResultObservableViaToJSON() {
        let uri = MonaURI(scheme: "file", path: "/Users/foo/bar.txt")
        let path = uri.fsPath

        XCTAssertEqual(path, "/Users/foo/bar.txt")

        let json = uri.toJSON()
        XCTAssertEqual(json.fsPath, path)
        XCTAssertEqual(json.sep, MonaURISeparator.posix.rawValue)

        // fsPath computes exactly once.
        _ = uri.fsPath
        _ = uri.fsPath
        XCTAssertEqual(uri._fsPathComputeCount, 1)
    }

    func testFsPathDecodesPercentEncodedPath() {
        let uri = MonaURI(scheme: "file", path: "/Users/%66oo/bar.txt")
        XCTAssertEqual(uri.fsPath, "/Users/foo/bar.txt")
    }

    func testToJSONCarriesFullCacheAfterBothAccessorsRun() throws {
        // After both toString and fsPath have run, toJSON carries the full
        // cache (external + fsPath + _sep). This is the cache-observable shape.
        let uri = MonaURI(
            scheme: "http",
            authority: "example.com",
            path: "/path",
            query: "q=1",
            fragment: "frag"
        )
        let formatted = try uri.toString()
        let path = uri.fsPath

        let json = uri.toJSON()
        XCTAssertEqual(json.external, formatted)
        XCTAssertEqual(json.fsPath, path)
        XCTAssertEqual(json.sep, MonaURISeparator.posix.rawValue)
        XCTAssertEqual(json.scheme, "http")
        XCTAssertEqual(json.authority, "example.com")
        XCTAssertEqual(json.path, "/path")
        XCTAssertEqual(json.query, "q=1")
        XCTAssertEqual(json.fragment, "frag")
    }

    // MARK: - Lone-surrogate rejection with typed error

    func testFormatRejectsLoneSurrogateWithTypedError() {
        // format delegates lone-surrogate rejection to _throwIfLoneSurrogate,
        // inspecting the UTF-16 code units of each component. A lone high
        // surrogate (not followed by a low surrogate) is rejected with the
        // typed MonaURIError.loneSurrogate.
        XCTAssertThrowsError(try MonaURI._throwIfLoneSurrogate(in: [0xD800])) { error in
            XCTAssertEqual(error as? MonaURIError, .loneSurrogate)
        }
        // A lone low surrogate (not preceded by a high surrogate) is rejected.
        XCTAssertThrowsError(try MonaURI._throwIfLoneSurrogate(in: [0x0041, 0xDC00])) { error in
            XCTAssertEqual(error as? MonaURIError, .loneSurrogate)
        }
        // A valid surrogate pair (U+10000) is not rejected.
        XCTAssertNoThrow(try MonaURI._throwIfLoneSurrogate(in: [0xD800, 0xDC00]))
        // Plain ASCII is not rejected.
        XCTAssertNoThrow(try MonaURI._throwIfLoneSurrogate(in: Array("hello".utf16)))

        // toString() is the throwing format operation; a well-formed URI
        // formats without error (no false rejection of valid components).
        let uri = MonaURI(scheme: "http", authority: "example.com", path: "/path")
        XCTAssertNoThrow(try uri.toString())
    }
}
