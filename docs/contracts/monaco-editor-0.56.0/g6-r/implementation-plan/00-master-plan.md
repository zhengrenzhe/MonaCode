# MonaCode G6-R master execution plan

## Fixed outcome

Deliver exactly three public products—`MonaCode`, `MonaCodeAppKit`, and `MonaCodeSwiftUI`—for arm64 macOS 26.0+, ported from monaco-editor@0.56.0. The G6-R plan is the execution-readiness revision of the adopted G5-R full-scope plan. It migrates the 200 G5-R product tasks into structured G6-R TaskRecords with a seven-stage lifecycle, pinned toolchain commands, and commit-before-evidence ordering.

The plan contains no product implementation. An assembly pass proves structural completeness only. It never proves behavioral equivalence, performance, reliability, candidate presence, or release readiness.

## Authority

- Plan ID: `G6-R`
- Plan revision: `g6-r-execution-readiness`
- Base commit: `6343dc191ad77310194915bea2514c7b70733cfe`
- Plan hash: `b02c1c1c764333bc61df4de47afc9bc2eab3bd532193cbf61f0c89654b576c85`
- Tasks: 200
- Ownership rows: 3582
- Commands: 400
- Interfaces: 340

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

## Fixed matrices

| Matrix | Count |
| --- | --- |
| Tasks | 200 |
| Test contracts | 200 |
| Verification commands | 400 |
| Leaf processes | 407 |
| Begin actions | 200 |
| Commit actions | 200 |
| Finalize actions | 200 |
| Product-commit contracts | 200 |
| Evidence-commit contracts | 200 |
| Source gaps | 0 |
| Acquisition gaps | 0 |
| Red-scaffold tasks | 139 |
| Red-scaffold paths | 249 |
| Interface contracts | 340 |
| Ownership rows | 3582 |
| Evidence contracts | 200 |

## Documents

| Document | SHA-256 |
| --- | --- |
| `implementation-plan/README.md` | `fd97a942c4260a744df15aae01e3569857f11a541b7163029a0dc1f476d07d4d` |
| `implementation-plan/00-master-plan.md` | `6d6057b84c42f029ea0201e16aed26102fc6514be5e4205c6f8ed9435c7bc5dc` |
| `implementation-plan/phase-00-scaffold-harness.md` | `15db643b95d2c3956ee76d1740d44023cb8ea2e9632d524e74aad075f972b825` |
| `implementation-plan/phase-01-base-model.md` | `54679212be9929384244e12ee5d2b23d31447cb1c4bd719e39658c82315d2098` |
| `implementation-plan/phase-02-model-semantics.md` | `96773dc4489841fe024074ed35a6a4c5aa2f51540c00a34f34e71c101cdfa49d` |
| `implementation-plan/phase-03-projection-layout-rendering.md` | `7365e494842b0f1d8ed8906d731e2d7aad5f06cba18ee5ee825d32453d62de98` |
| `implementation-plan/phase-04-input-transfer-accessibility.md` | `040a7d6845d409c20c990db0f5f23502aceaa703b58055ee47a76263cbbc6239` |
| `implementation-plan/phase-05-public-surface-features.md` | `e54b48e7e0d72b9125c18b9e5927a4eb11d05e77d5432fa3e573cea2d278b83a` |
| `implementation-plan/phase-06-language-lsp-snippet-markdown.md` | `89c406568172d99b6982068d4f4d6747e1572c85a177d3b61514104e713eae35` |
| `implementation-plan/phase-07-diff-services-host-source-closure.md` | `7f0da49b60a22437d5707db06523b9cb730beff1105cf0ecd29e48eb6e81ab07` |
| `implementation-plan/phase-08-release-candidate-distribution.md` | `bcdd9de61558e46e2535631342ed34371ddedf4be2aa1ada62fbf179d0610aad` |
| `implementation-plan/phase-09-acceptance-release-verdict.md` | `7eb2d6c5abb86fd8848922648ade10a4bf1f77901843e0d3e0b774a098d1c642` |
