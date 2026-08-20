import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const G6_ROOT = 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts';
const AUTHORITY_PATH = `${G6_ROOT}/monacode-g6r-authoritative-manifest.json`;
const PLAN_PATH = `${G6_ROOT}/monacode-g6r-implementation-plan-manifest.json`;

const FEATURE_DOMAINS = {
  INPUT: new Set([
    'P05-T103', 'P05-T111', 'P05-T114', 'P05-T116', 'P05-T133',
    'P05-T139', 'P05-T155',
  ]),
  LANG: new Set([
    'P05-T104', 'P05-T106', 'P05-T115', 'P05-T119', 'P05-T121',
    'P05-T124', 'P05-T125', 'P05-T126', 'P05-T127', 'P05-T128',
    'P05-T135', 'P05-T140', 'P05-T146', 'P05-T147', 'P05-T149',
    'P05-T150', 'P05-T151', 'P05-T153', 'P05-T156',
  ]),
  RENDER: new Set([
    'P05-T107', 'P05-T108', 'P05-T118', 'P05-T120', 'P05-T129',
    'P05-T132', 'P05-T136', 'P05-T141', 'P05-T148', 'P05-T152',
    'P05-T154', 'P05-T157', 'P05-T159',
  ]),
  DIFF: new Set(['P05-T112', 'P05-T113']),
  COMMAND: new Set([
    'P05-T100', 'P05-T102', 'P05-T109', 'P05-T117', 'P05-T123',
    'P05-T130', 'P05-T131', 'P05-T134', 'P05-T137', 'P05-T138',
    'P05-T145', 'P05-T158', 'P05-T160', 'P05-T161',
  ]),
};

const readJSON = (repoRoot, path) =>
  JSON.parse(readFileSync(resolve(repoRoot, path), 'utf8'));

const ownershipIdentity = (row) => `${row.kind}:${row.id}`;

function domainForTask(taskID) {
  const match = /^P(\d{2})-T(\d{3})$/.exec(taskID);
  if (!match) {
    throw new Error(`GOVERNANCE_UNMAPPED_PLAN_TASK ${taskID}`);
  }
  const [, phase, taskText] = match;
  const taskNumber = Number(taskText);

  if (phase === '00') {
    if (taskNumber === 1 || taskNumber === 4) return 'SURFACE';
    if (taskNumber >= 5 && taskNumber <= 7) return 'SERVICE';
    return 'VERIFY';
  }
  if (phase === '01') {
    if (taskNumber >= 1 && taskNumber <= 11) return 'MODEL';
    if (taskNumber === 12) return 'SERVICE';
    if (taskNumber === 13) return 'VERIFY';
  }
  if (phase === '02') {
    if (taskNumber >= 1 && taskNumber <= 8) return 'MODEL';
    if (taskNumber === 9) return 'VERIFY';
  }
  if (phase === '03') return 'RENDER';
  if (phase === '04') {
    if (taskNumber >= 1 && taskNumber <= 13) return 'INPUT';
    if (taskNumber >= 14 && taskNumber <= 15) return 'EDITOR';
    if (taskNumber === 16) return 'VERIFY';
  }
  if (phase === '05') {
    if (taskNumber === 1 || taskNumber === 190) return 'SURFACE';
    if (taskNumber >= 2 && taskNumber <= 4) return 'COMMAND';
    if (taskNumber >= 5 && taskNumber <= 7) return 'REGISTRY';
    if (taskNumber === 8 || taskNumber === 13) return 'LANG';
    if (taskNumber >= 9 && taskNumber <= 11) return 'RENDER';
    if (taskNumber === 12) return 'EDITOR';
    if (taskNumber >= 100 && taskNumber <= 161) {
      for (const [domain, tasks] of Object.entries(FEATURE_DOMAINS)) {
        if (tasks.has(taskID)) return domain;
      }
      return 'EDITOR';
    }
    if (taskNumber === 200) return 'VERIFY';
  }
  if (phase === '06') return taskNumber === 9 ? 'SERVICE' : 'LANG';
  if (phase === '07') {
    if ([1, 2, 9].includes(taskNumber)) return 'DIFF';
    if (taskNumber >= 3 && taskNumber <= 8) return 'SERVICE';
    if (taskNumber === 10) return 'VERIFY';
    if (taskNumber === 11) return 'SURFACE';
  }
  if (phase === '08' || phase === '09') return 'VERIFY';

  throw new Error(`GOVERNANCE_UNMAPPED_PLAN_TASK ${taskID}`);
}

export function loadContractCatalog(repoRoot) {
  const authority = readJSON(repoRoot, AUTHORITY_PATH);
  const plan = readJSON(repoRoot, PLAN_PATH);
  const ownershipRows = plan.ownership;

  const activeRows = ownershipRows.filter(
    (row) => row.implementationOwners.length === 1,
  );
  const laterRows = ownershipRows.filter(
    (row) => row.disposition === 'later-ipados',
  );
  const cutRows = ownershipRows.filter(
    (row) => row.implementationOwners.length === 0
      && row.disposition !== 'later-ipados',
  );

  return {
    planTasks: plan.tasks,
    ownershipRows,
    activeIdentities: activeRows.map(
      (row) => `plan:${row.implementationOwners[0]}/${ownershipIdentity(row)}`,
    ),
    cutIdentities: cutRows.map((row) => `cut:${ownershipIdentity(row)}`),
    laterIdentities: laterRows.map(
      (row) => `mobile:02/ownership:${ownershipIdentity(row)}`,
    ),
    mobileScope: authority.deliveryScope.laterRevisions.slice(),
    surfaceCounts: authority.surfaceCounts,
    authority,
    plan,
  };
}

export function deriveProjectTaskDefinitions(catalog) {
  const sortedTasks = catalog.planTasks.slice().sort((left, right) =>
    left.id.localeCompare(right.id, 'en-US'));
  const domains = new Map(
    sortedTasks.map((task) => [task.id, domainForTask(task.id)]),
  );
  const ordinals = new Map([['VERIFY', 1]]);

  const definitions = [{
    id: 'VERIFY-001',
    domain: 'VERIFY',
    sourceTaskID: 'VERIFY-001',
    title: 'Establish and verify single-source project governance',
    selectors: ['governance:single-source'],
    platformScope: ['repository-governance'],
  }];

  for (const task of sortedTasks) {
    const domain = domains.get(task.id);
    const ordinal = (ordinals.get(domain) ?? 0) + 1;
    ordinals.set(domain, ordinal);
    definitions.push({
      id: `${domain}-${String(ordinal).padStart(3, '0')}`,
      domain,
      sourceTaskID: task.id,
      title: task.title,
      selectors: [`plan:${task.id}/*`],
      platformScope: task.platformScope.slice(),
    });
  }

  catalog.mobileScope.forEach((title, index) => {
    const suffix = String(index).padStart(2, '0');
    definitions.push({
      id: `MOBILE-${String(index + 1).padStart(3, '0')}`,
      domain: 'MOBILE',
      sourceTaskID: `MOBILE-${suffix}`,
      title,
      selectors: [`mobile:${suffix}/*`],
      platformScope: ['later-ios-ipados'],
    });
  });

  return definitions;
}
