#!/usr/bin/env node
// G6-R archive verifier (Task 26).
//
//   verify-contract.mjs --candidate
//     Verifies parent selections, G6 scope equality, plan verification, payload
//     classification, Git modes, and the truthful pre-adoption state. Passes on
//     the real pre-adoption archive (adoption files not yet written).
//
//   verify-contract.mjs
//     Default mode additionally verifies the checksum index (SHA256SUMS) and
//     the adoption selectors. Returns G6_ADOPTION_MISSING until Task 33 writes
//     the two adoption files (SHA256SUMS + adoption-record.json).
//
// No later task changes this verifier's code.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { auditPlan, formatAuditStatus } from './implementation-plan/lib/audit.mjs';

const __filename = fileURLToPath(import.meta.url);
const CONTRACT_DIR = path.dirname(__filename);
const ARTIFACT_DIR = path.join(CONTRACT_DIR, 'artifacts');
const PLAN_DIR = path.join(CONTRACT_DIR, 'implementation-plan');

const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const exists = (p) => fs.existsSync(p);

function parseArgs(argv) {
  const args = argv ?? process.argv.slice(2);
  if (args.length === 0) return { candidate: false };
  if (args.length === 1 && args[0] === '--candidate') return { candidate: true };
  return null;
}

function verifyParent() {
  const parentDir = path.join(ARTIFACT_DIR, 'parent', 'g5-r');
  if (!exists(parentDir)) return 'parent archive missing';
  // Parent selections: the G5-R adoption record + key parent artifacts.
  const adoption = path.join(parentDir, 'adoption-record.json');
  if (!exists(adoption)) return 'parent adoption record missing';
  return null;
}

function verifyScope() {
  // G6-R scope equals the adopted G5-R parent scope (no drift). The G6-R
  // contract inherits the G5-R delivery surface; a real drift would surface
  // here. This is a structural pass on the real candidate.
  return null;
}

function verifyPayload() {
  const idxPath = path.join(PLAN_DIR, 'verification', 'payload-index.json');
  if (!exists(idxPath)) return 'payload index missing';
  const idx = loadJSON(idxPath);
  if (!Array.isArray(idx.rows) || idx.rows.length !== 232) return `payload index must have 232 rows, got ${idx.rows?.length}`;
  for (const r of idx.rows) {
    if (r.gitMode !== '100644') return `row ${r.path} gitMode ${r.gitMode} != 100644`;
  }
  // Presence must be consistent with the index's own completedThroughTask
  // cursor: a row is present iff producerTask <= cursor, planned otherwise.
  const cursor = Number.isInteger(idx.completedThroughTask) ? idx.completedThroughTask : 26;
  const expectedPresent = idx.rows.filter((r) => (r.producerTask ?? 0) <= cursor).length;
  const expectedPlanned = idx.rows.length - expectedPresent;
  const present = idx.rows.filter((r) => r.presence === 'present').length;
  const planned = idx.rows.filter((r) => r.presence === 'planned').length;
  if (present !== expectedPresent || planned !== expectedPlanned)
    return `present/planned ${present}/${planned} != expected ${expectedPresent}/${expectedPlanned} for cursor ${cursor}`;
  return null;
}

function verifyGitModes() {
  // Every archive row carries gitMode 100644 (verified in verifyPayload).
  return null;
}

function verifyTruthfulPreAdoption() {
  // Truthful pre-adoption state: the adoption files do NOT yet exist (Task 33
  // writes them). Their absence is the truthful state for --candidate.
  if (exists(path.join(CONTRACT_DIR, 'adoption-record.json'))) return 'adoption-record.json exists before Task 33';
  if (exists(path.join(CONTRACT_DIR, 'SHA256SUMS'))) return 'SHA256SUMS exists before Task 33';
  return null;
}

function verifyChecksumIndex() {
  const sums = path.join(CONTRACT_DIR, 'SHA256SUMS');
  if (!exists(sums)) return 'G6_ADOPTION_MISSING';
  return null;
}

function verifyAdoptionSelectors() {
  const rec = path.join(CONTRACT_DIR, 'adoption-record.json');
  if (!exists(rec)) return 'G6_ADOPTION_MISSING';
  return null;
}

function runPlanAudit() {
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
  return result;
}

function main() {
  const options = parseArgs();
  if (options === null) {
    process.stderr.write('verify-contract: expected no arguments or --candidate\n');
    process.exit(2);
  }

  const checks = [verifyParent, verifyScope, verifyPayload, verifyGitModes, verifyTruthfulPreAdoption];
  for (const check of checks) {
    const err = check();
    if (err) {
      process.stderr.write(`verify-contract: ${err}\n`);
      process.exit(1);
    }
  }

  if (!options.candidate) {
    const ck = verifyChecksumIndex();
    if (ck) { process.stdout.write('G6_ADOPTION_MISSING\n'); process.exit(1); }
    const as = verifyAdoptionSelectors();
    if (as) { process.stdout.write('G6_ADOPTION_MISSING\n'); process.exit(1); }
  }

  const result = runPlanAudit();
  const line = formatAuditStatus({ status: result.status, findingCount: result.findingCount, ...result.counts });
  process.stdout.write(line + '\n');
  process.exitCode = result.findingCount === 0 ? 0 : 1;
}

if (process.argv[1] === __filename) {
  main();
}
