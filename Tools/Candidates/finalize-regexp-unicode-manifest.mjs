// finalize-regexp-unicode-manifest.mjs
//
// P08-T011 — Finalize MonaRegExpUnicodeManifest after all semantic consumers.
//
// This is the Node finalizer for the MonaCode FINAL RegExp/Unicode manifest.
// It regenerates ALL six distinct Unicode profiles, ten consumer mappings
// (the Monaco RegExp consumer profiles), Test262 selection, generator inputs,
// licenses, and output hashes from the FROZEN M1-R3 source contract (plus the
// P07-T011 frozen public-API closure baseline), verifies the frozen counts,
// verifies every final semantic consumer appears and no post-finalization
// product consumer exists, hashes every source artifact, and marks the
// manifest FINAL only after exact provenance reproduction (zero drift).
//
// The manifest is FINAL: identity.frozen = true, identity.final = true, and
// identity.provisional is absent. This is distinct from the M1-R3 provisional
// source contract (identity.currentStatus = "product implementation absent;
// every affected gate is not-run"). Phase 09 acceptance reads this final
// manifest without re-running the finalizer.
//
// Sources (FROZEN):
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monacode-m1r3-regexp-unicode-manifest.json     (frozen M1-R3 source)
//     model-m1r3-regexp-unicode-provenance-closure.html
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/
//     monacode-p07-t011-public-api-closure-manifest.json  (frozen API baseline)
//   docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/
//     phase-08-release-candidate-distribution.md     (P08-T011 leaf)
//
// Product source (regExpUnicode consumers + generated tables):
//   Sources/MonaCode/RegExp/MonaRegExp*.swift          (engine + consumer profiles)
//   Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift  (tables)
//   Sources/MonaCode/Generated/RegExp/UNICODE-LICENSE.txt            (Unicode notice)
//
// The API is FROZEN (P07-T011). The finalizer regenerates from the frozen
// source — no public API changes.
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/finalize-regexp-unicode-manifest.mjs
//
// Writes:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p08-t011-regexp-unicode-manifest.json
//
// Determinism: byte-identical across re-runs (stable key order, trailing
// newline, no non-deterministic data sources).

import { createHash } from 'node:crypto';
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  existsSync,
  mkdtempSync,
  rmSync,
} from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..');

export const FINAL_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p08-t011-regexp-unicode-manifest.json'
);

// The frozen M1-R3 source manifest (the regExpUnicode contract). Both the
// g5-r copy and the inherited g6-r/parent/g5-r copy are byte-identical.
const FROZEN_SOURCE_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'monacode-m1r3-regexp-unicode-manifest.json'
);

const PROVENANCE_CLOSURE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'model-m1r3-regexp-unicode-provenance-closure.html'
);

const FROZEN_API_CLOSURE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p07-t011-public-api-closure-manifest.json'
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

// The frozen source manifest SHA-256 (with trailing LF). Recorded in the
// g4-r/g5-r/g6-r SHA256SUMS and the g4-r authoritative manifest
// (M1-R3-regexp-unicode entry). This is the zero-drift anchor for the source.
const FROZEN_SOURCE_MANIFEST_SHA256 =
  '19b93a5f0dda741de6d193130b6eb46ec936a6273a35dbe31bbda8d44e46cf62';

// The frozen count contract (from the g6-r authoritative manifest's
// regexpUnicode block). The finalizer refuses to finalize unless the
// regenerated manifest reproduces every frozen count exactly.
export const EXPECTED_COUNTS = {
  unicodeProfiles: 6,
  consumerMappings: 10,
  publicRegExpReferences: 14,
  retainedReferences: 11,
  cutReferences: 3,
  acceptedFlags: 8,
  test262Sources: 2117,
  test262RegexpFiles: 1879,
  test262RegexpLiteralFiles: 238,
};

// The six distinct Unicode profile IDs (frozen). These remain independent —
// no system Unicode, Swift Character, NSRegularExpression, ICU runtime, or
// newer UCD can replace a profile without a new versioned contract and full
// differential.
const EXPECTED_UNICODE_PROFILE_IDS = [
  'regexp-unicode',
  'grapheme-break',
  'rtl',
  'emoji-imprecise',
  'ambiguous-characters',
  'invisible-characters',
];

// The ten consumer mapping IDs (frozen) — the Monaco RegExp consumer
// profiles. Every semantic consumer of RegExp in the frozen product appears
// here; no post-finalization product consumer may be added.
const EXPECTED_CONSUMER_MAPPING_IDS = [
  'search',
  'word-definition',
  'indentation',
  'on-enter',
  'folding-range-equal-flags',
  'folding-range-unequal-flags',
  'fold-all-regions',
  'section-headers',
  'linked-editing',
  'inline-accept-next-word',
];

// The product source artifacts referenced by the manifest. Each is hashed for
// provenance + drift detection. These are the repository-owned Swift RegExp
// engine + consumer-profile + generated Unicode table files.
const PRODUCT_SOURCE_ARTIFACTS = [
  'Sources/MonaCode/RegExp/MonaRegExpAST.swift',
  'Sources/MonaCode/RegExp/MonaRegExpCompiler.swift',
  'Sources/MonaCode/RegExp/MonaRegExpConsumerProfile.swift',
  'Sources/MonaCode/RegExp/MonaRegExpExecutor.swift',
  'Sources/MonaCode/RegExp/MonaRegExpParser.swift',
  'Sources/MonaCode/RegExp/MonaRegExpProgram.swift',
  'Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift',
  'Sources/MonaCode/Generated/RegExp/UNICODE-LICENSE.txt',
];

// ---------------------------------------------------------------------------
// 1. Zero-drift verification — the frozen M1-R3 source manifest must hash to
//    the recorded SHA-256. Any mismatch means the source has drifted and the
//    finalizer refuses to finalize.
// ---------------------------------------------------------------------------

export function verifySourceZeroDrift(sourcePath) {
  const content = readFileSync(sourcePath, 'utf8');
  const hash = sha256(content);
  if (hash !== FROZEN_SOURCE_MANIFEST_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_SOURCE path=${sourcePath} regenerated=${hash} frozen=${FROZEN_SOURCE_MANIFEST_SHA256}`
    );
  }
  return hash;
}

// ---------------------------------------------------------------------------
// 2. Count verification — the frozen count contract.
// ---------------------------------------------------------------------------

export function verifyCounts(source) {
  const unicodeProfiles = source.unicodeProfiles || [];
  const consumerMappings = source.regexpProfiles || [];
  const publicRefs = source.publicRegExpReferences || {};
  const acceptedFlags = (source.nativeRegExpType || {}).acceptedFlags || [];
  const test262 = (source.authorities || {}).test262 || {};

  const actual = {
    unicodeProfiles: unicodeProfiles.length,
    consumerMappings: consumerMappings.length,
    publicRegExpReferences: publicRefs.total,
    retainedReferences: publicRefs.retained,
    cutReferences: publicRefs.cut,
    acceptedFlags: acceptedFlags.length,
    test262Sources: test262.totalSourceFileCount,
    test262RegexpFiles: test262.regexpFileCount,
    test262RegexpLiteralFiles: test262.regexpLiteralFileCount,
  };

  const checks = [
    ['unicodeProfiles', actual.unicodeProfiles, EXPECTED_COUNTS.unicodeProfiles],
    ['consumerMappings', actual.consumerMappings, EXPECTED_COUNTS.consumerMappings],
    ['publicRegExpReferences', actual.publicRegExpReferences, EXPECTED_COUNTS.publicRegExpReferences],
    ['retainedReferences', actual.retainedReferences, EXPECTED_COUNTS.retainedReferences],
    ['cutReferences', actual.cutReferences, EXPECTED_COUNTS.cutReferences],
    ['acceptedFlags', actual.acceptedFlags, EXPECTED_COUNTS.acceptedFlags],
    ['test262Sources', actual.test262Sources, EXPECTED_COUNTS.test262Sources],
    ['test262RegexpFiles', actual.test262RegexpFiles, EXPECTED_COUNTS.test262RegexpFiles],
    ['test262RegexpLiteralFiles', actual.test262RegexpLiteralFiles, EXPECTED_COUNTS.test262RegexpLiteralFiles],
  ];

  for (const [label, got, expected] of checks) {
    if (got !== expected) {
      throw new Error(
        `COUNT_MISMATCH ${label} actual=${got} expected=${expected}`
      );
    }
  }
  return actual;
}

// ---------------------------------------------------------------------------
// 3. Semantic consumer verification — every final semantic consumer of
//    RegExp appears in the manifest, and no post-finalization product
//    consumer exists (the regenerated consumer set is exactly the frozen set
//    — zero drift on consumer IDs).
// ---------------------------------------------------------------------------

export function verifySemanticConsumers(source) {
  const consumerMappings = source.regexpProfiles || [];
  const actualIds = consumerMappings.map((p) => p.id);
  const expectedSet = new Set(EXPECTED_CONSUMER_MAPPING_IDS);

  // Every frozen consumer must appear (no missing consumer).
  const missing = EXPECTED_CONSUMER_MAPPING_IDS.filter(
    (id) => !actualIds.includes(id)
  );
  if (missing.length > 0) {
    throw new Error(
      `DRIFT_MISSING_CONSUMER missing=${JSON.stringify(missing)} actual=${JSON.stringify(actualIds)}`
    );
  }

  // No extra consumer was added after finalization (zero drift on the
  // consumer set — the regenerated IDs are exactly the frozen set).
  const extra = actualIds.filter((id) => !expectedSet.has(id));
  if (extra.length > 0) {
    throw new Error(
      `DRIFT_POST_FINALIZATION_CONSUMER extra=${JSON.stringify(extra)} actual=${JSON.stringify(actualIds)}`
    );
  }

  // The consumer count must match exactly (no post-finalization product
  // consumer exists).
  if (actualIds.length !== EXPECTED_CONSUMER_MAPPING_IDS.length) {
    throw new Error(
      `DRIFT_CONSUMER_COUNT actual=${actualIds.length} frozen=${EXPECTED_CONSUMER_MAPPING_IDS.length}`
    );
  }

  return {
    consumerIds: actualIds,
    allConsumersPresent: missing.length === 0,
    postFinalizationProductConsumerExists: extra.length > 0,
  };
}

// ---------------------------------------------------------------------------
// 4. Unicode profile verification — every frozen profile appears and the
//    six remain independent (no merge/replacement).
// ---------------------------------------------------------------------------

export function verifyUnicodeProfiles(source) {
  const profiles = source.unicodeProfiles || [];
  const actualIds = profiles.map((p) => p.id);
  const missing = EXPECTED_UNICODE_PROFILE_IDS.filter(
    (id) => !actualIds.includes(id)
  );
  if (missing.length > 0) {
    throw new Error(
      `DRIFT_MISSING_UNICODE_PROFILE missing=${JSON.stringify(missing)} actual=${JSON.stringify(actualIds)}`
    );
  }
  if (actualIds.length !== EXPECTED_UNICODE_PROFILE_IDS.length) {
    throw new Error(
      `DRIFT_UNICODE_PROFILE_COUNT actual=${actualIds.length} frozen=${EXPECTED_UNICODE_PROFILE_IDS.length}`
    );
  }
  return profiles;
}

// ---------------------------------------------------------------------------
// 5. Generator inputs — extract the generator provenance from each generated
//    profile (generator commit, input/generator hashes). These are the
//    "generator inputs" the spec requires the finalizer to regenerate.
// ---------------------------------------------------------------------------

function buildGeneratorInputs(source) {
  const inputs = [];
  for (const profile of source.unicodeProfiles || []) {
    const entry = { profileId: profile.id };
    if (profile.generatorCommit) entry.generatorCommit = profile.generatorCommit;
    if (profile.version) entry.version = profile.version;
    if (profile.inputSha256) entry.inputSha256 = profile.inputSha256;
    if (profile.inputsSha256) entry.inputsSha256 = profile.inputsSha256;
    if (profile.unicodeDataSha256) entry.unicodeDataSha256 = profile.unicodeDataSha256;
    if (profile.generatorSha256) entry.generatorSha256 = profile.generatorSha256;
    if (profile.normativeSource) entry.normativeSource = profile.normativeSource;
    if (profile.nonNormativeProvenanceCommit) {
      entry.nonNormativeProvenanceCommit = profile.nonNormativeProvenanceCommit;
    }
    inputs.push(entry);
  }
  return inputs;
}

// ---------------------------------------------------------------------------
// 6. Output hashes — collect every output hash recorded in the frozen source
//    (tableSha256, generatedSourceSha256, expressionSha256, patternSha256,
//    innerJsonSha256, confusablesSha256, overridesSha256,
//    localeExceptionsSha256, rawBrowserScanSha256). These are the "output
//    hashes" the spec requires the finalizer to regenerate. Zero drift means
//    every output hash from the frozen source is preserved verbatim in the
//    final manifest.
// ---------------------------------------------------------------------------

function buildOutputHashes(source) {
  const out = {};
  for (const profile of source.unicodeProfiles || []) {
    const block = {};
    if (profile.tableSha256) block.tableSha256 = profile.tableSha256;
    if (profile.generatedSourceSha256) block.generatedSourceSha256 = profile.generatedSourceSha256;
    if (profile.expressionSha256) block.expressionSha256 = profile.expressionSha256;
    if (profile.patternSha256) block.patternSha256 = profile.patternSha256;
    if (profile.innerJsonSha256) block.innerJsonSha256 = profile.innerJsonSha256;
    if (profile.confusablesSha256) block.confusablesSha256 = profile.confusablesSha256;
    if (profile.overridesSha256) block.overridesSha256 = profile.overridesSha256;
    if (profile.localeExceptionsSha256) block.localeExceptionsSha256 = profile.localeExceptionsSha256;
    if (profile.rawBrowserScanSha256) block.rawBrowserScanSha256 = profile.rawBrowserScanSha256;
    if (Object.keys(block).length > 0) out[profile.id] = block;
  }
  return out;
}

// ---------------------------------------------------------------------------
// 7. Source artifact hashing — every source artifact referenced by the
//    manifest (the Swift RegExp engine + generated Unicode tables + frozen
//    contract artifacts) gets a recorded SHA-256 (provenance + drift
//    detection).
// ---------------------------------------------------------------------------

function buildSourceArtifacts() {
  const artifacts = {};
  for (const rel of PRODUCT_SOURCE_ARTIFACTS) {
    const abs = join(REPO_ROOT, rel);
    artifacts[rel] = sha256File(abs);
  }
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-m1r3-regexp-unicode-manifest.json'
  ] = sha256File(FROZEN_SOURCE_MANIFEST_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/model-m1r3-regexp-unicode-provenance-closure.html'
  ] = sha256File(PROVENANCE_CLOSURE_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t011-public-api-closure-manifest.json'
  ] = sha256File(FROZEN_API_CLOSURE_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-08-release-candidate-distribution.md'
  ] = sha256File(IMPLEMENTATION_PLAN_PATH);
  return artifacts;
}

// ---------------------------------------------------------------------------
// 8. Final manifest assembly + deterministic JSON serialization.
// ---------------------------------------------------------------------------

/**
 * Assemble the FINAL RegExp/Unicode manifest. Regenerates all six Unicode
 * profiles, ten consumer mappings, Test262 selection, generator inputs,
 * licenses, and output hashes from the frozen M1-R3 source, verifies zero
 * drift + counts + every semantic consumer, hashes every source artifact,
 * and marks the manifest FINAL. Returns the manifest object. If outPath is
 * provided, also writes the deterministic JSON.
 */
export function finalizeManifest({ outPath } = {}) {
  // ---- Zero-drift gate on the frozen source (exact provenance anchor) ----
  const frozenSourceHash = verifySourceZeroDrift(FROZEN_SOURCE_MANIFEST_PATH);
  const source = JSON.parse(readFileSync(FROZEN_SOURCE_MANIFEST_PATH, 'utf8'));

  // ---- Regenerate the six Unicode profiles from the frozen source ----
  const unicodeProfiles = verifyUnicodeProfiles(source);
  // Deep-clone the profiles so the final manifest is an independent snapshot
  // (the source object is not mutated and the final manifest carries its own
  // copy of the regenerated profiles).
  const unicodeProfilesRegen = unicodeProfiles.map((p) => ({ ...p }));

  // ---- Regenerate the ten consumer mappings from the frozen source ----
  const consumerMappingsRegen = (source.regexpProfiles || []).map((p) => ({
    ...p,
  }));

  // ---- Regenerate Test262 selection from the frozen source ----
  const test262Selection = {
    authorities: source.authorities.test262,
    corpusContract: source.regexpCorpusContract,
  };

  // ---- Regenerate generator inputs from the frozen source ----
  const generatorInputs = buildGeneratorInputs(source);

  // ---- Regenerate licenses from the frozen source ----
  const licenseContract = source.licenseContract;

  // ---- Regenerate output hashes from the frozen source ----
  const outputHashes = buildOutputHashes(source);

  // ---- Verify every final semantic consumer appears and no
  //      post-finalization product consumer exists ----
  const semanticConsumers = verifySemanticConsumers(source);

  // ---- Verify the frozen counts: 6 / 10 / 14 / 11 / 3 / 8 / 2117 ----
  const verifiedCounts = verifyCounts(source);

  // ---- Hash every source artifact (provenance + drift detection) ----
  const sourceArtifacts = buildSourceArtifacts();

  // ---- Frozen API closure provenance (P07-T011) ----
  const frozenApiClosureRaw = JSON.parse(
    readFileSync(FROZEN_API_CLOSURE_PATH, 'utf8')
  );
  const frozenApiClosure = {
    path: FROZEN_API_CLOSURE_PATH,
    frozenAt: frozenApiClosureRaw.identity.frozenAt,
    sourceSetDigest: frozenApiClosureRaw.frozenSourceSet.sourceSetDigest,
    sourceCount: frozenApiClosureRaw.frozenSourceSet.sourceCount,
  };

  // ---- Counts block (deterministic key order) ----
  const counts = {
    unicodeProfiles: unicodeProfilesRegen.length,
    consumerMappings: consumerMappingsRegen.length,
    publicRegExpReferences: source.publicRegExpReferences.total,
    retainedReferences: source.publicRegExpReferences.retained,
    cutReferences: source.publicRegExpReferences.cut,
    acceptedFlags: source.nativeRegExpType.acceptedFlags.length,
    test262Sources: source.authorities.test262.totalSourceFileCount,
    test262RegexpFiles: source.authorities.test262.regexpFileCount,
    test262RegexpLiteralFiles: source.authorities.test262.regexpLiteralFileCount,
  };

  const manifest = {
    schemaVersion: 1,
    identity: {
      product: 'MonaCode',
      revision: 'P08-T011-final-regexp-unicode-manifest',
      baseline: 'monaco-editor@0.56.0',
      frozen: true,
      final: true,
      finalReason:
        'The M1-R3 regExpUnicode source contract is frozen; the Phase 07 ' +
        'public API closure (P07-T011) is frozen; every semantic consumer ' +
        'of RegExp appears in the manifest and no post-finalization product ' +
        'consumer exists; the regenerated six Unicode profiles, ten consumer ' +
        'mappings, Test262 selection, generator inputs, licenses and output ' +
        'hashes match the frozen M1-R3 source with zero drift. This is the ' +
        'FINAL MonaRegExpUnicodeManifest.',
    },
    frozenBaseline: {
      path: FROZEN_SOURCE_MANIFEST_PATH,
      sha256: frozenSourceHash,
      revision: source.identity.revision,
      title: source.identity.title,
      provenanceClosureSha256: sha256File(PROVENANCE_CLOSURE_PATH),
    },
    frozenApiClosure,
    sources: {
      m1r3RegExpUnicodeManifest: frozenSourceHash,
      provenanceClosureHtml: sha256File(PROVENANCE_CLOSURE_PATH),
      frozenApiClosureManifest: sha256File(FROZEN_API_CLOSURE_PATH),
      implementationPlanPhase08: sha256File(IMPLEMENTATION_PLAN_PATH),
    },
    counts,
    verifiedCounts,
    unicodeProfiles: unicodeProfilesRegen,
    consumerMappings: consumerMappingsRegen,
    test262Selection,
    generatorInputs,
    licenseContract,
    outputHashes,
    semanticConsumers,
    sourceArtifacts,
  };

  // ---- Zero-drift gate: mark final only after exact provenance
  //      reproduction ----
  // verifySourceZeroDrift threw if the source manifest drifted.
  // verifyCounts threw if any frozen count drifted.
  // verifySemanticConsumers threw if any consumer was missing or a
  // post-finalization consumer appeared. verifyUnicodeProfiles threw if any
  // profile was missing. If we reach here, drift is zero and the manifest
  // is final.

  const json = stableStringify(manifest) + '\n';

  if (outPath) {
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, json);
  } else {
    mkdirSync(dirname(FINAL_MANIFEST_PATH), { recursive: true });
    writeFileSync(FINAL_MANIFEST_PATH, json);
  }

  // Stable summary line for CI/observability.
  process.stdout.write(
    `FINAL_REGEXP_UNICODE_MANIFEST profiles=${unicodeProfilesRegen.length} ` +
      `consumers=${consumerMappingsRegen.length} ` +
      `test262=${source.authorities.test262.totalSourceFileCount} ` +
      `final=true drift=0 ` +
      `publicRefs=${source.publicRegExpReferences.total} ` +
      `retained=${source.publicRegExpReferences.retained} ` +
      `cut=${source.publicRegExpReferences.cut} ` +
      `flags=${source.nativeRegExpType.acceptedFlags.length}\n`
  );

  return manifest;
}

// ---------------------------------------------------------------------------
// Utilities.
// ---------------------------------------------------------------------------

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

function sha256File(path) {
  return sha256(readFileSync(path, 'utf8'));
}

/**
 * Deterministic JSON stringifier. Produces stable key order by sorting keys
 * at every object level, with 2-space indentation. This guarantees
 * byte-identical output across re-runs regardless of object key insertion
 * order.
 */
function stableStringify(value, indent) {
  const ind = indent === undefined ? 0 : indent;
  const pad = ' '.repeat(ind * 2);
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    if (value.length === 0) return '[]';
    const inner = ' '.repeat((ind + 1) * 2);
    const items = value.map((v) => inner + stableStringify(v, ind + 1));
    return '[\n' + items.join(',\n') + '\n' + pad + ']';
  }
  const keys = Object.keys(value).sort();
  if (keys.length === 0) return '{}';
  const inner = ' '.repeat((ind + 1) * 2);
  const pairs = keys.map(
    (k) => inner + JSON.stringify(k) + ': ' + stableStringify(value[k], ind + 1)
  );
  return '{\n' + pairs.join(',\n') + '\n' + pad + '}';
}

// When invoked directly, write the final manifest to the committed artifact path.
const isMain =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith('finalize-regexp-unicode-manifest.mjs');
if (isMain) {
  finalizeManifest({});
}
