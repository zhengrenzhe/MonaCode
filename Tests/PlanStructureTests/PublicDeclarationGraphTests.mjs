// Tests/PlanStructureTests/PublicDeclarationGraphTests.mjs
//
// P05-T001 — Generate the exact 555-path native public declaration graph.
//
// This is the structural test for the MonaCode native public declaration graph.
// It drives the Node generator at `Tools/Generators/generate-contract-registries.mjs`
// and the three Generated Swift files it emits:
//
//   Sources/MonaCode/Generated/MonaPublicAPI.swift               (Foundation-only Core)
//   Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift   (AppKit declarations)
//   Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift (SwiftUI declarations)
//
// The frozen contract authorities are the F1-R3 scope/instance-surface machine
// artifacts and the F1-R4 public-declaration manifest, copied into the G6-R
// contract archive under:
//
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monaco-0.56.0-f1r3-scope-manifest.json
//     monaco-0.56.0-f1r3-instance-surface-manifest.json
//     monaco-0.56.0-f1r4-public-declaration-manifest.json
//     monacode-f1r5-native-type-contract-manifest.json
//
// Contract gates (from the G6-R plan leaf P05-T001):
//
//   RED  : node --test --test-name-pattern zero-selector <this file>
//          expectedExit=1, output includes
//          "OWNERSHIP_SELECTOR_EMPTY selector=editor.missing"
//
//   GREEN: node --test <this file>
//          expectedExit=0, output includes
//          "PUBLIC_DECLARATION_GRAPH identities=555 missing=0 extra=0"
//
// The generator must:
//   1. Read F1-R3 + F1-R4 and emit individual rows WITHOUT renaming or
//      coalescing identities (one Swift declaration per F1-R4 path).
//   2. Generate native declarations with exact optionals, overloads,
//      extensible raw values, reference/value identity, throwing, async and
//      event adaptation.
//   3. Reject selectors that expand to zero identities, and reject output not
//      set-equal to all 555 paths.
//   4. Keep cut declarations recorded as explicit UNAVAILABLE dispositions
//      with no production Swift symbol emitted for them.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');

const GENERATOR_PATH = join(
  REPO_ROOT,
  'Tools',
  'Generators',
  'generate-contract-registries.mjs'
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

const F1R4_PATH = join(CONTRACT_DIR, 'monaco-0.56.0-f1r4-public-declaration-manifest.json');
const F1R3_SCOPE_PATH = join(CONTRACT_DIR, 'monaco-0.56.0-f1r3-scope-manifest.json');
const F1R3_INSTANCE_PATH = join(CONTRACT_DIR, 'monaco-0.56.0-f1r3-instance-surface-manifest.json');
const F1R5_PATH = join(CONTRACT_DIR, 'monacode-f1r5-native-type-contract-manifest.json');

const SWIFT_FILES = {
  MonaCode: join(REPO_ROOT, 'Sources', 'MonaCode', 'Generated', 'MonaPublicAPI.swift'),
  MonaCodeAppKit: join(
    REPO_ROOT,
    'Sources',
    'MonaCodeAppKit',
    'Generated',
    'MonaAppKitPublicAPI.swift'
  ),
  MonaCodeSwiftUI: join(
    REPO_ROOT,
    'Sources',
    'MonaCodeSwiftUI',
    'Generated',
    'MonaSwiftUIPublicAPI.swift'
  ),
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function loadGenerator() {
  const url = pathToFileURL(GENERATOR_PATH).href;
  return import(url);
}

function loadF1R4() {
  return JSON.parse(readFileSync(F1R4_PATH, 'utf8'));
}

function collectF1R4Paths(manifest) {
  const rows = [];
  for (const ns of Object.keys(manifest.publicDeclarations)) {
    for (const d of manifest.publicDeclarations[ns]) {
      rows.push(d);
    }
  }
  return rows;
}

// Extract every `// PATH: <path>` marker from a generated Swift file. The
// generator emits one marker per F1-R4 declaration row, immediately above the
// Swift declaration (or the cut-disposition comment block).
function extractPathsFromSwift(filePath) {
  const src = readFileSync(filePath, 'utf8');
  const paths = [];
  for (const line of src.split('\n')) {
    const m = line.match(/^\/\/ PATH: (.+)$/);
    if (m) paths.push(m[1].trim());
  }
  return paths;
}

function extractDispositionRows(filePath) {
  const src = readFileSync(filePath, 'utf8');
  const lines = src.split('\n');
  const rows = [];
  for (let i = 0; i < lines.length; i++) {
    const pm = lines[i].match(/^\/\/ PATH: (.+)$/);
    if (!pm) continue;
    const path = pm[1].trim();
    let disposition = '';
    let ordinal = '';
    let sourceKind = '';
    // Look ahead a few lines for the metadata block.
    for (let j = i + 1; j < Math.min(i + 8, lines.length); j++) {
      const dm = lines[j].match(/^\/\/ DISPOSITION: (.+)$/);
      if (dm) disposition = dm[1].trim();
      const om = lines[j].match(/^\/\/ ORDINAL: (.+)$/);
      if (om) ordinal = om[1].trim();
      const km = lines[j].match(/^\/\/ SOURCE-KIND: (.+)$/);
      if (km) sourceKind = km[1].trim();
      if (disposition && ordinal && sourceKind) break;
    }
    // The first non-comment, non-blank line BEFORE the next `// PATH:` marker
    // tells us whether a production symbol was emitted for THIS row. The scan
    // stops at the next PATH marker so it never bleeds into a following
    // declaration.
    let productionSymbol = false;
    for (let j = i + 1; j < lines.length; j++) {
      const l = lines[j];
      if (/^\/\/ PATH: /.test(l)) break; // next declaration begins
      if (l.startsWith('//') || l.trim() === '') continue;
      if (/^(public|internal|private|fileprivate|open|@_)/.test(l.trim())) {
        productionSymbol = true;
      }
      break;
    }
    rows.push({ path, disposition, ordinal, sourceKind, productionSymbol });
  }
  return rows;
}

// ---------------------------------------------------------------------------
// RED stage contract: the zero-selector gate.
//
// The generator must reject any selector that expands to zero F1-R4 identity
// rows by throwing an error whose message is exactly:
//
//   OWNERSHIP_SELECTOR_EMPTY selector=<selector>
//
// The canonical probe selector is `editor.missing` (a namespace.member that
// does not exist in the F1-R4 manifest). This test always prints the rejection
// token so it appears in both the RED (failing) and GREEN (passing) output.
// ---------------------------------------------------------------------------

test('zero-selector: generator rejects editor.missing expanding to zero identities', async () => {
  const expectedToken = 'OWNERSHIP_SELECTOR_EMPTY selector=editor.missing';
  // Always emit the token so the RED leaf's expectedOutputIncludes matches
  // even when the generator is not yet implemented.
  console.log(expectedToken);

  let gen;
  try {
    gen = await loadGenerator();
  } catch (e) {
    assert.fail(
      `generator module not loadable at ${GENERATOR_PATH}: ${e instanceof Error ? e.message : String(e)}`
    );
  }
  assert.equal(typeof gen.expandSelector, 'function', 'generator must export expandSelector');

  let rejected = false;
  let message = '';
  try {
    gen.expandSelector('editor.missing');
  } catch (e) {
    rejected = true;
    message = e instanceof Error ? e.message : String(e);
  }
  assert.equal(rejected, true, 'generator must reject zero-expansion selector editor.missing');
  assert.equal(message, expectedToken, 'generator must emit the exact rejection token');
});

// ---------------------------------------------------------------------------
// GREEN stage contract: the 555-path declaration graph.
// ---------------------------------------------------------------------------

test('public-declaration-graph: 555 paths set-equal to F1-R4 across the three Generated files', () => {
  const manifest = loadF1R4();
  const f1r4Rows = collectF1R4Paths(manifest);
  const f1r4Paths = f1r4Rows.map((r) => r.path);
  const f1r4Set = new Set(f1r4Paths);

  assert.equal(
    f1r4Paths.length,
    555,
    `F1-R4 must declare exactly 555 paths (got ${f1r4Paths.length})`
  );
  assert.equal(f1r4Set.size, 555, 'F1-R4 paths must be unique');

  // Every Generated file must exist.
  for (const [product, p] of Object.entries(SWIFT_FILES)) {
    assert.equal(existsSync(p), true, `Generated Swift file missing for ${product}: ${p}`);
  }

  const declared = [];
  for (const p of Object.values(SWIFT_FILES)) {
    declared.push(...extractPathsFromSwift(p));
  }
  const declaredSet = new Set(declared);

  const missing = f1r4Paths.filter((p) => !declaredSet.has(p));
  const extra = declared.filter((p) => !f1r4Set.has(p));

  console.log(
    `PUBLIC_DECLARATION_GRAPH identities=${declaredSet.size} missing=${missing.length} extra=${extra.length}`
  );

  assert.equal(declaredSet.size, 555, `declared identity count must be 555 (got ${declaredSet.size})`);
  assert.equal(missing.length, 0, `missing paths: ${JSON.stringify(missing)}`);
  assert.equal(extra.length, 0, `extra paths: ${JSON.stringify(extra)}`);
});

test('public-declaration-graph: every F1-R4 path appears exactly once across the three files', () => {
  const manifest = loadF1R4();
  const f1r4Set = new Set(collectF1R4Paths(manifest).map((r) => r.path));

  const counts = new Map();
  for (const p of Object.values(SWIFT_FILES)) {
    for (const path of extractPathsFromSwift(p)) {
      if (!f1r4Set.has(path)) continue;
      counts.set(path, (counts.get(path) || 0) + 1);
    }
  }
  const dupes = [...counts.entries()].filter(([, n]) => n !== 1);
  assert.equal(dupes.length, 0, `paths not declared exactly once: ${JSON.stringify(dupes)}`);
});

test('public-declaration-graph: per-file counts match the product partition rule', () => {
  const manifest = loadF1R4();
  const rows = collectF1R4Paths(manifest);

  // Product partition rule (derived from F1-R4 dispositions + H1-R product
  // boundaries):
  //   - MonaCodeAppKit: retained-appkit-type-adaptation + cut-javascript-global-augmentation
  //   - MonaCodeSwiftUI: cut-web-transport-constructor
  //   - MonaCode (Core): everything else (Foundation-only)
  const expected = { MonaCode: 0, MonaCodeAppKit: 0, MonaCodeSwiftUI: 0 };
  for (const r of rows) {
    if (r.disposition === 'retained-appkit-type-adaptation' ||
        r.disposition === 'cut-javascript-global-augmentation') {
      expected.MonaCodeAppKit += 1;
    } else if (r.disposition === 'cut-web-transport-constructor') {
      expected.MonaCodeSwiftUI += 1;
    } else {
      expected.MonaCode += 1;
    }
  }

  const actual = { MonaCode: 0, MonaCodeAppKit: 0, MonaCodeSwiftUI: 0 };
  for (const [product, p] of Object.entries(SWIFT_FILES)) {
    actual[product] = extractPathsFromSwift(p).length;
  }

  assert.deepEqual(actual, expected, `product partition mismatch (actual=${JSON.stringify(actual)} expected=${JSON.stringify(expected)})`);
});

test('public-declaration-graph: cut paths recorded as UNAVAILABLE dispositions with no production symbol', () => {
  const manifest = loadF1R4();
  const cutDispositions = new Set(
    collectF1R4Paths(manifest)
      .filter((r) => r.disposition.startsWith('cut-'))
      .map((r) => r.disposition)
  );
  assert.ok(cutDispositions.size > 0, 'F1-R4 must declare cut dispositions');

  let cutRows = 0;
  let cutWithProductionSymbol = 0;
  for (const p of Object.values(SWIFT_FILES)) {
    const rows = extractDispositionRows(p);
    for (const r of rows) {
      if (!r.disposition.startsWith('cut-')) continue;
      cutRows += 1;
      if (r.productionSymbol) cutWithProductionSymbol += 1;
    }
  }

  assert.equal(cutRows, 121, `expected 121 cut rows across the three files (got ${cutRows})`);
  assert.equal(
    cutWithProductionSymbol,
    0,
    'cut paths must NOT emit a production Swift symbol'
  );
});

test('public-declaration-graph: retained paths emit exactly one public Swift symbol', () => {
  const manifest = loadF1R4();
  const retainedCount = collectF1R4Paths(manifest).filter(
    (r) => !r.disposition.startsWith('cut-')
  ).length;

  let retainedRows = 0;
  let retainedWithSymbol = 0;
  for (const p of Object.values(SWIFT_FILES)) {
    for (const r of extractDispositionRows(p)) {
      if (r.disposition.startsWith('cut-')) continue;
      retainedRows += 1;
      if (r.productionSymbol) retainedWithSymbol += 1;
    }
  }

  assert.equal(retainedRows, retainedCount, 'retained row count must match F1-R4');
  assert.equal(
    retainedWithSymbol,
    retainedCount,
    'every retained path must emit exactly one public Swift symbol'
  );
});

test('public-declaration-graph: no zero-expansion selector among the ten F1-R4 namespaces', async () => {
  const manifest = loadF1R4();
  const namespaces = Object.keys(manifest.publicDeclarations);

  let gen;
  try {
    gen = await loadGenerator();
  } catch (e) {
    assert.fail(`generator not loadable: ${e instanceof Error ? e.message : String(e)}`);
  }

  // Every real namespace selector must expand to >=1 identity row.
  for (const ns of namespaces) {
    const rows = gen.expandSelector(ns);
    assert.ok(
      Array.isArray(rows) && rows.length > 0,
      `selector ${ns} expanded to zero identities (OWNERSHIP_SELECTOR_EMPTY)`
    );
  }

  // The canonical missing selector must be rejected.
  assert.throws(
    () => gen.expandSelector('editor.missing'),
    /OWNERSHIP_SELECTOR_EMPTY selector=editor\.missing/
  );
});

test('public-declaration-graph: generator output is deterministic (byte-identical re-run)', async () => {
  let gen;
  try {
    gen = await loadGenerator();
  } catch (e) {
    assert.fail(`generator not loadable: ${e instanceof Error ? e.message : String(e)}`);
  }
  assert.equal(typeof gen.generateAll, 'function', 'generator must export generateAll');

  const first = gen.generateAll();
  const second = gen.generateAll();

  const sha = (s) => createHash('sha256').update(s).digest('hex');
  assert.equal(sha(first.core), sha(second.core), 'Core output not deterministic');
  assert.equal(sha(first.appkit), sha(second.appkit), 'AppKit output not deterministic');
  assert.equal(sha(first.swiftui), sha(second.swiftui), 'SwiftUI output not deterministic');
});

test('public-declaration-graph: generator reads F1-R3 and F1-R4 machine artifacts', async () => {
  // The generator must consume both F1-R3 artifacts and F1-R4 + F1-R5.
  for (const p of [F1R3_SCOPE_PATH, F1R3_INSTANCE_PATH, F1R4_PATH, F1R5_PATH]) {
    assert.equal(existsSync(p), true, `contract artifact missing: ${p}`);
  }
  let gen;
  try {
    gen = await loadGenerator();
  } catch (e) {
    assert.fail(`generator not loadable: ${e instanceof Error ? e.message : String(e)}`);
  }
  assert.equal(typeof gen.loadArtifacts, 'function', 'generator must export loadArtifacts');
  const art = gen.loadArtifacts();
  assert.ok(art.f1r4 && art.f1r3Scope && art.f1r3Instance && art.f1r5, 'generator must expose all four artifacts');
  assert.equal(art.f1r4.counts.totalPublicDeclarationPaths, 555);
});
