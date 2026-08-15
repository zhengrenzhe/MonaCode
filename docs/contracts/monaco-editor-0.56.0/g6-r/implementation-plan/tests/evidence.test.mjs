// G6-R evidence-truth tests (TDD Step 1).
// Proves selectEvidenceCommit enforces the fail-closed first-parent evidence
// contract: the product commit is on repoHead's first-parent ancestry, the
// immediate first-parent successor exists, has the product commit as its sole
// parent, matches the evidence identity/subject contract, changes exactly the
// declared evidence path to the bytes under validation, and no later
// first-parent commit touches that path (rejecting modify-then-restore).
// Builds a real temporary Git history with two completed tasks and proves the
// first task remains valid when HEAD is the second task's evidence commit.
// Node built-in test runner + locked /usr/bin/git only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';
import * as path from 'node:path';

import { selectEvidenceCommit, EVIDENCE_FINDING_IDS } from '../lib/evidence.mjs';
import { makeFinding } from '../lib/findings.mjs';

const GIT = '/usr/bin/git';
const IDENTITY = {
  name: 'zhengrenzhe',
  email: 'zhengrenzhe0416@outlook.com',
};

const dirs = [];
function mktmp() {
  const d = mkdtempSync(path.join(tmpdir(), 'g6r-ev-'));
  dirs.push(d);
  return d;
}
function cleanup() {
  for (const d of dirs) { try { rmSync(d, { recursive: true, force: true }); } catch {} }
}

function sha256(s) {
  return createHash('sha256').update(s, 'utf8').digest('hex');
}

// ---------------------------------------------------------------------------
// Real temporary Git repository helpers
// ---------------------------------------------------------------------------

function makeRepo() {
  const dir = mktmp();
  const env = {
    ...process.env,
    GIT_AUTHOR_NAME: IDENTITY.name, GIT_AUTHOR_EMAIL: IDENTITY.email,
    GIT_COMMITTER_NAME: IDENTITY.name, GIT_COMMITTER_EMAIL: IDENTITY.email,
  };
  gitRun(dir, env, ['init', '-q', '-b', 'main']);
  gitRun(dir, env, ['config', 'user.name', IDENTITY.name]);
  gitRun(dir, env, ['config', 'user.email', IDENTITY.email]);
  gitRun(dir, env, ['config', 'commit.gpgSign', 'false']);
  gitRun(dir, env, ['config', 'core.hooksPath', '/dev/null']);
  return { dir, env };
}

function gitRun(dir, env, args) {
  const r = spawnSync(GIT, ['-C', dir, ...args], { env, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (r.status !== 0) {
    throw new Error(`git ${args.join(' ')} failed (${r.status}): ${r.stderr || r.stdout}`);
  }
  return r;
}

function makeGitRunner(dir, env) {
  return (args) => {
    const r = spawnSync(GIT, ['-C', dir, ...args], { env, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    return { stdout: r.stdout ?? '', stderr: r.stderr ?? '', status: r.status ?? 1 };
  };
}

function commit(dir, env, message, files, opts = {}) {
  for (const [p, content] of Object.entries(files)) {
    const full = path.join(dir, p);
    mkdirSync(path.dirname(full), { recursive: true });
    writeFileSync(full, content);
    gitRun(dir, env, ['add', '--', p]);
  }
  const commitEnv = { ...env };
  if (opts.author) { commitEnv.GIT_AUTHOR_NAME = opts.author.name; commitEnv.GIT_AUTHOR_EMAIL = opts.author.email; }
  if (opts.committer) { commitEnv.GIT_COMMITTER_NAME = opts.committer.name; commitEnv.GIT_COMMITTER_EMAIL = opts.committer.email; }
  gitRun(dir, commitEnv, ['-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgSign=false', 'commit', '--no-verify', '--no-gpg-sign', '-m', message]);
  return gitRun(dir, env, ['rev-parse', 'HEAD']).stdout.trim();
}

function headOf(dir, env) {
  return gitRun(dir, env, ['rev-parse', 'HEAD']).stdout.trim();
}

// Build the canonical two-task linear history:
// base -> t1Product -> t1Evidence -> t2Product -> t2Evidence(=HEAD)
function buildTwoTaskHistory() {
  const { dir, env } = makeRepo();
  const base = commit(dir, env, 'base', { 'README.md': 'base\n' });
  const t1Product = commit(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'foo\n' });
  const t1Evidence = commit(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': '{"v":1}\n' });
  const t2Product = commit(dir, env, 'monacode: complete P00-T002', { 'Sources/Bar.swift': 'bar\n' });
  const t2Evidence = commit(dir, env, 'evidence(monacode): complete P00-T002', { 'evidence/P00-T002.json': '{"v":2}\n' });
  return { dir, env, base, t1Product, t1Evidence, t2Product, t2Evidence, head: t2Evidence };
}

// ---------------------------------------------------------------------------
// Closed finding-id set
// ---------------------------------------------------------------------------

test('EVIDENCE_FINDING_IDS includes the stable evidence-truth findings', () => {
  for (const id of [
    'PLAN_EVIDENCE_PRODUCT_ANCESTRY',
    'PLAN_EVIDENCE_IMMEDIATE_SUCCESSOR',
    'PLAN_EVIDENCE_COMMIT_PARENT',
    'PLAN_EVIDENCE_COMMIT_IDENTITY',
    'PLAN_EVIDENCE_COMMIT_SUBJECT',
    'PLAN_EVIDENCE_COMMIT_BOUNDARY',
    'PLAN_EVIDENCE_BLOB',
    'PLAN_EVIDENCE_LATER_TOUCH',
  ]) {
    assert.ok(EVIDENCE_FINDING_IDS.includes(id), `missing ${id}`);
  }
});

// ---------------------------------------------------------------------------
// Two-completed-task proof: first task remains valid when HEAD is the second
// task's evidence commit (first-parent validity across tasks)
// ---------------------------------------------------------------------------

test('selectEvidenceCommit: task1 evidence valid when HEAD is task2 evidence commit', () => {
  const h = buildTwoTaskHistory();
  const git = makeGitRunner(h.dir, h.env);
  const sel = selectEvidenceCommit({
    repoHead: h.head, productCommit: h.t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('{"v":1}\n'),
  });
  assert.equal(sel.ok, true, `expected ok; findings=${JSON.stringify(sel.findings)}`);
  assert.equal(sel.evidenceCommit, h.t1Evidence);
  assert.equal(sel.taskID, 'P00-T001');
  assert.equal(sel.selectorMode, 'external-git');
  assert.deepEqual(sel.findings, []);
  assert.match(sel.evidenceBlobSha256, /^[0-9a-f]{64}$/);
});

test('selectEvidenceCommit: task2 evidence valid at its own evidence commit (repoHead=t2e)', () => {
  const h = buildTwoTaskHistory();
  const git = makeGitRunner(h.dir, h.env);
  const sel = selectEvidenceCommit({
    repoHead: h.head, productCommit: h.t2Product,
    evidencePath: 'evidence/P00-T002.json', git, taskID: 'P00-T002',
    expectedEvidenceSha256: sha256('{"v":2}\n'),
  });
  assert.equal(sel.ok, true);
  assert.equal(sel.evidenceCommit, h.t2Evidence);
  assert.deepEqual(sel.findings, []);
});

test('selectEvidenceCommit: empty range (productCommit == repoHead) yields IMMEDIATE_SUCCESSOR', () => {
  const h = buildTwoTaskHistory();
  const git = makeGitRunner(h.dir, h.env);
  // productCommit is HEAD (no successor yet) — no evidence commit created.
  const sel = selectEvidenceCommit({
    repoHead: h.t1Product, productCommit: h.t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_IMMEDIATE_SUCCESSOR');
});

// ---------------------------------------------------------------------------
// Mutation matrix — each mutation yields its stable evidence finding ID
// ---------------------------------------------------------------------------

test('PLAN_EVIDENCE_PRODUCT_ANCESTRY: product commit not on first-parent ancestry', () => {
  // Build a history where productCommit lives on a side branch off base, not
  // on repoHead's first-parent chain.
  const { dir, env } = makeRepo();
  const base = commit(dir, env, 'base', { 'README.md': 'x\n' });
  gitRun(dir, env, ['checkout', '-q', '-b', 'side']);
  const sideProduct = commit(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f\n' });
  const sideEvidence = commit(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': '{}\n' });
  gitRun(dir, env, ['checkout', '-q', 'main']);
  const unrelated = commit(dir, env, 'unrelated', { 'Other.txt': 'y\n' });
  const git = makeGitRunner(dir, env);
  const sel = selectEvidenceCommit({
    repoHead: unrelated, productCommit: sideProduct,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_PRODUCT_ANCESTRY');
});

test('PLAN_EVIDENCE_COMMIT_PARENT: evidence commit sole parent != product commit', () => {
  // Use the synthetic runner to isolate the sole-parent invariant: the
  // immediate first-parent successor exists and is on the ancestry, but its
  // sole recorded parent is a different commit than the product commit.
  const ev = 'e'.repeat(40);
  const pc = '1'.repeat(40);
  const rh = '2'.repeat(40);
  const other = '3'.repeat(40);
  const git = syntheticGit({
    ancestry: [rh, ev, pc, '0'.repeat(40)],
    successorRange: [pc, [ev]],
    parents: { [ev]: [other] },            // sole parent is `other`, not pc
    identity: { [ev]: goodIdentity() },
    subject: { [ev]: 'evidence(monacode): complete P00-T001' },
    diff: { [ev]: ['evidence/P00-T001.json'] },
    blob: { [ev]: sha256('c') },
    blobContent: { [ev]: 'c' },
    later: [],
  });
  const sel = selectEvidenceCommit({
    repoHead: rh, productCommit: pc, evidencePath: 'evidence/P00-T001.json',
    git, taskID: 'P00-T001', expectedEvidenceSha256: sha256('c'),
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_COMMIT_PARENT');
});

test('PLAN_EVIDENCE_COMMIT_IDENTITY: evidence commit author wrong', () => {
  const { dir, env } = makeRepo();
  const base = commit(dir, env, 'base', { 'R': 'b' });
  const t1Product = commit(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1Evidence = commit(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': '{}' },
    { author: { name: 'wrong', email: 'wrong@example.com' } });
  const git = makeGitRunner(dir, env);
  const sel = selectEvidenceCommit({
    repoHead: t1Evidence, productCommit: t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('{}'),
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_COMMIT_IDENTITY');
});

test('PLAN_EVIDENCE_COMMIT_SUBJECT: evidence commit subject wrong', () => {
  const { dir, env } = makeRepo();
  const base = commit(dir, env, 'base', { 'R': 'b' });
  const t1Product = commit(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1Evidence = commit(dir, env, 'wrong subject', { 'evidence/P00-T001.json': '{}' });
  const git = makeGitRunner(dir, env);
  const sel = selectEvidenceCommit({
    repoHead: t1Evidence, productCommit: t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('{}'),
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_COMMIT_SUBJECT');
});

test('PLAN_EVIDENCE_COMMIT_BOUNDARY: evidence commit touches a second path', () => {
  const { dir, env } = makeRepo();
  const base = commit(dir, env, 'base', { 'R': 'b' });
  const t1Product = commit(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1Evidence = commit(dir, env, 'evidence(monacode): complete P00-T001',
    { 'evidence/P00-T001.json': '{}', 'Sources/Extra.swift': 'x' });
  const git = makeGitRunner(dir, env);
  const sel = selectEvidenceCommit({
    repoHead: t1Evidence, productCommit: t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('{}'),
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_COMMIT_BOUNDARY');
});

test('PLAN_EVIDENCE_BLOB: evidence blob bytes != bytes under validation', () => {
  const { dir, env } = makeRepo();
  const base = commit(dir, env, 'base', { 'R': 'b' });
  const t1Product = commit(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1Evidence = commit(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': 'actual-bytes' });
  const git = makeGitRunner(dir, env);
  const sel = selectEvidenceCommit({
    repoHead: t1Evidence, productCommit: t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('expected-bytes'),
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_BLOB');
});

test('PLAN_EVIDENCE_LATER_TOUCH: a later first-parent commit modifies the evidence path', () => {
  const { dir, env } = makeRepo();
  const base = commit(dir, env, 'base', { 'R': 'b' });
  const t1Product = commit(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1Evidence = commit(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': '{}' });
  const laterModify = commit(dir, env, 'later modify evidence', { 'evidence/P00-T001.json': 'changed' });
  const git = makeGitRunner(dir, env);
  const sel = selectEvidenceCommit({
    repoHead: laterModify, productCommit: t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('{}'),
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_LATER_TOUCH');
});

test('PLAN_EVIDENCE_LATER_TOUCH: modify-then-restore sequence is still rejected', () => {
  const { dir, env } = makeRepo();
  const base = commit(dir, env, 'base', { 'R': 'b' });
  const t1Product = commit(dir, env, 'monacode: complete P00-T001', { 'Sources/Foo.swift': 'f' });
  const t1Evidence = commit(dir, env, 'evidence(monacode): complete P00-T001', { 'evidence/P00-T001.json': 'orig' });
  const modify = commit(dir, env, 'modify', { 'evidence/P00-T001.json': 'changed' });
  // restore to the original bytes
  const restore = commit(dir, env, 'restore', { 'evidence/P00-T001.json': 'orig' });
  const git = makeGitRunner(dir, env);
  const sel = selectEvidenceCommit({
    repoHead: restore, productCommit: t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('orig'),
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings.length, 1);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_LATER_TOUCH');
});

// ---------------------------------------------------------------------------
// Determinism — stable finding IDs across two runs
// ---------------------------------------------------------------------------

test('selectEvidenceCommit produces stable findings across two runs', () => {
  const h = buildTwoTaskHistory();
  const git = makeGitRunner(h.dir, h.env);
  const r1 = selectEvidenceCommit({
    repoHead: h.head, productCommit: h.t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('wrong'),
  });
  const r2 = selectEvidenceCommit({
    repoHead: h.head, productCommit: h.t1Product,
    evidencePath: 'evidence/P00-T001.json', git, taskID: 'P00-T001',
    expectedEvidenceSha256: sha256('wrong'),
  });
  assert.deepEqual(r1.findings, r2.findings);
  assert.equal(r1.findings[0].id, 'PLAN_EVIDENCE_BLOB');
});

// ---------------------------------------------------------------------------
// Synthetic git runner — unit-level isolation of the ancestry + successor
// enumeration logic without touching the filesystem
// ---------------------------------------------------------------------------

function goodIdentity() {
  return { name: IDENTITY.name, email: IDENTITY.email };
}

function syntheticGit(spec) {
  const ancestrySet = new Set(spec.ancestry);
  return (args) => {
    const key = args.join(' ');
    // rev-list --first-parent <repoHead>  -> ancestry chain
    if (args[0] === 'rev-list' && args[1] === '--first-parent' && args.length === 3 && !args[2].includes('..')) {
      return { stdout: spec.ancestry.join('\n') + '\n', stderr: '', status: 0 };
    }
    // rev-list --first-parent <productCommit>..<repoHead>
    if (args[0] === 'rev-list' && args[1] === '--first-parent' && args.length === 3 && args[2].includes('..')) {
      const range = spec.successorRange;
      // range is [productCommit, [chronoList]]; but we store the rev-list output (reverse chrono)
      const [pc, list] = spec.successorRange;
      if (args[2].startsWith(pc + '..')) {
        // rev-list outputs reverse-chrono (newest first); our list is chronological
        return { stdout: [...list].reverse().join('\n') + (list.length ? '\n' : ''), stderr: '', status: 0 };
      }
      return { stdout: '', stderr: '', status: 0 };
    }
    // rev-list --first-parent <evidenceCommit>..<repoHead> -- <evidencePath>
    if (args[0] === 'rev-list' && args[1] === '--first-parent' && args.length === 5 && args[3] === '--') {
      return { stdout: spec.later.join('\n') + (spec.later.length ? '\n' : ''), stderr: '', status: 0 };
    }
    // show -s --format=... <commit>
    if (args[0] === 'show' && args[1] === '-s') {
      const fmt = args[2];
      const commit = args[3];
      if (fmt === '--format=%P') {
        return { stdout: (spec.parents[commit] || []).join(' ') + '\n', stderr: '', status: 0 };
      }
      if (fmt.startsWith('--format=%an%n%ae%n%cn%n%ce%n%s')) {
        const id = spec.identity[commit] || { name: '', email: '' };
        const subj = spec.subject[commit] || '';
        return { stdout: `${id.name}\n${id.email}\n${id.name}\n${id.email}\n${subj}\n`, stderr: '', status: 0 };
      }
    }
    // diff-tree -r --no-commit-id --name-only <commit>
    if (args[0] === 'diff-tree' && args.includes('--name-only')) {
      const commit = args[args.length - 1];
      const paths = spec.diff[commit] || [];
      return { stdout: paths.join('\n') + (paths.length ? '\n' : ''), stderr: '', status: 0 };
    }
    // cat-file blob <commit>:<path>
    if (args[0] === 'cat-file' && args[1] === 'blob') {
      const ref = args[2];
      const [commit] = ref.split(':');
      const content = spec.blobContent && spec.blobContent[commit] !== undefined ? spec.blobContent[commit] : '';
      return { stdout: content, stderr: '', status: 0 };
    }
    // ls-tree / rev-parse fallback
    if (args[0] === 'rev-parse' && args[1] && args[1].includes(':')) {
      const [commit, p] = args[1].split(':');
      return { stdout: spec.blob[commit] || '', stderr: '', status: 0 };
    }
    return { stdout: '', stderr: '', status: 0 };
  };
}

test('synthetic runner: valid selection returns ok with evidenceCommit', () => {
  const ev = 'e'.repeat(40);
  const pc = '1'.repeat(40);
  const rh = '2'.repeat(40);
  const git = syntheticGit({
    ancestry: [rh, ev, pc, '0'.repeat(40)],
    successorRange: [pc, [ev]],            // chronological list: [ev]
    parents: { [ev]: [pc] },
    identity: { [ev]: goodIdentity() },
    subject: { [ev]: 'evidence(monacode): complete P00-T001' },
    diff: { [ev]: ['evidence/P00-T001.json'] },
    blob: { [ev]: sha256('content') },
    blobContent: { [ev]: 'content' },
    later: [],
  });
  const sel = selectEvidenceCommit({
    repoHead: rh, productCommit: pc, evidencePath: 'evidence/P00-T001.json',
    git, taskID: 'P00-T001', expectedEvidenceSha256: sha256('content'),
  });
  assert.equal(sel.ok, true);
  assert.equal(sel.evidenceCommit, ev);
  assert.deepEqual(sel.findings, []);
});

test('synthetic runner: taskID mismatch in subject yields COMMIT_SUBJECT', () => {
  const ev = 'e'.repeat(40);
  const pc = '1'.repeat(40);
  const rh = '2'.repeat(40);
  const git = syntheticGit({
    ancestry: [rh, ev, pc, '0'.repeat(40)],
    successorRange: [pc, [ev]],
    parents: { [ev]: [pc] },
    identity: { [ev]: goodIdentity() },
    subject: { [ev]: 'evidence(monacode): complete P00-T099' },
    diff: { [ev]: ['evidence/P00-T001.json'] },
    blob: { [ev]: sha256('c') },
    blobContent: { [ev]: 'c' },
    later: [],
  });
  const sel = selectEvidenceCommit({
    repoHead: rh, productCommit: pc, evidencePath: 'evidence/P00-T001.json',
    git, taskID: 'P00-T001', expectedEvidenceSha256: sha256('c'),
  });
  assert.equal(sel.ok, false);
  assert.equal(sel.findings[0].id, 'PLAN_EVIDENCE_COMMIT_SUBJECT');
});

// ---------------------------------------------------------------------------
// Teardown
// ---------------------------------------------------------------------------

test('teardown cleans temp repos', () => {
  cleanup();
  assert.ok(true);
});

// Run cleanup after the suite regardless of outcome.
process.on('exit', cleanup);
process.on('SIGINT', () => { cleanup(); process.exit(130); });
