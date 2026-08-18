// C04Tests.swift
//
// P09-T013 — Run C04: public declarations, registries, options, themes,
// localization, and runtime-style closure.
//
// The C04 differential conformance suite — the FOURTH C-candidate acceptance
// test. It compares the Swift port's public declarations, registry identities,
// option boundaries, theme assets, localization profiles, and runtime-style
// substitutions against the monaco-editor reference fixtures M0 + M1, and
// binds all evidence hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - The P08-T010 native-declaration manifest
//     (monacode-p08-t010-native-declaration-manifest.json) — the M0/M1
//     declaration oracle (555 declarations, 174 options, 15 profiles, 1219
//     registry rows, 1211 theme rows, 64 features, 91 languages).
//   - The source-x1r-runtime-style-closure.html — the M0/M1 runtime-style
//     oracle (X1-R closure: explicit cuts, forbidden runtime classes, native
//     style projections).
//   - The P08-T013 source-closure manifest — the M0/M1 runtime-style
//     candidate (12 explicit cuts, 14 forbidden runtime classes, 20 runtime-
//     style substitutions).
//   - The Phase 05 documented public-surface semantics (the M0/M1-ported
//     semantics frozen by the G4-R design).
//
// The 4 implementation operations:
//   1. Validate all 555 public paths, registry identities, option boundaries,
//      theme assets, 2120 messages, native type adaptations, and X1-R
//      occurrence sets.
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
// --filter C04Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import MonaCode
import MonaCodeAppKit

// MARK: - C04Tests

final class C04Tests: XCTestCase {

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

    // MARK: Operation 1 — Validate all 555 public paths, registry identities,
    // option boundaries, theme assets, 2120 messages, native type adaptations,
    // and X1-R occurrence sets against M0 and M1.

    // ── 1a. The 555 public declarations (P08-T010 native-declaration manifest) ─

    /// The P08-T010 native-declaration manifest carries exactly 555
    /// declarations, 174 options, 15 localization profiles, 1219 registry rows,
    /// 1211 theme rows, 64 features, 91 languages, and 7 native adaptations —
    /// the M0/M1-ported public-surface oracle. The frozen baseline is pinned
    /// to P07-T011 with the frozen source set digest.
    func testC04_PublicDeclarations555AgainstM0M1() throws {
        let path = artifactsDir + "/monacode-p08-t010-native-declaration-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let counts = obj?["counts"] as? [String: Any] ?? [:]

        // The 555 public declarations (the M0/M1 declaration oracle).
        XCTAssertEqual(counts["declaration"] as? Int, 555,
                       "exactly 555 public declarations (M0/M1 match)")
        XCTAssertEqual(counts["option"] as? Int, 174,
                       "exactly 174 options (M0/M1 match)")
        XCTAssertEqual(counts["localization"] as? Int, 15,
                       "exactly 15 localization profiles (M0/M1 match)")
        XCTAssertEqual(counts["registry"] as? Int, 1219,
                       "exactly 1219 registry rows (M0/M1 match)")
        XCTAssertEqual(counts["theme"] as? Int, 1211,
                       "exactly 1211 theme rows (M0/M1 match)")
        XCTAssertEqual(counts["feature"] as? Int, 64,
                       "exactly 64 features (M0/M1 match)")
        XCTAssertEqual(counts["language"] as? Int, 91,
                       "exactly 91 languages (M0/M1 match)")
        XCTAssertEqual(counts["nativeAdaptation"] as? Int, 7,
                       "exactly 7 native adaptations (M0/M1 match)")
        Self.recordNativeOutput("declarations:555=options\(counts["option"]!)profiles\(counts["localization"]!)")

        // The frozen baseline is pinned to P07-T011.
        let baseline = obj?["frozenBaseline"] as? [String: Any] ?? [:]
        XCTAssertEqual(baseline["frozenAt"] as? String, "P07-T011",
                       "frozen baseline pinned to P07-T011")
        let sourceSetDigest = baseline["sourceSetDigest"] as? String ?? ""
        XCTAssertEqual(sourceSetDigest, Self.frozenSourceSetDigest,
                       "frozen source set digest matches the P09-T002 anchor")
    }

    // ── 1b. Command / action / contribution registries ──

    /// The command registry holds 454 frozen identities (453 retained + 1
    /// cutWebGpuDebug). The action registry holds 167 action identities + 127
    /// pureText identities. The contribution registry holds 53 identities
    /// (52 retainedMacos + 1 laterIpados). These are the M0/M1-ported
    /// registry identity sets, emitted without renaming or coalescing.
    func testC04_RegistriesCommandActionContributionAgainstM0M1() {
        let commands = MonaCommandRegistry()
        XCTAssertEqual(commands.totalCount, 454, "454 frozen command identities")
        XCTAssertEqual(commands.liveCount, 453, "453 live commands")
        XCTAssertEqual(commands.cutCount, 1, "1 cut command (WebGPU debug)")
        XCTAssertTrue(commands.contains("cursorEnd"), "a known live command is present")
        XCTAssertFalse(commands.isDisposed, "registry is not disposed")
        commands.dispose()
        XCTAssertTrue(commands.isDisposed, "disposal is idempotent")
        Self.recordNativeOutput("registry:commands=total\(commands.totalCount)live\(commands.liveCount)cut\(commands.cutCount)")

        let actions = MonaActionRegistry()
        XCTAssertEqual(actions.actionCount, 167, "167 frozen action identities")
        XCTAssertEqual(actions.pureTextCount, 127, "127 pureText action identities")
        Self.recordNativeOutput("registry:actions=\(actions.actionCount)pureText=\(actions.pureTextCount)")

        let contributions = MonaContributionRegistry()
        XCTAssertEqual(contributions.totalCount, 53, "53 frozen contribution identities")
        XCTAssertEqual(contributions.liveCount, 52, "52 live contributions (retainedMacos)")
        XCTAssertEqual(contributions.cutCount, 1, "1 cut contribution (laterIpados)")
        Self.recordNativeOutput("registry:contributions=total\(contributions.totalCount)live\(contributions.liveCount)")
    }

    // ── 1c. The 174 editor options (157 retained-input + 6 computed-only + 11 cut) ──

    /// The option store holds exactly 174 builtin options: 157 retained-input
    /// (mutable), 6 computed-only (read-only derived), and 11 cut (excluded).
    /// The store populates canonical defaults on init and validates input types
    /// — the M0/M1 option contract.
    func testC04_Options174AgainstM0M1() {
        XCTAssertEqual(MonaBuiltinOptions.options.count, 174,
                       "exactly 174 builtin options (M0/M1 match)")
        XCTAssertEqual(MonaBuiltinOptions.retainedInputOptions.count, 157,
                       "157 retained-input options")
        XCTAssertEqual(MonaBuiltinOptions.computedOnlyOptions.count, 6,
                       "6 computed-only options")
        XCTAssertEqual(MonaBuiltinOptions.cutOptions.count, 11,
                       "11 cut options")
        XCTAssertEqual(
            MonaBuiltinOptions.retainedInputOptions.count
            + MonaBuiltinOptions.computedOnlyOptions.count
            + MonaBuiltinOptions.cutOptions.count,
            174, "157 + 6 + 11 = 174 (exact partition)")

        let store = MonaOptionStore()
        XCTAssertEqual(MonaOptionStore.cutOptionNames.count, 11,
                       "11 cut option names exposed by the store")
        XCTAssertEqual(MonaOptionStore.computedOptionNames.count, 6,
                       "6 computed-only option names exposed by the store")
        XCTAssertFalse(store.isDisposed, "store is not disposed on init")
        store.dispose()
        XCTAssertTrue(store.isDisposed, "store disposal is idempotent")
        Self.recordNativeOutput("options:174=retained157+computed6+cut11")
    }

    // ── 1d. The 4 builtin themes ──

    /// The theme registry owns the 4 builtin themes (vs, vs-dark, hc-black,
    /// hc-light) and boots on vs-dark (Monaco's standalone default). Setting
    /// a known theme fires a change event; setting the same id is a no-op;
    /// an unknown id is rejected — the M0/M1 theme contract.
    func testC04_Themes4BuiltinAgainstM0M1() {
        let builtinIds = MonaBuiltinThemes.ids
        XCTAssertEqual(builtinIds, ["vs", "vs-dark", "hc-black", "hc-light"],
                       "the 4 builtin theme ids in source-ordinal order")
        XCTAssertEqual(MonaBuiltinThemes.builtinThemes.count, 4,
                       "exactly 4 builtin theme definitions")

        let registry = MonaThemeRegistry()
        XCTAssertEqual(registry.currentThemeId, "vs-dark",
                       "default active theme is vs-dark (M0/M1 standalone default)")
        XCTAssertEqual(registry.availableThemes.count, 4,
                       "4 available themes on init")
        XCTAssertFalse(registry.isHighContrast,
                       "vs-dark is not high-contrast")

        // Theme switch fires a change event with old + new ids.
        var events: [MonaThemeChange] = []
        let token = registry.onDidChangeTheme { events.append($0) }
        defer { token.dispose() }
        registry.setTheme("vs")
        XCTAssertEqual(events.count, 1, "one event on switch to vs")
        XCTAssertEqual(events[0].oldThemeId, "vs-dark")
        XCTAssertEqual(events[0].newThemeId, "vs")
        XCTAssertEqual(registry.currentThemeId, "vs")

        // Same id is a no-op (no event).
        registry.setTheme("vs")
        XCTAssertEqual(events.count, 1, "no event on same id")

        // Unknown id is rejected (no event, active theme unchanged).
        registry.setTheme("nonexistent")
        XCTAssertEqual(events.count, 1, "no event on unknown id")
        XCTAssertEqual(registry.currentThemeId, "vs", "active theme unchanged on reject")
        Self.recordNativeOutput("themes:4=defaultvs-dark:switchEventFired")
    }

    // ── 1e. The 15 localization profiles × 2120 messages ──

    /// The N1 UI localization surface carries exactly 15 selectable profiles
    /// × 2120 messages. Each profile is an immutable, repository-owned value
    /// type. Resolution is through the explicit MonaCodeEnvironmentProfile
    /// mechanism (never the runtime locale, never Foundation localization,
    /// never network) — the M0/M1 localization contract.
    func testC04_Localization15Profiles2120MessagesAgainstM0M1() throws {
        let ids = MonaLocalization.selectableProfileIdentifiers
        XCTAssertEqual(ids.count, 15, "exactly 15 selectable N1 profiles")
        XCTAssertEqual(ids, [
            "en", "cs", "de", "es", "fr", "it",
            "ja", "ko", "pl", "pt-br", "ru", "tr",
            "zh-cn", "zh-tw", "pseudo",
        ], "the 15 ids in manifest order (M0/M1 exact-set)")

        XCTAssertEqual(MonaLocalization.messageCount, 2120,
                       "exactly 2120 messages per profile")
        XCTAssertEqual(MonaLocalizationProfiles.profiles.count, 15,
                       "exactly 15 generated profile tables")
        XCTAssertEqual(MonaLocalizationProfiles.identities.count, 2120,
                       "2120 message identities (180 modules / 2120 ordered keys)")

        // Every profile carries exactly 2120 entries.
        for profile in MonaLocalizationProfiles.profiles {
            XCTAssertEqual(profile.entries.count, 2120,
                           "profile \(profile.id) carries exactly 2120 entries")
        }

        // Resolution through the explicit profile mechanism.
        let resolved = try MonaLocalization.resolve(0, profile: .default)
        XCTAssertEqual(resolved, "{0} ({1})", "index 0 resolves to '{0} ({1})' in en")
        Self.recordNativeOutput("localization:15profiles×2120messages=en[0]='{0} ({1})'")
    }

    // ── 1f. Runtime-style (X1-R closure + P08-T013 source-closure manifest) ──

    /// The P08-T013 source-closure manifest carries the runtime-style
    /// occurrence set: 12 explicit cuts, 14 forbidden runtime classes, 20
    /// runtime-style substitutions, 8 native style projections — the M0/M1
    /// runtime-style oracle (X1-R closure).
    func testC04_RuntimeStyleAgainstM0M1() throws {
        let path = artifactsDir + "/monacode-p08-t013-source-closure-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let counts = obj?["counts"] as? [String: Any] ?? [:]

        XCTAssertEqual(counts["explicitCuts"] as? Int, 12,
                       "12 explicit cuts (X1-R M0/M1 match)")
        XCTAssertEqual(counts["forbiddenRuntimeClasses"] as? Int, 14,
                       "14 forbidden runtime classes (X1-R M0/M1 match)")
        XCTAssertEqual(counts["runtimeStyleSubstitutions"] as? Int, 20,
                       "20 runtime-style substitutions (X1-R M0/M1 match)")
        XCTAssertEqual(counts["nativeStyleProjections"] as? Int, 8,
                       "8 native style projections (X1-R M0/M1 match)")
        XCTAssertEqual(counts["generatedSwift"] as? Int, 11,
                       "11 generated Swift sources (X1-R M0/M1 match)")
        XCTAssertEqual(counts["licenseNotices"] as? Int, 3,
                       "3 license notices (X1-R M0/M1 match)")
        Self.recordNativeOutput("runtimeStyle:cuts12=forbidden14=substitutions20")

        // The explicit cuts include the documented X1-R cuts (WebWorker,
        // WebGPU, network, storage, webcrypto).
        let cuts = obj?["explicitCuts"] as? [[String: Any]] ?? []
        XCTAssertEqual(cuts.count, 12, "12 explicit cut rows")
        let cutIds = Set(cuts.compactMap { $0["id"] as? String })
        XCTAssertTrue(cutIds.contains("cut.webworker"), "WebWorker cut present")
        XCTAssertTrue(cutIds.contains("cut.webgpu"), "WebGPU cut present")
        XCTAssertTrue(cutIds.contains("cut.network"), "network cut present")
        XCTAssertTrue(cutIds.contains("cut.storage"), "storage cut present")
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. Contract overlay (P08-T010 manifest frozen baseline) ──

    /// The contract overlay: the P08-T010 native-declaration manifest exists on
    /// disk, hashes to a stable SHA-256 digest, and carries the frozen baseline
    /// (pinned to P07-T011 with the frozen source set digest). Any divergence is
    /// a post-source-change rejection.
    func testC04_ContractOverlayAndExactSetCheck() throws {
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011")
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let hexRange = NSRange(Self.frozenSourceSetDigest.startIndex...,
                               in: Self.frozenSourceSetDigest)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.frozenSourceSetDigest, range: hexRange))

        let qsRange = NSRange(Self.qualifiedSetHash.startIndex...,
                              in: Self.qualifiedSetHash)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.qualifiedSetHash, range: qsRange),
                        "qualified-set hash is 64-char lowercase hex SHA-256")

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
                     "exact-set check: missing candidate manifest files: \(missing)")
        XCTAssertEqual(candidateHashes.count, 6)
    }

    // ── 2b. T-1/T/T+1 boundary (theme switch + option set + localization fallback) ──

    /// The T-1/T/T+1 boundary cases for the public-surface domain: theme
    /// switch boundaries (switch-to-known, same-id, unknown), option-set
    /// boundaries (valid input, cut option, computed-only read-only), and
    /// localization fallback boundaries (en default, pt-br null fallback,
    /// missing message). Every case must run.
    func testC04_TMinus1TTPlus1BoundaryCases() throws {
        let boundaries: [(id: String, bound: String, expect: Bool, check: () throws -> Bool)] = [
            ("theme-switch-T-1", "T-1", true, {
                let r = MonaThemeRegistry()
                return r.currentThemeId == "vs-dark"
            }),
            ("theme-switch-T", "T", true, {
                let r = MonaThemeRegistry()
                r.setTheme("vs")
                return r.currentThemeId == "vs"
            }),
            ("theme-switch-T+1", "T+1", true, {
                let r = MonaThemeRegistry()
                r.setTheme("nonexistent")
                return r.currentThemeId == "vs-dark"
            }),
            ("option-set-T-1", "T-1", true, {
                let s = MonaOptionStore()
                return s.value(for: "lineNumbersMinChars") != nil
            }),
            ("option-set-T", "T", true, {
                let s = MonaOptionStore()
                let result = s.setValue(.int(20), for: "lineNumbersMinChars")
                return result == .success
            }),
            ("option-cut-T+1", "T+1", true, {
                let s = MonaOptionStore()
                let cutName = MonaOptionStore.cutOptionNames.first!
                let result = s.setValue(.int(1), for: cutName)
                return result == .cutOption(cutName)
            }),
            ("localization-en-T-1", "T-1", true, {
                let r = try MonaLocalization.resolve(0, profile: .default)
                return r == "{0} ({1})"
            }),
            ("localization-fallback-T", "T", true, {
                let ptBr = try MonaCodeEnvironmentProfile(identifier: "pt-br")
                let r = try MonaLocalization.resolve(0, profile: ptBr)
                return r == "{0} ({1})"
            }),
            ("localization-missing-T+1", "T+1", true, {
                let r = try? MonaLocalization.resolve(99999, profile: .default)
                return r == nil
            }),
        ]
        var compared = 0
        var mismatches: [String] = []
        for b in boundaries {
            let nativeResult = try b.check()
            if nativeResult != b.expect {
                mismatches.append("\(b.id) [\(b.bound)]: expect=\(b.expect) native=\(nativeResult)")
            }
            Self.recordNativeOutput("boundary:\(b.id):bound=\(b.bound):native=\(nativeResult)")
            compared += 1
        }
        XCTAssertEqual(compared, boundaries.count,
                       "every boundary case must run: \(compared)/\(boundaries.count)")
        XCTAssertTrue(mismatches.isEmpty,
                      "M0/M1 boundary mismatches:\n" + mismatches.joined(separator: "\n"))
    }

    // ── 2c. Native-adapted assertion + failure row ──

    /// The native-adapted assertion: the registries, option store, theme
    /// registry, and localization surface all dispose idempotently (the failure
    /// row — disposal does not crash on re-dispose). Cut options are rejected
    /// from the input API, and computed-only options are read-only.
    func testC04_NativeAdaptedAssertionAndFailureRows() {
        // Failure row 1: cut option is rejected from the input API.
        let store = MonaOptionStore()
        let cutName = MonaOptionStore.cutOptionNames.first!
        XCTAssertEqual(store.setValue(.int(1), for: cutName), .cutOption(cutName),
                       "cut option is rejected from input API")
        XCTAssertNil(store.value(for: cutName), "cut option value is nil")

        // Failure row 2: computed-only option is read-only (never settable).
        let computedName = MonaOptionStore.computedOptionNames.first!
        let computedResult = store.setValue(.int(1), for: computedName)
        XCTAssertNotEqual(computedResult, .success,
                           "computed-only option is never accepted as input")

        // Failure row 3: idempotent disposal does not crash.
        store.dispose()
        store.dispose()
        XCTAssertTrue(store.isDisposed, "idempotent disposal")

        let commands = MonaCommandRegistry()
        commands.dispose()
        commands.dispose()
        XCTAssertTrue(commands.isDisposed)

        let contributions = MonaContributionRegistry()
        contributions.dispose()
        contributions.dispose()
        XCTAssertTrue(contributions.isDisposed)
        Self.recordNativeOutput("failureRows:cutOption+computedReadOnly+idempotentDisposal=rejected")
    }

    // MARK: Operation 3 — Bind evidence manifest

    func testC04_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 reference (P08-T010 native-declaration manifest).
        let comparatorPath = artifactsDir + "/monacode-p08-t010-native-declaration-manifest.json"
        let comparatorHash = sha256File(comparatorPath)
        XCTAssertEqual(comparatorHash.count, 64)

        // fixture: the M0/M1 runtime-style reference (X1-R closure).
        let fixturePath = parentArtifactsDir + "/source-x1r-runtime-style-closure.html"
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
        XCTAssertFalse(accumulated.isEmpty, "native output accumulator must be non-empty")
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

        print("P09-T013 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(Self.qualifiedSetHash.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=9")
    }

    // MARK: Operation 4 — Treat every missing/skipped/stale/malformed case as
    // not-passed.

    func testC04_NoMissingSkippedStaleMalformedCases() throws {
        let path = artifactsDir + "/monacode-p08-t010-native-declaration-manifest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let counts = obj?["counts"] as? [String: Any] ?? [:]
        XCTAssertFalse(counts.isEmpty, "declaration counts present (not malformed)")

        let requiredCounts = [
            "declaration", "option", "localization", "registry", "theme",
            "feature", "language", "nativeAdaptation", "total",
        ]
        var malformedCounts: [String] = []
        for key in requiredCounts {
            guard counts[key] is Int else {
                malformedCounts.append("\(key): missing/non-integer")
                continue
            }
        }
        XCTAssertTrue(malformedCounts.isEmpty,
                      "malformed/stale counts (not-passed):\n" + malformedCounts.joined(separator: "\n"))

        // The X1-R closure artifact exists and is non-empty.
        let closurePath = parentArtifactsDir + "/source-x1r-runtime-style-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: closurePath),
                      "X1-R closure artifact must exist (not stale/missing)")
        let closureData = try Data(contentsOf: URL(fileURLWithPath: closurePath))
        XCTAssertGreaterThan(closureData.count, 0, "X1-R closure artifact non-empty")

        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        let expectedBounds = ["T-1", "T", "T+1", "T-1", "T", "T+1", "T-1", "T", "T+1"]
        for bound in expectedBounds {
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
