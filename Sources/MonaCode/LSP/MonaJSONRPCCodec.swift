// MonaJSONRPCCodec.swift
//
// P06-T003 — Implement deterministic JSON-RPC wire values and errors.
//
// `MonaJSONRPCCodec` is the JSON-RPC 2.0 message codec. It sits above the
// frame codec (`MonaLSPFrameDecoder` / `MonaLSPFrameEncoder` from P06-T002)
// and below the session layer (T004). The frame codec carries raw bytes; this
// codec encodes typed `MonaJSONRPCMessage` values into canonical bytes and
// decodes bytes into typed messages, rejecting malformed wire shapes with
// the L2-R3 typed error taxonomy.
//
// It is the Swift counterpart of Monaco's JSON-RPC message reader/writer
// (monaco-editor 0.56.0, vendored from vscode's `vscode-jsonrpc`).
//
// Two L2-R3-frozen properties govern the codec:
//
//   1. Canonical byte representation. The envelope fields are emitted in the
//      fixed order `jsonrpc, id, method, params, result, error`; the nested
//      error payload in schema order `code, message, data`; general map
//      keys (in params/result/data) in raw UTF-16 lexicographic order.
//      Integers spell without leading zeros or a trailing `.0`; decimals
//      via the shortest round-trip binary64 spelling. The encoded bytes are
//      therefore reproducible — identical messages always produce identical
//      bytes, so fixture hashes are stable.
//
//   2. Exact field directionality on decode. The four message kinds are
//      distinguished by the presence/absence of `id` plus the
//      `method`/`result`/`error` field: request = id + method;
//      notification = method (no id); response = id + result;
//      error = id + error. A null id is valid ONLY in an error response.
//      Malformed shapes are rejected with `.parseError` (bad JSON) or
//      `.invalidRequest(reason)` (valid JSON, wrong shape).
//
// `MonaJSONRPCCodec` is a value type (a `struct`): it is a stateless,
// referentially-transparent transform — no mutable state, no identity —
// matching the `MonaLSPFrameEncoder` convention. Instances are freely
// copyable; one `init()` and two methods.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A stateless JSON-RPC 2.0 message codec — encodes typed messages into
/// canonical bytes and decodes bytes into typed messages with L2-R3 typed
/// errors.
///
/// Create with `init()`, then call `encode(_:)` / `decode(_:)`. See the
/// file header for the full encode/decode contract.
public struct MonaJSONRPCCodec {

    /// Creates a new stateless JSON-RPC codec.
    public init() {}

    /// Encodes `message` into canonical JSON-RPC 2.0 bytes.
    ///
    /// The envelope fields are emitted in the fixed L2-R3 order
    /// (`jsonrpc, id, method, params, result, error`); the nested error
    /// payload in schema order (`code, message, data`); general map keys
    /// in raw UTF-16 lexicographic order. Identical messages always produce
    /// identical bytes.
    ///
    /// Returns `.failure(.numberNotRepresentable)` if a `.decimal` value in
    /// the message holds `NaN` or infinity (L2-R3: rejected, never coerced
    /// to `null`).
    public func encode(
        _ message: MonaJSONRPCMessage
    ) -> Result<Data, MonaJSONRPCError> {
        var sink = _MonaJSONEncodeSink()
        sink.append("{\"jsonrpc\":\"2.0\"")
        switch message {
        case .request(let id, let method, let params):
            appendID(id, into: &sink)
            sink.append(",\"method\":")
            _MonaJSONEncoder.encodeString(method, into: &sink)
            if let params = params {
                sink.append(",\"params\":")
                if case .failure(let err) = _MonaJSONEncoder.encode(
                    params, into: &sink) {
                    return .failure(err)
                }
            }
        case .notification(let method, let params):
            sink.append(",\"method\":")
            _MonaJSONEncoder.encodeString(method, into: &sink)
            if let params = params {
                sink.append(",\"params\":")
                if case .failure(let err) = _MonaJSONEncoder.encode(
                    params, into: &sink) {
                    return .failure(err)
                }
            }
        case .response(let id, let result):
            appendID(id, into: &sink)
            sink.append(",\"result\":")
            if case .failure(let err) = _MonaJSONEncoder.encode(
                result, into: &sink) {
                return .failure(err)
            }
        case .error(let id, let payload):
            appendID(id, into: &sink)
            sink.append(",\"error\":")
            if case .failure(let err) = appendErrorPayload(
                payload, into: &sink) {
                return .failure(err)
            }
        }
        sink.append("}")
        return .success(Data(sink.bytes))
    }

    /// Decodes canonical (or non-canonical) JSON-RPC 2.0 bytes into a typed
    /// `MonaJSONRPCMessage`.
    ///
    /// Returns `.failure(.parseError)` if the bytes are not well-formed
    /// JSON. Returns `.failure(.invalidRequest(reason))` if the JSON is
    /// well-formed but not a valid JSON-RPC 2.0 message shape (wrong field
    /// directionality, forbidden batch, ambiguous fields, malformed error
    /// payload, invalid id type, …). The `id` is preserved without coercion
    /// (string stays string, integer stays integer, null stays null).
    public func decode(
        _ data: Data
    ) -> Result<MonaJSONRPCMessage, MonaJSONRPCError> {
        switch MonaJSONValue.parse(data) {
        case .failure:
            return .failure(.parseError)
        case .success(let value):
            return Self.decodeMessage(from: value)
        }
    }

    // MARK: - Private (encode)

    private func appendID(
        _ id: MonaJSONRPCRequestID, into sink: inout _MonaJSONEncodeSink
    ) {
        sink.append(",\"id\":")
        switch id {
        case .integer(let i):
            sink.append(String(i))
        case .string(let s):
            _MonaJSONEncoder.encodeString(s, into: &sink)
        case .null:
            sink.append("null")
        }
    }

    private func appendErrorPayload(
        _ payload: MonaJSONRPCErrorPayload,
        into sink: inout _MonaJSONEncodeSink
    ) -> Result<Void, MonaJSONRPCError> {
        sink.append("{")
        sink.append("\"code\":")
        sink.append(String(payload.code))
        sink.append(",\"message\":")
        _MonaJSONEncoder.encodeString(payload.message, into: &sink)
        if let data = payload.data {
            sink.append(",\"data\":")
            if case .failure(let err) = _MonaJSONEncoder.encode(
                data, into: &sink) {
                return .failure(err)
            }
        }
        sink.append("}")
        return .success(())
    }

    // MARK: - Private (decode)

    /// Validates the message shape and constructs the typed message.
    static func decodeMessage(
        from value: MonaJSONValue
    ) -> Result<MonaJSONRPCMessage, MonaJSONRPCError> {

        // Top-level must be a JSON object.
        guard case .object(let fields) = value else {
            if case .array = value {
                return .failure(.invalidRequest(.batchForbidden))
            }
            return .failure(.invalidRequest(.notAnObject))
        }

        // Build a last-value-wins key map (objects are already deduped by
        // the parser, but this is safe regardless).
        var fieldMap: [String: MonaJSONValue] = [:]
        for entry in fields {
            fieldMap[entry.key] = entry.value
        }

        // jsonrpc must be the string "2.0".
        guard let jsonrpc = fieldMap["jsonrpc"] else {
            return .failure(.invalidRequest(.missingJSONRPC))
        }
        guard case .string(let version) = jsonrpc, version == "2.0" else {
            return .failure(.invalidRequest(.invalidJSONRPC))
        }

        // Identify dispatch fields. `method` counts only if it is a string.
        let methodValue = fieldMap["method"]
        let methodString: String? = methodValue.flatMap {
            if case .string(let s) = $0 { return s } else { return nil }
        }
        let hasMethod = methodString != nil
        let hasResult = fieldMap["result"] != nil
        let hasError = fieldMap["error"] != nil

        let dispatchCount = (hasMethod ? 1 : 0)
            + (hasResult ? 1 : 0) + (hasError ? 1 : 0)
        if dispatchCount == 0 {
            return .failure(.invalidRequest(.missingDispatchFields))
        }
        if dispatchCount > 1 {
            return .failure(.invalidRequest(.ambiguousFields))
        }

        let idValue = fieldMap["id"]
        let hasID = idValue != nil

        // Exactly one dispatch field — determine the kind.
        if hasMethod {
            let method = methodString!
            let params = fieldMap["params"]
            if hasID {
                // Request: id must be integer/string (NOT null).
                switch Self.classifyID(idValue!) {
                case .ok(let id):
                    return .success(.request(
                        id: id, method: method, params: params))
                case .null:
                    return .failure(.invalidRequest(.requestIDIsNull))
                case .invalidType:
                    return .failure(.invalidRequest(.idTypeInvalid))
                }
            } else {
                // Notification (no id field).
                return .success(.notification(method: method, params: params))
            }
        }

        if hasResult {
            // Success response: id required, must be integer/string (NOT null).
            guard hasID else {
                return .failure(.invalidRequest(.responseMissingID))
            }
            switch Self.classifyID(idValue!) {
            case .ok(let id):
                return .success(.response(id: id, result: fieldMap["result"]!))
            case .null:
                return .failure(.invalidRequest(.responseIDIsNull))
            case .invalidType:
                return .failure(.invalidRequest(.idTypeInvalid))
            }
        }

        // Error response: id required (may be null), error payload must be valid.
        guard hasID else {
            return .failure(.invalidRequest(.errorMissingID))
        }
        let id: MonaJSONRPCRequestID
        switch Self.classifyID(idValue!) {
        case .ok(let value):
            id = value
        case .null:
            id = .null
        case .invalidType:
            return .failure(.invalidRequest(.idTypeInvalid))
        }
        switch Self.parseErrorPayload(fieldMap["error"]!) {
        case .success(let payload):
            return .success(.error(id: id, error: payload))
        case .failure(let err):
            return .failure(err)
        }
    }

    /// Classifies an `id` value. `null` is distinguished from `invalidType`
    /// because the null-id rule differs by message kind (valid for error,
    /// invalid for request/response).
    private enum IDClassification {
        case ok(MonaJSONRPCRequestID)
        case null
        case invalidType
    }

    private static func classifyID(_ value: MonaJSONValue) -> IDClassification {
        switch value {
        case .number(.integer(let i)):
            return .ok(.integer(i))
        case .number(.decimal):
            return .invalidType  // a non-integer number is not a valid id
        case .string(let s):
            return .ok(.string(s))
        case .null:
            return .null
        default:
            return .invalidType  // bool, array, or object
        }
    }

    /// Parses the `error` object `{ code: Int, message: String, data?: ... }`.
    /// Returns `.failure(.invalidRequest(.errorPayloadMalformed))` if the
    /// payload is not a valid error object.
    private static func parseErrorPayload(
        _ value: MonaJSONValue
    ) -> Result<MonaJSONRPCErrorPayload, MonaJSONRPCError> {
        guard case .object(let pairs) = value else {
            return .failure(.invalidRequest(.errorPayloadMalformed))
        }
        var fieldMap: [String: MonaJSONValue] = [:]
        for entry in pairs {
            fieldMap[entry.key] = entry.value
        }
        guard let codeValue = fieldMap["code"] else {
            return .failure(.invalidRequest(.errorPayloadMalformed))
        }
        guard case .number(.integer(let code)) = codeValue else {
            return .failure(.invalidRequest(.errorPayloadMalformed))
        }
        guard let messageValue = fieldMap["message"] else {
            return .failure(.invalidRequest(.errorPayloadMalformed))
        }
        guard case .string(let message) = messageValue else {
            return .failure(.invalidRequest(.errorPayloadMalformed))
        }
        let data = fieldMap["data"]
        return .success(MonaJSONRPCErrorPayload(
            code: Int(code), message: message, data: data))
    }
}
