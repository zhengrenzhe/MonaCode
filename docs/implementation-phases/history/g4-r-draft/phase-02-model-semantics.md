# Phase 2 — Model Semantics: Undo/Decoration/Search/RegExp/Unicode

**Goal:** Complete the model's behavioral semantics: undo/redo, Decoration Tree, search (find/replace, word/grapheme), the repository-owned Swift ECMAScript RegExp engine + generated Unicode tables (M1-R3), E1 text semantics (case/collation/normalization/`Number::toString`), and X1 finite intrinsic profiles + encoding/hashing (StringSHA1, TextDecoder, StringBuilder). This phase **completes C01 and C02**.

**G4-R mapping:** model-regexp-unicode M1-R3; environment-intl-clock-entropy E1-R (text semantics); source-runtime-style X1-R (intrinsics/encoding/hashing subset; full source closure is Phase 7); model M1-R/R2 (undo/decoration/search clauses).

**Prerequisites:** Phase 1 (Piece Tree, transactions, version, events, snapshot, base types, validity gate).

**Exit Gates (this phase completes):**
- **C01 (pass)** — full 256-seed × 10K edit/EOL/undo/decoration/search traces + large-model thresholds, zero raw-unit diff vs M0/M1.
- **C02 (pass)** — RegExp + search + 9 language/provider profiles + 8 flags + numeric lastIndex + raw UTF-16 + 2117 Test262 dispositions + E1 case/collation/normalize/Number::toString/clock/entropy vs Chrome 151.
- Candidate artifacts produced: `MonaRegExpUnicodeManifest.json`, `MonaEnvironmentManifest.json` (completed).
- Preflight: both candidate manifests validate against their machine artifacts (`monacode-m1r3-regexp-unicode-manifest.json`, `monacode-e1r-environment-intl-clock-entropy-manifest.json`); audit/verify-contract pass.

---

## Task 2.1 — Undo/Redo stack + edit elements

**Dependencies:** 1.9
**Files:** Create `Sources/MonaCode/Undo/MonaUndoStack.swift`, `Sources/MonaCode/Undo/EditStackElement.swift`, `Sources/MonaCode/Model/Transactions/WorkspaceUndoGroup.swift`; Test `Tests/MonaCodeTests/Undo/test_UndoRedo.swift`
**Tests:** Undo saves inverse edit elements (NOT old roots — root retention would keep deleted large text alive). `undo()`/`redo()` are `@MainActor async` (void|Promise → MainActor async per M1-R2): single-resource element without prepare/confirm commits before first suspension; workspace awaits confirm/prepare, re-validates stack identity + validity, then commits. Errors → internal notification + stack policy (NOT increased Swift throws surface). EOL/`setValue`/undo/redo each have own increment + `alternativeVersion` restore rules (NOT abstracted into one "transaction number"). `WorkspaceUndoGroupID` tracks cross-model undo.
**Contract:** G4-R §surfaceCounts.model; M1-R (undo/events/version transaction boundary); M1-R2 (void|Promise → MainActor async); R1 (workspace batch enqueues ALL then drains; listener fault does NOT roll back committed text; re-entry appends to batch tail); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C01 undo traces.
**Steps:**
- [ ] Implement `EditStackElement` (inverse edits, not root snapshots), `MonaUndoStack`, `WorkspaceUndoGroup`.
- [ ] Replace Phase-1 `undo`/`redo` stubs; capture undo differential fixtures; commit.

## Task 2.2 — Decoration Tree

**Dependencies:** 1.9, 1.2
**Files:** Create `Sources/MonaCode/Decorations/MonaDecorationTree.swift`, `Sources/MonaCode/Decorations/MonaDecorationOptions.swift`; Test `Tests/MonaCodeTests/Decorations/test_DecorationTree.swift`
**Tests:** Decoration ranges use Relaxed validation path. Interval-tree queries preserve Monaco asymptotic upper bounds (operation-count complexity gate, not wall-time). `deltaDecorations`, `getDecorationsInRange`, `getLineDecorations`, sticky behavior, `IModelDecorationOptions` (12 members). Decoration updates participate in the transaction event draft (Phase 1 gateway) without re-shaping model truth.
**Contract:** G4-R §surfaceCounts.model (Decorations 12); M1-R (Decorations surface); §acceptance.crossCutting (operation counters prove Monaco asymptotic upper bounds); §architecture (Decoration Tree is MainActor synchronous core).
**Produces:** —
**Exit-gate contribution:** C01 decoration traces; P07 decoration workload (100K) substrate.
**Steps:**
- [ ] Implement the decoration interval tree with Relaxed-range validation; wire into transaction event draft; capture fixtures; commit.

## Task 2.3 — Word / grapheme / search base

**Dependencies:** 1.7, 1.2
**Files:** Create `Sources/MonaCode/Search/MonaWordBoundary.swift`, `Sources/MonaCode/Search/MonaGraphemeIterator.swift`, `Sources/MonaCode/Search/MonaSearchService.swift`; Test `Tests/MonaCodeTests/Search/test_Search.swift`
**Tests:** Default `wordSeparators` classifier + `GraphemeIterator` (locale-dependent word path is an F1-R explicit cut — default wordSeparators only). LF view; CRLF offset compensation; default result limit 999; zero-length match advances by next code point; whole-word uses Monaco wordSeparators classifier (NOT regex `\b`). Search runtime: fixed `g+u`; `matchCase=false` adds `i`; multiline detected → adds `m`. `findMatches` 2 typed overloads (M1-R2). Word-definition regex clone-failure is observable (dropping `v` then recompiling can throw `SyntaxError` — NOT hidden).
**Contract:** G4-R §surfaceCounts.model (Search/word/language 6); M1-R (search runtime rules); §explicitCuts (locale-dependent word path cut); §equivalenceDomains.exact (search semantics).
**Produces:** —
**Exit-gate contribution:** C01 search traces; C02 search (partial; RegExp engine in 2.4 completes it); P08 substrate.
**Steps:**
- [ ] Implement word/grapheme classifiers and search service (delegates RegExp to 2.4); capture non-RegExp search fixtures; commit.

## Task 2.4 — Swift ECMAScript RegExp engine: parser + compiler

**Dependencies:** 1.6
**Files:** Create `Sources/MonaCode/RegExp/RegexpParser.swift`, `Sources/MonaCode/RegExp/RegexpCompiler.swift`, `Sources/MonaCode/RegExp/RegexpExecutor.swift`, `Sources/MonaCode/RegExp/MonaRegExp.swift`; Test `Tests/MonaCodeTests/RegExp/test_ParserCompiler.swift`
**Tests:** 8 flags `d/g/i/m/s/u/v/y` (canonical order `dgimsuvy`; `u+v` together = `SyntaxError`). Parser/compiler/executor directly consume UInt16 (no JS engine, no NSRegularExpression oracle). `@MainActor public final class MonaRegExp`: reference identity retained by language profiles/provider results; NOT Sendable; canonical source/flags + observable numeric `lastIndex` (IEEE-754 binary64). Compiled pattern cache key = source + actual `g/u/i/m` flags. No RegExp subclass/species, no Proxy/accessor interception, no `Symbol.match/replace/species` hooks, no object/string/BigInt/Symbol `lastIndex` coercion. Cuts remove JS metaprogramming; they do NOT remove any pattern syntax, flag, or standard numeric matching state.
**Contract:** G4-R §architecture.regexpUnicode (repository-owned Swift ECMAScript engine; no JS engine/ICU/NSRegularExpression oracle); M1-R3 (8 flags, no metaprogramming cuts); §explicitCuts (JS engine, NSRegularExpression oracle); §equivalenceDomains.exact (RegExp consumers).
**Produces:** —
**Exit-gate contribution:** C02 (parser/compiler); P08 compile cases.
**Steps:**
- [ ] Implement parser → compiler → executor over UInt16; implement `MonaRegExp`; commit.

## Task 2.5 — RegExp Unicode tables (6 non-mergeable profiles)

**Dependencies:** 2.4
**Files:** Create `Sources/MonaCode/Generated/Unicode/` (RegExp=Unicode 17.0, Grapheme=14.0, RTL=14.0, EmojiFuzzy=14.0, Ambiguous=Monaco JSON snapshot, Invisible=Monaco JSON snapshot), `Tools/gen_unicode_tables.swift`; Test `Tests/MonaCodeTests/RegExp/test_UnicodeProfiles.swift`
**Tests:** Six independent Unicode profiles — versions MUST NOT merge: RegExp=Unicode 17.0.0 (V8 15.1 commit `20ad8d0` + ICU 78.2 `d578f2e8`; verified via Chrome accepting Beria_Erfe/Sidetic/Tai_Yo/Tolong_Siki `v` property escapes); Grapheme=Unicode 14.0 (table SHA `34054fdb`); RTL=14.0 (pattern SHA `421cfe79`); EmojiFuzzy=14.0 (SHA `91a00c2b`); Ambiguous=Monaco JSON snapshot (UTS #39 16 + overrides, inner SHA `a41c9ed2`; upstream vscode-unicode-data has NO license — forbidden as build input); Invisible=Monaco JSON snapshot (inner SHA `98e6a24a`; regeneration PROHIBITED). Each table carries Unicode-3.0 notice.
**Contract:** G4-R §architecture.regexpUnicode; M1-R3 (6 Unicode profiles); §licensingProfile.unicodeTables (Unicode-3.0), §licensingProfile.vscodeUnicodeData (unlicensed repo forbidden as build input); §authorityArtifacts (V8/ICU commits).
**Produces:** `MonaRegExpUnicodeManifest.json` ( RegExp exporter + Unicode-table scanner + Test262 vector classifier).
**Exit-gate contribution:** C02 (Unicode profiles); C06 (RegExp-valued language fields); C10 (license notices, no vscode-unicode-data code).
**Steps:**
- [ ] Generate the 6 profile tables from pinned inputs; emit `MonaRegExpUnicodeManifest.json`; cross-validate against `monacode-m1r3-regexp-unicode-manifest.json`; commit.

## Task 2.6 — RegExp 10 consumer profiles + Test262

**Dependencies:** 2.4, 2.5, 2.3
**Files:** Create `Sources/MonaCode/RegExp/ConsumerProfiles.swift`; Test `Tests/MonaCodeTests/RegExp/test_ConsumerProfiles.swift`, `Tests/DifferentialFixtures/regexp/test262/`
**Tests:** 10 consumer profiles each with exact clone/reset/exec/test/match rules: search (fixed g+u), word-definition (non-g cloned to g+i/m/u, drops d/s/v/y; g reused), indentation (reused; reset only if global; sticky carries lastIndex), on-enter (reused; unconditional reset=0 before test), fold-equal-flags (compile combined `(start)|(end)`), fold-unequal-flags (reuse both; reset each; skip end after start match), fold-all-regions (new RegExp(existing) clone; no per-line reset; g/y carry state across strings), section-headers (String.match per line), linked-editing (provider-priority; `match[0].length` must equal full reference length), inline-accept-next-word (drop g, keep rest; temp clone from 0). 2117 Test262 sources (1879 RegExp + 238 literal) each with a disposition; zero raw-unit diff vs Chrome 151.
**Contract:** G4-R §surfaceCounts.regexpUnicode (publicReferences 14, retained 11, cut 3, consumerProfiles 10, unicodeProfiles 6, flags 8, test262Sources 2117); M1-R3; §acceptance.overlays.C02; §acceptance.overlays.C06.
**Produces:** — (manifest produced in 2.5).
**Exit-gate contribution:** C02 (full pass); C06; P08 (all compile + consumer + Test262 cases).
**Steps:**
- [ ] Implement the 10 profiles with exact clone/reset semantics; classify 2117 Test262 sources; capture Chrome-151 differential; commit.

## Task 2.7 — E1 case conversion + collation + normalization

**Dependencies:** 0.6, 2.5
**Files:** Create `Sources/MonaCode/Environment/TextSemantics/MonaCaseConversion.swift`, `Sources/MonaCode/Environment/TextSemantics/MonaCollator.swift`, `Sources/MonaCode/Environment/TextSemantics/MonaNormalization.swift`; Test `Tests/MonaCodeTests/Environment/test_TextSemantics.swift`
**Tests:** Default `toUpperCase`/`toLowerCase` via repository Swift algorithms over pinned Unicode 17 / Chrome 151 data; raw UTF-16 preserved; isolated surrogates copied unchanged. Locale case uses `MonaRuntimeLocale` + generated Chromium-ICU data; Foundation case output is NOT an oracle. 4 Collator profiles (`file-name-base-numeric` raw-tie-break, `file-name-numeric`, `file-name-accent-numeric`, `sort-lines-default` stable) + 11 `localeCompare` sites. Normalization: NFD only; fast path U+0000–U+0080; only U+0300–036F stripped; `tryNormalizeToBase` accepts deaccented value only when raw UTF-16 length unchanged; two 10000-capacity LRU caches (NFD + base); NFC cache baseline-inert (absent). 7 line-action families + 7 snippet format families each port their own pinned source algorithm (equal names do not authorize sharing).
**Contract:** G4-R §architecture.environmentIntl; E1-R (default/locale case, 4 collation profiles, NFD/base normalization, two 10000 LRUs); §acceptance.overlays.C02; §explicitCuts (ICU code/runtime; Foundation semantic substitution).
**Produces:** `MonaEnvironmentManifest.json` text-semantics rows (completes the manifest started in Phase 0).
**Exit-gate contribution:** C02 (case/collation/normalize); C05 (line transforms); P08/P11 (collation/sort stability).
**Steps:**
- [ ] Generate Chromium-ICU case/collation tables from pinned `icudtl.dat`; implement the 3 text-semantics modules + 2 LRUs; emit manifest rows; commit.

## Task 2.8 — X1 finite intrinsic profiles + encoding/hashing

**Dependencies:** 1.7, 0.5
**Files:** Create `Sources/MonaCode/Environment/Intrinsics/MonaIntrinsicProfiles.swift`, `Sources/MonaCode/Environment/Encoding/MonaTextDecoder.swift`, `Sources/MonaCode/Environment/Encoding/MonaStringSHA1.swift`, `Sources/MonaCode/Environment/Encoding/MonaStringBuilder.swift`; Test `Tests/MonaCodeTests/Environment/test_EncodingHashing.swift`
**Tests:** Finite intrinsic profiles (Math 1099, Object 638, Reflect 618, Array 250, Map 230, Promise 192, Set 176, String 131, Number 107, RegExp 74, JSON 73, Symbol 39 refs) preserve Chrome binary64 results, control-flow decisions, enumeration order (ECMA array-index-then-insertion; replacement keeps position; delete+reinsert moves), Map/Set insertion order + SameValueZero + mutation-during-iteration. `StringSHA1` for ModelService: UTF-16→UTF-8 stream including high surrogate split across update calls; lowercase 40-hex; no WebCrypto. Chrome vectors: empty=`da39a3ee…0709`, D800=`9bdb7727…4024`, 💩=`82ab1e5b…5cbd`, reversed pair=`8750ec9d…`, FEFF 0041=`3a61e1eb…`; split-surrogate-across-updates == whole-pair hash. TextDecoder UTF-16: D800→FFFD, DC00→FFFD, D83D DCA9→pair, DCA9 D83D→FFFD FFFD, FEFF→empty, FFFE→preserved; `decodeUTF16LE` leading BOM branch. StringBuilder UTF-16LE on arm64 macOS.
**Contract:** G4-R §architecture.sourceRuntimeStyle (finite retained ECMAScript intrinsic operations; no general JS runtime); X1-R (intrinsic profiles, encoding, StringSHA1, StringBuilder); §authorityArtifacts (V8 ieee754 SHA `998f6f44…`); §equivalenceDomains.exact.
**Produces:** `MonaEnvironmentManifest.json` encoding/intrinsic rows; cross-reference to `MonaSourceClosureManifest.json` (full in Phase 7).
**Exit-gate contribution:** C02 (binary64/decoder/StringSHA1 vectors); C04 (intrinsic profile closure substrate); P08.
**Steps:**
- [ ] Implement the finite intrinsic profiles (binary64 over UInt16/Double, not Darwin libm); implement StringSHA1, TextDecoder, StringBuilder; capture Chrome vectors; commit.

## Task 2.9 — Candidate-manifest validation + Phase 2 acceptance

**Dependencies:** 2.5, 2.6, 2.7, 2.8
**Files:** Create `Tools/validate_candidate_manifest.mjs`; Create `docs/implementation-phases/verification/phase-02-verification.md` (after verification)
**Tests:** `MonaRegExpUnicodeManifest.json` validates set-equality against `monacode-m1r3-regexp-unicode-manifest.json` (14/11/3 refs, 10 profiles, 6 Unicode profiles, 8 flags, 2117 Test262 dispositions); `MonaEnvironmentManifest.json` set-equal to E1-sensitive occurrences (clocks, entropy, locale, case, collation, normalize, Number::toString) with pinned source hashes + fixtures. C01 + C02 full differential passes vs M0 and M1.
**Contract:** G4-R §implementationOutputRules (publicSwiftSpelling, environmentEffects, sourceClosure); §candidateGeneratedArtifacts (MonaRegExpUnicodeManifest, MonaEnvironmentManifest); §acceptance.overlays.C02/C04/C06/C10/P08.
**Produces:** both candidate manifests (status: present).
**Exit-gate contribution:** C01 pass, C02 pass; Phase 2 done when manifests validate + three adversarial rounds pass.
**Steps:**
- [ ] Implement the validator; run C01/C02 differential; commit; trigger per-phase adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-02-verification.md` (3 rounds, no BLOCKING):

- **Task 2.3 (M2):** search time-budget wired to the Phase-0 E1 **wall clock** (`MonaWallClock`, `Date.now` semantics, CLOCK_REALTIME); 150 ms budget checked at the outer-loop top (sampled before loop + at top of every iteration); a single regex exec MAY exceed 150 ms; no step counter/deadline inside synchronous `exec`/`test`/`match`/`replace`. Add step: wire search time-budget to `MonaWallClock`. Task 2.3 also owns the wrap-break character classifier (wordSeparators, NOT regex `\b`) consumed by Phase 3 simple-wrap.
- **Task 2.4 (M4):** compiled-pattern cache is **scoped to the `createRegExp` search path** (4-flag key: source + actual `g/u/i/m`, matching Monaco). The general `MonaRegExp` constructor cache key is source + all compilation-affecting flags (`i/m/s/u/v`) so same-source different-`s`/`v` patterns do not collide. Cache has a high-water bound per §implementationOutputRules.cacheBounds (registered in `MonaCacheManifest`, Phase 7).
- **Task 2.7 (M1):** **5 collation profiles** = 4 Collator constructions (`file-name-base-numeric` raw-tie-break, `file-name-numeric`, `file-name-accent-numeric`, `sort-lines-default` stable) + 1 localeCompare profile (`string-locale-compare-default`); plus the 11 `localeCompare` call sites. (Matches E1-R C05 "four Collator constructions, eleven localeCompare call sites" and `collationProfiles=5`.)
- **Task 2.7 (M3):** `tryNormalizeToBase` = NFD → strip only U+0300–036F → accept deaccented value **only when raw UTF-16 length unchanged** → **then apply locale-insensitive lowercase** (e.g. "Café"→"cafe"). Locale scope: **all Chrome 151 locales, NOT reduced to zh-CN**.
- **Task 2.7/2.8:** `Number::toString` explicitly named in Tests (C02 traceability).
- **Task 2.8:** per-intrinsic reference counts cite X1-R `intrinsicOperationProfiles.selectedReferenceCounts` (Math 1099/Object 638/Reflect 618/Array 250/Map 230/Promise 192/Set 176/String 131/Number 107/RegExp 74/JSON 73/Symbol 39 — subset of the 7523 aggregate). Note all **3 active** decoder profiles (StringBuilder UTF-16LE; decodeUTF16LE with leading-BOM branch; rich-edit bracket code-unit reversal + platform UTF-16 decoder) + **1 inert** textEncoder for `MonaEnvironmentManifest` classification. Add `decodeUTF16LELeadingBOM` vectors (`[FEFF,0041]→[FEFF,0041]` preserved; first-unit U+FEFF/U+FFFE bypasses decoding). Downstream framing corrected: RegExp enables **Phase 6** (C06's 11 RegExp-valued language fields + SN1 transform), not Phase 5.
- **Task 2.9:** `MonaEnvironmentManifest` set-equality validated against `monacode-e1r-environment-intl-clock-entropy-manifest.json` (SHA `ecc1e42b7061baf4ade5bd3fd5e3c1c2ee89d46f96b3aafc4c94dba5edb78dc9`); enumerate all E1 occurrence categories with counts (timers 94, microtask 11, StopWatch 21=13+6+2, input-latency 25, default/locale case 138+16, localeCompare 11, normalize 1, Math.random 8, Date.now 90, new Date 14).
- **Task 2.6:** gloss — 10 consumer profiles = 1 search + 9 language/provider.
