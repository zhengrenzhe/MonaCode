# Phase 2 Adversarial Verification Report

Three independent rounds. No BLOCKING. Four MAJOR (specification-precision). Citation integrity clean — all 10 RegExp consumer profiles verified word-for-word against m1r3; all 6 Unicode profile SHAs verified; all 12 intrinsic ref counts (Math 1099/Object 638/Reflect 618/Array 250/Map 230/Promise 192/Set 176/String 131/Number 107/RegExp 74/JSON 73/Symbol 39) match X1-R exactly; StringSHA1 (5/5) + TextDecoder (6/6) vectors match.

## MAJOR (fixed)

| # | Finding | Rounds | Disposition |
|---|---------|--------|-------------|
| M1 | Task 2.7 Contract says "4 Collator profiles" but G4-R `collationProfiles=5` and C02 says "five". | R1,R3 | **Fixed**: "5 collation profiles (4 Collator constructions + 1 localeCompare profile `string-locale-compare-default`)" — matches E1-R C05 wording "four Collator constructions, eleven localeCompare call sites". |
| M2 | Search time-budget clock (wordHelper `Date.now` wall-clock, 150ms budget, checked at outer-loop top) has no explicit task step. | R3 | **Fixed**: Task 2.3 step added — wire search time-budget to the Phase-0 E1 wall clock (`MonaWallClock`); single regex exec may exceed 150ms; no step counter inside synchronous exec. |
| M3 | `tryNormalizeToBase` omits the final "locale-insensitive lowercase" step (E1-R: NFD → strip U+0300–036F → accept if length unchanged → THEN lowercase). Without it "Café"→"Cafe" not "cafe". | R2 | **Fixed**: Task 2.7 — append the locale-insensitive lowercase step. |
| M4 | Compiled pattern cache key = source + `g/u/i/m` omits `s`(dotAll)/`v`(unicodeSets); if applied to general `MonaRegExp`, same-source different-s/v patterns collide. | R2 | **Fixed**: Task 2.4 — cache scoped to the `createRegExp` search path (4-flag key, matching Monaco); general `MonaRegExp` constructor uses source + all compilation-affecting flags (i/m/s/u/v); high-water bound per §implementationOutputRules.cacheBounds. |

## MINOR (noted; high-value applied)

- Task 2.7/2.8 add explicit `Number::toString` mention in Tests (C02 traceability). [applied]
- Task 2.8 per-intrinsic counts cite X1-R `intrinsicOperationProfiles.selectedReferenceCounts` (not manifest aggregate). [applied]
- Task 2.8 note all 3 active decoder profiles + 1 inert textEncoder for `MonaEnvironmentManifest` classification. [applied]
- Task 2.8 add `decodeUTF16LELeadingBOM` vectors (FEFF/FFFE first-unit bypass). [applied]
- Task 2.9 name E1-R artifact `monacode-e1r-environment-intl-clock-entropy-manifest.json` (SHA `ecc1e42b…`) for `MonaEnvironmentManifest` set-equality. [applied]
- Task 2.9 enumerate all E1 occurrence categories with counts (timers 94, microtask 11, StopWatch 21=13+6+2, input-latency 25). [applied]
- Task 2.7 state locale scope: all Chrome 151 locales, NOT reduced to zh-CN. [applied]
- Task 2.6 add gloss: "10 consumer profiles = 1 search + 9 language/provider". [applied]
- TokensProviderFactory is a Phase-5 F1-R5 surface, not a Phase-2 RegExp downstream — downstream framing corrected (RegExp enables Phase 6, not Phase 5). [applied]

## Outcome
Phase 2 approved. All MAJOR fixed; MINOR applied. No architecture/scope/freeze-rule issue. C01 + C02 pass framing honest (full 256-seed × 10K + 2117 Test262 vs M0 AND M1).
