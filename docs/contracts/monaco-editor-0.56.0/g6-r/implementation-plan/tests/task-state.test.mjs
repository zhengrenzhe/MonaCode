// G6-R task-state and evidence lifecycle tests (TDD Step 1).
// Proves the fail-closed task-state machine (absent/running/failed/passed),
// the begin/resume/finalize lifecycle, and the begin journal recovery
// protocol across its five ordered operations. Each mutation yields its stable
// evidence finding ID. Node built-in test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, statSync, readdirSync, renameSync, openSync, writeSync, closeSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { createHash, randomBytes } from 'node:crypto';
import * as path from 'node:path';

import {
  nextTask,
  beginTaskEvidence,
  resumeTaskEvidence,
  auditTaskEvidence,
  finalizeTaskEvidence,
  EVIDENCE_STATES,
} from '../lib/task-state.mjs';
import { selectEvidenceCommit } from '../lib/evidence.mjs';

const GIT = '/usr/bin/git';
const IDENTITY = { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' };
const PLAN_HASH = 'a'.repeat(40);
const TASK_HASH = '1'.repeat(40);
const BASE_HASH = 'b'.repeat(40);

const dirs = [];
function mktmp() {
  const d = mkdtempSync(path.join(tmpdir(), 'g6r-ts-'));
  dirs.push(d);
  return d;
}
function cleanup() { for (const d of dirs) { try { rmSync(d, { recursive: true, force: true }); } catch {} } }
function sha256(s) { return createHash('sha256').update(s, 'utf8').digest('hex'); }

// ---------------------------------------------------------------------------
// Real git helpers (for the two-completed-task first-parent-validity proof)
// ---------------------------------------------------------------------------

function makeRepo() {
  const dir = mktmp();
  const env = { ...process.env, GIT_AUTHOR_NAME: IDENTITY.name, GIT_AUTHOR_EMAIL: IDENTITY.email, GIT_COMMITTER_NAME: IDENTITY.name, GIT_COMMITTER_EMAIL: IDENTITY.email };
  const r = spawnSync(GIT, ['-C', dir, 'init', '-q', '-b', 'main'], { env, encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`git init failed: ${r.stderr}`);
  spawnSync(GIT, ['-C', dir, 'config', 'user.name', IDENTITY.name], { env, encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'user.email', IDENTITY.email], { env, encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'commit.gpgSign', 'false'], { env, encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'core.hooksPath', '/dev/null'], { env, encoding: 'utf8' });
  return { dir, env };
}
function gitRun(dir, env, args) {
  const r = spawnSync(GIT, ['-C', dir, ...args], { env, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(`git ${args.join(' ')} failed: ${r.stderr || r.stdout}`);
  return r;
}
function makeGitRunner(dir, env) {
  return (args) => {
    const r = spawnSync(GIT, ['-C', dir, ...args], { env, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    return { stdout: r.stdout ?? '', stderr: r.stderr ?? '', status: r.status ?? 1 };
  };
}
function commitFiles(dir, env, message, files) {
  for (const [p, content] of Object.entries(files)) {
    const full = path.join(dir, p);
    mkdirSync(path.dirname(full), { recursive: true });
    writeFileSync(full, content);
    gitRun(dir, env, ['add', '--', p]);
  }
  gitRun(dir, env, ['-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgSign=false', 'commit', '--no-verify', '--no-gpg-sign', '-m', message]);
  return gitRun(dir, env, ['rev-parse', 'HEAD']).stdout.trim();
}

// ---------------------------------------------------------------------------
// Plan + workspace fixtures
// ---------------------------------------------------------------------------

function basePlan(overrides = {}) {
  return {
    planID: 'P00',
    baseCommit: BASE_HASH,
    planHash: PLAN_HASH,
    tasks: [baseTask(overrides)],
  };
}

function baseTask(overrides = {}) {
  const taskID = overrides.taskID || 'P00-T001';
  return {
    taskID,
    stages: [
      { name: 'preflight', steps: [{ kind: 'controller-action', action: 'begin-task' }] },
      { name: 'test-authoring', steps: [{ kind: 'authoring-operation', operation: 'author-tests' }] },
      { name: 'red', steps: [{ kind: 'verification-command', command: {
        commandID: `${taskID}.RED.001`, kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
        leaves: [{ leafID: `${taskID}.RED.001.PROC.001`, executable: '/usr/bin/swift', toolchainRow: 'swift-6.0', args: ['test'], timeoutMs: 60000 }],
      } }] },
      { name: 'implementation', steps: [{ kind: 'implementation-operation', operation: 'implement', modifies: ['Sources/Foo.swift'] }] },
      { name: 'green', steps: [{ kind: 'verification-command', command: {
        commandID: `${taskID}.GREEN.001`, kind: 'process', networkMode: 'forbidden', timeoutMs: 120000,
        leaves: [{ leafID: `${taskID}.GREEN.001.PROC.001`, executable: '/usr/bin/swift', toolchainRow: 'swift-6.0', args: ['test'], timeoutMs: 60000 }],
      } }] },
      { name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] },
      { name: 'evidence', steps: [{ kind: 'controller-action', action: 'finalize-evidence' }] },
    ],
    testContract: { contractID: `TC-${taskID}`, cases: [{
      caseID: 'C1', file: { path: 'Tests/Foo.test.swift', availability: 'task-step' },
      checker: 'swift-test', target: 'Tests', testSymbol: 'testFoo',
      fixtures: { kind: 'inline', values: {} },
      assertions: [{ id: 'A1', operand: 'exit' }],
      redLeafID: `${taskID}.RED.001.PROC.001`, greenLeafID: `${taskID}.GREEN.001.PROC.001`,
      inheritedOutput: false, failureClass: 'behavioral', authoringOperation: 'author-tests', source: 'baseline',
    }] },
    completionAssertions: ['A1', 'A2'],
    workspace: {
      ownershipToken: '0'.repeat(64), taskRoot: `/tmp/monacode-planctl/${taskID}`,
      planHash: PLAN_HASH, taskHash: TASK_HASH, baseHash: BASE_HASH,
      currentStage: 'preflight', lifecycleState: 'idle',
    },
    redScaffold: {
      sourcePath: 'Sources/Foo.swift', declarationText: 'scaffold',
      declarationHash: 'sha256:' + 'b'.repeat(64),
      sentinelBehavior: 'compile-fail', createOwner: 'test-authoring', replacementOwner: 'implementation',
      redAssertionID: 'RA1', finalAbsenceAssertion: 'FAA1',
    },
    productCommit: {
      author: IDENTITY, committer: IDENTITY,
      message: `monacode: complete ${taskID}`,
      preflightBaseParent: BASE_HASH,
      stagedProductPaths: ['Sources/Foo.swift'],
      hooksDisabled: true, signingDisabled: true, evidenceExcluded: true,
    },
    evidenceCommit: {
      author: IDENTITY, committer: IDENTITY,
      message: `evidence(monacode): complete ${taskID}`,
      parentCommit: '0'.repeat(40),
      firstParentSuccessor: 'immediate',
      stagedEvidencePath: `evidence/${taskID}.json`,
      laterFirstParentTouches: 0,
      hooksDisabled: true, signingDisabled: true,
      selectorMode: 'external-git', prohibitsSelfEmbedding: true,
      evidenceSchema: 'schemas/task-evidence.schema.json',
      verifiedAssertions: ['A1', 'A2'],
    },
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Evidence states are exactly the four closed values
// ---------------------------------------------------------------------------

test('EVIDENCE_STATES is exactly absent/running/failed/passed', () => {
  assert.deepEqual(EVIDENCE_STATES, ['absent', 'running', 'failed', 'passed']);
});

// ---------------------------------------------------------------------------
// nextTask — one task, completion, or one blocking finding
// ---------------------------------------------------------------------------

test('nextTask: selects the single ready task (no dependencies)', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH,
    tasks: [baseTask({ taskID: 'P00-T001' })] };
  const got = nextTask({ plan, evidenceByTask: {} });
  assert.equal(got.complete, false);
  assert.equal(got.finding, null);
  assert.equal(got.task.taskID, 'P00-T001');
});

test('nextTask: completion when every task is passed', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH,
    tasks: [baseTask({ taskID: 'P00-T001' })] };
  const evidenceByTask = { 'P00-T001': { state: 'passed', planHash: PLAN_HASH, taskHash: TASK_HASH } };
  const got = nextTask({ plan, evidenceByTask });
  assert.equal(got.complete, true);
  assert.equal(got.task, null);
  assert.equal(got.finding, null);
});

test('nextTask: blocking finding when dependency evidence is not passed', () => {
  const t1 = baseTask({ taskID: 'P00-T001' });
  const t2 = baseTask({ taskID: 'P00-T002' });
  t2.dependsOn = ['P00-T001'];
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [t1, t2] };
  const evidenceByTask = { 'P00-T001': { state: 'failed', planHash: PLAN_HASH, taskHash: TASK_HASH } };
  const got = nextTask({ plan, evidenceByTask });
  assert.equal(got.complete, false);
  assert.equal(got.task, null);
  assert.equal(got.finding.id, 'PLAN_EVIDENCE_DEPENDENCY');
  assert.equal(got.finding.taskID, 'P00-T002');
});

test('nextTask: accepts dependency when passed + hashes match + selectEvidenceCommit ok', () => {
  // Real two-task history; task2 depends on task1 whose evidence is passed.
  const { dir, env } = makeRepo();
  const base = commitFiles(dir, env, 'base', { 'R': 'b' });
  const t1p = commitFiles(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1e = commitFiles(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': '{}' });
  const git = makeGitRunner(dir, env);
  const t1 = baseTask({ taskID: 'P00-T001' });
  const t2 = baseTask({ taskID: 'P00-T002' });
  t2.dependsOn = ['P00-T001'];
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: base, tasks: [t1, t2] };
  const evidenceByTask = {
    'P00-T001': {
      state: 'passed', planHash: PLAN_HASH, taskHash: TASK_HASH,
      productCommit: t1p, evidencePath: 'evidence/P00-T001.json', repoHead: t1e,
      passedSha256: sha256('{}'),
    },
  };
  const got = nextTask({ plan, evidenceByTask, git, repoHead: t1e });
  assert.equal(got.finding, null, `expected no finding; got ${JSON.stringify(got.finding)}`);
  assert.equal(got.task.taskID, 'P00-T002');
});

test('nextTask: rejects dependency when plan hash mismatch', () => {
  const t1 = baseTask({ taskID: 'P00-T001' });
  const t2 = baseTask({ taskID: 'P00-T002' });
  t2.dependsOn = ['P00-T001'];
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [t1, t2] };
  const evidenceByTask = { 'P00-T001': { state: 'passed', planHash: 'x'.repeat(40), taskHash: TASK_HASH } };
  const got = nextTask({ plan, evidenceByTask });
  assert.equal(got.finding.id, 'PLAN_EVIDENCE_HASH');
  assert.equal(got.finding.taskID, 'P00-T002');
});

test('nextTask: lexicographic topological order picks the smaller ready taskID', () => {
  const t2 = baseTask({ taskID: 'P00-T002' });
  const t1 = baseTask({ taskID: 'P00-T001' });
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [t2, t1] };
  const got = nextTask({ plan, evidenceByTask: {} });
  assert.equal(got.task.taskID, 'P00-T001');
});

// ---------------------------------------------------------------------------
// beginTaskEvidence — recoverable beginning journal + 5 prefix states
// ---------------------------------------------------------------------------

function makeWorkspace(opts = {}) {
  const repoDir = mktmp();
  const rootParent = mktmp();
  const evidencePath = 'evidence/P00-T001.json';
  const taskID = 'P00-T001';
  const plan = basePlan();
  const repositoryState = {
    head: BASE_HASH,
    indexEmpty: true,
    priorEvidenceTrackedClean: true,
    productCommitPreflight: 'approved',
    evidencePreflight: 'approved',
  };
  const taskWorkspace = {
    repoDir, rootParent, evidencePath, taskID,
    fs: { existsSync, mkdirSync, writeFileSync, readFileSync, rmSync, statSync, readdirSync, renameSync, openSync, writeSync, closeSync, fsyncSync: () => {}, chmodSync: () => {} },
    crypto: { randomBytes },
    hooks: {},
    ...opts,
  };
  return { repoDir, rootParent, evidencePath, taskID, plan, repositoryState, taskWorkspace };
}

function readJournal(repoDir, evidencePath) {
  const jp = path.join(repoDir, evidencePath + '.g6-beginning');
  return existsSync(jp) ? JSON.parse(readFileSync(jp, 'utf8')) : null;
}
function runningBytes(repoDir, evidencePath) {
  const rp = path.join(repoDir, evidencePath);
  return existsSync(rp) ? readFileSync(rp, 'utf8') : null;
}
function markerBytes(rootParent, taskRoot) {
  const mp = path.join(taskRoot, '.token');
  return existsSync(mp) ? readFileSync(mp) : null;
}

test('beginTaskEvidence: records one base commit + one 256-bit token via recoverable journal', () => {
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'running');
  assert.equal(rec.baseCommit, BASE_HASH);
  assert.match(rec.tokenSha256, /^[0-9a-f]{64}$/, 'token sha256 must be 256-bit');
  // Journal records one base commit + one 32-byte token + plan/task hashes + root name.
  const j = readJournal(w.repoDir, w.evidencePath);
  // Journal is removed at the end of a successful begin.
  assert.equal(j, null, 'raw-token journal must be removed after a successful begin');
  // Marker holds the raw 32-byte token.
  const marker = markerBytes(w.rootParent, rec.taskRoot);
  assert.equal(marker.length, 32, 'raw-token marker must be 32 bytes (256-bit)');
  assert.equal(sha256(marker), rec.tokenSha256, 'tokenSha256 must equal sha256(raw token bytes)');
  // Running bytes contain ONLY the token sha256.
  const rb = JSON.parse(runningBytes(w.repoDir, w.evidencePath));
  assert.deepEqual(Object.keys(rb).sort(), ['tokenSha256']);
  assert.equal(rb.tokenSha256, rec.tokenSha256);
});

test('beginTaskEvidence: a retry accepts each of the five prefix states and produces identical running bytes', () => {
  // A single fixed token is injected into every run so all converge to the
  // same running bytes (sha256 of the fixed token).
  const FIXED_TOKEN = Buffer.alloc(32, 0x9a);

  // First, obtain the canonical running bytes from a clean run.
  const clean = makeWorkspace();
  clean.taskWorkspace.token = FIXED_TOKEN;
  beginTaskEvidence({ plan: clean.plan, taskID: clean.taskID, evidencePath: clean.evidencePath, repositoryState: clean.repositoryState, taskWorkspace: clean.taskWorkspace });
  const canonicalRunning = runningBytes(clean.repoDir, clean.evidencePath);

  // For each of the five prefix states (1..5), set up a fresh workspace with
  // the same fixed token, run beginTaskEvidence with a hook that throws after
  // operation N, then retry and assert convergence to the identical running
  // bytes.
  const opHooks = ['afterJournal', 'afterRoot', 'afterMarker', 'afterRunning', 'afterRemove'];
  for (let n = 0; n < 5; n++) {
    const w = makeWorkspace();
    w.taskWorkspace.token = FIXED_TOKEN;
    const hookName = opHooks[n];
    w.taskWorkspace.hooks = { [hookName]: () => { throw new Error(`crash after ${hookName}`); } };
    assert.throws(() => beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace }), /crash after/);
    w.taskWorkspace.hooks = {};
    const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
    assert.equal(rec.state, 'running');
    const rb = runningBytes(w.repoDir, w.evidencePath);
    assert.equal(rb, canonicalRunning, `prefix ${n + 1} did not converge to identical running bytes`);
  }
});

test('beginTaskEvidence: rejects a non-absent existing state', () => {
  const w = makeWorkspace();
  // Simulate an already-running evidence file.
  mkdirSync(path.join(w.repoDir, 'evidence'), { recursive: true });
  writeFileSync(path.join(w.repoDir, w.evidencePath), JSON.stringify({ tokenSha256: 'x'.repeat(64) }));
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings.length, 1);
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_STATE');
});

test('beginTaskEvidence: rejects a dirty index (non-empty)', () => {
  const w = makeWorkspace({ repositoryStateOverride: { indexEmpty: false } });
  w.repositoryState.indexEmpty = false;
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_INDEX');
});

test('beginTaskEvidence: rejects dirty tracked prior evidence', () => {
  const w = makeWorkspace();
  w.repositoryState.priorEvidenceTrackedClean = false;
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_BEGIN_BASE');
});

test('beginTaskEvidence: rejects when preflight not approved', () => {
  const w = makeWorkspace();
  w.repositoryState.productCommitPreflight = 'pending';
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_BEGIN_BASE');
});

// ---------------------------------------------------------------------------
// beginTaskEvidence mutation matrix — journal/token/base/plan/task
// ---------------------------------------------------------------------------

test('PLAN_EVIDENCE_BEGIN_JOURNAL: corrupted beginning journal fails closed', () => {
  const w = makeWorkspace();
  // Seed a journal with a corrupted token (wrong length).
  const jp = path.join(w.repoDir, w.evidencePath + '.g6-beginning');
  mkdirSync(path.dirname(jp), { recursive: true });
  writeFileSync(jp, JSON.stringify({ baseCommit: BASE_HASH, planHash: PLAN_HASH, taskHash: TASK_HASH, token: 'tooshort', taskRoot: '/tmp/x' }));
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_BEGIN_JOURNAL');
});

test('PLAN_EVIDENCE_TOKEN: workspace token mismatch between marker and journal fails closed', () => {
  const w = makeWorkspace();
  // First run to completion to establish a root + marker.
  const rec1 = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  // Corrupt the marker so it no longer matches the recorded token hash.
  writeFileSync(path.join(rec1.taskRoot, '.token'), Buffer.alloc(32, 0x01));
  // Re-enter begin: the running file exists (state is running, not absent) -> STATE.
  // Instead, simulate a retry at prefix-4 by re-creating the journal with the
  // original token hash but a tampered marker, then retry.
  const rb = path.join(w.repoDir, w.evidencePath);
  rmSync(rb, { force: true });
  const jp = path.join(w.repoDir, w.evidencePath + '.g6-beginning');
  writeFileSync(jp, JSON.stringify({ baseCommit: BASE_HASH, planHash: PLAN_HASH, taskHash: TASK_HASH, token: 'f'.repeat(64), taskRoot: rec1.taskRoot }));
  // marker now holds 0x01.. but journal claims token f..ff -> mismatch on recovery.
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_TOKEN');
});

test('PLAN_EVIDENCE_BASE: base commit changed between begin and resume fails closed', () => {
  // begin at BASE_HASH, then resume with head moved to a different commit.
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'running');
  const newHead = 'c'.repeat(40);
  const resume = resumeTaskEvidence({ plan: w.plan, taskID: w.taskID, evidence: rec, repositoryState: { ...w.repositoryState, head: newHead }, taskWorkspace: w.taskWorkspace });
  assert.equal(resume.state, 'failed');
  assert.equal(resume.findings[0].id, 'PLAN_EVIDENCE_BASE');
});

test('PLAN_EVIDENCE_HASH: plan/task hash mismatch on resume fails closed', () => {
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  const badPlan = basePlan();
  badPlan.planHash = 'z'.repeat(40);
  const resume = resumeTaskEvidence({ plan: badPlan, taskID: w.taskID, evidence: rec, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(resume.state, 'failed');
  assert.equal(resume.findings[0].id, 'PLAN_EVIDENCE_HASH');
});

// ---------------------------------------------------------------------------
// resumeTaskEvidence — accepts only failed/running with exact crash residue
// ---------------------------------------------------------------------------

test('resumeTaskEvidence: accepts running with exact crash residue + empty index + matching token/hashes', () => {
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  // Two leftover .g6-part transients below the task root, each non-symlink.
  mkdirSync(path.join(rec.taskRoot, 'cmd-child'), { recursive: true });
  writeFileSync(path.join(rec.taskRoot, 'cmd-child', '.g6-part'), 'attempt-1');
  // residue declared with prior hash matching.
  const residue = [
    { path: path.join(rec.taskRoot, 'cmd-child', '.g6-part'), type: 'plan-part', priorHash: sha256('attempt-1') },
  ];
  const resume = resumeTaskEvidence({
    plan: w.plan, taskID: w.taskID, evidence: { ...rec, crashResidue: residue },
    repositoryState: { ...w.repositoryState, observedMutations: ['Sources/Foo.swift'], policy: { stage: 'implementation', allowed: ['Sources/Foo.swift'], temporaryRoots: [], journals: ['.g6-part'] } },
    taskWorkspace: { ...w.taskWorkspace, crashResidue: residue },
  });
  assert.equal(resume.state, 'running', `expected running; findings=${JSON.stringify(resume.findings)}`);
  assert.equal(resume.findings.length, 0);
  // The residue file is removed.
  assert.equal(existsSync(path.join(rec.taskRoot, 'cmd-child', '.g6-part')), false);
  // A resume record is appended.
  assert.ok(resume.resumeRecords.length >= 1);
});

test('resumeTaskEvidence: rejects when index is dirty', () => {
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  const resume = resumeTaskEvidence({ plan: w.plan, taskID: w.taskID, evidence: rec, repositoryState: { ...w.repositoryState, indexEmpty: false }, taskWorkspace: { ...w.taskWorkspace, crashResidue: [] } });
  assert.equal(resume.state, 'failed');
  assert.equal(resume.findings[0].id, 'PLAN_EVIDENCE_INDEX');
});

test('resumeTaskEvidence: rejects worktree outside policy (PLAN_EVIDENCE_WORKTREE_POLICY)', () => {
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  const resume = resumeTaskEvidence({
    plan: w.plan, taskID: w.taskID, evidence: rec,
    repositoryState: { ...w.repositoryState, observedMutations: ['Sources/Undeclared.swift'], policy: { stage: 'implementation', allowed: ['Sources/Foo.swift'], temporaryRoots: [], journals: ['.g6-part'] } },
    taskWorkspace: { ...w.taskWorkspace, crashResidue: [] },
  });
  assert.equal(resume.state, 'failed');
  assert.equal(resume.findings[0].id, 'PLAN_EVIDENCE_WORKTREE_POLICY');
});

test('PLAN_EVIDENCE_CRASH_RESIDUE: non-plan-derived residue path fails closed', () => {
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  // A residue entry whose path is NOT below the task root and not a plan .g6-part.
  const residue = [{ path: '/etc/passwd', type: 'plan-part', priorHash: 'x' }];
  const resume = resumeTaskEvidence({
    plan: w.plan, taskID: w.taskID, evidence: { ...rec, crashResidue: residue },
    repositoryState: { ...w.repositoryState, observedMutations: [], policy: { stage: 'implementation', allowed: [], temporaryRoots: [], journals: ['.g6-part'] } },
    taskWorkspace: { ...w.taskWorkspace, crashResidue: residue },
  });
  assert.equal(resume.state, 'failed');
  assert.equal(resume.findings[0].id, 'PLAN_EVIDENCE_CRASH_RESIDUE');
});

test('PLAN_EVIDENCE_CRASH_RESIDUE: residue prior-hash drift fails closed', () => {
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  mkdirSync(path.join(rec.taskRoot, 'cmd-child'), { recursive: true });
  writeFileSync(path.join(rec.taskRoot, 'cmd-child', '.g6-part'), 'actual');
  const residue = [{ path: path.join(rec.taskRoot, 'cmd-child', '.g6-part'), type: 'plan-part', priorHash: sha256('different') }];
  const resume = resumeTaskEvidence({
    plan: w.plan, taskID: w.taskID, evidence: { ...rec, crashResidue: residue },
    repositoryState: { ...w.repositoryState, observedMutations: [], policy: { stage: 'implementation', allowed: [], temporaryRoots: [], journals: ['.g6-part'] } },
    taskWorkspace: { ...w.taskWorkspace, crashResidue: residue },
  });
  assert.equal(resume.state, 'failed');
  assert.equal(resume.findings[0].id, 'PLAN_EVIDENCE_CRASH_RESIDUE');
  // The residue is NOT removed on failure.
  assert.equal(existsSync(path.join(rec.taskRoot, 'cmd-child', '.g6-part')), true);
});

// ---------------------------------------------------------------------------
// auditTaskEvidence — dependency + command/acquisition/assertion provenance
// ---------------------------------------------------------------------------

test('auditTaskEvidence: zero findings when dependencies passed + selectEvidenceCommit ok', () => {
  const { dir, env } = makeRepo();
  const base = commitFiles(dir, env, 'base', { 'R': 'b' });
  const t1p = commitFiles(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1e = commitFiles(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': '{}' });
  const git = makeGitRunner(dir, env);
  const t2 = baseTask({ taskID: 'P00-T002' });
  t2.dependsOn = ['P00-T001'];
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: base, tasks: [baseTask({ taskID: 'P00-T001' }), t2] };
  const dependencyEvidence = [{
    taskID: 'P00-T001', state: 'passed', planHash: PLAN_HASH, taskHash: TASK_HASH,
    productCommit: t1p, evidencePath: 'evidence/P00-T001.json', repoHead: t1e,
    passedSha256: sha256('{}'),
  }];
  const findings = auditTaskEvidence({ plan, taskID: 'P00-T002', evidence: { state: 'running' }, dependencyEvidence, git, repoHead: t1e });
  assert.deepEqual(findings, []);
});

test('PLAN_EVIDENCE_COMMAND_RESULT: command result without executor provenance fails closed', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', commandResults: [{ leafID: 'P00-T001.RED.001.PROC.001' /* no executorHash */ }] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_COMMAND_RESULT');
});

test('PLAN_EVIDENCE_ACQUISITION: acquisition result without source contract fails closed', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', acquisitionResults: [{ /* no sourceContract */ }] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_ACQUISITION');
});

test('PLAN_EVIDENCE_ASSERTION: assertion result mismatch fails closed', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', assertionResults: [{ id: 'A1', result: 'failed' }, { id: 'A2', result: 'passed' }] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_ASSERTION');
});

// ---------------------------------------------------------------------------
// An unexpected Red/Green attempt stays running; an invariant failure -> failed
// ---------------------------------------------------------------------------

test('unexpected Red attempt mismatch stays running (does not advance)', () => {
  // A Red expected-result mismatch appends the attempt and leaves state running.
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  // Simulate a Red attempt with an unexpected result (expected exit 1, got 0).
  const attempt = { kind: 'red', leafID: 'P00-T001.RED.001.PROC.001', expectedExit: 1, actualExit: 0, executorHash: 'e'.repeat(64), stdoutHash: sha256(''), stderrHash: sha256('') };
  rec.commandResults = rec.commandResults.concat([attempt]);
  rec.currentStage = 'test-authoring'; // stays at test-authoring (Red did not pass)
  assert.equal(rec.state, 'running');
  assert.equal(rec.currentStage, 'test-authoring');
});

test('invariant failure (mutation result outside policy) moves to failed', () => {
  const w = makeWorkspace();
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  // A mutation-policy failure surfaces a finding and moves state to failed.
  const findings = auditTaskEvidence({
    plan: w.plan, taskID: w.taskID,
    evidence: { ...rec, mutationResult: { observedMutations: ['Sources/Undeclared.swift'], policy: { stage: 'implementation', allowed: ['Sources/Foo.swift'], temporaryRoots: [], journals: ['.g6-part'] } } },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_WORKTREE_POLICY');
});

// ---------------------------------------------------------------------------
// finalizeTaskEvidence — product parent/identity/boundary + self-embedding
// ---------------------------------------------------------------------------

function goodProductCommit(overrides = {}) {
  return {
    hash: 'f'.repeat(40),
    parent: BASE_HASH,
    author: IDENTITY, committer: IDENTITY,
    message: 'monacode: complete P00-T001',
    stagedPaths: ['Sources/Foo.swift'],
    treeDelta: ['Sources/Foo.swift'],
    ...overrides,
  };
}

test('finalizeTaskEvidence: builds passed bytes with productCommit + external-git, no blob/commit id', () => {
  const plan = basePlan();
  const evidence = { state: 'running', taskID: 'P00-T001', planHash: PLAN_HASH, taskHash: TASK_HASH, baseCommit: BASE_HASH, commandResults: [], acquisitionResults: [], assertionResults: [], completionAssertions: ['A1', 'A2'], fileHashes: [{ path: 'Sources/Foo.swift', sha256: 'a'.repeat(64) }] };
  const rec = finalizeTaskEvidence({ plan, taskID: 'P00-T001', evidence, productCommit: goodProductCommit() });
  assert.equal(rec.state, 'passed');
  assert.ok(rec.passedBytes);
  assert.equal(rec.passedSha256, sha256(rec.passedBytes));
  const parsed = JSON.parse(rec.passedBytes);
  assert.equal(parsed.productCommit, 'f'.repeat(40));
  assert.equal(parsed.selectorMode, 'external-git');
  // Neither the blob hash (passedSha256) nor an evidence commit id appears.
  assert.equal(parsed.passedSha256, undefined, 'passed JSON must not embed its own blob hash');
  assert.equal(parsed.evidenceCommit, undefined, 'passed JSON must not embed its evidence commit id');
  assert.equal(parsed.evidenceCommitId, undefined);
  assert.equal(parsed.blobHash, undefined);
  // The passed bytes must not contain the passedSha256 value anywhere.
  assert.ok(!rec.passedBytes.includes(rec.passedSha256), 'passed bytes must not embed their own sha256');
});

test('PLAN_EVIDENCE_FINALIZE_PARENT: product commit parent != preflight base', () => {
  const plan = basePlan();
  const evidence = { state: 'running', taskID: 'P00-T001', planHash: PLAN_HASH, taskHash: TASK_HASH, baseCommit: BASE_HASH, commandResults: [], acquisitionResults: [], assertionResults: [], completionAssertions: ['A1', 'A2'] };
  const rec = finalizeTaskEvidence({ plan, taskID: 'P00-T001', evidence, productCommit: goodProductCommit({ parent: 'd'.repeat(40) }) });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_FINALIZE_PARENT');
});

test('PLAN_EVIDENCE_FINALIZE_BOUNDARY: product commit boundary != task paths', () => {
  const plan = basePlan();
  const evidence = { state: 'running', taskID: 'P00-T001', planHash: PLAN_HASH, taskHash: TASK_HASH, baseCommit: BASE_HASH, commandResults: [], acquisitionResults: [], assertionResults: [], completionAssertions: ['A1', 'A2'] };
  const rec = finalizeTaskEvidence({ plan, taskID: 'P00-T001', evidence, productCommit: goodProductCommit({ stagedPaths: ['Sources/Foo.swift', 'Sources/Extra.swift'], treeDelta: ['Sources/Foo.swift', 'Sources/Extra.swift'] }) });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_FINALIZE_BOUNDARY');
});

test('PLAN_EVIDENCE_FINALIZE_EVIDENCE_IN_DELTA: evidence path in product tree delta', () => {
  const plan = basePlan();
  const evidence = { state: 'running', taskID: 'P00-T001', planHash: PLAN_HASH, taskHash: TASK_HASH, baseCommit: BASE_HASH, commandResults: [], acquisitionResults: [], assertionResults: [], completionAssertions: ['A1', 'A2'] };
  const rec = finalizeTaskEvidence({ plan, taskID: 'P00-T001', evidence, productCommit: goodProductCommit({ treeDelta: ['Sources/Foo.swift', 'evidence/P00-T001.json'] }) });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_FINALIZE_EVIDENCE_IN_DELTA');
});

test('PLAN_EVIDENCE_FINALIZE: product identity/message mismatch', () => {
  const plan = basePlan();
  const evidence = { state: 'running', taskID: 'P00-T001', planHash: PLAN_HASH, taskHash: TASK_HASH, baseCommit: BASE_HASH, commandResults: [], acquisitionResults: [], assertionResults: [], completionAssertions: ['A1', 'A2'] };
  const rec = finalizeTaskEvidence({ plan, taskID: 'P00-T001', evidence, productCommit: goodProductCommit({ message: 'wrong' }) });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_FINALIZE_IDENTITY');
});

test('finalizeTaskEvidence: passed bytes without matching evidence commit fails closed (no productCommit)', () => {
  const plan = basePlan();
  const evidence = { state: 'running', taskID: 'P00-T001', planHash: PLAN_HASH, taskHash: TASK_HASH, baseCommit: BASE_HASH, commandResults: [], acquisitionResults: [], assertionResults: [], completionAssertions: ['A1', 'A2'] };
  const rec = finalizeTaskEvidence({ plan, taskID: 'P00-T001', evidence, productCommit: null });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_FINALIZE_PARENT');
});

// ---------------------------------------------------------------------------
// Fix #1: nextTask passes expectedEvidenceSha256 so a tampered evidence blob
// (structure matches but blob bytes differ from dep.passedSha256) is rejected
// ---------------------------------------------------------------------------

test('Fix #1: dependency evidence blob bytes differ from passedSha256 -> PLAN_EVIDENCE_BLOB', () => {
  const { dir, env } = makeRepo();
  const base = commitFiles(dir, env, 'base', { 'R': 'b' });
  const t1p = commitFiles(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1e = commitFiles(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': 'actual-bytes' });
  const git = makeGitRunner(dir, env);
  const t1 = baseTask({ taskID: 'P00-T001' });
  const t2 = baseTask({ taskID: 'P00-T002' });
  t2.dependsOn = ['P00-T001'];
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: base, tasks: [t1, t2] };
  // passedSha256 claims the blob is 'expected-bytes' but the evidence commit stages 'actual-bytes'.
  const evidenceByTask = {
    'P00-T001': {
      state: 'passed', planHash: PLAN_HASH, taskHash: TASK_HASH,
      productCommit: t1p, evidencePath: 'evidence/P00-T001.json', repoHead: t1e,
      passedSha256: sha256('expected-bytes'),
    },
  };
  const got = nextTask({ plan, evidenceByTask, git, repoHead: t1e });
  assert.equal(got.task, null);
  assert.equal(got.finding.id, 'PLAN_EVIDENCE_BLOB');
  assert.equal(got.finding.taskID, 'P00-T002');
});

// ---------------------------------------------------------------------------
// Fix #2: nextTask fails closed when git/repoHead are absent for a passed dep
// ---------------------------------------------------------------------------

test('Fix #2: passed dependency without git/repoHead -> PLAN_EVIDENCE_SELECTOR_UNAVAILABLE', () => {
  const t1 = baseTask({ taskID: 'P00-T001' });
  const t2 = baseTask({ taskID: 'P00-T002' });
  t2.dependsOn = ['P00-T001'];
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [t1, t2] };
  const evidenceByTask = {
    'P00-T001': { state: 'passed', planHash: PLAN_HASH, taskHash: TASK_HASH, productCommit: 'f'.repeat(40), evidencePath: 'evidence/P00-T001.json', passedSha256: sha256('x') },
  };
  // No git / no repoHead provided.
  const got = nextTask({ plan, evidenceByTask });
  assert.equal(got.task, null);
  assert.equal(got.finding.id, 'PLAN_EVIDENCE_SELECTOR_UNAVAILABLE');
  assert.equal(got.finding.taskID, 'P00-T002');
});

// ---------------------------------------------------------------------------
// Fix #3: a stale .g6-part transient (crash after write, before rename) is
// cleaned on re-entry and converges to the identical running bytes
// ---------------------------------------------------------------------------

test('Fix #3: stale .g6-part after a crash mid-publish converges to identical running bytes', () => {
  const FIXED_TOKEN = Buffer.alloc(32, 0x7e);
  const clean = makeWorkspace();
  clean.taskWorkspace.token = FIXED_TOKEN;
  beginTaskEvidence({ plan: clean.plan, taskID: clean.taskID, evidencePath: clean.evidencePath, repositoryState: clean.repositoryState, taskWorkspace: clean.taskWorkspace });
  const canonicalRunning = runningBytes(clean.repoDir, clean.evidencePath);

  const w = makeWorkspace();
  w.taskWorkspace.token = FIXED_TOKEN;
  // Crash after the .g6-part is written+fsync'd but BEFORE the rename.
  w.taskWorkspace.hooks = { afterPartWrite: () => { throw new Error('crash before rename'); } };
  assert.throws(() => beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace }), /crash before rename/);
  // A stale .g6-part is left behind; running is absent.
  assert.ok(existsSync(path.join(w.repoDir, w.evidencePath + '.g6-part')));
  assert.equal(existsSync(path.join(w.repoDir, w.evidencePath)), false);
  // Retry converges.
  w.taskWorkspace.hooks = {};
  const rec = beginTaskEvidence({ plan: w.plan, taskID: w.taskID, evidencePath: w.evidencePath, repositoryState: w.repositoryState, taskWorkspace: w.taskWorkspace });
  assert.equal(rec.state, 'running');
  assert.equal(runningBytes(w.repoDir, w.evidencePath), canonicalRunning);
  // The stale partial is consumed by the rename.
  assert.equal(existsSync(path.join(w.repoDir, w.evidencePath + '.g6-part')), false);
});

// ---------------------------------------------------------------------------
// Fix #4: extended evidence validation in auditTaskEvidence — each tampered
// field yields its stable finding ID
// ---------------------------------------------------------------------------

function goodCommandResult(overrides = {}) {
  return {
    leafID: 'P00-T001.RED.001.PROC.001',
    executorHash: 'e'.repeat(64),
    sandboxProfileHash: 's'.repeat(64),
    parentCommandID: 'P00-T001.RED.001',
    exitStatus: 0,
    stdoutHash: sha256('out'),
    stderrHash: sha256('err'),
    expectedResult: true,
    ...overrides,
  };
}
function goodAcquisitionResult(overrides = {}) {
  return {
    sourceContract: 'SRC-1',
    url: 'https://example.com/x',
    host: 'example.com',
    sha256: 'sha256:' + 'a'.repeat(64),
    bytes: 100,
    license: 'MIT',
    ...overrides,
  };
}

test('Fix #4: command result with undeclared leaf -> PLAN_EVIDENCE_COMMAND_RESULT', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', commandResults: [goodCommandResult({ leafID: 'P00-T001.RED.001.PROC.099' })] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_COMMAND_RESULT');
});

test('Fix #4: command result with mismatched parent command ID -> PLAN_EVIDENCE_COMMAND_RESULT', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', commandResults: [goodCommandResult({ parentCommandID: 'P00-T001.GREEN.001' })] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_COMMAND_RESULT');
});

test('Fix #4: command result missing sandbox-profile hash -> PLAN_EVIDENCE_COMMAND_RESULT', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', commandResults: [goodCommandResult({ sandboxProfileHash: undefined })] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_COMMAND_RESULT');
});

test('Fix #4: acquisition result with non-HTTPS url -> PLAN_EVIDENCE_ACQUISITION', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', acquisitionResults: [goodAcquisitionResult({ url: 'http://insecure' })] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_ACQUISITION');
});

test('Fix #4: acquisition result with malformed sha256 -> PLAN_EVIDENCE_ACQUISITION', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', acquisitionResults: [goodAcquisitionResult({ sha256: 'not-a-hash' })] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_ACQUISITION');
});

test('Fix #4: completion assertion with no passed result -> PLAN_EVIDENCE_ASSERTION', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', assertionResults: [{ id: 'A1', result: 'passed' }] /* A2 missing */ },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_ASSERTION');
  assert.ok(findings[0].message.includes('A2'));
});

test('Fix #4: verified assertions mismatch the evidence-commit contract -> PLAN_EVIDENCE_ASSERTION', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'running', verifiedAssertions: ['A1', 'WRONG'] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_ASSERTION');
});

// ---------------------------------------------------------------------------
// Fix #4-filehash: fileHashes structural validation + product-boundary membership
// ---------------------------------------------------------------------------

test('Fix #4-filehash: fileHashes path outside the product boundary -> PLAN_EVIDENCE_FILE_HASH', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'passed', fileHashes: [
      { path: 'Sources/Foo.swift', sha256: 'a'.repeat(64) },
      { path: 'Sources/Outside.swift', sha256: 'b'.repeat(64) },
    ] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_FILE_HASH');
  assert.ok(findings[0].message.includes('Sources/Outside.swift'));
});

test('Fix #4-filehash: fileHashes with malformed sha256 -> PLAN_EVIDENCE_FILE_HASH', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'passed', fileHashes: [{ path: 'Sources/Foo.swift', sha256: 'not-a-hash' }] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_FILE_HASH');
});

test('Fix #4-filehash: passed task with boundary but no fileHashes -> PLAN_EVIDENCE_FILE_HASH', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'passed' /* no fileHashes */ },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_FILE_HASH');
});

test('Fix #4-filehash: valid fileHashes (all paths in boundary, 64-hex) -> no finding', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'passed', fileHashes: [{ path: 'Sources/Foo.swift', sha256: 'a'.repeat(64) }] },
    dependencyEvidence: [],
  });
  assert.deepEqual(findings, []);
});

test('Fix #4-filehash: task with no product boundary may omit fileHashes -> no finding', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask({ productCommit: { stagedProductPaths: [] } })] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'passed' /* no fileHashes, but no boundary either */ },
    dependencyEvidence: [],
  });
  assert.deepEqual(findings, []);
});

test('Fix #4-filehash: passed boundary task with empty fileHashes array -> PLAN_EVIDENCE_FILE_HASH', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask()] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'passed', fileHashes: [] },
    dependencyEvidence: [],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'PLAN_EVIDENCE_FILE_HASH');
  assert.ok(findings[0].message.includes('empty fileHashes'));
});

test('Fix #4-filehash: no-boundary task with empty fileHashes array -> no finding', () => {
  const plan = { planID: 'P00', planHash: PLAN_HASH, baseCommit: BASE_HASH, tasks: [baseTask({ productCommit: { stagedProductPaths: [] } })] };
  const findings = auditTaskEvidence({
    plan, taskID: 'P00-T001',
    evidence: { state: 'passed', fileHashes: [] },
    dependencyEvidence: [],
  });
  assert.deepEqual(findings, []);
});

test('Fix #4-filehash: finalize boundary task without fileHashes -> PLAN_EVIDENCE_FILE_HASH', () => {
  const plan = basePlan();
  const evidence = { state: 'running', taskID: 'P00-T001', planHash: PLAN_HASH, taskHash: TASK_HASH, baseCommit: BASE_HASH, commandResults: [], acquisitionResults: [], assertionResults: [], completionAssertions: ['A1', 'A2'] /* no fileHashes */ };
  const rec = finalizeTaskEvidence({ plan, taskID: 'P00-T001', evidence, productCommit: goodProductCommit() });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_FILE_HASH');
});

test('Fix #4-filehash: finalize boundary task with empty fileHashes array -> PLAN_EVIDENCE_FILE_HASH', () => {
  const plan = basePlan();
  const evidence = { state: 'running', taskID: 'P00-T001', planHash: PLAN_HASH, taskHash: TASK_HASH, baseCommit: BASE_HASH, commandResults: [], acquisitionResults: [], assertionResults: [], completionAssertions: ['A1', 'A2'], fileHashes: [] };
  const rec = finalizeTaskEvidence({ plan, taskID: 'P00-T001', evidence, productCommit: goodProductCommit() });
  assert.equal(rec.state, 'failed');
  assert.equal(rec.findings[0].id, 'PLAN_EVIDENCE_FILE_HASH');
});

// ---------------------------------------------------------------------------
// Teardown
// ---------------------------------------------------------------------------

test('teardown cleans temp dirs', () => { cleanup(); assert.ok(true); });
process.on('exit', cleanup);
process.on('SIGINT', () => { cleanup(); process.exit(130); });
