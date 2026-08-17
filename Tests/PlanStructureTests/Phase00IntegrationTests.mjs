// Tests/PlanStructureTests/Phase00IntegrationTests.mjs
//
// P00-T012 — Integrate Phase 00 gates without claiming product evidence.
//
// This is the single structural gate that wires every Phase 00 test and
// preflight together. It verifies STRUCTURE — that every gate file exists and
// every checker exits 0 — without claiming empirical product evidence. The
// output state is `planned` or `structurally verified`, never `passed`: no
// gate here executes a Monaco model, runs a benchmark, or records a verdict.
// Empirical evidence is deferred to future product execution.
//
// The gate FAILS when any Phase 00 gate (comparator, scope, privacy,
// statistics, font, cold-launch, display, module-boundary) is absent.
//
// The P00-T003 provenance tests (retained verbatim below) double as the
// comparator-provenance gate: they verify the committed monaco-provenance.json
// is internally consistent under network=forbidden and reject seeded
// corruptions, then restore the record so the working tree is left untouched.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const NODE = process.execPath;
const SWIFT = '/usr/bin/swift';
const BASH = '/bin/bash';

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/** Resolve a repo-relative path. */
function r(rel) { return resolve(REPO_ROOT, rel); }

/** Return true when a repo-relative path exists on disk. */
function exists(rel) { return existsSync(r(rel)); }

/** Run a Node script (repo-relative path) with network forbidden by contract. */
function runNode(scriptRel) {
  return spawnSync(NODE, [r(scriptRel)], { encoding: 'utf8', cwd: REPO_ROOT });
}

/** Run a bash script (repo-relative path) with the given positional args. */
function runBash(scriptRel, ...args) {
  return spawnSync(BASH, [r(scriptRel), ...args], { encoding: 'utf8', cwd: REPO_ROOT });
}

// ===========================================================================
// P00-T001 — Package.swift + package-graph checker.
// Gate: comparator + module-boundary (the package graph is the structural
// spine that every later gate hangs off).
// ===========================================================================

test('P00-T001: Package.swift exists at the repo root', () => {
  assert.equal(exists('Package.swift'), true);
});

test('P00-T001: the package-graph checker passes (products=3, nonProductTargets=3, fixtureTargets=0)', () => {
  const dump = spawnSync(SWIFT, ['package', 'dump-package'], {
    encoding: 'utf8', cwd: REPO_ROOT,
  });
  assert.equal(dump.status, 0, 'swift package dump-package must succeed');
  const checker = r('docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs');
  assert.equal(existsSync(checker), true, 'assert-package-graph.mjs must exist');
  const result = spawnSync(NODE, [checker], {
    encoding: 'utf8', cwd: REPO_ROOT, input: dump.stdout,
  });
  assert.equal(result.status, 0, 'package-graph checker must exit 0');
  assert.match(result.stdout, /products=3 nonProductTargets=3 fixtureTargets=0/);
  assert.doesNotMatch(result.stdout, /MISMATCH/, 'graph must not mismatch');
});

// ===========================================================================
// P00-T002 — forbidden-core-imports.sh + Foundation-only boundary.
// Gate: module-boundary (MonaCode is Foundation-only).
// ===========================================================================

test('P00-T002: forbidden-core-imports.sh exists at its declared path', () => {
  assert.equal(exists('Tools/PlanChecks/forbidden-core-imports.sh'), true);
});

test('P00-T002: the Foundation-only boundary is enforced on the clean tree', () => {
  const result = runBash('Tools/PlanChecks/forbidden-core-imports.sh', 'Sources/MonaCode');
  if (result.status !== 0) {
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'MonaCode sources must be Foundation-only');
});

// ===========================================================================
// P00-T003 — verify-provenance.mjs + monaco-provenance.json.
// Gate: comparator provenance (Monaco 0.56.0 M0 + M1 lock).
//
// The Monaco comparator oracles are large archives that live outside the
// repository (disposition=temporary). What the repository pins is a provenance
// record — monaco-provenance.json — that locks every archive's URL, SHA-256,
// byte count, and archive-entry count, plus the monaco.d.ts declaration hash.
// The checker (verify-provenance.mjs) verifies that record is internally
// consistent under network=forbidden (no download).
//
// The tests below drive the checker against the committed record (clean case)
// and against seeded corruptions to prove the gate fails closed when metadata
// drifts, then restore the record so the working tree is left untouched.
// ===========================================================================

const CHECKER = r('Tools/PlanChecks/verify-provenance.mjs');
const RECORD = r('Tools/PlanChecks/monaco-provenance.json');
const BACKUP = `${RECORD}.bak`;

function runChecker() {
  return spawnSync(NODE, [CHECKER], { encoding: 'utf8', cwd: REPO_ROOT });
}

function loadRecord() {
  return JSON.parse(readFileSync(RECORD, 'utf8'));
}

function saveRecord(obj) {
  writeFileSync(RECORD, JSON.stringify(obj, null, 2) + '\n', 'utf8');
}

function backupRecord() {
  writeFileSync(BACKUP, readFileSync(RECORD, 'utf8'), 'utf8');
}

function restoreRecord() {
  if (existsSync(BACKUP)) {
    writeFileSync(RECORD, readFileSync(BACKUP, 'utf8'), 'utf8');
    rmSync(BACKUP, { force: true });
  }
}

test('P00-T003: the provenance checker exists at its declared path', () => {
  assert.equal(existsSync(CHECKER), true);
});

test('P00-T003: the provenance record exists at its declared path', () => {
  assert.equal(existsSync(RECORD), true);
});

test('P00-T003: provenance checker exits 0 on the committed record', () => {
  restoreRecord();
  const result = runChecker();
  if (result.status !== 0) {
    console.error('stdout:\n%s', result.stdout);
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'checker must accept the committed provenance record');
  assert.match(result.stderr, /OK/, 'checker must report OK on success');
});

test('P00-T003: the record pins Monaco 0.56.0 and the source commit', () => {
  restoreRecord();
  const rec = loadRecord();
  assert.equal(rec.monacoVersion, '0.56.0');
  assert.equal(rec.sourceCommit, '13f0c872dcf352815cc28d92dfff496c9839ea5c');
  assert.match(rec.sourceCommit, /^[0-9a-f]{40}$/, 'sourceCommit must be a 40-hex SHA-1');
});

test('P00-T003: the record declares exactly 3 archives with HTTPS URLs and SHA-256 hashes', () => {
  restoreRecord();
  const rec = loadRecord();
  assert.equal(rec.archives.length, 3);
  const ids = new Set();
  for (const arc of rec.archives) {
    assert.ok(arc.id, 'archive must have an id');
    assert.ok(!ids.has(arc.id), `archive id "${arc.id}" must be unique`);
    ids.add(arc.id);
    assert.equal(new URL(arc.url).protocol, 'https:', `archive "${arc.id}" url must be HTTPS`);
    assert.equal(arc.disposition, 'temporary', `archive "${arc.id}" disposition must be temporary`);
    assert.match(arc.sha256, /^[0-9a-f]{64}$/, `archive "${arc.id}" sha256 must be 64 lowercase hex`);
    assert.ok(arc.bytes > 0, `archive "${arc.id}" bytes must be positive`);
    assert.ok(arc.entries > 0, `archive "${arc.id}" entries must be positive`);
  }
});

test('P00-T003: the record locks the expected archive entry counts', () => {
  restoreRecord();
  const rec = loadRecord();
  const byId = Object.fromEntries(rec.archives.map((a) => [a.id, a]));
  assert.equal(byId['monaco-editor-npm'].entries, 1909);
  assert.equal(byId['monaco-editor-core-final-npm'].entries, 2112);
  const tag = byId['monaco-source-tag'];
  assert.equal(tag.entries, 1293);
  assert.equal(tag.regularFiles, 993);
  assert.equal(tag.directories, 300);
  assert.equal(tag.regularFiles + tag.directories, tag.entries);
});

test('P00-T003: the record locks the monaco.d.ts declaration hash and size', () => {
  restoreRecord();
  const rec = loadRecord();
  const dts = rec.declarations.monacoDts;
  assert.equal(dts.sha256, 'fbbab04ba04224a04b2bc3243e536d1af6e26d14eb00fe8b3177bf3daef8d3f2');
  assert.equal(dts.bytes, 327877);
  assert.equal(dts.archiveId, 'monaco-editor-npm');
  assert.equal(dts.path, 'package/monaco.d.ts');
});

test('P00-T003: checker rejects a corrupted SHA-256', () => {
  backupRecord();
  try {
    const rec = loadRecord();
    rec.archives[0].sha256 = '0'.repeat(63) + 'g'; // not hex
    saveRecord(rec);
    const result = runChecker();
    assert.equal(result.status, 1, 'checker must exit 1 on a bad sha256');
    assert.match(result.stderr, /sha256/, 'stderr must mention sha256');
  } finally {
    restoreRecord();
  }
});

test('P00-T003: checker rejects a non-HTTPS URL', () => {
  backupRecord();
  try {
    const rec = loadRecord();
    rec.archives[1].url = 'http://insecure.example/monaco.tgz';
    rec.archives[1].host = 'insecure.example';
    saveRecord(rec);
    const result = runChecker();
    assert.equal(result.status, 1, 'checker must exit 1 on a non-HTTPS url');
    assert.match(result.stderr, /url/, 'stderr must mention url');
  } finally {
    restoreRecord();
  }
});

test('P00-T003: checker rejects a duplicate archive id', () => {
  backupRecord();
  try {
    const rec = loadRecord();
    rec.archives[2].id = rec.archives[0].id;
    saveRecord(rec);
    const result = runChecker();
    assert.equal(result.status, 1, 'checker must exit 1 on a duplicate id');
    assert.match(result.stderr, /duplicated/, 'stderr must mention duplication');
  } finally {
    restoreRecord();
  }
});

test('P00-T003: checker rejects a monaco.d.ts archiveId that references no archive', () => {
  backupRecord();
  try {
    const rec = loadRecord();
    rec.declarations.monacoDts.archiveId = 'does-not-exist';
    saveRecord(rec);
    const result = runChecker();
    assert.equal(result.status, 1, 'checker must exit 1 on a dangling archiveId');
    assert.match(result.stderr, /archiveId/, 'stderr must mention archiveId');
  } finally {
    restoreRecord();
  }
});

test('P00-T003: checker rejects a wrong Monaco version', () => {
  backupRecord();
  try {
    const rec = loadRecord();
    rec.monacoVersion = '0.57.0';
    saveRecord(rec);
    const result = runChecker();
    assert.equal(result.status, 1, 'checker must exit 1 on a wrong monacoVersion');
    assert.match(result.stderr, /monacoVersion/, 'stderr must mention monacoVersion');
  } finally {
    restoreRecord();
  }
});

test('P00-T003: working tree is clean after all seeded corruptions', () => {
  restoreRecord();
  assert.equal(existsSync(BACKUP), false, 'backup must be removed');
  // Re-run the checker to confirm the restored record is still valid.
  const result = runChecker();
  assert.equal(result.status, 0, 'checker must pass on the restored record');
});

// ===========================================================================
// P00-T004 — scope/instance-surface/public-declaration probes.
// Gate: scope (frozen F1-R3/F1-R4 manifests reproduced from the locked
// comparators).
// ===========================================================================

test('P00-T004: scope-probe.mjs exists at its declared path', () => {
  assert.equal(exists('Comparators/probes/scope-probe.mjs'), true);
});

test('P00-T004: instance-surface-probe.mjs exists at its declared path', () => {
  assert.equal(exists('Comparators/probes/instance-surface-probe.mjs'), true);
});

test('P00-T004: public-declaration-probe.mjs exists at its declared path', () => {
  assert.equal(exists('Comparators/probes/public-declaration-probe.mjs'), true);
});

test('P00-T004: scope-probe passes on the committed manifests', () => {
  const result = runNode('Comparators/probes/scope-probe.mjs');
  if (result.status !== 0) {
    console.error('stdout:\n%s', result.stdout);
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'scope-probe must accept the committed scope manifest');
  assert.match(result.stderr, /OK/, 'scope-probe must report OK on success');
});

test('P00-T004: instance-surface-probe passes on the committed manifests', () => {
  const result = runNode('Comparators/probes/instance-surface-probe.mjs');
  if (result.status !== 0) {
    console.error('stdout:\n%s', result.stdout);
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'instance-surface-probe must accept the committed manifest');
  assert.match(result.stderr, /OK/, 'instance-surface-probe must report OK on success');
});

test('P00-T004: public-declaration-probe passes on the committed manifests', () => {
  const result = runNode('Comparators/probes/public-declaration-probe.mjs');
  if (result.status !== 0) {
    console.error('stdout:\n%s', result.stdout);
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'public-declaration-probe must accept the committed manifest');
  assert.match(result.stderr, /OK/, 'public-declaration-probe must report OK on success');
});

// ===========================================================================
// P00-T005 — Wall and high-resolution clock domains.
// P00-T006 — Deterministic / cryptographic random + Number-to-string.
// P00-T007 — Runtime locale + UI localization boundary.
// Gate: module-boundary (the MonaCode Environment sources that every later
// phase injects; Foundation-only, no platform UI).
// ===========================================================================

test('P00-T005: MonaClock + MonaWallClock + MonaHighResolutionClock exist', () => {
  const sources = [
    'Sources/MonaCode/Environment/MonaClock.swift',
    'Sources/MonaCode/Environment/MonaWallClock.swift',
    'Sources/MonaCode/Environment/MonaHighResolutionClock.swift',
  ];
  for (const s of sources) {
    assert.equal(exists(s), true, `${s} must exist`);
  }
});

test('P00-T006: MonaRandomDoubleSource + MonaCryptoRandomSource + MonaNumberToString exist', () => {
  const sources = [
    'Sources/MonaCode/Environment/MonaRandomDoubleSource.swift',
    'Sources/MonaCode/Environment/MonaCryptoRandomSource.swift',
    'Sources/MonaCode/Environment/MonaNumberToString.swift',
  ];
  for (const s of sources) {
    assert.equal(exists(s), true, `${s} must exist`);
  }
});

test('P00-T007: MonaRuntimeLocale + MonaCodeEnvironment exist', () => {
  const sources = [
    'Sources/MonaCode/Environment/MonaRuntimeLocale.swift',
    'Sources/MonaCode/Environment/MonaCodeEnvironment.swift',
  ];
  for (const s of sources) {
    assert.equal(exists(s), true, `${s} must exist`);
  }
});

// ===========================================================================
// P00-T008 — Differential fixture and comparator harness.
// Gate: comparator (M0/M1/native differential runner).
// ===========================================================================

test('P00-T008: Tools/Differential/runner.mjs + fixture-schema.json exist', () => {
  assert.equal(exists('Tools/Differential/runner.mjs'), true);
  assert.equal(exists('Tools/Differential/fixture-schema.json'), true);
});

// ===========================================================================
// P00-T009 — Q1-R3 statistical verdict engine.
// Gate: statistics (bootstrap resampling + intersection-union verdict).
// ===========================================================================

test('P00-T009: Tests/BenchmarkHarness/BootstrapStatistics.swift exists', () => {
  assert.equal(exists('Tests/BenchmarkHarness/BootstrapStatistics.swift'), true);
});

// ===========================================================================
// P00-T010 — Font provenance, cold launch, display isolation, refresh cells.
// Gate: font + cold-launch + display.
// ===========================================================================

test('P00-T010: Q1R4FontProvenance + ColdLaunchManager + DisplayModeEnforcer exist', () => {
  assert.equal(exists('Tests/BenchmarkHarness/Q1R4FontProvenance.swift'), true);
  assert.equal(exists('Tests/BenchmarkHarness/ColdLaunchManager.swift'), true);
  assert.equal(exists('Tests/BenchmarkHarness/DisplayModeEnforcer.swift'), true);
});

// ===========================================================================
// P00-T011 — Privacy-filtered QEnvironmentID + formal preflight.
// Gate: privacy (QEnvironmentCollector rejects serial/account/UUID fields).
// ===========================================================================

test('P00-T011: Tools/Qualification/QEnvironmentCollector.swift + qenvironment-schema.json exist', () => {
  assert.equal(exists('Tools/Qualification/QEnvironmentCollector.swift'), true);
  assert.equal(exists('Tools/Qualification/qenvironment-schema.json'), true);
});

// ===========================================================================
// P00-T012 — Structural integration: the gate FAILS when any Phase 00 gate
// is absent. This is the single wiring check that collapses every gate above
// into one fail-closed invariant.
// ===========================================================================

test('P00-T012: the Phase 00 structural integration gate is complete (no gate absent)', () => {
  // Every Phase 00 gate file, enumerated once. If any is absent the
  // integration gate fails closed, regardless of whether the individual
  // checker tests above passed.
  const gates = [
    // P00-T001 — package graph (comparator + module-boundary spine)
    'Package.swift',
    'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs',
    // P00-T002 — module-boundary (Foundation-only)
    'Tools/PlanChecks/forbidden-core-imports.sh',
    // P00-T003 — comparator provenance
    'Tools/PlanChecks/verify-provenance.mjs',
    'Tools/PlanChecks/monaco-provenance.json',
    // P00-T004 — scope
    'Comparators/probes/scope-probe.mjs',
    'Comparators/probes/instance-surface-probe.mjs',
    'Comparators/probes/public-declaration-probe.mjs',
    // P00-T005 — clock domains
    'Sources/MonaCode/Environment/MonaClock.swift',
    'Sources/MonaCode/Environment/MonaWallClock.swift',
    'Sources/MonaCode/Environment/MonaHighResolutionClock.swift',
    // P00-T006 — entropy + number-to-string
    'Sources/MonaCode/Environment/MonaRandomDoubleSource.swift',
    'Sources/MonaCode/Environment/MonaCryptoRandomSource.swift',
    'Sources/MonaCode/Environment/MonaNumberToString.swift',
    // P00-T007 — locale boundary
    'Sources/MonaCode/Environment/MonaRuntimeLocale.swift',
    'Sources/MonaCode/Environment/MonaCodeEnvironment.swift',
    // P00-T008 — differential comparator
    'Tools/Differential/runner.mjs',
    'Tools/Differential/fixture-schema.json',
    // P00-T009 — statistics
    'Tests/BenchmarkHarness/BootstrapStatistics.swift',
    // P00-T010 — font / cold-launch / display
    'Tests/BenchmarkHarness/Q1R4FontProvenance.swift',
    'Tests/BenchmarkHarness/ColdLaunchManager.swift',
    'Tests/BenchmarkHarness/DisplayModeEnforcer.swift',
    // P00-T011 — privacy
    'Tools/Qualification/QEnvironmentCollector.swift',
    'Tools/Qualification/qenvironment-schema.json',
  ];
  const absent = gates.filter((g) => !exists(g));
  assert.deepEqual(
    absent, [],
    `Phase 00 gates must not be absent; missing: ${absent.join(', ')}`,
  );
});

test('P00-T012: output state is structurally verified, not claiming product evidence', () => {
  // This integration gate verifies STRUCTURE only: files exist and the
  // structural checkers (package graph, module boundary, provenance, scope)
  // exit 0. It does NOT execute any Monaco model, run any benchmark, or
  // record any empirical verdict. The output state remains `planned` or
  // `structurally verified` until future product execution supplies empirical
  // evidence; it must NOT be reported as `passed`.
  //
  // Concretely: no staged evidence file for P00-T012 may claim an empirical
  // `passed` state. If the evidence file does not yet exist, the gate is
  // structurally verified by default — which is the intended ceiling here.
  const evidencePath = r('artifacts/acceptance-evidence/g6-r/phase-00/P00-T012.json');
  if (existsSync(evidencePath)) {
    const ev = JSON.parse(readFileSync(evidencePath, 'utf8'));
    assert.notEqual(
      ev.state, 'passed',
      'P00-T012 must not claim empirical passage; state must be planned or structurally verified',
    );
  }
  // The structural ceiling holds: this assertion exists to anchor the
  // no-product-evidence contract in the integration gate.
  assert.equal(true, true);
});
