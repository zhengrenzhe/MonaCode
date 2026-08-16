// G6-R boundary audit tests (Task 26 Step 1). Mutates one input per boundary
// category and asserts the boundary finding count increments.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { auditForbiddenProductPaths, auditProductTargetBoundary, auditBoundaries } from '../lib/boundaries.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ARTIFACT_DIR = path.resolve(__dirname, '..', '..', 'artifacts');
const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const PLAN = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-implementation-plan-manifest.json'));

function baseTask(id, create = []) {
  return { id, paths: { create, modify: [], productTarget: 'MonaCode' } };
}

test('boundaries: real plan has zero forbidden-path findings', () => {
  assert.equal(auditForbiddenProductPaths(PLAN).length, 0);
});

test('boundaries: a forbidden runtime path yields one finding', () => {
  const p = { tasks: [baseTask('P00-T001', ['Sources/MonaCode/BuiltinLanguagePack.swift'])] };
  assert.equal(auditForbiddenProductPaths(p).length, 1);
  assert.equal(auditForbiddenProductPaths(p)[0].id, 'PLAN_FORBIDDEN_PRODUCT_PATH');
});

test('boundaries: product-target boundary — Sources root mismatch yields one finding', () => {
  const p = { tasks: [{ id: 'P01-T001', paths: { create: ['Sources/MonaCodeAppKit/Foo.swift'], modify: [], productTarget: 'MonaCode' } }] };
  assert.equal(auditProductTargetBoundary(p).length, 1);
});

test('boundaries: product-target boundary — matching root yields zero findings', () => {
  const p = { tasks: [{ id: 'P01-T001', paths: { create: ['Sources/MonaCode/Foo.swift'], modify: [], productTarget: 'MonaCode' } }] };
  assert.equal(auditProductTargetBoundary(p).length, 0);
});

test('boundaries: real plan boundary aggregate is zero', () => {
  assert.equal(auditBoundaries(PLAN).length, 0);
});
