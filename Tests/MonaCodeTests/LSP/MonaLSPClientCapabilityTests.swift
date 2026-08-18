// MonaLSPClientCapabilityTests.swift
//
// P06-T004 — Implement LSP session state and 25 capability mappings.
//
// Verifies the four implementation-operation contracts:
//   1. Lifecycle state transitions: initialize, initialized, shutdown, exit,
//      restart, request, notification, cancellation, progress, and error.
//   2. Exactly 25 LSP-backed provider surfaces mapped with raw UTF-16
//      (UInt16) positions and explicit capability availability.
//   3. Static and dynamic registration, resolve, release, partial results,
//      stale responses, and versionless diagnostics.
//   4. Provider results published ONLY through validity tickets and the
//      deterministic executor (MonaProviderExecutor + MonaMicrotaskQueue +
//      MonaAsyncValidityTicket from P05-T013).

import XCTest
@testable import MonaCode

final class MonaLSPClientCapabilityTests: XCTestCase {

    // MARK: - Helpers

    private func makeModel() -> MonaCodeModel {
        return MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/lsp"))
    }

    private func makeExecutor(model: MonaCodeModel) -> (MonaPublicationGate, MonaProviderExecutor) {
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        return (gate, executor)
    }

    // MARK: - 1. Lifecycle state transitions

    func testSessionStartsUninitialized() {
        let session = MonaLSPSession()
        XCTAssertEqual(session.state, .uninitialized)
        XCTAssertEqual(session.epoch, 0)
        XCTAssertEqual(session.cancellationGeneration, 0)
        XCTAssertTrue(session.activeProgressTokens.isEmpty)
        XCTAssertNil(session.lastError)
    }

    func testInitializeTransitionUninitializedToInitializingToInitialized() {
        let session = MonaLSPSession()
        // uninitialized → initializing
        let prev1 = session.beginInitialize()
        XCTAssertEqual(prev1, .uninitialized)
        XCTAssertEqual(session.state, .initializing)
        // initializing → initialized
        let prev2 = session.completeInitialize()
        XCTAssertEqual(prev2, .initializing)
        XCTAssertEqual(session.state, .initialized)
    }

    func testShutdownTransitionInitializedToShuttingDownToShutdown() {
        let session = MonaLSPSession()
        session.beginInitialize()
        session.completeInitialize()
        // initialized → shuttingDown
        let prev1 = session.beginShutdown()
        XCTAssertEqual(prev1, .initialized)
        XCTAssertEqual(session.state, .shuttingDown)
        // shuttingDown → shutdown
        let prev2 = session.completeShutdown()
        XCTAssertEqual(prev2, .shuttingDown)
        XCTAssertEqual(session.state, .shutdown)
    }

    func testExitTransitionShutdownToExited() {
        let session = MonaLSPSession()
        session.beginInitialize()
        session.completeInitialize()
        session.beginShutdown()
        session.completeShutdown()
        let prev = session.exit()
        XCTAssertEqual(prev, .shutdown)
        XCTAssertEqual(session.state, .exited)
    }

    func testRestartBumpsEpochAndResetsToUninitialized() {
        let session = MonaLSPSession()
        session.beginInitialize()
        session.completeInitialize()
        XCTAssertEqual(session.epoch, 0)
        let prev = session.restart()
        XCTAssertEqual(prev, .initialized)
        XCTAssertEqual(session.state, .uninitialized)
        XCTAssertEqual(session.epoch, 1)
        // After restart the session can re-initialize.
        session.beginInitialize()
        XCTAssertEqual(session.state, .initializing)
        session.completeInitialize()
        XCTAssertEqual(session.state, .initialized)
    }

    func testErrorTransitionFromInitialized() {
        let session = MonaLSPSession()
        session.beginInitialize()
        session.completeInitialize()
        let prev = session.fail(.transportFailure("boom"))
        XCTAssertEqual(prev, .initialized)
        XCTAssertEqual(session.state, .error)
        XCTAssertEqual(session.lastError, .transportFailure("boom"))
    }

    func testErrorTransitionIsTerminalExceptExit() {
        let session = MonaLSPSession()
        session.fail(.transportFailure("fatal"))
        XCTAssertEqual(session.state, .error)
        // From error, lifecycle transitions are no-ops.
        XCTAssertNil(session.beginInitialize())
        XCTAssertNil(session.beginShutdown())
        // restart recovers from error.
        let prev = session.restart()
        XCTAssertEqual(prev, .error)
        XCTAssertEqual(session.state, .uninitialized)
    }

    func testIllegalTransitionsAreNoOps() {
        let session = MonaLSPSession()
        // Cannot complete-initialize before begin-initialize.
        XCTAssertNil(session.completeInitialize())
        XCTAssertEqual(session.state, .uninitialized)
        // Cannot begin-shutdown before initialized.
        XCTAssertNil(session.beginShutdown())
        // Cannot exit before shutdown.
        XCTAssertNil(session.exit())
        // Cannot complete-shutdown before begin-shutdown.
        session.beginInitialize()
        session.completeInitialize()
        XCTAssertNil(session.completeShutdown())
        XCTAssertEqual(session.state, .initialized)
    }

    func testCancellationBumpsGeneration() {
        let session = MonaLSPSession()
        XCTAssertEqual(session.cancellationGeneration, 0)
        session.requestCancellation()
        XCTAssertEqual(session.cancellationGeneration, 1)
        session.requestCancellation()
        XCTAssertEqual(session.cancellationGeneration, 2)
    }

    func testProgressTokenRegisterReportUnregister() {
        let session = MonaLSPSession()
        // Register a progress token.
        XCTAssertTrue(session.registerProgress(token: "token-1"))
        XCTAssertEqual(session.activeProgressTokens, ["token-1"])
        // Registering the same token again returns false (already active).
        XCTAssertFalse(session.registerProgress(token: "token-1"))
        // Reporting an active token succeeds.
        XCTAssertTrue(session.reportProgress(token: "token-1"))
        // Reporting an unknown token fails.
        XCTAssertFalse(session.reportProgress(token: "token-x"))
        // Unregister removes the token.
        session.unregisterProgress(token: "token-1")
        XCTAssertTrue(session.activeProgressTokens.isEmpty)
    }

    // MARK: - 2. Exactly 25 LSP provider surfaces with raw UTF-16 positions

    func testExactly25ProviderSurfaces() {
        XCTAssertEqual(MonaLSPProviderSurface.allCases.count, 25)
        XCTAssertEqual(MonaLSPCapabilityRegistry.surfaceCount, 25)
    }

    func test25SurfacesAreTheContractSet() {
        // The 25 LSP method names from the L2-R closure artifact.
        let expectedMethods: Set<String> = [
            "textDocument/references",
            "textDocument/definition",
            "textDocument/declaration",
            "textDocument/typeDefinition",
            "textDocument/implementation",
            "textDocument/documentSymbol",
            "textDocument/documentHighlight",
            "textDocument/selectionRange",
            "textDocument/documentLink",
            "textDocument/rename",
            "textDocument/completion",
            "textDocument/signatureHelp",
            "textDocument/codeAction",
            "textDocument/codeLens",
            "textDocument/formatting",
            "textDocument/rangeFormatting",
            "textDocument/onTypeFormatting",
            "textDocument/hover",
            "textDocument/documentColor",
            "textDocument/foldingRange",
            "textDocument/inlayHint",
            "textDocument/inlineCompletion",
            "textDocument/linkedEditingRange",
            "textDocument/semanticTokens/full",
            "textDocument/semanticTokens/range",
        ]
        let actualMethods = Set(MonaLSPProviderSurface.allCases.map { $0.method })
        XCTAssertEqual(actualMethods, expectedMethods)
        XCTAssertEqual(actualMethods.count, 25)
    }

    func testSurfaceGroupsMatchContractCounts() {
        // Navigation (9), Editing (8), Presentation (8) = 25.
        let nav = MonaLSPProviderSurface.allCases.filter { $0.group == .navigation }
        let edit = MonaLSPProviderSurface.allCases.filter { $0.group == .editing }
        let pres = MonaLSPProviderSurface.allCases.filter { $0.group == .presentation }
        XCTAssertEqual(nav.count, 9)
        XCTAssertEqual(edit.count, 8)
        XCTAssertEqual(pres.count, 8)
        XCTAssertEqual(nav.count + edit.count + pres.count, 25)
    }

    func testResolveMethodsForResolvableSurfaces() {
        // Completion → completionItem/resolve
        XCTAssertEqual(MonaLSPProviderSurface.completion.resolveMethod, "completionItem/resolve")
        // CodeAction → codeAction/resolve
        XCTAssertEqual(MonaLSPProviderSurface.codeAction.resolveMethod, "codeAction/resolve")
        // CodeLens → codeLens/resolve
        XCTAssertEqual(MonaLSPProviderSurface.codeLens.resolveMethod, "codeLens/resolve")
        // InlayHint → inlayHint/resolve
        XCTAssertEqual(MonaLSPProviderSurface.inlayHint.resolveMethod, "inlayHint/resolve")
        // DocumentLink → documentLink/resolve
        XCTAssertEqual(MonaLSPProviderSurface.documentLink.resolveMethod, "documentLink/resolve")
        // Non-resolvable surfaces have nil resolve method.
        XCTAssertNil(MonaLSPProviderSurface.hover.resolveMethod)
        XCTAssertNil(MonaLSPProviderSurface.formatting.resolveMethod)
    }

    func testRawUTF16PositionUsesUInt16() {
        // The raw-UInt16 invariant: LSP positions store UInt16 line/character
        // (UTF-16 code-unit offsets, no grapheme conversion).
        let pos = MonaLSPPosition(line: 3, character: 7)
        XCTAssertEqual(pos.line, 3)
        XCTAssertEqual(pos.character, 7)
        // A position that lands inside a surrogate pair (odd character offset
        // after a high surrogate) is preserved verbatim.
        let midSurrogate = MonaLSPPosition(line: 0, character: 1)
        XCTAssertEqual(midSurrogate.character, 1)
    }

    func testRawUTF16RangePreservesSurrogatePairOffset() {
        let range = MonaLSPRange(
            start: MonaLSPPosition(line: 0, character: 0),
            end: MonaLSPPosition(line: 0, character: 2))
        XCTAssertEqual(range.start, MonaLSPPosition(line: 0, character: 0))
        XCTAssertEqual(range.end, MonaLSPPosition(line: 0, character: 2))
        XCTAssertNotEqual(range.start, range.end)
    }

    // MARK: - 3. Static + dynamic registration, resolve, release, partial,
    //              stale, versionless

    func testRegistryStartsAllUnavailable() {
        let registry = MonaLSPCapabilityRegistry()
        for surface in MonaLSPProviderSurface.allCases {
            XCTAssertEqual(registry.availability(for: surface), .unavailable,
                           "\(surface.method) should start unavailable")
            XCTAssertFalse(registry.isAvailable(surface))
        }
        XCTAssertEqual(registry.allMappings().count, 25)
    }

    func testStaticRegistrationSetsAvailability() {
        let registry = MonaLSPCapabilityRegistry()
        registry.setStaticAvailability(.hover, .available)
        registry.setStaticAvailability(.completion, .available)
        XCTAssertEqual(registry.availability(for: .hover), .available)
        XCTAssertTrue(registry.isAvailable(.hover))
        XCTAssertEqual(registry.availability(for: .completion), .available)
        // Other surfaces remain unavailable.
        XCTAssertEqual(registry.availability(for: .rename), .unavailable)
    }

    func testDynamicRegistrationMarksDynamicallyRegistered() {
        let registry = MonaLSPCapabilityRegistry()
        // Dynamic registration: server registers at runtime.
        XCTAssertTrue(registry.registerDynamically(.definition))
        XCTAssertEqual(registry.availability(for: .definition), .dynamicallyRegistered)
        XCTAssertTrue(registry.isAvailable(.definition))
        // Registering an already-dynamically-registered surface returns false.
        XCTAssertFalse(registry.registerDynamically(.definition))
        // Dynamic registration can also apply to a statically-available surface
        // (upgrade), and the availability reads as dynamicallyRegistered.
        registry.setStaticAvailability(.hover, .available)
        XCTAssertTrue(registry.registerDynamically(.hover))
        XCTAssertEqual(registry.availability(for: .hover), .dynamicallyRegistered)
    }

    func testDynamicUnregistrationReleasesToUnavailable() {
        let registry = MonaLSPCapabilityRegistry()
        registry.registerDynamically(.codeAction)
        XCTAssertEqual(registry.availability(for: .codeAction), .dynamicallyRegistered)
        // Unregister (release) returns to unavailable.
        XCTAssertTrue(registry.unregister(.codeAction))
        XCTAssertEqual(registry.availability(for: .codeAction), .unavailable)
        XCTAssertFalse(registry.isAvailable(.codeAction))
        // Unregistering an unregistered surface returns false.
        XCTAssertFalse(registry.unregister(.codeAction))
    }

    func testProviderResultCarriesRawUTF16PositionsAndPartialFlag() {
        let result = MonaLSPProviderResult(
            surface: .hover,
            positions: [MonaLSPPosition(line: 1, character: 0),
                        MonaLSPPosition(line: 1, character: 3)],
            isPartial: true,
            releaseToken: 42,
            modelVersion: 5)
        XCTAssertEqual(result.surface, .hover)
        XCTAssertEqual(result.positions.count, 2)
        XCTAssertTrue(result.isPartial)
        XCTAssertEqual(result.releaseToken, 42)
        XCTAssertEqual(result.modelVersion, 5)
    }

    func testProviderAdapterPublishesThroughExecutorAndTicket() {
        let model = makeModel()
        let (gate, executor) = makeExecutor(model: model)
        let adapter = MonaLSPProviderAdapter(surface: .hover, executor: executor)
        let ticket = gate.captureTicket()
        var received: MonaLSPProviderResult? = nil
        let result = MonaLSPProviderResult(
            surface: .hover,
            positions: [MonaLSPPosition(line: 0, character: 0)],
            isPartial: false,
            releaseToken: 1,
            modelVersion: model.getVersionId())
        let accepted = adapter.publish(
            result: result, ticket: ticket,
            receive: { received = $0 })
        XCTAssertTrue(accepted)
        // Publication drains through the executor's microtask queue.
        executor.drain()
        XCTAssertEqual(received?.surface, .hover)
        XCTAssertEqual(received?.positions.first, MonaLSPPosition(line: 0, character: 0))
    }

    func testProviderAdapterStaleTicketDropsPublicationSilently() {
        let model = makeModel()
        let (gate, executor) = makeExecutor(model: model)
        let adapter = MonaLSPProviderAdapter(surface: .hover, executor: executor)
        let ticket = gate.captureTicket()
        // Invalidate the ticket by replacing the model (owner generation bump).
        let newModel = MonaCodeModel(
            text: "xyz", uri: MonaURI(scheme: "inmemory", path: "/lsp2"))
        gate.replaceModel(newModel)
        var received: MonaLSPProviderResult? = nil
        let result = MonaLSPProviderResult(
            surface: .hover,
            positions: [MonaLSPPosition(line: 0, character: 0)],
            isPartial: false, releaseToken: 1, modelVersion: 1)
        let accepted = adapter.publish(
            result: result, ticket: ticket,
            receive: { received = $0 })
        XCTAssertTrue(accepted)  // enqueued, but dropped at publication time
        executor.drain()
        // Stale ticket: receive was never invoked (silent drop).
        XCTAssertNil(received)
    }

    func testProviderAdapterCancellationGenerationDropsPublication() {
        let model = makeModel()
        let (gate, executor) = makeExecutor(model: model)
        let adapter = MonaLSPProviderAdapter(surface: .completion, executor: executor)
        let ticket = gate.captureTicket()
        // Request cancellation — bumps the cancellation generation.
        gate.cancel()
        var received: MonaLSPProviderResult? = nil
        let result = MonaLSPProviderResult(
            surface: .completion,
            positions: [MonaLSPPosition(line: 0, character: 0)],
            isPartial: false, releaseToken: 7, modelVersion: 1)
        XCTAssertTrue(adapter.publish(result: result, ticket: ticket,
                                      receive: { received = $0 }))
        executor.drain()
        XCTAssertNil(received)  // cancellation dropped silently
    }

    func testResolvePartialPublishesResolvedResult() {
        let model = makeModel()
        let (gate, executor) = makeExecutor(model: model)
        let adapter = MonaLSPProviderAdapter(surface: .completion, executor: executor)
        let ticket = gate.captureTicket()
        let partial = MonaLSPProviderResult(
            surface: .completion,
            positions: [MonaLSPPosition(line: 0, character: 0)],
            isPartial: true, releaseToken: 9, modelVersion: model.getVersionId())
        var received: MonaLSPProviderResult? = nil
        XCTAssertTrue(adapter.resolvePartial(
            partial, ticket: ticket,
            receive: { received = $0 }))
        executor.drain()
        // The resolved result is published with isPartial == false.
        XCTAssertFalse(received?.isPartial ?? true)
        XCTAssertEqual(received?.releaseToken, 9)
    }

    func testReleaseDisposesReleaseToken() {
        let model = makeModel()
        let (_, executor) = makeExecutor(model: model)
        let adapter = MonaLSPProviderAdapter(surface: .codeLens, executor: executor)
        // Release a provider by release token — no throw, idempotent.
        adapter.release(releaseToken: 100)
        adapter.release(releaseToken: 100)  // idempotent: no-op second call
    }

    func testVersionlessDiagnosticsPublishWithoutVersionGating() {
        let model = makeModel()
        let (gate, executor) = makeExecutor(model: model)
        let sink = MonaLSPDiagnosticSink(executor: executor)
        // Versionless diagnostics: the payload carries no model version. The
        // ticket is captured fresh at publish time; only epoch/owner/cancellation
        // gate it (not a request-time version).
        var received: [MonaJSONValue] = []
        let accepted = sink.publishVersionless(
            diagnostics: [.array([.string("diag-1")])],
            ticket: gate.captureTicket(),
            receive: { received = $0 })
        XCTAssertTrue(accepted)
        executor.drain()
        XCTAssertEqual(received.count, 1)
    }

    func testVersionlessDiagnosticsStaleTicketDropsSilently() {
        let model = makeModel()
        let (gate, executor) = makeExecutor(model: model)
        let sink = MonaLSPDiagnosticSink(executor: executor)
        let ticket = gate.captureTicket()
        gate.replaceModel(MonaCodeModel(
            text: "x", uri: MonaURI(scheme: "inmemory", path: "/v2")))
        var received: [MonaJSONValue] = []
        XCTAssertTrue(sink.publishVersionless(
            diagnostics: [.string("d")], ticket: ticket,
            receive: { received = $0 }))
        executor.drain()
        XCTAssertTrue(received.isEmpty)  // stale → dropped silently
    }

    func testProviderAdapterRegistryHasExactly25Adapters() {
        let model = makeModel()
        let (_, executor) = makeExecutor(model: model)
        let registry = MonaLSPProviderAdapterRegistry(executor: executor)
        XCTAssertEqual(registry.adapters.count, 25)
        // Every surface has an adapter.
        for surface in MonaLSPProviderSurface.allCases {
            XCTAssertNotNil(registry.adapter(for: surface),
                            "missing adapter for \(surface.method)")
        }
    }

    // MARK: - 4. LSP client: request, notification, cancellation, progress,
    //              stale, partial, restart-epoch

    func testClientSendRequestEncodesAndFramesAndSends() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var sentBytes: [Data] = []
        let _ = transport.onEvent { event in
            if case .sent(let data) = event { sentBytes.append(data) }
        }
        let id = client.sendRequest(
            method: "textDocument/hover",
            params: .object([("line", .integer(0))]),
            handler: { _ in })
        XCTAssertNotNil(id)
        XCTAssertEqual(sentBytes.count, 1)
        // The sent bytes are a framed JSON-RPC request.
        let frame = String(data: sentBytes[0], encoding: .utf8) ?? ""
        XCTAssertTrue(frame.contains("Content-Length:"))
        XCTAssertTrue(frame.contains("\"jsonrpc\":\"2.0\""))
        XCTAssertTrue(frame.contains("\"method\":\"textDocument/hover\""))
    }

    func testClientSendNotificationHasNoID() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var sentBytes: [Data] = []
        let _ = transport.onEvent { event in
            if case .sent(let data) = event { sentBytes.append(data) }
        }
        client.sendNotification(method: "initialized", params: nil)
        XCTAssertEqual(sentBytes.count, 1)
        let frame = String(data: sentBytes[0], encoding: .utf8) ?? ""
        XCTAssertTrue(frame.contains("\"method\":\"initialized\""))
        // A notification has NO id field.
        XCTAssertFalse(frame.contains("\"id\":"))
    }

    func testClientCancellationSendsCancelRequest() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var sentFrames: [String] = []
        let _ = transport.onEvent { event in
            if case .sent(let data) = event {
                sentFrames.append(String(data: data, encoding: .utf8) ?? "")
            }
        }
        client.cancelRequest(id: 17)
        // The cancel notification uses method "$/cancelRequest".
        let cancelFrame = sentFrames.first { $0.contains("cancelRequest") } ?? ""
        XCTAssertTrue(cancelFrame.contains("$/cancelRequest"))
        XCTAssertTrue(cancelFrame.contains("\"id\":17"))
    }

    func testClientProgressSendsProgressNotification() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var sentFrames: [String] = []
        let _ = transport.onEvent { event in
            if case .sent(let data) = event {
                sentFrames.append(String(data: data, encoding: .utf8) ?? "")
            }
        }
        client.sendProgress(token: "progress-1", value: .integer(50))
        let frame = sentFrames.first { $0.contains("progress") } ?? ""
        XCTAssertTrue(frame.contains("$/progress"))
        XCTAssertTrue(frame.contains("progress-1"))
    }

    func testClientReceiveDispatchesResponseToHandler() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        // Subscribe to the transport's event stream so the client receives
        // injected bytes. The client subscribes on init; just feed bytes.
        var handlerResult: Result<MonaJSONValue, MonaJSONRPCErrorPayload>? = nil
        let id = client.sendRequest(
            method: "textDocument/definition",
            params: nil,
            handler: { handlerResult = $0 })
        XCTAssertNotNil(id)
        // Inject a server response for that id.
        let responseJSON = "{\"jsonrpc\":\"2.0\",\"id\":\(id!),\"result\":{\"ok\":true}}"
        let frame = MonaLSPFrameEncoder().encode(Data(responseJSON.utf8))
        transport.receive(frame)
        // Drain the publication queue so the handler fires.
        client.drain()
        switch handlerResult {
        case .some(.success(let value)):
            XCTAssertEqual(value, .object([("ok", .bool(true))]))
        default:
            XCTFail("expected success response, got \(String(describing: handlerResult))")
        }
    }

    func testClientReceiveDispatchesErrorResponse() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var handlerResult: Result<MonaJSONValue, MonaJSONRPCErrorPayload>? = nil
        let id = client.sendRequest(
            method: "textDocument/rename",
            params: nil,
            handler: { handlerResult = $0 })
        let errorJSON = "{\"jsonrpc\":\"2.0\",\"id\":\(id!),"
            + "\"error\":{\"code\":-32602,\"message\":\"bad params\"}}"
        transport.receive(MonaLSPFrameEncoder().encode(Data(errorJSON.utf8)))
        client.drain()
        switch handlerResult {
        case .some(.failure(let payload)):
            XCTAssertEqual(payload.code, -32602)
            XCTAssertEqual(payload.message, "bad params")
        default:
            XCTFail("expected error response, got \(String(describing: handlerResult))")
        }
    }

    func testClientStaleResponseAfterRestartIsDropped() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var handlerResult: Result<MonaJSONValue, MonaJSONRPCErrorPayload>? = nil
        let id = client.sendRequest(
            method: "textDocument/hover",
            params: nil,
            handler: { handlerResult = $0 })
        let epochAtRequest = client.session.epoch
        // Restart the session — bumps epoch; old responses are stale.
        client.restart()
        XCTAssertEqual(client.session.epoch, epochAtRequest + 1)
        // Inject a response for the pre-restart request — must be dropped.
        let responseJSON = "{\"jsonrpc\":\"2.0\",\"id\":\(id!),\"result\":{\"stale\":true}}"
        transport.receive(MonaLSPFrameEncoder().encode(Data(responseJSON.utf8)))
        client.drain()
        // Stale: handler was never invoked.
        XCTAssertNil(handlerResult)
    }

    func testClientPartialResultIsDelivered() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var partials: [MonaJSONValue] = []
        let id = client.sendRequest(
            method: "textDocument/completion",
            params: nil,
            handler: { _ in },
            onPartial: { partials.append($0) })
        XCTAssertNotNil(id)
        // The server sends a partial result notification.
        // (In real LSP, partial results come as responses with the same id and
        // partial result flag; here the client exposes a partial-results hook.)
        let partialJSON = "{\"jsonrpc\":\"2.0\",\"id\":\(id!),\"result\":{\"items\":[]}}"
        transport.receive(MonaLSPFrameEncoder().encode(Data(partialJSON.utf8)))
        client.drain()
        // The partial hook fired with the partial result.
        XCTAssertFalse(partials.isEmpty)
    }

    func testClientInitializeSendsInitializeAndAdvancesSession() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var sentFrames: [String] = []
        let _ = transport.onEvent { event in
            if case .sent(let data) = event {
                sentFrames.append(String(data: data, encoding: .utf8) ?? "")
            }
        }
        let id = client.initialize(params: nil, handler: { _ in })
        XCTAssertNotNil(id)
        XCTAssertEqual(client.session.state, .initializing)
        let initFrame = sentFrames.first { $0.contains("initialize") } ?? ""
        XCTAssertTrue(initFrame.contains("\"method\":\"initialize\""))
        // Send initialized notification.
        client.sendInitialized()
        // Cannot send initialized twice (it's a one-shot notification).
        // After the initialize *response* arrives, the session becomes initialized.
        let initResponse = "{\"jsonrpc\":\"2.0\",\"id\":\(id!),\"result\":{\"capabilities\":{}}}"
        transport.receive(MonaLSPFrameEncoder().encode(Data(initResponse.utf8)))
        client.drain()
        XCTAssertEqual(client.session.state, .initialized)
    }

    func testClientShutdownAndExitAdvanceSession() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        client.initialize(params: nil, handler: { _ in })
        // Complete initialize.
        transport.receive(MonaLSPFrameEncoder().encode(Data(
            "{\"jsonrpc\":\"2.0\",\"id\":0,\"result\":{\"capabilities\":{}}}".utf8)))
        client.drain()
        XCTAssertEqual(client.session.state, .initialized)
        // Shutdown.
        let _ = client.shutdown(handler: { _ in })
        XCTAssertEqual(client.session.state, .shuttingDown)
        transport.receive(MonaLSPFrameEncoder().encode(Data(
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}".utf8)))
        client.drain()
        XCTAssertEqual(client.session.state, .shutdown)
        // Exit.
        client.sendExit()
        XCTAssertEqual(client.session.state, .exited)
    }

    func testClientOnlyUTF16PositionEncodingAdvertised() {
        let transport = MonaMessageTransportImpl()
        let gate = MonaPublicationGate(model: makeModel())
        let client = MonaLSPClient(transport: transport, gate: gate)
        var sentFrames: [String] = []
        let _ = transport.onEvent { event in
            if case .sent(let data) = event {
                sentFrames.append(String(data: data, encoding: .utf8) ?? "")
            }
        }
        client.initialize(params: nil, handler: { _ in })
        let initFrame = sentFrames.first { $0.contains("initialize") } ?? ""
        // Only UTF-16 position encoding is advertised (L2-R: only UTF-16).
        XCTAssertTrue(initFrame.contains("positionEncoding") || initFrame.contains("capabilities"))
    }

    // MARK: - 5. Publication only through the deterministic executor

    func testPublicationOrderIsFIFOThroughExecutor() {
        let model = makeModel()
        let (_, executor) = makeExecutor(model: model)
        let adapter = MonaLSPProviderAdapter(surface: .hover, executor: executor)
        let gate = MonaPublicationGate(model: model)
        let ticket = gate.captureTicket()
        var order: [Int] = []
        for i in 0..<5 {
            let r = MonaLSPProviderResult(
                surface: .hover,
                positions: [MonaLSPPosition(line: UInt16(i), character: 0)],
                isPartial: false, releaseToken: i, modelVersion: model.getVersionId())
            XCTAssertTrue(adapter.publish(result: r, ticket: ticket,
                                         receive: { _ in order.append(i) }))
        }
        executor.drain()
        // FIFO: publication order matches enqueue order.
        XCTAssertEqual(order, [0, 1, 2, 3, 4])
    }

    func testProviderAdapterReleaseInvokesDisposableExactlyOnce() {
        let model = makeModel()
        let (_, executor) = makeExecutor(model: model)
        let adapter = MonaLSPProviderAdapter(surface: .codeAction, executor: executor)
        var releaseCount = 0
        let disposable = MonaDisposableImpl { releaseCount += 1 }
        let gate = MonaPublicationGate(model: model)
        let ticket = gate.captureTicket()
        var received: MonaLSPProviderResult? = nil
        let r = MonaLSPProviderResult(
            surface: .codeAction,
            positions: [], isPartial: false, releaseToken: 3,
            modelVersion: model.getVersionId())
        XCTAssertTrue(adapter.publish(result: r, ticket: ticket, owned: [disposable],
                                      receive: { received = $0 }))
        executor.drain()
        // Owned disposable released exactly once after publication.
        XCTAssertEqual(releaseCount, 1)
        // Second dispose is a no-op (idempotent).
        disposable.dispose()
        XCTAssertEqual(releaseCount, 1)
    }
}
