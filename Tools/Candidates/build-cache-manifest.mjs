// build-cache-manifest.mjs
//
// P07-T007 — Close the bounded cache registry and provisional cache manifest.
//
// This is the Node manifest-builder for the MonaCode provisional cache
// manifest. It joins every strong derived cache registration (the closed set
// the Swift `MonaCacheRegistry` exposes) into ONE provisional manifest,
// recording each cache's stable id, owner, key shape, entry bound, byte bound,
// counter width, invalidation, eviction, memory-pressure action, and quiescent
// plateau. The manifest is PROVISIONAL: Phase 08 regeneration has not occurred
// yet (the manifest carries `provisional: true`).
//
// Contract source (frozen G6-R contract archive):
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monacode-h2r-runtime-resource-manifest.json   (H2-R cacheBounds rule)
//     monacode-d1r-diff-engine-manifest.json         (D1-R diff cache, max 11)
//     monacode-s1r-standalone-service-contract-manifest.json (S1-R 300/200/50/20)
//     monacode-e1r-environment-intl-clock-entropy-manifest.json (E1-R 10000x2)
//
// Runtime registry (the closed set, single source of truth):
//   Sources/MonaCode/Runtime/MonaCacheRegistry.swift  (P07-T007)
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/build-cache-manifest.mjs
//
// Writes:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t007-cache-manifest.json
//
// Determinism: byte-identical across re-runs (stable key order, trailing
// newline, no non-deterministic data sources).

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..');

export const MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p07-t007-cache-manifest.json'
);

const REGISTRY_SOURCE_PATH = join(
  REPO_ROOT,
  'Sources',
  'MonaCode',
  'Runtime',
  'MonaCacheRegistry.swift'
);

const CONTRACT_SOURCES = {
  h2r: join(
    REPO_ROOT,
    'docs',
    'contracts',
    'monaco-editor-0.56.0',
    'g6-r',
    'artifacts',
    'parent',
    'g5-r',
    'artifacts',
    'monacode-h2r-runtime-resource-manifest.json'
  ),
  d1r: join(
    REPO_ROOT,
    'docs',
    'contracts',
    'monaco-editor-0.56.0',
    'g6-r',
    'artifacts',
    'parent',
    'g5-r',
    'artifacts',
    'monacode-d1r-diff-engine-manifest.json'
  ),
  s1r: join(
    REPO_ROOT,
    'docs',
    'contracts',
    'monaco-editor-0.56.0',
    'g6-r',
    'artifacts',
    'parent',
    'g5-r',
    'artifacts',
    'monacode-s1r-standalone-service-contract-manifest.json'
  ),
  e1r: join(
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
  ),
};

// ---------------------------------------------------------------------------
// 1. The cache registration list (the closed set, single source of truth).
// ---------------------------------------------------------------------------

// This list is the authoritative provisional manifest data. It is derived from
// the same G6-R contract artifacts the Swift `MonaCacheRegistry` reads
// (D1-R / S1-R / E1-R). Phase 08 regeneration will re-emit this manifest from
// the finalized registry. Each row's fields match `MonaCacheRegistration`.
export const CACHE_REGISTRATIONS = [
  {
    id: 'session.suggestion-memory.recently-used',
    owner: 'S1-R/MonaSessionStore',
    keyShape: 'suggestion string (LRU de-dup: re-insert moves to back)',
    entryBound: 300,
    byteBound: 0,
    counterWidth: 32,
    invalidation: 'process termination clears; editor disposal does not',
    eviction: 'LRU',
    quiescentPlateau: 300,
    memoryPressure:
      'evict recomputable unpinned entries; never discard semantic state',
  },
  {
    id: 'session.suggestion-prefix',
    owner: 'S1-R/MonaSessionStore',
    keyShape: 'prefix string (LRU de-dup)',
    entryBound: 200,
    byteBound: 0,
    counterWidth: 32,
    invalidation: 'process termination clears; editor disposal does not',
    eviction: 'LRU',
    quiescentPlateau: 200,
    memoryPressure:
      'evict recomputable unpinned entries; never discard semantic state',
  },
  {
    id: 'session.command-mru',
    owner: 'S1-R/MonaSessionStore',
    keyShape: 'command id (LRU de-dup)',
    entryBound: 50,
    byteBound: 0,
    counterWidth: 32,
    invalidation: 'process termination clears; editor disposal does not',
    eviction: 'LRU',
    quiescentPlateau: 50,
    memoryPressure:
      'evict recomputable unpinned entries; never discard semantic state',
  },
  {
    id: 'session.codelens-lru',
    owner: 'S1-R/MonaSessionStore',
    keyShape: 'CodeLens cache key (LRU)',
    entryBound: 20,
    byteBound: 0,
    counterWidth: 32,
    invalidation: 'process termination clears; editor disposal does not',
    eviction: 'LRU',
    quiescentPlateau: 20,
    memoryPressure:
      'evict recomputable unpinned entries; never discard semantic state',
  },
  {
    id: 'normalizer.compose',
    owner: 'E1-R/MonaNormalizer',
    keyShape:
      '(normalizationForm, [UInt16] input) — NFC/NFKC share compose cache',
    entryBound: 10000,
    byteBound: 0,
    counterWidth: 32,
    invalidation:
      'recomputable; evict on memory pressure or editor/process disposal',
    eviction: 'LRU',
    quiescentPlateau: 10000,
    memoryPressure:
      'evict recomputable unpinned entries; never discard semantic state',
  },
  {
    id: 'normalizer.decompose',
    owner: 'E1-R/MonaNormalizer',
    keyShape:
      '(normalizationForm, [UInt16] input) — NFD/NFKD share decompose cache',
    entryBound: 10000,
    byteBound: 0,
    counterWidth: 32,
    invalidation:
      'recomputable; evict on memory pressure or editor/process disposal',
    eviction: 'LRU',
    quiescentPlateau: 10000,
    memoryPressure:
      'evict recomputable unpinned entries; never discard semantic state',
  },
  {
    id: 'diff.document-result.process-fifo',
    owner: 'D1-R/MonaDiffCoordinator',
    keyShape:
      'originalUri+modifiedUri+originalVersionId+modifiedVersionId+originalAlternativeVersionId+modifiedAlternativeVersionId+optionsHash',
    entryBound: 11,
    byteBound: 0,
    counterWidth: 32,
    invalidation:
      'version/context mismatch prevents stale reuse; FIFO and process termination remove entries',
    eviction: 'FIFO',
    quiescentPlateau: 11,
    memoryPressure:
      'H2 may evict this recomputable cache early without changing semantic state; ordinary execution must preserve the source FIFO rule and counters',
  },
];

// ---------------------------------------------------------------------------
// 2. Validation — reject any drift from the frozen contract bounds.
// ---------------------------------------------------------------------------

const REQUIRED_FIELDS = [
  'id',
  'owner',
  'keyShape',
  'entryBound',
  'byteBound',
  'counterWidth',
  'invalidation',
  'eviction',
  'quiescentPlateau',
  'memoryPressure',
];

/**
 * Validate every registration row. Reject mismatches by throwing.
 *
 * Validation rules (from the G6-R plan leaf P07-T007 + H2-R cacheBounds):
 *   1. Every required field is present and non-empty (positive for bounds).
 *   2. The closed set is exactly 7 caches (4 suggestion + 2 normalization + 1 diff).
 *   3. No duplicate ids (set-equality).
 *   4. The specific bounds are present: 300 / 200 / 50 / 20, 10000 x2, 11.
 *   5. quiescentPlateau <= entryBound (steady state settles at or below bound).
 *   6. eviction is FIFO or LRU.
 *   7. The registry source file exists (provenance).
 */
export function validateRegistrations(rows) {
  if (!Array.isArray(rows) || rows.length !== 7) {
    throw new Error(
      `CACHE_SET_MISMATCH expected=7 actual=${rows ? rows.length : 'n/a'} ` +
        '(4 suggestion + 2 normalization + 1 diff)'
    );
  }
  const seen = new Set();
  for (const r of rows) {
    for (const f of REQUIRED_FIELDS) {
      if (r[f] === undefined || r[f] === null || r[f] === '') {
        throw new Error(`ROW_FIELD_EMPTY id=${r.id} field=${f}`);
      }
    }
    if (r.entryBound <= 0) {
      throw new Error(`ENTRY_BOUND_NONPOSITIVE id=${r.id} entryBound=${r.entryBound}`);
    }
    if (r.byteBound < 0) {
      throw new Error(`BYTE_BOUND_NEGATIVE id=${r.id} byteBound=${r.byteBound}`);
    }
    if (r.counterWidth <= 0) {
      throw new Error(`COUNTER_WIDTH_NONPOSITIVE id=${r.id} counterWidth=${r.counterWidth}`);
    }
    if (r.quiescentPlateau <= 0) {
      throw new Error(`PLATEAU_NONPOSITIVE id=${r.id} plateau=${r.quiescentPlateau}`);
    }
    if (r.quiescentPlateau > r.entryBound) {
      throw new Error(
        `PLATEAU_EXCEEDS_BOUND id=${r.id} plateau=${r.quiescentPlateau} entryBound=${r.entryBound}`
      );
    }
    if (r.eviction !== 'FIFO' && r.eviction !== 'LRU') {
      throw new Error(`EVICTION_INVALID id=${r.id} eviction=${r.eviction}`);
    }
    if (seen.has(r.id)) {
      throw new Error(`DUPLICATE_CACHE_ID id=${r.id}`);
    }
    seen.add(r.id);
  }

  // Rule 4: the specific bounds are present (300 / 200 / 50 / 20, 10000 x2, 11).
  const byId = new Map(rows.map((r) => [r.id, r]));
  const expectedBounds = {
    'session.suggestion-memory.recently-used': 300,
    'session.suggestion-prefix': 200,
    'session.command-mru': 50,
    'session.codelens-lru': 20,
    'normalizer.compose': 10000,
    'normalizer.decompose': 10000,
    'diff.document-result.process-fifo': 11,
  };
  for (const [id, bound] of Object.entries(expectedBounds)) {
    const r = byId.get(id);
    if (!r) {
      throw new Error(`EXPECTED_CACHE_MISSING id=${id}`);
    }
    if (r.entryBound !== bound) {
      throw new Error(
        `BOUND_MISMATCH id=${id} expected=${bound} actual=${r.entryBound}`
      );
    }
  }

  // Rule 7: the registry source file exists.
  if (!existsSync(REGISTRY_SOURCE_PATH)) {
    throw new Error(`REGISTRY_SOURCE_MISSING path=${REGISTRY_SOURCE_PATH}`);
  }
}

// ---------------------------------------------------------------------------
// 3. Manifest assembly + deterministic JSON serialization.
// ---------------------------------------------------------------------------

/**
 * Assemble the provisional cache manifest. Returns the manifest object. If
 * outPath is provided, also writes the deterministic JSON; otherwise writes to
 * the default committed artifact path.
 */
export function buildCacheManifest({ outPath } = {}) {
  const rows = CACHE_REGISTRATIONS.map((r) => ({ ...r }));
  validateRegistrations(rows);

  const counts = {
    suggestion: rows.filter((r) => r.id.startsWith('session.')).length,
    normalization: rows.filter((r) => r.id.startsWith('normalizer.')).length,
    diff: rows.filter((r) => r.id.startsWith('diff.')).length,
    total: rows.length,
  };

  const sources = {
    h2rRuntimeResourceManifest: sha256File(CONTRACT_SOURCES.h2r),
    d1rDiffEngineManifest: sha256File(CONTRACT_SOURCES.d1r),
    s1rStandaloneServiceContractManifest: sha256File(CONTRACT_SOURCES.s1r),
    e1rEnvironmentIntlClockEntropyManifest: sha256File(CONTRACT_SOURCES.e1r),
    cacheRegistrySource: sha256File(REGISTRY_SOURCE_PATH),
  };

  const manifest = {
    schemaVersion: 1,
    identity: {
      product: 'MonaCode',
      revision: 'P07-T007-provisional-cache-manifest',
      baseline: 'monaco-editor@0.56.0',
      provisional: true,
      provisionalReason:
        'Phase 08 cache manifest regeneration has not occurred; this ' +
        'manifest will be finalized then from the closed cache registry.',
    },
    sources,
    counts,
    rows,
  };

  const json = stableStringify(manifest) + '\n';
  const target = outPath || MANIFEST_PATH;
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, json);

  // Stable summary line for CI/observability.
  process.stdout.write(
    `CACHE_MANIFEST rows=${rows.length} provisional=true ` +
      `suggestion=${counts.suggestion} normalization=${counts.normalization} ` +
      `diff=${counts.diff} bounds=300/200/50/20+10000x2+11\n`
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

// When invoked directly, write the manifest to the committed artifact path.
const isMain =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith('build-cache-manifest.mjs');
if (isMain) {
  buildCacheManifest({});
}
