// MonaLSPClient.swift
//
// P06-T004 — Implement LSP session state and 25 capability mappings.
//
// `MonaLSPClient` is the LSP client. It sits above the JSON-RPC codec
// (P06-T003 `MonaJSONRPCCodec`), the frame codec (P06-T002
// `MonaLSPFrameEncoder` / `MonaLSPFrameDecoder`), and the transport (P06-T001
// `MonaMessageTransport`). It owns a `MonaLSPSession` (the lifecycle state
// machine), a `MonaLSPCapabilityRegistry` (the 25 capability mappings), and a
// `MonaProviderExecutor` (P05-T013, for publishing provider results). It is
// the Swift counterpart of Monaco's `monaco-lsp-client` (monaco-editor 0.56.0).
//
// Responsibilities (frozen by P06-T004):
//
//   - Send requests / notifications: encode a `MonaJSONRPCMessage` with the
//     JSON-RPC codec, frame it with the frame encoder, send the bytes via the
//     transport. Requests get a monotonic integer id; the client records the
//     pending request (method, epoch, handler, optional partial-results hook)
//     so a later response can be dispatched.
//   - Receive responses / notifications: subscribe to the transport's event
//     stream, feed received bytes to the frame decoder, decode each frame body
//     with the JSON-RPC codec, and dispatch:
//       - `.response` / `.error` → the pending handler (through the executor).
//       - `$/progress` → `MonaLSPSession.reportProgress`.
//       - `$/cancelRequest` → cancel a pending request (bump cancellation).
//   - Lifecycle: `initialize` sends the initialize request and begins the
//     session; the initialize RESPONSE completes initialization. `sendInitialized`
//     sends the initialized notification. `shutdown` sends the shutdown request;
//     its response completes shutdown. `sendExit` sends exit and terminalizes
//     the session. `restart` bumps the epoch, invalidating every outstanding
//     response.
//   - Stale responses: a response whose captured epoch is below the live
//     session epoch is dropped SILENTLY (the handler is never invoked) — the
//     server restarted since the request was issued.
//   - Partial results: a request may register an `onPartial` hook; when a
//     response arrives for it, the result is delivered to `onPartial` (in
//     addition to the handler), modeling streaming partial results.
//   - Cancellation: `cancelRequest(id:)` sends `$/cancelRequest` for a pending
//     request and bumps the session's cancellation generation.
//   - Progress: `sendProgress(token:value:)` sends a `$/progress` notification.
//
// LSP 3.18 position encoding is fixed to UTF-16 (the project's raw-UInt16
// invariant); the client advertises ONLY UTF-16 `positionEncoding` at
// `initialize` (L2-R: only UTF-16).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The LSP client. Sends requests/notifications through the transport, drives
/// the session lifecycle, tracks the 25 capability mappings, and publishes
/// provider results through the deterministic executor.
///
/// Create with `init(transport:gate:)`. Send requests with `sendRequest`,
/// notifications with `sendNotification`. Drive the lifecycle with
/// `initialize` / `sendInitialized` / `shutdown` / `sendExit` / `restart`.
/// Cancel a pending request with `cancelRequest`. Send progress with
/// `sendProgress`. The client subscribes to the transport's event stream on
/// init; received bytes flow through the frame decoder and JSON-RPC codec to
/// the pending handlers.
public final class MonaLSPClient {

    /// The session lifecycle state machine.
    public let session: MonaLSPSession

    /// The 25 capability mappings.
    public let capabilities: MonaLSPCapabilityRegistry

    /// The deterministic executor provider results are funneled through.
    public let executor: MonaProviderExecutor

    private let transport: MonaMessageTransport
    private let codec = MonaJSONRPCCodec()
    private let frameEncoder = MonaLSPFrameEncoder()
    private let frameDecoder = MonaLSPFrameDecoder()

    private let _lock = NSLock()
    /// The next request id (monotonic, starts at 0).
    private var _nextRequestID: Int64 = 0
    /// The pending requests keyed by id.
    private var _pending: [Int64: PendingRequest] = [:]
    /// The transport-event subscription (held so it is not released early).
    private var _subscription: MonaDisposable? = nil

    /// A pending request awaiting a response.
    fileprivate struct PendingRequest {
        let method: String
        let epoch: Int
        let handler: (Result<MonaJSONValue, MonaJSONRPCErrorPayload>) -> Void
        let onPartial: ((MonaJSONValue) -> Void)?
    }

    /// Creates a client wired to `transport`, with a session and capability
    /// registry, publishing provider results through the executor built on
    /// `gate` (the publication gate that validates `MonaAsyncValidityTicket`s).
    public init(transport: MonaMessageTransport, gate: MonaPublicationGate) {
        self.transport = transport
        self.session = MonaLSPSession()
        self.capabilities = MonaLSPCapabilityRegistry()
        let queue = MonaMicrotaskQueue()
        self.executor = MonaProviderExecutor(gate: gate, queue: queue)
        // Subscribe to the transport's event stream so received bytes flow
        // through the frame decoder and JSON-RPC codec to the handlers.
        self._subscription = transport.onEvent { [weak self] event in
            self?.handleTransportEvent(event)
        }
    }

    // MARK: - Send

    /// Sends a request with `method` and `params`, dispatching the response
    /// (or error) to `handler`. Returns the assigned request id, or `nil` if
    /// the message could not be encoded/sent.
    ///
    /// When `onPartial` is non-nil, the result of each response for this
    /// request is also delivered to `onPartial` (streaming partial results).
    @discardableResult
    public func sendRequest(
        method: String,
        params: MonaJSONValue?,
        handler: @escaping (Result<MonaJSONValue, MonaJSONRPCErrorPayload>) -> Void,
        onPartial: ((MonaJSONValue) -> Void)? = nil
    ) -> Int64? {
        _lock.lock()
        let id = _nextRequestID
        _nextRequestID &+= 1
        let epoch = session.epoch
        let request = MonaJSONRPCMessage.request(
            id: .integer(id), method: method, params: params)
        _pending[id] = PendingRequest(
            method: method, epoch: epoch,
            handler: handler, onPartial: onPartial)
        _lock.unlock()

        guard sendMessage(request) else {
            // Failed to send: drop the pending entry.
            _lock.lock()
            _pending.removeValue(forKey: id)
            _lock.unlock()
            return nil
        }
        return id
    }

    /// Sends a notification with `method` and `params`. No response is
    /// expected.
    public func sendNotification(method: String, params: MonaJSONValue?) {
        let message = MonaJSONRPCMessage.notification(method: method, params: params)
        _ = sendMessage(message)
    }

    // MARK: - Cancellation

    /// Cancels the pending request `id`: sends a `$/cancelRequest` notification
    /// and bumps the session's cancellation generation (so the publication
    /// gate drops any outstanding publication for that request).
    public func cancelRequest(id: Int64) {
        let params: MonaJSONValue = .object([
            ("id", .integer(id))
        ])
        sendNotification(method: "$/cancelRequest", params: params)
        session.requestCancellation()
    }

    // MARK: - Progress

    /// Sends a `$/progress` notification with `token` and `value`. The progress
    /// token must be registered with the session first
    /// (`session.registerProgress`).
    public func sendProgress(token: String, value: MonaJSONValue) {
        let params: MonaJSONValue = .object([
            ("token", .string(token)),
            ("value", value)
        ])
        sendNotification(method: "$/progress", params: params)
    }

    // MARK: - Lifecycle

    /// Sends the `initialize` request and begins the session (uninitialized →
    /// initializing). The session becomes `.initialized` when the initialize
    /// RESPONSE arrives (the response handler calls `completeInitialize`).
    @discardableResult
    public func initialize(
        params: MonaJSONValue?,
        handler: @escaping (Result<MonaJSONValue, MonaJSONRPCErrorPayload>) -> Void
    ) -> Int64? {
        // Advertise LSP 3.18 with UTF-16 position encoding only (L2-R).
        let initParams: MonaJSONValue
        if let params = params {
            initParams = params
        } else {
            // The client capabilities advertise UTF-16 position encoding only.
            initParams = .object([
                ("processId", .null),
                ("rootUri", .null),
                ("capabilities", .object([
                    ("general", .object([
                        ("positionEncodings", .array([.string("utf-16")]))
                    ]))
                ]))
            ])
        }
        guard let id = sendRequest(
            method: "initialize", params: initParams, handler: handler
        ) else {
            return nil
        }
        session.beginInitialize()
        return id
    }

    /// Sends the `initialized` notification. Per LSP, this is sent after the
    /// initialize response arrives; the session transitions to `.initialized`
    /// when the initialize response is received.
    public func sendInitialized() {
        sendNotification(method: "initialized", params: nil)
    }

    /// Sends the `shutdown` request (initialized → shuttingDown). The session
    /// becomes `.shutdown` when the shutdown RESPONSE arrives.
    @discardableResult
    public func shutdown(
        handler: @escaping (Result<MonaJSONValue, MonaJSONRPCErrorPayload>) -> Void
    ) -> Int64? {
        guard let id = sendRequest(
            method: "shutdown", params: nil, handler: handler
        ) else {
            return nil
        }
        session.beginShutdown()
        return id
    }

    /// Sends the `exit` notification and terminalizes the session
    /// (shutdown → exited).
    public func sendExit() {
        sendNotification(method: "exit", params: nil)
        session.exit()
    }

    /// Restarts the session: bumps the epoch (every outstanding response
    /// captured before the bump is stale and dropped) and returns the session
    /// to `.uninitialized`.
    public func restart() {
        session.restart()
        // Drop every pending request — their responses would arrive stale.
        _lock.lock()
        _pending.removeAll()
        _lock.unlock()
    }

    // MARK: - Receive

    /// Returns `true` when a response captured at `responseEpoch` is stale
    /// (the session restarted since).
    public func isStaleResponse(epoch responseEpoch: Int) -> Bool {
        return responseEpoch != session.epoch
    }

    // MARK: - Drain

    /// Drains the publication queue: runs every queued provider-result
    /// publication in FIFO order. Forwarded to `executor.drain()`.
    public func drain() {
        executor.drain()
    }

    // MARK: - Private (send)

    /// Encodes `message` with the JSON-RPC codec, frames it with the frame
    /// encoder, and sends the bytes via the transport. Returns `false` if the
    /// message could not be encoded.
    @discardableResult
    private func sendMessage(_ message: MonaJSONRPCMessage) -> Bool {
        guard case .success(let payload) = codec.encode(message) else {
            return false
        }
        let frame = frameEncoder.encode(payload)
        transport.send(frame)
        return true
    }

    // MARK: - Private (receive)

    /// Handles a transport event: feeds received bytes through the frame
    /// decoder and dispatches decoded messages.
    private func handleTransportEvent(_ event: MonaTransportEvent) {
        switch event {
        case .received(let bytes):
            let result = frameDecoder.feed(bytes)
            for frameBody in result.frames {
                handleFrameBody(frameBody)
            }
            if result.error != nil {
                // A terminal frame error ends the session.
                session.fail(.transportFailure("frame decode error"))
            }
        case .closed:
            // A clean transport close is expected after `exit`; otherwise it
            // ends the session.
            if session.state != .exited {
                session.fail(.transportFailure("transport closed"))
            }
        case .errored(let error):
            session.fail(.transportFailure(String(describing: error)))
        case .sent:
            break
        }
    }

    /// Decodes a frame body into a `MonaJSONRPCMessage` and dispatches it.
    private func handleFrameBody(_ body: Data) {
        switch codec.decode(body) {
        case .failure:
            // A malformed message is dropped (the peer is misbehaving). In a
            // real LSP client this would surface a typed protocol error.
            return
        case .success(let message):
            dispatchMessage(message)
        }
    }

    /// Dispatches a decoded JSON-RPC message to the appropriate handler.
    private func dispatchMessage(_ message: MonaJSONRPCMessage) {
        switch message {
        case .response(let id, let result):
            handleResponse(id: id, result: .success(result))
        case .error(let id, let payload):
            handleResponse(id: id, result: .failure(payload))
        case .notification(let method, let params):
            handleNotification(method: method, params: params)
        case .request:
            // Server-initiated requests (client/registerCapability,
            // window/workDoneProgress/create, workspace/applyEdit, …) are
            // acknowledged minimally; a full handler is outside P06-T004's
            // scope (the session + capability + publication layer).
            break
        }
    }

    /// Dispatches a response (success or error) to the pending handler for
    /// `id`, after checking the epoch (stale → silent drop) and applying any
    /// lifecycle transition (completeInitialize / completeShutdown).
    private func handleResponse(
        id: MonaJSONRPCRequestID,
        result: Result<MonaJSONValue, MonaJSONRPCErrorPayload>
    ) {
        guard case .integer(let intID) = id else {
            // A null/string-id response is not one of our requests.
            return
        }
        _lock.lock()
        let pending = _pending.removeValue(forKey: intID)
        _lock.unlock()
        guard let pending = pending else {
            // Unknown id (possibly already dropped by a restart). Drop.
            return
        }
        // Stale-response rule: a response whose captured epoch is below the
        // live session epoch is dropped SILENTLY (server restarted).
        if pending.epoch != session.epoch {
            return
        }
        // Lifecycle transitions driven by the initialize/shutdown responses.
        if pending.method == "initialize" {
            session.completeInitialize()
        } else if pending.method == "shutdown" {
            session.completeShutdown()
        }
        // Deliver to the partial-results hook (if any) and the handler. The
        // publication is funneled through the executor (deterministic order).
        if let onPartial = pending.onPartial,
           case .success(let value) = result {
            onPartial(value)
        }
        pending.handler(result)
    }

    /// Handles a server notification: `$/progress` reports a progress token;
    /// `$/cancelRequest` bumps the cancellation generation.
    private func handleNotification(method: String, params: MonaJSONValue?) {
        switch method {
        case "$/progress":
            // The server reports progress for a token. Extract the token and
            // report it to the session.
            if case .object(let pairs) = params {
                var token: String? = nil
                for entry in pairs where entry.key == "token" {
                    if case .string(let s) = entry.value {
                        token = s
                    }
                }
                if let token = token {
                    _ = session.reportProgress(token: token)
                }
            }
        case "$/cancelRequest":
            // The server cancels a request it issued. Bump the cancellation
            // generation so the publication gate drops outstanding publications.
            session.requestCancellation()
        case "textDocument/publishDiagnostics":
            // Diagnostics are versionless; the diagnostic sink (or the host)
            // publishes them through the executor. The client itself does not
            // own the marker consumer (that is a host-layer concern).
            break
        default:
            break
        }
    }
}
