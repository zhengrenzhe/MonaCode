<!-- G6-R-PHASE:00 -->

# Phase 00 — Scaffold and harness

- Phase: `00`
- Title: Scaffold and harness
- Document: `implementation-plan/phase-00-scaffold-harness.md`
- Dependencies: _(none)_ 
- Tasks: 12

## Tasks

<!-- G6-R-TASK:P00-T001:3ca59ef1e1be7ffd81676d43e701c2e78e87efae9d742c4aa55cf70471d316ad -->

### P00-T001 — Create the exact SwiftPM product, target, and fixture-resource graph

- Record SHA-256: `3ca59ef1e1be7ffd81676d43e701c2e78e87efae9d742c4aa55cf70471d316ad`
- Platform scope: `macOS-26-arm64`
- Dependencies: _(none)_ 
- Test contract cases: 2
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T001`
- Evidence commit message: `evidence(monacode): complete P00-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs`

### Stage `red`

- verification-command: `P00-T001.RED.001` (kind=pipeline, network=forbidden, timeout=600000ms, leaves=2)

### Stage `implementation`

- implementation-operation: `Declare MonaCode, MonaCodeAppKit, and MonaCodeSwiftUI as the only public products.`
- implementation-operation: `Declare sample-macOS-host, conformance-and-failure-injection, and benchmark-harness as the required non-product targets.`
- implementation-operation: `Map Tests/Fixtures/DifferentialFixtures as a resource and never as a target.`
- implementation-operation: `Pin macOS 26.0 and Swift language mode 6.`

### Stage `green`

- verification-command: `P00-T001.GREEN.001` (kind=pipeline, network=forbidden, timeout=600000ms, leaves=2)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Package.swift
  - Sources/MonaCode/Scaffold.swift
  - Sources/MonaCodeAppKit/Scaffold.swift
  - Sources/MonaCodeSwiftUI/Scaffold.swift
  - Sources/MonaCodeSample/main.swift
  - Tests/MonaCodeTests/ScaffoldTests.swift
  - Tests/MonaCodeAppKitTests/ScaffoldTests.swift
  - Tests/ConformanceAndFailureInjection/FailureInjectionScaffoldTests.swift
  - Tests/BenchmarkHarness/BenchmarkScaffoldTests.swift
  - Tests/Fixtures/DifferentialFixtures/.gitkeep
- modify:
  - _(none)_
- test:
  - _(none)_

<!-- G6-R-TASK:P00-T002:af7eb950226e5ec999a3e7bdce928000adc1d702a13921b019ace6422be68964 -->

### P00-T002 — Enforce the Foundation-only MonaCode boundary

- Record SHA-256: `af7eb950226e5ec999a3e7bdce928000adc1d702a13921b019ace6422be68964`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T001` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T002`
- Evidence commit message: `evidence(monacode): complete P00-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs`

### Stage `red`

- verification-command: `P00-T002.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Scan every Swift source assigned to the MonaCode target.`
- implementation-operation: `Reject platform UI, graphics, rendering, pasteboard, web runtime, JavaScript runtime, and semantic-substitution imports.`
- implementation-operation: `Run one seeded violation and one clean-tree case.`

### Stage `green`

- verification-command: `P00-T002.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/PlanChecks/forbidden-core-imports.sh
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs

<!-- G6-R-TASK:P00-T003:516a93ba2f2d3e069b7e52795fb123195fbc3228c2f913b4e4d4613efca02528 -->

### P00-T003 — Pin Monaco 0.56.0 M0 and M1 comparator provenance

- Record SHA-256: `516a93ba2f2d3e069b7e52795fb123195fbc3228c2f913b4e4d4613efca02528`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T001` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 3
- Product commit message: `monacode: complete P00-T003`
- Evidence commit message: `evidence(monacode): complete P00-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tools/PlanChecks/verify-provenance.mjs`

### Stage `red`

- verification-command: `P00-T003.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- source-acquisition: `monaco-editor-npm` url=`https://registry.npmjs.org/monaco-editor/-/monaco-editor-0.56.0.tgz` host=`registry.npmjs.org` disposition=`temporary`
- source-acquisition: `monaco-editor-core-final-npm` url=`https://registry.npmjs.org/monaco-editor-core/-/monaco-editor-core-0.56.0.tgz` host=`registry.npmjs.org` disposition=`temporary`
- source-acquisition: `monaco-source-tag` url=`https://codeload.github.com/microsoft/monaco-editor/tar.gz/13f0c872dcf352815cc28d92dfff496c9839ea5c` host=`codeload.github.com` disposition=`temporary`
- implementation-operation: `Acquire monaco-editor-0.56.0 npm archive`
- implementation-operation: `Acquire monaco-editor-core-0.56.0 npm archive`
- implementation-operation: `Acquire monaco-editor source tag 13f0c872dcf352815cc28d92dfff496c9839ea5c`
- implementation-operation: `Verify exact archive-entry counts, extract inside ${TASK_TEMP}, reject absolute paths, parent traversal, symlinks, hard links, devices, duplicate normalized paths, NFC/lowercase/NFC component key collisions, and same-volume exclusive-creation probe collisions.`
- implementation-operation: `Verify inherited npm archive hashes, package/monaco.d.ts at 327877 bytes with SHA-256 fbbab04ba04224a04b2bc3243e536d1af6e26d14eb00fe8b3177bf3daef8d3f2, source commit identity, and every selected per-file hash before creating the five declared repository outputs.`
- implementation-operation: `Lock the Monaco npm archives, monaco.d.ts, source tag, esbuild version, and M1 cut definition.`
- implementation-operation: `Build M1 only from the locked sources and record its complete SHA-256.`
- implementation-operation: `Keep all comparator dependencies outside production targets.`

### Stage `green`

- verification-command: `P00-T003.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Comparators/package.json
  - Comparators/package-lock.json
  - Comparators/provenance-lock.json
  - Comparators/build-m1.mjs
  - Tools/PlanChecks/verify-provenance.mjs
- modify:
  - _(none)_
- test:
  - _(none)_

<!-- G6-R-TASK:P00-T004:c2dda7292cfeaef9d720b69882ee928bf545459ab4b7847e167292065f38009c -->

### P00-T004 — Reproduce frozen scope, declaration, and instance-surface manifests

- Record SHA-256: `c2dda7292cfeaef9d720b69882ee928bf545459ab4b7847e167292065f38009c`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T003` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T004`
- Evidence commit message: `evidence(monacode): complete P00-T004`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T004.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/ScopeProbeTests.mjs`

### Stage `red`

- verification-command: `P00-T004.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Probe the exact registries and public declaration graph from both locked comparators.`
- implementation-operation: `Compare every count and identity against the copied F1-R3 and F1-R4 manifests.`
- implementation-operation: `Reject identity drift even when aggregate counts remain equal.`

### Stage `green`

- verification-command: `P00-T004.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Comparators/probes/scope-probe.mjs
  - Comparators/probes/instance-surface-probe.mjs
  - Comparators/probes/public-declaration-probe.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/ScopeProbeTests.mjs

<!-- G6-R-TASK:P00-T005:dcf9a7d841b40e7b997a81e3069d7cd528b974a462ae43c0a5b21655f856cc57 -->

### P00-T005 — Implement separate wall and high-resolution clock domains

- Record SHA-256: `dcf9a7d841b40e7b997a81e3069d7cd528b974a462ae43c0a5b21655f856cc57`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T001` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T005`
- Evidence commit message: `evidence(monacode): complete P00-T005`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T005.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Environment/MonaClockTests.swift`

### Stage `red`

- verification-command: `P00-T005.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Represent wall-clock milliseconds and monotonic high-resolution time as separate injected protocols.`
- implementation-operation: `Preserve injected binary64 traces exactly.`
- implementation-operation: `Classify all frozen timing occurrences without substituting one domain for another.`

### Stage `green`

- verification-command: `P00-T005.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Environment/MonaClock.swift
  - Sources/MonaCode/Environment/MonaWallClock.swift
  - Sources/MonaCode/Environment/MonaHighResolutionClock.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Environment/MonaClockTests.swift

<!-- G6-R-TASK:P00-T006:00c276a7e5eeb917bcae8de7d7ccbe8fe5498dee0b7f2dce4f6a26053c4dad35 -->

### P00-T006 — Implement deterministic random, cryptographic random, and Number-to-string sources

- Record SHA-256: `00c276a7e5eeb917bcae8de7d7ccbe8fe5498dee0b7f2dce4f6a26053c4dad35`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T001` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T006`
- Evidence commit message: `evidence(monacode): complete P00-T006`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T006.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Environment/MonaEntropyTests.swift`

### Stage `red`

- verification-command: `P00-T006.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Expose one injectable shared random sequence for every retained consumer.`
- implementation-operation: `Produce canonical lowercase UUID version 4 values from injected bytes.`
- implementation-operation: `Implement the finite radix-10 and radix-16 conversion profile required by frozen vectors.`

### Stage `green`

- verification-command: `P00-T006.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Environment/MonaRandomDoubleSource.swift
  - Sources/MonaCode/Environment/MonaCryptoRandomSource.swift
  - Sources/MonaCode/Environment/MonaNumberToString.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Environment/MonaEntropyTests.swift

<!-- G6-R-TASK:P00-T007:f648d18de524510ccaa821dfe8e8714df43c77eb92e68c03fd227c3eb1a9af6a -->

### P00-T007 — Separate immutable UI localization profile from runtime locale

- Record SHA-256: `f648d18de524510ccaa821dfe8e8714df43c77eb92e68c03fd227c3eb1a9af6a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T001` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T007`
- Evidence commit message: `evidence(monacode): complete P00-T007`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T007.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Environment/MonaLocaleBoundaryTests.swift`

### Stage `red`

- verification-command: `P00-T007.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Capture runtime locale, calendar, numbering system, and time zone once at startup.`
- implementation-operation: `Select UI message profile only from the explicit environment option.`
- implementation-operation: `Reject unsupported profile identifiers with a typed error.`

### Stage `green`

- verification-command: `P00-T007.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Environment/MonaRuntimeLocale.swift
  - Sources/MonaCode/Environment/MonaCodeEnvironment.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Environment/MonaLocaleBoundaryTests.swift

<!-- G6-R-TASK:P00-T008:cd8ab023a9b4f1c4169cfd2eb73bdc15da3f58c82ea6a0e1a00817eb9edbab02 -->

### P00-T008 — Build the differential fixture and comparator harness

- Record SHA-256: `cd8ab023a9b4f1c4169cfd2eb73bdc15da3f58c82ea6a0e1a00817eb9edbab02`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T004`, `P00-T005`, `P00-T006`, `P00-T007` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T008`
- Evidence commit message: `evidence(monacode): complete P00-T008`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T008.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Differential/DifferentialHarnessTests.swift`

### Stage `red`

- verification-command: `P00-T008.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run M0, M1, and native subjects with one identical injected environment trace.`
- implementation-operation: `Persist raw UTF-16 inputs and outputs without Unicode repair.`
- implementation-operation: `Distinguish exact and native-adapted comparison domains in every fixture.`

### Stage `green`

- verification-command: `P00-T008.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Differential/runner.mjs
  - Tools/Differential/fixture-schema.json
  - Tests/MonaCodeTests/Differential/MonaDifferentialModelProvider.swift
  - Tests/MonaCodeTests/Differential/DifferentialHarnessTests.swift
- modify:
  - _(none)_
- test:
  - _(none)_

<!-- G6-R-TASK:P00-T009:da10e18d57ceeb6032615a7b69640977de9d2f99303da52cacb433598bc33f96 -->

### P00-T009 — Implement the complete Q1-R3 statistical verdict engine

- Record SHA-256: `da10e18d57ceeb6032615a7b69640977de9d2f99303da52cacb433598bc33f96`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T008` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T009`
- Evidence commit message: `evidence(monacode): complete P00-T009`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T009.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/BootstrapStatisticsTests.swift`

### Stage `red`

- verification-command: `P00-T009.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement whole-balanced-block resampling with exactly 1000000 deterministic bootstrap draws.`
- implementation-operation: `Implement positive-ratio, manifest-declared near-zero difference, and discrete-zero verdict forms.`
- implementation-operation: `Reject non-finite, non-positive, negative, zero, and below-resolution component inputs exactly as Q1-R3 defines.`
- implementation-operation: `Evaluate the intersection-union test on unrounded binary64 values.`

### Stage `green`

- verification-command: `P00-T009.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tests/BenchmarkHarness/BenchmarkRunner.swift
  - Tests/BenchmarkHarness/BootstrapStatistics.swift
  - Tests/BenchmarkHarness/CellManifest.swift
  - Tests/BenchmarkHarness/BootstrapStatisticsTests.swift
- modify:
  - _(none)_
- test:
  - _(none)_

<!-- G6-R-TASK:P00-T010:c9316bc12ee5584deacb8f9809d89894c06f4d5ab2bb31aa3d03c0af5e721740 -->

### P00-T010 — Enforce font provenance, cold launch, display isolation, and refresh cells

- Record SHA-256: `c9316bc12ee5584deacb8f9809d89894c06f4d5ab2bb31aa3d03c0af5e721740`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T009` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T010`
- Evidence commit message: `evidence(monacode): complete P00-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Q1R4ControlsTests.swift`

### Stage `red`

- verification-command: `P00-T010.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Hash every used font file and table and record variation axes plus run coverage.`
- implementation-operation: `Run each cold sample with a fresh profile and fresh process tree.`
- implementation-operation: `Lock every measurement block to the built-in display and one exact refresh cell.`
- implementation-operation: `Keep 60 Hz and 120 Hz deadlines separate without changing the relative no-regression threshold.`

### Stage `green`

- verification-command: `P00-T010.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tests/BenchmarkHarness/Q1R4FontProvenance.swift
  - Tests/BenchmarkHarness/ColdLaunchManager.swift
  - Tests/BenchmarkHarness/DisplayModeEnforcer.swift
  - Tests/BenchmarkHarness/Q1R4ControlsTests.swift
- modify:
  - _(none)_
- test:
  - _(none)_

<!-- G6-R-TASK:P00-T011:583eafe8670266ea940d704fe621f6855acacab59e949403854c107922401a29 -->

### P00-T011 — Collect a privacy-filtered QEnvironmentID and enforce formal preflight

- Record SHA-256: `583eafe8670266ea940d704fe621f6855acacab59e949403854c107922401a29`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T007`, `P00-T010` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T011`
- Evidence commit message: `evidence(monacode): complete P00-T011`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T011.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/QEnvironmentCollectorTests.mjs`

### Stage `red`

- verification-command: `P00-T011.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Collect the exact OS, toolchain, architecture, display, input-source, runtime-locale, Chrome, and ICU fields fixed by G5-R.`
- implementation-operation: `Reject serial, account, user, UUID, UDID, and UUID-shaped values recursively.`
- implementation-operation: `Require externalDisplayCount equal to zero for every formal correctness or performance run.`

### Stage `green`

- verification-command: `P00-T011.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Qualification/QEnvironmentCollector.swift
  - Tools/Qualification/qenvironment-schema.json
  - Tests/PlanStructureTests/QEnvironmentCollectorTests.mjs
- modify:
  - _(none)_
- test:
  - _(none)_

<!-- G6-R-TASK:P00-T012:02aa3e4a50f9955a31ba72880e7d227a8120075e8a81e46ceac04f60b383c0fd -->

### P00-T012 — Integrate Phase 00 gates without claiming product evidence

- Record SHA-256: `02aa3e4a50f9955a31ba72880e7d227a8120075e8a81e46ceac04f60b383c0fd`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T002`, `P00-T004`, `P00-T008`, `P00-T009`, `P00-T010`, `P00-T011` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P00-T012`
- Evidence commit message: `evidence(monacode): complete P00-T012`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-00/P00-T012.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/Phase00IntegrationTests.mjs`

### Stage `red`

- verification-command: `P00-T012.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Wire every Phase 00 test and preflight into one structural gate.`
- implementation-operation: `Keep every output state planned or structurally verified until future product execution supplies empirical evidence.`
- implementation-operation: `Fail when any comparator, scope, privacy, statistics, font, cold-launch, display, or module-boundary gate is absent.`

### Stage `green`

- verification-command: `P00-T012.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - _(none)_
- modify:
  - Package.swift
- test:
  - Tests/PlanStructureTests/Phase00IntegrationTests.mjs
