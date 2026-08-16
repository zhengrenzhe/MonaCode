// G6-R payload-index tests (Task 26 Step 1).
// Asserts the closed 232-row payload index: exact gitMode 100644 on all rows,
// 230 checksum payload rows, one self-index row without a self-hash, exactly
// two hash-cycle-excluded rows (SHA256SUMS, adoption-record.json), and the
// exact present/planned counts through each authoring cursor. Runs against the
// real archive tree via buildPayloadIndex (it never reads a committed index).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildPayloadIndex } from '../update-payload-index.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ARCHIVE_ROOT = path.resolve(__dirname, '..', '..', '..', 'docs', 'contracts', 'monaco-editor-0.56.0', 'g6-r');

const ROWS_26 = buildPayloadIndex({ completedThroughTask: 26, archiveRoot: ARCHIVE_ROOT }).rows;

test('payload-index: exactly 232 final archive rows', () => {
  assert.equal(ROWS_26.length, 232);
});

test('payload-index: gitMode 100644 on all 232 rows', () => {
  assert.equal(ROWS_26.filter((r) => r.gitMode === '100644').length, 232);
});

test('payload-index: one authoring-task producer on all 232 rows', () => {
  for (const r of ROWS_26) assert.equal(typeof r.producerTask, 'number');
});

test('payload-index: exactly 230 checksum payload rows (non-excluded)', () => {
  assert.equal(ROWS_26.filter((r) => r.checksumDisposition !== 'hash-cycle-excluded').length, 230);
});

test('payload-index: exactly two hash-cycle-excluded rows for SHA256SUMS and adoption-record.json', () => {
  const excluded = ROWS_26.filter((r) => r.checksumDisposition === 'hash-cycle-excluded');
  assert.equal(excluded.length, 2);
  const excludedPaths = excluded.map((r) => r.path).sort();
  assert.deepEqual(excludedPaths, ['SHA256SUMS', 'adoption-record.json'].sort());
});

test('payload-index: one self-index row without a self-hash', () => {
  const self = ROWS_26.filter((r) => r.checksumDisposition === 'self-index');
  assert.equal(self.length, 1);
  assert.equal(self[0].path, 'implementation-plan/verification/payload-index.json');
  assert.equal(self[0].sha256, null);
});

test('payload-index: presence and checksumDisposition are orthogonal', () => {
  for (const r of ROWS_26) {
    assert.ok(r.presence === 'present' || r.presence === 'planned');
    assert.ok(['checksum', 'self-index', 'hash-cycle-excluded'].includes(r.checksumDisposition));
  }
});

test('payload-index: present/planned 223/9 through Task 26', () => {
  assert.equal(ROWS_26.filter((r) => r.presence === 'present').length, 223);
  assert.equal(ROWS_26.filter((r) => r.presence === 'planned').length, 9);
});

test('payload-index: present/planned 228/4 through Task 27', () => {
  const rows = buildPayloadIndex({ completedThroughTask: 27, archiveRoot: ARCHIVE_ROOT }).rows;
  assert.equal(rows.filter((r) => r.presence === 'present').length, 228);
  assert.equal(rows.filter((r) => r.presence === 'planned').length, 4);
});

test('payload-index: present/planned 229/3 through Task 28', () => {
  const rows = buildPayloadIndex({ completedThroughTask: 28, archiveRoot: ARCHIVE_ROOT }).rows;
  assert.equal(rows.filter((r) => r.presence === 'present').length, 229);
  assert.equal(rows.filter((r) => r.presence === 'planned').length, 3);
});

test('payload-index: present/planned 230/2 through Tasks 29-32', () => {
  const rows = buildPayloadIndex({ completedThroughTask: 32, archiveRoot: ARCHIVE_ROOT }).rows;
  assert.equal(rows.filter((r) => r.presence === 'present').length, 230);
  assert.equal(rows.filter((r) => r.presence === 'planned').length, 2);
});

test('payload-index: present/planned 232/0 through Task 33', () => {
  const rows = buildPayloadIndex({ completedThroughTask: 33, archiveRoot: ARCHIVE_ROOT }).rows;
  assert.equal(rows.filter((r) => r.presence === 'present').length, 232);
  assert.equal(rows.filter((r) => r.presence === 'planned').length, 0);
});

test('payload-index: presence derives only from producerTask <= cursor', () => {
  for (const r of ROWS_26) {
    const expected = r.producerTask <= 26 ? 'present' : 'planned';
    assert.equal(r.presence, expected);
  }
});
