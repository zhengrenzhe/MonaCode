import { compareFindings, finding } from './findings.mjs';

const sortedTasks = (tasks) => [...tasks].sort((left, right) => left.id.localeCompare(right.id, 'en'));

export function topologicalOrder(tasks) {
  const byId = new Map(tasks.map((task) => [task.id, task]));
  const indegree = new Map(tasks.map((task) => [
    task.id,
    new Set(task.dependencies.filter((dependency) => byId.has(dependency))).size
  ]));
  const dependents = new Map(tasks.map((task) => [task.id, []]));
  for (const task of tasks) {
    for (const dependency of new Set(task.dependencies)) {
      if (dependents.has(dependency)) dependents.get(dependency).push(task.id);
    }
  }
  for (const rows of dependents.values()) rows.sort((left, right) => left.localeCompare(right, 'en'));

  const ready = [...indegree]
    .filter(([, count]) => count === 0)
    .map(([id]) => id)
    .sort((left, right) => left.localeCompare(right, 'en'));
  const order = [];
  while (ready.length !== 0) {
    const id = ready.shift();
    order.push(id);
    for (const dependent of dependents.get(id) ?? []) {
      const count = indegree.get(dependent) - 1;
      indegree.set(dependent, count);
      if (count === 0) {
        ready.push(dependent);
        ready.sort((left, right) => left.localeCompare(right, 'en'));
      }
    }
  }
  return order;
}

export function findClosedCycle(tasks) {
  const byId = new Map(tasks.map((task) => [task.id, task]));
  const state = new Map();
  const stack = [];
  let result = [];

  function visit(id) {
    state.set(id, 'active');
    stack.push(id);
    const dependencies = [...new Set(byId.get(id).dependencies)]
      .filter((dependency) => byId.has(dependency))
      .sort((left, right) => left.localeCompare(right, 'en'));
    for (const dependency of dependencies) {
      if (state.get(dependency) === 'active') {
        const start = stack.indexOf(dependency);
        result = stack.slice(start).concat(dependency);
        return true;
      }
      if (state.get(dependency) !== 'done' && visit(dependency)) return true;
    }
    stack.pop();
    state.set(id, 'done');
    return false;
  }

  for (const task of sortedTasks(tasks)) {
    if (!state.has(task.id) && visit(task.id)) break;
  }
  return result;
}

export function auditTaskGraph(plan) {
  const tasks = plan.tasks ?? [];
  const byId = new Map(tasks.map((task) => [task.id, task]));
  const findings = [];
  for (const task of sortedTasks(tasks)) {
    const seen = new Set();
    for (const dependency of task.dependencies) {
      if (!byId.has(dependency)) {
        findings.push(finding('PLAN_DEPENDENCY_ABSENT', task.id, dependency));
      }
      if (seen.has(dependency)) {
        findings.push(finding('PLAN_DEPENDENCY_DUPLICATE', task.id, dependency));
      }
      seen.add(dependency);
    }
  }
  if (findings.some((row) => row.id === 'PLAN_DEPENDENCY_ABSENT')) {
    return findings.sort(compareFindings);
  }
  const order = topologicalOrder(tasks);
  if (order.length !== tasks.length) {
    const cycle = findClosedCycle(tasks);
    findings.push(finding('PLAN_DEPENDENCY_CYCLE', 'taskGraph', cycle.join(' -> ')));
  }
  return findings.sort(compareFindings);
}
