# MonaCode G5-R master implementation plan

## Fixed outcome

Deliver exactly three public products—`MonaCode`, `MonaCodeAppKit`, and `MonaCodeSwiftUI`—for arm64 macOS 26.0+, with the contract's three AppKit views, four SwiftUI types, 3,582 contract identities, seven candidate artifacts, C01–C10, P00–P13, and cross-cutting release gates. iOS and iPadOS remain later revisions and are not implementation work in this plan.

The plan contains no product implementation. A plan pass proves structural completeness only. It never proves behavioral equivalence, performance, reliability, candidate presence, or release readiness.

## Fixed module graph

| Product | Production dependencies | Boundary |
| --- | --- | --- |
| `MonaCode` | Foundation and repository-owned Core code | No platform UI/rendering/event/pasteboard types |
| `MonaCodeAppKit` | `MonaCode`, AppKit, Core Text, Core Graphics; Metal only under the frozen Phase 03 decision | Native view, input, accessibility, shaping, layout, rendering |
| `MonaCodeSwiftUI` | `MonaCode`, `MonaCodeAppKit`, SwiftUI | Lifecycle and binding wrappers only |

Non-product targets are exactly `sample-macOS-host`, `conformance-and-failure-injection`, and `benchmark-harness`. `Tests/Fixtures/DifferentialFixtures` is a resource, never a target.

## Phase graph

| Phase | Scope | Depends on | Human document |
| --- | --- | --- | --- |
| 00 | Scaffold and harness | none | `implementation-plan/phase-00-scaffold-harness.md` |
| 01 | Base model and transaction truth | 00 | `implementation-plan/phase-01-base-model.md` |
| 02 | Model semantics and environment behavior | 01 | `implementation-plan/phase-02-model-semantics.md` |
| 03 | Projection, layout, and rendering | 02 | `implementation-plan/phase-03-projection-layout-rendering.md` |
| 04 | Input, transfer, accessibility, and embedding | 03 | `implementation-plan/phase-04-input-transfer-accessibility.md` |
| 05 | Public surface and retained features | 04 | `implementation-plan/phase-05-public-surface-features.md` |
| 06 | Language, LSP, snippet, and Markdown | 05 | `implementation-plan/phase-06-language-lsp-snippet-markdown.md` |
| 07 | Diff, services, host, and source closure | 06 | `implementation-plan/phase-07-diff-services-host-source-closure.md` |
| 08 | Release candidate and distribution | 07 | `implementation-plan/phase-08-release-candidate-distribution.md` |
| 09 | Acceptance and release verdict | 08 | `implementation-plan/phase-09-acceptance-release-verdict.md` |

## Normative-layer matrix (42/42)

| Identity | Frozen source | Owning phase |
| --- | --- | --- |
| `accessibility:A1-R` | `accessibility-a1r-native-text-contract-closure.html` | 04 |
| `accessibility:A1-R2` | `accessibility-a1r2-selector-attribute-action-closure.html` | 04 |
| `accessibility:A2-R2` | `accessibility-a2r-native-widget-focus-closure.html` | 04 |
| `base-values-events:B1-R` | `base-b1r-value-event-uri-closure.html` | 01 |
| `clipboard-drag-drop-services:I4-R` | `transfer-i4r-adversarial.html` | 04 |
| `concurrency-transactions-validity:A+` | `concurrency-a-adversarial.html` | 01 |
| `concurrency-transactions-validity:A+-base` | `transactions-validity-recovery.html` | 01 |
| `concurrency-transactions-validity:R1` | `transactions-validity-adversarial.html` | 01 |
| `diff-engine:D1-R` | `diff-d1r-engine-closure.html` | 07 |
| `environment-intl-clock-entropy:E1-R` | `environment-e1r-intl-clock-entropy-closure.html` | 00 |
| `feature-public-surface:F1-R` | `features-f1r-complete-surface-closure.html` | 05 |
| `feature-public-surface:F1-R2` | `features-f1r2-instance-option-domain-closure.html` | 05 |
| `feature-public-surface:F1-R3` | `features-f1r3-machine-manifest-closure.html` | 05 |
| `feature-public-surface:F1-R4` | `features-f1r4-public-declaration-closure.html` | 05 |
| `feature-public-surface:F1-R5` | `features-f1r5-native-type-semantics-closure.html` | 05 |
| `language-lsp:L2-R` | `language-l2r-provider-lsp-closure.html` | 06 |
| `language-lsp:L2-R2` | `language-l2r2-framing-closure.html` | 06 |
| `language-lsp:L2-R3` | `language-l2r3-wire-error-closure.html` | 06 |
| `layout-rendering:V1-R3` | `layout-v1r3-final-closure.html` | 03 |
| `layout-rendering:V1-R4` | `layout-v1r4-cross-engine-closure.html` | 03 |
| `markdown-presentation-security:MD1-R` | `markdown-md1r-native-security-closure.html` | 06 |
| `model-regexp-unicode:M1-R` | `model-m1r-regex-snapshot-closure.html` | 02 |
| `model-regexp-unicode:M1-R2` | `model-m1r2-public-surface-closure.html` | 02 |
| `model-regexp-unicode:M1-R3` | `model-m1r3-regexp-unicode-provenance-closure.html` | 00 |
| `native-embedding-host:H1-R` | `host-h1r-native-embedding-closure.html` | 07 |
| `native-embedding-host:H1-R2` | `host-h1r2-opener-count-closure.html` | 07 |
| `native-input:I3-R` | `native-input-i3r-adversarial.html` | 04 |
| `native-input:I3-R2` | `native-input-i3r2-keybinding-closure.html` | 04 |
| `native-input:I3-R3` | `native-input-i3r3-composition-arbitration-closure.html` | 04 |
| `native-input:I3-R4` | `native-input-i3r4-public-event-pointer-scroll-closure.html` | 04 |
| `provenance:P1-R` | `provenance-p1r-final-artifact-closure.html` | 00 |
| `runtime-lifetime-resource:H2-R` | `runtime-h2r-global-lifetime-resource-closure.html` | 01 |
| `snippet-engine:SN1-R` | `snippet-sn1r-engine-closure.html` | 06 |
| `source-runtime-style:X1-R` | `source-x1r-runtime-style-closure.html` | 07 |
| `standalone-services-session-feedback:S1-R` | `services-s1r-session-feedback-closure.html` | 07 |
| `theme-token-icon:T1-R` | `theme-t1r-registry-token-icon-closure.html` | 05 |
| `ui-localization:N1-R` | `localization-n1r-ui-message-closure.html` | 05 |
| `verification:Q1-R` | `verification-q1r-differential-performance-closure.html` | 00 |
| `verification:Q1-R2` | `verification-q1r2-measurement-closure.html` | 00 |
| `verification:Q1-R3` | `verification-q1r3-statistical-window-closure.html` | 00 |
| `verification:Q1-R4` | `verification-q1r4-environment-font-cold-closure.html` | 00 |
| `verification:Q1-R5` | `verification-q1r5-complete-acceptance-closure.html` | 00 |

## Inherited machine-artifact matrix (17/17)

| Identity | Frozen source | Owning phase |
| --- | --- | --- |
| `A2-R2-accessibility` | `monaco-0.56.0-a2r-accessibility-manifest.json` | 04 |
| `D1-R-diff-engine` | `monacode-d1r-diff-engine-manifest.json` | 07 |
| `E1-R-environment-intl` | `monacode-e1r-environment-intl-clock-entropy-manifest.json` | 00 |
| `F1-R3-instance` | `monaco-0.56.0-f1r3-instance-surface-manifest.json` | 00 |
| `F1-R3-scope` | `monaco-0.56.0-f1r3-scope-manifest.json` | 00 |
| `F1-R4-public` | `monaco-0.56.0-f1r4-public-declaration-manifest.json` | 05 |
| `F1-R5-native-types` | `monacode-f1r5-native-type-contract-manifest.json` | 05 |
| `H1-R-native-boundary` | `monacode-h1r-native-boundary-manifest.json` | 07 |
| `H1-R2-host-group` | `monacode-h1r2-host-group-correction-manifest.json` | 07 |
| `H2-R-runtime-resource` | `monacode-h2r-runtime-resource-manifest.json` | 07 |
| `M1-R3-regexp-unicode` | `monacode-m1r3-regexp-unicode-manifest.json` | 02 |
| `MD1-R-markdown` | `monacode-md1r-markdown-contract-manifest.json` | 06 |
| `N1-R-localization` | `monacode-n1r-localization-manifest.json` | 05 |
| `Q1-R5-acceptance` | `monacode-q1r5-acceptance-manifest.json` | 00 |
| `S1-R-standalone-services` | `monacode-s1r-standalone-service-contract-manifest.json` | 07 |
| `SN1-R-snippet-engine` | `monacode-sn1r-snippet-engine-manifest.json` | 05 |
| `X1-R-source-runtime-style` | `monacode-x1r-source-runtime-style-manifest.json` | 07 |

## Correctness matrix (C01–C10)

| Gate | Owning phase | Terminal task family |
| --- | --- | --- |
| C01 | 09 | P09-C01 |
| C02 | 09 | P09-C02 |
| C03 | 09 | P09-C03 |
| C04 | 09 | P09-C04 |
| C05 | 09 | P09-C05 |
| C06 | 09 | P09-C06 |
| C07 | 09 | P09-C07 |
| C08 | 09 | P09-C08 |
| C09 | 09 | P09-C09 |
| C10 | 09 | P09-C10 |

## Performance matrix (P00–P13)

| Workload | Owning phase | Terminal task | Required comparison cells |
| --- | --- | --- | --- |
| P00 | 09 | P09-P00 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P01 | 09 | P09-P01 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P02 | 09 | P09-P02 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P03 | 09 | P09-P03 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P04 | 09 | P09-P04 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P05 | 09 | P09-P05 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P06 | 09 | P09-P06 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P07 | 09 | P09-P07 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P08 | 09 | P09-P08 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P09 | 09 | P09-P09 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P10 | 09 | P09-P10 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P11 | 09 | P09-P11 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P12 | 09 | P09-P12 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |
| P13 | 09 | P09-P13 | M0 × M1 × native; M0/M1; 60/120 Hz where applicable |

Refresh rate changes the frame deadline only. It never relaxes the native-versus-comparator no-regression threshold.

## Candidate-artifact order

| Candidate | Finalizing phase | Required predecessor |
| --- | --- | --- |
| `MonaNativeDeclarationManifest.json` | 08 | After Phase 07 public-api-closure |
| `MonaRegExpUnicodeManifest.json` | 08 | After all RegExp and Unicode consumers |
| `MonaEnvironmentManifest.json` | 08 | After all environment-sensitive consumers |
| `MonaSourceClosureManifest.json` | 08 | After all product source producers |
| `MonaCacheManifest.json` | 08 | After all cache producers |
| `MonaDistributionManifest.json` | 08 | After release package and notice scans |
| `QEnvironmentID.json` | 09 | Recollected for each formal run; exact environment preflight |

Phase 09 correctness, performance, reliability, and verdict tasks consume finalized candidates; no acceptance task creates product source.

## Contract inventory and ownership rule

The copied contract inventory contains exactly 3582 identities: 3349 retained and 233 disposition-only. Every retained identity receives exactly one implementation owner and at least one test owner. Every disposition-only identity receives no implementation or test owner. Ownership rows preserve the exact identity and disposition text; aggregate selectors never replace individual rows.

## Evidence directories

| Evidence family | Repository path | Meaning |
| --- | --- | --- |
| Per-task red/green | `artifacts/acceptance-evidence/g5-r/phase-NN/TASK.json` | Future implementation result for one task |
| Correctness | `artifacts/acceptance-evidence/g5-r/correctness/CNN/` | C01–C10 comparator and native evidence |
| Performance | `artifacts/acceptance-evidence/g5-r/performance/PNN/` | M0/M1 blocks, cells, bootstrap inputs, verdicts |
| Reliability | `artifacts/acceptance-evidence/g5-r/reliability/` | Lifecycle, soak, sanitizers, failure injection, complexity |
| Qualification | `artifacts/acceptance-evidence/g5-r/environment/` | Per-run privacy-filtered QEnvironmentID |
| Distribution | `artifacts/acceptance-evidence/g5-r/distribution/` | Release package, symbols, links, resources, notices, hashes |

Files under `implementation-plan/verification/` prove plan structure only and are forbidden as product evidence.

## Global execution constraints

- Preserve raw UTF-16 semantics, including isolated surrogates, wherever the contract declares exact behavior.
- Keep model mutation behind one transactional gateway with version, cancellation, reconciliation, and rollback truth.
- Complete a correct Core Graphics renderer before the Phase 03 renderer-owned C03/C08 decision gate; create Metal only inside the declared conditional task.
- Keep language behavior transport-neutral and LSP-first; without an attached provider or LSP capability, retain plain-text behavior.
- Keep built-in language packs, JavaScript runtimes, web workers, WebView/DOM/CSS runtimes, TextKit semantic substitution, third-party production runtimes, telemetry, persistence, and later mobile adapters out of production.
- Run all formal C/P evidence on exact macOS build `25G83`, Chrome `151.0.7922.170`, built-in display only, zero external displays, and the fixed input-source/font prerequisites.
- Treat every skipped, missing, stale, malformed, unauthorized, or incomplete cell as not-passed.

## Machine verification

- `node verify-plan.mjs --phase NN` verifies one authored phase without demanding unauthored future identities.
- `node verify-plan.mjs` requires the entire graph, all 3,582 ownership rows, all ten documents, boundaries, evidence truth, and deterministic hashes.
- `node --test tests/*.test.mjs` proves all positive controls and negative fixtures.
