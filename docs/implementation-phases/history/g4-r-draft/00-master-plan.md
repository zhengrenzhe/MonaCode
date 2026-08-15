# MonaCode Full Implementation Phase Plan — Master Plan

> **For agentic workers:** This is a phase/task-level implementation plan for a frozen design contract (G4-R). It does not duplicate or alter the contract. The normative authority is `docs/contracts/monaco-editor-0.56.0/g4-r/artifacts/monacode-g4r-authoritative-manifest.json`. Every task cites its G4-R domain, machine artifact, and acceptance gate. Execution order can change; scope, cuts, native adaptations, architecture, host contracts, correctness gates, and performance thresholds cannot.

**Goal:** Implement MonaCode — a native Swift code-editor component whose retained behavior and performance do not fall below `monaco-editor@0.56.0` — for arm64 macOS, passing G4-R acceptance (C01–C10, P00–P13, cross-cutting gates) and producing the seven candidate-generated artifacts.

**Architecture:** Single raw-UTF-16 Piece Tree model truth owned by a thin MainActor core; all background work consumes immutable versioned snapshots; one EditTransaction gateway owns all live mutation; Core Text is the sole typography/hit-test authority; Core Graphics renders first with Metal conditional on a renderer-owned gate; custom `NSTextInputClient` + `NSAccessibilityElement` proxies; a repository-owned Swift ECMAScript RegExp engine + generated Unicode tables; 30 provider surfaces + frozen LSP 3.18 client with zero shipped language content; no third-party production runtime.

**Tech Stack:** Swift 6.3, SwiftPM, macOS 26.0 deployment target (qualified on macOS 26.6 build 25G72 / M4 Pro), AppKit, Core Text, Core Graphics, conditional Metal. Node.js (audited G4-R tooling + M1 comparator build via esbuild 0.25.9) is build/test-only and absent from product binaries.

**Spec:** `docs/contracts/monaco-editor-0.56.0/g4-r/README.md` → `adoption-record.json` → `artifacts/monacode-g4r-authoritative-manifest.json` (SHA-256 `f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021`).

## Global Constraints

Copied verbatim or near-verbatim from G4-R; every task implicitly includes these.

- **Deployment target:** macOS 26.0; runtime qualification only on the current arm64 machine, macOS 26.6 build 25G72.
- **Production dependencies:** Apple system frameworks, repository-owned MonaCode code, licensed generated Unicode/Chromium-ICU/localization data, and licensed Codicon assets only. **No third-party production runtime.**
- **Forbidden in production:** JavaScript engine (JSC/QuickJS/V8), ICU code/runtime (only generated immutable tables ship), `NSRegularExpression` as semantic oracle, WebView, DOMPurify production code, DOM/CSS runtime, WebWorker, WebGPU, `@vscode/diff`, WASM, TextKit/NSTextView production backend, source-map resources, `fetch`/`XMLHttpRequest`/`WebSocket`/`localStorage`.
- **Public products:** `MonaCode` (Foundation-only), `MonaCodeAppKit` (→ MonaCode), `MonaCodeSwiftUI` (→ AppKit+Core).
- **Required non-product targets:** `sample-macOS-host`, `conformance-and-failure-injection`, `benchmark-harness`.
- **Required AppKit views:** `MonaCodeEditorView`, `MonaDiffEditorView`, `MonaMultiDiffEditorView`.
- **Required SwiftUI types:** `MonaCodeEditor`, `MonaDiffEditor`, `MonaMultiDiffEditor`, `MonaSwiftUIEditorController`.
- **Host contract closure:** 7 groups, 10 concrete types — `MonaCodeEnvironment`, `MonaLinkOpener`, `MonaCodeEditorOpener`, `MonaWorkspaceEditHost`, `MonaPreparedWorkspaceTransaction`, `MonaCommandHost`, `MonaLogSink`, `MonaMessageTransport`, `MonaLSPTransportFactory`, `MonaMultiDiffDataSource`. `MonaResourceOpener` is **not** a symbol.
- **Model truth:** persistent raw-UTF-16 Piece Tree; all live model and editor APIs are MainActor synchronous.
- **Rendering:** Core Graphics first; Metal only after the locked renderer-owned performance trigger fires; both consume immutable `LineLayoutRecord` geometry.
- **Performance verdict:** every P00–P13 cell × metric × {60,120}Hz × {M0,M1} baseline passes the paired one-sided 95% bootstrap upper bound `native/comparator ≤ 1.00`.
- **Freeze rule:** phases change order only. Any scope/cut/adaptation/architecture/host/gate/threshold change requires a new global revision and adoption record.
- **Oracle:** Chrome 151.0.7922.109 / Chromium-ICU 78.2 (`icudtl.dat` SHA-256 `9f48c7f9c7c94d516a14870707e910ab94d75ae640ff6842c4af53276cd26ebe`); V8 ieee754 (`src/base/ieee754.cc` SHA-256 `998f6f44757e62a5774fca533101145942f362c8739a247c12a37caf9fbea53f`) is provenance-only, never linked.

## Repository Layout (target)

```
MonaCode/
├── Package.swift                     # 3 products + 3 non-product targets
├── Sources/
│   ├── MonaCode/                     # Foundation-only public API
│   │   ├── Base/                     # B1-R: Position/Range/Selection/Uri/KeyCode/KeyMod/Event/Cancellation
│   │   ├── Model/                    # M1-R/R2: Piece Tree, transactions, version, events, snapshot
│   │   ├── RegExp/                   # M1-R3: Swift ECMAScript engine + Unicode tables
│   │   ├── Environment/              # E1-R: locale/clock/entropy; X1-R: intrinsics/encoding/hash
│   │   ├── Undo/                     # undo/redo stacks, edit elements
│   │   ├── Decorations/              # Decoration Tree
│   │   ├── Search/                   # find/replace, word/grapheme
│   │   ├── Editor/                   # EditorCore, ViewGraph, projection, options
│   │   ├── Commands/                 # commands/actions/keybindings/menus/contributions
│   │   ├── Features/                 # 62 retained features, registry
│   │   ├── Theme/                    # T1-R: 431 colors / 776 icons / 4 themes
│   │   ├── Localization/             # N1-R: 2120 keys × 15 profiles
│   │   ├── Language/                 # L2-R: 30 provider surfaces, selector
│   │   ├── LSP/                      # L2-R2/R3: transport, framing, JSON-RPC, client
│   │   ├── Snippet/                  # SN1-R: parser, resolvers, session
│   │   ├── Markdown/                 # MD1-R: Marked 14 port, semantic tree
│   │   ├── Diff/                     # D1-R: legacy + advanced
│   │   ├── Services/                 # S1-R: 40 services, session store, dialogs
│   │   ├── Host/                     # H1-R/R2: 7 host groups, 10 concrete types
│   │   ├── Runtime/                  # H2-R: process-global/per-editor state, cache registry
│   │   └── Generated/                # licensed generated Unicode/ICU/localization tables (resources)
│   ├── MonaCodeAppKit/               # AppKit hot path
│   │   ├── Views/                    # MonaCodeEditorView/Diff/MultiDiff : NSView + NSTextInputClient
│   │   ├── Input/                    # I3-R: key gateway, keybinding, composition, pointer, scroll, menu
│   │   ├── Transfer/                 # I4-R: pasteboard, drag/drop, services
│   │   ├── Accessibility/            # A1-R/A2-R2: AX proxies, MonaAXTextArea, focus, announcements
│   │   ├── Layout/                   # V1-R3/R4: Core Text, ViewGraph, LineLayoutRecord
│   │   └── Rendering/                # V1-R4: Core Graphics renderer, conditional Metal
│   └── MonaCodeSwiftUI/              # lifecycle-only Representables
├── Tests/
│   ├── MonaCodeTests/                # unit + differential
│   ├── MonaCodeAppKitTests/
│   ├── ConformanceAndFailureInjection/   # required non-product target
│   ├── BenchmarkHarness/                 # required non-product target
│   └── DifferentialFixtures/             # golden traces vs M0/M1
├── Comparators/                      # M0 official npm + M1 esbuild build (test-only, not in product)
├── Tools/                             # candidate-manifest producers, source-closure scanner, audit
└── docs/implementation-phases/        # this plan + verification reports
```

## Phase Dependency Graph

```
Phase 0 (scaffold, comparators, harness, E1 infra, Q1 harness)
   │
   ▼
Phase 1 (MonaCodeBase B1-R + MonaCodeModel M1-R/R2/A+/R1/H2 model)
   │
   ▼
Phase 2 (Undo/Decoration/Search/RegExp M1-R3 + E1 text semantics + X1 intrinsics/encoding)
   │
   ▼
Phase 3 (EditorCore/ViewGraph/Core Text/Core Graphics V1-R3/R4)
   │
   ▼
Phase 4 (Input I3-R / Transfer I4-R / Accessibility A1-R/A2-R2)   ──┐
   │                                                                │
   ▼                                                                ▼
Phase 5 (Commands/Options/Theme T1-R/L10n N1-R/Features F1-R4/R5)   (Phase 4 gates feed Phase 5 AX/event paths)
   │
   ▼
Phase 6 (Provider/LSP L2-R / Snippet SN1-R / Markdown MD1-R)
   │
   ▼
Phase 7 (Diff D1-R / Services S1-R / Host H1-R/R2 / Resources H2-R / Source-closure X1-R)
   │
   ▼
Phase 8 (C01–C10 + P00–P13 acceptance; Metal only on gate)
   │
   ▼
Phase 9 (Distribution / License / 7 candidates / release verdict)
```

**Hard ordering rationale:** Phase 1 needs Phase 0 (harness + E1 clocks/entropy injected into both MonaCode and comparators). Phase 2 needs Phase 1 (model + base types). Phase 3 needs Phase 1–2 (model + base + RegExp for word boundary). Phase 4 needs Phase 3 (LineLayoutRecord for IME `firstRect` / AX `frameForRange` / pointer hit-test). Phase 5 needs Phase 3–4 (options affect layout; features wire input). Phase 6 needs Phase 1–2 (provider results pass R1 version gate against live model) + Phase 5 (command/option registries). Phase 7 needs Phase 6 (diff/services consume provider/LSP) + Phase 5 (host commands). Phase 8 needs all. Phase 9 needs Phase 8. **Phase 8 and Phase 9 overlap:** Phase 9 Tasks 9.1–9.3 (distribution build + license + `MonaDistributionManifest`) run concurrently with Phase 8 acceptance; the convergence point is `8.5 → 9.3 → 8.9 → 9.4` (Task 9.3 depends on 8.5 for QEnvironmentID; Task 8.9 depends on 9.3 for the distribution manifest; Task 9.4 is the final release verdict). This is execution ordering, not a scope change.

**Cross-cutting note (not a phase reorder):** E1-R (environment) and X1-R (source closure) and H2-R (runtime) are each split across phases by responsibility — environment *infrastructure* in Phase 0, *text semantics* in Phase 2; source-closure *intrinsics/encoding* in Phase 2, *full manifest* in Phase 7; H2 *model construction/large-model* in Phase 1, *cache registry* in Phase 7, *resource/soak gates* in Phase 8. This is scheduling only; each domain's full contract is honored wherever its clauses are active.

## G4-R Cross-Reference Matrix

### 42 normative layers → phase (primary owner; cross-cutting noted)

| Domain | Layer(s) | Primary phase | Cross-cutting |
|--------|----------|---------------|---------------|
| provenance | P1-R | 0 (comparators) | 9 (distribution provenance) |
| model-regexp-unicode | M1-R, M1-R2 | 1 | — |
| model-regexp-unicode | M1-R3 | 2 | — |
| environment-intl-clock-entropy | E1-R | 0 (infra: clocks/entropy/locale-separation/**Number::toString for entropy**) | 2 (case/collation/normalize occurrence classification + C02 verification), 5 (UI/runtime locale boundary) |
| source-runtime-style | X1-R | 7 (full closure) | 2 (intrinsics/encoding/StringSHA1), 3 (style→native state) |
| base-values-events | B1-R | 1 | — |
| concurrency-transactions-validity | A+, A+-base, R1 | 1 | 6 (provider validity gate), 7 (WorkspaceEdit) |
| native-input | I3-R, I3-R2, I3-R3, I3-R4 | 4 | — |
| clipboard-drag-drop-services | I4-R | 4 | — |
| layout-rendering | V1-R3, V1-R4 | 3 | 4 (LineLayoutRecord consumers), 8 (Metal) |
| language-lsp | L2-R, L2-R2, L2-R3 | 6 | — |
| feature-public-surface | F1-R, F1-R2, F1-R3 | 5 | 0 (scope/instance as comparators) |
| feature-public-surface | F1-R4, F1-R5 | 5 | — |
| snippet-engine | SN1-R | 6 | — |
| diff-engine | D1-R | 7 | — |
| theme-token-icon | T1-R | 5 | — |
| ui-localization | N1-R | 5 | — |
| markdown-presentation-security | MD1-R | 6 | — |
| standalone-services-session-feedback | S1-R | 7 | — |
| accessibility | A1-R, A1-R2, A2-R2 | 4 | — |
| native-embedding-host | H1-R, H1-R2 | 7 | 6 (LSP transport host) |
| runtime-lifetime-resource | H2-R | 1 (model construction) | 7 (cache registry), 8 (soak/resource) |
| verification | Q1-R, Q1-R2, Q1-R3, Q1-R4, Q1-R5 | 0 (harness) | 8 (acceptance), 9 (release) |

### 17 machine artifacts → phase

| Artifact | Phase |
|----------|-------|
| `monaco-0.56.0-f1r3-scope-manifest.json` | 0 (comparator), 5 (registry impl) |
| `monaco-0.56.0-f1r3-instance-surface-manifest.json` | 0 (comparator), 5 (instance impl) |
| `monaco-0.56.0-f1r4-public-declaration-manifest.json` | 5 |
| `monacode-f1r5-native-type-contract-manifest.json` | 5 |
| `monaco-0.56.0-a2r-accessibility-manifest.json` | 4 |
| `monacode-m1r3-regexp-unicode-manifest.json` | 2 |
| `monacode-e1r-environment-intl-clock-entropy-manifest.json` | 0, 2 |
| `monacode-x1r-source-runtime-style-manifest.json` | 7 (intrinsics cross-ref in 2) |
| `monacode-n1r-localization-manifest.json` | 5 |
| `monacode-md1r-markdown-contract-manifest.json` | 6 |
| `monacode-s1r-standalone-service-contract-manifest.json` | 7 |
| `monacode-sn1r-snippet-engine-manifest.json` | 6 |
| `monacode-d1r-diff-engine-manifest.json` | 7 |
| `monacode-h1r-native-boundary-manifest.json` | 7 |
| `monacode-h1r2-host-group-correction-manifest.json` | 7 |
| `monacode-h2r-runtime-resource-manifest.json` | 1, 7 |
| `monacode-q1r5-acceptance-manifest.json` | 0, 8 |

### C01–C10 correctness gates → phase (gate is *passed* in the listed phase; partial evidence may arrive earlier)

| Gate | Verifies | Pass phase |
|------|----------|------------|
| C01 | ITextModel / Piece Tree / large-model (73 decl / 70 members; 256-seed × 10K traces; 20Mi/300k-line/50Mi/256Mi thresholds) | 2 |
| C02 | ECMAScript RegExp & search (8 flags, 10 profiles, 2117 Test262; case/collation/normalize/Number::toString) | 2 |
| C03 | Projection / native geometry (Core Text oracle; V1-R4 invariants) | 3 |
| C04 | Public API / registries (555 paths 434/121; 64 features; 454 commands; 379 keybindings; symbol-graph closure) | 5 (symbol-graph/registries/l10n contribution) → 7 (full pass: + H1-R2 openers, S1-R services, SN1/MD1 paths, X1 source-closure set equality) |
| C05 | Options / Diff / MultiDiff (174 options; diff option groups; stable-ID multi-diff) | 5 (options) + 7 (diff) |
| C06 | Language / LSP 3.18 (30/25/5 surfaces; framing/JSON/session matrices; 1 client + 3 cut transports) | 6 |
| C07 | Native input / AX / transfer (ABC + 拼音 IME; VoiceOver; copy/cut/paste/drag/drop) | 4 (native-interaction core) → 7 (full pass: + N1/MD1/S1/SN1/X1 overlay clauses) |
| C08 | CG / conditional Metal renderer (CTLine goldens; CG/Metal parity ≤1/255) | 3 (CG) + 8 (Metal if triggered) |
| C09 | Embedding / lifetime / resources (3 products; 7 host groups; cache registry; fault fixtures) | 7 |
| C10 | Distribution / license provenance (3-product graph; no forbidden runtime; license notices) | 9 |

### P00–P13 performance workloads → phase (cell is *passed* in Phase 8; workload exercised earlier where noted)

| Workload | Scenario | First exercised | Pass |
|----------|----------|-----------------|------|
| P00 | cold startup (1 MiU16/100K lines) | 3 | 8 |
| P01 | model load (1 Mi & 100 Mi) | 1 | 8 |
| P02 | typing / undo (10K actions) | 3 | 8 |
| P03 | batch edits (1/100/10K) | 1 | 8 |
| P04 | vertical scroll (60 & 120 Hz) | 3 | 8 |
| P05 | long line (1M units) | 3 | 8 |
| P06 | wrap / resize | 3 | 8 |
| P07 | decorations (100K) | 2 | 8 |
| P08 | find / replace (incl. RegExp/Test262/snippet transform) | 2 | 8 |
| P09 | multicursor (incl. snippet insertion) | 4 | 8 |
| P10 | Diff / MultiDiff | 7 | 8 |
| P11 | Provider / LSP / Markdown / services | 6 | 8 |
| P12 | shared model (4 editors) | 3 | 8 |
| P13 | IME / AX query | 4 | 8 |

### 7 candidate-generated artifacts → phase (produced)

| Artifact | Producer phase | Required for gates |
|----------|---------------|-------------------|
| `MonaRegExpUnicodeManifest.json` | 2 | C02, C06, C10, P08 |
| `MonaEnvironmentManifest.json` | 0 (infra) + 2 (text semantics) | C02, C04, C05, C06, C09, C10, P08–P11 |
| `MonaNativeDeclarationManifest.json` | 5 | C04, C05, C06, C09, C10 |
| `MonaSourceClosureManifest.json` | 7 | C02, C04, C05, C07, C09, C10, P00–P13, soak |
| `MonaCacheManifest.json` | 7 | C09, C10, P00–P13, soak |
| `QEnvironmentID.json` | 0 (collector) + 8 (per-run) | C07, C10, P00–P13 |
| `MonaDistributionManifest.json` | 9 | C10 |

## Global Conventions

### Contract citation format
Every task carries a **Contract** block citing exact G4-R entries:
```
Contract: G4-R domain=<domain>; layers=<revisions>; artifact=<machine-manifest>;
  gates=<C##/P##>; manifest §<top-level-key>
```
A task that cannot cite a G4-R entry is out of scope and must not be planned (freeze rule).

### File-path convention
- Product source: `Sources/<Product>/<Domain>/<File>.swift`.
- Tests: `Tests/<Target>/<Domain>/test_<File>.swift`.
- Differential fixtures: `Tests/DifferentialFixtures/<domain>/<case>.json` (golden traces captured from M0/M1).
- Generated licensed data: `Sources/MonaCode/Generated/<domain>/<table>.swift` (Unicode-3.0 / Chromium-ICU / Monaco-MIT / Marked-MIT / Codicon notices inline).
- Candidate manifests: `Tools/<producer>.swift` → emits `<Artifact>.json` at `Build/` then checked into `artifacts/candidate/`.

### Exit-gate format
Each phase ends with an **Exit Gates** block: the C/P gates whose evidence this phase *completes* (not necessarily final-pass, which is Phase 8), the candidate artifacts produced, and the preflight checks (audit + verify-contract still pass; no new source counterexample). A phase is *done* when: (a) all its tasks committed; (b) its differential fixtures pass against M0/M1; (c) its produced candidate manifest validates against its machine artifact; (d) three independent adversarial verification rounds report no blocking finding.

### Testing strategy
- **Differential testing** is the primary correctness oracle: the same frozen input corpus + injected E1 clock/entropy/locale traces run against M0 (official Monaco), M1 (capability-matched), and N (MonaCode); zero raw-unit diff required for *exact* domains; Core-Text-self-consistency for *native-adapted* domains.
- **Unit tests** for isolated algorithms (Piece Tree, RegExp, collation, snippet parser, diff).
- **Conformance + failure injection** target for R1 rollback, H2 recoverable faults, LSP malformed frames, provider cancel/reentry.
- **Benchmark harness** for P00–P13: paired AB/BA blocks, 1,000,000-iteration bootstrap, 60/120 Hz cells, `QEnvironmentID` preflight per run.
- **TDD per task** where the unit is isolated; differential fixtures are captured first from comparators, then made to pass in N.

### Commit convention
One commit per task. Message prefix `feat(<phase-domain>):`, `test:`, `chore(phase-0):`, etc. Each commit body cites the G4-R contract entry. Branch per phase: `impl/phase-N-<slug>` off `main`.

## Per-Phase Summary

| Phase | Title | Owns (layers) | Produces (candidates) | Completes gates |
|-------|-------|---------------|----------------------|-----------------|
| 0 | Scaffold + comparators + harness | P1-R, E1-R(infra), Q1-R/R2/R3/R4, F1-R3(comparator) | QEnvironmentID (collector), MonaEnvironmentManifest (infra) | (harness only) |
| 1 | MonaCodeBase + MonaCodeModel | B1-R, M1-R, M1-R2, A+, A+-base, R1, H2-R(model) | — | C01 (partial) |
| 2 | Model semantics | M1-R3, E1-R(text), X1-R(intrinsics/encoding) | MonaRegExpUnicodeManifest, MonaEnvironmentManifest | C01, C02 (pass) |
| 3 | EditorCore + Core Text + CG | V1-R3, V1-R4 | — | C03, C08(CG partial) |
| 4 | Input + transfer + a11y | I3-R*, I4-R, A1-R/R2, A2-R2 | — | C07 core (full in Phase 7) |
| 5 | Commands + options + theme + l10n + features | F1-R/R2/R3/R4/R5, T1-R, N1-R | MonaNativeDeclarationManifest | C04 contribution (full in Phase 7), C05(options) |
| 6 | Provider + LSP + snippet + markdown | L2-R*, SN1-R, MD1-R | — | C06 (+ C04/C05 overlay contribution: SN1/MD1 paths) |
| 7 | Diff + services + host + resources + source-closure | D1-R, S1-R, H1-R/R2, H2-R(cache), X1-R(full) | MonaSourceClosureManifest, MonaCacheManifest | C05(diff), C09, C04 full, C07 full |
| 8 | Correctness + performance acceptance | Q1-R5 | QEnvironmentID (per-run) | C01–C09 + C10 evidence, P00–P13, cross-cutting |
| 9 | Distribution + license + candidates + release | P1-R(dist), Q1-R5(release) | MonaDistributionManifest | C10, release verdict |

## Verification Protocol (per the task brief)

1. **Per phase:** after a phase doc is written, three independent adversarial verifier agents (fresh context, each pointed at the phase doc + relevant G4-R artifacts) check (a) before/after dependency correctness, (b) architecture conformance, (c) artifacts, (d) phase state, (e) contract satisfaction. Findings consolidated into `verification/phase-XX-verification.md`; blocking findings trigger phase-doc revision.
2. **Whole plan:** after all phases, three independent adversarial verifier agents check (a) architecture, (b) artifacts, (c) original-requirement coverage, (d) all planned content completeness. Consolidated into `verification/whole-plan-verification.md`.
3. All documents persist to `docs/implementation-phases/` (落库).
