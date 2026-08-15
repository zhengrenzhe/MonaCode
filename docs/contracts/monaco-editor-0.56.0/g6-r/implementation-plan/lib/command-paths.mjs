// G6-R command-input availability and producer-order proof.
// Repository-owned, dependency-free. Resolves every structured-command input
// to exactly one stage-time source (baseline / dependency / task-step /
// temporary) and walks every implementation-operation source reference.
// Each input yields at most one finding; findings are sorted via findings.mjs
// so output is deterministic and comparable. Never throws for data errors.

import { makeFinding, sortFindings } from './findings.mjs';

// Canonical G6-R stage order (mirrors schema.mjs STAGE_NAMES).
const STAGE_ORDER = [
  'preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence',
];

// ---------------------------------------------------------------------------
// PathProducer index
// ---------------------------------------------------------------------------

/**
 * Build the global path-producer index from a plan and the Task 1 baseline
 * inventory rows. Each producer records its availability class and the
 * stage-time coordinates needed to order it against a consumer.
 *
 * Producers derived:
 *  - baseline:      every baseline row ({ path, sha256 }).
 *  - dependency:    every task's productCommit.stagedProductPaths (committed
 *                    product paths available to later tasks).
 *  - task-step:      every task's testContract case files and path fixtures
 *                    (produced by the test-authoring stage of the same task).
 *  - temporary:     resolved per-command in auditCommandDependencies (an
 *                    earlier leaf under the command's temporary root).
 *
 * @param {{tasks?:any[]}} plan
 * @param {{path:string, sha256?:string}[]} baselineRows
 * @returns {Map<string, import('./findings.mjs').ReturnType<typeof makeFinding>[]>}
 */
export function buildPathProducerIndex(plan, baselineRows) {
  const idx = new Map();
  const add = (p) => {
    const arr = idx.get(p.path) || [];
    arr.push(p);
    idx.set(p.path, arr);
  };

  for (const row of baselineRows || []) {
    if (!row || typeof row.path !== 'string') continue;
    add({
      path: row.path,
      availability: 'baseline',
      taskID: null,
      taskOrder: -1,
      stage: null,
      stageOrder: -1,
      stepIndex: null,
      sha256: typeof row.sha256 === 'string' ? row.sha256 : null,
    });
  }

  const tasks = (plan && Array.isArray(plan.tasks)) ? plan.tasks : [];
  for (let ti = 0; ti < tasks.length; ti++) {
    const task = tasks[ti];
    if (!task) continue;
    const taskID = typeof task.taskID === 'string' ? task.taskID : null;

    // task-step producers: test files and path fixtures (test-authoring stage).
    const tc = task.testContract;
    if (tc && Array.isArray(tc.cases)) {
      for (const c of tc.cases) {
        if (c && c.file && typeof c.file.path === 'string') {
          add({
            path: c.file.path, availability: 'task-step', taskID, taskOrder: ti,
            stage: 'test-authoring', stageOrder: 1, stepIndex: 0, sha256: null,
          });
        }
        if (c && c.fixtures && c.fixtures.kind === 'path' && typeof c.fixtures.path === 'string') {
          add({
            path: c.fixtures.path, availability: 'task-step', taskID, taskOrder: ti,
            stage: 'test-authoring', stageOrder: 1, stepIndex: 0, sha256: null,
          });
        }
      }
    }

    // dependency producers: committed product paths (available to later tasks).
    const pc = task.productCommit;
    if (pc && Array.isArray(pc.stagedProductPaths)) {
      for (const p of pc.stagedProductPaths) {
        if (typeof p !== 'string') continue;
        add({
          path: p, availability: 'dependency', taskID, taskOrder: ti,
          stage: 'commit', stageOrder: 5, stepIndex: 0, sha256: null,
        });
      }
    }
  }

  return idx;
}

// ---------------------------------------------------------------------------
// Producer classification relative to a consumer
// ---------------------------------------------------------------------------

/**
 * Classify a producer as 'prior', 'future', or 'none' relative to a consumer
 * located at (taskOrder ti, stageOrder, stepIndex stepi).
 * @returns {'prior'|'future'|'none'}
 */
function classifyProducer(p, ti, stageOrder, stepi) {
  if (p.availability === 'baseline') return 'prior';
  if (p.availability === 'temporary') return 'none'; // resolved per-command
  if (p.availability === 'dependency') {
    if (p.taskOrder < ti) return 'prior';
    if (p.taskOrder > ti) return 'future';
    return 'none'; // same task: commit-stage output is not a dependency for itself
  }
  if (p.availability === 'task-step') {
    if (p.taskOrder !== ti) return 'none'; // task-step is same-task only
    if (p.stageOrder < stageOrder) return 'prior';
    if (p.stageOrder === stageOrder &&
        p.stepIndex !== null && stepi !== null && p.stepIndex < stepi) return 'prior';
    return 'none'; // a later-stage same-task producer is not yet available
  }
  return 'none';
}

// ---------------------------------------------------------------------------
// Temporary root extraction (per-command)
// ---------------------------------------------------------------------------

function getTempRoots(command) {
  const mut = command.mutations;
  if (!mut || !Array.isArray(mut.temporary)) return [];
  const roots = [];
  for (const pattern of mut.temporary) {
    if (typeof pattern !== 'string') continue;
    const star = pattern.indexOf('*');
    roots.push(star >= 0 ? pattern.slice(0, star) : pattern);
  }
  return roots;
}

function findTempProducer(input, command) {
  const roots = getTempRoots(command);
  if (roots.length === 0) return null;
  const inputPath = input.path;
  if (typeof inputPath !== 'string') return null;
  if (!roots.some((r) => inputPath.startsWith(r))) return null;
  const leaves = (Array.isArray(command.leaves) ? command.leaves : [])
    .filter((l) => l && typeof l.leafID === 'string');
  if (leaves.length < 2) return null; // no earlier leaf could have produced it
  return {
    availability: 'temporary', path: inputPath, taskID: null,
    taskOrder: -1, stage: null, stageOrder: -1, stepIndex: null, sha256: null,
  };
}

// ---------------------------------------------------------------------------
// Command-input resolution
// ---------------------------------------------------------------------------

function resolveCommandInput(input, command, task, ti, si, stageOrder, stepi, ii, index) {
  const inputPath = input.path;
  const commandID = command.commandID;
  const leafIDs = (Array.isArray(command.leaves) ? command.leaves : [])
    .map((l) => l && l.leafID)
    .filter((s) => typeof s === 'string');
  const subject = `command=${commandID} leaves=[${leafIDs.join(',')}]`;
  const findingPath = `/tasks/${ti}/stages/${si}/steps/${stepi}/command/inputs/${ii}`;
  const taskID = (task && typeof task.taskID === 'string') ? task.taskID : null;

  const producers = index.get(inputPath) || [];
  const prior = [];
  const future = [];
  for (const p of producers) {
    const c = classifyProducer(p, ti, stageOrder, stepi);
    if (c === 'prior') prior.push(p);
    else if (c === 'future') future.push(p);
  }
  const temp = findTempProducer(input, command);
  if (temp) prior.push(temp);

  if (prior.length === 0 && future.length === 0) {
    return makeFinding({
      id: 'PLAN_COMMAND_INPUT_UNAVAILABLE', category: 'semantic', taskID, path: findingPath,
      message: `input path "${inputPath}" has no stage-time source; ${subject}`,
    });
  }
  if (prior.length === 0 && future.length > 0) {
    return makeFinding({
      id: 'PLAN_COMMAND_INPUT_FROM_FUTURE', category: 'semantic', taskID, path: findingPath,
      message: `input path "${inputPath}" produced only by a later task; ${subject}`,
    });
  }
  if (prior.length > 1) {
    return makeFinding({
      id: 'PLAN_COMMAND_INPUT_AMBIGUOUS', category: 'semantic', taskID, path: findingPath,
      message: `input path "${inputPath}" has ${prior.length} producers; ${subject}`,
    });
  }
  // exactly one prior producer: verify baseline checksum
  const producer = prior[0];
  if (producer.availability === 'baseline' &&
      typeof input.sha256 === 'string' && typeof producer.sha256 === 'string' &&
      input.sha256 !== producer.sha256) {
    return makeFinding({
      id: 'PLAN_COMMAND_INPUT_HASH_MISMATCH', category: 'semantic', taskID, path: findingPath,
      message: `input path "${inputPath}" baseline sha256 ${input.sha256} != ${producer.sha256}; ${subject}`,
    });
  }
  return null;
}

/**
 * Audit every verification-command input for stage-time availability, producer
 * uniqueness, same-task step order, transitive task dependency, and baseline
 * checksum. Returns a deterministically sorted Finding[].
 * @param {{tasks?:any[]}} plan
 * @param {{path:string, sha256?:string}[]} baselineRows
 */
export function auditCommandDependencies(plan, baselineRows) {
  const index = buildPathProducerIndex(plan, baselineRows);
  const findings = [];
  const tasks = (plan && Array.isArray(plan.tasks)) ? plan.tasks : [];
  for (let ti = 0; ti < tasks.length; ti++) {
    const task = tasks[ti];
    if (!task) continue;
    const stages = Array.isArray(task.stages) ? task.stages : [];
    for (let si = 0; si < stages.length; si++) {
      const stage = stages[si];
      if (!stage) continue;
      const stageOrder = STAGE_ORDER.indexOf(stage.name);
      const steps = Array.isArray(stage.steps) ? stage.steps : [];
      for (let stepi = 0; stepi < steps.length; stepi++) {
        const step = steps[stepi];
        if (!step || step.kind !== 'verification-command' || !step.command) continue;
        const command = step.command;
        const inputs = Array.isArray(command.inputs) ? command.inputs : [];
        for (let ii = 0; ii < inputs.length; ii++) {
          const input = inputs[ii];
          if (!input || typeof input.path !== 'string') continue;
          const f = resolveCommandInput(input, command, task, ti, si, stageOrder, stepi, ii, index);
          if (f) findings.push(f);
        }
      }
    }
  }
  return sortFindings(findings);
}

// ---------------------------------------------------------------------------
// Implementation-operation source-input audit
// ---------------------------------------------------------------------------

function isAcqBefore(acq, op) {
  if (acq.stageOrder < op.stageOrder) return true;
  if (acq.stageOrder === op.stageOrder && acq.stepIndex < op.stepIndex) return true;
  return false;
}

/**
 * @returns {string|null} the collider kind, or null if no collision
 */
function checkOutputCollision(acq, acquisitions, baselinePaths, index, ti) {
  const out = acq.outputPath;
  if (typeof out !== 'string') return null;
  if (baselinePaths.has(out)) return 'baseline';
  for (const a of acquisitions) {
    if (a === acq) continue;
    if (a.outputPath === out) return 'acquisition';
  }
  const producers = index.get(out) || [];
  for (const p of producers) {
    if (p.availability === 'baseline') continue; // already checked
    const c = classifyProducer(p, ti, acq.stageOrder, acq.stepIndex);
    if (c === 'prior') return 'producer';
  }
  return null;
}

/**
 * Audit every implementation-operation source reference. A local source
 * resolves through the same four availability classes; a remote source selects
 * one SourceAcquisition owned by the task before the consuming operation, with
 * one output path/disposition that does not collide with a baseline or another
 * producer. Returns a deterministically sorted Finding[].
 * @param {{tasks?:any[]}} plan
 * @param {{path:string, sha256?:string}[]} baselineRows
 */
export function auditImplementationSourceInputs(plan, baselineRows) {
  const index = buildPathProducerIndex(plan, baselineRows);
  const baselinePaths = new Set(
    (baselineRows || [])
      .filter((r) => r && typeof r.path === 'string')
      .map((r) => r.path)
  );
  const findings = [];
  const tasks = (plan && Array.isArray(plan.tasks)) ? plan.tasks : [];

  for (let ti = 0; ti < tasks.length; ti++) {
    const task = tasks[ti];
    if (!task) continue;
    const taskID = (typeof task.taskID === 'string') ? task.taskID : null;
    const stages = Array.isArray(task.stages) ? task.stages : [];

    const acquisitions = [];
    const operations = [];
    for (let si = 0; si < stages.length; si++) {
      const stage = stages[si];
      if (!stage) continue;
      const stageOrder = STAGE_ORDER.indexOf(stage.name);
      const steps = Array.isArray(stage.steps) ? stage.steps : [];
      for (let stepi = 0; stepi < steps.length; stepi++) {
        const step = steps[stepi];
        if (!step) continue;
        if (step.kind === 'source-acquisition' && step.acquisition) {
          const acq = step.acquisition;
          acquisitions.push({
            url: acq.url, outputPath: acq.outputPath, disposition: acq.disposition,
            stageOrder, stepIndex: stepi, si, stepi,
          });
        } else if (step.kind === 'implementation-operation' && step.source) {
          operations.push({
            source: step.source, operation: step.operation,
            stageOrder, stepIndex: stepi, si, stepi,
          });
        }
      }
    }

    for (const op of operations) {
      const source = op.source;
      const opPath = `/tasks/${ti}/stages/${op.si}/steps/${op.stepi}/source`;

      if (source.kind === 'local') {
        const srcPath = source.path;
        const producers = (typeof srcPath === 'string') ? (index.get(srcPath) || []) : [];
        let hasPrior = false;
        for (const p of producers) {
          if (classifyProducer(p, ti, op.stageOrder, op.stepIndex) === 'prior') {
            hasPrior = true;
            break;
          }
        }
        if (!hasPrior) {
          findings.push(makeFinding({
            id: 'PLAN_SOURCE_INPUT_UNDECLARED', category: 'semantic', taskID, path: opPath,
            message: `implementation source "${srcPath}" has no declared producer; task=${taskID} operation=${op.operation}`,
          }));
        }
      } else if (source.kind === 'remote') {
        const matching = acquisitions.filter((a) => a.url === source.url);
        if (matching.length === 0) {
          findings.push(makeFinding({
            id: 'PLAN_SOURCE_INPUT_UNDECLARED', category: 'semantic', taskID, path: opPath,
            message: `implementation source "${source.url}" has no declared acquisition; task=${taskID} operation=${op.operation}`,
          }));
          continue;
        }
        const before = matching.filter((a) => isAcqBefore(a, op));
        if (before.length === 0) {
          findings.push(makeFinding({
            id: 'PLAN_SOURCE_PRODUCER_ORDER', category: 'semantic', taskID, path: opPath,
            message: `acquisition for "${source.url}" is not before its consuming operation; task=${taskID} operation=${op.operation}`,
          }));
          continue;
        }
        const acq = before[0];
        const collider = checkOutputCollision(acq, acquisitions, baselinePaths, index, ti);
        if (collider) {
          findings.push(makeFinding({
            id: 'PLAN_SOURCE_OUTPUT_COLLISION', category: 'semantic', taskID,
            path: `/tasks/${ti}/stages/${acq.si}/steps/${acq.stepi}/acquisition/outputPath`,
            message: `acquisition output "${acq.outputPath}" collides with ${collider}; task=${taskID} url=${acq.url}`,
          }));
          continue;
        }
        // A temporary disposition is task-local: a later task cannot select it
        // (its task root is removed after finalize-evidence). That path has no
        // producer in this task's index, so a later-task consumer resolves to
        // PLAN_SOURCE_INPUT_UNDECLARED — also a blocking finding.
      }
    }
  }

  return sortFindings(findings);
}
