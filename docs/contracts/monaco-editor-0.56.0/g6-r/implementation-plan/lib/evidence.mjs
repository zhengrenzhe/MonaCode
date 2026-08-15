// G6-R evidence-truth module.
// Repository-owned, dependency-free. Implements selectEvidenceCommit: the
// fail-closed first-parent evidence selector that proves a product commit is
// on repoHead's first-parent ancestry, selects its immediate first-parent
// successor as the evidence commit, and rejects any later first-parent commit
// touching the evidence path (including a modify-then-restore sequence).
//
// selectEvidenceCommit uses ONLY the following locked /usr/bin/git argument
// arrays (the injected `git` runner executes /usr/bin/git with them; tests
// inject a synthetic runner over the same arrays):
//   ['rev-list','--first-parent', repoHead]
//   ['rev-list','--first-parent', `${productCommit}..${repoHead}`]
//   ['show','-s','--format=%P', evidenceCommit]
//   ['show','-s','--format=%an%n%ae%n%cn%n%ce%n%s', evidenceCommit]
//   ['diff-tree','-r','--no-commit-id','--name-only', evidenceCommit]
//   ['cat-file','blob', `${evidenceCommit}:${evidencePath}`]
//   ['rev-list','--first-parent', `${evidenceCommit}..${repoHead}`, '--', evidencePath]
//
// Every failure is fail-closed: the selector returns ok=false with exactly one
// stable finding ID so evidence validation is deterministic across runs.

import { createHash } from 'node:crypto';
import { makeFinding, sortFindings } from './findings.mjs';

// ---------------------------------------------------------------------------
// Closed evidence finding-id set
// ---------------------------------------------------------------------------

export const EVIDENCE_FINDING_IDS = [
  'PLAN_EVIDENCE_PRODUCT_ANCESTRY',   // productCommit not on repoHead first-parent ancestry
  'PLAN_EVIDENCE_IMMEDIATE_SUCCESSOR',// no immediate first-parent successor of productCommit
  'PLAN_EVIDENCE_COMMIT_PARENT',      // evidence commit sole parent != productCommit
  'PLAN_EVIDENCE_COMMIT_IDENTITY',    // evidence commit author/committer wrong
  'PLAN_EVIDENCE_COMMIT_SUBJECT',     // evidence commit subject wrong / taskID mismatch
  'PLAN_EVIDENCE_COMMIT_BOUNDARY',    // evidence commit diff != exactly the evidence path
  'PLAN_EVIDENCE_BLOB',               // evidence blob bytes != bytes under validation
  'PLAN_EVIDENCE_LATER_TOUCH',        // a later first-parent commit touches the evidence path
];

// ---------------------------------------------------------------------------
// Identity + subject contract
// ---------------------------------------------------------------------------

const IDENTITY = { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' };
const EVIDENCE_MSG_RE = /^evidence\(monacode\): complete (P[0-9]{2}-T[0-9]{3})$/;
const HEX40_RE = /^[0-9a-f]{40}$/;

function sha256hex(text) {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

// ---------------------------------------------------------------------------
// git output parsers
// ---------------------------------------------------------------------------

function parseLines(stdout) {
  if (!stdout) return [];
  return stdout.split('\n').filter((l) => l.length > 0);
}

function parseParents(stdout) {
  if (!stdout) return [];
  return stdout.trim().split(/\s+/).filter((h) => HEX40_RE.test(h));
}

// ---------------------------------------------------------------------------
// selectEvidenceCommit
// ---------------------------------------------------------------------------

/**
 * Prove the evidence-truth contract for one task's dependency evidence.
 *
 * @param {{
 *   repoHead: string,
 *   productCommit: string,
 *   evidencePath: string,
 *   git: (args: string[]) => { stdout: string, stderr: string, status: number },
 *   taskID?: string,
 *   expectedEvidenceSha256?: string,
 * }} input
 * @returns {{
 *   ok: boolean,
 *   evidenceCommit: string|null,
 *   evidenceBlobSha256: string|null,
 *   taskID: string|null,
 *   selectorMode: 'external-git',
 *   findings: ReturnType<typeof makeFinding>[],
 * }}
 */
export function selectEvidenceCommit({ repoHead, productCommit, evidencePath, git, taskID, expectedEvidenceSha256 }) {
  const findings = [];
  const fail = (id, message) => {
    findings.push(makeFinding({ id, category: 'semantic', taskID: taskID ?? null, path: evidencePath, message }));
    return { ok: false, evidenceCommit: null, evidenceBlobSha256: null, taskID: taskID ?? null, selectorMode: 'external-git', findings: sortFindings(findings) };
  };

  if (typeof git !== 'function') {
    return fail('PLAN_EVIDENCE_PRODUCT_ANCESTRY', 'git runner is required');
  }
  if (!HEX40_RE.test(repoHead || '') || !HEX40_RE.test(productCommit || '') || typeof evidencePath !== 'string' || evidencePath.length === 0) {
    return fail('PLAN_EVIDENCE_PRODUCT_ANCESTRY', 'repoHead, productCommit must be 40-hex and evidencePath non-empty');
  }

  // 1. Prove productCommit is on repoHead's first-parent ancestry.
  const ancestry = parseLines(git(['rev-list', '--first-parent', repoHead]).stdout);
  if (!ancestry.includes(productCommit)) {
    return fail('PLAN_EVIDENCE_PRODUCT_ANCESTRY', `product commit ${productCommit} is not on repoHead ${repoHead} first-parent ancestry`);
  }

  // 2. Enumerate productCommit..repoHead first-parent; chronological = reverse of rev-list output.
  const rangeRev = parseLines(git(['rev-list', '--first-parent', `${productCommit}..${repoHead}`]).stdout);
  if (rangeRev.length === 0) {
    return fail('PLAN_EVIDENCE_IMMEDIATE_SUCCESSOR', `no first-parent successor of product commit ${productCommit} before repoHead ${repoHead}`);
  }
  const chronological = [...rangeRev].reverse();
  const evidenceCommit = chronological[0]; // immediate first-parent successor

  // 3. The selected commit must have the product commit as its SOLE parent.
  const parents = parseParents(git(['show', '-s', '--format=%P', evidenceCommit]).stdout);
  if (parents.length !== 1 || parents[0] !== productCommit) {
    return fail('PLAN_EVIDENCE_COMMIT_PARENT', `evidence commit ${evidenceCommit} sole parent [${parents.join(',')}] != product commit ${productCommit}`);
  }

  // 4. Identity contract (author + committer).
  const idOut = git(['show', '-s', '--format=%an%n%ae%n%cn%n%ce%n%s', evidenceCommit]).stdout || '';
  const idLines = idOut.split('\n');
  const an = idLines[0] || '', ae = idLines[1] || '', cn = idLines[2] || '', ce = idLines[3] || '', subject = idLines.slice(4).join('\n').trim();
  if (an !== IDENTITY.name || ae !== IDENTITY.email || cn !== IDENTITY.name || ce !== IDENTITY.email) {
    return fail('PLAN_EVIDENCE_COMMIT_IDENTITY', `evidence commit ${evidenceCommit} identity ${an}<${ae}>/${cn}<${ce}> != zhengrenzhe contract`);
  }

  // 5. Subject contract + taskID binding.
  const m = EVIDENCE_MSG_RE.exec(subject);
  if (!m) {
    return fail('PLAN_EVIDENCE_COMMIT_SUBJECT', `evidence commit ${evidenceCommit} subject "${subject}" does not match evidence contract`);
  }
  const subjectTaskID = m[1];
  if (taskID !== undefined && taskID !== subjectTaskID) {
    return fail('PLAN_EVIDENCE_COMMIT_SUBJECT', `evidence commit ${evidenceCommit} subject references ${subjectTaskID} != expected ${taskID}`);
  }

  // 6. Boundary: the evidence commit changes EXACTLY the declared evidence path.
  const diffPaths = parseLines(git(['diff-tree', '-r', '--no-commit-id', '--name-only', evidenceCommit]).stdout);
  if (diffPaths.length !== 1 || diffPaths[0] !== evidencePath) {
    return fail('PLAN_EVIDENCE_COMMIT_BOUNDARY', `evidence commit ${evidenceCommit} diff [${diffPaths.join(',')}] != exactly [${evidencePath}]`);
  }

  // 7. Blob bytes match the bytes currently under validation.
  const blob = git(['cat-file', 'blob', `${evidenceCommit}:${evidencePath}`]);
  const blobContent = blob.stdout || '';
  const evidenceBlobSha256 = sha256hex(blobContent);
  if (expectedEvidenceSha256 !== undefined && evidenceBlobSha256 !== expectedEvidenceSha256) {
    return fail('PLAN_EVIDENCE_BLOB', `evidence blob sha256 ${evidenceBlobSha256} != expected ${expectedEvidenceSha256}`);
  }

  // 8. No later first-parent commit touches the evidence path (rejects modify / modify-then-restore).
  const later = parseLines(git(['rev-list', '--first-parent', `${evidenceCommit}..${repoHead}`, '--', evidencePath]).stdout);
  if (later.length !== 0) {
    return fail('PLAN_EVIDENCE_LATER_TOUCH', `${later.length} later first-parent commit(s) touch evidence path "${evidencePath}"`);
  }

  return {
    ok: true,
    evidenceCommit,
    evidenceBlobSha256,
    taskID: subjectTaskID,
    selectorMode: 'external-git',
    findings: [],
  };
}
