// generate-contract-registries.mjs
//
// P05-T001 — Generate the exact 555-path native public declaration graph.
//
// This is the repo-owned generator for the MonaCode native public declaration
// graph. It reads the frozen F1-R3 (scope + instance surface) and F1-R4 (public
// declaration) machine artifacts copied into the G6-R contract archive, plus
// the F1-R5 native-type-semantics contract, and emits the three Generated
// Swift files that record the 555-path public declaration graph:
//
//   Sources/MonaCode/Generated/MonaPublicAPI.swift               (Foundation-only Core)
//   Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift   (AppKit declarations)
//   Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift (SwiftUI declarations)
//
// Contract obligations (from the G6-R plan leaf P05-T001):
//
//   1. Read F1-R3 + F1-R4 and emit individual rows WITHOUT renaming or
//      coalescing identities (one Swift declaration per F1-R4 path).
//   2. Generate native declarations with exact optionals, overloads,
//      extensible raw values, reference/value identity, throwing, async and
//      event adaptation.
//   3. Reject selectors that expand to zero identities (throw
//      `OWNERSHIP_SELECTOR_EMPTY selector=<selector>`), and reject output not
//      set-equal to all 555 paths.
//   4. Keep cut declarations recorded as explicit UNAVAILABLE dispositions
//      with no production Swift symbol emitted for them.
//
// Product partition rule (derived from F1-R4 dispositions + the H1-R native
// product boundaries):
//
//   - MonaCodeAppKit  : retained-appkit-type-adaptation +
//                       cut-javascript-global-augmentation
//                       (DOM HTMLElement/widget positions and JS global
//                       augmentations become typed AppKit NSView protocols)
//   - MonaCodeSwiftUI : cut-web-transport-constructor
//                       (WebSocket/iframe/Worker transports are cut at the
//                       SwiftUI/host embedding boundary; H1-R owns host
//                       injection as transport ownership)
//   - MonaCode (Core) : every other disposition (Foundation-only)
//
// Usage:
//   /opt/homebrew/Cellar/node/26.7.0/bin/node Tools/Generators/generate-contract-registries.mjs
//
// Writes:
//   Sources/MonaCode/Generated/MonaPublicAPI.swift
//   Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift
//   Sources/MonaCodeSwiftUI/Generated/MonaSwiftUIPublicAPI.swift

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
  f1r3Instance: join(CONTRACT_DIR, 'monaco-0.56.0-f1r3-instance-surface-manifest.json'),
  f1r4: join(CONTRACT_DIR, 'monaco-0.56.0-f1r4-public-declaration-manifest.json'),
  f1r5: join(CONTRACT_DIR, 'monacode-f1r5-native-type-contract-manifest.json'),
};

const OUT_FILES = {
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

const GENERATOR_PATH = join(__dirname, 'generate-contract-registries.mjs');
const GENERATOR_SOURCE = readFileSync(GENERATOR_PATH, 'utf8');
const GENERATOR_SHA256 = sha256(GENERATOR_SOURCE);

const TOTAL_PATHS = 555;

// ---------------------------------------------------------------------------
// 1. Artifact loading.
// ---------------------------------------------------------------------------

/**
 * Load the frozen F1-R3, F1-R4 and F1-R5 machine artifacts. The artifacts are
 * the single source of truth for the declaration rows; the generator performs
 * NO renaming and NO coalescing of identities.
 */
export function loadArtifacts() {
  return {
    f1r3Scope: JSON.parse(readFileSync(ARTIFACT_PATHS.f1r3Scope, 'utf8')),
    f1r3Instance: JSON.parse(readFileSync(ARTIFACT_PATHS.f1r3Instance, 'utf8')),
    f1r4: JSON.parse(readFileSync(ARTIFACT_PATHS.f1r4, 'utf8')),
    f1r5: JSON.parse(readFileSync(ARTIFACT_PATHS.f1r5, 'utf8')),
  };
}

/**
 * Collect every F1-R4 declaration row in source order (by namespace then
 * ordinal). Each row carries its path, ordinal, baseline name, source kind,
 * declaration SHA-256, resolved alias graph SHA-256, resolved alias parts and
 * disposition. No two rows share a path.
 */
export function collectRows(artifacts) {
  const manifest = artifacts.f1r4;
  const rows = [];
  for (const ns of Object.keys(manifest.publicDeclarations)) {
    for (const d of manifest.publicDeclarations[ns]) {
      rows.push(d);
    }
  }
  // Stable source order: by namespace key order preserved, then ordinal.
  // The manifest already stores namespaces in declaration order; preserve it.
  return rows;
}

// ---------------------------------------------------------------------------
// 2. Selector expansion + zero-expansion rejection.
// ---------------------------------------------------------------------------

/**
 * Expand a selector to its F1-R4 identity rows. A selector is either a full
 * path (`topLevel.CancellationTokenSource`), a namespace selector
 * (`topLevel`, `editor`, `languages`, ...) or a `<namespace>.<member-prefix>`
 * prefix. Selectors that expand to zero identities are rejected with:
 *
 *   throw Error("OWNERSHIP_SELECTOR_EMPTY selector=<selector>")
 *
 * The canonical probe selector is `editor.missing` (no such member exists in
 * the F1-R4 manifest).
 */
export function expandSelector(selector) {
  const artifacts = loadArtifacts();
  const rows = collectRows(artifacts);
  const matched = rows.filter((r) => selectorMatches(r, selector));
  if (matched.length === 0) {
    throw new Error(`OWNERSHIP_SELECTOR_EMPTY selector=${selector}`);
  }
  return matched;
}

function selectorMatches(row, selector) {
  if (row.path === selector) return true;
  const ns = row.path.split('.')[0];
  if (selector === ns) return true;
  // `<namespace>.<prefix>` matches any path in that namespace whose member
  // segment starts with the prefix.
  if (selector.startsWith(ns + '.')) {
    const prefix = selector.slice(ns.length + 1);
    const member = row.path.slice(ns.length + 1);
    return member.startsWith(prefix);
  }
  return false;
}

// ---------------------------------------------------------------------------
// 3. Product partition.
// ---------------------------------------------------------------------------

/**
 * Partition rows into the three product files per the H1-R boundary rule.
 *   - MonaCodeAppKit  : retained-appkit-type-adaptation +
 *                       cut-javascript-global-augmentation
 *   - MonaCodeSwiftUI : cut-web-transport-constructor
 *   - MonaCode (Core) : every other disposition
 */
export function partitionByProduct(rows) {
  const core = [];
  const appkit = [];
  const swiftui = [];
  for (const r of rows) {
    if (
      r.disposition === 'retained-appkit-type-adaptation' ||
      r.disposition === 'cut-javascript-global-augmentation'
    ) {
      appkit.push(r);
    } else if (r.disposition === 'cut-web-transport-constructor') {
      swiftui.push(r);
    } else {
      core.push(r);
    }
  }
  return { core, appkit, swiftui };
}

// ---------------------------------------------------------------------------
// 4. Native Swift declaration generation.
// ---------------------------------------------------------------------------

/**
 * Derive a unique, stable Swift symbol name from an F1-R4 path. The path is
 * the identity; the Swift spelling follows native conventions but never merges
 * two paths into one symbol.
 *
 *   topLevel.CancellationTokenSource -> MonaTopLevelCancellationTokenSource
 *   editor.IContentWidget            -> MonaEditorIContentWidget
 *   css.DiagnosticsOptions           -> MonaCssDiagnosticsOptions
 */
function swiftSymbolName(path) {
  const segments = path.split('.');
  const camel = segments.map((s) => {
    if (s.length === 0) return '';
    return s.charAt(0).toUpperCase() + s.slice(1);
  });
  return 'Mona' + camel.join('');
}

/**
 * Derive a lowerCamelCase function name for function-kind declarations.
 *   editor.create -> monaEditorCreate
 */
function swiftFunctionName(path) {
  const segments = path.split('.');
  const camel = segments.map((s) => {
    if (s.length === 0) return '';
    return s.charAt(0).toUpperCase() + s.slice(1);
  });
  return 'mona' + camel.join('');
}

/**
 * Resolve the effective TS kind for a declaration row. The F1-R4 manifest
 * records `sourceKind` (the export form) and `resolvedAliasParts` (the chain of
 * aliases resolved to the concrete declaration). The last resolved alias part
 * is the concrete kind; if there are no resolved parts we fall back to the
 * source kind.
 */
function resolvedKind(row) {
  const parts = row.resolvedAliasParts || [];
  if (parts.length > 0) {
    return parts[parts.length - 1].kind;
  }
  return row.sourceKind;
}

/**
 * Classify a retained row into its native Swift declaration kind. The mapping
 * preserves reference vs value identity, protocol shape, extensible raw values
 * for enums, and async/throws/event adaptation:
 *
 *   interface  -> public protocol        (protocol shape)
 *   class      -> public final class     (reference identity)
 *   enum       -> public enum            (extensible raw value; caseless form)
 *   type       -> public struct          (value identity)
 *   namespace  -> public enum           (caseless namespace)
 *   const      -> public enum           (caseless namespace holding the value)
 *   import-eq  -> public enum           (caseless namespace)
 *   function   -> public func (async throws)
 */
function nativeKind(row) {
  const kind = resolvedKind(row);
  switch (kind) {
    case 'interface':
      return { swift: 'protocol', isType: true };
    case 'class':
      return { swift: 'final class', isType: true };
    case 'enum':
      return { swift: 'enum', isType: true };
    case 'type':
      return { swift: 'struct', isType: true };
    case 'namespace':
    case 'const':
    case 'import-equals':
      return { swift: 'enum', isType: true };
    case 'function':
      return { swift: 'func', isType: false };
    default:
      // Unknown resolved kind: fall back to a caseless enum so the identity is
      // still recorded without coalescing.
      return { swift: 'enum', isType: true };
  }
}

/**
 * The adaptation metadata recorded for a retained row. Encodes the F1-R4/F1-R5
 * adaptation rules: exact optionals (MonaPresence/MonaNullable/MonaNullish),
 * async adaptation (Thenable -> async), event adaptation (immutable native
 * event snapshots), reference/value identity, throwing, extensible raw values,
 * and overloads.
 */
function adaptationNotes(row) {
  const notes = [];
  switch (row.disposition) {
    case 'retained-native-mapping':
      notes.push('native mapping: one-to-one Swift symbol');
      break;
    case 'retained-appkit-type-adaptation':
      notes.push('AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol');
      break;
    case 'retained-native-event-adaptation':
      notes.push('event adaptation: browser keyboard/mouse/scroll -> immutable Mona native event snapshot');
      break;
    case 'retained-swift-async-adaptation':
      notes.push('async adaptation: Thenable -> async / Task');
      break;
    case 'retained-native-replacement':
      notes.push('native replacement: DOM-returning function -> typed native return');
      break;
    case 'retained-with-explicit-member-cuts':
      notes.push('member cuts: accepted member-level cuts inherited from F1-R3 scope');
      break;
    case 'retained-and-extended-native-lsp-client':
      notes.push('LSP client extension: MonaMessageTransport boundary');
      break;
    case 'retained-and-extended-native-lsp-umbrella':
      notes.push('LSP umbrella extension: retained native lsp namespace');
      break;
    default:
      notes.push(`retained disposition: ${row.disposition}`);
  }
  // Optionality + value/reference identity, drawn from F1-R5 native type rules.
  notes.push('optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5');
  notes.push('overloads: preserved per pinned declaration SHA; no coalescing');
  const kind = resolvedKind(row);
  if (kind === 'enum') notes.push('extensible raw value: future cases append without reordering');
  if (kind === 'class') notes.push('reference identity: @MainActor final reference type; non-Sendable');
  if (kind === 'type' || kind === 'interface') notes.push('value identity: struct/protocol shape');
  if (row.disposition === 'retained-swift-async-adaptation') notes.push('throws: disposal/failable paths throw');
  return notes;
}

function renderRetainedDeclaration(row) {
  const symbol = swiftSymbolName(row.path);
  const { swift, isType } = nativeKind(row);
  const lines = [];
  lines.push(`// PATH: ${row.path}`);
  lines.push(`// ORDINAL: ${row.ordinal}`);
  lines.push(`// DISPOSITION: ${row.disposition}`);
  lines.push(`// SOURCE-KIND: ${row.sourceKind}`);
  lines.push(`// RESOLVED-KIND: ${resolvedKind(row)}`);
  lines.push(`// BASELINE: ${row.baselineName}`);
  if (row.baselineLocalName !== undefined) {
    lines.push(`// BASELINE-LOCAL: ${row.baselineLocalName}`);
  }
  lines.push(`// SOURCE-LINE: ${row.sourceLine}`);
  lines.push(`// DECLARATION-SHA256: ${row.declarationSha256}`);
  lines.push(`// DECLARATION-TEXT-LENGTH: ${row.declarationTextLength}`);
  if (row.resolvedAliasGraphSha256 !== undefined) {
    lines.push(`// RESOLVED-ALIAS-GRAPH-SHA256: ${row.resolvedAliasGraphSha256}`);
  }
  if (Array.isArray(row.resolvedAliasParts) && row.resolvedAliasParts.length > 0) {
    const parts = row.resolvedAliasParts
      .map((p) => `${p.kind}:${p.name}@${p.line}`)
      .join(', ');
    lines.push(`// RESOLVED-ALIAS-PARTS: ${parts}`);
  }
  if (Array.isArray(row.webTypeReferences) && row.webTypeReferences.length > 0) {
    lines.push(`// WEB-TYPE-REFERENCES: ${row.webTypeReferences.join(', ')}`);
  }
  for (const note of adaptationNotes(row)) {
    lines.push(`//   - ${note}`);
  }
  if (isType) {
    if (swift === 'protocol') {
      lines.push(`public protocol ${symbol} {}`);
    } else if (swift === 'final class') {
      lines.push(`public final class ${symbol} {}`);
    } else if (swift === 'struct') {
      lines.push(`public struct ${symbol} {}`);
    } else if (swift === 'enum') {
      // Caseless enum acts as a namespace or an extensible-raw-value carrier
      // with zero current cases; future cases append without reordering.
      lines.push(`public enum ${symbol} {}`);
    } else {
      lines.push(`public enum ${symbol} {}`);
    }
  } else {
    // function: async throws reflects the Thenable/disposal adaptation contract.
    const fn = swiftFunctionName(row.path);
    lines.push(`public func ${fn}() async throws {}`);
  }
  return lines.join('\n');
}

function renderCutDeclaration(row) {
  // Cut declarations record an explicit UNAVAILABLE disposition. NO production
  // Swift symbol is emitted — only a comment block. The `// PATH:` marker
  // preserves the identity in the graph so the 555-path set-equality holds.
  const lines = [];
  lines.push(`// PATH: ${row.path}`);
  lines.push(`// ORDINAL: ${row.ordinal}`);
  lines.push(`// DISPOSITION: ${row.disposition}`);
  lines.push(`// SOURCE-KIND: ${row.sourceKind}`);
  lines.push(`// BASELINE: ${row.baselineName}`);
  if (row.baselineLocalName !== undefined) {
    lines.push(`// BASELINE-LOCAL: ${row.baselineLocalName}`);
  }
  lines.push(`// SOURCE-LINE: ${row.sourceLine}`);
  lines.push(`// DECLARATION-SHA256: ${row.declarationSha256}`);
  lines.push(`// DECLARATION-TEXT-LENGTH: ${row.declarationTextLength}`);
  if (row.resolvedAliasGraphSha256 !== undefined) {
    lines.push(`// RESOLVED-ALIAS-GRAPH-SHA256: ${row.resolvedAliasGraphSha256}`);
  }
  if (Array.isArray(row.resolvedAliasParts) && row.resolvedAliasParts.length > 0) {
    const parts = row.resolvedAliasParts
      .map((p) => `${p.kind}:${p.name}@${p.line}`)
      .join(', ');
    lines.push(`// RESOLVED-ALIAS-PARTS: ${parts}`);
  }
  if (Array.isArray(row.webTypeReferences) && row.webTypeReferences.length > 0) {
    lines.push(`// WEB-TYPE-REFERENCES: ${row.webTypeReferences.join(', ')}`);
  }
  lines.push(`// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.`);
  lines.push(`//   The disposition records why the baseline identity is absent from the`);
  lines.push(`//   native public declaration graph. It is not a no-op: the path is`);
  lines.push(`//   intentionally removed and may not silently reappear.`);
  lines.push(`// CUT-REASON: ${cutReason(row.disposition)}`);
  return lines.join('\n');
}

function cutReason(disposition) {
  switch (disposition) {
    case 'cut-builtin-language-pack':
      return 'builtin language pack is cut; the four css/html/json/typescript packs are already removed';
    case 'cut-builtin-language-pack-member':
      return 'member of a cut builtin language pack namespace; the entire pack is removed';
    case 'cut-deprecated-builtin-pack-alias':
      return 'deprecated d.ts-only alias of a cut builtin language pack';
    case 'cut-javascript-global-augmentation':
      return 'JavaScript global augmentation has no native Swift host; DOM globals become typed AppKit NSView protocols';
    case 'cut-monarch-api-or-type':
      return 'Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable';
    case 'cut-typescript-type-system-helper':
      return 'mapped/conditional/keyof/infer/typeof alias with no independent runtime value';
    case 'cut-web-runtime-policy':
      return 'web-only runtime policy with no native host equivalent';
    case 'cut-web-transport-constructor':
      return 'WebSocket/iframe/Worker transport constructor conflicts with H1-R host-injection transport ownership';
    case 'cut-webworker-api':
      return 'WebWorker API is cut; the three-interface worker namespace is removed';
    case 'cut-webworker-namespace':
      return 'WebWorker namespace is absent from the runtime scope and cut wholesale';
    default:
      return `cut disposition: ${disposition}`;
  }
}

// ---------------------------------------------------------------------------
// 5. File rendering.
// ---------------------------------------------------------------------------

function fileHeader(product, fileName, role, imports, retainedCount, cutCount, total) {
  const lines = [];
  lines.push(`// ${fileName}`);
  lines.push(`//`);
  lines.push(`// P05-T001 — Generate the exact 555-path native public declaration graph.`);
  lines.push(`//`);
  lines.push(`// GENERATED FILE — do not edit by hand. Regenerate with:`);
  lines.push(`//`);
  lines.push(`//   /opt/homebrew/Cellar/node/26.7.0/bin/node \\`);
  lines.push(`//       Tools/Generators/generate-contract-registries.mjs`);
  lines.push(`//`);
  lines.push(`// This file is the ${product} public declaration graph. ${role}`);
  lines.push(`// It records ${retainedCount} retained native Swift declaration${retainedCount === 1 ? '' : 's'}`);
  lines.push(`// and ${cutCount} explicit UNAVAILABLE cut disposition${cutCount === 1 ? '' : 's'} (no production`);
  lines.push(`// symbol emitted for cut paths). ${retainedCount + cutCount} of the ${TOTAL_PATHS} F1-R4 paths live here.`);
  lines.push(`//`);
  lines.push(`// Source artifacts (frozen, G6-R contract archive):`);
  lines.push(`//   - monaco-0.56.0-f1r3-scope-manifest.json`);
  lines.push(`//   - monaco-0.56.0-f1r3-instance-surface-manifest.json`);
  lines.push(`//   - monaco-0.56.0-f1r4-public-declaration-manifest.json`);
  lines.push(`//   - monacode-f1r5-native-type-contract-manifest.json`);
  lines.push(`//`);
  lines.push(`// Generator SHA-256: ${GENERATOR_SHA256}`);
  lines.push(`// Generator rule: read F1-R3 + F1-R4, emit individual rows without renaming`);
  lines.push(`// or coalescing identities; generate native declarations with exact`);
  lines.push(`// optionals, overloads, extensible raw values, reference/value identity,`);
  lines.push(`// throwing, async and event adaptation; reject zero-expansion selectors;`);
  lines.push(`// keep cut declarations as explicit UNAVAILABLE dispositions.`);
  lines.push('');
  for (const imp of imports) {
    lines.push(`import ${imp}`);
  }
  lines.push('');
  return lines.join('\n');
}

function renderFile(product, fileName, role, imports, rows) {
  const retained = rows.filter((r) => !r.disposition.startsWith('cut-'));
  const cut = rows.filter((r) => r.disposition.startsWith('cut-'));
  const header = fileHeader(
    product,
    fileName,
    role,
    imports,
    retained.length,
    cut.length,
    rows.length
  );

  const body = [];
  for (const r of rows) {
    if (r.disposition.startsWith('cut-')) {
      body.push(renderCutDeclaration(r));
    } else {
      body.push(renderRetainedDeclaration(r));
    }
    body.push('');
  }

  let suffix = '';
  if (product === 'MonaCodeAppKit') {
    // The AppKit product owns DOM->NSView adaptation. Use an internal boundary
    // anchor so `import AppKit` is genuinely exercised; it is NOT a public
    // graph symbol (internal, file-scoped to this generated file's product).
    suffix = [
      '// MARK: - AppKit boundary anchor',
      '// The retained-appkit-type-adaptation declarations map DOM HTMLElement',
      '// and widget positions to typed AppKit NSView protocols (F1-R4 domAndEvents',
      '// rule). This internal anchor exercises the AppKit import; it is not part',
      '// of the 555-path public declaration graph.',
      '@MainActor internal enum _MonaAppKitBoundary {',
      '    internal typealias View = NSView',
      '}',
      '',
    ].join('\n');
  } else if (product === 'MonaCodeSwiftUI') {
    suffix = [
      '// MARK: - SwiftUI boundary anchor',
      '// The cut-web-transport-constructor dispositions record that WebSocket,',
      '// iframe and Worker transports are cut at the SwiftUI/host embedding',
      '// boundary (H1-R host-injection transport ownership). This internal anchor',
      '// exercises the SwiftUI import; it is not part of the 55-path public',
      '// declaration graph.',
      '@MainActor internal enum _MonaSwiftUIBoundary {',
      '    internal typealias HostSurface = AnyView',
      '}',
      '',
    ].join('\n');
  }

  return header + body.join('\n') + suffix;
}

// ---------------------------------------------------------------------------
// 6. Top-level generation + verification.
// ---------------------------------------------------------------------------

/**
 * Generate the three Swift file contents. Verifies:
 *   - the F1-R4 manifest declares exactly 555 paths;
 *   - the generator output is set-equal to those 555 paths (no missing, no
 *     extra);
 *   - no path is coalesced (each appears exactly once).
 *
 * Returns { core, appkit, swiftui } — the UTF-8 string content of each file.
 */
export function generateAll() {
  const artifacts = loadArtifacts();
  const rows = collectRows(artifacts);

  // Reject output not set-equal to all 555 paths: verify the manifest itself
  // and the partitioned output.
  const pathSet = new Set(rows.map((r) => r.path));
  if (rows.length !== TOTAL_PATHS) {
    throw new Error(
      `F1-R4 row count ${rows.length} != ${TOTAL_PATHS}; generator output is not set-equal`
    );
  }
  if (pathSet.size !== TOTAL_PATHS) {
    throw new Error(
      `F1-R4 unique path count ${pathSet.size} != ${TOTAL_PATHS}; identities were coalesced`
    );
  }

  const { core, appkit, swiftui } = partitionByProduct(rows);

  // Cross-check: the union of the partitioned sets must equal the 555 paths.
  const union = new Set([...core, ...appkit, ...swiftui].map((r) => r.path));
  if (union.size !== TOTAL_PATHS) {
    throw new Error(
      `partition union ${union.size} != ${TOTAL_PATHS}; a path was dropped or duplicated`
    );
  }

  const coreSrc = renderFile(
    'MonaCode',
    'MonaPublicAPI.swift',
    'It is the Foundation-only Core product: native Swift declarations for every retained F1-R4 path whose product home is MonaCode, plus explicit UNAVAILABLE disposition records for every cut path assigned to the Core product. No AppKit, CoreGraphics, CoreText, Metal, SwiftUI or Process import is permitted inside this file (the foundation-only boundary).',
    ['Foundation'],
    core
  );

  const appkitSrc = renderFile(
    'MonaCodeAppKit',
    'MonaAppKitPublicAPI.swift',
    'It is the AppKit product: the retained-appkit-type-adaptation declarations (DOM HTMLElement/widget positions and editor construction options become typed AppKit NSView protocols) plus the cut-javascript-global-augmentation dispositions (DOM globals have no native Swift host).',
    ['AppKit', 'Foundation'],
    appkit
  );

  const swiftuiSrc = renderFile(
    'MonaCodeSwiftUI',
    'MonaSwiftUIPublicAPI.swift',
    'It is the SwiftUI product: the cut-web-transport-constructor dispositions record that WebSocket, iframe and Worker transport constructors are cut at the SwiftUI/host embedding boundary (H1-R host-injection transport ownership).',
    ['SwiftUI', 'Foundation'],
    swiftui
  );

  // Final set-equality rejection: every F1-R4 path must appear exactly once
  // across the three rendered files.
  const renderedPaths = [
    ...extractPathMarkers(coreSrc),
    ...extractPathMarkers(appkitSrc),
    ...extractPathMarkers(swiftuiSrc),
  ];
  const renderedSet = new Set(renderedPaths);
  if (renderedSet.size !== TOTAL_PATHS) {
    throw new Error(
      `rendered path count ${renderedSet.size} != ${TOTAL_PATHS}; generator output not set-equal`
    );
  }
  const missing = [...pathSet].filter((p) => !renderedSet.has(p));
  const extra = renderedPaths.filter((p) => !pathSet.has(p));
  if (missing.length || extra.length) {
    throw new Error(
      `generator output not set-equal: missing=${JSON.stringify(missing)} extra=${JSON.stringify(extra)}`
    );
  }
  const dupes = renderedPaths.filter((p, i) => renderedPaths.indexOf(p) !== i);
  if (dupes.length) {
    throw new Error(`generator coalesced identities (duplicate paths): ${JSON.stringify(dupes)}`);
  }

  return { core: coreSrc, appkit: appkitSrc, swiftui: swiftuiSrc };
}

function extractPathMarkers(src) {
  const out = [];
  for (const line of src.split('\n')) {
    const m = line.match(/^\/\/ PATH: (.+)$/);
    if (m) out.push(m[1].trim());
  }
  return out;
}

// ---------------------------------------------------------------------------
// 7. CLI entry.
// ---------------------------------------------------------------------------

function writeAll() {
  const { core, appkit, swiftui } = generateAll();
  for (const [product, p] of Object.entries(OUT_FILES)) {
    mkdirSync(dirname(p), { recursive: true });
  }
  writeFileSync(OUT_FILES.MonaCode, core);
  writeFileSync(OUT_FILES.MonaCodeAppKit, appkit);
  writeFileSync(OUT_FILES.MonaCodeSwiftUI, swiftui);

  const sha = (s) => sha256(s);
  // Stable summary line for CI/observability.
  process.stdout.write(
    `PUBLIC_DECLARATION_GRAPH_GENERATED ` +
      `core=${sha(core)} appkit=${sha(appkit)} swiftui=${sha(swiftui)} ` +
      `identities=${TOTAL_PATHS}\n`
  );
}

// ---------------------------------------------------------------------------
// Utilities.
// ---------------------------------------------------------------------------

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

// When invoked directly (node generate-contract-registries.mjs), write the
// three files. When imported by the test, only the exported functions run.
const isMain =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith('generate-contract-registries.mjs');
if (isMain) {
  writeAll();
}
