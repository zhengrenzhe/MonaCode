// Task 25: scope-delta mutation tests.
// Proves G6-R product scope equals G5-R outside the fixed plan-governance allowlist.
// Start from a zero-delta candidate, then mutate one product feature / public count /
// architecture rule / language exclusion / Metal trigger / correctness gate /
// performance threshold / platform scope / qualification predicate. Assert
// G6_FORBIDDEN_SCOPE_DELTA with the exact JSON pointer for each mutation.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { readFileSync, existsSync } from 'node:fs';
import {
  compareFrozenScope,
  buildG6Candidate,
  buildHtmlCompanion,
  PERMITTED_PREFIXES,
} from '../compare-g5-g6-scope.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../../..');
const G5_MANIFEST_PATH = resolve(
  REPO_ROOT,
  'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-g5r-authoritative-manifest.json',
);
const G6_MANIFEST_PATH = resolve(
  REPO_ROOT,
  'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json',
);
const G6_HTML_PATH = resolve(
  REPO_ROOT,
  'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/global-g6r-authoritative-contract.html',
);

const g5 = JSON.parse(readFileSync(G5_MANIFEST_PATH, 'utf8'));
const g6Zero = buildG6Candidate(g5, { repoRoot: REPO_ROOT });

function clone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

test('permitted prefixes are the ten bytewise-sorted exact prefixes', () => {
  const expected = [
    '/authorityRules/companion',
    '/authorityRules/global',
    '/authorityRules/hashMismatch',
    '/identity/revision',
    '/identity/status',
    '/machineArtifacts/implementationPlan',
    '/parent',
    '/planGovernance',
    '/schemaVersion',
    '/verificationTools/planVerifier',
  ];
  assert.deepEqual([...PERMITTED_PREFIXES], expected);
  const sorted = [...expected].sort();
  assert.deepEqual([...PERMITTED_PREFIXES], sorted, 'must be bytewise-sorted');
});

test('zero-delta candidate produces no forbidden scope deltas', () => {
  const findings = compareFrozenScope(g5, g6Zero);
  assert.equal(findings.length, 0,
    `expected 0 forbidden deltas, got ${findings.length}: ${JSON.stringify(findings, null, 2)}`);
});

test('zero-delta candidate preserves identity values not under a permitted prefix', () => {
  // identity.date, identity.product, identity.component, identity.currentRelease,
  // identity.behaviorBaseline are NOT permitted deltas and must equal G5 exactly.
  assert.equal(g6Zero.identity.product, g5.identity.product);
  assert.equal(g6Zero.identity.date, g5.identity.date);
  assert.equal(g6Zero.identity.component, g5.identity.component);
  assert.equal(g6Zero.identity.currentRelease, g5.identity.currentRelease);
  assert.equal(g6Zero.identity.behaviorBaseline, g5.identity.behaviorBaseline);
});

test('zero-delta candidate sets the permitted identity + schema deltas', () => {
  assert.equal(g6Zero.schemaVersion, 3);
  assert.equal(g6Zero.identity.revision, 'G6-R-execution-ready-candidate');
  assert.equal(g6Zero.identity.status, 'design-and-execution-plan-candidate');
});

test('zero-delta candidate adds the parent object with exact snapshot values', () => {
  const p = g6Zero.parent;
  assert.equal(p.root, 'artifacts/parent/g5-r');
  assert.equal(p.revision, 'G5-R-full-scope-final');
  assert.equal(p.files, 148);
  assert.equal(p.bytes, 4050132);
  assert.equal(p.checksumRows, 144);
  assert.equal(p.checksumIndexSha256,
    'b8546da4a43056ca4b0f944ac33c872d0d12fa14fe29e5e296b0eedb10423e8f');
  assert.equal(p.adoptionRecordSha256,
    '9f2e0e8be14940050bc2d649f2c27cc3237379f31617e019d5f7389943b6513c');
  assert.equal(p.authoritativeManifestSha256,
    'b8f9b31f739d2b5587b3bef1699786cef465af3f7173a1c413d276772c81f94f');
  assert.equal(p.implementationPlanSha256,
    '114979c5faf1369d1f74a8a3905981c1cbef85b9dd93b6a12f8fc48460e64b5c');
});

test('zero-delta candidate adds planGovernance with exact G6 counts', () => {
  const pg = g6Zero.planGovernance;
  assert.equal(pg.planState, 'execution-ready-candidate');
  assert.equal(pg.adoptionState, 'candidate');
  assert.equal(pg.implementation, 'not-started');
  assert.equal(pg.releaseAcceptance, 'not-passed');
  assert.equal(pg.taskTestContracts, 200);
  assert.equal(pg.verificationCommands, 400);
  assert.equal(pg.leaves, 407);
  assert.equal(pg.beginActions, 200);
  assert.equal(pg.commitActions, 200);
  assert.equal(pg.finalizeActions, 200);
  assert.equal(pg.productCommitContracts, 200);
  assert.equal(pg.evidenceCommitContracts, 200);
  assert.equal(pg.productCommitSubjectTemplate, 'monacode: complete <TASK_ID>');
  assert.equal(pg.evidenceCommitSubjectTemplate, 'evidence(monacode): complete <TASK_ID>');
  assert.equal(pg.evidenceCommitSelectorMode, 'external-git');
  assert.equal(pg.workspaceLifecycle, 'token-bound');
  assert.equal(pg.sourceAcquisitions.count, 3);
  assert.equal(pg.sourceAcquisitions.sourceGaps, 0);
  assert.equal(pg.sourceAcquisitions.acquisitionGaps, 0);
  assert.equal(pg.authoringTaskProducers.audit, 'Task 26');
  assert.equal(pg.authoringTaskProducers.adversarialReview, 'Tasks 29-32');
  assert.equal(pg.authoringTaskProducers.coldCheckoutEvidence, 'Task 28');
});

test('zero-delta candidate replaces implementationPlan row with G6 paths and hashes', () => {
  const row = g6Zero.machineArtifacts.find((m) => m.id === 'implementationPlan');
  assert.equal(row.schemaFile, 'monacode-g6r-execution-schema.json');
  assert.equal(row.planFile, 'monacode-g6r-implementation-plan-manifest.json');
  assert.equal(row.commandDependencyFile, 'monacode-g6r-command-dependency-manifest.json');
  assert.equal(row.interfaceContractFile, 'monacode-g6r-interface-contract-manifest.json');
  assert.equal(row.adoptionState, 'candidate');
  assert.equal(row.planAuditAvailability, 'declared-by-plan');
  assert.equal(row.planAuditProducer, 'Task 27');
  assert.equal(row.adversarialReviewAvailability, 'declared-by-plan');
  assert.equal(row.adversarialReviewProducer, 'Tasks 29-32');
  // sha256 values are real (computed from disk by buildG6Candidate)
  assert.equal(row.schemaSha256.length, 64);
  assert.equal(row.planSha256.length, 64);
  assert.equal(row.commandDependencySha256.length, 64);
  assert.equal(row.interfaceContractSha256.length, 64);
});

test('zero-delta candidate replaces planVerifier with Task 26 destination', () => {
  const row = g6Zero.verificationTools.find((v) => v.id === 'planVerifier');
  assert.equal(row.file, '../implementation-plan/runtime/planctl.mjs');
  assert.equal(row.availability, 'declared-by-plan');
  assert.equal(row.producer, 'Task 26');
  // G4-R-audit row stays exactly inherited
  const audit = g6Zero.verificationTools.find((v) => v.id === 'G4-R-audit');
  const g5Audit = g5.verificationTools.find((v) => v.id === 'G4-R-audit');
  assert.deepEqual(audit, g5Audit);
});

test('zero-delta candidate updates the three authority-rule strings to name G6', () => {
  assert.match(g6Zero.authorityRules.global, /G6-R/);
  assert.match(g6Zero.authorityRules.global, /G1-R through G5-R/);
  assert.match(g6Zero.authorityRules.companion, /global-g6r-authoritative-contract\.html/);
  assert.match(g6Zero.authorityRules.hashMismatch, /invalidates G6/);
  // non-permitted authorityRules stay exactly inherited
  assert.equal(g6Zero.authorityRules.withinDomain, g5.authorityRules.withinDomain);
  assert.equal(g6Zero.authorityRules.sourceCounterexample, g5.authorityRules.sourceCounterexample);
  assert.equal(g6Zero.authorityRules.scopeChange, g5.authorityRules.scopeChange);
  assert.deepEqual(g6Zero.authorityRules.crossDomainOverrides, g5.authorityRules.crossDomainOverrides);
});

// 9 mutation tests — each mutates exactly one product-scope leaf and asserts
// G6_FORBIDDEN_SCOPE_DELTA with the exact JSON pointer.
const mutations = [
  {
    name: 'product feature',
    pointer: '/surfaceCounts/features/baseline',
    mutate: (g6) => { g6.surfaceCounts.features.baseline = 65; },
  },
  {
    name: 'public count',
    pointer: '/surfaceCounts/publicDeclarations/total',
    mutate: (g6) => { g6.surfaceCounts.publicDeclarations.total = 556; },
  },
  {
    name: 'architecture rule',
    pointer: '/architecture/modelTruth',
    mutate: (g6) => { g6.architecture.modelTruth += '!'; },
  },
  {
    name: 'language exclusion',
    pointer: '/explicitCuts/languageContent/0',
    mutate: (g6) => { g6.explicitCuts.languageContent[0] += '!'; },
  },
  {
    name: 'Metal trigger',
    pointer: '/performanceDecision/metalTrigger',
    mutate: (g6) => { g6.performanceDecision.metalTrigger += '!'; },
  },
  {
    name: 'correctness gate',
    pointer: '/acceptance/correctnessGates/9',
    mutate: (g6) => { g6.acceptance.correctnessGates[9] = 'C99'; },
  },
  {
    name: 'performance threshold',
    pointer: '/performanceDecision/cellVerdict',
    mutate: (g6) => { g6.performanceDecision.cellVerdict += '!'; },
  },
  {
    name: 'platform scope',
    pointer: '/validationScope/packageDeploymentTarget',
    mutate: (g6) => { g6.validationScope.packageDeploymentTarget = 'macOS 26.1'; },
  },
  {
    name: 'qualification predicate',
    pointer: '/currentLocalEnvironment/onlineDisplaySlots/0/qualification',
    mutate: (g6) => { g6.currentLocalEnvironment.onlineDisplaySlots[0].qualification += '!'; },
  },
];

for (const { name, pointer, mutate } of mutations) {
  test(`mutation ${name} -> G6_FORBIDDEN_SCOPE_DELTA at ${pointer}`, () => {
    const g6 = clone(g6Zero);
    mutate(g6);
    const findings = compareFrozenScope(g5, g6);
    assert.equal(findings.length, 1,
      `expected exactly 1 forbidden delta for ${name}, got ${findings.length}: ${JSON.stringify(findings, null, 2)}`);
    assert.equal(findings[0].id, 'G6_FORBIDDEN_SCOPE_DELTA');
    assert.equal(findings[0].pointer, pointer,
      `pointer mismatch for ${name}: expected ${pointer}, got ${findings[0].pointer}`);
  });
}

test('changing a permitted delta produces zero forbidden deltas', () => {
  // Change identity.date (NOT under a permitted prefix) -> forbidden.
  // Change identity.revision (permitted prefix) -> NOT forbidden.
  const g6 = clone(g6Zero);
  g6.identity.revision = 'G6-R-different-candidate';
  g6.planGovernance.planState = 'some-other-state';
  g6.parent.files = 999;
  const findings = compareFrozenScope(g5, g6);
  assert.equal(findings.length, 0,
    `permitted-only deltas must produce 0 forbidden deltas, got ${findings.length}`);
});

test('changing a non-permitted identity leaf is forbidden', () => {
  const g6 = clone(g6Zero);
  g6.identity.date = '2026-08-16';
  const findings = compareFrozenScope(g5, g6);
  assert.equal(findings.length, 1);
  assert.equal(findings[0].id, 'G6_FORBIDDEN_SCOPE_DELTA');
  assert.equal(findings[0].pointer, '/identity/date');
});

test('removing a product leaf is forbidden', () => {
  const g6 = clone(g6Zero);
  delete g6.architecture.modelTruth;
  const findings = compareFrozenScope(g5, g6);
  const forbidden = findings.filter((f) => f.id === 'G6_FORBIDDEN_SCOPE_DELTA');
  assert.ok(forbidden.length >= 1, 'removing a leaf must be forbidden');
  assert.ok(forbidden.some((f) => f.pointer === '/architecture/modelTruth'));
});

test('HTML companion renders values equal to the machine source', () => {
  const html = buildHtmlCompanion(g6Zero);
  // identity
  assert.match(html, /G6-R-execution-ready-candidate/);
  assert.match(html, /design-and-execution-plan-candidate/);
  // frozen product scope
  assert.match(html, /monaco-editor@0\.56\.0/);
  assert.match(html, /555 total: 434 retained, 121 cut/);
  assert.match(html, /64 total: 62 retained for macOS/);
  assert.match(html, /30 provider surfaces/);
  assert.match(html, /C01-C10/);
  // architecture
  assert.match(html, /Core Text/);
  assert.match(html, /Core Graphics/);
  // qualified environment
  assert.match(html, /26\.6\.1/);
  assert.match(html, /25G76/);
  // parent
  assert.match(html, /148/);
  // plan governance
  assert.match(html, /execution-ready-candidate/);
  assert.match(html, /monacode: complete <TASK_ID>/);
  assert.match(html, /evidence\(monacode\): complete <TASK_ID>/);
  assert.match(html, /external-git/);
  assert.match(html, /token-bound/);
  // companion authority statement
  assert.match(html, /non-normative/);
  assert.match(html, /global-g6r-authoritative-contract\.html/);
});

test('committed G6 manifest file has zero forbidden scope deltas', { skip: !existsSync(G6_MANIFEST_PATH) }, () => {
  const g6Committed = JSON.parse(readFileSync(G6_MANIFEST_PATH, 'utf8'));
  const findings = compareFrozenScope(g5, g6Committed);
  assert.equal(findings.length, 0,
    `committed G6 manifest has ${findings.length} forbidden deltas: ${JSON.stringify(findings, null, 2)}`);
});

test('committed HTML companion exists and is consistent', { skip: !existsSync(G6_HTML_PATH) }, () => {
  const html = readFileSync(G6_HTML_PATH, 'utf8');
  const g6Committed = JSON.parse(readFileSync(G6_MANIFEST_PATH, 'utf8'));
  // every identity value rendered equals its machine source
  assert.match(html, new RegExp(g6Committed.identity.revision));
  assert.match(html, new RegExp(g6Committed.identity.status));
  assert.match(html, /555 total: 434 retained, 121 cut/);
});
