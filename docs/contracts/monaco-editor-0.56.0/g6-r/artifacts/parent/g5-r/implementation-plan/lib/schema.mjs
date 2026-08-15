import { compareFindings, finding } from './findings.mjs';

const REQUIRED_TASK_KEYS = [
  'id',
  'phase',
  'title',
  'platformScope',
  'dependencies',
  'contractRefs',
  'ownership',
  'files',
  'interfaces',
  'red',
  'implementation',
  'green',
  'evidence',
  'completion',
  'commitBoundary'
];

const schemaFinding = (subject, message) => finding('PLAN_SCHEMA_INVALID', subject, message);
const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const nonEmptyString = (value) => typeof value === 'string' && value.trim().length > 0;
const stringArray = (value, minimum = 0) => Array.isArray(value)
  && value.length >= minimum
  && value.every(nonEmptyString);

function boundedPath(value) {
  if (!nonEmptyString(value)) return false;
  if (value.startsWith('/') || value.endsWith('/')) return false;
  if (value === '.' || value === '..') return false;
  if (value.includes('\\') || /[*?\[\]]/.test(value)) return false;
  const segments = value.split('/');
  if (segments.some((segment) => segment === '' || segment === '.' || segment === '..')) return false;
  return true;
}

function validateCommand(command, subject) {
  const findings = [];
  if (!isObject(command)) return [schemaFinding(subject, 'command must be an object')];
  if (!nonEmptyString(command.run)) findings.push(schemaFinding(`${subject}.run`, 'run must be exact non-empty text'));
  if (!Number.isInteger(command.expectedExit)) {
    findings.push(schemaFinding(`${subject}.expectedExit`, 'expectedExit must be an integer'));
  }
  if (!stringArray(command.expectedOutputIncludes, 1)) {
    findings.push(schemaFinding(
      `${subject}.expectedOutputIncludes`,
      'expectedOutputIncludes must contain at least one exact output fragment'
    ));
  }
  return findings;
}

function validateTask(task, index, phaseIDs) {
  const subject = `$.tasks[${index}]`;
  if (!isObject(task)) return [schemaFinding(subject, 'task must be an object')];
  const findings = [];
  for (const key of REQUIRED_TASK_KEYS) {
    if (!(key in task)) findings.push(schemaFinding(`${subject}.${key}`, 'required task field missing'));
  }
  if (!nonEmptyString(task.id)) findings.push(schemaFinding(`${subject}.id`, 'id must be non-empty'));
  if (!phaseIDs.has(task.phase)) findings.push(schemaFinding(`${subject}.phase`, 'phase must reference 00 through 09'));
  if (!nonEmptyString(task.title)) findings.push(schemaFinding(`${subject}.title`, 'title must be non-empty'));
  for (const [key, minimum] of [
    ['platformScope', 1],
    ['dependencies', 0],
    ['contractRefs', 1],
    ['ownership', 1],
    ['evidence', 1],
    ['completion', 1],
    ['commitBoundary', 1]
  ]) {
    if (!stringArray(task[key], minimum)) {
      findings.push(schemaFinding(`${subject}.${key}`, `${key} must be a string array with at least ${minimum} item(s)`));
    }
  }

  if (!isObject(task.files)) {
    findings.push(schemaFinding(`${subject}.files`, 'files must be an object'));
  } else {
    if (task.files.productTarget !== null && !nonEmptyString(task.files.productTarget)) {
      findings.push(schemaFinding(`${subject}.files.productTarget`, 'productTarget must be a string or null'));
    }
    for (const key of ['create', 'modify', 'test']) {
      if (!stringArray(task.files[key])) {
        findings.push(schemaFinding(`${subject}.files.${key}`, `${key} must be a string array`));
      } else {
        for (const [pathIndex, file] of task.files[key].entries()) {
          if (!boundedPath(file)) findings.push(schemaFinding(`${subject}.files.${key}[${pathIndex}]`, 'file path is unbounded'));
        }
      }
    }
  }

  if (!isObject(task.interfaces)) {
    findings.push(schemaFinding(`${subject}.interfaces`, 'interfaces must be an object'));
  } else {
    if (!stringArray(task.interfaces.consumes)) {
      findings.push(schemaFinding(`${subject}.interfaces.consumes`, 'consumes must be a string array'));
    }
    if (!stringArray(task.interfaces.produces)) {
      findings.push(schemaFinding(`${subject}.interfaces.produces`, 'produces must be a string array'));
    }
    if ((task.interfaces.consumes?.length ?? 0) + (task.interfaces.produces?.length ?? 0) === 0) {
      findings.push(schemaFinding(`${subject}.interfaces`, 'at least one consumed or produced interface is required'));
    }
  }

  for (const key of ['red', 'green']) {
    if (!Array.isArray(task[key]) || task[key].length === 0) {
      findings.push(schemaFinding(`${subject}.${key}`, `${key} must contain at least one command`));
    } else {
      task[key].forEach((command, commandIndex) => {
        findings.push(...validateCommand(command, `${subject}.${key}[${commandIndex}]`));
      });
    }
  }

  if (!isObject(task.implementation) || !stringArray(task.implementation.operations, 1)) {
    findings.push(schemaFinding(`${subject}.implementation.operations`, 'operations must be a non-empty string array'));
  }

  if (Array.isArray(task.commitBoundary)) {
    const declaredFiles = new Set([
      ...(task.files?.create ?? []),
      ...(task.files?.modify ?? []),
      ...(task.files?.test ?? [])
    ]);
    for (const [boundaryIndex, boundary] of task.commitBoundary.entries()) {
      if (!boundedPath(boundary)) {
        findings.push(schemaFinding(`${subject}.commitBoundary[${boundaryIndex}]`, 'commit path is unbounded'));
      } else if (!declaredFiles.has(boundary)) {
        findings.push(schemaFinding(`${subject}.commitBoundary[${boundaryIndex}]`, 'commit path is not declared by task files'));
      }
    }
  }
  return findings;
}

function validateOwnership(row, index) {
  const subject = `$.ownership[${index}]`;
  if (!isObject(row)) return [schemaFinding(subject, 'ownership row must be an object')];
  const findings = [];
  for (const key of ['kind', 'id', 'disposition']) {
    if (!nonEmptyString(row[key])) findings.push(schemaFinding(`${subject}.${key}`, `${key} must be non-empty`));
  }
  for (const key of ['implementationOwners', 'testOwners']) {
    if (!stringArray(row[key])) findings.push(schemaFinding(`${subject}.${key}`, `${key} must be a string array`));
  }
  return findings;
}

function duplicateFindings(rows, keyFor, subject) {
  const seen = new Set();
  const duplicates = new Set();
  for (const row of rows) {
    const key = keyFor(row);
    if (!nonEmptyString(key)) continue;
    if (seen.has(key)) duplicates.add(key);
    seen.add(key);
  }
  return [...duplicates].sort().map((key) => schemaFinding(subject, `duplicate identity: ${key}`));
}

export function validatePlanSchema(value) {
  if (!isObject(value)) return [schemaFinding('$', 'plan manifest must be an object')];
  const findings = [];
  const requiredTopLevel = [
    'schemaVersion', 'planRevision', 'contract', 'adoptionState', 'planState',
    'platformScope', 'globalConstraints', 'packageGraph', 'qualificationEnvironment',
    'evidenceStates', 'candidateArtifacts', 'phases', 'tasks', 'ownership', 'documents', 'audit'
  ];
  for (const key of requiredTopLevel) {
    if (!(key in value)) findings.push(schemaFinding(`$.${key}`, 'required manifest field missing'));
  }
  if (value.schemaVersion !== 1) findings.push(schemaFinding('$.schemaVersion', 'schemaVersion must equal 1'));
  if (!['candidate', 'adopted'].includes(value.adoptionState)) {
    findings.push(schemaFinding('$.adoptionState', 'adoptionState must be candidate or adopted'));
  }
  if (!['planned', 'mapped', 'structurally-verified'].includes(value.planState)) {
    findings.push(schemaFinding('$.planState', 'planState is not a plan evidence state'));
  }
  if (!stringArray(value.platformScope, 1)) findings.push(schemaFinding('$.platformScope', 'platformScope must be non-empty'));
  if (!stringArray(value.globalConstraints, 1)) findings.push(schemaFinding('$.globalConstraints', 'globalConstraints must be non-empty'));

  const expectedPhases = Array.from({ length: 10 }, (_, index) => String(index).padStart(2, '0'));
  const phaseIDs = new Set(Array.isArray(value.phases) ? value.phases.map((phase) => phase?.id) : []);
  if (!Array.isArray(value.phases) || JSON.stringify([...phaseIDs].sort()) !== JSON.stringify(expectedPhases)) {
    findings.push(schemaFinding('$.phases', 'phases must contain unique IDs 00 through 09'));
  }
  if (!Array.isArray(value.tasks)) {
    findings.push(schemaFinding('$.tasks', 'tasks must be an array'));
  } else {
    value.tasks.forEach((task, index) => findings.push(...validateTask(task, index, phaseIDs)));
    findings.push(...duplicateFindings(value.tasks, (task) => task?.id, '$.tasks'));
  }
  if (!Array.isArray(value.ownership)) {
    findings.push(schemaFinding('$.ownership', 'ownership must be an array'));
  } else {
    value.ownership.forEach((row, index) => findings.push(...validateOwnership(row, index)));
    findings.push(...duplicateFindings(value.ownership, (row) => `${row?.kind}:${row?.id}`, '$.ownership'));
  }
  if (!Array.isArray(value.documents)) findings.push(schemaFinding('$.documents', 'documents must be an array'));

  if (value.adoptionState === 'adopted') {
    if ((value.tasks?.length ?? 0) === 0) findings.push(schemaFinding('$.tasks', 'adopted plan requires tasks'));
    if ((value.ownership?.length ?? 0) === 0) findings.push(schemaFinding('$.ownership', 'adopted plan requires ownership'));
    if ((value.documents?.length ?? 0) === 0) findings.push(schemaFinding('$.documents', 'adopted plan requires document hashes'));
    if (value.audit?.status !== 'pass' || value.audit?.findingCount !== 0) {
      findings.push(schemaFinding('$.audit', 'adopted plan requires a zero-finding pass audit'));
    }
  }
  return findings.sort(compareFindings);
}
