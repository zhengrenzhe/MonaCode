// MonaLiteralSearch.swift
//
// P02-T003 — Implement word, grapheme, literal search, and replacement primitives.
//
// `MonaLiteralSearch` performs forward and backward literal (non-RegExp) search
// over raw UTF-16 code units — the Swift counterpart of Monaco's
// `TextModelSearch` literal path (monaco-editor 0.56.0,
// `vs/editor/common/model/textModelSearch.ts`). It is the search primitive the
// Phase-02 find/replace model operations build on; RegExp search arrives
// separately in P02-T004 and is deliberately not used here.
//
// Frozen profile (M1-R model, raw UTF-16):
//
//   - The needle and haystack are raw `[UInt16]`. A lone surrogate in either is
//     compared code-unit-wise and never repaired.
//   - Forward search (`findNext`) returns the match with the smallest start
//     offset `>= fromOffset`. Backward search (`findPrevious`) returns the
//     match with the greatest start offset strictly `< fromOffset`.
//   - Zero-length progression: a zero-length needle produces zero-length
//     matches at every offset `0...haystack.count`. `findAll` advances the
//     cursor by one code unit after a zero-length match so the search
//     terminates instead of looping forever (matching Monaco's
//     `_findMatchesInRange` zero-length advancement).
//   - Match limits: `findAll` stops once it has collected `limit` matches.
//   - Case conversion is NOT implemented inline. Case-insensitive matching
//     uses the explicit `MonaCaseConverter` provider (`MonaCaseConverterStub`
//     here, an ASCII-only A-Z→a-z folder). Full Unicode case folding arrives
//     in P02-T007, which supplies a real converter conforming to the same
//     protocol — the search code does not change.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A literal-search match: a start offset and a length, both in UTF-16 code
/// units, over a `[UInt16]` haystack.
public struct MonaSearchMatch: Equatable, Hashable {

    /// The UTF-16 code-unit offset in the haystack where the match begins.
    public let startOffset: Int

    /// The length of the match in UTF-16 code units. A zero-length needle
    /// yields matches of length 0.
    public let length: Int

    /// The UTF-16 code-unit offset one past the end of the match.
    public var endOffset: Int { startOffset + length }

    /// Creates a match.
    public init(startOffset: Int, length: Int) {
        self.startOffset = startOffset
        self.length = length
    }
}

/// The Phase-02 case-conversion provider.
///
/// `MonaLiteralSearch` uses this to fold code units for case-insensitive
/// matching. The stub (`MonaCaseConverterStub`) folds only ASCII A-Z → a-z;
/// the full Unicode case tables are generated in P02-T007 and supplied as a
/// conforming converter — the search code does not change.
public protocol MonaCaseConverter {

    /// Returns the case-folded form of `codeUnit` used for case-insensitive
    /// comparison. For ASCII A-Z this is the corresponding a-z; for all other
    /// code units it is the unit itself under the stub.
    func foldCase(_ codeUnit: UInt16) -> UInt16
}

/// An ASCII-only case-conversion stub.
///
/// Folds ASCII A-Z (0x0041..0x005A) to a-z (0x0061..0x007A) by adding 0x0020.
/// Every other code unit — including non-ASCII and surrogates — is returned
/// unchanged. This is the Phase-02 placeholder; P02-T007 replaces it with a
/// converter backed by the frozen Chromium ICU case tables.
public struct MonaCaseConverterStub: MonaCaseConverter, Equatable {

    /// Creates the stub.
    public init() {}

    public func foldCase(_ codeUnit: UInt16) -> UInt16 {
        if codeUnit >= 0x0041 && codeUnit <= 0x005A {
            return codeUnit + 0x0020
        }
        return codeUnit
    }
}

/// A literal (non-RegExp) search over raw UTF-16 code units.
///
/// Construct with a needle and a case-sensitivity flag (and, for
/// case-insensitive search, an optional `MonaCaseConverter`). Use `findNext`,
/// `findPrevious`, and `findAll` to locate matches.
public struct MonaLiteralSearch {

    /// The needle code units.
    public let needle: [UInt16]

    /// `true` for case-sensitive matching (the default); `false` for
    /// case-insensitive.
    public let matchCase: Bool

    /// The case converter used when `matchCase` is `false`. `nil` when
    /// case-sensitive (no folding is applied).
    public let caseConverter: MonaCaseConverter?

    /// Creates a literal search.
    ///
    /// - Parameters:
    ///   - needle: the needle code units.
    ///   - matchCase: `true` (default) for case-sensitive; `false` for
    ///     case-insensitive.
    ///   - caseConverter: the converter for case-insensitive mode. When
    ///     `matchCase` is `false` and `caseConverter` is `nil`, the
    ///     `MonaCaseConverterStub` is used. Ignored when `matchCase` is `true`.
    public init(needle: [UInt16], matchCase: Bool = true, caseConverter: MonaCaseConverter? = nil) {
        self.needle = needle
        self.matchCase = matchCase
        if matchCase {
            self.caseConverter = nil
        } else {
            self.caseConverter = caseConverter ?? MonaCaseConverterStub()
        }
    }

    /// Returns the first match with start offset `>= fromOffset`, or `nil` if
    /// none exists.
    public func findNext(in haystack: [UInt16], fromOffset: Int = 0) -> MonaSearchMatch? {
        let L = needle.count
        if L == 0 {
            // Zero-length needle matches at every offset 0...haystack.count.
            let start = fromOffset < 0 ? 0 : fromOffset
            if start <= haystack.count {
                return MonaSearchMatch(startOffset: start, length: 0)
            }
            return nil
        }
        let upper = haystack.count - L
        var p = fromOffset < 0 ? 0 : fromOffset
        while p <= upper {
            if matches(at: p, in: haystack) {
                return MonaSearchMatch(startOffset: p, length: L)
            }
            p += 1
        }
        return nil
    }

    /// Returns the match with the greatest start offset strictly less than
    /// `fromOffset`, or `nil` if none exists.
    public func findPrevious(in haystack: [UInt16], fromOffset: Int) -> MonaSearchMatch? {
        let L = needle.count
        if L == 0 {
            if fromOffset <= 0 {
                return nil
            }
            let p = min(fromOffset - 1, haystack.count)
            if p >= 0 {
                return MonaSearchMatch(startOffset: p, length: 0)
            }
            return nil
        }
        let upper = min(fromOffset - 1, haystack.count - L)
        var p = upper
        while p >= 0 {
            if matches(at: p, in: haystack) {
                return MonaSearchMatch(startOffset: p, length: L)
            }
            p -= 1
        }
        return nil
    }

    /// Returns all matches with start offset `>= fromOffset`, up to `limit`
    /// matches.
    ///
    /// Zero-length matches progress the cursor by one code unit so the search
    /// never loops forever; non-zero-length matches advance to the match end.
    public func findAll(in haystack: [UInt16], fromOffset: Int = 0, limit: Int = Int.max) -> [MonaSearchMatch] {
        var results: [MonaSearchMatch] = []
        var pos = fromOffset < 0 ? 0 : fromOffset
        while results.count < limit {
            guard let m = findNext(in: haystack, fromOffset: pos) else {
                break
            }
            results.append(m)
            if m.length == 0 {
                pos = m.startOffset + 1
                if pos > haystack.count {
                    break
                }
            } else {
                pos = m.endOffset
            }
        }
        return results
    }

    // MARK: - Internals

    /// Returns `true` if the needle matches `haystack` at `offset`.
    private func matches(at offset: Int, in haystack: [UInt16]) -> Bool {
        let L = needle.count
        if L == 0 {
            return true
        }
        if offset + L > haystack.count {
            return false
        }
        if matchCase {
            for k in 0..<L {
                if needle[k] != haystack[offset + k] {
                    return false
                }
            }
            return true
        }
        guard let conv = caseConverter else {
            // Unreachable: caseConverter is non-nil when matchCase is false.
            return false
        }
        for k in 0..<L {
            if conv.foldCase(needle[k]) != conv.foldCase(haystack[offset + k]) {
                return false
            }
        }
        return true
    }
}
