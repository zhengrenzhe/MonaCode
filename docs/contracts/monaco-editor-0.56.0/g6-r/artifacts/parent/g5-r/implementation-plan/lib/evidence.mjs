import { compareFindings, finding } from './findings.mjs';
import { auditEnvironment } from '../tools/collect-environment.mjs';

const PLAN_STATES = new Set(['planned', 'mapped', 'structurally-verified']);

export function auditEvidence(plan, contract) {
  const findings = [];
  if (!PLAN_STATES.has(plan.planState)) {
    findings.push(finding('PLAN_FALSE_EVIDENCE_STATE', '$.planState', String(plan.planState)));
  }
  if (
    JSON.stringify(plan.evidenceStates) !== JSON.stringify(['planned', 'mapped', 'structurally-verified'])
  ) {
    findings.push(finding('PLAN_FALSE_EVIDENCE_STATE', '$.evidenceStates', 'plan evidence state set changed'));
  }
  for (const task of plan.tasks ?? []) {
    for (const evidencePath of task.evidence ?? []) {
      if (evidencePath.includes('implementation-plan/verification/')) {
        findings.push(finding(
          'PLAN_FALSE_EVIDENCE_STATE',
          task.id,
          'plan-review output cannot serve as product evidence'
        ));
      }
    }
  }

  const expectedEnvironment = {
    manifest: 'artifacts/monacode-g5r-qualification-environment-manifest.json',
    macOSBuild: contract.currentLocalEnvironment.macOSBuild,
    chromeVersion: contract.currentLocalEnvironment.chrome,
    externalDisplayCountRequired: contract.currentLocalEnvironment.externalDisplayCountRequiredForFormalRuns,
    formalDisplayScope: contract.currentLocalEnvironment.releaseDisplayScope
  };
  for (const [key, expected] of Object.entries(expectedEnvironment)) {
    const actual = plan.qualificationEnvironment?.[key];
    if (actual !== expected) {
      findings.push(finding('PLAN_ENVIRONMENT_MISMATCH', `$.qualificationEnvironment.${key}`, `${actual} != ${expected}`));
    }
  }
  findings.push(...auditEnvironment(plan.qualificationEnvironment ?? {}));
  return findings.sort(compareFindings);
}
