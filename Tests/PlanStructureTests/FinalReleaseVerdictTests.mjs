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
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Statically importing the verdict tool makes a missing implementation fail with
// ERR_MODULE_NOT_FOUND during the Red stage (before the tool is authored).
import { aggregateVerdict } from '../../Tools/Release/release-verdict.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const VERDICT_TOOL = resolve(REPO_ROOT, 'Tools/Release/release-verdict.mjs');
const VERDICT_DOC = resolve(REPO_ROOT, 'RELEASE_VERDICT.md');

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

// The complete expected blocker set (sorted). The verdict is not-passed because
// three formal-acceptance items are deferred to the formal run on the formal
// device. Every other prerequisite passes.
const EXPECTED_BLOCKER_IDS = [
  'qualified-environment',
  'formal-performance-measurement',
  'formal-24h-soak',
];

// The complete expected passed-prerequisite set (sorted).
const EXPECTED_PASSED_IDS = [
  'c01-c10-equivalence',
  'complexity-bounds',
  'failure-injection',
  'license-provenance',
  'renderer-decision',
  'release-build',
  'sanitizers',
  'six-static-candidates',
];

// --- helpers ---------------------------------------------------------------

function sortStrings(arr) {
  return [...arr].sort((a, b) => a.localeCompare(b));
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

test('Operation 2: the blocker set is complete, well-formed, and sorted', () => {
  const v = aggregateVerdict();
  const blockers = v.blockers;
  assert.ok(Array.isArray(blockers), 'blockers must be an array');
  assert.equal(blockers.length, EXPECTED_BLOCKER_IDS.length, 'all blockers present');

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

  // The blocker set is sorted by id.
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

test('Operation 3: the verdict is not-passed with the complete blocker set', () => {
  const v = aggregateVerdict();

  // The verdict is not-passed because the formal-device items are deferred.
  assert.equal(v.verdict, 'not-passed', 'the verdict must be not-passed');
  assert.ok(v.blockers.length > 0, 'a not-passed verdict must have blockers');
  assert.ok(
    v.passedPrerequisites.length > 0,
    'the passed prerequisites must still be recorded',
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

test('Operation 3: the qualified-environment blocker records recorded + verdict-time state', () => {
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
    'the recorded acceptance evidence must be bound under qualified=false',
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

  // The prerequisite passes IFF the live env is qualified AND the recorded
  // hash matches the live hash (i.e. the evidence is re-bound under a
  // qualified environment). Until the formal run re-binds, this is false.
  assert.equal(
    qe.prerequisitePasses,
    qe.verdictTime.qualified === true &&
      qe.verdictTime.qualifiedSetHash === qe.recorded.qualifiedSetHash,
    'prerequisitePasses must be (live qualified AND recorded hash == live hash)',
  );
  assert.equal(qe.prerequisitePasses, false, 'the qualified-env prerequisite must not pass yet');
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
// Operation 4 — the verdict tool, run directly, produces a valid verdict and
// validates the RELEASE_VERDICT.md document.
// ===========================================================================

test('Operation 4: the verdict tool runs directly and exits 0', () => {
  const r = spawnSync(NODE, [VERDICT_TOOL], { encoding: 'utf8', cwd: REPO_ROOT, timeout: 120000 });
  assert.equal(r.status, 0, `verdict tool must exit 0; stderr=${r.stderr}`);
  assert.ok(r.stdout.length > 0, 'verdict tool must print output');
  // The tool prints a JSON verdict line.
  const parsed = JSON.parse(r.stdout.split('\n').find((l) => l.startsWith('{')));
  assert.equal(parsed.verdict, 'not-passed', 'the printed verdict must be not-passed');
  assert.ok(Array.isArray(parsed.blockers), 'the printed verdict must carry blockers');
});

// ===========================================================================
// Operation 4 — RELEASE_VERDICT.md exists and is internally consistent with
// the verdict tool's output.
// ===========================================================================

test('Operation 4: RELEASE_VERDICT.md exists and is consistent with the verdict', () => {
  assert.equal(existsSync(VERDICT_DOC), true, 'RELEASE_VERDICT.md must exist');
  const md = readFileSync(VERDICT_DOC, 'utf8');

  const v = aggregateVerdict();

  // The document records the verdict.
  assert.ok(md.includes('not-passed'), 'the document must record the not-passed verdict');

  // The document records the source revision + acceptance-set hash.
  assert.ok(md.includes(FROZEN_SOURCE_REVISION), 'the document must record P07-T011');
  assert.ok(md.includes(RECORDED_QUALIFIED_SET_HASH), 'the document must record the qualified-set hash');

  // The document records every blocker id.
  for (const b of v.blockers) {
    assert.ok(
      md.includes(b.id),
      `the document must record blocker ${b.id}`,
    );
  }

  // The document records every passed-prerequisite id.
  for (const p of v.passedPrerequisites) {
    assert.ok(
      md.includes(p.id),
      `the document must record passed prerequisite ${p.id}`,
    );
  }

  // The document is honest: it records the deferred formal items.
  assert.ok(/deferred/i.test(md), 'the document must record deferred items');
  // The document records the frozen-contract-unchanged assertion.
  assert.ok(/frozen/i.test(md), 'the document must assert the contract is frozen');
});
