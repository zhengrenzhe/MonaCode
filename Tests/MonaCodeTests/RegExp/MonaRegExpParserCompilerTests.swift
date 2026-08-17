// MonaRegExpParserCompilerTests.swift
//
// P02-T004 — Implement the finite ECMAScript RegExp parser and compiler.
//
// Verifies the five Phase-02 RegExp sources held in `Sources/MonaCode/RegExp/`:
//
//   - `MonaRegExpAST.swift`      — AST node types (char, charClass, quantifier,
//                                  group, alternation, assertion, backreference,
//                                  namedCapture) + flags.
//   - `MonaRegExpParser.swift`   — `MonaRegExpParser`: parses a pattern + flags
//                                  into an AST; typed syntax errors with offsets.
//   - `MonaRegExpCompiler.swift` — `MonaRegExpCompiler`: compiles the AST into a
//                                  deterministic `MonaRegExpProgram`.
//   - `MonaRegExpProgram.swift`  — `MonaRegExpProgram`: the bytecode
//                                  representation (MATCH_CHAR, MATCH_CLASS, JUMP,
//                                  SPLIT, SAVE_CAPTURE, ASSERT, ...).
//   - `MonaRegExpExecutor.swift` — `MonaRegExpExecutor`: executes a program over
//                                  raw `[UInt16]` input with frozen `lastIndex`
//                                  semantics, zero-length progression, and
//                                  typed resource errors (step limit, stack
//                                  overflow).
//
// Test contract (P02-T004): parser (grammar/flags/assertions/classes/quantifiers/
// groups/named captures/backreferences), compiler (deterministic bytecode),
// executor (raw UInt16, frozen lastIndex, zero-length progression), typed errors
// with source offsets.
//
// MonaCode is a Foundation-only target; tests import XCTest + MonaCode.

import XCTest
import MonaCode

final class MonaRegExpParserCompilerTests: XCTestCase {

    // MARK: - Helpers

    /// Converts a Swift `String` to its raw UTF-16 code units.
    private func units(_ s: String) -> [UInt16] {
        return Array(s.utf16)
    }

    /// Convenience: compile a pattern + flags straight to a program.
    private func compile(_ pattern: String, _ flags: String = "") throws -> MonaRegExpProgram {
        return try monaRegExpCompile(pattern, flags: flags)
    }

    // MARK: - 1. Parser — grammar

    /// A plain concatenation parses to a concatenation of character nodes.
    func testParserConcatenation() throws {
        let p = try MonaRegExpParser(pattern: "abc", flags: "")
        XCTAssertEqual(p.captureCount, 0)
        XCTAssertEqual(p.ast, .concatenation([
            .character(0x0061),
            .character(0x0062),
            .character(0x0063),
        ]))
    }

    /// An empty pattern parses to `.empty`.
    func testParserEmptyPattern() throws {
        let p = try MonaRegExpParser(pattern: "", flags: "")
        XCTAssertEqual(p.ast, .empty)
    }

    /// Alternation `a|b` parses to a two-branch alternation.
    func testParserAlternation() throws {
        let p = try MonaRegExpParser(pattern: "a|b", flags: "")
        XCTAssertEqual(p.ast, .alternation([
            .character(0x0061),
            .character(0x0062),
        ]))
    }

    /// Alternation binds looser than concatenation: `ab|cd` is `(ab)|(cd)`.
    func testParserAlternationPrecedence() throws {
        let p = try MonaRegExpParser(pattern: "ab|cd", flags: "")
        XCTAssertEqual(p.ast, .alternation([
            .concatenation([.character(0x0061), .character(0x0062)]),
            .concatenation([.character(0x0063), .character(0x0064)]),
        ]))
    }

    // MARK: - 2. Parser — flags

    /// All eight ECMAScript flags are accepted and surface on the parsed flags.
    func testParserAcceptsAllFlags() throws {
        let p = try MonaRegExpParser(pattern: "a", flags: "gimsuy")
        XCTAssertTrue(p.flags.contains(.global))
        XCTAssertTrue(p.flags.contains(.ignoreCase))
        XCTAssertTrue(p.flags.contains(.multiline))
        XCTAssertTrue(p.flags.contains(.dotAll))
        XCTAssertTrue(p.flags.contains(.unicode))
        XCTAssertTrue(p.flags.contains(.sticky))
    }

    /// An unknown flag is a syntax error at offset 0 of the flags (reported
    /// with the flags-region offset).
    func testParserRejectsUnknownFlag() {
        XCTAssertThrowsError(try MonaRegExpParser(pattern: "a", flags: "z")) { err in
            guard let e = err as? MonaRegExpSyntaxError else {
                XCTFail("expected MonaRegExpSyntaxError"); return
            }
            XCTAssertGreaterThanOrEqual(e.offset, 0)
            XCTAssertTrue(e.message.contains("flag") || e.message.contains("Flag"))
        }
    }

    /// Duplicate flags are rejected (ECMAScript SyntaxError).
    func testParserRejectsDuplicateFlag() {
        XCTAssertThrowsError(try MonaRegExpParser(pattern: "a", flags: "gg")) { err in
            XCTAssertTrue(err is MonaRegExpSyntaxError)
        }
    }

    // MARK: - 3. Parser — assertions

    /// `^` and `$` parse to start/end assertions.
    func testParserStartEndAssertions() throws {
        let p = try MonaRegExpParser(pattern: "^a$", flags: "")
        XCTAssertEqual(p.ast, .concatenation([
            .assertion(.start),
            .character(0x0061),
            .assertion(.end),
        ]))
    }

    /// `\b` and `\B` parse to word-boundary assertions.
    func testParserWordBoundaryAssertions() throws {
        let p = try MonaRegExpParser(pattern: "\\bb\\B", flags: "")
        XCTAssertEqual(p.ast, .concatenation([
            .assertion(.wordBoundary),
            .character(0x0062),
            .assertion(.notWordBoundary),
        ]))
    }

    /// Lookahead `(?=X)` and `(?!X)` parse with negation flag.
    func testParserLookahead() throws {
        let pos = try MonaRegExpParser(pattern: "(?=a)", flags: "")
        XCTAssertEqual(pos.ast, .assertion(.lookahead(.character(0x0061), false)))
        let neg = try MonaRegExpParser(pattern: "(?!a)", flags: "")
        XCTAssertEqual(neg.ast, .assertion(.lookahead(.character(0x0061), true)))
    }

    /// Lookbehind `(?<=X)` and `(?<!X)` parse with negation flag.
    func testParserLookbehind() throws {
        let pos = try MonaRegExpParser(pattern: "(?<=a)", flags: "")
        XCTAssertEqual(pos.ast, .assertion(.lookbehind(.character(0x0061), false)))
        let neg = try MonaRegExpParser(pattern: "(?<!a)", flags: "")
        XCTAssertEqual(neg.ast, .assertion(.lookbehind(.character(0x0061), true)))
    }

    // MARK: - 4. Parser — character classes

    /// `[a-z]` parses to a class with one range, not negated.
    func testParserCharClassRange() throws {
        let p = try MonaRegExpParser(pattern: "[a-z]", flags: "")
        let cls = MonaRegExpCharClass(negated: false, items: [.range(0x0061, 0x007A)])
        XCTAssertEqual(p.ast, .charClass(cls))
    }

    /// `[^a-z]` parses to a negated class.
    func testParserCharClassNegated() throws {
        let p = try MonaRegExpParser(pattern: "[^a-z]", flags: "")
        let cls = MonaRegExpCharClass(negated: true, items: [.range(0x0061, 0x007A)])
        XCTAssertEqual(p.ast, .charClass(cls))
    }

    /// `[a0-9]` parses to a char + range.
    func testParserCharClassMixed() throws {
        let p = try MonaRegExpParser(pattern: "[a0-9]", flags: "")
        XCTAssertEqual(p.ast, .charClass(MonaRegExpCharClass(
            negated: false,
            items: [.char(0x0061), .range(0x0030, 0x0039)]
        )))
    }

    /// `\d`, `\w`, `\s` parse to builtins.
    func testParserBuiltinClasses() throws {
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "\\d", flags: "").ast,
            .charClass(MonaRegExpCharClass(items: [.builtin(.digit)]))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "\\w", flags: "").ast,
            .charClass(MonaRegExpCharClass(items: [.builtin(.word)]))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "\\s", flags: "").ast,
            .charClass(MonaRegExpCharClass(items: [.builtin(.whitespace)]))
        )
    }

    /// `\D`, `\W`, `\S` parse to the negated builtins.
    func testParserNegatedBuiltinClasses() throws {
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "\\D", flags: "").ast,
            .charClass(MonaRegExpCharClass(items: [.builtin(.notDigit)]))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "\\W", flags: "").ast,
            .charClass(MonaRegExpCharClass(items: [.builtin(.notWord)]))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "\\S", flags: "").ast,
            .charClass(MonaRegExpCharClass(items: [.builtin(.notWhitespace)]))
        )
    }

    /// `.` parses to `.anyChar`.
    func testParserDotAnyChar() throws {
        let p = try MonaRegExpParser(pattern: ".", flags: "")
        XCTAssertEqual(p.ast, .anyChar)
    }

    /// `\\.` is an escaped literal dot, not anyChar.
    func testParserEscapedDot() throws {
        let p = try MonaRegExpParser(pattern: "\\.", flags: "")
        XCTAssertEqual(p.ast, .character(0x002E))
    }

    // MARK: - 5. Parser — quantifiers

    /// `a*`, `a+`, `a?` parse to greedy quantifiers with the right bounds.
    func testParserGreedyQuantifiers() throws {
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a*", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 0, max: nil, greedy: true))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a+", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 1, max: nil, greedy: true))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a?", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 0, max: 1, greedy: true))
        )
    }

    /// `a*?`, `a+?`, `a??` parse to lazy quantifiers.
    func testParserLazyQuantifiers() throws {
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a*?", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 0, max: nil, greedy: false))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a+?", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 1, max: nil, greedy: false))
        )
    }

    /// `a{3}`, `a{2,}`, `a{2,4}` parse to bounded quantifiers.
    func testParserBoundedQuantifiers() throws {
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a{3}", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 3, max: 3, greedy: true))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a{2,}", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 2, max: nil, greedy: true))
        )
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a{2,4}", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 2, max: 4, greedy: true))
        )
    }

    /// `a{2,4}?` is the lazy form.
    func testParserBoundedLazyQuantifier() throws {
        XCTAssertEqual(
            try MonaRegExpParser(pattern: "a{2,4}?", flags: "").ast,
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0061), min: 2, max: 4, greedy: false))
        )
    }

    /// Quantifiers apply to the preceding atom only; `ab*` is `a(b*)`.
    func testParserQuantifierPrecedence() throws {
        let p = try MonaRegExpParser(pattern: "ab*", flags: "")
        XCTAssertEqual(p.ast, .concatenation([
            .character(0x0061),
            .quantifier(MonaRegExpQuantifier(atom: .character(0x0062), min: 0, max: nil, greedy: true)),
        ]))
    }

    // MARK: - 6. Parser — groups

    /// `(...)` is a capturing group with index 1.
    func testParserCapturingGroup() throws {
        let p = try MonaRegExpParser(pattern: "(a)", flags: "")
        XCTAssertEqual(p.captureCount, 1)
        XCTAssertEqual(p.ast, .group(MonaRegExpGroup(
            kind: .capturing, node: .character(0x0061), index: 1
        )))
    }

    /// `(?:...)` is non-capturing (index 0, no capture increment).
    func testParserNonCapturingGroup() throws {
        let p = try MonaRegExpParser(pattern: "(?:a)", flags: "")
        XCTAssertEqual(p.captureCount, 0)
        XCTAssertEqual(p.ast, .group(MonaRegExpGroup(
            kind: .nonCapturing, node: .character(0x0061), index: 0
        )))
    }

    /// Nested capturing groups get increasing indices left-to-right.
    func testParserNestedGroupIndices() throws {
        let p = try MonaRegExpParser(pattern: "(a(b)c)", flags: "")
        XCTAssertEqual(p.captureCount, 2)
        guard case .group(let outer) = p.ast else {
            XCTFail("expected outer group"); return
        }
        XCTAssertEqual(outer.index, 1)
        guard case .concatenation(let outerTerms) = outer.node else {
            XCTFail("expected concatenation in outer"); return
        }
        XCTAssertEqual(outerTerms.count, 3)
        guard case .group(let inner) = outerTerms[1] else {
            XCTFail("expected inner group at index 1"); return
        }
        XCTAssertEqual(inner.index, 2)
    }

    // MARK: - 7. Parser — named captures

    /// `(?<name>X)` is a named capturing group.
    func testParserNamedCapture() throws {
        let p = try MonaRegExpParser(pattern: "(?<word>\\w+)", flags: "")
        XCTAssertEqual(p.captureCount, 1)
        XCTAssertEqual(p.namedCaptures["word"], 1)
        XCTAssertEqual(p.ast, .group(MonaRegExpGroup(
            kind: .named("word"),
            node: .quantifier(MonaRegExpQuantifier(atom: .charClass(MonaRegExpCharClass(items: [.builtin(.word)])), min: 1, max: nil, greedy: true)),
            index: 1
        )))
    }

    /// Duplicate named captures are rejected (ECMAScript SyntaxError).
    func testParserDuplicateNamedCaptureRejected() {
        XCTAssertThrowsError(try MonaRegExpParser(pattern: "(?<a>x)(?<a>y)", flags: "")) { err in
            XCTAssertTrue(err is MonaRegExpSyntaxError)
        }
    }

    // MARK: - 8. Parser — backreferences

    /// `\1` is a numeric backreference.
    func testParserNumericBackreference() throws {
        let p = try MonaRegExpParser(pattern: "(a)\\1", flags: "")
        guard case .concatenation(let terms) = p.ast else {
            XCTFail("expected concatenation"); return
        }
        XCTAssertEqual(terms.count, 2)
        XCTAssertEqual(terms[1], .backreference(1))
    }

    /// `\k<name>` is a named backreference.
    func testParserNamedBackreference() throws {
        let p = try MonaRegExpParser(pattern: "(?<x>a)\\k<x>", flags: "")
        guard case .concatenation(let terms) = p.ast else {
            XCTFail("expected concatenation"); return
        }
        XCTAssertEqual(terms.count, 2)
        XCTAssertEqual(terms[1], .namedBackreference("x"))
    }

    /// A named backreference to an undefined group is a syntax error.
    func testParserNamedBackreferenceUndefinedGroupRejected() {
        XCTAssertThrowsError(try MonaRegExpParser(pattern: "\\k<missing>", flags: "")) { err in
            XCTAssertTrue(err is MonaRegExpSyntaxError)
        }
    }

    // MARK: - 9. Parser — escape sequences

    /// `\n`, `\t`, `\r` parse to their control-character code units.
    func testParserControlEscapes() throws {
        XCTAssertEqual(try MonaRegExpParser(pattern: "\\n", flags: "").ast, .character(0x000A))
        XCTAssertEqual(try MonaRegExpParser(pattern: "\\t", flags: "").ast, .character(0x0009))
        XCTAssertEqual(try MonaRegExpParser(pattern: "\\r", flags: "").ast, .character(0x000D))
    }

    /// `A` parses to the code unit U+0041 (`A`).
    func testParserUnicodeEscape() throws {
        XCTAssertEqual(try MonaRegExpParser(pattern: "\\u0041", flags: "").ast, .character(0x0041))
    }

    /// `\x41` parses to the code unit U+0041.
    func testParserHexEscape() throws {
        XCTAssertEqual(try MonaRegExpParser(pattern: "\\x41", flags: "").ast, .character(0x0041))
    }

    /// `\u{1F600}` under the `u` flag parses to the surrogate pair.
    func testParserUnicodeCodePointEscape() throws {
        let p = try MonaRegExpParser(pattern: "\\u{1F600}", flags: "u")
        // U+1F600 = high 0xD83D, low 0xDE00
        XCTAssertEqual(p.ast, .concatenation([
            .character(0xD83D),
            .character(0xDE00),
        ]))
    }

    // MARK: - 10. Parser — syntax errors with source offsets

    /// An unterminated group `(` reports a syntax error at the offset of the `(`.
    func testParserUnterminatedGroupOffset() {
        XCTAssertThrowsError(try MonaRegExpParser(pattern: "(abc", flags: "")) { err in
            guard let e = err as? MonaRegExpSyntaxError else {
                XCTFail("expected MonaRegExpSyntaxError"); return
            }
            XCTAssertEqual(e.offset, 0)
        }
    }

    /// An unterminated character class `[` reports a syntax error at the `[`.
    func testParserUnterminatedClassOffset() {
        XCTAssertThrowsError(try MonaRegExpParser(pattern: "[abc", flags: "")) { err in
            guard let e = err as? MonaRegExpSyntaxError else {
                XCTFail("expected MonaRegExpSyntaxError"); return
            }
            XCTAssertEqual(e.offset, 0)
        }
    }

    /// A quantifier with no preceding atom reports an error at the quantifier.
    func testParserQuantifierWithNoAtom() {
        XCTAssertThrowsError(try MonaRegExpParser(pattern: "*", flags: "")) { err in
            guard let e = err as? MonaRegExpSyntaxError else {
                XCTFail("expected MonaRegExpSyntaxError"); return
            }
            XCTAssertEqual(e.offset, 0)
        }
    }

    /// An invalid `{n,m}` range reports an error at the `{`.
    func testParserInvalidQuantifierRange() {
        XCTAssertThrowsError(try MonaRegExpParser(pattern: "a{3,2}", flags: "")) { err in
            XCTAssertTrue(err is MonaRegExpSyntaxError)
        }
    }

    // MARK: - 11. Compiler — deterministic bytecode

    /// Compiling the same pattern twice yields equal programs.
    func testCompilerDeterministic() throws {
        let p1 = try compile("a(b|c)*d")
        let p2 = try compile("a(b|c)*d")
        XCTAssertEqual(p1, p2)
    }

    /// A `*` quantifier produces at least one SPLIT instruction.
    func testCompilerStarProducesSplit() throws {
        let prog = try compile("a*")
        XCTAssertTrue(prog.instructions.contains { op in
            if case .split = op { return true } else { return false }
        }, "a* should compile to at least one SPLIT")
    }

    /// A capturing group produces SAVE instructions for its slots.
    func testCompilerCapturingGroupSaves() throws {
        let prog = try compile("(a)")
        let saveCount = prog.instructions.reduce(0) { acc, op in
            if case .save = op { return acc + 1 } else { return acc }
        }
        XCTAssertGreaterThanOrEqual(saveCount, 2, "(a) should save group 1 start/end + full-match")
        XCTAssertEqual(prog.captureCount, 1)
    }

    /// The program records the capture count and named captures.
    func testCompilerProgramMetadata() throws {
        let prog = try compile("(?<x>a)(b)")
        XCTAssertEqual(prog.captureCount, 2)
        XCTAssertEqual(prog.namedCaptures["x"], 1)
    }

    /// `^` compiles to an assert-start instruction.
    func testCompilerAssertStart() throws {
        let prog = try compile("^a")
        XCTAssertTrue(prog.instructions.contains { op in
            if case .assertStart = op { return true } else { return false }
        })
    }

    // MARK: - 12. Executor — raw UInt16 matching

    /// A literal pattern matches at the right offset in raw UInt16 input.
    func testExecutorLiteralMatch() throws {
        let prog = try compile("world")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("hello world"), at: 0)
        XCTAssertNotNil(r.match)
        XCTAssertEqual(r.match?.startOffset, 6)
        XCTAssertEqual(r.match?.endOffset, 11)
    }

    /// A lone surrogate in the input is matched code-unit-wise and never
    /// repaired.
    func testExecutorLoneSurrogate() throws {
        // High surrogate 0xD83D not followed by a low surrogate.
        let prog = try compile("\\uD83D")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec([0xD83D, 0x0061], at: 0)
        XCTAssertEqual(r.match?.startOffset, 0)
        XCTAssertEqual(r.match?.endOffset, 1)
    }

    /// `.` does not match a line terminator by default.
    func testExecutorDotDoesNotMatchNewline() throws {
        let prog = try compile("a.c")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("a\nc"), at: 0)
        XCTAssertNil(r.match)
    }

    /// With the `s` (dotAll) flag, `.` matches a line terminator.
    func testExecutorDotAllMatchesNewline() throws {
        let prog = try compile("a.c", "s")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("a\nc"), at: 0)
        XCTAssertEqual(r.match?.startOffset, 0)
        XCTAssertEqual(r.match?.endOffset, 3)
    }

    // MARK: - 13. Executor — captures and backreferences

    /// A capturing group records its span; group 0 is the full match.
    func testExecutorCaptures() throws {
        let prog = try compile("(\\d+)-(\\d+)")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("phone 555-1234"), at: 0)
        XCTAssertEqual(r.match?.captures.count, 3) // group 0 + two captures
        XCTAssertEqual(r.match?.captures[0].start, 6)
        XCTAssertEqual(r.match?.captures[0].end, 14)
        XCTAssertEqual(r.match?.captures[1].start, 6)
        XCTAssertEqual(r.match?.captures[1].end, 9)
        XCTAssertEqual(r.match?.captures[2].start, 10)
        XCTAssertEqual(r.match?.captures[2].end, 14)
    }

    /// Named captures are populated by name.
    func testExecutorNamedCaptures() throws {
        let prog = try compile("(?<year>\\d{4})-(?<month>\\d{2})")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("2026-08"), at: 0)
        XCTAssertEqual(r.match?.namedCaptures["year"]?.start, 0)
        XCTAssertEqual(r.match?.namedCaptures["year"]?.end, 4)
        XCTAssertEqual(r.match?.namedCaptures["month"]?.start, 5)
        XCTAssertEqual(r.match?.namedCaptures["month"]?.end, 7)
    }

    /// A numeric backreference matches a repeated capture.
    func testExecutorBackreference() throws {
        let prog = try compile("(\\w+) \\1")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("hello hello"), at: 0)
        XCTAssertEqual(r.match?.startOffset, 0)
        XCTAssertEqual(r.match?.endOffset, 11)
    }

    /// A named backreference matches a repeated named capture.
    func testExecutorNamedBackreference() throws {
        let prog = try compile("(?<x>\\w+) \\k<x>")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("cat cat"), at: 0)
        XCTAssertEqual(r.match?.endOffset, 7)
    }

    // MARK: - 14. Executor — assertions

    /// `^` matches only at the start (no `m` flag).
    func testExecutorStartAssertion() throws {
        let prog = try compile("^a")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertNotNil(try ex.exec(units("a"), at: 0).match)
        XCTAssertNil(try ex.exec(units("ba"), at: 0).match)
    }

    /// `$` matches only at the end.
    func testExecutorEndAssertion() throws {
        let prog = try compile("a$")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertNotNil(try ex.exec(units("a"), at: 0).match)
        XCTAssertNil(try ex.exec(units("ab"), at: 0).match)
    }

    /// With `m`, `^` matches after a line terminator.
    func testExecutorMultilineStart() throws {
        let prog = try compile("^b", "m")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertNotNil(try ex.exec(units("a\nb"), at: 0).match)
    }

    /// `\b` matches at a word boundary.
    func testExecutorWordBoundary() throws {
        let prog = try compile("\\bcat\\b")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertNotNil(try ex.exec(units("the cat sat"), at: 0).match)
        XCTAssertNil(try ex.exec(units("category"), at: 0).match)
    }

    /// A positive lookahead asserts without consuming.
    func testExecutorLookahead() throws {
        let prog = try compile("a(?=b)")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("ab"), at: 0)
        XCTAssertEqual(r.match?.endOffset, 1, "lookahead must not consume")
        XCTAssertNil(try ex.exec(units("ac"), at: 0).match)
    }

    /// A negative lookahead fails when the assertion matches.
    func testExecutorNegativeLookahead() throws {
        let prog = try compile("a(?!b)")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertNil(try ex.exec(units("ab"), at: 0).match)
        XCTAssertNotNil(try ex.exec(units("ac"), at: 0).match)
    }

    /// A positive lookbehind asserts on the text before the cursor.
    func testExecutorLookbehind() throws {
        let prog = try compile("(?<=a)b")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertNotNil(try ex.exec(units("ab"), at: 0).match)
        XCTAssertNil(try ex.exec(units("cb"), at: 0).match)
    }

    /// A negative lookbehind fails when the preceding text matches.
    func testExecutorNegativeLookbehind() throws {
        let prog = try compile("(?<!a)b")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertNil(try ex.exec(units("ab"), at: 0).match)
        XCTAssertNotNil(try ex.exec(units("cb"), at: 0).match)
    }

    // MARK: - 15. Executor — character classes

    /// `\d+` matches a run of digits.
    func testExecutorDigitClass() throws {
        let prog = try compile("\\d+")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("abc123def"), at: 0)
        XCTAssertEqual(r.match?.startOffset, 3)
        XCTAssertEqual(r.match?.endOffset, 6)
    }

    /// `[^a-z]` matches a non-lowercase-letter.
    func testExecutorNegatedClass() throws {
        let prog = try compile("[^a-z]")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("abcABC"), at: 0)
        XCTAssertEqual(r.match?.startOffset, 3)
    }

    /// `\w+` matches word characters including underscore.
    func testExecutorWordClass() throws {
        let prog = try compile("\\w+")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("var_name = 1"), at: 0)
        XCTAssertEqual(r.match?.endOffset, 8)
    }

    // MARK: - 16. Executor — quantifiers

    /// Greedy `a*` matches as much as possible.
    func testExecutorGreedyStar() throws {
        let prog = try compile("a*")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("aaa"), at: 0)
        XCTAssertEqual(r.match?.endOffset, 3)
    }

    /// Lazy `a*?` matches as little as possible — the empty string — while
    /// greedy `a*` matches as much as possible.
    func testExecutorLazyStar() throws {
        let lazy = try compile("a*?")
        let exLazy = MonaRegExpExecutor(program: lazy)
        let rLazy = try exLazy.exec(units("aaa"), at: 0)
        XCTAssertEqual(rLazy.match?.endOffset, 0, "lazy a*? matches the empty string")

        let greedy = try compile("a*")
        let exGreedy = MonaRegExpExecutor(program: greedy)
        let rGreedy = try exGreedy.exec(units("aaa"), at: 0)
        XCTAssertEqual(rGreedy.match?.endOffset, 3, "greedy a* matches all")
    }

    /// `a{2,3}` matches 2 or 3, preferring 3 (greedy).
    func testExecutorBoundedQuantifier() throws {
        let prog = try compile("a{2,3}")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertEqual(try ex.exec(units("aaaa"), at: 0).match?.endOffset, 3)
    }

    // MARK: - 17. Executor — case-insensitive (via Phase-02 provider)

    /// With the `i` flag, `[A-Z]` matches lowercase.
    func testExecutorIgnoreCaseClassRange() throws {
        let prog = try compile("[A-Z]+", "i")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("abcXYZ"), at: 0)
        XCTAssertEqual(r.match?.endOffset, 6)
    }

    /// With the `i` flag, a literal `a` matches `A`.
    func testExecutorIgnoreCaseLiteral() throws {
        let prog = try compile("abc", "i")
        let ex = MonaRegExpExecutor(program: prog)
        XCTAssertNotNil(try ex.exec(units("ABC"), at: 0).match)
    }

    // MARK: - 18. Executor — frozen lastIndex semantics

    /// With the `y` (sticky) flag, a match must start exactly at lastIndex.
    func testExecutorStickyMatchesAtLastIndex() throws {
        let prog = try compile("cat", "y")
        let ex = MonaRegExpExecutor(program: prog)
        // At lastIndex 0 over "cat" → match.
        XCTAssertNotNil(try ex.exec(units("cat"), at: 0).match)
        // At lastIndex 1 → no match (sticky requires exact position).
        XCTAssertNil(try ex.exec(units("cat"), at: 1).match)
    }

    /// Without `y`, exec searches forward from lastIndex.
    func testExecutorForwardSearch() throws {
        let prog = try compile("o")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("foo"), at: 0)
        XCTAssertEqual(r.match?.startOffset, 1)
    }

    /// After a match, nextLastIndex is the match end (frozen lastIndex update).
    func testExecutorNextLastIndex() throws {
        let prog = try compile("\\d+", "g")
        let ex = MonaRegExpExecutor(program: prog)
        let r1 = try ex.exec(units("12 34"), at: 0)
        XCTAssertEqual(r1.match?.endOffset, 2)
        XCTAssertEqual(r1.nextLastIndex, 2)
        let r2 = try ex.exec(units("12 34"), at: r1.nextLastIndex)
        XCTAssertEqual(r2.match?.startOffset, 3)
        XCTAssertEqual(r2.match?.endOffset, 5)
    }

    /// After a zero-length match, nextLastIndex advances by one (progression).
    func testExecutorZeroLengthNextLastIndex() throws {
        let prog = try compile("a*", "g")
        let ex = MonaRegExpExecutor(program: prog)
        let r = try ex.exec(units("bbb"), at: 0)
        // a* matches empty at 0; lastIndex must advance to 1, not stay at 0.
        XCTAssertEqual(r.match?.startOffset, 0)
        XCTAssertEqual(r.match?.endOffset, 0)
        XCTAssertEqual(r.nextLastIndex, 1)
    }

    // MARK: - 19. Executor — zero-length progression (no infinite loop)

    /// `findAll` over an empty-matching pattern terminates and produces
    /// progressing matches.
    func testExecutorZeroLengthProgressionTerminates() throws {
        let prog = try compile("a*", "g")
        let ex = MonaRegExpExecutor(program: prog)
        let matches = try ex.findAll(in: units("bbb"), from: 0, limit: 1000)
        // Four zero-length matches: at 0, 1, 2, 3 — and it terminates.
        XCTAssertEqual(matches.count, 4)
        XCTAssertEqual(matches.map { $0.startOffset }, [0, 1, 2, 3])
        for m in matches {
            XCTAssertEqual(m.endOffset - m.startOffset, 0)
        }
    }

    /// `findAll` over a non-empty-matching pattern collects all matches.
    func testExecutorFindAllNonEmpty() throws {
        let prog = try compile("a", "g")
        let ex = MonaRegExpExecutor(program: prog)
        let matches = try ex.findAll(in: units("banana"), from: 0, limit: 1000)
        XCTAssertEqual(matches.map { $0.startOffset }, [1, 3, 5])
    }

    /// `findAll` respects the `limit`.
    func testExecutorFindAllLimit() throws {
        let prog = try compile("a", "g")
        let ex = MonaRegExpExecutor(program: prog)
        let matches = try ex.findAll(in: units("aaaa"), from: 0, limit: 2)
        XCTAssertEqual(matches.count, 2)
    }

    /// Without `g` or `y`, `findAll` returns a single match.
    func testExecutorFindAllNoFlagSingleMatch() throws {
        let prog = try compile("a")
        let ex = MonaRegExpExecutor(program: prog)
        let matches = try ex.findAll(in: units("aaaa"), from: 0, limit: 1000)
        XCTAssertEqual(matches.count, 1)
    }

    // MARK: - 20. Executor — typed resource errors

    /// A catastrophic-backtracking pattern with a low step limit throws
    /// `.stepLimitExceeded`.
    func testExecutorStepLimitExceeded() throws {
        let prog = try compile("(a+)+b")
        let ex = MonaRegExpExecutor(program: prog, stepLimit: 1_000)
        let input = units(String(repeating: "a", count: 30) + "!")
        XCTAssertThrowsError(try ex.exec(input, at: 0)) { err in
            guard case .stepLimitExceeded = err as? MonaRegExpResourceError else {
                XCTFail("expected stepLimitExceeded, got \(err)"); return
            }
        }
    }

    /// A pattern that pushes many frames with a low stack limit throws
    /// `.stackOverflow`.
    func testExecutorStackOverflow() throws {
        let prog = try compile("(a|b)*")
        let ex = MonaRegExpExecutor(program: prog, stackLimit: 64)
        let input = units(String(repeating: "ab", count: 100))
        XCTAssertThrowsError(try ex.exec(input, at: 0)) { err in
            guard case .stackOverflow = err as? MonaRegExpResourceError else {
                XCTFail("expected stackOverflow, got \(err)"); return
            }
        }
    }
}
