# Phase 0 — Scaffold, Comparators, Harness, Environment Infrastructure

> **Revision 2** — incorporates all fixes from the three-round adversarial verification (`verification/phase-00-verification.md`).

**Goal:** Stand up the SwiftPM package (3 products + 3 non-product targets), the fixed Monaco 0.56 comparators (M0 official + M1 capability-matched), the differential test framework, the performance benchmark harness, the `QEnvironmentID` preflight collector, and the E1 environment infrastructure (injectable clocks/entropy/locale separation) that every later phase depends on.

**G4-R mapping:** P1-R (provenance/comparators), E1-R (environment infrastructure: locale separation, two clock domains, entropy sources, `Number::toString` for entropy), Q1-R/R2/R3/R4 (measurement harness, dual baseline, statistical method, environment/font/cold rules), F1-R3 (scope/instance manifests used as comparators).

**Prerequisites:** None (entry phase). Repo is clean; `node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs` passes.

**Exit Gates (this phase completes):**
- No C/P gate is *passed* in Phase 0 (no editor behavior yet), but the **harness infrastructure** for every later gate is operational: differential framework captures M0/M1 golden traces; benchmark harness runs paired AB/BA blocks with the full Q1-R3 bootstrap; `QEnvironmentID.json` collects per-run privacy-filtered environment; E1 clock/entropy/locale injection drives both N and comparators.
- Candidate artifacts produced: `QEnvironmentID.json` (collector tooling), `MonaEnvironmentManifest.json` (infrastructure skeleton — occurrence classification completed in Phase 2).
- Preflight: G4-R audit + verify-contract still pass (the frozen manifest is **not** mutated); `Tools/` does not touch product sources.

**Implementation-state note (per verification B1):** The G4-R `empiricalStatus.productSourceFiles=0` is a frozen design-baseline field, never mutated during implementation. Phase 0 adds 9 E1 infrastructure product source files in `Sources/MonaCode/Environment/` (MonaClock, MonaHighResolutionClock, MonaWallClock, MonaRandomDoubleSource, MonaCryptoRandomSource, MonaNumberToString, MonaRuntimeLocale, MonaCodeEnvironment, MonaEnvironmentManifestBuilder); these are tracked in the E1-R manifest's `nativeEnvironmentSourceFiles`, not in the G4-R `productSourceFiles` counter. No C/P gate is passed.

---

## Task 0.1 — SwiftPM package skeleton + test scaffolding

**Dependencies:** —
**Files:**
- Create: `Package.swift`
- Create: `Sources/MonaCode/.gitkeep`, `Sources/MonaCodeAppKit/.gitkeep`, `Sources/MonaCodeSwiftUI/.gitkeep`
- Create: `Sources/MonaCode/Generated/.gitkeep`, `Sources/MonaCode/Generated/LICENSE.md` (template: Unicode-3.0 / Chromium-ICU / Monaco-MIT / Marked-MIT / Test262 BSD sections)
- Create: `Sources/sample-macOS-host/main.swift` (stub: `print("MonaCode sample host — Phase 4 wires editor view")`; does NOT import `MonaCodeSwiftUI` yet)
- Create: `Tests/MonaCodeTests/.gitkeep`, `Tests/MonaCodeAppKitTests/.gitkeep`, `Tests/ConformanceAndFailureInjection/FailureInjection.swift` (`FailureInjector` protocol + `ConformanceTestCase` base + fault enumeration: rolledBack/malformed/cancelled/reentrant/resourceDenied), `Tests/BenchmarkHarness/.gitkeep`
- Create: `Tests/DifferentialFixtures/.gitkeep` (resource directory, not a target)

**Tests:** `swift build` succeeds (including the `sample-macOS-host` stub); `swift test` runs zero tests and exits 0; `MonaCodeTests` + `MonaCodeAppKitTests` + `ConformanceAndFailureInjection` + `BenchmarkHarness` are declared `.testTarget`s and compile.

**Contract:** G4-R §deliveryScope (publicProducts=[MonaCode,MonaCodeAppKit,MonaCodeSwiftUI]; requiredNonProductTargets=[sample-macOS-host, conformance-and-failure-injection, benchmark-harness]); §validationScope.packageDeploymentTarget=macOS 26.0; §architecture.dependencies="no third-party production runtime"; §licensingProfile (notice scaffolding).

**Produces:** —
**Exit-gate contribution:** package graph compiles; product/non-product target set matches G4-R §deliveryScope; failure-injection skeleton present for Phases 1+.

**Steps:**
- [ ] Author `Package.swift`: three library products (`MonaCode`, `MonaCodeAppKit`, `MonaCodeSwiftUI`); targets `MonaCode` (Foundation only), `MonaCodeAppKit` (depends `MonaCode`, links AppKit/CoreText/CoreGraphics), `MonaCodeSwiftUI` (depends `MonaCodeAppKit`); test targets `MonaCodeTests` (depends `MonaCode`), `MonaCodeAppKitTests` (depends `MonaCodeAppKit`), `ConformanceAndFailureInjection`, `BenchmarkHarness`; executable `sample-macOS-host` (NO `MonaCodeSwiftUI` dependency until Phase 4). Deployment target `macOS 26.0`; Swift mode `.v6`. `DifferentialFixtures` is a `.copy("Fixtures")` resource on `MonaCodeTests`, not a target.
- [ ] Create the `Generated/` directory + `LICENSE.md` template + `FailureInjection.swift` skeleton + `sample-macOS-host/main.swift` stub.
- [ ] Run `swift build` and `swift test`; commit.

## Task 0.1b — Forbidden-import CI grep gate

**Dependencies:** 0.1
**Files:** Create `Tools/forbidden-imports.sh`
**Tests:** The gate scans all `Sources/MonaCode/**/*.swift` and fails on any match of: `import AppKit`, `import SwiftUI`, `import UIKit`, `import Metal`, `import CoreText`, `import CoreGraphics`, `NSRegularExpression`, `Foundation.ICU`, `JavaScriptCore`, `WebKit`. A seeded violating file is detected; a clean tree passes. (Phase 9 hardens via `swift package dump-package`.)

**Contract:** G4-R §architecture.dependencies; §explicitCuts.platformAndCompatibility (forbidden: JS engine, ICU code/runtime, NSRegularExpression oracle, WebView, DOM/CSS runtime, TextKit); §baselineInertPaths.
**Produces:** —
**Exit-gate contribution:** guards the Foundation-only `MonaCode` product across Phases 1–8.
**Steps:**
- [ ] Implement the grep gate; add a seeded-detection test; wire into Task 0.10 preflight; commit.

## Task 0.2 — Provenance: pin Monaco 0.56 comparators

**Dependencies:** 0.1
**Files:**
- Create: `Comparators/M0/` (official `monaco-editor@0.56.0` min bundle), `Comparators/M0/SHA256SUMS`
- Create: `Comparators/M1/` (capability-matched esbuild build), `Comparators/M1/build.mjs`, `Comparators/M1/lock.json`
- Create: `Tools/provenance.mjs`

**Tests:** `node Tools/provenance.mjs` verifies `monaco-editor` tar SHA-256 `b74bc4437205c194b779b0f21e5e7fcd3b4e9acbf3f7c8732a545d2059fb7412`, `monaco-editor-core` tar SHA-256 `78e222c77e7ef6402ea0bfb20e02caad7b63156f5d2798bc3c398a8bb396f4ed`, `monaco.d.ts` SHA-256 `fbbab04ba04224a04b2bc3243e536d1af6e26d14eb00fe8b3177bf3daef8d3f2`. M1: the candidate **self-pins** the full lock SHA-256 (reproducible from esbuild 0.25.9 + the Q1-R2 cut spec) and verifies prefix `166a192d` + suffix `efe9b` against the Q1-R2 HTML artifact — G4-R publishes only the truncated form; no full M1 hash exists in a JSON machine artifact, and the audit does not verify M1 hash.

**Contract:** G4-R §authorityArtifacts (monaco-editor-npm, monaco-editor-core-final-npm, monaco-public-dts, monaco-source-tag commit `13f0c872dcf352815cc28d92dfff496c9839ea5c`); P1-R 5-tier authority order; Q1-R2 M0/M1 baseline definitions; §licensingProfile (esbuild 0.25.9 MIT, absent from product).

**Produces:** M0 + M1 comparator artifacts (test-only, never linked into product).
**Exit-gate contribution:** both comparators reproducibly present and hash-verified; M1 build script cuts exactly WebGPU debug + 81 language definitions + 4 language feature packs (Q1-R2 M1 definition).

**Steps:**
- [ ] Vendor `monaco-editor@0.56.0` npm tarball into `Comparators/M0/`; record every file SHA-256.
- [ ] Write `Comparators/M1/build.mjs` (esbuild 0.25.9; 62 macOS features; cut WebGPU debug + 81 defs + 4 packs); self-pin full lock SHA-256; verify prefix/suffix against Q1-R2 HTML.
- [ ] Write `Tools/provenance.mjs`; commit.

## Task 0.3 — F1-R3 scope/instance comparators + Chrome probe harness

**Dependencies:** 0.2
**Files:** Create `Comparators/probe/scopeProbe.mjs`, `Comparators/probe/instanceSurface.mjs`; Create `Tests/DifferentialFixtures/registries/.gitkeep`
**Tests:** `node Comparators/probe/scopeProbe.mjs` reproduces `monaco-0.56.0-f1r3-scope-manifest.json` counts (64 features, 167 actions, 454 commands, 379 keybindings, 18 menus/121 items, 174 options, 431 colors, 776 icons, 4 themes, 91 language descriptors); `node Comparators/probe/instanceSurface.mjs` reproduces instance counts (IEditor 43/40, ICodeEditor 137/130, IStandaloneCodeEditor 141/133, IDiffEditor 60/52, IStandaloneDiffEditor 65/55). Any reproduction failure is a blocking diff (the probe must match the machine manifest exactly).
**Contract:** G4-R machineArtifacts F1-R3-scope (`31d79fd334a6e461e6ee03726a08a40e6f0f9978cbabe04d6096fcca1a79c1d5`), F1-R3-instance (`1163834f91fbf3f3ecaeb334e16160be25c7703ee6295b2bc82aad96d3c1ab5e`), F1-R4-public (`b6cb6c73add7739821f1daafa12efc520561d6f7aaeafd841209394dbe990a34`); §surfaceCounts.
**Produces:** registry probe tooling (Phase 5 oracle for C04).
**Exit-gate contribution:** comparator registry counts reproducibly match the F1-R3 machine manifests.
**Steps:**
- [ ] Implement the Chrome 151 registry probe (blank 98 CSS served as JS); dump counts + full registry arrays.
- [ ] Implement the `monaco.d.ts` instance-surface parser (TypeScript 5.9.3); emit declaration/unique counts per interface.
- [ ] Diff probe output against the G4-R machine manifests (zero diff required); commit.

## Task 0.4 — E1 environment infrastructure: clock domains

**Dependencies:** 0.1
**Files:** Create `Sources/MonaCode/Environment/MonaClock.swift`, `MonaHighResolutionClock.swift`, `MonaWallClock.swift`; Test `Tests/MonaCodeTests/Environment/test_MonaClock.swift`
**Tests:** (a) wall clock returns Unix-epoch integer milliseconds and observes injected jumps (CLOCK_REALTIME semantics, matches `Date.now`); (b) high-resolution clock uses `mach_absolute_time` × Mach timebase (monotonic while awake, never substitutes for wall); (c) the two domains never interchange; (d) conformance injects an exact binary64 trace and replays identically into N and comparators.
**Contract:** G4-R §architecture.environmentIntl; E1-R; X1-R clockAndPerformanceCorrection (21 StopWatch sites: 13 high-res, 6 wall, 2 cut); artifact `monacode-e1r-environment-intl-clock-entropy-manifest.json` (`ecc1e42b7061baf4ade5bd3fd5e3c1c2ee89d46f96b3aafc4c94dba5edb78dc9`); §authorityArtifacts chrome-m0-m1-runtime timeSourceSha256 `0015cb2fa5ee082bb61f07e24c150d161b08a7148143914d43c58f4850c68134`.
**Produces:** clock rows in `MonaEnvironmentManifest.json` skeleton (occurrence classification completed Phase 2; validated against the E1-R artifact).
**Exit-gate contribution:** C02/C04/C09 clock-domain evidence infrastructure. (The 21 StopWatch sites + 25 input-latency Performance-API calls are source occurrences pinned to X1-R `clockAndPerformanceCorrection.inputLatencyPerformanceCalls` (total 25 = 8 mark + 4 measure + 1 getEntriesByName + 8 clearMarks + 4 clearMeasures) + E1-R `inputLatencyPerformanceApi`; classified in Phase 2; the recorder built in Phase 3 Task 3.6 — not produced here.)
**Steps:**
- [ ] Define `MonaClock` protocol (`wallNow() -> Int64`, `highResNow() -> MonaHighResolutionTime`).
- [ ] Implement `MonaHighResolutionClock` (`mach_absolute_time` + `mach_timebase_info`; verify monotonicity while awake) and `MonaWallClock` (production `clock_gettime` CLOCK_REALTIME; conformance fixed trace).
- [ ] Write trace-injection tests; commit.

## Task 0.5 — E1 entropy sources (incl. Number::toString)

**Dependencies:** 0.1
**Files:** Create `Sources/MonaCode/Environment/MonaRandomDoubleSource.swift`, `MonaCryptoRandomSource.swift`, `MonaNumberToString.swift`; Test `Tests/MonaCodeTests/Environment/test_Entropy.swift`
**Tests:** Vectors: `RANDOM`/`RANDOM_HEX` double `0.123456789`→`456789`, `0.5`→RANDOM_HEX `0.8`, `0.9999999999999999`→`999999`, `0.00000123456789`→RANDOM_HEX `15e19b` (exact ECMA-262 `Number::toString` radix 10/16, last 6 UTF-16 units); UUID v4 canonical lowercase `8-4-4-4-12` with forced variant bits; active draws share one process sequence (quickSelect pivot → snippet RANDOM → suggest telemetry).
**Contract:** G4-R §architecture.environmentIntl; E1-R entropy; §acceptance.overlays.C02 (RANDOM_HEX `0.5`→`0.8`); SN1-R (draw order = depth-first parser walk); audit `environment-random-vectors`. `Number::toString` is built here (entropy infrastructure); occurrence classification + C02 verification in Phase 2.
**Produces:** entropy rows in `MonaEnvironmentManifest.json`.
**Exit-gate contribution:** C02 entropy traces; P09 multicursor random/UUID traces.
**Steps:**
- [ ] Implement ECMA-262 `Number::toString(radix:)` (10/16) matching Chrome 151 binary64 (no Darwin libm/Swift `String` oracle).
- [ ] Implement `MonaRandomDoubleSource` + `MonaCryptoRandomSource` + shared process-global draw-sequence registry (MainActor); write the four pinned vectors; commit.

## Task 0.6 — E1 locale separation + runtime-locale snapshot

**Dependencies:** 0.1
**Files:** Create `Sources/MonaCode/Environment/MonaRuntimeLocale.swift`, `MonaCodeEnvironment.swift` (localization-profile selection skeleton; full N1 logic in Phase 5); Test `Tests/MonaCodeTests/Environment/test_LocaleSeparation.swift`
**Tests:** UI profile (N1, default `en`, never auto-reads system locale) and `MonaRuntimeLocale` (process-start snapshot; current machine `zh-CN`/`gregory`/`latn`/`Asia/Shanghai`) are separate immutable values; unsupported profile IDs typed-rejected; a running process never mutates the profile; runtime locale never silently changes the N1 UI profile.
**Contract:** G4-R §architecture.environmentIntl; §hostContractClosure.environmentLocalization / runtimeLocaleBoundary; §currentLocalEnvironment; artifact `monacode-e1r-environment-intl-clock-entropy-manifest.json`.
**Produces:** environment-locale rows in `MonaEnvironmentManifest.json`.
**Exit-gate contribution:** C02 locale/clock/entropy traces; C07 localized AX/announcements (Phase 4/5).
**Steps:**
- [ ] Define `MonaRuntimeLocale` (locale, calendar, numberingSystem, timeZone) immutable snapshot; production reads `Locale.current`/`TimeZone.current` once; conformance injects `zh-CN`/`gregory`/`latn`/`Asia/Shanghai`.
- [ ] Define `MonaCodeEnvironment` skeleton with `initialize(overrides:)` (once; later calls `alreadyInitialized`); commit.

## Task 0.7 — Differential test framework (harness infrastructure; N-side deferred to Phase 1)

**Dependencies:** 0.2, 0.3, 0.4, 0.5, 0.6
**Files:** Create `Tools/differential/runner.mjs`, `Sources/MonaCode/Environment/MonaEnvironmentManifestBuilder.swift` (skeleton), `Tests/MonaCodeTests/Differential/test_harness.swift`, `Tests/MonaCodeTests/Differential/MonaDifferentialModelProvider.swift` (protocol stub)
**Tests:** Phase-0 scope: the Chrome 151 driver loads M0/M1, injects the identical E1 clock/entropy/locale trace used by N, captures golden output; the fixture format (`{schemaVersion: 1, id, input, injectedTrace, expected, domain: exact|native-adapted}`) round-trips; a seeded mismatch is detected and reported. The N-side uses a `MonaDifferentialModelProvider` stub returning hardcoded UTF-16 for the trivial case (defined as: `setValue("a")` on an empty model — 1 model, 1 edit, LF EOL; the stub returns the input unchanged). **The N-side zero-diff round-trip against M0/M1 is deferred to the Phase 1 exit gate** (requires the Piece Tree).
**Contract:** G4-R §equivalenceDomains.exact; §acceptance.overlays; §implementationOutputRules.environmentEffects (MonaEnvironmentManifest set-equal to E1-sensitive occurrences — validated against artifact `monacode-e1r-environment-intl-clock-entropy-manifest.json` `ecc1e42b…`).
**Produces:** `MonaEnvironmentManifest.json` (infrastructure; occurrence rows completed Phase 2).
**Exit-gate contribution:** every later C/P gate's differential evidence path (harness infra); N-side round-trip in Phase 1.
**Steps:**
- [ ] Build the headless Chrome 151 driver (inject identical E1 trace into M0/M1/N).
- [ ] Define the versioned fixture format; wire `MonaEnvironmentManifestBuilder` + stub provider; commit.

## Task 0.8 — Performance benchmark harness + full Q1-R3 statistical method

**Dependencies:** 0.7
**Files:** Create `Tests/BenchmarkHarness/BenchmarkRunner.swift`, `BootstrapStatistics.swift`, `CellManifest.swift`; Test `Tests/BenchmarkHarness/test_statistics.swift`
**Tests:** Statistical unit tests verify: intersection-union verdict (no Bonferroni; α=0.05); positive metric `exp(mean block log-ratio)`; `B=1,000,000`; `seed=SHA256(manifestHash || cellID || "Q1-R3")`; nearest-rank 5% quantile; basic one-sided upper bound `U = 2·θ̂ − q05`; **negative/zero/below-resolution component delta → pair invalid (not clamped)**; **near-zero continuous metric (comparator ≤ collector resolution, manifest-declared) switches to `mean(N−C)` difference estimator** (not auto-switched); **discrete comparator=0 requires all N=0**; **bootstrap resamples whole balanced blocks (M0/M1/N + active/idle/neutral), not individual samples**; **positive metric rejects non-finite/non-positive values**; **`U≤0` equality on unrounded binary64**. `CellManifest` schema validated against `monacode-q1r5-acceptance-manifest.json` (every C01–C10 / P00–P13 / cross-cutting cell has a corresponding manifest entry).
**Contract:** G4-R §performanceDecision; Q1-R2 (dual baseline), Q1-R3 (IUT, 1,000,000 bootstrap, deterministic seed, whole-block resampling, near-zero difference estimator, negative-delta invalidation, unrounded binary64), Q1-R4 (environment/font/cold-window); artifact `monacode-q1r5-acceptance-manifest.json`.
**Produces:** —
**Exit-gate contribution:** P00–P13 verdict infrastructure (cells passed in Phase 8). `BenchmarkRunner` includes a `QEnvironmentID` preflight hook (wired in Task 0.10).
**Steps:**
- [ ] Implement `CellManifest` (signed before any run) + schema validation against Q1-R5 manifest.
- [ ] Implement `BootstrapStatistics` with ALL Q1-R3 rules above; implement `BenchmarkRunner` (paired AB/BA, six orderings balanced, thermalState sampling, attempt cap 2×, QEnvironmentID preflight hook); commit.

## Task 0.8b — Q1-R4 font provenance + cold-launch + display enforcement

**Dependencies:** 0.8
**Files:** Create `Tests/BenchmarkHarness/Q1R4FontProvenance.swift`, `Tests/BenchmarkHarness/ColdLaunchProcessManager.swift`, `Tests/BenchmarkHarness/DisplayModeEnforcer.swift`
**Tests:** Font provenance: each rendered corpus records font family, PostScript name, file/table SHA-256, variation axes, glyph/run coverage via Core Text (`CTRun`/`kCTFontAttributeName`); an unmanifested face/run is a failure. Cold-launch: 50 cold launches per valid block, each with a fresh profile + new process tree, launch→ready latency recorded, process terminated after ready (no product-specific cold-slot timeout per §performanceDecision.absoluteTimeout; an external abort invalidates the block). Display enforcement: window fixed on one screen throughout; 60.0 and 120.0 are separate cells that never mix; 59.94 does NOT round to 60; any mode/screen change invalidates the block.
**Contract:** G4-R §performanceDecision.sampleProtocol; Q1-R4 (environment/font/cold-window); §acceptance.overlays.environment; §currentLocalEnvironment (display slots).
**Produces:** font-provenance manifest output wired to the candidate pipeline.
**Exit-gate contribution:** P00 cold-start + Q1-R4-compliant measurements.
**Steps:**
- [ ] Implement the font provenance collector, cold-launch process manager, and display-mode enforcer; commit.

## Task 0.9 — QEnvironmentID preflight collector

**Dependencies:** 0.1
**Files:** Create `Tools/QEnvironmentID.swift`, `Tools/qenvironment_schema.json`
**Tests:** Collector emits `QEnvironmentID.json` with: macOS build, Xcode, SDK, Swift, architecture, SoC, memory, display slots (session-local slot + connection + mode + backing scale + refresh + ICC bytes SHA-256 + EDR), enabled input sources, runtime locale (`zh-CN`), **runtime calendar (`gregory`)**, **runtime numbering system (`latn`)**, runtime time zone (`Asia/Shanghai`), Chrome + ICU data hash; **no** hardware serial/UUID/UDID/raw identity. Privacy self-check uses the audit's exact regex `[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}` with `gi` flag over all produced `.json`/`.html`/`.mjs` files → must be empty.
**Contract:** G4-R §currentLocalEnvironment; §validationScope.privacy; §candidateGeneratedArtifacts QEnvironmentID (requiredFor C07, C10, P00–P13); §acceptance.overlays.environment; audit `no-sensitive-environment-key`/`no-uuid-value`/`no-persisted-uuid-value`.
**Produces:** `QEnvironmentID.json` (per-run, Phase 8 stamps each acceptance run).
**Exit-gate contribution:** C07, C10, P00–P13 preflight (gates refuse to run without a fresh `QEnvironmentID`).
**Steps:**
- [ ] Implement the collector (reads non-identifying fields directly; redacts hardware/display identifiers to session-local slot + ICC SHA-256); pin the audit regex self-check; commit.

## Task 0.10 — Phase 0 integration + preflight gate

**Dependencies:** 0.1–0.9b
**Files:** Modify `Package.swift` (wire all test targets + resource); Create `docs/implementation-phases/verification/phase-00-verification.md` (done)
**Tests:** `swift build && swift test` green; `Tools/forbidden-imports.sh` clean; `node Tools/provenance.mjs` green; `node Comparators/probe/scopeProbe.mjs` reproduces F1-R3 counts; `QEnvironmentID.json` privacy-clean; G4-R `verify-contract.mjs` still `status: pass`. `BenchmarkRunner` QEnvironmentID preflight hook wired.
**Contract:** G4-R §designClosure.phaseRule; §empiricalStatus (frozen baseline; not mutated).
**Produces:** harness + comparators + E1 infra.
**Exit-gate contribution:** Phase 0 done when all tasks committed + three adversarial rounds pass (done — see `phase-00-verification.md`).
**Steps:**
- [ ] Run full Phase 0 suite; fix any red.
- [ ] Confirm the G4-R manifest is **unmodified** (`verify-contract.mjs` pass); Phase 0 adds E1 infra product sources tracked in E1-R `nativeEnvironmentSourceFiles`, not G4-R `productSourceFiles`.
- [ ] Commit.
