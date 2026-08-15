import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { compareFrozenScope } from '../implementation-plan/tools/compare-g4-g5-scope.mjs';

const artifactDirectory = path.dirname(fileURLToPath(import.meta.url));
const contractDirectory = path.dirname(artifactDirectory);
const planDirectory = path.join(contractDirectory, 'implementation-plan');
const failures = [];

const sha256Bytes = (value) => createHash('sha256').update(value).digest('hex');
const sha256File = (file) => sha256Bytes(fs.readFileSync(file));
const readJSON = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const check = (id, actual, expected) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) failures.push({ id, actual, expected });
};

function reviewValue(contents, name) {
  const expression = new RegExp('`' + name + ': (\\d+)`', 'g');
  const values = [...contents.matchAll(expression)].map((match) => Number(match[1]));
  if (values.length !== 1) {
    failures.push({ id: `review-${name}-cardinality`, actual: values.length, expected: 1 });
    return null;
  }
  return values[0];
}

function privacyPaths(value, pointer = '$') {
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => privacyPaths(item, `${pointer}[${index}]`));
  }
  if (value !== null && typeof value === 'object') {
    return Object.entries(value).flatMap(([key, item]) => {
      const own = /serial|uuid|udid|account|user/i.test(key) ? [`${pointer}.${key}`] : [];
      return own.concat(privacyPaths(item, `${pointer}.${key}`));
    });
  }
  if (
    typeof value === 'string'
    && /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i.test(value)
  ) {
    return [pointer];
  }
  return [];
}

function runJSON(modulePath) {
  const result = spawnSync(process.execPath, [modulePath], {
    cwd: path.dirname(modulePath),
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024
  });
  if (result.error) {
    failures.push({ id: 'child-process-error', actual: result.error.message, expected: null });
    return null;
  }
  let output = null;
  try {
    output = JSON.parse(result.stdout);
  } catch (error) {
    failures.push({ id: 'child-output-json', actual: error.message, expected: 'one JSON object' });
  }
  if (result.status !== 0) {
    failures.push({
      id: 'child-process-status',
      actual: { module: path.basename(modulePath), status: result.status, stderr: result.stderr.trim() },
      expected: { status: 0 }
    });
  }
  return output;
}

const contractPath = path.join(artifactDirectory, 'monacode-g5r-authoritative-manifest.json');
const planPath = path.join(artifactDirectory, 'monacode-g5r-implementation-plan-manifest.json');
const inheritedPath = path.join(artifactDirectory, 'monacode-g5r-inherited-artifacts.json');
const qualificationPath = path.join(artifactDirectory, 'monacode-g5r-qualification-environment-manifest.json');
const planAuditPath = path.join(planDirectory, 'verification/plan-audit.json');
const reviewPath = path.join(planDirectory, 'verification/adversarial-plan-review.md');
const companionPath = path.join(artifactDirectory, 'global-g5r-authoritative-contract.html');

const contract = readJSON(contractPath);
const plan = readJSON(planPath);
const inherited = readJSON(inheritedPath);
const qualification = readJSON(qualificationPath);
const planAudit = readJSON(planAuditPath);
const reviewContents = fs.readFileSync(reviewPath, 'utf8');
const companionContents = fs.readFileSync(companionPath, 'utf8');
const g4 = readJSON(path.join(artifactDirectory, 'monacode-g4r-authoritative-manifest.json'));

check('contract-revision', contract.identity?.revision, 'G5-R-full-scope-candidate');
check('contract-baseline', contract.identity?.behaviorBaseline, 'monaco-editor@0.56.0');
check('product-source-files', contract.empiricalStatus?.productSourceFiles, 0);
check('release-verdict', contract.empiricalStatus?.releaseVerdict, 'not-passed');
check('unresolved-scope-decisions', contract.designClosure?.unresolvedScopeDecisions, []);

for (const finding of compareFrozenScope(g4, contract)) failures.push(finding);

check('inherited-count-field', inherited.inheritedArtifactCount, 72);
check('inherited-row-count', inherited.rows?.length, 72);
check('inherited-parent-revision', inherited.parentRevision, 'G4-R-full-scope-final');
check('inherited-parent-hash', inherited.parentContractSha256, sha256File(
  path.join(artifactDirectory, 'monacode-g4r-authoritative-manifest.json')
));
const inheritedPaths = (inherited.rows ?? []).map((row) => row.path);
check('inherited-unique-paths', new Set(inheritedPaths).size, inheritedPaths.length);
let inheritedVerified = 0;
for (const row of inherited.rows ?? []) {
  const file = path.join(contractDirectory, row.path);
  if (!row.path.startsWith('artifacts/') || !fs.existsSync(file)) {
    failures.push({ id: 'inherited-file-missing', actual: row.path, expected: 'existing artifacts file' });
  } else {
    const actual = sha256File(file);
    if (actual !== row.sha256) failures.push({ id: 'inherited-hash', actual, expected: row.sha256, path: row.path });
    else inheritedVerified += 1;
  }
}

const g4Audit = runJSON(path.join(artifactDirectory, 'monacode-g4r-audit.mjs'));
check('g4-audit-status', g4Audit?.status, 'pass');
check('g4-audit-failures', g4Audit?.failureCount, 0);
check('g4-audit-unresolved', g4Audit?.audited?.unresolvedScopeDecisions, 0);
check('g4-audit-contract-hash', g4Audit?.g4Sha256, inherited.parentContractSha256);

const expectedDocumentPaths = [
  'implementation-plan/README.md',
  'implementation-plan/00-master-plan.md',
  ...Array.from({ length: 10 }, (_, index) => {
    const phase = String(index).padStart(2, '0');
    return plan.phases?.find((row) => row.id === phase)?.document;
  })
];
check('plan-document-count', plan.documents?.length, 12);
check('plan-document-paths', (plan.documents ?? []).map((row) => row.path), expectedDocumentPaths);
let planDocumentsVerified = 0;
for (const row of plan.documents ?? []) {
  const file = path.join(contractDirectory, row.path);
  if (!fs.existsSync(file)) {
    failures.push({ id: 'plan-document-missing', actual: row.path, expected: 'existing plan document' });
  } else {
    const actual = sha256File(file);
    if (actual !== row.sha256) failures.push({ id: 'plan-document-hash', actual, expected: row.sha256, path: row.path });
    else planDocumentsVerified += 1;
  }
}

check('plan-audit-status', planAudit.status, 'pass');
check('plan-audit-findings', planAudit.findingCount, 0);
check('plan-audit-executability', planAudit.counts?.executabilityFailures, 0);
check('coverage-identities', planAudit.coverage?.contractIdentities, 3582);
check('coverage-retained', planAudit.coverage?.retainedIdentities, 3349);
check('coverage-disposition-only', planAudit.coverage?.dispositionOnlyIdentities, 233);
check('coverage-ownership', planAudit.coverage?.ownershipRows, 3582);
check('coverage-features', planAudit.coverage?.retainedFeatureIds, 62);
check('coverage-missing-features', planAudit.coverage?.missingRetainedFeatureIds, 0);
check('coverage-colorize', planAudit.coverage?.nativeColorizeReplacements, 3);

const review = {
  rounds: reviewValue(reviewContents, 'rounds'),
  attacks: reviewValue(reviewContents, 'attacks'),
  detected: reviewValue(reviewContents, 'detected'),
  missed: reviewValue(reviewContents, 'missed'),
  unresolvedFindings: reviewValue(reviewContents, 'unresolvedFindings')
};
check('review-rounds', review.rounds, 3);
check('review-attacks', review.attacks, 53);
check('review-detected', review.detected, 53);
check('review-missed', review.missed, 0);
check('review-unresolved', review.unresolvedFindings, 0);

const qualified = qualification.qualifiedEnvironment;
check('environment-macos', qualified?.macOS?.version, contract.currentLocalEnvironment?.macOS);
check('environment-macos-build', qualified?.macOS?.build, contract.currentLocalEnvironment?.macOSBuild);
check('environment-xcode', qualified?.xcode?.version, contract.currentLocalEnvironment?.xcode);
check('environment-xcode-build', qualified?.xcode?.build, contract.currentLocalEnvironment?.xcodeBuild);
check('environment-sdk', qualified?.macOSSDK, contract.currentLocalEnvironment?.sdk);
check('environment-swift', qualified?.swift?.version, contract.currentLocalEnvironment?.swift);
check('environment-architecture', qualified?.architecture, contract.currentLocalEnvironment?.architecture);
check('environment-chrome', qualified?.chrome?.version, contract.currentLocalEnvironment?.chrome);
check('environment-external-count', qualification.qualificationPredicate?.externalDisplayCountRequired, 0);
check('environment-display-scope', qualification.qualificationPredicate?.releaseDisplayScope, 'built-in-display-only');
check('environment-privacy', privacyPaths(qualification), []);

const governance = contract.designClosure?.planGovernance;
const machinePlan = contract.machineArtifacts?.find((artifact) => artifact.id === 'implementationPlan');
const planVerifier = contract.verificationTools?.find((tool) => tool.id === 'planVerifier');
const adopted = governance?.status === 'adopted';
check('governance-status', governance?.status, adopted ? 'adopted' : 'candidate');
check('governance-evidence-state', governance?.evidenceState, adopted ? 'structurally-verified' : 'planned');
check('plan-adoption-state', plan.adoptionState, adopted ? 'adopted' : 'candidate');
check('plan-state', plan.planState, adopted ? 'structurally-verified' : 'mapped');
check('machine-plan-adoption-state', machinePlan?.adoptionState, adopted ? 'adopted' : 'candidate');
check(
  'companion-title',
  companionContents.includes(`<title>MonaCode G5-R authoritative contract${adopted ? '' : ' candidate'}</title>`),
  true
);
check(
  'companion-status',
  companionContents.includes(adopted ? '<strong>Status:</strong> adopted.' : '<strong>Status:</strong> candidate, not adopted.'),
  true
);
check('governance-contract-manifest-self-hash', governance?.selectedHashes?.contractManifestSha256, null);
check(
  'governance-contract-companion-hash',
  governance?.selectedHashes?.contractCompanionSha256,
  adopted ? sha256File(companionPath) : null
);

const selectedFiles = {
  planSchemaSha256: path.join(artifactDirectory, machinePlan.schemaFile),
  planManifestSha256: planPath,
  planAuditSha256: planAuditPath,
  adversarialReviewSha256: reviewPath
};
for (const [field, file] of Object.entries(selectedFiles)) {
  const expected = adopted ? sha256File(file) : null;
  check(`governance-${field}`, governance?.selectedHashes?.[field], expected);
}
check('machine-plan-schema-hash', machinePlan?.schemaSha256, adopted ? sha256File(selectedFiles.planSchemaSha256) : null);
check('machine-plan-manifest-hash', machinePlan?.planSha256, adopted ? sha256File(planPath) : null);
check('machine-plan-audit-hash', machinePlan?.planAuditSha256, adopted ? sha256File(planAuditPath) : null);
check('machine-plan-review-hash', machinePlan?.adversarialReviewSha256, adopted ? sha256File(reviewPath) : null);
check('plan-verifier-hash', planVerifier?.sha256, adopted ? sha256File(path.join(planDirectory, 'verify-plan.mjs')) : null);

const unresolvedScopeDecisions = contract.designClosure?.unresolvedScopeDecisions?.length ?? 0;
const unresolvedPlanFindings = (planAudit.findingCount ?? 0) + (review.unresolvedFindings ?? 0);
const output = {
  status: failures.length === 0 ? 'pass' : 'fail',
  failureCount: failures.length,
  failures,
  unresolvedScopeDecisions,
  unresolvedPlanFindings,
  contractSha256: sha256File(contractPath),
  planSha256: sha256File(planPath),
  adoptionState: adopted ? 'adopted' : 'candidate',
  inherited: {
    expected: 72,
    verified: inheritedVerified
  },
  planDocuments: {
    expected: 12,
    verified: planDocumentsVerified
  },
  coverage: planAudit.coverage,
  environmentIdentity: {
    macOS: qualified?.macOS?.version,
    macOSBuild: qualified?.macOS?.build,
    architecture: qualified?.architecture,
    chrome: qualified?.chrome?.version,
    externalDisplayCountRequired: qualification.qualificationPredicate?.externalDisplayCountRequired,
    releaseDisplayScope: qualification.qualificationPredicate?.releaseDisplayScope,
    manifestSha256: sha256File(qualificationPath)
  },
  adversarialReview: review
};

process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
for (const failure of failures) process.stderr.write(`G5_AUDIT_FAILURE\t${failure.id}\n`);
process.exitCode = failures.length === 0 ? 0 : 1;
