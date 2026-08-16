<!-- G6-R-PHASE:07 -->

# Phase 07 — Diff, services, host, and source closure

- Phase: `07`
- Title: Diff, services, host, and source closure
- Document: `implementation-plan/phase-07-diff-services-host-source-closure.md`
- Dependencies: `06` 
- Tasks: 11

## Tasks

<!-- G6-R-TASK:P07-T001:c23c6fe6f5f4b428054d1ffd8153658970eb3d0cbf6c0142bd3cb79a700a3e72 -->

### P07-T001 — Implement legacy and advanced diff engines over raw UTF-16

- Record SHA-256: `c23c6fe6f5f4b428054d1ffd8153658970eb3d0cbf6c0142bd3cb79a700a3e72`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T009`, `P06-T010` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T001`
- Evidence commit message: `evidence(monacode): complete P07-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Diff/MonaDiffEngineDifferentialTests.swift`

### Stage `red`

- verification-command: `P07-T001.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Port line hashing, sequence diff, character refinement, moved-block detection, inner changes, and result normalization for both engines.`
- implementation-operation: `Operate on raw UTF-16 ranges and preserve comparator ordering and optional fields.`
- implementation-operation: `Check cancellation and timeout at the frozen algorithm checkpoints.`

### Stage `green`

- verification-command: `P07-T001.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Diff/MonaDiffEngine.swift
  - Sources/MonaCode/Diff/MonaLegacyDiffEngine.swift
  - Sources/MonaCode/Diff/MonaAdvancedDiffEngine.swift
  - Sources/MonaCode/Diff/MonaDiffResult.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Diff/MonaDiffEngineDifferentialTests.swift

<!-- G6-R-TASK:P07-T002:33abb3d6dbec371ab1813bbedf9c2764acfad4bcf09c7e59b1a8887eeee15efa -->

### P07-T002 — Close diff timeouts, caches, maximum size, and unavailable external paths

- Record SHA-256: `33abb3d6dbec371ab1813bbedf9c2764acfad4bcf09c7e59b1a8887eeee15efa`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P07-T001` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T002`
- Evidence commit message: `evidence(monacode): complete P07-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Diff/MonaDiffCoordinatorTests.swift`

### Stage `red`

- verification-command: `P07-T002.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Apply T-1, T, and T+1 timeout truth with injected monotonic time.`
- implementation-operation: `Implement the bounded maximum-11 cache with exact key, hit, miss, invalidation, and eviction semantics.`
- implementation-operation: `Return explicit no-op results for maximum-file-size and external/WASM-unavailable paths.`
- implementation-operation: `Publish only complete results whose model versions still match.`

### Stage `green`

- verification-command: `P07-T002.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Diff/MonaDiffCoordinator.swift
  - Sources/MonaCode/Diff/MonaDiffCache.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Diff/MonaDiffCoordinatorTests.swift

<!-- G6-R-TASK:P07-T003:f632ffc2e68f44f9fcbadbcd38a132e5d805c16ebd5a873e9be910ffcc4c1485 -->

### P07-T003 — Implement 40 standalone services and bounded session state

- Record SHA-256: `f632ffc2e68f44f9fcbadbcd38a132e5d805c16ebd5a873e9be910ffcc4c1485`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T200`, `P06-T010` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T003`
- Evidence commit message: `evidence(monacode): complete P07-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Services/MonaStandaloneServiceTests.swift`

### Stage `red`

- verification-command: `P07-T003.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Instantiate exactly 40 retained services with explicit global or per-editor lifetime ownership.`
- implementation-operation: `Implement bounded session rows for suggestion memory, scope switching, save delay, widget details, and shared state.`
- implementation-operation: `Keep persistence, telemetry transport, notification-progress UI, and signal audio absent.`
- implementation-operation: `Expose nonblocking localized feedback without document-text logging.`

### Stage `green`

- verification-command: `P07-T003.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Services/MonaServiceCollection.swift
  - Sources/MonaCode/Services/MonaStandaloneServices.swift
  - Sources/MonaCode/Services/MonaSessionStore.swift
  - Sources/MonaCode/Services/MonaFeedbackService.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Services/MonaStandaloneServiceTests.swift

<!-- G6-R-TASK:P07-T004:3c6c9d93ed5c3e1b42460760dce787431c0299f9c984e4d3473c5eb3de9821bd -->

### P07-T004 — Project four dialog sites into host-authorized native dialogs

- Record SHA-256: `3c6c9d93ed5c3e1b42460760dce787431c0299f9c984e4d3473c5eb3de9821bd`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T014`, `P07-T003` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T004`
- Evidence commit message: `evidence(monacode): complete P07-T004`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T004.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Services/MonaDialogServiceTests.swift`

### Stage `red`

- verification-command: `P07-T004.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Map exactly four retained dialog call sites to native sheet or alert requests.`
- implementation-operation: `Require an attached authorized host window and expose accepted, canceled, and unavailable outcomes.`
- implementation-operation: `Never fabricate acceptance when presentation is unavailable.`

### Stage `green`

- verification-command: `P07-T004.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Services/MonaDialogService.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Services/MonaDialogServiceTests.swift

<!-- G6-R-TASK:P07-T005:2ea9b4a2fecebd70905f606ecabf3434e320c28921fb2b6ce5f62bc1dc9f5285 -->

### P07-T005 — Implement seven host groups and ten concrete host types

- Record SHA-256: `2ea9b4a2fecebd70905f606ecabf3434e320c28921fb2b6ce5f62bc1dc9f5285`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P06-T009`, `P07-T003` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T005`
- Evidence commit message: `evidence(monacode): complete P07-T005`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T005.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Host/MonaHostContractClosureTests.swift`

### Stage `red`

- verification-command: `P07-T005.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement environment, opener-registry, workspace-edit, command, logging, LSP-transport, and multi-diff-data host groups.`
- implementation-operation: `Expose exactly ten concrete public types with their frozen throwing, nonthrowing, ordering, disposal, and fallback behavior.`
- implementation-operation: `Keep link and code-editor opener registries distinct and traverse last-registered-first.`
- implementation-operation: `Add no implicit URL, file, network, logging, transport, or workspace authority.`

### Stage `green`

- verification-command: `P07-T005.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Sources/MonaCode/Host/MonaHostContracts.swift
  - Sources/MonaCode/Host/MonaOpenerRegistry.swift
  - Sources/MonaCodeAppKit/Host/MonaAppKitHostAdapters.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Host/MonaHostContractClosureTests.swift

<!-- G6-R-TASK:P07-T006:d11bf66705c3f8033550b3eb6ff0f9cf02b556e48ee58208f2d0f70f32fd0330 -->

### P07-T006 — Implement the four-outcome WorkspaceEdit transaction

- Record SHA-256: `d11bf66705c3f8033550b3eb6ff0f9cf02b556e48ee58208f2d0f70f32fd0330`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T010`, `P07-T005` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T006`
- Evidence commit message: `evidence(monacode): complete P07-T006`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T006.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Host/MonaWorkspaceEditTests.swift`

### Stage `red`

- verification-command: `P07-T006.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Prepare open-model edits inside component truth and external resource operations through the explicit host.`
- implementation-operation: `Expose applied, rejected, failed, and canceled outcomes with exact failure details.`
- implementation-operation: `Require a prepared nonthrowing atomic external commit before publishing open-model changes.`
- implementation-operation: `Roll back every prepared open-model mutation when external preparation or commit fails.`

### Stage `green`

- verification-command: `P07-T006.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Host/MonaWorkspaceEdit.swift
  - Sources/MonaCode/Host/MonaPreparedWorkspaceTransaction.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Host/MonaWorkspaceEditTests.swift

<!-- G6-R-TASK:P07-T007:a320c9e1e708f5d4c05b9c2adab47b00c1427f00ef029b764daa3d07dfd6eb50 -->

### P07-T007 — Close the bounded cache registry and provisional cache manifest

- Record SHA-256: `a320c9e1e708f5d4c05b9c2adab47b00c1427f00ef029b764daa3d07dfd6eb50`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T007`, `P06-T010`, `P07-T002`, `P07-T003` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T007`
- Evidence commit message: `evidence(monacode): complete P07-T007`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T007.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Runtime/MonaCacheRegistryTests.swift`

### Stage `red`

- verification-command: `P07-T007.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Register every cache with exact owner, key shape, entry bound, byte bound, counter width, invalidation, eviction, and quiescent plateau.`
- implementation-operation: `Include suggestion caches 300/200/50/20, two normalization caches of 10000, and maximum-11 diff cache.`
- implementation-operation: `Reject unregistered cache allocations and signed-counter overflow.`
- implementation-operation: `Emit a provisional cache manifest for Phase 08 regeneration.`

### Stage `green`

- verification-command: `P07-T007.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Runtime/MonaCacheRegistry.swift
  - Tools/Candidates/build-cache-manifest.mjs
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Runtime/MonaCacheRegistryTests.swift

<!-- G6-R-TASK:P07-T008:2380077556c78dbdca05892c949b32c0e5ec68b08e01371a7e9486543b43bc73 -->

### P07-T008 — Close runtime-style substitutions and full source inventory

- Record SHA-256: `2380077556c78dbdca05892c949b32c0e5ec68b08e01371a7e9486543b43bc73`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T200`, `P06-T010`, `P07-T006`, `P07-T007` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T008`
- Evidence commit message: `evidence(monacode): complete P07-T008`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T008.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/SourceRuntimeStyleTests.mjs`

### Stage `red`

- verification-command: `P07-T008.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Enumerate every product source file, generated source, resource, license, finite runtime substitution, native style projection, and explicit cut.`
- implementation-operation: `Verify X1-R set-equality counts 956, 98, 1281, 3120, 84, and 8221 plus all 2120 localization messages.`
- implementation-operation: `Reject source or resource paths that are absent from the manifest and reject forbidden runtime classes.`
- implementation-operation: `Emit a provisional source-closure manifest pending Phase 08 release regeneration.`

### Stage `green`

- verification-command: `P07-T008.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Tools/Candidates/build-source-closure-manifest.mjs
  - Tests/PlanStructureTests/SourceClosureTests.mjs
- modify:
  - _(none)_
- test:
  - Tests/PlanStructureTests/SourceRuntimeStyleTests.mjs

<!-- G6-R-TASK:P07-T009:b4ee5190c106407aba47d62fd16315e456fae56dd473cdfdf7a4ef7e6298ebfc -->

### P07-T009 — Deliver diff and multi-diff views, SwiftUI wrappers, and sample-host activation

- Record SHA-256: `b4ee5190c106407aba47d62fd16315e456fae56dd473cdfdf7a4ef7e6298ebfc`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T015`, `P07-T002`, `P07-T005` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T009`
- Evidence commit message: `evidence(monacode): complete P07-T009`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T009.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Views/MonaDiffViewLifecycleTests.swift`

### Stage `red`

- verification-command: `P07-T009.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Compose original and modified editors over shared models and one diff coordinator.`
- implementation-operation: `Consume ordered multi-diff snapshots with stable item identity and synchronous change events.`
- implementation-operation: `Wrap both native views with lifecycle-only SwiftUI types.`
- implementation-operation: `Activate all three products in the sample host without adding production dependencies.`

### Stage `green`

- verification-command: `P07-T009.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - Sources/MonaCodeAppKit/Views/MonaDiffEditorView.swift
  - Sources/MonaCodeAppKit/Views/MonaMultiDiffEditorView.swift
  - Sources/MonaCodeSwiftUI/MonaDiffEditor.swift
  - Sources/MonaCodeSwiftUI/MonaMultiDiffEditor.swift
- modify:
  - Sources/MonaCodeSample/main.swift
- test:
  - Tests/MonaCodeAppKitTests/Views/MonaDiffViewLifecycleTests.swift

<!-- G6-R-TASK:P07-T010:71e03e2b884442b83ee9c4f41ba128d067d01f108e343530768be5ab6563d9f6 -->

### P07-T010 — Close diff, service, host, cache, source, and view conformance

- Record SHA-256: `71e03e2b884442b83ee9c4f41ba128d067d01f108e343530768be5ab6563d9f6`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P07-T004`, `P07-T006`, `P07-T007`, `P07-T008`, `P07-T009` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T010`
- Evidence commit message: `evidence(monacode): complete P07-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Phase07HostAndDiffConformanceTests.swift`

### Stage `red`

- verification-command: `P07-T010.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run diff, service, dialog, opener, workspace edit, command host, log sink, transport factory, multi-diff data, cache, source, and lifecycle matrices.`
- implementation-operation: `Inject timeout, stale diff, cache allocation, host rejection, opener fallthrough, external commit, reentry, and disposal failures.`
- implementation-operation: `Verify three views, four wrappers, seven host groups, ten concrete types, and all source occurrence counts.`

### Stage `green`

- verification-command: `P07-T010.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Phase07HostAndDiffConformanceTests.swift

<!-- G6-R-TASK:P07-T011:dc09ff242f5618c0f8e917ea6ca570a1e65508e5511cb08393dc51727451d2b9 -->

### P07-T011 — Freeze the final public API closure before candidate generation

- Record SHA-256: `dc09ff242f5618c0f8e917ea6ca570a1e65508e5511cb08393dc51727451d2b9`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T014`, `P04-T015`, `P05-T001`, `P05-T012`, `P06-T004`, `P07-T009`, `P07-T010` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P07-T011`
- Evidence commit message: `evidence(monacode): complete P07-T011`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-07/P07-T011.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/PlanStructureTests/PublicAPIClosureTests.mjs`

### Stage `red`

- verification-command: `P07-T011.RED.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Generate symbol graphs and API digester baselines for all three products after every public producer.`
- implementation-operation: `Join every public declaration path to one native symbol or explicit cut disposition.`
- implementation-operation: `Freeze the public source set and reject every later public declaration or signature change.`

### Stage `green`

- verification-command: `P07-T011.GREEN.001` (kind=process, network=forbidden, timeout=120000ms, leaves=1)

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
  - Tests/PlanStructureTests/PublicAPIClosureTests.mjs
