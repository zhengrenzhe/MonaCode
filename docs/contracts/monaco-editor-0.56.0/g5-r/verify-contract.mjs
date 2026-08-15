#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const contractDirectory = path.dirname(fileURLToPath(import.meta.url));
const argumentsList = process.argv.slice(2);
if (argumentsList.length > 1 || (argumentsList.length === 1 && argumentsList[0] !== '--candidate')) {
  process.stderr.write('MonaCode G5-R verification failed: expected no arguments or --candidate\n');
  process.exit(2);
}
const candidateMode = argumentsList[0] === '--candidate';
const runtimeStateNames = new Set([
  '.last-port',
  '.last-token',
  'server-info',
  'server-instance-id',
  'server.pid'
]);

function fail(message) {
  process.stderr.write(`MonaCode G5-R verification failed: ${message}\n`);
  process.exit(1);
}

const sha256File = (file) => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const readJSON = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));

function archivePaths(root) {
  const files = [];
  function walk(relativeDirectory) {
    const directory = path.join(root, relativeDirectory);
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const relativePath = path.posix.join(relativeDirectory, entry.name);
      if (runtimeStateNames.has(entry.name)) continue;
      if (entry.isDirectory()) walk(relativePath);
      else if (entry.isFile()) files.push(relativePath);
      else fail(`unsupported archive entry ${relativePath}`);
    }
  }
  walk('artifacts');
  walk('implementation-plan');
  return files.sort((left, right) => left.localeCompare(right, 'en'));
}

function verifyChecksumIndex(root) {
  const checksumPath = path.join(root, 'SHA256SUMS');
  if (!fs.existsSync(checksumPath)) {
    return { present: false, verified: 0, paths: [], hashes: new Map(), failures: [] };
  }
  const contents = fs.readFileSync(checksumPath, 'utf8');
  const lines = contents.endsWith('\n') ? contents.slice(0, -1).split('\n') : contents.split('\n');
  const failures = [];
  const rows = [];
  for (const [index, line] of lines.entries()) {
    const match = /^([0-9a-f]{64})  ((?:artifacts|implementation-plan)\/.+)$/.exec(line);
    if (!match || match[2].includes('\\') || match[2].split('/').includes('..')) {
      failures.push(`invalid SHA256SUMS row ${index + 1}`);
    } else {
      rows.push({ sha256: match[1], path: match[2] });
    }
  }
  const paths = rows.map((row) => row.path);
  if (new Set(paths).size !== paths.length) failures.push('duplicate SHA256SUMS path');
  const expectedPaths = archivePaths(root);
  if (JSON.stringify(paths) !== JSON.stringify(expectedPaths)) {
    failures.push('SHA256SUMS and archive contain different ordered path sets');
  }
  let verified = 0;
  for (const row of rows) {
    const file = path.join(root, row.path);
    if (!fs.existsSync(file)) {
      failures.push(`${row.path} is missing`);
      continue;
    }
    const actual = sha256File(file);
    if (actual !== row.sha256) failures.push(`${row.path} hash ${actual} does not match ${row.sha256}`);
    else verified += 1;
  }
  return {
    present: true,
    verified,
    paths,
    hashes: new Map(rows.map((row) => [row.path, row.sha256])),
    failures
  };
}

function runJsonModule(modulePath) {
  const result = spawnSync(process.execPath, [modulePath], {
    cwd: path.dirname(modulePath),
    encoding: 'utf8',
    env: process.env,
    maxBuffer: 64 * 1024 * 1024
  });
  if (result.error) fail(`${path.basename(modulePath)} process error: ${result.error.message}`);
  let output;
  try {
    output = JSON.parse(result.stdout);
  } catch (error) {
    fail(`${path.basename(modulePath)} output is not JSON: ${error.message}`);
  }
  if (result.status !== 0) {
    fail(`${path.basename(modulePath)} exited with ${result.status}: ${result.stderr.trim()}`);
  }
  return output;
}

function verifyAdoptionRecord(record, checksumResult, globalAudit, planAudit) {
  const check = (condition, message) => {
    if (!condition) fail(message);
  };
  const selected = (label, entry, expectedPath) => {
    check(entry?.path === expectedPath, `${label} path is not ${expectedPath}`);
    check(/^[0-9a-f]{64}$/.test(entry?.sha256 ?? ''), `${label} hash is invalid`);
    check(checksumResult.hashes.get(entry.path) === entry.sha256, `${label} hash is not selected by SHA256SUMS`);
  };

  check(record.schemaVersion === 1, 'adoption schemaVersion is not 1');
  check(record.product === 'MonaCode', 'adoption product is not MonaCode');
  check(record.decision === 'adopted', 'adoption decision is not adopted');
  check(record.adoptedOn === '2026-08-15', 'adoption date is not 2026-08-15');
  check(record.behaviorBaseline === 'monaco-editor@0.56.0', 'adoption baseline is not monaco-editor@0.56.0');
  check(record.promotedRevision === 'G5-R-full-scope-final', 'promoted revision is not G5-R-full-scope-final');

  selected('contract', record.contract, 'artifacts/monacode-g5r-authoritative-manifest.json');
  selected('plan', record.plan, 'artifacts/monacode-g5r-implementation-plan-manifest.json');
  selected('human companion', record.humanReadableCompanion, 'artifacts/global-g5r-authoritative-contract.html');
  selected('global audit', record.globalAudit, 'artifacts/monacode-g5r-audit.mjs');
  selected('plan audit', record.planAudit, 'implementation-plan/verification/plan-audit.json');
  selected('adversarial review', record.adversarialReview, 'implementation-plan/verification/adversarial-plan-review.md');

  check(record.contract.sha256 === globalAudit.contractSha256, 'global audit selected a different contract hash');
  check(record.plan.sha256 === globalAudit.planSha256, 'global audit selected a different plan hash');
  check(record.contract.bytesAreImmutable === true, 'contract bytes are not marked immutable');
  check(record.plan.acceptedState === 'structurally-verified', 'accepted plan state is not structurally-verified');
  check(record.globalAudit.acceptedStatus === 'pass', 'accepted global audit status is not pass');
  check(record.globalAudit.acceptedFailureCount === 0, 'accepted global audit failure count is not zero');
  check(record.globalAudit.acceptedFailureCount === globalAudit.failureCount, 'global audit failure count differs from adoption');
  check(record.globalAudit.acceptedUnresolvedScopeDecisions === 0, 'accepted unresolved scope count is not zero');
  check(
    record.globalAudit.acceptedUnresolvedScopeDecisions === globalAudit.unresolvedScopeDecisions,
    'global audit unresolved scope count differs from adoption'
  );
  check(record.globalAudit.acceptedUnresolvedPlanFindings === 0, 'accepted unresolved plan count is not zero');
  check(
    record.globalAudit.acceptedUnresolvedPlanFindings === globalAudit.unresolvedPlanFindings,
    'global audit unresolved plan count differs from adoption'
  );
  check(record.planAudit.acceptedStatus === 'pass', 'accepted plan audit status is not pass');
  check(record.planAudit.acceptedFindingCount === 0, 'accepted plan finding count is not zero');
  check(record.planAudit.acceptedFindingCount === planAudit.findingCount, 'plan finding count differs from adoption');
  check(record.adversarialReview.acceptedRounds === 3, 'accepted adversarial rounds is not three');
  check(record.adversarialReview.acceptedAttacks === 53, 'accepted adversarial attacks is not 53');
  check(record.adversarialReview.acceptedMissed === 0, 'accepted missed attacks is not zero');
  check(record.adversarialReview.acceptedUnresolvedFindings === 0, 'accepted unresolved findings is not zero');
  check(record.adversarialReview.acceptedRounds === globalAudit.adversarialReview?.rounds, 'review round count differs');
  check(record.adversarialReview.acceptedAttacks === globalAudit.adversarialReview?.attacks, 'review attack count differs');
  check(record.adversarialReview.acceptedMissed === globalAudit.adversarialReview?.missed, 'review missed count differs');
  check(
    record.adversarialReview.acceptedUnresolvedFindings === globalAudit.adversarialReview?.unresolvedFindings,
    'review unresolved count differs'
  );
  check(record.archive.checksumIndex === 'SHA256SUMS', 'archive checksum index is not SHA256SUMS');
  check(record.archive.indexedFileCount === checksumResult.paths.length, 'archive indexed file count differs');
  check(record.status.designScope === 'frozen', 'adopted design scope is not frozen');
  check(record.status.implementationPlan === 'structurally-verified', 'implementation plan is not structurally-verified');
  check(record.status.implementation === 'not-started', 'implementation status is not not-started');
  check(record.status.releaseAcceptance === 'not-passed', 'release acceptance is not not-passed');
  check(globalAudit.adoptionState === 'adopted', 'global audit does not report adopted state');
}

if (!candidateMode && !fs.existsSync(path.join(contractDirectory, 'adoption-record.json'))) {
  fail('adoption record missing');
}

const checksumResult = verifyChecksumIndex(contractDirectory);
if (checksumResult.failures.length !== 0) fail(checksumResult.failures.join('; '));
if (!candidateMode && !checksumResult.present) fail('SHA256SUMS missing');

const globalAudit = runJsonModule(path.join(contractDirectory, 'artifacts/monacode-g5r-audit.mjs'));
const planAudit = runJsonModule(path.join(contractDirectory, 'implementation-plan/verify-plan.mjs'));

if (globalAudit.status !== 'pass' || globalAudit.failureCount !== 0) fail('global audit did not pass with zero failures');
if (globalAudit.unresolvedScopeDecisions !== 0) fail('global audit has unresolved scope decisions');
if (globalAudit.unresolvedPlanFindings !== 0) fail('global audit has unresolved plan findings');
if (planAudit.status !== 'pass' || planAudit.findingCount !== 0) fail('plan audit did not pass with zero findings');

let adoption = null;
if (!candidateMode) {
  adoption = readJSON(path.join(contractDirectory, 'adoption-record.json'));
  verifyAdoptionRecord(adoption, checksumResult, globalAudit, planAudit);
}

process.stdout.write(`${JSON.stringify({
  status: candidateMode ? 'candidate-pass' : 'pass',
  adopted: !candidateMode,
  ...(candidateMode ? {} : { adoptedRevision: adoption.promotedRevision }),
  artifactHashesVerified: checksumResult.present ? checksumResult.verified : globalAudit.inherited.verified,
  planFindingCount: planAudit.findingCount,
  unresolvedPlanFindings: globalAudit.unresolvedPlanFindings
}, null, 2)}\n`);
