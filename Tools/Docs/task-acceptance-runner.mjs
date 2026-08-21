import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { canonicalJSON } from '../../Comparators/probes/product-integration-probe.mjs';
import { loadContractCatalog } from './contract-catalog.mjs';
import { computeVerificationSourceSet, sha256 } from './source-set.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_REPO_ROOT = resolve(HERE, '..', '..');
const SHARED_SCRATCH = '/tmp/monacode-acceptance/shared';

export function loadGreenCommands(catalog) {
  return catalog.planTasks.flatMap((task) => {
    const green = (task.stages ?? []).find((s) => s.name === 'green');
    if (!green) return [];
    return green.steps
      .filter((step) => step.kind === 'verification-command')
      .map((step) => ({
        taskID: task.id,
        commandID: step.command.commandID,
        kind: step.command.kind,
        expectedExit: step.command.expectedExit,
        expectedOutputIncludes: step.command.expectedOutputIncludes ?? [],
        leaves: step.command.leaves ?? [],
      }));
  });
}

export function rewriteScratch(args) {
  const out = [...args];
  for (let i = 0; i < out.length - 1; i++) {
    if (out[i] === '--scratch-path' && String(out[i + 1]).startsWith('/tmp/monacode-planctl/')) {
      out[i + 1] = SHARED_SCRATCH;
    }
  }
  return out;
}

export function executeLeaf(leaf, repoRoot) {
  const args = rewriteScratch(leaf.args);
  const result = spawnSync(leaf.executable, args, {
    cwd: repoRoot,
    encoding: 'utf8',
    maxBuffer: 512 * 1024 * 1024,
    timeout: leaf.timeoutMs ?? 600000,
  });
  const stdout = result.stdout ?? '';
  const stderr = result.stderr ?? '';
  // outputIncludesPass: caller (runCommand) asserts expectedOutputIncludes;
  // leaf-level returns raw exit + whether stderr has XCTest failure markers.
  return {
    leafID: leaf.leafID,
    exitCode: result.status,
    stdout,
    stderr,
    outputIncludesPass: true, // no per-leaf output assertion; asserted at command level
  };
}

const leafPasses = (leaf, result, expectedExit, expectedOutputIncludes) => {
  if (!result) return false;
  if (result.exitCode !== expectedExit) return false;
  return expectedOutputIncludes.every((needle) => result.stdout.includes(needle));
};

export function synthesizeTask(commands, leafResults) {
  const exitCodes = [];
  const outputIncludesPass = [];
  for (const cmd of commands) {
    for (const leaf of cmd.leaves) {
      const r = leafResults[leaf.leafID];
      exitCodes.push(r?.exitCode ?? null);
      outputIncludesPass.push(leafPasses(leaf, r, cmd.expectedExit, cmd.expectedOutputIncludes));
    }
  }
  // process: one command, all its leaves pass. all-success: all commands all leaves pass.
  // pipeline: all commands all leaves pass (pipefail semantics → same as all-success for exit).
  const passed = commands.length > 0 && commands.every((cmd) =>
    cmd.leaves.every((leaf) => leafPasses(leaf, leafResults[leaf.leafID], cmd.expectedExit, cmd.expectedOutputIncludes)));
  return { passed, exitCodes, outputIncludesPass };
}

export function runAllAcceptance(repoRoot, options = {}) {
  const sourceSet = computeVerificationSourceSet(repoRoot);
  const catalog = loadContractCatalog(repoRoot);
  const commands = loadGreenCommands(catalog);
  const limited = options.limit ? commands.slice(0, options.limit) : commands;
  const leafResults = {};
  for (const cmd of limited) {
    for (const leaf of cmd.leaves) {
      leafResults[leaf.leafID] = executeLeaf(leaf, repoRoot);
    }
  }
  // group commands by taskID (a task may have multiple green commands)
  const byTask = new Map();
  for (const cmd of limited) {
    if (!byTask.has(cmd.taskID)) byTask.set(cmd.taskID, []);
    byTask.get(cmd.taskID).push(cmd);
  }
  const taskResults = [...byTask.entries()].map(([taskID, cmds]) => {
    const synth = synthesizeTask(cmds, leafResults);
    return { taskID, commandIDs: cmds.map((c) => c.commandID), ...synth };
  });
  const evidence = {
    schemaVersion: 1,
    digest: sourceSet.digest,
    runnerAt: null,
    taskResults,
  };
  if (options.write) {
    const path = join(repoRoot, 'artifacts', 'progress', sourceSet.digest, 'task-acceptance.json');
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, canonicalJSON(evidence));
  }
  return evidence;
}

const invokedDirectly = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invokedDirectly) {
  const args = new Set(process.argv.slice(2));
  const limit = args.has('--limit') ? 2 : undefined; // --limit smoke; full run = no flag
  const evidence = runAllAcceptance(DEFAULT_REPO_ROOT, { limit, write: true });
  process.stdout.write(canonicalJSON({ digest: evidence.digest, taskCount: evidence.taskResults.length, passed: evidence.taskResults.filter((r) => r.passed).length }));
}
