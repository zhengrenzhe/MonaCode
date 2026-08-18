// Tests/PlanStructureTests/ReleaseBuildTests.mjs
//
// P08-T001 — Build the frozen three-product release package.
//
// This test drives `Tools/Release/build-release.sh` and verifies the three
// implementation operations from the G6-R plan leaf P08-T001:
//
//   1. Build arm64 macOS 26.0+ release artifacts for MonaCode, MonaCodeAppKit,
//      MonaCodeSwiftUI plus the sample-macOS-host executable.
//   2. Record compiler, SDK, deployment target, architecture, binary-UUID-
//      independent content hashes, and complete artifact paths.
//   3. Reject debug-only, unsigned-input, stale-source, extra-product, or
//      missing-target output.
//
// Contract gates (from the G6-R plan leaf P08-T001):
//
//   RED  : node --test <this file>
//          expectedExit=1 (build-release.sh not yet present)
//
//   GREEN: node --test <this file>
//          expectedExit=0 — the script builds + records + all gates pass.
//
// The build is REPRODUCIBLE: the script passes `-Xlinker -reproducible` so the
// linker emits a deterministic, content-derived LC_UUID (instead of a random
// one). Two builds of the same source therefore produce a byte-identical
// executable and the same sha256 content hash. The recorded hash is a content
// hash (sha256 of the artifact bytes), not the dwarfdump UUID — it is binary-
// UUID-independent (stable across reproducible builds).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, join } from 'node:path';
import {
  existsSync,
  readFileSync,
  writeFileSync,
  rmSync,
  mkdirSync,
  cpSync,
} from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const SCRIPT = resolve(REPO_ROOT, 'Tools/Release/build-release.sh');
const RELEASE_REAL = resolve(REPO_ROOT, '.build/arm64-apple-macosx/release');
const RELEASE_SYMLINK = resolve(REPO_ROOT, '.build/release');
const METADATA_PATH = resolve(RELEASE_SYMLINK, 'release-build-metadata.json');

const EXPECTED_PRODUCTS = ['MonaCode', 'MonaCodeAppKit', 'MonaCodeSwiftUI'];
const EXPECTED_EXEC = 'sample-macOS-host';
const SHA256_RE = /^[0-9a-f]{64}$/;

// --- helpers ---------------------------------------------------------------

function runScript(args = [], env = {}) {
  return spawnSync('bash', [SCRIPT, ...args], {
    encoding: 'utf8',
    cwd: REPO_ROOT,
    env: { ...process.env, ...env },
    timeout: 240000,
  });
}

function runCheckOnly(env = {}) {
  return runScript(['--check-only'], env);
}

function metadata() {
  assert.equal(existsSync(METADATA_PATH), true, 'metadata file must exist');
  return JSON.parse(readFileSync(METADATA_PATH, 'utf8'));
}

function artifactById(md, id) {
  const a = md.artifacts.find((x) => x.id === id);
  assert.ok(a, `artifact ${id} must be recorded in metadata`);
  return a;
}

function sha256File(absPath) {
  const r = spawnSync('shasum', ['-a', '256', absPath], { encoding: 'utf8' });
  assert.equal(r.status, 0, `shasum failed for ${absPath}`);
  return r.stdout.trim().split(/\s+/)[0];
}

// ---------------------------------------------------------------------------
// RED-phase anchor: the script must exist at its declared path.
// ---------------------------------------------------------------------------

test('the build-release script exists at its declared path', () => {
  assert.equal(existsSync(SCRIPT), true, `expected ${SCRIPT} to exist`);
});

// ---------------------------------------------------------------------------
// GREEN — Operation 1 + 2: the script builds the release artifacts and
// records complete provenance metadata.
// ---------------------------------------------------------------------------

test('the script builds the release artifacts and records metadata', () => {
  const r = runScript();
  if (r.status !== 0) {
    console.error('stdout:\n%s', r.stdout);
    console.error('stderr:\n%s', r.stderr);
  }
  assert.equal(r.status, 0, 'build-release.sh must exit 0 on the clean tree');

  const md = metadata();

  // Operation 2 — recorded fields.
  assert.equal(md.schemaVersion, 'monacode-release-build-v1');
  assert.equal(md.product, 'MonaCode');
  assert.equal(md.platform, 'macOS-26-arm64');
  assert.equal(md.buildConfig, 'release');
  assert.equal(md.deploymentTarget, 'macOS 26.0');
  assert.equal(md.architecture, 'arm64');
  assert.equal(md.freezeCommit, 'efe78e976b616116e0a0c1b5dcdb3fcd05419fbb');
  assert.match(md.sourceCommit || '', /^[0-9a-f]{40}$/, 'sourceCommit must be a 40-hex SHA-1');
  assert.ok(typeof md.swiftCompiler === 'string' && md.swiftCompiler.length > 0, 'swiftCompiler recorded');
  assert.ok(typeof md.macosSdk === 'string' && md.macosSdk.length > 0, 'macosSdk recorded');

  // Operation 1 — the four release artifacts are present + recorded.
  assert.ok(Array.isArray(md.artifacts) && md.artifacts.length === 4, 'exactly 4 release artifacts');

  for (const p of EXPECTED_PRODUCTS) {
    const a = artifactById(md, `${p}-module`);
    assert.equal(a.kind, 'library');
    assert.match(a.path, /Modules\/[^/]+\.swiftmodule$/);
    assert.match(a.sha256, SHA256_RE, `${p} sha256 must be 64 hex`);
    assert.ok(a.bytes > 0, `${p} bytes must be positive`);
    assert.equal(existsSync(resolve(REPO_ROOT, a.path)), true, `${p} artifact must exist at recorded path`);
    // Content hash must match a freshly computed shasum (reproducible content hash).
    assert.equal(a.sha256, sha256File(resolve(REPO_ROOT, a.path)), `${p} recorded hash must match content`);
  }

  const exe = artifactById(md, 'sample-macOS-host');
  assert.equal(exe.kind, 'executable');
  assert.equal(resolve(REPO_ROOT, exe.path), resolve(REPO_ROOT, '.build/release/sample-macOS-host'));
  assert.match(exe.sha256, SHA256_RE);
  assert.ok(exe.bytes > 0);
  assert.equal(existsSync(resolve(REPO_ROOT, exe.path)), true, 'executable artifact must exist');
  assert.equal(exe.sha256, sha256File(resolve(REPO_ROOT, exe.path)), 'executable recorded hash must match content');
  assert.equal(exe.architecture, 'arm64');
});

// ---------------------------------------------------------------------------
// GREEN — Reproducibility: two builds of the same source produce the same
// binary-UUID-independent content hash.
// ---------------------------------------------------------------------------

test('the build is reproducible — same content hash across rebuilds', () => {
  // First run (may be warm or cold).
  const r1 = runScript();
  assert.equal(r1.status, 0, 'first build must succeed');
  const md1 = metadata();
  const exe1 = artifactById(md1, 'sample-macOS-host');
  const monacode1 = artifactById(md1, 'MonaCode-module');

  // Second run (warm rebuild).
  const r2 = runScript();
  assert.equal(r2.status, 0, 'second build must succeed');
  const md2 = metadata();
  const exe2 = artifactById(md2, 'sample-macOS-host');
  const monacode2 = artifactById(md2, 'MonaCode-module');

  // The executable content hash is stable across rebuilds (binary-UUID-
  // independent: -Xlinker -reproducible makes the UUID deterministic, so the
  // content hash — not the dwarfdump UUID — is stable).
  assert.equal(exe1.sha256, exe2.sha256, 'executable content hash must be stable across rebuilds');
  assert.equal(monacode1.sha256, monacode2.sha256, 'swiftmodule content hash must be stable across rebuilds');
});

// ---------------------------------------------------------------------------
// GREEN — Operation 3: rejection gates. Each gate is exercised via
// --check-only against a seeded bad state, then reverted.
// ---------------------------------------------------------------------------

test('reject: missing-target — an absent expected artifact is rejected', () => {
  const modPath = resolve(RELEASE_REAL, 'Modules', 'MonaCode.swiftmodule');
  const backup = modPath + '.bak';
  cpSync(modPath, backup);
  try {
    rmSync(modPath, { force: true });
    const r = runCheckOnly();
    assert.notEqual(r.status, 0, 'must reject when an expected artifact is missing');
    assert.match(r.stderr, /missing-target/, 'must report missing-target');
  } finally {
    cpSync(backup, modPath);
    rmSync(backup, { force: true });
  }
});

test('reject: debug-only — no release executable is rejected', () => {
  const exe = resolve(RELEASE_REAL, EXPECTED_EXEC);
  const backup = exe + '.bak';
  cpSync(exe, backup);
  try {
    rmSync(exe, { force: true });
    const r = runCheckOnly();
    assert.notEqual(r.status, 0, 'must reject when the release executable is absent (debug-only)');
    assert.match(r.stderr, /debug-only|missing-target/, 'must report debug-only or missing-target');
  } finally {
    cpSync(backup, exe);
    rmSync(backup, { force: true });
  }
});

test('reject: extra-product — a foreign module artifact is rejected', () => {
  const foreign = resolve(RELEASE_REAL, 'Modules', 'ForeignProduct.swiftmodule');
  writeFileSync(foreign, 'not a real module', 'utf8');
  try {
    const r = runCheckOnly();
    assert.notEqual(r.status, 0, 'must reject a foreign module artifact');
    assert.match(r.stderr, /extra-product/, 'must report extra-product');
  } finally {
    rmSync(foreign, { force: true });
  }
});

test('reject: unsigned-input — uncommitted source changes are rejected', () => {
  const src = resolve(REPO_ROOT, 'Sources/MonaCode/Base/MonaMarker.swift');
  const orig = readFileSync(src, 'utf8');
  try {
    writeFileSync(src, orig + '\n// P08-T001 unsigned-input probe\n', 'utf8');
    const r = runCheckOnly();
    assert.notEqual(r.status, 0, 'must reject uncommitted source changes');
    assert.match(r.stderr, /unsigned-input/, 'must report unsigned-input');
  } finally {
    writeFileSync(src, orig, 'utf8');
  }
});

test('reject: stale-source — source drift since the freeze is rejected', () => {
  // A fake freeze commit that differs from HEAD on Sources/Package.swift →
  // every line of source reads as "drifted since freeze" → stale-source.
  const r = runCheckOnly({ MONACODE_FREEZE_COMMIT: '0000000000000000000000000000000000000000' });
  assert.notEqual(r.status, 0, 'must reject source drift since the freeze');
  assert.match(r.stderr, /stale-source/, 'must report stale-source');
});
