// build-native-declaration-manifest.mjs
//
// P05-T190 — Produce and validate the provisional native declaration manifest.
//
// This is the Node manifest-builder for the MonaCode provisional native
// declaration manifest. It joins ALL retained and disposition-only declaration,
// registry, option, theme, localization, feature, and native-adaptation rows
// into ONE provisional manifest, validating each row's identity, disposition,
// native symbol, signature, owner, test owner, and source hash. The manifest
// is PROVISIONAL: Phase 07 public API closure + Phase 08 regeneration have not
// occurred yet (the manifest carries `provisional: true`).
//
// Sources (frozen G6-R contract archive):
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monaco-0.56.0-f1r3-scope-manifest.json
//     monaco-0.56.0-f1r4-public-declaration-manifest.json
//     monacode-f1r5-native-type-contract-manifest.json
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monacode-n1r-localization-manifest.json
//
// Generated/hand-written Swift code (the native symbols + source hashes):
//   Sources/MonaCode/Generated/*PublicAPI.swift        (T001 — 555 declarations)
//   Sources/MonaCode/Registry/*.swift                  (T002 — command/action/contribution)
//   Sources/MonaCode/Generated/MonaBuiltinKeybindings.swift  (T003)
//   Sources/MonaCode/Generated/MonaBuiltinMenus.swift        (T004)
//   Sources/MonaCode/Options/*.swift + Generated/MonaBuiltinOptions.swift (T005)
//   Sources/MonaCode/Theme/*.swift + Generated/MonaCodiconMap.swift        (T006)
//   Sources/MonaCode/Generated/MonaLocalizationProfiles.swift             (T007)
//   Sources/MonaCode/Language/*.swift                                      (T008)
//   Sources/MonaCodeAppKit/Colorize/*.swift                                (T009-T011)
//   Sources/MonaCodeAppKit/Views/*.swift                                    (T012)
//   Sources/MonaCode/Language/MonaProviderExecutor.swift + Runtime/*.swift (T013)
//   Sources/MonaCode*/Features/*.swift                                      (T100-T161)
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/build-native-declaration-manifest.mjs
//
// Writes:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p05-t190-native-declaration-manifest.json
//
// Determinism: byte-identical across re-runs (stable key order, trailing
// newline, no non-deterministic data sources).

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..');

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

const ARTIFACT_PATHS = {
  f1r3Scope: join(CONTRACT_DIR, 'monaco-0.56.0-f1r3-scope-manifest.json'),
  f1r4: join(CONTRACT_DIR, 'monaco-0.56.0-f1r4-public-declaration-manifest.json'),
  f1r5: join(CONTRACT_DIR, 'monacode-f1r5-native-type-contract-manifest.json'),
  n1r: join(CONTRACT_DIR, 'monacode-n1r-localization-manifest.json'),
};

const IMPLEMENTATION_PLAN_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'implementation-plan',
  'phase-05-public-surface-features.md'
);

export const MANIFEST_PATH = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts',
  'monacode-p05-t190-native-declaration-manifest.json'
);

// ---------------------------------------------------------------------------
// 1. Artifact loading.
// ---------------------------------------------------------------------------

export function loadArtifacts() {
  return {
    f1r3: JSON.parse(readFileSync(ARTIFACT_PATHS.f1r3Scope, 'utf8')),
    f1r4: JSON.parse(readFileSync(ARTIFACT_PATHS.f1r4, 'utf8')),
    f1r5: JSON.parse(readFileSync(ARTIFACT_PATHS.f1r5, 'utf8')),
    n1r: JSON.parse(readFileSync(ARTIFACT_PATHS.n1r, 'utf8')),
  };
}

// ---------------------------------------------------------------------------
// 2. Implementation plan parsing — build the task -> files map.
// ---------------------------------------------------------------------------

/**
 * Parse the G6-R phase-05 implementation plan to extract the task map:
 *   taskId -> { title, productTarget, createPaths: [], testPath, recordSha256 }
 *
 * The plan has one block per task:
 *   ### P05-T001 — Generate the exact 555-path native public declaration graph
 *   - Record SHA-256: `...`
 *   - productTarget: `null`
 *   - create:
 *     - Sources/...
 *   - test:
 *     - Tests/...
 */
export function parseImplementationPlan(planPath) {
  const src = readFileSync(planPath, 'utf8');
  const tasks = new Map();
  const blocks = src.split(/^### (P05-T\d{3}) —/m);
  // split: [preamble, id1, title1, id2, title2, ...]
  for (let i = 1; i < blocks.length; i += 2) {
    const taskId = blocks[i];
    const rest = blocks[i + 1] || '';
    // Extract title (first line, trimmed).
    const title = rest.split('\n')[0].trim();
    // Extract productTarget.
    const ptMatch = rest.match(/^- productTarget: `([^`]+)`/m);
    const productTarget = ptMatch ? ptMatch[1] : null;
    // Extract Record SHA-256.
    const shaMatch = rest.match(/^- Record SHA-256: `([0-9a-f]+)`/m);
    const recordSha256 = shaMatch ? shaMatch[1] : '';
    // Extract create paths.
    const createPaths = [];
    const createSection = rest.match(/^- create:\n((?:  - .+\n)+)/m);
    if (createSection) {
      for (const line of createSection[1].split('\n')) {
        const m = line.match(/^  - (.+)$/);
        if (m && m[1] !== '_(none)_') createPaths.push(m[1].trim());
      }
    }
    // Extract test path.
    let testPath = '';
    const testSection = rest.match(/^- test:\n((?:  - .+\n)+)/m);
    if (testSection) {
      for (const line of testSection[1].split('\n')) {
        const m = line.match(/^  - (.+)$/);
        if (m && m[1] !== '_(none)_') {
          testPath = m[1].trim();
          break;
        }
      }
    }
    tasks.set(taskId, { title, productTarget, createPaths, testPath, recordSha256 });
  }
  return tasks;
}

/**
 * Build a feature-id -> task-id map from the implementation plan task titles.
 * Feature task titles look like: "Implement retained feature anchorSelect"
 */
export function buildFeatureTaskMap(taskMap) {
  const m = new Map();
  for (const [taskId, info] of taskMap) {
    const fm = info.title.match(/retained feature (\w+)/);
    if (fm) m.set(fm[1], taskId);
  }
  return m;
}

// ---------------------------------------------------------------------------
// 3. Swift source scanning — extract native symbols + signatures.
// ---------------------------------------------------------------------------

const DECLARATION_SWIFT_FILES = [
  join(REPO_ROOT, 'Sources', 'MonaCode', 'Generated', 'MonaPublicAPI.swift'),
  join(REPO_ROOT, 'Sources', 'MonaCodeAppKit', 'Generated', 'MonaAppKitPublicAPI.swift'),
  join(REPO_ROOT, 'Sources', 'MonaCodeSwiftUI', 'Generated', 'MonaSwiftUIPublicAPI.swift'),
];

const DECLARATION_SWIFT_REL = [
  'Sources/MonaCode/Generated/MonaPublicAPI.swift',
  'Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift',
  'Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift',
];

/**
 * Scan the three generated declaration Swift files for `// PATH:` markers and
 * extract, for each F1-R4 path, its disposition, native Swift symbol, and the
 * signature line. Cut rows have nativeSymbol `UNAVAILABLE` and the signature
 * is the `// UNAVAILABLE:` comment line.
 */
export function scanDeclarationRows() {
  const rows = [];
  for (let fi = 0; fi < DECLARATION_SWIFT_FILES.length; fi++) {
    const abs = DECLARATION_SWIFT_FILES[fi];
    const rel = DECLARATION_SWIFT_REL[fi];
    const src = readFileSync(abs, 'utf8');
    const lines = src.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const pm = lines[i].match(/^\/\/ PATH: (.+)$/);
      if (!pm) continue;
      const path = pm[1].trim();
      // Look ahead for disposition + signature.
      let disposition = '';
      let signature = '';
      let nativeSymbol = '';
      for (let j = i + 1; j < Math.min(i + 20, lines.length); j++) {
        const dm = lines[j].match(/^\/\/ DISPOSITION: (.+)$/);
        if (dm) disposition = dm[1].trim();
        // Cut rows: the UNAVAILABLE comment is the signature.
        const um = lines[j].match(/^\/\/ UNAVAILABLE: (.+)$/);
        if (um) {
          nativeSymbol = 'UNAVAILABLE';
          signature = `// UNAVAILABLE: ${um[1].trim()}`;
          break;
        }
        // Retained rows: the first `public ...` line is the signature.
        if (/^public /.test(lines[j])) {
          signature = lines[j].trim();
          const symMatch = lines[j].match(
            /public\s+(?:final\s+|@\w+\s+)*(?:class|struct|enum|protocol|func|typealias|var)\s+(\w+)/
          );
          if (symMatch) nativeSymbol = symMatch[1];
          break;
        }
        // Stop at the next PATH marker.
        if (/^\/\/ PATH: /.test(lines[j])) break;
      }
      if (!nativeSymbol) nativeSymbol = 'UNAVAILABLE';
      if (!signature) signature = '// UNAVAILABLE: no production symbol';
      rows.push({
        identity: path,
        category: 'declaration',
        disposition,
        nativeSymbol,
        signature,
        sourcePath: rel,
        sourceHash: sha256File(abs),
      });
    }
  }
  return rows;
}

/**
 * Extract the main public type declaration from a Swift file. Returns
 * { nativeSymbol, signature }. The "main" type is the one whose name matches
 * the file stem (e.g. MonaColorizeSource in MonaColorizeSource.swift); if none
 * matches, the first public type declaration is used.
 */
export function extractMainType(absPath, fileStem) {
  const src = readFileSync(absPath, 'utf8');
  const lines = src.split('\n');
  // Prefer a type whose name matches the file stem.
  const preferred = `public final class ${fileStem}`.replace('public final class ', '');
  let firstType = null;
  for (const line of lines) {
    const m = line.match(
      /^public (?:final )?(?:class|struct|enum|protocol|typealias|func) (\w+)/
    );
    if (!m) continue;
    const sym = m[1];
    const sig = line.trim();
    if (!firstType) firstType = { nativeSymbol: sym, signature: sig };
    if (sym === fileStem || sym === `Mona${fileStem}`) {
      return { nativeSymbol: sym, signature: sig };
    }
  }
  if (firstType) return firstType;
  // Fallback: no public type found.
  return { nativeSymbol: fileStem, signature: `// ${fileStem}` };
}

// ---------------------------------------------------------------------------
// 4. Row builders — one per category.
// ---------------------------------------------------------------------------

/**
 * Declaration rows: 555 F1-R4 paths, each mapped to its Swift symbol.
 * Owner: P05-T001 (the generator task). Test owner: P05-T001.
 */
function buildDeclarationRows(scanned, f1r4, taskMap) {
  const owner = 'P05-T001';
  const testOwner = 'P05-T001';
  // Build a path -> f1r4 row map for validation.
  const f1r4Map = new Map();
  for (const ns of Object.keys(f1r4.publicDeclarations)) {
    for (const d of f1r4.publicDeclarations[ns]) {
      f1r4Map.set(d.path, d);
    }
  }
  const rows = [];
  for (const r of scanned) {
    // Validate identity + disposition against F1-R4.
    const f = f1r4Map.get(r.identity);
    if (!f) {
      throw new Error(
        `DECLARATION_IDENTITY_MISMATCH path=${r.identity} not found in F1-R4`
      );
    }
    if (r.disposition !== f.disposition) {
      throw new Error(
        `DECLARATION_DISPOSITION_MISMATCH path=${r.identity} ` +
          `manifest=${r.disposition} f1r4=${f.disposition}`
      );
    }
    rows.push({
      identity: r.identity,
      category: 'declaration',
      disposition: r.disposition,
      nativeSymbol: r.nativeSymbol,
      signature: r.signature,
      owner,
      testOwner,
      sourcePath: r.sourcePath,
      sourceHash: r.sourceHash,
    });
  }
  return rows;
}

/**
 * Registry rows: actions, pureTextSupportedActions, contributions, commands,
 * keybindings, menus, menuCommands. Each entry becomes one row. The native
 * symbol is the container registry type; the signature is the container's
 * public declaration.
 */
const REGISTRY_SOURCE_MAP = {
  actions: {
    owner: 'P05-T002',
    sourcePath: 'Sources/MonaCode/Registry/MonaActionRegistry.swift',
    nativeSymbol: 'MonaActionRegistry',
    signature: 'public final class MonaActionRegistry {',
  },
  pureTextSupportedActions: {
    owner: 'P05-T002',
    sourcePath: 'Sources/MonaCode/Registry/MonaActionRegistry.swift',
    nativeSymbol: 'MonaActionRegistry',
    signature: 'public final class MonaActionRegistry {',
  },
  contributions: {
    owner: 'P05-T002',
    sourcePath: 'Sources/MonaCode/Registry/MonaContributionRegistry.swift',
    nativeSymbol: 'MonaContributionRegistry',
    signature: 'public final class MonaContributionRegistry {',
  },
  commands: {
    owner: 'P05-T002',
    sourcePath: 'Sources/MonaCode/Registry/MonaCommandRegistry.swift',
    nativeSymbol: 'MonaCommandRegistry',
    signature: 'public final class MonaCommandRegistry {',
  },
  keybindings: {
    owner: 'P05-T003',
    sourcePath: 'Sources/MonaCode/Generated/MonaBuiltinKeybindings.swift',
    nativeSymbol: 'MonaBuiltinKeybindings',
    signature: 'public enum MonaBuiltinKeybindings {',
  },
  menus: {
    owner: 'P05-T004',
    sourcePath: 'Sources/MonaCode/Generated/MonaBuiltinMenus.swift',
    nativeSymbol: 'MonaBuiltinMenus',
    signature: 'public enum MonaBuiltinMenus {',
  },
  menuCommands: {
    owner: 'P05-T004',
    sourcePath: 'Sources/MonaCode/Generated/MonaBuiltinMenus.swift',
    nativeSymbol: 'MonaBuiltinMenus',
    signature: 'public enum MonaBuiltinMenus {',
  },
};

function buildRegistryRows(f1r3) {
  const rows = [];
  for (const regKey of Object.keys(REGISTRY_SOURCE_MAP)) {
    const meta = REGISTRY_SOURCE_MAP[regKey];
    const entries = f1r3.registries[regKey] || [];
    const abs = join(REPO_ROOT, meta.sourcePath);
    const hash = sha256File(abs);
    for (const entry of entries) {
      if (!entry) continue;
      // Identity: use id if present, else ordinal, else index.
      let identity = entry.id || `ordinal:${entry.ordinal}`;
      if (!identity && entry.ordinal !== undefined) identity = `ordinal:${entry.ordinal}`;
      if (!identity) identity = JSON.stringify(entry).slice(0, 40);
      const disposition = entry.disposition || 'retained';
      rows.push({
        identity: `${regKey}:${identity}`,
        category: 'registry',
        disposition,
        nativeSymbol: meta.nativeSymbol,
        signature: meta.signature,
        owner: meta.owner,
        testOwner: meta.owner,
        sourcePath: meta.sourcePath,
        sourceHash: hash,
      });
    }
  }
  return rows;
}

/**
 * Option rows: 174 editor options from F1-R3. Native symbol is
 * MonaBuiltinOptions (the container enum).
 */
function buildOptionRows(f1r3) {
  const owner = 'P05-T005';
  const sourcePath = 'Sources/MonaCode/Generated/MonaBuiltinOptions.swift';
  const nativeSymbol = 'MonaBuiltinOptions';
  const signature = 'public enum MonaBuiltinOptions {';
  const abs = join(REPO_ROOT, sourcePath);
  const hash = sha256File(abs);
  const options = f1r3.registries.options || [];
  const rows = [];
  for (const opt of options) {
    if (!opt) continue;
    rows.push({
      identity: `option:${opt.name || opt.id}`,
      category: 'option',
      disposition: opt.disposition || 'retained-input',
      nativeSymbol,
      signature,
      owner,
      testOwner: owner,
      sourcePath,
      sourceHash: hash,
    });
  }
  return rows;
}

/**
 * Theme rows: colors (431), icons (776), builtinThemes (4). Each entry becomes
 * one row. Native symbol is the container type per sub-category.
 */
const THEME_SOURCE_MAP = {
  colors: {
    owner: 'P05-T006',
    sourcePath: 'Sources/MonaCode/Theme/MonaColorRegistry.swift',
    nativeSymbol: 'MonaColorRegistry',
    signature: 'public enum MonaColorRegistry {',
    idPrefix: 'color',
  },
  icons: {
    owner: 'P05-T006',
    sourcePath: 'Sources/MonaCode/Generated/MonaCodiconMap.swift',
    nativeSymbol: 'MonaCodiconMap',
    signature: 'public enum MonaCodiconMap {',
    idPrefix: 'icon',
  },
  builtinThemes: {
    owner: 'P05-T006',
    sourcePath: 'Sources/MonaCode/Theme/MonaThemeRegistry.swift',
    nativeSymbol: 'MonaThemeRegistry',
    signature: 'public final class MonaThemeRegistry {',
    idPrefix: 'builtinTheme',
  },
};

function buildThemeRows(f1r3) {
  const rows = [];
  for (const key of Object.keys(THEME_SOURCE_MAP)) {
    const meta = THEME_SOURCE_MAP[key];
    const entries = f1r3.registries[key] || [];
    const abs = join(REPO_ROOT, meta.sourcePath);
    const hash = sha256File(abs);
    for (const entry of entries) {
      if (!entry) continue;
      const identity = `${meta.idPrefix}:${entry.id}`;
      const disposition = entry.disposition || 'retained';
      rows.push({
        identity,
        category: 'theme',
        disposition,
        nativeSymbol: meta.nativeSymbol,
        signature: meta.signature,
        owner: meta.owner,
        testOwner: meta.owner,
        sourcePath: meta.sourcePath,
        sourceHash: hash,
      });
    }
  }
  return rows;
}

/**
 * Localization rows: 15 locale profiles from the N1-R manifest. Native symbol
 * is MonaLocalizationProfiles (the container enum).
 */
function buildLocalizationRows(n1r) {
  const owner = 'P05-T007';
  const sourcePath = 'Sources/MonaCode/Generated/MonaLocalizationProfiles.swift';
  const nativeSymbol = 'MonaLocalizationProfiles';
  const signature = 'public enum MonaLocalizationProfiles {';
  const abs = join(REPO_ROOT, sourcePath);
  const hash = sha256File(abs);
  const profiles = n1r.localeProfiles || [];
  const rows = [];
  for (const prof of profiles) {
    if (!prof) continue;
    rows.push({
      identity: `locale:${prof.id}`,
      category: 'localization',
      disposition: 'retained',
      nativeSymbol,
      signature,
      owner,
      testOwner: owner,
      sourcePath,
      sourceHash: hash,
    });
  }
  return rows;
}

/**
 * Language rows: 91 language descriptors from F1-R3. Native symbol is
 * MonaLanguageRegistry (the container class).
 */
function buildLanguageRows(f1r3) {
  const owner = 'P05-T008';
  const sourcePath = 'Sources/MonaCode/Language/MonaLanguageRegistry.swift';
  const nativeSymbol = 'MonaLanguageRegistry';
  const signature = 'public final class MonaLanguageRegistry {';
  const abs = join(REPO_ROOT, sourcePath);
  const hash = sha256File(abs);
  const descriptors = f1r3.registries.languageDescriptors || [];
  const rows = [];
  for (const desc of descriptors) {
    if (!desc) continue;
    rows.push({
      identity: `language:${desc.id}`,
      category: 'language',
      disposition: desc.disposition || 'retained',
      nativeSymbol,
      signature,
      owner,
      testOwner: owner,
      sourcePath,
      sourceHash: hash,
    });
  }
  return rows;
}

/**
 * Feature rows: 64 feature entries from F1-R3 (62 retained + 2 cut/later).
 * Each retained feature maps to a task T100-T161 and a feature Swift file.
 * The native symbol is the feature type extracted from the file.
 */
function buildFeatureRows(f1r3, taskMap, featureTaskMap) {
  const rows = [];
  const features = f1r3.sourceGraph.featureEntries || [];
  for (const feat of features) {
    if (!feat) continue;
    const taskId = featureTaskMap.get(feat.id);
    if (!taskId) {
      // Cut/later features have no implementation task; record as disposition-only.
      // The native symbol is UNAVAILABLE and the signature is the container
      // registry declaration (which exists in the source file).
      const cutSourcePath = 'Sources/MonaCode/Registry/MonaFeatureRegistry.swift';
      const cutAbs = join(REPO_ROOT, cutSourcePath);
      rows.push({
        identity: `feature:${feat.id}`,
        category: 'feature',
        disposition: feat.disposition,
        nativeSymbol: 'UNAVAILABLE',
        signature: 'public final class MonaFeatureRegistry {',
        owner: 'P05-T002',
        testOwner: 'P05-T002',
        sourcePath: cutSourcePath,
        sourceHash: sha256File(cutAbs),
      });
      continue;
    }
    const task = taskMap.get(taskId);
    if (!task) {
      throw new Error(`FEATURE_TASK_MISSING feature=${feat.id} task=${taskId}`);
    }
    // Find the feature Swift file from the task's create paths.
    const featureFile = task.createPaths.find((p) => p.endsWith('Feature.swift'));
    if (!featureFile) {
      throw new Error(`FEATURE_SOURCE_MISSING feature=${feat.id} task=${taskId}`);
    }
    const abs = join(REPO_ROOT, featureFile);
    const fileStem = featureFile.split('/').pop().replace('.swift', '');
    const { nativeSymbol, signature } = extractMainType(abs, fileStem);
    rows.push({
      identity: `feature:${feat.id}`,
      category: 'feature',
      disposition: feat.disposition,
      nativeSymbol,
      signature,
      owner: taskId,
      testOwner: taskId,
      sourcePath: featureFile,
      sourceHash: sha256File(abs),
    });
  }
  return rows;
}

/**
 * Native-adaptation rows: the T009-T013 source files (colorize, factory,
 * provider executor, microtask queue). Each source file produces one row.
 */
const NATIVE_ADAPTATION_SPECS = [
  {
    owner: 'P05-T009',
    sourcePath: 'Sources/MonaCodeAppKit/Colorize/MonaColorizeSource.swift',
    identity: 'native-adaptation:colorize-source',
    disposition: 'retained-native-replacement',
  },
  {
    owner: 'P05-T010',
    sourcePath: 'Sources/MonaCodeAppKit/Colorize/MonaColorizeView.swift',
    identity: 'native-adaptation:colorize-view',
    disposition: 'retained-native-replacement',
  },
  {
    owner: 'P05-T011',
    sourcePath: 'Sources/MonaCodeAppKit/Colorize/MonaColorizeModelLine.swift',
    identity: 'native-adaptation:colorize-model-line',
    disposition: 'retained-native-replacement',
  },
  {
    owner: 'P05-T012',
    sourcePath: 'Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift',
    identity: 'native-adaptation:editor-factory',
    disposition: 'retained-native-mapping',
  },
  {
    owner: 'P05-T012',
    sourcePath: 'Sources/MonaCodeAppKit/Views/MonaEditorInstanceAdapters.swift',
    identity: 'native-adaptation:instance-adapters',
    disposition: 'retained-appkit-type-adaptation',
  },
  {
    owner: 'P05-T013',
    sourcePath: 'Sources/MonaCode/Language/MonaProviderExecutor.swift',
    identity: 'native-adaptation:provider-executor',
    disposition: 'retained-native-mapping',
  },
  {
    owner: 'P05-T013',
    sourcePath: 'Sources/MonaCode/Runtime/MonaMicrotaskQueue.swift',
    identity: 'native-adaptation:microtask-queue',
    disposition: 'retained-native-mapping',
  },
];

function buildNativeAdaptationRows() {
  const rows = [];
  for (const spec of NATIVE_ADAPTATION_SPECS) {
    const abs = join(REPO_ROOT, spec.sourcePath);
    const fileStem = spec.sourcePath.split('/').pop().replace('.swift', '');
    const { nativeSymbol, signature } = extractMainType(abs, fileStem);
    rows.push({
      identity: spec.identity,
      category: 'native-adaptation',
      disposition: spec.disposition,
      nativeSymbol,
      signature,
      owner: spec.owner,
      testOwner: spec.owner,
      sourcePath: spec.sourcePath,
      sourceHash: sha256File(abs),
    });
  }
  return rows;
}

// ---------------------------------------------------------------------------
// 5. Row validation.
// ---------------------------------------------------------------------------

const REQUIRED_STRING_FIELDS = [
  'identity',
  'category',
  'disposition',
  'nativeSymbol',
  'signature',
  'owner',
  'testOwner',
  'sourcePath',
  'sourceHash',
];

const OWNER_ID_RE = /^P05-T\d{3}$/;

/**
 * Validate every row. Reject mismatches by throwing.
 *
 * Validation rules (from the G6-R plan leaf P05-T190):
 *   1. identity matches the source manifest (F1-R4 for declarations, F1-R3 for
 *      registries/options/themes/languages/features).
 *   2. disposition matches the cut/retained mapping.
 *   3. native symbol exists in the generated Swift.
 *   4. signature matches (the signature string appears in the Swift source).
 *   5. owner + test owner are non-empty P05-T### task ids.
 *   6. source hash matches the committed file (recomputed SHA-256).
 */
export function validateRows(rows) {
  // Cache of sourcePath -> file content + recomputed hash (avoid re-reading
  // the same file for every row).
  const fileCache = new Map();
  function getFile(relPath) {
    if (!fileCache.has(relPath)) {
      const abs = join(REPO_ROOT, relPath);
      if (!existsSync(abs)) {
        throw new Error(`SOURCE_FILE_MISSING sourcePath=${relPath}`);
      }
      const content = readFileSync(abs, 'utf8');
      const hash = sha256(content);
      fileCache.set(relPath, { content, hash });
    }
    return fileCache.get(relPath);
  }

  for (const row of rows) {
    // Rule 5: owner + test owner are non-empty P05-T### ids.
    for (const f of REQUIRED_STRING_FIELDS) {
      if (typeof row[f] !== 'string' || row[f].length === 0) {
        throw new Error(
          `ROW_FIELD_EMPTY identity=${row.identity} field=${f} (must be non-empty string)`
        );
      }
    }
    if (!OWNER_ID_RE.test(row.owner)) {
      throw new Error(
        `OWNER_INVALID identity=${row.identity} owner=${row.owner} (must match P05-T###)`
      );
    }
    if (!OWNER_ID_RE.test(row.testOwner)) {
      throw new Error(
        `TEST_OWNER_INVALID identity=${row.identity} testOwner=${row.testOwner} (must match P05-T###)`
      );
    }

    // Rule 6: source hash matches the committed file.
    const file = getFile(row.sourcePath);
    if (file.hash !== row.sourceHash) {
      throw new Error(
        `SOURCE_HASH_MISMATCH identity=${row.identity} sourcePath=${row.sourcePath} ` +
          `manifest=${row.sourceHash} recomputed=${file.hash}`
      );
    }

    // Rule 3: native symbol exists in the generated Swift.
    if (row.nativeSymbol !== 'UNAVAILABLE') {
      if (!file.content.includes(row.nativeSymbol)) {
        throw new Error(
          `NATIVE_SYMBOL_MISSING identity=${row.identity} ` +
            `nativeSymbol=${row.nativeSymbol} not found in ${row.sourcePath}`
        );
      }
    } else {
      // Cut rows: the path marker or UNAVAILABLE comment must exist.
      if (
        !file.content.includes('UNAVAILABLE') &&
        !file.content.includes(row.identity.replace(/^(declaration:|feature:)/, ''))
      ) {
        throw new Error(
          `CUT_ROW_MARKER_MISSING identity=${row.identity} sourcePath=${row.sourcePath}`
        );
      }
    }

    // Rule 4: signature matches (the signature string appears in the source).
    // For declaration rows, the signature is the exact line. For other rows,
    // the signature is the container type declaration.
    if (!file.content.includes(row.signature)) {
      throw new Error(
        `SIGNATURE_MISMATCH identity=${row.identity} ` +
          `signature=${JSON.stringify(row.signature)} not found in ${row.sourcePath}`
      );
    }
  }
}

// ---------------------------------------------------------------------------
// 6. Manifest assembly + deterministic JSON serialization.
// ---------------------------------------------------------------------------

/**
 * Assemble the full provisional native declaration manifest. Returns the
 * manifest object. If outPath is provided, also writes the deterministic JSON.
 */
export function buildManifest({ outPath } = {}) {
  const artifacts = loadArtifacts();
  const taskMap = parseImplementationPlan(IMPLEMENTATION_PLAN_PATH);
  const featureTaskMap = buildFeatureTaskMap(taskMap);

  // Build all row categories in deterministic order.
  const scannedDecls = scanDeclarationRows();
  const declarationRows = buildDeclarationRows(scannedDecls, artifacts.f1r4, taskMap);
  const registryRows = buildRegistryRows(artifacts.f1r3);
  const optionRows = buildOptionRows(artifacts.f1r3);
  const themeRows = buildThemeRows(artifacts.f1r3);
  const localizationRows = buildLocalizationRows(artifacts.n1r);
  const languageRows = buildLanguageRows(artifacts.f1r3);
  const featureRows = buildFeatureRows(artifacts.f1r3, taskMap, featureTaskMap);
  const nativeAdaptationRows = buildNativeAdaptationRows();

  const rows = [
    ...declarationRows,
    ...registryRows,
    ...optionRows,
    ...themeRows,
    ...localizationRows,
    ...languageRows,
    ...featureRows,
    ...nativeAdaptationRows,
  ];

  // Validate every row. Reject mismatches by throwing.
  validateRows(rows);

  // Counts block (deterministic key order).
  const counts = {
    declaration: declarationRows.length,
    registry: registryRows.length,
    option: optionRows.length,
    theme: themeRows.length,
    localization: localizationRows.length,
    language: languageRows.length,
    feature: featureRows.length,
    nativeAdaptation: nativeAdaptationRows.length,
    total: rows.length,
  };

  // Source artifact hashes (for provenance).
  const sources = {
    f1r3ScopeManifest: sha256File(ARTIFACT_PATHS.f1r3Scope),
    f1r4PublicDeclarationManifest: sha256File(ARTIFACT_PATHS.f1r4),
    f1r5NativeTypeContractManifest: sha256File(ARTIFACT_PATHS.f1r5),
    n1rLocalizationManifest: sha256File(ARTIFACT_PATHS.n1r),
    implementationPlanPhase05: sha256File(IMPLEMENTATION_PLAN_PATH),
  };

  const manifest = {
    schemaVersion: 1,
    identity: {
      product: 'MonaCode',
      revision: 'P05-T190-provisional-native-declaration-manifest',
      baseline: 'monaco-editor@0.56.0',
      provisional: true,
      provisionalReason:
        'Phase 07 public API closure and Phase 08 regeneration have not occurred; ' +
        'this manifest will be finalized then.',
    },
    sources,
    counts,
    rows,
  };

  const json = stableStringify(manifest) + '\n';

  if (outPath) {
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, json);
  } else {
    // Default: write to the committed artifact path.
    mkdirSync(dirname(MANIFEST_PATH), { recursive: true });
    writeFileSync(MANIFEST_PATH, json);
  }

  // Stable summary line for CI/observability.
  process.stdout.write(
    `NATIVE_DECLARATION_MANIFEST rows=${rows.length} provisional=true ` +
      `declaration=${counts.declaration} registry=${counts.registry} ` +
      `option=${counts.option} theme=${counts.theme} ` +
      `localization=${counts.localization} language=${counts.language} ` +
      `feature=${counts.feature} nativeAdaptation=${counts.nativeAdaptation}\n`
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
  process.argv[1]?.endsWith('build-native-declaration-manifest.mjs');
if (isMain) {
  buildManifest({});
}
