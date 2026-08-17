// MonaDragDropServicesTests.swift
//
// P04-T009 — Implement drag, drop, and macOS Services transfer.
//
// Verifies the two AppKit transfer types that carry drag/drop and macOS
// Services content through the editor boundary:
//
//   - `MonaDragDropGateway`  — the single native gateway that validates drag
//                              types (accepted UTI types), operation masks
//                              (copy/move/link), drop geometry (position via
//                              the geometry barrier P03-T007), direct drop-edit
//                              providers (transform content before insertion),
//                              and transfer payloads (the dropped content).
//                              Rejects stale drop geometry (model changed since
//                              the drag started) and disposes provider lists
//                              exactly once (idempotent).
//   - `MonaServicesGateway`  — maps macOS Services (NSPasteboard read/write
//                              selection) to the same transfer pipeline as
//                              copy/paste (P04-T008). `readSelection()` /
//                              `writeSelection(_:)` use the paste-edit pipeline
//                              for provider-ordered transformations.
//
// Test contract (P04-T009): drag types, operation masks, drop geometry,
// drop-edit providers, transfer payloads, stale-geometry rejection, idempotent
// disposal; Services read/write selection through the paste-edit pipeline.

import XCTest
import AppKit
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaDragDropServicesTests: XCTestCase {

    // MARK: - Shared helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// Creates a fresh, uniquely-named `NSPasteboard` so tests never collide
    /// with the system pasteboard or each other.
    private func makePasteboard() -> NSPasteboard {
        return NSPasteboard(name: NSPasteboard.Name("MonaDragDropTest-\(UUID().uuidString)"))
    }

    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/m"))
    }

    private func pos(_ line: Int, _ column: Int) -> MonaPosition {
        return MonaPosition(line: line, column: column)
    }

    /// Builds a geometry barrier over a real model + view graph + scroll model
    /// + builder (mirrors `MonaPointerScrollMenuTests.makeBarrier`).
    private func makeBarrier(
        text: String = "abc\ndef",
        lineHeight: Int = 20
    ) -> (MonaQueryGeometryBarrier, MonaCodeModel) {
        let model = MonaCodeModel(text: text, uri: MonaURI.parse("monacode:dragdrop")!)
        let viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 400, contentHeight: Double(2 * lineHeight),
            viewportWidth: 400, viewportHeight: Double(lineHeight)
        )
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let provider: (Int) -> [UInt16] = { lineNum in
            Array(model.getLineContent(lineNum).utf16)
        }
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: provider
        )
        return (barrier, model)
    }

    // MARK: - MonaDragDropGateway: accepted drag types (UTI types)

    /// The default accepted drag types include plain-text, rich-text, and file URLs.
    func testDefaultAcceptedDragTypesIncludesAllFlavors() {
        let gateway = MonaDragDropGateway()
        XCTAssertTrue(gateway.acceptedDragTypes.contains(.plainText))
        XCTAssertTrue(gateway.acceptedDragTypes.contains(.richText))
        XCTAssertTrue(gateway.acceptedDragTypes.contains(.fileURLs))
    }

    /// The accepted pasteboard types reflect the accepted drag types: plainText →
    /// .string, richText → .rtf, fileURLs → .fileURL.
    func testAcceptedPasteboardTypesReflectDragTypes() {
        let gateway = MonaDragDropGateway(
            acceptedDragTypes: [.plainText, .richText],
            acceptedOperations: [.copy]
        )
        let types = gateway.acceptedPasteboardTypes
        XCTAssertTrue(types.contains(.string))
        XCTAssertTrue(types.contains(.rtf))
        XCTAssertFalse(types.contains(.fileURL))
    }

    /// `accepts(dragTypes:)` returns true when the pasteboard carries at least
    /// one accepted type.
    func testAcceptsDragTypesReturnsTrueOnOverlap() {
        let gateway = MonaDragDropGateway(acceptedDragTypes: [.plainText], acceptedOperations: [.copy])
        XCTAssertTrue(gateway.accepts(dragTypes: [.string, .pdf]))
    }

    /// `accepts(dragTypes:)` returns false when the pasteboard carries none of
    /// the accepted types.
    func testAcceptsDragTypesReturnsFalseWhenNoOverlap() {
        let gateway = MonaDragDropGateway(acceptedDragTypes: [.richText], acceptedOperations: [.copy])
        XCTAssertFalse(gateway.accepts(dragTypes: [.string, .pdf]))
    }

    // MARK: - MonaDragDropGateway: operation masks (copy/move/link)

    /// `validate(operation:)` masks the requested operation down to the
    /// accepted operations.
    func testValidateOperationMasksToAccepted() {
        let gateway = MonaDragDropGateway(acceptedDragTypes: .all, acceptedOperations: [.copy, .link])
        let masked = gateway.validate(operation: [.copy, .move, .link])
        XCTAssertEqual(masked, [.copy, .link])
    }

    /// `validate(operation:)` returns an empty mask when none of the requested
    /// operations are accepted.
    func testValidateOperationReturnsEmptyWhenNoneAccepted() {
        let gateway = MonaDragDropGateway(acceptedDragTypes: .all, acceptedOperations: [.copy])
        let masked = gateway.validate(operation: [.move, .link])
        XCTAssertTrue(masked.isEmpty)
    }

    // MARK: - MonaDragDropGateway: drop geometry (position via geometry barrier)

    /// `resolveDropGeometry(point:model:geometryBarrier:)` resolves the drop
    /// position through the geometry barrier against the model's current version.
    func testResolveDropGeometryReturnsPosition() {
        let (barrier, model) = makeBarrier(text: "abc\ndef")
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        let gateway = MonaDragDropGateway()

        guard let geometry = gateway.resolveDropGeometry(
            point: CGPoint(x: 5, y: 5),
            model: model,
            geometryBarrier: barrier
        ) else {
            return XCTFail("expected a resolved drop geometry")
        }
        XCTAssertEqual(geometry.position.line, 1)
        XCTAssertEqual(geometry.resolvedVersionId, model.getVersionId())
        XCTAssertEqual(geometry.resolvedGeneration, barrier.currentGeneration)
    }

    /// `resolveDropGeometry` returns nil when no complete generation has been
    /// published (the barrier cannot resolve the position).
    func testResolveDropGeometryReturnsNilWhenNoGeneration() {
        let (barrier, model) = makeBarrier()
        // No publishGeneration call — the barrier has no complete generation.
        let gateway = MonaDragDropGateway()
        XCTAssertNil(gateway.resolveDropGeometry(
            point: CGPoint(x: 5, y: 5),
            model: model,
            geometryBarrier: barrier
        ))
    }

    // MARK: - MonaDragDropGateway: stale drop geometry rejection

    /// `isDropGeometryStale` returns false when the model version matches the
    /// version the geometry was resolved against.
    func testDropGeometryNotStaleWhenModelUnchanged() {
        let (barrier, model) = makeBarrier(text: "abc\ndef")
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        let gateway = MonaDragDropGateway()
        guard let geometry = gateway.resolveDropGeometry(
            point: CGPoint(x: 5, y: 5),
            model: model,
            geometryBarrier: barrier
        ) else {
            return XCTFail("expected a resolved drop geometry")
        }
        XCTAssertFalse(gateway.isDropGeometryStale(geometry, model: model))
    }

    /// `isDropGeometryStale` returns true when the model changed since the
    /// drag started (version diverges).
    func testDropGeometryStaleWhenModelChanged() {
        let (barrier, model) = makeBarrier(text: "abc\ndef")
        _ = barrier.publishGeneration(visibleViewLines: 1...2)
        let gateway = MonaDragDropGateway()
        guard let geometry = gateway.resolveDropGeometry(
            point: CGPoint(x: 5, y: 5),
            model: model,
            geometryBarrier: barrier
        ) else {
            return XCTFail("expected a resolved drop geometry")
        }
        // Mutate the model so its version diverges from the geometry's snapshot.
        model.setValue("abc\ndef\nghi")
        XCTAssertTrue(gateway.isDropGeometryStale(geometry, model: model))
    }

    // MARK: - MonaDragDropGateway: drop-edit providers (transform before insertion)

    /// Registered drop-edit providers run in deterministic registration order;
    /// each receives the output of the previous provider.
    func testDropEditProvidersRunInRegistrationOrder() {
        let gateway = MonaDragDropGateway()
        let geometry = MonaDropGeometry(position: pos(1, 1), resolvedVersionId: 1)
        gateway.register(RecordingDropProvider(id: "D1") { content in
            return MonaClipboardContent(
                plainText: (content.plainText ?? "") + "->D1",
                richText: nil, metadata: content.metadata
            )
        })
        gateway.register(RecordingDropProvider(id: "D2") { content in
            return MonaClipboardContent(
                plainText: (content.plainText ?? "") + "->D2",
                richText: nil, metadata: content.metadata
            )
        })

        let input = MonaClipboardContent(plainText: "DROP", richText: nil, metadata: nil)
        guard let result = gateway.runDropEditProviders(
            input, geometry: geometry
        ) else {
            return XCTFail("drop-edit pipeline returned nil")
        }
        XCTAssertEqual(result.plainText, "DROP->D1->D2")
    }

    /// With no registered drop-edit providers, the content passes through
    /// unchanged.
    func testNoDropEditProvidersPassesContentThrough() {
        let gateway = MonaDragDropGateway()
        let geometry = MonaDropGeometry(position: pos(1, 1), resolvedVersionId: 1)
        let input = MonaClipboardContent(plainText: "untouched", richText: nil, metadata: nil)
        guard let result = gateway.runDropEditProviders(input, geometry: geometry) else {
            return XCTFail("drop-edit pipeline returned nil")
        }
        XCTAssertEqual(result.plainText, "untouched")
    }

    /// When a drop-edit provider returns nil (explicitly drops the drop), the
    /// pipeline stops and returns nil; subsequent providers do not run.
    func testDropEditProviderReturningNilDropsContent() {
        let gateway = MonaDragDropGateway()
        let geometry = MonaDropGeometry(position: pos(1, 1), resolvedVersionId: 1)
        var d2Ran = false
        gateway.register(RecordingDropProvider(id: "dropper") { _ in nil })
        gateway.register(RecordingDropProvider(id: "D2") { content in
            d2Ran = true
            return content
        })
        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(gateway.runDropEditProviders(input, geometry: geometry))
        XCTAssertFalse(d2Ran)
    }

    /// When cancellation is requested before running, the drop-edit pipeline
    /// drops the content (returns nil).
    func testDropEditCancellationDropsContent() {
        let gateway = MonaDragDropGateway()
        let geometry = MonaDropGeometry(position: pos(1, 1), resolvedVersionId: 1)
        let cancelSource = MonaCancellationTokenSource()
        cancelSource.cancel()
        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(gateway.runDropEditProviders(
            input, geometry: geometry, cancellationToken: cancelSource.token
        ))
    }

    // MARK: - MonaDragDropGateway: transfer payloads (the dropped content)

    /// `readTransferPayload` reads the dropped content from a pasteboard,
    /// validates the drag types + operation, and returns the payload carrying
    /// the content, masked operation, and drop geometry.
    func testReadTransferPayloadReturnsDroppedContent() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        gateway.write(MonaClipboardContent(plainText: "dropped!", richText: nil, metadata: nil))

        let dragGateway = MonaDragDropGateway(acceptedDragTypes: .all, acceptedOperations: [.copy, .move])
        let geometry = MonaDropGeometry(position: pos(2, 3), resolvedVersionId: 5)

        guard let payload = dragGateway.readTransferPayload(
            from: pb,
            operation: [.copy, .link],
            geometry: geometry
        ) else {
            return XCTFail("expected a transfer payload")
        }
        XCTAssertEqual(payload.content.plainText, "dropped!")
        XCTAssertEqual(payload.operation, [.copy])
        XCTAssertEqual(payload.geometry.position, pos(2, 3))
        XCTAssertEqual(payload.geometry.resolvedVersionId, 5)
    }

    /// `readTransferPayload` returns nil when the pasteboard carries none of the
    /// accepted drag types.
    func testReadTransferPayloadReturnsNilWhenDragTypeNotAccepted() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        gateway.write(MonaClipboardContent(plainText: "text", richText: nil, metadata: nil))

        let dragGateway = MonaDragDropGateway(acceptedDragTypes: [.richText], acceptedOperations: [.copy])
        let geometry = MonaDropGeometry(position: pos(1, 1), resolvedVersionId: 1)
        XCTAssertNil(dragGateway.readTransferPayload(from: pb, operation: [.copy], geometry: geometry))
    }

    /// `readTransferPayload` returns nil when none of the requested operations
    /// are accepted (the masked operation is empty).
    func testReadTransferPayloadReturnsNilWhenOperationNotAccepted() {
        let pb = makePasteboard()
        let gateway = MonaPasteboardGateway(pasteboard: pb)
        gateway.write(MonaClipboardContent(plainText: "text", richText: nil, metadata: nil))

        let dragGateway = MonaDragDropGateway(acceptedDragTypes: .all, acceptedOperations: [.copy])
        let geometry = MonaDropGeometry(position: pos(1, 1), resolvedVersionId: 1)
        XCTAssertNil(dragGateway.readTransferPayload(from: pb, operation: [.move], geometry: geometry))
    }

    // MARK: - MonaDragDropGateway: idempotent disposal of provider lists

    /// `dispose()` clears the provider list so no provider runs afterwards.
    func testDisposeClearsProviderList() {
        let gateway = MonaDragDropGateway()
        let geometry = MonaDropGeometry(position: pos(1, 1), resolvedVersionId: 1)
        var ran = false
        gateway.register(RecordingDropProvider(id: "D1") { content in
            ran = true
            return content
        })
        gateway.dispose()

        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(gateway.runDropEditProviders(input, geometry: geometry))
        XCTAssertFalse(ran, "a disposed gateway must not run providers")
    }

    /// `dispose()` is idempotent: calling it more than once is a no-op and never
    /// re-arms providers.
    func testDisposeIsIdempotent() {
        let gateway = MonaDragDropGateway()
        gateway.dispose()
        // A second dispose must not throw / crash and remains disposed.
        gateway.dispose()
        gateway.dispose()
        let geometry = MonaDropGeometry(position: pos(1, 1), resolvedVersionId: 1)
        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(gateway.runDropEditProviders(input, geometry: geometry))
    }

    // MARK: - MonaServicesGateway: read selection

    /// `readSelection()` returns the clipboard content currently on the
    /// Services pasteboard.
    func testServicesReadSelectionReturnsContent() {
        let pb = makePasteboard()
        let pbGateway = MonaPasteboardGateway(pasteboard: pb)
        pbGateway.write(MonaClipboardContent(
            plainText: "services text",
            richText: nil, metadata: nil
        ))

        let services = MonaServicesGateway(pasteboardGateway: pbGateway, pipeline: MonaPasteEditPipeline())
        guard let read = services.readSelection() else {
            return XCTFail("readSelection() returned nil")
        }
        XCTAssertEqual(read.plainText, "services text")
    }

    /// `readSelection()` returns nil when the Services pasteboard is empty.
    func testServicesReadSelectionReturnsNilWhenEmpty() {
        let pb = makePasteboard()
        let pbGateway = MonaPasteboardGateway(pasteboard: pb)
        let services = MonaServicesGateway(pasteboardGateway: pbGateway, pipeline: MonaPasteEditPipeline())
        XCTAssertNil(services.readSelection())
    }

    // MARK: - MonaServicesGateway: write selection

    /// `writeSelection(_:)` writes content to the Services pasteboard so a
    /// subsequent read returns the same content.
    func testServicesWriteSelectionWritesToPasteboard() {
        let pb = makePasteboard()
        let pbGateway = MonaPasteboardGateway(pasteboard: pb)
        let services = MonaServicesGateway(pasteboardGateway: pbGateway, pipeline: MonaPasteEditPipeline())

        services.writeSelection(MonaClipboardContent(
            plainText: "written by services",
            richText: nil, metadata: nil
        ))
        guard let read = services.readSelection() else {
            return XCTFail("readSelection() returned nil after writeSelection")
        }
        XCTAssertEqual(read.plainText, "written by services")
    }

    // MARK: - MonaServicesGateway: uses the paste-edit pipeline

    /// `runSelectionEditProviders` delegates to the paste-edit pipeline so
    /// Services uses the SAME provider-ordered transformations as copy/paste.
    func testServicesRunSelectionEditProvidersUsesPasteEditPipeline() {
        let pb = makePasteboard()
        let pbGateway = MonaPasteboardGateway(pasteboard: pb)
        let pipeline = MonaPasteEditPipeline()
        pipeline.register(RecordingPasteProvider(id: "P1") { content in
            return MonaClipboardContent(
                plainText: content.plainText?.uppercased(),
                richText: nil, metadata: content.metadata
            )
        })
        let services = MonaServicesGateway(pasteboardGateway: pbGateway, pipeline: pipeline)

        let input = MonaClipboardContent(plainText: "lower", richText: nil, metadata: nil)
        guard let result = services.runSelectionEditProviders(input) else {
            return XCTFail("runSelectionEditProviders returned nil")
        }
        XCTAssertEqual(result.plainText, "LOWER")
    }

    /// `runSelectionEditProviders` forwards cancellation to the paste-edit
    /// pipeline: a cancelled token drops the content.
    func testServicesRunSelectionEditProvidersForwardsCancellation() {
        let pb = makePasteboard()
        let pbGateway = MonaPasteboardGateway(pasteboard: pb)
        let pipeline = MonaPasteEditPipeline()
        pipeline.register(RecordingPasteProvider(id: "P1") { content in content })
        let services = MonaServicesGateway(pasteboardGateway: pbGateway, pipeline: pipeline)

        let cancelSource = MonaCancellationTokenSource()
        cancelSource.cancel()
        let input = MonaClipboardContent(plainText: "X", richText: nil, metadata: nil)
        XCTAssertNil(services.runSelectionEditProviders(
            input, cancellationToken: cancelSource.token
        ))
    }
}

// MARK: - Test doubles

/// A drop-edit provider that records its invocation and delegates to a closure
/// to produce (or drop) the transformed content.
private final class RecordingDropProvider: MonaDropEditProvider {
    let identifier: String
    let transform: (MonaClipboardContent) -> MonaClipboardContent?
    var invocations = 0

    init(id: String, transform: @escaping (MonaClipboardContent) -> MonaClipboardContent?) {
        self.identifier = id
        self.transform = transform
    }

    func edit(
        _ content: MonaClipboardContent,
        geometry: MonaDropGeometry,
        cancellationToken: MonaCancellationToken,
        ticket: MonaAsyncValidityTicket
    ) -> MonaClipboardContent? {
        invocations += 1
        return transform(content)
    }
}

/// A paste-edit provider used by the Services tests.
private final class RecordingPasteProvider: MonaPasteEditProvider {
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
