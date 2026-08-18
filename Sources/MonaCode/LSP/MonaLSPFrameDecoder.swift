// MonaLSPFrameDecoder.swift
//
// P06-T002 — Implement streaming LSP frame decoding and encoding.
//
// `MonaLSPFrameDecoder` is the LSP frame codec's decode half. It sits above
// the transport-neutral byte channel (`MonaMessageTransport` from P06-T001)
// and below the JSON-RPC layer (T003). Its sole job is Content-Length header
// framing: feed it arbitrary byte chunks, it decodes complete LSP message
// frames (header `Content-Length: N\r\n\r\n` + exactly N body bytes) and
// returns the body bytes of each fully decoded frame.
//
// This is the Swift counterpart of the framing reader that sits beneath
// Monaco's JSON-RPC message reader (monaco-editor 0.56.0, vendored from
// vscode's `vs/base/common/bufferStream` / `vs/workbench/api/node/...`
// JSON-RPC reader). The framing format is the Language Server Protocol
// base protocol framing (RFC-like, header-delimited):
//
//     <header-part> \r\n\r\n <body-bytes>
//
// where the header part is one or more `Name: Value\r\n` lines and the body is
// exactly `Content-Length` bytes. The only header the codec requires is
// `Content-Length`; other headers are ignored (lenient, matching vscode).
//
// Streaming decode (frozen by P06-T002):
//
//   - The decoder accepts byte chunks in ANY fragmentation pattern. It buffers
//     partial headers until the `\r\n\r\n` terminator arrives, parses
//     `Content-Length`, then buffers the body until exactly N bytes arrive.
//     A chunk may contain: a partial header, a partial body, multiple
//     complete frames, or the tail of one frame plus the head of the next.
//   - Exact Content-Length validation: the body is EXACTLY N bytes. Trailing
//     bytes after N belong to the next frame's header — they never bleed into
//     the current body.
//   - Typed terminal errors: duplicate / malformed / negative / overflowed /
//     missing / oversized Content-Length each produce a distinct
//     `MonaLSPFrameCodecError` case. An error is terminal — after one fires,
//     the decoder is inert (further `feed` calls return no frames and no new
//     error).
//
// `MonaLSPFrameDecoder` is a `final class` (reference type): it holds mutable
// streaming state (a byte buffer and a decode state machine) that is shared
// across `feed` calls, mirroring the reference-typed stateful Core conventions
// (`MonaMessageTransportImpl`, `MonaEmitter`). An `NSLock` guards the mutable
// state so a decoder wired to a transport's event stream is reentrancy-safe,
// matching the transport's own locking discipline.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A typed terminal error produced by the LSP frame codec (`MonaLSPFrameDecoder`
/// decode path). Each case corresponds to a distinct Content-Length
/// validation failure. All cases are terminal: after one fires, the decoder
/// is inert.
public enum MonaLSPFrameCodecError: Error, Equatable {

    /// Two `Content-Length` headers appeared in one frame's header section.
    case duplicateContentLength

    /// The `Content-Length` value was not a non-negative integer (e.g.
    /// `abc`, `12x`, `0x10`, empty).
    case malformedLength

    /// The `Content-Length` value began with `-` and the remainder was all
    /// ASCII digits (e.g. `-5`).
    case negativeLength

    /// The `Content-Length` value was all ASCII digits but did not fit in
    /// `Int` (the integer type's representable range was exceeded).
    case overflowedLength

    /// The header section terminated (`\r\n\r\n`) without any
    /// `Content-Length` header.
    case missingContentLength

    /// The `Content-Length` value parsed to a valid `Int` but exceeded the
    /// decoder's configured maximum body length. `actual` is the declared
    /// length; `max` is the configured ceiling.
    case oversizedBody(actual: Int, max: Int)
}

/// The result of feeding one byte chunk to a `MonaLSPFrameDecoder`.
///
/// `frames` holds zero or more fully decoded frame bodies (raw JSON bytes) in
/// arrival order. `error` is `nil` while decoding is healthy; when non-`nil`
/// it is a terminal error and the decoder is now inert (further `feed` calls
/// return an empty result with no new error).
public struct MonaLSPFrameDecodeResult: Equatable {

    /// Fully decoded frame bodies (raw JSON bytes), in arrival order. May be
    /// non-empty even when `error` is non-`nil` — frames decoded earlier in
    /// the same chunk, before the terminal error was hit, are still returned.
    public let frames: [Data]

    /// A terminal decode error, if one was hit while feeding these bytes.
    /// `nil` means decoding is still healthy.
    public let error: MonaLSPFrameCodecError?

    /// Creates a decode result.
    public init(frames: [Data] = [], error: MonaLSPFrameCodecError? = nil) {
        self.frames = frames
        self.error = error
    }
}

/// A streaming LSP frame decoder — Content-Length header framing over the
/// byte channel.
///
/// Create with `init(maxBodyLength:)`, then call `feed(_:)` with arbitrary byte
/// chunks. The decoder buffers partial headers/bodies across calls and returns
/// each fully decoded frame body. See the file header for the full streaming
/// decode contract.
public final class MonaLSPFrameDecoder {

    /// The default maximum body length: 100 MiB. Generous enough for any real
    /// LSP message (semantic-token full deltas, document symbols, …) while
    /// bounding pathological inputs. Override via `init(maxBodyLength:)`.
    public static let defaultMaxBodyLength: Int = 100 * 1024 * 1024

    /// The maximum permitted `Content-Length` value. A declared body length
    /// exceeding this fires `.oversizedBody(actual:max:)`.
    public let maxBodyLength: Int

    private let _lock = NSLock()
    /// Accumulated, unprocessed bytes awaiting either the header terminator or
    /// the remaining body bytes.
    private var _buffer = Data()
    /// The current decode phase.
    private var _state: State = .readingHeaders
    /// `true` once a terminal error has fired — the decoder is then inert.
    private var _terminal = false

    /// Creates a new streaming LSP frame decoder.
    ///
    /// - Parameter maxBodyLength: The maximum permitted `Content-Length`. A
    ///   declared body length exceeding this fires `.oversizedBody`. Defaults
    ///   to `defaultMaxBodyLength` (100 MiB).
    public init(maxBodyLength: Int = MonaLSPFrameDecoder.defaultMaxBodyLength) {
        self.maxBodyLength = maxBodyLength
    }

    /// Feeds `bytes` into the streaming decoder and returns any fully decoded
    /// frame bodies, plus a terminal error if one was hit.
    ///
    /// The decoder accepts bytes in any fragmentation pattern — partial
    /// headers, partial bodies, multiple frames, or a frame tail plus the next
    /// frame's head — and buffers across calls until each frame is complete.
    /// After a terminal `error` has been returned, the decoder is inert:
    /// further `feed` calls return an empty result with no new error.
    @discardableResult
    public func feed(_ bytes: Data) -> MonaLSPFrameDecodeResult {
        var frames: [Data] = []
        var terminalError: MonaLSPFrameCodecError? = nil

        _lock.lock()
        if _terminal {
            _lock.unlock()
            return MonaLSPFrameDecodeResult()
        }
        _buffer.append(bytes)

        loop: while true {
            switch _state {
            case .readingHeaders:
                guard let sep = _buffer.firstRange(
                    of: Self.headerTerminator
                ) else {
                    // Header terminator not yet arrived — wait for more bytes.
                    break loop
                }
                // Extract the header section (before the terminator) and
                // drop the terminator, leaving the body / next frame in the
                // buffer. `subdata(in:)` returns a fresh 0-based `Data`, so
                // the buffer stays 0-based across iterations regardless of
                // how `Data` re-indexes after slicing (unlike `removeFirst`,
                // which advances `startIndex` and would make `firstRange`'s
                // absolute indices unsafe to pass back as a count).
                let headerBytes = _buffer.subdata(in: 0..<sep.lowerBound)
                _buffer = _buffer.subdata(in: sep.upperBound..<_buffer.count)
                // Parse the header section into a Content-Length (or a typed
                // terminal error).
                switch Self.parseContentLength(headerBytes) {
                case let .success(length):
                    if length > maxBodyLength {
                        _terminal = true
                        _state = .terminal
                        terminalError = .oversizedBody(
                            actual: length, max: maxBodyLength
                        )
                        break loop
                    }
                    _state = .readingBody(remaining: length)
                case let .failure(err):
                    _terminal = true
                    _state = .terminal
                    terminalError = err
                    break loop
                }

            case .readingBody(let remaining):
                if _buffer.count >= remaining {
                    // Body complete — extract exactly `remaining` bytes and
                    // leave any trailing bytes (the next frame's start) in
                    // the buffer. `subdata` keeps the buffer 0-based.
                    let body = _buffer.subdata(in: 0..<remaining)
                    _buffer = _buffer.subdata(in: remaining..<_buffer.count)
                    frames.append(body)
                    _state = .readingHeaders
                    // Loop: the leftover may hold another complete frame, or
                    // the start of the next header.
                    continue
                } else {
                    // Body not yet complete — wait for more bytes.
                    break loop
                }

            case .terminal:
                // Defensive: `_terminal` is checked at entry; this branch is
                // unreachable in normal flow.
                break loop
            }
        }
        _lock.unlock()

        return MonaLSPFrameDecodeResult(frames: frames, error: terminalError)
    }

    // MARK: - Private

    /// The decode phase.
    private enum State {
        /// Accumulating header bytes until the `\r\n\r\n` terminator arrives.
        case readingHeaders
        /// Header parsed; accumulating exactly `remaining` body bytes.
        case readingBody(remaining: Int)
        /// A terminal error fired — the decoder is inert.
        case terminal
    }

    /// The four-byte header terminator: `\r\n\r\n`.
    private static let headerTerminator = Data([0x0D, 0x0A, 0x0D, 0x0A])

    /// Parses a header section (the bytes before `\r\n\r\n`) and extracts the
    /// `Content-Length`, or returns a typed terminal error.
    ///
    /// Header lines are `Name: Value\r\n` pairs; the terminator's leading
    /// `\r\n` belongs to the terminator (not the header section), so the header
    /// section never ends with a trailing `\r\n`. Lines are split on `\r\n`.
    /// Only `Content-Length` (case-insensitive) is required; other headers are
    /// ignored. A second `Content-Length` is `.duplicateContentLength`.
    private static func parseContentLength(
        _ headerBytes: Data
    ) -> Result<Int, MonaLSPFrameCodecError> {
        // Headers are ASCII by the base-protocol spec. Decode losslessly so
        // the parser never traps on odd bytes; non-ASCII bytes in a
        // Content-Length value fail the ASCII-digit check below and surface as
        // `.malformedLength`.
        let headerString = String(decoding: headerBytes, as: UTF8.self)
        // An empty header section means no Content-Length was supplied.
        if headerString.isEmpty {
            return .failure(.missingContentLength)
        }
        let lines = headerString.components(separatedBy: "\r\n")
        var contentLength: Int? = nil
        var contentLengthSeen = false
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else {
                // A header line without a colon. Lenient: ignore lines that
                // are not Content-Length (and any stray non-header noise).
                // A bare "Content-Length" with no colon is treated as a
                // missing-value header, not a duplicate.
                continue
            }
            let name = line[..<colon]
                .trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
            guard name.lowercased() == "content-length" else {
                continue  // ignore non-Content-Length headers (lenient)
            }
            if contentLengthSeen {
                return .failure(.duplicateContentLength)
            }
            contentLengthSeen = true
            switch Self.parseLengthValue(value) {
            case let .success(n):
                contentLength = n
            case let .failure(err):
                return .failure(err)
            }
        }
        guard let length = contentLength else {
            return .failure(.missingContentLength)
        }
        return .success(length)
    }

    /// Parses a `Content-Length` value string into an `Int`, distinguishing
    /// malformed, negative, and overflowed values.
    ///
    ///   - Empty or non-digit (with no leading `-`)  → `.malformedLength`
    ///   - Leading `-` followed by ASCII digits       → `.negativeLength`
    ///   - Leading `-` followed by non-digits         → `.malformedLength`
    ///   - All ASCII digits but overflows `Int`       → `.overflowedLength`
    private static func parseLengthValue(
        _ raw: String
    ) -> Result<Int, MonaLSPFrameCodecError> {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return .failure(.malformedLength)
        }
        if trimmed.hasPrefix("-") {
            let rest = trimmed.dropFirst()
            if !rest.isEmpty && rest.allSatisfy(Self.isASCIIDigit) {
                return .failure(.negativeLength)
            }
            return .failure(.malformedLength)
        }
        guard trimmed.allSatisfy(Self.isASCIIDigit) else {
            return .failure(.malformedLength)
        }
        guard let n = Int(trimmed) else {
            return .failure(.overflowedLength)
        }
        return .success(n)
    }

    /// `true` iff `c` is an ASCII digit (`0`–`9`).
    private static func isASCIIDigit(_ c: Character) -> Bool {
        guard let v = c.asciiValue else { return false }
        return v >= 0x30 && v <= 0x39
    }
}
