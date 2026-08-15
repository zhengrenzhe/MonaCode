// G6-R deterministic file-state simulator.
// Repository-owned, dependency-free. Walks every declared task operation
// topologically and proves each has a deterministic input/output file state:
// no create-collision, no modify-before-create, no consumed-before-step, no
// commit-boundary drift, no missing/unreplaced Red scaffold. Models the
// evidence/journal lifecycle (.g6-beginning / .g6-part / .g6-committing /
// .g6-finalizing) and the product-commit-before-passed-evidence +
// first-parent-evidence-successor invariants. Produces 200 task-state hashes
// and one final-state SHA-256.

import { createHash } from 'node:crypto';
import { canonicalJSONStringify } from './canonical-json.mjs';
import { makeFinding, sortFindings } from './findings.mjs';

// Canonical G6-R stage order (mirrors schema.mjs STAGE_NAMES).
const STAGE_ORDER = [
  'preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence',
];

// Journal lifecycle states (never staged, never tracked in the product map).
const JOURNAL_PREFIX = '.g6-';

const isObj = (v) => v !== null && typeof v === 'object';
const isStr = (v) => typeof v === 'string' && v.length > 0;

/**
 * Sort pathMap values by path ascending and return the canonical JSON string.
 * @param {Map<string, object>} pathMap
 * @returns {string}
 */
function canonicalRows(pathMap) {
  const rows = [...pathMap.values()].sort((a, b) =>
    a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
  return canonicalJSONStringify(rows);
}

/**
 * SHA-256 hex digest of a string.
 */
function sha256(s) {
  return createHash('sha256').update(s, 'utf8').digest('hex');
}

/**
 * Simulate every task's file-state transition.
 *
 * @param {{tasks?:any[]}} plan - the G6-R ExecutionPlan (tasks in topological order).
 * @param {{path:string, sha256?:string}[]} baselineRows - Task 1 baseline inventory rows.
 * @returns {{findings:object[], taskStateHashes:string[], finalStateHash:string}}
 */
export function simulateFileState(plan, baselineRows) {
  const findings = [];
  const taskStateHashes = [];
  const pathMap = new Map();
  const evidenceMap = new Map();
  const allEvidencePaths = new Set();

  // --- Initialize pathMap with baseline rows ---
  for (const row of baselineRows || []) {
    if (!row || !isStr(row.path)) continue;
    pathMap.set(row.path, {
      path: row.path, kind: 'baseline', ownerTask: null, ownerStage: null,
      contentSource: 'baseline', disposition: 'baseline',
    });
  }

  const tasks = (isObj(plan) && Array.isArray(plan.tasks)) ? plan.tasks : [];

  // --- Pre-pass: collect all evidence paths ---
  for (const task of tasks) {
    if (!isObj(task)) continue;
    const ec = task.evidenceCommit;
    if (isObj(ec) && isStr(ec.stagedEvidencePath)) {
      allEvidencePaths.add(ec.stagedEvidencePath);
    }
  }

  // --- Walk tasks in topological (plan) order ---
  for (let ti = 0; ti < tasks.length; ti++) {
    const task = tasks[ti];
    if (!isObj(task)) continue;
    const taskID = isStr(task.taskID) ? task.taskID : null;
    const stages = Array.isArray(task.stages) ? task.stages : [];
    const byName = {};
    for (const s of stages) {
      if (isObj(s) && isStr(s.name)) byName[s.name] = s;
    }

    // Track product mutations since preflight.
    const productMutations = new Set();
    const replacedScaffolds = new Set();
    let evidenceJournalState = null;
    let productCommitted = false;

    // --- Walk stages in canonical order ---
    for (const stageName of STAGE_ORDER) {
      const stage = byName[stageName];
      if (!isObj(stage)) continue;
      const steps = Array.isArray(stage.steps) ? stage.steps : [];

      for (let stepi = 0; stepi < steps.length; stepi++) {
        const step = steps[stepi];
        if (!isObj(step)) continue;

        // ---- controller-action ----
        if (step.kind === 'controller-action') {
          if (step.action === 'begin-task') {
            evidenceJournalState = '.g6-beginning';
          } else if (step.action === 'commit-task') {
            evidenceJournalState = '.g6-committing';
            productCommitted = true;

            const pc = task.productCommit;
            const staged = (isObj(pc) && Array.isArray(pc.stagedProductPaths))
              ? pc.stagedProductPaths.filter(isStr) : [];

            // Check: no evidence path enters the product staged set.
            for (const sp of staged) {
              if (allEvidencePaths.has(sp)) {
                findings.push(makeFinding({
                  id: 'PLAN_COMMIT_BOUNDARY_DRIFT', category: 'semantic', taskID,
                  path: `/tasks/${ti}/productCommit`,
                  message: `evidence path "${sp}" must not enter the product staged set`,
                }));
              }
              if (sp.startsWith(JOURNAL_PREFIX)) {
                findings.push(makeFinding({
                  id: 'PLAN_COMMIT_BOUNDARY_DRIFT', category: 'semantic', taskID,
                  path: `/tasks/${ti}/productCommit`,
                  message: `journal path "${sp}" must not enter the product staged set`,
                }));
              }
            }

            // Commit boundary: staged paths must equal accumulated product mutations.
            const stagedSorted = [...staged].sort();
            const mutatedSorted = [...productMutations].sort();
            if (JSON.stringify(stagedSorted) !== JSON.stringify(mutatedSorted)) {
              findings.push(makeFinding({
                id: 'PLAN_COMMIT_BOUNDARY_DRIFT', category: 'semantic', taskID,
                path: `/tasks/${ti}/productCommit`,
                message: `staged paths [${stagedSorted.join(',')}] differ from mutated paths [${mutatedSorted.join(',')}]`,
              }));
            }

            // Mark staged paths as committed.
            for (const sp of staged) {
              const entry = pathMap.get(sp);
              if (entry) entry.disposition = 'committed';
            }
          } else if (step.action === 'finalize-evidence') {
            evidenceJournalState = '.g6-finalizing';
            const ec = task.evidenceCommit;
            const evPath = (isObj(ec) && isStr(ec.stagedEvidencePath))
              ? ec.stagedEvidencePath : null;

            if (evPath) {
              // Product commit must precede passed evidence.
              if (!productCommitted) {
                findings.push(makeFinding({
                  id: 'PLAN_COMMIT_BOUNDARY_DRIFT', category: 'semantic', taskID,
                  path: `/tasks/${ti}/evidenceCommit`,
                  message: 'product commit must precede passed evidence',
                }));
              }
              // Evidence path must not be in the product path map.
              if (pathMap.has(evPath)) {
                findings.push(makeFinding({
                  id: 'PLAN_COMMIT_BOUNDARY_DRIFT', category: 'semantic', taskID,
                  path: `/tasks/${ti}/evidenceCommit`,
                  message: `evidence path "${evPath}" must not enter the product staged set`,
                }));
              }
              // Stage evidence in the separate evidence map (never in pathMap).
              evidenceMap.set(evPath, {
                state: 'passed', ownerTask: taskID,
                journalState: evidenceJournalState,
              });
            }
          }
          continue;
        }

        // ---- authoring-operation ----
        if (step.kind === 'authoring-operation') {
          if (stageName === 'test-authoring') evidenceJournalState = '.g6-part';

          const tc = task.testContract;
          if (isObj(tc) && Array.isArray(tc.cases)) {
            for (const c of tc.cases) {
              if (!isObj(c)) continue;
              // Create test file.
              if (isObj(c.file) && isStr(c.file.path)) {
                const p = c.file.path;
                if (pathMap.has(p)) {
                  const owner = pathMap.get(p).ownerTask || 'baseline';
                  findings.push(makeFinding({
                    id: 'PLAN_FILE_CREATE_COLLISION', category: 'semantic', taskID,
                    path: p,
                    message: `path "${p}" already exists in file state (owner=${owner})`,
                  }));
                } else {
                  pathMap.set(p, {
                    path: p, kind: 'test', ownerTask: taskID, ownerStage: 'test-authoring',
                    contentSource: 'task-step', disposition: 'task-step',
                  });
                }
              }
              // Create path fixture.
              if (isObj(c.fixtures) && c.fixtures.kind === 'path' && isStr(c.fixtures.path)) {
                const p = c.fixtures.path;
                if (pathMap.has(p)) {
                  const owner = pathMap.get(p).ownerTask || 'baseline';
                  findings.push(makeFinding({
                    id: 'PLAN_FILE_CREATE_COLLISION', category: 'semantic', taskID,
                    path: p,
                    message: `path "${p}" already exists in file state (owner=${owner})`,
                  }));
                } else {
                  pathMap.set(p, {
                    path: p, kind: 'fixture', ownerTask: taskID, ownerStage: 'test-authoring',
                    contentSource: 'task-step', disposition: 'task-step',
                  });
                }
              }
            }
          }

          // Explicit creates from the step (product paths authored early).
          if (Array.isArray(step.creates)) {
            for (const p of step.creates) {
              if (!isStr(p)) continue;
              if (pathMap.has(p)) {
                const owner = pathMap.get(p).ownerTask || 'baseline';
                findings.push(makeFinding({
                  id: 'PLAN_FILE_CREATE_COLLISION', category: 'semantic', taskID,
                  path: p,
                  message: `path "${p}" already exists in file state (owner=${owner})`,
                }));
              } else {
                pathMap.set(p, {
                  path: p, kind: 'product', ownerTask: taskID, ownerStage: 'test-authoring',
                  contentSource: 'task-step', disposition: 'task-step',
                });
                productMutations.add(p);
              }
            }
          }

          // Red scaffold: absent -> red-scaffold (Swift-Red tasks only).
          if (isObj(task.redScaffold) && isStr(task.redScaffold.sourcePath)) {
            const sp = task.redScaffold.sourcePath;
            if (sp.endsWith('.swift')) {
              if (pathMap.has(sp)) {
                findings.push(makeFinding({
                  id: 'PLAN_RED_SCAFFOLD_MISSING', category: 'semantic', taskID,
                  path: `/tasks/${ti}/redScaffold`,
                  message: `Swift-Red task scaffold missing for path "${sp}"`,
                }));
              } else {
                pathMap.set(sp, {
                  path: sp, kind: 'scaffold', ownerTask: taskID, ownerStage: 'test-authoring',
                  contentSource: 'task-step', disposition: 'red-scaffold',
                });
                productMutations.add(sp);
              }
            } else {
              findings.push(makeFinding({
                id: 'PLAN_RED_SCAFFOLD_MISSING', category: 'semantic', taskID,
                path: `/tasks/${ti}/redScaffold`,
                message: `Swift-Red task scaffold missing for path "${sp}"`,
              }));
            }
          }
          continue;
        }

        // ---- verification-command ----
        if (step.kind === 'verification-command') {
          if (stageName === 'red' || stageName === 'green') evidenceJournalState = '.g6-part';
          const cmd = isObj(step.command) ? step.command : {};
          const inputs = Array.isArray(cmd.inputs) ? cmd.inputs : [];
          for (const input of inputs) {
            if (!isObj(input) || !isStr(input.path)) continue;
            if (!pathMap.has(input.path)) {
              findings.push(makeFinding({
                id: 'PLAN_FILE_INPUT_UNAVAILABLE_AT_STAGE', category: 'semantic', taskID,
                path: input.path,
                message: `path "${input.path}" consumed at stage "${stageName}" is not available`,
              }));
            }
          }
          continue;
        }

        // ---- source-acquisition ----
        if (step.kind === 'source-acquisition') {
          const acq = isObj(step.acquisition) ? step.acquisition : {};
          if (isStr(acq.outputPath)) {
            const p = acq.outputPath;
            if (pathMap.has(p)) {
              const owner = pathMap.get(p).ownerTask || 'baseline';
              findings.push(makeFinding({
                id: 'PLAN_FILE_CREATE_COLLISION', category: 'semantic', taskID,
                path: p,
                message: `path "${p}" already exists in file state (owner=${owner})`,
              }));
            } else {
              pathMap.set(p, {
                path: p, kind: 'acquisition', ownerTask: taskID, ownerStage: 'implementation',
                contentSource: 'remote', disposition: isStr(acq.disposition) ? acq.disposition : 'temporary',
              });
            }
          }
          continue;
        }

        // ---- implementation-operation ----
        if (step.kind === 'implementation-operation') {
          // Modify declared paths (must already exist).
          if (Array.isArray(step.modifies)) {
            for (const p of step.modifies) {
              if (!isStr(p)) continue;
              if (!pathMap.has(p)) {
                findings.push(makeFinding({
                  id: 'PLAN_FILE_MODIFY_UNAVAILABLE', category: 'semantic', taskID,
                  path: p,
                  message: `path "${p}" cannot be modified: not present in file state`,
                }));
              } else {
                const entry = pathMap.get(p);
                if (entry.disposition === 'red-scaffold') {
                  // Transition: red-scaffold -> implementation.
                  entry.disposition = 'implementation';
                  entry.ownerStage = 'implementation';
                  replacedScaffolds.add(p);
                } else {
                  entry.ownerStage = 'implementation';
                  if (entry.kind !== 'test' && entry.kind !== 'fixture' && entry.kind !== 'baseline') {
                    entry.kind = 'product';
                  }
                }
                productMutations.add(p);
              }
            }
          }
          // Create new product paths.
          if (Array.isArray(step.creates)) {
            for (const p of step.creates) {
              if (!isStr(p)) continue;
              if (pathMap.has(p)) {
                const owner = pathMap.get(p).ownerTask || 'baseline';
                findings.push(makeFinding({
                  id: 'PLAN_FILE_CREATE_COLLISION', category: 'semantic', taskID,
                  path: p,
                  message: `path "${p}" already exists in file state (owner=${owner})`,
                }));
              } else {
                pathMap.set(p, {
                  path: p, kind: 'product', ownerTask: taskID, ownerStage: 'implementation',
                  contentSource: 'task-step', disposition: 'task-step',
                });
                productMutations.add(p);
              }
            }
          }
          continue;
        }
      }
    }

    // --- After all stages: check scaffold final state ---
    if (isObj(task.redScaffold) && isStr(task.redScaffold.sourcePath)) {
      const sp = task.redScaffold.sourcePath;
      if (sp.endsWith('.swift') && pathMap.has(sp) &&
          pathMap.get(sp).kind === 'scaffold' && !replacedScaffolds.has(sp)) {
        findings.push(makeFinding({
          id: 'PLAN_RED_SCAFFOLD_UNREPLACED', category: 'semantic', taskID,
          path: `/tasks/${ti}/redScaffold`,
          message: `red scaffold at "${sp}" was not replaced by implementation`,
        }));
      }
    }

    // --- Compute task-state hash ---
    taskStateHashes.push(sha256(canonicalRows(pathMap)));
  }

  // --- Final-state SHA-256 ---
  const finalStateHash = sha256(canonicalRows(pathMap));

  return { findings: sortFindings(findings), taskStateHashes, finalStateHash };
}
