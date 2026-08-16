// G6-R Task 11 — phase fragment builder.
//
// buildPhaseFragment migrates every selected G5-R task of a phase into a G6-R
// TaskRecord (via migrateTask) and aggregates the records, converted commands,
// produced interface contracts, and evidence contracts into one PhaseFragment.
// The fragment is the unit Tasks 12-23 author and Task 24 assembles.

import { migrateTask } from './migrate-task.mjs';
import { convertG5Command } from '../../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/command-grammar.mjs';

function taskOverride(overrides, taskID) {
  const tasks = (overrides && overrides.tasks) ? overrides.tasks : {};
  const entry = tasks[taskID];
  return entry && typeof entry === 'object' ? entry : {};
}

function extractCommands(taskRecord) {
  const commands = [];
  for (const stage of taskRecord.stages) {
    if (stage.name !== 'red' && stage.name !== 'green') continue;
    for (const step of stage.steps) {
      if (step.kind === 'verification-command' && step.command) {
        commands.push(step.command);
      }
    }
  }
  return commands;
}

function extractProducedInterfaces(taskRecord, taskOverride) {
  // Produced interface contracts come from the override's interface rows; the
  // migration record carries the selected ID set. We emit one contract row per
  // produced interface, preferring the full override-supplied row.
  const overrideRows = (taskOverride.interfaces && Array.isArray(taskOverride.interfaces.produces))
    ? taskOverride.interfaces.produces
    : [];
  const byID = new Map();
  for (const row of overrideRows) {
    if (row && typeof row === 'object' && typeof row.id === 'string') byID.set(row.id, row);
  }
  return (taskRecord.interfaces?.produces ?? []).map((entry) => {
    const id = typeof entry === 'string' ? entry : entry?.id;
    return byID.get(id) ?? { id };
  });
}

function extractEvidenceContract(taskRecord) {
  return {
    taskID: taskRecord.id,
    stagedEvidencePath: taskRecord.commits.evidence.stagedEvidencePath,
    message: taskRecord.commits.evidence.message,
    verifiedAssertions: [...taskRecord.commits.evidence.verifiedAssertions],
    selectorMode: taskRecord.commits.evidence.selectorMode,
    evidenceSchema: taskRecord.commits.evidence.evidenceSchema,
  };
}

/**
 * Build a PhaseFragment from the selected G5-R tasks and authored overrides.
 *
 * @param {{phase:string, taskIDs:string[], parentPlan:object, overrides:object}} input
 * @returns {{phase:string, tasks:object[], commands:object[], interfaces:object[], evidence:object[], counts:object}}
 */
export function buildPhaseFragment({ phase, taskIDs, parentPlan, overrides }) {
  const tasksByID = new Map();
  for (const task of parentPlan.tasks ?? []) {
    if (task && typeof task.id === 'string') tasksByID.set(task.id, task);
  }

  const taskRecords = [];
  const commands = [];
  const interfaces = [];
  const evidence = [];
  const seenTaskIDs = new Set();

  for (const taskID of taskIDs) {
    if (seenTaskIDs.has(taskID)) continue;
    seenTaskIDs.add(taskID);
    const g5Task = tasksByID.get(taskID);
    if (!g5Task) continue;
    const ov = taskOverride(overrides, taskID);
    const interfaceRows = (ov.interfaces && Array.isArray(ov.interfaces.produces))
      ? ov.interfaces.produces
      : [];
    const record = migrateTask({
      g5Task,
      commandConverter: convertG5Command,
      interfaceRows,
      overrides: ov,
    });
    taskRecords.push(record);
    commands.push(...extractCommands(record));
    interfaces.push(...extractProducedInterfaces(record, ov));
    evidence.push(extractEvidenceContract(record));
  }

  const counts = {
    tasks: taskRecords.length,
    commands: commands.length,
    producedInterfaces: interfaces.length,
    evidence: evidence.length,
  };

  return { phase, tasks: taskRecords, commands, interfaces, evidence, counts };
}

/**
 * Topologically sort tasks: dependencies before dependents, lexicographic
 * tie-breaking among independent tasks (and among a task's own dependencies).
 * @param {object[]} tasks
 * @returns {object[]}
 */
function topologicalSort(tasks) {
  const byID = new Map(tasks.map((t) => [t.id, t]));
  const visited = new Set();
  const result = [];
  function visit(id) {
    if (visited.has(id)) return;
    visited.add(id);
    const task = byID.get(id);
    if (!task) return;
    for (const dep of [...(task.dependencies ?? [])].sort()) {
      if (byID.has(dep)) visit(dep);
    }
    result.push(task);
  }
  for (const id of [...byID.keys()].sort()) {
    visit(id);
  }
  return result;
}

/**
 * Merge multiple phase fragments into one.
 *
 * Tasks are concatenated, deduplicated by ID (duplicates are rejected), and
 * topologically sorted with lexicographic tie-breaking. Commands, interfaces,
 * and evidence are merged by their respective IDs (first occurrence wins).
 *
 * @param {object[]} fragments
 * @param {string} phase
 * @returns {{phase:string, tasks:object[], commands:object[], interfaces:object[], evidence:object[], counts:object}}
 */
export function mergeFragments(fragments, phase) {
  const taskMap = new Map();
  for (const frag of fragments) {
    for (const task of (frag?.tasks ?? [])) {
      if (taskMap.has(task.id)) {
        throw new Error(`G6_MERGE_DUPLICATE_TASK ${task.id}`);
      }
      taskMap.set(task.id, task);
    }
  }
  const tasks = topologicalSort([...taskMap.values()]);

  const commandMap = new Map();
  for (const frag of fragments) {
    for (const cmd of (frag?.commands ?? [])) {
      const id = cmd?.commandID;
      if (id && !commandMap.has(id)) commandMap.set(id, cmd);
    }
  }

  const interfaceMap = new Map();
  for (const frag of fragments) {
    for (const row of (frag?.interfaces ?? [])) {
      const id = typeof row === 'string' ? row : row?.id;
      if (id && !interfaceMap.has(id)) interfaceMap.set(id, row);
    }
  }

  const evidenceMap = new Map();
  for (const frag of fragments) {
    for (const row of (frag?.evidence ?? [])) {
      const id = row?.taskID;
      if (id && !evidenceMap.has(id)) evidenceMap.set(id, row);
    }
  }

  const commands = [...commandMap.values()];
  const interfaces = [...interfaceMap.values()];
  const evidence = [...evidenceMap.values()];

  const counts = {
    tasks: tasks.length,
    commands: commands.length,
    producedInterfaces: interfaces.length,
    evidence: evidence.length,
  };

  return { phase, tasks, commands, interfaces, evidence, counts };
}
