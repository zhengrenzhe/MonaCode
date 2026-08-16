// G6-R Task 11 — migration invariance tests.
// Controls: P00-T001 (pipeline package-graph check) and P01-T001 (process swift-test).
// Asserts the migrateTask converter preserves every G5-R planning field, rewrites
// ONLY the evidence-root revision segment g5-r -> g6-r, derives the product/evidence
// commit subjects by exact ASCII concatenation, rejects message/ID/parent/staged-set
// mismatches, produces exactly seven ordered stages with one converted Red command
// and one converted Green command, one task-test contract selecting every Red/Green
// leaf exactly once, and a canonical record hash that is stable across two runs.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

import { migrateTask, buildCommitMessage, buildEvidenceCommitMessage, scaffoldMarker } from '../lib/migrate-task.mjs';
import { convertG5Command } from '../../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/command-grammar.mjs';
import { renderTask } from '../lib/render-task.mjs';
import { validatePhaseOverrides } from '../validate-overrides.mjs';
import { computeRendererPathHash, checkFeatureManifest, extractFragmentFeatureIDs, checkDependency } from '../verify-fragment.mjs';
import { mergeFragments } from '../lib/build-fragment.mjs';

const G5_MANIFEST = 'docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json';

function loadG5Task(taskID) {
  const plan = JSON.parse(fs.readFileSync(path.join(process.cwd(), G5_MANIFEST), 'utf8'));
  return plan.tasks.find((task) => task.id === taskID);
}

function loadG5Plan() {
  return JSON.parse(fs.readFileSync(path.join(process.cwd(), G5_MANIFEST), 'utf8'));
}

function migrate(g5Task, overrides = {}) {
  return migrateTask({
    g5Task,
    commandConverter: convertG5Command,
    interfaceRows: [],
    overrides,
  });
}

const P00 = loadG5Task('P00-T001');
const P01 = loadG5Task('P01-T001');

// ---------- Field preservation (ID, phase, dependencies, contractRefs, ownership, files, completion, commit path set) ----------

for (const g5Task of [P00, P01]) {
  test(`preserves planning fields for ${g5Task.id}`, () => {
    const record = migrate(g5Task);
    assert.equal(record.id, g5Task.id);
    assert.equal(record.phase, g5Task.phase);
    assert.equal(record.title, g5Task.title);
    assert.deepEqual(record.platformScope, [...g5Task.platformScope]);
    assert.deepEqual(record.dependencies, [...g5Task.dependencies].sort());
    assert.deepEqual(record.contractRefs, [...g5Task.contractRefs].sort());
    assert.deepEqual(record.ownership, [...g5Task.ownership]);
    assert.deepEqual(record.paths.productTarget, g5Task.files.productTarget);
    assert.deepEqual(record.paths.create, [...g5Task.files.create]);
    assert.deepEqual(record.paths.modify, [...g5Task.files.modify]);
    assert.deepEqual(record.paths.test, [...g5Task.files.test]);
    assert.deepEqual(record.completion, [...g5Task.completion]);
    // Product commit path set is the inherited commitBoundary, byte-for-byte.
    assert.deepEqual(record.commits.product.stagedProductPaths, [...g5Task.commitBoundary]);
  });
}

// ---------- Evidence path rewrite: ONLY the g5-r -> g6-r revision segment ----------

for (const g5Task of [P00, P01]) {
  test(`rewrites only the evidence revision segment for ${g5Task.id}`, () => {
    const record = migrate(g5Task);
    for (const original of g5Task.evidence) {
      assert.ok(original.startsWith('artifacts/acceptance-evidence/g5-r/'),
        `g5 evidence prefix: ${original}`);
    }
    assert.equal(record.evidence.paths.length, g5Task.evidence.length);
    record.evidence.paths.forEach((rewritten, i) => {
      const original = g5Task.evidence[i];
      assert.ok(rewritten.startsWith('artifacts/acceptance-evidence/g6-r/'),
        `g6 evidence prefix: ${rewritten}`);
      // The suffix after the revision segment is byte-for-byte identical.
      const g5Suffix = original.slice('artifacts/acceptance-evidence/g5-r/'.length);
      const g6Suffix = rewritten.slice('artifacts/acceptance-evidence/g6-r/'.length);
      assert.equal(g6Suffix, g5Suffix, `evidence suffix retained for ${original}`);
    });
    // Exactly one evidence path; the staged evidence path is the rewritten single path.
    assert.equal(record.evidence.paths.length, 1);
    assert.equal(record.commits.evidence.stagedEvidencePath, record.evidence.paths[0]);
  });
}

// ---------- G5 provides NO commitMessage; G6 derives exact subjects ----------

test('G5 controls carry no commitMessage field and G6 derives exact subjects', () => {
  assert.equal(Object.hasOwn(P00, 'commitMessage'), false);
  assert.equal(Object.hasOwn(P01, 'commitMessage'), false);
  const r00 = migrate(P00);
  const r01 = migrate(P01);
  assert.equal(r00.commits.product.message, 'monacode: complete P00-T001');
  assert.equal(r00.commits.evidence.message, 'evidence(monacode): complete P00-T001');
  assert.equal(r01.commits.product.message, 'monacode: complete P01-T001');
  assert.equal(r01.commits.evidence.message, 'evidence(monacode): complete P01-T001');
  // Both identities are the locked author.
  const identity = { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' };
  assert.deepEqual(r00.commits.product.author, identity);
  assert.deepEqual(r00.commits.product.committer, identity);
  assert.deepEqual(r00.commits.evidence.author, identity);
  assert.deepEqual(r00.commits.evidence.committer, identity);
  // Product stage prohibits evidence staging.
  assert.equal(r00.commits.product.evidenceExcluded, true);
  assert.ok(!r00.commits.product.stagedProductPaths.includes(r00.commits.evidence.stagedEvidencePath));
});

test('buildCommitMessage and buildEvidenceCommitMessage derive exact ASCII concatenation', () => {
  assert.equal(buildCommitMessage('P00-T001'), 'monacode: complete P00-T001');
  assert.equal(buildEvidenceCommitMessage('P00-T001'), 'evidence(monacode): complete P00-T001');
  assert.equal(buildCommitMessage('P01-T001'), 'monacode: complete P01-T001');
  assert.equal(buildEvidenceCommitMessage('P01-T001'), 'evidence(monacode): complete P01-T001');
  assert.throws(() => buildCommitMessage('P0-T001'), /TASK_ID/);
  assert.throws(() => buildCommitMessage('P00-T01'), /TASK_ID/);
  assert.throws(() => buildEvidenceCommitMessage('bad'), /TASK_ID/);
});

// ---------- Rejection: message / ID / parent / staged-set mismatch ----------

test('rejects a G5 task that carries a conflicting commitMessage field', () => {
  const bad = { ...P00, commitMessage: 'monacode: complete P00-T001' };
  assert.throws(() => migrate(bad), /COMMIT_MESSAGE_CONFLICT|commitMessage/);
});

test('rejects an override commit message that conflicts with the derived subject', () => {
  assert.throws(
    () => migrate(P00, { commitMessage: 'monacode: complete P00-T002' }),
    /COMMIT_MESSAGE_CONFLICT|stagedProductPaths|message/i,
  );
});

test('rejects an override staged product path set that conflicts with the inherited commit boundary', () => {
  assert.throws(
    () => migrate(P00, { stagedProductPaths: ['Package.swift'] }),
    /COMMIT_BOUNDARY|stagedProductPaths/i,
  );
});

test('rejects an evidence override that does not match the g5-r prefix', () => {
  assert.throws(
    () => migrate(P00, { evidencePaths: ['artifacts/acceptance-evidence/g4-r/phase-00/P00-T001.json'] }),
    /EVIDENCE_PREFIX|evidence/i,
  );
});

// ---------- Seven ordered stages, one Red command, one Green command ----------

for (const g5Task of [P00, P01]) {
  test(`produces exactly seven ordered stages with one Red and one Green command for ${g5Task.id}`, () => {
    const record = migrate(g5Task);
    assert.deepEqual(record.stages.map((stage) => stage.name),
      ['preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence']);

    const preflight = record.stages[0];
    assert.equal(preflight.steps.length, 1);
    assert.equal(preflight.steps[0].kind, 'controller-action');
    assert.equal(preflight.steps[0].action, 'begin-task');

    const red = record.stages[2];
    assert.equal(red.steps.length, 1, 'exactly one converted Red command');
    assert.equal(red.steps[0].kind, 'verification-command');
    const redCommand = red.steps[0].command;
    assert.equal(redCommand.commandID, `${g5Task.id}.RED.001`);
    assert.equal(redCommand.networkMode, 'forbidden');
    assert.ok(redCommand.leaves.length >= 1);
    for (const leaf of redCommand.leaves) {
      assert.ok(leaf.leafID.startsWith(`${g5Task.id}.RED.001.PROC.`), `red leaf id: ${leaf.leafID}`);
    }

    const implementation = record.stages[3];
    assert.equal(implementation.steps.length, g5Task.implementation.operations.length);
    for (const step of implementation.steps) {
      assert.equal(step.kind, 'implementation-operation');
      assert.ok(g5Task.implementation.operations.includes(step.operation));
    }

    const green = record.stages[4];
    assert.equal(green.steps.length, 1, 'exactly one converted Green command');
    assert.equal(green.steps[0].kind, 'verification-command');
    const greenCommand = green.steps[0].command;
    assert.equal(greenCommand.commandID, `${g5Task.id}.GREEN.001`);
    for (const leaf of greenCommand.leaves) {
      assert.ok(leaf.leafID.startsWith(`${g5Task.id}.GREEN.001.PROC.`), `green leaf id: ${leaf.leafID}`);
    }

    const commit = record.stages[5];
    assert.equal(commit.steps.length, 1);
    assert.equal(commit.steps[0].kind, 'controller-action');
    assert.equal(commit.steps[0].action, 'commit-task');

    const evidence = record.stages[6];
    assert.equal(evidence.steps.length, 1);
    assert.equal(evidence.steps[0].kind, 'controller-action');
    assert.equal(evidence.steps[0].action, 'finalize-evidence');
  });
}

// ---------- One task-test contract selecting every Red/Green leaf exactly once ----------

for (const g5Task of [P00, P01]) {
  test(`selects every Red/Green leaf exactly once in one task-test contract for ${g5Task.id}`, () => {
    const record = migrate(g5Task);
    const contract = record.testContract;
    assert.equal(contract.contractID, g5Task.id);

    const redLeaves = record.stages[2].steps[0].command.leaves.map((leaf) => leaf.leafID);
    const greenLeaves = record.stages[4].steps[0].command.leaves.map((leaf) => leaf.leafID);
    const allLeaves = [...redLeaves, ...greenLeaves];

    const selected = [];
    for (const testCase of contract.cases) {
      selected.push(testCase.redLeafID, testCase.greenLeafID);
    }
    // Every declared leaf is selected exactly once.
    assert.equal(selected.length, allLeaves.length);
    const selectedSorted = [...selected].sort();
    const allSorted = [...allLeaves].sort();
    assert.deepEqual(selectedSorted, allSorted);
    // No duplicate selection.
    assert.equal(new Set(selected).size, selected.length);
  });
}

// ---------- Canonical record-hash stability across two runs ----------

for (const g5Task of [P00, P01]) {
  test(`canonical record hash is stable across two runs for ${g5Task.id}`, () => {
    const first = migrate(g5Task);
    const second = migrate(g5Task);
    assert.ok(/^[0-9a-f]{64}$/.test(first.recordSha256), `hash shape: ${first.recordSha256}`);
    assert.equal(first.recordSha256, second.recordSha256);
    // The hash is NOT embedded in the hashed body.
    const body = { ...first };
    delete body.recordSha256;
    assert.ok(!JSON.stringify(body).includes(first.recordSha256));
  });
}

// ---------- Deterministic rendering: same task twice -> byte-identical Markdown ----------

for (const g5Task of [P00, P01]) {
  test(`rendering the same task twice produces byte-identical Markdown for ${g5Task.id}`, () => {
    const record = migrate(g5Task);
    const first = renderTask(record);
    const second = renderTask(record);
    assert.equal(first, second);
    // The rendered Markdown carries the canonical task marker with the record hash.
    assert.ok(first.includes(`<!-- G6-R-TASK:${g5Task.id}:`), 'task marker prefix');
    assert.ok(first.includes(first.match(/G6-R-TASK:P[0-9]{2}-T[0-9]{3}:[0-9a-f]{64}/)[0]), 'marker includes hash');
    assert.ok(first.includes(g5Task.id));
  });
}

// ---------- Cross-control: the two controls produce distinct hashes ----------

test('the two controls produce distinct canonical record hashes', () => {
  assert.notEqual(migrate(P00).recordSha256, migrate(P01).recordSha256);
});

// ===========================================================================
// Fix #4 — override threading: authored testContract/implementationOperations/
// sourceAcquisitions/redScaffold reach the migrated task record.
// ===========================================================================

test('an authored testContract replaces the G5-derived scaffold in the migrated record', () => {
  const authored = {
    contractID: P00.id,
    cases: [{
      caseID: 'P00-T001.CASE.001',
      file: { path: 'Package.swift', availability: 'local' },
      checker: 'Tools/PlanChecks/assert-package-graph.mjs',
      target: 'Package.swift',
      testSymbol: 'testPackageGraph',
      fixtures: { kind: 'inline', values: { products: 3 } },
      assertions: [{ id: 'PACKAGE_GRAPH_MISSING', operand: 'equals' }],
      redLeafID: 'P00-T001.RED.001.PROC.001',
      greenLeafID: 'P00-T001.GREEN.001.PROC.001',
      inheritedOutput: true,
      failureClass: 'assertion',
      authoringOperation: 'author-package-graph-contract',
      source: 'baseline',
    }],
  };
  const record = migrate(P00, { testContract: authored });
  assert.equal(record.testContract, authored);
  assert.equal(record.testContract.cases[0].caseID, 'P00-T001.CASE.001');
  // The G5-derived scaffold would have paired 2 leaves into 2 cases; the authored
  // contract is used verbatim (1 case here).
  assert.equal(record.testContract.cases.length, 1);
});

test('authored implementationOperations and sourceAcquisitions thread into the implementation stage', () => {
  const acq = { url: 'https://registry.npmjs.org/monaco-editor/-/monaco-editor-0.56.0.tgz', allowedHost: 'registry.npmjs.org', disposition: 'temporary' };
  const record = migrate(P00, {
    implementationOperations: ['Declare MonaCode product.', 'Pin macOS 26.0.'],
    sourceAcquisitions: [acq],
  });
  const impl = record.stages[3];
  // One source-acquisition step precedes the two authored implementation-operation steps.
  assert.equal(impl.steps.length, 3);
  assert.equal(impl.steps[0].kind, 'source-acquisition');
  assert.deepEqual(impl.steps[0].acquisition, acq);
  assert.equal(impl.steps[1].kind, 'implementation-operation');
  assert.equal(impl.steps[1].operation, 'Declare MonaCode product.');
  assert.equal(impl.steps[2].operation, 'Pin macOS 26.0.');
  assert.deepEqual(record.sourceAcquisitions, [acq]);
});

test('authored redScaffold replaces the G5-derived scaffold for a Swift-Red task', () => {
  const authoredScaffold = [{
    sourcePath: 'Sources/MonaCode/Base/MonaPosition.swift',
    marker: scaffoldMarker('P01-T001', 'Sources/MonaCode/Base/MonaPosition.swift'),
    declarationText: 'struct MonaPosition {}',
    sentinelBehavior: 'compile-fail',
  }];
  const record = migrate(P01, { redScaffold: authoredScaffold });
  assert.equal(record.redScaffold.length, 1);
  assert.deepEqual(record.redScaffold, authoredScaffold);
  assert.equal(record.redScaffold[0].marker, authoredScaffold[0].marker);
});

test('G5-derived redScaffold is minimal and carries the canonical marker for each created Swift path', () => {
  const record = migrate(P01); // no overrides
  assert.ok(record.redScaffold.length >= 1);
  for (const s of record.redScaffold) {
    assert.equal(s.marker, scaffoldMarker('P01-T001', s.sourcePath));
    assert.equal(s.sentinelBehavior, 'compile-fail');
  }
});

// ===========================================================================
// Fix #1 — PLAN_OVERRIDE_ROW_CONFLICT detection (3 conflict classes).
// ===========================================================================

function validate(overrides, taskIDs, checksumIndex = new Map()) {
  const plan = loadG5Plan();
  return validatePhaseOverrides({
    phase: '00', taskIDs, parentPlan: plan, productArtifacts: {}, overrides, checksumIndex,
  });
}

function findingIDs(result) {
  return new Set(result.findings.map((f) => f.id));
}

test('Fix #1a: duplicate interface IDs with divergent declarations emit PLAN_OVERRIDE_ROW_CONFLICT', () => {
  const overrides = {
    tasks: {
      'P00-T001': {
        testAuthoringOperation: 'author',
        interfaces: {
          produces: [
            { id: 'SwiftPMGraph', kind: 'swift-declaration', declarationText: 'a', sourceArtifactPath: 'x', sourceArtifactHash: 'y', sourceLocator: 'p', contractRefs: [] },
            { id: 'SwiftPMGraph', kind: 'json-schema', schemaPath: 'b', sourceArtifactPath: 'x', sourceArtifactHash: 'y', sourceLocator: 'p', contractRefs: [] },
          ],
        },
      },
    },
  };
  const result = validate(overrides, ['P00-T001']);
  assert.ok(findingIDs(result).has('PLAN_OVERRIDE_ROW_CONFLICT'));
});

test('Fix #1b: duplicate Red-scaffold sourcePath emits PLAN_OVERRIDE_ROW_CONFLICT', () => {
  const sourcePath = 'Sources/MonaCode/Base/MonaPosition.swift';
  const overrides = {
    tasks: {
      'P01-T001': {
        testAuthoringOperation: 'author',
        redScaffold: [
          { sourcePath, marker: scaffoldMarker('P01-T001', sourcePath) },
          { sourcePath, marker: scaffoldMarker('P01-T001', sourcePath) },
        ],
      },
    },
  };
  const plan = loadG5Plan();
  const result = validatePhaseOverrides({
    phase: '01', taskIDs: ['P01-T001'], parentPlan: plan, productArtifacts: {}, overrides, checksumIndex: new Map(),
  });
  assert.ok(findingIDs(result).has('PLAN_OVERRIDE_ROW_CONFLICT'));
});

test('Fix #1c: a Red/Green leaf claimed by more than one testContract case emits PLAN_OVERRIDE_ROW_CONFLICT', () => {
  const overrides = {
    tasks: {
      'P00-T001': {
        testAuthoringOperation: 'author',
        testContract: {
          contractID: 'P00-T001',
          cases: [
            { caseID: 'C1', file: { path: 'Package.swift', availability: 'local' }, checker: 'c', target: 't', testSymbol: 's', fixtures: { kind: 'inline', values: {} }, assertions: [{ id: 'a', operand: 'equals' }], redLeafID: 'P00-T001.RED.001.PROC.001', greenLeafID: 'P00-T001.GREEN.001.PROC.001', inheritedOutput: true, failureClass: 'assertion', authoringOperation: 'op', source: 'baseline' },
            { caseID: 'C2', file: { path: 'Package.swift', availability: 'local' }, checker: 'c', target: 't', testSymbol: 's', fixtures: { kind: 'inline', values: {} }, assertions: [{ id: 'a', operand: 'equals' }], redLeafID: 'P00-T001.RED.001.PROC.001', greenLeafID: 'P00-T001.GREEN.001.PROC.002', inheritedOutput: true, failureClass: 'assertion', authoringOperation: 'op', source: 'baseline' },
          ],
        },
      },
    },
  };
  const result = validate(overrides, ['P00-T001']);
  assert.ok(findingIDs(result).has('PLAN_OVERRIDE_ROW_CONFLICT'));
});

// ===========================================================================
// Fix #2 — field-level validation (test-contract case fields + interface fields).
// ===========================================================================

test('Fix #2a: a test-contract case missing a fixed field emits PLAN_TEST_CONTRACT_MISSING', () => {
  const overrides = {
    tasks: {
      'P00-T001': {
        testAuthoringOperation: 'author',
        testContract: {
          contractID: 'P00-T001',
          cases: [{
            caseID: 'C1', file: { path: 'Package.swift', availability: 'local' },
            // checker missing
            target: 't', testSymbol: 's', fixtures: { kind: 'inline', values: {} },
            assertions: [{ id: 'a', operand: 'equals' }],
            redLeafID: 'P00-T001.RED.001.PROC.001', greenLeafID: 'P00-T001.GREEN.001.PROC.001',
            inheritedOutput: true, failureClass: 'assertion', authoringOperation: 'op', source: 'baseline',
          }],
        },
      },
    },
  };
  const result = validate(overrides, ['P00-T001']);
  assert.ok(findingIDs(result).has('PLAN_TEST_CONTRACT_MISSING'));
});

test('Fix #2b: an interface row missing a kind-specific field emits PLAN_INTERFACE_CONTRACT_INCOMPLETE', () => {
  const overrides = {
    tasks: {
      'P00-T001': {
        testAuthoringOperation: 'author',
        interfaces: {
          produces: [
            { id: 'SwiftPMGraph', kind: 'swift-declaration' /* missing declarationText etc */, sourceArtifactPath: 'x', sourceArtifactHash: 'y', sourceLocator: 'p', contractRefs: [] },
          ],
        },
      },
    },
  };
  const result = validate(overrides, ['P00-T001']);
  assert.ok(findingIDs(result).has('PLAN_INTERFACE_CONTRACT_INCOMPLETE'));
});

// ===========================================================================
// Fix #3 — productArtifacts/checksum-index cross-check.
// ===========================================================================

test('Fix #3: an interface source artifact path not in the checksum index emits PLAN_INTERFACE_CONTRACT_INCOMPLETE', () => {
  const overrides = {
    tasks: {
      'P00-T001': {
        testAuthoringOperation: 'author',
        interfaces: {
          produces: [
            { id: 'SwiftPMGraph', kind: 'swift-declaration', declarationText: 'a', target: 't', visibility: 'public', availability: 'local', actorIsolation: 'none', ownership: 'MonaCode', sendable: false, sourceArtifactPath: 'artifacts/does-not-exist.html', sourceArtifactHash: 'deadbeef', sourceLocator: 'p', contractRefs: [] },
          ],
        },
      },
    },
  };
  const result = validate(overrides, ['P00-T001'], new Map());
  const ids = findingIDs(result);
  assert.ok(ids.has('PLAN_INTERFACE_CONTRACT_INCOMPLETE'));
});

test('Fix #3: an interface source artifact hash mismatch against the checksum index emits PLAN_INTERFACE_CONTRACT_INCOMPLETE', () => {
  const cksum = new Map([['artifacts/real.html', 'abc123']]);
  const overrides = {
    tasks: {
      'P00-T001': {
        testAuthoringOperation: 'author',
        interfaces: {
          produces: [
            { id: 'SwiftPMGraph', kind: 'swift-declaration', declarationText: 'a', target: 't', visibility: 'public', availability: 'local', actorIsolation: 'none', ownership: 'MonaCode', sendable: false, sourceArtifactPath: 'artifacts/real.html', sourceArtifactHash: 'wrong', sourceLocator: 'p', contractRefs: [] },
          ],
        },
      },
    },
  };
  const result = validate(overrides, ['P00-T001'], cksum);
  const ids = findingIDs(result);
  assert.ok(ids.has('PLAN_INTERFACE_CONTRACT_INCOMPLETE'));
});

// ===========================================================================
// Flag tests — the 4 missing flags added to verify-fragment / build-fragment.
// ===========================================================================

const STAGE_NAMES = ['preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence'];

function makeStages() {
  return STAGE_NAMES.map((name) => ({ name, steps: [] }));
}

function makeTask(id, opts = {}) {
  return {
    id,
    phase: opts.phase ?? '05',
    dependencies: opts.dependencies ?? [],
    ownership: opts.ownership ?? [],
    interfaces: opts.interfaces ?? { produces: [], consumes: [] },
    commits: { product: { stagedProductPaths: opts.stagedPaths ?? [] } },
    stages: makeStages(),
  };
}

function makeFragment(tasks) {
  return { phase: '05', tasks, commands: [], interfaces: [], evidence: [], counts: { tasks: tasks.length, commands: 0, producedInterfaces: 0, evidence: 0 } };
}

function runVerify(args, fragment) {
  const tmp = path.join(os.tmpdir(), `g6-verify-${process.pid}-${Date.now()}.json`);
  fs.writeFileSync(tmp, JSON.stringify(fragment) + '\n');
  try {
    return spawnSync(process.execPath,
      [path.resolve('Tools/G6PlanAuthoring/verify-fragment.mjs'), '--phase', '05', '--path', tmp, ...args],
      { encoding: 'utf8' });
  } finally {
    fs.unlinkSync(tmp);
  }
}

// ---------- Flag #1 — --renderer core-graphics | core-graphics-plus-metal ----------

test('Flag #1: core-graphics excludes Metal-named paths, core-graphics-plus-metal includes them → different hashes', () => {
  const fragment = makeFragment([
    makeTask('P05-T100', { stagedPaths: ['Sources/Rendering/MetalRenderer.swift', 'Sources/Rendering/CGRenderer.swift'] }),
  ]);
  const cg = computeRendererPathHash(fragment, 'core-graphics');
  const metal = computeRendererPathHash(fragment, 'core-graphics-plus-metal');
  assert.equal(cg.selectedCount, 1);
  assert.equal(cg.selected[0], 'Sources/Rendering/CGRenderer.swift');
  assert.equal(metal.selectedCount, 2);
  assert.notEqual(cg.hash, metal.hash);
});

test('Flag #1: no Metal paths → identical hashes for both modes', () => {
  const fragment = makeFragment([
    makeTask('P05-T100', { stagedPaths: ['Sources/Rendering/CGRenderer.swift', 'Sources/Text/MonaText.swift'] }),
  ]);
  const cg = computeRendererPathHash(fragment, 'core-graphics');
  const metal = computeRendererPathHash(fragment, 'core-graphics-plus-metal');
  assert.equal(cg.selectedCount, 2);
  assert.equal(metal.selectedCount, 2);
  assert.equal(cg.hash, metal.hash);
});

test('Flag #1: CLI --renderer core-graphics is accepted and emits the path hash', () => {
  const fragment = makeFragment([
    makeTask('P05-T100', { stagedPaths: ['Sources/Rendering/MetalRenderer.swift', 'Sources/Rendering/CGRenderer.swift'] }),
  ]);
  const r = runVerify(['--renderer', 'core-graphics'], fragment);
  assert.equal(r.status, 0);
  assert.ok(r.stdout.includes('renderer=core-graphics'));
  assert.ok(r.stdout.includes('finalPathHash='));
});

test('Flag #1: CLI --renderer core-graphics-plus-metal is accepted and includes all paths', () => {
  const fragment = makeFragment([
    makeTask('P05-T100', { stagedPaths: ['Sources/Rendering/MetalRenderer.swift', 'Sources/Rendering/CGRenderer.swift'] }),
  ]);
  const r = runVerify(['--renderer', 'core-graphics-plus-metal'], fragment);
  assert.equal(r.status, 0);
  assert.ok(r.stdout.includes('renderer=core-graphics-plus-metal'));
  assert.ok(r.stdout.includes('selectedPaths=2'));
});

// ---------- Flag #2 — --feature-manifest <path> ----------

test('Flag #2: matching feature IDs → missingFeatures=0 extraFeatures=0', () => {
  const manifest = { tasks: [{ id: 'P05-T100' }, { id: 'P05-T101' }, { id: 'P05-T102' }] };
  const fragment = makeFragment([
    makeTask('P05-T100'), makeTask('P05-T101'), makeTask('P05-T102'),
  ]);
  const r = checkFeatureManifest(fragment, manifest);
  assert.equal(r.missingFeatures, 0);
  assert.equal(r.extraFeatures, 0);
});

test('Flag #2: a missing and an extra feature → missingFeatures=1 extraFeatures=1', () => {
  const manifest = { tasks: [{ id: 'P05-T100' }, { id: 'P05-T101' }, { id: 'P05-T102' }] };
  const fragment = makeFragment([
    makeTask('P05-T100'), makeTask('P05-T101'), makeTask('P05-T150'),
  ]);
  const r = checkFeatureManifest(fragment, manifest);
  assert.equal(r.missingFeatures, 1);
  assert.equal(r.extraFeatures, 1);
});

test('Flag #2: closure task IDs (T190/T200) are excluded from feature identities', () => {
  const manifest = { tasks: [{ id: 'P05-T100' }, { id: 'P05-T190' }, { id: 'P05-T200' }] };
  const fragment = makeFragment([makeTask('P05-T100'), makeTask('P05-T190')]);
  const r = checkFeatureManifest(fragment, manifest);
  // T190/T200 are not features; both sides have them, so they don't count.
  assert.equal(r.missingFeatures, 0);
  assert.equal(r.extraFeatures, 0);
});

test('Flag #2: CLI --feature-manifest exits 0 when features match', () => {
  const manifest = { tasks: [{ id: 'P05-T100' }] };
  const manifestTmp = path.join(os.tmpdir(), `g6-manifest-${process.pid}-${Date.now()}.json`);
  fs.writeFileSync(manifestTmp, JSON.stringify(manifest) + '\n');
  try {
    const fragment = makeFragment([makeTask('P05-T100')]);
    const r = runVerify(['--feature-manifest', manifestTmp], fragment);
    assert.equal(r.status, 0);
    assert.ok(r.stdout.includes('missingFeatures=0 extraFeatures=0'));
  } finally {
    fs.unlinkSync(manifestTmp);
  }
});

test('Flag #2: CLI --feature-manifest exits 1 when features mismatch', () => {
  const manifest = { tasks: [{ id: 'P05-T100' }] };
  const manifestTmp = path.join(os.tmpdir(), `g6-manifest-${process.pid}-${Date.now()}.json`);
  fs.writeFileSync(manifestTmp, JSON.stringify(manifest) + '\n');
  try {
    const fragment = makeFragment([makeTask('P05-T150')]);
    const r = runVerify(['--feature-manifest', manifestTmp], fragment);
    assert.equal(r.status, 1);
    assert.ok(r.stdout.includes('missingFeatures=1'));
    assert.ok(r.stdout.includes('extraFeatures=1'));
  } finally {
    fs.unlinkSync(manifestTmp);
  }
});

// ---------- Flag #3 — build-fragment --merge-phase ----------

test('Flag #3: mergeFragments unions disjoint task sets, sorted by dependency topology', () => {
  const fragA = makeFragment([
    makeTask('P05-T100', { dependencies: [] }),
    makeTask('P05-T102', { dependencies: ['P05-T100'] }),
  ]);
  const fragB = makeFragment([
    makeTask('P05-T101', { dependencies: ['P05-T100'] }),
  ]);
  const merged = mergeFragments([fragA, fragB], '05');
  assert.equal(merged.counts.tasks, 3);
  const ids = merged.tasks.map((t) => t.id);
  // P05-T100 (no deps) before P05-T101 and P05-T102 (which depend on it).
  assert.ok(ids.indexOf('P05-T100') < ids.indexOf('P05-T101'));
  assert.ok(ids.indexOf('P05-T100') < ids.indexOf('P05-T102'));
  // No duplicates.
  assert.equal(new Set(ids).size, ids.length);
});

test('Flag #3: mergeFragments rejects duplicate task IDs', () => {
  const fragA = makeFragment([makeTask('P05-T100')]);
  const fragB = makeFragment([makeTask('P05-T100')]);
  assert.throws(() => mergeFragments([fragA, fragB], '05'), /G6_MERGE_DUPLICATE_TASK/);
});

test('Flag #3: CLI --merge-phase writes the merged fragment to --output', () => {
  const fragA = makeFragment([makeTask('P05-T100')]);
  const fragB = makeFragment([makeTask('P05-T101', { dependencies: ['P05-T100'] })]);
  const inA = path.join(os.tmpdir(), `g6-merge-a-${process.pid}-${Date.now()}.json`);
  const inB = path.join(os.tmpdir(), `g6-merge-b-${process.pid}-${Date.now()}.json`);
  const out = path.join(os.tmpdir(), `g6-merge-out-${process.pid}-${Date.now()}.json`);
  fs.writeFileSync(inA, JSON.stringify(fragA) + '\n');
  fs.writeFileSync(inB, JSON.stringify(fragB) + '\n');
  try {
    const r = spawnSync(process.execPath,
      [path.resolve('Tools/G6PlanAuthoring/build-fragment.mjs'),
        '--merge-phase', '05', '--input', inA, '--input', inB, '--output', out],
      { encoding: 'utf8' });
    assert.equal(r.status, 0);
    assert.ok(r.stdout.includes('G6_FRAGMENT_WRITTEN phase=05 tasks=2'));
    const merged = JSON.parse(fs.readFileSync(out, 'utf8'));
    assert.equal(merged.tasks.length, 2);
    assert.deepEqual(merged.tasks.map((t) => t.id), ['P05-T100', 'P05-T101']);
  } finally {
    for (const f of [inA, inB, out]) { try { fs.unlinkSync(f); } catch { /* ok */ } }
  }
});

// ---------- Flag #4 — --phase 05 + --dependency <predecessor-fragment> ----------

test('Flag #4: --phase 05 is accepted at the CLI (not rejected as unknown phase)', () => {
  const fragment = makeFragment([makeTask('P05-T100')]);
  const r = runVerify([], fragment);
  assert.equal(r.status, 0);
  assert.ok(r.stdout.includes('tasks=1'));
});

test('Flag #4: consumed interface not produced by predecessor → candidateBeforeProducer=1', () => {
  const predecessor = makeFragment([
    makeTask('P04-T001', { interfaces: { produces: [{ id: 'MonaRegistry' }], consumes: [] } }),
  ]);
  const fragment = makeFragment([
    makeTask('P05-T100', { interfaces: { produces: [], consumes: [{ id: 'MonaRegistry' }, { id: 'MonaUnknownInterface' }] } }),
  ]);
  const r = checkDependency(fragment, predecessor);
  assert.equal(r.candidateBeforeProducer, 1);
});

test('Flag #4: all consumed interfaces produced by predecessor → candidateBeforeProducer=0', () => {
  const predecessor = makeFragment([
    makeTask('P04-T001', { interfaces: { produces: [{ id: 'MonaRegistry' }, { id: 'MonaCommandRegistry' }], consumes: [] } }),
  ]);
  const fragment = makeFragment([
    makeTask('P05-T100', { interfaces: { produces: [], consumes: [{ id: 'MonaRegistry' }, { id: 'MonaCommandRegistry' }] } }),
  ]);
  const r = checkDependency(fragment, predecessor);
  assert.equal(r.candidateBeforeProducer, 0);
});

test('Flag #4: CLI --dependency exits 0 when all consumed interfaces are produced', () => {
  const predecessor = makeFragment([
    makeTask('P04-T001', { interfaces: { produces: [{ id: 'MonaRegistry' }], consumes: [] } }),
  ]);
  const depTmp = path.join(os.tmpdir(), `g6-dep-${process.pid}-${Date.now()}.json`);
  fs.writeFileSync(depTmp, JSON.stringify(predecessor) + '\n');
  try {
    const fragment = makeFragment([
      makeTask('P05-T100', { interfaces: { produces: [], consumes: [{ id: 'MonaRegistry' }] } }),
    ]);
    const r = runVerify(['--dependency', depTmp], fragment);
    assert.equal(r.status, 0);
    assert.ok(r.stdout.includes('candidateBeforeProducer=0'));
  } finally {
    fs.unlinkSync(depTmp);
  }
});

test('Flag #4: CLI --dependency exits 1 on a forward reference', () => {
  const predecessor = makeFragment([
    makeTask('P04-T001', { interfaces: { produces: [{ id: 'MonaRegistry' }], consumes: [] } }),
  ]);
  const depTmp = path.join(os.tmpdir(), `g6-dep-${process.pid}-${Date.now()}.json`);
  fs.writeFileSync(depTmp, JSON.stringify(predecessor) + '\n');
  try {
    const fragment = makeFragment([
      makeTask('P05-T100', { interfaces: { produces: [], consumes: [{ id: 'MonaRegistry' }, { id: 'MonaFutureInterface' }] } }),
    ]);
    const r = runVerify(['--dependency', depTmp], fragment);
    assert.equal(r.status, 1);
    assert.ok(r.stdout.includes('candidateBeforeProducer=1'));
  } finally {
    fs.unlinkSync(depTmp);
  }
});
