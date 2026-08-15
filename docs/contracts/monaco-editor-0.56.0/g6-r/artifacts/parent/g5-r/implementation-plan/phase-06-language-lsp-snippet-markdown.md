# Phase 06: Language, LSP, snippet, and Markdown

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 05.

Task count: 10.

<!-- monacode-plan-task:{"id":"P06-T001","recordSha256":"ab756326f4393805195f60a40e1d76f679adcb5f7843cff88db09a04c8b9eb60"} -->
## P06-T001 — Define a transport-neutral byte channel in Core

Contract: `L2-R.transportBoundary`, `H1-R.lspTransport`, `C06`

Dependencies:
- `P05-T200`

Ownership selectors:
- `lsp:MonaMessageTransport`
- `lsp:byte-channel`

Files to create:
- `Sources/MonaCode/LSP/MonaMessageTransport.swift`
- `Sources/MonaCode/LSP/MonaTransportEvent.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/LSP/MonaMessageTransportContractTests.swift`

Interfaces consumed:
- `MonaEvent`
- `MonaDisposable`
- `MonaCancellationToken`

Interfaces produced:
- `MonaMessageTransport`
- `MonaTransportEvent`

Red verification:
- Run: `swift test --filter MonaMessageTransportContractTests/testFragmentedByteDelivery`
  - Expected exit: `1`
  - Expected output includes: `TRANSPORT_CONTRACT_MISMATCH fixture=fragmented-bytes`

Minimal implementation operations:
- `Expose only ordered byte receive, byte send, close, error, and disposal operations.`
- `Keep framing, JSON, session state, launch policy, file descriptors, and platform lifecycle outside the protocol.`
- `Serialize close and error terminal events exactly once.`

Green verification:
- Run: `swift test --filter MonaMessageTransportContractTests`
  - Expected exit: `0`
  - Expected output includes: `MESSAGE_TRANSPORT bytesOnly=pass terminalEvents=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T001.json`

Completion assertions:
- `Core transport contains bytes only.`
- `Terminal events are single and ordered.`
- `No host launch type enters Core.`

Commit boundary:
- `Sources/MonaCode/LSP/MonaMessageTransport.swift`
- `Sources/MonaCode/LSP/MonaTransportEvent.swift`
- `Tests/MonaCodeTests/LSP/MonaMessageTransportContractTests.swift`

<!-- monacode-plan-task:{"id":"P06-T002","recordSha256":"24a0f06844c2c452f2e49f430e73910976a0e704b19e266ec91ff02e5f50b4a2"} -->
## P06-T002 — Implement streaming LSP frame decoding and encoding

Contract: `L2-R2`, `C06`, `P11`

Dependencies:
- `P06-T001`

Ownership selectors:
- `normativeLayer:language-lsp:L2-R2`
- `lsp:frame-codec`

Files to create:
- `Sources/MonaCode/LSP/MonaLSPFrameDecoder.swift`
- `Sources/MonaCode/LSP/MonaLSPFrameEncoder.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/LSP/MonaLSPFrameCodecTests.swift`

Interfaces consumed:
- `MonaMessageTransport`

Interfaces produced:
- `MonaLSPFrameDecoder`
- `MonaLSPFrameEncoder`
- `MonaLSPFrameError`

Red verification:
- Run: `swift test --filter MonaLSPFrameCodecTests/testFragmentedHeaderBodyMatrix`
  - Expected exit: `1`
  - Expected output includes: `LSP_FRAME_MISMATCH fixture=split-every-byte`

Minimal implementation operations:
- `Decode arbitrary header and body fragmentation with exact Content-Length validation.`
- `Reject duplicate, malformed, negative, overflowed, missing, and oversized lengths with typed terminal errors.`
- `Encode canonical ASCII headers and raw JSON payload bytes without text normalization.`

Green verification:
- Run: `swift test --filter MonaLSPFrameCodecTests`
  - Expected exit: `0`
  - Expected output includes: `LSP_FRAME_CODEC fragmentation=all malformed=typed`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T002.json`

Completion assertions:
- `Every fragmentation partition decodes identically.`
- `Malformed frames fail at the frozen boundary.`
- `Payload bytes round-trip unchanged.`

Commit boundary:
- `Sources/MonaCode/LSP/MonaLSPFrameDecoder.swift`
- `Sources/MonaCode/LSP/MonaLSPFrameEncoder.swift`
- `Tests/MonaCodeTests/LSP/MonaLSPFrameCodecTests.swift`

<!-- monacode-plan-task:{"id":"P06-T003","recordSha256":"8933bd4dcc2c3595e1828189aa9c7986667d24cfaa5244381c3f1e1a382505d3"} -->
## P06-T003 — Implement deterministic JSON-RPC wire values and errors

Contract: `L2-R3`, `C06`, `P11`

Dependencies:
- `P06-T002`

Ownership selectors:
- `normativeLayer:language-lsp:L2-R3`
- `lsp:json-rpc-codec`

Files to create:
- `Sources/MonaCode/LSP/MonaJSONValue.swift`
- `Sources/MonaCode/LSP/MonaJSONRPCMessage.swift`
- `Sources/MonaCode/LSP/MonaJSONRPCCodec.swift`
- `Sources/MonaCode/LSP/MonaJSONRPCError.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/LSP/MonaJSONRPCCodecTests.swift`

Interfaces consumed:
- `MonaLSPFrameDecoder`
- `MonaLSPFrameEncoder`

Interfaces produced:
- `MonaJSONValue`
- `MonaJSONRPCMessage`
- `MonaJSONRPCCodec`
- `MonaJSONRPCError`

Red verification:
- Run: `swift test --filter MonaJSONRPCCodecTests/testDirectionAndIdentifierMatrix`
  - Expected exit: `1`
  - Expected output includes: `JSON_RPC_DIRECTION_MISMATCH fixture=response-with-method`

Minimal implementation operations:
- `Preserve string, integer, and null identifiers without coercion.`
- `Distinguish requests, notifications, responses, and errors by exact field directionality.`
- `Emit deterministic object-key order and number spelling for fixture hashes.`
- `Reject malformed wire shapes with the L2-R3 typed error taxonomy.`

Green verification:
- Run: `swift test --filter MonaJSONRPCCodecTests`
  - Expected exit: `0`
  - Expected output includes: `JSON_RPC_CODEC vectors=640 deterministic=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T003.json`

Completion assertions:
- `Wire messages preserve exact identifier types.`
- `Encoding hashes are deterministic.`
- `Malformed direction and error shapes are rejected.`

Commit boundary:
- `Sources/MonaCode/LSP/MonaJSONValue.swift`
- `Sources/MonaCode/LSP/MonaJSONRPCMessage.swift`
- `Sources/MonaCode/LSP/MonaJSONRPCCodec.swift`
- `Sources/MonaCode/LSP/MonaJSONRPCError.swift`
- `Tests/MonaCodeTests/LSP/MonaJSONRPCCodecTests.swift`

<!-- monacode-plan-task:{"id":"P06-T004","recordSha256":"3c52e81d3944df967c6550b4963cacad30993994f0ce948069d8f9724512f71d"} -->
## P06-T004 — Implement LSP session state and 25 capability mappings

Contract: `L2-R.lspClient`, `L2-R.capabilityMappings`, `C06`, `P11`

Dependencies:
- `P06-T003`
- `P05-T013`

Ownership selectors:
- `lsp:client-session`
- `provider:lsp-backed-25`

Files to create:
- `Sources/MonaCode/LSP/MonaLSPClient.swift`
- `Sources/MonaCode/LSP/MonaLSPSession.swift`
- `Sources/MonaCode/LSP/MonaLSPCapabilityRegistry.swift`
- `Sources/MonaCode/LSP/MonaLSPProviderAdapters.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/LSP/MonaLSPClientCapabilityTests.swift`

Interfaces consumed:
- `MonaMessageTransport`
- `MonaJSONRPCCodec`
- `MonaProviderExecutor`
- `MonaCodeModel`

Interfaces produced:
- `MonaLSPClient`
- `MonaLSPSession`
- `MonaLSPCapabilityRegistry`
- `MonaLSPProviderAdapters`

Red verification:
- Run: `swift test --filter MonaLSPClientCapabilityTests/testDynamicRegistrationVersionlessDiagnostics`
  - Expected exit: `1`
  - Expected output includes: `LSP_CAPABILITY_STATE_MISMATCH fixture=versionless-diagnostics`

Minimal implementation operations:
- `Implement initialize, initialized, shutdown, exit, restart, request, notification, cancellation, progress, and error state transitions.`
- `Map exactly 25 LSP-backed provider surfaces with raw UTF-16 positions and explicit capability availability.`
- `Handle static and dynamic registration, resolve, release, partial results, stale responses, and versionless diagnostics.`
- `Publish provider results only through validity tickets and the deterministic executor.`

Green verification:
- Run: `swift test --filter MonaLSPClientCapabilityTests`
  - Expected exit: `0`
  - Expected output includes: `LSP_CLIENT mappings=25 dynamicRegistration=pass stalePublications=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T004.json`

Completion assertions:
- `All 25 LSP-backed provider identities have one mapping.`
- `Session and restart state machines are explicit.`
- `Versionless diagnostics follow the frozen policy.`

Commit boundary:
- `Sources/MonaCode/LSP/MonaLSPClient.swift`
- `Sources/MonaCode/LSP/MonaLSPSession.swift`
- `Sources/MonaCode/LSP/MonaLSPCapabilityRegistry.swift`
- `Sources/MonaCode/LSP/MonaLSPProviderAdapters.swift`
- `Tests/MonaCodeTests/LSP/MonaLSPClientCapabilityTests.swift`

<!-- monacode-plan-task:{"id":"P06-T005","recordSha256":"3caab05363ec7a6b1257fc4abb39930f46f2e6115d4ed52a66ddd3dfee351b7e"} -->
## P06-T005 — Close all 30 provider registries and five direct-only surfaces

Contract: `L2-R.providerRegistry`, `F1-R5.providerExecution`, `C06`

Dependencies:
- `P06-T004`
- `P05-T008`

Ownership selectors:
- `normativeLayer:language-lsp:L2-R`
- `provider:all-30`
- `provider:direct-only-5`

Files to create:
- `Sources/MonaCode/Language/MonaProviderRegistry.swift`
- `Sources/MonaCode/Language/MonaDirectProviderAdapters.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Language/MonaProviderRegistryClosureTests.swift`

Interfaces consumed:
- `MonaLSPProviderAdapters`
- `MonaProviderExecutor`
- `MonaLanguageRegistry`

Interfaces produced:
- `MonaProviderRegistry`
- `MonaDirectProviderAdapters`

Red verification:
- Run: `swift test --filter MonaProviderRegistryClosureTests/testExactDispositionMatrix`
  - Expected exit: `1`
  - Expected output includes: `PROVIDER_DISPOSITION_MISMATCH id=MultiDocumentHighlight`

Minimal implementation operations:
- `Register exactly 30 provider identities: 25 LSP-backed and five direct-only.`
- `Implement direct token factory, new-symbol-name, multi-document-highlight, paste-edit, and drop-edit adapters without pretending they are LSP capabilities.`
- `Return explicit unavailable capability or plain-text behavior when no provider is attached.`
- `Never bundle a built-in language implementation or server.`

Green verification:
- Run: `swift test --filter MonaProviderRegistryClosureTests`
  - Expected exit: `0`
  - Expected output includes: `PROVIDER_REGISTRY total=30 lspBacked=25 directOnly=5`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T005.json`

Completion assertions:
- `All 30 provider identities and dispositions are exact.`
- `Direct-only providers remain direct.`
- `No-provider mode is stable plain text.`

Commit boundary:
- `Sources/MonaCode/Language/MonaProviderRegistry.swift`
- `Sources/MonaCode/Language/MonaDirectProviderAdapters.swift`
- `Tests/MonaCodeTests/Language/MonaProviderRegistryClosureTests.swift`

<!-- monacode-plan-task:{"id":"P06-T006","recordSha256":"9201e28278c58332de06f8fcc38d30a4f7c9e8f55e80f9807c0d0cb910a29fb7"} -->
## P06-T006 — Port the complete snippet parser and grammar

Contract: `SN1-R.grammar`, `C06`, `P09`

Dependencies:
- `P06-T005`
- `P02-T004`

Ownership selectors:
- `snippet:parser`
- `snippet:grammar`

Files to create:
- `Sources/MonaCode/Snippet/MonaSnippetAST.swift`
- `Sources/MonaCode/Snippet/MonaSnippetParser.swift`
- `Sources/MonaCode/Snippet/MonaSnippetTransform.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Snippet/MonaSnippetParserTests.swift`

Interfaces consumed:
- `MonaRegExpExecutor`
- `MonaRegExpConsumerProfileSet`

Interfaces produced:
- `MonaSnippetAST`
- `MonaSnippetParser`
- `MonaSnippetTransform`

Red verification:
- Run: `swift test --filter MonaSnippetParserTests/testNestedPlaceholderTransformMatrix`
  - Expected exit: `1`
  - Expected output includes: `SNIPPET_PARSE_MISMATCH fixture=nested-placeholder-transform`

Minimal implementation operations:
- `Port text, escape, tabstop, placeholder, choice, variable, nested child, transform, format, conditional, and fallback grammar.`
- `Preserve source offsets and depth-first parse order over raw UTF-16.`
- `Execute transform RegExp through the declared snippet consumer profile.`

Green verification:
- Run: `swift test --filter MonaSnippetParserTests`
  - Expected exit: `0`
  - Expected output includes: `SNIPPET_PARSER grammarVectors=1240 failures=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T006.json`

Completion assertions:
- `Accepted and rejected grammar vectors match.`
- `Nested and transform nodes preserve order.`
- `No generic template engine enters production.`

Commit boundary:
- `Sources/MonaCode/Snippet/MonaSnippetAST.swift`
- `Sources/MonaCode/Snippet/MonaSnippetParser.swift`
- `Sources/MonaCode/Snippet/MonaSnippetTransform.swift`
- `Tests/MonaCodeTests/Snippet/MonaSnippetParserTests.swift`

<!-- monacode-plan-task:{"id":"P06-T007","recordSha256":"0d271cf2e1339c05ef405d59139aa9bed3930c24d85886717bbb947321e3bd32"} -->
## P06-T007 — Implement snippet variables, resolvers, sessions, and multi-cursor ordering

Contract: `SN1-R.variables`, `SN1-R.session`, `E1-R.entropy`, `C06`, `P09`

Dependencies:
- `P06-T006`
- `P04-T005`

Ownership selectors:
- `normativeLayer:snippet-engine:SN1-R`
- `machineArtifact:SN1-R-snippet-engine`

Files to create:
- `Sources/MonaCode/Snippet/MonaSnippetVariableResolver.swift`
- `Sources/MonaCode/Snippet/MonaSnippetSession.swift`
- `Sources/MonaCode/Snippet/MonaSnippetController.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Snippet/MonaSnippetSessionTests.swift`

Interfaces consumed:
- `MonaSnippetParser`
- `MonaModelInputBarrier`
- `MonaRandomDoubleSource`
- `MonaCryptoRandomSource`
- `MonaWallClock`

Interfaces produced:
- `MonaSnippetVariableResolver`
- `MonaSnippetSession`
- `MonaSnippetController`

Red verification:
- Run: `swift test --filter MonaSnippetSessionTests/testThirtyNineVariableAndDrawOrderMatrix`
  - Expected exit: `1`
  - Expected output includes: `SNIPPET_VARIABLE_MISMATCH variable=RANDOM_HEX`

Minimal implementation operations:
- `Implement all 39 variable identifiers, clipboard spreading, time snapshot, original index, selected text, file, workspace, comment, random, and UUID resolvers.`
- `Resolve variables in depth-first parser order with one injected time snapshot and shared entropy sequence.`
- `Manage placeholder navigation, nested sessions, merge, cancel, undo, and 1/100/10000 cursor insertion through the input barrier.`

Green verification:
- Run: `swift test --filter MonaSnippetSessionTests`
  - Expected exit: `0`
  - Expected output includes: `SNIPPET_SESSION variables=39 cursors=1,100,10000 ordering=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T007.json`

Completion assertions:
- `All 39 variables match fixed vectors.`
- `Entropy and time draw order is exact.`
- `Session edits are transactional and disposable.`

Commit boundary:
- `Sources/MonaCode/Snippet/MonaSnippetVariableResolver.swift`
- `Sources/MonaCode/Snippet/MonaSnippetSession.swift`
- `Sources/MonaCode/Snippet/MonaSnippetController.swift`
- `Tests/MonaCodeTests/Snippet/MonaSnippetSessionTests.swift`

<!-- monacode-plan-task:{"id":"P06-T008","recordSha256":"42e536d1ebde8eba57af6d55cb45fbc570feef9b74b3aa1dc1412b80b0a4383c"} -->
## P06-T008 — Port Markdown semantics into a native presentation tree

Contract: `MD1-R`, `G5-R.licensingProfile.marked`, `C06`, `P11`

Dependencies:
- `P06-T005`
- `P05-T007`

Ownership selectors:
- `normativeLayer:markdown-presentation-security:MD1-R`
- `machineArtifact:MD1-R-markdown`

Files to create:
- `Sources/MonaCode/Markdown/MonaMarkdownAST.swift`
- `Sources/MonaCode/Markdown/MonaMarkdownParser.swift`
- `Sources/MonaCode/Markdown/MonaMarkdownPresentation.swift`
- `Sources/MonaCode/Markdown/MARKED-MIT-LICENSE.txt`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Markdown/MonaMarkdownSecurityTests.swift`

Interfaces consumed:
- `MonaURI`
- `MonaLocalization`

Interfaces produced:
- `MonaMarkdownAST`
- `MonaMarkdownParser`
- `MonaMarkdownPresentation`

Red verification:
- Run: `swift test --filter MonaMarkdownSecurityTests/testHostileHTMLAndMediaMatrix`
  - Expected exit: `1`
  - Expected output includes: `MARKDOWN_SECURITY_VIOLATION fixture=hostile-media`

Minimal implementation operations:
- `Port the pinned Marked 14 grammar subset with its MIT notice and modification record.`
- `Produce a semantic tree for native text, code, lists, tables, links, and trusted command metadata.`
- `Reject raw HTML execution, style, scripts, media loading, remote images, web layout, and untrusted command links.`
- `Keep parsed source ranges in raw UTF-16.`

Green verification:
- Run: `swift test --filter MonaMarkdownSecurityTests`
  - Expected exit: `0`
  - Expected output includes: `MARKDOWN_NATIVE hostileFixtures=blocked semanticFixtures=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T008.json`

Completion assertions:
- `Markdown semantic fixtures match MD1-R.`
- `Hostile inputs cannot load or execute content.`
- `No web sanitizer or renderer ships.`

Commit boundary:
- `Sources/MonaCode/Markdown/MonaMarkdownAST.swift`
- `Sources/MonaCode/Markdown/MonaMarkdownParser.swift`
- `Sources/MonaCode/Markdown/MonaMarkdownPresentation.swift`
- `Sources/MonaCode/Markdown/MARKED-MIT-LICENSE.txt`
- `Tests/MonaCodeTests/Markdown/MonaMarkdownSecurityTests.swift`

<!-- monacode-plan-task:{"id":"P06-T009","recordSha256":"0c7977753c98c076aafd69361b0e9ca7105f1c546b6d5f866df796bdc8602c57"} -->
## P06-T009 — Implement the macOS host byte-transport adapter outside Core

Contract: `H1-R.lspTransport`, `L2-R.transportBoundary`, `C06`

Dependencies:
- `P06-T001`
- `P04-T014`

Ownership selectors:
- `host:lsp-process-adapter`

Files to create:
- `Sources/MonaCodeAppKit/Host/MonaProcessMessageTransport.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Host/MonaProcessMessageTransportTests.swift`

Interfaces consumed:
- `MonaMessageTransport`

Interfaces produced:
- `MonaProcessMessageTransport`

Red verification:
- Run: `swift test --filter MonaProcessMessageTransportTests/testExitAndPartialWriteOrdering`
  - Expected exit: `1`
  - Expected output includes: `HOST_TRANSPORT_ORDER_MISMATCH fixture=exit-partial-write`

Minimal implementation operations:
- `Launch only an explicitly host-authorized executable with an explicit environment and working directory.`
- `Bridge standard input and output bytes to the transport-neutral Core protocol.`
- `Serialize partial writes, end-of-file, exit, cancellation, termination, and disposal without embedding framing logic.`

Green verification:
- Run: `swift test --filter MonaProcessMessageTransportTests`
  - Expected exit: `0`
  - Expected output includes: `HOST_MESSAGE_TRANSPORT byteBridge=pass lifecycle=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T009.json`

Completion assertions:
- `Host launch and file-descriptor details stay outside Core.`
- `Bytes remain unchanged.`
- `Exit and disposal emit one terminal sequence.`

Commit boundary:
- `Sources/MonaCodeAppKit/Host/MonaProcessMessageTransport.swift`
- `Tests/MonaCodeAppKitTests/Host/MonaProcessMessageTransportTests.swift`

<!-- monacode-plan-task:{"id":"P06-T010","recordSha256":"a206d1a8e3445890cac45ef4d7e2987d3df910390d3a3c674f98b2a37ce806c9"} -->
## P06-T010 — Close LSP, provider, snippet, Markdown, and plain-text fallback behavior

Contract: `L2-R`, `L2-R2`, `L2-R3`, `SN1-R`, `MD1-R`, `C06`, `P11`

Dependencies:
- `P06-T005`
- `P06-T007`
- `P06-T008`
- `P06-T009`

Ownership selectors:
- `phase-gate:06`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Phase06LanguageInfrastructureTests.swift`

Interfaces consumed:
- `MonaLSPClient`
- `MonaProviderRegistry`
- `MonaSnippetController`
- `MonaMarkdownPresentation`
- `MonaProcessMessageTransport`

Interfaces produced:
- `Phase06LanguageGate`

Red verification:
- Run: `swift test --filter Phase06LanguageInfrastructureTests/testSeededLateResponsePublication`
  - Expected exit: `1`
  - Expected output includes: `PHASE06_LANGUAGE_GATE_FAILED fixture=late-response-after-restart`

Minimal implementation operations:
- `Run transport fragmentation, framing, JSON direction, session, capability, provider, cancellation, stale, snippet, Markdown, hostile-input, and fallback matrices.`
- `Inject malformed frames, oversized frames, duplicate IDs, disconnect, restart, late response, provider reentry, and release failures.`
- `Verify product binaries contain no built-in language implementation, server, grammar pack, JavaScript runtime, or ICU runtime.`

Green verification:
- Run: `swift test --filter Phase06LanguageInfrastructureTests`
  - Expected exit: `0`
  - Expected output includes: `PHASE06_LANGUAGE_GATE C06=pass providers=30 builtinLanguages=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-06/P06-T010.json`

Completion assertions:
- `C06 prerequisites pass.`
- `All 30 provider surfaces have exact dispositions.`
- `No-provider state remains pure text.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Phase06LanguageInfrastructureTests.swift`
