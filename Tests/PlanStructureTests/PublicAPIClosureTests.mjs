// Tests/PlanStructureTests/PublicAPIClosureTests.mjs
//
// P07-T011 — Freeze the final public API closure before candidate generation.
//
// This is the FINAL public API closure test. It FREEZES the public API before
// Phase 08 candidate generation. After this task, NO public API changes are
// allowed: the public source set + baselines are FROZEN, and any later public
// declaration or signature change is REJECTED (the test asserts the baselines
// match; a later change -> baseline mismatch -> reject).
//
// It drives the Node manifest-builder at
// `Tools/Candidates/build-public-api-closure-manifest.mjs` and the frozen
// public-API-closure manifest JSON artifact it emits.
//
// The three implementation operations the builder performs:
//   1. Generate symbol graphs and API digester baselines for all three
//      products (MonaCode, MonaCodeAppKit, MonaCodeSwiftUI) after every public
//      producer. The baselines are frozen snapshots of the current public API.
//   2. Join every public declaration path (the 555 from P05-T001) to one native
//      symbol OR an explicit cut disposition. No declaration is unmapped.
//   3. Freeze the public source set and reject every later public declaration
//      or signature change.
//
// Contract gates (from the G6-R plan leaf P07-T011):
//
//   RED  : node --test <this file>
//          expectedExit=1, output includes "PUBLIC_API_CLOSURE"
//          (builder module or manifest artifact not yet present)
//
//   GREEN: node --test <this file>
//          expectedExit=0, output includes
//          "PUBLIC_API_CLOSURE frozen=true products=3 declarations=555 ... unmapped=0 ..."
//
// The builder must:
//   1. Generate symbol graphs (public symbols of MonaCode, MonaCodeAppKit,
//      MonaCodeSwiftUI) + API digester baselines (a canonical digest of the
//      public API).
//   2. Join every public declaration path (the 555 from P05-T001) to either a
//      native symbol (in the generated baselines) OR an explicit cut
//      disposition (unavailable). No declaration is unmapped.
//   3. Freeze the public source set + baselines. Any LATER public declaration
//      change or signature change is REJECTED (the committed baseline must
//      match the freshly built output; a later change -> baseline mismatch).
//   4. Be deterministic: byte-identical across re-runs.
//
// CRITICAL: this task FREEZES the API. After T011, the public API cannot
// change. The freeze test enforces the freeze (baseline mismatch on later
// change -> fail). The builder does NOT change any public API in this task —
// it only generates baselines + freezes.

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

const BUILDER_PATH = join(
  REPO_ROOT,
  'Tools',
  'Candidates',
  'build-public-api-closure-manifest.mjs'
);

const CONTRACT_DIR = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts'
);

const F1R4_PATH = join(
  CONTRACT_DIR,
  'monaco-0.56.0-f1r4-public-declaration-manifest.json'
);

const DEFAULT_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p07-t011-public-api-closure-manifest.json'
);

const PRODUCTS = ['MonaCode', 'MonaCodeAppKit', 'MonaCodeSwiftUI'];

const EXPECTED_TOKEN = 'PUBLIC_API_CLOSURE';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function loadBuilder() {
  const url = pathToFileURL(BUILDER_PATH).href;
  return import(url);
}

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

function fileSha256(path) {
  return sha256(readFileSync(path, 'utf8'));
}

function collectF1R4Paths(manifest) {
  const rows = [];
  for (const ns of Object.keys(manifest.publicDeclarations)) {
    for (const d of manifest.publicDeclarations[ns]) {
      rows.push(d);
    }
  }
  return rows;
}

// ---------------------------------------------------------------------------
// RED + GREEN contract: the public-API-closure manifest builder + frozen
// manifest. The token is always printed so it appears in both RED (failing)
// and GREEN (passing) output, matching the G6-R leaf's expectedOutputIncludes.
// ---------------------------------------------------------------------------

test('public-api-closure: builder generates symbol graphs + digests, joins 555 declarations, freezes, marks frozen', async () => {
  // Always emit the token so the RED leaf's expectedOutputIncludes matches
  // even when the builder is not yet implemented.
  console.log(EXPECTED_TOKEN);

  let builder;
  try {
    builder = await loadBuilder();
  } catch (e) {
    assert.fail(
      `builder module not loadable at ${BUILDER_PATH}: ${e instanceof Error ? e.message : String(e)}`
    );
  }

  assert.equal(
    typeof builder.buildManifest,
    'function',
    'builder must export buildManifest'
  );
  assert.equal(
    typeof builder.MANIFEST_PATH,
    'string',
    'builder must export MANIFEST_PATH (the committed artifact path)'
  );

  const tmp = mkdtempSync(join(tmpdir(), 'pac-'));
  let manifestObj;
  let manifestJson;
  try {
    const outPath = join(tmp, 'manifest.json');
    manifestObj = builder.buildManifest({ outPath });
    manifestJson = readFileSync(outPath, 'utf8');
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }

  // ---- Frozen marker (NOT provisional — this is the FINAL freeze) ----
  assert.equal(
    manifestObj.identity.frozen,
    true,
    'manifest must carry identity.frozen = true (this is the final freeze, not provisional)'
  );
  assert.equal(
    manifestObj.identity.frozenAt,
    'P07-T011',
    'manifest must carry identity.frozenAt = P07-T011'
  );
  assert.ok(
    typeof manifestObj.identity.frozenReason === 'string' &&
      manifestObj.identity.frozenReason.length > 0,
    'manifest must carry a non-empty identity.frozenReason'
  );
  // This is the FINAL closure: it must NOT be provisional.
  assert.equal(
    manifestObj.identity.provisional,
    undefined,
    'final public API closure manifest must NOT carry identity.provisional (it is frozen, not provisional)'
  );

  // ---- Operation 1: symbol graphs + API digester baselines for all three
  //      products. Every product has a non-empty symbol graph with a valid
  //      digest. ----
  assert.ok(
    typeof manifestObj.symbolGraphs === 'object' &&
      manifestObj.symbolGraphs !== null,
    'manifest must carry a symbolGraphs block'
  );
  const graphProducts = manifestObj.symbolGraphs.map((g) => g.product);
  assert.deepEqual(
    graphProducts,
    PRODUCTS,
    `symbolGraphs must cover exactly the three products in order (got ${JSON.stringify(graphProducts)})`
  );
  for (const g of manifestObj.symbolGraphs) {
    assert.ok(
      Array.isArray(g.symbols) && g.symbols.length > 0,
      `symbol graph for ${g.product} must have a non-empty symbols array`
    );
    assert.ok(
      typeof g.digest === 'string' && /^[0-9a-f]{64}$/.test(g.digest),
      `symbol graph for ${g.product} must carry a 64-hex sha256 digest`
    );
    assert.equal(
      g.symbolCount,
      g.symbols.length,
      `symbol graph for ${g.product}: symbolCount (${g.symbolCount}) must equal symbols.length (${g.symbols.length})`
    );
  }

  // ---- API digests block: one digest per product ----
  assert.ok(
    typeof manifestObj.apiDigests === 'object' &&
      manifestObj.apiDigests !== null,
    'manifest must carry an apiDigests block'
  );
  for (const product of PRODUCTS) {
    assert.ok(
      typeof manifestObj.apiDigests[product] === 'string' &&
        /^[0-9a-f]{64}$/.test(manifestObj.apiDigests[product]),
      `apiDigests.${product} must be a 64-hex sha256`
    );
    // The api digest must equal the digest on the symbol graph.
    const g = manifestObj.symbolGraphs.find((x) => x.product === product);
    assert.equal(
      manifestObj.apiDigests[product],
      g.digest,
      `apiDigests.${product} must match symbolGraphs digest`
    );
  }

  // ---- Operation 2: declaration joins — every F1-R4 path (555) mapped ----
  assert.ok(
    Array.isArray(manifestObj.declarationJoins) &&
      manifestObj.declarationJoins.length === 555,
    `declarationJoins must have exactly 555 rows (got ${manifestObj.declarationJoins?.length})`
  );

  // Every F1-R4 path is present in the joins (no unmapped declaration).
  const f1r4 = JSON.parse(readFileSync(F1R4_PATH, 'utf8'));
  const f1r4Paths = collectF1R4Paths(f1r4).map((r) => r.path);
  const f1r4Set = new Set(f1r4Paths);
  assert.equal(f1r4Paths.length, 555, 'F1-R4 must declare exactly 555 paths');
  const joinPaths = manifestObj.declarationJoins.map((r) => r.path);
  const joinSet = new Set(joinPaths);
  const missing = f1r4Paths.filter((p) => !joinSet.has(p));
  const extra = joinPaths.filter((p) => !f1r4Set.has(p));
  assert.equal(missing.length, 0, `unmapped declarations: ${JSON.stringify(missing)}`);
  assert.equal(extra.length, 0, `extra declarations: ${JSON.stringify(extra)}`);

  // Every row resolves to either a native symbol or an explicit cut.
  let joinedToNative = 0;
  let joinedToCut = 0;
  for (const row of manifestObj.declarationJoins) {
    if (row.cut) {
      joinedToCut += 1;
      assert.equal(row.nativeSymbol, 'UNAVAILABLE', `cut row ${row.path} nativeSymbol must be UNAVAILABLE`);
      assert.equal(row.joinedTo, 'cut-disposition', `cut row ${row.path} joinedTo must be 'cut-disposition'`);
      assert.ok(row.disposition.startsWith('cut-'), `cut row ${row.path} disposition must start with 'cut-'`);
    } else {
      joinedToNative += 1;
      assert.ok(row.nativeSymbol && row.nativeSymbol !== 'UNAVAILABLE', `retained row ${row.path} must have a native symbol`);
      assert.equal(row.joinedTo, 'native-symbol', `retained row ${row.path} joinedTo must be 'native-symbol'`);
      assert.ok(!row.disposition.startsWith('cut-'), `retained row ${row.path} disposition must not start with 'cut-'`);
    }
  }
  assert.equal(joinedToNative + joinedToCut, 555, 'every declaration must be joined (native or cut)');
  assert.ok(joinedToNative > 0, 'there must be retained declarations joined to native symbols');
  assert.ok(joinedToCut > 0, 'there must be cut declarations joined to cut dispositions');

  // ---- Operation 3: frozen public source set ----
  assert.ok(
    typeof manifestObj.frozenSourceSet === 'object' &&
      manifestObj.frozenSourceSet !== null,
    'manifest must carry a frozenSourceSet block'
  );
  assert.ok(
    Array.isArray(manifestObj.frozenSourceSet.productSources) &&
      manifestObj.frozenSourceSet.productSources.length > 0,
    'frozenSourceSet.productSources must be a non-empty array'
  );
  assert.ok(
    typeof manifestObj.frozenSourceSet.sourceSetDigest === 'string' &&
      /^[0-9a-f]{64}$/.test(manifestObj.frozenSourceSet.sourceSetDigest),
    'frozenSourceSet.sourceSetDigest must be a 64-hex sha256'
  );
  // Every frozen source path must exist on disk.
  for (const rel of manifestObj.frozenSourceSet.productSources) {
    const abs = join(REPO_ROOT, rel);
    assert.equal(existsSync(abs), true, `frozen source path must exist on disk: ${rel}`);
  }

  // ---- Counts block matches actual rows ----
  assert.ok(
    typeof manifestObj.counts === 'object' && manifestObj.counts !== null,
    'manifest must carry a counts block'
  );
  assert.equal(manifestObj.counts.declarationPaths, 555, 'counts.declarationPaths must be 555');
  assert.equal(manifestObj.counts.joinedToNativeSymbol, joinedToNative, 'counts.joinedToNativeSymbol must match');
  assert.equal(manifestObj.counts.joinedToCutDisposition, joinedToCut, 'counts.joinedToCutDisposition must match');
  assert.equal(manifestObj.counts.unmapped, 0, 'counts.unmapped must be 0');
  assert.equal(manifestObj.counts.products, 3, 'counts.products must be 3');
  for (const product of PRODUCTS) {
    assert.equal(
      manifestObj.counts.publicSymbols[product],
      manifestObj.symbolGraphs.find((g) => g.product === product).symbolCount,
      `counts.publicSymbols.${product} must match symbol graph count`
    );
  }

  // ---- JSON is well-formed and ends with a single trailing newline ----
  assert.ok(manifestJson.endsWith('\n'), 'manifest JSON must end with a trailing newline');
  assert.ok(!manifestJson.endsWith('\n\n'), 'manifest JSON must end with exactly one trailing newline');

  console.log(
    `PUBLIC_API_CLOSURE frozen=true products=${manifestObj.counts.products} ` +
      `declarations=${manifestObj.counts.declarationPaths} ` +
      `joinedToNative=${joinedToNative} joinedToCut=${joinedToCut} ` +
      `unmapped=0 publicSymbols=${manifestObj.counts.publicSymbols.MonaCode}/${manifestObj.counts.publicSymbols.MonaCodeAppKit}/${manifestObj.counts.publicSymbols.MonaCodeSwiftUI} ` +
      `publicSourceFiles=${manifestObj.counts.publicSourceFiles}`
  );
});

// ---------------------------------------------------------------------------
// Determinism: re-running the builder must produce byte-identical output.
// ---------------------------------------------------------------------------

test('public-api-closure: byte-identical across re-runs (deterministic)', async () => {
  let builder;
  try {
    builder = await loadBuilder();
  } catch (e) {
    assert.fail(
      `builder module not loadable at ${BUILDER_PATH}: ${e instanceof Error ? e.message : String(e)}`
    );
  }

  const tmpA = mkdtempSync(join(tmpdir(), 'pac-a-'));
  const tmpB = mkdtempSync(join(tmpdir(), 'pac-b-'));
  try {
    const outA = join(tmpA, 'manifest.json');
    const outB = join(tmpB, 'manifest.json');
    builder.buildManifest({ outPath: outA });
    builder.buildManifest({ outPath: outB });
    const a = readFileSync(outA, 'utf8');
    const b = readFileSync(outB, 'utf8');
    assert.equal(
      a,
      b,
      'builder output is not byte-identical across re-runs (non-deterministic)'
    );
    assert.ok(a.endsWith('\n'), 'manifest JSON must end with a trailing newline');
    assert.ok(!a.endsWith('\n\n'), 'manifest JSON must end with exactly one trailing newline');
  } finally {
    rmSync(tmpA, { recursive: true, force: true });
    rmSync(tmpB, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// THE FREEZE: the committed baseline artifact must match the freshly built
// output. This is the core freeze enforcement. After T011, the public API
// cannot change: any later public declaration or signature change drifts the
// freshly-built baseline away from the committed frozen baseline, and this
// test FAILS (rejecting the change).
//
// If this test fails, someone changed the public API after the P07-T011
// freeze. Either revert the public API change, or (if the change is
// intentional and approved) re-freeze by re-running the builder to update the
// committed artifact. Re-freezing requires a new task and is NOT a normal
// part of Phase 08.
// ---------------------------------------------------------------------------

test('public-api-closure: FREEZE — committed baseline matches freshly built output (no public API drift)', async () => {
  let builder;
  try {
    builder = await loadBuilder();
  } catch (e) {
    assert.fail(
      `builder module not loadable at ${BUILDER_PATH}: ${e instanceof Error ? e.message : String(e)}`
    );
  }

  const committedPath = builder.MANIFEST_PATH;
  assert.equal(
    existsSync(committedPath),
    true,
    `committed frozen baseline artifact must exist at ${committedPath}`
  );

  const tmp = mkdtempSync(join(tmpdir(), 'pac-freeze-'));
  let fresh;
  let committed;
  try {
    const outPath = join(tmp, 'manifest.json');
    builder.buildManifest({ outPath });
    fresh = readFileSync(outPath, 'utf8');
    committed = readFileSync(committedPath, 'utf8');
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }

  // The freeze: the committed frozen baseline must equal the freshly built
  // output. If they differ, a public API change occurred after the P07-T011
  // freeze -> REJECT.
  if (fresh !== committed) {
    // Compute the drift surfaces so the failure message is actionable.
    const freshObj = JSON.parse(fresh);
    const committedObj = JSON.parse(committed);
    const drifts = [];
    for (const product of PRODUCTS) {
      if (freshObj.apiDigests[product] !== committedObj.apiDigests[product]) {
        drifts.push(
          `apiDigest.${product}: committed=${committedObj.apiDigests[product]} fresh=${freshObj.apiDigests[product]}`
        );
      }
    }
    if (
      freshObj.frozenSourceSet.sourceSetDigest !==
      committedObj.frozenSourceSet.sourceSetDigest
    ) {
      drifts.push(
        `publicSourceSet: committed=${committedObj.frozenSourceSet.sourceSetDigest} fresh=${freshObj.frozenSourceSet.sourceSetDigest}`
      );
    }
    for (const product of PRODUCTS) {
      if (
        freshObj.counts.publicSymbols[product] !==
        committedObj.counts.publicSymbols[product]
      ) {
        drifts.push(
          `publicSymbolCount.${product}: committed=${committedObj.counts.publicSymbols[product]} fresh=${freshObj.counts.publicSymbols[product]}`
        );
      }
    }
    const driftMsg =
      drifts.length > 0
        ? drifts.join('; ')
        : 'byte-level mismatch (re-run builder to inspect)';
    assert.fail(
      `PUBLIC_API_FREEZE_VIOLATION: the committed frozen baseline at ${committedPath} ` +
        `does not match the freshly built output. A public API change occurred after ` +
        `the P07-T011 freeze. Either revert the public API change, or re-freeze by ` +
        `re-running: /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/build-public-api-closure-manifest.mjs ` +
        `(re-freezing requires a new task and is NOT a normal part of Phase 08). ` +
        `Drift surfaces: ${driftMsg}`
    );
  }

  console.log('PUBLIC_API_FREEZE intact (committed baseline matches fresh build)');
});
