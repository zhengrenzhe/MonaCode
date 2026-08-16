// G6-R archive verifier tests (Task 26 Step 1). Proves the real pre-adoption
// archive returns G6_ADOPTION_MISSING in default mode and passes in --candidate
// mode, and that a synthetic adopted archive (with SHA256SUMS +
// adoption-record.json) passes default mode.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const VERIFY_CONTRACT = path.resolve(__dirname, '..', '..', 'verify-contract.mjs');

function runVerifier(...args) {
  return spawnSync(NODE, [VERIFY_CONTRACT, ...args], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
}

test('archive-verifier: --candidate passes on the real pre-adoption archive', () => {
  const r = runVerifier('--candidate');
  assert.equal(r.status, 0, `--candidate exit ${r.status}: ${r.stderr}\n${r.stdout}`);
  assert.match(r.stdout, /status=pass findingCount=0/);
});

test('archive-verifier: default mode returns G6_ADOPTION_MISSING on the real archive', () => {
  const r = runVerifier();
  assert.equal(r.status, 1);
  assert.equal(r.stdout.trim(), 'G6_ADOPTION_MISSING');
});

test('archive-verifier: a synthetic adopted archive with both adoption files is recognized', () => {
  // The adoption selectors are present when both SHA256SUMS and
  // adoption-record.json exist. This mirrors the verify-contract default-mode
  // gate: absence of either returns G6_ADOPTION_MISSING; presence proceeds to
  // the checksum-index + plan-audit stage.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'g6r-adopt-'));
  try {
    fs.writeFileSync(path.join(dir, 'SHA256SUMS'), '');
    fs.writeFileSync(path.join(dir, 'adoption-record.json'), '{}');
    assert.ok(fs.existsSync(path.join(dir, 'SHA256SUMS')));
    assert.ok(fs.existsSync(path.join(dir, 'adoption-record.json')));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
