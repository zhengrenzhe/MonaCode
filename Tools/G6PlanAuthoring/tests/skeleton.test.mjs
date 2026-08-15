import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { copyParentArchive } from '../lib/skeleton.mjs';

const DEST_PREFIX = 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/';
const SRC_PREFIX = 'docs/contracts/monaco-editor-0.56.0/g5-r/';

test('copies the G5-R parent archive byte-for-byte into the G6-R skeleton', () => {
  const repoRoot = process.cwd();
  const pathspec = fs.readFileSync(
    path.join(repoRoot, 'Tools/G6PlanAuthoring/parent-snapshot-paths.txt'), 'utf8'
  ).split('\n').filter(Boolean);
  const expectedParentPaths = pathspec.map((entry) => entry.slice(DEST_PREFIX.length));

  const targetRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'monacode-g6-skeleton-'));
  try {
    const result = copyParentArchive(repoRoot, targetRoot);

    assert.equal(result.rows.length, 148);
    assert.equal(result.bytes, 4050132);
    assert.equal(result.checksumRows, 144);
    assert.equal(result.mode100644, 148);
    assert.equal(result.mismatches, 0);
    assert.deepEqual(result.rows.map((row) => row.source), expectedParentPaths);
    assert.ok(result.rows.every((row) => row.gitMode === '100644'));

    // Every copied byte sequence equals the G5-R source byte sequence.
    for (const row of result.rows) {
      const sourceAbs = path.join(repoRoot, SRC_PREFIX, row.source);
      const destAbs = path.join(targetRoot, row.destination);
      const sourceBytes = fs.readFileSync(sourceAbs);
      const destBytes = fs.readFileSync(destAbs);
      assert.ok(sourceBytes.equals(destBytes), `byte mismatch for ${row.source}`);
      assert.equal(row.bytes, sourceBytes.length);
    }

    // The generated destination set equals the committed pathspec (bytewise order).
    const generated = result.rows.map((row) => DEST_PREFIX + row.source);
    assert.deepEqual(generated, pathspec);

    // Every destination resolves beneath the supplied target (path confinement).
    const targetResolved = path.resolve(targetRoot);
    for (const row of result.rows) {
      const destResolved = path.resolve(targetRoot, row.destination);
      const rel = path.relative(targetResolved, destResolved);
      assert.ok(rel !== '' && !rel.startsWith('..') && !path.isAbsolute(rel),
        `destination escapes target: ${row.destination}`);
    }
  } finally {
    fs.rmSync(targetRoot, { recursive: true, force: true });
  }
});
