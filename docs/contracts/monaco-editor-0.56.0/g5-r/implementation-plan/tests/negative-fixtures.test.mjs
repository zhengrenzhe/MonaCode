import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const planDirectory = path.dirname(testDirectory);
const fixtureDirectory = path.join(testDirectory, 'fixtures');
const verifier = path.join(planDirectory, 'verify-plan.mjs');

const run = (args = []) => spawnSync(process.execPath, [verifier, ...args], {
  encoding: 'utf8',
  maxBuffer: 32 * 1024 * 1024
});

test('an incomplete candidate plan fails with JSON stdout and diagnostics stderr', () => {
  const result = run();
  assert.equal(result.status, 1);
  const output = JSON.parse(result.stdout);
  assert.equal(output.status, 'fail');
  assert.equal(output.findingCount > 0, true);
  assert.equal(output.coverage.retainedFeatureIds, 62);
  assert.equal(output.coverage.missingRetainedFeatureIds, 0);
  assert.equal(output.coverage.nativeColorizeReplacements, 3);
  assert.equal(result.stderr.includes('PLAN_'), true);
});

for (const name of fs.readdirSync(fixtureDirectory).filter((entry) => entry.endsWith('.json')).sort()) {
  test(`fixture ${name} is rejected with its declared exact findings`, () => {
    const fixturePath = path.join(fixtureDirectory, name);
    const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
    const result = run(['--fixture', fixturePath]);
    assert.equal(result.status, 1);
    const output = JSON.parse(result.stdout);
    assert.equal(output.status, 'fail');
    assert.deepEqual(output.findings.map((finding) => finding.id), [...fixture.expectedFindingIds].sort());
    assert.equal(result.stderr.includes(fixture.expectedFindingIds[0]), true);
  });
}
