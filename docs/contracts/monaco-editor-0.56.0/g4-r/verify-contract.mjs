import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const contractDirectory = path.dirname(fileURLToPath(import.meta.url));
const artifactDirectory = path.join(contractDirectory, 'artifacts');

function fail(message) {
  process.stderr.write(`MonaCode G4-R verification failed: ${message}\n`);
  process.exit(1);
}

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(contractDirectory, relativePath), 'utf8'));
}

function sha256(relativePath) {
  return createHash('sha256')
    .update(fs.readFileSync(path.join(contractDirectory, relativePath)))
    .digest('hex');
}

const checksumRows = fs.readFileSync(path.join(contractDirectory, 'SHA256SUMS'), 'utf8')
  .trim()
  .split('\n')
  .map((line, index) => {
    const match = /^([0-9a-f]{64})  (artifacts\/.+)$/.exec(line);
    if (!match) fail(`invalid SHA256SUMS row ${index + 1}`);
    return { sha256: match[1], path: match[2] };
  });

const checksumPaths = checksumRows.map((row) => row.path);
if (new Set(checksumPaths).size !== checksumPaths.length) fail('duplicate SHA256SUMS path');

const artifactPaths = fs.readdirSync(artifactDirectory, { withFileTypes: true })
  .filter((entry) => entry.isFile())
  .map((entry) => `artifacts/${entry.name}`)
  .sort();

if (JSON.stringify([...checksumPaths].sort()) !== JSON.stringify(artifactPaths)) {
  fail('SHA256SUMS and artifact directory contain different path sets');
}

for (const row of checksumRows) {
  const actual = sha256(row.path);
  if (actual !== row.sha256) fail(`${row.path} hash ${actual} does not match ${row.sha256}`);
}

const adoption = readJson('adoption-record.json');
if (adoption.decision !== 'adopted') fail('adoption decision is not adopted');
if (adoption.archive.artifactCount !== artifactPaths.length) fail('adopted artifact count does not match archive');

const extensionCounts = artifactPaths.reduce((counts, artifactPath) => {
  const extension = path.extname(artifactPath);
  counts[extension] = (counts[extension] ?? 0) + 1;
  return counts;
}, {});

if (extensionCounts['.html'] !== adoption.archive.htmlCount) fail('HTML artifact count mismatch');
if (extensionCounts['.json'] !== adoption.archive.jsonCount) fail('JSON artifact count mismatch');
if (extensionCounts['.mjs'] !== adoption.archive.moduleCount) fail('module artifact count mismatch');

for (const selectedArtifact of [adoption.contract, adoption.humanReadableCompanion, adoption.audit]) {
  const actual = sha256(selectedArtifact.path);
  if (actual !== selectedArtifact.sha256) fail(`${selectedArtifact.path} does not match the adopted hash`);
}

const auditPath = path.join(contractDirectory, adoption.audit.path);
const auditProcess = spawnSync(process.execPath, [auditPath], {
  cwd: artifactDirectory,
  encoding: 'utf8',
  env: process.env
});

if (auditProcess.error) fail(`audit process error: ${auditProcess.error.message}`);
if (auditProcess.status !== 0) fail(`audit process exited with ${auditProcess.status}`);

let audit;
try {
  audit = JSON.parse(auditProcess.stdout);
} catch (error) {
  fail(`audit output is not JSON: ${error.message}`);
}

if (audit.status !== adoption.audit.acceptedStatus) fail(`audit status is ${audit.status}`);
if (audit.failureCount !== adoption.audit.acceptedFailureCount) fail(`audit failureCount is ${audit.failureCount}`);
if (audit.audited?.unresolvedScopeDecisions !== adoption.audit.acceptedUnresolvedScopeDecisions) {
  fail(`audit unresolvedScopeDecisions is ${audit.audited?.unresolvedScopeDecisions}`);
}
if (audit.g4Sha256 !== adoption.contract.sha256) fail('audit selected a different G4-R hash');

process.stdout.write(`${JSON.stringify({
  status: 'pass',
  adoptedRevision: adoption.promotedRevision,
  artifactCount: artifactPaths.length,
  artifactHashesVerified: checksumRows.length,
  audit: audit.audited,
  g4Sha256: audit.g4Sha256
}, null, 2)}\n`);
