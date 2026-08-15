// G6-R command executor tests (TDD Step 1).
// Proves executeVerificationCommand (ordered leaves, all-success short-circuit,
// pipeline pipefail, timeout termination, stream hashing, 8 MiB stream cap,
// expected-result matching, running-evidence update via a .g6-part transient
// that is absent before and after a successful call, toolchain drift, and the
// recorded executor/sandbox-profile hashes), the production sandbox loopback
// network denial and outside-root write denial, acquireSource (deterministic
// HTTPS client + attack scheme), commitTask (sole product-commit creator with
// rejection cases and stop/rerun convergence), and finalizeEvidence (convergence
// to one evidence commit, self-embedding rejection). Node test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync, spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, statSync, readdirSync, renameSync, openSync, writeSync, closeSync, fsyncSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { createHash, randomBytes } from 'node:crypto';
import * as path from 'node:path';
import { createServer } from 'node:net';

import {
  executeVerificationCommand,
  acquireSource,
  commitTask,
  finalizeEvidence,
  verifyToolchain,
  buildSandboxProfile,
  STREAM_CAP,
  KILL_GRACE_MS,
} from '../lib/command-executor.mjs';
import { canonicalJSONStringify } from '../lib/canonical-json.mjs';

const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const GIT = '/usr/bin/git';
const SANDBOX = '/usr/bin/sandbox-exec';
const IDENTITY = { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' };

const TOOLCHAIN = {
  node: { path: NODE, sha256: '1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040', version: 'v26.7.0' },
  xcrun: { path: '/usr/bin/xcrun', sha256: '4bc0cc7099775fbe35c653ceb09e0e393d2e5ada024db872e0eb8c43500b4dc6' },
  sandboxExec: { path: SANDBOX, sha256: 'e3d7a792c58a5d3783d2f7274c82d70062393830d8cb1ded713ca554a470bd2f' },
  git: { path: GIT, sha256: '44a68ddc1983d6cff3fd35ba3f9ba5f82004216f1dcde69892b3d1b06e408698', version: '2.50.1 (Apple Git-155)' },
  bsdtar: { path: '/usr/bin/bsdtar', sha256: 'bc069dd7ef2ecea4c27ff9daa97f4ba4c5a1a41938bad8050e96bce5daa64346', version: '3.5.3' },
  swift: { path: '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift', sha256: '2ed38571e92c0283091838c1649e27650ad9c99950288e883c7b2dc6c4ce89fb' },
  chrome: { path: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', sha256: 'ee37661755341e9fc1babf9c20ec09d6a36e50aa8713ceb08082f8bbe2d8217d', version: '151.0.7922.138' },
  systemProfiler: { path: '/usr/sbin/system_profiler', sha256: '6b868d95b01d44045fc434d5e867cd9ac5de15634fef126522d0a6919ccd2652' },
};

const dirs = [];
function mktmp() { const d = mkdtempSync(path.join(tmpdir(), 'g6r-ce-')); dirs.push(d); return d; }
function cleanup() { for (const d of dirs) { try { rmSync(d, { recursive: true, force: true }); } catch {} } }
function sha256(b) { return createHash('sha256').update(b).digest('hex'); }

// A real git repo with one base commit, for executor tests (the executor
// captures `git status --porcelain=v2` before and after each command).
function makeExecutorRepo() {
  const dir = mktmp();
  const env = { ...process.env, GIT_AUTHOR_NAME: IDENTITY.name, GIT_AUTHOR_EMAIL: IDENTITY.email, GIT_COMMITTER_NAME: IDENTITY.name, GIT_COMMITTER_EMAIL: IDENTITY.email, LC_ALL: 'C', TZ: 'UTC' };
  spawnSync(GIT, ['-C', dir, 'init', '-q', '-b', 'main'], { env, encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'core.hooksPath', '/dev/null'], { env, encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'commit.gpgSign', 'false'], { env, encoding: 'utf8' });
  writeFileSync(path.join(dir, 'README'), 'r');
  spawnSync(GIT, ['-C', dir, 'add', '--', 'README'], { env, encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgSign=false', 'commit', '--no-verify', '--no-gpg-sign', '-m', 'base'], { env, encoding: 'utf8' });
  return dir;
}

// ---------------------------------------------------------------------------
// Task-root + running-evidence fixture for executor tests.
// ---------------------------------------------------------------------------

function makeTaskRoot(taskID = 'P00-T001') {
  const rootParent = mktmp();
  const token = randomBytes(32);
  const tokenSha256 = sha256(token);
  const rootName = `monacode-g6-${taskID}-${tokenSha256.slice(0, 16)}`;
  const taskRoot = path.join(rootParent, rootName);
  mkdirSync(taskRoot, { recursive: true, mode: 0o700 });
  const marker = path.join(taskRoot, '.token');
  const fd = openSync(marker, 'w', 0o600);
  writeSync(fd, token);
  fsyncSync(fd);
  closeSync(fd);
  return { rootParent, taskRoot, token, tokenSha256 };
}

function writeRunning(repoDir, evidencePath, running) {
  const full = path.join(repoDir, evidencePath);
  mkdirSync(path.dirname(full), { recursive: true });
  writeFileSync(full, canonicalJSONStringify(running));
  return full;
}

function baseRunning(taskRoot, tokenSha256, overrides = {}) {
  return {
    taskID: 'P00-T001',
    state: 'running',
    tokenSha256,
    taskRoot,
    currentStage: 'green',
    lifecycleState: 'running',
    baseCommit: 'b'.repeat(40),
    planHash: 'a'.repeat(40),
    taskHash: '1'.repeat(40),
    commandResults: [],
    acquisitionResults: [],
    assertionResults: [],
    fileHashes: [],
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Toolchain lock comparison.
// ---------------------------------------------------------------------------

test('verifyToolchain: accepts the exact Task 1 lock', () => {
  const f = verifyToolchain(TOOLCHAIN);
  assert.equal(f.length, 0, JSON.stringify(f));
});

test('verifyToolchain: drift in any locked field is a finding', () => {
  const drifted = JSON.parse(JSON.stringify(TOOLCHAIN));
  drifted.node.sha256 = '0'.repeat(64);
  const f = verifyToolchain(drifted);
  assert.ok(f.length >= 1);
  assert.equal(f[0].id, 'PLAN_TOOLCHAIN_DRIFT');
});

test('verifyToolchain: missing executable is a finding', () => {
  const partial = { ...TOOLCHAIN, sandboxExec: undefined };
  const f = verifyToolchain(partial);
  assert.ok(f.length >= 1);
  assert.equal(f[0].id, 'PLAN_TOOLCHAIN_DRIFT');
});

// ---------------------------------------------------------------------------
// Sandbox profile.
// ---------------------------------------------------------------------------

test('buildSandboxProfile: denies network and file-write outside the realpath temp root', () => {
  const tmp = mktmp();
  const { profile, hash } = buildSandboxProfile(tmp);
  assert.match(profile, /\(deny network\*\)/);
  assert.match(profile, /\(deny file-write\*/);
  assert.match(profile, new RegExp(tmp.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  assert.equal(hash.length, 64);
  rmSync(tmp, { recursive: true, force: true });
});

// ---------------------------------------------------------------------------
// executeVerificationCommand — synthetic process record.
// ---------------------------------------------------------------------------

function leafScript(script, opts = {}) {
  const args = ['-e', script];
  return { leafID: opts.leafID || 'L.001', executable: NODE, args, timeoutMs: opts.timeoutMs || 30000, form: 'node-script', stage: opts.stage || 'green' };
}

test('executeVerificationCommand: process leaf records exit/stdout/stderr hashes and advances running evidence', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  const running = baseRunning(taskRoot, tokenSha256);
  writeRunning(repoDir, evidencePath, running);
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: ['ok\n'], leaves: [
      leafScript("process.stdout.write('ok\\n');", { leafID: 'P00-T001.GREEN.001.PROC.001' }),
    ],
  };
  // .g6-part must be absent before.
  assert.ok(!existsSync(path.join(repoDir, evidencePath + '.g6-part')));
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  assert.ok(res.result.expectedResult, 'expected result should be true');
  const leaf = res.result.leaves[0];
  assert.equal(leaf.exitStatus, 0);
  assert.equal(leaf.stdoutHash, sha256('ok\n'));
  assert.equal(leaf.parentCommandID, 'P00-T001.GREEN.001');
  assert.equal(res.result.executorHash.length, 64);
  assert.equal(res.result.sandboxProfileHash.length, 64);
  assert.equal(res.result.beforeStateHash, res.result.afterStateHash, 'read-only command: state unchanged');
  // .g6-part absent after.
  assert.ok(!existsSync(path.join(repoDir, evidencePath + '.g6-part')));
  // Running evidence now contains the command result.
  const updated = JSON.parse(readFileSync(path.join(repoDir, evidencePath), 'utf8'));
  assert.equal(updated.commandResults.length, 1);
  assert.equal(updated.commandResults[0].executorHash, res.result.executorHash);
  assert.equal(updated.commandResults[0].sandboxProfileHash, res.result.sandboxProfileHash);
});

test('executeVerificationCommand: expected-result mismatch when exit code differs', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: [], leaves: [
      leafScript("process.exit(2);", { leafID: 'P00-T001.GREEN.001.PROC.001' }),
    ],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.equal(res.result.expectedResult, false);
  assert.ok(res.findings.some((f) => f.id === 'PLAN_COMMAND_RESULT_MISMATCH'), JSON.stringify(res.findings));
});

// ---------------------------------------------------------------------------
// all-success: ordered leaves, short-circuit after first non-zero.
// ---------------------------------------------------------------------------

test('executeVerificationCommand: all-success runs leaves in order and short-circuits on first non-zero', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  // Leaf 2 writes a marker to the command child; leaf 3 should never run.
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'all-success', networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: [],
    leaves: [
      leafScript("process.stdout.write('one\\n');", { leafID: 'P00-T001.GREEN.001.PROC.001' }),
      leafScript("process.exit(3);", { leafID: 'P00-T001.GREEN.001.PROC.002' }),
      leafScript("process.exit(0);", { leafID: 'P00-T001.GREEN.001.PROC.003' }),
    ],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.equal(res.result.expectedResult, false);
  assert.equal(res.result.leaves.length, 2, 'short-circuit should stop after leaf 2');
  assert.equal(res.result.leaves[0].exitStatus, 0);
  assert.equal(res.result.leaves[1].exitStatus, 3);
});

// ---------------------------------------------------------------------------
// pipeline: connected streams, aggregate pipefail.
// ---------------------------------------------------------------------------

test('executeVerificationCommand: pipeline connects stdout to stdin and aggregates pipefail', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const producer = "process.stdout.write('payload\\n');";
  const consumer = "let s='';process.stdin.setEncoding('utf8');process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{process.stdout.write(s); if(s.trim()!=='payload') process.exit(4);});";
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'pipeline', pipefail: true, networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: ['payload'],
    leaves: [
      leafScript(producer, { leafID: 'P00-T001.GREEN.001.PROC.001' }),
      leafScript(consumer, { leafID: 'P00-T001.GREEN.001.PROC.002' }),
    ],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  assert.equal(res.result.leaves[1].stdoutHash, sha256('payload\n'));
});

test('executeVerificationCommand: pipeline pipefail surfaces a non-zero leaf', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const producer = "process.stdout.write('payload\\n');";
  const failing = "process.exit(5);";
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'pipeline', pipefail: true, networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: [],
    leaves: [
      leafScript(producer, { leafID: 'P00-T001.GREEN.001.PROC.001' }),
      leafScript(failing, { leafID: 'P00-T001.GREEN.001.PROC.002' }),
    ],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.equal(res.result.expectedResult, false);
});

// ---------------------------------------------------------------------------
// Timeout: SIGTERM then SIGKILL after the grace period.
// ---------------------------------------------------------------------------

test('executeVerificationCommand: timeout terminates the leaf (TERM then KILL)', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 800,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: [],
    leaves: [leafScript("setTimeout(()=>{},60000);", { leafID: 'P00-T001.GREEN.001.PROC.001', timeoutMs: 800 })],
  };
  const t0 = Date.now();
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  const elapsed = Date.now() - t0;
  assert.equal(res.result.expectedResult, false);
  assert.ok(res.findings.some((f) => f.id === 'PLAN_COMMAND_TIMEOUT'), JSON.stringify(res.findings));
  assert.ok(elapsed < 20000, `timeout took too long: ${elapsed}ms`);
});

// ---------------------------------------------------------------------------
// Stream cap overflow (8 MiB).
// ---------------------------------------------------------------------------

test('STREAM_CAP is exactly 8,388,608 bytes', () => {
  assert.equal(STREAM_CAP, 8388608);
});

test('KILL_GRACE_MS is exactly 5000 ms', () => {
  assert.equal(KILL_GRACE_MS, 5000);
});

test('executeVerificationCommand: stream cap overflow is a finding', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  // Write 9 MiB to stdout.
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: [],
    leaves: [leafScript("process.stdout.write(Buffer.alloc(9*1024*1024).fill(65));", { leafID: 'P00-T001.GREEN.001.PROC.001' })],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_COMMAND_STREAM_CAP'), JSON.stringify(res.findings));
});

// ---------------------------------------------------------------------------
// Loopback network denial under the production sandbox.
// ---------------------------------------------------------------------------

function startLoopback() {
  return new Promise((resolve) => {
    const server = createServer((c) => { c.on('data', () => c.write('PONG\n')); });
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port }));
  });
}

test('executeVerificationCommand: verification leaf CANNOT connect to a loopback server (sandbox denies network)', async () => {
  const { server, port } = await startLoopback();
  try {
    const repoDir = mktmp();
    const { taskRoot, tokenSha256 } = makeTaskRoot();
    const evidencePath = 'evidence/P00-T001.json';
    writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
    const connectScript = `
      const net = require('node:net');
      const s = net.createConnection({ host: '127.0.0.1', port: ${port} }, () => { s.write('PING\\n'); });
      s.on('error', () => process.exit(7));
      setTimeout(() => { process.exit(8); }, 4000);
    `;
    const command = {
      commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 20000,
      stage: 'green', expectedExit: 0, expectedOutputIncludes: [],
      leaves: [leafScript(connectScript, { leafID: 'P00-T001.GREEN.001.PROC.001' })],
    };
    const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
    // The leaf must not have connected: exit 7 (ECONNREFUSED/EPERM) or 8 (timeout).
    assert.equal(res.result.expectedResult, false);
    assert.notEqual(res.result.leaves[0].exitStatus, 0, 'leaf should not have exited 0 (connected)');
    assert.ok(res.findings.length >= 1, 'network denial should produce a finding');
  } finally {
    server.close();
  }
});

// ---------------------------------------------------------------------------
// Outside-root write denial + inside-root write allowed.
// ---------------------------------------------------------------------------

test('executeVerificationCommand: only the fresh command child below the task root is writable', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  // The leaf receives the command child temp root via COMMAND_TEMP env var and
  // writes inside it (succeeds) then attempts to write outside (fails).
  const probeScript = `
    const fs = require('node:fs');
    const path = require('node:path');
    const child = process.env.TMPDIR;
    // Inside write must succeed.
    fs.writeFileSync(path.join(child, 'inside.txt'), 'ok');
    // Outside write must be denied.
    let outsideDenied = false;
    try { fs.writeFileSync(path.join(${JSON.stringify(repoDir)}, 'outside.txt'), 'x'); }
    catch (e) { outsideDenied = true; }
    process.stdout.write(outsideDenied ? 'DENIED\\n' : 'WROTE\\n');
    process.exit(outsideDenied ? 0 : 9);
  `;
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 20000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: ['DENIED'],
    leaves: [leafScript(probeScript, { leafID: 'P00-T001.GREEN.001.PROC.001' })],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  // The command child is removed after the call.
  assert.ok(!existsSync(path.join(repoDir, 'outside.txt')), 'outside file must not exist');
});

test('executeVerificationCommand: toolchain drift blocks execution', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const drifted = JSON.parse(JSON.stringify(TOOLCHAIN));
  drifted.node.sha256 = '0'.repeat(64);
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: [],
    leaves: [leafScript("process.exit(0);", { leafID: 'P00-T001.GREEN.001.PROC.001' })],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: drifted });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_TOOLCHAIN_DRIFT'));
});

test('executeVerificationCommand: a stray .g6-beginning journal row during run-command is a finding', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  // A stray beginning journal in the worktree.
  writeFileSync(path.join(repoDir, evidencePath + '.g6-beginning'), '{}');
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: [],
    leaves: [leafScript("process.exit(0);", { leafID: 'P00-T001.GREEN.001.PROC.001' })],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_EVIDENCE_JOURNAL_STATE'), JSON.stringify(res.findings));
});

test('executeVerificationCommand: a stray evidence row during run-command is a finding', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  // A stray evidence file for a different task.
  mkdirSync(path.join(repoDir, 'evidence'), { recursive: true });
  writeFileSync(path.join(repoDir, 'evidence/P00-T002.json'), '{}');
  const command = {
    commandID: 'P00-T001.GREEN.001', kind: 'process', networkMode: 'forbidden', timeoutMs: 30000,
    stage: 'green', expectedExit: 0, expectedOutputIncludes: [],
    leaves: [leafScript("process.exit(0);", { leafID: 'P00-T001.GREEN.001.PROC.001' })],
  };
  const res = await executeVerificationCommand({ command, task: { taskID: 'P00-T001' }, repoRoot: repoDir, evidencePath, toolchain: TOOLCHAIN });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_EVIDENCE_JOURNAL_STATE'), JSON.stringify(res.findings));
});

// ---------------------------------------------------------------------------
// acquireSource — deterministic HTTPS client + attack scheme.
// ---------------------------------------------------------------------------

// A deterministic HTTPS client that tests inject. It returns a controlled
// response stream without touching the network.
function makeClient(responses) {
  return async function httpsClient(opts) {
    const key = `${opts.host}:${opts.port}:${opts.path}`;
    const r = responses[key] || responses[opts.url] || responses.default;
    if (!r) throw new Error('no client response for ' + opts.url);
    if (r.throwErr) throw new Error(r.throwErr);
    return {
      statusCode: r.statusCode,
      headers: r.headers || {},
      async *stream() { for (const chunk of r.chunks || [r.body || Buffer.alloc(0)]) yield chunk; },
    };
  };
}

function baseAcquisition(overrides = {}) {
  return {
    sourceID: 'SRC-1',
    url: 'https://example.com/file.bin',
    host: 'example.com',
    port: 443,
    redirectChain: [],
    expectedBytes: 4,
    expectedSha256: sha256(Buffer.from('data')),
    license: 'MIT',
    disposition: 'task-step',
    outputPath: 'acquired/file.bin',
    maxBytes: 1048576,
    timeoutMs: 30000,
    archive: null,
    ...overrides,
  };
}

function acquisitionTask(taskRoot, overrides = {}) {
  return {
    taskID: 'P00-T001',
    workspace: { taskRoot, ownershipToken: '0'.repeat(64) },
    ...overrides,
  };
}

test('acquireSource: happy path streams, hashes, fsyncs, atomically renames, records hashes', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const body = Buffer.from('data');
  const src = baseAcquisition({ expectedSha256: sha256(body), expectedBytes: body.length, outputPath: 'acquired/file.bin' });
  const client = makeClient({
    'example.com:443:/file.bin': { statusCode: 200, headers: { 'content-length': String(body.length) }, chunks: [body] },
  });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  assert.ok(existsSync(path.join(repoDir, 'acquired/file.bin')));
  // .g6-part transient removed.
  assert.ok(!existsSync(path.join(repoDir, 'acquired/file.bin.g6-part')));
  // Running evidence has the acquisition result.
  const updated = JSON.parse(readFileSync(path.join(repoDir, evidencePath), 'utf8'));
  assert.equal(updated.acquisitionResults.length, 1);
  assert.equal(updated.acquisitionResults[0].sha256, 'sha256:' + sha256(body));
});

test('acquireSource: non-200 status is rejected', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const src = baseAcquisition();
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 404 } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_STATUS'));
  assert.ok(!existsSync(path.join(repoDir, 'acquired/file.bin')));
});

test('acquireSource: byte-count mismatch is rejected', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const body = Buffer.from('data');
  const src = baseAcquisition({ expectedBytes: 99 });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [body] } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_BYTES'));
});

test('acquireSource: sha256 mismatch is rejected', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const body = Buffer.from('data');
  const src = baseAcquisition({ expectedSha256: '0'.repeat(64) });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [body] } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_HASH'));
});

test('acquireSource: max-bytes cap is enforced', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const big = Buffer.alloc(2048, 65);
  const src = baseAcquisition({ maxBytes: 1024, expectedBytes: big.length, expectedSha256: sha256(big) });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [big] } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_MAX_BYTES'));
});

test('acquireSource: credentials in URL are rejected', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const src = baseAcquisition({ url: 'https://user:pass@example.com/file.bin', host: 'example.com' });
  const client = makeClient({ default: { statusCode: 200 } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_CREDENTIAL'));
});

test('acquireSource: wrong host is rejected', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const src = baseAcquisition({ host: 'wrong.example.com' });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200 } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_HOST'));
});

test('acquireSource: unexpected redirect chain is rejected', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const body = Buffer.from('data');
  const src = baseAcquisition({ redirectChain: [], expectedSha256: sha256(body), expectedBytes: body.length });
  // The client reports a redirect to a different host.
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 301, headers: { location: 'https://evil.com/file.bin' } } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_REDIRECT'));
});

test('acquireSource: idempotent same-hash reuse succeeds without re-downloading', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const body = Buffer.from('data');
  const src = baseAcquisition({ expectedSha256: sha256(body), expectedBytes: body.length, outputPath: 'acquired/file.bin' });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [body] } });
  // Pre-existing output with matching hash.
  mkdirSync(path.join(repoDir, 'acquired'), { recursive: true });
  writeFileSync(path.join(repoDir, 'acquired/file.bin'), body);
  let calls = 0;
  const countingClient = async (opts) => { calls++; return client(opts); };
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: countingClient });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  assert.equal(calls, 0, 'should not re-download a matching pre-existing output');
});

test('acquireSource: foreign workspace token is rejected', async () => {
  const repoDir = mktmp();
  const otherRoot = mktmp();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const body = Buffer.from('data');
  // The acquisition targets a path under a foreign task root.
  const src = baseAcquisition({ expectedSha256: sha256(body), expectedBytes: body.length, outputPath: path.relative(repoDir, path.join(otherRoot, 'stolen.bin')) });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [body] } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.length >= 1);
});

// ---------------------------------------------------------------------------
// acquireSource — archive (bsdtar) extraction.
// ---------------------------------------------------------------------------

function makeArchive(buildFn) {
  const buildDir = mktmp();
  buildFn(buildDir);
  const archivePath = path.join(mktmp(), 'archive.tar');
  // Archive the `pkg` directory inside buildDir so entries are `pkg/...`.
  const r = spawnSync('/usr/bin/bsdtar', ['-cf', archivePath, '-C', buildDir, 'pkg'], { encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`bsdtar cf failed: ${r.stderr}`);
  const bytes = readFileSync(archivePath);
  const sum = sha256(bytes);
  // Count entries + expanded bytes from the listing.
  const list = spawnSync('/usr/bin/bsdtar', ['-tvf', archivePath], { encoding: 'utf8' });
  const entries = list.stdout.split('\n').filter((l) => l.trim());
  const expandedBytes = entries.reduce((s, l) => {
    const parts = l.split(/\s+/);
    return s + (Number(parts[4]) || 0);
  }, 0);
  return { bytes, sum, entries: entries.length, expandedBytes, archivePath };
}

test('acquireSource: archive row extracts to the declared output with exact count/bytes + recorded hashes', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const arch = makeArchive((d) => {
    mkdirSync(path.join(d, 'pkg'), { recursive: true });
    writeFileSync(path.join(d, 'pkg/file1.txt'), 'data');
    writeFileSync(path.join(d, 'pkg/file2.txt'), 'more!');
  });
  const src = baseAcquisition({
    expectedSha256: arch.sum, expectedBytes: arch.bytes.length,
    outputPath: 'acquired',
    archive: { expectedEntries: arch.entries, expectedExpandedBytes: arch.expandedBytes },
  });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, headers: { 'content-length': String(arch.bytes.length) }, chunks: [arch.bytes] } })
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  // The output directory exists with the extracted files.
  assert.ok(existsSync(path.join(repoDir, 'acquired/pkg/file1.txt')));
  assert.ok(existsSync(path.join(repoDir, 'acquired/pkg/file2.txt')));
  assert.equal(readFileSync(path.join(repoDir, 'acquired/pkg/file1.txt'), 'utf8'), 'data');
  // .g6-part removed.
  assert.ok(!existsSync(path.join(repoDir, 'acquired.g6-part')));
  // Running evidence records the archive/collision/probe hashes.
  const updated = JSON.parse(readFileSync(path.join(repoDir, evidencePath), 'utf8'));
  assert.equal(updated.acquisitionResults.length, 1);
  assert.ok(updated.acquisitionResults[0].archiveHash.length === 64);
  assert.ok(updated.acquisitionResults[0].collisionKeyHash.length === 64);
});

test('acquireSource: archive rejects a symlink entry before extraction', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const arch = makeArchive((d) => {
    mkdirSync(path.join(d, 'pkg'), { recursive: true });
    writeFileSync(path.join(d, 'pkg/file1.txt'), 'data');
    // Create a symlink entry inside the archive.
    try { symlinkSync('/etc/hosts', path.join(d, 'pkg/evil')); } catch {}
  });
  const src = baseAcquisition({
    expectedSha256: arch.sum, expectedBytes: arch.bytes.length,
    outputPath: 'acquired',
    archive: { expectedEntries: arch.entries, expectedExpandedBytes: arch.expandedBytes },
  });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [arch.bytes] } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_ARCHIVE_INVALID'), JSON.stringify(res.findings));
  assert.ok(!existsSync(path.join(repoDir, 'acquired')));
});

test('acquireSource: archive rejects duplicate NFC collision-key entries', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  // Build a tar with a duplicate entry name (append the same file twice).
  const buildDir = mktmp();
  mkdirSync(path.join(buildDir, 'pkg'), { recursive: true });
  writeFileSync(path.join(buildDir, 'pkg/dup.txt'), 'x');
  const archivePath = path.join(mktmp(), 'dup.tar');
  spawnSync('/usr/bin/bsdtar', ['-cf', archivePath, '-C', buildDir, 'pkg'], { encoding: 'utf8' });
  spawnSync('/usr/bin/bsdtar', ['-rf', archivePath, '-C', buildDir, 'pkg'], { encoding: 'utf8' });
  const bytes = readFileSync(archivePath);
  const sum = sha256(bytes);
  const src = baseAcquisition({
    expectedSha256: sum, expectedBytes: bytes.length,
    outputPath: 'acquired',
    archive: { expectedEntries: 999, expectedExpandedBytes: 999 },
  });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [bytes] } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_ARCHIVE_INVALID' && /collision/i.test(f.message)), JSON.stringify(res.findings));
});

test('acquireSource: archive rejects an entry-count mismatch', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const arch = makeArchive((d) => {
    mkdirSync(path.join(d, 'pkg'), { recursive: true });
    writeFileSync(path.join(d, 'pkg/file1.txt'), 'data');
  });
  const src = baseAcquisition({
    expectedSha256: arch.sum, expectedBytes: arch.bytes.length,
    outputPath: 'acquired',
    archive: { expectedEntries: 99, expectedExpandedBytes: arch.expandedBytes },
  });
  const client = makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [arch.bytes] } });
  const res = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_SOURCE_ARCHIVE_INVALID' && /entry count/i.test(f.message)), JSON.stringify(res.findings));
});

test('acquireSource: archive idempotent same-hash reuse skips re-extraction', async () => {
  const repoDir = makeExecutorRepo();
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = 'evidence/P00-T001.json';
  writeRunning(repoDir, evidencePath, baseRunning(taskRoot, tokenSha256));
  const arch = makeArchive((d) => {
    mkdirSync(path.join(d, 'pkg'), { recursive: true });
    writeFileSync(path.join(d, 'pkg/file1.txt'), 'data');
  });
  const src = baseAcquisition({
    expectedSha256: arch.sum, expectedBytes: arch.bytes.length,
    outputPath: 'acquired',
    archive: { expectedEntries: arch.entries, expectedExpandedBytes: arch.expandedBytes },
  });
  let calls = 0;
  const client = async (opts) => { calls++; return makeClient({ 'example.com:443:/file.bin': { statusCode: 200, chunks: [arch.bytes] } })(opts); };
  const r1 = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.equal(r1.findings.length, 0, JSON.stringify(r1.findings));
  // Mutate the extracted output so we can detect re-extraction.
  writeFileSync(path.join(repoDir, 'acquired/pkg/file1.txt'), 'MUTATED');
  const r2 = await acquireSource({ source: src, task: acquisitionTask(taskRoot), repoRoot: repoDir, evidencePath, httpsClient: client });
  assert.equal(r2.findings.length, 0, JSON.stringify(r2.findings));
  assert.equal(r2.result.idempotent, true);
  // The mutation must persist (no re-extraction overwrote it).
  assert.equal(readFileSync(path.join(repoDir, 'acquired/pkg/file1.txt'), 'utf8'), 'MUTATED');
});

// ---------------------------------------------------------------------------
// commitTask — sole product-commit creator (real git fixture).
// ---------------------------------------------------------------------------

function makeGitRepo() {
  const dir = mktmp();
  const env = {
    ...process.env,
    GIT_AUTHOR_NAME: IDENTITY.name, GIT_AUTHOR_EMAIL: IDENTITY.email,
    GIT_COMMITTER_NAME: IDENTITY.name, GIT_COMMITTER_EMAIL: IDENTITY.email,
    LC_ALL: 'C', LANG: 'C', TZ: 'UTC',
    PATH: '/usr/bin:/bin:/usr/sbin:/sbin',
    DEVELOPER_DIR: '/Applications/Xcode.app/Contents/Developer',
  };
  spawnSync(GIT, ['-C', dir, 'init', '-q', '-b', 'main'], { env, encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'core.hooksPath', '/dev/null'], { env, encoding: 'utf8' });
  spawnSync(GIT, ['-C', dir, 'config', 'commit.gpgSign', 'false'], { env, encoding: 'utf8' });
  return { dir, env };
}

function gitCommit(dir, env, message, files) {
  for (const [p, content] of Object.entries(files)) {
    const full = path.join(dir, p);
    mkdirSync(path.dirname(full), { recursive: true });
    writeFileSync(full, content);
    spawnSync(GIT, ['-C', dir, 'add', '--', p], { env, encoding: 'utf8' });
  }
  spawnSync(GIT, ['-C', dir, '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgSign=false', 'commit', '--no-verify', '--no-gpg-sign', '-m', message], { env, encoding: 'utf8' });
  return spawnSync(GIT, ['-C', dir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
}

function commitPlan(repoDir, baseCommit, taskID = 'P00-T001', productPaths = ['Sources/Foo.swift']) {
  return {
    planID: 'P00', planHash: 'a'.repeat(40), baseCommit,
    tasks: [{
      taskID,
      stages: [
        { name: 'green', steps: [{ kind: 'verification-command', command: { commandID: `${taskID}.GREEN.001`, kind: 'process', networkMode: 'forbidden', timeoutMs: 120000, leaves: [{ leafID: `${taskID}.GREEN.001.PROC.001` }] } }] },
        { name: 'commit', steps: [{ kind: 'controller-action', action: 'commit-task' }] },
      ],
      workspace: { taskHash: '1'.repeat(40), planHash: 'a'.repeat(40) },
      productCommit: {
        author: IDENTITY, committer: IDENTITY,
        message: `monacode: complete ${taskID}`,
        preflightBaseParent: baseCommit,
        stagedProductPaths: productPaths,
        hooksDisabled: true, signingDisabled: true, evidenceExcluded: true,
      },
      evidenceCommit: { stagedEvidencePath: `evidence/${taskID}.json`, verifiedAssertions: [] },
      completionAssertions: [],
    }],
  };
}

function commitRunning(repoDir, baseCommit, taskRoot, tokenSha256, productPaths, fileHashes) {
  return {
    taskID: 'P00-T001', state: 'running', currentStage: 'commit', lifecycleState: 'running',
    tokenSha256, taskRoot, baseCommit, planHash: 'a'.repeat(40), taskHash: '1'.repeat(40),
    commandResults: [{ leafID: 'P00-T001.GREEN.001.PROC.001', parentCommandID: 'P00-T001.GREEN.001', exitStatus: 0, stdoutHash: '0'.repeat(64), stderrHash: '0'.repeat(64), expectedResult: true, executorHash: '0'.repeat(64), sandboxProfileHash: '0'.repeat(64) }],
    acquisitionResults: [], assertionResults: [],
    fileHashes: fileHashes || productPaths.map((p) => ({ path: p, sha256: sha256('impl') })),
  };
}

async function setupCommitFixture(overrides = {}) {
  const { dir: repoDir, env } = makeGitRepo();
  const base = gitCommit(repoDir, env, 'base', { 'README': 'r' });
  // Modify a product file so it can be staged.
  mkdirSync(path.join(repoDir, 'Sources'), { recursive: true });
  writeFileSync(path.join(repoDir, 'Sources/Foo.swift'), 'impl content');
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const productPaths = overrides.productPaths || ['Sources/Foo.swift'];
  const evidencePath = `evidence/P00-T001.json`;
  const plan = commitPlan(repoDir, base, 'P00-T001', productPaths);
  const fileHashes = productPaths.filter((p) => existsSync(path.join(repoDir, p))).map((p) => ({ path: p, sha256: sha256(readFileSync(path.join(repoDir, p))) }));
  const running = commitRunning(repoDir, base, taskRoot, tokenSha256, productPaths, fileHashes);
  if (overrides.running) Object.assign(running, overrides.running);
  writeRunning(repoDir, evidencePath, running);
  return { repoDir, env, base, taskRoot, tokenSha256, evidencePath, plan, productPaths };
}

test('commitTask: creates the sole product commit with exact identity/message/boundary', async () => {
  const { repoDir, env, base, taskRoot, evidencePath, plan, productPaths } = await setupCommitFixture();
  const res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  // Exactly one new commit; HEAD's sole parent is base.
  const head = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  assert.notEqual(head, base);
  const parents = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD^'], { env, encoding: 'utf8' }).stdout.trim();
  assert.equal(parents, base);
  // Identity + message.
  const show = spawnSync(GIT, ['-C', repoDir, 'show', '-s', '--format=%an%n%ae%n%cn%n%ce%n%s', 'HEAD'], { env, encoding: 'utf8' }).stdout.split('\n');
  assert.equal(show[0], 'zhengrenzhe'); assert.equal(show[1], 'zhengrenzhe0416@outlook.com');
  assert.equal(show[4], 'monacode: complete P00-T001');
  // Boundary: exactly the product path.
  const diff = spawnSync(GIT, ['-C', repoDir, 'diff-tree', '-r', '--no-commit-id', '--name-only', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  assert.deepEqual(diff.split('\n').sort(), [...productPaths].sort());
  // Index is empty after commit.
  const idx = spawnSync(GIT, ['-C', repoDir, 'diff', '--cached', '--name-only'], { env, encoding: 'utf8' }).stdout.trim();
  assert.equal(idx, '');
  // .g6-committing journal removed.
  assert.ok(!existsSync(path.join(repoDir, evidencePath + '.g6-committing')));
  // Running evidence records the product commit.
  const updated = JSON.parse(readFileSync(path.join(repoDir, evidencePath), 'utf8'));
  assert.equal(updated.productCommit, head);
});

test('commitTask: rejects wrong base (HEAD moved)', async () => {
  const { repoDir, env, base, evidencePath, plan } = await setupCommitFixture();
  // Move HEAD by committing something else.
  gitCommit(repoDir, env, 'extra', { 'OTHER': 'x' });
  const res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_EVIDENCE_BASE'));
});

test('commitTask: rejects dirty index', async () => {
  const { repoDir, env, evidencePath, plan } = await setupCommitFixture();
  // Stage an unrelated file.
  writeFileSync(path.join(repoDir, 'EXTRA'), 'x');
  spawnSync(GIT, ['-C', repoDir, 'add', '--', 'EXTRA'], { env, encoding: 'utf8' });
  const res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_EVIDENCE_INDEX'));
});

test('commitTask: rejects underreach (missing a boundary path)', async () => {
  const { repoDir, env, evidencePath, plan } = await setupCommitFixture({ productPaths: ['Sources/Foo.swift', 'Sources/Bar.swift'] });
  // Only stage Foo; Bar is missing from the worktree.
  writeFileSync(path.join(repoDir, 'Sources/Foo.swift'), 'impl');
  const res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.ok(res.findings.length >= 1);
});

test('commitTask: rejects overreach (extra undeclared path staged)', async () => {
  const { repoDir, env, evidencePath, plan } = await setupCommitFixture();
  // Add an extra file to the worktree that is not in the boundary.
  writeFileSync(path.join(repoDir, 'Sources/Extra.swift'), 'extra');
  const res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_PRODUCT_BOUNDARY_OVERREACH' || f.id === 'PLAN_EVIDENCE_WORKTREE_POLICY'));
});

test('commitTask: rejects cherry-pick/rebase/bisect in-progress state', async () => {
  const { repoDir, env, evidencePath, plan } = await setupCommitFixture();
  // Simulate an in-progress cherry-pick by creating the git marker.
  const gitDir = path.join(repoDir, '.git');
  writeFileSync(path.join(gitDir, 'CHERRY_PICK_HEAD'), '0'.repeat(40));
  const res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_EVIDENCE_INDEX'), JSON.stringify(res.findings));
});

test('commitTask: rejects a stray .g6-beginning journal during commit (out-of-order state)', async () => {
  const { repoDir, env, evidencePath, plan } = await setupCommitFixture();
  // A stray beginning journal is out-of-order for the commit stage.
  writeFileSync(path.join(repoDir, evidencePath + '.g6-beginning'), '{}');
  const res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_EVIDENCE_JOURNAL_STATE'), JSON.stringify(res.findings));
});

test('commitTask: rejects a stray .g6-finalizing journal during commit (out-of-order state)', async () => {
  const { repoDir, env, evidencePath, plan } = await setupCommitFixture();
  writeFileSync(path.join(repoDir, evidencePath + '.g6-finalizing'), '{}');
  const res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.ok(res.findings.some((f) => f.id === 'PLAN_EVIDENCE_JOURNAL_STATE'), JSON.stringify(res.findings));
});

test('commitTask: stop after journal then rerun converges to the same sole product commit', async () => {
  const { repoDir, env, base, evidencePath, plan } = await setupCommitFixture();
  // First call: inject a hook that stops after writing the .g6-committing journal.
  const stopHook = { afterJournal: () => { throw new Error('STOP_AFTER_COMMIT_JOURNAL'); } };
  let res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath, hooks: stopHook });
  // The journal exists; no commit yet.
  assert.ok(existsSync(path.join(repoDir, evidencePath + '.g6-committing')));
  assert.equal(spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim(), base);
  // Rerun without the stop: converges to one product commit.
  res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  const head = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  // Rerun again: idempotent, same commit, no second commit.
  res = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  const head2 = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  assert.equal(head, head2, 'rerun created a second product commit');
});

// ---------------------------------------------------------------------------
// finalizeEvidence — convergence to one evidence commit.
// ---------------------------------------------------------------------------

async function setupFinalizeFixture() {
  const { dir: repoDir, env } = makeGitRepo();
  const base = gitCommit(repoDir, env, 'base', { 'README': 'r' });
  mkdirSync(path.join(repoDir, 'Sources'), { recursive: true });
  writeFileSync(path.join(repoDir, 'Sources/Foo.swift'), 'impl content');
  const { taskRoot, tokenSha256 } = makeTaskRoot();
  const evidencePath = `evidence/P00-T001.json`;
  const productPaths = ['Sources/Foo.swift'];
  const plan = commitPlan(repoDir, base, 'P00-T001', productPaths);
  const fileHashes = [{ path: 'Sources/Foo.swift', sha256: sha256('impl content') }];
  const running = commitRunning(repoDir, base, taskRoot, tokenSha256, productPaths, fileHashes);
  writeRunning(repoDir, evidencePath, running);
  // Create the product commit via commitTask.
  const cres = await commitTask({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath });
  assert.equal(cres.findings.length, 0, JSON.stringify(cres.findings));
  const productCommit = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  return { repoDir, env, base, taskRoot, tokenSha256, evidencePath, plan, productPaths, productCommit };
}

test('finalizeEvidence: creates one evidence commit with exact parent/identity/message/blob', async () => {
  const { repoDir, env, base, taskRoot, tokenSha256, evidencePath, plan, productCommit } = await setupFinalizeFixture();
  const res = await finalizeEvidence({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath, path: evidencePath });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  const head = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  // HEAD is the evidence commit; its sole parent is the product commit.
  const parent = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD^'], { env, encoding: 'utf8' }).stdout.trim();
  assert.equal(parent, productCommit);
  // Identity + message.
  const show = spawnSync(GIT, ['-C', repoDir, 'show', '-s', '--format=%an%n%ae%n%cn%n%ce%n%s', 'HEAD'], { env, encoding: 'utf8' }).stdout.split('\n');
  assert.equal(show[0], 'zhengrenzhe'); assert.equal(show[1], 'zhengrenzhe0416@outlook.com');
  assert.equal(show[4], 'evidence(monacode): complete P00-T001');
  // Only the evidence path is in the diff.
  const diff = spawnSync(GIT, ['-C', repoDir, 'diff-tree', '-r', '--no-commit-id', '--name-only', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  assert.equal(diff, evidencePath);
  // The token-owned task root is removed.
  assert.ok(!existsSync(taskRoot));
  // .g6-finalizing journal removed.
  assert.ok(!existsSync(path.join(repoDir, evidencePath + '.g6-finalizing')));
  // Passed JSON does not embed its own blob hash or commit ID.
  const evidence = JSON.parse(readFileSync(path.join(repoDir, evidencePath), 'utf8'));
  assert.equal(evidence.state, 'passed');
  assert.equal(evidence.selectorMode, 'external-git');
  assert.equal(evidence.productCommit, productCommit);
  const evidenceContent = readFileSync(path.join(repoDir, evidencePath), 'utf8');
  assert.ok(!evidenceContent.includes(head), 'passed JSON must not embed its own commit ID');
});

test('finalizeEvidence: rejects when HEAD is not the product commit (parent mismatch)', async () => {
  const { repoDir, env, evidencePath, plan, productCommit } = await setupFinalizeFixture();
  // Move HEAD past the product commit with an unrelated commit.
  gitCommit(repoDir, env, 'unrelated', { 'OTHER': 'x' });
  const res = await finalizeEvidence({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath, path: evidencePath });
  assert.ok(res.findings.length >= 1);
});

test('finalizeEvidence: stop after journal then rerun converges to the same evidence commit', async () => {
  const { repoDir, env, evidencePath, plan, productCommit } = await setupFinalizeFixture();
  // First call: stop after writing the .g6-finalizing journal.
  const stopHook = { afterJournal: () => { throw new Error('STOP_AFTER_FINALIZE_JOURNAL'); } };
  let res = await finalizeEvidence({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath, path: evidencePath, hooks: stopHook });
  assert.ok(existsSync(path.join(repoDir, evidencePath + '.g6-finalizing')), 'finalizing journal should exist after stop');
  // Product commit intact.
  assert.equal(spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim(), productCommit);
  // Rerun without stop: converges to one evidence commit.
  res = await finalizeEvidence({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath, path: evidencePath });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  const head = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  // Rerun again: idempotent.
  res = await finalizeEvidence({ plan, taskID: 'P00-T001', repoRoot: repoDir, evidencePath, path: evidencePath });
  assert.equal(res.findings.length, 0, JSON.stringify(res.findings));
  const head2 = spawnSync(GIT, ['-C', repoDir, 'rev-parse', 'HEAD'], { env, encoding: 'utf8' }).stdout.trim();
  assert.equal(head, head2, 'rerun created a second evidence commit');
});

// ---------------------------------------------------------------------------
// Cleanup.
// ---------------------------------------------------------------------------

test('cleanup temp dirs', () => { cleanup(); assert.ok(true); });
