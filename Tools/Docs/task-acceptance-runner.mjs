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
