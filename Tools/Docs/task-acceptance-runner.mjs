import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
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
