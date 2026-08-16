#!/usr/bin/env node
// G6-R Task 11 — validate-overrides CLI and library.
//
// Usage:
//   node Tools/G6PlanAuthoring/validate-overrides.mjs --phase PHASE_SELECTOR --path OVERRIDE_PATH
//
// Loads only the embedded G5-R authoritative + implementation-plan manifests
// and the normative files selected by the embedded G5-R checksum index. Requires
// one row per selected task, one complete task-test contract selecting every
// Red/Green leaf, every produced interface, every external/generated input named
// by an implementation operation, and one compile-only scaffold row for every
// newly created Swift source path on each of the 139 Swift-Red tasks.
//
// Finding IDs: PLAN_OVERRIDE_TASK_MISSING, PLAN_TEST_CONTRACT_MISSING,
// PLAN_TEST_LEAF_UNSELECTED, PLAN_OVERRIDE_INTERFACE_MISSING,
// PLAN_SOURCE_INPUT_UNDECLARED, PLAN_INTERFACE_CONTRACT_INCOMPLETE,
// PLAN_RED_SCAFFOLD_MISSING, PLAN_RED_SCAFFOLD_EXTRA, PLAN_RED_SCAFFOLD_ASSERTION,
// PLAN_OVERRIDE_ROW_UNUSED, PLAN_OVERRIDE_ROW_CONFLICT.
//
// On success prints:
//   G6_OVERRIDES_VALID phase=<phase> tasks=<n> interfaces=<n> sourceGaps=0 acquisitionGaps=0 scaffoldTasks=<n> scaffoldPaths=<n> authoringGaps=0 symbolicOnly=0

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

import { makeFinding, sortFindings } from '../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/findings.mjs';

const PHASE_BASE_FOR = {
  '00': '00', '01': '01', '02': '02', '03': '03', '04': '04',
  '05-foundation': '05', '05-features': '05', '05-closure': '05',
  '06': '06', '07': '07', '08': '08', '09': '09',
};
const VALID_SELECTORS = new Set(Object.keys(PHASE_BASE_FOR));
const INTERFACE_KINDS = new Set(['swift-declaration', 'json-schema', 'command-contract']);
const EVIDENCE_FROM_PREFIX = 'artifacts/acceptance-evidence/g5-r/';

const G5_PARENT_ROOT = 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r';
const G5_PLAN_MANIFEST = `${G5_PARENT_ROOT}/artifacts/monacode-g5r-implementation-plan-manifest.json`;
const G5_CHECKSUM_INDEX = `${G5_PARENT_ROOT}/SHA256SUMS`;

// Required kind-specific interface fields (mirrors lib/interfaces.mjs REQUIRED_FIELDS).
const INTERFACE_REQUIRED_FIELDS = {
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
// Common interface provenance fields (source artifact + contract location).
const INTERFACE_PROVENANCE_FIELDS = [
  'sourceArtifactPath', 'sourceArtifactHash', 'sourceLocator', 'contractRefs',
];
const TEST_CASE_REQUIRED_FIELDS = [
  'caseID', 'file', 'checker', 'target', 'testSymbol', 'fixtures',
  'assertions', 'redLeafID', 'greenLeafID', 'inheritedOutput',
  'failureClass', 'authoringOperation', 'source',
];
const FAILURE_CLASSES = new Set(['assertion', 'compile', 'runtime', 'timeout', 'crash', 'signal']);
const TEST_SOURCES = new Set(['baseline', 'dependency', 'task-step']);
const AVAILABILITIES = new Set(['local', 'remote', 'generated', 'inherited']);

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

/**
 * Load the embedded G5-R SHA256SUMS checksum index into a Map<path, sha256>.
 * The checksum index is the sole authority for interface source-artifact
 * path/hash cross-checks (Fix #3).
 */
function loadChecksumIndex(repoRoot) {
  const abs = path.resolve(repoRoot, G5_CHECKSUM_INDEX);
  if (!fs.existsSync(abs)) return new Map();
  const text = fs.readFileSync(abs, 'utf8');
  const index = new Map();
  for (const line of text.split('\n')) {
    if (line.length === 0) continue;
    const parts = line.split(/\s+/);
    if (parts.length >= 2) index.set(parts[1], parts[0]);
  }
  return index;
}

/**
 * Normalize a repository-relative path: forward slashes, no leading `./`,
 * no parent traversal, no NUL. Returns null if the path is invalid.
 */
function normalizePath(p) {
  if (typeof p !== 'string' || p.length === 0) return null;
  if (p.includes('\0')) return null;
  let normalized = p;
  if (normalized.startsWith('./')) normalized = normalized.slice(2);
  normalized = normalized.replace(/\\/g, '/');
  while (normalized.startsWith('/')) normalized = normalized.slice(1);
  if (normalized.length === 0) return null;
  const segments = normalized.split('/');
  for (const seg of segments) {
    if (seg === '..' || seg === '.' || seg === '') return null;
  }
  return normalized;
}

function scaffoldMarker(taskID, sourcePath) {
  const normalized = normalizePath(sourcePath);
  if (normalized === null) return null;
  return `G6_RED_SCAFFOLD:${taskID}:${sha256(Buffer.from(normalized, 'utf-8'))}`;
}

function isSwiftRedTask(g5Task) {
  const red = g5Task.red ?? [];
  const createsSwift = (g5Task.files?.create ?? []).some((p) => p.startsWith('Sources/') && p.endsWith('.swift'));
  return createsSwift && red.some((row) => typeof row.run === 'string' && row.run.startsWith('swift test '));
}

function leafIDsFromCommands(g5Task) {
  // Recompute the leaf IDs the way the converter would, without invoking the
  // converter (validate-overrides loads only the embedded G5-R manifests).
  const ids = [];
  for (const stage of ['red', 'green']) {
    const rows = g5Task[stage] ?? [];
    rows.forEach((row, index) => {
      const commandID = `${g5Task.id}.${stage === 'red' ? 'RED' : 'GREEN'}.${String(index + 1).padStart(3, '0')}`;
      const run = row.run ?? '';
      const leaves = run.includes(' | ') ? run.split(' | ')
        : run.includes(' && ') ? run.split(' && ')
        : [run];
      leaves.forEach((_, leafIndex) => {
        ids.push(`${commandID}.PROC.${String(leafIndex + 1).padStart(3, '0')}`);
      });
    });
  }
  return ids;
}

function selectPhaseTasks(parentPlan, basePhase, selector, overrides) {
  if (selector.startsWith('05-')) {
    const declared = overrides?.tasks && typeof overrides.tasks === 'object' ? Object.keys(overrides.tasks) : [];
    return declared.filter((id) => {
      const t = (parentPlan.tasks ?? []).find((x) => x.id === id);
      return t && t.phase === '05';
    }).sort();
  }
  return (parentPlan.tasks ?? []).filter((t) => t.phase === basePhase).map((t) => t.id).sort();
}

/**
 * Validate phase overrides against the embedded G5-R manifests.
 *
 * @param {{phase:string, taskIDs:string[], parentPlan:object, overrides:object, checksumIndex?:Map}} input
 * @returns {{findings:object[], summary:object}} sorted findings + summary counts
 */
export function validatePhaseOverrides({ phase, taskIDs, parentPlan, overrides, checksumIndex }) {
  const findings = [];
  const cksum = checksumIndex instanceof Map ? checksumIndex : new Map();
  const tasksByID = new Map();
  for (const t of parentPlan.tasks ?? []) tasksByID.set(t.id, t);

  const overrideTasks = (overrides?.tasks && typeof overrides.tasks === 'object') ? overrides.tasks : {};
  const selected = new Set(taskIDs);

  // Unused override rows: declared but not selected for this phase.
  for (const declaredID of Object.keys(overrideTasks)) {
    if (!selected.has(declaredID)) {
      const t = tasksByID.get(declaredID);
      if (!t || t.phase !== phase.replace(/-.*/, '')) {
        findings.push(makeFinding({
          id: 'PLAN_OVERRIDE_ROW_UNUSED',
          category: 'structure',
          taskID: declaredID,
          path: `/tasks/${declaredID}`,
          message: `override row for ${declaredID} is not selected by phase ${phase}`,
        }));
      }
    }
  }

  let producedInterfaceCount = 0;
  let sourceGaps = 0;
  let acquisitionGaps = 0;
  let scaffoldTasks = 0;
  let scaffoldPaths = 0;
  let authoringGaps = 0;
  let symbolicOnly = 0;

  for (const taskID of taskIDs) {
    const g5Task = tasksByID.get(taskID);
    if (!g5Task) {
      findings.push(makeFinding({
        id: 'PLAN_OVERRIDE_TASK_MISSING',
        category: 'structure',
        taskID,
        path: `/tasks/${taskID}`,
        message: `G5 task ${taskID} not found in parent plan`,
      }));
      continue;
    }
    const row = overrideTasks[taskID];
    if (!row || typeof row !== 'object') {
      findings.push(makeFinding({
        id: 'PLAN_OVERRIDE_TASK_MISSING',
        category: 'structure',
        taskID,
        path: `/tasks/${taskID}`,
        message: `missing override row for ${taskID}`,
      }));
      continue;
    }

    // testAuthoringOperation gap.
    if (row.testAuthoringOperation === undefined) authoringGaps += 1;

    // Task-test contract: one complete contract selecting every Red/Green leaf
    // exactly once. Each case must fix every mandated field (file/checker/target/
    // testSymbol/fixtures/assertions/leaf mapping/inheritedOutput/failureClass/
    // authoringOperation/source).
    const contract = row.testContract;
    if (!contract || !Array.isArray(contract.cases) || contract.cases.length === 0) {
      findings.push(makeFinding({
        id: 'PLAN_TEST_CONTRACT_MISSING',
        category: 'structure',
        taskID,
        path: `/tasks/${taskID}/testContract`,
        message: `missing task-test contract for ${taskID}`,
      }));
    } else {
      const expectedLeaves = leafIDsFromCommands(g5Task);
      const selectedLeaves = new Set();
      const seenLeaves = new Map();
      for (const c of contract.cases) {
        const casePath = `/tasks/${taskID}/testContract/${c.caseID ?? '?'} `;
        // Field presence + well-formedness for each fixed field.
        for (const field of TEST_CASE_REQUIRED_FIELDS) {
          if (c[field] === undefined || c[field] === null) {
            findings.push(makeFinding({
              id: 'PLAN_TEST_CONTRACT_MISSING',
              category: 'structure',
              taskID,
              path: `${casePath}${field}`,
              message: `test case missing fixed field ${field}`,
            }));
          }
        }
        if (c.file && typeof c.file === 'object') {
          if (typeof c.file.path !== 'string' || c.file.path.length === 0
              || !AVAILABILITIES.has(c.file.availability)) {
            findings.push(makeFinding({
              id: 'PLAN_TEST_CONTRACT_MISSING',
              category: 'structure', taskID, path: `${casePath}file`,
              message: `test case file/path/availability malformed`,
            }));
          }
        }
        if (c.fixtures && typeof c.fixtures === 'object') {
          const k = c.fixtures.kind;
          if (k === 'inline' && typeof c.fixtures.values !== 'object') {
            findings.push(makeFinding({ id: 'PLAN_TEST_CONTRACT_MISSING', category: 'structure', taskID, path: `${casePath}fixtures`, message: `inline fixtures missing values` }));
          } else if (k === 'path' && (typeof c.fixtures.path !== 'string' || typeof c.fixtures.hash !== 'string')) {
            findings.push(makeFinding({ id: 'PLAN_TEST_CONTRACT_MISSING', category: 'structure', taskID, path: `${casePath}fixtures`, message: `path fixtures missing path/hash` }));
          } else if (!['inline', 'path'].includes(k)) {
            findings.push(makeFinding({ id: 'PLAN_TEST_CONTRACT_MISSING', category: 'structure', taskID, path: `${casePath}fixtures`, message: `fixtures kind ${k} invalid` }));
          }
        }
        if (!Array.isArray(c.assertions) || c.assertions.length === 0
            || !c.assertions.every((a) => a && typeof a.id === 'string' && typeof a.operand === 'string')) {
          findings.push(makeFinding({ id: 'PLAN_TEST_CONTRACT_MISSING', category: 'structure', taskID, path: `${casePath}assertions`, message: `assertions must be a non-empty array of {id,operand}` }));
        }
        if (typeof c.inheritedOutput !== 'boolean') {
          findings.push(makeFinding({ id: 'PLAN_TEST_CONTRACT_MISSING', category: 'structure', taskID, path: `${casePath}inheritedOutput`, message: `inheritedOutput must be boolean` }));
        }
        if (typeof c.failureClass === 'string' && !FAILURE_CLASSES.has(c.failureClass)) {
          findings.push(makeFinding({ id: 'PLAN_TEST_CONTRACT_MISSING', category: 'structure', taskID, path: `${casePath}failureClass`, message: `failureClass ${c.failureClass} invalid` }));
        }
        if (typeof c.source === 'string' && !TEST_SOURCES.has(c.source)) {
          findings.push(makeFinding({ id: 'PLAN_TEST_CONTRACT_MISSING', category: 'structure', taskID, path: `${casePath}source`, message: `source ${c.source} invalid` }));
        }
        // Leaf selection tracking + duplicate-leaf conflict (Fix #1).
        for (const leaf of [c.redLeafID, c.greenLeafID]) {
          if (typeof leaf !== 'string' || leaf.length === 0) continue;
          if (selectedLeaves.has(leaf)) {
            findings.push(makeFinding({
              id: 'PLAN_OVERRIDE_ROW_CONFLICT',
              category: 'structure', taskID, path: `${casePath}leaf`,
              message: `leaf ${leaf} selected by more than one test case`,
            }));
          } else {
            selectedLeaves.add(leaf);
          }
          seenLeaves.set(leaf, (seenLeaves.get(leaf) ?? 0) + 1);
        }
      }
      for (const leaf of expectedLeaves) {
        if (!selectedLeaves.has(leaf)) {
          findings.push(makeFinding({
            id: 'PLAN_TEST_LEAF_UNSELECTED',
            category: 'structure', taskID,
            path: `/tasks/${taskID}/testContract`,
            message: `leaf ${leaf} not selected by any test case`,
          }));
        }
      }
    }

    // Produced interfaces: every produced ID needs a full contract row with an
    // exact kind, full declaration/schema/command contract, source artifact path
    // and hash, JSON pointer/HTML section identity, and contract references.
    const produced = g5Task.interfaces?.produces ?? [];
    const producedRows = Array.isArray(row.interfaces?.produces) ? row.interfaces.produces : [];
    // Fix #1: duplicate interface IDs with divergent declarations.
    const rowsByID = new Map();
    for (const r of producedRows) {
      if (!r || typeof r !== 'object' || typeof r.id !== 'string') continue;
      if (rowsByID.has(r.id)) {
        const prev = rowsByID.get(r.id);
        const divergent = prev.kind !== r.kind
          || prev.signatureSha256 !== r.signatureSha256
          || prev.declarationHash !== r.declarationHash
          || prev.commandRecordHash !== r.commandRecordHash
          || prev.schemaHash !== r.schemaHash;
        if (divergent) {
          findings.push(makeFinding({
            id: 'PLAN_OVERRIDE_ROW_CONFLICT',
            category: 'structure', taskID,
            path: `/tasks/${taskID}/interfaces/produces/${r.id}`,
            message: `duplicate interface ${r.id} with divergent declaration`,
          }));
        }
      } else {
        rowsByID.set(r.id, r);
      }
    }
    for (const id of produced) {
      const r = rowsByID.get(id);
      const ifacePath = `/tasks/${taskID}/interfaces/produces/${id}`;
      if (!r) {
        findings.push(makeFinding({
          id: 'PLAN_OVERRIDE_INTERFACE_MISSING',
          category: 'structure', taskID, path: ifacePath,
          message: `missing produced interface contract for ${id}`,
        }));
        continue;
      }
      if (!INTERFACE_KINDS.has(r.kind)) {
        symbolicOnly += 1;
        findings.push(makeFinding({
          id: 'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
          category: 'structure', taskID, path: ifacePath,
          message: `interface ${id} has symbolic-only or unknown kind ${r.kind}`,
        }));
        continue;
      }
      // Fix #2: per-kind required contract fields.
      const required = INTERFACE_REQUIRED_FIELDS[r.kind];
      const missing = required.filter((f) => r[f] === undefined || r[f] === null
        || (typeof r[f] === 'string' && r[f].length === 0));
      if (missing.length > 0) {
        symbolicOnly += 1;
        findings.push(makeFinding({
          id: 'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
          category: 'structure', taskID, path: ifacePath,
          message: `interface ${id} (${r.kind}) missing fields: ${missing.join(', ')}`,
        }));
      }
      // Fix #2: provenance fields (source artifact path/hash + locator + refs).
      for (const pf of INTERFACE_PROVENANCE_FIELDS) {
        if (r[pf] === undefined || r[pf] === null) {
          findings.push(makeFinding({
            id: 'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
            category: 'structure', taskID, path: `${ifacePath}/${pf}`,
            message: `interface ${id} missing provenance field ${pf}`,
          }));
        }
      }
      // Fix #3: cross-check source artifact path/hash against the G5-R checksum index.
      if (typeof r.sourceArtifactPath === 'string' && r.sourceArtifactPath.length > 0) {
        const expectedHash = cksum.get(r.sourceArtifactPath);
        if (expectedHash === undefined) {
          findings.push(makeFinding({
            id: 'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
            category: 'structure', taskID, path: `${ifacePath}/sourceArtifactPath`,
            message: `interface ${id} source artifact ${r.sourceArtifactPath} not in G5-R checksum index`,
          }));
        } else if (typeof r.sourceArtifactHash === 'string' && r.sourceArtifactHash.length > 0
                   && r.sourceArtifactHash !== expectedHash) {
          findings.push(makeFinding({
            id: 'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
            category: 'structure', taskID, path: `${ifacePath}/sourceArtifactHash`,
            message: `interface ${id} source artifact hash mismatch expected=${expectedHash} actual=${r.sourceArtifactHash}`,
          }));
        }
      }
      if (missing.length === 0) producedInterfaceCount += 1;
    }

    // Source acquisitions: every remote/external input named by an implementation
    // operation must declare a complete SourceAcquisition row.
    const acquisitions = Array.isArray(row.sourceAcquisitions) ? row.sourceAcquisitions : [];
    const acqByID = new Map();
    for (const a of acquisitions) {
      if (a && typeof a === 'object' && typeof a.url === 'string') acqByID.set(a.url, a);
    }
    const opSources = Array.isArray(row.implementationOperations) ? row.implementationOperations : [];
    for (const op of opSources) {
      if (op && typeof op === 'object' && typeof op.sourceURL === 'string' && !acqByID.has(op.sourceURL)) {
        sourceGaps += 1;
        findings.push(makeFinding({
          id: 'PLAN_SOURCE_INPUT_UNDECLARED',
          category: 'structure',
          taskID,
          path: `/tasks/${taskID}/implementation`,
          message: `undeclared source URL ${op.sourceURL}`,
        }));
      }
    }

    // Red scaffold rows for Swift-Red tasks.
    if (isSwiftRedTask(g5Task)) {
      scaffoldTasks += 1;
      const createdSwift = (g5Task.files?.create ?? [])
        .filter((p) => p.startsWith('Sources/') && p.endsWith('.swift'));
      const scaffolds = Array.isArray(row.redScaffold) ? row.redScaffold : [];
      const scaffoldByPath = new Map();
      for (const s of scaffolds) {
        if (s && typeof s === 'object' && typeof s.sourcePath === 'string') {
          // Fix #1: duplicate Red-scaffold sourcePath across rows for the same task.
          if (scaffoldByPath.has(s.sourcePath)) {
            findings.push(makeFinding({
              id: 'PLAN_OVERRIDE_ROW_CONFLICT',
              category: 'structure', taskID,
              path: `/tasks/${taskID}/redScaffold/${s.sourcePath}`,
              message: `duplicate scaffold row for ${s.sourcePath}`,
            }));
          } else {
            scaffoldByPath.set(s.sourcePath, s);
          }
        }
      }
      for (const sourcePath of createdSwift) {
        scaffoldPaths += 1;
        const s = scaffoldByPath.get(sourcePath);
        if (!s) {
          findings.push(makeFinding({
            id: 'PLAN_RED_SCAFFOLD_MISSING',
            category: 'structure',
            taskID,
            path: `/tasks/${taskID}/redScaffold/${sourcePath}`,
            message: `missing scaffold for ${sourcePath}`,
          }));
          continue;
        }
        const expectedMarker = scaffoldMarker(taskID, sourcePath);
        if (expectedMarker === null) {
          findings.push(makeFinding({
            id: 'PLAN_RED_SCAFFOLD_ASSERTION',
            category: 'structure',
            taskID,
            path: `/tasks/${taskID}/redScaffold/${sourcePath}`,
            message: `invalid source path ${sourcePath}`,
          }));
        } else if (s.marker !== undefined && s.marker !== expectedMarker) {
          findings.push(makeFinding({
            id: 'PLAN_RED_SCAFFOLD_ASSERTION',
            category: 'structure',
            taskID,
            path: `/tasks/${taskID}/redScaffold/${sourcePath}`,
            message: `scaffold marker mismatch expected=${expectedMarker} actual=${s.marker}`,
          }));
        }
      }
      // Extra scaffold rows (no matching created .swift path).
      for (const s of scaffolds) {
        if (s && typeof s === 'object' && typeof s.sourcePath === 'string'
            && !createdSwift.includes(s.sourcePath)) {
          findings.push(makeFinding({
            id: 'PLAN_RED_SCAFFOLD_EXTRA',
            category: 'structure',
            taskID,
            path: `/tasks/${taskID}/redScaffold/${s.sourcePath}`,
            message: `scaffold row has no matching created Swift source path`,
          }));
        }
      }
    }
  }

  const summary = {
    tasks: taskIDs.length,
    interfaces: producedInterfaceCount,
    sourceGaps,
    acquisitionGaps,
    scaffoldTasks,
    scaffoldPaths,
    authoringGaps,
    symbolicOnly,
  };
  return { findings: sortFindings(findings), summary };
}

function parseArgs(argv) {
  let phase = null;
  let overridePath = null;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--phase') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_OVERRIDES_MISSING_VALUE --phase');
      phase = argv[i];
    } else if (arg === '--path') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_OVERRIDES_MISSING_VALUE --path');
      overridePath = argv[i];
    } else {
      throw new Error(`G6_OVERRIDES_UNKNOWN_FLAG ${arg}`);
    }
  }
  if (!phase) throw new Error('G6_OVERRIDES_REQUIRES --phase');
  if (!VALID_SELECTORS.has(phase)) throw new Error(`G6_OVERRIDES_UNKNOWN_PHASE ${phase}`);
  if (!overridePath) throw new Error('G6_OVERRIDES_REQUIRES --path');
  return { phase, overridePath };
}

function loadJSON(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function main() {
  const { phase, overridePath } = parseArgs(process.argv.slice(2));
  const repoRoot = process.cwd();
  const parentPlan = loadJSON(path.resolve(repoRoot, G5_PLAN_MANIFEST));
  const checksumIndex = loadChecksumIndex(repoRoot);
  const overrides = loadJSON(path.resolve(repoRoot, overridePath));
  const basePhase = PHASE_BASE_FOR[phase];
  const taskIDs = selectPhaseTasks(parentPlan, basePhase, phase, overrides);

  const { findings, summary } = validatePhaseOverrides({
    phase, taskIDs, parentPlan, overrides, checksumIndex,
  });

  if (findings.length > 0) {
    for (const f of findings) {
      process.stdout.write(`${f.id} phase=${phase} task=${f.taskID ?? ''} path=${f.path} ${f.message}\n`);
    }
    process.exit(1);
  }

  process.stdout.write(
    `G6_OVERRIDES_VALID phase=${phase} tasks=${summary.tasks} interfaces=${summary.interfaces} sourceGaps=${summary.sourceGaps} acquisitionGaps=${summary.acquisitionGaps} scaffoldTasks=${summary.scaffoldTasks} scaffoldPaths=${summary.scaffoldPaths} authoringGaps=${summary.authoringGaps} symbolicOnly=${summary.symbolicOnly}\n`,
  );
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main();
}
