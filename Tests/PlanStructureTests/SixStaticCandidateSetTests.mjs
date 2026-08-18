// Tests/PlanStructureTests/SixStaticCandidateSetTests.mjs
//
// P08-T016 — Validate the exact six-static-candidate release set.
//
// This is the release-set validation gate — the LAST Phase 08 task. It is
// TEST-ONLY: productTarget=null, create=none, modify=none. It validates the
// exact 6 static candidates that form the Phase 08 release set.
//
// The 6 static candidates:
//
//   1. native-declaration  (P08-T010)
//   2. regExpUnicode       (P08-T011)
//   3. environment          (P08-T012)
//   4. sourceClosure       (P08-T013)
//   5. cache               (P08-T014)
//   6. distribution        (P08-T015 — joins the 5 + records release artifacts)
//
// QEnvironmentID is EXCLUDED — it is recollected per formal Phase 09 run, not
// static.
//
// The three implementation operations this suite VERIFIES:
//
//   1. Require exactly the six static candidate names with no duplicate or
//      extra artifact.
//   2. Verify schema, source revision, dependency edges, internal hashes,
//      release hash, and mutual references.
//   3. Exclude QEnvironmentID because it is recollected per formal Phase 09
//      run.
//
// Contract gates (from the G6-R plan leaf P08-T016):
//
//   RED  : node --test <this file>
//          expectedExit=1 (validation logic not yet authored / compilation)
//
//   GREEN: node --test <this file>
//          expectedExit=0 — all six-candidate verifications pass.
//
// The API is FROZEN (P07-T011). This suite validates the committed artifacts
// that Phase 09 acceptance reads without re-running any finalizer.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

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
// The exact six static candidates. These are the verbatim names and the
// committed manifest artifact paths. QEnvironmentID is NOT in this set.
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

const EXPECTED_NAMES = [
  'native-declaration',
  'regExpUnicode',
  'environment',
  'sourceClosure',
  'cache',
  'distribution',
];

const SHA256_RE = /^[0-9a-f]{64}$/;

// The frozen source revision all 6 candidates must reference.
const FROZEN_SOURCE_REVISION = 'P07-T011';
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
  const raw = readRaw(c);
  return JSON.parse(raw);
}

// Try to parse a candidate. Returns { ok, obj, error }.
function tryParse(c) {
  try {
    return { ok: true, obj: loadCandidate(c), error: null };
  } catch (e) {
    return { ok: false, obj: null, error: e instanceof Error ? e.message : String(e) };
  }
}

// ===========================================================================
// Operation 1 — Require exactly the six static candidate names with no
// duplicate or extra artifact.
// ===========================================================================

test('Operation 1: exactly six static candidates — count, names, no duplicates, no extras', () => {
  // Exactly 6 candidates.
  assert.equal(
    SIX_STATIC_CANDIDATES.length,
    6,
    'the release set must contain exactly 6 static candidates',
  );

  // Names match the spec verbatim.
  const names = SIX_STATIC_CANDIDATES.map((c) => c.name);
  assert.deepEqual(
    names,
    EXPECTED_NAMES,
    'candidate names must match the exact six from the spec',
  );

  // No duplicate names.
  const nameSet = new Set(names);
  assert.equal(
    nameSet.size,
    6,
    'there must be no duplicate candidate names',
  );

  // No duplicate leaf IDs.
  const leaves = SIX_STATIC_CANDIDATES.map((c) => c.leaf);
  assert.equal(
    new Set(leaves).size,
    6,
    'there must be no duplicate leaf IDs',
  );

  // No duplicate artifact files.
  const files = SIX_STATIC_CANDIDATES.map((c) => c.file);
  assert.equal(
    new Set(files).size,
    6,
    'there must be no duplicate artifact files',
  );

  // Every artifact file exists at its committed path.
  for (const c of SIX_STATIC_CANDIDATES) {
    const p = candidatePath(c);
    assert.equal(
      existsSync(p),
      true,
      `candidate artifact must exist: ${c.file}`,
    );
  }

  // No extra P08-T01x candidate manifest files in the artifacts directory.
  const artifactFiles = readdirSync(ARTIFACTS_DIR).filter(
    (f) => /^monacode-p08-t01[0-9]+-.*-manifest\.json$/.test(f),
  );
  const expectedFiles = new Set(files);
  for (const f of artifactFiles) {
    assert.ok(
      expectedFiles.has(f),
      `unexpected extra P08 candidate manifest: ${f}`,
    );
  }
});

// ===========================================================================
// Operation 2 — schema: each candidate's manifest JSON schema is valid.
// Each manifest must be valid JSON (JSON.parse succeeds) with
// schemaVersion === 1.
// ===========================================================================

test('Operation 2 — schema: each candidate manifest is valid JSON with schemaVersion=1', () => {
  for (const c of SIX_STATIC_CANDIDATES) {
    const { ok, obj, error } = tryParse(c);
    assert.ok(
      ok,
      `P08-T016 schema defect in ${c.leaf} (${c.name}): ` +
        `candidate manifest is not valid JSON — ${error}. ` +
        `This is a defect in the prior task ${c.leaf}, not a test-authoring error.`,
    );
    assert.equal(
      obj.schemaVersion,
      1,
      `${c.leaf} (${c.name}) schemaVersion must be 1`,
    );
  }
});

// ===========================================================================
// Operation 2 — identity: each candidate is frozen + final with the correct
// baseline and revision.
// ===========================================================================

test('Operation 2 — identity: each candidate is frozen, final, with correct baseline + revision', () => {
  for (const c of SIX_STATIC_CANDIDATES) {
    const { ok, obj, error } = tryParse(c);
    if (!ok) {
      // T012 schema defect is reported in the schema test; skip here to
      // avoid masking the primary failure.
      continue;
    }
    assert.equal(
      obj.identity.baseline,
      'monaco-editor@0.56.0',
      `${c.leaf} baseline must be monaco-editor@0.56.0`,
    );
    assert.equal(obj.identity.frozen, true, `${c.leaf} must be frozen`);
    assert.equal(obj.identity.final, true, `${c.leaf} must be final`);
    assert.equal(
      obj.identity.product,
      'MonaCode',
      `${c.leaf} product must be MonaCode`,
    );
    assert.equal(
      obj.identity.revision,
      c.revision,
      `${c.leaf} revision must be ${c.revision}`,
    );
    assert.equal(
      obj.identity.provisional,
      undefined,
      `${c.leaf} must not be provisional`,
    );
  }
});

// ===========================================================================
// Operation 2 — source revision: all 6 candidates reference the same frozen
// source revision P07-T011. For T010-T014 this is via frozenApiClosure or
// sourceArtifacts; for T015 it is via frozenApiClosure AND joinedCandidates.
// For T012 (unparseable) we verify the raw text contains the P07-T011
// references.
// ===========================================================================

test('Operation 2 — source revision: all candidates reference frozen P07-T011', () => {
  const p07Hash = sha256(FROZEN_API_CLOSURE_PATH);

  for (const c of SIX_STATIC_CANDIDATES) {
    const { ok, obj } = tryParse(c);

    if (ok) {
      // Parseable candidate: verify frozenApiClosure or sourceArtifacts
      // references P07-T011.
      const fac = obj.frozenApiClosure;
      if (fac) {
        assert.equal(
          fac.frozenAt,
          FROZEN_SOURCE_REVISION,
          `${c.leaf} frozenApiClosure.frozenAt must be P07-T011`,
        );
        assert.equal(
          fac.sourceSetDigest,
          FROZEN_SOURCE_SET_DIGEST,
          `${c.leaf} frozenApiClosure.sourceSetDigest must match`,
        );
      }
      // sourceArtifacts must include the P07-T011 manifest with the correct
      // hash.
      const sa = obj.sourceArtifacts || {};
      const p07Key = Object.keys(sa).find((k) =>
        k.includes('monacode-p07-t011-public-api-closure-manifest'),
      );
      assert.ok(
        p07Key,
        `${c.leaf} sourceArtifacts must reference the P07-T011 manifest`,
      );
      assert.equal(
        sa[p07Key],
        p07Hash,
        `${c.leaf} P07-T011 manifest hash must match the actual file`,
      );
    } else {
      // Unparseable candidate (T012): verify raw text contains the P07-T011
      // references. The schema defect is reported in the schema test.
      const raw = readRaw(c);
      assert.ok(
        raw.includes('P07-T011'),
        `${c.leaf} must reference P07-T011 in raw text`,
      );
      assert.ok(
        raw.includes(p07Hash),
        `${c.leaf} must contain the P07-T011 manifest hash`,
      );
      assert.ok(
        raw.includes(FROZEN_SOURCE_SET_DIGEST),
        `${c.leaf} must contain the P07-T011 sourceSetDigest`,
      );
    }
  }

  // T015 (distribution) must also record sourceRevision=P07-T011 for every
  // joined candidate.
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);
  assert.ok(
    Array.isArray(t015.joinedCandidates),
    'distribution manifest must have joinedCandidates',
  );
  for (const jc of t015.joinedCandidates) {
    assert.equal(
      jc.sourceRevision,
      FROZEN_SOURCE_REVISION,
      `joined candidate ${jc.leaf} sourceRevision must be P07-T011`,
    );
  }
});

// ===========================================================================
// Operation 2 — dependency edges: the distribution manifest (T015) depends on
// the 5 preceding candidates (T010-T014). The 5 candidates do not depend on
// each other (they are independent static candidates).
// ===========================================================================

test('Operation 2 — dependency edges: distribution depends on the five preceding candidates', () => {
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);
  const joined = t015.joinedCandidates;

  // Exactly 5 joined candidates.
  assert.equal(
    joined.length,
    5,
    'distribution must join exactly 5 preceding candidates',
  );

  // The 5 joined candidates are T010-T014 (not T015, not QEnvironmentID).
  const joinedLeaves = joined.map((c) => c.leaf).sort();
  const expectedLeaves = SIX_STATIC_CANDIDATES.slice(0, 5)
    .map((c) => c.leaf)
    .sort();
  assert.deepEqual(
    joinedLeaves,
    expectedLeaves,
    'joined candidates must be exactly T010-T014',
  );

  // T015 is NOT in the joinedCandidates (it does not join itself).
  assert.ok(
    !joined.some((c) => c.leaf === 'P08-T015'),
    'distribution must not join itself',
  );

  // QEnvironmentID is NOT in the joinedCandidates.
  assert.ok(
    !joined.some((c) => c.leaf && c.leaf.includes('QEnvironment')),
    'QEnvironmentID must not be in the joined candidates',
  );

  // Each joined candidate is final + frozen.
  for (const jc of joined) {
    assert.equal(jc.final, true, `joined ${jc.leaf} must be final`);
    assert.equal(jc.frozen, true, `joined ${jc.leaf} must be frozen`);
  }
});

// ===========================================================================
// Operation 2 — internal hashes: each candidate's recorded SHA-256 values
// match the committed files. We verify:
//   (a) each candidate's own file hash matches what T015 records
//   (b) the P07-T011 manifest hash is consistent across all candidates
//   (c) the phase-08 implementation plan hash is consistent
//   (d) a spot-check of sourceArtifacts entries that point to committed files
// ===========================================================================

test('Operation 2 — internal hashes: recorded hashes match committed files', () => {
  const p07Hash = sha256(FROZEN_API_CLOSURE_PATH);
  const planHash = sha256(IMPLEMENTATION_PLAN_PATH);

  // Load T015 to get the recorded hashes for the 5 joined candidates.
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);

  // (a) Each of the 5 candidates' own file hash matches T015's record.
  for (const c of SIX_STATIC_CANDIDATES.slice(0, 5)) {
    const actualHash = sha256(candidatePath(c));
    const jc = t015.joinedCandidates.find((j) => j.leaf === c.leaf);
    assert.ok(jc, `T015 must record a joinedCandidate entry for ${c.leaf}`);
    assert.equal(
      jc.sha256,
      actualHash,
      `${c.leaf} file hash must match T015 joinedCandidates record`,
    );
    assert.match(jc.sha256, SHA256_RE, `${c.leaf} sha256 must be 64-hex`);
  }

  // (a) T015's own sourceArtifacts must include all 5 candidate paths with
  // correct hashes.
  const sa = t015.sourceArtifacts;
  for (const c of SIX_STATIC_CANDIDATES.slice(0, 5)) {
    const key = `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/${c.file}`;
    assert.ok(
      key in sa,
      `T015 sourceArtifacts must include ${c.file}`,
    );
    assert.equal(
      sa[key],
      sha256(candidatePath(c)),
      `T015 sourceArtifacts hash for ${c.file} must match the actual file`,
    );
  }

  // (b) The P07-T011 manifest hash is consistent across all candidates that
  // reference it (via sourceArtifacts).
  for (const c of SIX_STATIC_CANDIDATES) {
    const { ok, obj } = tryParse(c);
    if (!ok) continue; // T012 schema defect reported in schema test
    const csa = obj.sourceArtifacts || {};
    const p07Key = Object.keys(csa).find((k) =>
      k.includes('monacode-p07-t011-public-api-closure-manifest'),
    );
    if (p07Key) {
      assert.equal(
        csa[p07Key],
        p07Hash,
        `${c.leaf} P07-T011 manifest hash must match the actual file`,
      );
    }
  }

  // (c) The phase-08 plan hash is consistent in T015's sourceArtifacts.
  const planKey = Object.keys(sa).find((k) =>
    k.includes('phase-08-release-candidate-distribution.md'),
  );
  assert.ok(planKey, 'T015 sourceArtifacts must include the phase-08 plan');
  assert.equal(
    sa[planKey],
    planHash,
    'T015 phase-08 plan hash must match the actual file',
  );

  // (d) Spot-check: verify a sample of sourceArtifacts entries that point to
  // committed files (Sources/ and docs/) for each parseable candidate.
  for (const c of SIX_STATIC_CANDIDATES) {
    const { ok, obj } = tryParse(c);
    if (!ok) continue; // T012 schema defect reported in schema test
    const csa = obj.sourceArtifacts || {};
    let checked = 0;
    for (const [key, hash] of Object.entries(csa)) {
      // Only check files that exist on disk (committed files).
      const fullPath = key.startsWith('/')
        ? key
        : join(REPO_ROOT, key);
      if (existsSync(fullPath) && !key.includes('.build/')) {
        assert.equal(
          sha256(fullPath),
          hash,
          `${c.leaf} sourceArtifacts hash for ${key} must match`,
        );
        checked++;
      }
      if (checked >= 3) break; // spot-check at least 3 per candidate
    }
    assert.ok(
      checked >= 1,
      `${c.leaf} must have at least 1 verifiable sourceArtifacts entry`,
    );
  }
});

// ===========================================================================
// Operation 2 — release hash: the distribution manifest (T015) records the
// release build hash and every release artifact's SHA-256.
// ===========================================================================

test('Operation 2 — release hash: distribution records release build + artifact hashes', () => {
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);

  // releaseBuild metadata.
  assert.ok(t015.releaseBuild, 'distribution must record releaseBuild');
  assert.equal(
    t015.releaseBuild.present,
    true,
    'release build must be present',
  );
  assert.equal(
    t015.releaseBuild.reproducible,
    true,
    'release build must be reproducible',
  );
  assert.match(
    t015.releaseBuild.freezeCommit,
    /^[0-9a-f]{40}$/,
    'release build freeze commit must be 40-hex',
  );
  assert.match(
    t015.releaseBuild.sourceCommit,
    /^[0-9a-f]{40}$/,
    'release build source commit must be 40-hex',
  );

  // releaseArtifacts: exactly 4 (3 product modules + 1 sample executable).
  assert.equal(
    t015.releaseArtifacts.length,
    4,
    'distribution must record exactly 4 release artifacts',
  );

  const artifactIds = t015.releaseArtifacts.map((a) => a.id).sort();
  assert.deepEqual(
    artifactIds,
    [
      'MonaCode-module',
      'MonaCodeAppKit-module',
      'MonaCodeSwiftUI-module',
      'sample-macOS-host',
    ].sort(),
    'release artifact IDs must match the 3 modules + sample executable',
  );

  // Every release artifact has a 64-hex sha256.
  for (const ra of t015.releaseArtifacts) {
    assert.match(ra.sha256, SHA256_RE, `${ra.id} sha256 must be 64-hex`);
    assert.ok(ra.bytes > 0, `${ra.id} bytes must be positive`);
  }

  // The release executable exists on disk (if the build is present).
  if (t015.releaseBuild.executable) {
    assert.equal(
      existsSync(t015.releaseBuild.executable),
      true,
      'release build executable must exist at the recorded path',
    );
  }
});

// ===========================================================================
// Operation 2 — mutual references: the distribution manifest (T015)
// references the 5 candidates (via joinedCandidates + sourceArtifacts), and
// the 5 candidates are referenced by T015. Each cross-reference's hash must
// agree.
// ===========================================================================

test('Operation 2 — mutual references: distribution references the five and hashes agree', () => {
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);
  const joined = t015.joinedCandidates;

  // T015 references all 5 via joinedCandidates.
  assert.equal(joined.length, 5, 'T015 joinedCandidates must have 5 entries');

  // Each joinedCandidate entry records the path, revision, sha256, and
  // sourceRevision.
  for (const jc of joined) {
    assert.ok(jc.path, `joined ${jc.leaf} must record path`);
    assert.ok(jc.revision, `joined ${jc.leaf} must record revision`);
    assert.match(jc.sha256, SHA256_RE, `joined ${jc.leaf} sha256 must be 64-hex`);
    assert.equal(
      jc.sourceRevision,
      FROZEN_SOURCE_REVISION,
      `joined ${jc.leaf} sourceRevision must be P07-T011`,
    );

    // The recorded path must point to the actual candidate artifact.
    assert.equal(
      existsSync(jc.path),
      true,
      `joined ${jc.leaf} path must exist: ${jc.path}`,
    );

    // The recorded sha256 must match the actual file's hash.
    const actualHash = sha256(jc.path);
    assert.equal(
      jc.sha256,
      actualHash,
      `joined ${jc.leaf} sha256 must match the actual file hash`,
    );

    // The recorded revision must match the candidate's own identity.revision.
    const { ok, obj } = tryParse({
      file: jc.path.split('/').pop(),
    });
    if (ok) {
      assert.equal(
        obj.identity.revision,
        jc.revision,
        `joined ${jc.leaf} revision must match the candidate's identity.revision`,
      );
    }
  }

  // T015's sourceArtifacts also includes all 5 candidate manifest paths with
  // correct hashes.
  const sa = t015.sourceArtifacts;
  for (const c of SIX_STATIC_CANDIDATES.slice(0, 5)) {
    const key = `docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/${c.file}`;
    assert.ok(key in sa, `T015 sourceArtifacts must include ${c.file}`);
    assert.equal(
      sa[key],
      sha256(candidatePath(c)),
      `T015 sourceArtifacts hash for ${c.file} must match`,
    );
  }

  // The 5 candidates do NOT reference each other (they are independent static
  // candidates — only T015 joins them).
  for (const c of SIX_STATIC_CANDIDATES.slice(0, 5)) {
    const { ok, obj } = tryParse(c);
    if (!ok) continue; // T012 schema defect reported in schema test
    assert.equal(
      obj.joinedCandidates,
      undefined,
      `${c.leaf} must not have joinedCandidates (only distribution joins)`,
    );
  }
});

// ===========================================================================
// Operation 3 — Exclude QEnvironmentID because it is recollected per formal
// Phase 09 run.
// ===========================================================================

test('Operation 3: QEnvironmentID is excluded from the static release set', () => {
  // QEnvironmentID is NOT one of the 6 static candidate names.
  const names = SIX_STATIC_CANDIDATES.map((c) => c.name);
  assert.ok(
    !names.includes('QEnvironmentID'),
    'QEnvironmentID must not be in the 6 static candidate names',
  );

  // QEnvironmentID is NOT one of the 6 static candidate leaf IDs.
  const leaves = SIX_STATIC_CANDIDATES.map((c) => c.leaf);
  assert.ok(
    !leaves.some((l) => l.includes('QEnvironment')),
    'QEnvironmentID must not be in the 6 static candidate leaf IDs',
  );

  // No QEnvironmentID manifest file exists in the static artifact set.
  const artifactFiles = readdirSync(ARTIFACTS_DIR);
  const qEnvFiles = artifactFiles.filter((f) =>
    /qenvironment|q-environment/i.test(f),
  );
  assert.deepEqual(
    qEnvFiles,
    [],
    'no QEnvironmentID manifest may exist in the static artifact set',
  );

  // T015's joinedCandidates does NOT include QEnvironmentID.
  const t015 = loadCandidate(SIX_STATIC_CANDIDATES[5]);
  assert.ok(
    !t015.joinedCandidates.some((c) =>
      c.leaf ? c.leaf.includes('QEnvironment') : false,
    ),
    'T015 joinedCandidates must not include QEnvironmentID',
  );

  // T015's joinedCandidates has exactly 5 entries (not 6) — QEnvironmentID
  // is the absent 6th because it is recollected per Phase 09 run.
  assert.equal(
    t015.joinedCandidates.length,
    5,
    'T015 must join exactly 5 candidates (QEnvironmentID excluded)',
  );
});
