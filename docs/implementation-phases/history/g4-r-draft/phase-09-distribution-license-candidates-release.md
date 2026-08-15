# Phase 9 — Distribution, License, Candidate Artifacts, Release Verdict

**Goal:** Produce the release distribution (3-product graph, arm64 macOS 26.0+), complete license provenance, emit `MonaDistributionManifest.json` (the 7th candidate artifact), validate all 7 candidate artifacts present, and run the final C10 pass + release acceptance verdict.

**G4-R mapping:** provenance P1-R (distribution provenance); verification Q1-R5 (release verdict); §licensingProfile; §candidateGeneratedArtifacts; §acceptance.overlays.C10; §empiricalStatus.

**Prerequisites:** Phase 8 (C01–C09 pass, P00–P13 pass, cross-cutting pass; C10 evidence gathered pending distribution manifest). All product behavior complete.

**Exit Gates (this phase completes):**
- **C10 (pass)** — distribution includes all 15 N1-R profiles + 2120 messages + Monaco MIT, Marked MIT (modified-port notice), LSP CC BY 4.0, Codicon CC BY 4.0, Git Logo CC BY 3.0, Unicode-3.0, Chromium ICU license, Test262 BSD; generated E1 tables carry exact inputs/hashes; zero unclassified reachable module/exclusion/style/rule/global/effect row; Codicon font hash `cc2472e2…` (140956 bytes); absence of every forbidden production dependency.
- All 7 candidate artifacts present + validated.
- **Release verdict: passed** (signed artifact set).
- Preflight: audit/verify-contract pass.

---

## Task 9.1 — Release distribution + 3-product graph

**Dependencies:** 8.9
**Files:** Create `Tools/release_build.sh`, `Tools/distribution_scan.swift`; Modify `Package.swift` (release configuration)
**Tests:** `swift build -c release` produces arm64 macOS 26.0+ artifacts for `MonaCode`, `MonaCodeAppKit`, `MonaCodeSwiftUI` + the `sample-macOS-host` executable. `swift package dump-package` / `describe` / `show-dependencies` confirm the 3-product graph, the 3 non-product targets, the 3 AppKit views, and the 4 SwiftUI types. Linked dylibs/resources enumerated; no third-party production runtime linked.
**Contract:** G4-R §deliveryScope (publicProducts, requiredNonProductTargets, requiredViews, requiredSwiftUITypes, productionLinkedDependencies); §validationScope.packageDeploymentTarget=macOS 26.0; §architecture.dependencies="no third-party production runtime"; §acceptance.overlays.C10.
**Produces:** release artifacts.
**Exit-gate contribution:** C10 (3-product graph, release builds, dependency scan).
**Steps:**
- [ ] Configure release build; enumerate products/targets/views/types; scan linked dylibs + resources; commit.

## Task 9.2 — License provenance + notices

**Dependencies:** 5.4, 5.5, 6.8, 2.5, 2.7
**Files:** Create `Sources/MonaCode/Generated/LICENSE.md` (consolidated), per-domain notice headers; Modify generated-table headers
**Tests:** Distribution carries: Monaco MIT (copied/generated English + 13 locale tables retain Monaco MIT provenance); Marked MIT (Swift port retains MarkedJS MIT copyright + license, marks modified files); LSP specification CC BY 4.0 (attribution + license reference + modification notice); Codicon CC BY 4.0 (artwork + font) + CC BY 3.0 (Git Logo exception when bundled full font includes the glyph) + MIT (generator/code); Unicode-3.0 (pinned notice on every derived Unicode table); Chromium ICU license (generated collation/locale tables from ICU 78.2 commit `d578f2e8…`, local `icudtl.dat` SHA `9f48c7f9…`, exact LICENSE + generated-table provenance record); Test262 BSD (redistributed source corpora + generated vectors + binary artifacts). DOMPurify 3.4.8 oracle-only (absent from production). esbuild 0.25.9 MIT (M1 build-only, absent from product binaries; redistributed benchmark bundle includes its notice). V8/ICU code/runtime oracle-only (V8 ieee754 `998f6f44…` provenance only, never copied/linked). vscode-unicode-data unlicensed repo NOT a build/distribution input.
**Contract:** G4-R §licensingProfile (monacoCode, monacoLocalization, marked, domPurify, lspSpecification, codiconArtworkAndFont, codiconGitLogoException, codiconGeneratorAndCode, unicodeTables, chromiumIcuData, test262, v8AndIcu, vscodeUnicodeData, comparatorBuildTools); §acceptance.overlays.C10.
**Produces:** consolidated license manifest.
**Exit-gate contribution:** C10 (license notices).
**Steps:**
- [ ] Author/verify all notice headers + consolidated LICENSE; commit.

## Task 9.3 — MonaDistributionManifest producer + candidate validation

**Dependencies:** 9.1, 9.2, 2.9, 5.8, 7.7, 7.8, 8.5
**Files:** Create `Tools/MonaDistributionManifest.swift`; Create `Tools/validate_all_candidates.mjs`
**Tests:** `MonaDistributionManifest.json` records release artifact, dependency, API, and notice scan: every artifact SHA-256, all 15 N1-R profiles + 2120 messages, generated E1 table inputs/hashes, Codicon font hash `cc2472e2…` (140956 bytes), absence of persistence backends/telemetry/notification-progress UI/signal audio/supportHtml/media loading/DOM/CSS runtime/WebView/DOMPurify production code/V8 and ICU code-runtime/JavaScript/source-map resources/JS engines/@vscode/diff/WASM/`NSRegularExpression` semantic substitution/unlicensed vscode-unicode-data code or output. All 7 candidate artifacts present + validated against their machine artifacts: `MonaNativeDeclarationManifest`, `MonaRegExpUnicodeManifest`, `MonaEnvironmentManifest`, `MonaSourceClosureManifest`, `MonaCacheManifest`, `MonaDistributionManifest`, `QEnvironmentID`.
**Contract:** G4-R §candidateGeneratedArtifacts (7 artifacts, all `present`); §implementationOutputRules; §acceptance.overlays.C10; §empiricalStatus (candidateGeneratedArtifactsPresent transitions to 7).
**Produces:** `MonaDistributionManifest.json` (present); all 7 candidates validated.
**Exit-gate contribution:** C10 (distribution manifest exact-set).
**Steps:**
- [ ] Implement the distribution scanner; emit manifest; validate all 7 candidates; commit.

## Task 9.4 — C10 final pass + release verdict

**Dependencies:** 9.3, 8.9
**Files:** Modify `Tools/release_verdict.mjs`; Create `docs/implementation-phases/verification/phase-09-verification.md` (after verification); Create `docs/implementation-phases/RELEASE_VERDICT.md`
**Tests:** C10 final pass: `swift package dump-package/describe/show-dependencies` for the 3-product graph; release builds arm64 macOS 26.0+; symbol graphs + API digester; linked dylibs + resources; every artifact SHA-256; no forbidden runtime; all license notices; `MonaDistributionManifest` exact-set. Release verdict: C01–C10 + every P00–P13 cell + reliability + failure-injection + complexity gates pass for one exact revision + signed artifact set. Any missing artifact/permission/input source/sample/comparator/manifest entry or skipped/failed cell → not-passed.
**Contract:** G4-R §acceptance.releaseVerdict / notPass; §empiricalStatus (releaseVerdict → `passed`); §designClosure.stoppingCriterion.implementationVerdict ("not-passed until all seven candidate artifacts, native source, C01–C10, P00–P13 and cross-cutting gates pass"); Q1-R5.
**Produces:** signed release artifact set; `RELEASE_VERDICT.md`.
**Exit-gate contribution:** C10 pass; release verdict passed.
**Steps:**
- [ ] Run C10 final + release verdict aggregator; if pass, sign artifact set + write `RELEASE_VERDICT.md`; commit; trigger per-phase adversarial verification.

## Task 9.5 — Post-release contract integrity confirmation

**Dependencies:** 9.4
**Files:** —
**Tests:** `node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs` still `status: pass`; G4-R audit still `failureCount=0`, `unresolvedScopeDecisions=0`. The implementation did not mutate the frozen contract (freeze rule honored throughout).
**Contract:** G4-R §designClosure.phaseRule; §authorityRules (hashMismatch/scopeChange); §designClosure.historicalPreflightRule.
**Produces:** —
**Exit-gate contribution:** confirms implementation proceeded under G4-R without contract mutation.
**Steps:**
- [ ] Run verify-contract + audit; confirm pass; commit; trigger whole-plan adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-09-verification.md` (3 rounds; no BLOCKING/MAJOR):

- **Task 9.1:** `dump-package`/`describe`/`show-dependencies` confirm products/targets only — the 3 AppKit views + 4 SwiftUI types are confirmed by **symbol graph + API digester** in Task 9.4. "Release configuration" = `-c release` flag + platform/deployment-target confirmation (not a `Package.swift` section).
- **Task 9.2:** pin **Marked 14.0.0**; explicitly discharge the DOMPurify conditional — "no DOMPurify-derived code in production" (replaced, not ported; derived code would require a new provenance revision + Apache-2.0/MPL-2.0); add Phase 0/7 refs for esbuild 0.25.9 MIT + V8 ieee754 `998f6f44…` provenance.
- **Task 9.3:** cross-verify the four license-file SHA-256s from `authorityArtifacts` (LSP `9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188`, Chromium-ICU `e55522d81edc687a341a4411e0776e54ca654e90147f354a90458aaced4116af`, Codicon artwork `af5e030844efddbc7ab00dcfea8b019703753d4d9f5172d727c533a492aec665` / code `9906940f61b1f0b533fa7d99baf55178b2808fbe113ea51dfbfad8572ccd5f2b`).
- **Task 9.4:** restate **QEnvironmentID recollection as preflight** before the verdict run; verdict line adds "**all 7 candidate artifacts present + native source complete**" per §designClosure.stoppingCriterion.implementationVerdict.
- **Tasks 9.3/9.4:** the `empiricalStatus` transitions (candidateGeneratedArtifactsPresent 0→7; releaseVerdict `not-passed`→`passed`) are tracked in **`RELEASE_VERDICT.md` / candidate artifacts**, NOT by mutating the frozen G4-R contract (verify-contract.mjs would reject any mutation).
