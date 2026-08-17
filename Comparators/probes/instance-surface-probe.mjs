// Comparators/probes/instance-surface-probe.mjs
//
// P00-T004 — Reproduce frozen scope, declaration, and instance-surface manifests.
//
// The instance surface is the public editor API declaration graph: the five
// editor interfaces (IEditor, ICodeEditor, IStandaloneCodeEditor, IDiffEditor,
// IStandaloneDiffEditor), their inheritance bases, their own/full declaration
// lists, and the native-type replacements for DOM-bearing members. It is
// captured once in the F1-R3 instance-surface manifest and inherited
// unchanged by every later contract revision.
//
// This probe reproduces the frozen instance surface from the committed
// manifest in BOTH the g5-r and g4-r artifact trees, verifies the two copies
// are byte-identical (so identity drift between revisions is rejected even
// when aggregate counts remain equal), verifies the manifest identity matches
// the locked monaco.d.ts provenance hash, and verifies every per-interface
// declaration count matches the actual member list length and the frozen
// expected values.
//
// Usage:
//   node Comparators/probes/instance-surface-probe.mjs
//
// Exit status:
//   0 — the frozen instance surface is internally consistent.
//   1 — one or more checks failed (details on stderr).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const CONTRACTS = resolve(REPO_ROOT, 'docs/contracts/monaco-editor-0.56.0');
const G5_ARTIFACTS = resolve(CONTRACTS, 'g5-r/artifacts');
const G4_ARTIFACTS = resolve(CONTRACTS, 'g4-r/artifacts');
const INSTANCE_MANIFEST = 'monaco-0.56.0-f1r3-instance-surface-manifest.json';
const PROVENANCE_PATH = resolve(REPO_ROOT, 'Tools/PlanChecks/monaco-provenance.json');

// The frozen instance surface: five interfaces, each with its own/full
// declaration counts and unique-member counts. Every value is locked.
const FROZEN_INTERFACES = {
  IEditor: { bases: [], ownDeclarationCount: 43, ownUniqueCount: 40, fullDeclarationCount: 43, fullUniqueCount: 40 },
  ICodeEditor: { bases: ['IEditor'], ownDeclarationCount: 94, ownUniqueCount: 94, fullDeclarationCount: 137, fullUniqueCount: 130 },
  IStandaloneCodeEditor: { bases: ['ICodeEditor'], ownDeclarationCount: 4, ownUniqueCount: 4, fullDeclarationCount: 141, fullUniqueCount: 133 },
  IDiffEditor: { bases: ['IEditor'], ownDeclarationCount: 17, ownUniqueCount: 17, fullDeclarationCount: 60, fullUniqueCount: 52 },
  IStandaloneDiffEditor: { bases: ['IDiffEditor'], ownDeclarationCount: 5, ownUniqueCount: 5, fullDeclarationCount: 65, fullUniqueCount: 55 },
};

const errors = [];

function fail(message) {
  errors.push(message);
}

function readRaw(path) {
  return readFileSync(path, 'utf8');
}

// ---------------------------------------------------------------------------
// 1. Both the g5-r and g4-r artifact trees must carry the frozen instance
//    surface, and the two copies must be byte-identical. This is the
//    identity-drift gate: if a later revision silently reorders or swaps a
//    declaration while keeping the count equal, the two copies diverge and the
//    probe fails closed.
// ---------------------------------------------------------------------------

const g5Path = resolve(G5_ARTIFACTS, INSTANCE_MANIFEST);
const g4Path = resolve(G4_ARTIFACTS, INSTANCE_MANIFEST);

let g5Raw;
let g4Raw;
try {
  g5Raw = readRaw(g5Path);
} catch (err) {
  fail(`g5-r instance-surface manifest is missing: ${err.message}`);
}
try {
  g4Raw = readRaw(g4Path);
} catch (err) {
  fail(`g4-r instance-surface manifest is missing: ${err.message}`);
}

if (g5Raw !== undefined && g4Raw !== undefined && g5Raw !== g4Raw) {
  fail('g5-r and g4-r instance-surface manifests are not byte-identical (identity drift between revisions)');
}

let manifest = null;
if (g5Raw !== undefined) {
  try {
    manifest = JSON.parse(g5Raw);
  } catch (err) {
    fail(`g5-r instance-surface manifest is not valid JSON: ${err.message}`);
  }
}

// ---------------------------------------------------------------------------
// 2. The manifest identity must match the locked monaco.d.ts provenance hash.
// ---------------------------------------------------------------------------

let provenance = null;
try {
  provenance = JSON.parse(readRaw(PROVENANCE_PATH));
} catch (err) {
  fail(`cannot read/parse provenance record: ${err.message}`);
}

if (manifest && provenance) {
  const id = manifest.identity || {};
  if (id.product !== 'MonaCode') {
    fail(`instance-surface identity.product must be "MonaCode", got ${JSON.stringify(id.product)}`);
  }
  if (id.revision !== 'F1-R3-instance-surface') {
    fail(`instance-surface identity.revision must be "F1-R3-instance-surface", got ${JSON.stringify(id.revision)}`);
  }
  if (typeof id.baseline !== 'string' || !id.baseline.includes('monaco-editor@0.56.0')) {
    fail(`instance-surface identity.baseline must mention monaco-editor@0.56.0, got ${JSON.stringify(id.baseline)}`);
  }
  if (id.source !== 'monaco.d.ts') {
    fail(`instance-surface identity.source must be "monaco.d.ts", got ${JSON.stringify(id.source)}`);
  }
  const dts = (provenance.declarations || {}).monacoDts;
  if (!dts) {
    fail('provenance record is missing declarations.monacoDts');
  } else if (id.publicDtsSha256 !== dts.sha256) {
    fail(
      `instance-surface identity.publicDtsSha256 (${JSON.stringify(id.publicDtsSha256)}) must equal provenance monacoDts sha256 (${dts.sha256})`,
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Every interface must match its frozen counts AND the actual member-list
//    lengths. A swapped member (count unchanged) is still caught by the
//    byte-identical revision check above; this section also rejects any
//    internal inconsistency within a single manifest.
// ---------------------------------------------------------------------------

if (manifest) {
  const interfaces = manifest.interfaces || {};
  const expectedNames = Object.keys(FROZEN_INTERFACES);
  const actualNames = Object.keys(interfaces);
  if (actualNames.length !== expectedNames.length) {
    fail(`interfaces count must be ${expectedNames.length}, got ${actualNames.length}`);
  }
  for (const name of expectedNames) {
    if (!(name in interfaces)) {
      fail(`interface "${name}" is missing from the manifest`);
      continue;
    }
    const iface = interfaces[name];
    const frozen = FROZEN_INTERFACES[name];

    // Bases must match exactly (identity, not just count).
    const basesOk =
      Array.isArray(iface.bases) &&
      iface.bases.length === frozen.bases.length &&
      iface.bases.every((b, i) => b === frozen.bases[i]);
    if (!basesOk) {
      fail(`interface "${name}" bases must be ${JSON.stringify(frozen.bases)}, got ${JSON.stringify(iface.bases)}`);
    }

    // Each count must match the frozen value AND the actual list length.
    const countFields = [
      ['ownDeclarationCount', 'ownDeclarations'],
      ['ownUniqueCount', 'ownUniqueMembers'],
      ['fullDeclarationCount', 'fullDeclarations'],
      ['fullUniqueCount', 'fullUniqueMembers'],
    ];
    for (const [countField, listField] of countFields) {
      const expected = frozen[countField];
      const actual = iface[countField];
      if (actual !== expected) {
        fail(`interface "${name}" ${countField} must be ${expected}, got ${JSON.stringify(actual)}`);
      }
      const list = iface[listField];
      if (!Array.isArray(list)) {
        fail(`interface "${name}" ${listField} must be an array`);
      } else if (list.length !== actual) {
        fail(`interface "${name}" ${listField} length (${list.length}) must equal ${countField} (${actual})`);
      }
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
      ? 'instance-surface-probe: OK — frozen F1-R3 instance surface reproduced (g5-r == g4-r, 5 interfaces, declaration counts verified)'
      : `instance-surface-probe: ${errors.length} error(s)`,
  };
}

const isMain = import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  const result = probe();
  if (!result.ok) {
    for (const msg of result.errors) {
      console.error(`instance-surface-probe: ${msg}`);
    }
    console.error(result.summary);
    process.exit(1);
  }
  console.error(result.summary);
  process.exit(0);
}

export { probe };
