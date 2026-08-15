// G6-R task-state and evidence lifecycle module.
// Repository-owned, dependency-free. Implements the fail-closed task-state
// machine (absent/running/failed/passed), the begin/resume/finalize lifecycle,
// the beginning-journal recovery protocol (five ordered operations, each
// prefix state recoverable to identical running bytes), and dependency
// acceptance via lexicographic topological order + selectEvidenceCommit.
//
// Every failure is fail-closed: the lifecycle moves to `failed` with exactly
// one stable finding ID so evidence validation is deterministic across runs.

import { createHash } from 'node:crypto';
import * as path from 'node:path';

import { makeFinding, sortFindings } from './findings.mjs';
import { canonicalJSONStringify } from './canonical-json.mjs';
import { selectEvidenceCommit } from './evidence.mjs';
import { compareObservedMutations } from './mutation-policy.mjs';

// ---------------------------------------------------------------------------
// Closed evidence state set + finding IDs
// ---------------------------------------------------------------------------

export const EVIDENCE_STATES = ['absent', 'running', 'failed', 'passed'];

export const TASK_STATE_FINDING_IDS = [
  'PLAN_EVIDENCE_STATE',
  'PLAN_EVIDENCE_NEXT_TASK',
  'PLAN_EVIDENCE_HASH',
  'PLAN_EVIDENCE_DEPENDENCY',
  'PLAN_EVIDENCE_SELECTOR',
  'PLAN_EVIDENCE_SELECTOR_UNAVAILABLE',
  'PLAN_EVIDENCE_BEGIN_BASE',
  'PLAN_EVIDENCE_BEGIN_JOURNAL',
  'PLAN_EVIDENCE_TOKEN',
  'PLAN_EVIDENCE_BASE',
  'PLAN_EVIDENCE_INDEX',
  'PLAN_EVIDENCE_RESUME_STATE',
  'PLAN_EVIDENCE_CRASH_RESIDUE',
  'PLAN_EVIDENCE_WORKTREE_POLICY',
  'PLAN_EVIDENCE_COMMAND_RESULT',
  'PLAN_EVIDENCE_ACQUISITION',
  'PLAN_EVIDENCE_ASSERTION',
  'PLAN_EVIDENCE_FILE_HASH',
  'PLAN_EVIDENCE_FINALIZE_PARENT',
  'PLAN_EVIDENCE_FINALIZE_IDENTITY',
  'PLAN_EVIDENCE_FINALIZE_BOUNDARY',
  'PLAN_EVIDENCE_FINALIZE_EVIDENCE_IN_DELTA',
  'PLAN_EVIDENCE_SELF_EMBEDDING',
];

const IDENTITY = { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' };

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function finding(id, taskID, message, pathStr = '') {
  return makeFinding({ id, category: 'semantic', taskID: taskID ?? null, path: pathStr, message });
}

// ---------------------------------------------------------------------------
// nextTask — lexicographic topological selection
// ---------------------------------------------------------------------------

/**
 * Select the next task to begin. Returns one task, completion, or one blocking
 * finding. A dependency is accepted only when its evidence is `passed` with
 * matching plan/task hashes and selectEvidenceCommit returns exactly one valid
 * evidence commit (when git + repoHead are provided).
 * @param {{
 *   plan: { planHash: string, tasks: Array<{taskID: string, dependsOn?: string[], workspace?: {taskHash: string}}> },
 *   evidenceByTask?: Record<string, object>,
 *   git?: Function, repoHead?: string,
 * }} input
 * @returns {{ task: object|null, complete: boolean, finding: object|null }}
 */
export function nextTask({ plan, evidenceByTask = {}, git, repoHead }) {
  const byTask = evidenceByTask || {};
  const tasks = (plan && Array.isArray(plan.tasks)) ? plan.tasks : [];

  const allPassed = tasks.length > 0 && tasks.every((t) => byTask[t.taskID] && byTask[t.taskID].state === 'passed');
  if (allPassed) return { task: null, complete: true, finding: null };

  // A task is a begin-candidate only when it is `absent` (not yet begun). A
  // `running` or `failed` task is recovered via resumeTaskEvidence, not begun.
  const isAbsent = (t) => !byTask[t.taskID] || byTask[t.taskID].state === 'absent';

  const ready = [];
  const blocked = [];
  for (const t of tasks) {
    if (!isAbsent(t)) continue;
    const deps = Array.isArray(t.dependsOn) ? t.dependsOn : [];
    let depOk = true, depFinding = null;
    for (const depID of deps) {
      const dep = byTask[depID];
      if (!dep || dep.state !== 'passed') {
        depOk = false; depFinding = { id: 'PLAN_EVIDENCE_DEPENDENCY', message: `dependency ${depID} evidence is not passed` }; break;
      }
      if (dep.planHash !== plan.planHash) {
        depOk = false; depFinding = { id: 'PLAN_EVIDENCE_HASH', message: `dependency ${depID} planHash mismatch` }; break;
      }
      const depTask = tasks.find((x) => x.taskID === depID);
      if (depTask && dep.taskHash !== depTask.workspace.taskHash) {
        depOk = false; depFinding = { id: 'PLAN_EVIDENCE_HASH', message: `dependency ${depID} taskHash mismatch` }; break;
      }
      // Fail-closed: a passed dependency MUST be verified by selectEvidenceCommit;
      // if the selector (git/repoHead) or the dependency evidence anchors are
      // unavailable, the dependency is NOT accepted.
      if (typeof git !== 'function' || !repoHead || !dep.productCommit || !dep.evidencePath) {
        depOk = false; depFinding = { id: 'PLAN_EVIDENCE_SELECTOR_UNAVAILABLE', message: `dependency ${depID} evidence commit selector unavailable` }; break;
      }
      // Pass the dependency's passedSha256 so selectEvidenceCommit compares the
      // evidence commit's blob bytes against the validated passed bytes.
      const sel = selectEvidenceCommit({
        repoHead, productCommit: dep.productCommit, evidencePath: dep.evidencePath, git, taskID: depID,
        expectedEvidenceSha256: dep.passedSha256,
      });
      if (!sel.ok) {
        depOk = false;
        depFinding = { id: (sel.findings[0] && sel.findings[0].id) || 'PLAN_EVIDENCE_SELECTOR', message: `dependency ${depID} evidence commit invalid` };
        break;
      }
    }
    if (depOk) ready.push(t);
    else blocked.push({ task: t, finding: { ...depFinding, taskID: t.taskID } });
  }

  if (ready.length > 0) {
    ready.sort((a, b) => (a.taskID < b.taskID ? -1 : a.taskID > b.taskID ? 1 : 0));
    return { task: ready[0], complete: false, finding: null };
  }

  blocked.sort((a, b) => (a.task.taskID < b.task.taskID ? -1 : a.task.taskID > b.task.taskID ? 1 : 0));
  const fb = blocked[0];
  return { task: null, complete: false, finding: finding(fb.finding.id, fb.task.taskID, fb.finding.message) };
}

// ---------------------------------------------------------------------------
// beginTaskEvidence — beginning-journal recovery protocol
// ---------------------------------------------------------------------------

const ROOT_PREFIX = 'monacode-g6-';

function discoverTaskRoot(rootParent, taskID, fs) {
  let entries = [];
  try { entries = fs.readdirSync(rootParent); } catch { return { root: null, count: 0 }; }
  const prefix = `${ROOT_PREFIX}${taskID}-`;
  const matches = entries.filter((e) => typeof e === 'string' && e.startsWith(prefix));
  return {
    root: matches.length === 1 ? path.join(rootParent, matches[0]) : null,
    count: matches.length,
  };
}

function readMarker(fs, markerPath) {
  if (!fs.existsSync(markerPath)) return null;
  const mb = fs.readFileSync(markerPath);
  return Buffer.isBuffer(mb) ? mb : Buffer.from(mb);
}

/**
 * Begin a task's evidence lifecycle. Accepts only `absent` (no running file),
 * the single nextTask-selected task, an empty index, clean tracked prior
 * evidence, and the preflight-approved product/evidence status. Creates the
 * beginning journal, the token-owned task root, the raw-token marker, publishes
 * the running record, and removes the raw-token journal. A retry accepts only
 * the five non-empty prefix states of those five ordered operations and
 * produces identical running bytes.
 * @param {{
 *   plan: object, taskID: string, evidencePath: string,
 *   repositoryState: { head: string, indexEmpty: boolean, priorEvidenceTrackedClean: boolean, productCommitPreflight: string, evidencePreflight: string },
 *   taskWorkspace: { repoDir: string, rootParent: string, fs: object, crypto: { randomBytes: Function }, token?: Buffer, hooks?: object },
 * }} input
 * @returns {object} EvidenceRecord
 */
export function beginTaskEvidence({ plan, taskID, evidencePath, repositoryState, taskWorkspace }) {
  const fs = taskWorkspace.fs;
  const crypto = taskWorkspace.crypto;
  const hooks = taskWorkspace.hooks || {};
  const journalPath = path.join(taskWorkspace.repoDir, evidencePath + '.g6-beginning');
  const runningPath = path.join(taskWorkspace.repoDir, evidencePath);

  const fail = (id, message) => ({
    state: 'failed', taskID, findings: [finding(id, taskID, message, evidencePath)],
  });

  const task = (plan && Array.isArray(plan.tasks) ? plan.tasks : []).find((t) => t.taskID === taskID);
  if (!task) return fail('PLAN_EVIDENCE_STATE', `task ${taskID} not present in plan`);

  // Preconditions.
  if (!repositoryState || repositoryState.indexEmpty !== true) return fail('PLAN_EVIDENCE_INDEX', 'index must be empty to begin');
  if (!repositoryState || repositoryState.priorEvidenceTrackedClean !== true) return fail('PLAN_EVIDENCE_BEGIN_BASE', 'tracked prior evidence must be clean');
  if (!repositoryState || repositoryState.productCommitPreflight !== 'approved' || repositoryState.evidencePreflight !== 'approved') return fail('PLAN_EVIDENCE_BEGIN_BASE', 'product/evidence preflight must be approved');

  const J = fs.existsSync(journalPath);
  const disc = discoverTaskRoot(taskWorkspace.rootParent, taskID, fs);
  if (disc.count > 1) return fail('PLAN_EVIDENCE_TOKEN', `multiple task roots for ${taskID}`);
  const discoveredRoot = disc.root;
  const R = !!discoveredRoot;
  const markerPath = R ? path.join(discoveredRoot, '.token') : null;
  const M = R && fs.existsSync(markerPath);
  const P = fs.existsSync(runningPath);

  // Recover the token from the beginning journal and/or the raw-token marker.
  let token = null;
  let journal = null;
  if (J) {
    let raw;
    try { raw = fs.readFileSync(journalPath, 'utf8'); } catch { return fail('PLAN_EVIDENCE_BEGIN_JOURNAL', 'beginning journal unreadable'); }
    try { journal = JSON.parse(raw); } catch { return fail('PLAN_EVIDENCE_BEGIN_JOURNAL', 'beginning journal unparseable'); }
    if (!journal || typeof journal.token !== 'string' || !/^[0-9a-f]{64}$/.test(journal.token)) return fail('PLAN_EVIDENCE_BEGIN_JOURNAL', 'beginning journal token must be 64 hex (32 bytes)');
    token = Buffer.from(journal.token, 'hex');
    if (token.length !== 32) return fail('PLAN_EVIDENCE_BEGIN_JOURNAL', 'beginning journal token must decode to 32 bytes');
    if (journal.baseCommit !== repositoryState.head) return fail('PLAN_EVIDENCE_BASE', 'beginning journal base commit != current HEAD');
    if (journal.planHash !== plan.planHash) return fail('PLAN_EVIDENCE_HASH', 'beginning journal planHash mismatch');
    if (journal.taskHash !== task.workspace.taskHash) return fail('PLAN_EVIDENCE_HASH', 'beginning journal taskHash mismatch');
  }
  let markerToken = null;
  if (M) {
    markerToken = readMarker(fs, markerPath);
    if (!markerToken || markerToken.length !== 32) return fail('PLAN_EVIDENCE_TOKEN', 'raw-token marker must be 32 bytes (256-bit)');
  }
  if (token && markerToken) {
    if (!token.equals(markerToken)) return fail('PLAN_EVIDENCE_TOKEN', 'beginning journal token != raw-token marker');
  } else if (markerToken) {
    token = markerToken;
  }

  // If a token was recovered, the discovered root must match the computed root.
  if (token) {
    const ts = sha256(token);
    const computedRoot = path.join(taskWorkspace.rootParent, `${ROOT_PREFIX}${taskID}-${ts.slice(0, 16)}`);
    if (R && discoveredRoot !== computedRoot) return fail('PLAN_EVIDENCE_TOKEN', `task root ${discoveredRoot} != token-derived ${computedRoot}`);
  }

  // Classify the prefix state.
  const complete = (!J) && R && M && P;
  let stage;
  if (!J && !R && !M && !P) stage = 'first';
  else if (J && !R && !M && !P) stage = 'prefix-1';
  else if (J && R && !M && !P) stage = 'prefix-2';
  else if (J && R && M && !P) stage = 'prefix-3';
  else if (J && R && M && P) stage = 'prefix-4';
  else if (complete) stage = 'complete';
  else stage = 'invalid';

  if (stage === 'invalid') return fail('PLAN_EVIDENCE_STATE', `inconsistent beginning state (J=${J} R=${R} M=${M} P=${P})`);

  if (stage === 'complete') {
    const rb = fs.readFileSync(runningPath, 'utf8');
    let parsed;
    try { parsed = JSON.parse(rb); } catch { return fail('PLAN_EVIDENCE_STATE', 'running evidence unparseable'); }
    const ts = sha256(token);
    if (!parsed || parsed.tokenSha256 !== ts) return fail('PLAN_EVIDENCE_TOKEN', 'running tokenSha256 != recovered token');
    return {
      state: 'running', taskID, baseCommit: repositoryState.head, tokenSha256: ts,
      taskRoot: discoveredRoot, evidencePath, currentStage: 'preflight', lifecycleState: 'running',
      runningBytes: rb, planHash: plan.planHash, taskHash: task.workspace.taskHash,
      findings: [],
    };
  }

  // First call or retry: ensure a token exists.
  if (!token) {
    token = taskWorkspace.token ? Buffer.from(taskWorkspace.token) : Buffer.from(crypto.randomBytes(32));
  }
  const tokenSha256 = sha256(token);
  const rootName = `${ROOT_PREFIX}${taskID}-${tokenSha256.slice(0, 16)}`;
  const taskRoot = path.join(taskWorkspace.rootParent, rootName);
  const marker = path.join(taskRoot, '.token');

  // Op 1: create/fsync the beginning journal (open+write+fsync+close).
  if (!fs.existsSync(journalPath)) {
    try { fs.mkdirSync(path.dirname(journalPath), { recursive: true }); } catch {}
    const journalContent = canonicalJSONStringify({
      baseCommit: repositoryState.head,
      planHash: plan.planHash,
      taskHash: task.workspace.taskHash,
      token: token.toString('hex'),
      taskRoot,
    });
    const jfd = fs.openSync(journalPath, 'w');
    fs.writeSync(jfd, journalContent);
    fs.fsyncSync(jfd);
    fs.closeSync(jfd);
  }
  if (hooks.afterJournal) hooks.afterJournal();

  // Op 2: create the mode-0700 task root exclusively (atomic mkdir; EEXIST is
  // the retry path for an existing root from a prior attempt).
  try {
    fs.mkdirSync(taskRoot, { mode: 0o700 });
  } catch (e) {
    if (e.code !== 'EEXIST') throw e;
  }
  if (hooks.afterRoot) hooks.afterRoot();

  // Op 3: write/fsync the mode-0600 raw-token marker, then fsync the root dir.
  if (!fs.existsSync(marker)) {
    const mfd = fs.openSync(marker, 'w', 0o600);
    fs.writeSync(mfd, token);
    fs.fsyncSync(mfd);
    fs.closeSync(mfd);
  }
  try {
    const rdfd = fs.openSync(taskRoot, 'r');
    fs.fsyncSync(rdfd);
    fs.closeSync(rdfd);
  } catch (e) { /* directory fsync best-effort; not all fs mocks support it */ }
  if (hooks.afterMarker) hooks.afterMarker();

  // Op 4: atomically publish the running record (only the token SHA-256) via a
  // .g6-part transient: write+fsync the partial, then rename (atomic on the
  // same filesystem). A stale partial from a crashed prior attempt is removed
  // first so the prefix state (J/R/M/P) is unaffected.
  const runningBytes = canonicalJSONStringify({ tokenSha256 });
  try { fs.mkdirSync(path.dirname(runningPath), { recursive: true }); } catch {}
  const partPath = runningPath + '.g6-part';
  try { fs.rmSync(partPath, { force: true }); } catch {}
  const pfd = fs.openSync(partPath, 'w');
  fs.writeSync(pfd, runningBytes);
  fs.fsyncSync(pfd);
  fs.closeSync(pfd);
  if (hooks.afterPartWrite) hooks.afterPartWrite();
  fs.renameSync(partPath, runningPath);
  if (hooks.afterRunning) hooks.afterRunning();

  // Op 5: remove the raw-token journal.
  if (fs.existsSync(journalPath)) {
    try { fs.rmSync(journalPath, { force: true }); } catch {}
  }
  if (hooks.afterRemove) hooks.afterRemove();

  return {
    state: 'running', taskID, baseCommit: repositoryState.head, tokenSha256,
    taskRoot, evidencePath, currentStage: 'preflight', lifecycleState: 'running',
    runningBytes, planHash: plan.planHash, taskHash: task.workspace.taskHash,
    commandResults: [], acquisitionResults: [], assertionResults: [],
    resumeRecords: [], crashResidue: [], findings: [],
  };
}

// ---------------------------------------------------------------------------
// resumeTaskEvidence — fail-closed recovery predicate
// ---------------------------------------------------------------------------

/**
 * Resume a `failed` or `running` task. Accepts only exact crash residue when
 * HEAD still equals the recorded base, the index is empty, observed changes are
 * a subset of the current task policy, the same task root and token hash
 * validate, and authority hashes match. Removes only exact plan-derived
 * `.g6-part` files or token-owned command children that are non-symlink nodes
 * below the selected workspace and whose final target still has the prior
 * recorded hash or declared-absent state. Appends a resume record and returns
 * to the recorded stage WITHOUT deleting/reverting/staging/committing a
 * product path.
 * @param {{
 *   plan: object, taskID: string, evidence: object,
 *   repositoryState: { head: string, indexEmpty: boolean, observedMutations?: string[], policy?: object },
 *   taskWorkspace: { repoDir: string, fs: object, crashResidue?: Array<object> },
 * }} input
 * @returns {object} EvidenceRecord
 */
export function resumeTaskEvidence({ plan, taskID, evidence, repositoryState, taskWorkspace }) {
  const fs = taskWorkspace.fs;
  const fail = (id, message) => ({
    state: 'failed', taskID, findings: [finding(id, taskID, message, evidence && evidence.evidencePath ? evidence.evidencePath : '')],
  });

  if (!evidence || (evidence.state !== 'failed' && evidence.state !== 'running')) return fail('PLAN_EVIDENCE_RESUME_STATE', 'resume accepts only failed or running');
  const task = (plan && Array.isArray(plan.tasks) ? plan.tasks : []).find((t) => t.taskID === taskID);
  if (!task) return fail('PLAN_EVIDENCE_STATE', `task ${taskID} not present in plan`);

  if (evidence.baseCommit !== repositoryState.head) return fail('PLAN_EVIDENCE_BASE', 'HEAD moved since begin (base commit changed)');
  if (repositoryState.indexEmpty !== true) return fail('PLAN_EVIDENCE_INDEX', 'index must be empty to resume');

  // Worktree must be a subset of the current task policy.
  if (repositoryState.policy && Array.isArray(repositoryState.observedMutations)) {
    const leak = compareObservedMutations(repositoryState.policy, repositoryState.observedMutations);
    if (leak.length > 0) return fail('PLAN_EVIDENCE_WORKTREE_POLICY', leak[0].message);
  }

  // Authority hashes.
  if (evidence.planHash !== plan.planHash) return fail('PLAN_EVIDENCE_HASH', 'planHash mismatch on resume');
  if (evidence.taskHash !== task.workspace.taskHash) return fail('PLAN_EVIDENCE_HASH', 'taskHash mismatch on resume');

  // Task root + token validation.
  if (typeof evidence.taskRoot !== 'string' || !evidence.taskRoot.startsWith('/')) return fail('PLAN_EVIDENCE_TOKEN', 'task root missing');
  const markerPath = path.join(evidence.taskRoot, '.token');
  if (!fs.existsSync(markerPath)) return fail('PLAN_EVIDENCE_TOKEN', 'task-root raw-token marker missing');
  const markerToken = readMarker(fs, markerPath);
  if (!markerToken || markerToken.length !== 32 || sha256(markerToken) !== evidence.tokenSha256) return fail('PLAN_EVIDENCE_TOKEN', 'workspace token mismatch');

  // Crash residue: validate every candidate before removing any.
  const residue = (taskWorkspace.crashResidue || evidence.crashResidue || []);
  const validated = [];
  for (const r of residue) {
    if (!r || typeof r.path !== 'string') return fail('PLAN_EVIDENCE_CRASH_RESIDUE', 'crash residue entry missing path');
    if (r.type !== 'plan-part' && r.type !== 'command-child') return fail('PLAN_EVIDENCE_CRASH_RESIDUE', `residue type ${r.type} is not plan-derived`);
    const belowTaskRoot = r.path.startsWith(evidence.taskRoot + '/');
    const belowRepo = r.path.startsWith(taskWorkspace.repoDir + '/');
    if (!belowTaskRoot && !belowRepo) return fail('PLAN_EVIDENCE_CRASH_RESIDUE', `residue path ${r.path} is not below the selected workspace`);
    let st;
    try { st = fs.statSync(r.path); } catch {
      if (r.declaredAbsent) { validated.push(r); continue; }
      return fail('PLAN_EVIDENCE_CRASH_RESIDUE', `residue ${r.path} not present and not declared-absent`);
    }
    if (typeof st.isSymbolicLink === 'function' && st.isSymbolicLink()) return fail('PLAN_EVIDENCE_CRASH_RESIDUE', `residue ${r.path} is a symlink`);
    if (r.priorHash) {
      let content;
      try { content = fs.readFileSync(r.path); } catch { return fail('PLAN_EVIDENCE_CRASH_RESIDUE', `residue ${r.path} unreadable`); }
      if (sha256(content) !== r.priorHash) return fail('PLAN_EVIDENCE_CRASH_RESIDUE', `residue ${r.path} prior-hash drift`);
    }
    validated.push(r);
  }
  for (const r of validated) {
    try { fs.rmSync(r.path, { force: true, recursive: r.type === 'command-child' }); } catch {}
  }

  const resumeRecords = (evidence.resumeRecords || []).concat([{ stage: evidence.currentStage, baseCommit: evidence.baseCommit }]);
  return {
    ...evidence,
    state: 'running',
    resumeRecords,
    findings: [],
  };
}

// ---------------------------------------------------------------------------
// auditTaskEvidence — dependency + provenance validation
// ---------------------------------------------------------------------------

/**
 * Audit a task's evidence against the plan, its dependencies, and the
 * command/acquisition/assertion/mutation provenance. Returns a deterministically
 * sorted Finding[] and never throws for data errors.
 * @param {{
 *   plan: object, taskID: string, evidence: object,
 *   dependencyEvidence?: Array<object>, git?: Function, repoHead?: string,
 * }} input
 * @returns {Array<object>}
 */
export function auditTaskEvidence({ plan, taskID, evidence = {}, dependencyEvidence = [], git, repoHead }) {
  const out = [];
  const tasks = (plan && Array.isArray(plan.tasks)) ? plan.tasks : [];
  const task = tasks.find((t) => t.taskID === taskID);

  // --- Dependency evidence: passed + matching hashes + exactly one valid evidence commit ---
  for (const dep of dependencyEvidence) {
    if (!dep || dep.state !== 'passed') { out.push(finding('PLAN_EVIDENCE_DEPENDENCY', taskID, `dependency ${dep && dep.taskID} evidence is not passed`)); continue; }
    if (dep.planHash !== plan.planHash) { out.push(finding('PLAN_EVIDENCE_HASH', taskID, `dependency ${dep.taskID} planHash mismatch`)); continue; }
    const depTask = tasks.find((t) => t.taskID === dep.taskID);
    if (depTask && dep.taskHash !== depTask.workspace.taskHash) { out.push(finding('PLAN_EVIDENCE_HASH', taskID, `dependency ${dep.taskID} taskHash mismatch`)); continue; }
    if (typeof git !== 'function' || !repoHead || !dep.productCommit || !dep.evidencePath) { out.push(finding('PLAN_EVIDENCE_SELECTOR_UNAVAILABLE', taskID, `dependency ${dep.taskID} evidence commit selector unavailable`)); continue; }
    const sel = selectEvidenceCommit({ repoHead, productCommit: dep.productCommit, evidencePath: dep.evidencePath, git, taskID: dep.taskID, expectedEvidenceSha256: dep.passedSha256 });
    if (!sel.ok) { out.push(finding((sel.findings[0] && sel.findings[0].id) || 'PLAN_EVIDENCE_SELECTOR', taskID, `dependency ${dep.taskID} evidence commit invalid`)); continue; }
  }

  // --- Declared leaf -> parent command map (for command-result validation) ---
  const declaredLeaves = new Map();
  if (task) {
    for (const stageName of ['red', 'green']) {
      const stage = (task.stages || []).find((s) => s && s.name === stageName);
      const steps = (stage && Array.isArray(stage.steps)) ? stage.steps : [];
      for (const step of steps) {
        if (!step || step.kind !== 'verification-command' || !step.command) continue;
        const cmd = step.command;
        for (const leaf of (Array.isArray(cmd.leaves) ? cmd.leaves : [])) {
          if (leaf && typeof leaf.leafID === 'string') declaredLeaves.set(leaf.leafID, cmd.commandID);
        }
      }
    }
  }

  // --- Command results: executor + sandbox-profile hashes, parent command ID,
  //     leaf declaration, exit status, stdout/stderr hashes, expected result ---
  for (const cr of (evidence.commandResults || [])) {
    if (!cr || typeof cr.executorHash !== 'string' || !/^[0-9a-f]{64}$/.test(cr.executorHash)) { out.push(finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, 'command result lacks selected executor provenance')); continue; }
    if (typeof cr.sandboxProfileHash !== 'string' || !/^[0-9a-f]{64}$/.test(cr.sandboxProfileHash)) { out.push(finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, `command result for leaf ${cr.leafID} lacks sandbox-profile hash`)); continue; }
    if (typeof cr.leafID !== 'string' || !declaredLeaves.has(cr.leafID)) { out.push(finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, `command result leaf ${cr && cr.leafID} is not a declared leaf`)); continue; }
    if (cr.parentCommandID !== declaredLeaves.get(cr.leafID)) { out.push(finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, `command result leaf ${cr.leafID} parent command ID mismatch`)); continue; }
    if (typeof cr.exitStatus !== 'number') { out.push(finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, `command result leaf ${cr.leafID} lacks exit status`)); continue; }
    if (typeof cr.stdoutHash !== 'string' || !/^[0-9a-f]{64}$/.test(cr.stdoutHash)) { out.push(finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, `command result leaf ${cr.leafID} lacks stdout hash`)); continue; }
    if (typeof cr.stderrHash !== 'string' || !/^[0-9a-f]{64}$/.test(cr.stderrHash)) { out.push(finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, `command result leaf ${cr.leafID} lacks stderr hash`)); continue; }
    if (typeof cr.expectedResult !== 'boolean') { out.push(finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, `command result leaf ${cr.leafID} lacks aggregate expected result`)); continue; }
  }

  // --- Acquisition results: source contract + URL/host/redirect/byte/hash/license ---
  for (const ar of (evidence.acquisitionResults || [])) {
    if (!ar || !ar.sourceContract) { out.push(finding('PLAN_EVIDENCE_ACQUISITION', taskID, 'acquisition result lacks selected source contract')); continue; }
    if (typeof ar.url !== 'string' || !/^https:\/\//.test(ar.url)) { out.push(finding('PLAN_EVIDENCE_ACQUISITION', taskID, `acquisition ${ar.sourceContract} url invalid`)); continue; }
    if (typeof ar.host !== 'string' || ar.host.length === 0) { out.push(finding('PLAN_EVIDENCE_ACQUISITION', taskID, `acquisition ${ar.sourceContract} host invalid`)); continue; }
    if (typeof ar.sha256 !== 'string' || !/^sha256:[0-9a-f]{64}$/.test(ar.sha256)) { out.push(finding('PLAN_EVIDENCE_ACQUISITION', taskID, `acquisition ${ar.sourceContract} sha256 invalid`)); continue; }
    if (typeof ar.bytes !== 'number' || ar.bytes < 0) { out.push(finding('PLAN_EVIDENCE_ACQUISITION', taskID, `acquisition ${ar.sourceContract} bytes invalid`)); continue; }
    if (typeof ar.license !== 'string' || ar.license.length === 0) { out.push(finding('PLAN_EVIDENCE_ACQUISITION', taskID, `acquisition ${ar.sourceContract} license identity invalid`)); continue; }
  }

  // --- Assertion results: every result passed; every completion assertion covered ---
  const assertionById = new Map();
  for (const ar of (evidence.assertionResults || [])) {
    if (!ar || ar.result !== 'passed') { out.push(finding('PLAN_EVIDENCE_ASSERTION', taskID, `assertion ${ar && ar.id} result is not passed`)); }
    if (ar && typeof ar.id === 'string') assertionById.set(ar.id, ar);
  }
  if (Array.isArray(evidence.assertionResults) && evidence.assertionResults.length > 0 && task && Array.isArray(task.completionAssertions)) {
    for (const ca of task.completionAssertions) {
      if (!assertionById.has(ca)) out.push(finding('PLAN_EVIDENCE_ASSERTION', taskID, `completion assertion ${ca} has no passed result`));
    }
  }

  // --- Mutation result: observed mutations must be a subset of the policy ---
  if (evidence.mutationResult && evidence.mutationResult.policy && Array.isArray(evidence.mutationResult.observedMutations)) {
    const leak = compareObservedMutations(evidence.mutationResult.policy, evidence.mutationResult.observedMutations);
    if (leak.length > 0) out.push(finding('PLAN_EVIDENCE_WORKTREE_POLICY', taskID, leak[0].message));
  }

  // --- File hashes: structural validation + product-boundary membership ---
  // The controller records a sha256 per product-boundary file after command
  // execution; the lib validates that the recorded set is well-formed and that
  // every path is a member of the task's product-commit boundary. The full
  // hash-VALUE comparison (recorded hash vs the file on disk) is the
  // controller's runtime job — the lib has no filesystem access to product
  // files. A task with no product-boundary mutations may legitimately omit them.
  const boundary = new Set(task && task.productCommit && Array.isArray(task.productCommit.stagedProductPaths) ? task.productCommit.stagedProductPaths : []);
  const hasBoundary = boundary.size > 0;
  const fileHashes = evidence.fileHashes;
  if (Array.isArray(fileHashes)) {
    for (const fh of fileHashes) {
      if (!fh || typeof fh.path !== 'string' || fh.path.length === 0 || fh.path.startsWith('/') || fh.path.startsWith('./') || fh.path.includes('\0') || fh.path.split('/').includes('..')) {
        out.push(finding('PLAN_EVIDENCE_FILE_HASH', taskID, `file hash path "${fh && fh.path}" is malformed`)); continue;
      }
      if (typeof fh.sha256 !== 'string' || !/^[0-9a-f]{64}$/.test(fh.sha256)) {
        out.push(finding('PLAN_EVIDENCE_FILE_HASH', taskID, `file hash for path ${fh.path} has a malformed sha256`)); continue;
      }
      if (hasBoundary && !boundary.has(fh.path)) {
        out.push(finding('PLAN_EVIDENCE_FILE_HASH', taskID, `file hash path ${fh.path} is outside the product boundary`)); continue;
      }
    }
    // A passed boundary task must record at least one file hash; an empty array
    // is not acceptable (the controller must have hashed the boundary files).
    if (evidence.state === 'passed' && hasBoundary && fileHashes.length === 0) {
      out.push(finding('PLAN_EVIDENCE_FILE_HASH', taskID, 'passed task with product-boundary mutations has an empty fileHashes array'));
    }
  } else if (evidence.state === 'passed' && hasBoundary) {
    out.push(finding('PLAN_EVIDENCE_FILE_HASH', taskID, 'passed task with product-boundary mutations lacks fileHashes'));
  }

  // --- Verified assertions must equal the task evidence-commit contract ---
  if (task && task.evidenceCommit && Array.isArray(task.evidenceCommit.verifiedAssertions) && Array.isArray(evidence.verifiedAssertions)) {
    if (JSON.stringify(evidence.verifiedAssertions) !== JSON.stringify(task.evidenceCommit.verifiedAssertions)) {
      out.push(finding('PLAN_EVIDENCE_ASSERTION', taskID, 'verified assertions do not match the evidence-commit contract'));
    }
  }

  return sortFindings(out);
}

// ---------------------------------------------------------------------------
// finalizeTaskEvidence — passed-byte construction + product commit proof
// ---------------------------------------------------------------------------

/**
 * Build the passed evidence bytes after product commit. Requires that commit's
 * parent to equal the task preflight base, its author/committer/subject to
 * equal the product contract, its committed path set to equal the task's exact
 * boundary, and no evidence path in its tree delta. The passed JSON contains the
 * product commit and selector mode `external-git`, but neither its own blob
 * hash nor evidence commit ID.
 * @param {{
 *   plan: object, taskID: string, evidence: object,
 *   productCommit: { hash: string, parent: string, author: object, committer: object, message: string, stagedPaths: string[], treeDelta: string[] } | null,
 * }} input
 * @returns {object} EvidenceRecord
 */
export function finalizeTaskEvidence({ plan, taskID, evidence = {}, productCommit }) {
  const fail = (id, message) => ({ state: 'failed', taskID, findings: [finding(id, taskID, message)] });
  const task = (plan && Array.isArray(plan.tasks) ? plan.tasks : []).find((t) => t.taskID === taskID);
  if (!task) return fail('PLAN_EVIDENCE_STATE', `task ${taskID} not present in plan`);
  if (!productCommit) return fail('PLAN_EVIDENCE_FINALIZE_PARENT', 'product commit required to finalize');

  if (productCommit.parent !== evidence.baseCommit) return fail('PLAN_EVIDENCE_FINALIZE_PARENT', 'product commit parent != task preflight base');
  if (!productCommit.author || productCommit.author.name !== IDENTITY.name || productCommit.author.email !== IDENTITY.email) return fail('PLAN_EVIDENCE_FINALIZE_IDENTITY', 'product commit author identity wrong');
  if (!productCommit.committer || productCommit.committer.name !== IDENTITY.name || productCommit.committer.email !== IDENTITY.email) return fail('PLAN_EVIDENCE_FINALIZE_IDENTITY', 'product commit committer identity wrong');
  if (productCommit.message !== `monacode: complete ${taskID}`) return fail('PLAN_EVIDENCE_FINALIZE_IDENTITY', 'product commit message does not match product contract');

  const evidencePath = task.evidenceCommit && task.evidenceCommit.stagedEvidencePath;
  const delta = Array.isArray(productCommit.treeDelta) ? productCommit.treeDelta : [];
  if (evidencePath && delta.includes(evidencePath)) return fail('PLAN_EVIDENCE_FINALIZE_EVIDENCE_IN_DELTA', 'evidence path present in product commit tree delta');

  const planBoundary = (task.productCommit && Array.isArray(task.productCommit.stagedProductPaths) ? task.productCommit.stagedProductPaths : []).slice().sort();
  const committed = delta.slice().sort();
  if (JSON.stringify(committed) !== JSON.stringify(planBoundary)) return fail('PLAN_EVIDENCE_FINALIZE_BOUNDARY', 'product commit path set != task plan boundary');

  // Revalidate every running command, acquisition, assertion, and mutation
  // result against the plan/task contract before building passed bytes.
  const auditFindings = auditTaskEvidence({ plan, taskID, evidence, dependencyEvidence: [] });
  if (auditFindings.length > 0) return { state: 'failed', taskID, findings: auditFindings };

  // A boundary task must carry non-empty recorded fileHashes before it can be
  // treated as passed. The audit call above runs against the RUNNING evidence
  // (state !== 'passed'), so the passed-state fileHashes check does not fire
  // there; enforce it here on the finalize path.
  if (planBoundary.length > 0 && (!Array.isArray(evidence.fileHashes) || evidence.fileHashes.length === 0)) {
    return fail('PLAN_EVIDENCE_FILE_HASH', 'cannot finalize a boundary task without recorded fileHashes');
  }

  const passedRecord = {
    taskID,
    state: 'passed',
    planHash: plan.planHash,
    taskHash: task.workspace.taskHash,
    baseCommit: evidence.baseCommit,
    productCommit: productCommit.hash,
    selectorMode: 'external-git',
    commandResults: evidence.commandResults || [],
    acquisitionResults: evidence.acquisitionResults || [],
    assertionResults: evidence.assertionResults || [],
    completionAssertions: task.completionAssertions || evidence.completionAssertions || [],
    verifiedAssertions: (task.evidenceCommit && task.evidenceCommit.verifiedAssertions) || [],
    fileHashes: Array.isArray(evidence.fileHashes) ? evidence.fileHashes : [],
  };
  const passedBytes = canonicalJSONStringify(passedRecord);
  const passedSha256 = sha256(passedBytes);

  if (passedBytes.includes(passedSha256)) return fail('PLAN_EVIDENCE_SELF_EMBEDDING', 'passed bytes embed their own blob hash');

  return {
    state: 'passed', taskID, passedBytes, passedSha256,
    productCommit: productCommit.hash, selectorMode: 'external-git',
    planHash: plan.planHash, taskHash: task.workspace.taskHash, baseCommit: evidence.baseCommit,
    findings: [],
  };
}
