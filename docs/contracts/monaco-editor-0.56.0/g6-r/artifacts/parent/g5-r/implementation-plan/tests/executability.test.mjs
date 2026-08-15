import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { auditExecutability } from '../lib/executability.mjs';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const artifactDirectory = path.resolve(testDirectory, '../../artifacts');
const plan = JSON.parse(fs.readFileSync(
  path.join(artifactDirectory, 'monacode-g5r-implementation-plan-manifest.json'),
  'utf8'
));

test('the canonical plan has complete file and interface provenance with executable commands', () => {
  assert.deepEqual(auditExecutability(plan), []);
});

test('rejects undefined interfaces, unordered consumers, absent files, and prose commands', () => {
  const input = structuredClone(plan);
  const undefinedTask = input.tasks.find((task) => task.id === 'P00-T001');
  undefinedTask.interfaces.consumes.push('MonaUndefinedInterface');
  const unorderedTask = input.tasks.find((task) => task.id === 'P01-T002');
  unorderedTask.dependencies = [];
  const fileTask = input.tasks.find((task) => task.id === 'P01-T008');
  fileTask.files.modify.push('Sources/MonaCode/Model/MonaNeverCreated.swift');
  const commandTask = input.tasks.find((task) => task.id === 'P00-T001');
  commandTask.green[0].run = 'Run the focused tests and confirm success';

  assert.deepEqual(
    [...new Set(auditExecutability(input).map((finding) => finding.id))].sort(),
    [
      'PLAN_COMMAND_NOT_EXECUTABLE',
      'PLAN_FILE_PROVENANCE',
      'PLAN_INTERFACE_ORDER',
      'PLAN_INTERFACE_UNDEFINED'
    ]
  );
});
