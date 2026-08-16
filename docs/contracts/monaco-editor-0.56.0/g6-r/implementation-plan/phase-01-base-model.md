<!-- G6-R-PHASE:01 -->

# Phase 01 — Base model and transaction truth

- Phase: `01`
- Title: Base model and transaction truth
- Document: `implementation-plan/phase-01-base-model.md`
- Dependencies: `00` 
- Tasks: 13

## Tasks

<!-- G6-R-TASK:P01-T001:770e51b01ae03cb742bdacf13bb187f5f074fded408a80b138cf295d20bca26d -->

### P01-T001 — Implement raw UTF-16 positions and validation modes

- Record SHA-256: `770e51b01ae03cb742bdacf13bb187f5f074fded408a80b138cf295d20bca26d`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T012` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T001`
- Evidence commit message: `evidence(monacode): complete P01-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Base/MonaPositionTests.swift`

### Stage `red`

- verification-command: `P01-T001.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Store one-based line and column values without grapheme conversion.`
- implementation-operation: `Implement strict, relaxed, and raw-offset validation as separate code paths.`
- implementation-operation: `Preserve comparator identity behavior for equal-value transformations.`

### Stage `green`

- verification-command: `P01-T001.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Base/MonaPosition.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Base/MonaPositionTests.swift

<!-- G6-R-TASK:P01-T002:2f2f850e771ca4a88ccf210eabad88fe2c525e3ccb7596a66e0bd4d4441f5808 -->

### P01-T002 — Implement ranges and oriented selections

- Record SHA-256: `2f2f850e771ca4a88ccf210eabad88fe2c525e3ccb7596a66e0bd4d4441f5808`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T001` 
- Test contract cases: 2
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T002`
- Evidence commit message: `evidence(monacode): complete P01-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Base/MonaRangeTests.swift`

### Stage `red`

- verification-command: `P01-T002.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Normalize reversed endpoints while preserving selection anchor and active orientation.`
- implementation-operation: `Port all three intersection predicates branch-for-branch from Monaco.`
- implementation-operation: `Expand non-folded ranges outward when validation lands inside a surrogate pair.`

### Stage `green`

- verification-command: `P01-T002.GREEN.001` (kind=all-success, network=forbidden, timeout=600000ms, leaves=2)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Base/MonaRange.swift
  - Sources/MonaCode/Base/MonaSelection.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Base/MonaRangeTests.swift
  - Tests/MonaCodeTests/Base/MonaSelectionTests.swift

<!-- G6-R-TASK:P01-T003:11528d3dcec1372c0d901446834c3bc84df38bea934534d2708ec3d67d42b2a5 -->

### P01-T003 — Implement cache-observable Monaco URI semantics

- Record SHA-256: `11528d3dcec1372c0d901446834c3bc84df38bea934534d2708ec3d67d42b2a5`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T012` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T003`
- Evidence commit message: `evidence(monacode): complete P01-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Base/MonaURITests.swift`

### Stage `red`

- verification-command: `P01-T003.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Parse and format scheme, authority, path, query, and fragment with the frozen comparator rules.`
- implementation-operation: `Preserve graceful percent-decoder failure by complete percent run.`
- implementation-operation: `Preserve cache-observable toString, fsPath, and toJSON behavior in a reference type.`
- implementation-operation: `Reject lone-surrogate formatting with the exact typed error.`

### Stage `green`

- verification-command: `P01-T003.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Base/MonaURI.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Base/MonaURITests.swift

<!-- G6-R-TASK:P01-T004:eda035b91eb5a8f79d54b884b8fb4959ce61a04e5480cc27854aabf1f5cc1614 -->

### P01-T004 — Implement key, modifier, token, and marker value types

- Record SHA-256: `eda035b91eb5a8f79d54b884b8fb4959ce61a04e5480cc27854aabf1f5cc1614`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T012` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T004`
- Evidence commit message: `evidence(monacode): complete P01-T004`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T004.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Base/MonaValueEnumTests.swift`

### Stage `red`

- verification-command: `P01-T004.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Use extensible raw-value wrappers where Monaco accepts unknown numeric values.`
- implementation-operation: `Preserve modifier bit composition and keybinding serialization.`
- implementation-operation: `Preserve token offsets and marker severity ordering.`

### Stage `green`

- verification-command: `P01-T004.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Base/MonaKeyCode.swift
  - Sources/MonaCode/Base/MonaKeyMod.swift
  - Sources/MonaCode/Base/MonaToken.swift
  - Sources/MonaCode/Base/MonaMarker.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Base/MonaValueEnumTests.swift

<!-- G6-R-TASK:P01-T005:06d709e621bc6c2bdca76ae1d00cadaa800b60043c239b897de4bf6c34f0c18a -->

### P01-T005 — Implement deterministic events and idempotent disposal

- Record SHA-256: `06d709e621bc6c2bdca76ae1d00cadaa800b60043c239b897de4bf6c34f0c18a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P00-T012` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T005`
- Evidence commit message: `evidence(monacode): complete P01-T005`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T005.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Base/MonaEmitterTests.swift`

### Stage `red`

- verification-command: `P01-T005.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Serialize listener insertion, removal, nested fire, and disposal in comparator order.`
- implementation-operation: `Make disposal idempotent and ensure additions during dispatch observe the next dispatch only.`
- implementation-operation: `Report listener failures through the declared error boundary without skipping later listeners.`

### Stage `green`

- verification-command: `P01-T005.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Base/MonaDisposable.swift
  - Sources/MonaCode/Base/MonaEvent.swift
  - Sources/MonaCode/Base/MonaEmitter.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Base/MonaEmitterTests.swift

<!-- G6-R-TASK:P01-T006:19fc18470a5f94a708d3d3db937b804ae1a86c306d3d44468886fdd161615744 -->

### P01-T006 — Implement cancellation tokens and sources

- Record SHA-256: `19fc18470a5f94a708d3d3db937b804ae1a86c306d3d44468886fdd161615744`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T005` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T006`
- Evidence commit message: `evidence(monacode): complete P01-T006`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T006.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Base/MonaCancellationTests.swift`

### Stage `red`

- verification-command: `P01-T006.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Provide immutable None and Cancelled token singletons.`
- implementation-operation: `Fire cancellation once and preserve comparator behavior for listeners registered after cancellation.`
- implementation-operation: `Dispose child sources without canceling unrelated parents.`

### Stage `green`

- verification-command: `P01-T006.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Base/MonaCancellation.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Base/MonaCancellationTests.swift

<!-- G6-R-TASK:P01-T007:d34e153df04994fa2760a62a9f715069f5e2d60da22a5935e28f399f2d438a0a -->

### P01-T007 — Port the Piece Tree over raw UInt16 storage

- Record SHA-256: `d34e153df04994fa2760a62a9f715069f5e2d60da22a5935e28f399f2d438a0a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T002`, `P01-T006` 
- Test contract cases: 2
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T007`
- Evidence commit message: `evidence(monacode): complete P01-T007`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T007.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Model/MonaPieceTreeDifferentialTests.swift`

### Stage `red`

- verification-command: `P01-T007.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Port node balancing, buffer append, line-start metadata, insert, delete, offset, position, and snapshot algorithms.`
- implementation-operation: `Store raw UInt16 units and never repair isolated surrogates.`
- implementation-operation: `Instrument edit, search, offset, and position operation counts for later complexity gates.`
- implementation-operation: `Retain Monaco asymptotic upper bounds under adversarial edit sequences.`

### Stage `green`

- verification-command: `P01-T007.GREEN.001` (kind=all-success, network=forbidden, timeout=600000ms, leaves=2)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Model/PieceTree/MonaPieceTree.swift
  - Sources/MonaCode/Model/PieceTree/MonaPieceTreeNode.swift
  - Sources/MonaCode/Model/PieceTree/MonaLineStarts.swift
  - Sources/MonaCode/Model/PieceTree/MonaTextSnapshot.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Model/MonaPieceTreeDifferentialTests.swift
  - Tests/MonaCodeTests/Model/MonaPieceTreeComplexityTests.swift

<!-- G6-R-TASK:P01-T008:d6bd316ba8aa7ec710ca4fad53c4d79af41e37fe01f6e725d53d566bebbb31c2 -->

### P01-T008 — Implement all 70 retained text-model members on Piece Tree truth

- Record SHA-256: `d6bd316ba8aa7ec710ca4fad53c4d79af41e37fe01f6e725d53d566bebbb31c2`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T003`, `P01-T007` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T008`
- Evidence commit message: `evidence(monacode): complete P01-T008`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T008.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Model/MonaCodeModelSurfaceTests.swift`

### Stage `red`

- verification-command: `P01-T008.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Expose all 70 retained M1-R2 members with the frozen value, error, and event semantics.`
- implementation-operation: `Delegate text truth exclusively to Piece Tree snapshots and raw-unit coordinates.`
- implementation-operation: `Leave undo, decorations, word, RegExp, and search behavior behind explicit Phase 02 interfaces.`

### Stage `green`

- verification-command: `P01-T008.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Model/MonaCodeModel.swift
  - Sources/MonaCode/Model/MonaModelOptions.swift
  - Sources/MonaCode/Model/MonaModelEvents.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Model/MonaCodeModelSurfaceTests.swift

<!-- G6-R-TASK:P01-T009:e75aa096bcf8dc9675e0070c676dcb612a4090b7333d6c14073e75e6240b2874 -->

### P01-T009 — Make one edit transaction gateway own mutation and version truth

- Record SHA-256: `e75aa096bcf8dc9675e0070c676dcb612a4090b7333d6c14073e75e6240b2874`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T008` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T009`
- Evidence commit message: `evidence(monacode): complete P01-T009`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T009.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Transactions/MonaTransactionGatewayTests.swift`

### Stage `red`

- verification-command: `P01-T009.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Prepare edits without mutating published model state.`
- implementation-operation: `Commit text, version, alternative version, events, selections, and undo metadata as one ordered unit.`
- implementation-operation: `Roll back every prepared component on cancellation, validation failure, allocation failure, or reentrant invalidation.`
- implementation-operation: `Emit typed applied, dropped, reconciled, and rolled-back outcomes.`

### Stage `green`

- verification-command: `P01-T009.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Transactions/MonaEditTransaction.swift
  - Sources/MonaCode/Transactions/MonaTransactionGateway.swift
  - Sources/MonaCode/Transactions/MonaReconciliationOutcome.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Transactions/MonaTransactionGatewayTests.swift

<!-- G6-R-TASK:P01-T010:f3955473ec6a4d3a5b9ee712fd9e3708ac8cd42f435d62806f33bf9cdb3051c0 -->

### P01-T010 — Gate asynchronous publication with validity tickets

- Record SHA-256: `f3955473ec6a4d3a5b9ee712fd9e3708ac8cd42f435d62806f33bf9cdb3051c0`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T009` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T010`
- Evidence commit message: `evidence(monacode): complete P01-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Transactions/MonaAsyncValidityTicketTests.swift`

### Stage `red`

- verification-command: `P01-T010.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Capture model identity, version, alternative version, owner generation, and cancellation generation in an immutable ticket.`
- implementation-operation: `Validate the complete ticket immediately before publication.`
- implementation-operation: `Drop stale results without events, cache writes, decorations, or selection mutations.`

### Stage `green`

- verification-command: `P01-T010.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Transactions/MonaAsyncValidityTicket.swift
  - Sources/MonaCode/Transactions/MonaPublicationGate.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Transactions/MonaAsyncValidityTicketTests.swift

<!-- G6-R-TASK:P01-T011:e398cfe1d288dacfad480e41ca8d9d6cba8d3b3f4b452b1144297845fd36d0bb -->

### P01-T011 — Implement model construction and large-model state

- Record SHA-256: `e398cfe1d288dacfad480e41ca8d9d6cba8d3b3f4b452b1144297845fd36d0bb`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T008` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T011`
- Evidence commit message: `evidence(monacode): complete P01-T011`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T011.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Model/MonaModelFactoryTests.swift`

### Stage `red`

- verification-command: `P01-T011.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Apply the exact large-file thresholds and one-way state transitions fixed by H2-R.`
- implementation-operation: `Construct model identity, URI, options, Piece Tree, and lifetime registration atomically.`
- implementation-operation: `Reject malformed creation inputs without publishing a partial model.`

### Stage `green`

- verification-command: `P01-T011.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Model/MonaModelFactory.swift
  - Sources/MonaCode/Model/MonaLargeModelState.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Model/MonaModelFactoryTests.swift

<!-- G6-R-TASK:P01-T012:3c0437a31f13ae9ea4e728bb15ed6ad91933a58845e36973346dcd2db67a4766 -->

### P01-T012 — Implement application-global and per-editor lifetime registries

- Record SHA-256: `3c0437a31f13ae9ea4e728bb15ed6ad91933a58845e36973346dcd2db67a4766`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T005`, `P01-T011` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T012`
- Evidence commit message: `evidence(monacode): complete P01-T012`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T012.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Runtime/MonaLifetimeRegistryTests.swift`

### Stage `red`

- verification-command: `P01-T012.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Separate application-global, per-editor, and initial-model state with explicit owners.`
- implementation-operation: `Dispose children in reverse acquisition order and make repeated teardown inert.`
- implementation-operation: `Expose weak accounting hooks for C09 and the 1000-cycle lifecycle gate.`

### Stage `green`

- verification-command: `P01-T012.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Runtime/MonaGlobalLifetime.swift
  - Sources/MonaCode/Runtime/MonaEditorLifetime.swift
  - Sources/MonaCode/Runtime/MonaInitialModelRegistry.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Runtime/MonaLifetimeRegistryTests.swift

<!-- G6-R-TASK:P01-T013:181a2e807f1ac6092e6e80546865b7a44405307150338e5b74c666cb29b9d44f -->

### P01-T013 — Close Phase 01 with full model differential and failure matrices

- Record SHA-256: `181a2e807f1ac6092e6e80546865b7a44405307150338e5b74c666cb29b9d44f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T003`, `P01-T004`, `P01-T006`, `P01-T009`, `P01-T010`, `P01-T012` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P01-T013`
- Evidence commit message: `evidence(monacode): complete P01-T013`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-01/P01-T013.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Phase01ModelConformanceTests.swift`

### Stage `red`

- verification-command: `P01-T013.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run raw UInt16 differential fixtures across base values, URI, Piece Tree, all retained model members, and edit transactions.`
- implementation-operation: `Inject cancellation, allocation, reentrancy, and stale-publication failures at every declared checkpoint.`
- implementation-operation: `Record zero-diff, invariant, operation-count, and lifetime results in the task evidence artifact.`

### Stage `green`

- verification-command: `P01-T013.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Phase01ModelConformanceTests.swift
