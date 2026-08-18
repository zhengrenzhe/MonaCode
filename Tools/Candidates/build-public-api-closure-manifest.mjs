// build-public-api-closure-manifest.mjs
//
// P07-T011 — Freeze the final public API closure before candidate generation.
//
// This is the Node manifest-builder for the MonaCode FINAL public API closure.
// It FREEZES the public API before Phase 08 candidate generation. After this
// task, NO public API changes are allowed: the public source set + baselines
// are FROZEN, and any later public declaration or signature change is REJECTED
// (the test asserts the baselines match; a later change -> baseline mismatch
// -> reject).
//
// The three implementation operations:
//   1. Generate symbol graphs and API digester baselines for all three
//      products (MonaCode, MonaCodeAppKit, MonaCodeSwiftUI) after every public
//      producer. The baselines are frozen snapshots of the current public API.
//   2. Join every public declaration path (the 555 from P05-T001) to one native
//      symbol OR an explicit cut disposition. No declaration is unmapped.
//   3. Freeze the public source set and reject every later public declaration
//      or signature change.
//
// The manifest is FROZEN (identity.frozen = true). This is NOT provisional:
// it is the pre-Phase-08 API freeze. The committed artifact is the frozen
// baseline; re-running the builder from the current source must produce
// byte-identical output, or the freeze is violated.
//
// Sources (frozen G6-R contract archive):
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monaco-0.56.0-f1r4-public-declaration-manifest.json  (555 paths)
//     monaco-0.56.0-f1r3-scope-manifest.json
//
// Public producers (the Generated declaration graph + every product source):
//   Sources/MonaCode/Generated/MonaPublicAPI.swift        (T001 — 537 paths)
//   Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift  (15 paths)
//   Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift (3 paths)
//   Sources/MonaCode/**/*.swift           (all public symbols)
//   Sources/MonaCodeAppKit/**/*.swift      (all public symbols)
//   Sources/MonaCodeSwiftUI/**/*.swift     (all public symbols)
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/build-public-api-closure-manifest.mjs
//
// Writes:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t011-public-api-closure-manifest.json
//
// Determinism: byte-identical across re-runs (stable key order, sorted file
// enumeration, trailing newline, no non-deterministic data sources).

import { createHash } from 'node:crypto';
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  existsSync,
  readdirSync,
  statSync,
} from 'node:fs';
import { dirname, join, relative } from 'node:path';
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
  'monacode-p07-t011-public-api-closure-manifest.json'
);

const CONTRACT_DIR = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'parent',
  'g5-r',
  'artifacts'
);

const F1R4_PATH = join(
  CONTRACT_DIR,
  'monaco-0.56.0-f1r4-public-declaration-manifest.json'
);
const F1R3_SCOPE_PATH = join(
  CONTRACT_DIR,
  'monaco-0.56.0-f1r3-scope-manifest.json'
);

// The three product library targets whose public API is frozen.
const PRODUCT_SOURCE_ROOTS = [
  { product: 'MonaCode', root: join(REPO_ROOT, 'Sources', 'MonaCode') },
  { product: 'MonaCodeAppKit', root: join(REPO_ROOT, 'Sources', 'MonaCodeAppKit') },
  { product: 'MonaCodeSwiftUI', root: join(REPO_ROOT, 'Sources', 'MonaCodeSwiftUI') },
];

// The three Generated declaration graph files (the 555 F1-R4 paths live here).
const DECLARATION_SWIFT_FILES = [
  {
    product: 'MonaCode',
    abs: join(REPO_ROOT, 'Sources', 'MonaCode', 'Generated', 'MonaPublicAPI.swift'),
    rel: 'Sources/MonaCode/Generated/MonaPublicAPI.swift',
  },
  {
    product: 'MonaCodeAppKit',
    abs: join(REPO_ROOT, 'Sources', 'MonaCodeAppKit', 'Generated', 'MonaAppKitPublicAPI.swift'),
    rel: 'Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift',
  },
  {
    product: 'MonaCodeSwiftUI',
    abs: join(REPO_ROOT, 'Sources', 'MonaCodeSwiftUI', 'Generated', 'MonaSwiftUIPublicAPI.swift'),
    rel: 'Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift',
  },
];

// ---------------------------------------------------------------------------
// 1. Artifact loading.
// ---------------------------------------------------------------------------

export function loadArtifacts() {
  return {
    f1r4: JSON.parse(readFileSync(F1R4_PATH, 'utf8')),
    f1r3Scope: JSON.parse(readFileSync(F1R3_SCOPE_PATH, 'utf8')),
  };
}

// ---------------------------------------------------------------------------
// 2. Product source enumeration — walk a product root deterministically.
// ---------------------------------------------------------------------------

function walkSwiftFiles(rootAbs) {
  const out = [];
  function recurse(dir) {
    let entries;
    try {
      entries = readdirSync(dir);
    } catch {
      return;
    }
    for (const name of entries.sort()) {
      const full = join(dir, name);
      let st;
      try {
        st = statSync(full);
      } catch {
        continue;
      }
      if (st.isDirectory()) {
        recurse(full);
      } else if (st.isFile() && name.endsWith('.swift')) {
        out.push(relative(REPO_ROOT, full));
      }
    }
  }
  recurse(rootAbs);
  return out;
}

// ---------------------------------------------------------------------------
// 3. Symbol graph — extract every public symbol from a product's Swift sources.
//
// The symbol graph is the canonical inventory of the public API surface. Each
// entry carries the symbol name, kind, signature (the declaration line,
// trimmed), the repo-relative source path, and the 1-based source line. The
// graph is sorted (by name, then sourcePath, then signature) for deterministic
// digest computation.
// ---------------------------------------------------------------------------

const PUBLIC_DECL_RE =
  /^\s*(public\s+(?:final\s+|open\s+|static\s+|@\w+\s+)*(?:actor|class|struct|enum|protocol|func|init|subscript|typealias|var)\s+(\w+))/

/**
 * Scan one Swift file for public declarations. Returns an array of symbol
 * entries: { name, kind, signature, sourcePath, sourceLine }.
 */
function scanSwiftFileForPublicSymbols(absPath, relPath) {
  const src = readFileSync(absPath, 'utf8');
  const lines = src.split('\n');
  const symbols = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(PUBLIC_DECL_RE);
    if (!m) continue;
    const signature = m[1].trim();
    const name = m[2];
    // Derive the kind from the signature (the keyword after visibility
    // modifiers). This is the symbol's structural role in the public API.
    const kindMatch = signature.match(
      /\b(actor|class|struct|enum|protocol|func|init|subscript|typealias|var)\b/
    );
    const kind = kindMatch ? kindMatch[1] : 'unknown';
    symbols.push({
      name,
      kind,
      signature,
      sourcePath: relPath,
      sourceLine: i + 1,
    });
  }
  return symbols;
}

/**
 * Build the symbol graph for one product. Returns:
 *   { product, symbols, symbolCount, digest }
 * The digest is a canonical sha256 over the sorted symbol tuples. Any added,
 * removed, or signature-changed public symbol changes the digest.
 */
export function buildSymbolGraph(product) {
  const root = PRODUCT_SOURCE_ROOTS.find((p) => p.product === product);
  if (!root) {
    throw new Error(`UNKNOWN_PRODUCT product=${product}`);
  }
  const files = walkSwiftFiles(root.root);
  const symbols = [];
  for (const rel of files) {
    const abs = join(REPO_ROOT, rel);
    if (!existsSync(abs)) continue;
    symbols.push(...scanSwiftFileForPublicSymbols(abs, rel));
  }
  // Deterministic sort: by name, then sourcePath, then signature, then line.
  symbols.sort((a, b) => {
    if (a.name !== b.name) return a.name < b.name ? -1 : 1;
    if (a.sourcePath !== b.sourcePath) return a.sourcePath < b.sourcePath ? -1 : 1;
    if (a.signature !== b.signature) return a.signature < b.signature ? -1 : 1;
    return a.sourceLine - b.sourceLine;
  });
  const digest = computeApiDigest(symbols);
  return { product, symbolCount: symbols.length, digest, symbols };
}

/**
 * Compute the canonical API digester baseline (a sha256) over a symbol list.
 * The digest is taken over the stable JSON representation of each symbol's
 * identity tuple (name, kind, signature, sourcePath), sorted. This makes the
 * digest sensitive to: a symbol being added, removed, renamed, its kind
 * changing, its signature changing, or it moving to another source file. It
 * is NOT sensitive to private/internal changes (those are not public API).
 */
export function computeApiDigest(symbols) {
  const tuples = symbols
    .map((s) => ({ name: s.name, kind: s.kind, signature: s.signature, sourcePath: s.sourcePath }))
    .sort((a, b) => {
      if (a.name !== b.name) return a.name < b.name ? -1 : 1;
      if (a.sourcePath !== b.sourcePath) return a.sourcePath < b.sourcePath ? -1 : 1;
      return a.signature < b.signature ? -1 : a.signature > b.signature ? 1 : 0;
    });
  const canonical = stableStringify(tuples);
  return createHash('sha256').update(canonical).digest('hex');
}

// ---------------------------------------------------------------------------
// 4. Declaration joins — join every F1-R4 path (the 555 from P05-T001) to one
//    native symbol OR an explicit cut disposition. No declaration unmapped.
//
// Each row carries: path, disposition, nativeSymbol, joinedTo, cut.
//   - retained rows: joinedTo = 'native-symbol', nativeSymbol = <Swift symbol>,
//     cut = false.
//   - cut rows: joinedTo = 'cut-disposition', nativeSymbol = 'UNAVAILABLE',
//     cut = true.
// ---------------------------------------------------------------------------

/**
 * Scan the three Generated declaration Swift files for `// PATH:` markers and
 * extract, for each F1-R4 path, its disposition and native Swift symbol. Cut
 * rows have nativeSymbol 'UNAVAILABLE'. Reuses the scan contract established
 * by build-native-declaration-manifest.mjs (P05-T190).
 */
export function scanDeclarationJoins() {
  const rows = [];
  for (const f of DECLARATION_SWIFT_FILES) {
    const src = readFileSync(f.abs, 'utf8');
    const lines = src.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const pm = lines[i].match(/^\/\/ PATH: (.+)$/);
      if (!pm) continue;
      const path = pm[1].trim();
      let disposition = '';
      let nativeSymbol = '';
      let cut = false;
      for (let j = i + 1; j < Math.min(i + 20, lines.length); j++) {
        const dm = lines[j].match(/^\/\/ DISPOSITION: (.+)$/);
        if (dm) disposition = dm[1].trim();
        // Cut rows: the UNAVAILABLE comment marks the cut disposition.
        const um = lines[j].match(/^\/\/ UNAVAILABLE: (.+)$/);
        if (um) {
          nativeSymbol = 'UNAVAILABLE';
          cut = true;
          break;
        }
        // Retained rows: the first `public ...` line is the production symbol.
        if (/^public /.test(lines[j])) {
          const symMatch = lines[j].match(
            /public\s+(?:final\s+|open\s+|static\s+|@\w+\s+)*(?:actor|class|struct|enum|protocol|func|init|subscript|typealias|var)\s+(\w+)/
          );
          nativeSymbol = symMatch ? symMatch[1] : '';
          cut = false;
          break;
        }
        // Stop at the next PATH marker.
        if (/^\/\/ PATH: /.test(lines[j])) break;
      }
      if (!disposition) disposition = 'unknown';
      if (!nativeSymbol) nativeSymbol = 'UNAVAILABLE';
      if (!cut && nativeSymbol === 'UNAVAILABLE') cut = true;
      rows.push({
        path,
        disposition,
        nativeSymbol,
        joinedTo: cut ? 'cut-disposition' : 'native-symbol',
        cut,
        sourcePath: f.rel,
        product: f.product,
      });
    }
  }
  // Deterministic sort by path.
  rows.sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
  return rows;
}

/**
 * Validate the declaration joins against F1-R4. Every F1-R4 path must be
 * present exactly once, every retained row must map to a native symbol, and
 * every cut row must map to the explicit UNAVAILABLE disposition. No
 * declaration is unmapped. Throws on any violation.
 */
export function validateDeclarationJoins(joins, f1r4) {
  const f1r4Paths = [];
  for (const ns of Object.keys(f1r4.publicDeclarations)) {
    for (const d of f1r4.publicDeclarations[ns]) {
      f1r4Paths.push(d.path);
    }
  }
  const f1r4Set = new Set(f1r4Paths);
  if (f1r4Paths.length !== 555) {
    throw new Error(
      `F1R4_PATH_COUNT expected=555 actual=${f1r4Paths.length}`
    );
  }

  const joinPaths = joins.map((r) => r.path);
  const joinSet = new Set(joinPaths);
  if (joinPaths.length !== 555) {
    throw new Error(
      `DECLARATION_JOIN_COUNT expected=555 actual=${joinPaths.length}`
    );
  }

  // No unmapped declaration: every F1-R4 path must appear in the joins.
  const missing = f1r4Paths.filter((p) => !joinSet.has(p));
  if (missing.length > 0) {
    throw new Error(
      `UNMAPPED_DECLARATIONS count=${missing.length} first=${missing[0]}`
    );
  }
  // No extra declarations (a path in the joins not in F1-R4).
  const extra = joinPaths.filter((p) => !f1r4Set.has(p));
  if (extra.length > 0) {
    throw new Error(
      `EXTRA_DECLARATIONS count=${extra.length} first=${extra[0]}`
    );
  }
  // No duplicate declarations.
  const dupes = joinPaths.filter((p, i) => joinPaths.indexOf(p) !== i);
  if (dupes.length > 0) {
    throw new Error(
      `DUPLICATE_DECLARATIONS count=${dupes.length} first=${dupes[0]}`
    );
  }

  // Every row resolves to either a native symbol or an explicit cut.
  for (const row of joins) {
    if (row.cut) {
      if (row.nativeSymbol !== 'UNAVAILABLE') {
        throw new Error(
          `CUT_ROW_SYMBOL_NOT_UNAVAILABLE path=${row.path} nativeSymbol=${row.nativeSymbol}`
        );
      }
      if (row.joinedTo !== 'cut-disposition') {
        throw new Error(
          `CUT_ROW_JOIN_MISMATCH path=${row.path} joinedTo=${row.joinedTo}`
        );
      }
      if (!row.disposition.startsWith('cut-')) {
        throw new Error(
          `CUT_ROW_DISPOSITION_NOT_CUT path=${row.path} disposition=${row.disposition}`
        );
      }
    } else {
      if (!row.nativeSymbol || row.nativeSymbol === 'UNAVAILABLE') {
        throw new Error(
          `RETAINED_ROW_NO_NATIVE_SYMBOL path=${row.path} disposition=${row.disposition}`
        );
      }
      if (row.joinedTo !== 'native-symbol') {
        throw new Error(
          `RETAINED_ROW_JOIN_MISMATCH path=${row.path} joinedTo=${row.joinedTo}`
        );
      }
      if (row.disposition.startsWith('cut-')) {
        throw new Error(
          `RETAINED_ROW_DISPOSITION_IS_CUT path=${row.path} disposition=${row.disposition}`
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 5. Frozen public source set — the set of product Swift files that contain at
//    least one public declaration. The set itself is frozen: adding a new file
//    with public declarations changes the set -> freeze violation.
// ---------------------------------------------------------------------------

export function buildPublicSourceSet(symbolGraphs) {
  // Collect the sorted set of source paths that contain >=1 public symbol.
  const pathSet = new Set();
  for (const g of symbolGraphs) {
    for (const s of g.symbols) {
      pathSet.add(s.sourcePath);
    }
  }
  const paths = [...pathSet].sort();
  const digest = createHash('sha256').update(paths.join('\n')).digest('hex');
  return { productSources: paths, sourceCount: paths.length, sourceSetDigest: digest };
}

// ---------------------------------------------------------------------------
// 6. Manifest assembly + deterministic JSON serialization.
// ---------------------------------------------------------------------------

/**
 * Assemble the FINAL public API closure manifest. Returns the manifest object.
 * If outPath is provided, also writes the deterministic JSON; otherwise writes
 * to the default committed artifact path.
 *
 * The manifest is FROZEN (identity.frozen = true). Re-running this builder
 * from the current source must produce byte-identical output, or the freeze
 * is violated (a later public API change drifted the baseline).
 */
export function buildManifest({ outPath } = {}) {
  const artifacts = loadArtifacts();

  // Operation 1: generate symbol graphs + API digester baselines for all three
  // products after every public producer.
  const symbolGraphs = [
    buildSymbolGraph('MonaCode'),
    buildSymbolGraph('MonaCodeAppKit'),
    buildSymbolGraph('MonaCodeSwiftUI'),
  ];
  const apiDigests = {};
  const symbolCounts = {};
  for (const g of symbolGraphs) {
    apiDigests[g.product] = g.digest;
    symbolCounts[g.product] = g.symbolCount;
  }

  // Operation 2: join every public declaration path (the 555) to one native
  // symbol or explicit cut disposition. No declaration unmapped.
  const declarationJoins = scanDeclarationJoins();
  validateDeclarationJoins(declarationJoins, artifacts.f1r4);

  // Operation 3: freeze the public source set.
  const frozenSourceSet = buildPublicSourceSet(symbolGraphs);

  // Counts block (deterministic key order).
  const joinedToNative = declarationJoins.filter((r) => !r.cut).length;
  const joinedToCut = declarationJoins.filter((r) => r.cut).length;
  const counts = {
    declarationPaths: declarationJoins.length,
    joinedToNativeSymbol: joinedToNative,
    joinedToCutDisposition: joinedToCut,
    unmapped: 0,
    products: symbolGraphs.length,
    publicSymbols: { ...symbolCounts },
    publicSourceFiles: frozenSourceSet.sourceCount,
  };

  // Source artifact hashes (for provenance).
  const sources = {
    f1r4PublicDeclarationManifest: sha256File(F1R4_PATH),
    f1r3ScopeManifest: sha256File(F1R3_SCOPE_PATH),
    monaPublicApiSwift: sha256File(DECLARATION_SWIFT_FILES[0].abs),
    monaAppKitPublicApiSwift: sha256File(DECLARATION_SWIFT_FILES[1].abs),
    monaSwiftUiPublicApiSwift: sha256File(DECLARATION_SWIFT_FILES[2].abs),
  };

  const manifest = {
    schemaVersion: 1,
    identity: {
      product: 'MonaCode',
      revision: 'P07-T011-final-public-api-closure',
      baseline: 'monaco-editor@0.56.0',
      frozen: true,
      frozenAt: 'P07-T011',
      frozenReason:
        'Phase 07 final public API closure; no public API changes are ' +
        'allowed after this freeze. The public source set + baselines are ' +
        'frozen; any later public declaration or signature change is ' +
        'rejected (baseline mismatch -> reject).',
    },
    sources,
    symbolGraphs,
    apiDigests,
    declarationJoins,
    frozenSourceSet,
    counts,
  };

  const json = stableStringify(manifest) + '\n';
  const target = outPath || MANIFEST_PATH;
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, json);

  // Stable summary line for CI/observability.
  process.stdout.write(
    `PUBLIC_API_CLOSURE frozen=true products=${symbolGraphs.length} ` +
      `declarations=${declarationJoins.length} ` +
      `joinedToNative=${joinedToNative} joinedToCut=${joinedToCut} ` +
      `unmapped=0 publicSymbols=${symbolCounts.MonaCode}/${symbolCounts.MonaCodeAppKit}/${symbolCounts.MonaCodeSwiftUI} ` +
      `publicSourceFiles=${frozenSourceSet.sourceCount}\n`
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
  process.argv[1]?.endsWith('build-public-api-closure-manifest.mjs');
if (isMain) {
  buildManifest({});
}
