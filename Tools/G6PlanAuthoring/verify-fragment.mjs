#!/usr/bin/env node
// G6-R Task 11 — verify-fragment CLI.
//
// Usage:
//   node Tools/G6PlanAuthoring/verify-fragment.mjs --phase PHASE_SELECTOR \
//     --path Tools/G6PlanAuthoring/fragments/phase-NN.json [--dependency <prior-fragment.json>] [--feature-manifest <manifest>]
//
// If the fragment file is absent or empty, prints `PLAN_FRAGMENT_MISSING phase=<phase>` and exits 1.
// Otherwise validates the fragment structure and prints:
//   tasks=N commands=N create=N modify=N test=N commit=N ownership=N produced=N consumed=N evidence=N

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

import { makeFinding, sortFindings } from '../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/findings.mjs';

const VALID_SELECTORS = new Set([
  '00', '01', '02', '03', '04',
  '05', '05-foundation', '05-features', '05-closure',
  '06', '07', '08', '09',
]);
const STAGE_NAMES = ['preflight', 'test-authoring', 'red', 'implementation', 'green', 'commit', 'evidence'];

function uniqueCount(rows) {
  return new Set(rows).size;
}

function countFragment(fragment) {
  const tasks = Array.isArray(fragment?.tasks) ? fragment.tasks : [];
  const commands = Array.isArray(fragment?.commands) ? fragment.commands : [];
  const interfaces = Array.isArray(fragment?.interfaces) ? fragment.interfaces : [];
  const evidence = Array.isArray(fragment?.evidence) ? fragment.evidence : [];

  const create = uniqueCount(tasks.flatMap((t) => t.paths?.create ?? []));
  const modify = uniqueCount(tasks.flatMap((t) => t.paths?.modify ?? []));
  const test = uniqueCount(tasks.flatMap((t) => t.paths?.test ?? []));
  const commit = uniqueCount(tasks.flatMap((t) => t.commits?.product?.stagedProductPaths ?? []));
  const ownership = tasks.reduce((n, t) => n + (Array.isArray(t.ownership) ? t.ownership.length : 0), 0);
  const produced = interfaces.length;
  const consumed = uniqueCount(tasks.flatMap((t) => (t.interfaces?.consumes ?? []).map((c) => typeof c === 'string' ? c : c?.id)));
  return {
    tasks: tasks.length,
    commands: commands.length,
    create, modify, test, commit, ownership, produced, consumed,
    evidence: evidence.length,
  };
}

/**
 * Validate a parsed phase fragment and compare against expected counts.
 * @param {object} fragment
 * @param {{phase?:string, expected?:object}} [expected]
 * @returns {object[]} Finding[] (sorted)
 */
export function verifyFragment(fragment, expected) {
  const findings = [];
  const phase = expected?.phase ?? null;
  if (!fragment || typeof fragment !== 'object' || !Array.isArray(fragment.tasks)) {
    findings.push(makeFinding({
      id: 'PLAN_FRAGMENT_SHAPE',
      category: 'structure',
      taskID: null,
      path: '',
      message: `fragment is not a task array${phase ? ` phase=${phase}` : ''}`,
    }));
    return sortFindings(findings);
  }
  for (const task of fragment.tasks) {
    const names = (task.stages ?? []).map((s) => s?.name);
    if (names.length !== 7 || !names.every((n, i) => n === STAGE_NAMES[i])) {
      findings.push(makeFinding({
        id: 'PLAN_FRAGMENT_STAGE',
        category: 'structure',
        taskID: task.id ?? null,
        path: '/stages',
        message: `stage set/order mismatch: ${JSON.stringify(names)}`,
      }));
    }
  }
  const counts = countFragment(fragment);
  if (expected?.expected) {
    for (const [key, value] of Object.entries(expected.expected)) {
      if (counts[key] !== value) {
        findings.push(makeFinding({
          id: 'PLAN_FRAGMENT_COUNT',
          category: 'structure',
          taskID: null,
          path: `/${key}`,
          message: `${key} expected=${value} actual=${counts[key]}${phase ? ` phase=${phase}` : ''}`,
        }));
      }
    }
  }
  return sortFindings(findings);
}

// ===========================================================================
// Flag #1 — --renderer core-graphics | core-graphics-plus-metal
// Computes a branch-specific final path hash from the fragment's product-commit
// staged paths. `core-graphics` EXCLUDES paths whose last path component
// contains "Metal" (case-sensitive); `core-graphics-plus-metal` INCLUDES all.
// Both branches yield IDENTICAL task/command/ownership/interface counts (the
// Metal branch adds paths, not tasks/commands). The path hash is informational.
// ===========================================================================

function collectStagedPaths(fragment) {
  const tasks = Array.isArray(fragment?.tasks) ? fragment.tasks : [];
  const paths = new Set();
  for (const t of tasks) {
    for (const p of (t.commits?.product?.stagedProductPaths ?? [])) {
      paths.add(p);
    }
  }
  return [...paths];
}

function lastPathComponent(p) {
  const parts = String(p).split('/');
  return parts[parts.length - 1];
}

/**
 * Compute the branch-specific final path hash.
 * @param {object} fragment
 * @param {'core-graphics'|'core-graphics-plus-metal'} mode
 * @returns {{hash:string, selected:string[], selectedCount:number, totalCount:number}}
 */
export function computeRendererPathHash(fragment, mode) {
  const allPaths = collectStagedPaths(fragment);
  const selected = allPaths
    .filter((p) => mode !== 'core-graphics' || !lastPathComponent(p).includes('Metal'))
    .sort();
  const hash = crypto.createHash('sha256').update(selected.join('\n')).digest('hex');
  return { hash, selected, selectedCount: selected.length, totalCount: allPaths.length };
}

// ===========================================================================
// Flag #2 — --feature-manifest <path>
// Extracts the fragment's feature task IDs (P05-T100..T199, excluding closure
// T190/T200) and compares against the manifest's retained feature identities.
// ===========================================================================

const FEATURE_ID_RE = /^P05-T1\d\d$/;
const CLOSURE_TASK_IDS = new Set(['P05-T190', 'P05-T200']);

function isFeatureTaskID(id) {
  return typeof id === 'string' && FEATURE_ID_RE.test(id) && !CLOSURE_TASK_IDS.has(id);
}

/**
 * Extract feature task IDs from a fragment.
 * @param {object} fragment
 * @returns {string[]}
 */
export function extractFragmentFeatureIDs(fragment) {
  const tasks = Array.isArray(fragment?.tasks) ? fragment.tasks : [];
  return [...new Set(tasks.map((t) => t?.id).filter(isFeatureTaskID))].sort();
}

/**
 * Extract retained feature identities from a manifest JSON. Supports a
 * `retainedFeatures`/`features` array (of strings or {id} objects) or a
 * `tasks` array (filtered by the feature pattern).
 * @param {object} manifest
 * @returns {string[]}
 */
export function extractManifestFeatureIDs(manifest) {
  let rows = [];
  if (Array.isArray(manifest?.retainedFeatures)) {
    rows = manifest.retainedFeatures;
  } else if (Array.isArray(manifest?.features)) {
    rows = manifest.features;
  } else if (Array.isArray(manifest?.tasks)) {
    rows = manifest.tasks.map((t) => t?.id);
  }
  return [...new Set(rows.map((r) => (typeof r === 'string' ? r : r?.id)).filter(isFeatureTaskID))].sort();
}

/**
 * Compare the fragment's feature IDs against the manifest's retained features.
 * @returns {{missingFeatures:number, extraFeatures:number}}
 */
export function checkFeatureManifest(fragment, manifest) {
  const fragmentIDs = new Set(extractFragmentFeatureIDs(fragment));
  const manifestIDs = new Set(extractManifestFeatureIDs(manifest));
  let missing = 0;
  let extra = 0;
  for (const id of manifestIDs) if (!fragmentIDs.has(id)) missing += 1;
  for (const id of fragmentIDs) if (!manifestIDs.has(id)) extra += 1;
  return { missingFeatures: missing, extraFeatures: extra };
}

// ===========================================================================
// Flag #4 — --dependency <predecessor-fragment>
// Verifies the current fragment's CONSUMED interfaces are all PRODUCED by the
// predecessor (no forward references to interfaces only produced later).
// ===========================================================================

function collectProducedInterfaces(fragment) {
  const produced = new Set();
  if (Array.isArray(fragment?.interfaces)) {
    for (const row of fragment.interfaces) {
      const id = typeof row === 'string' ? row : row?.id;
      if (typeof id === 'string') produced.add(id);
    }
  }
  if (Array.isArray(fragment?.tasks)) {
    for (const t of fragment.tasks) {
      for (const c of (t.interfaces?.produces ?? [])) {
        const id = typeof c === 'string' ? c : c?.id;
        if (typeof id === 'string') produced.add(id);
      }
    }
  }
  return produced;
}

function collectConsumedInterfaces(fragment) {
  const consumed = new Set();
  if (Array.isArray(fragment?.tasks)) {
    for (const t of fragment.tasks) {
      for (const c of (t.interfaces?.consumes ?? [])) {
        const id = typeof c === 'string' ? c : c?.id;
        if (typeof id === 'string') consumed.add(id);
      }
    }
  }
  return consumed;
}

/**
 * Check that every consumed interface of `fragment` is produced by `predecessor`.
 * @returns {{candidateBeforeProducer:number}}
 */
export function checkDependency(fragment, predecessor) {
  const produced = collectProducedInterfaces(predecessor);
  const consumed = collectConsumedInterfaces(fragment);
  let candidateBeforeProducer = 0;
  for (const id of consumed) {
    if (!produced.has(id)) candidateBeforeProducer += 1;
  }
  return { candidateBeforeProducer };
}

function parseArgs(argv) {
  let phase = null;
  let fragmentPath = null;
  let dependencyPath = null;
  let featureManifestPath = null;
  let renderer = null;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--phase') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_VERIFY_MISSING_VALUE --phase');
      phase = argv[i];
    } else if (arg === '--path') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_VERIFY_MISSING_VALUE --path');
      fragmentPath = argv[i];
    } else if (arg === '--dependency') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_VERIFY_MISSING_VALUE --dependency');
      dependencyPath = argv[i];
    } else if (arg === '--feature-manifest') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_VERIFY_MISSING_VALUE --feature-manifest');
      featureManifestPath = argv[i];
    } else if (arg === '--renderer') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_VERIFY_MISSING_VALUE --renderer');
      renderer = argv[i];
    } else {
      throw new Error(`G6_VERIFY_UNKNOWN_FLAG ${arg}`);
    }
  }
  if (!phase) throw new Error('G6_VERIFY_REQUIRES --phase');
  if (!VALID_SELECTORS.has(phase)) throw new Error(`G6_VERIFY_UNKNOWN_PHASE ${phase}`);
  if (!fragmentPath) throw new Error('G6_VERIFY_REQUIRES --path');
  if (renderer !== null && renderer !== 'core-graphics' && renderer !== 'core-graphics-plus-metal') {
    throw new Error(`G6_VERIFY_UNKNOWN_RENDERER ${renderer}`);
  }
  return { phase, fragmentPath, dependencyPath, featureManifestPath, renderer };
}

function loadJSON(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function main() {
  const { phase, fragmentPath, dependencyPath, featureManifestPath, renderer } = parseArgs(process.argv.slice(2));
  const repoRoot = process.cwd();
  const absFragment = path.resolve(repoRoot, fragmentPath);
  if (!fs.existsSync(absFragment)) {
    process.stdout.write(`PLAN_FRAGMENT_MISSING phase=${phase}\n`);
    process.exit(1);
  }
  const stat = fs.statSync(absFragment);
  if (!stat.isFile() || stat.size === 0) {
    process.stdout.write(`PLAN_FRAGMENT_MISSING phase=${phase}\n`);
    process.exit(1);
  }
  const fragment = loadJSON(absFragment);
  const findings = verifyFragment(fragment, { phase });
  if (findings.length > 0) {
    for (const f of findings) {
      process.stdout.write(`${f.id} phase=${phase} path=${f.path} ${f.message}\n`);
    }
    process.exit(1);
  }
  const c = countFragment(fragment);
  process.stdout.write(
    `tasks=${c.tasks} commands=${c.commands} create=${c.create} modify=${c.modify} test=${c.test} commit=${c.commit} ownership=${c.ownership} produced=${c.produced} consumed=${c.consumed} evidence=${c.evidence}\n`,
  );

  let failed = 0;

  // --renderer: branch-specific final path hash (informational; exit 0 if valid).
  if (renderer) {
    const r = computeRendererPathHash(fragment, renderer);
    process.stdout.write(
      `renderer=${renderer} finalPathHash=${r.hash} selectedPaths=${r.selectedCount} totalPaths=${r.totalCount}\n`,
    );
  }

  // --feature-manifest: compare fragment feature IDs against the manifest.
  if (featureManifestPath) {
    const manifest = loadJSON(path.resolve(repoRoot, featureManifestPath));
    const fc = checkFeatureManifest(fragment, manifest);
    process.stdout.write(`missingFeatures=${fc.missingFeatures} extraFeatures=${fc.extraFeatures}\n`);
    if (fc.missingFeatures > 0 || fc.extraFeatures > 0) failed += 1;
  }

  // --dependency: verify no forward references (consumed interfaces must be
  // produced by the predecessor).
  if (dependencyPath) {
    const predecessor = loadJSON(path.resolve(repoRoot, dependencyPath));
    const dc = checkDependency(fragment, predecessor);
    process.stdout.write(`candidateBeforeProducer=${dc.candidateBeforeProducer}\n`);
    if (dc.candidateBeforeProducer > 0) failed += 1;
  }

  if (failed > 0) process.exit(1);
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main();
}
