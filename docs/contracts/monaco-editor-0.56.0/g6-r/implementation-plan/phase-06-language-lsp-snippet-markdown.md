<!-- G6-R-PHASE:06 -->

# Phase 06 — Language, LSP, snippet, and Markdown

- Phase: `06`
- Title: Language, LSP, snippet, and Markdown
- Document: `implementation-plan/phase-06-language-lsp-snippet-markdown.md`
- Dependencies: `05` 
- Tasks: 10

## Tasks

<!-- G6-R-TASK:P06-T001:44cc5393ba290c4e7f4e09d4bcc0a4faa2b0eba58cfa6a58a3726a2b307087ed -->

### P06-T001 — Define a transport-neutral byte channel in Core

- Record SHA-256: `44cc5393ba290c4e7f4e09d4bcc0a4faa2b0eba58cfa6a58a3726a2b307087ed`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T200` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T001`
- Evidence commit message: `evidence(monacode): complete P06-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/LSP/MonaMessageTransportContractTests.swift`

### Stage `red`

- verification-command: `P06-T001.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Expose only ordered byte receive, byte send, close, error, and disposal operations.`
- implementation-operation: `Keep framing, JSON, session state, launch policy, file descriptors, and platform lifecycle outside the protocol.`
- implementation-operation: `Serialize close and error terminal events exactly once.`

### Stage `green`

- verification-command: `P06-T001.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/LSP/MonaMessageTransport.swift
  - Sources/MonaCode/LSP/MonaTransportEvent.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/LSP/MonaMessageTransportContractTests.swift

<!-- G6-R-TASK:P06-T002:89b657aa4dd7117f2a47f100c5104fb7f67d19153f66775a4e6fefcb01cc69aa -->

### P06-T002 — Implement streaming LSP frame decoding and encoding

- Record SHA-256: `89b657aa4dd7117f2a47f100c5104fb7f67d19153f66775a4e6fefcb01cc69aa`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P06-T001` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T002`
- Evidence commit message: `evidence(monacode): complete P06-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/LSP/MonaLSPFrameCodecTests.swift`

### Stage `red`

- verification-command: `P06-T002.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Decode arbitrary header and body fragmentation with exact Content-Length validation.`
- implementation-operation: `Reject duplicate, malformed, negative, overflowed, missing, and oversized lengths with typed terminal errors.`
- implementation-operation: `Encode canonical ASCII headers and raw JSON payload bytes without text normalization.`

### Stage `green`

- verification-command: `P06-T002.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/LSP/MonaLSPFrameDecoder.swift
  - Sources/MonaCode/LSP/MonaLSPFrameEncoder.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/LSP/MonaLSPFrameCodecTests.swift

<!-- G6-R-TASK:P06-T003:37a3ef0a4417f0de2f11616e30872d17952700770dbbc34d8b16624559c254cc -->

### P06-T003 — Implement deterministic JSON-RPC wire values and errors

- Record SHA-256: `37a3ef0a4417f0de2f11616e30872d17952700770dbbc34d8b16624559c254cc`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P06-T002` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T003`
- Evidence commit message: `evidence(monacode): complete P06-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/LSP/MonaJSONRPCCodecTests.swift`

### Stage `red`

- verification-command: `P06-T003.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Preserve string, integer, and null identifiers without coercion.`
- implementation-operation: `Distinguish requests, notifications, responses, and errors by exact field directionality.`
- implementation-operation: `Emit deterministic object-key order and number spelling for fixture hashes.`
- implementation-operation: `Reject malformed wire shapes with the L2-R3 typed error taxonomy.`

### Stage `green`

- verification-command: `P06-T003.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/LSP/MonaJSONValue.swift
  - Sources/MonaCode/LSP/MonaJSONRPCMessage.swift
  - Sources/MonaCode/LSP/MonaJSONRPCCodec.swift
  - Sources/MonaCode/LSP/MonaJSONRPCError.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/LSP/MonaJSONRPCCodecTests.swift

<!-- G6-R-TASK:P06-T004:00349e305f063c36ef1173dcd467a8a8405f33fecb8bf55aa9c60c0169e9fa63 -->

### P06-T004 — Implement LSP session state and 25 capability mappings

- Record SHA-256: `00349e305f063c36ef1173dcd467a8a8405f33fecb8bf55aa9c60c0169e9fa63`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T013`, `P06-T003` 
- Test contract cases: 1
- Red-scaffold rows: 4
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T004`
- Evidence commit message: `evidence(monacode): complete P06-T004`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T004.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/LSP/MonaLSPClientCapabilityTests.swift`

### Stage `red`

- verification-command: `P06-T004.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement initialize, initialized, shutdown, exit, restart, request, notification, cancellation, progress, and error state transitions.`
- implementation-operation: `Map exactly 25 LSP-backed provider surfaces with raw UTF-16 positions and explicit capability availability.`
- implementation-operation: `Handle static and dynamic registration, resolve, release, partial results, stale responses, and versionless diagnostics.`
- implementation-operation: `Publish provider results only through validity tickets and the deterministic executor.`

### Stage `green`

- verification-command: `P06-T004.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/LSP/MonaLSPClient.swift
  - Sources/MonaCode/LSP/MonaLSPSession.swift
  - Sources/MonaCode/LSP/MonaLSPCapabilityRegistry.swift
  - Sources/MonaCode/LSP/MonaLSPProviderAdapters.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/LSP/MonaLSPClientCapabilityTests.swift

<!-- G6-R-TASK:P06-T005:f75074da2acc88dd1c53fbbe43a7741654d6f06fb6ef5b459670a72a3a82fd14 -->

### P06-T005 — Close all 30 provider registries and five direct-only surfaces

- Record SHA-256: `f75074da2acc88dd1c53fbbe43a7741654d6f06fb6ef5b459670a72a3a82fd14`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T008`, `P06-T004` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T005`
- Evidence commit message: `evidence(monacode): complete P06-T005`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T005.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Language/MonaProviderRegistryClosureTests.swift`

### Stage `red`

- verification-command: `P06-T005.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Register exactly 30 provider identities: 25 LSP-backed and five direct-only.`
- implementation-operation: `Implement direct token factory, new-symbol-name, multi-document-highlight, paste-edit, and drop-edit adapters without pretending they are LSP capabilities.`
- implementation-operation: `Return explicit unavailable capability or plain-text behavior when no provider is attached.`
- implementation-operation: `Never bundle a built-in language implementation or server.`

### Stage `green`

- verification-command: `P06-T005.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Language/MonaProviderRegistry.swift
  - Sources/MonaCode/Language/MonaDirectProviderAdapters.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Language/MonaProviderRegistryClosureTests.swift

<!-- G6-R-TASK:P06-T006:e1ff7033d376ae6f372441bc4f6b6ed4d47a1ccd700ef18b3b81f928a8a2581e -->

### P06-T006 — Port the complete snippet parser and grammar

- Record SHA-256: `e1ff7033d376ae6f372441bc4f6b6ed4d47a1ccd700ef18b3b81f928a8a2581e`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P02-T004`, `P06-T005` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T006`
- Evidence commit message: `evidence(monacode): complete P06-T006`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T006.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Snippet/MonaSnippetParserTests.swift`

### Stage `red`

- verification-command: `P06-T006.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Port text, escape, tabstop, placeholder, choice, variable, nested child, transform, format, conditional, and fallback grammar.`
- implementation-operation: `Preserve source offsets and depth-first parse order over raw UTF-16.`
- implementation-operation: `Execute transform RegExp through the declared snippet consumer profile.`

### Stage `green`

- verification-command: `P06-T006.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Snippet/MonaSnippetAST.swift
  - Sources/MonaCode/Snippet/MonaSnippetParser.swift
  - Sources/MonaCode/Snippet/MonaSnippetTransform.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Snippet/MonaSnippetParserTests.swift

<!-- G6-R-TASK:P06-T007:874c200b3d487e8d41c78b63f390eeeffc858d4465da01ed7489d7b12e39c8ca -->

### P06-T007 — Implement snippet variables, resolvers, sessions, and multi-cursor ordering

- Record SHA-256: `874c200b3d487e8d41c78b63f390eeeffc858d4465da01ed7489d7b12e39c8ca`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T005`, `P06-T006` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T007`
- Evidence commit message: `evidence(monacode): complete P06-T007`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T007.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Snippet/MonaSnippetSessionTests.swift`

### Stage `red`

- verification-command: `P06-T007.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement all 39 variable identifiers, clipboard spreading, time snapshot, original index, selected text, file, workspace, comment, random, and UUID resolvers.`
- implementation-operation: `Resolve variables in depth-first parser order with one injected time snapshot and shared entropy sequence.`
- implementation-operation: `Manage placeholder navigation, nested sessions, merge, cancel, undo, and 1/100/10000 cursor insertion through the input barrier.`

### Stage `green`

- verification-command: `P06-T007.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Snippet/MonaSnippetVariableResolver.swift
  - Sources/MonaCode/Snippet/MonaSnippetSession.swift
  - Sources/MonaCode/Snippet/MonaSnippetController.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Snippet/MonaSnippetSessionTests.swift

<!-- G6-R-TASK:P06-T008:3b0794a4d9f4c2203f1902910f3afb0f8b2de3c76d606e7eb7bdc6412810c99d -->

### P06-T008 — Port Markdown semantics into a native presentation tree

- Record SHA-256: `3b0794a4d9f4c2203f1902910f3afb0f8b2de3c76d606e7eb7bdc6412810c99d`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P05-T007`, `P06-T005` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T008`
- Evidence commit message: `evidence(monacode): complete P06-T008`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T008.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Markdown/MonaMarkdownSecurityTests.swift`

### Stage `red`

- verification-command: `P06-T008.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Port the pinned Marked 14 grammar subset with its MIT notice and modification record.`
- implementation-operation: `Produce a semantic tree for native text, code, lists, tables, links, and trusted command metadata.`
- implementation-operation: `Reject raw HTML execution, style, scripts, media loading, remote images, web layout, and untrusted command links.`
- implementation-operation: `Keep parsed source ranges in raw UTF-16.`

### Stage `green`

- verification-command: `P06-T008.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Markdown/MonaMarkdownAST.swift
  - Sources/MonaCode/Markdown/MonaMarkdownParser.swift
  - Sources/MonaCode/Markdown/MonaMarkdownPresentation.swift
  - Sources/MonaCode/Markdown/MARKED-MIT-LICENSE.txt
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Markdown/MonaMarkdownSecurityTests.swift

<!-- G6-R-TASK:P06-T009:0ef47617bc1b1ae8016513e61cb1b6c979229a2051c0129adf23941fb67776c6 -->

### P06-T009 — Implement the macOS host byte-transport adapter outside Core

- Record SHA-256: `0ef47617bc1b1ae8016513e61cb1b6c979229a2051c0129adf23941fb67776c6`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T014`, `P06-T001` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T009`
- Evidence commit message: `evidence(monacode): complete P06-T009`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T009.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Host/MonaProcessMessageTransportTests.swift`

### Stage `red`

- verification-command: `P06-T009.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Launch only an explicitly host-authorized executable with an explicit environment and working directory.`
- implementation-operation: `Bridge standard input and output bytes to the transport-neutral Core protocol.`
- implementation-operation: `Serialize partial writes, end-of-file, exit, cancellation, termination, and disposal without embedding framing logic.`

### Stage `green`

- verification-command: `P06-T009.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Host/MonaProcessMessageTransport.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Host/MonaProcessMessageTransportTests.swift

<!-- G6-R-TASK:P06-T010:1ba778ee03706115c83e96639549bee7cf108818a3536443246a315a4f51b3a2 -->

### P06-T010 — Close LSP, provider, snippet, Markdown, and plain-text fallback behavior

- Record SHA-256: `1ba778ee03706115c83e96639549bee7cf108818a3536443246a315a4f51b3a2`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P06-T005`, `P06-T007`, `P06-T008`, `P06-T009` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P06-T010`
- Evidence commit message: `evidence(monacode): complete P06-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-06/P06-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Phase06LanguageInfrastructureTests.swift`

### Stage `red`

- verification-command: `P06-T010.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run transport fragmentation, framing, JSON direction, session, capability, provider, cancellation, stale, snippet, Markdown, hostile-input, and fallback matrices.`
- implementation-operation: `Inject malformed frames, oversized frames, duplicate IDs, disconnect, restart, late response, provider reentry, and release failures.`
- implementation-operation: `Verify product binaries contain no built-in language implementation, server, grammar pack, JavaScript runtime, or ICU runtime.`

### Stage `green`

- verification-command: `P06-T010.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

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
  - Tests/ConformanceAndFailureInjection/Phase06LanguageInfrastructureTests.swift
