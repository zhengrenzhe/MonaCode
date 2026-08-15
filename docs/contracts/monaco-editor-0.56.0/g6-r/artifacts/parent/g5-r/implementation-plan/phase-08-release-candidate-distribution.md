# Phase 08: Release candidate and distribution

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 07.

Task count: 10.

<!-- monacode-plan-task:{"id":"P08-T001","recordSha256":"b7e776de342509f8b93886d126caf0c08e4e36fc12f4a74d7df8bc03d63f4a47"} -->
## P08-T001 — Build the frozen three-product release package

Contract: `G5-R.deliveryScope`, `G5-R.validationScope.packageDeploymentTarget`, `C10`

Dependencies:
- `P07-T011`

Ownership selectors:
- `release:three-product-build`
- `release:arm64-macos26`

Files to create:
- `Tools/Release/build-release.sh`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/ReleaseBuildTests.mjs`

Interfaces consumed:
- `MonaPublicAPIClosure`
- `Phase07HostAndDiffGate`

Interfaces produced:
- `MonaReleasePackage`

Red verification:
- Run: `node --test Tests/PlanStructureTests/ReleaseBuildTests.mjs --test-name-pattern wrong-product-set`
  - Expected exit: `1`
  - Expected output includes: `RELEASE_PRODUCT_SET_MISMATCH expected=3`

Minimal implementation operations:
- `Build arm64 macOS 26.0-or-newer release artifacts for MonaCode, MonaCodeAppKit, and MonaCodeSwiftUI plus the sample host.`
- `Record compiler, SDK, deployment target, architecture, binary UUID-independent hashes, and complete artifact paths.`
- `Reject debug-only, unsigned-input, stale-source, extra-product, or missing-target output.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/ReleaseBuildTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `RELEASE_BUILD products=3 nonProductTargets=3 architecture=arm64 deployment=macOS26.0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T001.json`

Completion assertions:
- `Exactly three public products build in release mode.`
- `All three non-product targets remain declared.`
- `Artifacts bind to one frozen source revision.`

Commit boundary:
- `Tools/Release/build-release.sh`
- `Tests/PlanStructureTests/ReleaseBuildTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T002","recordSha256":"417765d808fde302d4e1585bb4c83237e77762107deaefbc8fefb0c5c494d85a"} -->
## P08-T002 — Scan package graph, symbols, links, resources, and forbidden runtimes

Contract: `G5-R.deliveryScope.productionLinkedDependencies`, `G5-R.explicitCuts`, `C10`

Dependencies:
- `P08-T001`

Ownership selectors:
- `release:dependency-scan`
- `release:symbol-resource-scan`

Files to create:
- `Tools/Release/scan-distribution.swift`
- `Tools/Release/scan-symbol-graphs.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/DistributionScanTests.mjs`

Interfaces consumed:
- `MonaReleasePackage`
- `MonaPublicAPIClosure`

Interfaces produced:
- `MonaDistributionScan`
- `MonaReleaseSymbolGraphs`

Red verification:
- Run: `node --test Tests/PlanStructureTests/DistributionScanTests.mjs --test-name-pattern forbidden-runtime`
  - Expected exit: `1`
  - Expected output includes: `FORBIDDEN_RUNTIME_LINKED name=JavaScriptCore`

Minimal implementation operations:
- `Run package dump, describe, and dependency scans for exact products and targets.`
- `Generate and compare symbol graphs plus API digester output for all three products.`
- `Enumerate linked dylibs, embedded resources, exported symbols, source maps, scripts, WASM, language content, and third-party runtime classes.`
- `Reject every linked or bundled item outside the contract allowlist.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/DistributionScanTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `DISTRIBUTION_SCAN products=3 publicAPIDrift=0 forbiddenRuntime=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T002.json`

Completion assertions:
- `Package and public API sets are exact.`
- `Production links only allowed system frameworks and repository code.`
- `Forbidden runtime and resource classes are absent.`

Commit boundary:
- `Tools/Release/scan-distribution.swift`
- `Tools/Release/scan-symbol-graphs.mjs`
- `Tests/PlanStructureTests/DistributionScanTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T003","recordSha256":"9a958a0d575fff9b97ca91ed21162958b11c1d07fe811b1d72910141e78f6383"} -->
## P08-T003 — Assemble exact license provenance and distribution notices

Contract: `G5-R.licensingProfile`, `P1-R`, `C10`

Dependencies:
- `P08-T001`
- `P05-T006`
- `P05-T007`
- `P06-T008`
- `P02-T005`
- `P02-T007`

Ownership selectors:
- `release:license-notices`
- `provenance:distribution-inputs`

Files to create:
- `Sources/MonaCode/Generated/LICENSE.md`
- `Tools/Release/verify-notices.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/LicenseNoticeTests.mjs`

Interfaces consumed:
- `ComparatorProvenanceLock`
- `MonaLocalizationProfileSet`
- `MonaIconRegistry`
- `MonaMarkdownParser`
- `MonaRegExpUnicodeProfileSet`

Interfaces produced:
- `MonaLicenseNoticeSet`

Red verification:
- Run: `node --test Tests/PlanStructureTests/LicenseNoticeTests.mjs --test-name-pattern missing-notice`
  - Expected exit: `1`
  - Expected output includes: `LICENSE_NOTICE_MISSING profile=chromium-icu`

Minimal implementation operations:
- `Assemble Monaco MIT, Monaco localization MIT, Marked 14 MIT, LSP specification CC BY 4.0, Codicon CC BY 4.0 plus Git Logo exception and generator MIT, Unicode-3.0, Chromium ICU, Test262 BSD, and esbuild comparator notices.`
- `Record DOMPurify, V8/ICU runtime, and vscode-unicode-data as oracle-only or excluded inputs with no derived production code.`
- `Verify pinned license hashes: LSP 9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188, Chromium ICU e55522d81edc687a341a4411e0776e54ca654e90147f354a90458aaced4116af, Codicon artwork af5e030844efddbc7ab00dcfea8b019703753d4d9f5172d727c533a492aec665, and Codicon code 9906940f61b1f0b533fa7d99baf55178b2808fbe113ea51dfbfad8572ccd5f2b.`
- `Attach provenance headers to every generated table and asset.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/LicenseNoticeTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `LICENSE_NOTICES profiles=complete hashMismatches=0 unlicensedInputs=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T003.json`

Completion assertions:
- `Every distributed or generated input has the exact notice.`
- `Oracle-only inputs are absent from product output.`
- `No unlicensed vscode-unicode-data input or output exists.`

Commit boundary:
- `Sources/MonaCode/Generated/LICENSE.md`
- `Tools/Release/verify-notices.mjs`
- `Tests/PlanStructureTests/LicenseNoticeTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T010","recordSha256":"a738f8134734f32cd9524cf53dcfad05de1b34c20743122185d4d519d95f1cd4"} -->
## P08-T010 — Finalize MonaNativeDeclarationManifest after public API closure

Contract: `F1-R4`, `F1-R5`, `G5-R.candidateGeneratedArtifacts.MonaNativeDeclarationManifest`

Dependencies:
- `P07-T011`
- `P08-T002`
- `P05-T190`

Ownership selectors:
- `candidate-finalizer:MonaNativeDeclarationManifest.json`

Files to create:
- `Tools/Candidates/finalize-native-declaration-manifest.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/FinalNativeDeclarationManifestTests.mjs`

Interfaces consumed:
- `MonaPublicAPIClosure`
- `MonaReleaseSymbolGraphs`
- `ProvisionalMonaNativeDeclarationManifest`

Interfaces produced:
- `MonaNativeDeclarationManifest.json`

Red verification:
- Run: `node --test Tests/PlanStructureTests/FinalNativeDeclarationManifestTests.mjs --test-name-pattern late-symbol`
  - Expected exit: `1`
  - Expected output includes: `NATIVE_DECLARATION_FINALIZATION_FAILED reason=late-public-symbol`

Minimal implementation operations:
- `Regenerate all declaration, signature, disposition, owner, symbol, and product rows from the frozen release outputs.`
- `Verify 555 public paths, five instance surfaces, three views, four SwiftUI types, 62 retained features, and three distinct native colorize replacements.`
- `Hash every source artifact and mark the candidate final only after zero drift.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/FinalNativeDeclarationManifestTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `CANDIDATE_FINAL name=MonaNativeDeclarationManifest.json paths=555 drift=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T010.json`

Completion assertions:
- `The native declaration candidate follows public API closure.`
- `All public and feature sets are exact.`
- `Candidate hash binds to release symbols and sources.`

Commit boundary:
- `Tools/Candidates/finalize-native-declaration-manifest.mjs`
- `Tests/PlanStructureTests/FinalNativeDeclarationManifestTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T011","recordSha256":"78b3c7236d5c8e059b7dced5fcc2d460d74b42785dfef8d22085e73499b85bb5"} -->
## P08-T011 — Finalize MonaRegExpUnicodeManifest after all semantic consumers

Contract: `M1-R3`, `G5-R.candidateGeneratedArtifacts.MonaRegExpUnicodeManifest`

Dependencies:
- `P07-T011`
- `P08-T003`
- `P02-T009`
- `P06-T007`

Ownership selectors:
- `candidate-finalizer:MonaRegExpUnicodeManifest.json`

Files to create:
- `Tools/Candidates/finalize-regexp-unicode-manifest.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/FinalRegExpUnicodeManifestTests.mjs`

Interfaces consumed:
- `RegExpCandidateInputSet`
- `MonaRegExpConsumerProfileSet`
- `MonaLicenseNoticeSet`

Interfaces produced:
- `MonaRegExpUnicodeManifest.json`

Red verification:
- Run: `node --test Tests/PlanStructureTests/FinalRegExpUnicodeManifestTests.mjs --test-name-pattern wrong-consumer-set`
  - Expected exit: `1`
  - Expected output includes: `REGEXP_UNICODE_FINALIZATION_FAILED expectedConsumerProfiles=10`

Minimal implementation operations:
- `Regenerate six distinct Unicode profiles, ten consumer mappings, Test262 selection, generator inputs, licenses, and output hashes.`
- `Verify every final semantic consumer appears and no post-finalization product consumer exists.`
- `Mark the candidate final only after exact provenance reproduction.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/FinalRegExpUnicodeManifestTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `CANDIDATE_FINAL name=MonaRegExpUnicodeManifest.json unicodeProfiles=6 consumers=10`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T011.json`

Completion assertions:
- `Six profiles and ten consumers remain exact.`
- `All generated data and licenses reproduce.`
- `Candidate follows the last RegExp consumer.`

Commit boundary:
- `Tools/Candidates/finalize-regexp-unicode-manifest.mjs`
- `Tests/PlanStructureTests/FinalRegExpUnicodeManifestTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T012","recordSha256":"af8f6b4455bce6d72b15cfd3c2d52318018f534c00f0aed079fb574791673e86"} -->
## P08-T012 — Finalize MonaEnvironmentManifest after every environment-sensitive consumer

Contract: `E1-R`, `X1-R.environmentConsumers`, `G5-R.candidateGeneratedArtifacts.MonaEnvironmentManifest`

Dependencies:
- `P07-T011`
- `P08-T003`
- `P02-T009`
- `P07-T008`

Ownership selectors:
- `candidate-finalizer:MonaEnvironmentManifest.json`

Files to create:
- `Tools/Candidates/finalize-environment-manifest.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/FinalEnvironmentManifestTests.mjs`

Interfaces consumed:
- `EnvironmentCandidateInputSet`
- `ProvisionalMonaSourceClosureManifest`
- `MonaLicenseNoticeSet`

Interfaces produced:
- `MonaEnvironmentManifest.json`

Red verification:
- Run: `node --test Tests/PlanStructureTests/FinalEnvironmentManifestTests.mjs --test-name-pattern missing-occurrence`
  - Expected exit: `1`
  - Expected output includes: `ENVIRONMENT_FINALIZATION_FAILED occurrence=StopWatch`

Minimal implementation operations:
- `Regenerate clock, entropy, number formatting, locale, calendar, numbering, time zone, case, collation, normalization, and finite-intrinsic occurrence rows.`
- `Verify set equality against E1-R and X1-R plus generated input and output hashes.`
- `Mark the candidate final only after the last source consumer and notice input.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/FinalEnvironmentManifestTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `CANDIDATE_FINAL name=MonaEnvironmentManifest.json occurrences=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T012.json`

Completion assertions:
- `Every environment-sensitive occurrence is present exactly once.`
- `Generated tables and sources reproduce.`
- `Candidate follows all product consumers.`

Commit boundary:
- `Tools/Candidates/finalize-environment-manifest.mjs`
- `Tests/PlanStructureTests/FinalEnvironmentManifestTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T013","recordSha256":"7f9a44a579fd05fb0d4742453738213e9c6b3b1382c047773d2c0353ce57cee5"} -->
## P08-T013 — Finalize MonaSourceClosureManifest from the release source set

Contract: `X1-R`, `G5-R.implementationOutputRules`, `G5-R.candidateGeneratedArtifacts.MonaSourceClosureManifest`

Dependencies:
- `P07-T011`
- `P08-T002`
- `P08-T003`
- `P07-T008`

Ownership selectors:
- `candidate-finalizer:MonaSourceClosureManifest.json`

Files to create:
- `Tools/Candidates/finalize-source-closure-manifest.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/FinalSourceClosureManifestTests.mjs`

Interfaces consumed:
- `ProvisionalMonaSourceClosureManifest`
- `MonaDistributionScan`
- `MonaLicenseNoticeSet`

Interfaces produced:
- `MonaSourceClosureManifest.json`

Red verification:
- Run: `node --test Tests/PlanStructureTests/FinalSourceClosureManifestTests.mjs --test-name-pattern unmanifested-source`
  - Expected exit: `1`
  - Expected output includes: `SOURCE_CLOSURE_FINALIZATION_FAILED path=Sources/MonaCode/Late.swift`

Minimal implementation operations:
- `Regenerate the complete product source, generated source, resource, notice, finite-runtime, native-style, and explicit-cut inventory from release inputs.`
- `Include the renderer source branch frozen in Phase 03 and reject every source path created afterward.`
- `Verify all X1-R set-equality counts and artifact hashes before finalization.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/FinalSourceClosureManifestTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `CANDIDATE_FINAL name=MonaSourceClosureManifest.json unmanifestedSources=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T013.json`

Completion assertions:
- `Release source set is exhaustively enumerated.`
- `Renderer branch and all generated assets are bound.`
- `No unmanifested production source remains.`

Commit boundary:
- `Tools/Candidates/finalize-source-closure-manifest.mjs`
- `Tests/PlanStructureTests/FinalSourceClosureManifestTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T014","recordSha256":"806dc62148bb914326143a16c5149a0f8dc2ad1a91f684dafa8ecc69f54f8120"} -->
## P08-T014 — Finalize MonaCacheManifest from all registered caches

Contract: `H2-R.cacheRegistry`, `S1-R.cacheBounds`, `G5-R.candidateGeneratedArtifacts.MonaCacheManifest`

Dependencies:
- `P07-T011`
- `P08-T002`
- `P07-T007`

Ownership selectors:
- `candidate-finalizer:MonaCacheManifest.json`

Files to create:
- `Tools/Candidates/finalize-cache-manifest.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/FinalCacheManifestTests.mjs`

Interfaces consumed:
- `ProvisionalMonaCacheManifest`
- `MonaDistributionScan`

Interfaces produced:
- `MonaCacheManifest.json`

Red verification:
- Run: `node --test Tests/PlanStructureTests/FinalCacheManifestTests.mjs --test-name-pattern undeclared-cache`
  - Expected exit: `1`
  - Expected output includes: `CACHE_FINALIZATION_FAILED cache=lateCache`

Minimal implementation operations:
- `Regenerate the exact cache identity, owner, key, entry bound, byte bound, invalidation, eviction, counter, and plateau set.`
- `Scan release symbols and source paths for undeclared cache-like storage.`
- `Mark the candidate final only when exact-set and all bounds pass.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/FinalCacheManifestTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `CANDIDATE_FINAL name=MonaCacheManifest.json undeclaredCaches=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T014.json`

Completion assertions:
- `All caches are declared and bounded.`
- `Release source contains no hidden cache.`
- `Candidate binds to the release revision.`

Commit boundary:
- `Tools/Candidates/finalize-cache-manifest.mjs`
- `Tests/PlanStructureTests/FinalCacheManifestTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T015","recordSha256":"ecde066bd9339ba79021afd3159e073ac4f03d1f5933743b82cb97fa57127fe2"} -->
## P08-T015 — Finalize MonaDistributionManifest after package and notice closure

Contract: `G5-R.deliveryScope`, `G5-R.licensingProfile`, `G5-R.candidateGeneratedArtifacts.MonaDistributionManifest`, `C10`

Dependencies:
- `P08-T001`
- `P08-T002`
- `P08-T003`
- `P08-T010`
- `P08-T011`
- `P08-T012`
- `P08-T013`
- `P08-T014`

Ownership selectors:
- `candidate-finalizer:MonaDistributionManifest.json`

Files to create:
- `Tools/Candidates/finalize-distribution-manifest.mjs`

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/FinalDistributionManifestTests.mjs`

Interfaces consumed:
- `MonaReleasePackage`
- `MonaDistributionScan`
- `MonaLicenseNoticeSet`
- `MonaNativeDeclarationManifest.json`
- `MonaRegExpUnicodeManifest.json`
- `MonaEnvironmentManifest.json`
- `MonaSourceClosureManifest.json`
- `MonaCacheManifest.json`

Interfaces produced:
- `MonaDistributionManifest.json`

Red verification:
- Run: `node --test Tests/PlanStructureTests/FinalDistributionManifestTests.mjs --test-name-pattern artifact-hash-drift`
  - Expected exit: `1`
  - Expected output includes: `DISTRIBUTION_FINALIZATION_FAILED artifact=MonaCode.framework`

Minimal implementation operations:
- `Record every release artifact, product, target, architecture, deployment target, symbol graph, dependency, linked dylib, resource, license profile, and SHA-256.`
- `Join the five preceding static candidates and verify their source revision and hash agreement.`
- `Record exact absence of every prohibited runtime, resource, service, language bundle, and unlicensed input.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/FinalDistributionManifestTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `CANDIDATE_FINAL name=MonaDistributionManifest.json products=3 forbidden=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T015.json`

Completion assertions:
- `Distribution candidate follows build, scans, notices, and five other static candidates.`
- `All release artifact hashes agree.`
- `Every prohibited class is explicitly absent.`

Commit boundary:
- `Tools/Candidates/finalize-distribution-manifest.mjs`
- `Tests/PlanStructureTests/FinalDistributionManifestTests.mjs`

<!-- monacode-plan-task:{"id":"P08-T016","recordSha256":"1cb4aa1e3cf2e53eb3cdb329023c1de1c0c38fb4016b93c2e06103f3476a4904"} -->
## P08-T016 — Validate the exact six-static-candidate release set

Contract: `G5-R.candidateGeneratedArtifacts`, `G5-R.designClosure.candidateOrder`

Dependencies:
- `P08-T010`
- `P08-T011`
- `P08-T012`
- `P08-T013`
- `P08-T014`
- `P08-T015`

Ownership selectors:
- `candidate-consumer:MonaNativeDeclarationManifest.json`
- `candidate-consumer:MonaRegExpUnicodeManifest.json`
- `candidate-consumer:MonaEnvironmentManifest.json`
- `candidate-consumer:MonaSourceClosureManifest.json`
- `candidate-consumer:MonaCacheManifest.json`
- `candidate-consumer:MonaDistributionManifest.json`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/PlanStructureTests/SixStaticCandidateSetTests.mjs`

Interfaces consumed:
- `MonaNativeDeclarationManifest.json`
- `MonaRegExpUnicodeManifest.json`
- `MonaEnvironmentManifest.json`
- `MonaSourceClosureManifest.json`
- `MonaCacheManifest.json`
- `MonaDistributionManifest.json`

Interfaces produced:
- `MonaStaticCandidateSet`

Red verification:
- Run: `node --test Tests/PlanStructureTests/SixStaticCandidateSetTests.mjs --test-name-pattern stale-candidate`
  - Expected exit: `1`
  - Expected output includes: `STATIC_CANDIDATE_SET_INVALID reason=source-revision-mismatch`

Minimal implementation operations:
- `Require exactly the six static candidate names with no duplicate or extra artifact.`
- `Verify schema, source revision, dependency edges, internal hashes, release hash, and mutual references.`
- `Exclude QEnvironmentID because it is recollected per formal Phase 09 run.`

Green verification:
- Run: `node --test Tests/PlanStructureTests/SixStaticCandidateSetTests.mjs`
  - Expected exit: `0`
  - Expected output includes: `STATIC_CANDIDATE_SET count=6 orderFailures=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-08/P08-T016.json`

Completion assertions:
- `All six static candidates are final and mutually consistent.`
- `No acceptance run has started.`
- `QEnvironmentID remains run-specific.`

Commit boundary:
- `Tests/PlanStructureTests/SixStaticCandidateSetTests.mjs`
