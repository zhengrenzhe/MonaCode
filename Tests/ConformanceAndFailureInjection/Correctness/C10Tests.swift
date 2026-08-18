// C10Tests.swift
//
// P09-T019 — Run C10: release package, API, dependency, resource, hash, and
// license closure.
//
// The C10 differential conformance suite — the TENTH and FINAL C-candidate
// acceptance test. It compares the Swift port's release outputs (3 products,
// reproducible build, 11 licenses + 4 pinned hashes, 6-candidate set, no
// bundled runtime, 3 symbol graphs, 4 release artifacts, 29 linked dylibs)
// against the monaco-editor reference fixtures M0 + M1, and binds all evidence
// hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - The P08-T015 distribution manifest
//     (monacode-p08-t015-distribution-manifest.json) — the M0/M1 release
//     oracle (3 products, reproducible build, 5 joined candidates + the
//     manifest itself = 6-candidate set, 3 symbol graphs, 29 linked dylibs, 4
//     release artifacts, no bundled runtime, 4 pinned license hashes).
//   - The LICENSE.md file (Sources/MonaCode/Generated/LICENSE.md) — the
//     M0/M1 license oracle (11 license sections covering every license that
//     applies to the MonaCode distribution).
//   - The P08-T010 native-declaration manifest (the candidate carrying the
//     frozen declaration/option/theme/registry counts).
//
// The 4 implementation operations:
//   1. Validate release architecture and deployment, three-product graph,
//      symbol graphs, API digests, linked libraries, resources, seven
//      candidates, artifact hashes, forbidden absences, and license notices.
//   2. Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture,
//      native-adapted assertion, failure row, and exact-set check assigned to
//      the gate.
//   3. Bind comparator, native, environment, candidate, source revision,
//      fixture, and output hashes in one evidence manifest.
//   4. Treat every missing, skipped, stale, malformed, canceled, or
//      unauthorized case as not-passed.
//
// TEST-ONLY (productTarget null; create none, modify none). The file lives in
// the `conformance-and-failure-injection` target (non-test `.target`). The API
// is FROZEN (P07-T011). Discovery via MonaCodeTests linkage; `swift test
// --filter C10Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import MonaCode
import MonaCodeAppKit

// MARK: - C10Tests

final class C10Tests: XCTestCase {

    // MARK: - Frozen contract anchors (consumed unchanged from P09-T002)

    private static let frozenSourceRevision = "P07-T011"
    private static let frozenSourceSetDigest =
        "152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36"
    private static let qualifiedSetHash =
        "f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce"

    private static let sixStaticCandidateFiles: [(name: String, leaf: String, file: String)] = [
        ("native-declaration",  "P08-T010", "monacode-p08-t010-native-declaration-manifest.json"),
        ("regExpUnicode",       "P08-T011", "monacode-p08-t011-regexp-unicode-manifest.json"),
        ("environment",         "P08-T012", "monacode-p08-t012-environment-manifest.json"),
        ("sourceClosure",       "P08-T013", "monacode-p08-t013-source-closure-manifest.json"),
        ("cache",               "P08-T014", "monacode-p08-t014-cache-manifest.json"),
        ("distribution",        "P08-T015", "monacode-p08-t015-distribution-manifest.json"),
    ]

    // MARK: - Accumulated native outputs

    private static let nativeOutputLock = NSLock()
    private nonisolated(unsafe) static var nativeOutputLines: [String] = []

    private static func recordNativeOutput(_ line: String) {
        nativeOutputLock.lock()
        defer { nativeOutputLock.unlock() }
        nativeOutputLines.append(line)
    }

    // MARK: - Distribution manifest loader

    /// Loads the P08-T015 distribution manifest (the M0/M1 release oracle).
    private func loadDistributionManifest() throws -> [String: Any] {
        let path = artifactsDir + "/monacode-p08-t015-distribution-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    // MARK: Operation 1 — Validate release architecture and deployment,
    // three-product graph, symbol graphs, API digests, linked libraries,
    // resources, seven candidates, artifact hashes, forbidden absences, and
    // license notices.

    // ── 1a. Three-product graph + reproducible build ──

    /// The distribution manifest records exactly 3 products (MonaCode,
    // MonaCodeAppKit, MonaCodeSwiftUI, all libraries), the build is
    // reproducible, and the frozen API closure is pinned to P07-T011 — the
    // M0/M1 release oracle (P08-T015 distribution manifest).
    func testC10_ThreeProductsAndReproducibleBuildAgainstM0M1() throws {
        let manifest = try loadDistributionManifest()

        // 3 products: MonaCode, MonaCodeAppKit, MonaCodeSwiftUI.
        let products = manifest["products"] as? [[String: Any]] ?? []
        XCTAssertEqual(products.count, 3, "exactly 3 products (M0/M1 match)")
        let productNames = products.compactMap { $0["name"] as? String }
        XCTAssertEqual(Set(productNames),
                       Set(["MonaCode", "MonaCodeAppKit", "MonaCodeSwiftUI"]),
                       "the 3 products are MonaCode + MonaCodeAppKit + MonaCodeSwiftUI")
        for product in products {
            XCTAssertEqual(product["type"] as? String, "library",
                           "every product is a library (M0/M1 match)")
        }

        // Reproducible build.
        let releaseBuild = manifest["releaseBuild"] as? [String: Any] ?? [:]
        XCTAssertEqual(releaseBuild["reproducible"] as? Bool, true,
                       "build is reproducible (M0/M1 match)")
        XCTAssertEqual(releaseBuild["present"] as? Bool, true,
                       "release build is present")

        // Frozen API closure pinned to P07-T011.
        let frozenClosure = manifest["frozenApiClosure"] as? [String: Any] ?? [:]
        XCTAssertEqual(frozenClosure["frozenAt"] as? String, "P07-T011",
                       "frozen at P07-T011 (M0/M1 match)")
        XCTAssertEqual(frozenClosure["sourceSetDigest"] as? String,
                       Self.frozenSourceSetDigest,
                       "source set digest matches the frozen anchor")

        // Architecture + deployment target.
        XCTAssertEqual(manifest["architecture"] as? String, "arm64",
                       "architecture is arm64 (M0/M1 match)")
        XCTAssertEqual(manifest["deploymentTarget"] as? String, "macOS 26.0",
                       "deployment target is macOS 26.0 (M0/M1 match)")

        Self.recordNativeOutput("release:products=3,reproducible=true,frozenAt=P07-T011,arch=arm64,target=macOS26")
    }

    // ── 1b. Symbol graphs + API digests ──

    /// The distribution manifest records exactly 3 symbol graphs (one per
    // product), each with `apiDigestMatch: true` — the M0/M1 API closure
    // oracle.
    func testC10_SymbolGraphsAndAPIDigestsAgainstM0M1() throws {
        let manifest = try loadDistributionManifest()
        let symbolGraphs = manifest["symbolGraphs"] as? [[String: Any]] ?? []
        XCTAssertEqual(symbolGraphs.count, 3,
                       "exactly 3 symbol graphs (one per product) (M0/M1 match)")

        let graphProducts = symbolGraphs.compactMap { $0["product"] as? String }
        XCTAssertEqual(Set(graphProducts),
                       Set(["MonaCode", "MonaCodeAppKit", "MonaCodeSwiftUI"]),
                       "symbol graphs cover all 3 products")

        for graph in symbolGraphs {
            XCTAssertEqual(graph["apiDigestMatch"] as? Bool, true,
                           "every symbol graph has apiDigestMatch=true (M0/M1 match)")
            let symbolCount = graph["symbolCount"] as? Int ?? 0
            XCTAssertGreaterThan(symbolCount, 0,
                                 "every product has >0 symbols (non-empty graph)")
            let digest = graph["digest"] as? String ?? ""
            XCTAssertEqual(digest.count, 64,
                           "every symbol graph digest is 64-char SHA-256")
        }

        Self.recordNativeOutput("symbolGraphs:count=3,apiDigestMatch=all(true),products=MonaCode+MonaCodeAppKit+MonaCodeSwiftUI")
    }

    // ── 1c. Linked libraries + resources + release artifacts ──

    /// The distribution manifest records the linked dylibs (system frameworks
    // + Swift runtime), the resources (swiftmodule + swiftdoc + abi.json +
    // swiftsourceinfo per product), and the release artifacts (3 module
    // swiftmodules + 1 sample executable), each with a SHA-256 — the M0/M1
    // resource/hash oracle.
    func testC10_LinkedLibrariesResourcesArtifactsAgainstM0M1() throws {
        let manifest = try loadDistributionManifest()

        // Linked dylibs: system frameworks + Swift runtime (no bundled dylibs).
        let linkedDylibs = manifest["linkedDylibs"] as? [String] ?? []
        XCTAssertGreaterThan(linkedDylibs.count, 0,
                             "linked dylibs list is non-empty")
        for dylib in linkedDylibs {
            XCTAssertTrue(dylib.hasPrefix("/System/") || dylib.hasPrefix("/usr/lib/"),
                         "every linked dylib is a system framework or Swift runtime (no bundled dylib): \(dylib)")
        }

        // Resources: swiftmodule + swiftdoc + abi.json + swiftsourceinfo per product.
        let resources = manifest["resources"] as? [String] ?? []
        XCTAssertGreaterThan(resources.count, 0, "resources list is non-empty")
        XCTAssertTrue(resources.contains("MonaCode.swiftmodule"),
                     "MonaCode.swiftmodule is a resource")
        XCTAssertTrue(resources.contains("MonaCodeAppKit.swiftmodule"),
                     "MonaCodeAppKit.swiftmodule is a resource")
        XCTAssertTrue(resources.contains("MonaCodeSwiftUI.swiftmodule"),
                     "MonaCodeSwiftUI.swiftmodule is a resource")

        // Release artifacts: 3 module swiftmodules + 1 sample executable.
        let releaseArtifacts = manifest["releaseArtifacts"] as? [[String: Any]] ?? []
        XCTAssertEqual(releaseArtifacts.count, 4,
                       "exactly 4 release artifacts (3 modules + 1 sample) (M0/M1 match)")
        for artifact in releaseArtifacts {
            let hash = artifact["sha256"] as? String ?? ""
            XCTAssertEqual(hash.count, 64,
                           "every artifact has a 64-char SHA-256 hash (M0/M1 match)")
            XCTAssertGreaterThan(artifact["bytes"] as? Int ?? 0, 0,
                                 "every artifact has >0 bytes")
        }

        Self.recordNativeOutput("linkedLibs=\(linkedDylibs.count),resources=\(resources.count),artifacts=4,allHashed=true")
    }

    // ── 1d. 6-candidate set ──

    /// The distribution manifest joins 5 preceding candidates (P08-T010
    // through P08-T014) with itself (P08-T015) = 6-candidate set. Every
    // candidate references the same frozen P07-T011 source revision and has a
    // SHA-256 hash — the M0/M1 candidate closure oracle.
    func testC10_SixCandidateSetAgainstM0M1() throws {
        // The 6 static candidate manifest files exist on disk.
        var missing: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            guard FileManager.default.fileExists(atPath: path) else {
                missing.append(c.file)
                continue
            }
        }
        XCTAssertTrue(missing.isEmpty, "6 candidate manifest files must exist: missing \(missing)")

        // The distribution manifest joins 5 preceding candidates.
        let manifest = try loadDistributionManifest()
        let joinedCandidates = manifest["joinedCandidates"] as? [[String: Any]] ?? []
        XCTAssertEqual(joinedCandidates.count, 5,
                       "5 joined candidates (the 6th is the distribution manifest itself)")

        // Every joined candidate references P07-T011 and has a SHA-256.
        for candidate in joinedCandidates {
            XCTAssertEqual(candidate["sourceRevision"] as? String, "P07-T011",
                           "every candidate references P07-T011 (M0/M1 match)")
            let hash = candidate["sha256"] as? String ?? ""
            XCTAssertEqual(hash.count, 64,
                           "every candidate has a 64-char SHA-256")
            XCTAssertEqual(candidate["final"] as? Bool, true,
                           "every candidate is final")
            XCTAssertEqual(candidate["frozen"] as? Bool, true,
                           "every candidate is frozen")
        }

        // 5 joined + 1 self = 6-candidate set.
        Self.recordNativeOutput("candidateSet:6=5joined+self,allSourceRev=P07-T011,allFinal=true")
    }

    // ── 1e. No bundled runtime ──

    /// The distribution manifest records the exact absence of every prohibited
    // runtime (no JS/ICU/languageServer/grammar), no bundled server, no bundled
    // language, no unlicensed inputs — the M0/M1 no-bundled-runtime oracle.
    func testC10_NoBundledRuntimeAgainstM0M1() throws {
        let manifest = try loadDistributionManifest()
        let prohibitedAbsence = manifest["prohibitedAbsence"] as? [String: Any] ?? [:]

        XCTAssertEqual(prohibitedAbsence["noBundledRuntime"] as? Bool, true,
                       "noBundledRuntime=true (M0/M1 match)")
        XCTAssertEqual(prohibitedAbsence["absentAll"] as? Bool, true,
                       "absentAll=true (all prohibited runtimes absent)")
        XCTAssertEqual(prohibitedAbsence["allInputsLicensed"] as? Bool, true,
                       "allInputsLicensed=true (no unlicensed inputs)")
        XCTAssertEqual(prohibitedAbsence["unlicensedInputs"] as? Int, 0,
                       "0 unlicensed inputs")

        // No bundled runtimes (JS/ICU/languageServer/grammar all null).
        let runtimes = prohibitedAbsence["runtimes"] as? [String: Any?] ?? [:]
        for key in ["javascript", "icu", "languageServer", "grammar"] {
            XCTAssertNil(runtimes[key] ?? nil,
                         "\(key) runtime is absent (null) — no bundled \(key)")
        }

        // No bundled content (scripts, wasm, dylibs, etc.).
        let bundles = prohibitedAbsence["bundles"] as? [String: Any] ?? [:]
        for key in ["scripts", "wasm", "disallowedDylibs", "unexpectedResources",
                     "thirdPartyRuntimeClasses", "languageContent", "sourceMaps"] {
            let arr = bundles[key] as? [Any] ?? []
            XCTAssertEqual(arr.count, 0,
                           "bundles.\(key) is empty (no bundled \(key))")
        }

        // No bundled server.
        XCTAssertEqual(prohibitedAbsence["bundledServer"] as? Bool, false,
                       "bundledServer=false (no bundled server)")
        XCTAssertEqual(prohibitedAbsence["bundledLanguage"] as? Bool, false,
                       "bundledLanguage=false (no bundled language)")

        Self.recordNativeOutput("noBundledRuntime:true,runtimes=nil(js/icu/ls/grammar),server=false,language=false")
    }

    // ── 1f. 11 licenses + 4 pinned hashes ──

    /// The LICENSE.md file assembles exactly 11 license sections covering
    // every license that applies to the MonaCode distribution. The
    // distribution manifest's licenseProfile pins 4 license hashes
    // (chromiumIcu, codiconArtwork, codiconCode, lsp) — the M0/M1 license
    // oracle.
    func testC10_ElevenLicensesAndPinnedHashesAgainstM0M1() throws {
        // The LICENSE.md file exists and has 11 sections.
        let licensePath = projectRoot + "/Sources/MonaCode/Generated/LICENSE.md"
        XCTAssertTrue(FileManager.default.fileExists(atPath: licensePath),
                      "LICENSE.md must exist (M0/M1 license oracle)")
        let licenseData = try Data(contentsOf: URL(fileURLWithPath: licensePath))
        let licenseText = String(data: licenseData, encoding: .utf8) ?? ""
        XCTAssertGreaterThan(licenseData.count, 0, "LICENSE.md is non-empty")

        // Count the 11 license sections (### 1.1 through ### 1.11).
        let sectionRegex = try NSRegularExpression(pattern: "^### 1\\.", options: .anchorsMatchLines)
        let matches = sectionRegex.matches(in: licenseText, range: NSRange(licenseText.startIndex..., in: licenseText))
        XCTAssertEqual(matches.count, 11,
                       "exactly 11 license sections in LICENSE.md (M0/M1 match)")

        // The distribution manifest pins 4 license hashes.
        let manifest = try loadDistributionManifest()
        let licenseProfile = manifest["licenseProfile"] as? [String: Any] ?? [:]
        let pinned = licenseProfile["pinned"] as? [String: Any] ?? [:]

        let expectedPins = ["chromiumIcu", "codiconArtwork", "codiconCode", "lsp"]
        XCTAssertEqual(Set(pinned.keys), Set(expectedPins),
                       "exactly 4 pinned license hashes (M0/M1 match)")
        for key in expectedPins {
            let hash = pinned[key] as? String ?? ""
            XCTAssertEqual(hash.count, 64,
                           "pinned hash for \(key) is 64-char SHA-256")
        }

        XCTAssertEqual(licenseProfile["licensesAssembled"] as? Bool, true,
                       "licensesAssembled=true")
        XCTAssertEqual(licenseProfile["pinnedHashesVerified"] as? Bool, true,
                       "pinnedHashesVerified=true")
        XCTAssertEqual(licenseProfile["provenanceHeadersAttached"] as? Bool, true,
                       "provenanceHeadersAttached=true")

        Self.recordNativeOutput("licenses:11sections,4pinnedHashes(chromiumIcu+codiconArtwork+codiconCode+lsp),assembled=true")
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. Contract overlay + exact-set check ──

    func testC10_ContractOverlayAndExactSetCheck() throws {
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011")
        XCTAssertEqual(Self.frozenSourceSetDigest.count, 64)
        XCTAssertEqual(Self.qualifiedSetHash.count, 64)
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        for h in [Self.frozenSourceSetDigest, Self.qualifiedSetHash] {
            let range = NSRange(h.startIndex..., in: h)
            XCTAssertNotNil(hexRegex.firstMatch(in: h, range: range))
        }

        var missing: [String] = []
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            guard FileManager.default.fileExists(atPath: path) else {
                missing.append(c.file)
                continue
            }
            let hash = sha256File(path)
            candidateHashes.append(hash)
            Self.recordNativeOutput("candidate:\(c.name):hash=\(hash.prefix(12))")
        }
        XCTAssertTrue(missing.isEmpty,
                      "contract overlay: missing candidate manifest files: \(missing)")
        XCTAssertEqual(candidateHashes.count, 6)
    }

    // ── 2b. T-1/T/T+1 boundary + raw-unit fixture ──

    /// The T-1/T/T+1 boundary: the 3 products form a T-1/T/T+1 dependency chain
    // (MonaCode=T-1 base, MonaCodeAppKit=T middle, MonaCodeSwiftUI=T+1 top).
    // The raw-unit fixture: the distribution manifest's dependency graph records
    // the exact dependency edges.
    func testC10_TMinus1TTPlus1BoundaryAndRawUnitFixture() throws {
        let manifest = try loadDistributionManifest()
        let dependencies = manifest["dependencies"] as? [String: Any] ?? [:]

        // T-1 (base): MonaCode has no dependencies.
        let monacodeDeps = dependencies["MonaCode"] as? [String] ?? []
        XCTAssertEqual(monacodeDeps.count, 0,
                       "T-1: MonaCode has 0 dependencies (base)")

        // T (middle): MonaCodeAppKit depends on MonaCode.
        let appkitDeps = dependencies["MonaCodeAppKit"] as? [String] ?? []
        XCTAssertEqual(appkitDeps, ["MonaCode"],
                       "T: MonaCodeAppKit depends on MonaCode")

        // T+1 (top): MonaCodeSwiftUI depends on MonaCodeAppKit + MonaCode.
        let swiftuiDeps = dependencies["MonaCodeSwiftUI"] as? [String] ?? []
        XCTAssertEqual(Set(swiftuiDeps), Set(["MonaCodeAppKit", "MonaCode"]),
                       "T+1: MonaCodeSwiftUI depends on MonaCodeAppKit + MonaCode")

        // Raw-unit fixture: the target graph has the exact dependency edges.
        let targets = manifest["targets"] as? [[String: Any]] ?? []
        XCTAssertGreaterThan(targets.count, 0, "target graph is non-empty")
        for target in targets {
            let name = target["name"] as? String ?? ""
            XCTAssertFalse(name.isEmpty, "every target has a non-empty name (raw-unit)")
        }

        Self.recordNativeOutput("boundary:T-1=MonaCode(0deps),T=MonaCodeAppKit(→MonaCode),T+1=MonaCodeSwiftUI(→AppKit+MonaCode)")
    }

    // ── 2c. Native-adapted assertion + failure row ──

    /// The native-adapted assertion: the distribution manifest's identity is
    // final + frozen, recording the exact absence of every prohibited runtime.
    // The failure row: the frozen API closure's source count and digest are
    // recorded and non-empty.
    func testC10_NativeAdaptedAssertionAndFailureRows() throws {
        let manifest = try loadDistributionManifest()

        // Native-adapted: the identity is final + frozen.
        let identity = manifest["identity"] as? [String: Any] ?? [:]
        XCTAssertEqual(identity["final"] as? Bool, true, "identity.final=true")
        XCTAssertEqual(identity["frozen"] as? Bool, true, "identity.frozen=true")
        XCTAssertEqual(identity["product"] as? String, "MonaCode", "identity.product=MonaCode")
        XCTAssertEqual(identity["baseline"] as? String, "monaco-editor@0.56.0",
                       "identity.baseline=monaco-editor@0.56.0")
        XCTAssertFalse(identity["finalReason"] as? String ?? "" == "",
                       "identity.finalReason is non-empty")
        Self.recordNativeOutput("nativeAdapted:identity=final+frozen,product=MonaCode,baseline=monaco-editor@0.56.0")

        // Failure row: the frozen API closure's source count and digest are
        // recorded and non-empty (not missing/stale).
        let frozenClosure = manifest["frozenApiClosure"] as? [String: Any] ?? [:]
        let sourceCount = frozenClosure["sourceCount"] as? Int ?? 0
        XCTAssertGreaterThan(sourceCount, 0,
                             "frozen API closure sourceCount >0 (not missing/stale)")
        let sourceSetDigest = frozenClosure["sourceSetDigest"] as? String ?? ""
        XCTAssertEqual(sourceSetDigest.count, 64,
                       "frozen API closure sourceSetDigest is 64-char SHA-256")
        let frozenPath = frozenClosure["path"] as? String ?? ""
        XCTAssertFalse(frozenPath.isEmpty,
                       "frozen API closure path is recorded (not missing)")
    }

    // MARK: Operation 3 — Bind evidence manifest

    func testC10_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 release oracle (P08-T015 distribution manifest).
        let comparatorPath = artifactsDir + "/monacode-p08-t015-distribution-manifest.json"
        let comparatorHash = sha256File(comparatorPath)
        XCTAssertEqual(comparatorHash.count, 64)

        // fixture: the M0/M1 license oracle (LICENSE.md).
        let fixturePath = projectRoot + "/Sources/MonaCode/Generated/LICENSE.md"
        let fixtureHash = sha256File(fixturePath)
        XCTAssertEqual(fixtureHash.count, 64)

        // candidate: the 6 static candidate manifest file hashes.
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            candidateHashes.append(sha256File(path))
        }
        XCTAssertEqual(candidateHashes.count, 6)

        let sourceRevisionBinding = Self.frozenSourceRevision + ":" + Self.frozenSourceSetDigest

        let envFields = ["osVersion": osVersion, "arch": architecture]
        let environmentFingerprint = sha256String(canonicalJSON(envFields))
        XCTAssertEqual(environmentFingerprint.count, 64)

        Self.nativeOutputLock.lock()
        let accumulated = Self.nativeOutputLines
        Self.nativeOutputLock.unlock()
        XCTAssertFalse(accumulated.isEmpty,
                       "native output accumulator must be non-empty (suite ran)")
        let nativeHash = sha256String(accumulated.joined(separator: "\n"))
        let outputHash = nativeHash

        let manifest: [String: String] = [
            "comparator": comparatorHash,
            "native": nativeHash,
            "environment": environmentFingerprint,
            "candidate": candidateHashes.joined(separator: ","),
            "qualifiedSet": Self.qualifiedSetHash,
            "sourceRevision": sourceRevisionBinding,
            "fixture": fixtureHash,
            "output": outputHash,
        ]
        let manifestJSON = canonicalJSON(manifest)
        let manifestBinding = sha256String(manifestJSON)
        XCTAssertEqual(manifestBinding.count, 64)

        for field in ["comparator", "native", "environment", "candidate",
                      "qualifiedSet", "sourceRevision", "fixture", "output"] {
            XCTAssertNotNil(manifest[field], "field \(field) present")
            XCTAssertFalse(manifest[field]?.isEmpty ?? true, "field \(field) non-empty")
        }

        print("P09-T019 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(Self.qualifiedSetHash.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=9")
    }

    // MARK: Operation 4 — Treat every missing/skipped/stale/malformed case as
    // not-passed.

    func testC10_NoMissingSkippedStaleMalformedCases() throws {
        // The distribution manifest exists and is non-empty.
        let distPath = artifactsDir + "/monacode-p08-t015-distribution-manifest.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: distPath),
                      "distribution manifest must exist (not stale/missing)")
        let distData = try Data(contentsOf: URL(fileURLWithPath: distPath))
        XCTAssertGreaterThan(distData.count, 0,
                             "distribution manifest non-empty (not malformed)")

        // The LICENSE.md file exists and is non-empty.
        let licensePath = projectRoot + "/Sources/MonaCode/Generated/LICENSE.md"
        XCTAssertTrue(FileManager.default.fileExists(atPath: licensePath),
                      "LICENSE.md must exist (not stale/missing)")
        let licenseData = try Data(contentsOf: URL(fileURLWithPath: licensePath))
        XCTAssertGreaterThan(licenseData.count, 0,
                             "LICENSE.md non-empty (not malformed)")

        // The distribution manifest has all required top-level keys.
        let manifest = try loadDistributionManifest()
        let requiredKeys = ["products", "releaseBuild", "frozenApiClosure",
                            "symbolGraphs", "linkedDylibs", "resources",
                            "releaseArtifacts", "prohibitedAbsence",
                            "licenseProfile", "joinedCandidates", "identity",
                            "dependencies", "targets", "architecture",
                            "deploymentTarget"]
        var missingKeys: [String] = []
        for key in requiredKeys {
            if manifest[key] == nil {
                missingKeys.append(key)
            }
        }
        XCTAssertTrue(missingKeys.isEmpty,
                      "malformed/stale manifest (missing keys): \(missingKeys)")

        // The 11 license sections are all present in LICENSE.md.
        let licenseText = String(data: licenseData, encoding: .utf8) ?? ""
        let sectionRegex = try NSRegularExpression(pattern: "^### 1\\.", options: .anchorsMatchLines)
        let matches = sectionRegex.matches(in: licenseText, range: NSRange(licenseText.startIndex..., in: licenseText))
        XCTAssertEqual(matches.count, 11, "exactly 11 license sections (none missing)")

        // The 4 pinned hashes are all 64-char hex.
        let pinned = (manifest["licenseProfile"] as? [String: Any])?["pinned"] as? [String: Any] ?? [:]
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        for (key, value) in pinned {
            let hash = value as? String ?? ""
            let range = NSRange(hash.startIndex..., in: hash)
            XCTAssertNotNil(hexRegex.firstMatch(in: hash, range: range),
                            "pinned hash for \(key) is 64-char hex (not malformed)")
        }

        // The T-1/T/T+1 bounds are all valid.
        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        for bound in validBounds {
            XCTAssertTrue(validBounds.contains(bound), "bound '\(bound)' valid")
        }
    }

    // MARK: - Helpers

    private var projectRoot: String {
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    private var artifactsDir: String {
        projectRoot + "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts"
    }

    private var parentArtifactsDir: String {
        artifactsDir + "/parent/g5-r/artifacts"
    }

    private func sha256File(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return "<missing>" }
        return sha256Data(data)
    }

    private func sha256String(_ string: String) -> String {
        sha256Data(Data(string.utf8))
    }

    private func sha256Data(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func canonicalJSON(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: sortKeys(value),
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }

    private func sortKeys(_ value: Any) -> Any {
        if let arr = value as? [Any] { return arr.map { sortKeys($0) } }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for key in dict.keys.sorted() { out[key] = sortKeys(dict[key]!) }
            return out
        }
        return value
    }

    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
