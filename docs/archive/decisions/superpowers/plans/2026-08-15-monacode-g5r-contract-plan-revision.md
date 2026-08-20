# MonaCode G5-R Contract and Full Plan Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create and adopt an immutable G5-R contract archive containing a complete, machine-verifiable MonaCode product implementation plan that has passed automated negative testing and three independent adversarial review rounds.

**Architecture:** Preserve G4-R and the current G4-R plan draft byte-for-byte, construct G5-R as a self-contained sibling archive, and make a JSON plan manifest the machine authority for task ownership and dependency order. Human phase documents carry stable task markers and reviewer-sized red/green steps, while focused Node.js audit modules reject graph, coverage, boundary, evidence, and environment violations before adoption.

**Tech Stack:** Markdown, JSON, JSON Schema 2020-12, Node.js ESM using built-in modules only, POSIX shell utilities available on macOS, SHA-256, Git.

## Global Constraints

- The approved design is `docs/superpowers/specs/2026-08-15-monacode-g5r-contract-plan-revision-design.md` at commit `207f738`, with factual and renderer-order corrections in commits `b85dcaf` and `f7f0929`.
- G4-R remains byte-immutable and independently verifiable at `docs/contracts/monaco-editor-0.56.0/g4-r/`.
- G5-R changes qualification environment and plan governance only; product features, cuts, native adaptations, architecture, host behavior, C01-C10, P00-P13, M0/M1, 60/120 Hz cells, and `native/comparator <= 1.00` remain unchanged.
- The qualified runtime is arm64 macOS 26.6.1 build `25G76` with Xcode 26.6 build `17F113`, SDK 26.5, Swift 6.3.3, and Chrome `151.0.7922.138`.
- Formal C/P runs require the built-in display and `externalDisplayCount == 0`; external displays remain outside the release verdict.
- `MonaCode` imports Foundation only. AppKit, Core Text, Core Graphics, Metal, Process, and native UI types remain outside the Core target.
- No product Swift source, generated product table, release package, or product acceptance evidence is created by this plan.
- Product implementation not started, release acceptance not passed, remains the required status after this plan finishes.
- Plan audit states are limited to `planned`, `mapped`, and `structurally-verified`.
- The plan manifest references the contract by path and revision ID, never by contract hash; the adoption record is the only object that binds exact contract and plan hashes, so the hash graph is acyclic.
- G5-R adoption requires zero verifier failures and zero unresolved adversarial findings.
- Every commit stages only the paths named by its task.
- No remote push occurs in this plan.

## File and responsibility map

- `docs/implementation-phases/history/g4-r-draft/`: immutable copy of the 24 current G4-R planning files.
- `docs/implementation-phases/history/g4-r-draft/SHA256SUMS`: stable hashes for those 24 files.
- `docs/implementation-phases/README.md`: non-normative index pointing to history and the adopted G5-R plan.
- `docs/contracts/monaco-editor-0.56.0/g5-r/README.md`: G5-R authority order, status, and verification entry point.
- `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-inherited-artifacts.json`: exact parent archive path/hash proof.
- `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-qualification-environment-manifest.json`: pinned local qualification and comparator provenance.
- `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-authoritative-manifest.json`: complete G5-R product and acceptance contract.
- `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/global-g5r-authoritative-contract.html`: human companion to the machine contract.
- `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-schema.json`: exact schema for the authoritative plan manifest.
- `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`: task graph, ownership rows, commands, evidence, and document hashes.
- `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/*.mjs`: focused plan validation units.
- `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/*.test.mjs`: positive and negative verifier tests.
- `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/*.json`: adversarial malformed-plan fixtures with exact expected finding IDs.
- `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs`: plan-verifier CLI.
- `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/00-master-plan.md`: execution entry point and full cross-reference matrices.
- `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-00-*.md` through `phase-09-*.md`: reviewer-sized product implementation tasks.
- `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/plan-audit.json`: machine structural-verification result.
- `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/adversarial-plan-review.md`: three-round human adversarial record.
- `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-audit.mjs`: global contract and plan audit.
- `docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs`: archive hash, adoption, global audit, and plan audit entry point.
- `docs/contracts/monaco-editor-0.56.0/g5-r/adoption-record.json`: final selector for exact contract and plan hashes.
- `docs/contracts/monaco-editor-0.56.0/g5-r/SHA256SUMS`: final archive path and byte index.

## Task dependency graph

| Task | Direct dependencies |
|---:|---|
| 1 | none |
| 2 | 1 |
| 3 | 2 |
| 4 | 3 |
| 5 | 4 |
| 6 | 5 |
| 7 | 5 |
| 8 | 5 |
| 9 | 6, 7, 8 |
| 10 | 9 |
| 11 | 10 |
| 12 | 11 |
| 13 | 12 |
| 14 | 13 |
| 15 | 14 |
| 16 | 15 |
| 17 | 16 |
| 18 | 17 |
| 19 | 18 |
| 20 | 19 |
| 21 | 20 |
| 22 | 21 |
| 23 | 22 |
| 24 | 23 |
| 25 | 24 |
| 26 | 25 |

---

### Task 1: Preserve the current G4-R implementation-plan draft

**Files:**
- Create: `docs/implementation-phases/history/g4-r-draft/` with the current 24 Markdown files
- Create: `docs/implementation-phases/history/g4-r-draft/SHA256SUMS`
- Modify: `docs/implementation-phases/README.md`

**Interfaces:**
- Consumes: the current 13 root Markdown files and 11 files under `docs/implementation-phases/verification/`
- Produces: a 24-row checksum index whose own SHA-256 is `7e01ec83c05496f1a35810f476372ee43c3fb2751f6510ef47ee65e1a362a0b7`

- [ ] **Step 1: Run the missing-history red check**

Run: `test -f docs/implementation-phases/history/g4-r-draft/SHA256SUMS`

Expected: exit 1 because the immutable history snapshot does not exist.

- [ ] **Step 2: Copy the exact historical file set**

Run:

```bash
mkdir -p docs/implementation-phases/history/g4-r-draft/verification
cp docs/implementation-phases/*.md docs/implementation-phases/history/g4-r-draft/
cp docs/implementation-phases/verification/*.md docs/implementation-phases/history/g4-r-draft/verification/
```

Expected: 24 copied Markdown files; no source file changes.

- [ ] **Step 3: Generate and verify the stable checksum index**

Run:

```bash
cd docs/implementation-phases/history/g4-r-draft
find . -type f -name '*.md' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > SHA256SUMS
test "$(wc -l < SHA256SUMS | tr -d ' ')" = 24
test "$(shasum -a 256 SHA256SUMS | awk '{print $1}')" = 7e01ec83c05496f1a35810f476372ee43c3fb2751f6510ef47ee65e1a362a0b7
shasum -a 256 -c SHA256SUMS
```

Expected: 24 `OK` rows and both equality checks exit 0.

- [ ] **Step 4: Replace the root README with an authority index**

After the 24/24 history check passes, remove the original root copies with these exact paths:

```bash
rm docs/implementation-phases/00-master-plan.md \
  docs/implementation-phases/determinism-resolution.md \
  docs/implementation-phases/phase-00-scaffold-harness.md \
  docs/implementation-phases/phase-01-base-model.md \
  docs/implementation-phases/phase-02-model-semantics.md \
  docs/implementation-phases/phase-03-editorcore-layout-render.md \
  docs/implementation-phases/phase-04-input-ime-transfer-a11y.md \
  docs/implementation-phases/phase-05-commands-options-theme-l10n-features.md \
  docs/implementation-phases/phase-06-provider-lsp-snippet-markdown.md \
  docs/implementation-phases/phase-07-diff-services-host-resources-sourceclosure.md \
  docs/implementation-phases/phase-08-correctness-performance-acceptance.md \
  docs/implementation-phases/phase-09-distribution-license-candidates-release.md
rm docs/implementation-phases/verification/phase-00-verification.md \
  docs/implementation-phases/verification/phase-01-verification.md \
  docs/implementation-phases/verification/phase-02-verification.md \
  docs/implementation-phases/verification/phase-03-verification.md \
  docs/implementation-phases/verification/phase-04-verification.md \
  docs/implementation-phases/verification/phase-05-verification.md \
  docs/implementation-phases/verification/phase-06-verification.md \
  docs/implementation-phases/verification/phase-07-verification.md \
  docs/implementation-phases/verification/phase-08-verification.md \
  docs/implementation-phases/verification/phase-09-verification.md \
  docs/implementation-phases/verification/whole-plan-verification.md
rmdir docs/implementation-phases/verification
```

Write an index that labels `history/g4-r-draft/` as non-normative planning history and points the current authority to `../contracts/monaco-editor-0.56.0/g5-r/implementation-plan/`. It must not claim G5-R is adopted before Task 25.

- [ ] **Step 5: Commit the preserved history**

```bash
git add -- docs/implementation-phases/README.md docs/implementation-phases/history/g4-r-draft
git commit -m "docs: preserve G4-R implementation plan history"
```

### Task 2: Create the unadopted G5-R archive skeleton

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/README.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/` with all 72 G4-R artifacts copied byte-for-byte
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-inherited-artifacts.json`

**Interfaces:**
- Consumes: G4-R artifact set and authoritative manifest hash `f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021`
- Produces: an unadopted G5-R candidate with `parentRevision: "G4-R-full-scope-final"` and 72 verified inherited hashes

- [ ] **Step 1: Run the missing-candidate red check**

Run: `test -d docs/contracts/monaco-editor-0.56.0/g5-r/artifacts`

Expected: exit 1.

- [ ] **Step 2: Copy inherited evidence bytes**

```bash
mkdir -p docs/contracts/monaco-editor-0.56.0/g5-r/artifacts
cp docs/contracts/monaco-editor-0.56.0/g4-r/artifacts/* docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/
```

- [ ] **Step 3: Write the candidate README and inherited-artifact index**

Use this index shape in `monacode-g5r-inherited-artifacts.json`:

```json
{
  "schemaVersion": 1,
  "parentRevision": "G4-R-full-scope-final",
  "parentContractSha256": "f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021",
  "inheritedArtifactCount": 72,
  "rows": [
    {
      "path": "artifacts/accessibility-a1r-native-text-contract-closure.html",
      "sha256": "6ffcae4edfd2d8d4fdcf864030c74ea3529ba7e61a30971eed4d198a05e73f4b"
    }
  ]
}
```

The implementation expands `rows` to all 72 exact path/hash pairs from `g4-r/SHA256SUMS`.

- [ ] **Step 4: Verify path and hash equality**

Run a Node one-liner that loads `monacode-g5r-inherited-artifacts.json`, checks 72 unique paths, hashes both G4-R and G5-R copies, and exits non-zero on any mismatch.

Expected: `inheritedArtifactCount=72`, `pathMismatches=0`, `hashMismatches=0`.

- [ ] **Step 5: Commit the archive skeleton**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/README.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts
git commit -m "docs: create MonaCode G5-R candidate archive"
```

### Task 3: Pin current qualification and comparator provenance

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-qualification-environment-manifest.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tools/collect-environment.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/environment.test.mjs`

**Interfaces:**
- Produces: `collectEnvironment(): Promise<QualificationObservation>` and `auditEnvironment(observation): Finding[]`
- `QualificationObservation` contains version, build, architecture, non-identifying hardware class, display slots, Chrome/V8/ICU/time-source hashes, locale, input-source IDs, and the formal `externalDisplayCountRequired: 0` predicate

- [ ] **Step 1: Write the failing environment test**

The test asserts exact `25G76`, `151.0.7922.138`, Chrome SHA `ee37661755341e9fc1babf9c20ec09d6a36e50aa8713ceb08082f8bbe2d8217d`, V8 source `00c2754b59cf5f79b323950c63b07cfb1a8377d4`, ICU data SHA `9f48c7f9c7c94d516a14870707e910ab94d75ae640ff6842c4af53276cd26ebe`, the dated 2026-08-15 design observation with one unqualified external display, the formal zero-external-display predicate, and absence of forbidden identity keys.

- [ ] **Step 2: Run the red test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/environment.test.mjs`

Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `collect-environment.mjs`.

- [ ] **Step 3: Implement the collector and pinned manifest**

Use `execFileSync` with argument arrays for `sw_vers`, `xcodebuild`, `xcrun`, `swift`, `system_profiler`, and `/usr/libexec/PlistBuddy`. Hash files with `createHash('sha256')`. Fetch source provenance only from `chromium.googlesource.com`. Filter keys matching `/serial|uuid|udid|account|user/i` before serialization.

```js
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';

const text = (file, args) => execFileSync(file, args, { encoding: 'utf8' }).trim();
const sha256File = (file) => createHash('sha256').update(fs.readFileSync(file)).digest('hex');

export async function collectEnvironment() {
  return {
    macOS: text('/usr/bin/sw_vers', ['-productVersion']),
    macOSBuild: text('/usr/bin/sw_vers', ['-buildVersion']),
    chrome: text('/usr/libexec/PlistBuddy', [
      '-c', 'Print :CFBundleShortVersionString',
      '/Applications/Google Chrome.app/Contents/Info.plist'
    ]),
    chromeBinarySha256: sha256File('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'),
    externalDisplayCountRequired: 0
  };
}

function privacyViolations(value, path = '$') {
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => privacyViolations(item, `${path}[${index}]`));
  }
  if (value !== null && typeof value === 'object') {
    return Object.entries(value).flatMap(([key, item]) => {
      const own = /serial|uuid|udid|account|user/i.test(key) ? [`${path}.${key}`] : [];
      return own.concat(privacyViolations(item, `${path}.${key}`));
    });
  }
  if (typeof value === 'string' && /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i.test(value)) {
    return [path];
  }
  return [];
}

export function auditEnvironment(observation) {
  return privacyViolations(observation).map((path) => ({
    id: 'PLAN_ENVIRONMENT_PRIVACY',
    subject: path,
    message: 'forbidden persistent environment identity'
  }));
}
```

- [ ] **Step 4: Run the green test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/environment.test.mjs`

Expected: PASS with the dated design observation preserved, the live display count reported separately, and `externalDisplayCountRequired=0`. A later live display change does not rewrite the dated observation.

- [ ] **Step 5: Commit environment provenance**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-qualification-environment-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tools/collect-environment.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/environment.test.mjs
git commit -m "docs: pin G5-R qualification environment"
```

### Task 4: Author the G5-R authoritative contract candidate

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-authoritative-manifest.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/global-g5r-authoritative-contract.html`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tools/compare-g4-g5-scope.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/scope-delta.test.mjs`

**Interfaces:**
- Produces: `normalizeAuthorityRows(value)`, `diffLeaves(left, right)`, `isPermittedPointer(pointer, permitted)`, and `compareFrozenScope(g4, g5): Finding[]`
- Permitted deltas: revision identity, qualification environment, Chrome/V8 authority rows, runtime-qualified-environment text, implementation-plan normative domain, plan machine artifact, plan verification tools, and plan-governance closure
- Forbidden deltas: every product surface count, feature disposition, cut, native replacement, architecture rule, host rule, correctness gate, performance workload, statistical threshold, and delivery-scope item

- [ ] **Step 1: Write and run the missing-contract red test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/scope-delta.test.mjs`

Expected: FAIL because `monacode-g5r-authoritative-manifest.json` does not exist.

- [ ] **Step 2: Implement leaf-level frozen-scope comparison**

Normalize `authorityArtifacts` by `id`, recursively compare JSON leaves, and accept only explicit JSON-pointer prefixes. Return finding ID `G5_FORBIDDEN_SCOPE_DELTA` for every other difference.

```js
export function compareFrozenScope(g4, g5) {
  const permitted = new Set([
    '/identity',
    '/currentLocalEnvironment',
    '/validationScope/runtimeQualifiedEnvironment',
    '/validationScope/claimsExcludedFromThisReleaseVerdict',
    '/authorityArtifacts/chrome-m0-m1-runtime/version',
    '/authorityArtifacts/chrome-m0-m1-runtime/v8',
    '/authorityArtifacts/chrome-m0-m1-runtime/chromiumTagCommit',
    '/authorityArtifacts/chrome-m0-m1-runtime/v8SourceCommit',
    '/authorityArtifacts/chrome-m0-m1-runtime/binarySha256',
    '/normativeDomains/implementationPlan',
    '/machineArtifacts/implementationPlan',
    '/verificationTools/planVerifier',
    '/designClosure/planGovernance'
  ]);
  return diffLeaves(normalizeAuthorityRows(g4), normalizeAuthorityRows(g5))
    .filter((row) => !isPermittedPointer(row.pointer, permitted))
    .map((row) => ({
      id: 'G5_FORBIDDEN_SCOPE_DELTA',
      subject: row.pointer,
      message: `frozen value changed from ${JSON.stringify(row.left)} to ${JSON.stringify(row.right)}`
    }));
}
```

- [ ] **Step 3: Write the complete machine contract and human companion**

Copy all frozen values from G4-R. Set G5 identity and environment values exactly. Add the plan schema, plan manifest, plan verifier, plan audit, and adversarial review paths to the authority graph. Candidate-only selected-hash fields use JSON `null`, which the candidate schema permits and the adopted schema rejects. Keep implementation and release status at `not-started` and `not-passed`.

- [ ] **Step 4: Run the green scope test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/scope-delta.test.mjs`

Expected: PASS with `forbiddenScopeDeltas=0` and an exact permitted-delta report.

- [ ] **Step 5: Commit the G5 contract candidate**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-authoritative-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/global-g5r-authoritative-contract.html \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tools/compare-g4-g5-scope.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/scope-delta.test.mjs
git commit -m "docs: define MonaCode G5-R contract candidate"
```

### Task 5: Define canonical JSON and the plan-manifest schema

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-schema.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/canonical-json.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/findings.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/schema.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/schema.test.mjs`

**Interfaces:**
- Produces: `canonicalJSONString(value): string`, `recordSha256(value): string`, `finding(id, subject, message): Finding`, `compareFindings(left, right): number`, and `validatePlanSchema(value): Finding[]`
- `Finding` is `{ id: string, subject: string, message: string }`
- Task records require `id`, `phase`, `title`, `platformScope`, `dependencies`, `contractRefs`, `ownership`, `files`, `interfaces`, `red`, `implementation`, `green`, `evidence`, `completion`, and `commitBoundary`
- `files` is `{ productTarget: string | null, create: string[], modify: string[], test: string[] }`
- `interfaces` is `{ consumes: string[], produces: string[] }`
- `red` and `green` are non-empty arrays of `{ run: string, expectedExit: number, expectedOutputIncludes: string[] }`
- `implementation` is `{ operations: string[] }`; `evidence`, `completion`, and `commitBoundary` are non-empty string arrays

- [ ] **Step 1: Write schema rejection tests**

Test missing `interfaces`, missing expected red output, duplicate task IDs, an empty evidence list, and an unbounded commit path. Each case asserts finding ID `PLAN_SCHEMA_INVALID`.

- [ ] **Step 2: Run the red test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/schema.test.mjs`

Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `schema.mjs`.

- [ ] **Step 3: Implement canonical serialization and schema checks**

Canonical JSON sorts object keys recursively, preserves array order, emits no insignificant whitespace, and rejects non-finite numbers. The initial plan manifest contains global constraints, phase records 00-09, empty task and ownership arrays, and `adoptionState: "candidate"`.

```js
import { createHash } from 'node:crypto';

export function canonicalJSONString(value) {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new TypeError('non-finite number');
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJSONString).join(',')}]`;
  }
  const keys = Object.keys(value).sort();
  return `{${keys.map((key) => `${JSON.stringify(key)}:${canonicalJSONString(value[key])}`).join(',')}}`;
}

export function recordSha256(value) {
  return createHash('sha256').update(canonicalJSONString(value)).digest('hex');
}
```

The schema permits empty task and ownership arrays only while `adoptionState` equals `candidate`. The final manifest uses `adoptionState: "adopted"`, non-empty arrays, and zero audit findings.

- [ ] **Step 4: Run the green test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/schema.test.mjs`

Expected: PASS for the seed manifest and all rejection fixtures.

- [ ] **Step 5: Commit the plan schema**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-schema.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/canonical-json.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/findings.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/schema.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/schema.test.mjs
git commit -m "docs: add G5-R plan manifest schema"
```

### Task 6: Implement graph and Markdown-equivalence verification

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/graph.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/markdown.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/graph-markdown.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/dependency-cycle.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/markdown-drift.json`

**Interfaces:**
- Produces: `topologicalOrder(tasks): string[]`, `findClosedCycle(tasks): string[]`, `auditTaskGraph(plan): Finding[]`, and `auditMarkdown(plan, planDirectory): Finding[]`
- Stable marker grammar: prefix `<!-- monacode-plan-task:`, followed by canonical JSON containing exactly `id` and `recordSha256`, followed by ` -->`; `recordSha256` matches `/^[0-9a-f]{64}$/`

- [ ] **Step 1: Write cycle, absent-dependency, duplicate-edge, and marker-drift tests**

Expected finding IDs are `PLAN_DEPENDENCY_CYCLE`, `PLAN_DEPENDENCY_ABSENT`, `PLAN_DEPENDENCY_DUPLICATE`, and `PLAN_MARKDOWN_DRIFT`.

- [ ] **Step 2: Run the red test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/graph-markdown.test.mjs`

Expected: FAIL with missing module errors.

- [ ] **Step 3: Implement deterministic graph and marker audits**

Use Kahn topological sorting with lexicographically sorted ready IDs. On a cycle, report the exact closed path. Parse every marker, reject duplicates, and compare its hash with `recordSha256(taskRecord)`.

```js
export function auditTaskGraph(plan) {
  const byId = new Map(plan.tasks.map((task) => [task.id, task]));
  const absent = plan.tasks.flatMap((task) => task.dependencies
    .filter((dependency) => !byId.has(dependency))
    .map((dependency) => finding('PLAN_DEPENDENCY_ABSENT', task.id, dependency)));
  if (absent.length !== 0) return absent;
  const order = topologicalOrder(plan.tasks);
  if (order.length === plan.tasks.length) return [];
  return [finding('PLAN_DEPENDENCY_CYCLE', 'taskGraph', findClosedCycle(plan.tasks))];
}
```

- [ ] **Step 4: Run the green test**

Run the same test command.

Expected: PASS; each malformed fixture produces only its declared finding IDs.

- [ ] **Step 5: Commit graph and Markdown verification**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/graph.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/markdown.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/graph-markdown.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/dependency-cycle.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/markdown-drift.json
git commit -m "test: verify G5-R plan graph and Markdown"
```

### Task 7: Implement contract inventory and ownership verification

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/inventory.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/coverage.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/coverage.test.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/missing-retained-feature.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/duplicate-owner.json`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/cut-production-owner.json`

**Interfaces:**
- Produces: `buildContractInventory(artifactDirectory): ContractInventory` and `auditOwnership(inventory, plan): Finding[]`; both use `finding` from `lib/findings.mjs`
- `ContractInventory` contains exact sets for 42 normative layers, 17 inherited machine artifacts plus G5 plan artifacts, 555 public paths, 64 feature entries, commands, actions, contributions, keybindings, menus, menu items, options, colors, icons, themes, providers, host groups, C01-C10, P00-P13, and seven candidate artifacts
- Each ownership row is `{ kind: string, id: string, disposition: string, implementationOwners: string[], testOwners: string[] }`

- [ ] **Step 1: Write coverage rejection tests**

Assert `PLAN_RETAINED_IDENTITY_UNMAPPED`, `PLAN_DUPLICATE_IMPLEMENTATION_OWNER`, `PLAN_TEST_OWNER_MISSING`, and `PLAN_CUT_IDENTITY_OWNED` for exact fixtures.

- [ ] **Step 2: Run the red test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/coverage.test.mjs`

Expected: FAIL with missing module errors.

- [ ] **Step 3: Implement inventory extraction and set-equality checks**

Read only copied G5-R JSON artifacts. Preserve source IDs exactly. Require one implementation owner and at least one test owner for each retained identity, disposition-only rows for later/cut identities, and separate rows for all three `editor.colorize*` replacements.

```js
export function auditOwnership(inventory, plan) {
  const findings = [];
  for (const identity of inventory.retained) {
    const row = plan.ownership.find((candidate) => candidate.kind === identity.kind && candidate.id === identity.id);
    if (!row) findings.push(finding('PLAN_RETAINED_IDENTITY_UNMAPPED', identity.kind, identity.id));
    if (row && row.implementationOwners.length !== 1) {
      findings.push(finding('PLAN_DUPLICATE_IMPLEMENTATION_OWNER', identity.kind, identity.id));
    }
    if (row && row.testOwners.length === 0) {
      findings.push(finding('PLAN_TEST_OWNER_MISSING', identity.kind, identity.id));
    }
  }
  return findings;
}
```

- [ ] **Step 4: Run the green test**

Run the same test command.

Expected: PASS and exact rejection of all three malformed ownership fixtures.

- [ ] **Step 5: Commit coverage verification**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/inventory.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/coverage.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/coverage.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/missing-retained-feature.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/duplicate-owner.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/cut-production-owner.json
git commit -m "test: verify G5-R contract ownership coverage"
```

### Task 8: Implement boundary, candidate-order, evidence, and environment audits

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/boundaries.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/evidence.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/boundary-evidence.test.mjs`
- Create: six fixtures named `core-appkit-leak.json`, `package-graph-drift.json`, `candidate-after-consumer.json`, `false-evidence-state.json`, `stale-environment.json`, and `wrong-metal-trigger.json`

**Interfaces:**
- Produces: `auditPackageGraph(plan, contract): Finding[]`, `auditCandidateOrder(plan): Finding[]`, `auditMetalTrigger(plan): Finding[]`, `auditBoundaries(plan, contract): Finding[]`, and `auditEvidence(plan, contract): Finding[]`
- Required finding IDs: `PLAN_FORBIDDEN_CORE_IMPORT`, `PLAN_PACKAGE_GRAPH_MISMATCH`, `PLAN_CANDIDATE_ORDER`, `PLAN_FALSE_EVIDENCE_STATE`, `PLAN_ENVIRONMENT_MISMATCH`, and `PLAN_METAL_TRIGGER_SCOPE`

- [ ] **Step 1: Write all six negative tests**

Each fixture changes exactly one valid seed property and declares exactly one expected finding ID.

- [ ] **Step 2: Run the red test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/boundary-evidence.test.mjs`

Expected: FAIL with missing module errors.

- [ ] **Step 3: Implement the audits**

Enforce the three-product dependency graph, Foundation-only Core paths, finalizer-before-consumer topological order, plan-only evidence states, exact qualification fields, zero-external-display formal predicate, and a Phase 03 Metal product task reachable only from a failed renderer-owned decision gate.

```js
const forbiddenCoreTokens = [
  'import AppKit', 'import CoreText', 'import CoreGraphics', 'import Metal',
  'NSView', 'CGPoint', 'NSEvent', 'NSPasteboard', 'Process'
];

export function auditBoundaries(plan, contract) {
  const findings = auditPackageGraph(plan, contract);
  for (const task of plan.tasks.filter((candidate) => candidate.files.productTarget === 'MonaCode')) {
    const productionText = JSON.stringify({
      create: task.files.create,
      modify: task.files.modify,
      produces: task.interfaces.produces,
      operations: task.implementation.operations
    });
    for (const token of forbiddenCoreTokens) {
      if (productionText.includes(token)) {
        findings.push(finding('PLAN_FORBIDDEN_CORE_IMPORT', task.id, token));
      }
    }
  }
  return findings.concat(auditCandidateOrder(plan), auditMetalTrigger(plan));
}
```

- [ ] **Step 4: Run the green test**

Run the same test command.

Expected: PASS and six deterministic fixture rejections.

- [ ] **Step 5: Commit boundary and evidence verification**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/boundaries.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/evidence.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/boundary-evidence.test.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/core-appkit-leak.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/package-graph-drift.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/candidate-after-consumer.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/false-evidence-state.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/stale-environment.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/fixtures/wrong-metal-trigger.json
git commit -m "test: verify G5-R plan boundaries and evidence"
```

### Task 9: Assemble the plan-verifier CLI and negative-fixture runner

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/audit.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/negative-fixtures.test.mjs`

**Interfaces:**
- Produces: `auditPlan({ contract, plan, inventory, planDirectory, mode }): AuditResult`; the CLI owns file loading
- Consumes: `compareFindings` from `lib/findings.mjs` and `buildContractInventory` from `lib/inventory.mjs`
- CLI modes: full audit with no flag, `--phase 00` through `--phase 09`, and `--fixture path/to/fixture.json`
- `AuditResult` contains `status`, `findingCount`, sorted `findings`, `counts`, `coverage`, `topologicalOrder`, and `documentHashes`

- [ ] **Step 1: Write CLI failure and fixture-runner tests**

Assert exit 1 for the empty candidate manifest, JSON output on stdout, diagnostics on stderr, and exact finding equality for every fixture.

- [ ] **Step 2: Run the red test**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/negative-fixtures.test.mjs`

Expected: FAIL because `audit.mjs` and `verify-plan.mjs` are absent.

- [ ] **Step 3: Implement the composed audit and CLI**

Concatenate findings from schema, graph, Markdown, coverage, boundaries, evidence, and environment audits. Sort by `id`, then `subject`, then `message`. Exit 0 only when `findingCount === 0`.

```js
export function auditPlan(input) {
  const findings = [
    validatePlanSchema(input.plan),
    auditTaskGraph(input.plan),
    auditMarkdown(input.plan, input.planDirectory),
    auditOwnership(input.inventory, input.plan),
    auditBoundaries(input.plan, input.contract),
    auditEvidence(input.plan, input.contract)
  ].flat().sort(compareFindings);
  return {
    status: findings.length === 0 ? 'pass' : 'fail',
    findingCount: findings.length,
    findings
  };
}
```

- [ ] **Step 4: Run all verifier tests**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/*.test.mjs`

Expected: all tests pass and every negative fixture is rejected.

- [ ] **Step 5: Commit the verifier CLI**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/lib/audit.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/negative-fixtures.test.mjs
git commit -m "test: add G5-R implementation plan verifier"
```

### Task 10: Author the master plan and Phase 00

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/README.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/00-master-plan.md`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-00-scaffold-harness.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Phase 00 produces the exact three-product SwiftPM graph, test and executable target mapping, provenance locks, scope probes, environment infrastructure, differential harness, statistical harness, font/cold/display controls, and `QEnvironmentID` preflight
- Every task marker hashes its complete task record

- [ ] **Step 1: Run the missing-phase red check**

Run: `node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs --phase 00`

Expected: exit 1 with `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add reviewer-sized Phase 00 task records**

Split package graph, forbidden imports, provenance, scope probes, clocks, entropy, locale, differential harness, performance statistics, font/cold/display enforcement, environment collection, and integration into separate task records. Every record includes exact file paths, interfaces, red command/output, minimal implementation action, green command/output, evidence path, and commit path list.

- [ ] **Step 3: Write matching Markdown and stable markers**

The master plan includes full matrices for 42 layers, machine artifacts, C01-C10, P00-P13, seven candidates, phase dependencies, module ownership, and evidence directories.

- [ ] **Step 4: Run the Phase 00 green check**

Run the same verifier command.

Expected: exit 0 with `phase=00`, `schemaFailures=0`, `markerFailures=0`, and `dependencyFailures=0`.

- [ ] **Step 5: Commit Phase 00**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/README.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/00-master-plan.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-00-scaffold-harness.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 00"
```

### Task 11: Author Phase 01 base model and transaction truth

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-01-base-model.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns raw UTF-16 values, URI, events, cancellation, Piece Tree, all 70 retained model members, transaction gateway, reconciliation, large-model state, and process/editor lifetime scaffolding

- [ ] **Step 1: Run `verify-plan.mjs --phase 01`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add independent task records for each Phase 01 interface boundary**

Use exact Swift signatures for positions, ranges, selections, URI components, emitter/disposable/cancellation, Piece Tree snapshots, model mutations, version tickets, reconciliation outcomes, and lifetime registries. Map all B1-R, M1-R/M1-R2, A+/A+-base/R1, and H2-R identities.

- [ ] **Step 3: Write the phase document and markers**

Each task uses raw `UInt16` fixtures, isolated-surrogate vectors, Monaco comparator commands, expected red diagnostics, focused green commands, and exact evidence paths.

- [ ] **Step 4: Run the Phase 01 green check**

Expected: exit 0 with no schema, graph, or marker findings.

- [ ] **Step 5: Commit Phase 01**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-01-base-model.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 01"
```

### Task 12: Author Phase 02 model semantics and environment-sensitive behavior

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-02-model-semantics.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns undo/redo, decorations, word/grapheme/search, RegExp parser/compiler, six Unicode profiles, ten consumer profiles, Test262 vectors, case/collation/normalization, finite ECMAScript intrinsics, `MonaRegExpUnicodeManifest`, and `MonaEnvironmentManifest`

- [ ] **Step 1: Run `verify-plan.mjs --phase 02`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add Phase 02 records and explicit producer/finalizer distinctions**

Each environment-sensitive occurrence receives an ownership row. Static candidate manifests are marked provisional here and finalizable only after their last source consumer closes.

- [ ] **Step 3: Write the phase document and markers**

Include exact Chrome comparator commands, Test262 counts, Unicode table hashes, T-1/T/T+1 cases, expected failure strings, and green evidence outputs.

- [ ] **Step 4: Run the Phase 02 green check**

Expected: exit 0 with no local findings.

- [ ] **Step 5: Commit Phase 02**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-02-model-semantics.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 02"
```

### Task 13: Author Phase 03 projection, layout, and rendering

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-03-projection-layout-rendering.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns ViewGraph, vertical indexes, Core Text shaping and geometry, immutable `LineLayoutRecord`, seven dependency stamp domains, scroll truth, Core Graphics tiles, geometry barrier, failed-line behavior, renderer metrics, the renderer decision gate, conditional Metal implementation, and final renderer parity

- [ ] **Step 1: Run `verify-plan.mjs --phase 03`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add one task per independently rejectable geometry/rendering boundary**

The stamp task defines `ProjectionStamp`, `VerticalStamp`, `ScrollDimensionStamp`, `GeometryStamp`, `PaintStamp`, `SurfaceStamp`, and `FrameStamp` without contradictory six-domain prose. After the complete correct Core Graphics renderer exists, the renderer-owned gate records exactly one branch: `not-triggered-and-absent`, or `triggered-and-required`. The second branch implements Metal and completes Core Graphics/Metal parity before Phase 03 closes. No later phase creates renderer source.

- [ ] **Step 3: Write exact red/green geometry and renderer commands**

Cover isolated surrogates, bidi, fallback fonts, color glyphs, folding, injected text, viewport hot-path operation counters, failed Core Text records, scale and subpixel cells, renderer-owned trigger metrics, and C03/C08 Core Graphics or Core Graphics-plus-Metal evidence.

- [ ] **Step 4: Run the Phase 03 green check**

Expected: exit 0 with no local findings, exactly one renderer branch, and no product task after Phase 03 that creates Metal source.

- [ ] **Step 5: Commit Phase 03**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-03-projection-layout-rendering.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 03"
```

### Task 14: Author Phase 04 input, transfer, accessibility, and editor embedding

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-04-input-transfer-accessibility.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns key events, chords, `NSTextInputClient`, composition arbitration, multi-cursor input, pointer/scroll/menu, public event control, pasteboard, drag/drop, Services, native text accessibility, widget/focus/announcement contracts, `MonaCodeEditorView`, `MonaCodeEditor`, and `MonaSwiftUIEditorController`

- [ ] **Step 1: Run `verify-plan.mjs --phase 04`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add Core-semantic and AppKit-projection tasks separately**

No task under `Sources/MonaCode/` names `NSView`, `CGPoint`, `NSEvent`, `NSRange`, `NSPasteboard`, or an accessibility selector. AppKit tasks consume Core semantic protocols and values through exact interfaces.

- [ ] **Step 3: Write exact red/green native behavior commands**

Include ABC and Pinyin IME matrices, marked-text barriers, copy/cut/paste/drop, VoiceOver selectors, raw UTF-16 AX preservation, focus modes, announcements, and SwiftUI lifecycle-only tests.

- [ ] **Step 4: Run the Phase 04 green check**

Expected: exit 0 with no local findings.

- [ ] **Step 5: Commit Phase 04**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-04-input-transfer-accessibility.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 04"
```

### Task 15: Author Phase 05 public declarations, registries, options, and presentation data

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-05-public-surface-features.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns 555 declaration paths, command/action/contribution/keybinding/menu registries, 174 options, theme/token/icon registries, localization profiles, retained feature entry points, provider execution, and `MonaNativeDeclarationManifest` producer definition

- [ ] **Step 1: Run `verify-plan.mjs --phase 05`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Generate explicit identity rows from the copied machine artifacts**

Populate individual ownership rows for every declaration, command, action, contribution, keybinding, menu, menu item, option, color, icon, theme, localization profile, and feature. The generator preserves IDs and dispositions exactly and rejects an ownership selector that expands to zero identities.

- [ ] **Step 3: Split implementation tasks by registry or feature boundary**

All 62 retained macOS feature IDs appear verbatim. `editor.colorize`, `editor.colorizeElement`, and `editor.colorizeModelLine` each receive distinct native-replacement interfaces, tests, and ownership rows. `MonaNativeDeclarationManifest` remains provisional until Phase 08 finalization.

- [ ] **Step 4: Run the Phase 05 green check**

Expected: exit 0 with `retainedFeatureIds=62`, `missingRetainedFeatureIds=0`, `nativeColorizeReplacements=3`, and no local findings.

- [ ] **Step 5: Commit Phase 05**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-05-public-surface-features.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 05"
```

### Task 16: Author Phase 06 provider, LSP, snippet, and Markdown infrastructure

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-06-language-lsp-snippet-markdown.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns byte transport, framing, JSON-RPC encoding, LSP session state, 25 LSP-backed and five direct-only providers, all 30 provider registries, plain-text fallback, snippet grammar/session/variables, and native Markdown semantic presentation

- [ ] **Step 1: Run `verify-plan.mjs --phase 06`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add transport-neutral Core and host-adapter records**

`MonaMessageTransport` owns bytes only. `Process` appears only in a macOS host adapter. No built-in language implementation, grammar pack, snippet catalog, LSP server, JavaScript runtime, or ICU runtime enters production.

- [ ] **Step 3: Write exact protocol, fallback, snippet, and Markdown red/green commands**

Cover frame fragmentation, malformed headers, JSON directionality, cancellation, dynamic registration, versionless diagnostics, UTF-16 positions, all provider dispositions, snippet random/UUID ordering, and hostile Markdown inputs.

- [ ] **Step 4: Run the Phase 06 green check**

Expected: exit 0 with no local findings.

- [ ] **Step 5: Commit Phase 06**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-06-language-lsp-snippet-markdown.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 06"
```

### Task 17: Author Phase 07 diff, services, host, resources, and final public API closure

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-07-diff-services-host-source-closure.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns legacy/advanced diff, standalone services, dialogs, seven host groups, ten concrete host types, WorkspaceEdit, cache registry, source closure, `MonaDiffEditorView`, `MonaMultiDiffEditorView`, two remaining SwiftUI wrappers, and sample-host activation

- [ ] **Step 1: Run `verify-plan.mjs --phase 07`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add diff, service, host, resource, and public-view records**

Package dependencies are fixed in Phase 00 and only source usage activates here. Public API closure is a named terminal task that depends on every public type producer.

- [ ] **Step 3: Add candidate ordering edges**

`MonaNativeDeclarationManifest`, `MonaSourceClosureManifest`, and `MonaCacheManifest` finalizers depend on public API closure and all relevant producers. No C/P task precedes these finalizers.

- [ ] **Step 4: Run the Phase 07 green check**

Expected: exit 0 with no local findings and no public declaration added after the closure task.

- [ ] **Step 5: Commit Phase 07**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-07-diff-services-host-source-closure.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 07"
```

### Task 18: Author Phase 08 release-candidate and distribution construction

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-08-release-candidate-distribution.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns release builds, three-product and non-product target scans, license notices, final static candidate regeneration, `MonaDistributionManifest`, and six-static-candidate exact-set validation

- [ ] **Step 1: Run `verify-plan.mjs --phase 08`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add forward-only candidate tasks**

The release package and notices precede `MonaDistributionManifest`. All five earlier static manifests are regenerated after their final producers and include the renderer source set frozen in Phase 03. A six-static-candidate validator completes before Phase 09 captures run-specific `QEnvironmentID`.

- [ ] **Step 3: Write exact release, dependency, symbol, resource, and license scan commands**

Every expected output states exact product/target counts, prohibited linked runtime classes, artifact hashes, attribution profiles, and failure identifiers.

- [ ] **Step 4: Run the Phase 08 green check**

Expected: exit 0 with no local findings and `candidateOrderFailures=0`.

- [ ] **Step 5: Commit Phase 08**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-08-release-candidate-distribution.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 08"
```

### Task 19: Author Phase 09 acceptance and final release verdict

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-09-acceptance-release-verdict.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`

**Interfaces:**
- Owns per-run `QEnvironmentID`, seven-candidate joining, C01-C10, P00-P13, lifecycle, soak, sanitizers, failure injection, complexity, validation of the frozen Phase 03 renderer decision, and final release verdict

- [ ] **Step 1: Run `verify-plan.mjs --phase 09`**

Expected: `PLAN_PHASE_DOCUMENT_MISSING`.

- [ ] **Step 2: Add environment and correctness records**

The first task rejects any run that is not exact `25G76` and `.138`, has an external display, lacks required input sources or fonts, or contains forbidden identity fields. C01-C10 consume the completed distribution candidate and all seven joined candidate artifacts.

- [ ] **Step 3: Add performance, cross-cutting, renderer-decision validation, and verdict records**

Every P workload expands to M0/M1 and 60/120 Hz cells with exact sample and bootstrap rules. Phase 09 validates the already recorded renderer branch and never adds product source. The verdict task is last in topological order and depends on every C/P and cross-cutting result.

- [ ] **Step 4: Run the Phase 09 green check**

Expected: exit 0 with no local findings, no backward edge, and release verdict last.

- [ ] **Step 5: Commit Phase 09**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/phase-09-acceptance-release-verdict.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json
git commit -m "docs: plan MonaCode G5-R phase 09"
```

### Task 20: Run the complete machine plan audit

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/plan-audit.json`

**Interfaces:**
- Consumes: complete contract, plan manifest, phase documents, negative fixtures, and history checksum index
- Produces: a machine audit with `status: "pass"`, `findingCount: 0`, full counts, topological order, ownership totals, and document hashes

- [ ] **Step 1: Run all negative tests**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/*.test.mjs`

Expected: all tests pass; every malformed fixture is rejected with its exact declared finding IDs.

- [ ] **Step 2: Run the full plan audit**

Run: `node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs`

Expected: exit 0 with `status="pass"` and `findingCount=0`. A non-zero exit is a concrete defect and blocks Step 4.

- [ ] **Step 3: Assert the canonical plan needs no correction**

Confirm the Step 2 result contains an empty `findings` array. A non-empty array stops this task and requires a new explicit correction task with its own files, red/green commands, and commit boundary.

- [ ] **Step 4: Persist and revalidate the audit**

Run: `node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs > docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/plan-audit.json`

Expected: parsed JSON with `status="pass"` and `findingCount=0`.

- [ ] **Step 5: Commit the machine audit**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/plan-audit.json
git commit -m "test: audit complete G5-R implementation plan"
```

### Task 21: Adversarial review round 1 — graph, identity, and phase-order attacks

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/adversarial-plan-review.md`

**Interfaces:**
- Produces review rows with `attackId`, input, invariant, command, expected rejection, observed result, disposition, changed paths, and verification commit

- [ ] **Step 1: Attack dependency ordering**

Inject, in temporary copies only, the former `8.2 -> 9.3 -> 9.1 -> 8.9 -> 8.2` cycle, an absent task dependency, a duplicate edge, acceptance before distribution, and manifest finalization before API closure.

- [ ] **Step 2: Attack identity coverage**

Remove one retained feature, each `editor.colorize*` row in separate runs, one command, one public path, one keybinding, one C gate, one P workload, and one candidate artifact. Duplicate one implementation owner and assign one cut identity to production.

- [ ] **Step 3: Record exact results**

Every mutation must be rejected by the declared finding ID. A missed mutation becomes an unresolved finding and blocks progression.

- [ ] **Step 4: Enforce the round 1 blocking condition**

Expected: round 1 reports `unresolvedFindings=0`; the canonical plan audit remains pass. A missed attack stops execution and requires a new explicit correction task before round 1 is rerun.

- [ ] **Step 5: Commit round 1 evidence**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/adversarial-plan-review.md
git commit -m "test: adversarially review G5-R plan graph and coverage"
```

### Task 22: Adversarial review round 2 — module, package, and behavior-boundary attacks

**Files:**
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/adversarial-plan-review.md`

**Interfaces:**
- Extends the same review record with round 2 attack rows

- [ ] **Step 1: Attack module and package boundaries**

Inject `NSView`, `CGPoint`, `Process`, Core Text, Core Graphics, and Metal into Core task files; remove the direct `MonaCode` dependency from `MonaCodeSwiftUI`; drift non-product target names; break the fixture resource path; and delay the sample-host dependency declaration.

- [ ] **Step 2: Attack frozen product decisions**

Add a bundled language implementation, LSP server, JavaScript engine, ICU runtime, WebView, TextKit backend, eager Metal task, persistence backend, telemetry UI, or relaxed performance threshold in temporary copies.

- [ ] **Step 3: Record exact results and enforce the blocking condition**

Every injected change must be rejected. Record the exact finding ID and observed non-zero exit. A missed attack stops execution and requires a new explicit correction task before round 2 is rerun.

- [ ] **Step 4: Rerun the full test and plan suites**

Expected: all tests pass, canonical audit pass, and round 2 `unresolvedFindings=0`.

- [ ] **Step 5: Commit round 2 evidence**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/adversarial-plan-review.md
git commit -m "test: adversarially review G5-R plan boundaries"
```

### Task 23: Adversarial review round 3 — evidence, environment, and executability attacks

**Files:**
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/adversarial-plan-review.md`

**Interfaces:**
- Completes the review with a final summary containing `rounds: 3`, `attacks`, `detected`, `missed: 0`, and `unresolvedFindings: 0`

- [ ] **Step 1: Attack evidence truthfulness and environment identity**

Change a plan state to `implemented`, reuse a plan-review path as acceptance evidence, remove an expected red result, remove a green command, insert a forbidden UUID key, restore `25G72` or Chrome `.109`, allow an external display, and remove one required refresh cell.

- [ ] **Step 2: Attack task executability**

Remove an interface signature, use a nonexistent source file, reference an undefined type, give a commit boundary broader than task files, create Markdown/manifest hash drift, and replace an exact command with prose.

- [ ] **Step 3: Record exact results and enforce the blocking condition**

Every mutation must fail. A missed attack stops execution and requires a new explicit correction task that adds the permanent fixture and repairs the verifier before round 3 is rerun.

- [ ] **Step 4: Run the complete verification set**

Run:

```bash
node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/*.test.mjs
node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs
```

Expected: tests pass; plan output has `status="pass"`, `findingCount=0`; review summary has `missed=0`, `unresolvedFindings=0`.

- [ ] **Step 5: Commit round 3 evidence**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verification/adversarial-plan-review.md
git commit -m "test: adversarially verify G5-R plan executability"
```

### Task 24: Implement the global G5-R audit and archive verifier

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-audit.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/archive-verifier.test.mjs`

**Interfaces:**
- Global audit produces `status`, `failureCount`, `unresolvedScopeDecisions`, `unresolvedPlanFindings`, `contractSha256`, `planSha256`, inherited counts, coverage counts, and environment identity
- Archive verifier validates every indexed artifact and plan file, spawns both audits, and compares their outputs with the adoption record
- CLI modes: `--candidate` validates the complete archive without an adoption record; the default mode requires an adopted record
- Private verifier helpers are `verifyChecksumIndex(contractDirectory)`, `runJsonModule(modulePath)`, and `verifyAdoptionRecord(record, checksumResult, globalAudit, planAudit)`

- [ ] **Step 1: Write verifier rejection tests**

Use temporary archive copies to mutate one inherited artifact, plan document, contract hash, plan hash, adoption status, audit count, and review unresolved count. Each mutation must exit non-zero.

- [ ] **Step 2: Run the red tests**

Run: `node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/archive-verifier.test.mjs`

Expected: FAIL because audit and verifier modules are absent.

- [ ] **Step 3: Implement global audit and verifier**

Use built-in Node modules only. Never rewrite files. Emit one JSON object on success and exact stderr diagnostics on failure.

```js
const candidateMode = process.argv.includes('--candidate');
const checksumResult = verifyChecksumIndex(contractDirectory);
const globalAudit = runJsonModule(adoptionAuditPath);
const planAudit = runJsonModule(planVerifierPath);
if (!candidateMode) verifyAdoptionRecord(adoptionRecord, checksumResult, globalAudit, planAudit);
if (checksumResult.failures.length !== 0 || globalAudit.failureCount !== 0 || planAudit.findingCount !== 0) {
  process.exitCode = 1;
} else {
  process.stdout.write(`${JSON.stringify({
    status: candidateMode ? 'candidate-pass' : 'pass',
    adopted: !candidateMode,
    artifactHashesVerified: checksumResult.verified
  }, null, 2)}\n`);
}
```

- [ ] **Step 4: Run verifier tests and candidate audit**

Run:

```bash
node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/archive-verifier.test.mjs
node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs --candidate
```

Expected: mutation tests pass; candidate audit exits 0 with `status="candidate-pass"` and `adopted=false`.

- [ ] **Step 5: Commit global verification tools**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-audit.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs \
  docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/archive-verifier.test.mjs
git commit -m "test: add MonaCode G5-R global verifier"
```

### Task 25: Freeze hashes and adopt exact G5-R bytes

**Files:**
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/SHA256SUMS`
- Create: `docs/contracts/monaco-editor-0.56.0/g5-r/adoption-record.json`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/README.md`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-authoritative-manifest.json`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/global-g5r-authoritative-contract.html`
- Modify: `docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json`
- Modify: `docs/implementation-phases/README.md`

**Interfaces:**
- Adoption record selects exact contract, plan, human companion, global audit, plan audit, and adversarial review hashes
- Archive index contains every file below `artifacts/` and `implementation-plan/`, excluding generated runtime state

- [ ] **Step 1: Run the no-adoption red check**

Run: `node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs`

Expected: exit 1 with `adoption record missing` or `decision is not adopted`.

- [ ] **Step 2: Generate final document hashes and archive checksums**

Set the plan manifest to `adoptionState: "adopted"`, update every plan-document hash, and rerun the plan audit. Fill the authoritative contract's selected plan-schema and plan-manifest hashes, finalize the human companion, and then generate `SHA256SUMS` in sorted path order. The plan manifest contains no contract hash. No hashed file changes after this step.

- [ ] **Step 3: Write the adoption record**

Set `decision: "adopted"`, `adoptedOn: "2026-08-15"`, `promotedRevision: "G5-R-full-scope-final"`, exact selected hashes, zero accepted failures, zero unresolved scope decisions, and zero unresolved plan findings.

- [ ] **Step 4: Update authority indexes and run the green verifier**

Run: `node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs`

Expected: exit 0 with `status="pass"`, adopted G5-R revision, all indexed hashes verified, both audits pass, and zero unresolved findings.

- [ ] **Step 5: Commit adoption**

```bash
git add -- docs/contracts/monaco-editor-0.56.0/g5-r/SHA256SUMS \
  docs/contracts/monaco-editor-0.56.0/g5-r/adoption-record.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/README.md \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-authoritative-manifest.json \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/global-g5r-authoritative-contract.html \
  docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json \
  docs/implementation-phases/README.md
git commit -m "docs: adopt MonaCode G5-R contract and implementation plan"
```

### Task 26: Run final independent verification and record the handoff

**Files:**
- Modify: none unless a verifier exposes a concrete defect

**Interfaces:**
- Produces: a verified handoff stating contract and plan status only; it does not claim product implementation or release acceptance

- [ ] **Step 1: Verify G4-R remains intact**

Run: `node docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs`

Expected: `status="pass"`, 72 hashes verified, G4 SHA `f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021`.

- [ ] **Step 2: Verify G5-R and the full plan**

Run:

```bash
node docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs
node --test docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/tests/*.test.mjs
node docs/contracts/monaco-editor-0.56.0/g5-r/implementation-plan/verify-plan.mjs
```

Expected: all commands exit 0; plan finding count and adversarial unresolved count are zero.

- [ ] **Step 3: Verify history and repository hygiene**

Run:

```bash
cd docs/implementation-phases/history/g4-r-draft
shasum -a 256 -c SHA256SUMS
cd ../../../..
git diff --check
git status --short --branch
```

Expected: 24 `OK` rows, no whitespace errors, no unintended untracked or staged paths, and the branch contains only the planned commits.

- [ ] **Step 4: Review the final claims**

State exactly: G5-R contract and plan adopted; product implementation not started; C01-C10 and P00-P13 not executed; release acceptance not passed.

- [ ] **Step 5: Stop before product implementation or remote push**

Return the exact commit range, verification commands, counts, remaining product state, and the separate authorization boundary for plan execution.
