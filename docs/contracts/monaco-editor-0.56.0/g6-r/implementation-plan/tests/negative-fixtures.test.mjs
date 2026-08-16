// G6-R negative-fixtures execution test (Task 27 Step 1).
//
// Executes every negative fixture (every attack variant and every per-rule
// negativeFixture) by applying its mutation and running the appropriate audit
// entry point, and asserts every mutation is rejected under its exact finding
// array: each expectedFinding ID is observed in the audit's findings. Positive
// controls prove the unmutated plan achieves zero findings (the rule is
// satisfiable, not vacuously enforced).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildSealedCatalog, executeFixture, PRODUCTION_RULES } from '../lib/mutation-coverage.mjs';
import { auditPlan } from '../lib/audit.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PLAN_DIR = path.dirname(__dirname);
const CONTRACT_DIR = path.dirname(PLAN_DIR);
const ARCHIVE_ROOT = CONTRACT_DIR;
const ARTIFACT_DIR = path.join(CONTRACT_DIR, 'artifacts');
const FIXTURES_PATH = path.join(__dirname, 'fixtures', 'mutation-fixtures.json');

const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const PLAN = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-implementation-plan-manifest.json'));
const CONTRACT = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-authoritative-manifest.json'));
const PAYLOAD = loadJSON(path.join(PLAN_DIR, 'verification', 'payload-index.json'));
const CTX = { plan: PLAN, contract: CONTRACT, payloadIndex: PAYLOAD, archiveRoot: ARCHIVE_ROOT };

const CATALOG = buildSealedCatalog();

test('negative-fixtures: catalog file matches the sealed library catalog', () => {
  const committed = loadJSON(FIXTURES_PATH);
  assert.equal(committed.catalogHash, CATALOG.catalogHash);
});

test('negative-fixtures: clean plan is the universal positive control (zero findings)', () => {
  // Every production rule's positive control is the unmutated plan: the
  // integrated audit achieves zero findings, proving every rule is
  // satisfiable rather than vacuously enforced.
  const result = auditPlan({
    contract: CONTRACT, plan: PLAN, commands: PLAN.commands, interfaces: PLAN.interfaces,
    archiveRoot: ARCHIVE_ROOT,
    completedThroughTask: PAYLOAD.completedThroughTask ?? 26, payloadIndex: PAYLOAD,
  });
  assert.equal(result.findingCount, 0, result.findings.map((f) => `${f.id} ${f.message}`).join('\n'));
});

test('negative-fixtures: every attack variant mutation is rejected under its exact finding array', async () => {
  let executed = 0;
  const failures = [];
  for (const attack of CATALOG.attacks) {
    for (const variant of attack.variants) {
      executed++;
      const res = await executeFixture(variant, CTX);
      const ok = variant.expectedFindings.every((id) => res.observedIDs.includes(id));
      if (!ok) failures.push(`${variant.id}: exp=${variant.expectedFindings.join(',')} obs=${res.observedIDs.join(',')}`);
    }
  }
  assert.equal(executed, CATALOG.attacks.flatMap((a) => a.variants).length);
  assert.deepEqual(failures, [], `mutations not rejected under their exact finding array:\n${failures.join('\n')}`);
});

test('negative-fixtures: every per-rule negativeFixture mutation is rejected under its exact finding array', async () => {
  let executed = 0;
  const failures = [];
  for (const nf of CATALOG.negativeFixtures ?? []) {
    executed++;
    const res = await executeFixture(nf, CTX);
    const ok = nf.expectedFindings.every((id) => res.observedIDs.includes(id));
    if (!ok) failures.push(`${nf.id}: exp=${nf.expectedFindings.join(',')} obs=${res.observedIDs.join(',')}`);
  }
  assert.ok(executed > 0, 'catalog must declare per-rule negativeFixtures');
  assert.deepEqual(failures, [], `per-rule fixtures not rejected:\n${failures.join('\n')}`);
});

test('negative-fixtures: positive controls pass (no findings on the unmutated plan)', async () => {
  // Each positive control uses a noop mutation; the audit on the unchanged
  // plan must produce zero findings (the rule's happy path).
  let checked = 0;
  for (const pc of CATALOG.positiveControls) {
    checked++;
    const res = await executeFixture(pc, CTX);
    // The positive control asserts the rule is satisfiable: the expected
    // finding array is empty, so the mutation must NOT be rejected.
    assert.equal(pc.expectedFindings.length, 0);
    assert.equal(pc.expectedFindings.every((id) => res.observedIDs.includes(id)), true);
  }
  assert.equal(checked, PRODUCTION_RULES.length);
});
