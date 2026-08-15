import { compareFindings, finding } from './findings.mjs';

function producerMap(tasks, selector) {
  const producers = new Map();
  for (const task of tasks) {
    for (const identity of selector(task)) {
      const owners = producers.get(identity) ?? [];
      owners.push(task.id);
      producers.set(identity, owners);
    }
  }
  return producers;
}

function transitivelyDepends(taskByID, consumerID, producerID) {
  if (consumerID === producerID) return true;
  const visited = new Set();
  const pending = [...(taskByID.get(consumerID)?.dependencies ?? [])];
  while (pending.length > 0) {
    const candidate = pending.pop();
    if (candidate === producerID) return true;
    if (visited.has(candidate)) continue;
    visited.add(candidate);
    pending.push(...(taskByID.get(candidate)?.dependencies ?? []));
  }
  return false;
}

function executableSegment(segment) {
  return /^(?:swift (?:test|package)(?:\s|$)|node (?:--test(?:\s|$)|[A-Za-z0-9_./-]+\.mjs(?:\s|$)))/.test(segment);
}

function exactExecutableCommand(command) {
  if (typeof command !== 'string' || command.includes('\n')) return false;
  const segments = command.split(/\s*(?:&&|\|)\s*/);
  return segments.length > 0 && segments.every((segment) => segment.length > 0 && executableSegment(segment));
}

export function auditExecutability(plan) {
  const tasks = plan.tasks ?? [];
  const taskByID = new Map(tasks.map((task) => [task.id, task]));
  const findings = [];

  const interfaceProducers = producerMap(tasks, (task) => task.interfaces?.produces ?? []);
  for (const [identity, producers] of interfaceProducers) {
    if (producers.length > 1) {
      findings.push(finding(
        'PLAN_INTERFACE_PRODUCER_DUPLICATE',
        identity,
        `interface has multiple producers: ${producers.join(',')}`
      ));
    }
  }
  for (const task of tasks) {
    for (const identity of task.interfaces?.consumes ?? []) {
      const producers = interfaceProducers.get(identity) ?? [];
      if (producers.length === 0) {
        findings.push(finding('PLAN_INTERFACE_UNDEFINED', `${task.id}:${identity}`, 'consumed interface has no producer'));
      } else if (
        producers.length === 1
        && producers[0] !== task.id
        && !transitivelyDepends(taskByID, task.id, producers[0])
      ) {
        findings.push(finding(
          'PLAN_INTERFACE_ORDER',
          `${task.id}:${identity}`,
          `consumer does not transitively depend on producer ${producers[0]}`
        ));
      }
    }
  }

  const fileCreators = producerMap(tasks, (task) => task.files?.create ?? []);
  for (const [file, creators] of fileCreators) {
    if (creators.length > 1) {
      findings.push(finding(
        'PLAN_FILE_PRODUCER_DUPLICATE',
        file,
        `file has multiple create owners: ${creators.join(',')}`
      ));
    }
  }
  for (const task of tasks) {
    for (const file of task.files?.modify ?? []) {
      const creators = fileCreators.get(file) ?? [];
      if (
        creators.length !== 1
        || creators[0] === task.id
        || !transitivelyDepends(taskByID, task.id, creators[0])
      ) {
        findings.push(finding(
          'PLAN_FILE_PROVENANCE',
          `${task.id}:${file}`,
          creators.length === 0
            ? 'modified file has no create owner'
            : `modifier does not follow one unique create owner: ${creators.join(',')}`
        ));
      }
    }
  }

  for (const task of tasks) {
    for (const stage of ['red', 'green']) {
      for (const [index, command] of (task[stage] ?? []).entries()) {
        if (!exactExecutableCommand(command?.run)) {
          findings.push(finding(
            'PLAN_COMMAND_NOT_EXECUTABLE',
            `${task.id}:${stage}[${index}]`,
            String(command?.run)
          ));
        }
      }
    }
  }

  return findings.sort(compareFindings);
}
