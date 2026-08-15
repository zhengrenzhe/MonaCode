# Phase 1 — MonaCodeBase + MonaCodeModel

**Goal:** Implement the base value/event/URI layer (B1-R) and the raw-UTF-16 Piece Tree model with transactions, versioning, events, and snapshots (M1-R/R2), on the thin-MainActor ownership model with the single-entry EditTransaction gateway (A+/A+-base/R1), plus model-construction and large-model policy (H2-R). No undo/decoration/search yet (Phase 2).

**G4-R mapping:** base-values-events B1-R; model-regexp-unicode M1-R, M1-R2; concurrency-transactions-validity A+, A+-base, R1; runtime-lifetime-resource H2-R (model construction + large-model only; cache registry is Phase 7).

**Prerequisites:** Phase 0 (E1 clock/entropy/locale infra injectable into differential harness; comparator M0/M1 available; differential runner operational).

**Exit Gates (this phase completes):**
- **C01 (partial)** — Piece Tree, raw UTF-16, transactions, version, events, snapshot match M0/M1 on the subset of the 256-seed × 10K-trace corpus that excludes undo/decoration/search (those land in Phase 2, completing C01).
- No candidate artifact produced in Phase 1 (model is product code; manifests come with Phase 2+).
- Preflight: G4-R audit/verify-contract still pass; differential harness green on the Phase-1 subset.

---

## Task 1.1 — MonaPosition

**Dependencies:** 0.6
**Files:** Create `Sources/MonaCode/Base/MonaPosition.swift`; Test `Tests/MonaCodeTests/Base/test_MonaPosition.swift`
**Tests:** 16 declaration fixtures vs M0/M1: `with` returns same object on equal value (identity observable); `delta` floors at 1; constructor rejects negative; `validatePosition` rejects/advances inside surrogate pair; `getOffsetAt` uses Relaxed validation; `getPositionAt` returns raw offset (can land mid-pair). Zero raw-unit diff vs comparators.
**Contract:** G4-R §surfaceCounts (model 73 decl/70 members); B1-R (Position 13 unique/16 declarations); §equivalenceDomains.exact (raw UTF-16 Position).
**Produces:** —
**Exit-gate contribution:** C01 base-value fixtures.
**Steps:**
- [ ] Define `@MainActor struct MonaPosition: Equatable` with `lineNumber: Int`, `column: Int` (Int valid coordinate domain; JS number/coercion excluded per M1-R).
- [ ] Implement `with`, `delta`, `isBefore`, `isBeforeOrEqual`, `equals`, `clone`, `toString`, `validate`.
- [ ] Capture 16 differential fixtures from M0/M1; make N pass; commit.

## Task 1.2 — MonaRange / MonaSelection

**Dependencies:** 1.1
**Files:** Create `Sources/MonaCode/Base/MonaRange.swift`, `Sources/MonaCode/Base/MonaSelection.swift`; Test `Tests/MonaCodeTests/Base/test_MonaRange.swift`, `test_MonaSelection.swift`
**Tests:** Range 30 unique/43 declarations; Selection 18 own/44 total. Constructor auto-swaps reversed endpoints; `validateRange` folds/advances, non-folded expands outward on pair hit; three intersect predicates (`areIntersecting`, `areIntersectingOrTouching`, `areOnlyIntersecting`) ported per-branch (do NOT derive from names — they differ from intuition); Selection stores normalized range + anchor/active orientation; `SelectionDirection` RawRepresentable.
**Contract:** G4-R §surfaceCounts.model; B1-R (Range/Selection); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C01 base-value fixtures.
**Steps:**
- [ ] Implement `MonaRange` (value semantics; `with`-style returns new values); `MonaSelection: MonaRange` (orientation); enums `SelectionDirection`.
- [ ] Port the three intersect predicates exactly; capture fixtures; commit.

## Task 1.3 — MonaURI

**Dependencies:** 0.6
**Files:** Create `Sources/MonaCode/Base/MonaURI.swift`; Test `Tests/MonaCodeTests/Base/test_MonaURI.swift`
**Tests:** Component parser/formatter: scheme regex `^\w[\w\d+.-]*$` (strict mode accepts `1bad`); graceful percent decoder (`%F0%9F%92%A9%GG` stays fully encoded; consecutive percent run fails as a whole then recurses by 3); authority lowercased; drive letter lowercased; lone surrogate format throws `URIError`; `joinPath` uses posix; `revive` 4 overloads; 5 components + `fsPath`. **Not** `Foundation.URL` (MonaURI is a locked reference type preserving cache-observable output — calling `fsPath`/`toString` changes `toJSON` output). Raw-unit zero diff vs comparators.
**Contract:** G4-R §surfaceCounts.model; B1-R (Uri 15 unique); §explicitCuts (Foundation.URL NOT used); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C01 URI fixtures.
**Steps:**
- [ ] Implement `MonaURI` as a locked reference type with canonical components, custom percent codec, lazy cache, stateful `toJSON`.
- [ ] Capture URI component/error fixtures from M0/M1; commit.

## Task 1.4 — KeyCode / KeyMod / Token / marker enums

**Dependencies:** 1.1
**Files:** Create `Sources/MonaCode/Base/MonaKeyCode.swift`, `Sources/MonaCode/Base/MonaKeyMod.swift`, `Sources/MonaCode/Base/MonaToken.swift`, `Sources/MonaCode/Base/MonaEnums.swift`; Test `Tests/MonaCodeTests/Base/test_KeyCode.swift`
**Tests:** KeyCode 134 cases (`-1` and `0…132`); KeyMod 4 masks + chord; Token 5 unique (offset/type/language/_tokenBrand/toString, brand as Void field); MarkerTag 2, MarkerSeverity 4, SelectionDirection 2 — RawRepresentable, NOT reordered/compressed.
**Contract:** G4-R §surfaceCounts.model; B1-R (KeyCode/KeyMod/Token/enums).
**Produces:** —
**Exit-gate contribution:** C01 enum raw-value manifest.
**Steps:**
- [ ] Define enums with exact integer raw values; commit.

## Task 1.5 — MonaEmitter / MonaDisposable / MonaEvent

**Dependencies:** 1.1
**Files:** Create `Sources/MonaCode/Base/MonaEmitter.swift`, `Sources/MonaCode/Base/MonaDisposable.swift`; Test `Tests/MonaCodeTests/Base/test_MonaEmitter.swift`
**Tests:** `@MainActor MonaEmitter<T>` nonthrowing callback; internal exact delivery queue; synchronous subscription order; `remove`/`dispose` can intercept undelivered listener; callback failure does NOT truncate subsequent listeners; `dispose`-then-subscribe = empty disposable. Reentry matrix: two-listener reentry drains current event fully first; single-listener reentry nests immediately; listeners added in current round do NOT receive current event (UniqueContainer + snapshot-end delivery queue).
**Contract:** G4-R §surfaceCounts.model; B1-R (`@MainActor MonaEmitter<T>`); §equivalenceDomains.exact (event semantics); §architecture (synchronous events MainActor).
**Produces:** —
**Exit-gate contribution:** C01 event reentry trace matrix.
**Steps:**
- [ ] Implement `MonaEmitter` with UniqueContainer + snapshot-end queue; implement `MonaDisposable`; capture reentry matrix; commit.

## Task 1.6 — Cancellation

**Dependencies:** 1.5
**Files:** Create `Sources/MonaCode/Base/MonaCancellation.swift`; Test `Tests/MonaCodeTests/Base/test_Cancellation.swift`
**Tests:** Lazy token; cancel-before-token uses `Cancelled` singleton; `dispose(false)`-before-token = None; parent already cancelled → child cancels on next task; `MainTurnQueue` drains only the snapshot taken at enqueue time per turn (FIFO); disposable can revoke; first cancel fires registered listeners synchronously; post-cancel new listener uses zero-delay task.
**Contract:** G4-R §surfaceCounts.model; B1-R (cancellation); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C01 cancellation turn-order matrix.
**Steps:**
- [ ] Implement `MonaCancellationToken`, `MonaCancellationTokenSource`, `MainTurnQueue`; capture turn-order matrix; commit.

## Task 1.7 — Piece Tree core (raw UTF-16)

**Dependencies:** 1.3
**Files:** Create `Sources/MonaCode/Model/PieceTree/`, `Sources/MonaCode/Model/MonaText.swift`, `Sources/MonaCode/Model/MonaTextSlice.swift`; Test `Tests/MonaCodeTests/Model/test_PieceTree.swift`
**Tests:** Red-black Piece Tree behavior; average buffer size 65,535; append slab seal-before-publish; snapshot O(1) retain of root; edit O(log pieces + inserted units); no model lock. `MonaText`/`MonaTextSlice` hold `UInt16` (canonical raw-unit value); isolated surrogates are single units; Swift `String` is convenience-only, never canonical truth. `setValue`, `getValueInRange`, `getLineCount`, `getLineContent`, EOL handling (LF view; CRLF offset compensation).
**Contract:** G4-R §architecture.modelTruth (persistent raw-UTF-16 Piece Tree); M1-R (Piece Tree, 65535 avg buffer); M1-R2; §equivalenceDomains.exact (Piece Tree semantics).
**Produces:** —
**Exit-gate contribution:** C01 Piece Tree differential (subset).
**Steps:**
- [ ] Implement immutable published piece nodes/buffers; path-copy on edit; snapshot retains root.
- [ ] Implement `MonaText` (UInt16 storage) and `MonaTextSlice`; capture Piece Tree fixtures; commit.

## Task 1.8 — MonaCodeModel public surface (M1-R2 70 members, no undo/decoration/search)

**Dependencies:** 1.7, 1.1, 1.2, 1.3
**Files:** Create `Sources/MonaCode/Model/MonaCodeModel.swift`; Test `Tests/MonaCodeTests/Model/test_MonaCodeModelSurface.swift`
**Tests:** Implement the M1-R2 70-unique-member surface EXCLUDING undo/redo (`undo`/`redo` stubs that throw `unsupported` until Phase 2), decorations, and search (`findMatches` etc. stubbed until Phase 2). Content/snapshot (13), position/range (11) — already in base; options/edits/`applyEdits` (3 overloads, 1000-op reduction), identity/version/events/lifecycle (15). Character count is NOT grapheme count (high surrogate counts as one, skip next unit; isolated low surrogate counts as one — NOT Swift `Character.count`). `ITextSnapshot.read` → Sendable immutable snapshot with mutating reader cursor; `preserveBOM` semantics; chunk boundary is publicly observable; builder buffers trailing CR + high surrogate across chunk boundaries; EOF settles residuals.
**Contract:** G4-R §surfaceCounts.model (73 decl/70 members, 0 cuts); M1-R2 (70 native retained, 0 public cuts); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C01 model surface (subset; full 256-seed × 10K completes in Phase 2).
**Steps:**
- [ ] Implement `@MainActor final class MonaCodeModel` with the 70-member surface; stub undo/decoration/search with typed `unsupported`.
- [ ] Port `applyEdits` 1000-op reduction, EOL normalization, trailing-whitespace branches, `computeUndoStamps`; capture fixtures; commit.

## Task 1.9 — EditTransaction gateway + version/alternativeVersion (A+/R1)

**Dependencies:** 1.8, 1.5
**Files:** Create `Sources/MonaCode/Model/Transactions/EditTransaction.swift`, `Sources/MonaCode/Model/Transactions/GlobalModelEventHub.swift`, `Sources/MonaCode/Model/Transactions/PreparedModelCommit.swift`; Test `Tests/MonaCodeTests/Model/test_EditTransaction.swift`
**Tests:** 5-stage flow: EditIntent → Preflight (range normalization, EOL, overlap check, inverse edits, event draft; zero mutation) → Commit (Piece Tree + line index + undo stack + version; no external code) → Event batch (immutable payload; old-version listeners finish before reentrant events) → Invalidate. `PreparedModelCommit`: generate new roots + undo element + events, then MainActor allocation-free/callback-free/await-free root swap. Version rules NOT simplified to "+1": non-empty text batch +1; empty batch unchanged; real EOL change +1; `setValue` +1; undo/redo retain Monaco's actual increment + merge events; `alternativeVersionId` restores stack-recorded value. Failure occurs BEFORE mutation (ranges validated/clamped; touching legal; true overlap rejected; `baseVersion` only for async path). Cross-model: preflight ALL, commit ALL, events in input order, one shared undo element; any open-model version mismatch = entire batch not executed.
**Contract:** G4-R §architecture.mutation (one prepare/validate/atomic-apply/deterministic-event transaction gateway); A+ (MainActor live ownership base); A+-base (transaction base); R1 (PreparedModelCommit, GlobalModelEventHub enqueue-then-drain, cross-model event order); §equivalenceDomains.exact (transaction semantics).
**Produces:** —
**Exit-gate contribution:** C01 transaction traces; R1 gate (Phase 8 failure-injection).
**Steps:**
- [ ] Implement `EditTransaction` 5-stage; `PreparedModelCommit` root-swap; `GlobalModelEventHub` enqueue-then-drain.
- [ ] Capture transaction/validity differential fixtures (including cross-model reentry); commit.

## Task 1.10 — AsyncValidityTicket + version gate (R1)

**Dependencies:** 1.9
**Files:** Create `Sources/MonaCode/Model/Transactions/AsyncValidityTicket.swift`, `Sources/MonaCode/Model/Transactions/ReconciliationContract.swift`; Test `Tests/MonaCodeTests/Model/test_ValidityGate.swift`
**Tests:** `AsyncValidityTicket` = modelInstance + version + anchor + editor/config/provider/session epochs + request ID (NOT a single versionId). Background result passes MainActor version gate (session + URI + version + capability + owner match) before any commit; stale → release/drop. 6 ReconciliationContract types defined (Exact editor state, Edit-log replay, Continuation state machine, Bounded-change predicate, Server-authoritative push, Workspace/session scoped) — used by Phase 6 providers. Diagnostics special case: versioned push exact-match only; versionless binds to current version at receipt (Phase 6 implements the diagnostics consumer).
**Contract:** G4-R §architecture (background consumes immutable versioned snapshots; stale results pass explicit version gate); R1 (6 ReconciliationContract types; versionless diagnostics = ServerAuthoritativePush, didClose does NOT clear markers); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C01 validity traces; C06 (Phase 6) validity gate substrate.
**Steps:**
- [ ] Define `AsyncValidityTicket`, `DependencyStamp` (full-field equality: projection, fold, injected text, font, theme, viewport, scale, renderer generation — V1-R4 supplies layout fields in Phase 3; model fields now), 6 `ReconciliationContract` cases; commit.

## Task 1.11 — H2-R model construction + large-model policy

**Dependencies:** 1.8
**Files:** Create `Sources/MonaCode/Runtime/MonaModelConstruction.swift`, `Sources/MonaCode/Runtime/MonaLargeModelPolicy.swift`; Test `Tests/MonaCodeTests/Runtime/test_LargeModel.swift`
**Tests:** 3 model construction states: `implicitOwned` (model omitted → editor creates+owns, disposes on first detach/replace/dispose), `externalBorrowed` (model object → attach exact reference, never dispose), `none` (explicit null → no model, later `setModel` attaches borrowed). 3 large-model flags, all sticky (constructor-only, never recompute on edit), all strict `>`: `tooLargeForTokenization` (initialLength > 20 MiU16 OR initialLineCount > 300,000; forced false when `largeFileOptimizations=false`); `tooLargeForSyncing` (> 50 MiU16; regardless of `largeFileOptimizations`); `tooLargeForHeapOperation` (> 256 MiU16; forced false when `largeFileOptimizations=false`; `getValue`/`getLinesContent` fail; replace-all refuses). Measurement unit = UTF-16 code units (not serialized bytes). T−1/T/T+1 fixtures vs M0/M1.
**Contract:** G4-R §architecture; H2-R (3 model construction states, 3 large-model sticky flags); §surfaceCounts.runtimeState.initialModelStates=3; §acceptance.overlays.C09 (large-model gate T−1/T/T+1).
**Produces:** —
**Exit-gate contribution:** C09 large-model gate (partial; full in Phase 8).
**Steps:**
- [ ] Implement construction states + sticky flags; capture T−1/T/T+1 fixtures; commit.

## Task 1.12 — H2-R process-global + per-editor state scaffolding

**Dependencies:** 1.11
**Files:** Create `Sources/MonaCode/Runtime/MonaProcessGlobals.swift` (model-registry, editor-registry, marker-registry, theme-registry, language-registry, command-keybinding-menu-registry, opener-registry skeletons), `Sources/MonaCode/Runtime/MonaEditorState.swift`; Test `Tests/MonaCodeTests/Runtime/test_ProcessGlobals.swift`
**Tests:** 8 process-global MainActor classes + 7 per-editor classes present (skeletons; full behavior filled by later phases). Model-registry: URI-keyed; duplicate live URI fails pre-publication. Shared-model rule: multiple editors attach one model; mutation/marker fan out to all attachments; per-editor state independent (no shared selection/view). Theme last-writer-wins across all live editors (stub). Provider registration ordering: higher selector score first; equal → non-builtin before builtin, later before earlier; exclusive suppresses others (stub; full in Phase 6).
**Contract:** G4-R §surfaceCounts.runtimeState (processGlobalClasses=8, perEditorClasses=7); H2-R (ownership rules, shared-model rule, provider registration ordering).
**Produces:** —
**Exit-gate contribution:** C09 runtime-scope gate (skeleton).
**Steps:**
- [ ] Define the 8+7 state class skeletons with the ownership/registry rules; commit.

## Task 1.13 — Phase 1 integration + differential subset

**Dependencies:** 1.1–1.12
**Files:** Modify `Tests/DifferentialFixtures/model/`; Create `docs/implementation-phases/verification/phase-01-verification.md` (after verification)
**Tests:** Full Phase 1 differential subset (Piece Tree, transactions, version, events, snapshot, large-model) passes zero raw-unit diff vs M0 and M1; `swift test` green; C01 subset green. Undo/decoration/search explicitly stubbed (`unsupported`) and excluded from the Phase-1 corpus.
**Contract:** G4-R §designClosure.phaseRule; §empiricalStatus.
**Produces:** —
**Exit-gate contribution:** C01 partial; Phase 1 done when all tasks committed + three adversarial rounds pass.
**Steps:**
- [ ] Run Phase 1 suite; confirm stubs are isolated; commit; trigger per-phase adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-01-verification.md` (3 rounds, no BLOCKING):

- **Task 1.8 (M2/M4):** the 70-member surface exclusion list is explicit — **decorations** (subsumes markers + injected-text observation), **search** (subsumes `findMatches`/word-boundary `getWordAtPosition`/`getWordUntilPosition`/`findMatchingBracket`/`matchBracket`), **tokenization**, **language state** — all stubbed `unsupported`; implemented + stubbed = 70 (0 cuts). The large-model flag methods `isTooLargeForTokenization()`/`isTooLargeForSyncing()`/`isTooLargeForHeapOperation()` are among the 70 (identity/version/lifecycle group), declared as stubs returning the Task-1.11-computed flags. Member-list authority: M1-R2 `model-m1r2-public-surface-closure.html` (SHA `eaaa4ed865d56b0eabc745a38af7ab4dde8598d079e6e7788d4f0b44eebf9666`). Dependency add **1.5** (MonaEmitter). `applyEdits` 3 overloads = 3 edit-operation types (`IIdentifiedSingleEditOperation`/`ISingleEditOperation`/`IValidatedEditOperation`); the Promise-returning path → MainActor `async` (M1-R2 actor overlay, F1-R5 `retained-swift-async-adaptation`). `ITextSnapshot` is `Sendable`; `read` returns a stack-allocated `SnapshotReader` value type (mutation on the reader, not the snapshot).
- **Task 1.8 (M3):** `getValue`/`getLinesContent` consult a `tooLargeForHeapOperation` property **declared in 1.8** (default false), **computed in 1.11**.
- **Task 1.9 (M5):** undo/redo version rules are **specified in Phase 1, verified in the Phase 2 exit gate** (since `undo()`/`redo()` throw `unsupported` here). The 4 testable rules (non-empty +1, empty unchanged, EOL +1, `setValue` +1) are Phase-1-verified. Cross-model version-mismatch rule applies **only when `baseVersion` is provided (async path)**. Invalidate stage scope (Phase 1): line index / cached line starts / EOL metadata only.
- **Task 1.10 (M1):** `DependencyStamp` — `projection`/`fold`/`font`/`theme`/`viewport`/`scale`/`renderer-generation` are **Phase-3 layout fields** (optional/`nil` in Phase 1, comparing equal to `nil`); Phase 1 populates only `injectedText` + model identity fields. Phase 3 populates the layout fields without changing the type shape or equality semantics.
- **Task 1.11:** exit-gate contributes **C01 large-model thresholds** (not C09-only); C09 covers resource-implication only.
- **Task 1.12:** the 8 process-global classes are distinct: environment-services, model-registry, editor-registry, marker-registry, theme-registry, language-registry, opener-registry, and command/keybinding/menu as separate registries.
- **Task 1.13:** preflight runs `Tools/forbidden-imports.sh`.
