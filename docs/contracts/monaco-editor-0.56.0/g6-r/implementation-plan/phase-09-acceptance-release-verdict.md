<!-- G6-R-PHASE:09 -->

# Phase 09 — Acceptance and release verdict

- Phase: `09`
- Title: Acceptance and release verdict
- Document: `implementation-plan/phase-09-acceptance-release-verdict.md`
- Dependencies: `08` 
- Tasks: 30

## Tasks

<!-- G6-R-TASK:P09-T001:5e1f0f8d54d8524ad405cca75cbe778c96b886dde585387d2b721ffe3c587e5a -->

### P09-T001 — Recollect and finalize the per-run privacy-filtered QEnvironmentID

- Record SHA-256: `5e1f0f8d54d8524ad405cca75cbe778c96b886dde585387d2b721ffe3c587e5a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P08-T016` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T001`
- Evidence commit message: `evidence(monacode): complete P09-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/FormalQEnvironmentPreflightTests.mjs`

### Stage `red`

- verification-command: `P09-T001.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Collect a fresh environment identity immediately before each formal run.`
- implementation-operation: `Require macOS build 25G76, Chrome 151.0.7922.138 with pinned binary and ICU hashes, arm64, built-in display only, zero external displays, exact 60 or 120 Hz cell, required ABC and SCIM.ITABC input sources, runtime locale fields, and manifest-approved fonts.`
- implementation-operation: `Recursively reject serial, account, user, UUID, UDID, raw identity keys, and UUID-shaped values in every produced artifact.`
- implementation-operation: `Bind the environment, six static candidate hashes, source revision, and run nonce-free identifier by SHA-256.`

### Stage `green`

- verification-command: `P09-T001.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Qualification/finalize-qenvironment.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/FormalQEnvironmentPreflightTests.mjs

<!-- G6-R-TASK:P09-T002:554a1e88227f8972e134b7bb27265181c2698ec1f86197a2ec5eafb7d9ee33be -->

### P09-T002 — Join all seven candidates into one qualified acceptance set

- Record SHA-256: `554a1e88227f8972e134b7bb27265181c2698ec1f86197a2ec5eafb7d9ee33be`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P08-T016`, `P09-T001` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T002`
- Evidence commit message: `evidence(monacode): complete P09-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/QualifiedCandidateSetTests.mjs`

### Stage `red`

- verification-command: `P09-T002.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Require exactly seven candidate names and validate every schema, hash, source revision, environment predicate, dependency edge, and mutual reference.`
- implementation-operation: `Reject stale, duplicate, extra, mixed-revision, pre-environment, or post-source-change artifacts.`
- implementation-operation: `Emit one qualified set hash consumed unchanged by every C/P and cross-cutting task.`

### Stage `green`

- verification-command: `P09-T002.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/PlanStructureTests/QualifiedCandidateSetTests.mjs

<!-- G6-R-TASK:P09-T010:bcfa3213b6e5066bd64083e0102688888fcf9ffe8ee5f8ed103c7416ad7b8ce2 -->

### P09-T010 — Run C01: model and exact semantic equivalence

- Record SHA-256: `bcfa3213b6e5066bd64083e0102688888fcf9ffe8ee5f8ed103c7416ad7b8ce2`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T013`, `P02-T009`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T010`
- Evidence commit message: `evidence(monacode): complete P09-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C01Tests.swift`

### Stage `red`

- verification-command: `P09-T010.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Compare base values, URI, raw UTF-16 Piece Tree, 70 model members, transactions, undo, decorations, search, RegExp, and Unicode outputs against M0 and M1.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T010.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C01Tests.swift

<!-- G6-R-TASK:P09-T011:19da923e96c0c0e4804f2500d3b909da05ecab13afc3170be5d130f605df4111 -->

### P09-T011 — Run C02: environment, locale, clock, entropy, and intrinsic equivalence

- Record SHA-256: `19da923e96c0c0e4804f2500d3b909da05ecab13afc3170be5d130f605df4111`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T012`, `P02-T009`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T011`
- Evidence commit message: `evidence(monacode): complete P09-T011`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T011.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C02Tests.swift`

### Stage `red`

- verification-command: `P09-T011.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Replay identical wall-clock, high-resolution clock, entropy, locale, case, collation, normalization, number, codec, and hash traces across M0, M1, and native.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T011.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C02Tests.swift

<!-- G6-R-TASK:P09-T012:dbc620a9caa920afb5304cf9a5f8b2d048790ea8d0f0ee67013fa1dfa68b2d9f -->

### P09-T012 — Run C03: projection, layout, scroll, and geometry equivalence

- Record SHA-256: `dbc620a9caa920afb5304cf9a5f8b2d048790ea8d0f0ee67013fa1dfa68b2d9f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T012`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T012`
- Evidence commit message: `evidence(monacode): complete P09-T012`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T012.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C03Tests.swift`

### Stage `red`

- verification-command: `P09-T012.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Compare projection, wrapping, folding, injected text, vertical indexes, scroll order, shaping, raw-offset geometry, stamps, and bounded failure behavior.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T012.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C03Tests.swift

<!-- G6-R-TASK:P09-T013:1a546d7e427e7c209683067e1faa2350b4223d38d118b126c9d1d7dc1c2cc8c9 -->

### P09-T013 — Run C04: public declarations, registries, options, themes, localization, and runtime-style closure

- Record SHA-256: `1a546d7e427e7c209683067e1faa2350b4223d38d118b126c9d1d7dc1c2cc8c9`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T200`, `P07-T008`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T013`
- Evidence commit message: `evidence(monacode): complete P09-T013`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T013.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C04Tests.swift`

### Stage `red`

- verification-command: `P09-T013.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Validate all 555 public paths, registry identities, option boundaries, theme assets, 2120 messages, native type adaptations, and X1-R occurrence sets.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T013.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C04Tests.swift

<!-- G6-R-TASK:P09-T014:726401c88fe4a08743dbd145106ea792a0ec7e6cec2ee99367d2ee4c29a19790 -->

### P09-T014 — Run C05: retained feature and diff equivalence

- Record SHA-256: `726401c88fe4a08743dbd145106ea792a0ec7e6cec2ee99367d2ee4c29a19790`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T200`, `P07-T010`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T014`
- Evidence commit message: `evidence(monacode): complete P09-T014`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T014.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C05Tests.swift`

### Stage `red`

- verification-command: `P09-T014.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Execute all 62 retained feature entry points, five instance sequences, legacy and advanced diff, timeout, cache, and native replacement behavior.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T014.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C05Tests.swift

<!-- G6-R-TASK:P09-T015:56053bd2bc8f7ec56d7f24501e95798f320fcf970a2e2267cb7e21814eb42267 -->

### P09-T015 — Run C06: provider, LSP, snippet, and Markdown equivalence

- Record SHA-256: `56053bd2bc8f7ec56d7f24501e95798f320fcf970a2e2267cb7e21814eb42267`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P06-T010`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T015`
- Evidence commit message: `evidence(monacode): complete P09-T015`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T015.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C06Tests.swift`

### Stage `red`

- verification-command: `P09-T015.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Validate 30 provider surfaces, 25 LSP mappings, five direct-only paths, transport, framing, JSON-RPC, session, fallback, snippet, and hostile Markdown matrices.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T015.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C06Tests.swift

<!-- G6-R-TASK:P09-T016:a8dc2505439083ad5ea18d746ba51b0c6a91148a6e451241513f7cb43ca80b64 -->

### P09-T016 — Run C07: native input, transfer, accessibility, and workspace-edit equivalence

- Record SHA-256: `a8dc2505439083ad5ea18d746ba51b0c6a91148a6e451241513f7cb43ca80b64`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T016`, `P07-T006`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T016`
- Evidence commit message: `evidence(monacode): complete P09-T016`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T016.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C07Tests.swift`

### Stage `red`

- verification-command: `P09-T016.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run ABC and Pinyin, chords, multi-cursor input, pointer, scroll, menu, copy/cut/paste, drag/drop, Services, VoiceOver, focus, announcements, and four WorkspaceEdit outcomes.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T016.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C07Tests.swift

<!-- G6-R-TASK:P09-T017:d59c9ef69fc833d882633a88e79747754ab9e1d2cdb0b23e90ff7a69f6b7ce34 -->

### P09-T017 — Run C08: renderer correctness and frozen branch parity

- Record SHA-256: `d59c9ef69fc833d882633a88e79747754ab9e1d2cdb0b23e90ff7a69f6b7ce34`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T012`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T017`
- Evidence commit message: `evidence(monacode): complete P09-T017`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T017.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C08Tests.swift`

### Stage `red`

- verification-command: `P09-T017.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Validate every Core Graphics golden, scale, subpixel phase, fallback, color glyph, generation, failure, and the frozen Phase 03 Metal absence-or-parity branch.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T017.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C08Tests.swift

<!-- G6-R-TASK:P09-T018:51587e693da34c987dda3da56daf3ada6b25fde43c2a6b5ef1961547a2b50884 -->

### P09-T018 — Run C09: delivery views, hosts, lifetimes, services, and resource bounds

- Record SHA-256: `51587e693da34c987dda3da56daf3ada6b25fde43c2a6b5ef1961547a2b50884`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T015`, `P07-T010`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T018`
- Evidence commit message: `evidence(monacode): complete P09-T018`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T018.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C09Tests.swift`

### Stage `red`

- verification-command: `P09-T018.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Validate three products, three views, four wrappers, seven host groups, ten concrete host types, service and cache exact sets, lifetime ownership, plateau, and workspace rollback.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T018.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C09Tests.swift

<!-- G6-R-TASK:P09-T019:4618f401d944b8a38648da60cddfcb98a6a645bd9c1e8e60f5358be780da2346 -->

### P09-T019 — Run C10: release package, API, dependency, resource, hash, and license closure

- Record SHA-256: `4618f401d944b8a38648da60cddfcb98a6a645bd9c1e8e60f5358be780da2346`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P08-T016`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T019`
- Evidence commit message: `evidence(monacode): complete P09-T019`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T019.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Correctness/C10Tests.swift`

### Stage `red`

- verification-command: `P09-T019.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Validate release architecture and deployment, three-product graph, symbol graphs, API digests, linked libraries, resources, seven candidates, artifact hashes, forbidden absences, and license notices.`
- implementation-operation: `Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture, native-adapted assertion, failure row, and exact-set check assigned to the gate.`
- implementation-operation: `Bind comparator, native, environment, candidate, source revision, fixture, and output hashes in one evidence manifest.`
- implementation-operation: `Treat every missing, skipped, stale, malformed, canceled, or unauthorized case as not-passed.`

### Stage `green`

- verification-command: `P09-T019.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Correctness/C10Tests.swift

<!-- G6-R-TASK:P09-T030:fcce6a0fc94d63225f61493b55b173a25802dc777ccb2c54a3b59e30e72ed19f -->

### P09-T030 — Run P00: cold startup

- Record SHA-256: `fcce6a0fc94d63225f61493b55b173a25802dc777ccb2c54a3b59e30e72ed19f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T012`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T030`
- Evidence commit message: `evidence(monacode): complete P09-T030`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T030.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P00WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T030.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Measure 50 fresh-profile, fresh-process-tree launches of the 1 MiU16/100000-line corpus from launch to ready, then terminate each tree.`
- implementation-operation: `Collect 50 cold balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T030.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P00WorkloadTests.swift

<!-- G6-R-TASK:P09-T031:01a0a19e69977bb269f5bb80faa15ef82178e28273aefc06308fff3305bc2fe3 -->

### P09-T031 — Run P01: model load

- Record SHA-256: `01a0a19e69977bb269f5bb80faa15ef82178e28273aefc06308fff3305bc2fe3`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T013`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T031`
- Evidence commit message: `evidence(monacode): complete P09-T031`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T031.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P01WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T031.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Load 1 MiU16 and 100 MiU16 raw-text corpora across LF, CRLF, valid Unicode, isolated-surrogate, and mixed-line families.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T031.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P01WorkloadTests.swift

<!-- G6-R-TASK:P09-T032:26ba31faa2fcffb239591d3234d2820bebcb804067c422c1bd093550dc70add3 -->

### P09-T032 — Run P02: typing and undo

- Record SHA-256: `26ba31faa2fcffb239591d3234d2820bebcb804067c422c1bd093550dc70add3`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T001`, `P04-T005`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T032`
- Evidence commit message: `evidence(monacode): complete P09-T032`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T032.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P02WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T032.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Execute 10000 ABC typing, delete, selection, undo, and redo actions on the 1 MiU16 corpus.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T032.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P02WorkloadTests.swift

<!-- G6-R-TASK:P09-T033:17ba704b196b295b74d96da8b833d9968f01f0d84ba9da80f190c6b1f9e0bdb0 -->

### P09-T033 — Run P03: batch edits

- Record SHA-256: `17ba704b196b295b74d96da8b833d9968f01f0d84ba9da80f190c6b1f9e0bdb0`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T009`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T033`
- Evidence commit message: `evidence(monacode): complete P09-T033`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T033.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P03WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T033.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Prepare and commit 1, 100, and 10000 non-overlapping edits while measuring preparation and commit components separately.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T033.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P03WorkloadTests.swift

<!-- G6-R-TASK:P09-T034:255c53df858982a5002e03589bbfc082cbbb1fc5296d9b52497199839f9d68cf -->

### P09-T034 — Run P04: vertical scroll

- Record SHA-256: `255c53df858982a5002e03589bbfc082cbbb1fc5296d9b52497199839f9d68cf`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T012`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T034`
- Evidence commit message: `evidence(monacode): complete P09-T034`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T034.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P04WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T034.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Inject at least 10000 intervals over the 100 MiU16/1000000-line corpus in separate exact 60 Hz and 120 Hz cells.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T034.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P04WorkloadTests.swift

<!-- G6-R-TASK:P09-T035:ad06338a58e7f55f34020dfa9d760fa749123179232b33acefa37942b44bfbcf -->

### P09-T035 — Run P05: long line

- Record SHA-256: `ad06338a58e7f55f34020dfa9d760fa749123179232b33acefa37942b44bfbcf`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T012`, `P05-T005`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T035`
- Evidence commit message: `evidence(monacode): complete P09-T035`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T035.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P05WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T035.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Render 1000000-unit lines with stopRenderingLineAfter equal to 10000 and -1 across scale, fallback, and subpixel cells.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T035.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P05WorkloadTests.swift

<!-- G6-R-TASK:P09-T036:8eab42f6389385253f6a77615ab1774da10d6bd3dc9bc002da6fb35f5c4db736 -->

### P09-T036 — Run P06: wrap and resize

- Record SHA-256: `8eab42f6389385253f6a77615ab1774da10d6bd3dc9bc002da6fb35f5c4db736`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T012`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T036`
- Evidence commit message: `evidence(monacode): complete P09-T036`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T036.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P06WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T036.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Cycle widths 320, 768, and 1440 points 10000 times over 100000 mixed-script lines with fold, inlay, and variable-height matrices.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T036.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P06WorkloadTests.swift

<!-- G6-R-TASK:P09-T037:9e0cf5c945f612e16d65659432bb4181edf0d35d886526376a2703be7e135952 -->

### P09-T037 — Run P07: decorations

- Record SHA-256: `9e0cf5c945f612e16d65659432bb4181edf0d35d886526376a2703be7e135952`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T002`, `P03-T012`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T037`
- Evidence commit message: `evidence(monacode): complete P09-T037`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T037.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P07WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T037.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Update 100000 model decorations with 10000 visible/offscreen mixed actions and exact interval-operation counters.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T037.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P07WorkloadTests.swift

<!-- G6-R-TASK:P09-T038:8c474d6c618116e22dfb110555369df6d2be81b08fc5de7580660a6adaf6b62b -->

### P09-T038 — Run P08: find and replace

- Record SHA-256: `8c474d6c618116e22dfb110555369df6d2be81b08fc5de7580660a6adaf6b62b`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T009`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T038`
- Evidence commit message: `evidence(monacode): complete P09-T038`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T038.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P08WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T038.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run literal, /gimu, zero-length, capture replacement, density 0/0.1/10/1000 per KiB, RegExp consumer, case, normalization, binary64, decoder, and hash matrices on 10 MiU16.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T038.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P08WorkloadTests.swift

<!-- G6-R-TASK:P09-T039:9ee520001c426512c1e638478f1235de609bf9dd3732e15a947c723ae4d4e1d3 -->

### P09-T039 — Run P09: multi-cursor and snippet

- Record SHA-256: `9ee520001c426512c1e638478f1235de609bf9dd3732e15a947c723ae4d4e1d3`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T005`, `P06-T007`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T039`
- Evidence commit message: `evidence(monacode): complete P09-T039`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T039.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P09WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T039.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run type, paste, delete, undo, overlap, snippet insertion, 39 variables, clipboard spread, time snapshot, random, and UUID traces for 1, 100, and 10000 cursors.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T039.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P09WorkloadTests.swift

<!-- G6-R-TASK:P09-T040:6776082a2170cf874acccdf15dca1321a2009981a1cf951c5109d1d659bd4b53 -->

### P09-T040 — Run P10: diff and multi-diff

- Record SHA-256: `6776082a2170cf874acccdf15dca1321a2009981a1cf951c5109d1d659bd4b53`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P07-T002`, `P07-T009`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T040`
- Evidence commit message: `evidence(monacode): complete P09-T040`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T040.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P10WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T040.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run legacy/advanced diff on 1/10/50 MiU16 with 1/10/30 percent changes and multi-diff 1/10/100 items of 1 MiU16, including timeout and cache cells.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T040.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P10WorkloadTests.swift

<!-- G6-R-TASK:P09-T041:d9bd0b9979ae7441865e7024534afbfa64702828cc6922b65c6ee2ade9bbce12 -->

### P09-T041 — Run P11: provider and LSP

- Record SHA-256: `d9bd0b9979ae7441865e7024534afbfa64702828cc6922b65c6ee2ade9bbce12`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P06-T010`, `P07-T003`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T041`
- Evidence commit message: `evidence(monacode): complete P09-T041`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T041.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P11WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T041.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run 30 provider surfaces, 25 mappings, 0/1/10000 results, cancellation, stale, resolve, Markdown, session, framing, and 0/10/100 ms injected transport delays with adapter delay subtraction.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T041.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P11WorkloadTests.swift

<!-- G6-R-TASK:P09-T042:e39ad3ced79159aa769c975f85b33b6e3f244fac9629c121033c2c391b0c94c9 -->

### P09-T042 — Run P12: shared model

- Record SHA-256: `e39ad3ced79159aa769c975f85b33b6e3f244fac9629c121033c2c391b0c94c9`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T014`, `P07-T009`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T042`
- Evidence commit message: `evidence(monacode): complete P09-T042`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T042.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P12WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T042.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Drive four editors over one 10 MiU16 model with independent wrap, fold, selection, and scroll state through 10000 interleaved actions and commit fanout.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T042.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P12WorkloadTests.swift

<!-- G6-R-TASK:P09-T043:a88a2774bab648d9c074eb111caf3c9ed752fcf73b55af42ba5c71fc0f70d004 -->

### P09-T043 — Run P13: IME and accessibility queries

- Record SHA-256: `a88a2774bab648d9c074eb111caf3c9ed752fcf73b55af42ba5c71fc0f70d004`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T016`, `P09-T002` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T043`
- Evidence commit message: `evidence(monacode): complete P09-T043`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T043.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/BenchmarkHarness/Workloads/P13WorkloadTests.swift`

### Stage `red`

- verification-command: `P09-T043.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run ABC/Pinyin marked-text traces, 10000 small accessibility range queries, 100 full-document queries, VoiceOver on/off, and callback latency.`
- implementation-operation: `Collect 30 hot balanced blocks per valid cell, with attempt cap 2x, six balanced AB/BA orderings where applicable, thermal-state sampling, no outlier deletion, and separate total/component metrics.`
- implementation-operation: `Evaluate M0 and M1 independently with positive log-ratio, manifest-declared near-zero difference, or discrete-zero verdict form; resample whole balanced blocks 1000000 times.`
- implementation-operation: `Require the one-sided 95 percent bootstrap upper bound to be at most zero on unrounded binary64 values for every comparator and cell.`
- implementation-operation: `Keep exact 60 Hz and 120 Hz frame cells separate; refresh rate changes only the deadline and never the relative no-regression threshold.`

### Stage `green`

- verification-command: `P09-T043.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/BenchmarkHarness/Workloads/P13WorkloadTests.swift

<!-- G6-R-TASK:P09-T050:40e6baf4834baaa3770ae66dc84f557b814aa302b12764a80dca610c6df955cb -->

### P09-T050 — Run lifecycle, 24-hour soak, sanitizers, and validation layers

- Record SHA-256: `40e6baf4834baaa3770ae66dc84f557b814aa302b12764a80dca610c6df955cb`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P09-T002`, `P09-T030`, `P09-T031`, `P09-T032`, `P09-T033`, `P09-T034`, `P09-T035`, `P09-T036`, `P09-T037`, `P09-T038`, `P09-T039`, `P09-T040`, `P09-T041`, `P09-T042`, `P09-T043` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T050`
- Evidence commit message: `evidence(monacode): complete P09-T050`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T050.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/CrossCutting/LifecycleSoakSanitizerTests.swift`

### Stage `red`

- verification-command: `P09-T050.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run 1000 create, attach, detach, and dispose cycles and require weak accounting to return to the warm baseline.`
- implementation-operation: `Run 24 hours of mixed P02-P13 actions and require quiescent allocations and counters to remain within MonaCacheManifest bounds.`
- implementation-operation: `Run complete ASan, TSan, and UBSan suites separately with zero findings and Main Thread Checker with zero findings.`
- implementation-operation: `Run Metal validation only for the triggered-and-required renderer branch; record not-applicable for the absent branch.`
- implementation-operation: `Treat crash, hang, data loss, half commit, leak, race, undefined behavior, validation error, or counter overflow as failure.`

### Stage `green`

- verification-command: `P09-T050.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/CrossCutting/LifecycleSoakSanitizerTests.swift

<!-- G6-R-TASK:P09-T051:3898d7e6ae8441a34988794d2d979e2e0a02d042b926ad8075c505ba7c92e2ad -->

### P09-T051 — Run failure-injection and algorithmic complexity gates

- Record SHA-256: `3898d7e6ae8441a34988794d2d979e2e0a02d042b926ad8075c505ba7c92e2ad`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P09-T002`, `P09-T010`, `P09-T011`, `P09-T012`, `P09-T013`, `P09-T014`, `P09-T015`, `P09-T016`, `P09-T017`, `P09-T018`, `P09-T019` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T051`
- Evidence commit message: `evidence(monacode): complete P09-T051`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T051.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/CrossCutting/FailureAndComplexityTests.swift`

### Stage `red`

- verification-command: `P09-T051.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Inject every declared recoverable allocation, shaping, renderer resource, LSP framing/session, provider, host, workspace, IME, cache, reentry, cancellation, and disposal failure.`
- implementation-operation: `Require typed failure plus rollback or drop with zero half-committed state; exclude fatal OOM from recoverable claims.`
- implementation-operation: `Use operation counters to prove Piece Tree, decoration, projection, vertical index, layout, renderer, search, diff, provider, and fanout growth classes retain Monaco upper bounds.`
- implementation-operation: `Fail immediately on any worse asymptotic order, viewport full-document scan, or work not bounded by visible rows plus changed dependencies.`

### Stage `green`

- verification-command: `P09-T051.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/CrossCutting/FailureAndComplexityTests.swift

<!-- G6-R-TASK:P09-T052:c033b83326495f21c873e7a0a0602ef6a4bf933089a4c98b0554f880037e67d9 -->

### P09-T052 — Validate the frozen Phase 03 renderer decision without source changes

- Record SHA-256: `c033b83326495f21c873e7a0a0602ef6a4bf933089a4c98b0554f880037e67d9`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P09-T012`, `P09-T017`, `P09-T034`, `P09-T035`, `P09-T036` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T052`
- Evidence commit message: `evidence(monacode): complete P09-T052`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T052.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/CrossCutting/RendererDecisionValidationTests.swift`

### Stage `red`

- verification-command: `P09-T052.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Verify the immutable Phase 03 decision hash, Core Graphics completion predecessor, trigger metric scope, selected source set, and absence-or-parity evidence.`
- implementation-operation: `Confirm every current renderer correctness and performance cell agrees with the frozen branch.`
- implementation-operation: `Reject any Phase 09 source creation, decision recomputation, cross-domain trigger, missing fallback, or unvalidated triggered branch.`

### Stage `green`

- verification-command: `P09-T052.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/CrossCutting/RendererDecisionValidationTests.swift

<!-- G6-R-TASK:P09-T099:41944f0c8c835b15a75a8e74e4b98cc5cbc39c0ae89aba39823af5d7d4147c9b -->

### P09-T099 — Aggregate the final all-or-nothing G5-R release verdict

- Record SHA-256: `41944f0c8c835b15a75a8e74e4b98cc5cbc39c0ae89aba39823af5d7d4147c9b`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P09-T002`, `P09-T010`, `P09-T011`, `P09-T012`, `P09-T013`, `P09-T014`, `P09-T015`, `P09-T016`, `P09-T017`, `P09-T018`, `P09-T019`, `P09-T030`, `P09-T031`, `P09-T032`, `P09-T033`, `P09-T034`, `P09-T035`, `P09-T036`, `P09-T037`, `P09-T038`, `P09-T039`, `P09-T040`, `P09-T041`, `P09-T042`, `P09-T043`, `P09-T050`, `P09-T051`, `P09-T052` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P09-T099`
- Evidence commit message: `evidence(monacode): complete P09-T099`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-09/P09-T099.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs`

### Stage `red`

- verification-command: `P09-T099.RED.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Verify one source revision, one seven-candidate set, one exact qualified environment, C01-C10, every P00-P13 M0/M1 cell, lifecycle, soak, sanitizers, validation, failure injection, complexity, and renderer decision evidence.`
- implementation-operation: `Reject missing, failed, skipped, stale, malformed, unauthorized, mixed-revision, mixed-environment, unhashed, or unsigned-input evidence.`
- implementation-operation: `Emit passed only when every prerequisite passes; otherwise emit not-passed with the complete sorted blocker set.`
- implementation-operation: `Keep the frozen G5-R design contract unchanged and record empirical implementation state only in the verdict and candidate artifacts.`

### Stage `green`

- verification-command: `P09-T099.GREEN.001` (kind=process, network=forbidden, timeout=1800000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Release/release-verdict.mjs
  - RELEASE_VERDICT.md
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs
