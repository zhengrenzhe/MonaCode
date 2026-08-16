// G6-R Markdown audit tests (Task 26 Step 1). Loads the real plan and proves
// zero markdown findings (phase documents exist, no malformed markers), then
// mutates a fixture document and asserts a markdown finding.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

import { auditMarkdown } from '../lib/markdown.mjs';
import { canonicalJSONStringify } from '../lib/canonical-json.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PLAN_DIR = path.dirname(__dirname);
const CONTRACT_DIR = path.dirname(PLAN_DIR);
const ARTIFACT_DIR = path.join(CONTRACT_DIR, 'artifacts');
const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const PLAN = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-implementation-plan-manifest.json'));

test('markdown: real plan phase documents all exist (zero findings)', () => {
  const r = auditMarkdown(PLAN, CONTRACT_DIR);
  assert.equal(r.findings.length, 0);
  assert.ok(r.documentHashes.length >= 10);
});

test('markdown: a missing phase document yields one finding', () => {
  const p = structuredClone(PLAN);
  p.phases[0].document = 'implementation-plan/does-not-exist.md';
  const r = auditMarkdown(p, CONTRACT_DIR);
  assert.equal(r.findings.length, 1);
  assert.equal(r.findings[0].id, 'PLAN_PHASE_DOCUMENT_MISSING');
});

test('markdown: a malformed marker yields one finding', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'g6r-md-'));
  try {
    const doc = 'phase-00-scaffold-harness.md';
    fs.writeFileSync(path.join(dir, doc), '<!-- monacode-plan-task:not-json -->\n');
    const plan = { phases: [{ id: '00', document: doc }], tasks: [] };
    const r = auditMarkdown(plan, dir);
    assert.equal(r.findings.length, 1);
    assert.equal(r.findings[0].id, 'PLAN_MARKDOWN_DRIFT');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('markdown: a canonical marker matches a task recordSha256 (zero findings)', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'g6r-md-'));
  try {
    const task = { id: 'P00-T001', phase: '00', recordSha256: 'a'.repeat(64) };
    const marker = canonicalJSONStringify({ id: task.id, recordSha256: task.recordSha256 });
    const doc = 'phase-00-scaffold-harness.md';
    fs.writeFileSync(path.join(dir, doc), `<!-- monacode-plan-task:${marker} -->\n`);
    const r = auditMarkdown({ phases: [{ id: '00', document: doc }], tasks: [task] }, dir);
    assert.equal(r.findings.length, 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
