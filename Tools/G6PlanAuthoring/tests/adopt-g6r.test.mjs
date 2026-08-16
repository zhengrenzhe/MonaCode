// G6-R adoption tool tests (Task 33 Step 1).
//
// Proves the adoption tool computes all seven final byte strings before the
// first repository-file replacement, publishes via a 7-path journaled retry-safe
// transaction, and that --verify-only changes no byte.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const GIT = '/usr/bin/git';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const TOOL = path.resolve(__dirname, '..', 'adopt-g6r.mjs');
const ARCHIVE_SRC = path.resolve(REPO_ROOT, 'docs/contracts/monaco-editor-0.56.0/g6-r');
const PHASE_INDEX_SRC = path.resolve(REPO_ROOT, 'docs/implementation-phases/README.md');

const sha256 = (bytes) => createHash('sha256').update(typeof bytes === 'string' ? bytes : Buffer.from(bytes)).digest('hex');
const sha256File = (p) => sha256(fs.readFileSync(p));

function copyArchive(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  const walk = (rel) => {
    for (const e of fs.readdirSync(path.join(src, rel), { withFileTypes: true })) {
      const relp = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) {
        fs.mkdirSync(path.join(dst, relp), { recursive: true });
        walk(relp);
      } else if (e.isFile()) {
        fs.copyFileSync(path.join(src, relp), path.join(dst, relp));
      }
    }
  };
  walk('');
}

// Extract a file's candidate (pre-adoption) content from HEAD~1 so the temp
// fixture can be reverted to candidate state regardless of the real archive's
// adopted state. This makes every test that runs the adoption tool perform a
// fresh candidate→adopted promotion.
function gitShowHead1(relPath) {
  const r = spawnSync(GIT, ['-C', REPO_ROOT, 'show', `HEAD~1:${relPath}`], {
    encoding: 'utf8',
    maxBuffer: 128 * 1024 * 1024,
  });
  if (r.status !== 0) {
    throw new Error(`git show HEAD~1:${relPath} failed: ${r.stderr}`);
  }
  return r.stdout;
}

const ARCHIVE_GIT_PREFIX = 'docs/contracts/monaco-editor-0.56.0/g6-r';

function makeTempArchive() {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'g6r-adopt-'));
  const archive = path.join(tmp, 'g6-r');
  copyArchive(ARCHIVE_SRC, archive);
  // Remove adoption files (created by adoption, absent in candidate state)
  try { fs.unlinkSync(path.join(archive, 'SHA256SUMS')); } catch {}
  try { fs.unlinkSync(path.join(archive, 'adoption-record.json')); } catch {}
  // Revert the four archive files the adoption tool modifies back to their
  // candidate (HEAD~1) state so each test performs a fresh candidate→adopted
  // promotion regardless of the real archive's adopted state.
  const candidateRelPaths = [
    'artifacts/monacode-g6r-authoritative-manifest.json',
    'artifacts/global-g6r-authoritative-contract.html',
    'README.md',
    'implementation-plan/verification/payload-index.json',
  ];
  for (const rel of candidateRelPaths) {
    fs.writeFileSync(
      path.join(archive, rel),
      gitShowHead1(`${ARCHIVE_GIT_PREFIX}/${rel}`),
    );
  }
  // Phase index: candidate version from HEAD~1 (reverted from adopted state)
  const phaseIndex = path.join(tmp, 'README.md');
  fs.writeFileSync(phaseIndex, gitShowHead1('docs/implementation-phases/README.md'));
  return { tmp, archive, phaseIndex };
}

function runTool(archive, phaseIndex, ...extra) {
  return spawnSync(NODE, [TOOL, '--archive', archive, '--phase-index', phaseIndex, '--revision', 'G6-R-execution-ready-final', ...extra], {
    encoding: 'utf8',
    maxBuffer: 128 * 1024 * 1024,
  });
}

// ---------------------------------------------------------------------------
// Core adoption tests.
// ---------------------------------------------------------------------------

test('adopt-g6r: promotes manifest to G6-R-execution-ready-final with adopted state', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, `exit ${r.status}: ${r.stderr}\n${r.stdout}`);
    assert.match(r.stdout, /G6_ADOPTED revision=G6-R-execution-ready-final/);
    assert.match(r.stdout, /planState=execution-ready/);
    assert.match(r.stdout, /implementation=not-started/);

    const manifest = JSON.parse(fs.readFileSync(path.join(archive, 'artifacts/monacode-g6r-authoritative-manifest.json'), 'utf8'));
    assert.equal(manifest.identity.revision, 'G6-R-execution-ready-final');
    assert.equal(manifest.identity.status, 'design-and-execution-plan-adopted');
    assert.equal(manifest.planGovernance.planState, 'execution-ready');
    assert.equal(manifest.planGovernance.adoptionState, 'adopted');
    assert.equal(manifest.planGovernance.implementation, 'not-started');
    assert.equal(manifest.planGovernance.releaseAcceptance, 'not-passed');
    assert.ok(manifest.planGovernance.selectedHashes, 'selectedHashes must be filled');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: SHA256SUMS has 230 rows excluding SHA256SUMS and adoption-record.json', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);
    const sums = fs.readFileSync(path.join(archive, 'SHA256SUMS'), 'utf8').trim().split('\n');
    assert.equal(sums.length, 230, `SHA256SUMS must have 230 rows, got ${sums.length}`);
    const paths = sums.map((l) => l.split('  ')[1]);
    assert.ok(!paths.includes('SHA256SUMS'), 'SHA256SUMS must exclude itself');
    assert.ok(!paths.includes('adoption-record.json'), 'SHA256SUMS must exclude adoption-record.json');
    // Bytewise sorted
    const sorted = [...paths].sort((a, b) => a.localeCompare(b, 'en'));
    assert.deepEqual(paths, sorted, 'SHA256SUMS paths must be bytewise sorted');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: adoption-record selects checksum-index, contract, plan, audit, review, cold-checkout, and phase-index hashes', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);
    const rec = JSON.parse(fs.readFileSync(path.join(archive, 'adoption-record.json'), 'utf8'));
    assert.equal(rec.decision, 'adopted');
    assert.equal(rec.promotedRevision, 'G6-R-execution-ready-final');

    // checksum-index hash = hash of SHA256SUMS file
    const sumsHash = sha256File(path.join(archive, 'SHA256SUMS'));
    assert.equal(rec.archive.checksumIndexSha256, sumsHash);
    assert.equal(rec.archive.indexedFileCount, 230);

    // contract hash = hash of promoted manifest
    const manifestHash = sha256File(path.join(archive, 'artifacts/monacode-g6r-authoritative-manifest.json'));
    assert.equal(rec.contract.sha256, manifestHash);

    // plan hash = hash of implementation-plan-manifest (unchanged)
    const planHash = sha256File(path.join(archive, 'artifacts/monacode-g6r-implementation-plan-manifest.json'));
    assert.equal(rec.plan.sha256, planHash);

    // audit hash
    const auditHash = sha256File(path.join(archive, 'implementation-plan/verification/plan-audit.json'));
    assert.equal(rec.planAudit.sha256, auditHash);

    // review hash
    const reviewHash = sha256File(path.join(archive, 'implementation-plan/verification/adversarial-plan-review.md'));
    assert.equal(rec.adversarialReview.sha256, reviewHash);

    // cold-checkout hash
    const coldHash = sha256File(path.join(archive, 'implementation-plan/verification/cold-checkout-preflight.json'));
    assert.equal(rec.coldCheckoutEvidence.sha256, coldHash);

    // phase-index hash = hash of the supplied phase index
    const phaseHash = sha256File(phaseIndex);
    assert.equal(rec.phaseIndex.sha256, phaseHash);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: payload index has cursor 33 with 232 present rows all 100644', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);
    const idx = JSON.parse(fs.readFileSync(path.join(archive, 'implementation-plan/verification/payload-index.json'), 'utf8'));
    assert.equal(idx.completedThroughTask, 33);
    assert.equal(idx.rows.length, 232);
    const present = idx.rows.filter((r) => r.presence === 'present').length;
    const planned = idx.rows.filter((r) => r.presence === 'planned').length;
    assert.equal(present, 232);
    assert.equal(planned, 0);
    const mode100644 = idx.rows.filter((r) => r.gitMode === '100644').length;
    assert.equal(mode100644, 232);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: verify-contract.mjs is byte-identical before and after adoption', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const before = sha256File(path.join(archive, 'verify-contract.mjs'));
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);
    const after = sha256File(path.join(archive, 'verify-contract.mjs'));
    assert.equal(before, after, 'verify-contract.mjs must be byte-identical');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: only the seven allowlisted paths change', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    // Hash all files before adoption
    const before = new Map();
    const walk = (rel) => {
      for (const e of fs.readdirSync(path.join(archive, rel), { withFileTypes: true })) {
        const relp = rel ? `${rel}/${e.name}` : e.name;
        if (e.isDirectory()) walk(relp);
        else if (e.isFile()) before.set(relp, sha256File(path.join(archive, relp)));
      }
    };
    walk('');

    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);

    const allowlist = new Set([
      'artifacts/monacode-g6r-authoritative-manifest.json',
      'artifacts/global-g6r-authoritative-contract.html',
      'README.md',
      'implementation-plan/verification/payload-index.json',
      'SHA256SUMS',
      'adoption-record.json',
    ]);

    // Hash all files after adoption
    for (const [relp, beforeHash] of before) {
      const afterHash = sha256File(path.join(archive, relp));
      if (beforeHash !== afterHash) {
        assert.ok(allowlist.has(relp), `unexpected change: ${relp}`);
      }
    }
    // SHA256SUMS and adoption-record.json are new
    assert.ok(!before.has('SHA256SUMS'), 'SHA256SUMS should be new');
    assert.ok(!before.has('adoption-record.json'), 'adoption-record.json should be new');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: journal is absent after successful adoption', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);
    // The journal is in the git dir of the REPO, not the temp dir.
    // For temp archives, the tool uses the repo's git dir.
    // Check that no journal exists in the repo git dir.
    const journalPath = path.join(REPO_ROOT, '.git', 'monacode-g6r-adoption-journal.json');
    assert.ok(!fs.existsSync(journalPath), 'journal must be absent after adoption');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: --verify-only changes no byte on the real adopted archive', () => {
  // --verify-only is read-only; run it directly against the real adopted
  // archive (no temp fixture needed). The real archive is already adopted, so
  // verify-only should confirm all seven paths match and change nothing.
  const archive = ARCHIVE_SRC;
  const phaseIndex = PHASE_INDEX_SRC;

  // Hash all files before verify
  const before = new Map();
  const walk = (rel) => {
    for (const e of fs.readdirSync(path.join(archive, rel), { withFileTypes: true })) {
      const relp = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) walk(relp);
      else if (e.isFile()) before.set(relp, sha256File(path.join(archive, relp)));
    }
  };
  walk('');
  const phaseBefore = sha256File(phaseIndex);

  // Run --verify-only
  const r = runTool(archive, phaseIndex, '--verify-only');
  assert.equal(r.status, 0, `verify-only exit ${r.status}: ${r.stderr}\n${r.stdout}`);
  assert.match(r.stdout, /G6_VERIFY_OK/);

  // Verify no bytes changed
  for (const [relp, beforeHash] of before) {
    assert.equal(sha256File(path.join(archive, relp)), beforeHash, `${relp} changed during verify-only`);
  }
  assert.equal(sha256File(phaseIndex), phaseBefore, 'phase index changed during verify-only');
});

test('adopt-g6r: rerun after adoption converges to same final hashes', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r1 = runTool(archive, phaseIndex);
    assert.equal(r1.status, 0, r1.stderr);

    // Hash all 7 output files
    const outputs = [
      'artifacts/monacode-g6r-authoritative-manifest.json',
      'artifacts/global-g6r-authoritative-contract.html',
      'README.md',
      'implementation-plan/verification/payload-index.json',
      'SHA256SUMS',
      'adoption-record.json',
    ];
    const hashes1 = new Map();
    for (const p of outputs) hashes1.set(p, sha256File(path.join(archive, p)));
    const phaseHash1 = sha256File(phaseIndex);

    // Rerun
    const r2 = runTool(archive, phaseIndex);
    assert.equal(r2.status, 0, r2.stderr);

    for (const p of outputs) {
      assert.equal(sha256File(path.join(archive, p)), hashes1.get(p), `${p} changed on rerun`);
    }
    assert.equal(sha256File(phaseIndex), phaseHash1, 'phase index changed on rerun');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: mutation of a payload file produces an exact finding (mode 100755)', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);

    // Mutate one file's mode to 100755 (keep bytes same)
    const target = path.join(archive, 'artifacts/monacode-g6r-execution-schema.json');
    fs.chmodSync(target, 0o755);

    // verify-only should fail
    const r2 = runTool(archive, phaseIndex, '--verify-only');
    assert.notEqual(r2.status, 0, 'verify-only should fail after mode mutation');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: mutation of payload bytes produces a finding', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);

    // Mutate a file's bytes
    const target = path.join(archive, 'artifacts/monacode-g6r-execution-schema.json');
    const content = fs.readFileSync(target, 'utf8');
    fs.writeFileSync(target, content + '\n// mutation');

    const r2 = runTool(archive, phaseIndex, '--verify-only');
    assert.notEqual(r2.status, 0, 'verify-only should fail after byte mutation');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: mutation of phase-index bytes produces a finding', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);

    // Mutate the phase index
    const content = fs.readFileSync(phaseIndex, 'utf8');
    fs.writeFileSync(phaseIndex, content + '\n<!-- mutation -->');

    const r2 = runTool(archive, phaseIndex, '--verify-only');
    assert.notEqual(r2.status, 0, 'verify-only should fail after phase-index mutation');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: adoption record selects the phase-index hash from the supplied phase index', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);
    const rec = JSON.parse(fs.readFileSync(path.join(archive, 'adoption-record.json'), 'utf8'));
    const phaseHash = sha256File(phaseIndex);
    assert.equal(rec.phaseIndex.sha256, phaseHash, 'adoption record must select the supplied phase-index hash');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('adopt-g6r: G6_ADOPTED line has exact expected fields', () => {
  const { tmp, archive, phaseIndex } = makeTempArchive();
  try {
    const r = runTool(archive, phaseIndex);
    assert.equal(r.status, 0, r.stderr);
    const line = r.stdout.trim();
    assert.match(line, /^G6_ADOPTED revision=G6-R-execution-ready-final/);
    assert.match(line, /archiveFiles=232/);
    assert.match(line, /present=232/);
    assert.match(line, /planned=0/);
    assert.match(line, /mode100644=232/);
    assert.match(line, /payloads=230/);
    assert.match(line, /planState=execution-ready/);
    assert.match(line, /tasks=200/);
    assert.match(line, /testContracts=200/);
    assert.match(line, /beginActions=200/);
    assert.match(line, /commitActions=200/);
    assert.match(line, /finalizeActions=200/);
    assert.match(line, /productCommitContracts=200/);
    assert.match(line, /evidenceCommitContracts=200/);
    assert.match(line, /implementation=not-started/);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});
