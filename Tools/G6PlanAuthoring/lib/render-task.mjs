// G6-R Task 11 — deterministic task Markdown renderer.
//
// renderTask produces a stable Markdown representation of a migrated TaskRecord.
// The first line is a stable task marker carrying the canonical task-record hash:
//   <!-- G6-R-TASK:<TASK_ID>:<recordSha256> -->
// Rendering the same task twice yields byte-identical Markdown (all fields
// emitted in a fixed order; arrays emitted in their stored order).

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
      } else {
        out.push(`- ${escapeInline(kind)}: \`${JSON.stringify(step)}\``);
      }
    }
    out.push('');
  }
}

/**
 * Render a migrated TaskRecord as deterministic Markdown.
 * @param {object} task
 * @returns {string}
 */
export function renderTask(task) {
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
    out.push(`  - \`${a?.url ?? ''}\` host=\`${a?.allowedHost ?? ''}\` disposition=\`${a?.disposition ?? ''}\``);
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
