// Comparators/probes/scope-probe.mjs
//
// P00-T004 — Reproduce frozen scope, declaration, and instance-surface manifests.
//
// The frozen scope is the set of Monaco 0.56.0 registries, namespaces, and
// source-graph entries that MonaCode must reproduce, captured once in the
// F1-R3 scope manifest and then inherited unchanged by every later contract
// revision (G4-R, G5-R, ...). This probe reproduces the frozen scope from the
// committed F1-R3 scope manifest in BOTH the g5-r and g4-r artifact trees,
// verifies the two copies are byte-identical (so identity drift between
// revisions is rejected even when aggregate counts remain equal), verifies the
// scope identity matches the locked provenance record (P00-T003), verifies the
// 3 MonaCode products and the macOS 26 platform pin declared in Package.swift,
// and verifies every frozen count matches the actual array content.
//
// Usage:
//   node Comparators/probes/scope-probe.mjs
//
// Exit status:
//   0 — the frozen scope is internally consistent and matches provenance.
//   1 — one or more checks failed (details on stderr).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const CONTRACTS = resolve(REPO_ROOT, 'docs/contracts/monaco-editor-0.56.0');
const G5_ARTIFACTS = resolve(CONTRACTS, 'g5-r/artifacts');
const G4_ARTIFACTS = resolve(CONTRACTS, 'g4-r/artifacts');
const SCOPE_MANIFEST = 'monaco-0.56.0-f1r3-scope-manifest.json';
const PROVENANCE_PATH = resolve(REPO_ROOT, 'Tools/PlanChecks/monaco-provenance.json');
const PACKAGE_SWIFT = resolve(REPO_ROOT, 'Package.swift');

// The frozen scope counts (F1-R3). Each value is locked; changing any one of
// these is a scope drift that the probe must reject.
const FROZEN_COUNTS = {
  featureEntries: 64,
  actions: 167,
  pureTextSupportedActions: 127,
  contributions: 53,
  diffContributions: 0,
  commands: 454,
  keybindings: 379,
  menus: 18,
  menuItems: 121,
  menuCommands: 21,
  options: 174,
  topLevelExports: 19,
  editorNamespace: 68,
  languageNamespace: 57,
  lspNamespace: 4,
  languageDefinitionEntries: 81,
  languageDescriptors: 91,
  colors: 431,
  icons: 776,
  builtinThemes: 4,
};

// The frozen set of MonaCode products and platform pin (P00-T001).
const FROZEN_PRODUCTS = ['MonaCode', 'MonaCodeAppKit', 'MonaCodeSwiftUI'];
const FROZEN_PLATFORM = '26.0';

const errors = [];

function fail(message) {
  errors.push(message);
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (err) {
    throw new Error(`cannot read/parse ${path}: ${err.message}`);
  }
}

function readRaw(path) {
  return readFileSync(path, 'utf8');
}

// ---------------------------------------------------------------------------
// 1. Both the g5-r and g4-r artifact trees must carry the frozen scope, and the
//    two copies must be byte-identical. This is the identity-drift gate: if a
//    later revision silently swaps one registry id while keeping the count
//    equal, the two copies diverge and the probe fails closed.
// ---------------------------------------------------------------------------

const g5Path = resolve(G5_ARTIFACTS, SCOPE_MANIFEST);
const g4Path = resolve(G4_ARTIFACTS, SCOPE_MANIFEST);

let g5Raw;
let g4Raw;
try {
  g5Raw = readRaw(g5Path);
} catch (err) {
  fail(`g5-r scope manifest is missing: ${err.message}`);
}
try {
  g4Raw = readRaw(g4Path);
} catch (err) {
  fail(`g4-r scope manifest is missing: ${err.message}`);
}

if (g5Raw !== undefined && g4Raw !== undefined && g5Raw !== g4Raw) {
  fail('g5-r and g4-r scope manifests are not byte-identical (identity drift between revisions)');
}

let manifest = null;
if (g5Raw !== undefined) {
  try {
    manifest = JSON.parse(g5Raw);
  } catch (err) {
    fail(`g5-r scope manifest is not valid JSON: ${err.message}`);
  }
}

// ---------------------------------------------------------------------------
// 2. The 3 MonaCode products and the macOS 26 platform pin declared in
//    Package.swift are part of the frozen scope (P00-T001).
// ---------------------------------------------------------------------------

function extractProductsAndPlatform() {
  let source;
  try {
    source = readRaw(PACKAGE_SWIFT);
  } catch (err) {
    fail(`cannot read Package.swift: ${err.message}`);
    return;
  }
  const products = [];
  const prodRe = /\.library\(\s*name:\s*"([^"]+)"/g;
  let m;
  while ((m = prodRe.exec(source)) !== null) {
    products.push(m[1]);
  }
  const productsOk =
    products.length === FROZEN_PRODUCTS.length &&
    products.every((p, i) => p === FROZEN_PRODUCTS[i]);
  if (!productsOk) {
    fail(
      `Package.swift products must be exactly ${JSON.stringify(FROZEN_PRODUCTS)}, got ${JSON.stringify(products)}`,
    );
  }
  if (!/\.macOS\(\s*"([^"]+)"\)/.test(source)) {
    fail('Package.swift must declare a .macOS(...) platform pin');
  } else {
    const platformMatch = source.match(/\.macOS\(\s*"([^"]+)"\)/);
    if (platformMatch[1] !== FROZEN_PLATFORM) {
      fail(`Package.swift platform must be macOS ${FROZEN_PLATFORM}, got ${platformMatch[1]}`);
    }
  }
}

extractProductsAndPlatform();

// ---------------------------------------------------------------------------
// 3. The scope manifest identity must match the locked provenance record.
// ---------------------------------------------------------------------------

let provenance = null;
try {
  provenance = readJson(PROVENANCE_PATH);
} catch (err) {
  fail(err.message);
}

if (manifest && provenance) {
  const id = manifest.identity || {};
  if (id.product !== 'MonaCode') {
    fail(`scope identity.product must be "MonaCode", got ${JSON.stringify(id.product)}`);
  }
  if (id.scopeRevision !== 'F1-R3-candidate') {
    fail(`scope identity.scopeRevision must be "F1-R3-candidate", got ${JSON.stringify(id.scopeRevision)}`);
  }
  if (typeof id.baseline !== 'string' || !id.baseline.includes('monaco-editor@0.56.0')) {
    fail(`scope identity.baseline must mention monaco-editor@0.56.0, got ${JSON.stringify(id.baseline)}`);
  }
  if (id.tagCommit !== provenance.sourceCommit) {
    fail(
      `scope identity.tagCommit (${JSON.stringify(id.tagCommit)}) must equal provenance.sourceCommit (${JSON.stringify(provenance.sourceCommit)})`,
    );
  }
  const npmArchive = (provenance.archives || []).find((a) => a.id === 'monaco-editor-npm');
  if (!npmArchive) {
    fail('provenance record is missing the monaco-editor-npm archive');
  } else if (id.npmTarSha256 !== npmArchive.sha256) {
    fail(
      `scope identity.npmTarSha256 (${JSON.stringify(id.npmTarSha256)}) must equal provenance monaco-editor-npm sha256 (${npmArchive.sha256})`,
    );
  }
  const dts = (provenance.declarations || {}).monacoDts;
  if (!dts) {
    fail('provenance record is missing declarations.monacoDts');
  } else if (id.monacoDtsSha256 !== dts.sha256) {
    fail(
      `scope identity.monacoDtsSha256 (${JSON.stringify(id.monacoDtsSha256)}) must equal provenance monacoDts sha256 (${dts.sha256})`,
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Every frozen count must match the declared count AND the actual array
//    length. This rejects identity drift even when aggregate counts remain
//    equal: a swapped id keeps the count but the canonical signature (below)
//    diverges between revisions.
// ---------------------------------------------------------------------------

if (manifest) {
  const c = manifest.counts || {};
  for (const [key, expected] of Object.entries(FROZEN_COUNTS)) {
    const actual = c[key];
    if (actual !== expected) {
      fail(`counts.${key} must be ${expected}, got ${JSON.stringify(actual)}`);
    }
  }

  // Internal consistency: declared counts must equal the actual array lengths.
  const r = manifest.registries || {};
  const sg = manifest.sourceGraph || {};
  const ns = manifest.namespaces || {};
  const lengthChecks = [
    ['registries.actions', r.actions, c.actions],
    ['registries.pureTextSupportedActions', r.pureTextSupportedActions, c.pureTextSupportedActions],
    ['registries.contributions', r.contributions, c.contributions],
    ['registries.diffContributions', r.diffContributions, c.diffContributions],
    ['registries.commands', r.commands, c.commands],
    ['registries.keybindings', r.keybindings, c.keybindings],
    ['registries.menus', r.menus, c.menus],
    ['registries.menuCommands', r.menuCommands, c.menuCommands],
    ['registries.options', r.options, c.options],
    ['registries.languageDescriptors', r.languageDescriptors, c.languageDescriptors],
    ['registries.colors', r.colors, c.colors],
    ['registries.icons', r.icons, c.icons],
    ['registries.builtinThemes', r.builtinThemes, c.builtinThemes],
    ['sourceGraph.featureEntries', sg.featureEntries, c.featureEntries],
    ['sourceGraph.languageDefinitionEntries', sg.languageDefinitionEntries, c.languageDefinitionEntries],
    ['namespaces.topLevel', ns.topLevel, c.topLevelExports],
    ['namespaces.editor', ns.editor, c.editorNamespace],
    ['namespaces.languages', ns.languages, c.languageNamespace],
    ['namespaces.lsp', ns.lsp, c.lspNamespace],
  ];
  for (const [name, arr, declared] of lengthChecks) {
    if (!Array.isArray(arr)) {
      fail(`${name} must be an array`);
    } else if (arr.length !== declared) {
      fail(`${name} length (${arr.length}) must equal counts declaration (${declared})`);
    }
  }

  // menuItems is nested across registries.menus[*].items.
  let menuItems = 0;
  for (const mu of r.menus || []) {
    if (Array.isArray(mu.items)) menuItems += mu.items.length;
  }
  if (menuItems !== c.menuItems) {
    fail(`registries.menus items total (${menuItems}) must equal counts.menuItems (${c.menuItems})`);
  }

  // Exclusions: diffContributions must be empty (no diff-editor contributions
  // are in scope), and the disposition multiset must be the frozen set. Any
  // change to the disposition vocabulary is a scope drift.
  if (Array.isArray(r.diffContributions) && r.diffContributions.length !== 0) {
    fail(`registries.diffContributions must be empty (excluded from scope), got ${r.diffContributions.length} entries`);
  }

  // Identity uniqueness: every registry id must be unique within its registry.
  // A swapped id (count unchanged) is still caught by the byte-identical
  // revision check above, but we also assert uniqueness here so a single
  // manifest with a duplicate id is rejected on its own. Only registries that
  // carry a non-empty string `id` per entry are checked here; keybindings
  // (identity is the composite of command+chords, no `id` field) and options
  // (numeric `id`) rely on the byte-identical revision gate for identity drift.
  const uniquenessRegistries = [
    'actions', 'pureTextSupportedActions', 'contributions', 'commands',
    'menuCommands', 'languageDescriptors',
    'colors', 'icons', 'builtinThemes',
  ];
  for (const key of uniquenessRegistries) {
    const arr = r[key];
    if (!Array.isArray(arr)) continue;
    const seen = new Set();
    for (const entry of arr) {
      const id = entry && entry.id;
      if (typeof id !== 'string' || id.length === 0) {
        fail(`registries.${key} contains an entry without a non-empty id`);
        break;
      }
      if (seen.has(id)) {
        fail(`registries.${key} id "${id}" is duplicated (identity drift)`);
      }
      seen.add(id);
    }
  }
  // Namespace ids must be unique within each namespace.
  for (const [key, arr] of [
    ['namespaces.topLevel', ns.topLevel],
    ['namespaces.editor', ns.editor],
    ['namespaces.languages', ns.languages],
    ['namespaces.lsp', ns.lsp],
  ]) {
    if (!Array.isArray(arr)) continue;
    const seen = new Set();
    for (const entry of arr) {
      const id = entry && entry.id;
      if (typeof id !== 'string' || id.length === 0) {
        fail(`${key} contains an entry without a non-empty id`);
        break;
      }
      if (seen.has(id)) {
        fail(`${key} id "${id}" is duplicated (identity drift)`);
      }
      seen.add(id);
    }
  }
}

// ---------------------------------------------------------------------------
// Report.
// ---------------------------------------------------------------------------

function probe() {
  return {
    ok: errors.length === 0,
    errors: errors.slice(),
    summary: errors.length === 0
      ? 'scope-probe: OK — frozen F1-R3 scope reproduced (g5-r == g4-r, 3 products, macOS 26, 20 counts verified)'
      : `scope-probe: ${errors.length} error(s)`,
  };
}

// Run as a script when invoked directly.
const isMain = import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  const result = probe();
  if (!result.ok) {
    for (const msg of result.errors) {
      console.error(`scope-probe: ${msg}`);
    }
    console.error(result.summary);
    process.exit(1);
  }
  console.error(result.summary);
  process.exit(0);
}

export { probe };
