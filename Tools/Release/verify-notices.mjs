// Tools/Release/verify-notices.mjs
//
// P08-T003 — Assemble exact license provenance and distribution notices.
//
// This is the repo-owned Node license-verification tool for the MonaCode
// release distribution. It performs pure local verification (no network) and
// implements the four implementation operations from the G6-R plan leaf
// P08-T003:
//
//   1. Assemble Monaco MIT, Monaco localization MIT, Marked 14 MIT, LSP
//      specification CC BY 4.0, Codicon CC BY 4.0 plus Git Logo exception and
//      generator MIT, Unicode-3.0, Chromium ICU, Test262 BSD, and esbuild
//      comparator notices. (Reads Sources/MonaCode/Generated/LICENSE.md and
//      confirms all eleven license sections are present.)
//   2. Record DOMPurify, V8/ICU runtime, and vscode-unicode-data as
//      oracle-only or excluded inputs with no derived production code.
//      (Confirms LICENSE.md records all three as oracle-only/excluded.)
//   3. Verify pinned license hashes: LSP, Chromium ICU, Codicon artwork, and
//      Codicon code. (Cross-checks the four pinned hashes recorded in
//      LICENSE.md against the G6-R authoritative manifest's licensingProfile
//      / authorityArtifacts values.)
//   4. Attach provenance headers to every generated table and asset.
//      (Confirms every generated table and asset carries a provenance header
//      — task marker + license reference + source reference.)
//
// Usage
// -----
//   node Tools/Release/verify-notices.mjs
//       Emits a JSON report to stdout.
//       exit 0 — all four operations verified.
//       exit 1 — a gate failed (missing LICENSE.md, missing license section,
//                missing oracle/excluded record, pinned-hash mismatch, or a
//                generated table/asset missing its provenance header).
//
// Network is never used. All verification is local file introspection against
// the G6-R authoritative manifest.

import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');

const LICENSE_MD = resolve(REPO_ROOT, 'Sources/MonaCode/Generated/LICENSE.md');
const G6R_MANIFEST = resolve(
  REPO_ROOT,
  'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json',
);

// The eleven assembled license sections (operation 1).
const ELEVEN_LICENSES = [
  'Monaco (MIT)',
  'Monaco localization (MIT)',
  'Marked 14 (MIT)',
  'LSP specification (CC BY 4.0)',
  'Codicon (CC BY 4.0)',
  'Git Logo exception (CC BY 3.0)',
  'generator (MIT)',
  'Unicode-3.0',
  'Chromium ICU',
  'Test262 (BSD)',
  'esbuild comparator notice',
];

// The three oracle-only / excluded inputs (operation 2).
const ORACLE_OR_EXCLUDED = ['DOMPurify', 'V8/ICU runtime', 'vscode-unicode-data'];

// The four pinned license hashes (operation 3) — verbatim from the G6-R plan
// leaf P08-T003. These are cross-checked against the G6-R authoritative
// manifest's authorityArtifacts values.
const PINNED = {
  lsp: '9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188',
  chromiumIcu: 'e55522d81edc687a341a4411e0776e54ca654e90147f354a90458aaced4116af',
  codiconArtwork: 'af5e030844efddbc7ab00dcfea8b019703753d4d9f5172d727c533a492aec665',
  codiconCode: '9906940f61b1f0b533fa7d99baf55178b2808fbe113ea51dfbfad8572ccd5f2b',
};

// Generated tables and assets (operation 4). Each must carry a provenance
// header: a task marker (P0X-TXXX), a license reference, and a source
// reference. The headerBytes window is the leading bytes scanned.
const GENERATED_TABLES = [
  'Sources/MonaCode/Generated/MonaPublicAPI.swift',
  'Sources/MonaCode/Generated/MonaBuiltinKeybindings.swift',
  'Sources/MonaCode/Generated/MonaBuiltinMenus.swift',
  'Sources/MonaCode/Generated/MonaBuiltinOptions.swift',
  'Sources/MonaCode/Generated/MonaCodiconMap.swift',
  'Sources/MonaCode/Generated/MonaLocalizationProfiles.swift',
  'Sources/MonaCode/Generated/RegExp/MonaRegExpUnicodeTables.swift',
];

const GENERATED_ASSETS = [
  'Sources/MonaCode/Generated/MONACO-MIT-LICENSE.txt',
  'Sources/MonaCode/Generated/RegExp/UNICODE-LICENSE.txt',
  'Sources/MonaCode/Markdown/MARKED-MIT-LICENSE.txt',
  'Sources/MonaCode/Generated/LICENSE.md',
];

const LICENSE_KEYWORDS = /MIT|CC BY|Unicode|BSD|ICU|Apache|MPL/i;
// A provenance/contract marker: either a G6-R plan-leaf task id (P0X-TXXX)
// or one of the contract-baseline markers used by the license .txt files
// (MD1-R, N1-R, F1-R3, X1-R, E1-R, T1-R, M1-R, …) or an explicit provenance
// preamble. Every generated table/asset must carry one of these.
const CONTRACT_MARKER_RE =
  /P0\d-T\d{3}|\b[A-Z]{1,3}\d{0,3}-R\d?\b|pinned source provenance|contract baseline/i;
const HEADER_BYTES = 4096;
const SHA256_RE = /^[0-9a-f]{64}$/;

// --- helpers ---------------------------------------------------------------

function readText(p) {
  return readFileSync(p, 'utf8');
}

function readHeader(p) {
  // Read the leading HEADER_BYTES window for provenance-header scanning.
  const buf = readFileSync(p);
  const n = Math.min(HEADER_BYTES, buf.length);
  return buf.subarray(0, n).toString('utf8');
}

function loadManifest() {
  if (!existsSync(G6R_MANIFEST)) {
    return null;
  }
  return JSON.parse(readText(G6R_MANIFEST));
}

function findAuthorityArtifact(manifest, id) {
  const arts = (manifest && manifest.authorityArtifacts) || [];
  return arts.find((a) => a.id === id) || null;
}

// --- gates -----------------------------------------------------------------

function gateLicensesAssembled(licenseText) {
  const missing = ELEVEN_LICENSES.filter((label) => !licenseText.includes(label));
  return { ok: missing.length === 0, missing };
}

function gateOracleAndExcludedRecorded(licenseText) {
  const missing = ORACLE_OR_EXCLUDED.filter((name) => !licenseText.includes(name));
  const hasTerm = /oracle-only|excluded/i.test(licenseText);
  const hasNoDerived = /no derived production code/i.test(licenseText);
  return { ok: missing.length === 0 && hasTerm && hasNoDerived, missing, hasTerm, hasNoDerived };
}

function gatePinnedHashes(licenseText, manifest) {
  const result = {
    lsp: { inLicense: false, matchesManifest: false, manifestValue: null },
    chromiumIcu: { inLicense: false, matchesManifest: false, manifestValue: null },
    codiconArtwork: { inLicense: false, matchesManifest: false, manifestValue: null },
    codiconCode: { inLicense: false, matchesManifest: false, manifestValue: null },
  };

  // LSP license hash -> authorityArtifacts[id=lsp-3.18-snapshot].licenseSha256
  const lsp = findAuthorityArtifact(manifest, 'lsp-3.18-snapshot');
  const lspManifest = lsp ? lsp.licenseSha256 : null;
  result.lsp = {
    inLicense: licenseText.includes(PINNED.lsp),
    matchesManifest: lspManifest === PINNED.lsp,
    manifestValue: lspManifest,
  };

  // Chromium ICU license hash -> authorityArtifacts[id=chromium-151-icu-data].licenseSha256
  const icu = findAuthorityArtifact(manifest, 'chromium-151-icu-data');
  const icuManifest = icu ? icu.licenseSha256 : null;
  result.chromiumIcu = {
    inLicense: licenseText.includes(PINNED.chromiumIcu),
    matchesManifest: icuManifest === PINNED.chromiumIcu,
    manifestValue: icuManifest,
  };

  // Codicon artwork + code hashes -> authorityArtifacts[id=vscode-codicons]
  const codicon = findAuthorityArtifact(manifest, 'vscode-codicons');
  const artworkManifest = codicon ? codicon.artworkLicenseSha256 : null;
  const codeManifest = codicon ? codicon.codeLicenseSha256 : null;
  result.codiconArtwork = {
    inLicense: licenseText.includes(PINNED.codiconArtwork),
    matchesManifest: artworkManifest === PINNED.codiconArtwork,
    manifestValue: artworkManifest,
  };
  result.codiconCode = {
    inLicense: licenseText.includes(PINNED.codiconCode),
    matchesManifest: codeManifest === PINNED.codiconCode,
    manifestValue: codeManifest,
  };

  const ok =
    result.lsp.inLicense &&
    result.lsp.matchesManifest &&
    result.chromiumIcu.inLicense &&
    result.chromiumIcu.matchesManifest &&
    result.codiconArtwork.inLicense &&
    result.codiconArtwork.matchesManifest &&
    result.codiconCode.inLicense &&
    result.codiconCode.matchesManifest;

  // All pinned values must also be well-formed 64-hex SHA-256.
  const wellFormed = Object.values(PINNED).every((h) => SHA256_RE.test(h));

  return { ok: ok && wellFormed, detail: result };
}

function gateProvenanceHeaders(filePaths) {
  const problems = [];
  for (const rel of filePaths) {
    const abs = resolve(REPO_ROOT, rel);
    if (!existsSync(abs)) {
      problems.push({ file: rel, reason: 'missing file' });
      continue;
    }
    const head = readHeader(abs);
    // Contract/task marker (P0X-TXXX or a contract-baseline marker like MD1-R).
    const hasContractMarker = CONTRACT_MARKER_RE.test(head);
    // License reference (a license keyword OR the file is itself a LICENSE file).
    const isLicenseFile = /LICENSE\.|LICENSE-|MIT-LICENSE|UNICODE-LICENSE/i.test(rel);
    const hasLicenseRef = LICENSE_KEYWORDS.test(head) || isLicenseFile;
    // Source reference (a manifest path, a generator path, a commit hash, or a
    // provenance preamble).
    const hasSourceRef =
      /docs\/contracts|Tools\/Generators|Tools\/Release|manifest|commit|sha256|sha-256|GENERATED FILE|Source:|Provenance/i.test(head);
    if (!hasContractMarker || !hasLicenseRef || !hasSourceRef) {
      problems.push({
        file: rel,
        hasContractMarker,
        hasLicenseRef,
        hasSourceRef,
      });
    }
  }
  return { ok: problems.length === 0, problems };
}

// --- main ------------------------------------------------------------------

function main() {
  const report = {
    ok: false,
    licensesAssembled: false,
    oracleAndExcludedRecorded: false,
    pinnedHashesVerified: false,
    provenanceHeadersAttached: false,
    pinned: { ...PINNED },
    gates: {},
  };

  // LICENSE.md must exist.
  if (!existsSync(LICENSE_MD)) {
    report.error = 'LICENSE.md not found at ' + LICENSE_MD;
    process.stdout.write(JSON.stringify(report, null, 2) + '\n');
    process.exit(1);
  }
  const licenseText = readText(LICENSE_MD);

  // Gate 1: all eleven licenses assembled.
  const g1 = gateLicensesAssembled(licenseText);
  report.licensesAssembled = g1.ok;
  report.gates.licensesAssembled = g1;

  // Gate 2: oracle-only / excluded recorded.
  const g2 = gateOracleAndExcludedRecorded(licenseText);
  report.oracleAndExcludedRecorded = g2.ok;
  report.gates.oracleAndExcludedRecorded = g2;

  // Gate 3: pinned license hashes match the G6-R authoritative manifest.
  const manifest = loadManifest();
  const g3 = gatePinnedHashes(licenseText, manifest);
  report.pinnedHashesVerified = g3.ok;
  report.gates.pinnedHashes = g3;

  // Gate 4: provenance headers on every generated table and asset.
  const g4tables = gateProvenanceHeaders(GENERATED_TABLES);
  const g4assets = gateProvenanceHeaders(GENERATED_ASSETS);
  const g4 = {
    ok: g4tables.ok && g4assets.ok,
    tables: g4tables,
    assets: g4assets,
  };
  report.provenanceHeadersAttached = g4.ok;
  report.gates.provenanceHeaders = g4;

  report.ok =
    report.licensesAssembled &&
    report.oracleAndExcludedRecorded &&
    report.pinnedHashesVerified &&
    report.provenanceHeadersAttached;

  process.stdout.write(JSON.stringify(report, null, 2) + '\n');
  process.exit(report.ok ? 0 : 1);
}

main();
