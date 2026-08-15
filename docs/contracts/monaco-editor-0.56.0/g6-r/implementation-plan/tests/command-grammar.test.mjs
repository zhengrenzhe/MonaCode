// G6-R command grammar converter and baseline checker tests (TDD Step 1).
// Asserts the closed command grammar: topology classification, leaf forms,
// the 20 Node-test option reorders, forbidden-shell rejection, and the
// P00-T001 baseline package-graph checker. Node built-in test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import * as cp from 'node:child_process';

import {
  convertG5Command,
  auditCommandSpec,
  parseObservedG5Command,
  summarizeConversion,
} from '../lib/command-grammar.mjs';
import { assertPackageGraph } from '../runtime/assert-package-graph.mjs';

const NODE_BIN = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const XCRUN_BIN = '/usr/bin/xcrun';

const REPO_ROOT = path.resolve(import.meta.dirname, '..', '..', '..', '..', '..', '..');
const MANIFEST_PATH = path.join(
  REPO_ROOT,
  'docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json',
);
const MANIFEST = JSON.parse(readFileSync(MANIFEST_PATH, 'utf8'));

// Convert the entire embedded G5-R parent plan (200 tasks x red+green = 400 records).
function convertAll() {
  const records = [];
  for (const task of MANIFEST.tasks) {
    for (const stage of ['red', 'green']) {
      task[stage].forEach((row, index) => {
        records.push(convertG5Command({ task, stage, index, row }));
      });
    }
  }
  return records;
}

const EXPECTED_SUMMARY =
  'records=400 process=393 allSuccess=5 pipeline=2 leaves=407 swiftTest=359 nodeTest=42 nodeScript=4 swiftPackage=2 nodeOptionReorders=20 unsupported=0';

// ---------------------------------------------------------------------------
// parseObservedG5Command topology classification
// ---------------------------------------------------------------------------

test('parseObservedG5Command classifies process / all-success / pipeline', () => {
  assert.deepEqual(parseObservedG5Command('swift test --filter X'), { topology: 'process', leaves: ['swift test --filter X'] });
  assert.deepEqual(parseObservedG5Command('swift test --filter A && swift test --filter B'), { topology: 'all-success', leaves: ['swift test --filter A', 'swift test --filter B'] });
  assert.deepEqual(parseObservedG5Command('swift package dump-package | node checker.mjs'), { topology: 'pipeline', leaves: ['swift package dump-package', 'node checker.mjs'] });
});

test('parseObservedG5Command rejects empty input', () => {
  assert.throws(() => parseObservedG5Command(''), /PLAN_COMMAND_FORM_UNSUPPORTED/);
  assert.throws(() => parseObservedG5Command('   '), /PLAN_COMMAND_FORM_UNSUPPORTED/);
});

// ---------------------------------------------------------------------------
// Exact conversion counts from the embedded G5-R parent plan
// ---------------------------------------------------------------------------

test('conversion produces exactly 400 records with the pinned topology split', () => {
  const records = convertAll();
  assert.equal(records.length, 400);
  const byKind = { process: 0, 'all-success': 0, pipeline: 0 };
  for (const r of records) byKind[r.kind]++;
  assert.deepEqual(byKind, { process: 393, 'all-success': 5, pipeline: 2 });
});

test('conversion produces exactly 407 leaves with the pinned form split', () => {
  const records = convertAll();
  const leaves = records.flatMap((r) => r.leaves);
  assert.equal(leaves.length, 407);
  const byForm = { 'swift-test': 0, 'node-test': 0, 'node-script': 0, 'swift-package': 0 };
  for (const l of leaves) byForm[l.form]++;
  assert.deepEqual(byForm, { 'swift-test': 359, 'node-test': 42, 'node-script': 4, 'swift-package': 2 });
});

test('conversion produces exactly 20 Node-test option reorders and no other reorders', () => {
  const records = convertAll();
  const leaves = records.flatMap((r) => r.leaves);
  const reorders = leaves.filter((l) => l.optionReorder);
  assert.equal(reorders.length, 20);
  assert.equal(reorders.every((l) => l.form === 'node-test'), true);
});

test('summarizeConversion emits the exact pinned summary line', () => {
  const records = convertAll();
  assert.equal(summarizeConversion(records), EXPECTED_SUMMARY);
});

// ---------------------------------------------------------------------------
// Leaf executable + argv invariants across every converted leaf
// ---------------------------------------------------------------------------

test('every Swift-test leaf uses xcrun, argv starts swift test, carries --scratch-path', () => {
  const leaves = convertAll().flatMap((r) => r.leaves).filter((l) => l.form === 'swift-test');
  assert.equal(leaves.length, 359);
  for (const l of leaves) {
    assert.equal(l.executable, XCRUN_BIN);
    assert.equal(l.args[0], 'swift');
    assert.equal(l.args[1], 'test');
    const sp = l.args.indexOf('--scratch-path');
    assert.ok(sp > 1, 'swift-test leaf must carry --scratch-path');
    assert.ok(typeof l.args[sp + 1] === 'string' && l.args[sp + 1].length > 0, '--scratch-path must name a dir');
  }
});

test('every Swift-package leaf uses xcrun and argv starts swift package', () => {
  const leaves = convertAll().flatMap((r) => r.leaves).filter((l) => l.form === 'swift-package');
  assert.equal(leaves.length, 2);
  for (const l of leaves) {
    assert.equal(l.executable, XCRUN_BIN);
    assert.equal(l.args[0], 'swift');
    assert.equal(l.args[1], 'package');
  }
});

test('every Node leaf uses the pinned Node binary', () => {
  const leaves = convertAll().flatMap((r) => r.leaves).filter((l) => l.form === 'node-test' || l.form === 'node-script');
  assert.equal(leaves.length, 46);
  for (const l of leaves) assert.equal(l.executable, NODE_BIN);
});

test('convertLeaf rewrites only the 20 Node-test argv from file-before-option to option-before-file', () => {
  const leaves = convertAll().flatMap((r) => r.leaves).filter((l) => l.form === 'node-test');
  for (const l of leaves) {
    const i = l.args.indexOf('--test');
    assert.ok(i === 0, 'node-test argv must start with --test');
    if (l.args.includes('--test-name-pattern')) {
      // normalized form: --test --test-name-pattern VALUE FILE
      assert.equal(l.args[i + 1], '--test-name-pattern');
      const patIdx = i + 1;
      assert.ok(typeof l.args[patIdx + 1] === 'string' && l.args[patIdx + 1].length > 0);
      // the FILE (a .mjs path) must come AFTER the pattern value
      const fileToken = l.args.find((a, idx) => idx > patIdx + 1 && a.endsWith('.mjs'));
      assert.ok(fileToken, 'node-test argv must place the .mjs file after the pattern value');
    }
  }
});

test('no converted leaf retains the absent G5-R checker path', () => {
  const leaves = convertAll().flatMap((r) => r.leaves);
  for (const l of leaves) {
    for (const a of l.args) {
      assert.ok(!a.includes('Tools/PlanChecks/assert-package-graph.mjs'),
        `leaf ${l.leafID} retained the absent G5-R checker path in arg ${a}`);
    }
    for (const p of (l.declaredPaths || [])) {
      assert.ok(!p.includes('Tools/PlanChecks/assert-package-graph.mjs'),
        `leaf ${l.leafID} declared the absent G5-R checker path ${p}`);
    }
  }
});

// ---------------------------------------------------------------------------
// Red expected-result invariants
// ---------------------------------------------------------------------------

test('every Red record carries a closed failure class and a non-empty expected marker', () => {
  const records = convertAll().filter((r) => r.stage === 'red');
  assert.equal(records.length, 200);
  const valid = ['behavioral', 'structural', 'package-graph', 'provenance', 'qualification'];
  for (const r of records) {
    assert.ok(valid.includes(r.failureClass), `${r.commandID} failureClass ${r.failureClass} not closed`);
    assert.ok(Array.isArray(r.expectedOutputIncludes) && r.expectedOutputIncludes.length > 0,
      `${r.commandID} must retain its G5 required output marker`);
  }
});

test('every Swift-test Red uses failure class behavioral', () => {
  const records = convertAll().filter((r) => r.stage === 'red');
  for (const r of records) {
    const forms = r.leaves.map((l) => l.form);
    if (forms.includes('swift-test') && !forms.includes('node-test') && !forms.includes('node-script') && !forms.includes('swift-package')) {
      assert.equal(r.failureClass, 'behavioral', `${r.commandID} swift-test Red must be behavioral`);
    }
  }
});

test('P00-T001 Red is a pipeline with pipefail and failure class package-graph', () => {
  const records = convertAll();
  const p00 = records.find((r) => r.commandID === 'P00-T001.RED.001');
  assert.equal(p00.kind, 'pipeline');
  assert.equal(p00.pipefail, true);
  assert.equal(p00.failureClass, 'package-graph');
  assert.deepEqual(p00.expectedOutputIncludes, ['PLAN_PACKAGE_GRAPH_MISSING']);
  assert.equal(p00.expectedExit, 1);
});

test('the 5 all-success records are all Green swift-test pairs preserving source order', () => {
  const records = convertAll().filter((r) => r.kind === 'all-success');
  assert.equal(records.length, 5);
  for (const r of records) {
    assert.equal(r.stage, 'green');
    assert.equal(r.leaves.length, 2);
    for (const l of r.leaves) assert.equal(l.form, 'swift-test');
    // leafIDs must be strictly ascending PROC.001 then PROC.002
    assert.ok(r.leaves[0].leafID < r.leaves[1].leafID);
  }
});

// ---------------------------------------------------------------------------
// Node control: file-before-option selects all, option-before-file selects one
// ---------------------------------------------------------------------------

test('Node control: file-before-option selects all cases while option-before-file selects one', () => {
  const tmp = path.join(os.tmpdir(), `monacode-node-ctrl-${process.pid}-${Date.now()}`);
  const file = path.join(tmp, 'MultiCase.mjs');
  mkdirSync(tmp, { recursive: true });
  writeFileSync(file,
    "import { test } from 'node:test';\n" +
    "test('tampered-case-one', () => {});\n" +
    "test('tampered-case-two', () => {});\n" +
    "test('other-case-three', () => {});\n" +
    "import { readFileSync } from 'node:fs';\nreadFileSync;\n");
  try {
    // Strip the parent test-runner context so the child `node --test` actually runs
    // (NODE_TEST_CONTEXT / NODE_TEST_WORKER_ID would otherwise make it skip as a nested run).
    const cleanEnv = {};
    for (const [k, v] of Object.entries(process.env)) {
      if (!k.startsWith('NODE_TEST') && k !== 'NODE_OPTIONS') cleanEnv[k] = v;
    }
    const spawn = (args) => cp.spawnSync(NODE_BIN, args, { encoding: 'utf8', env: cleanEnv });
    // Form A (file-before-option, the inherited G5-R form): pattern is IGNORED -> runs all 3.
    const a = spawn(['--test', file, '--test-name-pattern', 'tampered']);
    // Form B (option-before-file, the normalized G6-R form): pattern is APPLIED -> runs 2.
    const b = spawn(['--test', '--test-name-pattern', 'tampered', file]);
    const passOf = (res) => {
      const out = (res.stdout || '') + (res.stderr || '');
      const m = out.match(/pass[^\d]*(\d+)/);
      return m ? parseInt(m[1], 10) : -1;
    };
    const passA = passOf(a);
    const passB = passOf(b);
    assert.equal(passA, 3, `file-before-option must select ALL cases (pattern ignored); got ${passA}\n${(a.stdout||'')+(a.stderr||'')}`);
    assert.equal(passB, 2, `option-before-file must select only the matching cases; got ${passB}\n${(b.stdout||'')+(b.stderr||'')}`);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// auditCommandSpec rejection of forbidden shell and malformed structure
// ---------------------------------------------------------------------------

const baseLeaf = {
  leafID: 'P99-T001.RED.001.PROC.001',
  executable: XCRUN_BIN,
  toolchainRow: 'xcrun-swift-6.0-macos-26',
  args: ['swift', 'test', '--filter', 'Foo', '--scratch-path', '/tmp/planctl/P99-T001.RED.001'],
  timeoutMs: 600000,
  form: 'swift-test',
  stage: 'red',
  optionReorder: false,
  declaredPaths: [],
};

function baseCommand(overrides = {}) {
  return {
    commandID: 'P99-T001.RED.001',
    kind: 'process',
    networkMode: 'forbidden',
    timeoutMs: 600000,
    stage: 'red',
    expectedExit: 1,
    expectedOutputIncludes: ['MARKER_X'],
    failureClass: 'behavioral',
    leaves: [structuredClone(baseLeaf)],
    ...overrides,
  };
}

function auditHas(command) {
  return auditCommandSpec(command).length > 0;
}

test('audit accepts a well-formed command (zero findings)', () => {
  assert.equal(auditCommandSpec(baseCommand()).length, 0);
});

test('audit rejects mixed composition (process kind with two leaves)', () => {
  const c = baseCommand({
    leaves: [structuredClone(baseLeaf), { ...structuredClone(baseLeaf), leafID: 'P99-T001.RED.001.PROC.002' }],
  });
  assert.ok(auditHas(c));
});

test('audit rejects nested composition (a leaf arg carries && or |)', () => {
  const c = baseCommand({ leaves: [{ ...structuredClone(baseLeaf), args: ['swift', 'test', '&&', 'swift', 'test'] }] });
  assert.ok(auditHas(c));
});

test('audit rejects an all-success record with fewer than two leaves', () => {
  const c = baseCommand({ kind: 'all-success', leaves: [structuredClone(baseLeaf)] });
  assert.ok(auditHas(c));
});

test('audit rejects command substitution ($(...) and backticks)', () => {
  assert.ok(auditHas(baseCommand({ leaves: [{ ...structuredClone(baseLeaf), args: ['swift', 'test', '$(rm -rf /)'] }] })));
  assert.ok(auditHas(baseCommand({ leaves: [{ ...structuredClone(baseLeaf), args: ['swift', 'test', '`whoami`'] }] })));
});

test('audit rejects implicit globbing (unquoted *)', () => {
  assert.ok(auditHas(baseCommand({ leaves: [{ ...structuredClone(baseLeaf), args: ['swift', 'test', '*'] }] })));
});

test('audit rejects interactive flags (-i, --interactive)', () => {
  assert.ok(auditHas(baseCommand({ leaves: [{ ...structuredClone(baseLeaf), args: ['swift', 'test', '-i'] }] })));
  assert.ok(auditHas(baseCommand({ leaves: [{ ...structuredClone(baseLeaf), args: ['swift', 'test', '--interactive'] }] })));
});

test('audit rejects an absent timeout', () => {
  const c = baseCommand({ timeoutMs: undefined });
  delete c.timeoutMs;
  assert.ok(auditHas(c));
  assert.ok(auditHas(baseCommand({ timeoutMs: 0 })));
});

test('audit rejects any verification-command network mode other than forbidden', () => {
  assert.ok(auditHas(baseCommand({ networkMode: 'allowed' })));
  assert.ok(auditHas(baseCommand({ networkMode: 'offline' })));
});

test('audit rejects a pipeline without pipefail: true', () => {
  const l2 = { ...structuredClone(baseLeaf), leafID: 'P99-T001.RED.001.PROC.002' };
  const c = baseCommand({ kind: 'pipeline', pipefail: false, leaves: [structuredClone(baseLeaf), l2] });
  assert.ok(auditHas(c));
  const c2 = baseCommand({ kind: 'pipeline', leaves: [structuredClone(baseLeaf), l2] });
  delete c2.pipefail;
  assert.ok(auditHas(c2));
});

test('audit rejects a changed all-success short-circuit order (non-ascending leafIDs)', () => {
  const l1 = { ...structuredClone(baseLeaf), leafID: 'P99-T001.RED.001.PROC.002' };
  const l2 = { ...structuredClone(baseLeaf), leafID: 'P99-T001.RED.001.PROC.001' };
  const c = baseCommand({ kind: 'all-success', stage: 'green', failureClass: undefined, expectedExit: 0, expectedOutputIncludes: ['OK'], leaves: [l1, l2] });
  assert.ok(auditHas(c));
});

test('audit rejects an unnormalized Node-test option (file-before-option)', () => {
  // inherited (wrong) form: --test FILE --test-name-pattern VALUE
  const c = baseCommand({
    leaves: [{
      ...structuredClone(baseLeaf),
      executable: NODE_BIN,
      toolchainRow: 'node-26.7.0',
      args: ['--test', 'Tests/Foo.mjs', '--test-name-pattern', 'tampered'],
      form: 'node-test',
      optionReorder: false,
    }],
  });
  assert.ok(auditHas(c));
});

test('audit accepts a normalized Node-test option (option-before-file)', () => {
  const c = baseCommand({
    leaves: [{
      ...structuredClone(baseLeaf),
      executable: NODE_BIN,
      toolchainRow: 'node-26.7.0',
      args: ['--test', '--test-name-pattern', 'tampered', 'Tests/Foo.mjs'],
      form: 'node-test',
      optionReorder: true,
    }],
  });
  assert.equal(auditCommandSpec(c).length, 0);
});

test('audit rejects a Red failure class outside the closed set', () => {
  assert.ok(auditHas(baseCommand({ failureClass: 'compile' })));
  assert.ok(auditHas(baseCommand({ failureClass: 'runtime' })));
  assert.ok(auditHas(baseCommand({ failureClass: 'unknown' })));
});

test('audit rejects a Red record whose expected output marker is absent', () => {
  assert.ok(auditHas(baseCommand({ expectedOutputIncludes: [] })));
  assert.ok(auditHas(baseCommand({ expectedOutputIncludes: undefined })));
});

test('audit rejects an executable that is not an absolute pinned path', () => {
  assert.ok(auditHas(baseCommand({ leaves: [{ ...structuredClone(baseLeaf), executable: '/usr/bin/swift' }] })));
  assert.ok(auditHas(baseCommand({ leaves: [{ ...structuredClone(baseLeaf), executable: 'node' }] })));
});

// ---------------------------------------------------------------------------
// P00-T001 Red control: PLAN_PACKAGE_GRAPH_MISSING without MODULE_NOT_FOUND
// ---------------------------------------------------------------------------

test('P00-T001 Red checker leaf points at the G6-R runtime checker, not the absent G5-R path', () => {
  const p00 = convertAll().find((r) => r.commandID === 'P00-T001.RED.001');
  const checkerLeaf = p00.leaves.find((l) => l.form === 'node-script');
  assert.ok(checkerLeaf, 'P00-T001 pipeline must have a node-script checker leaf');
  const checkerPath = checkerLeaf.args[0];
  assert.ok(checkerPath.endsWith('g6-r/implementation-plan/runtime/assert-package-graph.mjs'),
    `checker leaf arg must point at the G6-R runtime checker, got ${checkerPath}`);
  assert.ok(!checkerPath.includes('Tools/PlanChecks/'));
});

test('P00-T001 Red control emits PLAN_PACKAGE_GRAPH_MISSING without MODULE_NOT_FOUND', () => {
  const p00 = convertAll().find((r) => r.commandID === 'P00-T001.RED.001');
  const checkerLeaf = p00.leaves.find((l) => l.form === 'node-script');
  const checkerAbs = path.join(REPO_ROOT, checkerLeaf.args[0]);
  const res = cp.spawnSync(NODE_BIN, [checkerAbs], { encoding: 'utf8', input: '' });
  const combined = (res.stdout || '') + (res.stderr || '');
  assert.ok(combined.includes('PLAN_PACKAGE_GRAPH_MISSING'),
    `checker must emit PLAN_PACKAGE_GRAPH_MISSING, got: ${combined}`);
  assert.ok(!combined.includes('MODULE_NOT_FOUND'),
    `checker must not crash with MODULE_NOT_FOUND, got: ${combined}`);
  assert.notEqual(res.status, 0, 'checker must exit non-zero for absent input');
});

// ---------------------------------------------------------------------------
// assertPackageGraph baseline checker
// ---------------------------------------------------------------------------

test('assertPackageGraph emits PLAN_PACKAGE_GRAPH_MISSING for absent input', () => {
  for (const absent of [null, undefined, '', 'not-an-object', 42, []]) {
    const r = assertPackageGraph(absent);
    assert.equal(r.exit, 1);
    assert.ok(r.output.includes('PLAN_PACKAGE_GRAPH_MISSING'), `input ${JSON.stringify(absent)} -> ${r.output}`);
  }
});

test('assertPackageGraph emits the exact Green summary for the required graph', () => {
  const r = assertPackageGraph(MANIFEST.packageGraph);
  assert.equal(r.exit, 0);
  assert.equal(r.output, 'PACKAGE_GRAPH products=3 nonProductTargets=3 fixtureTargets=0');
});

test('assertPackageGraph rejects a graph with the wrong product count', () => {
  const bad = JSON.parse(JSON.stringify(MANIFEST.packageGraph));
  bad.products = bad.products.slice(0, 2);
  const r = assertPackageGraph(bad);
  assert.equal(r.exit, 1);
  assert.ok(r.output.includes('PACKAGE_GRAPH'));
  assert.ok(!r.output.includes('products=3 nonProductTargets=3 fixtureTargets=0'));
});

// ---------------------------------------------------------------------------
// assertPackageGraph: real `swift package dump-package` JSON shape
// ---------------------------------------------------------------------------

// Realistic dump-package output for the required G6-R three-product graph at
// P00-T001 Green time. DifferentialFixtures is a resource inside MonaCodeTests,
// not a target; test targets are excluded from nonProductTargets.
const DUMP_PACKAGE = {
  name: 'MonaCode',
  products: [
    { name: 'MonaCode', type: { library: ['automatic'] }, targets: ['MonaCode'] },
    { name: 'MonaCodeAppKit', type: { library: ['automatic'] }, targets: ['MonaCodeAppKit'] },
    { name: 'MonaCodeSwiftUI', type: { library: ['automatic'] }, targets: ['MonaCodeSwiftUI'] },
  ],
  targets: [
    { name: 'MonaCode', type: 'regular', path: 'Sources/MonaCode', dependencies: [] },
    { name: 'MonaCodeAppKit', type: 'regular', path: 'Sources/MonaCodeAppKit', dependencies: [{ byName: ['MonaCode'] }] },
    { name: 'MonaCodeSwiftUI', type: 'regular', path: 'Sources/MonaCodeSwiftUI', dependencies: [{ byName: ['MonaCode'] }, { byName: ['MonaCodeAppKit'] }] },
    { name: 'sample-macOS-host', type: 'executable', path: 'Sources/MonaCodeSample', dependencies: [{ byName: ['MonaCode'] }, { byName: ['MonaCodeAppKit'] }, { byName: ['MonaCodeSwiftUI'] }] },
    { name: 'conformance-and-failure-injection', type: 'executable', path: 'Tests/ConformanceAndFailureInjection', dependencies: [{ byName: ['MonaCode'] }, { byName: ['MonaCodeAppKit'] }] },
    { name: 'benchmark-harness', type: 'executable', path: 'Tests/BenchmarkHarness', dependencies: [{ byName: ['MonaCode'] }, { byName: ['MonaCodeAppKit'] }] },
    { name: 'MonaCodeTests', type: 'test', path: 'Tests/MonaCodeTests', dependencies: [{ byName: ['MonaCode'] }], resources: [{ path: 'Tests/Fixtures/DifferentialFixtures' }] },
    { name: 'MonaCodeAppKitTests', type: 'test', path: 'Tests/MonaCodeAppKitTests', dependencies: [{ byName: ['MonaCodeAppKit'] }], resources: [] },
  ],
};

test('assertPackageGraph parses dump-package JSON and emits the exact Green summary', () => {
  const r = assertPackageGraph(DUMP_PACKAGE);
  assert.equal(r.exit, 0);
  assert.equal(r.output, 'PACKAGE_GRAPH products=3 nonProductTargets=3 fixtureTargets=0');
});

test('assertPackageGraph excludes test targets from nonProductTargets (dump-package shape)', () => {
  // 3 products, 3 non-product executables, 2 test targets, DifferentialFixtures as a resource.
  const r = assertPackageGraph(DUMP_PACKAGE);
  assert.equal(r.exit, 0, `test targets must not inflate nonProductTargets; got ${r.output}`);
  // If test targets were counted, nonProductTargets would be 5, not 3.
  assert.ok(!r.output.includes('nonProductTargets=5'));
});

test('assertPackageGraph script mode emits Green summary for dump-package JSON on stdin', () => {
  const checkerAbs = path.join(
    REPO_ROOT,
    'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs',
  );
  const res = cp.spawnSync(NODE_BIN, [checkerAbs], {
    encoding: 'utf8',
    input: JSON.stringify(DUMP_PACKAGE),
  });
  const combined = (res.stdout || '') + (res.stderr || '');
  assert.equal(res.status, 0, `Green dump-package must exit 0; got: ${combined}`);
  assert.ok(combined.includes('PACKAGE_GRAPH products=3 nonProductTargets=3 fixtureTargets=0'),
    `Green summary must appear on stdout; got: ${combined}`);
  assert.ok(!combined.includes('MODULE_NOT_FOUND'));
});

test('assertPackageGraph rejects a dump-package graph with the wrong product count', () => {
  const bad = JSON.parse(JSON.stringify(DUMP_PACKAGE));
  bad.products = bad.products.slice(0, 2);
  const r = assertPackageGraph(bad);
  assert.equal(r.exit, 1);
  assert.ok(r.output.includes('PACKAGE_GRAPH'));
  assert.ok(!r.output.includes('products=3 nonProductTargets=3 fixtureTargets=0'));
});

test('assertPackageGraph rejects a dump-package graph that declares a fixture target', () => {
  const bad = JSON.parse(JSON.stringify(DUMP_PACKAGE));
  // Wrongly declare DifferentialFixtures as a target (not a resource).
  bad.targets.push({ name: 'DifferentialFixtures', type: 'regular', path: 'Tests/Fixtures/DifferentialFixtures', dependencies: [] });
  const r = assertPackageGraph(bad);
  assert.equal(r.exit, 1);
  assert.ok(r.output.includes('fixtureTargets=1'), `fixture target must be counted; got ${r.output}`);
});
