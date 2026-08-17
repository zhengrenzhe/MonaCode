// MonaPasteboardTests.swift
//
// P04-T008 — Implement copy, cut, paste, and paste-edit pipelines.
//
// Verifies the two AppKit transfer types that carry clipboard content through
// the editor boundary:
//
//   - `MonaPasteboardGateway` — the single native gateway that reads and writes
//                               the pasteboard (NSPasteboard). Handles plain-text
//                               (NSString), rich-text (NSAttributedString), and
//                               editor metadata (a custom MonaCode clipboard format
//                               carrying selection / range info). Read:
//                               `read() -> MonaClipboardContent?`. Write:
//                               `write(_ content: MonaClipboardContent)`.
//   - `MonaPasteEditPipeline`  — runs direct paste-edit providers in deterministic
//                               order. Each provider transforms the clipboard
//                               content before insertion. Supports cancellation
//                               (via MonaCancellationToken from P01-T006) and
//                               validity tickets (from P01-T010
//                               MonaAsyncValidityTicket). Commits cut and
//                               multi-cursor paste through the model input
//                               barrier (P04-T005 MonaModelInputBarrier).
//
// Test contract (P04-T008): read/write exact retained representations;
// paste-edit providers in deterministic order under cancellation and validity
// tickets; cut + multi-cursor paste through the model input barrier.

import XCTest
import AppKit
import MonaCode
@testable import MonaCodeAppKit

final class MonaPasteboardTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a fresh, uniquely-named `NSPasteboard` so tests never collide
    /// with the system pasteboard or each other.
    private func makePasteboard() -> NSPasteboard {
        return NSPasteboard(name: NSPasteboard.Name("MonaPasteboardTest-\(UUID().uuidString)"))
    }

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/m"))
    }

    private func pos(_ line: Int, _ column: Int) -> MonaPosition {
        return MonaPosition(line: line, column: column)
    }

    private func selection(_ sl: Int, _ sc: Int, _ el: Int, _ ec: Int) -> MonaSelection {
        return MonaSelection(
            startPosition: pos(sl, sc),
            endPosition: pos(el, ec),
            orientation: .forward
        )
    }

    private func makeRichText(_ string: String, bold: Bool = false) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = bold
            ? [.font: NSFont.boldSystemFont(ofSize: 12)]
            : [.font: NSFont.systemFont(ofSize: 12)]
        return NSAttributedString(string: string, attributes: attrs)
    }

    // MARK: - MonaPasteboardGateway: plain-text round-trip

    /// Writing plain-text content and reading it back preserves the exact
    /// retained plain-text representation.
    func testPlainTextRoundTrip() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        let content = MonaClipboardContent(
            plainText: "line one\nline two",
            richText: nil,
            metadata: nil
        )
        gateway.write(content)

        guard let read = gateway.read() else {
            return XCTFail("read() returned nil after writing plain-text")
        }
        XCTAssertEqual(read.plainText, "line one\nline two")
        XCTAssertNil(read.metadata)
    }

    // MARK: - MonaPasteboardGateway: rich-text round-trip

    /// Writing rich-text content and reading it back preserves the exact
    /// retained rich-text representation (string + attributes).
    func testRichTextRoundTrip() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        let rich = makeRichText("hello bold", bold: true)
        let content = MonaClipboardContent(
            plainText: "hello bold",
            richText: rich,
            metadata: nil
        )
        gateway.write(content)

        guard let read = gateway.read() else {
            return XCTFail("read() returned nil after writing rich-text")
        }
        XCTAssertEqual(read.plainText, "hello bold")
        XCTAssertEqual(read.richTextString, "hello bold")
        XCTAssertNotNil(read.richText)
        // The bold attribute is preserved across the round-trip.
        let boldRange = NSRange(location: 0, length: "hello bold".utf16.count)
        let boldAttr = read.richText?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(boldAttr)
        let isBold = read.richText?.attribute(.font, at: 0, longestEffectiveRange: nil, in: boldRange) as? NSFont
        XCTAssertNotNil(isBold)
    }

    // MARK: - MonaPasteboardGateway: editor metadata round-trip

    /// Writing editor metadata (custom MonaCode clipboard format with selection
    /// / range info) and reading it back preserves the exact retained metadata.
    func testEditorMetadataRoundTrip() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        let metadata = MonaClipboardEditorMetadata(
            sourceModelId: "inmemory:/m",
            sourceVersionId: 7,
            selectionAnchorLine: 1,
            selectionAnchorColumn: 1,
            selectionActiveLine: 2,
            selectionActiveColumn: 5
        )
        let content = MonaClipboardContent(
            plainText: "selected text",
            richText: nil,
            metadata: metadata
        )
        gateway.write(content)

        guard let read = gateway.read() else {
            return XCTFail("read() returned nil after writing metadata")
        }
        XCTAssertEqual(read.plainText, "selected text")
        XCTAssertEqual(read.metadata, metadata)
    }

    // MARK: - MonaPasteboardGateway: all three representations together

    /// Writing plain-text + rich-text + metadata together reads all three back.
    func testAllThreeRepresentationsRoundTrip() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        let metadata = MonaClipboardEditorMetadata(
            sourceModelId: "inmemory:/m",
            sourceVersionId: 3,
            selectionAnchorLine: 1,
            selectionAnchorColumn: 1,
            selectionActiveLine: 1,
            selectionActiveColumn: 4
        )
        let content = MonaClipboardContent(
            plainText: "abc",
            richText: makeRichText("abc", bold: true),
            metadata: metadata
        )
        gateway.write(content)

        guard let read = gateway.read() else {
            return XCTFail("read() returned nil")
        }
        XCTAssertEqual(read.plainText, "abc")
        XCTAssertEqual(read.richTextString, "abc")
        XCTAssertEqual(read.metadata, metadata)
    }

    // MARK: - MonaPasteboardGateway: empty pasteboard reads nil

    /// Reading an empty pasteboard returns nil.
    func testReadEmptyPasteboardReturnsNil() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        XCTAssertNil(gateway.read())
    }

    // MARK: - MonaPasteboardGateway: write with only metadata

    /// Writing only metadata (no plain-text, no rich-text) reads the metadata
    /// back; the plain-text is nil.
    func testWriteOnlyMetadata() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        let metadata = MonaClipboardEditorMetadata(
            sourceModelId: "inmemory:/m",
            sourceVersionId: 1,
            selectionAnchorLine: 1,
            selectionAnchorColumn: 1,
            selectionActiveLine: 1,
            selectionActiveColumn: 1
        )
        gateway.write(MonaClipboardContent(plainText: nil, richText: nil, metadata: metadata))

        guard let read = gateway.read() else {
            return XCTFail("read() returned nil")
        }
        XCTAssertEqual(read.metadata, metadata)
        XCTAssertNil(read.plainText)
    }

    // MARK: - MonaPasteEditPipeline: providers run in registration order

    /// Registered providers run in deterministic registration order; each
    /// provider receives the output of the previous provider.
    func testProvidersRunInRegistrationOrder() {
        let pipeline = MonaPasteEditPipeline()
        pipeline.register(RecordingProvider(id: "P1", transform: { content in
            return MonaClipboardContent(
                plainText: (content.plainText ?? "") + "->P1",
                richText: nil,
                metadata: content.metadata
            )
        }))
        pipeline.register(RecordingProvider(id: "P2", transform: { content in
            return MonaClipboardContent(
                plainText: (content.plainText ?? "") + "->P2",
                richText: nil,
                metadata: content.metadata
            )
        }))

        let input = MonaClipboardContent(plainText: "START", richText: nil, metadata: nil)
        guard let result = pipeline.run(input) else {
            return XCTFail("pipeline returned nil")
        }
        XCTAssertEqual(result.plainText, "START->P1->P2")
    }

    // MARK: - MonaPasteEditPipeline: no providers passes content through

    /// With no registered providers, the pipeline passes the content through
    /// unchanged.
    func testNoProvidersPassesThrough() {
        let pipeline = MonaPasteEditPipeline()
        let input = MonaClipboardContent(plainText: "untouched", richText: nil, metadata: nil)
        guard let result = pipeline.run(input) else {
            return XCTFail("pipeline returned nil")
        }
        XCTAssertEqual(result.plainText, "untouched")
    }

    // MARK: - MonaPasteEditPipeline: cancellation stops the pipeline

    /// When cancellation is requested before running, the pipeline drops the
    /// content (returns nil).
    func testCancellationStopsPipeline() {
        let pipeline = MonaPasteEditPipeline()
        let cancelSource = MonaCancellationTokenSource()
        cancelSource.cancel()
        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(pipeline.run(input, cancellationToken: cancelSource.token))
    }

    /// When cancellation is requested MID-pipeline (a provider observes it),
    /// the pipeline stops at that provider and returns nil.
    func testCancellationMidPipelineStopsRemainingProviders() {
        let pipeline = MonaPasteEditPipeline()
        let cancelSource = MonaCancellationTokenSource()
        var p2Ran = false
        pipeline.register(RecordingProvider(id: "P1", transform: { content in
            cancelSource.cancel()
            return content
        }))
        pipeline.register(RecordingProvider(id: "P2", transform: { content in
            p2Ran = true
            return content
        }))
        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(pipeline.run(input, cancellationToken: cancelSource.token))
        XCTAssertFalse(p2Ran, "P2 must not run after P1 cancelled")
    }

    // MARK: - MonaPasteEditPipeline: a provider returning nil cancels the paste

    /// When a provider returns nil (explicitly drops the paste), the pipeline
    /// stops and returns nil; subsequent providers do not run.
    func testProviderReturningNilCancelsPaste() {
        let pipeline = MonaPasteEditPipeline()
        var p2Ran = false
        pipeline.register(RecordingProvider(id: "dropper", transform: { _ in nil }))
        pipeline.register(RecordingProvider(id: "P2", transform: { content in
            p2Ran = true
            return content
        }))
        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(pipeline.run(input))
        XCTAssertFalse(p2Ran)
    }

    // MARK: - MonaPasteEditPipeline: stale validity ticket drops the paste

    /// When the validity ticket is stale (the gate reports it invalid), the
    /// pipeline drops the content before running any provider.
    func testStaleValidityTicketDropsPaste() {
        let model = makeModel("hello")
        let gate = MonaPublicationGate(model: model)
        // Capture a ticket, then mutate the model so the ticket goes stale.
        let ticket = gate.captureTicket()
        model.setValue("changed")

        let pipeline = MonaPasteEditPipeline()
        pipeline.register(RecordingProvider(id: "P1", transform: { content in content }))
        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(pipeline.run(input, gate: gate, ticket: ticket))
    }

    /// When the validity ticket is fresh, the pipeline runs all providers.
    func testFreshValidityTicketRunsProviders() {
        let model = makeModel("hello")
        let gate = MonaPublicationGate(model: model)
        let ticket = gate.captureTicket()

        let pipeline = MonaPasteEditPipeline()
        pipeline.register(RecordingProvider(id: "P1", transform: { content in
            return MonaClipboardContent(
                plainText: (content.plainText ?? "") + "!",
                richText: nil,
                metadata: content.metadata
            )
        }))
        let input = MonaClipboardContent(plainText: "hi", richText: nil, metadata: nil)
        guard let result = pipeline.run(input, gate: gate, ticket: ticket) else {
            return XCTFail("pipeline returned nil on a fresh ticket")
        }
        XCTAssertEqual(result.plainText, "hi!")
    }

    // MARK: - MonaPasteEditPipeline: multi-cursor paste through the barrier

    /// A multi-cursor clipboard paste commits through the model input barrier:
    /// every cursor receives the pasted text, and the barrier publishes all
    /// edits in one transaction.
    func testMultiCursorPasteCommitsThroughBarrier() {
        let model = makeModel("aaa\nbbb\nccc")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()

        let outcome = pipeline.commitMultiCursorPaste(
            text: "X",
            cursorPositions: [pos(1, 2), pos(2, 2), pos(3, 2)],
            barrier: barrier
        )

        guard case .applied(let selections) = outcome else {
            return XCTFail("expected .applied, got \(outcome)")
        }
        XCTAssertEqual(selections.count, 3)
        XCTAssertEqual(model.getValue(), "aXaa\nbXbb\ncXcc")
    }

    // MARK: - MonaPasteEditPipeline: multi-cursor paste single cursor

    /// A single-cursor paste commits the text at that cursor.
    func testSingleCursorPasteCommits() {
        let model = makeModel("hello")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()

        let outcome = pipeline.commitMultiCursorPaste(
            text: ">>",
            cursorPositions: [pos(1, 3)],
            barrier: barrier
        )
        guard case .applied = outcome else {
            return XCTFail("expected .applied, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "he>>llo")
    }

    // MARK: - MonaPasteEditPipeline: multi-cursor paste rollback on overlap

    /// When two cursors produce overlapping edits (reject policy), the barrier
    /// rolls back the whole batch: the model is untouched.
    func testMultiCursorPasteRollbackOnOverlap() {
        let model = makeModel("abcdef")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()

        // Two cursors whose paste ranges overlap: cursor at (1,2) replaces
        // cols 2..4 with "X", cursor at (1,3) replaces cols 3..5 with "Y".
        // These overlap, so the barrier rolls back.
        let plan = MonaMultiCursorInputPlan(
            primary: MonaCursorInputEdit(
                range: MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 4),
                text: "X",
                kind: .clipboard
            ),
            secondary: [MonaCursorInputEdit(
                range: MonaRange(startLine: 1, startColumn: 3, endLine: 1, endColumn: 5),
                text: "Y",
                kind: .clipboard
            )]
        )
        let outcome = barrier.commit(plan, overlapPolicy: .reject)
        guard case .rolledBack = outcome else {
            return XCTFail("expected .rolledBack for overlapping paste, got \(outcome)")
        }
        // Model untouched.
        XCTAssertEqual(model.getValue(), "abcdef")
    }

    // MARK: - MonaPasteEditPipeline: cut through the barrier

    /// A cut commits through the model input barrier: every selection is
    /// deleted in one transaction.
    func testCutCommitsThroughBarrier() {
        let model = makeModel("aaa\nbbb\nccc")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()

        let outcome = pipeline.commitCut(
            selections: [
                selection(1, 2, 1, 4),   // delete "aa" on line 1 (cols 2..3)
                selection(2, 2, 2, 4),   // delete "bb" on line 2
            ],
            barrier: barrier
        )
        guard case .applied = outcome else {
            return XCTFail("expected .applied, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "a\nb\nccc")
    }

    /// Cut with a single selection deletes that selection's text.
    func testCutSingleSelection() {
        let model = makeModel("hello world")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()

        let outcome = pipeline.commitCut(
            selections: [selection(1, 7, 1, 12)],  // "world"
            barrier: barrier
        )
        guard case .applied = outcome else {
            return XCTFail("expected .applied, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "hello ")
    }

    /// Cut with no selections is a no-op applied (nothing to delete).
    func testCutNoSelectionsIsAppliedNoOp() {
        let model = makeModel("untouched")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()

        let outcome = pipeline.commitCut(selections: [], barrier: barrier)
        if case .applied = outcome {
            // ok
        } else {
            XCTFail("expected .applied for empty cut, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "untouched")
    }

    // MARK: - MonaPasteEditPipeline: paste with edit providers before barrier

    /// The paste-edit pipeline runs its providers on the clipboard content
    /// BEFORE committing the paste through the barrier: the provider's
    /// transformed text is what lands in the model.
    func testPasteEditProvidersRunBeforeBarrierCommit() {
        let model = makeModel("ab")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()
        pipeline.register(RecordingProvider(id: "upper", transform: { content in
            return MonaClipboardContent(
                plainText: content.plainText?.uppercased(),
                richText: nil,
                metadata: content.metadata
            )
        }))

        let outcome = pipeline.pasteThroughBarrier(
            text: "x",
            cursorPositions: [pos(1, 2)],
            barrier: barrier,
            cancellationToken: .none
        )
        guard case .applied = outcome else {
            return XCTFail("expected .applied, got \(outcome)")
        }
        // The provider upper-cased "x" to "X" before it was pasted.
        XCTAssertEqual(model.getValue(), "aXb")
    }

    /// When a paste-edit provider cancels (returns nil) the paste is dropped:
    /// the barrier is never invoked and the model is untouched.
    func testPasteEditProviderCancelDropsBarrierCommit() {
        let model = makeModel("ab")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()
        pipeline.register(RecordingProvider(id: "dropper", transform: { _ in nil }))

        let outcome = pipeline.pasteThroughBarrier(
            text: "x",
            cursorPositions: [pos(1, 2)],
            barrier: barrier,
            cancellationToken: .none
        )
        guard case .dropped = outcome else {
            return XCTFail("expected .dropped, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "ab")
    }

    /// When cancellation is requested, the paste is dropped: the barrier is
    /// never invoked and the model is untouched.
    func testPasteEditCancellationDropsBarrierCommit() {
        let model = makeModel("ab")
        let barrier = MonaModelInputBarrier(model: model)
        let pipeline = MonaPasteEditPipeline()
        let cancelSource = MonaCancellationTokenSource()
        cancelSource.cancel()

        let outcome = pipeline.pasteThroughBarrier(
            text: "x",
            cursorPositions: [pos(1, 2)],
            barrier: barrier,
            cancellationToken: cancelSource.token
        )
        guard case .dropped = outcome else {
            return XCTFail("expected .dropped, got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "ab")
    }
}

// MARK: - Test doubles

/// A paste-edit provider that records its invocation and delegates to a
/// closure to produce (or drop) the transformed content.
private final class RecordingProvider: MonaPasteEditProvider {
    let identifier: String
    let transform: (MonaClipboardContent) -> MonaClipboardContent?
    var invocations = 0

    init(id: String, transform: @escaping (MonaClipboardContent) -> MonaClipboardContent?) {
        self.identifier = id
        self.transform = transform
    }

    func edit(
        _ content: MonaClipboardContent,
        cancellationToken: MonaCancellationToken,
        ticket: MonaAsyncValidityTicket
    ) -> MonaClipboardContent? {
        invocations += 1
        return transform(content)
    }
}
