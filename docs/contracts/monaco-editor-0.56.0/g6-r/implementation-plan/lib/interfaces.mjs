// G6-R interface contracts.
// Defines the three closed interface-contract kinds (swift-declaration,
// json-schema, command-contract) and renders compile-only Swift stub packages
// that type-check against the pinned Swift compiler (xcrun swiftc -typecheck).
//
// buildInterfaceContract stamps each produced interface with an exact
// signatureSha256 derived from the canonical JSON of its kind-specific fields.
// auditInterfaceContracts verifies consumed signatures, producer order, and
// producer uniqueness against a plan. renderInterfaceStubPackage emits a
// deterministic SwiftPM package that type-checks without compilation.

import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import * as path from 'node:path';

import { makeFinding, sortFindings } from './findings.mjs';
import { canonicalJSONStringify } from './canonical-json.mjs';

// ---------------------------------------------------------------------------
// Closed interface-kind set
// ---------------------------------------------------------------------------

export const INTERFACE_KINDS = new Set([
  'swift-declaration',
  'json-schema',
  'command-contract',
]);

/**
 * Finding IDs emitted by this module. These are NOT in the FINDING_IDS list
 * from lib/findings.mjs (Task 3); sortFindings places unknown IDs after all
 * declared IDs, preserving insertion order among themselves (stable sort).
 */
export const INTERFACE_FINDING_IDS = [
  'PLAN_INTERFACE_SIGNATURE_MISMATCH',
  'PLAN_INTERFACE_ORDER',
  'PLAN_INTERFACE_PRODUCER_DUPLICATE',
  'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
];

// Required kind-specific fields (excludes id, task, ordinal which are common).
const REQUIRED_FIELDS = {
  'swift-declaration': [
    'declarationText', 'target', 'visibility', 'availability',
    'actorIsolation', 'ownership', 'sendable',
  ],
  'json-schema': ['schemaPath', 'schemaHash', 'closedSchemaIdentity'],
  'command-contract': [
    'commandRecordHash', 'orderedLeafHashes', 'inputContractHashes',
    'outputSchema', 'expectedResultContract',
  ],
};

const isObj = (v) => v !== null && typeof v === 'object';
const isNonEmptyStr = (v) => typeof v === 'string' && v.length > 0;

function sha256hex(text) {
  return createHash('sha256').update(text).digest('hex');
}

/**
 * Build the signature record for a kind from contractSources. Includes `kind`
 * and exactly the required fields — never `id`, `task`, or `ordinal` (those are
 * not part of the interface signature). Canonical JSON of this record is hashed.
 */
function signatureRecord(kind, sources) {
  const rec = { kind };
  for (const f of REQUIRED_FIELDS[kind]) rec[f] = sources[f];
  return rec;
}

// ---------------------------------------------------------------------------
// buildInterfaceContract
// ---------------------------------------------------------------------------

/**
 * Construct one InterfaceContract from contract sources.
 *
 * @param {{task:string, interfaceID:string, contractSources:object}} input
 * @returns {{id:string, kind:string, task:string, signatureSha256:string, ordinal?:number, [k:string]:unknown}}
 * @throws {Error} PLAN_INTERFACE_CONTRACT_INCOMPLETE when the kind is not one
 *   of the three closed kinds (symbolic-only or a fourth kind) or when a
 *   required kind-specific field is missing/invalid.
 */
export function buildInterfaceContract({ task, interfaceID, contractSources }) {
  const sources = contractSources ?? {};
  const kind = sources.kind;

  if (!INTERFACE_KINDS.has(kind)) {
    throw new Error(
      `PLAN_INTERFACE_CONTRACT_INCOMPLETE ${interfaceID}: kind "${String(kind)}" is not one of ${[...INTERFACE_KINDS].join('|')}`,
    );
  }

  const required = REQUIRED_FIELDS[kind];
  const missing = required.filter((f) => sources[f] === undefined || sources[f] === null);
  if (missing.length > 0) {
    throw new Error(
      `PLAN_INTERFACE_CONTRACT_INCOMPLETE ${interfaceID}: missing required ${kind} fields: ${missing.join(', ')}`,
    );
  }

  // Validate array-typed command-contract fields.
  if (kind === 'command-contract') {
    if (!Array.isArray(sources.orderedLeafHashes) ||
        !sources.orderedLeafHashes.every(isNonEmptyStr)) {
      throw new Error(
        `PLAN_INTERFACE_CONTRACT_INCOMPLETE ${interfaceID}: orderedLeafHashes must be a non-empty string array`,
      );
    }
    if (!Array.isArray(sources.inputContractHashes) ||
        !sources.inputContractHashes.every(isNonEmptyStr)) {
      throw new Error(
        `PLAN_INTERFACE_CONTRACT_INCOMPLETE ${interfaceID}: inputContractHashes must be a string array`,
      );
    }
  }

  const signatureSha256 = sha256hex(canonicalJSONStringify(signatureRecord(kind, sources)));

  const contract = {
    id: interfaceID,
    kind,
    task,
    signatureSha256,
  };
  for (const f of required) contract[f] = sources[f];
  if (typeof sources.ordinal === 'number') contract.ordinal = sources.ordinal;
  return contract;
}

// ---------------------------------------------------------------------------
// auditInterfaceContracts
// ---------------------------------------------------------------------------

/**
 * Audit interface contracts against a plan.
 *
 * Emits findings for:
 *  - PLAN_INTERFACE_SIGNATURE_MISMATCH: a consumed interface has no produced
 *    contract or the produced signatureSha256 differs from the consumed one.
 *  - PLAN_INTERFACE_ORDER: a produced interface's ordinal in the contract
 *    differs from the ordinal declared in the plan's produces list.
 *  - PLAN_INTERFACE_PRODUCER_DUPLICATE: an interface is produced by more than
 *    one task.
 *  - PLAN_INTERFACE_CONTRACT_INCOMPLETE: a contract carries a kind outside the
 *    closed set (symbolic-only or a fourth kind).
 *
 * @param {{tasks:Array<{taskID:string, interfaces?:{consumes?:Array<{id:string,signatureSha256:string}>, produces?:Array<{id:string,ordinal:number}>}}>}} plan
 * @param {Array<object>} contracts
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function auditInterfaceContracts(plan, contracts) {
  const rows = Array.isArray(contracts) ? contracts : [];
  const byID = new Map();
  for (const c of rows) {
    if (isObj(c) && typeof c.id === 'string') byID.set(c.id, c);
  }
  const findings = [];

  // 0. Contract completeness — reject symbolic-only / fourth-kind rows.
  for (let i = 0; i < rows.length; i++) {
    const c = rows[i];
    const kind = c && c.kind;
    if (!INTERFACE_KINDS.has(kind)) {
      findings.push(makeFinding({
        id: 'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
        category: 'semantic',
        taskID: null,
        path: `/contracts/${i}`,
        message: `interface "${String(c && c.id)}" kind "${String(kind)}" is not one of ${[...INTERFACE_KINDS].join('|')}`,
      }));
    }
  }

  const tasks = (plan && Array.isArray(plan.tasks)) ? plan.tasks : [];

  // 1. Signature mismatch on consumed interfaces.
  for (let ti = 0; ti < tasks.length; ti++) {
    const task = tasks[ti];
    const consumes = (task.interfaces && task.interfaces.consumes) ? task.interfaces.consumes : [];
    for (let ci = 0; ci < consumes.length; ci++) {
      const input = consumes[ci];
      const contract = byID.get(input.id);
      if (!contract) {
        findings.push(makeFinding({
          id: 'PLAN_INTERFACE_SIGNATURE_MISMATCH',
          category: 'semantic',
          taskID: task.taskID,
          path: `/tasks/${ti}/interfaces/consumes/${ci}`,
          message: `interface "${input.id}" consumed by ${task.taskID} has no produced contract`,
        }));
      } else if (contract.signatureSha256 !== input.signatureSha256) {
        findings.push(makeFinding({
          id: 'PLAN_INTERFACE_SIGNATURE_MISMATCH',
          category: 'semantic',
          taskID: task.taskID,
          path: `/tasks/${ti}/interfaces/consumes/${ci}`,
          message: `interface "${input.id}" produced signatureSha256 ${contract.signatureSha256} != consumed ${input.signatureSha256}`,
        }));
      }
    }
  }

  // 2. Producer order — contract ordinal must match the plan-declared ordinal.
  for (let ti = 0; ti < tasks.length; ti++) {
    const task = tasks[ti];
    const produces = (task.interfaces && task.interfaces.produces) ? task.interfaces.produces : [];
    for (let pi = 0; pi < produces.length; pi++) {
      const entry = produces[pi];
      const contract = byID.get(entry.id);
      if (contract && typeof contract.ordinal === 'number' && contract.ordinal !== entry.ordinal) {
        findings.push(makeFinding({
          id: 'PLAN_INTERFACE_ORDER',
          category: 'semantic',
          taskID: task.taskID,
          path: `/tasks/${ti}/interfaces/produces/${pi}`,
          message: `interface "${entry.id}" produced ordinal ${contract.ordinal} != declared ${entry.ordinal}`,
        }));
      }
    }
  }

  // 3. Duplicate producers — an interface produced by more than one task.
  const producers = new Map(); // id -> string[] of taskIDs
  for (const task of tasks) {
    const produces = (task.interfaces && task.interfaces.produces) ? task.interfaces.produces : [];
    for (const entry of produces) {
      if (!producers.has(entry.id)) producers.set(entry.id, []);
      producers.get(entry.id).push(task.taskID);
    }
  }
  for (const [id, producerTasks] of producers) {
    if (producerTasks.length > 1) {
      findings.push(makeFinding({
        id: 'PLAN_INTERFACE_PRODUCER_DUPLICATE',
        category: 'semantic',
        taskID: null,
        path: `/interfaces/${id}`,
        message: `interface "${id}" has ${producerTasks.length} producers: ${producerTasks.join(', ')}`,
      }));
    }
  }

  return sortFindings(findings);
}

// ---------------------------------------------------------------------------
// renderInterfaceStubPackage
// ---------------------------------------------------------------------------

/**
 * Render a compile-only Swift stub package from swift-declaration contracts.
 *
 * Writes a SwiftPM package (Package.swift + Sources/MonaInterfaces/*.swift)
 * into outputDirectory. The generated sources type-check under
 * `xcrun swiftc -typecheck` but are never compiled into artifacts. Output is
 * deterministic: the same contracts always produce byte-identical files.
 *
 * @param {Array<object>} contracts
 * @param {string} outputDirectory
 * @returns {string[]} Absolute paths of the generated files.
 */
export function renderInterfaceStubPackage(contracts, outputDirectory) {
  const all = Array.isArray(contracts) ? contracts : [];
  const swiftContracts = all
    .filter((c) => c && c.kind === 'swift-declaration')
    .slice()
    .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));

  const sourcesDir = path.join(outputDirectory, 'Sources', 'MonaInterfaces');
  mkdirSync(sourcesDir, { recursive: true });

  const generatedFiles = [];

  // Package.swift
  const pkgLines = [
    '// swift-tools-version: 6.0',
    'import PackageDescription',
    '',
    'let package = Package(',
    '    name: "MonaInterfaces",',
    '    products: [',
    '        .library(name: "MonaInterfaces", targets: ["MonaInterfaces"]),',
    '    ],',
    '    targets: [',
    '        .target(name: "MonaInterfaces", path: "Sources/MonaInterfaces"),',
    '    ]',
    ')',
    '',
  ];
  const pkgPath = path.join(outputDirectory, 'Package.swift');
  writeFileSync(pkgPath, pkgLines.join('\n'));
  generatedFiles.push(pkgPath);

  // Sources/MonaInterfaces/MonaInterfaces.swift
  const srcLines = [
    '// G6-R interface stub package — generated by renderInterfaceStubPackage. Do not edit.',
    `// Produced interface contracts (swift-declaration kind): ${swiftContracts.length}`,
    '',
  ];
  for (const c of swiftContracts) {
    srcLines.push(`// Interface: ${c.id} (swift-declaration, task ${c.task})`);
    srcLines.push(
      `// Target: ${c.target} | Visibility: ${c.visibility} | Sendable: ${c.sendable}`,
    );
    if (isNonEmptyStr(c.availability) && c.availability !== 'none') {
      srcLines.push(c.availability);
    }
    srcLines.push(c.declarationText);
    srcLines.push('');
  }
  const srcPath = path.join(sourcesDir, 'MonaInterfaces.swift');
  writeFileSync(srcPath, srcLines.join('\n'));
  generatedFiles.push(srcPath);

  return generatedFiles;
}
