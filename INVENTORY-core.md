# MonaCode Core Implementation Inventory

Scope: `/Users/bytedance/Documents/ChatGPT/MonaCode/Sources/MonaCode/` (Foundation-only Core target, 174 Swift files).
Audited for real-vs-stub status against monaco-editor@0.56.0. Every status judgment is backed by file:line evidence.

Status legend: **REAL** (functional logic that computes/mutates) · **PARTIAL** (real primitive but API not fully wired / degraded fallback) · **STUB** (returns nil/empty/no-op by design or deferred) · **DATA** (generated tables/registries, not logic).

---

## Quantitative Summary (REAL vs PARTIAL vs STUB by subdirectory)

| Directory | Files | REAL | PARTIAL | STUB | DATA |
|---|---|---|---|---|---|
| Base/ | 12 | 12 | 0 | 0 | 0 |
| Generated/ | 9 | 0 | 0 | 0 | 9 |
| Options/ | 3 | 3 | 0 | 0 | 0 |
| RegExp/ | 6 | 5 | 1 | 0 | 0 |
| Host/ | 4 | 4 | 0 | 0 | 0 |
| Input/ | 10 | 10 | 0 | 0 | 0 |
| Markdown/ | 3 | 3 | 0 | 0 | 0 |
| Features/ | 39 | 37 | 2 | 0 | 0 |
| LSP/ | 12 | 12 | 0 | 0 | 0 |
| Language/ | 5 | 3 | 2 | 0 | 0 |
| Runtime/ | 9 | 9 | 0 | 0 | 0 |
| Environment/ | 11 | 9 | 2 | 0 | 0 |
| Localization/ | 1 | 1 | 0 | 0 | 0 |
| Model/ (top) | 5 | 3 | 2 | 0 | 0 |
| Model/PieceTree/ | 4 | 4 | 0 | 0 | 0 |
| Model/Decorations/ | 3 | 3 | 0 | 0 | 0 |
| Model/Search/ | 4 | 3 | 1 | 0 | 0 |
| Model/Undo/ | 2 | 2 | 0 | 0 | 0 |
| Diff/ | 6 | 6 | 0 | 0 | 0 |
| Snippet/ | 6 | 6 | 0 | 0 | 0 |
| Theme/ | 4 | 4 | 0 | 0 | 0 |
| Registry/ | 6 | 6 | 0 | 0 | 0 |
| Transactions/ | 5 | 5 | 0 | 0 | 0 |
| Services/ | 4 | 2 | 0 | 2 | 0 |
| Scaffold.swift | 1 | 0 | 0 | 1 | 0 |
| **TOTAL** | **174** | **152** | **10** | **3** | **9** |

**Bottom line:** 152/174 files (87%) are REAL functional logic. 10 PARTIAL (real primitives with unwired/degraded paths — decorations query API, case converter not injected, tokenization plain-text fallback, DiffEditor diff construction deferred, literal search ASCII-only case folding). 3 STUB (Scaffold.swift placeholder, FeedbackService/SessionStore strict no-ops by contract). 9 DATA (generated tables).

Key finding: **no file is a pure registration shell**. Every Feature file has real feature-specific logic (filtering, ranking, sorting, staging, version-gating, committing through the transaction gateway, projecting, cycling, boundary scanning). The two PARTIAL features are Tokenization (plain-text fallback, no Monarch) and DiffEditor (diff construction deferred to Phase 07). All others are REAL: the language **provider** that supplies semantic data is an attachment-point protocol not wired in Core, but the feature logic itself computes, projects, and routes mutations through the gateway.

---

## 1. Text Model — Piece Tree Text Buffer (REAL)

### Model/PieceTree/MonaPieceTree.swift — REAL
Implements the self-balancing BST (AVL tree) text buffer over raw `[UInt16]` storage with insert/delete/getText/getLineContent/getOffsetAt/getPositionAt/createSnapshot.
- `insert` splits pieces and rebalances: `MonaPieceTree.swift:129-185`
- `delete` removes/trims pieces with AVL rebalance: `MonaPieceTree.swift:205-245`
- AVL rotations: `rotateLeft` `:592`, `rotateRight` `:615`, `rebalanceUp` `:637`
- offset↔position queries via accumulated line-feed metadata: `nodeAtOffset` `:360`, `findNthLineFeedGlobalOffset` `:383`, `rawPositionAt` `:463`

### Model/PieceTree/MonaPieceTreeNode.swift — REAL
AVL node with `subtreeLength`/`subtreeLineFeeds`/`height` metadata, parent/child links.

### Model/PieceTree/MonaLineStarts.swift — REAL
Computes line-feed offsets within a piece's raw `[UInt16]`.

### Model/PieceTree/MonaTextSnapshot.swift — REAL
Immutable snapshot materializing full text.

### Model/MonaCodeModel.swift — REAL (text/edits) + PARTIAL (decorations/indent)
The text model facade: 70 members over Piece Tree truth.
- **Text edits REAL**: `applyEdits` `:767`, `pushEditOperations` (undoable, pushes undo element) `:724`, `pushEOL` `:758`, `setValue` (rebuilds tree), `setEOL` `:778`.
- **Content/position queries REAL**: `getValue`, `getLineContent`, `getLineCount`, `getLineMaxColumn`, `getOffsetAt` `:356`, `getPositionAt` `:362`, `validatePosition` `:314`, `validateRange` `:338`, `getFullModelRange` `:367`.
- **Search REAL (literal only)**: `findMatches` `:398` delegates to `MonaLiteralSearch`; `isRegex`/`captureMatches` accepted but not honored `:407-409`; `.range(_)` scope not narrowed `:409`.
- **Word REAL**: `getWordAtPosition` `:545` delegates to `MonaWordClassifier` with outward scan `:506-538`; `getWordUntilPosition` `:554`.
- **Decorations PARTIAL/STUB**: `deltaDecorations` `:577` does real id generation + add/remove on the decoration store, but every query returns nil/empty — `getDecorationOptions` `:590` returns nil, `getDecorationRange` `:595` nil, `getLineDecorations` `:600` `[]`, `getLinesDecorations` `:609` `[]`, `getDecorationsInRange` `:619` `[]`, `getAllDecorations` `:628` `[]`, + 5 more `[]` `:636-661`.
- **Indentation STUB**: `detectIndentation` `:694` is a deferred no-op (options stay configured) `:695`.
- **Undo/redo REAL**: `undo()` `:793` delegates to `MonaUndoRedoStack`; `pushStackElement`/`popStackElement` `:701-710` are empty group-boundary markers (deferred).
- **Language**: `getLanguageId()` `:482` always returns `"plaintext"`.

### Model/MonaModelFactory.swift — REAL
Model construction (create from value/empty, attach/detach lifecycle).

### Model/MonaModelOptions.swift — REAL
Tab size, indent size, insert spaces, trim auto whitespace.

### Model/MonaModelEvents.swift — PARTIAL
Event types + minimal Phase-02 placeholder value types (`MonaModelDecorationOptions`, `MonaFindMatch`) — `:178` "Phase 02 placeholder value types"; `:224` "Phase 02 fills in the real decoration contract".

### Model/MonaLargeModelState.swift — REAL
Large-model state tracking (is too large for...).

### Model/Decorations/MonaDecorationTree.swift — REAL
Augmented interval tree over decoration ranges (max-end-position augmentation). A real BST-based interval tree primitive.

### Model/Decorations/MonaDecorationCollection.swift — REAL
Collection owning a `MonaDecorationTree`; exposes add/remove/clear/range-query/owner-filtered access. (Real primitive — but `MonaCodeModel`'s query methods don't wire through to it yet.)

### Model/Decorations/MonaDecoration.swift — REAL
Decoration value type.

### Model/Search/MonaLiteralSearch.swift — PARTIAL
Real literal UTF-16 needle scan (`findAll`, `findNext`, `findPrevious`). Case-insensitive matching uses `MonaCaseConverterStub` (ASCII-only A-Z→a-z) by default `:122`; the real `MonaCaseConverter` exists but is never injected `:76-84`.

### Model/Search/MonaWordClassifier.swift — REAL
UTF-16 word-character classifier (word / wordSeparator / other) — Monaco's `WordCharacterClassifier` port.

### Model/Search/MonaGraphemeSegmenter.swift — REAL
Grapheme cluster segmentation.

### Model/Search/MonaReplacePattern.swift — REAL
Replacement-pattern parser + capture-group substitution (`$1`, `${name}`).

### Model/Undo/MonaUndoRedoStack.swift — REAL
LIFO undo/redo lists; routes every replay mutation through `MonaTransactionGateway`.

### Model/Undo/MonaUndoRedoElement.swift — REAL
Immutable undo element (forward ops, reverse ops, before/after version + alt version, before/after selections).

---

## 2. Command Dispatcher MonaCommandDispatcher (REAL)

### Input/MonaCommandDispatcher.swift — REAL
Registers 9 core commands: `type`, `deleteLeft`, `deleteRight`, `cursorLeft`, `cursorRight`, `cursorUp`, `cursorDown`, `cursorEnd`, `cursorHome` `:51-59`.
- **`type`** REAL: inserts `args["text"]` at every active cursor via `inputBarrier.commit(MonaMultiCursorInputPlan(...))` `:68-74`.
- **`deleteLeft`** REAL: computes delete range (caret/selection/join-line) `:86-98`; `deleteLeftRange` pure logic `:109-127`.
- **`deleteRight`** REAL: `:139-151`; `deleteRightRange` `:163-181`.
- **`cursor*`** REAL: delegates to `caretOps.commitCaretMove` `:208-217`; v1 supports single primary cursor only — secondary selections "not yet carried" `:201`.
- All edit handlers commit through `inputBarrier` (text) or `caretOps`→`gateway` (selections), mutating the real model.

---

## 3. Multi-cursor Input Barrier + Transaction Gateway (REAL)

### Input/MonaModelInputBarrier.swift — REAL
Chokepoint for multi-cursor input batches. Captures model version at `prepare` `:136-145`; `commit` validates version, resolves overlaps, orders operations in reverse start-offset order, computes post-edit selections, publishes all-or-none in one transaction `:167-205`.

### Input/MonaMultiCursorInputPlan.swift — REAL
Multi-cursor plan value: primary + secondary edits, snippet tabstop replication, overlap resolution (`resolvingConflicts`), ordering (`orderedOperations`), resulting selections.

### Transactions/MonaTransactionGateway.swift — REAL
Single owner of mutation + version truth. `beginTransaction` captures version `:93-107`; `commit` validates version truth, validates every range, applies text batch + EOL through model, records selections + undo metadata `:117-164`; `rollback` discards prepared components (model untouched) `:171-183`; reconcile path on version divergence `:209-240`.

### Transactions/MonaEditTransaction.swift — REAL
Prepared-but-not-applied edit unit. `prepareEdits`/`prepareSelections`/`prepareUndoMetadata`/`prepareEOL` accumulate without mutating model; `commit()`/`rollback()` resolve through gateway `:177-251`.

### Transactions/MonaReconciliationOutcome.swift — REAL
Typed outcome enum (`.applied`/`.reconciled`/`.dropped`/`.rolledBack`).

### Transactions/MonaPublicationGate.swift — REAL
"Alive version" re-check before deferred computation may publish (captures model/version/owner/cancellation truth).

### Transactions/MonaAsyncValidityTicket.swift — REAL
Validity ticket carrying epoch/owner/cancellation generation for stale-response gating.

---

## 4. LSP Layer (REAL protocol stack — no I/O, never connected to a server)

The entire LSP layer is a **real protocol codec + state machine** but has **zero real I/O**. No `Process`, `URLSession`, `stdin`/`stdout`, `Pipe`, `FileHandle`, `NSTask`, or `spawn` anywhere in `LSP/`. The transport is an in-memory `MonaEmitter` byte channel. No real language server has ever been connected. The macOS host adapter (T009, outside Core in `MonaCodeAppKit`) would wire `send`/`receive` to a real byte stream.

### LSP/MonaLSPSession.swift — REAL (pure state machine)
Lifecycle state machine: `uninitialized → initializing → initialized → shuttingDown → shutdown → exited` + `error`. Epoch (restart), cancellation generation, progress tokens. No I/O, no bytes `:14-20`. Transitions `:134-199`.

### LSP/MonaMessageTransport.swift — REAL (in-memory byte channel, no real I/O)
Transport-neutral byte channel. `MonaMessageTransportImpl.send` fires `.sent(bytes)` to an in-memory emitter `:112-117`; `receive(_:)` injects bytes `:149-152`. No process/socket/file. The comment at `:35-39` explicitly states the host adapter (T009) wires `.received` to the real byte stream.

### LSP/MonaLSPClient.swift — REAL (protocol client logic)
Sends requests/notifications (encode → frame → transport), tracks pending requests by id+epoch, dispatches responses (stale-epoch drop), handles `$/progress`/`$/cancelRequest`, lifecycle (`initialize`/`sendInitialized`/`shutdown`/`sendExit`/`restart`), partial results, cancellation `:118-410`. Server-initiated requests are acknowledged minimally `:333-339`.

### LSP/MonaJSONRPCCodec.swift — REAL
Stateless JSON-RPC 2.0 codec: canonical byte encoding (fixed field order, UTF-16 lexicographic map keys), exact field-directionality decode.

### LSP/MonaLSPFrameDecoder.swift — REAL
Streaming Content-Length frame decoder: buffers partial headers/bodies across byte chunks, exact N-body validation, typed terminal errors.

### LSP/MonaLSPFrameEncoder.swift — REAL
Frame encoder: emits `Content-Length: N\r\n\r\n` + body bytes.

### LSP/MonaJSONRPCMessage.swift — REAL
Typed JSON-RPC 2.0 message tree (request/notification/response/error).

### LSP/MonaJSONValue.swift — REAL
JSON value tree (object/array/string/number/bool/null) with canonical serialization.

### LSP/MonaJSONRPCError.swift — REAL
L2-R3 typed error taxonomy.

### LSP/MonaLSPCapabilityRegistry.swift — REAL
25 LSP-backed provider surface → method-name mappings + capability availability (all 25 start `.unavailable`).

### LSP/MonaLSPProviderAdapters.swift — REAL (publication-side adapters)
Per-surface adapter that publishes provider results through `MonaProviderExecutor`, validating tickets. `publish`/`resolvePartial`/`release` are real publication logic `:177-240`. 25-adapter registry `:284-307`. **But**: these are publication-side only — they take already-computed results and funnel them through the executor. No result is ever fetched from a real server.

### LSP/MonaTransportEvent.swift — REAL
Event value enum (`.received`/`.sent`/`.closed`/`.errored`).

---

## 5. Tokenization (PARTIAL — plain-text fallback, no Monarch)

### Features/MonaTokenizationFeature.swift — PARTIAL
The tokenization feature. `tokenize(line:languageId:)` consumes an attached `directTokenProvider` when present; when none is attached (the default), returns the plain-text token — one `MonaToken` per line (offset 0, type `""`, language `"plaintext"`) `:163-175`.
- `isPlainTextDegraded` returns `true` `:271` — "the Foundation-only Core carries no language tokenizers until Phase 06" `:269-271`.
- `directTokenProvider` is `nil` by default `:125` — attachment point, no built-in tokenizer registered.
- **No Monarch implementation exists anywhere in the codebase** (grep for `monarch`/`MonarchTokenizer`/`registerTokenizer`/`TMGrammar` finds nothing).
- **No basic-languages registered**: `MonaLanguageRegistry` records every built-in language as `cutBuiltinLanguageContent` (not live) `:50`; only `plaintext` (`coreFallbackMetadata`) is live `:44`.
- `confirmReadOnly` commits an empty (vacuous) transaction `:204-208` — tokenization performs no model mutation.

### Language/MonaPlainTextLanguage.swift — PARTIAL
The plain-text fallback language. Bundles no grammar, no `TokenizerConfig` `:64`. `languageId = "plaintext"`.

### Language/MonaLanguageRegistry.swift — REAL (registry) / PARTIAL (no live languages)
Real registry with frozen identity inventory. Only `plaintext` is live; all other built-in language descriptors are CUT (`cutBuiltinLanguageContent`, no grammar, no provider) `:50`. Host may register its own metadata.

### Language/MonaProviderRegistry.swift — REAL (registry) / PARTIAL (no providers)
30 provider attachment points (25 LSP-backed + 5 direct-only), all starting `.unavailable`/unattached `:12-37`. `bundledLanguageServer` and `bundledLanguageImplementation` are both `nil` `:35-37`.

### Language/MonaDirectProviderAdapters.swift — REAL
Direct-only provider adapter (publication through executor, attachment lifecycle).

### Language/MonaProviderExecutor.swift — REAL
Deterministic executor: serializes provider-result publication on `MonaMicrotaskQueue` (FIFO), validates tickets immediately before publication, owns deferred-value resolvers.

---

## 6. Language Service Features (REAL feature-logic; providers are attachment points)

Every Features/ file follows the same three-operation contract: (1) feature-specific behavior, (2) register frozen identity + declared commands/actions/contributions, (3) route mutation/publication/disposal/localization through shared gateways. The feature logic is REAL; the language **provider** that supplies data is an attachment point (protocol) not wired in Core. Marked PARTIAL where the provider attachment is the only gap; REAL where the feature computes/projection is self-contained.

### Features/MonaSuggestFeature.swift — REAL
Trigger/filter/rank/resolve/accept/release/remember. `trigger` calls `provider.provideCompletions` + retains by version `:354-368`; `filter` case-insensitive contains `:381-388`; `rank` by sortText `:393-398`; `accept` commits insert text through gateway `:414-422`. Provider is `MonaSuggestProvider` attachment (Phase 06/07) `:192-203`.

### Features/MonaParameterHintsFeature.swift — REAL
`triggerParameterHints`/`cycleNextHint`/`cyclePreviousHint`/`updateActiveHint`/`dismissParameterHints`/`commitParameterEdit` (routes edit through gateway) `:236-345`.

### Features/MonaRenameFeature.swift — REAL
`prepareRename`/`collectWorkspaceEdit`/`previewRename`/`applyRename`/`acceptRenameInput`/`cancelRenameInput`/`publishRename` `:218-352`.

### Features/MonaCodeActionFeature.swift — REAL
`provideCodeActions`/`resolveCodeAction`/`applyCodeAction` (commits through gateway) `:231-294`. `MonaCodeActionKind.isSubkind` real hierarchy `:57`.

### Features/MonaFormatFeature.swift — REAL
`formatDocument`/`formatRange`/`formatOnType` — real acceptance logic: sort by start, reject overlapping batch `:207-222`; `applyFormatEdits` commits through gateway `:229`.

### Features/MonaFindFeature.swift — REAL
`findMatches` real literal + RegExp search (reuses `MonaLiteralSearch`/`MonaRegExpParser`/`MonaRegExpExecutor`), scope + whole-word filtering `:249-273`; `replaceNext`/`replaceAll` with capture-group substitution via `MonaReplacePattern`, commits through gateway `:281-339`.

### Features/MonaFoldingFeature.swift — REAL
`combineRanges` real precedence composition (manual > base > marker), strategy selection (auto/indentation), overlap dropping, sort `:239-284`; `collapse`/`expand`/`toggleFold` manage folded state `:305-335`; `commitFoldToggle` through gateway `:369`.

### Features/MonaInlayHintsFeature.swift — REAL
`requestInlayHints`/`resolveInlayHint`/`layoutInlayHints`/`releaseInlayHints`/`commitInlayHintEdits` (through gateway) `:182-259`.

### Features/MonaSemanticTokensFeature.swift — REAL
`applyFull` version-gated `:239-253`; `applyDelta` version + resultId gated, applies edits to retained data (real delta merge) `:263-284`; `reset` `:288`; `applyEdits` static `:389`.

### Features/MonaDocumentSymbolsFeature.swift — REAL
`requestDocumentSymbols`/`releaseDocumentSymbols`/`invokeDocumentSymbol`; `sortDocumentSymbols` real stable ordering (range start, then name) `:302-316`; `publishDocumentSymbols` through executor `:324-336`.

### Features/MonaCodelensFeature.swift — REAL
`renderCodeLenses` (retains by version) `:175-185`; `resolveCodeLens` `:199-203`; `invokeCodeLens` commits command edits through gateway `:211-214`.

### Features/MonaTokenizationFeature.swift — PARTIAL (see §5)

### Features/MonaInspectTokensFeature.swift — REAL
Inspects token/scope/foreground/background at a position (read-only). `inspect(at:model:theme:)` finds the word, resolves its scope (`""` under plain-text fallback since no tokenizer is registered) to `MonaTokenTheme.rule(for:)`. No model mutation (read-only — vacuous mutation path is correct behavior) `:287-289`.

### Features/MonaUnicodeHighlighterFeature.swift — REAL
Detects invisible/ambiguous/non-basic-ASCII Unicode spans. `detectHighlights` scans scalars with classification precedence (invisible->ambiguous->nonBasicASCII), respects `allowedCharacters` `:209`. Read-only (no model mutation).

### Features/MonaWordHighlighterFeature.swift — REAL
Combines textual (literal whole-word case-sensitive scan across document) + provider document highlights (read-only). `textualHighlights` does real whole-word scan `:209`; `combine` merges with provider authoritative on shared range kind `:257`.

### Features/MonaDiffEditorFeature.swift — PARTIAL
Registers the diff-editor command slice per instance + `diffEditor.revert` mutation routing `:181`/`:205`. But **diff construction itself is explicitly deferred to the Phase 07 adapter** `:176-177`. No diff computation in Core.

### Remaining Features (REAL feature-logic; provider attachment point):
- **MonaCaretOperationsFeature.swift** — REAL: `computeCaretMove` implements all 12 target cases with clamping `:334`; `moveByCharacter` wraps across line boundaries `:389`; `commitCaretMove` routes through gateway `:245`. Wrapped-line degrades to plain line (`isPlainTextDegraded = true` `:329`).
- **MonaCodeEditorFeature.swift** — REAL (thin host): `createEditor` attaches model + fires `.created` `:140`; `commitEdit` routes through gateway `:171`; lifecycle `activate`/`dispose`.
- **MonaBracketMatchingFeature.swift** — REAL: `highlightBracketPairs` flattens text + stack-based matching (nested/cross-line) `:174`; `commitSelectToBracket` routes selection through gateway `:201`.
- **MonaCommentFeature.swift** — REAL: `toggleLineComment` computes per-line edit ops `:262`; `addLineComment` inserts token on uncommented non-blank lines `:280`; `removeLineComment` strips; all commit through gateway.
- **MonaCursorUndoFeature.swift** — REAL: `recordCursorState` pushes onto undo stack + clears redo `:156`; `cursorUndo`/`cursorRedo` pop/restore. Real LIFO stack management.
- **MonaGotoLineFeature.swift** — REAL: `parse` splits on `:`/`,` `:143`; `validate` delegates to `MonaPosition.validateOrNil` `:169`; `reveal`/`commitReveal` route through gateway.
- **MonaGotoSymbolFeature.swift** — REAL: `filterSymbols` preserves provider order (case-insensitive substring) `:172`; `setSymbols`/`navigate` manage index; `commitNavigate` routes through gateway.
- **MonaIndentationFeature.swift** — REAL: `detectIndentation` scans leading whitespace per line (tab-led vs space-led majority + modal tab size) `:207`; `convertToSpaces`/`convertToTabs` `:258`/`:283`; `commitReindent` routes through gateway `:407`.
- **MonaInlineCompletionsFeature.swift** — REAL: `requestInlineCompletion` retains per model version `:212`; `accept` commits insert text through gateway. Provider is attachment point (no built-in completion engine in Core).
- **MonaInPlaceReplaceFeature.swift** — REAL: `candidates(for:)` returns n+/-1 / true<->false `:~225`; `candidate(base:step:)` cycles `:248`; `replace` anchors + steps, commits through gateway `:273`. Real cycling logic.
- **MonaInsertFinalNewLineFeature.swift** — REAL: `endsWithLineTerminator` checks last scalar `:121`; `insertFinalNewLine` inserts model's declared EOL through gateway `:132`/`:154`.
- **MonaLineSelectionFeature.swift** — REAL: `wholeLineRange` handles final-line edge `:139`; `extendWholeLineRange` spans inclusive `:159`; `applyReplacement` routes through gateway `:180`.
- **MonaLinesOperationsFeature.swift** — REAL: `sortLines` sorts ascending/descending + reassembles with terminator handling `:587`; copy/cut/paste/delete/duplicate/transpose operations commit through gateway `:548`/`:639`.
- **MonaLinkedEditingFeature.swift** — REAL: `startLinkedEditing` asks provider for ranges (attachment point) `:201`; `mirrorEdit` applies same text to all session ranges as one batch through gateway `:227`. Real mirror-edit logic.
- **MonaLongLinesHelperFeature.swift** — REAL: `readLongLinesOptions` reads options `:194`; `enforceLongLines` flags lines exceeding threshold `:222`; `setExplicitUnlimited` overrides `:208`.
- **MonaMulticursorFeature.swift** — REAL: `addCursor` inserts sorted with merge `:196`; `removeCursor` `:212`; cursors kept in stable ascending order.
- **MonaReferenceSearchFeature.swift** — REAL: `groupReferences` groups by URI preserving order `:233`; `openReferences` retains + arms cancellation `:253`; `navigateNext`/`navigatePrevious` wrap; `cancelReferenceSearch` cancels token `:309`.
- **MonaSmartSelectFeature.swift** — REAL: `beginSession` `:218`; `expandedRange` returns parent `:239`; `retainOrientation` preserves orientation `:248`; `expandSelection`/`shrinkSelection` push/pop history + commit through gateway `:266`.
- **MonaSnippetFeature.swift** — REAL: `insertSnippet` expands through engine + commits + parses tabstops `:267`; `moveToNextTabstop` `:322`/`moveToPreviousTabstop` navigate; `leaveSnippet`. Engine is attachment point (plain-text fallback: single final tabstop).
- **MonaUnusualLineTerminatorsFeature.swift** — REAL: `detectUnusualLineTerminators` scans for U+2028/U+2029/U+0085 `:164`; `removeUnusualLineTerminators` commits replacements through gateway `:204`/`:254`.
- **MonaWordOperationsFeature.swift** — REAL: `runEndRight`/`runEndLeft` scan word-class runs; `deleteWordRight`/`deleteInsideWord` commit through gateway `:~300`/`:336`.
- **MonaWordPartOperationsFeature.swift** — REAL: `moveWordPartLeft`/`moveWordPartRight` scan camelCase/snake_case part boundaries via `partStartLeft`/`partStartRight` `:~224`/`:244`; `deleteWordPartLeft` commits through gateway `:296`.
- **MonaAnchorSelectFeature.swift** — REAL: `extendSelections` zips anchors+cursors deriving orientation `:136`; `setSelectionAnchor` `:158`/`cancelSelectionAnchor` manage anchor state.

Note: `MonaHoverFeature.swift` does **not exist**. Hover is one of the 25 LSP-backed provider surfaces (`MonaLSPProviderSurface`), handled via the provider registry + LSP provider adapters, not a standalone Feature file.

---

## 7. RegExp Engine (REAL)

### RegExp/MonaRegExpParser.swift — REAL
Recursive-descent ECMAScript RegExp parser. Full grammar: escapes, character classes, quantifiers (greedy/lazy), groups (capturing/non-capturing/named), named captures + `\k<name>`, assertions (`^`/`$`/`\b`/lookahead/lookbehind), all 8 flags `gimsuydv` `:6-19`.

### RegExp/MonaRegExpCompiler.swift — REAL
AST → bytecode compiler. Emits opcodes (match-char, split, jump, save, assert...). Placeholder split/jump offsets patched after emit `:137`/`:141`/`:180`/`:205` (these are compile-time patching, not runtime stubs).

### RegExp/MonaRegExpExecutor.swift — REAL (PARTIAL case-insensitive)
Backtracking VM with explicit stack + step limit. Runs compiled program over raw `[UInt16]`. Capture groups, named captures, `lastIndex` semantics, zero-length progression, finite execution (`stepLimitExceeded`/`stackOverflow`) `:18-28`. **Case-insensitive uses `MonaCaseConverterStub` (ASCII-only) by default** `:145` — the real Unicode `MonaCaseConverter` is never injected.

### RegExp/MonaRegExpProgram.swift — REAL
Compiled program bytecode (opcodes + constants).

### RegExp/MonaRegExpAST.swift — REAL
RegExp AST node tree. Flags `d` (indices) and `v` (unicode sets) are "accepted, not yet runtime" `:62`/`:65` — parser accepts them, executor doesn't implement them.

### RegExp/MonaRegExpConsumerProfile.swift — REAL
Consumer profile (sticky/global flags, lastIndex semantics).

---

## 8. Markdown Parser (REAL)

### Markdown/MonaMarkdownParser.swift — REAL
Recursive-descent port of pinned Marked 14.0.0 synchronous GFM default grammar subset over raw `[UInt16]` (1602 lines). Sanitizer integrated at tree-build (raw HTML captured + rejected, image src discarded, untrusted command links dropped, `data:`/`javascript:` schemes dropped). Value cap 100000 UTF-16 units `:58-61`. Produces immutable `MonaMarkdownDocument` — never emits HTML, never touches DOM/WebView, never fetches.

### Markdown/MonaMarkdownAST.swift — REAL
Typed semantic tree (headings, paragraphs, lists, code blocks, links, images, raw HTML nodes, command links, theme icons).

### Markdown/MonaMarkdownPresentation.swift — REAL
Presentation projection over the AST (inline rendering, icon-id placeholder glyph for AppKit layer) `:311`.

---

## Other Directories

### Base/ (12 files) — all REAL
Value types + primitives: `MonaPosition`, `MonaRange`, `MonaSelection`, `MonaToken`, `MonaURI`, `MonaKeyCode`/`MonaKeyMod`/`MonaMarker`, `MonaCancellation` (tokens + sources), `MonaDisposable` (idempotent disposal), `MonaEmitter`/`MonaEvent` (deterministic events).

### Generated/ (9 files) — DATA
Generated tables/registries (not logic): `MonaBuiltinOptions.swift` (174 options), `MonaBuiltinKeybindings.swift`, `MonaBuiltinMenus.swift`, `MonaCodiconMap.swift` (glyph map; TTF binary NOT created — deferred to AppKit), `MonaLocalizationProfiles.swift` (15 profiles, 2120 messages), `MonaPublicAPI.swift` (declaration graph), `MonaCaseTables.swift` + `MonaCollationTables.swift` + `RegExp/MonaRegExpUnicodeTables.swift` (Unicode data tables).

### Options/ (3 files) — REAL
`MonaEditorOption` (174 option definitions), `MonaOptionSnapshot`, `MonaOptionStore` (computed option truth).

### Host/ (4 files) — REAL
Host-contract protocols (7 groups, 10 types): `MonaHostContracts`, `MonaOpenerRegistry` (LIFO opener stacks), `MonaWorkspaceEdit` + `MonaPreparedWorkspaceTransaction` (4-outcome transaction). Foundation-only protocols; macOS concrete adapters live in `MonaCodeAppKit`. No implicit URL/file/network authority.

### Input/ (10 files) — all REAL
`MonaCommandDispatcher`, `MonaModelInputBarrier`, `MonaMultiCursorInputPlan`, `MonaKeybindingResolver`, `MonaKeybinding`, `MonaKeyEvent`, `MonaKeyDispatchOutcome`, `MonaChordState`, `MonaEventControl`, `MonaPublicInputEvents`.

### Runtime/ (9 files) — all REAL
`MonaStringSHA1` (pure-Swift FIPS 180-4 SHA-1 over UTF-16→UTF-8 stream), `MonaTextCodec` (UTF-8 encode/decode), `MonaBinary64` (ECMAScript Number semantics), `MonaFiniteIntrinsics` (closed 12-category intrinsic gate), `MonaMicrotaskQueue` (FIFO deterministic publication queue), `MonaEditorLifetime`/`MonaGlobalLifetime`/`MonaInitialModelRegistry` (ownership scopes), `MonaCacheRegistry` (bounded cache manifest).

### Environment/ (11 files) — REAL + 2 PARTIAL
- REAL: `MonaClock`/`MonaWallClock`/`MonaHighResolutionClock` (separate clock domains), `MonaCodeEnvironment`/`MonaRuntimeLocale` (immutable profile vs runtime locale), `MonaRandomDoubleSource`/`MonaCryptoRandomSource`/`MonaNumberToString`.
- PARTIAL: `MonaCaseConverter` (real Unicode converter backed by `MonaCaseTables`, but **never wired** — `MonaLiteralSearch`/`MonaRegExpExecutor` still use `MonaCaseConverterStub`); `MonaCollator` (real but locale-sensitive collation only used where injected).

### Localization/ (1 file) — REAL
`MonaLocalization` — `{N}` placeholder format rule, 15 profiles, 2120 messages. No Foundation locale lookup, no network.

### Theme/ (4 files) — REAL
`MonaColorRegistry` (color entries; arithmetic deferred to native rendering layer `:564`/`:95`), `MonaThemeRegistry`, `MonaTokenTheme`, `MonaIconRegistry`.

### Registry/ (6 files) — REAL
`MonaCommandRegistry`, `MonaActionRegistry`, `MonaContributionRegistry`, `MonaFeatureRegistry`, `MonaMenuRegistry`, `MonaContextKey` — frozen identity inventories + runtime registration.

### Diff/ (6 files) — REAL
`MonaDiffEngine` (protocol), `MonaAdvancedDiffEngine` (DP/Myers line diff + character refinement), `MonaLegacyDiffEngine`, `MonaDiffCoordinator` (T-1/T/T+1 timeout, max-11 cache, max-file-size no-op), `MonaDiffResult`, `MonaDiffCache`.

### Snippet/ (6 files) — REAL
`MonaSnippetParser` (recursive-descent over raw `[UInt16]`), `MonaSnippetAST`, `MonaSnippetVariableResolver` (39 resolvers), `MonaSnippetSession` (placeholder navigation, nested sessions, merge), `MonaSnippetController` (inserts through input barrier, multi-cursor ordering), `MonaSnippetTransform`.

### Services/ (4 files) — 2 REAL + 2 STUB (by contract)
- REAL: `MonaServiceCollection` (40-service collection).
- STUB (by S1-R contract): `MonaFeedbackService` — severity-tagged log events for info/warn/error; **strict no-ops** for prompt/status/telemetry/accessibility signals `:8-9`/`:33-35`/`:160-168`; `MonaSessionStore` — declares absent capabilities (persistence, telemetry transport, notification UI, signal audio, webWorker) `:51-77`; deferred-save timers are in-memory only.

### Scaffold.swift — STUB
One-line placeholder `// MonaCode scaffold`.
