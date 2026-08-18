// MonaJSONRPCMessage.swift
//
// P06-T003 — Implement deterministic JSON-RPC wire values and errors.
//
// `MonaJSONRPCMessage` is the typed JSON-RPC 2.0 message tree. It sits
// above the JSON value tree (`MonaJSONValue`) and below the codec
// (`MonaJSONRPCCodec`). The four message kinds are distinguished by exact
// field directionality (the L2-R3 message-shape matrix):
//
//   - request:       { jsonrpc, id, method, params? }              id = int|str
//   - notification:  { jsonrpc, method, params? }   (NO id)        id absent
//   - response:      { jsonrpc, id, result }                      id = int|str
//   - error:         { jsonrpc, id, error: {code, message, data?}}id = int|str|null
//
// The `id` is preserved WITHOUT coercion: a string id `"5"` stays a string,
// an integer `5` stays an integer, and `null` stays null (valid only in an
// error response).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A JSON-RPC 2.0 request identifier, preserved without coercion. A `null`
/// id is only valid in an error response (a peer error that cannot be
/// associated with a request).
public enum MonaJSONRPCRequestID: Equatable, Hashable {

    /// An integer id (e.g. `5`). Preserved as an integer — never coerced to
    /// a string.
    case integer(Int64)

    /// A string id (e.g. `"5"` or `"abc"`). Preserved as a string — never
    /// coerced to an integer, even if its contents are numeric.
    case string(String)

    /// A null id. Valid only in an error response.
    case null
}

/// The `error` object carried by a JSON-RPC error response:
/// `{ code: Int, message: String, data?: JSONValue }`.
public struct MonaJSONRPCErrorPayload: Error, Equatable {

    /// The JSON-RPC error code (e.g. `-32600` for InvalidRequest).
    public let code: Int

    /// A short human-readable summary of the error.
    public let message: String

    /// Optional structured data. `nil` means the `data` field is absent
    /// (distinct from `.null`, which means `data: null` was present).
    public let data: MonaJSONValue?

    /// Creates an error payload.
    public init(
        code: Int, message: String, data: MonaJSONValue? = nil
    ) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// A typed JSON-RPC 2.0 message. The four kinds are distinguished by exact
/// field directionality (the presence/absence of `id` plus the
/// `method`/`result`/`error` field).
public enum MonaJSONRPCMessage: Equatable {

    /// A request: `{ jsonrpc: "2.0", id, method, params? }`. The id is an
    /// integer or string (never null for a request).
    case request(
        id: MonaJSONRPCRequestID, method: String, params: MonaJSONValue?)

    /// A notification: `{ jsonrpc: "2.0", method, params? }`. No `id`
    /// field — the receiver MUST NOT reply.
    case notification(method: String, params: MonaJSONValue?)

    /// A success response: `{ jsonrpc: "2.0", id, result }`. The id is an
    /// integer or string (never null for a success response).
    case response(id: MonaJSONRPCRequestID, result: MonaJSONValue)

    /// An error response: `{ jsonrpc: "2.0", id, error: {code, message, data?} }`.
    /// The id may be an integer, string, or null (null = the peer could not
    /// associate the error with a request).
    case error(id: MonaJSONRPCRequestID, error: MonaJSONRPCErrorPayload)

    // MARK: - Accessors

    /// The message's id, or `nil` if the message is a notification (no id
    /// field). For an error response with a null id, returns `.some(.null)`.
    public var id: MonaJSONRPCRequestID? {
        switch self {
        case .request(let id, _, _): return id
        case .notification: return nil
        case .response(let id, _): return id
        case .error(let id, _): return id
        }
    }

    /// The method name, if this is a request or notification.
    public var method: String? {
        switch self {
        case .request(_, let method, _): return method
        case .notification(let method, _): return method
        case .response, .error: return nil
        }
    }
}
