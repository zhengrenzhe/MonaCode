import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { posix, resolve } from 'node:path';

export const TASKS_BEGIN = '<!-- MONACODE_TASKS:BEGIN -->';
export const TASKS_END = '<!-- MONACODE_TASKS:END -->';
export const TASK_COLUMNS = [
  'ID',
  'State',
  'Deliverable',
  'Contract coverage',
  'Acceptance',
  'Evidence',
];
export const STATES = new Set(['TODO', 'IN PROGRESS', 'BLOCKED', 'DONE']);

const taskIDPattern =
  /^(MODEL|REGISTRY|EDITOR|COMMAND|RENDER|INPUT|LANG|DIFF|SERVICE|SURFACE|VERIFY|MOBILE)-\d{3}$/;

const addOnce = (findings, id, message, details = {}) => {
  if (!findings.some((finding) => finding.id === id)) {
    findings.push({ id, message, ...details });
  }
};

const tableCells = (line) => {
  if (!line.startsWith('|') || !line.endsWith('|')) return null;
  return line
    .slice(1, -1)
    .split('|')
    .map((cell) => cell.trim());
};

export function parseTaskLedger(markdown) {
  const findings = [];
  const beginCount = markdown.split(TASKS_BEGIN).length - 1;
  const endCount = markdown.split(TASKS_END).length - 1;
  const beginIndex = markdown.indexOf(TASKS_BEGIN);
  const endIndex = markdown.indexOf(TASKS_END);

  if (
    beginCount !== 1
    || endCount !== 1
    || beginIndex < 0
    || endIndex < beginIndex
  ) {
    findings.push({
      id: 'GOVERNANCE_MARKERS',
      message: `begin=${beginCount} end=${endCount}`,
    });
    return { rows: [], findings };
  }

  const block = markdown.slice(beginIndex + TASKS_BEGIN.length, endIndex);
  const lines = block
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.startsWith('|'));
  const header = tableCells(lines[0] ?? '');
  const separator = tableCells(lines[1] ?? '');

  if (
    JSON.stringify(header) !== JSON.stringify(TASK_COLUMNS)
    || separator?.length !== TASK_COLUMNS.length
    || !separator.every((cell) => /^:?-{3,}:?$/.test(cell))
  ) {
    findings.push({
      id: 'GOVERNANCE_COLUMNS',
      message: 'task table header or separator differs from the six-column schema',
    });
    return { rows: [], findings };
  }

  const rows = [];
  const seen = new Set();
  for (const line of lines.slice(2)) {
    const cells = tableCells(line);
    if (cells?.length !== TASK_COLUMNS.length) {
      addOnce(findings, 'GOVERNANCE_COLUMNS', 'task row does not contain six columns');
      continue;
    }
    const [id, state, deliverable, contractCoverage, acceptance, evidence] = cells;
    const row = {
      id,
      state,
      deliverable,
      contractCoverage,
      acceptance,
      evidence,
    };
    rows.push(row);

    if (!taskIDPattern.test(id)) {
      addOnce(findings, 'GOVERNANCE_TASK_ID_INVALID', `invalid task id: ${id}`);
    }
    if (seen.has(id)) {
      addOnce(findings, 'GOVERNANCE_TASK_ID_DUPLICATE', `duplicate task id: ${id}`);
    }
    seen.add(id);
    if (!STATES.has(state)) {
      addOnce(findings, 'GOVERNANCE_STATE_INVALID', `invalid state for ${id}: ${state}`);
    }
  }

  return { rows, findings };
}

export function validateEvidence({ state, evidence }) {
  const findings = [];
  if (state === 'TODO') {
    if (evidence !== '—') {
      findings.push({
        id: 'GOVERNANCE_TODO_EVIDENCE',
        message: 'TODO evidence must be an em dash',
      });
    }
    return findings;
  }
  if (state === 'IN PROGRESS') {
    const clauses = evidence.split('<br>');
    if (!/^change:.+/.test(clauses[0] ?? '')) {
      findings.push({
        id: 'GOVERNANCE_IN_PROGRESS_CHANGE',
        message: 'IN PROGRESS evidence requires change:<change-ref>',
      });
    }
    if (!/^owner:.+/.test(clauses[1] ?? '')) {
      findings.push({
        id: 'GOVERNANCE_IN_PROGRESS_OWNER',
        message: 'IN PROGRESS evidence requires owner:<owner>',
      });
    }
    return findings;
  }
  if (state === 'BLOCKED') {
    const clauses = evidence.split('<br>');
    if (!/^blocker:.+/.test(clauses[0] ?? '')) {
      findings.push({
        id: 'GOVERNANCE_BLOCKED_BLOCKER',
        message: 'BLOCKED evidence requires blocker:<evidence-ref>',
      });
    }
    if (!/^unblock:.+/.test(clauses[1] ?? '')) {
      findings.push({
        id: 'GOVERNANCE_BLOCKED_UNBLOCK',
        message: 'BLOCKED evidence requires unblock:<observable-condition>',
      });
    }
    return findings;
  }
  if (state === 'DONE') {
    const clauses = evidence.split('<br>');
    if (
      !/^digest:[0-9a-f]{64}$/.test(clauses[0] ?? '')
      || !/^source:.+/.test(clauses[1] ?? '')
      || !/^tests:.+/.test(clauses[2] ?? '')
      || !/^results:.+ sha256:[0-9a-f]{64}$/.test(clauses[3] ?? '')
      || clauses.length !== 4
    ) {
      findings.push({
        id: 'GOVERNANCE_DONE_EVIDENCE',
        message: 'DONE evidence does not match the four-clause grammar',
      });
    }
  }
  return findings;
}

export function buildCoverageCatalog(catalog) {
  const active = new Set(['governance:single-source']);
  for (const task of catalog.planTasks) {
    active.add(`plan:${task.id}/self`);
  }
  for (const identity of catalog.activeIdentities) active.add(identity);
  catalog.mobileScope.forEach((_, index) => {
    active.add(`mobile:${String(index).padStart(2, '0')}/self`);
  });
  for (const identity of catalog.laterIdentities) active.add(identity);
  return {
    active,
    cuts: new Set(catalog.cutIdentities),
  };
}

const resolveSelector = (selector, identities) => {
  if (selector.endsWith('/*') && selector.indexOf('*') === selector.length - 1) {
    const prefix = selector.slice(0, -1);
    return [...identities].filter((identity) => identity.startsWith(prefix));
  }
  if (selector.includes('*')) return [];
  return identities.has(selector) ? [selector] : [];
};

export function validateCoverage({ rows, catalog }) {
  const findings = [];
  const owners = new Map();

  for (const row of rows) {
    const selectors = row.contractCoverage
      .split('<br>')
      .map((selector) => selector.trim())
      .filter(Boolean);
    for (const selector of selectors) {
      const activeMatches = resolveSelector(selector, catalog.active);
      const cutMatches = resolveSelector(selector, catalog.cuts);
      if (activeMatches.length === 0 && cutMatches.length === 0) {
        addOnce(
          findings,
          'GOVERNANCE_SELECTOR_UNMATCHED',
          `selector matches no canonical identity: ${selector}`,
          { taskID: row.id, selector },
        );
      }
      if (cutMatches.length > 0) {
        addOnce(
          findings,
          'GOVERNANCE_CUT_ACTIVE',
          `selector claims accepted cut: ${selector}`,
          { taskID: row.id, selector },
        );
      }
      for (const identity of activeMatches) {
        const taskIDs = owners.get(identity) ?? [];
        taskIDs.push(row.id);
        owners.set(identity, taskIDs);
      }
    }
  }

  const duplicate = [...owners.entries()].find(([, taskIDs]) => taskIDs.length > 1);
  if (duplicate) {
    addOnce(
      findings,
      'GOVERNANCE_COVERAGE_DUPLICATE',
      `identity has multiple task owners: ${duplicate[0]}`,
      { identity: duplicate[0], taskIDs: duplicate[1] },
    );
  }
  const missing = [...catalog.active].find((identity) => !owners.has(identity));
  if (missing) {
    addOnce(
      findings,
      'GOVERNANCE_COVERAGE_MISSING',
      `identity has no task owner: ${missing}`,
      { identity: missing },
    );
  }

  return findings;
}

const markdownLinks = (text) => {
  const links = [];
  const pattern = /\[([^\]]+)\]\(([^)]+)\)/g;
  for (const match of text.matchAll(pattern)) {
    links.push({ label: match[1].trim(), target: match[2].trim() });
  }
  return links;
};

const repositoryPath = (target) => {
  const withoutAnchor = target.split('#', 1)[0].replace(/^<|>$/g, '');
  if (
    withoutAnchor.length === 0
    || withoutAnchor.startsWith('/')
    || /^[a-z][a-z0-9+.-]*:/i.test(withoutAnchor)
  ) {
    return null;
  }
  const normalized = posix.normalize(withoutAnchor);
  if (normalized === '..' || normalized.startsWith('../')) return null;
  return normalized;
};

export function validateDoneEvidence({
  row,
  currentDigest,
  repoRoot,
  trackedPaths,
}) {
  const findings = [];
  const clauses = row.evidence.split('<br>');
  const digest = /^digest:([0-9a-f]{64})$/.exec(clauses[0] ?? '')?.[1];
  if (digest !== currentDigest) {
    addOnce(
      findings,
      'GOVERNANCE_DONE_DIGEST_STALE',
      `DONE digest differs from current source set: ${digest ?? 'missing'}`,
    );
  }

  const links = markdownLinks(row.evidence);
  let missingLink = false;
  for (const link of links) {
    const path = repositoryPath(link.target);
    if (
      !link.label
      || !path
      || !trackedPaths.has(path)
      || !existsSync(resolve(repoRoot, path))
    ) {
      missingLink = true;
    }
  }
  if (links.length < 3 || missingLink) {
    addOnce(
      findings,
      'GOVERNANCE_DONE_LINK_MISSING',
      'DONE evidence contains an empty, untracked, unsafe, or missing link',
    );
  }

  const resultMatch = /^results:(.+) sha256:([0-9a-f]{64})$/.exec(clauses[3] ?? '');
  const resultLink = markdownLinks(resultMatch?.[1] ?? '')[0];
  const resultPath = resultLink ? repositoryPath(resultLink.target) : null;
  let actualHash = null;
  if (resultPath && trackedPaths.has(resultPath)) {
    try {
      actualHash = createHash('sha256')
        .update(readFileSync(resolve(repoRoot, resultPath)))
        .digest('hex');
    } catch {
      actualHash = null;
    }
  }
  if (!resultMatch || actualHash !== resultMatch[2]) {
    addOnce(
      findings,
      'GOVERNANCE_DONE_RESULT_HASH',
      'DONE result artifact is missing or its SHA-256 differs',
    );
  }

  return findings;
}

export function validateTaskLedger({
  markdown,
  definitions,
  catalog,
  repoRoot,
  currentDigest,
  trackedPaths,
}) {
  const parsed = parseTaskLedger(markdown);
  const findings = parsed.findings.slice();
  const expected = new Set(definitions.map((definition) => definition.id));
  const actual = new Set(parsed.rows.map((row) => row.id));

  const missingTask = [...expected].find((id) => !actual.has(id));
  if (missingTask) {
    addOnce(findings, 'GOVERNANCE_TASK_MISSING', `canonical task missing: ${missingTask}`);
  }
  const extraTask = [...actual].find((id) => !expected.has(id));
  if (extraTask) {
    addOnce(findings, 'GOVERNANCE_TASK_EXTRA', `non-canonical task present: ${extraTask}`);
  }

  for (const row of parsed.rows) {
    if (!row.deliverable) {
      addOnce(findings, 'GOVERNANCE_DELIVERABLE_MISSING', `deliverable missing: ${row.id}`);
    }
    if (!row.contractCoverage) {
      addOnce(findings, 'GOVERNANCE_COVERAGE_EMPTY', `coverage missing: ${row.id}`);
    }
    const acceptanceClauses = row.acceptance.split('<br>');
    if (
      acceptanceClauses.some(
        (clause) => !clause.includes('⇒') || !/\bexit\s+[01]\b/.test(clause),
      )
    ) {
      addOnce(
        findings,
        'GOVERNANCE_ACCEPTANCE_INVALID',
        `acceptance command lacks exact exit contract: ${row.id}`,
      );
    }
    for (const evidenceFinding of validateEvidence(row)) {
      addOnce(findings, evidenceFinding.id, evidenceFinding.message, { taskID: row.id });
    }
    if (row.state === 'DONE') {
      for (const doneFinding of validateDoneEvidence({
        row,
        currentDigest,
        repoRoot,
        trackedPaths,
      })) {
        addOnce(findings, doneFinding.id, doneFinding.message, { taskID: row.id });
      }
    }
  }

  for (const coverageFinding of validateCoverage({
    rows: parsed.rows,
    catalog: buildCoverageCatalog(catalog),
  })) {
    addOnce(findings, coverageFinding.id, coverageFinding.message, coverageFinding);
  }

  return { rows: parsed.rows, findings };
}
