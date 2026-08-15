// G6-R interface contract tests (TDD Step 1).
// Asserts the three closed interface-contract kinds (swift-declaration,
// json-schema, command-contract), exact signature hashing per kind, the
// three exact findings (PLAN_INTERFACE_SIGNATURE_MISMATCH, PLAN_INTERFACE_ORDER,
// PLAN_INTERFACE_PRODUCER_DUPLICATE), rejection of symbolic-only / fourth
// kinds (PLAN_INTERFACE_CONTRACT_INCOMPLETE), and that the rendered Swift
// stub package type-checks twice with identical file hashes (determinism).
// Node built-in test runner only.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import * as path from 'node:path';
import * as os from 'node:os';

import {
  buildInterfaceContract,
  auditInterfaceContracts,
  renderInterfaceStubPackage,
  INTERFACE_KINDS,
} from '../lib/interfaces.mjs';
import { canonicalJSONStringify } from '../lib/canonical-json.mjs';

const FIXTURES_DIR = path.join(import.meta.dirname, 'fixtures');

function loadFixture(name) {
  return JSON.parse(readFileSync(path.join(FIXTURES_DIR, name), 'utf8'));
}

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

// ---------------------------------------------------------------------------
// Contract sources for the three closed kinds
// ---------------------------------------------------------------------------

const SWIFT_DECLARATION = [
  'public struct MonaEditorConfiguration: Sendable {',
  '    public var value: Int',
  '    public init(value: Int) { self.value = value }',
  '}',
].join('\n');

const SWIFT_SOURCES = {
  kind: 'swift-declaration',
  declarationText: SWIFT_DECLARATION,
  target: 'MonaEditor',
  visibility: 'public',
  availability: '@available(macOS 12.0, *)',
  actorIsolation: 'none',
  ownership: 'value',
  sendable: 'conforming',
  ordinal: 1,
};

const JSON_SOURCES = {
  kind: 'json-schema',
  schemaPath: '/properties/editor',
  schemaHash: 'c'.repeat(64),
  closedSchemaIdentity: 'monaco-editor-0.56.0/editor-config.json',
  ordinal: 1,
};

const COMMAND_SOURCES = {
  kind: 'command-contract',
  commandRecordHash: 'd'.repeat(64),
  orderedLeafHashes: ['e'.repeat(64), 'f'.repeat(64)],
  inputContractHashes: ['1'.repeat(64)],
  outputSchema: 'exit-code:int',
  expectedResultContract: 'exit:0',
  ordinal: 1,
};

// ---------------------------------------------------------------------------
// Closed kind set
// ---------------------------------------------------------------------------

test('INTERFACE_KINDS is exactly the three closed kinds', () => {
  assert.deepEqual([...INTERFACE_KINDS].sort(), [
    'command-contract',
    'json-schema',
    'swift-declaration',
  ]);
});

// ---------------------------------------------------------------------------
// buildInterfaceContract: exact signature hashing per kind
// ---------------------------------------------------------------------------

test('swift-declaration contract carries the exact signature hash', () => {
  const c = buildInterfaceContract({
    task: 'P00-T001',
    interfaceID: 'MonaEditorConfiguration',
    contractSources: SWIFT_SOURCES,
  });
  assert.equal(c.kind, 'swift-declaration');
  assert.equal(c.id, 'MonaEditorConfiguration');
  assert.equal(c.task, 'P00-T001');
  assert.equal(c.ordinal, 1);
  assert.equal(c.declarationText, SWIFT_DECLARATION);
  assert.equal(c.target, 'MonaEditor');
  assert.equal(c.visibility, 'public');
  assert.equal(c.availability, '@available(macOS 12.0, *)');
  assert.equal(c.actorIsolation, 'none');
  assert.equal(c.ownership, 'value');
  assert.equal(c.sendable, 'conforming');
  const expected = sha256(canonicalJSONStringify({
    kind: 'swift-declaration',
    declarationText: SWIFT_DECLARATION,
    target: 'MonaEditor',
    visibility: 'public',
    availability: '@available(macOS 12.0, *)',
    actorIsolation: 'none',
    ownership: 'value',
    sendable: 'conforming',
  }));
  assert.equal(c.signatureSha256, expected);
});

test('json-schema contract carries the exact signature hash', () => {
  const c = buildInterfaceContract({
    task: 'P00-T001',
    interfaceID: 'MonaEditorConfigSchema',
    contractSources: JSON_SOURCES,
  });
  assert.equal(c.kind, 'json-schema');
  assert.equal(c.id, 'MonaEditorConfigSchema');
  assert.equal(c.schemaPath, '/properties/editor');
  assert.equal(c.schemaHash, 'c'.repeat(64));
  assert.equal(c.closedSchemaIdentity, 'monaco-editor-0.56.0/editor-config.json');
  const expected = sha256(canonicalJSONStringify({
    kind: 'json-schema',
    schemaPath: '/properties/editor',
    schemaHash: 'c'.repeat(64),
    closedSchemaIdentity: 'monaco-editor-0.56.0/editor-config.json',
  }));
  assert.equal(c.signatureSha256, expected);
});

test('command-contract carries the exact signature hash', () => {
  const c = buildInterfaceContract({
    task: 'P00-T001',
    interfaceID: 'MonaEditorBuildCommand',
    contractSources: COMMAND_SOURCES,
  });
  assert.equal(c.kind, 'command-contract');
  assert.equal(c.id, 'MonaEditorBuildCommand');
  assert.equal(c.commandRecordHash, 'd'.repeat(64));
  assert.deepEqual(c.orderedLeafHashes, ['e'.repeat(64), 'f'.repeat(64)]);
  assert.deepEqual(c.inputContractHashes, ['1'.repeat(64)]);
  assert.equal(c.outputSchema, 'exit-code:int');
  assert.equal(c.expectedResultContract, 'exit:0');
  const expected = sha256(canonicalJSONStringify({
    kind: 'command-contract',
    commandRecordHash: 'd'.repeat(64),
    orderedLeafHashes: ['e'.repeat(64), 'f'.repeat(64)],
    inputContractHashes: ['1'.repeat(64)],
    outputSchema: 'exit-code:int',
    expectedResultContract: 'exit:0',
  }));
  assert.equal(c.signatureSha256, expected);
});

test('signature hash excludes ordinal so reordering does not change the signature', () => {
  const a = buildInterfaceContract({
    task: 'P00-T001',
    interfaceID: 'MonaEditorConfiguration',
    contractSources: SWIFT_SOURCES,
  });
  const b = buildInterfaceContract({
    task: 'P00-T001',
    interfaceID: 'MonaEditorConfiguration',
    contractSources: { ...SWIFT_SOURCES, ordinal: 99 },
  });
  assert.equal(a.signatureSha256, b.signatureSha256);
  assert.notEqual(a.ordinal, b.ordinal);
});

test('a declaration text drift changes the signature hash', () => {
  const a = buildInterfaceContract({
    task: 'P00-T001',
    interfaceID: 'MonaEditorConfiguration',
    contractSources: SWIFT_SOURCES,
  });
  const b = buildInterfaceContract({
    task: 'P00-T001',
    interfaceID: 'MonaEditorConfiguration',
    contractSources: { ...SWIFT_SOURCES, declarationText: SWIFT_DECLARATION + '\n' },
  });
  assert.notEqual(a.signatureSha256, b.signatureSha256);
});

// ---------------------------------------------------------------------------
// PLAN_INTERFACE_CONTRACT_INCOMPLETE — symbolic-only / fourth kind
// ---------------------------------------------------------------------------

test('buildInterfaceContract rejects a fourth kind', () => {
  assert.throws(
    () => buildInterfaceContract({
      task: 'P00-T001', interfaceID: 'X', contractSources: { kind: 'graphql-schema' },
    }),
    /PLAN_INTERFACE_CONTRACT_INCOMPLETE/,
  );
});

test('buildInterfaceContract rejects a symbolic-only row', () => {
  assert.throws(
    () => buildInterfaceContract({
      task: 'P00-T001', interfaceID: 'X', contractSources: { kind: 'symbolic' },
    }),
    /PLAN_INTERFACE_CONTRACT_INCOMPLETE/,
  );
});

test('buildInterfaceContract rejects missing required swift-declaration fields', () => {
  assert.throws(
    () => buildInterfaceContract({
      task: 'P00-T001', interfaceID: 'X',
      contractSources: { kind: 'swift-declaration', declarationText: 'public struct X {}' },
    }),
    /PLAN_INTERFACE_CONTRACT_INCOMPLETE/,
  );
});

test('auditInterfaceContracts flags an incomplete contract kind with PLAN_INTERFACE_CONTRACT_INCOMPLETE', () => {
  const plan = { planID: 'g6r-incomplete', tasks: [] };
  const contracts = [{ id: 'X', kind: 'graphql-schema', task: 'P00-T001', signatureSha256: '0'.repeat(64) }];
  const got = auditInterfaceContracts(plan, contracts);
  assert.equal(got.length, 1);
  assert.equal(got[0].id, 'PLAN_INTERFACE_CONTRACT_INCOMPLETE');
});

// ---------------------------------------------------------------------------
// Fixture-driven findings (one exact finding each)
// ---------------------------------------------------------------------------

test('interface-signature-drift yields exactly PLAN_INTERFACE_SIGNATURE_MISMATCH', () => {
  const fx = loadFixture('interface-signature-drift.json');
  const got = auditInterfaceContracts(fx.plan, fx.contracts);
  assert.deepEqual(got, [fx.expected]);
});

test('interface-order-drift yields exactly PLAN_INTERFACE_ORDER', () => {
  const fx = loadFixture('interface-order-drift.json');
  const got = auditInterfaceContracts(fx.plan, fx.contracts);
  assert.deepEqual(got, [fx.expected]);
});

test('interface-duplicate-producer yields exactly PLAN_INTERFACE_PRODUCER_DUPLICATE', () => {
  const fx = loadFixture('interface-duplicate-producer.json');
  const got = auditInterfaceContracts(fx.plan, fx.contracts);
  assert.deepEqual(got, [fx.expected]);
});

// ---------------------------------------------------------------------------
// Positive control — a clean plan produces no findings
// ---------------------------------------------------------------------------

test('a clean plan with matching signatures, correct order, and unique producers produces no findings', () => {
  const contract = buildInterfaceContract({
    task: 'P00-T001', interfaceID: 'MonaEditorConfiguration', contractSources: SWIFT_SOURCES,
  });
  const plan = {
    planID: 'g6r-clean',
    tasks: [{
      taskID: 'P00-T001',
      interfaces: {
        consumes: [{ id: 'MonaEditorConfiguration', signatureSha256: contract.signatureSha256 }],
        produces: [{ id: 'MonaEditorConfiguration', ordinal: 1 }],
      },
    }],
  };
  assert.deepEqual(auditInterfaceContracts(plan, [contract]), []);
});

// ---------------------------------------------------------------------------
// Swift stub package: type-check + double-render determinism
// ---------------------------------------------------------------------------

test('renderInterfaceStubPackage type-checks twice with identical file hashes', () => {
  const contract = buildInterfaceContract({
    task: 'P00-T001', interfaceID: 'MonaEditorConfiguration', contractSources: SWIFT_SOURCES,
  });
  const dirA = mkdtempSync(path.join(os.tmpdir(), 'g6r-iface-a-'));
  const dirB = mkdtempSync(path.join(os.tmpdir(), 'g6r-iface-b-'));
  try {
    const filesA = renderInterfaceStubPackage([contract], dirA);
    const filesB = renderInterfaceStubPackage([contract], dirB);

    // Same file count and relative paths.
    assert.equal(filesA.length, filesB.length);
    const rel = (f, root) => path.relative(root, f);
    for (let i = 0; i < filesA.length; i++) {
      assert.equal(rel(filesA[i], dirA), rel(filesB[i], dirB));
    }

    // Identical file contents (determinism proof) — hash every file.
    const hashesA = filesA.map((f) => sha256(readFileSync(f)));
    const hashesB = filesB.map((f) => sha256(readFileSync(f)));
    assert.deepEqual(hashesA, hashesB);

    // Type-check the first render (source files only; Package.swift is a
    // SwiftPM manifest that requires the PackageDescription module).
    const swiftA = filesA.filter((f) => f.includes(`${path.sep}Sources${path.sep}`) && f.endsWith('.swift'));
    assert.ok(swiftA.length > 0, 'no source .swift files generated');
    const resA = spawnSync('xcrun', ['swiftc', '-typecheck', '-parse-as-library', '-module-name', 'MonaInterfaces', ...swiftA], { encoding: 'utf8' });
    assert.equal(resA.status, 0,
      `typecheck A failed (exit ${resA.status}):\nstdout: ${resA.stdout}\nstderr: ${resA.stderr}`);

    // Type-check the second render.
    const swiftB = filesB.filter((f) => f.includes(`${path.sep}Sources${path.sep}`) && f.endsWith('.swift'));
    const resB = spawnSync('xcrun', ['swiftc', '-typecheck', '-parse-as-library', '-module-name', 'MonaInterfaces', ...swiftB], { encoding: 'utf8' });
    assert.equal(resB.status, 0,
      `typecheck B failed (exit ${resB.status}):\nstdout: ${resB.stdout}\nstderr: ${resB.stderr}`);
  } finally {
    rmSync(dirA, { recursive: true, force: true });
    rmSync(dirB, { recursive: true, force: true });
  }
});

test('renderInterfaceStubPackage emits a Package.swift and one Sources file', () => {
  const contract = buildInterfaceContract({
    task: 'P00-T001', interfaceID: 'MonaEditorConfiguration', contractSources: SWIFT_SOURCES,
  });
  const dir = mkdtempSync(path.join(os.tmpdir(), 'g6r-iface-c-'));
  try {
    const files = renderInterfaceStubPackage([contract], dir);
    const rels = files.map((f) => path.relative(dir, f)).sort();
    assert.deepEqual(rels, ['Package.swift', 'Sources/MonaInterfaces/MonaInterfaces.swift']);
    const pkg = readFileSync(path.join(dir, 'Package.swift'), 'utf8');
    assert.ok(pkg.includes('name: "MonaInterfaces"'));
    const src = readFileSync(path.join(dir, 'Sources/MonaInterfaces/MonaInterfaces.swift'), 'utf8');
    assert.ok(src.includes('public struct MonaEditorConfiguration: Sendable'));
    assert.ok(src.includes('@available(macOS 12.0, *)'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
