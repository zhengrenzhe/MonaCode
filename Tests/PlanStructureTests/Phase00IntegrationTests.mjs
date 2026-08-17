// Tests/PlanStructureTests/Phase00IntegrationTests.mjs
//
// P00-T003 — Pin Monaco 0.56.0 M0 and M1 comparator provenance.
//
// The Monaco comparator oracles are large archives that live outside the
// repository (disposition=temporary). What the repository pins is a provenance
// record — monaco-provenance.json — that locks every archive's URL, SHA-256,
// byte count, and archive-entry count, plus the monaco.d.ts declaration hash.
// The checker (verify-provenance.mjs) verifies that record is internally
// consistent under network=forbidden (no download).
//
// This test drives the checker against the committed record (clean case) and
// against seeded corruptions to prove the gate fails closed when metadata
// drifts, then restores the record so the working tree is left untouched.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { existsSync, readFileSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const CHECKER = resolve(REPO_ROOT, 'Tools/PlanChecks/verify-provenance.mjs');
const RECORD = resolve(REPO_ROOT, 'Tools/PlanChecks/monaco-provenance.json');
const BACKUP = `${RECORD}.bak`;
const NODE = process.execPath;

function runChecker() {
  return spawnSync(NODE, [CHECKER], {
    encoding: 'utf8',
    cwd: REPO_ROOT,
  });
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

// ---------------------------------------------------------------------------
// Existence checks.
// ---------------------------------------------------------------------------

test('the provenance checker exists at its declared path', () => {
  assert.equal(existsSync(CHECKER), true);
});

test('the provenance record exists at its declared path', () => {
  assert.equal(existsSync(RECORD), true);
});

// ---------------------------------------------------------------------------
// Green: the checker passes against the committed record.
// ---------------------------------------------------------------------------

test('provenance checker exits 0 on the committed record', () => {
  restoreRecord();
  const result = runChecker();
  if (result.status !== 0) {
    console.error('stdout:\n%s', result.stdout);
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'checker must accept the committed provenance record');
  assert.match(result.stderr, /OK/, 'checker must report OK on success');
});

// ---------------------------------------------------------------------------
// Structural assertions on the committed record.
// ---------------------------------------------------------------------------

test('the record pins Monaco 0.56.0 and the source commit', () => {
  restoreRecord();
  const rec = loadRecord();
  assert.equal(rec.monacoVersion, '0.56.0');
  assert.equal(rec.sourceCommit, '13f0c872dcf352815cc28d92dfff496c9839ea5c');
  assert.match(rec.sourceCommit, /^[0-9a-f]{40}$/, 'sourceCommit must be a 40-hex SHA-1');
});

test('the record declares exactly 3 archives with HTTPS URLs and SHA-256 hashes', () => {
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

test('the record locks the expected archive entry counts', () => {
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

test('the record locks the monaco.d.ts declaration hash and size', () => {
  restoreRecord();
  const rec = loadRecord();
  const dts = rec.declarations.monacoDts;
  assert.equal(dts.sha256, 'fbbab04ba04224a04b2bc3243e536d1af6e26d14eb00fe8b3177bf3daef8d3f2');
  assert.equal(dts.bytes, 327877);
  assert.equal(dts.archiveId, 'monaco-editor-npm');
  assert.equal(dts.path, 'package/monaco.d.ts');
});

// ---------------------------------------------------------------------------
// Red: seeded corruptions must make the checker fail closed.
// ---------------------------------------------------------------------------

test('checker rejects a corrupted SHA-256', () => {
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

test('checker rejects a non-HTTPS URL', () => {
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

test('checker rejects a duplicate archive id', () => {
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

test('checker rejects a monaco.d.ts archiveId that references no archive', () => {
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

test('checker rejects a wrong Monaco version', () => {
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

test('working tree is clean after all seeded corruptions', () => {
  restoreRecord();
  assert.equal(existsSync(BACKUP), false, 'backup must be removed');
  // Re-run the checker to confirm the restored record is still valid.
  const result = runChecker();
  assert.equal(result.status, 0, 'checker must pass on the restored record');
});
