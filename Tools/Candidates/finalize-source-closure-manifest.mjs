// finalize-source-closure-manifest.mjs
//
// P08-T013 — Finalize MonaSourceClosureManifest from the release source set.
//
// This is the Node finalizer for the MonaCode FINAL source-closure manifest.
// It regenerates the COMPLETE product source, generated source, resource,
// notice, finite-runtime, native-style, and explicit-cut inventory from the
// FROZEN release source set (the Phase 07 source closure frozen at P07-T011),
// includes the renderer source branch frozen in Phase 03, rejects every
// source path created afterward (zero source drift since the freeze), verifies
// all X1-R set-equality counts and artifact hashes before finalization, and
// marks the manifest FINAL only after exact provenance reproduction (zero
// drift).
//
// The manifest is FINAL: identity.frozen = true, identity.final = true, and
// identity.provisional is absent. This supersedes the P07-T008 PROVISIONAL
// source-closure manifest (identity.provisional = true). Phase 09 acceptance
// reads this final manifest without re-running the finalizer.
//
// The finalizer reuses the P07-T008 provisional builder's buildProductSourceRows
// + validateClosure + the frozen runtime-style/native-style/explicit-cut
// tables to regenerate the rows, then adds the X1-R count verification (read
// from the frozen source), the zero source-drift gate (against the committed
// provisional closure), the renderer source branch inclusion gate, the frozen
// API closure (P07-T011) provenance, the source-artifact hash block, and the
// FINAL identity marker, and verifies zero drift against the frozen baselines.
//
// Sources (FROZEN):
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monacode-x1r-source-runtime-style-manifest.json   (X1-R baseline closure)
//     monacode-g4r-authoritative-manifest.json           (C04/C10 invariants)
//     monacode-n1r-localization-manifest.json           (2120 l10n messages)
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/
//     monacode-p07-t011-public-api-closure-manifest.json  (frozen API baseline)
//     monacode-p07-t008-source-closure-manifest.json      (provisional closure)
//   docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/
//     phase-08-release-candidate-distribution.md            (P08-T013 leaf)
//
// Product source roots (walked by the reused builder):
//   Sources/MonaCode/        (product target MonaCode)
//   Sources/MonaCodeAppKit/   (product target MonaCodeAppKit)
//   Sources/MonaCodeSwiftUI/  (product target MonaCodeSwiftUI)
//
// The API is FROZEN (P07-T011). The finalizer regenerates from the frozen
// release source — no public API changes. LICENSE.md is a sanctioned Phase-08
// resource (included, not rejected as a post-freeze source path — it is a
// resource, not source).
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/finalize-source-closure-manifest.mjs
//
// Writes:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p08-t013-source-closure-manifest.json
//
// Determinism: byte-identical across re-runs (stable key order, trailing
// newline, no non-deterministic data sources).

import { createHash } from 'node:crypto';
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  existsSync,
} from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Reuse the P07-T008 provisional builder's frozen tables + enumeration +
// validation logic. The finalizer regenerates the same rows then adds the
// final-specific zero-drift gates.
import {
  buildProductSourceRows,
  validateClosure,
  X1R_SET_EQUALITY,
  RUNTIME_STYLE_SUBSTITUTIONS,
  NATIVE_STYLE_PROJECTIONS,
  EXPLICIT_CUTS,
  FORBIDDEN_RUNTIME_CLASSES,
  MANIFEST_PATH as PROVISIONAL_MANIFEST_PATH_BUILDER,
} from './build-source-closure-manifest.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..');

export const FINAL_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p08-t013-source-closure-manifest.json'
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

const PROVISIONAL_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p07-t008-source-closure-manifest.json'
);

const IMPLEMENTATION_PLAN_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'implementation-plan',
  'phase-08-release-candidate-distribution.md'
);

const LICENSE_NOTICE_PATH = join(
  REPO_ROOT,
  'Sources',
  'MonaCode',
  'Generated',
  'LICENSE.md'
);

// The frozen source manifest SHA-256 anchors (with trailing LF). Recorded in
// the g5-r/g6-r SHA256SUMS and the g6-r authoritative manifest. These are the
// zero-drift anchors for the X1-R + G4-R + N1-R sources + the P07-T011 frozen
// API closure.
const FROZEN_X1R_MANIFEST_SHA256 =
  '516c91d905532e9c54e2b3691e74024c81f5887203e6b1cb9184e2c981aaa280';
const FROZEN_G4R_AUTHORITATIVE_SHA256 =
  'f4d0da0ff6c1ad90ab1376588260afd6c92c1eca236619449c9b6532b5e57021';
const FROZEN_N1R_LOCALIZATION_SHA256 =
  '4e91e4a40f752065629241c502bbcc0fb0e6925f0be28f03c7ffce1731aedb74';
const FROZEN_API_CLOSURE_SHA256 =
  '0aca883079e7d0978f59ed1fe9de1d4b2614368e1450e0df2b8f204381a623c6';

// The frozen X1-R set-equality count contract. The finalizer refuses to
// finalize unless the regenerated counts (read from the frozen X1-R + N1-R
// source) reproduce every frozen count exactly.
export const EXPECTED_X1R_SET_EQUALITY = {
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
// final manifest's product source rows (the renderer branch is frozen + included;
// no source path created after the freeze may appear).
const RENDERER_SOURCE_BRANCH_PATHS = [
  'Sources/MonaCodeAppKit/Rendering/MonaCoreGraphicsRenderer.swift',
  'Sources/MonaCodeAppKit/Rendering/MonaMetalRenderer.swift',
  'Sources/MonaCodeAppKit/Rendering/MonaRendererMetrics.swift',
  'Sources/MonaCodeAppKit/Rendering/MonaRenderSurface.swift',
  'Sources/MonaCodeAppKit/Rendering/MonaRenderTileCache.swift',
];

// ---------------------------------------------------------------------------
// 1. Zero-drift verification — the frozen X1-R + G4-R + N1-R source manifests
//    and the P07-T011 frozen API closure must hash to the recorded SHA-256
//    anchors. Any mismatch means a source contract has drifted and the
//    finalizer refuses to finalize.
// ---------------------------------------------------------------------------

export function verifySourceZeroDrift(
  x1rPath,
  g4rPath,
  n1rPath,
  apiClosurePath
) {
  const x1rHash = sha256File(x1rPath);
  if (x1rHash !== FROZEN_X1R_MANIFEST_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_X1R_SOURCE path=${x1rPath} regenerated=${x1rHash} frozen=${FROZEN_X1R_MANIFEST_SHA256}`
    );
  }
  const g4rHash = sha256File(g4rPath);
  if (g4rHash !== FROZEN_G4R_AUTHORITATIVE_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_G4R_SOURCE path=${g4rPath} regenerated=${g4rHash} frozen=${FROZEN_G4R_AUTHORITATIVE_SHA256}`
    );
  }
  const n1rHash = sha256File(n1rPath);
  if (n1rHash !== FROZEN_N1R_LOCALIZATION_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_N1R_SOURCE path=${n1rPath} regenerated=${n1rHash} frozen=${FROZEN_N1R_LOCALIZATION_SHA256}`
    );
  }
  const apiHash = sha256File(apiClosurePath);
  if (apiHash !== FROZEN_API_CLOSURE_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_API_CLOSURE path=${apiClosurePath} regenerated=${apiHash} frozen=${FROZEN_API_CLOSURE_SHA256}`
    );
  }
  return {
    x1rManifest: x1rHash,
    g4rManifest: g4rHash,
    n1rManifest: n1rHash,
    apiClosure: apiHash,
  };
}

// ---------------------------------------------------------------------------
// 2. X1-R set-equality count verification — read every count from the FROZEN
//    X1-R + N1-R source (not hardcoded alone) and verify it reproduces the
//    frozen count contract exactly (set equality on the count contract, zero
//    drift on counts). The finalizer refuses to finalize if any count drifted.
// ---------------------------------------------------------------------------

export function verifyX1rCountsFromSource(x1rSource, n1rSource) {
  const x1rModule = x1rSource.moduleAndResourceClosure;
  const x1rStyle = x1rSource.styleResourceClosure;
  const x1rGlobals = x1rSource.directGlobalClosure;
  const n1rCounts = n1rSource.counts;

  const actual = {
    javascriptModules: x1rModule.javascriptModules,
    styleResources: x1rModule.styleResources,
    styleRuleNodes: x1rStyle.sourceSyntaxScan.ruleNodes,
    styleDeclarations: x1rStyle.sourceSyntaxScan.declarations,
    directGlobalIdentifiers: x1rGlobals.identifierCount,
    directGlobalReferences: x1rGlobals.referenceCount,
    localizationMessages: n1rCounts.messageKeys,
  };

  const checks = [
    ['javascriptModules', actual.javascriptModules, EXPECTED_X1R_SET_EQUALITY.javascriptModules],
    ['styleResources', actual.styleResources, EXPECTED_X1R_SET_EQUALITY.styleResources],
    ['styleRuleNodes', actual.styleRuleNodes, EXPECTED_X1R_SET_EQUALITY.styleRuleNodes],
    ['styleDeclarations', actual.styleDeclarations, EXPECTED_X1R_SET_EQUALITY.styleDeclarations],
    ['directGlobalIdentifiers', actual.directGlobalIdentifiers, EXPECTED_X1R_SET_EQUALITY.directGlobalIdentifiers],
    ['directGlobalReferences', actual.directGlobalReferences, EXPECTED_X1R_SET_EQUALITY.directGlobalReferences],
    ['localizationMessages', actual.localizationMessages, EXPECTED_X1R_SET_EQUALITY.localizationMessages],
  ];

  for (const [label, got, expected] of checks) {
    if (got !== expected) {
      throw new Error(
        `X1R_SET_EQUALITY_MISMATCH ${label} actual=${got} expected=${expected}`
      );
    }
  }
  return actual;
}

// ---------------------------------------------------------------------------
// 3. Zero source-drift gate — the regenerated SOURCE rows (product-swift +
//    generated-swift, path + sha256) must be set-equal to the PROVISIONAL
//    (P07-T008) source closure frozen at P07-T011. This rejects every source
//    path created afterward (no post-freeze new source, no post-freeze changed
//    source, no dropped frozen source). The API is FROZEN; source drift is
//    zero. Resource/notice rows (including the sanctioned Phase-08 LICENSE.md)
//    are NOT subject to this source-path gate — they are resources, not source.
// ---------------------------------------------------------------------------

export function verifySourceSetZeroDrift(regenRows, provisionalRows) {
  const isSource = (r) =>
    r.role === 'product-swift' || r.role === 'generated-swift';
  const key = (r) => r.path + '::' + r.sha256;

  const regenSrc = regenRows.filter(isSource);
  const provSrc = provisionalRows.filter(isSource);

  const regenKeys = new Set(regenSrc.map(key));
  const provKeys = new Set(provSrc.map(key));

  // New source paths, or source paths whose content changed after the freeze.
  const added = regenSrc
    .filter((r) => !provKeys.has(key(r)))
    .map((r) => r.path);
  // Frozen source paths dropped from the regenerated set.
  const removed = provSrc
    .filter((r) => !regenKeys.has(key(r)))
    .map((r) => r.path);

  // Separate content drift (path present in both, sha256 differs) from new
  // paths (path absent from the provisional set).
  const provByPath = new Map(provSrc.map((r) => [r.path, r.sha256]));
  const newPaths = new Set(added);
  const contentDrifted = regenSrc
    .filter((r) => !newPaths.has(r.path) && provByPath.get(r.path) !== r.sha256)
    .map((r) => r.path);

  if (added.length > 0) {
    throw new Error(
      `DRIFT_POST_FREEZE_SOURCE_PATH count=${added.length} first=${added[0]} ` +
        '(source path created after the P07-T011 freeze — API is frozen)'
    );
  }
  if (removed.length > 0) {
    throw new Error(
      `DRIFT_FROZEN_SOURCE_PATH_DROPPED count=${removed.length} first=${removed[0]} ` +
        '(a frozen source path is absent from the regenerated release source set)'
    );
  }
  if (contentDrifted.length > 0) {
    throw new Error(
      `DRIFT_SOURCE_CONTENT count=${contentDrifted.length} first=${contentDrifted[0]} ` +
        '(source content changed after the P07-T011 freeze — API is frozen)'
    );
  }

  return {
    zeroDrift: true,
    regeneratedSourceRows: regenSrc.length,
    provisionalSourceRows: provSrc.length,
    addedSourcePaths: 0,
    removedSourcePaths: 0,
    contentDriftedSourcePaths: 0,
  };
}

// ---------------------------------------------------------------------------
// 4. Renderer source branch inclusion — the Phase 03 CG/Metal renderer source
//    branch must be included (every frozen renderer file appears as a source
//    row). The renderer branch was frozen in Phase 03 and is part of the
//    release source set.
// ---------------------------------------------------------------------------

export function verifyRendererBranch(regenRows) {
  const rowMap = new Map(regenRows.map((r) => [r.path, r]));
  const missing = [];
  for (const p of RENDERER_SOURCE_BRANCH_PATHS) {
    const row = rowMap.get(p);
    if (!row) {
      missing.push(p);
      continue;
    }
    if (row.role !== 'product-swift' && row.role !== 'generated-swift') {
      throw new Error(
        `RENDERER_BRANCH_NON_SOURCE path=${p} role=${row.role} (renderer files must be source rows)`
      );
    }
  }
  if (missing.length > 0) {
    throw new Error(
      `RENDERER_BRANCH_MISSING count=${missing.length} first=${missing[0]} ` +
        '(Phase 03 CG/Metal renderer source branch not included in the release source set)'
    );
  }
  return {
    frozenIn: 'Phase 03',
    paths: RENDERER_SOURCE_BRANCH_PATHS.slice(),
    count: RENDERER_SOURCE_BRANCH_PATHS.length,
  };
}

// ---------------------------------------------------------------------------
// 5. Frozen API closure (P07-T011) provenance — every frozen public-API
//    source path is present in the regenerated source set (no public-API source
//    was dropped). The P07-T011 frozenSourceSet records the API-freeze baseline
//    (sourceCount + sourceSetDigest); the finalizer records it and asserts
//    coverage.
// ---------------------------------------------------------------------------

export function verifyApiClosureProvenance(regenRows, apiClosure) {
  const fss = apiClosure.frozenSourceSet;
  const regenPaths = new Set(
    regenRows
      .filter(
        (r) => r.role === 'product-swift' || r.role === 'generated-swift'
      )
      .map((r) => r.path)
  );
  const missing = fss.productSources.filter((p) => !regenPaths.has(p));
  if (missing.length > 0) {
    throw new Error(
      `DRIFT_FROZEN_API_SOURCE_DROPPED count=${missing.length} first=${missing[0]} ` +
        '(a P07-T011 frozen public-API source path is absent from the regenerated source set)'
    );
  }
  return {
    path: FROZEN_API_CLOSURE_PATH,
    frozenAt: apiClosure.identity.frozenAt,
    sourceCount: fss.sourceCount,
    sourceSetDigest: fss.sourceSetDigest,
    coverageVerified: missing.length === 0,
  };
}

// ---------------------------------------------------------------------------
// 6. Source artifact hashing — every source artifact referenced by the
//    manifest (every product source row + the frozen contract artifacts +
//    LICENSE.md) gets a recorded SHA-256 (provenance + drift detection). The
//    finalizer verifies every product source row's recorded sha256 matches the
//    file on disk before finalization (artifact hashes verified).
// ---------------------------------------------------------------------------

function buildSourceArtifacts(rows) {
  const artifacts = {};
  for (const row of rows) {
    artifacts[row.path] = sha256File(join(REPO_ROOT, row.path));
  }
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-x1r-source-runtime-style-manifest.json'
  ] = sha256File(FROZEN_X1R_MANIFEST_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-g4r-authoritative-manifest.json'
  ] = sha256File(FROZEN_G4R_AUTHORITATIVE_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-n1r-localization-manifest.json'
  ] = sha256File(FROZEN_N1R_LOCALIZATION_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t011-public-api-closure-manifest.json'
  ] = sha256File(FROZEN_API_CLOSURE_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t008-source-closure-manifest.json'
  ] = sha256File(PROVISIONAL_MANIFEST_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-08-release-candidate-distribution.md'
  ] = sha256File(IMPLEMENTATION_PLAN_PATH);
  return artifacts;
}

// ---------------------------------------------------------------------------
// 7. Notice input — the LICENSE.md provenance is recorded (the notice input
//    the spec requires before marking final). LICENSE.md is a sanctioned
//    Phase-08 resource; it is included, not rejected as a post-freeze source
//    path (it is a resource, not source).
// ---------------------------------------------------------------------------

function buildNoticeInput() {
  const present = existsSync(LICENSE_NOTICE_PATH);
  if (!present) {
    throw new Error(
      `NOTICE_INPUT_ABSENT licensePath=${LICENSE_NOTICE_PATH} (P08-T003 notice input not present)`
    );
  }
  const content = readFileSync(LICENSE_NOTICE_PATH, 'utf8');
  return {
    present,
    licensePath: LICENSE_NOTICE_PATH,
    licenseSha256: sha256(content),
    role: 'resource',
    disposition: 'sanctioned Phase-08 resource (included, not rejected)',
  };
}

// ---------------------------------------------------------------------------
// 8. Counts block — recompute the role counts from the regenerated rows.
// ---------------------------------------------------------------------------

function buildCounts(rows) {
  return {
    productSwift: rows.filter((r) => r.role === 'product-swift').length,
    generatedSwift: rows.filter((r) => r.role === 'generated-swift').length,
    licenseNotices: rows.filter((r) => r.role === 'license-notice').length,
    resources: rows.filter((r) => r.role === 'resource').length,
    totalProductRows: rows.length,
    runtimeStyleSubstitutions: RUNTIME_STYLE_SUBSTITUTIONS.length,
    nativeStyleProjections: NATIVE_STYLE_PROJECTIONS.length,
    explicitCuts: EXPLICIT_CUTS.length,
    forbiddenRuntimeClasses: FORBIDDEN_RUNTIME_CLASSES.length,
  };
}

// ---------------------------------------------------------------------------
// 9. Final manifest assembly + deterministic JSON serialization.
// ---------------------------------------------------------------------------

/**
 * Assemble the FINAL source-closure manifest. Regenerates the complete product
 * source, generated source, resource, notice, finite-runtime, native-style, and
 * explicit-cut inventory from the frozen release source set; includes the
 * renderer source branch frozen in Phase 03; rejects every source path created
 * afterward (zero source drift since P07-T011); verifies all X1-R set-equality
 * counts and artifact hashes before finalization; and marks the manifest FINAL
 * only after exact provenance reproduction (zero drift). Returns the manifest
 * object. If outPath is provided, also writes the deterministic JSON; otherwise
 * writes to the committed artifact path.
 */
export function finalizeManifest({ outPath } = {}) {
  // ---- Zero-drift gate on the frozen source contracts (exact provenance
  //      anchors) ----
  const frozenHashes = verifySourceZeroDrift(
    FROZEN_X1R_MANIFEST_PATH,
    FROZEN_G4R_AUTHORITATIVE_PATH,
    FROZEN_N1R_LOCALIZATION_PATH,
    FROZEN_API_CLOSURE_PATH
  );

  const x1rSource = JSON.parse(readFileSync(FROZEN_X1R_MANIFEST_PATH, 'utf8'));
  const n1rSource = JSON.parse(readFileSync(FROZEN_N1R_LOCALIZATION_PATH, 'utf8'));
  const apiClosure = JSON.parse(readFileSync(FROZEN_API_CLOSURE_PATH, 'utf8'));
  const provisional = JSON.parse(readFileSync(PROVISIONAL_MANIFEST_PATH, 'utf8'));

  // ---- Regenerate the complete product source/resource/notice inventory from
  //      the frozen release source set (reusing the P07-T008 builder's
  //      enumeration + the frozen runtime-style/native-style/explicit-cut
  //      tables). validateClosure rejects absent paths, X1-R count drift, and
  //      forbidden runtime classes. ----
  const rows = buildProductSourceRows();
  validateClosure(rows, { ...X1R_SET_EQUALITY });

  // ---- Verify the X1-R set-equality counts read from the frozen source
  //      (zero drift on the count contract) ----
  const verifiedX1rCounts = verifyX1rCountsFromSource(x1rSource, n1rSource);

  // ---- Verify zero source drift since the P07-T011 freeze (reject every
  //      source path created afterward; LICENSE.md is a resource, not subject
  //      to this source-path gate) ----
  const sourceDriftVerification = verifySourceSetZeroDrift(
    rows,
    provisional.productSourceRows
  );

  // ---- Verify the renderer source branch frozen in Phase 03 is included ----
  const rendererSourceBranch = verifyRendererBranch(rows);

  // ---- Verify the P07-T011 frozen API closure provenance (every frozen
  //      public-API source path present) ----
  const frozenApiClosure = verifyApiClosureProvenance(rows, apiClosure);

  // ---- Verify every product source artifact hash before finalization
  //      (artifact hashes verified — zero drift on every repo source artifact) ----
  const sourceArtifacts = buildSourceArtifacts(rows);
  for (const row of rows) {
    const recomputed = sha256File(join(REPO_ROOT, row.path));
    if (recomputed !== row.sha256) {
      throw new Error(
        `ARTIFACT_HASH_DRIFT path=${row.path} row=${row.sha256} recomputed=${recomputed}`
      );
    }
  }

  // ---- Notice input (P08-T003 LICENSE.md — sanctioned Phase-08 resource) ----
  const noticeInput = buildNoticeInput();

  // ---- Counts block (deterministic key order) ----
  const counts = buildCounts(rows);

  const manifest = {
    schemaVersion: 1,
    identity: {
      product: 'MonaCode',
      revision: 'P08-T013-final-source-closure-manifest',
      baseline: 'monaco-editor@0.56.0',
      frozen: true,
      final: true,
      finalReason:
        'The X1-R source-runtime-style contract, the G4-R authoritative ' +
        'manifest, the N1-R localization manifest, and the P07-T011 public ' +
        'API closure are frozen; the regenerated complete product source, ' +
        'generated source, resource, notice, finite-runtime, native-style, ' +
        'and explicit-cut inventory is set-equal to the frozen X1-R counts ' +
        '(956/98/1281/3120/84/8221/2120) read from the frozen source with ' +
        'zero drift; the renderer source branch frozen in Phase 03 is ' +
        'included; every source path created after the P07-T011 freeze is ' +
        'rejected (zero source drift; the API is frozen); and every product ' +
        'source artifact hash is verified. This is the FINAL ' +
        'MonaSourceClosureManifest.',
    },
    frozenBaselines: {
      x1r: {
        path: FROZEN_X1R_MANIFEST_PATH,
        sha256: frozenHashes.x1rManifest,
        revision: x1rSource.identity.revision,
      },
      g4r: {
        path: FROZEN_G4R_AUTHORITATIVE_PATH,
        sha256: frozenHashes.g4rManifest,
      },
      n1r: {
        path: FROZEN_N1R_LOCALIZATION_PATH,
        sha256: frozenHashes.n1rManifest,
        revision: n1rSource.identity.revision,
      },
      apiClosure: {
        path: FROZEN_API_CLOSURE_PATH,
        sha256: frozenHashes.apiClosure,
        revision: apiClosure.identity.revision,
      },
    },
    frozenApiClosure,
    sources: {
      x1rManifest: frozenHashes.x1rManifest,
      g4rAuthoritativeManifest: frozenHashes.g4rManifest,
      n1rLocalizationManifest: frozenHashes.n1rManifest,
      frozenApiClosureManifest: frozenHashes.apiClosure,
      provisionalSourceClosureManifest: sha256File(PROVISIONAL_MANIFEST_PATH),
      implementationPlanPhase08: sha256File(IMPLEMENTATION_PLAN_PATH),
    },
    x1rSetEquality: { ...X1R_SET_EQUALITY },
    verifiedX1rCounts,
    counts,
    sourceDriftVerification,
    rendererSourceBranch,
    runtimeStyleSubstitutions: RUNTIME_STYLE_SUBSTITUTIONS.map((r) => ({ ...r })),
    nativeStyleProjections: NATIVE_STYLE_PROJECTIONS.map((r) => ({ ...r })),
    explicitCuts: EXPLICIT_CUTS.map((r) => ({ ...r })),
    forbiddenRuntimeClasses: FORBIDDEN_RUNTIME_CLASSES.slice(),
    productSourceRows: rows,
    noticeInput,
    sourceArtifacts,
  };

  // ---- Zero-drift gate: mark final only after exact provenance reproduction
  //      + zero source drift + renderer branch included + artifact hashes
  //      verified ----
  // verifySourceZeroDrift threw if a frozen source contract drifted.
  // verifyX1rCountsFromSource threw if any X1-R count drifted from the source.
  // verifySourceSetZeroDrift threw if a post-freeze source path appeared, a
  // frozen source path was dropped, or source content drifted.
  // verifyRendererBranch threw if a Phase 03 renderer file was missing.
  // verifyApiClosureProvenance threw if a frozen public-API source was dropped.
  // buildNoticeInput threw if LICENSE.md was absent.
  // The artifact-hash loop threw if any product source row's sha256 drifted
  // from the file on disk. If we reach here, drift is zero, the renderer
  // branch is included, every artifact hash is verified, and the manifest is
  // final.

  const json = stableStringify(manifest) + '\n';

  if (outPath) {
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, json);
  } else {
    mkdirSync(dirname(FINAL_MANIFEST_PATH), { recursive: true });
    writeFileSync(FINAL_MANIFEST_PATH, json);
  }

  // Stable summary line for CI/observability.
  process.stdout.write(
    `FINAL_SOURCE_CLOSURE_MANIFEST rows=${rows.length} ` +
      `final=true drift=0 ` +
      `x1r=${verifiedX1rCounts.javascriptModules}/${verifiedX1rCounts.styleResources}/${verifiedX1rCounts.styleRuleNodes}/${verifiedX1rCounts.styleDeclarations}/${verifiedX1rCounts.directGlobalIdentifiers}/${verifiedX1rCounts.directGlobalReferences}/${verifiedX1rCounts.localizationMessages} ` +
      `renderer=${rendererSourceBranch.count} ` +
      `sourceDrift=${sourceDriftVerification.addedSourcePaths}/${sourceDriftVerification.removedSourcePaths}/${sourceDriftVerification.contentDriftedSourcePaths}\n`
  );

  return manifest;
}

// ---------------------------------------------------------------------------
// Utilities.
// ---------------------------------------------------------------------------

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

function sha256File(path) {
  return sha256(readFileSync(path, 'utf8'));
}

/**
 * Deterministic JSON stringifier. Produces stable key order by sorting keys
 * at every object level, with 2-space indentation. This guarantees
 * byte-identical output across re-runs regardless of object key insertion
 * order.
 */
function stableStringify(value, indent) {
  const ind = indent === undefined ? 0 : indent;
  const pad = ' '.repeat(ind * 2);
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    if (value.length === 0) return '[]';
    const inner = ' '.repeat((ind + 1) * 2);
    const items = value.map((v) => inner + stableStringify(v, ind + 1));
    return '[\n' + items.join(',\n') + '\n' + pad + ']';
  }
  const keys = Object.keys(value).sort();
  if (keys.length === 0) return '{}';
  const inner = ' '.repeat((ind + 1) * 2);
  const pairs = keys.map(
    (k) => inner + JSON.stringify(k) + ': ' + stableStringify(value[k], ind + 1)
  );
  return '{\n' + pairs.join(',\n') + '\n' + pad + '}';
}

// When invoked directly, write the final manifest to the committed artifact path.
const isMain =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith('finalize-source-closure-manifest.mjs');
if (isMain) {
  finalizeManifest({});
}
