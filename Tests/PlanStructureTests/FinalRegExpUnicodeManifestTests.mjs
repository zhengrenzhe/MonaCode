// Tests/PlanStructureTests/FinalRegExpUnicodeManifestTests.mjs
//
// P08-T011 — Finalize MonaRegExpUnicodeManifest after all semantic consumers.
//
// This is the structural test for the MonaCode FINAL RegExp/Unicode manifest.
// It drives the Node finalizer at
// `Tools/Candidates/finalize-regexp-unicode-manifest.mjs` and the finalized
// manifest JSON artifact it emits.
//
// The finalizer regenerates ALL six distinct Unicode profiles, ten consumer
// mappings (the Monaco RegExp consumer profiles), Test262 selection,
// generator inputs, licenses, and output hashes from the FROZEN M1-R3 source
// contract (plus the P07-T011 frozen public-API closure baseline), verifies
// the frozen counts, verifies every final semantic consumer appears and no
// post-finalization product consumer exists, hashes every source artifact,
// and marks the manifest FINAL only after exact provenance reproduction
// (zero drift).
//
// The manifest is FINAL: identity.frozen = true, identity.final = true, and
// identity.provisional is absent/false. This is distinct from the M1-R3
// provisional source contract (identity.currentStatus = "product
// implementation absent; every affected gate is not-run").
//
// Contract gates (from the G6-R plan leaf P08-T011):
//
//   RED  : node --test <this file>
//          expectedExit=1, output includes "FINAL_REGEXP_UNICODE_MANIFEST"
//          (finalizer module not yet present)
//
//   GREEN: node --test <this file>
//          expectedExit=0, output includes
//          "FINAL_REGEXP_UNICODE_MANIFEST profiles=6 consumers=10
//           test262=2117 final=true drift=0"
//
// The frozen count contract (from the g6-r authoritative manifest's
// regexpUnicode block and the M1-R3 source manifest):
//   unicodeProfiles: 6
//   consumerProfiles (consumer mappings): 10
//   publicRegExpReferences: 14  (retained 11, cut 3)
//   acceptedFlags: 8
//   test262Sources: 2117  (1879 RegExp + 238 regexp literal)
//
// The finalizer must:
//   1. Regenerate six distinct Unicode profiles, ten consumer mappings,
//      Test262 selection, generator inputs, licenses, and output hashes from
//      the frozen M1-R3 source.
//   2. Verify every final semantic consumer appears and no post-finalization
//      product consumer exists.
//   3. Mark the candidate final only after exact provenance reproduction
//      (the regenerated manifest's hashes match the frozen source exactly —
//      zero drift). If drift, do not finalize (throw).
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
  'finalize-regexp-unicode-manifest.mjs'
);

// The frozen M1-R3 source manifest (the regExpUnicode contract). This is the
// source the finalizer regenerates from. Both the g5-r copy and the inherited
// g6-r/parent/g5-r copy are byte-identical (sha 19b93a5f...).
const FROZEN_SOURCE_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'monacode-m1r3-regexp-unicode-manifest.json'
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

const COMMITTED_FINAL_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p08-t011-regexp-unicode-manifest.json'
);

const EXPECTED_TOKEN = 'FINAL_REGEXP_UNICODE_MANIFEST';

// The frozen source manifest SHA-256 (with trailing LF). Recorded in the
// g4-r/g5-r/g6-r SHA256SUMS and the g4-r authoritative manifest.
const FROZEN_SOURCE_MANIFEST_SHA256 =
  '19b93a5f0dda741de6d193130b6eb46ec936a6273a35dbe31bbda8d44e46cf62';

// The frozen count contract (from the g6-r authoritative manifest's
// regexpUnicode block and the M1-R3 source manifest).
const EXPECTED_COUNTS = {
  unicodeProfiles: 6,
  consumerMappings: 10,
  publicRegExpReferences: 14,
  retainedReferences: 11,
  cutReferences: 3,
  acceptedFlags: 8,
  test262Sources: 2117,
  test262RegexpFiles: 1879,
  test262RegexpLiteralFiles: 238,
};

// The six distinct Unicode profile IDs (frozen). These remain independent —
// no system Unicode, Swift Character, NSRegularExpression, ICU runtime, or
// newer UCD can replace a profile.
const EXPECTED_UNICODE_PROFILE_IDS = [
  'regexp-unicode',
  'grapheme-break',
  'rtl',
  'emoji-imprecise',
  'ambiguous-characters',
  'invisible-characters',
];

// The ten consumer mapping IDs (frozen) — the Monaco RegExp consumer
// profiles. Every semantic consumer of RegExp in the frozen product appears
// here; no post-finalization product consumer may be added.
const EXPECTED_CONSUMER_MAPPING_IDS = [
  'search',
  'word-definition',
  'indentation',
  'on-enter',
  'folding-range-equal-flags',
  'folding-range-unequal-flags',
  'fold-all-regions',
  'section-headers',
  'linked-editing',
  'inline-accept-next-word',
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

// Recursively collect every string-valued SHA-256 field in a parsed M1-R3
// manifest (keys whose name ends with "Sha256" or "sha256" plus the nested
// inputSha256 / inputsSha256 / tableSha256 / etc. maps). Used to prove that
// the finalizer preserved every output hash from the frozen source (zero
// drift across the full provenance).
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

test('final-regexp-unicode-manifest: regenerated from frozen M1-R3 source, counts verified, zero drift, marked final', async () => {
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
  const tmp = mkdtempSync(join(tmpdir(), 'frum-'));
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

  // ---- Six distinct Unicode profiles ----
  const unicodeProfiles = manifestObj.unicodeProfiles || [];
  assert.equal(
    unicodeProfiles.length,
    EXPECTED_COUNTS.unicodeProfiles,
    `unicodeProfiles must be ${EXPECTED_COUNTS.unicodeProfiles} (got ${unicodeProfiles.length})`
  );
  const unicodeIds = unicodeProfiles.map((p) => p.id);
  for (const id of EXPECTED_UNICODE_PROFILE_IDS) {
    assert.ok(
      unicodeIds.includes(id),
      `unicode profile ${id} must appear in the final manifest (got ${JSON.stringify(unicodeIds)})`
    );
  }

  // ---- Ten consumer mappings ----
  const consumerMappings = manifestObj.consumerMappings || [];
  assert.equal(
    consumerMappings.length,
    EXPECTED_COUNTS.consumerMappings,
    `consumerMappings must be ${EXPECTED_COUNTS.consumerMappings} (got ${consumerMappings.length})`
  );
  const consumerIds = consumerMappings.map((p) => p.id);
  for (const id of EXPECTED_CONSUMER_MAPPING_IDS) {
    assert.ok(
      consumerIds.includes(id),
      `consumer mapping ${id} must appear in the final manifest (got ${JSON.stringify(consumerIds)})`
    );
  }

  // ---- Every final semantic consumer appears and no post-finalization
  //      product consumer exists ----
  const semanticConsumers = manifestObj.semanticConsumers || {};
  assert.equal(
    semanticConsumers.allConsumersPresent,
    true,
    'every final semantic consumer must appear (allConsumersPresent = true)'
  );
  assert.equal(
    semanticConsumers.postFinalizationProductConsumerExists,
    false,
    'no post-finalization product consumer may exist (postFinalizationProductConsumerExists = false)'
  );
  assert.equal(
    semanticConsumers.consumerIds.length,
    EXPECTED_COUNTS.consumerMappings,
    `semanticConsumers.consumerIds must list ${EXPECTED_COUNTS.consumerMappings} consumers`
  );

  // ---- Test262 selection ----
  const test262Selection = manifestObj.test262Selection || {};
  const test262Authorities = test262Selection.authorities || {};
  assert.equal(
    test262Authorities.totalSourceFileCount,
    EXPECTED_COUNTS.test262Sources,
    `test262 total source files must be ${EXPECTED_COUNTS.test262Sources}`
  );
  assert.equal(
    test262Authorities.regexpFileCount,
    EXPECTED_COUNTS.test262RegexpFiles,
    `test262 regexp file count must be ${EXPECTED_COUNTS.test262RegexpFiles}`
  );
  assert.equal(
    test262Authorities.regexpLiteralFileCount,
    EXPECTED_COUNTS.test262RegexpLiteralFiles,
    `test262 regexp literal file count must be ${EXPECTED_COUNTS.test262RegexpLiteralFiles}`
  );

  // ---- Generator inputs present (every generated profile carries its
  //      generator commit + input/generator hashes) ----
  const generatorInputs = manifestObj.generatorInputs || [];
  assert.ok(
    generatorInputs.length > 0,
    'generatorInputs block must be non-empty (every generated profile records its generator inputs)'
  );
  for (const gi of generatorInputs) {
    assert.ok(
      typeof gi.profileId === 'string' && gi.profileId.length > 0,
      `generatorInputs entry must carry a profileId (got ${JSON.stringify(gi)})`
    );
  }

  // ---- Licenses present (Monaco MIT, Unicode-3.0, Test262 BSD) ----
  const licenseContract = manifestObj.licenseContract || {};
  assert.ok(licenseContract.monaco, 'licenseContract.monaco must be present');
  assert.equal(
    licenseContract.monaco.license,
    'MIT',
    'Monaco license must be MIT'
  );
  assert.ok(
    licenseContract.unicode,
    'licenseContract.unicode must be present'
  );
  assert.equal(
    licenseContract.unicode.spdx,
    'Unicode-3.0',
    'Unicode license SPDX must be Unicode-3.0'
  );
  assert.ok(
    licenseContract.test262,
    'licenseContract.test262 must be present'
  );
  assert.equal(
    licenseContract.test262.license,
    'Test262 BSD License',
    'Test262 license must be Test262 BSD License'
  );

  // ---- Output hashes present (every output hash from the frozen source
  //      preserved in the final manifest — zero drift on outputs) ----
  const outputHashes = manifestObj.outputHashes || {};
  assert.ok(
    Object.keys(outputHashes).length > 0,
    'outputHashes block must be non-empty (every generated output hash recorded)'
  );
  // Cross-check: every SHA-256 field within the SIX regenerated categories of
  // the frozen M1-R3 source (unicodeProfiles, regexpProfiles/consumer
  // mappings, authorities.test262, regexpCorpusContract, licenseContract)
  // must appear verbatim in the final manifest — the finalizer preserved
  // every output hash with zero drift. Hashes outside these categories
  // (authorities.monaco/browser package hashes, chromeProbe,
  // implementationBoundary oracle hashes, monacoSourceFiles) are source-
  // contract context outside the P08-T011 regeneration scope.
  const frozenSource = JSON.parse(
    readFileSync(FROZEN_SOURCE_MANIFEST_PATH, 'utf8')
  );
  const regeneratedSourceCategories = {
    unicodeProfiles: frozenSource.unicodeProfiles,
    consumerMappings: frozenSource.regexpProfiles,
    test262Authorities: frozenSource.authorities.test262,
    test262CorpusContract: frozenSource.regexpCorpusContract,
    licenseContract: frozenSource.licenseContract,
  };
  const frozenHashes = collectHashFields(
    regeneratedSourceCategories,
    [],
    ''
  );
  assert.ok(
    frozenHashes.length > 0,
    'frozen M1-R3 source must carry SHA-256 fields in the regenerated categories to verify against'
  );
  // Serialize the regenerated final-manifest blocks back to a string and
  // confirm every frozen hash is reproduced verbatim.
  const finalHashBlobs = JSON.stringify({
    outputHashes,
    generatorInputs,
    licenseContract,
    unicodeProfiles,
    consumerMappings,
    test262Selection,
  });
  let reproduced = 0;
  for (const { hash } of frozenHashes) {
    if (finalHashBlobs.includes(hash)) reproduced++;
  }
  assert.equal(
    reproduced,
    frozenHashes.length,
    `every frozen SHA-256 in the regenerated categories must be reproduced ` +
      `verbatim in the final manifest (reproduced=${reproduced} of ${frozenHashes.length})`
  );

  // ---- Zero drift: the frozen source manifest file hash matches the
  //      recorded SHA-256 (exact provenance reproduction of the source) ----
  const frozenFileHash = fileSha256(FROZEN_SOURCE_MANIFEST_PATH);
  assert.equal(
    frozenFileHash,
    FROZEN_SOURCE_MANIFEST_SHA256,
    `frozen M1-R3 source manifest sha256 must be ${FROZEN_SOURCE_MANIFEST_SHA256} ` +
      `(got ${frozenFileHash}) — the source has drifted`
  );
  assert.equal(
    manifestObj.frozenBaseline.sha256,
    FROZEN_SOURCE_MANIFEST_SHA256,
    'final manifest must record the frozen source manifest sha256 (zero drift)'
  );

  // ---- Count verification: 6 / 10 / 14 / 11 / 3 / 8 / 2117 ----
  assert.equal(
    manifestObj.counts.unicodeProfiles,
    EXPECTED_COUNTS.unicodeProfiles,
    `counts.unicodeProfiles must be ${EXPECTED_COUNTS.unicodeProfiles}`
  );
  assert.equal(
    manifestObj.counts.consumerMappings,
    EXPECTED_COUNTS.consumerMappings,
    `counts.consumerMappings must be ${EXPECTED_COUNTS.consumerMappings}`
  );
  assert.equal(
    manifestObj.counts.publicRegExpReferences,
    EXPECTED_COUNTS.publicRegExpReferences,
    `counts.publicRegExpReferences must be ${EXPECTED_COUNTS.publicRegExpReferences}`
  );
  assert.equal(
    manifestObj.counts.retainedReferences,
    EXPECTED_COUNTS.retainedReferences,
    `counts.retainedReferences must be ${EXPECTED_COUNTS.retainedReferences}`
  );
  assert.equal(
    manifestObj.counts.cutReferences,
    EXPECTED_COUNTS.cutReferences,
    `counts.cutReferences must be ${EXPECTED_COUNTS.cutReferences}`
  );
  assert.equal(
    manifestObj.counts.acceptedFlags,
    EXPECTED_COUNTS.acceptedFlags,
    `counts.acceptedFlags must be ${EXPECTED_COUNTS.acceptedFlags}`
  );
  assert.equal(
    manifestObj.counts.test262Sources,
    EXPECTED_COUNTS.test262Sources,
    `counts.test262Sources must be ${EXPECTED_COUNTS.test262Sources}`
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

  console.log(
    `FINAL_REGEXP_UNICODE_MANIFEST profiles=${unicodeProfiles.length} ` +
      `consumers=${consumerMappings.length} ` +
      `test262=${test262Authorities.totalSourceFileCount} ` +
      `final=true drift=0 ` +
      `publicRefs=${manifestObj.counts.publicRegExpReferences} ` +
      `retained=${manifestObj.counts.retainedReferences} ` +
      `cut=${manifestObj.counts.cutReferences} ` +
      `flags=${manifestObj.counts.acceptedFlags} ` +
      `reproducedHashes=${reproduced}`
  );
});

// ---------------------------------------------------------------------------
// Determinism: re-running the finalizer must produce byte-identical output.
// ---------------------------------------------------------------------------

test('final-regexp-unicode-manifest: byte-identical across re-runs (deterministic)', async () => {
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

  const tmpA = mkdtempSync(join(tmpdir(), 'frum-a-'));
  const tmpB = mkdtempSync(join(tmpdir(), 'frum-b-'));
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

test('final-regexp-unicode-manifest: committed artifact exists and is up to date', async () => {
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
  const tmp = mkdtempSync(join(tmpdir(), 'frum-committed-'));
  try {
    const outPath = join(tmp, 'manifest.json');
    finalizer.finalizeManifest({ outPath });
    const fresh = readFileSync(outPath, 'utf8');
    const committed = readFileSync(committedPath, 'utf8');
    assert.equal(
      committed,
      fresh,
      'committed final manifest artifact is stale: does not match freshly finalized output. ' +
        'Re-run: /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/finalize-regexp-unicode-manifest.mjs'
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
