import assert from 'node:assert/strict';
import test from 'node:test';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadContractCatalog } from '../../Tools/Docs/contract-catalog.mjs';
import { loadGreenCommands } from '../../Tools/Docs/task-acceptance-runner.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..');

test('loadGreenCommands reads every task green verification-command', () => {
  const catalog = loadContractCatalog(REPO_ROOT);
  const cmds = loadGreenCommands(catalog);
  // 200 plan tasks each have ≥1 green verification-command
  const taskIDs = new Set(cmds.map((c) => c.taskID));
  assert.equal(taskIDs.size, 200, 'all 200 plan tasks have green commands');
  // 206 leaves total
  const leafCount = cmds.reduce((n, c) => n + c.leaves.length, 0);
  assert.equal(leafCount, 206, '206 green leaves total');
  // commandID prefix is <taskID>.GREEN.
  for (const c of cmds) {
    assert.ok(c.commandID.startsWith(`${c.taskID}.GREEN.`), `${c.commandID} prefix`);
    assert.equal(c.expectedExit, 0, `${c.commandID} green expects exit 0`);
    assert.ok(Array.isArray(c.expectedOutputIncludes), `${c.commandID} has output assertions`);
  }
});
