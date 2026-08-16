// G6-R mutation-coverage structural test (Task 27 Step 1).
//
// Owns the exact ordered family-key set AF01..AF35, the exact ordered 75-attack
// key set transcribed from Tasks 29-32 (R1=12, R2=22, R3=29, R4=12), and the
// ordered required variant-key set transcribed from the approved design and
// Tasks 29-32. Requires exact equality with the catalog's flattened family,
// attack, and variant keys and rejects a missing, duplicate, empty, prose-only,
// or multiply selected row. Asserts every production audit rule has one
// positive control and at least one exact negative fixture, and zero fixture
// IDs without a production rule.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import {
  FAMILIES, PRODUCTION_RULES, ATTACK_IDS, REQUIRED_VARIANT_IDS,
  auditMutationCoverage, buildSealedCatalog, hashCatalog,
} from '../lib/mutation-coverage.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES_PATH = path.join(__dirname, 'fixtures', 'mutation-fixtures.json');

// The closed 35-family set, transcribed verbatim from the approved design's
// adversarial matrix (lines 391-425). The test owns this literal.
const EXPECTED_FAMILIES = [
  'AF01', 'AF02', 'AF03', 'AF04', 'AF05', 'AF06', 'AF07', 'AF08', 'AF09',
  'AF10', 'AF11', 'AF12', 'AF13', 'AF14', 'AF15', 'AF16', 'AF17', 'AF18',
  'AF19', 'AF20', 'AF21', 'AF22', 'AF23', 'AF24', 'AF25', 'AF26', 'AF27',
  'AF28', 'AF29', 'AF30', 'AF31', 'AF32', 'AF33', 'AF34', 'AF35',
];

// The closed 75-attack set transcribed from Tasks 29-32. R1=12, R2=22, R3=29,
// R4=12. Each ID is consecutive within its round.
const EXPECTED_ATTACK_IDS = [
  ...Array.from({ length: 12 }, (_, i) => `R1-A${String(i + 1).padStart(2, '0')}`),
  ...Array.from({ length: 22 }, (_, i) => `R2-A${String(i + 1).padStart(2, '0')}`),
  ...Array.from({ length: 29 }, (_, i) => `R3-A${String(i + 1).padStart(2, '0')}`),
  ...Array.from({ length: 12 }, (_, i) => `R4-A${String(i + 1).padStart(2, '0')}`),
];

// Required variant IDs transcribed from the approved design and Tasks 29-32:
// every distinct "plus", "or", slash-delimited, or named-bypass case is its own
// variant row. Built by expanding the design's per-attack variant counts.
function buildExpectedVariantIDs() {
  const counts = {
    'R1-A01': 1, 'R1-A02': 1, 'R1-A03': 2, 'R1-A04': 1, 'R1-A05': 1, 'R1-A06': 1,
    'R1-A07': 1, 'R1-A08': 1, 'R1-A09': 1, 'R1-A10': 1, 'R1-A11': 1, 'R1-A12': 1,
    'R2-A01': 1, 'R2-A02': 1, 'R2-A03': 1, 'R2-A04': 1, 'R2-A05': 1, 'R2-A06': 1,
    'R2-A07': 1, 'R2-A08': 1, 'R2-A09': 1, 'R2-A10': 1, 'R2-A11': 1, 'R2-A12': 5,
    'R2-A13': 1, 'R2-A14': 11, 'R2-A15': 1, 'R2-A16': 1, 'R2-A17': 1, 'R2-A18': 1,
    'R2-A19': 1, 'R2-A20': 1, 'R2-A21': 2, 'R2-A22': 1,
    'R3-A01': 1, 'R3-A02': 1, 'R3-A03': 1, 'R3-A04': 1, 'R3-A05': 1, 'R3-A06': 1,
    'R3-A07': 1, 'R3-A08': 1, 'R3-A09': 1, 'R3-A10': 1, 'R3-A11': 1, 'R3-A12': 1,
    'R3-A13': 1, 'R3-A14': 1, 'R3-A15': 1, 'R3-A16': 1, 'R3-A17': 1, 'R3-A18': 1,
    'R3-A19': 1, 'R3-A20': 1, 'R3-A21': 4, 'R3-A22': 5, 'R3-A23': 1, 'R3-A24': 1,
    'R3-A25': 1, 'R3-A26': 1, 'R3-A27': 1, 'R3-A28': 1, 'R3-A29': 1,
    'R4-A01': 1, 'R4-A02': 1, 'R4-A03': 4, 'R4-A04': 1, 'R4-A05': 3, 'R4-A06': 1,
    'R4-A07': 5, 'R4-A08': 1, 'R4-A09': 3, 'R4-A10': 1, 'R4-A11': 1, 'R4-A12': 3,
  };
  const ids = [];
  for (const attack of EXPECTED_ATTACK_IDS) {
    for (let i = 1; i <= counts[attack]; i++) ids.push(`${attack}.V${String(i).padStart(2, '0')}`);
  }
  return ids;
}

const EXPECTED_VARIANT_IDS = buildExpectedVariantIDs();

test('mutation-coverage: catalog file exists and parses', () => {
  assert.ok(fs.existsSync(FIXTURES_PATH), 'mutation-fixtures.json must exist');
  const text = fs.readFileSync(FIXTURES_PATH, 'utf8');
  const cat = JSON.parse(text);
  assert.equal(cat.schemaVersion, 1);
});

test('mutation-coverage: exactly 35 ordered family keys AF01..AF35', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  assert.deepEqual(cat.families, EXPECTED_FAMILIES);
  assert.deepEqual(FAMILIES, EXPECTED_FAMILIES);
  // No duplicates, no empties, no prose-only entries.
  assert.equal(new Set(cat.families).size, 35);
});

test('mutation-coverage: exactly 75 ordered attack IDs (R1=12, R2=22, R3=29, R4=12)', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const ids = cat.attacks.map((a) => a.id);
  assert.deepEqual(ids, EXPECTED_ATTACK_IDS);
  assert.deepEqual(ATTACK_IDS, EXPECTED_ATTACK_IDS);
  // Consecutive within each round.
  for (const round of ['R1', 'R2', 'R3', 'R4']) {
    const roundIDs = ids.filter((id) => id.startsWith(round + '-A'));
    for (let i = 0; i < roundIDs.length; i++) {
      assert.equal(roundIDs[i], `${round}-A${String(i + 1).padStart(2, '0')}`);
    }
  }
});

test('mutation-coverage: required variant IDs exactly match the catalog', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const variantIDs = cat.attacks.flatMap((a) => a.variants.map((v) => v.id));
  assert.deepEqual(variantIDs, EXPECTED_VARIANT_IDS);
  assert.deepEqual(REQUIRED_VARIANT_IDS, EXPECTED_VARIANT_IDS);
  // No duplicates.
  assert.equal(new Set(variantIDs).size, variantIDs.length);
});

test('mutation-coverage: every attack selects >=1 family from the closed set and owns a non-empty variant array', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  for (const a of cat.attacks) {
    assert.ok(Array.isArray(a.families) && a.families.length > 0, `${a.id} must select >=1 family`);
    for (const f of a.families) {
      assert.ok(EXPECTED_FAMILIES.includes(f), `${a.id} selects unknown family ${f}`);
    }
    assert.equal(new Set(a.families).size, a.families.length, `${a.id} multiply selects a family`);
    assert.ok(Array.isArray(a.variants) && a.variants.length > 0, `${a.id} must own a non-empty variant array`);
  }
});

test('mutation-coverage: every variant has a non-empty expectedFindings array, a valid owning command, and references only production rules', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const ruleSet = new Set(PRODUCTION_RULES);
  for (const a of cat.attacks) {
    for (const v of a.variants) {
      assert.ok(Array.isArray(v.expectedFindings) && v.expectedFindings.length > 0,
        `${v.id} must declare a non-empty expectedFindings array`);
      for (const fid of v.expectedFindings) {
        assert.ok(ruleSet.has(fid), `${v.id} references unknown finding ${fid}`);
      }
      assert.equal(typeof v.owningCommand, 'string');
      assert.ok(v.owningCommand.length > 0, `${v.id} must declare an owning command`);
      assert.ok(typeof v.payloadHash === 'string' && v.payloadHash.length > 0, `${v.id} must declare a payload hash`);
      assert.equal(v.resolutionCommit, null, `${v.id} must have resolutionCommit null`);
    }
  }
});

test('mutation-coverage: every production rule has >=1 negative fixture and >=1 positive control', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const negByRule = new Map();
  const addNeg = (fid, id) => { if (!negByRule.has(fid)) negByRule.set(fid, []); negByRule.get(fid).push(id); };
  for (const a of cat.attacks) for (const v of a.variants) for (const fid of v.expectedFindings) addNeg(fid, v.id);
  for (const nf of (cat.negativeFixtures ?? [])) {
    for (const fid of nf.expectedFindings) addNeg(fid, nf.id);
    if (nf.ruleID) addNeg(nf.ruleID, nf.id);
  }
  for (const rule of PRODUCTION_RULES) {
    assert.ok(negByRule.has(rule) && negByRule.get(rule).length > 0,
      `production rule ${rule} has no negative fixture`);
  }
  const posByRule = new Set();
  for (const pc of cat.positiveControls) posByRule.add(pc.ruleID);
  for (const rule of PRODUCTION_RULES) {
    assert.ok(posByRule.has(rule), `production rule ${rule} has no positive control`);
  }
});

test('mutation-coverage: positive control IDs are unique and reference real rules', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const ruleSet = new Set(PRODUCTION_RULES);
  const seen = new Set();
  assert.equal(cat.positiveControls.length, PRODUCTION_RULES.length);
  for (const pc of cat.positiveControls) {
    assert.ok(!seen.has(pc.id), `duplicate positive control ${pc.id}`);
    seen.add(pc.id);
    assert.ok(ruleSet.has(pc.ruleID), `${pc.id} references unknown rule ${pc.ruleID}`);
  }
});

test('mutation-coverage: negativeFixtures reference real rules and have non-empty expectedFindings', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const ruleSet = new Set(PRODUCTION_RULES);
  for (const nf of cat.negativeFixtures ?? []) {
    assert.ok(ruleSet.has(nf.ruleID), `${nf.id} references unknown rule ${nf.ruleID}`);
    assert.ok(Array.isArray(nf.expectedFindings) && nf.expectedFindings.length > 0, `${nf.id} needs expectedFindings`);
  }
});

test('mutation-coverage: auditMutationCoverage returns zero findings on the committed catalog', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const findings = auditMutationCoverage(PRODUCTION_RULES, cat);
  assert.equal(findings.length, 0, findings.map((f) => f.message).join('; '));
});

test('mutation-coverage: committed catalog hash matches the sealed catalog', () => {
  const committed = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const sealed = buildSealedCatalog();
  assert.equal(committed.catalogHash, sealed.catalogHash);
  const { catalogHash, ...rest } = committed;
  assert.equal(catalogHash, hashCatalog(rest));
});

test('mutation-coverage: auditMutationCoverage rejects a missing family', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const bad = { ...cat, families: cat.families.slice(0, 34) };
  assert.notEqual(auditMutationCoverage(PRODUCTION_RULES, bad).length, 0);
});

test('mutation-coverage: auditMutationCoverage rejects a duplicate variant ID', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const bad = structuredClone(cat);
  bad.attacks[0].variants[0].id = bad.attacks[0].variants[1]?.id ?? 'R1-A01.V02';
  assert.notEqual(auditMutationCoverage(PRODUCTION_RULES, bad).length, 0);
});

test('mutation-coverage: auditMutationCoverage rejects an unknown finding in a variant', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const bad = structuredClone(cat);
  bad.attacks[0].variants[0].expectedFindings = ['PLAN_NONEXISTENT_RULE'];
  assert.notEqual(auditMutationCoverage(PRODUCTION_RULES, bad).length, 0);
});

test('mutation-coverage: auditMutationCoverage rejects a rule with no negative fixture', () => {
  const cat = JSON.parse(fs.readFileSync(FIXTURES_PATH, 'utf8'));
  const bad = structuredClone(cat);
  // Remove every fixture for the first production rule.
  const rule = PRODUCTION_RULES[0];
  for (const a of bad.attacks) for (const v of a.variants) v.expectedFindings = v.expectedFindings.filter((f) => f !== rule);
  bad.negativeFixtures = bad.negativeFixtures.filter((nf) => nf.ruleID !== rule);
  assert.notEqual(auditMutationCoverage(PRODUCTION_RULES, bad).length, 0);
});

test('mutation-coverage: --verify-only on a missing review file exits 1', () => {
  const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
  const runner = path.resolve(__dirname, '..', '..', '..', '..', '..', '..', 'Tools', 'G6PlanAuthoring', 'run-adversarial-round.mjs');
  const missing = path.join(os.tmpdir(), 'g6r-nonexistent-review-' + process.pid + '.md');
  const r = spawnSync(NODE, [runner, '--round', 'R1', '--review', missing, '--verify-only'], { encoding: 'utf8' });
  assert.equal(r.status, 1, `expected exit 1 for missing review file, got ${r.status}: ${r.stdout}\n${r.stderr}`);
  assert.match(r.stdout, /G6_ADVERSARIAL_RECORD_MISSING/);
});
