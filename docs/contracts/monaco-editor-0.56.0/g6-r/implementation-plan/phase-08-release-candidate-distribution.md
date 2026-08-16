<!-- G6-R-PHASE:08 -->

# Phase 08 — Release candidate and distribution

- Phase: `08`
- Title: Release candidate and distribution
- Document: `implementation-plan/phase-08-release-candidate-distribution.md`
- Dependencies: `07` 
- Tasks: 10

## Tasks

<!-- G6-R-TASK:P08-T001:62f7fc757fed1fe88cac97b18505e6f811c78543f260d8e9349381c952e24277 -->

### P08-T001 — Build the frozen three-product release package

- Record SHA-256: `62f7fc757fed1fe88cac97b18505e6f811c78543f260d8e9349381c952e24277`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P07-T011` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T001`
- Evidence commit message: `evidence(monacode): complete P08-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/ReleaseBuildTests.mjs`

### Stage `red`

- verification-command: `P08-T001.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Build arm64 macOS 26.0-or-newer release artifacts for MonaCode, MonaCodeAppKit, and MonaCodeSwiftUI plus the sample host.`
- implementation-operation: `Record compiler, SDK, deployment target, architecture, binary UUID-independent hashes, and complete artifact paths.`
- implementation-operation: `Reject debug-only, unsigned-input, stale-source, extra-product, or missing-target output.`

### Stage `green`

- verification-command: `P08-T001.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Release/build-release.sh
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/ReleaseBuildTests.mjs

<!-- G6-R-TASK:P08-T002:1d134286e8c9d03b5f26fe952f93809e9eac5af6340e5e54de6a16feff61fe1a -->

### P08-T002 — Scan package graph, symbols, links, resources, and forbidden runtimes

- Record SHA-256: `1d134286e8c9d03b5f26fe952f93809e9eac5af6340e5e54de6a16feff61fe1a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P08-T001` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T002`
- Evidence commit message: `evidence(monacode): complete P08-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/DistributionScanTests.mjs`

### Stage `red`

- verification-command: `P08-T002.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run package dump, describe, and dependency scans for exact products and targets.`
- implementation-operation: `Generate and compare symbol graphs plus API digester output for all three products.`
- implementation-operation: `Enumerate linked dylibs, embedded resources, exported symbols, source maps, scripts, WASM, language content, and third-party runtime classes.`
- implementation-operation: `Reject every linked or bundled item outside the contract allowlist.`

### Stage `green`

- verification-command: `P08-T002.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Release/scan-distribution.swift
  - Tools/Release/scan-symbol-graphs.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/DistributionScanTests.mjs

<!-- G6-R-TASK:P08-T003:5fa3493b4af2f2c9b5d7aa71c503553ff389801a991a44f8c509340b9e579ca4 -->

### P08-T003 — Assemble exact license provenance and distribution notices

- Record SHA-256: `5fa3493b4af2f2c9b5d7aa71c503553ff389801a991a44f8c509340b9e579ca4`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T005`, `P02-T007`, `P05-T006`, `P05-T007`, `P06-T008`, `P08-T001` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T003`
- Evidence commit message: `evidence(monacode): complete P08-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/LicenseNoticeTests.mjs`

### Stage `red`

- verification-command: `P08-T003.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Assemble Monaco MIT, Monaco localization MIT, Marked 14 MIT, LSP specification CC BY 4.0, Codicon CC BY 4.0 plus Git Logo exception and generator MIT, Unicode-3.0, Chromium ICU, Test262 BSD, and esbuild comparator notices.`
- implementation-operation: `Record DOMPurify, V8/ICU runtime, and vscode-unicode-data as oracle-only or excluded inputs with no derived production code.`
- implementation-operation: `Verify pinned license hashes: LSP 9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188, Chromium ICU e55522d81edc687a341a4411e0776e54ca654e90147f354a90458aaced4116af, Codicon artwork af5e030844efddbc7ab00dcfea8b019703753d4d9f5172d727c533a492aec665, and Codicon code 9906940f61b1f0b533fa7d99baf55178b2808fbe113ea51dfbfad8572ccd5f2b.`
- implementation-operation: `Attach provenance headers to every generated table and asset.`

### Stage `green`

- verification-command: `P08-T003.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Sources/MonaCode/Generated/LICENSE.md
  - Tools/Release/verify-notices.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/LicenseNoticeTests.mjs

<!-- G6-R-TASK:P08-T010:e2545ff378e9599027fc6c32888cab02e0af968e5d4e3fb20f64a39aa14f0396 -->

### P08-T010 — Finalize MonaNativeDeclarationManifest after public API closure

- Record SHA-256: `e2545ff378e9599027fc6c32888cab02e0af968e5d4e3fb20f64a39aa14f0396`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T190`, `P07-T011`, `P08-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T010`
- Evidence commit message: `evidence(monacode): complete P08-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/FinalNativeDeclarationManifestTests.mjs`

### Stage `red`

- verification-command: `P08-T010.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Regenerate all declaration, signature, disposition, owner, symbol, and product rows from the frozen release outputs.`
- implementation-operation: `Verify 555 public paths, five instance surfaces, three views, four SwiftUI types, 62 retained features, and three distinct native colorize replacements.`
- implementation-operation: `Hash every source artifact and mark the candidate final only after zero drift.`

### Stage `green`

- verification-command: `P08-T010.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Candidates/finalize-native-declaration-manifest.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/FinalNativeDeclarationManifestTests.mjs

<!-- G6-R-TASK:P08-T011:37587d7290f19c36214d9bf08e1767076ed5b3a0d121237dee0853dca19e57f0 -->

### P08-T011 — Finalize MonaRegExpUnicodeManifest after all semantic consumers

- Record SHA-256: `37587d7290f19c36214d9bf08e1767076ed5b3a0d121237dee0853dca19e57f0`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T009`, `P06-T007`, `P07-T011`, `P08-T003` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T011`
- Evidence commit message: `evidence(monacode): complete P08-T011`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T011.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/FinalRegExpUnicodeManifestTests.mjs`

### Stage `red`

- verification-command: `P08-T011.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Regenerate six distinct Unicode profiles, ten consumer mappings, Test262 selection, generator inputs, licenses, and output hashes.`
- implementation-operation: `Verify every final semantic consumer appears and no post-finalization product consumer exists.`
- implementation-operation: `Mark the candidate final only after exact provenance reproduction.`

### Stage `green`

- verification-command: `P08-T011.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Candidates/finalize-regexp-unicode-manifest.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/FinalRegExpUnicodeManifestTests.mjs

<!-- G6-R-TASK:P08-T012:09e2bb889538958a30dc9edfc02c6b1c1e58209314a5d39fd159f3ce1bfa5275 -->

### P08-T012 — Finalize MonaEnvironmentManifest after every environment-sensitive consumer

- Record SHA-256: `09e2bb889538958a30dc9edfc02c6b1c1e58209314a5d39fd159f3ce1bfa5275`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T009`, `P07-T008`, `P07-T011`, `P08-T003` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T012`
- Evidence commit message: `evidence(monacode): complete P08-T012`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T012.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/FinalEnvironmentManifestTests.mjs`

### Stage `red`

- verification-command: `P08-T012.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Regenerate clock, entropy, number formatting, locale, calendar, numbering, time zone, case, collation, normalization, and finite-intrinsic occurrence rows.`
- implementation-operation: `Verify set equality against E1-R and X1-R plus generated input and output hashes.`
- implementation-operation: `Mark the candidate final only after the last source consumer and notice input.`

### Stage `green`

- verification-command: `P08-T012.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Candidates/finalize-environment-manifest.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/FinalEnvironmentManifestTests.mjs

<!-- G6-R-TASK:P08-T013:e0a000d44fa93c4f214fb34ccb3c9f6889f6bc14344c86a3bf8f47e5d9b01db0 -->

### P08-T013 — Finalize MonaSourceClosureManifest from the release source set

- Record SHA-256: `e0a000d44fa93c4f214fb34ccb3c9f6889f6bc14344c86a3bf8f47e5d9b01db0`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P07-T008`, `P07-T011`, `P08-T002`, `P08-T003` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T013`
- Evidence commit message: `evidence(monacode): complete P08-T013`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T013.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/FinalSourceClosureManifestTests.mjs`

### Stage `red`

- verification-command: `P08-T013.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Regenerate the complete product source, generated source, resource, notice, finite-runtime, native-style, and explicit-cut inventory from release inputs.`
- implementation-operation: `Include the renderer source branch frozen in Phase 03 and reject every source path created afterward.`
- implementation-operation: `Verify all X1-R set-equality counts and artifact hashes before finalization.`

### Stage `green`

- verification-command: `P08-T013.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Candidates/finalize-source-closure-manifest.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/FinalSourceClosureManifestTests.mjs

<!-- G6-R-TASK:P08-T014:9b508044aa383d638393fbd8b67d459286e6b6ae2eae4a4eb156bc4162a777e6 -->

### P08-T014 — Finalize MonaCacheManifest from all registered caches

- Record SHA-256: `9b508044aa383d638393fbd8b67d459286e6b6ae2eae4a4eb156bc4162a777e6`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P07-T007`, `P07-T011`, `P08-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T014`
- Evidence commit message: `evidence(monacode): complete P08-T014`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T014.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/FinalCacheManifestTests.mjs`

### Stage `red`

- verification-command: `P08-T014.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Regenerate the exact cache identity, owner, key, entry bound, byte bound, invalidation, eviction, counter, and plateau set.`
- implementation-operation: `Scan release symbols and source paths for undeclared cache-like storage.`
- implementation-operation: `Mark the candidate final only when exact-set and all bounds pass.`

### Stage `green`

- verification-command: `P08-T014.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Candidates/finalize-cache-manifest.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/FinalCacheManifestTests.mjs

<!-- G6-R-TASK:P08-T015:edec06032ea7dfeb5003bee63d1a1726b0249b715583119b811303acdcf9c5fb -->

### P08-T015 — Finalize MonaDistributionManifest after package and notice closure

- Record SHA-256: `edec06032ea7dfeb5003bee63d1a1726b0249b715583119b811303acdcf9c5fb`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P08-T001`, `P08-T002`, `P08-T003`, `P08-T010`, `P08-T011`, `P08-T012`, `P08-T013`, `P08-T014` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T015`
- Evidence commit message: `evidence(monacode): complete P08-T015`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T015.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/FinalDistributionManifestTests.mjs`

### Stage `red`

- verification-command: `P08-T015.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Record every release artifact, product, target, architecture, deployment target, symbol graph, dependency, linked dylib, resource, license profile, and SHA-256.`
- implementation-operation: `Join the five preceding static candidates and verify their source revision and hash agreement.`
- implementation-operation: `Record exact absence of every prohibited runtime, resource, service, language bundle, and unlicensed input.`

### Stage `green`

- verification-command: `P08-T015.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Candidates/finalize-distribution-manifest.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/FinalDistributionManifestTests.mjs

<!-- G6-R-TASK:P08-T016:e77cfca5d3b8e2da18c86ead6e2ff0ebe0b3fefd0160512fa52938dad772348f -->

### P08-T016 — Validate the exact six-static-candidate release set

- Record SHA-256: `e77cfca5d3b8e2da18c86ead6e2ff0ebe0b3fefd0160512fa52938dad772348f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P08-T010`, `P08-T011`, `P08-T012`, `P08-T013`, `P08-T014`, `P08-T015` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P08-T016`
- Evidence commit message: `evidence(monacode): complete P08-T016`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-08/P08-T016.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/SixStaticCandidateSetTests.mjs`

### Stage `red`

- verification-command: `P08-T016.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Require exactly the six static candidate names with no duplicate or extra artifact.`
- implementation-operation: `Verify schema, source revision, dependency edges, internal hashes, release hash, and mutual references.`
- implementation-operation: `Exclude QEnvironmentID because it is recollected per formal Phase 09 run.`

### Stage `green`

- verification-command: `P08-T016.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - _(none)_
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/SixStaticCandidateSetTests.mjs
