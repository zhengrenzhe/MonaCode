// MonaTextCodec.swift
//
// P02-T008 — Implement finite ECMAScript intrinsics, codecs, and String SHA-1.
//
// UTF-8 encoding and decoding over raw `[UInt16]` code units.
//
// X1-R `encodingAndHashing.modelBoundary`: "The text model, positions,
// selections and public text events remain raw UTF-16. Encoding replacement
// occurs only at the exact compatibility utilities listed below and never
// mutates model truth."
//
// Encoding: UTF-16 code units → UTF-8 bytes. A valid surrogate pair encodes
// to the 4-byte UTF-8 sequence of the corresponding supplementary code point.
// A lone surrogate (high without a following low, or low without a preceding
// high) is replaced by U+FFFD (EF BF BD), matching the TextEncoder behavior
// of the retained SHA-1 stream (X1-R `activeSha1`).
//
// Decoding: UTF-8 bytes → UTF-16 code units. Malformed sequences (truncated
// continuations, overlong encodings, out-of-range code points, and code points
// above U+10FFFF) are each replaced by U+FFFD — graceful, never a crash. A
// supplementary code point decodes to its surrogate pair in UTF-16.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// UTF-8 encoding and decoding over raw `[UInt16]` code units.
///
/// A stateless namespace (caseless enum). Encoding converts lone surrogates to
/// U+FFFD; decoding replaces malformed sequences with U+FFFD.
public enum MonaTextCodec {

    // MARK: - Encoding (UTF-16 → UTF-8)

    /// Encodes `units` (UTF-16 code units) to UTF-8 bytes.
    ///
    /// A valid surrogate pair (high in `[D800..DBFF]` followed by low in
    /// `[DC00..DFFF]`) encodes to the 4-byte UTF-8 sequence of the
    /// supplementary code point. A lone surrogate is replaced by U+FFFD
    /// (`EF BF BD`). The BOM (U+FEFF) is encoded verbatim — it is not stripped
    /// by the encoder.
    public static func encodeUTF8(_ units: [UInt16]) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(units.count)
        var i = 0
        while i < units.count {
            let unit = UInt32(units[i])
            if unit >= 0xD800 && unit <= 0xDBFF {
                // High surrogate.
                if i + 1 < units.count {
                    let next = UInt32(units[i + 1])
                    if next >= 0xDC00 && next <= 0xDFFF {
                        // Valid surrogate pair → supplementary code point.
                        let cp = 0x10000 + ((unit - 0xD800) << 10) + (next - 0xDC00)
                        appendUTF8(cp, into: &bytes)
                        i += 2
                        continue
                    }
                }
                // Lone high surrogate → U+FFFD.
                appendUTF8(0xFFFD, into: &bytes)
                i += 1
            } else if unit >= 0xDC00 && unit <= 0xDFFF {
                // Lone low surrogate → U+FFFD.
                appendUTF8(0xFFFD, into: &bytes)
                i += 1
            } else {
                appendUTF8(unit, into: &bytes)
                i += 1
            }
        }
        return bytes
    }

    // MARK: - Decoding (UTF-8 → UTF-16)

    /// Decodes `bytes` (UTF-8) to UTF-16 code units.
    ///
    /// Malformed sequences are replaced by U+FFFD (`FFFD`): each ill-formed
    /// maximal subsequence contributes one replacement unit. A supplementary
    /// code point (4-byte sequence) decodes to its UTF-16 surrogate pair.
    public static func decodeUTF8(_ bytes: [UInt8]) -> [UInt16] {
        var units: [UInt16] = []
        units.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            let b0 = bytes[i]

            if b0 < 0x80 {
                // 1-byte sequence (ASCII).
                units.append(UInt16(b0))
                i += 1
                continue
            }

            if b0 < 0xC2 {
                // Continuation byte (0x80-0xBF) or overlong lead (0xC0, 0xC1):
                // malformed. Consume one byte → one U+FFFD.
                units.append(0xFFFD)
                i += 1
                continue
            }

            if b0 < 0xE0 {
                // 2-byte sequence: b0 in [0xC2, 0xDF], one continuation.
                guard i + 1 < bytes.count else {
                    // Truncated: consume the lead byte only.
                    units.append(0xFFFD)
                    i += 1
                    continue
                }
                let b1 = bytes[i + 1]
                if isContinuation(b1) {
                    let cp = (UInt32(b0 & 0x1F) << 6) | UInt32(b1 & 0x3F)
                    appendCodePoint(cp, into: &units)
                    i += 2
                } else {
                    // Invalid continuation: consume only the lead byte.
                    units.append(0xFFFD)
                    i += 1
                }
                continue
            }

            if b0 < 0xF0 {
                // 3-byte sequence: b0 in [0xE0, 0xEF].
                guard i + 2 < bytes.count else {
                    // Truncated: consume the lead and any valid continuation
                    // bytes that follow, emitting one U+FFFD.
                    var consumed = 1
                    while i + consumed < bytes.count && isContinuation(bytes[i + consumed]) {
                        consumed += 1
                    }
                    units.append(0xFFFD)
                    i += consumed
                    continue
                }
                let b1 = bytes[i + 1]
                let b2 = bytes[i + 2]
                // Reject overlong (E0 with continuation < A0) and surrogate
                // ranges (ED with continuation >= A0).
                if isContinuation(b1) && isContinuation(b2)
                    && !isOverlong3(b0, b1) && !isSurrogate3(b0, b1) {
                    let cp = (UInt32(b0 & 0x0F) << 12)
                           | (UInt32(b1 & 0x3F) << 6)
                           | UInt32(b2 & 0x3F)
                    appendCodePoint(cp, into: &units)
                    i += 3
                } else {
                    units.append(0xFFFD)
                    i += 1
                }
                continue
            }

            // 4-byte sequence: b0 in [0xF0, 0xF4].
            guard i + 3 < bytes.count else {
                // Truncated: consume the lead and any valid continuation bytes
                // that follow, emitting one U+FFFD.
                var consumed = 1
                while i + consumed < bytes.count && isContinuation(bytes[i + consumed]) {
                    consumed += 1
                }
                units.append(0xFFFD)
                i += consumed
                continue
            }
            let b1 = bytes[i + 1]
            let b2 = bytes[i + 2]
            let b3 = bytes[i + 3]
            if isContinuation(b1) && isContinuation(b2) && isContinuation(b3)
                && !isOverlong4(b0, b1) && !isOutOfRange4(b0, b1) {
                let cp = (UInt32(b0 & 0x07) << 18)
                       | (UInt32(b1 & 0x3F) << 12)
                       | (UInt32(b2 & 0x3F) << 6)
                       | UInt32(b3 & 0x3F)
                appendCodePoint(cp, into: &units)
                i += 4
            } else {
                units.append(0xFFFD)
                i += 1
            }
        }
        return units
    }

    // MARK: - Private helpers

    /// Appends the UTF-8 encoding of `codePoint` (a valid Unicode scalar,
    /// never a surrogate) to `bytes`.
    private static func appendUTF8(_ codePoint: UInt32, into bytes: inout [UInt8]) {
        if codePoint <= 0x7F {
            bytes.append(UInt8(codePoint))
        } else if codePoint <= 0x7FF {
            bytes.append(UInt8(0xC0 | (codePoint >> 6)))
            bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
        } else if codePoint <= 0xFFFF {
            bytes.append(UInt8(0xE0 | (codePoint >> 12)))
            bytes.append(UInt8(0x80 | ((codePoint >> 6) & 0x3F)))
            bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
        } else {
            bytes.append(UInt8(0xF0 | (codePoint >> 18)))
            bytes.append(UInt8(0x80 | ((codePoint >> 12) & 0x3F)))
            bytes.append(UInt8(0x80 | ((codePoint >> 6) & 0x3F)))
            bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
        }
    }

    /// Appends `codePoint` (a valid Unicode scalar ≤ U+10FFFF, never a
    /// surrogate) to `units` as UTF-16 code units.
    private static func appendCodePoint(_ codePoint: UInt32, into units: inout [UInt16]) {
        if codePoint <= 0xFFFF {
            units.append(UInt16(codePoint))
        } else {
            let adjusted = codePoint - 0x10000
            let high = 0xD800 + UInt16(adjusted >> 10)
            let low = 0xDC00 + UInt16(adjusted & 0x3FF)
            units.append(high)
            units.append(low)
        }
    }

    /// Returns `true` if `byte` is a UTF-8 continuation byte (10xxxxxx).
    private static func isContinuation(_ byte: UInt8) -> Bool {
        (byte & 0xC0) == 0x80
    }

    /// Returns `true` if a 3-byte sequence starting with `b0, b1` is overlong
    /// (i.e. encodes a code point ≤ U+07FF).
    private static func isOverlong3(_ b0: UInt8, _ b1: UInt8) -> Bool {
        b0 == 0xE0 && b1 < 0xA0
    }

    /// Returns `true` if a 3-byte sequence starting with `b0, b1` encodes a
    /// surrogate code point (U+D800..U+DFFF).
    private static func isSurrogate3(_ b0: UInt8, _ b1: UInt8) -> Bool {
        b0 == 0xED && b1 >= 0xA0
    }

    /// Returns `true` if a 4-byte sequence starting with `b0, b1` is overlong
    /// (i.e. encodes a code point ≤ U+FFFF).
    private static func isOverlong4(_ b0: UInt8, _ b1: UInt8) -> Bool {
        b0 == 0xF0 && b1 < 0x90
    }

    /// Returns `true` if a 4-byte sequence starting with `b0, b1` encodes a
    /// code point above U+10FFFF (only possible when `b0 == 0xF4` and
    /// `b1 >= 0x90`, or `b0 >= 0xF5`).
    private static func isOutOfRange4(_ b0: UInt8, _ b1: UInt8) -> Bool {
        b0 >= 0xF5 || (b0 == 0xF4 && b1 >= 0x90)
    }
}
