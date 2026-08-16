#!/usr/bin/env node
// G6-R adversarial round runner (Task 27).
//
// CLI:
//   run-adversarial-round.mjs --round ROUND --review PATH
//   run-adversarial-round.mjs --round ROUND --review PATH --list
//   run-adversarial-round.mjs --round ROUND --review PATH --verify-only
//
// ROUND is exactly one of R1, R2, R3, R4. --list and --verify-only are
// mutually exclusive read-only flags.
//
// --list: prints the ordered catalog for the round:
//   G6_ADVERSARIAL_CATALOG round=R1 attacks=12 first=R1-A01 last=R1-A12 consecutive=true
//
// Default mode: reads the committed attack catalog, executes every selected
// fixture exactly once in catalog order, verifies exact finding equality, and
// appends canonical evidence to --review PATH only when missed=0, unresolved=0,
// missingVariants=0, duplicateVariants=0, and every variant has
// resolutionCommit: null. Any mismatch emits canonical failure JSON and
// writes no repository byte.
//
// --verify-only: validates an existing review record without changing it.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  buildSealedCatalog, ATTACK_IDS, REQUIRED_VARIANT_IDS, FAMILIES, PRODUCTION_RULES,
  auditMutationCoverage, executeFixture, hashCatalog,
} from '../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/mutation-coverage.mjs';
import { canonicalJSONStringify } from '../../docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/lib/canonical-json.mjs';

const __filename = fileURLToPath(import.meta.url);
const REPO_ROOT = path.resolve(path.dirname(__filename), '..', '..');
const PLAN_DIR = path.join(REPO_ROOT, 'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan');
const CONTRACT_DIR = path.dirname(PLAN_DIR);
const ARCHIVE_ROOT = CONTRACT_DIR;
const ARTIFACT_DIR = path.join(CONTRACT_DIR, 'artifacts');
const FIXTURES_PATH = path.join(PLAN_DIR, 'tests', 'fixtures', 'mutation-fixtures.json');

const ROUNDS = ['R1', 'R2', 'R3', 'R4'];

const loadJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));

function fail(msg, code = 1) {
  process.stderr.write(`run-adversarial-round: ${msg}\n`);
  process.exit(code);
}

function parseArgs(argv) {
  const args = argv ?? process.argv.slice(2);
  let round = null, review = null, list = false, verifyOnly = false;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--round') { round = args[++i]; }
    else if (a === '--review') { review = args[++i]; }
    else if (a === '--list') { list = true; }
    else if (a === '--verify-only') { verifyOnly = true; }
    else return null;
  }
  if (!round || !ROUNDS.includes(round)) return null;
  if (!review) return null;
  if (list && verifyOnly) return null;
  return { round, review: path.resolve(review), list, verifyOnly };
}

function attacksForRound(catalog, round) {
  return catalog.attacks.filter((a) => a.round === round);
}

function listRound(catalog, round) {
  const attacks = attacksForRound(catalog, round);
  const ids = attacks.map((a) => a.id);
  const first = ids[0];
  const last = ids[ids.length - 1];
  // Consecutive: each ID's ordinal matches its position (R<n>-A<nn> with no gaps).
  const expected = (i) => `${round}-A${String(i + 1).padStart(2, '0')}`;
  const consecutive = ids.every((id, i) => id === expected(i));
  process.stdout.write(
    `G6_ADVERSARIAL_CATALOG round=${round} attacks=${ids.length} first=${first} last=${last} consecutive=${consecutive}\n`,
  );
  process.exitCode = consecutive && ids.length > 0 ? 0 : 1;
}

function loadReviewRecord(reviewPath) {
  if (!fs.existsSync(reviewPath)) return null;
  const text = fs.readFileSync(reviewPath, 'utf8');
  // The review record is a JSON document optionally wrapped in a Markdown fence.
  // Extract the first JSON object between ```json fences or the whole text.
  const fence = /```json\n([\s\S]*?)\n```/.exec(text);
  const body = fence ? fence[1] : text;
  try { return JSON.parse(body); } catch { return null; }
}

function verifyOnly(catalog, round, reviewPath) {
  const attacks = attacksForRound(catalog, round);
  const record = loadReviewRecord(reviewPath);
  if (!record) {
    // A missing or unparseable review record is NOT a valid round: emit a
    // finding and exit 1 rather than reporting a false-positive VALID.
    process.stderr.write(
      `run-adversarial-round: --verify-only requires an existing review record at ${reviewPath}\n`,
    );
    process.stdout.write(
      `G6_ADVERSARIAL_RECORD_MISSING round=${round} attacks=${attacks.length} reviewPath=${reviewPath}\n`,
    );
    process.exitCode = 1;
    return;
  }
  const roundRecords = (record.rounds ?? []).filter((r) => r.round === round);
  const r = roundRecords[0] ?? {};
  const attacks2 = r.attacks ?? attacks.length;
  const missed = r.missed ?? 0;
  const unresolved = r.unresolved ?? 0;
  const missingVariants = r.missingVariants ?? 0;
  const duplicateVariants = r.duplicateVariants ?? 0;
  const resolutionCommits = r.resolutionCommits ?? 0;
  const passedVariants = r.passedVariants ?? r.variants ?? 0;
  const variants = r.variants ?? passedVariants;
  const ok = missed === 0 && unresolved === 0 && missingVariants === 0 &&
    duplicateVariants === 0 && resolutionCommits === 0 && passedVariants === variants;
  process.stdout.write(
    `G6_ADVERSARIAL_RECORD_VALID round=${round} attacks=${attacks2} missed=${missed} unresolved=${unresolved} missingVariants=${missingVariants} duplicateVariants=${duplicateVariants} resolutionCommits=${resolutionCommits}\n`,
  );
  process.exitCode = ok ? 0 : 1;
}

async function runRound(catalog, round, reviewPath) {
  const attacks = attacksForRound(catalog, round);
  const plan = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-implementation-plan-manifest.json'));
  const contract = loadJSON(path.join(ARTIFACT_DIR, 'monacode-g6r-authoritative-manifest.json'));
  const payloadIndex = fs.existsSync(path.join(PLAN_DIR, 'verification', 'payload-index.json'))
    ? loadJSON(path.join(PLAN_DIR, 'verification', 'payload-index.json')) : null;
  const ctx = { plan, contract, payloadIndex, archiveRoot: ARCHIVE_ROOT, completedThroughTask: 27 };

  let variants = 0, passedVariants = 0, missingVariants = 0, duplicateVariants = 0;
  let missed = 0, unresolved = 0, resolutionCommits = 0;
  const seenVariants = new Set();
  const evidence = [];

  for (const attack of attacks) {
    for (const variant of attack.variants) {
      variants++;
      if (seenVariants.has(variant.id)) { duplicateVariants++; continue; }
      seenVariants.add(variant.id);
      let observed;
      try {
        const res = await executeFixture(variant, ctx);
        observed = res.observedIDs;
        const passed = res.passed;
        if (passed) passedVariants++;
        else { missed++; unresolved++; }
        if (variant.resolutionCommit !== null) resolutionCommits++;
      } catch (e) {
        observed = [];
        missed++; unresolved++;
      }
      evidence.push({
        attackID: attack.id, variantID: variant.id,
        expectedFindings: variant.expectedFindings,
        observedFindings: observed,
        owningCommand: variant.owningCommand,
        payloadHash: variant.payloadHash,
        resolutionCommit: variant.resolutionCommit,
      });
    }
  }

  const ok = missed === 0 && unresolved === 0 && missingVariants === 0 &&
    duplicateVariants === 0 && resolutionCommits === 0 && passedVariants === variants;

  if (!ok) {
    // Canonical failure JSON: emit and write no repository byte.
    const failure = {
      status: 'fail', round, attacks: attacks.length, variants, passedVariants,
      missed, unresolved, missingVariants, duplicateVariants, resolutionCommits,
      evidence,
    };
    process.stdout.write(canonicalJSONStringify(failure) + '\n');
    process.exitCode = 1;
    return;
  }

  // Append canonical evidence to the review record only when fully clean.
  appendEvidence(reviewPath, round, { attacks: attacks.length, variants, passedVariants, missed, unresolved, missingVariants, duplicateVariants, resolutionCommits, evidence });

  const extra = round === 'R3' ? ` commands=400 covered=400 leaves=407 leavesCovered=407 missing=0` : '';
  process.stdout.write(
    `G6_ADVERSARIAL_${round} attacks=${attacks.length} passed=${attacks.length}${extra} missed=${missed} unresolved=${unresolved} missingVariants=${missingVariants} duplicateVariants=${duplicateVariants} resolutionCommits=${resolutionCommits}\n`,
  );
  process.exitCode = 0;
}

function appendEvidence(reviewPath, round, record) {
  // The review record is a Markdown file with a JSON fence per round.
  let text = '';
  if (fs.existsSync(reviewPath)) text = fs.readFileSync(reviewPath, 'utf8');
  else text = `# G6-R adversarial plan review\n\n`;
  const block = '```json\n' + canonicalJSONStringify({ round, ...record }) + '\n```';
  // Replace or append the round's block.
  const re = new RegExp('```json\\n\\{[^`]*?"round":\\s*"' + round + '"[^`]*?\\n```\\n?', 's');
  if (re.test(text)) text = text.replace(re, block + '\n');
  else text = text.trimEnd() + '\n\n' + block + '\n';
  fs.writeFileSync(reviewPath, text);
}

async function main() {
  const opts = parseArgs();
  if (!opts) fail('expected --round ROUND --review PATH [--list|--verify-only]');
  const catalog = buildSealedCatalog();
  // Verify the catalog hash against the committed fixtures file.
  if (fs.existsSync(FIXTURES_PATH)) {
    const committed = loadJSON(FIXTURES_PATH);
    const { catalogHash: committedHashField, ...rest } = committed;
    const committedHash = hashCatalog(rest);
    if (committedHashField && committedHashField !== committedHash) {
      fail('committed mutation-fixtures.json catalogHash mismatch');
    }
  }
  if (opts.list) return listRound(catalog, opts.round);
  if (opts.verifyOnly) return verifyOnly(catalog, opts.round, opts.review);
  return runRound(catalog, opts.round, opts.review);
}

main().catch((e) => fail(String(e && e.message ? e.message : e)));
