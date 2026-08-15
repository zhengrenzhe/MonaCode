import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const sourceContractDirectory = path.resolve(testDirectory, '../..');

const readJSON = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const writeJSON = (file, value) => fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
const sha256 = (file) => createHash('sha256').update(fs.readFileSync(file)).digest('hex');

function copyArchive(t) {
  const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'monacode-g5r-archive-'));
  const contractDirectory = path.join(temporaryRoot, 'g5-r');
  fs.cpSync(sourceContractDirectory, contractDirectory, { recursive: true });
  t.after(() => fs.rmSync(temporaryRoot, { recursive: true, force: true }));
  return contractDirectory;
}

function runVerifier(contractDirectory, args = []) {
  return spawnSync(process.execPath, [path.join(contractDirectory, 'verify-contract.mjs'), ...args], {
    cwd: contractDirectory,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024
  });
}

function indexedPaths(contractDirectory) {
  const rows = [];
  function walk(relativeDirectory) {
    const directory = path.join(contractDirectory, relativeDirectory);
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const relativePath = path.posix.join(relativeDirectory, entry.name);
      if (entry.isDirectory()) walk(relativePath);
      else if (entry.isFile()) rows.push(relativePath);
      else throw new Error(`unexpected archive entry: ${relativePath}`);
    }
  }
  walk('artifacts');
  walk('implementation-plan');
  return rows.sort((left, right) => left.localeCompare(right, 'en'));
}

function generateChecksumIndex(contractDirectory) {
  const rows = indexedPaths(contractDirectory).map((relativePath) => (
    `${sha256(path.join(contractDirectory, relativePath))}  ${relativePath}`
  ));
  fs.writeFileSync(path.join(contractDirectory, 'SHA256SUMS'), `${rows.join('\n')}\n`);
  return rows.length;
}

function promoteTemporaryArchive(contractDirectory) {
  const artifactDirectory = path.join(contractDirectory, 'artifacts');
  const planDirectory = path.join(contractDirectory, 'implementation-plan');
  const planPath = path.join(artifactDirectory, 'monacode-g5r-implementation-plan-manifest.json');
  const plan = readJSON(planPath);
  plan.adoptionState = 'adopted';
  plan.planState = 'structurally-verified';
  plan.audit = { status: 'pass', findingCount: 0, findings: [] };
  writeJSON(planPath, plan);

  const planProcess = spawnSync(process.execPath, [path.join(planDirectory, 'verify-plan.mjs')], {
    cwd: contractDirectory,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024
  });
  assert.equal(planProcess.status, 0, planProcess.stderr);
  const planAuditPath = path.join(planDirectory, 'verification/plan-audit.json');
  fs.writeFileSync(planAuditPath, planProcess.stdout);

  const contractPath = path.join(artifactDirectory, 'monacode-g5r-authoritative-manifest.json');
  const companionPath = path.join(artifactDirectory, 'global-g5r-authoritative-contract.html');
  fs.writeFileSync(
    companionPath,
    fs.readFileSync(companionPath, 'utf8')
      .replaceAll('MonaCode G5-R authoritative contract candidate', 'MonaCode G5-R authoritative contract')
      .replace('<strong>Status:</strong> candidate, not adopted.', '<strong>Status:</strong> adopted.')
  );
  const contract = readJSON(contractPath);
  contract.identity.status = 'design-and-plan-adopted';
  const governance = contract.designClosure.planGovernance;
  governance.status = 'adopted';
  governance.evidenceState = 'structurally-verified';
  const machinePlan = contract.machineArtifacts.find((artifact) => artifact.id === 'implementationPlan');
  const selected = {
    planSchemaSha256: sha256(path.join(artifactDirectory, machinePlan.schemaFile)),
    planManifestSha256: sha256(planPath),
    planAuditSha256: sha256(planAuditPath),
    adversarialReviewSha256: sha256(path.join(planDirectory, 'verification/adversarial-plan-review.md'))
  };
  Object.assign(governance.selectedHashes, selected);
  governance.selectedHashes.contractCompanionSha256 = sha256(companionPath);
  machinePlan.schemaSha256 = selected.planSchemaSha256;
  machinePlan.planSha256 = selected.planManifestSha256;
  machinePlan.planAuditSha256 = selected.planAuditSha256;
  machinePlan.adversarialReviewSha256 = selected.adversarialReviewSha256;
  machinePlan.adoptionState = 'adopted';
  contract.verificationTools.find((tool) => tool.id === 'planVerifier').sha256 = sha256(
    path.join(planDirectory, 'verify-plan.mjs')
  );
  writeJSON(contractPath, contract);

  const globalAuditPath = path.join(artifactDirectory, 'monacode-g5r-audit.mjs');
  const globalProcess = spawnSync(process.execPath, [globalAuditPath], {
    cwd: artifactDirectory,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024
  });
  assert.equal(globalProcess.status, 0, globalProcess.stderr);
  const globalAudit = JSON.parse(globalProcess.stdout);
  const planAudit = readJSON(planAuditPath);
  const reviewPath = path.join(planDirectory, 'verification/adversarial-plan-review.md');
  const indexedFileCount = generateChecksumIndex(contractDirectory);

  const adoption = {
    schemaVersion: 1,
    product: 'MonaCode',
    decision: 'adopted',
    adoptedOn: '2026-08-15',
    behaviorBaseline: 'monaco-editor@0.56.0',
    promotedRevision: 'G5-R-full-scope-final',
    contract: {
      path: 'artifacts/monacode-g5r-authoritative-manifest.json',
      artifactRevision: 'G5-R-full-scope-candidate',
      sha256: sha256(contractPath),
      bytesAreImmutable: true
    },
    plan: {
      path: 'artifacts/monacode-g5r-implementation-plan-manifest.json',
      planRevision: plan.planRevision,
      sha256: sha256(planPath),
      acceptedState: 'structurally-verified'
    },
    humanReadableCompanion: {
      path: 'artifacts/global-g5r-authoritative-contract.html',
      sha256: sha256(path.join(artifactDirectory, 'global-g5r-authoritative-contract.html')),
      normative: false
    },
    globalAudit: {
      path: 'artifacts/monacode-g5r-audit.mjs',
      sha256: sha256(globalAuditPath),
      acceptedStatus: 'pass',
      acceptedFailureCount: 0,
      acceptedUnresolvedScopeDecisions: 0,
      acceptedUnresolvedPlanFindings: 0
    },
    planAudit: {
      path: 'implementation-plan/verification/plan-audit.json',
      sha256: sha256(planAuditPath),
      acceptedStatus: 'pass',
      acceptedFindingCount: 0
    },
    adversarialReview: {
      path: 'implementation-plan/verification/adversarial-plan-review.md',
      sha256: sha256(reviewPath),
      acceptedRounds: 3,
      acceptedAttacks: 53,
      acceptedMissed: 0,
      acceptedUnresolvedFindings: 0
    },
    archive: {
      checksumIndex: 'SHA256SUMS',
      indexedFileCount
    },
    status: {
      designScope: 'frozen',
      implementationPlan: 'structurally-verified',
      implementation: 'not-started',
      releaseAcceptance: 'not-passed'
    }
  };
  assert.equal(globalAudit.contractSha256, adoption.contract.sha256);
  assert.equal(globalAudit.planSha256, adoption.plan.sha256);
  assert.equal(planAudit.findingCount, 0);
  writeJSON(path.join(contractDirectory, 'adoption-record.json'), adoption);
  return adoption;
}

test('candidate verifier accepts the complete structurally verified archive', (t) => {
  const contractDirectory = copyArchive(t);
  const result = runVerifier(contractDirectory, ['--candidate']);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), {
    status: 'candidate-pass',
    adopted: false,
    artifactHashesVerified: 72,
    planFindingCount: 0,
    unresolvedPlanFindings: 0
  });
});

for (const attack of [
  {
    name: 'inherited artifact mutation',
    mutate(contractDirectory) {
      const inherited = readJSON(path.join(contractDirectory, 'artifacts/monacode-g5r-inherited-artifacts.json'));
      fs.appendFileSync(path.join(contractDirectory, inherited.rows[0].path), '\n');
    }
  },
  {
    name: 'plan document mutation',
    mutate(contractDirectory) {
      fs.appendFileSync(path.join(contractDirectory, 'implementation-plan/phase-00-scaffold-harness.md'), '\nmutation\n');
    }
  },
  {
    name: 'review unresolved count mutation',
    mutate(contractDirectory) {
      const review = path.join(contractDirectory, 'implementation-plan/verification/adversarial-plan-review.md');
      fs.writeFileSync(review, fs.readFileSync(review, 'utf8').replace('`unresolvedFindings: 0`', '`unresolvedFindings: 1`'));
    }
  }
]) {
  test(`candidate verifier rejects ${attack.name}`, (t) => {
    const contractDirectory = copyArchive(t);
    attack.mutate(contractDirectory);
    assert.notEqual(runVerifier(contractDirectory, ['--candidate']).status, 0);
  });
}

test('default verifier accepts a fully selected temporary adoption', (t) => {
  const contractDirectory = copyArchive(t);
  promoteTemporaryArchive(contractDirectory);
  const result = runVerifier(contractDirectory);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).status, 'pass');
});

for (const attack of [
  {
    name: 'contract hash mutation',
    mutate(adoption) { adoption.contract.sha256 = '0'.repeat(64); }
  },
  {
    name: 'plan hash mutation',
    mutate(adoption) { adoption.plan.sha256 = '0'.repeat(64); }
  },
  {
    name: 'adoption status mutation',
    mutate(adoption) { adoption.decision = 'candidate'; }
  },
  {
    name: 'accepted audit count mutation',
    mutate(adoption) { adoption.globalAudit.acceptedFailureCount = 1; }
  }
]) {
  test(`default verifier rejects ${attack.name}`, (t) => {
    const contractDirectory = copyArchive(t);
    const adoption = promoteTemporaryArchive(contractDirectory);
    attack.mutate(adoption);
    writeJSON(path.join(contractDirectory, 'adoption-record.json'), adoption);
    assert.notEqual(runVerifier(contractDirectory).status, 0);
  });
}
