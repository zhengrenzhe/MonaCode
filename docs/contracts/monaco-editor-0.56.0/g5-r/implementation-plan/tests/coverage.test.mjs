import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { auditOwnership } from '../lib/coverage.mjs';
import { buildContractInventory } from '../lib/inventory.mjs';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const artifactDirectory = path.resolve(testDirectory, '../../artifacts');
const fixtureDirectory = path.join(testDirectory, 'fixtures');
const fixture = (name) => JSON.parse(fs.readFileSync(path.join(fixtureDirectory, name), 'utf8'));

const inventory = buildContractInventory(artifactDirectory);

function validPlan() {
  return {
    tasks: [{ id: 'P00-T001' }, { id: 'P00-T002' }],
    ownership: inventory.identities.map((identity) => ({
      kind: identity.kind,
      id: identity.id,
      disposition: identity.disposition,
      implementationOwners: identity.retained ? ['P00-T001'] : [],
      testOwners: identity.retained ? ['P00-T001'] : []
    }))
  };
}

function row(plan, mutation) {
  return plan.ownership.find((candidate) => (
    candidate.kind === mutation.kind && candidate.id === mutation.id
  ));
}

function applyFixture(plan, mutation) {
  if (mutation.mutation === 'remove-row') {
    plan.ownership = plan.ownership.filter((candidate) => (
      candidate.kind !== mutation.kind || candidate.id !== mutation.id
    ));
  } else if (mutation.mutation === 'add-implementation-owner') {
    row(plan, mutation).implementationOwners.push(mutation.owner);
  } else if (mutation.mutation === 'own-cut-row') {
    row(plan, mutation).implementationOwners = [mutation.owner];
  } else {
    throw new Error(`unknown fixture mutation: ${mutation.mutation}`);
  }
}

test('extracts the exact frozen contract inventory', () => {
  assert.equal(inventory.counts.normativeLayer, 42);
  assert.equal(inventory.counts.machineArtifact, 17);
  assert.equal(inventory.counts.planArtifact, 5);
  assert.equal(inventory.counts.publicPath, 555);
  assert.equal(inventory.counts.feature, 64);
  assert.equal(inventory.counts.action, 167);
  assert.equal(inventory.counts.command, 454);
  assert.equal(inventory.counts.contribution, 53);
  assert.equal(inventory.counts.keybinding, 379);
  assert.equal(inventory.counts.menu, 18);
  assert.equal(inventory.counts.menuItem, 121);
  assert.equal(inventory.counts.option, 174);
  assert.equal(inventory.counts.color, 431);
  assert.equal(inventory.counts.icon, 776);
  assert.equal(inventory.counts.theme, 4);
  assert.equal(inventory.counts.provider, 30);
  assert.equal(inventory.counts.hostGroup, 7);
  assert.equal(inventory.counts.correctnessGate, 10);
  assert.equal(inventory.counts.performanceWorkload, 14);
  assert.equal(inventory.counts.candidateArtifact, 7);
  assert.equal(new Set(inventory.identities.map((identity) => `${identity.kind}:${identity.id}`)).size, inventory.identities.length);
  assert.deepEqual(
    inventory.identities
      .filter((identity) => identity.kind === 'publicPath' && identity.id.startsWith('editor.colorize'))
      .map((identity) => identity.id)
      .sort(),
    ['editor.colorize', 'editor.colorizeElement', 'editor.colorizeModelLine']
  );
});

test('accepts complete one-owner and one-test-owner coverage', () => {
  assert.deepEqual(auditOwnership(inventory, validPlan()), []);
});

for (const name of [
  'missing-retained-feature.json',
  'duplicate-owner.json',
  'cut-production-owner.json'
]) {
  test(`rejects ${name}`, () => {
    const mutation = fixture(name);
    const plan = validPlan();
    applyFixture(plan, mutation);
    assert.deepEqual(
      auditOwnership(inventory, plan).map((finding) => finding.id),
      mutation.expectedFindingIds
    );
  });
}

test('rejects a retained identity without a test owner', () => {
  const plan = validPlan();
  row(plan, { kind: 'feature', id: 'anchorSelect' }).testOwners = [];
  assert.deepEqual(auditOwnership(inventory, plan).map((finding) => finding.id), [
    'PLAN_TEST_OWNER_MISSING'
  ]);
});
