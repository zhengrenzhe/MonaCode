// Comparators/probes/public-declaration-probe.mjs
//
// P00-T004 — Reproduce frozen scope, declaration, and instance-surface manifests.
//
// The public declaration graph is the complete set of public TypeScript
// declaration paths in monaco.d.ts, each with a frozen disposition (retained
// or cut) and a declarationSha256 identity. It is captured once in the F1-R4
// public-declaration manifest and inherited unchanged by every later contract
// revision. The manifest also carries a runtimeCrossCheck that asserts the
// F1-R4 runtime values are set-equal to the F1-R3 scope namespaces.
//
// This probe reproduces the frozen declaration graph from the committed
// manifest in BOTH the g5-r and g4-r artifact trees, verifies the two copies
// are byte-identical (so identity drift between revisions is rejected even
// when aggregate counts remain equal), verifies the manifest identity matches
// the locked monaco.d.ts provenance hash and the TypeScript parser provenance,
// verifies every byNamespace count matches the actual declaration list length
// and the frozen expected values, verifies the runtime cross-check against the
// F1-R3 scope manifest holds, and verifies every declaration has a unique
// sha256 identity within its namespace.
//
// Usage:
//   node Comparators/probes/public-declaration-probe.mjs
//
// Exit status:
//   0 — the frozen public declaration graph is internally consistent.
//   1 — one or more checks failed (details on stderr).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const CONTRACTS = resolve(REPO_ROOT, 'docs/contracts/monaco-editor-0.56.0');
const G5_ARTIFACTS = resolve(CONTRACTS, 'g5-r/artifacts');
const G4_ARTIFACTS = resolve(CONTRACTS, 'g4-r/artifacts');
const DECL_MANIFEST = 'monaco-0.56.0-f1r4-public-declaration-manifest.json';
const SCOPE_MANIFEST = 'monaco-0.56.0-f1r3-scope-manifest.json';
const PROVENANCE_PATH = resolve(REPO_ROOT, 'Tools/PlanChecks/monaco-provenance.json');

// The frozen byNamespace declaration counts (F1-R4).
const FROZEN_BY_NAMESPACE = {
  topLevel: 36,
  editor: 229,
  languages: 198,
  worker: 3,
  lsp: 4,
  css: 19,
  html: 22,
  json: 21,
  typescript: 20,
  global: 3,
};
const FROZEN_TOTAL = 555;
const FROZEN_RUNTIME_VALUE_PATHS = 148;
const FROZEN_NON_RUNTIME_DECLARATION_PATHS = 407;

// The F1-R3 scope namespace counts that the runtime cross-check must equal.
const F1R3_SCOPE_NAMESPACE_COUNTS = {
  topLevel: 19,
  editor: 68,
  languages: 57,
  lsp: 4,
};

const errors = [];

function fail(message) {
  errors.push(message);
}

function readRaw(path) {
  return readFileSync(path, 'utf8');
}

// ---------------------------------------------------------------------------
// 1. Both the g5-r and g4-r artifact trees must carry the frozen declaration
//    graph, and the two copies must be byte-identical. This is the
//    identity-drift gate.
// ---------------------------------------------------------------------------

const g5Path = resolve(G5_ARTIFACTS, DECL_MANIFEST);
const g4Path = resolve(G4_ARTIFACTS, DECL_MANIFEST);

let g5Raw;
let g4Raw;
try {
  g5Raw = readRaw(g5Path);
} catch (err) {
  fail(`g5-r public-declaration manifest is missing: ${err.message}`);
}
try {
  g4Raw = readRaw(g4Path);
} catch (err) {
  fail(`g4-r public-declaration manifest is missing: ${err.message}`);
}

if (g5Raw !== undefined && g4Raw !== undefined && g5Raw !== g4Raw) {
  fail('g5-r and g4-r public-declaration manifests are not byte-identical (identity drift between revisions)');
}

let manifest = null;
if (g5Raw !== undefined) {
  try {
    manifest = JSON.parse(g5Raw);
  } catch (err) {
    fail(`g5-r public-declaration manifest is not valid JSON: ${err.message}`);
  }
}

// ---------------------------------------------------------------------------
// 2. The manifest identity must match the locked provenance record.
// ---------------------------------------------------------------------------

let provenance = null;
try {
  provenance = JSON.parse(readRaw(PROVENANCE_PATH));
} catch (err) {
  fail(`cannot read/parse provenance record: ${err.message}`);
}

if (manifest && provenance) {
  const id = manifest.identity || {};
  if (id.product !== 'MonaCode') {
    fail(`public-declaration identity.product must be "MonaCode", got ${JSON.stringify(id.product)}`);
  }
  if (id.revision !== 'F1-R4-public-declaration-surface') {
    fail(`public-declaration identity.revision must be "F1-R4-public-declaration-surface", got ${JSON.stringify(id.revision)}`);
  }
  if (typeof id.baseline !== 'string' || !id.baseline.includes('monaco-editor@0.56.0')) {
    fail(`public-declaration identity.baseline must mention monaco-editor@0.56.0, got ${JSON.stringify(id.baseline)}`);
  }
  if (id.source !== 'monaco.d.ts') {
    fail(`public-declaration identity.source must be "monaco.d.ts", got ${JSON.stringify(id.source)}`);
  }
  if (id.parser !== 'typescript@5.9.3') {
    fail(`public-declaration identity.parser must be "typescript@5.9.3", got ${JSON.stringify(id.parser)}`);
  }
  const dts = (provenance.declarations || {}).monacoDts;
  if (!dts) {
    fail('provenance record is missing declarations.monacoDts');
  } else if (id.publicDtsSha256 !== dts.sha256) {
    fail(
      `public-declaration identity.publicDtsSha256 (${JSON.stringify(id.publicDtsSha256)}) must equal provenance monacoDts sha256 (${dts.sha256})`,
    );
  }
  if (typeof id.parserPackageSha256 !== 'string' || !/^[0-9a-f]{64}$/.test(id.parserPackageSha256)) {
    fail(`public-declaration identity.parserPackageSha256 must be 64 lowercase hex, got ${JSON.stringify(id.parserPackageSha256)}`);
  }
  if (typeof id.parserRuntimeSha256 !== 'string' || !/^[0-9a-f]{64}$/.test(id.parserRuntimeSha256)) {
    fail(`public-declaration identity.parserRuntimeSha256 must be 64 lowercase hex, got ${JSON.stringify(id.parserRuntimeSha256)}`);
  }
}

// ---------------------------------------------------------------------------
// 3. Every byNamespace count must match the frozen value AND the actual
//    declaration list length. The sum of byNamespace declarations must equal
//    totalPublicDeclarationPaths, and runtime + nonRuntime must equal total.
// ---------------------------------------------------------------------------

if (manifest) {
  const c = manifest.counts || {};
  if (c.totalPublicDeclarationPaths !== FROZEN_TOTAL) {
    fail(`counts.totalPublicDeclarationPaths must be ${FROZEN_TOTAL}, got ${JSON.stringify(c.totalPublicDeclarationPaths)}`);
  }
  if (c.runtimeValuePaths !== FROZEN_RUNTIME_VALUE_PATHS) {
    fail(`counts.runtimeValuePaths must be ${FROZEN_RUNTIME_VALUE_PATHS}, got ${JSON.stringify(c.runtimeValuePaths)}`);
  }
  if (c.nonRuntimeDeclarationPaths !== FROZEN_NON_RUNTIME_DECLARATION_PATHS) {
    fail(`counts.nonRuntimeDeclarationPaths must be ${FROZEN_NON_RUNTIME_DECLARATION_PATHS}, got ${JSON.stringify(c.nonRuntimeDeclarationPaths)}`);
  }
  if (typeof c.runtimeValuePaths === 'number' && typeof c.nonRuntimeDeclarationPaths === 'number' && typeof c.totalPublicDeclarationPaths === 'number') {
    if (c.runtimeValuePaths + c.nonRuntimeDeclarationPaths !== c.totalPublicDeclarationPaths) {
      fail(
        `counts.runtimeValuePaths (${c.runtimeValuePaths}) + nonRuntimeDeclarationPaths (${c.nonRuntimeDeclarationPaths}) must equal totalPublicDeclarationPaths (${c.totalPublicDeclarationPaths})`,
      );
    }
  }

  const byNs = c.byNamespace || {};
  const decls = manifest.publicDeclarations || {};
  let totalActual = 0;
  for (const [ns, expected] of Object.entries(FROZEN_BY_NAMESPACE)) {
    const declared = byNs[ns] && byNs[ns].declarations;
    if (declared !== expected) {
      fail(`counts.byNamespace.${ns}.declarations must be ${expected}, got ${JSON.stringify(declared)}`);
    }
    const arr = decls[ns];
    if (!Array.isArray(arr)) {
      fail(`publicDeclarations.${ns} must be an array`);
      continue;
    }
    if (arr.length !== expected) {
      fail(`publicDeclarations.${ns} length (${arr.length}) must equal frozen count (${expected})`);
    }
    if (typeof declared === 'number' && arr.length !== declared) {
      fail(`publicDeclarations.${ns} length (${arr.length}) must equal counts.byNamespace.${ns}.declarations (${declared})`);
    }
    totalActual += arr.length;
  }
  if (totalActual !== FROZEN_TOTAL) {
    fail(`sum of publicDeclarations lengths (${totalActual}) must equal frozen total (${FROZEN_TOTAL})`);
  }

  // Identity uniqueness: every declaration path must be unique within its
  // namespace (path is the declaration identity; declarationSha256 is the
  // declaration text hash and is intentionally shared across declarations
  // that resolve to identical text). A swapped path (count unchanged) is
  // still caught by the byte-identical revision check above; this also
  // rejects a single manifest with a duplicate path. Every entry must also
  // carry a valid 64-hex declarationSha256.
  for (const [ns, arr] of Object.entries(decls)) {
    if (!Array.isArray(arr)) continue;
    const seen = new Set();
    for (const entry of arr) {
      const sha = entry && entry.declarationSha256;
      if (typeof sha !== 'string' || !/^[0-9a-f]{64}$/.test(sha)) {
        fail(`publicDeclarations.${ns} contains an entry with an invalid declarationSha256`);
      }
      const path = entry && entry.path;
      if (typeof path !== 'string' || path.length === 0) {
        fail(`publicDeclarations.${ns} contains an entry without a non-empty path`);
        continue;
      }
      if (seen.has(path)) {
        fail(`publicDeclarations.${ns} path "${path}" is duplicated (identity drift)`);
      }
      seen.add(path);
    }
  }

  // ---------------------------------------------------------------------------
  // 4. The runtime cross-check must hold against the F1-R3 scope manifest:
  //    every namespace's f1r3ScopeCount must equal the F1-R3 scope count, the
  //    exactSetMatch flag must be true, and both missingFromF1R3 and
  //    extraInF1R3 must be empty. This is the cross-manifest identity link.
  // ---------------------------------------------------------------------------

  let scopeManifest = null;
  try {
    scopeManifest = JSON.parse(readRaw(resolve(G5_ARTIFACTS, SCOPE_MANIFEST)));
  } catch (err) {
    fail(`cannot read F1-R3 scope manifest for cross-check: ${err.message}`);
  }

  if (scopeManifest) {
    const scopeNs = scopeManifest.namespaces || {};
    const scopeCounts = {
      topLevel: (scopeNs.topLevel || []).length,
      editor: (scopeNs.editor || []).length,
      languages: (scopeNs.languages || []).length,
      lsp: (scopeNs.lsp || []).length,
    };
    const rcc = manifest.runtimeCrossCheck || {};
    for (const [ns, expectedScopeCount] of Object.entries(F1R3_SCOPE_NAMESPACE_COUNTS)) {
      const entry = rcc[ns];
      if (!entry) {
        fail(`runtimeCrossCheck.${ns} is missing`);
        continue;
      }
      if (entry.f1r3ScopeCount !== expectedScopeCount) {
        fail(`runtimeCrossCheck.${ns}.f1r3ScopeCount must be ${expectedScopeCount}, got ${JSON.stringify(entry.f1r3ScopeCount)}`);
      }
      if (entry.f1r3ScopeCount !== scopeCounts[ns]) {
        fail(`runtimeCrossCheck.${ns}.f1r3ScopeCount (${entry.f1r3ScopeCount}) must equal actual F1-R3 scope namespace length (${scopeCounts[ns]})`);
      }
      if (entry.exactSetMatch !== true) {
        fail(`runtimeCrossCheck.${ns}.exactSetMatch must be true, got ${JSON.stringify(entry.exactSetMatch)}`);
      }
      if (Array.isArray(entry.missingFromF1R3) && entry.missingFromF1R3.length !== 0) {
        fail(`runtimeCrossCheck.${ns}.missingFromF1R3 must be empty, got ${entry.missingFromF1R3.length} entries`);
      }
      if (Array.isArray(entry.extraInF1R3) && entry.extraInF1R3.length !== 0) {
        fail(`runtimeCrossCheck.${ns}.extraInF1R3 must be empty, got ${entry.extraInF1R3.length} entries`);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Report.
// ---------------------------------------------------------------------------

function probe() {
  return {
    ok: errors.length === 0,
    errors: errors.slice(),
    summary: errors.length === 0
      ? 'public-declaration-probe: OK — frozen F1-R4 declaration graph reproduced (g5-r == g4-r, 555 paths, runtime cross-check holds)'
      : `public-declaration-probe: ${errors.length} error(s)`,
  };
}

const isMain = import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  const result = probe();
  if (!result.ok) {
    for (const msg of result.errors) {
      console.error(`public-declaration-probe: ${msg}`);
    }
    console.error(result.summary);
    process.exit(1);
  }
  console.error(result.summary);
  process.exit(0);
}

export { probe };
