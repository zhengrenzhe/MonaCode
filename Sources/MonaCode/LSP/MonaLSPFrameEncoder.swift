// MonaLSPFrameEncoder.swift
//
// P06-T002 — Implement streaming LSP frame decoding and encoding.
//
// `MonaLSPFrameEncoder` is the LSP frame codec's encode half. It sits above
// the transport-neutral byte channel (`MonaMessageTransport` from P06-T001)
// and below the JSON-RPC layer (T003). Its sole job is Content-Length header
// framing: given a raw JSON payload (already-serialized bytes), it produces
// the canonical LSP base-protocol frame:
//
//     Content-Length: N\r\n\r\n<N raw payload bytes>
//
// where N is the payload's byte count. This is the Swift counterpart of the
// framing writer that sits above Monaco's JSON-RPC message writer
// (monaco-editor 0.56.0). See `MonaLSPFrameDecoder` for the decode half.
//
// Encode contract (frozen by P06-T002):
//
//   - Canonical ASCII headers: exactly `Content-Length: N\r\n\r\n` — a single
//     space after the colon, CRLF line terminators, the blank-line terminator,
//     and ASCII digits only.
//   - Raw payload passthrough: the payload bytes are appended verbatim. No
//     String conversion, no encoding normalization, no re-serialization. A
//     multibyte UTF-8 payload (or any non-UTF-8 byte sequence) passes through
//     byte-for-byte; the encoder measures `payload.count` and writes that
//     exact count and those exact bytes.
//
// `MonaLSPFrameEncoder` is a value type (a `struct`): it is a stateless,
// referentially-transparent transform — no mutable state, no identity, no
// disposal — matching Swift's convention that pure transforms are value types.
// (`MonaEmitterOptions` is the analogous Core precedent: a config/transform
// value type.) One `init()` and one method; instances are freely copyable.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A stateless LSP frame encoder — Content-Length header framing for raw
/// payload bytes.
///
/// Create with `init()`, then call `encode(_:)` with the already-serialized
/// payload bytes. The encoder produces `Content-Length: N\r\n\r\n` + the raw
/// payload bytes, with no text normalization. See the file header for the full
/// encode contract.
public struct MonaLSPFrameEncoder {

    /// Creates a new stateless frame encoder.
    public init() {}

    /// Encodes `payload` into a canonical LSP frame.
    ///
    /// Returns `Content-Length: N\r\n\r\n` + the raw payload bytes, where N is
    /// `payload.count`. The payload bytes pass through verbatim — no String
    /// conversion, no encoding normalization.
    ///
    /// - Parameter payload: The already-serialized payload bytes (raw JSON).
    /// - Returns: The framed message bytes.
    public func encode(_ payload: Data) -> Data {
        // Canonical ASCII header. `String` interpolation of an `Int` yields
        // ASCII digits only; `.utf8` is a strict ASCII superset and these are
        // all ASCII bytes. The two CRLFs are the terminator.
        let header = "Content-Length: \(payload.count)\r\n\r\n"
        return Data(header.utf8) + payload
    }
}
