# Phase 00: Scaffold and harness

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: none.

Task count: 12.

<!-- monacode-plan-task:{"id":"P00-T001","recordSha256":"910209a4c1d03eebce97e722fd5b61c5eb6429ea3d3837359f31d984abdd0206"} -->
## P00-T001 — Create the exact SwiftPM product, target, and fixture-resource graph

Contract: `G5-R.deliveryScope`, `G5-R.validationScope.packageDeploymentTarget`, `Architecture-A.dependencies`

Dependencies:
- None.

Ownership selectors:
- `package-graph:three-products`
- `target-graph:three-non-product-targets`

Files to create:
- `Package.swift`
- `Sources/MonaCode/Scaffold.swift`
- `Sources/MonaCodeAppKit/Scaffold.swift`
- `Sources/MonaCodeSwiftUI/Scaffold.swift`
- `Sources/MonaCodeSample/main.swift`
- `Tests/MonaCodeTests/ScaffoldTests.swift`
- `Tests/MonaCodeAppKitTests/ScaffoldTests.swift`
- `Tests/ConformanceAndFailureInjection/FailureInjectionScaffoldTests.swift`
- `Tests/BenchmarkHarness/BenchmarkScaffoldTests.swift`
- `Tests/Fixtures/DifferentialFixtures/.gitkeep`

Files to modify:
- None.

Test files:
- None.

Interfaces consumed:
- None.

Interfaces produced:
- `SwiftPMGraph`
- `DifferentialFixturesResource`

Red verification:
- Run: `swift package dump-package | node Tools/PlanChecks/assert-package-graph.mjs`
  - Expected exit: `1`
  - Expected output includes: `PLAN_PACKAGE_GRAPH_MISSING`

Minimal implementation operations:
- `Declare MonaCode, MonaCodeAppKit, and MonaCodeSwiftUI as the only public products.`
- `Declare sample-macOS-host, conformance-and-failure-injection, and benchmark-harness as the required non-product targets.`
- `Map Tests/Fixtures/DifferentialFixtures as a resource and never as a target.`
- `Pin macOS 26.0 and Swift language mode 6.`

Green verification:
- Run: `swift package dump-package | node Tools/PlanChecks/assert-package-graph.mjs`
  - Expected exit: `0`
  - Expected output includes: `PACKAGE_GRAPH products=3 nonProductTargets=3 fixtureTargets=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T001.json`

Completion assertions:
- `Exact three-product graph exists.`
- `Exact three required non-product targets exist.`
- `DifferentialFixtures is a resource only.`

Commit boundary:
- `Package.swift`
- `Sources/MonaCode/Scaffold.swift`
- `Sources/MonaCodeAppKit/Scaffold.swift`
- `Sources/MonaCodeSwiftUI/Scaffold.swift`
- `Sources/MonaCodeSample/main.swift`
- `Tests/MonaCodeTests/ScaffoldTests.swift`
- `Tests/MonaCodeAppKitTests/ScaffoldTests.swift`
- `Tests/ConformanceAndFailureInjection/FailureInjectionScaffoldTests.swift`
- `Tests/BenchmarkHarness/BenchmarkScaffoldTests.swift`
- `Tests/Fixtures/DifferentialFixtures/.gitkeep`

<!-- monacode-plan-task:{"id":"P00-T002","recordSha256":"53eba934ed12ffa803649b8b8d249720cf1d99598ba8c65fb2b392a93618de80"} -->
## P00-T002 — Enforce the Foundation-only MonaCode boundary

Contract: `Architecture-A.boundaries`, `G5-R.explicitCuts.platformAndCompatibility`

Dependencies:
- `P00-T001`

Ownership selectors:
- `module-boundary:MonaCode`

Files to create:
- `Tools/PlanChecks/forbidden-core-imports.sh`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs`

Interfaces consumed:
- None.

Interfaces produced:
- `ForbiddenCoreImportGate`

Red verification:
- Run: `node --test Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs`
  - Expected exit: `1`
  - Expected output includes: `PLAN_FORBIDDEN_CORE_IMPORT fixture=seeded-violation`

Minimal implementation operations:
- `Scan every Swift source assigned to the MonaCode target.`
- `Reject platform UI, graphics, rendering, pasteboard, web runtime, JavaScript runtime, and semantic-substitution imports.`
- `Run one seeded violation and one clean-tree case.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `FORBIDDEN_CORE_IMPORTS seeded=detected clean=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T002.json`

Completion assertions:
- `A seeded prohibited import fails.`
- `A clean Foundation-only Core tree passes.`

Commit boundary:
- `Tools/PlanChecks/forbidden-core-imports.sh`
- `Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs`

<!-- monacode-plan-task:{"id":"P00-T003","recordSha256":"808b2164b4b12c743fa2ea6da3d9d477d9df9102ff8a5b4aa51b4801c5ed61bb"} -->
## P00-T003 — Pin Monaco 0.56.0 M0 and M1 comparator provenance

Contract: `P1-R`, `Q1-R2`, `G5-R.authorityArtifacts`

Dependencies:
- `P00-T001`

Ownership selectors:
- `normativeLayer:provenance:P1-R`
- `comparator:M0`
- `comparator:M1`

Files to create:
- `Comparators/package.json`
- `Comparators/package-lock.json`
- `Comparators/provenance-lock.json`
- `Comparators/build-m1.mjs`
- `Tools/PlanChecks/verify-provenance.mjs`

Files to modify:
- None.

Test files:
- None.

Interfaces consumed:
- None.

Interfaces produced:
- `M0Comparator`
- `M1Comparator`
- `ComparatorProvenanceLock`

Red verification:
- Run: `node Tools/PlanChecks/verify-provenance.mjs --fixture tampered-lock`
  - Expected exit: `1`
  - Expected output includes: `PROVENANCE_HASH_MISMATCH artifact=monaco-editor-0.56.0`

Minimal implementation operations:
- `Lock the Monaco npm archives, monaco.d.ts, source tag, esbuild version, and M1 cut definition.`
- `Build M1 only from the locked sources and record its complete SHA-256.`
- `Keep all comparator dependencies outside production targets.`

Green verification:
- Run: `node Tools/PlanChecks/verify-provenance.mjs`
  - Expected exit: `0`
  - Expected output includes: `PROVENANCE_OK monaco=0.56.0 comparators=2`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T003.json`

Completion assertions:
- `M0 and M1 inputs are hash-verified.`
- `Production targets do not link comparator dependencies.`

Commit boundary:
- `Comparators/package.json`
- `Comparators/package-lock.json`
- `Comparators/provenance-lock.json`
- `Comparators/build-m1.mjs`
- `Tools/PlanChecks/verify-provenance.mjs`

<!-- monacode-plan-task:{"id":"P00-T004","recordSha256":"b34ea3d18df252b9d0c966cb1958bb67215a05caf2fba404e96ad7c6c0b05915"} -->
## P00-T004 — Reproduce frozen scope, declaration, and instance-surface manifests

Contract: `F1-R3`, `F1-R4`, `G5-R.surfaceCounts`

Dependencies:
- `P00-T003`

Ownership selectors:
- `machineArtifact:F1-R3-scope`
- `machineArtifact:F1-R3-instance`

Files to create:
- `Comparators/probes/scope-probe.mjs`
- `Comparators/probes/instance-surface-probe.mjs`
- `Comparators/probes/public-declaration-probe.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/ScopeProbeTests.mjs`

Interfaces consumed:
- `M0Comparator`
- `M1Comparator`
- `ComparatorProvenanceLock`

Interfaces produced:
- `ScopeProbe`
- `InstanceSurfaceProbe`
- `PublicDeclarationProbe`

Red verification:
- Run: `node --test Tests/PlanStructureTests/ScopeProbeTests.mjs --test-name-pattern tampered`
  - Expected exit: `1`
  - Expected output includes: `SCOPE_MANIFEST_COUNT_MISMATCH registry=features`

Minimal implementation operations:
- `Probe the exact registries and public declaration graph from both locked comparators.`
- `Compare every count and identity against the copied F1-R3 and F1-R4 manifests.`
- `Reject identity drift even when aggregate counts remain equal.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/ScopeProbeTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `SCOPE_PROBES_OK features=64 publicPaths=555`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T004.json`

Completion assertions:
- `All frozen registry counts reproduce.`
- `All 555 public declaration paths reproduce by identity.`

Commit boundary:
- `Comparators/probes/scope-probe.mjs`
- `Comparators/probes/instance-surface-probe.mjs`
- `Comparators/probes/public-declaration-probe.mjs`
- `Tests/PlanStructureTests/ScopeProbeTests.mjs`

<!-- monacode-plan-task:{"id":"P00-T005","recordSha256":"3dfb3036a18d095b19e9a74c73fa42048949edca300fd737f3ba8f81eadcdcb8"} -->
## P00-T005 — Implement separate wall and high-resolution clock domains

Contract: `E1-R.clockDomains`, `X1-R.clockAndPerformanceCorrection`

Dependencies:
- `P00-T001`

Ownership selectors:
- `environment:clock-domains`

Files to create:
- `Sources/MonaCode/Environment/MonaClock.swift`
- `Sources/MonaCode/Environment/MonaWallClock.swift`
- `Sources/MonaCode/Environment/MonaHighResolutionClock.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Environment/MonaClockTests.swift`

Interfaces consumed:
- None.

Interfaces produced:
- `MonaClock`
- `MonaWallClock`
- `MonaHighResolutionClock`

Red verification:
- Run: `swift test --filter MonaClockTests/testClockDomainsNeverInterchange`
  - Expected exit: `1`
  - Expected output includes: `XCTAssertEqual failed: clock-domain-classification`

Minimal implementation operations:
- `Represent wall-clock milliseconds and monotonic high-resolution time as separate injected protocols.`
- `Preserve injected binary64 traces exactly.`
- `Classify all frozen timing occurrences without substituting one domain for another.`

Green verification:
- Run: `swift test --filter MonaClockTests`
  - Expected exit: `0`
  - Expected output includes: `Executed 4 tests, with 0 failures`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T005.json`

Completion assertions:
- `Wall-clock jumps remain observable.`
- `High-resolution readings remain monotonic.`
- `Injected traces replay byte-identically.`

Commit boundary:
- `Sources/MonaCode/Environment/MonaClock.swift`
- `Sources/MonaCode/Environment/MonaWallClock.swift`
- `Sources/MonaCode/Environment/MonaHighResolutionClock.swift`
- `Tests/MonaCodeTests/Environment/MonaClockTests.swift`

<!-- monacode-plan-task:{"id":"P00-T006","recordSha256":"f1cd9e53f40dde482641f4d52f5f35d2d5cbc028fe75239305f443bd75e95c21"} -->
## P00-T006 — Implement deterministic random, cryptographic random, and Number-to-string sources

Contract: `E1-R.entropy`, `SN1-R.variables`, `C02`

Dependencies:
- `P00-T001`

Ownership selectors:
- `environment:entropy`
- `environment:number-to-string`

Files to create:
- `Sources/MonaCode/Environment/MonaRandomDoubleSource.swift`
- `Sources/MonaCode/Environment/MonaCryptoRandomSource.swift`
- `Sources/MonaCode/Environment/MonaNumberToString.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Environment/MonaEntropyTests.swift`

Interfaces consumed:
- None.

Interfaces produced:
- `MonaRandomDoubleSource`
- `MonaCryptoRandomSource`
- `MonaNumberToString`

Red verification:
- Run: `swift test --filter MonaEntropyTests/testInjectedDrawOrder`
  - Expected exit: `1`
  - Expected output includes: `XCTAssertEqual failed: entropy-draw-order`

Minimal implementation operations:
- `Expose one injectable shared random sequence for every retained consumer.`
- `Produce canonical lowercase UUID version 4 values from injected bytes.`
- `Implement the finite radix-10 and radix-16 conversion profile required by frozen vectors.`

Green verification:
- Run: `swift test --filter MonaEntropyTests`
  - Expected exit: `0`
  - Expected output includes: `Executed 6 tests, with 0 failures`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T006.json`

Completion assertions:
- `RANDOM and RANDOM_HEX vectors match M0/M1.`
- `UUID version and variant bits match.`
- `Draw order is deterministic.`

Commit boundary:
- `Sources/MonaCode/Environment/MonaRandomDoubleSource.swift`
- `Sources/MonaCode/Environment/MonaCryptoRandomSource.swift`
- `Sources/MonaCode/Environment/MonaNumberToString.swift`
- `Tests/MonaCodeTests/Environment/MonaEntropyTests.swift`

<!-- monacode-plan-task:{"id":"P00-T007","recordSha256":"00ca0da39c22dd09f4c0560184a418658bbe1ec5eceb96dfc07aab40da715bda"} -->
## P00-T007 — Separate immutable UI localization profile from runtime locale

Contract: `E1-R.localeBoundary`, `N1-R.profileSelection`, `G5-R.currentLocalEnvironment`

Dependencies:
- `P00-T001`

Ownership selectors:
- `normativeLayer:environment-intl-clock-entropy:E1-R`
- `machineArtifact:E1-R-environment-intl`

Files to create:
- `Sources/MonaCode/Environment/MonaRuntimeLocale.swift`
- `Sources/MonaCode/Environment/MonaCodeEnvironment.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Environment/MonaLocaleBoundaryTests.swift`

Interfaces consumed:
- None.

Interfaces produced:
- `MonaRuntimeLocaleSnapshot`
- `MonaCodeEnvironment`

Red verification:
- Run: `swift test --filter MonaLocaleBoundaryTests/testRuntimeLocaleCannotSelectUIProfile`
  - Expected exit: `1`
  - Expected output includes: `XCTAssertEqual failed: localization-profile-boundary`

Minimal implementation operations:
- `Capture runtime locale, calendar, numbering system, and time zone once at startup.`
- `Select UI message profile only from the explicit environment option.`
- `Reject unsupported profile identifiers with a typed error.`

Green verification:
- Run: `swift test --filter MonaLocaleBoundaryTests`
  - Expected exit: `0`
  - Expected output includes: `Executed 5 tests, with 0 failures`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T007.json`

Completion assertions:
- `Runtime locale never mutates the UI profile.`
- `Current zh-CN runtime values reproduce.`
- `Profile state is immutable.`

Commit boundary:
- `Sources/MonaCode/Environment/MonaRuntimeLocale.swift`
- `Sources/MonaCode/Environment/MonaCodeEnvironment.swift`
- `Tests/MonaCodeTests/Environment/MonaLocaleBoundaryTests.swift`

<!-- monacode-plan-task:{"id":"P00-T008","recordSha256":"2fe2a548e0cf109d8c10f5dbea4461ad7b673498a5d9c18b5d826c6669097db7"} -->
## P00-T008 — Build the differential fixture and comparator harness

Contract: `Q1-R.differentialHarness`, `G5-R.equivalenceDomains`

Dependencies:
- `P00-T004`
- `P00-T005`
- `P00-T006`
- `P00-T007`

Ownership selectors:
- `verification:differential-harness`

Files to create:
- `Tools/Differential/runner.mjs`
- `Tools/Differential/fixture-schema.json`
- `Tests/MonaCodeTests/Differential/MonaDifferentialModelProvider.swift`
- `Tests/MonaCodeTests/Differential/DifferentialHarnessTests.swift`

Files to modify:
- None.

Test files:
- None.

Interfaces consumed:
- `M0Comparator`
- `M1Comparator`
- `MonaClock`
- `MonaRandomDoubleSource`
- `MonaRuntimeLocaleSnapshot`

Interfaces produced:
- `DifferentialFixtureV1`
- `DifferentialRunner`
- `MonaDifferentialModelProvider`

Red verification:
- Run: `swift test --filter DifferentialHarnessTests/testSeededMismatchIsBlocking`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=seeded-mismatch domain=exact`

Minimal implementation operations:
- `Run M0, M1, and native subjects with one identical injected environment trace.`
- `Persist raw UTF-16 inputs and outputs without Unicode repair.`
- `Distinguish exact and native-adapted comparison domains in every fixture.`

Green verification:
- Run: `swift test --filter DifferentialHarnessTests`
  - Expected exit: `0`
  - Expected output includes: `DIFFERENTIAL_HARNESS fixtures=2 seededMismatch=detected`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T008.json`

Completion assertions:
- `Fixture schema round-trips.`
- `Seeded exact-domain drift blocks.`
- `Comparator and native traces share one environment input.`

Commit boundary:
- `Tools/Differential/runner.mjs`
- `Tools/Differential/fixture-schema.json`
- `Tests/MonaCodeTests/Differential/MonaDifferentialModelProvider.swift`
- `Tests/MonaCodeTests/Differential/DifferentialHarnessTests.swift`

<!-- monacode-plan-task:{"id":"P00-T009","recordSha256":"e289407555e0323445ad411ec20ddab3ad20625455c472bf43c78316be7ac669"} -->
## P00-T009 — Implement the complete Q1-R3 statistical verdict engine

Contract: `Q1-R2`, `Q1-R3`, `G5-R.performanceDecision.sampleProtocol`

Dependencies:
- `P00-T008`

Ownership selectors:
- `normativeLayer:verification:Q1-R`
- `normativeLayer:verification:Q1-R2`
- `normativeLayer:verification:Q1-R3`

Files to create:
- `Tests/BenchmarkHarness/BenchmarkRunner.swift`
- `Tests/BenchmarkHarness/BootstrapStatistics.swift`
- `Tests/BenchmarkHarness/CellManifest.swift`
- `Tests/BenchmarkHarness/BootstrapStatisticsTests.swift`

Files to modify:
- None.

Test files:
- None.

Interfaces consumed:
- `DifferentialFixtureV1`

Interfaces produced:
- `BootstrapVerdict`
- `BenchmarkCellManifest`

Red verification:
- Run: `swift test --filter BootstrapStatisticsTests/testRejectsInvalidComponentDelta`
  - Expected exit: `1`
  - Expected output includes: `BENCHMARK_PAIR_INVALID reason=component-below-resolution`

Minimal implementation operations:
- `Implement whole-balanced-block resampling with exactly 1000000 deterministic bootstrap draws.`
- `Implement positive-ratio, manifest-declared near-zero difference, and discrete-zero verdict forms.`
- `Reject non-finite, non-positive, negative, zero, and below-resolution component inputs exactly as Q1-R3 defines.`
- `Evaluate the intersection-union test on unrounded binary64 values.`

Green verification:
- Run: `swift test --filter BootstrapStatisticsTests`
  - Expected exit: `0`
  - Expected output includes: `BOOTSTRAP_STATISTICS B=1000000 verdictForms=3 failures=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T009.json`

Completion assertions:
- `All three verdict forms pass locked vectors.`
- `Bootstrap seed is reproducible.`
- `No outlier deletion or clamping exists.`

Commit boundary:
- `Tests/BenchmarkHarness/BenchmarkRunner.swift`
- `Tests/BenchmarkHarness/BootstrapStatistics.swift`
- `Tests/BenchmarkHarness/CellManifest.swift`
- `Tests/BenchmarkHarness/BootstrapStatisticsTests.swift`

<!-- monacode-plan-task:{"id":"P00-T010","recordSha256":"7e8406a47c3f3f9de39f0a09c78253688d9531895966c3444e12eacae45a3588"} -->
## P00-T010 — Enforce font provenance, cold launch, display isolation, and refresh cells

Contract: `Q1-R4`, `G5-R.currentLocalEnvironment.onlineDisplaySlots`

Dependencies:
- `P00-T009`

Ownership selectors:
- `normativeLayer:verification:Q1-R4`
- `qualification:font-cold-display`

Files to create:
- `Tests/BenchmarkHarness/Q1R4FontProvenance.swift`
- `Tests/BenchmarkHarness/ColdLaunchManager.swift`
- `Tests/BenchmarkHarness/DisplayModeEnforcer.swift`
- `Tests/BenchmarkHarness/Q1R4ControlsTests.swift`

Files to modify:
- None.

Test files:
- None.

Interfaces consumed:
- `BenchmarkCellManifest`

Interfaces produced:
- `FontProvenanceRecord`
- `ColdLaunchBlock`
- `DisplayCellLock`

Red verification:
- Run: `swift test --filter Q1R4ControlsTests/testRejectsMixedRefreshBlock`
  - Expected exit: `1`
  - Expected output includes: `Q1R4_BLOCK_INVALID reason=display-refresh-changed`

Minimal implementation operations:
- `Hash every used font file and table and record variation axes plus run coverage.`
- `Run each cold sample with a fresh profile and fresh process tree.`
- `Lock every measurement block to the built-in display and one exact refresh cell.`
- `Keep 60 Hz and 120 Hz deadlines separate without changing the relative no-regression threshold.`

Green verification:
- Run: `swift test --filter Q1R4ControlsTests`
  - Expected exit: `0`
  - Expected output includes: `Q1R4_CONTROLS font=locked cold=isolated refreshCells=2`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T010.json`

Completion assertions:
- `Unmanifested font runs fail.`
- `Cold launches are process-isolated.`
- `59.94 Hz never enters the 60 Hz cell.`
- `External displays invalidate formal runs.`

Commit boundary:
- `Tests/BenchmarkHarness/Q1R4FontProvenance.swift`
- `Tests/BenchmarkHarness/ColdLaunchManager.swift`
- `Tests/BenchmarkHarness/DisplayModeEnforcer.swift`
- `Tests/BenchmarkHarness/Q1R4ControlsTests.swift`

<!-- monacode-plan-task:{"id":"P00-T011","recordSha256":"d4324451a93f401e4b50397eb1f0595b6db6f3a291771e84b212bd95b5d33d6b"} -->
## P00-T011 — Collect a privacy-filtered QEnvironmentID and enforce formal preflight

Contract: `G5-R.currentLocalEnvironment`, `G5-R.validationScope.privacy`, `Q1-R5.environmentPreflight`

Dependencies:
- `P00-T007`
- `P00-T010`

Ownership selectors:
- `qualification:QEnvironmentID-preflight`

Files to create:
- `Tools/Qualification/QEnvironmentCollector.swift`
- `Tools/Qualification/qenvironment-schema.json`
- `Tests/PlanStructureTests/QEnvironmentCollectorTests.mjs`

Files to modify:
- None.

Test files:
- None.

Interfaces consumed:
- `MonaRuntimeLocaleSnapshot`
- `DisplayCellLock`

Interfaces produced:
- `QEnvironmentIDPreflight`

Red verification:
- Run: `node --test Tests/PlanStructureTests/QEnvironmentCollectorTests.mjs --test-name-pattern forbidden-identity`
  - Expected exit: `1`
  - Expected output includes: `QENVIRONMENT_PRIVACY_VIOLATION path=$.hardwareUUID`

Minimal implementation operations:
- `Collect the exact OS, toolchain, architecture, display, input-source, runtime-locale, Chrome, and ICU fields fixed by G5-R.`
- `Reject serial, account, user, UUID, UDID, and UUID-shaped values recursively.`
- `Require externalDisplayCount equal to zero for every formal correctness or performance run.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/QEnvironmentCollectorTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `QENVIRONMENT_PREFLIGHT build=25G76 chrome=151.0.7922.138 externalDisplays=0 privacy=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T011.json`

Completion assertions:
- `Collector output matches the qualification schema.`
- `Forbidden identity fields and values are absent.`
- `Formal display predicate is enforced.`

Commit boundary:
- `Tools/Qualification/QEnvironmentCollector.swift`
- `Tools/Qualification/qenvironment-schema.json`
- `Tests/PlanStructureTests/QEnvironmentCollectorTests.mjs`

<!-- monacode-plan-task:{"id":"P00-T012","recordSha256":"35ff586348cc733146205ebc7b68ed3dcae2fae657b66aa501d3fba03dae5a36"} -->
## P00-T012 — Integrate Phase 00 gates without claiming product evidence

Contract: `Q1-R5`, `G5-R.designClosure.planGovernance`, `G5-R.empiricalStatus`

Dependencies:
- `P00-T002`
- `P00-T004`
- `P00-T008`
- `P00-T009`
- `P00-T010`
- `P00-T011`

Ownership selectors:
- `normativeLayer:verification:Q1-R5`
- `machineArtifact:Q1-R5-acceptance`

Files to create:
- None.

Files to modify:
- `Package.swift`

Test files:
- `Tests/PlanStructureTests/Phase00IntegrationTests.mjs`

Interfaces consumed:
- `SwiftPMGraph`
- `ForbiddenCoreImportGate`
- `ComparatorProvenanceLock`
- `DifferentialRunner`
- `BootstrapVerdict`
- `QEnvironmentIDPreflight`

Interfaces produced:
- `Phase00InfrastructureGate`

Red verification:
- Run: `node --test Tests/PlanStructureTests/Phase00IntegrationTests.mjs --test-name-pattern missing-gate`
  - Expected exit: `1`
  - Expected output includes: `PHASE00_GATE_MISSING gate=QEnvironmentIDPreflight`

Minimal implementation operations:
- `Wire every Phase 00 test and preflight into one structural gate.`
- `Keep every output state planned or structurally verified until future product execution supplies empirical evidence.`
- `Fail when any comparator, scope, privacy, statistics, font, cold-launch, display, or module-boundary gate is absent.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/Phase00IntegrationTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `PHASE00_INFRASTRUCTURE gates=8 evidenceState=structurally-verified`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-00/P00-T012.json`

Completion assertions:
- `All Phase 00 structural gates are wired.`
- `No C/P gate is marked passed.`
- `No release verdict is emitted.`

Commit boundary:
- `Package.swift`
- `Tests/PlanStructureTests/Phase00IntegrationTests.mjs`
