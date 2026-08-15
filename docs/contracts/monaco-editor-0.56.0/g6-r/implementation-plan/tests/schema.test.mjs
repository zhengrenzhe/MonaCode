// G6-R execution schema rejection tests (TDD Step 1).
// Validates the closed ExecutionPlan schema and the repository-owned validator.
// Node built-in test runner only; no third-party dependencies.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { validateExecutionPlan } from '../lib/schema.mjs';
import { makeFinding, sortFindings } from '../lib/findings.mjs';
import { canonicalJSONStringify } from '../lib/canonical-json.mjs';

const ids = (findings) => findings.map((f) => f.id);
const clone = (v) => structuredClone(v);

const TASK_ID = 'P01-T001';
const BASE = 'ac7d02a68dd25016e8c2e32a78cdae9a822fedf6';
const ZERO40 = '0'.repeat(40);
const ZERO64 = '0'.repeat(64);

const redCommand = {
  commandID: 'P01-T001.RED.001',
  kind: 'process',
  networkMode: 'forbidden',
  timeoutMs: 60000,
  leaves: [
    {
      leafID: 'P01-T001.RED.001.PROC.001',
      executable: '/usr/bin/swift',
      toolchainRow: 'swift-6.0',
      args: ['test'],
      timeoutMs: 60000,
    },
  ],
};

const greenCommand = {
  commandID: 'P01-T001.GREEN.001',
  kind: 'process',
  networkMode: 'forbidden',
  timeoutMs: 60000,
  leaves: [
    {
      leafID: 'P01-T001.GREEN.001.PROC.001',
      executable: '/usr/bin/swift',
      toolchainRow: 'swift-6.0',
      args: ['test'],
      timeoutMs: 60000,
    },
  ],
};

const basePlan = {
  planID: 'P01',
  baseCommit: BASE,
  planHash: ZERO40,
  tasks: [
    {
      taskID: TASK_ID,
      stages: [
        { name: 'preflight', steps: [{ kind: 'controller-action', action: 'begin-task' }] },
        { name: 'test-authoring', steps: [{ kind: 'authoring-operation', operation: 'write-test-contract' }] },
        { name: 'red', steps: [{ kind: 'verification-command', command: redCommand }] },
        { name: 'implementation', steps: [{ kind: 'implementation-operation', operation: 'implement-feature' }] },
        { name: 'green', steps: [{ kind: 'verification-command', command: greenCommand }] },
        { name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] },
        { name: 'evidence', steps: [{ kind: 'controller-action', action: 'finalize-evidence' }] },
      ],
      testContract: {
        contractID: 'P01-T001-TEST',
        cases: [
          {
            caseID: 'C001',
            file: { path: 'tests/P01-T001.test.swift', availability: 'local' },
            checker: 'swift-test',
            target: 'MonaCodeTests',
            testSymbol: 'testP01T001Red()',
            fixtures: { kind: 'inline', values: {} },
            assertions: [{ id: 'A1', operand: 'equals' }],
            redLeafID: 'P01-T001.RED.001.PROC.001',
            greenLeafID: 'P01-T001.GREEN.001.PROC.001',
            inheritedOutput: false,
            failureClass: 'assertion',
            authoringOperation: 'write-test-contract',
            source: 'task-step',
          },
        ],
      },
      completionAssertions: ['A1', 'A2'],
      workspace: {
        ownershipToken: ZERO64,
        taskRoot: '/Users/bytedance/Documents/ChatGPT/MonaCode/.worktrees/P01-T001',
        planHash: ZERO40,
        taskHash: ZERO40,
        baseHash: BASE,
        currentStage: 'preflight',
        lifecycleState: 'idle',
      },
      redScaffold: {
        sourcePath: 'src/P01-T001.swift',
        declarationText: 'let x = 1',
        declarationHash: 'sha256:' + ZERO64,
        sentinelBehavior: 'compile-fail',
        createOwner: 'test-authoring',
        replacementOwner: 'implementation',
        redAssertionID: 'A1',
        finalAbsenceAssertion: 'A2',
      },
      productCommit: {
        author: { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' },
        committer: { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' },
        message: 'monacode: complete P01-T001',
        preflightBaseParent: BASE,
        stagedProductPaths: ['src/P01-T001.swift'],
        hooksDisabled: true,
        signingDisabled: true,
        evidenceExcluded: true,
      },
      evidenceCommit: {
        author: { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' },
        committer: { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' },
        message: 'evidence(monacode): complete P01-T001',
        parentCommit: '1'.repeat(40),
        firstParentSuccessor: 'immediate',
        stagedEvidencePath: 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/evidence/P01-T001.json',
        laterFirstParentTouches: 0,
        hooksDisabled: true,
        signingDisabled: true,
        selectorMode: 'external-git',
        prohibitsSelfEmbedding: true,
        evidenceSchema: 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-execution-schema.json',
        verifiedAssertions: ['A1', 'A2'],
      },
    },
  ],
};

// --- mutations ---

const withoutGreen = (() => {
  const p = clone(basePlan);
  p.tasks[0].stages = p.tasks[0].stages.filter((s) => s.name !== 'green');
  return p;
})();

const eighthStage = (() => {
  const p = clone(basePlan);
  p.tasks[0].stages.push({ name: 'post-evidence', steps: [{ kind: 'controller-action', action: 'begin-task' }] });
  return p;
})();

const evidenceBeforeCommit = (() => {
  const p = clone(basePlan);
  const stages = p.tasks[0].stages;
  const commitIdx = stages.findIndex((s) => s.name === 'commit');
  const evidenceIdx = stages.findIndex((s) => s.name === 'evidence');
  [stages[commitIdx], stages[evidenceIdx]] = [stages[evidenceIdx], stages[commitIdx]];
  return p;
})();

const freeFormCommand = (() => {
  const p = clone(basePlan);
  p.tasks[0].stages.find((s) => s.name === 'red').steps[0].command = 'swift test --parallel';
  return p;
})();

const withoutTimeout = (() => {
  const p = clone(basePlan);
  delete p.tasks[0].stages.find((s) => s.name === 'red').steps[0].command.timeoutMs;
  return p;
})();

const unknownAvailability = (() => {
  const p = clone(basePlan);
  p.tasks[0].testContract.cases[0].file.availability = 'cloud';
  return p;
})();

const withoutEvidenceSchema = (() => {
  const p = clone(basePlan);
  delete p.tasks[0].evidenceCommit.evidenceSchema;
  return p;
})();

const extraProperty = (() => {
  const p = clone(basePlan);
  p.__extra = true;
  return p;
})();

// --- Fix #1 / Fix #2 fixtures ---

const nullStep = (() => {
  const p = clone(basePlan);
  p.tasks[0].stages.find((s) => s.name === 'preflight').steps = [null];
  return p;
})();

const validArchive = {
  format: 'tar.gz',
  entryCount: 3,
  exactExpandedBytes: 2048,
  maxExpandedBytes: 8192,
  extractionRoot: 'foo-1.0.0',
  rejectAbsolute: true,
  rejectTraversal: true,
  rejectSymlinks: true,
  rejectHardLinks: true,
  rejectDevices: true,
  rejectDuplicateNormalized: true,
  rejectComponentCollisions: true,
  rejectProbeCollisions: true,
};

const makeSourceAcqStep = (archiveOverride) => ({
  kind: 'source-acquisition',
  acquisition: {
    url: 'https://registry.npmjs.org/foo/-/foo-1.0.0.tgz',
    allowedHost: 'registry.npmjs.org',
    redirectChain: ['registry.npmjs.org'],
    expectedBytes: 1024,
    maxBytes: 4096,
    sha256: 'sha256:' + 'a'.repeat(64),
    license: 'MIT',
    outputPath: 'vendor/foo-1.0.0.tgz',
    disposition: 'task-step',
    taskOwner: 'P01-T001',
    stageOwner: 'implementation',
    timeoutMs: 30000,
    existingOutputBehavior: 'require-same-hash',
    archive: archiveOverride === undefined ? clone(validArchive) : archiveOverride,
  },
});

const addSourceAcqStep = (plan, archiveOverride) => {
  const p = clone(plan);
  p.tasks[0].stages.find((s) => s.name === 'implementation').steps.push(makeSourceAcqStep(archiveOverride));
  return p;
};

const validWithSourceAcquisition = addSourceAcqStep(basePlan);

const archiveMissingFormat = addSourceAcqStep(basePlan, (() => {
  const a = clone(validArchive); delete a.format; return a;
})());

const archiveRejectAbsoluteFalse = addSourceAcqStep(basePlan, (() => {
  const a = clone(validArchive); a.rejectAbsolute = false; return a;
})());

// --- tests ---

test('canonicalJSONStringify sorts object keys and preserves array order', () => {
  assert.equal(canonicalJSONStringify({ b: 1, a: 2 }), '{"a":2,"b":1}');
  assert.equal(canonicalJSONStringify([3, 1, 2]), '[3,1,2]');
  assert.equal(canonicalJSONStringify({ z: [3, 1], a: { y: 1, x: 0 } }), '{"a":{"x":0,"y":1},"z":[3,1]}');
  assert.equal(canonicalJSONStringify(null), 'null');
});

test('makeFinding produces the canonical finding shape', () => {
  const f = makeFinding({ id: 'X', category: 'structure', taskID: 'P01-T001', path: '/p', message: 'm' });
  assert.deepEqual(f, { id: 'X', category: 'structure', taskID: 'P01-T001', path: '/p', message: 'm' });
  const g = makeFinding({ id: 'Y', category: 'semantic', path: '/q', message: 'n' });
  assert.equal(g.taskID, null);
});

test('sortFindings orders by canonical ID then path', () => {
  const out = sortFindings([
    makeFinding({ id: 'PLAN_COMMAND_SHAPE', category: 'c', path: '/b', message: 'm' }),
    makeFinding({ id: 'PLAN_STAGE_SET', category: 'c', path: '/a', message: 'm' }),
    makeFinding({ id: 'PLAN_STAGE_ORDER', category: 'c', path: '/a', message: 'm' }),
  ]);
  assert.deepEqual(out.map((f) => f.id), ['PLAN_STAGE_SET', 'PLAN_STAGE_ORDER', 'PLAN_COMMAND_SHAPE']);
});

test('base plan is valid (zero findings)', () => {
  assert.deepEqual(ids(validateExecutionPlan(basePlan)), []);
});

test('omit a stage -> PLAN_STAGE_SET', () => {
  assert.deepEqual(ids(validateExecutionPlan(withoutGreen)), ['PLAN_STAGE_SET']);
});

test('eighth stage -> PLAN_STAGE_SET', () => {
  assert.deepEqual(ids(validateExecutionPlan(eighthStage)), ['PLAN_STAGE_SET']);
});

test('swap commit/evidence order -> PLAN_STAGE_ORDER', () => {
  assert.deepEqual(ids(validateExecutionPlan(evidenceBeforeCommit)), ['PLAN_STAGE_ORDER']);
});

test('free-form command string -> PLAN_COMMAND_SHAPE', () => {
  assert.deepEqual(ids(validateExecutionPlan(freeFormCommand)), ['PLAN_COMMAND_SHAPE']);
});

test('omit timeout -> PLAN_COMMAND_SHAPE', () => {
  assert.deepEqual(ids(validateExecutionPlan(withoutTimeout)), ['PLAN_COMMAND_SHAPE']);
});

test('unknown availability class -> PLAN_PATH_AVAILABILITY', () => {
  assert.deepEqual(ids(validateExecutionPlan(unknownAvailability)), ['PLAN_PATH_AVAILABILITY']);
});

test('omit evidence schema -> PLAN_EVIDENCE_CONTRACT', () => {
  assert.deepEqual(ids(validateExecutionPlan(withoutEvidenceSchema)), ['PLAN_EVIDENCE_CONTRACT']);
});

test('extra property -> PLAN_SCHEMA_ADDITIONAL_PROPERTY', () => {
  assert.deepEqual(ids(validateExecutionPlan(extraProperty)), ['PLAN_SCHEMA_ADDITIONAL_PROPERTY']);
});

test('validator does not throw on malformed input', () => {
  assert.doesNotThrow(() => validateExecutionPlan(null));
  assert.doesNotThrow(() => validateExecutionPlan('not a plan'));
  assert.doesNotThrow(() => validateExecutionPlan(42));
  assert.doesNotThrow(() => validateExecutionPlan({}));
});

test('null step element -> PLAN_STAGE_STEP_INVALID (no throw)', () => {
  assert.doesNotThrow(() => validateExecutionPlan(nullStep));
  assert.deepEqual(ids(validateExecutionPlan(nullStep)), ['PLAN_STAGE_STEP_INVALID']);
});

test('valid source acquisition with archive is accepted', () => {
  assert.deepEqual(ids(validateExecutionPlan(validWithSourceAcquisition)), []);
});

test('archive missing format -> PLAN_SOURCE_ARCHIVE_INVALID', () => {
  assert.deepEqual(ids(validateExecutionPlan(archiveMissingFormat)), ['PLAN_SOURCE_ARCHIVE_INVALID']);
});

test('archive rejectAbsolute:false -> PLAN_SOURCE_ARCHIVE_INVALID', () => {
  assert.deepEqual(ids(validateExecutionPlan(archiveRejectAbsoluteFalse)), ['PLAN_SOURCE_ARCHIVE_INVALID']);
});
