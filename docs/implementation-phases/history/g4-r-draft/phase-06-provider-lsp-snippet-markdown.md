# Phase 6 — Provider, LSP, Snippet, Markdown

**Goal:** Implement the 30 language provider surfaces + frozen LSP 3.18 client (L2-R*), the snippet engine (SN1-R), and the native Markdown Marked 14 port (MD1-R), with plain-text fallback for missing support. Completes **C06**.

**G4-R mapping:** language-lsp L2-R, L2-R2, L2-R3; snippet-engine SN1-R; markdown-presentation-security MD1-R.

**Prerequisites:** Phase 5 (provider execution model, microtask queue, selector, command/option registries, native types), Phase 2 (RegExp for snippet transforms + Markdown sanitizer), Phase 1 (validity gate, R1 transactions).

**Exit Gates (this phase completes):**
- **C06 (pass)** — 30 direct / 25 LSP / 5 direct-only surfaces; selector ordering, dynamic registration, resolve/release/cancel/dispose; framing/JSON/session/malformed matrices; 1 retained `MonacoLspClient`, 3 absent web transports; plain-text fallback.
- No candidate artifact (source-closure/distribution manifests are Phase 7/9).
- Preflight: audit/verify-contract pass.

---

## Task 6.1 — MonaMessageTransport (LSP byte transport)

**Dependencies:** 5.7, 1.10
**Files:** Create `Sources/MonaCode/LSP/MonaMessageTransport.swift`, `Sources/MonaCode/LSP/MonaLSPTransportFactory.swift`; Test `Tests/MonaCodeTests/LSP/test_MessageTransport.swift`
**Tests:** `MonaMessageTransport` (Sendable): state (connecting/open/closed with typed reason), single-consumer ordered byte-chunk stream, `send(bytes)` async throws with backpressure, `close` idempotent; NEVER parses frames/JSON (L2-R2/R3 codec owns bytes above this boundary). `MonaLSPTransportFactory`: ownership `ownedRestartable`/`remoteReconnectable`/`embeddedRecreatable`; `makeTransport(sessionDescriptor, epoch)`. Core depends only on `MonaMessageTransport`; `Process` is a macOS-host adapter only (not a core dependency; iOS/iPadOS does not depend on `Process`). `positionEncoding` advertises only UTF-16; positions align to Monaco model UTF-16 code units.
**Contract:** G4-R §hostContractClosure.groups (lsp-transport); §architecture.language (frozen LSP 3.18 client architecture; host supplies byte transports); L2-R (30 provider surfaces and LSP mapping base); §surfaceCounts.runtimeNamespaces.lsp (1 retained-and-extended client, 3 web-transport cuts).
**Produces:** —
**Exit-gate contribution:** C06 transport.
**Steps:**
- [ ] Implement `MonaMessageTransport` + factory; commit.

## Task 6.2 — LSP frame codec + framing (L2-R2)

**Dependencies:** 6.1, 2.8
**Files:** Create `Sources/MonaCode/LSP/MonaLSPFrameCodec.swift`, `Sources/MonaCode/LSP/MonaLSPFramingLimits.swift`; Test `Tests/MonaCodeTests/LSP/test_Framing.swift`
**Tests:** 4-layer byte→provider pipeline: `MonaMessageTransport` (ordered ByteBuffer chunks) → `LSPFrameCodec` (ASCII header, CRLFCRLF, Content-Length byte count) → `RawUTF16JSONRPC` (jsonrpc=2.0, integer|string id, batch prohibited) → Session/R1 gate. Limits: header ≤ 8 KiB; body default 64 MiB / hard cap 256 MiB (host can only lower); JSON nesting 128; pending requests 4096 (MonaCode frozen defense bounds, NOT LSP standard values). `Content-Type`: only `utf-8` charset accepted (`utf8` alias removed as baseless; media type case-insensitive; `utf-16` and others rejected). Frame failure → no JSON-RPC response, close both halves, fail all pending. Body/request failure → `ParseError` (id=null) or `InvalidRequest` then close; unknown request → `MethodNotFound` WITHOUT close.
**Contract:** G4-R §architecture.language; L2-R2 (byte transport and framing overlay); §acceptance.overlays.C06 (framing matrices).
**Produces:** —
**Exit-gate contribution:** C06 framing.
**Steps:**
- [ ] Implement the frame codec + limits + error policy; capture framing/malformed fixtures; commit.

## Task 6.3 — JSON-RPC codec + deterministic wire encoding (L2-R3)

**Dependencies:** 6.2
**Files:** Create `Sources/MonaCode/LSP/MonaRawUTF16JSONRPC.swift`, `Sources/MonaCode/LSP/MonaLSPErrorPolicy.swift`; Test `Tests/MonaCodeTests/LSP/test_JSONRPC.swift`
**Tests:** Deterministic outbound encoder: object field order `jsonrpc, id, method, params, result, error`; map keys sorted by raw UTF-16 lexicographic order; isolated surrogates encoded as `\uXXXX` lowercase; `−0` integer outputs `0`; NaN/Infinity rejected (NOT converted to null); no BOM. Request id: integer (−2³¹…2³¹−1) | string; `ResponseMessage.id` additionally allows `null` only in error responses. Role-sensitive error policy: response failure → no further response; non-null unknown id / duplicate / result+error → close; null error response fails all pending then close. Diagnostics: versioned push accepted only on exact version match; versionless binds to current model version at receipt (ServerAuthoritativePush); `didClose` does NOT clear markers (project diagnostics persist after close per LSP). LSP lifecycle: stopped→starting→initializing→ready→restarting→suspended; unexpected exit → epoch+1, cancel pending, clear session-owned transient UI + diagnostics, degrade to pure text.
**Contract:** G4-R §architecture.language; L2-R3 (wire encoding and error-direction overlay); R1 (versionless diagnostics = ServerAuthoritativePush; didClose does not clear markers); §acceptance.overlays.C06 (wire encoding and error-direction).
**Produces:** —
**Exit-gate contribution:** C06 wire/session/matrices.
**Steps:**
- [ ] Implement the JSON-RPC codec + error policy + lifecycle; capture wire fixtures; commit.

## Task 6.4 — LSP client + 25 capability mappings

**Dependencies:** 6.3, 5.7
**Files:** Create `Sources/MonaCode/LSP/MonaLSPClient.swift` (22 feature adapter classes → 25 mappings with documentColor/inlineCompletion/linkedEditingRange bridge), `Sources/MonaCode/LSP/MonaModelSession.swift`; Test `Tests/MonaCodeTests/LSP/test_LSPClient.swift`
**Tests:** 25 LSP 3.18 mappings (standard `textDocument` capabilities). `ModelSession` sends `didOpen` exactly once per URI/model/session; sync mode (none/full/incremental) follows server capability. Server restart increments epoch; all old responses invalidate. Results pass R1 gate (session + URI + version + capability + owner match) before any commit; otherwise release/drop. Diagnostics feeds the marker consumer (Phase 1 marker-registry). SemanticTokens occupies full+range.
**Contract:** G4-R §architecture.language; L2-R (30 provider surfaces and LSP mapping base); §authorityArtifacts.lsp-3.18-snapshot (commit `8b9fab8f…`, spec SHA `67e09b54…`, CC BY 4.0); §licensingProfile.lspSpecification; §surfaceCounts.languageInfrastructure (surfaces 30, lspBacked 25, directOnly 5).
**Produces:** —
**Exit-gate contribution:** C06 (25 mappings, lifecycle).
**Steps:**
- [ ] Implement the 22 adapter classes + 25 mappings + ModelSession; capture lifecycle fixtures; commit.

## Task 6.5 — 30 provider surfaces + 5 direct-only + plain-text fallback

**Dependencies:** 5.7, 6.4
**Files:** Create `Sources/MonaCode/Language/MonaLanguageFeatureRegistry.swift` (29 registries), `Sources/MonaCode/Language/MonaDirectProviders.swift` (5 direct-only: lexical Tokens, NewSymbolName, MultiDocumentHighlight, PasteEdit, DropEdit); Test `Tests/MonaCodeTests/Language/test_ProviderSurfaces.swift`
**Tests:** 30 language capability surfaces: 29 `LanguageFeatureRegistry` instances + 1 lexical-token provider factory (outside the service, in `register*Provider` functions). 5 direct-only (Swift provider, no LSP request): lexical Tokens, NewSymbolName, MultiDocumentHighlight, PasteEdit, DropEdit. Group mapping: Navigation 9/9, Editing 8/8, Presentation 8/8, Direct-only 0/5. Missing direct provider or LSP support → plain text (conditional decision: fixed trigger). `plaintext` is retained fallback metadata only, NOT a language pack. 0 shipped language content.
**Contract:** G4-R §architecture.language (all 30 provider registry surfaces + frozen LSP 3.18; zero language implementation ships; missing support is plain text); §surfaceCounts.languageContent (definitionEntriesCut 81, descriptorsTotal 91, descriptorsCut 90, plainTextFallbackMetadataRetained 1, builtinPacksCut 4, shippedLanguageImplementations 0, bundledLspServers 0); §explicitCuts (Monarch, tree-sitter, 81 defs, 4 packs, bundled LSP servers); §designClosure.conditionalDecisionsWithFixedTriggers (missing direct provider or LSP → plain text).
**Produces:** —
**Exit-gate contribution:** C06 (30/25/5 surfaces, plain-text fallback).
**Steps:**
- [ ] Implement the 29 registries + 5 direct providers + plaintext fallback; commit.

## Task 6.6 — Snippet parser + grammar (SN1-R)

**Dependencies:** 2.4, 5.7
**Files:** Create `Sources/MonaCode/Snippet/MonaSnippetParser.swift`, `Sources/MonaCode/Snippet/MonaSnippetScanner.swift`, `Sources/MonaCode/Snippet/MonaSnippetMarkers.swift`; Test `Tests/MonaCodeTests/Snippet/test_Parser.swift`
**Tests:** 11 engine classes (Scanner, Marker, Text, TransformableMarker, Placeholder, Choice, Transform, FormatString, Variable, TextmateSnippet, SnippetParser). 15 token types (ids 0–14, Dollar…EOF). Scan priority: escaped text → simple tabstop/variable → complex placeholder → complex variable → literal fallback. Grammar: simple/default, choice (`${1|one,two|}` independent comma/pipe/backslash escaping), transform (`${VAR/regex/format/options}` via M1-R3 RegExp), mirrors (first placeholder with children clones backward; nested recursion with cycle guard), final tabstop (`$0` enforced/inserted once when missing). Probe vector `${1:one}-${2|two,three|}-${TM_FILENAME/(.*)/${1:/upcase}/}-$0` with `TM_FILENAME` injected as `"mixedcase"` via the ModelBasedResolver → `one-two-MIXEDCASE-`, placeholder order `[1,2,0]`.
**Contract:** G4-R §surfaceCounts.snippetEngine (exportedClasses 11, tokenTypes 15, resolverPositions 7, formatShorthands 7, commands 4, bundledCatalogs 0); SN1-R; §equivalenceDomains.exact (snippet grammar).
**Produces:** —
**Exit-gate contribution:** C04 (snippet counts); C05 (parse tree/order/mirrors/nested); C06 (completion snippets).
**Steps:**
- [ ] Implement parser + scanner + markers; capture probe + grammar fixtures; commit.

## Task 6.7 — Snippet variables, resolvers, session (SN1-R)

**Dependencies:** 6.6, 0.5, 0.6
**Files:** Create `Sources/MonaCode/Snippet/MonaSnippetVariables.swift`, `Sources/MonaCode/Snippet/MonaSnippetResolvers.swift`, `Sources/MonaCode/Snippet/MonaSnippetSession.swift`, `Sources/MonaCode/Snippet/MonaClipboardProvider.swift`; Test `Tests/MonaCodeTests/Snippet/test_Resolvers.swift`
**Tests:** 39 known variables (16 time + 8 selection + 1 clipboard + 6 model + 3 comments + 2 workspace + 3 random). 7 format shorthands (upcase/downcase/capitalize/pascalcase/camelcase/kebabcase/snakecase). 7 resolvers first-defined-wins (ModelBased → ClipboardBased → SelectionBased → CommentBased → TimeBased → WorkspaceBased → RandomBased). 4 session commands (jumpToNextSnippetPlaceholder, jumpToPrevSnippetPlaceholder, leaveSnippet, acceptSnippet). Two unmergeable batch paths: selection-insert (per-cursor `Date`, original cursor idx retained, Clipboard/Selection/Comment per-cursor) vs snippet-edit-array (shared `Date`/Model/Time/Workspace/Random across batch; backfill boundary snapshots existing Variable nodes before each fragment). `CURSOR_INDEX`/`CURSOR_NUMBER` use original caller index (NOT range-sorted). `RANDOM`/`RANDOM_HEX`/`UUID` use E1 process-global draw sequence (depth-first parser walk order); `RANDOM`/`RANDOM_HEX` exact `Number::toString` suffix. Clipboard spread: split CRLF/LF/CR, drop falsy/whitespace, distribute only when remaining line count == cursor count.
**Contract:** G4-R §surfaceCounts.snippetEngine (knownVariables 39); SN1-R (resolver order, multi-cursor snapshots, session contract); §acceptance.overlays.C06 (completion snippets, transforms, variables); §acceptance.overlays.P09 (multicursor snippet insertion, 39-variable, clipboard spread, time-snapshot, original-index, injected random/UUID).
**Produces:** —
**Exit-gate contribution:** C06 (provider/LSP completion snippets); P09 substrate.
**Steps:**
- [ ] Implement variables + resolvers + session (both batch paths); capture variable/multicursor fixtures; commit.

## Task 6.8 — Markdown Marked 14 port + semantic tree (MD1-R)

**Dependencies:** 2.4, 5.4
**Files:** Create `Sources/MonaCode/Markdown/MonaMarkedPort.swift` (pinned Marked 14.0.0, SHA `75746ae6…`), `Sources/MonaCode/Markdown/MonaMarkdownString.swift`, `Sources/MonaCode/Markdown/MonaMarkdownSemanticTree.swift`, `Sources/MonaCode/Markdown/MonaMarkdownSanitizer.swift`; Generated `Sources/MonaCode/Generated/Markdown/`; Test `Tests/MonaCodeTests/Markdown/test_Markdown.swift`
**Tests:** `MonaMarkdownString` = value type with raw-UTF16 value, explicit trust, theme-icon bit, optional base `MonaURI`, mutable href→MonaURI map; NO `supportHtml` member (1 cut of 7 input members → 6 retained). Marked 14 Swift port: synchronous defaults (async=false, breaks=false, GFM=true, pedantic=false, silent=false, no extensions/hooks/tokenizer/walkTokens) → immutable semantic document. No JS engine/DOM/WebView/HTML-string-becomes-truth. 67 basic markup tag entries (66 unique + `<input>`), 27 allowed attribute names, 9 untrusted link schemes, `command` as trusted-additional scheme, 3 always-dropped link types, 7 media schemes. 100000 UTF-16 value cap (100001+ → 100000 + `…`). Typed sanitizer admits only typed nodes; applies link/trust/baseUri/uris rules BEFORE creating controls; never parses post-render HTML. Native projection: runs/lists/tables/quotes/tasks/code/links/safe-trusted-spans → native attributed runs + AppKit controls → Core Text geometry + A2 accessibility (same tree drives visual + AX). DOMPurify 3.4.8 oracle-only (absent from production).
**Contract:** G4-R §surfaceCounts.markdown (declarationPaths 2, inputMembersBeforeMD1 7, retainedInputMembers 6, cutInputMembers 1, consumerDeclarationFields 11, consumerSourceFiles 15); MD1-R; §architecture.markdown; §explicitCuts (supportHtml, media byte loading); §licensingProfile.marked / domPurify.
**Produces:** —
**Exit-gate contribution:** C04 (2 paths/6 members/supportHtml absent); C05 (widget semantic order); C06 (provider/LSP Markdown raw UTF-16/trust); C07 (visible text/links → native labels/roles/actions); C10 (no JS/DOM/WebView/DOMPurify, Marked MIT notice).
**Steps:**
- [ ] Port Marked 14 synchronously; implement semantic tree + sanitizer + projection; capture security fixtures (malformed/hostile links/raw HTML/encoded schemes/oversized); commit.

## Task 6.9 — Phase 6 integration + C06 differential

**Dependencies:** 6.1–6.8
**Files:** Modify `Tests/DifferentialFixtures/language/`; Create `docs/implementation-phases/verification/phase-06-verification.md` (after verification)
**Tests:** C06 full differential passes (30/25/5 surfaces; framing/JSON/session/malformed matrices; 1 client + 3 cut transports; plain-text fallback; snippet completion; Markdown provider) vs M0/M1; `swift test` green.
**Contract:** G4-R §designClosure.phaseRule; §acceptance.overlays.C06.
**Produces:** —
**Exit-gate contribution:** C06 pass; Phase 6 done when committed + three adversarial rounds pass.
**Steps:**
- [ ] Run C06 differential; commit; trigger per-phase adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-06-verification.md` (3 rounds, no BLOCKING/MAJOR):

- **Task 6.6:** the probe vector uses `TM_FILENAME` (a known model variable, one of the 6: `TM_FILENAME, TM_FILENAME_BASE, TM_DIRECTORY, TM_DIRECTORY_BASE, TM_FILEPATH, RELATIVE_FILEPATH` per SN1-R `knownVariables.groups.model`) injected as `"mixedcase"` via the ModelBasedResolver → `${TM_FILENAME/(.*)/${1:/upcase}/}` → `MIXEDCASE`. (The earlier `NAME` placeholder — not among the 39 known variables — is replaced.)
- **Task 6.7:** enumerate the 6 model variables (`TM_FILENAME, TM_FILENAME_BASE, TM_DIRECTORY, TM_DIRECTORY_BASE, TM_FILEPATH, RELATIVE_FILEPATH` per SN1-R `knownVariables.groups.model`); selection-insert per-cursor resolvers = **Clipboard/Selection/Comment/Time/Workspace/Random** (only Model shared across cursors) per SN1-R. **Clipboard-injection interface (deterministic):** create `MonaClipboardProvider` — a Foundation-only `@MainActor protocol { func clipboardString() -> MonaText? }` in `Sources/MonaCode/Snippet/MonaClipboardProvider.swift`; the snippet `ClipboardBasedVariableResolver` depends on this protocol (not AppKit). Phase 4 Task 4.7 `MonaDataTransfer` conforms to `MonaClipboardProvider` (AppKit implementation); the Foundation-only snippet engine never imports AppKit.
- **Task 6.8:** enumerate all **6 retained** `MonaMarkdownString` members (value, isTrusted, supportThemeIcons, baseUri, uris, enabledCommands). Native projection (Core Text/AppKit/A2) is **consumer-side (Phase 3/4/7)**; Phase 6 builds the semantic tree. Label the 67 markup tags / 27 attribute names as the **cut `baselineWebPolicy`** reference (absent in production due to the `supportHtml` cut), not a production allowlist. Marked-14 SHA `75746ae6…` cites the MD1-R machine artifact as source (not in `authorityArtifacts`).
- **Task 6.3:** "clear transient UI + diagnostics" on unexpected server exit is scoped to **transient session diagnostics only**, NOT `ServerAuthoritativePush` project markers (which persist). "didClose does NOT clear markers" cites **R1 `ServerAuthoritativePush`** (LSP 3.18 says clear; R1 overrides — do NOT cite "per LSP").
- **Exit-gate phrasing:** "30 total / 25 LSP-backed / 5 direct-only surfaces."
