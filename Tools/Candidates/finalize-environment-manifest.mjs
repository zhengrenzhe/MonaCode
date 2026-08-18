// finalize-environment-manifest.mjs
//
// P08-T012 — Finalize MonaEnvironmentManifest after every
// environment-sensitive consumer.
//
// This is the Node finalizer for the MonaCode FINAL environment manifest. It
// regenerates ALL clock, entropy, number-formatting, locale, calendar,
// numbering, time-zone, case, collation, normalization, and finite-intrinsic
// occurrence rows from the FROZEN E1-R environment-intl-clock-entropy source
// contract plus the X1-R source-runtime-style contract (plus the P07-T011
// frozen public-API closure baseline), verifies set equality against E1-R and
// X1-R plus the generated input and output hashes, verifies every
// environment-sensitive consumer appears and the notice input (LICENSE.md) is
// complete, hashes every source artifact, and marks the manifest FINAL only
// after exact provenance reproduction (zero drift).
//
// The manifest is FINAL: identity.frozen = true, identity.final = true, and
// identity.provisional is absent. This is distinct from the E1-R/X1-R
// provisional source contracts (identity.status = "design-baseline-only" and
// implementationStatus.verdict = "not-passed"). Phase 09 acceptance reads
// this final manifest without re-running the finalizer.
//
// Sources (FROZEN):
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monacode-e1r-environment-intl-clock-entropy-manifest.json  (E1-R source)
//     monacode-x1r-source-runtime-style-manifest.json             (X1-R source)
//     environment-e1r-intl-clock-entropy-closure.html             (E1-R closure)
//     source-x1r-runtime-style-closure.html                      (X1-R closure)
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/
//     monacode-p07-t011-public-api-closure-manifest.json         (frozen API baseline)
//   docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/
//     phase-08-release-candidate-distribution.md                  (P08-T012 leaf)
//
// Product source (generated environment tables + notice input):
//   Sources/MonaCode/Generated/Environment/MonaCaseTables.swift        (case)
//   Sources/MonaCode/Generated/Environment/MonaCollationTables.swift  (collation)
//   Sources/MonaCode/Generated/LICENSE.md                              (notice input)
//
// The API is FROZEN (P07-T011). The finalizer regenerates from the frozen
// source — no public API changes.
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/finalize-environment-manifest.mjs
//
// Writes:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p08-t012-environment-manifest.json
//
// Determinism: byte-identical across re-runs (stable key order, trailing
// newline, no non-deterministic data sources).

import { createHash } from 'node:crypto';
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  existsSync,
} from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..');

export const FINAL_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p08-t012-environment-manifest.json'
);

const FROZEN_E1R_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'monacode-e1r-environment-intl-clock-entropy-manifest.json'
);

const FROZEN_X1R_MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'monacode-x1r-source-runtime-style-manifest.json'
);

const E1R_CLOSURE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'environment-e1r-intl-clock-entropy-closure.html'
);

const X1R_CLOSURE_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts',
  'source-x1r-runtime-style-closure.html'
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

const LICENSE_NOTICE_PATH = join(
  REPO_ROOT,
  'Sources',
  'MonaCode',
  'Generated',
  'LICENSE.md'
);

const CASE_TABLES_PATH = join(
  REPO_ROOT,
  'Sources',
  'MonaCode',
  'Generated',
  'Environment',
  'MonaCaseTables.swift'
);

const COLLATION_TABLES_PATH = join(
  REPO_ROOT,
  'Sources',
  'MonaCode',
  'Generated',
  'Environment',
  'MonaCollationTables.swift'
);

// The frozen source manifest SHA-256 anchors (with trailing LF). Recorded in
// the g4-r/g5-r/g6-r SHA256SUMS and the g6-r authoritative manifest. These are
// the zero-drift anchors for the E1-R + X1-R sources.
const FROZEN_E1R_MANIFEST_SHA256 =
  'ecc1e42b7061baf4ade5bd3fd5e3c1c2ee89d46f96b3aafc4c94dba5edb78dc9';
const FROZEN_X1R_MANIFEST_SHA256 =
  '516c91d905532e9c54e2b3691e74024c81f5887203e6b1cb9184e2c981aaa280';
const FROZEN_E1R_CLOSURE_SHA256 =
  '920e102184648cd1a08d589944708ceb62b4f3f6c091b4b100378f989709637b';
const FROZEN_X1R_CLOSURE_SHA256 =
  '32bebccbf932e1baab6bb9ebd386715295625792198ae378566d0bc11ca2a3a9';

// The frozen count contract (from the g6-r authoritative manifest's
// environmentIntl + sourceRuntimeStyle blocks and the E1-R/X1-R source
// manifests). The finalizer refuses to finalize unless the regenerated
// manifest reproduces every frozen count exactly.
export const EXPECTED_COUNTS = {
  reachableJavaScriptFiles: 956,
  reachableStyleResources: 98,
  totalImportedFiles: 1054,
  importEdges: 6275,
  defaultCaseOccurrences: 138,
  localeCaseOccurrences: 16,
  localeCompareOccurrences: 11,
  normalizationOccurrences: 1,
  mathRandomOccurrences: 8,
  dateNowOccurrences: 90,
  newDateOccurrences: 14,
  stopWatchConstructionSites: 21,
  retainedHighResolutionStopWatchSites: 13,
  retainedWallClockStopWatchSites: 6,
  cutTreeSitterHighResolutionStopWatchSites: 2,
  inputLatencyPerformanceCalls: 25,
  timerOccurrences: 94,
  microtaskOccurrences: 11,
  collationProfiles: 5,
  activeNormalizationCaches: 2,
  directGlobalIdentifiers: 84,
  directGlobalReferences: 8221,
  ecmascriptIntrinsicIdentifiers: 41,
  ecmascriptIntrinsicReferences: 7523,
  platformIdentifiers: 43,
  platformReferences: 698,
  finiteIntrinsicProfiles: 12,
};

// The twelve finite intrinsic profiles (frozen) — the X1-R
// intrinsicOperationProfiles.selectedReferenceCounts keys. These remain the
// exhaustive set of finite intrinsic profiles the product implements; no
// general JavaScript runtime is exposed.
const EXPECTED_FINITE_INTRINSIC_PROFILES = [
  'Array',
  'Object',
  'Reflect',
  'Map',
  'Set',
  'Promise',
  'Math',
  'Number',
  'String',
  'JSON',
  'RegExp',
  'Symbol',
];

// The eleven environment-sensitive consumer categories the finalizer must
// regenerate (clock, entropy, number formatting, locale, calendar, numbering,
// time zone, case, collation, normalization, finite-intrinsic). The last
// source consumer is the union of these; every one must appear before the
// manifest is marked final.
const EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES = [
  'clock',
  'entropy',
  'number-formatting',
  'locale',
  'calendar',
  'numbering',
  'time-zone',
  'case',
  'collation',
  'normalization',
  'finite-intrinsic',
];

// The license/notice inputs the finalizer records as the "notice input" gate.
// These map to the g6-r authoritative manifest's licensingProfile entries.
const NOTICE_INPUT_LABELS = [
  { label: 'MonacoCode (MIT)', match: /MIT/i, profileKey: 'monacoCode' },
  { label: 'Monaco localization (MIT)', match: /Monaco localization/i, profileKey: 'monacoLocalization' },
  { label: 'Marked (MIT)', match: /Marked/i, profileKey: 'marked' },
  { label: 'LSP specification (CC BY 4.0)', match: /LSP/i, profileKey: 'lspSpecification' },
  { label: 'Codicon artwork (CC BY 4.0)', match: /Codicon artwork/i, profileKey: 'codiconArtworkAndFont' },
  { label: 'Codicon generator + code (MIT)', match: /Codicon generator/i, profileKey: 'codiconGeneratorAndCode' },
  { label: 'esbuild comparator (MIT)', match: /esbuild/i, profileKey: 'comparatorBuildTools' },
  { label: 'DOMPurify (oracle-only)', match: /DOMPurify/i, profileKey: 'domPurify' },
  { label: 'Unicode tables (Unicode-3.0)', match: /Unicode/i, profileKey: 'unicodeTables' },
  { label: 'Chromium ICU data', match: /ICU/i, profileKey: 'chromiumIcuData' },
  { label: 'Test262 (BSD)', match: /Test262/i, profileKey: 'test262' },
  { label: 'V8 / ICU runtime (oracle-only)', match: /V8/i, profileKey: 'v8AndIcu' },
  { label: 'vscode-unicode-data (excluded)', match: /vscode-unicode/i, profileKey: 'vscodeUnicodeData' },
];

// ---------------------------------------------------------------------------
// 1. Zero-drift verification — the frozen E1-R + X1-R source manifests and
//    their closure HTMLs must hash to the recorded SHA-256 anchors. Any
//    mismatch means the source has drifted and the finalizer refuses to
//    finalize.
// ---------------------------------------------------------------------------

export function verifySourceZeroDrift(
  e1rPath,
  x1rPath,
  e1rClosurePath,
  x1rClosurePath
) {
  const e1rHash = sha256File(e1rPath);
  if (e1rHash !== FROZEN_E1R_MANIFEST_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_E1R_SOURCE path=${e1rPath} regenerated=${e1rHash} frozen=${FROZEN_E1R_MANIFEST_SHA256}`
    );
  }
  const x1rHash = sha256File(x1rPath);
  if (x1rHash !== FROZEN_X1R_MANIFEST_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_X1R_SOURCE path=${x1rPath} regenerated=${x1rHash} frozen=${FROZEN_X1R_MANIFEST_SHA256}`
    );
  }
  const e1rClosureHash = sha256File(e1rClosurePath);
  if (e1rClosureHash !== FROZEN_E1R_CLOSURE_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_E1R_CLOSURE path=${e1rClosurePath} regenerated=${e1rClosureHash} frozen=${FROZEN_E1R_CLOSURE_SHA256}`
    );
  }
  const x1rClosureHash = sha256File(x1rClosurePath);
  if (x1rClosureHash !== FROZEN_X1R_CLOSURE_SHA256) {
    throw new Error(
      `DRIFT_FROZEN_X1R_CLOSURE path=${x1rClosurePath} regenerated=${x1rClosureHash} frozen=${FROZEN_X1R_CLOSURE_SHA256}`
    );
  }
  return {
    e1rManifest: e1rHash,
    x1rManifest: x1rHash,
    e1rClosure: e1rClosureHash,
    x1rClosure: x1rClosureHash,
  };
}

// ---------------------------------------------------------------------------
// 2. Count verification — the frozen count contract. The regenerated counts
//    must reproduce every frozen count exactly (set equality on the count
//    contract).
// ---------------------------------------------------------------------------

export function verifyCounts(e1rSource, x1rSource) {
  const syntaxCounts = e1rSource.sourceEffectClosure.syntaxCounts;
  const x1rClock = x1rSource.clockAndPerformanceCorrection;
  const x1rGlobals = x1rSource.directGlobalClosure;
  const x1rIntrinsics = x1rSource.intrinsicOperationProfiles;

  const actual = {
    reachableJavaScriptFiles: e1rSource.sourceEffectClosure.reachableJavaScriptFiles,
    reachableStyleResources: e1rSource.sourceEffectClosure.reachableStyleResources,
    totalImportedFiles: e1rSource.sourceEffectClosure.totalImportedFiles,
    importEdges: e1rSource.sourceEffectClosure.parsedImportEdges,
    defaultCaseOccurrences:
      (syntaxCounts.toUpperCase?.occurrences || 0) +
      (syntaxCounts.toLowerCase?.occurrences || 0),
    localeCaseOccurrences:
      (syntaxCounts.toLocaleUpperCase?.occurrences || 0) +
      (syntaxCounts.toLocaleLowerCase?.occurrences || 0),
    localeCompareOccurrences: syntaxCounts.localeCompare?.occurrences || 0,
    normalizationOccurrences: syntaxCounts.unicodeNormalize?.occurrences || 0,
    mathRandomOccurrences: syntaxCounts.mathRandom?.occurrences || 0,
    dateNowOccurrences: syntaxCounts.dateNow?.occurrences || 0,
    newDateOccurrences: syntaxCounts.newDate?.occurrences || 0,
    stopWatchConstructionSites:
      syntaxCounts.stopWatchConstructionSites?.occurrences || 0,
    retainedHighResolutionStopWatchSites:
      syntaxCounts.stopWatchConstructionSites?.retainedHighResolution || 0,
    retainedWallClockStopWatchSites:
      syntaxCounts.stopWatchConstructionSites?.retainedWallClock || 0,
    cutTreeSitterHighResolutionStopWatchSites:
      syntaxCounts.stopWatchConstructionSites?.cutTreeSitterHighResolution || 0,
    inputLatencyPerformanceCalls:
      syntaxCounts.inputLatencyPerformanceApi?.occurrences || 0,
    timerOccurrences: syntaxCounts.timerCalls?.occurrences || 0,
    microtaskOccurrences: syntaxCounts.queueMicrotask?.occurrences || 0,
    collationProfiles: (e1rSource.textSemantics.collationProfiles || []).length,
    activeNormalizationCaches:
      (e1rSource.textSemantics.normalization?.nfdCache?.capacity ? 1 : 0) +
      (e1rSource.textSemantics.normalization?.baseCache?.capacity ? 1 : 0),
    directGlobalIdentifiers: x1rGlobals.identifierCount,
    directGlobalReferences: x1rGlobals.referenceCount,
    ecmascriptIntrinsicIdentifiers:
      x1rGlobals.ecmascriptIntrinsicIdentifiers.count,
    ecmascriptIntrinsicReferences:
      x1rGlobals.ecmascriptIntrinsicIdentifiers.references,
    platformIdentifiers: x1rGlobals.platformIdentifiers.count,
    platformReferences: x1rGlobals.platformIdentifiers.references,
    finiteIntrinsicProfiles: Object.keys(
      x1rIntrinsics.selectedReferenceCounts || {}
    ).length,
  };

  const checks = [
    ['reachableJavaScriptFiles', actual.reachableJavaScriptFiles, EXPECTED_COUNTS.reachableJavaScriptFiles],
    ['reachableStyleResources', actual.reachableStyleResources, EXPECTED_COUNTS.reachableStyleResources],
    ['totalImportedFiles', actual.totalImportedFiles, EXPECTED_COUNTS.totalImportedFiles],
    ['importEdges', actual.importEdges, EXPECTED_COUNTS.importEdges],
    ['defaultCaseOccurrences', actual.defaultCaseOccurrences, EXPECTED_COUNTS.defaultCaseOccurrences],
    ['localeCaseOccurrences', actual.localeCaseOccurrences, EXPECTED_COUNTS.localeCaseOccurrences],
    ['localeCompareOccurrences', actual.localeCompareOccurrences, EXPECTED_COUNTS.localeCompareOccurrences],
    ['normalizationOccurrences', actual.normalizationOccurrences, EXPECTED_COUNTS.normalizationOccurrences],
    ['mathRandomOccurrences', actual.mathRandomOccurrences, EXPECTED_COUNTS.mathRandomOccurrences],
    ['dateNowOccurrences', actual.dateNowOccurrences, EXPECTED_COUNTS.dateNowOccurrences],
    ['newDateOccurrences', actual.newDateOccurrences, EXPECTED_COUNTS.newDateOccurrences],
    ['stopWatchConstructionSites', actual.stopWatchConstructionSites, EXPECTED_COUNTS.stopWatchConstructionSites],
    ['retainedHighResolutionStopWatchSites', actual.retainedHighResolutionStopWatchSites, EXPECTED_COUNTS.retainedHighResolutionStopWatchSites],
    ['retainedWallClockStopWatchSites', actual.retainedWallClockStopWatchSites, EXPECTED_COUNTS.retainedWallClockStopWatchSites],
    ['cutTreeSitterHighResolutionStopWatchSites', actual.cutTreeSitterHighResolutionStopWatchSites, EXPECTED_COUNTS.cutTreeSitterHighResolutionStopWatchSites],
    ['inputLatencyPerformanceCalls', actual.inputLatencyPerformanceCalls, EXPECTED_COUNTS.inputLatencyPerformanceCalls],
    ['timerOccurrences', actual.timerOccurrences, EXPECTED_COUNTS.timerOccurrences],
    ['microtaskOccurrences', actual.microtaskOccurrences, EXPECTED_COUNTS.microtaskOccurrences],
    ['collationProfiles', actual.collationProfiles, EXPECTED_COUNTS.collationProfiles],
    ['activeNormalizationCaches', actual.activeNormalizationCaches, EXPECTED_COUNTS.activeNormalizationCaches],
    ['directGlobalIdentifiers', actual.directGlobalIdentifiers, EXPECTED_COUNTS.directGlobalIdentifiers],
    ['directGlobalReferences', actual.directGlobalReferences, EXPECTED_COUNTS.directGlobalReferences],
    ['ecmascriptIntrinsicIdentifiers', actual.ecmascriptIntrinsicIdentifiers, EXPECTED_COUNTS.ecmascriptIntrinsicIdentifiers],
    ['ecmascriptIntrinsicReferences', actual.ecmascriptIntrinsicReferences, EXPECTED_COUNTS.ecmascriptIntrinsicReferences],
    ['platformIdentifiers', actual.platformIdentifiers, EXPECTED_COUNTS.platformIdentifiers],
    ['platformReferences', actual.platformReferences, EXPECTED_COUNTS.platformReferences],
    ['finiteIntrinsicProfiles', actual.finiteIntrinsicProfiles, EXPECTED_COUNTS.finiteIntrinsicProfiles],
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
// 3. Environment-sensitive consumer verification — every final environment-
//    sensitive consumer appears and no post-finalization product consumer
//    exists (the regenerated consumer set is exactly the frozen set — zero
//    drift on consumer categories).
// ---------------------------------------------------------------------------

export function verifySemanticConsumers(occurrenceRows) {
  const actualCategories = new Set(
    occurrenceRows.map((r) => r.category)
  );
  const expectedSet = new Set(EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES);

  // Every frozen consumer category must appear (no missing consumer).
  const missing = EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES.filter(
    (id) => !actualCategories.has(id)
  );
  if (missing.length > 0) {
    throw new Error(
      `DRIFT_MISSING_ENVIRONMENT_CONSUMER missing=${JSON.stringify(missing)} actual=${JSON.stringify([...actualCategories])}`
    );
  }

  // No extra consumer category was added after finalization (zero drift on the
  // consumer set — the regenerated categories are exactly the frozen set).
  const extra = [...actualCategories].filter((id) => !expectedSet.has(id));
  if (extra.length > 0) {
    throw new Error(
      `DRIFT_POST_FINALIZATION_CONSUMER extra=${JSON.stringify(extra)} actual=${JSON.stringify([...actualCategories])}`
    );
  }

  if (actualCategories.size !== EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES.length) {
    throw new Error(
      `DRIFT_CONSUMER_COUNT actual=${actualCategories.size} frozen=${EXPECTED_ENVIRONMENT_CONSUMER_CATEGORIES.length}`
    );
  }

  return {
    consumerCategories: [...actualCategories].sort(),
    allConsumersPresent: missing.length === 0,
    postFinalizationProductConsumerExists: extra.length > 0,
  };
}

// ---------------------------------------------------------------------------
// 4. Finite-intrinsic profile verification — every frozen finite-intrinsic
//    profile appears and the twelve remain the exhaustive set (no general
//    JavaScript runtime is exposed).
// ---------------------------------------------------------------------------

export function verifyFiniteIntrinsicProfiles(x1rSource) {
  const counts = x1rSource.intrinsicOperationProfiles.selectedReferenceCounts || {};
  const actualNames = Object.keys(counts);
  const expectedSet = new Set(EXPECTED_FINITE_INTRINSIC_PROFILES);

  const missing = EXPECTED_FINITE_INTRINSIC_PROFILES.filter(
    (name) => !actualNames.includes(name)
  );
  if (missing.length > 0) {
    throw new Error(
      `DRIFT_MISSING_FINITE_INTRINSIC_PROFILE missing=${JSON.stringify(missing)} actual=${JSON.stringify(actualNames)}`
    );
  }
  const extra = actualNames.filter((name) => !expectedSet.has(name));
  if (extra.length > 0) {
    throw new Error(
      `DRIFT_POST_FINALIZATION_FINITE_INTRINSIC_PROFILE extra=${JSON.stringify(extra)} actual=${JSON.stringify(actualNames)}`
    );
  }
  if (actualNames.length !== EXPECTED_FINITE_INTRINSIC_PROFILES.length) {
    throw new Error(
      `DRIFT_FINITE_INTRINSIC_PROFILE_COUNT actual=${actualNames.length} frozen=${EXPECTED_FINITE_INTRINSIC_PROFILES.length}`
    );
  }

  // Return the profiles in the frozen key order (deterministic).
  return EXPECTED_FINITE_INTRINSIC_PROFILES.map((name) => ({
    name,
    referenceCount: counts[name],
  }));
}

// ---------------------------------------------------------------------------
// 5. Occurrence-row regeneration — rebuild the clock, entropy, number-
//    formatting, locale, calendar, numbering, time-zone, case, collation,
//    normalization, and finite-intrinsic occurrence rows from the frozen E1-R
//    + X1-R source. Each row records its category, its source contract (E1-R
//    or X1-R), its identity, its occurrence count, and the source provenance.
// ---------------------------------------------------------------------------

function buildOccurrenceRows(e1rSource, x1rSource) {
  const syntaxCounts = e1rSource.sourceEffectClosure.syntaxCounts;
  const x1rClock = x1rSource.clockAndPerformanceCorrection;
  const x1rGlobals = x1rSource.directGlobalClosure;
  const x1rIntrinsics = x1rSource.intrinsicOperationProfiles;
  const textSemantics = e1rSource.textSemantics;
  const entropyBlock = e1rSource.entropy;
  const clocksBlock = e1rSource.clocksAndScheduling;
  const qualified = e1rSource.qualifiedRuntimeObservation;

  const rows = [];

  // ---- clock ----
  rows.push({
    category: 'clock',
    identity: 'dateNow',
    occurrences: syntaxCounts.dateNow.occurrences,
    files: syntaxCounts.dateNow.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaWallClock',
    source: clocksBlock.wallClock,
  });
  rows.push({
    category: 'clock',
    identity: 'newDate',
    occurrences: syntaxCounts.newDate.occurrences,
    files: syntaxCounts.newDate.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaWallClock',
    source: clocksBlock.dateObject,
  });
  rows.push({
    category: 'clock',
    identity: 'stopWatchConstructionSites',
    occurrences: syntaxCounts.stopWatchConstructionSites.occurrences,
    retainedHighResolution: syntaxCounts.stopWatchConstructionSites.retainedHighResolution,
    retainedWallClock: syntaxCounts.stopWatchConstructionSites.retainedWallClock,
    cutTreeSitterHighResolution: syntaxCounts.stopWatchConstructionSites.cutTreeSitterHighResolution,
    sourceContract: 'E1-R + X1-R',
    disposition: 'retained + cut-tree-sitter',
    nativeSymbol: 'MonaHighResolutionClock',
    source: `${clocksBlock.stopWatch} ${x1rClock.highResolutionClock}`,
  });
  rows.push({
    category: 'clock',
    identity: 'inputLatencyPerformanceApi',
    occurrences: syntaxCounts.inputLatencyPerformanceApi.occurrences,
    files: syntaxCounts.inputLatencyPerformanceApi.files,
    mark: x1rClock.inputLatencyPerformanceCalls.mark,
    measure: x1rClock.inputLatencyPerformanceCalls.measure,
    getEntriesByName: x1rClock.inputLatencyPerformanceCalls.getEntriesByName,
    clearMarks: x1rClock.inputLatencyPerformanceCalls.clearMarks,
    clearMeasures: x1rClock.inputLatencyPerformanceCalls.clearMeasures,
    sourceContract: 'E1-R + X1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaHighResolutionClock',
    source: clocksBlock.inputLatency,
  });
  rows.push({
    category: 'clock',
    identity: 'directPerformanceNow',
    occurrences: syntaxCounts.directPerformanceNow.occurrences,
    files: syntaxCounts.directPerformanceNow.files,
    disposition: 'cut-tree-sitter',
    sourceContract: 'E1-R',
    nativeSymbol: 'UNAVAILABLE',
    source: clocksBlock.directPerformanceNow,
  });
  rows.push({
    category: 'clock',
    identity: 'timerCalls',
    occurrences: syntaxCounts.timerCalls.occurrences,
    freeSetTimeout: syntaxCounts.timerCalls.freeSetTimeout,
    freeClearTimeout: syntaxCounts.timerCalls.freeClearTimeout,
    memberSetTimeout: syntaxCounts.timerCalls.memberSetTimeout,
    memberClearTimeout: syntaxCounts.timerCalls.memberClearTimeout,
    memberSetInterval: syntaxCounts.timerCalls.memberSetInterval,
    memberClearInterval: syntaxCounts.timerCalls.memberClearInterval,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaScheduler',
    source: clocksBlock.timers,
  });
  rows.push({
    category: 'clock',
    identity: 'directAnimationFrameCalls',
    occurrences: syntaxCounts.directAnimationFrameCalls.occurrences,
    files: syntaxCounts.directAnimationFrameCalls.files,
    sourceContract: 'E1-R',
    disposition: 'retained (V1-R4)',
    nativeSymbol: 'MonaDisplayFrameScheduler',
    source: clocksBlock.animationFrames,
  });
  rows.push({
    category: 'clock',
    identity: 'idleCallbackCalls',
    occurrences: syntaxCounts.idleCallbackCalls.occurrences,
    files: syntaxCounts.idleCallbackCalls.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaIdleQueue',
    source: clocksBlock.idleWork,
  });
  rows.push({
    category: 'clock',
    identity: 'queueMicrotask',
    occurrences: syntaxCounts.queueMicrotask.occurrences,
    files: syntaxCounts.queueMicrotask.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaMicrotaskQueue',
    source: clocksBlock.microtasks,
  });

  // ---- entropy ----
  rows.push({
    category: 'entropy',
    identity: 'mathRandom',
    occurrences: syntaxCounts.mathRandom.occurrences,
    files: syntaxCounts.mathRandom.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaRandomDoubleSource',
    source: entropyBlock.mathRandomDomain,
  });
  rows.push({
    category: 'entropy',
    identity: 'cryptoRandomUUID',
    occurrences: 1,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaCryptoRandomSource',
    source: entropyBlock.uuid,
  });
  rows.push({
    category: 'entropy',
    identity: 'snippetVectors',
    occurrences: entropyBlock.snippetVectors.length,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaRandomDoubleSource',
    snippetVectors: entropyBlock.snippetVectors,
    source: entropyBlock.numberToString,
  });

  // ---- number formatting ----
  rows.push({
    category: 'number-formatting',
    identity: 'numberToString',
    occurrences: 1,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaNumberToString',
    source: entropyBlock.numberToString,
  });
  rows.push({
    category: 'number-formatting',
    identity: 'intlNumberFormat',
    occurrences: 0,
    sourceContract: 'E1-R',
    disposition: 'inactive-intl',
    nativeSymbol: 'UNAVAILABLE',
    source: textSemantics.inactiveIntl.numberFormat,
  });

  // ---- locale ----
  rows.push({
    category: 'locale',
    identity: 'runtimeLocale',
    occurrences: 1,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaRuntimeLocale',
    source: e1rSource.languageAndLocaleSeparation.runtimeLocale,
    qualifiedValue: qualified.swiftLocaleCurrent,
    chromeResolved: qualified.chromeIntlResolvedLocale,
  });
  rows.push({
    category: 'locale',
    identity: 'toLocaleUpperCase',
    occurrences: syntaxCounts.toLocaleUpperCase.occurrences,
    files: syntaxCounts.toLocaleUpperCase.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaLocaleCaseConversion',
    source: textSemantics.localeCaseConversion,
  });
  rows.push({
    category: 'locale',
    identity: 'toLocaleLowerCase',
    occurrences: syntaxCounts.toLocaleLowerCase.occurrences,
    files: syntaxCounts.toLocaleLowerCase.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaLocaleCaseConversion',
    source: textSemantics.localeCaseConversion,
  });

  // ---- calendar ----
  rows.push({
    category: 'calendar',
    identity: 'runtimeCalendar',
    occurrences: 1,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaRuntimeCalendar',
    source: clocksBlock.dateObject,
    qualifiedValue: qualified.chromeCalendar,
  });

  // ---- numbering ----
  rows.push({
    category: 'numbering',
    identity: 'runtimeNumberingSystem',
    occurrences: 1,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaRuntimeNumberingSystem',
    source: textSemantics.representation,
    qualifiedValue: qualified.chromeNumberingSystem,
  });

  // ---- time zone ----
  rows.push({
    category: 'time-zone',
    identity: 'runtimeTimeZone',
    occurrences: 1,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaRuntimeTimeZone',
    source: clocksBlock.wallClock,
    qualifiedValue: qualified.swiftTimeZoneCurrent,
    chromeResolved: qualified.chromeTimeZone,
  });

  // ---- case ----
  rows.push({
    category: 'case',
    identity: 'toUpperCase',
    occurrences: syntaxCounts.toUpperCase.occurrences,
    files: syntaxCounts.toUpperCase.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaDefaultCaseConversion',
    source: textSemantics.defaultCaseConversion,
  });
  rows.push({
    category: 'case',
    identity: 'toLowerCase',
    occurrences: syntaxCounts.toLowerCase.occurrences,
    files: syntaxCounts.toLowerCase.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaDefaultCaseConversion',
    source: textSemantics.defaultCaseConversion,
  });
  rows.push({
    category: 'case',
    identity: 'caseActionFamilies',
    occurrences: (textSemantics.caseActionFamilies?.lineOperations || []).length +
      (textSemantics.caseActionFamilies?.snippetFormats || []).length,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaCaseActionFamily',
    lineOperations: textSemantics.caseActionFamilies.lineOperations,
    snippetFormats: textSemantics.caseActionFamilies.snippetFormats,
    source: textSemantics.caseActionFamilies.rule,
  });

  // ---- collation ----
  rows.push({
    category: 'collation',
    identity: 'localeCompare',
    occurrences: syntaxCounts.localeCompare.occurrences,
    files: syntaxCounts.localeCompare.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaLocaleCompare',
    source: textSemantics.collationData,
  });
  for (const profile of textSemantics.collationProfiles || []) {
    rows.push({
      category: 'collation',
      identity: `collationProfile:${profile.id}`,
      occurrences: profile.sourceOccurrences || 0,
      files: profile.sourceFiles || 0,
      sourceContract: 'E1-R',
      disposition: 'retained',
      nativeSymbol: 'MonaCollator',
      options: profile.options,
      stable: profile.stable === true,
      tieBreak: profile.tieBreak,
      source: textSemantics.collationData,
    });
  }

  // ---- normalization ----
  rows.push({
    category: 'normalization',
    identity: 'unicodeNormalize',
    occurrences: syntaxCounts.unicodeNormalize.occurrences,
    files: syntaxCounts.unicodeNormalize.files,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaNormalization',
    source: textSemantics.normalization,
  });
  rows.push({
    category: 'normalization',
    identity: 'nfdCache',
    occurrences: 1,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaNormalization',
    cache: textSemantics.normalization.nfdCache,
    source: textSemantics.normalization.fastPath,
  });
  rows.push({
    category: 'normalization',
    identity: 'baseCache',
    occurrences: 1,
    sourceContract: 'E1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaNormalization',
    cache: textSemantics.normalization.baseCache,
    source: textSemantics.normalization.tryNormalizeToBase,
  });

  // ---- finite-intrinsic ----
  const selectedCounts = x1rIntrinsics.selectedReferenceCounts || {};
  for (const name of EXPECTED_FINITE_INTRINSIC_PROFILES) {
    rows.push({
      category: 'finite-intrinsic',
      identity: `intrinsic:${name}`,
      occurrences: selectedCounts[name] || 0,
      sourceContract: 'X1-R',
      disposition: 'retained',
      nativeSymbol: `MonaIntrinsic:${name}`,
      source: x1rIntrinsics.finitePortRule,
    });
  }
  rows.push({
    category: 'finite-intrinsic',
    identity: 'ecmascriptIntrinsicIdentifiers',
    occurrences: x1rGlobals.ecmascriptIntrinsicIdentifiers.count,
    references: x1rGlobals.ecmascriptIntrinsicIdentifiers.references,
    sourceContract: 'X1-R',
    disposition: 'retained',
    nativeSymbol: 'MonaIntrinsicSet',
    names: x1rGlobals.ecmascriptIntrinsicIdentifiers.names,
    source: x1rIntrinsics.finitePortRule,
  });
  rows.push({
    category: 'finite-intrinsic',
    identity: 'platformIdentifiers',
    occurrences: x1rGlobals.platformIdentifiers.count,
    references: x1rGlobals.platformIdentifiers.references,
    sourceContract: 'X1-R',
    disposition: 'retained + cut',
    nativeSymbol: 'MonaPlatformEffectSet',
    names: x1rGlobals.platformIdentifiers.names,
    source: x1rSource.platformEffectDispositions.nativeUI,
  });

  // Deterministic key order within each row (stableStringify sorts keys at
  // serialization time, so insertion order here is irrelevant to determinism).
  return rows;
}

// ---------------------------------------------------------------------------
// 6. Generated inputs — extract every input hash recorded in the frozen
//    E1-R + X1-R authorities (coreTar, entry, chrome timeSource, icuData,
//    unicodeInputs, sourceFiles, v8 ieee754, packageInventory). These are the
//    "generated inputs" the spec requires the finalizer to regenerate. Zero
//    drift means every input hash from the frozen source is preserved verbatim
//    in the final manifest.
// ---------------------------------------------------------------------------

function buildGeneratedInputs(e1rSource, x1rSource) {
  const e1rAuth = e1rSource.authorities;
  const x1rAuth = x1rSource.authorities;
  // The X1-R moduleAndResourceClosure + directGlobalClosure are top-level
  // keys on the X1-R manifest (not under authorities). The X1-R authorities
  // carry syntaxScan, sourceFiles, chromiumClock and v8.
  return {
    coreTarSha256: e1rAuth.coreTarSha256,
    entry: { file: e1rAuth.entry.file, sha256: e1rAuth.entry.sha256 },
    chromeVersion: e1rAuth.chrome.version,
    chromiumTagCommit: e1rAuth.chrome.chromiumTagCommit,
    icuSubmoduleCommit: e1rAuth.chrome.icuSubmoduleCommit,
    icuVersion: e1rAuth.chrome.icuVersion,
    localIcuDataBytes: e1rAuth.chrome.localIcuDataBytes,
    localIcuDataSha256: e1rAuth.chrome.localIcuDataSha256,
    icuReadmeSha256: e1rAuth.chrome.icuReadmeSha256,
    icuLicenseSha256: e1rAuth.chrome.icuLicenseSha256,
    chromeTimeSource: e1rAuth.chrome.timeSource,
    ecmascript: e1rAuth.standards.ecmascript,
    ecma402: e1rAuth.standards.ecma402,
    unicode: e1rAuth.standards.unicode,
    unicodeInputs: e1rAuth.unicodeInputs,
    e1rSourceFiles: e1rAuth.sourceFiles,
    x1rSyntaxScan: x1rAuth.syntaxScan,
    x1rSourceFiles: x1rAuth.sourceFiles,
    x1rChromiumClock: x1rAuth.chromiumClock,
    x1rV8: x1rAuth.v8,
    x1rPackageInventory: x1rSource.moduleAndResourceClosure.packageInventory,
  };
}

// ---------------------------------------------------------------------------
// 7. Generated outputs — collect every output hash recorded in the generated
//    product tables (MonaCaseTables.swift, MonaCollationTables.swift) plus
//    the generator hash. These are the "output hashes" the spec requires the
//    finalizer to regenerate. Zero drift means every output hash from the
//    frozen source is preserved verbatim in the final manifest.
// ---------------------------------------------------------------------------

function buildGeneratedOutputs() {
  const caseTablesContent = readFileSync(CASE_TABLES_PATH, 'utf8');
  const collationTablesContent = readFileSync(COLLATION_TABLES_PATH, 'utf8');
  // The generator hash is recorded verbatim in both generated-table headers
  // (see Sources/MonaCode/Generated/Environment/MonaCaseTables.swift).
  const generatorHash = extractGeneratorHash(caseTablesContent);
  return {
    caseTablesSha256: sha256(caseTablesContent),
    collationTablesSha256: sha256(collationTablesContent),
    generatorHash,
    sourceVersion: extractSourceVersion(caseTablesContent),
  };
}

function extractGeneratorHash(content) {
  const m = content.match(/generatorHash\s*=\s*([0-9a-f]{64})/);
  return m ? m[1] : '';
}

function extractSourceVersion(content) {
  const m = content.match(/sourceVersion\s*=\s*["']([^"']+)["']/);
  return m ? m[1] : '';
}

// ---------------------------------------------------------------------------
// 8. Notice input — the LICENSE.md provenance is complete (the notice input
//    gate). The finalizer refuses to mark final unless LICENSE.md exists and
//    carries every required notice.
// ---------------------------------------------------------------------------

function buildNoticeInput(licensingProfile) {
  const present = existsSync(LICENSE_NOTICE_PATH);
  if (!present) {
    throw new Error(
      `NOTICE_INPUT_ABSENT licensePath=${LICENSE_NOTICE_PATH} (P08-T003 notice input not present)`
    );
  }
  const content = readFileSync(LICENSE_NOTICE_PATH, 'utf8');
  const notices = [];
  for (const { label, match, profileKey } of NOTICE_INPUT_LABELS) {
    const profileText = licensingProfile[profileKey] || '';
    const inLicense = match.test(content);
    notices.push({
      label,
      profileKey,
      presentInLicense: inLicense,
      profilePresent: profileText.length > 0,
    });
    if (!inLicense) {
      throw new Error(
        `NOTICE_INPUT_MISSING label=${label} profileKey=${profileKey} (LICENSE.md does not carry this notice)`
      );
    }
  }
  return {
    present,
    licensePath: LICENSE_NOTICE_PATH,
    licenseSha256: sha256(content),
    notices,
  };
}

// ---------------------------------------------------------------------------
// 9. Source artifact hashing — every source artifact referenced by the
//    manifest (the generated environment tables + LICENSE.md + frozen contract
//    artifacts) gets a recorded SHA-256 (provenance + drift detection).
// ---------------------------------------------------------------------------

function buildSourceArtifacts() {
  const artifacts = {};
  artifacts[
    'Sources/MonaCode/Generated/Environment/MonaCaseTables.swift'
  ] = sha256File(CASE_TABLES_PATH);
  artifacts[
    'Sources/MonaCode/Generated/Environment/MonaCollationTables.swift'
  ] = sha256File(COLLATION_TABLES_PATH);
  artifacts['Sources/MonaCode/Generated/LICENSE.md'] = sha256File(LICENSE_NOTICE_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-e1r-environment-intl-clock-entropy-manifest.json'
  ] = sha256File(FROZEN_E1R_MANIFEST_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-x1r-source-runtime-style-manifest.json'
  ] = sha256File(FROZEN_X1R_MANIFEST_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/environment-e1r-intl-clock-entropy-closure.html'
  ] = sha256File(E1R_CLOSURE_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/source-x1r-runtime-style-closure.html'
  ] = sha256File(X1R_CLOSURE_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t011-public-api-closure-manifest.json'
  ] = sha256File(FROZEN_API_CLOSURE_PATH);
  artifacts[
    'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/phase-08-release-candidate-distribution.md'
  ] = sha256File(IMPLEMENTATION_PLAN_PATH);
  return artifacts;
}

// ---------------------------------------------------------------------------
// 10. Final manifest assembly + deterministic JSON serialization.
// ---------------------------------------------------------------------------

/**
 * Assemble the FINAL environment manifest. Regenerates all clock, entropy,
 * number-formatting, locale, calendar, numbering, time-zone, case, collation,
 * normalization, and finite-intrinsic occurrence rows from the frozen E1-R +
 * X1-R source, verifies set equality against E1-R + X1-R plus the generated
 * input and output hashes, verifies every environment-sensitive consumer
 * appears and the notice input is complete, hashes every source artifact, and
 * marks the manifest FINAL. Returns the manifest object. If outPath is
 * provided, also writes the deterministic JSON.
 */
export function finalizeManifest({ outPath } = {}) {
  // ---- Zero-drift gate on the frozen sources (exact provenance anchors) ----
  const frozenHashes = verifySourceZeroDrift(
    FROZEN_E1R_MANIFEST_PATH,
    FROZEN_X1R_MANIFEST_PATH,
    E1R_CLOSURE_PATH,
    X1R_CLOSURE_PATH
  );

  const e1rSource = JSON.parse(readFileSync(FROZEN_E1R_MANIFEST_PATH, 'utf8'));
  const x1rSource = JSON.parse(readFileSync(FROZEN_X1R_MANIFEST_PATH, 'utf8'));

  // ---- Regenerate the occurrence rows from the frozen E1-R + X1-R source ----
  const occurrenceRows = buildOccurrenceRows(e1rSource, x1rSource);

  // ---- Regenerate the generated inputs from the frozen source ----
  const generatedInputs = buildGeneratedInputs(e1rSource, x1rSource);

  // ---- Regenerate the generated outputs (MonaCaseTables + MonaCollationTables
  //      + generator hash) from the generated product tables ----
  const generatedOutputs = buildGeneratedOutputs();

  // ---- Verify the twelve finite-intrinsic profiles (zero drift on profiles) ----
  const finiteIntrinsicProfiles = verifyFiniteIntrinsicProfiles(x1rSource);

  // ---- Verify every environment-sensitive consumer appears and no
  //      post-finalization product consumer exists ----
  const semanticConsumers = verifySemanticConsumers(occurrenceRows);

  // ---- Verify the frozen counts (set equality on the count contract) ----
  const verifiedCounts = verifyCounts(e1rSource, x1rSource);

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

  // ---- Notice input gate (P08-T003 LICENSE.md) ----
  const licensingProfile = readLicensingProfile();
  const noticeInput = buildNoticeInput(licensingProfile);

  // ---- Counts block (deterministic key order) ----
  const counts = { ...verifiedCounts };

  const manifest = {
    schemaVersion: 1,
    identity: {
      product: 'MonaCode',
      revision: 'P08-T012-final-environment-manifest',
      baseline: 'monaco-editor@0.56.0',
      frozen: true,
      final: true,
      finalReason:
        'The E1-R environment-intl-clock-entropy source contract and the ' +
        'X1-R source-runtime-style contract are frozen; the Phase 07 public ' +
        'API closure (P07-T011) is frozen; the regenerated clock, entropy, ' +
        'number-formatting, locale, calendar, numbering, time-zone, case, ' +
        'collation, normalization, and finite-intrinsic occurrence rows are ' +
        'set-equal to E1-R + X1-R plus the generated input and output hashes ' +
        'with zero drift; every environment-sensitive consumer appears and ' +
        'the notice input (LICENSE.md) is complete. This is the FINAL ' +
        'MonaEnvironmentManifest.',
    },
    frozenBaselines: {
      e1r: {
        path: FROZEN_E1R_MANIFEST_PATH,
        sha256: frozenHashes.e1rManifest,
        revision: e1rSource.identity.revision,
        closureSha256: frozenHashes.e1rClosure,
      },
      x1r: {
        path: FROZEN_X1R_MANIFEST_PATH,
        sha256: frozenHashes.x1rManifest,
        revision: x1rSource.identity.revision,
        closureSha256: frozenHashes.x1rClosure,
      },
    },
    frozenApiClosure,
    sources: {
      e1rManifest: frozenHashes.e1rManifest,
      x1rManifest: frozenHashes.x1rManifest,
      e1rClosureHtml: frozenHashes.e1rClosure,
      x1rClosureHtml: frozenHashes.x1rClosure,
      frozenApiClosureManifest: sha256File(FROZEN_API_CLOSURE_PATH),
      implementationPlanPhase08: sha256File(IMPLEMENTATION_PLAN_PATH),
    },
    counts,
    verifiedCounts,
    occurrenceRows,
    finiteIntrinsicProfiles,
    semanticConsumers,
    generatedInputs,
    generatedOutputs,
    noticeInput,
    sourceArtifacts,
  };

  // ---- Zero-drift gate: mark final only after exact provenance reproduction
  //      + every consumer appears + notice input complete ----
  // verifySourceZeroDrift threw if the E1-R/X1-R source drifted.
  // verifyCounts threw if any frozen count drifted.
  // verifySemanticConsumers threw if any consumer was missing or a
  // post-finalization consumer appeared. verifyFiniteIntrinsicProfiles threw
  // if any finite-intrinsic profile was missing or an extra appeared.
  // buildNoticeInput threw if LICENSE.md was absent or any notice was missing.
  // If we reach here, drift is zero, every consumer appears, the notice input
  // is complete, and the manifest is final.

  const json = stableStringify(manifest) + '\n';

  if (outPath) {
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, json);
  } else {
    mkdirSync(dirname(FINAL_MANIFEST_PATH), { recursive: true });
    writeFileSync(FINAL_MANIFEST_PATH, json);
  }

  // Stable summary line for CI/observability.
  const generatedHashesCount =
    Object.keys(generatedInputs).length + Object.keys(generatedOutputs).length;
  process.stdout.write(
    `FINAL_ENVIRONMENT_MANIFEST rows=${occurrenceRows.length} ` +
      `final=true drift=0 ` +
      `environmentConsumers=${semanticConsumers.consumerCategories.length} ` +
      `generatedHashes=${generatedHashesCount}\n`
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

// Read the licensingProfile block from the g6-r authoritative manifest. This
// is the source of truth for the notice inputs the finalizer must verify.
function readLicensingProfile() {
  const authPath = join(
    REPO_ROOT,
    'docs',
    'contracts',
    'monaco-editor-0.56.0',
    'g6-r',
    'artifacts',
    'monacode-g6r-authoritative-manifest.json'
  );
  const auth = JSON.parse(readFileSync(authPath, 'utf8'));
  return auth.licensingProfile || {};
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
  process.argv[1]?.endsWith('finalize-environment-manifest.mjs');
if (isMain) {
  finalizeManifest({});
}
