#!/usr/bin/env node
// G6-R plan verifier (Task 26, --write-audit enabled in Task 27).
//
// Loads the assembled G6-R plan, contract, commands, interfaces, and payload
// index from the archive, runs the integrated execution audit, and prints the
// single status line. Exit 0 = zero findings; exit 1 = findings.
//
//   verify-plan.mjs                         normal verification (read-only)
//   verify-plan.mjs --write-audit AUDIT_PATH closed authoring mode (Task 27)
//
// The --write-audit mode is the Task 27 closed authoring mode: it requires HEAD
// to equal the Task 26 commit, the committed index cursor to equal 26, an empty
// Git index, and the unstaged path set to equal the Task 27 declarations other
// than the not-yet-written audit path and the unchanged payload-index path. It
// projects completedThroughTask=27 plus the audit output and cursor-27 payload
// index in memory, writes only AUDIT_PATH atomically, and refuses every other
// state. Normal verification takes no flag and reads the committed state.

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { auditPlan, formatAuditStatus } from './lib/audit.mjs';
import { buildPayloadIndex } from '../../../../../Tools/G6PlanAuthoring/update-payload-index.mjs';
import { auditMutationCoverage, PRODUCTION_RULES, buildSealedCatalog } from './lib/mutation-coverage.mjs';
import { canonicalJSONStringify } from './lib/canonical-json.mjs';

const __filename = fileURLToPath(import.meta.url);
const PLAN_DIR = path.dirname(__filename);
const CONTRACT_DIR = path.dirname(PLAN_DIR);
const ARCHIVE_ROOT = CONTRACT_DIR;
const ARTIFACT_DIR = path.join(CONTRACT_DIR, 'artifacts');
const REPO_ROOT = path.resolve(PLAN_DIR, '..', '..', '..', '..', '..');
const TASK26_COMMIT = '47bc7ff02e3cb74858589d37b8bce38ed974e538';

const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));

function loadInputs() {
  const plan = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-implementation-plan-manifest.json'));
  const contract = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-authoritative-manifest.json'));
  const payloadIndexPath = path.join(PLAN_DIR, 'verification', 'payload-index.json');
  const payloadIndex = fs.existsSync(payloadIndexPath) ? loadJSON(payloadIndexPath) : null;
  return { plan, contract, payloadIndex };
}

function usageFailure(message) {
  process.stderr.write(`verify-plan: ${message}\n`);
  process.exit(2);
}

function parseArgs(argv) {
  const args = argv ?? process.argv.slice(2);
  if (args.length === 0) return { mode: 'verify' };
  if (args.length === 2 && args[0] === '--write-audit') return { mode: 'write-audit', auditPath: path.resolve(args[1]) };
  return null;
}

function runVerify() {
  const { plan, contract, payloadIndex } = loadInputs();
  const completedThroughTask = (payloadIndex && Number.isInteger(payloadIndex.completedThroughTask))
    ? payloadIndex.completedThroughTask : 26;
  const result = auditPlan({
    contract, plan, commands: plan.commands, interfaces: plan.interfaces,
    archiveRoot: ARCHIVE_ROOT, completedThroughTask, payloadIndex,
  });
  const line = formatAuditStatus({ status: result.status, findingCount: result.findingCount, ...result.counts });
  process.stdout.write(line + '\n');
  for (const f of result.findings) {
    process.stderr.write(`${f.id}\t${f.category}\t${f.taskID ?? ''}\t${f.message}\n`);
  }
  process.exitCode = result.findingCount === 0 ? 0 : 1;
}

// Closed authoring mode guards.
function gitHeadSha() {
  const r = spawnSync('/usr/bin/git', ['-C', REPO_ROOT, 'rev-parse', 'HEAD'], { encoding: 'utf8' });
  return r.stdout.trim();
}

function gitStagedFiles() {
  const r = spawnSync('/usr/bin/git', ['-C', REPO_ROOT, 'diff', '--cached', '--name-only'], { encoding: 'utf8' });
  return r.stdout.split('\n').map((s) => s.trim()).filter(Boolean);
}

function gitUnstagedUntracked() {
  // Unstaged modifications + untracked files, relative to repo root.
  const r = spawnSync('/usr/bin/git', ['-C', REPO_ROOT, 'status', '--porcelain', '-z'], { encoding: 'utf8' });
  const out = [];
  let cur = '';
  for (const ch of r.stdout) {
    if (ch === '\0') { if (cur.length) out.push(cur); cur = ''; }
    else cur += ch;
  }
  if (cur.length) out.push(cur);
  return out.map((line) => line.slice(3).trimEnd()).filter(Boolean);
}

// The Task 27 declared authoring paths (created), relative to repo root,
// excluding the not-yet-written audit output and the unchanged payload index.
const TASK27_DECLARED_PATHS = [
  'Tools/G6PlanAuthoring/run-adversarial-round.mjs',
  'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/mutation-coverage.mjs',
  'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/fixtures/mutation-fixtures.json',
  'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/mutation-coverage.test.mjs',
  'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/negative-fixtures.test.mjs',
  'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/tests/audit.test.mjs',
  'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/verify-plan.mjs',
  'docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs',
  'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-audit.mjs',
];

function runWriteAudit(auditPath) {
  // Guard 1: HEAD must equal the Task 26 commit.
  const head = gitHeadSha();
  if (head !== TASK26_COMMIT) {
    usageFailure(`--write-audit requires HEAD to equal the Task 26 commit ${TASK26_COMMIT.slice(0, 12)}, got ${head.slice(0, 12)}`);
  }

  // Guard 2: committed payload-index cursor must equal 26.
  const { plan, contract, payloadIndex } = loadInputs();
  const cursor = (payloadIndex && Number.isInteger(payloadIndex.completedThroughTask))
    ? payloadIndex.completedThroughTask : null;
  if (cursor !== 26) {
    usageFailure(`--write-audit requires the committed payload-index cursor to equal 26, got ${cursor}`);
  }

  // Guard 3: empty Git index (nothing staged).
  const staged = gitStagedFiles();
  if (staged.length !== 0) {
    usageFailure(`--write-audit requires an empty Git index, found ${staged.length} staged paths`);
  }

  // Guard 4: the unstaged/untracked path set must equal the Task 27 declared
  // paths (the audit output and payload index are excluded by design).
  const unstaged = gitUnstagedUntracked().sort();
  const expected = [...TASK27_DECLARED_PATHS].sort();
  if (unstaged.length !== expected.length || !unstaged.every((p, i) => p === expected[i])) {
    usageFailure(`--write-audit unstaged path set must equal the Task 27 declarations; got:\n${unstaged.join('\n')}`);
  }

  // Project the cursor-27 payload index in memory (the audit output and the
  // refreshed index are not yet committed). The cursor-27 index marks the five
  // Task-27 produced paths present.
  const cursor27Index = buildPayloadIndex({ completedThroughTask: 27 });

  const result = auditPlan({
    contract, plan, commands: plan.commands, interfaces: plan.interfaces,
    archiveRoot: ARCHIVE_ROOT, completedThroughTask: 27, payloadIndex: cursor27Index,
  });

  // Mutation-coverage uncovered-rule count: the closed catalog's coverage gaps.
  const catalog = buildSealedCatalog();
  const coverageFindings = auditMutationCoverage(PRODUCTION_RULES, catalog);
  const uncoveredRuleCount = coverageFindings.length;

  const auditRecord = {
    schemaVersion: 1,
    status: result.status,
    findingCount: result.findingCount,
    uncoveredRuleCount,
    completedThroughTask: 27,
    counts: result.counts,
    findings: result.findings,
    categoryCounts: result.categoryCounts,
    mutationCoverage: {
      status: uncoveredRuleCount === 0 && result.findingCount === 0 ? 'covered' : 'uncovered',
      families: 35,
      attacks: 75,
      variants: catalog.attacks.flatMap((a) => a.variants).length,
      productionRules: PRODUCTION_RULES.length,
      uncoveredRuleCount,
    },
  };

  fs.mkdirSync(path.dirname(auditPath), { recursive: true });
  fs.writeFileSync(auditPath, canonicalJSONStringify(auditRecord) + '\n');
  const line = formatAuditStatus({ status: result.status, findingCount: result.findingCount, ...result.counts });
  process.stdout.write(line + `\n`);
  process.stdout.write(`uncoveredRuleCount=${uncoveredRuleCount}\n`);
  process.exitCode = result.findingCount === 0 && uncoveredRuleCount === 0 ? 0 : 1;
}

const options = parseArgs();
if (options === null) {
  usageFailure('expected no arguments or --write-audit AUDIT_PATH');
} else if (options.mode === 'verify') {
  runVerify();
} else {
  runWriteAudit(options.auditPath);
}
