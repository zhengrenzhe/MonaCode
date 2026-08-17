// Tests/PlanStructureTests/ScopeProbeTests.mjs
//
// P00-T004 — Reproduce frozen scope, declaration, and instance-surface manifests.
//
// The frozen scope, instance surface, and public declaration graph are captured
// once in the F1-R3 / F1-R4 manifests and inherited unchanged by every later
// contract revision (G4-R, G5-R, ...). Three comparators reproduce them:
//
//   Comparators/probes/scope-probe.mjs            — frozen scope (3 products,
//                                                     platform, exclusions) +
//                                                     20 registry/namespace
//                                                     counts, cross-referenced
//                                                     against the provenance
//                                                     record.
//   Comparators/probes/instance-surface-probe.mjs — frozen instance surface
//                                                     (5 editor interfaces and
//                                                     their declaration counts).
//   Comparators/probes/public-declaration-probe.mjs — frozen public declaration
//                                                     graph (555 paths across 10
//                                                     namespaces) + the runtime
//                                                     cross-check against F1-R3.
//
// This test drives the three probes against the committed manifests (clean
// case) and against seeded identity drifts to prove each probe fails closed
// when an identity is swapped even though the aggregate count stays equal,
// then restores the manifests so the working tree is left untouched.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { existsSync, readFileSync, writeFileSync, rmSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const NODE = process.execPath;

const PROBES = {
  scope: resolve(REPO_ROOT, 'Comparators/probes/scope-probe.mjs'),
  instanceSurface: resolve(REPO_ROOT, 'Comparators/probes/instance-surface-probe.mjs'),
  publicDeclaration: resolve(REPO_ROOT, 'Comparators/probes/public-declaration-probe.mjs'),
};

const G5 = resolve(REPO_ROOT, 'docs/contracts/monaco-editor-0.56.0/g5-r/artifacts');
const SCOPE_MANIFEST = resolve(G5, 'monaco-0.56.0-f1r3-scope-manifest.json');
const INSTANCE_MANIFEST = resolve(G5, 'monaco-0.56.0-f1r3-instance-surface-manifest.json');
const DECL_MANIFEST = resolve(G5, 'monaco-0.56.0-f1r4-public-declaration-manifest.json');

function runProbe(probePath) {
  return spawnSync(NODE, [probePath], {
    encoding: 'utf8',
    cwd: REPO_ROOT,
  });
}

function backup(path) {
  writeFileSync(`${path}.bak`, readFileSync(path, 'utf8'), 'utf8');
}

function restore(path) {
  const bak = `${path}.bak`;
  if (existsSync(bak)) {
    writeFileSync(path, readFileSync(bak, 'utf8'), 'utf8');
    rmSync(bak, { force: true });
  }
}

function loadJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function saveJson(path, obj) {
  writeFileSync(path, JSON.stringify(obj, null, 2) + '\n', 'utf8');
}

// ---------------------------------------------------------------------------
// Existence checks.
// ---------------------------------------------------------------------------

test('the three probe files exist at their declared paths', () => {
  for (const [name, path] of Object.entries(PROBES)) {
    assert.equal(existsSync(path), true, `${name} probe must exist at ${path}`);
  }
});

// ---------------------------------------------------------------------------
// Green: the probes pass against the committed manifests.
// ---------------------------------------------------------------------------

test('scope-probe passes on the committed scope manifest', () => {
  restore(SCOPE_MANIFEST);
  const result = runProbe(PROBES.scope);
  if (result.status !== 0) {
    console.error('stdout:\n%s', result.stdout);
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'scope-probe must accept the committed scope manifest');
  assert.match(result.stderr, /OK/, 'scope-probe must report OK on success');
});

test('instance-surface-probe passes on the committed instance-surface manifest', () => {
  restore(INSTANCE_MANIFEST);
  const result = runProbe(PROBES.instanceSurface);
  if (result.status !== 0) {
    console.error('stdout:\n%s', result.stdout);
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'instance-surface-probe must accept the committed manifest');
  assert.match(result.stderr, /OK/, 'instance-surface-probe must report OK on success');
});

test('public-declaration-probe passes on the committed declaration manifest', () => {
  restore(DECL_MANIFEST);
  const result = runProbe(PROBES.publicDeclaration);
  if (result.status !== 0) {
    console.error('stdout:\n%s', result.stdout);
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'public-declaration-probe must accept the committed manifest');
  assert.match(result.stderr, /OK/, 'public-declaration-probe must report OK on success');
});

// ---------------------------------------------------------------------------
// Structural assertions on the committed scope manifest.
// ---------------------------------------------------------------------------

test('the committed scope manifest declares the 3 MonaCode products and macOS 26', () => {
  restore(SCOPE_MANIFEST);
  const pkg = readFileSync(resolve(REPO_ROOT, 'Package.swift'), 'utf8');
  const products = [];
  const re = /\.library\(\s*name:\s*"([^"]+)"/g;
  let m;
  while ((m = re.exec(pkg)) !== null) products.push(m[1]);
  assert.deepEqual(products, ['MonaCode', 'MonaCodeAppKit', 'MonaCodeSwiftUI']);
  assert.match(pkg, /\.macOS\(\s*"26\.0"\)/);
});

test('the scope manifest identity matches the locked provenance record', () => {
  restore(SCOPE_MANIFEST);
  const scope = loadJson(SCOPE_MANIFEST);
  const prov = loadJson(resolve(REPO_ROOT, 'Tools/PlanChecks/monaco-provenance.json'));
  assert.equal(scope.identity.tagCommit, prov.sourceCommit);
  assert.equal(scope.identity.npmTarSha256, prov.archives.find((a) => a.id === 'monaco-editor-npm').sha256);
  assert.equal(scope.identity.monacoDtsSha256, prov.declarations.monacoDts.sha256);
});

// ---------------------------------------------------------------------------
// Red: seeded identity drift must make the probes fail closed even when the
// aggregate count stays equal.
// ---------------------------------------------------------------------------

test('scope-probe rejects an identity swap that preserves the count', () => {
  backup(SCOPE_MANIFEST);
  try {
    const m = loadJson(SCOPE_MANIFEST);
    // Swap the first two builtinTheme ids. Count is unchanged (still 4) but
    // the id set is no longer the frozen set.
    const themes = m.registries.builtinThemes;
    const a = themes[0].id;
    themes[0].id = themes[1].id;
    themes[1].id = a;
    saveJson(SCOPE_MANIFEST, m);
    const result = runProbe(PROBES.scope);
    assert.equal(result.status, 1, 'scope-probe must exit 1 on identity drift');
    assert.match(result.stderr, /identity drift|duplicated/i, 'stderr must mention identity drift');
  } finally {
    restore(SCOPE_MANIFEST);
  }
});

test('scope-probe rejects a frozen-count drift', () => {
  backup(SCOPE_MANIFEST);
  try {
    const m = loadJson(SCOPE_MANIFEST);
    m.counts.actions = m.counts.actions + 1;
    saveJson(SCOPE_MANIFEST, m);
    const result = runProbe(PROBES.scope);
    assert.equal(result.status, 1, 'scope-probe must exit 1 on a count drift');
    assert.match(result.stderr, /counts\.actions/, 'stderr must name the drifted count');
  } finally {
    restore(SCOPE_MANIFEST);
  }
});

test('instance-surface-probe rejects an interface-count drift', () => {
  backup(INSTANCE_MANIFEST);
  try {
    const m = loadJson(INSTANCE_MANIFEST);
    m.interfaces.IEditor.ownDeclarationCount = m.interfaces.IEditor.ownDeclarationCount + 1;
    saveJson(INSTANCE_MANIFEST, m);
    const result = runProbe(PROBES.instanceSurface);
    assert.equal(result.status, 1, 'instance-surface-probe must exit 1 on a count drift');
    assert.match(result.stderr, /ownDeclarationCount/, 'stderr must name the drifted count');
  } finally {
    restore(INSTANCE_MANIFEST);
  }
});

test('instance-surface-probe rejects a base-interface drift', () => {
  backup(INSTANCE_MANIFEST);
  try {
    const m = loadJson(INSTANCE_MANIFEST);
    m.interfaces.IStandaloneCodeEditor.bases = ['IEditor'];
    saveJson(INSTANCE_MANIFEST, m);
    const result = runProbe(PROBES.instanceSurface);
    assert.equal(result.status, 1, 'instance-surface-probe must exit 1 on a base drift');
    assert.match(result.stderr, /bases/, 'stderr must name bases');
  } finally {
    restore(INSTANCE_MANIFEST);
  }
});

test('public-declaration-probe rejects a byNamespace count drift', () => {
  backup(DECL_MANIFEST);
  try {
    const m = loadJson(DECL_MANIFEST);
    m.counts.byNamespace.editor.declarations = m.counts.byNamespace.editor.declarations + 1;
    saveJson(DECL_MANIFEST, m);
    const result = runProbe(PROBES.publicDeclaration);
    assert.equal(result.status, 1, 'public-declaration-probe must exit 1 on a count drift');
    assert.match(result.stderr, /editor/, 'stderr must name the drifted namespace');
  } finally {
    restore(DECL_MANIFEST);
  }
});

test('public-declaration-probe rejects a broken runtime cross-check', () => {
  backup(DECL_MANIFEST);
  try {
    const m = loadJson(DECL_MANIFEST);
    m.runtimeCrossCheck.editor.exactSetMatch = false;
    saveJson(DECL_MANIFEST, m);
    const result = runProbe(PROBES.publicDeclaration);
    assert.equal(result.status, 1, 'public-declaration-probe must exit 1 on a broken cross-check');
    assert.match(result.stderr, /exactSetMatch/, 'stderr must name the cross-check field');
  } finally {
    restore(DECL_MANIFEST);
  }
});

// ---------------------------------------------------------------------------
// Working tree is clean after all seeded drifts.
// ---------------------------------------------------------------------------

test('working tree is clean after all seeded drifts', () => {
  restore(SCOPE_MANIFEST);
  restore(INSTANCE_MANIFEST);
  restore(DECL_MANIFEST);
  assert.equal(existsSync(`${SCOPE_MANIFEST}.bak`), false, 'scope backup must be removed');
  assert.equal(existsSync(`${INSTANCE_MANIFEST}.bak`), false, 'instance-surface backup must be removed');
  assert.equal(existsSync(`${DECL_MANIFEST}.bak`), false, 'declaration backup must be removed');
  for (const path of [PROBES.scope, PROBES.instanceSurface, PROBES.publicDeclaration]) {
    const result = runProbe(path);
    assert.equal(result.status, 0, `probe ${path} must pass on the restored manifests`);
  }
});
