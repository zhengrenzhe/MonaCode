// Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs
//
// P09-T099 — Aggregate the final all-or-nothing G5-R release verdict.
//
// This is the FINAL task of the entire 200-task G6-R plan — the all-or-nothing
// release verdict. It aggregates ALL acceptance evidence into ONE verdict.
// TEST-ONLY: productTarget=null. Creates the verdict tool + document; this
// suite verifies the verdict tool runs + produces a valid verdict document.
//
// The four implementation operations this suite VERIFIES:
//
//   1. Verify one source revision, one seven-candidate set, one exact qualified
//      environment, C01-C10, every P00-P13 M0/M1 cell, lifecycle, soak,
//      sanitizers, validation, failure injection, complexity, and renderer
//      decision evidence.
//   2. Reject missing, failed, skipped, stale, malformed, unauthorized,
//      mixed-revision, mixed-environment, unhashed, or unsigned-input evidence.
//   3. Emit passed only when every prerequisite passes; otherwise emit
//      not-passed with the complete sorted blocker set.
//   4. Keep the frozen G5-R design contract unchanged and record empirical
//      implementation state only in the verdict and candidate artifacts.
//
// Contract gates (from the G6-R plan leaf P09-T099):
//
//   RED  : node --test <this file>
//          expectedExit=1 (verdict tool not yet authored → ERR_MODULE_NOT_FOUND)
//
//   GREEN: node --test <this file>
//          expectedExit=0 — the verdict tool runs, produces a valid verdict,
//          the document is consistent, the blocker set is complete + sorted, the
//          frozen contract is unchanged.
//
// The API is FROZEN (P07-T011). This suite validates the verdict tool + document
// without changing any public API or the frozen G5-R design contract.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Statically importing the verdict tool makes a missing implementation fail with
// ERR_MODULE_NOT_FOUND during the Red stage (before the tool is authored).
import {
  aggregateVerdict,
  releaseEvidenceDirectory,
  renderVerdictDocument,
} from '../../Tools/Release/release-verdict.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const VERDICT_TOOL = resolve(REPO_ROOT, 'Tools/Release/release-verdict.mjs');
const ARCHIVED_VERDICT = resolve(
  REPO_ROOT,
  'docs/archive/releases/P07-T011/RELEASE_VERDICT.md',
);
const ARCHIVED_VERDICT_SHA256 =
  'e760ffb971149bbb3afb70c7e6d99aadf5499b25b8202085062584af3037d339';

const SHA256_RE = /^[0-9a-f]{64}$/;

// The frozen contract anchors (consumed unchanged from the G6-R plan leaf).
const RECORD_SHA256 = '41944f0c8c835b15a75a8e74e4b98cc5cbc39c0ae89aba39823af5d7d4147c9b';
const PLATFORM_SCOPE = 'macOS-26-arm64';
const FROZEN_SOURCE_REVISION = 'P07-T011';
const FROZEN_SOURCE_SET_DIGEST =
  '152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36';

// The recorded acceptance-set hash consumed unchanged by every C/P task
// (P09-T002). Bound under qualified=false (1 external display at
// evidence-collection time). Read from the C02 test source as the
// authoritative acceptance-set binding.
const RECORDED_QUALIFIED_SET_HASH =
  'f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce';

// The historical evidence can remain passed, but it cannot certify a changed
// verification source set. The current source therefore has one mandatory
// staleness blocker until evidence is recollected against its exact digest.
const EXPECTED_BLOCKER_IDS = ['current-source-evidence-stale'];

// The complete expected passed-prerequisite set (sorted, 11). Includes the
// three resolved formal-device items.
const EXPECTED_PASSED_IDS = [
  'c01-c10-equivalence',
  'complexity-bounds',
  'failure-injection',
  'formal-24h-soak',
  'formal-performance-measurement',
  'license-provenance',
  'qualified-environment',
  'release-build',
  'renderer-decision',
  'sanitizers',
  'six-static-candidates',
];

// --- helpers ---------------------------------------------------------------

function sortStrings(arr) {
  return [...arr].sort((a, b) => a.localeCompare(b));
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

// ===========================================================================
// RED-phase anchor: the verdict tool exists at its declared path.
// ===========================================================================

test('the release-verdict tool exists at its declared path', () => {
  assert.equal(existsSync(VERDICT_TOOL), true, `expected ${VERDICT_TOOL} to exist`);
});

// ===========================================================================
// Operation 1 — aggregate ALL evidence: the verdict object is well-formed and
// carries every required field.
// ===========================================================================

test('Operation 1: aggregateVerdict returns a well-formed verdict object', () => {
  const v = aggregateVerdict();
  assert.ok(v, 'aggregateVerdict must return a result');

  // Schema + identity.
  assert.equal(v.schemaVersion, 1, 'schemaVersion must be 1');
  assert.equal(v.task, 'P09-T099', 'task must be P09-T099');
  assert.equal(v.recordSHA256, RECORD_SHA256, 'recordSHA256 must match the plan leaf');
  assert.equal(v.platformScope, PLATFORM_SCOPE, 'platformScope must match');

  // Source revision + set digest (frozen P07-T011).
  assert.equal(v.sourceRevision, FROZEN_SOURCE_REVISION, 'sourceRevision must be P07-T011');
  assert.equal(v.sourceSetDigest, FROZEN_SOURCE_SET_DIGEST, 'sourceSetDigest must match');
  assert.equal(
    v.evidenceSourceSetDigest,
    FROZEN_SOURCE_SET_DIGEST,
    'evidenceSourceSetDigest must retain the frozen evidence binding',
  );
  assert.match(
    v.verificationSourceSetDigest,
    SHA256_RE,
    'verificationSourceSetDigest must be a current 64-hex SHA-256',
  );

  // The recorded acceptance-set hash consumed by every C/P task.
  assert.equal(
    v.qualifiedSetHash,
    RECORDED_QUALIFIED_SET_HASH,
    'qualifiedSetHash must be the recorded acceptance-set hash',
  );
  assert.match(v.qualifiedSetHash, SHA256_RE, 'qualifiedSetHash must be 64-hex SHA-256');
});

// ===========================================================================
// Operation 1 — exactly seven candidates with no missing/extra/duplicate.
// ===========================================================================

test('Operation 1: exactly seven candidates — count, names, no duplicates, source revision', () => {
  const v = aggregateVerdict();
  const candidates = v.candidates;
  assert.ok(Array.isArray(candidates), 'candidates must be an array');
  assert.equal(candidates.length, 7, 'the acceptance set must contain exactly 7 candidates');

  const names = candidates.map((c) => c.name);
  assert.deepEqual(
    names,
    [
      'native-declaration',
      'regExpUnicode',
      'environment',
      'sourceClosure',
      'cache',
      'distribution',
      'QEnvironmentID',
    ],
    'candidate names must match the exact seven',
  );
  assert.equal(new Set(names).size, 7, 'no duplicate candidate names');
  assert.equal(new Set(candidates.map((c) => c.leaf)).size, 7, 'no duplicate leaf IDs');

  // Every candidate references the frozen source revision.
  for (const c of candidates) {
    assert.equal(
      c.sourceRevision,
      FROZEN_SOURCE_REVISION,
      `candidate ${c.name} must reference P07-T011`,
    );
    assert.match(c.hash, SHA256_RE, `candidate ${c.name} hash must be 64-hex SHA-256`);
  }
});

// ===========================================================================
// Operation 2 — reject missing/failed/skipped/stale/malformed evidence:
// every passed prerequisite and every blocker is well-formed + complete.
// ===========================================================================

test('Operation 2: the passed-prerequisite set is complete and well-formed', () => {
  const v = aggregateVerdict();
  const passed = v.passedPrerequisites;
  assert.ok(Array.isArray(passed), 'passedPrerequisites must be an array');
  assert.equal(passed.length, EXPECTED_PASSED_IDS.length, 'all passed prerequisites present');

  const ids = passed.map((p) => p.id);
  assert.deepEqual(
    sortStrings(ids),
    sortStrings(EXPECTED_PASSED_IDS),
    'passed-prerequisite ids must match the expected complete set',
  );

  // Each passed prerequisite has a status + evidence summary.
  for (const p of passed) {
    assert.equal(p.status, 'passed', `prerequisite ${p.id} status must be passed`);
    assert.ok(p.evidence && typeof p.evidence === 'string', `prerequisite ${p.id} needs evidence`);
    assert.ok(typeof p.id === 'string' && p.id.length > 0, 'prerequisite id non-empty');
  }

  // The passed set is sorted.
  for (let i = 1; i < passed.length; i++) {
    assert.ok(
      passed[i - 1].id.localeCompare(passed[i].id) <= 0,
      `passed prerequisites must be sorted: ${passed[i - 1].id} <= ${passed[i].id}`,
    );
  }
});

test('Operation 2: the blocker set rejects stale evidence and is well-formed', () => {
  const v = aggregateVerdict();
  const blockers = v.blockers;
  assert.ok(Array.isArray(blockers), 'blockers must be an array');
  assert.equal(blockers.length, EXPECTED_BLOCKER_IDS.length, 'complete blocker set must be present');

  const ids = blockers.map((b) => b.id);
  assert.deepEqual(
    sortStrings(ids),
    sortStrings(EXPECTED_BLOCKER_IDS),
    'blocker ids must match the expected complete set',
  );

  for (const b of blockers) {
    assert.equal(b.status, 'not-passed', `blocker ${b.id} status must be not-passed`);
    assert.ok(b.reason && typeof b.reason === 'string', `blocker ${b.id} needs a reason`);
    assert.ok(
      b.deferredTo && typeof b.deferredTo === 'string',
      `blocker ${b.id} must record what it is deferred to`,
    );
  }
  for (let i = 1; i < blockers.length; i++) {
    assert.ok(
      blockers[i - 1].id.localeCompare(blockers[i].id) <= 0,
      `blockers must be sorted: ${blockers[i - 1].id} <= ${blockers[i].id}`,
    );
  }
});

// ===========================================================================
// Operation 3 — emit passed only when every prerequisite passes; otherwise
// emit not-passed. The verdict string must be internally consistent with the
// blocker set: not-passed IFF blockers is non-empty.
// ===========================================================================

test('Operation 3: current source cannot inherit the frozen passed verdict', () => {
  const v = aggregateVerdict();

  assert.notEqual(
    v.verificationSourceSetDigest,
    v.evidenceSourceSetDigest,
    'changed current source must not equal the frozen evidence source set',
  );
  assert.equal(v.verdict, 'not-passed', 'stale evidence must make the verdict not-passed');
  assert.equal(
    v.blockers.some((row) => row.id === 'current-source-evidence-stale'),
    true,
    'the stale-source blocker must be present',
  );
  assert.ok(
    v.passedPrerequisites.length > 0,
    'historically passed prerequisites must remain recorded',
  );

  // Internal consistency: passed IFF no blockers.
  if (v.verdict === 'passed') {
    assert.equal(v.blockers.length, 0, 'a passed verdict must have zero blockers');
  } else {
    assert.equal(v.verdict, 'not-passed', 'a non-passed verdict must be the string not-passed');
    assert.ok(v.blockers.length > 0, 'a not-passed verdict must have at least one blocker');
  }
});

// ===========================================================================
// Operation 3 — the qualified-environment prerequisite: the recorded
// acceptance-set hash is bound under qualified=false (1 external display at
// evidence-collection time); the formal device (zero external displays) is
// required for a qualified verdict. The blocker stands until the formal run
// re-binds the evidence under a qualified environment.
// ===========================================================================

test('Operation 3: the qualified-environment prerequisite records recorded + verdict-time + user-accepted state', () => {
  const v = aggregateVerdict();
  const qe = v.qualifiedEnvironment;

  assert.ok(qe, 'qualifiedEnvironment must be present');
  // The recorded acceptance-set hash (consumed by C01-C10) is the qualified=false binding.
  assert.equal(
    qe.recorded.qualifiedSetHash,
    RECORDED_QUALIFIED_SET_HASH,
    'recorded qualifiedSetHash must match the C-test binding',
  );
  assert.equal(
    qe.recorded.boundUnderQualified,
    false,
    'the recorded acceptance evidence is bound under qualified=false (unchanged)',
  );

  // The verdict-time environment is captured live for transparency.
  assert.equal(typeof qe.verdictTime.qualified, 'boolean', 'verdictTime.qualified is boolean');
  assert.match(
    qe.verdictTime.qEnvironmentId,
    SHA256_RE,
    'verdictTime qEnvironmentId must be 64-hex',
  );
  assert.match(
    qe.verdictTime.qualifiedSetHash,
    SHA256_RE,
    'verdictTime qualifiedSetHash must be 64-hex',
  );

  // The formal-device requirement is waived by user authority: the user
  // accepted the non-formal environment (2026-08-19 directive:
  // "直接在这个设备上跑，不需要可溯源"). The prerequisite therefore passes
  // via user acceptance, even though the recorded hash remains bound under
  // qualified=false and the live environment is non-formal.
  assert.equal(qe.userAccepted, true, 'userAccepted must be true');
  const formallyQualified =
    qe.verdictTime.qualified === true &&
    qe.verdictTime.qualifiedSetHash === qe.recorded.qualifiedSetHash;
  assert.equal(
    qe.prerequisitePasses,
    formallyQualified || qe.userAccepted,
    'prerequisitePasses must be (formally qualified OR user-accepted)',
  );
  assert.equal(qe.prerequisitePasses, true, 'the qualified-env prerequisite must pass (user-accepted)');
});

// ===========================================================================
// Operation 4 — keep the frozen G5-R design contract unchanged: the verdict
// records empirical state only; the contract files are not modified.
// ===========================================================================

test('Operation 4: the frozen G5-R contract is unchanged (contractUnchanged=true)', () => {
  const v = aggregateVerdict();
  assert.equal(v.contractUnchanged, true, 'contractUnchanged must be true');
  // The verdict records empirical implementation state, not contract changes.
  assert.ok(v.evidence, 'evidence block must be present');
  assert.equal(v.evidence.contractFrozen, true, 'the contract must remain frozen');
});

// ===========================================================================
// Operation 4 — the verdict tool, run directly, produces a valid current
// verdict without treating the historical document as current evidence.
// ===========================================================================

test('Operation 4: the verdict tool runs directly and exits 0', () => {
  const r = spawnSync(NODE, [VERDICT_TOOL], { encoding: 'utf8', cwd: REPO_ROOT, timeout: 120000 });
  assert.equal(r.status, 0, `verdict tool must exit 0; stderr=${r.stderr}`);
  assert.ok(r.stdout.length > 0, 'verdict tool must print output');
  // The tool prints a JSON verdict line.
  const parsed = JSON.parse(r.stdout.split('\n').find((l) => l.startsWith('{')));
  assert.equal(parsed.verdict, 'not-passed', 'the printed verdict must reject stale evidence');
  assert.ok(Array.isArray(parsed.blockers), 'the printed verdict must carry a blockers array');
  assert.equal(
    parsed.blockers.some((row) => row.id === 'current-source-evidence-stale'),
    true,
    'the printed verdict must carry the stale-source blocker',
  );
});

// ===========================================================================
// Operation 4 — the historical document is immutable; current evidence is
// rendered into a digest-bound artifacts directory.
// ===========================================================================

test('Operation 4: the historical P07-T011 verdict is byte-preserved', () => {
  assert.equal(existsSync(ARCHIVED_VERDICT), true, 'the archived verdict must exist');
  assert.equal(
    sha256(readFileSync(ARCHIVED_VERDICT)),
    ARCHIVED_VERDICT_SHA256,
    'the archived verdict bytes must remain unchanged',
  );
});

test('Operation 4: current evidence path and Markdown are bound to the current digest', () => {
  const v = aggregateVerdict();
  const evidenceDirectory = releaseEvidenceDirectory(v.verificationSourceSetDigest);
  assert.equal(
    evidenceDirectory,
    resolve(REPO_ROOT, 'artifacts/releases', v.verificationSourceSetDigest),
    'release evidence directory must be keyed by the current source digest',
  );

  const md = renderVerdictDocument(v);

  assert.ok(/## Verdict:\s*`not-passed`/.test(md), 'current Markdown must record not-passed');

  // Current and frozen evidence identities are both explicit.
  assert.ok(md.includes(FROZEN_SOURCE_REVISION), 'the document must record P07-T011');
  assert.ok(
    md.includes(v.verificationSourceSetDigest),
    'the document must record the current verification source-set digest',
  );
  assert.ok(
    md.includes(v.evidenceSourceSetDigest),
    'the document must record the frozen evidence source-set digest',
  );
  assert.ok(md.includes(RECORDED_QUALIFIED_SET_HASH), 'the document must record the qualified-set hash');

  for (const b of v.blockers) {
    assert.ok(
      md.includes(b.id),
      `the document must record blocker ${b.id}`,
    );
  }

  for (const p of v.passedPrerequisites) {
    assert.ok(
      md.includes(p.id),
      `the document must record passed prerequisite ${p.id}`,
    );
  }

  assert.ok(/frozen/i.test(md), 'the document must assert the contract is frozen');
});
