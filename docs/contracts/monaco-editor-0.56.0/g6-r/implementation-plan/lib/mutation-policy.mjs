// G6-R command and task mutation-policy enforcement.
// Repository-owned, dependency-free. Binds every G6-R task stage to a bounded
// allowlist of paths it may mutate:
//   begin-task        -> evidence path + .g6-beginning journal + token-owned task root
//   test-authoring    -> declared tests/fixtures/checkers + Red-scaffold paths
//   red/green leaves  -> the parent record's declared command child
//                        (scratch path under /tmp/monacode-planctl/<leafID>)
//   implementation    -> task file rows + declared source-acquisition paths +
//                        scaffold replacements
//   commit            -> exact product commit boundary + .g6-committing journal +
//                        running evidence (never the evidence path itself)
//   evidence          -> evidence path + .g6-part/.g6-finalizing journals +
//                        token-owned root/tombstone + Git index/history for the
//                        single evidence-only commit
// Closes the "unbounded repository mutation" class of execution-readiness gaps.
// auditMutationPolicy audits the task structure; compareObservedMutations audits
// an observed set of mutated paths against a declared MutationPolicy. Both
// return a deterministically sorted Finding[] and never throw for data errors.

import { makeFinding, sortFindings } from './findings.mjs';

// Canonical G6-R stage order (mirrors schema.mjs STAGE_NAMES).
const STAGE_ORDER = [
  'preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence',
];

const JOURNAL_PREFIX = '.g6-';
const SCRATCH_ROOT = '/tmp/monacode-planctl';

/**
 * Finding IDs emitted by this module. These are NOT in the FINDING_IDS list
 * from lib/findings.mjs (Task 3); sortFindings places unknown IDs after all
 * declared IDs, preserving insertion order among themselves (stable sort).
 */
export const MUTATION_FINDING_IDS = [
  'PLAN_REPOSITORY_MUTATION_UNDECLARED',
  'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT',
  'PLAN_EVIDENCE_JOURNAL_STATE',
  'PLAN_EVIDENCE_COMMIT_BOUNDARY',
  'PLAN_ALL_SUCCESS_ORDER',
  'PLAN_PIPELINE_STATUS',
  'PLAN_RED_SCAFFOLD_MUTATION',
];

const isObj = (v) => v !== null && typeof v === 'object';
const isStr = (v) => typeof v === 'string' && v.length > 0;
const isArr = (v) => Array.isArray(v);

// ---------------------------------------------------------------------------
// Path normalization
// ---------------------------------------------------------------------------

/**
 * Normalize a path: collapse '.' segments and duplicate slashes, strip a
 * trailing slash. Rejects NUL bytes and any '..' segment (parent traversal /
 * symlink escape). Accepts both repo-relative and absolute paths. Returns the
 * normalized path, or null if the path is empty, carries a traversal segment,
 * or is otherwise invalid. Absolute repository paths are rejected downstream
 * by compareObservedMutations when they fall outside a declared temporary root.
 * @param {unknown} p
 * @returns {string|null}
 */
export function normalizePath(p) {
  if (typeof p !== 'string' || p.length === 0) return null;
  if (p.includes('\0')) return null;
  const isAbs = p.startsWith('/');
  const segs = [];
  for (const raw of p.split('/')) {
    if (raw === '' || raw === '.') continue;
    if (raw === '..') return null; // reject parent traversal / symlink escape
    segs.push(raw);
  }
  if (segs.length === 0) return null;
  return (isAbs ? '/' : '') + segs.join('/');
}

/**
 * Normalize, deduplicate, and sort an array of paths. Drops null results.
 * @param {string[]} paths
 * @returns {string[]}
 */
function cleanPaths(paths) {
  const set = new Set();
  for (const p of paths) {
    const n = normalizePath(p);
    if (n !== null) set.add(n);
  }
  return [...set].sort();
}

function scratchPathFor(leafID) {
  return `${SCRATCH_ROOT}/${leafID}`;
}

/**
 * Does path `p` live under the temporary root `root`? Both must be absolute.
 * A root is a directory: the root itself and anything beneath it is allowed.
 * @param {string} p
 * @param {string} root
 * @returns {boolean}
 */
function underRoot(p, root) {
  return p === root || p.startsWith(root + '/');
}

/**
 * Do two temporary roots overlap (one is a prefix of the other)? This is the
 * "overlapping wildcard policies" rejection: two recursive prefix roots that
 * shadow each other.
 * @param {string} a
 * @param {string} b
 * @returns {boolean}
 */
function rootsOverlap(a, b) {
  if (a === b) return true;
  return a.startsWith(b + '/') || b.startsWith(a + '/');
}

// ---------------------------------------------------------------------------
// MutationPolicy record
// ---------------------------------------------------------------------------

/**
 * @typedef {Object} MutationPolicy
 * @property {string} stage - G6-R stage name.
 * @property {string|null} taskID - Owning task ID.
 * @property {string[]} allowed - Repo-relative paths this stage may mutate
 *   (normalized, deduplicated, sorted).
 * @property {string[]} temporaryRoots - Absolute path prefixes for temporary
 *   mutations (normalized, deduplicated, sorted).
 * @property {string[]} journals - Allowed journal-state names (.g6-*).
 * @property {string|null} evidencePath - The evidence path (commit/evidence).
 * @property {string|null} commandID - The verification command ID (red/green).
 */

// ---------------------------------------------------------------------------
// Path collectors
// ---------------------------------------------------------------------------

function casePaths(tc) {
  const out = [];
  if (!isObj(tc) || !isArr(tc.cases)) return out;
  for (const c of tc.cases) {
    if (!isObj(c)) continue;
    if (isObj(c.file) && isStr(c.file.path)) out.push(c.file.path);
    if (isObj(c.fixtures) && c.fixtures.kind === 'path' && isStr(c.fixtures.path)) out.push(c.fixtures.path);
    // A checker may be a toolchain name (swift-test) or a script path.
    if (isStr(c.checker) && (c.checker.includes('/') || /\.(mjs|swift)$/.test(c.checker))) {
      out.push(c.checker);
    }
  }
  return out;
}

function implementationPaths(task) {
  const out = [];
  const stages = isArr(task.stages) ? task.stages : [];
  for (const s of stages) {
    if (!isObj(s) || s.name !== 'implementation') continue;
    const steps = isArr(s.steps) ? s.steps : [];
    for (const step of steps) {
      if (!isObj(step)) continue;
      if (step.kind === 'implementation-operation') {
        if (isArr(step.modifies)) for (const p of step.modifies) if (isStr(p)) out.push(p);
        if (isArr(step.creates)) for (const p of step.creates) if (isStr(p)) out.push(p);
      }
      if (step.kind === 'source-acquisition' && isObj(step.acquisition) && isStr(step.acquisition.outputPath)) {
        out.push(step.acquisition.outputPath);
      }
    }
  }
  // Scaffold replacement: the redScaffold sourcePath is replaced by implementation.
  if (isObj(task.redScaffold) && isStr(task.redScaffold.sourcePath)) out.push(task.redScaffold.sourcePath);
  return out;
}

function hasTemporaryAcquisition(task) {
  const stages = isArr(task.stages) ? task.stages : [];
  for (const s of stages) {
    if (!isObj(s) || s.name !== 'implementation') continue;
    const steps = isArr(s.steps) ? s.steps : [];
    for (const step of steps) {
      if (isObj(step) && step.kind === 'source-acquisition' &&
          isObj(step.acquisition) && step.acquisition.disposition === 'temporary') {
        return true;
      }
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// buildMutationPolicies — derive the per-stage bounded allowlists from a task
// ---------------------------------------------------------------------------

/**
 * Build one MutationPolicy per stage (plus one per red/green verification
 * command) from a task record. Paths are normalized, deduplicated, and sorted.
 * @param {unknown} task
 * @returns {MutationPolicy[]}
 */
export function buildMutationPolicies(task) {
  if (!isObj(task)) return [];
  const taskID = isStr(task.taskID) ? task.taskID : null;
  const stages = isArr(task.stages) ? task.stages : [];
  const byName = {};
  for (const s of stages) if (isObj(s) && isStr(s.name)) byName[s.name] = s;

  const ws = isObj(task.workspace) ? task.workspace : {};
  const taskRoot = isStr(ws.taskRoot) ? ws.taskRoot : null;
  const ec = isObj(task.evidenceCommit) ? task.evidenceCommit : {};
  const evidencePath = isStr(ec.stagedEvidencePath) ? ec.stagedEvidencePath : null;
  const pc = isObj(task.productCommit) ? task.productCommit : {};
  const stagedProduct = isArr(pc.stagedProductPaths) ? pc.stagedProductPaths.filter(isStr) : [];
  const rs = isObj(task.redScaffold) ? task.redScaffold : null;
  const scaffoldPath = rs && isStr(rs.sourcePath) ? rs.sourcePath : null;
  const tc = isObj(task.testContract) ? task.testContract : null;

  const policies = [];

  // preflight (begin-task): evidence path + .g6-beginning + token-owned task root.
  policies.push({
    stage: 'preflight',
    taskID,
    allowed: evidencePath ? [evidencePath] : [],
    temporaryRoots: taskRoot ? [taskRoot] : [],
    journals: ['.g6-beginning'],
    evidencePath,
    commandID: null,
  });

  // test-authoring: declared tests/fixtures/checkers + Red-scaffold paths.
  const taAllowed = [...casePaths(tc)];
  if (scaffoldPath) taAllowed.push(scaffoldPath);
  policies.push({
    stage: 'test-authoring',
    taskID,
    allowed: cleanPaths(taAllowed),
    temporaryRoots: [],
    journals: ['.g6-part'],
    evidencePath: null,
    commandID: null,
  });

  // red / green: each process leaf mutates only its declared command child
  // (the scratch path under /tmp/monacode-planctl/<leafID>). Policies are
  // emitted in canonical stage order: red precedes implementation precedes green.
  const verificationPolicyFor = (stageName) => {
    const stage = byName[stageName];
    if (!isObj(stage)) return;
    const steps = isArr(stage.steps) ? stage.steps : [];
    for (const step of steps) {
      if (!isObj(step) || step.kind !== 'verification-command') continue;
      const cmd = isObj(step.command) ? step.command : {};
      const commandID = isStr(cmd.commandID) ? cmd.commandID : null;
      const leaves = isArr(cmd.leaves) ? cmd.leaves : [];
      const roots = [];
      for (const l of leaves) {
        if (isObj(l) && isStr(l.leafID)) roots.push(scratchPathFor(l.leafID));
      }
      policies.push({
        stage: stageName,
        taskID,
        allowed: [],
        temporaryRoots: cleanPaths(roots),
        journals: ['.g6-part'],
        evidencePath: null,
        commandID,
      });
    }
  };
  verificationPolicyFor('red');

  // implementation: task file rows + declared source-acquisition paths +
  // scaffold replacements. A temporary-disposition acquisition also mutates
  // under the token-owned task root.
  policies.push({
    stage: 'implementation',
    taskID,
    allowed: cleanPaths(implementationPaths(task)),
    temporaryRoots: (taskRoot && hasTemporaryAcquisition(task)) ? [taskRoot] : [],
    journals: ['.g6-part'],
    evidencePath: null,
    commandID: null,
  });

  verificationPolicyFor('green');

  // commit: exact product commit boundary + .g6-committing journal + running
  // evidence (never the evidence path itself).
  policies.push({
    stage: 'commit',
    taskID,
    allowed: cleanPaths([...stagedProduct]),
    temporaryRoots: [],
    journals: ['.g6-committing'],
    evidencePath,
    commandID: null,
  });

  // evidence finalization: evidence path + .g6-part/.g6-finalizing journals +
  // token-owned root/tombstone + Git index/history for the single evidence-only commit.
  policies.push({
    stage: 'evidence',
    taskID,
    allowed: evidencePath ? [evidencePath] : [],
    temporaryRoots: taskRoot ? [taskRoot] : [],
    journals: ['.g6-part', '.g6-finalizing'],
    evidencePath,
    commandID: null,
  });

  return policies;
}

// ---------------------------------------------------------------------------
// auditMutationPolicy — structural audits over the task record
// ---------------------------------------------------------------------------

/**
 * Audit a task record for mutation-policy structural defects. Returns a
 * deterministically sorted Finding[] and never throws for data errors.
 *
 * Emitted findings:
 *  - PLAN_EVIDENCE_COMMIT_BOUNDARY: evidence/journal paths enter the product
 *    commit boundary, or the evidence path is itself a journal path.
 *  - PLAN_ALL_SUCCESS_ORDER: an all-success command's leafIDs are not ascending
 *    (it would not stop deterministically after the first non-zero leaf).
 *  - PLAN_PIPELINE_STATUS: a pipeline lacks pipefail or fails to report a leaf.
 *  - PLAN_RED_SCAFFOLD_MUTATION: scaffold createOwner/replacementOwner are wrong.
 *  - PLAN_EVIDENCE_JOURNAL_STATE: a controller action sets the wrong journal.
 * @param {unknown} task
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function auditMutationPolicy(task) {
  const findings = [];
  if (!isObj(task)) return sortFindings(findings);
  const taskID = isStr(task.taskID) ? task.taskID : null;

  const stages = isArr(task.stages) ? task.stages : [];
  const byName = {};
  for (const s of stages) if (isObj(s) && isStr(s.name)) byName[s.name] = s;

  // --- PLAN_EVIDENCE_COMMIT_BOUNDARY ---
  // The product commit boundary must exclude evidence and journal paths; the
  // evidence commit diff must contain exactly the evidence path (never a
  // product or journal path).
  const ec = isObj(task.evidenceCommit) ? task.evidenceCommit : {};
  const pc = isObj(task.productCommit) ? task.productCommit : {};
  const evidencePath = isStr(ec.stagedEvidencePath) ? ec.stagedEvidencePath : null;
  const stagedProduct = isArr(pc.stagedProductPaths) ? pc.stagedProductPaths.filter(isStr) : [];

  for (const sp of stagedProduct) {
    if (evidencePath && sp === evidencePath) {
      findings.push(makeFinding({
        id: 'PLAN_EVIDENCE_COMMIT_BOUNDARY', category: 'semantic', taskID,
        path: '/productCommit/stagedProductPaths',
        message: `evidence path "${sp}" must not enter the product commit boundary`,
      }));
    }
    if (typeof sp === 'string' && sp.startsWith(JOURNAL_PREFIX)) {
      findings.push(makeFinding({
        id: 'PLAN_EVIDENCE_COMMIT_BOUNDARY', category: 'semantic', taskID,
        path: '/productCommit/stagedProductPaths',
        message: `journal path "${sp}" must not enter the product commit boundary`,
      }));
    }
  }
  if (evidencePath && evidencePath.startsWith(JOURNAL_PREFIX)) {
    findings.push(makeFinding({
      id: 'PLAN_EVIDENCE_COMMIT_BOUNDARY', category: 'semantic', taskID,
      path: '/evidenceCommit',
      message: `evidence path "${evidencePath}" must not be a journal path`,
    }));
  }

  // --- PLAN_ALL_SUCCESS_ORDER ---
  // all-success leafIDs must be strictly ascending so the command stops after
  // its first non-zero leaf.
  for (const stageName of ['red', 'green']) {
    const stage = byName[stageName];
    if (!isObj(stage)) continue;
    const steps = isArr(stage.steps) ? stage.steps : [];
    for (let si = 0; si < steps.length; si++) {
      const step = steps[si];
      if (!isObj(step) || step.kind !== 'verification-command') continue;
      const cmd = isObj(step.command) ? step.command : {};
      if (cmd.kind !== 'all-success') continue;
      const leaves = isArr(cmd.leaves) ? cmd.leaves : [];
      for (let i = 1; i < leaves.length; i++) {
        const a = leaves[i - 1] && leaves[i - 1].leafID;
        const b = leaves[i] && leaves[i].leafID;
        if (typeof a !== 'string' || typeof b !== 'string' || !(b > a)) {
          findings.push(makeFinding({
            id: 'PLAN_ALL_SUCCESS_ORDER', category: 'semantic', taskID,
            path: `/stages/${stageName}/steps/${si}/command`,
            message: `all-success leafIDs must be ascending to stop after the first non-zero leaf at index ${i}`,
          }));
          break;
        }
      }
    }
  }

  // --- PLAN_PIPELINE_STATUS ---
  // Pipelines must carry pipefail: true and report every leaf.
  for (const stageName of ['red', 'green']) {
    const stage = byName[stageName];
    if (!isObj(stage)) continue;
    const steps = isArr(stage.steps) ? stage.steps : [];
    for (let si = 0; si < steps.length; si++) {
      const step = steps[si];
      if (!isObj(step) || step.kind !== 'verification-command') continue;
      const cmd = isObj(step.command) ? step.command : {};
      if (cmd.kind !== 'pipeline') continue;
      if (cmd.pipefail !== true) {
        findings.push(makeFinding({
          id: 'PLAN_PIPELINE_STATUS', category: 'semantic', taskID,
          path: `/stages/${stageName}/steps/${si}/command`,
          message: 'pipeline must carry pipefail: true and aggregate every leaf status',
        }));
      }
      const leaves = isArr(cmd.leaves) ? cmd.leaves : [];
      for (let i = 0; i < leaves.length; i++) {
        if (!isObj(leaves[i]) || !isStr(leaves[i].leafID)) {
          findings.push(makeFinding({
            id: 'PLAN_PIPELINE_STATUS', category: 'semantic', taskID,
            path: `/stages/${stageName}/steps/${si}/command/leaves/${i}`,
            message: 'pipeline must report every leaf',
          }));
        }
      }
    }
  }

  // --- PLAN_RED_SCAFFOLD_MUTATION ---
  // The Red scaffold sourcePath is the only allowed scaffold mutation; its
  // createOwner must be test-authoring and its replacementOwner implementation.
  const rs = isObj(task.redScaffold) ? task.redScaffold : null;
  if (rs) {
    if (rs.createOwner !== 'test-authoring') {
      findings.push(makeFinding({
        id: 'PLAN_RED_SCAFFOLD_MUTATION', category: 'semantic', taskID,
        path: '/redScaffold',
        message: `red scaffold createOwner must be test-authoring, got ${String(rs.createOwner)}`,
      }));
    }
    if (rs.replacementOwner !== 'implementation') {
      findings.push(makeFinding({
        id: 'PLAN_RED_SCAFFOLD_MUTATION', category: 'semantic', taskID,
        path: '/redScaffold',
        message: `red scaffold replacementOwner must be implementation, got ${String(rs.replacementOwner)}`,
      }));
    }
  }

  // --- PLAN_EVIDENCE_JOURNAL_STATE ---
  // Each controller-action stage must set the correct journal state via the
  // correct action.
  const expectAction = (stageName, action, journal, msg) => {
    const stage = byName[stageName];
    if (!isObj(stage)) return;
    const steps = isArr(stage.steps) ? stage.steps : [];
    if (steps.length !== 1 || !isObj(steps[0]) ||
        steps[0].kind !== 'controller-action' || steps[0].action !== action) {
      findings.push(makeFinding({
        id: 'PLAN_EVIDENCE_JOURNAL_STATE', category: 'semantic', taskID,
        path: `/stages/${stageName}`,
        message: msg,
      }));
    }
  };
  expectAction('preflight', 'begin-task', '.g6-beginning',
    'preflight must set journal state .g6-beginning via begin-task');
  expectAction('commit', 'commit-task', '.g6-committing',
    'commit must set journal state .g6-committing via commit-task');
  expectAction('evidence', 'finalize-evidence', '.g6-finalizing',
    'evidence must set journal state .g6-finalizing via finalize-evidence');

  return sortFindings(findings);
}

// ---------------------------------------------------------------------------
// compareObservedMutations — observed-path leakage against a declared policy
// ---------------------------------------------------------------------------

/**
 * Compare an observed set of mutated paths against a declared MutationPolicy.
 * Returns a deterministically sorted Finding[] for every observed path outside
 * the policy's allowlist. Never throws for data errors.
 *
 * Emitted findings:
 *  - PLAN_REPOSITORY_MUTATION_UNDECLARED: a repo-relative observed path (or one
 *    that rejects normalization: parent traversal, NUL, empty) is not in the
 *    declared allowed set.
 *  - PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT: an absolute observed path is not
 *    under any declared temporary root, or the policy carries overlapping
 *    temporary-root prefixes.
 *  - PLAN_EVIDENCE_JOURNAL_STATE: an observed .g6-* journal path is not in the
 *    policy's allowed journal states.
 *
 * @param {unknown} policy
 * @param {unknown} observedPaths
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function compareObservedMutations(policy, observedPaths) {
  const findings = [];
  if (!isObj(policy)) {
    findings.push(makeFinding({
      id: 'PLAN_REPOSITORY_MUTATION_UNDECLARED', category: 'structure',
      taskID: null, path: '',
      message: 'policy must be a MutationPolicy object',
    }));
    return sortFindings(findings);
  }
  const taskID = (policy.taskID !== undefined && policy.taskID !== null) ? policy.taskID : null;
  const stage = isStr(policy.stage) ? policy.stage : '<unknown>';

  const allowed = new Set(
    (isArr(policy.allowed) ? policy.allowed : [])
      .map(normalizePath)
      .filter((p) => p !== null),
  );
  const tempRoots = (isArr(policy.temporaryRoots) ? policy.temporaryRoots : [])
    .map(normalizePath)
    .filter((p) => p !== null);
  const journals = new Set(isArr(policy.journals) ? policy.journals : []);

  // Reject overlapping wildcard policies (two recursive prefix roots that
  // shadow each other). This is a policy defect surfaced before observation.
  for (let i = 0; i < tempRoots.length; i++) {
    for (let j = i + 1; j < tempRoots.length; j++) {
      if (rootsOverlap(tempRoots[i], tempRoots[j])) {
        findings.push(makeFinding({
          id: 'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT', category: 'semantic', taskID,
          path: tempRoots[i] < tempRoots[j] ? tempRoots[i] : tempRoots[j],
          message: `overlapping temporary root policies: ${tempRoots[i]} overlaps ${tempRoots[j]}`,
        }));
      }
    }
  }

  const observed = isArr(observedPaths) ? observedPaths : [];
  for (const raw of observed) {
    const p = normalizePath(raw);
    if (p === null) {
      findings.push(makeFinding({
        id: 'PLAN_REPOSITORY_MUTATION_UNDECLARED', category: 'semantic', taskID,
        path: String(raw),
        message: `observed path "${String(raw)}" is not a normalized repository path`,
      }));
      continue;
    }
    // Journal-state path (.g6-* at the repository root).
    if (p.startsWith(JOURNAL_PREFIX)) {
      if (!journals.has(p)) {
        findings.push(makeFinding({
          id: 'PLAN_EVIDENCE_JOURNAL_STATE', category: 'semantic', taskID,
          path: p,
          message: `observed journal path "${p}" is outside the allowed journal states for stage ${stage}`,
        }));
      }
      continue;
    }
    // Absolute path: a temporary mutation, must be under a declared temp root.
    if (p.startsWith('/')) {
      const under = tempRoots.some((r) => underRoot(p, r));
      if (!under) {
        findings.push(makeFinding({
          id: 'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT', category: 'semantic', taskID,
          path: p,
          message: `observed temporary path "${p}" is outside the command temporary root for stage ${stage}`,
        }));
      }
      continue;
    }
    // Repo-relative non-journal path: must be in the declared allowlist.
    if (allowed.has(p)) continue;
    findings.push(makeFinding({
      id: 'PLAN_REPOSITORY_MUTATION_UNDECLARED', category: 'semantic', taskID,
      path: p,
      message: `observed path "${p}" is not in the declared repository allowlist for stage ${stage}`,
    }));
  }

  return sortFindings(findings);
}
