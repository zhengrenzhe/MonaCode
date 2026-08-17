// Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs
//
// P00-T002 — Enforce the Foundation-only MonaCode boundary.
//
// MonaCode is a Foundation-only library target: the only module import
// permitted inside `Sources/MonaCode/**/*.swift` is `Foundation`. This test
// drives `Tools/PlanChecks/forbidden-core-imports.sh` against the real
// MonaCode sources (clean-tree case) and against a seeded violation to prove
// the gate fails closed when a forbidden import is introduced, then cleans up
// the seed so the working tree is left untouched.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { existsSync, rmSync, writeFileSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const SCRIPT = resolve(REPO_ROOT, 'Tools/PlanChecks/forbidden-core-imports.sh');
const MONACODE_DIR = resolve(REPO_ROOT, 'Sources/MonaCode');

// Seed file names used by the violation cases. Kept inside Sources/MonaCode so
// the real target directory is scanned exactly as the gate will run in CI.
const SEED_APPKIT = '__P00_T002_SEED_APPKIT__.swift';
const SEED_SWIFTUI = '__P00_T002_SEED_SWIFTUI__.swift';
const SEED_FOUNDATION = '__P00_T002_SEED_FOUNDATION__.swift';
const ALL_SEEDS = [SEED_APPKIT, SEED_SWIFTUI, SEED_FOUNDATION];

function runScript(scanDir) {
  return spawnSync('bash', [SCRIPT, scanDir], {
    encoding: 'utf8',
    cwd: REPO_ROOT,
  });
}

function removeSeeds() {
  for (const name of ALL_SEEDS) {
    rmSync(resolve(MONACODE_DIR, name), { force: true });
  }
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

test('the forbidden-core-imports gate exists at its declared path', () => {
  assert.equal(existsSync(SCRIPT), true);
});

test('clean MonaCode tree has no forbidden imports', () => {
  removeSeeds();
  const result = runScript(MONACODE_DIR);
  if (result.status !== 0) {
    console.error('stderr:\n%s', result.stderr);
  }
  assert.equal(result.status, 0, 'MonaCode sources must be Foundation-only');
});

test('seeded import AppKit is rejected and reported with file + line', () => {
  const seedPath = resolve(MONACODE_DIR, SEED_APPKIT);
  removeSeeds();
  writeFileSync(seedPath, 'import AppKit\n', 'utf8');

  try {
    const result = runScript(MONACODE_DIR);
    assert.equal(result.status, 1, 'gate must exit 1 when a forbidden import is present');
    assert.match(result.stderr, /import AppKit/, 'stderr must name the forbidden module');
    assert.match(
      result.stderr,
      new RegExp(escapeRegExp(seedPath)),
      'stderr must name the offending file',
    );
    assert.match(result.stderr, /:1:/, 'stderr must report the offending line number');
  } finally {
    removeSeeds();
  }
});

test('seeded import SwiftUI is rejected even alongside Foundation', () => {
  const seedPath = resolve(MONACODE_DIR, SEED_SWIFTUI);
  removeSeeds();
  writeFileSync(seedPath, 'import Foundation\nimport SwiftUI\n', 'utf8');

  try {
    const result = runScript(MONACODE_DIR);
    assert.equal(result.status, 1, 'gate must exit 1 when SwiftUI is present');
    assert.match(result.stderr, /import SwiftUI/, 'stderr must name SwiftUI');
    assert.doesNotMatch(
      result.stderr,
      /import Foundation/,
      'Foundation must not be reported as forbidden',
    );
  } finally {
    removeSeeds();
  }
});

test('import Foundation alone is permitted', () => {
  const seedPath = resolve(MONACODE_DIR, SEED_FOUNDATION);
  removeSeeds();
  writeFileSync(seedPath, 'import Foundation\n', 'utf8');

  try {
    const result = runScript(MONACODE_DIR);
    if (result.status !== 0) {
      console.error('stderr:\n%s', result.stderr);
    }
    assert.equal(result.status, 0, 'import Foundation must be permitted');
  } finally {
    removeSeeds();
  }
});

test('commented forbidden imports are not flagged', () => {
  const seedPath = resolve(MONACODE_DIR, SEED_APPKIT);
  removeSeeds();
  // A commented import is not a real import declaration.
  writeFileSync(seedPath, '// import AppKit\nimport Foundation\n', 'utf8');

  try {
    const result = runScript(MONACODE_DIR);
    if (result.status !== 0) {
      console.error('stderr:\n%s', result.stderr);
    }
    assert.equal(result.status, 0, 'commented imports must not be flagged');
  } finally {
    removeSeeds();
  }
});
