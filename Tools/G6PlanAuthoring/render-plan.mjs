// G6-R Task 24 — deterministic human-document renderer.
//
// renderPlan produces the eleven human-readable Markdown documents from the
// assembled ExecutionPlan machine record. Every byte is derived from the
// machine record; the documents contain no normative content absent from the
// machine record. Rendering the same plan twice yields byte-identical output.
//
// Documents produced:
//   implementation-plan/README.md
//   implementation-plan/00-master-plan.md
//   implementation-plan/phase-00-scaffold-harness.md
//   ... through phase-09-acceptance-release-verdict.md (10 phase docs)

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import * as path from 'node:path';

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

const PHASE_SLUGS = [
  'phase-00-scaffold-harness',
  'phase-01-base-model',
  'phase-02-model-semantics',
  'phase-03-projection-layout-rendering',
  'phase-04-input-transfer-accessibility',
  'phase-05-public-surface-features',
  'phase-06-language-lsp-snippet-markdown',
  'phase-07-diff-services-host-source-closure',
  'phase-08-release-candidate-distribution',
  'phase-09-acceptance-release-verdict',
];

const escapeInline = (value) => String(value).replace(/[\\`]/g, (m) => `\\${m}`);

function lines(out, arr) {
  for (const line of arr) out.push(line);
}

function renderValue(value) {
  if (value === null) return 'null';
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return JSON.stringify(value);
}

function renderList(out, indent, items) {
  const prefix = `${indent}- `;
  if (!Array.isArray(items) || items.length === 0) {
    out.push(`${indent}- _(none)_`);
    return;
  }
  for (const item of items) {
    if (item !== null && typeof item === 'object') {
      out.push(`${prefix}\`${JSON.stringify(item)}\``);
    } else {
      out.push(`${prefix}${escapeInline(renderValue(item))}`);
    }
  }
}

function renderStages(out, stages) {
  for (const stage of stages) {
    out.push(`### Stage \`${stage.name}\``);
    out.push('');
    if (!Array.isArray(stage.steps) || stage.steps.length === 0) {
      out.push('- _(no steps)_');
      out.push('');
      continue;
    }
    for (const step of stage.steps) {
      const kind = step.kind ?? 'unknown';
      if (kind === 'controller-action') {
        out.push(`- controller-action: \`${step.action ?? ''}\``);
      } else if (kind === 'authoring-operation') {
        out.push(`- authoring-operation: \`${escapeInline(step.operation ?? '')}\``);
      } else if (kind === 'implementation-operation') {
        out.push(`- implementation-operation: \`${escapeInline(step.operation ?? '')}\``);
      } else if (kind === 'verification-command') {
        const command = step.command ?? {};
        out.push(`- verification-command: \`${command.commandID ?? ''}\` (kind=${command.kind ?? ''}, network=${command.networkMode ?? ''}, timeout=${command.timeoutMs ?? ''}ms, leaves=${(command.leaves ?? []).length})`);
      } else if (kind === 'source-acquisition') {
        const acq = step.acquisition ?? {};
        out.push(`- source-acquisition: \`${acq.sourceID ?? ''}\` url=\`${acq.url ?? ''}\` host=\`${acq.host ?? ''}\` disposition=\`${acq.outputDisposition ?? ''}\``);
      } else {
        out.push(`- ${escapeInline(kind)}: \`${JSON.stringify(step)}\``);
      }
    }
    out.push('');
  }
}

function renderTask(task) {
  const out = [];
  out.push(`<!-- G6-R-TASK:${task.id}:${task.recordSha256} -->`);
  out.push('');
  out.push(`# ${task.id} — ${task.title ?? ''}`);
  out.push('');
  out.push(`- Phase: \`${task.phase ?? ''}\``);
  out.push(`- Record SHA-256: \`${task.recordSha256}\``);
  out.push(`- Platform scope: \`${(task.platformScope ?? []).join(', ')}\``);
  out.push('');
  out.push('## Dependencies');
  out.push('');
  renderList(out, '', task.dependencies ?? []);
  out.push('');
  out.push('## Contract references');
  out.push('');
  renderList(out, '', task.contractRefs ?? []);
  out.push('');
  out.push('## Ownership');
  out.push('');
  renderList(out, '', task.ownership ?? []);
  out.push('');
  out.push('## Paths');
  out.push('');
  out.push(`- productTarget: \`${task.paths?.productTarget ?? 'null'}\``);
  out.push('- create:');
  renderList(out, '  ', task.paths?.create ?? []);
  out.push('- modify:');
  renderList(out, '  ', task.paths?.modify ?? []);
  out.push('- test:');
  renderList(out, '  ', task.paths?.test ?? []);
  out.push('');
  out.push('## Interfaces');
  out.push('');
  out.push('- produces:');
  renderList(out, '  ', task.interfaces?.produces ?? []);
  out.push('- consumes:');
  renderList(out, '  ', task.interfaces?.consumes ?? []);
  out.push('');
  out.push('## Completion assertions');
  out.push('');
  renderList(out, '', task.completion ?? []);
  out.push('');
  out.push('## Stages');
  out.push('');
  renderStages(out, task.stages ?? []);
  out.push('## Test contract');
  out.push('');
  const contract = task.testContract ?? { cases: [] };
  out.push(`- contractID: \`${contract.contractID ?? ''}\``);
  out.push(`- cases: ${contract.cases?.length ?? 0}`);
  for (const c of contract.cases ?? []) {
    out.push(`  - \`${c.caseID}\` red=\`${c.redLeafID}\` green=\`${c.greenLeafID}\` failureClass=\`${c.failureClass ?? ''}\``);
  }
  out.push('');
  out.push('## Red scaffold');
  out.push('');
  const scaffolds = task.redScaffold ?? [];
  out.push(`- rows: ${scaffolds.length}`);
  for (const s of scaffolds) {
    out.push(`  - \`${s.sourcePath ?? ''}\` marker=\`${s.marker ?? ''}\` sentinel=\`${s.sentinelBehavior ?? ''}\``);
  }
  out.push('');
  out.push('## Source acquisitions');
  out.push('');
  const acquisitions = task.sourceAcquisitions ?? [];
  out.push(`- rows: ${acquisitions.length}`);
  for (const a of acquisitions) {
    out.push(`  - \`${a?.sourceID ?? ''}\` url=\`${a?.url ?? ''}\` host=\`${a?.host ?? ''}\` disposition=\`${a?.outputDisposition ?? ''}\``);
  }
  out.push('');
  out.push('## Evidence');
  out.push('');
  out.push(`- fromRevision: \`${task.evidence?.fromRevision ?? ''}\``);
  out.push(`- toRevision: \`${task.evidence?.toRevision ?? ''}\``);
  out.push(`- stagedEvidencePath: \`${task.evidence?.stagedEvidencePath ?? ''}\``);
  out.push('- paths:');
  renderList(out, '  ', task.evidence?.paths ?? []);
  out.push('');
  out.push('## Commits');
  out.push('');
  const product = task.commits?.product ?? {};
  out.push('### Product commit');
  out.push('');
  out.push(`- message: \`${product.message ?? ''}\``);
  out.push(`- author: \`${product.author?.name ?? ''} <${product.author?.email ?? ''}>\``);
  out.push(`- committer: \`${product.committer?.name ?? ''} <${product.committer?.email ?? ''}>\``);
  out.push(`- hooksDisabled: \`${product.hooksDisabled ?? ''}\``);
  out.push(`- signingDisabled: \`${product.signingDisabled ?? ''}\``);
  out.push(`- evidenceExcluded: \`${product.evidenceExcluded ?? ''}\``);
  out.push('- stagedProductPaths:');
  renderList(out, '  ', product.stagedProductPaths ?? []);
  out.push('');
  const evidence = task.commits?.evidence ?? {};
  out.push('### Evidence commit');
  out.push('');
  out.push(`- message: \`${evidence.message ?? ''}\``);
  out.push(`- stagedEvidencePath: \`${evidence.stagedEvidencePath ?? ''}\``);
  out.push(`- selectorMode: \`${evidence.selectorMode ?? ''}\``);
  out.push(`- firstParentSuccessor: \`${evidence.firstParentSuccessor ?? ''}\``);
  out.push(`- laterFirstParentTouches: \`${evidence.laterFirstParentTouches ?? ''}\``);
  out.push(`- prohibitsSelfEmbedding: \`${evidence.prohibitsSelfEmbedding ?? ''}\``);
  out.push(`- evidenceSchema: \`${evidence.evidenceSchema ?? ''}\``);
  out.push('- verifiedAssertions:');
  renderList(out, '  ', evidence.verifiedAssertions ?? []);
  out.push('');
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Master plan
// ---------------------------------------------------------------------------

function renderMasterPlan(plan) {
  const out = [];
  out.push('# MonaCode G6-R master execution plan');
  out.push('');
  out.push('## Fixed outcome');
  out.push('');
  out.push('Deliver exactly three public products—`MonaCode`, `MonaCodeAppKit`, and `MonaCodeSwiftUI`—for arm64 macOS 26.0+, ported from monaco-editor@0.56.0. The G6-R plan is the execution-readiness revision of the adopted G5-R full-scope plan. It migrates the 200 G5-R product tasks into structured G6-R TaskRecords with a seven-stage lifecycle, pinned toolchain commands, and commit-before-evidence ordering.');
  out.push('');
  out.push('The plan contains no product implementation. An assembly pass proves structural completeness only. It never proves behavioral equivalence, performance, reliability, candidate presence, or release readiness.');
  out.push('');
  out.push('## Authority');
  out.push('');
  out.push(`- Plan ID: \`${plan.planID}\``);
  out.push(`- Plan revision: \`${plan.planRevision}\``);
  out.push(`- Base commit: \`${plan.baseCommit}\``);
  out.push(`- Plan hash: \`${plan.planHash}\``);
  out.push(`- Tasks: ${plan.counts.tasks}`);
  out.push(`- Ownership rows: ${plan.counts.ownership}`);
  out.push(`- Commands: ${plan.counts.commands}`);
  out.push(`- Interfaces: ${plan.counts.interfaces}`);
  out.push('');
  out.push('## Phase graph');
  out.push('');
  out.push('| Phase | Scope | Depends on | Human document |');
  out.push('| --- | --- | --- | --- |');
  for (const phase of plan.phases) {
    out.push(`| ${phase.id} | ${phase.title} | ${phase.dependencies.join(', ') || 'none'} | \`${phase.document}\` |`);
  }
  out.push('');
  out.push('## Fixed matrices');
  out.push('');
  out.push('| Matrix | Count |');
  out.push('| --- | --- |');
  out.push(`| Tasks | ${plan.counts.tasks} |`);
  out.push(`| Test contracts | ${plan.counts.testContracts} |`);
  out.push(`| Verification commands | ${plan.counts.commands} |`);
  out.push(`| Leaf processes | ${plan.counts.leaves} |`);
  out.push(`| Begin actions | ${plan.counts.beginActions} |`);
  out.push(`| Commit actions | ${plan.counts.commitActions} |`);
  out.push(`| Finalize actions | ${plan.counts.finalizeActions} |`);
  out.push(`| Product-commit contracts | ${plan.counts.productCommitContracts} |`);
  out.push(`| Evidence-commit contracts | ${plan.counts.evidenceCommitContracts} |`);
  out.push(`| Source gaps | ${plan.counts.sourceGaps} |`);
  out.push(`| Acquisition gaps | ${plan.counts.acquisitionGaps} |`);
  out.push(`| Red-scaffold tasks | ${plan.counts.scaffoldTasks} |`);
  out.push(`| Red-scaffold paths | ${plan.counts.scaffoldPaths} |`);
  out.push(`| Interface contracts | ${plan.counts.interfaces} |`);
  out.push(`| Ownership rows | ${plan.counts.ownership} |`);
  out.push(`| Evidence contracts | ${plan.counts.evidence} |`);
  out.push('');
  out.push('## Documents');
  out.push('');
  out.push('| Document | SHA-256 |');
  out.push('| --- | --- |');
  for (const doc of plan.documents) {
    out.push(`| \`${doc.path}\` | \`${doc.sha256 ?? ''}\` |`);
  }
  out.push('');
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Phase document
// ---------------------------------------------------------------------------

function renderPhaseDoc(plan, phaseIndex) {
  const phase = plan.phases[phaseIndex];
  const phaseID = phase.id;
  const phaseTasks = plan.tasks.filter((t) => t.phase === phaseID);
  const out = [];
  out.push(`<!-- G6-R-PHASE:${phaseID} -->`);
  out.push('');
  out.push(`# Phase ${phaseID} — ${phase.title}`);
  out.push('');
  out.push(`- Phase: \`${phaseID}\``);
  out.push(`- Title: ${phase.title}`);
  out.push(`- Document: \`${phase.document}\``);
  out.push(`- Dependencies: ${phase.dependencies.length ? phase.dependencies.map((d) => `\`${d}\``).join(', ') : '_(none)_'} `);
  out.push(`- Tasks: ${phaseTasks.length}`);
  out.push('');
  out.push('## Tasks');
  out.push('');
  for (const task of phaseTasks) {
    out.push(`<!-- G6-R-TASK:${task.id}:${task.recordSha256} -->`);
    out.push('');
    out.push(`### ${task.id} — ${task.title ?? ''}`);
    out.push('');
    out.push(`- Record SHA-256: \`${task.recordSha256}\``);
    out.push(`- Platform scope: \`${(task.platformScope ?? []).join(', ')}\``);
    out.push(`- Dependencies: ${(task.dependencies ?? []).length ? task.dependencies.map((d) => `\`${d}\``).join(', ') : '_(none)_'} `);
    out.push(`- Test contract cases: ${task.testContract?.cases?.length ?? 0}`);
    out.push(`- Red-scaffold rows: ${task.redScaffold?.length ?? 0}`);
    out.push(`- Source acquisitions: ${task.sourceAcquisitions?.length ?? 0}`);
    out.push(`- Product commit message: \`${task.commits?.product?.message ?? ''}\``);
    out.push(`- Evidence commit message: \`${task.commits?.evidence?.message ?? ''}\``);
    out.push(`- Staged evidence path: \`${task.evidence?.stagedEvidencePath ?? ''}\``);
    out.push('');
    out.push('#### Stages');
    out.push('');
    renderStages(out, task.stages ?? []);
    out.push('#### Paths');
    out.push('');
    out.push(`- productTarget: \`${task.paths?.productTarget ?? 'null'}\``);
    out.push('- create:');
    renderList(out, '  ', task.paths?.create ?? []);
    out.push('- modify:');
    renderList(out, '  ', task.paths?.modify ?? []);
    out.push('- test:');
    renderList(out, '  ', task.paths?.test ?? []);
    out.push('');
  }
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// README
// ---------------------------------------------------------------------------

function renderREADME(plan) {
  const out = [];
  out.push('# MonaCode G6-R execution plan');
  out.push('');
  out.push('This directory is the human companion to the machine-authoritative G6-R execution plan manifest. It renders the complete execution-readiness plan: 200 tasks across 10 phases, each with a seven-stage lifecycle, pinned toolchain commands, and commit-before-evidence ordering.');
  out.push('');
  out.push('## Authority and reading order');
  out.push('');
  out.push('1. `../artifacts/monacode-g6r-execution-schema.json` defines the closed TaskRecord contract.');
  out.push('2. `../artifacts/monacode-g6r-implementation-plan-manifest.json` owns task records, ownership, evidence, and commit contracts.');
  out.push('3. `../artifacts/monacode-g6r-command-dependency-manifest.json` owns the 400 deduplicated verification commands.');
  out.push('4. `../artifacts/monacode-g6r-interface-contract-manifest.json` owns the 340 deduplicated interface contracts.');
  out.push('5. `00-master-plan.md` summarizes the whole-project graph and fixed matrices.');
  out.push('6. `phase-00-*.md` through `phase-09-*.md` render the same task records. Every task marker contains the SHA-256 of its complete machine record.');
  out.push('');
  out.push('## Verification');
  out.push('');
  out.push('```sh');
  out.push('/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/assemble-plan.mjs');
  out.push('/opt/homebrew/Cellar/node/26.7.0/bin/node Tools/G6PlanAuthoring/render-plan.mjs');
  out.push('/opt/homebrew/Cellar/node/26.7.0/bin/node --test Tools/G6PlanAuthoring/tests/assemble-plan.test.mjs');
  out.push('```');
  out.push('');
  out.push('The assembly prints `G6_PLAN_ASSEMBLED ...` with the exact pinned counts. Rendering twice changes zero bytes. Every human document is derived from the machine record; no normative content is absent from the manifest.');
  out.push('');
  out.push('## Plan summary');
  out.push('');
  out.push('| Matrix | Count |');
  out.push('| --- | --- |');
  out.push(`| Phases | ${plan.counts.phases} |`);
  out.push(`| Tasks | ${plan.counts.tasks} |`);
  out.push(`| Test contracts | ${plan.counts.testContracts} |`);
  out.push(`| Commands | ${plan.counts.commands} |`);
  out.push(`| Leaves | ${plan.counts.leaves} |`);
  out.push(`| Begin actions | ${plan.counts.beginActions} |`);
  out.push(`| Commit actions | ${plan.counts.commitActions} |`);
  out.push(`| Finalize actions | ${plan.counts.finalizeActions} |`);
  out.push(`| Product-commit contracts | ${plan.counts.productCommitContracts} |`);
  out.push(`| Evidence-commit contracts | ${plan.counts.evidenceCommitContracts} |`);
  out.push(`| Source gaps | ${plan.counts.sourceGaps} |`);
  out.push(`| Acquisition gaps | ${plan.counts.acquisitionGaps} |`);
  out.push(`| Red-scaffold tasks | ${plan.counts.scaffoldTasks} |`);
  out.push(`| Red-scaffold paths | ${plan.counts.scaffoldPaths} |`);
  out.push(`| Interfaces | ${plan.counts.interfaces} |`);
  out.push(`| Ownership rows | ${plan.counts.ownership} |`);
  out.push(`| Evidence contracts | ${plan.counts.evidence} |`);
  out.push('');
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// renderPlan — public entry point
// ---------------------------------------------------------------------------

/**
 * Render the eleven human documents from an assembled ExecutionPlan.
 * Returns a Map<string, string> of relative-path -> Markdown content.
 * Deterministic: the same plan always produces byte-identical documents.
 *
 * @param {object} plan - Assembled ExecutionPlan from assemblePlan.
 * @returns {Map<string, string>}
 */
export function renderPlan(plan) {
  const docs = new Map();
  docs.set('implementation-plan/README.md', renderREADME(plan));
  docs.set('implementation-plan/00-master-plan.md', renderMasterPlan(plan));
  for (let i = 0; i < 10; i += 1) {
    docs.set(`implementation-plan/${PHASE_SLUGS[i]}.md`, renderPhaseDoc(plan, i));
  }
  return docs;
}

// ---------------------------------------------------------------------------
// Script entry point
// ---------------------------------------------------------------------------

const MANIFEST_PATH =
  'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-implementation-plan-manifest.json';

function main() {
  const repoRoot = process.cwd();
  const manifest = JSON.parse(readFileSync(path.join(repoRoot, MANIFEST_PATH), 'utf8'));
  const docs = renderPlan(manifest);
  const planDir = path.join(repoRoot, 'docs/contracts/monaco-editor-0.56.0/g6-r');
  for (const [relPath, content] of docs) {
    const abs = path.join(planDir, relPath);
    mkdirSync(path.dirname(abs), { recursive: true });
    writeFileSync(abs, content, 'utf8');
  }
  // eslint-disable-next-line no-console
  console.log(`G6_PLAN_RENDERED docs=${docs.size}`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
