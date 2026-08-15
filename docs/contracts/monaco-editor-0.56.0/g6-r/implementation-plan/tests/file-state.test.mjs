// G6-R deterministic file-state simulator tests (TDD Step 1).
// Proves every declared task operation has a deterministic input/output file
// state: no create-collision, no modify-before-create, no consumed-before-step,
// no commit-boundary drift, no missing/unreplaced Red scaffold. Each fixture
// declares ONE expected finding; inline controls assert deep equality, not set
// containment. Node built-in test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import * as path from 'node:path';

import { simulateFileState } from '../lib/file-state.mjs';

const FIXTURES_DIR = path.join(import.meta.dirname, 'fixtures');

function loadFixture(name) {
  return JSON.parse(readFileSync(path.join(FIXTURES_DIR, name), 'utf8'));
}

// ---------------------------------------------------------------------------
// Fixture-driven file-state findings (one exact finding each)
// ---------------------------------------------------------------------------

test('file-created-twice yields exactly PLAN_FILE_CREATE_COLLISION', () => {
  const fx = loadFixture('file-created-twice.json');
  const got = simulateFileState(fx.plan, fx.baselineRows);
  assert.deepEqual(got.findings, [fx.expected]);
});

test('file-modified-before-create yields exactly PLAN_FILE_MODIFY_UNAVAILABLE', () => {
  const fx = loadFixture('file-modified-before-create.json');
  const got = simulateFileState(fx.plan, fx.baselineRows);
  assert.deepEqual(got.findings, [fx.expected]);
});

test('file-consumed-before-step yields exactly PLAN_FILE_INPUT_UNAVAILABLE_AT_STAGE', () => {
  const fx = loadFixture('file-consumed-before-step.json');
  const got = simulateFileState(fx.plan, fx.baselineRows);
  assert.deepEqual(got.findings, [fx.expected]);
});

test('commit-boundary-drift yields exactly PLAN_COMMIT_BOUNDARY_DRIFT', () => {
  const fx = loadFixture('commit-boundary-drift.json');
  const got = simulateFileState(fx.plan, fx.baselineRows);
  assert.deepEqual(got.findings, [fx.expected]);
});

test('red-scaffold-missing yields exactly PLAN_RED_SCAFFOLD_MISSING', () => {
  const fx = loadFixture('red-scaffold-missing.json');
  const got = simulateFileState(fx.plan, fx.baselineRows);
  assert.deepEqual(got.findings, [fx.expected]);
});

test('red-scaffold-unreplaced yields exactly PLAN_RED_SCAFFOLD_UNREPLACED', () => {
  const fx = loadFixture('red-scaffold-unreplaced.json');
  const got = simulateFileState(fx.plan, fx.baselineRows);
  assert.deepEqual(got.findings, [fx.expected]);
});

// ---------------------------------------------------------------------------
// Positive control — zero findings + stable hash on two runs
// ---------------------------------------------------------------------------

function positivePlan() {
  return {
    planID: 'g6r-file-state-positive',
    tasks: [
      // Task 1: Swift-Red task with scaffold transition absent -> red-scaffold -> implementation
      {
        taskID: 'P00-T001',
        stages: [
          { name: 'preflight', steps: [{ kind: 'controller-action', action: 'begin-task' }] },
          { name: 'test-authoring', steps: [{ kind: 'authoring-operation', operation: 'author-tests' }] },
          { name: 'red', steps: [{ kind: 'verification-command', command: {
            commandID: 'P00-T001.RED.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
            leaves: [{ leafID: 'P00-T001.RED.001.PROC.001' }],
            inputs: [{ path: 'Tests/Foo.test.swift', availability: 'task-step' }],
          } }] },
          { name: 'implementation', steps: [{ kind: 'implementation-operation', operation: 'implement', modifies: ['Sources/Foo.swift'] }] },
          { name: 'green', steps: [{ kind: 'verification-command', command: {
            commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
            leaves: [{ leafID: 'P00-T001.GREEN.001.PROC.001' }],
            inputs: [{ path: 'Sources/Foo.swift', availability: 'task-step' }],
          } }] },
          { name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] },
          { name: 'evidence', steps: [{ kind: 'controller-action', action: 'finalize-evidence' }] },
        ],
        testContract: { contractID: 'TC-P00-T001', cases: [{
          caseID: 'C1', file: { path: 'Tests/Foo.test.swift', availability: 'task-step' },
          checker: 'swift-test', target: 'Tests', testSymbol: 'testFoo',
          fixtures: { kind: 'inline', values: {} },
          assertions: [{ id: 'A1', operand: 'exit' }],
          redLeafID: 'P00-T001.RED.001.PROC.001', greenLeafID: 'P00-T001.GREEN.001.PROC.001',
          inheritedOutput: false, failureClass: 'behavioral', authoringOperation: 'author-tests', source: 'baseline',
        }] },
        redScaffold: {
          sourcePath: 'Sources/Foo.swift', declarationText: 'scaffold',
          declarationHash: 'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          sentinelBehavior: 'compile-fail', createOwner: 'test-authoring', replacementOwner: 'implementation',
          redAssertionID: 'RA1', finalAbsenceAssertion: 'FAA1',
        },
        productCommit: { stagedProductPaths: ['Sources/Foo.swift'] },
        evidenceCommit: { stagedEvidencePath: 'evidence/P00-T001.json' },
      },
      // Task 2: non-Red task creating a new product path (dependency on Task 1)
      {
        taskID: 'P00-T002',
        stages: [
          { name: 'preflight', steps: [{ kind: 'controller-action', action: 'begin-task' }] },
          { name: 'test-authoring', steps: [{ kind: 'authoring-operation', operation: 'author-tests' }] },
          { name: 'red', steps: [{ kind: 'verification-command', command: {
            commandID: 'P00-T002.RED.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
            leaves: [{ leafID: 'P00-T002.RED.001.PROC.001' }],
            inputs: [{ path: 'Tests/Bar.test.swift', availability: 'task-step' }],
          } }] },
          { name: 'implementation', steps: [
            { kind: 'implementation-operation', operation: 'implement', creates: ['Sources/Bar.swift'] },
          ] },
          { name: 'green', steps: [{ kind: 'verification-command', command: {
            commandID: 'P00-T002.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
            leaves: [{ leafID: 'P00-T002.GREEN.001.PROC.001' }],
            inputs: [{ path: 'Sources/Bar.swift', availability: 'task-step' }],
          } }] },
          { name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] },
          { name: 'evidence', steps: [{ kind: 'controller-action', action: 'finalize-evidence' }] },
        ],
        testContract: { contractID: 'TC-P00-T002', cases: [{
          caseID: 'C1', file: { path: 'Tests/Bar.test.swift', availability: 'task-step' },
          checker: 'swift-test', target: 'Tests', testSymbol: 'testBar',
          fixtures: { kind: 'inline', values: {} },
          assertions: [{ id: 'A1', operand: 'exit' }],
          redLeafID: 'P00-T002.RED.001.PROC.001', greenLeafID: 'P00-T002.GREEN.001.PROC.001',
          inheritedOutput: false, failureClass: 'behavioral', authoringOperation: 'author-tests', source: 'baseline',
        }] },
        productCommit: { stagedProductPaths: ['Sources/Bar.swift'] },
        evidenceCommit: { stagedEvidencePath: 'evidence/P00-T002.json' },
      },
    ],
  };
}

test('positive plan produces zero findings and stable task-state hashes on two runs', () => {
  const plan = positivePlan();
  const baselineRows = [];
  const r1 = simulateFileState(plan, baselineRows);
  const r2 = simulateFileState(plan, baselineRows);

  assert.deepEqual(r1.findings, [], 'positive plan must produce zero findings');
  assert.equal(r1.taskStateHashes.length, 2, 'one task-state hash per task');

  // Stable hash proof: two independent runs produce identical hashes.
  assert.deepEqual(r1.taskStateHashes, r2.taskStateHashes, 'task-state hashes must be stable across runs');
  assert.equal(r1.finalStateHash, r2.finalStateHash, 'final-state hash must be stable across runs');
  assert.match(r1.finalStateHash, /^[0-9a-f]{64}$/, 'final-state hash must be SHA-256 (64 hex)');
  for (const h of r1.taskStateHashes) {
    assert.match(h, /^[0-9a-f]{64}$/, 'each task-state hash must be SHA-256 (64 hex)');
  }
});

// ---------------------------------------------------------------------------
// SimulationResult shape contract
// ---------------------------------------------------------------------------

test('simulateFileState returns findings, taskStateHashes, and finalStateHash', () => {
  const plan = { planID: 'g6r-shape', tasks: [] };
  const got = simulateFileState(plan, []);
  assert.ok(Array.isArray(got.findings));
  assert.ok(Array.isArray(got.taskStateHashes));
  assert.equal(typeof got.finalStateHash, 'string');
  assert.equal(got.taskStateHashes.length, 0);
});

test('simulateFileState handles empty plan with only baseline rows', () => {
  const got = simulateFileState({ planID: 'empty', tasks: [] }, [{ path: 'base/a.swift' }]);
  assert.deepEqual(got.findings, []);
  assert.deepEqual(got.taskStateHashes, []);
  assert.match(got.finalStateHash, /^[0-9a-f]{64}$/);
});

// ---------------------------------------------------------------------------
// Evidence/journal invariants — evidence path must not enter product staged set
// ---------------------------------------------------------------------------

test('evidence path in productCommit.stagedProductPaths yields COMMIT_BOUNDARY_DRIFT', () => {
  const plan = {
    planID: 'g6r-evidence-in-product',
    tasks: [{
      taskID: 'P00-T001',
      stages: [
        { name: 'preflight', steps: [{ kind: 'controller-action', action: 'begin-task' }] },
        { name: 'test-authoring', steps: [{ kind: 'authoring-operation', operation: 'author-tests' }] },
        { name: 'red', steps: [{ kind: 'verification-command', command: {
          commandID: 'P00-T001.RED.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
          leaves: [{ leafID: 'P00-T001.RED.001.PROC.001' }], inputs: [],
        } }] },
        { name: 'implementation', steps: [{ kind: 'implementation-operation', operation: 'implement', creates: ['Sources/Foo.swift', 'evidence/P00-T001.json'] }] },
        { name: 'green', steps: [{ kind: 'verification-command', command: {
          commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
          leaves: [{ leafID: 'P00-T001.GREEN.001.PROC.001' }], inputs: [],
        } }] },
        { name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] },
        { name: 'evidence', steps: [{ kind: 'controller-action', action: 'finalize-evidence' }] },
      ],
      testContract: { contractID: 'TC-P00-T001', cases: [{
        caseID: 'C1', file: { path: 'Tests/Foo.test.swift', availability: 'task-step' },
        checker: 'swift-test', target: 'Tests', testSymbol: 'testFoo',
        fixtures: { kind: 'inline', values: {} },
        assertions: [{ id: 'A1', operand: 'exit' }],
        redLeafID: 'P00-T001.RED.001.PROC.001', greenLeafID: 'P00-T001.GREEN.001.PROC.001',
        inheritedOutput: false, failureClass: 'behavioral', authoringOperation: 'author-tests', source: 'baseline',
      }] },
      productCommit: { stagedProductPaths: ['Sources/Foo.swift', 'evidence/P00-T001.json'] },
      evidenceCommit: { stagedEvidencePath: 'evidence/P00-T001.json' },
    }],
  };
  const got = simulateFileState(plan, []);
  assert.ok(got.findings.length > 0, 'must flag evidence path entering product staged set');
  assert.ok(got.findings.some((f) => f.id === 'PLAN_COMMIT_BOUNDARY_DRIFT'),
    'evidence path in stagedProductPaths must yield COMMIT_BOUNDARY_DRIFT');
});
