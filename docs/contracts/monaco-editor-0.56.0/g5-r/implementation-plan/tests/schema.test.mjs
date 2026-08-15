import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { canonicalJSONString, recordSha256 } from '../lib/canonical-json.mjs';
import { validatePlanSchema } from '../lib/schema.mjs';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const manifestPath = path.resolve(
  testDirectory,
  '../../artifacts/monacode-g5r-implementation-plan-manifest.json'
);

const seed = () => JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

const validTask = () => ({
  id: 'P00-T001',
  phase: '00',
  title: 'Create a bounded test target',
  platformScope: ['macOS'],
  dependencies: [],
  contractRefs: ['G5-R:deliveryScope.publicProducts'],
  ownership: ['package-target:MonaCode'],
  files: {
    productTarget: 'MonaCode',
    create: ['Sources/MonaCode/MonaCode.swift'],
    modify: [],
    test: ['Tests/MonaCodeTests/MonaCodeTests.swift']
  },
  interfaces: {
    consumes: ['Foundation'],
    produces: ['public enum MonaCodeVersion {}']
  },
  red: [
    {
      run: 'swift test --filter MonaCodeTests',
      expectedExit: 1,
      expectedOutputIncludes: ['cannot find MonaCodeVersion in scope']
    }
  ],
  implementation: {
    operations: ['Create the exact declaration exercised by the focused test.']
  },
  green: [
    {
      run: 'swift test --filter MonaCodeTests',
      expectedExit: 0,
      expectedOutputIncludes: ['Test Suite Passed']
    }
  ],
  evidence: ['artifacts/acceptance-evidence/g5-r/phase-00/P00-T001.json'],
  completion: ['The focused test exits zero.'],
  commitBoundary: [
    'Sources/MonaCode/MonaCode.swift',
    'Tests/MonaCodeTests/MonaCodeTests.swift'
  ]
});

const withTask = () => {
  const manifest = seed();
  manifest.tasks = [validTask()];
  return manifest;
};

const assertOnlySchemaFindings = (manifest) => {
  const findings = validatePlanSchema(manifest);
  assert.equal(findings.length > 0, true);
  assert.deepEqual([...new Set(findings.map((finding) => finding.id))], ['PLAN_SCHEMA_INVALID']);
};

test('accepts the adopted structurally verified manifest', () => {
  assert.deepEqual(validatePlanSchema(seed()), []);
});

test('canonical JSON sorts keys, preserves arrays, and hashes records', () => {
  const value = { z: 1, a: { y: [3, 2, 1], x: true } };
  assert.equal(canonicalJSONString(value), '{"a":{"x":true,"y":[3,2,1]},"z":1}');
  assert.match(recordSha256(value), /^[0-9a-f]{64}$/);
  assert.throws(() => canonicalJSONString({ value: Number.NaN }), /non-finite number/);
});

test('rejects a task without interfaces', () => {
  const manifest = withTask();
  delete manifest.tasks[0].interfaces;
  assertOnlySchemaFindings(manifest);
});

test('rejects a red command without exact expected output', () => {
  const manifest = withTask();
  manifest.tasks[0].red[0].expectedOutputIncludes = [];
  assertOnlySchemaFindings(manifest);
});

test('rejects duplicate task IDs', () => {
  const manifest = withTask();
  manifest.tasks.push(structuredClone(manifest.tasks[0]));
  assertOnlySchemaFindings(manifest);
});

test('rejects an empty evidence list', () => {
  const manifest = withTask();
  manifest.tasks[0].evidence = [];
  assertOnlySchemaFindings(manifest);
});

test('rejects an unbounded commit path', () => {
  const manifest = withTask();
  manifest.tasks[0].commitBoundary = ['.'];
  assertOnlySchemaFindings(manifest);
});

test('requires populated, zero-finding evidence before adoption', () => {
  const manifest = seed();
  manifest.adoptionState = 'adopted';
  manifest.audit = { status: 'not-run', findingCount: null, findings: [] };
  assertOnlySchemaFindings(manifest);
});
