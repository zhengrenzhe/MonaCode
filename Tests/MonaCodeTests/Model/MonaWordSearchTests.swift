// MonaWordSearchTests.swift
//
// P02-T003 — Implement word, grapheme, literal search, and replacement primitives.
//
// Verifies the four Phase-02 search primitives held in `Sources/MonaCode/Model/Search/`:
//
//   - `MonaWordClassifier`         — the frozen word-separator profile over raw
//                                    UTF-16 code units (Monaco's
//                                    `WordCharacterClassifier` / `wordHelper.ts`).
//   - `MonaGraphemeSegmenter`      — grapheme-cluster segmentation over raw
//                                    UTF-16 (surrogate pairs + combining marks).
//   - `MonaLiteralSearch`          — forward + backward literal search with
//                                    zero-length progression, match limits,
//                                    case-sensitive + case-insensitive modes.
//   - `MonaReplacePattern`         — replacement pattern with capture syntax
//                                    (`$1`..`$99`, `$&`, `$$`, `$<name>`).
//
// Test contract (P02-T003): word classifier (separators), grapheme segmenter,
// literal search (forward/backward/zero-length/match-limits/case), replace
// pattern (capture syntax).
//
// Case conversion is exercised only through the explicit `MonaCaseConverter`
// provider (stub here); full Unicode case tables arrive in P02-T007. RegExp is
// not exercised here (P02-T004).
//
// MonaCode is a Foundation-only target; tests import XCTest + MonaCode.

import XCTest
import MonaCode

final class MonaWordSearchTests: XCTestCase {

    // MARK: - Helpers

    /// Converts a Swift `String` to its raw UTF-16 code units.
    private func units(_ s: String) -> [UInt16] {
        return Array(s.utf16)
    }

    // MARK: - 1. MonaWordClassifier

    /// Monaco's default word-separator profile (`USUAL_WORD_SEPARATORS`) marks
    /// ASCII punctuation as word separators: backtick, `!`, `@`, `#`, `$`, `%`,
    /// `^`, `&`, `*`, `(`, `)`, `-`, `=`, `+`, `[`, `{`, `]`, `}`, `\`, `|`,
    /// `;`, `:`, `'`, `"`, `,`, `.`, `<`, `>`, `/`, `?`. Each of these code
    /// units classifies as a separator.
    func testWordClassifierDefaultSeparatorsClassifyPunctuation() {
        let c = MonaWordClassifier()
        // `~!@#$%^&*()-=+[{]}\|;:'",.<>/?
        let separators = "`~!@#$%^&*()-=+[{]}\\|;:'\",.<>/?"
        for scalar in separators.unicodeScalars {
            XCTAssertTrue(c.isWordSeparator(UInt16(scalar.value)),
                "0x\(String(UInt16(scalar.value), radix: 16)) should be a word separator")
        }
    }

    /// ASCII letters (a-z, A-Z), digits (0-9), and underscore are word
    /// characters — not separators.
    func testWordClassifierLettersDigitsUnderscoreAreNonSeparators() {
        let c = MonaWordClassifier()
        for scalar in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".unicodeScalars {
            XCTAssertFalse(c.isWordSeparator(UInt16(scalar.value)),
                "0x\(String(UInt16(scalar.value), radix: 16)) should NOT be a word separator")
        }
    }

    /// Monaco's `WordCharacterClassifier` keeps whitespace in its own class —
    /// whitespace is NOT a `WordSeparator`. `isWordSeparator` returns false for
    /// space, tab, and line feed; `isWhitespace` returns true.
    func testWordClassifierWhitespaceIsNotAWordSeparator() {
        let c = MonaWordClassifier()
        XCTAssertFalse(c.isWordSeparator(0x0020), "space is not a word separator")
        XCTAssertFalse(c.isWordSeparator(0x0009), "tab is not a word separator")
        XCTAssertFalse(c.isWordSeparator(0x000A), "line feed is not a word separator")
        XCTAssertTrue(c.isWhitespace(0x0020))
        XCTAssertTrue(c.isWhitespace(0x0009))
        XCTAssertTrue(c.isWhitespace(0x000A))
    }

    /// `wordClass` returns the three-way classification matching Monaco's
    /// `WordCharClassification`: `.other` for word characters, `.wordSeparator`
    /// for the configured separators, `.whitespace` for whitespace.
    func testWordClassifierThreeWayClassification() {
        let c = MonaWordClassifier()
        XCTAssertEqual(c.wordClass(0x0061), .other, "'a' is a word character (other)")
        XCTAssertEqual(c.wordClass(0x005A), .other, "'Z' is a word character (other)")
        XCTAssertEqual(c.wordClass(0x0030), .other, "'0' is a word character (other)")
        XCTAssertEqual(c.wordClass(0x005F), .other, "'_' is a word character (other)")
        XCTAssertEqual(c.wordClass(0x002E), .wordSeparator, "'.' is a word separator")
        XCTAssertEqual(c.wordClass(0x002D), .wordSeparator, "'-' is a word separator")
        XCTAssertEqual(c.wordClass(0x0040), .wordSeparator, "'@' is a word separator")
        XCTAssertEqual(c.wordClass(0x0020), .whitespace, "space is whitespace")
        XCTAssertEqual(c.wordClass(0x000A), .whitespace, "newline is whitespace")
    }

    /// A custom separator set overrides the default: `.` is a separator, but `!`
    /// (not in the custom set) is not.
    func testWordClassifierCustomSeparatorSet() {
        let c = MonaWordClassifier(separators: [0x002E])  // only "."
        XCTAssertTrue(c.isWordSeparator(0x002E), "'.' is a separator in the custom set")
        XCTAssertFalse(c.isWordSeparator(0x0021), "'!' is NOT a separator in the custom set")
    }

    /// Non-ASCII code units (e.g. U+00E9 é, a high surrogate) are not in the
    /// default separator profile and classify as `.other` (word characters).
    func testWordClassifierNonASCIIIsOtherByDefault() {
        let c = MonaWordClassifier()
        XCTAssertEqual(c.wordClass(0x00E9), .other, "é is not a separator by default")
        XCTAssertFalse(c.isWordSeparator(0x00E9))
        // A lone high surrogate (not 0x000A, not in separator set) is `.other`.
        XCTAssertEqual(c.wordClass(0xD83D), .other)
    }

    // MARK: - 2. MonaGraphemeSegmenter

    /// `graphemeLength` counts grapheme clusters: ASCII text has one grapheme
    /// per code unit.
    func testGraphemeLengthASCII() {
        XCTAssertEqual(MonaGraphemeSegmenter.graphemeLength(units("hello")), 5)
        XCTAssertEqual(MonaGraphemeSegmenter.graphemeLength(units("")), 0)
        XCTAssertEqual(MonaGraphemeSegmenter.graphemeLength(units("a")), 1)
    }

    /// A surrogate pair (e.g. U+1F600 grinning face = [0xD83D, 0xDE00]) is one
    /// grapheme cluster even though it is two UTF-16 code units.
    func testGraphemeLengthSurrogatePairIsOneGrapheme() {
        let emoji = units("\u{1F600}")
        XCTAssertEqual(emoji.count, 2, "sanity: emoji is two UTF-16 code units")
        XCTAssertEqual(MonaGraphemeSegmenter.graphemeLength(emoji), 1)
    }

    /// Two emoji (two surrogate pairs) are two grapheme clusters.
    func testGraphemeLengthTwoEmojiAreTwoGraphemes() {
        let two = units("\u{1F600}\u{1F600}")
        XCTAssertEqual(two.count, 4)
        XCTAssertEqual(MonaGraphemeSegmenter.graphemeLength(two), 2)
    }

    /// A combining mark clusters with its base: 'e' (U+0065) + combining acute
    /// accent (U+0301) is one grapheme cluster.
    func testGraphemeLengthCombiningMarkClustersWithBase() {
        let eAcute: [UInt16] = [0x0065, 0x0301]
        XCTAssertEqual(MonaGraphemeSegmenter.graphemeLength(eAcute), 1)
    }

    /// Mixed ASCII + surrogate pairs + combining marks segment correctly.
    /// "café" where é = e + combining → [c, a, f, e, combining] = 4 graphemes.
    func testGraphemeLengthMixedContent() {
        let cafe: [UInt16] = [0x0063, 0x0061, 0x0066, 0x0065, 0x0301]
        XCTAssertEqual(MonaGraphemeSegmenter.graphemeLength(cafe), 4)
        // "a" + emoji + "b" = 3 graphemes, 4 code units.
        let mixed: [UInt16] = [0x0061, 0xD83D, 0xDE00, 0x0062]
        XCTAssertEqual(MonaGraphemeSegmenter.graphemeLength(mixed), 3)
    }

    /// `nextBoundary(after:)` returns the UTF-16 offset of the next grapheme
    /// boundary strictly after `from`, enabling forward grapheme iteration.
    func testGraphemeNextBoundary() {
        let cafe: [UInt16] = [0x0063, 0x0061, 0x0066, 0x0065, 0x0301]
        // boundaries at 0 (c), 1 (a), 2 (f), 3 (é = e+combining), 5 (end)
        XCTAssertEqual(MonaGraphemeSegmenter.nextBoundary(after: 0, in: cafe), 1)
        XCTAssertEqual(MonaGraphemeSegmenter.nextBoundary(after: 3, in: cafe), 5, "skips the combining mark")
        XCTAssertEqual(MonaGraphemeSegmenter.nextBoundary(after: 5, in: cafe), 5, "clamps at end")
    }

    /// `previousBoundary(before:)` returns the UTF-16 offset of the grapheme
    /// boundary at or before `from`, enabling backward grapheme iteration.
    func testGraphemePreviousBoundary() {
        let cafe: [UInt16] = [0x0063, 0x0061, 0x0066, 0x0065, 0x0301]
        XCTAssertEqual(MonaGraphemeSegmenter.previousBoundary(before: 5, in: cafe), 3, "lands on the é cluster start")
        XCTAssertEqual(MonaGraphemeSegmenter.previousBoundary(before: 3, in: cafe), 2)
        XCTAssertEqual(MonaGraphemeSegmenter.previousBoundary(before: 0, in: cafe), 0, "clamps at start")
    }

    // MARK: - 3. MonaLiteralSearch

    /// Forward literal search finds the first occurrence at or after the
    /// starting offset, returning a match with start offset and length (in
    /// UTF-16 code units).
    func testForwardLiteralSearchFindsMatches() {
        let hay = units("xab ab ab")
        let search = MonaLiteralSearch(needle: units("ab"), matchCase: true)
        XCTAssertEqual(search.findNext(in: hay, fromOffset: 0),
            MonaSearchMatch(startOffset: 1, length: 2))
        XCTAssertEqual(search.findNext(in: hay, fromOffset: 1),
            MonaSearchMatch(startOffset: 1, length: 2))
        XCTAssertEqual(search.findNext(in: hay, fromOffset: 2),
            MonaSearchMatch(startOffset: 4, length: 2))
        XCTAssertEqual(search.findNext(in: hay, fromOffset: 6),
            MonaSearchMatch(startOffset: 7, length: 2))
    }

    /// Forward search returns nil when there is no match at or after the
    /// offset, and when the needle is longer than the haystack.
    func testForwardLiteralSearchNoMatch() {
        let hay = units("xab ab ab")
        let search = MonaLiteralSearch(needle: units("ab"), matchCase: true)
        XCTAssertNil(search.findNext(in: hay, fromOffset: 8))
        let longSearch = MonaLiteralSearch(needle: units("abcd"), matchCase: true)
        XCTAssertNil(longSearch.findNext(in: hay, fromOffset: 0))
    }

    /// Backward literal search returns the match with the greatest start offset
    /// strictly less than the given offset, enabling reverse cycling.
    func testBackwardLiteralSearchFindsMatches() {
        let hay = units("xab ab ab")
        let search = MonaLiteralSearch(needle: units("ab"), matchCase: true)
        XCTAssertEqual(search.findPrevious(in: hay, fromOffset: 9),
            MonaSearchMatch(startOffset: 7, length: 2))
        XCTAssertEqual(search.findPrevious(in: hay, fromOffset: 7),
            MonaSearchMatch(startOffset: 4, length: 2))
        XCTAssertEqual(search.findPrevious(in: hay, fromOffset: 4),
            MonaSearchMatch(startOffset: 1, length: 2))
        XCTAssertNil(search.findPrevious(in: hay, fromOffset: 1))
    }

    /// A zero-length needle must not cause `findAll` to loop forever: each
    /// zero-length match progresses the cursor by one code unit.
    func testZeroLengthNeedleProgressesAndDoesNotLoop() {
        let hay = units("abc")
        let search = MonaLiteralSearch(needle: [], matchCase: true)
        let matches = search.findAll(in: hay, fromOffset: 0, limit: 10)
        // Zero-length matches at offsets 0, 1, 2, 3 (4 positions); limit 10 is
        // not hit, so progression terminated on its own after the end.
        XCTAssertEqual(matches.count, 4)
        XCTAssertEqual(matches[0], MonaSearchMatch(startOffset: 0, length: 0))
        XCTAssertEqual(matches[3], MonaSearchMatch(startOffset: 3, length: 0))
    }

    /// `findAll` respects the match limit and stops collecting once the limit
    /// is reached.
    func testFindAllRespectsMatchLimit() {
        let hay = units("ab ab ab ab ab")
        let search = MonaLiteralSearch(needle: units("ab"), matchCase: true)
        let matches = search.findAll(in: hay, fromOffset: 0, limit: 2)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0], MonaSearchMatch(startOffset: 0, length: 2))
        XCTAssertEqual(matches[1], MonaSearchMatch(startOffset: 3, length: 2))
    }

    /// `findAll` with a non-zero-length needle progresses past each match's end
    /// so adjacent occurrences are all found.
    func testFindAllFindsAllOccurrences() {
        let hay = units("ababab")
        let search = MonaLiteralSearch(needle: units("ab"), matchCase: true)
        let matches = search.findAll(in: hay, fromOffset: 0, limit: 100)
        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0], MonaSearchMatch(startOffset: 0, length: 2))
        XCTAssertEqual(matches[1], MonaSearchMatch(startOffset: 2, length: 2))
        XCTAssertEqual(matches[2], MonaSearchMatch(startOffset: 4, length: 2))
    }

    /// Case-sensitive mode (the default) only matches exact-case occurrences.
    func testCaseSensitiveSearch() {
        let hay = units("ab Ab ab")
        let search = MonaLiteralSearch(needle: units("Ab"), matchCase: true)
        XCTAssertEqual(search.findNext(in: hay, fromOffset: 0),
            MonaSearchMatch(startOffset: 3, length: 2))
        XCTAssertEqual(search.findAll(in: hay, fromOffset: 0, limit: 100).count, 1)
    }

    /// Case-insensitive mode matches across ASCII case differences using the
    /// injected `MonaCaseConverter` provider (the stub folds A-Z to a-z).
    func testCaseInsensitiveSearchFoldsASCII() {
        let hay = units("ab Ab aB AB")
        let search = MonaLiteralSearch(needle: units("ab"), matchCase: false)
        let matches = search.findAll(in: hay, fromOffset: 0, limit: 100)
        XCTAssertEqual(matches.count, 4)
        XCTAssertEqual(matches[0], MonaSearchMatch(startOffset: 0, length: 2))
        XCTAssertEqual(matches[1], MonaSearchMatch(startOffset: 3, length: 2))
        XCTAssertEqual(matches[2], MonaSearchMatch(startOffset: 6, length: 2))
        XCTAssertEqual(matches[3], MonaSearchMatch(startOffset: 9, length: 2))
    }

    /// Case-insensitive search leaves non-ASCII code units untouched (the stub
    /// converter only folds ASCII A-Z), so é does not match É.
    func testCaseInsensitiveStubLeavesNonASCIIUntouched() {
        let hay = units("café CAFÉ")
        let search = MonaLiteralSearch(needle: units("café"), matchCase: false)
        // 'C'/'c' fold, but 'É'/'é' do not (stub is ASCII-only), so only the
        // lowercase occurrence matches.
        let matches = search.findAll(in: hay, fromOffset: 0, limit: 100)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0], MonaSearchMatch(startOffset: 0, length: 4))
    }

    // MARK: - 4. MonaReplacePattern

    /// A pattern with no capture syntax yields itself verbatim.
    func testReplacePatternLiteral() {
        let p = MonaReplacePattern(units("XYZ"))
        let out = p.apply(.init(fullMatch: units("hi")))
        XCTAssertEqual(out, units("XYZ"))
    }

    /// `$1` and `$2` substitute the first and second numbered captures.
    func testReplacePatternNumberedCaptures() {
        let p = MonaReplacePattern(units("$1-$2"))
        let out = p.apply(.init(
            fullMatch: units("full"),
            captures: [units("foo"), units("bar")]
        ))
        XCTAssertEqual(out, units("foo-bar"))
    }

    /// `$&` substitutes the full match text.
    func testReplacePatternFullMatchAmpersand() {
        let p = MonaReplacePattern(units("[$&]"))
        let out = p.apply(.init(fullMatch: units("hi"), captures: []))
        XCTAssertEqual(out, units("[hi]"))
    }

    /// `$$` is the escape for a literal `$`.
    func testReplacePatternDollarDollarIsLiteralDollar() {
        let p = MonaReplacePattern(units("$$1"))
        let out = p.apply(.init(fullMatch: units("m"), captures: [units("X")]))
        // `$$` → `$`, then `1` is a literal "1" (not a capture, since the `$`
        // was consumed by `$$`). Result: "$1".
        XCTAssertEqual(out, units("$1"))
    }

    /// A capture reference beyond the number of groups is left as a literal
    /// `$n` (matching ECMAScript `String.prototype.replace` semantics).
    func testReplacePatternCaptureBeyondGroupsIsLiteral() {
        let p = MonaReplacePattern(units("[$3]"))
        let out = p.apply(.init(fullMatch: units("m"), captures: [units("a"), units("b")]))
        XCTAssertEqual(out, units("[$3]"))
    }

    /// A group that exists but did not participate (empty capture) substitutes
    /// the empty string.
    func testReplacePatternEmptyCaptureIsEmpty() {
        let p = MonaReplacePattern(units("[$2]"))
        let out = p.apply(.init(fullMatch: units("m"), captures: [units("a"), []]))
        XCTAssertEqual(out, units("[]"))
    }

    /// Two-digit `$10`: with fewer than 10 groups, falls back to capture 1
    /// followed by a literal "0".
    func testReplacePatternTwoDigitFallback() {
        let p = MonaReplacePattern(units("$10"))
        let out = p.apply(.init(fullMatch: units("m"), captures: [units("a")]))
        XCTAssertEqual(out, units("a0"))
    }

    /// Two-digit `$10`: with 10 or more groups, substitutes the 10th capture.
    func testReplacePatternTwoDigitTenthCapture() {
        let p = MonaReplacePattern(units("$10"))
        var captures: [[UInt16]] = []
        for i in 1...10 {
            captures.append(units("g\(i)"))
        }
        let out = p.apply(.init(fullMatch: units("m"), captures: captures))
        XCTAssertEqual(out, units("g10"))
    }

    /// `$<name>` substitutes a named capture; an absent name substitutes empty.
    func testReplacePatternNamedCapture() {
        let p = MonaReplacePattern(units("$<foo>"))
        let present = p.apply(.init(
            fullMatch: units("m"),
            captures: [],
            namedCaptures: ["foo": units("BAR")]
        ))
        XCTAssertEqual(present, units("BAR"))
        let absent = p.apply(.init(fullMatch: units("m"), captures: []))
        XCTAssertEqual(absent, units(""))
    }

    /// A combined pattern with literals, numbered captures, and the full match
    /// substitutes every token in order.
    func testReplacePatternCombined() {
        let p = MonaReplacePattern(units("pre-$1-mid-$&-suf-$2-end"))
        let out = p.apply(.init(
            fullMatch: units("MATCH"),
            captures: [units("A"), units("B")]
        ))
        XCTAssertEqual(out, units("pre-A-mid-MATCH-suf-B-end"))
    }

    /// An empty replacement pattern produces an empty result.
    func testReplacePatternEmpty() {
        let p = MonaReplacePattern(units(""))
        let out = p.apply(.init(fullMatch: units("m"), captures: [units("a")]))
        XCTAssertEqual(out, units(""))
    }

    /// A `$` with no following token (trailing `$`) is treated as a literal `$`.
    func testReplacePatternTrailingDollarIsLiteral() {
        let p = MonaReplacePattern(units("cost$"))
        let out = p.apply(.init(fullMatch: units("m"), captures: []))
        XCTAssertEqual(out, units("cost$"))
    }
}
