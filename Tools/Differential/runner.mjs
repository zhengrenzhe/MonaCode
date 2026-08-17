// Tools/Differential/runner.mjs
//
// P00-T008 — Build the differential fixture and comparator harness.
//
// The Node.js differential runner. It loads differential fixtures from a
// directory, validates each against fixture-schema.json, invokes the native
// (MonaCode Swift) subject with ONE identical injected environment trace per
// fixture, captures the native raw UTF-16 output, and compares it against the
// M0 (npm monaco-editor@0.56.0) / M1 (built comparator) expected outputs that
// are baked into the fixture. It distinguishes the exact and native-adapted
// comparison domains in every fixture.
//
// The native subject is invoked by running the Swift test target
// (`xcrun swift test --filter DifferentialHarnessTests`) with two environment
// variables set:
//   - MONACODE_DIFFERENTIAL_FIXTURES  — the fixtures directory.
//   - MONACODE_DIFFERENTIAL_RESULTS  — a path where the native subject writes
//     a results manifest `{ results: [{ id, output: [code units] }] }`.
// The runner reads that manifest and compares each native output against
// `expected.exact` and `expected.nativeAdapted`.
//
// Raw UTF-16 inputs and outputs are arrays of 16-bit code units (0-65535), so
// unpaired surrogates survive WITHOUT Unicode repair.
//
// Usage:
//   node Tools/Differential/runner.mjs [fixturesDir] [--native]
//
//   fixturesDir  Directory of `*.json` fixtures.
//                Defaults to `Tests/Fixtures/DifferentialFixtures`.
//   --native     Invoke the native Swift subject and compare. Without this
//                flag the runner only validates fixtures against the schema.
//
// Exit status:
//   0 — all fixtures are schema-valid (and, in --native mode, every fixture
//       matches the nativeAdapted domain).
//   1 — one or more fixtures are invalid or a comparison failed.

import { readFileSync, readdirSync, existsSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const SCHEMA_PATH = resolve(here, 'fixture-schema.json');
const DEFAULT_FIXTURES_DIR = resolve(REPO_ROOT, 'Tests/Fixtures/DifferentialFixtures');
const SWIFT_BIN = process.env.MONACODE_SWIFT_BIN || 'xcrun';

// ---------------------------------------------------------------------------
// Schema validation (inline, no external dependencies).
// Mirrors Tools/Differential/fixture-schema.json.
// ---------------------------------------------------------------------------

const ID_RE = /^[A-Za-z0-9._-]+$/;

function isUInt16(n) {
  return Number.isInteger(n) && n >= 0 && n <= 65535;
}

function isUInt8(n) {
  return Number.isInteger(n) && n >= 0 && n <= 255;
}

function isFiniteNumber(n) {
  return typeof n === 'number' && Number.isFinite(n);
}

function validateCodeUnitArray(value, path) {
  const errors = [];
  if (!Array.isArray(value)) {
    errors.push(`${path} must be an array`);
    return errors;
  }
  value.forEach((u, i) => {
    if (!isUInt16(u)) {
      errors.push(`${path}[${i}] must be an integer in [0, 65535], got ${JSON.stringify(u)}`);
    }
  });
  return errors;
}

function validateFixture(obj) {
  const errors = [];
  if (obj === null || typeof obj !== 'object' || Array.isArray(obj)) {
    return { ok: false, errors: ['fixture must be a JSON object'] };
  }

  for (const key of ['id', 'input', 'expected', 'environmentTrace']) {
    if (!(key in obj)) {
      errors.push(`missing required field "${key}"`);
    }
  }

  // id
  if (typeof obj.id !== 'string' || !ID_RE.test(obj.id)) {
    errors.push('id must be a string matching ^[A-Za-z0-9._-]+$');
  }

  // input
  errors.push(...validateCodeUnitArray(obj.input, 'input'));

  // expected
  const exp = obj.expected;
  if (exp === null || typeof exp !== 'object' || Array.isArray(exp)) {
    errors.push('expected must be an object');
  } else {
    for (const key of ['exact', 'nativeAdapted']) {
      if (!(key in exp)) {
        errors.push(`missing required field "expected.${key}"`);
      }
    }
    errors.push(...validateCodeUnitArray(exp?.exact, 'expected.exact'));
    errors.push(...validateCodeUnitArray(exp?.nativeAdapted, 'expected.nativeAdapted'));
  }

  // environmentTrace
  const tr = obj.environmentTrace;
  if (tr === null || typeof tr !== 'object' || Array.isArray(tr)) {
    errors.push('environmentTrace must be an object');
  } else {
    const requiredTrace = [
      'wallMilliseconds',
      'highResolutionMilliseconds',
      'randomDoubles',
      'cryptoBytes',
      'localeIdentifier',
      'calendarIdentifier',
      'numberingSystem',
      'timeZoneIdentifier',
      'profileIdentifier',
    ];
    for (const key of requiredTrace) {
      if (!(key in tr)) {
        errors.push(`missing required field "environmentTrace.${key}"`);
      }
    }
    if (!isFiniteNumber(tr?.wallMilliseconds)) {
      errors.push('environmentTrace.wallMilliseconds must be a finite number');
    }
    if (!isFiniteNumber(tr?.highResolutionMilliseconds)) {
      errors.push('environmentTrace.highResolutionMilliseconds must be a finite number');
    }
    if (!Array.isArray(tr?.randomDoubles)) {
      errors.push('environmentTrace.randomDoubles must be an array');
    } else {
      tr.randomDoubles.forEach((d, i) => {
        if (!isFiniteNumber(d)) {
          errors.push(`environmentTrace.randomDoubles[${i}] must be a finite number`);
        }
      });
    }
    if (!Array.isArray(tr?.cryptoBytes)) {
      errors.push('environmentTrace.cryptoBytes must be an array');
    } else {
      tr.cryptoBytes.forEach((b, i) => {
        if (!isUInt8(b)) {
          errors.push(`environmentTrace.cryptoBytes[${i}] must be an integer in [0, 255]`);
        }
      });
    }
    for (const key of [
      'localeIdentifier',
      'calendarIdentifier',
      'numberingSystem',
      'timeZoneIdentifier',
      'profileIdentifier',
    ]) {
      if (typeof tr?.[key] !== 'string' || tr[key].length === 0) {
        errors.push(`environmentTrace.${key} must be a non-empty string`);
      }
    }
  }

  return { ok: errors.length === 0, errors };
}

// ---------------------------------------------------------------------------
// Fixture loading.
// ---------------------------------------------------------------------------

function loadFixtures(fixturesDir) {
  if (!existsSync(fixturesDir)) {
    return [];
  }
  const files = readdirSync(fixturesDir)
    .filter((f) => f.endsWith('.json'))
    .sort();
  const fixtures = [];
  for (const file of files) {
    const path = join(fixturesDir, file);
    let raw, obj;
    try {
      raw = readFileSync(path, 'utf8');
    } catch (err) {
      throw new Error(`cannot read fixture ${path}: ${err.message}`);
    }
    try {
      obj = JSON.parse(raw);
    } catch (err) {
      throw new Error(`fixture ${path} is not valid JSON: ${err.message}`);
    }
    const { ok, errors } = validateFixture(obj);
    if (!ok) {
      throw new Error(`fixture ${path} fails schema validation:\n  ${errors.join('\n  ')}`);
    }
    fixtures.push({ path, fixture: obj });
  }
  return fixtures;
}

// ---------------------------------------------------------------------------
// Native subject invocation.
// ---------------------------------------------------------------------------

function runNative(fixturesDir) {
  const resultsDir = mkdtempSync(join(tmpdir(), 'monacode-differential-'));
  const resultsPath = join(resultsDir, 'native-results.json');
  const env = {
    ...process.env,
    MONACODE_DIFFERENTIAL_FIXTURES: fixturesDir,
    MONACODE_DIFFERENTIAL_RESULTS: resultsPath,
  };
  const result = spawnSync(
    SWIFT_BIN,
    ['swift', 'test', '--filter', 'DifferentialHarnessTests'],
    { encoding: 'utf8', cwd: REPO_ROOT, env },
  );
  if (result.status !== 0) {
    rmSync(resultsDir, { recursive: true, force: true });
    throw new Error(
      `native subject (xcrun swift test) failed with status ${result.status}\n` +
        `stdout:\n${result.stdout || ''}\nstderr:\n${result.stderr || ''}`,
    );
  }
  if (!existsSync(resultsPath)) {
    rmSync(resultsDir, { recursive: true, force: true });
    throw new Error(
      'native subject did not emit a results manifest at MONACODE_DIFFERENTIAL_RESULTS',
    );
  }
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(resultsPath, 'utf8'));
  } catch (err) {
    rmSync(resultsDir, { recursive: true, force: true });
    throw new Error(`cannot parse native results manifest: ${err.message}`);
  }
  rmSync(resultsDir, { recursive: true, force: true });
  return manifest;
}

// ---------------------------------------------------------------------------
// Comparison.
// ---------------------------------------------------------------------------

function arraysEqual(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b)) return false;
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

function compareResults(fixtures, manifest) {
  const byId = new Map();
  for (const entry of manifest.results || []) {
    byId.set(entry.id, entry.output);
  }
  const verdicts = [];
  for (const { fixture } of fixtures) {
    const native = byId.get(fixture.id);
    if (native === undefined) {
      verdicts.push({
        id: fixture.id,
        exactMatch: false,
        nativeAdaptedMatch: false,
        missing: true,
      });
      continue;
    }
    verdicts.push({
      id: fixture.id,
      exactMatch: arraysEqual(native, fixture.expected.exact),
      nativeAdaptedMatch: arraysEqual(native, fixture.expected.nativeAdapted),
      missing: false,
    });
  }
  return verdicts;
}

// ---------------------------------------------------------------------------
// Reporting.
// ---------------------------------------------------------------------------

function report(fixtures, verdicts, nativeMode) {
  const lines = [];
  lines.push('differential-runner: ' + (nativeMode ? 'native comparison' : 'schema validation'));
  lines.push(`  fixtures: ${fixtures.length}`);
  if (nativeMode) {
    let exact = 0;
    let adapted = 0;
    let missing = 0;
    for (const v of verdicts) {
      if (v.missing) missing++;
      if (v.exactMatch) exact++;
      if (v.nativeAdaptedMatch) adapted++;
    }
    lines.push(`  exact matches:        ${exact}/${fixtures.length}`);
    lines.push(`  nativeAdapted matches: ${adapted}/${fixtures.length}`);
    if (missing > 0) {
      lines.push(`  missing native output: ${missing}`);
    }
    for (const v of verdicts) {
      const tag = v.nativeAdaptedMatch ? 'PASS' : 'FAIL';
      const exactTag = v.exactMatch ? 'exact' : 'no-exact';
      lines.push(`  [${tag}] ${v.id} (${exactTag})${v.missing ? ' MISSING' : ''}`);
    }
  }
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// CLI.
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = { fixturesDir: DEFAULT_FIXTURES_DIR, native: false };
  for (const a of argv.slice(2)) {
    if (a === '--native') {
      args.native = true;
    } else if (a.startsWith('--')) {
      throw new Error(`unknown option: ${a}`);
    } else {
      args.fixturesDir = resolve(a);
    }
  }
  return args;
}

function main(argv) {
  const args = parseArgs(argv);
  const fixtures = loadFixtures(args.fixturesDir);
  let verdicts = [];
  let ok = true;
  if (args.native) {
    const manifest = runNative(args.fixturesDir);
    verdicts = compareResults(fixtures, manifest);
    for (const v of verdicts) {
      if (!v.nativeAdaptedMatch) ok = false;
    }
  }
  const summary = report(fixtures, verdicts, args.native);
  if (!ok) {
    console.error(summary);
    console.error('differential-runner: FAIL');
    process.exit(1);
  }
  console.error(summary);
  console.error('differential-runner: OK');
  process.exit(0);
}

const isMain = import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  main(process.argv);
}

export {
  validateFixture,
  loadFixtures,
  runNative,
  compareResults,
  report,
  SCHEMA_PATH,
  DEFAULT_FIXTURES_DIR,
};
