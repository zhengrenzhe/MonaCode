// G6-R command executor, source acquisition, and product/evidence commit
// creators. Repository-owned, dependency-free (Node built-ins only).
//
// executeVerificationCommand runs a structured CommandSpec (process /
// all-success / pipeline) under the locked /usr/bin/sandbox-exec profile that
// denies network and file writes outside the realpath-normalized command child.
// It implements parent-record order, all-success short-circuit, connected
// pipeline streams with aggregate pipefail, timeout (TERM then KILL after 5s),
// an 8,388,608-byte stdout/stderr cap, expected-result matching, before/after
// Git product-state snapshots, cleanup of the command child, and an atomic
// running-evidence advance through a .g6-part transient that is absent before
// and after a successful call.
//
// acquireSource retrieves a declared remote input under its HTTPS/host/redirect/
// byte/hash/license/output contract, streaming to a .g6-part and atomically
// renaming, with bsdtar archive extraction in a separate probe root.
//
// commitTask is the sole product-commit creator; finalizeEvidence is the sole
// evidence-commit creator. Both use locked /usr/bin/git argument-array
// invocations with a closed environment, hooks/signing disabled, and a journal
// protocol whose ordered prefix states are each recoverable to the same result.

import { createHash } from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

import { makeFinding, sortFindings } from './findings.mjs';
import { canonicalJSONStringify } from './canonical-json.mjs';
import { finalizeTaskEvidence, auditTaskEvidence } from './task-state.mjs';

// ---------------------------------------------------------------------------
// Pinned constants
// ---------------------------------------------------------------------------

export const NODE_BIN = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
export const XCRUN_BIN = '/usr/bin/xcrun';
export const SANDBOX_BIN = '/usr/bin/sandbox-exec';
export const GIT_BIN = '/usr/bin/git';
export const BSDTAR_BIN = '/usr/bin/bsdtar';
export const STREAM_CAP = 8388608; // 8 MiB
export const KILL_GRACE_MS = 5000;

export const CHILD_ENV_PATH = '/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/Cellar/node/26.7.0/bin';
export const CHILD_ENV_DEVELOPER_DIR = '/Applications/Xcode.app/Contents/Developer';

const IDENTITY = { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' };

const VALID_LEAF_EXECUTABLES = new Set([NODE_BIN, XCRUN_BIN]);

// The complete Task 1 toolchain lock (baseline-inventory.json toolchain rows).
const EXPECTED_TOOLCHAIN = {
  node: { path: NODE_BIN, sha256: '1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040', version: 'v26.7.0' },
  xcrun: { path: XCRUN_BIN, sha256: '4bc0cc7099775fbe35c653ceb09e0e393d2e5ada024db872e0eb8c43500b4dc6' },
  sandboxExec: { path: SANDBOX_BIN, sha256: 'e3d7a792c58a5d3783d2f7274c82d70062393830d8cb1ded713ca554a470bd2f' },
  git: { path: GIT_BIN, sha256: '44a68ddc1983d6cff3fd35ba3f9ba5f82004216f1dcde69892b3d1b06e408698', version: '2.50.1 (Apple Git-155)' },
  bsdtar: { path: BSDTAR_BIN, sha256: 'bc069dd7ef2ecea4c27ff9daa97f4ba4c5a1a41938bad8050e96bce5daa64346', version: '3.5.3' },
  swift: { path: '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift', sha256: '2ed38571e92c0283091838c1649e27650ad9c99950288e883c7b2dc6c4ce89fb', version: '6.3.3' },
  chrome: { path: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', sha256: 'ee37661755341e9fc1babf9c20ec09d6a36e50aa8713ceb08082f8bbe2d8217d', version: '151.0.7922.138' },
  systemProfiler: { path: '/usr/sbin/system_profiler', sha256: '6b868d95b01d44045fc434d5e867cd9ac5de15634fef126522d0a6919ccd2652' },
};

const REQUIRED_TOOLCHAIN_KEYS = ['node', 'xcrun', 'sandboxExec', 'git', 'bsdtar'];

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function sha256Buf(buf) {
  return createHash('sha256').update(buf).digest('hex');
}

function finding(id, taskID, message, pathStr = '') {
  return makeFinding({ id, category: 'semantic', taskID: taskID ?? null, path: pathStr, message });
}

// The executor module hash: SHA-256 of this file's own source bytes. Recorded
// in every command result so evidence validation can prove the locked executor
// produced the result.
let _executorModuleHash = null;
function executorModuleHash() {
  if (_executorModuleHash) return _executorModuleHash;
  try {
    const self = fileURLToPath(import.meta.url);
    _executorModuleHash = sha256Buf(fs.readFileSync(self));
  } catch {
    _executorModuleHash = sha256('command-executor.mjs');
  }
  return _executorModuleHash;
}

// ---------------------------------------------------------------------------
// verifyToolchain — compare the complete Task 1 lock
// ---------------------------------------------------------------------------

/**
 * Compare a provided toolchain lock against the expected Task 1 fields. Returns
 * a sorted Finding[] for any missing or mismatched field.
 * @param {unknown} toolchain
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function verifyToolchain(toolchain) {
  const findings = [];
  if (!toolchain || typeof toolchain !== 'object') {
    findings.push(finding('PLAN_TOOLCHAIN_DRIFT', null, 'toolchain lock is not an object'));
    return sortFindings(findings);
  }
  for (const key of REQUIRED_TOOLCHAIN_KEYS) {
    const exp = EXPECTED_TOOLCHAIN[key];
    const got = toolchain[key];
    if (!got || typeof got !== 'object') {
      findings.push(finding('PLAN_TOOLCHAIN_DRIFT', null, `toolchain lock missing required key ${key}`));
      continue;
    }
    if (got.path !== exp.path) findings.push(finding('PLAN_TOOLCHAIN_DRIFT', null, `toolchain ${key}.path drift: ${got.path} != ${exp.path}`));
    if (got.sha256 !== exp.sha256) findings.push(finding('PLAN_TOOLCHAIN_DRIFT', null, `toolchain ${key}.sha256 drift`));
    if (exp.version && got.version !== exp.version) findings.push(finding('PLAN_TOOLCHAIN_DRIFT', null, `toolchain ${key}.version drift: ${got.version} != ${exp.version}`));
  }
  return sortFindings(findings);
}

// ---------------------------------------------------------------------------
// buildSandboxProfile — the locked sandbox-exec profile
// ---------------------------------------------------------------------------

/**
 * Build the locked sandbox-exec profile for a realpath-normalized command
 * child. The profile allows default operations, denies all network, and denies
 * file writes outside the command child.
 * @param {string} realCommandTemp
 * @returns {{ profile: string, hash: string }}
 */
export function buildSandboxProfile(realCommandTemp) {
  const profile = `(version 1) (allow default) (deny network*) (deny file-write* (require-not (subpath "${realCommandTemp}")))`;
  return { profile, hash: sha256(profile) };
}

// ---------------------------------------------------------------------------
// Git helpers (real /usr/bin/git arg-array invocations with a closed env)
// ---------------------------------------------------------------------------

function closedGitEnv() {
  return {
    GIT_AUTHOR_NAME: IDENTITY.name,
    GIT_AUTHOR_EMAIL: IDENTITY.email,
    GIT_COMMITTER_NAME: IDENTITY.name,
    GIT_COMMITTER_EMAIL: IDENTITY.email,
    LC_ALL: 'C',
    LANG: 'C',
    TZ: 'UTC',
    PATH: CHILD_ENV_PATH,
    DEVELOPER_DIR: CHILD_ENV_DEVELOPER_DIR,
  };
}

function realGit(repoRoot, args, opts = {}) {
  const env = { ...closedGitEnv(), ...(opts.env || {}) };
  const r = spawnSyncGit(repoRoot, args, env);
  return r;
}

function spawnSyncGit(repoRoot, args, env) {
  const r = spawnSync(GIT_BIN, ['-C', repoRoot, ...args], { env, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
  return { stdout: r.stdout ?? '', stderr: r.stderr ?? '', status: r.status ?? 1 };
}

// ---------------------------------------------------------------------------
// executeVerificationCommand
// ---------------------------------------------------------------------------

/**
 * Execute one verification command under the locked sandbox and write its
 * canonical result only to the declared task evidence path.
 * @param {{
 *   command: object, task: { taskID: string }, repoRoot: string, evidencePath: string,
 *   toolchain: object, fs?: object, git?: Function, hooks?: object,
 * }} input
 * @returns {Promise<{ ok: boolean, findings: object[], result: object }>}
 */
export async function executeVerificationCommand({ command, task, repoRoot, evidencePath, toolchain, fs: fsOpt, git, hooks }) {
  const _fs = fsOpt || fs;
  const taskID = task && task.taskID;
  const findings = [];
  const evidenceFull = path.join(repoRoot, evidencePath);
  const partPath = evidenceFull + '.g6-part';

  // 1. Toolchain lock comparison.
  const toolchainFindings = verifyToolchain(toolchain);
  findings.push(...toolchainFindings);

  // 2. Read + validate the running evidence selected by the task root.
  let running;
  try {
    running = JSON.parse(_fs.readFileSync(evidenceFull, 'utf8'));
  } catch {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_STATE', taskID, 'running evidence unreadable', evidencePath)], result: null };
  }
  if (!running || running.state !== 'running') {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_STATE', taskID, `evidence state ${running && running.state} is not running`, evidencePath)], result: null };
  }
  const taskRoot = running.taskRoot;
  const tokenSha256 = running.tokenSha256;
  if (typeof taskRoot !== 'string' || !taskRoot.startsWith('/')) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_TOKEN', taskID, 'task root missing', evidencePath)], result: null };
  }
  // Validate the task-root marker (mode-0600, 32-byte token, sha256 matches).
  const markerPath = path.join(taskRoot, '.token');
  let markerStat;
  try { markerStat = _fs.statSync(markerPath); } catch {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_TOKEN', taskID, 'task-root marker missing', markerPath)], result: null };
  }
  const markerMode = markerStat.mode & 0o777;
  if (markerMode !== 0o600) findings.push(finding('PLAN_EVIDENCE_TOKEN', taskID, `marker mode ${markerMode.toString(8)} != 600`, markerPath));
  const markerToken = _fs.readFileSync(markerPath);
  if (markerToken.length !== 32 || sha256Buf(markerToken) !== tokenSha256) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_TOKEN', taskID, 'workspace token mismatch', markerPath)], result: null };
  }

  // 3. Validate leaf executables.
  const leaves = Array.isArray(command.leaves) ? command.leaves : [];
  for (const leaf of leaves) {
    if (!leaf || !VALID_LEAF_EXECUTABLES.has(leaf.executable)) {
      findings.push(finding('PLAN_LEAF_SELECTION', taskID, `leaf ${leaf && leaf.leafID} executable ${leaf && leaf.executable} is not a pinned toolchain path`));
    }
  }

  // 4. .g6-part must be absent before a successful call.
  if (_fs.existsSync(partPath)) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, '.g6-part transient present before execution', partPath)], result: null };
  }

  // 5. Before Git snapshot.
  const gitRunner = git || ((args) => realGit(repoRoot, args));
  const beforeStatus = gitRunner(['status', '--porcelain=v2', '-z', '--untracked-files=all']);
  const beforeStateHash = beforeStatus.status === 0 ? sha256(beforeStatus.stdout) : null;
  if (beforeStatus.status !== 0) findings.push(finding('PLAN_REPO_STATE', taskID, 'git status before execution failed'));

  // 4b. Classify worktree evidence/journal rows. Permit the selected current
  // running evidence path and the `.g6-part` transient (checked absent below);
  // every other evidence or journal row is a finding.
  findings.push(...classifyWorktreeRows(beforeStatus.stdout, evidencePath, taskID));

  // 6. Create a fresh realpath-normalized command child below the task root.
  const commandChild = _fs.mkdtempSync(path.join(taskRoot, 'cmd-'));
  // Resolve to the realpath (macOS /tmp -> /private/tmp).
  let commandChildReal;
  try { commandChildReal = _fs.realpathSync(commandChild); } catch { commandChildReal = commandChild; }

  // 7. Set up the exact child environment.
  const childEnv = {
    PATH: CHILD_ENV_PATH,
    LC_ALL: 'C', LANG: 'C', TZ: 'UTC',
    DEVELOPER_DIR: CHILD_ENV_DEVELOPER_DIR,
    HOME: path.join(commandChildReal, 'home'),
    TMPDIR: path.join(commandChildReal, 'tmp'),
    XDG_CACHE_HOME: path.join(commandChildReal, 'cache'),
    CLANG_MODULE_CACHE_PATH: path.join(commandChildReal, 'clang'),
    SWIFTPM_MODULECACHE_OVERRIDE: path.join(commandChildReal, 'swiftpm'),
  };
  for (const sub of ['home', 'tmp', 'cache', 'clang', 'swiftpm']) {
    _fs.mkdirSync(path.join(commandChildReal, sub), { recursive: true });
  }

  const { profile, hash: sandboxProfileHash } = buildSandboxProfile(commandChildReal);
  const executorHash = executorModuleHash();
  const parentCommandID = command.commandID;
  const expectedExit = command.expectedExit !== undefined ? command.expectedExit : (command.expected && command.expected.exit !== undefined ? command.expected.exit : 0);
  const stdoutIncludes = command.expectedOutputIncludes || (command.expected && command.expected.stdoutIncludes) || [];
  const stdoutExcludes = (command.expected && command.expected.stdoutExcludes) || [];
  const stderrIncludes = (command.expected && command.expected.stderrIncludes) || [];
  const stderrExcludes = (command.expected && command.expected.stderrExcludes) || [];

  // 8. Execute leaves in topology order.
  let leafResults = [];
  let aggregateOk = true;
  let timeoutFinding = null;
  let capFinding = null;
  try {
    if (command.kind === 'process') {
      const r = await runLeaf(leaves[0], commandChildReal, childEnv, profile, repoRoot);
      leafResults.push(r);
      if (r.timeout) { timeoutFinding = finding('PLAN_COMMAND_TIMEOUT', taskID, `leaf ${leaves[0].leafID} timed out`); aggregateOk = false; }
      if (r.capOverflow) { capFinding = finding('PLAN_COMMAND_STREAM_CAP', taskID, `leaf ${leaves[0].leafID} stream cap overflow`); aggregateOk = false; }
    } else if (command.kind === 'all-success') {
      for (const leaf of leaves) {
        const r = await runLeaf(leaf, commandChildReal, childEnv, profile, repoRoot);
        leafResults.push(r);
        if (r.timeout) { timeoutFinding = finding('PLAN_COMMAND_TIMEOUT', taskID, `leaf ${leaf.leafID} timed out`); aggregateOk = false; break; }
        if (r.capOverflow) { capFinding = finding('PLAN_COMMAND_STREAM_CAP', taskID, `leaf ${leaf.leafID} stream cap overflow`); aggregateOk = false; break; }
        if (r.exitStatus !== 0) { aggregateOk = false; break; } // short-circuit
      }
    } else if (command.kind === 'pipeline') {
      leafResults = await runPipeline(leaves, commandChildReal, childEnv, profile, repoRoot);
      for (const r of leafResults) {
        if (r.timeout) { timeoutFinding = finding('PLAN_COMMAND_TIMEOUT', taskID, `leaf ${r.leafID} timed out`); aggregateOk = false; }
        if (r.capOverflow) { capFinding = finding('PLAN_COMMAND_STREAM_CAP', taskID, `leaf ${r.leafID} stream cap overflow`); aggregateOk = false; }
      }
      if (command.pipefail === true && leafResults.some((r) => r.exitStatus !== 0)) aggregateOk = false;
    } else {
      findings.push(finding('PLAN_COMMAND_SHAPE', taskID, `unknown command kind ${command.kind}`));
      aggregateOk = false;
    }
  } catch (e) {
    findings.push(finding('PLAN_COMMAND_RESULT_MISMATCH', taskID, `execution error: ${e.message}`));
    aggregateOk = false;
  }

  if (timeoutFinding) findings.push(timeoutFinding);
  if (capFinding) findings.push(capFinding);

  // 9. Expected matching (exit + stdout/stderr includes/excludes) on the final leaf.
  const finalLeaf = leafResults[leafResults.length - 1] || { exitStatus: -1, stdout: '', stderr: '' };
  const exitMatch = finalLeaf.exitStatus === expectedExit;
  const stdoutOk = stdoutIncludes.every((s) => finalLeaf.stdout.includes(s)) && stdoutExcludes.every((s) => !finalLeaf.stdout.includes(s));
  const stderrOk = stderrIncludes.every((s) => finalLeaf.stderr.includes(s)) && stderrExcludes.every((s) => !finalLeaf.stderr.includes(s));
  const expectedMatched = exitMatch && stdoutOk && stderrOk;
  const expectedResult = aggregateOk && expectedMatched && findings.filter((f) => f.id !== 'PLAN_TOOLCHAIN_DRIFT').length === 0;
  if (!expectedMatched && !timeoutFinding && !capFinding) {
    findings.push(finding('PLAN_COMMAND_RESULT_MISMATCH', taskID, `expected exit ${expectedExit} got ${finalLeaf.exitStatus}; stdoutMatch=${stdoutOk}; stderrMatch=${stderrOk}`));
  }

  // 10. After Git snapshot.
  const afterStatus = gitRunner(['status', '--porcelain=v2', '-z', '--untracked-files=all']);
  const afterStateHash = afterStatus.status === 0 ? sha256(afterStatus.stdout) : null;
  if (afterStatus.status !== 0) findings.push(finding('PLAN_REPO_STATE', taskID, 'git status after execution failed'));
  if (beforeStateHash && afterStateHash && beforeStateHash !== afterStateHash) {
    findings.push(finding('PLAN_REPO_DELTA', taskID, 'repository state changed during a read-only verification command'));
  }

  // 11. Cleanup the command child.
  try { _fs.rmSync(commandChild, { recursive: true, force: true }); } catch {
    findings.push(finding('PLAN_WORKSPACE', taskID, 'command child cleanup failed'));
  }

  // 12. Build the leaf result records (one per leaf, carrying executor/sandbox/before/after hashes).
  const leafRecords = leafResults.map((r) => ({
    leafID: r.leafID,
    parentCommandID,
    exitStatus: r.exitStatus,
    stdoutHash: sha256(r.stdout || ''),
    stderrHash: sha256(r.stderr || ''),
    durationMs: r.durationMs,
    expectedResult: r.exitStatus === expectedExit,
    executorHash,
    sandboxProfileHash,
    beforeStateHash,
    afterStateHash,
  }));

  // 13. Atomically advance the running evidence via .g6-part.
  if (findings.filter((f) => f.id === 'PLAN_TOOLCHAIN_DRIFT' || f.id === 'PLAN_REPO_STATE' || f.id === 'PLAN_LEAF_SELECTION').length === 0) {
    const updated = { ...running, commandResults: (running.commandResults || []).concat(leafRecords) };
    try {
      const buf = Buffer.from(canonicalJSONStringify(updated), 'utf8');
      const fd = _fs.openSync(partPath, 'w');
      _fs.writeSync(fd, buf);
      _fs.fsyncSync(fd);
      _fs.closeSync(fd);
      _fs.renameSync(partPath, evidenceFull);
    } catch (e) {
      findings.push(finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, `running evidence advance failed: ${e.message}`));
    }
    if (_fs.existsSync(partPath)) {
      findings.push(finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, '.g6-part transient present after execution'));
    }
  }

  return {
    ok: findings.length === 0,
    findings: sortFindings(findings),
    result: {
      commandID: parentCommandID,
      kind: command.kind,
      expectedResult,
      leaves: leafRecords,
      executorHash,
      sandboxProfileHash,
      beforeStateHash,
      afterStateHash,
    },
  };
}

// Run a single leaf under sandbox-exec.
function runLeaf(leaf, commandChildReal, childEnv, profile, cwd) {
  return new Promise((resolve) => {
    const args = ['-p', profile, leaf.executable, ...leaf.args];
    const child = spawn(SANDBOX_BIN, args, { env: childEnv, cwd, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    let capOverflow = false;
    let killed = false;
    const start = Date.now();
    child.stdout.on('data', (d) => {
      if (stdout.length + d.length > STREAM_CAP) { capOverflow = true; stdout = stdout + d.slice(0, STREAM_CAP - stdout.length); killLeaf(child); return; }
      stdout += d;
    });
    child.stderr.on('data', (d) => {
      if (stderr.length + d.length > STREAM_CAP) { capOverflow = true; stderr = stderr + d.slice(0, STREAM_CAP - stderr.length); killLeaf(child); return; }
      stderr += d;
    });
    const timeoutMs = leaf.timeoutMs || 30000;
    const termTimer = setTimeout(() => {
      killed = true;
      try { child.kill('SIGTERM'); } catch {}
      setTimeout(() => { try { child.kill('SIGKILL'); } catch {} }, KILL_GRACE_MS);
    }, timeoutMs);
    child.on('exit', (code, signal) => {
      clearTimeout(termTimer);
      resolve({
        leafID: leaf.leafID,
        exitStatus: code === null ? -1 : code,
        stdout, stderr,
        durationMs: Date.now() - start,
        timeout: killed,
        capOverflow,
      });
    });
    child.on('error', (err) => {
      clearTimeout(termTimer);
      resolve({ leafID: leaf.leafID, exitStatus: -1, stdout, stderr: String(err), durationMs: Date.now() - start, timeout: false, capOverflow });
    });
  });
}

function killLeaf(child) {
  try { child.kill('SIGTERM'); } catch {}
}

// Run a pipeline: forward stdout[i] -> stdin[i+1] manually so a downstream
// leaf that exits early (without reading its stdin) does not stall the upstream.
// Each leaf's stdout/stderr is captured via a 'data' listener for hashing.
async function runPipeline(leaves, commandChildReal, childEnv, profile, cwd) {
  const procs = [];
  const stdoutBuf = leaves.map(() => '');
  const stderrBuf = leaves.map(() => '');
  const capOverflow = leaves.map(() => false);
  const killed = leaves.map(() => false);
  const starts = leaves.map(() => 0);
  const timers = [];

  for (let i = 0; i < leaves.length; i++) {
    const leaf = leaves[i];
    const args = ['-p', profile, leaf.executable, ...leaf.args];
    const stdio = i === 0 ? ['ignore', 'pipe', 'pipe'] : ['pipe', 'pipe', 'pipe'];
    const child = spawn(SANDBOX_BIN, args, { env: childEnv, cwd, stdio });
    // Swallow stream errors (EPIPE when a downstream leaf exits early, etc.).
    if (child.stdin) child.stdin.on('error', () => {});
    child.stdout.on('error', () => {});
    child.stderr.on('error', () => {});
    child.stdout.on('data', (d) => {
      if (stdoutBuf[i].length + d.length > STREAM_CAP) { capOverflow[i] = true; stdoutBuf[i] = stdoutBuf[i] + d.slice(0, STREAM_CAP - stdoutBuf[i].length); try { child.kill('SIGTERM'); } catch {} return; }
      stdoutBuf[i] += d;
      // Forward to the next leaf's stdin.
      if (i < leaves.length - 1) {
        const next = procs[i + 1] && procs[i + 1].child;
        if (next && next.stdin && !next.stdin.destroyed) {
          try { next.stdin.write(d); } catch {}
        }
      }
    });
    child.stderr.on('data', (d) => {
      if (stderrBuf[i].length + d.length > STREAM_CAP) { capOverflow[i] = true; stderrBuf[i] = stderrBuf[i] + d.slice(0, STREAM_CAP - stderrBuf[i].length); return; }
      stderrBuf[i] += d;
    });
    starts[i] = Date.now();
    const timeoutMs = leaf.timeoutMs || 30000;
    const termTimer = setTimeout(() => {
      killed[i] = true;
      try { child.kill('SIGTERM'); } catch {}
      setTimeout(() => { try { child.kill('SIGKILL'); } catch {} }, KILL_GRACE_MS);
    }, timeoutMs);
    timers.push(termTimer);
    // Attach the exit/error listener NOW (before the child can exit) so a leaf
    // that exits before its predecessor (e.g. a failing pipefail leaf) is not
    // missed by a later sequential await.
    const exitPromise = new Promise((resolve) => {
      child.on('exit', (c) => { clearTimeout(timers[i]); resolve(c === null ? -1 : c); });
      child.on('error', () => { clearTimeout(timers[i]); resolve(-1); });
    });
    procs.push({ child, leafID: leaf.leafID, exitPromise });
  }
  // Signal EOF to each non-first leaf once its upstream has exited.
  for (let i = 1; i < procs.length; i++) {
    procs[i - 1].child.on('exit', () => { try { procs[i].child.stdin.end(); } catch {} });
  }

  const results = [];
  for (let i = 0; i < procs.length; i++) {
    const p = procs[i];
    const code = await p.exitPromise;
    results.push({
      leafID: p.leafID,
      exitStatus: code,
      stdout: stdoutBuf[i], stderr: stderrBuf[i],
      durationMs: Date.now() - starts[i],
      timeout: killed[i],
      capOverflow: capOverflow[i],
    });
  }
  return results;
}

// ---------------------------------------------------------------------------
// acquireSource
// ---------------------------------------------------------------------------

/**
 * Acquire one declared remote implementation input under its HTTPS/host/redirect/
 * byte/hash/license/output contract.
 * @param {{
 *   source: object, task: { taskID: string, workspace?: { taskRoot: string } },
 *   repoRoot: string, evidencePath: string, httpsClient: Function,
 *   fs?: object, bsdtar?: string, hooks?: object,
 * }} input
 */
export async function acquireSource({ source, task, repoRoot, evidencePath, httpsClient, fs: fsOpt, hooks }) {
  const _fs = fsOpt || fs;
  const taskID = task && task.taskID;
  const taskRoot = task && task.workspace && task.workspace.taskRoot;
  const findings = [];
  const evidenceFull = path.join(repoRoot, evidencePath);

  // Clear credential/proxy/cookie/authorization ambient inputs by only setting
  // the caller-controlled header set.
  const headers = {
    'Accept': 'application/octet-stream',
    'Accept-Encoding': 'identity',
    'User-Agent': 'MonaCode-G6-R-SourceAcquisition/1',
  };

  // Reject credentials in URL.
  if (/@/.test(source.url || '')) {
    return { ok: false, findings: [finding('PLAN_SOURCE_CREDENTIAL', taskID, 'credentials in URL are forbidden')], result: null };
  }

  // Validate host.
  const url = source.url || '';
  const u = parseUrl(url);
  if (!u || u.scheme !== 'https') {
    return { ok: false, findings: [finding('PLAN_SOURCE_HOST', taskID, 'url must be https')], result: null };
  }
  if (u.host !== source.host) {
    return { ok: false, findings: [finding('PLAN_SOURCE_HOST', taskID, `host ${u.host} != declared ${source.host}`)], result: null };
  }
  if (source.port !== 443) {
    return { ok: false, findings: [finding('PLAN_SOURCE_HOST', taskID, `port ${source.port} != 443`)], result: null };
  }

  // Pre-existing output: pass only on matching hash. For an archive row the
  // output is a directory; it is validated by re-downloading the archive and
  // re-verifying the .tgz hash below (a directory has no single file hash).
  const outputPath = source.outputPath;
  const outputFull = path.join(repoRoot, outputPath);
  if (_fs.existsSync(outputFull) && !source.archive) {
    const existing = _fs.readFileSync(outputFull);
    if (sha256Buf(existing) === source.expectedSha256) {
      // Idempotent reuse: record and succeed without re-downloading.
      return recordAcquisition({ repoRoot, evidencePath, evidenceFull, _fs, taskID, source, status: 200, observedBytes: existing.length, sha256Hex: sha256Buf(existing), redirectChain: [], headerHash: '', licenseHash: sha256(source.license || ''), outputFull, idempotent: true });
    }
    return { ok: false, findings: [finding('PLAN_SOURCE_HASH', taskID, 'pre-existing output hash mismatch')], result: null };
  }

  // Output path must stay below repoRoot (no foreign workspace token).
  const rel = path.relative(repoRoot, outputFull);
  if (rel.startsWith('..') || path.isAbsolute(rel)) {
    return { ok: false, findings: [finding('PLAN_SOURCE_OUTPUT_COLLISION', taskID, 'output path escapes repo root')], result: null };
  }

  // Stream to .g6-part.
  const partPath = outputFull + '.g6-part';
  mkdirSync(_fs, path.dirname(outputFull));
  let observed = 0;
  let hash = createHash('sha256');
  let statusCode = 0;
  let responseHeaders = {};
  let redirectObserved = [];

  try {
    const resp = await httpsClient({ url, host: source.host, port: source.port, path: u.path, headers, redirectChain: source.redirectChain || [], timeoutMs: source.timeoutMs, maxBytes: source.maxBytes });
    statusCode = resp.statusCode;
    responseHeaders = resp.headers || {};
    if (resp.headers && resp.headers.location) redirectObserved.push(resp.headers.location);

    // An unexpected redirect (3xx with a location not in the declared chain) is
    // rejected before the generic status check.
    if (statusCode >= 300 && statusCode < 400 && responseHeaders.location) {
      const declared = source.redirectChain || [];
      if (declared.length === 0 || declared[0] !== responseHeaders.location) {
        return { ok: false, findings: [finding('PLAN_SOURCE_REDIRECT', taskID, `unexpected redirect to ${responseHeaders.location}`)], result: null };
      }
    }
    if (statusCode !== 200) {
      return { ok: false, findings: [finding('PLAN_SOURCE_STATUS', taskID, `status ${statusCode} != 200`)], result: null };
    }
    if (source.redirectChain && source.redirectChain.length > 0) {
      // The client must have followed the exact declared chain; if the observed
      // chain differs, the client reports a redirect that we reject.
      if (redirectObserved.length > 0) {
        return { ok: false, findings: [finding('PLAN_SOURCE_REDIRECT', taskID, `unexpected redirect to ${redirectObserved[0]}`)], result: null };
      }
    }

    // Content-Length check.
    if (responseHeaders['content-length'] !== undefined && responseHeaders['content-length'] !== null) {
      const cl = Number(responseHeaders['content-length']);
      if (Number.isFinite(cl) && cl !== source.expectedBytes) {
        return { ok: false, findings: [finding('PLAN_SOURCE_BYTES', taskID, `content-length ${cl} != expected ${source.expectedBytes}`)], result: null };
      }
    }

    const fd = _fs.openSync(partPath, 'w');
    for await (const chunk of resp.stream()) {
      observed += chunk.length;
      if (observed > source.maxBytes) {
        _fs.closeSync(fd);
        try { _fs.rmSync(partPath, { force: true }); } catch {}
        return { ok: false, findings: [finding('PLAN_SOURCE_MAX_BYTES', taskID, `observed ${observed} > max ${source.maxBytes}`)], result: null };
      }
      _fs.writeSync(fd, chunk);
      hash.update(chunk);
    }
    _fs.fsyncSync(fd);
    _fs.closeSync(fd);

    if (observed !== source.expectedBytes) {
      try { _fs.rmSync(partPath, { force: true }); } catch {}
      return { ok: false, findings: [finding('PLAN_SOURCE_BYTES', taskID, `observed ${observed} != expected ${source.expectedBytes}`)], result: null };
    }
    const gotHash = hash.digest('hex');
    if (gotHash !== source.expectedSha256) {
      try { _fs.rmSync(partPath, { force: true }); } catch {}
      return { ok: false, findings: [finding('PLAN_SOURCE_HASH', taskID, 'sha256 mismatch')], result: null };
    }
    if (source.license && source.license.length === 0) {
      try { _fs.rmSync(partPath, { force: true }); } catch {}
      return { ok: false, findings: [finding('PLAN_SOURCE_LICENSE', taskID, 'license identity empty')], result: null };
    }

    // Branch: archive extraction vs plain-file rename.
    if (source.archive) {
      // Idempotent reuse: output directory already exists and the .tgz hash matches.
      if (_fs.existsSync(outputFull)) {
        try { _fs.rmSync(partPath, { force: true }); } catch {}
        return recordAcquisition({ repoRoot, evidencePath, evidenceFull, _fs, taskID, source, status: statusCode, observedBytes: observed, sha256Hex: gotHash, redirectChain: redirectObserved, headerHash: sha256(canonicalJSONStringify(responseHeaders)), licenseHash: sha256(source.license || ''), outputFull, idempotent: true, archiveHash: sha256('archive:' + gotHash), collisionKeyHash: '', probeHash: '' });
      }
      const arch = extractArchive({ source, partPath, taskRoot, outputFull, _fs, taskID });
      if (arch.findings.length > 0) {
        try { _fs.rmSync(partPath, { force: true }); } catch {}
        if (arch.probeRoot) try { _fs.rmSync(arch.probeRoot, { recursive: true, force: true }); } catch {}
        return { ok: false, findings: arch.findings, result: null };
      }
      // The probe root was atomically renamed to the output; the .tgz partial is no longer needed.
      try { _fs.rmSync(partPath, { force: true }); } catch {}
      return recordAcquisition({ repoRoot, evidencePath, evidenceFull, _fs, taskID, source, status: statusCode, observedBytes: observed, sha256Hex: gotHash, redirectChain: redirectObserved, headerHash: sha256(canonicalJSONStringify(responseHeaders)), licenseHash: sha256(source.license || ''), outputFull, idempotent: false, archiveHash: arch.archiveHash, collisionKeyHash: arch.collisionKeyHash, probeHash: arch.probeHash });
    }

    // Non-archive: atomic rename of the .g6-part to the declared output.
    _fs.renameSync(partPath, outputFull);
    const parent = path.dirname(outputFull);
    try { const pfd = _fs.openSync(parent, 'r'); _fs.fsyncSync(pfd); _fs.closeSync(pfd); } catch {}

    return recordAcquisition({ repoRoot, evidencePath, evidenceFull, _fs, taskID, source, status: statusCode, observedBytes: observed, sha256Hex: gotHash, redirectChain: redirectObserved, headerHash: sha256(canonicalJSONStringify(responseHeaders)), licenseHash: sha256(source.license || ''), outputFull, idempotent: false });
  } catch (e) {
    try { _fs.rmSync(partPath, { force: true }); } catch {}
    return { ok: false, findings: [finding('PLAN_SOURCE_STATUS', taskID, `acquisition error: ${e.message}`)], result: null };
  }
}

// ---------------------------------------------------------------------------
// extractArchive — bsdtar archive extraction in a probe root
// ---------------------------------------------------------------------------

function parseBsdtarListing(stdout) {
  const entries = [];
  for (const line of stdout.split('\n')) {
    if (!line.trim()) continue;
    const parts = line.split(/\s+/);
    if (parts.length < 9) continue;
    const mode = parts[0];
    const type = mode[0]; // '-' file, 'd' dir, 'l' symlink, 'h' hardlink, 'c'/'b' device
    const size = Number(parts[4]) || 0;
    let name = parts.slice(8).join(' ');
    // Strip symlink target (" name -> target ").
    const arrow = name.indexOf(' -> ');
    if (arrow >= 0) name = name.slice(0, arrow);
    entries.push({ type, mode, size, name });
  }
  return entries;
}

/**
 * Extract a downloaded archive (.g6-part) into a probe root below the task root,
 * validate every entry type + normalized path + NFC collision keys before
 * extraction, require the exact entry count + expanded bytes, then atomically
 * rename the probe root to the declared output. Returns { findings, probeRoot,
 * archiveHash, collisionKeyHash, probeHash }.
 */
function extractArchive({ source, partPath, taskRoot, outputFull, _fs, taskID }) {
  const archive = source.archive || {};
  // 1. List entries BEFORE extraction.
  const listR = spawnSync(BSDTAR_BIN, ['-tvf', partPath], { encoding: 'utf8', maxBuffer: 128 * 1024 * 1024 });
  if (listR.status !== 0) {
    return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `bsdtar list failed: ${listR.stderr}`)] };
  }
  const entries = parseBsdtarListing(listR.stdout);

  // 2. Validate entry types + normalized paths.
  for (const e of entries) {
    if (e.type !== '-' && e.type !== 'd') {
      return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `entry "${e.name}" has forbidden type "${e.type}" (only regular files and directories)`)] };
    }
    if (e.name.startsWith('/') || e.name.includes('..') || e.name.includes('\0') || e.name.includes('\r') || e.name.includes('\n')) {
      return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `entry "${e.name}" has an unsafe path`)] };
    }
    // Reject NUL / invalid surrogate pairs (invalid UTF-8) — node already decoded
    // the bytes as UTF-8; a replacement char indicates invalid encoding.
    if (e.name.includes('�')) {
      return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `entry "${e.name}" contains invalid UTF-8`)] };
    }
  }

  // 3. Reject duplicate component keys computed as normalize('NFC').toLowerCase().normalize('NFC').
  const foldedKeys = new Set();
  for (const e of entries) {
    const comps = e.name.split('/').filter((c) => c.length > 0);
    const folded = comps.map((c) => c.normalize('NFC').toLowerCase().normalize('NFC')).join('/');
    if (foldedKeys.has(folded)) {
      return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `duplicate NFC collision key "${folded}" from entry "${e.name}"`)] };
    }
    foldedKeys.add(folded);
  }
  const collisionKeyHash = sha256([...foldedKeys].sort().join('\n'));

  // 4. Exact entry count + exact/max expanded bytes.
  const expandedBytes = entries.filter((e) => e.type === '-').reduce((s, e) => s + e.size, 0);
  if (archive.expectedEntries !== undefined && entries.length !== archive.expectedEntries) {
    return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `entry count ${entries.length} != expected ${archive.expectedEntries}`)] };
  }
  if (archive.expectedExpandedBytes !== undefined && expandedBytes !== archive.expectedExpandedBytes) {
    return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `expanded bytes ${expandedBytes} != expected ${archive.expectedExpandedBytes}`)] };
  }
  if (archive.maxExpandedBytes !== undefined && expandedBytes > archive.maxExpandedBytes) {
    return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `expanded bytes ${expandedBytes} > max ${archive.maxExpandedBytes}`)] };
  }

  // 5. Probe root below the SAME task root and target volume.
  const probeRoot = _fs.mkdtempSync(path.join(taskRoot, 'probe-'));

  // 6. Extract to the probe root.
  const extractR = spawnSync(BSDTAR_BIN, ['-xf', partPath, '-C', probeRoot], { encoding: 'utf8', maxBuffer: 128 * 1024 * 1024 });
  if (extractR.status !== 0) {
    return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `bsdtar extract failed: ${extractR.stderr}`)], probeRoot };
  }

  // 7. Verify the probe topology: no symlinks, no devices (exclusive create).
  const walkFail = walkProbeForSymlinks(_fs, probeRoot);
  if (walkFail) {
    return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, walkFail)], probeRoot };
  }
  // Verify the extracted file count matches the regular-file entry count.
  const observedFiles = countFiles(_fs, probeRoot);
  const expectedFiles = entries.filter((e) => e.type === '-').length;
  if (observedFiles !== expectedFiles) {
    return { findings: [finding('PLAN_SOURCE_ARCHIVE_INVALID', taskID, `extracted ${observedFiles} files != ${expectedFiles} expected`)], probeRoot };
  }

  // 8. fsync the probe root + its parent.
  try { const fd = _fs.openSync(probeRoot, 'r'); _fs.fsyncSync(fd); _fs.closeSync(fd); } catch {}
  try { const pfd = _fs.openSync(path.dirname(probeRoot), 'r'); _fs.fsyncSync(pfd); _fs.closeSync(pfd); } catch {}

  // 9. Atomically rename the probe root to the declared output.
  mkdirSync(_fs, path.dirname(outputFull));
  // A pre-existing output at this point is a collision (handled above as idempotent);
  // fail closed rather than overwriting.
  if (_fs.existsSync(outputFull)) {
    return { findings: [finding('PLAN_SOURCE_OUTPUT_COLLISION', taskID, `output "${outputPath}" already exists`)], probeRoot };
  }
  _fs.renameSync(probeRoot, outputFull);
  try { const ofd = _fs.openSync(path.dirname(outputFull), 'r'); _fs.fsyncSync(ofd); _fs.closeSync(ofd); } catch {}

  const archiveHash = sha256('archive:' + source.sourceID + ':' + entries.length + ':' + expandedBytes);
  const probeHash = sha256(probeRoot);
  return { findings: [], probeRoot: null, archiveHash, collisionKeyHash, probeHash };
}

function walkProbeForSymlinks(_fs, dir) {
  let entries = [];
  try { entries = _fs.readdirSync(dir, { withFileTypes: true }); } catch { return null; }
  for (const ent of entries) {
    const full = path.join(dir, ent.name);
    let st;
    try { st = _fs.lstatSync(full); } catch { return `lstat failed for ${full}`; }
    if (typeof st.isSymbolicLink === 'function' && st.isSymbolicLink()) return `symlink in probe: ${full}`;
    if (ent.isDirectory()) {
      const sub = walkProbeForSymlinks(_fs, full);
      if (sub) return sub;
    }
  }
  return null;
}

function countFiles(_fs, dir) {
  let count = 0;
  let entries = [];
  try { entries = _fs.readdirSync(dir, { withFileTypes: true }); } catch { return 0; }
  for (const ent of entries) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) count += countFiles(_fs, full);
    else if (ent.isFile()) count++;
  }
  return count;
}

function parseUrl(url) {
  const m = /^https:\/\/([^/:@]+)(?::(\d+))?(\/[^?#]*)?/.exec(url);
  if (!m) return null;
  return { scheme: 'https', host: m[1], port: m[2] ? Number(m[2]) : 443, path: m[3] || '/' };
}

function mkdirSync(_fs, p) { try { _fs.mkdirSync(p, { recursive: true }); } catch {} }

function recordAcquisition({ repoRoot, evidencePath, evidenceFull, _fs, taskID, source, status, observedBytes, sha256Hex, redirectChain, headerHash, licenseHash, outputFull, idempotent, archiveHash, collisionKeyHash, probeHash }) {
  let running;
  try { running = JSON.parse(_fs.readFileSync(evidenceFull, 'utf8')); } catch { running = { acquisitionResults: [] }; }
  const rec = {
    sourceContract: source.sourceID,
    url: source.url, host: source.host, port: source.port,
    status, redirectChain,
    bytes: observedBytes,
    sha256: 'sha256:' + sha256Hex,
    license: source.license,
    headerHash, licenseHash,
    acquisitionHash: sha256(source.sourceID + source.url + sha256Hex),
    outputPath: source.outputPath,
    idempotent,
    archiveHash: archiveHash || '',
    collisionKeyHash: collisionKeyHash || '',
    probeHash: probeHash || '',
  };
  running.acquisitionResults = (running.acquisitionResults || []).concat([rec]);
  const partPath = evidenceFull + '.g6-part';
  try {
    const buf = Buffer.from(canonicalJSONStringify(running), 'utf8');
    const fd = _fs.openSync(partPath, 'w');
    _fs.writeSync(fd, buf);
    _fs.fsyncSync(fd);
    _fs.closeSync(fd);
    _fs.renameSync(partPath, evidenceFull);
  } catch (e) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, `evidence update failed: ${e.message}`)], result: null };
  }
  return { ok: true, findings: [], result: rec };
}

// ---------------------------------------------------------------------------
// commitTask — sole product-commit creator
// ---------------------------------------------------------------------------

/**
 * Create the single product commit for the selected task. Verifies the base,
 * worktree boundary, empty index, and evidence exclusion; stages exact literal
 * paths; commits with hooks/signing disabled. Resumable via the .g6-committing
 * journal.
 * @param {{
 *   plan: object, taskID: string, repoRoot: string, evidencePath: string,
 *   git?: Function, fs?: object, hooks?: object,
 * }} input
 */
export async function commitTask({ plan, taskID, repoRoot, evidencePath, git, fs: fsOpt, hooks }) {
  const _fs = fsOpt || fs;
  const hooks2 = hooks || {};
  const evidenceFull = path.join(repoRoot, evidencePath);
  const journalPath = evidenceFull + '.g6-committing';
  const task = (plan.tasks || []).find((t) => t.taskID === taskID);
  if (!task) return { ok: false, findings: [finding('PLAN_EVIDENCE_STATE', taskID, 'task not in plan')], result: null };

  const gitRunner = git || ((args) => realGit(repoRoot, args));

  // Read running evidence.
  let running;
  try { running = JSON.parse(_fs.readFileSync(evidenceFull, 'utf8')); } catch {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_STATE', taskID, 'running evidence unreadable')], result: null };
  }
  if (running.state !== 'running') return { ok: false, findings: [finding('PLAN_EVIDENCE_STATE', taskID, `state ${running.state} != running`)], result: null };
  if (running.currentStage !== 'commit') return { ok: false, findings: [finding('PLAN_EVIDENCE_STATE', taskID, `stage ${running.currentStage} != commit`)], result: null };

  // Find a Green command result with expectedResult.
  const green = (running.commandResults || []).find((cr) => cr.parentCommandID && cr.parentCommandID.includes('.GREEN.') && cr.expectedResult);
  if (!green) return { ok: false, findings: [finding('PLAN_EVIDENCE_COMMAND_RESULT', taskID, 'no passed Green command result')], result: null };

  const baseCommit = running.baseCommit;
  const pc = task.productCommit || {};
  const boundary = (pc.stagedProductPaths || []).slice().sort();
  const evidenceCommitPath = task.evidenceCommit && task.evidenceCommit.stagedEvidencePath;

  const head = gitRunner(['rev-parse', 'HEAD']);
  const headCommit = head.stdout.trim();

  // Re-entry: if HEAD is already the exact product commit whose sole parent is
  // the recorded base, verify identity/message/boundary and return idempotent.
  // This must precede the HEAD==base check, which would otherwise reject the
  // already-created product commit.
  const existingProduct = running.productCommit;
  if (existingProduct && existingProduct === headCommit) {
    const parents = gitRunner(['rev-parse', `${headCommit}^`]);
    if (parents.status === 0 && parents.stdout.trim() === baseCommit) {
      const v = verifyProductCommit(gitRunner, headCommit, taskID, boundary, evidenceCommitPath);
      if (v.ok) {
        return { ok: true, findings: [], result: { productCommit: headCommit, idempotent: true } };
      }
    }
  }

  // Verify HEAD == base (for a fresh commit).
  if (head.status !== 0 || headCommit !== baseCommit) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_BASE', taskID, `HEAD ${headCommit} != base ${baseCommit}`)], result: null };
  }

  // Reject merge/rebase/cherry-pick/bisect state. Resolve the git dir (it may
  // not be `.git` in a worktree) and check for each in-progress marker.
  const gitDirOut = gitRunner(['rev-parse', '--absolute-git-dir']);
  const gitDir = gitDirOut.status === 0 ? gitDirOut.stdout.trim() : path.join(repoRoot, '.git');
  const inProgressMarkers = ['MERGE_HEAD', 'rebase-merge', 'rebase-apply', 'CHERRY_PICK_HEAD', 'BISECT_LOG'];
  for (const marker of inProgressMarkers) {
    if (_fs.existsSync(path.join(gitDir, marker))) {
      return { ok: false, findings: [finding('PLAN_EVIDENCE_INDEX', taskID, `merge/rebase/cherry-pick/bisect state active (${marker})`)], result: null };
    }
  }

  // Classify worktree.
  const statusOut = gitRunner(['status', '--porcelain=v2', '-z', '--untracked-files=all']);
  const entries = parseStatus(statusOut.stdout);
  const trackedModified = entries.filter((e) => e.tracked).map((e) => e.path);
  const untracked = entries.filter((e) => !e.tracked).map((e) => e.path);

  // Current evidence must not be tracked.
  if (evidenceCommitPath && trackedModified.includes(evidenceCommitPath)) {
    return { ok: false, findings: [finding('PLAN_PRODUCT_BOUNDARY_OVERREACH', taskID, `evidence path ${evidenceCommitPath} is tracked`)], result: null };
  }

  // Empty index check (unless resuming under a matching journal).
  const hasJournal = _fs.existsSync(journalPath);
  if (!hasJournal) {
    const cached = gitRunner(['diff', '--cached', '--name-only', '-z']);
    const stagedPaths = cached.stdout.split('\0').filter(Boolean);
    if (stagedPaths.length > 0) {
      return { ok: false, findings: [finding('PLAN_EVIDENCE_INDEX', taskID, `index not empty: ${stagedPaths.join(',')}`)], result: null };
    }
  }

  // Verify worktree boundary: every tracked-modified path must be in the boundary.
  for (const p of trackedModified) {
    if (!boundary.includes(p)) {
      return { ok: false, findings: [finding('PLAN_PRODUCT_BOUNDARY_OVERREACH', taskID, `undeclared modified path ${p}`)], result: null };
    }
  }
  // Untracked paths must be boundary paths, the current evidence path, or the
  // exact controller journal permitted by the current lifecycle operation. For
  // commit-task that is `.g6-committing` (and the `.g6-part` transient); a stray
  // `.g6-beginning`/`.g6-finalizing` is an out-of-order/crashed-state finding.
  for (const p of untracked) {
    if (boundary.includes(p)) continue;
    if (evidenceCommitPath && p === evidenceCommitPath) continue;
    if (p.endsWith('.g6-committing') || p.endsWith('.g6-part')) continue;
    if (p.endsWith('.g6-beginning') || p.endsWith('.g6-finalizing')) {
      return { ok: false, findings: [finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, `out-of-order journal path ${p} during commit`)], result: null };
    }
    return { ok: false, findings: [finding('PLAN_PRODUCT_BOUNDARY_OVERREACH', taskID, `undeclared untracked path ${p}`)], result: null };
  }
  // Every boundary path must be present (modified or untracked) — underreach check.
  for (const p of boundary) {
    if (!trackedModified.includes(p) && !untracked.includes(p)) {
      // Could be already-committed (no change) — that's fine for re-runs after commit.
      // But before commit, a boundary path with no worktree change means underreach.
      const hasChange = trackedModified.includes(p) || untracked.includes(p);
      if (!hasChange && !existingProduct) {
        return { ok: false, findings: [finding('PLAN_PRODUCT_BOUNDARY_UNDERREACH', taskID, `boundary path ${p} not present in worktree`)], result: null };
      }
    }
  }

  // Write the .g6-committing journal.
  const journalContent = canonicalJSONStringify({
    base: baseCommit, boundary, dispositions: boundary, fileHashes: running.fileHashes || [],
    identity: IDENTITY, subject: `monacode: complete ${taskID}`, expectedEvidencePriorHash: null,
  });
  if (!hasJournal) {
    const fd = _fs.openSync(journalPath, 'w');
    _fs.writeSync(fd, journalContent);
    _fs.fsyncSync(fd);
    _fs.closeSync(fd);
  }
  if (hooks2.afterJournal) {
    try { hooks2.afterJournal(); }
    catch (e) { return { ok: false, findings: [finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, `controller stopped after journal: ${e.message}`)], result: null }; }
  }

  // Stage each boundary path one at a time.
  for (const p of boundary) {
    const r = gitRunner(['add', '--', p]);
    if (r.status !== 0) {
      return { ok: false, findings: [finding('PLAN_PRODUCT_BOUNDARY_UNDERREACH', taskID, `git add ${p} failed: ${r.stderr}`)], result: null };
    }
    if (hooks2.afterStagedPath) { hooks2.afterStagedPath(p); }
  }

  // Verify cached diff == boundary.
  const cached = gitRunner(['diff', '--cached', '--name-status', '-z']);
  const stagedEntries = parseNameStatus(cached.stdout);
  const stagedPaths = stagedEntries.map((e) => e.path).sort();
  if (JSON.stringify(stagedPaths) !== JSON.stringify(boundary)) {
    return { ok: false, findings: [finding('PLAN_PRODUCT_BOUNDARY_OVERREACH', taskID, `staged paths [${stagedPaths.join(',')}] != boundary [${boundary.join(',')}]`)], result: null };
  }

  // Verify no undeclared product path in the worktree diff.
  const worktreeDiff = gitRunner(['diff', '--name-only', '-z']);
  const worktreePaths = worktreeDiff.stdout.split('\0').filter(Boolean);
  for (const p of worktreePaths) {
    if (!boundary.includes(p)) {
      return { ok: false, findings: [finding('PLAN_PRODUCT_BOUNDARY_OVERREACH', taskID, `undeclared worktree path ${p}`)], result: null };
    }
  }

  // Commit with closed env, hooks/signing disabled.
  const commitEnv = closedGitEnv();
  const commitR = gitRunnerWithEnv(repoRoot, ['-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgSign=false', 'commit', '--no-verify', '--no-gpg-sign', '-m', `monacode: complete ${taskID}`], commitEnv);
  if (commitR.status !== 0) {
    return { ok: false, findings: [finding('PLAN_PRODUCT_COMMIT_CONTRACT', taskID, `git commit failed: ${commitR.stderr}`)], result: null };
  }
  if (hooks2.afterCommit) { hooks2.afterCommit(); }

  // Verify the new commit.
  const newHead = gitRunner(['rev-parse', 'HEAD']);
  const newCommit = newHead.stdout.trim();
  const v = verifyProductCommit(gitRunner, newCommit, taskID, boundary, evidenceCommitPath);
  if (!v.ok) {
    return { ok: false, findings: v.findings, result: null };
  }

  // Append commit hash to running evidence.
  running.productCommit = newCommit;
  const partPath = evidenceFull + '.g6-part';
  try {
    const buf = Buffer.from(canonicalJSONStringify(running), 'utf8');
    const fd = _fs.openSync(partPath, 'w');
    _fs.writeSync(fd, buf);
    _fs.fsyncSync(fd);
    _fs.closeSync(fd);
    _fs.renameSync(partPath, evidenceFull);
  } catch (e) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, `evidence append failed: ${e.message}`)], result: null };
  }
  if (hooks2.afterEvidenceAppend) { hooks2.afterEvidenceAppend(); }

  // Remove the journal.
  try { _fs.rmSync(journalPath, { force: true }); } catch {}
  if (hooks2.afterJournalRemoval) { hooks2.afterJournalRemoval(); }

  return { ok: true, findings: [], result: { productCommit: newCommit, idempotent: false } };
}

function gitRunnerWithEnv(repoRoot, args, env) {
  const r = spawnSync(GIT_BIN, ['-C', repoRoot, ...args], { env, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
  return { stdout: r.stdout ?? '', stderr: r.stderr ?? '', status: r.status ?? 1 };
}

function verifyProductCommit(gitRunner, commit, taskID, boundary, evidencePath) {
  const findings = [];
  const parents = gitRunner(['rev-parse', `${commit}^`]);
  if (parents.status !== 0) {
    findings.push(finding('PLAN_PRODUCT_COMMIT_CONTRACT', taskID, 'product commit has no parent'));
    return { ok: false, findings };
  }
  // Identity + message.
  const show = gitRunner(['show', '-s', '--format=%an%n%ae%n%cn%n%ce%n%s', commit]);
  const lines = show.stdout.split('\n');
  if (lines[0] !== IDENTITY.name || lines[1] !== IDENTITY.email || lines[2] !== IDENTITY.name || lines[3] !== IDENTITY.email) {
    findings.push(finding('PLAN_PRODUCT_COMMIT_CONTRACT', taskID, 'product commit identity wrong'));
  }
  if (lines[4] !== `monacode: complete ${taskID}`) {
    findings.push(finding('PLAN_PRODUCT_COMMIT_CONTRACT', taskID, `product commit subject wrong: ${lines[4]}`));
  }
  // Boundary diff.
  const diff = gitRunner(['diff-tree', '-r', '--no-commit-id', '--name-only', commit]);
  const diffPaths = diff.stdout.split('\n').filter(Boolean).sort();
  if (JSON.stringify(diffPaths) !== JSON.stringify(boundary)) {
    findings.push(finding('PLAN_PRODUCT_COMMIT_CONTRACT', taskID, `product commit boundary [${diffPaths.join(',')}] != [${boundary.join(',')}]`));
  }
  // Evidence path not in delta.
  if (evidencePath && diffPaths.includes(evidencePath)) {
    findings.push(finding('PLAN_PRODUCT_COMMIT_CONTRACT', taskID, 'evidence path in product commit delta'));
  }
  return { ok: findings.length === 0, findings };
}

function parseStatus(stdout) {
  const entries = [];
  for (const line of stdout.split('\0')) {
    if (line.startsWith('? ')) { entries.push({ tracked: false, path: line.slice(2) }); }
    else if (line.startsWith('1 ') || line.startsWith('2 ')) {
      // porcelain v2 tracked line: "1 <XY> ... <path>" or "2 <XY> ... <path> <origpath>"
      const parts = line.split('\t');
      const p = parts[parts.length - 1];
      entries.push({ tracked: true, path: p });
    }
  }
  return entries;
}

function parseNameStatus(stdout) {
  const out = [];
  const parts = stdout.split('\0');
  for (let i = 0; i + 1 < parts.length; i += 2) {
    out.push({ status: parts[i], path: parts[i + 1] });
  }
  return out;
}

/**
 * Classify worktree rows from `git status --porcelain=v2 -z` for evidence/journal
 * discipline during a verification command. Permits the selected current running
 * evidence path and the `.g6-part` transient; every other evidence or journal
 * row (a stray `.g6-beginning`/`.g6-committing`/`.g6-finalizing`, or another
 * evidence path) is a finding.
 * @param {string} stdout
 * @param {string} evidencePath
 * @param {string} taskID
 * @returns {object[]}
 */
function classifyWorktreeRows(stdout, evidencePath, taskID) {
  const findings = [];
  const rows = parseStatus(stdout);
  for (const r of rows) {
    const p = r.path;
    // The selected current running evidence path is permitted.
    if (p === evidencePath) continue;
    // The .g6-part transient is permitted (its presence is checked separately).
    if (p.endsWith('.g6-part')) continue;
    // Any other .g6-* journal is out-of-order for a verification command.
    if (/\.g6-(beginning|committing|finalizing)$/.test(p)) {
      findings.push(finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, `stray journal path ${p} during run-command`));
      continue;
    }
    // Any other evidence path (under an evidence directory) is a stray evidence row.
    if (/(^|\/)evidence\/.+\.json$/.test(p) || /(^|\/)acceptance-evidence\//.test(p)) {
      findings.push(finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, `stray evidence path ${p} during run-command`));
    }
  }
  return findings;
}

// ---------------------------------------------------------------------------
// finalizeEvidence — sole evidence-commit creator
// ---------------------------------------------------------------------------

/**
 * After the product commit, validate its parent/identity/message/tree/boundary
 * and task results, clean the token-owned workspace, publish the passed record,
 * and create or resume the one evidence-only commit.
 * @param {{
 *   plan: object, taskID: string, repoRoot: string, evidencePath: string,
 *   path: string, git?: Function, fs?: object, hooks?: object,
 * }} input
 */
export async function finalizeEvidence({ plan, taskID, repoRoot, evidencePath, path: evidencePathArg, git, fs: fsOpt, hooks }) {
  const _fs = fsOpt || fs;
  const hooks2 = hooks || {};
  const evidenceFull = path.join(repoRoot, evidencePath);
  const journalPath = evidenceFull + '.g6-finalizing';
  const task = (plan.tasks || []).find((t) => t.taskID === taskID);
  if (!task) return { ok: false, findings: [finding('PLAN_EVIDENCE_STATE', taskID, 'task not in plan')], result: null };

  const gitRunner = git || ((args) => realGit(repoRoot, args));

  // Read running evidence.
  let running;
  try { running = JSON.parse(_fs.readFileSync(evidenceFull, 'utf8')); } catch {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_STATE', taskID, 'running evidence unreadable')], result: null };
  }
  const productCommit = running.productCommit;
  if (!productCommit) return { ok: false, findings: [finding('PLAN_EVIDENCE_FINALIZE_PARENT', taskID, 'no product commit in running evidence')], result: null };

  // Verify HEAD == product commit.
  const head = gitRunner(['rev-parse', 'HEAD']);
  const headCommit = head.stdout.trim();

  // Re-entry: if HEAD is already the evidence commit (sole parent productCommit), verify.
  if (headCommit !== productCommit) {
    // Could be the evidence commit already.
    const parents = gitRunner(['rev-parse', `${headCommit}^`]);
    if (parents.status === 0 && parents.stdout.trim() === productCommit) {
      // Verify it's the evidence commit.
      const show = gitRunner(['show', '-s', '--format=%an%n%ae%n%cn%n%ce%n%s', headCommit]);
      const lines = show.stdout.split('\n');
      if (lines[0] === IDENTITY.name && lines[1] === IDENTITY.email && lines[4] === `evidence(monacode): complete ${taskID}`) {
        const diff = gitRunner(['diff-tree', '-r', '--no-commit-id', '--name-only', headCommit]);
        if (diff.stdout.trim() === evidencePath) {
          return { ok: true, findings: [], result: { evidenceCommit: headCommit, idempotent: true } };
        }
      }
      // HEAD moved past product commit — reject.
      return { ok: false, findings: [finding('PLAN_EVIDENCE_FINALIZE_PARENT', taskID, `HEAD ${headCommit} is not the product commit ${productCommit}`)], result: null };
    }
    return { ok: false, findings: [finding('PLAN_EVIDENCE_FINALIZE_PARENT', taskID, `HEAD ${headCommit} is not the product commit ${productCommit}`)], result: null };
  }

  // Verify product commit identity/message/boundary.
  const boundary = (task.productCommit && task.productCommit.stagedProductPaths || []).slice().sort();
  const v = verifyProductCommit(gitRunner, productCommit, taskID, boundary, evidencePath);
  if (!v.ok) return { ok: false, findings: v.findings, result: null };

  // Revalidate running command/acquisition/file/assertion/mutation results.
  const audit = auditTaskEvidence({ plan, taskID, evidence: running, dependencyEvidence: [] });
  if (audit.length > 0) return { ok: false, findings: audit, result: null };

  // Validate task-root realpath, mode-0600 marker, ownership-token hash.
  const taskRoot = running.taskRoot;
  const tokenSha256 = running.tokenSha256;
  if (typeof taskRoot !== 'string' || !taskRoot.startsWith('/')) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_TOKEN', taskID, 'task root missing')], result: null };
  }
  const markerPath = path.join(taskRoot, '.token');
  let markerStat;
  try { markerStat = _fs.statSync(markerPath); } catch {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_TOKEN', taskID, 'task-root marker missing')], result: null };
  }
  if ((markerStat.mode & 0o777) !== 0o600) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_TOKEN', taskID, `marker mode ${(markerStat.mode & 0o777).toString(8)} != 600`)], result: null };
  }
  const markerToken = _fs.readFileSync(markerPath);
  if (markerToken.length !== 32 || sha256Buf(markerToken) !== tokenSha256) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_TOKEN', taskID, 'workspace token mismatch')], result: null };
  }

  // Build the passed bytes via finalizeTaskEvidence (Task 9 lib).
  const show = gitRunner(['show', '-s', '--format=%an%n%ae%n%cn%n%ce%n%s', productCommit]);
  const sl = show.stdout.split('\n');
  const productCommitObj = {
    hash: productCommit,
    parent: running.baseCommit,
    author: { name: sl[0], email: sl[1] },
    committer: { name: sl[2], email: sl[3] },
    message: sl[4],
    stagedPaths: boundary,
    treeDelta: gitRunner(['diff-tree', '-r', '--no-commit-id', '--name-only', productCommit]).stdout.split('\n').filter(Boolean),
  };
  const fin = finalizeTaskEvidence({ plan, taskID, evidence: running, productCommit: productCommitObj });
  if (fin.state !== 'passed') {
    return { ok: false, findings: fin.findings || [finding('PLAN_EVIDENCE_FINALIZE_PARENT', taskID, 'finalize predicate failed')], result: null };
  }
  const passedBytes = fin.passedBytes;
  const passedSha256 = fin.passedSha256;

  // Write the .g6-finalizing journal.
  const hasJournal = _fs.existsSync(journalPath);
  if (!hasJournal) {
    const journalContent = canonicalJSONStringify({
      productCommit, evidencePath, root: taskRoot, tokenHash: tokenSha256,
      tombstone: `${taskRoot}.g6-delete-${tokenSha256}`,
      passedSha256, subject: `evidence(monacode): complete ${taskID}`,
      identity: IDENTITY,
    });
    const fd = _fs.openSync(journalPath, 'w');
    _fs.writeSync(fd, journalContent);
    _fs.fsyncSync(fd);
    _fs.closeSync(fd);
  }
  if (hooks2.afterJournal) {
    try { hooks2.afterJournal(); }
    catch (e) { return { ok: false, findings: [finding('PLAN_EVIDENCE_JOURNAL_STATE', taskID, `controller stopped after journal: ${e.message}`)], result: null }; }
  }

  // Atomically rename root to <ROOT>.g6-delete-<TOKEN_SHA256> and remove only that tombstone.
  const tombstone = `${taskRoot}.g6-delete-${tokenSha256}`;
  if (_fs.existsSync(taskRoot) && !_fs.existsSync(tombstone)) {
    _fs.renameSync(taskRoot, tombstone);
  }
  if (_fs.existsSync(tombstone)) {
    _fs.rmSync(tombstone, { recursive: true, force: true });
  }
  if (hooks2.afterCleanup) { hooks2.afterCleanup(); }

  // Publish the passed bytes via .g6-part.
  const partPath = evidenceFull + '.g6-part';
  {
    const fd = _fs.openSync(partPath, 'w');
    _fs.writeSync(fd, Buffer.from(passedBytes, 'utf8'));
    _fs.fsyncSync(fd);
    _fs.closeSync(fd);
    _fs.renameSync(partPath, evidenceFull);
    const parent = path.dirname(evidenceFull);
    try { const pfd = _fs.openSync(parent, 'r'); _fs.fsyncSync(pfd); _fs.closeSync(pfd); } catch {}
  }
  if (hooks2.afterPublish) { hooks2.afterPublish(); }

  // Stage exactly the evidence path.
  gitRunner(['add', '--', evidencePath]);
  if (hooks2.afterStage) { hooks2.afterStage(); }

  // Verify cached diff is one added evidence blob + no journal.
  const cached = gitRunner(['diff', '--cached', '--name-status', '-z']);
  const staged = parseNameStatus(cached.stdout);
  if (staged.length !== 1 || staged[0].path !== evidencePath) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_FINALIZE_BOUNDARY', taskID, `staged [${staged.map((s) => s.path).join(',')}] != [${evidencePath}]`)], result: null };
  }

  // Create the evidence commit.
  const commitEnv = closedGitEnv();
  const commitR = gitRunnerWithEnv(repoRoot, ['-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgSign=false', 'commit', '--no-verify', '--no-gpg-sign', '-m', `evidence(monacode): complete ${taskID}`], commitEnv);
  if (commitR.status !== 0) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_CONTRACT', taskID, `evidence commit failed: ${commitR.stderr}`)], result: null };
  }
  if (hooks2.afterCommit) { hooks2.afterCommit(); }

  // Verify the evidence commit.
  const newHead = gitRunner(['rev-parse', 'HEAD']);
  const evidenceCommit = newHead.stdout.trim();
  const parents = gitRunner(['rev-parse', `${evidenceCommit}^`]);
  if (parents.stdout.trim() !== productCommit) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_COMMIT_PARENT', taskID, 'evidence commit parent != product commit')], result: null };
  }
  const eshow = gitRunner(['show', '-s', '--format=%an%n%ae%n%cn%n%ce%n%s', evidenceCommit]);
  const el = eshow.stdout.split('\n');
  if (el[0] !== IDENTITY.name || el[1] !== IDENTITY.email || el[4] !== `evidence(monacode): complete ${taskID}`) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_COMMIT_IDENTITY', taskID, 'evidence commit identity/message wrong')], result: null };
  }
  const ediff = gitRunner(['diff-tree', '-r', '--no-commit-id', '--name-only', evidenceCommit]);
  if (ediff.stdout.trim() !== evidencePath) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_COMMIT_BOUNDARY', taskID, `evidence commit diff != ${evidencePath}`)], result: null };
  }
  // Blob bytes == prehashed passed bytes.
  const blob = gitRunner(['cat-file', 'blob', `${evidenceCommit}:${evidencePath}`]);
  if (sha256(blob.stdout) !== passedSha256) {
    return { ok: false, findings: [finding('PLAN_EVIDENCE_BLOB', taskID, 'evidence blob bytes != prehashed passed bytes')], result: null };
  }
  if (hooks2.afterVerify) { hooks2.afterVerify(); }

  // Remove the journal.
  try { _fs.rmSync(journalPath, { force: true }); } catch {}
  if (hooks2.afterJournalRemoval) { hooks2.afterJournalRemoval(); }

  return { ok: true, findings: [], result: { evidenceCommit, passedSha256, productCommit } };
}
