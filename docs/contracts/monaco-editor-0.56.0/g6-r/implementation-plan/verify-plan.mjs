#!/usr/bin/env node
// G6-R plan verifier (Task 26).
//
// Loads the assembled G6-R plan, contract, commands, interfaces, and payload
// index from the archive, runs the integrated execution audit, and prints the
// single status line. Exit 0 = zero findings; exit 1 = findings.
//
//   verify-plan.mjs                         normal verification (read-only)
//   verify-plan.mjs --write-audit AUDIT_PATH closed authoring mode (Task 27)
//
// The --write-audit mode is valid only at the Task 27 base with the exact
// Task 27 declared working set; it projects completedThroughTask=27 plus the
// audit output and the refreshed payload index in memory, writes only
// AUDIT_PATH, and refuses every other state. Normal verification takes no
// flag and compares nothing.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { auditPlan, formatAuditStatus } from './lib/audit.mjs';

const __filename = fileURLToPath(import.meta.url);
const PLAN_DIR = path.dirname(__filename);
const CONTRACT_DIR = path.dirname(PLAN_DIR);
const ARCHIVE_ROOT = CONTRACT_DIR;
const ARTIFACT_DIR = path.join(CONTRACT_DIR, 'artifacts');

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
  const result = auditPlan({
    contract,
    plan,
    commands: plan.commands,
    interfaces: plan.interfaces,
    archiveRoot: ARCHIVE_ROOT,
    completedThroughTask: 26,
    payloadIndex,
  });
  const line = formatAuditStatus({ status: result.status, findingCount: result.findingCount, ...result.counts });
  process.stdout.write(line + '\n');
  for (const f of result.findings) {
    process.stderr.write(`${f.id}\t${f.category}\t${f.taskID ?? ''}\t${f.message}\n`);
  }
  process.exitCode = result.findingCount === 0 ? 0 : 1;
}

function runWriteAudit(auditPath) {
  // Closed authoring mode (Task 27). Requires HEAD to equal the Task 26
  // commit, the committed index cursor to equal 26, an empty Git index, and
  // the unstaged path set to equal the Task 27 declarations other than the
  // not-yet-written audit path and unchanged payload-index path. Projects
  // completedThroughTask=27 plus the audit output and cursor-27 payload index
  // in memory, writes only AUDIT_PATH, and refuses every other state.
  //
  // At Task 26 this mode is not yet valid (the Task 27 base has not been
  // committed); it refuses with a finding so the Task 27 commit can enable it.
  usageFailure('--write-audit is the closed Task 27 authoring mode; it is not valid at the Task 26 base');
}

const options = parseArgs();
if (options === null) {
  usageFailure('expected no arguments or --write-audit AUDIT_PATH');
} else if (options.mode === 'verify') {
  runVerify();
} else {
  runWriteAudit(options.auditPath);
}
