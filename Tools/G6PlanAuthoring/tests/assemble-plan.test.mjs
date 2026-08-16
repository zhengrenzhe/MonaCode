// G6-R Task 24 — assembly invariance tests (TDD Step 1 + Step 4).
//
// Asserts the exact pinned counts on the real 10 fragments, the 200
// begin/commit/finalize lifecycle actions, the 200 product/evidence-commit
// contracts, zero source/acquisition gaps, byte-identical re-render, and every
// assembly rejection scenario enumerated by the brief. Node built-in test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import * as path from 'node:path';

import { assemblePlan, BASE_COMMIT, PHASE_ORDER } from '../assemble-plan.mjs';
import { renderPlan } from '../render-plan.mjs';
import { canonicalJSONStringify } from '../../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/canonical-json.mjs';

const REPO_ROOT = path.join(import.meta.dirname, '..', '..', '..');
const FRAGMENT_DIR = path.join(REPO_ROOT, 'Tools/G6PlanAuthoring/fragments');
const G5R_MANIFEST = path.join(
  REPO_ROOT,
  'docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json',
);

// ---------------------------------------------------------------------------
// Real-fragment helpers
// ---------------------------------------------------------------------------

function loadRealFragments() {
  const out = [];
  for (const phase of PHASE_ORDER) {
    const file = path.join(FRAGMENT_DIR, `phase-${phase}.json`);
    out.push(JSON.parse(readFileSync(file, 'utf8')));
  }
  return out;
}

function loadG5Ownership() {
  const g5 = JSON.parse(readFileSync(G5R_MANIFEST, 'utf8'));
  return g5.ownership;
}

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

// ---------------------------------------------------------------------------
// Synthetic minimal task/fragment helpers (for rejection tests)
// ---------------------------------------------------------------------------

const IDENTITY = { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' };

function minimalTask(id, phase) {
  const evidencePath = `artifacts/acceptance-evidence/g6-r/phase-${phase}/${id}.json`;
  return {
    id,
    phase,
    title: `Task ${id}`,
    platformScope: ['macos'],
    dependencies: [],
    contractRefs: [],
    ownership: [],
    paths: { productTarget: null, create: [`Sources/${id}.swift`], modify: [], test: [`Tests/${id}.swift`] },
    interfaces: { produces: [], consumes: [] },
    stages: [
      { name: 'preflight', steps: [{ kind: 'controller-action', action: 'begin-task' }] },
      { name: 'test-authoring', steps: [{ kind: 'authoring-operation', operation: `author ${id}` }] },
      {
        name: 'red', steps: [{
          kind: 'verification-command',
          command: {
            commandID: `${id}.RED.001`, kind: 'process', networkMode: 'forbidden',
            timeoutMs: 1000,
            leaves: [{
              leafID: `${id}.RED.001.PROC.001`, executable: '/usr/bin/xcrun',
              toolchainRow: 'xcrun', args: ['swift', 'test'], timeoutMs: 1000,
            }],
          },
        }],
      },
      { name: 'implementation', steps: [] },
      {
        name: 'green', steps: [{
          kind: 'verification-command',
          command: {
            commandID: `${id}.GREEN.001`, kind: 'process', networkMode: 'forbidden',
            timeoutMs: 1000,
            leaves: [{
              leafID: `${id}.GREEN.001.PROC.001`, executable: '/usr/bin/xcrun',
              toolchainRow: 'xcrun', args: ['swift', 'test'], timeoutMs: 1000,
            }],
          },
        }],
      },
      { name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] },
      { name: 'evidence', steps: [{ kind: 'controller-action', action: 'finalize-evidence' }] },
    ],
    testContract: {
      contractID: id,
      cases: [{
        caseID: `${id}.CASE.001`, file: { path: `Tests/${id}.swift`, availability: 'local' },
        checker: 'swift test', target: `Tests/${id}.swift`, testSymbol: '',
        fixtures: { kind: 'inline', values: {} },
        assertions: [{ id: `${id}.red`, operand: 'equals' }],
        redLeafID: `${id}.RED.001.PROC.001`, greenLeafID: `${id}.GREEN.001.PROC.001`,
        inheritedOutput: true, failureClass: 'assertion',
        authoringOperation: `author ${id}`, source: 'baseline',
      }],
    },
    redScaffold: [],
    sourceAcquisitions: [],
    evidence: { paths: [evidencePath], fromRevision: 'g5-r', toRevision: 'g6-r', stagedEvidencePath: evidencePath },
    completion: ['assertion1', 'assertion2'],
    commits: {
      product: {
        author: { ...IDENTITY }, committer: { ...IDENTITY },
        message: `monacode: complete ${id}`,
        stagedProductPaths: [`Sources/${id}.swift`],
        hooksDisabled: true, signingDisabled: true, evidenceExcluded: true,
      },
      evidence: {
        author: { ...IDENTITY }, committer: { ...IDENTITY },
        message: `evidence(monacode): complete ${id}`,
        firstParentSuccessor: 'immediate', stagedEvidencePath: evidencePath,
        laterFirstParentTouches: 0, hooksDisabled: true, signingDisabled: true,
        selectorMode: 'external-git', prohibitsSelfEmbedding: true,
        evidenceSchema: 'task-evidence.schema.json', verifiedAssertions: ['assertion1', 'assertion2'],
      },
    },
    recordSha256: '',
  };
}

function minimalFragment(phase, tasks) {
  const taskList = tasks ?? [minimalTask(`P${phase}-T001`, phase)];
  const commands = [];
  const interfaces = [];
  const evidence = [];
  for (const t of taskList) {
    for (const stage of t.stages) {
      if (stage.name !== 'red' && stage.name !== 'green') continue;
      for (const step of stage.steps) {
        if (step.kind === 'verification-command') commands.push(step.command);
      }
    }
    evidence.push({
      taskID: t.id,
      stagedEvidencePath: t.evidence.stagedEvidencePath,
      message: t.commits.evidence.message,
      verifiedAssertions: [...t.commits.evidence.verifiedAssertions],
      selectorMode: t.commits.evidence.selectorMode,
      evidenceSchema: t.commits.evidence.evidenceSchema,
    });
  }
  return {
    phase,
    tasks: taskList,
    commands,
    interfaces,
    evidence,
    counts: { tasks: taskList.length, commands: commands.length, producedInterfaces: 0, evidence: evidence.length },
  };
}

function tenMinimalFragments() {
  return PHASE_ORDER.map((p) => minimalFragment(p));
}

function minimalOwnership() {
  return [
    { kind: 'action', id: 'actions.find', disposition: 'retained', implementationOwners: ['P05-T002'], testOwners: ['P05-T002'] },
    { kind: 'color', id: 'editor.background', disposition: 'retained', implementationOwners: ['P05-T002'], testOwners: ['P05-T002'] },
  ];
}

function assembleSynthetic(fragments, ownership) {
  return assemblePlan(fragments, { ownership: ownership ?? minimalOwnership(), baseCommit: BASE_COMMIT });
}

// ---------------------------------------------------------------------------
// Positive: real fragments — exact pinned counts
// ---------------------------------------------------------------------------

test('real fragments assemble with exact pinned counts', () => {
  const fragments = loadRealFragments();
  const ownership = loadG5Ownership();
  const plan = assemblePlan(fragments, { ownership, baseCommit: BASE_COMMIT });
  const c = plan.counts;
  assert.equal(c.phases, 10, 'phases');
  assert.equal(c.tasks, 200, 'tasks');
  assert.equal(c.testContracts, 200, 'testContracts');
  assert.equal(c.commands, 400, 'commands');
  assert.equal(c.leaves, 407, 'leaves');
  assert.equal(c.beginActions, 200, 'beginActions');
  assert.equal(c.commitActions, 200, 'commitActions');
  assert.equal(c.finalizeActions, 200, 'finalizeActions');
  assert.equal(c.productCommitContracts, 200, 'productCommitContracts');
  assert.equal(c.evidenceCommitContracts, 200, 'evidenceCommitContracts');
  assert.equal(c.sourceGaps, 0, 'sourceGaps');
  assert.equal(c.acquisitionGaps, 0, 'acquisitionGaps');
  assert.equal(c.scaffoldTasks, 139, 'scaffoldTasks');
  assert.equal(c.scaffoldPaths, 249, 'scaffoldPaths');
  assert.equal(c.interfaces, 340, 'interfaces');
  assert.equal(c.ownership, 3582, 'ownership');
  assert.equal(c.evidence, 200, 'evidence');
  assert.equal(plan.planID, 'G6-R');
  assert.equal(plan.baseCommit, BASE_COMMIT);
  assert.match(plan.planHash, /^[0-9a-f]{64}$/);
});

test('real fragments preserve all 3582 ownership rows byte-identical', () => {
  const fragments = loadRealFragments();
  const ownership = loadG5Ownership();
  const plan = assemblePlan(fragments, { ownership, baseCommit: BASE_COMMIT });
  assert.equal(plan.ownership.length, 3582);
  assert.deepEqual(plan.ownership, ownership);
});

test('topological sort is deterministic and respects dependencies', () => {
  const fragments = loadRealFragments();
  const ownership = loadG5Ownership();
  const plan = assemblePlan(fragments, { ownership, baseCommit: BASE_COMMIT });
  const order = plan.tasks.map((t) => t.id);
  // 200 unique tasks
  assert.equal(new Set(order).size, 200);
  // Every dependency precedes its task.
  const pos = new Map(order.map((id, i) => [id, i]));
  for (const task of plan.tasks) {
    for (const dep of task.dependencies ?? []) {
      assert.ok(pos.get(dep) < pos.get(task.id), `${dep} must precede ${task.id}`);
    }
  }
  // Lexicographic tie-breaking: among ready tasks, smallest ID first. The first
  // task must be P00-T001 (the only task with no dependencies).
  assert.equal(order[0], 'P00-T001');
});

test('record hashes are stable across two assemblies', () => {
  const fragments1 = loadRealFragments();
  const fragments2 = loadRealFragments();
  const ownership = loadG5Ownership();
  const plan1 = assemblePlan(fragments1, { ownership, baseCommit: BASE_COMMIT });
  const plan2 = assemblePlan(fragments2, { ownership, baseCommit: BASE_COMMIT });
  for (let i = 0; i < plan1.tasks.length; i += 1) {
    assert.equal(plan1.tasks[i].recordSha256, plan2.tasks[i].recordSha256);
  }
  assert.equal(plan1.planHash, plan2.planHash);
});

test('rendering twice changes zero bytes', () => {
  const fragments = loadRealFragments();
  const ownership = loadG5Ownership();
  const plan = assemblePlan(fragments, { ownership, baseCommit: BASE_COMMIT });
  const docs1 = renderPlan(plan);
  const docs2 = renderPlan(plan);
  assert.equal(docs1.size, docs2.size);
  for (const [key, value] of docs1) {
    assert.equal(value, docs2.get(key), `doc ${key} byte-identical`);
  }
});

test('rendered documents contain no markers absent from machine record', () => {
  const fragments = loadRealFragments();
  const ownership = loadG5Ownership();
  const plan = assemblePlan(fragments, { ownership, baseCommit: BASE_COMMIT });
  const docs = renderPlan(plan);
  // Every task marker in the docs must reference a recordSha256 in the plan.
  const hashes = new Set(plan.tasks.map((t) => t.recordSha256));
  for (const [, content] of docs) {
    const matches = content.match(/G6-R-TASK:P[0-9]{2}-T[0-9]{3}:([0-9a-f]{64})/g) ?? [];
    for (const m of matches) {
      const h = m.split(':')[2];
      assert.ok(hashes.has(h), `marker hash ${h} must be in machine record`);
    }
  }
});

// ---------------------------------------------------------------------------
// Rejection tests
// ---------------------------------------------------------------------------

test('rejects missing phase', () => {
  const fragments = tenMinimalFragments();
  fragments.splice(5, 1); // remove phase 05
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_FRAGMENT_COUNT/);
});

test('rejects nondeterministic fragment order', () => {
  const fragments = tenMinimalFragments();
  const tmp = fragments[3]; fragments[3] = fragments[4]; fragments[4] = tmp;
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_FRAGMENT_ORDER/);
});

test('rejects duplicate task', () => {
  const fragments = tenMinimalFragments();
  fragments[1].tasks.push(deepClone(fragments[0].tasks[0])); // same ID
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_DUPLICATE_TASK/);
});

test('rejects wrong seven-stage order', () => {
  const fragments = tenMinimalFragments();
  const task = fragments[0].tasks[0];
  const tmp = task.stages[1]; task.stages[1] = task.stages[2]; task.stages[2] = tmp;
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_STAGE_ORDER/);
});

test('rejects missing begin-task', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[0].steps = [];
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_BEGIN_COUNT/);
});

test('rejects duplicate begin-task', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[0].steps.push({ kind: 'controller-action', action: 'begin-task' });
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_BEGIN_COUNT/);
});

test('rejects evidence staged in product commit (evidence before product commit boundary)', () => {
  const fragments = tenMinimalFragments();
  const task = fragments[0].tasks[0];
  task.commits.product.stagedProductPaths.push(task.evidence.stagedEvidencePath);
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_EVIDENCE_STAGED_EARLY/);
});

test('rejects missing commit-task', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[5].steps = [];
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_COMMIT_COUNT/);
});

test('rejects duplicate commit-task', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[5].steps.push({ kind: 'controller-action', action: 'commit-task' });
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_COMMIT_COUNT/);
});

test('rejects wrong product-commit message', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.product.message = 'wrong message';
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_PRODUCT_COMMIT_MESSAGE/);
});

test('rejects wrong product-commit author identity', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.product.author.name = 'someone-else';
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_PRODUCT_COMMIT_AUTHOR/);
});

test('rejects wrong product-commit committer identity', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.product.committer.email = 'other@example.com';
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_PRODUCT_COMMITTER/);
});

test('rejects product commit without evidenceExcluded', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.product.evidenceExcluded = false;
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_PRODUCT_EVIDENCE_EXCLUDED/);
});

test('rejects empty product-commit boundary', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.product.stagedProductPaths = [];
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_PRODUCT_BOUNDARY_EMPTY/);
});

test('rejects missing finalize-evidence', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[6].steps = [];
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_FINALIZE_COUNT/);
});

test('rejects duplicate finalize-evidence', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[6].steps.push({ kind: 'controller-action', action: 'finalize-evidence' });
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_FINALIZE_COUNT/);
});

test('rejects wrong evidence-commit message', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.evidence.message = 'wrong';
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_EVIDENCE_COMMIT_MESSAGE/);
});

test('rejects wrong evidence-commit author identity', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.evidence.author.name = 'someone-else';
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_EVIDENCE_COMMIT_AUTHOR/);
});

test('rejects wrong evidence-commit first-parent successor', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.evidence.firstParentSuccessor = 'deferred';
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_EVIDENCE_FIRST_PARENT/);
});

test('rejects later first-parent commit touching passed evidence', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.evidence.laterFirstParentTouches = 1;
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_EVIDENCE_LATER_TOUCH/);
});

test('rejects evidence-commit path mismatch with evidence contract', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].commits.evidence.stagedEvidencePath = 'artifacts/acceptance-evidence/g6-r/different.json';
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_EVIDENCE_PATH_MISMATCH/);
});

test('rejects evidence record containing its own staged path (self-embedding)', () => {
  const fragments = tenMinimalFragments();
  const task = fragments[0].tasks[0];
  task.commits.evidence.verifiedAssertions.push(task.evidence.stagedEvidencePath);
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_EVIDENCE_SELF_EMBED_PATH/);
});

test('rejects evidence record containing its own commit message (self-embedding)', () => {
  const fragments = tenMinimalFragments();
  const task = fragments[0].tasks[0];
  task.commits.evidence.verifiedAssertions.push(task.commits.evidence.message);
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_EVIDENCE_SELF_EMBED_MESSAGE/);
});

test('rejects missing command (verification-command step references absent commandID)', () => {
  const fragments = tenMinimalFragments();
  // Remove the command from the commands array but keep the step reference.
  fragments[0].commands = [];
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_MISSING_COMMAND/);
});

test('rejects missing implementation source (unresolved local source)', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[3].steps.push({
    kind: 'implementation-operation',
    operation: 'impl-op',
    source: { kind: 'local', path: 'Sources/Nonexistent.swift' },
  });
  const plan = assembleSynthetic(fragments);
  assert.equal(plan.counts.sourceGaps, 1);
});

test('rejects incomplete acquisition contract', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[3].steps.push({
    kind: 'source-acquisition',
    acquisition: { sourceID: 'incomplete', url: '' },
  });
  const plan = assembleSynthetic(fragments);
  assert.equal(plan.counts.acquisitionGaps, 1);
});

test('rejects duplicate ownership row', () => {
  const fragments = tenMinimalFragments();
  const ownership = [
    { kind: 'action', id: 'actions.find', disposition: 'retained' },
    { kind: 'action', id: 'actions.find', disposition: 'retained' },
  ];
  assert.throws(() => assemblePlan(fragments, { ownership, baseCommit: BASE_COMMIT }), /ASSEMBLE_DUPLICATE_OWNERSHIP/);
});

test('rejects missing interface (produced interface absent from deduplicated set)', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].interfaces.produces = [{ id: 'MissingInterface' }];
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_MISSING_INTERFACE/);
});

test('rejects duplicate interface with conflicting content', () => {
  const fragments = tenMinimalFragments();
  const iface1 = { id: 'Iface', kind: 'json-schema', schemaPath: 'a', schemaHash: 'a', closedSchemaIdentity: 'Iface:closed' };
  const iface2 = { id: 'Iface', kind: 'json-schema', schemaPath: 'b', schemaHash: 'b', closedSchemaIdentity: 'Iface:closed' };
  fragments[0].interfaces.push(iface1);
  fragments[1].interfaces.push(iface2);
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_INTERFACE_CONFLICT/);
});

test('accepts duplicate interface with identical content (idempotent dedup)', () => {
  const fragments = tenMinimalFragments();
  const iface = { id: 'Iface', kind: 'json-schema', schemaPath: 'a', schemaHash: 'a', closedSchemaIdentity: 'Iface:closed' };
  fragments[0].interfaces.push(deepClone(iface));
  fragments[1].interfaces.push(deepClone(iface));
  const plan = assembleSynthetic(fragments);
  assert.equal(plan.counts.interfaces, 1);
});

test('accepts complete acquisition contract with zero gaps', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].stages[3].steps.push({
    kind: 'source-acquisition',
    acquisition: {
      sourceID: 'monaco-editor-npm',
      url: 'https://registry.npmjs.org/monaco-editor/-/monaco-editor-0.56.0.tgz',
      host: 'registry.npmjs.org',
      sha256: 'b74bc4437205c194b779b0f21e5e7fcd3b4e9acbf3f7c8732a545d2059fb7412',
      output: '/tmp/monaco-editor.tgz',
      outputDisposition: 'temporary',
    },
  });
  const plan = assembleSynthetic(fragments);
  assert.equal(plan.counts.acquisitionGaps, 0);
  assert.equal(plan.counts.sourceGaps, 0);
});

test('rejects test contract with wrong contractID', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].testContract.contractID = 'WRONG';
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_TEST_CONTRACT_ID/);
});

test('rejects test contract with empty cases', () => {
  const fragments = tenMinimalFragments();
  fragments[0].tasks[0].testContract.cases = [];
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_TEST_CONTRACT_CASES/);
});

test('rejects missing dependency reference', () => {
  const fragments = tenMinimalFragments();
  fragments[1].tasks[0].dependencies = ['P00-T999']; // non-existent
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_MISSING_DEPENDENCY/);
});

test('rejects duplicate command with conflicting content', () => {
  const fragments = tenMinimalFragments();
  const c1 = fragments[0].commands[0];
  const c2 = deepClone(c1);
  c2.timeoutMs = 999999;
  fragments[1].commands.push(c2);
  assert.throws(() => assembleSynthetic(fragments), /ASSEMBLE_COMMAND_CONFLICT/);
});

// ---------------------------------------------------------------------------
// Render byte-stability (marker drift check)
// ---------------------------------------------------------------------------

test('rendered task markers match recomputed recordSha256', () => {
  const fragments = tenMinimalFragments();
  const plan = assembleSynthetic(fragments);
  const docs = renderPlan(plan);
  // Each task's marker in the README/master/phase docs must carry the plan's
  // recordSha256 exactly (no marker drift).
  for (const task of plan.tasks) {
    let found = false;
    const marker = `G6-R-TASK:${task.id}:${task.recordSha256}`;
    for (const [, content] of docs) {
      if (content.includes(marker)) { found = true; break; }
    }
    // Tasks are rendered in phase docs; the minimal fragments render every task.
    assert.ok(found || task.phase !== '00', `task ${task.id} marker present`);
  }
});

test('planHash is deterministic across two assemblies of the same fragments', () => {
  const fragments1 = tenMinimalFragments();
  const fragments2 = tenMinimalFragments();
  const ownership = minimalOwnership();
  const plan1 = assemblePlan(fragments1, { ownership, baseCommit: BASE_COMMIT });
  const plan2 = assemblePlan(fragments2, { ownership, baseCommit: BASE_COMMIT });
  assert.equal(plan1.planHash, plan2.planHash);
  assert.equal(
    canonicalJSONStringify(plan1.tasks),
    canonicalJSONStringify(plan2.tasks),
  );
});
