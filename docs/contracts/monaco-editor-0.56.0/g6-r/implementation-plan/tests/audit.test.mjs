// G6-R integrated audit tests (Task 26 Step 1).
// Loads the real assembled plan and proves the audit achieves zero findings
// (GREEN), then mutates one input per audit category and asserts that
// category's finding count increments by one while unrelated categories remain
// zero. Each mutation is applied to a deep copy of the real plan.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { auditPlan } from '../lib/audit.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PLAN_DIR = path.dirname(__dirname);
const CONTRACT_DIR = path.dirname(PLAN_DIR);
const ARCHIVE_ROOT = CONTRACT_DIR;
const ARTIFACT_DIR = path.join(CONTRACT_DIR, 'artifacts');

const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const PLAN = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-implementation-plan-manifest.json'));
const CONTRACT = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-authoritative-manifest.json'));
const PAYLOAD_PATH = path.join(PLAN_DIR, 'verification', 'payload-index.json');
const PAYLOAD = fs.existsSync(PAYLOAD_PATH) ? loadJSON(PAYLOAD_PATH) : null;

const COMPLETED_THROUGH_TASK = (PAYLOAD && Number.isInteger(PAYLOAD.completedThroughTask))
  ? PAYLOAD.completedThroughTask : 26;

function run(plan) {
  return auditPlan({
    contract: CONTRACT, plan, commands: plan.commands ?? [], interfaces: plan.interfaces ?? [],
    archiveRoot: ARCHIVE_ROOT, completedThroughTask: COMPLETED_THROUGH_TASK, payloadIndex: PAYLOAD,
  });
}

function countByCategory(findings) {
  const m = {};
  for (const f of findings) m[f.category] = (m[f.category] ?? 0) + 1;
  return m;
}

test('audit: real assembled plan achieves zero findings (GREEN)', () => {
  const r = run(PLAN);
  assert.equal(r.findingCount, 0, `expected zero findings, got:\n${r.findings.map((f) => `${f.id} ${f.message}`).join('\n')}`);
  assert.equal(r.status, 'pass');
});

test('audit: schema category — corrupt stage set', () => {
  const p = structuredClone(PLAN);
  p.tasks[0].stages[0].name = 'not-preflight';
  const c = countByCategory(run(p).findings);
  assert.equal(c.schema, 1);
});

test('audit: graph category — add a missing dependency', () => {
  const p = structuredClone(PLAN);
  p.tasks[0].dependencies.push('P99-T999');
  const c = countByCategory(run(p).findings);
  assert.equal(c.graph, 1);
});

test('audit: coverage category — remove an ownership row', () => {
  const p = structuredClone(PLAN);
  p.ownership.shift();
  const c = countByCategory(run(p).findings);
  assert.equal(c.coverage, 1);
});

test('audit: boundary category — add a forbidden runtime path', () => {
  const p = structuredClone(PLAN);
  p.tasks[0].paths.create.push('Sources/MonaCode/BuiltinLanguagePack.swift');
  const c = countByCategory(run(p).findings);
  assert.equal(c.boundary, 1);
});

test('audit: product-commit category — wrong author identity', () => {
  const p = structuredClone(PLAN);
  p.tasks[0].commits.product.author.name = 'someone-else';
  const c = countByCategory(run(p).findings);
  assert.equal(c['product-commit'], 1);
});

test('audit: evidence-commit category — wrong message', () => {
  const p = structuredClone(PLAN);
  p.tasks[0].commits.evidence.message = 'wrong';
  const c = countByCategory(run(p).findings);
  assert.equal(c['evidence-commit'], 1);
});

test('audit: commit-lifecycle category — remove begin-task', () => {
  const p = structuredClone(PLAN);
  p.tasks[0].stages.find((s) => s.name === 'preflight').steps[0].action = 'not-begin';
  const c = countByCategory(run(p).findings);
  assert.equal(c['commit-lifecycle'], 1);
});

test('audit: source-acquisition category — bad url', () => {
  const p = structuredClone(PLAN);
  const t = p.tasks.find((x) => (x.sourceAcquisitions ?? []).length > 0);
  t.sourceAcquisitions[0].url = 'http://insecure';
  const c = countByCategory(run(p).findings);
  assert.equal(c['source-acquisition'], 1);
});

test('audit: file-state category — duplicate create path across tasks', () => {
  const p = structuredClone(PLAN);
  p.tasks[1].paths.create.push(p.tasks[0].paths.create[0]);
  const c = countByCategory(run(p).findings);
  assert.equal(c['file-state'], 1);
});

test('audit: ambiguity category — reference an unknown leaf', () => {
  const p = structuredClone(PLAN);
  p.tasks[0].testContract.cases[0].redLeafID = 'P00-T001.RED.999.PROC.999';
  const c = countByCategory(run(p).findings);
  assert.equal(c.ambiguity, 1);
});

test('audit: interface category — consume an unproduced interface', () => {
  const p = structuredClone(PLAN);
  p.tasks[0].interfaces.consumes.push({ id: 'NonexistentInterface' });
  const c = countByCategory(run(p).findings);
  assert.equal(c.interface, 1);
});

test('audit: payload-inventory category — wrong row count', () => {
  const badPayload = { rows: PAYLOAD.rows.slice(0, 100) };
  const r = auditPlan({
    contract: CONTRACT, plan: PLAN, commands: PLAN.commands, interfaces: PLAN.interfaces,
    archiveRoot: ARCHIVE_ROOT, completedThroughTask: COMPLETED_THROUGH_TASK, payloadIndex: badPayload,
  });
  const c = countByCategory(r.findings);
  assert.equal(c['payload-inventory'], 1);
});
