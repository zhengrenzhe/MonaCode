import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, extname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  deriveProjectTaskDefinitions,
  loadContractCatalog,
} from './contract-catalog.mjs';
import { computeVerificationSourceSet } from './source-set.mjs';
import {
  buildCoverageCatalog,
  TASKS_BEGIN,
  validateTaskLedger,
} from './task-ledger.mjs';

const CURRENT_STATUS_HEADING =
  /^#{1,6}\s+(current status|project status|status|当前状态|当前进展|项目进展)\s*$/im;
const TASK_TABLE_HEADER =
  '| ID | State | Deliverable | Contract coverage | Acceptance | Evidence |';

const PRE_GOVERNANCE_SPECS = [
  '2026-08-14-monacode-g4r-design.md',
  '2026-08-15-monacode-g5r-contract-plan-revision-design.md',
  '2026-08-15-monacode-g6r-execution-readiness-design.md',
  '2026-08-19-monacode-command-dispatcher-design.md',
  '2026-08-20-monacode-driving-layer-design.md',
];
const PRE_GOVERNANCE_PLANS = [
  '2026-08-15-monacode-g5r-contract-plan-revision-adversarial-review.md',
  '2026-08-15-monacode-g5r-contract-plan-revision.md',
  '2026-08-15-monacode-g6r-execution-readiness.md',
  '2026-08-19-monacode-command-dispatcher.md',
  '2026-08-20-monacode-driving-layer.md',
];

export const ARCHIVE_REQUIRED_ENTRIES = [
  {
    originalPath: 'STATUS.md',
    archivedPath: 'docs/archive/status-snapshots/0fd99e28b11f2eb1910be227b6f26c1aa15c8049/STATUS.md',
  },
  {
    originalPath: 'RELEASE_VERDICT.md',
    archivedPath: 'docs/archive/releases/P07-T011/RELEASE_VERDICT.md',
  },
  {
    originalPath: 'docs/equivalence/equivalence-gap.md',
    archivedPath: 'docs/archive/audits/2026-08-19-monaco-api-equivalence/equivalence-gap.md',
  },
  {
    originalPath: 'docs/equivalence/monaco-editor-0.56.0.editor.api.d.ts',
    archivedPath: 'Comparators/Baselines/monaco-editor-0.56.0.editor.api.d.ts',
  },
  ...PRE_GOVERNANCE_SPECS.map((name) => ({
    originalPath: `docs/superpowers/specs/${name}`,
    archivedPath: `docs/archive/decisions/superpowers/specs/${name}`,
  })),
  ...PRE_GOVERNANCE_PLANS.map((name) => ({
    originalPath: `docs/superpowers/plans/${name}`,
    archivedPath: `docs/archive/decisions/superpowers/plans/${name}`,
  })),
  {
    originalPath: 'docs/superpowers/specs/2026-08-20-monacode-single-source-governance-design.md',
    archivedPath: 'docs/archive/decisions/superpowers/specs/2026-08-20-monacode-single-source-governance-design.md',
  },
  {
    originalPath: 'docs/superpowers/plans/2026-08-20-monacode-single-source-governance.md',
    archivedPath: 'docs/archive/decisions/superpowers/plans/2026-08-20-monacode-single-source-governance.md',
  },
];

const isExcluded = (path, exclusions) =>
  [...exclusions].some((entry) => path === entry || path.startsWith(`${entry}/`));

const addOnce = (findings, id, message, details = {}) => {
  if (!findings.some((finding) => finding.id === id)) {
    findings.push({ id, message, ...details });
  }
};

export function scanActiveProgressSources({ files, exclusions }) {
  const findings = [];
  if (files.has('STATUS.md')) {
    findings.push({
      id: 'GOVERNANCE_ROOT_STATUS',
      message: 'tracked root STATUS.md is prohibited',
    });
  }
  if (files.has('RELEASE_VERDICT.md')) {
    findings.push({
      id: 'GOVERNANCE_ROOT_RELEASE_VERDICT',
      message: 'tracked root RELEASE_VERDICT.md is prohibited',
    });
  }

  for (const [path, text] of files) {
    if (isExcluded(path, exclusions) || path === 'README.md' || path === 'AGENTS.md') {
      continue;
    }
    if (path === 'STATUS.md' || path === 'RELEASE_VERDICT.md') continue;
    if (path === 'docs/archive/README.md') {
      if (CURRENT_STATUS_HEADING.test(text)) {
        addOnce(
          findings,
          'GOVERNANCE_ARCHIVE_STATUS',
          'archive index claims current project status',
          { path },
        );
      }
      continue;
    }
    if (path.startsWith('docs/archive/')) continue;
    if (
      path.startsWith('docs/contracts/')
      || path.startsWith('docs/implementation-phases/')
      || path.startsWith('docs/superpowers/')
      || path.startsWith('artifacts/')
      || path.startsWith('.build/')
    ) {
      continue;
    }
    if (text.includes(TASKS_BEGIN) || text.includes(TASK_TABLE_HEADER)) {
      addOnce(
        findings,
        'GOVERNANCE_DUPLICATE_LEDGER',
        `active task ledger found outside README: ${path}`,
        { path },
      );
    }
    if (path.startsWith('docs/equivalence/')) {
      addOnce(
        findings,
        'GOVERNANCE_ACTIVE_EQUIVALENCE_STATUS',
        `mutable equivalence report remains active: ${path}`,
        { path },
      );
    }
    if (CURRENT_STATUS_HEADING.test(text)) {
      addOnce(
        findings,
        'GOVERNANCE_ACTIVE_STATUS',
        `active status heading found outside README: ${path}`,
        { path },
      );
    }
  }

  return findings;
}

const archiveCells = (line) => {
  if (!line.startsWith('|') || !line.endsWith('|')) return null;
  return line.slice(1, -1).split('|').map((cell) => cell.trim());
};

const stripCode = (value) => value.replace(/^`|`$/g, '').trim();

export function validateArchiveIndex({
  markdown,
  requiredEntries,
  trackedPaths,
  repoRoot,
}) {
  const findings = [];
  const lines = markdown
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.startsWith('|'));
  const rows = [];
  for (const line of lines.slice(2)) {
    const cells = archiveCells(line);
    if (cells?.length !== 5) continue;
    const originalPath = stripCode(cells[0]);
    const archivedLink = /\[([^\]]+)\]\(([^)]+)\)/.exec(cells[1]);
    const archivedAbsolute = archivedLink
      ? resolve(repoRoot, 'docs/archive', archivedLink[2].replace(/^<|>$/g, ''))
      : null;
    const repoPrefix = `${resolve(repoRoot)}/`;
    const archivedPath = archivedAbsolute?.startsWith(repoPrefix)
      ? archivedAbsolute.slice(repoPrefix.length)
      : null;
    rows.push({
      originalPath,
      archivedPath,
      sha256: stripCode(cells[3]),
      classification: cells[4],
    });
  }

  const duplicate = rows.find(
    (row, index) => rows.findIndex((candidate) => candidate.originalPath === row.originalPath) !== index,
  );
  if (duplicate) {
    addOnce(
      findings,
      'GOVERNANCE_ARCHIVE_ENTRY_DUPLICATE',
      `archive index repeats original path: ${duplicate.originalPath}`,
    );
  }

  for (const required of requiredEntries) {
    const row = rows.find(
      (candidate) => candidate.originalPath === required.originalPath
        && candidate.archivedPath === required.archivedPath,
    );
    if (!row) {
      addOnce(
        findings,
        'GOVERNANCE_ARCHIVE_ENTRY_MISSING',
        `archive index is missing ${required.originalPath} -> ${required.archivedPath}`,
      );
    }
  }

  for (const row of rows) {
    if (!row.classification.includes('progress authority=false')) {
      addOnce(
        findings,
        'GOVERNANCE_ARCHIVE_CLASSIFICATION',
        `archive row lacks non-authority classification: ${row.originalPath}`,
      );
    }
    let actualHash = null;
    if (row.archivedPath && trackedPaths.has(row.archivedPath)) {
      try {
        actualHash = createHash('sha256')
          .update(readFileSync(resolve(repoRoot, row.archivedPath)))
          .digest('hex');
      } catch {
        actualHash = null;
      }
    }
    if (!/^[0-9a-f]{64}$/.test(row.sha256) || actualHash !== row.sha256) {
      addOnce(
        findings,
        'GOVERNANCE_ARCHIVE_HASH',
        `archive row path/hash is missing, untracked, or stale: ${row.originalPath}`,
      );
    }
  }

  return findings;
}

const trackedPaths = (repoRoot) => {
  const output = execFileSync('/usr/bin/git', ['ls-files', '-z'], { cwd: repoRoot });
  return output.toString('utf8').split('\0').filter(Boolean);
};

const repositoryLinks = (markdown) => {
  const links = [];
  const pattern = /\[([^\]]+)\]\(([^)]+)\)/g;
  for (const match of markdown.matchAll(pattern)) {
    const target = match[2].replace(/^<|>$/g, '').split('#', 1)[0];
    if (
      !target
      || target.startsWith('/')
      || target.startsWith('#')
      || /^[a-z][a-z0-9+.-]*:/i.test(target)
    ) {
      continue;
    }
    links.push({ label: match[1].trim(), target });
  }
  return links;
};

const validateLinks = ({ repoRoot, path, markdown, tracked }) => {
  const findings = [];
  for (const link of repositoryLinks(markdown)) {
    const relative = resolve(dirname(resolve(repoRoot, path)), link.target);
    const repoPrefix = `${resolve(repoRoot)}/`;
    const repoRelative = relative.startsWith(repoPrefix)
      ? relative.slice(repoPrefix.length)
      : null;
    if (
      !link.label
      || !repoRelative
      || !tracked.has(repoRelative)
      || !existsSync(relative)
    ) {
      addOnce(
        findings,
        'GOVERNANCE_LINK_MISSING',
        `missing or untracked link in ${path}: ${link.target}`,
        { path, target: link.target },
      );
    }
  }
  return findings;
};

export function checkProjectGovernance(repoRoot) {
  const sourceSet = computeVerificationSourceSet(repoRoot);
  const catalog = loadContractCatalog(repoRoot);
  const definitions = deriveProjectTaskDefinitions(catalog);
  const paths = trackedPaths(repoRoot);
  const tracked = new Set(paths);
  const findings = [];

  let readme = '';
  if (!tracked.has('README.md') || !existsSync(resolve(repoRoot, 'README.md'))) {
    findings.push({ id: 'GOVERNANCE_README_MISSING', message: 'root README.md is missing' });
  } else {
    readme = readFileSync(resolve(repoRoot, 'README.md'), 'utf8');
  }

  const ledger = validateTaskLedger({
    markdown: readme,
    definitions,
    catalog,
    repoRoot,
    currentDigest: sourceSet.digest,
    trackedPaths: tracked,
  });
  findings.push(...ledger.findings);

  const markdownFiles = new Map();
  for (const path of paths.filter((candidate) => extname(candidate) === '.md')) {
    markdownFiles.set(path, readFileSync(resolve(repoRoot, path), 'utf8'));
  }
  findings.push(...scanActiveProgressSources({
    files: markdownFiles,
    exclusions: new Set(),
  }));

  for (const path of ['README.md', 'AGENTS.md', 'docs/archive/README.md']) {
    if (!markdownFiles.has(path)) continue;
    findings.push(...validateLinks({
      repoRoot,
      path,
      markdown: markdownFiles.get(path),
      tracked,
    }));
  }

  if (!markdownFiles.has('docs/archive/README.md')) {
    findings.push({
      id: 'GOVERNANCE_ARCHIVE_INDEX_MISSING',
      message: 'docs/archive/README.md is missing',
    });
  } else {
    findings.push(...validateArchiveIndex({
      markdown: markdownFiles.get('docs/archive/README.md'),
      requiredEntries: ARCHIVE_REQUIRED_ENTRIES,
      trackedPaths: tracked,
      repoRoot,
    }));
  }

  const sortedFindings = findings.sort((left, right) =>
    `${left.id}\0${left.message}`.localeCompare(`${right.id}\0${right.message}`, 'en-US'));
  const taskCounts = {
    done: ledger.rows.filter((row) => row.state === 'DONE').length,
    inProgress: ledger.rows.filter((row) => row.state === 'IN PROGRESS').length,
    blocked: ledger.rows.filter((row) => row.state === 'BLOCKED').length,
    todo: ledger.rows.filter((row) => row.state === 'TODO').length,
  };

  return {
    digest: sourceSet.digest,
    tasks: ledger.rows.length,
    taskCounts,
    coveredIdentities: buildCoverageCatalog(catalog).active.size,
    findings: sortedFindings,
  };
}

function main() {
  const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
  const result = checkProjectGovernance(repoRoot);
  if (result.findings.length > 0) {
    process.stdout.write(`${JSON.stringify(result.findings, null, 2)}\n`);
    process.exitCode = 1;
    return;
  }
  process.stdout.write(
    `PROJECT_GOVERNANCE tasks=${result.tasks} done=${result.taskCounts.done}`
      + ` inProgress=${result.taskCounts.inProgress}`
      + ` blocked=${result.taskCounts.blocked} todo=${result.taskCounts.todo}`
      + ` identities=${result.coveredIdentities} findings=0 digest=${result.digest}\n`,
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
