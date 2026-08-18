// Tests/PlanStructureTests/FinalSourceClosureManifestTests.mjs
//
// P08-T013 — Finalize MonaSourceClosureManifest from the release source set.
//
// This is the structural test for the MonaCode FINAL source-closure manifest.
// It drives the Node finalizer at `Tools/Candidates/finalize-source-closure-
// manifest.mjs` and the finalized manifest JSON artifact it emits.
//
// The finalizer regenerates the COMPLETE product source, generated source,
// resource, notice, finite-runtime, native-style, and explicit-cut inventory
// from the FROZEN release source set (the Phase 07 source closure frozen at
// P07-T011), includes the renderer source branch frozen in Phase 03, rejects
// every source path created afterward (zero source drift since the freeze),
// verifies all X1-R set-equality counts and artifact hashes before
// finalization, and marks the manifest FINAL only after exact provenance
// reproduction (zero drift).
//
// The manifest is FINAL: identity.frozen = true, identity.final = true, and
// identity.provisional is absent/false. This supersedes the P07-T008
// PROVISIONAL source-closure manifest (identity.provisional = true). Phase 09
// acceptance reads this final manifest without re-running the finalizer.
//
// The API is FROZEN (P07-T011). The finalizer regenerates from the frozen
// release source — no public API changes. LICENSE.md is a sanctioned Phase-08
// resource (it is included, not rejected as a post-freeze source path — it is
// a resource, not source).
//
// Contract gates (from the G6-R plan leaf P08-T013):
//
//   RED  : node --test <this file>
//          expectedExit=1, output includes "FINAL_SOURCE_CLOSURE_MANIFEST"
//          (finalizer module not yet present)
//
//   GREEN: node --test <this file>
//          expectedExit=0, output includes
//          "FINAL_SOURCE_CLOSURE_MANIFEST rows=<N> final=true drift=0
//           x1r=956/98/1281/3120/84/8221/2120"
//
// The frozen X1-R set-equality count contract (verbatim from the X1-R
// source-runtime-style manifest + the N1-R localization manifest):
//   javascriptModules: 956        (X1-R moduleAndResourceClosure.javascriptModules)
//   styleResources: 98            (X1-R moduleAndResourceClosure.styleResources)
//   styleRuleNodes: 1281          (X1-R styleResourceClosure.sourceSyntaxScan.ruleNodes)
//   styleDeclarations: 3120       (X1-R styleResourceClosure.sourceSyntaxScan.declarations)
//   directGlobalIdentifiers: 84   (X1-R directGlobalClosure.identifierCount)
//   directGlobalReferences: 8221  (X1-R directGlobalClosure.referenceCount)
//   localizationMessages: 2120    (N1-R counts.messageKeys)
//
// The finalizer must:
//   1. Regenerate the complete product source, generated source, resource,
//      notice, finite-runtime, native-style, and explicit-cut inventory from
//      release inputs.
//   2. Include the renderer source branch frozen in Phase 03 (the CG/Metal
//      renderer under Sources/MonaCodeAppKit/Rendering/) and reject every
//      source path created afterward (zero source drift since P07-T011).
//      LICENSE.md is a sanctioned Phase-08 resource (included, not rejected).
//   3. Verify all X1-R set-equality counts and artifact hashes before
//      finalization (zero drift on counts + every product source row's sha256
//      matches the file on disk + every frozen source manifest hash matches
//      its anchor).
//   4. Mark identity.frozen = true / final = true (NOT provisional).

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

const FINALIZER_PATH = join(
  REPO_ROOT,
  'Tools',
  'Candidates',
  'finalize-source-closure-manifest.mjs'
);

// The frozen X1-R source manifest (the source-runtime-style contract). This
// is the source the finalizer regenerates from + verifies counts against.
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

const FROZEN_G4R_AUTHORITATIVE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'monacode-g4r-authoritative-manifest.json'
);

const FROZEN_N1R_LOCALIZATION_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'monacode-n1r-localization-manifest.json'
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

// The PROVISIONAL source-closure manifest (P07-T008). This is the frozen
// source closure the finalizer verifies zero source drift against.
const PROVISIONAL_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p07-t008-source-closure-manifest.json'
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
  'monacode-p08-t013-source-closure-manifest.json'
);

const EXPECTED_TOKEN = 'FINAL_SOURCE_CLOSURE_MANIFEST';

const PRODUCT_SOURCE_ROOTS = [
  join(REPO_ROOT, 'Sources', 'MonaCode'),
  join(REPO_ROOT, 'Sources', 'MonaCodeAppKit'),
  join(REPO_ROOT, 'Sources', 'MonaCodeSwiftUI'),
];

// The frozen source manifest SHA-256 anchors (with trailing LF). Recorded in
// the g5-r/g6-r SHA256SUMS. These are the zero-drift anchors for the X1-R,
// G4-R, N1-R sources + the P07-T011 frozen API closure.
const FROZEN_X1R_MANIFEST_SHA256 =
  '516c91d905532e9c54e2b3691e74024c81f5887203e6b1cb9184e2c981aaa280';
const FROZEN_G4R_AUTHORITATIVE_SHA256 =
  'f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021';
const FROZEN_N1R_LOCALIZATION_SHA256 =
  '4e91e4a40f752065629241c502bbcc0fb0e6925f0be28f03c7ffce1731aedb74';
const FROZEN_API_CLOSURE_SHA256 =
  '0aca883079e7d0978f59ed1fe9de1d4b2614368e1450e0df2b8f204381a623c6';

// The frozen X1-R set-equality count contract (verbatim from the X1-R
// source-runtime-style manifest + the N1-R localization manifest).
const X1R_SET_EQUALITY = {
  javascriptModules: 956,
  styleResources: 98,
  styleRuleNodes: 1281,
  styleDeclarations: 3120,
  directGlobalIdentifiers: 84,
  directGlobalReferences: 8221,
  localizationMessages: 2120,
};

// The renderer source branch frozen in Phase 03 (the CG/Metal renderer under
// Sources/MonaCodeAppKit/Rendering/). Every one of these must appear in the
// final manifest's product source rows.
const RENDERER_SOURCE_BRANCH = [
  'Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift',
  'Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift',
  'Sources/MonaCodeAppKit/Rendering/MonaRendererMetrics.swift',
  'Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift',
  'Sources/MonaCodeAppKit/Rendering/MonaRenderTileCache.swift',
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function loadFinalizer() {
  const url = pathToFileURL(FINALIZER_PATH).href;
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
// RED + GREEN contract: the finalizer + finalized manifest.
//
// The token is always emitted so the RED leaf's expectedOutputIncludes matches
// even when the finalizer is not yet implemented.
// ---------------------------------------------------------------------------

test('final-source-closure-manifest: regenerated from frozen release source, set-equal, zero drift, renderer branch included, marked final', async () => {
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
  const tmp = mkdtempSync(join(tmpdir(), 'fscm-'));
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

  // ---- Regenerated product source rows: every product file enumerated ----
  assert.ok(
    Array.isArray(manifestObj.productSourceRows) &&
      manifestObj.productSourceRows.length > 0,
    'manifest must have a non-empty productSourceRows array'
  );
  const rowMap = new Map(
    manifestObj.productSourceRows.map((r) => [r.path, r])
  );

  // Every product source file in the repo must be a row (no absent paths).
  for (const root of PRODUCT_SOURCE_ROOTS) {
    for (const rel of walkDir(root)) {
      assert.ok(
        rowMap.has(rel),
        `absent source path: ${rel} exists in repo but is not in the manifest`
      );
    }
  }

  // Every row's hash must match the file on disk (artifact hashes verified
  // before finalization — zero drift on every product source artifact).
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
  }

  // ---- Counts block matches actual rows ----
  const counts = manifestObj.counts || {};
  assert.equal(
    counts.totalProductRows,
    manifestObj.productSourceRows.length,
    `counts.totalProductRows (${counts.totalProductRows}) must equal productSourceRows.length (${manifestObj.productSourceRows.length})`
  );
  assert.equal(
    counts.productSwift +
      counts.generatedSwift +
      counts.licenseNotices +
      counts.resources,
    counts.totalProductRows,
    'role counts must sum to totalProductRows'
  );

  // ---- LICENSE.md is included as a sanctioned Phase-08 resource (NOT
  //      rejected as a post-freeze source path — it is a resource, not
  //      source) ----
  const licenseRow = rowMap.get('Sources/MonaCode/Generated/LICENSE.md');
  assert.ok(
    licenseRow,
    'LICENSE.md must be enumerated in the final manifest (sanctioned Phase-08 resource)'
  );
  assert.ok(
    licenseRow.role === 'resource',
    `LICENSE.md must have role 'resource' (got ${licenseRow.role}) — it is a resource, not source`
  );

  // ---- Renderer source branch frozen in Phase 03 is included ----
  for (const rendererPath of RENDERER_SOURCE_BRANCH) {
    const row = rowMap.get(rendererPath);
    assert.ok(
      row,
      `renderer source branch file ${rendererPath} must appear in the final manifest (Phase 03 CG/Metal renderer frozen)`
    );
    assert.ok(
      row.role === 'product-swift' || row.role === 'generated-swift',
      `renderer file ${rendererPath} must be a source row (got role ${row.role})`
    );
  }
  const rendererBranch = manifestObj.rendererSourceBranch || {};
  assert.ok(
    Array.isArray(rendererBranch.paths) &&
      rendererBranch.paths.length === RENDERER_SOURCE_BRANCH.length,
    `rendererSourceBranch.paths must list all ${RENDERER_SOURCE_BRANCH.length} renderer files`
  );
  assert.equal(
    rendererBranch.frozenIn,
    'Phase 03',
    "rendererSourceBranch.frozenIn must be 'Phase 03'"
  );

  // ---- X1-R set-equality counts: verified from the frozen source (zero
  //      drift on the count contract) ----
  assert.ok(
    typeof manifestObj.x1rSetEquality === 'object' &&
      manifestObj.x1rSetEquality !== null,
    'manifest must carry an x1rSetEquality block'
  );
  for (const [key, expected] of Object.entries(X1R_SET_EQUALITY)) {
    assert.equal(
      manifestObj.x1rSetEquality[key],
      expected,
      `x1rSetEquality.${key} must be ${expected} (got ${manifestObj.x1rSetEquality[key]})`
    );
  }
  // The finalizer must have read the counts from the frozen X1-R + N1-R source
  // (not hardcoded alone) — the verifiedX1rCounts block records the source
  // provenance for each count.
  const verifiedCounts = manifestObj.verifiedX1rCounts || {};
  assert.ok(
    typeof verifiedCounts === 'object' && verifiedCounts !== null,
    'manifest must carry a verifiedX1rCounts block (counts read from frozen source)'
  );
  for (const [key, expected] of Object.entries(X1R_SET_EQUALITY)) {
    assert.equal(
      verifiedCounts[key],
      expected,
      `verifiedX1rCounts.${key} must be ${expected} (read from frozen source, got ${verifiedCounts[key]})`
    );
  }

  // ---- Zero source drift since the P07-T011 freeze: the regenerated SOURCE
  //      rows (product-swift + generated-swift, path + sha256) must be
  //      set-equal to the PROVISIONAL (P07-T008) source closure. This rejects
  //      every source path created afterward (no post-freeze new/changed
  //      source). ----
  const sourceDrift = manifestObj.sourceDriftVerification || {};
  assert.equal(
    sourceDrift.zeroDrift,
    true,
    'sourceDriftVerification.zeroDrift must be true (no post-freeze source path created)'
  );
  assert.equal(
    sourceDrift.addedSourcePaths,
    0,
    'sourceDriftVerification.addedSourcePaths must be 0 (no source path created after the freeze)'
  );
  assert.equal(
    sourceDrift.removedSourcePaths,
    0,
    'sourceDriftVerification.removedSourcePaths must be 0 (no frozen source path dropped)'
  );
  assert.equal(
    sourceDrift.contentDriftedSourcePaths,
    0,
    'sourceDriftVerification.contentDriftedSourcePaths must be 0 (no source content changed after the freeze — API frozen)'
  );
  // Cross-check: independently recompute the source-drift against the
  // committed provisional manifest.
  const provisional = JSON.parse(
    readFileSync(PROVISIONAL_MANIFEST_PATH, 'utf8')
  );
  const srcKey = (r) =>
    r.role === 'product-swift' || r.role === 'generated-swift'
      ? r.path + '::' + r.sha256
      : null;
  const regenSrcKeys = new Set(
    manifestObj.productSourceRows.map(srcKey).filter(Boolean)
  );
  const provSrcRows = provisional.productSourceRows
    .filter(
      (r) => r.role === 'product-swift' || r.role === 'generated-swift'
    )
    .map((r) => r.path + '::' + r.sha256);
  const provSrcSet = new Set(provSrcRows);
  const added = [...regenSrcKeys].filter((k) => !provSrcSet.has(k));
  const removed = provSrcRows.filter((k) => !regenSrcKeys.has(k));
  assert.equal(
    added.length,
    0,
    `independent recompute: ${added.length} source paths exist in the regenerated set but not the provisional (post-freeze new/changed source)`
  );
  assert.equal(
    removed.length,
    0,
    `independent recompute: ${removed.length} frozen source paths are absent from the regenerated set`
  );

  // ---- Frozen API closure provenance (P07-T011): every frozen public-API
  //      source path is present in the regenerated source set (no public-API
  //      source dropped) ----
  const frozenApiClosure = manifestObj.frozenApiClosure || {};
  assert.equal(
    frozenApiClosure.sourceCount,
    251,
    'frozenApiClosure.sourceCount must be 251 (P07-T011 frozenSourceSet)'
  );
  assert.ok(
    typeof frozenApiClosure.sourceSetDigest === 'string' &&
      frozenApiClosure.sourceSetDigest.length > 0,
    'frozenApiClosure.sourceSetDigest must be recorded'
  );
  const apiFrozen = JSON.parse(readFileSync(FROZEN_API_CLOSURE_PATH, 'utf8'));
  assert.equal(
    apiFrozen.frozenSourceSet.sourceCount,
    251,
    'P07-T011 frozenSourceSet.sourceCount must be 251'
  );
  // Every frozen public-API source path must be present in the regenerated set.
  const regenPaths = new Set(
    manifestObj.productSourceRows
      .filter(
        (r) => r.role === 'product-swift' || r.role === 'generated-swift'
      )
      .map((r) => r.path)
  );
  const missingApi = apiFrozen.frozenSourceSet.productSources.filter(
    (p) => !regenPaths.has(p)
  );
  assert.equal(
    missingApi.length,
    0,
    `every P07-T011 frozen public-API source path must be present in the regenerated source set (missing=${missingApi.length}: ${JSON.stringify(missingApi.slice(0, 3))})`
  );

  // ---- Zero drift: the frozen X1-R/G4-R/N1-R source manifest file hashes
  //      match the recorded SHA-256 anchors (exact provenance reproduction of
  //      the source contracts) ----
  assert.equal(
    fileSha256(FROZEN_X1R_MANIFEST_PATH),
    FROZEN_X1R_MANIFEST_SHA256,
    'frozen X1-R source manifest sha256 must match the anchor (source has drifted)'
  );
  assert.equal(
    fileSha256(FROZEN_G4R_AUTHORITATIVE_PATH),
    FROZEN_G4R_AUTHORITATIVE_SHA256,
    'frozen G4-R authoritative manifest sha256 must match the anchor'
  );
  assert.equal(
    fileSha256(FROZEN_N1R_LOCALIZATION_PATH),
    FROZEN_N1R_LOCALIZATION_SHA256,
    'frozen N1-R localization manifest sha256 must match the anchor'
  );
  assert.equal(
    fileSha256(FROZEN_API_CLOSURE_PATH),
    FROZEN_API_CLOSURE_SHA256,
    'frozen P07-T011 API closure manifest sha256 must match the anchor'
  );
  const frozenBaselines = manifestObj.frozenBaselines || {};
  assert.equal(
    frozenBaselines.x1r?.sha256,
    FROZEN_X1R_MANIFEST_SHA256,
    'final manifest must record the frozen X1-R source manifest sha256 (zero drift)'
  );
  assert.equal(
    frozenBaselines.g4r?.sha256,
    FROZEN_G4R_AUTHORITATIVE_SHA256,
    'final manifest must record the frozen G4-R authoritative manifest sha256 (zero drift)'
  );
  assert.equal(
    frozenBaselines.n1r?.sha256,
    FROZEN_N1R_LOCALIZATION_SHA256,
    'final manifest must record the frozen N1-R localization manifest sha256 (zero drift)'
  );
  assert.equal(
    frozenBaselines.apiClosure?.sha256,
    FROZEN_API_CLOSURE_SHA256,
    'final manifest must record the frozen P07-T011 API closure sha256 (zero drift)'
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

  // ---- Finite-runtime, native-style, explicit-cut inventory regenerated ----
  assert.ok(
    Array.isArray(manifestObj.runtimeStyleSubstitutions) &&
      manifestObj.runtimeStyleSubstitutions.length > 0,
    'runtimeStyleSubstitutions (finite-runtime) must be regenerated and non-empty'
  );
  assert.ok(
    Array.isArray(manifestObj.nativeStyleProjections) &&
      manifestObj.nativeStyleProjections.length > 0,
    'nativeStyleProjections (native-style) must be regenerated and non-empty'
  );
  assert.ok(
    Array.isArray(manifestObj.explicitCuts) &&
      manifestObj.explicitCuts.length > 0,
    'explicitCuts (explicit-cut) must be regenerated and non-empty'
  );
  assert.ok(
    Array.isArray(manifestObj.forbiddenRuntimeClasses) &&
      manifestObj.forbiddenRuntimeClasses.length > 0,
    'forbiddenRuntimeClasses must be regenerated and non-empty'
  );

  // ---- LICENSE.md notice input present in the repo (the notice input gate) ----
  assert.equal(
    existsSync(LICENSE_NOTICE_PATH),
    true,
    `LICENSE.md notice input must exist at ${LICENSE_NOTICE_PATH}`
  );

  // ---- JSON is well-formed and ends with a single trailing newline ----
  assert.ok(manifestJson.endsWith('\n'), 'manifest JSON must end with a trailing newline');
  assert.ok(
    !manifestJson.endsWith('\n\n'),
    'manifest JSON must end with exactly one trailing newline'
  );

  console.log(
    `FINAL_SOURCE_CLOSURE_MANIFEST rows=${manifestObj.productSourceRows.length} ` +
      `final=true drift=0 ` +
      `x1r=${manifestObj.x1rSetEquality.javascriptModules}/${manifestObj.x1rSetEquality.styleResources}/${manifestObj.x1rSetEquality.styleRuleNodes}/${manifestObj.x1rSetEquality.styleDeclarations}/${manifestObj.x1rSetEquality.directGlobalIdentifiers}/${manifestObj.x1rSetEquality.directGlobalReferences}/${manifestObj.x1rSetEquality.localizationMessages} ` +
      `renderer=${rendererBranch.paths.length} ` +
      `sourceDrift=${sourceDrift.addedSourcePaths}/${sourceDrift.removedSourcePaths}/${sourceDrift.contentDriftedSourcePaths}`
  );
});

// ---------------------------------------------------------------------------
// Determinism: re-running the finalizer must produce byte-identical output.
// ---------------------------------------------------------------------------

test('final-source-closure-manifest: byte-identical across re-runs (deterministic)', async () => {
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

  const tmpA = mkdtempSync(join(tmpdir(), 'fscm-a-'));
  const tmpB = mkdtempSync(join(tmpdir(), 'fscm-b-'));
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

test('final-source-closure-manifest: committed artifact exists and is up to date', async () => {
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
  const tmp = mkdtempSync(join(tmpdir(), 'fscm-committed-'));
  try {
    const outPath = join(tmp, 'manifest.json');
    finalizer.finalizeManifest({ outPath });
    const fresh = readFileSync(outPath, 'utf8');
    const committed = readFileSync(committedPath, 'utf8');
    assert.equal(
      committed,
      fresh,
      'committed final manifest artifact is stale: does not match freshly finalized output. ' +
        'Re-run: /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/finalize-source-closure-manifest.mjs'
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
