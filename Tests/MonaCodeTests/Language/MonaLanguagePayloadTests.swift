// MonaLanguagePayloadTests.swift
//
// LANG-001 (Task 3: LANGUAGE payload) — Behavior test for the nine retained
// languages provider context / result declarations exposed by the public API.
//
// Verifies that `MonaLanguagesCodeActionContext`, `MonaLanguagesProviderResult`,
// `MonaLanguagesHoverContext`, `MonaLanguagesCompletionContext`,
// `MonaLanguagesInlineCompletionContext`, `MonaLanguagesSignatureHelpResult`,
// `MonaLanguagesSignatureHelpContext`, `MonaLanguagesReferenceContext`, and
// `MonaLanguagesFoldingContext` declare concrete payload members (not
// zero-member shells), and that a concrete conforming type carries its
// `trigger` / `value` / `verbosity` / `triggerKind` / `maxRanges` /
// `includeDeclaration` through the protocol witness (or, for the result
// struct, through its public stored property).
//
// This is an exit-only behavior test (Ruling I): it guards against the
// declarations collapsing back to empty `{}` shells by asserting the payload
// is readable through the protocol type — a conformance that lacks the
// required member would not compile, and an empty protocol would offer no
// payload to read.

import XCTest
import MonaCode

final class MonaLanguagePayloadTests: XCTestCase {

    // MARK: - CodeActionContext

    /// A concrete code-action context carrying its trigger-kind sentinel. The
    /// `let` stored property satisfies the protocol's `{ get }` requirement.
    // monaco cross-reference: `languages.CodeActionContext` (markers/only);
    // MonaCode retains a `trigger: Int` trigger-kind payload for the port.
    private struct TestCodeActionContext: MonaLanguagesCodeActionContext {
        let trigger: Int
    }

    func testCodeActionContextCarriesTriggerThroughProtocol() {
        let context: MonaLanguagesCodeActionContext = TestCodeActionContext(trigger: 2)

        // The trigger kind is readable through the protocol witness.
        XCTAssertEqual(context.trigger, 2,
                       "CodeActionContext: trigger carries through the protocol")
    }

    func testCodeActionContextSupportsZeroTriggerKind() {
        // 0 is the "automatic"/unknown sentinel retained by the port contract.
        let context: MonaLanguagesCodeActionContext = TestCodeActionContext(trigger: 0)
        XCTAssertEqual(context.trigger, 0,
                       "CodeActionContext: triggerKind=0 preserves the automatic sentinel")
    }

    // MARK: - ProviderResult

    // monaco cross-reference: `ProviderResult<T>` (T | undefined | null |
    // Thenable); MonaCode type-erases to `value: Any` on a concrete struct.
    func testProviderResultCarriesValueThroughStoredProperty() {
        let result = MonaLanguagesProviderResult(value: "sig-help" as Any)

        // The wrapped value is readable through the struct's public property.
        XCTAssertEqual(result.value as? String, "sig-help",
                       "ProviderResult: value carries through the public stored property")
    }

    func testProviderResultWrapsArbitraryPayload() {
        // Any-typed value: a numeric payload survives the round-trip.
        let result = MonaLanguagesProviderResult(value: 42 as Any)
        XCTAssertEqual(result.value as? Int, 42,
                       "ProviderResult: numeric value preserved through Any erasure")
    }

    // MARK: - HoverContext

    // monaco cross-reference: `HoverContext` (verbosityRequest?); MonaCode
    // retains a `verbosity: Int` request level payload.
    private struct TestHoverContext: MonaLanguagesHoverContext {
        let verbosity: Int
    }

    func testHoverContextCarriesVerbosityThroughProtocol() {
        let context: MonaLanguagesHoverContext = TestHoverContext(verbosity: 1)
        XCTAssertEqual(context.verbosity, 1,
                       "HoverContext: verbosity carries through the protocol")
    }

    // MARK: - CompletionContext

    // monaco cross-reference: `CompletionContext.triggerKind`
    // (CompletionTriggerKind); MonaCode retains it as `triggerKind: Int`.
    private struct TestCompletionContext: MonaLanguagesCompletionContext {
        let triggerKind: Int
    }

    func testCompletionContextCarriesTriggerKindThroughProtocol() {
        let context: MonaLanguagesCompletionContext = TestCompletionContext(triggerKind: 1)
        XCTAssertEqual(context.triggerKind, 1,
                       "CompletionContext: triggerKind carries through the protocol")
    }

    // MARK: - InlineCompletionContext

    // monaco cross-reference: `InlineCompletionContext.triggerKind`
    // (InlineCompletionTriggerKind); MonaCode retains it as `triggerKind: Int`.
    private struct TestInlineCompletionContext: MonaLanguagesInlineCompletionContext {
        let triggerKind: Int
    }

    func testInlineCompletionContextCarriesTriggerKindThroughProtocol() {
        let context: MonaLanguagesInlineCompletionContext =
            TestInlineCompletionContext(triggerKind: 0)
        XCTAssertEqual(context.triggerKind, 0,
                       "InlineCompletionContext: triggerKind carries through the protocol")
    }

    // MARK: - SignatureHelpResult

    // monaco cross-reference: `SignatureHelpResult.value` (SignatureHelp);
    // MonaCode type-erases to `value: Any { get }`.
    private struct TestSignatureHelpResult: MonaLanguagesSignatureHelpResult {
        let value: Any
    }

    func testSignatureHelpResultCarriesValueThroughProtocol() {
        let result: MonaLanguagesSignatureHelpResult =
            TestSignatureHelpResult(value: "signatures" as Any)
        XCTAssertEqual(result.value as? String, "signatures",
                       "SignatureHelpResult: value carries through the protocol witness")
    }

    // MARK: - SignatureHelpContext

    // monaco cross-reference: `SignatureHelpContext.triggerKind`
    // (SignatureHelpTriggerKind); MonaCode retains it as `triggerKind: Int`.
    private struct TestSignatureHelpContext: MonaLanguagesSignatureHelpContext {
        let triggerKind: Int
    }

    func testSignatureHelpContextCarriesTriggerKindThroughProtocol() {
        let context: MonaLanguagesSignatureHelpContext =
            TestSignatureHelpContext(triggerKind: 1)
        XCTAssertEqual(context.triggerKind, 1,
                       "SignatureHelpContext: triggerKind carries through the protocol")
    }

    // MARK: - ReferenceContext

    // monaco cross-reference: `ReferenceContext.includeDeclaration: boolean`;
    // MonaCode retains it as `includeDeclaration: Bool { get }`.
    private struct TestReferenceContext: MonaLanguagesReferenceContext {
        let includeDeclaration: Bool
    }

    func testReferenceContextCarriesIncludeDeclarationThroughProtocol() {
        let context: MonaLanguagesReferenceContext =
            TestReferenceContext(includeDeclaration: true)
        XCTAssertEqual(context.includeDeclaration, true,
                       "ReferenceContext: includeDeclaration carries through the protocol")
    }

    func testReferenceContextExcludesDeclarationWhenFalse() {
        let context: MonaLanguagesReferenceContext =
            TestReferenceContext(includeDeclaration: false)
        XCTAssertFalse(context.includeDeclaration,
                       "ReferenceContext: includeDeclaration=false excludes the declaration")
    }

    // MARK: - FoldingContext

    // monaco cross-reference: `FoldingContext` (empty in monaco); MonaCode
    // retains a `maxRanges: Int` cap payload for the port's folding adapter.
    private struct TestFoldingContext: MonaLanguagesFoldingContext {
        let maxRanges: Int
    }

    func testFoldingContextCarriesMaxRangesThroughProtocol() {
        let context: MonaLanguagesFoldingContext = TestFoldingContext(maxRanges: 1000)
        XCTAssertEqual(context.maxRanges, 1000,
                       "FoldingContext: maxRanges carries through the protocol")
    }
}
