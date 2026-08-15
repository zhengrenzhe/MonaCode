// G6-R command-input availability and producer-order tests (TDD Step 1).
// Proves every repository-local command input resolves to exactly one valid
// stage-time source (baseline / dependency / task-step / temporary) and that
// remote implementation sources select one complete SourceAcquisition before
// their consuming operation. Each fixture declares ONE expected finding;
// inline controls assert deep equality, not set containment. Node built-in
// test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import * as path from 'node:path';

import {
  buildPathProducerIndex,
  auditCommandDependencies,
  auditImplementationSourceInputs,
} from '../lib/command-paths.mjs';

const FIXTURES_DIR = path.join(import.meta.dirname, 'fixtures');

function loadFixture(name) {
  return JSON.parse(readFileSync(path.join(FIXTURES_DIR, name), 'utf8'));
}

// ---------------------------------------------------------------------------
// Fixture-driven command-input findings (one exact finding each)
// ---------------------------------------------------------------------------

test('command-input-missing yields exactly PLAN_COMMAND_INPUT_UNAVAILABLE', () => {
  const fx = loadFixture('command-input-missing.json');
  const got = auditCommandDependencies(fx.plan, fx.baselineRows);
  assert.deepEqual(got, [fx.expected]);
});

test('command-input-future yields exactly PLAN_COMMAND_INPUT_FROM_FUTURE', () => {
  const fx = loadFixture('command-input-future.json');
  const got = auditCommandDependencies(fx.plan, fx.baselineRows);
  assert.deepEqual(got, [fx.expected]);
});

test('command-input-duplicate yields exactly PLAN_COMMAND_INPUT_AMBIGUOUS', () => {
  const fx = loadFixture('command-input-duplicate.json');
  const got = auditCommandDependencies(fx.plan, fx.baselineRows);
  assert.deepEqual(got, [fx.expected]);
});

test('command-input-hash-drift yields exactly PLAN_COMMAND_INPUT_HASH_MISMATCH', () => {
  const fx = loadFixture('command-input-hash-drift.json');
  const got = auditCommandDependencies(fx.plan, fx.baselineRows);
  assert.deepEqual(got, [fx.expected]);
});

// ---------------------------------------------------------------------------
// Command positive controls — each availability class resolves cleanly
// ---------------------------------------------------------------------------

test('baseline command input with matching sha256 produces no finding', () => {
  const sha = 'a'.repeat(64);
  const plan = {
    planID: 'g6r-baseline-ok',
    tasks: [{
      taskID: 'P00-T001',
      stages: [{
        name: 'red',
        steps: [{
          kind: 'verification-command',
          command: {
            commandID: 'P00-T001.RED.001', kind: 'process',
            leaves: [{ leafID: 'P00-T001.RED.001.PROC.001' }],
            inputs: [{ path: 'base/file.swift', availability: 'baseline', sha256: sha }],
          },
        }],
      }],
    }],
  };
  assert.deepEqual(auditCommandDependencies(plan, [{ path: 'base/file.swift', sha256: sha }]), []);
});

test('dependency command input from an earlier task produces no finding', () => {
  const plan = {
    planID: 'g6r-dependency-ok',
    tasks: [
      { taskID: 'P00-T001', productCommit: { stagedProductPaths: ['lib/dep.swift'] },
        stages: [{ name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] }] },
      { taskID: 'P00-T002',
        stages: [{
          name: 'red',
          steps: [{
            kind: 'verification-command',
            command: {
              commandID: 'P00-T002.RED.001', kind: 'process',
              leaves: [{ leafID: 'P00-T002.RED.001.PROC.001' }],
              inputs: [{ path: 'lib/dep.swift', availability: 'dependency' }],
            },
          }],
        }] },
    ],
  };
  assert.deepEqual(auditCommandDependencies(plan, []), []);
});

test('task-step command input produced by test-authoring produces no finding', () => {
  const plan = {
    planID: 'g6r-taskstep-ok',
    tasks: [{
      taskID: 'P00-T001',
      testContract: { cases: [{ file: { path: 'Tests/Foo.test.swift' } }] },
      stages: [{
        name: 'red',
        steps: [{
          kind: 'verification-command',
          command: {
            commandID: 'P00-T001.RED.001', kind: 'process',
            leaves: [{ leafID: 'P00-T001.RED.001.PROC.001' }],
            inputs: [{ path: 'Tests/Foo.test.swift', availability: 'task-step' }],
          },
        }],
      }],
    }],
  };
  assert.deepEqual(auditCommandDependencies(plan, []), []);
});

test('temporary command input under the command temp root produces no finding', () => {
  const plan = {
    planID: 'g6r-temporary-ok',
    tasks: [{
      taskID: 'P00-T001',
      stages: [{
        name: 'green',
        steps: [{
          kind: 'verification-command',
          command: {
            commandID: 'P00-T001.GREEN.001', kind: 'pipeline', pipefail: true,
            leaves: [
              { leafID: 'P00-T001.GREEN.001.PROC.001' },
              { leafID: 'P00-T001.GREEN.001.PROC.002' },
            ],
            mutations: { temporary: ['/tmp/monacode-plan/P00-T001.GREEN.001/**'] },
            inputs: [
              { path: '/tmp/monacode-plan/P00-T001.GREEN.001/intermediate.bin', availability: 'temporary' },
            ],
          },
        }],
      }],
    }],
  };
  assert.deepEqual(auditCommandDependencies(plan, []), []);
});

test('pipeline command input finding names the parent and every leaf', () => {
  // An all-success/pipeline input cannot hide behind aggregate validation: the
  // finding subject carries the parent commandID and every leafID.
  const plan = {
    planID: 'g6r-pipeline-subject',
    tasks: [{
      taskID: 'P00-T001',
      stages: [{
        name: 'green',
        steps: [{
          kind: 'verification-command',
          command: {
            commandID: 'P00-T001.GREEN.001', kind: 'pipeline', pipefail: true,
            leaves: [
              { leafID: 'P00-T001.GREEN.001.PROC.001' },
              { leafID: 'P00-T001.GREEN.001.PROC.002' },
            ],
            inputs: [{ path: 'no/where.swift', availability: 'baseline' }],
          },
        }],
      }],
    }],
  };
  const got = auditCommandDependencies(plan, []);
  assert.deepEqual(got, [{
    id: 'PLAN_COMMAND_INPUT_UNAVAILABLE',
    category: 'semantic',
    taskID: 'P00-T001',
    path: '/tasks/0/stages/0/steps/0/command/inputs/0',
    message: 'input path "no/where.swift" has no stage-time source; command=P00-T001.GREEN.001 leaves=[P00-T001.GREEN.001.PROC.001,P00-T001.GREEN.001.PROC.002]',
  }]);
});

// ---------------------------------------------------------------------------
// Implementation source-input findings (inline, one exact finding each)
// ---------------------------------------------------------------------------

test('undeclared local implementation source yields PLAN_SOURCE_INPUT_UNDECLARED', () => {
  const plan = {
    planID: 'g6r-source-undeclared',
    tasks: [{
      taskID: 'P00-T001',
      stages: [{
        name: 'implementation',
        steps: [{
          kind: 'implementation-operation',
          operation: 'implement-feature',
          source: { kind: 'local', path: 'no/where.swift' },
        }],
      }],
    }],
  };
  const got = auditImplementationSourceInputs(plan, []);
  assert.deepEqual(got, [{
    id: 'PLAN_SOURCE_INPUT_UNDECLARED',
    category: 'semantic',
    taskID: 'P00-T001',
    path: '/tasks/0/stages/0/steps/0/source',
    message: 'implementation source "no/where.swift" has no declared producer; task=P00-T001 operation=implement-feature',
  }]);
});

test('acquisition output colliding with baseline yields PLAN_SOURCE_OUTPUT_COLLISION', () => {
  const plan = {
    planID: 'g6r-source-collision',
    tasks: [{
      taskID: 'P00-T001',
      stages: [{
        name: 'implementation',
        steps: [
          { kind: 'source-acquisition', acquisition: {
              url: 'https://example.com/data', outputPath: 'baseline/file.swift',
              disposition: 'task-step', taskOwner: 'P00-T001', stageOwner: 'implementation' } },
          { kind: 'implementation-operation', operation: 'consume-remote',
            source: { kind: 'remote', url: 'https://example.com/data' } },
        ],
      }],
    }],
  };
  const got = auditImplementationSourceInputs(plan, [{ path: 'baseline/file.swift', sha256: 'b'.repeat(64) }]);
  assert.deepEqual(got, [{
    id: 'PLAN_SOURCE_OUTPUT_COLLISION',
    category: 'semantic',
    taskID: 'P00-T001',
    path: '/tasks/0/stages/0/steps/0/acquisition/outputPath',
    message: 'acquisition output "baseline/file.swift" collides with baseline; task=P00-T001 url=https://example.com/data',
  }]);
});

test('acquisition ordered after its consumer yields PLAN_SOURCE_PRODUCER_ORDER', () => {
  const plan = {
    planID: 'g6r-source-order',
    tasks: [{
      taskID: 'P00-T001',
      stages: [{
        name: 'implementation',
        steps: [
          { kind: 'implementation-operation', operation: 'consume-early',
            source: { kind: 'remote', url: 'https://example.com/data' } },
          { kind: 'source-acquisition', acquisition: {
              url: 'https://example.com/data', outputPath: 'sources/data.bin',
              disposition: 'task-step', taskOwner: 'P00-T001', stageOwner: 'implementation' } },
        ],
      }],
    }],
  };
  const got = auditImplementationSourceInputs(plan, []);
  assert.deepEqual(got, [{
    id: 'PLAN_SOURCE_PRODUCER_ORDER',
    category: 'semantic',
    taskID: 'P00-T001',
    path: '/tasks/0/stages/0/steps/0/source',
    message: 'acquisition for "https://example.com/data" is not before its consuming operation; task=P00-T001 operation=consume-early',
  }]);
});

test('valid local and remote implementation sources produce no finding', () => {
  const plan = {
    planID: 'g6r-source-ok',
    tasks: [
      { taskID: 'P00-T001', productCommit: { stagedProductPaths: ['lib/dep.swift'] },
        stages: [{ name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] }] },
      { taskID: 'P00-T002', stages: [{
          name: 'implementation',
          steps: [
            { kind: 'source-acquisition', acquisition: {
                url: 'https://example.com/data', outputPath: 'sources/data.bin',
                disposition: 'task-step', taskOwner: 'P00-T002', stageOwner: 'implementation' } },
            { kind: 'implementation-operation', operation: 'consume-remote',
              source: { kind: 'remote', url: 'https://example.com/data' } },
            { kind: 'implementation-operation', operation: 'consume-local',
              source: { kind: 'local', path: 'lib/dep.swift' } },
          ],
      }] },
    ],
  };
  assert.deepEqual(auditImplementationSourceInputs(plan, []), []);
});

// ---------------------------------------------------------------------------
// buildPathProducerIndex shape contract
// ---------------------------------------------------------------------------

test('buildPathProducerIndex maps each path to its producer list', () => {
  const plan = {
    planID: 'g6r-index',
    tasks: [
      { taskID: 'P00-T001',
        testContract: { cases: [{ file: { path: 'Tests/Foo.test.swift' } }] },
        productCommit: { stagedProductPaths: ['Sources/Foo.swift'] },
        stages: [{ name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] }] },
    ],
  };
  const idx = buildPathProducerIndex(plan, [{ path: 'base/file.swift', sha256: 'a'.repeat(64) }]);
  assert.ok(idx instanceof Map);
  const base = idx.get('base/file.swift');
  assert.equal(base.length, 1);
  assert.equal(base[0].availability, 'baseline');
  assert.equal(base[0].taskID, null);
  const dep = idx.get('Sources/Foo.swift');
  assert.equal(dep.length, 1);
  assert.equal(dep[0].availability, 'dependency');
  assert.equal(dep[0].taskID, 'P00-T001');
  const step = idx.get('Tests/Foo.test.swift');
  assert.equal(step.length, 1);
  assert.equal(step[0].availability, 'task-step');
  assert.equal(step[0].taskID, 'P00-T001');
});
