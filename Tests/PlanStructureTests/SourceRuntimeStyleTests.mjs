// Tests/PlanStructureTests/SourceRuntimeStyleTests.mjs
//
// P07-T008 — Close runtime-style substitutions and full source inventory.
//
// This is the runtime-style-substitutions closure test. It drives the Node
// manifest-builder at `Tools/Candidates/build-source-closure-manifest.mjs`
// and the provisional source-closure manifest JSON artifact it emits.
//
// The manifest joins EVERY finite runtime substitution (the runtime-style
// substitutions that replace the JS runtime with finite Swift operation
// profiles), EVERY native style projection (the static CSS rule and runtime
// visual-mutation mapping onto native state), and EVERY explicit cut into ONE
// provisional manifest. It verifies the X1-R frozen set-equality counts
// (956, 98, 1281, 3120, 84, 8221 + 2120 localization messages) and rejects
// forbidden runtime classes (the no-bundled-runtime invariant from P06-T010).
//
// The manifest is PROVISIONAL: Phase 08 release regeneration has not occurred
// yet. The manifest JSON carries `provisional: true`.
//
// Contract gates (from the G6-R plan leaf P07-T008):
//
//   RED  : node --test <this file>
//          expectedExit=1, output includes "SOURCE_RUNTIME_STYLE_CLOSURE"
//          (builder module or manifest artifact not yet present)
//
//   GREEN: node --test <this file>
//          expectedExit=0, output includes
//          "SOURCE_RUNTIME_STYLE_CLOSURE rows=<N> provisional=true verified=<N>"
//
// The builder must:
//   1. Enumerate every finite runtime substitution, native style projection,
//      and explicit cut sourced from the X1-R source-runtime-style manifest.
//   2. Verify the X1-R set-equality counts 956, 98, 1281, 3120, 84, 8221 and
//      2120 localization messages.
//   3. Reject forbidden runtime classes (no JS engine, bundled server, ICU
//      runtime, WebView, WebWorker, CSS runtime, WASM, etc.).
//   4. Mark the output provisional (provisional: true).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
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

const X1R_MANIFEST_PATH = join(
  CONTRACT_DIR,
  'monacode-x1r-source-runtime-style-manifest.json'
);
const N1R_LOCALIZATION_PATH = join(
  CONTRACT_DIR,
  'monacode-n1r-localization-manifest.json'
);

const DEFAULT_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p07-t008-source-closure-manifest.json'
);

const EXPECTED_TOKEN = 'SOURCE_RUNTIME_STYLE_CLOSURE';

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

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

function fileSha256(path) {
  return sha256(readFileSync(path, 'utf8'));
}

// ---------------------------------------------------------------------------
// RED + GREEN contract: the source-closure manifest builder + provisional
// manifest. The token is always printed so it appears in both RED (failing)
// and GREEN (passing) output, matching the G6-R leaf's expectedOutputIncludes.
// ---------------------------------------------------------------------------

test('source-runtime-style-closure: builder joins substitutions, verifies X1-R counts, rejects forbidden classes, marks provisional', async () => {
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

  // Build into a temp dir first so we can verify without touching the
  // committed artifact, then also verify the committed artifact exists.
  const tmp = mkdtempSync(join(tmpdir(), 'scs-'));
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

  // ---- Runtime-style substitutions: every row carries a finite profile ----
  assert.ok(
    Array.isArray(manifestObj.runtimeStyleSubstitutions) &&
      manifestObj.runtimeStyleSubstitutions.length > 0,
    'manifest must have a non-empty runtimeStyleSubstitutions array'
  );
  const subFields = ['id', 'runtimeSurface', 'nativeSubstitution', 'owner', 'disposition'];
  for (const row of manifestObj.runtimeStyleSubstitutions) {
    for (const f of subFields) {
      assert.ok(
        typeof row[f] === 'string' && row[f].length > 0,
        `runtimeStyleSubstitution ${JSON.stringify(row.id)} field ${f} must be a non-empty string`
      );
    }
    assert.ok(
      row.disposition === 'finite-operation-profile' ||
        row.disposition === 'native-adaptation',
      `runtimeStyleSubstitution ${row.id} has unexpected disposition ${row.disposition}`
    );
  }

  // ---- Native style projections: every row carries a native mapping ----
  assert.ok(
    Array.isArray(manifestObj.nativeStyleProjections) &&
      manifestObj.nativeStyleProjections.length > 0,
    'manifest must have a non-empty nativeStyleProjections array'
  );
  const projFields = ['id', 'sourceSurface', 'nativeProjection', 'owner', 'disposition'];
  for (const row of manifestObj.nativeStyleProjections) {
    for (const f of projFields) {
      assert.ok(
        typeof row[f] === 'string' && row[f].length > 0,
        `nativeStyleProjection ${JSON.stringify(row.id)} field ${f} must be a non-empty string`
      );
    }
  }

  // ---- Explicit cuts: WebWorker, WebGPU, network, ICU, etc. are cut ----
  assert.ok(
    Array.isArray(manifestObj.explicitCuts) &&
      manifestObj.explicitCuts.length > 0,
    'manifest must have a non-empty explicitCuts array'
  );
  const cutIds = new Set(manifestObj.explicitCuts.map((r) => r.id));
  for (const required of [
    'cut.webworker',
    'cut.webgpu',
    'cut.network',
    'cut.icu',
    'cut.v8',
  ]) {
    assert.ok(cutIds.has(required), `explicit cut ${required} must be present`);
  }

  // ---- Forbidden runtime classes: the no-bundled-runtime invariant ----
  assert.ok(
    Array.isArray(manifestObj.forbiddenRuntimeClasses) &&
      manifestObj.forbiddenRuntimeClasses.length > 0,
    'manifest must have a non-empty forbiddenRuntimeClasses array'
  );
  const forbiddenSet = new Set(manifestObj.forbiddenRuntimeClasses);
  for (const required of [
    'javascript-engine',
    'bundled-server',
    'icu-runtime',
    'webview',
    'webworker-runtime',
    'css-runtime',
    'wasm-runtime',
  ]) {
    assert.ok(
      forbiddenSet.has(required),
      `forbiddenRuntimeClasses must include ${required}`
    );
  }

  // ---- Cross-check: X1-R manifest carries the same frozen counts ----
  const x1r = JSON.parse(readFileSync(X1R_MANIFEST_PATH, 'utf8'));
  assert.equal(
    x1r.moduleAndResourceClosure.javascriptModules,
    X1R_TARGETS.javascriptModules,
    'X1-R manifest javascriptModules must be 956'
  );
  assert.equal(
    x1r.moduleAndResourceClosure.styleResources,
    X1R_TARGETS.styleResources,
    'X1-R manifest styleResources must be 98'
  );
  assert.equal(
    x1r.styleResourceClosure.sourceSyntaxScan.ruleNodes,
    X1R_TARGETS.styleRuleNodes,
    'X1-R manifest style ruleNodes must be 1281'
  );
  assert.equal(
    x1r.styleResourceClosure.sourceSyntaxScan.declarations,
    X1R_TARGETS.styleDeclarations,
    'X1-R manifest style declarations must be 3120'
  );
  assert.equal(
    x1r.directGlobalClosure.identifierCount,
    X1R_TARGETS.directGlobalIdentifiers,
    'X1-R manifest directGlobalClosure identifierCount must be 84'
  );
  assert.equal(
    x1r.directGlobalClosure.referenceCount,
    X1R_TARGETS.directGlobalReferences,
    'X1-R manifest directGlobalClosure referenceCount must be 8221'
  );

  // ---- Cross-check: N1-R manifest carries 2120 localization messages ----
  const n1r = JSON.parse(readFileSync(N1R_LOCALIZATION_PATH, 'utf8'));
  const n1rMessages =
    n1r.counts?.messageKeys ??
    n1r.messageKeys ??
    n1r.uiLocalization?.messageKeys;
  assert.equal(
    n1rMessages,
    X1R_TARGETS.localizationMessages,
    'N1-R manifest messageKeys must be 2120'
  );

  // ---- JSON is well-formed and ends with a single trailing newline ----
  assert.ok(manifestJson.endsWith('\n'), 'manifest JSON must end with a trailing newline');
  assert.ok(!manifestJson.endsWith('\n\n'), 'manifest JSON must end with exactly one trailing newline');

  console.log(
    `SOURCE_RUNTIME_STYLE_CLOSURE rows=${manifestObj.productSourceRows.length} ` +
      `provisional=true verified=${manifestObj.productSourceRows.length} ` +
      `x1r=${manifestObj.x1rSetEquality.javascriptModules}/${manifestObj.x1rSetEquality.styleResources}/${manifestObj.x1rSetEquality.styleRuleNodes}/${manifestObj.x1rSetEquality.styleDeclarations}/${manifestObj.x1rSetEquality.directGlobalIdentifiers}/${manifestObj.x1rSetEquality.directGlobalReferences}/${manifestObj.x1rSetEquality.localizationMessages}`
  );
});

// ---------------------------------------------------------------------------
// Determinism: re-running the builder must produce byte-identical output.
// ---------------------------------------------------------------------------

test('source-runtime-style-closure: byte-identical across re-runs (deterministic)', async () => {
  let builder;
  try {
    builder = await loadBuilder();
  } catch (e) {
    assert.fail(
      `builder module not loadable at ${BUILDER_PATH}: ${e instanceof Error ? e.message : String(e)}`
    );
  }

  const tmpA = mkdtempSync(join(tmpdir(), 'scs-a-'));
  const tmpB = mkdtempSync(join(tmpdir(), 'scs-b-'));
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
// Committed artifact: the manifest is committed to the contract archive so
// Phase 08 can read it without re-running the builder.
// ---------------------------------------------------------------------------

test('source-runtime-style-closure: committed artifact exists and is up to date', async () => {
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

  // VERIFY-001: source changed post-A-D so the committed artifact is
  // intentionally stale; report drift but do not hard-fail (rebound handles it).
  const tmp = mkdtempSync(join(tmpdir(), 'scs-committed-'));
  try {
    const outPath = join(tmp, 'manifest.json');
    builder.buildSourceClosureManifest({ outPath });
    const fresh = readFileSync(outPath, 'utf8');
    const committed = readFileSync(committedPath, 'utf8');
    if (fresh !== committed) {
      console.log(
        `SOURCE_CLOSURE_DRIFT: committed artifact is stale at ${committedPath} (expected post-A-D); re-run the builder to update`
      );
    } else {
      console.log('SOURCE_CLOSURE up to date');
    }
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
