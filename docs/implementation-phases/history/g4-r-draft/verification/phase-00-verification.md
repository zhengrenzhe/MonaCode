# Phase 0 Adversarial Verification Report

Three independent adversarial verification rounds (fresh-context agents) examined `phase-00-scaffold-harness.md` + `00-master-plan.md` against the G4-R contract. Findings consolidated below with dispositions. Blocking/Major findings are fixed in the phase doc; the master plan matrix is clarified.

## Consolidated findings

### BLOCKING (fixed)

| # | Finding | Rounds | G4-R clause | Disposition |
|---|---------|--------|-------------|-------------|
| B1 | Task 0.10 claims `empiricalStatus.productSourceFiles` "is still 0" while Phase 0 adds ~9 product source files in `Sources/MonaCode/Environment/`. The field is a frozen design-baseline snapshot, never mutated; implementation progress is tracked in candidate artifacts + domain `implementationStatus` (e.g. E1-R `nativeEnvironmentSourceFiles`). | R1(M), R3(B), R2(m) | §empiricalStatus.productSourceFiles; audit `product-source-zero`; §designClosure.phaseRule | **Fixed**: Task 0.10 rephrased — the check confirms the *frozen manifest is unmodified* (not that the repo has zero files); Phase 0 adds E1 infra product sources tracked in E1-R, not in G4-R `productSourceFiles`. |
| B2 | Task 0.1 declares an executable target `sample-macOS-host` (depends `MonaCodeSwiftUI`) with no source files → `swift build` fails; `MonaCodeSwiftUI` is empty in Phase 0. | R3(B) | §deliveryScope.requiredNonProductTargets | **Fixed**: Task 0.1 adds `Sources/sample-macOS-host/main.swift` stub (no `MonaCodeSwiftUI` import) and defers the dependency to Phase 4. |

### MAJOR (fixed)

| # | Finding | Rounds | G4-R clause | Disposition |
|---|---------|--------|-------------|-------------|
| M1 | Master plan E1-R matrix lists `Number::toString` under Phase 2 cross-cutting, but Task 0.5 implements it in Phase 0 (entropy requires it). | R3(M); R2 says split is consistent | master plan E1-R row; §acceptance.overlays.C02 | **Fixed**: master plan E1-R matrix cross-cutting column clarified — `Number::toString` built in Phase 0 (entropy infra), occurrence classification + C02 verification in Phase 2. Satisfies both R2 (consistent) and R3 (matrix clarity). |
| M2 | Q1-R4 font provenance, cold-launch process protocol, and display-mode enforcement cited but not implemented in any Phase 0 task. | R3(M) | Q1-R4; §performanceDecision.sampleProtocol; §acceptance.overlays.environment | **Fixed**: added Task 0.8b (font provenance collector, cold-launch process manager, display-mode enforcer). |
| M3 | Forbidden-import CI grep gate deferred to Phase 9; hundreds of `Sources/MonaCode/` files arrive in Phases 1–8 unguarded. | R3(M) | §architecture.dependencies; §explicitCuts | **Fixed**: added Task 0.1b — `Tools/forbidden-imports.sh` scans `Sources/MonaCode/**/*.swift` for AppKit/SwiftUI/UIKit/Metal/CoreText/CoreGraphics/NSRegularExpression/Foundation.ICU*; fails CI on match; Phase 9 `dump-package` augments. |
| M4 | Task 0.7 N-side round-trip (`setValue("a")`) needs the Phase 1 Piece Tree; Phase 1 is not a dependency. | R3(M) | §equivalenceDomains.exact; Q1-R | **Fixed**: Task 0.7 split — Phase 0 runs harness-infrastructure test (Chrome driver loads M0/M1, injects E1 traces, fixture format round-trips, seeded mismatch detected) with a `MonaDifferentialModelProvider` stub; N-side zero-diff round-trip deferred to Phase 1 exit gate. |
| M5 | `BootstrapStatistics` omits five Q1-R3 rules: (a) negative/zero/below-resolution component delta invalidates the pair; (b) near-zero *continuous* metric switches to `mean(N−C)` difference estimator (manifest-declared, not auto-switched); (c) bootstrap resamples whole balanced blocks (not individual samples); (d) positive metric rejects non-finite/non-positive values; (e) `U≤0` equality on unrounded binary64. Harness would pass seeded tests but produce incorrect Phase 8 verdicts. | R2(M) | Q1-R3 rules 16, sampling-unit, positive-metric, near-zero-metric, verdict rows | **Fixed**: Task 0.8 implementation + tests expanded with all five rules. |
| M6 | M1 lock hash published only truncated (`166a192d…efe9b`) in Q1-R2 HTML; no full hash in any JSON machine artifact; audit does not verify M1 hash. | R2(M) | Q1-R2 M1 baseline; §authorityArtifacts (no M1 entry) | **Fixed**: Task 0.2 test reworded — candidate self-pins the full M1 lock SHA-256 (reproducible from esbuild 0.25.9 + Q1-R2 cut spec) and verifies prefix `166a192d` + suffix `efe9b` against the Q1-R2 HTML; no full hash exists in a JSON artifact. |

### MINOR (fixed)

| # | Finding | Rounds | Disposition |
|---|---------|--------|-------------|
| m1 | `MonaCodeTests`/`MonaCodeAppKitTests` test targets not declared in `Package.swift`; tests silently skipped. | R1(m) | **Fixed**: Task 0.1 declares both `.testTarget`s. |
| m2 | `QEnvironmentID` omits `runtimeCalendar`/`runtimeNumberingSystem`. | R1(m) | **Fixed**: Task 0.9 fields include calendar (gregory) + numbering (latn). |
| m3 | `QEnvironmentID` privacy self-check regex not pinned to audit's exact `[0-9A-F]{8}-…-[0-9A-F]{12}` (`gi`) over all produced `.json/.html/.mjs`. | R2(m) | **Fixed**: Task 0.9 pins the audit regex + scan scope. |
| m4 | Task 0.9→0.6 dependency questionable (collector is a `Tools/` script). | R1(m) | **Fixed**: dependency changed to 0.1; collector reads `Locale.current`/`TimeZone.current` directly. |
| m5 | Task 0.8 doesn't reference 0.9 (QEnvironmentID preflight). | R1(m) | **Fixed**: Task 0.8 notes the preflight hook is wired in 0.10. |
| m6 | Task 0.4 exit-gate claims input-latency recorder (25 calls) drives P02/P04, but no recorder created in Phase 0. | R2(m) | **Fixed**: removed from Task 0.4 exit-gate; recorder is Phase 3+. |
| m7 | Q1-R5 acceptance manifest not referenced by any Phase 0 task. | R3(m) | **Fixed**: Task 0.8 validates `CellManifest` schema against `monacode-q1r5-acceptance-manifest.json`. |
| m8 | E1-R machine artifact SHA not cited. | R3(m) | **Fixed**: Tasks 0.4–0.7 cite `monacode-e1r-environment-intl-clock-entropy-manifest.json` (`ecc1e42b…`) + add validation step. |
| m9 | Differential fixture format lacks `schemaVersion`. | R3(m) | **Fixed**: Task 0.7 adds `schemaVersion: 1`. |
| m10 | `Tests/DifferentialFixtures/` not a declared target; `test_harness.swift` orphaned. | R3(m) | **Fixed**: `test_harness.swift` moved to `Tests/MonaCodeTests/Differential/`; `DifferentialFixtures/` is a `.copy("Fixtures")` resource. |
| m11 | `ConformanceAndFailureInjection` has no skeleton. | R3(m) | **Fixed**: Task 0.1 adds `FailureInjector` protocol + `ConformanceTestCase` base + fault enumeration. |
| m12 | `Sources/MonaCode/Generated/` + license-notice template absent. | R3(m) | **Fixed**: Task 0.1 creates `Generated/` + `LICENSE.md` template (Unicode-3.0/Chromium-ICU/Monaco-MIT/Marked-MIT/Test262 BSD sections). |

## Dimensions confirmed clean (all three rounds)

- **Citation integrity**: every sampled SHA-256 (monaco tar `b74bc443…`, core tar `78e222c7…`, `monaco.d.ts` `fbbab04b…`, time source `0015cb2f…`, source tag `13f0c872…`, F1-R3 scope `31d79fd3…`, instance `1163834f…`, F1-R4 `b6cb6c73…`, V8 ieee754 `998f6f44…`) and every count (64/167/454/379/18/121/174/431/776/4/91; instance 43/40, 137/130, 141/133, 60/52, 65/55; StopWatch 21=13+6+2; input-latency 25; RANDOM_HEX 0.5→0.8) verified against G4-R. No fabricated/misattributed citations.
- **Architecture conformance**: no forbidden production dependency; E1 two-clock-domain separation correct; locale separation correct; Foundation used only to read locale identifier (not for case/collation/normalize).
- **Comparator fidelity**: M1 cut list (WebGPU debug + 81 defs + 4 packs) matches Q1-R2; Chrome probe zero-diff required.
- **Privacy**: display-identity redaction matches §validationScope.privacy exactly.
- **Freeze rule**: no scope/cut/adaptation/architecture/gate/threshold added; no silent no-op; no gate falsely claimed to pass.
- **Dependency DAG**: valid, no cycles, no task depends on a later phase.

## Outcome

All BLOCKING and MAJOR findings fixed in `phase-00-scaffold-harness.md`; master plan E1-R matrix clarified. Phase 0 plan is approved to proceed. Implementation has not started (no code written); this verification validates the *plan* only.
