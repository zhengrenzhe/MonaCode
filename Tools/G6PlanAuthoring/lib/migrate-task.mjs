// G6-R Task 11 — deterministic G5-R task migration.
//
// migrateTask converts one G5-R product task into a G6-R TaskRecord without
// semantic inference. The ONLY automatic path rewrite is the evidence-root
// revision segment `artifacts/acceptance-evidence/g5-r/` -> `.../g6-r/`; every
// other planning decision (interface signature, environment value, mutation,
// source input, test behavior, implementation decision) must be authored
// explicitly in phase override files by Tasks 12-23.
//
// Every migrated task:
//   - places commit before evidence;
//   - keeps the inherited product commit-boundary path set (g5Task.commitBoundary);
//   - derives product subject `monacode: complete <TASK_ID>` and evidence subject
//     `evidence(monacode): complete <TASK_ID>` by exact ASCII concatenation;
//   - sets both identities to zhengrenzhe <zhengrenzhe0416@outlook.com>;
//   - prohibits product-stage evidence staging (evidenceExcluded: true);
//   - uses exactly one `planctl commit-task` controller-action in the commit stage;
//   - ends with exactly one `planctl finalize-evidence` controller-action that
//     commits only the evidence path.
//
// The converter never invents a missing path, interface signature, environment
// value, mutation, source input, test behavior, or implementation decision.

import { createHash } from 'node:crypto';

export const IDENTITY = Object.freeze({
  name: 'zhengrenzhe',
  email: 'zhengrenzhe0416@outlook.com',
});

export const TASK_ID_RE = /^P[0-9]{2}-T[0-9]{3}$/;

export const STAGE_NAMES = [
  'preflight',
  'test-authoring',
  'red',
  'implementation',
  'green',
  'commit',
  'evidence',
];

const EVIDENCE_FROM_PREFIX = 'artifacts/acceptance-evidence/g5-r/';
const EVIDENCE_TO_PREFIX = 'artifacts/acceptance-evidence/g6-r/';

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

/**
 * Canonical JSON: object keys sorted ascending, array order preserved exactly.
 * Matches the G6-R contract canonical form so record hashes are reproducible.
 * @param {unknown} value
 * @returns {string}
 */
function canonicalStringify(value) {
  if (Array.isArray(value)) {
    let out = '[';
    for (let i = 0; i < value.length; i += 1) {
      if (i > 0) out += ',';
      out += canonicalStringify(value[i]);
    }
    out += ']';
    return out;
  }
  if (value !== null && typeof value === 'object') {
    const keys = Object.keys(value).sort();
    let out = '{';
    for (let i = 0; i < keys.length; i += 1) {
      if (i > 0) out += ',';
      out += JSON.stringify(keys[i]) + ':' + canonicalStringify(value[keys[i]]);
    }
    out += '}';
    return out;
  }
  return JSON.stringify(value);
}

function assertTaskID(taskID) {
  if (typeof taskID !== 'string' || !TASK_ID_RE.test(taskID)) {
    throw new Error(`TASK_ID_GRAMMAR:${String(taskID)}`);
  }
}

/**
 * Build the product commit subject by exact ASCII concatenation.
 * @param {string} taskID
 * @returns {string} `monacode: complete ${taskID}`
 */
export function buildCommitMessage(taskID) {
  assertTaskID(taskID);
  return `monacode: complete ${taskID}`;
}

/**
 * Build the evidence commit subject by exact ASCII concatenation.
 * @param {string} taskID
 * @returns {string} `evidence(monacode): complete ${taskID}`
 */
export function buildEvidenceCommitMessage(taskID) {
  assertTaskID(taskID);
  return `evidence(monacode): complete ${taskID}`;
}

/**
 * Rewrite the evidence-root revision segment `g5-r` -> `g6-r`.
 * Requires every input to match the G5 prefix, preserves each remaining suffix
 * byte-for-byte, and rejects collisions.
 * @param {string[]} g5EvidencePaths
 * @returns {{paths:string[], fromRevision:string, toRevision:string, stagedEvidencePath:string}}
 */
function buildEvidenceContract(g5Task, { fromRevision, toRevision }) {
  const paths = g5Task.evidence;
  const rewritten = [];
  const seen = new Set();
  for (const original of paths) {
    if (typeof original !== 'string' || !original.startsWith(EVIDENCE_FROM_PREFIX)) {
      throw new Error(`EVIDENCE_PREFIX:${String(original)}`);
    }
    const suffix = original.slice(EVIDENCE_FROM_PREFIX.length);
    if (suffix.length === 0) {
      throw new Error(`EVIDENCE_SUFFIX_EMPTY:${String(original)}`);
    }
    const next = EVIDENCE_TO_PREFIX + suffix;
    if (seen.has(next)) {
      throw new Error(`EVIDENCE_COLLISION:${next}`);
    }
    seen.add(next);
    rewritten.push(next);
  }
  // A task stages exactly one evidence path.
  if (rewritten.length !== 1) {
    throw new Error(`EVIDENCE_PATH_COUNT:${rewritten.length}`);
  }
  return {
    paths: rewritten,
    fromRevision,
    toRevision,
    stagedEvidencePath: rewritten[0],
  };
}

/**
 * Preserve the G5 file rows. Override paths (Tasks 12-23) may augment the create
 * set; the converter never invents a path.
 * @param {object} g5Task
 * @param {Array} overridePaths
 */
function normalizePathRows(g5Task, overridePaths) {
  const files = g5Task.files ?? {};
  const create = [...(Array.isArray(files.create) ? files.create : [])];
  const modify = [...(Array.isArray(files.modify) ? files.modify : [])];
  const test = [...(Array.isArray(files.test) ? files.test : [])];
  for (const row of overridePaths) {
    if (typeof row === 'string') {
      if (!create.includes(row)) create.push(row);
    } else if (row && typeof row === 'object' && typeof row.path === 'string') {
      const target = row.kind === 'modify' ? modify : row.kind === 'test' ? test : create;
      if (!target.includes(row.path)) target.push(row.path);
    }
  }
  return {
    productTarget: files.productTarget ?? null,
    create,
    modify,
    test,
  };
}

/**
 * Select the interface rows belonging to this task. Preserves the G5
 * produces/consumes ID sets and attaches the full declaration row where the
 * caller (Tasks 12-23) supplied one in `interfaceRows`. The converter never
 * invents an interface signature.
 * @param {object} g5Task
 * @param {object[]} interfaceRows
 */
function selectInterfaceRows(g5Task, interfaceRows) {
  const byID = new Map();
  for (const row of Array.isArray(interfaceRows) ? interfaceRows : []) {
    if (row && typeof row === 'object' && typeof row.id === 'string') {
      byID.set(row.id, row);
    }
  }
  const produces = (g5Task.interfaces?.produces ?? []).map((id) => byID.get(id) ?? { id });
  const consumes = (g5Task.interfaces?.consumes ?? []).map((id) => byID.get(id) ?? { id });
  return { produces, consumes };
}

function deriveTestAuthoringOperation(g5Task) {
  const testFiles = g5Task.files?.test ?? [];
  if (testFiles.length > 0) return testFiles[0];
  const run = g5Task.red?.[0]?.run;
  if (typeof run === 'string' && run.length > 0) return run;
  return g5Task.id;
}

/**
 * Build exactly seven ordered stages. The red and green stages each carry one
 * converted verification command (the converter is injected; migrateTask never
 * invents command shape). The commit stage carries exactly one `commit-task`
 * controller-action; the evidence stage ends with exactly one `finalize-evidence`
 * controller-action.
 */
function buildSevenStages(g5Task, commandConverter, overrides, stageNames) {
  if (stageNames.length !== 7) throw new Error(`STAGE_COUNT:${stageNames.length}`);
  for (let i = 0; i < STAGE_NAMES.length; i += 1) {
    if (stageNames[i] !== STAGE_NAMES[i]) throw new Error(`STAGE_NAME:${stageNames[i]}`);
  }

  const convert = (stage, index, row) => commandConverter({ task: g5Task, stage, index, row });
  const redCommands = (g5Task.red ?? []).map((row, i) => convert('red', i, row));
  const greenCommands = (g5Task.green ?? []).map((row, i) => convert('green', i, row));

  if (redCommands.length !== 1) throw new Error(`RED_COMMAND_COUNT:${redCommands.length}`);
  if (greenCommands.length !== 1) throw new Error(`GREEN_COMMAND_COUNT:${greenCommands.length}`);

  // Implementation operations: authored overrides take precedence; the G5
  // operations are the fallback when no override is supplied. Each override
  // entry may be a string (operation) or an object carrying `.operation`.
  const fallbackOps = Array.isArray(g5Task.implementation?.operations)
    ? g5Task.implementation.operations
    : [];
  const overrideOps = Array.isArray(overrides.implementationOperations)
    ? overrides.implementationOperations
    : null;
  const implementationOps = (overrideOps && overrideOps.length > 0 ? overrideOps : fallbackOps)
    .map((op) => (typeof op === 'string' ? op : op?.operation ?? ''))
    .filter((op) => typeof op === 'string' && op.length > 0);

  // Source-acquisition steps precede the implementation operations that
  // consume them. Authored overrides supply the complete SourceAcquisition
  // records; the converter never invents a remote source.
  const acquisitionSteps = (Array.isArray(overrides.sourceAcquisitions) ? overrides.sourceAcquisitions : [])
    .filter((a) => a && typeof a === 'object')
    .map((a) => ({ kind: 'source-acquisition', acquisition: a }));

  const stages = [
    {
      name: 'preflight',
      steps: [{ kind: 'controller-action', action: 'begin-task' }],
    },
    {
      name: 'test-authoring',
      steps: [{
        kind: 'authoring-operation',
        operation: overrides.testAuthoringOperation ?? deriveTestAuthoringOperation(g5Task),
      }],
    },
    {
      name: 'red',
      steps: redCommands.map((command) => ({ kind: 'verification-command', command })),
    },
    {
      name: 'implementation',
      steps: [
        ...acquisitionSteps,
        ...implementationOps.map((operation) => ({ kind: 'implementation-operation', operation })),
      ],
    },
    {
      name: 'green',
      steps: greenCommands.map((command) => ({ kind: 'verification-command', command })),
    },
    {
      name: 'commit',
      steps: [{ kind: 'controller-action', action: 'commit-task' }],
    },
    {
      name: 'evidence',
      steps: [{ kind: 'controller-action', action: 'finalize-evidence' }],
    },
  ];

  return { stages, redCommands, greenCommands };
}

function leafIDs(command) {
  return (command?.leaves ?? []).map((leaf) => leaf.leafID);
}

/**
 * Normalize a repository-relative path: forward slashes, no leading `./`,
 * no parent traversal, no NUL. Returns null if the path is invalid.
 */
function normalizePath(p) {
  if (typeof p !== 'string' || p.length === 0) return null;
  if (p.includes('\0')) return null;
  let normalized = p;
  if (normalized.startsWith('./')) normalized = normalized.slice(2);
  normalized = normalized.replace(/\\/g, '/');
  while (normalized.startsWith('/')) normalized = normalized.slice(1);
  if (normalized.length === 0) return null;
  for (const seg of normalized.split('/')) {
    if (seg === '..' || seg === '.' || seg === '') return null;
  }
  return normalized;
}

/**
 * Build the Red-scaffold marker `G6_RED_SCAFFOLD:<task-id>:<sha256(normalizedPath)>`
 * where the suffix hashes the UTF-8 bytes of the normalized repo-relative path.
 * @returns {string|null} null if the path is invalid.
 */
export function scaffoldMarker(taskID, sourcePath) {
  const normalized = normalizePath(sourcePath);
  if (normalized === null) return null;
  return `G6_RED_SCAFFOLD:${taskID}:${sha256(Buffer.from(normalized, 'utf-8'))}`;
}

/**
 * A Swift-Red task creates Swift sources under Sources/ and runs `swift test`.
 */
function isSwiftRedTask(g5Task) {
  const createsSwift = (g5Task.files?.create ?? []).some(
    (p) => p.startsWith('Sources/') && p.endsWith('.swift'),
  );
  const red = g5Task.red ?? [];
  return createsSwift && red.some((row) => typeof row.run === 'string' && row.run.startsWith('swift test '));
}

/**
 * Build the Red-scaffold rows for a task. Authored overrides take precedence;
 * otherwise the migration derives one minimal scaffold row per created Swift
 * source path (sourcePath + marker). The full declaration text, hash, and
 * compile-only body are authored by Tasks 12-23; the converter never invents
 * a declaration.
 */
function buildRedScaffold(g5Task, overrides) {
  if (Array.isArray(overrides.redScaffold)) {
    return overrides.redScaffold.filter((s) => s && typeof s === 'object');
  }
  if (!isSwiftRedTask(g5Task)) return [];
  const createdSwift = (g5Task.files?.create ?? [])
    .filter((p) => p.startsWith('Sources/') && p.endsWith('.swift'));
  return createdSwift.map((sourcePath) => {
    const marker = scaffoldMarker(g5Task.id, sourcePath);
    return {
      sourcePath,
      marker,
      sentinelBehavior: 'compile-fail',
      createOwner: 'test-authoring',
      replacementOwner: 'implementation',
    };
  });
}

/**
 * Build one task-test contract selecting every Red/Green leaf exactly once.
 * Pairs red leaves with green leaves by index. Case field defaults are derived
 * from G5 data; Tasks 12-23 author the exact contract via overrides, which
 * replace the G5-derived scaffold wholesale when supplied.
 */
function buildTestContract(g5Task, redCommands, greenCommands, overrides) {
  const redLeaves = redCommands.flatMap(leafIDs);
  const greenLeaves = greenCommands.flatMap(leafIDs);
  const pairCount = Math.max(redLeaves.length, greenLeaves.length);
  const cases = [];
  const testFile = g5Task.files?.test?.[0] ?? g5Task.commitBoundary?.[0] ?? '';
  const checker = g5Task.red?.[0]?.run ?? '';
  const assertionID = g5Task.red?.[0]?.expectedOutputIncludes?.[0] ?? `${g5Task.id}.red`;
  for (let i = 0; i < pairCount; i += 1) {
    const redLeafID = redLeaves[i] ?? redLeaves[redLeaves.length - 1];
    const greenLeafID = greenLeaves[i] ?? greenLeaves[greenLeaves.length - 1];
    cases.push({
      caseID: `${g5Task.id}.CASE.${String(i + 1).padStart(3, '0')}`,
      file: { path: testFile, availability: testFile ? 'local' : 'inherited' },
      checker,
      target: testFile,
      testSymbol: '',
      fixtures: { kind: 'inline', values: {} },
      assertions: [{ id: assertionID, operand: 'equals' }],
      redLeafID,
      greenLeafID,
      inheritedOutput: true,
      failureClass: 'assertion',
      authoringOperation: overrides.testAuthoringOperation ?? deriveTestAuthoringOperation(g5Task),
      source: 'baseline',
    });
  }
  return { contractID: g5Task.id, cases };
}

function buildProductCommitContract(g5Task) {
  const stagedProductPaths = [...(g5Task.commitBoundary ?? [])];
  return {
    author: { ...IDENTITY },
    committer: { ...IDENTITY },
    message: buildCommitMessage(g5Task.id),
    stagedProductPaths,
    hooksDisabled: true,
    signingDisabled: true,
    evidenceExcluded: true,
  };
}

function buildEvidenceCommitContract(g5Task, stagedEvidencePath) {
  return {
    author: { ...IDENTITY },
    committer: { ...IDENTITY },
    message: buildEvidenceCommitMessage(g5Task.id),
    firstParentSuccessor: 'immediate',
    stagedEvidencePath,
    laterFirstParentTouches: 0,
    hooksDisabled: true,
    signingDisabled: true,
    selectorMode: 'external-git',
    prohibitsSelfEmbedding: true,
    evidenceSchema: 'task-evidence.schema.json',
    verifiedAssertions: [...(g5Task.completion ?? [])],
  };
}

/**
 * Canonical record hash: SHA-256 of the canonical JSON of the task record with
 * the `recordSha256` field excluded. Stable across runs.
 */
function recordSha256(task) {
  const body = { ...task };
  delete body.recordSha256;
  return sha256(canonicalStringify(body));
}

/**
 * Migrate one G5-R product task into a G6-R TaskRecord.
 *
 * @param {{g5Task:object, commandConverter:function, interfaceRows:object[], overrides:object}} input
 * @returns {object} TaskRecord with a canonical `recordSha256`
 */
export function migrateTask({ g5Task, commandConverter, interfaceRows, overrides }) {
  if (!g5Task || typeof g5Task !== 'object') throw new Error('G5_TASK_TYPE');
  assertTaskID(g5Task.id);

  // G5 provides NO commitMessage field; a conflicting field is rejected.
  if (Object.hasOwn(g5Task, 'commitMessage')) {
    throw new Error(`COMMIT_MESSAGE_CONFLICT:${g5Task.id}`);
  }
  // Override conflicts are rejected: the derived subject/boundary are authoritative.
  if (overrides && overrides.commitMessage !== undefined
      && overrides.commitMessage !== buildCommitMessage(g5Task.id)) {
    throw new Error(`COMMIT_MESSAGE_CONFLICT:${g5Task.id}`);
  }
  if (overrides && overrides.stagedProductPaths !== undefined) {
    const inherited = [...(g5Task.commitBoundary ?? [])].sort();
    const provided = [...overrides.stagedProductPaths].sort();
    if (JSON.stringify(provided) !== JSON.stringify(inherited)) {
      throw new Error(`COMMIT_BOUNDARY_CONFLICT:${g5Task.id}`);
    }
  }
  if (overrides && overrides.evidencePaths !== undefined) {
    for (const p of overrides.evidencePaths) {
      if (typeof p !== 'string' || !p.startsWith(EVIDENCE_FROM_PREFIX)) {
        throw new Error(`EVIDENCE_PREFIX:${String(p)}`);
      }
    }
  }

  const ov = overrides ?? {};
  const evidence = buildEvidenceContract(g5Task, { fromRevision: 'g5-r', toRevision: 'g6-r' });
  const { stages, redCommands, greenCommands } = buildSevenStages(
    g5Task, commandConverter, ov, STAGE_NAMES,
  );
  // Authored test contract replaces the G5-derived scaffold when supplied
  // complete (object with a non-empty cases array); otherwise the migration
  // derives the scaffold from G5 data.
  const testContract = (ov.testContract && typeof ov.testContract === 'object'
    && Array.isArray(ov.testContract.cases) && ov.testContract.cases.length > 0)
    ? ov.testContract
    : buildTestContract(g5Task, redCommands, greenCommands, ov);
  const redScaffold = buildRedScaffold(g5Task, ov);
  const sourceAcquisitions = Array.isArray(ov.sourceAcquisitions) ? ov.sourceAcquisitions : [];

  const task = {
    id: g5Task.id,
    phase: g5Task.phase,
    title: g5Task.title,
    platformScope: [...g5Task.platformScope],
    dependencies: [...(g5Task.dependencies ?? [])].sort(),
    contractRefs: [...(g5Task.contractRefs ?? [])].sort(),
    ownership: [...(g5Task.ownership ?? [])],
    paths: normalizePathRows(g5Task, ov.paths ?? []),
    interfaces: selectInterfaceRows(g5Task, interfaceRows),
    stages,
    testContract,
    redScaffold,
    sourceAcquisitions,
    evidence,
    completion: [...(g5Task.completion ?? [])],
    commits: {
      product: buildProductCommitContract(g5Task),
      evidence: buildEvidenceCommitContract(g5Task, evidence.stagedEvidencePath),
    },
  };
  return { ...task, recordSha256: recordSha256(task) };
}
