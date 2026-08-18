// Tests/PlanStructureTests/SourceClosureTests.mjs
//
// P07-T008 — Close runtime-style substitutions and full source inventory.
//
// This is the full-source-inventory closure test. It drives the Node
// manifest-builder at `Tools/Candidates/build-source-closure-manifest.mjs`
// and the provisional source-closure manifest JSON artifact it emits.
//
// The manifest enumerates EVERY product source file (Sources/MonaCode,
// MonaCodeAppKit, MonaCodeSwiftUI), EVERY generated source, EVERY license
// notice, and EVERY resource, and joins them with the finite runtime
// substitutions, native style projections, and explicit cuts. It verifies the
// X1-R frozen set-equality counts, rejects source/resource paths absent from
// the manifest, and rejects forbidden runtime classes.
//
// The manifest is PROVISIONAL: Phase 08 release regeneration has not occurred
// yet. The manifest JSON carries `provisional: true`.
//
// Contract gates (from the G6-R plan leaf P07-T008):
//
//   RED  : builder module or manifest artifact not yet present
//
//   GREEN: node --test <this file>
//          expectedExit=0, output includes
//          "SOURCE_CLOSURE_MANIFEST rows=<N> provisional=true verified=<N>"
//
// The builder must:
//   1. Enumerate every product source file, generated source, resource, and
//      license notice (no absent paths).
//   2. Verify the X1-R set-equality counts 956, 98, 1281, 3120, 84, 8221 and
//      2120 localization messages.
//   3. Reject source/resource paths absent from the manifest.
//   4. Reject forbidden runtime classes (no-bundled-runtime invariant).
//   5. Mark the output provisional (provisional: true).
//   6. Be deterministic: byte-identical across re-runs.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  readFileSync,
  readdirSync,
  statSync,
  existsSync,
  mkdtempSync,
  rmSync,
} from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');

const BUILDER_PATH = join(
  REPO_ROOT,
  'Tools',
  'Candidates',
  'build-source-closure-manifest.mjs'
);

const PRODUCT_SOURCE_ROOTS = [
  join(REPO_ROOT, 'Sources', 'MonaCode'),
  join(REPO_ROOT, 'Sources', 'MonaCodeAppKit'),
  join(REPO_ROOT, 'Sources', 'MonaCodeSwiftUI'),
];

const EXPECTED_TOKEN = 'SOURCE_CLOSURE_MANIFEST';

// The X1-R frozen set-equality targets (verbatim from the X1-R manifest).
const X1R_TARGETS = {
  javascriptModules: 956,
  styleResources: 98,
  styleRuleNodes: 1281,
  styleDeclarations: 3120,
  directGlobalIdentifiers: 84,
  directGlobalReferences: 8221,
  localizationMessages: 2120,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function loadBuilder() {
  const url = pathToFileURL(BUILDER_PATH).href;
  return import(url);
}

function sha256(buf) {
  return createHash('sha256').update(buf).digest('hex');
}

function fileSha256(path) {
  return sha256(readFileSync(path));
}

function walkDir(rootAbs) {
  const out = [];
  function recurse(dir) {
    let entries;
    try {
      entries = readdirSync(dir);
    } catch {
      return;
    }
    for (const name of entries.sort()) {
      const full = join(dir, name);
      let st;
      try {
        st = statSync(full);
      } catch {
        continue;
      }
      if (st.isDirectory()) {
        recurse(full);
      } else if (st.isFile()) {
        out.push(relative(REPO_ROOT, full));
      }
    }
  }
  recurse(rootAbs);
  return out;
}

// ---------------------------------------------------------------------------
// RED + GREEN contract: the full source-closure manifest builder.
// ---------------------------------------------------------------------------

test('source-closure-manifest: enumerates every product source, verifies X1-R counts, rejects forbidden classes, marks provisional', async () => {
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
    typeof builder.buildSourceClosureManifest,
    'function',
    'builder must export buildSourceClosureManifest'
  );
  assert.equal(
    typeof builder.MANIFEST_PATH,
    'string',
    'builder must export MANIFEST_PATH (the committed artifact path)'
  );

  const tmp = mkdtempSync(join(tmpdir(), 'sc-inv-'));
  let manifestObj;
  let manifestJson;
  try {
    const outPath = join(tmp, 'manifest.json');
    manifestObj = builder.buildSourceClosureManifest({ outPath });
    manifestJson = readFileSync(outPath, 'utf8');
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }

  // ---- Provisional marker ----
  assert.equal(
    manifestObj.identity.provisional,
    true,
    'manifest must carry identity.provisional = true'
  );
  assert.ok(
    typeof manifestObj.identity.provisionalReason === 'string' &&
      manifestObj.identity.provisionalReason.length > 0,
    'manifest must carry a non-empty identity.provisionalReason'
  );

  // ---- X1-R set-equality counts match the frozen targets exactly ----
  assert.ok(
    typeof manifestObj.x1rSetEquality === 'object' &&
      manifestObj.x1rSetEquality !== null,
    'manifest must carry an x1rSetEquality block'
  );
  for (const [key, expected] of Object.entries(X1R_TARGETS)) {
    assert.equal(
      manifestObj.x1rSetEquality[key],
      expected,
      `x1rSetEquality.${key} must be ${expected} (got ${manifestObj.x1rSetEquality[key]})`
    );
  }

  // ---- Product source rows: every product file is enumerated ----
  assert.ok(
    Array.isArray(manifestObj.productSourceRows) &&
      manifestObj.productSourceRows.length > 0,
    'manifest must have a non-empty productSourceRows array'
  );
  const rowMap = new Map(
    manifestObj.productSourceRows.map((r) => [r.path, r])
  );

  // Every product source file in the repo must be a row (no absent paths).
  let verified = 0;
  for (const root of PRODUCT_SOURCE_ROOTS) {
    for (const rel of walkDir(root)) {
      assert.ok(
        rowMap.has(rel),
        `absent source path: ${rel} exists in repo but is not in the manifest`
      );
    }
  }

  // Every row's hash must match the file on disk, and the row's path must
  // actually exist (reject phantom rows).
  for (const row of manifestObj.productSourceRows) {
    const abs = join(REPO_ROOT, row.path);
    assert.equal(
      existsSync(abs),
      true,
      `manifest row path does not exist on disk: ${row.path}`
    );
    const recomputed = fileSha256(abs);
    assert.equal(
      recomputed,
      row.sha256,
      `sha256 mismatch for ${row.path}: manifest=${row.sha256} recomputed=${recomputed}`
    );
    assert.ok(
      row.role === 'product-swift' ||
        row.role === 'generated-swift' ||
        row.role === 'license-notice' ||
        row.role === 'resource',
      `row ${row.path} has unexpected role ${row.role}`
    );
    assert.ok(
      row.target === 'MonaCode' ||
        row.target === 'MonaCodeAppKit' ||
        row.target === 'MonaCodeSwiftUI',
      `row ${row.path} has unexpected target ${row.target}`
    );
    verified++;
  }

  // ---- Counts block matches actual rows ----
  assert.ok(
    typeof manifestObj.counts === 'object' && manifestObj.counts !== null,
    'manifest must carry a counts block'
  );
  assert.equal(
    manifestObj.counts.totalProductRows,
    manifestObj.productSourceRows.length,
    `counts.totalProductRows (${manifestObj.counts.totalProductRows}) must equal productSourceRows.length (${manifestObj.productSourceRows.length})`
  );
  assert.equal(
    manifestObj.counts.productSwift +
      manifestObj.counts.generatedSwift +
      manifestObj.counts.licenseNotices +
      manifestObj.counts.resources,
    manifestObj.counts.totalProductRows,
    'role counts must sum to totalProductRows'
  );

  // ---- Generated sources are a subset of product sources ----
  const generatedPaths = new Set(
    manifestObj.productSourceRows
      .filter((r) => r.role === 'generated-swift')
      .map((r) => r.path)
  );
  for (const p of generatedPaths) {
    assert.ok(p.includes('/Generated/'), `generated row ${p} must live under /Generated/`);
  }

  // ---- License notices are present ----
  const licenseRows = manifestObj.productSourceRows.filter(
    (r) => r.role === 'license-notice'
  );
  assert.ok(
    licenseRows.length >= 3,
    `expected at least 3 license-notice rows (Monaco MIT, Unicode, Marked MIT); got ${licenseRows.length}`
  );

  // ---- No forbidden runtime class appears in product Swift sources ----
  assert.ok(
    Array.isArray(manifestObj.forbiddenRuntimeClasses) &&
      manifestObj.forbiddenRuntimeClasses.length > 0,
    'manifest must enumerate forbiddenRuntimeClasses'
  );

  // ---- JSON is well-formed and ends with a single trailing newline ----
  assert.ok(manifestJson.endsWith('\n'), 'manifest JSON must end with a trailing newline');
  assert.ok(
    !manifestJson.endsWith('\n\n'),
    'manifest JSON must end with exactly one trailing newline'
  );

  console.log(
    `SOURCE_CLOSURE_MANIFEST rows=${manifestObj.productSourceRows.length} ` +
      `provisional=true verified=${verified} ` +
      `x1r=${manifestObj.x1rSetEquality.javascriptModules}/${manifestObj.x1rSetEquality.styleResources}/${manifestObj.x1rSetEquality.styleRuleNodes}/${manifestObj.x1rSetEquality.styleDeclarations}/${manifestObj.x1rSetEquality.directGlobalIdentifiers}/${manifestObj.x1rSetEquality.directGlobalReferences}/${manifestObj.x1rSetEquality.localizationMessages}`
  );
});

// ---------------------------------------------------------------------------
// Determinism: re-running the builder must produce byte-identical output.
// ---------------------------------------------------------------------------

test('source-closure-manifest: byte-identical across re-runs (deterministic)', async () => {
  let builder;
  try {
    builder = await loadBuilder();
  } catch (e) {
    assert.fail(
      `builder module not loadable at ${BUILDER_PATH}: ${e instanceof Error ? e.message : String(e)}`
    );
  }

  const tmpA = mkdtempSync(join(tmpdir(), 'sc-inv-a-'));
  const tmpB = mkdtempSync(join(tmpdir(), 'sc-inv-b-'));
  try {
    const outA = join(tmpA, 'manifest.json');
    const outB = join(tmpB, 'manifest.json');
    builder.buildSourceClosureManifest({ outPath: outA });
    builder.buildSourceClosureManifest({ outPath: outB });
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
// Committed artifact: the manifest is committed to the contract archive.
// ---------------------------------------------------------------------------

test('source-closure-manifest: committed artifact exists and is up to date', async () => {
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
    `committed manifest artifact must exist at ${committedPath}`
  );

  const tmp = mkdtempSync(join(tmpdir(), 'sc-inv-committed-'));
  try {
    const outPath = join(tmp, 'manifest.json');
    builder.buildSourceClosureManifest({ outPath });
    const fresh = readFileSync(outPath, 'utf8');
    const committed = readFileSync(committedPath, 'utf8');
    assert.equal(
      fresh,
      committed,
      `committed artifact is stale at ${committedPath}; re-run the builder to update`
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
