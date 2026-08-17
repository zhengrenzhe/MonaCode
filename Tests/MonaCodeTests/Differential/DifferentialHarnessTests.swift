// DifferentialHarnessTests.swift
//
// P00-T008 — Build the differential fixture and comparator harness.
//
// Verifies the native differential subject harness:
//   - The `MonaDifferentialModelProvider` protocol exists and defines the seam
//     through which the native (MonaCode) model is plugged into differential
//     testing against the M0 (npm monaco) and M1 (built comparator) oracles.
//   - The deterministic test provider returns deterministic outputs that are a
//     pure function of (input, environmentTrace).
//   - Raw UTF-16 inputs and outputs are persisted WITHOUT Unicode repair:
//     unpaired surrogates survive the round trip verbatim.
//   - The harness loads a fixture, runs the native subject, and produces output.
//   - Exact and native-adapted comparison domains are distinguished in every
//     fixture: a native output may match the native-adapted domain while
//     diverging from the exact domain.
//   - One identical injected environment trace is shared by all subjects.
//
// When `MONACODE_DIFFERENTIAL_RESULTS` is set in the environment, the harness
// additionally emits a results manifest (native raw UTF-16 outputs) for the
// Node.js runner (`Tools/Differential/runner.mjs`) to compare against the
// M0/M1 expected outputs. When unset, that emission test is skipped so
// `xcrun swift test --filter DifferentialHarnessTests` passes standalone.

import XCTest
import Foundation

final class DifferentialHarnessTests: XCTestCase {

    // MARK: - Protocol existence

    func testMonaDifferentialModelProviderProtocolExists() {
        // The protocol is the seam through which the native MonaCode model is
        // injected into differential testing. It takes a differential input
        // (raw UTF-16 + the shared environment trace) and returns a
        // differential output (raw UTF-16), persisted without Unicode repair.
        let provider: any MonaDifferentialModelProvider = DeterministicMonaDifferentialModelProvider()
        let input = MonaDifferentialInput(
            input: MonaDifferentialUTF16(units: [0x0048, 0x0069]),
            environmentTrace: .defaultTestTrace
        )
        let output = provider.run(input)
        XCTAssertFalse(output.output.units.isEmpty, "provider must produce output")
    }

    // MARK: - Deterministic output (pure function of input + trace)

    func testDeterministicProviderReturnsIdenticalOutputForIdenticalInputAndTrace() {
        let provider = DeterministicMonaDifferentialModelProvider()
        let input = MonaDifferentialInput(
            input: MonaDifferentialUTF16(units: [0x0061, 0x0062, 0x0063]),
            environmentTrace: .defaultTestTrace
        )
        let a = provider.run(input)
        let b = provider.run(input)
        XCTAssertEqual(a, b, "deterministic provider must be a pure function")
    }

    func testDeterministicProviderOutputDiffersWhenInputDiffers() {
        let provider = DeterministicMonaDifferentialModelProvider()
        let trace = MonaDifferentialEnvironmentTrace.defaultTestTrace
        let outA = provider.run(MonaDifferentialInput(
            input: MonaDifferentialUTF16(units: [0x0061]),
            environmentTrace: trace
        ))
        let outB = provider.run(MonaDifferentialInput(
            input: MonaDifferentialUTF16(units: [0x0062]),
            environmentTrace: trace
        ))
        XCTAssertNotEqual(outA, outB, "different inputs must yield different outputs")
    }

    // MARK: - Raw UTF-16 preservation without Unicode repair

    func testRawUTF16WithUnpairedSurrogateSurvivesWithoutUnicodeRepair() {
        // A lone high surrogate (0xD800) cannot round-trip through a Swift
        // `String` without being replaced by U+FFFD. The differential harness
        // persists raw UTF-16 code units directly, so the unpaired surrogate
        // must survive verbatim through the native subject.
        let provider = DeterministicMonaDifferentialModelProvider()
        let loneSurrogateInput = MonaDifferentialUTF16(units: [0xD800])
        let output = provider.run(MonaDifferentialInput(
            input: loneSurrogateInput,
            environmentTrace: .defaultTestTrace
        ))
        // The unpaired surrogate is preserved, NOT repaired to 0xFFFD.
        XCTAssertTrue(output.output.units.contains(0xD800), "unpaired surrogate must be preserved")
        XCTAssertFalse(output.output.units.contains(0xFFFD), "no Unicode repair to U+FFFD may occur")
    }

    func testRawUTF16WithSurrogatePairAndLoneLowSurrogatePreserved() {
        // A well-formed surrogate pair (U+10000 = D800 DC00) followed by a lone
        // low surrogate (0xDC00). The lone low surrogate must survive.
        let provider = DeterministicMonaDifferentialModelProvider()
        let units: [UInt16] = [0xD800, 0xDC00, 0xDC00]
        let output = provider.run(MonaDifferentialInput(
            input: MonaDifferentialUTF16(units: units),
            environmentTrace: .defaultTestTrace
        ))
        XCTAssertEqual(Array(output.output.units.prefix(3)), units, "raw code units preserved in order")
    }

    // MARK: - Harness: loads a fixture, runs the native subject, produces output

    func testHarnessLoadsFixtureAndRunsNativeSubject() {
        let fixture = MonaDifferentialFixture.builtInCases.first { $0.id == "echo-exact" }!
        let provider = DeterministicMonaDifferentialModelProvider()
        let output = provider.run(MonaDifferentialInput(
            input: fixture.input,
            environmentTrace: fixture.environmentTrace
        ))
        XCTAssertFalse(output.output.units.isEmpty, "harness must produce output for a loaded fixture")
        // The native subject echoes the input (identity contract for the
        // scaffold), so the output must contain the fixture's input code units.
        let inputUnits = fixture.input.units
        XCTAssertTrue(
            Array(output.output.units.prefix(inputUnits.count)) == inputUnits,
            "native output must reflect the fixture input under the echo contract"
        )
    }

    // MARK: - Exact vs native-adapted comparison domains

    func testComparisonDomainEnumDistinguishesExactAndNativeAdapted() {
        XCTAssertEqual(MonaDifferentialComparisonDomain.exact.rawValue, "exact")
        XCTAssertEqual(MonaDifferentialComparisonDomain.nativeAdapted.rawValue, "nativeAdapted")
        XCTAssertNotEqual(MonaDifferentialComparisonDomain.exact, .nativeAdapted)
    }

    func testComparatorReportsExactMatchWhenNativeEqualsExact() {
        // Fixture "echo-exact": exact == nativeAdapted == input. The native
        // echo matches BOTH domains.
        let fixture = MonaDifferentialFixture.builtInCases.first { $0.id == "echo-exact" }!
        let provider = DeterministicMonaDifferentialModelProvider()
        let native = provider.run(MonaDifferentialInput(
            input: fixture.input,
            environmentTrace: fixture.environmentTrace
        )).output
        let verdict = MonaDifferentialComparator.verdict(native: native, expected: fixture.expected)
        XCTAssertTrue(verdict.exactMatch, "native must match exact domain for echo-exact")
        XCTAssertTrue(verdict.nativeAdaptedMatch, "native must match nativeAdapted domain for echo-exact")
    }

    func testComparatorReportsNativeAdaptedOnlyWhenExactDiffers() {
        // Fixture "native-adapted-divergence": exact != nativeAdapted. The
        // native echo matches nativeAdapted (the native contract) but NOT
        // exact (the M0/M1 oracle). This is the core domain distinction.
        let fixture = MonaDifferentialFixture.builtInCases.first { $0.id == "native-adapted-divergence" }!
        XCTAssertNotEqual(fixture.expected.exact, fixture.expected.nativeAdapted,
                          "fixture must distinguish exact from nativeAdapted")
        let provider = DeterministicMonaDifferentialModelProvider()
        let native = provider.run(MonaDifferentialInput(
            input: fixture.input,
            environmentTrace: fixture.environmentTrace
        )).output
        let verdict = MonaDifferentialComparator.verdict(native: native, expected: fixture.expected)
        XCTAssertTrue(verdict.nativeAdaptedMatch, "native must match nativeAdapted domain")
        XCTAssertFalse(verdict.exactMatch, "native must NOT match exact domain (documented divergence)")
    }

    func testComparatorReportsMismatchWhenNativeMatchesNeitherDomain() {
        // A native output that matches neither domain is a failure under both.
        let expected = MonaDifferentialExpected(
            exact: MonaDifferentialUTF16(units: [0x0041]),
            nativeAdapted: MonaDifferentialUTF16(units: [0x0042])
        )
        let native = MonaDifferentialUTF16(units: [0x0043])
        let verdict = MonaDifferentialComparator.verdict(native: native, expected: expected)
        XCTAssertFalse(verdict.exactMatch)
        XCTAssertFalse(verdict.nativeAdaptedMatch)
    }

    // MARK: - One identical injected environment trace shared by all subjects

    func testEnvironmentTraceCarriesAllInjectedDomains() {
        // The single shared trace must carry every injected domain established
        // in P00-T005/T006/T007: wall ms, high-resolution ms, random doubles,
        // crypto bytes, runtime locale fields, and the UI message profile.
        let trace = MonaDifferentialEnvironmentTrace.defaultTestTrace
        // Wall and high-resolution are separate, non-substitutable domains.
        let _: Double = trace.wallMilliseconds
        let _: Double = trace.highResolutionMilliseconds
        XCTAssertFalse(trace.randomDoubles.isEmpty, "trace must carry the shared random sequence")
        XCTAssertFalse(trace.cryptoBytes.isEmpty, "trace must carry the shared crypto bytes")
        XCTAssertFalse(trace.localeIdentifier.isEmpty)
        XCTAssertFalse(trace.numberingSystem.isEmpty)
        XCTAssertFalse(trace.timeZoneIdentifier.isEmpty)
        XCTAssertFalse(trace.profileIdentifier.isEmpty)
        // Wall != high-resolution in the injected trace (separate domains).
        XCTAssertNotEqual(trace.wallMilliseconds, trace.highResolutionMilliseconds)
    }

    func testTwoFixturesShareOneIdenticalEnvironmentTrace() {
        // M0, M1, and native run with ONE identical injected environment trace.
        // The built-in cases share the same trace.
        let traces = Set(MonaDifferentialFixture.builtInCases.map { $0.environmentTrace })
        XCTAssertEqual(traces.count, 1, "all built-in fixtures must share one identical environment trace")
    }

    // MARK: - Fixture Codable round-trip (raw UTF-16 preserved across encoding)

    func testFixtureCodableRoundTripsPreservingRawUTF16() throws {
        let fixture = MonaDifferentialFixture.builtInCases.first { $0.id == "surrogate-preservation" }!
        let encoded = try JSONEncoder().encode(fixture)
        let decoded = try JSONDecoder().decode(MonaDifferentialFixture.self, from: encoded)
        XCTAssertEqual(decoded, fixture, "fixture must round-trip through JSON")
        // The unpaired surrogate survives the JSON round-trip as a raw code unit.
        XCTAssertTrue(decoded.input.units.contains(0xD800))
    }

    // MARK: - Runner integration: emit native results manifest on request

    func testHarnessEmitsNativeResultsManifestForRunnerWhenRequested() throws {
        guard let resultsPath = ProcessInfo.processInfo.environment["MONACODE_DIFFERENTIAL_RESULTS"] else {
            throw XCTSkip("MONACODE_DIFFERENTIAL_RESULTS not set; skipping runner-results emission")
        }
        let fixturesDir = ProcessInfo.processInfo.environment["MONACODE_DIFFERENTIAL_FIXTURES"]
        let fixtures: [MonaDifferentialFixture]
        if let dir = fixturesDir {
            fixtures = try MonaDifferentialFixture.load(fromDirectory: dir)
        } else {
            fixtures = MonaDifferentialFixture.builtInCases
        }
        XCTAssertFalse(fixtures.isEmpty, "must have at least one fixture to emit")

        let provider = DeterministicMonaDifferentialModelProvider()
        let entries = fixtures.map { fixture in
            MonaDifferentialResultEntry(
                id: fixture.id,
                output: provider.run(MonaDifferentialInput(
                    input: fixture.input,
                    environmentTrace: fixture.environmentTrace
                )).output
            )
        }
        let manifest = MonaDifferentialResultsManifest(results: entries)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: URL(fileURLWithPath: resultsPath))
        XCTAssertGreaterThan(entries.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultsPath))
    }
}
