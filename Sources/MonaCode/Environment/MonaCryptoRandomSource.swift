// MonaCryptoRandomSource.swift
//
// P00-T006 — Implement deterministic random, cryptographic random, and
// Number-to-string sources.
//
// This file defines the cryptographic random source protocol and its default
// implementation. The default implementation reads from `/dev/urandom`, which
// is the kernel's non-blocking CSPRNG on macOS and is accessible through
// Foundation's `FileHandle` — no `import Security` is needed.
//
// `import Security` would be rejected by the P00-T002 forbidden-core-imports
// gate, which enforces that `Foundation` is the only permitted import inside
// `Sources/MonaCode/**/*.swift`. `/dev/urandom` provides the same
// cryptographic quality as `SecRandomCopyBytes` on macOS without leaving the
// Foundation-only boundary.
//
// The source also produces canonical lowercase UUID version 4 values from
// injected bytes via `MonaCryptoRandomFormatter.uuidv4(from:)`.

import Foundation

/// Injectable cryptographic random source.
///
/// Produces cryptographically strong random bytes and canonical lowercase UUID
/// version 4 values. The protocol is non-mutating so it can be used through an
/// existential `any MonaCryptoRandomSource` with `let`.
public protocol MonaCryptoRandomSource {

    /// Returns `count` cryptographically random bytes.
    ///
    /// - Parameter count: The number of bytes to produce. Must be non-negative.
    /// - Returns: An array of `count` random bytes. Returns an empty array when
    ///   `count == 0`.
    func nextBytes(count: Int) -> [UInt8]

    /// Produces a canonical lowercase UUID version 4 string from 16 random
    /// bytes.
    ///
    /// The returned string has the form
    /// `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` where `y` is `8`, `9`, `a`, or
    /// `b`, matching RFC 4122.
    func makeUUIDv4() -> String
}

/// Stateless formatter for canonical lowercase UUID version 4 values.
///
/// Sets the version (4) and variant (RFC 4122) bits on the first 16 bytes of
/// the input and formats the result as a canonical lowercase UUID string. This
/// is a pure function over its input — it does not read randomness itself — so
/// tests can verify the formatting deterministically from fixed bytes.
public enum MonaCryptoRandomFormatter {

    /// Formats 16 bytes as a canonical lowercase UUID version 4 string.
    ///
    /// - Precondition: `bytes.count >= 16`. Only the first 16 bytes are used.
    public static func uuidv4(from bytes: [UInt8]) -> String {
        precondition(bytes.count >= 16, "UUID v4 requires at least 16 bytes")
        var b = bytes
        // Version field (bits 48-51 of the UUID) = 0100 (version 4).
        b[6] = (b[6] & 0x0F) | 0x40
        // Variant field (bits 64-65 of the UUID) = 10 (RFC 4122).
        b[8] = (b[8] & 0x3F) | 0x80
        // Canonical lowercase: 8-4-4-4-12 hex digits.
        let hexChars: [Character] = [
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
            "a", "b", "c", "d", "e", "f",
        ]
        var result: [Character] = []
        result.reserveCapacity(36)
        let groups = [4, 2, 2, 2, 6]  // byte counts per UUID group
        var offset = 0
        for (gi, groupBytes) in groups.enumerated() {
            if gi > 0 { result.append("-") }
            for _ in 0..<groupBytes {
                let byte = b[offset]
                result.append(hexChars[Int(byte >> 4) & 0xF])
                result.append(hexChars[Int(byte) & 0xF])
                offset += 1
            }
        }
        return String(result)
    }
}

/// Default extension providing `makeUUIDv4()` from `nextBytes(count: 16)`.
public extension MonaCryptoRandomSource {

    func makeUUIDv4() -> String {
        return MonaCryptoRandomFormatter.uuidv4(from: nextBytes(count: 16))
    }
}

/// Default implementation of `MonaCryptoRandomSource`.
///
/// Reads cryptographically strong random bytes from `/dev/urandom`, the kernel's
/// non-blocking CSPRNG on macOS. `/dev/urandom` is accessed through
/// Foundation's `FileHandle`, so no `import Security` is required and the
/// P00-T002 Foundation-only boundary is preserved.
public struct MonaSystemCryptoRandomSource: MonaCryptoRandomSource {

    /// Creates a cryptographic random source.
    public init() {}

    public func nextBytes(count: Int) -> [UInt8] {
        precondition(count >= 0, "byte count must be non-negative")
        guard count > 0 else { return [] }

        // /dev/urandom is the kernel CSPRNG; reads never block and always
        // return the requested number of bytes on macOS.
        let url = URL(fileURLWithPath: "/dev/urandom")
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            preconditionFailure("MonaCryptoRandomSource: failed to open /dev/urandom: \(error)")
        }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: count)
        precondition(
            data.count == count,
            "MonaCryptoRandomSource: /dev/urandom short read (got \(data.count) of \(count))"
        )
        return [UInt8](data)
    }
}
