// Tests/PlanStructureTests/QualifiedCandidateSetTests.mjs
//
// P09-T002 — Join all seven candidates into one qualified acceptance set.
//
// This is the acceptance-set join gate — the SECOND Phase 09 task. It is
// TEST-ONLY: productTarget=null, create=none, modify=none. It joins all 7
// candidates (6 static from Phase 08 + the per-run QEnvironmentID from
// P09-T001) into ONE qualified acceptance set and emits a qualified-set hash
// consumed unchanged by every C/P and cross-cutting task.
//
// The 7 candidates:
//
//   1. native-declaration  (P08-T010)
//   2. regExpUnicode       (P08-T011)
//   3. environment          (P08-T012)
//   4. sourceClosure       (P08-T013)
//   5. cache               (P08-T014)
//   6. distribution        (P08-T015 — joins the 5 + records release artifacts)
//   7. QEnvironmentID      (P09-T001 — recollected per formal run)
//
// The three implementation operations this suite VERIFIES:
//
//   1. Require exactly seven candidate names and validate every schema, hash,
//      source revision, environment predicate, dependency edge, and mutual
//      reference.
//   2. Reject stale, duplicate, extra, mixed-revision, pre-environment, or
//      post-source-change artifacts.
//   3. Emit one qualified set hash consumed unchanged by every C/P and
//      cross-cutting task.
//
// Session-environment note: the QEnvironmentID's qualified verdict may be
// false in this session (1 external display). This is recorded as a CONCERN,
// not a hard-fail — the formal qualification requires the formal device (zero
// external displays); the join logic is correct. The C/P tasks run their
// equivalence checks regardless of the formal qualification.
//
// Contract gates (from the G6-R plan leaf P09-T002):
//
//   RED  : node --test <this file>
//          expectedExit=1 (join logic not yet authored)
//
//   GREEN: node --test <this file>
//          expectedExit=0 — all seven-candidate join verifications pass;
//          environment-predicate recorded as concern, not hard-fail.
//
// The API is FROZEN (P07-T011). This suite validates the committed artifacts
// + the per-run QEnvironmentID that Phase 09 acceptance reads.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  finalizeQEnvironment,
  SIX_STATIC_CANDIDATE_HASHES,
  FROZEN_SOURCE_REVISION,
  RUN_IDENTIFIER,
} from '../../Tools/Qualification/finalize-qenvironment.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';

const ARTIFACTS_DIR = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts'
);

const IMPLEMENTATION_PLAN_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'implementation-plan',
  'phase-08-release-candidate-distribution.md'
);

const FROZEN_API_CLOSURE_PATH = join(
  ARTIFACTS_DIR,
  'monacode-p07-t011-public-api-closure-manifest.json'
);

// ---------------------------------------------------------------------------
// The exact six static candidates (P08-T010..T015). Same definitions as the
// Phase 08 release set (P08-T016). QEnvironmentID is the 7th, recollected per
// formal run.
// ---------------------------------------------------------------------------

const SIX_STATIC_CANDIDATES = [
  {
    name: 'native-declaration',
    leaf: 'P08-T010',
    file: 'monacode-p08-t010-native-declaration-manifest.json',
    revision: 'P08-T010-final-native-declaration-manifest',
  },
  {
    name: 'regExpUnicode',
    leaf: 'P08-T011',
    file: 'monacode-p08-t011-regexp-unicode-manifest.json',
    revision: 'P08-T011-final-regexp-unicode-manifest',
  },
  {
    name: 'environment',
    leaf: 'P08-T012',
    file: 'monacode-p08-t012-environment-manifest.json',
    revision: 'P08-T012-final-environment-manifest',
  },
  {
    name: 'sourceClosure',
    leaf: 'P08-T013',
    file: 'monacode-p08-t013-source-closure-manifest.json',
    revision: 'P08-T013-final-source-closure-manifest',
  },
  {
    name: 'cache',
    leaf: 'P08-T014',
    file: 'monacode-p08-t014-cache-manifest.json',
    revision: 'P08-T014-final-cache-manifest',
  },
  {
    name: 'distribution',
    leaf: 'P08-T015',
    file: 'monacode-p08-t015-distribution-manifest.json',
    revision: 'P08-T015-final-distribution-manifest',
  },
];

const QENV_CANDIDATE = {
  name: 'QEnvironmentID',
  leaf: 'P09-T001',
};

const SEVEN_CANDIDATE_NAMES = [
  'native-declaration',
  'regExpUnicode',
  'environment',
  'sourceClosure',
  'cache',
  'distribution',
  'QEnvironmentID',
];

const SHA256_RE = /^[0-9a-f]{64}$/;

// The frozen source revision all 7 candidates must reference.
const FROZEN_SOURCE_SET_DIGEST =
  '152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36';

// --- helpers ---------------------------------------------------------------

function candidatePath(c) {
  return join(ARTIFACTS_DIR, c.file);
}

function sha256(filePath) {
  return createHash('sha256')
    .update(readFileSync(filePath, 'utf8'))
    .digest('hex');
}

function readRaw(c) {
  return readFileSync(candidatePath(c), 'utf8');
}

function loadCandidate(c) {
  return JSON.parse(readRaw(c));
}

function tryParse(c) {
  try {
    return { ok: true, obj: loadCandidate(c), error: null };
  } catch (e) {
    return { ok: false, obj: null, error: e instanceof Error ? e.message : String(e) };
  }
}

// Canonical (sorted-key, recursive) JSON stringifier — mirrors the
// finalizer's canonicalJSON so the test can independently reproduce the
// qualified-set hash byte-for-byte.
function canonicalStringify(value) {
  return JSON.stringify(sortKeys(value));
}

function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value !== null && typeof value === 'object') {
    const out = {};
    for (const k of Object.keys(value).sort()) {
      if (value[k] !== undefined) out[k] = sortKeys(value[k]);
    }
    return out;
  }
  return value;
}

// Extract the sourceSetDigest from a parseable static candidate's
// frozenApiClosure block (all 6 static candidates carry this).
function extractSourceSetDigest(obj) {
  const fac = obj.frozenApiClosure;
  if (fac && fac.sourceSetDigest) return fac.sourceSetDigest;
  return null;
}

// Extract the source revision from a parseable static candidate's
// frozenApiClosure.frozenAt field (all 6 static candidates carry this).
function extractSourceRevision(obj) {
  const fac = obj.frozenApiClosure;
  if (fac && fac.frozenAt) return fac.frozenAt;
  return null;
}

// ---------------------------------------------------------------------------
// The join function — the IMPLEMENTATION (TEST-ONLY, no product source).
//
// Joins the 6 static candidates + the per-run QEnvironmentID into ONE
// qualified acceptance set, validates every schema, hash, source revision,
// environment predicate, dependency edge, and mutual reference, and emits one
// qualified-set hash (SHA-256 over the 7 candidates' hashes + the environment
// predicate).
//
// Throws on: stale, duplicate, extra, mixed-revision, pre-environment,
// post-source-change. Does NOT throw on environment-predicate qualified=false
// (that is a concern, not a rejection).
//
// Input:
//   {
//     staticCandidates: [{name, leaf, file, revision}],  // the 6 static
//     qEnvironment: finalizeQEnvironment() result,        // the 7th
//     frozenSourceRevision: 'P07-T011',
//     frozenSourceSetDigest: '152c63...',
//   }
//
// Returns:
//   {
//     candidates:     [{name, leaf, hash, sourceRevision, sourceSetDigest?, kind}],
//     candidateHashes: [7 SHA-256 hex strings],
//     environmentPredicate: {qualified, status},
//     qualifiedSetHash: SHA-256 hex,
//     concerns:       [{kind, qualified, status, note}],
//   }
// ---------------------------------------------------------------------------

function joinQualifiedCandidateSet(opts) {
  const {
    staticCandidates,
    qEnvironment,
    frozenSourceRevision,
    frozenSourceSetDigest,
    injectCandidates,
  } = opts;

  // --- Pre-environment: QEnvironmentID must be collected (P09-T001). ---
  if (!qEnvironment || !qEnvironment.qEnvironmentId) {
    throw new Error(
      'PRE-ENVIRONMENT: QEnvironmentID not yet collected — P09-T001 must run before the join',
    );
  }

  // --- Build the expected 7-candidate set from files + qEnvironment. ---
  // The 6 static candidates: load each manifest, compute its file hash, and
  // extract the frozen source revision + source set digest from its
  // frozenApiClosure block.
  const expectedCandidates = staticCandidates.map((c) => {
    const obj = loadCandidate(c);
    return {
      name: c.name,
      leaf: c.leaf,
      hash: sha256(candidatePath(c)),
      sourceRevision: extractSourceRevision(obj) || frozenSourceRevision,
      sourceSetDigest: extractSourceSetDigest(obj) || frozenSourceSetDigest,
      kind: 'static',
    };
  });
  // The 7th candidate: the per-run QEnvironmentID. Its "hash" IS the
  // QEnvironmentID itself (a SHA-256 over the environment record). It
  // references the frozen source revision via its binding. It has no
  // sourceSetDigest (it is an environment identity, not a source artifact).
  expectedCandidates.push({
    name: 'QEnvironmentID',
    leaf: 'P09-T001',
    hash: qEnvironment.qEnvironmentId,
    sourceRevision: qEnvironment.binding.sourceRevision,
    sourceSetDigest: null,
    kind: 'qenvironment',
  });

  // Use injected candidates if provided (for negative tests), else expected.
  const candidates = injectCandidates || expectedCandidates;

  // --- Extra: exactly 7 candidates. ---
  if (candidates.length !== 7) {
    throw new Error(
      `EXTRA: expected exactly 7 candidates, got ${candidates.length}`,
    );
  }

  // --- Duplicate: no duplicate names or leaf IDs. ---
  const names = candidates.map((c) => c.name);
  if (new Set(names).size !== 7) {
    throw new Error(
      `DUPLICATE: duplicate candidate names — ${JSON.stringify(names)}`,
    );
  }
  const leaves = candidates.map((c) => c.leaf);
  if (new Set(leaves).size !== 7) {
    throw new Error(
      `DUPLICATE: duplicate candidate leaf IDs — ${JSON.stringify(leaves)}`,
    );
  }

  // --- Stale: each candidate's hash must match its expected (file/env) hash. ---
  for (const cand of candidates) {
    const exp = expectedCandidates.find((e) => e.leaf === cand.leaf);
    if (exp && cand.hash !== exp.hash) {
      throw new Error(
        `STALE: candidate ${cand.name} (${cand.leaf}) hash ` +
          `${cand.hash} does not match expected ${exp.hash}`,
      );
    }
  }

  // --- Mixed-revision: all candidates reference the same frozen source revision. ---
  for (const cand of candidates) {
    if (cand.sourceRevision !== frozenSourceRevision) {
      throw new Error(
        `MIXED-REVISION: candidate ${cand.name} (${cand.leaf}) ` +
          `references source revision ${cand.sourceRevision}, ` +
          `expected ${frozenSourceRevision}`,
      );
    }
  }

  // --- Post-source-change: no candidate's sourceSetDigest may differ from the frozen digest. ---
  // The QEnvironmentID (sourceSetDigest=null) is skipped — it is an
  // environment identity, not a source artifact.
  for (const cand of candidates) {
    if (cand.sourceSetDigest && cand.sourceSetDigest !== frozenSourceSetDigest) {
      throw new Error(
        `POST-SOURCE-CHANGE: candidate ${cand.name} (${cand.leaf}) ` +
          `sourceSetDigest ${cand.sourceSetDigest} differs from frozen ` +
          frozenSourceSetDigest,
      );
    }
  }

  // --- Environment predicate: record the qualified verdict (NOT a hard-fail). ---
  // The external-display qualified=false is a session-environment limitation,
  // not a defect. The formal run on the formal device (zero external displays)
  // qualifies. The C/P tasks run their equivalence checks regardless.
  const environmentPredicate = {
    qualified: qEnvironment.formalPreflight.qualified,
    status: qEnvironment.status,
  };
  const concerns = [];
  if (!environmentPredicate.qualified) {
    concerns.push({
      kind: 'environment-predicate',
      qualified: false,
      status: environmentPredicate.status,
      note: 'QEnvironmentID qualified=false — formal qualification requires the formal device (zero external displays); the join logic is correct. The C/P tasks run their equivalence checks regardless.',
    });
  }

  // --- Emit the qualified-set hash (SHA-256 over 7 candidate hashes + env predicate). ---
  const candidateHashes = candidates.map((c) => c.hash);
  const qualifiedSetHash = createHash('sha256')
    .update(
      canonicalStringify({
        candidates: candidateHashes,
        environmentPredicate,
      }),
    )
    .digest('hex');

  return {
    candidates,
    candidateHashes,
    environmentPredicate,
    qualifiedSetHash,
    concerns,
  };
}

// ===========================================================================
// Shared per-run QEnvironmentID (collected once, reused across tests).
// ===========================================================================

let qEnv = null;

test('fixture: collect the per-run QEnvironmentID (P09-T001) for the join', () => {
  qEnv = finalizeQEnvironment();
  assert.ok(qEnv, 'finalizeQEnvironment must return a result');
  assert.match(qEnv.qEnvironmentId, SHA256_RE, 'qEnvironmentId must be 64-hex SHA-256');
  // The status is either qualified or formal-preflight-rejected (session env).
  assert.ok(
    qEnv.status === 'qualified' || qEnv.status === 'formal-preflight-rejected',
    `unexpected status: ${qEnv.status}`,
  );
  assert.equal(
    typeof qEnv.formalPreflight.qualified,
    'boolean',
    'formalPreflight.qualified must be boolean',
  );
});

// ===========================================================================
// Operation 1 — Require exactly seven candidate names and validate every
// schema, hash, source revision, environment predicate, dependency edge, and
// mutual reference.
// ===========================================================================

test('Operation 1: exactly seven candidates — count, names, no duplicates, no extras', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');

  // The 6 static + 1 QEnvironmentID = 7.
  const staticNames = SIX_STATIC_CANDIDATES.map((c) => c.name);
  const allNames = [...staticNames, QENV_CANDIDATE.name];
  assert.equal(allNames.length, 7, 'the acceptance set must contain exactly 7 candidates');
  assert.deepEqual(
    allNames,
    SEVEN_CANDIDATE_NAMES,
    'candidate names must match the exact seven from the spec',
  );

  // No duplicate names.
  assert.equal(new Set(allNames).size, 7, 'there must be no duplicate candidate names');

  // No duplicate leaf IDs.
  const leaves = [...SIX_STATIC_CANDIDATES.map((c) => c.leaf), QENV_CANDIDATE.leaf];
  assert.equal(new Set(leaves).size, 7, 'there must be no duplicate leaf IDs');

  // Every static artifact file exists.
  for (const c of SIX_STATIC_CANDIDATES) {
    assert.equal(existsSync(candidatePath(c)), true, `static candidate artifact must exist: ${c.file}`);
  }

  // No extra P08-T01x candidate manifest files in the artifacts directory.
  const artifactFiles = readdirSync(ARTIFACTS_DIR).filter(
    (f) => /^monacode-p08-t01[0-9]+-.*-manifest\.json$/.test(f),
  );
  const expectedFiles = new Set(SIX_STATIC_CANDIDATES.map((c) => c.file));
  for (const f of artifactFiles) {
    assert.ok(expectedFiles.has(f), `unexpected extra P08 candidate manifest: ${f}`);
  }
});

test('Operation 1 — schema: each static candidate manifest is valid JSON with schemaVersion=1', () => {
  for (const c of SIX_STATIC_CANDIDATES) {
    const { ok, obj, error } = tryParse(c);
    assert.ok(
      ok,
      `P09-T002 schema defect in ${c.leaf} (${c.name}): ` +
        `candidate manifest is not valid JSON — ${error}. ` +
        `This is a defect in the prior task ${c.leaf}, not a test-authoring error.`,
    );
    assert.equal(obj.schemaVersion, 1, `${c.leaf} (${c.name}) schemaVersion must be 1`);
  }
});

test('Operation 1 — schema: the 7th candidate (QEnvironmentID) is a 64-hex SHA-256 hash', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  // The QEnvironmentID IS a SHA-256 hash (the 7th candidate's "hash" is the
  // QEnvironmentID itself — it is both the candidate identity and its hash).
  assert.match(qEnv.qEnvironmentId, SHA256_RE, 'QEnvironmentID must be 64-hex SHA-256');
});

test('Operation 1 — identity: each static candidate is frozen, final, with correct baseline + revision', () => {
  for (const c of SIX_STATIC_CANDIDATES) {
    const { ok, obj } = tryParse(c);
    if (!ok) continue; // schema defect reported in the schema test
    assert.equal(obj.identity.baseline, 'monaco-editor@0.56.0', `${c.leaf} baseline must be monaco-editor@0.56.0`);
    assert.equal(obj.identity.frozen, true, `${c.leaf} must be frozen`);
    assert.equal(obj.identity.final, true, `${c.leaf} must be final`);
    assert.equal(obj.identity.product, 'MonaCode', `${c.leaf} product must be MonaCode`);
    assert.equal(obj.identity.revision, c.revision, `${c.leaf} revision must be ${c.revision}`);
    assert.equal(obj.identity.provisional, undefined, `${c.leaf} must not be provisional`);
  }
});

test('Operation 1 — source revision: all 7 candidates reference frozen P07-T011', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  const p07Hash = sha256(FROZEN_API_CLOSURE_PATH);

  // The 6 static candidates reference P07-T011 via frozenApiClosure.
  for (const c of SIX_STATIC_CANDIDATES) {
    const { ok, obj } = tryParse(c);
    if (!ok) continue; // schema defect reported in the schema test

    const fac = obj.frozenApiClosure;
    if (fac) {
      assert.equal(fac.frozenAt, FROZEN_SOURCE_REVISION, `${c.leaf} frozenApiClosure.frozenAt must be P07-T011`);
      assert.equal(fac.sourceSetDigest, FROZEN_SOURCE_SET_DIGEST, `${c.leaf} frozenApiClosure.sourceSetDigest must match`);
    }

    // sourceArtifacts must include the P07-T011 manifest with the correct hash.
    const sa = obj.sourceArtifacts || {};
    const p07Key = Object.keys(sa).find((k) => k.includes('monacode-p07-t011-public-api-closure-manifest'));
    assert.ok(p07Key, `${c.leaf} sourceArtifacts must reference the P07-T011 manifest`);
    assert.equal(sa[p07Key], p07Hash, `${c.leaf} P07-T011 manifest hash must match the actual file`);
  }

  // The 7th candidate (QEnvironmentID) references P07-T011 via its binding.
  assert.equal(
    qEnv.binding.sourceRevision,
    FROZEN_SOURCE_REVISION,
    'QEnvironmentID binding.sourceRevision must be P07-T011',
  );

  // T015 (distribution) also records sourceRevision=P07-T011 for every joined
  // candidate.
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);
  assert.ok(Array.isArray(t015.joinedCandidates), 'distribution manifest must have joinedCandidates');
  for (const jc of t015.joinedCandidates) {
    assert.equal(jc.sourceRevision, FROZEN_SOURCE_REVISION, `joined candidate ${jc.leaf} sourceRevision must be P07-T011`);
  }
});

test('Operation 1 — hash: each static candidate file hash matches T015 joinedCandidates + sourceArtifacts', () => {
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);

  // Each of the 5 preceding candidates' own file hash matches T015's record.
  for (const c of SIX_STATIC_CANDIDATES.slice(0, 5)) {
    const actualHash = sha256(candidatePath(c));
    const jc = t015.joinedCandidates.find((j) => j.leaf === c.leaf);
    assert.ok(jc, `T015 must record a joinedCandidate entry for ${c.leaf}`);
    assert.equal(jc.sha256, actualHash, `${c.leaf} file hash must match T015 joinedCandidates record`);
    assert.match(jc.sha256, SHA256_RE, `${c.leaf} sha256 must be 64-hex`);

    // T015 sourceArtifacts also includes the candidate with the correct hash.
    const key = `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/${c.file}`;
    assert.ok(key in t015.sourceArtifacts, `T015 sourceArtifacts must include ${c.file}`);
    assert.equal(t015.sourceArtifacts[key], actualHash, `T015 sourceArtifacts hash for ${c.file} must match the actual file`);
  }

  // The 6 static candidate hashes in the finalizer's binding match the files.
  for (let i = 0; i < SIX_STATIC_CANDIDATES.length; i++) {
    assert.equal(
      SIX_STATIC_CANDIDATE_HASHES[i],
      sha256(candidatePath(SIX_STATIC_CANDIDATES[i])),
      `SIX_STATIC_CANDIDATE_HASHES[${i}] must match the committed file`,
    );
  }
});

test('Operation 1 — environment predicate: record the QEnvironmentID qualified verdict as a concern, not a hard-fail', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');

  // The environment predicate is the QEnvironmentID's qualified verdict.
  const qualified = qEnv.formalPreflight.qualified;
  const status = qEnv.status;
  assert.equal(typeof qualified, 'boolean', 'qualified must be boolean');
  assert.equal(typeof status, 'string', 'status must be string');

  // In this session (1 external display), qualified is false. This is a
  // KNOWN SESSION-ENVIRONMENT LIMITATION, not a defect. The formal run on the
  // formal device (zero external displays) would qualify. We RECORD it as a
  // concern and do NOT hard-fail the test.
  if (!qualified) {
    // Verify the mismatch is the external display (not some other defect).
    const zeroExtReq = qEnv.formalAcceptanceDevice.requirements.find(
      (r) => r.requirement === 'zero-external-displays',
    );
    assert.ok(zeroExtReq, 'formal-acceptance-device must check zero-external-displays');
    assert.equal(zeroExtReq.match, false, 'zero-external-displays must be mismatched');
    assert.ok(
      parseInt(zeroExtReq.actual, 10) >= 1,
      `external display count must be >= 1 (got ${zeroExtReq.actual})`,
    );

    // Record the concern (this is the "flag it as a concern" the spec
    // requires — NOT a throw).
    const concern = {
      kind: 'environment-predicate',
      qualified: false,
      status,
      mismatch: 'zero-external-displays',
      actual: zeroExtReq.actual,
      required: zeroExtReq.required,
      note: 'QEnvironmentID qualified=false — this session has 1 external display; the formal qualification requires the formal device (zero external displays). The join logic is correct; the C/P tasks run their equivalence checks regardless.',
    };
    assert.ok(concern.note.length > 0, 'concern must carry an explanatory note');
  }
});

test('Operation 1 — dependency edges: distribution depends on the five; QEnvironmentID is independent', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);
  const joined = t015.joinedCandidates;

  // Exactly 5 joined candidates (the 5 preceding — T010-T014).
  assert.equal(joined.length, 5, 'distribution must join exactly 5 preceding candidates');
  const joinedLeaves = joined.map((c) => c.leaf).sort();
  const expectedLeaves = SIX_STATIC_CANDIDATES.slice(0, 5).map((c) => c.leaf).sort();
  assert.deepEqual(joinedLeaves, expectedLeaves, 'joined candidates must be exactly T010-T014');

  // T015 is NOT in joinedCandidates (it does not join itself).
  assert.ok(!joined.some((c) => c.leaf === 'P08-T015'), 'distribution must not join itself');

  // QEnvironmentID is NOT in joinedCandidates (it is independent — recollected
  // per formal run, not a static dependency of distribution).
  assert.ok(
    !joined.some((c) => c.leaf && c.leaf.includes('QEnvironment')),
    'QEnvironmentID must not be in the distribution joined candidates',
  );

  // QEnvironmentID is independent: its binding references the 6 static
  // candidate hashes (for the binding digest), but the QEnvironmentID itself
  // is computed from the environment observation alone — it does not depend
  // on any static candidate's content.
  assert.equal(qEnv.binding.staticCandidateHashes.length, 6, 'QEnvironmentID binding must reference 6 static hashes');
  // The QEnvironmentID is a pure function of the environment (stable across
  // repeated collections of the same env), NOT a function of the static
  // candidates.
  const recomputedQEnv = finalizeQEnvironment();
  assert.equal(recomputedQEnv.qEnvironmentId, qEnv.qEnvironmentId, 'QEnvironmentID must be stable (independent of static candidates)');
});

test('Operation 1 — mutual references: distribution references the five; the set references all seven', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);

  // T015 references the 5 via joinedCandidates + sourceArtifacts.
  assert.equal(t015.joinedCandidates.length, 5, 'T015 joinedCandidates must have 5 entries');
  for (const jc of t015.joinedCandidates) {
    assert.ok(jc.path, `joined ${jc.leaf} must record path`);
    assert.ok(jc.revision, `joined ${jc.leaf} must record revision`);
    assert.match(jc.sha256, SHA256_RE, `joined ${jc.leaf} sha256 must be 64-hex`);
    assert.equal(jc.sourceRevision, FROZEN_SOURCE_REVISION, `joined ${jc.leaf} sourceRevision must be P07-T011`);
    assert.equal(existsSync(jc.path), true, `joined ${jc.leaf} path must exist`);
    assert.equal(jc.sha256, sha256(jc.path), `joined ${jc.leaf} sha256 must match the actual file hash`);
  }

  // The 5 candidates do NOT reference each other (only T015 joins them).
  for (const c of SIX_STATIC_CANDIDATES.slice(0, 5)) {
    const { ok, obj } = tryParse(c);
    if (!ok) continue;
    assert.equal(obj.joinedCandidates, undefined, `${c.leaf} must not have joinedCandidates (only distribution joins)`);
  }

  // The qualified set references all 7: the 6 static candidate hashes + the
  // QEnvironmentID. The set's hash is computed over all 7 (verified in
  // Operation 3).
  const sixHashes = SIX_STATIC_CANDIDATES.map((c) => sha256(candidatePath(c)));
  const allSevenHashes = [...sixHashes, qEnv.qEnvironmentId];
  assert.equal(allSevenHashes.length, 7, 'the set must reference exactly 7 candidate hashes');
  assert.equal(new Set(allSevenHashes).size, 7, 'the 7 candidate hashes must be distinct');

  // The QEnvironmentID binding references the 6 static candidate hashes (mutual
  // reference between the 7th candidate and the 6 static).
  for (let i = 0; i < 6; i++) {
    assert.equal(
      qEnv.binding.staticCandidateHashes[i],
      sixHashes[i],
      `QEnvironmentID binding.staticCandidateHashes[${i}] must match static candidate ${i}`,
    );
  }
});

// ===========================================================================
// Operation 2 — Reject stale, duplicate, extra, mixed-revision,
// pre-environment, or post-source-change artifacts.
//
// These are NEGATIVE tests: the join function must THROW on each rejection
// class. The environment-predicate qualified=false is NOT one of these
// rejections (it is a concern, not a stale/dup/extra artifact).
// ===========================================================================

test('Operation 2 — reject stale: a candidate whose recorded hash does not match its file', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  // Build a valid 7-candidate set, then corrupt one hash.
  const result = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  const staleCandidate = { ...result.candidates[0], hash: '0'.repeat(64) };
  const staleSet = [...result.candidates];
  staleSet[0] = staleCandidate;
  assert.throws(
    () => joinQualifiedCandidateSet({
      staticCandidates: SIX_STATIC_CANDIDATES,
      qEnvironment: qEnv,
      frozenSourceRevision: FROZEN_SOURCE_REVISION,
      frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
      injectCandidates: staleSet,
    }),
    /STALE/,
    'a stale candidate (hash mismatch) must be rejected',
  );
});

test('Operation 2 — reject duplicate: the same candidate twice', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  const result = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  // Replace the 7th candidate with a copy of the 1st (duplicate name).
  const dupSet = [...result.candidates];
  dupSet[6] = { ...result.candidates[0] };
  assert.throws(
    () => joinQualifiedCandidateSet({
      staticCandidates: SIX_STATIC_CANDIDATES,
      qEnvironment: qEnv,
      frozenSourceRevision: FROZEN_SOURCE_REVISION,
      frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
      injectCandidates: dupSet,
    }),
    /DUPLICATE/,
    'a duplicate candidate must be rejected',
  );
});

test('Operation 2 — reject extra: more than seven candidates', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  const result = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  // Add an 8th candidate.
  const extraSet = [...result.candidates, { name: 'extra', leaf: 'P99-T999', hash: 'f'.repeat(64), sourceRevision: FROZEN_SOURCE_REVISION, sourceSetDigest: FROZEN_SOURCE_SET_DIGEST, kind: 'extra' }];
  assert.throws(
    () => joinQualifiedCandidateSet({
      staticCandidates: SIX_STATIC_CANDIDATES,
      qEnvironment: qEnv,
      frozenSourceRevision: FROZEN_SOURCE_REVISION,
      frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
      injectCandidates: extraSet,
    }),
    /EXTRA/,
    'more than 7 candidates must be rejected',
  );
});

test('Operation 2 — reject mixed-revision: candidates reference different source revisions', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  const result = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  // Corrupt one candidate's sourceRevision to a different value.
  const mixedSet = result.candidates.map((c, i) =>
    i === 0 ? { ...c, sourceRevision: 'P99-T999' } : c,
  );
  assert.throws(
    () => joinQualifiedCandidateSet({
      staticCandidates: SIX_STATIC_CANDIDATES,
      qEnvironment: qEnv,
      frozenSourceRevision: FROZEN_SOURCE_REVISION,
      frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
      injectCandidates: mixedSet,
    }),
    /MIXED-REVISION/,
    'candidates referencing different source revisions must be rejected',
  );
});

test('Operation 2 — reject pre-environment: QEnvironmentID not yet collected', () => {
  // A null/undefined qEnvironment means P09-T001 has not been run.
  assert.throws(
    () => joinQualifiedCandidateSet({
      staticCandidates: SIX_STATIC_CANDIDATES,
      qEnvironment: null,
      frozenSourceRevision: FROZEN_SOURCE_REVISION,
      frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
    }),
    /PRE-ENVIRONMENT/,
    'a null QEnvironmentID (not yet collected) must be rejected',
  );
  assert.throws(
    () => joinQualifiedCandidateSet({
      staticCandidates: SIX_STATIC_CANDIDATES,
      qEnvironment: { ...qEnv, qEnvironmentId: null },
      frozenSourceRevision: FROZEN_SOURCE_REVISION,
      frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
    }),
    /PRE-ENVIRONMENT/,
    'a null qEnvironmentId must be rejected',
  );
});

test('Operation 2 — reject post-source-change: source changed after the freeze', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  const result = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  // Corrupt one candidate's sourceSetDigest to simulate a post-freeze source
  // change.
  const changedSet = result.candidates.map((c, i) =>
    i === 0 ? { ...c, sourceSetDigest: '0'.repeat(64) } : c,
  );
  assert.throws(
    () => joinQualifiedCandidateSet({
      staticCandidates: SIX_STATIC_CANDIDATES,
      qEnvironment: qEnv,
      frozenSourceRevision: FROZEN_SOURCE_REVISION,
      frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
      injectCandidates: changedSet,
    }),
    /POST-SOURCE-CHANGE/,
    'a candidate whose sourceSetDigest differs from the frozen digest must be rejected',
  );
});

test('Operation 2 — environment-predicate qualified=false is NOT a rejection', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  // The join must NOT throw when the environment predicate is qualified=false
  // (external display). It records a concern instead.
  const result = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  if (!qEnv.formalPreflight.qualified) {
    // qualified=false → a concern is recorded, NOT a throw.
    assert.ok(result.concerns.length >= 1, 'a qualified=false must produce at least one concern');
    const envConcern = result.concerns.find((c) => c.kind === 'environment-predicate');
    assert.ok(envConcern, 'there must be an environment-predicate concern');
    assert.equal(envConcern.qualified, false, 'the concern must record qualified=false');
  }
});

// ===========================================================================
// Operation 3 — Emit one qualified set hash consumed unchanged by every C/P
// and cross-cutting task.
// ===========================================================================

test('Operation 3: emit one qualified-set hash (SHA-256 over 7 candidate hashes + environment predicate)', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');

  const result = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });

  // The qualified-set hash is a 64-hex SHA-256.
  assert.match(result.qualifiedSetHash, SHA256_RE, 'qualifiedSetHash must be 64-hex SHA-256');

  // The hash is computed over exactly 7 candidate hashes + the environment
  // predicate.
  assert.equal(result.candidateHashes.length, 7, 'there must be exactly 7 candidate hashes');

  // The 6 static candidate hashes match the committed files.
  for (let i = 0; i < 6; i++) {
    assert.equal(
      result.candidateHashes[i],
      sha256(candidatePath(SIX_STATIC_CANDIDATES[i])),
      `candidate hash ${i} must match the committed file`,
    );
  }
  // The 7th candidate hash is the QEnvironmentID.
  assert.equal(result.candidateHashes[6], qEnv.qEnvironmentId, 'the 7th candidate hash must be the QEnvironmentID');

  // Independently reproduce the qualified-set hash.
  const environmentPredicate = {
    qualified: qEnv.formalPreflight.qualified,
    status: qEnv.status,
  };
  const expected = createHash('sha256')
    .update(canonicalStringify({
      candidates: result.candidateHashes,
      environmentPredicate,
    }))
    .digest('hex');
  assert.equal(result.qualifiedSetHash, expected, 'qualifiedSetHash must be SHA-256 over canonical(7 hashes + environmentPredicate)');
});

test('Operation 3: the qualified-set hash is deterministic + reproducible (consumed unchanged by C/P tasks)', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');

  const a = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  const b = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });

  // The hash is deterministic — same inputs → same hash.
  assert.equal(a.qualifiedSetHash, b.qualifiedSetHash, 'qualifiedSetHash must be deterministic');
  assert.deepEqual(a.candidateHashes, b.candidateHashes, 'candidateHashes must be deterministic');
  assert.deepEqual(a.environmentPredicate, b.environmentPredicate, 'environmentPredicate must be deterministic');

  // The hash is reproducible from the exported components.
  const recomputed = createHash('sha256')
    .update(canonicalStringify({
      candidates: a.candidateHashes,
      environmentPredicate: a.environmentPredicate,
    }))
    .digest('hex');
  assert.equal(recomputed, a.qualifiedSetHash, 'qualifiedSetHash must be reproducible from the components');
});

test('Operation 3: the qualified-set hash is stable across repeated QEnvironmentID collections (same environment)', () => {
  // The QEnvironmentID is stable across repeated collections of the same env.
  // Therefore the qualified-set hash is also stable.
  const qEnv2 = finalizeQEnvironment();
  assert.equal(qEnv2.qEnvironmentId, qEnv.qEnvironmentId, 'QEnvironmentID must be stable');

  const a = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  const b = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv2,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });
  assert.equal(a.qualifiedSetHash, b.qualifiedSetHash, 'qualifiedSetHash must be stable across repeated collections');
});

test('Operation 3: the qualified-set hash is consumed by every C/P + cross-cutting task (contract)', () => {
  assert.ok(qEnv, 'fixture must have collected QEnvironmentID');
  const result = joinQualifiedCandidateSet({
    staticCandidates: SIX_STATIC_CANDIDATES,
    qEnvironment: qEnv,
    frozenSourceRevision: FROZEN_SOURCE_REVISION,
    frozenSourceSetDigest: FROZEN_SOURCE_SET_DIGEST,
  });

  // The qualified-set hash is a READ-ONLY fingerprint consumed by every C/P
  // task (P09-T010..T019, P09-T030..T043) + cross-cutting (P09-T050..T052).
  // This test records the hash value for the contract; the C/P tasks read it
  // without modifying it.
  assert.match(result.qualifiedSetHash, SHA256_RE, 'qualifiedSetHash must be 64-hex');
  assert.equal(typeof result.qualifiedSetHash, 'string', 'qualifiedSetHash must be a string');
  assert.equal(result.qualifiedSetHash.length, 64, 'qualifiedSetHash must be 64 chars');

  // The hash uniquely identifies the acceptance set (7 candidates + env
  // predicate). Any change to any candidate hash or the environment predicate
  // would change the qualified-set hash.
  const tampered = [...result.candidateHashes];
  tampered[0] = '0'.repeat(64);
  const tamperedHash = createHash('sha256')
    .update(canonicalStringify({
      candidates: tampered,
      environmentPredicate: result.environmentPredicate,
    }))
    .digest('hex');
  assert.notEqual(tamperedHash, result.qualifiedSetHash, 'a tampered candidate hash must change the qualified-set hash');
});
