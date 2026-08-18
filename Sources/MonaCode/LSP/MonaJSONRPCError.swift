// MonaJSONRPCError.swift
//
// P06-T003 — Implement deterministic JSON-RPC wire values and errors.
//
// This file holds the L2-R3-frozen typed error taxonomy for the JSON-RPC
// codec. L2-R3 ("语言基础设施第五轮攻击：L2-R3 wire encoding 与错误方向闭包")
// freezes two rejection categories for malformed wire shapes:
//
//   - ParseError: the body bytes are not well-formed JSON.
//   - InvalidRequest: the bytes are well-formed JSON but not a valid
//     JSON-RPC 2.0 message shape (wrong field directionality, forbidden
//     batch, ambiguous fields, malformed error payload, …).
//
// The taxonomy maps directly to the standard JSON-RPC 2.0 error codes
// (ParseError = -32700, InvalidRequest = -32600, …). When a server-side
// codec rejects an incoming message it surfaces the corresponding wire
// code; the Swift-typed cases here let the codec distinguish WHY a shape
// was rejected without surfacing untrusted body bytes.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Standard JSON-RPC 2.0 error codes (frozen by L2-R3). These are the wire
/// integer codes a peer sends inside an error response's `error.code`.
public enum MonaJSONRPCErrorCode {

    /// Invalid JSON was received. (-32700)
    public static let parseError: Int = -32700

    /// The JSON received is not a valid JSON-RPC 2.0 request/notification.
    /// (-32600)
    public static let invalidRequest: Int = -32600

    /// The method does not exist or is not available. (-32601)
    public static let methodNotFound: Int = -32601

    /// Invalid method parameters. (-32602)
    public static let invalidParams: Int = -32602

    /// Internal JSON-RPC error. (-32603)
    public static let internalError: Int = -32603
}

/// A typed error produced by the JSON-RPC codec (`MonaJSONRPCCodec`) when it
/// rejects malformed wire shapes or cannot encode a value. Each case maps
/// to the L2-R3 error taxonomy.
public enum MonaJSONRPCError: Error, Equatable {

    /// The body bytes are not well-formed JSON (invalid UTF-8, unterminated
    /// string, trailing content, etc.). Maps to JSON-RPC `ParseError`
    /// (-32700).
    case parseError

    /// The bytes are well-formed JSON but not a valid JSON-RPC 2.0 message
    /// shape. `reason` distinguishes which field-directionality rule was
    /// violated. Maps to JSON-RPC `InvalidRequest` (-32600).
    case invalidRequest(MonaJSONRPCInvalidRequestReason)

    /// A `.decimal` value holds `NaN` or infinity and cannot be encoded as
    /// JSON. L2-R3 rejects NaN/Infinity rather than coercing to `null`.
    case numberNotRepresentable
}

/// The detailed reason an `InvalidRequest` shape was rejected. Each case
/// corresponds to a row of the L2-R3 message-shape matrix.
public enum MonaJSONRPCInvalidRequestReason: Equatable {

    /// The top-level JSON value was not an object (a string, number, bool,
    /// or null).
    case notAnObject

    /// The top-level JSON value was an array. L2-R3 forbids JSON-RPC batch
    /// (top-level arrays are rejected with `InvalidRequest`, id=null).
    case batchForbidden

    /// The object had no `jsonrpc` field.
    case missingJSONRPC

    /// The `jsonrpc` field was present but not the string `"2.0"`.
    case invalidJSONRPC

    /// The object had `jsonrpc` but none of the dispatch fields
    /// (`method`, `result`, `error`), so its kind is undeterminable.
    case missingDispatchFields

    /// Ambiguous dispatch fields appeared together: `result` and `error`,
    /// or `method` with `result`/`error`. L2-R3 requires exact field
    /// directionality.
    case ambiguousFields

    /// A request (has `method` + `id`) had `id: null`. The null id is only
    /// valid in an error response (a peer error that cannot be associated
    /// with a request).
    case requestIDIsNull

    /// A success response (has `result`) had no `id` field. A success
    /// response requires an integer/string id.
    case responseMissingID

    /// A success response (has `result`) had `id: null`. The null id is
    /// only valid in an error response.
    case responseIDIsNull

    /// An error response (has `error`) had no `id` field. The id field is
    /// required on every response (it may be `null`, but must be present).
    case errorMissingID

    /// The `error` field was present but not a valid error object
    /// (`{code: Int, message: String, data?: ...}`).
    case errorPayloadMalformed

    /// The `id` field was present but not an integer, string, or null
    /// (e.g. a bool, array, or object — or a decimal non-integer).
    case idTypeInvalid
}
