// MonaStringSHA1.swift
//
// P02-T008 — Implement finite ECMAScript intrinsics, codecs, and String SHA-1.
//
// SHA-1 over the UTF-16 code units of a string.
//
// X1-R `encodingAndHashing.activeSha1`: "StringSHA1 is retained for
// ModelService and implements the source UTF-16-to-UTF-8 stream, including a
// high surrogate split across update calls. It emits lowercase 40-hex SHA-1
// and does not call WebCrypto."
//
// The hash converts the UTF-16 input units to a UTF-8 byte stream (the same
// encoding used by `MonaTextCodec.encodeUTF8`: lone surrogates become U+FFFD),
// then computes SHA-1 over that byte stream. A high surrogate at the end of
// one `update` call is buffered and rejoined with a low surrogate at the start
// of the next call — so `update([D83D])` followed by `update([DCA9])` hashes
// the same bytes as a one-shot `hash([D83D, DCA9])`.
//
// Pure Swift: no CryptoKit, no Foundation crypto. The SHA-1 core is a direct
// FIPS 180-4 implementation.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// SHA-1 over the UTF-16 code units of a string.
///
/// The one-shot `hash(_:)` computes the SHA-1 of a code-unit sequence. The
/// nested `Hasher` supports streaming `update` calls with surrogate-pair
/// rejoining across call boundaries. Output is lowercase 40-hex.
public enum MonaStringSHA1 {

    /// Computes the SHA-1 hash of `units` (UTF-16 code units).
    ///
    /// The units are converted to a UTF-8 byte stream (lone surrogates →
    /// U+FFFD) and hashed. Returns the lowercase 40-hex digest.
    public static func hash(_ units: [UInt16]) -> String {
        var state = MonaSHA1State()
        var pendingHigh: UInt16? = nil
        feed(units, into: &state, pendingHigh: &pendingHigh)
        if pendingHigh != nil {
            // A trailing lone high surrogate → U+FFFD (EF BF BD).
            state.update([0xEF, 0xBF, 0xBD])
        }
        return state.finalize()
    }

    /// A streaming SHA-1 hasher over UTF-16 code units.
    ///
    /// A high surrogate at the end of one `update` is held back and rejoined
    /// with a low surrogate at the start of the next `update`; the split
    /// therefore hashes identically to a single `hash` of the concatenated
    /// units.
    public struct Hasher {

        private var state = MonaSHA1State()
        private var pendingHigh: UInt16? = nil

        /// Creates an empty hasher.
        public init() {}

        /// Feeds `units` into the hash. A trailing high surrogate is buffered
        /// for the next call; an empty `units` leaves the buffer untouched.
        public mutating func update(_ units: [UInt16]) {
            MonaStringSHA1.feed(units, into: &state, pendingHigh: &pendingHigh)
        }

        /// Finalizes the hash, flushing any pending lone surrogate as U+FFFD,
        /// and returns the lowercase 40-hex digest.
        public mutating func finalize() -> String {
            if pendingHigh != nil {
                state.update([0xEF, 0xBF, 0xBD])
                pendingHigh = nil
            }
            return state.finalize()
        }
    }

    // MARK: - Internal: UTF-16 → UTF-8 feed with surrogate rejoin

    /// Feeds `units` into `state`, converting to UTF-8 bytes. A pending high
    /// surrogate from the previous call (in `pendingHigh`) is rejoined with a
    /// leading low surrogate, or emitted as U+FFFD if no low surrogate follows.
    /// A trailing high surrogate is stored back into `pendingHigh`.
    static func feed(
        _ units: [UInt16],
        into state: inout MonaSHA1State,
        pendingHigh: inout UInt16?
    ) {
        var i = 0

        // Rejoin a buffered high surrogate from the previous update.
        if let pending = pendingHigh {
            guard !units.isEmpty else { return } // keep pending
            let first = UInt32(units[0])
            if first >= 0xDC00 && first <= 0xDFFF {
                // Valid pair split across calls.
                let cp = 0x10000 + ((UInt32(pending) - 0xD800) << 10)
                       + (first - 0xDC00)
                state.update(utf8Bytes(of: cp))
                pendingHigh = nil
                i = 1
            } else {
                // Buffered high was lone → U+FFFD; process units[0] normally.
                state.update([0xEF, 0xBF, 0xBD])
                pendingHigh = nil
                i = 0
            }
        }

        while i < units.count {
            let unit = UInt32(units[i])
            if unit >= 0xD800 && unit <= 0xDBFF {
                // High surrogate.
                if i + 1 < units.count {
                    let next = UInt32(units[i + 1])
                    if next >= 0xDC00 && next <= 0xDFFF {
                        let cp = 0x10000 + ((unit - 0xD800) << 10) + (next - 0xDC00)
                        state.update(utf8Bytes(of: cp))
                        i += 2
                        continue
                    }
                    // Lone high (next is not a low surrogate) → U+FFFD.
                    state.update([0xEF, 0xBF, 0xBD])
                    i += 1
                } else {
                    // Trailing high surrogate — buffer for the next update.
                    pendingHigh = units[i]
                    i += 1
                }
            } else if unit >= 0xDC00 && unit <= 0xDFFF {
                // Lone low surrogate → U+FFFD.
                state.update([0xEF, 0xBF, 0xBD])
                i += 1
            } else {
                state.update(utf8Bytes(of: unit))
                i += 1
            }
        }
    }

    /// Returns the UTF-8 encoding of `codePoint` (a valid scalar, never a
    /// surrogate).
    private static func utf8Bytes(of codePoint: UInt32) -> [UInt8] {
        if codePoint <= 0x7F {
            return [UInt8(codePoint)]
        } else if codePoint <= 0x7FF {
            return [
                UInt8(0xC0 | (codePoint >> 6)),
                UInt8(0x80 | (codePoint & 0x3F)),
            ]
        } else if codePoint <= 0xFFFF {
            return [
                UInt8(0xE0 | (codePoint >> 12)),
                UInt8(0x80 | ((codePoint >> 6) & 0x3F)),
                UInt8(0x80 | (codePoint & 0x3F)),
            ]
        } else {
            return [
                UInt8(0xF0 | (codePoint >> 18)),
                UInt8(0x80 | ((codePoint >> 12) & 0x3F)),
                UInt8(0x80 | ((codePoint >> 6) & 0x3F)),
                UInt8(0x80 | (codePoint & 0x3F)),
            ]
        }
    }
}

/// A pure-Swift SHA-1 state (FIPS 180-4).
///
/// Incremental: call `update` with byte chunks, then `finalize` for the
/// lowercase 40-hex digest.
struct MonaSHA1State {

    private var h0: UInt32 = 0x67452301
    private var h1: UInt32 = 0xEFCDAB89
    private var h2: UInt32 = 0x98BADCFE
    private var h3: UInt32 = 0x10325476
    private var h4: UInt32 = 0xC3D2E1F0

    private var buffer: [UInt8] = []
    private var totalLength: UInt64 = 0

    mutating func update(_ data: [UInt8]) {
        buffer.append(contentsOf: data)
        totalLength &+= UInt64(data.count)
        processBuffer()
    }

    mutating func finalize() -> String {
        // Append the 0x80 padding byte.
        buffer.append(0x80)
        // Pad with zeros until 56 mod 64.
        while buffer.count % 64 != 56 {
            buffer.append(0x00)
        }
        // Append the 64-bit big-endian bit length.
        let bitLength = totalLength &* 8
        for shift in stride(from: 56, through: 0, by: -8) {
            buffer.append(UInt8((bitLength >> UInt64(shift)) & 0xFF))
        }
        // Process any remaining full blocks.
        processBuffer()

        return String(format: "%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4)
    }

    private mutating func processBuffer() {
        while buffer.count >= 64 {
            let block = Array(buffer.prefix(64))
            buffer.removeFirst(64)
            processBlock(block)
        }
    }

    private mutating func processBlock(_ block: [UInt8]) {
        var w = [UInt32](repeating: 0, count: 80)

        // First 16 words from the block (big-endian).
        for j in 0..<16 {
            let b0 = UInt32(block[j * 4])
            let b1 = UInt32(block[j * 4 + 1])
            let b2 = UInt32(block[j * 4 + 2])
            let b3 = UInt32(block[j * 4 + 3])
            w[j] = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
        }

        // Extend the schedule.
        for j in 16..<80 {
            let v = w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16]
            w[j] = (v << 1) | (v >> 31)
        }

        var a = h0
        var b = h1
        var c = h2
        var d = h3
        var e = h4

        for j in 0..<80 {
            var f: UInt32
            var k: UInt32

            if j < 20 {
                f = (b & c) | ((~b) & d)
                k = 0x5A827999
            } else if j < 40 {
                f = b ^ c ^ d
                k = 0x6ED9EBA1
            } else if j < 60 {
                f = (b & c) | (b & d) | (c & d)
                k = 0x8F1BBCDC
            } else {
                f = b ^ c ^ d
                k = 0xCA62C1D6
            }

            let temp = leftRotate(a, by: 5) &+ f &+ e &+ k &+ w[j]
            e = d
            d = c
            c = leftRotate(b, by: 30)
            b = a
            a = temp
        }

        h0 = h0 &+ a
        h1 = h1 &+ b
        h2 = h2 &+ c
        h3 = h3 &+ d
        h4 = h4 &+ e
    }

    private func leftRotate(_ value: UInt32, by bits: UInt32) -> UInt32 {
        (value << bits) | (value >> (32 - bits))
    }
}
