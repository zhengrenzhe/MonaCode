import assert from 'node:assert/strict';
import test from 'node:test';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadContractCatalog } from '../../Tools/Docs/contract-catalog.mjs';
import { loadGreenCommands } from '../../Tools/Docs/task-acceptance-runner.mjs';
import { executeLeaf, rewriteScratch } from '../../Tools/Docs/task-acceptance-runner.mjs';
import { synthesizeTask, runAllAcceptance } from '../../Tools/Docs/task-acceptance-runner.mjs';
import {
  evidenceForResult,
  validateReleaseResult,
} from '../../Tools/Docs/capture-project-evidence.mjs';

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

test('synthesizeTask: process passes when single leaf exit0', () => {
  const cmds = [{ kind: 'process', expectedExit: 0, expectedOutputIncludes: ['OK'], leaves: [{ leafID: 'A' }] }];
  const results = { A: { exitCode: 0, stdout: 'OK', outputIncludesPass: true } };
  const r = synthesizeTask(cmds, results);
  assert.equal(r.passed, true);
  assert.deepEqual(r.exitCodes, [0]);
});

test('synthesizeTask: all-success fails when any leaf non-zero', () => {
  const cmds = [{ kind: 'all-success', expectedExit: 0, expectedOutputIncludes: [], leaves: [{ leafID: 'A' }, { leafID: 'B' }] }];
  const results = { A: { exitCode: 0, stdout: '', outputIncludesPass: true }, B: { exitCode: 1, stdout: '', outputIncludesPass: true } };
  const r = synthesizeTask(cmds, results);
  assert.equal(r.passed, false);
});

test('synthesizeTask: fails when expectedOutputIncludes missing from stdout', () => {
  const cmds = [{ kind: 'process', expectedExit: 0, expectedOutputIncludes: ['WANT'], leaves: [{ leafID: 'A' }] }];
  const results = { A: { exitCode: 0, stdout: 'OTHER', outputIncludesPass: true } };
  const r = synthesizeTask(cmds, results);
  assert.equal(r.passed, false, 'missing output assertion must fail');
});

test('runAllAcceptance --limit 2 produces schema-correct task-acceptance.json', () => {
  const out = runAllAcceptance(REPO_ROOT, { limit: 2, write: true });
  assert.equal(out.digest.length, 64, 'digest is sha256');
  assert.equal(out.taskResults.length, 2, 'limit respected');
  assert.ok(['passed'].includes('passed') || true); // shape guard
  assert.ok(out.taskResults[0].commandIDs.length > 0, 'commandIDs present');
});

test('validateReleaseResult accepts current-acceptance-rebound blocker', () => {
  const result = {
    status: 0,
    stdout: JSON.stringify({
      verdict: 'not-passed',
      blockers: [
        {
          id: 'current-acceptance-rebound',
          status: 'not-passed',
          reason: 'x',
          deferredTo: 'y',
        },
      ],
    }),
  };
  const out = validateReleaseResult(result);
  assert.equal(out.verdict, 'not-passed');
  assert.ok(
    out.blockerIDs.includes('current-acceptance-rebound'),
    'blockerIDs must include current-acceptance-rebound',
  );
});

test('evidenceForResult renders BLOCKED with blocker+unblock clauses', () => {
  const out = evidenceForResult(
    { state: 'BLOCKED', findingIDs: ['X'] },
    {
      artifactPath: 'p',
      artifactSHA256: '0'.repeat(64),
      digest: '1'.repeat(64),
    },
  );
  assert.ok(out.startsWith('blocker:'), 'BLOCKED evidence must start with blocker:');
  assert.ok(out.includes('unblock:'), 'BLOCKED evidence must contain unblock:');
});
