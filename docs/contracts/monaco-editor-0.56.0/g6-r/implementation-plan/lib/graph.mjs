// G6-R task-graph audit (ported from G5-R without cross-directory imports).
// Verifies the dependency graph is acyclic, every dependency references a real
// task, and no task lists a duplicate dependency. topologicalOrder returns the
// lexicographic Kahn order; findClosedCycle returns the first cycle found.

import { makeFinding, sortFindings } from './findings.mjs';

const sortedTasks = (tasks) => [...tasks].sort((a, b) =>
  (a.id ?? '').localeCompare(b.id ?? '', 'en'));

/**
 * Return the lexicographic topological order of task IDs. Dependencies that
 * reference unknown tasks are ignored (auditTaskGraph surfaces them separately).
 * @param {Array<{id:string, dependencies?:string[]}>} tasks
 * @returns {string[]}
 */
export function topologicalOrder(tasks) {
  const list = Array.isArray(tasks) ? tasks : [];
  const byId = new Map(list.map((t) => [t.id, t]));
  const indegree = new Map(list.map((t) => [
    t.id,
    new Set((t.dependencies ?? []).filter((d) => byId.has(d))).size,
  ]));
  const dependents = new Map(list.map((t) => [t.id, []]));
  for (const t of list) {
    for (const d of new Set(t.dependencies ?? [])) {
      if (dependents.has(d)) dependents.get(d).push(t.id);
    }
  }
  for (const rows of dependents.values()) {
    rows.sort((a, b) => a.localeCompare(b, 'en'));
  }
  const ready = [...indegree]
    .filter(([, c]) => c === 0)
    .map(([id]) => id)
    .sort((a, b) => a.localeCompare(b, 'en'));
  const order = [];
  while (ready.length !== 0) {
    const id = ready.shift();
    order.push(id);
    for (const dep of dependents.get(id) ?? []) {
      const c = indegree.get(dep) - 1;
      indegree.set(dep, c);
      if (c === 0) {
        ready.push(dep);
        ready.sort((a, b) => a.localeCompare(b, 'en'));
      }
    }
  }
  return order;
}

/**
 * Return the first cycle (as an ordered list of IDs, repeating the entry) or
 * an empty array if the graph is acyclic.
 * @param {Array<{id:string, dependencies?:string[]}>} tasks
 * @returns {string[]}
 */
export function findClosedCycle(tasks) {
  const list = Array.isArray(tasks) ? tasks : [];
  const byId = new Map(list.map((t) => [t.id, t]));
  const state = new Map();
  const stack = [];
  let result = [];

  function visit(id) {
    state.set(id, 'active');
    stack.push(id);
    const deps = [...new Set(byId.get(id)?.dependencies ?? [])]
      .filter((d) => byId.has(d))
      .sort((a, b) => a.localeCompare(b, 'en'));
    for (const d of deps) {
      if (state.get(d) === 'active') {
        const start = stack.indexOf(d);
        result = stack.slice(start).concat(d);
        return true;
      }
      if (state.get(d) !== 'done' && visit(d)) return true;
    }
    stack.pop();
    state.set(id, 'done');
    return false;
  }

  for (const t of sortedTasks(list)) {
    if (!state.has(t.id) && visit(t.id)) break;
  }
  return result;
}

/**
 * Audit the task dependency graph. Returns a deterministically sorted
 * Finding[]. Never throws for data errors.
 * @param {{tasks?:Array<{id:string, dependencies?:string[]}>}} plan
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function auditTaskGraph(plan) {
  const tasks = (plan && Array.isArray(plan.tasks)) ? plan.tasks : [];
  const byId = new Map(tasks.map((t) => [t.id, t]));
  const findings = [];
  for (const task of sortedTasks(tasks)) {
    const seen = new Set();
    for (const dep of (task.dependencies ?? [])) {
      if (!byId.has(dep)) {
        findings.push(makeFinding({
          id: 'PLAN_DEPENDENCY_ABSENT', category: 'graph', taskID: task.id,
          path: `/tasks/${task.id}/dependencies`, message: `dependency ${dep} does not reference a real task`,
        }));
      }
      if (seen.has(dep)) {
        findings.push(makeFinding({
          id: 'PLAN_DEPENDENCY_DUPLICATE', category: 'graph', taskID: task.id,
          path: `/tasks/${task.id}/dependencies`, message: `dependency ${dep} listed more than once`,
        }));
      }
      seen.add(dep);
    }
  }
  if (findings.some((f) => f.id === 'PLAN_DEPENDENCY_ABSENT')) {
    return sortFindings(findings);
  }
  const order = topologicalOrder(tasks);
  if (order.length !== tasks.length) {
    const cycle = findClosedCycle(tasks);
    findings.push(makeFinding({
      id: 'PLAN_DEPENDENCY_CYCLE', category: 'graph', taskID: null,
      path: '/tasks', message: `dependency cycle: ${cycle.join(' -> ')}`,
    }));
  }
  return sortFindings(findings);
}
