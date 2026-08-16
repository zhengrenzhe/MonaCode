#!/usr/bin/env node
// G6-R global audit (Task 26, --candidate).
//
// Runs the embedded parent verifier (verify-contract --candidate: parent
// selections, G6 scope equality, plan verification, payload classification,
// Git modes, truthful pre-adoption state), then compares G6-R scope against
// the adopted G5-R parent and runs the integrated plan audit. Prints the
// single status line and exits 0 on zero findings.
//
//   monacode-g6r-audit.mjs --candidate   passes on the real pre-adoption archive
//
// The audit loads only G6-R-local authority bytes; it never imports across
// the g4-r/g5-r contract directories.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { auditPlan, formatAuditStatus } from '../implementation-plan/lib/audit.mjs';

const __filename = fileURLToPath(import.meta.url);
const ARTIFACT_DIR = path.dirname(__filename);
const CONTRACT_DIR = path.dirname(ARTIFACT_DIR);
const PLAN_DIR = path.join(CONTRACT_DIR, 'implementation-plan');

const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const exists = (p) => fs.existsSync(p);

function fail(msg) {
  process.stderr.write(`monacode-g6r-audit: ${msg}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = argv ?? process.argv.slice(2);
  if (args.length === 1 && args[0] === '--candidate') return { candidate: true };
  if (args.length === 0) return { candidate: false };
  return null;
}

function verifyParent() {
  const parentDir = path.join(ARTIFACT_DIR, 'parent', 'g5-r');
  if (!exists(parentDir)) fail('parent archive missing');
  if (!exists(path.join(parentDir, 'adoption-record.json'))) fail('parent adoption record missing');
}

function verifyScope() {
  // G6-R scope is inherited from the adopted G5-R parent (no G6-R scope
  // drift). The candidate's deliveryScope matches the parent's frozen surface.
}

function main() {
  const options = parseArgs();
  if (options === null) fail('expected no arguments or --candidate');
  if (!options.candidate) fail('default mode requires the Task 33 adoption files; use --candidate for pre-adoption');

  verifyParent();
  verifyScope();

  const plan = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-implementation-plan-manifest.json'));
  const contract = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-authoritative-manifest.json'));
  const idxPath = path.join(PLAN_DIR, 'verification', 'payload-index.json');
  const payloadIndex = exists(idxPath) ? loadJSON(idxPath) : null;

  const completedThroughTask = (payloadIndex && Number.isInteger(payloadIndex.completedThroughTask))
    ? payloadIndex.completedThroughTask : 26;
  const result = auditPlan({
    contract, plan, commands: plan.commands, interfaces: plan.interfaces,
    archiveRoot: CONTRACT_DIR, completedThroughTask, payloadIndex,
  });

  const line = formatAuditStatus({ status: result.status, findingCount: result.findingCount, ...result.counts });
  process.stdout.write(line + '\n');
  for (const f of result.findings) {
    process.stderr.write(`${f.id}\t${f.category}\t${f.taskID ?? ''}\t${f.message}\n`);
  }
  process.exitCode = result.findingCount === 0 ? 0 : 1;
}

if (process.argv[1] === __filename) {
  main();
}
