// Tests/PlanStructureTests/LicenseNoticeTests.mjs
//
// P08-T003 — Assemble exact license provenance and distribution notices.
//
// This test drives `Tools/Release/verify-notices.mjs` and verifies the four
// implementation operations from the G6-R plan leaf P08-T003:
//
//   1. Assemble Monaco MIT, Monaco localization MIT, Marked 14 MIT, LSP
//      specification CC BY 4.0, Codicon CC BY 4.0 plus Git Logo exception and
//      generator MIT, Unicode-3.0, Chromium ICU, Test262 BSD, and esbuild
//      comparator notices. (LICENSE.md contains all eleven license sections,
//      each with its exact license text + provenance.)
//   2. Record DOMPurify, V8/ICU runtime, and vscode-unicode-data as
//      oracle-only or excluded inputs with no derived production code.
//      (LICENSE.md records all three as oracle-only/excluded.)
//   3. Verify pinned license hashes: LSP
//      9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188,
//      Chromium ICU
//      e55522d81edc687a341a4411e0776e54ca654e90147f354a90458aaced4116af,
//      Codicon artwork
//      af5e030844efddbc7ab00dcfea8b019703753d4d9f5172d727c533a492aec665,
//      Codicon code
//      9906940f61b1f0b533fa7d99baf55178b2808fbe113ea51dfbfad8572ccd5f2b.
//      (verify-notices.mjs confirms the four pinned license hashes match the
//      G6-R authoritative manifest's licensingProfile / authorityArtifacts.)
//   4. Attach provenance headers to every generated table and asset.
//      (verify-notices.mjs confirms every generated table and asset carries
//      a provenance header — task marker + license + source reference.)
//
// Contract gates (from the G6-R plan leaf P08-T003):
//
//   RED  : node --test <this file>
//          expectedExit=1 (LICENSE.md + verify-notices.mjs not yet present)
//
//   GREEN: node --test <this file>
//          expectedExit=0 — all four operations verified.
//
// The API is FROZEN (P07-T011); LICENSE.md is a Generated resource, not a
// public API symbol — adding it does not change the API.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { existsSync, readFileSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const VERIFY_NOTICES = resolve(REPO_ROOT, 'Tools/Release/verify-notices.mjs');
const LICENSE_MD = resolve(REPO_ROOT, 'Sources/MonaCode/Generated/LICENSE.md');

// The eleven assembled license sections (operation 1). Each must appear as a
// section heading in LICENSE.md with its exact license provenance.
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
const ORACLE_OR_EXCLUDED = [
  'DOMPurify',
  'V8/ICU runtime',
  'vscode-unicode-data',
];

// The four pinned license hashes (operation 3) — verbatim from the G6-R plan
// leaf P08-T003 implementation operation and the G6-R authoritative manifest.
const PINNED_HASHES = {
  lsp: '9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188',
  chromiumIcu: 'e55522d81edc687a341a4411e0776e54ca654e90147f354a90458aaced4116af',
  codiconArtwork: 'af5e030844efddbc7ab00dcfea8b019703753d4d9f5172d727c533a492aec665',
  codiconCode: '9906940f61b1f0b533fa7d99baf55178b2808fbe113ea51dfbfad8572ccd5f2b',
};

// --- helpers ---------------------------------------------------------------

function runVerifyNotices() {
  return spawnSync(NODE, [VERIFY_NOTICES], {
    encoding: 'utf8',
    cwd: REPO_ROOT,
    maxBuffer: 1 << 24,
    timeout: 60000,
  });
}

// --- RED gate --------------------------------------------------------------
// Before implementation: LICENSE.md and verify-notices.mjs do not exist, so
// the GREEN probes below fail (existsSync → false, spawnSync → non-zero).
// expectedExit=1. After implementation the GREEN probes pass → expectedExit=0.

// --- GREEN gate ------------------------------------------------------------

test('GREEN: LICENSE.md exists and contains all eleven license sections', () => {
  assert.ok(existsSync(LICENSE_MD), 'LICENSE.md must exist');
  const text = readFileSync(LICENSE_MD, 'utf8');
  for (const label of ELEVEN_LICENSES) {
    assert.ok(
      text.includes(label),
      `LICENSE.md must contain license section: ${label}`,
    );
  }
});

test('GREEN: LICENSE.md records DOMPurify, V8/ICU runtime, vscode-unicode-data as oracle-only/excluded', () => {
  assert.ok(existsSync(LICENSE_MD), 'LICENSE.md must exist');
  const text = readFileSync(LICENSE_MD, 'utf8');
  for (const name of ORACLE_OR_EXCLUDED) {
    assert.ok(
      text.includes(name),
      `LICENSE.md must record oracle-only/excluded input: ${name}`,
    );
  }
  // All three must be explicitly marked as oracle-only or excluded with no
  // derived production code.
  assert.ok(
    /oracle-only|excluded/i.test(text),
    'LICENSE.md must use the term oracle-only or excluded',
  );
  assert.ok(
    /no derived production code/i.test(text),
    'LICENSE.md must state no derived production code from oracle-only/excluded inputs',
  );
});

test('GREEN: LICENSE.md records all four pinned license hashes verbatim', () => {
  assert.ok(existsSync(LICENSE_MD), 'LICENSE.md must exist');
  const text = readFileSync(LICENSE_MD, 'utf8');
  for (const [key, hash] of Object.entries(PINNED_HASHES)) {
    assert.ok(
      text.includes(hash),
      `LICENSE.md must record pinned ${key} license hash: ${hash}`,
    );
  }
});

test('GREEN: verify-notices.mjs exits 0 and verifies all four operations', () => {
  assert.ok(existsSync(VERIFY_NOTICES), 'verify-notices.mjs must exist');
  const res = runVerifyNotices();
  assert.equal(res.status, 0, `verify-notices.mjs must exit 0; got stderr:\n${res.stderr}`);
  assert.ok(res.stdout.length > 0, 'verify-notices.mjs must emit a JSON report');
  let report;
  try {
    report = JSON.parse(res.stdout);
  } catch (e) {
    assert.fail(`verify-notices.mjs stdout must be valid JSON; got:\n${res.stdout}`);
  }
  assert.equal(report.ok, true, 'verify-notices.mjs report.ok must be true');
  assert.equal(report.licensesAssembled, true, 'operation 1 (licenses assembled)');
  assert.equal(report.oracleAndExcludedRecorded, true, 'operation 2 (oracle/excluded recorded)');
  assert.equal(report.pinnedHashesVerified, true, 'operation 3 (pinned hashes verified)');
  assert.equal(report.provenanceHeadersAttached, true, 'operation 4 (provenance headers)');
  // The four pinned hashes must be reported as matching the contract.
  assert.equal(report.pinned.lsp, PINNED_HASHES.lsp);
  assert.equal(report.pinned.chromiumIcu, PINNED_HASHES.chromiumIcu);
  assert.equal(report.pinned.codiconArtwork, PINNED_HASHES.codiconArtwork);
  assert.equal(report.pinned.codiconCode, PINNED_HASHES.codiconCode);
});
