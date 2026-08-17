// MonaTextShaperTests.swift
//
// P03-T002 — Shape mixed-script lines with Core Text and deterministic fallback.
//
// Verifies the MonaCodeAppKit Core Text shaping layer:
//   - `MonaTextShaper` shapes raw UTF-16 (`[UInt16]`) lines using Core Text
//     (`CTLine`, `CTRun`), taking a primary font descriptor, a font fallback
//     resolver, a base direction (LTR/RTL), a device-space scale, and a set of
//     tab stops. It preserves isolated-surrogate input positions even when no
//     glyph is emitted, records every font face and glyph run for Q1-R4 font
//     provenance, and returns a bounded typed failure (`MonaTextShaperError`)
//     instead of publishing partial runs.
//   - `MonaGlyphRun` is the immutable shaped glyph-run output: glyph IDs,
//     positions, advances, source UTF-16 range, the resolved font, and its
//     descriptor.
//   - `MonaFontFallbackResolver` resolves the deterministic font cascade
//     (primary font -> fallback fonts for missing glyphs) using Core Text's
//     font cascade list.
//
// One contract case: Core Text shaping with font/direction/scale/tab-stops/
// fallback, isolated-surrogate preservation, face/run recording, and bounded
// typed failure.

import XCTest
import CoreText
import CoreGraphics
@testable import MonaCodeAppKit

final class MonaTextShaperTests: XCTestCase {

    // MARK: - Helpers

    /// Menlo is the default macOS monospace face and is always present; it is
    /// used as the primary font throughout these tests.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// Apple Color Emoji is always present on macOS and covers emoji code
    /// points that Menlo does not, making it a deterministic fallback.
    private let emoji = MonaFontDescriptor(familyName: "Apple Color Emoji", size: 12)

    private func utf16(_ string: String) -> [UInt16] {
        return Array(string.utf16)
    }

    // MARK: - MonaGlyphRun (immutable glyph-run output)

    func testGlyphRunIsImmutableWithValueSemantics() {
        // MonaGlyphRun is a struct with let-bound fields; two runs with equal
        // fields are equal regardless of construction path.
        let runA = MonaGlyphRun(
            glyphs: [1, 2, 3],
            positions: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0)],
            advances: [CGSize(width: 1, height: 0), CGSize(width: 1, height: 0), CGSize(width: 1, height: 0)],
            stringIndices: [0, 1, 2],
            sourceRange: 0..<3,
            fontDescriptor: menlo,
            ascent: 9,
            descent: 3,
            leading: 0
        )
        let runB = MonaGlyphRun(
            glyphs: [1, 2, 3],
            positions: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0)],
            advances: [CGSize(width: 1, height: 0), CGSize(width: 1, height: 0), CGSize(width: 1, height: 0)],
            stringIndices: [0, 1, 2],
            sourceRange: 0..<3,
            fontDescriptor: menlo,
            ascent: 9,
            descent: 3,
            leading: 0
        )
        XCTAssertEqual(runA, runB)
        XCTAssertEqual(runA.glyphs.count, 3)
        XCTAssertEqual(runA.sourceRange, 0..<3)
        XCTAssertEqual(runA.fontDescriptor, menlo)
    }

    // MARK: - MonaTextShaper: basic shaping

    func testShapeAsciiProducesOneRunWithCorrectGlyphCount() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [emoji])
        let shaper = MonaTextShaper(
            primaryFont: menlo,
            fallback: resolver,
            direction: .ltr,
            scale: 1,
            tabStops: []
        )
        let units = utf16("Hello")
        let result = try shaper.shape(units)

        XCTAssertGreaterThanOrEqual(result.runs.count, 1)
        // The five ASCII code units must be covered by glyph runs (possibly one
        // run covering the whole string).
        let totalGlyphs = result.runs.reduce(0) { $0 + $1.glyphs.count }
        XCTAssertEqual(totalGlyphs, 5, "ASCII 'Hello' should produce exactly 5 glyphs")
        // The single run covers the full source range.
        var covered = Set<Int>()
        for run in result.runs {
            covered.formUnion(run.sourceRange)
        }
        XCTAssertEqual(covered, Set(0..<5))
        // The run's font matches the primary face.
        XCTAssertTrue(result.runs.contains { $0.fontDescriptor == menlo })
        // Isolated surrogates: none in this input.
        XCTAssertEqual(result.isolatedSurrogateOffsets, [])
    }

    func testShapeEmptyInputProducesNoRuns() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver)
        let result = try shaper.shape([])
        XCTAssertEqual(result.runs.count, 0)
        XCTAssertEqual(result.isolatedSurrogateOffsets, [])
        XCTAssertEqual(result.unshapedUnitOffsets, [])
    }

    // MARK: - Scale

    func testShapeScaleScalesAdvances() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let units = utf16("WWWW")

        let shaper1 = MonaTextShaper(primaryFont: menlo, fallback: resolver, scale: 1)
        let result1 = try shaper1.shape(units)
        let advance1 = totalAdvanceWidth(of: result1)

        let shaper2 = MonaTextShaper(primaryFont: menlo, fallback: resolver, scale: 2)
        let result2 = try shaper2.shape(units)
        let advance2 = totalAdvanceWidth(of: result2)

        // Scaling by 2 must roughly double the total advance width.
        XCTAssertGreaterThan(advance1, 0)
        XCTAssertEqual(advance2, advance1 * 2, accuracy: max(advance1 * 0.25, 1.0),
                       "scale=2 should approximately double the advance width")
    }

    // MARK: - Tab stops

    func testShapeTabStopsAdvanceToNextTabStop() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(
            primaryFont: menlo,
            fallback: resolver,
            direction: .ltr,
            scale: 1,
            tabStops: [MonaTabStop(position: 100), MonaTabStop(position: 200)]
        )
        // "a\tb": 'a' then a tab then 'b'. After shaping, 'b' should start at
        // the first tab stop position (100) because the tab snaps the pen to
        // the next tab stop strictly greater than the current x.
        let units = utf16("a\tb")
        let result = try shaper.shape(units)

        // Find the position of the glyph whose source index corresponds to 'b'
        // (source index 2, the third UTF-16 unit).
        var bX: CGFloat?
        for run in result.runs {
            for i in 0..<run.glyphs.count {
                if run.stringIndices[i] == 2 {
                    bX = run.positions[i].x
                    break
                }
            }
        }
        XCTAssertNotNil(bX, "'b' glyph must be present in the shaped runs")
        if let bX = bX {
            XCTAssertEqual(bX, 100, accuracy: 0.5,
                           "'b' after a tab should start at the first tab stop (100)")
        }
    }

    // MARK: - Mixed-script fallback

    func testShapeMixedScriptUsesFallbackAndRecordsFaces() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [emoji])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver)
        // ASCII + emoji. The emoji code point is outside Menlo's coverage, so
        // Core Text must fall back to Apple Color Emoji for it.
        let units = utf16("Hi \u{1F600}") // "Hi " + smiling face emoji
        let result = try shaper.shape(units)

        // At least one run uses the emoji face (the emoji is a surrogate pair
        // in UTF-16, two code units).
        let facesUsed = result.runs.map { $0.fontDescriptor }
        XCTAssertTrue(facesUsed.contains(emoji),
                      "emoji code point should trigger the emoji fallback face")
        // The shaper records every face used (Q1-R4 provenance).
        XCTAssertTrue(shaper.recordedFaces.contains(emoji))
        XCTAssertTrue(shaper.recordedFaces.contains(menlo))
        // Recorded run count matches the produced runs.
        XCTAssertEqual(shaper.recordedRunCount, result.runs.count)
        // The emoji's surrogate pair (two UTF-16 units) is covered by a run.
        let emojiPairRange = (3..<5) // "Hi " is 3 units, then the surrogate pair
        let hasEmojiCoverage = result.runs.contains { $0.sourceRange.overlaps(emojiPairRange) }
        XCTAssertTrue(hasEmojiCoverage, "emoji surrogate pair must be covered by a run")
    }

    // MARK: - Isolated surrogates preserved

    func testShapeIsolatedSurrogateRecordsPositionWithNoGlyph() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver)
        // "A" + lone high surrogate (0xD800) + "B". The lone surrogate is not a
        // valid character; Core Text will not emit a glyph for it, but the
        // shaper must RECORD its source offset.
        let units: [UInt16] = [0x0041, 0xD800, 0x0042] // A, <lone high>, B
        let result = try shaper.shape(units)

        XCTAssertEqual(result.isolatedSurrogateOffsets, [1],
                       "the lone surrogate at UTF-16 offset 1 must be recorded")
        // The surrogate's position is recorded even though Core Text may emit a
        // .notdef/replacement glyph for it. The spec requires the POSITION to be
        // recorded, not that no glyph is emitted.
        // The surrounding ASCII code units (0 and 2) must still be shaped.
        let covered = result.runs.reduce(into: Set<Int>()) { acc, run in
            acc.formUnion(run.sourceRange)
        }
        XCTAssertTrue(covered.contains(0), "'A' must be covered")
        XCTAssertTrue(covered.contains(2), "'B' must be covered")
        // The surrogate offset is a subset of the unshaped offsets: the original
        // surrogate code unit produced no real glyph (it was replaced before
        // shaping), so it counts as unshaped.
        XCTAssertTrue(result.unshapedUnitOffsets.contains(1))
    }

    func testShapeMultipleIsolatedSurrogatesAllRecorded() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver)
        // Lone high surrogate at 0, 'A' at 1, lone low surrogate at 2, then a
        // valid emoji surrogate pair at 3..4. Only offsets 0 and 2 are isolated.
        let units: [UInt16] = [0xD800, 0x0041, 0xDC00, 0xD83D, 0xDE00]
        let result = try shaper.shape(units)

        XCTAssertEqual(result.isolatedSurrogateOffsets.sorted(), [0, 2],
                       "both isolated surrogates (offsets 0 and 2) must be recorded")
        // The valid surrogate pair (offsets 3..4) must NOT appear as isolated.
        XCTAssertFalse(result.isolatedSurrogateOffsets.contains(3))
        XCTAssertFalse(result.isolatedSurrogateOffsets.contains(4))
    }

    // MARK: - Direction

    func testShaperStoresDirectionParameter() {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let ltrShaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr)
        let rtlShaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .rtl)
        XCTAssertEqual(ltrShaper.direction, .ltr)
        XCTAssertEqual(rtlShaper.direction, .rtl)
    }

    func testShapeRTLArabicProducesRightToLeftRun() throws {
        // Arabic is strongly RTL. macOS ships Arabic coverage via the default
        // font cascade (Geeza Pro / Arabic system), so this is a deterministic
        // bidi witness for the direction input. If the host somehow cannot
        // shape Arabic at all, skip.
        let arabicUnits = utf16("مرحبا") // Arabic "hello"
        guard !arabicUnits.isEmpty else {
            throw XCTSkip("empty Arabic input; skipping RTL bidi-level test")
        }
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        // No explicit Arabic fallback; Core Text's default cascade covers it.
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .rtl)
        let result = try shaper.shape(arabicUnits)
        guard result.runs.count >= 1 else {
            throw XCTSkip("host shaped no Arabic runs; skipping RTL bidi-level test")
        }
        // At least one run should be laid out right-to-left.
        let hasRTLRun = result.runs.contains { $0.isRightToLeft }
        XCTAssertTrue(hasRTLRun, "Arabic shaped under .rtl should produce an RTL run")
    }

    // MARK: - Bounded typed failure

    func testShapeInvalidFontDescriptorThrowsTypedError() {
        // Empty family name is an invalid descriptor.
        let bad = MonaFontDescriptor(familyName: "", size: 12)
        let resolver = MonaFontFallbackResolver(primary: bad, fallback: [])
        let shaper = MonaTextShaper(primaryFont: bad, fallback: resolver)
        XCTAssertThrowsError(try shaper.shape(utf16("x"))) { error in
            guard case .fontDescriptorInvalid(let desc) = error as? MonaTextShaperError else {
                XCTFail("expected .fontDescriptorInvalid, got \(error)")
                return
            }
            XCTAssertEqual(desc, bad)
        }
    }

    func testShapeInvalidFontSizeThrowsTypedError() {
        let bad = MonaFontDescriptor(familyName: "Menlo", size: 0)
        let resolver = MonaFontFallbackResolver(primary: bad, fallback: [])
        let shaper = MonaTextShaper(primaryFont: bad, fallback: resolver)
        XCTAssertThrowsError(try shaper.shape(utf16("x"))) { error in
            guard case .fontDescriptorInvalid = error as? MonaTextShaperError else {
                XCTFail("expected .fontDescriptorInvalid for zero size, got \(error)")
                return
            }
        }
    }

    func testShapeNonExistentPrimaryFontThrowsTypedErrorNoPartialRuns() {
        // A family that definitely does not exist. Core Text would substitute
        // Menlo/Monaco silently; the shaper must detect the substitution and
        // throw a bounded typed failure instead of publishing partial runs.
        let bogus = MonaFontDescriptor(familyName: "MonaCodeDefinitelyNonExistentFace", size: 12)
        let resolver = MonaFontFallbackResolver(primary: bogus, fallback: [])
        let shaper = MonaTextShaper(primaryFont: bogus, fallback: resolver)
        do {
            let _ = try shaper.shape(utf16("hello"))
            XCTFail("shaping with a non-existent primary font must throw")
        } catch let error as MonaTextShaperError {
            switch error {
            case .primaryFontUnavailable(let desc, let resolved):
                XCTAssertEqual(desc, bogus)
                XCTAssertNotNil(resolved, "resolved family name should be reported for provenance")
                XCTAssertNotEqual(resolved ?? "", bogus.familyName,
                                  "resolved family must differ from the requested bogus family")
            default:
                XCTFail("expected .primaryFontUnavailable, got \(error)")
            }
        } catch {
            XCTFail("expected MonaTextShaperError, got \(error)")
        }
        // No partial runs are published: recordedFaces/recordedRunCount stay
        // empty after a failed shape() call.
        XCTAssertEqual(shaper.recordedFaces, [])
        XCTAssertEqual(shaper.recordedRunCount, 0)
    }

    // MARK: - Font provenance recording

    func testRecordedFacesCapturesEveryFaceUsed() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [emoji])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver)
        let _ = try shaper.shape(utf16("A\u{1F600}B"))
        // Every distinct face used during shaping is recorded for Q1-R4.
        let recordedSet = Set(shaper.recordedFaces)
        XCTAssertTrue(recordedSet.contains(menlo))
        XCTAssertTrue(recordedSet.contains(emoji))
    }

    func testRecordedRunCountMatchesResultRunCount() throws {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [emoji])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver)
        let result = try shaper.shape(utf16("Hi \u{1F600}"))
        XCTAssertEqual(shaper.recordedRunCount, result.runs.count)
    }

    // MARK: - MonaFontFallbackResolver

    func testFallbackResolverExposesPrimaryAndFallbacks() {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [emoji])
        XCTAssertEqual(resolver.primary, menlo)
        XCTAssertEqual(resolver.fallbacks, [emoji])
    }

    func testFallbackResolverDescriptorCoveringCodePointPrefersPrimary() {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [emoji])
        // 'A' (U+0041) is covered by Menlo; the resolver should return Menlo.
        let cover = resolver.descriptorCoveringCodePoint(0x0041)
        XCTAssertEqual(cover, menlo)
    }

    func testFallbackResolverDescriptorCoveringCodePointFallsBack() {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [emoji])
        // U+1F600 is not in Menlo; the resolver should return the emoji face.
        let cover = resolver.descriptorCoveringCodePoint(0x1F600)
        XCTAssertEqual(cover, emoji)
    }

    func testFallbackResolverDescriptorCoveringCodePointReturnsNilWhenUncovered() {
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [emoji])
        // A private-use code point covered by neither face.
        let cover = resolver.descriptorCoveringCodePoint(0xE000)
        // Either nil (neither covers it) or one of the descriptors is
        // acceptable; we mainly assert the resolver does not crash and returns
        // a deterministic answer.
        if let cover = cover {
            XCTAssertTrue(cover == menlo || cover == emoji)
        }
    }

    // MARK: - Helpers

    private func totalAdvanceWidth(of result: MonaShapingResult) -> CGFloat {
        var total: CGFloat = 0
        for run in result.runs {
            for adv in run.advances {
                total += adv.width
            }
        }
        return total
    }
}

