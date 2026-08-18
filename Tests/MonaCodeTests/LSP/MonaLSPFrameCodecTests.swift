// MonaLSPFrameCodecTests.swift
//
// P06-T002 — Implement streaming LSP frame decoding and encoding.
//
// Verifies the `MonaLSPFrameDecoder` / `MonaLSPFrameEncoder` contract:
//   - Decode: arbitrary header/body fragmentation with exact Content-Length
//     validation (header split, body split, multi-frame chunk, partial frame +
//     start of next, single-byte feeds).
//   - Decode: duplicate, malformed, negative, overflowed, missing, and
//     oversized Content-Length each produce a typed terminal error; after the
//     error the decoder is terminal.
//   - Encode: canonical ASCII headers (`Content-Length: N\r\n\r\n`) + raw JSON
//     payload bytes, with no text normalization (multibyte UTF-8 passes
//     through byte-for-byte).

import XCTest
@testable import MonaCode

final class MonaLSPFrameCodecTests: XCTestCase {

    // MARK: - Test helpers

    /// Builds a Content-Length-framed message INDEPENDENTLY of the encoder
    /// under test, so decode tests do not depend on encoder correctness.
    private func framed(_ payload: Data) -> Data {
        return Data("Content-Length: \(payload.count)\r\n\r\n".utf8) + payload
    }

    /// Feeds `data` through `decoder` in fixed-size chunks, accumulating
    /// decoded frames and capturing the first terminal error (if any).
    private func feedChunked(
        _ decoder: MonaLSPFrameDecoder,
        _ data: Data,
        chunkSize: Int
    ) -> (frames: [Data], error: MonaLSPFrameCodecError?) {
        var frames: [Data] = []
        var terminal: MonaLSPFrameCodecError? = nil
        var i = 0
        while i < data.count {
            let end = min(i + max(chunkSize, 1), data.count)
            let result = decoder.feed(data.subdata(in: i..<end))
            frames.append(contentsOf: result.frames)
            if let err = result.error {
                terminal = err
                break
            }
            i = end
        }
        return (frames, terminal)
    }

    /// Feeds `data` one byte at a time — the most aggressive fragmentation.
    private func feedByteByByte(
        _ decoder: MonaLSPFrameDecoder,
        _ data: Data
    ) -> (frames: [Data], error: MonaLSPFrameCodecError?) {
        return feedChunked(decoder, data, chunkSize: 1)
    }

    // MARK: - Encode: canonical ASCII headers + raw payload bytes

    func testEncodeProducesCanonicalASCIIHeadersAndRawPayload() {
        let encoder = MonaLSPFrameEncoder()
        let payload = Data("{\"jsonrpc\":\"2.0\"}".utf8)
        let framed = encoder.encode(payload)
        let expected = Data("Content-Length: \(payload.count)\r\n\r\n".utf8) + payload
        XCTAssertEqual(framed, expected)
    }

    func testEncodePassesRawMultibytePayloadWithoutNormalization() {
        // Multibyte UTF-8 payload must pass through byte-for-byte — no String
        // normalization, no encoding conversion.
        let encoder = MonaLSPFrameEncoder()
        let payload = Data("héllo→世界🌱".utf8)
        let framed = encoder.encode(payload)
        let header = Data("Content-Length: \(payload.count)\r\n\r\n".utf8)
        XCTAssertEqual(framed, header + payload)
        // The trailing payload portion is byte-identical to the input.
        let payloadStart = framed.count - payload.count
        XCTAssertEqual(framed.subdata(in: payloadStart..<framed.count), payload)
    }

    func testEncodeEmptyPayload() {
        let encoder = MonaLSPFrameEncoder()
        let framed = encoder.encode(Data())
        XCTAssertEqual(framed, Data("Content-Length: 0\r\n\r\n".utf8))
    }

    func testEncodeHeaderIsASCIICanonical() {
        // The header is exactly `Content-Length: N\r\n\r\n` — CRLF terminators,
        // a single space after the colon, ASCII digits only.
        let encoder = MonaLSPFrameEncoder()
        let payload = Data([0x01, 0x02, 0x03])
        let framed = encoder.encode(payload)
        let headerEnd = framed.firstRange(of: Data([0x0D, 0x0A, 0x0D, 0x0A]))!
        let headerString = String(data: framed.subdata(in: 0..<headerEnd.lowerBound),
                                 encoding: .ascii)!
        XCTAssertEqual(headerString, "Content-Length: 3")
        // The two CRLFs are the terminator, nothing more.
        XCTAssertEqual(
            framed.subdata(in: headerEnd.lowerBound..<headerEnd.upperBound),
            Data([0x0D, 0x0A, 0x0D, 0x0A])
        )
    }

    // MARK: - Decode: single complete frame

    func testDecodeSingleCompleteFrame() {
        let decoder = MonaLSPFrameDecoder()
        let payload = Data("{\"id\":1}".utf8)
        let result = decoder.feed(framed(payload))
        XCTAssertEqual(result.frames, [payload])
        XCTAssertNil(result.error)
    }

    // MARK: - Decode: fragmentation patterns

    func testDecodeHeaderSplitAcrossChunks() {
        let decoder = MonaLSPFrameDecoder()
        let payload = Data("{\"id\":1}".utf8)
        let frame = framed(payload)
        // Split the header in the middle (inside "Content-Length").
        let mid = 8
        var frames: [Data] = []
        var terminal: MonaLSPFrameCodecError? = nil

        var r = decoder.feed(frame.subdata(in: 0..<mid))
        frames.append(contentsOf: r.frames)
        if let e = r.error { terminal = e }

        if terminal == nil {
            r = decoder.feed(frame.subdata(in: mid..<frame.count))
            frames.append(contentsOf: r.frames)
            if let e = r.error { terminal = e }
        }

        XCTAssertEqual(frames, [payload])
        XCTAssertNil(terminal)
    }

    func testDecodeBodySplitAcrossChunks() {
        let decoder = MonaLSPFrameDecoder()
        let payload = Data("body-bytes-here".utf8)
        let frame = framed(payload)
        // Feed the full header + first half of the body, then the rest.
        let bodyStart = frame.count - payload.count
        let split = bodyStart + payload.count / 2

        var r = decoder.feed(frame.subdata(in: 0..<split))
        // No complete frame yet — body is partial.
        XCTAssertEqual(r.frames, [])
        XCTAssertNil(r.error)

        r = decoder.feed(frame.subdata(in: split..<frame.count))
        XCTAssertEqual(r.frames, [payload])
        XCTAssertNil(r.error)
    }

    func testDecodeMultipleFramesInOneChunk() {
        let decoder = MonaLSPFrameDecoder()
        let p1 = Data("{\"id\":1}".utf8)
        let p2 = Data("{\"id\":2}".utf8)
        let chunk = framed(p1) + framed(p2)
        let result = decoder.feed(chunk)
        XCTAssertEqual(result.frames, [p1, p2])
        XCTAssertNil(result.error)
    }

    func testDecodePartialFrameThenStartOfNextInSameChunk() {
        let decoder = MonaLSPFrameDecoder()
        let p1 = Data("{\"id\":1}".utf8)
        let p2 = Data("{\"id\":2}".utf8)
        let frame1 = framed(p1)
        // Chunk = complete frame1 + first 5 bytes of frame2's header.
        let partialHeader = Data("Content-L".utf8)
        let chunk1 = frame1 + partialHeader

        var r = decoder.feed(chunk1)
        XCTAssertEqual(r.frames, [p1])  // frame1 decoded; frame2 header partial
        XCTAssertNil(r.error)

        // Now feed the remainder of frame2.
        let frame2 = framed(p2)
        let remainder = frame2.subdata(in: partialHeader.count..<frame2.count)
        r = decoder.feed(remainder)
        XCTAssertEqual(r.frames, [p2])
        XCTAssertNil(r.error)
    }

    func testDecodeByteByByteFragmentation() {
        // The strongest fragmentation test: feed one byte at a time.
        let decoder = MonaLSPFrameDecoder()
        let p1 = Data("{\"id\":1}".utf8)
        let p2 = Data("hello".utf8)
        let stream = framed(p1) + framed(p2)
        let (frames, err) = feedByteByByte(decoder, stream)
        XCTAssertEqual(frames, [p1, p2])
        XCTAssertNil(err)
    }

    func testDecodeRandomChunkSizesReconstructsFrames() {
        // Feed the same stream in several chunk sizes; all must reconstruct
        // the same frames.
        let p1 = Data("{\"method\":\"initialize\"}".utf8)
        let p2 = Data("ok".utf8)
        let p3 = Data("第三个".utf8)
        let stream = framed(p1) + framed(p2) + framed(p3)
        for chunkSize in [1, 2, 3, 5, 7, 13, 50] {
            let decoder = MonaLSPFrameDecoder()
            let (frames, err) = feedChunked(decoder, stream, chunkSize: chunkSize)
            XCTAssertEqual(frames, [p1, p2, p3], "chunkSize=\(chunkSize)")
            XCTAssertNil(err, "chunkSize=\(chunkSize)")
        }
    }

    // MARK: - Decode: exact Content-Length validation (body is exactly N bytes)

    func testDecodeBodyIsExactlyContentLengthBytes() {
        // If the stream carries extra trailing bytes after the declared body,
        // those belong to the NEXT frame's header — they must NOT bleed into
        // the current frame's body.
        let decoder = MonaLSPFrameDecoder()
        let payload = Data("abc".utf8)  // exactly 3 bytes
        // Craft a header that lies: Content-Length: 2, body "abc" (3 bytes).
        // The decoder must take EXACTLY 2 bytes ("ab") and leave "c" for the
        // next frame's header (which will then fail to parse as a header).
        let lieHeader = Data("Content-Length: 2\r\n\r\n".utf8)
        let stream = lieHeader + Data("abc".utf8)
        let r = decoder.feed(stream)
        XCTAssertEqual(r.frames, [Data("ab".utf8)])
        XCTAssertNil(r.error)  // "c" is buffered as the start of the next header
    }

    // MARK: - Decode: typed terminal errors for each malformed-length case

    func testDecodeRejectsDuplicateContentLength() {
        let decoder = MonaLSPFrameDecoder()
        let stream = Data("Content-Length: 1\r\nContent-Length: 2\r\n\r\n".utf8)
        let r = decoder.feed(stream)
        XCTAssertEqual(r.frames, [])
        XCTAssertEqual(r.error, .duplicateContentLength)
    }

    func testDecodeRejectsMalformedContentLength() {
        let decoder = MonaLSPFrameDecoder()
        let stream = Data("Content-Length: abc\r\n\r\n".utf8)
        let r = decoder.feed(stream)
        XCTAssertEqual(r.frames, [])
        XCTAssertEqual(r.error, .malformedLength)
    }

    func testDecodeRejectsNegativeContentLength() {
        let decoder = MonaLSPFrameDecoder()
        let stream = Data("Content-Length: -5\r\n\r\n".utf8)
        let r = decoder.feed(stream)
        XCTAssertEqual(r.frames, [])
        XCTAssertEqual(r.error, .negativeLength)
    }

    func testDecodeRejectsOverflowedContentLength() {
        // A value whose digits exceed Int's representable range.
        let decoder = MonaLSPFrameDecoder()
        let overflow = "99999999999999999999999999"  // 26 nines — overflows Int64
        let stream = Data("Content-Length: \(overflow)\r\n\r\n".utf8)
        let r = decoder.feed(stream)
        XCTAssertEqual(r.frames, [])
        XCTAssertEqual(r.error, .overflowedLength)
    }

    func testDecodeRejectsMissingContentLength() {
        // Headers present but none is Content-Length.
        let decoder = MonaLSPFrameDecoder()
        let stream = Data("Content-Type: application/json\r\n\r\n".utf8)
        let r = decoder.feed(stream)
        XCTAssertEqual(r.frames, [])
        XCTAssertEqual(r.error, .missingContentLength)
    }

    func testDecodeRejectsOversizedContentLength() {
        // Content-Length parses fine and fits in Int, but exceeds the
        // configured max body length.
        let decoder = MonaLSPFrameDecoder(maxBodyLength: 10)
        let stream = Data("Content-Length: 100\r\n\r\n".utf8)
        let r = decoder.feed(stream)
        XCTAssertEqual(r.frames, [])
        XCTAssertEqual(r.error, .oversizedBody(actual: 100, max: 10))
    }

    // MARK: - Decode: terminality after error

    func testDecodeIsTerminalAfterError() {
        let decoder = MonaLSPFrameDecoder()
        let stream = Data("Content-Length: abc\r\n\r\n".utf8)
        _ = decoder.feed(stream)
        // After a terminal error, further feeds produce no frames and no new
        // error (the decoder is inert).
        let r = decoder.feed(framed(Data("ok".utf8)))
        XCTAssertEqual(r.frames, [])
        XCTAssertNil(r.error)  // already terminal; no second error reported
    }

    func testDecodeReturnsFramesDecodedBeforeErrorInSameChunk() {
        // A single chunk carrying a valid frame followed by a frame whose
        // Content-Length is malformed: the first frame must still be returned
        // alongside the terminal error.
        let decoder = MonaLSPFrameDecoder()
        let p1 = Data("{\"id\":1}".utf8)
        let chunk = framed(p1) + Data("Content-Length: nope\r\n\r\n".utf8)
        let r = decoder.feed(chunk)
        XCTAssertEqual(r.frames, [p1])
        XCTAssertEqual(r.error, .malformedLength)
    }

    // MARK: - Decode: default max body length is a sane, large value

    func testDecodeDefaultMaxBodyLengthIsPositiveAndLarge() {
        // The default must permit ordinary LSP messages (tens of MB). We only
        // assert it is a positive constant greater than 1 MiB so the test is
        // not coupled to an exact magic number.
        XCTAssertGreaterThan(MonaLSPFrameDecoder.defaultMaxBodyLength, 1024 * 1024)
    }

    // MARK: - Round-trip: encode -> decode

    func testEncodeThenDecodeRoundTripsPayloads() {
        let encoder = MonaLSPFrameEncoder()
        let payloads: [Data] = [
            Data(),
            Data("{}".utf8),
            Data("{\"x\":1}".utf8),
            Data("héllo→世界🌱".utf8),
            Data(repeating: 0x41, count: 4096),
        ]
        for payload in payloads {
            let decoder = MonaLSPFrameDecoder()
            let r = decoder.feed(encoder.encode(payload))
            XCTAssertEqual(r.frames, [payload])
            XCTAssertNil(r.error)
        }
    }
}
