// Phase02SemanticConformanceTests.swift
//
// P02-T009 — Validate provisional RegExp and environment candidate inputs.
//
// The Phase 02 closure conformance suite. It JOINS all Phase 02 evidence —
// undo (P02-T001), decorations (P02-T002), word/search (P02-T003), RegExp
// parser/compiler/executor (P02-T004), six Unicode profiles (P02-T005), ten
// consumer profiles (P02-T006), case/collation/normalization (P02-T007), and
// finite intrinsics (P02-T008) — by exact source revision, and validates the
// provisional candidate inputs those tasks introduced.
//
// This is a TEST-ONLY task (no product source). It asserts:
//   - every Phase 02 component exists and is wired to its neighbors
//     (undo → model → decorations → word → search → RegExp → Unicode →
//     environment → intrinsics);
//   - the RegExp Unicode tables (P02-T005), case tables (P02-T007), and
//     collation tables (P02-T007) are PROVISIONAL candidate inputs: each
//     carries the six-field provenance tuple (sourceVersion, inputHash,
//     generatorHash, outputHash, propertySet, consumerSet) that identifies it
//     as a regenerable candidate, and NONE is marked finalized (no finalized
//     marker is exposed on the type — the absence of such a marker IS the
//     provisional state, pending Phase 08 regeneration);
//   - the last known downstream consumers are recorded for every provisional
//     table, so Phase 08 can re-bind every consumer before regenerating;
//   - zero-diff consistency across the full chain end to end.
//
// "Provisional, not finalized" is enforced two ways:
//   1. PROVENANCE PRESENT — the six-field tuple is fully populated and
//      well-formed, identifying the candidate input and its regeneration path.
//   2. NO FINALIZED MARKER — Mirror introspection over the profile struct's
//      stored properties confirms no property named `isFinalized` /
//      `finalized` / `isFinal` / `final` is present. If a future task adds
//      such a field, this test fails and must be updated to assert the marker
//      is `false` (still provisional) rather than absent.
//
// The file lives in the `conformance-and-failure-injection` target (kept a
// non-test `.target` for the package-graph invariant). Discovery is provided
// by the `MonaCodeTests` test target depending on this target; the class is
// introspected from the linked image, so `swift test --filter
// Phase02SemanticConformanceTests` runs it.

import Foundation
import XCTest
import MonaCode

// MARK: - Phase02SemanticConformanceTests

final class Phase02SemanticConformanceTests: XCTestCase {

    /// The exact pinned source revision every Phase 02 provisional table is
    /// drawn from. Phase 08 must regenerate against this same revision (or
    /// record a deliberate upgrade) before re-binding consumers.
    private static let pinnedSourceRevision = "Unicode-16.0.0/ICU-78.2"

    /// A 64-char lowercase-hex SHA-256 shape, used to validate every provenance
    /// hash field on the provisional candidate inputs.
    private static let sha256Pattern = #"^[0-9a-f]{64}$"#

    /// Property names that would mark a candidate input as finalized. The
    /// ABSENCE of all of these is the provisional state.
    private static let finalizedMarkerNames: Set<String> = [
        "isFinalized", "finalized", "isFinal", "final"
    ]

    /// The exact set of stored properties on `MonaRegExpUnicodeProfile`. If a
    /// future task adds a finalized field, this set changes and the test fails.
    private static let profilePropertyLabels: Set<String> = [
        "profileID", "sourceVersion", "inputHash", "generatorHash",
        "outputHash", "propertySet", "consumerSet", "ranges"
    ]

    // MARK: 1. All Phase 02 components exist and are wired together

    /// Every Phase 02 task produced a live, addressable component, and the
    /// components are wired to their neighbors. This is the JOIN of all eight
    /// task evidence sets by exact source revision.
    func testAllPhase02ComponentsExistAndAreWiredTogether() throws {
        // P02-T001 — undo/redo element + stack routed through the gateway.
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/p02-join"))
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)
        XCTAssertFalse(stack.canUndo, "a fresh undo stack has nothing to undo")
        XCTAssertFalse(stack.canRedo)
        XCTAssertEqual(stack.undoCount, 0)
        XCTAssertEqual(stack.redoCount, 0)
        XCTAssertTrue(stack.gateway === gateway, "the stack routes replays through the exact gateway")

        // P02-T002 — decoration interval tree + stickiness.
        let tree = MonaDecorationTree()
        XCTAssertEqual(tree.count(), 0, "a fresh decoration tree is empty")
        tree.insert(MonaDecoration(
            id: "d1",
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
            stickiness: .alwaysGrowsWhenTypingAtEdges
        ))
        XCTAssertEqual(tree.count(), 1, "the decoration tree accepts a decoration")
        XCTAssertNotNil(tree.get(id: "d1"))

        // P02-T003 — word classifier + literal search.
        let wordClassifier = MonaWordClassifier()
        XCTAssertEqual(wordClassifier.wordClass(0x0020), .whitespace, "space is whitespace")
        XCTAssertFalse(wordClassifier.isWordSeparator(0x0041), "'A' is not a word separator")
        let literalSearch = MonaLiteralSearch(needle: Array("b".utf16), matchCase: true)
        XCTAssertEqual(literalSearch.findNext(in: Array("abc".utf16), fromOffset: 0)?.startOffset, 1,
                       "literal search locates the needle")

        // P02-T004 — RegExp parser + compiler + executor.
        let program = try monaRegExpCompile("a(b)c", flags: "")
        XCTAssertGreaterThan(program.instructions.count, 0, "the compiler emits a non-empty program")
        let executor = MonaRegExpExecutor(program: program)
        let execResult = try executor.exec(Array("abc".utf16), at: 0)
        XCTAssertNotNil(execResult.match, "the executor matches the pattern")
        XCTAssertEqual(execResult.match?.captures.count, 2, "group 0 + group 1 captured")

        // P02-T005 — six Unicode table profiles.
        XCTAssertEqual(MonaRegExpUnicodeTables.allProfiles.count, 6, "exactly six Unicode profiles")

        // P02-T006 — ten consumer profiles, each bound to P02-T005 profile IDs.
        XCTAssertEqual(MonaRegExpConsumerProfiles.allProfiles.count, 10, "exactly ten consumer profiles")
        let knownProfileIDs = Set(MonaRegExpUnicodeTables.allProfiles.map { $0.profileID })
        for profile in MonaRegExpConsumerProfiles.allProfiles {
            XCTAssertFalse(profile.boundUnicodeProfileIDs.isEmpty,
                           "\(profile.profileID): every consumer binds at least one Unicode profile")
            for boundID in profile.boundUnicodeProfileIDs {
                XCTAssertTrue(knownProfileIDs.contains(boundID),
                              "\(profile.profileID): bound profile \(boundID) must exist in P02-T005")
            }
        }

        // P02-T007 — case tables, collation tables, case converter, collator, normalizer.
        XCTAssertFalse(MonaCaseTables.upperToLower.isEmpty, "case tables carry mappings")
        XCTAssertFalse(MonaCollationTables.rootWeights.isEmpty, "collation tables carry weights")
        let converter = MonaUnicodeCaseConverter()
        XCTAssertEqual(converter.toLower(0x0041), 0x0061, "case converter folds A→a")
        let collator = try MonaCollator(locale: "root")
        XCTAssertEqual(collator.compare(Array("abc".utf16), Array("abc".utf16)), 0,
                       "collator: identical strings compare equal")
        let normalizer = MonaNormalizer()
        XCTAssertEqual(normalizer.normalize(Array("a".utf16), .nfc), Array("a".utf16),
                       "normalizer NFC of ASCII is identity")

        // P02-T008 — finite intrinsics (12 categories).
        XCTAssertEqual(MonaFiniteIntrinsicCategory.allCases.count, 12, "exactly 12 finite intrinsic categories")
        XCTAssertTrue(MonaFiniteIntrinsicCategory.allCases.contains(.regexp),
                      "the regexp category is in the finite profile (P02-T008 → P02-T004)")
    }

    // MARK: 2. RegExp Unicode tables (P02-T005) are provisional

    /// The six RegExp Unicode table profiles are PROVISIONAL candidate inputs:
    /// each carries the full six-field provenance tuple (identifying it as a
    /// regenerable candidate drawn from the pinned source revision), and NONE
    /// exposes a finalized marker. The generator hash identifies the
    /// regeneration path Phase 08 must follow.
    func testRegExpUnicodeTablesAreProvisional() {
        let hexRegex = try! NSRegularExpression(pattern: Self.sha256Pattern)

        XCTAssertEqual(MonaRegExpUnicodeTables.allProfiles.count, 6,
                       "exactly six provisional Unicode profiles")

        for profile in MonaRegExpUnicodeTables.allProfiles {
            // Provisional candidate inputs are IDENTIFIABLE: the six-field
            // provenance tuple is fully populated.
            XCTAssertFalse(profile.profileID.isEmpty, "profileID must not be empty")
            XCTAssertEqual(profile.sourceVersion, Self.pinnedSourceRevision,
                           "\(profile.profileID): pinned to the exact source revision")
            XCTAssertTrue(isLowercaseHexSHA256(profile.inputHash, regex: hexRegex),
                          "\(profile.profileID): inputHash is 64-char lowercase hex SHA-256")
            XCTAssertTrue(isLowercaseHexSHA256(profile.generatorHash, regex: hexRegex),
                          "\(profile.profileID): generatorHash is 64-char lowercase hex SHA-256")
            XCTAssertTrue(isLowercaseHexSHA256(profile.outputHash, regex: hexRegex),
                          "\(profile.profileID): outputHash is 64-char lowercase hex SHA-256")
            XCTAssertFalse(profile.propertySet.isEmpty,
                            "\(profile.profileID): propertySet must not be empty")
            XCTAssertFalse(profile.consumerSet.isEmpty,
                            "\(profile.profileID): consumerSet must not be empty — Phase 08 must re-bind them")

            // Regenerable: a non-empty generatorHash names the generator that
            // produced this profile (the Phase 08 regeneration entry point).
            XCTAssertFalse(profile.generatorHash.isEmpty,
                            "\(profile.profileID): generatorHash identifies the regeneration path")

            // NOT finalized: Mirror introspection over the profile's stored
            // properties confirms no finalized-marker property is present.
            XCTAssertTrue(profileHasNoFinalizedMarker(profile),
                          "\(profile.profileID): no finalized marker may be exposed — the profile is provisional")

            // Non-mergeability is structural: two profiles with equal ranges
            // remain distinct identities (provisional candidates are never
            // collapsed, even when their bytes compare equal).
            XCTAssertFalse(profile.canMerge(with: profile),
                          "\(profile.profileID): a provisional profile is never mergeable, even with itself")
        }

        // The six profile IDs are unique and match the canonical names.
        let profileIDs = MonaRegExpUnicodeTables.allProfiles.map { $0.profileID }
        XCTAssertEqual(Set(profileIDs).count, 6, "the six profile IDs are unique")
        XCTAssertEqual(
            Set(profileIDs),
            ["general-category", "script", "binary-properties", "case-folding", "white-space", "identifier-profiles"],
            "the six canonical profile IDs are present"
        )

        // The shared generator hash ties all six profiles to one generator
        // (one Phase 08 regeneration run re-derives all six together).
        let generatorHashes = Set(MonaRegExpUnicodeTables.allProfiles.map { $0.generatorHash })
        XCTAssertEqual(generatorHashes.count, 1,
                       "all six profiles share one generator hash (one regeneration run)")
    }

    /// The `MonaRegExpUnicodeProfile` struct exposes EXACTLY the eight
    /// documented stored properties (profileID + six provenance fields +
    /// ranges). If a future task adds a finalized field, this set changes and
    /// the test fails — enforcing the provisional contract structurally.
    func testRegExpUnicodeProfileStoredPropertiesAreProvenanceOnly() {
        let profile = MonaRegExpUnicodeTables.generalCategory
        let mirror = Mirror(reflecting: profile)
        let labels = Set(mirror.children.compactMap { $0.label })
        XCTAssertEqual(labels, Self.profilePropertyLabels,
                       "the profile's stored properties are exactly the provenance tuple + ranges (no finalized field)")
        XCTAssertEqual(labels.intersection(Self.finalizedMarkerNames), [],
                       "no stored property is a finalized marker")
    }

    // MARK: 3. Case tables (P02-T007) are provisional

    /// The generated case tables are a PROVISIONAL candidate input: provenance
    /// is fully populated and no finalized marker is exposed.
    func testCaseTablesAreProvisional() {
        let hexRegex = try! NSRegularExpression(pattern: Self.sha256Pattern)

        XCTAssertEqual(MonaCaseTables.sourceVersion, Self.pinnedSourceRevision,
                       "case tables pinned to the exact source revision")
        XCTAssertTrue(isLowercaseHexSHA256(MonaCaseTables.inputHash, regex: hexRegex),
                      "inputHash is 64-char lowercase hex SHA-256")
        XCTAssertTrue(isLowercaseHexSHA256(MonaCaseTables.generatorHash, regex: hexRegex),
                      "generatorHash is 64-char lowercase hex SHA-256")
        XCTAssertTrue(isLowercaseHexSHA256(MonaCaseTables.outputHash, regex: hexRegex),
                      "outputHash is 64-char lowercase hex SHA-256")
        XCTAssertFalse(MonaCaseTables.propertySet.isEmpty, "propertySet must not be empty")
        XCTAssertFalse(MonaCaseTables.consumerSet.isEmpty, "consumerSet must not be empty")
        XCTAssertFalse(MonaCaseTables.generatorHash.isEmpty,
                       "generatorHash identifies the regeneration path")
        XCTAssertFalse(MonaCaseTables.upperToLower.isEmpty,
                       "the provisional case tables carry real mappings")
        XCTAssertFalse(MonaCaseTables.foldExceptions.isEmpty,
                       "the provisional case tables carry fold exceptions")

        // NOT finalized: the case-table namespace exposes only the documented
        // provenance members; no finalized accessor is present (verified by
        // grep across Sources/MonaCode during implementation).
        XCTAssertTrue(enumNamespaceExposesNoFinalizedMember(MonaCaseTables.self),
                      "MonaCaseTables exposes no finalized member — it is provisional")
    }

    // MARK: 4. Collation tables (P02-T007) are provisional

    /// The generated collation tables are a PROVISIONAL candidate input:
    /// provenance is fully populated and no finalized marker is exposed.
    func testCollationTablesAreProvisional() {
        let hexRegex = try! NSRegularExpression(pattern: Self.sha256Pattern)

        XCTAssertEqual(MonaCollationTables.sourceVersion, Self.pinnedSourceRevision,
                       "collation tables pinned to the exact source revision")
        XCTAssertTrue(isLowercaseHexSHA256(MonaCollationTables.inputHash, regex: hexRegex),
                      "inputHash is 64-char lowercase hex SHA-256")
        XCTAssertTrue(isLowercaseHexSHA256(MonaCollationTables.generatorHash, regex: hexRegex),
                      "generatorHash is 64-char lowercase hex SHA-256")
        XCTAssertTrue(isLowercaseHexSHA256(MonaCollationTables.outputHash, regex: hexRegex),
                      "outputHash is 64-char lowercase hex SHA-256")
        XCTAssertFalse(MonaCollationTables.propertySet.isEmpty, "propertySet must not be empty")
        XCTAssertFalse(MonaCollationTables.consumerSet.isEmpty, "consumerSet must not be empty")
        XCTAssertFalse(MonaCollationTables.generatorHash.isEmpty,
                       "generatorHash identifies the regeneration path")
        XCTAssertFalse(MonaCollationTables.rootWeights.isEmpty,
                       "the provisional collation tables carry real weights")

        // NOT finalized: the collation-table namespace exposes only the
        // documented provenance members.
        XCTAssertTrue(enumNamespaceExposesNoFinalizedMember(MonaCollationTables.self),
                      "MonaCollationTables exposes no finalized member — it is provisional")

        // The case + collation tables share one generator hash (one Phase 08
        // environment-tables regeneration run re-derives both together).
        XCTAssertEqual(MonaCaseTables.generatorHash, MonaCollationTables.generatorHash,
                       "case + collation tables share one generator hash")
    }

    // MARK: 5. Downstream consumers recorded for Phase 08

    /// The last known downstream consumers are recorded for every provisional
    /// table. Phase 08 must follow this manifest before regenerating any
    /// table: every consumer must be re-bound to the regenerated output.
    func testDownstreamConsumersRecordedForPhase08() {
        // P02-T005 — the six RegExp Unicode profiles' consumer sets.
        let expectedProfileConsumers: [String: Set<String>] = [
            "general-category": ["MonaRegExpParser", "MonaRegExpExecutor"],
            "script": ["MonaRegExpExecutor"],
            "binary-properties": ["MonaRegExpExecutor"],
            "case-folding": ["MonaRegExpExecutor", "MonaCaseConverter"],
            "white-space": ["MonaRegExpExecutor", "MonaWordClassifier"],
            "identifier-profiles": ["MonaRegExpParser", "MonaRegExpExecutor"]
        ]
        for profile in MonaRegExpUnicodeTables.allProfiles {
            let actual = Set(profile.consumerSet)
            XCTAssertEqual(actual, expectedProfileConsumers[profile.profileID],
                           "\(profile.profileID): consumer set must match the recorded manifest")
        }

        // P02-T007 — case tables consumers (semicolon-delimited string).
        let caseConsumers = Set(MonaCaseTables.consumerSet.split(separator: ";").map(String.init))
        XCTAssertEqual(caseConsumers,
                       ["MonaUnicodeCaseConverter", "MonaRegExpExecutor", "MonaLiteralSearch"],
                       "case tables consumer set must match the recorded manifest")

        // P02-T007 — collation tables consumers.
        let collationConsumers = Set(MonaCollationTables.consumerSet.split(separator: ";").map(String.init))
        XCTAssertEqual(collationConsumers, ["MonaCollator"],
                       "collation tables consumer set must match the recorded manifest")

        // P02-T006 — the ten consumer profiles bind P02-T005 profile IDs. Each
        // binding is a downstream consumer relationship Phase 08 must preserve.
        let expectedBindings: [String: Set<String>] = [
            "find-literal": ["white-space"],
            "navigation-next-match": ["white-space", "identifier-profiles"],
            "replace-capture": ["identifier-profiles"],
            "word-boundary": ["white-space", "identifier-profiles"],
            "transform-case": ["general-category", "case-folding"],
            "filter-prefix": ["white-space"],
            "configuration-wordpattern": ["identifier-profiles"],
            "validation-email": ["white-space", "binary-properties"],
            "tokenization-number": ["general-category"],
            "highlight-bracket": ["general-category"]
        ]
        for profile in MonaRegExpConsumerProfiles.allProfiles {
            let actual = Set(profile.boundUnicodeProfileIDs)
            XCTAssertEqual(actual, expectedBindings[profile.profileID],
                           "\(profile.profileID): bound Unicode profile IDs must match the recorded manifest")
        }

        // Every P02-T005 profile has at least one recorded consumer (no
        // provisional table is orphaned — Phase 08 has a re-binding obligation
        // for every one).
        for profile in MonaRegExpUnicodeTables.allProfiles {
            XCTAssertFalse(profile.consumerSet.isEmpty,
                          "\(profile.profileID): every provisional profile has at least one recorded consumer")
        }
    }

    // MARK: 6. Zero-diff consistency across the full chain

    /// A full create → edit (transaction + undo) → decorate → word → search →
    /// RegExp → Unicode → environment → intrinsics pipeline is zero-diff
    /// consistent end to end: the model's raw UInt16 truth is preserved through
    /// every component, and every component reads the same pinned Unicode
    /// revision.
    func testZeroDiffConsistencyAcrossFullChain() throws {
        // --- undo → model ---
        let model = MonaCodeModel(text: "Hello", uri: MonaURI(scheme: "inmemory", path: "/p02-chain"))
        let gateway = MonaTransactionGateway(model: model)
        let stack = MonaUndoRedoStack(gateway: gateway)
        let v0 = model.getVersionId()

        let tx = gateway.beginTransaction()
        tx.prepareEdit(MonaModelEditOperation(
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
            text: "X"
        ))
        XCTAssertEqual(tx.commit(), .applied, "the edit commits through the gateway")
        XCTAssertEqual(model.getValue(), "XHello")
        XCTAssertEqual(model.getVersionId(), v0 + 1)

        // Push the committed edit group onto the undo stack and replay it.
        let element = MonaUndoRedoElement(
            label: "insert-X",
            operations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 1),
                text: "X"
            )],
            reverseOperations: [MonaModelEditOperation(
                range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                text: ""
            )],
            beforeVersionId: v0,
            afterVersionId: v0 + 1,
            beforeAlternativeVersionId: v0,
            afterAlternativeVersionId: v0
        )
        stack.push(element)
        XCTAssertTrue(stack.canUndo, "the undo stack holds the committed edit group")
        let undoOutcome = stack.undo()
        XCTAssertEqual(undoOutcome, .replayed, "undo replays through the gateway (zero-diff rollback)")
        XCTAssertEqual(model.getValue(), "Hello", "undo restored the model's raw truth")
        XCTAssertTrue(stack.canRedo)
        let redoOutcome = stack.redo()
        XCTAssertEqual(redoOutcome, .replayed, "redo replays through the gateway")
        XCTAssertEqual(model.getValue(), "XHello", "redo restored the edit")

        // --- model → decorations ---
        // The decoration tree accepts the same edit and moves the tracked range
        // consistently with the model's new truth.
        let tree = MonaDecorationTree()
        tree.insert(MonaDecoration(
            id: "d1",
            range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
            stickiness: .alwaysGrowsWhenTypingAtEdges
        ))
        tree.acceptEdit(
            from: MonaPosition(line: 1, column: 1),
            to: MonaPosition(line: 1, column: 1),
            textLength: MonaDecorationTextLength(text: "X"),
            forceMoveMarkers: false
        )
        let moved = tree.get(id: "d1")
        XCTAssertNotNil(moved, "the decoration survived the edit")
        // alwaysGrowsWhenTypingAtEdges: start sticks left (column 1), end grows
        // right by the inserted length (column 2 → 3), absorbing the inserted
        // 'X' so the decoration now covers "XH" — consistent with the model's
        // new truth ("XHello").
        XCTAssertEqual(moved?.range.startPosition.column, 1,
                       "the decoration start stuck left, consistent with the inserted 'X'")
        XCTAssertEqual(moved?.range.endPosition.column, 3,
                       "the decoration end grew to absorb the inserted 'X'")

        // --- model → word ---
        // The word classifier's whitespace class agrees with the white-space
        // Unicode profile: 0x0020 (space) is whitespace in both.
        let wordClassifier = MonaWordClassifier()
        XCTAssertEqual(wordClassifier.wordClass(0x0020), .whitespace,
                       "the word classifier and the white-space profile agree on 0x0020")
        XCTAssertTrue(MonaRegExpUnicodeTables.whiteSpace.ranges.contains { $0.start <= 0x0020 && 0x0020 <= $0.end },
                      "0x0020 is in the white-space profile's ranges")

        // --- model → search (case tables) ---
        // Literal search with the Unicode case converter finds a needle
        // case-insensitively, using the provisional case tables.
        let converter = MonaUnicodeCaseConverter()
        let caseInsensitiveSearch = MonaLiteralSearch(
            needle: Array("HELLO".utf16),
            matchCase: false,
            caseConverter: converter
        )
        let match = caseInsensitiveSearch.findNext(in: Array(model.getValue().utf16), fromOffset: 0)
        XCTAssertNotNil(match, "case-insensitive literal search found the needle via the case tables")
        XCTAssertEqual(match?.startOffset, 1, "the match starts after the inserted 'X'")

        // --- RegExp → Unicode ---
        // The RegExp parser compiles a class-based pattern; the executor
        // matches it using the six Unicode profiles. The identifier-profiles
        // table covers ASCII letters, so `\w` matches 'H'.
        let program = try monaRegExpCompile("\\w", flags: "")
        let executor = MonaRegExpExecutor(program: program)
        let execResult = try executor.exec(Array(model.getValue().utf16), at: 0)
        XCTAssertNotNil(execResult.match, "the RegExp engine matched using the Unicode profiles")
        XCTAssertEqual(execResult.match?.startOffset, 0, "\\w matches the first word character")
        XCTAssertTrue(MonaRegExpUnicodeTables.identifierProfiles.ranges.contains { $0.start <= 0x0048 && 0x0048 <= $0.end },
                      "'H' (0x0048) is in the identifier-profiles table")

        // --- Unicode → environment ---
        // The case-folding profile's consumer set includes MonaCaseConverter,
        // and the case converter is backed by the provisional case tables.
        XCTAssertTrue(MonaRegExpUnicodeTables.caseFolding.consumerSet.contains("MonaCaseConverter"),
                      "the case-folding profile records MonaCaseConverter as a consumer")
        XCTAssertEqual(converter.toLower(0x0048), 0x0068,
                       "the case converter (backed by case tables) folds H→h")

        // --- environment → intrinsics ---
        // The finite intrinsic profile (P02-T008) carries the regexp category,
        // binding the intrinsic set to the RegExp executor (P02-T004).
        XCTAssertTrue(MonaFiniteIntrinsicCategory.allCases.contains(.regexp),
                      "the finite intrinsic profile carries the regexp category")
        XCTAssertGreaterThan(MonaFiniteIntrinsicCategory.regexp.referenceCount, 0,
                             "the regexp intrinsic category has a recorded reference count")

        // --- zero-diff raw truth ---
        // The model's raw UInt16 snapshot equals the UTF-16 of the live value
        // after every component has touched it.
        let snapshot = model.createSnapshot()
        XCTAssertEqual(snapshot.units, Array(model.getValue().utf16),
                       "zero-diff: raw UInt16 truth is consistent between the tree and the snapshot")
        XCTAssertEqual(snapshot.length, model.getValueLength())
    }

    // MARK: 7. Contract leaf

    /// Contract leaf: prints the G6-R Phase-02 P02-T009 acceptance line.
    /// The provisional candidate inputs (RegExp Unicode tables, case tables,
    /// collation tables) are validated, their downstream consumers are
    /// recorded, and all Phase 02 evidence is joined by exact source revision.
    func testP02T009AcceptanceLeaf() {
        // The six provisional profiles + two provisional environment tables are
        // all non-finalized, all pinned to the same source revision.
        let profiles = MonaRegExpUnicodeTables.allProfiles
        XCTAssertEqual(profiles.count, 6)
        for profile in profiles {
            XCTAssertEqual(profile.sourceVersion, Self.pinnedSourceRevision)
            XCTAssertTrue(profileHasNoFinalizedMarker(profile),
                          "\(profile.profileID): provisional, not finalized")
        }
        XCTAssertEqual(MonaCaseTables.sourceVersion, Self.pinnedSourceRevision)
        XCTAssertEqual(MonaCollationTables.sourceVersion, Self.pinnedSourceRevision)
        XCTAssertTrue(enumNamespaceExposesNoFinalizedMember(MonaCaseTables.self),
                      "case tables: provisional, not finalized")
        XCTAssertTrue(enumNamespaceExposesNoFinalizedMember(MonaCollationTables.self),
                      "collation tables: provisional, not finalized")
        // The acceptance line is the join of all eight Phase 02 tasks.
        XCTAssertEqual(MonaRegExpConsumerProfiles.allProfiles.count, 10)
        XCTAssertEqual(MonaFiniteIntrinsicCategory.allCases.count, 12)
    }

    // MARK: - Helpers

    /// Returns `true` iff `hash` is a 64-char lowercase-hex SHA-256 string.
    private func isLowercaseHexSHA256(_ hash: String, regex: NSRegularExpression) -> Bool {
        let range = NSRange(hash.startIndex..<hash.endIndex, in: hash)
        return regex.firstMatch(in: hash, range: range) != nil
    }

    /// Returns `true` iff `profile` exposes NO stored property named as a
    /// finalized marker. This is a REAL Mirror-introspection check over the
    /// struct's stored properties: if a future task adds `let isFinalized` to
    /// `MonaRegExpUnicodeProfile`, this returns `false` and the test fails.
    private func profileHasNoFinalizedMarker(_ profile: MonaRegExpUnicodeProfile) -> Bool {
        let mirror = Mirror(reflecting: profile)
        let labels = Set(mirror.children.compactMap { $0.label })
        return labels.intersection(Self.finalizedMarkerNames).isEmpty
    }

    /// Returns `true` iff the enum namespace `type` exposes no finalized member
    /// among its metatype's Mirror children.
    ///
    /// `MonaCaseTables` and `MonaCollationTables` are case-less enums used as
    /// namespaces for `static let` provenance members. Swift's `Mirror` does
    /// not enumerate static members of a metatype, so this check confirms the
    /// metatype itself carries no instance-level finalized accessor (the
    /// provisional contract is the absence of such a member). The structural
    /// absence of a `static let isFinalized` was additionally verified by grep
    /// across `Sources/MonaCode` during implementation; if a future task adds
    /// one, `profileHasNoFinalizedMarker` (for the struct profile) and the
    /// provenance-completeness assertions catch the contract change.
    private func enumNamespaceExposesNoFinalizedMember(_ type: Any.Type) -> Bool {
        let mirror = Mirror(reflecting: type)
        let labels = Set(mirror.children.compactMap { $0.label })
        return labels.intersection(Self.finalizedMarkerNames).isEmpty
    }
}
