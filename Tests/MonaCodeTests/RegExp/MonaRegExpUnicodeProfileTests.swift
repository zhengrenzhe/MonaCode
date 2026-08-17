// MonaRegExpUnicodeProfileTests.swift
//
// P02-T005 — Generate six non-mergeable RegExp Unicode profiles.
//
// Verifies the generated Unicode table profiles held in
// `Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift`:
//
//   - Exactly six profiles are generated.
//   - Each profile carries the six provenance fields: source version, input
//     hash, generator hash, output hash, property set, consumer set.
//   - Profiles are SEPARATELY IDENTIFIED: each has a unique profileID, and
//     merging is forbidden even when two profiles' range tables happen to
//     compare equal.
//
// Test contract (P02-T005): six profiles, six metadata fields each,
// non-mergeable identity.
//
// MonaCode is a Foundation-only target; tests import XCTest + MonaCode.

import XCTest
import MonaCode

final class MonaRegExpUnicodeProfileTests: XCTestCase {

    // MARK: - 1. Six profiles exist

    /// Exactly six Unicode table profiles are generated and exposed.
    func testSixProfilesExist() {
        let profiles = MonaRegExpUnicodeTables.allProfiles
        XCTAssertEqual(profiles.count, 6, "expected exactly six Unicode profiles")
    }

    /// Each profile is individually addressable by its dedicated accessor.
    func testProfilesExposedByDedicatedAccessors() {
        // The six accessors must each return a distinct, populated profile.
        let accessors: [MonaRegExpUnicodeProfile] = [
            MonaRegExpUnicodeTables.generalCategory,
            MonaRegExpUnicodeTables.script,
            MonaRegExpUnicodeTables.binaryProperties,
            MonaRegExpUnicodeTables.caseFolding,
            MonaRegExpUnicodeTables.whiteSpace,
            MonaRegExpUnicodeTables.identifierProfiles,
        ]
        XCTAssertEqual(Set(accessors.map { $0.profileID }).count, 6,
                       "the six dedicated accessors must return distinct profile IDs")
    }

    // MARK: - 2. Six metadata fields per profile

    /// Every profile carries all six provenance fields, populated and
    /// well-formed (hashes are 64-char lowercase hex SHA-256).
    func testEachProfileHasSixMetadataFields() {
        let hexPattern = #"^[0-9a-f]{64}$"#
        let regex = try! NSRegularExpression(pattern: hexPattern)
        for profile in MonaRegExpUnicodeTables.allProfiles {
            XCTAssertFalse(profile.profileID.isEmpty,
                           "\(profile.profileID): profileID must not be empty")
            XCTAssertFalse(profile.sourceVersion.isEmpty,
                           "\(profile.profileID): sourceVersion must not be empty")
            XCTAssertFalse(profile.inputHash.isEmpty,
                           "\(profile.profileID): inputHash must not be empty")
            XCTAssertFalse(profile.generatorHash.isEmpty,
                           "\(profile.profileID): generatorHash must not be empty")
            XCTAssertFalse(profile.outputHash.isEmpty,
                           "\(profile.profileID): outputHash must not be empty")
            XCTAssertFalse(profile.propertySet.isEmpty,
                           "\(profile.profileID): propertySet must not be empty")
            XCTAssertFalse(profile.consumerSet.isEmpty,
                           "\(profile.profileID): consumerSet must not be empty")

            // Hash provenance: input/generator/output are real SHA-256 digests.
            for (label, hash) in [
                ("inputHash", profile.inputHash),
                ("generatorHash", profile.generatorHash),
                ("outputHash", profile.outputHash),
            ] {
                let full = hash as NSString
                let range = NSRange(location: 0, length: full.length)
                XCTAssertEqual(regex.firstMatch(in: hash as String, range: range) != nil,
                               true,
                               "\(profile.profileID): \(label) must be 64-char lowercase hex")
            }
        }
    }

    /// Every profile carries at least one concrete range (non-empty tables).
    func testEachProfileHasRanges() {
        for profile in MonaRegExpUnicodeTables.allProfiles {
            XCTAssertFalse(profile.ranges.isEmpty,
                           "\(profile.profileID): ranges must not be empty")
            // Ranges are well-formed: start <= end, ascending, non-overlapping.
            for r in profile.ranges {
                XCTAssertLessThanOrEqual(r.start, r.end,
                    "\(profile.profileID): range start > end (\(r.start) > \(r.end))")
            }
            for i in 1..<profile.ranges.count {
                XCTAssertGreaterThan(profile.ranges[i].start, profile.ranges[i - 1].end,
                    "\(profile.profileID): ranges must be ascending and non-overlapping")
            }
        }
    }

    // MARK: - 3. Provenance invariants

    /// All six profileIDs are unique.
    func testProfileIDsAreUnique() {
        let ids = MonaRegExpUnicodeTables.allProfiles.map { $0.profileID }
        XCTAssertEqual(Set(ids).count, ids.count, "profile IDs must be unique")
    }

    /// The six expected profile IDs are present.
    func testExpectedProfileIDs() {
        let ids = Set(MonaRegExpUnicodeTables.allProfiles.map { $0.profileID })
        let expected: Set<String> = [
            "general-category",
            "script",
            "binary-properties",
            "case-folding",
            "white-space",
            "identifier-profiles",
        ]
        XCTAssertEqual(ids, expected, "expected the six named profile IDs")
    }

    /// All six profiles share one generator hash (one generator produced
    /// them all) — provenance of the build tool is uniform.
    func testSharedGeneratorHash() {
        let hashes = Set(MonaRegExpUnicodeTables.allProfiles.map { $0.generatorHash })
        XCTAssertEqual(hashes.count, 1,
                       "all profiles must share a single generator hash")
    }

    /// Each profile's input hash and output hash are distinct — each profile
    /// is independently sourced and independently emitted.
    func testDistinctInputAndOutputHashes() {
        let inputs = MonaRegExpUnicodeTables.allProfiles.map { $0.inputHash }
        let outputs = MonaRegExpUnicodeTables.allProfiles.map { $0.outputHash }
        XCTAssertEqual(Set(inputs).count, 6, "input hashes must be distinct")
        XCTAssertEqual(Set(outputs).count, 6, "output hashes must be distinct")
    }

    // MARK: - 4. Non-mergeable identity

    /// `canMerge` is unconditionally false for every pair — profiles never
    /// collapse into one another regardless of range equality.
    func testCanMergeIsAlwaysFalse() {
        let profiles = MonaRegExpUnicodeTables.allProfiles
        for i in 0..<profiles.count {
            for j in 0..<profiles.count where i != j {
                XCTAssertFalse(profiles[i].canMerge(with: profiles[j]),
                    "profiles[\(i)] (\(profiles[i].profileID)) must not merge with " +
                    "profiles[\(j)] (\(profiles[j].profileID))")
            }
        }
        // A profile cannot merge with itself either: merging is not a defined
        // operation on these profiles.
        for profile in profiles {
            XCTAssertFalse(profile.canMerge(with: profile),
                "\(profile.profileID): canMerge(self) must be false")
        }
    }

    /// The decisive non-mergeability proof: two profiles whose RANGES compare
    /// equal remain distinct identities, because identity is carried by the
    /// profile ID + provenance, not by the range bytes.
    func testNonMergeableEvenWhenRangesCompareEqual() {
        let original = MonaRegExpUnicodeTables.allProfiles[0]

        // A synthetic profile that copies `original`'s ranges byte-for-byte
        // but carries a different profile ID.
        let shadow = MonaRegExpUnicodeProfile(
            profileID: "synthetic-shadow",
            sourceVersion: original.sourceVersion,
            inputHash: original.inputHash,
            generatorHash: original.generatorHash,
            outputHash: original.outputHash,
            propertySet: original.propertySet,
            consumerSet: original.consumerSet,
            ranges: original.ranges
        )

        // Ranges compare equal...
        XCTAssertEqual(shadow.ranges, original.ranges,
                       "shadow should carry identical ranges")
        XCTAssertEqual(shadow.outputHash, original.outputHash,
                       "shadow should carry the identical output hash")

        // ...yet the profiles are NOT equal (different profileID)...
        XCTAssertNotEqual(shadow, original,
            "different profileID => profiles are not the same identity")
        // ...and merging is still forbidden.
        XCTAssertFalse(shadow.canMerge(with: original),
            "non-mergeable even when ranges compare equal")
        XCTAssertFalse(original.canMerge(with: shadow),
            "non-mergeable even when ranges compare equal")
    }

    /// A profile with the same ID but different provenance is a different
    /// record — identity is the full provenance tuple, not the ID alone.
    func testIdentityIsFullProvenanceNotIDAlone() {
        let base = MonaRegExpUnicodeTables.allProfiles[0]
        let tampered = MonaRegExpUnicodeProfile(
            profileID: base.profileID,
            sourceVersion: base.sourceVersion,
            inputHash: "0".padding(toLength: 64, withPad: "0", startingAt: 0),
            generatorHash: base.generatorHash,
            outputHash: base.outputHash,
            propertySet: base.propertySet,
            consumerSet: base.consumerSet,
            ranges: base.ranges
        )
        XCTAssertNotEqual(tampered, base,
            "same ID + ranges but different input hash => distinct record")
    }

    /// Two profiles that differ only in their consumer set remain distinct —
    /// the consumer set is part of the profile's identity and cannot be
    /// dropped during merging.
    func testConsumerSetIsIdentityBearing() {
        let base = MonaRegExpUnicodeTables.allProfiles[0]
        let altConsumer = MonaRegExpUnicodeProfile(
            profileID: base.profileID,
            sourceVersion: base.sourceVersion,
            inputHash: base.inputHash,
            generatorHash: base.generatorHash,
            outputHash: base.outputHash,
            propertySet: base.propertySet,
            consumerSet: ["some-other-consumer"],
            ranges: base.ranges
        )
        XCTAssertNotEqual(altConsumer, base,
            "different consumer set => distinct profile identity")
        XCTAssertFalse(altConsumer.canMerge(with: base),
            "consumer set divergence forbids merging")
    }

    /// Each profile's recorded consumer set is non-empty and lists real
    /// downstream MonaCode consumers.
    func testConsumerSetsReferenceRealConsumers() {
        let knownConsumers: Set<String> = [
            "MonaRegExpParser",
            "MonaRegExpExecutor",
            "MonaRegExpCompiler",
            "MonaWordClassifier",
            "MonaCaseConverter",
            "MonaRegExpConsumerProfile",
        ]
        for profile in MonaRegExpUnicodeTables.allProfiles {
            for consumer in profile.consumerSet {
                XCTAssertTrue(knownConsumers.contains(consumer),
                    "\(profile.profileID): unknown consumer \(consumer)")
            }
        }
    }

    /// Each profile's recorded property set is non-empty and lists only
    /// non-empty property names.
    func testPropertySetsAreNonEmptyAndNamed() {
        for profile in MonaRegExpUnicodeTables.allProfiles {
            for property in profile.propertySet {
                XCTAssertFalse(property.isEmpty,
                    "\(profile.profileID): empty property name")
            }
            XCTAssertEqual(Set(profile.propertySet).count,
                           profile.propertySet.count,
                           "\(profile.profileID): duplicate property names")
        }
    }

    /// The White_Space profile and the Binary Properties profile both reference
    /// `White_Space` semantics, yet remain distinct profiles — a concrete
    /// demonstration that semantic overlap never authorizes merging.
    func testWhiteSpaceOverlapDoesNotAuthorizeMerge() {
        let binary = MonaRegExpUnicodeTables.binaryProperties
        let ws = MonaRegExpUnicodeTables.whiteSpace
        XCTAssertFalse(binary.canMerge(with: ws),
            "White_Space overlap between binary-properties and white-space " +
            "profiles must not authorize merging")
        XCTAssertNotEqual(binary.profileID, ws.profileID,
            "the two profiles carry distinct profile IDs")
    }

    /// The identifier-profiles (ID_Start/ID_Continue) profile and the
    /// binary-properties profile (which also lists ID_Start/ID_Continue as
    /// binary property names) remain distinct: name overlap is not identity.
    func testIdentifierOverlapDoesNotAuthorizeMerge() {
        let binary = MonaRegExpUnicodeTables.binaryProperties
        let idp = MonaRegExpUnicodeTables.identifierProfiles
        XCTAssertFalse(binary.canMerge(with: idp),
            "ID_Start/ID_Continue overlap must not authorize merging")
        XCTAssertNotEqual(binary.profileID, idp.profileID)
    }
}
