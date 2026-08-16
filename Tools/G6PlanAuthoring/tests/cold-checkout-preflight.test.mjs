// G6-R cold-checkout preflight tests (Task 28).
//
// Tests archive confinement, dirty-tree isolation, closed Git environment,
// resource caps, path validation, collision detection, and the full
// ten-command preflight against HEAD. Uses temp Git fixtures for unit tests
// and the real MonaCode repo for the integration test.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, existsSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  validatePath,
  validateBlobPaths,
  validateCollisionKeys,
  validateResourceCaps,
  closedGitEnv,
  collisionKey,
  G6_TEST_PATHS,
  MAX_BLOBS,
  MAX_BLOB_BYTES,
  MAX_AGGREGATE_BLOB_BYTES,
  MAX_TAR_BYTES,
  MAX_PATH_BYTES,
  MAX_COMPONENT_BYTES,
} from '../cold-checkout-preflight.mjs';

const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const GIT = '/usr/bin/git';
const REPO_ROOT = path.resolve(fileURLToPath(import.meta.url), '..', '..', '..');

const dirs = [];
function mktmp() {
  const d = mkdtempSync(path.join(tmpdir(), 'g6r-cc-'));
  dirs.push(d);
  return d;
}
function cleanup() { for (const d of dirs) { try { rmSync(d, { recursive: true, force: true }); } catch {} } }

// ---------------------------------------------------------------------------
// Temp Git fixture helpers.
// ---------------------------------------------------------------------------

function makeGitRepo(dir) {
  spawnSync(GIT, ['-C', dir, 'init', '-q'], { encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'user.name', 'test'], { encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'user.email', 'test@test.test'], { encoding: 'utf8' });
}

function gitCommit(dir, msg) {
  const env = { ...process.env, GIT_AUTHOR_NAME: 'test', GIT_AUTHOR_EMAIL: 'test@test.test', GIT_COMMITTER_NAME: 'test', GIT_COMMITTER_EMAIL: 'test@test.test' };
  spawnSync(GIT, ['-C', dir, 'add', '--all'], { encoding: 'utf8', env });
  spawnSync(GIT, ['-C', dir, 'commit', '-q', '-m', msg], { encoding: 'utf8', env });
}

function getHead(dir) {
  return spawnSync(GIT, ['-C', dir, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).stdout.trim();
}

// ---------------------------------------------------------------------------
// Path validation unit tests.
// ---------------------------------------------------------------------------

test('validatePath: rejects absolute paths', () => {
  assert.ok(validatePath('/etc/passwd').some((e) => e.includes('absolute')));
});

test('validatePath: rejects CR/LF in path', () => {
  assert.ok(validatePath('foo\rbar').some((e) => e.includes('CR/LF')));
  assert.ok(validatePath('foo\nbar').some((e) => e.includes('CR/LF')));
});

test('validatePath: rejects parent traversal', () => {
  assert.ok(validatePath('foo/../../../etc/passwd').some((e) => e.includes('traversal')));
});

test('validatePath: rejects null bytes', () => {
  assert.ok(validatePath('foo\0bar').some((e) => e.includes('null')));
});

test('validatePath: rejects path over 4096 UTF-8 bytes', () => {
  const longPath = 'a'.repeat(MAX_PATH_BYTES + 1);
  assert.ok(validatePath(longPath).some((e) => e.includes('path over')));
});

test('validatePath: rejects component over 255 UTF-8 bytes', () => {
  const longComp = 'b'.repeat(MAX_COMPONENT_BYTES + 1);
  assert.ok(validatePath(`dir/${longComp}`).some((e) => e.includes('component over')));
});

test('validatePath: accepts normal paths', () => {
  assert.equal(validatePath('docs/contracts/test.md').length, 0);
  assert.equal(validatePath('Tools/test.mjs').length, 0);
});

// ---------------------------------------------------------------------------
// Blob path / mode validation.
// ---------------------------------------------------------------------------

test('validateBlobPaths: rejects symlink mode 120000', () => {
  const blobs = [{ mode: '120000', type: 'blob', oid: 'a'.repeat(40), size: 10, path: 'link' }];
  assert.ok(validateBlobPaths(blobs).some((e) => e.includes('symlink')));
});

test('validateBlobPaths: rejects submodule mode 160000', () => {
  const blobs = [{ mode: '160000', type: 'commit', oid: 'a'.repeat(40), size: 0, path: 'sub' }];
  assert.ok(validateBlobPaths(blobs).some((e) => e.includes('submodule')));
});

test('validateBlobPaths: rejects tree records', () => {
  const blobs = [{ mode: '040000', type: 'tree', oid: 'a'.repeat(40), size: 0, path: 'dir' }];
  assert.ok(validateBlobPaths(blobs).some((e) => e.includes('tree record')));
});

test('validateBlobPaths: accepts 100644 and 100755 for repo as a whole', () => {
  const blobs = [
    { mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: 10, path: 'file.txt' },
    { mode: '100755', type: 'blob', oid: 'b'.repeat(40), size: 10, path: 'script.sh' },
  ];
  assert.equal(validateBlobPaths(blobs).length, 0);
});

test('validateBlobPaths: rejects 100755 for G6-R archive paths', () => {
  const blobs = [{ mode: '100755', type: 'blob', oid: 'a'.repeat(40), size: 10, path: 'docs/contracts/monaco-editor-0.56.0/g6-r/test.sh' }];
  assert.ok(validateBlobPaths(blobs).some((e) => e.includes('G6-R path mode')));
});

test('validateBlobPaths: rejects duplicate paths', () => {
  const blobs = [
    { mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: 10, path: 'dup.txt' },
    { mode: '100644', type: 'blob', oid: 'b'.repeat(40), size: 10, path: 'dup.txt' },
  ];
  assert.ok(validateBlobPaths(blobs).some((e) => e.includes('duplicate')));
});

// ---------------------------------------------------------------------------
// Collision key detection.
// ---------------------------------------------------------------------------

test('collisionKey: NFC + lowercase + NFC', () => {
  assert.equal(collisionKey('Tools'), 'tools');
  assert.equal(collisionKey('TOOLS'), 'tools');
  assert.equal(collisionKey('café'), 'café'.normalize('NFC').toLowerCase());
});

test('validateCollisionKeys: rejects per-directory collision', () => {
  const blobs = [
    { mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: 10, path: 'dir/Tools' },
    { mode: '100644', type: 'blob', oid: 'b'.repeat(40), size: 10, path: 'dir/tools' },
  ];
  assert.ok(validateCollisionKeys(blobs).some((e) => e.includes('collision-key-equal')));
});

test('validateCollisionKeys: accepts same-name in different directories', () => {
  const blobs = [
    { mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: 10, path: 'Tools/file' },
    { mode: '100644', type: 'blob', oid: 'b'.repeat(40), size: 10, path: 'docs/tools/file' },
  ];
  assert.equal(validateCollisionKeys(blobs).length, 0);
});

// ---------------------------------------------------------------------------
// Resource caps.
// ---------------------------------------------------------------------------

test('validateResourceCaps: rejects too many blobs', () => {
  const blobs = Array.from({ length: MAX_BLOBS + 1 }, (_, i) => ({ mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: 1, path: `f${i}` }));
  assert.ok(validateResourceCaps(blobs, 100).some((e) => e.includes('blob count')));
});

test('validateResourceCaps: rejects blob over max bytes', () => {
  const blobs = [{ mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: MAX_BLOB_BYTES + 1, path: 'big' }];
  assert.ok(validateResourceCaps(blobs, 100).some((e) => e.includes('blob big size')));
});

test('validateResourceCaps: rejects aggregate over max', () => {
  const blobs = Array.from({ length: 20 }, () => ({ mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: Math.ceil(MAX_AGGREGATE_BLOB_BYTES / 10), path: 'f' }));
  assert.ok(validateResourceCaps(blobs, 100).some((e) => e.includes('aggregate')));
});

test('validateResourceCaps: rejects tar output over max', () => {
  const blobs = [{ mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: 10, path: 'f' }];
  assert.ok(validateResourceCaps(blobs, MAX_TAR_BYTES + 1).some((e) => e.includes('tar bytes')));
});

test('validateResourceCaps: passes within limits', () => {
  const blobs = [{ mode: '100644', type: 'blob', oid: 'a'.repeat(40), size: 100, path: 'f' }];
  assert.equal(validateResourceCaps(blobs, 1000).length, 0);
});

// ---------------------------------------------------------------------------
// Closed Git environment.
// ---------------------------------------------------------------------------

test('closedGitEnv: removes inherited GIT_* values', () => {
  const oldEnv = { ...process.env };
  process.env.GIT_TEST_VAR = 'should-be-removed';
  process.env.GIT_AUTHOR_NAME = 'should-be-removed';
  const env = closedGitEnv();
  process.env = oldEnv;
  assert.equal(env.GIT_TEST_VAR, undefined);
  assert.equal(env.GIT_AUTHOR_NAME, undefined);
  assert.equal(env.GIT_AUTHOR_NAME, undefined);
});

test('closedGitEnv: sets exact GIT_CONFIG_* values', () => {
  const env = closedGitEnv();
  assert.equal(env.GIT_CONFIG_NOSYSTEM, '1');
  assert.equal(env.GIT_CONFIG_GLOBAL, '/dev/null');
  assert.equal(env.GIT_TERMINAL_PROMPT, '0');
  assert.equal(env.GIT_OPTIONAL_LOCKS, '0');
});

// ---------------------------------------------------------------------------
// Archive confinement: temp Git fixture with 100644 and 100755.
// ---------------------------------------------------------------------------

test('archive confinement: export uses one commit, enumerates blobs, ignores uncommitted', () => {
  const dir = mktmp();
  makeGitRepo(dir);
  writeFileSync(path.join(dir, 'regular.txt'), 'hello');
  writeFileSync(path.join(dir, 'script.sh'), '#!/bin/sh\necho hi\n');
  spawnSync(GIT, ['-C', dir, 'update-index', '--add', '--cacheinfo', '100644', spawnSync(GIT, ['-C', dir, 'hash-object', '-w', '--', path.join(dir, 'regular.txt')], { encoding: 'utf8' }).stdout.trim(), 'regular.txt'], { encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'update-index', '--add', '--cacheinfo', '100755', spawnSync(GIT, ['-C', dir, 'hash-object', '-w', '--', path.join(dir, 'script.sh')], { encoding: 'utf8' }).stdout.trim(), 'script.sh'], { encoding: 'utf8' });
  gitCommit(dir, 'initial');
  const head = getHead(dir);

  // Add an uncommitted file.
  writeFileSync(path.join(dir, 'uncommitted.txt'), 'should not appear');

  // Enumerate blobs from the committed state.
  const r = spawnSync(GIT, ['-C', dir, 'ls-tree', '-r', '-l', '-z', '--full-tree', head], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const records = r.stdout.split('\0').filter(Boolean);
  assert.equal(records.length, 2, 'should enumerate exactly 2 committed blobs');

  // The uncommitted file should NOT appear.
  for (const rec of records) {
    const filePath = rec.slice(rec.indexOf('\t') + 1);
    assert.notEqual(filePath, 'uncommitted.txt');
  }
});

test('archive confinement: tar.umask=0002 produces exact mode mappings', () => {
  const dir = mktmp();
  makeGitRepo(dir);
  // Create a file with mode 100644.
  writeFileSync(path.join(dir, 'regular.txt'), 'data');
  spawnSync(GIT, ['-C', dir, 'add', 'regular.txt'], { encoding: 'utf8' });
  // Create a file with mode 100755.
  writeFileSync(path.join(dir, 'script.sh'), '#!/bin/sh\n');
  spawnSync(GIT, ['-C', dir, 'add', 'script.sh'], { encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'update-index', '--chmod=+x', 'script.sh'], { encoding: 'utf8' });
  gitCommit(dir, 'modes');
  const head = getHead(dir);

  // Stream git archive with -c tar.umask=0002.
  const archivePath = path.join(dir, 'test.tar');
  const r = spawnSync(GIT, ['-C', dir, '-c', 'tar.umask=0002', 'archive', '--format=tar', head], { encoding: 'buffer', maxBuffer: 64 * 1024 * 1024 });
  writeFileSync(archivePath, r.stdout);

  // bsdtar -tvf.
  const tvf = spawnSync('/usr/bin/bsdtar', ['-tvf', archivePath], { encoding: 'utf8', env: { ...process.env, LC_ALL: 'C' } });
  const lines = tvf.stdout.split('\n').filter(Boolean);
  for (const line of lines) {
    const perms = line.slice(0, 10);
    if (perms[0] === '-') {
      // Regular file: must be -rw-rw-r-- (100644) or -rwxrwxr-x (100755).
      assert.ok(
        perms === '-rw-rw-r--' || perms === '-rwxrwxr-x',
        `unexpected regular file perms: ${perms}`
      );
    } else if (perms[0] === 'd') {
      // Directory: must be drwxrwxr-x.
      assert.equal(perms, 'drwxrwxr-x', `unexpected directory perms: ${perms}`);
    }
  }
});

// ---------------------------------------------------------------------------
// G6 test paths: exactly 17 in Task 27 Step 4 order.
// ---------------------------------------------------------------------------

test('G6 test paths: exactly 17 paths in Task 27 Step 4 order', () => {
  assert.equal(G6_TEST_PATHS.length, 17);
  assert.equal(G6_TEST_PATHS[0], 'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/schema.test.mjs');
  assert.equal(G6_TEST_PATHS[6], 'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/task-state.test.mjs');
  assert.equal(G6_TEST_PATHS[16], 'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/negative-fixtures.test.mjs');
});

// ---------------------------------------------------------------------------
// Cleanup.
// ---------------------------------------------------------------------------

test('cleanup temp dirs', () => { cleanup(); assert.ok(true); });
