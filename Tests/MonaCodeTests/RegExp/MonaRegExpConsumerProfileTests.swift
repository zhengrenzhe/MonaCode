// MonaRegExpConsumerProfileTests.swift
//
// P02-T006 — Close ten RegExp consumer profiles with pinned Test262 vectors.
//
// Verifies the ten RegExp consumer profiles held in
// `Sources/MonaCode/RegExp/MonaRegExpConsumerProfile.swift` and the pinned
// Test262 inclusion/exclusion manifest at
// `Tests/Fixtures/DifferentialFixtures/regexp/test262-manifest.json`:
//
//   - Exactly ten named consumer profiles exist (find, replace, word,
//     transform, filter, configuration, validation, tokenization, highlight,
//     navigation), each binding a frozen RegExp occurrence (pattern + flags)
//     to a consumer use case and to its bound Unicode profiles (from P02-T005).
//   - The pinned Test262 manifest runs: every inclusion case matches, every
//     exclusion case does not, and the T-1 / T / T+1 bounds are exercised.
//
// Test contract (P02-T006): 2 cases — ten bound profiles + Test262 manifest.
//
// MonaCode is a Foundation-only target; tests import XCTest + MonaCode.

import XCTest
import MonaCode

final class MonaRegExpConsumerProfileTests: XCTestCase {

    // MARK: - 1. Ten consumer profiles exist and are bound

    /// Exactly ten named consumer profiles are generated and exposed, each
    /// binding a frozen RegExp occurrence (non-empty pattern + flags), a
    /// consumer type drawn from the ten enumerated consumers, and at least one
    /// bound Unicode profile ID drawn from the six P02-T005 profiles.
    func testTenConsumerProfilesExistAndBound() throws {
        let profiles = MonaRegExpConsumerProfiles.allProfiles
        XCTAssertEqual(profiles.count, 10, "expected exactly ten consumer profiles")

        // Each profile ID is unique and non-empty.
        let ids = profiles.map { $0.profileID }
        XCTAssertEqual(Set(ids).count, 10, "the ten profile IDs must be unique")
        for p in profiles {
            XCTAssertFalse(p.profileID.isEmpty, "profileID must not be empty")
        }

        // The ten consumer types are individually addressable.
        let types = Set(profiles.map { $0.consumerType })
        XCTAssertEqual(types.count, 10, "the ten consumer types must be distinct")
        XCTAssertEqual(Set(MonaRegExpConsumerType.allCases).count, 10,
                       "MonaRegExpConsumerType must enumerate ten cases")
        let expectedTypes: Set<MonaRegExpConsumerType> = [
            .find, .replace, .word, .transform, .filter,
            .configuration, .validation, .tokenization, .highlight, .navigation,
        ]
        XCTAssertEqual(types, expectedTypes, "the ten named consumer types must be present")

        // Each profile binds a frozen RegExp occurrence: non-empty pattern and
        // well-formed flags that compile through the P02-T004 parser/compiler.
        let knownUnicodeProfileIDs: Set<String> = Set(
            MonaRegExpUnicodeTables.allProfiles.map { $0.profileID }
        )
        for p in profiles {
            XCTAssertFalse(p.pattern.isEmpty,
                           "\(p.profileID): pattern must not be empty")
            XCTAssertFalse(p.boundUnicodeProfileIDs.isEmpty,
                           "\(p.profileID): must bind at least one Unicode profile")
            for id in p.boundUnicodeProfileIDs {
                XCTAssertTrue(knownUnicodeProfileIDs.contains(id),
                              "\(p.profileID): bound Unicode profile \(id) is not one of the six P02-T005 profiles")
            }
            // The frozen occurrence compiles.
            let program = try p.compile()
            XCTAssertEqual(program.flags, try MonaRegExpFlags.parse(p.flags),
                           "\(p.profileID): program flags must match the profile's flag string")
        }

        // Each profile is individually addressable by its dedicated accessor.
        for p in profiles {
            let resolved = MonaRegExpConsumerProfiles.profile(id: p.profileID)
            XCTAssertEqual(resolved, p,
                           "profile(id:) must resolve \(p.profileID)")
        }
    }

    // MARK: - 2. Pinned Test262 manifest runs (inclusion + exclusion + bounds)

    /// The pinned Test262 manifest runs: every inclusion case matches, every
    /// exclusion case does not match, each case is bound to one of the ten
    /// profiles, and the T-1 / T / T+1 bounds are all exercised.
    func testTest262ManifestInclusionExclusionAndBounds() throws {
        let manifestURL = Self.manifestURL()
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)

        XCTAssertEqual(manifest.manifestVersion, "1.0",
                       "manifest version must be 1.0")
        XCTAssertEqual(manifest.source, "Test262-pinned",
                       "manifest source must be Test262-pinned")

        // The manifest declares all ten profile IDs.
        let declaredIDs = Set(manifest.profileIDs)
        let knownIDs = Set(MonaRegExpConsumerProfiles.allProfiles.map { $0.profileID })
        XCTAssertEqual(declaredIDs, knownIDs,
                       "manifest must declare exactly the ten profile IDs")

        // The manifest exercises both inclusion and exclusion, and all three
        // bounds (T-1, T, T+1).
        let expectations = Set(manifest.cases.map { $0.expectMatch })
        XCTAssertTrue(expectations.contains(true), "manifest must include inclusion cases")
        XCTAssertTrue(expectations.contains(false), "manifest must include exclusion cases")

        let bounds = Set(manifest.cases.map { $0.bound })
        let expectedBounds: Set<String> = ["T-1", "T", "T+1"]
        XCTAssertEqual(bounds, expectedBounds,
                       "manifest must exercise the T-1, T, and T+1 bounds")

        // Every case is bound to a real profile and the case's frozen
        // occurrence matches the profile's occurrence (binding integrity).
        let profileByID = Dictionary(
            MonaRegExpConsumerProfiles.allProfiles.map { ($0.profileID, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        XCTAssertGreaterThan(manifest.cases.count, 0, "manifest must be non-empty")

        for c in manifest.cases {
            guard let profile = profileByID[c.profileID] else {
                XCTFail("case \(c.id): profileID \(c.profileID) is not one of the ten profiles")
                continue
            }
            XCTAssertEqual(c.pattern, profile.pattern,
                           "case \(c.id): pattern must match the bound profile's pattern")
            XCTAssertEqual(c.flags, profile.flags,
                           "case \(c.id): flags must match the bound profile's flags")

            // Run the frozen occurrence over the case input and check the
            // expectation.
            let program = try monaRegExpCompile(c.pattern, flags: c.flags)
            let executor = MonaRegExpExecutor(program: program)
            let input = Array(c.input.utf16)
            let r = try executor.exec(input, at: 0)
            if c.expectMatch {
                XCTAssertNotNil(r.match,
                    "case \(c.id) (\(c.bound)): expected match for /\(c.pattern)/\(c.flags) against \(c.input.debugDescription)")
            } else {
                XCTAssertNil(r.match,
                    "case \(c.id) (\(c.bound)): expected no match for /\(c.pattern)/\(c.flags) against \(c.input.debugDescription)")
            }
        }
    }

    // MARK: - Helpers

    /// Resolves the pinned Test262 manifest URL by walking up from the test
    /// source file's location to the repo root (the directory containing
    /// `Package.swift`), then joining the manifest's relative path. This is
    /// independent of the `#file` form (absolute, relative, or basename) and
    /// of the process working directory.
    private static func manifestURL() -> URL {
        let fm = FileManager.default
        var dir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        for _ in 0..<12 {
            if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir.appendingPathComponent(
                    "Tests/Fixtures/DifferentialFixtures/regexp/test262-manifest.json"
                )
            }
            dir = dir.deletingLastPathComponent()
        }
        // Fallback: assume the process working directory is the repo root.
        return URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent(
                "Tests/Fixtures/DifferentialFixtures/regexp/test262-manifest.json"
            )
    }
}

// MARK: - Manifest Codable model

private struct Manifest: Decodable {
    let manifestVersion: String
    let source: String
    let profileIDs: [String]
    let cases: [Case]
}

private struct Case: Decodable {
    let id: String
    let profileID: String
    let pattern: String
    let flags: String
    let input: String
    let expectMatch: Bool
    let bound: String
}
