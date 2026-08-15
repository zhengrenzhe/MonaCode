// G6-R command and task mutation-policy enforcement tests (TDD Step 1).
// Binds every G6-R task stage to a bounded allowlist of paths it may mutate:
// begin-task -> evidence path + .g6-beginning journal + token-owned task root;
// test-authoring -> declared tests/fixtures/checkers + Red-scaffold paths;
// Red/Green process leaves -> the parent record's declared command child
// (scratch path under /tmp/monacode-planctl/<leafID>); implementation -> task
// file rows + declared source-acquisition paths + scaffold replacements;
// commit -> exact product commit boundary + .g6-committing journal + running
// evidence (never the evidence path); evidence finalization -> evidence path +
// .g6-part/.g6-finalizing journals + token-owned root/tombstone + Git
// index/history for the single evidence-only commit. Each fixture declares ONE
// expected finding; inline controls assert deep equality, not set containment.
// Node built-in test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import * as path from 'node:path';

import {
  MUTATION_FINDING_IDS,
  normalizePath,
  buildMutationPolicies,
  auditMutationPolicy,
  compareObservedMutations,
} from '../lib/mutation-policy.mjs';

const FIXTURES_DIR = path.join(import.meta.dirname, 'fixtures');

function loadFixture(name) {
  return JSON.parse(readFileSync(path.join(FIXTURES_DIR, name), 'utf8'));
}

const SCRATCH_ROOT = '/tmp/monacode-planctl';
const TASK_ROOT = `${SCRATCH_ROOT}/task-root-P00-T001`;
const TOKEN = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const PLAN_HASH = '0123456789abcdef0123456789abcdef01234567';
const TASK_HASH = 'fedcba9876543210fedcba9876543210fedcba98';
const BASE_HASH = '757d1c3660dc80e2756e35bbd52580688011c67a';

// ---------------------------------------------------------------------------
// Closed finding-id set
// ---------------------------------------------------------------------------

test('MUTATION_FINDING_IDS is exactly the seven closed mutation findings', () => {
  assert.deepEqual(MUTATION_FINDING_IDS, [
    'PLAN_REPOSITORY_MUTATION_UNDECLARED',
    'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT',
    'PLAN_EVIDENCE_JOURNAL_STATE',
    'PLAN_EVIDENCE_COMMIT_BOUNDARY',
    'PLAN_ALL_SUCCESS_ORDER',
    'PLAN_PIPELINE_STATUS',
    'PLAN_RED_SCAFFOLD_MUTATION',
  ]);
});

// ---------------------------------------------------------------------------
// baseTask — a well-formed task that yields zero audit findings
// ---------------------------------------------------------------------------

function baseTask(overrides = {}) {
  return {
    taskID: 'P00-T001',
    stages: [
      { name: 'preflight', steps: [{ kind: 'controller-action', action: 'begin-task' }] },
      { name: 'test-authoring', steps: [{ kind: 'authoring-operation', operation: 'author-tests' }] },
      { name: 'red', steps: [{ kind: 'verification-command', command: {
        commandID: 'P00-T001.RED.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
        leaves: [{ leafID: 'P00-T001.RED.001.PROC.001' }],
      } }] },
      { name: 'implementation', steps: [{ kind: 'implementation-operation', operation: 'implement', modifies: ['Sources/Foo.swift'] }] },
      { name: 'green', steps: [{ kind: 'verification-command', command: {
        commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
        leaves: [{ leafID: 'P00-T001.GREEN.001.PROC.001' }],
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
    workspace: {
      ownershipToken: TOKEN, taskRoot: TASK_ROOT,
      planHash: PLAN_HASH, taskHash: TASK_HASH, baseHash: BASE_HASH,
      currentStage: 'implementation', lifecycleState: 'running',
    },
    productCommit: { stagedProductPaths: ['Sources/Foo.swift'] },
    evidenceCommit: { stagedEvidencePath: 'evidence/P00-T001.json' },
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Positive control — zero audit findings on a well-formed task
// ---------------------------------------------------------------------------

test('auditMutationPolicy accepts a well-formed task (zero findings)', () => {
  assert.deepEqual(auditMutationPolicy(baseTask()), []);
});

test('auditMutationPolicy never throws for malformed input', () => {
  assert.deepEqual(auditMutationPolicy(null), []);
  assert.deepEqual(auditMutationPolicy({}), []);
  assert.deepEqual(auditMutationPolicy({ taskID: 'P00-T001' }), []);
});

// ---------------------------------------------------------------------------
// PLAN_EVIDENCE_COMMIT_BOUNDARY — evidence/journal paths must not enter the
// product commit boundary; the evidence commit diff is exactly the evidence path
// ---------------------------------------------------------------------------

test('PLAN_EVIDENCE_COMMIT_BOUNDARY: evidence path in productCommit.stagedProductPaths', () => {
  const task = baseTask({
    productCommit: { stagedProductPaths: ['Sources/Foo.swift', 'evidence/P00-T001.json'] },
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_EVIDENCE_COMMIT_BOUNDARY', category: 'semantic', taskID: 'P00-T001',
    path: '/productCommit/stagedProductPaths',
    message: 'evidence path "evidence/P00-T001.json" must not enter the product commit boundary',
  }]);
});

test('PLAN_EVIDENCE_COMMIT_BOUNDARY: journal path in productCommit.stagedProductPaths', () => {
  const task = baseTask({
    productCommit: { stagedProductPaths: ['Sources/Foo.swift', '.g6-committing'] },
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_EVIDENCE_COMMIT_BOUNDARY', category: 'semantic', taskID: 'P00-T001',
    path: '/productCommit/stagedProductPaths',
    message: 'journal path ".g6-committing" must not enter the product commit boundary',
  }]);
});

test('PLAN_EVIDENCE_COMMIT_BOUNDARY: evidence path that is itself a journal path', () => {
  const task = baseTask({
    evidenceCommit: { stagedEvidencePath: '.g6-finalizing' },
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_EVIDENCE_COMMIT_BOUNDARY', category: 'semantic', taskID: 'P00-T001',
    path: '/evidenceCommit',
    message: 'evidence path ".g6-finalizing" must not be a journal path',
  }]);
});

// ---------------------------------------------------------------------------
// PLAN_ALL_SUCCESS_ORDER — all-success leafIDs must be ascending so the
// command stops after its first non-zero leaf
// ---------------------------------------------------------------------------

test('PLAN_ALL_SUCCESS_ORDER: non-ascending all-success leafIDs', () => {
  const task = baseTask({
    stages: baseTask().stages.map((s) => s.name === 'red' ? {
      name: 'red',
      steps: [{ kind: 'verification-command', command: {
        commandID: 'P00-T001.RED.001', kind: 'all-success', networkMode: 'forbidden', timeoutMs: 120000,
        leaves: [
          { leafID: 'P00-T001.RED.001.PROC.002' },
          { leafID: 'P00-T001.RED.001.PROC.001' },
        ],
      } }],
    } : s),
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_ALL_SUCCESS_ORDER', category: 'semantic', taskID: 'P00-T001',
    path: '/stages/red/steps/0/command',
    message: 'all-success leafIDs must be ascending to stop after the first non-zero leaf at index 1',
  }]);
});

test('PLAN_ALL_SUCCESS_ORDER: ascending all-success leafIDs accepted', () => {
  const task = baseTask({
    stages: baseTask().stages.map((s) => s.name === 'red' ? {
      name: 'red',
      steps: [{ kind: 'verification-command', command: {
        commandID: 'P00-T001.RED.001', kind: 'all-success', networkMode: 'forbidden', timeoutMs: 120000,
        leaves: [
          { leafID: 'P00-T001.RED.001.PROC.001' },
          { leafID: 'P00-T001.RED.001.PROC.002' },
        ],
      } }],
    } : s),
  });
  assert.deepEqual(auditMutationPolicy(task), []);
});

// ---------------------------------------------------------------------------
// PLAN_PIPELINE_STATUS — pipelines must carry pipefail and report every leaf
// ---------------------------------------------------------------------------

test('PLAN_PIPELINE_STATUS: pipeline missing pipefail', () => {
  const task = baseTask({
    stages: baseTask().stages.map((s) => s.name === 'red' ? {
      name: 'red',
      steps: [{ kind: 'verification-command', command: {
        commandID: 'P00-T001.RED.001', kind: 'pipeline', networkMode: 'forbidden', timeoutMs: 120000,
        leaves: [
          { leafID: 'P00-T001.RED.001.PROC.001' },
          { leafID: 'P00-T001.RED.001.PROC.002' },
        ],
      } }],
    } : s),
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_PIPELINE_STATUS', category: 'semantic', taskID: 'P00-T001',
    path: '/stages/red/steps/0/command',
    message: 'pipeline must carry pipefail: true and aggregate every leaf status',
  }]);
});

test('PLAN_PIPELINE_STATUS: pipeline with an unreported leaf (no leafID)', () => {
  const task = baseTask({
    stages: baseTask().stages.map((s) => s.name === 'red' ? {
      name: 'red',
      steps: [{ kind: 'verification-command', command: {
        commandID: 'P00-T001.RED.001', kind: 'pipeline', networkMode: 'forbidden', timeoutMs: 120000,
        pipefail: true,
        leaves: [
          { leafID: 'P00-T001.RED.001.PROC.001' },
          { leafID: null },
        ],
      } }],
    } : s),
  });
  const got = auditMutationPolicy(task);
  assert.ok(got.some((f) => f.id === 'PLAN_PIPELINE_STATUS' &&
    f.path === '/stages/red/steps/0/command/leaves/1' &&
    f.message.includes('pipeline must report every leaf')));
});

test('PLAN_PIPELINE_STATUS: well-formed pipeline accepted', () => {
  const task = baseTask({
    stages: baseTask().stages.map((s) => s.name === 'red' ? {
      name: 'red',
      steps: [{ kind: 'verification-command', command: {
        commandID: 'P00-T001.RED.001', kind: 'pipeline', networkMode: 'forbidden', timeoutMs: 120000,
        pipefail: true,
        leaves: [
          { leafID: 'P00-T001.RED.001.PROC.001' },
          { leafID: 'P00-T001.RED.001.PROC.002' },
        ],
      } }],
    } : s),
  });
  assert.deepEqual(auditMutationPolicy(task), []);
});

// ---------------------------------------------------------------------------
// PLAN_RED_SCAFFOLD_MUTATION — scaffold createOwner/replacementOwner must be
// test-authoring/implementation; the sourcePath is the only scaffold mutation
// ---------------------------------------------------------------------------

test('PLAN_RED_SCAFFOLD_MUTATION: createOwner not test-authoring', () => {
  const task = baseTask({
    redScaffold: { ...baseTask().redScaffold, createOwner: 'implementation' },
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_RED_SCAFFOLD_MUTATION', category: 'semantic', taskID: 'P00-T001',
    path: '/redScaffold',
    message: 'red scaffold createOwner must be test-authoring, got implementation',
  }]);
});

test('PLAN_RED_SCAFFOLD_MUTATION: replacementOwner not implementation', () => {
  const task = baseTask({
    redScaffold: { ...baseTask().redScaffold, replacementOwner: 'test-authoring' },
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_RED_SCAFFOLD_MUTATION', category: 'semantic', taskID: 'P00-T001',
    path: '/redScaffold',
    message: 'red scaffold replacementOwner must be implementation, got test-authoring',
  }]);
});

// ---------------------------------------------------------------------------
// PLAN_EVIDENCE_JOURNAL_STATE — controller actions must set the right journal
// state via the correct action
// ---------------------------------------------------------------------------

test('PLAN_EVIDENCE_JOURNAL_STATE: preflight not begin-task', () => {
  const task = baseTask({
    stages: baseTask().stages.map((s) => s.name === 'preflight' ? {
      name: 'preflight', steps: [{ kind: 'controller-action', action: 'commit-task' }],
    } : s),
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_EVIDENCE_JOURNAL_STATE', category: 'semantic', taskID: 'P00-T001',
    path: '/stages/preflight',
    message: 'preflight must set journal state .g6-beginning via begin-task',
  }]);
});

test('PLAN_EVIDENCE_JOURNAL_STATE: commit not commit-task', () => {
  const task = baseTask({
    stages: baseTask().stages.map((s) => s.name === 'commit' ? {
      name: 'commit', steps: [{ kind: 'controller-action', action: 'begin-task' }],
    } : s),
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_EVIDENCE_JOURNAL_STATE', category: 'semantic', taskID: 'P00-T001',
    path: '/stages/commit',
    message: 'commit must set journal state .g6-committing via commit-task',
  }]);
});

test('PLAN_EVIDENCE_JOURNAL_STATE: evidence not finalize-evidence', () => {
  const task = baseTask({
    stages: baseTask().stages.map((s) => s.name === 'evidence' ? {
      name: 'evidence', steps: [{ kind: 'controller-action', action: 'commit-task' }],
    } : s),
  });
  const got = auditMutationPolicy(task);
  assert.deepEqual(got, [{
    id: 'PLAN_EVIDENCE_JOURNAL_STATE', category: 'semantic', taskID: 'P00-T001',
    path: '/stages/evidence',
    message: 'evidence must set journal state .g6-finalizing via finalize-evidence',
  }]);
});

// ---------------------------------------------------------------------------
// buildMutationPolicies — per-stage bounded allowlists
// ---------------------------------------------------------------------------

test('buildMutationPolicies emits one policy per stage plus per-command red/green', () => {
  const policies = buildMutationPolicies(baseTask());
  const stages = policies.map((p) => p.stage);
  // preflight, test-authoring, red (one command), implementation, green (one), commit, evidence
  assert.deepEqual(stages, [
    'preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence',
  ]);
});

test('begin-task policy allows the evidence path + .g6-beginning + token-owned task root', () => {
  const p = buildMutationPolicies(baseTask()).find((x) => x.stage === 'preflight');
  assert.deepEqual(p.allowed, ['evidence/P00-T001.json']);
  assert.deepEqual(p.journals, ['.g6-beginning']);
  assert.deepEqual(p.temporaryRoots, [TASK_ROOT]);
  assert.equal(p.evidencePath, 'evidence/P00-T001.json');
});

test('test-authoring policy allows declared tests/fixtures + Red-scaffold path', () => {
  const p = buildMutationPolicies(baseTask()).find((x) => x.stage === 'test-authoring');
  assert.deepEqual(p.allowed, ['Sources/Foo.swift', 'Tests/Foo.test.swift']);
  assert.deepEqual(p.journals, ['.g6-part']);
});

test('red process-leaf policy allows only the declared command child scratch path', () => {
  const p = buildMutationPolicies(baseTask()).find((x) => x.stage === 'red');
  assert.deepEqual(p.allowed, []);
  assert.deepEqual(p.temporaryRoots, [`${SCRATCH_ROOT}/P00-T001.RED.001.PROC.001`]);
  assert.deepEqual(p.journals, ['.g6-part']);
  assert.equal(p.commandID, 'P00-T001.RED.001');
});

test('implementation policy allows task file rows + scaffold replacement', () => {
  const p = buildMutationPolicies(baseTask()).find((x) => x.stage === 'implementation');
  // modifies Sources/Foo.swift (also the scaffold replacement path)
  assert.deepEqual(p.allowed, ['Sources/Foo.swift']);
  assert.deepEqual(p.journals, ['.g6-part']);
});

test('commit policy allows only the exact product commit boundary, never the evidence path', () => {
  const p = buildMutationPolicies(baseTask()).find((x) => x.stage === 'commit');
  assert.deepEqual(p.allowed, ['Sources/Foo.swift']);
  assert.ok(!p.allowed.includes('evidence/P00-T001.json'),
    'commit policy must never allow the evidence path');
  assert.deepEqual(p.journals, ['.g6-committing']);
  assert.equal(p.evidencePath, 'evidence/P00-T001.json');
});

test('evidence policy allows the evidence path + token-owned root + finalizing journals', () => {
  const p = buildMutationPolicies(baseTask()).find((x) => x.stage === 'evidence');
  assert.deepEqual(p.allowed, ['evidence/P00-T001.json']);
  assert.deepEqual(p.temporaryRoots, [TASK_ROOT]);
  assert.deepEqual(p.journals, ['.g6-part', '.g6-finalizing']);
  assert.equal(p.evidencePath, 'evidence/P00-T001.json');
});

// ---------------------------------------------------------------------------
// compareObservedMutations — inline leakage controls
// ---------------------------------------------------------------------------

test('PLAN_REPOSITORY_MUTATION_UNDECLARED: observed repo path outside allowlist', () => {
  const policy = { stage: 'implementation', taskID: 'P00-T001', allowed: ['Sources/Foo.swift'], temporaryRoots: [], journals: ['.g6-part'] };
  const got = compareObservedMutations(policy, ['Sources/Foo.swift', 'Sources/Undeclared.swift']);
  assert.deepEqual(got, [{
    id: 'PLAN_REPOSITORY_MUTATION_UNDECLARED', category: 'semantic', taskID: 'P00-T001',
    path: 'Sources/Undeclared.swift',
    message: 'observed path "Sources/Undeclared.swift" is not in the declared repository allowlist for stage implementation',
  }]);
});

test('PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT: observed temp path outside command root', () => {
  const root = `${SCRATCH_ROOT}/P00-T001.RED.001.PROC.001`;
  const policy = { stage: 'red', taskID: 'P00-T001', allowed: [], temporaryRoots: [root], journals: ['.g6-part'] };
  const got = compareObservedMutations(policy, [`${root}/out.txt`, `${SCRATCH_ROOT}/OUTSIDE/leak`]);
  assert.deepEqual(got, [{
    id: 'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT', category: 'semantic', taskID: 'P00-T001',
    path: `${SCRATCH_ROOT}/OUTSIDE/leak`,
    message: `observed temporary path "${SCRATCH_ROOT}/OUTSIDE/leak" is outside the command temporary root for stage red`,
  }]);
});

test('PLAN_EVIDENCE_JOURNAL_STATE: observed journal path outside allowed journals', () => {
  const policy = { stage: 'preflight', taskID: 'P00-T001', allowed: [], temporaryRoots: [], journals: ['.g6-beginning'] };
  const got = compareObservedMutations(policy, ['.g6-beginning', '.g6-committing']);
  assert.deepEqual(got, [{
    id: 'PLAN_EVIDENCE_JOURNAL_STATE', category: 'semantic', taskID: 'P00-T001',
    path: '.g6-committing',
    message: 'observed journal path ".g6-committing" is outside the allowed journal states for stage preflight',
  }]);
});

test('compareObservedMutations accepts a fully-conforming observed set (zero findings)', () => {
  const policy = { stage: 'implementation', taskID: 'P00-T001', allowed: ['Sources/Foo.swift', 'Tests/Foo.test.swift'], temporaryRoots: [], journals: ['.g6-part'] };
  const got = compareObservedMutations(policy, ['Sources/Foo.swift', '.g6-part']);
  assert.deepEqual(got, []);
});

// ---------------------------------------------------------------------------
// Path normalization rejection — absolute repo paths, parent traversal,
// symlink escape, overlapping wildcard policies, outside repo/temp root
// ---------------------------------------------------------------------------

test('normalizePath collapses "." and duplicate slashes, strips trailing slash', () => {
  assert.equal(normalizePath('a/./b//c/'), 'a/b/c');
  assert.equal(normalizePath('a/b'), 'a/b');
  assert.equal(normalizePath('/x/y'), '/x/y');
});

test('normalizePath rejects parent traversal and symlink escape (.. segments)', () => {
  assert.equal(normalizePath('../escape'), null);
  assert.equal(normalizePath('a/../b'), null);
  assert.equal(normalizePath('a/../../b'), null);
  assert.equal(normalizePath('/etc/../../../passwd'), null);
});

test('normalizePath rejects empty / NUL / non-string input', () => {
  assert.equal(normalizePath(''), null);
  assert.equal(normalizePath('a\0b'), null);
  assert.equal(normalizePath(null), null);
  assert.equal(normalizePath(42), null);
});

test('absolute repository path observed under a repo-relative-only policy is undeclared', () => {
  // An absolute path that is not under any declared temporary root is a
  // temporary mutation outside the command temporary root.
  const policy = { stage: 'implementation', taskID: 'P00-T001', allowed: ['Sources/Foo.swift'], temporaryRoots: [], journals: ['.g6-part'] };
  const got = compareObservedMutations(policy, ['/Users/repo/Sources/Foo.swift']);
  assert.equal(got.length, 1);
  assert.equal(got[0].id, 'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT');
  assert.equal(got[0].path, '/Users/repo/Sources/Foo.swift');
});

test('observed path with parent traversal is rejected as undeclared', () => {
  const policy = { stage: 'implementation', taskID: 'P00-T001', allowed: ['Sources/Foo.swift'], temporaryRoots: [], journals: ['.g6-part'] };
  const got = compareObservedMutations(policy, ['Sources/Foo.swift', '../escape']);
  assert.equal(got.length, 1);
  assert.equal(got[0].id, 'PLAN_REPOSITORY_MUTATION_UNDECLARED');
});

test('overlapping temporary-root policies are rejected', () => {
  const policy = {
    stage: 'red', taskID: 'P00-T001', allowed: [], journals: ['.g6-part'],
    temporaryRoots: [`${SCRATCH_ROOT}/root`, `${SCRATCH_ROOT}/root/sub`],
  };
  const got = compareObservedMutations(policy, []);
  assert.equal(got.length, 1);
  assert.equal(got[0].id, 'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT');
  assert.ok(got[0].message.includes('overlapping temporary root policies'));
});

test('evidence path observed during commit is undeclared (commit never mutates evidence)', () => {
  const policy = { stage: 'commit', taskID: 'P00-T001', allowed: ['Sources/Foo.swift'], temporaryRoots: [], journals: ['.g6-committing'], evidencePath: 'evidence/P00-T001.json' };
  const got = compareObservedMutations(policy, ['Sources/Foo.swift', 'evidence/P00-T001.json']);
  assert.equal(got.length, 1);
  assert.equal(got[0].id, 'PLAN_REPOSITORY_MUTATION_UNDECLARED');
  assert.equal(got[0].path, 'evidence/P00-T001.json');
});

// ---------------------------------------------------------------------------
// Fixture-driven leakage tests (one exact finding each)
// ---------------------------------------------------------------------------

test('repository-mutation-leak fixture yields exactly PLAN_REPOSITORY_MUTATION_UNDECLARED', () => {
  const fx = loadFixture('repository-mutation-leak.json');
  const policies = buildMutationPolicies(fx.task);
  const policy = policies.find((p) => p.stage === fx.stage);
  const got = compareObservedMutations(policy, fx.observedPaths);
  assert.deepEqual(got, [fx.expected]);
});

test('temporary-mutation-leak fixture yields exactly PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT', () => {
  const fx = loadFixture('temporary-mutation-leak.json');
  const policies = buildMutationPolicies(fx.task);
  const policy = policies.find((p) => p.stage === fx.stage);
  const got = compareObservedMutations(policy, fx.observedPaths);
  assert.deepEqual(got, [fx.expected]);
});

// ---------------------------------------------------------------------------
// Determinism — compareObservedMutations is stable across runs
// ---------------------------------------------------------------------------

test('compareObservedMutations is stable across two runs (deterministic order)', () => {
  const policy = { stage: 'implementation', taskID: 'P00-T001', allowed: ['a.swift'], temporaryRoots: [], journals: ['.g6-part'] };
  const observed = ['b.swift', 'a.swift', 'c.swift'];
  const r1 = compareObservedMutations(policy, observed);
  const r2 = compareObservedMutations(policy, observed);
  assert.deepEqual(r1, r2);
  assert.equal(r1.length, 2);
  // sorted by path: b.swift then c.swift
  assert.deepEqual(r1.map((f) => f.path), ['b.swift', 'c.swift']);
});
