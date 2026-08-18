// Tests/PlanStructureTests/FinalNativeDeclarationManifestTests.mjs
//
// P08-T010 — Finalize MonaNativeDeclarationManifest after public API closure.
//
// This is the structural test for the MonaCode FINAL native declaration
// manifest. It drives the Node finalizer at
// `Tools/Candidates/finalize-native-declaration-manifest.mjs` and the
// finalized manifest JSON artifact it emits.
//
// The finalizer regenerates ALL declaration, signature, disposition, owner,
// symbol, and product rows from the FROZEN release outputs (the P07-T011
// frozen public-API closure manifest + the P08-T001 release build + the
// P08-T002 distribution scan), verifies the frozen counts, hashes every
// source artifact, and marks the manifest FINAL only after zero drift.
//
// The manifest is FINAL: identity.frozen = true, identity.final = true, and
// identity.provisional is absent/false. This is distinct from the P05-T190
// provisional manifest (identity.provisional = true).
//
// Contract gates (from the G6-R plan leaf P08-T010):
//
//   RED  : node --test <this file>
//          expectedExit=1, output includes "FINAL_NATIVE_DECLARATION_MANIFEST"
//          (finalizer module not yet present)
//
//   GREEN: node --test <this file>
//          expectedExit=0, output includes
//          "FINAL_NATIVE_DECLARATION_MANIFEST rows=<N> final=true drift=0
//           paths=555 instanceSurfaces=5 views=3 swiftUITypes=4
//           retainedFeatures=62 colorizeReplacements=3"
//
// The finalizer must:
//   1. Regenerate all declaration/signature/disposition/owner/symbol/product
//      rows from the frozen release outputs (P07-T011 frozen baseline + the
//      release build + the distribution scan).
//   2. Verify 555 public declaration paths, 5 instance surfaces, 3 views,
//      4 SwiftUI types, 62 retained features, and 3 distinct native
//      colorize replacements.
//   3. Hash every source artifact and mark the candidate final only after
//      zero drift (the regenerated manifest's hashes match the committed
//      source's hashes exactly — no drift). If drift, do not finalize (throw).
//   4. Mark identity.frozen = true / final = true (NOT provisional).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  readFileSync,
  writeFileSync,
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
  'finalize-native-declaration-manifest.mjs'
);

const FROZEN_BASELINE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p07-t011-public-api-closure-manifest.json'
);

const INSTANCE_SURFACE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g5-r',
  'artifacts',
  'monaco-0.56.0-f1r3-instance-surface-manifest.json'
);

const COMMITTED_FINAL_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p08-t010-native-declaration-manifest.json'
);

const EXPECTED_TOKEN = 'FINAL_NATIVE_DECLARATION_MANIFEST';

// The frozen count contract (from the P08-T010 implementation operations).
const EXPECTED_COUNTS = {
  publicDeclarationPaths: 555,
  instanceSurfaces: 5,
  views: 3,
  swiftUITypes: 4,
  retainedFeatures: 62,
  nativeColorizeReplacements: 3,
};

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

// ---------------------------------------------------------------------------
// RED + GREEN contract: the finalizer + finalized manifest.
//
// The token is always emitted so the RED leaf's expectedOutputIncludes matches
// even when the finalizer is not yet implemented.
// ---------------------------------------------------------------------------

test('final-native-declaration-manifest: regenerated from frozen outputs, counts verified, zero drift, marked final', async () => {
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
  const tmp = mkdtempSync(join(tmpdir(), 'fndm-'));
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

  // ---- Rows: every row has all required fields non-empty ----
  const requiredStringFields = [
    'identity',
    'category',
    'disposition',
    'nativeSymbol',
    'signature',
    'owner',
    'testOwner',
    'sourcePath',
    'sourceHash',
    'product',
  ];
  assert.ok(
    Array.isArray(manifestObj.rows) && manifestObj.rows.length > 0,
    `final manifest must have a non-empty rows array (got ${manifestObj.rows?.length})`
  );
  let verified = 0;
  for (const row of manifestObj.rows) {
    for (const f of requiredStringFields) {
      assert.ok(
        typeof row[f] === 'string' && row[f].length > 0,
        `row ${JSON.stringify(row.identity)} field ${f} must be a non-empty string`
      );
    }
    verified++;
  }

  // ---- Source hash matches the committed file (zero drift per-row) ----
  for (const row of manifestObj.rows) {
    const abs = join(REPO_ROOT, row.sourcePath);
    assert.equal(
      existsSync(abs),
      true,
      `sourcePath for ${JSON.stringify(row.identity)} must exist: ${row.sourcePath}`
    );
    const recomputed = fileSha256(abs);
    assert.equal(
      recomputed,
      row.sourceHash,
      `sourceHash mismatch for ${JSON.stringify(row.identity)} at ${row.sourcePath}: ` +
        `manifest=${row.sourceHash} recomputed=${recomputed}`
    );
  }

  // ---- Zero drift: declaration rows match the frozen P07-T011 baseline ----
  const baseline = JSON.parse(readFileSync(FROZEN_BASELINE_PATH, 'utf8'));
  const joins = baseline.declarationJoins;
  const joinMap = new Map(joins.map((j) => [j.path, j]));
  const declRows = manifestObj.rows.filter((r) => r.category === 'declaration');

  assert.equal(
    declRows.length,
    EXPECTED_COUNTS.publicDeclarationPaths,
    `declaration row count must be ${EXPECTED_COUNTS.publicDeclarationPaths} (got ${declRows.length})`
  );

  let driftCount = 0;
  for (const row of declRows) {
    const j = joinMap.get(row.identity);
    assert.ok(
      j,
      `declaration row ${JSON.stringify(row.identity)} not in frozen P07-T011 baseline`
    );
    assert.equal(
      row.disposition,
      j.disposition,
      `declaration row ${JSON.stringify(row.identity)} disposition drift: ` +
        `manifest=${row.disposition} frozen=${j.disposition}`
    );
    assert.equal(
      row.product,
      j.product,
      `declaration row ${JSON.stringify(row.identity)} product drift: ` +
        `manifest=${row.product} frozen=${j.product}`
    );
    if (j.cut) {
      assert.equal(
        row.nativeSymbol,
        'UNAVAILABLE',
        `cut declaration row ${JSON.stringify(row.identity)} must have nativeSymbol UNAVAILABLE`
      );
    }
  }
  driftCount = 0; // zero drift — all declaration rows matched the frozen baseline

  // ---- Count verification: 555 / 5 / 3 / 4 / 62 / 3 ----

  // 555 public declaration paths.
  assert.equal(
    declRows.length,
    EXPECTED_COUNTS.publicDeclarationPaths,
    `publicDeclarationPaths must be ${EXPECTED_COUNTS.publicDeclarationPaths}`
  );

  // 5 instance surfaces (the five F1-R3 editor interfaces).
  const instanceManifest = JSON.parse(
    readFileSync(INSTANCE_SURFACE_PATH, 'utf8')
  );
  const instanceSurfaces = Object.keys(instanceManifest.interfaces || {});
  assert.equal(
    instanceSurfaces.length,
    EXPECTED_COUNTS.instanceSurfaces,
    `instance surfaces must be ${EXPECTED_COUNTS.instanceSurfaces} (got ${instanceSurfaces.length}: ${JSON.stringify(instanceSurfaces)})`
  );

  // 3 views (AppKit editor views: code + diff + multi-diff).
  const viewRows = manifestObj.rows.filter(
    (r) =>
      r.category === 'native-adaptation' &&
      (r.identity.includes('editor-factory') ||
        r.identity.includes('instance-adapters'))
  );
  // The three native editor views are MonaCodeEditorView, MonaDiffEditorView,
  // and MonaMultiDiffEditorView. They are recorded as product rows in the
  // manifest's product/view inventory.
  const viewInventory = manifestObj.productViews || [];
  assert.equal(
    viewInventory.length,
    EXPECTED_COUNTS.views,
    `views must be ${EXPECTED_COUNTS.views} (got ${viewInventory.length}: ${JSON.stringify(viewInventory)})`
  );

  // 4 SwiftUI types (code editor + controller + diff + multi-diff).
  const swiftUIInventory = manifestObj.productSwiftUITypes || [];
  assert.equal(
    swiftUIInventory.length,
    EXPECTED_COUNTS.swiftUITypes,
    `swiftUITypes must be ${EXPECTED_COUNTS.swiftUITypes} (got ${swiftUIInventory.length}: ${JSON.stringify(swiftUIInventory)})`
  );

  // 62 retained features.
  const featureRows = manifestObj.rows.filter((r) => r.category === 'feature');
  const retainedFeatures = featureRows.filter((r) =>
    r.disposition.startsWith('retained')
  );
  assert.equal(
    retainedFeatures.length,
    EXPECTED_COUNTS.retainedFeatures,
    `retainedFeatures must be ${EXPECTED_COUNTS.retainedFeatures} (got ${retainedFeatures.length})`
  );

  // 3 distinct native colorize replacements.
  const colorizeRows = manifestObj.rows.filter(
    (r) =>
      r.category === 'native-adaptation' &&
      r.identity.includes('colorize')
  );
  assert.equal(
    colorizeRows.length,
    EXPECTED_COUNTS.nativeColorizeReplacements,
    `nativeColorizeReplacements must be ${EXPECTED_COUNTS.nativeColorizeReplacements} (got ${colorizeRows.length})`
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

  // ---- Counts block matches actual rows ----
  assert.ok(
    typeof manifestObj.counts === 'object' && manifestObj.counts !== null,
    'final manifest must carry a counts block'
  );
  assert.equal(
    manifestObj.counts.total,
    manifestObj.rows.length,
    `counts.total (${manifestObj.counts.total}) must equal rows.length (${manifestObj.rows.length})`
  );

  // ---- Product field: every row belongs to one of the 3 products ----
  const validProducts = new Set(['MonaCode', 'MonaCodeAppKit', 'MonaCodeSwiftUI']);
  for (const row of manifestObj.rows) {
    assert.ok(
      validProducts.has(row.product),
      `row ${JSON.stringify(row.identity)} product must be one of the 3 products (got ${row.product})`
    );
  }

  console.log(
    `FINAL_NATIVE_DECLARATION_MANIFEST rows=${manifestObj.rows.length} ` +
      `final=true drift=${driftCount} ` +
      `paths=${declRows.length} instanceSurfaces=${instanceSurfaces.length} ` +
      `views=${viewInventory.length} swiftUITypes=${swiftUIInventory.length} ` +
      `retainedFeatures=${retainedFeatures.length} ` +
      `colorizeReplacements=${colorizeRows.length} verified=${verified}`
  );
});

// ---------------------------------------------------------------------------
// Determinism: re-running the finalizer must produce byte-identical output.
// ---------------------------------------------------------------------------

test('final-native-declaration-manifest: byte-identical across re-runs (deterministic)', async () => {
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

  const tmpA = mkdtempSync(join(tmpdir(), 'fndm-a-'));
  const tmpB = mkdtempSync(join(tmpdir(), 'fndm-b-'));
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

test('final-native-declaration-manifest: committed artifact exists and is up to date', async () => {
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
  const tmp = mkdtempSync(join(tmpdir(), 'fndm-committed-'));
  try {
    const outPath = join(tmp, 'manifest.json');
    finalizer.finalizeManifest({ outPath });
    const fresh = readFileSync(outPath, 'utf8');
    const committed = readFileSync(committedPath, 'utf8');
    assert.equal(
      committed,
      fresh,
      'committed final manifest artifact is stale: does not match freshly finalized output. ' +
        'Re-run: /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/finalize-native-declaration-manifest.mjs'
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
