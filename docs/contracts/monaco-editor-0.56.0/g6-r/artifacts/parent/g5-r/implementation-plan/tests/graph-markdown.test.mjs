import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { recordSha256 } from '../lib/canonical-json.mjs';
import { auditTaskGraph, findClosedCycle, topologicalOrder } from '../lib/graph.mjs';
import { auditMarkdown } from '../lib/markdown.mjs';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const fixtureDirectory = path.join(testDirectory, 'fixtures');
const fixture = (name) => JSON.parse(fs.readFileSync(path.join(fixtureDirectory, name), 'utf8'));

function materializeDocuments(t, documents) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'monacode-plan-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const [relativePath, contents] of Object.entries(documents)) {
    const target = path.join(root, relativePath);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, contents);
  }
  return root;
}

test('rejects a deterministic closed dependency cycle', () => {
  const input = fixture('dependency-cycle.json');
  const findings = auditTaskGraph({ tasks: input.tasks });

  assert.deepEqual(findings.map((finding) => finding.id), input.expectedFindingIds);
  assert.deepEqual(findClosedCycle(input.tasks), [
    'P00-T001',
    'P00-T003',
    'P00-T002',
    'P00-T001'
  ]);
});

test('rejects absent dependencies and duplicate edges', () => {
  const findings = auditTaskGraph({
    tasks: [
      { id: 'P00-T001', dependencies: [] },
      { id: 'P00-T002', dependencies: ['P00-T001', 'P00-T001', 'P00-T999'] }
    ]
  });

  assert.deepEqual(findings.map((finding) => finding.id), [
    'PLAN_DEPENDENCY_ABSENT',
    'PLAN_DEPENDENCY_DUPLICATE'
  ]);
});

test('returns a stable lexicographic topological order', () => {
  assert.deepEqual(topologicalOrder([
    { id: 'P00-T003', dependencies: ['P00-T001'] },
    { id: 'P00-T002', dependencies: [] },
    { id: 'P00-T001', dependencies: [] }
  ]), ['P00-T001', 'P00-T002', 'P00-T003']);
});

test('rejects a Markdown task marker hash drift', (t) => {
  const input = fixture('markdown-drift.json');
  const root = materializeDocuments(t, input.documents);
  const findings = auditMarkdown(input.plan, root);

  assert.deepEqual(findings.map((finding) => finding.id), input.expectedFindingIds);
});

test('accepts exact canonical task markers', (t) => {
  const taskRecord = {
    id: 'P00-T001',
    phase: '00',
    title: 'Exact marker fixture',
    dependencies: []
  };
  const marker = `<!-- monacode-plan-task:{"id":"${taskRecord.id}","recordSha256":"${recordSha256(taskRecord)}"} -->`;
  const documentPath = 'implementation-plan/phase-00-scaffold-harness.md';
  const root = materializeDocuments(t, { [documentPath]: `# Phase 00\n\n${marker}\n` });
  const plan = {
    phases: [{ id: '00', document: documentPath }],
    tasks: [taskRecord]
  };

  assert.deepEqual(auditMarkdown(plan, root), []);
});

test('reports a missing phase document', (t) => {
  const root = materializeDocuments(t, {});
  const findings = auditMarkdown({
    phases: [{ id: '00', document: 'implementation-plan/phase-00-scaffold-harness.md' }],
    tasks: []
  }, root);

  assert.deepEqual(findings.map((finding) => finding.id), ['PLAN_PHASE_DOCUMENT_MISSING']);
});
