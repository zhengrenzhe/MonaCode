# Phase 01: Base model and transaction truth

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 00.

Task count: 13.

<!-- monacode-plan-task:{"id":"P01-T001","recordSha256":"7a674d495f7d0843297127195fb639df0589b8102d4ae764be15d8e04019263a"} -->
## P01-T001 — Implement raw UTF-16 positions and validation modes

Contract: `B1-R.Position`, `M1-R2.modelCoordinates`, `C01`

Dependencies:
- `P00-T012`

Ownership selectors:
- `base:MonaPosition`
- `model:position-validation`

Files to create:
- `Sources/MonaCode/Base/MonaPosition.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Base/MonaPositionTests.swift`

Interfaces consumed:
- `MonaDifferentialModelProvider`

Interfaces produced:
- `MonaPosition`
- `MonaPositionValidationMode`

Red verification:
- Run: `swift test --filter MonaPositionTests/testIsolatedSurrogateOffsets`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=position-isolated-surrogate`

Minimal implementation operations:
- `Store one-based line and column values without grapheme conversion.`
- `Implement strict, relaxed, and raw-offset validation as separate code paths.`
- `Preserve comparator identity behavior for equal-value transformations.`

Green verification:
- Run: `swift test --filter MonaPositionTests`
  - Expected exit: `0`
  - Expected output includes: `POSITION_PARITY fixtures=16 rawUTF16=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T001.json`

Completion assertions:
- `All 16 frozen declaration fixtures match M0 and M1.`
- `Offsets may represent isolated surrogate boundaries exactly.`

Commit boundary:
- `Sources/MonaCode/Base/MonaPosition.swift`
- `Tests/MonaCodeTests/Base/MonaPositionTests.swift`

<!-- monacode-plan-task:{"id":"P01-T002","recordSha256":"bd4c170c2d76e73f536a1ec223db0ae55ac190b40bdc236b9021f0db290c1bf1"} -->
## P01-T002 — Implement ranges and oriented selections

Contract: `B1-R.Range`, `B1-R.Selection`, `C01`

Dependencies:
- `P01-T001`

Ownership selectors:
- `base:MonaRange`
- `base:MonaSelection`

Files to create:
- `Sources/MonaCode/Base/MonaRange.swift`
- `Sources/MonaCode/Base/MonaSelection.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Base/MonaRangeTests.swift`
- `Tests/MonaCodeTests/Base/MonaSelectionTests.swift`

Interfaces consumed:
- `MonaPosition`
- `MonaPositionValidationMode`

Interfaces produced:
- `MonaRange`
- `MonaSelection`
- `MonaSelectionDirection`

Red verification:
- Run: `swift test --filter MonaRangeTests/testIntersectPredicateTruthTable`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=range-intersection-truth-table`

Minimal implementation operations:
- `Normalize reversed endpoints while preserving selection anchor and active orientation.`
- `Port all three intersection predicates branch-for-branch from Monaco.`
- `Expand non-folded ranges outward when validation lands inside a surrogate pair.`

Green verification:
- Run: `swift test --filter MonaRangeTests && swift test --filter MonaSelectionTests`
  - Expected exit: `0`
  - Expected output includes: `RANGE_SELECTION_PARITY rangeDeclarations=43 selectionDeclarations=44`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T002.json`

Completion assertions:
- `Range and selection declaration fixtures are zero-diff.`
- `Orientation survives normalization.`
- `Touching and strict-intersection predicates remain distinct.`

Commit boundary:
- `Sources/MonaCode/Base/MonaRange.swift`
- `Sources/MonaCode/Base/MonaSelection.swift`
- `Tests/MonaCodeTests/Base/MonaRangeTests.swift`
- `Tests/MonaCodeTests/Base/MonaSelectionTests.swift`

<!-- monacode-plan-task:{"id":"P01-T003","recordSha256":"2c1bb4460cc2e56701bfb2360d5b68d52f55a434b7d344edb2604a1a44368698"} -->
## P01-T003 — Implement cache-observable Monaco URI semantics

Contract: `B1-R.Uri`, `G5-R.explicitCuts.foundationURLSubstitution`, `C01`

Dependencies:
- `P00-T012`

Ownership selectors:
- `base:MonaURI`

Files to create:
- `Sources/MonaCode/Base/MonaURI.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Base/MonaURITests.swift`

Interfaces consumed:
- None.

Interfaces produced:
- `MonaURI`
- `MonaURIComponents`
- `MonaURIError`

Red verification:
- Run: `swift test --filter MonaURITests/testGracefulPercentDecodeRun`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=uri-percent-run`

Minimal implementation operations:
- `Parse and format scheme, authority, path, query, and fragment with the frozen comparator rules.`
- `Preserve graceful percent-decoder failure by complete percent run.`
- `Preserve cache-observable toString, fsPath, and toJSON behavior in a reference type.`
- `Reject lone-surrogate formatting with the exact typed error.`

Green verification:
- Run: `swift test --filter MonaURITests`
  - Expected exit: `0`
  - Expected output includes: `URI_PARITY fixtures=27 cacheObservable=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T003.json`

Completion assertions:
- `URI fixtures match raw comparator output.`
- `No generic URL semantic substitution occurs.`
- `Cache state remains observable.`

Commit boundary:
- `Sources/MonaCode/Base/MonaURI.swift`
- `Tests/MonaCodeTests/Base/MonaURITests.swift`

<!-- monacode-plan-task:{"id":"P01-T004","recordSha256":"d6a657958f1458d09e7059a508f35ffed5430cef38e638dac285a34e8180ec8d"} -->
## P01-T004 — Implement key, modifier, token, and marker value types

Contract: `B1-R.keyAndMarkerValues`, `F1-R5.nativeTypeSemantics`, `C01`

Dependencies:
- `P00-T012`

Ownership selectors:
- `base:key-codes`
- `base:marker-enums`

Files to create:
- `Sources/MonaCode/Base/MonaKeyCode.swift`
- `Sources/MonaCode/Base/MonaKeyMod.swift`
- `Sources/MonaCode/Base/MonaToken.swift`
- `Sources/MonaCode/Base/MonaMarker.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Base/MonaValueEnumTests.swift`

Interfaces consumed:
- None.

Interfaces produced:
- `MonaKeyCode`
- `MonaKeyMod`
- `MonaToken`
- `MonaMarkerSeverity`
- `MonaMarkerTag`

Red verification:
- Run: `swift test --filter MonaValueEnumTests/testUnknownRawValuesRoundTrip`
  - Expected exit: `1`
  - Expected output includes: `XCTAssertEqual failed: unknown-raw-value`

Minimal implementation operations:
- `Use extensible raw-value wrappers where Monaco accepts unknown numeric values.`
- `Preserve modifier bit composition and keybinding serialization.`
- `Preserve token offsets and marker severity ordering.`

Green verification:
- Run: `swift test --filter MonaValueEnumTests`
  - Expected exit: `0`
  - Expected output includes: `BASE_ENUM_PARITY unknownRawValues=preserved`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T004.json`

Completion assertions:
- `Known and unknown raw values round-trip.`
- `Modifier composition matches comparator bit patterns.`

Commit boundary:
- `Sources/MonaCode/Base/MonaKeyCode.swift`
- `Sources/MonaCode/Base/MonaKeyMod.swift`
- `Sources/MonaCode/Base/MonaToken.swift`
- `Sources/MonaCode/Base/MonaMarker.swift`
- `Tests/MonaCodeTests/Base/MonaValueEnumTests.swift`

<!-- monacode-plan-task:{"id":"P01-T005","recordSha256":"1f8e0376e40dbccf0cb340712ef0aae40ac2f0340f6bf611df408dd88e49c4a4"} -->
## P01-T005 — Implement deterministic events and idempotent disposal

Contract: `B1-R.Event`, `A+.reentrancy`, `H2-R.lifetime`

Dependencies:
- `P00-T012`

Ownership selectors:
- `base:MonaEmitter`
- `base:MonaDisposable`
- `base:MonaEvent`

Files to create:
- `Sources/MonaCode/Base/MonaDisposable.swift`
- `Sources/MonaCode/Base/MonaEvent.swift`
- `Sources/MonaCode/Base/MonaEmitter.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Base/MonaEmitterTests.swift`

Interfaces consumed:
- None.

Interfaces produced:
- `MonaDisposable`
- `MonaEvent`
- `MonaEmitter`

Red verification:
- Run: `swift test --filter MonaEmitterTests/testReentrantDisposeOrder`
  - Expected exit: `1`
  - Expected output includes: `XCTAssertEqual failed: emitter-reentrant-order`

Minimal implementation operations:
- `Serialize listener insertion, removal, nested fire, and disposal in comparator order.`
- `Make disposal idempotent and ensure additions during dispatch observe the next dispatch only.`
- `Report listener failures through the declared error boundary without skipping later listeners.`

Green verification:
- Run: `swift test --filter MonaEmitterTests`
  - Expected exit: `0`
  - Expected output includes: `EMITTER_PARITY reentrancyVectors=18 failures=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T005.json`

Completion assertions:
- `Dispatch order matches Monaco.`
- `Nested fire and disposal preserve listener truth.`
- `Repeated disposal has no effect.`

Commit boundary:
- `Sources/MonaCode/Base/MonaDisposable.swift`
- `Sources/MonaCode/Base/MonaEvent.swift`
- `Sources/MonaCode/Base/MonaEmitter.swift`
- `Tests/MonaCodeTests/Base/MonaEmitterTests.swift`

<!-- monacode-plan-task:{"id":"P01-T006","recordSha256":"ab46bb2aec48421e981f8f787158c611a63d49018032dc56a6cd5185083ef3a1"} -->
## P01-T006 — Implement cancellation tokens and sources

Contract: `B1-R.Cancellation`, `R1.cancellationValidity`

Dependencies:
- `P01-T005`

Ownership selectors:
- `base:MonaCancellationToken`
- `base:MonaCancellationTokenSource`

Files to create:
- `Sources/MonaCode/Base/MonaCancellation.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Base/MonaCancellationTests.swift`

Interfaces consumed:
- `MonaEmitter`
- `MonaDisposable`

Interfaces produced:
- `MonaCancellationToken`
- `MonaCancellationTokenSource`

Red verification:
- Run: `swift test --filter MonaCancellationTests/testCancelThenSubscribe`
  - Expected exit: `1`
  - Expected output includes: `XCTAssertEqual failed: late-cancellation-listener`

Minimal implementation operations:
- `Provide immutable None and Cancelled token singletons.`
- `Fire cancellation once and preserve comparator behavior for listeners registered after cancellation.`
- `Dispose child sources without canceling unrelated parents.`

Green verification:
- Run: `swift test --filter MonaCancellationTests`
  - Expected exit: `0`
  - Expected output includes: `CANCELLATION_PARITY vectors=12 failures=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T006.json`

Completion assertions:
- `Cancellation fires exactly once.`
- `Late listeners observe the frozen behavior.`
- `Source disposal is idempotent.`

Commit boundary:
- `Sources/MonaCode/Base/MonaCancellation.swift`
- `Tests/MonaCodeTests/Base/MonaCancellationTests.swift`

<!-- monacode-plan-task:{"id":"P01-T007","recordSha256":"b064f2c2dee7c3b7deab33c80ae562250f598709fc264cda5ce2750d8d27681b"} -->
## P01-T007 — Port the Piece Tree over raw UInt16 storage

Contract: `M1-R2.pieceTree`, `G5-R.equivalenceDomains.exact`, `C01`, `P01`

Dependencies:
- `P01-T002`
- `P01-T006`

Ownership selectors:
- `model:piece-tree`
- `model:raw-utf16-storage`

Files to create:
- `Sources/MonaCode/Model/PieceTree/MonaPieceTree.swift`
- `Sources/MonaCode/Model/PieceTree/MonaPieceTreeNode.swift`
- `Sources/MonaCode/Model/PieceTree/MonaLineStarts.swift`
- `Sources/MonaCode/Model/PieceTree/MonaTextSnapshot.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Model/MonaPieceTreeDifferentialTests.swift`
- `Tests/MonaCodeTests/Model/MonaPieceTreeComplexityTests.swift`

Interfaces consumed:
- `MonaPosition`
- `MonaRange`
- `MonaCancellationToken`

Interfaces produced:
- `MonaPieceTree`
- `MonaTextSnapshot`
- `MonaLineStarts`

Red verification:
- Run: `swift test --filter MonaPieceTreeDifferentialTests/testIsolatedSurrogateEditTrace`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=piece-tree-isolated-surrogate`

Minimal implementation operations:
- `Port node balancing, buffer append, line-start metadata, insert, delete, offset, position, and snapshot algorithms.`
- `Store raw UInt16 units and never repair isolated surrogates.`
- `Instrument edit, search, offset, and position operation counts for later complexity gates.`
- `Retain Monaco asymptotic upper bounds under adversarial edit sequences.`

Green verification:
- Run: `swift test --filter MonaPieceTreeDifferentialTests && swift test --filter MonaPieceTreeComplexityTests`
  - Expected exit: `0`
  - Expected output includes: `PIECE_TREE_PARITY traces=10000 complexity=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T007.json`

Completion assertions:
- `Differential traces are raw-unit zero-diff.`
- `Snapshots remain immutable.`
- `Operation counters retain the frozen growth class.`

Commit boundary:
- `Sources/MonaCode/Model/PieceTree/MonaPieceTree.swift`
- `Sources/MonaCode/Model/PieceTree/MonaPieceTreeNode.swift`
- `Sources/MonaCode/Model/PieceTree/MonaLineStarts.swift`
- `Sources/MonaCode/Model/PieceTree/MonaTextSnapshot.swift`
- `Tests/MonaCodeTests/Model/MonaPieceTreeDifferentialTests.swift`
- `Tests/MonaCodeTests/Model/MonaPieceTreeComplexityTests.swift`

<!-- monacode-plan-task:{"id":"P01-T008","recordSha256":"447542a2e7c6d1ce53ed39c95be14d97ccca0e8db0ff088157fce27a940360f3"} -->
## P01-T008 — Implement all 70 retained text-model members on Piece Tree truth

Contract: `M1-R2.publicSurface`, `F1-R2.instanceSurface`, `C01`

Dependencies:
- `P01-T007`

Ownership selectors:
- `model:MonaCodeModel`
- `model:70-retained-members`

Files to create:
- `Sources/MonaCode/Model/MonaCodeModel.swift`
- `Sources/MonaCode/Model/MonaModelOptions.swift`
- `Sources/MonaCode/Model/MonaModelEvents.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Model/MonaCodeModelSurfaceTests.swift`

Interfaces consumed:
- `MonaPieceTree`
- `MonaTextSnapshot`
- `MonaURI`
- `MonaEmitter`

Interfaces produced:
- `MonaCodeModel`
- `MonaModelOptions`
- `MonaModelEventStream`

Red verification:
- Run: `swift test --filter MonaCodeModelSurfaceTests/testRetainedMemberManifest`
  - Expected exit: `1`
  - Expected output includes: `MODEL_MEMBER_MISSING member=getOffsetAt retained=70`

Minimal implementation operations:
- `Expose all 70 retained M1-R2 members with the frozen value, error, and event semantics.`
- `Delegate text truth exclusively to Piece Tree snapshots and raw-unit coordinates.`
- `Leave undo, decorations, word, RegExp, and search behavior behind explicit Phase 02 interfaces.`

Green verification:
- Run: `swift test --filter MonaCodeModelSurfaceTests`
  - Expected exit: `0`
  - Expected output includes: `MODEL_SURFACE retainedMembers=70 missing=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T008.json`

Completion assertions:
- `All retained model members are callable.`
- `No Phase 02 behavior is silently stubbed as success.`
- `Event payloads preserve raw-unit values.`

Commit boundary:
- `Sources/MonaCode/Model/MonaCodeModel.swift`
- `Sources/MonaCode/Model/MonaModelOptions.swift`
- `Sources/MonaCode/Model/MonaModelEvents.swift`
- `Tests/MonaCodeTests/Model/MonaCodeModelSurfaceTests.swift`

<!-- monacode-plan-task:{"id":"P01-T009","recordSha256":"3fb8d5468a3b76338681fdc0524d98b4384d51b756b52808cf6ef4cc97a09a93"} -->
## P01-T009 — Make one edit transaction gateway own mutation and version truth

Contract: `A+`, `A+-base`, `R1.transactionRecovery`

Dependencies:
- `P01-T008`

Ownership selectors:
- `transaction:MonaEditTransaction`
- `transaction:version-truth`

Files to create:
- `Sources/MonaCode/Transactions/MonaEditTransaction.swift`
- `Sources/MonaCode/Transactions/MonaTransactionGateway.swift`
- `Sources/MonaCode/Transactions/MonaReconciliationOutcome.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Transactions/MonaTransactionGatewayTests.swift`

Interfaces consumed:
- `MonaCodeModel`
- `MonaCancellationToken`

Interfaces produced:
- `MonaEditTransaction`
- `MonaTransactionGateway`
- `MonaReconciliationOutcome`

Red verification:
- Run: `swift test --filter MonaTransactionGatewayTests/testInjectedCommitFailureRollsBack`
  - Expected exit: `1`
  - Expected output includes: `TRANSACTION_INVARIANT_FAILED state=half-committed`

Minimal implementation operations:
- `Prepare edits without mutating published model state.`
- `Commit text, version, alternative version, events, selections, and undo metadata as one ordered unit.`
- `Roll back every prepared component on cancellation, validation failure, allocation failure, or reentrant invalidation.`
- `Emit typed applied, dropped, reconciled, and rolled-back outcomes.`

Green verification:
- Run: `swift test --filter MonaTransactionGatewayTests`
  - Expected exit: `0`
  - Expected output includes: `TRANSACTION_GATEWAY commits=24 rollbacks=18 halfCommitted=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T009.json`

Completion assertions:
- `All model writes traverse one gateway.`
- `Version and alternative version advance exactly once per committed transaction.`
- `Failure leaves no published partial state.`

Commit boundary:
- `Sources/MonaCode/Transactions/MonaEditTransaction.swift`
- `Sources/MonaCode/Transactions/MonaTransactionGateway.swift`
- `Sources/MonaCode/Transactions/MonaReconciliationOutcome.swift`
- `Tests/MonaCodeTests/Transactions/MonaTransactionGatewayTests.swift`

<!-- monacode-plan-task:{"id":"P01-T010","recordSha256":"53393d53c952831b987657e821f8c6c3f66856a4ab85d4baa46fd0b23f9fd29c"} -->
## P01-T010 — Gate asynchronous publication with validity tickets

Contract: `R1.asyncValidity`, `A+.ownership`, `C09`

Dependencies:
- `P01-T009`

Ownership selectors:
- `validity:MonaAsyncValidityTicket`
- `validity:publication-gate`

Files to create:
- `Sources/MonaCode/Transactions/MonaAsyncValidityTicket.swift`
- `Sources/MonaCode/Transactions/MonaPublicationGate.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Transactions/MonaAsyncValidityTicketTests.swift`

Interfaces consumed:
- `MonaTransactionGateway`
- `MonaCancellationToken`

Interfaces produced:
- `MonaAsyncValidityTicket`
- `MonaPublicationGate`

Red verification:
- Run: `swift test --filter MonaAsyncValidityTicketTests/testLateResultAfterVersionChange`
  - Expected exit: `1`
  - Expected output includes: `PUBLICATION_GATE_ACCEPTED_STALE_RESULT ticketVersion=1 currentVersion=2`

Minimal implementation operations:
- `Capture model identity, version, alternative version, owner generation, and cancellation generation in an immutable ticket.`
- `Validate the complete ticket immediately before publication.`
- `Drop stale results without events, cache writes, decorations, or selection mutations.`

Green verification:
- Run: `swift test --filter MonaAsyncValidityTicketTests`
  - Expected exit: `0`
  - Expected output includes: `ASYNC_VALIDITY stale=18 dropped=18 published=6`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T010.json`

Completion assertions:
- `Every asynchronous consumer uses the publication gate.`
- `Stale and canceled results have zero side effects.`
- `Valid results retain deterministic order.`

Commit boundary:
- `Sources/MonaCode/Transactions/MonaAsyncValidityTicket.swift`
- `Sources/MonaCode/Transactions/MonaPublicationGate.swift`
- `Tests/MonaCodeTests/Transactions/MonaAsyncValidityTicketTests.swift`

<!-- monacode-plan-task:{"id":"P01-T011","recordSha256":"c28f1f4810dddee3bfab829fda805412c0f05e1c7ac243225f35863c2cf5a71e"} -->
## P01-T011 — Implement model construction and large-model state

Contract: `H2-R.modelConstruction`, `M1-R2.largeModelPolicy`, `P01`

Dependencies:
- `P01-T008`

Ownership selectors:
- `runtime:model-construction`
- `runtime:large-model-state`

Files to create:
- `Sources/MonaCode/Model/MonaModelFactory.swift`
- `Sources/MonaCode/Model/MonaLargeModelState.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Model/MonaModelFactoryTests.swift`

Interfaces consumed:
- `MonaCodeModel`
- `MonaPieceTree`

Interfaces produced:
- `MonaModelFactory`
- `MonaLargeModelState`

Red verification:
- Run: `swift test --filter MonaModelFactoryTests/testLargeModelThresholdBoundaries`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=large-model-threshold-T`

Minimal implementation operations:
- `Apply the exact large-file thresholds and one-way state transitions fixed by H2-R.`
- `Construct model identity, URI, options, Piece Tree, and lifetime registration atomically.`
- `Reject malformed creation inputs without publishing a partial model.`

Green verification:
- Run: `swift test --filter MonaModelFactoryTests`
  - Expected exit: `0`
  - Expected output includes: `MODEL_FACTORY thresholds=6 rollback=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T011.json`

Completion assertions:
- `T-1, T, and T+1 threshold fixtures match comparators.`
- `Failed construction publishes no model.`
- `Large-model state is explicit.`

Commit boundary:
- `Sources/MonaCode/Model/MonaModelFactory.swift`
- `Sources/MonaCode/Model/MonaLargeModelState.swift`
- `Tests/MonaCodeTests/Model/MonaModelFactoryTests.swift`

<!-- monacode-plan-task:{"id":"P01-T012","recordSha256":"0e443dc25ddaff29e031022d9c25a41d2bb99982006ee89e06ea00860a270b93"} -->
## P01-T012 — Implement application-global and per-editor lifetime registries

Contract: `H2-R.globalLifetime`, `H2-R.perEditorLifetime`, `C09`

Dependencies:
- `P01-T005`
- `P01-T011`

Ownership selectors:
- `normativeLayer:runtime-lifetime-resource:H2-R`
- `runtime:lifetime-registries`

Files to create:
- `Sources/MonaCode/Runtime/MonaGlobalLifetime.swift`
- `Sources/MonaCode/Runtime/MonaEditorLifetime.swift`
- `Sources/MonaCode/Runtime/MonaInitialModelRegistry.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Runtime/MonaLifetimeRegistryTests.swift`

Interfaces consumed:
- `MonaDisposable`
- `MonaModelFactory`

Interfaces produced:
- `MonaGlobalLifetime`
- `MonaEditorLifetime`
- `MonaInitialModelRegistry`

Red verification:
- Run: `swift test --filter MonaLifetimeRegistryTests/testDisposeOrderAndBaselineReturn`
  - Expected exit: `1`
  - Expected output includes: `LIFETIME_BASELINE_LEAK registry=editor`

Minimal implementation operations:
- `Separate application-global, per-editor, and initial-model state with explicit owners.`
- `Dispose children in reverse acquisition order and make repeated teardown inert.`
- `Expose weak accounting hooks for C09 and the 1000-cycle lifecycle gate.`

Green verification:
- Run: `swift test --filter MonaLifetimeRegistryTests`
  - Expected exit: `0`
  - Expected output includes: `LIFETIME_REGISTRIES global=8 editor=7 initialModel=3 leak=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T012.json`

Completion assertions:
- `All 18 frozen state rows have an explicit lifetime owner.`
- `Editor teardown returns to the warm baseline.`
- `No global state is duplicated per editor.`

Commit boundary:
- `Sources/MonaCode/Runtime/MonaGlobalLifetime.swift`
- `Sources/MonaCode/Runtime/MonaEditorLifetime.swift`
- `Sources/MonaCode/Runtime/MonaInitialModelRegistry.swift`
- `Tests/MonaCodeTests/Runtime/MonaLifetimeRegistryTests.swift`

<!-- monacode-plan-task:{"id":"P01-T013","recordSha256":"2f200a2c3812141a66bc7c21f5dae04030c4683fa6933d5fbad62c60f01b6761"} -->
## P01-T013 — Close Phase 01 with full model differential and failure matrices

Contract: `B1-R`, `M1-R2`, `A+`, `A+-base`, `R1`, `H2-R`, `C01`

Dependencies:
- `P01-T003`
- `P01-T004`
- `P01-T006`
- `P01-T009`
- `P01-T010`
- `P01-T012`

Ownership selectors:
- `normativeLayer:base-values-events:B1-R`
- `phase-gate:01`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Phase01ModelConformanceTests.swift`

Interfaces consumed:
- `MonaPosition`
- `MonaRange`
- `MonaSelection`
- `MonaURI`
- `MonaCodeModel`
- `MonaTransactionGateway`
- `MonaPublicationGate`
- `MonaGlobalLifetime`

Interfaces produced:
- `Phase01ModelGate`

Red verification:
- Run: `swift test --filter Phase01ModelConformanceTests/testSeededRawUnitDrift`
  - Expected exit: `1`
  - Expected output includes: `C01_MODEL_DIFFERENTIAL_FAILED fixture=seeded-raw-unit-drift`

Minimal implementation operations:
- `Run raw UInt16 differential fixtures across base values, URI, Piece Tree, all retained model members, and edit transactions.`
- `Inject cancellation, allocation, reentrancy, and stale-publication failures at every declared checkpoint.`
- `Record zero-diff, invariant, operation-count, and lifetime results in the task evidence artifact.`

Green verification:
- Run: `swift test --filter Phase01ModelConformanceTests`
  - Expected exit: `0`
  - Expected output includes: `PHASE01_MODEL_GATE exactDiff=0 halfCommitted=0 staleSideEffects=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-01/P01-T013.json`

Completion assertions:
- `B1-R and Phase 01 M1-R2 fixtures are exact.`
- `All injected recoverable failures preserve model invariants.`
- `No later phase can bypass the transaction gateway.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Phase01ModelConformanceTests.swift`
