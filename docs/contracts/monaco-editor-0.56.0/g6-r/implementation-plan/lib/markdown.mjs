// G6-R Markdown audit (ported from G5-R without cross-directory imports).
// Verifies every phase document referenced by the plan exists on disk and, when
// a phase document carries `<!-- monacode-plan-task:... -->` markers, proves
// each marker is canonical JSON ({id,recordSha256}), unique, and matches a task
// record's sha256. The G6-R execution-plan phase documents are structural
// narratives (no per-task markers), so the marker path is exercised only by the
// unit tests' fixture documents. documentHashes returns the actual sha256 of
// each present phase document (informational; never compared as a finding).

import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

import { makeFinding, sortFindings } from './findings.mjs';
import { canonicalJSONStringify, recordSha256 } from './canonical-json.mjs';

const PREFIX = '<!-- monacode-plan-task:';
const SUFFIX = ' -->';
const HASH = /^[0-9a-f]{64}$/;

function parseMarkers(contents, documentPath) {
  const findings = [];
  const markers = [];
  for (const [lineIndex, sourceLine] of contents.split('\n').entries()) {
    if (!sourceLine.includes(PREFIX)) continue;
    const line = sourceLine.trim();
    const subject = `${documentPath}:${lineIndex + 1}`;
    if (!line.startsWith(PREFIX) || !line.endsWith(SUFFIX)) {
      findings.push(makeFinding({
        id: 'PLAN_MARKDOWN_DRIFT', category: 'markdown', taskID: null, path: subject,
        message: 'malformed task marker boundary',
      }));
      continue;
    }
    const payload = line.slice(PREFIX.length, -SUFFIX.length);
    let marker;
    try {
      marker = JSON.parse(payload);
    } catch {
      findings.push(makeFinding({
        id: 'PLAN_MARKDOWN_DRIFT', category: 'markdown', taskID: null, path: subject,
        message: 'task marker JSON is invalid',
      }));
      continue;
    }
    if (
      Object.keys(marker).sort().join(',') !== 'id,recordSha256'
      || typeof marker.id !== 'string'
      || !HASH.test(marker.recordSha256 ?? '')
      || canonicalJSONStringify(marker) !== payload
    ) {
      findings.push(makeFinding({
        id: 'PLAN_MARKDOWN_DRIFT', category: 'markdown', taskID: null, path: subject,
        message: 'task marker is not canonical',
      }));
      continue;
    }
    markers.push({ ...marker, subject });
  }
  return { findings, markers };
}

/**
 * Audit the plan's phase documents for existence and marker integrity.
 * @param {{phases?:Array<{id:string,document:string}>,tasks?:Array<{id:string,phase?:string,recordSha256?:string}>}} plan
 * @param {string} planDirectory - directory containing the phase documents.
 * @returns {{findings:object[], documentHashes:Array<{path:string,sha256:string}>}}
 */
export function auditMarkdown(plan, planDirectory) {
  const findings = [];
  const documentHashes = [];
  const tasks = plan.tasks ?? [];
  for (const phase of [...(plan.phases ?? [])].sort((a, b) =>
    (a.id ?? '').localeCompare(b.id ?? '', 'en'))) {
    const documentPath = phase.document;
    const resolved = path.resolve(planDirectory, documentPath);
    if (!fs.existsSync(resolved)) {
      findings.push(makeFinding({
        id: 'PLAN_PHASE_DOCUMENT_MISSING', category: 'markdown', taskID: null,
        path: documentPath, message: `phase ${phase.id} document ${documentPath} is missing`,
      }));
      continue;
    }
    const contents = fs.readFileSync(resolved, 'utf8');
    documentHashes.push({
      path: documentPath,
      sha256: createHash('sha256').update(contents).digest('hex'),
    });
    const parsed = parseMarkers(contents, documentPath);
    findings.push(...parsed.findings);
    // Marker validation only applies when the document carries markers.
    if (parsed.markers.length === 0) continue;
    const byId = new Map();
    for (const marker of parsed.markers) {
      if (byId.has(marker.id)) {
        findings.push(makeFinding({
          id: 'PLAN_MARKDOWN_DRIFT', category: 'markdown', taskID: marker.id,
          path: marker.subject, message: `duplicate marker ${marker.id}`,
        }));
      } else {
        byId.set(marker.id, marker);
      }
    }
    const expectedTasks = tasks
      .filter((t) => t.phase === phase.id)
      .sort((a, b) => (a.id ?? '').localeCompare(b.id ?? '', 'en'));
    for (const task of expectedTasks) {
      const marker = byId.get(task.id);
      if (!marker) {
        findings.push(makeFinding({
          id: 'PLAN_MARKDOWN_DRIFT', category: 'markdown', taskID: task.id,
          path: documentPath, message: `missing marker for ${task.id}`,
        }));
      } else if (typeof task.recordSha256 === 'string' && marker.recordSha256 !== task.recordSha256) {
        findings.push(makeFinding({
          id: 'PLAN_MARKDOWN_DRIFT', category: 'markdown', taskID: task.id,
          path: documentPath, message: `record hash differs for ${task.id}`,
        }));
      }
    }
  }
  return { findings: sortFindings(findings), documentHashes };
}
