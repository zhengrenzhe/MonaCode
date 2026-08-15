import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const artifactDirectory = path.resolve(testDirectory, '../../artifacts');
const g4ManifestPath = path.resolve(
  artifactDirectory,
  '../../g4-r/artifacts/monacode-g4r-authoritative-manifest.json'
);
const g5ManifestPath = path.join(artifactDirectory, 'monacode-g5r-authoritative-manifest.json');

test('the G5-R contract candidate exists before scope comparison', () => {
  assert.equal(
    fs.existsSync(g5ManifestPath),
    true,
    'monacode-g5r-authoritative-manifest.json does not exist'
  );
});

test('accepts only the declared G4-R to G5-R delta set', async () => {
  const {
    compareFrozenScope,
    diffLeaves,
    isPermittedPointer,
    normalizeAuthorityRows
  } = await import('../tools/compare-g4-g5-scope.mjs');
  const g4 = JSON.parse(fs.readFileSync(g4ManifestPath, 'utf8'));
  const g5 = JSON.parse(fs.readFileSync(g5ManifestPath, 'utf8'));

  assert.deepEqual(compareFrozenScope(g4, g5), []);
  const deltas = diffLeaves(normalizeAuthorityRows(g4), normalizeAuthorityRows(g5));
  assert.equal(deltas.length > 0, true);
  assert.equal(deltas.every((row) => isPermittedPointer(row.pointer)), true);
  assert.equal(g5.identity.revision, 'G5-R-full-scope-candidate');
  assert.equal(g5.empiricalStatus.productSourceFiles, 0);
  assert.equal(g5.empiricalStatus.releaseVerdict, 'not-passed');
  assert.equal(g5.machineArtifacts.at(-1).id, 'implementationPlan');
  assert.equal(g5.machineArtifacts.at(-1).planSha256, null);
});

test('rejects a frozen product-scope mutation', async () => {
  const { compareFrozenScope } = await import('../tools/compare-g4-g5-scope.mjs');
  const g4 = JSON.parse(fs.readFileSync(g4ManifestPath, 'utf8'));
  const g5 = JSON.parse(fs.readFileSync(g5ManifestPath, 'utf8'));
  const mutated = structuredClone(g5);
  mutated.surfaceCounts.features.retainedMacOS = 61;

  assert.deepEqual(compareFrozenScope(g4, mutated), [
    {
      id: 'G5_FORBIDDEN_SCOPE_DELTA',
      subject: '/surfaceCounts/features/retainedMacOS',
      message: 'frozen value changed from 62 to 61'
    }
  ]);
});

test('normalizes authority arrays and does not overmatch pointer prefixes', async () => {
  const { compareFrozenScope, isPermittedPointer } = await import('../tools/compare-g4-g5-scope.mjs');
  const g4 = JSON.parse(fs.readFileSync(g4ManifestPath, 'utf8'));
  const g5 = JSON.parse(fs.readFileSync(g5ManifestPath, 'utf8'));
  const reordered = structuredClone(g5);
  reordered.authorityArtifacts.reverse();

  assert.deepEqual(compareFrozenScope(g4, reordered), []);
  assert.equal(isPermittedPointer('/identity/revision'), true);
  assert.equal(isPermittedPointer('/identityLeak/revision'), false);
});
