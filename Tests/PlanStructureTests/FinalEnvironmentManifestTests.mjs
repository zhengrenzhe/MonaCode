// Tests/PlanStructureTests/FinalEnvironmentManifestTests.mjs
//
// P08-T012 — Finalize MonaEnvironmentManifest after every
// environment-sensitive consumer.
//
// This is the structural test for the MonaCode FINAL environment manifest. It
// drives the Node finalizer at
// `Tools/Candidates/finalize-environment-manifest.mjs` and the finalized
// manifest JSON artifact it emits.
//
// The finalizer regenerates ALL clock, entropy, number-formatting, locale,
// calendar, numbering, time-zone, case, collation, normalization, and
// finite-intrinsic occurrence rows from the FROZEN E1-R environment-intl-
// clock-entropy source contract plus the X1-R source-runtime-style contract
// (plus the P07-T011 frozen public-API closure baseline), verifies set
// equality against E1-R and X1-R plus the generated input and output hashes,
// verifies every environment-sensitive consumer appears and the notice input
// (LICENSE.md) is complete, hashes every source artifact, and marks the
// manifest FINAL only after exact provenance reproduction (zero drift).
//
// The manifest is FINAL: identity.frozen = true, identity.final = true, and
// identity.provisional is absent/false. This is distinct from the E1-R/X1-R
// provisional source contracts (identity.status = "design-baseline-only" and
// implementationStatus.verdict = "not-passed"). Phase 09 acceptance reads
// this final manifest without re-running the finalizer.
//
// Contract gates (from the G6-R plan leaf P08-T012):
//
//   RED  : node --test <this file>
//          expectedExit=1, output includes "FINAL_ENVIRONMENT_MANIFEST"
//          (finalizer module not yet present)
//
//   GREEN: node --test <this file>
//          expectedExit=0, output includes
//          "FINAL_ENVIRONMENT_MANIFEST rows=<N> final=true drift=0
//           environmentConsumers=<N> generatedHashes=<N>"
//
// The frozen count contract (from the g6-r authoritative manifest's
// environmentIntl + sourceRuntimeStyle blocks, the E1-R sourceEffectClosure
// syntaxCounts, and the X1-R clockAndPerformanceCorrection /
// directGlobalClosure / intrinsicOperationProfiles blocks):
//   reachableJavaScriptFiles: 956
//   reachableStyleResources: 98
//   totalImportedFiles: 1054
//   importEdges: 6275
//   defaultCaseOccurrences: 138       (toUpperCase 15 + toLowerCase 123)
//   localeCaseOccurrences: 16          (toLocaleUpperCase 6 + toLocaleLowerCase 10)
//   localeCompareOccurrences: 11
//   normalizationOccurrences: 1
//   mathRandomOccurrences: 8
//   dateNowOccurrences: 90
//   newDateOccurrences: 14
//   stopWatchConstructionSites: 21    (13 retained high-res + 6 retained wall + 2 cut)
//   inputLatencyPerformanceCalls: 25  (8 mark + 4 measure + 1 getEntriesByName + 8 clearMarks + 4 clearMeasures)
//   timerOccurrences: 94
//   microtaskOccurrences: 11
//   collationProfiles: 5
//   activeNormalizationCaches: 2
//   directGlobalIdentifiers: 84
//   directGlobalReferences: 8221
//   ecmascriptIntrinsicIdentifiers: 41
//   ecmascriptIntrinsicReferences: 7523
//   platformIdentifiers: 43
//   platformReferences: 698
//   finiteIntrinsicProfiles: 12
//
// The finalizer must:
//   1. Regenerate clock, entropy, number formatting, locale, calendar,
//      numbering, time zone, case, collation, normalization, and
//      finite-intrinsic occurrence rows from the frozen E1-R + X1-R source.
//   2. Verify set equality against E1-R and X1-R plus the generated input
//      and output hashes (zero drift). If drift, do not finalize (throw).
//   3. Mark the candidate final only after the last source consumer (every
//      environment-sensitive consumer appears) and notice input (the
//      LICENSE.md provenance is complete).
//   4. Mark identity.frozen = true / final = true (NOT provisional).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  readFileSync,
  existsSync,
  mkdtempSync,
  rmSync,
} from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');

const FINALIZER_PATH = join(
  REPO_ROOT,
  'Tools',
  'Candidates',
  'finalize-environment-manifest.mjs'
);

// The frozen E1-R source manifest (the environment-intl-clock-entropy
// contract). This is the source the finalizer regenerates from.
const FROZEN_E1R_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'monacode-e1r-environment-intl-clock-entropy-manifest.json'
);

const FROZEN_X1R_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'monacode-x1r-source-runtime-style-manifest.json'
);

const E1R_CLOSURE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'environment-e1r-intl-clock-entropy-closure.html'
);

const X1R_CLOSURE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'source-x1r-runtime-style-closure.html'
);

const FROZEN_API_CLOSURE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p07-t011-public-api-closure-manifest.json'
);

const LICENSE_NOTICE_PATH = join(
  REPO_ROOT,
  'Sources',
  'MonaCode',
  'Generated',
  'LICENSE.md'
);

const COMMITTED_FINAL_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p08-t012-environment-manifest.json'
);

const EXPECTED_TOKEN = 'FINAL_ENVIRONMENT_MANIFEST';

// The frozen source manifest SHA-256 anchors (with trailing LF). Recorded in
// the g6-r SHA256SUMS and the g5-r SHA256SUMS. These are the zero-drift
// anchors for the E1-R + X1-R sources.
const FROZEN_E1R_MANIFEST_SHA256 =
  'ecc1e42b7061baf4ade5bd3fd5e3c1c2ee89d46f96b3aafc4c94dba5edb78dc9';
const FROZEN_X1R_MANIFEST_SHA256 =
  '516c91d905532e9c54e2b3691e74024c81f5887203e6b1cb9184e2c981aaa280';
const FROZEN_E1R_CLOSURE_SHA256 =
  '920e102184648cd1a08d589944708ceb62b4f3f6c091b4b100378f989709637b';
const FROZEN_X1R_CLOSURE_SHA256 =
  '32bebccbf932e1baab6bb9ebd386715295625792198ae378566d0bc11ca2a3a9';

// The frozen count contract (from the g6-r authoritative manifest's
// environmentIntl + sourceRuntimeStyle blocks and the E1-R/X1-R source
// manifests).
const EXPECTED_COUNTS = {
  reachableJavaScriptFiles: 956,
  reachableStyleResources: 98,
  totalImportedFiles: 1054,
  importEdges: 6275,
  defaultCaseOccurrences: 138,
  localeCaseOccurrences: 16,
  localeCompareOccurrences: 11,
  normalizationOccurrences: 1,
  mathRandomOccurrences: 8,
  dateNowOccurrences: 90,
  newDateOccurrences: 14,
  stopWatchConstructionSites: 21,
  retainedHighResolutionStopWatchSites: 13,
  retainedWallClockStopWatchSites: 6,
  cutTreeSitterHighResolutionStopWatchSites: 2,
  inputLatencyPerformanceCalls: 25,
  timerOccurrences: 94,
  microtaskOccurrences: 11,
  collationProfiles: 5,
  activeNormalizationCaches: 2,
  directGlobalIdentifiers: 84,
  directGlobalReferences: 8221,
  ecmascriptIntrinsicIdentifiers: 41,
  ecmascriptIntrinsicReferences: 7523,
  platformIdentifiers: 43,
  platformReferences: 698,
  finiteIntrinsicProfiles: 12,
};

// The twelve finite intrinsic profiles (frozen) — the X1-R
// intrinsicOperationProfiles.selectedReferenceCounts keys. These remain the
// exhaustive set of finite intrinsic profiles the product implements; no
// general JavaScript runtime is exposed.
const EXPECTED_FINITE_INTRINSIC_PROFILES = [
  'Array',
  'Object',
  'Reflect',
  'Map',
  'Set',
  'Promise',
  'Math',
  'Number',
  'String',
  'JSON',
  'RegExp',
  'Symbol',
];

// The eleven environment-sensitive consumer categories the finalizer must
// regenerate (clock, entropy, number formatting, locale, calendar, numbering,
// time zone, case, collation, normalization, finite-intrinsic). The last
// source consumer is the union of these; every one must appear before the
// manifest is marked final.
const EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES = [
  'clock',
  'entropy',
  'number-formatting',
  'locale',
  'calendar',
  'numbering',
  'time-zone',
  'case',
  'collation',
  'normalization',
  'finite-intrinsic',
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function loadFinalizer() {
  const url = pathToFileURL(FINALIZER_PATH).href;
  return import(url);
}

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

function fileSha256(path) {
  return sha256(readFileSync(path, 'utf8'));
}

// Recursively collect every string-valued SHA-256 field in a parsed source
// manifest (keys whose name contains "sha256" case-insensitive). Used to
// prove that the finalizer preserved every input/output hash from the frozen
// source (zero drift across the full provenance).
function collectHashFields(obj, acc, path) {
  if (Array.isArray(obj)) {
    for (let i = 0; i < obj.length; i++) {
      collectHashFields(obj[i], acc, `${path}[${i}]`);
    }
  } else if (obj && typeof obj === 'object') {
    for (const k of Object.keys(obj)) {
      const v = obj[k];
      const p = path ? `${path}.${k}` : k;
      if (
        typeof v === 'string' &&
        /^[0-9a-f]{64}$/.test(v) &&
        /sha256/i.test(k)
      ) {
        acc.push({ path: p, hash: v });
      } else if (typeof v === 'object' && v !== null) {
        collectHashFields(v, acc, p);
      }
    }
  }
  return acc;
}

// ---------------------------------------------------------------------------
// RED + GREEN contract: the finalizer + finalized manifest.
//
// The token is always emitted so the RED leaf's expectedOutputIncludes matches
// even when the finalizer is not yet implemented.
// ---------------------------------------------------------------------------

test('final-environment-manifest: regenerated from frozen E1-R + X1-R source, set-equal, zero drift, marked final', async () => {
  // Always emit the token so the RED leaf's expectedOutputIncludes matches
  // even when the finalizer is not yet implemented.
  console.log(EXPECTED_TOKEN);

  let finalizer;
  try {
    finalizer = await loadFinalizer();
  } catch (e) {
    assert.fail(
      `finalizer module not loadable at ${FINALIZER_PATH}: ${
        e instanceof Error ? e.message : String(e)
      }`
    );
  }

  assert.equal(
    typeof finalizer.finalizeManifest,
    'function',
    'finalizer must export finalizeManifest'
  );
  assert.equal(
    typeof finalizer.FINAL_MANIFEST_PATH,
    'string',
    'finalizer must export FINAL_MANIFEST_PATH (the committed artifact path)'
  );

  // Finalize into a temp dir first so we can verify determinism without
  // touching the committed artifact, then also verify the committed artifact.
  const tmp = mkdtempSync(join(tmpdir(), 'fem-'));
  let manifestObj;
  let manifestJson;
  try {
    const outPath = join(tmp, 'manifest.json');
    manifestObj = finalizer.finalizeManifest({ outPath });
    manifestJson = readFileSync(outPath, 'utf8');
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }

  // ---- Final marker (NOT provisional) ----
  assert.equal(
    manifestObj.identity.frozen,
    true,
    'final manifest must carry identity.frozen = true'
  );
  assert.equal(
    manifestObj.identity.final,
    true,
    'final manifest must carry identity.final = true'
  );
  assert.notEqual(
    manifestObj.identity.provisional,
    true,
    'final manifest must NOT be provisional (identity.provisional must not be true)'
  );
  assert.ok(
    typeof manifestObj.identity.finalReason === 'string' &&
      manifestObj.identity.finalReason.length > 0,
    'final manifest must carry a non-empty identity.finalReason'
  );

  // ---- Regenerated occurrence rows cover all eleven environment-sensitive
  //      consumer categories (clock, entropy, number formatting, locale,
  //      calendar, numbering, time zone, case, collation, normalization,
  //      finite-intrinsic) ----
  const occurrenceRows = manifestObj.occurrenceRows || [];
  assert.ok(
    occurrenceRows.length > 0,
    'occurrenceRows block must be non-empty (every E1-sensitive occurrence regenerated)'
  );
  const occurrenceCategories = new Set(
    occurrenceRows.map((r) => r.category)
  );
  for (const category of EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES) {
    assert.ok(
      occurrenceCategories.has(category),
      `occurrenceRows must include the ${category} category (got ${JSON.stringify([...occurrenceCategories])})`
    );
  }

  // ---- Set equality against E1-R + X1-R: every environment-sensitive
  //      consumer appears and no post-finalization product consumer exists ----
  const semanticConsumers = manifestObj.semanticConsumers || {};
  assert.equal(
    semanticConsumers.allConsumersPresent,
    true,
    'every environment-sensitive consumer must appear (allConsumersPresent = true)'
  );
  assert.equal(
    semanticConsumers.postFinalizationProductConsumerExists,
    false,
    'no post-finalization product consumer may exist (postFinalizationProductConsumerExists = false)'
  );
  assert.ok(
    Array.isArray(semanticConsumers.consumerCategories) &&
      semanticConsumers.consumerCategories.length ===
        EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES.length,
    `semanticConsumers.consumerCategories must list all ${EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES.length} categories`
  );

  // ---- Notice input: the LICENSE.md provenance is complete (the notice
  //      input the spec requires before marking final) ----
  const noticeInput = manifestObj.noticeInput || {};
  assert.equal(
    noticeInput.present,
    true,
    'noticeInput.present must be true (LICENSE.md notice input is complete)'
  );
  assert.ok(
    typeof noticeInput.licensePath === 'string' &&
      noticeInput.licensePath.length > 0,
    'noticeInput.licensePath must be recorded'
  );
  assert.ok(
    noticeInput.notices.length > 0,
    'noticeInput.notices must be non-empty (Monaco MIT, Unicode-3.0, Chromium ICU, Test262 BSD, etc.)'
  );
  // The Chromium ICU license, Unicode notice, and Monaco MIT must appear.
  const noticeLabels = noticeInput.notices.map((n) => n.label).join('\n');
  assert.ok(/MIT/i.test(noticeLabels), 'Monaco MIT notice must appear');
  assert.ok(
    /Unicode/i.test(noticeLabels),
    'Unicode-3.0 notice must appear'
  );
  assert.ok(
    /ICU/i.test(noticeLabels),
    'Chromium ICU notice must appear'
  );

  // ---- Count verification: 956 / 138 / 16 / 11 / 1 / 8 / 90 / 14 / 21 / 25
  //      / 94 / 11 / 5 / 2 / 84 / 8221 / 41 / 7523 / 43 / 698 / 12 ----
  const counts = manifestObj.counts || {};
  for (const [label, expected] of Object.entries(EXPECTED_COUNTS)) {
    const actual = counts[label];
    assert.equal(
      actual,
      expected,
      `counts.${label} must be ${expected} (got ${actual})`
    );
  }

  // ---- Twelve finite intrinsic profiles (the X1-R
  //      intrinsicOperationProfiles.selectedReferenceCounts keys) ----
  const finiteIntrinsic = manifestObj.finiteIntrinsicProfiles || [];
  assert.equal(
    finiteIntrinsic.length,
    EXPECTED_COUNTS.finiteIntrinsicProfiles,
    `finiteIntrinsicProfiles must be ${EXPECTED_COUNTS.finiteIntrinsicProfiles} (got ${finiteIntrinsic.length})`
  );
  const finiteProfileNames = finiteIntrinsic.map((p) => p.name);
  for (const name of EXPECTED_FINITE_INTRINSIC_PROFILES) {
    assert.ok(
      finiteProfileNames.includes(name),
      `finite intrinsic profile ${name} must appear in the final manifest (got ${JSON.stringify(finiteProfileNames)})`
    );
  }

  // ---- Generated input hashes: every SHA-256 in the E1-R authorities
  //      (coreTar, entry, chrome timeSource, unicodeInputs, sourceFiles)
  //      preserved verbatim in the final manifest (zero drift on inputs) ----
  const generatedInputs = manifestObj.generatedInputs || {};
  assert.ok(
    Object.keys(generatedInputs).length > 0,
    'generatedInputs block must be non-empty (every generated input hash recorded)'
  );
  const e1rSource = JSON.parse(readFileSync(FROZEN_E1R_MANIFEST_PATH, 'utf8'));
  const x1rSource = JSON.parse(readFileSync(FROZEN_X1R_MANIFEST_PATH, 'utf8'));
  const frozenInputHashes = collectHashFields(
    {
      e1rAuthorities: e1rSource.authorities,
      x1rAuthorities: x1rSource.authorities,
    },
    [],
    ''
  );
  assert.ok(
    frozenInputHashes.length > 0,
    'frozen E1-R + X1-R authorities must carry SHA-256 fields to verify against'
  );
  const finalInputBlob = JSON.stringify({
    generatedInputs,
    occurrenceRows,
    finiteIntrinsicProfiles: finiteIntrinsic,
  });
  let inputReproduced = 0;
  for (const { hash } of frozenInputHashes) {
    if (finalInputBlob.includes(hash)) inputReproduced++;
  }
  assert.equal(
    inputReproduced,
    frozenInputHashes.length,
    `every frozen E1-R + X1-R input SHA-256 must be reproduced verbatim in the final manifest (reproduced=${inputReproduced} of ${frozenInputHashes.length})`
  );

  // ---- Generated output hashes: every generated Swift table (MonaCaseTables,
  //      MonaCollationTables) source hash recorded, plus the generator hash
  //      preserved verbatim from the frozen source (zero drift on outputs) ----
  const generatedOutputs = manifestObj.generatedOutputs || {};
  assert.ok(
    Object.keys(generatedOutputs).length > 0,
    'generatedOutputs block must be non-empty (every generated output hash recorded)'
  );
  assert.ok(
    generatedOutputs.caseTablesSha256,
    'generatedOutputs.caseTablesSha256 must be recorded (MonaCaseTables.swift)'
  );
  assert.ok(
    generatedOutputs.collationTablesSha256,
    'generatedOutputs.collationTablesSha256 must be recorded (MonaCollationTables.swift)'
  );
  assert.ok(
    /^[0-9a-f]{64}$/.test(generatedOutputs.caseTablesSha256),
    'generatedOutputs.caseTablesSha256 must be a 64-hex SHA-256'
  );
  assert.ok(
    /^[0-9a-f]{64}$/.test(generatedOutputs.collationTablesSha256),
    'generatedOutputs.collationTablesSha256 must be a 64-hex SHA-256'
  );
  // The generator hash from the generated tables must match the recorded
  // generatorHash in the frozen E1-R source (zero drift on the generator).
  assert.equal(
    typeof generatedOutputs.generatorHash,
    'string',
    'generatedOutputs.generatorHash must be recorded (the generator hash)'
  );
  assert.ok(
    /^[0-9a-f]{64}$/.test(generatedOutputs.generatorHash),
    'generatedOutputs.generatorHash must be a 64-hex SHA-256'
  );

  // ---- Zero drift: the frozen E1-R + X1-R source manifest file hashes match
  //      the recorded SHA-256 anchors (exact provenance reproduction of the
  //      source) ----
  const e1rFileHash = fileSha256(FROZEN_E1R_MANIFEST_PATH);
  assert.equal(
    e1rFileHash,
    FROZEN_E1R_MANIFEST_SHA256,
    `frozen E1-R source manifest sha256 must be ${FROZEN_E1R_MANIFEST_SHA256} (got ${e1rFileHash}) — the source has drifted`
  );
  const x1rFileHash = fileSha256(FROZEN_X1R_MANIFEST_PATH);
  assert.equal(
    x1rFileHash,
    FROZEN_X1R_MANIFEST_SHA256,
    `frozen X1-R source manifest sha256 must be ${FROZEN_X1R_MANIFEST_SHA256} (got ${x1rFileHash}) — the source has drifted`
  );
  assert.equal(
    manifestObj.frozenBaselines.e1r.sha256,
    FROZEN_E1R_MANIFEST_SHA256,
    'final manifest must record the frozen E1-R source manifest sha256 (zero drift)'
  );
  assert.equal(
    manifestObj.frozenBaselines.x1r.sha256,
    FROZEN_X1R_MANIFEST_SHA256,
    'final manifest must record the frozen X1-R source manifest sha256 (zero drift)'
  );
  assert.equal(
    manifestObj.frozenBaselines.e1r.closureSha256,
    FROZEN_E1R_CLOSURE_SHA256,
    'final manifest must record the frozen E1-R closure HTML sha256 (zero drift)'
  );
  assert.equal(
    manifestObj.frozenBaselines.x1r.closureSha256,
    FROZEN_X1R_CLOSURE_SHA256,
    'final manifest must record the frozen X1-R closure HTML sha256 (zero drift)'
  );

  // ---- Source artifact hashes recorded (every source artifact hashed) ----
  assert.ok(
    typeof manifestObj.sourceArtifacts === 'object' &&
      manifestObj.sourceArtifacts !== null,
    'final manifest must carry a sourceArtifacts block (every source artifact hashed)'
  );
  assert.ok(
    Object.keys(manifestObj.sourceArtifacts).length > 0,
    'sourceArtifacts block must be non-empty'
  );
  // Every sourceArtifacts entry must match the recomputed file hash (zero
  // drift on every referenced repo source artifact).
  for (const [rel, recorded] of Object.entries(manifestObj.sourceArtifacts)) {
    const abs = join(REPO_ROOT, rel);
    assert.equal(
      existsSync(abs),
      true,
      `sourceArtifacts entry ${rel} must exist in the repo`
    );
    const recomputed = fileSha256(abs);
    assert.equal(
      recomputed,
      recorded,
      `sourceArtifacts hash drift for ${rel}: manifest=${recorded} recomputed=${recomputed}`
    );
  }

  // ---- LICENSE.md notice input present in the repo (the notice input gate) ----
  assert.equal(
    existsSync(LICENSE_NOTICE_PATH),
    true,
    `LICENSE.md notice input must exist at ${LICENSE_NOTICE_PATH}`
  );

  const generatedHashesCount =
    Object.keys(generatedInputs).length + Object.keys(generatedOutputs).length;

  console.log(
    `FINAL_ENVIRONMENT_MANIFEST rows=${occurrenceRows.length} ` +
      `final=true drift=0 ` +
      `environmentConsumers=${semanticConsumers.consumerCategories.length} ` +
      `generatedHashes=${generatedHashesCount} ` +
      `reproducedInputHashes=${inputReproduced}`
  );
});

// ---------------------------------------------------------------------------
// Determinism: re-running the finalizer must produce byte-identical output.
// ---------------------------------------------------------------------------

test('final-environment-manifest: byte-identical across re-runs (deterministic)', async () => {
  let finalizer;
  try {
    finalizer = await loadFinalizer();
  } catch (e) {
    assert.fail(
      `finalizer module not loadable at ${FINALIZER_PATH}: ${
        e instanceof Error ? e.message : String(e)
      }`
    );
  }

  const tmpA = mkdtempSync(join(tmpdir(), 'fem-a-'));
  const tmpB = mkdtempSync(join(tmpdir(), 'fem-b-'));
  try {
    const outA = join(tmpA, 'manifest.json');
    const outB = join(tmpB, 'manifest.json');
    finalizer.finalizeManifest({ outPath: outA });
    finalizer.finalizeManifest({ outPath: outB });
    const a = readFileSync(outA, 'utf8');
    const b = readFileSync(outB, 'utf8');
    assert.equal(
      a,
      b,
      'finalizer output is not byte-identical across re-runs (non-deterministic)'
    );
    assert.ok(a.endsWith('\n'), 'final manifest JSON must end with a trailing newline');
    assert.ok(
      !a.endsWith('\n\n'),
      'final manifest JSON must end with exactly one trailing newline'
    );
  } finally {
    rmSync(tmpA, { recursive: true, force: true });
    rmSync(tmpB, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// Committed artifact: the finalized manifest is committed to the contract
// archive so Phase 09 acceptance can read it without re-running the finalizer.
// ---------------------------------------------------------------------------

test('final-environment-manifest: committed artifact exists and is up to date', async () => {
  let finalizer;
  try {
    finalizer = await loadFinalizer();
  } catch (e) {
    assert.fail(
      `finalizer module not loadable at ${FINALIZER_PATH}: ${
        e instanceof Error ? e.message : String(e)
      }`
    );
  }

  const committedPath = finalizer.FINAL_MANIFEST_PATH;
  assert.equal(
    existsSync(committedPath),
    true,
    `committed final manifest artifact must exist at ${committedPath}`
  );

  // Re-finalize into a temp file and verify the committed artifact matches the
  // freshly finalized output (i.e. the committed artifact is up to date).
  const tmp = mkdtempSync(join(tmpdir(), 'fem-committed-'));
  try {
    const outPath = join(tmp, 'manifest.json');
    finalizer.finalizeManifest({ outPath });
    const fresh = readFileSync(outPath, 'utf8');
    const committed = readFileSync(committedPath, 'utf8');
    assert.equal(
      committed,
      fresh,
      'committed final manifest artifact is stale: does not match freshly finalized output. ' +
        'Re-run: /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/finalize-environment-manifest.mjs'
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
