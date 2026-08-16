// G6-R coverage audit tests (Task 26 Step 1). Loads the real inventory + plan
// and proves zero coverage findings, then mutates one input and asserts the
// coverage finding count increments.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { auditOwnership } from '../lib/coverage.mjs';
import { buildContractInventory, identityKey } from '../lib/inventory.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ARTIFACT_DIR = path.resolve(__dirname, '..', '..', 'artifacts');
const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const INVENTORY = buildContractInventory(ARTIFACT_DIR);
const PLAN = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-implementation-plan-manifest.json'));

test('coverage: real plan has zero coverage findings', () => {
  assert.equal(auditOwnership(INVENTORY, PLAN).length, 0);
});

test('coverage: inventory matches ownership row count (3582)', () => {
  assert.equal(INVENTORY.identities.length, PLAN.ownership.length);
});

test('coverage: removing an ownership row yields one retained-unmapped finding', () => {
  const p = structuredClone(PLAN);
  p.ownership.shift();
  const findings = auditOwnership(INVENTORY, p);
  assert.ok(findings.length >= 1);
  assert.ok(findings.some((f) => f.id === 'PLAN_RETAINED_IDENTITY_UNMAPPED' || f.id === 'PLAN_DISPOSITION_IDENTITY_UNMAPPED'));
});

test('coverage: a duplicate ownership row yields one duplicate finding', () => {
  const p = structuredClone(PLAN);
  p.ownership.push(p.ownership[0]);
  const findings = auditOwnership(INVENTORY, p);
  assert.ok(findings.some((f) => f.id === 'PLAN_DUPLICATE_OWNERSHIP_ROW'));
});

test('coverage: an unknown ownership identity yields one unknown finding', () => {
  const p = structuredClone(PLAN);
  p.ownership.push({ kind: 'action', id: 'actions.nonexistent', disposition: 'retained', implementationOwners: ['P05-T002'], testOwners: ['P05-T002'] });
  const findings = auditOwnership(INVENTORY, p);
  assert.ok(findings.some((f) => f.id === 'PLAN_OWNERSHIP_IDENTITY_UNKNOWN'));
});
