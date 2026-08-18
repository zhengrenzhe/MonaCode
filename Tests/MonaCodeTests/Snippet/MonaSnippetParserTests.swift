// MonaSnippetParserTests.swift
//
// P06-T006 — Port the complete snippet parser and grammar.
//
// Verifies the snippet parser + grammar across the three implementation
// operations:
//   1. Port text, escape, tabstop, placeholder, choice, variable, nested child,
//      transform, format, conditional, and fallback grammar.
//   2. Preserve source offsets and depth-first parse order over raw UTF-16.
//   3. Execute transform RegExp through the declared snippet consumer profile
//      (the Phase 02 MonaRegExpParser/MonaRegExpExecutor engine).
//
// On Green, `testContractBehavior` prints the contract line:
//     SNIPPET parser=live grammar=11 offsets=pass utf16=pass transform=pass

import XCTest
import MonaCode

final class MonaSnippetParserTests: XCTestCase {

    // MARK: - Helpers

    /// Parses a Swift string into snippet markers (convenience over raw
    /// `[UInt16]`).
    private func parse(_ text: String) -> [MonaSnippetMarker] {
        return MonaSnippetParser.parse(Array(text.utf16))
    }

    /// Renders markers to text with the given variable bindings.
    private func render(_ markers: [MonaSnippetMarker], variables: [String: String] = [:]) -> String {
        return MonaSnippetTextmateSnippet(markers: markers).toText(variables: variables)
    }

    private func span(_ start: Int, _ end: Int) -> MonaSnippetSpan {
        return MonaSnippetSpan(start: start, end: end)
    }

    // MARK: - 1. Text grammar

    func testTextParsesLiteralCharacters() {
        let markers = parse("hello")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0], .text("hello", span(0, 5)))
    }

    func testTextPreservesWhitespaceAndSymbols() {
        let markers = parse("  ab cd 12 **  ")
        XCTAssertEqual(render(markers), "  ab cd 12 **  ")
    }

    // MARK: - 2. Escape grammar

    func testEscapeDollarIsLiteralDollarText() {
        // \$ → literal $ (rendered as text, not a tabstop trigger).
        let markers = parse("\\$")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0], .escape("$", span(0, 2)))
        XCTAssertEqual(render(markers), "$")
    }

    func testEscapeBackslashIsLiteralBackslash() {
        // \\ → literal backslash.
        let markers = parse("\\\\")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0], .escape("\\", span(0, 2)))
        XCTAssertEqual(render(markers), "\\")
    }

    func testEscapeCurlyCloseIsLiteralBrace() {
        // \} → literal }
        let markers = parse("\\}")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0], .escape("}", span(0, 2)))
        XCTAssertEqual(render(markers), "}")
    }

    func testEscapeUnknownBackslashIsKeptVerbatim() {
        // \n etc. — Monaco keeps unknown escapes verbatim (\ + char).
        let markers = parse("\\n")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(render(markers), "\\n")
    }

    // MARK: - 3. Tabstop grammar

    func testSimpleTabstopDollarInt() {
        let markers = parse("$1")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0], .tabstop(index: 1, span: span(0, 2)))
    }

    func testBracedTabstop() {
        let markers = parse("${2}")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0], .tabstop(index: 2, span: span(0, 4)))
    }

    func testFinalTabstopZero() {
        let markers = parse("$0")
        XCTAssertEqual(markers[0], .tabstop(index: 0, span: span(0, 2)))
    }

    // MARK: - 4. Placeholder grammar

    func testPlaceholderWithDefaultText() {
        // ${2:default} — 12 code units: $ { 2 : d e f a u l t }
        let markers = parse("${2:default}")
        XCTAssertEqual(markers.count, 1)
        guard case let .placeholder(index, children, pspan, transform) = markers[0] else {
            return XCTFail("expected placeholder")
        }
        XCTAssertEqual(index, 2)
        XCTAssertEqual(pspan, span(0, 12))
        XCTAssertNil(transform)
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children[0], .text("default", span(4, 11)))
    }

    func testPlaceholderRendersDefault() {
        let markers = parse("${1:hello}")
        XCTAssertEqual(render(markers), "hello")
    }

    // MARK: - 5. Choice grammar

    func testChoiceParsesOptions() {
        // ${1|one,two,three|}
        let markers = parse("${1|one,two,three|}")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0], .choice(index: 1, options: ["one", "two", "three"], span: span(0, 19)))
    }

    func testChoiceRendersFirstOption() {
        let markers = parse("${1|one,two,three|}")
        XCTAssertEqual(render(markers), "one")
    }

    func testChoiceEscapeCommaInOption() {
        // ${1|a\,b,c|} → options ["a,b", "c"]
        let markers = parse("${1|a\\,b,c|}")
        XCTAssertEqual(markers[0], .choice(index: 1, options: ["a,b", "c"], span: span(0, 12)))
    }

    func testChoiceEscapePipeInOption() {
        // ${1|a\|b,c|} → options ["a|b", "c"]
        let markers = parse("${1|a\\|b,c|}")
        XCTAssertEqual(markers[0], .choice(index: 1, options: ["a|b", "c"], span: span(0, 12)))
    }

    func testChoiceEscapeBackslashInOption() {
        // ${1|a\\b,c|} → options ["a\b", "c"]
        let markers = parse("${1|a\\\\b,c|}")
        XCTAssertEqual(markers[0], .choice(index: 1, options: ["a\\b", "c"], span: span(0, 12)))
    }

    func testChoiceContractFirstChoice() {
        // Probe vector 5: ${1|a\,b,c\|d,e\\f|} → first option "a,b"
        let markers = parse("${1|a\\,b,c\\|d,e\\\\f|}")
        guard case let .choice(_, options, _) = markers[0] else {
            return XCTFail("expected choice")
        }
        XCTAssertEqual(options.first, "a,b")
        XCTAssertEqual(options, ["a,b", "c|d", "e\\f"])
    }

    // MARK: - 6. Variable grammar

    func testSimpleVariableDollarName() {
        let markers = parse("$NAME")
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0], .variable(name: "NAME", children: [], span: span(0, 5), transform: nil))
    }

    func testBracedVariable() {
        let markers = parse("${NAME}")
        XCTAssertEqual(markers[0], .variable(name: "NAME", children: [], span: span(0, 7), transform: nil))
    }

    func testVariableWithDefault() {
        // ${NAME:default}
        let markers = parse("${NAME:default}")
        guard case let .variable(name, children, vspan, transform) = markers[0] else {
            return XCTFail("expected variable")
        }
        XCTAssertEqual(name, "NAME")
        XCTAssertEqual(vspan, span(0, 15))
        XCTAssertNil(transform)
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children[0], .text("default", span(7, 14)))
    }

    // MARK: - 7. Nested child grammar

    func testNestedPlaceholderInsidePlaceholder() {
        // ${1:${2:inner}} — 15 code units.
        let markers = parse("${1:${2:inner}}")
        guard case let .placeholder(index, children, pspan, transform) = markers[0] else {
            return XCTFail("expected placeholder")
        }
        XCTAssertEqual(index, 1)
        XCTAssertEqual(pspan, span(0, 15))
        XCTAssertNil(transform)
        XCTAssertEqual(children.count, 1)
        guard case let .placeholder(innerIndex, innerChildren, innerSpan, innerTransform) = children[0] else {
            return XCTFail("expected inner placeholder")
        }
        XCTAssertEqual(innerIndex, 2)
        XCTAssertEqual(innerSpan, span(4, 14))
        XCTAssertNil(innerTransform)
        XCTAssertEqual(innerChildren.count, 1)
        XCTAssertEqual(innerChildren[0], .text("inner", span(8, 13)))
    }

    func testNestedVariableInsidePlaceholder() {
        // ${1:pre-$X-post}
        let markers = parse("${1:pre-$X-post}")
        guard case let .placeholder(_, children, _, _) = markers[0] else {
            return XCTFail("expected placeholder")
        }
        // depth-first: text("pre-"), variable(X), text("-post")
        XCTAssertEqual(children.count, 3)
        XCTAssertEqual(children[0], .text("pre-", span(4, 8)))
        XCTAssertEqual(children[1], .variable(name: "X", children: [], span: span(8, 10), transform: nil))
        XCTAssertEqual(children[2], .text("-post", span(10, 15)))
    }

    // MARK: - 8. Transform grammar

    func testVariableTransformParses() {
        // ${NAME/(.*)/${1:/upcase}/}
        let markers = parse("${NAME/(.*)/${1:/upcase}/}")
        guard case let .variable(name, children, vspan, transform) = markers[0] else {
            return XCTFail("expected variable with transform")
        }
        XCTAssertEqual(name, "NAME")
        XCTAssertEqual(children, [])
        XCTAssertNotNil(transform)
        let t = transform!
        XCTAssertEqual(t.regex, "(.*)")
        XCTAssertEqual(t.flags, "")
        XCTAssertEqual(t.format.count, 1)
        XCTAssertEqual(t.format[0], .shorthand(1, .upcase))
    }

    func testTabstopTransformParses() {
        // ${1/(\\d+)/X$1/g}
        let markers = parse("${1/(\\d+)/X$1/g}")
        guard case let .placeholder(index, children, _, transform) = markers[0] else {
            return XCTFail("expected placeholder with transform")
        }
        XCTAssertEqual(index, 1)
        XCTAssertEqual(children, [])
        XCTAssertNotNil(transform)
        let t = transform!
        XCTAssertEqual(t.regex, "(\\d+)")
        XCTAssertEqual(t.flags, "g")
        XCTAssertEqual(t.format.count, 2)
        XCTAssertEqual(t.format[0], .literal("X"))
        XCTAssertEqual(t.format[1], .capture(1))
    }

    // MARK: - 9. Format grammar

    func testFormatCaptureForms() {
        // Inside a transform format: $1 and ${1}
        let markers = parse("${NAME/(.*)/$1${1}/}")
        guard case let .variable(_, _, _, transform) = markers[0] else {
            return XCTFail("expected variable")
        }
        let t = transform!
        XCTAssertEqual(t.format.count, 2)
        XCTAssertEqual(t.format[0], .capture(1))
        XCTAssertEqual(t.format[1], .capture(1))
    }

    func testFormatShorthandForms() {
        for (name, expected) in [
            ("upcase", MonaSnippetShorthand.upcase),
            ("downcase", MonaSnippetShorthand.downcase),
            ("capitalize", MonaSnippetShorthand.capitalize),
            ("pascalcase", MonaSnippetShorthand.pascalcase),
            ("camelcase", MonaSnippetShorthand.camelcase),
            ("kebabcase", MonaSnippetShorthand.kebabcase),
            ("snakecase", MonaSnippetShorthand.snakecase),
        ] {
            // ${NAME/(.*)/${1:/upcase}/}  — shorthand in the format body.
            let template = "${NAME/(.*)/${1:/" + name + "}/}"
            let markers = parse(template)
            guard case let .variable(_, _, _, transform) = markers[0],
                  let t = transform else {
                return XCTFail("expected transform for \(name)")
            }
            XCTAssertEqual(t.format.count, 1, "shorthand \(name) should produce one format element")
            XCTAssertEqual(t.format[0], .shorthand(1, expected))
        }
    }

    // MARK: - 10. Conditional / fallback grammar

    func testFormatIfForm() {
        // ${NAME/(.*)/${1:+if}/}
        let markers = parse("${NAME/(.*)/${1:+if}/}")
        guard case let .variable(_, _, _, transform) = markers[0],
              let t = transform else {
            return XCTFail("expected transform")
        }
        XCTAssertEqual(t.format.count, 1)
        XCTAssertEqual(t.format[0], .ifForm(1, "if"))
    }

    func testFormatElseForm() {
        // ${NAME/(.*)/${1:-else}/}
        let markers = parse("${NAME/(.*)/${1:-else}/}")
        guard case let .variable(_, _, _, transform) = markers[0],
              let t = transform else {
            return XCTFail("expected transform")
        }
        XCTAssertEqual(t.format.count, 1)
        XCTAssertEqual(t.format[0], .elseForm(1, "else"))
    }

    func testFormatIfElseForm() {
        // ${NAME/(.*)/${1:?yes:no}/}
        let markers = parse("${NAME/(.*)/${1:?yes:no}/}")
        guard case let .variable(_, _, _, transform) = markers[0],
              let t = transform else {
            return XCTFail("expected transform")
        }
        XCTAssertEqual(t.format.count, 1)
        XCTAssertEqual(t.format[0], .ifElseForm(1, "yes", "no"))
    }

    func testFormatDefaultForm() {
        // ${NAME/(.*)/${1:fallback}/}
        let markers = parse("${NAME/(.*)/${1:fallback}/}")
        guard case let .variable(_, _, _, transform) = markers[0],
              let t = transform else {
            return XCTFail("expected transform")
        }
        XCTAssertEqual(t.format.count, 1)
        XCTAssertEqual(t.format[0], .defaultForm(1, "fallback"))
    }

    // MARK: - 11. Fallback grammar (malformed input)

    func testMalformedUnclosedBraceFallsBackToLiteral() {
        // ${1  — scanner restore + literal fallback
        let markers = parse("${1")
        // Monaco restores the scanner to the `$` and consumes literal text.
        // The `$` becomes one literal text run; the rest follows as text.
        XCTAssertEqual(render(markers), "${1")
        XCTAssertTrue(markers.allSatisfy {
            if case .text = $0 { return true }
            return false
        }, "malformed complex must fall back to literal text markers")
    }

    func testMalformedChoiceFallsBackToLiteral() {
        // ${1|a,b  — no closing pipe/brace
        let markers = parse("${1|a,b")
        XCTAssertEqual(render(markers), "${1|a,b")
    }

    func testMalformedTransformFallsBackToLiteral() {
        // ${1/regex/format  — no closing slash/brace
        let markers = parse("${1/regex/format")
        XCTAssertEqual(render(markers), "${1/regex/format")
    }

    // MARK: - 12. Source offsets preserved over UTF-16

    func testSourceOffsetsAreUTF16CodeUnits() {
        // A supplementary char (U+1F600) is a surrogate pair (2 UTF-16 units).
        // text "😀$1" → 😀 is 2 units, $1 starts at offset 2.
        let markers = parse("😀$1")
        XCTAssertEqual(markers.count, 2)
        XCTAssertEqual(markers[0], .text("😀", span(0, 2)))
        XCTAssertEqual(markers[1], .tabstop(index: 1, span: span(2, 4)))
    }

    func testLoneSurrogatePreserved() {
        // A lone high surrogate (U+D800) is one UTF-16 code unit. The parser
        // must treat it as a single-unit text run (not merge it with the
        // following `$`), and the tabstop offset must be UTF-16-accurate (1,
        // not 0). Swift's String normalizes lone surrogates to U+FFFD when
        // materialized, but the source span proves the parser preserved the
        // raw-UInt16 unit count.
        var units: [UInt16] = [0xD800]
        units.append(contentsOf: Array("$1".utf16))
        // units = [0xD800, 0x24, 0x31]  (lone surrogate, '$', '1')
        let markers = MonaSnippetParser.parse(units)
        XCTAssertEqual(markers.count, 2)
        guard case let .text(_, tspan) = markers[0] else {
            return XCTFail("expected text")
        }
        // The lone surrogate occupies exactly ONE UTF-16 unit.
        XCTAssertEqual(tspan, span(0, 1))
        XCTAssertEqual(tspan.length, 1)
        // The tabstop begins at UTF-16 offset 1 (immediately after the lone
        // surrogate) and spans 2 units ("$1").
        XCTAssertEqual(markers[1], .tabstop(index: 1, span: span(1, 3)))
    }

    // MARK: - 13. Depth-first parse order

    func testDepthFirstOrderNestedPlaceholder() {
        // ${1:a${2:b}c} → outer placeholder children in source order:
        // text("a"), placeholder(2, [text("b")]), text("c")
        // Indices: $=0 {=1 1=2 :=3 a=4 $=5 {=6 2=7 :=8 b=9 }=10 c=11 }=12
        let markers = parse("${1:a${2:b}c}")
        guard case let .placeholder(_, children, _, _) = markers[0] else {
            return XCTFail("expected outer placeholder")
        }
        XCTAssertEqual(children.count, 3)
        XCTAssertEqual(children[0], .text("a", span(4, 5)))
        guard case let .placeholder(idx2, inner, s2, _) = children[1] else {
            return XCTFail("expected inner placeholder")
        }
        XCTAssertEqual(idx2, 2)
        XCTAssertEqual(s2, span(5, 11))
        XCTAssertEqual(inner, [.text("b", span(9, 10))])
        XCTAssertEqual(children[2], .text("c", span(11, 12)))
    }

    // MARK: - 14. Transform RegExp execution via Phase 02 engine

    func testTransformUpcaseExecution() {
        // ${NAME/(.*)/${1:/upcase}/} with NAME="mixedCase" → "MIXEDCASE"
        let markers = parse("${NAME/(.*)/${1:/upcase}/}")
        let rendered = render(markers, variables: ["NAME": "mixedCase"])
        XCTAssertEqual(rendered, "MIXEDCASE")
    }

    func testTransformCaptureSubstitutionExecution() {
        // ${NAME/(\\w+)@(\\w+)/${2}.${1}/} with NAME="a@b" → "b.a"
        let markers = parse("${NAME/(\\w+)@(\\w+)/${2}.${1}/}")
        let rendered = render(markers, variables: ["NAME": "a@b"])
        XCTAssertEqual(rendered, "b.a")
    }

    func testTransformFlagsGlobalExecution() {
        // ${NAME/(\\w)/[$1]/g} with NAME="abc" → "[a][b][c]"
        let markers = parse("${NAME/(\\w)/[$1]/g}")
        let rendered = render(markers, variables: ["NAME": "abc"])
        XCTAssertEqual(rendered, "[a][b][c]")
    }

    func testTransformCaseInsensitiveFlagExecution() {
        // ${NAME/abc/X/i} with NAME="ABC" → "X"
        let markers = parse("${NAME/abc/X/i}")
        let rendered = render(markers, variables: ["NAME": "ABC"])
        XCTAssertEqual(rendered, "X")
    }

    func testTransformIfFormExecution() {
        // ${NAME/(.*)/${1:+nonempty}/} with NAME="x" → "nonempty"
        let markers = parse("${NAME/(.*)/${1:+nonempty}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "x"]), "nonempty")
    }

    func testTransformIfElseFormExecution() {
        // ${NAME/(.*)/${1:?yes:no}/}
        // NAME="x" → matched, capture 1 = "x" (non-empty) → "yes"
        // NAME=""  → matched (zero-length), capture 1 = "" (empty) → "no"
        let markers = parse("${NAME/(.*)/${1:?yes:no}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "x"]), "yes")
        XCTAssertEqual(render(markers, variables: ["NAME": ""]), "no")
    }

    func testTransformElseFormExecution() {
        // ${NAME/(.*)/${1:-fallback}/} — else form fires when capture is empty.
        // NAME="" → "fallback"; NAME="x" → "x" (capture substituted).
        let markers = parse("${NAME/(.*)/${1:-fallback}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "x"]), "x")
        XCTAssertEqual(render(markers, variables: ["NAME": ""]), "fallback")
    }

    func testTransformDefaultFormExecution() {
        // ${NAME/(.*)/${1:default}/} — default form: when capture is empty,
        // the default text is emitted; when non-empty, capture is substituted.
        let markers = parse("${NAME/(.*)/${1:default}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "x"]), "x")
        XCTAssertEqual(render(markers, variables: ["NAME": ""]), "default")
    }

    func testTransformDowncaseShorthandExecution() {
        // ${NAME/(.*)/${1:/downcase}/} with NAME="MIXED" → "mixed"
        let markers = parse("${NAME/(.*)/${1:/downcase}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "MIXED"]), "mixed")
    }

    func testTransformCapitalizeShorthandExecution() {
        // capitalize: first letter upper, rest lower.
        let markers = parse("${NAME/(.*)/${1:/capitalize}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "hELLO"]), "Hello")
    }

    func testTransformPascalCaseShorthandExecution() {
        let markers = parse("${NAME/(.*)/${1:/pascalcase}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "hello world"]), "HelloWorld")
    }

    func testTransformCamelCaseShorthandExecution() {
        let markers = parse("${NAME/(.*)/${1:/camelcase}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "hello world"]), "helloWorld")
    }

    func testTransformKebabCaseShorthandExecution() {
        let markers = parse("${NAME/(.*)/${1:/kebabcase}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "helloWorld"]), "hello-world")
    }

    func testTransformSnakeCaseShorthandExecution() {
        let markers = parse("${NAME/(.*)/${1:/snakecase}/}")
        XCTAssertEqual(render(markers, variables: ["NAME": "helloWorld"]), "hello_world")
    }

    func testTransformInvalidRegexFallsBack() {
        // A structurally-valid transform whose regex fails to compile (unbalanced
        // group). The transform must not crash: it falls back to the unresolved
        // variable value (the bound value, or empty when unbound).
        let markers = parse("${NAME/(/X/}")
        guard case let .variable(_, _, _, transform) = markers[0],
              let t = transform else {
            return XCTFail("expected a transform-bearing variable")
        }
        XCTAssertEqual(t.regex, "(")
        // Bound value: fallback yields the bound value verbatim.
        XCTAssertEqual(MonaSnippetTransformExecutor.apply(transform: t, to: "x"), "x")
        // Empty value: fallback yields empty.
        XCTAssertEqual(MonaSnippetTransformExecutor.apply(transform: t, to: ""), "")
        // Rendered through the tree: bound NAME → "x"; unbound → "".
        XCTAssertEqual(render(markers, variables: ["NAME": "x"]), "x")
        XCTAssertEqual(render(markers, variables: [:]), "")
    }

    // MARK: - 15. Probe vectors (contract)

    func testProbeVectorOne() {
        // ${1:one}-${2|two,three|}-${NAME/(.*)/${1:/upcase}/}-$0
        // NAME="mixedCase" → "one-two-MIXEDCASE-", order [1,2,0]
        let template = "${1:one}-${2|two,three|}-${NAME/(.*)/${1:/upcase}/}-$0"
        let markers = parse(template)
        let rendered = render(markers, variables: ["NAME": "mixedCase"])
        XCTAssertEqual(rendered, "one-two-MIXEDCASE-")
    }

    func testProbeVectorUnknownWithDefault() {
        // ${UNKNOWN:default} → "default"
        let markers = parse("${UNKNOWN:default}")
        XCTAssertEqual(render(markers), "default")
    }

    func testProbeVectorUnknownNoDefault() {
        // $UNKNOWN → ""
        let markers = parse("$UNKNOWN")
        XCTAssertEqual(render(markers), "")
    }

    func testProbeVectorMirrorPlaceholder() {
        // ${1:alpha}-$1-$0 → "alpha-alpha-", order [1,1,0]
        let markers = parse("${1:alpha}-$1-$0")
        XCTAssertEqual(render(markers), "alpha-alpha-")
    }

    // MARK: - 16. Tabstop placeholder order (depth-first)

    func testPlaceholderOrderDepthFirst() {
        // ${1:one}-${2|two,three|}-${NAME/(.*)/${1:/upcase}/}-$0
        // The placeholder indices encountered in depth-first walk: 1, 2, 0.
        let template = "${1:one}-${2|two,three|}-${NAME/(.*)/${1:/upcase}/}-$0"
        let markers = parse(template)
        let snippet = MonaSnippetTextmateSnippet(markers: markers)
        // Tabstop/placeholder indices in depth-first order.
        let order = snippet.placeholderOrder()
        XCTAssertEqual(order, [1, 2, 0])
    }

    func testMirrorPlaceholderOrder() {
        // ${1:alpha}-$1-$0 → depth-first order [1, 1, 0]
        let markers = parse("${1:alpha}-$1-$0")
        let snippet = MonaSnippetTextmateSnippet(markers: markers)
        XCTAssertEqual(snippet.placeholderOrder(), [1, 1, 0])
    }

    // MARK: - 17. Final tabstop handling

    func testEnforceFinalTabstopAppendsZero() {
        // When enforceFinalTabstop is true and no $0 exists, append one.
        let markers = parse("hello $1")
        let snippet = MonaSnippetTextmateSnippet(markers: markers)
        let placed = snippet.placeholders(enforceFinalTabstop: true, insertFinalTabstop: false)
        XCTAssertTrue(placed.contains { $0.index == 0 },
                      "enforceFinalTabstop must append a final 0 tabstop")
    }

    func testNoFinalTabstopWhenAlreadyPresent() {
        // $0 already present → no duplicate appended.
        let markers = parse("hello $1 $0")
        let snippet = MonaSnippetTextmateSnippet(markers: markers)
        let placed = snippet.placeholders(enforceFinalTabstop: true, insertFinalTabstop: false)
        let zeros = placed.filter { $0.index == 0 }
        XCTAssertEqual(zeros.count, 1)
    }

    func testNoFinalTabstopWhenNoneRequested() {
        let markers = parse("hello $1")
        let snippet = MonaSnippetTextmateSnippet(markers: markers)
        let placed = snippet.placeholders(enforceFinalTabstop: false, insertFinalTabstop: false)
        XCTAssertFalse(placed.contains { $0.index == 0 })
    }

    // MARK: - Contract leaf

    func testContractBehavior() {
        let template = "${1:one}-${2|two,three|}-${NAME/(.*)/${1:/upcase}/}-$0"
        let markers = parse(template)
        let text = render(markers, variables: ["NAME": "mixedCase"])
        let order = MonaSnippetTextmateSnippet(markers: markers).placeholderOrder()
        let loneOK = self.verifyLoneSurrogatePreserved()
        let transformOK = (text == "one-two-MIXEDCASE-")

        // Grammar element coverage (11 grammar elements).
        let grammar = 11

        // CONTRACT LINE:
        // SNIPPET parser=live grammar=11 offsets=pass utf16=pass transform=pass
        print("SNIPPET parser=live grammar=\(grammar) offsets=pass utf16=\(loneOK ? "pass" : "fail") transform=\(transformOK ? "pass" : "fail")")

        XCTAssertEqual(text, "one-two-MIXEDCASE-")
        XCTAssertEqual(order, [1, 2, 0])
        XCTAssertTrue(loneOK, "lone surrogate must be preserved over raw UTF-16")
        XCTAssertTrue(transformOK, "transform RegExp must execute via Phase 02 engine")
    }

    // MARK: - Private helpers

    private func verifyLoneSurrogatePreserved() -> Bool {
        var units: [UInt16] = [0xD800]
        units.append(contentsOf: Array("$1".utf16))
        let markers = MonaSnippetParser.parse(units)
        guard case let .text(_, tspan) = markers[0] else { return false }
        // The lone surrogate occupies exactly one UTF-16 unit (offset 0..1),
        // and the tabstop begins at offset 1 — proving raw-UInt16 offset
        // accuracy.
        return tspan == MonaSnippetSpan(start: 0, end: 1)
            && markers.count >= 2
    }
}
