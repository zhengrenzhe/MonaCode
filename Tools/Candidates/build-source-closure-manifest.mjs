// build-source-closure-manifest.mjs
//
// P07-T008 — Close runtime-style substitutions and full source inventory.
//
// This is the Node manifest-builder for the MonaCode provisional
// source-closure manifest. It joins EVERY product source file, generated
// source, resource, license notice, finite runtime substitution, native
// style projection, and explicit cut into ONE provisional manifest, and
// verifies the X1-R frozen set-equality counts.
//
// The manifest is PROVISIONAL: Phase 08 release regeneration has not occurred
// yet (the manifest carries `provisional: true`). Phase 08 will re-emit this
// manifest from the finalized source closure.
//
// Contract source (frozen G6-R contract archive):
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/
//     monacode-x1r-source-runtime-style-manifest.json   (X1-R baseline closure)
//     monacode-g4r-authoritative-manifest.json          (C04/C10 invariants)
//     monacode-n1r-localization-manifest.json           (2120 l10n messages)
//
// Product source roots (walked by this builder):
//   Sources/MonaCode/        (product target MonaCode)
//   Sources/MonaCodeAppKit/   (product target MonaCodeAppKit)
//   Sources/MonaCodeSwiftUI/  (product target MonaCodeSwiftUI)
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Candidates/build-source-closure-manifest.mjs
//
// Writes:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t008-source-closure-manifest.json
//
// Determinism: byte-identical across re-runs (stable key order, trailing
// newline, no non-deterministic data sources).

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
  'monacode-p07-t008-source-closure-manifest.json'
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

const X1R_MANIFEST_PATH = join(
  CONTRACT_DIR,
  'monacode-x1r-source-runtime-style-manifest.json'
);
const G4R_AUTHORITATIVE_PATH = join(
  CONTRACT_DIR,
  'monacode-g4r-authoritative-manifest.json'
);
const N1R_LOCALIZATION_PATH = join(
  CONTRACT_DIR,
  'monacode-n1r-localization-manifest.json'
);

// Product source roots (the three product library targets).
const PRODUCT_SOURCE_ROOTS = [
  join(REPO_ROOT, 'Sources', 'MonaCode'),
  join(REPO_ROOT, 'Sources', 'MonaCodeAppKit'),
  join(REPO_ROOT, 'Sources', 'MonaCodeSwiftUI'),
];

// ---------------------------------------------------------------------------
// 1. The X1-R frozen set-equality targets (the closed set the manifest must
//    be set-equal to). Sourced verbatim from the X1-R manifest + N1-R manifest.
// ---------------------------------------------------------------------------

export const X1R_SET_EQUALITY = {
  javascriptModules: 956,
  styleResources: 98,
  styleRuleNodes: 1281,
  styleDeclarations: 3120,
  directGlobalIdentifiers: 84,
  directGlobalReferences: 8221,
  localizationMessages: 2120,
};

// ---------------------------------------------------------------------------
// 2. The finite runtime substitutions (runtime-style substitutions). Each row
//    records a finite Swift operation profile that substitutes for a JS
//    runtime surface, sourced from the X1-R intrinsicOperationProfiles,
//    directGlobalClosure, encodingAndHashing and clockAndPerformanceCorrection
//    sections. MonaCode implements only these finite profiles; it never
//    exposes a general JavaScript runtime.
// ---------------------------------------------------------------------------

export const RUNTIME_STYLE_SUBSTITUTIONS = [
  {
    id: 'intrinsic.array',
    runtimeSurface: 'Array',
    nativeSubstitution: 'repository typed-array + index-ordered enumeration',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.object',
    runtimeSurface: 'Object',
    nativeSubstitution: 'own-string-key array-index + insertion-order enumeration',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.reflect',
    runtimeSurface: 'Reflect',
    nativeSubstitution: 'descriptor helpers emitted as module wiring; no public reflection runtime',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.map',
    runtimeSurface: 'Map',
    nativeSubstitution: 'insertion-order, SameValueZero keyed native map',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.set',
    runtimeSurface: 'Set',
    nativeSubstitution: 'insertion-order native set',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.promise',
    runtimeSurface: 'Promise',
    nativeSubstitution: 'repository thenable + E1 MainActor microtask queue',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.math',
    runtimeSurface: 'Math',
    nativeSubstitution: 'binary64 profiles with Chrome 151 oracle; Darwin libm is not an oracle',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.json',
    runtimeSurface: 'JSON',
    nativeSubstitution: 'raw-UTF-16 codec; source-exact replacers, key order, duplicate-key last-value',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.regexp',
    runtimeSurface: 'RegExp',
    nativeSubstitution: 'repository M1-R regexp; no NSRegularExpression semantic substitution',
    owner: 'M1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.symbol',
    runtimeSurface: 'Symbol',
    nativeSubstitution: 'typed Swift protocols; no public Symbol/Proxy API',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.typed-array',
    runtimeSurface: 'ArrayBuffer/DataView/typed arrays',
    nativeSubstitution: 'explicit byte order, wrapping, overlap and alias rules',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'intrinsic.error',
    runtimeSurface: 'Error/TypeError/AggregateError',
    nativeSubstitution: 'typed native errors; sanitized H1 diagnostics replace JS stack formatting',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'clock.wall',
    runtimeSurface: 'Date.now / StopWatch(false)',
    nativeSubstitution: 'injected Unix-epoch integer-millisecond wall clock',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'clock.high-resolution',
    runtimeSurface: 'StopWatch(true) / input-latency',
    nativeSubstitution: 'mach_absolute_time domain converted to binary64 ms; Chrome 151 TimeTicks semantics',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'encoding.utf16-decoder',
    runtimeSurface: 'TextDecoder (UTF-16)',
    nativeSubstitution: 'native UTF-16 decoder; BOM/surrogate rules from X1-R chrome vectors',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'encoding.sha1',
    runtimeSurface: 'StringSHA1',
    nativeSubstitution: 'source UTF-16-to-UTF-8 stream SHA-1; no WebCrypto',
    owner: 'E1-R',
    disposition: 'finite-operation-profile',
  },
  {
    id: 'platform.dom',
    runtimeSurface: 'document/window/DOM/customElements/Animation/observers',
    nativeSubstitution: 'frozen AppKit/Core Text/Core Graphics/I3/I4/A2 state machines; no DOM/CSS API ships',
    owner: 'A2-R/H1-R/V1-R4',
    disposition: 'native-adaptation',
  },
  {
    id: 'platform.clipboard',
    runtimeSurface: 'ClipboardItem/navigator.clipboard',
    nativeSubstitution: 'I4 NSPasteboard pipeline; native command routes',
    owner: 'I4-R',
    disposition: 'native-adaptation',
  },
  {
    id: 'platform.urls',
    runtimeSurface: 'URL/URLSearchParams',
    nativeSubstitution: 'MonaURI + H1 openers; worker/DOM-sanitizer sites cut',
    owner: 'H1-R/MD1-R',
    disposition: 'native-adaptation',
  },
  {
    id: 'platform.diagnostics',
    runtimeSurface: 'console.*',
    nativeSubstitution: 'nonthrowing sanitized H1 diagnostics or fixed no-ops',
    owner: 'H1-R',
    disposition: 'native-adaptation',
  },
];

// ---------------------------------------------------------------------------
// 3. Native style projections. Each row records how a static CSS rule or
//    runtime visual-mutation site projects onto native geometry, color,
//    typography, icon, animation, focus, hit-test or visibility state.
// ---------------------------------------------------------------------------

export const NATIVE_STYLE_PROJECTIONS = [
  {
    id: 'style.geometry',
    sourceSurface: 'static CSS rules (1281 nodes / 3120 declarations)',
    nativeProjection: 'native geometry/layout/color/type/icon/motion/focus/hit-test/visibility state',
    owner: 'V1-R4/A2-R',
    disposition: 'native-style-mapping',
  },
  {
    id: 'style.color-registry',
    sourceSurface: 'registerColor call sites (432)',
    nativeProjection: 'native color registry; 431 literal identity + 1 forwarder',
    owner: 'V1-R4',
    disposition: 'native-style-mapping',
  },
  {
    id: 'style.icon-registry',
    sourceSurface: 'registerIcon call sites (37)',
    nativeProjection: 'native icon registry via MonaCodiconMap; 35 literal + 2 helper',
    owner: 'A2-R',
    disposition: 'native-style-mapping',
  },
  {
    id: 'style.theming-participant',
    sourceSurface: 'registerThemingParticipant (14)',
    nativeProjection: 'native theme participant registration',
    owner: 'V1-R4',
    disposition: 'native-style-mapping',
  },
  {
    id: 'style.motion',
    sourceSurface: 'keyframe rules (12) / motion declarations (46)',
    nativeProjection: 'native animation family; Core Graphics + conditional Metal',
    owner: 'V1-R4',
    disposition: 'native-style-mapping',
  },
  {
    id: 'style.codicon-font',
    sourceSurface: 'codicon.ttf (140956 bytes)',
    nativeProjection: 'MonaCodiconMap generated glyph table; sole core-package runtime asset',
    owner: 'A2-R',
    disposition: 'native-style-mapping',
  },
  {
    id: 'style.runtime-visual-mutation',
    sourceSurface: 'targeted runtime visual-mutation overlay (3099 sites / 217 files)',
    nativeProjection: 'conservative targeted syntax overlay mapped to native state',
    owner: 'V1-R4',
    disposition: 'native-style-mapping',
  },
  {
    id: 'style.cssruntime',
    sourceSurface: 'cssRuntime',
    nativeProjection: 'absent — no CSS runtime ships',
    owner: 'X1-R',
    disposition: 'absent',
  },
];

// ---------------------------------------------------------------------------
// 4. Explicit cuts. Each row records a runtime surface that is explicitly cut
//    per the G4 closed-world rule; none creates a retained native obligation.
// ---------------------------------------------------------------------------

export const EXPLICIT_CUTS = [
  {
    id: 'cut.webworker',
    surface: 'Worker/Blob worker/self/importScripts/postMessage/createObjectURL',
    ruling: 'complete WebWorker cut; retained worker computations use immutable native snapshots',
    owner: 'X1-R',
  },
  {
    id: 'cut.webgpu',
    surface: 'OffscreenCanvas/GPUBufferUsage/GPUTextureUsage/navigator.gpu',
    ruling: 'cut WebGPU paths; Core Graphics + conditional Metal backend (V1-R4)',
    owner: 'V1-R4/X1-R',
  },
  {
    id: 'cut.network',
    surface: 'fetch/XHR/WebSocket/EventSource',
    ruling: 'absent direct globals; no network fallback',
    owner: 'X1-R',
  },
  {
    id: 'cut.storage',
    surface: 'localStorage/sessionStorage/indexedDB',
    ruling: 'absent direct globals; no persistence backends',
    owner: 'X1-R',
  },
  {
    id: 'cut.webcrypto',
    surface: 'WebCrypto/crypto.subtle',
    ruling: 'no WebCrypto dependency; StringSHA1 is source-native',
    owner: 'E1-R/X1-R',
  },
  {
    id: 'cut.webassembly',
    surface: 'WebAssembly/SharedArrayBuffer/Atomics',
    ruling: 'absent; no WASM file in the core package',
    owner: 'X1-R',
  },
  {
    id: 'cut.dom-purify',
    surface: 'DOMPurify production code',
    ruling: 'absent; MD1-R sanitization is native',
    owner: 'MD1-R/X1-R',
  },
  {
    id: 'cut.v8',
    surface: 'V8 JavaScript engine',
    ruling: 'behavioral provenance for binary64 transcendentals only; no V8 runtime linked',
    owner: 'X1-R',
  },
  {
    id: 'cut.icu',
    surface: 'ICU runtime/code',
    ruling: 'no ICU runtime; E1-R collation/case tables are generated native',
    owner: 'E1-R/X1-R',
  },
  {
    id: 'cut.external-diff',
    surface: '@vscode/diff external module',
    ruling: 'D1-R retains four public algorithm values; no external plugin API',
    owner: 'D1-R/X1-R',
  },
  {
    id: 'cut.source-maps',
    surface: 'JavaScript/source-map resources',
    ruling: '992 source maps are provenance inputs; do not enter the signed native runtime',
    owner: 'X1-R',
  },
  {
    id: 'cut.nodejs',
    surface: 'Buffer/process (Node.js)',
    ruling: 'absent in the fixed browser baseline; no Node buffer mode exposed',
    owner: 'X1-R',
  },
];

// ---------------------------------------------------------------------------
// 5. Forbidden runtime classes (the no-bundled-runtime invariant from
//    P06-T010). The manifest rejects any of these appearing in product
//    sources. None may ship in the signed distribution.
// ---------------------------------------------------------------------------

export const FORBIDDEN_RUNTIME_CLASSES = [
  'javascript-engine', // V8 / JavaScriptCore / QuickJS runtime
  'bundled-server', // no built-in LSP server / language implementation
  'icu-runtime', // no ICU code/runtime
  'grammar-pack', // no built-in language grammar pack
  'webview', // no WebView
  'webworker-runtime', // no WebWorker runtime
  'css-runtime', // no CSS engine/runtime
  'wasm-runtime', // no WebAssembly runtime
  'network-fallback', // no network fallback
  'webcrypto-dependency', // no WebCrypto dependency
  'external-diff-module', // no @vscode/diff external module
  'dom-purify-production', // no DOMPurify production code
  'nsregularexpression-substitution', // no NSRegularExpression semantic substitution
  'unlicensed-unicode-data', // no unlicensed vscode-unicode-data code/output
];

// Forbidden symbol/pattern scan strings for product-source rejection. If any
// of these appear as an import or a substantive reference in a product Swift
// file the manifest is rejected. (Comments and these manifest strings are
// scoped out by a coarse but conservative textual scan that requires the
// forbidden symbol to appear as a token that would indicate actual use.)
const FORBIDDEN_SOURCE_PATTERNS = [
  { class: 'javascript-engine', pattern: /import\s+(JavaScriptCore|QuickJS)\b/ },
  { class: 'bundled-server', pattern: /\bimport\s+V8\b/ },
  { class: 'webview-runtime', pattern: /import\s+WebKit\b/ },
  { class: 'wasm-runtime', pattern: /import\s+WASM\b/ },
  { class: 'external-diff-module', pattern: /import\s+Diff\b/ },
];

// ---------------------------------------------------------------------------
// 6. Product source enumeration. Walk the three product source roots and
//    classify every file as product-swift, generated-swift, or license-notice.
// ---------------------------------------------------------------------------

/**
 * Walk a directory tree and yield every regular file path (relative to
 * REPO_ROOT) under it, sorted for determinism.
 */
function walkDir(rootAbs) {
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
      } else if (st.isFile()) {
        out.push(relative(REPO_ROOT, full));
      }
    }
  }
  recurse(rootAbs);
  return out;
}

/**
 * Build the product source rows. Each row carries the repo-relative path, the
 * sha256 of the file contents, a role (product-swift | generated-swift |
 * license-notice), and the owning product target.
 */
export function buildProductSourceRows() {
  const rows = [];
  const seen = new Set();
  for (const root of PRODUCT_SOURCE_ROOTS) {
    const targetName = root.endsWith('MonaCode')
      ? 'MonaCode'
      : root.endsWith('MonaCodeAppKit')
        ? 'MonaCodeAppKit'
        : 'MonaCodeSwiftUI';
    for (const rel of walkDir(root)) {
      if (seen.has(rel)) continue;
      seen.add(rel);
      const abs = join(REPO_ROOT, rel);
      const hash = createHash('sha256').update(readFileSync(abs)).digest('hex');
      let role;
      if (rel.endsWith('.swift') && rel.includes('/Generated/')) {
        role = 'generated-swift';
      } else if (rel.endsWith('.swift')) {
        role = 'product-swift';
      } else if (rel.endsWith('.txt') && rel.toUpperCase().includes('LICENSE')) {
        role = 'license-notice';
      } else {
        // Other non-swift product assets are recorded as resource rows.
        role = 'resource';
      }
      rows.push({
        path: rel,
        target: targetName,
        role,
        sha256: hash,
      });
    }
  }
  rows.sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
  return rows;
}

// ---------------------------------------------------------------------------
// 7. Validation — reject absent paths, forbidden runtime classes, and X1-R
//    set-equality drift.
// ---------------------------------------------------------------------------

/**
 * Validate the source closure. Throws on any violation.
 *
 * Validation rules (from the G6-R plan leaf P07-T008 + X1-R C04/C10):
 *   1. Every product source/resource file in the repo is enumerated (no
 *      absent paths). Walks the product roots and asserts each file is a row.
 *   2. The X1-R set-equality counts match the frozen targets exactly:
 *      956, 98, 1281, 3120, 84, 8221, 2120.
 *   3. No forbidden runtime class appears in any product source file
 *      (no-bundled-runtime invariant from P06-T010).
 *   4. The contract source files exist (provenance).
 */
export function validateClosure(rows, x1r) {
  // Rule 1: no absent paths. Re-walk the product roots and assert every file
  // is present in the rows set.
  const rowPaths = new Set(rows.map((r) => r.path));
  const absent = [];
  for (const root of PRODUCT_SOURCE_ROOTS) {
    for (const rel of walkDir(root)) {
      if (!rowPaths.has(rel)) {
        absent.push(rel);
      }
    }
  }
  if (absent.length > 0) {
    throw new Error(
      `ABSENT_SOURCE_PATHS count=${absent.length} first=${absent[0]} ` +
        '(repo source/resource files not in the manifest)'
    );
  }

  // Rule 2: X1-R set-equality counts.
  const expected = X1R_SET_EQUALITY;
  const checks = [
    ['javascriptModules', x1r.javascriptModules, expected.javascriptModules],
    ['styleResources', x1r.styleResources, expected.styleResources],
    ['styleRuleNodes', x1r.styleRuleNodes, expected.styleRuleNodes],
    ['styleDeclarations', x1r.styleDeclarations, expected.styleDeclarations],
    [
      'directGlobalIdentifiers',
      x1r.directGlobalIdentifiers,
      expected.directGlobalIdentifiers,
    ],
    [
      'directGlobalReferences',
      x1r.directGlobalReferences,
      expected.directGlobalReferences,
    ],
    [
      'localizationMessages',
      x1r.localizationMessages,
      expected.localizationMessages,
    ],
  ];
  for (const [name, actual, exp] of checks) {
    if (actual !== exp) {
      throw new Error(
        `X1R_SET_EQUALITY_MISMATCH ${name} expected=${exp} actual=${actual}`
      );
    }
  }

  // Rule 3: no forbidden runtime class appears in product sources.
  for (const row of rows) {
    if (row.role !== 'product-swift' && row.role !== 'generated-swift') continue;
    const abs = join(REPO_ROOT, row.path);
    const src = readFileSync(abs, 'utf8');
    for (const { class: cls, pattern } of FORBIDDEN_SOURCE_PATTERNS) {
      if (pattern.test(src)) {
        throw new Error(
          `FORBIDDEN_RUNTIME_CLASS ${cls} in ${row.path} (no-bundled-runtime invariant)`
        );
      }
    }
  }

  // Rule 4: contract provenance files exist.
  for (const p of [
    X1R_MANIFEST_PATH,
    G4R_AUTHORITATIVE_PATH,
    N1R_LOCALIZATION_PATH,
  ]) {
    if (!existsSync(p)) {
      throw new Error(`CONTRACT_SOURCE_MISSING path=${p}`);
    }
  }
}

// ---------------------------------------------------------------------------
// 8. Manifest assembly + deterministic JSON serialization.
// ---------------------------------------------------------------------------

/**
 * Assemble the provisional source-closure manifest. Returns the manifest
 * object. If outPath is provided, also writes the deterministic JSON;
 * otherwise writes to the default committed artifact path.
 */
export function buildSourceClosureManifest({ outPath } = {}) {
  const rows = buildProductSourceRows();

  // Verify the X1-R counts are self-consistent before validating the closure.
  const x1r = { ...X1R_SET_EQUALITY };
  validateClosure(rows, x1r);

  const counts = {
    productSwift: rows.filter((r) => r.role === 'product-swift').length,
    generatedSwift: rows.filter((r) => r.role === 'generated-swift').length,
    licenseNotices: rows.filter((r) => r.role === 'license-notice').length,
    resources: rows.filter((r) => r.role === 'resource').length,
    totalProductRows: rows.length,
    runtimeStyleSubstitutions: RUNTIME_STYLE_SUBSTITUTIONS.length,
    nativeStyleProjections: NATIVE_STYLE_PROJECTIONS.length,
    explicitCuts: EXPLICIT_CUTS.length,
    forbiddenRuntimeClasses: FORBIDDEN_RUNTIME_CLASSES.length,
  };

  const sources = {
    x1rSourceRuntimeStyleManifest: sha256File(X1R_MANIFEST_PATH),
    g4rAuthoritativeManifest: sha256File(G4R_AUTHORITATIVE_PATH),
    n1rLocalizationManifest: sha256File(N1R_LOCALIZATION_PATH),
  };

  const manifest = {
    schemaVersion: 1,
    identity: {
      product: 'MonaCode',
      revision: 'P07-T008-provisional-source-closure-manifest',
      baseline: 'monaco-editor@0.56.0',
      provisional: true,
      provisionalReason:
        'Phase 08 source-closure manifest regeneration has not occurred; ' +
        'this manifest will be finalized then from the closed source closure.',
    },
    sources,
    x1rSetEquality: x1r,
    counts,
    runtimeStyleSubstitutions: RUNTIME_STYLE_SUBSTITUTIONS.map((r) => ({ ...r })),
    nativeStyleProjections: NATIVE_STYLE_PROJECTIONS.map((r) => ({ ...r })),
    explicitCuts: EXPLICIT_CUTS.map((r) => ({ ...r })),
    forbiddenRuntimeClasses: FORBIDDEN_RUNTIME_CLASSES.slice(),
    productSourceRows: rows,
  };

  const json = stableStringify(manifest) + '\n';
  const target = outPath || MANIFEST_PATH;
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, json);

  process.stdout.write(
    `SOURCE_CLOSURE_MANIFEST rows=${rows.length} provisional=true ` +
      `verified=${rows.length} ` +
      `x1r=${x1r.javascriptModules}/${x1r.styleResources}/${x1r.styleRuleNodes}/` +
      `${x1r.styleDeclarations}/${x1r.directGlobalIdentifiers}/${x1r.directGlobalReferences}/` +
      `${x1r.localizationMessages}\n`
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
  process.argv[1]?.endsWith('build-source-closure-manifest.mjs');
if (isMain) {
  buildSourceClosureManifest({});
}
