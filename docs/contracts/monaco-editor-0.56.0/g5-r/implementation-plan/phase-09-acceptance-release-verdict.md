# Phase 09: Acceptance and release verdict

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 08.

Task count: 30.

<!-- monacode-plan-task:{"id":"P09-T001","recordSha256":"c7a63fcde054bd52e5075de29e36d8606b8fd5e1331a5a16759ac698e40b407c"} -->
## P09-T001 — Recollect and finalize the per-run privacy-filtered QEnvironmentID

Contract: `G5-R.currentLocalEnvironment`, `Q1-R4.environmentIdentity`, `Q1-R5.preflight`, `G5-R.validationScope.privacy`

Dependencies:
- `P08-T016`

Ownership selectors:
- `candidate-finalizer:QEnvironmentID.json`

Files to create:
- `Tools/Qualification/finalize-qenvironment.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/FormalQEnvironmentPreflightTests.mjs`

Interfaces consumed:
- `QEnvironmentIDPreflight`
- `MonaStaticCandidateSet`

Interfaces produced:
- `QEnvironmentID.json`

Red verification:
- Run: `node --test Tests/PlanStructureTests/FormalQEnvironmentPreflightTests.mjs --test-name-pattern external-display`
  - Expected exit: `1`
  - Expected output includes: `QENVIRONMENT_FORMAL_RUN_REJECTED externalDisplayCount=1 required=0`

Minimal implementation operations:
- `Collect a fresh environment identity immediately before each formal run.`
- `Require macOS build 25G83, Chrome 151.0.7922.170 with pinned binary and ICU hashes, arm64, built-in display only, zero external displays, exact 60 or 120 Hz cell, required ABC and SCIM.ITABC input sources, runtime locale fields, and manifest-approved fonts.`
- `Recursively reject serial, account, user, UUID, UDID, raw identity keys, and UUID-shaped values in every produced artifact.`
- `Bind the environment, six static candidate hashes, source revision, and run nonce-free identifier by SHA-256.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/FormalQEnvironmentPreflightTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `CANDIDATE_FINAL name=QEnvironmentID.json build=25G83 chrome=151.0.7922.170 externalDisplays=0 privacy=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T001.json`

Completion assertions:
- `QEnvironmentID is fresh for the formal run.`
- `Every qualification predicate is exact.`
- `No forbidden identity field or value is persisted.`

Commit boundary:
- `Tools/Qualification/finalize-qenvironment.mjs`
- `Tests/PlanStructureTests/FormalQEnvironmentPreflightTests.mjs`

<!-- monacode-plan-task:{"id":"P09-T002","recordSha256":"bd39ba507b19b345f13fc4a3c45d4e17082f689c3f311d3044516bed803160e1"} -->
## P09-T002 — Join all seven candidates into one qualified acceptance set

Contract: `G5-R.candidateGeneratedArtifacts`, `Q1-R5.candidateJoin`

Dependencies:
- `P08-T016`
- `P09-T001`

Ownership selectors:
- `candidate-consumer:MonaNativeDeclarationManifest.json`
- `candidate-consumer:MonaRegExpUnicodeManifest.json`
- `candidate-consumer:MonaEnvironmentManifest.json`
- `candidate-consumer:MonaSourceClosureManifest.json`
- `candidate-consumer:MonaCacheManifest.json`
- `candidate-consumer:MonaDistributionManifest.json`
- `candidate-consumer:QEnvironmentID.json`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/QualifiedCandidateSetTests.mjs`

Interfaces consumed:
- `MonaStaticCandidateSet`
- `QEnvironmentID.json`

Interfaces produced:
- `MonaQualifiedCandidateSet`

Red verification:
- Run: `node --test Tests/PlanStructureTests/QualifiedCandidateSetTests.mjs --test-name-pattern mixed-revision`
  - Expected exit: `1`
  - Expected output includes: `QUALIFIED_CANDIDATE_SET_INVALID reason=mixed-source-revision`

Minimal implementation operations:
- `Require exactly seven candidate names and validate every schema, hash, source revision, environment predicate, dependency edge, and mutual reference.`
- `Reject stale, duplicate, extra, mixed-revision, pre-environment, or post-source-change artifacts.`
- `Emit one qualified set hash consumed unchanged by every C/P and cross-cutting task.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/QualifiedCandidateSetTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `QUALIFIED_CANDIDATE_SET count=7 sourceRevisions=1 environments=1`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T002.json`

Completion assertions:
- `Exactly seven mutually consistent candidates join.`
- `All acceptance tasks consume one immutable set hash.`
- `No product source changes after qualification.`

Commit boundary:
- `Tests/PlanStructureTests/QualifiedCandidateSetTests.mjs`

<!-- monacode-plan-task:{"id":"P09-T010","recordSha256":"104ad6892d514340c33170479ac35ec5d61b0e799b0ebc9955740dad279df00b"} -->
## P09-T010 — Run C01: model and exact semantic equivalence

Contract: `G5-R.acceptance.correctnessGates.C01`, `Q1-R5`, `C01`

Dependencies:
- `P09-T002`
- `P01-T013`
- `P02-T009`

Ownership selectors:
- `correctnessGate:C01`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C01Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C01Evidence`

Red verification:
- Run: `swift test --filter C01Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C01`

Minimal implementation operations:
- `Compare base values, URI, raw UTF-16 Piece Tree, 70 model members, transactions, undo, decorations, search, RegExp, and Unicode outputs against M0 and M1.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C01Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C01 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T010.json`

Completion assertions:
- `C01 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C01Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T011","recordSha256":"db7dee53fcd94f7106842693e17ac827eb0052c0e624a231382845e8f8b9bce9"} -->
## P09-T011 — Run C02: environment, locale, clock, entropy, and intrinsic equivalence

Contract: `G5-R.acceptance.correctnessGates.C02`, `Q1-R5`, `C02`

Dependencies:
- `P09-T002`
- `P00-T012`
- `P02-T009`

Ownership selectors:
- `correctnessGate:C02`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C02Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C02Evidence`

Red verification:
- Run: `swift test --filter C02Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C02`

Minimal implementation operations:
- `Replay identical wall-clock, high-resolution clock, entropy, locale, case, collation, normalization, number, codec, and hash traces across M0, M1, and native.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C02Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C02 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T011.json`

Completion assertions:
- `C02 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C02Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T012","recordSha256":"a8aef19bade4e0904fccd46b8fe7f9cf3e02b3747760a030005d4c0f8e3898d1"} -->
## P09-T012 — Run C03: projection, layout, scroll, and geometry equivalence

Contract: `G5-R.acceptance.correctnessGates.C03`, `Q1-R5`, `C03`

Dependencies:
- `P09-T002`
- `P03-T012`

Ownership selectors:
- `correctnessGate:C03`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C03Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C03Evidence`

Red verification:
- Run: `swift test --filter C03Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C03`

Minimal implementation operations:
- `Compare projection, wrapping, folding, injected text, vertical indexes, scroll order, shaping, raw-offset geometry, stamps, and bounded failure behavior.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C03Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C03 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T012.json`

Completion assertions:
- `C03 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C03Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T013","recordSha256":"84f5e9a945d8fd1b9c20f38fb1587941bbea63375fc0f18d23e59b045697fb7f"} -->
## P09-T013 — Run C04: public declarations, registries, options, themes, localization, and runtime-style closure

Contract: `G5-R.acceptance.correctnessGates.C04`, `Q1-R5`, `C04`

Dependencies:
- `P09-T002`
- `P05-T200`
- `P07-T008`

Ownership selectors:
- `correctnessGate:C04`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C04Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C04Evidence`

Red verification:
- Run: `swift test --filter C04Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C04`

Minimal implementation operations:
- `Validate all 555 public paths, registry identities, option boundaries, theme assets, 2120 messages, native type adaptations, and X1-R occurrence sets.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C04Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C04 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T013.json`

Completion assertions:
- `C04 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C04Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T014","recordSha256":"3d78682cf0f59ae976d3de4d4392d06ca2188d7be82362b49ae8acd1f11b9a60"} -->
## P09-T014 — Run C05: retained feature and diff equivalence

Contract: `G5-R.acceptance.correctnessGates.C05`, `Q1-R5`, `C05`

Dependencies:
- `P09-T002`
- `P05-T200`
- `P07-T010`

Ownership selectors:
- `correctnessGate:C05`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C05Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C05Evidence`

Red verification:
- Run: `swift test --filter C05Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C05`

Minimal implementation operations:
- `Execute all 62 retained feature entry points, five instance sequences, legacy and advanced diff, timeout, cache, and native replacement behavior.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C05Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C05 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T014.json`

Completion assertions:
- `C05 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C05Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T015","recordSha256":"9998d3719d476e78a04cb3c7ace80689de0907709e40c4ce66befa043bcd87b5"} -->
## P09-T015 — Run C06: provider, LSP, snippet, and Markdown equivalence

Contract: `G5-R.acceptance.correctnessGates.C06`, `Q1-R5`, `C06`

Dependencies:
- `P09-T002`
- `P06-T010`

Ownership selectors:
- `correctnessGate:C06`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C06Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C06Evidence`

Red verification:
- Run: `swift test --filter C06Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C06`

Minimal implementation operations:
- `Validate 30 provider surfaces, 25 LSP mappings, five direct-only paths, transport, framing, JSON-RPC, session, fallback, snippet, and hostile Markdown matrices.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C06Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C06 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T015.json`

Completion assertions:
- `C06 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C06Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T016","recordSha256":"a042fd4f8b2e6a6c4dff9118e1d73364eaaac6c450a000a265925aa2ebe90beb"} -->
## P09-T016 — Run C07: native input, transfer, accessibility, and workspace-edit equivalence

Contract: `G5-R.acceptance.correctnessGates.C07`, `Q1-R5`, `C07`

Dependencies:
- `P09-T002`
- `P04-T016`
- `P07-T006`

Ownership selectors:
- `correctnessGate:C07`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C07Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C07Evidence`

Red verification:
- Run: `swift test --filter C07Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C07`

Minimal implementation operations:
- `Run ABC and Pinyin, chords, multi-cursor input, pointer, scroll, menu, copy/cut/paste, drag/drop, Services, VoiceOver, focus, announcements, and four WorkspaceEdit outcomes.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C07Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C07 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T016.json`

Completion assertions:
- `C07 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C07Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T017","recordSha256":"be23192ca8dbe3b2386bb032ab6f75efb34ce0484ac481022d17fc3ce4ff702f"} -->
## P09-T017 — Run C08: renderer correctness and frozen branch parity

Contract: `G5-R.acceptance.correctnessGates.C08`, `Q1-R5`, `C08`

Dependencies:
- `P09-T002`
- `P03-T012`

Ownership selectors:
- `correctnessGate:C08`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C08Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C08Evidence`

Red verification:
- Run: `swift test --filter C08Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C08`

Minimal implementation operations:
- `Validate every Core Graphics golden, scale, subpixel phase, fallback, color glyph, generation, failure, and the frozen Phase 03 Metal absence-or-parity branch.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C08Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C08 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T017.json`

Completion assertions:
- `C08 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C08Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T018","recordSha256":"b922b84ef98087df21939a9fd8b8feb5e36f2c5e771ad1f5c31012f3b53b4d30"} -->
## P09-T018 — Run C09: delivery views, hosts, lifetimes, services, and resource bounds

Contract: `G5-R.acceptance.correctnessGates.C09`, `Q1-R5`, `C09`

Dependencies:
- `P09-T002`
- `P04-T015`
- `P07-T010`

Ownership selectors:
- `correctnessGate:C09`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C09Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C09Evidence`

Red verification:
- Run: `swift test --filter C09Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C09`

Minimal implementation operations:
- `Validate three products, three views, four wrappers, seven host groups, ten concrete host types, service and cache exact sets, lifetime ownership, plateau, and workspace rollback.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C09Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C09 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T018.json`

Completion assertions:
- `C09 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C09Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T019","recordSha256":"f4b808a5e46e806851dd46a5b37f643efc02e2b23a2b277a44377f8d98d9dd0a"} -->
## P09-T019 — Run C10: release package, API, dependency, resource, hash, and license closure

Contract: `G5-R.acceptance.correctnessGates.C10`, `Q1-R5`, `C10`

Dependencies:
- `P09-T002`
- `P08-T016`

Ownership selectors:
- `correctnessGate:C10`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Correctness/C10Tests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `QEnvironmentID.json`

Interfaces produced:
- `C10Evidence`

Red verification:
- Run: `swift test --filter C10Tests/testSeededMismatch`
  - Expected exit: `1`
  - Expected output includes: `CORRECTNESS_GATE_FAILED gate=C10`

Minimal implementation operations:
- `Validate release architecture and deployment, three-product graph, symbol graphs, API digests, linked libraries, resources, seven candidates, artifact hashes, forbidden absences, and license notices.`
- `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

Green verification:
- Run: `swift test --filter C10Tests`
  - Expected exit: `0`
  - Expected output includes: `CORRECTNESS_GATE_PASS gate=C10 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T019.json`

Completion assertions:
- `C10 has zero mismatches.`
- `Every assigned overlay and failure row executed.`
- `Evidence binds to the qualified candidate set.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Correctness/C10Tests.swift`

<!-- monacode-plan-task:{"id":"P09-T030","recordSha256":"2894e38b4201a0555d7e658c7767139c135313463241ebcc387726fcd86ae4c8"} -->
## P09-T030 — Run P00: cold startup

Contract: `G5-R.performanceDecision.workloads.P00`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P00-T012`

Ownership selectors:
- `performanceWorkload:P00`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P00WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P00Evidence`

Red verification:
- Run: `swift test --filter P00WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P00 comparator=M0`

Minimal implementation operations:
- `Measure 50 fresh-profile, fresh-process-tree launches of the 1 MiU16/100000-line corpus from launch to ready, then terminate each tree.`
- `Collect 50 cold balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P00WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P00 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T030.json`

Completion assertions:
- `P00 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P00WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T031","recordSha256":"fc0a1dee8c758c84f144de5c933f6faf7ef280d3c88df7773fc54df5e38e7918"} -->
## P09-T031 — Run P01: model load

Contract: `G5-R.performanceDecision.workloads.P01`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P01-T013`

Ownership selectors:
- `performanceWorkload:P01`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P01WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P01Evidence`

Red verification:
- Run: `swift test --filter P01WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P01 comparator=M0`

Minimal implementation operations:
- `Load 1 MiU16 and 100 MiU16 raw-text corpora across LF, CRLF, valid Unicode, isolated-surrogate, and mixed-line families.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P01WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P01 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T031.json`

Completion assertions:
- `P01 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P01WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T032","recordSha256":"98f70ac64beccec168dee440af023f438b352e6d69725158cf2187d8658cab38"} -->
## P09-T032 — Run P02: typing and undo

Contract: `G5-R.performanceDecision.workloads.P02`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P02-T001`
- `P04-T005`

Ownership selectors:
- `performanceWorkload:P02`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P02WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P02Evidence`

Red verification:
- Run: `swift test --filter P02WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P02 comparator=M0`

Minimal implementation operations:
- `Execute 10000 ABC typing, delete, selection, undo, and redo actions on the 1 MiU16 corpus.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P02WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P02 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T032.json`

Completion assertions:
- `P02 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P02WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T033","recordSha256":"68b9491c61fb1f0da0a344f4fbddc199ddc0fba072c097b53eb8d2caa74e3a70"} -->
## P09-T033 — Run P03: batch edits

Contract: `G5-R.performanceDecision.workloads.P03`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P01-T009`

Ownership selectors:
- `performanceWorkload:P03`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P03WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P03Evidence`

Red verification:
- Run: `swift test --filter P03WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P03 comparator=M0`

Minimal implementation operations:
- `Prepare and commit 1, 100, and 10000 non-overlapping edits while measuring preparation and commit components separately.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P03WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P03 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T033.json`

Completion assertions:
- `P03 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P03WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T034","recordSha256":"3c2f7cfee4901f3638d0e90841119ff703186b99cc420745f99374eec920fc7b"} -->
## P09-T034 — Run P04: vertical scroll

Contract: `G5-R.performanceDecision.workloads.P04`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P03-T012`

Ownership selectors:
- `performanceWorkload:P04`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P04WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P04Evidence`

Red verification:
- Run: `swift test --filter P04WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P04 comparator=M0`

Minimal implementation operations:
- `Inject at least 10000 intervals over the 100 MiU16/1000000-line corpus in separate exact 60 Hz and 120 Hz cells.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P04WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P04 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T034.json`

Completion assertions:
- `P04 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P04WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T035","recordSha256":"a582fefa0e6dc48d840f15bf915b8ae6dab5283ac42acbe574f45a68046202f9"} -->
## P09-T035 — Run P05: long line

Contract: `G5-R.performanceDecision.workloads.P05`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P03-T012`
- `P05-T005`

Ownership selectors:
- `performanceWorkload:P05`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P05WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P05Evidence`

Red verification:
- Run: `swift test --filter P05WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P05 comparator=M0`

Minimal implementation operations:
- `Render 1000000-unit lines with stopRenderingLineAfter equal to 10000 and -1 across scale, fallback, and subpixel cells.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P05WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P05 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T035.json`

Completion assertions:
- `P05 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P05WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T036","recordSha256":"c19ae3a6a83ca26851c0d293695c43c6441f010cb8d60e4b051b5309d036916e"} -->
## P09-T036 — Run P06: wrap and resize

Contract: `G5-R.performanceDecision.workloads.P06`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P03-T012`

Ownership selectors:
- `performanceWorkload:P06`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P06WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P06Evidence`

Red verification:
- Run: `swift test --filter P06WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P06 comparator=M0`

Minimal implementation operations:
- `Cycle widths 320, 768, and 1440 points 10000 times over 100000 mixed-script lines with fold, inlay, and variable-height matrices.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P06WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P06 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T036.json`

Completion assertions:
- `P06 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P06WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T037","recordSha256":"d349150d9f68549cd858731968d7ddf667defc6b0266de4218a36ba11b1a32aa"} -->
## P09-T037 — Run P07: decorations

Contract: `G5-R.performanceDecision.workloads.P07`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P02-T002`
- `P03-T012`

Ownership selectors:
- `performanceWorkload:P07`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P07WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P07Evidence`

Red verification:
- Run: `swift test --filter P07WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P07 comparator=M0`

Minimal implementation operations:
- `Update 100000 model decorations with 10000 visible/offscreen mixed actions and exact interval-operation counters.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P07WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P07 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T037.json`

Completion assertions:
- `P07 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P07WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T038","recordSha256":"9a2be80f1c0a7d1219edd5a1399f8bfc8405ce85abae997c0454ae96001a3fd5"} -->
## P09-T038 — Run P08: find and replace

Contract: `G5-R.performanceDecision.workloads.P08`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P02-T009`

Ownership selectors:
- `performanceWorkload:P08`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P08WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P08Evidence`

Red verification:
- Run: `swift test --filter P08WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P08 comparator=M0`

Minimal implementation operations:
- `Run literal, /gimu, zero-length, capture replacement, density 0/0.1/10/1000 per KiB, RegExp consumer, case, normalization, binary64, decoder, and hash matrices on 10 MiU16.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P08WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P08 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T038.json`

Completion assertions:
- `P08 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P08WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T039","recordSha256":"f3ea27a9bf2d3da9a5156fd51f0a6845836996f16dc36ff7a84539a39614ca3c"} -->
## P09-T039 — Run P09: multi-cursor and snippet

Contract: `G5-R.performanceDecision.workloads.P09`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P04-T005`
- `P06-T007`

Ownership selectors:
- `performanceWorkload:P09`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P09WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P09Evidence`

Red verification:
- Run: `swift test --filter P09WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P09 comparator=M0`

Minimal implementation operations:
- `Run type, paste, delete, undo, overlap, snippet insertion, 39 variables, clipboard spread, time snapshot, random, and UUID traces for 1, 100, and 10000 cursors.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P09WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P09 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T039.json`

Completion assertions:
- `P09 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P09WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T040","recordSha256":"64891700654c10eab4a3bbd2fb6d84d8b5ce5ee5381c6c7304e5e8cf6629bad3"} -->
## P09-T040 — Run P10: diff and multi-diff

Contract: `G5-R.performanceDecision.workloads.P10`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P07-T002`
- `P07-T009`

Ownership selectors:
- `performanceWorkload:P10`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P10WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P10Evidence`

Red verification:
- Run: `swift test --filter P10WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P10 comparator=M0`

Minimal implementation operations:
- `Run legacy/advanced diff on 1/10/50 MiU16 with 1/10/30 percent changes and multi-diff 1/10/100 items of 1 MiU16, including timeout and cache cells.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P10WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P10 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T040.json`

Completion assertions:
- `P10 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P10WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T041","recordSha256":"44e4cd04a3defc8e58870766b55c222ed9f7fea900db7fe226424b9856ca064c"} -->
## P09-T041 — Run P11: provider and LSP

Contract: `G5-R.performanceDecision.workloads.P11`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P06-T010`
- `P07-T003`

Ownership selectors:
- `performanceWorkload:P11`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P11WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P11Evidence`

Red verification:
- Run: `swift test --filter P11WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P11 comparator=M0`

Minimal implementation operations:
- `Run 30 provider surfaces, 25 mappings, 0/1/10000 results, cancellation, stale, resolve, Markdown, session, framing, and 0/10/100 ms injected transport delays with adapter delay subtraction.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P11WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P11 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T041.json`

Completion assertions:
- `P11 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P11WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T042","recordSha256":"af3e1b171c8e77b4674239032a085afffd8a9862c7c2c6a2789d2bba97855f76"} -->
## P09-T042 — Run P12: shared model

Contract: `G5-R.performanceDecision.workloads.P12`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P04-T014`
- `P07-T009`

Ownership selectors:
- `performanceWorkload:P12`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P12WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P12Evidence`

Red verification:
- Run: `swift test --filter P12WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P12 comparator=M0`

Minimal implementation operations:
- `Drive four editors over one 10 MiU16 model with independent wrap, fold, selection, and scroll state through 10000 interleaved actions and commit fanout.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P12WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P12 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T042.json`

Completion assertions:
- `P12 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P12WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T043","recordSha256":"0554d55bce73ed37de98e11c82f11e861e0d56a09eb5d5ce22497ff768c2dd71"} -->
## P09-T043 — Run P13: IME and accessibility queries

Contract: `G5-R.performanceDecision.workloads.P13`, `Q1-R2`, `Q1-R3`, `Q1-R4`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P04-T016`

Ownership selectors:
- `performanceWorkload:P13`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/BenchmarkHarness/Workloads/P13WorkloadTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `M0Comparator`
- `M1Comparator`
- `BootstrapVerdict`
- `QEnvironmentID.json`
- `DisplayCellLock`

Interfaces produced:
- `P13Evidence`

Red verification:
- Run: `swift test --filter P13WorkloadTests/testSeededRegression`
  - Expected exit: `1`
  - Expected output includes: `PERFORMANCE_NO_REGRESSION_FAILED workload=P13 comparator=M0`

Minimal implementation operations:
- `Run ABC/Pinyin marked-text traces, 10000 small accessibility range queries, 100 full-document queries, VoiceOver on/off, and callback latency.`
- `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter P13WorkloadTests`
  - Expected exit: `0`
  - Expected output includes: `PERFORMANCE_WORKLOAD_PASS workload=P13 baselines=M0,M1 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T043.json`

Completion assertions:
- `P13 passes every M0 and M1 cell.`
- `Every sample block satisfies environment, font, display, cold/hot, and statistic validity.`
- `No cell is skipped or clamped.`

Commit boundary:
- `Tests/BenchmarkHarness/Workloads/P13WorkloadTests.swift`

<!-- monacode-plan-task:{"id":"P09-T050","recordSha256":"693aedde79fbf7d1040d4cf83c85ab9b498939a967d45bbd1d7209421517e5a8"} -->
## P09-T050 — Run lifecycle, 24-hour soak, sanitizers, and validation layers

Contract: `G5-R.acceptance.crossCutting.lifecycle`, `G5-R.acceptance.crossCutting.soak`, `G5-R.acceptance.crossCutting.sanitizers`

Dependencies:
- `P09-T002`
- `P09-T030`
- `P09-T031`
- `P09-T032`
- `P09-T033`
- `P09-T034`
- `P09-T035`
- `P09-T036`
- `P09-T037`
- `P09-T038`
- `P09-T039`
- `P09-T040`
- `P09-T041`
- `P09-T042`
- `P09-T043`

Ownership selectors:
- `acceptance:lifecycle-1000`
- `acceptance:soak-24h`
- `acceptance:sanitizers`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/CrossCutting/LifecycleSoakSanitizerTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `MonaCacheManifest.json`
- `RendererBranchEvidence`

Interfaces produced:
- `LifecycleSoakSanitizerEvidence`

Red verification:
- Run: `swift test --filter LifecycleSoakSanitizerTests/testSeededLifetimeLeak`
  - Expected exit: `1`
  - Expected output includes: `LIFECYCLE_SOAK_GATE_FAILED reason=definite-leak`

Minimal implementation operations:
- `Run 1000 create, attach, detach, and dispose cycles and require weak accounting to return to the warm baseline.`
- `Run 24 hours of mixed P02-P13 actions and require quiescent allocations and counters to remain within MonaCacheManifest bounds.`
- `Run complete ASan, TSan, and UBSan suites separately with zero findings and Main Thread Checker with zero findings.`
- `Run Metal validation only for the triggered-and-required renderer branch; record not-applicable for the absent branch.`
- `Treat crash, hang, data loss, half commit, leak, race, undefined behavior, validation error, or counter overflow as failure.`

Green verification:
- Run: `swift test --filter LifecycleSoakSanitizerTests`
  - Expected exit: `0`
  - Expected output includes: `LIFECYCLE_SOAK_SANITIZERS cycles=1000 hours=24 findings=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T050.json`

Completion assertions:
- `1000 cycles return to baseline.`
- `24-hour soak stays within declared plateaus.`
- `All applicable sanitizers and validation layers report zero findings.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/CrossCutting/LifecycleSoakSanitizerTests.swift`

<!-- monacode-plan-task:{"id":"P09-T051","recordSha256":"4bfca81907c15b203512283cbf5d430424fd36e9e20e9932944a2a78d4cd3dd7"} -->
## P09-T051 — Run failure-injection and algorithmic complexity gates

Contract: `G5-R.acceptance.crossCutting.failureInjection`, `G5-R.acceptance.crossCutting.complexity`, `R1`, `H2-R`

Dependencies:
- `P09-T002`
- `P09-T010`
- `P09-T011`
- `P09-T012`
- `P09-T013`
- `P09-T014`
- `P09-T015`
- `P09-T016`
- `P09-T017`
- `P09-T018`
- `P09-T019`

Ownership selectors:
- `acceptance:failure-injection`
- `acceptance:complexity-gates`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/CrossCutting/FailureAndComplexityTests.swift`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `Phase01ModelGate`
- `Phase03RendererGate`
- `Phase04NativeBoundaryGate`
- `Phase06LanguageGate`
- `Phase07HostAndDiffGate`

Interfaces produced:
- `FailureInjectionEvidence`
- `ComplexityEvidence`

Red verification:
- Run: `swift test --filter FailureAndComplexityTests/testSeededViewportFullScan`
  - Expected exit: `1`
  - Expected output includes: `COMPLEXITY_GATE_FAILED operation=viewport-layout observed=full-document-scan`

Minimal implementation operations:
- `Inject every declared recoverable allocation, shaping, renderer resource, LSP framing/session, provider, host, workspace, IME, cache, reentry, cancellation, and disposal failure.`
- `Require typed failure plus rollback or drop with zero half-committed state; exclude fatal OOM from recoverable claims.`
- `Use operation counters to prove Piece Tree, decoration, projection, vertical index, layout, renderer, search, diff, provider, and fanout growth classes retain Monaco upper bounds.`
- `Fail immediately on any worse asymptotic order, viewport full-document scan, or work not bounded by visible rows plus changed dependencies.`

Green verification:
- Run: `swift test --filter FailureAndComplexityTests`
  - Expected exit: `0`
  - Expected output includes: `FAILURE_COMPLEXITY recoverableRows=all halfCommits=0 growthRegressions=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T051.json`

Completion assertions:
- `Every declared recoverable failure is injected.`
- `All invariants and rollback rules hold.`
- `Every operation-count growth class remains within the frozen bound.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/CrossCutting/FailureAndComplexityTests.swift`

<!-- monacode-plan-task:{"id":"P09-T052","recordSha256":"5a4d6f4d3380ff63dfd17eb72c75591c3f1ac17bfc8f38378fa82525a2f7ee40"} -->
## P09-T052 — Validate the frozen Phase 03 renderer decision without source changes

Contract: `G5-R.performanceDecision.metalTrigger`, `V1-R4.rendererDecision`, `C03`, `C08`

Dependencies:
- `P09-T012`
- `P09-T017`
- `P09-T034`
- `P09-T035`
- `P09-T036`

Ownership selectors:
- `acceptance:renderer-decision-validation`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/CrossCutting/RendererDecisionValidationTests.swift`

Interfaces consumed:
- `MonaRendererDecision`
- `RendererBranchEvidence`
- `C03Evidence`
- `C08Evidence`
- `P04Evidence`
- `P05Evidence`
- `P06Evidence`

Interfaces produced:
- `RendererDecisionValidationEvidence`

Red verification:
- Run: `swift test --filter RendererDecisionValidationTests/testDecisionEvidenceCannotBeRecomputed`
  - Expected exit: `1`
  - Expected output includes: `RENDERER_DECISION_VALIDATION_FAILED reason=phase09-source-change`

Minimal implementation operations:
- `Verify the immutable Phase 03 decision hash, Core Graphics completion predecessor, trigger metric scope, selected source set, and absence-or-parity evidence.`
- `Confirm every current renderer correctness and performance cell agrees with the frozen branch.`
- `Reject any Phase 09 source creation, decision recomputation, cross-domain trigger, missing fallback, or unvalidated triggered branch.`

Green verification:
- Run: `swift test --filter RendererDecisionValidationTests`
  - Expected exit: `0`
  - Expected output includes: `RENDERER_DECISION_VALIDATION frozen=pass sourceChanges=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T052.json`

Completion assertions:
- `Renderer branch matches Phase 03 exactly.`
- `No later product source or decision change exists.`
- `All applicable parity and fallback evidence passes.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/CrossCutting/RendererDecisionValidationTests.swift`

<!-- monacode-plan-task:{"id":"P09-T099","recordSha256":"fa6af0f176727969baeb922c85e2fe4eee69eb9b26b097b7fb9288d28f37d5c2"} -->
## P09-T099 — Aggregate the final all-or-nothing G5-R release verdict

Contract: `G5-R.acceptance.releaseVerdict`, `G5-R.designClosure.stoppingCriterion`, `Q1-R5`

Dependencies:
- `P09-T002`
- `P09-T010`
- `P09-T011`
- `P09-T012`
- `P09-T013`
- `P09-T014`
- `P09-T015`
- `P09-T016`
- `P09-T017`
- `P09-T018`
- `P09-T019`
- `P09-T030`
- `P09-T031`
- `P09-T032`
- `P09-T033`
- `P09-T034`
- `P09-T035`
- `P09-T036`
- `P09-T037`
- `P09-T038`
- `P09-T039`
- `P09-T040`
- `P09-T041`
- `P09-T042`
- `P09-T043`
- `P09-T050`
- `P09-T051`
- `P09-T052`

Ownership selectors:
- `release:final-verdict`

Files to create:
- `Tools/Release/release-verdict.mjs`
- `RELEASE_VERDICT.md`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs`

Interfaces consumed:
- `MonaQualifiedCandidateSet`
- `C01Evidence`
- `C02Evidence`
- `C03Evidence`
- `C04Evidence`
- `C05Evidence`
- `C06Evidence`
- `C07Evidence`
- `C08Evidence`
- `C09Evidence`
- `C10Evidence`
- `P00Evidence`
- `P01Evidence`
- `P02Evidence`
- `P03Evidence`
- `P04Evidence`
- `P05Evidence`
- `P06Evidence`
- `P07Evidence`
- `P08Evidence`
- `P09Evidence`
- `P10Evidence`
- `P11Evidence`
- `P12Evidence`
- `P13Evidence`
- `LifecycleSoakSanitizerEvidence`
- `FailureInjectionEvidence`
- `ComplexityEvidence`
- `RendererDecisionValidationEvidence`

Interfaces produced:
- `MonaG5RReleaseVerdict`

Red verification:
- Run: `node --test Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs --test-name-pattern skipped-cell`
  - Expected exit: `1`
  - Expected output includes: `RELEASE_VERDICT_NOT_PASSED reason=skipped-cell cell=P04-M1-120Hz`

Minimal implementation operations:
- `Verify one source revision, one seven-candidate set, one exact qualified environment, C01-C10, every P00-P13 M0/M1 cell, lifecycle, soak, sanitizers, validation, failure injection, complexity, and renderer decision evidence.`
- `Reject missing, failed, skipped, stale, malformed, unauthorized, mixed-revision, mixed-environment, unhashed, or unsigned-input evidence.`
- `Emit passed only when every prerequisite passes; otherwise emit not-passed with the complete sorted blocker set.`
- `Keep the frozen G5-R design contract unchanged and record empirical implementation state only in the verdict and candidate artifacts.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `RELEASE_VERDICT passed sourceRevisions=1 candidates=7 correctness=10 performance=14 skipped=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-09/P09-T099.json`

Completion assertions:
- `The verdict task is last in topological order.`
- `Passed requires every frozen product and evidence condition.`
- `Contract files remain hash-identical to the adopted G5-R lock.`

Commit boundary:
- `Tools/Release/release-verdict.mjs`
- `RELEASE_VERDICT.md`
- `Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs`
