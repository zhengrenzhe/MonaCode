#!/usr/bin/env node
// G6-R Task 11 — build-fragment CLI.
//
// Usage:
//   node Tools/G6PlanAuthoring/build-fragment.mjs --phase PHASE_SELECTOR \
//     --overrides Tools/G6PlanAuthoring/overrides/phase-NN.json \
//     --output Tools/G6PlanAuthoring/fragments/phase-NN.json
//
// Migrates every task declared in the override file into a G6-R TaskRecord,
// aggregates the phase fragment, writes it to --output, and prints:
//   G6_FRAGMENT_WRITTEN phase=<phase> tasks=<n> commands=<n> producedInterfaces=<n> evidence=<n>

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import { buildPhaseFragment, mergeFragments } from './lib/build-fragment.mjs';

const G5_MANIFEST = 'docs/contracts/monaco-editor-0.56.0/g5-r/artifacts/monacode-g5r-implementation-plan-manifest.json';
const PHASE_BASE_FOR = {
  '00': '00', '01': '01', '02': '02', '03': '03', '04': '04',
  '05': '05', '05-foundation': '05', '05-features': '05', '05-closure': '05',
  '06': '06', '07': '07', '08': '08', '09': '09',
};
const VALID_SELECTORS = new Set(Object.keys(PHASE_BASE_FOR));

function parseArgs(argv) {
  let phase = null;
  let mergePhase = null;
  let overridesPath = null;
  let outputPath = null;
  const inputs = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--phase') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_FRAGMENT_MISSING_VALUE --phase');
      phase = argv[i];
    } else if (arg === '--merge-phase') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_FRAGMENT_MISSING_VALUE --merge-phase');
      mergePhase = argv[i];
    } else if (arg === '--input') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_FRAGMENT_MISSING_VALUE --input');
      inputs.push(argv[i]);
    } else if (arg === '--overrides') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_FRAGMENT_MISSING_VALUE --overrides');
      overridesPath = argv[i];
    } else if (arg === '--output') {
      i += 1;
      if (i >= argv.length) throw new Error('G6_FRAGMENT_MISSING_VALUE --output');
      outputPath = argv[i];
    } else {
      throw new Error(`G6_FRAGMENT_UNKNOWN_FLAG ${arg}`);
    }
  }
  if (mergePhase) {
    if (phase) throw new Error('G6_FRAGMENT_CONFLICT --phase --merge-phase');
    if (!VALID_SELECTORS.has(mergePhase)) throw new Error(`G6_FRAGMENT_UNKNOWN_PHASE ${mergePhase}`);
    if (inputs.length < 2) throw new Error('G6_FRAGMENT_REQUIRES --input (at least 2)');
    if (!outputPath) throw new Error('G6_FRAGMENT_REQUIRES --output');
    return { mode: 'merge', phase: mergePhase, inputs, outputPath };
  }
  if (!phase) throw new Error('G6_FRAGMENT_REQUIRES --phase or --merge-phase');
  if (!VALID_SELECTORS.has(phase)) throw new Error(`G6_FRAGMENT_UNKNOWN_PHASE ${phase}`);
  if (!overridesPath) throw new Error('G6_FRAGMENT_REQUIRES --overrides');
  if (!outputPath) throw new Error('G6_FRAGMENT_REQUIRES --output');
  return { mode: 'build', phase, overridesPath, outputPath };
}

function loadJSON(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function selectTaskIDs(overrides, parentPlan, basePhase) {
  const declared = overrides?.tasks && typeof overrides.tasks === 'object'
    ? Object.keys(overrides.tasks)
    : [];
  const declaredSet = new Set(declared);
  // Prefer the override-declared task set; fall back to every G5 task of the base phase.
  if (declaredSet.size > 0) {
    const filtered = declared.filter((id) => {
      const task = parentPlan.tasks.find((t) => t.id === id);
      return task && task.phase === basePhase;
    });
    if (filtered.length > 0) return filtered.sort();
  }
  return parentPlan.tasks.filter((t) => t.phase === basePhase).map((t) => t.id).sort();
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = process.cwd();
  const absOutput = path.resolve(repoRoot, args.outputPath);
  fs.mkdirSync(path.dirname(absOutput), { recursive: true });

  let fragment;
  if (args.mode === 'merge') {
    const fragments = args.inputs.map((p) => loadJSON(path.resolve(repoRoot, p)));
    fragment = mergeFragments(fragments, args.phase);
  } else {
    const basePhase = PHASE_BASE_FOR[args.phase];
    const parentPlan = loadJSON(path.resolve(repoRoot, G5_MANIFEST));
    const overrides = loadJSON(path.resolve(repoRoot, args.overridesPath));
    const taskIDs = selectTaskIDs(overrides, parentPlan, basePhase);
    fragment = buildPhaseFragment({ phase: args.phase, taskIDs, parentPlan, overrides });
  }

  const json = JSON.stringify(fragment, null, 2) + '\n';
  fs.writeFileSync(absOutput, json);

  const c = fragment.counts;
  process.stdout.write(
    `G6_FRAGMENT_WRITTEN phase=${args.phase} tasks=${c.tasks} commands=${c.commands} producedInterfaces=${c.producedInterfaces} evidence=${c.evidence}\n`,
  );
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main();
}
