// MonaJSONRPCCodecTests.swift
//
// P06-T003 — Implement deterministic JSON-RPC wire values and errors.
//
// Verifies the `MonaJSONRPCCodec` / `MonaJSONValue` / `MonaJSONRPCMessage` /
// `MonaJSONRPCError` contract across the four L2-R3-frozen operations:
//   1. Preserve string, integer, and null identifiers without coercion.
//   2. Distinguish requests, notifications, responses, and errors by exact
//      field directionality (presence/absence of `id` + the
//      `method`/`result`/`error` field).
//   3. Emit deterministic object-key order and number spelling for fixture
//      hashes (canonical JSON: sorted keys, no leading zeros, no trailing
//      `.0` on integers, reproducible bytes).
//   4. Reject malformed wire shapes with the L2-R3 typed error taxonomy
//      (`.parseError`, `.invalidRequest(reason)`).

import XCTest
@testable import MonaCode

final class MonaJSONRPCCodecTests: XCTestCase {

    // MARK: - Helpers

    private func decode(_ json: String) -> Result<MonaJSONRPCMessage, MonaJSONRPCError> {
        return MonaJSONRPCCodec().decode(Data(json.utf8))
    }

    private func decodeOK(_ json: String) throws -> MonaJSONRPCMessage {
        return try MonaJSONRPCCodec().decode(Data(json.utf8)).get()
    }

    private func encode(_ message: MonaJSONRPCMessage) -> Data {
        return try! MonaJSONRPCCodec().encode(message).get()
    }

    // MARK: - 1. Identifier type preservation (string / integer / null)

    func testIntegerIDRoundTripsAsInteger() throws {
        let codec = MonaJSONRPCCodec()
        let msg = MonaJSONRPCMessage.request(
            id: .integer(5), method: "initialize", params: nil)
        let bytes = try! codec.encode(msg).get()
        // Wire spelling is a bare integer, not a quoted string.
        XCTAssertEqual(
            bytes,
            Data("{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"initialize\"}".utf8))
        let decoded = try codec.decode(bytes).get()
        guard case .request(let id, _, _) = decoded else {
            return XCTFail("expected request, got \(decoded)")
        }
        XCTAssertEqual(id, .integer(5))
        XCTAssertNotEqual(id, .string("5"))
    }

    func testStringIDRoundTripsAsString() throws {
        let codec = MonaJSONRPCCodec()
        // String id "5" must NOT be coerced to integer 5.
        let msg = MonaJSONRPCMessage.request(
            id: .string("5"), method: "foo", params: nil)
        let bytes = try! codec.encode(msg).get()
        XCTAssertEqual(
            bytes,
            Data("{\"jsonrpc\":\"2.0\",\"id\":\"5\",\"method\":\"foo\"}".utf8))
        let decoded = try codec.decode(bytes).get()
        guard case .request(let id, _, _) = decoded else {
            return XCTFail("expected request, got \(decoded)")
        }
        XCTAssertEqual(id, .string("5"))
        XCTAssertNotEqual(id, .integer(5))
    }

    func testStringIDThatLooksNumericPreservedAsString() throws {
        // A string id whose contents are numeric ("42") stays a string.
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":\"42\",\"method\":\"foo\"}")
        guard case .request(let id, _, _) = msg else {
            return XCTFail("expected request, got \(msg)")
        }
        XCTAssertEqual(id, .string("42"))
        XCTAssertNotEqual(id, .integer(42))
    }

    func testNullIDInErrorResponsePreservedAsNull() throws {
        let codec = MonaJSONRPCCodec()
        let msg = MonaJSONRPCMessage.error(
            id: .null,
            error: MonaJSONRPCErrorPayload(
                code: -32700, message: "Parse error", data: nil))
        let bytes = try! codec.encode(msg).get()
        XCTAssertEqual(bytes, Data((
            "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":"
            + "{\"code\":-32700,\"message\":\"Parse error\"}}").utf8))
        let decoded = try codec.decode(bytes).get()
        guard case .error(let id, let err) = decoded else {
            return XCTFail("expected error, got \(decoded)")
        }
        XCTAssertEqual(id, .null)
        XCTAssertEqual(err.code, -32700)
        XCTAssertEqual(err.message, "Parse error")
    }

    func testDecodeIntegerIDFromWireIsInteger() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"foo\"}")
        guard case .request(let id, _, _) = msg else {
            return XCTFail("expected request, got \(msg)")
        }
        XCTAssertEqual(id, .integer(7))
    }

    func testDecodeStringIDFromWireIsString() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":\"abc\",\"method\":\"foo\"}")
        guard case .request(let id, _, _) = msg else {
            return XCTFail("expected request, got \(msg)")
        }
        XCTAssertEqual(id, .string("abc"))
    }

    // MARK: - 2. Message-kind distinction by exact field directionality

    func testDecodeRequestByIDAndMethod() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}")
        guard case .request(let id, let method, let params) = msg else {
            return XCTFail("expected request, got \(msg)")
        }
        XCTAssertEqual(id, .integer(1))
        XCTAssertEqual(method, "initialize")
        XCTAssertNil(params)
    }

    func testDecodeRequestWithParams() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\","
            + "\"params\":{\"a\":1}}")
        guard case .request(_, _, let params) = msg else {
            return XCTFail("expected request, got \(msg)")
        }
        XCTAssertEqual(params, .object([("a", .integer(1))]))
    }

    func testDecodeNotificationByMethodNoID() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"method\":\"didChange\"}")
        guard case .notification(let method, let params) = msg else {
            return XCTFail("expected notification, got \(msg)")
        }
        XCTAssertEqual(method, "didChange")
        XCTAssertNil(params)
    }

    func testNotificationHasNilID() throws {
        // A notification has NO id field at all — `id` accessor is nil.
        let msg = MonaJSONRPCMessage.notification(method: "didChange", params: nil)
        XCTAssertNil(msg.id)
    }

    func testDecodeNotificationWithParams() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"method\":\"didChange\",\"params\":[1,2]}")
        guard case .notification(_, let params) = msg else {
            return XCTFail("expected notification, got \(msg)")
        }
        XCTAssertEqual(params, .array([.integer(1), .integer(2)]))
    }

    func testDecodeSuccessResponseByIDAndResult() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"x\":2}}")
        guard case .response(let id, let result) = msg else {
            return XCTFail("expected response, got \(msg)")
        }
        XCTAssertEqual(id, .integer(1))
        XCTAssertEqual(result, .object([("x", .integer(2))]))
    }

    func testDecodeErrorResponseByIDAndError() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":1,"
            + "\"error\":{\"code\":-32600,\"message\":\"Invalid Request\"}}")
        guard case .error(let id, let err) = msg else {
            return XCTFail("expected error response, got \(msg)")
        }
        XCTAssertEqual(id, .integer(1))
        XCTAssertEqual(err.code, -32600)
        XCTAssertEqual(err.message, "Invalid Request")
        XCTAssertNil(err.data)
    }

    func testDecodeErrorResponseWithNullID() throws {
        // null id is valid ONLY in an error response (peer error that can't
        // be associated with a request).
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":null,"
            + "\"error\":{\"code\":-32700,\"message\":\"Parse error\"}}")
        guard case .error(let id, _) = msg else {
            return XCTFail("expected error response, got \(msg)")
        }
        XCTAssertEqual(id, .null)
    }

    func testDecodeErrorResponseWithData() throws {
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":"
            + "{\"code\":-32601,\"message\":\"Method not found\","
            + "\"data\":\"foo\"}}")
        guard case .error(_, let err) = msg else {
            return XCTFail("expected error response, got \(msg)")
        }
        XCTAssertEqual(err.code, -32601)
        XCTAssertEqual(err.data, .string("foo"))
    }

    // MARK: - 3. Deterministic encoding (key order + number spelling)

    func testEncodeRequestGoldenBytes() {
        let bytes = encode(.request(
            id: .integer(5), method: "initialize",
            params: .object([("b", .integer(1)), ("a", .integer(2))])))
        // Field order: jsonrpc, id, method, params.
        // Object keys sorted by UTF-16 lexicographic order: a < b.
        XCTAssertEqual(bytes, Data((
            "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"initialize\","
            + "\"params\":{\"a\":2,\"b\":1}}").utf8))
    }

    func testEncodeNotificationGoldenBytes() {
        // A notification has NO id field (field directionality: method, no id).
        let bytes = encode(.notification(method: "didChange", params: nil))
        XCTAssertEqual(bytes, Data(
            "{\"jsonrpc\":\"2.0\",\"method\":\"didChange\"}".utf8))
    }

    func testEncodeResponseGoldenBytes() {
        let bytes = encode(.response(
            id: .integer(5), result: .bool(true)))
        // Field order: jsonrpc, id, result.
        XCTAssertEqual(bytes, Data(
            "{\"jsonrpc\":\"2.0\",\"id\":5,\"result\":true}".utf8))
    }

    func testEncodeErrorGoldenBytes() {
        let bytes = encode(.error(
            id: .integer(5),
            error: MonaJSONRPCErrorPayload(
                code: -32600, message: "Invalid Request", data: nil)))
        // Field order: jsonrpc, id, error. Error object order: code, message.
        XCTAssertEqual(bytes, Data((
            "{\"jsonrpc\":\"2.0\",\"id\":5,\"error\":"
            + "{\"code\":-32600,\"message\":\"Invalid Request\"}}").utf8))
    }

    func testEncodeErrorWithDataGoldenBytes() {
        let bytes = encode(.error(
            id: .integer(1),
            error: MonaJSONRPCErrorPayload(
                code: -32601, message: "Method not found",
                data: .string("foo"))))
        // Error object order: code, message, data.
        XCTAssertEqual(bytes, Data((
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":"
            + "{\"code\":-32601,\"message\":\"Method not found\","
            + "\"data\":\"foo\"}}").utf8))
    }

    func testObjectKeysEmittedInUTF16LexicographicOrder() {
        // "Z" (U+005A) precedes "a" (U+0061) in raw UTF-16 lexicographic
        // order, even though Unicode collation would sort "a" before "Z".
        let bytes = encode(.request(
            id: .integer(1), method: "m",
            params: .object([("a", .integer(1)), ("Z", .integer(2))])))
        XCTAssertTrue(String(data: bytes, encoding: .utf8)!.contains("\"Z\":2,\"a\":1"))
    }

    func testObjectKeyPrefixSortsShorterFirst() {
        // "a" is a prefix of "ab"; shorter sorts first.
        let bytes = encode(.request(
            id: .integer(1), method: "m",
            params: .object([("ab", .integer(9)), ("a", .integer(8))])))
        XCTAssertTrue(String(data: bytes, encoding: .utf8)!.contains("\"a\":8,\"ab\":9"))
    }

    func testIntegerNumberSpellingNoTrailingDotZero() {
        // An integer value spells without a trailing `.0`.
        let bytes = encode(.response(
            id: .integer(1), result: .integer(5)))
        let s = String(data: bytes, encoding: .utf8)!
        XCTAssertTrue(s.contains("\"result\":5"))
        XCTAssertFalse(s.contains("\"result\":5.0"))
    }

    func testZeroIntegerSpellsAsZero() {
        let bytes = encode(.response(
            id: .integer(0), result: .integer(0)))
        let s = String(data: bytes, encoding: .utf8)!
        XCTAssertTrue(s.contains("\"id\":0,"))
        XCTAssertTrue(s.contains("\"result\":0}"))
    }

    func testNegativeIntegerNumberSpelling() {
        let bytes = encode(.response(
            id: .integer(-3), result: .integer(-7)))
        let s = String(data: bytes, encoding: .utf8)!
        XCTAssertTrue(s.contains("\"id\":-3,"))
        XCTAssertTrue(s.contains("\"result\":-7}"))
    }

    func testDecimalNumberSpelling() {
        let bytes = encode(.response(
            id: .integer(1), result: .number(.decimal(1.5))))
        let s = String(data: bytes, encoding: .utf8)!
        XCTAssertTrue(s.contains("\"result\":1.5"))
    }

    func testEncodeIsDeterministicSameMessageSameBytes() {
        // The same message must always produce identical bytes (fixture
        // hashes are reproducible).
        let codec = MonaJSONRPCCodec()
        let msg = MonaJSONRPCMessage.request(
            id: .integer(5), method: "initialize",
            params: .object([("b", .integer(1)), ("a", .integer(2)),
                             ("Z", .integer(3))]))
        let b1 = try! codec.encode(msg).get()
        let b2 = try! codec.encode(msg).get()
        XCTAssertEqual(b1, b2)
    }

    func testDecodeNonCanonicalKeyOrderNormalizesOnReencode() {
        // Wire bytes with non-canonical (unsorted) object keys decode to a
        // value tree whose canonical re-encoding has sorted keys.
        let codec = MonaJSONRPCCodec()
        let wire = Data((
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"m\","
            + "\"params\":{\"b\":1,\"a\":2}}").utf8)
        let decoded = try! codec.decode(wire).get()
        let reencoded = try! codec.encode(decoded).get()
        XCTAssertEqual(reencoded, Data((
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"m\","
            + "\"params\":{\"a\":2,\"b\":1}}").utf8))
    }

    func testDuplicateObjectKeyLastValueWinsOnDecode() throws {
        // Per L2-R3: duplicate object key adopts the last value, consistent
        // with the fixed JS oracle.
        let msg = try decodeOK(
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"m\","
            + "\"params\":{\"a\":1,\"a\":2}}")
        guard case .request(_, _, let params) = msg else {
            return XCTFail("expected request, got \(msg)")
        }
        XCTAssertEqual(params, .object([("a", .integer(2))]))
    }

    // MARK: - 4. Malformed-shape rejection with L2-R3 typed errors

    func testRejectMalformedJSONParseError() {
        XCTAssertEqual(decode("{bad json"), .failure(.parseError))
        XCTAssertEqual(decode(""), .failure(.parseError))
        XCTAssertEqual(decode("{\"id\":1"), .failure(.parseError))
        XCTAssertEqual(decode("{\"id\":1}trailing"), .failure(.parseError))
    }

    func testRejectTopLevelArrayBatchForbidden() {
        // JSON-RPC batch (top-level array) is forbidden by L2-R3.
        XCTAssertEqual(
            decode("[{\"jsonrpc\":\"2.0\"}]"),
            .failure(.invalidRequest(.batchForbidden)))
    }

    func testRejectTopLevelStringNotAnObject() {
        XCTAssertEqual(
            decode("\"hello\""),
            .failure(.invalidRequest(.notAnObject)))
    }

    func testRejectTopLevelNumberNotAnObject() {
        XCTAssertEqual(
            decode("42"),
            .failure(.invalidRequest(.notAnObject)))
    }

    func testRejectTopLevelBoolNotAnObject() {
        XCTAssertEqual(
            decode("true"),
            .failure(.invalidRequest(.notAnObject)))
    }

    func testRejectTopLevelNullNotAnObject() {
        XCTAssertEqual(
            decode("null"),
            .failure(.invalidRequest(.notAnObject)))
    }

    func testRejectMissingJSONRPC() {
        XCTAssertEqual(
            decode("{\"id\":1,\"method\":\"foo\"}"),
            .failure(.invalidRequest(.missingJSONRPC)))
    }

    func testRejectInvalidJSONRPCVersion() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"1.0\",\"id\":1,\"method\":\"foo\"}"),
            .failure(.invalidRequest(.invalidJSONRPC)))
        XCTAssertEqual(
            decode("{\"jsonrpc\":2,\"id\":1,\"method\":\"foo\"}"),
            .failure(.invalidRequest(.invalidJSONRPC)))
    }

    func testRejectMissingDispatchFields() {
        // jsonrpc present but none of method/result/error.
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\"}"),
            .failure(.invalidRequest(.missingDispatchFields)))
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1}"),
            .failure(.invalidRequest(.missingDispatchFields)))
    }

    func testRejectAmbiguousResultAndError() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1,"
                + "\"result\":{},\"error\":{\"code\":1,\"message\":\"x\"}}"),
            .failure(.invalidRequest(.ambiguousFields)))
    }

    func testRejectAmbiguousMethodAndResult() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1,"
                + "\"method\":\"foo\",\"result\":{}}"),
            .failure(.invalidRequest(.ambiguousFields)))
    }

    func testRejectAmbiguousMethodAndError() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1,"
                + "\"method\":\"foo\",\"error\":{\"code\":1,\"message\":\"x\"}}"),
            .failure(.invalidRequest(.ambiguousFields)))
    }

    func testRejectRequestWithNullID() {
        // A request (has method + id) with id=null is invalid: null id is
        // only valid in an error response.
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":null,\"method\":\"foo\"}"),
            .failure(.invalidRequest(.requestIDIsNull)))
    }

    func testRejectSuccessResponseMissingID() {
        // A success response (has result) requires an id.
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"result\":{}}"),
            .failure(.invalidRequest(.responseMissingID)))
    }

    func testRejectSuccessResponseWithNullID() {
        // A success response with id=null is invalid: null id is only valid
        // in an error response.
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":null,\"result\":{}}"),
            .failure(.invalidRequest(.responseIDIsNull)))
    }

    func testRejectErrorResponseMissingID() {
        // An error response requires an id field (which may be null, but
        // must be present).
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\","
                + "\"error\":{\"code\":1,\"message\":\"x\"}}"),
            .failure(.invalidRequest(.errorMissingID)))
    }

    func testRejectErrorPayloadMissingCode() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1,"
                + "\"error\":{\"message\":\"x\"}}"),
            .failure(.invalidRequest(.errorPayloadMalformed)))
    }

    func testRejectErrorPayloadMissingMessage() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1,"
                + "\"error\":{\"code\":1}}"),
            .failure(.invalidRequest(.errorPayloadMalformed)))
    }

    func testRejectErrorPayloadNotObject() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":\"nope\"}"),
            .failure(.invalidRequest(.errorPayloadMalformed)))
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":42}"),
            .failure(.invalidRequest(.errorPayloadMalformed)))
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":null}"),
            .failure(.invalidRequest(.errorPayloadMalformed)))
    }

    func testRejectIDTypeBool() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":true,\"method\":\"foo\"}"),
            .failure(.invalidRequest(.idTypeInvalid)))
    }

    func testRejectIDTypeArray() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":[1],\"method\":\"foo\"}"),
            .failure(.invalidRequest(.idTypeInvalid)))
    }

    func testRejectIDTypeObject() {
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":{},\"method\":\"foo\"}"),
            .failure(.invalidRequest(.idTypeInvalid)))
    }

    func testRejectIDTypeDecimal() {
        // A decimal (non-integer) id is not a valid JSON-RPC id.
        XCTAssertEqual(
            decode("{\"jsonrpc\":\"2.0\",\"id\":1.5,\"method\":\"foo\"}"),
            .failure(.invalidRequest(.idTypeInvalid)))
    }

    // MARK: - Round-trip: all message kinds

    func testRoundTripAllMessageKinds() throws {
        let codec = MonaJSONRPCCodec()
        let messages: [MonaJSONRPCMessage] = [
            .request(id: .integer(1), method: "initialize",
                     params: .object([("capability", .bool(true))])),
            .request(id: .string("req-1"), method: "shutdown", params: nil),
            .notification(method: "didChange",
                          params: .array([.integer(1)])),
            .response(id: .integer(1), result: .null),
            .error(id: .integer(1),
                   error: MonaJSONRPCErrorPayload(
                       code: -32601, message: "Method not found",
                       data: .object([("method", .string("foo"))]))),
            .error(id: .null,
                   error: MonaJSONRPCErrorPayload(
                       code: -32700, message: "Parse error", data: nil)),
        ]
        for msg in messages {
            let bytes = try codec.encode(msg).get()
            let decoded = try codec.decode(bytes).get()
            XCTAssertEqual(decoded, msg, "round-trip failed for \(msg)")
        }
    }
}
