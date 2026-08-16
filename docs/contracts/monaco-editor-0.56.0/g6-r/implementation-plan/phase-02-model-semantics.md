<!-- G6-R-PHASE:02 -->

# Phase 02 — Model semantics and environment behavior

- Phase: `02`
- Title: Model semantics and environment behavior
- Document: `implementation-plan/phase-02-model-semantics.md`
- Dependencies: `01` 
- Tasks: 9

## Tasks

<!-- G6-R-TASK:P02-T001:2a962cb38ed5c1c16c468a84fdeda0ba715810b6d6b1d947756d07f2b893399b -->

### P02-T001 — Implement undo and redo elements on transaction truth

- Record SHA-256: `2a962cb38ed5c1c16c468a84fdeda0ba715810b6d6b1d947756d07f2b893399b`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T013` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T001`
- Evidence commit message: `evidence(monacode): complete P02-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Model/MonaUndoRedoTests.swift`

### Stage `red`

- verification-command: `P02-T001.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Port edit grouping, stack elements, EOL changes, selection recovery, and alternative-version transitions.`
- implementation-operation: `Route undo and redo mutations through the same transaction gateway as direct edits.`
- implementation-operation: `Roll back stack position when a replay transaction fails.`

### Stage `green`

- verification-command: `P02-T001.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Model/Undo/MonaUndoRedoElement.swift
  - Sources/MonaCode/Model/Undo/MonaUndoRedoStack.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Model/MonaUndoRedoTests.swift

<!-- G6-R-TASK:P02-T002:693eb8c281773e0236d9001c782ca03cc180e51ecb5c01e4acd1f5c6a29e9028 -->

### P02-T002 — Port decoration interval trees and stickiness semantics

- Record SHA-256: `693eb8c281773e0236d9001c782ca03cc180e51ecb5c01e4acd1f5c6a29e9028`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T001` 
- Test contract cases: 2
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T002`
- Evidence commit message: `evidence(monacode): complete P02-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Model/MonaDecorationTreeDifferentialTests.swift`

### Stage `red`

- verification-command: `P02-T002.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Port interval augmentation, owner filtering, range movement, overview data, and stickiness updates.`
- implementation-operation: `Update decoration positions inside transaction commit before public change events.`
- implementation-operation: `Instrument insert, delete, interval query, and owner query operation counts.`

### Stage `green`

- verification-command: `P02-T002.GREEN.001` (kind=all-success, network=forbidden, timeout=600000ms, leaves=2)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Model/Decorations/MonaDecoration.swift
  - Sources/MonaCode/Model/Decorations/MonaDecorationTree.swift
  - Sources/MonaCode/Model/Decorations/MonaDecorationCollection.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Model/MonaDecorationTreeDifferentialTests.swift
  - Tests/MonaCodeTests/Model/MonaDecorationTreeComplexityTests.swift

<!-- G6-R-TASK:P02-T003:ca4b02ac27629f3887e60b52f43ba9c60f7a8adf9d05b2648466252f67bad504 -->

### P02-T003 — Implement word, grapheme, literal search, and replacement primitives

- Record SHA-256: `ca4b02ac27629f3887e60b52f43ba9c60f7a8adf9d05b2648466252f67bad504`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T002` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T003`
- Evidence commit message: `evidence(monacode): complete P02-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Model/MonaWordSearchTests.swift`

### Stage `red`

- verification-command: `P02-T003.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement the frozen word-separator and grapheme profiles over raw UTF-16.`
- implementation-operation: `Port forward and backward literal search, zero-length progression, match limits, and replacement capture syntax.`
- implementation-operation: `Keep case conversion and RegExp execution behind the explicit Phase 02 providers.`

### Stage `green`

- verification-command: `P02-T003.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Model/Search/MonaWordClassifier.swift
  - Sources/MonaCode/Model/Search/MonaGraphemeSegmenter.swift
  - Sources/MonaCode/Model/Search/MonaLiteralSearch.swift
  - Sources/MonaCode/Model/Search/MonaReplacePattern.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Model/MonaWordSearchTests.swift

<!-- G6-R-TASK:P02-T004:600193e64e5ccadd36bbbea14874c10037eeebcc876585c030981dfdfa692824 -->

### P02-T004 — Implement the finite ECMAScript RegExp parser and compiler

- Record SHA-256: `600193e64e5ccadd36bbbea14874c10037eeebcc876585c030981dfdfa692824`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T003` 
- Test contract cases: 1
- Red-scaffold rows: 5
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T004`
- Evidence commit message: `evidence(monacode): complete P02-T004`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T004.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/RegExp/MonaRegExpParserCompilerTests.swift`

### Stage `red`

- verification-command: `P02-T004.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Parse the exact grammar, flags, assertions, classes, quantifiers, groups, named captures, and backreferences retained by M1-R.`
- implementation-operation: `Compile deterministic bytecode with explicit step, stack, and capture bounds.`
- implementation-operation: `Execute over raw UInt16 input with frozen lastIndex and zero-length progression behavior.`
- implementation-operation: `Return typed syntax and resource errors with exact source offsets.`

### Stage `green`

- verification-command: `P02-T004.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/RegExp/MonaRegExpAST.swift
  - Sources/MonaCode/RegExp/MonaRegExpParser.swift
  - Sources/MonaCode/RegExp/MonaRegExpCompiler.swift
  - Sources/MonaCode/RegExp/MonaRegExpProgram.swift
  - Sources/MonaCode/RegExp/MonaRegExpExecutor.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/RegExp/MonaRegExpParserCompilerTests.swift

<!-- G6-R-TASK:P02-T005:708cf62cf1d5e75641501671a6d7e5d1de481f94df338ecf1128bdbfab40fc25 -->

### P02-T005 — Generate six non-mergeable RegExp Unicode profiles

- Record SHA-256: `708cf62cf1d5e75641501671a6d7e5d1de481f94df338ecf1128bdbfab40fc25`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T004` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T005`
- Evidence commit message: `evidence(monacode): complete P02-T005`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T005.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/RegExp/MonaRegExpUnicodeProfileTests.swift`

### Stage `red`

- verification-command: `P02-T005.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Generate exactly six separately identified Unicode table profiles from the pinned licensed inputs.`
- implementation-operation: `Record source version, input hash, generator hash, output hash, property set, and consumer set.`
- implementation-operation: `Reject profile merging even when generated ranges happen to compare equal.`

### Stage `green`

- verification-command: `P02-T005.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Tools/Generators/generate-regexp-unicode.mjs
  - Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift
  - Sources/MonaCode/Generated/RegExp/UNICODE-LICENSE.txt
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/RegExp/MonaRegExpUnicodeProfileTests.swift

<!-- G6-R-TASK:P02-T006:b34ac4d4c0fdfc5917578513961c36e8521651973a0ebe8075adbc3287ec4ca6 -->

### P02-T006 — Close ten RegExp consumer profiles with pinned Test262 vectors

- Record SHA-256: `b34ac4d4c0fdfc5917578513961c36e8521651973a0ebe8075adbc3287ec4ca6`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T005` 
- Test contract cases: 2
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T006`
- Evidence commit message: `evidence(monacode): complete P02-T006`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T006.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/RegExp/MonaRegExpTest262Tests.swift`

### Stage `red`

- verification-command: `P02-T006.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Bind each frozen RegExp occurrence to one of ten named consumer profiles.`
- implementation-operation: `Run the exact pinned Test262 inclusion and exclusion manifest.`
- implementation-operation: `Exercise find, replace, word, transform, filter, and configuration consumers at T-1, T, and T+1 bounds.`

### Stage `green`

- verification-command: `P02-T006.GREEN.001` (kind=all-success, network=forbidden, timeout=600000ms, leaves=2)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/RegExp/MonaRegExpConsumerProfile.swift
  - Tests/Fixtures/DifferentialFixtures/regexp/test262-manifest.json
  - Tests/MonaCodeTests/RegExp/MonaRegExpConsumerProfileTests.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/RegExp/MonaRegExpTest262Tests.swift

<!-- G6-R-TASK:P02-T007:1d568bd3aa5be709da5c8eb0efb73882c005771c2885b452a00efb18542cb5af -->

### P02-T007 — Implement fixed case conversion, collation, and normalization profiles

- Record SHA-256: `1d568bd3aa5be709da5c8eb0efb73882c005771c2885b452a00efb18542cb5af`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T003` 
- Test contract cases: 1
- Red-scaffold rows: 5
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T007`
- Evidence commit message: `evidence(monacode): complete P02-T007`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T007.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Environment/MonaEnvironmentSemanticsTests.swift`

### Stage `red`

- verification-command: `P02-T007.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Generate finite case and collation data from the pinned Chromium ICU input and record exact provenance.`
- implementation-operation: `Implement only the normalization forms and locale-sensitive behaviors enumerated by E1-R.`
- implementation-operation: `Maintain the two fixed 10000-entry normalization caches with explicit bounds and counters.`

### Stage `green`

- verification-command: `P02-T007.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Tools/Generators/generate-environment-tables.mjs
  - Sources/MonaCode/Generated/Environment/MonaCaseTables.swift
  - Sources/MonaCode/Generated/Environment/MonaCollationTables.swift
  - Sources/MonaCode/Environment/MonaCaseConverter.swift
  - Sources/MonaCode/Environment/MonaCollator.swift
  - Sources/MonaCode/Environment/MonaNormalizer.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Environment/MonaEnvironmentSemanticsTests.swift

<!-- G6-R-TASK:P02-T008:7c5cff4a1702f3cea9cf2e0d013fdd5216353eb398b287f2299d89fc188482e6 -->

### P02-T008 — Implement finite ECMAScript intrinsics, codecs, and String SHA-1

- Record SHA-256: `7c5cff4a1702f3cea9cf2e0d013fdd5216353eb398b287f2299d89fc188482e6`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T006`, `P02-T007` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T008`
- Evidence commit message: `evidence(monacode): complete P02-T008`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T008.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Runtime/MonaFiniteIntrinsicTests.swift`

### Stage `red`

- verification-command: `P02-T008.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement only the exact intrinsic occurrences listed by X1-R.`
- implementation-operation: `Preserve binary64 rounding, signed zero, NaN classification, graceful decoding, UTF-8 encoding, and SHA-1 input-unit behavior.`
- implementation-operation: `Reject any request outside the finite profile with a typed unsupported-operation error.`

### Stage `green`

- verification-command: `P02-T008.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Runtime/MonaFiniteIntrinsics.swift
  - Sources/MonaCode/Runtime/MonaBinary64.swift
  - Sources/MonaCode/Runtime/MonaTextCodec.swift
  - Sources/MonaCode/Runtime/MonaStringSHA1.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Runtime/MonaFiniteIntrinsicTests.swift

<!-- G6-R-TASK:P02-T009:8d478e7fd1ca61ba8dc674da55aa891e385611cfa57538b58a89226ab7a666b6 -->

### P02-T009 — Validate provisional RegExp and environment candidate inputs

- Record SHA-256: `8d478e7fd1ca61ba8dc674da55aa891e385611cfa57538b58a89226ab7a666b6`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T001`, `P02-T002`, `P02-T006`, `P02-T008` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P02-T009`
- Evidence commit message: `evidence(monacode): complete P02-T009`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-02/P02-T009.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Phase02SemanticConformanceTests.swift`

### Stage `red`

- verification-command: `P02-T009.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Join undo, decoration, word, search, RegExp, Unicode, environment, and intrinsic evidence by exact source revision.`
- implementation-operation: `Validate provisional candidate inputs without marking either candidate finalized or present.`
- implementation-operation: `Record the last known downstream consumers that Phase 08 must follow before regeneration.`

### Stage `green`

- verification-command: `P02-T009.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Phase02SemanticConformanceTests.swift
