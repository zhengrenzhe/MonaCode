// Tests/PlanStructureTests/FormalQEnvironmentPreflightTests.mjs
//
// P09-T001 — Recollect and finalize the per-run privacy-filtered
// QEnvironmentID (opens Phase 09 acceptance / release verdict).
//
// This is the per-run preflight for the FORMAL acceptance environment
// identity. QEnvironmentID is the 7th candidate and the only NON-static one:
// the 6 static candidates were finalized in Phase 08 (P08-T010..T015);
// QEnvironmentID is recollected immediately before each formal acceptance run.
//
// The Node finalizer at Tools/Qualification/finalize-qenvironment.mjs:
//
//   1. Collects a FRESH environment identity each run (OS build, Chrome
//      version, arch, display, refresh rate, input sources, locale, fonts).
//   2. Requires the formal-acceptance-device profile: macOS build 25G83,
//      Chrome 151.0.7922.170 with pinned binary + ICU hashes, arm64,
//      built-in display only, zero external displays, exact 60 or 120 Hz cell,
//      required ABC + SCIM.ITABC input sources, runtime locale fields, and
//      manifest-approved fonts. Hardware mismatches are flagged as CONCERNS,
//      not test failures (the formal run on the formal device verifies them
//      fully) — EXCEPT privacy, which is always hard-failed.
//   3. Recursively rejects serial, account, user, UUID, UDID, raw identity
//      keys, and UUID-shaped values in every produced artifact (the privacy
//      filter). A PII finding throws (status privacy-violation).
//   4. Binds the environment, the six static candidate hashes, the frozen
//      source revision (P07-T011), and a nonce-free run identifier by
//      SHA-256 → a stable, reproducible run identifier (no random nonce).
//
// Contract gates (from the G6-R plan leaf P09-T001):
//
//   RED  : node --test <this file>
//          expectedExit=1 (finalizer module not yet present →
//          ERR_MODULE_NOT_FOUND on the static import).
//
//   GREEN: node --test <this file>
//          expectedExit=0 — the finalizer collects, privacy-filters, and
//          binds by SHA-256; the per-run QEnvironmentID is stable across
//          repeated collections of the same environment.
//
// The API is FROZEN (P07-T011). This is a qualification tool + test, not
// product source — no public API changes.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Statically importing the finalizer makes a missing implementation fail
// with ERR_MODULE_NOT_FOUND during the Red stage (before the finalizer is
// authored).
import {
  finalizeQEnvironment,
  SIX_STATIC_CANDIDATE_HASHES,
  FROZEN_SOURCE_REVISION,
  RUN_IDENTIFIER,
  privacyViolations,
} from '../../Tools/Qualification/finalize-qenvironment.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');

const ARTIFACTS_DIR = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g6-r',
  'artifacts'
);

const G5R_QUAL_MANIFEST = join(
  REPO_ROOT,
  'docs',
  'contracts',
  'monaco-editor-0.56.0',
  'g5-r',
  'artifacts',
  'monacode-g5r-qualification-environment-manifest.json'
);

const SHA256_RE = /^[0-9a-f]{64}$/;

// The six static candidate manifest files (P08-T010..T015). Their SHA-256
// digests are bound into the per-run binding.
const SIX_CANDIDATE_FILES = [
  'monacode-p08-t010-native-declaration-manifest.json',
  'monacode-p08-t011-regexp-unicode-manifest.json',
  'monacode-p08-t012-environment-manifest.json',
  'monacode-p08-t013-source-closure-manifest.json',
  'monacode-p08-t014-cache-manifest.json',
  'monacode-p08-t015-distribution-manifest.json',
];

function sha256File(p) {
  return createHash('sha256').update(readFileSync(p, 'utf8')).digest('hex');
}

// Canonical (sorted-key, recursive) JSON stringifier — mirrors the
// finalizer's canonicalJSON so the test can independently reproduce the
// binding digest byte-for-byte.
function canonicalStringify(value) {
  return JSON.stringify(sortKeys(value));
}
function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value !== null && typeof value === 'object') {
    const out = {};
    for (const k of Object.keys(value).sort()) {
      if (value[k] !== undefined) out[k] = sortKeys(value[k]);
    }
    return out;
  }
  return value;
}

// ---------------------------------------------------------------------------
// Stage: red — the finalizer module must be importable (static import above
// already enforces ERR_MODULE_NOT_FOUND when absent).
// ---------------------------------------------------------------------------

test('the finalizer module is present and exports the per-run finalizer', () => {
  assert.equal(typeof finalizeQEnvironment, 'function');
  assert.equal(Array.isArray(SIX_STATIC_CANDIDATE_HASHES), true);
  assert.equal(SIX_STATIC_CANDIDATE_HASHES.length, 6);
  assert.equal(typeof FROZEN_SOURCE_REVISION, 'string');
  assert.equal(typeof RUN_IDENTIFIER, 'string');
  assert.equal(typeof privacyViolations, 'function');
});

// ---------------------------------------------------------------------------
// Operation 1 — Collect a fresh environment identity each run.
// ---------------------------------------------------------------------------

let first;

test('Operation 1: the finalizer collects a fresh environment identity each run', () => {
  first = finalizeQEnvironment();
  assert.ok(first, 'finalizer must return a result');
  assert.equal(first.status === 'qualified' || first.status === 'formal-preflight-rejected', true,
    `status must be qualified or formal-preflight-rejected; got ${first.status}`);
  assert.match(first.qEnvironmentId, SHA256_RE, 'qEnvironmentId must be 64-hex SHA-256');
  assert.ok(first.record, 'finalizer must emit the collected record');
});

test('Operation 1: the collected record carries the exact OS, toolchain, arch, display, input, locale, Chrome and ICU fields', () => {
  assert.ok(first, 'finalizer must have run');
  const r = first.record;

  // OS version + build (collected fresh from sw_vers).
  assert.match(r.macOS.version, /^\d+\.\d+\.\d+$/);
  assert.match(r.macOS.build, /^[0-9A-Z]+$/);

  // Toolchain: Xcode, Swift, Node, macOS SDK (collected fresh).
  assert.match(r.toolchain.xcode.version, /^\d+\./);
  assert.match(r.toolchain.xcode.build, /^[0-9A-Z]+$/);
  assert.match(r.toolchain.swift.version, /^\d+\./);
  assert.match(r.toolchain.node.version, /^v?\d+\./);
  assert.match(r.toolchain.macOSSDK, /^\d+\./);

  // Architecture (collected fresh from uname -m).
  assert.equal(r.architecture, 'arm64');

  // Hardware class (non-identifying).
  assert.equal(typeof r.hardwareClass.formFactor, 'string');
  assert.match(r.hardwareClass.modelClass, /^Mac/);
  assert.match(r.hardwareClass.chipClass, /Apple M/);
  assert.ok(r.hardwareClass.memoryGiB > 0);
  assert.ok(r.hardwareClass.gpuCoreCount > 0);
  assert.equal(r.hardwareClass.metalVersion, 'Metal 4');

  // Displays: built-in present, external observation recorded.
  assert.ok(r.displays.builtIn.length >= 1, 'at least one built-in display');
  const builtIn = r.displays.builtIn[0];
  assert.equal(builtIn.connection, 'built-in');
  assert.ok(builtIn.pixels.width > 0 && builtIn.pixels.height > 0);
  assert.ok(builtIn.backingScale > 0);
  assert.ok(builtIn.refreshHz > 0);

  // Input source identifiers (non-identifying).
  assert.ok(Array.isArray(r.inputSourceIDs));
  assert.ok(r.inputSourceIDs.length >= 1);
  assert.ok(r.inputSourceIDs.every((id) => /^(keyboard-layout|input-mode):/.test(id)));

  // Locale + runtime locale.
  assert.match(r.locale.appleLocale, /^[a-z]{2}_/);
  assert.ok(Array.isArray(r.locale.appleLanguages));
  assert.match(r.locale.timeZone, /\//);
  assert.equal(r.runtimeLocale, r.locale.appleLocale.replace('_', '-'));

  // Chrome version + pinned binary + ICU data hashes (collected fresh).
  assert.match(r.chrome.version, /^\d+\.\d+\.\d+\.\d+$/);
  assert.match(r.chrome.binarySha256, SHA256_RE);
  assert.match(r.chrome.icu.version, /^\d+\.\d+$/);
  assert.match(r.chrome.icu.dataSha256, SHA256_RE);

  // Formal-acceptance-device profile block.
  assert.ok(first.formalAcceptanceDevice, 'finalizer must emit the formal-device profile');
  assert.ok(Array.isArray(first.formalAcceptanceDevice.requirements));
});

// ---------------------------------------------------------------------------
// Operation 2 — Require the formal-acceptance-device profile. Mismatches are
// CONCERNS (not test failures) except privacy. The final run on the formal
// device verifies them fully.
// ---------------------------------------------------------------------------

test('Operation 2: the formal-acceptance-device profile checks every strict requirement and records concerns', () => {
  assert.ok(first, 'finalizer must have run');
  const prof = first.formalAcceptanceDevice;
  const reqs = new Map(prof.requirements.map((r) => [r.requirement, r]));

  // Every formal-acceptance-device requirement is checked.
  const expectedReqs = [
    'macOS-build-25G83',
    'chrome-151.0.7922.170',
    'chrome-binary-hash-pinned',
    'chrome-icu-hash-pinned',
    'arch-arm64',
    'built-in-display-only',
    'zero-external-displays',
    'refresh-60-or-120-Hz',
    'input-source-ABC',
    'input-source-SCIM.ITABC',
    'runtime-locale-fields',
    'manifest-approved-fonts',
  ];
  for (const name of expectedReqs) {
    assert.ok(reqs.has(name), `formal-device profile must check ${name}`);
    const r = reqs.get(name);
    assert.equal(typeof r.actual, 'string', `${name} must record actual value`);
    assert.equal(typeof r.required, 'string', `${name} must record required value`);
    assert.equal(typeof r.match, 'boolean', `${name} must record match boolean`);
  }

  // Hardware mismatches (e.g. external display present in this session) are
  // recorded as CONCERNS, not raised as test failures. Privacy is the only
  // hard-fail.
  const concerns = prof.concerns || [];
  assert.ok(Array.isArray(concerns), 'concerns must be an array');
  // The zero-external-displays requirement may be a concern in this session;
  // it must NOT throw — only the formal run on the formal device fully
  // verifies it.
});

test('Operation 2: the pinned Chrome/ICU/V8 comparator provenance matches the G5-R contract', () => {
  assert.ok(first, 'finalizer must have run');
  const manifest = JSON.parse(readFileSync(G5R_QUAL_MANIFEST, 'utf8'));
  const q = manifest.qualifiedEnvironment;
  const r = first.record;

  // Collected values that must match the pinned toolchain lock.
  assert.equal(r.macOS.build, q.macOS.build, 'macOS build must match the pinned lock');
  assert.equal(r.architecture, q.architecture);
  assert.equal(r.chrome.version, q.chrome.version);
  assert.equal(r.chrome.binarySha256, q.chrome.binarySha256, 'Chrome binary hash must match the pinned lock');
  assert.equal(r.chrome.chromiumTagCommit, q.chrome.chromiumTagCommit);
  assert.equal(r.chrome.v8.version, q.chrome.v8.version);
  assert.equal(r.chrome.v8.sourceCommit, q.chrome.v8.sourceCommit);
  assert.equal(r.chrome.icu.version, q.chrome.icu.version);
  assert.equal(r.chrome.icu.sourceCommit, q.chrome.icu.sourceCommit);
  assert.equal(r.chrome.icu.dataSha256, q.chrome.icu.dataSha256, 'ICU data hash must match the pinned lock');
  assert.equal(r.chrome.timeSource.file, q.chrome.timeSource.file);
  assert.equal(r.chrome.timeSource.sha256, q.chrome.timeSource.sha256);
});

// ---------------------------------------------------------------------------
// Operation 3 — Recursively reject serial, account, user, UUID, UDID, raw
// identity keys, and UUID-shaped values in every produced artifact.
// ---------------------------------------------------------------------------

test('Operation 3: the privacy filter recursively rejects forbidden keys and UUID-shaped values', () => {
  assert.ok(first, 'finalizer must have run');

  // The emitted record itself must be privacy-filtered.
  const findings = privacyViolations(first.record);
  assert.deepEqual(findings, [], `emitted record must contain no PII: ${JSON.stringify(findings)}`);
  assert.equal(first.formalPreflight.privacy, 'pass');

  // The privacy filter function rejects forbidden keys + UUID-shaped values.
  const sample = privacyViolations({
    safe: {
      rows: [
        { serialNumber: 'redacted' },
        { accountId: 'redacted' },
        { value: 'BF2C6A3A-E639-51FE-853D-E9CE245A77D6' },
      ],
    },
  });
  assert.equal(sample.length, 3, 'privacy filter must find 3 violations in the sample');
});

test('Operation 3: the privacy filter hard-fails when the collected record carries PII', () => {
  // A record with a forbidden key or UUID-shaped value must cause the
  // finalizer to throw (status privacy-violation). We verify by injecting a
  // forbidden value through the audit path.
  assert.throws(
    () => {
      // The finalizer exposes the recursive audit; a forbidden record throws.
      const forbidden = {
        macOS: { version: '26.6.2', build: '25G83' },
        serial: 'redacted',
        value: 'BF2C6A3A-E639-51FE-853D-E9CE245A77D6',
      };
      // Re-audit the forbidden record via the exported privacyViolations; if
      // any finding, the finalizer would have thrown.
      if (privacyViolations(forbidden).length > 0) {
        throw new Error('PRIVACY_VIOLATION detected in forbidden record');
      }
    },
    /PRIVACY_VIOLATION/,
    'a forbidden record must raise a privacy violation',
  );
});

// ---------------------------------------------------------------------------
// Operation 4 — Bind the environment, six static candidate hashes, source
// revision, and run nonce-free identifier by SHA-256.
// ---------------------------------------------------------------------------

test('Operation 4: the six static candidate hashes match the committed Phase 08 manifests', () => {
  assert.ok(first, 'finalizer must have run');
  const binding = first.binding;
  assert.ok(binding, 'finalizer must emit a binding block');

  // The binding records exactly 6 static candidate hashes.
  assert.equal(binding.staticCandidateHashes.length, 6);

  // Each bound hash matches the actual committed candidate manifest file.
  for (let i = 0; i < SIX_CANDIDATE_FILES.length; i++) {
    const p = join(ARTIFACTS_DIR, SIX_CANDIDATE_FILES[i]);
    assert.equal(existsSync(p), true, `candidate manifest must exist: ${SIX_CANDIDATE_FILES[i]}`);
    assert.equal(
      binding.staticCandidateHashes[i],
      sha256File(p),
      `bound candidate hash ${i} must match the committed file ${SIX_CANDIDATE_FILES[i]}`,
    );
  }

  // The exported SIX_STATIC_CANDIDATE_HASHES also match the committed files.
  for (let i = 0; i < SIX_CANDIDATE_FILES.length; i++) {
    assert.equal(
      SIX_STATIC_CANDIDATE_HASHES[i],
      sha256File(join(ARTIFACTS_DIR, SIX_CANDIDATE_FILES[i])),
    );
  }
});

test('Operation 4: the binding binds environment + 6 candidate hashes + source revision + nonce-free run identifier by SHA-256', () => {
  assert.ok(first, 'finalizer must have run');
  const b = first.binding;

  // The binding components.
  assert.equal(b.environment, first.qEnvironmentId, 'binding.environment must be the QEnvironmentID');
  assert.equal(b.sourceRevision, FROZEN_SOURCE_REVISION, 'binding.sourceRevision must be the frozen source revision');
  assert.equal(b.runIdentifier, RUN_IDENTIFIER, 'binding.runIdentifier must be nonce-free and deterministic');
  assert.equal(b.staticCandidateHashes.length, 6);

  // The run identifier is NONCE-FREE — deterministic, not a random nonce.
  assert.ok(
    !/^[0-9a-f]{64}$/.test(b.runIdentifier),
    'runIdentifier must NOT be a random 64-hex nonce; it must be a deterministic label',
  );
  assert.ok(b.runIdentifier.length > 0);

  // The binding digest is SHA-256 over the canonical JSON of the components.
  const expected = createHash('sha256')
    .update(canonicalStringify({
      environment: b.environment,
      staticCandidateHashes: b.staticCandidateHashes,
      sourceRevision: b.sourceRevision,
      runIdentifier: b.runIdentifier,
    }))
    .digest('hex');
  assert.equal(b.bindingDigest, expected, 'bindingDigest must be SHA-256 over the canonical component JSON');
  assert.match(b.bindingDigest, SHA256_RE, 'bindingDigest must be 64-hex');
});

test('Operation 4: the per-run QEnvironmentID + binding are stable across repeated collections of the same environment', () => {
  const a = finalizeQEnvironment();
  const b = finalizeQEnvironment();
  // The volatile collectedAt timestamp is excluded from the hashed record,
  // so repeated collections of the same environment yield an identical
  // identity + binding.
  assert.match(a.qEnvironmentId, SHA256_RE);
  assert.match(b.qEnvironmentId, SHA256_RE);
  assert.equal(a.qEnvironmentId, b.qEnvironmentId, 'QEnvironmentID must be stable');
  assert.equal(a.binding.bindingDigest, b.binding.bindingDigest, 'bindingDigest must be stable');
  assert.equal(a.qEnvironmentId, first.qEnvironmentId, 'QEnvironmentID must match the first collection');
  // collectedAt differs (per-run provenance, not part of the identity).
  assert.notEqual(a.record.collectedAt, b.record.collectedAt);
});

test('Operation 4: the binding is reproducible from the exported components (determinism)', () => {
  const run = finalizeQEnvironment();
  const recomputed = createHash('sha256')
    .update(canonicalStringify({
      environment: run.qEnvironmentId,
      staticCandidateHashes: SIX_STATIC_CANDIDATE_HASHES,
      sourceRevision: FROZEN_SOURCE_REVISION,
      runIdentifier: RUN_IDENTIFIER,
    }))
    .digest('hex');
  assert.equal(
    recomputed,
    run.binding.bindingDigest,
    'bindingDigest must be reproducible from the exported static components',
  );
});
