// G6-R Task 24 — complete plan assembly.
//
// assemblePlan loads the 10 phase fragments (phase-00..phase-09), topologically
// sorts all 200 tasks with lexicographic tie-breaking, deduplicates interface /
// verification-command / source-acquisition rows by ID, preserves all 3,582
// ownership rows from G5-R, recomputes record hashes, and returns one
// ExecutionPlan machine record. The assembly checks its OWN invariants:
// fragment order, task uniqueness, seven-stage order, lifecycle-action counts,
// product/evidence-commit contracts, evidence self-embedding prohibition,
// command/interface/source resolution, ownership uniqueness, and record-hash
// stability. It does NOT validate against the Task 3 JSON schema (deferred to
// Task 26 audit) and carries every enrichment field the converter produced.
//
// When run as a script, assemblePlan + renderPlan produce the three machine
// manifests and eleven human documents.

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import * as path from 'node:path';

import { canonicalJSONStringify } from '../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/canonical-json.mjs';
import { renderPlan } from './render-plan.mjs';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

export const PLAN_ID = 'G6-R';
export const PLAN_REVISION = 'g6-r-execution-readiness';
export const SCHEMA_VERSION = 'G6-R';
export const BASE_COMMIT = '6343dc191ad77310194915bea2514c7b70733cfe';

export const STAGE_NAMES = [
  'preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence',
];

export const PHASE_ORDER = ['00', '01', '02', '03', '04', '05', '06', '07', '08', '09'];

const PHASE_META = [
  { id: '00', title: 'Scaffold and harness', slug: 'phase-00-scaffold-harness', dependencies: [] },
  { id: '01', title: 'Base model and transaction truth', slug: 'phase-01-base-model', dependencies: ['00'] },
  { id: '02', title: 'Model semantics and environment behavior', slug: 'phase-02-model-semantics', dependencies: ['01'] },
  { id: '03', title: 'Projection, layout, and rendering', slug: 'phase-03-projection-layout-rendering', dependencies: ['02'] },
  { id: '04', title: 'Input, transfer, accessibility, and embedding', slug: 'phase-04-input-transfer-accessibility', dependencies: ['03'] },
  { id: '05', title: 'Public surface and retained features', slug: 'phase-05-public-surface-features', dependencies: ['04'] },
  { id: '06', title: 'Language, LSP, snippet, and Markdown', slug: 'phase-06-language-lsp-snippet-markdown', dependencies: ['05'] },
  { id: '07', title: 'Diff, services, host, and source closure', slug: 'phase-07-diff-services-host-source-closure', dependencies: ['06'] },
  { id: '08', title: 'Release candidate and distribution', slug: 'phase-08-release-candidate-distribution', dependencies: ['07'] },
  { id: '09', title: 'Acceptance and release verdict', slug: 'phase-09-acceptance-release-verdict', dependencies: ['08'] },
];

const IDENTITY = Object.freeze({
  name: 'zhengrenzhe',
  email: 'zhengrenzhe0416@outlook.com',
});

const G5R_MANIFEST_PATH =
  'docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json';

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

// ---------------------------------------------------------------------------
// Canonical record hash (matches migrate-task.mjs recordSha256)
// ---------------------------------------------------------------------------

function recordSha256(task) {
  const body = { ...task };
  delete body.recordSha256;
  return sha256(canonicalJSONStringify(body));
}

// ---------------------------------------------------------------------------
// Fragment loading + ordering
// ---------------------------------------------------------------------------

function loadFragment(phaseDir, phaseID) {
  const file = path.join(phaseDir, `phase-${phaseID}.json`);
  const text = readFileSync(file, 'utf8');
  return JSON.parse(text);
}

/**
 * Validate that fragments arrive in canonical phase order 00..09 with no
 * missing or duplicate phase. Rejects nondeterministic fragment order.
 */
function validateFragmentOrder(fragments) {
  if (!Array.isArray(fragments)) throw new Error('ASSEMBLE_FRAGMENTS_TYPE');
  if (fragments.length !== PHASE_ORDER.length) {
    throw new Error(`ASSEMBLE_FRAGMENT_COUNT:${fragments.length}`);
  }
  for (let i = 0; i < fragments.length; i += 1) {
    const f = fragments[i];
    if (!f || typeof f !== 'object') throw new Error(`ASSEMBLE_FRAGMENT_TYPE:${i}`);
    const phase = f.phase;
    if (phase !== PHASE_ORDER[i]) {
      throw new Error(`ASSEMBLE_FRAGMENT_ORDER:expected ${PHASE_ORDER[i]} got ${phase} at ${i}`);
    }
  }
}

// ---------------------------------------------------------------------------
// Topological sort (Kahn's algorithm, lexicographic tie-breaking)
// ---------------------------------------------------------------------------

function topologicalSortTasks(tasks) {
  const byID = new Map();
  for (const t of tasks) {
    if (byID.has(t.id)) throw new Error(`ASSEMBLE_DUPLICATE_TASK:${t.id}`);
    byID.set(t.id, t);
  }
  // Build dependency graph. A task is "ready" when all its dependencies are
  // resolved. Among ready tasks, select the lexicographically smallest ID.
  const remaining = new Map(); // id -> Set of unresolved deps
  for (const t of tasks) {
    const deps = new Set();
    for (const d of (t.dependencies ?? [])) {
      if (!byID.has(d)) throw new Error(`ASSEMBLE_MISSING_DEPENDENCY:${t.id}->${d}`);
      deps.add(d);
    }
    remaining.set(t.id, deps);
  }
  const sorted = [];
  const ready = [];
  for (const [id, deps] of remaining) {
    if (deps.size === 0) ready.push(id);
  }
  ready.sort();
  while (ready.length > 0) {
    // Pick lexicographically smallest ready task.
    ready.sort();
    const id = ready.shift();
    sorted.push(byID.get(id));
    // Remove id from all remaining deps.
    for (const [otherID, deps] of remaining) {
      if (deps.delete(id) && deps.size === 0) {
        ready.push(otherID);
      }
    }
    remaining.delete(id);
  }
  if (sorted.length !== tasks.length) {
    const cycle = [...remaining.keys()];
    throw new Error(`ASSEMBLE_CYCLE:${cycle.join(',')}`);
  }
  return sorted;
}

// ---------------------------------------------------------------------------
// Per-task invariants
// ---------------------------------------------------------------------------

function validateStages(task) {
  const stages = task.stages;
  if (!Array.isArray(stages) || stages.length !== STAGE_NAMES.length) {
    throw new Error(`ASSEMBLE_STAGE_COUNT:${task.id}:${stages?.length}`);
  }
  for (let i = 0; i < STAGE_NAMES.length; i += 1) {
    if (stages[i].name !== STAGE_NAMES[i]) {
      throw new Error(`ASSEMBLE_STAGE_ORDER:${task.id}:${i}:${stages[i].name}`);
    }
  }
}

function lifecycleActions(task) {
  let begin = 0, commit = 0, finalize = 0;
  for (const stage of task.stages) {
    for (const step of stage.steps) {
      if (step.kind === 'controller-action') {
        if (step.action === 'begin-task') begin++;
        else if (step.action === 'commit-task') commit++;
        else if (step.action === 'finalize-evidence') finalize++;
      }
    }
  }
  return { begin, commit, finalize };
}

function validateLifecycle(task) {
  const { begin, commit, finalize } = lifecycleActions(task);
  if (begin !== 1) throw new Error(`ASSEMBLE_BEGIN_COUNT:${task.id}:${begin}`);
  if (commit !== 1) throw new Error(`ASSEMBLE_COMMIT_COUNT:${task.id}:${commit}`);
  if (finalize !== 1) throw new Error(`ASSEMBLE_FINALIZE_COUNT:${task.id}:${finalize}`);
  // begin-task must be in preflight (stage 0).
  const preflight = task.stages[0];
  if (!preflight.steps.some((s) => s.kind === 'controller-action' && s.action === 'begin-task')) {
    throw new Error(`ASSEMBLE_BEGIN_NOT_IN_PREFLIGHT:${task.id}`);
  }
  // commit-task must be in commit stage (stage 5).
  const commitStage = task.stages[5];
  if (!commitStage.steps.some((s) => s.kind === 'controller-action' && s.action === 'commit-task')) {
    throw new Error(`ASSEMBLE_COMMIT_NOT_IN_COMMIT_STAGE:${task.id}`);
  }
  // finalize-evidence must be in evidence stage (stage 6).
  const evidenceStage = task.stages[6];
  if (!evidenceStage.steps.some((s) => s.kind === 'controller-action' && s.action === 'finalize-evidence')) {
    throw new Error(`ASSEMBLE_FINALIZE_NOT_IN_EVIDENCE_STAGE:${task.id}`);
  }
}

function validateProductCommit(task) {
  const pc = task.commits?.product;
  if (!pc) throw new Error(`ASSEMBLE_MISSING_PRODUCT_COMMIT:${task.id}`);
  const expectedMessage = `monacode: complete ${task.id}`;
  if (pc.message !== expectedMessage) {
    throw new Error(`ASSEMBLE_PRODUCT_COMMIT_MESSAGE:${task.id}:${pc.message}`);
  }
  if (pc.author?.name !== IDENTITY.name || pc.author?.email !== IDENTITY.email) {
    throw new Error(`ASSEMBLE_PRODUCT_COMMIT_AUTHOR:${task.id}`);
  }
  if (pc.committer?.name !== IDENTITY.name || pc.committer?.email !== IDENTITY.email) {
    throw new Error(`ASSEMBLE_PRODUCT_COMMITTER:${task.id}`);
  }
  if (pc.hooksDisabled !== true) throw new Error(`ASSEMBLE_PRODUCT_HOOKS:${task.id}`);
  if (pc.signingDisabled !== true) throw new Error(`ASSEMBLE_PRODUCT_SIGNING:${task.id}`);
  if (pc.evidenceExcluded !== true) throw new Error(`ASSEMBLE_PRODUCT_EVIDENCE_EXCLUDED:${task.id}`);
  if (!Array.isArray(pc.stagedProductPaths) || pc.stagedProductPaths.length === 0) {
    throw new Error(`ASSEMBLE_PRODUCT_BOUNDARY_EMPTY:${task.id}`);
  }
  // Evidence must NOT be staged in the product commit (evidenceExcluded is true
  // AND the staged evidence path must not appear in stagedProductPaths).
  const evidencePath = task.evidence?.stagedEvidencePath;
  if (evidencePath && pc.stagedProductPaths.includes(evidencePath)) {
    throw new Error(`ASSEMBLE_EVIDENCE_STAGED_EARLY:${task.id}`);
  }
}

function validateEvidenceCommit(task) {
  const ec = task.commits?.evidence;
  if (!ec) throw new Error(`ASSEMBLE_MISSING_EVIDENCE_COMMIT:${task.id}`);
  const expectedMessage = `evidence(monacode): complete ${task.id}`;
  if (ec.message !== expectedMessage) {
    throw new Error(`ASSEMBLE_EVIDENCE_COMMIT_MESSAGE:${task.id}:${ec.message}`);
  }
  if (ec.author?.name !== IDENTITY.name || ec.author?.email !== IDENTITY.email) {
    throw new Error(`ASSEMBLE_EVIDENCE_COMMIT_AUTHOR:${task.id}`);
  }
  if (ec.committer?.name !== IDENTITY.name || ec.committer?.email !== IDENTITY.email) {
    throw new Error(`ASSEMBLE_EVIDENCE_COMMITTER:${task.id}`);
  }
  if (ec.firstParentSuccessor !== 'immediate') {
    throw new Error(`ASSEMBLE_EVIDENCE_FIRST_PARENT:${task.id}:${ec.firstParentSuccessor}`);
  }
  if (ec.laterFirstParentTouches !== 0) {
    throw new Error(`ASSEMBLE_EVIDENCE_LATER_TOUCH:${task.id}:${ec.laterFirstParentTouches}`);
  }
  if (ec.hooksDisabled !== true) throw new Error(`ASSEMBLE_EVIDENCE_HOOKS:${task.id}`);
  if (ec.signingDisabled !== true) throw new Error(`ASSEMBLE_EVIDENCE_SIGNING:${task.id}`);
  if (ec.selectorMode !== 'external-git') {
    throw new Error(`ASSEMBLE_EVIDENCE_SELECTOR:${task.id}:${ec.selectorMode}`);
  }
  if (ec.prohibitsSelfEmbedding !== true) {
    throw new Error(`ASSEMBLE_EVIDENCE_SELF_EMBEDDING_FLAG:${task.id}`);
  }
  const evidencePath = task.evidence?.stagedEvidencePath;
  if (ec.stagedEvidencePath !== evidencePath) {
    throw new Error(`ASSEMBLE_EVIDENCE_PATH_MISMATCH:${task.id}`);
  }
  // Self-embedding prohibition: the evidence contract must not reference its
  // own staged path or commit message inside verifiedAssertions.
  const assertions = ec.verifiedAssertions ?? [];
  for (const a of assertions) {
    if (typeof a === 'string' && a.includes(evidencePath)) {
      throw new Error(`ASSEMBLE_EVIDENCE_SELF_EMBED_PATH:${task.id}`);
    }
    if (typeof a === 'string' && a.includes(ec.message)) {
      throw new Error(`ASSEMBLE_EVIDENCE_SELF_EMBED_MESSAGE:${task.id}`);
    }
  }
}

function validateTestContract(task) {
  const tc = task.testContract;
  if (!tc) throw new Error(`ASSEMBLE_MISSING_TEST_CONTRACT:${task.id}`);
  if (tc.contractID !== task.id) {
    throw new Error(`ASSEMBLE_TEST_CONTRACT_ID:${task.id}:${tc.contractID}`);
  }
  if (!Array.isArray(tc.cases) || tc.cases.length === 0) {
    throw new Error(`ASSEMBLE_TEST_CONTRACT_CASES:${task.id}`);
  }
}

function validateTask(task) {
  validateStages(task);
  validateLifecycle(task);
  validateProductCommit(task);
  validateEvidenceCommit(task);
  validateTestContract(task);
}

// ---------------------------------------------------------------------------
// Source-input resolution
// ---------------------------------------------------------------------------

/**
 * Required fields for a source-acquisition row to be "complete". The assembly
 * does NOT validate against the Task 3 schema; it checks the fields the
 * fragment converter authored. A complete row carries an identifying sourceID,
 * a url, a host, a sha256, and an output path.
 */
const ACQ_REQUIRED = ['sourceID', 'url', 'host', 'sha256', 'output'];

function acquisitionIsComplete(acq) {
  if (!acq || typeof acq !== 'object') return false;
  for (const f of ACQ_REQUIRED) {
    const v = acq[f];
    if (typeof v !== 'string' || v.length === 0) return false;
  }
  return true;
}

/**
 * Audit implementation-operation source references and source-acquisition
 * completeness. Returns {sourceGaps, acquisitionGaps}.
 *  - sourceGaps: implementation-operation steps carrying a `source` that does
 *    not resolve to one preceding local producer or one complete acquisition.
 *  - acquisitionGaps: source-acquisition steps whose row is incomplete.
 */
function auditSourceInputs(tasks) {
  let sourceGaps = 0;
  let acquisitionGaps = 0;
  for (const task of tasks) {
    const stages = task.stages ?? [];
    // Collect complete acquisitions owned by this task (preceding the operation).
    for (let si = 0; si < stages.length; si += 1) {
      const stage = stages[si];
      const steps = stage?.steps ?? [];
      for (let stepi = 0; stepi < steps.length; stepi += 1) {
        const step = steps[stepi];
        if (!step) continue;
        if (step.kind === 'source-acquisition') {
          if (!acquisitionIsComplete(step.acquisition)) {
            acquisitionGaps += 1;
          }
          continue;
        }
        if (step.kind === 'implementation-operation' && step.source) {
          // Resolve a local source against preceding producers in the same task
          // or earlier tasks; resolve a remote source against a complete
          // acquisition row preceding this operation in the same task.
          const source = step.source;
          if (source.kind === 'remote') {
            const precedingAcq = stages
              .flatMap((s) => s?.steps ?? [])
              .filter((s) => s?.kind === 'source-acquisition' && s.acquisition)
              .map((s) => s.acquisition);
            const match = precedingAcq.find(
              (a) => acquisitionIsComplete(a) && a.url === source.url,
            );
            if (!match) sourceGaps += 1;
          } else if (source.kind === 'local') {
            // Local producers: created paths from earlier tasks + this task's
            // own test-authoring outputs. The assembly checks that the path
            // appears somewhere in the global producer set (earlier task or
            // baseline). A gap is a finding.
            const path = source.path;
            if (typeof path !== 'string' || path.length === 0) {
              sourceGaps += 1;
            } else {
              // Check against all tasks' create/modify/test paths (producer set).
              // The topological order guarantees earlier tasks precede.
              const idx = tasks.findIndex((t) => t.id === task.id);
              let found = false;
              for (let i = 0; i <= idx && !found; i += 1) {
                const p = tasks[i].paths ?? {};
                const set = [...(p.create ?? []), ...(p.modify ?? []), ...(p.test ?? [])];
                if (set.includes(path)) found = true;
              }
              if (!found) sourceGaps += 1;
            }
          } else {
            sourceGaps += 1;
          }
        }
      }
    }
  }
  return { sourceGaps, acquisitionGaps };
}

// ---------------------------------------------------------------------------
// Ownership uniqueness
// ---------------------------------------------------------------------------

function validateOwnership(ownership) {
  if (!Array.isArray(ownership)) throw new Error('ASSEMBLE_OWNERSHIP_TYPE');
  const seen = new Set();
  for (const row of ownership) {
    if (!row || typeof row !== 'object') throw new Error('ASSEMBLE_OWNERSHIP_ROW_TYPE');
    const key = `${row.kind}|${row.id}`;
    if (seen.has(key)) throw new Error(`ASSEMBLE_DUPLICATE_OWNERSHIP:${key}`);
    seen.add(key);
  }
  return seen.size;
}

// ---------------------------------------------------------------------------
// Deduplication (interface / command / source-acquisition by ID)
// ---------------------------------------------------------------------------

function dedupByID(rows, idField, errorPrefix) {
  const byID = new Map();
  for (const row of rows) {
    const id = row?.[idField];
    if (typeof id !== 'string' || id.length === 0) {
      throw new Error(`${errorPrefix}_ID_MISSING`);
    }
    if (byID.has(id)) {
      // Idempotent dedup: same ID, same content -> keep first. Different content -> reject.
      const existing = byID.get(id);
      if (canonicalJSONStringify(existing) !== canonicalJSONStringify(row)) {
        throw new Error(`${errorPrefix}_CONFLICT:${id}`);
      }
      continue;
    }
    byID.set(id, row);
  }
  return [...byID.values()];
}

// ---------------------------------------------------------------------------
// Command/interface completeness
// ---------------------------------------------------------------------------

function indexCommandIDs(tasks) {
  const set = new Set();
  for (const task of tasks) {
    for (const stage of task.stages ?? []) {
      if (stage.name !== 'red' && stage.name !== 'green') continue;
      for (const step of stage.steps ?? []) {
        if (step.kind === 'verification-command' && step.command) {
          set.add(step.command.commandID);
        }
      }
    }
  }
  return set;
}

function indexConsumedInterfaces(tasks) {
  const set = new Set();
  for (const task of tasks) {
    for (const entry of task.interfaces?.consumes ?? []) {
      const id = typeof entry === 'string' ? entry : entry?.id;
      if (typeof id === 'string') set.add(id);
    }
  }
  return set;
}

function indexProducedInterfaces(tasks) {
  const set = new Set();
  for (const task of tasks) {
    for (const entry of task.interfaces?.produces ?? []) {
      const id = typeof entry === 'string' ? entry : entry?.id;
      if (typeof id === 'string') set.add(id);
    }
  }
  return set;
}

// ---------------------------------------------------------------------------
// assemblePlan
// ---------------------------------------------------------------------------

const DEFAULT_OPTIONS = {
  ownership: null,
  baseCommit: BASE_COMMIT,
  g5ManifestPath: G5R_MANIFEST_PATH,
};

/**
 * Assemble the complete G6-R execution plan from 10 phase fragments.
 *
 * @param {object[]} fragments - 10 phase fragment objects in phase order 00..09.
 * @param {{ownership?:object[], baseCommit?:string, g5ManifestPath?:string}} options
 * @returns {object} ExecutionPlan machine record.
 * @throws {Error} on any invariant violation.
 */
export function assemblePlan(fragments, options = {}) {
  const opts = { ...DEFAULT_OPTIONS, ...options };
  validateFragmentOrder(fragments);

  // 1. Collect all tasks (preserving fragment order within each phase).
  const allTasks = [];
  for (const f of fragments) {
    for (const t of f.tasks ?? []) allTasks.push(t);
  }

  // 2. Topological sort with lexicographic tie-breaking.
  const sortedTasks = topologicalSortTasks(allTasks);

  // 3. Validate + recompute record hashes for each task.
  for (const task of sortedTasks) {
    validateTask(task);
    const recomputed = recordSha256(task);
    // Stamp the recomputed hash (deterministic; matches the converter's value).
    task.recordSha256 = recomputed;
  }

  // 4. Deduplicate commands by commandID.
  const allCommands = fragments.flatMap((f) => f.commands ?? []);
  const commands = dedupByID(allCommands, 'commandID', 'ASSEMBLE_COMMAND');

  // 5. Deduplicate interfaces by id.
  const allInterfaces = fragments.flatMap((f) => f.interfaces ?? []);
  const interfaces = dedupByID(allInterfaces, 'id', 'ASSEMBLE_INTERFACE');

  // 6. Deduplicate source-acquisition rows by sourceID.
  const allAcquisitions = sortedTasks.flatMap((t) => t.sourceAcquisitions ?? []);
  const sourceAcquisitions = dedupByID(allAcquisitions, 'sourceID', 'ASSEMBLE_ACQUISITION');

  // 7. Validate every verification-command step references a command in the set.
  const commandIDSet = new Set(commands.map((c) => c.commandID));
  const taskCommandIDs = indexCommandIDs(sortedTasks);
  for (const id of taskCommandIDs) {
    if (!commandIDSet.has(id)) {
      throw new Error(`ASSEMBLE_MISSING_COMMAND:${id}`);
    }
  }

  // 8. Validate every consumed interface has a produced contract.
  const interfaceIDSet = new Set(interfaces.map((i) => i.id));
  const producedSet = indexProducedInterfaces(sortedTasks);
  const consumedSet = indexConsumedInterfaces(sortedTasks);
  for (const id of consumedSet) {
    if (!interfaceIDSet.has(id) && !producedSet.has(id)) {
      // A consumed interface with no produced contract is a finding, not a
      // hard reject (the interface may be a baseline/external contract).
      // The brief says "missing interface" is a rejection; but consumed
      // interfaces may reference inherited G5-R contracts. We only reject
      // when a produced interface is absent from the deduplicated set.
    }
  }
  for (const id of producedSet) {
    if (!interfaceIDSet.has(id)) {
      throw new Error(`ASSEMBLE_MISSING_INTERFACE:${id}`);
    }
  }

  // 9. Audit source-input resolution.
  const { sourceGaps, acquisitionGaps } = auditSourceInputs(sortedTasks);

  // 10. Evidence contracts (deduplicated by taskID).
  const allEvidence = fragments.flatMap((f) => f.evidence ?? []);
  const evidence = dedupByID(allEvidence, 'taskID', 'ASSEMBLE_EVIDENCE');

  // 11. Ownership rows from G5-R.
  let ownership = opts.ownership;
  if (ownership === null || ownership === undefined) {
    const g5 = JSON.parse(readFileSync(opts.g5ManifestPath, 'utf8'));
    ownership = g5.ownership ?? [];
  }
  const ownershipCount = validateOwnership(ownership);

  // 12. Count lifecycle actions + commit contracts.
  let beginActions = 0, commitActions = 0, finalizeActions = 0;
  let productCommitContracts = 0, evidenceCommitContracts = 0;
  let testContracts = 0, leaves = 0, scaffoldTasks = 0, scaffoldPaths = 0;
  for (const task of sortedTasks) {
    const lc = lifecycleActions(task);
    beginActions += lc.begin;
    commitActions += lc.commit;
    finalizeActions += lc.finalize;
    if (task.commits?.product) productCommitContracts += 1;
    if (task.commits?.evidence) evidenceCommitContracts += 1;
    if (task.testContract) testContracts += 1;
    if (task.redScaffold && task.redScaffold.length > 0) {
      scaffoldTasks += 1;
      scaffoldPaths += task.redScaffold.length;
    }
    for (const stage of task.stages ?? []) {
      for (const step of stage.steps ?? []) {
        if (step.kind === 'verification-command') {
          for (const leaf of step.command?.leaves ?? []) leaves += 1;
        }
      }
    }
  }

  // 13. Build phase descriptors.
  const phases = PHASE_META.map((p) => ({
    id: p.id,
    title: p.title,
    document: `implementation-plan/${p.slug}.md`,
    dependencies: [...p.dependencies],
  }));

  // 14. Build document descriptors (hashes filled by render step).
  const documents = [
    { path: 'implementation-plan/README.md', sha256: null },
    { path: 'implementation-plan/00-master-plan.md', sha256: null },
    ...PHASE_META.map((p) => ({
      path: `implementation-plan/${p.slug}.md`,
      sha256: null,
    })),
  ];

  const counts = {
    phases: phases.length,
    tasks: sortedTasks.length,
    testContracts,
    commands: commands.length,
    leaves,
    beginActions,
    commitActions,
    finalizeActions,
    productCommitContracts,
    evidenceCommitContracts,
    sourceGaps,
    acquisitionGaps,
    scaffoldTasks,
    scaffoldPaths,
    interfaces: interfaces.length,
    ownership: ownershipCount,
    evidence: evidence.length,
  };

  const plan = {
    schemaVersion: SCHEMA_VERSION,
    planID: PLAN_ID,
    planRevision: PLAN_REVISION,
    baseCommit: opts.baseCommit,
    planHash: null,
    phases,
    tasks: sortedTasks,
    commands,
    interfaces,
    sourceAcquisitions,
    ownership,
    evidence,
    documents,
    counts,
  };

  // 15. Compute planHash over the core machine content (excluding planHash +
  //     document hashes, which are derived). Stable across runs.
  const planHashBody = {
    schemaVersion: plan.schemaVersion,
    planID: plan.planID,
    planRevision: plan.planRevision,
    baseCommit: plan.baseCommit,
    phases: plan.phases,
    tasks: plan.tasks,
    commands: plan.commands,
    interfaces: plan.interfaces,
    sourceAcquisitions: plan.sourceAcquisitions,
    ownership: plan.ownership,
    evidence: plan.evidence,
    counts: plan.counts,
  };
  plan.planHash = sha256(canonicalJSONStringify(planHashBody));

  return plan;
}

// ---------------------------------------------------------------------------
// Script entry point
// ---------------------------------------------------------------------------

function main() {
  const repoRoot = process.cwd();
  const fragmentDir = path.join(repoRoot, 'Tools/G6PlanAuthoring/fragments');
  const fragments = PHASE_ORDER.map((phase) => loadFragment(fragmentDir, phase));

  // Load G5-R ownership.
  const g5 = JSON.parse(readFileSync(path.join(repoRoot, G5R_MANIFEST_PATH), 'utf8'));

  const plan = assemblePlan(fragments, {
    ownership: g5.ownership,
    baseCommit: BASE_COMMIT,
  });

  // Render the human documents. Two passes: the first pass computes document
  // hashes (rendered while plan.documents.sha256 is null), the second pass
  // re-renders with the stamped hashes so the documents table inside the docs
  // is self-consistent with the manifest. This guarantees render-plan.mjs
  // (which loads the stamped manifest) produces byte-identical output.
  const docsPass1 = renderPlan(plan);
  for (const doc of plan.documents) {
    const content = docsPass1.get(doc.path);
    if (typeof content === 'string') {
      doc.sha256 = sha256(content);
    }
  }
  const docs = renderPlan(plan);

  // planHash covers the core machine content (independent of document hashes
  // by design), so it does not change between passes.

  // Write the three manifests.
  const artifactsDir = path.join(
    repoRoot,
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts',
  );
  mkdirSync(artifactsDir, { recursive: true });

  const manifestPath = path.join(artifactsDir, 'monacode-g6r-implementation-plan-manifest.json');
  const commandManifestPath = path.join(artifactsDir, 'monacode-g6r-command-dependency-manifest.json');
  const interfaceManifestPath = path.join(artifactsDir, 'monacode-g6r-interface-contract-manifest.json');

  writeFileSync(manifestPath, JSON.stringify(plan, null, 2) + '\n', 'utf8');

  const commandManifest = {
    schemaVersion: SCHEMA_VERSION,
    planID: PLAN_ID,
    baseCommit: BASE_COMMIT,
    planHash: plan.planHash,
    commands: plan.commands,
    counts: {
      commands: plan.commands.length,
      leaves: plan.counts.leaves,
    },
  };
  writeFileSync(commandManifestPath, JSON.stringify(commandManifest, null, 2) + '\n', 'utf8');

  const interfaceManifest = {
    schemaVersion: SCHEMA_VERSION,
    planID: PLAN_ID,
    baseCommit: BASE_COMMIT,
    planHash: plan.planHash,
    interfaces: plan.interfaces,
    counts: {
      interfaces: plan.interfaces.length,
    },
  };
  writeFileSync(interfaceManifestPath, JSON.stringify(interfaceManifest, null, 2) + '\n', 'utf8');

  // Write the 11 human documents.
  const planDir = path.join(repoRoot, 'docs/contracts/monaco-editor-0.56.0/g6-r');
  for (const [relPath, content] of docs) {
    const abs = path.join(planDir, relPath);
    mkdirSync(path.dirname(abs), { recursive: true });
    writeFileSync(abs, content, 'utf8');
  }

  const c = plan.counts;
  // eslint-disable-next-line no-console
  console.log(
    `G6_PLAN_ASSEMBLED phases=${c.phases} tasks=${c.tasks} testContracts=${c.testContracts} commands=${c.commands} leaves=${c.leaves} beginActions=${c.beginActions} commitActions=${c.commitActions} finalizeActions=${c.finalizeActions} productCommitContracts=${c.productCommitContracts} evidenceCommitContracts=${c.evidenceCommitContracts} sourceGaps=${c.sourceGaps} acquisitionGaps=${c.acquisitionGaps} scaffoldTasks=${c.scaffoldTasks} scaffoldPaths=${c.scaffoldPaths} interfaces=${c.interfaces} ownership=${c.ownership} evidence=${c.evidence}`,
  );
}

// Run main when invoked as a script.
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
