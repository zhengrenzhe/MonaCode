import { spawnSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  canonicalJSON,
} from '../../Comparators/probes/product-integration-probe.mjs';
import {
  deriveProjectTaskDefinitions,
  loadContractCatalog,
} from './contract-catalog.mjs';
import {
  computeVerificationSourceSet,
  sha256,
} from './source-set.mjs';
import {
  TASKS_BEGIN,
  TASKS_END,
} from './task-ledger.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_REPO_ROOT = resolve(HERE, '..', '..');
const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';

export const CAPTURE_COMMANDS = [
  {
    id: 'swift-tests',
    executable: '/usr/bin/xcrun',
    args: ['swift', 'test', '--skip', 'Soak4HourTests'],
    timeoutMs: 30 * 60 * 1000,
  },
  {
    id: 'governance-node-tests',
    executable: NODE,
    args: [
      '--test',
      'Tests/PlanStructureTests/ProjectGovernanceTests.mjs',
      'Tests/PlanStructureTests/ProductIntegrationProbeTests.mjs',
      'Tests/PlanStructureTests/FinalReleaseVerdictTests.mjs',
    ],
    timeoutMs: 10 * 60 * 1000,
  },
  {
    id: 'g4-contract',
    executable: NODE,
    args: ['docs/contracts/monaco-editor-0.56.0/g4-r/verify-contract.mjs'],
    timeoutMs: 2 * 60 * 1000,
  },
  {
    id: 'g5-contract',
    executable: NODE,
    args: ['docs/contracts/monaco-editor-0.56.0/g5-r/verify-contract.mjs'],
    timeoutMs: 2 * 60 * 1000,
  },
  {
    id: 'g6-contract',
    executable: NODE,
    args: ['docs/contracts/monaco-editor-0.56.0/g6-r/verify-contract.mjs'],
    timeoutMs: 2 * 60 * 1000,
  },
  {
    id: 'product-integration-probe',
    executable: NODE,
    args: ['Comparators/probes/product-integration-probe.mjs'],
    timeoutMs: 2 * 60 * 1000,
  },
  {
    id: 'release-verdict',
    executable: NODE,
    args: ['Tools/Release/release-verdict.mjs'],
    timeoutMs: 5 * 60 * 1000,
  },
];

const compareUTF8 = (left, right) =>
  Buffer.compare(Buffer.from(left, 'utf8'), Buffer.from(right, 'utf8'));

const commandText = (command) =>
  [command.executable, ...command.args].join(' ');

function runCommand(command, repoRoot) {
  const result = spawnSync(command.executable, command.args, {
    cwd: repoRoot,
    encoding: 'utf8',
    maxBuffer: 512 * 1024 * 1024,
    timeout: command.timeoutMs,
  });
  if (result.error) {
    throw new Error(
      `EVIDENCE_CAPTURE_COMMAND_ERROR ${command.id}: ${result.error.message}`,
    );
  }
  if (result.status === null) {
    throw new Error(
      `EVIDENCE_CAPTURE_COMMAND_SIGNAL ${command.id}: ${result.signal ?? 'unknown'}`,
    );
  }
  return {
    status: result.status,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? '',
  };
}

function parseJSONOutput(commandID, stdout) {
  try {
    return JSON.parse(stdout);
  } catch (error) {
    throw new Error(
      `EVIDENCE_CAPTURE_JSON_INVALID ${commandID}: ${error.message}`,
    );
  }
}

export function validateKnownSwiftFailure(result) {
  const output = `${result.stdout}\n${result.stderr}`;
  const target = 'testSampleHostActivatesThreeProducts';
  const assertionLines = output
    .split('\n')
    .filter((line) => /XCTAssert[A-Za-z]* failed/.test(line));
  const failedCaseLines = output
    .split('\n')
    .filter((line) => /Test Case .+ failed \(/.test(line));
  const summaryMatches = [...output.matchAll(
    /Executed\s+(\d+)\s+tests,\s+with\s+(\d+)\s+test skipped and\s+(\d+)\s+failures/g,
  )];
  const summary = summaryMatches.at(-1);
  const exactSummary = summary !== undefined
    && summary[1] === '2842'
    && summary[2] === '1'
    && summary[3] === '4';

  if (
    result.status !== 1
    || assertionLines.length !== 4
    || !assertionLines.every((line) => line.includes(target))
    || failedCaseLines.length !== 1
    || !failedCaseLines[0].includes(target)
    || !exactSummary
  ) {
    throw new Error(
      'EVIDENCE_CAPTURE_SWIFT_FAILURE_SET_CHANGED '
        + `exit=${result.status} assertions=${assertionLines.length}`
        + ` failedCases=${failedCaseLines.length}`
        + ` summary=${summary ? summary.slice(1).join('/') : 'missing'}`
        + ` assertionLines=${JSON.stringify(assertionLines.slice(0, 10))}`
        + ` failedCaseLines=${JSON.stringify(failedCaseLines.slice(0, 10))}`,
    );
  }

  return {
    executedTests: 2842,
    skippedTests: 1,
    assertionFailures: 4,
    failingTests: [target],
  };
}

function validateProbeResult(result) {
  const parsed = parseJSONOutput('product-integration-probe', result.stdout);
  if (!Array.isArray(parsed.findings)) {
    throw new Error('EVIDENCE_CAPTURE_PROBE_SCHEMA findings is not an array');
  }
  const expectedExit = parsed.findings.length === 0 ? 0 : 1;
  if (result.status !== expectedExit) {
    throw new Error(
      `EVIDENCE_CAPTURE_PROBE_EXIT expected=${expectedExit} actual=${result.status}`,
    );
  }
  const ids = parsed.findings.map((finding) => finding.id);
  if (
    ids.some((id) => typeof id !== 'string' || id.length === 0)
    || new Set(ids).size !== ids.length
    || JSON.stringify(ids) !== JSON.stringify(ids.slice().sort(compareUTF8))
    || parsed.findings.some(
      (finding) => !Array.isArray(finding.taskIDs)
        || finding.taskIDs.length === 0
        || !Array.isArray(finding.paths)
        || finding.paths.length === 0
        || typeof finding.observation !== 'string'
        || finding.observation.length === 0
        || typeof finding.unblockCondition !== 'string'
        || finding.unblockCondition.length === 0,
    )
  ) {
    throw new Error('EVIDENCE_CAPTURE_PROBE_SCHEMA finding fields are invalid');
  }
  return parsed;
}

export function validateReleaseResult(result) {
  if (result.status !== 0) {
    throw new Error(`EVIDENCE_CAPTURE_COMMAND_FAILED release-verdict exit=${result.status}`);
  }
  const parsed = parseJSONOutput('release-verdict', result.stdout);
  const reboundOrStale = (blocker) =>
    blocker.id === 'current-acceptance-rebound'
    || blocker.id === 'current-source-evidence-stale';
  if (
    parsed.verdict !== 'not-passed'
    || !Array.isArray(parsed.blockers)
    || !parsed.blockers.some(reboundOrStale)
  ) {
    throw new Error('EVIDENCE_CAPTURE_RELEASE_NOT_CURRENTLY_BLOCKED');
  }
  return {
    verdict: parsed.verdict,
    blockerCount: parsed.blockers.length,
    blockerIDs: parsed.blockers.map((blocker) => blocker.id).sort(compareUTF8),
  };
}

function validateCommand(command, result) {
  if (command.id === 'swift-tests') {
    return {
      status: 'accepted-known-product-failure',
      summary: validateKnownSwiftFailure(result),
    };
  }
  if (command.id === 'governance-node-tests') {
    if (result.status === 0) {
      return { status: 'passed', summary: { exitCode: 0 } };
    }
    // Ruling K (narrowed, I2): accept exit 1 ONLY when identifiable as the
    // VERIFY-001 stale-digest mid-state (README not yet rebound to the current
    // source-set digest). The signature is GOVERNANCE_DONE_DIGEST_STALE in the
    // governance-node-tests stdout. A non-stale exit 1 is a real regression
    // and must throw — do not mask it.
    const isStaleMidState = /GOVERNANCE_DONE_DIGEST_STALE/.test(result.stdout);
    if (!isStaleMidState) {
      throw new Error(
        `EVIDENCE_CAPTURE_GOVERNANCE_REGRESSION exit=${result.status}`
        + ' (no GOVERNANCE_DONE_DIGEST_STALE marker; not the VERIFY-001 stale mid-state)'
        + ` stdout=${result.stdout.slice(0, 500)}`,
      );
    }
    return {
      status: 'accepted-mid-state-stale',
      summary: {
        exitCode: result.status,
        reason: 'VERIFY-001 stale-digest mid-state (README not yet rebound to current source-set digest)',
      },
    };
  }
  if (command.id === 'product-integration-probe') {
    const parsed = validateProbeResult(result);
    return {
      status: parsed.findings.length === 0 ? 'passed' : 'accepted-product-findings',
      summary: {
        findingCount: parsed.findings.length,
        findingIDs: parsed.findings.map((finding) => finding.id),
      },
      parsed,
    };
  }
  if (command.id === 'release-verdict') {
    return {
      status: 'passed-current-rejection',
      summary: validateReleaseResult(result),
    };
  }
  if (result.status !== 0) {
    throw new Error(
      `EVIDENCE_CAPTURE_COMMAND_FAILED ${command.id} exit=${result.status}`,
    );
  }
  return {
    status: 'passed',
    summary: { exitCode: 0 },
  };
}

function shellQuote(value) {
  if (/^[A-Za-z0-9_./:=+@%,-]+$/.test(value)) return value;
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}

function renderLeaf(leaf) {
  return [leaf.executable, ...leaf.args].map(shellQuote).join(' ');
}

function renderPlanCommand(command) {
  const leaves = command.leaves.map(renderLeaf);
  if (command.kind === 'pipeline') {
    return `set -o pipefail; ${leaves.join(' | ')}`;
  }
  if (command.kind === 'all-success') {
    return leaves.join(' && ');
  }
  if (command.kind === 'process' && leaves.length === 1) {
    return leaves[0];
  }
  throw new Error(
    `GOVERNANCE_ACCEPTANCE_COMMAND_UNSUPPORTED ${command.commandID} ${command.kind}`,
  );
}

function acceptanceForDefinition(definition, tasksByID) {
  if (definition.id === 'VERIFY-001') {
    return `${NODE} Tools/Docs/check-project-governance.mjs ⇒ exit 0`;
  }
  if (definition.domain === 'MOBILE') {
    return '/usr/bin/test -d Sources/MonaCodeMobile ⇒ exit 0';
  }
  const task = tasksByID.get(definition.sourceTaskID);
  if (!task) {
    throw new Error(`GOVERNANCE_ACCEPTANCE_TASK_MISSING ${definition.sourceTaskID}`);
  }
  const green = task.stages.find((stage) => stage.name === 'green');
  const commands = (green?.steps ?? [])
    .filter((step) => step.kind === 'verification-command')
    .map((step) => step.command);
  if (commands.length === 0) {
    throw new Error(`GOVERNANCE_ACCEPTANCE_GREEN_MISSING ${task.id}`);
  }
  return commands
    .map((command) => `${renderPlanCommand(command)} ⇒ exit ${command.expectedExit}`)
    .join('<br>');
}

export function classifyState(definition, findingIDs, acceptancePassed) {
  if (findingIDs.length > 0) return 'BLOCKED';
  if (acceptancePassed) return 'DONE';
  return 'TODO';
}

function classifyTaskResults(definitions, catalog, integrationFindings, acceptanceByTask) {
  const tasksByID = new Map(catalog.planTasks.map((task) => [task.id, task]));
  const findingIDsByTask = new Map();
  for (const row of integrationFindings) {
    for (const taskID of row.taskIDs) {
      const ids = findingIDsByTask.get(taskID) ?? [];
      ids.push(row.id);
      findingIDsByTask.set(taskID, ids);
    }
  }
  return definitions.map((definition) => {
    const findingIDs = (findingIDsByTask.get(definition.sourceTaskID) ?? []).sort(compareUTF8);
    const acceptancePassed = acceptanceByTask.get(definition.sourceTaskID) ?? false;
    return {
      id: definition.id,
      sourceTaskID: definition.sourceTaskID,
      state: classifyState(definition, findingIDs, acceptancePassed),
      acceptance: acceptanceForDefinition(definition, tasksByID),
      findingIDs,
    };
  });
}

function taskCounts(taskResults) {
  return {
    blocked: taskResults.filter((row) => row.state === 'BLOCKED').length,
    done: taskResults.filter((row) => row.state === 'DONE').length,
    inProgress: taskResults.filter((row) => row.state === 'IN PROGRESS').length,
    todo: taskResults.filter((row) => row.state === 'TODO').length,
  };
}

export function captureProjectEvidence(repoRoot, options = {}) {
  const sourceSet = computeVerificationSourceSet(repoRoot);
  const catalog = loadContractCatalog(repoRoot);
  const definitions = deriveProjectTaskDefinitions(catalog);
  const execute = options.runCommand
    ?? ((command) => runCommand(command, repoRoot));
  const commandResults = [];
  let integrationFindings = null;

  for (const command of CAPTURE_COMMANDS) {
    const raw = execute(command);
    if (
      raw === null
      || typeof raw !== 'object'
      || !Number.isInteger(raw.status)
      || typeof raw.stdout !== 'string'
      || typeof raw.stderr !== 'string'
    ) {
      throw new Error(`EVIDENCE_CAPTURE_RUNNER_RESULT_INVALID ${command.id}`);
    }
    const validation = validateCommand(command, raw);
    if (validation.parsed) integrationFindings = validation.parsed.findings;
    commandResults.push({
      id: command.id,
      command: commandText(command),
      exitCode: raw.status,
      status: validation.status,
      stdoutSHA256: sha256(Buffer.from(raw.stdout, 'utf8')),
      stderrSHA256: sha256(Buffer.from(raw.stderr, 'utf8')),
      summary: validation.summary,
    });
  }

  if (integrationFindings === null) {
    throw new Error('EVIDENCE_CAPTURE_PROBE_RESULT_MISSING');
  }
  const acceptancePath = join(
    repoRoot,
    'artifacts',
    'progress',
    sourceSet.digest,
    'task-acceptance.json',
  );
  const acceptanceByTask = new Map();
  if (existsSync(acceptancePath)) {
    const acc = JSON.parse(readFileSync(acceptancePath, 'utf8'));
    for (const r of acc.taskResults ?? []) {
      acceptanceByTask.set(r.taskID, r.passed === true);
    }
  }
  // Ruling L: VERIFY-001 is the governance framework itself — its acceptance is
  // the governance-node-tests gate (exit 0). It is not in planTasks, so the
  // task-acceptance-runner does not run it; derive it from governance-node-tests.
  const govCmd = commandResults.find((c) => c.id === 'governance-node-tests');
  if (govCmd) acceptanceByTask.set('VERIFY-001', govCmd.exitCode === 0);
  const taskResults = classifyTaskResults(
    definitions,
    catalog,
    integrationFindings,
    acceptanceByTask,
  );

  return {
    schemaVersion: 1,
    digest: sourceSet.digest,
    g6ManifestDigest: sourceSet.g6ManifestDigest,
    sourceFileCount: sourceSet.rows.length,
    commands: commandResults,
    integrationFindings,
    taskResults,
    taskCounts: taskCounts(taskResults),
  };
}

export function progressEvidencePath(repoRoot, digest) {
  return join(repoRoot, 'artifacts', 'progress', digest, 'task-evidence.json');
}

export function writeProjectEvidence(repoRoot, evidence) {
  const path = progressEvidencePath(repoRoot, evidence.digest);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, canonicalJSON(evidence));
  return {
    path,
    repositoryPath: relative(repoRoot, path),
    sha256: sha256(readFileSync(path)),
  };
}

function escapeCell(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('|', '&#124;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('\n', ' ');
}

function renderAcceptance(value) {
  return value
    .split('<br>')
    .map((clause) => {
      const [command, exit] = clause.split(' ⇒ ');
      return `<code>${escapeCell(command)}</code> ⇒ ${escapeCell(exit)}`;
    })
    .join('<br>');
}

export function evidenceForResult(result, evidence) {
  if (result.state === 'TODO') return '—';
  if (result.state === 'IN PROGRESS') {
    return 'change:VERIFY-001<br>owner:zhengrenzhe';
  }
  if (result.state === 'BLOCKED') {
    return `blocker:${result.findingIDs.join(',')}<br>unblock:fill the corresponding product gap (subprojects A-D)`;
  }
  if (result.state === 'DONE') {
    if (
      !evidence.artifactPath
      || !/^[0-9a-f]{64}$/.test(evidence.artifactSHA256 ?? '')
    ) {
      throw new Error('GOVERNANCE_DONE_ARTIFACT_BINDING_MISSING');
    }
    return `digest:${evidence.digest}`
      + '<br>source:[governance checker](Tools/Docs/check-project-governance.mjs)'
      + '<br>tests:[governance tests](Tests/PlanStructureTests/ProjectGovernanceTests.mjs)'
      + `<br>results:[task evidence](${evidence.artifactPath})`
      + ` sha256:${evidence.artifactSHA256}`;
  }
  throw new Error(`GOVERNANCE_STATE_UNSUPPORTED ${result.state}`);
}

export function renderTaskTable(definitions, evidence) {
  const results = new Map(evidence.taskResults.map((row) => [row.id, row]));
  if (results.size !== definitions.length) {
    throw new Error(
      `GOVERNANCE_TASK_RESULT_COUNT expected=${definitions.length} actual=${results.size}`,
    );
  }
  const lines = [
    TASKS_BEGIN,
    '| ID | State | Deliverable | Contract coverage | Acceptance | Evidence |',
    '| --- | --- | --- | --- | --- | --- |',
  ];
  for (const definition of definitions) {
    const result = results.get(definition.id);
    if (!result) {
      throw new Error(`GOVERNANCE_TASK_RESULT_MISSING ${definition.id}`);
    }
    lines.push(
      `| ${definition.id} | ${result.state} | ${escapeCell(definition.title)}`
        + ` | ${definition.selectors.join('<br>')} | ${renderAcceptance(result.acceptance)}`
        + ` | ${evidenceForResult(result, evidence)} |`,
    );
  }
  lines.push(TASKS_END);
  return `${lines.join('\n')}\n`;
}

function loadCurrentEvidence(repoRoot) {
  const digest = computeVerificationSourceSet(repoRoot).digest;
  const path = progressEvidencePath(repoRoot, digest);
  if (!existsSync(path)) {
    throw new Error(`GOVERNANCE_CURRENT_EVIDENCE_MISSING ${relative(repoRoot, path)}`);
  }
  const evidence = JSON.parse(readFileSync(path, 'utf8'));
  if (evidence.digest !== digest) {
    throw new Error(
      `GOVERNANCE_CURRENT_EVIDENCE_DIGEST expected=${digest} actual=${evidence.digest}`,
    );
  }
  return {
    ...evidence,
    artifactPath: relative(repoRoot, path),
    artifactSHA256: sha256(readFileSync(path)),
  };
}

function main() {
  const args = new Set(process.argv.slice(2));
  const allowed = new Set(['--write', '--render-task-table', '--governance-complete']);
  const unknown = [...args].filter((arg) => !allowed.has(arg));
  if (unknown.length > 0) {
    throw new Error(`EVIDENCE_CAPTURE_ARGUMENT_UNKNOWN ${unknown.join(',')}`);
  }
  if (args.has('--render-task-table')) {
    if (args.has('--write')) {
      throw new Error('EVIDENCE_CAPTURE_RENDER_AND_WRITE_MUST_RUN_SEPARATELY');
    }
    const evidence = loadCurrentEvidence(DEFAULT_REPO_ROOT);
    const definitions = deriveProjectTaskDefinitions(
      loadContractCatalog(DEFAULT_REPO_ROOT),
    );
    process.stdout.write(renderTaskTable(definitions, evidence));
    return;
  }

  const evidence = captureProjectEvidence(DEFAULT_REPO_ROOT, {
    governanceComplete: args.has('--governance-complete'),
  });
  if (!args.has('--write')) {
    process.stdout.write(canonicalJSON(evidence));
    return;
  }
  const artifact = writeProjectEvidence(DEFAULT_REPO_ROOT, evidence);
  process.stdout.write(canonicalJSON({
    artifactPath: artifact.repositoryPath,
    artifactSHA256: artifact.sha256,
    digest: evidence.digest,
    commandResults: evidence.commands.map((row) => ({
      id: row.id,
      exitCode: row.exitCode,
      status: row.status,
    })),
    integrationFindings: evidence.integrationFindings,
    taskCounts: evidence.taskCounts,
  }));
}

const invokedDirectly = process.argv[1]
  && resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (invokedDirectly) main();
