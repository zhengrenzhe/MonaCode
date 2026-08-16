#!/usr/bin/env node
// G6-R payload-index writer (Task 26).
//
// Produces the closed 232-row payload index for the G6-R archive. The index is
// the single source of truth for which archive paths are present (produced by
// a completed SDD task) versus planned (produced by a later task), their Git
// mode (100644 for every G6-R archive row), and their checksum disposition
// (checksum / self-index / hash-cycle-excluded).
//
// CLI:  update-payload-index.mjs --through-task TASK_NUMBER
//   Task 26-32 write the real index; target 33 is rejected (the adoption
//   module calls buildPayloadIndex directly with the cursor-32 base and the
//   seven-path virtual final overlay).
//
// buildPayloadIndex({ completedThroughTask, overlay }) is the pure byte
// producer used by the Task 33 adoption transaction; it performs no write.
//
// presence = producerTask <= completedThroughTask. The 9 planned paths are
// produced by Tasks 27 (5), 28 (1), 29 (1), and 33 (2). The two Task-33
// adoption files (SHA256SUMS, adoption-record.json) are hash-cycle-excluded;
// the payload-index.json row is self-index (no self-hash). Every row carries
// gitMode "100644" and exactly one authoring-task producer.

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { canonicalJSONStringify } from '../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/canonical-json.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const ARCHIVE_ROOT = path.join(REPO_ROOT, 'docs/contracts/monaco-editor-0.56.0/g6-r');
const INDEX_PATH = path.join(ARCHIVE_ROOT, 'implementation-plan', 'verification', 'payload-index.json');

const runtimeStateNames = new Set(['.last-port', '.last-token', 'server-info', 'server-instance-id', 'server.pid']);

// Task 26 declared archive paths (the 16 files this task creates inside the
// g6-r archive). Their producerTask is 26.
const TASK26_PATHS = [
  'implementation-plan/lib/audit.mjs',
  'implementation-plan/lib/ambiguity.mjs',
  'implementation-plan/lib/boundaries.mjs',
  'implementation-plan/lib/coverage.mjs',
  'implementation-plan/lib/graph.mjs',
  'implementation-plan/lib/inventory.mjs',
  'implementation-plan/lib/markdown.mjs',
  'implementation-plan/verify-plan.mjs',
  'verify-contract.mjs',
  'artifacts/monacode-g6r-audit.mjs',
  'implementation-plan/tests/archive-verifier.test.mjs',
  'implementation-plan/tests/audit.test.mjs',
  'implementation-plan/tests/boundaries.test.mjs',
  'implementation-plan/tests/coverage.test.mjs',
  'implementation-plan/tests/markdown.test.mjs',
  'implementation-plan/verification/payload-index.json',
];

// The 9 planned archive paths produced by Tasks 27-33.
const PLANNED_PATHS = [
  { path: 'implementation-plan/lib/mutation-coverage.mjs', producerTask: 27 },
  { path: 'implementation-plan/tests/fixtures/mutation-fixtures.json', producerTask: 27 },
  { path: 'implementation-plan/tests/mutation-coverage.test.mjs', producerTask: 27 },
  { path: 'implementation-plan/tests/negative-fixtures.test.mjs', producerTask: 27 },
  { path: 'implementation-plan/verification/plan-audit.json', producerTask: 27 },
  { path: 'implementation-plan/verification/cold-checkout-preflight.json', producerTask: 28 },
  { path: 'implementation-plan/verification/adversarial-plan-review.md', producerTask: 29 },
  { path: 'SHA256SUMS', producerTask: 33 },
  { path: 'adoption-record.json', producerTask: 33 },
];

const TASK26_SET = new Set(TASK26_PATHS);
const SELF_INDEX_PATH = 'implementation-plan/verification/payload-index.json';
const HASH_CYCLE_EXCLUDED = new Set(['SHA256SUMS', 'adoption-record.json']);

// Expected HEAD subject for each authoring transition (the 35-commit sequence).
const EXPECTED_HEAD_SUBJECT = {
  26: 'docs: define MonaCode G6-R contract candidate',
};

function walkArchive(root) {
  const files = [];
  const walk = (rel) => {
    let entries;
    try { entries = fs.readdirSync(path.join(root, rel), { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (runtimeStateNames.has(e.name)) continue;
      const relp = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) walk(relp);
      else if (e.isFile()) files.push(relp);
    }
  };
  walk('');
  return files.sort((a, b) => a.localeCompare(b, 'en'));
}

function producerTaskFor(p) {
  for (const row of PLANNED_PATHS) if (row.path === p) return row.producerTask;
  if (TASK26_SET.has(p)) return 26;
  // Every other present archive path was produced by an earlier SDD task
  // (candidate skeleton / plan assembly / Tasks 1-25); all are complete
  // through Task 26, so producerTask 25 is the honest bound.
  return 25;
}

function checksumDispositionFor(p) {
  if (p === SELF_INDEX_PATH) return 'self-index';
  if (HASH_CYCLE_EXCLUDED.has(p)) return 'hash-cycle-excluded';
  return 'checksum';
}

function sha256File(root, rel) {
  const full = path.join(root, rel);
  try {
    return createHash('sha256').update(fs.readFileSync(full)).digest('hex');
  } catch {
    return null;
  }
}

/**
 * Build the closed 232-row payload index for the given completion cursor.
 * @param {{completedThroughTask:number, overlay?:Array<{path:string,bytes:Buffer|string}>, archiveRoot?:string}} input
 * @returns {{schemaVersion:number, completedThroughTask:number, rows:Array, selfIndex:object}}
 */
export function buildPayloadIndex({ completedThroughTask, overlay = [], archiveRoot = ARCHIVE_ROOT }) {
  const present = walkArchive(archiveRoot);
  const presentSet = new Set(present);
  // Merge planned paths + the closed Task-26 declared paths (the index is
  // self-referential: payload-index.json is a row that does not yet exist on
  // disk when the writer runs).
  const all = new Set(present);
  for (const p of TASK26_PATHS) all.add(p);
  for (const row of PLANNED_PATHS) all.add(row.path);
  for (const o of overlay) all.add(o.path);

  const rows = [];
  for (const p of [...all].sort((a, b) => a.localeCompare(b, 'en'))) {
    const producerTask = producerTaskFor(p);
    const presence = producerTask <= completedThroughTask ? 'present' : 'planned';
    const disposition = checksumDispositionFor(p);
    let sha256 = null;
    if (presence === 'present' && disposition === 'checksum') {
      const ovl = overlay.find((o) => o.path === p);
      if (ovl) {
        sha256 = createHash('sha256').update(typeof ovl.bytes === 'string' ? ovl.bytes : Buffer.from(ovl.bytes)).digest('hex');
      } else if (presentSet.has(p)) {
        sha256 = sha256File(archiveRoot, p);
      }
    }
    rows.push({
      path: p,
      producerTask,
      gitMode: '100644',
      presence,
      checksumDisposition: disposition,
      sha256,
    });
  }

  return {
    schemaVersion: 1,
    completedThroughTask,
    selfIndex: { path: SELF_INDEX_PATH, producerTask: 26, checksumDisposition: 'self-index' },
    rows,
  };
}

/**
 * Serialize the index to canonical JSON bytes (no self-hash to avoid a cycle).
 */
export function buildPayloadIndexBytes(input) {
  return canonicalJSONStringify(buildPayloadIndex(input)) + '\n';
}

// ---------------------------------------------------------------------------
// CLI transition guard.
// ---------------------------------------------------------------------------

function gitHeadSubject() {
  const r = spawnSync('/usr/bin/git', ['-C', REPO_ROOT, 'log', '-1', '--format=%s'], { encoding: 'utf8' });
  return r.stdout.trim();
}

function gitIndexEmpty() {
  const r = spawnSync('/usr/bin/git', ['-C', REPO_ROOT, 'status', '--porcelain', '--untracked-files=no'], { encoding: 'utf8' });
  // Empty Git index = no staged changes. We do not require a clean tree (the
  // Task 26 declared paths are unstaged by design); we require nothing staged.
  return r.stdout.trim().length === 0;
}

function priorIndexCursor() {
  if (!fs.existsSync(INDEX_PATH)) return null;
  try {
    const j = JSON.parse(fs.readFileSync(INDEX_PATH, 'utf8'));
    return typeof j.completedThroughTask === 'number' ? j.completedThroughTask : null;
  } catch {
    return null;
  }
}

function fail(msg) {
  process.stderr.write(`update-payload-index: ${msg}\n`);
  process.exit(1);
}

function main(argv) {
  const args = argv ?? process.argv.slice(2);
  if (args.length !== 2 || args[0] !== '--through-task') {
    fail('expected exactly --through-task TASK_NUMBER');
  }
  const task = Number(args[1]);
  if (!Number.isInteger(task) || task < 26 || task > 32) {
    fail('TASK_NUMBER must be an integer in [26, 32] (target 33 is reserved for the adoption module)');
  }

  // Prior-index cursor (declared before the guards that use it).
  const prior = priorIndexCursor();

  // HEAD subject guard. Enforced only for the first authoring transition
  // (none -> 26, when no prior index exists and HEAD must equal the Task 25
  // candidate commit). Forward transitions (26 -> 27, etc.) carry their own
  // expected HEAD in their own commits; same-cursor re-runs are refreshes that
  // do not re-check HEAD.
  if (prior === null && EXPECTED_HEAD_SUBJECT[task]) {
    const subject = gitHeadSubject();
    if (subject !== EXPECTED_HEAD_SUBJECT[task]) {
      fail(`HEAD subject "${subject}" != expected "${EXPECTED_HEAD_SUBJECT[task]}" for transition to Task ${task}`);
    }
  }

  // Prior-index state guard. The authoring transitions are one-shot per cursor:
  // none -> 26 (no prior index), 26 -> 27, 27 -> 28, etc. Re-running the SAME
  // cursor (prior === task) is a benign refresh of the committed index, not an
  // authoring transition, and is allowed so the Step 4 sequence is reproducible
  // from the committed state.
  if (prior !== null && prior !== task) {
    if (task === 26) fail(`transition none -> 26 requires no prior index, found cursor ${prior}`);
    if (prior !== task - 1) fail(`transition ${prior} -> ${task} requires prior cursor ${task - 1}, found ${prior}`);
  }

  const idx = buildPayloadIndex({ completedThroughTask: task });
  fs.mkdirSync(path.dirname(INDEX_PATH), { recursive: true });
  fs.writeFileSync(INDEX_PATH, canonicalJSONStringify(idx) + '\n');
  const present = idx.rows.filter((r) => r.presence === 'present').length;
  const planned = idx.rows.filter((r) => r.presence === 'planned').length;
  process.stdout.write(`payload-index: through-task=${task} rows=${idx.rows.length} present=${present} planned=${planned} mode100644=${idx.rows.filter((r) => r.gitMode === '100644').length}\n`);
}

if (process.argv[1] === __filename) {
  main();
}
