// G6-R planctl controller tests (TDD Step 1).
// Proves the non-interactive CLI dispatch contract: every documented command
// resolves to its handler, unknown commands and malformed flags are rejected,
// stdout is canonical JSON, exit codes are exact (0 = zero findings), and the
// pre-assembly CLI returns PLAN_AUTHORITY_NOT_ASSEMBLED for every command until
// Task 26 installs the complete audit/runtime handlers. The createPlanctl({handlers})
// factory is exercised with injected handlers to prove begin-task creates one
// owned task root + canonical running record, resume-task enforces its pre-commit
// recovery predicate, and a stop after the beginning-journal operation converges
// on rerun to identical running bytes. Node built-in test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { randomBytes, createHash } from 'node:crypto';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

import { createPlanctl, PLAN_AUTHORITY_NOT_ASSEMBLED } from '../runtime/planctl.mjs';
import { beginTaskEvidence, resumeTaskEvidence } from '../lib/task-state.mjs';
import { canonicalJSONStringify } from '../lib/canonical-json.mjs';

const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const PLANCTL = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  'runtime',
  'planctl.mjs',
);

const dirs = [];
function mktmp() {
  const d = mkdtempSync(path.join(tmpdir(), 'g6r-pc-'));
  dirs.push(d);
  return d;
}
function cleanup() { for (const d of dirs) { try { rmSync(d, { recursive: true, force: true }); } catch {} } }
function sha256(b) { return createHash('sha256').update(b).digest('hex'); }

// ---------------------------------------------------------------------------
// Spawn the real CLI entry point (pre-assembly handlers).
// ---------------------------------------------------------------------------

function runCLI(...argv) {
  const r = spawnSync(NODE, [PLANCTL, ...argv], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  return r;
}

function parseStdout(r) {
  assert.equal(r.status !== null, true, `process exited with signal ${r.signal}`);
  let payload;
  assert.doesNotThrow(() => { payload = JSON.parse(r.stdout); }, `stdout not JSON: ${r.stdout}`);
  return payload;
}

// Every documented command. Each is spawned with enough flags to pass argument
// validation; the pre-assembly handler returns PLAN_AUTHORITY_NOT_ASSEMBLED.
const COMMAND_CASES = [
  ['verify-archive', []],
  ['audit', []],
  ['simulate', []],
  ['render', []],
  ['begin-task', ['--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']],
  ['resume-task', ['--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']],
  ['preflight', ['--all']],
  ['preflight', ['--task', 'P00-T001']],
  ['run-command', ['--id', 'P00-T001.GREEN.001', '--evidence-path', 'evidence/P00-T001.json']],
  ['acquire-source', ['--task', 'P00-T001', '--source', 'SRC-1', '--evidence-path', 'evidence/P00-T001.json']],
  ['commit-task', ['--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']],
  ['finalize-evidence', ['--task', 'P00-T001', '--path', 'evidence/P00-T001.json']],
  ['interfaces', ['compile']],
  ['next', ['--evidence-root', 'artifacts/acceptance-evidence/g6-r']],
  ['verify-evidence', ['--task', 'P00-T001', '--path', 'evidence/P00-T001.json']],
];

test('CLI: every documented command returns PLAN_AUTHORITY_NOT_ASSEMBLED (pre-assembly)', () => {
  for (const [cmd, args] of COMMAND_CASES) {
    const r = runCLI(cmd, ...args);
    const payload = parseStdout(r);
    assert.equal(r.status, 1, `${cmd} exit code expected 1, got ${r.status}; stdout=${r.stdout}`);
    assert.ok(Array.isArray(payload.findings), `${cmd} findings not array`);
    assert.equal(payload.findings.length, 1, `${cmd} expected exactly one finding, got ${payload.findings.length}`);
    assert.equal(payload.findings[0].id, PLAN_AUTHORITY_NOT_ASSEMBLED, `${cmd} finding id`);
    // The payload is canonical JSON (sorted keys).
    assert.equal(r.stdout, canonicalJSONStringify(payload), `${cmd} stdout not canonical`);
  }
});

test('CLI: the resolved command name appears in the canonical payload', () => {
  // Two-word commands resolve to a single canonical command name.
  const r = runCLI('preflight', '--all');
  const payload = parseStdout(r);
  assert.equal(payload.command, 'preflight --all');
  const r2 = runCLI('interfaces', 'compile');
  assert.equal(parseStdout(r2).command, 'interfaces compile');
});

test('CLI: unknown command is rejected with a dispatch finding and exit 1', () => {
  const r = runCLI('frobnicate', '--task', 'P00-T001');
  const payload = parseStdout(r);
  assert.equal(r.status, 1);
  assert.ok(payload.findings.length >= 1);
  assert.equal(payload.findings[0].id, 'PLAN_COMMAND_DISPATCH');
  assert.match(payload.findings[0].message, /unknown command/i);
});

test('CLI: absent required flag is rejected with a dispatch finding and exit 1', () => {
  // begin-task requires --evidence-path; omit it.
  const r = runCLI('begin-task', '--task', 'P00-T001');
  const payload = parseStdout(r);
  assert.equal(r.status, 1);
  assert.equal(payload.findings[0].id, 'PLAN_COMMAND_DISPATCH');
  assert.match(payload.findings[0].message, /--evidence-path/);
});

test('CLI: unknown flag is rejected with a dispatch finding and exit 1', () => {
  const r = runCLI('begin-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json', '--bogus', 'x');
  const payload = parseStdout(r);
  assert.equal(r.status, 1);
  assert.equal(payload.findings[0].id, 'PLAN_COMMAND_DISPATCH');
  assert.match(payload.findings[0].message, /--bogus/);
});

test('CLI: duplicate flag is rejected with a dispatch finding and exit 1', () => {
  const r = runCLI('begin-task', '--task', 'P00-T001', '--task', 'P00-T002', '--evidence-path', 'evidence/P00-T001.json');
  const payload = parseStdout(r);
  assert.equal(r.status, 1);
  assert.equal(payload.findings[0].id, 'PLAN_COMMAND_DISPATCH');
  assert.match(payload.findings[0].message, /duplicate/i);
});

test('CLI: preflight requires exactly one of --all/--task (preflight bare is rejected)', () => {
  const r = runCLI('preflight');
  const payload = parseStdout(r);
  assert.equal(r.status, 1);
  assert.equal(payload.findings[0].id, 'PLAN_COMMAND_DISPATCH');
});

test('CLI: zero findings exits 0', async () => {
  // Inject a handler that returns zero findings to prove the exit-code contract.
  const ctl = createPlanctl({
    handlers: new Map([['verify-archive', async () => ({ result: { ok: true }, findings: [] })]]),
  });
  const res = await ctl.run(['verify-archive']);
  assert.equal(res.exitCode, 0);
  assert.equal(res.findings.length, 0);
  assert.deepEqual(JSON.parse(res.stdout), { command: 'verify-archive', result: { ok: true }, findings: [] });
});

// ---------------------------------------------------------------------------
// createPlanctl({ handlers }) — dependency injection + flag parsing.
// ---------------------------------------------------------------------------

test('createPlanctl: parses --flag value pairs and passes them to the handler', async () => {
  let captured = null;
  const ctl = createPlanctl({
    handlers: new Map([['begin-task', async (args) => {
      captured = args;
      return { result: { begun: true }, findings: [] };
    }]]),
  });
  const res = await ctl.run(['begin-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  assert.equal(res.exitCode, 0);
  assert.equal(captured.flags['--task'], 'P00-T001');
  assert.equal(captured.flags['--evidence-path'], 'evidence/P00-T001.json');
  assert.equal(captured.command, 'begin-task');
});

test('createPlanctl: handler findings propagate and set exit 1', async () => {
  const ctl = createPlanctl({
    handlers: new Map([['audit', async () => ({
      result: null,
      findings: [{ id: 'PLAN_TYPE', category: 'semantic', taskID: null, path: '', message: 'boom' }],
    })]]),
  });
  const res = await ctl.run(['audit']);
  assert.equal(res.exitCode, 1);
  assert.equal(res.findings.length, 1);
  assert.equal(res.findings[0].id, 'PLAN_TYPE');
});

test('createPlanctl: missing handler key is a dispatch finding', async () => {
  const ctl = createPlanctl({ handlers: new Map() });
  const res = await ctl.run(['verify-archive']);
  assert.equal(res.exitCode, 1);
  assert.equal(res.findings[0].id, 'PLAN_COMMAND_DISPATCH');
});

// ---------------------------------------------------------------------------
// begin-task delegation: one owned task root + canonical running record.
// ---------------------------------------------------------------------------

const PLAN_HASH = 'a'.repeat(40);
const TASK_HASH = '1'.repeat(40);
const BASE_HASH = 'b'.repeat(40);

function basePlan(overrides = {}) {
  const taskID = overrides.taskID || 'P00-T001';
  return {
    planID: 'P00', baseCommit: BASE_HASH, planHash: PLAN_HASH,
    tasks: [{
      taskID,
      stages: [
        { name: 'preflight', steps: [{ kind: 'controller-action', action: 'begin-task' }] },
        { name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] },
        { name: 'evidence', steps: [{ kind: 'controller-action', action: 'finalize-evidence' }] },
      ],
      workspace: { ownershipToken: '0'.repeat(64), taskRoot: `/tmp/monacode-planctl/${taskID}`, planHash: PLAN_HASH, taskHash: TASK_HASH, baseHash: BASE_HASH, currentStage: 'preflight', lifecycleState: 'idle' },
      productCommit: { author: { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' }, committer: { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' }, message: `monacode: complete ${taskID}`, preflightBaseParent: BASE_HASH, stagedProductPaths: ['Sources/Foo.swift'], hooksDisabled: true, signingDisabled: true, evidenceExcluded: true },
      evidenceCommit: { author: { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' }, committer: { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' }, message: `evidence(monacode): complete ${taskID}`, parentCommit: '0'.repeat(40), firstParentSuccessor: 'immediate', stagedEvidencePath: `evidence/${taskID}.json`, laterFirstParentTouches: 0, hooksDisabled: true, signingDisabled: true, selectorMode: 'external-git', prohibitsSelfEmbedding: true, evidenceSchema: 'schemas/task-evidence.schema.json', verifiedAssertions: [] },
      ...overrides,
    }],
  };
}

// A real fs-backed begin handler that delegates to beginTaskEvidence, with an
// optional stop hook fired after the beginning-journal operation. A stop is
// caught and surfaced as a finding so the controller records the crash point
// without aborting the process.
function makeBeginHandler(repoDir, rootParent, crypto, plan, stopAfter) {
  let stopped = false;
  return {
    stopped: () => stopped,
    handler: async (args) => {
      const taskID = args.flags['--task'];
      const evidencePath = args.flags['--evidence-path'];
      try {
        const res = beginTaskEvidence({
          plan, taskID, evidencePath,
          repositoryState: { head: BASE_HASH, indexEmpty: true, priorEvidenceTrackedClean: true, productCommitPreflight: 'approved', evidencePreflight: 'approved' },
          taskWorkspace: {
            repoDir, rootParent, fs: await import('node:fs'), crypto,
            hooks: { afterJournal: () => { if (stopAfter === 'afterJournal') { stopped = true; throw new Error('STOP_AFTER_JOURNAL'); } } },
          },
        });
        return { result: res, findings: res.findings || [] };
      } catch (e) {
        if (stopAfter && String(e.message).startsWith('STOP_AFTER')) {
          return { result: null, findings: [{ id: 'PLAN_EVIDENCE_BEGIN_JOURNAL', category: 'semantic', taskID, path: evidencePath, message: 'controller stopped after beginning-journal operation' }] };
        }
        throw e;
      }
    },
  };
}

test('begin-task: creates one owned task root and a canonical running record; product files/git untouched', async () => {
  const repoDir = mktmp();
  const rootParent = mktmp();
  const crypto = { randomBytes: (n) => randomBytes(n) };
  const plan = basePlan();
  const { handler } = makeBeginHandler(repoDir, rootParent, crypto, plan, null);
  const ctl = createPlanctl({ handlers: new Map([['begin-task', handler]]) });
  const res = await ctl.run(['begin-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  assert.equal(res.exitCode, 0, JSON.stringify(res.findings));
  // Exactly one task root below rootParent.
  const roots = readdirSync(rootParent).filter((e) => e.startsWith('monacode-g6-P00-T001-'));
  assert.equal(roots.length, 1);
  // The running record is published at the evidence path.
  const runningPath = path.join(repoDir, 'evidence/P00-T001.json');
  assert.ok(existsSync(runningPath));
  const running = JSON.parse(readFileSync(runningPath, 'utf8'));
  assert.equal(running.tokenSha256.length, 64);
  // No .g6-beginning journal remains.
  assert.ok(!existsSync(path.join(repoDir, 'evidence/P00-T001.json.g6-beginning')));
  // No .g6-part transient remains.
  assert.ok(!existsSync(path.join(repoDir, 'evidence/P00-T001.json.g6-part')));
  // Product files / git history untouched: repoDir has no .git and no product paths.
  assert.ok(!existsSync(path.join(repoDir, '.git')));
  assert.ok(!existsSync(path.join(repoDir, 'Sources')));
});

test('begin-task: stop after the journal operation then rerun converges to identical running bytes', async () => {
  const repoDir = mktmp();
  const rootParent = mktmp();
  const crypto = { randomBytes: () => Buffer.from('c'.repeat(32), 'utf8') };
  const plan = basePlan();
  // First run: stop after the journal op.
  const bh1 = makeBeginHandler(repoDir, rootParent, crypto, plan, 'afterJournal');
  const ctl1 = createPlanctl({ handlers: new Map([['begin-task', bh1.handler]]) });
  await ctl1.run(['begin-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  assert.ok(bh1.stopped(), 'first run should have stopped after the journal op');
  // The journal exists; the running record does not yet.
  assert.ok(existsSync(path.join(repoDir, 'evidence/P00-T001.json.g6-beginning')));
  assert.ok(!existsSync(path.join(repoDir, 'evidence/P00-T001.json')));
  // Rerun without the stop: converges to the canonical running record.
  const bh2 = makeBeginHandler(repoDir, rootParent, crypto, plan, null);
  const ctl2 = createPlanctl({ handlers: new Map([['begin-task', bh2.handler]]) });
  const res = await ctl2.run(['begin-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  assert.equal(res.exitCode, 0, JSON.stringify(res.findings));
  const running = readFileSync(path.join(repoDir, 'evidence/P00-T001.json'), 'utf8');
  // Re-run again: identical bytes (idempotent).
  const bh3 = makeBeginHandler(repoDir, rootParent, crypto, plan, null);
  const ctl3 = createPlanctl({ handlers: new Map([['begin-task', bh3.handler]]) });
  await ctl3.run(['begin-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  const running2 = readFileSync(path.join(repoDir, 'evidence/P00-T001.json'), 'utf8');
  assert.equal(running, running2, 'rerun did not converge to identical running bytes');
  // Journal removed.
  assert.ok(!existsSync(path.join(repoDir, 'evidence/P00-T001.json.g6-beginning')));
});

// ---------------------------------------------------------------------------
// resume-task delegation: enforces the pre-commit recovery predicate.
// ---------------------------------------------------------------------------

test('resume-task: rejects when HEAD moved since begin (base commit changed)', async () => {
  const repoDir = mktmp();
  const rootParent = mktmp();
  const crypto = { randomBytes: () => Buffer.from('d'.repeat(32), 'utf8') };
  const plan = basePlan();
  // Begin first; the begin result carries the full in-memory evidence record.
  const bh = makeBeginHandler(repoDir, rootParent, crypto, plan, null);
  const ctl = createPlanctl({ handlers: new Map([['begin-task', bh.handler]]) });
  const beginRes = await ctl.run(['begin-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  const evidence = beginRes.result;
  // Resume with a moved HEAD.
  const resumeHandler = async (args) => {
    const res = resumeTaskEvidence({
      plan, taskID: args.flags['--task'], evidence,
      repositoryState: { head: 'e'.repeat(40), indexEmpty: true, observedMutations: [], policy: { stage: 'preflight', allowed: [], temporaryRoots: [], journals: ['.g6-beginning'] } },
      taskWorkspace: { repoDir, fs: await import('node:fs') },
    });
    return { result: res, findings: res.findings || [] };
  };
  const ctl2 = createPlanctl({ handlers: new Map([['resume-task', resumeHandler]]) });
  const res = await ctl2.run(['resume-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  assert.equal(res.exitCode, 1);
  assert.equal(res.findings[0].id, 'PLAN_EVIDENCE_BASE');
});

test('resume-task: accepts an exact running record with no crash residue', async () => {
  const repoDir = mktmp();
  const rootParent = mktmp();
  const crypto = { randomBytes: () => Buffer.from('e'.repeat(32), 'utf8') };
  const plan = basePlan();
  const bh = makeBeginHandler(repoDir, rootParent, crypto, plan, null);
  const ctl = createPlanctl({ handlers: new Map([['begin-task', bh.handler]]) });
  const beginRes = await ctl.run(['begin-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  const evidence = beginRes.result;
  const resumeHandler = async (args) => {
    const res = resumeTaskEvidence({
      plan, taskID: args.flags['--task'], evidence,
      repositoryState: { head: BASE_HASH, indexEmpty: true, observedMutations: [], policy: { stage: 'preflight', allowed: [], temporaryRoots: [], journals: ['.g6-beginning'] } },
      taskWorkspace: { repoDir, fs: await import('node:fs') },
    });
    return { result: res, findings: res.findings || [] };
  };
  const ctl2 = createPlanctl({ handlers: new Map([['resume-task', resumeHandler]]) });
  const res = await ctl2.run(['resume-task', '--task', 'P00-T001', '--evidence-path', 'evidence/P00-T001.json']);
  assert.equal(res.exitCode, 0, JSON.stringify(res.findings));
});

// ---------------------------------------------------------------------------
// Cleanup.
// ---------------------------------------------------------------------------

test('cleanup temp dirs', () => { cleanup(); assert.ok(true); });
