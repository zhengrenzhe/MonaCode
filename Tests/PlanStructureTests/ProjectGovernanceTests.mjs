import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import test from 'node:test';

import {
  computeVerificationSourceSet,
} from '../../Tools/Docs/source-set.mjs';
import {
  deriveProjectTaskDefinitions,
  loadContractCatalog,
} from '../../Tools/Docs/contract-catalog.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..');

test('verification source set is deterministic and excludes mutable truth and evidence files', () => {
  const first = computeVerificationSourceSet(REPO_ROOT);
  const second = computeVerificationSourceSet(REPO_ROOT);

  assert.equal(first.digest, second.digest);
  assert.match(first.digest, /^[0-9a-f]{64}$/);
  assert.equal(first.rows.some((row) => row.path === 'Package.swift'), true);
  assert.equal(first.rows.some((row) => row.path === 'README.md'), false);
  assert.equal(first.rows.some((row) => row.path === 'AGENTS.md'), false);
  assert.equal(first.rows.some((row) => row.path.startsWith('artifacts/')), false);
  assert.equal(first.rows.some((row) => row.path.startsWith('.build/')), false);
});

test('G6 catalog closes every owned, cut, and later identity', () => {
  const catalog = loadContractCatalog(REPO_ROOT);

  assert.equal(catalog.planTasks.length, 200);
  assert.equal(catalog.ownershipRows.length, 3582);
  assert.equal(catalog.activeIdentities.length, 3349);
  assert.equal(catalog.cutIdentities.length, 231);
  assert.equal(catalog.laterIdentities.length, 2);
  assert.equal(catalog.mobileScope.length, 4);
  assert.equal(
    catalog.ownershipRows.filter((row) => row.implementationOwners.length > 1).length,
    0,
  );
  assert.equal(catalog.surfaceCounts.publicDeclarations.retained, 434);
  assert.equal(catalog.surfaceCounts.model.uniqueMembers, 70);
  assert.equal(catalog.surfaceCounts.commands.retained, 453);
  assert.equal(catalog.surfaceCounts.actions.retained, 166);
  assert.equal(catalog.surfaceCounts.contributions.retainedMacOS, 52);
  assert.equal(catalog.surfaceCounts.features.retainedMacOS, 62);
  assert.equal(catalog.surfaceCounts.languageInfrastructure.surfaces, 30);
  assert.equal(catalog.surfaceCounts.keybindings, 379);
});

test('project task definitions contain governance, all G6 tasks, and four mobile tasks', () => {
  const definitions = deriveProjectTaskDefinitions(loadContractCatalog(REPO_ROOT));

  assert.equal(definitions.length, 205);
  assert.equal(definitions[0].id, 'VERIFY-001');
  assert.equal(new Set(definitions.map((row) => row.id)).size, 205);
  assert.equal(
    definitions.every((row) => /^(MODEL|REGISTRY|EDITOR|COMMAND|RENDER|INPUT|LANG|DIFF|SERVICE|SURFACE|VERIFY|MOBILE)-\d{3}$/.test(row.id)),
    true,
  );
  assert.deepEqual(
    definitions
      .filter((row) => row.domain === 'MOBILE')
      .map((row) => row.sourceTaskID),
    ['MOBILE-00', 'MOBILE-01', 'MOBILE-02', 'MOBILE-03'],
  );
});
