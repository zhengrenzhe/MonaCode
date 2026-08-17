// generate-localization.mjs
//
// P05-T007 — Generate 15 immutable UI localization profiles with 2120 messages.
//
// This is the repo-owned generator for the MonaCode N1 UI localization
// surface. It reads the frozen N1-R localization manifest from the contract
// archive AND the pinned monaco-editor-core@0.56.0 final NLS artifacts
// (nls.keys.json / nls.messages.json / nls.messages.<locale>.js / vs/nls.js),
// and emits the immutable generated Swift profile tables:
//
//   Sources/MonaCode/Generated/MonaLocalizationProfiles.swift
//   Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt
//
// The 15 profiles × 2120 messages are transcribed VERBATIM from the pinned
// MIT artifacts (every locale JavaScript file is byte-identical to
// monaco-editor@0.56.0 esm/vs/nls/lang/<locale>.js). The core tarball is
// verified by SHA-256 against the N1-R manifest's `coreTarSha256` before any
// byte is read. No network access is performed at generation time; the
// tarball is located from the local npm cache (content-addressed by its
// recorded integrity) or an explicit `--core-tar` path / `MONACODE_CORE_TAR`
// environment variable.
//
// Output provenance: every generated profile table carries its pinned source
// SHA-256 (acceptance C10: "generated table hashes … are exact-set release
// resources") plus the source file name and the MIT notice.
//
// Usage:
//   /opt/homebrew/bin/node Tools/Generators/generate-localization.mjs
//   /opt/homebrew/bin/node Tools/Generators/generate-localization.mjs --core-tar /path/to/monaco-editor-core-0.56.0.tgz
//
// Reads:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-n1r-localization-manifest.json
//
// Writes:
//   Sources/MonaCode/Generated/MonaLocalizationProfiles.swift
//   Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import * as zlib from 'node:zlib';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..');
const MANIFEST_PATH = join(
  REPO_ROOT,
  'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-n1r-localization-manifest.json'
);
const OUT_SWIFT = join(REPO_ROOT, 'Sources/MonaCode/Generated/MonaLocalizationProfiles.swift');
const OUT_LICENSE = join(REPO_ROOT, 'Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt');

// ---------------------------------------------------------------------------
// 1. Load the frozen N1-R manifest.
// ---------------------------------------------------------------------------
const manifest = JSON.parse(readFileSync(MANIFEST_PATH, 'utf8'));
const CORE_TAR_SHA256 = manifest.authorities.coreTarSha256;
const PROFILE_DEFS = manifest.localeProfiles; // 15 entries
const SELECTABLE = manifest.scopeDisposition.selectableProfiles; // 15 ids

if (PROFILE_DEFS.length !== 15) {
  throw new Error(`N1-R manifest lists ${PROFILE_DEFS.length} profiles, expected 15`);
}
if (SELECTABLE.length !== 15) {
  throw new Error(`N1-R manifest selectableProfiles has ${SELECTABLE.length}, expected 15`);
}

// ---------------------------------------------------------------------------
// 2. Locate + verify the monaco-editor-core-0.56.0 tarball (no network).
// ---------------------------------------------------------------------------
function parseArgs(argv) {
  const out = { coreTar: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--core-tar' && i + 1 < argv.length) {
      out.coreTar = argv[++i];
    }
  }
  return out;
}

function sha256File(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function resolveCoreTar() {
  const args = parseArgs(process.argv.slice(2));
  if (args.coreTar) return args.coreTar;
  if (process.env.MONACODE_CORE_TAR) return process.env.MONACODE_CORE_TAR;

  // Resolve from the local npm cache: find the index entry for
  // monaco-editor-core-0.56.0.tgz, read its sha512 integrity, compute the
  // content-v2/sha512 path, and use that file. This is local-only.
  const home = process.env.HOME || '/Users/bytedance';
  const idxRoot = join(home, '.npm/_cacache/index-v5');
  if (!existsSync(idxRoot)) {
    throw new Error(
      'Could not locate monaco-editor-core-0.56.0.tgz. Pass --core-tar or set MONACODE_CORE_TAR.'
    );
  }
  const targetKeyFragment = 'monaco-editor-core/-/monaco-editor-core-0.56.0.tgz';
  let integrity = null;
  function walk(dir) {
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      const p = join(dir, e.name);
      if (e.isDirectory()) { if (walk(p)) return true; }
      else {
        const c = readFileSync(p, 'utf8');
        const lines = c.split('\n');
        for (const line of lines) {
          if (!line.trim()) continue;
          // npm cacache index-v5 line format: "<sha1>\t{json-object}"
          const tabIdx = line.indexOf('\t');
          const jsonPart = tabIdx >= 0 ? line.slice(tabIdx + 1) : line;
          try {
            const v = JSON.parse(jsonPart);
            if (v && v.key && v.key.includes(targetKeyFragment) && v.integrity) {
              integrity = v.integrity;
              return true;
            }
          } catch {}
        }
      }
    }
    return false;
  }
  walk(idxRoot);
  if (!integrity) {
    throw new Error(
      'monaco-editor-core-0.56.0.tgz not found in npm cache. Pass --core-tar or set MONACODE_CORE_TAR.'
    );
  }
  const b64 = integrity.slice('sha512-'.length);
  const hex = Buffer.from(b64, 'base64').toString('hex');
  const contentPath = join(home, '.npm/_cacache/content-v2/sha512', hex.slice(0, 2), hex.slice(2, 4), hex.slice(4));
  if (!existsSync(contentPath)) {
    throw new Error(
      `npm cache content file not found at ${contentPath}. Pass --core-tar or set MONACODE_CORE_TAR.`
    );
  }
  return contentPath;
}

const coreTarPath = resolveCoreTar();
const coreTarHash = sha256File(coreTarPath);
if (coreTarHash !== CORE_TAR_SHA256) {
  throw new Error(
    `monaco-editor-core-0.56.0.tgz SHA-256 mismatch:\n  got  ${coreTarHash}\n  want ${CORE_TAR_SHA256}`
  );
}
console.error(`[generate-localization] core tarball verified: ${coreTarHash}`);

// ---------------------------------------------------------------------------
// 3. Extract the NLS files from the verified tarball.
// ---------------------------------------------------------------------------
function readTarEntry(tarPath, entryName) {
  // Use system tar to extract a single member to stdout (gunzip transparently).
  return execSync(`tar -xzf "${tarPath}" -O "${entryName}"`, { maxBuffer: 1 << 28 });
}

function parseMessagesJs(buf) {
  // The locale JS sets: globalThis._VSCODE_NLS_MESSAGES=[...]; possibly
  // followed by globalThis._VSCODE_NLS_LANGUAGE="...";. Scan for the balanced
  // [...] array after the assignment, respecting JS string literals.
  const src = buf.toString('utf8');
  const marker = '_VSCODE_NLS_MESSAGES=';
  const start = src.indexOf(marker);
  if (start < 0) throw new Error('could not find _VSCODE_NLS_MESSAGES assignment');
  const arrStart = src.indexOf('[', start);
  if (arrStart < 0) throw new Error('could not find array start after assignment');
  // Scan to the matching closing ] (depth 0), tracking string literals.
  let depth = 0;
  let inStr = false;
  let strCh = '';
  let i = arrStart;
  for (; i < src.length; i++) {
    const c = src[i];
    if (inStr) {
      if (c === '\\') { i++; continue; }   // skip escaped char
      if (c === strCh) { inStr = false; }
      continue;
    }
    if (c === '"' || c === "'") { inStr = true; strCh = c; continue; }
    if (c === '[') depth++;
    else if (c === ']') {
      depth--;
      if (depth === 0) { break; }
    }
  }
  if (depth !== 0) throw new Error('unbalanced array');
  const arrText = src.slice(arrStart, i + 1);
  // The array is a JSON array of strings and nulls. Parse with JSON.parse
  // (single-quoted strings do not appear in these artifacts).
  return JSON.parse(arrText);
}

const keysJson = JSON.parse(readTarEntry(coreTarPath, 'package/esm/nls.keys.json').toString('utf8'));
const enMessages = JSON.parse(readTarEntry(coreTarPath, 'package/esm/nls.messages.json').toString('utf8'));
const nlsJsSource = readTarEntry(coreTarPath, 'package/esm/vs/nls.js').toString('utf8');
const licenseText = readTarEntry(coreTarPath, 'package/LICENSE').toString('utf8');

if (enMessages.length !== 2120) {
  throw new Error(`nls.messages.json has ${enMessages.length} entries, expected 2120`);
}

// Build the 2120 message identities (module path + key + flat index).
const identities = [];
const moduleIndices = Object.keys(keysJson).map(Number).sort((a, b) => a - b);
for (const mi of moduleIndices) {
  const [modulePath, keys] = keysJson[mi];
  for (let k = 0; k < keys.length; k++) {
    identities.push({ index: identities.length, modulePath, key: keys[k] });
  }
}
if (identities.length !== 2120) {
  throw new Error(`identities has ${identities.length} entries, expected 2120`);
}

// Build per-profile message tables. For each of the 15 profiles, produce the
// 2120-length [String?] table.
const profileTables = [];
for (const def of PROFILE_DEFS) {
  const id = def.id;
  let entries;
  if (id === 'en') {
    entries = enMessages.slice();
  } else if (id === 'pseudo') {
    // pseudo (runtime-transform): uses the English source messages; the
    // transform is applied at format time, not stored in the table.
    entries = enMessages.slice();
  } else {
    const buf = readTarEntry(coreTarPath, `package/esm/nls.messages.${id}.js`);
    entries = parseMessagesJs(buf);
  }
  if (entries.length !== 2120) {
    throw new Error(`profile ${id} has ${entries.length} entries, expected 2120`);
  }
  // Verify the locale file SHA-256 against the manifest.
  const fileSha = def.sha256;
  if (id !== 'en' && id !== 'pseudo') {
    const buf = readTarEntry(coreTarPath, `package/esm/nls.messages.${id}.js`);
    const actual = createHash('sha256').update(buf).digest('hex');
    if (actual !== fileSha) {
      throw new Error(`profile ${id} file SHA-256 mismatch: got ${actual}, want ${fileSha}`);
    }
  }
  // en hash is the JSON file hash.
  let sourceFileSha = fileSha;
  profileTables.push({
    id,
    kind: def.kind,
    entries,
    sha256: sourceFileSha,
    source: def.source,
    translated: def.translated,
    fallback: def.fallback,
  });
}

// ---------------------------------------------------------------------------
// 4. Swift string-literal emission (byte-exact escaping).
// ---------------------------------------------------------------------------
function emitStringLiteral(s) {
  // Escape for a Swift double-quoted string literal. Non-ASCII is emitted as
  // raw UTF-8 (Swift source is UTF-8); only control chars, quote, and
  // backslash are escaped.
  let out = '"';
  for (const ch of s) {
    const c = ch.codePointAt(0);
    if (c === 0x22) out += '\\"';            // "
    else if (c === 0x5C) out += '\\\\';       // \
    else if (c === 0x0A) out += '\\n';        // LF
    else if (c === 0x0D) out += '\\r';        // CR
    else if (c === 0x09) out += '\\t';        // TAB
    else if (c < 0x20) out += `\\u{${c.toString(16).toUpperCase()}}`;
    else out += ch;
  }
  out += '"';
  return out;
}

function emitOptionalString(s) {
  if (s === null || s === undefined) return 'nil';
  return emitStringLiteral(String(s));
}

function emitIdentities() {
  const lines = identities.map(
    (id) =>
      `        MonaLocalizationMessageIdentity(index: ${id.index}, modulePath: ${emitStringLiteral(
        id.modulePath
      )}, key: ${emitStringLiteral(id.key)}),`
  );
  return lines.join('\n');
}

function emitProfileTable(p) {
  // Emit the entries array, 4 per line for compactness.
  const entryChunks = [];
  for (let i = 0; i < p.entries.length; i += 4) {
    const chunk = p.entries.slice(i, i + 4).map(emitOptionalString).join(', ');
    entryChunks.push(`            ${chunk},`);
  }
  return `        MonaLocalizationProfileTable(
            id: ${emitStringLiteral(p.id)},
            kind: ${emitStringLiteral(p.kind)},
            source: ${emitStringLiteral(p.source)},
            sha256: ${emitStringLiteral(p.sha256)},
            translated: ${p.translated},
            fallback: ${p.fallback},
            entries: [
${entryChunks.join('\n')}
            ]
        )`;
}

const profileBlocks = profileTables.map(emitProfileTable).join(',\n');
const identitiesBlock = emitIdentities();

// ---------------------------------------------------------------------------
// 5. Emit MonaLocalizationProfiles.swift.
// ---------------------------------------------------------------------------
const swiftHeader = `// MonaLocalizationProfiles.swift
//
// P05-T007 — Generate 15 immutable UI localization profiles with 2120 messages.
//
// GENERATED FILE — do not edit by hand. Transcribed verbatim from the frozen
// N1-R localization manifest and the pinned monaco-editor-core@0.56.0 final
// NLS artifacts (esm/nls.keys.json / esm/nls.messages.json /
// esm/nls.messages.<locale>.js / esm/vs/nls.js). Regenerate by re-running the
// P05-T007 generator:
//   /opt/homebrew/bin/node Tools/Generators/generate-localization.mjs
//
// Contract archive manifest:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monacode-n1r-localization-manifest.json
//
// The 15 profiles × 2120 messages are immutable repository-owned Swift
// resources (acceptance C10). Every locale JavaScript file is byte-identical
// to monaco-editor@0.56.0 esm/vs/nls/lang/<locale>.js; the core tarball is
// verified by SHA-256 ${CORE_TAR_SHA256} at generation time.
//
// Lookup never calls Foundation localization or a network service
// (observableSemantics.storage). Profile selection is fixed before first
// service and is independent of the runtime locale (P00-T007).
//
// MonaCode is a Foundation-only target: \`import Foundation\` is the sole import.

import Foundation

// MARK: - Message identity (module path + key + flat index)

/// One N1 message identity: the flat index (0..<2120), the source module path,
/// and the message key within that module. The 2120-entry order is retained
/// from the pinned nls.keys module/key identity (observableSemantics.identity).
public struct MonaLocalizationMessageIdentity: Sendable, Equatable {
    /// The flat message index (\`0..<2120\`), matching the nls array position.
    public let index: Int
    /// The source module path (e.g. \`vs/base/browser/ui/actionbar/actionViewItems\`).
    public let modulePath: String
    /// The message key within the module (e.g. \`titleLabel\`).
    public let key: String
    public init(index: Int, modulePath: String, key: String) {
        self.index = index
        self.modulePath = modulePath
        self.key = key
    }
}

// MARK: - Profile table

/// One immutable N1 localization profile table: a language identifier, its
/// kind (default / packaged / packaged-all-fallback / runtime-transform), the
/// pinned source SHA-256, and the 2120-entry message vector. A \`nil\` entry
/// means "no profile-specific string — fall back to English" (the
/// packaged-all-fallback pt-br profile is 2120 nils).
public struct MonaLocalizationProfileTable: Sendable, Equatable {
    /// The N1 language identifier (\`en\`, \`cs\`, …, \`pseudo\`).
    public let id: String
    /// The profile kind (manifest \`localeProfiles[].kind\`).
    public let kind: String
    /// The pinned source file name (e.g. \`nls.messages.cs.js\`).
    public let source: String
    /// The pinned source SHA-256 (acceptance C10: generated table hashes).
    public let sha256: String
    /// The count of profile-specific translated (non-null) entries.
    public let translated: Int
    /// The count of entries that fall back to English.
    public let fallback: Int
    /// The 2120-entry message vector (a \`String?\` per slot).
    public let entries: [String?]
    public init(id: String, kind: String, source: String, sha256: String,
                translated: Int, fallback: Int, entries: [String?]) {
        self.id = id
        self.kind = kind
        self.source = source
        self.sha256 = sha256
        self.translated = translated
        self.fallback = fallback
        self.entries = entries
    }
}

// MARK: - The 15 immutable N1 profile tables

/// The 15 immutable N1 localization profiles × 2120 messages, transcribed
/// verbatim from the pinned monaco-editor-core@0.56.0 MIT artifacts.
///
/// \`MonaLocalizationProfiles\` is a namespace over the immutable generated
/// tables. It performs NO Foundation localization and NO network access.
public enum MonaLocalizationProfiles {

    /// All 2120 message identities in source-ordinal order (flat index
    /// \`0..<2120\`).
    public static let identities: [MonaLocalizationMessageIdentity] = [
${identitiesBlock}
    ]

    /// All 15 immutable profile tables, in manifest order (en, cs, de, es, fr,
    /// it, ja, ko, pl, pt-br, ru, tr, zh-cn, zh-tw, pseudo).
    public static let profiles: [MonaLocalizationProfileTable] = [
${profileBlocks}
    ]

    /// Returns the profile table for \`id\`, or \`nil\` when \`id\` is not one of
    /// the 15 N1 profiles.
    public static func profile(for id: String) -> MonaLocalizationProfileTable? {
        profiles.first { $0.id == id }
    }

    /// The Monaco Editor MIT license notice that accompanies the copied or
    /// generated message tables (manifest \`license.distribution\`).
    public static let monacoMitLicense: String = ${emitStringLiteral(licenseText)}
}
`;

mkdirSync(dirname(OUT_SWIFT), { recursive: true });
writeFileSync(OUT_SWIFT, swiftHeader);
console.error(`[generate-localization] wrote ${OUT_SWIFT}`);

// ---------------------------------------------------------------------------
// 6. Emit MONACO-MIT-LICENSE.txt.
// ---------------------------------------------------------------------------
const licenseFile = `MONACO-MIT-LICENSE.txt
//
// P05-T007 — Monaco Editor MIT license notice accompanying the generated N1
// localization profile tables (MonaLocalizationProfiles.swift).
//
// Source: monaco-editor-core@0.56.0 package/LICENSE (tarball SHA-256
// ${CORE_TAR_SHA256}). The 15 profile tables × 2120 messages are transcribed
// verbatim from this MIT-licensed artifact; the copyright and permission
// notice accompanies them per the N1-R manifest \`license.distribution\`.
//
// Copyright (c) 2016 - present Microsoft Corporation
//
---------------------------------------------------------------------------

${licenseText}`;
writeFileSync(OUT_LICENSE, licenseFile);
console.error(`[generate-localization] wrote ${OUT_LICENSE}`);
console.error(`[generate-localization] done: 15 profiles × 2120 messages emitted`);
