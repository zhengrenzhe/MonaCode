// Tests/PlanStructureTests/QEnvironmentCollectorTests.mjs
//
// P00-T011 — Collect a privacy-filtered QEnvironmentID and enforce formal preflight.
//
// This test is the Red/Green harness for the Swift qualification collector. It
// statically imports the JSON Schema (so a missing implementation surfaces as
// ERR_MODULE_NOT_FOUND), validates the schema document, runs the collector via
// `xcrun swift Tools/Qualification/QEnvironmentCollector.swift`, parses the
// emitted QEnvironmentID record, validates it against the schema, re-runs the
// recursive privacy audit in JavaScript to prove the record is privacy-filtered,
// and verifies the formal preflight (externalDisplayCount required to be zero)
// plus the pinned G5-R comparator provenance.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { writeFileSync, readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';

// Statically importing the schema makes a missing implementation fail with
// ERR_MODULE_NOT_FOUND during the Red stage before the schema exists.
import schema from '../../Tools/Qualification/qenvironment-schema.json' with { type: 'json' };

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const COLLECTOR = resolve(REPO_ROOT, 'Tools/Qualification/QEnvironmentCollector.swift');
const SWIFT = '/usr/bin/xcrun';
const G5R_MANIFEST = resolve(
  REPO_ROOT,
  'docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-qualification-environment-manifest.json'
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function runCollector(...extraArgs) {
  return spawnSync(SWIFT, ['swift', COLLECTOR, ...extraArgs], {
    encoding: 'utf8',
    cwd: REPO_ROOT,
    maxBuffer: 1 << 24,
  });
}

function parseStdout(result) {
  assert.equal(
    Buffer.isBuffer(result.stdout) === false,
    true,
    'stdout must be decoded string'
  );
  const text = (result.stdout ?? '').trim();
  assert.notEqual(text.length, 0, 'collector must emit JSON to stdout');
  return JSON.parse(text);
}

// Recursive privacy audit mirroring the Swift collector. Rejects any key
// matching /serial|uuid|udid|account|user/i and any UUID-shaped string value.
function privacyViolations(value, path = '$') {
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => privacyViolations(item, `${path}[${index}]`));
  }
  if (value !== null && typeof value === 'object') {
    return Object.entries(value).flatMap(([key, item]) => {
      const own = /serial|uuid|udid|account|user/i.test(key) ? [`${path}.${key}`] : [];
      return own.concat(privacyViolations(item, `${path}.${key}`));
    });
  }
  if (
    typeof value === 'string' &&
    /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i.test(value)
  ) {
    return [path];
  }
  return [];
}

function auditEnvironment(record) {
  return privacyViolations(record).map((subject) => ({
    id: 'PLAN_ENVIRONMENT_PRIVACY',
    subject,
    message: 'forbidden persistent environment identity',
  }));
}

// ---------------------------------------------------------------------------
// Minimal JSON-Schema validator (draft 2020-12 subset: type, required,
// properties, additionalProperties, const, enum, pattern, $ref to $defs,
// oneOf). Sufficient for the qenvironment-schema and dependency-free.
// ---------------------------------------------------------------------------

const TYPE_CHECKS = {
  object: (v) => v !== null && typeof v === 'object' && !Array.isArray(v),
  array: Array.isArray,
  string: (v) => typeof v === 'string',
  integer: (v) => Number.isInteger(v),
  number: (v) => typeof v === 'number',
  boolean: (v) => typeof v === 'boolean',
  null: (v) => v === null,
};

function resolveRef(ref, root) {
  if (!ref || !ref.startsWith('#/')) return null;
  const parts = ref.slice(2).split('/');
  let node = root;
  for (const part of parts) node = node?.[part];
  return node ?? null;
}

function validateSchema(value, node, root, path = '$', errors = []) {
  if (!node || typeof node !== 'object') return errors;
  if ('$ref' in node) {
    const target = resolveRef(node.$ref, root);
    if (target) validateSchema(value, target, root, path, errors);
    return errors;
  }
  if ('const' in node && value !== node.const) {
    errors.push(`${path}: expected const ${JSON.stringify(node.const)}, got ${JSON.stringify(value)}`);
  }
  if ('enum' in node && !node.enum.includes(value)) {
    errors.push(`${path}: value ${JSON.stringify(value)} not in enum ${JSON.stringify(node.enum)}`);
  }
  if ('type' in node) {
    const types = Array.isArray(node.type) ? node.type : [node.type];
    if (!types.some((t) => TYPE_CHECKS[t]?.(value))) {
      errors.push(`${path}: expected type ${JSON.stringify(node.type)}, got ${typeof value}`);
      return errors;
    }
  }
  if ('pattern' in node && typeof value === 'string' && !new RegExp(node.pattern).test(value)) {
    errors.push(`${path}: string ${JSON.stringify(value)} does not match ${node.pattern}`);
  }
  if (node.type === 'object' && value !== null && typeof value === 'object' && !Array.isArray(value)) {
    for (const key of node.required ?? []) {
      if (!(key in value)) errors.push(`${path}: missing required property ${key}`);
    }
    const allowed = node.properties ? Object.keys(node.properties) : null;
    const additional = node.additionalProperties;
    for (const key of Object.keys(value)) {
      if (allowed && !allowed.includes(key) && additional === false) {
        errors.push(`${path}: additional property ${key} not allowed`);
      }
      if (node.properties?.[key]) {
        validateSchema(value[key], node.properties[key], root, `${path}.${key}`, errors);
      }
    }
  }
  if (node.type === 'array' && Array.isArray(value)) {
    for (let i = 0; i < value.length; i++) {
      if (node.items) validateSchema(value[i], node.items, root, `${path}[${i}]`, errors);
    }
  }
  if ('oneOf' in node) {
    const branchErrors = [];
    const matched = node.oneOf.some((branch) => {
      const local = [];
      validateSchema(value, branch, root, path, local);
      branchErrors.push(local);
      return local.length === 0;
    });
    if (!matched) {
      errors.push(`${path}: matched no oneOf branch (${branchErrors.flat().length} sub-errors)`);
    }
  }
  return errors;
}

function validateAgainstSchema(value) {
  return validateSchema(value, schema, schema);
}

// ---------------------------------------------------------------------------
// Schema document checks
// ---------------------------------------------------------------------------

test('the schema document is a valid draft 2020-12 JSON Schema for the QEnvironmentID record', () => {
  assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
  assert.equal(schema.type, 'object');
  assert.equal(schema.additionalProperties, false);
  assert.deepEqual(schema.required, ['status', 'qEnvironmentId', 'record', 'formalPreflight']);
  assert.ok(schema.properties.qEnvironmentId.pattern.startsWith('^[0-9a-f]{64}$'));
  assert.ok(schema.properties.record.properties.chrome.properties.icu.required.includes('version'));
  assert.ok(schema.properties.record.properties.chrome.properties.icu.required.includes('dataSha256'));
  assert.ok('$defs' in schema && 'displaySlot' in schema.$defs);
  assert.ok(schema.privacyPolicy, 'schema must declare its privacy policy');
  assert.equal(schema.privacyPolicy.forbiddenKeyPattern, 'serial|uuid|udid|account|user');
  assert.match(
    schema.privacyPolicy.forbiddenValuePattern,
    /^\^\[0-9a-f\]\{8\}/
  );
  assert.equal(schema.privacyPolicy.externalDisplayCountRequiredForFormalRuns, 0);
});

test('the privacy audit recursively rejects forbidden keys and UUID-shaped values', () => {
  const findings = auditEnvironment({
    safe: {
      rows: [
        { serialNumber: 'redacted' },
        { value: 'BF2C6A3A-E639-51FE-853D-E9CE245A77D6' }
      ]
    }
  });
  assert.equal(findings.length, 2);
  assert.deepEqual(
    findings.map((f) => f.id),
    ['PLAN_ENVIRONMENT_PRIVACY', 'PLAN_ENVIRONMENT_PRIVACY']
  );
  assert.deepEqual(auditEnvironment({ architecture: 'arm64' }), []);
});

// ---------------------------------------------------------------------------
// Live collector run
// ---------------------------------------------------------------------------

let collected;

test('the collector runs via `xcrun swift` and emits parseable JSON', () => {
  const result = runCollector();
  const stderr = (result.stderr ?? '').trim();
  // Exit 0 (qualified, externalDisplayCount == 0) or exit 1
  // (formal-preflight-rejected, externalDisplayCount != 0). Both are valid
  // collector outcomes; exit 2 would mean a privacy violation, which must
  // never happen on a live qualified run.
  assert.ok(
    result.status === 0 || result.status === 1,
    `collector must exit 0 or 1; got ${result.status}. stderr: ${stderr}`
  );
  collected = parseStdout(result);
  assert.ok(['qualified', 'formal-preflight-rejected'].includes(collected.status));
});

test('the collector produces a QEnvironmentID hash of the collected fields', () => {
  assert.ok(collected, 'collector must have run');
  assert.match(
    collected.qEnvironmentId,
    /^[0-9a-f]{64}$/,
    'qEnvironmentId must be a 64-char lowercase hex SHA-256'
  );
  assert.equal(
    collected.qEnvironmentId.length,
    64,
    'qEnvironmentId must be exactly 64 hex chars'
  );
});

test('the emitted record satisfies the JSON Schema', () => {
  assert.ok(collected, 'collector must have run');
  const errors = validateAgainstSchema(collected);
  assert.deepEqual(errors, [], `schema validation errors:\n${errors.join('\n')}`);
});

test('the emitted record is privacy-filtered', () => {
  assert.ok(collected, 'collector must have run');
  assert.deepEqual(auditEnvironment(collected.record), []);
  assert.equal(collected.formalPreflight.privacy, 'pass');
});

test('the formal preflight requires externalDisplayCount equal to zero', () => {
  assert.ok(collected, 'collector must have run');
  assert.equal(collected.formalPreflight.required, 0);
  assert.equal(collected.record.externalDisplayCountRequired, 0);
  const observed = collected.formalPreflight.externalDisplayCount;
  assert.equal(
    Number.isInteger(observed),
    true,
    'externalDisplayCount must be an integer observation'
  );
  assert.equal(
    collected.formalPreflight.qualified,
    observed === 0,
    'qualified must be (externalDisplayCount === 0)'
  );
  assert.equal(
    collected.status === 'qualified',
    observed === 0,
    'status must reflect the qualified verdict'
  );
});

test('the record collects the exact OS, toolchain, architecture, display, input, locale, Chrome and ICU fields', () => {
  assert.ok(collected, 'collector must have run');
  const r = collected.record;

  // OS version + build.
  assert.match(r.macOS.version, /^\d+\.\d+\.\d+$/);
  assert.match(r.macOS.build, /^[0-9A-Z]+$/);

  // Toolchain: Swift, Xcode, Node.
  assert.match(r.toolchain.swift.version, /^\d+\./);
  assert.match(r.toolchain.xcode.version, /^\d+\./);
  assert.match(r.toolchain.xcode.build, /^[0-9A-Z]+$/);
  assert.match(r.toolchain.node.version, /^v?\d+\./);
  assert.match(r.toolchain.macOSSDK, /^\d+\./);

  // Architecture.
  assert.equal(r.architecture, 'arm64');

  // Hardware class (non-identifying).
  assert.equal(typeof r.hardwareClass.formFactor, 'string');
  assert.match(r.hardwareClass.modelClass, /^Mac/);
  assert.match(r.hardwareClass.chipClass, /Apple M/);
  assert.ok(r.hardwareClass.memoryGiB > 0);
  assert.ok(r.hardwareClass.gpuCoreCount > 0);
  assert.equal(r.hardwareClass.metalVersion, 'Metal 4');

  // Display: built-in present, external observation recorded.
  assert.ok(r.displays.builtIn.length >= 1, 'at least one built-in display');
  const builtIn = r.displays.builtIn[0];
  assert.equal(builtIn.connection, 'built-in');
  assert.equal(builtIn.pixels.width > 0 && builtIn.pixels.height > 0, true);
  assert.equal(builtIn.backingScale, 2);
  assert.ok(builtIn.refreshHz > 0);

  // Input source.
  assert.ok(Array.isArray(r.inputSourceIDs));
  assert.ok(r.inputSourceIDs.length >= 1);
  assert.ok(r.inputSourceIDs.every((id) => /^(keyboard-layout|input-mode):/.test(id)));

  // Locale + runtime locale.
  assert.match(r.locale.appleLocale, /^[a-z]{2}_/);
  assert.ok(Array.isArray(r.locale.appleLanguages));
  assert.match(r.locale.timeZone, /\//);
  assert.equal(r.runtimeLocale, r.locale.appleLocale.replace('_', '-'));

  // Chrome version.
  assert.match(r.chrome.version, /^\d+\.\d+\.\d+\.\d+$/);
  assert.match(r.chrome.binarySha256, /^[0-9a-f]{64}$/);

  // ICU version.
  assert.match(r.chrome.icu.version, /^\d+\.\d+$/);
  assert.match(r.chrome.icu.dataSha256, /^[0-9a-f]{64}$/);
});

test('the pinned Chrome/ICU/V8 comparator provenance matches the G5-R contract', () => {
  assert.ok(collected, 'collector must have run');
  const manifest = JSON.parse(readFileSync(G5R_MANIFEST, 'utf8'));
  const q = manifest.qualifiedEnvironment;
  const r = collected.record;

  assert.equal(r.chrome.version, q.chrome.version);
  assert.equal(r.chrome.binarySha256, q.chrome.binarySha256);
  assert.equal(r.chrome.chromiumTagCommit, q.chrome.chromiumTagCommit);
  assert.equal(r.chrome.v8.version, q.chrome.v8.version);
  assert.equal(r.chrome.v8.sourceCommit, q.chrome.v8.sourceCommit);
  assert.equal(r.chrome.icu.version, q.chrome.icu.version);
  assert.equal(r.chrome.icu.sourceCommit, q.chrome.icu.sourceCommit);
  assert.equal(r.chrome.icu.dataSha256, q.chrome.icu.dataSha256);
  assert.equal(r.chrome.timeSource.file, q.chrome.timeSource.file);
  assert.equal(r.chrome.timeSource.sha256, q.chrome.timeSource.sha256);
  assert.equal(r.macOS.version, q.macOS.version);
  assert.equal(r.macOS.build, q.macOS.build);
  assert.equal(r.architecture, q.architecture);
  assert.equal(r.toolchain.swift.version, q.swift.version);
  assert.equal(r.toolchain.xcode.version, q.xcode.version);
  assert.equal(r.toolchain.xcode.build, q.xcode.build);
  assert.equal(r.toolchain.macOSSDK, q.macOSSDK);
  assert.equal(r.hardwareClass.formFactor, q.hardwareClass.formFactor);
  assert.equal(r.hardwareClass.modelClass, q.hardwareClass.modelClass);
  assert.equal(r.hardwareClass.chipClass, q.hardwareClass.chipClass);
  assert.equal(r.hardwareClass.memoryGiB, q.hardwareClass.memoryGiB);
  assert.equal(r.hardwareClass.gpuCoreCount, q.hardwareClass.gpuCoreCount);
  assert.equal(r.hardwareClass.metalVersion, q.hardwareClass.metalVersion);
  assert.equal(r.locale.appleLocale, q.locale.appleLocale);
  assert.deepEqual(r.locale.appleLanguages, q.locale.appleLanguages);
  assert.equal(r.locale.timeZone, q.locale.timeZone);
  assert.deepEqual(r.inputSourceIDs, q.requiredInputSourceIDs);
  assert.equal(r.externalDisplayCountRequired, 0);
});

// ---------------------------------------------------------------------------
// Formal preflight enforcement (privacy rejection via --audit)
// ---------------------------------------------------------------------------

test('the collector rejects a forbidden record via --audit (exit 2, two findings)', () => {
  const dir = mkdtempSync(resolve(tmpdir(), 'qenv-audit-'));
  const forbiddenPath = resolve(dir, 'forbidden.json');
  writeFileSync(
    forbiddenPath,
    JSON.stringify({
      safe: {
        rows: [
          { serialNumber: 'redacted' },
          { value: 'BF2C6A3A-E639-51FE-853D-E9CE245A77D6' }
        ]
      }
    }),
    'utf8'
  );
  try {
    const result = runCollector('--audit', forbiddenPath);
    assert.equal(result.status, 2, 'privacy violation must exit 2');
    const out = parseStdout(result);
    assert.equal(out.status, 'privacy-violation');
    assert.equal(out.findings.length, 2);
    assert.deepEqual(
      out.findings.map((f) => f.id),
      ['PLAN_ENVIRONMENT_PRIVACY', 'PLAN_ENVIRONMENT_PRIVACY']
    );
    assert.ok(out.findings.some((f) => f.subject.endsWith('.serialNumber')));
    assert.ok(out.findings.some((f) => f.subject.endsWith('[1].value')));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('the collector accepts a clean record via --audit (exit 0)', () => {
  const dir = mkdtempSync(resolve(tmpdir(), 'qenv-audit-'));
  const cleanPath = resolve(dir, 'clean.json');
  writeFileSync(
    cleanPath,
    JSON.stringify({
      macOS: { version: '26.6.2', build: '25G83' },
      architecture: 'arm64',
      chrome: { icu: { version: '78.2' } }
    }),
    'utf8'
  );
  try {
    const result = runCollector('--audit', cleanPath);
    assert.equal(result.status, 0, 'clean record must exit 0');
    const out = parseStdout(result);
    assert.equal(out.status, 'ok');
    assert.deepEqual(out.findings, []);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('the QEnvironmentID is stable across repeated collections of the same environment', () => {
  const first = runCollector();
  const second = runCollector();
  assert.ok(first.status === 0 || first.status === 1);
  assert.ok(second.status === 0 || second.status === 1);
  const a = parseStdout(first);
  const b = parseStdout(second);
  // The volatile collectedAt timestamp is excluded from the hashed record, so
  // repeated collections of the same environment yield an identical identity.
  assert.match(a.qEnvironmentId, /^[0-9a-f]{64}$/);
  assert.match(b.qEnvironmentId, /^[0-9a-f]{64}$/);
  assert.equal(a.qEnvironmentId, b.qEnvironmentId, 'QEnvironmentID must be stable');
  // collectedAt differs (it is per-run provenance, not part of the identity).
  assert.notEqual(a.record.collectedAt, b.record.collectedAt);
});
