# Phase 07: Diff, services, host, and source closure

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 06.

Task count: 11.

<!-- monacode-plan-task:{"id":"P07-T001","recordSha256":"1ee10b7492388207d4ced9059aec05d41e86c8fb6b0ff91e8f63821b8bdc0900"} -->
## P07-T001 — Implement legacy and advanced diff engines over raw UTF-16

Contract: `D1-R.engines`, `C05`, `P10`

Dependencies:
- `P06-T010`
- `P02-T009`

Ownership selectors:
- `diff:legacy-engine`
- `diff:advanced-engine`

Files to create:
- `Sources/MonaCode/Diff/MonaDiffEngine.swift`
- `Sources/MonaCode/Diff/MonaLegacyDiffEngine.swift`
- `Sources/MonaCode/Diff/MonaAdvancedDiffEngine.swift`
- `Sources/MonaCode/Diff/MonaDiffResult.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Diff/MonaDiffEngineDifferentialTests.swift`

Interfaces consumed:
- `MonaCodeModel`
- `MonaHighResolutionClock`
- `MonaCancellationToken`

Interfaces produced:
- `MonaDiffEngine`
- `MonaLegacyDiffEngine`
- `MonaAdvancedDiffEngine`
- `MonaDiffResult`

Red verification:
- Run: `swift test --filter MonaDiffEngineDifferentialTests/testIsolatedSurrogateAndMovedBlockMatrix`
  - Expected exit: `1`
  - Expected output includes: `DIFF_DIFFERENTIAL_MISMATCH fixture=isolated-surrogate-moved-block`

Minimal implementation operations:
- `Port line hashing, sequence diff, character refinement, moved-block detection, inner changes, and result normalization for both engines.`
- `Operate on raw UTF-16 ranges and preserve comparator ordering and optional fields.`
- `Check cancellation and timeout at the frozen algorithm checkpoints.`

Green verification:
- Run: `swift test --filter MonaDiffEngineDifferentialTests`
  - Expected exit: `0`
  - Expected output includes: `DIFF_ENGINES legacy=exact advanced=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T001.json`

Completion assertions:
- `Legacy and advanced fixture outputs match M0/M1.`
- `Raw-unit inner changes remain exact.`
- `Cancellation leaves no cached partial result.`

Commit boundary:
- `Sources/MonaCode/Diff/MonaDiffEngine.swift`
- `Sources/MonaCode/Diff/MonaLegacyDiffEngine.swift`
- `Sources/MonaCode/Diff/MonaAdvancedDiffEngine.swift`
- `Sources/MonaCode/Diff/MonaDiffResult.swift`
- `Tests/MonaCodeTests/Diff/MonaDiffEngineDifferentialTests.swift`

<!-- monacode-plan-task:{"id":"P07-T002","recordSha256":"99b752bf1964b2e6d6b79488d1cd09e6e94d47f420666038d153908486451f8e"} -->
## P07-T002 — Close diff timeouts, caches, maximum size, and unavailable external paths

Contract: `D1-R.timeout`, `D1-R.cache`, `D1-R.externalUnavailable`, `C05`, `P10`

Dependencies:
- `P07-T001`

Ownership selectors:
- `normativeLayer:diff-engine:D1-R`
- `machineArtifact:D1-R-diff-engine`

Files to create:
- `Sources/MonaCode/Diff/MonaDiffCoordinator.swift`
- `Sources/MonaCode/Diff/MonaDiffCache.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Diff/MonaDiffCoordinatorTests.swift`

Interfaces consumed:
- `MonaDiffEngine`
- `MonaAsyncValidityTicket`

Interfaces produced:
- `MonaDiffCoordinator`
- `MonaDiffCache`

Red verification:
- Run: `swift test --filter MonaDiffCoordinatorTests/testTimeoutTMinusOneTPlusOne`
  - Expected exit: `1`
  - Expected output includes: `DIFF_TIMEOUT_BOUNDARY_MISMATCH boundary=T`

Minimal implementation operations:
- `Apply T-1, T, and T+1 timeout truth with injected monotonic time.`
- `Implement the bounded maximum-11 cache with exact key, hit, miss, invalidation, and eviction semantics.`
- `Return explicit no-op results for maximum-file-size and external/WASM-unavailable paths.`
- `Publish only complete results whose model versions still match.`

Green verification:
- Run: `swift test --filter MonaDiffCoordinatorTests`
  - Expected exit: `0`
  - Expected output includes: `DIFF_COORDINATOR timeout=exact cacheMax=11 external=unavailable`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T002.json`

Completion assertions:
- `Timeout boundaries match D1-R.`
- `Cache never exceeds 11 entries.`
- `Unavailable external paths never load external code.`

Commit boundary:
- `Sources/MonaCode/Diff/MonaDiffCoordinator.swift`
- `Sources/MonaCode/Diff/MonaDiffCache.swift`
- `Tests/MonaCodeTests/Diff/MonaDiffCoordinatorTests.swift`

<!-- monacode-plan-task:{"id":"P07-T003","recordSha256":"fcdb150534dfe9a009c1e87d3e567688167f1175fcb6961222ce862d26cc39d7"} -->
## P07-T003 — Implement 40 standalone services and bounded session state

Contract: `S1-R.services`, `S1-R.sessionStore`, `C09`, `P11`

Dependencies:
- `P05-T200`
- `P06-T010`

Ownership selectors:
- `normativeLayer:standalone-services-session-feedback:S1-R`
- `machineArtifact:S1-R-standalone-services`

Files to create:
- `Sources/MonaCode/Services/MonaServiceCollection.swift`
- `Sources/MonaCode/Services/MonaStandaloneServices.swift`
- `Sources/MonaCode/Services/MonaSessionStore.swift`
- `Sources/MonaCode/Services/MonaFeedbackService.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Services/MonaStandaloneServiceTests.swift`

Interfaces consumed:
- `MonaGlobalLifetime`
- `MonaEditorLifetime`
- `MonaCommandRegistry`
- `MonaLocalization`

Interfaces produced:
- `MonaServiceCollection`
- `MonaStandaloneServices`
- `MonaSessionStore`
- `MonaFeedbackService`

Red verification:
- Run: `swift test --filter MonaStandaloneServiceTests/testExactServiceAndCacheBounds`
  - Expected exit: `1`
  - Expected output includes: `STANDALONE_SERVICE_SET_MISMATCH expected=40`

Minimal implementation operations:
- `Instantiate exactly 40 retained services with explicit global or per-editor lifetime ownership.`
- `Implement bounded session rows for suggestion memory, scope switching, save delay, widget details, and shared state.`
- `Keep persistence, telemetry transport, notification-progress UI, and signal audio absent.`
- `Expose nonblocking localized feedback without document-text logging.`

Green verification:
- Run: `swift test --filter MonaStandaloneServiceTests`
  - Expected exit: `0`
  - Expected output includes: `STANDALONE_SERVICES count=40 caches=300,200,50,20 persistence=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T003.json`

Completion assertions:
- `Service identity set and lifetimes are exact.`
- `All session stores remain memory-only and bounded.`
- `Prohibited services are absent.`

Commit boundary:
- `Sources/MonaCode/Services/MonaServiceCollection.swift`
- `Sources/MonaCode/Services/MonaStandaloneServices.swift`
- `Sources/MonaCode/Services/MonaSessionStore.swift`
- `Sources/MonaCode/Services/MonaFeedbackService.swift`
- `Tests/MonaCodeTests/Services/MonaStandaloneServiceTests.swift`

<!-- monacode-plan-task:{"id":"P07-T004","recordSha256":"7e4114fd1ccf76e916735cd0c12011ea27e1d168a0036060cccf2b08c17474a4"} -->
## P07-T004 — Project four dialog sites into host-authorized native dialogs

Contract: `S1-R.dialogSites`, `H1-R.hostBoundary`, `C09`

Dependencies:
- `P07-T003`
- `P04-T014`

Ownership selectors:
- `services:dialog-sites-four`

Files to create:
- `Sources/MonaCodeAppKit/Services/MonaDialogService.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Services/MonaDialogServiceTests.swift`

Interfaces consumed:
- `MonaStandaloneServices`
- `MonaCodeEditorView`

Interfaces produced:
- `MonaDialogService`

Red verification:
- Run: `swift test --filter MonaDialogServiceTests/testFourSiteOutcomeMatrix`
  - Expected exit: `1`
  - Expected output includes: `DIALOG_SITE_MISMATCH site=saveConflict`

Minimal implementation operations:
- `Map exactly four retained dialog call sites to native sheet or alert requests.`
- `Require an attached authorized host window and expose accepted, canceled, and unavailable outcomes.`
- `Never fabricate acceptance when presentation is unavailable.`

Green verification:
- Run: `swift test --filter MonaDialogServiceTests`
  - Expected exit: `0`
  - Expected output includes: `DIALOG_SITES count=4 outcomes=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T004.json`

Completion assertions:
- `All four sites use explicit native outcomes.`
- `Detached editors return unavailable.`
- `No web dialog surface ships.`

Commit boundary:
- `Sources/MonaCodeAppKit/Services/MonaDialogService.swift`
- `Tests/MonaCodeAppKitTests/Services/MonaDialogServiceTests.swift`

<!-- monacode-plan-task:{"id":"P07-T005","recordSha256":"37aa360dd0be7dd7a82f0460a31ba082bac7043201d6f679226e09eedcaeae4c"} -->
## P07-T005 — Implement seven host groups and ten concrete host types

Contract: `H1-R`, `H1-R2`, `G5-R.deliveryScope.hostGroups`, `C09`

Dependencies:
- `P07-T003`
- `P06-T009`

Ownership selectors:
- `normativeLayer:native-embedding-host:H1-R`
- `normativeLayer:native-embedding-host:H1-R2`
- `machineArtifact:H1-R-native-boundary`
- `machineArtifact:H1-R2-host-group`

Files to create:
- `Sources/MonaCode/Host/MonaHostContracts.swift`
- `Sources/MonaCode/Host/MonaOpenerRegistry.swift`
- `Sources/MonaCodeAppKit/Host/MonaAppKitHostAdapters.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Host/MonaHostContractClosureTests.swift`

Interfaces consumed:
- `MonaCodeEnvironment`
- `MonaMessageTransport`
- `MonaCommandRegistry`
- `MonaURI`

Interfaces produced:
- `MonaHostContractSet`
- `MonaOpenerRegistry`
- `MonaAppKitHostAdapters`

Red verification:
- Run: `swift test --filter MonaHostContractClosureTests/testSevenGroupsTenTypes`
  - Expected exit: `1`
  - Expected output includes: `HOST_CONTRACT_SET_MISMATCH groups=7 concreteTypes=10`

Minimal implementation operations:
- `Implement environment, opener-registry, workspace-edit, command, logging, LSP-transport, and multi-diff-data host groups.`
- `Expose exactly ten concrete public types with their frozen throwing, nonthrowing, ordering, disposal, and fallback behavior.`
- `Keep link and code-editor opener registries distinct and traverse last-registered-first.`
- `Add no implicit URL, file, network, logging, transport, or workspace authority.`

Green verification:
- Run: `swift test --filter MonaHostContractClosureTests`
  - Expected exit: `0`
  - Expected output includes: `HOST_CONTRACTS groups=7 concreteTypes=10 implicitAuthority=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T005.json`

Completion assertions:
- `Seven host groups and ten concrete types are exact.`
- `Every host action requires explicit attachment.`
- `Opener fallthrough and disposal order match H1-R2.`

Commit boundary:
- `Sources/MonaCode/Host/MonaHostContracts.swift`
- `Sources/MonaCode/Host/MonaOpenerRegistry.swift`
- `Sources/MonaCodeAppKit/Host/MonaAppKitHostAdapters.swift`
- `Tests/MonaCodeAppKitTests/Host/MonaHostContractClosureTests.swift`

<!-- monacode-plan-task:{"id":"P07-T006","recordSha256":"3db38f104d7024a2d47820e1ff27dba08e6bd5afd9d31d0f2de0930f2003417b"} -->
## P07-T006 — Implement the four-outcome WorkspaceEdit transaction

Contract: `H1-R.workspaceEdit`, `R1.transactionRecovery`, `C07`, `C09`

Dependencies:
- `P07-T005`
- `P01-T010`

Ownership selectors:
- `host:workspace-edit`
- `transaction:workspace-edit`

Files to create:
- `Sources/MonaCode/Host/MonaWorkspaceEdit.swift`
- `Sources/MonaCode/Host/MonaPreparedWorkspaceTransaction.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Host/MonaWorkspaceEditTests.swift`

Interfaces consumed:
- `MonaTransactionGateway`
- `MonaHostContractSet`

Interfaces produced:
- `MonaWorkspaceEdit`
- `MonaPreparedWorkspaceTransaction`
- `MonaWorkspaceEditOutcome`

Red verification:
- Run: `swift test --filter MonaWorkspaceEditTests/testFourOutcomeAndRollbackMatrix`
  - Expected exit: `1`
  - Expected output includes: `WORKSPACE_EDIT_PARTIAL_COMMIT outcome=externalRejected`

Minimal implementation operations:
- `Prepare open-model edits inside component truth and external resource operations through the explicit host.`
- `Expose applied, rejected, failed, and canceled outcomes with exact failure details.`
- `Require a prepared nonthrowing atomic external commit before publishing open-model changes.`
- `Roll back every prepared open-model mutation when external preparation or commit fails.`

Green verification:
- Run: `swift test --filter MonaWorkspaceEditTests`
  - Expected exit: `0`
  - Expected output includes: `WORKSPACE_EDIT outcomes=4 partialCommits=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T006.json`

Completion assertions:
- `All four outcomes are distinguishable.`
- `External failure cannot partially mutate open models.`
- `Cancellation and stale versions leave no side effects.`

Commit boundary:
- `Sources/MonaCode/Host/MonaWorkspaceEdit.swift`
- `Sources/MonaCode/Host/MonaPreparedWorkspaceTransaction.swift`
- `Tests/MonaCodeTests/Host/MonaWorkspaceEditTests.swift`

<!-- monacode-plan-task:{"id":"P07-T007","recordSha256":"7413398374ba6a3c74d09e428c0936d500a4c3e5c8507587212ffcabab82014b"} -->
## P07-T007 — Close the bounded cache registry and provisional cache manifest

Contract: `H2-R.cacheRegistry`, `S1-R.cacheBounds`, `D1-R.cache`, `C09`

Dependencies:
- `P07-T002`
- `P07-T003`
- `P06-T010`
- `P02-T007`

Ownership selectors:
- `machineArtifact:H2-R-runtime-resource`
- `candidate-producer:MonaCacheManifest.json`

Files to create:
- `Sources/MonaCode/Runtime/MonaCacheRegistry.swift`
- `Tools/Candidates/build-cache-manifest.mjs`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Runtime/MonaCacheRegistryTests.swift`

Interfaces consumed:
- `MonaDiffCache`
- `MonaSessionStore`
- `MonaNormalizer`
- `MonaGlobalLifetime`

Interfaces produced:
- `MonaCacheRegistry`
- `ProvisionalMonaCacheManifest`

Red verification:
- Run: `swift test --filter MonaCacheRegistryTests/testExactSetBoundsAndPlateau`
  - Expected exit: `1`
  - Expected output includes: `CACHE_BOUND_EXCEEDED cache=diff actual=12 max=11`

Minimal implementation operations:
- `Register every cache with exact owner, key shape, entry bound, byte bound, counter width, invalidation, eviction, and quiescent plateau.`
- `Include suggestion caches 300/200/50/20, two normalization caches of 10000, and maximum-11 diff cache.`
- `Reject unregistered cache allocations and signed-counter overflow.`
- `Emit a provisional cache manifest for Phase 08 regeneration.`

Green verification:
- Run: `swift test --filter MonaCacheRegistryTests`
  - Expected exit: `0`
  - Expected output includes: `CACHE_REGISTRY exactSet=pass bounds=pass plateau=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T007.json`

Completion assertions:
- `All cache identities and bounds are explicit.`
- `Quiescent usage reaches the declared plateau.`
- `The candidate output remains provisional.`

Commit boundary:
- `Sources/MonaCode/Runtime/MonaCacheRegistry.swift`
- `Tools/Candidates/build-cache-manifest.mjs`
- `Tests/MonaCodeTests/Runtime/MonaCacheRegistryTests.swift`

<!-- monacode-plan-task:{"id":"P07-T008","recordSha256":"f034a6fa2357ad59139612163f88340008da7c2e0d29940325e90d6e0da976ae"} -->
## P07-T008 — Close runtime-style substitutions and full source inventory

Contract: `X1-R`, `G5-R.implementationOutputRules`, `C04`, `C10`

Dependencies:
- `P07-T006`
- `P07-T007`
- `P06-T010`
- `P05-T200`

Ownership selectors:
- `normativeLayer:source-runtime-style:X1-R`
- `machineArtifact:X1-R-source-runtime-style`
- `candidate-producer:MonaSourceClosureManifest.json`

Files to create:
- `Tools/Candidates/build-source-closure-manifest.mjs`
- `Tests/PlanStructureTests/SourceClosureTests.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/SourceRuntimeStyleTests.mjs`

Interfaces consumed:
- `MonaFiniteIntrinsics`
- `MonaRuntimeLocaleSnapshot`
- `MonaCacheRegistry`

Interfaces produced:
- `ProvisionalMonaSourceClosureManifest`

Red verification:
- Run: `node --test Tests/PlanStructureTests/SourceRuntimeStyleTests.mjs --test-name-pattern missing-occurrence`
  - Expected exit: `1`
  - Expected output includes: `SOURCE_OCCURRENCE_UNMAPPED profile=binary64`

Minimal implementation operations:
- `Enumerate every product source file, generated source, resource, license, finite runtime substitution, native style projection, and explicit cut.`
- `Verify X1-R set-equality counts 956, 98, 1281, 3120, 84, and 8221 plus all 2120 localization messages.`
- `Reject source or resource paths that are absent from the manifest and reject forbidden runtime classes.`
- `Emit a provisional source-closure manifest pending Phase 08 release regeneration.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/SourceRuntimeStyleTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `SOURCE_CLOSURE occurrences=exact unmanifestedSources=0 state=provisional`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T008.json`

Completion assertions:
- `Every X1-R occurrence is mapped.`
- `Every production source and resource is enumerated.`
- `The candidate output remains provisional until release source freezes.`

Commit boundary:
- `Tools/Candidates/build-source-closure-manifest.mjs`
- `Tests/PlanStructureTests/SourceClosureTests.mjs`
- `Tests/PlanStructureTests/SourceRuntimeStyleTests.mjs`

<!-- monacode-plan-task:{"id":"P07-T009","recordSha256":"feadcb585abf1acc16af47876f81c56c5cec94bb5a487e92f85fdfb04155d9be"} -->
## P07-T009 — Deliver diff and multi-diff views, SwiftUI wrappers, and sample-host activation

Contract: `G5-R.deliveryScope.requiredViews`, `G5-R.deliveryScope.requiredSwiftUITypes`, `H1-R.multiDiffData`, `C09`

Dependencies:
- `P07-T002`
- `P07-T005`
- `P04-T015`

Ownership selectors:
- `public-view:MonaDiffEditorView`
- `public-view:MonaMultiDiffEditorView`
- `public-swiftui:MonaDiffEditor`
- `public-swiftui:MonaMultiDiffEditor`

Files to create:
- `Sources/MonaCodeAppKit/Views/MonaDiffEditorView.swift`
- `Sources/MonaCodeAppKit/Views/MonaMultiDiffEditorView.swift`
- `Sources/MonaCodeSwiftUI/MonaDiffEditor.swift`
- `Sources/MonaCodeSwiftUI/MonaMultiDiffEditor.swift`

Files to modify:
- `Sources/MonaCodeSample/main.swift`

Test files:
- `Tests/MonaCodeAppKitTests/Views/MonaDiffViewLifecycleTests.swift`

Interfaces consumed:
- `MonaDiffCoordinator`
- `MonaCodeEditorView`
- `MonaHostContractSet`

Interfaces produced:
- `MonaDiffEditorView`
- `MonaMultiDiffEditorView`
- `MonaDiffEditor`
- `MonaMultiDiffEditor`

Red verification:
- Run: `swift test --filter MonaDiffViewLifecycleTests/testMultiDiffStableIdentityAndDisposal`
  - Expected exit: `1`
  - Expected output includes: `MULTI_DIFF_IDENTITY_DRIFT item=7`

Minimal implementation operations:
- `Compose original and modified editors over shared models and one diff coordinator.`
- `Consume ordered multi-diff snapshots with stable item identity and synchronous change events.`
- `Wrap both native views with lifecycle-only SwiftUI types.`
- `Activate all three products in the sample host without adding production dependencies.`

Green verification:
- Run: `swift test --filter MonaDiffViewLifecycleTests`
  - Expected exit: `0`
  - Expected output includes: `DIFF_VIEWS appKit=2 swiftUI=2 stableIdentity=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T009.json`

Completion assertions:
- `All three required AppKit views exist.`
- `All four required SwiftUI types exist.`
- `Sample host exercises the three-product graph.`

Commit boundary:
- `Sources/MonaCodeAppKit/Views/MonaDiffEditorView.swift`
- `Sources/MonaCodeAppKit/Views/MonaMultiDiffEditorView.swift`
- `Sources/MonaCodeSwiftUI/MonaDiffEditor.swift`
- `Sources/MonaCodeSwiftUI/MonaMultiDiffEditor.swift`
- `Sources/MonaCodeSample/main.swift`
- `Tests/MonaCodeAppKitTests/Views/MonaDiffViewLifecycleTests.swift`

<!-- monacode-plan-task:{"id":"P07-T010","recordSha256":"9bc02aa20a54dc7b287d30ad3229e791c75c627ce0953f2cc794fcb1809d9d49"} -->
## P07-T010 — Close diff, service, host, cache, source, and view conformance

Contract: `D1-R`, `S1-R`, `H1-R`, `H1-R2`, `H2-R`, `X1-R`, `C05`, `C09`

Dependencies:
- `P07-T004`
- `P07-T006`
- `P07-T007`
- `P07-T008`
- `P07-T009`

Ownership selectors:
- `phase-gate:07`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Phase07HostAndDiffConformanceTests.swift`

Interfaces consumed:
- `MonaDiffCoordinator`
- `MonaStandaloneServices`
- `MonaHostContractSet`
- `MonaPreparedWorkspaceTransaction`
- `MonaCacheRegistry`
- `ProvisionalMonaSourceClosureManifest`
- `MonaMultiDiffEditorView`

Interfaces produced:
- `Phase07HostAndDiffGate`

Red verification:
- Run: `swift test --filter Phase07HostAndDiffConformanceTests/testSeededWorkspaceCommitFailure`
  - Expected exit: `1`
  - Expected output includes: `PHASE07_HOST_DIFF_GATE_FAILED fixture=workspace-commit-failure`

Minimal implementation operations:
- `Run diff, service, dialog, opener, workspace edit, command host, log sink, transport factory, multi-diff data, cache, source, and lifecycle matrices.`
- `Inject timeout, stale diff, cache allocation, host rejection, opener fallthrough, external commit, reentry, and disposal failures.`
- `Verify three views, four wrappers, seven host groups, ten concrete types, and all source occurrence counts.`

Green verification:
- Run: `swift test --filter Phase07HostAndDiffConformanceTests`
  - Expected exit: `0`
  - Expected output includes: `PHASE07_HOST_DIFF_GATE C05=pass C09=pass partialCommits=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T010.json`

Completion assertions:
- `Diff and host correctness prerequisites pass.`
- `All caches and source occurrences are closed provisionally.`
- `Failure paths preserve transaction and lifetime invariants.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Phase07HostAndDiffConformanceTests.swift`

<!-- monacode-plan-task:{"id":"P07-T011","recordSha256":"ffb49d2f6459f20bca1215ba081eecdf710c0263b4bcc5ab17a935bab4f92bbd"} -->
## P07-T011 — Freeze the final public API closure before candidate generation

Contract: `F1-R4.publicDeclarations`, `H1-R.publicTypes`, `G5-R.designClosure.candidateOrder`

Dependencies:
- `P04-T014`
- `P04-T015`
- `P05-T001`
- `P05-T012`
- `P06-T004`
- `P07-T009`
- `P07-T010`

Ownership selectors:
- `public-api-closure`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/PublicAPIClosureTests.mjs`

Interfaces consumed:
- `MonaPublicDeclarationGraph`
- `MonaCodeEditorView`
- `MonaCodeEditor`
- `MonaLSPClient`
- `MonaDiffEditorView`
- `MonaMultiDiffEditorView`
- `MonaDiffEditor`
- `MonaMultiDiffEditor`

Interfaces produced:
- `MonaPublicAPIClosure`

Red verification:
- Run: `node --test Tests/PlanStructureTests/PublicAPIClosureTests.mjs --test-name-pattern late-public-symbol`
  - Expected exit: `1`
  - Expected output includes: `PUBLIC_API_AFTER_CLOSURE symbol=MonaLateType`

Minimal implementation operations:
- `Generate symbol graphs and API digester baselines for all three products after every public producer.`
- `Join every public declaration path to one native symbol or explicit cut disposition.`
- `Freeze the public source set and reject every later public declaration or signature change.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/PublicAPIClosureTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `PUBLIC_API_CLOSURE products=3 paths=555 lateSymbols=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-07/P07-T011.json`

Completion assertions:
- `Public API closure is terminal in Phase 07.`
- `All candidate finalizers depend on this closure where required.`
- `No later phase adds public product source.`

Commit boundary:
- `Tests/PlanStructureTests/PublicAPIClosureTests.mjs`
