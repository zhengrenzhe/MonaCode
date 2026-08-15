import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { auditBoundaries } from '../lib/boundaries.mjs';
import { auditEvidence } from '../lib/evidence.mjs';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const artifactDirectory = path.resolve(testDirectory, '../../artifacts');
const fixtureDirectory = path.join(testDirectory, 'fixtures');
const seedManifest = JSON.parse(fs.readFileSync(
  path.join(artifactDirectory, 'monacode-g5r-implementation-plan-manifest.json'),
  'utf8'
));
const contract = JSON.parse(fs.readFileSync(
  path.join(artifactDirectory, 'monacode-g5r-authoritative-manifest.json'),
  'utf8'
));
const fixture = (name) => JSON.parse(fs.readFileSync(path.join(fixtureDirectory, name), 'utf8'));

function task(id, phase, dependencies, ownership, productTarget = null) {
  return {
    id,
    phase,
    dependencies,
    ownership,
    files: {
      productTarget,
      create: productTarget === null ? [] : [`Sources/${productTarget}/${id}.swift`],
      modify: [],
      test: [`Tests/PlanFixtures/${id}.swift`]
    },
    interfaces: {
      consumes: dependencies,
      produces: ownership
    },
    implementation: {
      operations: [`Implement ${id} within its declared boundary.`]
    },
    evidence: [`artifacts/acceptance-evidence/g5-r/${phase}/${id}.json`]
  };
}

function validPlan() {
  const plan = structuredClone(seedManifest);
  plan.tasks = [
    task('P01-T001', '01', [], ['model:piece-tree'], 'MonaCode'),
    task('P03-T001', '03', ['P01-T001'], ['renderer:core-graphics-complete'], 'MonaCodeAppKit'),
    task('P03-T002', '03', ['P03-T001'], [
      'renderer:decision-gate',
      'renderer-metric:C03',
      'renderer-metric:C08'
    ]),
    task('P03-T003', '03', ['P03-T002'], ['renderer:metal-conditional'], 'MonaCodeAppKit'),
    task('P07-T001', '07', ['P03-T003'], ['public-api-closure']),
    task('P08-T010', '08', ['P07-T001'], ['candidate-finalizer:MonaNativeDeclarationManifest.json']),
    task('P08-T011', '08', ['P07-T001'], ['candidate-finalizer:MonaRegExpUnicodeManifest.json']),
    task('P08-T012', '08', ['P07-T001'], ['candidate-finalizer:MonaEnvironmentManifest.json']),
    task('P08-T013', '08', ['P07-T001'], ['candidate-finalizer:MonaSourceClosureManifest.json']),
    task('P08-T014', '08', ['P07-T001'], ['candidate-finalizer:MonaCacheManifest.json']),
    task('P08-T015', '08', ['P08-T010', 'P08-T011', 'P08-T012', 'P08-T013', 'P08-T014'], [
      'candidate-finalizer:MonaDistributionManifest.json'
    ]),
    task('P09-T001', '09', ['P08-T015'], ['candidate-finalizer:QEnvironmentID.json']),
    task('P09-T020', '09', [
      'P08-T010', 'P08-T011', 'P08-T012', 'P08-T013', 'P08-T014', 'P08-T015', 'P09-T001'
    ], plan.candidateArtifacts.map((name) => `candidate-consumer:${name}`))
  ];
  return plan;
}

function mutate(plan, row) {
  if (row.mutation === 'core-operation') {
    plan.tasks.find((candidate) => candidate.id === row.task).implementation.operations.push(row.value);
  } else if (row.mutation === 'replace-product-dependencies') {
    plan.packageGraph.products.find((product) => product.name === row.product).dependencies = row.value;
  } else if (row.mutation === 'remove-consumer-dependency') {
    const consumer = plan.tasks.find((candidate) => candidate.id === row.consumer);
    consumer.dependencies = consumer.dependencies.filter((dependency) => dependency !== row.finalizer);
  } else if (row.mutation === 'plan-state') {
    plan.planState = row.value;
  } else if (row.mutation === 'macos-build') {
    plan.qualificationEnvironment.macOSBuild = row.value;
  } else if (row.mutation === 'add-metal-gate-owner') {
    plan.tasks.find((candidate) => candidate.id === row.task).ownership.push(row.value);
  } else if (row.mutation === 'acceptance-before-distribution') {
    plan.tasks.find((candidate) => candidate.id === row.task).dependencies = row.value;
  } else {
    throw new Error(`unknown mutation: ${row.mutation}`);
  }
}

test('accepts the fixed package, candidate, renderer, evidence, and environment boundaries', () => {
  const plan = validPlan();
  assert.deepEqual(auditBoundaries(plan, contract), []);
  assert.deepEqual(auditEvidence(plan, contract), []);
});

for (const name of [
  'core-appkit-leak.json',
  'package-graph-drift.json',
  'candidate-after-consumer.json',
  'false-evidence-state.json',
  'stale-environment.json',
  'wrong-metal-trigger.json'
]) {
  test(`rejects ${name}`, () => {
    const row = fixture(name);
    const plan = validPlan();
    mutate(plan, row);
    const findings = auditBoundaries(plan, contract).concat(auditEvidence(plan, contract));
    assert.deepEqual(findings.map((finding) => finding.id).sort(), row.expectedFindingIds);
  });
}

test('rejects acceptance-before-distribution.json against the complete candidate graph', () => {
  const row = fixture('acceptance-before-distribution.json');
  const plan = structuredClone(seedManifest);
  mutate(plan, row);
  assert.deepEqual(auditBoundaries(plan, contract).map((finding) => finding.id), row.expectedFindingIds);
});
