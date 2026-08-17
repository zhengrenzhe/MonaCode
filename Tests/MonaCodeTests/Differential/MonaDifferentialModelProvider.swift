// MonaDifferentialModelProvider.swift
//
// P00-T008 — Build the differential fixture and comparator harness.
//
// Defines the native differential subject contract used by the differential
// testing harness. The harness runs three subjects against ONE identical
// injected environment trace:
//   - M0 — the pinned npm `monaco-editor@0.56.0` (the reference oracle).
//   - M1 — the built comparator derived from the locked Monaco sources.
//   - native — MonaCode's own model, injected through
//     `MonaDifferentialModelProvider`.
//
// M0 and M1 are reference oracles whose expected outputs are baked into
// fixtures (`MonaDifferentialExpected`). The native subject is MonaCode's own
// model, plugged in through the `MonaDifferentialModelProvider` protocol. A
// deterministic test implementation (`DeterministicMonaDifferentialModelProvider`)
// stands in for the real model until later phases supply it.
//
// Raw UTF-16 inputs and outputs are persisted as arrays of 16-bit code units
// (0…65535) WITHOUT Unicode repair: unpaired surrogates are representable and
// survive the round trip verbatim, never substituted with U+FFFD. This matches
// the Monaco reference, which operates on UTF-16 code units and may emit
// unpaired surrogates that a Swift `String` would repair.
//
// Every fixture distinguishes two comparison domains:
//   - `exact`         — byte-for-byte equality with the M0/M1 oracle.
//   - `nativeAdapted` — the documented native divergence permitted for the
//                       MonaCode subject. A native output may match
//                       `nativeAdapted` while diverging from `exact`.

import Foundation

// MARK: - Raw UTF-16 (no Unicode repair)

/// Raw UTF-16 code units, persisted without Unicode repair.
///
/// Each element is a 16-bit code unit in `[0, 65535]`. Unpaired surrogates
/// (e.g. a lone `0xD800`) are representable and preserved verbatim — they are
/// NEVER substituted with `U+FFFD`. This is the differential harness's
/// canonical wire format for inputs and outputs, matching the Monaco
/// reference's UTF-16 code-unit semantics.
///
/// `Codable` encodes/decodes this type as a plain JSON array of integers, so a
/// lone surrogate serializes as `[55296]` and round-trips losslessly.
public struct MonaDifferentialUTF16: Equatable, Sendable {
    /// The raw UTF-16 code units, in order. Each unit is in `[0, 65535]`.
    public let units: [UInt16]

    /// Creates a raw UTF-16 value from a code-unit array.
    public init(units: [UInt16]) {
        self.units = units
    }
}

extension MonaDifferentialUTF16: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(units)
    }
}

extension MonaDifferentialUTF16: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.units = try container.decode([UInt16].self)
    }
}

// MARK: - The single identical injected environment trace

/// The single injected environment trace shared by M0, M1, and the native
/// subject for one differential case.
///
/// This carries every injected domain established in P00-T005/T006/T007:
///   - `wallMilliseconds`           — wall-clock domain (P00-T005).
///   - `highResolutionMilliseconds` — high-resolution domain (P00-T005).
///   - `randomDoubles`              — shared random sequence (P00-T006).
///   - `cryptoBytes`                — cryptographic random bytes (P00-T006).
///   - locale / calendar / numbering / time zone / profile — P00-T007.
///
/// Wall and high-resolution are separate, non-substitutable domains; the trace
/// never substitutes one for the other. The trace is identical across all
/// three subjects so that any output divergence is attributable to the subject
/// model, not to the environment.
public struct MonaDifferentialEnvironmentTrace: Equatable, Hashable, Sendable {
    /// Wall-clock milliseconds since 1970-01-01T00:00:00Z (P00-T005 wall domain).
    public let wallMilliseconds: Double
    /// Monotonic high-resolution milliseconds (P00-T005 high-resolution domain).
    public let highResolutionMilliseconds: Double
    /// The shared deterministic random sequence (P00-T006).
    public let randomDoubles: [Double]
    /// The shared cryptographic random bytes (P00-T006).
    public let cryptoBytes: [UInt8]
    /// Runtime locale identifier captured at startup (P00-T007).
    public let localeIdentifier: String
    /// Runtime calendar identifier captured at startup (P00-T007).
    public let calendarIdentifier: String
    /// Runtime numbering-system identifier captured at startup (P00-T007).
    public let numberingSystem: String
    /// Runtime time-zone identifier captured at startup (P00-T007).
    public let timeZoneIdentifier: String
    /// The explicit UI message-profile identifier (P00-T007). Selected only
    /// from the explicit environment option; never derived from the locale.
    public let profileIdentifier: String

    public init(
        wallMilliseconds: Double,
        highResolutionMilliseconds: Double,
        randomDoubles: [Double],
        cryptoBytes: [UInt8],
        localeIdentifier: String,
        calendarIdentifier: String,
        numberingSystem: String,
        timeZoneIdentifier: String,
        profileIdentifier: String
    ) {
        self.wallMilliseconds = wallMilliseconds
        self.highResolutionMilliseconds = highResolutionMilliseconds
        self.randomDoubles = randomDoubles
        self.cryptoBytes = cryptoBytes
        self.localeIdentifier = localeIdentifier
        self.calendarIdentifier = calendarIdentifier
        self.numberingSystem = numberingSystem
        self.timeZoneIdentifier = timeZoneIdentifier
        self.profileIdentifier = profileIdentifier
    }

    /// A fixed, deterministic trace used by the built-in fixtures and tests.
    /// Wall and high-resolution are distinct values (separate domains).
    public static let defaultTestTrace = MonaDifferentialEnvironmentTrace(
        wallMilliseconds: 1_700_000_000_000.0,
        highResolutionMilliseconds: 12_345.678,
        randomDoubles: [0.125, 0.25, 0.5, 0.75],
        cryptoBytes: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                      0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10],
        localeIdentifier: "en_US",
        calendarIdentifier: "gregorian",
        numberingSystem: "latn",
        timeZoneIdentifier: "America/Los_Angeles",
        profileIdentifier: "default"
    )
}

// MARK: - Differential input / output

/// A differential input: the raw UTF-16 input plus the shared environment trace.
public struct MonaDifferentialInput: Equatable, Sendable {
    public let input: MonaDifferentialUTF16
    public let environmentTrace: MonaDifferentialEnvironmentTrace

    public init(input: MonaDifferentialUTF16, environmentTrace: MonaDifferentialEnvironmentTrace) {
        self.input = input
        self.environmentTrace = environmentTrace
    }
}

/// A differential output: the native subject's raw UTF-16 output, preserved
/// without Unicode repair.
public struct MonaDifferentialOutput: Equatable, Sendable {
    public let output: MonaDifferentialUTF16

    public init(output: MonaDifferentialUTF16) {
        self.output = output
    }
}

// MARK: - Comparison domains

/// The comparison domain for a differential case.
public enum MonaDifferentialComparisonDomain: String, Sendable {
    /// Byte-for-byte equality with the M0/M1 oracle.
    case exact
    /// The documented native divergence permitted for the MonaCode subject.
    case nativeAdapted
}

/// The expected outputs for one differential case, one per comparison domain.
public struct MonaDifferentialExpected: Equatable, Sendable {
    public let exact: MonaDifferentialUTF16
    public let nativeAdapted: MonaDifferentialUTF16

    public init(exact: MonaDifferentialUTF16, nativeAdapted: MonaDifferentialUTF16) {
        self.exact = exact
        self.nativeAdapted = nativeAdapted
    }
}

// MARK: - Fixture

/// A differential fixture: an identifier, the raw UTF-16 input, the expected
/// outputs per domain, and the single shared environment trace.
public struct MonaDifferentialFixture: Equatable, Sendable {
    public let id: String
    public let input: MonaDifferentialUTF16
    public let expected: MonaDifferentialExpected
    public let environmentTrace: MonaDifferentialEnvironmentTrace

    public init(
        id: String,
        input: MonaDifferentialUTF16,
        expected: MonaDifferentialExpected,
        environmentTrace: MonaDifferentialEnvironmentTrace
    ) {
        self.id = id
        self.input = input
        self.expected = expected
        self.environmentTrace = environmentTrace
    }

    /// The built-in differential cases. All share ONE identical injected
    /// environment trace (`.defaultTestTrace`) so that output divergence is
    /// attributable to the subject model, not the environment.
    public static let builtInCases: [MonaDifferentialFixture] = {
        let trace = MonaDifferentialEnvironmentTrace.defaultTestTrace
        return [
            // Native echo matches BOTH domains (exact == nativeAdapted).
            MonaDifferentialFixture(
                id: "echo-exact",
                input: MonaDifferentialUTF16(units: [0x0048, 0x0069]),  // "Hi"
                expected: MonaDifferentialExpected(
                    exact: MonaDifferentialUTF16(units: [0x0048, 0x0069]),
                    nativeAdapted: MonaDifferentialUTF16(units: [0x0048, 0x0069])
                ),
                environmentTrace: trace
            ),
            // Raw UTF-16 preservation: a lone high surrogate (0xD800) must
            // survive without Unicode repair. Native echo matches both domains.
            MonaDifferentialFixture(
                id: "surrogate-preservation",
                input: MonaDifferentialUTF16(units: [0xD800]),  // unpaired surrogate
                expected: MonaDifferentialExpected(
                    exact: MonaDifferentialUTF16(units: [0xD800]),
                    nativeAdapted: MonaDifferentialUTF16(units: [0xD800])
                ),
                environmentTrace: trace
            ),
            // Domain distinction: the M0/M1 oracle appends 'c' (exact), but
            // the native subject echoes the input (nativeAdapted). Native
            // matches nativeAdapted and diverges from exact.
            MonaDifferentialFixture(
                id: "native-adapted-divergence",
                input: MonaDifferentialUTF16(units: [0x0061, 0x0062]),  // "ab"
                expected: MonaDifferentialExpected(
                    exact: MonaDifferentialUTF16(units: [0x0061, 0x0062, 0x0063]),
                    nativeAdapted: MonaDifferentialUTF16(units: [0x0061, 0x0062])
                ),
                environmentTrace: trace
            ),
        ]
    }()

    /// Loads every `*.json` fixture from a directory, sorted by file name.
    ///
    /// Used by the Node.js runner, which points the native subject at a
    /// fixtures directory via the `MONACODE_DIFFERENTIAL_FIXTURES` environment
    /// variable. Each file must decode as a `MonaDifferentialFixture`.
    public static func load(fromDirectory directoryPath: String) throws -> [MonaDifferentialFixture] {
        let url = URL(fileURLWithPath: directoryPath)
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )
        let jsonFiles = contents
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var fixtures: [MonaDifferentialFixture] = []
        for file in jsonFiles {
            let data = try Data(contentsOf: file)
            fixtures.append(try JSONDecoder().decode(MonaDifferentialFixture.self, from: data))
        }
        return fixtures
    }
}

// MARK: - Native subject model provider

/// Provides the native (MonaCode) subject's model for differential testing.
///
/// The harness calls `run(_:)` with a `MonaDifferentialInput` carrying the raw
/// UTF-16 input and the single shared environment trace, and receives a
/// `MonaDifferentialOutput` carrying the native raw UTF-16 output (preserved
/// without Unicode repair). M0 and M1 are reference oracles whose expected
/// outputs are baked into fixtures; only the native subject is injected here.
public protocol MonaDifferentialModelProvider {
    func run(_ input: MonaDifferentialInput) -> MonaDifferentialOutput
}

/// A deterministic test implementation of `MonaDifferentialModelProvider`.
///
/// Returns a deterministic output that is a pure function of
/// `(input, environmentTrace)`. The scaffold contract is an identity echo:
/// the native subject reproduces the input's raw UTF-16 code units verbatim,
/// without Unicode repair. The real MonaCode model (later phases) replaces this
/// implementation without touching the harness or the protocol.
public final class DeterministicMonaDifferentialModelProvider: MonaDifferentialModelProvider, @unchecked Sendable {

    public init() {}

    public func run(_ input: MonaDifferentialInput) -> MonaDifferentialOutput {
        // Identity echo: reproduce the input's raw UTF-16 code units verbatim.
        // Unpaired surrogates survive because we never route through a Swift
        // `String` (which would repair them to U+FFFD).
        return MonaDifferentialOutput(output: input.input)
    }
}

// MARK: - Comparator

/// The per-domain comparison verdict for one differential case.
public struct MonaDifferentialVerdict: Equatable, Sendable {
    /// `true` when the native output matches the `exact` domain (M0/M1 oracle).
    public let exactMatch: Bool
    /// `true` when the native output matches the `nativeAdapted` domain.
    public let nativeAdaptedMatch: Bool

    public init(exactMatch: Bool, nativeAdaptedMatch: Bool) {
        self.exactMatch = exactMatch
        self.nativeAdaptedMatch = nativeAdaptedMatch
    }
}

/// Pure comparison of a native output against the expected outputs per domain.
public enum MonaDifferentialComparator {

    /// Returns the per-domain match verdict for `native` against `expected`.
    public static func verdict(
        native: MonaDifferentialUTF16,
        expected: MonaDifferentialExpected
    ) -> MonaDifferentialVerdict {
        MonaDifferentialVerdict(
            exactMatch: native == expected.exact,
            nativeAdaptedMatch: native == expected.nativeAdapted
        )
    }
}

// MARK: - Results manifest (for the Node.js runner)

/// One entry in the native results manifest: the fixture id and the native
/// subject's raw UTF-16 output for that fixture.
public struct MonaDifferentialResultEntry: Codable, Equatable, Sendable {
    public let id: String
    public let output: MonaDifferentialUTF16

    public init(id: String, output: MonaDifferentialUTF16) {
        self.id = id
        self.output = output
    }
}

/// The manifest of native results emitted by the native subject for the Node.js
/// runner to compare against the M0/M1 expected outputs.
public struct MonaDifferentialResultsManifest: Codable, Equatable, Sendable {
    public let results: [MonaDifferentialResultEntry]

    public init(results: [MonaDifferentialResultEntry]) {
        self.results = results
    }
}

// MARK: - Codable (fixtures load from disk and round-trip)

extension MonaDifferentialEnvironmentTrace: Codable {}
extension MonaDifferentialInput: Codable {}
extension MonaDifferentialOutput: Codable {}
extension MonaDifferentialExpected: Codable {}
extension MonaDifferentialFixture: Codable {}
