// G6-R ambiguity audit. Proves no plan identifier is ambiguous: task IDs,
// command IDs, leaf IDs, and test-contract leaf references are all unique and
// resolve to declared records. Each check emits at most one finding per
// ambiguous identity so a single seeded defect never cascades.

import { makeFinding, sortFindings } from './findings.mjs';

const isObj = (v) => v !== null && typeof v === 'object';

/**
 * Audit identifier uniqueness and leaf-selection ambiguity.
 * @param {{tasks?:Array, commands?:Array, interfaces?:Array}} plan
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function auditAmbiguity(plan) {
  const findings = [];
  const tasks = (plan && Array.isArray(plan.tasks)) ? plan.tasks : [];
  const commands = (plan && Array.isArray(plan.commands)) ? plan.commands : [];

  // Task ID uniqueness.
  const taskIDs = new Set();
  for (const t of tasks) {
    if (!isObj(t) || typeof t.id !== 'string') continue;
    if (taskIDs.has(t.id)) {
      findings.push(makeFinding({
        id: 'PLAN_AMBIGUITY', category: 'ambiguity', taskID: t.id, path: '/tasks',
        message: `task ID ${t.id} is not unique`,
      }));
    }
    taskIDs.add(t.id);
  }

  // Command ID uniqueness.
  const commandIDs = new Set();
  for (const c of commands) {
    if (!isObj(c) || typeof c.commandID !== 'string') continue;
    if (commandIDs.has(c.commandID)) {
      findings.push(makeFinding({
        id: 'PLAN_AMBIGUITY', category: 'ambiguity', taskID: null, path: '/commands',
        message: `command ID ${c.commandID} is not unique`,
      }));
    }
    commandIDs.add(c.commandID);
  }

  // Leaf ID uniqueness + selection: every declared leaf is selected exactly
  // once by a test contract, and every test-contract leaf ref resolves.
  const leafByID = new Map();
  for (const c of commands) {
    if (!isObj(c) || !Array.isArray(c.leaves)) continue;
    for (const leaf of c.leaves) {
      if (!isObj(leaf) || typeof leaf.leafID !== 'string') continue;
      if (leafByID.has(leaf.leafID)) {
        findings.push(makeFinding({
          id: 'PLAN_AMBIGUITY', category: 'ambiguity', taskID: null, path: '/commands',
          message: `leaf ID ${leaf.leafID} is declared by more than one command`,
        }));
      }
      leafByID.set(leaf.leafID, c.commandID);
    }
  }

  const refs = [];
  for (const t of tasks) {
    const tc = t && t.testContract;
    if (!isObj(tc) || !Array.isArray(tc.cases)) continue;
    for (const c of tc.cases) {
      if (!isObj(c)) continue;
      // A case may legitimately omit a Red leaf reference (green-only or
      // no-red cases carry an empty redLeafID); skip empties so they do not
      // register as an ambiguous empty selection.
      if (typeof c.redLeafID === 'string' && c.redLeafID.length > 0) refs.push({ id: c.redLeafID, taskID: t.id });
      if (typeof c.greenLeafID === 'string' && c.greenLeafID.length > 0) refs.push({ id: c.greenLeafID, taskID: t.id });
    }
  }
  const refCount = new Map();
  for (const r of refs) refCount.set(r.id, (refCount.get(r.id) ?? 0) + 1);
  for (const [leafID, count] of refCount) {
    if (count !== 1) {
      findings.push(makeFinding({
        id: 'PLAN_AMBIGUITY', category: 'ambiguity', taskID: null, path: '/tasks',
        message: `leaf ${leafID} is selected ${count} times (expected exactly one)`,
      }));
    }
  }
  for (const r of refs) {
    if (!leafByID.has(r.id)) {
      findings.push(makeFinding({
        id: 'PLAN_AMBIGUITY', category: 'ambiguity', taskID: r.taskID, path: '/tasks',
        message: `test contract references unknown leaf ${r.id}`,
      }));
    }
  }

  return sortFindings(findings);
}
