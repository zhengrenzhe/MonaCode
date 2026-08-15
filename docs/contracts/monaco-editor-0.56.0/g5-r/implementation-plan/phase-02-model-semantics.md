# Phase 02: Model semantics and environment behavior

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 01.

Task count: 9.

<!-- monacode-plan-task:{"id":"P02-T001","recordSha256":"21fbd500131f22aa945997e02bc24d1f1bb2653de57bb1c99fc123b12310ca74"} -->
## P02-T001 — Implement undo and redo elements on transaction truth

Contract: `M1-R2.undoRedo`, `A+.transactions`, `C01`, `P02`

Dependencies:
- `P01-T013`

Ownership selectors:
- `model:undo-redo`
- `transaction:undo-elements`

Files to create:
- `Sources/MonaCode/Model/Undo/MonaUndoRedoElement.swift`
- `Sources/MonaCode/Model/Undo/MonaUndoRedoStack.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Model/MonaUndoRedoTests.swift`

Interfaces consumed:
- `MonaTransactionGateway`
- `MonaSelection`

Interfaces produced:
- `MonaUndoRedoElement`
- `MonaUndoRedoStack`

Red verification:
- Run: `swift test --filter MonaUndoRedoTests/testAlternativeVersionTrace`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=undo-alternative-version`

Minimal implementation operations:
- `Port edit grouping, stack elements, EOL changes, selection recovery, and alternative-version transitions.`
- `Route undo and redo mutations through the same transaction gateway as direct edits.`
- `Roll back stack position when a replay transaction fails.`

Green verification:
- Run: `swift test --filter MonaUndoRedoTests`
  - Expected exit: `0`
  - Expected output includes: `UNDO_REDO_PARITY traces=420 rollback=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T001.json`

Completion assertions:
- `Undo and redo traces match M0/M1.`
- `Selection and version restoration are exact.`
- `Failed replay does not move the stack cursor.`

Commit boundary:
- `Sources/MonaCode/Model/Undo/MonaUndoRedoElement.swift`
- `Sources/MonaCode/Model/Undo/MonaUndoRedoStack.swift`
- `Tests/MonaCodeTests/Model/MonaUndoRedoTests.swift`

<!-- monacode-plan-task:{"id":"P02-T002","recordSha256":"86ff461e6ca6d10dd37991b298d3a2293fa81b16769fa61e291c10edade36f80"} -->
## P02-T002 — Port decoration interval trees and stickiness semantics

Contract: `M1-R2.decorations`, `F1-R2.modelSurface`, `C01`, `P07`

Dependencies:
- `P02-T001`

Ownership selectors:
- `model:decoration-tree`
- `model:decoration-stickiness`

Files to create:
- `Sources/MonaCode/Model/Decorations/MonaDecoration.swift`
- `Sources/MonaCode/Model/Decorations/MonaDecorationTree.swift`
- `Sources/MonaCode/Model/Decorations/MonaDecorationCollection.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Model/MonaDecorationTreeDifferentialTests.swift`
- `Tests/MonaCodeTests/Model/MonaDecorationTreeComplexityTests.swift`

Interfaces consumed:
- `MonaRange`
- `MonaTransactionGateway`

Interfaces produced:
- `MonaDecoration`
- `MonaDecorationTree`
- `MonaDecorationCollection`

Red verification:
- Run: `swift test --filter MonaDecorationTreeDifferentialTests/testStickinessBoundaryMatrix`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=decoration-stickiness-boundary`

Minimal implementation operations:
- `Port interval augmentation, owner filtering, range movement, overview data, and stickiness updates.`
- `Update decoration positions inside transaction commit before public change events.`
- `Instrument insert, delete, interval query, and owner query operation counts.`

Green verification:
- Run: `swift test --filter MonaDecorationTreeDifferentialTests && swift test --filter MonaDecorationTreeComplexityTests`
  - Expected exit: `0`
  - Expected output includes: `DECORATION_TREE_PARITY traces=10000 complexity=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T002.json`

Completion assertions:
- `Boundary stickiness is zero-diff.`
- `Owner and range queries preserve order.`
- `Complexity retains the frozen upper bounds.`

Commit boundary:
- `Sources/MonaCode/Model/Decorations/MonaDecoration.swift`
- `Sources/MonaCode/Model/Decorations/MonaDecorationTree.swift`
- `Sources/MonaCode/Model/Decorations/MonaDecorationCollection.swift`
- `Tests/MonaCodeTests/Model/MonaDecorationTreeDifferentialTests.swift`
- `Tests/MonaCodeTests/Model/MonaDecorationTreeComplexityTests.swift`

<!-- monacode-plan-task:{"id":"P02-T003","recordSha256":"696b1e7cc08a7b36bc2d258bd1723a0cc1992677ba36aa500ad545498671feed"} -->
## P02-T003 — Implement word, grapheme, literal search, and replacement primitives

Contract: `M1-R.wordAndSearch`, `E1-R.segmentation`, `C01`, `P08`

Dependencies:
- `P02-T002`

Ownership selectors:
- `model:word-boundaries`
- `model:grapheme-profile`
- `model:search-base`

Files to create:
- `Sources/MonaCode/Model/Search/MonaWordClassifier.swift`
- `Sources/MonaCode/Model/Search/MonaGraphemeSegmenter.swift`
- `Sources/MonaCode/Model/Search/MonaLiteralSearch.swift`
- `Sources/MonaCode/Model/Search/MonaReplacePattern.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Model/MonaWordSearchTests.swift`

Interfaces consumed:
- `MonaCodeModel`
- `MonaRange`

Interfaces produced:
- `MonaWordClassifier`
- `MonaGraphemeSegmenter`
- `MonaLiteralSearch`
- `MonaReplacePattern`

Red verification:
- Run: `swift test --filter MonaWordSearchTests/testIsolatedSurrogateWordBoundary`
  - Expected exit: `1`
  - Expected output includes: `DIFFERENTIAL_MISMATCH fixture=word-boundary-isolated-surrogate`

Minimal implementation operations:
- `Implement the frozen word-separator and grapheme profiles over raw UTF-16.`
- `Port forward and backward literal search, zero-length progression, match limits, and replacement capture syntax.`
- `Keep case conversion and RegExp execution behind the explicit Phase 02 providers.`

Green verification:
- Run: `swift test --filter MonaWordSearchTests`
  - Expected exit: `0`
  - Expected output includes: `WORD_SEARCH_PARITY fixtures=180 zeroLength=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T003.json`

Completion assertions:
- `Word and grapheme boundaries match fixed profiles.`
- `Literal and zero-length searches terminate and match comparators.`
- `Replacement parsing preserves raw units.`

Commit boundary:
- `Sources/MonaCode/Model/Search/MonaWordClassifier.swift`
- `Sources/MonaCode/Model/Search/MonaGraphemeSegmenter.swift`
- `Sources/MonaCode/Model/Search/MonaLiteralSearch.swift`
- `Sources/MonaCode/Model/Search/MonaReplacePattern.swift`
- `Tests/MonaCodeTests/Model/MonaWordSearchTests.swift`

<!-- monacode-plan-task:{"id":"P02-T004","recordSha256":"5b42faf5a6dd124ea19f8a60ef0da2271751289368c378fff9022bca5822b01f"} -->
## P02-T004 — Implement the finite ECMAScript RegExp parser and compiler

Contract: `M1-R.regexpEngine`, `M1-R3.provenance`, `C01`, `P08`

Dependencies:
- `P02-T003`

Ownership selectors:
- `regexp:parser`
- `regexp:compiler`
- `regexp:executor`

Files to create:
- `Sources/MonaCode/RegExp/MonaRegExpAST.swift`
- `Sources/MonaCode/RegExp/MonaRegExpParser.swift`
- `Sources/MonaCode/RegExp/MonaRegExpCompiler.swift`
- `Sources/MonaCode/RegExp/MonaRegExpProgram.swift`
- `Sources/MonaCode/RegExp/MonaRegExpExecutor.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/RegExp/MonaRegExpParserCompilerTests.swift`

Interfaces consumed:
- `MonaLiteralSearch`
- `MonaCancellationToken`

Interfaces produced:
- `MonaRegExpAST`
- `MonaRegExpProgram`
- `MonaRegExpExecutor`

Red verification:
- Run: `swift test --filter MonaRegExpParserCompilerTests/testUnicodeBackreferenceTrace`
  - Expected exit: `1`
  - Expected output includes: `REGEXP_DIFFERENTIAL_MISMATCH fixture=unicode-backreference`

Minimal implementation operations:
- `Parse the exact grammar, flags, assertions, classes, quantifiers, groups, named captures, and backreferences retained by M1-R.`
- `Compile deterministic bytecode with explicit step, stack, and capture bounds.`
- `Execute over raw UInt16 input with frozen lastIndex and zero-length progression behavior.`
- `Return typed syntax and resource errors with exact source offsets.`

Green verification:
- Run: `swift test --filter MonaRegExpParserCompilerTests`
  - Expected exit: `0`
  - Expected output includes: `REGEXP_CORE parserVectors=860 executorVectors=2200 failures=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T004.json`

Completion assertions:
- `Parser acceptance and rejection match the frozen oracle.`
- `Capture and lastIndex traces are exact.`
- `Execution is bounded and cancellation-aware.`

Commit boundary:
- `Sources/MonaCode/RegExp/MonaRegExpAST.swift`
- `Sources/MonaCode/RegExp/MonaRegExpParser.swift`
- `Sources/MonaCode/RegExp/MonaRegExpCompiler.swift`
- `Sources/MonaCode/RegExp/MonaRegExpProgram.swift`
- `Sources/MonaCode/RegExp/MonaRegExpExecutor.swift`
- `Tests/MonaCodeTests/RegExp/MonaRegExpParserCompilerTests.swift`

<!-- monacode-plan-task:{"id":"P02-T005","recordSha256":"9de460683a30b6a78da8c0f277a2fc81833306da86ef902a240ab1bd6334e8f8"} -->
## P02-T005 — Generate six non-mergeable RegExp Unicode profiles

Contract: `M1-R3.unicodeProfiles`, `G5-R.licensingProfile.unicodeTables`, `C01`

Dependencies:
- `P02-T004`

Ownership selectors:
- `regexp:unicode-profiles-six`
- `provenance:unicode-tables`

Files to create:
- `Tools/Generators/generate-regexp-unicode.mjs`
- `Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift`
- `Sources/MonaCode/Generated/RegExp/UNICODE-LICENSE.txt`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/RegExp/MonaRegExpUnicodeProfileTests.swift`

Interfaces consumed:
- `MonaRegExpProgram`

Interfaces produced:
- `MonaRegExpUnicodeProfileSet`
- `ProvisionalMonaRegExpUnicodeManifest`

Red verification:
- Run: `swift test --filter MonaRegExpUnicodeProfileTests/testProfileSetIdentity`
  - Expected exit: `1`
  - Expected output includes: `REGEXP_UNICODE_PROFILE_MERGED expected=6 actual=5`

Minimal implementation operations:
- `Generate exactly six separately identified Unicode table profiles from the pinned licensed inputs.`
- `Record source version, input hash, generator hash, output hash, property set, and consumer set.`
- `Reject profile merging even when generated ranges happen to compare equal.`

Green verification:
- Run: `swift test --filter MonaRegExpUnicodeProfileTests`
  - Expected exit: `0`
  - Expected output includes: `REGEXP_UNICODE_PROFILES count=6 hashes=verified`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T005.json`

Completion assertions:
- `All six profiles remain distinct.`
- `Generated bytes reproduce from pinned inputs.`
- `Unicode license and provenance accompany outputs.`

Commit boundary:
- `Tools/Generators/generate-regexp-unicode.mjs`
- `Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift`
- `Sources/MonaCode/Generated/RegExp/UNICODE-LICENSE.txt`
- `Tests/MonaCodeTests/RegExp/MonaRegExpUnicodeProfileTests.swift`

<!-- monacode-plan-task:{"id":"P02-T006","recordSha256":"c98f1e2868a58c5b4ab3bb86c86de13c0f6467616c9738838abcb97143f07413"} -->
## P02-T006 — Close ten RegExp consumer profiles with pinned Test262 vectors

Contract: `M1-R3.consumerProfiles`, `M1-R3.test262`, `C01`, `P08`

Dependencies:
- `P02-T005`

Ownership selectors:
- `regexp:consumer-profiles-ten`
- `verification:test262-regexp`

Files to create:
- `Sources/MonaCode/RegExp/MonaRegExpConsumerProfile.swift`
- `Tests/Fixtures/DifferentialFixtures/regexp/test262-manifest.json`
- `Tests/MonaCodeTests/RegExp/MonaRegExpConsumerProfileTests.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/RegExp/MonaRegExpTest262Tests.swift`

Interfaces consumed:
- `MonaRegExpExecutor`
- `MonaRegExpUnicodeProfileSet`
- `MonaReplacePattern`

Interfaces produced:
- `MonaRegExpConsumerProfileSet`
- `RegExpTest262Evidence`

Red verification:
- Run: `swift test --filter MonaRegExpConsumerProfileTests/testWrongProfileAtOccurrence`
  - Expected exit: `1`
  - Expected output includes: `REGEXP_CONSUMER_PROFILE_MISMATCH occurrence=findModel`

Minimal implementation operations:
- `Bind each frozen RegExp occurrence to one of ten named consumer profiles.`
- `Run the exact pinned Test262 inclusion and exclusion manifest.`
- `Exercise find, replace, word, transform, filter, and configuration consumers at T-1, T, and T+1 bounds.`

Green verification:
- Run: `swift test --filter MonaRegExpConsumerProfileTests && swift test --filter MonaRegExpTest262Tests`
  - Expected exit: `0`
  - Expected output includes: `REGEXP_CONSUMERS profiles=10 test262=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T006.json`

Completion assertions:
- `Every retained occurrence has one profile.`
- `Test262 selection matches the frozen manifest.`
- `No host regex substitution enters the semantic path.`

Commit boundary:
- `Sources/MonaCode/RegExp/MonaRegExpConsumerProfile.swift`
- `Tests/Fixtures/DifferentialFixtures/regexp/test262-manifest.json`
- `Tests/MonaCodeTests/RegExp/MonaRegExpConsumerProfileTests.swift`
- `Tests/MonaCodeTests/RegExp/MonaRegExpTest262Tests.swift`

<!-- monacode-plan-task:{"id":"P02-T007","recordSha256":"8c7e405364e7aca0f2e1b508cebe91600f56ab60dac436c15eeb2c1f68ae0e36"} -->
## P02-T007 — Implement fixed case conversion, collation, and normalization profiles

Contract: `E1-R.caseCollationNormalization`, `X1-R.environmentConsumers`, `C02`, `P08`

Dependencies:
- `P02-T003`

Ownership selectors:
- `environment:case-conversion`
- `environment:collation`
- `environment:normalization`

Files to create:
- `Tools/Generators/generate-environment-tables.mjs`
- `Sources/MonaCode/Generated/Environment/MonaCaseTables.swift`
- `Sources/MonaCode/Generated/Environment/MonaCollationTables.swift`
- `Sources/MonaCode/Environment/MonaCaseConverter.swift`
- `Sources/MonaCode/Environment/MonaCollator.swift`
- `Sources/MonaCode/Environment/MonaNormalizer.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Environment/MonaEnvironmentSemanticsTests.swift`

Interfaces consumed:
- `MonaRuntimeLocaleSnapshot`

Interfaces produced:
- `MonaCaseConverter`
- `MonaCollator`
- `MonaNormalizer`
- `ProvisionalMonaEnvironmentManifest`

Red verification:
- Run: `swift test --filter MonaEnvironmentSemanticsTests/testPinnedCollationBoundary`
  - Expected exit: `1`
  - Expected output includes: `ENVIRONMENT_DIFFERENTIAL_MISMATCH fixture=collation-T`

Minimal implementation operations:
- `Generate finite case and collation data from the pinned Chromium ICU input and record exact provenance.`
- `Implement only the normalization forms and locale-sensitive behaviors enumerated by E1-R.`
- `Maintain the two fixed 10000-entry normalization caches with explicit bounds and counters.`

Green verification:
- Run: `swift test --filter MonaEnvironmentSemanticsTests`
  - Expected exit: `0`
  - Expected output includes: `ENVIRONMENT_SEMANTICS case=exact collation=exact normalization=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T007.json`

Completion assertions:
- `Case and collation vectors match Chrome 151.`
- `Normalization forms and error cases match.`
- `Generated data is reproducible and licensed.`

Commit boundary:
- `Tools/Generators/generate-environment-tables.mjs`
- `Sources/MonaCode/Generated/Environment/MonaCaseTables.swift`
- `Sources/MonaCode/Generated/Environment/MonaCollationTables.swift`
- `Sources/MonaCode/Environment/MonaCaseConverter.swift`
- `Sources/MonaCode/Environment/MonaCollator.swift`
- `Sources/MonaCode/Environment/MonaNormalizer.swift`
- `Tests/MonaCodeTests/Environment/MonaEnvironmentSemanticsTests.swift`

<!-- monacode-plan-task:{"id":"P02-T008","recordSha256":"d3bad4f5272373d77d6096a320e1749335f31278ebe70be1a9b9be205f5c6c8d"} -->
## P02-T008 — Implement finite ECMAScript intrinsics, codecs, and String SHA-1

Contract: `X1-R.runtimeProfiles`, `E1-R.numberFormatting`, `C02`, `C04`

Dependencies:
- `P02-T006`
- `P02-T007`

Ownership selectors:
- `runtime:finite-intrinsics`
- `runtime:codecs`
- `runtime:string-sha1`

Files to create:
- `Sources/MonaCode/Runtime/MonaFiniteIntrinsics.swift`
- `Sources/MonaCode/Runtime/MonaBinary64.swift`
- `Sources/MonaCode/Runtime/MonaTextCodec.swift`
- `Sources/MonaCode/Runtime/MonaStringSHA1.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Runtime/MonaFiniteIntrinsicTests.swift`

Interfaces consumed:
- `MonaNumberToString`
- `MonaCaseConverter`
- `MonaNormalizer`

Interfaces produced:
- `MonaFiniteIntrinsics`
- `MonaBinary64`
- `MonaTextCodec`
- `MonaStringSHA1`

Red verification:
- Run: `swift test --filter MonaFiniteIntrinsicTests/testBinary64BoundaryVectors`
  - Expected exit: `1`
  - Expected output includes: `INTRINSIC_DIFFERENTIAL_MISMATCH fixture=binary64-boundary`

Minimal implementation operations:
- `Implement only the exact intrinsic occurrences listed by X1-R.`
- `Preserve binary64 rounding, signed zero, NaN classification, graceful decoding, UTF-8 encoding, and SHA-1 input-unit behavior.`
- `Reject any request outside the finite profile with a typed unsupported-operation error.`

Green verification:
- Run: `swift test --filter MonaFiniteIntrinsicTests`
  - Expected exit: `0`
  - Expected output includes: `FINITE_INTRINSICS occurrences=closed unsupported=typed`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T008.json`

Completion assertions:
- `All frozen intrinsic occurrences are exact.`
- `Out-of-profile calls fail explicitly.`
- `No general scripting runtime is present.`

Commit boundary:
- `Sources/MonaCode/Runtime/MonaFiniteIntrinsics.swift`
- `Sources/MonaCode/Runtime/MonaBinary64.swift`
- `Sources/MonaCode/Runtime/MonaTextCodec.swift`
- `Sources/MonaCode/Runtime/MonaStringSHA1.swift`
- `Tests/MonaCodeTests/Runtime/MonaFiniteIntrinsicTests.swift`

<!-- monacode-plan-task:{"id":"P02-T009","recordSha256":"2f6fee9e81c2cf4d382483aa0fe0a9b27f1257e1d2b255d8f84cc2bd19a6a2da"} -->
## P02-T009 — Validate provisional RegExp and environment candidate inputs

Contract: `M1-R`, `M1-R2`, `M1-R3`, `E1-R`, `G5-R.candidateGeneratedArtifacts`

Dependencies:
- `P02-T001`
- `P02-T002`
- `P02-T006`
- `P02-T008`

Ownership selectors:
- `normativeLayer:model-regexp-unicode:M1-R`
- `normativeLayer:model-regexp-unicode:M1-R2`
- `normativeLayer:model-regexp-unicode:M1-R3`
- `machineArtifact:M1-R3-regexp-unicode`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Phase02SemanticConformanceTests.swift`

Interfaces consumed:
- `MonaUndoRedoStack`
- `MonaDecorationTree`
- `MonaRegExpConsumerProfileSet`
- `RegExpTest262Evidence`
- `MonaFiniteIntrinsics`
- `ProvisionalMonaRegExpUnicodeManifest`
- `ProvisionalMonaEnvironmentManifest`

Interfaces produced:
- `Phase02SemanticGate`
- `RegExpCandidateInputSet`
- `EnvironmentCandidateInputSet`

Red verification:
- Run: `swift test --filter Phase02SemanticConformanceTests/testSeededConsumerProfileDrift`
  - Expected exit: `1`
  - Expected output includes: `PHASE02_SEMANTIC_GATE_FAILED profile=findModel`

Minimal implementation operations:
- `Join undo, decoration, word, search, RegExp, Unicode, environment, and intrinsic evidence by exact source revision.`
- `Validate provisional candidate inputs without marking either candidate finalized or present.`
- `Record the last known downstream consumers that Phase 08 must follow before regeneration.`

Green verification:
- Run: `swift test --filter Phase02SemanticConformanceTests`
  - Expected exit: `0`
  - Expected output includes: `PHASE02_SEMANTIC_GATE profiles=10 unicode=6 candidateState=provisional`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-02/P02-T009.json`

Completion assertions:
- `Phase 02 exact-domain suites are zero-diff.`
- `Candidate inputs are complete but explicitly provisional.`
- `No final candidate artifact is claimed.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Phase02SemanticConformanceTests.swift`
