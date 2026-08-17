#!/usr/bin/env node
// Tools/PlanChecks/verify-provenance.mjs
//
// P00-T003 — Pin Monaco 0.56.0 M0 and M1 comparator provenance.
//
// The Monaco comparator oracles (M0 = monaco-editor npm, M1 = monaco-editor-core
// npm, plus the monaco-editor source tag) must be acquired from exact, hash-pinned
// sources so that every differential test can prove it ran against the real
// Monaco 0.56.0 and not a silently-drifted mirror. The archives themselves are
// large and temporary (disposition=temporary); they are never committed. What IS
// committed is the provenance record (monaco-provenance.json) that locks every
// archive's URL, SHA-256, byte count, and archive-entry count, plus the
// monaco.d.ts declaration hash.
//
// This checker verifies the COMMITTED provenance metadata is internally
// consistent. It does not download anything (the Red/Green verification
// commands run with network=forbidden). A separate acquisition step downloads
// the archives into a temporary directory and checks them against this record;
// that step is what produced the values locked here.
//
// Usage:
//   node Tools/PlanChecks/verify-provenance.mjs
//
// Exit status:
//   0 — the provenance record is internally consistent.
//   1 — one or more consistency checks failed (details on stderr).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const PROVENANCE_PATH = resolve(here, 'monaco-provenance.json');

const SHA256_RE = /^[0-9a-f]{64}$/;
const HEX40_RE = /^[0-9a-f]{40}$/;
const EXPECTED_MONACO_VERSION = '0.56.0';
const EXPECTED_SOURCE_COMMIT = '13f0c872dcf352815cc28d92dfff496c9839ea5c';

const errors = [];

function fail(message) {
  errors.push(message);
}

function isPositiveInteger(value) {
  return typeof value === 'number' && Number.isInteger(value) && value > 0;
}

function isNonNegativeInteger(value) {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0;
}

function isHttpsUrl(value) {
  try {
    const u = new URL(value);
    return u.protocol === 'https:';
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Load and parse the provenance record.
// ---------------------------------------------------------------------------

let record;
try {
  const raw = readFileSync(PROVENANCE_PATH, 'utf8');
  record = JSON.parse(raw);
} catch (err) {
  console.error(`verify-provenance: cannot read/parse ${PROVENANCE_PATH}: ${err.message}`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Top-level fields.
// ---------------------------------------------------------------------------

if (record.$schema !== 'monaco-provenance-v1') {
  fail(`$schema must be "monaco-provenance-v1", got ${JSON.stringify(record.$schema)}`);
}

if (record.monacoVersion !== EXPECTED_MONACO_VERSION) {
  fail(`monacoVersion must be "${EXPECTED_MONACO_VERSION}", got ${JSON.stringify(record.monacoVersion)}`);
}

if (record.sourceCommit !== EXPECTED_SOURCE_COMMIT) {
  fail(`sourceCommit must be "${EXPECTED_SOURCE_COMMIT}", got ${JSON.stringify(record.sourceCommit)}`);
}

if (!HEX40_RE.test(record.sourceCommit || '')) {
  fail(`sourceCommit must be a 40-hex SHA-1, got ${JSON.stringify(record.sourceCommit)}`);
}

// ---------------------------------------------------------------------------
// Archives.
// ---------------------------------------------------------------------------

if (!Array.isArray(record.archives) || record.archives.length !== 3) {
  fail(`archives must be an array of exactly 3 entries, got ${Array.isArray(record.archives) ? record.archives.length : 'non-array'}`);
} else {
  const seenIds = new Set();
  for (const arc of record.archives) {
    const aid = arc && arc.id ? arc.id : '<missing id>';

    // id — non-empty string, unique.
    if (typeof arc.id !== 'string' || arc.id.length === 0) {
      fail(`archive id must be a non-empty string (in ${JSON.stringify(arc)})`);
    } else if (seenIds.has(arc.id)) {
      fail(`archive id "${arc.id}" is duplicated`);
    } else {
      seenIds.add(arc.id);
    }

    // url — HTTPS.
    if (typeof arc.url !== 'string' || !isHttpsUrl(arc.url)) {
      fail(`archive "${aid}" url must be an HTTPS URL, got ${JSON.stringify(arc.url)}`);
    }

    // host — non-empty string that appears in the URL.
    if (typeof arc.host !== 'string' || arc.host.length === 0) {
      fail(`archive "${aid}" host must be a non-empty string`);
    } else if (typeof arc.url === 'string' && !arc.url.includes(arc.host)) {
      fail(`archive "${aid}" host "${arc.host}" does not appear in its url`);
    }

    // disposition — must be "temporary" (archives are never committed).
    if (arc.disposition !== 'temporary') {
      fail(`archive "${aid}" disposition must be "temporary", got ${JSON.stringify(arc.disposition)}`);
    }

    // sha256 — 64 lowercase hex.
    if (typeof arc.sha256 !== 'string' || !SHA256_RE.test(arc.sha256)) {
      fail(`archive "${aid}" sha256 must be 64 lowercase hex chars, got ${JSON.stringify(arc.sha256)}`);
    }

    // bytes — positive integer.
    if (!isPositiveInteger(arc.bytes)) {
      fail(`archive "${aid}" bytes must be a positive integer, got ${JSON.stringify(arc.bytes)}`);
    }

    // entries — positive integer.
    if (!isPositiveInteger(arc.entries)) {
      fail(`archive "${aid}" entries must be a positive integer, got ${JSON.stringify(arc.entries)}`);
    }

    // For the source-tag archive, regularFiles + directories must equal entries.
    if (arc.regularFiles !== undefined || arc.directories !== undefined) {
      if (!isNonNegativeInteger(arc.regularFiles)) {
        fail(`archive "${aid}" regularFiles must be a non-negative integer, got ${JSON.stringify(arc.regularFiles)}`);
      }
      if (!isNonNegativeInteger(arc.directories)) {
        fail(`archive "${aid}" directories must be a non-negative integer, got ${JSON.stringify(arc.directories)}`);
      }
      if (
        isNonNegativeInteger(arc.regularFiles) &&
        isNonNegativeInteger(arc.directories) &&
        isPositiveInteger(arc.entries) &&
        arc.regularFiles + arc.directories !== arc.entries
      ) {
        fail(
          `archive "${aid}" regularFiles (${arc.regularFiles}) + directories (${arc.directories}) = ${arc.regularFiles + arc.directories} does not equal entries (${arc.entries})`,
        );
      }
    }

    // The source-tag archive URL must embed the source commit identity.
    if (arc.id === 'monaco-source-tag') {
      if (typeof arc.url === 'string' && !arc.url.includes(record.sourceCommit)) {
        fail(`archive "${aid}" url must contain the sourceCommit "${record.sourceCommit}"`);
      }
    }
  }

  // Cross-archive: SHA-256 hashes must be unique (no two archives share a hash).
  const hashCounts = new Map();
  for (const arc of record.archives) {
    if (typeof arc.sha256 === 'string' && SHA256_RE.test(arc.sha256)) {
      hashCounts.set(arc.sha256, (hashCounts.get(arc.sha256) || 0) + 1);
    }
  }
  for (const [hash, count] of hashCounts) {
    if (count > 1) {
      fail(`sha256 "${hash}" is shared by ${count} archives (must be unique)`);
    }
  }
}

// ---------------------------------------------------------------------------
// Declarations (monaco.d.ts).
// ---------------------------------------------------------------------------

if (!record.declarations || typeof record.declarations !== 'object') {
  fail('declarations must be an object');
} else {
  const dts = record.declarations.monacoDts;
  if (!dts || typeof dts !== 'object') {
    fail('declarations.monacoDts must be an object');
  } else {
    // sha256 — 64 lowercase hex.
    if (typeof dts.sha256 !== 'string' || !SHA256_RE.test(dts.sha256)) {
      fail(`monacoDts sha256 must be 64 lowercase hex chars, got ${JSON.stringify(dts.sha256)}`);
    }

    // bytes — positive integer.
    if (!isPositiveInteger(dts.bytes)) {
      fail(`monacoDts bytes must be a positive integer, got ${JSON.stringify(dts.bytes)}`);
    }

    // path — non-empty string.
    if (typeof dts.path !== 'string' || dts.path.length === 0) {
      fail(`monacoDts path must be a non-empty string, got ${JSON.stringify(dts.path)}`);
    }

    // archiveId — must reference a declared archive.
    if (typeof dts.archiveId !== 'string' || dts.archiveId.length === 0) {
      fail(`monacoDts archiveId must be a non-empty string`);
    } else if (record.archives && !record.archives.some((a) => a.id === dts.archiveId)) {
      fail(`monacoDts archiveId "${dts.archiveId}" does not match any declared archive`);
    }
  }
}

// ---------------------------------------------------------------------------
// Report.
// ---------------------------------------------------------------------------

if (errors.length > 0) {
  for (const msg of errors) {
    console.error(`verify-provenance: ${msg}`);
  }
  console.error(`verify-provenance: ${errors.length} consistency error(s) in ${PROVENANCE_PATH}`);
  process.exit(1);
}

console.error(`verify-provenance: OK — 3 archives + monaco.d.ts provenance verified (${PROVENANCE_PATH})`);
process.exit(0);
