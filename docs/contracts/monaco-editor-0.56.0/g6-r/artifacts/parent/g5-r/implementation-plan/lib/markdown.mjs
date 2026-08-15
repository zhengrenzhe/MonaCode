import fs from 'node:fs';
import path from 'node:path';

import { canonicalJSONString, recordSha256 } from './canonical-json.mjs';
import { compareFindings, finding } from './findings.mjs';

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
      findings.push(finding('PLAN_MARKDOWN_DRIFT', subject, 'malformed task marker boundary'));
      continue;
    }
    const payload = line.slice(PREFIX.length, -SUFFIX.length);
    let marker;
    try {
      marker = JSON.parse(payload);
    } catch {
      findings.push(finding('PLAN_MARKDOWN_DRIFT', subject, 'task marker JSON is invalid'));
      continue;
    }
    if (
      Object.keys(marker).sort().join(',') !== 'id,recordSha256'
      || typeof marker.id !== 'string'
      || !HASH.test(marker.recordSha256 ?? '')
      || canonicalJSONString(marker) !== payload
    ) {
      findings.push(finding('PLAN_MARKDOWN_DRIFT', subject, 'task marker is not canonical'));
      continue;
    }
    markers.push({ ...marker, subject });
  }
  return { findings, markers };
}

export function auditMarkdown(plan, planDirectory) {
  const findings = [];
  const tasks = plan.tasks ?? [];
  for (const phase of [...(plan.phases ?? [])].sort((left, right) => left.id.localeCompare(right.id, 'en'))) {
    const documentPath = path.resolve(planDirectory, phase.document);
    if (!fs.existsSync(documentPath)) {
      findings.push(finding('PLAN_PHASE_DOCUMENT_MISSING', phase.id, phase.document));
      continue;
    }
    const parsed = parseMarkers(fs.readFileSync(documentPath, 'utf8'), phase.document);
    findings.push(...parsed.findings);
    const byId = new Map();
    for (const marker of parsed.markers) {
      if (byId.has(marker.id)) {
        findings.push(finding('PLAN_MARKDOWN_DRIFT', marker.subject, `duplicate marker ${marker.id}`));
      } else {
        byId.set(marker.id, marker);
      }
    }
    const expectedTasks = tasks
      .filter((task) => task.phase === phase.id)
      .sort((left, right) => left.id.localeCompare(right.id, 'en'));
    const expectedIDs = new Set(expectedTasks.map((task) => task.id));
    for (const task of expectedTasks) {
      const marker = byId.get(task.id);
      if (!marker) {
        findings.push(finding('PLAN_MARKDOWN_DRIFT', task.id, `missing marker in ${phase.document}`));
      } else if (marker.recordSha256 !== recordSha256(task)) {
        findings.push(finding('PLAN_MARKDOWN_DRIFT', task.id, `record hash differs in ${phase.document}`));
      }
    }
    for (const marker of parsed.markers) {
      if (!expectedIDs.has(marker.id)) {
        findings.push(finding('PLAN_MARKDOWN_DRIFT', marker.id, `marker has no task in phase ${phase.id}`));
      }
    }
  }
  return findings.sort(compareFindings);
}
