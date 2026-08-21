import assert from 'node:assert/strict';
import test from 'node:test';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadContractCatalog } from '../../Tools/Docs/contract-catalog.mjs';
import { loadGreenCommands } from '../../Tools/Docs/task-acceptance-runner.mjs';
import { executeLeaf, rewriteScratch } from '../../Tools/Docs/task-acceptance-runner.mjs';

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

test('rewriteScratch rewrites per-task scratch-path to the shared cache', () => {
  const out = rewriteScratch(['swift', 'test', '--scratch-path', '/tmp/monacode-planctl/X.PROC.001']);
  assert.deepEqual(out, ['swift', 'test', '--scratch-path', '/tmp/monacode-acceptance/shared']);
});

test('executeLeaf runs a fixed leaf and captures exit + stdout', () => {
  const leaf = {
    leafID: 'TEST.LEAF.001',
    executable: '/opt/homebrew/Cellar/node/26.7.0/bin/node',
    args: ['-e', "console.log('LEAF_OK')"],
    timeoutMs: 30000,
  };
  const result = executeLeaf(leaf, REPO_ROOT);
  assert.equal(result.exitCode, 0, 'leaf exits 0');
  assert.equal(result.stdout.trim(), 'LEAF_OK', 'stdout captured');
  assert.equal(result.outputIncludesPass, true, 'output passes when no assertion required');
});
